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

function split_call(expr, what::AbstractString)
    call_expr = expr
    while !Meta.isexpr(call_expr, :call)
        call_expr = call_expr.args[end]
        call_expr isa Symbol && break
    end
    Meta.isexpr(call_expr, :call) || throw(ArgumentError("$what has to take a function call"))
    args = map(x -> Meta.isexpr(x, :(::)) ? x.args[1] : x, call_expr.args[2:end])
    annots = map(x -> Meta.isexpr(x, :(::)) ? x.args[2] : :nothing, call_expr.args[2:end])
    return args, annots
end

# @fcall ::x::y::z(a, b)
# @fcall x::y::z(a::T, b::S)
macro fcall(expr)
    func_name = nns(expr)
    args, annots = split_call(expr, "@fcall")
    return esc(quote
                   CppCall.cppgfcall(CppCall.CppContext{$__module__}(),
                                     CppCall.CppIdentifier{Symbol($func_name)}(),
                                     $(args...), $(annots...))
               end)
end

# Parameterised by the *module*, which the macro knows at expansion time. Keying on an
# interpreter id instead would make this a runtime type and cost a dynamic dispatch per call.
struct CppContext{M} end
struct CppIdentifier{S} end

# @ctor cppty(a, b)
# @ctor nns::cppty(a::T, b::S)
macro ctor(expr)
    type_name = nns(expr)
    args, annots = split_call(expr, "@ctor")
    return esc(quote
                   CppCall.cppctorcall(CppCall.CppContext{$__module__}(),
                                       CppCall.CppIdentifier{Symbol($type_name)}(),
                                       $(args...), $(annots...))
               end)
end

# @mcall obj.foo(a, b)   -- a value or reference receiver
# @mcall ptr->foo(a, b)  -- a pointer receiver
macro mcall(expr)
    local obj_sym, call_expr, func_name, arrow
    if Meta.isexpr(expr, :->)
        obj_sym, block_expr = expr.args
        call_expr = last(block_expr.args)
        func_name = string(call_expr.args[1])
        arrow = true
    elseif Meta.isexpr(expr, :call) && Meta.isexpr(first(expr.args), :.)
        obj_sym, node = first(expr.args).args
        call_expr = expr
        func_name = string(node.value)
        arrow = false
    else
        throw(ArgumentError("@mcall has to take a function call"))
    end

    args, annots = split_call(call_expr, "@mcall")
    return esc(quote
                   CppCall.cppmtcall(CppCall.CppContext{$__module__}(),
                                     CppCall.CppIdentifier{Symbol($func_name)}(), Val($arrow),
                                     $obj_sym, $(args...), $(annots...))
               end)
end

#! format: off
get_class(::Type{T}) where {T} = error("invalid object type: $T, expected a C++ object or a pointer to one")
get_class(::Type{T}) where {S,Q,T<:CppType{S,Q}} = string(S)
get_class(::Type{Ptr{T}}) where {T} = get_class(T)
get_class(::Type{CppPtr{Q,T}}) where {Q,T} = get_class(T)
get_class(::Type{CppRef{T}}) where {T} = get_class(T)
get_class(::Type{CppRvalueRef{T}}) where {T} = get_class(T)
get_class(::Type{CppValue{T,N}}) where {T,N} = get_class(T)
get_class(::Type{Base.RefValue{T}}) where {T} = get_class(T)

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
get_class(::Type{Bool}) = "bool"

function get_class(::Type{CppTemplate{T,Targs}}) where {S,Q,T<:CppType{S,Q},Targs}
    return string(S) * "<" * join(map(x -> get_class(x), Targs.types), ",") * ">"
end
#! format: on

# Overload resolution -----------------------------------------------------------------------
#
# Both sides of the question are asked in `to_jl`'s vocabulary: the C++ parameter is mapped
# through `to_jl` and compared against the Julia type the caller actually holds. That is the
# same vocabulary an `x::T` annotation is written in, so an annotation is simply an assertion
# that the parameter maps to exactly `T`.

# Lower is better. `nothing` means the candidate cannot be called at all.
const RANK_EXACT = 0   # identity, or a reference binding to a matching lvalue
const RANK_QUAL = 1    # adding const on the way in
const RANK_CONV = 3    # an arithmetic conversion
const RANK_REF = 4     # a Julia `Ref` standing in for a pointer parameter

