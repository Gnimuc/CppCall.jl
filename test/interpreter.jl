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
