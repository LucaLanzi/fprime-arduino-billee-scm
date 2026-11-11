####
# This sets up the build system for the 'FprimeArduinoBilleeScm' project, including
# components and deployments from project.cmake. In addition, it imports the core F Prime components.
####

cmake_minimum_required(VERSION 3.24.2)
project(FprimeArduinoBilleeScm C CXX)

# Works around a Teensyduino linker-script bug (see cmake/teensy_arm_extab_fix.cmake) that
# otherwise fails the teensy41 link with "relocation truncated to fit: R_ARM_PREL31 against
# `.ARM.extab'". No-ops for non-Teensy platforms.
include("${CMAKE_CURRENT_LIST_DIR}/cmake/teensy_arm_extab_fix.cmake")

# Teensy 4.1 runs all code from RAM1 (ITCM, allocated in 32 KB blocks), and whatever RAM1 the code
# doesn't take is shared by variables and the stack. Compile with -Os (Teensyduino's "Smallest Code")
# instead of the toolchain's -O2 so the deployment fits; GCC uses the last -O flag, and these options
# come after the toolchain's flags. Check `teensy_size` "free for local variables" after adding code.
if (ARDUINO_FQBN STREQUAL "teensy:avr:teensy41")
    add_compile_options(-Os)
endif()

###
# F' Core Setup
# This includes all of the F prime core components, and imports the make-system.
###
include("${CMAKE_CURRENT_LIST_DIR}/lib/fprime/cmake/FPrime.cmake")
# NOTE: register custom targets between these two lines
fprime_setup_included_code()


# This includes project-wide objects
add_fprime_subdirectory("${CMAKE_CURRENT_LIST_DIR}/FprimeArduinoBilleeScm")

# Defines the (opt-in, not part of `all`) `flash-teensy41` target: `fprime-util build teensy41
# --target flash-teensy41` or `make flash`. No-ops if teensy_loader_cli isn't installed.
include("${CMAKE_CURRENT_LIST_DIR}/cmake/teensy_flash_target.cmake")
