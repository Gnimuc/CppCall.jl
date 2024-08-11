using CppCall

@include "../test/include"

declare"""#include "overloading.h" """

x = @cppobj cppty"int"

@time @fcall increment(x)

@time @fcall increment(x)

y = @cppobj cppty"double"

@time @fcall increment(y)

@time @fcall increment(y)
