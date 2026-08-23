using CppCall
using CppCall: to_cpp, to_jl
using CppCall: get_rt, get_argst
using CppCall: machine_type, has_machine_type, is_const_sig, CppOpaque
using Test

@testset "Builtin Types" begin
    I = initialize()
    @test is_valid(I)

    @test to_jl(to_cpp(Cvoid, I)) == Cvoid

    @test to_jl(to_cpp(Bool, I)) == Bool

    @test to_jl(to_cpp(UInt8, I)) == UInt8
    @test to_jl(to_cpp(UInt16, I)) == UInt16
    @test to_jl(to_cpp(UInt32, I)) == UInt32
    @test to_jl(to_cpp(UInt64, I)) == UInt64
    @test to_jl(to_cpp(UInt128, I)) == UInt128

    @test to_jl(to_cpp(Int8, I)) == Int8
    @test to_jl(to_cpp(Int16, I)) == Int16
    @test to_jl(to_cpp(Int32, I)) == Int32
    @test to_jl(to_cpp(Int64, I)) == Int64
    @test to_jl(to_cpp(Int128, I)) == Int128

    @test to_jl(to_cpp(Float16, I)) == Float16
    @test to_jl(to_cpp(Float32, I)) == Float32
    @test to_jl(to_cpp(Float64, I)) == Float64

    # a pointer maps through its pointee, and a const pointee round trips as one
    @test to_jl(to_cpp(Ptr{Cint}, I)) == Ptr{Cint}
    @test to_jl(to_cpp(Ptr{Cdouble}, I)) == Ptr{Cdouble}
    @test to_jl(to_cpp(Ptr{CppType("int", CppCall.C)}, I)) == Ptr{CppType("int", CppCall.C)}

    terminate(I)
end

