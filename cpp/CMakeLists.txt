cmake_minimum_required(VERSION 3.10)
project(ImageProcessor VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

add_library(image_processor SHARED
    image_processor.cpp
    image_processor.h
)

target_include_directories(image_processor PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)

set_target_properties(image_processor PROPERTIES
    PUBLIC_HEADER image_processor.h
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../python/lib
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../python/lib
)

if(WIN32)
    set_target_properties(image_processor PROPERTIES
        PREFIX ""
        SUFFIX ".pyd"
    )
endif()

if(APPLE)
    set_target_properties(image_processor PROPERTIES
        PREFIX ""
        SUFFIX ".so"
    )
endif()

if(UNIX AND NOT APPLE)
    set_target_properties(image_processor PROPERTIES
        PREFIX ""
        SUFFIX ".so"
    )
endif()
