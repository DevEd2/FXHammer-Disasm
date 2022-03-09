; Disassembly of Aleksi Eeben's FX Hammer SFX player

section	"FX Hammer RAM",wram0

FXHammerRAM:		ds	6
; Bit 2: Ch3 reserved for playing a sample trigged in music data (1 = yes, 0 = no)
; Bit 1: Ch3 reserved for sound FX routines (1 = yes, 0 = no)
; Bit 0: Ch3 music note playing (1 = no, 0 = yes)
; When Ch3Flags is not $00, no instrument sound data is read and all Ch3 sound registers (rNR3x) remain intact.
Ch2Flags			equ	0
; Bit 1: Ch4 reserved for sound FX routines (1 = yes, 0 = no)
; Bit 0: Ch4 music note playing (1 = no, 0 = yes)
; When Ch4Flags is not $00, no instrument sound data is read and all Ch4 sound registers (rNR4x) remain intact.
Ch4Flags			equ	1
; FX Hammer: Priority of current Sound FX playing ($00 = lowest)
FXCurrentPri		equ	2
; FX Hammer: Countdown (in frames) before moving to next step in Sound FX
FXSoundCount		equ	3
; FX Hammer: Current Step
FXSoundP			equ	4
; FX Hammer: Current Sound FX (FX number + $44)
FXSoundH			equ 5

; A step is described in 8 bytes:
; TIME/END (TM)
; CH2/P_EV (P)
; CH2/_LEV (L)
; CH2/PWDT (W)
; CH2/NOTE (NT)
; CH4/P_EV (P)
; CH4/_LEV (L)
; CH4/FRQD (FR)

FXHammerBank		equ	1

FXHammerData		equ	$4200

section	"FX Hammer",romx,bank[FXHammerBank]

SoundFX_Trig:
	jp	FXHammer_Trig	; $404a
SoundFX_Stop:
	jp	FXHammer_Stop	; $4073
SoundFX_Update:
	jp	FXHammer_Update	; $409c
	
; thumbprint (this could be removed to save space)
	db	"FX HAMMER Version 1.0 (c)2000 Aleksi Eeben (email:aleksi@cncd.fi)"
	
; FX number in a
FXHammer_Trig:
	ld	e,a
	ld	d,high(FXHammerData)
	ld	hl,FXHammerRAM+FXCurrentPri
	ld	a,[de]
	cp	[hl]
	jr	z,.sameprio
	; [hl] > a
	ret	c
.sameprio:
	; store prio
	ld	[hl],a
	; +0x100
	inc	d
	ld	a,[de]
	swap	a
	and	$f
	ld	l,low(FXHammerRAM+Ch2Flags)
	or	[hl]
	ld	[hl],a
	ld	a,[de]
	and	$f
	ld	l,low(FXHammerRAM+Ch4Flags)
	or	[hl]
	ld	[hl],a
	ld	l,low(FXHammerRAM+FXSoundCount)
	; trigger step on next update
	ld	a,1
	ld	[hl+],a
	; FXHammerRAM+FXSoundP
	xor	a
	ld	[hl+],a
	ld	a,$44
	; e is FX number
	add	e
	ld	[hl],a
	ret
	
FXHammer_Stop:
	ld	hl,FXHammerRAM+Ch2Flags
	bit	1,[hl]
	; no sound playing
	jr	z,.skip_ch2
	ld	a,$08
	ldh	[rNR22],a
	ld	a,$80
	ldh	[rNR24],a
	ld	[hl],1
.skip_ch2:
	ld	l,low(FXHammerRAM+Ch4Flags)
	; turn off music note (inverted bit)
	set	0,[hl]
	bit	1,[hl]
	; no sound playing
	jr	z,.skip_ch4
	ld	a,$08
	ldh	[rNR42],a
	ld	a,$80
	ldh	[rNR44],a
	ld	[hl],1
.skip_ch4:
	ld	l,low(FXHammerRAM+FXCurrentPri)
	xor	a
	ld	[hl+],a
	; FXHammerRAM+FXSoundCount
	ld	[hl],a
	ret
	