"""
    describe_arg(::Type) -> (category, content)
Classify a Julia argument as a C++ value category plus the type it carries. `:prvalue` may
initialise a `const T&` or bind a `T&&`; `:lvalue` may bind a `T&`; `:xvalue` binds `T&&`.
"""
describe_arg(::Type{T}) where {T<:Number} = (:prvalue, T)
describe_arg(::Type{Base.RefValue{T}}) where {T} = (:lvalue, T)
describe_arg(::Type{CppRef{T}}) where {T} = (:lvalue, T)
describe_arg(::Type{CppRvalueRef{T}}) where {T} = (:xvalue, T)
describe_arg(::Type{Ptr{T}}) where {T} = (:pointer, T)
describe_arg(::Type{CppPtr{Q,T}}) where {Q,T} = (:pointer, T)
# the parameter side reaches this through `to_jl(::EnumType)`, which yields `CppEnumType`;
# describing the argument as `CppEnumValue` would make the two incomparable and reject every
# enum argument outright
describe_arg(::Type{CppEnumValue{S,U}}) where {S,U} = (:prvalue, CppEnumType{S,U})
describe_arg(::Type{CppValue{T,N}}) where {T,N} = (:prvalue, T)
describe_arg(::Type{Vector{T}}) where {T} = (:pointer, T)
describe_arg(::Type) = (:unknown, Nothing)

# The unqualified Julia type behind a possibly-const one, so `const int` and `int` compare equal
# on identity while `is_readonly` keeps the const distinction where it matters.
value_type(::Type{T}) where {T} = T
function value_type(::Type{CppType{S,Q}}) where {S,Q}
    m = machine_type(CppType{S,Unqualified})
    return m === nothing ? CppType{S,Unqualified} : m
end
# a class type needs the same treatment as a builtin, or an unqualified class pointer cannot
# bind a `const T *` parameter the way `int *` binds `const int *`
value_type(::Type{CppTemplate{CppType{S,Q},A}}) where {S,Q,A} = CppTemplate{CppType{S,Unqualified},A}
# an enum reaches the parameter side as `CppEnumType{S,U}` unqualified but as `CppType{S,Q}`
# when cv-qualified, so both have to normalise to the same thing or `const E&` rejects every
# enum argument
value_type(::Type{CppEnumType{S,U}}) where {S,U} = CppType{S,Unqualified}
# `Ref(@cppenum ...)` is how a mutable enum lvalue is spelled, so the stored value type has to
# normalise the same way. A `Ref{UInt32}` deliberately does NOT bind `color&` -- neither does an
# `unsigned int` lvalue in C++.
value_type(::Type{CppEnumValue{S,U}}) where {S,U} = CppType{S,Unqualified}
value_type(::Type{CppOpaque{S,Q}}) where {S,Q} = CppOpaque{S,Unqualified}

same_value(a, b) = value_type(a) === value_type(b)

"""
    binds(param, arg) -> Union{Tuple{Int,Int},Nothing}
Rank binding a caller-held `arg` type to a C++ parameter whose `to_jl` type is `param`.

Returns a conversion rank and a tiebreak. The tiebreak is C++'s reference-binding preference
([over.ics.rank]): when two candidates need the same conversions, binding an rvalue reference
to an rvalue beats binding an lvalue reference to it, which is why `v.push_back(5)` picks
`push_back(T&&)`. It is deliberately separate from the rank, because a by-value parameter and a
`const T&` parameter tie at rank 0 with no tiebreak between them -- and C++ calls that pair
ambiguous, as `f(int)` / `f(const int&)` shows.
"""
function binds(param, argty)
    cat, content = describe_arg(argty)
    cat === :unknown && return nothing

    if param <: CppRef
        W = unwrap_type(param)
        # a non-const reference cannot bind a const lvalue, and nothing binds a reference to a
        # different type -- C++ would have to materialise a temporary, which would not be the
        # caller's object any more
        if cat === :lvalue
            is_readonly(content) && !is_readonly(W) && return nothing
            return same_value(W, content) ? (RANK_EXACT, 0) : nothing
        elseif cat === :prvalue || cat === :xvalue
            # only `const T&` may bind a temporary
            is_readonly(W) || return nothing
            same_value(W, content) && return (RANK_EXACT, 0)
            return arithmetic(W, content) ? (RANK_CONV, 0) : nothing
        end
        return nothing
    elseif param <: CppRvalueRef
        W = unwrap_type(param)
        (cat === :prvalue || cat === :xvalue) || return nothing
        # binding an rvalue reference to an rvalue is preferred over any lvalue-reference binding
        return same_value(W, content) ? (RANK_EXACT, 1) : nothing
    elseif param <: Ptr || param <: CppPtr
        W = unwrap_type_ptr(param)
        if cat === :pointer
            is_readonly(content) && !is_readonly(W) && return nothing
            return same_value(W, content) ? (RANK_EXACT, 0) :
                   (content === Cvoid || W === Cvoid) ? (RANK_QUAL, 0) : nothing
        elseif cat === :lvalue
            # a Julia Ref is storage the caller owns; letting it stand in for `T*` is what
            # makes `@fcall f(Ref(x))` work, but it must lose to a real pointer
            is_readonly(content) && !is_readonly(W) && return nothing
            return same_value(W, content) ? (RANK_REF, 0) : nothing
        end
        return nothing
    else
        # by value
        same_value(param, content) && return (RANK_EXACT, 0)
        arithmetic(param, content) && return (RANK_CONV, 0)
        return nothing
    end
