using CppCall

@include "../test/include"

declare"""#include "overloading.h" """

x = @cppobj cppty"int"

@time @fcall increment(x,x)

@time @fcall increment(x,x)

y = @cppobj cppty"double"

@time @fcall increment(y)

@time @fcall increment(y)

convert(Cdouble, y)

t = cppty"float"

obj = @cppobj t
obj[] = 1
obj[]


z = CppObject{Cint}(1)

zz = Ref(z)

pointer_from_objref(z) == Base.unsafe_convert(Ptr{Cvoid}, zz)

zzz = @cppobj Ptr{cppty"int"}

@fcall increment(zz)

convert(Cint, z)

qualty"unsigned int"cv |> CppCall.CC.dump

@fcall increment(x)

convert(Cuint, y)

qualty"unsigned int" |> CppCall.to_jl

cppty"unsigned int" == CppCall.to_jl(qualty"unsigned int")

obj = CppObject{Cppint,sizeof(Cint)}()

reinterpret(Cint, obj.data)

ntuple(0x00, 0x00, 0x00, 0x00)
