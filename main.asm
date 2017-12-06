; ================================================================
; GB3D - simple, fast GBC raytracing engine
; ================================================================

include	"hardware.inc"

SECTION "Main variables",WRAM0

SpriteBuffer	ds	100

GBCFlag			ds	1
sys_btnPress	ds	1
sys_btnHold		ds	1
VBlankIRQFlag	ds	1
CPUSpeed		ds	1
ROMBank			ds	1

CurrentID		ds	1

; ================================================================
; Constants
; ================================================================

btnA		equ	0
btnB		equ	1
btnSelect	equ	2
btnStart	equ	3
btnRight	equ	4
btnLeft		equ	5
btnUp		equ	6
btnDown		equ	7

; ================================================================
; Macros
; ================================================================

; Copy a  tileset to a specified VRAM address.
; USAGE: CopyTileset [tileset],[VRAM address],[number of tiles to copy]
; "tiles" refers to any tileset.
CopyTileset:	macro
	ld	bc,$10*\3		; number of tiles to copy
	ld	hl,\1			; address of tiles to copy
	ld	de,$8000+\2		; address to copy to
	call	CopyTiles
	endm
	
str:			macro
	db	\1,0
	endm

paddedString:	macro
.start
	db	\1
.end
	rept	\2-(.start-.end)
	db	0
	endr
	endm
	
PrintString:	macro
	ld	hl,\1
	ld	de,\2
	call	_PrintString
	endm
	
TrapError:		macro
	ld	a,\1
	jp	_TrapError
	endm
	
WaitForVRAM:	macro
	ldh	a,[rSTAT]
	and	2
	jr	nz,@-4
	endm
	
DebugMessage: MACRO
	ld d,d
	jr .debugMessage\@
	dw $6464
	dw $0000
	rept _NARG
		db \1
		shift
	endr
.debugMessage\@
	endm
	
; z80 equivalent macros

djnz:	macro
	dec	b
	jr	nz,\1
	endm

; misc macros

peek:	macro
	; HERE BE HACKS
	if \1 == "af"
		push	af
	elif \1 == "bc"
		push	bc
	elif \1 == "de"
		push	de
	elif \1 == "hl"
		push	hl
	else
		fail	"Invalid argument for peek (must be af, bc, de, or hl)"
	endc
	rept	2
	dec	sp
	endr
	endm
	
; ================================================================	
; Reset vectors
; ================================================================

section	"Reset $00",rom0[$00]
WaitForVBlank:
	halt
	ret
	
; reset $08 is unused
	
section	"Reset $10",rom0[$10]
WaitForSTAT:
	ret
	
section	"Crash handler",rom0[$38]
TrapError_Crash:
	xor	a
	jp	_TrapError
	
; ================================================================
; Interrupt vectors
; ================================================================

SECTION	"VBlank interrupt",ROM0[$40]
IRQ_VBlank:
	reti
	
SECTION	"LCD STAT interrupt",ROM0[$48]
IRQ_STAT:
	reti

SECTION	"Timer interrupt",ROM0[$50]
IRQ_Timer:
	reti

SECTION	"Serial interrupt",ROM0[$58]
IRQ_Serial:
	reti

SECTION	"Joypad interrupt",ROM0[$60]
IRQ_Joypad:
	reti
	
; ================================================================
; ROM header
; ================================================================

SECTION	"ROM header",ROM0[$100]

EntryPoint:
	nop
	jp	ProgramStart

NintendoLogo:	; DO NOT MODIFY!!!
	db	$ce,$ed,$66,$66,$cc,$0d,$00,$0b,$03,$73,$00,$83,$00,$0c,$00,$0d
	db	$00,$08,$11,$1f,$88,$89,$00,$0e,$dc,$cc,$6e,$e6,$dd,$dd,$d9,$99
	db	$bb,$bb,$67,$63,$6e,$0e,$ec,$cc,$dd,$dc,$99,$9f,$bb,$b9,$33,$3e

