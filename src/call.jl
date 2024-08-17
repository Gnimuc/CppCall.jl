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

function dispatch(I::CppInterpreter, candidates::Vector{NamedDecl}, params)
    func = nothing
    for x in candidates
        ty = clty_to_jlty(get_type_ptr(to_cpp(x, I)))
        dispatch(ty, params) || continue
        if !isnothing(func)
            CC.dump(x)
            CC.dump(func)
            throw(ArgumentError("call of overloaded `$(err_signature(func, params))` is ambiguous."))
        end
        func = x
    end
    return func
end

_unwrap(::Type{Type{T}}) where {T} = T

@inline function dispatch(func::FunctionProtoType, params)
    argnum = length(params) ÷ 2
    get_param_num(func) != argnum && return false
    for i = 1:argnum
        argty = params[i]
        annotty = params[i + argnum]
        @assert argty <: CppObject "argument types should be `CppObject`, got a $argty"
        fromty = argty
        clty = get_param_type(func, i)
        toty = to_jl(clty)
        annotty != Nothing && toty != _unwrap(annotty) && return false
        !is_convertible(fromty, toty) && return false
    end
    return true
end

@inline function cppinvoke(x::CXScope, self::Ptr{Cvoid}, result::Union{CppObject,Ptr}, params...)
    ret_ptr = unsafe_pointer_rt(result)
    arg_ptrs = [unsafe_pointer(params[i]) for i = 1:(length(params) ÷ 2)]
    return GC.@preserve result params invoke(x, ret_ptr, arg_ptrs, self)
end
