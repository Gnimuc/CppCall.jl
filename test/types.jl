using CppCall
using CppCall: to_cpp, to_jl
using CppCall: get_rt, get_argst
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

    # void pbp(int* ptr);
    clty = to_cpp(lookup(I, "pbp", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Cvoid
    @test get_argst(func) == Tuple{Ptr{Cint}}

    # void pbcp(const int* ptr);
    clty = to_cpp(lookup(I, "pbcp", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Cvoid
    @test get_argst(func) == Tuple{Ptr{CppType("int",CppCall.C)}}

    # void pbp2c(int* const ptr);
    clty = to_cpp(lookup(I, "pbp2c", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Cvoid
    @test get_argst(func) == Tuple{CppPtr{CppCall.C,Cint}}

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
    clty = to_cpp(lookup(I, "pbrvr", FuncLookup()), I)
    func = to_jl(clty)
    @test get_rt(func) == Cvoid
    @test get_argst(func) == Tuple{CppRef{Cint}}

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

    terminate(I)
end
