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

is_convertible(::Type{S}, ::Type{T}) where {T,S} = false
is_convertible(::Type{S}, ::Type{T}) where {N,T,S<:CppObject{T,N}} = true

is_convertible(::Type{S}, ::Type{CppRef{T}}) where {N,T,S<:CppObject{T,N}} = true
# is_convertible(::Type{S}, ::Type{CppRef{T}}) where {N,T<:BuiltinTypes,S<:CppObject{T,N}} = true

is_convertible(::Type{S}, ::Type{CppCPtr{T}}) where {N,T,S<:CppObject{Ptr{T},N}} = true
is_convertible(::Type{S}, ::Type{CppCPtr{T}}) where {N,NP,T,U<:CppObject{T,N},S<:CppObject{Ptr{U},NP}} = true
is_convertible(::Type{S}, ::Type{CppCPtr{T}}) where {N,NP,T,U<:CppObject{T,N},S<:CppObject{CppCPtr{U},NP}} = true

is_convertible(::Type{S}, ::Type{Ptr{T}}) where {N,T,S<:CppObject{CppCPtr{T},N}} = true
is_convertible(::Type{S}, ::Type{Ptr{T}}) where {N,NP,T,U<:CppObject{T,N},S<:CppObject{Ptr{U},NP}} = true
