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

"""
    is_convertible(from, to)
Check if type `from` can be converted to type `to`.
"""
function is_convertible end

is_convertible(::Type{S}, ::Type{T}) where {T,S} = false
is_convertible(::Type{S}, ::Type{T}) where {N,T,S<:CppObject{T,N}} = true

# T -> const T&
is_convertible(::Type{S}, ::Type{CppRef{CppType{T,C}}}) where {N,T,S<:CppObject{CppType{T,U},N}} = true
for (cppty, jlty) in BuiltinTypeMap
    @eval is_convertible(::Type{S}, ::Type{CppRef{CppType{Symbol($cppty),C}}}) where {N,S<:CppObject{$jlty,N}} = true
end

# T& -> const T&
is_convertible(::Type{S}, ::Type{CppRef{CppType{T,C}}}) where {N,T,S<:CppObject{CppRef{CppType{T,U}},N}} = true
for (cppty, jlty) in BuiltinTypeMap
    @eval is_convertible(::Type{S}, ::Type{CppRef{CppType{Symbol($cppty),C}}}) where {N,S<:CppObject{CppRef{$jlty},N}} = true
end
is_convertible(::Type{S}, ::Type{CppRef{CppType{T,C}}}) where {N,NR,T,U<:CppObject{CppType{T,U},N},S<:CppObject{CppRef{U},NR}} = true
for (cppty, jlty) in BuiltinTypeMap
    @eval is_convertible(::Type{S}, ::Type{CppRef{CppType{Symbol($cppty),C}}}) where {N,NR,U<:CppObject{$jlty,N},S<:CppObject{CppRef{U},NR}} = true
end

# const T -> T
is_convertible(::Type{S}, ::Type{T}) where {N,T,S<:CppObject{CppType{T,C},N}} = true
for (cppty, jlty) in BuiltinTypeMap
    @eval is_convertible(::Type{S}, ::Type{$jlty}) where {N,S<:CppObject{CppType{Symbol($cppty),C},N}} = true
end

# const T& -> T
is_convertible(::Type{S}, ::Type{T}) where {N,T,S<:CppObject{CppRef{CppType{T,C}},N}} = true
for (cppty, jlty) in BuiltinTypeMap
    @eval is_convertible(::Type{S}, ::Type{$jlty}) where {N,S<:CppObject{CppRef{CppType{Symbol($cppty),C}},N}} = true
end
is_convertible(::Type{S}, ::Type{T}) where {N,NR,T,U<:CppObject{CppType{T,C},N},S<:CppObject{CppRef{U},NR}} = true
for (cppty, jlty) in BuiltinTypeMap
    @eval is_convertible(::Type{S}, ::Type{$jlty}) where {N,NR,U<:CppObject{CppType{Symbol($cppty),C},N},S<:CppObject{CppRef{U},NR}} = true
end

# T& -> T, const T& -> const T
is_convertible(::Type{S}, ::Type{T}) where {N,T,S<:CppObject{CppRef{T},N}} = true
is_convertible(::Type{S}, ::Type{T}) where {N,NR,T,U<:CppObject{T,N},S<:CppObject{CppRef{U},NR}} = true

# T& -> T&, const T& -> const T&
is_convertible(::Type{S}, ::Type{CppRef{T}}) where {N,T,S<:CppObject{T,N}} = true
is_convertible(::Type{S}, ::Type{CppRef{T}}) where {N,NR,T,U<:CppObject{T,N},S<:CppObject{CppRef{U},NR}} = true

# CppCPtr
is_convertible(::Type{S}, ::Type{CppCPtr{T}}) where {N,T,S<:CppObject{Ptr{T},N}} = true
is_convertible(::Type{S}, ::Type{CppCPtr{T}}) where {N,NP,T,U<:CppObject{T,N},S<:CppObject{Ptr{U},NP}} = true
is_convertible(::Type{S}, ::Type{CppCPtr{T}}) where {N,NP,T,U<:CppObject{T,N},S<:CppObject{CppCPtr{U},NP}} = true

# Ptr
is_convertible(::Type{S}, ::Type{Ptr{T}}) where {N,T,S<:CppObject{CppCPtr{T},N}} = true
is_convertible(::Type{S}, ::Type{Ptr{T}}) where {N,NP,T,U<:CppObject{T,N},S<:CppObject{Ptr{U},NP}} = true
is_convertible(::Type{S}, ::Type{Ptr{CppType{T,C}}}) where {N,NP,T,U<:CppObject{CppType{T,U},N},S<:CppObject{Ptr{U},NP}} = true

# Ptr
is_convertible(::Type{CppObject{Ptr{CppObject{Cchar,N}},NP}}, ::Type{Ptr{CppType{Symbol("char"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Cchar,N}},NP}}, ::Type{Ptr{CppType{Symbol("signed char"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Cuchar,N}},NP}}, ::Type{Ptr{CppType{Symbol("unsigned char"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Cshort,N}},NP}}, ::Type{Ptr{CppType{Symbol("short"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Cushort,N}},NP}}, ::Type{Ptr{CppType{Symbol("unsigned short"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Cint,N}},NP}}, ::Type{Ptr{CppType{Symbol("int"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Cuint,N}},NP}}, ::Type{Ptr{CppType{Symbol("unsigned int"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Clong,N}},NP}}, ::Type{Ptr{CppType{Symbol("long"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Culong,N}},NP}}, ::Type{Ptr{CppType{Symbol("unsigned long"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Clonglong,N}},NP}}, ::Type{Ptr{CppType{Symbol("long long"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Culonglong,N}},NP}}, ::Type{Ptr{CppType{Symbol("unsigned long long"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Cfloat,N}},NP}}, ::Type{Ptr{CppType{Symbol("float"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Cdouble,N}},NP}}, ::Type{Ptr{CppType{Symbol("double"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Bool,N}},NP}}, ::Type{Ptr{CppType{Symbol("_Bool"),C}}}) where {N,NP} = true

# CppCPtr
is_convertible(::Type{CppObject{Ptr{CppObject{Cchar,N}},NP}}, ::Type{CppCPtr{CppType{Symbol("char"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Cchar,N}},NP}}, ::Type{CppCPtr{CppType{Symbol("signed char"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Cuchar,N}},NP}}, ::Type{CppCPtr{CppType{Symbol("unsigned char"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Cshort,N}},NP}}, ::Type{CppCPtr{CppType{Symbol("short"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Cushort,N}},NP}}, ::Type{CppCPtr{CppType{Symbol("unsigned short"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Cint,N}},NP}}, ::Type{CppCPtr{CppType{Symbol("int"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Cuint,N}},NP}}, ::Type{CppCPtr{CppType{Symbol("unsigned int"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Clong,N}},NP}}, ::Type{CppCPtr{CppType{Symbol("long"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Culong,N}},NP}}, ::Type{CppCPtr{CppType{Symbol("unsigned long"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Clonglong,N}},NP}}, ::Type{CppCPtr{CppType{Symbol("long long"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Culonglong,N}},NP}}, ::Type{CppCPtr{CppType{Symbol("unsigned long long"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Cfloat,N}},NP}}, ::Type{CppCPtr{CppType{Symbol("float"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Cdouble,N}},NP}}, ::Type{CppCPtr{CppType{Symbol("double"),C}}}) where {N,NP} = true
is_convertible(::Type{CppObject{Ptr{CppObject{Bool,N}},NP}}, ::Type{CppCPtr{CppType{Symbol("_Bool"),C}}}) where {N,NP} = true
