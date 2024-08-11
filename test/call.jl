using CppCall
using Logging
using Test

# @include "./include"
# @test_logs min_level=Logging.Error declare"""#include "func.h" """

# x = CppObject{Cint}(0)
# @fcall pblvr(x)
# @test x[] == 1

@testset "Function Call" begin
    @include "./include"

    @test_logs min_level=Logging.Error declare"""#include "func.h" """

    # void pbv(int value);
    x = CppObject{Cint}(0)
    @fcall pbv(x)
    @test x[] == 0

    # void pbp(int* ptr);
    x = CppObject{Cint}(0)
    px = Ref(x)
    @fcall pbp(px)
    @test x[] == 1

    # void pbcp(const int* ptr);
    x = @cppobj cppty"int"c
    px = Ref(x)
    @fcall pbcp(px)
    @test x[] == 0

    # void pbp2c(int* const ptr);
    x = CppObject{Cint}(0)
    px = Ref(x)
    @fcall pbp2c(px)
    @test x[] == 1

    # void pbcp2c(const int* const ptr);
    x = @cppobj cppty"int"c
    px = Ref(x)
    @fcall pbcp2c(px)
    @test x[] == 0

    # void pblvr(int& ref);
    x = CppObject{Cint}(0)
    @fcall pblvr(x)
    @test x[] == 1

    # void pbclvr(const int& ref);
    x = @cppobj cppty"int"c
    @fcall pbclvr(x)
    @test x[] == 0

    # void pbrvr(int&& ref);
    x = CppObject{Cint}(0)
    @fcall pbrvr(x)
    @test x[] == 1

    # int rbv(void);
    x = CppObject{Cint}(0)
    @fcall x = rbv()
    @test x[] == 42

    # int* rbp(void);
    # x = CppObject{Cint}(0)
    # px = Ref(x)
    # @fcall px = rbp()
    # @test x[] == 42

    # int& rbr(void);
    # x = CppObject{Cint}(0)
    # @fcall x = rbr()
    # @test x[] == 42

    # const int& rbcr(void);
    # x = @cppobj cppty"int"c
    # @fcall x = rbcr()
    # @test x[] == 42
end

@testset "Function Overloading" begin
    @include "./include"

    @test_logs min_level=Logging.Error declare"""#include "overloading.h" """

    # void increment(int value);
    x = @cppobj cppty"int"c
    @fcall increment(x)
    @test x[] == 0

    # void increment(double value);
    x = CppObject{Cdouble}(0)
    @fcall increment(x)
    @test x[] == 0.0
end
