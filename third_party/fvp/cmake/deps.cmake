
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
    set(MDK_SDK_SHA256 cbba7b970908aa65f9bc3f68f7cac02a34172ae1af6227a5984639b5661ae0b8)
    if(CMAKE_CXX_COMPILER_ARCHITECTURE_ID MATCHES "[xX]64") # msvc
      set(MDK_SDK_PKG mdk-sdk-windows-x64-vs2026.7z)
      set(MDK_SDK_SHA256 5c08ba8b7dc08fc118180e89907478f29004d2d78d0e705ced71325d97d5018a)
    endif()
  elseif(ANDROID)
    set(MDK_SDK_PKG mdk-sdk-android.7z)
    set(MDK_SDK_SHA256 87aa236840134fe3b5c3b08e813c2b4f0557d4c2fc7034679417bc598dd785ba)
  elseif(CMAKE_SYSTEM_NAME MATCHES "OHOS")
    set(MDK_SDK_PKG mdk-sdk-ohos.7z)
    set(MDK_SDK_SHA256 c1435c774413f7442118c3b6816cd4b55d7aab7d5e16fe4fce0fc2d73c3b6453)
  elseif(LINUX OR CMAKE_SYSTEM_NAME MATCHES "Linux")
    set(MDK_SDK_PKG mdk-sdk-linux.tar.xz)
    set(MDK_SDK_SHA256 6c19de4ac3477cc1f63280dd753d5c3ad9f25a344d607a34513aa78eb2e99384)
    if(CMAKE_C_COMPILER_ARCHITECTURE_ID MATCHES "[xX].*64")
      set(MDK_SDK_PKG mdk-sdk-linux-x64.tar.xz)
      set(MDK_SDK_SHA256 111afc94fce1d209b4fbd26810707f37c14c4c9194f4ccf6f5003bad7548fabf)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "[xX].*64" OR CMAKE_SYSTEM_PROCESSOR MATCHES "[aA][mM][dD]64")
      set(MDK_SDK_PKG mdk-sdk-linux-x64.tar.xz)
      set(MDK_SDK_SHA256 111afc94fce1d209b4fbd26810707f37c14c4c9194f4ccf6f5003bad7548fabf)
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
    set(FVP_DEPS_URL https://github.com/wang-bin/mdk-sdk/releases/download/v0.37.0)
  endif()
  set(MDK_SDK_URL "${FVP_DEPS_URL}/${MDK_SDK_PKG}")
  set(MDK_SDK_SAVE "${CMAKE_CURRENT_SOURCE_DIR}/${MDK_SDK_PKG}")

  if(EXISTS "${MDK_SDK_SAVE}")
    file(SHA256 "${MDK_SDK_SAVE}" MDK_SDK_ACTUAL_SHA256)
    if(NOT MDK_SDK_ACTUAL_SHA256 STREQUAL MDK_SDK_SHA256)
      file(REMOVE "${MDK_SDK_SAVE}")
      message(STATUS "Removed MDK archive with an unexpected SHA-256")
    endif()
  endif()

  if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/mdk-sdk/lib/cmake/FindMDK.cmake")
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
    # Flutter reaches plugins through a generated symlink. Newer CMake secure
    # archive extraction refuses to write through that path, so extract through
    # its canonical directory instead.
    get_filename_component(MDK_SDK_EXTRACT_DIR "${CMAKE_CURRENT_SOURCE_DIR}" REALPATH)
    execute_process(
      COMMAND ${CMAKE_COMMAND} -E tar "xvf" "${MDK_SDK_SAVE}" # "--format=7zip"
      WORKING_DIRECTORY "${MDK_SDK_EXTRACT_DIR}"
      OUTPUT_STRIP_TRAILING_WHITESPACE
      RESULT_VARIABLE EXTRACT_RET
    )
    # EXTRACT_RET is 0 even for empty files
    if(NOT EXTRACT_RET EQUAL 0 OR NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/mdk-sdk/lib/cmake/FindMDK.cmake)
      file(REMOVE "${MDK_SDK_SAVE}")
      message(FATAL_ERROR "Failed to extract mdk-sdk. You can download manually from ${MDK_SDK_URL} and extract to ${CMAKE_CURRENT_SOURCE_DIR}")
    endif()
  endif()
  include(${CMAKE_CURRENT_SOURCE_DIR}/mdk-sdk/lib/cmake/FindMDK.cmake)
endmacro()
