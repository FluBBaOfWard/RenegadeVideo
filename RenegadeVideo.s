// Renegade Video Chip emulation

#ifdef __arm__

#ifdef GBA
#include "../Shared/gba_asm.h"
#elif NDS
#include "../Shared/nds_asm.h"
#endif
#include "../Shared/EmuSettings.h"
#include "RenegadeVideo.i"

	.global reVideoInit
	.global reVideoReset
	.global renegadeSaveState
	.global renegadeLoadState
	.global renegadeGetStateSize
	.global doScanline
	.global copyScrollValues
	.global convertChrTileMap
	.global convertBgrTileMap
	.global convertSpritesRenegade
	.global reLatchR
	.global reIOWrite


	.syntax unified
	.arm

	.section .text
	.align 2
;@----------------------------------------------------------------------------
reVideoInit:		;@ Only need to be called once
;@----------------------------------------------------------------------------
	mov r1,#0xffffff00		;@ Build bgr/spr tile decode tbl
	ldr r2,=CHR_DECODE2
ppi0:
	and r0,r1,#0x01
	tst r1,#0x02
	orrne r0,r0,#0x0010
	tst r1,#0x04
	orrne r0,r0,#0x0100
	tst r1,#0x08
	orrne r0,r0,#0x1000
	tst r1,#0x10
	orrne r0,r0,#0x0002
	tst r1,#0x20
	orrne r0,r0,#0x0020
	tst r1,#0x40
	orrne r0,r0,#0x0200
	tst r1,#0x80
	orrne r0,r0,#0x2000
	str r0,[r2],#4
	adds r1,r1,#1
	bne ppi0

	mov r1,#0xffffffc0		;@ Build fgr tile decode tbl
	ldr r2,=CHR_DECODE1
ppi1:
	and r0,r1,#0x01
	tst r1,#0x02
	orrne r0,r0,#0x10
	tst r1,#0x04
	orrne r0,r0,#0x02
	tst r1,#0x08
	orrne r0,r0,#0x20
	tst r1,#0x10
	orrne r0,r0,#0x04
	tst r1,#0x20
	orrne r0,r0,#0x40
;@	tst r1,#0x40
;@	orrne r0,r0,#0x08
;@	tst r1,#0x80
;@	orrne r0,r0,#0x80
	strb r0,[r2],#1
	adds r1,r1,#1
	bne ppi1

	bx lr
;@----------------------------------------------------------------------------
reVideoReset:		;@ r0=frameIrqFunc, r1=periodicIrqFunc, r2=latchIrqFunc, r3=RAM+remap mem
;@----------------------------------------------------------------------------
	stmfd sp!,{r0-r3,lr}

	mov r0,reptr
	ldr r1,=renegadeVideoSize/4
	bl memclr_						;@ Clear VDP state

	ldr r2,=lineStateTable
	ldr r1,[r2],#4
	mov r0,#-1
	stmia reptr,{r0-r2}				;@ Reset scanline, nextChange & lineState

