using CppCall

@include "../test/include"

declare"""#include "overloading.h" """

x = @cppinit cpp"int"c

# `increment(int)` and `increment(const int&)` both accept a `const int`, so the overload has
# to be named by annotating the argument -- calling without one is reported as ambiguous
@time @fcall increment(x::Cint)

@time @fcall increment(x::CppRef{cpp"int"c})

@time @fcall increment(x::Cint)

y = @cppinit cpp"double"

@time @fcall increment(y)

@time @fcall increment(y)
