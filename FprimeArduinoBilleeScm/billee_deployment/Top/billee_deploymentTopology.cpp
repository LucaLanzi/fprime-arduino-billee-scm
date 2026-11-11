// ======================================================================
// \title  billee_deploymentTopology.cpp
// \brief cpp file containing the topology instantiation code
//
// ======================================================================
// Provides access to autocoded functions
#include <billee_deployment/Top/billee_deploymentTopologyAc.hpp>
// Note: Uncomment when using Svc:TlmPacketizer
// #include <billee_deployment/Top/billee_deploymentPacketsAc.hpp>
#include <config/FppConstantsAc.hpp>
#include <Fw/Logger/Logger.hpp>

// Necessary project-specified types
#include <Arduino/config/FprimeArduino.hpp>
#include <billee_deployment/Top/SciencePins.hpp>
#include <SD.h> //Include the SD card top level header library
#include <Fw/Types/MallocAllocator.hpp>


Fw::MallocAllocator mallocator; //namespace scope

// Allows easy reference to objects in FPP/autocoder required namespaces
using namespace billee_deployment;

// The reference topology divides the incoming clock signal (1Hz) into sub-signals: 1/100Hz, 1/200Hz, and 1/1000Hz
Svc::RateGroupDriver::DividerSet rateGroupDivisors{{{100, 0}, {200, 0}, {1000, 0}}};

// Rate groups may supply a context token to each of the attached children whose purpose is set by the project. The
// reference topology sets each token to zero as these contexts are unused in this project.
U32 rateGroup1Context[FppConstant_PassiveRateGroupOutputPorts::PassiveRateGroupOutputPorts] = {};

/**
 * \brief configure/setup components in project-specific way
 *
 * This is a *helper* function which configures/sets up each component requiring project specific input. This includes
 * allocating resources, passing-in arguments, etc. This function may be inlined into the topology setup function if
 * desired, but is extracted here for clarity.
 */
void configureTopology() {
    // Rate group driver needs a divisor list
    rateGroupDriver.configure(rateGroupDivisors);

    // Allocate buffer for incoming command sequences
    cmdSeq.allocateBuffer(0, mallocator, 4 * 1024);


    // Rate groups require context arrays.
    rateGroup1.configure(rateGroup1Context, FW_NUM_ARRAY_ELEMENTS(rateGroup1Context));
}

