# Calling a C++ function from Julia means reproducing the platform ABI for its exact signature:
# which arguments travel in registers, which are copied to the stack, whether the result needs a
# hidden return pointer, where `this` goes. Rather than model any of that here, every call site
# gets a trampoline that the interpreter compiles for it, so Clang lowers the call.
#
# The trampoline's signature is NATIVE: it mirrors the callee's own, so `int add(int, int)`
# becomes `extern "C" int __w(int, int)` and Julia reaches it with one ordinary `ccall` passing
# ordinary Julia values. Nothing is boxed and nothing travels through a `void **` array.
#
# Only shapes with no Julia counterpart go by address: a reference (a pointer to its referent),
# a class passed or returned by value, and types like `long double` or a pointer-to-member that
# have no `ccall` slot at all. `has_machine_type` is the single predicate that decides, which is
# why `cppsig` has to be total.

const WRAPPER_PREFIX = "__cppcall_wrapper_"
const BUILDER_PREFIX = "__cppcall_new_"
const ALIAS_PREFIX = "__cppcall_ty_"
const RET_ALIAS = "__cppcall_ret_t"
const DEALLOCATE = "__cppcall_deallocate"

next_id!(I::CppInterpreter) = (I.counter[] += 1)

"""
    spell(I::CppInterpreter, ty::QualType, name::AbstractString="") -> String
Return the C++ spelling of `ty` under the interpreter's own printing policy. `name` is the
declarator being declared, so `spell(I, int_ptr_ty, "p")` gives `"int *p"` and the default
gives the bare type-id.
"""
function spell(I::CppInterpreter, ty::QualType, name::AbstractString="")
    return CC.printAsString(ty, get_ast_context(I), name)
end

# A type clang can only describe positionally -- an anonymous enum or record with no typedef --
# cannot be written into generated source. Refusing with a clear message beats emitting code
# that fails to parse against a diagnostic pointing at a line the user never wrote.
function checked_spell(I::CppInterpreter, ty::QualType, name::AbstractString="")
    s = spell(I, ty, name)
    if occursin("(unnamed", s) || occursin("(anonymous", s)
        throw(ArgumentError("cannot name the C++ type `$s` in generated code; " *
                            "give it a typedef name and use that instead"))
    end
    return s
end

ptr_to(I::CppInterpreter, ty::QualType) = get_pointer_type(get_ast_context(I), ty)

referent_of(P::QualType) = get_pointee_type(clty_to_jlty(get_type_ptr(CC.getCanonicalType(P))))

# What a materialised temporary for a `T&` referent has to be, or `Cvoid` when the referent has
# no Julia counterpart and therefore can never be materialised from a Julia value.
function referent_target(W::QualType)
    # ask the UNQUALIFIED type: `cppsig` of a cv-qualified enum is a bare `CppType` tag that has
    # dropped the underlying type, and materialising into the wrong width would corrupt the call
    m = machine_type(cppsig(CC.getUnqualifiedType(W)))
    return m === nothing ? Cvoid : m
end

"""
    jit(I::CppInterpreter, name::AbstractString, code::AbstractString) -> Ptr{Cvoid}
Compile `code`, which must define a function called `name` with external C linkage, and return
the address the JIT gave it.
"""
function jit(I::CppInterpreter, name::AbstractString, code::AbstractString)
    declare(I, code, true) || error("failed to compile the generated code:\n$code")
    fptr = CC.get_function_pointer(I.bridge, name)
    fptr == C_NULL && error("failed to resolve the address of `$name`.")
    return fptr
end

"""
    runtime!(I::CppInterpreter) -> Ptr{Cvoid}
Compile the support code the generated glue relies on and return the address of its
deallocation entry point. Runs at most once per interpreter, on first use rather than at
startup so an interpreter only ever used for declaration lookup never pays for it.

The placement `operator new` is declared here rather than pulled in from `<new>`: the
interpreter may have been built with a C header environment, where that header does not exist.
Only the standard placement signature is reserved, so the extra tag parameter is what makes
defining this one legal.

Both names carry the interpreter's serial number. `undo` can roll back past this code without
CppCall being able to tell, and re-declaring the same names would put clang in front of a
redefinition it crashes while diagnosing; a fresh pair cannot collide with what is still there.
"""
function runtime!(I::CppInterpreter)
    if !isempty(I.runtime[])
        haskey(I.builders, DEALLOCATE) ||
            error("the CppCall runtime support code failed to compile in this interpreter.")
        return I.builders[DEALLOCATE]
    end
    n = next_id!(I)
    ns = "__cppcall_rt_$n"
    dealloc = "$(DEALLOCATE)_$n"
    I.runtime[] = ns
    code = """
    namespace $ns { struct place {}; }
    inline void *operator new(decltype(sizeof(0)) __n, void *__p, $ns::place) noexcept {
        (void)__n;
        return __p;
    }
    extern "C" void $dealloc(void *__p) { ::operator delete(__p); }
    """
    return I.builders[DEALLOCATE] = jit(I, dealloc, code)
