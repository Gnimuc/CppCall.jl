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

get_s(::Type{CppType{S,Q}}) where {S,Q} = S
get_q(::Type{CppType{S,Q}}) where {S,Q} = Q

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

get_t(::Type{CppTemplate{T,TARGS}}) where {T<:CppType{S} where {S},TARGS} = T
get_s(::Type{CppTemplate{T,TARGS}}) where {T<:CppType{S} where {S},TARGS} = S
get_targs(::Type{CppTemplate{T,TARGS}}) where {T<:CppType{S} where {S},TARGS} = TARGS

CppTemplate(ty, targs...) = CppTemplate{ty,Tuple{targs...}}

"""
	struct CppEnumType{S,T} <: AbstractCppType
Represent a C/C++ enum type.
For anomynous enum types, [`CppEnum`](@ref) can be used to query the enum type.

`S` is a symbol, representing the name of the enumerator. `T` is the underlying integer type.
"""
struct CppEnumType{S,T} <: AbstractCppType end

get_s(::Type{CppEnumType{S,T}}) where {S,T} = S
get_t(::Type{CppEnumType{S,T}}) where {S,T} = T

"""
    CppEnumType(x::AbstractString)
Create a C++ enum type.
For anomynous enum types, [`CppEnum`](@ref) can be used to query the enum type.
Note that, the identifer `x` is not checked for existence in the C++ interpreter when creating the type.
"""
CppEnumType(x::AbstractString) = CppEnumType{Symbol(x),UInt32}

# Technically, `CppEnum` is not a TYPE.
"""
	struct CppEnum{S,N} <: AbstractCppType
Represent a C/C++ enumerator.

`S` is a symbol, representing the name of the enumerator. `N` is the value of the enumerator.
"""
struct CppEnum{S,N} <: AbstractCppType end

get_s(::Type{CppEnum{S,N}}) where {S,N} = S
get_n(::Type{CppEnum{S,N}}) where {S,N} = N

"""
    CppEnum(x::AbstractString)
Create a `CppEnum` from an enumerator name `x`.
Note that, the `x` is not checked for existence in the C++ interpreter when creating the type.
"""
CppEnum(x::AbstractString) = CppEnum{Symbol(x),0}

"""
    primitive type GenericCppPtr{Q,T,AS} <: AbstractCppType
Represent a generic qualified C++ pointer.
"""
primitive type GenericCppPtr{Q,T,AS} <: AbstractCppType sizeof(Int) end

const CppPtr{Q,T} = GenericCppPtr{Q,T,Core.CPU}

const CppCPtr{T} = CppPtr{C,T}
const CppVPtr{T} = CppPtr{V,T}
const CppCVPtr{T} = CppPtr{CV,T}

Base.cconvert(::Type{Ptr{Cvoid}}, x::CppPtr{Q,T}) where {Q,T} = reinterpret(Ptr{T}, x)

unwrap_type(::Type{CppPtr{Q,T}}) where {Q,T} = T

"""
    struct CppRef{T} <: AbstractCppType
Represent a C++ reference.
"""
struct CppRef{T} <: AbstractCppType end

unwrap_type(::Type{CppRef{T}}) where {T} = T

# only for type checking
struct CppRvalueRef{T} <: AbstractCppType end

"""
    mutable struct CppObject{T,N} <: Any
Represent a C++ object in Julia.
"""
mutable struct CppObject{T,N}
    data::NTuple{N,UInt8}
end

Base.isassigned(x::CppObject) = isdefined(x, :data)

function Base.unsafe_convert(P::Union{Type{Ptr{T}},Type{Ptr{Cvoid}}}, x::CppObject{T})::P where {T}
    p = pointer_from_objref(x)
    p == C_NULL && throw(UndefRefError())
    return p
end
# Base.unsafe_convert(::Type{Ptr{Any}}, x::CppObject{Any})::Ptr{Any} = pointer_from_objref(x)

Base.convert(::Type{T}, x::CppObject) where {T} = reinterpret(T, x.data)

Base.getindex(obj::CppObject{T}) where {T} = convert(cpptypemap(T), obj)

function Base.setindex!(obj::CppObject{T,N}, x) where {T,N}
    obj.data = reinterpret(NTuple{N,UInt8}, convert(cpptypemap(T), x))
    return x
end

Base.setindex!(obj::CppObject{CppType{T,C},N}, x) where {T,N} = error("assignment of read-only variable $obj")

