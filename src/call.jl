nns(expr::Symbol) = string(expr)

function nns(expr::Expr)
    if Meta.isexpr(expr, :call)
        return string(expr.args[1])
    elseif Meta.isexpr(expr, :(::))
        length(expr.args) == 1 && return "::" * nns(expr.args[1])
        return nns(expr.args[1]) * "::" * nns(expr.args[2])
    else
        @warn "unknown expression pattern: $expr"
        return string(expr)
    end
end

# @fcall ::x::y::z(a, b)
# @fcall x::y::z(a::T, b::S)
macro fcall(expr)
    func_name = nns(expr)
    call_expr = expr
    while !Meta.isexpr(call_expr, :call)
        call_expr = call_expr.args[end]
        call_expr isa Symbol && break
    end
    if !Meta.isexpr(call_expr, :call)
        throw(ArgumentError("@fcall has to take a function call"))
    end

    args = map(x -> Meta.isexpr(x, :(::)) ? x.args[1] : x, call_expr.args[2:end])
    annots = map(x -> Meta.isexpr(x, :(::)) ? x.args[2] : :nothing, call_expr.args[2:end])

    @gensym CC_ID CC_CTX CC_FUNC
    return esc(quote
                   local $CC_ID = CppCall.get_instance_id($__module__)
                   local $CC_CTX = CppCall.CppContext{$CC_ID}()
                   local $CC_FUNC = CppCall.CppIdentifier{Symbol($func_name)}()
                   CppCall.cppgfcall($CC_CTX, $CC_FUNC, $(args...), $(annots...))
               end)
end

struct CppContext{ID} end
struct CppIdentifier{S} end

@generated function cppgfcall(::CppContext{ID}, ::CppIdentifier{S}, params...) where {ID,S}
    I = CPPCALL_INSTANCES[ID]
    candidates = lookup(I, string(S), FuncOverloadingLookup())
    func = dispatch(I, candidates, params)
    isnothing(func) &&
        throw(ArgumentError("no matching function for call to `$(err_signature(first(candidates), params))`"))
    scope = make_scope(func, I)
    clty = get_return_type(clty_to_jlty(get_type_ptr(to_cpp(func, I)))) # TODO: cache func lookup results
    retty = to_jl(clty)
    if retty == Cvoid
        return quote
            Base.@_inline_meta
            cppinvoke($scope, C_NULL, C_NULL, params...)
        end
    elseif retty <: CppRef
        return quote
            Base.@_inline_meta
            ret = CppObject{$retty}()
            cppinvoke($scope, C_NULL, ret, params...)
            return ret
        end
    else
        sz = size_of(get_ast_context(I), clty)
        return quote
            Base.@_inline_meta
            ret = CppObject{$retty,$sz}()
            cppinvoke($scope, C_NULL, ret, params...)
            return ret
        end
    end
end

# @ctor cppty()
# @ctor nns::cppty()
macro ctor(expr)
    type_name = nns(expr)
    call_expr = expr
    while !Meta.isexpr(call_expr, :call)
        call_expr = call_expr.args[end]
        call_expr isa Symbol && break
    end
    if !Meta.isexpr(call_expr, :call)
        throw(ArgumentError("@ctor has to take a function call"))
    end

    args = map(x -> Meta.isexpr(x, :(::)) ? x.args[1] : x, call_expr.args[2:end])

    @gensym CC_ID CC_CTX CC_TY
    return esc(quote
                   local $CC_ID = CppCall.get_instance_id($__module__)
                   local $CC_CTX = CppCall.CppContext{$CC_ID}()
                   local $CC_TY = CppCall.CppIdentifier{Symbol($type_name)}()
                   CppCall.cppctorcall($CC_CTX, $CC_TY, $(args...))
               end)
end

@generated function cppctorcall(::CppContext{ID}, ::CppIdentifier{S}, params...) where {ID,S}
    I = CPPCALL_INSTANCES[ID]
    candidates = lookup(I, string(S), FuncOverloadingLookup())
    record = dispatch(I, candidates, params)
    isnothing(record) && throw(ArgumentError("no default constructor for `$S`"))
    ctor = CC.LookupDefaultConstructor(get_sema(I), CXXRecordDecl(record.ptr))
    scope = make_scope(ctor, I)
    retty = to_jl(to_cpp(record, I))
    return quote
        Base.@_inline_meta
        ret = CppObject{Ptr{$retty},Core.sizeof(Int)}()
        cppinvoke($scope, C_NULL, ret, params...)
        return ret
    end
