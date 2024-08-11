abstract type LookupKind end
struct TypeLookup <: LookupKind end
struct FuncLookup <: LookupKind end
struct FuncOverloadingLookup <: LookupKind end

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
