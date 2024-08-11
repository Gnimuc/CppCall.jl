#! format: off
const BuiltinTypes = Union{Nothing,Bool,UInt8,UInt16,UInt32,UInt64,UInt128,Int8,Int16,Int32,Int64,Int128,Float16,Float32,Float64}

const DEFAULT_TYPE_MAPPING = Dict{String,Type{T} where {T<:BuiltinTypes}}(
    "void" => Cvoid,
    "char" => Cchar,
    "unsigned char" => Cuchar,
    "short" => Cshort,
    "unsigned short" => Cushort,
    "int" => Cint,
    "unsigned int" => Cuint,
    "long" => Clong,
    "unsigned long" => Culong,
    "long long" => Clonglong,
    "unsigned long long" => Culonglong,
    "float" => Cfloat,
    "double" => Cdouble,
    "bool" => Bool,
    "intmax_t" => Cintmax_t,
    "uintmax_t" => Cuintmax_t,
    "size_t" => Csize_t,
    "ssize_t" => Cssize_t,
    "ptrdiff_t" => Cptrdiff_t,
    "wchar_t" => Cwchar_t,
    "unsigned" => Cuint)
#! format: on

# cv (const and volatile) type qualifiers
# see https://en.cppreference.com/w/cpp/language/cv
primitive type Qualifier 16 end
const Unqualified = Base.bitcast(Qualifier, 0x000)
const Const_Qualified = Base.bitcast(Qualifier, 0x001)
const Volatile_Qualified = Base.bitcast(Qualifier, 0x010)
const Const_Volatile_Qualified = Base.bitcast(Qualifier, 0x011)
# const Restrict_Qualified = Base.bitcast(Qualifier, 0x100)
# const Const_Restrict_Qualified = Base.bitcast(Qualifier, 0x101)
# const Volatile_Restrict_Qualified = Base.bitcast(Qualifier, 0x110)
# const Const_Volatile_Restrict_Qualified = Base.bitcast(Qualifier, 0x111)

# alias
const U = Unqualified
const C = Const_Qualified
const V = Volatile_Qualified
const CV = Const_Volatile_Qualified

"""
	abstract type AbstractCppType <: Any end
Super type for representing non-builtin C++ types in Julia.
"""
abstract type AbstractCppType end

"""
	struct CppType{S,Q} <: AbstractCppType
Represent a (possibly-)cv-qualified C++ type in Julia.

`S` is a symbol representing the type name and `Q` is an integer representing the qualifier.
"""
struct CppType{S,Q} <: AbstractCppType end

"""
    CppType(x::AbstractString, q::Qualifier=Unqualified)
Create a C++ type with the given name and qualifier. The qualifier is `Unqualified` by default.
Note that, the identifer `x` is not checked for existence in the C++ interpreter when creating the type.
"""
CppType(x::AbstractString, q::Qualifier=Unqualified) = CppType{Symbol(x),q}

# C++ function type
# See https://en.cppreference.com/w/cpp/language/functions for more details.
"""
	struct CppFuncType{RT,ARGST} <: AbstractCppType
Capture the return type and argument types of a C++ function in Julia.

`RT` is a [`CppType`](@ref) representing the return type.
`ARGST` is a tuple of [`CppType`](@ref) representing the argument types.
"""
struct CppFuncType{RT,ARGST} <: AbstractCppType end

get_rt(::Type{CppFuncType{RT,ARGST}}) where {RT,ARGST} = RT
get_argst(::Type{CppFuncType{RT,ARGST}}) where {RT,ARGST} = ARGST

"""
	struct CppTemplate{T<:CppType{S} where S,TARGS} <: AbstractCppType
A templated type where `T` is the [`CppType`](@ref) to be templated and
`TARGS` is a tuple of template arguments.
"""
struct CppTemplate{T<:CppType{S} where {S},TARGS} <: AbstractCppType end

"""
	struct CppEnum{S,T} <: AbstractCppType
Represent a C/C++ Enum.

`S` is a symbol, representing the fully qualified name of the enum, `T` the underlying type.
"""
struct CppEnum{S,T} <: AbstractCppType
    val::T
end

Base.:(==)(x::CppEnum, y::Integer) = x.val == y
Base.:(==)(x::Integer, y::CppEnum) = x == y.val

"""
    primitive type GenericCppPtr{Q,T,AS} <: AbstractCppType
Represent a generic qualified C++ pointer.
"""
primitive type GenericCppPtr{Q,T,AS} <: AbstractCppType sizeof(Int) end

