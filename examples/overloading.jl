using CppCall

@include "../test/include"

declare"""#include "overloading.h" """

x = @cppinit cpp"int"c

@time @fcall increment(x)

@time @fcall increment(x::CppRef{cpp"int"c})

@time @fcall increment(x)

y = @cppinit cpp"double"

@time @fcall increment(y)

@time @fcall increment(y)
