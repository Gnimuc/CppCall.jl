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
A C++ pointer that carries its own cv-qualification, for the cases where `Ptr{T}` cannot:
`T *const` and `T *volatile` differ from `T *` in the pointer, not the pointee.
"""
primitive type GenericCppPtr{Q,T,AS} <: AbstractCppType 8 * sizeof(Int) end

const CppPtr{Q,T} = GenericCppPtr{Q,T,Core.CPU}

const CppCPtr{T} = CppPtr{C,T}
const CppVPtr{T} = CppPtr{V,T}
const CppCVPtr{T} = CppPtr{CV,T}

Base.unsafe_convert(::Type{Ptr{Cvoid}}, x::CppPtr) = reinterpret(Ptr{Cvoid}, x)
CppPtr{Q,T}(p::Ptr) where {Q,T} = reinterpret(CppPtr{Q,T}, p)
Base.pointer(x::CppPtr{Q,T}) where {Q,T} = reinterpret(Ptr{T}, x)

unwrap_type(::Type{CppPtr{Q,T}}) where {Q,T} = T

is_const_ptr(::Type{CppPtr{Q,T}}) where {Q,T} = Q === C || Q === CV
is_volatile_ptr(::Type{CppPtr{Q,T}}) where {Q,T} = Q === V || Q === CV
is_const_ptr(::Type{<:Ptr}) = false
is_volatile_ptr(::Type{<:Ptr}) = false
is_const_ptr(x) = is_const_ptr(typeof(x))
is_volatile_ptr(x) = is_volatile_ptr(typeof(x))

"""
    struct CppRef{T} <: AbstractCppType
A C++ lvalue: the address of an object, plus whatever Julia object owns the storage.

`owner` is what makes a reference safe to hold. A raw `Ptr` into a Julia-owned buffer is
collectable the moment the last other binding goes away; a `CppRef` keeps its referent alive
for exactly as long as the reference itself is reachable. It is `nothing` when the referent
belongs to C++ -- a reference returned from a call -- where Julia has nothing to keep alive.
"""
struct CppRef{T} <: AbstractCppType
    ptr::Ptr{Cvoid}
    owner::Any
end

CppRef{T}(p::Ptr) where {T} = CppRef{T}(reinterpret(Ptr{Cvoid}, p), nothing)

"""
    struct CppRvalueRef{T} <: AbstractCppType
A C++ xvalue -- what `@move` produces, and what a `T&&` return yields. Binding one to a
parameter permits the callee to move from it.
"""
struct CppRvalueRef{T} <: AbstractCppType
    ptr::Ptr{Cvoid}
    owner::Any
end

CppRvalueRef{T}(p::Ptr) where {T} = CppRvalueRef{T}(reinterpret(Ptr{Cvoid}, p), nothing)

const AnyCppRef{T} = Union{CppRef{T},CppRvalueRef{T}}

unwrap_type(::Type{CppRef{T}}) where {T} = T
unwrap_type(::Type{CppRvalueRef{T}}) where {T} = T

Base.unsafe_convert(::Type{Ptr{Cvoid}}, x::AnyCppRef) = x.ptr
# `cconvert` returning the reference itself is what roots `owner` for the duration of a ccall:
# Julia keeps the `cconvert` result alive across the call, and the reference holds the owner.
Base.cconvert(::Type{Ptr{Cvoid}}, x::AnyCppRef) = x

Base.getindex(x::AnyCppRef{T}) where {T} = unsafe_load(reinterpret(Ptr{machine_type_of(T)}, x.ptr))

function Base.setindex!(x::CppRef{T}, v) where {T}
    is_readonly(T) && error("assignment to a reference to const")
    M = machine_type_of(T)
    unsafe_store!(reinterpret(Ptr{M}, x.ptr), convert(M, v))
    return v
end

"""
    struct CppEnumValue{S,U} <: AbstractCppType
A C++ enumerator value. `S` names the enum type and `U` is its underlying integer type. It is
isbits, so it lives on the stack like any other Julia value.
"""
struct CppEnumValue{S,U} <: AbstractCppType
    val::U
end

Base.getindex(x::CppEnumValue) = x.val
Base.convert(::Type{T}, x::CppEnumValue) where {T<:Integer} = convert(T, x.val)
(::Type{T})(x::CppEnumValue) where {T<:Integer} = T(x.val)
Base.:(==)(x::CppEnumValue, y::Number) = x.val == y
Base.:(==)(x::Number, y::CppEnumValue) = x == y.val
Base.:(==)(x::CppEnumValue{S,U}, y::CppEnumValue{S,U}) where {S,U} = x.val == y.val
Base.show(io::IO, x::CppEnumValue{S,U}) where {S,U} = print(io, S, "(", x.val, ")")

"""
    struct CppValue{T,N} <: Any
Storage for a C++ value with no Julia counterpart -- a class or union passed or returned by
value, a `long double`, a pointer-to-member.

