"""
    cppconvert(T, x)
Convert `x` to a value to be passed to C++ code as type `T`.
"""
function cppconvert end

"""
    is_convertible(from, to)
Check if type `from` can be converted to type `to`.
"""
function is_convertible end

is_convertible(::Type{F}, ::Type{T}) where {F,T} = false
is_convertible(::Type{T}, ::Type{T}) where {T} = true

is_convertible(::Type{T}, ::Type{CppRef{T}}) where {T} = true
# is_convertible(::Type{S}, ::Type{CppRef{T}}) where {N,T<:BuiltinTypes,S<:CppObject{T,N}} = true

is_convertible(::Type{S}, ::Type{CppPtr{Q,T}}) where {Q,N,T,U<:CppObject{T,N},S<:Ref{U}} = true
is_convertible(::Type{S}, ::Type{Ptr{T}}) where {N,T,U<:CppObject{T,N},S<:Ref{U}} = true
