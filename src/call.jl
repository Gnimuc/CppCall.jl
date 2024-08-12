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

# @fcall ::x::y::z()
# @fcall x::y::z()
macro fcall(expr)
    if !Meta.isexpr(expr, :(=))
        ret = nothing
        func_expr = expr
    else
        ret, func_expr = expr.args
    end

    func_name = nns(func_expr)

    call_expr = func_expr
    while !Meta.isexpr(call_expr, :call)
        call_expr = call_expr.args[end]
        call_expr isa Symbol && break
    end
    if !Meta.isexpr(call_expr, :call)
        throw(ArgumentError("@fcall has to take a function call"))
    end

    args = call_expr.args[2:end]

    result = isnothing(ret) ? C_NULL : ret

    @gensym CC_ID CC_CTX CC_FUNC
    return esc(quote
                   local $CC_ID = CppCall.get_instance_id($__module__)
                   local $CC_CTX = CppCall.CppContext{$CC_ID}()
                   local $CC_FUNC = CppCall.CppIdentifier{Symbol($func_name)}()
                   CppCall.cppgfcall($CC_CTX, $CC_FUNC, $result, $(args...))
               end)
end

struct CppContext{ID} end
struct CppIdentifier{S} end

@generated function cppgfcall(::CppContext{ID}, ::CppIdentifier{S}, result, args...) where {ID,S}
    I = CPPCALL_INSTANCES[ID]
    candidates = lookup(I, string(S), FuncOverloadingLookup())
    func = dispatch(I, candidates, args)
    isnothing(func) && throw(ArgumentError("no matching function call for argument types: $args"))
    scope = make_scope(func, I)
    return quote
        Base.@_inline_meta
        return cppinvoke($scope, C_NULL, result, args...)
    end
end

function dispatch(I::CppInterpreter, candidates::Vector{NamedDecl}, args)
    func = nothing
    for x in candidates
        ty = clty_to_jlty(get_type_ptr(to_cpp(x, I)))
        dispatch(ty, args) || continue
        if !isnothing(func)
            CC.dump(x)
            CC.dump(func)
            throw(ArgumentError("ambiguous function call `$(CC.getName(x))` with argument types: $args"))
        end
        func = x
    end
    return func
end

@inline function dispatch(func::FunctionProtoType, args)
    get_param_num(func) != length(args) && return false
    for i = 1:length(args)
        argty = args[i]
        @assert argty <: CppObject "argument types should be `CppObject`, got a $argty"
        fromty = argty
        clty = get_param_type(func, i)
        toty = to_jl(clty)
        # @show fromty, toty
        !is_convertible(fromty, toty) && return false
    end
    return true
end

@inline function cppinvoke(x::CXScope, self::Ptr{Cvoid}, result::Union{CppObject,Ptr}, args...)
    ret_ptr = unsafe_pointer(result)
    arg_ptrs = [unsafe_pointer(x) for x in args]
    GC.@preserve result args invoke(x, ret_ptr, arg_ptrs, self)
end
