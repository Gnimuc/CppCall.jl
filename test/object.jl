using CppCall
using Test

@testset "CppObject" begin
    @testset "Builtins" begin
        x = @cppinit cpp"char"
        @test x[] === Cchar(0)
        x[] = 1
        @test x[] === Cchar(1)
        x[] = 2.0
        @test x[] === Cchar(2)
        x[] = 0x03
        @test x[] === Cchar(3)
        @test_throws InexactError x[] = 4.1

        x = @cppinit cpp"unsigned char"
        @test x[] === Cuchar(0)
        x[] = 1
        @test x[] === Cuchar(1)
        x[] = 2.0
        @test x[] === Cuchar(2)
        x[] = 0x03
        @test x[] === Cuchar(3)
        @test_throws InexactError x[] = -1

        x = @cppinit cpp"int"
        @test x[] === Cint(0)
        x[] = 1
        @test x[] === Cint(1)
        x[] = 2.0
        @test x[] === Cint(2)
        x[] = 0x03
        @test x[] === Cint(3)
        @test_throws InexactError x[] = 4.1

        x = @cppinit cpp"unsigned"
        @test x[] === Cuint(0)
        x[] = 1
        @test x[] === Cuint(1)
        x[] = 2.0
        @test x[] === Cuint(2)
        x[] = 0x03
        @test x[] === Cuint(3)
        @test_throws InexactError x[] = -1

        x = @cppinit cpp"unsigned int"
        @test x[] === Cuint(0)
        x[] = 1
        @test x[] === Cuint(1)
        x[] = 2.0
        @test x[] === Cuint(2)
        x[] = 0x03
        @test x[] === Cuint(3)
        @test_throws InexactError x[] = -1

        x = @cppinit cpp"long"
        @test x[] === Clong(0)
        x[] = 1
        @test x[] === Clong(1)
        x[] = 2.0
        @test x[] === Clong(2)
        x[] = 0x03
        @test x[] === Clong(3)
        @test_throws InexactError x[] = 4.1

        x = @cppinit cpp"unsigned long"
        @test x[] === Culong(0)
        x[] = 1
        @test x[] === Culong(1)
        x[] = 2.0
        @test x[] === Culong(2)
        x[] = 0x03
        @test x[] === Culong(3)
        @test_throws InexactError x[] = -1

        x = @cppinit cpp"long long"
        @test x[] === Clonglong(0)
        x[] = 1
        @test x[] === Clonglong(1)
        x[] = 2.0
        @test x[] === Clonglong(2)
        x[] = 0x03
        @test x[] === Clonglong(3)
        @test_throws InexactError x[] = 4.1

        x = @cppinit cpp"unsigned long long"
        @test x[] === Culonglong(0)
        x[] = 1
        @test x[] === Culonglong(1)
        x[] = 2.0
        @test x[] === Culonglong(2)
        x[] = 0x03
        @test x[] === Culonglong(3)
        @test_throws InexactError x[] = -1

        x = @cppinit cpp"float"
        @test x[] === Float32(0.0f0)
        x[] = 1.0f0
        @test x[] === Float32(1.0f0)
        x[] = 2
        @test x[] === Float32(2.0f0)
        x[] = 0x03
        @test x[] === Float32(3.0f0)

        x = @cppinit cpp"double"
        @test x[] === Float64(0.0)
        x[] = 1.0
        @test x[] === Float64(1.0)
        x[] = 2
        @test x[] === Float64(2.0)
        x[] = 0x03
        @test x[] === Float64(3.0)

        x = @cppinit cpp"bool"
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
        x = @cppinit cpp"char"c
        @test x[] === Cchar(0)
        x = @cppinit cpp"char"v
        @test x[] === Cchar(0)
        x = @cppinit cpp"char"cv
        @test x[] === Cchar(0)

        x = @cppinit cpp"unsigned char"c
        @test x[] === Cuchar(0)
        x = @cppinit cpp"unsigned char"v
        @test x[] === Cuchar(0)
        x = @cppinit cpp"unsigned char"cv
        @test x[] === Cuchar(0)

        x = @cppinit cpp"int"
        @test x[] === Cint(0)
        x = @cppinit cpp"int"c
        @test x[] === Cint(0)
        x = @cppinit cpp"int"v
        @test x[] === Cint(0)
        x = @cppinit cpp"int"cv

        x = @cppinit cpp"unsigned"
        @test x[] === Cuint(0)
        x = @cppinit cpp"unsigned"c
        @test x[] === Cuint(0)
        x = @cppinit cpp"unsigned"v
        @test x[] === Cuint(0)
        x = @cppinit cpp"unsigned"cv

        x = @cppinit cpp"unsigned int"
        @test x[] === Cuint(0)
        x = @cppinit cpp"unsigned int"c
        @test x[] === Cuint(0)
        x = @cppinit cpp"unsigned int"v
        @test x[] === Cuint(0)
        x = @cppinit cpp"unsigned int"cv

        x = @cppinit cpp"long"
        @test x[] === Clong(0)
        x = @cppinit cpp"long"c
        @test x[] === Clong(0)
        x = @cppinit cpp"long"v
        @test x[] === Clong(0)
        x = @cppinit cpp"long"cv

        x = @cppinit cpp"unsigned long"
        @test x[] === Culong(0)
        x = @cppinit cpp"unsigned long"c
        @test x[] === Culong(0)
        x = @cppinit cpp"unsigned long"v
        @test x[] === Culong(0)
        x = @cppinit cpp"unsigned long"cv

        x = @cppinit cpp"long long"
        @test x[] === Clonglong(0)
        x = @cppinit cpp"long long"c
        @test x[] === Clonglong(0)
        x = @cppinit cpp"long long"v
        @test x[] === Clonglong(0)
        x = @cppinit cpp"long long"cv

        x = @cppinit cpp"unsigned long long"
        @test x[] === Culonglong(0)
        x = @cppinit cpp"unsigned long long"c
        @test x[] === Culonglong(0)
        x = @cppinit cpp"unsigned long long"v
        @test x[] === Culonglong(0)
        x = @cppinit cpp"unsigned long long"cv

        x = @cppinit cpp"float"
        @test x[] === Float32(0.0f0)
        x = @cppinit cpp"float"c
        @test x[] === Float32(0.0f0)
        x = @cppinit cpp"float"v
        @test x[] === Float32(0.0f0)
        x = @cppinit cpp"float"cv

        x = @cppinit cpp"double"
        @test x[] === Float64(0.0)
        x = @cppinit cpp"double"c
        @test x[] === Float64(0.0)
        x = @cppinit cpp"double"v
        @test x[] === Float64(0.0)
        x = @cppinit cpp"double"cv

        x = @cppinit cpp"bool"
        @test x[] === false
        x = @cppinit cpp"bool"c
        @test x[] === false
        x = @cppinit cpp"bool"v
        @test x[] === false
        x = @cppinit cpp"bool"cv
        @test x[] === false
    end
end