end

# @mcall obj.foo(a, b)
# @mcall obj.foo(a::T, b::S)
# @mcall ptr->foo(a, b)
# @mcall ptr->foo(a::T, b::S)
macro mcall(expr)
    local obj_sym, call_expr, func_name
    if Meta.isexpr(expr, :->)
        obj_sym, block_expr = expr.args
        call_expr = last(block_expr.args)
        func_name = string(call_expr.args[1])
    elseif Meta.isexpr(expr, :call) && Meta.isexpr(first(expr.args), :.)
        obj_sym, node = first(expr.args).args
        call_expr = expr
        func_name = string(node.value)
    else
        throw(ArgumentError("@mcall has to take a function call"))
    end

    args = map(x -> Meta.isexpr(x, :(::)) ? x.args[1] : x, call_expr.args[2:end])
    annots = map(x -> Meta.isexpr(x, :(::)) ? x.args[2] : :nothing, call_expr.args[2:end])

    @gensym CC_ID CC_CTX CC_METHOD
    return esc(quote
                   local $CC_ID = CppCall.get_instance_id($__module__)
                   local $CC_CTX = CppCall.CppContext{$CC_ID}()
                   local $CC_METHOD = CppCall.CppIdentifier{Symbol($func_name)}()
                   CppCall.cppmtcall($CC_CTX, $CC_METHOD, $obj_sym, $(args...), $(annots...))
               end)
end

#! format: off
get_class(::Type{T}) where {T} = error("invalid object type: $T, expected a `CppObject` that represents a C++ object or a pointer to a C++ object")
get_class(::Type{T}) where {S,Q,T<:CppType{S,Q}} = string(S)
get_class(::Type{S}) where {N,T<:CppType,S<:CppObject{T,N}} = get_class(T)
get_class(::Type{S}) where {N,T<:CppType,S<:CppObject{Ptr{T},N}} = get_class(T)
get_class(::Type{S}) where {N,T<:CppType,S<:CppObject{CppCPtr{T},N}} = get_class(T)
get_class(::Type{S}) where {N,NR,T,V<:CppObject{T,N},S<:CppObject{Ptr{V},NR}} = get_class(T)
get_class(::Type{S}) where {N,NR,T,V<:CppObject{T,N},S<:CppObject{CppCPtr{V},NR}} = get_class(T)

get_class(::Type{S}) where {N,Q,T<:CppRef{Q},S<:CppObject{T,N}} = get_class(CppObject{Q,N})

get_class(::Type{Cvoid}) = "void"
get_class(::Type{Cchar}) = "char"
get_class(::Type{Cuchar}) = "unsigned char"
get_class(::Type{Cshort}) = "short"
get_class(::Type{Cushort}) = "unsigned short"
get_class(::Type{Cint}) = "int"
get_class(::Type{Cuint}) = "unsigned int"
get_class(::Type{Clong}) = "long"
get_class(::Type{Culong}) = "unsigned long"
if Clonglong !== Clong
    get_class(::Type{Clonglong}) = "long long"
    get_class(::Type{Culonglong}) = "unsigned long long"
end
get_class(::Type{Cfloat}) = "float"
get_class(::Type{Cdouble}) = "double"
get_class(::Type{Bool}) = "_Bool"

function get_class(::Type{CppTemplate{T,Targs}}) where {S,Q,T<:CppType{S,Q},Targs}
    return string(S) * "<" * join(map(x -> get_class(x), Targs.types), ",") * ">"
end
get_class(::Type{S}) where {N,T<:CppTemplate,S<:CppObject{T,N}} = get_class(T)
get_class(::Type{S}) where {N,T<:CppTemplate,S<:CppObject{Ptr{T},N}} = get_class(T)
get_class(::Type{S}) where {N,T<:CppTemplate,S<:CppObject{CppCPtr{T},N}} = get_class(T)
# get_class(::Type{S}) where {N,NR,T<:CppTemplate,V<:CppObject{T,N},S<:CppObject{Ptr{V},NR}} = get_class(T)
# get_class(::Type{S}) where {N,NR,T<:CppTemplate,V<:CppObject{T,N},S<:CppObject{CppCPtr{V},NR}} = get_class(T)
#! format: on

