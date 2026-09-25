/*
 * CmdDispatcherImplCfg.hpp
 *
 *  Created on: May 6, 2015
 *      Author: tcanham
 */

#ifndef CMDDISPATCHER_COMMANDDISPATCHERIMPLCFG_HPP_
#define CMDDISPATCHER_COMMANDDISPATCHERIMPLCFG_HPP_

// Define configuration values for dispatcher

// CMD_DISPATCHER_DISPATCH_TABLE_SIZE must be >= the number of commands in the deployment (count them in the
// dictionary JSON: see README "Fixed-size tables"). Registering one command too many is an FW_ASSERT inside
// regCommands() at boot, and the assert hook then reboots the Teensy into its bootloader: the firmware builds and
// flashes fine and then never runs. It was 24 with 23 commands until PCA9685Manager (+6) took it to 29.
enum {
    CMD_DISPATCHER_DISPATCH_TABLE_SIZE = 40, // !< The size of the table holding opcodes to dispatch
    CMD_DISPATCHER_SEQUENCER_TABLE_SIZE = 8, // !< The size of the table holding commands in progress
};



#endif /* CMDDISPATCHER_COMMANDDISPATCHERIMPLCFG_HPP_ */