end

place_tag(I::CppInterpreter) = I.runtime[] * "::place{}"

# Marshalling ------------------------------------------------------------------------------

"""
    struct ArgMarshal
How one argument crosses: the trampoline's parameter declaration, the expression handed to the
callee, and the `ccall` slot Julia fills.
"""
struct ArgMarshal
    param::String
    arg::String
    slot::Type
    # the Julia type a materialised temporary must have. A prvalue bound to `const T&` has no
    # address of its own, so the call site makes one -- and it has to be a `T`, not whatever
    # the caller happened to write, or the callee reads the wrong width.
    target::Type
end

"""
    plan_param(I, P::QualType, i::Int, moved::Bool=false) -> ArgMarshal
Decide how parameter `i`, of C++ type `P`, is carried.

`P` must be the **canonical** parameter type from the function's prototype: clang has already
stripped top-level cv there, exactly as C++ does for overloading, so `int` and `const int` are
one parameter type rather than two.
"""
function plan_param(I::CppInterpreter, P::QualType, i::Int, moved::Bool=false)
    name = "__a$i"
    S = cppsig(P)
    if S <: CppRef
        # a reference is carried as a pointer to its referent, dereferenced on arrival
        W = referent_of(P)
        return ArgMarshal(checked_spell(I, ptr_to(I, W), name), "(*$name)", Ptr{Cvoid},
                          referent_target(W))
    elseif S <: CppRvalueRef
        W = referent_of(P)
        cast = checked_spell(I, W)
        # the dereference is an lvalue and would not bind to `T&&` on its own
        return ArgMarshal(checked_spell(I, ptr_to(I, W), name),
                          "static_cast<$cast &&>(*$name)", Ptr{Cvoid}, referent_target(W))
    elseif has_machine_type(S)
        return ArgMarshal(checked_spell(I, P, name), name, machine_type(S), machine_type(S))
    elseif moved
        # by value from an xvalue: move rather than copy. This is the only form that compiles
        # for a move-only class, and it is reached only through an explicit `@move`.
        cast = checked_spell(I, P)
        return ArgMarshal(checked_spell(I, ptr_to(I, P), name),
                          "static_cast<$cast &&>(*$name)", Ptr{Cvoid}, Cvoid)
    else
        # by value: dereferencing a pointer-to-const runs the copy constructor, which is what
        # by-value means in C++ -- not a byte copy
        return ArgMarshal(checked_spell(I, ptr_to(I, add_const(P)), name), "(*$name)",
                          Ptr{Cvoid}, Cvoid)
    end
end

"""
    struct RetMarshal
How the result comes back: the trampoline's return type, a builder wrapping the call expression
into the trampoline body, the `ccall` return slot, whether a leading `void *__ret`
out-parameter is needed, and the Julia type the caller ends up holding.
"""
struct RetMarshal
    rettype::String
    body::Function
    slot::Type
    sret::Bool
    jl::Any
end

