using CppCall
using Test

@testset "Enum" begin
    @include "./include"

    declare"""#include "enum.h" """

    a = @cppinit CppEnum("a")
    @test a[] == 0
    b = @cppinit CppEnum("b")
    @test b[] == 1
    c = @cppinit CppEnum("c")
    @test c[] == 2

    color = @cppinit CppEnumType("color")
    @test color[] == 0
    red = @cppinit CppEnum("red")
    @test red[] == 0
    green = @cppinit CppEnum("green")
    @test green[] == 20


    d = @cppinit CppEnum("d")
    @test d[] == 0
    e = @cppinit CppEnum("e")
    @test e[] == 1
    f = @cppinit CppEnum("f")
    @test f[] == 3

    y = @cppinit CppEnum("N98::y")
    @test y[] == 1
end
