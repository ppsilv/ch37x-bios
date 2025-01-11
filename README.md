# CH37x BIOS
A standalone, bootable BIOS for use with CH375/376 modules.

Specific Targets:
* Onboard CH376 module of the [Homebrew 8088](http://www.homebrew8088.com) mainboards
* Generic "ISA to USB" cards using CH375 chips

## Configuration
The disc.asm file contains a few configurable options at the top of the file.  These are summarized as follows:

MAX_CYL, MAX_HPC, and MAX_SPT define the largest geometry that is supported.  The default is the common 504Mb "1024 cylinders, 16 heads, 63 sectors" geometry. Even if you use a 64Gb drive, you'll only see 504Mb.  You can experiment with a MAX_HPC value of 255 to present an 8Gb geometry, but this may have more compatibility issues.

DISPLAY_CH376S_ERRORS:  If enabled, you'll see more verbose errors if the CH375/6 responds unpredictably.  Errors are reported in the form "CH37X ERROR/FUNC: aa/bb", where aa is the status the CH375/6 reported, and bb is the BIOS operation number.  Mostly useful for debugging.

INJECT_INT19_HANDLER:  A mini-bootloader will be registered on interrupt 0x19.  This will attempt to boot from drive A and then C once.  This is useful for PC BIOSes that would only probe floppy drives at boot time.  Some other BIOSes (i. e. XT-IDE Universal BIOS) may in turn provide their own handler that replaces this one.

ALLOW_INTS:  Restores interrupts while communicating with the CH375/6.  If disabled, you may experience clock drift during I/O operations.  There is some modest risk of errors in the event interrupt handling code fired off a new disc operation in the middle of an existing one.

DOUBLE_WIDE:  Use "word" style instructions instead of "byte" ones when communicating with the CH375/6 for a modest performance boost.  This requires that the CH375/6 is wired so that pairs of ports are routed to the same place.  The Homebrew8088 design is this way by default, and the common AliExpress cards can be modified to support this, but do not do so by default.

RESET_COUNT:  We'll try repeatedly to probe and initialize the CH37x device before giving up.  If you need to scan many ports for one, this can take a long time.  A lower value is faster with the proviso that it might not always activate the device.

SHADOW:  Copy the BIOS ROM into the top 6k of conventional memory, and execute from there.  Potentially a speed improvement on machines with wider or faster RAM busses than ROM (8086 or higher).

At the bottom of the file (since it resides in ROM) are SCAN_COMMAND_PORTS and SCAN_DATA_PORTS-- a list of ports, terminated with a zero value, to scan.  This allows for some auto-configuration-- you still have to decide if you want 16-bit mode, but it's nice to let the drive just "drop" if not detected.

Note the firmware populates the INT41 vector if any drives are found, and INT46 vectors if a second one is located.

WAIT_LEVEL:  how long to pause for the device to respond during some of the initial bring-up steps.  Unit is roughly 1/19 second.


At the very bottom of the code, there's two tables labelled DISK_1_TABLE and DISK_2_TABLE.  These are the geometries reported to software.  For normal scenarios (larger than 504Mb drives), these are sane and represent the maximum geometry described above.  If you're using a smaller drive, you may see a down arrow and exclamation points next to the drive size.

In that case, reduce the reference in DISK_1_TABLE or DISK_2_TABLE from MAX_CYL to a number of cylinders that produces a total smaller than, or equal to, your drive size.  The BIOS will advertise a geometry that actually resembles your drive.  Alternatively, go to a trade show and find a booth with people giving away bigger-than-512Mb flash drives.  A drive larger than the maximum geometry we advertise is annotated with an up arrow.

## Building
The image is built with NASM.  Run

/path/to/nasm disc.asm

to get a file named "disc".

This needs to be padded to size.  You can use "padbin" [found here](http://little-scale.blogspot.com/2009/06/how-to-pad-bin-file.html)

/path/to/padbin 6144 disc

The file should then be 6144 bytes long. 

You then need a utility like "romcksum32" [found here](https://github.com/agroza/romcksum) to add a checksum.  For example

/path/to/romcksum32 -o disc

This should report "Option ROM: YES" and "ROM Blocks: 12, 6144 (6 KiB), CORRECT".

If you don't want to build it manually, a canned image is provided with the filename "ch37x-bios.bin".  This is designed around a single CH37x device, with the Homebrew8088 ports and mini-bootloader enabled.


You can now install this image whereever you want-- in a ROM on a CH375 card, or as part of a bigger 32 or 64k image that contains other options and/or the system BIOS.

It's suggested that this get loaded before other option ROMs that might touch interrupt 0x13 or 0x19, such as the XT-IDE Universal BIOS.

## Disc Image

The file "discimage.zip" expands to a 504Mb image which is partitioned as a single FAT16 partition.  You can 1) write this to a USB stick with a tool like Rufus or 2) mount it as a "raw" disc image in something like QEMU, and then do further prep-work, like installing your preferred OS.  This should hopefully make it easier to build an image with a specific CHS geometry.

## ROM Disc
An experimental "Disc in ROM" module is included in this package now.  It uses a substantially cut down version of the functionality of the original BIOS-- discarding a lot of features like "writing" and actually talking to the CH37x module".   This is the romdisc.asm file.

How it works:
* At initial run, it registers an INT 18 "Boot to BASIC" handler.  This way, it runs if nothing else can boot.
* The custom INT 13 handler is designed to just accept requests for drive A.
* It stores the old INT 13 handler as INT BF.  This is documented as used by ROM BASIC, so we don't need to worry about that. :)  Drive A read requests are mapped to a block of ROM immediately following the ROM Disc image.

The ROM disc image begins 2k after the start of the option ROM.  So if you put it at segment E000, the disc image starts at E080.  There is no size or "over-run" protection.  The disc image might claim to be 360k, but if you overrun the actual space, it will start reading from other parts of memory.  This seems to work for a basic "boot to DOS" model, but some operating systems might try to store stuff at the far tracks of the "disc" and not support a "cut to fit" disc image.

The ROM image can be built with the following process:
/path/to/nasm romdisc.asm
/path/to/padbin 2048 romdisc
/path/to/romcksum32 -o romdisc

A pre-compiled version is included, since there's little configuration needed.

Optionally, you can append the disc image to the ROM.  If you're composing the image you want to flash in some other way, this may be unnecessary.
cat romdisc YOUR_DISC_IMAGE_HERE > romdisc_with_image

### Sample Use Case:  "Black Start" a new system without floppies

If you have a setup with a lot of ROM, you can build something like this, based on a 39SF040 (512k) ROM mounted in the upper half of the address space.

2k for ROMdisk firmware at 0x48000 (relative to the ROM's base)
Disc image at 0x48800 (size will vary)
8k for a HD floppy BIOS at 0x77000
6k for the CH376 BIOS at 0x79000
10k for the XT-IDE Universal BIOS at 0x7A800
2k for a clock ROM like GlaTICK at 0x7D800
8k for the main BIOS at 0x7E000


The space for a disc image will allow marginally more than a 180k (single-sided) disc.  The default ROM configuration, though, simulates a two-headed disc, though, for use with a truncated 360k image.

So you can start with an image like the ones at https://github.com/codercowboy/freedosbootdisks and use mtools or play with it in an emulator to build what you want.

The standard FreeDOS COMMAND.COM is heavy.  An alternative is SvarCOM http://svardos.org/svarcom/ which buys you like 30k+ back.

You can then add in basic commands-- I suggest "format", "sys", and "fdisk".

If you can get the boot process to fall back to ROM BASIC (with the XT-IDE bootloader, this is the F8 key), it will take over, and pretend the ROM is Drive A.

From there, it should be possible to partition and format hard discs/USB/XT-IDE devices.  You know there will be no surprises with geometry, which you might find if you use a drive partitioned on a different machine.

Once you've finished the "black start" phase of the process, you probably don't need the ROMdisc functionality anymore.  Hopefully you can rejumper the address space to reassign C8000-EFFFF as upper-memory blocks.

## Authors and acknowledgment
Some of the initial code derives from Elijah Miller's BIOS for the Homebrew8088 boards.

## License
See LICENSE file.
