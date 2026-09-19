// ======================================================================
// \title  Main.cpp
// \brief main program for the F' application. Intended for Arduino-based systems
//
// ======================================================================
// Used to access topology functions
#include <billee_deployment/Top/billee_deploymentTopologyAc.hpp>
#include <billee_deployment/Top/billee_deploymentTopology.hpp>

// Used for Baremetal TaskRunner
#include <fprime-baremetal/Os/TaskRunner/TaskRunner.hpp>

// Used for logging
#include <Arduino/Os/Console.hpp>


/**
 * \brief setup the program
 *
 * This is an extraction of the Arduino setup() function.
 * 
 */
void setup() {
    // Initialize OSAL
    Os::init();

    // Setup Serial
    Serial.begin(115200);
    // Os::Console is intentionally NOT wired to Serial here: comDriver (below,
    // via setupTopology) owns Serial exclusively as the binary CCSDS comm
    // channel fprime-gds connects to. Console/Fw::Logger text output and
    // comDriver's binary frames were both landing on the same wire, which
    // corrupts frame sync from fprime-gds's point of view (confirmed: a
    // direct pyserial read of Serial at boot showed plain-text
    // "EVENT: ... DIAGNOSTIC: (cmdDisp) OpCodeRegistered" lines, not clean
    // CCSDS frames) - the board was alive and running correctly, but GDS
    // could never lock onto a stable frame boundary. Os::Console's handle
    // defaults its stream to nullptr and writeMessage() no-ops on a null
    // stream (see Arduino/Os/Console.cpp), so leaving it unset here is safe;
    // Fw::Logger::log() calls (below) simply produce no output.

    // Object for communicating state to the reference topology
    billee_deployment::TopologyState inputs;
    inputs.uartNumber = 0;
    inputs.uartBaud = 115200;

    // Setup topology
    billee_deployment::setupTopology(inputs);

    Fw::Logger::log("Program Started\n");
}

/**
 * \brief run the program
 *
 * This is an extraction of the Arduino loop() function.
 * 
 */
void loop() {
#ifdef USE_BASIC_TIMER
    rateDriver.cycle();
#endif
    Os::Baremetal::TaskRunner::getSingleton().run();
}