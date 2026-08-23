# Two type languages meet in this package, and conflating them is what made the old one fragile.
#
# `to_jl` (src/types.jl) is the *user-facing* vocabulary: the type an annotation is written in
# and the type a result comes back as. It is deliberately lossy -- `long` and `long long` are
# both `Int64` -- because a caller does not want to care.
#
# `cppsig` here is the *ABI* vocabulary, used by the trampoline emitter and the overload
# resolver. It never collapses a C++ type onto a Julia one, and it is TOTAL: every `QualType`
# lands somewhere, with `CppOpaque` as the terminating fallback. Totality is the whole point.
# It lets "this type has no Julia counterpart" be a single predicate -- `machine_type` returning
# `nothing` -- instead of a list of special cases that a new C++ type silently falls off.

"""
    struct CppOpaque{S,Q} <: AbstractCppType
A C++ type with no Julia counterpart: `long double` where it is not `double`, `char16_t`, a
pointer-to-member, an array, `_Complex`. `S` is its spelling and `Q` its qualifier.

It is a tag, never a value. Storage for one is a [`CppValue`](@ref), and it crosses the
boundary by address.
"""
struct CppOpaque{S,Q} <: AbstractCppType end

# Anonymous types must still have a stable identity: the resolver compares these types, and a
# `gensym` would make a lookup answer differ between two calls in one session.
function stable_name(decl)
    n = CC.getQualifiedNameAsString(decl)
    isempty(n) && return Symbol("(anonymous@", string(hash(UInt(decl.ptr)); base=16), ")")
    return Symbol(n)
end

"""
    cppsig(x::QualType) -> Type
Return the signature-language type of `x`. Total: every C++ type maps to something.
"""
cppsig(x::QualType) = cppsig(clty_to_jlty(get_type_ptr(x)), get_qualifier(x))

# The fallback is what makes this total. Anything without a more specific method -- a builtin
# this package has no name for, a member pointer, an array -- becomes an opaque tag rather than
# recursing or asserting, which is what `to_jl` does today.
cppsig(x, q::Qualifier=Unqualified) = CppOpaque{Symbol(CC.getAsString(get_qual_type(x))),q}

cppsig(x::AbstractBuiltinType, q::Qualifier=Unqualified) = CppType{Symbol(builtin_spelling(x)),q}

# `getAsString` on the canonical builtin gives clang's own spelling -- "int", "unsigned long",
# "_Bool"/"bool" -- which is exactly what the emitter needs to write into the wrapper.
builtin_spelling(x::AbstractBuiltinType) = CC.getAsString(get_qual_type(x))

function cppsig(x::EnumType, q::Qualifier=Unqualified)
    sym = stable_name(getDecl(x))
    # a cv-qualified enum is only ever reached as a referent or pointee, where the underlying
    # type is not needed; dropping it there keeps one tag shape per qualifier
    q === Unqualified || return CppType{sym,q}
    return CppEnumType{sym,cppsig(get_integer_type(x))}
end

function cppsig(x::PointerType, q::Qualifier=Unqualified)
    pointee = cppsig(get_pointee_type(x))
    return q === Unqualified ? Ptr{pointee} : CppPtr{q,pointee}
end

# A reference is never itself cv-qualified in C++ -- `int & const` does not exist -- so the
# qualifier belongs to the referent and is already inside the recursive call.
cppsig(x::LValueReferenceType, q::Qualifier=Unqualified) = CppRef{cppsig(get_pointee_type(x))}
cppsig(x::RValueReferenceType, q::Qualifier=Unqualified) = CppRvalueRef{cppsig(get_pointee_type(x))}

function cppsig(x::AbstractRecordType, q::Qualifier=Unqualified)
    decl = getDecl(x)
    CC.isClassTemplateSpecializationDecl(decl) || return CppType{stable_name(decl),q}
    ctsd = ClassTemplateSpecializationDecl(decl)
    args = getTemplateArgs(ctsd)
    targs = Any[]
    for n = 0:(size(args) - 1)
        arg = get(args, n)
        getKind(arg) == CXTemplateArgument_Type && push!(targs, cppsig(getAsType(arg)))
    end
    return CppTemplate{CppType{Symbol(get_template_name(x)),q},Tuple{targs...}}
end

# Sugar is transparent to the ABI: what matters is the type clang will lower.
cppsig(x::ElaboratedType, q::Qualifier=Unqualified) = cppsig(desugar(x))
cppsig(x::TypedefType, q::Qualifier=Unqualified) = cppsig(desugar(x))
cppsig(x::UsingType, q::Qualifier=Unqualified) = cppsig(desugar(x))
cppsig(x::SubstTemplateTypeParmType, q::Qualifier=Unqualified) = cppsig(desugar(x))

# Machine types -----------------------------------------------------------------------------
#
# The Julia type that occupies a `ccall` slot for a signature type, or `nothing` when the C++
# type has no Julia counterpart and must travel by address instead. Returning `nothing` rather
# than throwing is deliberate: "no machine type" is a routine answer the emitter acts on, not
# an error.

const MACHINE_TYPES = Dict{String,Type}("void" => Cvoid,
                                        "bool" => Bool,
                                        "_Bool" => Bool,
                                        "char" => Cchar,
                                        "signed char" => Int8,
                                        "unsigned char" => UInt8,
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
                                        "__int128" => Int128,
                                        "unsigned __int128" => UInt128)

machine_type(::Type) = nothing
machine_type(::Type{CppType{S,Q}}) where {S,Q} = get(MACHINE_TYPES, string(S), nothing)
machine_type(::Type{CppEnumType{S,U}}) where {S,U} = machine_type(U)
# every pointer is one machine word whatever it points at; the pointee only decides which
# Julia `Ptr{...}` the *user* sees, which is `to_jl`'s job
machine_type(::Type{<:Ptr}) = Ptr{Cvoid}
machine_type(::Type{<:CppPtr}) = Ptr{Cvoid}

"""
    has_machine_type(S) -> Bool
Whether a value of signature type `S` fits in a `ccall` slot. When it does not, the trampoline
takes or returns it by address instead -- see the parameter and return tables in `wrap.jl`.
"""
has_machine_type(S) = machine_type(S) !== nothing

is_readonly(::Type{CppOpaque{S,Q}}) where {S,Q} = Q === C || Q === CV

is_const_sig(::Type) = false
is_const_sig(::Type{CppType{S,Q}}) where {S,Q} = Q === C || Q === CV
is_const_sig(::Type{CppOpaque{S,Q}}) where {S,Q} = Q === C || Q === CV
is_const_sig(::Type{CppTemplate{T,A}}) where {T,A} = is_const_sig(T)
