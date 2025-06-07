include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(SelfRegisteringFactory_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(SelfRegisteringFactory_setup_options)
  option(SelfRegisteringFactory_ENABLE_HARDENING "Enable hardening" ON)
  option(SelfRegisteringFactory_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    SelfRegisteringFactory_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    SelfRegisteringFactory_ENABLE_HARDENING
    OFF)

  SelfRegisteringFactory_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR SelfRegisteringFactory_PACKAGING_MAINTAINER_MODE)
    option(SelfRegisteringFactory_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(SelfRegisteringFactory_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(SelfRegisteringFactory_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(SelfRegisteringFactory_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(SelfRegisteringFactory_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(SelfRegisteringFactory_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(SelfRegisteringFactory_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(SelfRegisteringFactory_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(SelfRegisteringFactory_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(SelfRegisteringFactory_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(SelfRegisteringFactory_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(SelfRegisteringFactory_ENABLE_PCH "Enable precompiled headers" OFF)
    option(SelfRegisteringFactory_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(SelfRegisteringFactory_ENABLE_IPO "Enable IPO/LTO" ON)
    option(SelfRegisteringFactory_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(SelfRegisteringFactory_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(SelfRegisteringFactory_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(SelfRegisteringFactory_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(SelfRegisteringFactory_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(SelfRegisteringFactory_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(SelfRegisteringFactory_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(SelfRegisteringFactory_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(SelfRegisteringFactory_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(SelfRegisteringFactory_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(SelfRegisteringFactory_ENABLE_PCH "Enable precompiled headers" OFF)
    option(SelfRegisteringFactory_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      SelfRegisteringFactory_ENABLE_IPO
      SelfRegisteringFactory_WARNINGS_AS_ERRORS
      SelfRegisteringFactory_ENABLE_USER_LINKER
      SelfRegisteringFactory_ENABLE_SANITIZER_ADDRESS
      SelfRegisteringFactory_ENABLE_SANITIZER_LEAK
      SelfRegisteringFactory_ENABLE_SANITIZER_UNDEFINED
      SelfRegisteringFactory_ENABLE_SANITIZER_THREAD
      SelfRegisteringFactory_ENABLE_SANITIZER_MEMORY
      SelfRegisteringFactory_ENABLE_UNITY_BUILD
      SelfRegisteringFactory_ENABLE_CLANG_TIDY
      SelfRegisteringFactory_ENABLE_CPPCHECK
      SelfRegisteringFactory_ENABLE_COVERAGE
      SelfRegisteringFactory_ENABLE_PCH
      SelfRegisteringFactory_ENABLE_CACHE)
  endif()

  SelfRegisteringFactory_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (SelfRegisteringFactory_ENABLE_SANITIZER_ADDRESS OR SelfRegisteringFactory_ENABLE_SANITIZER_THREAD OR SelfRegisteringFactory_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(SelfRegisteringFactory_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(SelfRegisteringFactory_global_options)
  if(SelfRegisteringFactory_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    SelfRegisteringFactory_enable_ipo()
  endif()

  SelfRegisteringFactory_supports_sanitizers()

  if(SelfRegisteringFactory_ENABLE_HARDENING AND SelfRegisteringFactory_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR SelfRegisteringFactory_ENABLE_SANITIZER_UNDEFINED
       OR SelfRegisteringFactory_ENABLE_SANITIZER_ADDRESS
       OR SelfRegisteringFactory_ENABLE_SANITIZER_THREAD
       OR SelfRegisteringFactory_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${SelfRegisteringFactory_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${SelfRegisteringFactory_ENABLE_SANITIZER_UNDEFINED}")
    SelfRegisteringFactory_enable_hardening(SelfRegisteringFactory_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(SelfRegisteringFactory_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(SelfRegisteringFactory_warnings INTERFACE)
  add_library(SelfRegisteringFactory_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  SelfRegisteringFactory_set_project_warnings(
    SelfRegisteringFactory_warnings
    ${SelfRegisteringFactory_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(SelfRegisteringFactory_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    SelfRegisteringFactory_configure_linker(SelfRegisteringFactory_options)
  endif()

  include(cmake/Sanitizers.cmake)
  SelfRegisteringFactory_enable_sanitizers(
    SelfRegisteringFactory_options
    ${SelfRegisteringFactory_ENABLE_SANITIZER_ADDRESS}
    ${SelfRegisteringFactory_ENABLE_SANITIZER_LEAK}
    ${SelfRegisteringFactory_ENABLE_SANITIZER_UNDEFINED}
    ${SelfRegisteringFactory_ENABLE_SANITIZER_THREAD}
    ${SelfRegisteringFactory_ENABLE_SANITIZER_MEMORY})

  set_target_properties(SelfRegisteringFactory_options PROPERTIES UNITY_BUILD ${SelfRegisteringFactory_ENABLE_UNITY_BUILD})

  if(SelfRegisteringFactory_ENABLE_PCH)
    target_precompile_headers(
      SelfRegisteringFactory_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(SelfRegisteringFactory_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    SelfRegisteringFactory_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(SelfRegisteringFactory_ENABLE_CLANG_TIDY)
    SelfRegisteringFactory_enable_clang_tidy(SelfRegisteringFactory_options ${SelfRegisteringFactory_WARNINGS_AS_ERRORS})
  endif()

  if(SelfRegisteringFactory_ENABLE_CPPCHECK)
    SelfRegisteringFactory_enable_cppcheck(${SelfRegisteringFactory_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(SelfRegisteringFactory_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    SelfRegisteringFactory_enable_coverage(SelfRegisteringFactory_options)
  endif()

  if(SelfRegisteringFactory_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(SelfRegisteringFactory_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(SelfRegisteringFactory_ENABLE_HARDENING AND NOT SelfRegisteringFactory_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR SelfRegisteringFactory_ENABLE_SANITIZER_UNDEFINED
       OR SelfRegisteringFactory_ENABLE_SANITIZER_ADDRESS
       OR SelfRegisteringFactory_ENABLE_SANITIZER_THREAD
       OR SelfRegisteringFactory_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    SelfRegisteringFactory_enable_hardening(SelfRegisteringFactory_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
