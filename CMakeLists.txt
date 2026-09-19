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
