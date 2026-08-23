"""
    struct CppInterpreter
Hold Clang's incremental interpreter together with the lookup state and the caches of the
JIT-compiled glue code that is built on top of it.

The interpreter owns C++ resources, so it has to be released with [`terminate`](@ref).
"""
struct CppInterpreter
    bridge::ClangCompiler.CxxInterpreter
    lookup_type::DeclFinder
    lookup_func::DeclFinder
    # decl address -> address of its `extern "C"` call trampoline, see `wrap.jl`. Keyed by
    # the bare integer because ClangCompiler gives each handle class its own pointer type.
    wrappers::Dict{UInt,Ptr{Cvoid}}
    # C++ spelling of a type -> address of the function that heap-allocates one
    builders::Dict{String,Ptr{Cvoid}}
    # C++ spelling of a template-id -> the type Clang instantiated for it
    aliases::Dict{String,QualType}
    include_paths::Set{String}
    counter::Base.RefValue{Int}
    active::Base.RefValue{Bool}
    # namespace holding the runtime support code, empty until it has been compiled
    runtime::Base.RefValue{String}
end

get_ptr(x::CppInterpreter) = x.bridge.interp.ptr

is_valid(x::CppInterpreter) = x.active[] && get_ptr(x) != C_NULL

"""
    initialize(; args::Vector{String}=String[], is_cxx::Bool=true, version::String=JLLEnvs.GCC_MIN_VER) -> CppInterpreter
Create a C/C++ interpreter instance.

# Arguments
- `args::Vector{String}`: Compiler flags.
- `is_cxx::Bool`: Whether to use the C++ compiler build environment.
- `version::String`: The compiler version.
"""
function initialize(args::Vector{String}=String[]; is_cxx=true, version=JLLEnvs.GCC_MIN_VER)
    CxxI = CC.create_interpreter(args; is_cxx, version)
    return CppInterpreter(CxxI, DeclFinder(CxxI, CC.CXLookupNameKind_LookupTagName),
                          DeclFinder(CxxI), Dict{UInt,Ptr{Cvoid}}(),
                          Dict{String,Ptr{Cvoid}}(), Dict{String,QualType}(), Set{String}(),
                          Ref(0), Ref(true), Ref(""))
end

"""
    terminate(x::CppInterpreter)
Release the interpreter and everything JIT-compiled into it. Calling it twice is a no-op.
"""
function terminate(x::CppInterpreter)
    is_valid(x) || return nothing
    x.active[] = false
    empty!(x.wrappers)
    empty!(x.builders)
    empty!(x.aliases)
    # the lookup state points into the Sema the interpreter owns, so it has to go first
    CC.dispose(x.lookup_type)
    CC.dispose(x.lookup_func)
    CC.dispose(x.bridge)
    return nothing
end

"""
    declare(x::CppInterpreter, code::AbstractString, silent::Bool=false) -> Bool
Feed `code` to the interpreter and run whatever it defines, returning whether it compiled.
Clang reports the diagnostics itself; `silent` only suppresses the summary logged here.
"""
function declare(x::CppInterpreter, code::AbstractString, silent::Bool=false)
    ptu = CC.parse(x.bridge, String(code))
    if ptu.ptr == C_NULL
        # a rejected input leaves the engine latched in its error state, which would fail
        # every later declaration for a mistake the user has already been told about
        CC.Reset(CC.getDiagnostics(get_compiler_instance(x)), true)
        silent || @error "failed to declare the code. Please fix the error and try again."
        return false
    end
    CC.execute(x.bridge, ptu)
    return true
end

"""
    undo(x::CppInterpreter, n::Integer=1)
Roll back the last `n` declarations. Everything CppCall has JIT-compiled against the
interpreter is dropped too, since the code it was built from may be gone.
"""
function undo(x::CppInterpreter, n::Integer=1)
    CC.undo(x.bridge.interp, n)
    empty!(x.wrappers)
    empty!(x.builders)
    empty!(x.aliases)
    x.runtime[] = ""
    return nothing
end

lookup_func(x::CppInterpreter, name::AbstractString) = x.lookup_func(x.bridge, name)
lookup_type(x::CppInterpreter, name::AbstractString) = x.lookup_type(x.bridge, name)

get_type_decl(x::CppInterpreter) = get_decl(x.lookup_type)
get_func_decl(x::CppInterpreter) = get_decl(x.lookup_func)
get_func_decls(x::CppInterpreter) = get_decls(x.lookup_func)

get_compiler_instance(x::CppInterpreter) = CC.get_instance(x.bridge)
get_ast_context(x::CppInterpreter) = CC.get_ast_context(x.bridge)
get_sema(x::CppInterpreter) = CC.get_sema(x.bridge)

"""
    cppinclude(x::CppInterpreter, path::AbstractString)
Add `path` to the interpreter's header search path.

The directory is appended after every path already registered rather than spliced in at the
user/system boundary: an insertion shifts the indices the header search has already cached
for the headers it resolved, and those caches cannot be repaired from here.
"""
function cppinclude(x::CppInterpreter, path::AbstractString)
    dir = String(path)
    dir in x.include_paths && return nothing
    ci = get_compiler_instance(x)
    fm = CC.getFileManager(ci)
    ref = CC.getOptionalDirectoryRef(fm, dir)
    if ref === nothing
        @error "failed to add the include search path: no such directory: $dir"
        return nothing
    end
    lookup = CC.DirectoryLookup(ref, CC.CXCharacteristicKind_C_User)
    CC.AddSystemSearchPath(CC.getHeaderSearchInfo(CC.getPreprocessor(ci)), lookup)
    CC.dispose(lookup)
    CC.dispose(ref)
    push!(x.include_paths, dir)
    return nothing
end
