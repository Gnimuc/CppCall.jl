using CppCall
using Test

@testset "CppObject" begin
    @testset "Builtins" begin
        x = @cppobj cppty"char"
        @test x[] === Cchar(0)
        x[] = 1
        @test x[] === Cchar(1)
        x[] = 2.0
        @test x[] === Cchar(2)
        x[] = 0x03
        @test x[] === Cchar(3)
        @test_throws InexactError x[] = 4.1

        x = @cppobj cppty"unsigned char"
        @test x[] === Cuchar(0)
        x[] = 1
        @test x[] === Cuchar(1)
        x[] = 2.0
        @test x[] === Cuchar(2)
        x[] = 0x03
        @test x[] === Cuchar(3)
        @test_throws InexactError x[] = -1

        x = @cppobj cppty"int"
        @test x[] === Cint(0)
        x[] = 1
        @test x[] === Cint(1)
        x[] = 2.0
        @test x[] === Cint(2)
        x[] = 0x03
        @test x[] === Cint(3)
        @test_throws InexactError x[] = 4.1

        x = @cppobj cppty"unsigned"
        @test x[] === Cuint(0)
        x[] = 1
        @test x[] === Cuint(1)
        x[] = 2.0
        @test x[] === Cuint(2)
        x[] = 0x03
        @test x[] === Cuint(3)
        @test_throws InexactError x[] = -1

        x = @cppobj cppty"unsigned int"
        @test x[] === Cuint(0)
        x[] = 1
        @test x[] === Cuint(1)
        x[] = 2.0
        @test x[] === Cuint(2)
        x[] = 0x03
        @test x[] === Cuint(3)
        @test_throws InexactError x[] = -1

        x = @cppobj cppty"long"
        @test x[] === Clong(0)
        x[] = 1
        @test x[] === Clong(1)
        x[] = 2.0
        @test x[] === Clong(2)
        x[] = 0x03
        @test x[] === Clong(3)
        @test_throws InexactError x[] = 4.1

        x = @cppobj cppty"unsigned long"
        @test x[] === Culong(0)
        x[] = 1
        @test x[] === Culong(1)
        x[] = 2.0
        @test x[] === Culong(2)
        x[] = 0x03
        @test x[] === Culong(3)
        @test_throws InexactError x[] = -1

        x = @cppobj cppty"long long"
        @test x[] === Clonglong(0)
        x[] = 1
        @test x[] === Clonglong(1)
        x[] = 2.0
        @test x[] === Clonglong(2)
        x[] = 0x03
        @test x[] === Clonglong(3)
        @test_throws InexactError x[] = 4.1

        x = @cppobj cppty"unsigned long long"
        @test x[] === Culonglong(0)
        x[] = 1
        @test x[] === Culonglong(1)
        x[] = 2.0
        @test x[] === Culonglong(2)
        x[] = 0x03
        @test x[] === Culonglong(3)
        @test_throws InexactError x[] = -1

        x = @cppobj cppty"float"
        @test x[] === Float32(0.0f0)
        x[] = 1.0f0
        @test x[] === Float32(1.0f0)
        x[] = 2
        @test x[] === Float32(2.0f0)
        x[] = 0x03
        @test x[] === Float32(3.0f0)

        x = @cppobj cppty"double"
        @test x[] === Float64(0.0)
        x[] = 1.0
        @test x[] === Float64(1.0)
        x[] = 2
        @test x[] === Float64(2.0)
        x[] = 0x03
        @test x[] === Float64(3.0)

        x = @cppobj cppty"bool"
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
        x = @cppobj cppty"char"c
        @test x[] === Cchar(0)
        x = @cppobj cppty"char"v
        @test x[] === Cchar(0)
        x = @cppobj cppty"char"cv
        @test x[] === Cchar(0)

        x = @cppobj cppty"unsigned char"c
        @test x[] === Cuchar(0)
        x = @cppobj cppty"unsigned char"v
        @test x[] === Cuchar(0)
        x = @cppobj cppty"unsigned char"cv
        @test x[] === Cuchar(0)

        x = @cppobj cppty"int"
        @test x[] === Cint(0)
        x = @cppobj cppty"int"c
        @test x[] === Cint(0)
        x = @cppobj cppty"int"v
        @test x[] === Cint(0)
        x = @cppobj cppty"int"cv

        x = @cppobj cppty"unsigned"
        @test x[] === Cuint(0)
        x = @cppobj cppty"unsigned"c
        @test x[] === Cuint(0)
        x = @cppobj cppty"unsigned"v
        @test x[] === Cuint(0)
        x = @cppobj cppty"unsigned"cv

        x = @cppobj cppty"unsigned int"
        @test x[] === Cuint(0)
        x = @cppobj cppty"unsigned int"c
        @test x[] === Cuint(0)
        x = @cppobj cppty"unsigned int"v
        @test x[] === Cuint(0)
        x = @cppobj cppty"unsigned int"cv

        x = @cppobj cppty"long"
        @test x[] === Clong(0)
        x = @cppobj cppty"long"c
        @test x[] === Clong(0)
        x = @cppobj cppty"long"v
        @test x[] === Clong(0)
        x = @cppobj cppty"long"cv

        x = @cppobj cppty"unsigned long"
        @test x[] === Culong(0)
        x = @cppobj cppty"unsigned long"c
        @test x[] === Culong(0)
        x = @cppobj cppty"unsigned long"v
        @test x[] === Culong(0)
        x = @cppobj cppty"unsigned long"cv

        x = @cppobj cppty"long long"
        @test x[] === Clonglong(0)
        x = @cppobj cppty"long long"c
        @test x[] === Clonglong(0)
        x = @cppobj cppty"long long"v
        @test x[] === Clonglong(0)
        x = @cppobj cppty"long long"cv

        x = @cppobj cppty"unsigned long long"
        @test x[] === Culonglong(0)
        x = @cppobj cppty"unsigned long long"c
        @test x[] === Culonglong(0)
        x = @cppobj cppty"unsigned long long"v
        @test x[] === Culonglong(0)
        x = @cppobj cppty"unsigned long long"cv

        x = @cppobj cppty"float"
        @test x[] === Float32(0.0f0)
        x = @cppobj cppty"float"c
        @test x[] === Float32(0.0f0)
        x = @cppobj cppty"float"v
        @test x[] === Float32(0.0f0)
        x = @cppobj cppty"float"cv

        x = @cppobj cppty"double"
        @test x[] === Float64(0.0)
        x = @cppobj cppty"double"c
        @test x[] === Float64(0.0)
        x = @cppobj cppty"double"v
        @test x[] === Float64(0.0)
        x = @cppobj cppty"double"cv

        x = @cppobj cppty"bool"
        @test x[] === false
        x = @cppobj cppty"bool"c
        @test x[] === false
        x = @cppobj cppty"bool"v
        @test x[] === false
        x = @cppobj cppty"bool"cv
        @test x[] === false
    end
end
