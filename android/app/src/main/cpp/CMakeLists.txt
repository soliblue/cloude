cmake_minimum_required(VERSION 3.22.1)
project(swift_bridge C)

add_library(swift_bridge SHARED swift_bridge_jni.c)

target_link_libraries(swift_bridge
    ${CMAKE_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libCloudeAndroidBridge.so
    log
)
