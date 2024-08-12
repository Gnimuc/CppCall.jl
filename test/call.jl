using CppCall
using Logging
using Test

@testset "Function Call" begin
    @include "./include"

    @test_logs min_level=Logging.Error declare"""#include "func.h" """

    # void pbv(int value);
    x = @cppinit Cint
    @fcall pbv(x)
    @test x[] == 0

    # void pbp(int* ptr);
    x = @cppinit Cint
    px = @ptr x
    @fcall pbp(px)
    @test x[] == 1

    # void pbp2c(const int* ptr);
    x = @cppinit cppty"int"c
    px = @ptr x
    @fcall pbp2c(px)
    @test x[] == 0

    # void pbcp(int* const ptr);
    x = @cppinit Cint
    px = @ptr x
    @fcall pbcp(px)
    @test x[] == 1
    cpx = @cptr x
    @fcall pbcp(cpx)
    @test x[] == 2

    # void pbcp2c(const int* const ptr);
    x = @cppinit cppty"int"c
    px = @ptr x
    @fcall pbcp2c(px)
    @test x[] == 0

    # void pblvr(int& ref);
    x = @cppinit Cint
    @fcall pblvr(x)
    @test x[] == 1

    # void pbclvr(const int& ref);
    x = @cppinit cppty"int"c
    @fcall pbclvr(x)
    @test x[] == 0

    # void pbrvr(int&& ref);
    x = @cppinit Cint
    @fcall pbrvr(x)
    @test x[] == 1

    # int rbv(void);
    x = @cppinit Cint
    @fcall x = rbv()
    @test x[] == 42

    # int* rbp(void);
    p = @cppinit Ptr{cppty"int"}
    @fcall px = rbp()
    @test unsafe_load(px[]) == 42

    # int& rbr(void);
    p = @cppinit Ptr{cppty"int"}
    @fcall p = rbr()
    @test unsafe_load(p[]) == 42

    # const int& rbcr(void);
    p = @cppinit Ptr{cppty"int"c}
    @fcall p = rbcr()
    @test unsafe_load(p[]) == 42
end

@testset "Function Overloading" begin
    @include "./include"

    @test_logs min_level=Logging.Error declare"""#include "overloading.h" """

    # void increment(const int& value);
    x = @cppinit cppty"int"c
    @fcall increment(x)
    @test x[] == 0

    # void increment(double value);
    x = @cppinit Cdouble
    @fcall increment(x)
    @test x[] == 0.0
end
