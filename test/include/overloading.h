#ifndef CPPCALL_OVERLOADING_H
#define CPPCALL_OVERLOADING_H

#include <iostream>

void increment(int value) {
  value++;
  std::cout << "Value (by value): " << value << std::endl;
}

void increment(double value) {
  value++;
  std::cout << "Value (by value, double): " << value << std::endl;
}

void increment(int value1, int value2) {
  value1++;
  value2++;
  std::cout << "Values (by value, two ints): " << value1 << " and " << value2
            << std::endl;
}

void increment(int &value) {
  value++;
  std::cout << "Value (by reference): " << value << std::endl;
}

void increment(const int &value) {
  std::cout << "Value (by const reference): " << value << std::endl;
}

void increment(int *value) {
    (*value)++;
    std::cout << "Value (by pointer): " << *value << std::endl;
}

#endif // CPPCALL_OVERLOADING_H