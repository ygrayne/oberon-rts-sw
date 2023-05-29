# Oberon RTS Software

**Experimental work in progress!**

## Overview

Check out [oberon-rts.org](https://oberon-rts.org), which is awfully behind, but it's the best there is for now, apart from this and the corresponding hardware repository. As the saying goes, only debug code, don't get deceived by the comments.

Here is the sister repo for the corresponding hardware: [oberon-rts-hw](https://github.com/ygrayne/oberon-rts-hw).


## Status

* process concept and infrastructure
* error detection and handling
  * traps
  * stack overflow
  * watchdog
* logging, calltrace
* IO support
  * LEDs, switches, buttons, 7-seg displays
  * millisecond timer
  * RS232 (buffered, unbuffered)
  * SPI
  * GPIO
* (re-) start tables
* all activities as processes
  * command handling
  * upload
  * garbage collector
  * audit process
  * scheduling
* runs on both architectures and all platforms ("same SD card for all")


## Next Up

* I2C support
* extend processes API
* critical region protection
* process scheduling based on hardware events


## Architectures

There are hardware platforms that implement two different architectures. At their core, both use the RISC5 CPU and its environment as defined and implemented in [Project Oberon](http://projectoberon.net) and Embedded Project Oberon, which I refer to as the ETH architecture. I use the [Embedded Project Oberon](https://astrobe.com/RISC5/ReadMe.htm) version as basis.

The [THM architecture](https://github.com/hgeisse/THM-Oberon) is a different re-implementation of the CPU and its environment. Note that this project implements the full Project Oberon system, and is based on the [Extended Oberon](https://github.com/andreaspirklbauer) compiler.

See also the above hardware repo on GitHub.


## Compiler

All the software here uses the cross compiler of [Astrobe for RISC5](https://www.astrobe.com/RISC5/default.htm) in its latest version, currently v8.0.

The Project Oberon compiler and the Extended Oberon compiler are not supported. Things may or may not work, not tested.


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