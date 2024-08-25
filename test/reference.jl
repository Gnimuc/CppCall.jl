using CppCall
using Test

@testset "Reference" begin
    x = @cppinit cpp"unsigned int"
    @test x[] == 0
    x[] = 1
    @test x[] == 1

    # reference to a heap-allocated object
    xref = @ref x
    @test xref[] == 1
    x[] = 2
    @test xref[] == 2

    xref[] = 3
    @test x[] == 3

    m = @allocated xref[]
    @test m == 0
end

@testset "Reference | finalizer" begin
    xref = let
        x = @cppinit cpp"unsigned int"
        x[] = 1
        @ref x
    end

    GC.gc()
    GC.gc()
    GC.gc()

    @test xref[] == 1
end
