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
    instance cmdSeq
    instance comDriver
    instance eventLogger
    instance fatalHandler
    instance drillAsmLowerLimitGpio
    instance drillAsmUpperLimitGpio
    instance drillTubeLowerLimitGpio
    instance drillTubeUpperLimitGpio
    instance pca9685Manager
    instance pump1Gpio
    instance pump2Gpio
    instance pump3Gpio
    instance pump4Gpio
    instance pumpManager
    instance roboclaw1Manager
    instance roboclaw2Manager
    instance roboclaw3Manager
    instance soilLowerLimitGpio
    instance soilUpperLimitGpio
    instance stirrer1Gpio
    instance stirrer2Gpio
    instance stirrerManager
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
      rateGroup1.RateGroupMemberOut[5] -> roboclaw1Manager.run
      rateGroup1.RateGroupMemberOut[6] -> roboclaw2Manager.run
      rateGroup1.RateGroupMemberOut[7] -> pca9685Manager.run
      rateGroup1.RateGroupMemberOut[8] -> roboclaw3Manager.run
      rateGroup1.RateGroupMemberOut[9] -> stirrerManager.run
      rateGroup1.RateGroupMemberOut[10] -> cmdSeq.schedIn # invoke the command sequencer
    }

    connections FaultProtection {
      eventLogger.FatalAnnounce -> fatalHandler.FatalReceive
    }

    connections Sequencer {
      cmdSeq.comCmdOut -> cmdDisp.seqCmdBuff[1]
      cmdDisp.seqCmdStatus[1] -> cmdSeq.cmdResponseIn
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

      stirrerManager.stirrer1Set -> stirrer1Gpio.gpioWrite
      stirrerManager.stirrer2Set -> stirrer2Gpio.gpioWrite

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
