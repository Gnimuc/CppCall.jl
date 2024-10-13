module CppCall

using ClangCompiler
using ClangCompiler: AbstractClangType, AbstractType, AbstractBuiltinType, AbstractRecordType
using ClangCompiler: QualType, RecordType, EnumType, ElaboratedType, TypedefType
using ClangCompiler: PointerType, LValueReferenceType, RValueReferenceType
using ClangCompiler: FunctionNoProtoType, FunctionProtoType
using ClangCompiler: CXXConstructorDecl, CXXDestructorDecl, CXXMethodDecl
using ClangCompiler: TypeDecl, RecordDecl, NamedDecl, CXXRecordDecl
using ClangCompiler: get_type_ptr, get_qual_type, get_decl_type, get_pointee_type, desugar
using ClangCompiler: get_return_type, get_params, get_param_num, get_param_type, get_integer_type
using ClangCompiler: get_pointer_type
using ClangCompiler: add_const, add_volatile, is_const, is_volatile
using ClangCompiler: clty_to_jlty, jlty_to_clty, is_builtin_type
using ClangCompiler: size_of
using ClangCompiler: DeclFinder, get_decl, get_decls

import ClangCompiler as CC

using CppInterOp
using CppInterOp: JLLEnvs
using CppInterOp: create_interpreter, dispose
using CppInterOp: addIncludePath, getptr, undo
using CppInterOp: CXScope
using CppInterOp: invoke, construct, destruct, allocate, deallocate
using CppInterOp: getFunctionSignature

include("interpreter.jl")
export initialize, is_valid, terminate
export cppinclude, declare

include("utils.jl")

include("lookup.jl")
export LookupKind, TypeLookup, FuncLookup, FuncOverloadingLookup, lookup

include("types.jl")
export CppType, CppFunc, CppRef, CppObject
export CppPtr, CppCPtr, CppVPtr, CppCVPtr
export CppTemplate

include("typemap.jl")
export cpptypemap

include("convert.jl")

include("macros.jl")
export @declare_str, @include
export @cpp_str, @qualty
export @cppinit, @cppnew, @cppdelete
export @ptr, @cptr, @vptr, @cvptr, @ref, @template

include("registry.jl")
export register, get_instance, get_instance_id

function __init__()
    try
        register(CppCall, initialize())
    catch e
        @warn "failed to initialize the default interpreter: $e"
    end

    atexit() do
        for (_, I) in CPPCALL_INSTANCES
            terminate(I)
        end
    end
end

include("call.jl")
export @fcall, @mcall, @ctor

end # module
