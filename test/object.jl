using CppCall
using Test

@testset "CppObject" begin
    @testset "Builtins" begin
        x = @cppinit cppty"char"
        @test x[] === Cchar(0)
        x[] = 1
        @test x[] === Cchar(1)
        x[] = 2.0
        @test x[] === Cchar(2)
        x[] = 0x03
        @test x[] === Cchar(3)
        @test_throws InexactError x[] = 4.1

        x = @cppinit cppty"unsigned char"
        @test x[] === Cuchar(0)
        x[] = 1
        @test x[] === Cuchar(1)
        x[] = 2.0
        @test x[] === Cuchar(2)
        x[] = 0x03
        @test x[] === Cuchar(3)
        @test_throws InexactError x[] = -1

        x = @cppinit cppty"int"
        @test x[] === Cint(0)
        x[] = 1
        @test x[] === Cint(1)
        x[] = 2.0
        @test x[] === Cint(2)
        x[] = 0x03
        @test x[] === Cint(3)
        @test_throws InexactError x[] = 4.1

        x = @cppinit cppty"unsigned"
        @test x[] === Cuint(0)
        x[] = 1
        @test x[] === Cuint(1)
        x[] = 2.0
        @test x[] === Cuint(2)
        x[] = 0x03
        @test x[] === Cuint(3)
        @test_throws InexactError x[] = -1

        x = @cppinit cppty"unsigned int"
        @test x[] === Cuint(0)
        x[] = 1
        @test x[] === Cuint(1)
        x[] = 2.0
        @test x[] === Cuint(2)
        x[] = 0x03
        @test x[] === Cuint(3)
        @test_throws InexactError x[] = -1

        x = @cppinit cppty"long"
        @test x[] === Clong(0)
        x[] = 1
        @test x[] === Clong(1)
        x[] = 2.0
        @test x[] === Clong(2)
        x[] = 0x03
        @test x[] === Clong(3)
        @test_throws InexactError x[] = 4.1

        x = @cppinit cppty"unsigned long"
        @test x[] === Culong(0)
        x[] = 1
        @test x[] === Culong(1)
        x[] = 2.0
        @test x[] === Culong(2)
        x[] = 0x03
        @test x[] === Culong(3)
        @test_throws InexactError x[] = -1

        x = @cppinit cppty"long long"
        @test x[] === Clonglong(0)
        x[] = 1
        @test x[] === Clonglong(1)
        x[] = 2.0
        @test x[] === Clonglong(2)
        x[] = 0x03
        @test x[] === Clonglong(3)
        @test_throws InexactError x[] = 4.1

        x = @cppinit cppty"unsigned long long"
        @test x[] === Culonglong(0)
        x[] = 1
        @test x[] === Culonglong(1)
        x[] = 2.0
        @test x[] === Culonglong(2)
        x[] = 0x03
        @test x[] === Culonglong(3)
        @test_throws InexactError x[] = -1

        x = @cppinit cppty"float"
        @test x[] === Float32(0.0f0)
        x[] = 1.0f0
        @test x[] === Float32(1.0f0)
        x[] = 2
        @test x[] === Float32(2.0f0)
        x[] = 0x03
        @test x[] === Float32(3.0f0)

        x = @cppinit cppty"double"
        @test x[] === Float64(0.0)
        x[] = 1.0
        @test x[] === Float64(1.0)
        x[] = 2
        @test x[] === Float64(2.0)
        x[] = 0x03
        @test x[] === Float64(3.0)

        x = @cppinit cppty"bool"
        @test x[] === false
        x[] = true
        @test x[] === true
        x[] = 1
        @test x[] === true
        x[] = 0
        @test x[] === false
        @test_throws InexactError x[] = 2
    end

    @testset "Qualified Builtins" begin
        x = @cppinit cppty"char"c
        @test x[] === Cchar(0)
        x = @cppinit cppty"char"v
        @test x[] === Cchar(0)
        x = @cppinit cppty"char"cv
        @test x[] === Cchar(0)

        x = @cppinit cppty"unsigned char"c
        @test x[] === Cuchar(0)
        x = @cppinit cppty"unsigned char"v
        @test x[] === Cuchar(0)
        x = @cppinit cppty"unsigned char"cv
        @test x[] === Cuchar(0)

        x = @cppinit cppty"int"
        @test x[] === Cint(0)
        x = @cppinit cppty"int"c
        @test x[] === Cint(0)
        x = @cppinit cppty"int"v
        @test x[] === Cint(0)
        x = @cppinit cppty"int"cv

        x = @cppinit cppty"unsigned"
        @test x[] === Cuint(0)
        x = @cppinit cppty"unsigned"c
        @test x[] === Cuint(0)
        x = @cppinit cppty"unsigned"v
        @test x[] === Cuint(0)
        x = @cppinit cppty"unsigned"cv

        x = @cppinit cppty"unsigned int"
        @test x[] === Cuint(0)
        x = @cppinit cppty"unsigned int"c
        @test x[] === Cuint(0)
        x = @cppinit cppty"unsigned int"v
        @test x[] === Cuint(0)
        x = @cppinit cppty"unsigned int"cv

        x = @cppinit cppty"long"
        @test x[] === Clong(0)
        x = @cppinit cppty"long"c
        @test x[] === Clong(0)
        x = @cppinit cppty"long"v
        @test x[] === Clong(0)
        x = @cppinit cppty"long"cv

        x = @cppinit cppty"unsigned long"
        @test x[] === Culong(0)
        x = @cppinit cppty"unsigned long"c
        @test x[] === Culong(0)
        x = @cppinit cppty"unsigned long"v
        @test x[] === Culong(0)
        x = @cppinit cppty"unsigned long"cv

        x = @cppinit cppty"long long"
        @test x[] === Clonglong(0)
        x = @cppinit cppty"long long"c
        @test x[] === Clonglong(0)
        x = @cppinit cppty"long long"v
        @test x[] === Clonglong(0)
        x = @cppinit cppty"long long"cv

        x = @cppinit cppty"unsigned long long"
        @test x[] === Culonglong(0)
        x = @cppinit cppty"unsigned long long"c
        @test x[] === Culonglong(0)
        x = @cppinit cppty"unsigned long long"v
        @test x[] === Culonglong(0)
        x = @cppinit cppty"unsigned long long"cv

        x = @cppinit cppty"float"
        @test x[] === Float32(0.0f0)
        x = @cppinit cppty"float"c
        @test x[] === Float32(0.0f0)
        x = @cppinit cppty"float"v
        @test x[] === Float32(0.0f0)
        x = @cppinit cppty"float"cv

        x = @cppinit cppty"double"
        @test x[] === Float64(0.0)
        x = @cppinit cppty"double"c
        @test x[] === Float64(0.0)
        x = @cppinit cppty"double"v
        @test x[] === Float64(0.0)
        x = @cppinit cppty"double"cv

        x = @cppinit cppty"bool"
        @test x[] === false
        x = @cppinit cppty"bool"c
        @test x[] === false
        x = @cppinit cppty"bool"v
        @test x[] === false
        x = @cppinit cppty"bool"cv
        @test x[] === false
    end
end
