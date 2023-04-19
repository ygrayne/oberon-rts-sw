# Oberon RTS Software

**Experimental work in progress!**

## Overview

Check out [oberon-rts.org](https://oberon-rts.org), which is awfully behind, but it's the best there is for now, apart from this and the corresponding hardware repository. As the saying goes, only debug code, don't get deceived by the comments.

Here is the sister repo for the corresponding hardware: [oberon-rts-hw](https://github.com/ygrayne/oberon-rts-hw).


## Current Status

* 2023-04-18: added calltrace feature, cleaned up error handling and reporting

* 2023-04-10: added RTC

* 2023-04-09: restarted the Process module from the ground up, simpler for now, but well integrated with the error handling concept, which works now apart from repeated reset and restart protection.

* 2023-04-05: (re-) implemented the watchdog and the stack overflow monitor. Unified error signals from the hardware with the trap handling. The errors result in a reset and reload of the system for now, which is one possible corrective measure, but a more subtle way, where the (some) processes recover and can continue will be added. Need to rethink the processes first. Good thing is that the logging of all errors is back.

* 2023-03-30: Added FPGA-based logging facility.

* 2023-03-29: The simplified Oberon RTS system builds and runs on platforms P3 and P4 as provided by the designs in the hardware repo ("SD card swap compatible").


## Next Up

* Extend processes API
* Critical region protection


## Architectures

There are hardware platforms that implement two different architectures. At their core, both use the RISC5 CPU and its environment as defined and implemented in [Project Oberon](http://projectoberon.net) and Embedded Project Oberon, which I refer to as the ETH architecture. I use the [Embedded Project Oberon](https://astrobe.com/RISC5/ReadMe.htm) version as basis.

The [THM architecture](https://github.com/hgeisse/THM-Oberon) is a different re-implementation of the CPU and its environment. Note that this project implements the full Project Oberon system, and is based on the [Extended Oberon](https://github.com/andreaspirklbauer) compiler.

See also the above hardware repo on GitHub.


## Compiler

All the software here uses the cross compiler of [Astrobe for RISC5](https://www.astrobe.com/RISC5/default.htm) in its latest version, currently v8.0.

The Project Oberon compiler and the Extended Oberon compiler are not supported. Things may or may not work, not tested.


## The Simplified, Minimum System

Many modules have been removed and don't even appear yet in the repo. In the simplified modules, the relevant parts have been commented out, or removed. **It's a functioning mess.**

Getting slowly better, though. :)


## Directory Structure

* oberon-rts-sw
  * lib
    * any: the modules for Oberon RTS that are independent of the platform
    * platform: the platform-dependent ones
    * board: the board-dependent ones
  * system: a directory per system, usually only a module that builds the whole system
    * s1-rts: currently building the minimal system
  * orig
    * the modules from Embedded Project Oberon that are relevant for RTS


## Licences and Copyright

The repo contains unaltered original files, as well as altered ones to implement adaptations and extensions. All files that were edited refer to their base and origin. The respective copyrights apply.

Please refer to COPYRIGHT.