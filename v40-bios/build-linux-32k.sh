#!/bin/sh
# Vanilla 32k build-- nothing but disc and boot-to-something ROM are specified.  You will li

cp config-32k.asm configs.asm

# this has to be the one from the original build; a newer OpenWatcom complains about reused @@loop
../Downloads/linux/wasm -zcm=tasm -d1 -e=1 -fe=/dev/null -nm=code -fo=pcxtbios.obj pcxtbios.asm
/usr/bin/watcom/binl/wlink format dos name pcxtbios.exe file pcxtbios.obj

# These can be recompiled with a FreeBasic install, because they use an ancient library
exe2rom /8 pcxtbios.exe pcxtbios.bin
romfill /32 pcxtbios.bin pcxtbios.rom

nasm disc.asm
exe2rom /6 disc disc.rom
nasm migration.asm


inject /0000 disc.rom pcxtbios.rom
inject /2000 migration pcxtbios.rom

mv pcxtbios.rom eproms/27256