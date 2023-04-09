# Oberon RTS Library

* any: all Oberon modules that are not platform specific.

* platform: platform specific stuff
  * any: modules that work on either platform, kept here in lieu of the general 'any' directory as these are the candidates for specialisation.

* board: board specific stuff
  * any: modules that sort of work for all boards, with some limitations, but not stopping the software from functioning, such as missing LEDs. Allows for compiling for both platforms and keeping the "SD card swappability" for now.