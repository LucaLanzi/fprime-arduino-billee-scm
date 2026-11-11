// ======================================================================
// \title  SciencePins.hpp
// \brief  Teensy 4.1 pinout of the Science Control Module
//
// Single source of truth for every pin billee_deploymentTopology.cpp opens. Matches the "Science Hardware
// Architecture 2027" block diagram (net names T_GPIO_xx); change a pin here and in the diagram together.
// ======================================================================
#ifndef BILLEE_DEPLOYMENT_SCIENCEPINS_HPP
#define BILLEE_DEPLOYMENT_SCIENCEPINS_HPP

#include <Fw/FPrimeBasicTypes.hpp>

namespace billee_deployment {
namespace SciencePins {

// Logic-level relays (normally open, HIGH = load powered)
constexpr U8 UV_LIGHT = 40;   // T_GPIO_40, switches +22.2V to the UV light
constexpr U8 PUMP1 = 39;      // T_GPIO_39, +12V
constexpr U8 PUMP2 = 38;      // T_GPIO_38, +12V
constexpr U8 PUMP3 = 37;      // T_GPIO_37, +12V
constexpr U8 PUMP4 = 36;      // T_GPIO_36, +12V
constexpr U8 STIRRER = 34;    // T_GPIO_34, +12V magnetic stirrer MS1

// Limit switches (close to GND when tripped, read with INPUT_PULLUP), named after the Roboclaw motor they guard
// (billeeScm::RoboclawMotor). FORWARD moves a motor toward its UPPER switch.
constexpr U8 R1_M1_LOWER_LIMIT = 23;  // T_GPIO_23, soil drill actuator (Roboclaw 1, M1)
constexpr U8 R1_M1_UPPER_LIMIT = 22;  // T_GPIO_22
constexpr U8 R1_M2_LOWER_LIMIT = 21;  // T_GPIO_21, transfer tube actuator / drill up-down (Roboclaw 1, M2)
constexpr U8 R1_M2_UPPER_LIMIT = 15;  // T_GPIO_15
constexpr U8 R2_M1_LOWER_LIMIT = 14;  // T_GPIO_14, transfer tube lead screw (Roboclaw 2, M1)
constexpr U8 R2_M1_UPPER_LIMIT = 41;  // T_GPIO_41, drill tube to ground contact
constexpr U8 R3_M1_LOWER_LIMIT = 33;  // T_GPIO_33, sample rotation linear actuator (Roboclaw 3, M1)
constexpr U8 R3_M1_UPPER_LIMIT = 32;  // T_GPIO_32
// Roboclaw 2 M2 (drill) has no limit switches.

// PCA9685 on Wire: SDA 18, SCL 19 (fixed by the Wire peripheral, listed for reference)
constexpr U8 I2C_SDA = 18;
constexpr U8 I2C_SCL = 19;

// Roboclaw packet serial (Teensy TX -> Roboclaw S1, Roboclaw S2 -> Teensy RX), fixed by the UART peripheral:
//   Roboclaw 1 (0x80) Serial1: RX 0,  TX 1
//   Roboclaw 2 (0x81) Serial2: RX 7,  TX 8
//   Roboclaw 3 (0x82) Serial4: RX 16, TX 17   (linear actuator)
// Serial3 (14/15), Serial5 (21/20) and Serial8 (34/35) are unusable: their pins are limit switches / relays above.

// Reserved for the three HX711 load-cell ADCs (no driver yet). HX711 is a clocked 2-wire protocol, not I2C.
constexpr U8 HX711_1_DAT = 2;
constexpr U8 HX711_1_CLK = 3;
constexpr U8 HX711_2_DAT = 4;
constexpr U8 HX711_2_CLK = 5;
constexpr U8 HX711_3_DAT = 9;
constexpr U8 HX711_3_CLK = 10;

}  // namespace SciencePins
}  // namespace billee_deployment

#endif
