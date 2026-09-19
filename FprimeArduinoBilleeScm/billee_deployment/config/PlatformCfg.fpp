# =======================================================================
# PlatformCfg.fpp
# Override of lib/fprime/default/config/PlatformCfg.fpp
#
# Only FW_FILE_HANDLE_MAX_SIZE and FW_DIRECTORY_HANDLE_MAX_SIZE differ from
# the framework default, and it's not a RAM choice: Os::Arduino::ArduinoFile/
# ArduinoDirectory (the SD-card-backed Os::File/Os::Directory implementation
# fprime-arduino provides, compiled here regardless of this deployment's own
# "no filesystem" choice - F' compiles every registered Os implementation as
# its own library whether it's linked into the final executable or not) hold
# a real Arduino SD-library File object, which doesn't fit in the framework
# default's 16 bytes (confirmed directly: Os/Delegate.hpp's "Handle size not
# large enough" static_assert fires at the default size, on Teensy 4.1 same
# as any other Arduino board). Everything else here is copied unchanged from
# the framework original so nothing that depends on it goes missing
# (CONFIGURATION_OVERRIDES replaces the whole file, not just the constants
# that differ).
# =======================================================================

@ Maximum size of a handle for Os::Console
constant FW_CONSOLE_HANDLE_MAX_SIZE = 24

@ Maximum size of a handle for Os::Task
constant FW_TASK_HANDLE_MAX_SIZE = 40

@ Maximum size of a handle for Os::File
@ was 16 in the framework default - too small for Os::Arduino::ArduinoFile
constant FW_FILE_HANDLE_MAX_SIZE = 32

@ Maximum size of a handle for Os::Mutex
constant FW_MUTEX_HANDLE_MAX_SIZE = 72

@ Maximum size of a handle for Os::Queue
constant FW_QUEUE_HANDLE_MAX_SIZE = 368

@ Maximum size of a handle for Os::Directory
@ was 16 in the framework default - too small for Os::Arduino::ArduinoDirectory
constant FW_DIRECTORY_HANDLE_MAX_SIZE = 48

@ Maximum size of a handle for Os::FileSystem
constant FW_FILESYSTEM_HANDLE_MAX_SIZE = 16

@ Maximum size of a handle for Os::RawTime
constant FW_RAW_TIME_HANDLE_MAX_SIZE = 56

@ Maximum allowed serialization size for Os::RawTime objects
constant FW_RAW_TIME_SERIALIZATION_MAX_SIZE = 8

@ Maximum size of a handle for Os::ConditionVariable
constant FW_CONDITION_VARIABLE_HANDLE_MAX_SIZE = 56

@ Maximum size of a handle for Os::Cpu
constant FW_CPU_HANDLE_MAX_SIZE = 16

@ Maximum size of a handle for Os::Memory
constant FW_MEMORY_HANDLE_MAX_SIZE = 16

@ Alignment of handle storage
constant FW_HANDLE_ALIGNMENT = 8

@ Chunk size for working with files in the OSAL layer
constant FW_FILE_CHUNK_SIZE = 512
