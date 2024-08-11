#ifndef CPPCALL_TYPE_H
#define CPPCALL_TYPE_H

typedef struct Foo {
  int x;
  int y;
} FooTyDef;

int Foo(int x);

const int* f1(void);
const int* const *f2(void);
const int& f3(const int& x);
void f4(const FooTyDef* const x, const struct Foo* y);

const struct Bar {
  int n1;
  mutable int n2;
} x = {0, 0};

#endif // CPPCALL_TYPE_H