It is an immutable `NTuple` of bytes, so it is isbits and lives on the stack. Getting an
address for it -- which a call needs -- is `Ref(v)`, exactly as for any other Julia value.
"""
struct CppValue{T,N}
    data::NTuple{N,UInt8}
end

CppValue{T,N}() where {T,N} = CppValue{T,N}(ntuple(Returns(0x00), N))

unwrap_type(::Type{CppValue{T,N}}) where {T,N} = T
unwrap_size(::Type{CppValue{T,N}}) where {T,N} = N

Base.sizeof(::Type{CppValue{T,N}}) where {T,N} = N

# The machine type behind a user-facing type, for reading and writing through a reference.
machine_type_of(::Type{T}) where {T} = T
# NB: not `something(machine_type(...), error(...))` -- `something` is an ordinary function, so
# its second argument is evaluated first and the error would fire unconditionally.
function machine_type_of(::Type{CppType{S,Q}}) where {S,Q}
    m = machine_type(CppType{S,Unqualified})
    m === nothing && error("`$S` has no Julia machine type")
    return m
end
machine_type_of(::Type{CppEnumType{S,U}}) where {S,U} = U
machine_type_of(::Type{CppEnumValue{S,U}}) where {S,U} = U

is_readonly(::Type) = false
is_readonly(::Type{CppType{S,Q}}) where {S,Q} = Q === C || Q === CV
is_readonly(::Type{CppTemplate{T,A}}) where {T,A} = is_readonly(T)
# the CppOpaque method lives in sig.jl, beside the type it dispatches on

# type mapping
"""
    to_cpp(::Type{T}, I::CppInterpreter) -> QualType
Return a Clang type in memory representation corresponding to the Julia type `T`.
"""
to_cpp(::Type{T}, I::CppInterpreter) where {T<:AbstractCppType} = error("Unsupported type: $T")

to_cpp(::Type{T}, I::CppInterpreter) where {T<:BuiltinTypes} = get_qual_type(jlty_to_clty(T, get_ast_context(I)))
to_cpp(::Type{Ptr{T}}, I::CppInterpreter) where {T<:BuiltinTypes} = get_pointer_type(get_ast_context(I), to_cpp(T, I))

# lookups hand back the `NamedDecl` base carrier, so the concrete kind has to be recovered
# before asking for a type: a value declaration (a function, a variable, an enumerator) has
# the type it was declared with, while a type declaration *is* one
function to_cpp(x::AbstractNamedDecl, I::CppInterpreter)
    decl = CC.resolve(x)
    decl isa AbstractValueDecl && return getType(decl)
    return get_decl_type(get_ast_context(I), decl)
end

to_cpp(x::AbstractValueDecl, I::CppInterpreter) = getType(x)

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

"""
    instantiate(::Type{T}, I::CppInterpreter) where {T<:CppTemplate} -> QualType
Return the Clang type of the class template specialization `T` names, instantiating it in
the interpreter if this is the first time it is asked for.
"""
function instantiate(::Type{CppTemplate{T,TARGS}}, I::CppInterpreter) where {S,Q,T<:CppType{S,Q},TARGS}
    args = join((spell(I, to_cpp(t, I)) for t in TARGS.types), ", ")
    return specialize(I, string(S) * "<" * args * ">")
end

to_cpp(::Type{T}, I::CppInterpreter) where {T<:CppTemplate} = instantiate(T, I)

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
to_jl(x::CC.CharTy) = Cchar
to_jl(x::CC.WCharTy) = Cwchar_t
to_jl(x::CC.WideCharTy) = Cwchar_t
to_jl(x::CC.SignedCharTy) = Int8
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

# A builtin with no explicit method above lands here rather than recursing: `long double`,
# `char16_t` and friends have no Julia counterpart, and saying so is a routine answer.
to_jl(x::AbstractBuiltinType) = CppType{Symbol(builtin_spelling(x)),Unqualified}

function to_jl(x::AbstractBuiltinType, q::Qualifier)
    q === Unqualified && return to_jl(x)
    return CppType{Symbol(builtin_spelling(x)),q}
end

function to_jl(x::EnumType, q::Qualifier=Unqualified)
    sym = stable_name(getDecl(x))
    q === Unqualified || return CppType{sym,q}
    return CppEnumType{sym,to_jl(get_integer_type(x))}
end

function to_jl(x::AbstractRecordType, q::Qualifier=Unqualified)
    decl = getDecl(x)
    # a plain record is not a specialization, and the cast to one is checked
    if !CC.isClassTemplateSpecializationDecl(decl)
        n = get_name(x)
        sym = isempty(n) ? stable_name(decl) : Symbol(n)
        return CppType{sym,q}
    end
    ctsd = ClassTemplateSpecializationDecl(decl)
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
    sym = isempty(n) ? stable_name(getDecl(x)) : Symbol(n)
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
    # a TemplateSpecializationType has no decl to name; fall back to its own spelling
    sym = isempty(n) ? Symbol(CC.getAsString(get_qual_type(x))) : Symbol(n)
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
