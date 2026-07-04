# Standalone build for the semsys Csound plugin.
#
# semsys was originally a subdirectory of the csound-plugins tree, which supplied
# the project scaffolding (make_plugin, PLUGIN_INSTALL_DIR, vendored Csound
# headers). This top-level file reproduces the minimum of that scaffolding so the
# plugin builds on its own, then includes the plugin definition in
# cmake/semsys.cmake (the former in-tree fragment, unchanged).
#
# The plugin only needs the Csound plugin SDK *headers* at build time (it loads
# onnxruntime at runtime via dlopen -- see cmake/semsys.cmake and semsys.c). Those
# headers are NOT bundled here; point CSOUND_INCLUDE_DIR at them:
#
#   cmake -S . -B build -DCSOUND_INCLUDE_DIR=/path/to/csound/include
#   cmake --build build --target semsys --parallel
#
# where /path/to/csound/include is a Csound source checkout's include/ directory
# (contains csdl.h, csound.h, sysdep.h, soundfile.h, arrays.h).

cmake_minimum_required(VERSION 3.15)
project(csound_semsys C)

# semsys is Csound API 7 only.
set(APIVERSION "7.0" CACHE STRING "Csound API version (semsys requires 7.0)")

if(CMAKE_SYSTEM_NAME MATCHES "Linux")
    set(LINUX YES)
else()
    set(LINUX NO)
endif()

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Release")
endif()

set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(CMAKE_MACOSX_RPATH 1)
set(CMAKE_EXPORT_COMPILE_COMMANDS 1)

option(USE_DOUBLE "Use doubles for audio calculations" ON)
if(USE_DOUBLE)
    add_definitions(-DUSE_DOUBLE -DB64BIT)
endif()

add_definitions(-DCSOUNDAPI7 -DCS_API_VERSION_MAJOR=7)

# --- Csound plugin SDK headers ---------------------------------------------
# semsys needs csdl.h / csound.h / sysdep.h / soundfile.h / arrays.h from the
# Csound plugin SDK. They are external (not vendored). Override with
# -DCSOUND_INCLUDE_DIR=/path, or let the common install/framework paths be tried.
find_path(CSOUND_INCLUDE_DIR
    NAMES csdl.h
    HINTS ENV CSOUND_INCLUDE_DIR ENV CSOUND_HOME
    PATHS
        /usr/local/include/csound
        /usr/include/csound
        /opt/homebrew/include/csound
        /Library/Frameworks/CsoundLib64.framework/Headers
    PATH_SUFFIXES include include/csound)

if(NOT CSOUND_INCLUDE_DIR)
    message(FATAL_ERROR
        "Csound plugin headers (csdl.h) not found. "
        "Pass -DCSOUND_INCLUDE_DIR=/path/to/csound/include "
        "(a Csound source checkout's include/ directory).")
endif()
message(STATUS "semsys: Csound headers at ${CSOUND_INCLUDE_DIR}")

# csound.h #includes a *generated* version.h. A proper Csound install ships it in
# the include dir; a raw source checkout generates it elsewhere (e.g. under
# Android/CsoundAndroid/jni). Make sure it is reachable, else the build fails with
# "version.h file not found".
set(CSOUND_EXTRA_INCLUDE_DIRS "" CACHE STRING
    "Extra Csound include dirs (semicolon-separated), e.g. the dir holding a generated version.h")
if(NOT EXISTS "${CSOUND_INCLUDE_DIR}/version.h")
    find_file(CSOUND_VERSION_H version.h
        PATHS "${CSOUND_INCLUDE_DIR}/.."
        PATH_SUFFIXES Android/CsoundAndroid/jni
        NO_DEFAULT_PATH)
    if(CSOUND_VERSION_H)
        get_filename_component(_vdir "${CSOUND_VERSION_H}" DIRECTORY)
        list(APPEND CSOUND_EXTRA_INCLUDE_DIRS "${_vdir}")
        message(STATUS "semsys: generated version.h at ${_vdir}")
    elseif(NOT CSOUND_EXTRA_INCLUDE_DIRS)
        message(WARNING
            "Csound version.h not found next to csdl.h. When building against a "
            "Csound source checkout, pass -DCSOUND_EXTRA_INCLUDE_DIRS=/dir/with/version.h")
    endif()
endif()

# --- plugin install dir (matches csound-plugins layout) --------------------
if(APPLE)
    set(PLUGIN_INSTALL_DIR "$ENV{HOME}/Library/csound/${APIVERSION}/plugins64")
elseif(LINUX)
    set(PLUGIN_INSTALL_DIR "$ENV{HOME}/.local/lib/csound/${APIVERSION}/plugins64")
elseif(WIN32)
    set(PLUGIN_INSTALL_DIR "$ENV{LOCALAPPDATA}/csound/${APIVERSION}/plugins64")
endif()

# --- make_plugin: SHARED on macOS, MODULE elsewhere ------------------------
# Output names: libsemsys.dylib / libsemsys.so / semsys.dll -- matching the
# extractpath values in risset.json.
set(BUILD_PLUGINS_DIR ${CMAKE_CURRENT_BINARY_DIR})
function(make_plugin pluginlib srcs)
    message(STATUS "make_plugin: ${pluginlib}, sources: ${srcs}")
    if(APPLE)
        add_library(${pluginlib} SHARED ${srcs})
    else()
        add_library(${pluginlib} MODULE ${srcs})
    endif()
    target_include_directories(${pluginlib} PRIVATE ${CSOUND_INCLUDE_DIR} ${CSOUND_EXTRA_INCLUDE_DIRS})
    set_property(TARGET ${pluginlib} PROPERTY C_STANDARD 99)
    set_target_properties(${pluginlib} PROPERTIES
        RUNTIME_OUTPUT_DIRECTORY ${BUILD_PLUGINS_DIR}
        LIBRARY_OUTPUT_DIRECTORY ${BUILD_PLUGINS_DIR})
    install(TARGETS ${pluginlib} LIBRARY DESTINATION "${PLUGIN_INSTALL_DIR}")
endfunction()

# --- the plugin itself (former in-tree fragment) ---------------------------
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/semsys.cmake)
