# Calling a C++ function from Julia means reproducing the platform ABI for its exact
# signature: which arguments travel in registers, which are copied to the stack, whether the
# result needs a hidden return pointer, where `this` goes. Rather than model any of that
# here, every call site gets a small trampoline that the interpreter compiles for it, so
# Clang lowers the call and Julia only ever crosses the boundary through one fixed signature:
#
#     void wrapper(void *obj, void **args, void *ret)
#
# `obj` is the object a method is called on (NULL for free functions), `args[i]` points at
# the i-th argument, and `ret` points at storage for the result (NULL when there is none).
# The trampoline is generated as C++ source, which is also what makes overload resolution,
# implicit conversions and template instantiation Clang's problem rather than ours.

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

"""
    jit(I::CppInterpreter, name::AbstractString, code::AbstractString) -> Ptr{Cvoid}
Compile `code`, which must define a function called `name` with external C linkage, and
return the address the JIT gave it.
"""
function jit(I::CppInterpreter, name::AbstractString, code::AbstractString)
    declare(I, code, true) || error("failed to compile the generated code:\n$code")
    fptr = CC.get_function_pointer(I.bridge, name)
    fptr == C_NULL && error("failed to resolve the address of `$name`.")
    return fptr
end

# The interpreter is built by `IncrementalCompilerBuilder::CreateCpp`, so the generated glue
# is compiled as C++ whatever `is_cxx` selected for the header environment, and every
# generated entry point needs `extern "C"` to keep its name unmangled and findable.

"""
    runtime!(I::CppInterpreter) -> Ptr{Cvoid}
Compile the support code CppCall's generated glue relies on and return the address of its
deallocation entry point. Runs at most once per interpreter, on first use rather than at
startup so that an interpreter only ever used for declaration lookup never pays for it.

The placement `operator new` is declared here rather than pulled in from `<new>`: the
interpreter may have been built with a C header environment, where that header does not
exist. Only the standard placement signature is reserved, so the extra tag parameter is what
makes defining this one legal.

Both names carry the interpreter's serial number. `undo` can roll the interpreter back to
before this code without CppCall being able to tell, and re-declaring the same names would
put clang in front of a redefinition it crashes while diagnosing; a fresh pair cannot
collide with what is still there.
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

# the tag that selects the placement `operator new` above; `runtime!` must have run first
place_tag(I::CppInterpreter) = I.runtime[] * "::place{}"

# Argument spellings -----------------------------------------------------------------------

"""
    arg_expr(I::CppInterpreter, ty::QualType, i::Integer) -> String
Return the C++ expression that recovers the `i`-th (0-based) argument of a call from the
`args` array as a value of type `ty`.

`args[i]` always points at the argument object itself, so a parameter taken by reference and
one taken by value read the same pointer and differ only in what is done with it.
"""
function arg_expr(I::CppInterpreter, ty::QualType, i::Integer)
    ast = get_ast_context(I)
    canon = CC.getCanonicalType(ty)
    t = clty_to_jlty(get_type_ptr(canon))
    if t isa LValueReferenceType
        cast = spell(I, get_pointer_type(ast, get_pointee_type(t)))
        return "(*($cast)__args[$i])"
    elseif t isa RValueReferenceType
        cast = spell(I, get_pointer_type(ast, get_pointee_type(t)))
        # the dereference is an lvalue and would not bind to `T&&` on its own
        return "static_cast<$(spell(I, canon))>(*($cast)__args[$i])"
    else
        return "(*($(spell(I, get_pointer_type(ast, canon))))__args[$i])"
    end
end

function arg_exprs(I::CppInterpreter, f::CC.AbstractFunctionDecl)
    n = Int(CC.getNumParams(f))
    return [arg_expr(I, getType(CC.getParamDecl(f, i)), i) for i = 0:(n - 1)]
end

# Call spellings ---------------------------------------------------------------------------

"""
    call_expr(I::CppInterpreter, f, args::Vector{String}) -> String
Return the C++ expression that calls `f` with `args`.