//	mov r0,#-1
	str r0,[reptr,#gfxMemReload]

	ldmfd sp!,{r0-r3,lr}
	cmp r0,#0
	adreq r0,dummyIrqFunc
	cmp r1,#0
	adreq r1,dummyIrqFunc
	cmp r2,#0
	adreq r2,dummyIrqFunc
	str r0,[reptr,#frameIrqFunc]
	str r1,[reptr,#periodicIrqFunc]
	str r2,[reptr,#latchIrqFunc]

	str r3,[reptr,#gfxRAM]
	add r3,r3,#0x3200
	str r3,[reptr,#chrBlockLUT]
	add r3,r3,#CHRBLOCKCOUNT*4
	str r3,[reptr,#bgrBlockLUT]
	add r3,r3,#BGRBLOCKCOUNT*4
	str r3,[reptr,#sprBlockLUT]

dummyIrqFunc:
	bx lr

;@----------------------------------------------------------------------------
renegadeSaveState:			;@ In r0=destination, r1=reptr. Out r0=state size.
	.type   renegadeSaveState STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,r5,lr}
	mov r4,r0					;@ Store destination
	mov r5,r1					;@ Store reptr (r1)

	ldr r1,[r5,#gfxRAM]
	mov r2,#0x3200
	bl memcpy

	add r0,r4,#0x3200
	add r1,r5,#rVideoRegs
	mov r2,#0x08
	bl memcpy

	ldmfd sp!,{r4,r5,lr}
	ldr r0,=0x3208
	bx lr
#ifdef GBA
	.section .ewram,"ax"
#endif
;@----------------------------------------------------------------------------
renegadeLoadState:			;@ In r0=reptr, r1=source. Out r0=state size.
	.type   renegadeLoadState STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,r5,lr}
	mov r5,r0					;@ Store reptr (r0)
	mov r4,r1					;@ Store source

	ldr r0,[r5,#gfxRAM]
	mov r2,#0x3200
	bl memcpy

	add r0,r5,#rVideoRegs
	add r1,r4,#0x3200
	mov r2,#0x08
	bl memcpy

	mov r0,#-1
	str r0,[r5,#gfxMemReload]
	ldrb r0,[r5,#bankReg]
	bl bankSwitchW
	mov reptr,r5				;@ Restore reptr (r12)
	bl endFrame

	ldmfd sp!,{r4,r5,lr}
;@----------------------------------------------------------------------------
renegadeGetStateSize:	;@ Out r0=state size.
	.type   renegadeGetStateSize STT_FUNC
;@----------------------------------------------------------------------------
	ldr r0,=0x3208
	bx lr

;@----------------------------------------------------------------------------
reLatchR:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	mov r0,#0
	mov lr,pc
	ldr pc,[reptr,#latchIrqFunc]
	ldrb r0,[reptr,#latchReg]
	ldmfd sp!,{lr}
	bx lr

;@----------------------------------------------------------------------------
reIOWrite:				;@ r0=val, r1=IO adr
;@----------------------------------------------------------------------------
	cmp r1,#8
	addmi r2,reptr,#rVideoRegs
	strbmi r0,[r2,r1]
	ldrmi pc,[pc,r1,lsl#2]
;@---------------------------
	b empty_IO_W
;@ io_write_tbl
	.long scrollX1W			;@ 0x3800
	.long scrollX2W			;@ 0x3801
	.long soundLatchW		;@ 0x3802
	.long flipW				;@ 0x3803
	.long MCU04_W			;@ 0x3804
	.long bankSwitchW		;@ 0x3805
	.long ackFrameW			;@ 0x3806
	.long ackPeriodicW		;@ 0x3807
;@----------------------------------------------------------------------------
scrollX1W:				;@ Register 0
;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
scrollX2W:				;@ Register 1
;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
mcuW:					;@ Register 4
;@----------------------------------------------------------------------------
	bx lr
;@----------------------------------------------------------------------------
soundLatchW:			;@ Register 2
;@----------------------------------------------------------------------------
	mov r0,#1
	ldr pc,[reptr,#latchIrqFunc]
;@----------------------------------------------------------------------------
flipW:					;@ Register 3
;@----------------------------------------------------------------------------
//	tst r0,#0x01			;@ Screen flip bit
	mov r0,#0
	str r0,[reptr,#dirtyMap]
	str r0,[reptr,#dirtyMap+4]
	bx lr
;@----------------------------------------------------------------------------
bankSwitchW:			;@ Register 5
;@----------------------------------------------------------------------------
	stmfd sp!,{r3,lr}

	and r3,r0,#1
	mov r1,r3,lsl#1
	mov r0,#0x4
	bl m6502Mapper0

	mov r1,r3,lsl#1
	add r1,r1,#1
	mov r0,#0x8
	bl m6502Mapper0

	ldmfd sp!,{r3,pc}
;@----------------------------------------------------------------------------
ackFrameW:				;@ Register 6
;@----------------------------------------------------------------------------
	mov r0,#0
	ldr pc,[reptr,#frameIrqFunc]
;@----------------------------------------------------------------------------
ackPeriodicW:			;@ Register 7
;@----------------------------------------------------------------------------
	mov r0,#0
	ldr pc,[reptr,#periodicIrqFunc]

;@----------------------------------------------------------------------------
reloadChrTiles:
;@----------------------------------------------------------------------------
	mov r0,#0
	strb r0,[reptr,#dirtyMap+3]
	mov r0,#1<<(CHRDSTTILECOUNTBITS-CHRGROUPTILECOUNTBITS)
	str r0,[reptr,#chrMemAlloc]
	mov r1,#1<<(32-CHRGROUPTILECOUNTBITS)		;@ r1=value
	strb r1,[reptr,#chrMemReload]	;@ Clear bg mem reload.
	mov r0,r9					;@ r0=destination
	mov r2,#CHRBLOCKCOUNT		;@ 512 tile entries
	b memset_					;@ Prepare LUT
;@----------------------------------------------------------------------------
convertChrTileMap:			;@ r0 = destination
;@----------------------------------------------------------------------------
	stmfd sp!,{r3-r11,lr}
	add r6,r0,#64				;@ Destination + skip first row

	ldr r9,[reptr,#chrBlockLUT]
	ldrb r0,[reptr,#chrMemReload]
	cmp r0,#0
	blne reloadChrTiles

	ldrb r0,[reptr,#dirtyMap+3]	;@ Check dirty map
	eors r0,r0,#0xFF
	ldmfdeq sp!,{r3-r11,pc}
	strb r0,[reptr,#dirtyMap+3]

	ldr r4,[reptr,#gfxRAM]
	add r4,r4,#0x1800			;@ Chr map offset
	add r4,r4,#32				;@ Skip first row
	mov r8,#29					;@ Row count to render
	mov r7,#0x80				;@ Palette offset
	mov r10,#1

	ldrb r0,[reptr,#flipReg]
	tst r0,#1
	moveq r10,#-1
	orreq r7,r7,#0x0C
	addeq r4,r4,#32*29			;@ Start from bottom
	subeq r4,r4,#1

	bl chrMapRender
	ldmfd sp!,{r3-r11,pc}

;@----------------------------------------------------------------------------
reloadBGTiles:
;@----------------------------------------------------------------------------
	mov r0,#0
	strb r0,[reptr,#dirtyMap+5]
	mov r0,#1<<(BGRDSTTILECOUNTBITS-BGRGROUPTILECOUNTBITS)
	str r0,[reptr,#bgrMemAlloc]
	mov r1,#1<<(32-BGRGROUPTILECOUNTBITS)		;@ r1=value
	strb r1,[reptr,#bgrMemReload]	;@ Clear bg mem reload.
	mov r0,r9					;@ r0=destination
	mov r2,#BGRBLOCKCOUNT		;@ 512 tile entries
	b memset_					;@ Prepare LUT
;@----------------------------------------------------------------------------
convertBgrTileMap:			;@ r0 = destination
;@----------------------------------------------------------------------------
	stmfd sp!,{r3-r11,lr}
	mov r6,r0					;@ Destination

	ldr r9,[reptr,#bgrBlockLUT]
	ldrb r0,[reptr,#bgrMemReload]
	cmp r0,#0
	blne reloadBGTiles

	ldr r4,[reptr,#gfxRAM]
	add r4,r4,#0x2800
	ldrh r7,[reptr,#scrollXReg]
	add r7,r7,#8
	mov r7,r7,lsr#4				;@ Just keep tile x index
	ldrh r0,[reptr,#oldScrollX]
	eors r0,r0,r7
	strhne r7,[reptr,#oldScrollX]
	bne updateBG

	ldrb r0,[reptr,#dirtyMap+5]	;@ Check dirty map
	eors r0,r0,#0xFF
	ldmfdeq sp!,{r3-r11,pc}
updateBG:
	mov r0,#0xFF
	strb r0,[reptr,#dirtyMap+5]

	ldrb r0,[reptr,#flipReg]
	tst r0,#0x01				;@ Screen flip bit
//	bne flippedTileMap

	sub r7,r7,#0x10
//	ldr r3,=0x20000008			;@ Row modulo + tile vs color map offset
	mov r11,#0x01000000			;@ Increase read
	bl bgrMapRender
noChange:
	ldmfd sp!,{r3-r11,pc}

flippedTileMap:
//	ldr r3,=0xE0000008			;@ Row modulo + tile vs color map offset
	ldr r11,=0xFF000C00			;@ Decrease read, XY-flip
//	add r4,r4,#0x400			;@ From bottom
	bl bgrMapRender
	ldmfd sp!,{r3-r11,pc}

;@----------------------------------------------------------------------------
checkFrameIRQ:
;@----------------------------------------------------------------------------
	ldr r0,=g_dipSwitch2
	ldrb r1,[r0]
	orr r1,r1,#0x40					;@ VBL flag
	strb r1,[r0]
	mov r0,#1
	ldr pc,[reptr,#frameIrqFunc]
;@----------------------------------------------------------------------------
periodicIRQ:
;@----------------------------------------------------------------------------
	mov r0,#1
	ldr pc,[reptr,#periodicIrqFunc]
;@----------------------------------------------------------------------------
frameEndHook:
	ldr r2,=lineStateTable
	ldr r1,[r2],#4
	mov r0,#0
	stmia reptr,{r0-r2}				;@ Reset scanline, nextChange & lineState

//	mov r0,#0						;@ Must return 0 to end frame.
	ldmfd sp!,{pc}

;@----------------------------------------------------------------------------
newFrame:					;@ Called before line 0
;@----------------------------------------------------------------------------

	ldr r0,=g_dipSwitch2
	ldrb r1,[r0]
	bic r1,r1,#0x40					;@ VBL flag
	strb r1,[r0]
	bx lr

;@----------------------------------------------------------------------------
lineStateTable:
	.long 0, newFrame				;@ zeroLine
	.long 120, periodicIRQ			;@ periodicIRQ on
	.long 238, endFrame				;@ Last visible scanline
	.long 240, checkFrameIRQ		;@ frameIRQ on
	.long 272, frameEndHook			;@ totalScanlines
;@----------------------------------------------------------------------------
;@ Code in fastmem.
;@----------------------------------------------------------------------------
#ifdef NDS
	.section .itcm						;@ For the NDS
#elif GBA
	.section .iwram, "ax", %progbits	;@ For the GBA
#else
	.section .text
#endif
	.align 2
;@----------------------------------------------------------------------------
line0Ret:
	ldmfd sp!,{lr}
;@----------------------------------------------------------------------------
doScanline:
;@----------------------------------------------------------------------------
	ldmia reptr,{r1,r2}			;@ Read scanLine & nextLineChange
	subs r0,r1,r2
	addmi r1,r1,#1
	strmi r1,[reptr,#scanline]
	bxmi lr
;@----------------------------------------------------------------------------
redoScanline:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	ldr r2,[reptr,#lineState]
	ldmia r2!,{r0,r1}
	stmib reptr,{r1,r2}			;@ Write nextLineChange & lineState
	adr lr,line0Ret
	bx r0
;@----------------------------------------------------------------------------
bgrMapRender:
	stmfd sp!,{lr}

bgTrLoop2:
	mov r8,#16
bgTrLoop1:
	and r1,r7,#0x3f
	ldrb r0,[r1,r4]!			;@ Read from Renegade Tilemap RAM,  tttttttt
	ldrb r5,[r1,#0x400]			;@ Read from Renegade Colormap RAM, ccc??ttt -> 0ccc0ttt

	and r1,r5,#0x07
	orr r0,r0,r1,lsl#8

	and r5,r5,#0xE0				;@ Color bits

	mov r0,r0,lsl#2				;@ Convert 16x16 tile nr to 8x8 tile nr.
	bl getTilesFromCache

	orr r0,r0,r5,lsl#7			;@ Palette

	orr r0,r0,#0x20000			;@ + next tile
	orr r0,r0,r0,lsl#16
	and r1,r7,#0x0f
	mov r1,r1,lsl#2
	str r0,[r1,r6]!				;@ Write to NDS Tilemap RAM
	add r0,r0,#0x10000
	add r0,r0,#0x00001
	str r0,[r1,#0x40]			;@ Write to NDS Tilemap RAM

	add r7,r7,#1
	subs r8,r8,#1
	bne bgTrLoop1

	add r7,r7,#64-16			;@ Modulo
	add r4,r4,#64				;@ Modulo to next row
	add r6,r6,#0x80
	tst r6,#0x780
	bne bgTrLoop2

	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
tileCacheFull:
	strb r2,[reptr,#bgrMemReload]
	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
getTilesFromCache:			;@ Takes tile# in r0, returns new tile# in r0
;@----------------------------------------------------------------------------
	mov r1,r0,lsr#BGRGROUPTILECOUNTBITS		;@ Mask tile number
	bic r0,r0,r1,lsl#BGRGROUPTILECOUNTBITS
	ldr r2,[r9,r1,lsl#2]		;@ Check cache, uncached = 0x10000000
	orrs r0,r0,r2,lsl#BGRGROUPTILECOUNTBITS
	bxcc lr						;@ Allready cached
allocTiles:
	ldr r2,[reptr,#bgrMemAlloc]
	subs r2,r2,#1
	bmi tileCacheFull
	str r2,[reptr,#bgrMemAlloc]

	str r2,[r9,r1,lsl#2]
	orr r0,r0,r2,lsl#BGRGROUPTILECOUNTBITS
;@----------------------------------------------------------------------------
renderTiles:
	stmfd sp!,{r0,r4-r8,lr}
	ldr r6,=CHR_DECODE2
	mov r7,#0xf
	mov r8,#0
#ifdef ARM9
	ldrd r4,r5,[reptr,#bgrRomBase]
#else
	ldr r4,[reptr,#bgrRomBase]
	ldr r5,[reptr,#bgrGfxDest]
#endif
	add r3,r4,r1,lsl#BGRGROUPTILECOUNTBITS+4
	add r3,r3,#0x10000
	add r0,r5,r2,lsl#BGRGROUPTILECOUNTBITS+5

	movs r2,r1,lsr#8
	bic r1,r1,#0x80
	sub r1,r1,r2,lsl#7
	add r2,r4,r1,lsl#BGRGROUPTILECOUNTBITS+4
	movcs r8,#4

renderTilesLoop:
	ldrb r4,[r2],#1				;@ Read 3rd plane
	ldrb r5,[r3],#1				;@ Read 1st & 2nd plane
	and r4,r7,r4,lsr r8

	ldr r4,[r6,r4,lsl#2]
	ldr r5,[r6,r5,lsl#2]
	orr r1,r5,r4,lsl#2

	ldrb r4,[r2,#15]			;@ Read 3rd plane
	ldrb r5,[r3,#15]			;@ Read 1st & 2nd plane
	and r4,r7,r4,lsr r8

	ldr r4,[r6,r4,lsl#2]
	ldr r5,[r6,r5,lsl#2]
	orr r4,r5,r4,lsl#2
	orr r4,r1,r4,lsl#16
	str r4,[r0],#4

	tst r0,#0x3c
	bne renderTilesLoop

	add r2,r2,#16
	add r3,r3,#16
	tst r0,#0xc0				;@ #0x80 2 16x16 tiles
	bne renderTilesLoop

	ldmfd sp!,{r0,r4-r8,pc}

;@----------------------------------------------------------------------------
chrMapRender:
	stmfd sp!,{lr}

chrTrLoop1:
	ldrb r5,[r4,#0x400]			;@ Read from Renegade Colormap RAM, cc????tt -> 10cc00tt
	ldrb r0,[r4],r10			;@ Read from Renegade Charmap RAM,  tttttttt

	and r5,r5,#0xC3				;@ Mask used bits
	orr r5,r7,r5,ror#2
	orr r0,r0,r5,lsr#22

	bl getCharsFromCache

	orr r0,r0,r5,lsl#8			;@ Palette
	strh r0,[r6],#2				;@ Write to NDS Tilemap RAM

	tst r6,#0x03e
	bne chrTrLoop1

	subs r8,r8,#1
	bne chrTrLoop1

	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
charCacheFull:
	strb r2,[reptr,#chrMemReload]
	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
getCharsFromCache:			;@ Takes tile# in r0, returns new tile# in r0
;@----------------------------------------------------------------------------
	mov r1,r0,lsr#CHRGROUPTILECOUNTBITS		;@ Mask tile number
	bic r0,r0,r1,lsl#CHRGROUPTILECOUNTBITS
	ldr r2,[r9,r1,lsl#2]		;@ Check cache, uncached = 0x10000000
	orrs r0,r0,r2,lsl#CHRGROUPTILECOUNTBITS
	bxcc lr						;@ Allready cached
allocChars:
	ldr r2,[reptr,#chrMemAlloc]
	subs r2,r2,#1
	bmi charCacheFull
	str r2,[reptr,#chrMemAlloc]

	str r2,[r9,r1,lsl#2]
	orr r0,r0,r2,lsl#CHRGROUPTILECOUNTBITS
;@----------------------------------------------------------------------------
renderChars:
	stmfd sp!,{r0,r4-r6,lr}
	ldr r6,=CHR_DECODE1
#ifdef ARM9
	ldrd r4,r5,[reptr,#chrRomBase]
#else
	ldr r4,[reptr,#chrRomBase]
	ldr r5,[reptr,#chrGfxDest]
#endif
	add r4,r4,r1,lsl#CHRGROUPTILECOUNTBITS+5
	add r5,r5,r2,lsl#CHRGROUPTILECOUNTBITS+5

renderCharsLoop:
	ldrb r0,[r4],#1				;@ Read 1st & 2nd pixel
	ldrb r1,[r4,#7]				;@ Read 3rd & 4th pixel
	ldrb r2,[r4,#15]			;@ Read 5th & 6th pixel
	ldrb r3,[r4,#23]			;@ Read 7th & 8th pixel

	ldrb r0,[r6,r0]
	ldrb r1,[r6,r1]
	ldrb r2,[r6,r2]
	ldrb r3,[r6,r3]
	orr r0,r0,r1,lsl#8
	orr r0,r0,r2,lsl#16
	orr r0,r0,r3,lsl#24

	str r0,[r5],#4

	tst r5,#0x1c
	bne renderCharsLoop

	add r4,r4,#24
	tst r5,#0xe0				;@ #0x80 8 8x8 tiles
	bne renderCharsLoop

	ldmfd sp!,{r0,r4-r6,pc}
;@----------------------------------------------------------------------------
copyScrollValues:			;@ r0 = destination
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r7}
	mov r3,#0x20
	ldrh r6,[reptr,#scrollXReg]

//	ldrb r7,[reptr,#flipReg]
//	tst r7,#0x01				;@ Screen flip bit
//	movne r7,#-1
//	moveq r7,#1
//	rsbne r6,r6,#0x1800
//	add r1,reptr,#1
//	addne r1,r1,#0x1F

	mov r5,r6
setScrlLoop:
	stmia r0!,{r5,r6}
	stmia r0!,{r5,r6}
	stmia r0!,{r5,r6}
	stmia r0!,{r5,r6}
	subs r3,r3,#1
	bne setScrlLoop

	ldmfd sp!,{r4-r7}
	bx lr

;@----------------------------------------------------------------------------
reloadSprites:
;@----------------------------------------------------------------------------
	mov r1,#1<<(32-SPRGROUPTILECOUNTBITS)	;@ r1=value
	strb r1,[reptr,#sprMemReload]			;@ Clear spr mem reload.
	mov r0,r9								;@ r0=destination
	mov r2,#SPRBLOCKCOUNT					;@ Number of tile entries
	b memset_								;@ Prepare LUT
;@----------------------------------------------------------------------------
	.equ PRIORITY,	0x800		;@ 0x800=AGB OBJ priority 2
;@----------------------------------------------------------------------------
convertSpritesRenegade:		;@ In r0 = destination.
;@----------------------------------------------------------------------------
	stmfd sp!,{r4-r11,lr}

	mov r11,r0					;@ Destination
	mov r8,#96					;@ Number of sprites
//	ldrb r0,[reptr,#scrollXReg+1]
//	tst r0,#0x80				;@ Sprites enabled?
//	beq dm7

	ldr r9,[reptr,#sprBlockLUT]
	ldrb r0,[reptr,#sprMemReload]
	cmp r0,#0
	blne reloadSprites

	ldr r10,[reptr,#gfxRAM]
	add r10,r10,#0x2000

	ldr r7,=gScaling
	ldrb r7,[r7]
	cmp r7,#UNSCALED			;@ Do autoscroll
	ldreq r7,=0x01000000		;@ No scaling
//	ldrne r7,=0x00DB6DB6		;@ 192/224, 6/7, scaling. 0xC0000000/0xE0 = 0x00DB6DB6.
//	ldrne r7,=0x00B6DB6D		;@ 160/224, 5/7, scaling. 0xA0000000/0xE0 = 0x00B6DB6D.
	ldrne r7,=(SCREEN_HEIGHT<<21)/(GAME_HEIGHT>>3)		;@ 192/240, 12/15, scaling. 0xC0000000/0xF0 = 0x00DB6DB6.
	mov r0,#0
	ldreq r0,=yStart			;@ first scanline?
	ldrbeq r0,[r0]
	add r6,r0,#0x08

//	mov r5,#0x40000000			;@ 16x16 size
	mov r5,#0x00000000			;@ 8x8 size
	orrne r5,r5,#0x0100			;@ Scaling

//	ldrb r4,[reptr,#irqControl]
//	tst r4,#0x08				;@ Flip enabled?
//	orrne r5,#0x30000000		;@ flips
//	rsbne r7,r7,#0
//	rsbne r6,r0,#0xE8

	add r10,r10,r8,lsl#2		;@ Begin with the last sprite
dm5:
	ldr r4,[r10,#-4]!			;@ Renegade OBJ, r4=Ypos,Attrib,Tile,Xpos.
	ands r0,r4,#0xFF			;@ Mask Y, check yPos 0
	beq skipSprite
	rsb r0,r0,#232				;@ Fix up Y
	tst r4,#0x8000				;@ Check Ysize
	addeq r0,r0,#16

	mov r1,r4,lsr#24			;@ XPos
	cmp r1,#248					;@ XPos
	eorpl r1,r1,#0x100
//	tst r7,#0x80000000			;@ Is scaling negative (flip)?
	sub r1,r1,#(GAME_WIDTH-SCREEN_WIDTH)/2
//	rsbne r1,r1,#(GAME_WIDTH-16)-(GAME_WIDTH-SCREEN_WIDTH)/2			;@ Flip Xpos
	mov r1,r1,lsl#23

	sub r0,r0,r6
	mul r0,r7,r0				;@ Y scaling
	sub r0,r0,#0x07800000		;@ -8, + 0.5
	add r0,r5,r0,lsr#24			;@ YPos + size + scaling
	orr r0,r0,r1,lsr#7			;@ XPos

	and r1,r4,#0xc000
	ldr r3,=flipSizeTable
	ldr r1,[r3,r1,lsr#12]
	orr r0,r0,r1
	str r0,[r11],#4				;@ store OBJ Atr 0,1. Xpos, ypos, flip, scale/rot, size, shape.

	and r1,r4,#0xFF0000
	and r0,r4,#0xF00
	orr r0,r0,r1,lsr#16
	mov r0,r0,lsl#2				;@ Convert 16x16 tile nr to 8x8 tile nr.
	bl getSpriteFromCache		;@ jump to spr copy, takes tile# in r0, gives new tile# in r0

	and r1,r4,#0x3000			;@ Color
	orr r0,r1,r0
	orr r0,r0,#PRIORITY			;@ Priority
	strh r0,[r11],#4			;@ Store OBJ Atr 2. Pattern, prio & palette.
dm3:
	subs r8,r8,#1
	bne dm5
	ldmfd sp!,{r4-r11,pc}
skipSprite:
	mov r0,#0x200+SCREEN_HEIGHT	;@ Double, y=SCREEN_HEIGHT
	str r0,[r11],#8
	b dm3

dm7:
	mov r0,#0x200+SCREEN_HEIGHT	;@ Double, y=SCREEN_HEIGHT
	str r0,[r11],#8
	subs r8,r8,#1
	bne dm7
	ldmfd sp!,{r4-r11,pc}

;@----------------------------------------------------------------------------
spriteCacheFull:
	strb r2,[reptr,#sprMemReload]
	mov r2,#1<<(SPRDSTTILECOUNTBITS-SPRGROUPTILECOUNTBITS)
	str r2,[reptr,#sprMemAlloc]
	ldmfd sp!,{r4-r11,pc}
;@----------------------------------------------------------------------------
getSpriteFromCache:			;@ Takes tile# in r0, returns new tile# in r0
;@----------------------------------------------------------------------------
	mov r1,r0,lsr#SPRGROUPTILECOUNTBITS
	bic r0,r0,r1,lsl#SPRGROUPTILECOUNTBITS
	ldr r2,[r9,r1,lsl#2]
	orrs r0,r0,r2,lsl#SPRGROUPTILECOUNTBITS		;@ Check cache, uncached = 0x20000000
	bxcc lr										;@ Allready cached
alloc16x16x2:
	ldr r2,[reptr,#sprMemAlloc]
	subs r2,r2,#1
	bmi spriteCacheFull
	str r2,[reptr,#sprMemAlloc]

	str r2,[r9,r1,lsl#2]
	orr r0,r0,r2,lsl#SPRGROUPTILECOUNTBITS
;@----------------------------------------------------------------------------
do16:
	stmfd sp!,{r0,r4-r8,lr}
	ldr r6,=CHR_DECODE2
	mov r7,#0xf
	mov r8,#0
	ldr r0,=SPRITE_GFX			;@ r0=GBA/NDS SPR tileset
	add r0,r0,r2,lsl#SPRGROUPTILECOUNTBITS+5	;@ x 128 bytes x 4 tiles

	ldr r2,[reptr,#spriteRomBase]
	add r3,r2,r1,lsl#SPRGROUPTILECOUNTBITS+4
	add r3,r3,#0x20000

	movs r4,r1,lsr#8
	bic r1,r1,#0x80
	sub r1,r1,r4,lsl#7
	add r2,r2,r1,lsl#SPRGROUPTILECOUNTBITS+4
	movcs r8,#4

spr16Loop:
	ldrb r4,[r2],#1				;@ Read 3rd plane
	ldrb r5,[r3],#1				;@ Read 1st & 2nd plane
	and r4,r7,r4,lsr r8

	ldr r4,[r6,r4,lsl#2]
	ldr r5,[r6,r5,lsl#2]
	orr r1,r5,r4,lsl#2

	ldrb r4,[r2,#15]			;@ Read 3rd plane
	ldrb r5,[r3,#15]			;@ Read 1st & 2nd plane
	and r4,r7,r4,lsr r8

	ldr r4,[r6,r4,lsl#2]
	ldr r5,[r6,r5,lsl#2]
	orr r4,r5,r4,lsl#2
	orr r4,r1,r4,lsl#16
	str r4,[r0],#4

	tst r0,#0x1c
	bne spr16Loop

	tst r0,#0x20
	addne r2,r2,#24
	addne r3,r3,#24
	bne spr16Loop

	tst r0,#0x40
	subne r2,r2,#32
	subne r3,r3,#32
	bne spr16Loop

	add r2,r2,#16
	add r3,r3,#16
	tst r0,#0x80				;@ Allways 2 16x16 tiles
	bne spr16Loop

	ldmfd sp!,{r0,r4-r8,pc}

;@----------------------------------------------------------------------------
flipSizeTable:	;@ Convert from Renegade spr to GBA/NDS obj.
;@	    nothing		xflip		height32	xflip+height32
	.long 0x40000000,0x50000000,0x80008000,0x90008000
;@----------------------------------------------------------------------------

	.section .sbss
CHR_DECODE1:
	.space 0x40
CHR_DECODE2:
	.space 0x400

#endif // #ifdef __arm__
