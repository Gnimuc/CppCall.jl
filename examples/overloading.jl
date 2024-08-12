using CppCall

@include "../test/include"

declare"""#include "overloading.h" """

x = @cppinit cppty"int"

@time @fcall increment(x)

@time @fcall increment(x)

y = @cppinit cppty"double"

@time @fcall increment(y)

@time @fcall increment(y)
