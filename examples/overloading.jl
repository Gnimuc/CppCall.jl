using CppCall

@include "../test/include"

declare"""#include "overloading.h" """

# A plain Julia value is the argument. `increment(int)` and `increment(const int&)` both accept
# an `int` prvalue with an identity conversion, so C++ itself calls the unannotated call
# ambiguous -- the annotation names the parameter type and picks one.
x = Cint(1)

@time @fcall increment(x::Cint)

@time @fcall increment(x::CppRef{cpp"int"c})

@time @fcall increment(x::Cint)

# an lvalue can additionally bind `int&`, which mutates it
r = Ref(Cint(1))

@time @fcall increment(r::CppRef{Cint})

@show r[]

# no annotation needed here: only one `increment` takes a double
y = 1.0

@time @fcall increment(y)

@time @fcall increment(y)
