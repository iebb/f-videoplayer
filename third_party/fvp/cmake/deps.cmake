
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
    set(MDK_SDK_SHA256 e61c38782b13198732749caaca436b7c0e13d34cf8d9050f5e5505838ab5529b)
    if(CMAKE_CXX_COMPILER_ARCHITECTURE_ID MATCHES "[xX]64") # msvc
      set(MDK_SDK_PKG mdk-sdk-windows-x64-vs2026.7z)
      set(MDK_SDK_SHA256 c541fa13dd12e17414eb05e6a176f3fb40a93cc5c38aaf85dbce1cd68d2828f0)
    endif()
  elseif(ANDROID)
    set(MDK_SDK_PKG mdk-sdk-android.7z)
    set(MDK_SDK_SHA256 580c657e635023fe588a007fb8acf06d1e11c5c28fefe3ae3302850b8be2d800)
  elseif(CMAKE_SYSTEM_NAME MATCHES "OHOS")
    set(MDK_SDK_PKG mdk-sdk-ohos.7z)
    set(MDK_SDK_SHA256 de5a8ff0a104b220601775019b350810a73c13354571100b9a649b46faf33d3d)
  elseif(LINUX OR CMAKE_SYSTEM_NAME MATCHES "Linux")
    set(MDK_SDK_PKG mdk-sdk-linux.tar.xz)
    set(MDK_SDK_SHA256 d89195411c42d213013f3e48f2ae707dffc6b750a73a56bdf7793dade582d6ae)
    if(CMAKE_C_COMPILER_ARCHITECTURE_ID MATCHES "[xX].*64")
      set(MDK_SDK_PKG mdk-sdk-linux-x64.tar.xz)
      set(MDK_SDK_SHA256 0e0aee20b1c12cbc2e5b362ad028e556748a39ba9785a1065bed0dea1148a882)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "[xX].*64" OR CMAKE_SYSTEM_PROCESSOR MATCHES "[aA][mM][dD]64")
      set(MDK_SDK_PKG mdk-sdk-linux-x64.tar.xz)
      set(MDK_SDK_SHA256 0e0aee20b1c12cbc2e5b362ad028e556748a39ba9785a1065bed0dea1148a882)
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
    set(FVP_DEPS_URL https://github.com/iebb/f-videoplayer/releases/download/mdk-nightly-2026-08-14)
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
