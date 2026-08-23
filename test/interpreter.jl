using CppCall
using Logging
using Test

@testset "Initialization" begin
    I = initialize()
    @test is_valid(I)
    terminate(I)
end

@testset "Instance" begin
    @include "./include"
    @test_logs min_level=Logging.Error declare"""#include "dummy.h" """
end

@testset "Undo" begin
    I = initialize()
    @test declare(I, "int undo_me(void) { return 1; }")
    @test CppCall.lookup_func(I, "undo_me")
    CppCall.undo(I, 1)
    @test is_valid(I)
    @test declare(I, "int after_undo(void) { return 2; }")
    terminate(I)
end

@testset "Diagnostics" begin
    I = initialize()
    @test declare(I, "int diag_ok(void) { return 1; }")
    @test CppCall.lookup_func(I, "diag_ok")

    # a lookup used to detach clang's diagnostic printer from its source file, so rendering
    # the next diagnostic segfaulted; ClangCompiler re-arms it since 91a69f5, and this pins
    # that we depend on it
    bad = @test_logs (:error,) match_mode=:any declare(I,
                                                       "int diag_bad(void) { return \"nope\"; }")
    @test bad == false

    # the engine latches its error state, so a rejected declaration must not poison the next
    @test declare(I, "int diag_recovered(void) { return 2; }")
    @test CppCall.lookup_func(I, "diag_recovered")

    terminate(I)
    @test !is_valid(I)
    @test terminate(I) === nothing  # releasing twice is a no-op
end
