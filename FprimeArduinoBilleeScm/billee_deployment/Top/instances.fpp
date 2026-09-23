module billee_deployment {

  # ----------------------------------------------------------------------
  # Defaults
  # ----------------------------------------------------------------------

  module Default {
    constant QUEUE_SIZE = 3
    constant STACK_SIZE = 64 * 1024
  }

  # ----------------------------------------------------------------------
  # Active component instances
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

  instance pumpManager: billeeScm.PumpManager base id 0x4A00 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 96

  instance uvManager: billeeScm.UvManager base id 0x5000 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 99

  instance roboclaw1Manager: billeeScm.RoboclawManager base id 0x5100 \
    queue size Default.QUEUE_SIZE \
    stack size Default.STACK_SIZE \
    priority 97

  instance roboclaw2Manager: billeeScm.RoboclawManager base id 0x5900 \
    queue size Default.QUEUE_SIZE \
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
