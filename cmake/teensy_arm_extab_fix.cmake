####
# teensy_arm_extab_fix.cmake:
#
# Works around a bug in Teensyduino's imxrt1062_t41.ld (present upstream in
# PaulStoffregen/cores as of Teensyduino 1.59.0): the .ARM.exidx output section is placed in
# ITCM, but its input pattern only captures ".ARM.extab.text*" fragments (matching code built
# with -ffunction-sections). libgcc.a's pr-support.o is prebuilt without -ffunction-sections,
# so its plain ".ARM.extab" section falls through to FLASH instead - ~1.5GB away from ITCM,
# which overflows the +-1GB range of the R_ARM_PREL31 relocation linking exidx entries to their
# extab entries. Result: "relocation truncated to fit: R_ARM_PREL31 against `.ARM.extab'" at
# link time. Patch the installed linker script to also route bare ".ARM.extab" into ITCM.
####

if (NOT CMAKE_EXE_LINKER_FLAGS_INIT MATCHES "imxrt1062_t4[01]\\.ld")
    return()
endif()

string(REGEX MATCH "-T([^ ]+imxrt1062_t4[01]\\.ld)" _ "${CMAKE_EXE_LINKER_FLAGS_INIT}")
set(TEENSY_LD_SCRIPT "${CMAKE_MATCH_1}")

if (NOT TEENSY_LD_SCRIPT OR NOT EXISTS "${TEENSY_LD_SCRIPT}")
    message(WARNING "[teensy_arm_extab_fix] Could not locate Teensy linker script from CMAKE_EXE_LINKER_FLAGS_INIT; skipping ARM.extab patch. If the link fails with \"relocation truncated to fit: R_ARM_PREL31 against \`.ARM.extab'\", this is why.")
    return()
endif()

file(READ "${TEENSY_LD_SCRIPT}" TEENSY_LD_CONTENT)
set(FIXED_PATTERN ".ARM.exidx* .ARM.extab.text* .ARM.extab .gnu.linkonce.armexidx.*")
set(BUGGY_PATTERN ".ARM.exidx* .ARM.extab.text* .gnu.linkonce.armexidx.*")

if (TEENSY_LD_CONTENT MATCHES "\\.ARM\\.exidx\\* \\.ARM\\.extab\\.text\\* \\.ARM\\.extab \\.gnu\\.linkonce\\.armexidx\\.\\*")
    # Already patched (either by us previously, or fixed upstream).
    return()
elseif (TEENSY_LD_CONTENT MATCHES "\\.ARM\\.exidx\\* \\.ARM\\.extab\\.text\\* \\.gnu\\.linkonce\\.armexidx\\.\\*")
    string(REPLACE "${BUGGY_PATTERN}" "${FIXED_PATTERN}" TEENSY_LD_CONTENT_NEW "${TEENSY_LD_CONTENT}")
    file(WRITE "${TEENSY_LD_SCRIPT}" "${TEENSY_LD_CONTENT_NEW}")
    message(STATUS "[teensy_arm_extab_fix] Patched ${TEENSY_LD_SCRIPT} to fix ARM.exidx/ARM.extab relocation-truncated linker bug")
else()
    message(WARNING "[teensy_arm_extab_fix] ${TEENSY_LD_SCRIPT} does not match the expected .ARM.exidx pattern; cannot verify/apply the ARM.extab fix. If the link fails with \"relocation truncated to fit: R_ARM_PREL31 against \`.ARM.extab'\", patch it manually by adding \".ARM.extab\" to the .ARM.exidx section's input pattern.")
endif()
