=======================================================================
	Enhanced BIOS for the EMM Computers V40/8088 Mainboard
       		Version 3.2, 7th December 2021
=======================================================================

Most of the code here is from the original/modified Anonymous BIOS
(please see readme-original.txt for more information).

The additions here are based on Elijah M. Miller's custom BIOS with
modifications and further tweaks and repackaging by Jack Zeal

Build Process:

The build script expects you to have NASM (https://www.nasm.us/)
installed in \Program Files\NASM.  It also expects the utilities
"padbin" (http://www.pineight.com/gba/gbfs.zip) and "romcksum32"
(https://github.com/agroza/romcksum) installed one directory
above this repository.

Basically, disc.asm gets built with NASM, while the main pcxtbios.asm
gets built with WASM (inclouded in the win32 directory).
We then pad disc.asm to 2k, set an appropriate Option ROM checksum
and drop it at the bottom of the 32k image.

Run make_win.bat and it should generate a file in eproms/27256.
This will be a 32k image you can flash and go.

Modifications relative to the original Anonymous BIOS:

disc.asm produces an Option ROM designed to be installed at 0xF8000
This provides rudimentary initialize-read-write functionality for the
CH376S controller module when mounted at address 0x60.

The main pcxtbios.asm has been extended with a function called INIT_V40
which provides the hardware-specific initialization for the V40 onboard
peripherals and keyboard controller.

Configuration Gimmick:

The EMM Mainboard has none of the configuration switches a conventional XT
clone has.  If you have two floppy drives, enable the ASSUME_TWO_FLOPPIES
option in before assembly in pcxtbios.asm, or it will assume one.  This is moot if you use
a high-density floppy card with its own BIOS.

Embeddable ROM:

This is a 12k (8k for main ROM, 4k for disc) BIOS that's in a 32k chip.
To make more use of the other 20k, it's set up to believe that an INT18
handler (typically Cassette Basic) is installed at F9000.  This is
a brief stub that copies whatever it finds from F9100 onward down to
07C0:0100, then executes it.

There's also the option to build on a 64K ROM.  In this case, there's a script
"make_win_64k.bat" with different defaults.  

The main BIOS options that vary by build are in the file "configs.asm".  
The default build scripts (make_win.bat and friends or build-linux-32k.sh and friends)
will copy over files like "config-32k.asm" or "config-64k.asm" to configs.asm when they start.

They have these options:

* Configure STUB_LOADER_SEGMENT to the first two digits of the place that the "boot something from ROM" stuff is stored.
For example, F9 for 32k ROMs and F1 for 64k ones with no options other than the disc ROM.  If you add more options in the ROM, you'll need to adjust.

* MIGRATION_SEGMENT is the full segment for where the boot-from-ROM starts.  F910 on a 32k ROM, F110 for a 64k is typical.

* The WAIT_STATE_CONFIG value controls the V40 CPU's wait state default setting.  This is convenient to store here because you might want to leave it at FF (the most conservative) for "public" builds, and dial it down for your own consumption.


Viable embedded options include a some of the "512 byte boot sector" demos
or very simple programs that only use BIOS facilities, not DOS.
A good example would be the Palo Alto Tiny BASIC interpreter
https://www.vcfed.org/forum/forum/technical-support/vintage-computer-programming/40493-palo-alto-tiny-basic-download

Experimentation seems to show that the detection for "hit space at boot"
may not work with the 8088 card.

Building the disc option ROM Only:

The disc.asm provides a standalone Option ROM which may work both with the "CH376 on a module"
of the EMM mainboard and CH375 ISA cards.  To build it by itself, just run
nasm disc.asm.

Disc Option ROM Configuration:
disc.asm has several values that should be configured for your taste before building:

DISPLAY_CH376S_ERRORS:  Increased verbosity if errors occur.
INJECT_INT19_HANDLER:  Replace the default INT19 vector with a mini-loader that tries to hit 
drive A, then C.  This is useful when paired with some XT BIOSes which don't probe the hard disc
by default.
ALLOW_INTS:  turn back on hardware interrupts when we start INT13 calls.  This may reduce stuff like
"timer does not tick while the disc is being operated on"

COMMAND_PORT and DATA_PORT:  set up for the location of the ports on your card.  The EMM mainboard
uses 0xE4 and 0xE0, but CH375 cards tend to differ.

WAIT_LEVEL is how long to pause for certain CH375/6 bring-up activities.  It's roughly in "timer ticks"
"10" is the works-for-me default, you may need to bump it if detection of the CH375/6 or drive is erratic or sluggish.

DOUBLE_WIDE:  Try to make I/O (in 186/V20+ mode) use 16-bit instructions, which will hopefully be implemented as a faster
back-to-back read/write.  Requires appropriate hardware configuration and may break things.


Next steps:
* Fine-tuning the CH375/6 reset process so it's reliable but fast, especially on exotic configurations (unusual clock rates/wait state combos)
* Fixing the boot up autosense which is convinced we have a game port 
and RTC.

* Tweaking performance settings.  The wait states on memory above 640k
are particularly touchy-- lower them too much and some video cards have
a fit.

Notes on Building Under Linux:

The original Phatcode BIOS package is needed to supply some dependencies:

1) We need the precompiled wasm binary.  The current "wasm" in the OpenWatcom package does not like the code base and complains about reusing @@loop.  The other OpenWatcom file used -- wlink -- seems to work if you use a modern version.

2) There are some custom utilities (inject, exe2rom, and romfill) we need.  If you run the provided binaries on a modern distribution (I tested with Void), they complain about missing libraries.  These are provided in source form in the Phatcode package's "toolsrc" directory.  Install the FreeBasic compiler, and recompile them with "fbc -lang qb (filename.bas)" to create modern ones with modern library dependencies.

You can build with a script like this.  (See the build-linux-* scripts for more real examples.)

#!/bin/sh
# (if you want to use a different file than the default configs.asm, copy it over here)
# cp config-personal.asm configs.asm

# this has to be the one from the original build; a newer OpenWatcom complains about reused @@loop
/path/to/phatcode/package/linux/wasm -zcm=tasm -d1 -e=1 -fe=/dev/null -nm=code -fo=pcxtbios.obj pcxtbios.asm

# OpenWatcom installed in /usr/bin/watcom -- you may be able to use the Phatcode-provided wlink, I have not tried.
/usr/bin/watcom/binl/wlink format dos name pcxtbios.exe file pcxtbios.obj

# These two utilities can be recompiled with a FreeBasic install, and then stashed somewhere in your path, like /usr/local/bin
exe2rom /8 pcxtbios.exe pcxtbios.bin
romfill /64 pcxtbios.bin pcxtbios.rom

# nasm is available from the repository in most distributions
nasm disc.asm
exe2rom /4 disc disc.rom
nasm migration.asm

# inject is also rebuilt with FreeBasic
inject /2000 disc.rom pcxtbios.rom
inject /6000 migration pcxtbios.rom

# Additional options not included in this package, subject to personal tastes.
#inject /6100 mon88.com pcxtbios.rom
#inject /3000 ide_xtpl.bin pcxtbios.rom
#inject /0 floppy_bios-2.2.bin pcxtbios.rom

This leaves the finished file in "pcxtbios.rom" in the root of the repo.