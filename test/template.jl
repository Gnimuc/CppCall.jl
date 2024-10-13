using CppCall
using Logging
using Test

@testset "Class Template Lookup" begin
    @test_logs min_level=Logging.Error declare"""#include <vector> """

    # ignore template specialization
    x = CppCall.lookup(CppCall.@__INSTANCE__, "std::vector")
    y = CppCall.lookup(CppCall.@__INSTANCE__, "std::vector<int>")
    z = CppCall.lookup(CppCall.@__INSTANCE__, "std::vector<int, std::allocator<int>>")
    @test x == y == z
end

@testset "CppTemplate" begin
    @test_logs min_level=Logging.Error declare"""#include <vector> """

    const StdVector{T} = @template cpp"std::vector"{T} where T
    @test StdVector{cpp"int"} == CppTemplate{cpp"std::vector",Tuple{cpp"int"}}
end
