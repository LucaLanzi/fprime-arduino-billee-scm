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

    instance bootReporter
    instance cmdDisp
    instance cmdSeq
    instance comDriver
    instance eventLogger
    instance fatalHandler
    instance fileManager
    instance fileUplink
    instance drillAsmLowerLimitGpio
    instance drillAsmUpperLimitGpio
    instance drillTubeLowerLimitGpio
    instance drillTubeUpperLimitGpio
    instance pca9685Manager
    instance pump1Gpio
    instance pump2Gpio
    instance pump3Gpio
    instance pump4Gpio
    instance roboclaw1Manager
    instance roboclaw2Manager
    instance roboclaw3Manager
    instance soilLowerLimitGpio
    instance soilUpperLimitGpio
    instance relayManager
    instance stirrerGpio
    instance uvGpio
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
      rateGroup1.RateGroupMemberOut[3] -> relayManager.run
      rateGroup1.RateGroupMemberOut[5] -> roboclaw1Manager.run
      rateGroup1.RateGroupMemberOut[6] -> roboclaw2Manager.run
      rateGroup1.RateGroupMemberOut[7] -> pca9685Manager.run
      rateGroup1.RateGroupMemberOut[8] -> roboclaw3Manager.run
      rateGroup1.RateGroupMemberOut[10] -> cmdSeq.schedIn # invoke the command sequencer
      rateGroup1.RateGroupMemberOut[11] -> bootReporter.run
      # fileManager does ListDirectory a few entries per tick, so the listing only progresses with this connected
      rateGroup1.RateGroupMemberOut[12] -> fileManager.schedIn
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



      # Interim: RoboclawManager reads one switch per motor and blocks both directions while it is tripped,
      # so only each motor's lower switch is wired. The upper switches (soilUpperLimitGpio,
      # drillAsmUpperLimitGpio, drillTubeUpperLimitGpio) are opened but unread until a direction-aware
      # limit switch manager pairs them. Roboclaw 2 Motor2 (drill spin) and Roboclaw 3 have no switches,
      # so their limitSwGet ports stay unconnected.
      roboclaw1Manager.limitSwGet[0] -> soilLowerLimitGpio.gpioRead
      roboclaw1Manager.limitSwGet[1] -> drillAsmLowerLimitGpio.gpioRead
      roboclaw2Manager.limitSwGet[0] -> drillTubeLowerLimitGpio.gpioRead
    }

  }

}
