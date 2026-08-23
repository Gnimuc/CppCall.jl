using CppCall
using Logging
using Test

# `const int` is not a Julia type of its own -- constness lives in the referent or the pointee.
# A `const int` lvalue over Julia-owned storage is therefore a `CppRef{cpp"int"c}`, and it holds
# the `Ref` as its owner, so the storage cannot go away underneath it.
constref(x::Base.RefValue{Cint}) = CppRef{cpp"int"c}(Base.unsafe_convert(Ptr{Cint}, x), x)

# ... and `const int*` is `Ptr{cpp"int"c}`. Like any raw pointer it roots nothing, so calls that
# take one are wrapped in `GC.@preserve`.
constptr(x::Base.RefValue{Cint}) = reinterpret(Ptr{cpp"int"c}, Base.unsafe_convert(Ptr{Cint}, x))

@testset "Function Call" begin
    @include "./include"

    @test_logs min_level=Logging.Error declare"""#include "func.h" """

    @info "invoke `void pbv(int value)`: "
    # a prvalue is a plain Julia number now -- there is no box in between
    @test (@fcall pbv(Cint(41))) === nothing
    # an lvalue is copied on the way in, so the caller's storage is left alone
    x = Ref(Cint(0))
    @fcall pbv(x)
    @test x[] == 0
    # const T& -> T
    xref = @ref x
    @fcall pbv(xref)
    @test x[] == 0

    @info "invoke `void pbcv(const int value)`: "
    # top-level `const` on a parameter is not part of the signature, so `const int` takes
    # exactly what `int` takes
    x = Ref(Cint(0))
    @fcall pbcv(x)
    @test x[] == 0
    xref = @ref x
    @fcall pbcv(xref)
    @test x[] == 0
    @fcall pbcv(Cint(7))

    @info "invoke `void pbp(int* ptr)`: "
    x = Ref(Cint(0))
    px = @ptr x
    GC.@preserve x @fcall pbp(px)
    @test x[] == 1
    # `@ref` roots its referent, so a reference standing in for `int*` needs no `GC.@preserve`
    xref = @ref x
    @fcall pbp(xref)
    @test x[] == 2
    # and neither does a plain `Ref`, which is the storage itself
    @fcall pbp(x)
    @test x[] == 3
    # invalid conversion from 'const int*' to 'int*'
    cpx = constptr(x)
    @test_throws ArgumentError GC.@preserve x @fcall pbp(cpx)

    @info "invoke `void pbp2c(const int* ptr)`: "
    x = Ref(Cint(0))
    cpx = constptr(x)
    GC.@preserve x @fcall pbp2c(cpx)
    @test x[] == 0
    # 'int*' converts to 'const int*'
    px = @ptr x
    GC.@preserve x @fcall pbp2c(px)
    @test x[] == 0
    @fcall pbp2c(x)
    @test x[] == 0

    @info "invoke `void pbcp(int* const ptr)`: "
    # the pointer itself being const is invisible to the caller: `int* const` is the same
    # parameter type as `int*`
    x = Ref(Cint(0))
    px = @ptr x
    GC.@preserve x @fcall pbcp(px)
    @test x[] == 1
    xref = @ref x
    @fcall pbcp(xref)
    @test x[] == 2
    @fcall pbcp(x)
    @test x[] == 3
    # invalid conversion from 'const int*' to 'int*'
    cpx = constptr(x)
    @test_throws ArgumentError GC.@preserve x @fcall pbcp(cpx)

    @info "invoke `void pbcp2c(const int* const ptr)`: "
    x = Ref(Cint(0))
    cpx = constptr(x)
    GC.@preserve x @fcall pbcp2c(cpx)
    @test x[] == 0
    px = @ptr x
    GC.@preserve x @fcall pbcp2c(px)
    @test x[] == 0
    @fcall pbcp2c(x)
    @test x[] == 0

    @info "invoke `void pblvr(int& ref)`: "
    # Julia's own `Ref` IS the C++ lvalue, so the callee mutates the caller's storage
    x = Ref(Cint(0))
    @fcall pblvr(x)
    @test x[] == 1
    xref = @ref x
    @fcall pblvr(xref)
    @test x[] == 2
    @test xref[] == 2
    # binding reference of type 'int&' to 'const int' discards qualifiers
    xcref = constref(x)
    @test_throws ArgumentError @fcall pblvr(xcref)
    # cannot bind non-const lvalue reference of type 'int&' to an rvalue of type 'int'
    @test_throws ArgumentError @fcall pblvr(Cint(0))
    # a pointer is not an lvalue of type 'int' either
    px = @ptr x
    @test_throws ArgumentError GC.@preserve x @fcall pblvr(px)

    @info "invoke `void pbclvr(const int& ref)`: "
    x = Ref(Cint(0))
    @fcall pbclvr(x)
    @test x[] == 0
    xref = @ref x
    @fcall pbclvr(xref)
    @test x[] == 0
    xref[] = 1
    @fcall pbclvr(xref)
    @test x[] == 1
    xcref = constref(x)
    @fcall pbclvr(xcref)
    @test x[] == 1
    # a prvalue binds `const int&` through a temporary the call site materialises
    @fcall pbclvr(Cint(2))
    @test x[] == 1

    @info "invoke `void pbrvr(int&& ref)`: "
    x = Ref(Cint(0))
    # cannot bind rvalue reference of type 'int&&' to lvalue of type 'int'
    @test_throws ArgumentError @fcall pbrvr(x)
    xref = @ref x
    @test_throws ArgumentError @fcall pbrvr(xref)
    # a prvalue binds it ...
    @fcall pbrvr(Cint(9))
    @test x[] == 0
    # ... and so does an lvalue explicitly marked movable-from, which mutates that lvalue
    @fcall pbrvr(@move x)
    @test x[] == 1

    @info "invoke `int rbv(void)`: "
    x = @fcall rbv()
    @test x isa Cint
    @test x == 42

    @info "invoke `int* rbp(void)`: "
    p = @fcall rbp()
    @test p isa Ptr{Cint}
    @test unsafe_load(p) == 42

    @info "invoke `int& rbr(void)`: "
    p = @fcall rbr()
    @test p isa CppRef{Cint}
    # the referent is C++-owned, so Julia has nothing to keep alive
    @test p.owner === nothing
    @test p[] == 42
    @fcall pblvr(p)
    @test p[] == 43
    v = @fcall rbvpbr(p)
    @test v == 43 # can only be tested once

    @info "invoke `const int& rbcr(void)`: "
    p = @fcall rbcr()
    @test p isa CppRef{cpp"int"c}
    @fcall pbclvr(p)
    @test_throws ArgumentError @fcall pblvr(p)
