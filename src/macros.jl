"""
    @declare_str(code::AbstractString)
Declare the C++ code in the interpreter corresponding to the `__module__` it's being invoked.
"""
macro declare_str(code::AbstractString)
    @gensym CC_INSTANCE
    return esc(quote
                   local $CC_INSTANCE = CppCall.get_instance($__module__)
                   CppCall.declare($CC_INSTANCE, $code)
               end)
end

"""
    @include path
Add include search path to the interpreter corresponding to the `__module__` it's being invoked.
"""
macro include(path)
    @gensym CC_INSTANCE CC_PATH
    filename = string(__source__.file)
    prefix = startswith(filename, "REPL") ? pwd() : dirname(filename)
    return esc(quote
                   local $CC_INSTANCE = CppCall.get_instance($__module__)
                   local $CC_PATH = joinpath($prefix, $path) |> normpath
                   CppCall.cppinclude($CC_INSTANCE, $CC_PATH)
               end)
end

"""
    @__INSTANCE__ -> CppInterpreter
Macro to obtain the `CppInterpreter` instance corresponding to the `__module__` it's being invoked.
"""
macro __INSTANCE__()
    return esc(quote
                   CppCall.get_instance($__module__)
               end)
end

"""
    @undo(i)
Undo the last `i`-steps of the `CppInterpreter` instance corresponding to the `__module__` it's being invoked.
"""
macro undo(i)
    @gensym CC_INSTANCE
    return esc(quote
                   local $CC_INSTANCE = CppCall.get_instance($__module__)
                   CppCall.undo($CC_INSTANCE, $i)
               end)
end

"""
    @template cppty{T1, T2, ..., TN} where {T1, T2, ..., TN} -> CppTemplate{cppty, Tuple{T1, T2, ..., TN}}
Construct a `CppTemplate` with template arguments T1, T2, ..., TN.
"""
macro template(expr)
    root_expr = expr
    curly_expr = root_expr
    while Meta.isexpr(curly_expr, :where)
        curly_expr = first(curly_expr.args)
        Meta.isexpr(curly_expr, :curly) && break
        root_expr = curly_expr
    end
    if !Meta.isexpr(curly_expr, :curly)
        throw(ArgumentError("@template has to take a curly-brace expression"))
    end

    call_expr = Expr(:call, :CppTemplate, curly_expr.args...)

    Meta.isexpr(root_expr, :curly) && return call_expr

    root_expr.args[1] = call_expr
    return expr
end

# References and pointers -------------------------------------------------------------------
#
# Storage is Julia's own: `Ref(x)` is how you make a C++ lvalue out of a Julia value, and a
# `Ref` can be passed anywhere a `T&` or a `T*` is wanted. These macros exist for the two
# things `Ref` alone cannot say.

"""
    cppref(x) -> CppRef
Take a C++ reference to Julia-owned storage.

Unlike a bare pointer, the result keeps its referent alive: it holds the owning object, so the
storage cannot be collected while the reference is reachable. That is what makes it safe to
return one from a function or store it in a container.
"""
cppref(x::Base.RefValue{T}) where {T} = CppRef{T}(Base.unsafe_convert(Ptr{T}, x), x)
cppref(x::CppRef) = x
cppref(x::Ptr{T}) where {T} = CppRef{T}(reinterpret(Ptr{Cvoid}, x), nothing)

"""
    @ref obj
Create a C++ reference to `obj` that keeps `obj` alive for as long as the reference lives.
"""
macro ref(obj)
    return esc(:(CppCall.cppref($obj)))
end

"""
    cppmove(x) -> CppRvalueRef
Mark storage as movable-from, so a call binds it to a `T&&` parameter and the callee may take
its contents. The Julia object stays alive; its C++ contents may not survive the call.
"""
cppmove(x::Base.RefValue{T}) where {T} = CppRvalueRef{T}(Base.unsafe_convert(Ptr{T}, x), x)
cppmove(x::CppRef{T}) where {T} = CppRvalueRef{T}(x.ptr, x.owner)
cppmove(x::CppRvalueRef) = x

"""
    @move obj
Bind `obj` to a `T&&` parameter, permitting the callee to move from it -- C++'s `std::move`.
"""
macro move(obj)
    return esc(:(CppCall.cppmove($obj)))
end

"""
    cppptr(x) -> Ptr
The address of Julia-owned storage.

This does **not** keep the storage alive. Wrap the call in `GC.@preserve`, or use [`@ref`](@ref),
which does.
"""
cppptr(x::Base.RefValue{T}) where {T} = Base.unsafe_convert(Ptr{T}, x)
cppptr(x::AnyCppRef{T}) where {T} = reinterpret(Ptr{T}, x.ptr)
cppptr(x::Ptr) = x

"""
    @ptr obj
Take the address of `obj`. The result does not extend `obj`'s lifetime -- see [`@ref`](@ref).
"""
macro ptr(obj)
    return esc(:(CppCall.cppptr($obj)))