; progress a frame
FXHammer_Update:
	xor	a
	ld	hl,FXHammerRAM+FXSoundCount
	or	[hl]
	; ret == 0
	ret	z
	dec	[hl]
	; ret != 1
	ret	nz
	inc	l
	ld	a,[hl+]
	; FXHammerRAM+FXSoundP
	; de = pointer
	ld	d,[hl]
	ld	e,a
	; pointer+0
	; TIME/END (TM)
	; $80 is knee
	ld	a,[de]
	ld	l,low(FXHammerRAM+FXSoundCount)
	ld	[hl-],a
	or	a
	jr	nz,.keepprio
	; FXHammerRAM+FXCurrentPri
	; Prio is reset on last step
	ld	[hl],a
.keepprio:
	ld	l,low(FXHammerRAM+Ch2Flags)
	bit	1,[hl]
	; already music on channel 2
	jr	z,.skip_ch2
	inc	e
	; pointer+1
	; CH2/PLEV (P)
	; 0x22, 0x20, 0x02 or 0x00
	ld	a,[de]
	or	a
	jr	nz,.notmute_ch2
	ld	[hl],1
	; disable envelope
	ld	a,$08
	ldh	[rNR22],a
	; restart sound
	ld	a,$80
	ldh	[rNR24],a
	jr	.skip_ch2mute
.notmute_ch2:
	ld	b,a
	; Pan
	ldh	a,[rNR51]
	and	$dd
	or	b
	ldh	[rNR51],a
	inc	e
	; pointer+2
	; CH2/PLEV (L)
	; 0x00, 0x10 ... 0xF0
	ld	a,[de]
	ldh	[rNR22],a
	inc	e
	; pointer+3
	; CH2/PWDT (W)
	ld	a,[de]
	ldh	[rNR21],a
	inc	e
	; pointer+4
	; CH2/NOTE (NT)
	ld	a,[de]
	ld	b,high(FXHammerData)
	ld	c,a
	; bc = pointer to note
	ld	a,[bc]
	ldh	[rNR23],a
	inc	c
	ld	a,[bc]
	ldh	[rNR24],a
	jr	.noskip
	; skip pointer by four
	; aka skip channel 2
.skip_ch2:
	inc	e
.skip_ch2mute:
	inc	e
	inc	e
	inc	e
.noskip:
	ld	l,low(FXHammerRAM+Ch4Flags)
	bit	1,[hl]
	; already music on channel 4
	jr	z,.skip_ch4
	inc	e
	; pointer+5
	; CH4/PLEV (P)
	; 0x88, 0x80, 0x08 or 0x00
	ld	a,[de]
	or	a
	jr	nz,.notmute_ch4
	ld	[hl],1
	ld	a,$08
	ldh	[rNR42],a
	ld	a,$80
	ldh	[rNR44],a
	jr	.skip_ch4
.notmute_ch4:
	ld	b,a
	; Pan
	ldh	a,[rNR51]
	and	$77
	or	b
	ldh	[rNR51],a
	inc	e
	; pointer+6
	; CH4/PLEV (L)
	; 0x00, 0x10 ... 0xF0
	ld	a,[de]
	ldh	[rNR42],a
	inc	e
	; pointer+7
	; CH4/FRQD (FR)
	ld	a,[de]
	ldh	[rNR43],a
	ld	a,$80
	ldh	[rNR44],a
	inc	e
	ld	l,low(FXHammerRAM+FXSoundP)
	; set pointer to next step
	ld	[hl],e
	ret
.skip_ch4:
	ld	l,low(FXHammerRAM+FXSoundP)
	ld	a,8
	add	[hl]
	; set pointer to next step
	ld	[hl],a
	ret
	
section	"FXHammer data",romx[FXHammerData],bank[FXHammerBank]
	; To get sound data, open hammered.sav and copy everything from $200-$3FFF into SoundData.bin.
	incbin	"SoundData.bin"