end

unwrap_type_ptr(::Type{Ptr{T}}) where {T} = T
unwrap_type_ptr(::Type{CppPtr{Q,T}}) where {Q,T} = T

arithmetic(a, b) = value_type(a) <: Number && value_type(b) <: Number

"""
    dispatch(I, candidates, params) -> decl or nothing
Pick the overload that best matches the call. Ties are reported as ambiguous, which is what
C++ does; an `x::T` annotation resolves them by naming the parameter type outright.
"""
function dispatch(I::CppInterpreter, candidates::Vector{T}, params) where {T<:AbstractNamedDecl}
    n = length(params) ÷ 2
    best, best_rank, ambiguous = nothing, nothing, false
    for x in candidates
        ty = clty_to_jlty(get_type_ptr(to_cpp(x, I)))
        v = viable(I, ty, params, n)
        v === nothing && continue
        r = (v[1], -v[2])
        if best_rank === nothing || r < best_rank
            best, best_rank, ambiguous = x, r, false
        elseif r == best_rank
            # two candidates the arguments cannot choose between. `noexcept` is not part of
            # the signature for this purpose, so a pair differing only in it is not a tie.
            ty_best = clty_to_jlty(get_type_ptr(to_cpp(best, I)))
            if isNoThrow(ty_best) ⊻ isNoThrow(ty)
                isNoThrow(ty_best) && (best = x)
            else
                ambiguous = true
            end
        end
    end
    ambiguous && throw(ArgumentError("call of overloaded `$(err_signature(best, params))` is ambiguous."))
    return best
end

"""
    viable(I, func, params, n) -> Union{Tuple{Int,Int},Nothing}
The total conversion rank and tiebreak score for calling `func` with the given argument types,
or `nothing` if it cannot be called at all.
"""
function viable(I::CppInterpreter, func, params, n::Int)
    get_param_num(func) == n || return nothing
    total = 0
    tie = 0
    for i = 1:n
        P = CC.getCanonicalType(get_param_type(func, i))
        pjl = to_jl(P)
        annot = params[i + n]
        if annot !== Nothing
            # an annotation names the parameter type exactly; it is an assertion, not a hint
            pjl === _unwrap(annot) || return nothing
        end
        b = binds(pjl, params[i])
        b === nothing && return nothing
        total += b[1]
        tie += b[2]
    end
    return (total, tie)
end

_unwrap(::Type{Type{T}}) where {T} = T

# Emitting the call -------------------------------------------------------------------------

"""
    call_site(I, decl, n, params; objexpr, objclass) -> Expr
Build the `ccall` that reaches `decl`'s trampoline, together with whatever wrapping turns the
raw result into the Julia value the caller should see.
"""
function call_site(I::CppInterpreter, decl, n::Int; objexpr=nothing, objclass::String="")
    f = CC.resolve(decl)
    ptypes = QualType[CC.getCanonicalType(get_param_type_of(f, i)) for i = 1:n]
    plan = plan_call(I, decl, ptypes; objclass)
    ret = plan.ret

    slots = plan.slots
    callargs = Any[]
    objexpr !== nothing && push!(callargs, :(Base.unsafe_convert(Ptr{Cvoid}, $objexpr)))
    ret.sret && push!(callargs, :__ret)
    for i = 1:n
        push!(callargs, :(marshal($(slots[end - n + i]), $(plan.targets[i]), params[$i])))
    end

    call = :(ccall($(plan.fptr), $(ret.slot), ($(slots...),), $(callargs...)))

    if ret.sret
        V = ret.jl
        return quote
            Base.@_inline_meta
            __ret = Ref($V())
            $call
            return __ret[]
        end
    end
    return quote
        Base.@_inline_meta
        return $(wrap_result(ret, call))
    end
