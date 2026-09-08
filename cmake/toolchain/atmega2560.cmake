####
# atmega2560.cmake:
#
# Arduino Mega 2560 (MegaCore ATmega2560) toolchain for the F Prime CMake build
# system. Mirrors fprime-arduino/cmake/toolchain/ATmega128.cmake, with the FQBN
# and clock for the ATmega2560 (256 KB flash / 8 KB SRAM, 16 MHz external
# crystal on a stock Mega 2560 board).
#
# Used by: `fprime-util generate atmega2560` / `fprime-util build atmega2560`
# (also the default via `default_toolchain: atmega2560` in settings.ini).
####

# System setup for MegaCore / AVR
set(CMAKE_SYSTEM_NAME "Generic")
set(CMAKE_SYSTEM_PROCESSOR "avr")
set(CMAKE_CROSSCOMPILING 1)
set(FPRIME_PLATFORM "ArduinoFw")
set(FPRIME_USE_BAREMETAL_SCHEDULER ON)
set(ARDUINO_BUILD_PROPERTIES "build.extra_flags=-flto -mrelax -mcall-prologues")
set(ARDUINO_BOARD_OPTIONS "clock=16MHz_external")

set(ARDUINO_FQBN "MegaCore:avr:2560")
add_compile_options(-DATMEGA)

# fprime-arduino ships the shared arduino-cli support logic under its own
# cmake/toolchain/support/ directory. This project-local toolchain file has no
# such directory, so reach into the fprime-arduino submodule for it. Keep this
# path in sync with `lib/fprime-arduino` in .gitmodules.
get_filename_component(FPRIME_ARDUINO_DIR
    "${CMAKE_CURRENT_LIST_DIR}/../../lib/fprime-arduino" ABSOLUTE)
include("${FPRIME_ARDUINO_DIR}/cmake/toolchain/support/arduino-support.cmake")

# arduino-support.cmake sets CMAKE_AR (avr-gcc-ar) but leaves CMAKE_RANLIB unset,
# which makes CMake emit an empty archive-finish command ('"" libfoo.a' ->
# "/bin/sh: : Permission denied"). Derive the matching gcc ranlib wrapper (it
# adds the LTO --plugin option and lives next to avr-gcc-ar); fall back to a
# no-op since 'avr-gcc-ar rcs' already writes the archive index.
if(CMAKE_AR AND NOT CMAKE_RANLIB)
    string(REGEX REPLACE "-ar([^/]*)$" "-ranlib\\1" _ATMEGA_RANLIB "${CMAKE_AR}")
    if(EXISTS "${_ATMEGA_RANLIB}")
        set(CMAKE_RANLIB "${_ATMEGA_RANLIB}")
    endif()
endif()
if(NOT CMAKE_RANLIB)
    set(CMAKE_RANLIB ":")
endif()