end

@testset "Function Overloading" begin
    @include "./include"

    @test_logs min_level=Logging.Error declare"""#include "overloading.h" """

    @info "`void increment(const int& value)` vs `void increment(int value)`:"
    # `int`, `int&`, `const int&` and `int*` all accept a non-const lvalue and nothing in the
    # call chooses between the first three -- which is exactly what C++ calls ambiguous. An
    # `x::T` annotation asserts the parameter's `to_jl` type and breaks the tie.
    x = Ref(Cint(0))
    @test_throws ArgumentError @fcall increment(x) # ambiguous call
    @fcall increment(x::Cint) # calls `void increment(int value)`
    @test x[] == 0
    @fcall increment(x::CppRef{cpp"int"c}) # calls `void increment(const int& value)`
    @test x[] == 0
    @fcall increment(x::CppRef{Cint}) # calls `void increment(int& value)`
    @test x[] == 1
    @fcall increment(x::Ptr{Cint}) # calls `void increment(int* value)`
    @test x[] == 2

    xref = @ref x
    @test_throws ArgumentError @fcall increment(xref) # ambiguous call
    @fcall increment(xref::CppRef{cpp"int"c}) # calls `void increment(const int& value)`
    @test x[] == 2
    @fcall increment(xref::Cint) # calls `void increment(int value)`
    @test x[] == 2
    @fcall increment(xref::CppRef{Cint}) # calls `void increment(int& value)`
    @test x[] == 3

    # a reference to const drops `int&` and `int*` from the candidate set, but `int` and
    # `const int&` still tie
    xcref = constref(x)
    @test_throws ArgumentError @fcall increment(xcref) # ambiguous call
    @fcall increment(xcref::CppRef{cpp"int"c}) # calls `void increment(const int& value)`
    @test x[] == 3

    # a prvalue initialises `int` and binds `const int&` equally well; clang says ambiguous too
    @test_throws ArgumentError @fcall increment(Cint(5)) # ambiguous call
    @fcall increment(Cint(5)::Cint) # calls `void increment(int value)`
    @fcall increment(Cint(5)::CppRef{cpp"int"c}) # calls `void increment(const int& value)`
    # ... but it cannot bind `int&` at all
    @test_throws ArgumentError @fcall increment(Cint(5)::CppRef{Cint})

    # void increment(double value);
    @fcall increment(1.5)
    x = Ref(Cdouble(0.0))
    @fcall increment(x)
    @test x[] == 0.0

    # void increment(int value1, int value2);
    @fcall increment(Cint(1), Cint(2))