end

# Enumerators -------------------------------------------------------------------------------

"""
    cppvalue(::Type{CppEnum{S,N}}, I) -> CppEnumValue
The value of the C++ enumerator named `S`, typed by the enum it belongs to.
"""
function cppvalue(::Type{T}, I::CppInterpreter=@__INSTANCE__) where {T<:CppEnum{S,N}} where {S,N}
    decl = lookup(I, string(S), EnumLookup())
    jlty = to_jl(to_cpp(decl, I))
    U = machine_type_of(jlty)
    return CppEnumValue{get_s(jlty),U}(convert(U, getEnumConstantDeclValue(EnumConstantDecl(decl))))
end

"""
    cppvalue(::Type{CppEnumType{S,U}}, I) -> CppEnumValue
A zero-initialized value of the enum type named `S`.
"""
function cppvalue(::Type{CppEnumType{S,U}}, I::CppInterpreter=@__INSTANCE__) where {S,U}
    jlty = to_jl(to_cpp(CppEnumType{S,U}, I))
    M = machine_type_of(jlty)
    return CppEnumValue{get_s(jlty),M}(zero(M))
end

"""
    @cppenum x
The value of a C++ enumerator or a zero-initialized value of an enum type.

    @cppenum CppEnum("red")        # the enumerator `red`
    @cppenum CppEnumType("color")  # a zero-initialized `color`
"""
macro cppenum(x)
    @gensym CC_INSTANCE
    return esc(quote
                   local $CC_INSTANCE = CppCall.get_instance($__module__)
                   CppCall.cppvalue($x, $CC_INSTANCE)
               end)
end

# Heap objects ------------------------------------------------------------------------------

function cppnew(::Type{T}, I::CppInterpreter=@__INSTANCE__) where {T<:CppType{S,Q}} where {S,Q}
    s = string(S)
    haskey(DEFAULT_TYPE_MAPPING, s) && return cppnew(DEFAULT_TYPE_MAPPING[s], I)
    clty = to_cpp(T, I)
    return reinterpret(Ptr{to_jl(clty)}, cppconstruct(I, clty))
end

function cppnew(::Type{T}, I::CppInterpreter=@__INSTANCE__) where {T<:CppTemplate}
    clty = instantiate(T, I)
    return reinterpret(Ptr{to_jl(clty)}, cppconstruct(I, clty))
end

function cppnew(::Type{T}, I::CppInterpreter=@__INSTANCE__) where {T<:BuiltinTypes}
    clty = to_cpp(T, I)
    return reinterpret(Ptr{to_jl(clty)}, cppconstruct(I, clty))
end

"""
    @cppnew cppty
Allocate a value-initialized C++ object of type `cppty` on the C++ heap and return a pointer
to it. Release it with [`@cppdelete`](@ref).
"""
macro cppnew(cppty)
    @gensym CC_INSTANCE
    return esc(quote
                   local $CC_INSTANCE = CppCall.get_instance($__module__)
                   CppCall.cppnew($cppty, $CC_INSTANCE)
               end)
end

function cppdelete(x::Ptr, I::CppInterpreter=@__INSTANCE__)
    return cppdeallocate(I, reinterpret(Ptr{Cvoid}, x))
end

"""
    @cppdelete ptr
Release storage obtained from `@cppnew` or `@ctor`. The destructor is not run.
"""
macro cppdelete(obj)
    @gensym CC_INSTANCE
    return esc(quote
                   local $CC_INSTANCE = CppCall.get_instance($__module__)
                   CppCall.cppdelete($obj, $CC_INSTANCE)
               end)
end

# Type spellings ----------------------------------------------------------------------------

"""
    @cpp_str -> CppType

Construct a `CppType` with optional qualifiers marked by the flags `c`, `v`, `cv`.
"""
macro cpp_str(name::AbstractString, flags...)
    qualifier = :(CppCall.U)
    if !isempty(flags)
        flag = first(flags)
        qualifier = flag == "cv" ? :(CppCall.CV) :
                    flag == "c" ? :(CppCall.C) :
                    flag == "v" ? :(CppCall.V) : :(CppCall.U)
    end
    return :(CppType(strip($name), $qualifier))
end

macro qualty_str(name::AbstractString, flags...)
    qualifier = :(CppCall.U)
    if !isempty(flags)
        flag = first(flags)
        qualifier = flag == "cv" ? :(CppCall.CV) :
                    flag == "c" ? :(CppCall.C) :
                    flag == "v" ? :(CppCall.V) : :(CppCall.U)
    end
    @gensym CC_INSTANCE
    return esc(quote
                   local $CC_INSTANCE = CppCall.get_instance($__module__)
                   CppCall.to_cpp(CppType{Symbol($name),$qualifier}, $CC_INSTANCE)
               end)
end
