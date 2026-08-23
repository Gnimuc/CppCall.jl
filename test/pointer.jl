using CppCall
using CppCall: is_const_ptr, is_volatile_ptr, unwrap_type
using Test

@testset "Pointer" begin
    x = Ref(Cint(0))
    px = @ptr x                             # int *
    const_px = CppCPtr{Cint}(px)            # int *const
    volatile_px = CppVPtr{Cint}(px)         # int *volatile
    const_volatile_px = CppCVPtr{Cint}(px)  # int *const volatile

    # a plain `T *` is Julia's own `Ptr{T}`; only the cv-qualified forms need a `CppPtr`
    @test px isa Ptr{Cint}

    @test is_const_ptr(const_px)
    @test !is_const_ptr(px)
    @test is_volatile_ptr(volatile_px)
    @test !is_volatile_ptr(px)
    @test is_const_ptr(const_volatile_px)
    @test is_volatile_ptr(const_volatile_px)
    @test !is_const_ptr(volatile_px)
    @test !is_volatile_ptr(const_px)

    # the qualification lives in the type; the value is a machine word either way
    @test sizeof(CppCPtr{Cint}) == sizeof(Ptr{Cint})
    @test unwrap_type(CppCPtr{Cint}) === Cint
    @test pointer(const_px) === px

    # and it addresses the very storage the `Ref` owns
    GC.@preserve x begin
        unsafe_store!(pointer(const_px), Cint(7))
        @test unsafe_load(px) == 7
    end
    @test x[] == 7
end

@testset "Pass-by-pointer" begin
    @include "./include"

    declare"""#include "pointer.h" """

    # `void passbyptr(int *value)` -- increments through the pointer
    x = Ref(Cint(41))
    px = @ptr x
    @test px isa Ptr{Cint}
    GC.@preserve x @fcall passbyptr(px)
    @test x[] == 42

    # a `Ref` is the storage, so it stands in for `int *` on its own -- and `ccall` roots it,
    # which is why this one needs no `GC.@preserve`
    @fcall passbyptr(x)
    @test x[] == 43

    # `@ref` roots its owner too, and hands back the same address
    rx = @ref x
    @test rx isa CppRef{Cint}
    @test (@ptr rx) === px
    @fcall passbyptr(rx)
    @test x[] == 44
    @test rx[] == 44

    # `void passbyptr(int **value)` -- a tower is built by taking the address of a `Ref` that
    # holds the pointer below it
    rpx = Ref(px)
    ppx = @ptr rpx
    @test ppx isa Ptr{Ptr{Cint}}
    GC.@preserve x rpx @fcall passbyptr(ppx)
    @test x[] == 45

    # an annotation asserts the parameter type outright, which pins down which rung is meant
    GC.@preserve x rpx @fcall passbyptr(ppx::Ptr{Ptr{Cint}})
    @test x[] == 46
    @test_throws ArgumentError GC.@preserve x rpx @fcall passbyptr(ppx::Ptr{Cint})
    @test x[] == 46

    # `void passbyptr(int ***value)`
    rppx = Ref(ppx)
    pppx = @ptr rppx
    @test pppx isa Ptr{Ptr{Ptr{Cint}}}
    GC.@preserve x rpx rppx @fcall passbyptr(pppx)
    @test x[] == 47

    # `int ***const` -- top-level const on an argument is dropped for overload resolution,
    # so this still picks `passbyptr(int ***)`
    cpppx = CppCPtr{Ptr{Ptr{Cint}}}(pppx)
    @test is_const_ptr(cpppx)
    GC.@preserve x rpx rppx @fcall passbyptr(cpppx)
    @test x[] == 48

    # `void passbyptr(int **const *value)` -- here the const is on the *pointee* pointer, so
    # the storage the argument addresses has to be a `CppCPtr`. This overload only reads.
    rcppx = Ref(CppCPtr{Ptr{Cint}}(ppx))
    pcppx = @ptr rcppx
    @test pcppx isa Ptr{CppCPtr{Ptr{Cint}}}
    GC.@preserve x rpx rcppx @fcall passbyptr(pcppx)
    @test x[] == 48

    # `void passbyptr2c(const int **value)` -- `int **` does not convert to `const int **`,
    # exactly as in C++
    @test_throws ArgumentError GC.@preserve x rpx @fcall passbyptr2c(ppx)
    pcx = reinterpret(Ptr{cpp"int"c}, px)   # const int *
    rpcx = Ref(pcx)
    ppcx = @ptr rpcx
    @test ppcx isa Ptr{Ptr{cpp"int"c}}
    GC.@preserve x rpcx @fcall passbyptr2c(ppcx)
    @test x[] == 48

    # `void passbyptrc(int ***const value)` -- const on the parameter itself is not part of
    # the signature, so both an `int ***` and an `int ***const` bind it
    GC.@preserve x rpx rppx @fcall passbyptrc(pppx)
    @test x[] == 49
    GC.@preserve x rpx rppx @fcall passbyptrc(cpppx)
    @test x[] == 50

    # `int **returnptrptr(void)` -- the result is a plain `Ptr{Ptr{Cint}}` addressing C++-owned
    # storage, so it needs no rooting and can be fed straight back in
    pp = @fcall returnptrptr()
    @test pp isa Ptr{Ptr{Cint}}
    @test unsafe_load(unsafe_load(pp)) == 42
    @fcall passbyptr(pp)
    @test unsafe_load(unsafe_load(pp)) == 43

    # `int *const *returnptrcptr(void)` -- the const sits on the pointee pointer, so the
    # returned type carries it as a `CppCPtr`
    pcp = @fcall returnptrcptr()
    @test pcp isa Ptr{CppCPtr{Cint}}
    @test unsafe_load(pointer(unsafe_load(pcp))) == 42

    # invalid conversion from `int *const *` to `int **`, so no overload of `passbyptr` matches
    @test_throws ArgumentError @fcall passbyptr(pcp)

    declare"""void passbyptrcptr(int *const *p) { std::cout << **p << std::endl; }"""
    @fcall passbyptrcptr(pcp)

    @cppdelete unsafe_load(pp)
    @cppdelete pp
    @cppdelete pointer(unsafe_load(pcp))
    @cppdelete pcp
end
