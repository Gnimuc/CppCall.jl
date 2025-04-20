"""
    cpptypemap(::Type{From}) -> To
For any given type `From`, return the type `To`.
This interface is used to implement custom type mappings when unwrapping `CppObject`s.
"""
cpptypemap(::Type{T}) where {T} = error("no type mapping for $T")
cpptypemap(::Type{T}) where {T<:CppObject} = T

cpptypemap(::Type{T}) where {T<:BuiltinTypes} = T
cpptypemap(::Type{Ptr{T}}) where {T<:BuiltinTypes} = Ptr{T}
cpptypemap(::Type{Ptr{T}}) where {T<:CppType} = Ptr{cpptypemap(T)}
cpptypemap(::Type{Ptr{T}}) where {T<:CppObject} = Ptr{cpptypemap(T)}
cpptypemap(::Type{CppRef{T}}) where {T<:CppObject} = Ptr{cpptypemap(T)}

cpptypemap(::Type{CppType{:void,Q}}) where {Q} = T

cpptypemap(::Type{CppType{Symbol("char"),Q}}) where {Q} = Cchar
cpptypemap(::Type{CppType{Symbol("unsigned char"),Q}}) where {Q} = Cuchar
cpptypemap(::Type{CppType{Symbol("signed char"),Q}}) where {Q} = Cchar

cpptypemap(::Type{CppType{Symbol("short"),Q}}) where {Q} = Cshort
cpptypemap(::Type{CppType{Symbol("unsigned short"),Q}}) where {Q} = Cushort
cpptypemap(::Type{CppType{Symbol("int"),Q}}) where {Q} = Cint
cpptypemap(::Type{CppType{Symbol("unsigned int"),Q}}) where {Q} = Cuint
cpptypemap(::Type{CppType{Symbol("long"),Q}}) where {Q} = Clong
cpptypemap(::Type{CppType{Symbol("unsigned long"),Q}}) where {Q} = Culong
cpptypemap(::Type{CppType{Symbol("long long"),Q}}) where {Q} = Clonglong
cpptypemap(::Type{CppType{Symbol("unsigned long long"),Q}}) where {Q} = Culonglong
cpptypemap(::Type{CppType{Symbol("float"),Q}}) where {Q} = Cfloat
cpptypemap(::Type{CppType{Symbol("double"),Q}}) where {Q} = Cdouble
cpptypemap(::Type{CppType{Symbol("_Bool"),Q}}) where {Q} = Bool

cpptypemap(::Type{CppEnumType{S,T}}) where {S,T} = T
