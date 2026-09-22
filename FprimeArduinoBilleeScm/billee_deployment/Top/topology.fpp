module billee_deployment {

  # ----------------------------------------------------------------------
  # Symbolic constants for port numbers
  # ----------------------------------------------------------------------

    enum Ports_RateGroups {
      rateGroup1
    }

  topology billee_deployment {

    # ----------------------------------------------------------------------
    # Subtopology imports
    # ----------------------------------------------------------------------


    import ComCcsds.Subtopology

    # ----------------------------------------------------------------------
    # Instances used in the topology
    # ----------------------------------------------------------------------

    instance cmdDisp
    instance comDriver
    instance eventLogger
    instance fatalHandler
    instance pump1Gpio
    instance pump2Gpio
    instance pump3Gpio
    instance pump4Gpio
    instance pumpManager
    instance uvGpio 
    instance uvManager 
    instance rateDriver
    instance rateGroup1
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
      rateGroup1.RateGroupMemberOut[3] -> pumpManager.run
      rateGroup1.RateGroupMemberOut[4] -> uvManager.run
    }

    connections FaultProtection {
      eventLogger.FatalAnnounce -> fatalHandler.FatalReceive
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
      pumpManager.pump1Set -> pump1Gpio.gpioWrite
      pumpManager.pump2Set -> pump2Gpio.gpioWrite
      pumpManager.pump3Set -> pump3Gpio.gpioWrite
      pumpManager.pump4Set -> pump4Gpio.gpioWrite

      uvManager.uvSet -> uvGpio.gpioWrite
    }

  }

}
