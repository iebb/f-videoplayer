
function(fvp_version)
  if(NOT DEFINED CMAKE_CURRENT_FUNCTION_LIST_DIR)
    message(WARNING "CMAKE_CURRENT_FUNCTION_LIST_DIR not defined")
    set(CMAKE_CURRENT_FUNCTION_LIST_DIR ${CMAKE_CURRENT_LIST_DIR})
  endif()
  set(PUBSPEC_FILE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../pubspec.yaml")
  if(NOT EXISTS ${PUBSPEC_FILE})
    message(FATAL_ERROR "pubspec.yaml not found: ${PUBSPEC_FILE}")
  endif()
  file(READ ${PUBSPEC_FILE} PUBSPEC_CONTENTS)
  string(REGEX MATCH "version:[ \t]*([0-9]+\\.[0-9]+\\.[0-9]+|[0-9]+\\.[0-9]+|[^ \t\n\r]+)" MATCHED_LINE "${PUBSPEC_CONTENTS}")

  if(MATCHED_LINE)
    string(REGEX REPLACE "version:[ \t]*" "" FVP_VERSION "${MATCHED_LINE}")
    message(STATUS "Found fvp version: ${FVP_VERSION}")
    set(VERSION_HEADER_FILE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../lib/src/version.h")
    file(WRITE ${VERSION_HEADER_FILE} "#pragma once\n#define FVP_VERSION \"${FVP_VERSION}\"\n")
  else()
    message(WARNING "No version line found in file")
  endif()
endfunction(fvp_version)


macro(fvp_setup_deps)
  fvp_version()
  if(WIN32)
    set(MDK_SDK_PKG mdk-sdk-windows-vs2026.7z)
    set(MDK_SDK_SHA256 bec03fac5baee70df316981c5a63fe8be0efa80911c97f14840d2deef82928ce)
    if(CMAKE_CXX_COMPILER_ARCHITECTURE_ID MATCHES "[xX]64") # msvc
      set(MDK_SDK_PKG mdk-sdk-windows-x64-vs2026.7z)
      set(MDK_SDK_SHA256 57d38877a72607c5d135699207320d757b8c6b60437e8fb9b984ede5265a9c06)
    endif()
  elseif(ANDROID)
    set(MDK_SDK_PKG mdk-sdk-android.7z)
    set(MDK_SDK_SHA256 ac9ee8a4d24bb8a3d8294ff60fada7244145b8469fc1abbff8a9d45458b4de6a)
  elseif(CMAKE_SYSTEM_NAME MATCHES "OHOS")
    set(MDK_SDK_PKG mdk-sdk-ohos.7z)
    set(MDK_SDK_SHA256 6491cefb136ca56401c27947b5ee37e6533965f1aff826f1a6880a961c554672)
  elseif(LINUX OR CMAKE_SYSTEM_NAME MATCHES "Linux")
    set(MDK_SDK_PKG mdk-sdk-linux.tar.xz)
    set(MDK_SDK_SHA256 0ce5cc02a2adb07bd0d043d2cb88bbd97669282f848624ea3dd10d537757aff7)
    if(CMAKE_C_COMPILER_ARCHITECTURE_ID MATCHES "[xX].*64")
      set(MDK_SDK_PKG mdk-sdk-linux-x64.tar.xz)
      set(MDK_SDK_SHA256 9ce29b1c29aa2d051e52f50af8a1578ab80f6d17955a2935514e1c69b8a23d3e)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "[xX].*64" OR CMAKE_SYSTEM_PROCESSOR MATCHES "[aA][mM][dD]64")
      set(MDK_SDK_PKG mdk-sdk-linux-x64.tar.xz)
      set(MDK_SDK_SHA256 9ce29b1c29aa2d051e52f50af8a1578ab80f6d17955a2935514e1c69b8a23d3e)
    endif()
  endif()

  if(NOT DEFINED MDK_SDK_PKG OR NOT DEFINED MDK_SDK_SHA256)
    message(FATAL_ERROR "No pinned MDK SDK archive is configured for this platform")
  endif()

  if("$ENV{FVP_DEPS_LATEST}")
    message(FATAL_ERROR "FVP_DEPS_LATEST is disabled in this source-pinned fork. Set FVP_DEPS_URL and FVP_DEPS_SHA256 together for an audited override.")
  endif()

  if("$ENV{FVP_DEPS_URL}" MATCHES "^https://")
    set(FVP_DEPS_URL "$ENV{FVP_DEPS_URL}")
    set(MDK_SDK_SHA256 "$ENV{FVP_DEPS_SHA256}")
    string(LENGTH "${MDK_SDK_SHA256}" MDK_SDK_SHA256_LENGTH)
    if(NOT MDK_SDK_SHA256_LENGTH EQUAL 64 OR NOT MDK_SDK_SHA256 MATCHES "^[0-9A-Fa-f]+$")
      message(FATAL_ERROR "FVP_DEPS_URL requires the exact archive SHA-256 in FVP_DEPS_SHA256")
    endif()
  elseif(NOT "$ENV{FVP_DEPS_URL}" STREQUAL "")
    message(FATAL_ERROR "FVP_DEPS_URL must use HTTPS")
  else()
    # Keep every native target on the same pinned MDK release. The SHA-256
    # values above come from the immutable GitHub release asset metadata.
    set(FVP_DEPS_URL https://github.com/wang-bin/mdk-sdk/releases/download/v0.38.0)
  endif()
  set(MDK_SDK_URL "${FVP_DEPS_URL}/${MDK_SDK_PKG}")
  # Flutter reaches plugins through generated symlinks. Keep downloads,
  # extraction, and provenance checks on the canonical package directory.
  get_filename_component(MDK_SDK_ROOT "${CMAKE_CURRENT_SOURCE_DIR}" REALPATH)
  set(MDK_SDK_SAVE "${MDK_SDK_ROOT}/${MDK_SDK_PKG}")
  set(MDK_SDK_DIR "${MDK_SDK_ROOT}/mdk-sdk")
  set(MDK_SDK_MARKER "${MDK_SDK_DIR}/.fvp-archive-sha256")

  set(MDK_SDK_READY OFF)
  if(EXISTS "${MDK_SDK_DIR}/lib/cmake/FindMDK.cmake" AND EXISTS "${MDK_SDK_MARKER}")
    file(READ "${MDK_SDK_MARKER}" MDK_SDK_EXTRACTED_SHA256)
    string(STRIP "${MDK_SDK_EXTRACTED_SHA256}" MDK_SDK_EXTRACTED_SHA256)
    if(MDK_SDK_EXTRACTED_SHA256 STREQUAL MDK_SDK_SHA256)
      set(MDK_SDK_READY ON)
    endif()
  endif()
  if(EXISTS "${MDK_SDK_DIR}" AND NOT MDK_SDK_READY)
    file(REMOVE_RECURSE "${MDK_SDK_DIR}")
    message(STATUS "Removed unverified or stale extracted MDK SDK")
  endif()

  if(EXISTS "${MDK_SDK_SAVE}")
    file(SHA256 "${MDK_SDK_SAVE}" MDK_SDK_ACTUAL_SHA256)
    if(NOT MDK_SDK_ACTUAL_SHA256 STREQUAL MDK_SDK_SHA256)
      file(REMOVE "${MDK_SDK_SAVE}")
      message(STATUS "Removed MDK archive with an unexpected SHA-256")
    endif()
  endif()

  if(NOT MDK_SDK_READY)
    if(NOT EXISTS "${MDK_SDK_SAVE}")
      message("Downloading mdk-sdk from ${MDK_SDK_URL}")
      file(
        DOWNLOAD "${MDK_SDK_URL}" "${MDK_SDK_SAVE}"
        EXPECTED_HASH "SHA256=${MDK_SDK_SHA256}"
        STATUS MDK_DOWNLOAD_STATUS
        SHOW_PROGRESS
        TLS_VERIFY ON
      )
      list(GET MDK_DOWNLOAD_STATUS 0 MDK_DOWNLOAD_CODE)
      list(GET MDK_DOWNLOAD_STATUS 1 MDK_DOWNLOAD_MESSAGE)
      if(NOT MDK_DOWNLOAD_CODE EQUAL 0)
        file(REMOVE "${MDK_SDK_SAVE}")
        message(FATAL_ERROR "Failed to download verified mdk-sdk: ${MDK_DOWNLOAD_MESSAGE}")
      endif()
    endif()
    execute_process(
      COMMAND ${CMAKE_COMMAND} -E tar "xvf" "${MDK_SDK_SAVE}" # "--format=7zip"
      WORKING_DIRECTORY "${MDK_SDK_ROOT}"
      OUTPUT_STRIP_TRAILING_WHITESPACE
      RESULT_VARIABLE EXTRACT_RET
    )
    # EXTRACT_RET is 0 even for empty files
    if(NOT EXTRACT_RET EQUAL 0 OR NOT EXISTS "${MDK_SDK_DIR}/lib/cmake/FindMDK.cmake")
      file(REMOVE "${MDK_SDK_SAVE}")
      message(FATAL_ERROR "Failed to extract mdk-sdk. You can download manually from ${MDK_SDK_URL} and extract to ${CMAKE_CURRENT_SOURCE_DIR}")
    endif()
    file(WRITE "${MDK_SDK_MARKER}" "${MDK_SDK_SHA256}\n")
  endif()
  include("${MDK_SDK_DIR}/lib/cmake/FindMDK.cmake")
endmacro()
