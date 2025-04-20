#ifndef CPPCALL_ENUM_H
#define CPPCALL_ENUM_H

#include <cstdint>
 
enum smallenum: std::int16_t
{
    a,
    b,
    c
};
 
enum color
{
    red,
    yellow,
    green = 20,
    blue
};
 
enum class altitude: char
{
    high = 'h',
    low = 'l',
}; 
 
enum
{
    d,
    e,
    f = e + 2
};

 
enum struct E11 { x, y };
 
struct E98 { enum { x, y }; };
 
namespace N98 { enum { x, y }; }

#endif // CPPCALL_ENUM_H