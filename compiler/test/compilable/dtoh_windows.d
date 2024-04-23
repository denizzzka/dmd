/++
REQUIRED_ARGS: -HC -o-
TEST_OUTPUT:
---
// Automatically generated by Digital Mars D Compiler

#pragma once

#include <assert.h>
#include <math.h>
#include <stddef.h>
#include <stdint.h>

#ifndef _WIN32
#define EXTERN_SYSTEM_AFTER __stdcall
#define EXTERN_SYSTEM_BEFORE
#else
#define EXTERN_SYSTEM_AFTER
#define EXTERN_SYSTEM_BEFORE extern "C"
#endif

EXTERN_SYSTEM_BEFORE int32_t EXTERN_SYSTEM_AFTER exSystem(int32_t x);

int32_t __stdcall exWindows(int32_t y);
---
++/

extern(System) int exSystem(int x)
{
    return x;
}

extern(Windows) int exWindows(int y)
{
    return y;
}