function plan_return(I::CppInterpreter, R::QualType)
    canon = CC.getCanonicalType(R)
    CC.isVoidType(get_type_ptr(canon)) &&
        return RetMarshal("void", call -> "$call;", Cvoid, false, Cvoid)
    S = cppsig(canon)
    if S <: CppRef
        W = referent_of(canon)
        return RetMarshal(checked_spell(I, ptr_to(I, W)), call -> "return &($call);",
                          Ptr{Cvoid}, false, CppRef{to_jl(W)})
    elseif S <: CppRvalueRef
        W = referent_of(canon)
        cast = checked_spell(I, W)
        # a call returning `T&&` is an xvalue and `&` needs an lvalue: bind it to a named
        # rvalue reference first, or this is `error: cannot take the address of an rvalue`
        return RetMarshal(checked_spell(I, ptr_to(I, W)),
                          call -> "$cast &&__t = $call; return &__t;",
                          Ptr{Cvoid}, false, CppRvalueRef{to_jl(W)})
    elseif has_machine_type(S)
        return RetMarshal(checked_spell(I, canon), call -> "return $call;", machine_type(S),
                          false, to_jl(canon))
    else
        # no slot: construct into caller-provided storage. Under C++17 this is guaranteed copy
        # elision, so it costs nothing over an sret.
        sz = size_of(get_ast_context(I), canon)
        alias = checked_spell(I, canon, RET_ALIAS)
        return RetMarshal("void",
                          call -> "typedef $alias; new (__ret, $(place_tag(I))) $RET_ALIAS($call);",
                          Cvoid, true, CppValue{to_jl(canon),sz})
    end
end

# Call spellings ---------------------------------------------------------------------------

"""
    call_expr(I, f, args) -> String
The C++ expression that calls `f` with `args`.

The callee is reached through a pointer `static_cast` to its own type rather than by name.
Naming it re-runs overload resolution over the whole set, and the arguments are spelled as the
exact parameter types of the overload already chosen -- precisely the case where two candidates
tie. Converting to a function pointer selects by exact signature match instead.
"""
function call_expr(I::CppInterpreter, f::CC.AbstractFunctionDecl, args::Vector{String})
    target = spell(I, ptr_to(I, CC.getCanonicalType(getType(f))))
    return "static_cast<$target>(&$(CC.getQualifiedNameAsString(f)))($(join(args, ", ")))"
end

function call_expr(I::CppInterpreter, f::CC.AbstractCXXMethodDecl, args::Vector{String};
                   objclass::String="")
    ast = get_ast_context(I)
    parent = get_decl_type(ast, CC.getParent(f))
    declclass = spell(I, CC.getCanonicalType(parent))
    name = "$declclass::$(CC.getNameAsString(f))"
    fnty = CC.getCanonicalType(getType(f))
    CC.isStatic(f) &&
        return "static_cast<$(spell(I, ptr_to(I, fnty)))>(&$name)($(join(args, ", ")))"
    target = spell(I, CC.getMemberPointerType(ast, fnty, parent))
    # cast `__obj` to the object's OWN class, not the declaring one: under multiple inheritance
    # the two differ by an offset, and applying the member pointer to the derived object is what
    # makes C++ perform the adjustment
    recv = isempty(objclass) ? declclass : objclass
    return "((($recv *)__obj)->*static_cast<$target>(&$name))($(join(args, ", ")))"
end

# Trampolines ------------------------------------------------------------------------------

"""
    struct CallPlan
Everything both sides of one call site need, produced together so they cannot disagree about
the trampoline's signature.
"""
struct CallPlan
    fptr::Ptr{Cvoid}
    slots::Vector{Type}
    targets::Vector{Type}
    ret::RetMarshal
end

is_instance_method(f) = f isa CC.AbstractCXXMethodDecl &&
                        !(f isa CC.AbstractCXXConstructorDecl) && !CC.isStatic(f)

"""
    plan_call(I, decl, params; objclass, movemask) -> CallPlan
Build (or reuse) the trampoline for calling `decl`, and report the `ccall` shape reaching it.
"""
function plan_call(I::CppInterpreter, decl::AbstractNamedDecl, params::Vector{QualType};
                   objclass::String="", movemask::UInt32=UInt32(0))
    runtime!(I)
    f = CC.resolve(decl)
    marshals = ArgMarshal[plan_param(I, P, i - 1, isodd(movemask >> (i - 1)))
                          for (i, P) in enumerate(params)]
    ret = plan_return_for(I, f)
    method = is_instance_method(f)

    slots = Type[]
    # ORDER IS NORMATIVE: __obj, then __ret, then the arguments. Both are `void *`, so a
    # disagreement between the emitted source and the ccall would be silent memory corruption
    # rather than a diagnostic. This is the one function that writes both.
    method && push!(slots, Ptr{Cvoid})
    ret.sret && push!(slots, Ptr{Cvoid})
    append!(slots, (m.slot for m in marshals))

    fptr = get!(I.wrappers, (UInt(decl.ptr), objclass, movemask)) do
        emit_wrapper(I, f, marshals, ret, method, objclass)
    end
    return CallPlan(fptr, slots, Type[m.target for m in marshals], ret)
