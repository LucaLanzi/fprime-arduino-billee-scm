# =======================================================================
# FpConstants.fpp
# Override of lib/fprime/default/config/FpConstants.fpp
#
# Only FW_TLM_BUFFER_MAX_SIZE differs from the framework default, and it's a
# RAM1 choice. TlmChan (tlmSend) keeps two copies of every hash bucket
# (TLMCHAN_HASH_BUCKETS in TlmChanImplCfg.hpp), and each bucket holds an
# Fw::TlmBuffer sized FW_TLM_BUFFER_MAX_SIZE. The framework default derives it
# from FW_COM_BUFFER_MAX_SIZE (512 - 4 - 2 = 506 bytes), which made tlmSend
# ~83 KB of RAM1 with 72 buckets, while the largest channel in this deployment
# is 96 bytes (pca9685Manager.servoStates) and every other one is <= 8.
# 128 keeps all 72 buckets and frees ~60 KB of RAM1 for the stack.
#
# MUST be >= the largest serialized telemetry value in the deployment:
# writing a bigger one is an FW_ASSERT on the board, not a build error. Check
# with the "largest channel" script in README.md ("Fixed-size tables") after
# adding a channel, and also keep it >= FW_TLM_STRING_MAX_SIZE (a static_assert
# in Fw/FPrimeBasicTypes.hpp catches that one at build time).
#
# Everything else is copied unchanged from the framework original
# (CONFIGURATION_OVERRIDES replaces the whole file, not just the constants
# that differ).
# =======================================================================

# ---------------------------------------------------------------------
# Buffer sizes
# ---------------------------------------------------------------------

@ When dumping the contents of the registry, this specifies the size of the buffer used to store object names.
@ Should be >= FW_OBJ_NAME_BUFFER_SIZE.
constant FW_OBJ_SIMPLE_REG_BUFF_SIZE = 255

@ Specifies the size of the string holding the queue name for queues
constant FW_QUEUE_NAME_BUFFER_SIZE = 80

@ Specifies the size of the string holding the task name for active components and tasks
constant FW_TASK_NAME_BUFFER_SIZE = 80

@ Specifies the size of the buffer that contains a communications packet
constant FW_COM_BUFFER_MAX_SIZE = 512

@ Specifies the size of the buffer attached to state machine signals
constant FW_SM_SIGNAL_BUFFER_MAX_SIZE = 128

@ Specifies the size of the buffer that contains the serialized command arguments
constant FW_CMD_ARG_BUFFER_MAX_SIZE = FW_COM_BUFFER_MAX_SIZE - SIZE_OF_FwOpcodeType - SIZE_OF_FwPacketDescriptorType

@ Specifies the maximum size of a string in a command argument
constant FW_CMD_STRING_MAX_SIZE = 40

@ Specifies the size of the buffer that contains the serialized log arguments
constant FW_LOG_BUFFER_MAX_SIZE = FW_COM_BUFFER_MAX_SIZE - SIZE_OF_FwEventIdType - SIZE_OF_FwPacketDescriptorType

@ Specifies the maximum size of a string in a log event
@ Note: This constant truncates file names in assertion failure event reports
constant FW_LOG_STRING_MAX_SIZE = 200

@ Specifies the size of the buffer that contains the serialized telemetry value
@ was FW_COM_BUFFER_MAX_SIZE - SIZE_OF_FwChanIdType - SIZE_OF_FwPacketDescriptorType (506) in the framework default
@ MUST be >= the largest serialized telemetry value (see header comment)
constant FW_TLM_BUFFER_MAX_SIZE = 128

@ Specifies the size of the buffer that contains the serialized telemetry value
constant FW_STATEMENT_ARG_BUFFER_MAX_SIZE = FW_CMD_ARG_BUFFER_MAX_SIZE

@ Specifies the maximum size of a string in a telemetry channel
constant FW_TLM_STRING_MAX_SIZE = 40

@ Specifies the size of the buffer that contains the serialized parameter value
constant FW_PARAM_BUFFER_MAX_SIZE = FW_COM_BUFFER_MAX_SIZE - SIZE_OF_FwPrmIdType - SIZE_OF_FwPacketDescriptorType

@ Specifies the maximum size of a string in a parameter
constant FW_PARAM_STRING_MAX_SIZE = 40

@ Specifies the maximum size of a file downlink chunk
constant FW_FILE_BUFFER_MAX_SIZE = FW_COM_BUFFER_MAX_SIZE

@ Specifies the maximum size of a string in an interface call
constant FW_INTERNAL_INTERFACE_STRING_MAX_SIZE = 256

@ Defines the size of the text log string buffer. Should be large enough for format string and arguments
constant FW_LOG_TEXT_BUFFER_SIZE = 256

@ Configuration for Fw::String
@ Note: FPrimeBasicTypes.hpp needs to be updated to sync enum
constant FW_FIXED_LENGTH_STRING_SIZE = 256

# ---------------------------------------------------------------------
# Other constants
# ---------------------------------------------------------------------

@ For the simple object registry provided with the framework, this specifies how many objects the registry will store.
constant FW_OBJ_SIMPLE_REG_ENTRIES = 500

@ For the simple queue registry provided with the framework, this specifies how many queues the registry will store.
constant FW_QUEUE_SIMPLE_QUEUE_ENTRIES = 100

@ Maximum number of cascading FW_ASSERT check failures before forcing a system assert
constant FW_ASSERT_COUNT_MAX = 10

@ Don't care value for time contexts in sequences
constant FW_CONTEXT_DONT_CARE = 0xFF

@ Value encoded during serialization for boolean true
dictionary constant FW_SERIALIZE_TRUE_VALUE = 0xFF

@ Value encoded during serialization for boolean false
dictionary constant FW_SERIALIZE_FALSE_VALUE = 0x00
