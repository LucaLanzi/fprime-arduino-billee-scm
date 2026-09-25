module billee_deployment {

  # ----------------------------------------------------------------------
  # Defaults
  # ----------------------------------------------------------------------

  module Default {
    constant QUEUE_SIZE = 3
    # RoboclawManager queues more than the others: besides `run` and the commands it also puts its own
    # state-machine signals (tick, cmdRecv, success/fail) on this queue, and an overflow is an FW_ASSERT.
    constant ROBOCLAW_QUEUE_SIZE = 10
    # PCA9685Manager: `run` plus a burst of servo commands (e.g. a GDS sequence moving several servos back to
    # back) share this queue, and an overflow is an FW_ASSERT.
    constant PCA9685_QUEUE_SIZE = 10
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
  # Tasks are started in (fixed) alphabetical order: cmdDisp, eventLogger, pca9685Manager,
  # pumpManager, roboclaw1Manager, roboclaw2Manager, tlmSend, uvManager, so priorities below
  # MUST be non-increasing in that order. On the cooperative TaskRunner priority only orders the
  # round-robin, so equal priorities cost nothing.
  # ----------------------------------------------------------------------

  instance cmdDisp: Svc.CommandDispatcher base id 0x0100 \
    queue size Default.QUEUE_SIZE\
    stack size Default.STACK_SIZE \
    priority 101

  instance eventLogger: Svc.EventManager base id 0x0300 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 98

  instance tlmSend: Svc.TlmChan base id 0x0400 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 97

  # Starts between eventLogger (98) and pumpManager (97) ('c' < 'u'), so its priority must be 97 or 98.
  instance pca9685Manager: billeeScm.PCA9685Manager base id 0x5D00 \
    queue size Default.PCA9685_QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 97

  instance pumpManager: billeeScm.PumpManager base id 0x4A00 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 97

  instance uvManager: billeeScm.UvManager base id 0x5000 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 97

  instance roboclaw1Manager: billeeScm.RoboclawManager base id 0x5100 \
    queue size Default.ROBOCLAW_QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 97

  instance roboclaw2Manager: billeeScm.RoboclawManager base id 0x5900 \
    queue size Default.ROBOCLAW_QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 97



  # ----------------------------------------------------------------------
  # Queued component instances
  # ----------------------------------------------------------------------

  # ----------------------------------------------------------------------
  # Passive component instances
  # ----------------------------------------------------------------------

  instance rateGroup1: Svc.PassiveRateGroup base id 0x1000

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

  instance limitSw1Gpio: Arduino.GpioDriver base id 0x5200  @< roboclaw1Manager, Motor1

  instance limitSw2Gpio: Arduino.GpioDriver base id 0x5300  @< roboclaw1Manager, Motor2

  instance limitSw3Gpio: Arduino.GpioDriver base id 0x5B00  @< roboclaw2Manager, Motor1

  instance limitSw4Gpio: Arduino.GpioDriver base id 0x5C00  @< roboclaw2Manager, Motor2

}