end

plan_return_for(I::CppInterpreter, f) = plan_return(I, CC.getReturnType(f))

function plan_return_for(I::CppInterpreter, f::CC.AbstractCXXConstructorDecl)
    ty = CC.getCanonicalType(get_decl_type(get_ast_context(I), CC.getParent(f)))
    cls = checked_spell(I, ty)
    # a constructor has no address to call through, so the object is built by name; the
    # trampoline hands back the pointer, which is what `@ctor` returns
    return RetMarshal("void *", args -> "return (void *)(new $cls$args);", Ptr{Cvoid}, false,
                      Ptr{to_jl(ty)})
end

function emit_wrapper(I::CppInterpreter, f, marshals::Vector{ArgMarshal}, ret::RetMarshal,
                      method::Bool, objclass::String)
    name = WRAPPER_PREFIX * string(next_id!(I))
    decls = String[]
    method && push!(decls, "void *__obj")
    ret.sret && push!(decls, "void *__ret")
    append!(decls, (m.param for m in marshals))
    args = String[m.arg for m in marshals]

    body = if f isa CC.AbstractCXXConstructorDecl
        ret.body("(" * join(args, ", ") * ")")
    elseif f isa CC.AbstractCXXMethodDecl
        ret.body(call_expr(I, f, args; objclass))
    else
        ret.body(call_expr(I, f, args))
    end

    code = """
    extern "C" $(ret.rettype) $name($(isempty(decls) ? "void" : join(decls, ", "))) {
        $body
    }
    """
    return jit(I, name, code)
end

# Allocation -------------------------------------------------------------------------------

"""
    cppconstruct(I::CppInterpreter, ty::QualType) -> Ptr{Cvoid}
Heap-allocate a value-initialized object of type `ty` and return a pointer to it. Release it
with [`cppdeallocate`](@ref).
"""
function cppconstruct(I::CppInterpreter, ty::QualType)
    runtime!(I)
    s = checked_spell(I, CC.getUnqualifiedType(CC.getCanonicalType(ty)))
    fptr = get!(I.builders, s) do
        name = BUILDER_PREFIX * string(next_id!(I))
        jit(I, name, """extern "C" void *$name(void) { return (void *)(new $s()); }""")
    end
    ptr = ccall(fptr, Ptr{Cvoid}, ())
    ptr == C_NULL && error("failed to allocate a `$s`.")
    return ptr
end

"""
    cppdeallocate(I::CppInterpreter, ptr::Ptr{Cvoid})
Release memory obtained from [`cppconstruct`](@ref) or from a constructor call. The destructor
is not run, matching `@cppnew`/`@cppdelete`'s raw-storage semantics.
"""
function cppdeallocate(I::CppInterpreter, ptr::Ptr{Cvoid})
    ptr == C_NULL && return nothing
    ccall(runtime!(I), Cvoid, (Ptr{Cvoid},), ptr)
    return nothing
end

# Class templates --------------------------------------------------------------------------

"""
    specialize(I::CppInterpreter, spelling::AbstractString) -> QualType
Return the type Clang forms for the template-id `spelling`, e.g. `"std::vector<int>"`.

The template-id is handed back to the interpreter as an alias declaration and the alias is then
looked up, so the specialization is the one Clang itself would build: default template
arguments are filled in and partial specializations selected, neither of which happens when a
`ClassTemplateSpecializationDecl` is assembled by hand from the arguments written.
"""
function specialize(I::CppInterpreter, spelling::AbstractString)
    key = String(spelling)
    haskey(I.aliases, key) && return I.aliases[key]
    name = ALIAS_PREFIX * string(next_id!(I))
    declare(I, "namespace __cppcall { using $name = $key; }", true) ||
        error("failed to instantiate the class template `$key`.")
    lookup_func(I, "__cppcall::$name") ||
        error("failed to look up the instantiated class template `$key`.")
    ty = CC.getCanonicalType(CC.getUnderlyingType(CC.TypedefNameDecl(get_func_decl(I))))
    I.aliases[key] = ty
    return ty
end
