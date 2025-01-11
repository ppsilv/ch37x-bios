@echo off
set bios=pcxtbios
copy config-64k.asm configs.asm

if exist %bios%.obj del %bios%.obj
if exist %bios%.lst del %bios%.lst
if exist %bios%.exe del %bios%.exe
if exist %bios%.bin del %bios%.bin

@echo *******************************************************************************
@echo Assembling BIOS
@echo *******************************************************************************
win32\wasm -zcm=tasm -d2 -e=1 -fe=nul -nm=code -fo=%bios%.obj %bios%.asm
if errorlevel 1 goto errasm
if not exist %bios%.obj goto errasm

@echo.
@echo *******************************************************************************
@echo Generating Listing
@echo *******************************************************************************
win32\wdis -l=%bios%.lst -s=%bios%.asm %bios%.obj
if errorlevel 1 goto errlist
if not exist %bios%.lst goto errlist
echo Ok

@echo.
@echo *******************************************************************************
@echo Linking BIOS
@echo *******************************************************************************
win32\wlink format dos name %bios%.exe file %bios%.obj
del %bios%.obj
if not exist %bios%.exe goto errlink

@echo.
@echo *******************************************************************************
@echo Building Disc Bios
@echo *******************************************************************************
"\Program Files\NASM\nasm.exe" disc.asm
"..\padbin.exe" 6144 disc
"..\romcksum32.exe" -o disc

if not exist disc goto errdisc

"\Program Files\NASM\nasm.exe" migration.asm

if not exist migration goto errmigration

@echo.
@echo *******************************************************************************
@echo Building ROM Images
@echo *******************************************************************************

win32\exe2rom /8 %bios%.exe %bios%.bin
del %bios%.exe

if not exist eproms\39SF010\nul mkdir eproms\39SF010

win32\romfill /64 %bios%.bin                 eproms\39SF010\%bios%.rom
win32\inject /0 disc eproms\39SF010\%bios%.rom
REM The "boot from ROM" fails if you don't change STUB_LOADER_SEGMENT in pcxtbios.asm to F6
REM before building.  We'd inject at F900 to match the 32k ROM, but
REM INJECT seems to bet confused with an offset parameter of /9000 or /9100 and uses 8000.
win32\inject /2000 migration eproms\39SF010\%bios%.rom
REM Pack another executable option ROM at F0000, like a floppy controller
REM win32\inject /0000 ..\floppy_bios-2.2.bin eproms\39SF010\%bios%.rom
REM Pack another executable option ROM at F3000, like an XT-IDE ROM
REM win32\inject /4000 ..\ide_xtpl.bin eproms\39SF010\%bios%.rom
REM optional payload is loaded at 0xF6100 and can be selected at boot time
REM win32\inject /7100 ..\mon88.com eproms\39SF010\%bios%.rom

@echo *******************************************************************************
@echo SUCCESS!: BIOS successfully built
@echo *******************************************************************************
goto end

:errasm
@echo.
@echo.
@echo *******************************************************************************
@echo ERROR: Error assembling BIOS
@echo *******************************************************************************
goto end

:errlist
@echo.
@echo.
@echo *******************************************************************************
@echo ERROR: Error generating listing file
@echo *******************************************************************************
goto end

:errlink
@echo.
@echo *******************************************************************************
@echo ERROR: Error linking BIOS
@echo *******************************************************************************
goto end

:errdisc
@echo.
@echo.
@echo *******************************************************************************
@echo ERROR: Error building Disc BIOS
@echo *******************************************************************************
goto end


:errmigration
@echo.
@echo.
@echo *******************************************************************************
@echo ERROR: Error building monitor migration handoff code
@echo *******************************************************************************
goto end


:end
if exist disc del disc
if exist migration del migration
if exist %bios%.obj del %bios%.obj
if exist %bios%.exe del %bios%.exe

pause
