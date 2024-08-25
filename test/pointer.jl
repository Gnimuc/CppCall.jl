using CppCall
using CppCall: is_const_ptr, is_volatile_ptr
using Test

@testset "Pointer" begin
    x = @cppinit Cint
    px = @ptr x
    const_px = @cptr x
    volatile_px = @vptr x
    const_volatile_px = @cvptr x

    @test is_const_ptr(const_px)
    @test !is_const_ptr(px)
    @test is_volatile_ptr(volatile_px)
    @test !is_volatile_ptr(px)
    @test is_const_ptr(const_volatile_px)
    @test is_volatile_ptr(const_volatile_px)
    @test !is_const_ptr(volatile_px)
    @test !is_volatile_ptr(const_px)
end

@testset "Pass-by-pointer" begin
    @include "./include"

    declare"""#include "pointer.h" """

    @info "invoke `void passbyptr(int* value)`: "
    x = @cppinit Cint
    px = @ptr x
    GC.@preserve x @fcall passbyptr(px)

    @info "invoke `int **returnptrptr(int *value)`: "
    pp = @fcall returnptrptr()

    @info "invoke `void passbyptr(int** value)`: "
    @fcall passbyptr(pp)

    @info "invoke `int *const *returnptrcptr(void)`: "
    pcp = @fcall returnptrcptr()
    @info "invoke `void passbyptr(int** value)`: "
    @test_throws ArgumentError @fcall passbyptr(pcp) # invalid conversion from 'int* const*' to 'int**' # FIXME: when running the second time, segfaults on `TextDiagnosticPrinter.cpp, line 149`

    declare"""void passbyptrcptr(int *const *p) { std::cout << **p << std::endl; }"""
    @fcall passbyptrcptr(pcp)

    @info "invoke `void passbyptr(int **value)`: "
    ppx = @ptr px
    GC.@preserve x px ppx @fcall passbyptr(ppx)

    @info "invoke `void passbyptr(int ***value)`: "
    pppx = @ptr ppx
    GC.@preserve x px ppx pppx @fcall passbyptr(pppx)
    cpppx = @cptr ppx
    GC.@preserve x px ppx cpppx @fcall passbyptr(cpppx)

    @info "invoke `void passbyptr(int ** const *value)`: "
    cppx = @cptr px
    pcppx = @ptr cppx
    GC.@preserve x px cppx pcppx @fcall passbyptr(pcppx)

    @info "invoke `void passbyptr2c(const int **value)`: "
    @test_throws ArgumentError GC.@preserve x px ppx @fcall passbyptr2c(ppx) # invalid conversion from 'int**' to 'const int**'
    cx = @cppinit cpp"int"c
    pcx = @ptr cx
    ppcx = @ptr pcx
    GC.@preserve cx pcx ppcx @fcall passbyptr2c(ppcx)

    @info "invoke `void passbyptrc(int ***const value)`: "
    GC.@preserve x px ppx pppx @fcall passbyptrc(pppx)
    GC.@preserve x px ppx cpppx @fcall passbyptrc(cpppx)
end
