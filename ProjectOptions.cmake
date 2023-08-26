include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(CmakeTemplate_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(CmakeTemplate_setup_options)
  option(CmakeTemplate_ENABLE_HARDENING "Enable hardening" ON)
  option(CmakeTemplate_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    CmakeTemplate_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    CmakeTemplate_ENABLE_HARDENING
    OFF)

  CmakeTemplate_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR CmakeTemplate_PACKAGING_MAINTAINER_MODE)
    option(CmakeTemplate_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(CmakeTemplate_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(CmakeTemplate_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(CmakeTemplate_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(CmakeTemplate_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(CmakeTemplate_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(CmakeTemplate_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(CmakeTemplate_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(CmakeTemplate_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(CmakeTemplate_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(CmakeTemplate_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(CmakeTemplate_ENABLE_PCH "Enable precompiled headers" OFF)
    option(CmakeTemplate_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(CmakeTemplate_ENABLE_IPO "Enable IPO/LTO" ON)
    option(CmakeTemplate_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(CmakeTemplate_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(CmakeTemplate_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(CmakeTemplate_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(CmakeTemplate_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(CmakeTemplate_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(CmakeTemplate_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(CmakeTemplate_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(CmakeTemplate_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(CmakeTemplate_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(CmakeTemplate_ENABLE_PCH "Enable precompiled headers" OFF)
    option(CmakeTemplate_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      CmakeTemplate_ENABLE_IPO
      CmakeTemplate_WARNINGS_AS_ERRORS
      CmakeTemplate_ENABLE_USER_LINKER
      CmakeTemplate_ENABLE_SANITIZER_ADDRESS
      CmakeTemplate_ENABLE_SANITIZER_LEAK
      CmakeTemplate_ENABLE_SANITIZER_UNDEFINED
      CmakeTemplate_ENABLE_SANITIZER_THREAD
      CmakeTemplate_ENABLE_SANITIZER_MEMORY
      CmakeTemplate_ENABLE_UNITY_BUILD
      CmakeTemplate_ENABLE_CLANG_TIDY
      CmakeTemplate_ENABLE_CPPCHECK
      CmakeTemplate_ENABLE_COVERAGE
      CmakeTemplate_ENABLE_PCH
      CmakeTemplate_ENABLE_CACHE)
  endif()

  CmakeTemplate_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (CmakeTemplate_ENABLE_SANITIZER_ADDRESS OR CmakeTemplate_ENABLE_SANITIZER_THREAD OR CmakeTemplate_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(CmakeTemplate_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(CmakeTemplate_global_options)
  if(CmakeTemplate_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    CmakeTemplate_enable_ipo()
  endif()

  CmakeTemplate_supports_sanitizers()

  if(CmakeTemplate_ENABLE_HARDENING AND CmakeTemplate_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR CmakeTemplate_ENABLE_SANITIZER_UNDEFINED
       OR CmakeTemplate_ENABLE_SANITIZER_ADDRESS
       OR CmakeTemplate_ENABLE_SANITIZER_THREAD
       OR CmakeTemplate_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${CmakeTemplate_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${CmakeTemplate_ENABLE_SANITIZER_UNDEFINED}")
    CmakeTemplate_enable_hardening(CmakeTemplate_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(CmakeTemplate_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(CmakeTemplate_warnings INTERFACE)
  add_library(CmakeTemplate_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  CmakeTemplate_set_project_warnings(
    CmakeTemplate_warnings
    ${CmakeTemplate_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(CmakeTemplate_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(CmakeTemplate_options)
  endif()

  include(cmake/Sanitizers.cmake)
  CmakeTemplate_enable_sanitizers(
    CmakeTemplate_options
    ${CmakeTemplate_ENABLE_SANITIZER_ADDRESS}
    ${CmakeTemplate_ENABLE_SANITIZER_LEAK}
    ${CmakeTemplate_ENABLE_SANITIZER_UNDEFINED}
    ${CmakeTemplate_ENABLE_SANITIZER_THREAD}
    ${CmakeTemplate_ENABLE_SANITIZER_MEMORY})

  set_target_properties(CmakeTemplate_options PROPERTIES UNITY_BUILD ${CmakeTemplate_ENABLE_UNITY_BUILD})

  if(CmakeTemplate_ENABLE_PCH)
    target_precompile_headers(
      CmakeTemplate_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(CmakeTemplate_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    CmakeTemplate_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(CmakeTemplate_ENABLE_CLANG_TIDY)
    CmakeTemplate_enable_clang_tidy(CmakeTemplate_options ${CmakeTemplate_WARNINGS_AS_ERRORS})
  endif()

  if(CmakeTemplate_ENABLE_CPPCHECK)
    CmakeTemplate_enable_cppcheck(${CmakeTemplate_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(CmakeTemplate_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    CmakeTemplate_enable_coverage(CmakeTemplate_options)
  endif()

  if(CmakeTemplate_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(CmakeTemplate_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(CmakeTemplate_ENABLE_HARDENING AND NOT CmakeTemplate_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR CmakeTemplate_ENABLE_SANITIZER_UNDEFINED
       OR CmakeTemplate_ENABLE_SANITIZER_ADDRESS
       OR CmakeTemplate_ENABLE_SANITIZER_THREAD
       OR CmakeTemplate_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    CmakeTemplate_enable_hardening(CmakeTemplate_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
