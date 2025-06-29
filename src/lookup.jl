abstract type LookupKind end
struct TypeLookup <: LookupKind end
struct FuncLookup <: LookupKind end
struct FuncOverloadingLookup <: LookupKind end
struct EnumLookup <: LookupKind end
struct ConstructorLookup <: LookupKind end

lookup(I::CppInterpreter, id::AbstractString, kind::LookupKind=TypeLookup()) = lookup(I, id, kind)

function lookup(I::CppInterpreter, id::AbstractString, kind::TypeLookup)
    lookup_type(I, id) || error("failed to find the identifer: $id")
    decl = get_type_decl(I)
    return decl
end

function lookup(I::CppInterpreter, id::AbstractString, kind::FuncLookup)
    lookup_func(I, id) || error("failed to find the identifer: $id")
    decl = get_func_decl(I)
    return decl
end

function lookup(I::CppInterpreter, id::AbstractString, kind::FuncOverloadingLookup)
    lookup_func(I, id) || error("failed to find the identifer: $id")
    decls = get_func_decls(I)
    return decls
end

function lookup(I::CppInterpreter, id::AbstractString, kind::EnumLookup)
    lookup_func(I, id) || error("failed to find the identifer: $id")
    decl = get_func_decl(I)
    return decl
end

function lookup(I::CppInterpreter, id::AbstractString, kind::ConstructorLookup)
    lookup_type(I, id) || error("failed to find the identifer: $id")
    ty_decl = get_type_decl(I)
    ctors = CXXConstructorDecl[]
    for decl in CC.DeclIterator(ty_decl)
        ctor = CXXConstructorDecl(decl)
        ctor.ptr == C_NULL && continue
        push!(ctors, ctor)
    end
    return ctors
end
