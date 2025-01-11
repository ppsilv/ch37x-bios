[BITS 16]
CPU 186
ORG 0X0000



;These dimensions correspond to a traditional 360k floppy.

MAX_SPT equ 9
MAX_HPC equ 2




;Header so it's recognized as an option card

DB 0x55
DB 0xAA

; Uses 2 512-byte pages.  Expand if this grows over 1kb.
DB 0x04

; Code starts here.  Save everything before we start.

PUSHF
PUSH AX
PUSH BX
PUSH CX
PUSH DX
PUSH SI
PUSH DI
; Prep INT 18 handler
PUSH DS
XOR AX, AX
MOV DS, AX
MOV WORD DS:0x0060, INT18
MOV WORD DS:0x0062, CS
POP DS
POP DI
POP SI
POP DX
POP CX
POP BX
POP AX
POPF
RETF			;RETURN

MSG_INT18_SIGNATURE:
	DB '[BOOT] ROM Boot from ', 0

MSG_BOOT_FAIL:
	DB '[', 0x84, 'E', 0x84, 'R', 0x84, 'R', 0x84,'O', 0x84,'R ] Could not boot ROM.', 0x0D, 0x0A, 0

; Gimmick:  If you give it a 0x01 character, it will check CX to see which drive is being scanned; useful for messages like the "USB 1" message
; Characters over 0x80 will print a blank space with the lowest 4 bits to set colour, to preload a coloured character space.

WRITE_MESSAGE:
    PUSH AX
	PUSH CX
	MOV CX, 1
.WRITE_LOOP:
	MOV AH, 0x0E
    MOV AL, [BX]
	CMP AL, 0
	JE .WRITING_DONE
	CMP AL, 0x80
	JB .WRITE_ONE_CHAR
	PUSH BX
	MOV BL, AL
	AND BL, 0x7F
	MOV BH, 00
	MOV AX, 0x0920
	INT 0x10
	MOV AH, 0x0E
	POP BX
	INC BX
	JMP .WRITE_LOOP
.WRITE_ONE_CHAR:
	CMP AL, 1
	JNE .ACTUAL_CHAR
	POP CX
	MOV AX, CX ;During scan, CX is the number of drives found so far
	PUSH CX
	MOV AH, 0x0E
	ADD AL, '1';
.ACTUAL_CHAR:
    INT 0x10
    INC BX
	JMP .WRITE_LOOP
.WRITING_DONE:
	POP CX
    POP AX
    RET


INT18:
	sti					; Enable interrupts
	PUSH CS
	POP DS
	MOV BX, MSG_INT18_SIGNATURE
	CALL WRITE_MESSAGE
	MOV AX, CS
	ADD AX, 0x80	;Data storage segment = Code segment + 0x80
	CALL WRITE_AX
	MOV AX, 0x0e0d
	INT 0x10
	MOV AL, 0x0a
	INT 0x10
	; Stuff our INT13 in place
	PUSH DS
	MOV DX, INT13_8086
	XOR AX, AX
    MOV DS, AX
	; Vector migration logic based on examples at https://www.bttr-software.de/forum/board_entry.php?id=11433
	; Save old vector to INT 0xBF - using something internal to ROM BASIC supposedly, which is likely safe since we're a ROM BASIC substitute.
	MOV AX, DS:0x004C
	MOV DS:0x2FC, AX
	MOV AX, DS:0x004E
	MOV DS:0x2FE, AX
	
	; write our new vector into place

    MOV WORD DS:0x004C, DX
    MOV WORD DS:0x004E, CS

    POP DS

	xor	dx, dx				; Assume floppy drive (0)
TRY_BOOT:
	PUSH DX
	mov	ah, 0
	int	13h				; Reset drive
	jb	FAIL_BOOT
	POP DX
	xor	ax, ax
	mov	es, ax				; Segment 0
	mov	ax, 0201h			; One sector read
	mov	bx, 7C00h			;   offset  7C00
	mov	cl, 1				;   sector 1
	mov	ch, 0				;   track  0
	int	13h

	jb	FAIL_BOOT
	JMP 0:0x7C00			; Launch the sector we loaded
	
FAIL_BOOT:
	MOV BX, MSG_BOOT_FAIL
	CALL WRITE_MESSAGE
	INT 0x18			; Fall back to "NO ROM BASIC - SYSTEM HALTED" style error.


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;INT 0X13 SOFTWARE DISK INTERRUPTS
;DONT FORGET HARDWARE INTERRUPTS ARE DISABLED WHEN SOFTWARE INTERRUPTS ARE CALLED
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
INT13_8086:
	PUSHF
	CMP DL, 0		;CHECK FOR DISK NUMBER BEING REQUESTED 
	JE .START_INT13		;JMP IF 0X00 for drive A
	JMP NOT_A_DRIVE
  .START_INT13:	
	POPF				; we don't need the pushed flags, so discard them.
	STI					; Restore interrupts to prevent time dilation