// Public functions for use in main program are namespaced with deployment name billee_deployment
namespace billee_deployment {
void setupTopology(const TopologyState& state) {
    // Autocoded initialization. Function provided by autocoder.
    initComponents(state);
    // Autocoded id setup. Function provided by autocoder.
    setBaseIds();
    // Autocoded connection wiring. Function provided by autocoder.
    connectComponents();
    // Autocoded configuration. Function provided by autocoder.
    configComponents(state);
    // Project-specific component configuration. Function provided above. May be inlined, if desired.
    configureTopology();
    // Autocoded command registration. Function provided by autocoder.
    regCommands();
    // Autocoded parameter loading. Function provided by autocoder.
    // DISABLED FOR ARDUINO BOARDS. Loading parameters are not supported because there is typically no file system.
    // loadParameters();
    // Autocoded task kick-off (active components). Function provided by autocoder.
    
    if (!SD.begin(BUILTIN_SDCARD)) {
    Fw::Logger::log("SD card init failed; sequences unavailable\n");
    }


    startTasks(state);

    comDriver.configure(&Serial);

    // Relays, pins per SciencePins.hpp. Every relay is driven LOW (load off) right away so nothing switches on
    // during boot; the managers then re-drive their pins from their (all-off) state every rate-group tick.
    pump1Gpio.open(SciencePins::PUMP1, Arduino::GpioDriver::OUT);
    pump2Gpio.open(SciencePins::PUMP2, Arduino::GpioDriver::OUT);
    pump3Gpio.open(SciencePins::PUMP3, Arduino::GpioDriver::OUT);
    pump4Gpio.open(SciencePins::PUMP4, Arduino::GpioDriver::OUT);
    uvGpio.open(SciencePins::UV_LIGHT, Arduino::GpioDriver::OUT);
    stirrer1Gpio.open(SciencePins::STIRRER1, Arduino::GpioDriver::OUT);
    stirrer2Gpio.open(SciencePins::STIRRER2, Arduino::GpioDriver::OUT);

    Arduino::GpioDriver* const relays[] = {&pump1Gpio, &pump2Gpio,    &pump3Gpio,   &pump4Gpio,
                                           &uvGpio,    &stirrer1Gpio, &stirrer2Gpio};
    for (Arduino::GpioDriver* const relay : relays) {
        relay->get_gpioWrite_InputPort(0)->invoke(Fw::Logic::LOW);
    }

    // Limit switches, pins per SciencePins.hpp. Each closes to GND when tripped and RoboclawManager treats
    // LOW as "tripped". GpioDriver only offers plain INPUT (no pull-up), which would leave an open switch
    // floating and able to read LOW at random and stop a motor, so enable the Teensy's internal pull-up on each pin.
    struct LimitSwitch {
        Arduino::GpioDriver& gpio;
        U8 pin;
    };
    const LimitSwitch limitSwitches[] = {
        {soilLowerLimitGpio, SciencePins::SOIL_LOWER_LIMIT},
        {soilUpperLimitGpio, SciencePins::SOIL_UPPER_LIMIT},
        {drillAsmLowerLimitGpio, SciencePins::DRILL_ASM_LOWER_LIMIT},
        {drillAsmUpperLimitGpio, SciencePins::DRILL_ASM_UPPER_LIMIT},
        {drillTubeLowerLimitGpio, SciencePins::DRILL_TUBE_LOWER_LIMIT},
        {drillTubeUpperLimitGpio, SciencePins::DRILL_TUBE_UPPER_LIMIT},
    };
    for (const LimitSwitch& limitSwitch : limitSwitches) {
        limitSwitch.gpio.open(limitSwitch.pin, Arduino::GpioDriver::IN);
        pinMode(limitSwitch.pin, Arduino::DEF_INPUT_PULLUP);
    }

    // Each instance gets its own physical serial line and its own Roboclaw device address
    // (set per-device via Roboclaw's DIP switches / Motion Studio): roboclaw1Manager is 0x80 on Serial1
    // (RX 0 / TX 1), roboclaw2Manager is 0x81 on Serial2 (RX 7 / TX 8) and roboclaw3Manager (linear
    // actuator) is 0x82 on Serial4 (RX 16 / TX 17). Serial3, Serial5 and Serial8 are not usable: their
    // pins are limit switch inputs (14/15, 21) and stirrer relays (34/35), see SciencePins.hpp.
    roboclaw1Manager.configure(&Serial1, 0x80);
    roboclaw2Manager.configure(&Serial2, 0x81);
    roboclaw3Manager.configure(&Serial4, 0x82);

    // PCA9685 servo board on the Teensy's Wire bus (SDA pin 18, SCL pin 19). Wire, not Wire1: Wire1's pins
    // (16/17) are Serial4's, which roboclaw3Manager uses above. 0 = the board's A5..A0 address pins (-> I2C
    // address 0x40, the library adds the base itself). 100 kHz rather than the library's 400 kHz default: the
    // bus pull-ups (breakout's 10k in parallel with the Teensy's internal ~22k) are too weak to guarantee
    // 400 kHz rise times over jumper wires, and a servo frame is 20 ms so 100 kHz costs nothing.
    // Power the board's logic VCC from the Teensy's 3.3 V (its pins are not 5 V tolerant).
    pca9685Manager.configure(&Wire, 0, 100000);

    rateDriver.configure(1);
    rateDriver.start();
}

void teardownTopology(const TopologyState& state) {
    // Autocoded (active component) task clean-up. Functions provided by topology autocoder.
    cmdSeq.deallocateBuffer(mallocator);
    stopTasks(state);
    freeThreads(state);
}
};  // namespace billee_deployment
