# ======================================================================
# AcConstants.fpp
# F Prime configuration constants
# ======================================================================

@ Number of rate group member output ports for ActiveRateGroup
constant ActiveRateGroupOutputPorts = 10

@ Number of rate group member output ports for PassiveRateGroup. rateGroup1 uses 10 (0-9) as of
@ roboclaw3Manager + stirrerManager; 12 leaves two free slots.
constant PassiveRateGroupOutputPorts = 12

@ Used to drive rate groups
constant RateGroupDriverRateGroupPorts = 3

@ Used for command and registration ports: one per component with commands (11 as of roboclaw3Manager +
@ stirrerManager: cmdDisp, eventLogger, systemResources, timeHandler, pumpManager, uvManager, pca9685Manager,
@ roboclaw1-3Manager, stirrerManager). 14 leaves three free.
constant CmdDispatcherComponentCommandPorts = 14

@ Used for uplink/sequencer buffer/response ports
constant CmdDispatcherSequencePorts = 2

@ Used for dispatching sequences to command sequencers
constant SeqDispatcherSequencerPorts = 2

@ Used for sizing the command splitter input arrays
constant CmdSplitterPorts = CmdDispatcherSequencePorts

@ Number of static memory allocations
constant StaticMemoryAllocations = 4

@ Used to ping active components
constant HealthPingPorts = 1

@ Used for broadcasting completed file downlinks
constant FileDownCompletePorts = 1

@ Used for number of Fw::Com type ports supported by Svc::ComQueue
constant ComQueueComPorts = 2

@ Used for number of Fw::Buffer type ports supported by Svc::ComQueue
constant ComQueueBufferPorts = 1

@ Used for maximum number of connected buffer repeater consumers
constant BufferRepeaterOutputPorts = 10

@ Size of port array for DpManager
constant DpManagerNumPorts = 5

@ Size of processing port array for DpWriter
constant DpWriterNumProcPorts = 5

@ The size of a file name string
constant FileNameStringSize = 200

@ The size of an assert text string
constant FwAssertTextSize = 256

@ The size of a file name in an AssertFatalAdapter event
@ Note: File names in assertion failures are also truncated by
@ the constants FW_ASSERT_TEXT_SIZE and FW_LOG_STRING_MAX_SIZE, set
@ in FpConfig.h.
constant AssertFatalAdapterEventFileSize = FileNameStringSize

# ----------------------------------------------------------------------
# Hub connections. Connections on all deployments should mirror these settings.
# ----------------------------------------------------------------------

constant GenericHubInputPorts = 10
constant GenericHubOutputPorts = 10
constant GenericHubInputBuffers = 10
constant GenericHubOutputBuffers = 10
