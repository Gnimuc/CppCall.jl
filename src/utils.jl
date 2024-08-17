make_scope(decl::NamedDecl, interp::CppInterpreter) = CppInterOp.make_scope(decl.ptr, get_ptr(interp))

@noinline gcuse(x) = x

function err_signature(func, args)
    f = CC.getName(func)
    arglist = map(x->"::"*string(x), args)
    return isnothing(func) ? "unknown($(arglist...))" : "$f($(arglist...))"
end
