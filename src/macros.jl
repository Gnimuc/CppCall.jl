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
                   CppCall.undo($CC_INSTANCE.interpreter, $i)
               end)
end

function cppinit(::Type{T}, I::CppInterpreter=@__INSTANCE__) where {T<:Union{BuiltinTypes,CppType{S,Q}}} where {S,Q}
    clty = to_cpp(T, I)
    jlty = to_jl(clty)
    sz = size_of(get_ast_context(I), clty)
    return CppObject{jlty,sz}()
end

"""
    @cppinit cppty
Create a C++ object of type `cppty` with zero initialized values.
"""
macro cppinit(cppty)
    @gensym CC_INSTANCE
    return esc(quote
                   local $CC_INSTANCE = CppCall.get_instance($__module__)
                   CppCall.cppinit($cppty, $CC_INSTANCE)
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

"""
    @ptr obj
Create a C++ object that represents a `Unqualified`-pointer to `obj`.
"""
macro ptr(obj)
    return esc(:(CppObject{Ptr}($obj)))
end

"""
    @cptr obj
Create a C++ object that represents a `Const_Qualified`-pointer to `obj`.
"""
macro cptr(obj)
    return esc(:(CppObject{CppCPtr}($obj)))
end

"""
    @vptr obj
Create a C++ object that represents a `Volatile_Qualified`-pointer to `obj`.
"""
macro vptr(obj)
    return esc(:(CppObject{CppVPtr}($obj)))
end

"""
    @cvptr obj
Create a C++ object that represents a `Const_Volatile_Qualified`-pointer to `obj`.
"""
macro cvptr(obj)
    return esc(:(CppObject{CppCVPtr}($obj)))
end

"""
    @ref obj
Create a C++ object that represents a reference to `obj`.
"""
macro ref(obj)
    @gensym CC_VAR CC_X
    return esc(quote
                   $CC_VAR = CppObject{CppRef}($obj)
                   finalizer($CC_VAR) do $CC_X
                       CppCall.gcuse($obj)
                       $CC_X
                   end
                   $CC_VAR
               end)
end

_get_scope(::Type{CppType{S,Q}}, I::CppInterpreter=@__INSTANCE__) where {S,Q} = make_scope(lookup(I, string(S)), I)

function cppnew(::Type{T}, I::CppInterpreter=@__INSTANCE__) where {T<:CppType{S,Q}} where {S,Q}
    s = string(S)
    haskey(DEFAULT_TYPE_MAPPING, s) && return cppnew(DEFAULT_TYPE_MAPPING[s], I)
    jlty = to_jl(to_cpp(T, I))
    ptr = construct(_get_scope(T, I))
    N = Core.sizeof(Int)
    return CppObject{Ptr{jlty},N}(reinterpret(NTuple{N,UInt8}, ptr))
end

function cppnew(::Type{T}, I::CppInterpreter=@__INSTANCE__) where {T<:BuiltinTypes}
    clty = to_cpp(T, I)
    jlty = to_jl(clty)
    sz = size_of(get_ast_context(I), clty)
    ptr = allocate(sz)
    N = Core.sizeof(Int)
    return CppObject{Ptr{jlty},N}(reinterpret(NTuple{N,UInt8}, ptr))
end

"""
    @cppnew cppty
Allocate a C++ object that is of type `cppty` and return a pointer `CppObject`.
"""
macro cppnew(cppty)
    @gensym CC_INSTANCE
    return esc(quote
                   local $CC_INSTANCE = CppCall.get_instance($__module__)
                   CppCall.cppnew($cppty, $CC_INSTANCE)
               end)
end


cppdelete(x::CppObject{Ptr{T},N}) where {T,N} = deallocate(convert(Ptr{Cvoid}, x))

"""
    @cppdelete obj
Deallocate/destruct the `obj` which is allocated by `@cppnew`.
"""
macro cppdelete(obj)
    return esc(:(CppCall.cppdelete($obj)))
end

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