The call goes through a pointer the generated code `static_cast`s to `f`'s own type instead
of naming `f` directly. Naming it would re-run overload resolution over the whole overload
set, and the arguments are spelled as the exact parameter types of the overload CppCall
already picked -- which is precisely the case where two candidates tie and Clang reports the
call as ambiguous. Converting to a function pointer instead selects by exact signature
match, so the overload that comes back is always the one that was asked for.
"""
function call_expr(I::CppInterpreter, f::CC.AbstractFunctionDecl, args::Vector{String})
    ast = get_ast_context(I)
    fnty = CC.getCanonicalType(getType(f))
    target = spell(I, get_pointer_type(ast, fnty))
    return "static_cast<$target>(&$(CC.getQualifiedNameAsString(f)))($(join(args, ", ")))"
end

function call_expr(I::CppInterpreter, f::CC.AbstractCXXMethodDecl, args::Vector{String})
    ast = get_ast_context(I)
    cls = spell(I, CC.getCanonicalType(get_decl_type(ast, CC.getParent(f))))
    name = "$cls::$(CC.getNameAsString(f))"
    fnty = CC.getCanonicalType(getType(f))
    CC.isStatic(f) &&
        return "static_cast<$(spell(I, get_pointer_type(ast, fnty)))>(&$name)($(join(args, ", ")))"
    target = spell(I, CC.getMemberPointerType(ast, fnty, get_decl_type(ast, CC.getParent(f))))
    return "((($cls *)__obj)->*static_cast<$target>(&$name))($(join(args, ", ")))"
end

"""
    ret_stmt(I::CppInterpreter, ty::QualType, call::AbstractString) -> String
Return the statement that evaluates `call` and leaves a result of type `ty` in `ret`.

A reference result is stored as the address of what it refers to, matching the pointer-sized
[`CppObject`](@ref) the caller allocates for a `CppRef`. Anything else is constructed in
place, so a class type gets a real copy or move rather than a byte-wise one.
"""
function ret_stmt(I::CppInterpreter, ty::QualType, call::AbstractString)
    canon = CC.getCanonicalType(ty)
    CC.isVoidType(get_type_ptr(canon)) && return "$call;"
    t = clty_to_jlty(get_type_ptr(canon))
    if t isa LValueReferenceType || t isa RValueReferenceType
        return "*(void **)__ret = (void *)&($call);"
    end
    value_ty = CC.getUnqualifiedType(canon)
    # the alias keeps the placement-new out of the `new int *(x)` grammar ambiguity
    return "typedef $(spell(I, value_ty, RET_ALIAS)); " *
           "new (__ret, $(place_tag(I))) $RET_ALIAS($call);"
end

# Trampolines ------------------------------------------------------------------------------

"""
    get_wrapper(I::CppInterpreter, decl) -> Ptr{Cvoid}
Return the address of the call trampoline for `decl`, compiling it on first use.
"""
function get_wrapper(I::CppInterpreter, decl::AbstractNamedDecl)
    return get!(I.wrappers, UInt(decl.ptr)) do
        runtime!(I)  # the generated body names the placement tag it declares
        build_wrapper(I, CC.resolve(decl))
    end
end

build_wrapper(I::CppInterpreter, f) = error("cannot call a $(typeof(f)); only functions, "
                                            * "methods and constructors have a call wrapper.")

function build_wrapper(I::CppInterpreter, f::CC.AbstractFunctionDecl)
    return emit_wrapper(I, ret_stmt(I, CC.getReturnType(f), call_expr(I, f, arg_exprs(I, f))))
end

function build_wrapper(I::CppInterpreter, f::CC.AbstractCXXConstructorDecl)
    cls = spell(I, CC.getCanonicalType(get_decl_type(get_ast_context(I), CC.getParent(f))))
    args = join(arg_exprs(I, f), ", ")
    # a constructor has no address to call through, so the object is built by name; `ret`
    # takes the pointer to it, which is what `@ctor` hands back
    return emit_wrapper(I, "*(void **)__ret = (void *)(new $cls($args));")
end

function emit_wrapper(I::CppInterpreter, body::AbstractString)
    name = WRAPPER_PREFIX * string(next_id!(I))
    code = """
    extern "C" void $name(void *__obj, void **__args, void *__ret) {
        (void)__obj; (void)__args; (void)__ret;
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
    s = spell(I, CC.getUnqualifiedType(CC.getCanonicalType(ty)))
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
Release memory obtained from [`cppconstruct`](@ref) or from a constructor call. The
destructor is not run, matching `@cppnew`/`@cppdelete`'s raw-storage semantics.
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

The template-id is handed back to the interpreter as an alias declaration and the alias is
then looked up, so the specialization is the one Clang itself would build: default template
arguments are filled in and partial specializations are selected, neither of which happens
when a `ClassTemplateSpecializationDecl` is assembled by hand from the arguments written.
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
