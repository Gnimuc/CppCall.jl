struct CppInterpreter
    interpreter::CppInterOp.Interpreter
    bridge::ClangCompiler.CxxInterpreter
    lookup_type::DeclFinder
    lookup_func::DeclFinder
end

is_valid(x::CppInterpreter) = CppInterOp.is_valid(x.interpreter)

get_ptr(x::CppInterpreter) = x.interpreter.ptr

"""
    initialize(; args::Vector{String}=String[], is_cxx::Bool=true, version::String=JLLEnvs.GCC_MIN_VER) -> CppInterpreter
Create a C/C++ interpreter instance.

# Arguments
- `args::Vector{String}`: Compiler flags.
- `is_cxx::Bool`: Whether to use the C++ compiler build environment.
- `version::String`: The compiler version.
"""
function initialize(args::Vector{String}=String[]; is_cxx=true, version=JLLEnvs.GCC_MIN_VER)
    I = create_interpreter(args; is_cxx, version)
    CxxI = CC.CxxInterpreter(getptr(I))
    return CppInterpreter(I, CxxI, DeclFinder(CxxI, CC.CXLookupNameKind_LookupTagName), DeclFinder(CxxI))
end

terminate(x::CppInterpreter) = dispose(x.interpreter)

function declare(x::CppInterpreter, code::AbstractString, silent::Bool=false)
    if !CppInterOp.declare(x.interpreter, code, silent)
        @error "failed to declare the code. Please fix the error and try again."
    end
    return nothing
end

lookup_func(x::CppInterpreter, name::AbstractString) = x.lookup_func(x.bridge, name)
lookup_type(x::CppInterpreter, name::AbstractString) = x.lookup_type(x.bridge, name)

get_type_decl(x::CppInterpreter) = get_decl(x.lookup_type)
get_func_decl(x::CppInterpreter) = get_decl(x.lookup_func)
get_func_decls(x::CppInterpreter) = get_decls(x.lookup_func)

get_compiler_instance(x::CppInterpreter) = CC.get_instance(x.bridge)
get_ast_context(x::CppInterpreter) = CC.get_ast_context(x.bridge)

cppinclude(x::CppInterpreter, path::AbstractString) = CppInterOp.addIncludePath(x.interpreter, path)