;CALL DUMP_REGS
	CMP AH, 0X00
	JE PLACEHOLDER_RETURN 			;RESET DISK
	CMP AH, 0X0D
	JE PLACEHOLDER_RETURN			;RESET DISK
	CMP AH, 0X01
	JE GET_STATUS_LAST_OPERATION	;GET STATUS OF LAST OPERATION 
	CMP AH, 0X02	
	JE DISK_OP_8086
	CMP AH, 0x03
	JE PLACEHOLDER_READONLY
	CMP AH, 0x05
	JE PLACEHOLDER_READONLY
	CMP AH, 0x06
	JE PLACEHOLDER_READONLY
	CMP AH, 0x07
	JE PLACEHOLDER_READONLY
	CMP AH, 0X08
	JE PARAMETERS					;GET DISK PARAMETERS
	CMP AH, 0X15
	JE GET_DISK_TYPE				;GET DISK TYPE
	CMP AH, 0X10
	JE PLACEHOLDER_RETURN			;Test if ready
	CMP AH, 0X11
	JE PLACEHOLDER_RETURN			;Calibrate Drive
	CMP AH, 0X04
	JE PLACEHOLDER_RETURN			;VERIFY
	CMP AH, 0X0C
	JE PLACEHOLDER_RETURN					;Seek to cylinder
	CMP AH, 0X12
	JE PLACEHOLDER_RETURN			;Controller Diagnostic
	CMP AH, 0X13
	JE PLACEHOLDER_RETURN			;Drive Diagnostic
	CMP AH, 0X14
	JE PLACEHOLDER_RETURN			;Internal Diagnostic
	CMP AH, 0X16
	JE PLACEHOLDER_RETURN			;Disc change detection
	CMP AH, 0X09					
	JE PLACEHOLDER_RETURN			;Initialize format to disk table

									;FUNCTION NOT FOUND
	MOV AH, 0X01					;INVALID FUNCTION IN AH
	STC								;SET CARRY FLAG 	
	JMP INT13_END_WITH_CARRY_FLAG


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;PLACEHOLDER FOR FUNCTIONS THAT DON'T APPLY/WORK
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;		
PLACEHOLDER_RETURN:	
	MOV AH, 0X00		;STATUS 0X00 SUCCESSFULL
	CLC					;CLEAR CARRY FLAG SUCCESFUL	
	JMP INT13_END_WITH_CARRY_FLAG

PLACEHOLDER_READONLY:
	MOV AH, 0x03
	STC
	JMP INT13_END_WITH_CARRY_FLAG

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;STATUS OF LAST OPERATION  
;THIS PROABLY WILL NEED WORK
;THE CH376 ERROR STATUS NUMBERS DO NOT MATCH PC COMPATABLE NUMBERS
;STATUS 0X14 IS SUCCESS AND INTERPRETED TO RETURN 0X00
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;		
GET_STATUS_LAST_OPERATION:	
	MOV AH, 0X00						;STATUS 0X00 SUCCESSFULL
	CLC									;CLEAR CARRY FLAG SUCCESFUL	
	JMP INT13_END_WITH_CARRY_FLAG

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;READ DISK SECTOR	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;LBA = (C × HPC + H) × SPT + (S − 1)
;MAX NUMBERS C = 0X3FF, H = 0XFF, S = 0X3F
;AH = 02h
;AL = number of sectors to read (must be nonzero)
;CH = low eight bits of cylinder number
;CL = sector number 1-63 (bits 0-5)
;high two bits of cylinder (bits 6-7, hard disk only)
;DH = head number
;DL = drive number (bit 7 set for hard disk)
;ES:BX -> data buffer
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


DISK_OP_8086:
	; Store registers so we can access them at BP offsets

	PUSH BP
	MOV BP, SP
	PUSH DS					; BP-2
	PUSH ES					; BP-4
	PUSH DI					; BP-6
	PUSH SI					; BP-8
	PUSH DX					; BP-10
	PUSH CX					; BP-12
	PUSH BX					; BP-14
	PUSH AX					; BP-16	
	
	CALL CONVERT_CHS_TO_LBA
	MOV BX, AX					; BX is low LBA, which is enough for a floppy size image
	MOV CL, 5
	SHL BX, CL					; BX is now LBA offset in 16-byte paragraphs, again should be enough for a <200k ROM disk
	MOV AX, CS
	ADD BX, AX
	ADD BX, 0x80				; Data storage segment is CS + 0x80 + BX
	MOV DS, BX					; DS is now segment with ROM disk
	

	MOV CX, [SS:BP-16]          ; Store desired sector count in CX
	XOR CH, CH
	MOV BX, [SS:BP-14]			; Restore BX
.NEXT_SECTOR:
	XOR DX, DX

.NEXT_WORD:
	PUSH BX
	MOV BX, DX
	MOV AL, [DS:BX]
	POP BX
	MOV [ES:BX], AL
	INC BX
	INC DX
	CMP DX, 0x200
	JB .NEXT_WORD	

	

	PUSH BX
	MOV BX, DS
	ADD BX, 0x20			; Move DS 20 paragraphs (512 bytes) up.
	MOV DS, BX
	POP BX
	LOOP .NEXT_SECTOR

