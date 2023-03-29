# Oberon RTS Software

**Work in progress!**

## Overview

Check out [oberon-rts.org](https://oberon-rts.org), which is awfully behind, but it's the best there is for now, apart from this repository. As the saying goes, only debug code, don't get deceived by the comments.

Here is the sister repo for the corresponding hardware: [oberon-rts-hw](https://github.com/ygrayne/oberon-rts-hw).


## Status

2023-03-29: The simplified Oberon RTS system builds and runs on platforms P3 and P4 as provided by the designs in the hardware repo ("SD card swap compatible").


## Next Up

Enhance the current system. First thing will be to bring back the FPGA-based logging facility. Thereafter, the watch dog, so I can trigger "asynchrounous" errors from the hardware, ie. errors that are not detected by the software itself, namely traps. I want to rethink the whole error handling concept.


## The Simplified, Minimum System

Many modules have been removed and don't even appear yet in the repo. In the simplified modules, the relevant parts have been commented out, or removed. It's a functioning mess.


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