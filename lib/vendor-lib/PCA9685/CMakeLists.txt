set(SOURCE_FILES "${CMAKE_CURRENT_LIST_DIR}/PCA9685.cpp")
# PCA9685.h includes <Wire.h>, which is a Teensy *library* (not core) header: it is only on the include path / linked
# if some CMake file declares it. Declare it here rather than relying on Arduino/Drv/I2cDriver doing it as a side effect.
# target_use_arduino_libraries() only exists under the Arduino toolchain, so guard it (same as I2cDriver's CMakeLists).
if (FPRIME_ARDUINO)
    target_use_arduino_libraries("Wire")
endif()
register_fprime_module()
if (TARGET PCA9685)
    target_include_directories(PCA9685 PUBLIC "${CMAKE_CURRENT_LIST_DIR}")
endif()