unsafe_pointer(x::CppObject) = Base.unsafe_convert(Ptr{Cvoid}, x)
unsafe_pointer(x::CppObject{CppRef{CppObject{T,N}},NR}) where {T,N,NR} = reinterpret(Ptr{T}, x.data)
unsafe_pointer(x::CppObject{CppRef{T},N}) where {T,N} = reinterpret(Ptr{T}, x.data)
unsafe_pointer(x::Ptr{Cvoid}) = x

unsafe_pointer_rt(x::CppObject) = Base.unsafe_convert(Ptr{Cvoid}, x)
unsafe_pointer_rt(x::CppObject{CppRef{T},N}) where {T,N} = pointer_from_objref(x)
unsafe_pointer_rt(x::Ptr{Cvoid}) = x

unwrap_type(::Type{CppObject{T,N}}) where {T,N} = T
unwrap_size(::Type{CppObject{T,N}}) where {T,N} = N

# zero-initialization
CppObject{T,N}() where {T,N} = CppObject{T,N}(ntuple(Returns(0x00), N))
CppObject{CppRef{T}}() where {T} = CppObject{CppRef{T},Core.sizeof(Int)}()
CppObject{Ptr{T}}() where {T} = CppObject{Ptr{T},Core.sizeof(Int)}()
# CppObject{T}() where {T<:BuiltinTypes} = CppObject{T,Core.sizeof(T)}()

# pointers
# with the current design it's a bit tricky to make a difference between:
# - CppObject{Ptr{CppType{T}}} -> represents a heap-allocated pointer
# - CppObject{Ptr{CppObject{CppType{T}}}} -> represents a heap-allocated pointer to a heap-allocated object
# the former doesn't store the size of the C++ type, dereferencing the pointer is required to
# lookup the size of the type explicitly, while the latter does store the size, so it can be
# dereferenced directly via `unsafe_load`.
# the former should be used if the details of the type are not important (e.g. representing opaque pointers)
# the latter can be used like a `WeakRef`, it doesn't extend the lifetime of the object, so
# `GC.@preserve` should be used to keep the underlying object alive, when the object is allocated by Julia.
#
# note that, unlike references, pointers can be dangling, so it's important to keep track of the
# lifetime of the object they point to, especially when the object is allocated by Julia's GC.
function CppObject{Ptr}(x::CppObject{T,N}) where {T,N}
    S = Core.sizeof(Int)
    return GC.@preserve x CppObject{Ptr{CppObject{T,N}},S}(reinterpret(NTuple{S,UInt8}, pointer_from_objref(x)))
end

function CppObject{CppCPtr}(x::CppObject{T,N}) where {T,N}
    S = Core.sizeof(Int)
    return GC.@preserve x CppObject{CppCPtr{CppObject{T,N}},S}(reinterpret(NTuple{S,UInt8}, pointer_from_objref(x)))
end

function CppObject{CppVPtr}(x::CppObject{T,N}) where {T,N}
    S = Core.sizeof(Int)
    return GC.@preserve x CppObject{CppVPtr{CppObject{T,N}},S}(reinterpret(NTuple{S,UInt8}, pointer_from_objref(x)))
end

function CppObject{CppCVPtr}(x::CppObject{T,N}) where {T,N}
    S = Core.sizeof(Int)
    return GC.@preserve x CppObject{CppCVPtr{CppObject{T,N}},S}(reinterpret(NTuple{S,UInt8}, pointer_from_objref(x)))
end

is_const_ptr(::CppObject{Ptr{T}}) where {T} = false
is_volatile_ptr(::CppObject{Ptr{T}}) where {T} = false

is_const_ptr(::CppObject{CppCPtr{T}}) where {T} = true
is_volatile_ptr(::CppObject{CppCPtr{T}}) where {T} = false

is_const_ptr(::CppObject{CppVPtr{T}}) where {T} = false
is_volatile_ptr(::CppObject{CppVPtr{T}}) where {T} = true

is_const_ptr(::CppObject{CppCVPtr{T}}) where {T} = true
is_volatile_ptr(::CppObject{CppCVPtr{T}}) where {T} = true

