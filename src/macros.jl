"""
    @declare_str(code::AbstractString)
Declare the C++ code in the interpreter corresponding to the `__module__` it's being invoked.
"""
macro declare_str(code::AbstractString)
    @gensym CC_INSTANCE
    return esc(quote
                   local $CC_INSTANCE = CppCall.get_instance($__module__)
                   CppCall.declare($CC_INSTANCE, $code)
               end)
end

"""
    @include path
Add include search path to the interpreter corresponding to the `__module__` it's being invoked.
"""
macro include(path)
    @gensym CC_INSTANCE CC_PATH
    filename = string(__source__.file)
    prefix = startswith(filename, "REPL") ? pwd() : dirname(filename)
    return esc(quote
                   local $CC_INSTANCE = CppCall.get_instance($__module__)
                   local $CC_PATH = joinpath($prefix, $path) |> normpath
                   CppCall.cppinclude($CC_INSTANCE, $CC_PATH)
               end)
end

"""
    @__INSTANCE__ -> CppInterpreter
Macro to obtain the `CppInterpreter` instance corresponding to the `__module__` it's being invoked.
"""
macro __INSTANCE__()
    return esc(quote
                   CppCall.get_instance($__module__)
               end)
end

"""
    @undo(i)
Undo the last `i`-steps of the `CppInterpreter` instance corresponding to the `__module__` it's being invoked.
"""
macro undo(i)
    @gensym CC_INSTANCE
    return esc(quote
                   local $CC_INSTANCE = CppCall.get_instance($__module__)
                   CppCall.undo($CC_INSTANCE.interpreter, $i)
               end)
end

"""
    @cppinit cppty
Create a C++ object of type `cppty` with zero initialized values.
"""
macro cppinit(cppty)
    @gensym CC_INSTANCE CC_CLTY CC_JLTY CC_SIZE
    return esc(quote
                   local $CC_INSTANCE = CppCall.get_instance($__module__)
                   local $CC_CLTY = CppCall.to_cpp($cppty, $CC_INSTANCE)
                   local $CC_JLTY = CppCall.to_jl($CC_CLTY)
                   local $CC_SIZE = CppCall.size_of(CppCall.get_ast_context($CC_INSTANCE), $CC_CLTY)
                   CppObject{$CC_JLTY,$CC_SIZE}()
               end)
end

"""
    @ptr obj
Create a C++ object that represents a `Unqualified`-pointer to `obj`.
"""
macro ptr(obj)
    return esc(:(CppObject{Ptr}($obj)))
end

"""
    @cptr obj
Create a C++ object that represents a `Const_Qualified`-pointer to `obj`.
"""
macro cptr(obj)
    return esc(:(CppObject{CppCPtr}($obj)))
end

"""
    @vptr obj
Create a C++ object that represents a `Volatile_Qualified`-pointer to `obj`.
"""
macro vptr(obj)
    return esc(:(CppObject{CppVPtr}($obj)))
end

"""
    @cvptr obj
Create a C++ object that represents a `Const_Volatile_Qualified`-pointer to `obj`.
"""
macro cvptr(obj)
    return esc(:(CppObject{CppCVPtr}($obj)))
end

"""
    @ref obj
Create a C++ object that represents a reference to `obj`.
"""
macro ref(obj)
    @gensym CC_VAR CC_X
    return esc(
        quote
            $CC_VAR = CppObject{CppRef}($obj)
            finalizer($CC_VAR) do $CC_X
                CppCall.gcuse($obj)
                $CC_X
            end
            $CC_VAR
        end
    )
end

"""
    @cppnew cppty [args...]
Create a C++ object of type `cppty` with the given initialization values.
"""
macro cppnew(cppty, args...)
    @gensym CC_INSTANCE CC_CLTY CC_JLTY
    return esc(quote
                   local $CC_INSTANCE = CppCall.get_instance($__module__)
                   local $CC_CLTY = CppCall.to_cpp($cppty, $CC_INSTANCE)
                   local $CC_JLTY = CppCall.to_jl($CC_CLTY)
                   CppObject{$CC_JLTY}($(args...))
               end)
end


"""
    @cpp_str -> CppType

Construct a `CppType` with optional qualifiers marked by the flags `c`, `v`, `cv`.
"""
macro cpp_str(name::AbstractString, flags...)
    qualifier = :(CppCall.U)
    if !isempty(flags)
        flag = first(flags)
        qualifier = flag == "cv" ? :(CppCall.CV) :
                    flag == "c" ? :(CppCall.C) :
                    flag == "v" ? :(CppCall.V) : :(CppCall.U)
    end
    return :(CppType(strip($name), $qualifier))
end

macro qualty_str(name::AbstractString, flags...)
    qualifier = :(CppCall.U)
    if !isempty(flags)
        flag = first(flags)
        qualifier = flag == "cv" ? :(CppCall.CV) :
                    flag == "c" ? :(CppCall.C) :
                    flag == "v" ? :(CppCall.V) : :(CppCall.U)
    end
    @gensym CC_INSTANCE
    return esc(quote
                   local $CC_INSTANCE = CppCall.get_instance($__module__)
                   CppCall.to_cpp(CppType{Symbol($name),$qualifier}, $CC_INSTANCE)
               end)
end