DISK_OP_SUCCESS:
	POP AX	; Actual registers
	POP BX
	POP CX
	POP DX
	POP SI
	POP DI
	POP ES
	POP DS
	POP BP
	MOV AH, 0X00		;STATUS 0X00 SUCCESSFULL
	CLC					;CLEAR CARRY FLAG SUCCESFUL	
	JMP INT13_END_WITH_CARRY_FLAG

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;GET PARAMETERS	0X08
;RETURNS
;AH=STATUS 0X00 IS GOOD
;BL=DOES NOT APPLY 
;CH=CYLINDERS
;CL=0-5 SECTORS PER TRACK 6-7 UPPER 2 BITS CYLINDER
;DH=NUMBER OF HEADS / SIDES -1
;DL=NUMBER OF DRIVES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
PARAMETERS:
	MOV AH, 0
	MOV BL, 01
	MOV CH, 40
	MOV CL, 9
	MOV DX, 0x0102

	
	MOV AH, 0X00		;STATUS 0X00 SUCCESSFULL
	CLC					;CLEAR CARRY FLAG SUCCESFUL	
	JMP INT13_END_WITH_CARRY_FLAG
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;GET DISK TYPE	0X15
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GET_DISK_TYPE:

	MOV AH, 1
	CLC						;CLEAR CARRY FLAG SUCCESFUL	
	JMP INT13_END_WITH_CARRY_FLAG

	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;END INT 0X13 WITH UPDATED CARRY FLAG		
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  INT13_END_WITH_CARRY_FLAG:	;THIS IS HOW I RETURN THE CARRY FLAG
	PUSH AX						;STORE AX
	PUSHF						;STORE FLAGS
	POP AX						;GET AX = FLAGS
	PUSH BP						;STORE BP
	MOV BP, SP              	;Copy SP to BP for use as index
	ADD BP, 0X08				;offset 8
	AND WORD [BP], 0XFFFE		;CLEAR CF = ZER0
	AND AX, 0X0001				;ONLY CF 
	OR	WORD [BP], AX			;SET CF AX
	POP BP               		;RESTORE BASE POINTER
	POP AX						;RESTORE AX	
	IRET						;RETRUN

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; WHEN REQUEST IS NOT A VALID DRIVE NUMBER
; INVOKE OLD BIOS VECTOR AND RETURN
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
NOT_A_DRIVE:
  	POPF ; we want the flags we stored before the original compare
	INT 0xBF
	PUSH BP
	MOV BP,SP
	PUSHF
	POP WORD [SS:BP+6]
	POP BP
	IRET
		
;;;;;;;;;;;;;;;;;;;;;;;
;WRITE TO SCREEN;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;

WRITE_AL_AS_DIGIT:
	MOV AH, 0x0E
	OR AL, 0x30
	INT 0x10
	RET

WRITE_AX:
	PUSH AX
	MOV AL, AH
	CALL WIRTE_AL_INT10_E
	POP AX
	CALL WIRTE_AL_INT10_E
	RET


WIRTE_AL_INT10_E:

	PUSH AX
	PUSH BX
	PUSH CX
	PUSH DX

	MOV BL, AL

	MOV DH, AL
	MOV CL, 0X04
	SHR DH, CL

	MOV AL, DH
	AND AL, 0X0F
	CMP AL, 0X09
	JA LETTER_HIGH

	ADD AL, 0X30
	JMP PRINT_VALUE_HIGH

	LETTER_HIGH:
	ADD AL, 0X37

	PRINT_VALUE_HIGH:
	MOV AH, 0X0E
	INT 0X10

	MOV AL, BL
	AND AL, 0X0F
	CMP AL, 0X09
	JA LETTER_LOW

	ADD AL, 0X30
	JMP PRINT_VALUE_LOW

	LETTER_LOW:
	ADD AL, 0X37

	PRINT_VALUE_LOW:
	MOV AH, 0X0E
	INT 0X10

	POP DX
	POP CX
	POP BX
	POP AX

	RET



CONVERT_CHS_TO_LBA:
	PUSH CX
	PUSH CX					;STORE CX / SECTOR NUMBER
	PUSH DX					;STORE DX / DH HEAD NUMBER

	XOR AX, AX
	MOV AL, CL				;Top two bits go in AL
	SHL AX, 1					; shunted to bottom of AH
	SHL AX, 1
	MOV AL, CH				; bottom 8 bits now in AL

	MOV CX, MAX_HPC			;NUMBER OF HEADS / SIDES (HPC)
	MUL CX					;AX = C X HPC
	POP CX					;GET HEAD NUMBER
	MOV CL, CH				;MOV HEAD NUMBER
	MOV CH, 0X00			;CLEAR CH
	ADD AX, CX				;ADD IN HEAD (C X HPC + H)
	MOV CX, MAX_SPT			;SECTORS PER TRACK	
	MUL CX					;DX:AX (C X HPC + H) X SPT
	POP CX					;GET SECTOR NUMBER
	AND CX, 0X003F			;CLEAR OUT CYLINDER
	DEC CX					;(S - 1)
	ADD AX, CX				;LBA = (C × HPC + H) × SPT + (S − 1)
	ADC DX, 0X00			;IF THERE IS A CARRY POSIBLE I DONT KNOW
	POP CX
	RET