# references
# references are implemented as pointers:
# - CppObject{Ref{CppType{T}}} -> a CppObject that represents a reference
# - CppObject{Ref{CppObject{CppType{T}}}} -> a CppObject that represents a reference to a CppObject
# the former is used when the original object is unknown, for example, it is used as the
# return type of a C++ function which returns a reference. but unlike C++, the return value
# doesn't extend the lifetime of the original object. if the original object is allocated by Julia,
# `GC.@preserve` should be used to keep the object alive.
# the latter is used to create a reference to a CppObject that is allocated by Julia GC,
# the `@ref` macro needs to be used to extend the lifetime of the object.
function CppObject{CppRef}(x::CppObject{T,N}) where {T,N}
    S = Core.sizeof(Int)
    return GC.@preserve x CppObject{CppRef{CppObject{T,N}},S}(reinterpret(NTuple{S,UInt8}, pointer_from_objref(x)))
end

# there is no reference to reference in C++, it's equivalent to make a binding to the original object
CppObject{CppRef}(x::CppObject{CppRef{T},N}) where {T,N} = x

Base.getindex(x::CppObject{CppRef{T},N}) where {T,N} = error("failed to dereference the C++ reference $x.")

function Base.getindex(x::CppObject{CppRef{CppObject{T,N}},NR}) where {T,N,NR}
    ptr = reinterpret(Ptr{NTuple{N,UInt8}}, x.data)
    refee = unsafe_pointer_to_objref(ptr)
    return refee[]
end

function Base.setindex!(obj::CppObject{CppRef{CppObject{T,N}}}, x) where {T,N}
    ptr = reinterpret(Ptr{NTuple{N,UInt8}}, obj.data)
    unsafe_store!(ptr, reinterpret(NTuple{N,UInt8}, convert(cpptypemap(T), x)))
    return x
end

function Base.setindex!(obj::CppObject{CppRef{CppObject{CppType{T,C},N}}}, x) where {T,N}
    error("assignment of read-only reference $obj")
end

# builtin types
function CppObject{T}(x::S) where {T<:BuiltinTypes,S}
    N = Core.sizeof(T)
    CppObject{T,N}(reinterpret(NTuple{N,UInt8}, convert(T, x)))
end

function CppObject{T}(x::S) where {T,S}
    N = Core.sizeof(S)
    CppObject{T,N}(reinterpret(NTuple{N,UInt8}, x))
end

# type mapping
"""
    to_cpp(::Type{T}, I::CppInterpreter) -> QualType
Return a Clang type in memory representation corresponding to the Julia type `T`.
"""
to_cpp(::Type{T}, I::CppInterpreter) where {T<:AbstractCppType} = error("Unsupported type: $T")

to_cpp(::Type{T}, I::CppInterpreter) where {T<:BuiltinTypes} = get_qual_type(jlty_to_clty(T, get_ast_context(I)))
to_cpp(::Type{Ptr{T}}, I::CppInterpreter) where {T<:BuiltinTypes} = get_pointer_type(get_ast_context(I), to_cpp(T, I))

to_cpp(x::NamedDecl, I::CppInterpreter) = get_decl_type(get_ast_context(I), x)
# to_cpp(x::AbstractValueDecl, I::CppInterpreter) = getType(x)

function to_cpp(::Type{Ptr{T}}, I::CppInterpreter) where {T<:CppType{S,Q}} where {S,Q}
    ast = get_ast_context(I)
    return get_pointer_type(ast, to_cpp(T, I))
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

TemplateArgInfo(x::QualType) = CXTemplateArgInfo(x.ptr)

function instantiate(::Type{CppTemplate{T,TARGS}}, I::CppInterpreter) where {S,Q,T<:CppType{S,Q},TARGS}
    template_decl = lookup(I, string(S)) # ClassTemplateDecl
    args = [TemplateArgInfo(to_cpp(t, I)) for t in TARGS.types]
    scope = instantiateTemplate(make_scope(template_decl, I), args)
    return scope
end

to_cpp(x::ClassTemplateSpecializationDecl, I::CppInterpreter) = get_decl_type(get_ast_context(I), x)

function to_cpp(::Type{T}, I::CppInterpreter) where {T<:CppTemplate}
    scope = instantiate(T, I)
    ctsd = ClassTemplateSpecializationDecl(scope.data)
    return get_decl_type(get_ast_context(I), ctsd)
end

# FIXME: Add support for enum class scope
function to_cpp(::Type{CppEnumType{S,T}}, I::CppInterpreter) where {S,T}
    s = string(S)
    decl = lookup(I, s)
    return to_cpp(decl, I)
