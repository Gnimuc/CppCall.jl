#ifndef CPPCALL_POINTER_H
#define CPPCALL_POINTER_H

#include <iostream>

void passbyptr(int *value) {
  (*value)++;
  std::cout << "Value (*): " << value << std::endl;
}

void passbyptr(int **value) {
  (**value)++;
  std::cout << "Value (**): " << **value << std::endl;
}

void passbyptr(int ***value) {
  (***value)++;
  std::cout << "Value (***): " << ***value << std::endl;
}

void passbyptr(int **const *value) {
  std::cout << "Value (**c*): " << ***value << std::endl;
}

void passbyptr2c(const int **value) {
  std::cout << "Value (c**): " << **value << std::endl;
}

void passbyptrc(int ***const value) {
  (***value)++;
  std::cout << "Value (***): " << ***value << std::endl;
}

int **returnptrptr(void) {
  int *ptr = new int(42);
  int **pp = new int *(ptr);
  return pp;
}

int *const *returnptrcptr(void) {
  int *ptr = new int(42);
  int **pp = new int *(ptr);
  return pp;
}

#endif // CPPCALL_POINTER_H