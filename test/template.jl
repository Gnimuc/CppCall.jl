using CppCall
using CppCall: to_cpp, to_jl
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

    StdVector{T} = @template cpp"std::vector"{T} where T
    @test StdVector{cpp"int"} == CppTemplate{cpp"std::vector",Tuple{cpp"int"}}

    t = @template cpp"std::vector"{cpp"int"}
    clty = to_cpp(t, CppCall.@__INSTANCE__)
    jlty = to_jl(clty)
    @test jlty == @template cpp"std::vector"{Cint, @template cpp"std::allocator"{Cint}}

    t = @template cpp"std::vector"{cpp"int"c}
    clty = to_cpp(t, CppCall.@__INSTANCE__)
    jlty = to_jl(clty)
    @test jlty == @template cpp"std::vector"{cpp"int"c, @template cpp"std::allocator"{cpp"int"c}}

    t = @template cpp"std::vector"{cpp"int"v}
    clty = to_cpp(t, CppCall.@__INSTANCE__)
    jlty = to_jl(clty)
    @test jlty == @template cpp"std::vector"{cpp"int"v, @template cpp"std::allocator"{cpp"int"v}}

    t = @template cpp"std::vector"{cpp"int"cv}
    clty = to_cpp(t, CppCall.@__INSTANCE__)
    jlty = to_jl(clty)
    @test jlty == @template cpp"std::vector"{cpp"int"cv, @template cpp"std::allocator"{cpp"int"cv}}

    @test_logs min_level=Logging.Error declare"""#include <string> """

    StdString = cpp"std::string"
    clty = to_cpp(StdString, CppCall.@__INSTANCE__)
    jlty = to_jl(clty)
    @test jlty == @template cpp"std::basic_string"{Cuchar} # std::string is an alias of std::basic_string<char>

    clty2 = to_cpp(jlty, CppCall.@__INSTANCE__)
    jlty2 = to_jl(clty2)
    @test jlty2 == @template cpp"std::basic_string"{Cuchar, @template(cpp"std::char_traits"{Cuchar}), @template cpp"std::allocator"{Cuchar}}
end

@testset "CppTemplate | Method Call" begin
    @test_logs min_level=Logging.Error declare"""#include <vector> """

    StdVector{T} = @template cpp"std::vector"{T} where T
    px = @cppnew StdVector{cpp"int"}
    sz = @mcall px->size()
    @test sz[] == 0

    v = @cppinit cpp"int"
    v[] = 1
    @mcall px->push_back(v)

    sz = @mcall px->size()
    @test sz[] == 1

    @cppdelete px
end
