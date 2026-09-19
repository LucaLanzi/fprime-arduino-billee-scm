####
# teensy_flash_target.cmake:
#
# Defines a `flash-teensy41` CMake target that flashes the billee_deployment .hex onto a
# connected Teensy 4.1 via teensy_loader_cli (headless - no GUI Teensy Loader app needed).
# Not part of the default `all` target, so it never runs on a plain build; invoke it with:
#
#   fprime-util build teensy41 --target flash-teensy41
#   (or: make flash)
#
# Requires teensy_loader_cli on PATH - see `make setup-flash-tools`.
####

if (NOT ARDUINO_FQBN STREQUAL "teensy:avr:teensy41")
    return()
endif()

set(TEENSY_DEPLOYMENT_TARGET "FprimeArduinoBilleeScm_billee_deployment")
if (NOT TARGET "${TEENSY_DEPLOYMENT_TARGET}")
    return()
endif()

find_program(TEENSY_LOADER_CLI teensy_loader_cli)
if (NOT TEENSY_LOADER_CLI)
    message(WARNING "[teensy_flash_target] teensy_loader_cli not found on PATH; \"flash-teensy41\" target will not be defined. Run `make setup-flash-tools` (or `sudo apt-get install teensy-loader-cli`) to install it.")
    return()
endif()

add_custom_target(flash-teensy41
    COMMAND "${CMAKE_CURRENT_LIST_DIR}/teensy_flash_retry.sh" "${TEENSY_LOADER_CLI}" --mcu=TEENSY41 -w -v -s "$<TARGET_FILE:${TEENSY_DEPLOYMENT_TARGET}>.hex"
    DEPENDS "${TEENSY_DEPLOYMENT_TARGET}"
    COMMENT "Flashing ${TEENSY_DEPLOYMENT_TARGET} onto Teensy 4.1 via teensy_loader_cli (auto-retries on the known intermittent first-write failure)"
    VERBATIM
    USES_TERMINAL
)
