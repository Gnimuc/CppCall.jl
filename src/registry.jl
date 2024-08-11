const CPPCALL_INSTANCE_ID = Threads.Atomic{Int}(0)
const CPPCALL_REGISTRY = Dict{Module,Int}()
const CPPCALL_INSTANCES = Dict{Int,CppInterpreter}()

function register(m::Module, I::CppInterpreter)
    id = Threads.atomic_add!(CPPCALL_INSTANCE_ID, 1)
    CPPCALL_REGISTRY[m] = id
    CPPCALL_INSTANCES[id] = I
end

function get_instance_id(m::Module)
    if haskey(CPPCALL_REGISTRY, m)
        return CPPCALL_REGISTRY[m]
    else
        m != Main && !isinteractive() && @warn "failed to find the interpreter instance for module $m. Using the default interpreter[CppCall]."
        return CPPCALL_REGISTRY[CppCall]
    end
end

function get_instance(m::Module)
    if haskey(CPPCALL_REGISTRY, m)
        return CPPCALL_INSTANCES[CPPCALL_REGISTRY[m]]
    else
        m != Main && !isinteractive() && @warn "failed to find the interpreter instance for module $m. Using the default interpreter[CppCall]."
        return CPPCALL_INSTANCES[CPPCALL_REGISTRY[CppCall]]
    end
end
