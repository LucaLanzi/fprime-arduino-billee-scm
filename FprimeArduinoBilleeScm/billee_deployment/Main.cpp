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

#include <Fw/Types/Assert.hpp>

// A failed FW_ASSERT must leave the board reachable by `make flash`.
//
// Without a hook, Fw::AssertHook::doAssert() -> assert(0) -> abort(), which on Teensy is a silent
// `while (1) asm("WFI")`. The passive rate group runs from the rate driver's timer interrupt, so an
// assert raised there (e.g. a full async queue) hangs *inside an ISR*: the USB core is never serviced
// again, the host can no longer enumerate the board or send the soft-reboot request, and only the
// physical Program button recovers it. Rebooting into the Teensy bootloader instead means any assert
// leaves the board waiting for firmware (USB 16c0:0478), where `make flash` works unattended.
//
// No text is printed here on purpose: Serial is the binary CCSDS channel fprime-gds is attached to.
class RebootToBootloaderAssertHook : public Fw::AssertHook {
  public:
    void reportAssert(FILE_NAME_ARG file,
                      FwSizeType lineNo,
                      FwSizeType numArgs,
                      FwAssertArgType arg1,
                      FwAssertArgType arg2,
                      FwAssertArgType arg3,
                      FwAssertArgType arg4,
                      FwAssertArgType arg5,
                      FwAssertArgType arg6) override {}
    void doAssert() override {
        _reboot_Teensyduino_();  // runs the bootloader (bkpt #251); safe from ISR context, never returns
    }
};
static RebootToBootloaderAssertHook rebootToBootloaderAssertHook;


/**
 * \brief setup the program
 *
 * This is an extraction of the Arduino setup() function.
 * 
 */
void setup() {
    rebootToBootloaderAssertHook.registerHook();

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