@generated function cppmtcall(::CppContext{ID}, ::CppIdentifier{S}, obj::T, params...) where {ID,S,T}
    I = CPPCALL_INSTANCES[ID]
    n = get_class(T) * "::" * string(S)
    candidates = lookup(I, n, FuncOverloadingLookup())
    func = dispatch(I, candidates, params)
    isnothing(func) &&
        throw(ArgumentError("no matching function for call to `$(err_signature(first(candidates), params))`"))
    scope = make_scope(func, I)
    clty = get_return_type(clty_to_jlty(get_type_ptr(to_cpp(func, I)))) # TODO: cache func lookup results
    retty = to_jl(clty)
    if retty == Cvoid
        return quote
            Base.@_inline_meta
            cppinvoke($scope, obj, C_NULL, params...)
        end
    elseif retty <: CppRef
        return quote
            Base.@_inline_meta
            ret = CppObject{$retty}()
            cppinvoke($scope, obj, ret, params...)
            return ret
        end
    else
        sz = size_of(get_ast_context(I), clty)
        return quote
            Base.@_inline_meta
            ret = CppObject{$retty,$sz}()
            cppinvoke($scope, obj, ret, params...)
            return ret
        end
    end
end

function dispatch(I::CppInterpreter, candidates::Vector{NamedDecl}, params)
    func = nothing
    no_throw = false
    for x in candidates
        ty = clty_to_jlty(get_type_ptr(to_cpp(x, I)))
        dispatch(I, ty, params) || continue
        # FIXME: use OverloadCandidateSet
        if !isnothing(func)
            # skip noexcept methods
            ty_func = clty_to_jlty(get_type_ptr(to_cpp(func, I)))
            isNoThrow(ty_func) ⊻ isNoThrow(ty) || continue
            CC.dump(x)
            CC.dump(func)
            throw(ArgumentError("call of overloaded `$(err_signature(func, params))` is ambiguous."))
        end
        func = x
    end
    return func
end

_unwrap(::Type{Type{T}}) where {T} = T

@inline function dispatch(I::CppInterpreter, func::FunctionProtoType, params)
    argnum = length(params) ÷ 2
    get_param_num(func) != argnum && return false
    for i = 1:argnum
        argty = params[i]
        annotty = params[i + argnum]
        @assert argty <: CppObject "argument types should be of type `CppObject`, got a $argty"
        fromty = argty
        clty = get_param_type(func, i)
        toty = to_jl(clty)
        annotty != Nothing && toty != _unwrap(annotty) && return false
        !is_convertible(fromty, toty) && return false
    end
    return true
end

@inline dispatch(I::CppInterpreter, x::RecordType, params) = true # constructor or destructor

@inline function cppinvoke(x::CXScope, self::Ptr{Cvoid}, result::Union{CppObject,Ptr}, params...)
    ret_ptr = unsafe_pointer_rt(result)
    arg_ptrs = [unsafe_pointer(params[i]) for i = 1:(length(params) ÷ 2)]
    return GC.@preserve result params invoke(x, ret_ptr, arg_ptrs, self)
end

@inline function cppinvoke(x::CXScope, self::S, result::Union{CppObject,Ptr},
                           params...) where {N,T<:Union{CppType,CppTemplate},S<:CppObject{T,N}}
    ret_ptr = unsafe_pointer_rt(result)
    arg_ptrs = [unsafe_pointer(params[i]) for i = 1:(length(params) ÷ 2)]
    self_ptr = unsafe_pointer(self)
    return GC.@preserve self result params invoke(x, ret_ptr, arg_ptrs, self_ptr)
end

@inline function cppinvoke(x::CXScope, self::S, result::Union{CppObject,Ptr},
                           params...) where {N,T,S<:CppObject{Ptr{T},N}}
    ret_ptr = unsafe_pointer_rt(result)
    arg_ptrs = [unsafe_pointer(params[i]) for i = 1:(length(params) ÷ 2)]
    self_ptr = reinterpret(Ptr{Cvoid}, self.data)
    return GC.@preserve self result params invoke(x, ret_ptr, arg_ptrs, self_ptr)
end

@inline function cppinvoke(x::CXScope, self::S, result::Union{CppObject,Ptr},
                           params...) where {N,T,S<:CppObject{CppRef{T},N}}
    ret_ptr = unsafe_pointer_rt(result)
    arg_ptrs = [unsafe_pointer(params[i]) for i = 1:(length(params) ÷ 2)]
    self_ptr = reinterpret(Ptr{Cvoid}, self.data)
    return GC.@preserve self result params invoke(x, ret_ptr, arg_ptrs, self_ptr)
end