const CppPtr{Q,T} = GenericCppPtr{Q,T,Core.CPU}

Base.cconvert(::Type{Ptr{Cvoid}}, x::CppPtr{Q,T}) where {Q,T} = reinterpret(Ptr{T}, x)

unwrap_type(::Type{CppPtr{Q,T}}) where {Q,T} = T

"""
	struct CppRef{T} <: AbstractCppType
Represent a generic qualified C++ reference.
"""
struct CppRef{T} <: AbstractCppType end

"""
    mutable struct CppObject{T,N} <: Any
Represent a C++ object in Julia.
"""
mutable struct CppObject{T,N}
    data::NTuple{N,UInt8}
end

CppObject{T,N}() where {T,N} = CppObject{T,N}(ntuple(Returns(0x00), N))

function CppObject{T}(x::S) where {T<:BuiltinTypes,S}
    N = Core.sizeof(T)
    CppObject{T,N}(reinterpret(NTuple{N,UInt8}, convert(T, x)))
end

function CppObject{T}(x::S) where {T,S}
    N = Core.sizeof(S)
    CppObject{T,N}(reinterpret(NTuple{N,UInt8}, x))
end

Base.isassigned(x::CppObject) = isdefined(x, :data)

function Base.unsafe_convert(P::Union{Type{Ptr{T}},Type{Ptr{Cvoid}}}, x::CppObject{T})::P where T
    p = pointer_from_objref(x)
    p == C_NULL && throw(UndefRefError())
    return p
end
# Base.unsafe_convert(::Type{Ptr{Any}}, x::CppObject{Any})::Ptr{Any} = pointer_from_objref(x)

Base.convert(::Type{T}, x::CppObject) where {T} = reinterpret(T, x.data)

Base.getindex(obj::CppObject{T,N}) where {T,N} = convert(cpptypemap(T), obj)

function Base.setindex!(obj::CppObject{T,N}, x) where {T,N}
    obj.data = reinterpret(NTuple{N,UInt8}, convert(cpptypemap(T), x))
    return obj
end

unsafe_pointer(x::Ref) = Base.unsafe_convert(Ptr{Cvoid}, x)
unsafe_pointer(x::CppObject) = Base.unsafe_convert(Ptr{Cvoid}, x)
unsafe_pointer(x::Base.RefValue) = pointer_from_objref(x)
unsafe_pointer(x::Ptr{Cvoid}) = x

unwrap_type(::Type{Ref{T}}) where {T} = T
unwrap_type(::Type{CppObject{T,N}}) where {T,N} = T
unwrap_size(::Type{CppObject{T,N}}) where {T,N} = N

# type mapping
"""
	to_cpp(::Type{T}, I::CppInterpreter) -> QualType
Return a Clang type in memory representation corresponding to the Julia type `T`.
"""
to_cpp(::Type{T}, I::CppInterpreter) where {T<:AbstractCppType} = error("Unsupported type: $T")

to_cpp(::Type{T}, I::CppInterpreter) where {T<:BuiltinTypes} = get_qual_type(jlty_to_clty(T, get_ast_context(I)))

to_cpp(x::NamedDecl, I::CppInterpreter) = get_decl_type(get_ast_context(I), x)

function to_cpp(::Type{Ptr{T}}, I::CppInterpreter) where T<:CppType{S,Q} where {S,Q}
    ast = get_ast_context(I)
    get_pointer_type(ast, to_cpp(T, I))
end

function to_cpp(::Type{CppType{S,Q}}, I::CppInterpreter) where {S,Q}
    s = string(S)
    if haskey(DEFAULT_TYPE_MAPPING, s)
        t = DEFAULT_TYPE_MAPPING[s]
        Q == Unqualified && return to_cpp(t, I)
        qty = get_qual_type(jlty_to_clty(t, get_ast_context(I)))
    else
        decl = lookup(I, s)
        qty = to_cpp(decl, I)
    end
    Q == C && return add_const(qty)
    Q == V && return add_volatile(qty)
    Q == CV && return add_volatile(add_const(qty))
    return qty
end

function to_cpp(::Type{CppTemplate{S,TARGS}}, I::CppInterpreter) where {S,TARGS}
    lookup_type(I, string(S)) || error("failed to find the type: $S")
    decl = get_type_decl(I)
    CC.dump(decl)
    return get_decl_type(get_ast_context(I), decl)
end

