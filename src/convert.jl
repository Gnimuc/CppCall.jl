const BuiltinTypeMap = [
    ("void", :Cvoid),
    ("char", :Cchar),
    ("unsigned char", :Cuchar),
    ("signed char", :Cchar),
    ("short", :Cshort),
    ("unsigned short", :Cushort),
    ("int", :Cint),
    ("unsigned int", :Cuint),
    ("long", :Clong),
    ("unsigned long", :Culong),
    ("long long", :Clonglong),
    ("unsigned long long", :Culonglong),
    ("float", :Cfloat),
    ("double", :Cdouble),
    ("_Bool", :Bool),
]

"""
    cppconvert(T, x)
Convert `x` to a value to be passed to C++ code as type `T`.
"""
function cppconvert end

# | Variable Types |                         Argument Types                                |
# |                | T | const T| T& | const T& | T* | const T* | T* const | const T* const|
# |----------------|---|--------|----|----------|----|----------|----------|---------------|
# | T              | ⭕️|   ⭕   | ⭕ |    ⭕️   | ❌ |    ❌    |    ❌    |      ❌       |
# | const T        | ⭕️|   ⭕   | ❌ |    ⭕   | ❌ |    ❌    |    ❌    |      ❌       |
# | T&             | ⭕️|   ⭕   | ⭕ |    ⭕️   | ❌ |    ❌    |    ❌    |      ❌       |
# | const T&       | ⭕️|   ⭕   | ❌ |    ⭕   | ❌ |    ❌    |    ❌    |      ❌       |
# | T*             | ❌|   ❌   | ❌ |    ❌   | ⭕ |    ⭕    |    ⭕    |      ⭕       |
# | const T*       | ❌|   ❌   | ❌ |    ❌   | ❌ |    ⭕    |    ❌    |      ⭕       |
# | T* const       | ❌|   ❌   | ❌ |    ❌   | ⭕ |    ⭕    |    ⭕    |      ⭕       |
# | const T* const | ❌|   ❌   | ❌ |    ❌   | ❌ |    ⭕    |    ❌    |      ⭕       |

"""
    is_convertible(from, to)
Check if type `from` can be converted to type `to`.
"""
function is_convertible end

is_convertible(::Type{S}, ::Type{T}) where {T,S} = false
is_convertible(::Type{S}, ::Type{T}) where {N,T,S<:CppObject{T,N}} = true

# ignore const qualifier for pointer types in the function argument
is_convertible(::Type{S}, ::Type{CppCPtr{T}}) where {T,S} = is_convertible(S, Ptr{T})

# T -> const T
is_convertible(::Type{S}, ::Type{CppType{T,C}}) where {N,T,S<:CppObject{T,N}} = true
for (cppty, jlty) in BuiltinTypeMap
    @eval is_convertible(::Type{S}, ::Type{CppType{Symbol($cppty),C}}) where {N,S<:CppObject{$jlty,N}} = true
end

# T -> T&
is_convertible(::Type{S}, ::Type{CppRef{T}}) where {N,T,S<:CppObject{T,N}} = true

# T -> const T&
is_convertible(::Type{S}, ::Type{CppRef{CppType{T,C}}}) where {N,T,S<:CppObject{CppType{T,U},N}} = true
for (cppty, jlty) in BuiltinTypeMap
    @eval is_convertible(::Type{S}, ::Type{CppRef{CppType{Symbol($cppty),C}}}) where {N,S<:CppObject{$jlty,N}} = true
end

# const T -> T
is_convertible(::Type{S}, ::Type{T}) where {N,T,S<:CppObject{CppType{T,C},N}} = true
for (cppty, jlty) in BuiltinTypeMap
    @eval is_convertible(::Type{S}, ::Type{$jlty}) where {N,S<:CppObject{CppType{Symbol($cppty),C},N}} = true
end

# const T& -> const T&, T& -> T&
is_convertible(::Type{S}, ::Type{CppRef{T}}) where {N,T,S<:CppObject{CppRef{T},N}} = true
is_convertible(::Type{S}, ::Type{CppRef{T}}) where {N,NR,T,V<:CppObject{T,N},S<:CppObject{CppRef{V},NR}} = true

# T& -> T, const T& -> const T
is_convertible(::Type{S}, ::Type{T}) where {N,T,S<:CppObject{CppRef{T},N}} = true
is_convertible(::Type{S}, ::Type{T}) where {N,NR,T,V<:CppObject{T,N},S<:CppObject{CppRef{V},NR}} = true

