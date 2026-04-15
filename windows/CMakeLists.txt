# Project-level configuration.
cmake_minimum_required(VERSION 3.14)

# Tell CMake to accept any Windows 10+ SDK (including Windows 11 SDK).
# "10.0" means "find the latest 10.x SDK" — Win11 SDK versions start with 10.0.22xxx.
# This does NOT affect which Windows version the app runs on — it's just
# which SDK headers/libraries the compiler uses during build.
set(CMAKE_SYSTEM_VERSION 10.0 CACHE STRING "Windows SDK version" FORCE)

project(Converta LANGUAGES CXX)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "Converta")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)


# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)

# --- CONVERTA NATIVE ---
# Builds converta_core.dll from the native C++ sources and copies it
# (plus FFmpeg runtime DLLs) next to the Flutter exe on every build.
#
# Assumed layout (relative to repo root):
#   native/
#     include/          converta.h
#     src/              converta.cpp  avif_codec.cpp
#     third_party/
#       ffmpeg-windows/
#         include/      FFmpeg headers
#         lib/          avcodec.lib  avformat.lib  avutil.lib  swscale.lib  swresample.lib
#         bin/          avcodec-*.dll  avformat-*.dll  avutil-*.dll  swscale-*.dll  swresample-*.dll
#       libavif/
#         include/      avif/avif.h
#         lib/          avif.lib
#         bin/          avif.dll
#       stb/
#         stb_image.h   stb_image_write.h

set(CONVERTA_NATIVE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../native")
set(CONVERTA_FFMPEG_DIR "${CONVERTA_NATIVE_DIR}/third_party/ffmpeg-windows")
set(CONVERTA_AVIF_DIR   "${CONVERTA_NATIVE_DIR}/third_party/libavif")
set(CONVERTA_STB_DIR    "${CONVERTA_NATIVE_DIR}/third_party/stb")

# ── Build the DLL ─────────────────────────────────────────────────────────────
add_library(converta_core SHARED
  "${CONVERTA_NATIVE_DIR}/src/converta.cpp"
  "${CONVERTA_NATIVE_DIR}/src/avif_codec.cpp"
  "${CONVERTA_NATIVE_DIR}/src/thread_pool.cpp"
)

target_compile_definitions(converta_core PRIVATE CONVERTA_CORE_EXPORTS)

target_include_directories(converta_core PRIVATE
  "${CONVERTA_NATIVE_DIR}/include"
  "${CONVERTA_FFMPEG_DIR}/include"
  "${CONVERTA_AVIF_DIR}/include"
  "${CONVERTA_STB_DIR}"
)

target_link_libraries(converta_core PRIVATE
  "${CONVERTA_FFMPEG_DIR}/lib/avcodec.lib"
  "${CONVERTA_FFMPEG_DIR}/lib/avformat.lib"
  "${CONVERTA_FFMPEG_DIR}/lib/avutil.lib"
  "${CONVERTA_FFMPEG_DIR}/lib/swscale.lib"
  "${CONVERTA_FFMPEG_DIR}/lib/swresample.lib"
  "${CONVERTA_AVIF_DIR}/lib/avif.lib"
)

# Use C++17 (already the project standard, stated explicitly for clarity).
set_target_properties(converta_core PROPERTIES CXX_STANDARD 17)

# ── Copy DLLs next to the runner exe after each build ─────────────────────────
# $<TARGET_FILE_DIR:Converta> resolves to the correct Debug/Profile/Release dir.
set(CONVERTA_OUTPUT_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")

# converta_core.dll itself
add_custom_command(TARGET converta_core POST_BUILD
  COMMAND "${CMAKE_COMMAND}" -E copy_if_different
    "$<TARGET_FILE:converta_core>"
    "${CONVERTA_OUTPUT_DIR}/"
  COMMENT "Copying converta_core.dll to runner output"
)

# FFmpeg runtime DLLs (globbed at configure time; covers gyan.dev naming like avcodec-61.dll)
file(GLOB CONVERTA_FFMPEG_DLLS "${CONVERTA_FFMPEG_DIR}/bin/*.dll")
if(CONVERTA_FFMPEG_DLLS)
  add_custom_command(TARGET converta_core POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
      ${CONVERTA_FFMPEG_DLLS}
      "${CONVERTA_OUTPUT_DIR}/"
    COMMENT "Copying FFmpeg DLLs to runner output"
  )
endif()

# libavif runtime DLL
file(GLOB CONVERTA_AVIF_DLLS "${CONVERTA_AVIF_DIR}/bin/*.dll")
if(CONVERTA_AVIF_DLLS)
  add_custom_command(TARGET converta_core POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
      ${CONVERTA_AVIF_DLLS}
      "${CONVERTA_OUTPUT_DIR}/"
    COMMENT "Copying libavif DLLs to runner output"
  )
endif()

# (Removed explicit add_dependencies(${BINARY_NAME} converta_core) here
# because $<TARGET_FILE_DIR> implicitly handles the structural dependency
# without creating a cyclic dependency loop.)
# --- END CONVERTA NATIVE ---
