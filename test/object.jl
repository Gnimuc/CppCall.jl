using CppCall
using Test

# A Julia mirror of the C++ `Foo` in test/include/class.h. `@cppnew` now hands back a pointer to
# real C++ storage, so the object's layout can be read directly.
struct FooLayout
    x::Cint
end

# `@fcall` inside a function, so the cost of a single boundary crossing can be measured.
obj_roundtrip_int(x) = @fcall obj_id_int(x)

@testset "Objects" begin
    @include "./include"

    @test declare"""#include "class.h" """

    # Identity functions. A value that survives a round trip through C++ has crossed at the
    # right width and signedness -- which is what a heap box could never tell us, because
    # reading one back only ever exercised Julia's own `convert`.
    @test declare"""
        char obj_id_char(char x) { return x; }
        unsigned char obj_id_uchar(unsigned char x) { return x; }
        short obj_id_short(short x) { return x; }
        unsigned short obj_id_ushort(unsigned short x) { return x; }
        int obj_id_int(int x) { return x; }
        unsigned int obj_id_uint(unsigned int x) { return x; }
        long obj_id_long(long x) { return x; }
        unsigned long obj_id_ulong(unsigned long x) { return x; }
        long long obj_id_longlong(long long x) { return x; }
        unsigned long long obj_id_ulonglong(unsigned long long x) { return x; }
        float obj_id_float(float x) { return x; }
        double obj_id_double(double x) { return x; }
        bool obj_id_bool(bool x) { return x; }

        int obj_cid_int(const int x) { return x; }
        int obj_rid_int(const int &x) { return x; }
        char obj_rid_char(const char &x) { return x; }
        double obj_rid_double(const double &x) { return x; }

        Foo obj_make_foo(int v) { return Foo(v); }
        int obj_read_foo(Foo f) { return f.get(); }
        """

    @testset "Builtins" begin
        # `char` is signed here. It used to come back through `Cuchar`, which read -56 as 200.
        @test @fcall(obj_id_char(Cchar(0))) === Cchar(0)
        @test @fcall(obj_id_char(1)) === Cchar(1)
        @test @fcall(obj_id_char(2.0)) === Cchar(2)
        @test @fcall(obj_id_char(0x03)) === Cchar(3)
        @test @fcall(obj_id_char(Cchar(-56))) === Cchar(-56)
        @test @fcall(obj_id_char(typemin(Cchar))) === typemin(Cchar)
        @test @fcall(obj_id_char(typemax(Cchar))) === typemax(Cchar)
        @test_throws InexactError @fcall(obj_id_char(4.1))

        @test @fcall(obj_id_uchar(Cuchar(0))) === Cuchar(0)
        @test @fcall(obj_id_uchar(1)) === Cuchar(1)
        @test @fcall(obj_id_uchar(2.0)) === Cuchar(2)
        @test @fcall(obj_id_uchar(0x03)) === Cuchar(3)
        @test @fcall(obj_id_uchar(typemax(Cuchar))) === typemax(Cuchar)
        @test_throws InexactError @fcall(obj_id_uchar(-1))

        @test @fcall(obj_id_short(Cshort(0))) === Cshort(0)
        @test @fcall(obj_id_short(1)) === Cshort(1)
        @test @fcall(obj_id_short(typemin(Cshort))) === typemin(Cshort)
        @test @fcall(obj_id_short(typemax(Cshort))) === typemax(Cshort)
        @test_throws InexactError @fcall(obj_id_short(4.1))

        @test @fcall(obj_id_ushort(Cushort(0))) === Cushort(0)
        @test @fcall(obj_id_ushort(1)) === Cushort(1)
        @test @fcall(obj_id_ushort(typemax(Cushort))) === typemax(Cushort)
        @test_throws InexactError @fcall(obj_id_ushort(-1))

        @test @fcall(obj_id_int(Cint(0))) === Cint(0)
        @test @fcall(obj_id_int(1)) === Cint(1)
        @test @fcall(obj_id_int(2.0)) === Cint(2)
        @test @fcall(obj_id_int(0x03)) === Cint(3)
        @test @fcall(obj_id_int(typemin(Cint))) === typemin(Cint)
        @test @fcall(obj_id_int(typemax(Cint))) === typemax(Cint)
        @test_throws InexactError @fcall(obj_id_int(4.1))

        @test @fcall(obj_id_uint(Cuint(0))) === Cuint(0)
        @test @fcall(obj_id_uint(1)) === Cuint(1)
        @test @fcall(obj_id_uint(2.0)) === Cuint(2)
        @test @fcall(obj_id_uint(0x03)) === Cuint(3)
        @test @fcall(obj_id_uint(typemax(Cuint))) === typemax(Cuint)
        @test_throws InexactError @fcall(obj_id_uint(-1))

        @test @fcall(obj_id_long(Clong(0))) === Clong(0)
        @test @fcall(obj_id_long(1)) === Clong(1)
        @test @fcall(obj_id_long(2.0)) === Clong(2)
        @test @fcall(obj_id_long(0x03)) === Clong(3)
        @test @fcall(obj_id_long(typemin(Clong))) === typemin(Clong)
        @test @fcall(obj_id_long(typemax(Clong))) === typemax(Clong)
        @test_throws InexactError @fcall(obj_id_long(4.1))

        @test @fcall(obj_id_ulong(Culong(0))) === Culong(0)
        @test @fcall(obj_id_ulong(1)) === Culong(1)
        @test @fcall(obj_id_ulong(2.0)) === Culong(2)
        @test @fcall(obj_id_ulong(0x03)) === Culong(3)
        @test @fcall(obj_id_ulong(typemax(Culong))) === typemax(Culong)
        @test_throws InexactError @fcall(obj_id_ulong(-1))

        @test @fcall(obj_id_longlong(Clonglong(0))) === Clonglong(0)
        @test @fcall(obj_id_longlong(1)) === Clonglong(1)
        @test @fcall(obj_id_longlong(2.0)) === Clonglong(2)
        @test @fcall(obj_id_longlong(0x03)) === Clonglong(3)
        @test @fcall(obj_id_longlong(typemin(Clonglong))) === typemin(Clonglong)
        @test @fcall(obj_id_longlong(typemax(Clonglong))) === typemax(Clonglong)
        @test_throws InexactError @fcall(obj_id_longlong(4.1))

        @test @fcall(obj_id_ulonglong(Culonglong(0))) === Culonglong(0)
        @test @fcall(obj_id_ulonglong(1)) === Culonglong(1)
        @test @fcall(obj_id_ulonglong(2.0)) === Culonglong(2)
        @test @fcall(obj_id_ulonglong(0x03)) === Culonglong(3)
        @test @fcall(obj_id_ulonglong(typemax(Culonglong))) === typemax(Culonglong)
        @test_throws InexactError @fcall(obj_id_ulonglong(-1))

        @test @fcall(obj_id_float(0.0f0)) === 0.0f0
        @test @fcall(obj_id_float(1.0f0)) === 1.0f0
        @test @fcall(obj_id_float(2)) === 2.0f0
        @test @fcall(obj_id_float(0x03)) === 3.0f0
        # a `double` argument narrows on the way into a `float` parameter, as in C++
        @test @fcall(obj_id_float(1.5)) === 1.5f0

        @test @fcall(obj_id_double(0.0)) === 0.0
        @test @fcall(obj_id_double(1.0)) === 1.0
        @test @fcall(obj_id_double(2)) === 2.0
        @test @fcall(obj_id_double(0x03)) === 3.0
        @test @fcall(obj_id_double(1.0f0)) === 1.0

        @test @fcall(obj_id_bool(false)) === false
        @test @fcall(obj_id_bool(true)) === true
        @test @fcall(obj_id_bool(1)) === true
        @test @fcall(obj_id_bool(0)) === false
        @test_throws InexactError @fcall(obj_id_bool(2))

        # the point of the redesign: a scalar crosses as itself, with nothing boxed
        @test obj_roundtrip_int(Cint(7)) === Cint(7)
        @test (@allocated obj_roundtrip_int(Cint(7))) == 0
    end

    @testset "Qualified Builtins" begin
        # A cv-qualifier is not part of an object's storage, so every spelling of a builtin
        # names the same type and `@cppnew` value-initializes it to the same zero.
        builtins = ["char" => Cchar, "unsigned char" => Cuchar, "short" => Cshort,
                    "unsigned short" => Cushort, "int" => Cint, "unsigned" => Cuint,
                    "unsigned int" => Cuint, "long" => Clong, "unsigned long" => Culong,
                    "long long" => Clonglong, "unsigned long long" => Culonglong,
                    "float" => Cfloat, "double" => Cdouble, "bool" => Bool]
        for (spelling, T) in builtins, q in (CppCall.U, CppCall.C, CppCall.V, CppCall.CV)
            p = @cppnew CppType(spelling, q)
            @test p isa Ptr{T}
            @test unsafe_load(p) === zero(T)
            @cppdelete p
        end

        # top-level `const` is not part of a by-value parameter's type
        @test @fcall(obj_cid_int(Cint(7))) === Cint(7)

        # `const T&` binds a prvalue by materializing a temporary ...
        @test @fcall(obj_rid_int(Cint(7))) === Cint(7)
        @test @fcall(obj_rid_int(7)) === Cint(7)
        @test @fcall(obj_rid_char(Cchar(-56))) === Cchar(-56)
        @test @fcall(obj_rid_double(1.5)) === 1.5

        # ... and binds Julia-owned storage directly, whether a `Ref` or a `CppRef`
        r = Ref(Cint(9))
        @test @fcall(obj_rid_int(r)) === Cint(9)
        rr = @ref r
        @test @fcall(obj_rid_int(rr)) === Cint(9)
        r[] = Cint(11)
        @test @fcall(obj_rid_int(rr)) === Cint(11)

        # `cpp"int"c` is how the referent of `const int&` is spelled in an annotation
        @test @fcall(obj_rid_int(r::CppRef{cpp"int"c})) === Cint(11)
        @test @fcall(obj_rid_int(rr::CppRef{cpp"int"c})) === Cint(11)
    end

    @testset "@cppnew" begin
        px = @cppnew cpp"Foo"
        @test px isa Ptr{CppType{:Foo,CppCall.U}}
        @test px != C_NULL
        @test unsafe_load(reinterpret(Ptr{FooLayout}, px)) === FooLayout(42)
        # the storage holds a live object, not just bytes: the default constructor ran
        @test @mcall(px->get()) == 42
        # a pointer receiver needs `->`; the receiver's shape is visible now, so `.` is an error
        @test_throws ArgumentError @mcall(px.get())
        @cppdelete px

        px = @cppnew cpp"Foo"c
        @test px isa Ptr{CppType{:Foo,CppCall.C}}
        @test unsafe_load(reinterpret(Ptr{FooLayout}, px)) === FooLayout(42)
        @cppdelete px

        px = @cppnew Cint
        @test px isa Ptr{Cint}
        @test px != C_NULL
        @test unsafe_load(px) === Cint(0)
        # it is ordinary C++ storage, so Julia can write through the pointer
        unsafe_store!(px, Cint(7))
        @test unsafe_load(px) === Cint(7)
        @cppdelete px

        px = @cppnew cpp"int"
        @test px isa Ptr{Cint}
        @test px != C_NULL
        @test unsafe_load(px) === Cint(0)
        @cppdelete px

        px = @cppnew cpp"unsigned int"
        @test px isa Ptr{Cuint}
        @test px != C_NULL
        @test unsafe_load(px) === Cuint(0)
        @cppdelete px

        px = @cppnew cpp"long"
        @test px isa Ptr{Clong}
        @test px != C_NULL
        @test unsafe_load(px) === Clong(0)
        @cppdelete px

        px = @cppnew cpp"int"c
        @test px isa Ptr{Cint}
        @test px != C_NULL
        @test unsafe_load(px) === Cint(0)
        @cppdelete px

        px = @cppnew cpp"int"v
        @test px isa Ptr{Cint}
        @test px != C_NULL
        @test unsafe_load(px) === Cint(0)
        @cppdelete px
    end

    @testset "Values" begin
        # A class returned by value has no Julia counterpart, so it comes back as `CppValue`:
        # isbits storage on the stack, with no heap object and nothing to release.
        v = @fcall obj_make_foo(Cint(7))
        @test v isa CppValue{CppType{:Foo,CppCall.U},4}
        @test isbits(v)
        @test sizeof(v) == 4
        @test CppCall.unwrap_type(typeof(v)) === CppType{:Foo,CppCall.U}
        # and it crosses back the other way, by value
        @test @fcall(obj_read_foo(v)) === Cint(7)
        @test @fcall(obj_read_foo(@fcall(obj_make_foo(Cint(13))))) === Cint(13)
    end
end