end

@testset "Method Call" begin
    @include "./include"

    @test_logs min_level=Logging.Error declare"""#include "class.h" """

    # `@ctor` hands back a pointer to a heap-allocated object
    x = @ctor Foo()
    @test x isa Ptr{cpp"Foo"}
    y = @mcall x->get()
    @test y isa Cint
    @test y == 42

    # a non-default constructor, reached with a Julia lvalue ...
    n = Ref(Cint(100))
    px = @ctor Foo(n)
    y = @mcall px->get()
    @test y == 100
    @test n[] == 100
    # ... and with a plain prvalue
    qx = @ctor Foo(Cint(7))
    @test (@mcall qx->get()) == 7

    z = Ref(Cint(1))
    @mcall x->set(z)
    y = @mcall x->get()
    @test y == 1

    # `->` needs a pointer receiver and `.` needs a value or reference receiver, as in C++;
    # getting it the wrong way round is a type error rather than a silent reinterpretation
    xref = @ref x
    @test xref isa CppRef{cpp"Foo"}
    @test (@mcall xref.get()) == 1
    @test_throws ArgumentError @mcall x.get()
    @test_throws ArgumentError @mcall xref->get()

    @mcall xref.set(Cint(5))
    @test (@mcall x->get()) == 5

    x1 = @cppnew cpp"Foo"
    z1 = Ref(Cint(2))
    @mcall x1->set(z1)
    y1 = @mcall x1->get()
    @test y1 == 2
    @cppdelete x1
    @cppdelete qx
    @cppdelete px
    @cppdelete x
end

# FIXME: this testset is red. `machine_type_of(::Type{CppType{S,Q}})` (src/types.jl) hands its
# `error` call to `something` as an ARGUMENT, so the error is raised before the lookup it is
# meant to report on ever happens -- even for `const int`, whose machine type is right there in
# `MACHINE_TYPES`. Every read through a reference to a named C++ type therefore throws, and
# passing a `const int` lvalue to a by-value parameter is such a read. These assertions are the
# correct behaviour and are left asserting it. They live in a testset of their own, placed last,
# so that the one library bug does not abort the other 75 assertions in this file.
@testset "Function Call | const lvalue by value" begin
    @include "./include"

    @test_logs min_level=Logging.Error declare"""#include "func.h" """
    @test_logs min_level=Logging.Error declare"""#include "overloading.h" """

    x = Ref(Cint(0))
    xcref = constref(x)

    # const T& -> T: the value is read out of the referent and copied in
    @test (@fcall pbv(xcref)) === nothing
    @test x[] == 0
    @test (@fcall pbcv(xcref)) === nothing
    @test x[] == 0

    # and that same read is what an `x::Cint` annotation asks for on a const lvalue
    @test (@fcall increment(xcref::Cint)) === nothing # calls `void increment(int value)`
    @test x[] == 0

    # reading a `const int&` result goes through it too
    p = @fcall rbcr()
    @test p[] == 42
end