end

get_param_type_of(f, i) = getType(CC.getParamDecl(f, i - 1))

# Turn the raw `ccall` result into the value the caller should hold.
function wrap_result(ret::RetMarshal, call)
    J = ret.jl
    J === Cvoid && return :($call; nothing)
    if J <: CppRef || J <: CppRvalueRef
        return :($J($call, nothing))
    elseif J <: CppEnumType
        S, U = J.parameters
        # QuoteNode, not `$S`: interpolating a Symbol into an expression makes it an
        # identifier to look up, not the literal symbol
        return :(CppEnumValue{$(QuoteNode(S)),$U}($call))
    elseif J <: Ptr || J <: CppPtr
        return :(reinterpret($J, $call))
    end
    return call
end

# Argument marshalling at the call site. The slot decides everything: a `Ptr{Cvoid}` slot means
# the callee wants an address, so the object is handed to `ccall` intact and `ccall` takes its
# address and roots it for the duration; any other slot means the callee wants the value, so an
# lvalue is loaded first.
@inline marshal(::Type{Ptr{Cvoid}}, ::Type{M}, x) where {M} = x
@inline marshal(::Type{Ptr{Cvoid}}, ::Type{M}, x::Base.RefValue) where {M} = x
@inline marshal(::Type{Ptr{Cvoid}}, ::Type{M}, x::AnyCppRef) where {M} = x
@inline marshal(::Type{Ptr{Cvoid}}, ::Type{M}, x::CppValue) where {M} = Ref(x)
# a prvalue has no address; give it one that lives exactly as long as the call
@inline marshal(::Type{Ptr{Cvoid}}, ::Type{M}, x::Number) where {M} = Ref(convert(M, x))
@inline marshal(::Type{Ptr{Cvoid}}, ::Type{M}, x::CppEnumValue) where {M} = Ref(convert(M, x.val))

@inline marshal(::Type{S}, ::Type{M}, x) where {S,M} = x
@inline marshal(::Type{S}, ::Type{M}, x::Base.RefValue) where {S,M} = x[]
@inline marshal(::Type{S}, ::Type{M}, x::AnyCppRef) where {S,M} = x[]
@inline marshal(::Type{S}, ::Type{M}, x::CppEnumValue) where {S,M} = x.val

@generated function cppgfcall(::CppContext{M}, ::CppIdentifier{S}, params...) where {M,S}
    I = get_instance(M)
    n = length(params) ÷ 2
    candidates = lookup(I, string(S), FuncOverloadingLookup())
    func = dispatch(I, candidates, params)
    isnothing(func) &&
        throw(ArgumentError("no matching function for call to `$(err_signature(first(candidates), params))`"))
    return call_site(I, func, n)
end

@generated function cppctorcall(::CppContext{M}, ::CppIdentifier{S}, params...) where {M,S}
    I = get_instance(M)
    n = length(params) ÷ 2
    candidates = lookup(I, string(S), ConstructorLookup())
    ctor = dispatch(I, candidates, params)
    isnothing(ctor) &&
        throw(ArgumentError("no matching constructor for `$(string(S))`"))
    return call_site(I, ctor, n)
end

@generated function cppmtcall(::CppContext{M}, ::CppIdentifier{S}, ::Val{Arrow}, obj::T,
                              params...) where {M,S,Arrow,T}
    # `.` is for a value or reference receiver and `->` is for a pointer, as in C++. Before the
    # redesign every object was an opaque box and the two were indistinguishable; now that a
    # constructor visibly hands back a pointer, using the wrong one reads as a type error.
    isptr = T <: Ptr || T <: CppPtr
    if Arrow && !isptr
        return :(throw(ArgumentError("`->` needs a pointer receiver; `$($T)` is a value -- use `.`")))
    elseif !Arrow && isptr
        return :(throw(ArgumentError("`.` needs a value receiver; `$($T)` is a pointer -- use `->`")))
    end
    I = get_instance(M)
    n = length(params) ÷ 2
    cls = get_class(T)
    candidates = lookup(I, cls * "::" * string(S), FuncOverloadingLookup())
    func = dispatch(I, candidates, params)
    isnothing(func) &&
        throw(ArgumentError("no matching member function for call to `$(cls)::$(string(S))`"))
    return call_site(I, func, n; objexpr=:obj, objclass=cls)
end
