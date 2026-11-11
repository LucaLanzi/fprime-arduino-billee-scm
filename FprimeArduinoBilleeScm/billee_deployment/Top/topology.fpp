module billee_deployment {

  # ----------------------------------------------------------------------
  # Symbolic constants for port numbers
  # ----------------------------------------------------------------------

    enum Ports_RateGroups {
      rateGroup1
      rateGroup2
    }

  topology billee_deployment {

    # ----------------------------------------------------------------------
    # Subtopology imports
    # ----------------------------------------------------------------------


    import ComCcsds.Subtopology

    # ----------------------------------------------------------------------
    # Instances used in the topology
    # ----------------------------------------------------------------------

    instance bootReporter
    instance cmdDisp
    instance cmdSeq
    instance comDriver
    instance eventLogger
    instance fatalHandler
    instance fileManager
    instance fileUplink
    instance loadCellManager
    instance pca9685Manager
    instance pump1Gpio
    instance pump2Gpio
    instance pump3Gpio
    instance pump4Gpio
    instance r1m1LowerLimitGpio
    instance r1m1UpperLimitGpio
    instance r1m2LowerLimitGpio
    instance r1m2UpperLimitGpio
    instance r2m1LowerLimitGpio
    instance r2m1UpperLimitGpio
    instance r3m1LowerLimitGpio
    instance r3m1UpperLimitGpio
    instance roboclawManager
    instance relayManager
    instance stirrerGpio
    instance uvGpio
    instance rateDriver
    instance rateGroup1
    instance rateGroup2
    instance rateGroupDriver
    instance systemResources
    instance textLogger
    instance timeHandler
    instance tlmSend

    # ----------------------------------------------------------------------
    # Pattern graph specifiers
    # ----------------------------------------------------------------------

    command connections instance cmdDisp

    event connections instance eventLogger

    telemetry connections instance tlmSend

    text event connections instance textLogger

    time connections instance timeHandler

    # ----------------------------------------------------------------------
    # Direct graph specifiers
    # ----------------------------------------------------------------------

    connections RateGroups {
      # Block driver
      rateDriver.CycleOut -> rateGroupDriver.CycleIn

      # Rate group 1
      rateGroupDriver.CycleOut[Ports_RateGroups.rateGroup1] -> rateGroup1.CycleIn
      rateGroup1.RateGroupMemberOut[0] -> tlmSend.Run
      rateGroup1.RateGroupMemberOut[1] -> systemResources.run
      rateGroup1.RateGroupMemberOut[2] -> comDriver.schedIn
      rateGroup1.RateGroupMemberOut[3] -> relayManager.run
      rateGroup1.RateGroupMemberOut[4] -> loadCellManager.run
      rateGroup1.RateGroupMemberOut[7] -> pca9685Manager.run
      rateGroup1.RateGroupMemberOut[10] -> cmdSeq.schedIn # invoke the command sequencer
      rateGroup1.RateGroupMemberOut[11] -> bootReporter.run
      # fileManager does ListDirectory a few entries per tick, so the listing only progresses with this connected
      rateGroup1.RateGroupMemberOut[12] -> fileManager.schedIn

      # Rate group 2 (50 Hz)
      rateGroupDriver.CycleOut[Ports_RateGroups.rateGroup2] -> rateGroup2.CycleIn
      rateGroup2.RateGroupMemberOut[0] -> roboclawManager.run
    }

    connections FaultProtection {
      eventLogger.FatalAnnounce -> fatalHandler.FatalReceive
    }

    connections Sequencer {
      cmdSeq.comCmdOut -> cmdDisp.seqCmdBuff[1]
      cmdDisp.seqCmdStatus[1] -> cmdSeq.cmdResponseIn
    }

    connections FileUplink {
      # The router copies each uplinked file packet into a commsBufferManager buffer and hands it over;
      # fileUplink returns it when written so the router can free it (without the return, every file packet
      # would leak one buffer from the pool).
      ComCcsds.fprimeRouter.fileOut     -> fileUplink.bufferSendIn
      fileUplink.bufferSendOut          -> ComCcsds.fprimeRouter.fileBufferReturnIn
    }


    connections Communications {
      # Inputs to ComQueue (events, telemetry, file)
      eventLogger.PktSend -> ComCcsds.comQueue.comPacketQueueIn[ComCcsds.Ports_ComPacketQueue.EVENTS]
      tlmSend.PktSend     -> ComCcsds.comQueue.comPacketQueueIn[ComCcsds.Ports_ComPacketQueue.TELEMETRY]

      # ComDriver buffer allocations
      comDriver.allocate      -> ComCcsds.commsBufferManager.bufferGetCallee
      comDriver.deallocate    -> ComCcsds.commsBufferManager.bufferSendIn
      
      # ComDriver <-> ComStub (Uplink)
      comDriver.$recv                     -> ComCcsds.comStub.drvReceiveIn
      ComCcsds.comStub.drvReceiveReturnOut -> comDriver.recvReturnIn
      
      # ComStub <-> ComDriver (Downlink)
      ComCcsds.comStub.drvSendOut      -> comDriver.$send
      comDriver.ready         -> ComCcsds.comStub.drvConnected

      # Router <-> CmdDispatcher
      ComCcsds.fprimeRouter.commandOut  -> cmdDisp.seqCmdBuff
      cmdDisp.seqCmdStatus     -> ComCcsds.fprimeRouter.cmdResponseIn
    }

    connections billee_deployment {
      # relaySet index = billeeScm.RelayId value (Types/RelayTypes.fpp)
      relayManager.relaySet[0] -> pump1Gpio.gpioWrite    # PUMP1
      relayManager.relaySet[1] -> pump2Gpio.gpioWrite    # PUMP2
      relayManager.relaySet[2] -> pump3Gpio.gpioWrite    # PUMP3
      relayManager.relaySet[3] -> pump4Gpio.gpioWrite    # PUMP4
      relayManager.relaySet[4] -> uvGpio.gpioWrite       # UV_LIGHT
      relayManager.relaySet[5] -> stirrerGpio.gpioWrite  # STIRRER



      # Limit switches: limitSwGet[2 * RoboclawMotor + 0] = lower, [2 * RoboclawMotor + 1] = upper.
      # R2_M2 (the drill, ports 6/7) has none, so those ports stay unconnected.
      roboclawManager.limitSwGet[0] -> r1m1LowerLimitGpio.gpioRead
      roboclawManager.limitSwGet[1] -> r1m1UpperLimitGpio.gpioRead
      roboclawManager.limitSwGet[2] -> r1m2LowerLimitGpio.gpioRead
      roboclawManager.limitSwGet[3] -> r1m2UpperLimitGpio.gpioRead
      roboclawManager.limitSwGet[4] -> r2m1LowerLimitGpio.gpioRead
      roboclawManager.limitSwGet[5] -> r2m1UpperLimitGpio.gpioRead
      roboclawManager.limitSwGet[8] -> r3m1LowerLimitGpio.gpioRead
      roboclawManager.limitSwGet[9] -> r3m1UpperLimitGpio.gpioRead
    }

  }

}