function to_cpp(::Type{CppEnum{S}}, I::CppInterpreter) where {S}
    sc = CppInterOp.lookup(I, string(S))
    decl = TypeDecl(sc.scope.data)
    CppInterOp.@check_ptrs decl
    return get_decl_type(get_ast_context(I), decl)
end

function get_qualifier(ty::QualType)
    is_const(ty) && is_volatile(ty) && return CV
    is_const(ty) && return C
    is_volatile(ty) && return V
    return Unqualified
end

function get_name(x::AbstractType)
    n = CC.get_name(get_qual_type(x))
    i = findfirst(' ', n)
    return i == nothing ? n : n[(i + 1):end]
end

"""
	to_jl(x)
Return the Julia representation of a Clang type.
"""
to_jl(x) = x

to_jl(x::T) where {T<:AbstractClangType} = clty_to_jlty(x)

function to_jl(x::QualType)
    t = clty_to_jlty(get_type_ptr(x))
    q = get_qualifier(x)
    return to_jl(t, q)
end

to_jl(x::CC.VoidTy) = Cvoid
to_jl(x::CC.BoolTy) = Bool
to_jl(x::CC.CharTy) = Cuchar
to_jl(x::CC.WCharTy) = Cwchar_t
to_jl(x::CC.WideCharTy) = Cwchar_t
to_jl(x::CC.SignedCharTy) = Cchar
to_jl(x::CC.ShortTy) = Cshort
to_jl(x::CC.IntTy) = Cint
to_jl(x::CC.LongTy) = Clong
to_jl(x::CC.LongLongTy) = Clonglong
to_jl(x::CC.Int128Ty) = Int128
to_jl(x::CC.UnsignedCharTy) = Cuchar
to_jl(x::CC.UnsignedShortTy) = Cushort
to_jl(x::CC.UnsignedIntTy) = Cuint
to_jl(x::CC.UnsignedLongTy) = Culong
to_jl(x::CC.UnsignedLongLongTy) = Culonglong
to_jl(x::CC.UnsignedInt128Ty) = UInt128
to_jl(x::CC.FloatTy) = Cfloat
to_jl(x::CC.DoubleTy) = Cdouble
to_jl(x::CC.Float16Ty) = Float16
to_jl(x::CC.HalfTy) = Float16
to_jl(x::CC.BFloat16Ty) = Float16
to_jl(x::CC.NullPtrTy) = Ptr{Cvoid}
to_jl(x::CC.VoidPtrTy) = Ptr{Cvoid}

function to_jl(x::AbstractBuiltinType, q::Qualifier=Unqualified)
    q == Unqualified && return to_jl(x)
    n = CC.get_name(get_qual_type(x))
    @assert !isempty(n) "Builtin types must have a name."
    sym = Symbol(n)
    return CppType{sym,q}
end

function to_jl(x::EnumType, q::Qualifier=Unqualified)
    t = to_jl(get_integer_type(x))
    n = get_name(x)
    sym = isempty(n) ? gensym() : Symbol(n)
    return CppEnum{sym,t}
end

function to_jl(x::AbstractRecordType, q::Qualifier=Unqualified)
    n = get_name(x)
    sym = isempty(n) ? gensym() : Symbol(n)
    return CppType{sym,q}
end

to_jl(x::ElaboratedType, ::Qualifier) = to_jl(x)
to_jl(x::ElaboratedType) = to_jl(desugar(x))

to_jl(x::TypedefType, ::Qualifier) = to_jl(x)
to_jl(x::TypedefType) = to_jl(desugar(x))

to_jl(x::PointerType, q::Qualifier=Unqualified) = q == Unqualified ? Ptr{to_jl(get_pointee_type(x))} : CppPtr{q,to_jl(get_pointee_type(x))}

to_jl(x::LValueReferenceType, ::Qualifier) = to_jl(x)
to_jl(x::LValueReferenceType) = CppRef{to_jl(get_pointee_type(x))}
to_jl(x::RValueReferenceType, ::Qualifier) = to_jl(x)
to_jl(x::RValueReferenceType) = CppRef{to_jl(get_pointee_type(x))}

to_jl(x::FunctionNoProtoType, ::Qualifier) = to_jl(x)
to_jl(x::FunctionNoProtoType) = CppFuncType{to_jl(get_return_type(x))}

to_jl(x::FunctionProtoType, q::Qualifier) = to_jl(x)
function to_jl(x::FunctionProtoType)
    rt = to_jl(get_return_type(x))
    argts = to_jl.(get_params(x))
    return CppFuncType{rt,Tuple{argts...}}
end
