using CppCall

@include "../test/include"

declare"""#include "overloading.h" """

x = @cppinit cpp"int"

@time @fcall increment(x)

@time @fcall increment(x)

y = @cppinit cpp"double"

@time @fcall increment(y)

@time @fcall increment(y)
