#pragma once

// Cross-platform export/import macros for shared library symbols
#if defined(_WIN32) || defined(_WIN64)
  #if defined(MODERNDASH_BUILD)
    #define MD_API __declspec(dllexport)
  #else
    #define MD_API __declspec(dllimport)
  #endif
#else
  #if defined(MODERNDASH_BUILD)
    #define MD_API __attribute__((visibility("default")))
  #else
    #define MD_API
  #endif
#endif