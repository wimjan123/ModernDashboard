cmake_minimum_required(VERSION 3.15)
project(ModernDashboard)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(PkgConfig REQUIRED)

# Check for required dependencies with fallbacks
pkg_check_modules(CURL REQUIRED libcurl)
if(NOT CURL_FOUND)
    find_package(CURL REQUIRED)
    set(CURL_LIBRARIES ${CURL_LIBRARIES})
    set(CURL_INCLUDE_DIRS ${CURL_INCLUDE_DIRS})
endif()

pkg_check_modules(TINYXML2 REQUIRED tinyxml2)
if(NOT TINYXML2_FOUND)
    find_package(tinyxml2 REQUIRED)
    set(TINYXML2_LIBRARIES tinyxml2::tinyxml2)
    get_target_property(TINYXML2_INCLUDE_DIRS tinyxml2::tinyxml2 INTERFACE_INCLUDE_DIRECTORIES)
endif()

pkg_check_modules(SQLITE3 REQUIRED sqlite3)
if(NOT SQLITE3_FOUND)
    find_package(SQLite3 REQUIRED)
    set(SQLITE3_LIBRARIES SQLite::SQLite3)
    get_target_property(SQLITE3_INCLUDE_DIRS SQLite::SQLite3 INTERFACE_INCLUDE_DIRECTORIES)
endif()

find_package(OpenSSL REQUIRED)
find_package(nlohmann_json 3.2.0 REQUIRED)

# Print dependency status for debugging
message(STATUS "CURL found: ${CURL_FOUND}, libraries: ${CURL_LIBRARIES}")
message(STATUS "TINYXML2 found: ${TINYXML2_FOUND}, libraries: ${TINYXML2_LIBRARIES}")
message(STATUS "SQLITE3 found: ${SQLITE3_FOUND}, libraries: ${SQLITE3_LIBRARIES}")
message(STATUS "OpenSSL found: ${OPENSSL_FOUND}, libraries: ${OPENSSL_LIBRARIES}")
message(STATUS "nlohmann_json found: ${nlohmann_json_FOUND}")

# Source and header discovery
file(GLOB_RECURSE SOURCES "cpp_backend/src/*.cpp" "cpp_backend/src/services/news_service.cpp" "cpp_backend/src/services/weather_service.cpp" "cpp_backend/src/services/todo_service.cpp" "cpp_backend/src/services/mail_service.cpp" "cpp_backend/src/services/stream_service.cpp")
file(GLOB_RECURSE HEADERS "cpp_backend/include/*.h")

# Create shared library target for FFI: moderndash
# Define shared library with export macro
add_library(moderndash SHARED ${SOURCES})
target_compile_definitions(moderndash PRIVATE MODERNDASH_BUILD)

# Make include paths visible to dependents as well (fixes header resolution like shared/ffi_interface.h)
target_include_directories(moderndash
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/cpp_backend/include
        ${CMAKE_CURRENT_SOURCE_DIR}/shared
        ${TINYXML2_INCLUDE_DIRS}
        ${SQLITE3_INCLUDE_DIRS}
)

target_link_libraries(moderndash
    ${CURL_LIBRARIES}
    ${TINYXML2_LIBRARIES}
    ${SQLITE3_LIBRARIES}
    OpenSSL::SSL
    OpenSSL::Crypto
    nlohmann_json::nlohmann_json
)

# Add library directories for pkg-config libraries
target_link_directories(moderndash PRIVATE
    ${TINYXML2_LIBRARY_DIRS}
    ${SQLITE3_LIBRARY_DIRS}
    ${CURL_LIBRARY_DIRS}
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
    # Name library as moderndash.dylib (without lib prefix) for Flutter FFI
    set_target_properties(moderndash PROPERTIES
        OUTPUT_NAME "moderndash"
        PREFIX ""
        SUFFIX ".dylib"
        MACOSX_RPATH ON
        BUILD_WITH_INSTALL_RPATH ON
        INSTALL_NAME_DIR "@rpath"
        INSTALL_RPATH "@executable_path;@executable_path/../lib;@loader_path"
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
    ${CMAKE_CURRENT_SOURCE_DIR}/cpp_backend/include
    ${CMAKE_CURRENT_SOURCE_DIR}/shared
)
# Ensure the executable links to the shared library C API, avoiding duplicate symbol issues
target_link_libraries(ModernDashboard moderndash)

# Add library directories for the executable too (needed on macOS)
target_link_directories(ModernDashboard PRIVATE
    ${TINYXML2_LIBRARY_DIRS}
    ${SQLITE3_LIBRARY_DIRS}
    ${CURL_LIBRARY_DIRS}
)

# Add install targets for library deployment
install(TARGETS moderndash
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
    ARCHIVE DESTINATION lib
)

# Print build information
message(STATUS "Building shared library: ${CMAKE_CURRENT_BINARY_DIR}/moderndash${CMAKE_SHARED_LIBRARY_SUFFIX}")
message(STATUS "Build type: ${CMAKE_BUILD_TYPE}")
message(STATUS "C++ standard: ${CMAKE_CXX_STANDARD}")
