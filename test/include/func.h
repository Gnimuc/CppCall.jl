#ifndef CPPCALL_FUNC_H
#define CPPCALL_FUNC_H

#include <iostream>

void pbv(int value) {
    value++;
    std::cout << "Value (by value): " << value << std::endl;
}

void pbcv(const int value) {
    std::cout << "Value (by const value): " << value << std::endl;
}

void pbp(int* ptr) {
    if (ptr) {
        (*ptr)++;
        std::cout << "Value (by pointer): " << *ptr << std::endl;
    }
}

void pbp2c(const int* ptr) {
    if (ptr) {
        std::cout << "Value (by pointer to const): " << *ptr << std::endl;
    }
}

void pbcp(int* const ptr) {
    if (ptr) {
        (*ptr)++;
        std::cout << "Value (by const pointer): " << *ptr << std::endl;
    }
}

void pbcp2c(const int* const ptr) {
    if (ptr) {
        std::cout << "Value (by const pointer to const): " << *ptr << std::endl;
    }
}

void pblvr(int& ref) {
    ref++;
    std::cout << "Value (by lvalue reference): " << ref << std::endl;
}

void pbclvr(const int& ref) {
    std::cout << "Value (by const lvalue reference): " << ref << std::endl;
}

void pbrvr(int&& ref) {
    ref++;
    std::cout << "Value (by rvalue reference): " << ref << std::endl;
}

int rbv(void) {
    std::cout << "Value (by value): 42" << std::endl;
    return 42;
}

int* rbp(void) {
    static int value = 42;
    std::cout << "Value (by pointer): " << value << std::endl;
    return &value;
}

int& rbr(void) {
    static int value = 42;
    std::cout << "Value (by reference): " << value << std::endl;
    return value;
}

const int& rbcr(void) {
    static int value = 42;
    std::cout << "Value (by const reference): " << value << std::endl;
    return value;
}

int rbvpbr(int& ref) {
    return ref;
}

#endif // CPPCALL_FUNC_H