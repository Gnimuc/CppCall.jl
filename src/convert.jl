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

# CppRef
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

# builtin types
# CppRef
is_convertible(::Type{CppObject{Cchar,N}}, ::Type{CppRef{CppType{Symbol("char"),C}}}) where {N} = true
is_convertible(::Type{CppObject{Cchar,N}}, ::Type{CppRef{CppType{Symbol("signed char"),C}}}) where {N} = true
is_convertible(::Type{CppObject{Cuchar,N}}, ::Type{CppRef{CppType{Symbol("unsigned char"),C}}}) where {N} = true
is_convertible(::Type{CppObject{Cshort,N}}, ::Type{CppRef{CppType{Symbol("short"),C}}}) where {N} = true
is_convertible(::Type{CppObject{Cushort,N}}, ::Type{CppRef{CppType{Symbol("unsigned short"),C}}}) where {N} = true
is_convertible(::Type{CppObject{Cint,N}}, ::Type{CppRef{CppType{Symbol("int"),C}}}) where {N} = true
is_convertible(::Type{CppObject{Cuint,N}}, ::Type{CppRef{CppType{Symbol("unsigned int"),C}}}) where {N} = true
is_convertible(::Type{CppObject{Clong,N}}, ::Type{CppRef{CppType{Symbol("long"),C}}}) where {N} = true
is_convertible(::Type{CppObject{Culong,N}}, ::Type{CppRef{CppType{Symbol("unsigned long"),C}}}) where {N} = true
is_convertible(::Type{CppObject{Clonglong,N}}, ::Type{CppRef{CppType{Symbol("long long"),C}}}) where {N} = true
is_convertible(::Type{CppObject{Culonglong,N}}, ::Type{CppRef{CppType{Symbol("unsigned long long"),C}}}) where {N} = true
is_convertible(::Type{CppObject{Cfloat,N}}, ::Type{CppRef{CppType{Symbol("float"),C}}}) where {N} = true
is_convertible(::Type{CppObject{Cdouble,N}}, ::Type{CppRef{CppType{Symbol("double"),C}}}) where {N} = true
is_convertible(::Type{CppObject{Bool,N}}, ::Type{CppRef{CppType{Symbol("_Bool"),C}}}) where {N} = true

is_convertible(::Type{CppObject{CppRef{Cchar},NR}}, ::Type{CppRef{CppType{Symbol("char"),C}}}) where {NR} = true
is_convertible(::Type{CppObject{CppRef{Cchar},NR}}, ::Type{CppRef{CppType{Symbol("signed char"),C}}}) where {NR} = true
is_convertible(::Type{CppObject{CppRef{Cuchar},NR}}, ::Type{CppRef{CppType{Symbol("unsigned char"),C}}}) where {NR} = true
is_convertible(::Type{CppObject{CppRef{Cshort},NR}}, ::Type{CppRef{CppType{Symbol("short"),C}}}) where {NR} = true
is_convertible(::Type{CppObject{CppRef{Cushort},NR}}, ::Type{CppRef{CppType{Symbol("unsigned short"),C}}}) where {NR} = true
is_convertible(::Type{CppObject{CppRef{Cint},NR}}, ::Type{CppRef{CppType{Symbol("int"),C}}}) where {NR} = true
is_convertible(::Type{CppObject{CppRef{Cuint},NR}}, ::Type{CppRef{CppType{Symbol("unsigned int"),C}}}) where {NR} = true
is_convertible(::Type{CppObject{CppRef{Clong},NR}}, ::Type{CppRef{CppType{Symbol("long"),C}}}) where {NR} = true
is_convertible(::Type{CppObject{CppRef{Culong},NR}}, ::Type{CppRef{CppType{Symbol("unsigned long"),C}}}) where {NR} = true
is_convertible(::Type{CppObject{CppRef{Clonglong},NR}}, ::Type{CppRef{CppType{Symbol("long long"),C}}}) where {NR} = true
is_convertible(::Type{CppObject{CppRef{Culonglong},NR}}, ::Type{CppRef{CppType{Symbol("unsigned long long"),C}}}) where {NR} = true
is_convertible(::Type{CppObject{CppRef{Cfloat},NR}}, ::Type{CppRef{CppType{Symbol("float"),C}}}) where {NR} = true
is_convertible(::Type{CppObject{CppRef{Cdouble},NR}}, ::Type{CppRef{CppType{Symbol("double"),C}}}) where {NR} = true
is_convertible(::Type{CppObject{CppRef{Bool},NR}}, ::Type{CppRef{CppType{Symbol("_Bool"),C}}}) where {NR} = true

is_convertible(::Type{CppObject{CppRef{CppObject{Cchar,N}},NR}}, ::Type{CppRef{CppType{Symbol("char"),C}}}) where {N,NR} = true
is_convertible(::Type{CppObject{CppRef{CppObject{Cchar,N}},NR}}, ::Type{CppRef{CppType{Symbol("signed char"),C}}}) where {N,NR} = true
is_convertible(::Type{CppObject{CppRef{CppObject{Cuchar,N}},NR}}, ::Type{CppRef{CppType{Symbol("unsigned char"),C}}}) where {N,NR} = true
is_convertible(::Type{CppObject{CppRef{CppObject{Cshort,N}},NR}}, ::Type{CppRef{CppType{Symbol("short"),C}}}) where {N,NR} = true
is_convertible(::Type{CppObject{CppRef{CppObject{Cushort,N}},NR}}, ::Type{CppRef{CppType{Symbol("unsigned short"),C}}}) where {N,NR} = true
is_convertible(::Type{CppObject{CppRef{CppObject{Cint,N}},NR}}, ::Type{CppRef{CppType{Symbol("int"),C}}}) where {N,NR} = true
is_convertible(::Type{CppObject{CppRef{CppObject{Cuint,N}},NR}}, ::Type{CppRef{CppType{Symbol("unsigned int"),C}}}) where {N,NR} = true
is_convertible(::Type{CppObject{CppRef{CppObject{Clong,N}},NR}}, ::Type{CppRef{CppType{Symbol("long"),C}}}) where {N,NR} = true
is_convertible(::Type{CppObject{CppRef{CppObject{Culong,N}},NR}}, ::Type{CppRef{CppType{Symbol("unsigned long"),C}}}) where {N,NR} = true
is_convertible(::Type{CppObject{CppRef{CppObject{Clonglong,N}},NR}}, ::Type{CppRef{CppType{Symbol("long long"),C}}}) where {N,NR} = true
is_convertible(::Type{CppObject{CppRef{CppObject{Culonglong,N}},NR}}, ::Type{CppRef{CppType{Symbol("unsigned long long"),C}}}) where {N,NR} = true
is_convertible(::Type{CppObject{CppRef{CppObject{Cfloat,N}},NR}}, ::Type{CppRef{CppType{Symbol("float"),C}}}) where {N,NR} = true
is_convertible(::Type{CppObject{CppRef{CppObject{Cdouble,N}},NR}}, ::Type{CppRef{CppType{Symbol("double"),C}}}) where {N,NR} = true
is_convertible(::Type{CppObject{CppRef{CppObject{Bool,N}},NR}}, ::Type{CppRef{CppType{Symbol("_Bool"),C}}}) where {N,NR} = true

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