ROMTitle:		db	"FXHAMMER TEST",0,0				; ROM title (15 bytes)
GBCSupport:		db	$80								; GBC support (0 = DMG only, $80 = DMG/GBC, $C0 = GBC only)
NewLicenseCode:	db	"  "							; new license code (2 bytes)
SGBSupport:		db	0								; SGB support
CartType:		db	$1b								; Cart type (MBC5 + RAM + Battery)
ROMSize:		ds	1								; ROM size (handled by post-linking tool)
RAMSize:		db	2								; RAM size
DestCode:		db	1								; Destination code (0 = Japan, 1 = All others)
OldLicenseCode:	db	$33								; Old license code (if $33, check new license code)
ROMVersion:		db	0								; ROM version
HeaderChecksum:	ds	1								; Header checksum (handled by post-linking tool)
ROMChecksum:	ds	2								; ROM checksum (2 bytes) (handled by post-linking tool)

; ================================================================
; Start of program code
; ================================================================

ProgramStart:
	di
	ld	sp,$e000
	push	af
;	push	bc
.wait
	ldh	a,[rLY]
	cp	$91
	jr	nz,.wait
	xor	a
	ldh	[rLCDC],a	; disable LCD
	
	call	InitRAM
	
	; load the font
	CopyTileset	Font,0,63
	ld	hl,MainText
	call	LoadMapText
	
	; check for GBC
	pop	af
	cp	$11
	jr	nz,.notgbc
	and	1
	ld	[GBCFlag],a
	call	CPUToggleSpeed
	ld	a,1
	ld	[CPUSpeed],a
	dec	a
	ld	hl,Pal_Grayscale
	call	LoadBGPalLine
	jr	.continue
.notgbc
	xor	a
	ld	[GBCFlag],a
	ld	[CPUSpeed],a
	ld	a,%11100100
	ldh	[rBGP],a
	
.continue
	; set up sound output
	ld	c,low(rNR52)
	xor	a
	ld	[c],a	; disable sound output (resets all sound regs)
	set	7,a
	ld	[c],a	; enable sound output
	dec	c
	or	$ff
	ld	[c],a	; all sound channels to left+right speakers
	dec	c
	and	$77
	ld	[c],a	; VIN output off + master volume max
	; set up rendering parameters
	ld	a,%10010001	; LCD on; BG + OBJ + WIN
	ldh	[rLCDC],a
	; enable interrupts
	ld	a,IEF_VBLANK
	ldh	[rIE],a
	ei
	
MainLoop:
	call	SoundFX_Update
	
	call	CheckInput
	ld	a,[sys_btnPress]
	bit	btnUp,a
	jr	nz,.add16
	bit	btnDown,a
	jr	nz,.sub16
	bit	btnRight,a
	jr	nz,.add1
	bit	btnLeft,a
	jr	nz,.sub1
	bit	btnA,a
	jr	nz,.trig
	bit	btnB,a
	jr	z,.continue
.stop
	call	SoundFX_Stop
	jr	.continue
.trig
	ld	a,[CurrentID]
	call	SoundFX_Trig
	jr	.continue
.add1
	ld	a,[CurrentID]
	inc	a
	jr	.setID
.sub1
	ld	a,[CurrentID]
	dec	a
	jr	.setID
.add16
	ld	a,[CurrentID]
	add	$10
	jr	.setID
.sub16
	ld	a,[CurrentID]
	sub	$10
.setID
	ld	[CurrentID],a
.continue
	ld	a,[CurrentID]
	ld	hl,$9871
	call	DrawHex

	halt
	jp	MainLoop
	

; ================================================================
; Misc routines
; ================================================================


; ===============================
; Draw hexadecimal number A at HL
; ===============================

DrawHex:
	push	af
	swap	a
	call	.loop1
	pop	af
.loop1
	and	$f
	cp	$a
	jr	c,.loop2
	add	a,$7
.loop2
	add	a,$10
;	add	32
;	call	ConvertChar
	push	af
	WaitForVRAM
	pop	af
	ld	[hl+],a
	ret
	
; ===============================
; Switching CPU speeds on the GBC
;  written for RGBASM
; ===============================

;  This is the code needed to switch the GBC
; speed from single to double speed or from
; double speed to single speed.
;
; Note: The 'nop' below is ONLY required if
; you are using RGBASM version 1.10c or earlier
; and older versions of the GBDK assembly
; language compiler. If you are not sure if
; you need it or not then leave it in.
;
;  The real opcodes for 'stop' are $10,$00.
; Some older assemblers just compiled 'stop'
; to $10 hence the need for the extra byte $00.
; The opcode for 'nop' is $00 so no harm is
; done if an extra 'nop' is included

