module billee_deployment {

  # ----------------------------------------------------------------------
  # Defaults
  # ----------------------------------------------------------------------

  module Default {
    constant QUEUE_SIZE = 5
    # RoboclawManager: commands for five motors plus a 50 Hz run port (which drops when full).
    constant ROBOCLAW_QUEUE_SIZE = 10
    # PCA9685Manager: `run` plus a burst of servo commands (e.g. a GDS sequence moving several servos back to
    # back) share this queue, and an overflow is an FW_ASSERT.
    constant PCA9685_QUEUE_SIZE = 10
    # Command/event path (cmdDisp, cmdSeq, eventLogger): a running sequence, GDS commands and event bursts
    # (e.g. fileManager.ListDirectory emits one event per file) all pass through these queues.
    constant CORE_QUEUE_SIZE = 10
    # Framework components whose rate-group input ASSERTS when their queue is full (tlmSend.Run, cmdSeq.schedIn,
    # fileManager.schedIn). The TaskRunner is cooperative: while any handler blocks, the rate-group interrupt keeps
    # queuing ticks, so the queue must hold every tick of the longest legitimate block. The longest is SD.begin()
    # with no card (bootReporter.SD_MOUNT): SdFat's 2 s init timeout. 40 = 4 s at 10 Hz. (Our own components
    # declare their rate-group port `drop` instead.) RAM2 heap: ~20 bytes per slot for tlmSend, ~0.5 KB for the
    # two that queue commands.
    constant SCHED_QUEUE_SIZE = 40
    # fileUplink: one message per received file packet; holds packets until written to the SD card.
    constant FILE_UPLINK_QUEUE_SIZE = 10
    constant STACK_SIZE = 64 * 1024
  }

  # ----------------------------------------------------------------------
  # Active component instances
  #
  # PRIORITY ORDERING (do not change without reading this): Os::Baremetal::TaskRunner::addTask()
  # (lib/fprime-baremetal) appends each task at m_task_table[m_index] AND insertion-sorts it in,
  # so if a task is started with a HIGHER priority than one started before it, the append
  # overwrites a real task instead of the trailing duplicate and the lowest-priority task drops
  # out of the table. It is then never dispatched, its (depth 3) queue fills after three
  # rate-group ticks and Os::Queue::FULL trips an FW_ASSERT: a silent hang ~300 ms after boot.
  # Tasks are started in (fixed) alphabetical order: cmdDisp, cmdSeq, eventLogger, fileManager,
  # fileUplink, loadCellManager, pca9685Manager, relayManager, roboclawManager, stepperManager, tlmSend, so
  # priorities below
  # MUST be non-increasing in that order. On the cooperative TaskRunner priority only orders the
  # round-robin, so equal priorities cost nothing.
  # ----------------------------------------------------------------------

  instance cmdDisp: Svc.CommandDispatcher base id 0x0100 \
    queue size Default.CORE_QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 101

  instance cmdSeq: Svc.CmdSequencer base id 0x0200 \
    queue size Default.SCHED_QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 100

  instance eventLogger: Svc.EventManager base id 0x0300 \
    queue size Default.CORE_QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 98

  @ SD-card file operations for sequences: CreateDirectory, RemoveFile, ListDirectory, FileSize, ...
  @ Starts between eventLogger (98) and pca9685Manager (97), so its priority must be 97 or 98.
  instance fileManager: Svc.FileManager base id 0x0500 \
    queue size Default.SCHED_QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 98

  @ Receives files (e.g. sequence .bin files) from the GDS Uplink/Sequence tabs and writes them to the SD card.
  @ Starts between fileManager (98) and pca9685Manager (97), so its priority must be 97 or 98.
  instance fileUplink: Svc.FileUplink base id 0x0600 \
    queue size Default.FILE_UPLINK_QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 98

  @ Sample Cache carousel stepper (step / direction / motor-free driver on pins 2/3/4)
  instance stepperManager: billeeScm.StepperManager base id 0x6300 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 97

  instance tlmSend: Svc.TlmChan base id 0x0400 \
    queue size Default.SCHED_QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 97

