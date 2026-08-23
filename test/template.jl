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
    # std::string is an alias of std::basic_string<char>; Clang stores a template-id's
    # converted arguments, so the defaulted traits and allocator are part of the type.
    # `char` maps to `Cchar` -- it is a signed 8-bit type here, and reading one as `Cuchar`
    # is what used to turn -56 into 200.
    StdStringTy = @template cpp"std::basic_string"{Cchar, @template(cpp"std::char_traits"{Cchar}),
                                                   @template(cpp"std::allocator"{Cchar})}
    @test jlty == StdStringTy

    clty2 = to_cpp(jlty, CppCall.@__INSTANCE__)
    jlty2 = to_jl(clty2)
    @test jlty2 == StdStringTy
end

@testset "CppTemplate | Method Call" begin
    @test_logs min_level=Logging.Error declare"""#include <vector> """

    # reading an element back needs a member the resolver can pick: `at` and `operator[]` each
    # come as a const/non-const pair with identical parameters, which is a tie it reports as
    # ambiguous rather than guessing at
    @test declare"""
    namespace cppcall_tmpltest {
    int nth(std::vector<int> *v, int i) { return (*v)[i]; }
    }
    """

    StdVector{T} = @template cpp"std::vector"{T} where T
    px = @cppnew StdVector{cpp"int"}

    # the pointee carries the specialization Clang built, defaulted allocator and all
    @test px isa Ptr{@template cpp"std::vector"{Cint, @template cpp"std::allocator"{Cint}}}

    # `size()` hands back a plain Julia integer -- there is no box to index into
    sz = @mcall px->size()
    @test sz isa Unsigned
    @test sz == 0
    @test (@mcall px->empty()) === true

    # a prvalue prefers `push_back(int&&)` over `push_back(const int&)`, exactly as C++ does;
    # what is asserted here is that the call lands, not which overload took it
    @mcall px->push_back(Cint(5))
    @test (@mcall px->size()) == 1
    @test (@mcall px->empty()) === false
    @test (@fcall cppcall_tmpltest::nth(px, Cint(0))) == 5

    # an lvalue cannot bind `int&&`, so this one goes through `push_back(const int&)`
    v = Ref(Cint(7))
    @mcall px->push_back(v)
    @test (@mcall px->size()) == 2
    @test (@fcall cppcall_tmpltest::nth(px, Cint(1))) == 7

    # ... and `@move` makes the same storage an xvalue again, which binds `int&&`
    w = @move v
    @mcall px->push_back(w)
    @test (@mcall px->size()) == 3
    @test (@fcall cppcall_tmpltest::nth(px, Cint(2))) == 7

    # the receiver spelling is checked: `px` is a pointer, so `.` is a type error
    @test_throws ArgumentError @mcall px.size()

    # a member call on a template specialization is an ordinary ccall: nothing is allocated
    vecsize(p) = @mcall p->size()
    @test vecsize(px) == 3
    @test (@allocated vecsize(px)) == 0

    @mcall px->clear()
    @test (@mcall px->size()) == 0

    @cppdelete px
end

@testset "CppTemplate | By Value" begin
    @test_logs min_level=Logging.Error declare"""#include <vector> """

    @test declare"""
    namespace cppcall_tmpltest {
    std::vector<int> make3() {
        std::vector<int> v;
        v.push_back(1);
        v.push_back(2);
        v.push_back(3);
        return v;
    }
    int total(std::vector<int> v) {
        int s = 0;
        for (std::vector<int>::size_type i = 0; i < v.size(); ++i) s += v[i];
        return s;
    }
    }
    """

    VecInt = @template cpp"std::vector"{Cint, @template cpp"std::allocator"{Cint}}

    # a specialization returned by value is stack storage the caller holds outright
    v = @fcall cppcall_tmpltest::make3()
    @test v isa CppValue{VecInt}
    @test isbits(v)

    # `Ref` is the storage a value receiver names, and `.` is how a call reaches it
    rv = Ref(v)
    @test (@mcall rv.size()) == 3
    @test_throws ArgumentError @mcall rv->size()

    # it crosses back the same way: the callee copy-constructs its own parameter from it
    @test (@fcall cppcall_tmpltest::total(v)) == 6
    @test (@mcall rv.size()) == 3
end