; *** Set single speed mode ***

SingleSpeedMode:
	ld      a,[rKEY1]
	rlca	    ; Is GBC already in single speed mode?
	ret     nc      ; yes, exit
	jr      CPUToggleSpeed

; *** Set double speed mode ***

DoubleSpeedMode:
	ld      a,[rKEY1]
	rlca		    ; Is GBC already in double speed mode?
	ret     c       ; yes, exit

CPUToggleSpeed:
	di
	ld      hl,rIE
	ld      a,[hl]
	push    af
	xor     a
	ld      [hl],a	 ;disable interrupts
	ld      [rIF],a
	ld      a,$30
	ld      [rP1],a
	ld      a,1
	ld      [rKEY1],a
	stop
	pop     af
	ld      [hl],a
	ei
	ret

; ============================
; GBC palette loading routines
; ============================
	
; Input: hl = palette data	
LoadBGPal:
	ld	a,0
	call	LoadBGPalLine
	ld	a,1
	call	LoadBGPalLine
	ld	a,2
	call	LoadBGPalLine
	ld	a,3
	call	LoadBGPalLine
	ld	a,4
	call	LoadBGPalLine
	ld	a,5
	call	LoadBGPalLine
	ld	a,6
	call	LoadBGPalLine
	ld	a,7
	call	LoadBGPalLine
	ret
	
; Input: hl = palette data	
LoadObjPal:
	ld	a,0
	call	LoadObjPalLine
	ld	a,1
	call	LoadObjPalLine
	ld	a,2
	call	LoadObjPalLine
	ld	a,3
	call	LoadObjPalLine
	ld	a,4
	call	LoadObjPalLine
	ld	a,5
	call	LoadObjPalLine
	ld	a,6
	call	LoadObjPalLine
	ld	a,7
	call	LoadObjPalLine
	ret
	
; Input: hl = palette data
LoadBGPalLine:
	WaitForVRAM
	swap	a	; \  multiply
	rrca		; /  palette by 8
	or	$80		; auto increment
	ld	[rBCPS],a
	WaitForVRAM
	ld	a,[hl+]
	ld	[rBCPD],a
	WaitForVRAM
	ld	a,[hl+]
	ld	[rBCPD],a
	WaitForVRAM
	ld	a,[hl+]
	ld	[rBCPD],a
	WaitForVRAM
	ld	a,[hl+]
	ld	[rBCPD],a
	WaitForVRAM
	ld	a,[hl+]
	ld	[rBCPD],a
	WaitForVRAM
	ld	a,[hl+]
	ld	[rBCPD],a
	WaitForVRAM
	ld	a,[hl+]
	ld	[rBCPD],a
	WaitForVRAM
	ld	a,[hl+]
	ld	[rBCPD],a
	ret
	
; Input: hl = palette data
LoadObjPalLine:
	WaitForVRAM
	swap	a	; \  multiply
	rrca		; /  palette by 8
	or	$80		; auto increment
	ld	[rOCPS],a
	ld	a,[hl+]
	ld	[rOCPD],a
	WaitForVRAM
	ld	a,[hl+]
	ld	[rOCPD],a
	WaitForVRAM
	ld	a,[hl+]
	ld	[rOCPD],a
	WaitForVRAM
	ld	a,[hl+]
	ld	[rOCPD],a
	WaitForVRAM
	ld	a,[hl+]
	ld	[rOCPD],a
	WaitForVRAM
	ld	a,[hl+]
	ld	[rOCPD],a
	WaitForVRAM
	ld	a,[hl+]
	ld	[rOCPD],a
	WaitForVRAM
	ld	a,[hl+]
	ld	[rOCPD],a
	WaitForVRAM
	ret
	
; ==================
; Check joypad input
; ==================

