cmake_minimum_required(VERSION 3.15)
project(ModernDashboard)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(PkgConfig REQUIRED)
find_package(OpenSSL REQUIRED)

pkg_check_modules(CURL REQUIRED libcurl)

# Source and header discovery
file(GLOB_RECURSE SOURCES "cpp_backend/src/*.cpp")
file(GLOB_RECURSE HEADERS "cpp_backend/include/*.h")

# Create shared library target for FFI: moderndash
# Define shared library with export macro
add_library(moderndash SHARED ${SOURCES})
target_compile_definitions(moderndash PRIVATE MODERNDASH_BUILD)

target_include_directories(moderndash PRIVATE
    cpp_backend/include
    shared
)

target_link_libraries(moderndash
    ${CURL_LIBRARIES}
    OpenSSL::SSL
    OpenSSL::Crypto
)

# Platform-specific properties and deps
if(WIN32)
    target_link_libraries(moderndash ws2_32 winhttp)
    set_target_properties(moderndash PROPERTIES
        OUTPUT_NAME "moderndash"
        SUFFIX ".dll"
    )
elseif(APPLE)
    target_link_libraries(moderndash "-framework Cocoa")
    # Name library as libmoderndash.dylib and set install_name for Flutter embedding
    set_target_properties(moderndash PROPERTIES
        OUTPUT_NAME "moderndash"
        SUFFIX ".dylib"
        MACOSX_RPATH ON
        BUILD_WITH_INSTALL_RPATH ON
        INSTALL_NAME_DIR "@rpath"
        INSTALL_RPATH "@rpath"
    )
else()
    target_link_libraries(moderndash pthread)
    set_target_properties(moderndash PROPERTIES
        OUTPUT_NAME "moderndash"
        SUFFIX ".so"
    )
endif()

# Test executable linking against the shared library (ensure it does not define symbols separately)
add_executable(ModernDashboard cpp_backend/src/main.cpp)
target_include_directories(ModernDashboard PRIVATE
    cpp_backend/include
    shared
)
# Ensure the executable links to the shared library C API, avoiding duplicate symbol issues
target_link_libraries(ModernDashboard moderndash)
