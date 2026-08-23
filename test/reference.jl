using CppCall
using Test

@testset "Reference" begin
    # Julia's own `Ref` is the storage a C++ lvalue names -- there is no box in between.
    x = Ref(Cuint(0))
    @test x[] == 0
    x[] = 1
    @test x[] == 1

    # a reference to Julia-owned storage
    xref = @ref x
    @test xref isa CppRef{Cuint}
    @test xref[] == 1

    # the reference aliases the storage, and writes flow in both directions
    x[] = 2
    @test xref[] == 2

    xref[] = 3
    @test x[] == 3

    # it names the very same address, and referencing a reference is the identity
    @test (@ptr xref) === (@ptr x)
    @test (@ref xref) === xref

    # `@move` re-labels the same lvalue as movable-from: same address, same owner
    xrv = @move xref
    @test xrv isa CppRvalueRef{Cuint}
    @test (@ptr xrv) === (@ptr x)
    @test xrv[] == 3

    # reading through a reference is a plain load -- no box, no allocation
    m = @allocated xref[]
    @test m == 0
end

@testset "Reference | lifetime" begin
    # the reference is the only thing left that knows about the storage: it holds its owner,
    # so nothing else has to be kept in scope for it
    xref = let
        x = Ref(Cuint(1))
        @ref x
    end
    @test xref.owner isa Base.RefValue{Cuint}

    GC.gc(true)
    GC.gc(true)
    GC.gc(true)

    @test xref[] == 1

    # still the live storage, not a stale copy of it
    xref[] = 42
    @test xref[] == 42

    GC.gc(true)
    @test xref[] == 42
    @test xref.owner[] == 42

    # a reference to C++-owned storage has nothing for Julia to keep alive
    p = @cppnew cpp"unsigned int"
    pref = @ref p
    @test pref isa CppRef{Cuint}
    @test pref.owner === nothing
    @test pref[] == 0
    pref[] = 5
    @test unsafe_load(p) == 5
    @cppdelete p
end

@testset "Reference | binding" begin
    @test declare"""
    namespace cppcall_reftest {
    unsigned int &origin() {
        static unsigned int slot = 7;
        return slot;
    }
    unsigned int bump(unsigned int &r) { return ++r; }
    unsigned int peek(const unsigned int &r) { return r; }
    }
    """

    # a Julia `Ref` IS the lvalue: the callee mutates Julia's own storage
    x = Ref(Cuint(1))
    @test (@fcall cppcall_reftest::bump(x)) == 2
    @test x[] == 2

    # and so does a rooted reference to it
    xref = @ref x
    @test (@fcall cppcall_reftest::bump(xref)) == 3
    @test x[] == 3

    # `const unsigned int&` binds an lvalue, and materialises a temporary for a prvalue
    @test (@fcall cppcall_reftest::peek(xref)) == 3
    @test (@fcall cppcall_reftest::peek(Cuint(9))) == 9

    # a prvalue cannot bind `unsigned int&`
    @test_throws ArgumentError @fcall cppcall_reftest::bump(Cuint(9))

    # neither can a reference to const
    cxref = CppRef{cpp"unsigned int"c}(@ptr x)
    @test_throws ArgumentError @fcall cppcall_reftest::bump(cxref)
    @test (@fcall cppcall_reftest::peek(cxref)) == 3

    # a function returning `unsigned int&` hands back a reference into C++-owned storage
    r = @fcall cppcall_reftest::origin()
    @test r isa CppRef{Cuint}
    @test r.owner === nothing
    @test r[] == 7

    # writing through it is visible to C++ on the next call
    r[] = 11
    @test (@fcall cppcall_reftest::peek(r)) == 11
    @test (@fcall cppcall_reftest::origin())[] == 11
end

# FIXME: this testset is red. `machine_type_of(::Type{CppType{S,Q}})` (src/types.jl) passes its
# `error` call to `something` as an argument, so it is evaluated before the lookup it is meant to
# report on -- every read through a reference to a named C++ type throws. The reads below are the
# correct behaviour and are left asserting it.
@testset "Reference | const" begin
    x = Ref(Cuint(1))
    cxref = CppRef{cpp"unsigned int"c}(@ptr x)

    # a reference to const reads the same storage ...
    @test cxref[] == 1
    x[] = 2
    @test cxref[] == 2

    # ... but refuses to write through it
    @test_throws ErrorException (cxref[] = 3)
    @test x[] == 2

    # and that is the shape a `const unsigned int&` return hands back
    @test declare"""
    namespace cppcall_reftest {
    const unsigned int &frozen() {
        static unsigned int slot = 13;
        return slot;
    }
    }
    """

    cr = @fcall cppcall_reftest::frozen()
    @test cr isa CppRef{cpp"unsigned int"c}
    @test cr[] == 13
    @test_throws ErrorException (cr[] = 1)
end