CheckInput:
	ld	a,P1F_5
	ldh	[rP1],a
	ldh	a,[rP1]
	ldh	a,[rP1]
	cpl
	and	$f
	swap	a
	ld	b,a
	
	ld	a,P1F_4
	ldh	[rP1],a
	ldh	a,[rP1]
	ldh	a,[rP1]
	ldh	a,[rP1]
	ldh	a,[rP1]
	ldh	a,[rP1]
	ldh	a,[rP1]
	cpl
	and	$f
	or	b
	ld	b,a
	
	ld	a,[sys_btnHold]
	xor	b
	and	b
	ld	[sys_btnPress],a
	ld	a,b
	ld	[sys_btnHold],a
	ld	a,P1F_5|P1F_4
	ld	[rP1],a
	ret

; Initialize RAM
InitRAM:
	; clear WRAM
	ld	hl,$c000
	ld	bc,$1ffc	; don't clear last two bytes to preserve stack
.clearloop1
	xor	a
	ld	[hl+],a
	dec	bc
	ld	a,b
	or	c
	jr	nz,.clearloop1
	
	; clear each WRAM bank (only on GBC)
	ld	a,[$dfff]	; HACK: Read old value of A from stack
	cp	$11
	jr	nz,.notgbc1
	ld	de,$0206
	ld	a,d
	ldh	[rSVBK],a
.clearloop2a
	ld	hl,$d000
	ld	bc,$1000
.clearloop2b
	xor	a
	ld	[hl+],a
	dec	bc
	ld	a,b
	or	c
	jr	nz,.clearloop2b
	inc	d
	ld	a,d
	and	7
	ldh	[rSVBK],a
	dec	e
	jr	nz,.clearloop2a
	ld	a,1
	ldh	[rSVBK],a

.notgbc1	
	; clear VRAM bank 1
	ld	hl,$8000
	ld	bc,$2000
.clearloop3
	xor	a
	ld	[hl+],a
	dec	bc
	ld	a,b
	or	c
	jr	nz,.clearloop3
	
	; clear VRAM bank 2
	ld	a,[$dfff]	; HACK: Read old value of A from stack
	cp	$11
	jr	nz,.notgbc2
	ld	a,1
	ldh	[rVBK],a
	ld	hl,$8000
	ld	bc,$2000
.clearloop4
	xor	a
	ld	[hl+],a
	dec	bc
	ld	a,b
	or	c
	jr	nz,.clearloop4
	xor	a
	ldh	[rVBK],a
	
.notgbc2
	; clear HRAM
	ld	bc,$8080
	xor	a
.clearloop5
	ld	[c],a
	inc	c
	dec	b
	jr	nz,.clearloop5
	
	; init OAM
	call	CopyDMARoutine
	call	$ff80
	ret
	
; =======================
; Copy a  tileset to VRAM
; =======================
	
CopyTiles:
	ld	a,[hl+]			; get byte
	ld	[de],a			; write byte
	inc	de				; increment destination address
	dec	bc
	ld	a,b
	or	c
	jr	nz,CopyTiles
	ret
	
; ========================================
; Convert characters using a character map
; ========================================

ConvertChar:
;	push	hl
;	sub	32
;	ld	hl,CharTable	; because apparently CharMap is reserved
;	add	l
;	ld	l,a
;	jr	nc,.nocarry
;	inc	h
;.nocarry
;	ld	a,[hl]
;	pop	hl
	ret
	
LoadMapText:
	ld	de,_SCRN0
	ld	bc,$1214
.loop
	ld	a,[hl+]
	sub	32
;	call	ConvertChar
	ld	[de],a
	inc	de
	dec	c
	jr	nz,.loop
	ld	c,$14
	ld	a,e
	add	$C
	jr	nc,.continue
	inc	d
.continue
	ld	e,a
	dec	b
	jr	nz,.loop
	ret
	
LoadMapText_ToWindow:
	ld	de,_SCRN1
	ld	bc,$1214
.loop
	ld	a,[hl+]
	sub	32
;	call	ConvertChar
	ld	[de],a
	inc	de
	dec	c
	jr	nz,.loop
	ld	c,$14
	ld	a,e
	add	$C
	jr	nc,.continue
	inc	d
.continue
	ld	e,a
	dec	b
	jr	nz,.loop
	ret
	
DetectSGB:
	ret
	
; Print a string at a given VRAM address
; INPUT: hl = string pointer
;        de = destination
_PrintString:
	ld	a,[hl+]
	and	a
	ret	z
	sub	32
;	call	ConvertChar
	push	af
	WaitForVRAM
	pop	af
	ld	[de],a
	inc	de
	jr	_PrintString
	
