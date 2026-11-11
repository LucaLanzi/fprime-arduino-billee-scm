module ComCcsdsConfig {
    #Base ID for the ComCcsds Subtopology, all components are offsets from this base ID
    constant BASE_ID = 0x02000000

    # Was 3/3. ComQueue's comPacketQueueIn (events, telemetry) and run ports DROP when its queue is full, but
    # comStatusIn (one per frame sent) ASSERTS. With depth 3 any burst filled the queue with packets first and
    # the next frame's status asserted (ComQueueComponentAc.cpp: FW_ASSERT(qStatus == OP_OK)): a 3-event boot
    # report, a failed fileManager command, or anything blocking the cooperative scheduler for a while (SD.begin
    # with no card) rebooted the board into the bootloader. Each slot is ~0.5 KB on the RAM2 heap.
    module QueueSizes {
        constant comQueue    = 20
        constant aggregator  = 10
    }

    module StackSizes {
        constant comQueue   = 64 * 1024
        constant aggregator = 64 * 1024
    }

    module Priorities {
        constant comQueue   = 101
    }

    # The fprime-arduino-deployment-cookiecutter template that generated this
    # file drops the "aggregator" entries above entirely, even though
    # Svc/Subtopologies/ComCcsds/ComCcsds.fpp (v4.1.1) requires
    # QueueSizes.aggregator/StackSizes.aggregator unconditionally
    # (fpp-to-cpp: "symbol aggregator is not defined") - a standing
    # cookiecutter bug independent of F' version or target board. At this F'
    # version the aggregator instance takes no `priority` or `cpu` clause at
    # all (confirmed directly against ComCcsds.fpp), so no CpuAffinities
    # module or aggregator priority is needed here.

    # Queue configuration constants
    module QueueDepths {
        constant events      = 10
        constant tlm         = 25
        constant file        = 1
    }

    module QueuePriorities {
        constant events      = 0
        constant tlm         = 2
        constant file        = 1
    }

    # Buffer management constants
    module BuffMgr {
        constant frameAccumulatorSize  = 2048
        # Was 140 in the cookiecutter's generated file - far smaller than
        # Svc/Subtopologies/ComCcsds/ComCcsdsConfig/ComCcsdsConfig.fpp's own
        # framework default of 2048. SpacePacketFramer::dataIn_handler
        # allocates exactly (SpacePacketHeader::SERIALIZED_SIZE +
        # data.getSize()) bytes from this bin for every outgoing frame; at
        # 140 bytes the very first non-trivial downlink (the boot-time
        # cmdDispatcher opcode-registration event burst) already exceeds it,
        # so the second frameSerializer.serializeFrom() call overruns the
        # buffer and hits FW_ASSERT(status == Fw::FW_SERIALIZE_OK, status)
        # with status=2 (FW_SERIALIZE_NO_ROOM_LEFT) - confirmed by capturing
        # the board's own assert output directly over its serial port. This
        # crashed and rebooted the board in a loop immediately after boot,
        # which is what was actually preventing fprime-gds from ever holding
        # a stable connection (not a framing config issue on the GDS side).
        # Restored to match F' core's own default - trivial RAM cost on this
        # board (~5.7KB more across 3 buffers) compared to crashing on the
        # first real frame.
        constant commsBuffSize         = 2048
        constant commsFileBuffSize     = 140
        # Was 3. The manager hands out the first free buffer that fits, scanning bins in order, and bin 0 is
        # this 2048-byte one, so in practice every serial read, uplink frame, router file-packet copy and
        # downlink frame takes one of these. 3 ran out as soon as a file uplink overlapped downlink.
        # Allocated from the RAM2 heap, not RAM1.
        constant commsBuffCount        = 8
        constant commsFileBuffCount    = 3
        constant commsBuffMgrId        = 200
    }
}
