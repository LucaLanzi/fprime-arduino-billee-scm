# Teensy 4.1 pin table: BILLEE Science Control Module

Every Teensy 4.1 header pin, what this firmware uses it for, and what else the pin can do. The firmware's source of
truth is [`SciencePins.hpp`](FprimeArduinoBilleeScm/billee_deployment/Top/SciencePins.hpp); the hardware's is the
Science Hardware Architecture 2027 block diagram (net names `T_GPIO_xx`). Change a pin in both, and in this table.

All Teensy 4.1 pins are **3.3 V logic and not 5 V tolerant**.

## Pins 0-41

| Pin | Used for | Connects to | Mode | Other functions (unused here) |
|---|---|---|---|---|
| 0 | Serial1 RX | Roboclaw 1 S2 (its TX) | UART | PWM, SPI1 CS |
| 1 | Serial1 TX | Roboclaw 1 S1 (its RX) | UART | PWM, SPI1 MISO |
| 2 | Carousel stepper PU- (step) | T_GPIO_2 | Open-drain out, LOW = on | PWM |
| 3 | Carousel stepper DR- (direction) | T_GPIO_3 | Open-drain out, LOW = on | PWM |
| 4 | Carousel stepper MF- (motor free) | T_GPIO_4 | Open-drain out, LOW = on | PWM |
| 5 | Spare, reserved for the stepper (e.g. alarm/home input) | T_GPIO_5 | - | PWM |
| 6 | Free | | | PWM |
| 7 | Serial2 RX | Roboclaw 2 S2 (its TX) | UART | PWM |
| 8 | Serial2 TX | Roboclaw 2 S1 (its RX) | UART | PWM |
| 9 | Free | | | PWM |
| 10 | Free | | | PWM, SPI CS |
| 11 | Free | | | PWM, SPI MOSI |
| 12 | Free | | | PWM, SPI MISO |
| 13 | Free (on-board orange LED) | | | PWM, SPI SCK |
| 14 | R2_M1 lower limit switch (transfer tube lead screw) | T_GPIO_14 | Input, pull-up, LOW = tripped | A0, Serial3 TX, PWM |
| 15 | R1_M2 upper limit switch (transfer tube actuator) | T_GPIO_15 | Input, pull-up, LOW = tripped | A1, Serial3 RX, PWM |
| 16 | Serial4 RX | Roboclaw 3 S2 (its TX) | UART | A2, Wire1 SCL |
| 17 | Serial4 TX | Roboclaw 3 S1 (its RX) | UART | A3, Wire1 SDA |
| 18 | I2C SDA (Wire, 100 kHz) | PCA9685 SDA | I2C | A4, PWM |
| 19 | I2C SCL (Wire, 100 kHz) | PCA9685 SCL | I2C | A5, PWM |
| 20 | Free | | | A6, Serial5 TX |
| 21 | R1_M2 lower limit switch (transfer tube actuator) | T_GPIO_21 | Input, pull-up, LOW = tripped | A7, Serial5 RX |
| 22 | R1_M1 upper limit switch (soil drill actuator) | T_GPIO_22 | Input, pull-up, LOW = tripped | A8, PWM |
| 23 | R1_M1 lower limit switch (soil drill actuator) | T_GPIO_23 | Input, pull-up, LOW = tripped | A9, PWM |
| 24 | HX711 load cell 1 DAT | Dat/CLK bus 1 | Input, pull-up | A10, Serial6 TX, Wire2 SCL, PWM |
| 25 | HX711 load cell 1 CLK | Dat/CLK bus 1 | Output | A11, Serial6 RX, Wire2 SDA, PWM |
| 26 | HX711 load cell 2 DAT | Dat/CLK bus 2 | Input, pull-up | A12, SPI1 MOSI |
| 27 | HX711 load cell 2 CLK | Dat/CLK bus 2 | Output | A13, SPI1 SCK |
| 28 | Free | | | Serial7 RX, PWM |
| 29 | Free | | | Serial7 TX, PWM |
| 30 | Free | | | |
| 31 | Free | | | |
| 32 | R3_M1 upper limit switch (sample rotation linear actuator) | T_GPIO_32 | Input, pull-up, LOW = tripped | |
| 33 | R3_M1 lower limit switch (sample rotation linear actuator) | T_GPIO_33 | Input, pull-up, LOW = tripped | PWM |
| 34 | Magnetic stirrer relay (MS1, +12 V) | T_GPIO_34 | Output, HIGH = on | Serial8 RX |
| 35 | Free | | | Serial8 TX |
| 36 | Pump 4 relay (+12 V) | T_GPIO_36 | Output, HIGH = on | PWM |
| 37 | Pump 3 relay (+12 V) | T_GPIO_37 | Output, HIGH = on | PWM |
| 38 | Pump 2 relay (+12 V) | T_GPIO_38 | Output, HIGH = on | A14, SPI1 CS |
| 39 | Pump 1 relay (+12 V) | T_GPIO_39 | Output, HIGH = on | A15, SPI1 MISO |
| 40 | UV light relay (+22.2 V) | T_GPIO_40 | Output, HIGH = on | A16 |
| 41 | R2_M1 upper limit switch (drill tube to ground contact) | T_GPIO_41 | Input, pull-up, LOW = tripped | A17 |

