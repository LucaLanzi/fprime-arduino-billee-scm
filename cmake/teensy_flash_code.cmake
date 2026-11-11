####
# teensy_flash_code.cmake
#
# Teensy 4.1 runs all code from RAM1 (ITCM, allocated in 32 KB blocks) and keeps all read-only data (.rodata) in RAM1
# too (DTCM). Whatever RAM1 those don't use is the stack. This deployment outgrew that: adding the load-cell manager
# pushed the Jetson build's code into an 11th block, leaving 12 KB of stack.
#
# This file derives a copy of Teensy's linker script in the build directory that places the code and read-only data
# of the libraries in TEENSY_FLASH_LIBRARIES in FLASH instead (the script's .text.code section, which already
# collects FLASHMEM functions and is matched before the RAM1 .text section). Those libraries only run when a sequence
# or a file operation runs, where flash execution (cached, 600 MHz) is plenty fast. Teensy's own install is not
# modified. Add a library here only if it is not timing critical: code in flash runs slower on a cache miss.
#
# Check the effect with teensy_size (README "RAM1 budget"): code should drop, and `nm` shows the moved functions at
# 0x6xxxxxxx (flash) instead of 0x0000xxxx (ITCM).
####
if (NOT ARDUINO_FQBN STREQUAL "teensy:avr:teensy41")
    return()
endif()

set(TEENSY_FLASH_LIBRARIES
    Svc_CmdSequencer   # sequence loading and stepping
    Svc_FileManager    # SD file commands
    Svc_FileUplink     # file uplink from the GDS
    Fw_FilePacket      # file uplink packets
    CFDP_Checksum      # file uplink checksum
)

string(REGEX MATCH "-T([^ ]+imxrt1062_t41\\.ld)" _ "${CMAKE_EXE_LINKER_FLAGS}")
set(TEENSY_ORIGINAL_LD "${CMAKE_MATCH_1}")
if (NOT TEENSY_ORIGINAL_LD OR NOT EXISTS "${TEENSY_ORIGINAL_LD}")
    message(WARNING "[teensy_flash_code] Teensy linker script not found in CMAKE_EXE_LINKER_FLAGS; cold libraries stay in RAM1")
    return()
endif()

set(TEENSY_FLASH_PATTERNS "")
foreach(FLASH_LIB IN LISTS TEENSY_FLASH_LIBRARIES)
    string(APPEND TEENSY_FLASH_PATTERNS "\t\t*lib${FLASH_LIB}.a:(.text* .rodata*)\n")
endforeach()

file(READ "${TEENSY_ORIGINAL_LD}" TEENSY_LD_CONTENT)
string(REGEX REPLACE "(\\*\\(\\.flashmem\\*\\)[^\n]*\n)" "\\1${TEENSY_FLASH_PATTERNS}" TEENSY_LD_NEW "${TEENSY_LD_CONTENT}")
if (TEENSY_LD_NEW STREQUAL TEENSY_LD_CONTENT)
    message(WARNING "[teensy_flash_code] No *(.flashmem*) line in ${TEENSY_ORIGINAL_LD}; cold libraries stay in RAM1")
    return()
endif()

set(TEENSY_FLASH_LD "${CMAKE_BINARY_DIR}/imxrt1062_t41_flash_code.ld")
# Write only on change so an unchanged script does not force a relink
if (EXISTS "${TEENSY_FLASH_LD}")
    file(READ "${TEENSY_FLASH_LD}" TEENSY_LD_EXISTING)
endif()
if (NOT "${TEENSY_LD_EXISTING}" STREQUAL "${TEENSY_LD_NEW}")
    file(WRITE "${TEENSY_FLASH_LD}" "${TEENSY_LD_NEW}")
endif()

string(REPLACE "-T${TEENSY_ORIGINAL_LD}" "-T${TEENSY_FLASH_LD}" CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS}")
message(STATUS "[teensy_flash_code] Linking with ${TEENSY_FLASH_LD} (runs ${TEENSY_FLASH_LIBRARIES} from flash)")