# T& -> const T
is_convertible(::Type{S}, ::Type{CppType{T,C}}) where {N,T,S<:CppObject{CppRef{T},N}} = true
for (cppty, jlty) in BuiltinTypeMap
    @eval is_convertible(::Type{S}, ::Type{CppType{Symbol($cppty),C}}) where {N,S<:CppObject{CppRef{$jlty},N}} = true
end
is_convertible(::Type{S}, ::Type{CppType{T,C}}) where {N,NR,T,V<:CppObject{T,N},S<:CppObject{CppRef{V},NR}} = true
for (cppty, jlty) in BuiltinTypeMap
    @eval is_convertible(::Type{S}, ::Type{CppType{Symbol($cppty),C}}) where {N,NR,V<:CppObject{$jlty,N}, S<:CppObject{CppRef{V},NR}} = true
end

# T& -> const T&
is_convertible(::Type{S}, ::Type{CppRef{CppType{T,C}}}) where {N,T,S<:CppObject{CppRef{CppType{T,U}},N}} = true
for (cppty, jlty) in BuiltinTypeMap
    @eval is_convertible(::Type{S}, ::Type{CppRef{CppType{Symbol($cppty),C}}}) where {N,S<:CppObject{CppRef{$jlty},N}} = true
end
is_convertible(::Type{S}, ::Type{CppRef{CppType{T,C}}}) where {N,NR,T,V<:CppObject{CppType{T,U},N},S<:CppObject{CppRef{V},NR}} = true
for (cppty, jlty) in BuiltinTypeMap
    @eval is_convertible(::Type{S}, ::Type{CppRef{CppType{Symbol($cppty),C}}}) where {N,NR,V<:CppObject{$jlty,N},S<:CppObject{CppRef{V},NR}} = true
end

# const T& -> T
is_convertible(::Type{S}, ::Type{T}) where {N,T,S<:CppObject{CppRef{CppType{T,C}},N}} = true
for (cppty, jlty) in BuiltinTypeMap
    @eval is_convertible(::Type{S}, ::Type{$jlty}) where {N,S<:CppObject{CppRef{CppType{Symbol($cppty),C}},N}} = true
end
is_convertible(::Type{S}, ::Type{T}) where {N,NR,T,V<:CppObject{CppType{T,C},N},S<:CppObject{CppRef{V},NR}} = true
for (cppty, jlty) in BuiltinTypeMap
    @eval is_convertible(::Type{S}, ::Type{$jlty}) where {N,NR,V<:CppObject{CppType{Symbol($cppty),C},N},S<:CppObject{CppRef{V},NR}} = true
end

# T* -> const T*
is_convertible(::Type{S}, ::Type{Ptr{CppType{T,C}}}) where {N,T,S<:CppObject{Ptr{CppType{T,U}},N}} = true
for (cppty, jlty) in BuiltinTypeMap
    @eval is_convertible(::Type{S}, ::Type{Ptr{CppType{Symbol($cppty),C}}}) where {N,S<:CppObject{Ptr{$jlty},N}} = true
end
is_convertible(::Type{S}, ::Type{Ptr{CppType{T,C}}}) where {N,NR,T,V<:CppObject{CppType{T,U},N},S<:CppObject{Ptr{V},NR}} = true
for (cppty, jlty) in BuiltinTypeMap
    @eval is_convertible(::Type{S}, ::Type{Ptr{CppType{Symbol($cppty),C}}}) where {N,NR,V<:CppObject{$jlty,N},S<:CppObject{Ptr{V},NR}} = true
end

# T* -> T*, const T* -> const T*
is_convertible(::Type{S}, ::Type{Ptr{T}}) where {N,T,S<:CppObject{Ptr{T},N}} = true
is_convertible(::Type{S}, ::Type{Ptr{T}}) where {N,NR,T,V<:CppObject{T,N},S<:CppObject{Ptr{V},NR}} = true

# T* const -> T*, const T* const -> const T*
is_convertible(::Type{S}, ::Type{Ptr{T}}) where {N,T,S<:CppObject{CppCPtr{T},N}} = true
is_convertible(::Type{S}, ::Type{Ptr{T}}) where {N,NR,T,V<:CppObject{T,N},S<:CppObject{CppCPtr{V},NR}} = true
