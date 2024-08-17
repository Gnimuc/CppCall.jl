using CppCall
using Logging
using Test

@testset "Function Call" begin
    @include "./include"

    @test_logs min_level=Logging.Error declare"""#include "func.h" """

    @info "invoke `void pbv(int value)`"
    x = @cppinit Cint
    @fcall pbv(x)
    @test x[] == 0
    # const T& -> T
    x = @cppinit cppty"int"c
    xref = @ref x
    @fcall pbv(xref)

    @info "invoke `void pbp(int* ptr)`: "
    x = @cppinit Cint
    px = @ptr x
    GC.@preserve x @fcall pbp(px)
    @test x[] == 1
    x = @cppinit cppty"int"
    x[] = 1
    px = @ptr x
    GC.@preserve x @fcall pbp(px)
    @test x[] == 2
    x = @cppinit cppty"int"c
    px = @ptr x
    @test_throws ArgumentError GC.@preserve x @fcall pbp(px) # FIXME: should be ambiguous call

    @info "invoke `void pbp2c(const int* ptr)`: "
    x = @cppinit cppty"int"c
    px = @ptr x
    GC.@preserve x @fcall pbp2c(px)
    @test x[] == 0
    x = @cppinit cppty"int"
    px = @ptr x
    GC.@preserve x @fcall pbp2c(px) # this is ok
    @test x[] == 0

    @info "invoke `void pbcp(int* const ptr)`: "
    x = @cppinit Cint
    px = @ptr x
    GC.@preserve x @fcall pbcp(px)
    @test x[] == 1
    cpx = @cptr x
    GC.@preserve x @fcall pbcp(cpx)
    @test x[] == 2
    x = @cppinit cppty"int"c
    px = @ptr x
    @test_throws ArgumentError GC.@preserve x @fcall pbcp(px) # no permissive
    x = @cppinit cppty"int"
    x[] = 2
    px = @ptr x
    GC.@preserve x @fcall pbcp(px)
    @test x[] == 3

    @info "invoke `void pbcp2c(const int* const ptr)`: "
    x = @cppinit cppty"int"c
    px = @ptr x
    GC.@preserve x @fcall pbcp2c(px)
    @test x[] == 0
    x = @cppinit cppty"int"
    px = @ptr x
    GC.@preserve x @fcall pbcp2c(px)
    @test x[] == 0
    x = @cppinit Cint
    px = @ptr x
    GC.@preserve x @fcall pbcp2c(px)
    @test x[] == 0

    @info "invoke `void pblvr(int& ref)`: "
    x = @cppinit Cint
    @fcall pblvr(x)
    @test x[] == 1
    xref = @ref x
    @fcall pblvr(xref)
    @test x[] == 2
    x = @cppinit cppty"int"c
    @test_throws ArgumentError @fcall pblvr(x) # should not discard const-qualifier
    xref = @ref x
    @test_throws ArgumentError @fcall pblvr(xref) # should not discard const-qualifier

    @info "invoke `void pbclvr(const int& ref)`: "
    x = @cppinit cppty"int"c
    x[] = 1 # FIXME: this should not be allowed
    @fcall pbclvr(x)
    @test x[] == 1
    xref = @ref x
    xref[] = 2 # FIXME: this should not be allowed
    @fcall pbclvr(xref)
    @test x[] == 2
    x = @cppinit cppty"int"
    x[] = 1
    @fcall pbclvr(x)
    @test x[] == 1
    xref = @ref x
    xref[] = 2
    @fcall pbclvr(xref)
    @test x[] == 2

    @info "invoke `void pbrvr(int&& ref)`: " # FIXME: this should not be allowed
    x = @cppinit Cint
    @fcall pbrvr(x)
    @test x[] == 1

    @info "invoke `int rbv(void)`: "
    x = @fcall rbv()
    @test x[] == 42

    @info "invoke `int* rbp(void)`: "
    p = @fcall rbp()
    @test unsafe_load(p[]) == 42

    @info "invoke `int& rbr(void)`: "
    p = @fcall rbr()
    @fcall pblvr(p)
    v = @fcall rbvpbr(p)
    @test v[] == 43 # can only be tested once

    @info "invoke `const int& rbcr(void)`: "
    p = @fcall rbcr()
    @fcall pbclvr(p)
    @test_throws ArgumentError @fcall pblvr(p)
end

@testset "Function Overloading" begin
    @include "./include"

    @test_logs min_level=Logging.Error declare"""#include "overloading.h" """

    @info "`void increment(const int& value)` vs `void increment(int value)`:"
    x = @cppinit cppty"int"c
    xref = @ref x
    @fcall increment(xref::CppRef{cppty"int"c}) # calls `void increment(const int& value)`
    @test x[] == 0
    @fcall increment(xref::Cint) # calls `void increment(int value)`
    @test x[] == 0
    @test_throws ArgumentError @fcall increment(xref) # ambiguous call

    # void increment(double value);
    x = @cppinit Cdouble
    @fcall increment(x)
    @test x[] == 0.0
end
