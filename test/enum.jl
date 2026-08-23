using CppCall
using Test

@testset "Enum" begin
    @include "./include"

    declare"""#include "enum.h" """

    @testset "fixed underlying type" begin
        # `enum smallenum: std::int16_t`. The enumerator is a value, not a box: it is isbits and
        # exactly as wide as the underlying type the header fixed.
        a = @cppenum CppEnum("a")
        @test typeof(a) === CppEnumValue{:smallenum,Int16}
        @test a[] == 0
        b = @cppenum CppEnum("b")
        @test b[] == 1
        c = @cppenum CppEnum("c")
        @test c[] == 2

        @test typeof(b) === typeof(a)
        @test typeof(c) === typeof(a)
        @test isbitstype(typeof(a))
        @test sizeof(a) == sizeof(Int16)

        # a zero-initialized `smallenum` is the same type, and equals the enumerator `a`
        s = @cppenum CppEnumType("smallenum")
        @test typeof(s) === CppEnumValue{:smallenum,Int16}
        @test s[] == 0
        @test s == a
        @test s != c
    end

    @testset "unscoped enum" begin
        # `enum color` fixes no underlying type, so which integer clang picks is its own
        # business; what the header does pin down are the values and the enum they belong to.
        color = @cppenum CppEnumType("color")
        @test color[] == 0
        red = @cppenum CppEnum("red")
        @test red[] == 0
        yellow = @cppenum CppEnum("yellow")
        @test yellow[] == 1
        green = @cppenum CppEnum("green")
        @test green[] == 20
        blue = @cppenum CppEnum("blue")
        @test blue[] == 21  # counting resumes from the explicit `green = 20`

        @test typeof(red) === typeof(color)
        @test typeof(yellow) === typeof(color)
        @test typeof(green) === typeof(color)
        @test typeof(blue) === typeof(color)

        # a zero-initialized `color` *is* `red`
        @test color == red
        @test color != green

        # an enumerator compares against, and converts to, an ordinary integer
        @test green == 20
        @test 20 == green
        @test Int(green) == 20
        @test convert(Int, green) === 20
        @test sprint(show, green) == "color(20)"
    end

    @testset "scoped enum" begin
        # `enum class altitude: char`. Reaching an enumerator needs the enum's own scope, and
        # `char` maps to `Cchar` -- signed here, so `'h'` reads back as 104 rather than wrapping.
        altitude = @cppenum CppEnumType("altitude")
        @test typeof(altitude) === CppEnumValue{:altitude,Cchar}
        @test altitude[] == 0
        high = @cppenum CppEnum("altitude::high")
        @test typeof(high) === CppEnumValue{:altitude,Cchar}
        @test high[] == Cchar('h')
        @test high[] == 104
        low = @cppenum CppEnum("altitude::low")
        @test low[] == Cchar('l')
        @test low[] == 108
        @test sizeof(high) == 1
        @test high != low

        # `enum struct E11 { x, y }`: a scoped enum with no fixed type is `int` by [dcl.enum]
        x11 = @cppenum CppEnum("E11::x")
        y11 = @cppenum CppEnum("E11::y")
        @test typeof(y11) === CppEnumValue{:E11,Cint}
        @test x11[] == 0
        @test y11[] == 1
    end

    @testset "anonymous enum" begin
        # The enum has no name to spell, so nothing may depend on the symbol clang invents for
        # it. What must hold is that its enumerators agree on one type and carry the values the
        # header wrote.
        d = @cppenum CppEnum("d")
        @test d[] == 0
        e = @cppenum CppEnum("e")
        @test e[] == 1
        f = @cppenum CppEnum("f")
        @test f[] == 3  # `f = e + 2`

        @test typeof(e) === typeof(d)
        @test typeof(f) === typeof(d)
        @test d != f

        # anonymous enums nested in a class and in a namespace are reached through their scope
        x98 = @cppenum CppEnum("E98::x")
        y98 = @cppenum CppEnum("E98::y")
        @test x98[] == 0
        @test y98[] == 1
        x = @cppenum CppEnum("N98::x")
        y = @cppenum CppEnum("N98::y")
        @test x[] == 0
        @test y[] == 1

        # three distinct anonymous enums: `y98` and `y` share a value but not an identity
        @test typeof(y) !== typeof(y98)
        @test typeof(y) !== typeof(e)
        @test y != y98
        @test y != e
    end

    @testset "enumerators are typed values" begin
        # An enumerator carries the enum it came from, so two enums that happen to agree on a
        # value are still not the same value.
        red = @cppenum CppEnum("red")
        a = @cppenum CppEnum("a")
        @test red[] == 0
        @test a[] == 0
        @test typeof(red) !== typeof(a)
        @test red != a
    end
end

@testset "Enum | through a call" begin
    # Nothing exercised an enum across the boundary before, which is how three separate bugs
    # hid here: the argument and the parameter were described in different vocabularies so no
    # enum was ever viable, a returned enum's type name was interpolated as an identifier
    # rather than a literal, and a temporary materialised for `const E&` was built at the wrong
    # width because a cv-qualified enum tag has dropped its underlying type.
    @include "./include"
    declare"""#include "enum.h" """
    declare"""
    color     cppcall_next(color c)          { return (color)(c + 1); }
    int       cppcall_code(const color &c)   { return (int)c; }
    smallenum cppcall_bump(smallenum s)      { return (smallenum)(s + 1); }
    void      cppcall_advance(color &c)      { c = (color)(c + 1); }
    """

    red = @cppenum CppEnum("red")

    # by value, in and out, with the enum type preserved on the way back
    nxt = @fcall cppcall_next(red)
    @test nxt isa CppEnumValue{:color,Cuint}
    @test nxt[] == 1
    @test (@fcall cppcall_next(nxt))[] == 2

    # a prvalue binding `const E&` materialises a temporary of the UNDERLYING width
    @test (@fcall cppcall_code(red)) == 0
    @test (@fcall cppcall_code(@cppenum CppEnum("green"))) == 20

    # an enum whose underlying type is not int must round-trip at its own width
    a = @cppenum CppEnum("a")
    bumped = @fcall cppcall_bump(a)
    @test bumped isa CppEnumValue{:smallenum,Int16}
    @test bumped[] == 1

    # a mutable enum lvalue is a Ref holding an enum VALUE, not a Ref of the underlying integer:
    # C++ will not bind an `unsigned int` lvalue to `color&` either
    c = Ref(@cppenum CppEnumType("color"))
    @fcall cppcall_advance(c)
    @test c[][] == 1
    @fcall cppcall_advance(c)
    @test c[][] == 2
    @test_throws ArgumentError @fcall cppcall_advance(Ref(Cuint(0)))
end
