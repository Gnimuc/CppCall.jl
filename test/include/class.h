#ifndef CPPCALL_CLASS_H
#define CPPCALL_CLASS_H

#include <new>

class Foo {
public:
    Foo(int x) : x(x) {}
    Foo() : x(42) {}
    int get() const { return x; }
    void set(int v) { x = v; }
private:
    int x;
};

#endif // CPPCALL_CLASS_H