end

function to_cpp(::Type{CppEnum{S,N}}, I::CppInterpreter) where {S,N}
    s = string(S)
    decl = lookup(I, s, EnumLookup())
    return to_cpp(decl, I)
end

function get_qualifier(ty::QualType)
    is_const(ty) && is_volatile(ty) && return CV
    is_const(ty) && return C
    is_volatile(ty) && return V
    return Unqualified
end

# FIXME: using PrintingPolicy
function get_name(x::AbstractType)
    n = CC.get_name(get_qual_type(x))
    i = findfirst(' ', n)
    return i == nothing ? n : n[(i + 1):end]
end

function get_template_name(x::AbstractType)
    n = get_name(x)
    i = findfirst('<', n)
    return i == nothing ? n : n[1:(i - 1)]
end

# is_unnamed(x) = isempty(x) || occursin("unnamed", x)

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
    @assert q == Unqualified "Enum types must be unqualified."
    n = get_name(x)
    sym = isempty(n) ? gensym() : Symbol(n)
    t = to_jl(get_integer_type(x))
    return CppEnumType{sym,t}
end

function to_jl(x::AbstractRecordType, q::Qualifier=Unqualified)
    ctsd = ClassTemplateSpecializationDecl(getDecl(x))
    if ctsd.ptr == C_NULL
        n = get_name(x)
        sym = isempty(n) ? gensym() : Symbol(n)
        return CppType{sym,q}
    end
    args = getTemplateArgs(ctsd)
    targs = []
    for n = 0:(size(args) - 1)
        arg = get(args, n)
        k = getKind(arg)
        if k == CXTemplateArgument_Type
            qty = getAsType(arg)
            push!(targs, to_jl(qty))
            # elseif k == CXTemplateArgument_Integral
            #    @show getAsIntegral(arg)
        else
            # push!(targs, nothing)
        end
    end
    n = get_template_name(x)
    sym = isempty(n) ? gensym() : Symbol(n)
    return CppTemplate{CppType{sym,q},Tuple{targs...}}
end

function to_jl(x::TemplateSpecializationType, q::Qualifier=Unqualified)
    args = get_template_args(x)
    targs = []
    for arg in args
        k = getKind(arg)
        if k == CXTemplateArgument_Type
            qty = getAsType(arg)
            push!(targs, to_jl(qty))
            # elseif k == CXTemplateArgument_Integral
            #    @show getAsIntegral(arg)
        else
            # push!(targs, nothing)
        end
    end
    n = get_template_name(x)
    sym = isempty(n) ? gensym() : Symbol(n)
    return CppTemplate{CppType{sym,q},Tuple{targs...}}
end

to_jl(x::UsingType, ::Qualifier) = to_jl(x)
to_jl(x::UsingType) = to_jl(desugar(x))

to_jl(x::ElaboratedType, ::Qualifier) = to_jl(x)
to_jl(x::ElaboratedType) = to_jl(desugar(x))

to_jl(x::TypedefType, ::Qualifier) = to_jl(x)
to_jl(x::TypedefType) = to_jl(desugar(x))

to_jl(x::SubstTemplateTypeParmType, ::Qualifier) = to_jl(x)
to_jl(x::SubstTemplateTypeParmType) = to_jl(desugar(x))

function to_jl(x::PointerType, q::Qualifier=Unqualified)
    q == Unqualified ? Ptr{to_jl(get_pointee_type(x))} : CppPtr{q,to_jl(get_pointee_type(x))}
end

to_jl(x::LValueReferenceType, ::Qualifier) = to_jl(x)
to_jl(x::LValueReferenceType) = CppRef{to_jl(get_pointee_type(x))}
to_jl(x::RValueReferenceType, ::Qualifier) = to_jl(x)
to_jl(x::RValueReferenceType) = CppRvalueRef{to_jl(get_pointee_type(x))}

to_jl(x::FunctionNoProtoType, ::Qualifier) = to_jl(x)
to_jl(x::FunctionNoProtoType) = CppFuncType{to_jl(get_return_type(x))}

to_jl(x::FunctionProtoType, q::Qualifier) = to_jl(x)
function to_jl(x::FunctionProtoType)
    rt = to_jl(get_return_type(x))
    argts = to_jl.(get_params(x))
    return CppFuncType{rt,Tuple{argts...}}
end
