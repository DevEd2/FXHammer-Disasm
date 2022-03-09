; Disassembly of Aleksi Eeben's FX Hammer SFX player

section	"FX Hammer RAM",wram0

FXHammerRAM:		ds	6
FXHammer_SFXCH2		equ	0
FXHammer_SFXCH4		equ	1
FXHammer_prio		equ	2
FXHammer_cnt		equ	3
FXHammer_stepptr	equ	4 ; 2 bytes

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
	ld	hl,FXHammerRAM+FXHammer_prio
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
	ld	l,low(FXHammerRAM+FXHammer_SFXCH2)
	or	[hl]
	ld	[hl],a
	ld	a,[de]
	and	$f
	ld	l,low(FXHammerRAM+FXHammer_SFXCH4)
	or	[hl]
	ld	[hl],a
	ld	l,low(FXHammerRAM+FXHammer_cnt)
	; trigger step on next update
	ld	a,1
	ld	[hl+],a
	; FXHammerRAM+FXHammer_stepptr
	xor	a
	ld	[hl+],a
	ld	a,$44
	; e is FX number
	add	e
	ld	[hl],a
	ret
	
FXHammer_Stop:
	ld	hl,FXHammerRAM+FXHammer_SFXCH2
	bit	1,[hl]
	jr	z,.skip_ch2
	ld	a,$08
	ldh	[rNR22],a
	ld	a,$80
	ldh	[rNR24],a
	ld	[hl],1
.skip_ch2:
	ld	l,low(FXHammerRAM+FXHammer_SFXCH4)
	set	0,[hl]
	bit	1,[hl]
	jr	z,.skip_ch4
	ld	a,$08
	ldh	[rNR42],a
	ld	a,$80
	ldh	[rNR44],a
	ld	[hl],1
.skip_ch4:
	ld	l,low(FXHammerRAM+FXHammer_prio)
	xor	a
	ld	[hl+],a
	; FXHammerRAM+FXHammer_cnt
	ld	[hl],a
	ret
	
; progress a frame
FXHammer_Update:
	xor	a
	ld	hl,FXHammerRAM+FXHammer_cnt
	or	[hl]
	; ret == 0
	ret	z
	dec	[hl]
	; ret != 1
	ret	nz
	inc	l
	ld	a,[hl+]
	; FXHammerRAM+FXHammer_stepptr
	; de = pointer
	ld	d,[hl]
	ld	e,a
	; pointer+0
	; TIME/END (TM)
	ld	a,[de]
	ld	l,low(FXHammerRAM+FXHammer_cnt)
	ld	[hl-],a
	or	a
	jr	nz,.keepprio
	; FXHammerRAM+FXHammer_prio
	; Prio is reset on last step
	ld	[hl],a
.keepprio:
	ld	l,low(FXHammerRAM+FXHammer_SFXCH2)
	bit	1,[hl]
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
	ld	l,low(FXHammerRAM+FXHammer_SFXCH4)
	bit	1,[hl]
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
	ld	l,low(FXHammerRAM+FXHammer_stepptr)
	; set pointer to next step
	ld	[hl],e
	ret
.skip_ch4:
	ld	l,low(FXHammerRAM+FXHammer_stepptr)
	ld	a,8
	add	[hl]
	; set pointer to next step
	ld	[hl],a
	ret
	
section	"FXHammer data",romx[FXHammerData],bank[FXHammerBank]
	; To get sound data, open hammered.sav and copy everything from $200-$3FFF into SoundData.bin.
	incbin	"SoundData.bin"
