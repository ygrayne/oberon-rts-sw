# Oberon RTS Software

**Experimental work in progress!**

## Overview

Check out [oberon-rts.org](https://oberon-rts.org), which is awfully behind, but it's the best there is for now, apart from this and the corresponding hardware repository. As the saying goes, only debug code, don't get deceived by the comments.

Here is the sister repo for the corresponding hardware: [oberon-rts-hw](https://github.com/ygrayne/oberon-rts-hw).


## Current Status

* 2023-03-29: The simplified Oberon RTS system builds and runs on platforms P3 and P4 as provided by the designs in the hardware repo ("SD card swap compatible").
* 2023-03-30: Added FPGA-based logging facility.


## Next Up

* Watchdog
* Stack overflow monitor (maybe not yet)

Devices such as the watchdog and the stack overflow monitor are needed so I can trigger "asynchrounous" errors from the hardware, that is, errors that are not detected by the software itself, ie. traps. I want to rethink the whole error handling concept.

The stack overflow monitor will need a change in the CPU to "pull out" the stack register on hardware level. Not sure if I am ready and sufficiently confident with the THM architecture yet. :)


## Architectures

There are hardware platforms that implement two different architectures. At their core, both use the RISC5 CPU and its environment as defined and implemented in [Project Oberon](http://projectoberon.net) and Embedded Project Oberon, which I refer to as the ETH architecture. I use the [Embedded Project Oberon](https://astrobe.com/RISC5/ReadMe.htm) version as basis.

The [THM architecture](https://github.com/hgeisse/THM-Oberon) is a different re-implementation of the CPU and its environment. Note that this project implements the full Project Oberon system, and is based on the [Extended Oberon](https://github.com/andreaspirklbauer) compiler.

See also the above hardware repo on GitHub.


## Compiler

All the software here uses the cross compiler of [Astrobe for RISC5](https://www.astrobe.com/RISC5/default.htm) in its latest version, currently v8.0.

The Project Oberon compiler and the Extended Oberon compiler are not supported. Things may or may not work, not tested.


## The Simplified, Minimum System

Many modules have been removed and don't even appear yet in the repo. In the simplified modules, the relevant parts have been commented out, or removed. **It's a functioning mess.**


## Directory Structure

* oberon-rts-sw
  * lib
    * rts: the modules for Oberon RTS that are independent of the platform
    * platform: the platform-dependent ones
  * system: a directory per system, usually only a module that builds the whole system
    * s1-rts: currently building the minimal system
  * orig
    * the modules from Embedded Project Oberon that are relevant for RTS


## Licences and Copyright

The repo contains unaltered original files, as well as altered ones to implement adaptations and extensions. All files that were edited refer to their base and origin. The respective copyrights apply.

Please refer to COPYRIGHT.