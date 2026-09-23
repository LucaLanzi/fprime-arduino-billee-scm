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
    startTasks(state);

    comDriver.configure(&Serial);

    pump1Gpio.open(1, Arduino::GpioDriver::OUT);
    pump2Gpio.open(2, Arduino::GpioDriver::OUT);
    pump3Gpio.open(3, Arduino::GpioDriver::OUT);
    pump4Gpio.open(4, Arduino::GpioDriver::OUT);

    uvGpio.open(5, Arduino::GpioDriver::OUT);

    // Auto set to off when booting up
    uvGpio.get_gpioWrite_InputPort(0)->invoke(Fw::Logic::LOW);

    limitSw1Gpio.open(6, Arduino::GpioDriver::IN);
    limitSw2Gpio.open(7, Arduino::GpioDriver::IN);
    limitSw3Gpio.open(8, Arduino::GpioDriver::IN);
    limitSw4Gpio.open(9, Arduino::GpioDriver::IN);
    // Each limit switch closes to GND when tripped and RoboclawManager treats LOW as "tripped".
    // GpioDriver only offers plain INPUT (no pull-up), which would leave an open switch floating and
    // able to read LOW at random and stop a motor, so enable the Teensy's internal pull-up on each pin.
    pinMode(6, Arduino::DEF_INPUT_PULLUP);
    pinMode(7, Arduino::DEF_INPUT_PULLUP);
    pinMode(8, Arduino::DEF_INPUT_PULLUP);
    pinMode(9, Arduino::DEF_INPUT_PULLUP);

    // Each instance gets its own physical serial line and its own Roboclaw device address
    // (set per-device via Roboclaw's DIP switches / Motion Studio): roboclaw1Manager is address
    // 0x80 on Serial3 and roboclaw2Manager is 0x81 on Serial4. Serial3/Serial4 are used (not
    // Serial1/Serial2) because Serial1's default TX pin is pin 1, which pump1Gpio above already
    // claims as a plain digital output.
    roboclaw1Manager.configure(&Serial3, 0x80);
    roboclaw2Manager.configure(&Serial4, 0x81);

    rateDriver.configure(1);
    rateDriver.start();
}

void teardownTopology(const TopologyState& state) {
    // Autocoded (active component) task clean-up. Functions provided by topology autocoder.
    stopTasks(state);
    freeThreads(state);
}
};  // namespace billee_deployment