; =============================
; Wait for LCD status to change
; =============================

WaitStat:
	push	af
.wait
	ld	a,[rSTAT]
	and	2
	jr	z,.wait
.wait2
	ld	a,[rSTAT]
	and	2
	jr	nz,.wait2
	pop	af
	ret
	
OAM_DMA:
	ld	a,high(SpriteBuffer)
	ldh	[rDMA],a
	ld	a,$28
.wait
	dec	a
	jr	nz,.wait
	ret
OAM_DMA_End

CopyDMARoutine:
	ld	hl,OAM_DMA
	ld	bc,$a80
.loop
	ld	a,[hl+]
	ld	[c],a
	inc	c
	dec	b
	jr	nz,.loop
	ret	
	
; ================================================================
; Interrupt handlers
; ================================================================

DoVBlank:
	push	af
	push	bc
	push	de
	push	hl
	ld	a,1
	ld	[VBlankIRQFlag],a
	pop	af
	pop	bc
	pop	de
	pop	hl
	reti

; ================================================================
; Error handler
; ================================================================

; TODO
_TrapError:
	; preserve GBC flag before restart
	ld	a,[GBCFlag]
	add	$10
	jp	$150
	
;str_ErrGeneric:		str	"unknown error"
;str_ErrStack1:			str	"stack overflow"
;str_ErrStack2:			str	"stack underflow"
;str_ErrInvalidVRAM:	str	"invalid vram access"
;str_ErrInvalidBank:	str	"invalid rom bank"
	
; ================================================================	
; Graphics data
; ================================================================

MainText:
;		 --------------------
	db	" FX HAMMER TEST ROM "
	db	"      BY DEVED      "
	db	"                    "
	db	" SFX:           $?? "
	db	"                    "
	db	"CONTROLS:           "
	db	"A -         PLAY SFX"
	db	"B -         STOP SFX"
	db	"                    "
	db	"                    "
	db	"                    "
	db	"                    "
	db	"                    "
	db	"                    "
	db	"                    "
	db	"                    "
	db	"                    "
	db	"                    "
	db	"                    "
	
str_ConsoleDMG:		str	"DMG"
str_ConsoleMGB:		str	"MGB"
str_ConsoleCGB:		str	"CGB"
str_ConsoleAGB:		str	"AGB"
str_ConsoleSGB:		str	"SGB"

str_CPUSpeed1:		str	"NORMAL"
str_CPUSpeed2:		str	"DOUBLE"
str_CPUSpeed3:		str	"   N/A"

CharTable:
	;	 	 !	 "	 #	 $	 %	 &	 '	 (	 )	 *	 +	 ,	 -	 .	 /
;	db	$20,$21,$22,$23,$24,$25,$26,$27,$20,$20,$00,$2b,$2c,$2d,$2e,$2f
	;	 0	 1	 2	 3	 4	 5	 6	 7	 8	 9	 :	 ;	 <	 =	 >	 ?
;	db	$30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$3a,$3b,$3c,$3d,$3e,$3f
	;	 @	 A	 B	 C	 D	 E	 F	 G	 H	 I	 J	 K	 L	 M	 N	 O
;	db	$20,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b,$0c,$0d,$0e,$0f
	;	 P	 Q	 R	 S	 T	 U	 V	 W	 X	 Y	 Z	 [	 \	 ]	 ^	 _
;	db	$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1a,$20,$20,$20,$1e,$1f
	;	 `	 a	 b	 c	 d	 e	 f	 g	 h	 i	 j	 k	 l	 m	 n	 o
;	db	$20,$01,$02,$03,$04,$05,$06,$07,$08,$09,$0a,$0b,$0c,$0d,$0e,$0f
	;	 p	 q	 r	 s	 t	 u	 v	 w	 x	 y	 z	 {	 |	 }	 ~	
;	db	$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$1a,$20,$20,$20,$20,$20
	
Font:	incbin	"font.bin"

Pal_Grayscale:
	dw	$7fff,$6e94,$354a,$0000

Pal_GrayscaleInverted:
	dw	$0000,$354a,$6e94,$7fff
	
; ================================================================
; FX Hammer
; ================================================================

include	"FXHammer.asm"
