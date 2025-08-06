cmake_minimum_required(VERSION 3.15)
project(ModernDashboard)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(PkgConfig REQUIRED)
find_package(OpenSSL REQUIRED)

pkg_check_modules(SQLITE3 REQUIRED sqlite3)
pkg_check_modules(CURL REQUIRED libcurl)

find_path(AVCODEC_INCLUDE_DIR libavcodec/avcodec.h)
find_library(AVCODEC_LIBRARY avcodec)
find_path(AVFORMAT_INCLUDE_DIR libavformat/avformat.h)
find_library(AVFORMAT_LIBRARY avformat)

file(GLOB_RECURSE SOURCES "cpp_backend/src/*.cpp")
file(GLOB_RECURSE HEADERS "cpp_backend/include/*.h")

add_library(dashboard_backend SHARED ${SOURCES})

target_include_directories(dashboard_backend PRIVATE
    cpp_backend/include
    ${AVCODEC_INCLUDE_DIR}
    ${AVFORMAT_INCLUDE_DIR}
)

target_link_libraries(dashboard_backend
    ${SQLITE3_LIBRARIES}
    ${CURL_LIBRARIES}
    ${AVCODEC_LIBRARY}
    ${AVFORMAT_LIBRARY}
    OpenSSL::SSL
    OpenSSL::Crypto
)

if(WIN32)
    target_link_libraries(dashboard_backend ws2_32 winhttp)
    set_target_properties(dashboard_backend PROPERTIES
        OUTPUT_NAME "dashboard_backend"
        SUFFIX ".dll"
    )
elseif(APPLE)
    target_link_libraries(dashboard_backend "-framework Cocoa")
    set_target_properties(dashboard_backend PROPERTIES
        OUTPUT_NAME "libdashboard_backend"
        SUFFIX ".dylib"
    )
else()
    target_link_libraries(dashboard_backend pthread)
    set_target_properties(dashboard_backend PROPERTIES
        OUTPUT_NAME "libdashboard_backend"
        SUFFIX ".so"
    )
endif()
