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