  @ HX711 load-cell ADCs: Sample Cache weight sensors CELL1/CELL2 (pins in SciencePins.hpp)
  instance loadCellManager: billeeScm.LoadCellManager base id 0x6200 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 97

  @ PCA9685 servo board: servos S1-S16
  instance pca9685Manager: billeeScm.PCA9685Manager base id 0x5D00 \
    queue size Default.PCA9685_QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 97

  @ Logic-level relays: pumps 1-4, UV light, magnetic stirrer (relaySet[RelayId] -> the GPIOs below)
  instance relayManager: billeeScm.RelayManager base id 0x4A00 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 97

  @ All three Roboclaw boards (R1 Serial1, R2 Serial2, R3 Serial4) and their five motors, with limit switches.
  @ Ticked at 50 Hz by rateGroup2.
  instance roboclawManager: billeeScm.RoboclawManager base id 0x5100 \
    queue size Default.ROBOCLAW_QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 97

  # ----------------------------------------------------------------------
  # Queued component instances
  # ----------------------------------------------------------------------

  # ----------------------------------------------------------------------
  # Passive component instances
  # ----------------------------------------------------------------------

  @ 10 Hz: telemetry, comms, managers, sequencer
  instance rateGroup1: Svc.PassiveRateGroup base id 0x1000

  @ 50 Hz: roboclawManager (limit switches are checked every tick, so a motor stops within 20 ms of its switch)
  instance rateGroup2: Svc.PassiveRateGroup base id 0x1100

  @ Reports the previous boot's FW_ASSERT location / hard fault and the SD card mount result (see Main.cpp)
  instance bootReporter: billeeScm.BootReporter base id 0x0700

  @ Communications driver. May be swapped with other com drivers like Arduino.StreamDriver, Arduino.TcpServer, or Arduino.TcpClient.
  instance comDriver: Arduino.StreamDriver base id 0x4000

  instance fatalHandler: Baremetal.FatalHandler base id 0x4300

  instance timeHandler: Arduino.ArduinoTime base id 0x4400

  instance rateGroupDriver: Svc.RateGroupDriver base id 0x4500

  instance textLogger: Svc.PassiveTextLogger base id 0x4600

  instance systemResources: Svc.SystemResources base id 0x4800

  instance rateDriver: Arduino.HardwareRateDriver base id 0x4900

  instance pump1Gpio: Arduino.GpioDriver base id 0x4B00

  instance pump2Gpio: Arduino.GpioDriver base id 0x4C00

  instance pump3Gpio: Arduino.GpioDriver base id 0x4D00

  instance pump4Gpio: Arduino.GpioDriver base id 0x4E00

  instance uvGpio: Arduino.GpioDriver base id 0x5A00

  instance stirrerGpio: Arduino.GpioDriver base id 0x6000

  # Limit switches, one pair per Roboclaw motor (R2_M2, the drill, has none). Pins in SciencePins.hpp.
  instance r1m1LowerLimitGpio: Arduino.GpioDriver base id 0x5200  @< R1_M1 soil drill actuator, lower
  instance r1m1UpperLimitGpio: Arduino.GpioDriver base id 0x5300  @< R1_M1 soil drill actuator, upper
  instance r1m2LowerLimitGpio: Arduino.GpioDriver base id 0x5B00  @< R1_M2 transfer tube actuator, lower
  instance r1m2UpperLimitGpio: Arduino.GpioDriver base id 0x5C00  @< R1_M2 transfer tube actuator, upper
  instance r2m1LowerLimitGpio: Arduino.GpioDriver base id 0x5400  @< R2_M1 transfer tube lead screw, lower
  instance r2m1UpperLimitGpio: Arduino.GpioDriver base id 0x5500  @< R2_M1 drill tube to ground contact, upper
  instance r3m1LowerLimitGpio: Arduino.GpioDriver base id 0x5600  @< R3_M1 sample rotation linear actuator, lower
  instance r3m1UpperLimitGpio: Arduino.GpioDriver base id 0x5700  @< R3_M1 sample rotation linear actuator, upper

}