@testset "Lookup" begin
    I = initialize()
    @test is_valid(I)

    declare(I, """#include <ctime> """)

    # clock_t clock();
    clty = to_cpp(lookup(I, "clock", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Culong
    @test get_argst(func) == Tuple{}

    cppinclude(I, joinpath(@__DIR__, "include"))

    declare(I, """#include "type.h" """)

    # int Foo(int x);
    clty = to_cpp(lookup(I, "Foo", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Cint
    @test get_argst(func) == Tuple{Cint}

    # const int* f1(void);
    clty = to_cpp(lookup(I, "f1", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Ptr{CppType{:int,CppCall.C}}
    @test get_argst(func) == Tuple{}

    # const int* const *f2(void);
    # the outer pointer is unqualified, so it is a plain `Ptr`; the inner one is `const`, which
    # only a `CppPtr` can say
    clty = to_cpp(lookup(I, "f2", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Ptr{CppPtr{CppCall.C,CppType{:int,CppCall.C}}}
    @test get_argst(func) == Tuple{}

    # const int& f3(const int& x);
    clty = to_cpp(lookup(I, "f3", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == CppRef{CppType{:int,CppCall.C}}
    @test get_argst(func) == Tuple{CppRef{CppType{:int,CppCall.C}}}

    # void f4(const FooTyDef* const x, const struct Foo* y);
    # NOTE: the pointee's `const` is not visible here. `to_jl` desugars a typedef or an
    # elaborated type and drops the qualifier along with the sugar, which is why `Foo` comes
    # back unqualified where `int` in `f1` does not. It is a lossy view rather than a wrong
    # one: overload resolution canonicalises the parameter first, and the `const` survives
    # that path.
    clty = to_cpp(lookup(I, "f4", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Cvoid
    @test get_argst(func) == Tuple{CppPtr{CppCall.C,CppType("Foo")}, Ptr{CppType("Foo")}}

    terminate(I)
end

@testset "CppType" begin
    I = initialize()
    @test is_valid(I)

    @test to_jl(to_cpp(CppType("void"), I)) == Cvoid

    @test to_jl(to_cpp(CppType("bool"), I)) == Bool

    @test to_jl(to_cpp(CppType("unsigned"), I)) == Cuint

    @test to_jl(to_cpp(CppType("unsigned char"), I)) == Cuchar
    @test to_jl(to_cpp(CppType("unsigned short"), I)) == Cushort
    @test to_jl(to_cpp(CppType("unsigned int"), I)) == Cuint
    @test to_jl(to_cpp(CppType("unsigned long"), I)) == Culong
    @test to_jl(to_cpp(CppType("unsigned long long"), I)) == Culonglong

    # `char` is a type of its own, distinct from both `signed char` and `unsigned char`. It
    # maps to `Cchar`: mapping it to `Cuchar` is what used to read a `-56` back as `200`.
    @test to_jl(to_cpp(CppType("char"), I)) == Cchar
    @test to_jl(to_cpp(CppType("short"), I)) == Cshort
    @test to_jl(to_cpp(CppType("int"), I)) == Cint
    @test to_jl(to_cpp(CppType("long"), I)) == Clong
    @test to_jl(to_cpp(CppType("long long"), I)) == Clonglong

    @test to_jl(to_cpp(CppType("float"), I)) == Cfloat
    @test to_jl(to_cpp(CppType("double"), I)) == Cdouble

    @test to_jl(to_cpp(CppType("void", CppCall.Const_Qualified), I)) == CppType{:void, CppCall.Const_Qualified}
    @test to_jl(to_cpp(CppType("bool", CppCall.Const_Qualified), I)) == CppType{:_Bool, CppCall.Const_Qualified}
    @test to_jl(to_cpp(CppType("unsigned", CppCall.C), I)) == CppType("unsigned int", CppCall.C)
    @test to_jl(to_cpp(CppType("unsigned char", CppCall.C), I)) == CppType("unsigned char", CppCall.C)
    @test to_jl(to_cpp(CppType("unsigned short", CppCall.C), I)) == CppType("unsigned short", CppCall.C)
    @test to_jl(to_cpp(CppType("unsigned int", CppCall.C), I)) == CppType("unsigned int", CppCall.C)
    # a qualified builtin is spelled from the Julia type it maps to, and `Culong === Culonglong`
    # here, so the round trip comes back as the widest spelling of that machine type
    @test to_jl(to_cpp(CppType("unsigned long", CppCall.C), I)) == CppType("unsigned long long", CppCall.C)
    @test to_jl(to_cpp(CppType("unsigned long long", CppCall.C), I)) == CppType("unsigned long long", CppCall.C)

    declare(I, """class FooClass {}; """)

    @test to_jl(to_cpp(CppType("FooClass"), I)) == CppType{:FooClass, CppCall.Unqualified}
    @test to_jl(to_cpp(CppType("FooClass", CppCall.Const_Qualified), I)) == CppType{:FooClass, CppCall.Const_Qualified}
    @test to_jl(to_cpp(CppType("FooClass", CppCall.Volatile_Qualified), I)) == CppType{:FooClass, CppCall.Volatile_Qualified}
    @test to_jl(to_cpp(CppType("FooClass", CppCall.Const_Volatile_Qualified), I)) == CppType{:FooClass, CppCall.Const_Volatile_Qualified}

    declare(I, """struct FooStruct {}; """)

    @test to_jl(to_cpp(CppType("FooStruct"), I)) == CppType{:FooStruct, CppCall.Unqualified}
    @test to_jl(to_cpp(CppType("FooStruct", CppCall.Const_Qualified), I)) == CppType{:FooStruct, CppCall.C}
    @test to_jl(to_cpp(CppType("FooStruct", CppCall.Volatile_Qualified), I)) == CppType{:FooStruct, CppCall.V}
    @test to_jl(to_cpp(CppType("FooStruct", CppCall.Const_Volatile_Qualified), I)) == CppType{:FooStruct, CppCall.CV}

    declare(I, """union FooUnion {}; """)

    @test to_jl(to_cpp(CppType("FooUnion"), I)) == CppType{:FooUnion, CppCall.Unqualified}
    @test to_jl(to_cpp(CppType("FooUnion", CppCall.Const_Qualified), I)) == CppType{:FooUnion, CppCall.C}
    @test to_jl(to_cpp(CppType("FooUnion", CppCall.Volatile_Qualified), I)) == CppType{:FooUnion, CppCall.V}
    @test to_jl(to_cpp(CppType("FooUnion", CppCall.Const_Volatile_Qualified), I)) == CppType{:FooUnion, CppCall.CV}

    cppinclude(I, joinpath(@__DIR__, "include"))

    declare(I, """#include "type.h" """)

    clty = to_cpp(CppType("FooTyDef"), I)

    xx = to_cpp(to_jl(clty), I)
    @test to_cpp(to_jl(xx), I) == xx

    terminate(I)
end

@testset "CppEnumType" begin
    I = initialize()
    @test is_valid(I)

    cppinclude(I, joinpath(@__DIR__, "include"))

    declare(I, """#include "enum.h" """)

    # an enum type carries the underlying integer type C++ picked for it, not a default one
    @test to_jl(to_cpp(CppEnumType("color"), I)) == CppEnumType{:color,Cuint}
    @test to_jl(to_cpp(CppEnumType("smallenum"), I)) == CppEnumType{:smallenum,Int16}
    @test to_jl(to_cpp(CppEnumType("altitude"), I)) == CppEnumType{:altitude,Cchar}
    @test to_jl(to_cpp(CppEnumType("E11"), I)) == CppEnumType{:E11,Cint}

    # an enumerator has the type of the enum it belongs to
    @test to_jl(to_cpp(CppEnum("red"), I)) == CppEnumType{:color,Cuint}
    @test to_jl(to_cpp(CppEnum("green"), I)) == CppEnumType{:color,Cuint}
    @test to_jl(to_cpp(CppEnum("a"), I)) == CppEnumType{:smallenum,Int16}
    @test to_jl(to_cpp(CppEnum("E11::x"), I)) == CppEnumType{:E11,Cint}

    # a cv-qualified enum reaches `to_jl` as a referent or a pointee; it used to throw an
    # AssertionError from inside `to_jl` instead of naming the type
    @test to_jl(to_cpp(CppType("color"), I)) == CppEnumType{:color,Cuint}
    @test to_jl(to_cpp(CppType("color", CppCall.C), I)) == CppType{:color,CppCall.C}
    @test to_jl(to_cpp(CppType("color", CppCall.V), I)) == CppType{:color,CppCall.V}
    @test to_jl(to_cpp(CppType("color", CppCall.CV), I)) == CppType{:color,CppCall.CV}

    declare(I, """
            color ebv(color x);
            const color& ebcr(const color& x);
            const color* ebcp(const color* x);
            """)

    # color ebv(color x);
    clty = to_cpp(lookup(I, "ebv", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == CppEnumType{:color,Cuint}
    @test get_argst(func) == Tuple{CppEnumType{:color,Cuint}}

    # const color& ebcr(const color& x);
    clty = to_cpp(lookup(I, "ebcr", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == CppRef{CppEnumType{:color,Cuint}}
    @test get_argst(func) == Tuple{CppRef{CppEnumType{:color,Cuint}}}

    # const color* ebcp(const color* x);
    clty = to_cpp(lookup(I, "ebcp", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Ptr{CppEnumType{:color,Cuint}}
    @test get_argst(func) == Tuple{Ptr{CppEnumType{:color,Cuint}}}

    terminate(I)
end

@testset "CppFuncType" begin
    I = initialize()
    @test is_valid(I)

    cppinclude(I, joinpath(@__DIR__, "include"))

    declare(I, """#include "func.h" """)

    # void pbv(int value);
    clty = to_cpp(lookup(I, "pbv", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Cvoid
    @test get_argst(func) == Tuple{Cint}

    # void pbcv(const int value);
    # top-level `const` belongs to the declared parameter, so it is visible here. The resolver
    # looks through it -- `pbv` and `pbcv` are the same parameter type to a caller.
    clty = to_cpp(lookup(I, "pbcv", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Cvoid
    @test get_argst(func) == Tuple{CppType("int", CppCall.C)}

    # void pbp(int* ptr);
    clty = to_cpp(lookup(I, "pbp", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Cvoid
    @test get_argst(func) == Tuple{Ptr{Cint}}

    # void pbcp(int* const ptr);   -- a const POINTER to a mutable int
    clty = to_cpp(lookup(I, "pbcp", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Cvoid
    @test get_argst(func) == Tuple{CppPtr{CppCall.C,Cint}}

    # void pbp2c(const int* ptr);  -- a mutable pointer to a const int
    clty = to_cpp(lookup(I, "pbp2c", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Cvoid
    @test get_argst(func) == Tuple{Ptr{CppType("int",CppCall.C)}}

    # void pbcp2c(const int* const ptr);
    clty = to_cpp(lookup(I, "pbcp2c", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Cvoid
    @test get_argst(func) == Tuple{CppPtr{CppCall.C,CppType("int",CppCall.C)}}

    # void pblvr(int& ref);
    clty = to_cpp(lookup(I, "pblvr", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Cvoid
    @test get_argst(func) == Tuple{CppRef{Cint}}

    # void pbclvr(const int& ref);
    clty = to_cpp(lookup(I, "pbclvr", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Cvoid
    @test get_argst(func) == Tuple{CppRef{CppType("int",CppCall.C)}}

    # void pbrvr(int&& ref);
    # an rvalue reference is its own type now: it is what `@move` binds to, and what a prvalue
    # prefers over `const int&`. It is no longer indistinguishable from an lvalue reference.
    clty = to_cpp(lookup(I, "pbrvr", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Cvoid
    @test get_argst(func) == Tuple{CppRvalueRef{Cint}}
    @test get_argst(func) != Tuple{CppRef{Cint}}

    # int rbv(void);
    clty = to_cpp(lookup(I, "rbv", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Cint
    @test get_argst(func) == Tuple{}

    # int* rbp(void);
    clty = to_cpp(lookup(I, "rbp", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Ptr{Cint}
    @test get_argst(func) == Tuple{}

    # int& rbr(void);
    clty = to_cpp(lookup(I, "rbr", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == CppRef{Cint}
    @test get_argst(func) == Tuple{}

    # const int& rbcr(void);
    clty = to_cpp(lookup(I, "rbcr", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == CppRef{CppType("int",CppCall.C)}
    @test get_argst(func) == Tuple{}

    declare(I, """
            char cbv(char c);
            signed char scbv(signed char c);
            unsigned char ucbv(unsigned char c);
            long double ldbv(long double x);
            char16_t c16bv(char16_t c);
            """)

    # char cbv(char c);  -- `char` is neither `signed char` nor `unsigned char`, but it is
    # signed here, so it must map to `Cchar` and not to `Cuchar`
    clty = to_cpp(lookup(I, "cbv", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Cchar
    @test get_argst(func) == Tuple{Cchar}

    # signed char scbv(signed char c);
    clty = to_cpp(lookup(I, "scbv", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Int8
    @test get_argst(func) == Tuple{Int8}

    # unsigned char ucbv(unsigned char c);
    clty = to_cpp(lookup(I, "ucbv", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Cuchar
    @test get_argst(func) == Tuple{Cuchar}

    # long double ldbv(long double x);
    # a builtin with no Julia counterpart is named rather than guessed at: it comes back as a
    # `CppType` tag, which is the shape that travels by address
    clty = to_cpp(lookup(I, "ldbv", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == CppType("long double")
    @test get_argst(func) == Tuple{CppType("long double")}

    # char16_t c16bv(char16_t c);
    clty = to_cpp(lookup(I, "c16bv", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == CppType("char16_t")
    @test get_argst(func) == Tuple{CppType("char16_t")}

    terminate(I)
end

@testset "Machine Types" begin
    # `machine_type` is the single predicate deciding whether a value fits in a `ccall` slot or
    # has to travel by address, so the trampoline and the call site cannot disagree about the
    # shape of a call. It is asked in the signature vocabulary, where a C++ type is never
    # collapsed onto a Julia one.
    @test machine_type(CppType("void")) == Cvoid
    @test machine_type(CppType("bool")) == Bool
    @test machine_type(CppType("char")) == Cchar
    @test machine_type(CppType("int")) == Cint
    @test machine_type(CppType("unsigned long long")) == Culonglong
    @test machine_type(CppType("double")) == Cdouble

    # an enum carries its underlying type as a `CppType` in that vocabulary, and takes its slot
    @test machine_type(CppEnumType{:color,CppType("unsigned int")}) == Cuint

    # no Julia counterpart means no slot: the value crosses by address instead
    @test !has_machine_type(CppType("long double"))
    @test !has_machine_type(CppType("char16_t"))
    @test !has_machine_type(CppType("FooClass"))
    # `CppOpaque` is the terminating fallback of the signature language -- an array, a
    # pointer-to-member, a `_Complex` -- and never fits a slot
    @test !has_machine_type(CppOpaque{Symbol("int[4]"),CppCall.U})

    # every pointer is one machine word, whatever it points at
    @test machine_type(Ptr{Cint}) == Ptr{Cvoid}
    @test machine_type(CppPtr{CppCall.C,CppType("int", CppCall.C)}) == Ptr{Cvoid}
    @test has_machine_type(Ptr{CppOpaque{Symbol("int[4]"),CppCall.U}})

    # ... and a `CppPtr` really is one. It was once declared 8 bits wide, which truncated every
    # address that passed through it.
    @test sizeof(CppPtr{CppCall.C,Cint}) == sizeof(Ptr{Cvoid})
    p = reinterpret(Ptr{Cint}, 0x0123456789abcdef % UInt)
    @test pointer(CppPtr{CppCall.C,Cint}(p)) === p

    # const-ness of a signature type, which is what stops a `const T*` binding a `T*` parameter
    @test is_const_sig(CppType("int", CppCall.C))
    @test is_const_sig(CppType("int", CppCall.CV))
    @test !is_const_sig(CppType("int"))
    @test !is_const_sig(CppType("int", CppCall.V))
    @test is_const_sig(CppOpaque{Symbol("long double"),CppCall.C})

    # a class returned by value comes back as a `CppValue`: an isbits blob of exactly the C++
    # size, so it lives on the stack like any other Julia value
    blob = CppValue{CppType("FooClass"),8}
    @test isbitstype(blob)
    @test sizeof(blob) == 8
    @test all(iszero, blob().data)
end
