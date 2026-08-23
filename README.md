# CppCall

[![Build Status](https://github.com/Gnimuc/CppCall.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/Gnimuc/CppCall.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/Gnimuc/CppCall.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/Gnimuc/CppCall.jl)
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://Gnimuc.github.io/CppCall.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://Gnimuc.github.io/CppCall.jl/dev/)

Call C++ from Julia through an in-process Clang interpreter. C++ is compiled as you declare it,
and calls cross the boundary as ordinary Julia values -- nothing is boxed.

```julia
using CppCall

declare"""
int    add(int a, int b) { return a + b; }
void   bump(int &r)      { r++; }
double scale(double x, int n) { return x * n; }
"""

@fcall add(Cint(20), Cint(22))      # 42
@fcall scale(1.5, Cint(4))          # 6.0

r = Ref(Cint(41))                   # a Julia Ref IS a C++ lvalue
@fcall bump(r)
r[]                                 # 42
```

Headers work the same way:

```julia
@include "./include"
declare"""#include "class.h" """

foo = @ctor Foo()                   # a Ptr you own
@mcall foo->get()                   # 42
@mcall foo->set(Cint(7))
@cppdelete foo
```

| C++ | what you pass or get back |
| --- | --- |
| `int`, `double`, `bool` | a plain Julia number |
| `int &` | `Ref(x)`, or `@ref x` to also keep `x` alive |
| `const int &` | a `Ref`, or a plain value |
| `int &&` | `@move r`, or a plain value |
| `int *` | `Ptr{Cint}` (a `Ref` is accepted too) |
| `const int *` | `Ptr{CppType{:int,CppCall.C}}` |
| an enum | `@cppenum CppEnum("red")` |
| a class | `Ptr{...}` from `@ctor` or `@cppnew` |

Overloads are resolved the way C++ resolves them, including reporting a genuine ambiguity.
Annotate an argument to name the parameter type and break a tie:

```julia
declare"""
void f(int);
void f(const int &);
"""

@fcall f(Cint(1))                   # ArgumentError: ambiguous -- as in C++
@fcall f(Cint(1)::Cint)             # picks f(int)
```
