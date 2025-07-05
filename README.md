# CppCall

[![Build Status](https://github.com/Gnimuc/CppCall.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/Gnimuc/CppCall.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/Gnimuc/CppCall.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/Gnimuc/CppCall.jl)
[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://Gnimuc.github.io/CppCall.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://Gnimuc.github.io/CppCall.jl/dev/)

## Installation

```
pkg> dev https://github.com/Gnimuc/CppCall.jl.git
```

### Development

Build binaries locally and copy-paste `LocalPreferences.toml` to the directory of `CppCall`.

```
pkg> dev https://github.com/Gnimuc/ClangCompiler.jl.git
julia> import ClangCompiler
julia> cd(joinpath(dirname(pathof(ClangCompiler)), ".."))
shell> julia --project deps/build_local.jl
```

```
pkg> dev https://github.com/Gnimuc/CppInterOp.jl.git
julia> import CppInterOp
julia> cd(joinpath(dirname(pathof(CppInterOp)), ".."))
shell> julia --project deps/build_local.jl
```

## One Big Beautiful Example

```julia
# brew install quantlib
using CppCall
using Libdl

dlopen("/opt/homebrew/lib/libQuantLib.dylib")

ql_inc = "/opt/homebrew/include" |> normpath

@include ql_inc

declare"""#include <ql/qldefines.hpp>"""

declare"""
#include <ql/instruments/vanillaoption.hpp>
#include <ql/math/integrals/tanhsinhintegral.hpp>
#include <ql/pricingengines/vanilla/analyticeuropeanengine.hpp>
#include <ql/pricingengines/vanilla/analyticeuropeanvasicekengine.hpp>
#include <ql/pricingengines/vanilla/analytichestonengine.hpp>
#include <ql/pricingengines/vanilla/baroneadesiwhaleyengine.hpp>
#include <ql/pricingengines/vanilla/batesengine.hpp>
#include <ql/pricingengines/vanilla/binomialengine.hpp>
#include <ql/pricingengines/vanilla/bjerksundstenslandengine.hpp>
#include <ql/pricingengines/vanilla/fdblackscholesvanillaengine.hpp>
#include <ql/pricingengines/vanilla/integralengine.hpp>
#include <ql/pricingengines/vanilla/mcamericanengine.hpp>
#include <ql/pricingengines/vanilla/mceuropeanengine.hpp>
#include <ql/pricingengines/vanilla/qdfpamericanengine.hpp>
#include <ql/time/calendars/target.hpp>
#include <ql/utilities/dataformatters.hpp>
"""

declare"""using namespace QuantLib;"""

day = @cppinit cpp"Day"
day[] = 29
month = @cppinit CppEnum("June")
year = @cppinit cpp"Year"
year[] = 2025

is_leap = @fcall Date::isLeap(year)
@assert !is_leap[]

dp = @ctor Date(day, month, year)
y = @mcall dp->year()
@assert y[] == 2025
m = @mcall dp->month()
@assert m[] == month[]
wd = @mcall dp->weekday()
@assert wd[] == 1
d = @* dp 
@cppdelete dp

y = @mcall d.year()
@assert y[] == 2025
m = @mcall d.month()
@assert m[] == month[]

date_s = @fcall Date::startOfMonth(d)
day_s = @mcall date_s.dayOfMonth()
@assert day_s[] == 1

today = @fcall Date::todaysDate()
s = @mcall today.serialNumber()
s[]
d1 = @mcall today.dayOfMonth()

dp = @ctor Date(s)
d2 = @mcall dp->dayOfMonth()
@assert d1[] == d2[]
@cppdelete dp

calendar = @ctor TARGET()
n = @mcall calendar->name()
str = @mcall n.c_str()
@assert unsafe_string(str[]) == "TARGET"

day[] = 30
d2 = @* @ctor Date(day, month, year)
res = @mcall calendar->isHoliday(d2)
@assert !res[]
@mcall calendar->addHoliday(d2)
res = @mcall calendar->isHoliday(d2)
@assert res[]

hs = @mcall calendar.addedHolidays()
sz = @mcall hs.size()
@assert sz[] == 1

incws = @cppinit cpp"bool"
incws[] = false
list = @mcall calendar->holidayList(d, d2, incws)

@cppdelete calendar
```