Roboclaw R2_M2 (the drill) has no limit switches. Roboclaw addresses: R1 0x80, R2 0x81, R3 0x82, all at 38400 baud.

## Free pins

6, 9, 10, 11, 12, 13 (LED), 20, 28, 29, 30, 31, 35, plus 5 (reserved for the stepper).

- **SPI** (10/11/12/13) is completely free.
- **Serial7** (28 RX / 29 TX) is the only spare UART.
- **PWM** is available on 5, 6, 9, 10-13, 28, 29.
- **Analog inputs** free: 20 (A6) only. Every other analog-capable pin is in use.

## Peripherals lost to pin choices

| Peripheral | Pins | Why unavailable |
|---|---|---|
| Serial3 | 14, 15 | Limit switches |
| Serial5 | 20, 21 | 21 is a limit switch |
| Serial6, Wire2 | 24, 25 | HX711 load cell 1 |
| Serial8 | 34, 35 | 34 is the stirrer relay |
| Wire1 | 16, 17 | Serial4 (Roboclaw 3) |
| SPI1 | 26, 27, 38, 39 | HX711 load cell 2, pump relays |

## Power and other header pins

| Pin | Notes |
|---|---|
| VIN | 3.6-5.5 V input (connected to VUSB unless the pad between them is cut) |
| VUSB | 5 V from the USB port |
| 3.3V (several) | 3.3 V output, 250 mA max in total. Feeds the PCA9685 logic VCC and the two HX711 boards. |
| GND (several) | Common ground: tie it to the Roboclaws', the PCA9685's, the HX711s' and the stepper driver's grounds. |
| VBAT | Real-time clock backup (coin cell). Unused. |
| Program | Shorting it to GND starts the bootloader (what `make flash` needs if the board is hung). |
| On/Off | Not used. |

## Built in, not on the headers

| What | Pins / pads | Use here |
|---|---|---|
| microSD socket | 42-47 (SDIO) | Sequence files. Mounted at boot as `BUILTIN_SDCARD` (exFAT). |
| USB device port | micro-B connector | GDS link to the Jetson (`/dev/ttyBILLEE_SCM`, CCSDS over USB serial). |
| USB host port, Ethernet pads, bottom QSPI pads (48-54) | | Unused. |

## Wiring conventions

- **Limit switches** close to **GND** when tripped. The firmware enables the Teensy's internal pull-up, so an open
  switch reads HIGH. FORWARD moves a Roboclaw motor toward its **upper** switch.
- **Relays** (logic-level relay boards): pin HIGH = relay energized = load on. Every relay pin is driven LOW at boot.
- **Stepper driver** inputs are optocoupled with XCOM to +5 V. The pins are open-drain: LOW turns an input on,
  high-impedance turns it off. Do not drive them push-pull HIGH: 3.3 V against a 5 V XCOM can leave the optocoupler
  partly on.
- **HX711** boards are powered from 3.3 V. CLK must idle LOW (held HIGH for more than 60 us powers the HX711 down).
- **PCA9685** logic VCC from 3.3 V; servo power on its separate V+ rail with grounds tied. The OE pin is not wired.
- **Roboclaws**: Teensy TX goes to the Roboclaw's S1, the Roboclaw's S2 goes to Teensy RX, grounds tied.

## Physical layout (top view, USB connector at the top)

Check against the pinout card that ships with the Teensy before soldering.

| Left edge (top to bottom) | Right edge (top to bottom) |
|---|---|
| GND | VIN |
| 0 | GND |
| 1 | 3.3V |
| 2 | 23 |
| 3 | 22 |
| 4 | 21 |
| 5 | 20 |
| 6 | 19 |
| 7 | 18 |
| 8 | 17 |
| 9 | 16 |
| 10 | 15 |
| 11 | 14 |
| 12 | 13 |
| 3.3V | GND |
| 24 | 41 |
| 25 | 40 |
| 26 | 39 |
| 27 | 38 |
| 28 | 37 |
| 29 | 36 |
| 30 | 35 |
| 31 | 34 |
| 32 | 33 |
