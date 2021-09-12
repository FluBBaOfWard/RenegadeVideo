;@ ASM header for the Renegade Video emulator
;@

/** \brief  Game screen height in pixels */
#define GAME_HEIGHT (232)
/** \brief  Game screen width in pixels */
#define GAME_WIDTH  (256)

	.equ CHRSRCTILECOUNTBITS,	10
	.equ CHRDSTTILECOUNTBITS,	9
	.equ CHRGROUPTILECOUNTBITS,	3
	.equ CHRBLOCKCOUNT,			(1<<(CHRSRCTILECOUNTBITS - CHRGROUPTILECOUNTBITS))
	.equ CHRTILESIZEBITS,		4

	.equ BGRSRCTILECOUNTBITS,	13
	.equ BGRDSTTILECOUNTBITS,	10
	.equ BGRGROUPTILECOUNTBITS,	3
	.equ BGRBLOCKCOUNT,			(1<<(BGRSRCTILECOUNTBITS - BGRGROUPTILECOUNTBITS))
	.equ BGRTILESIZEBITS,		5

	.equ SPRSRCTILECOUNTBITS,	14
	.equ SPRDSTTILECOUNTBITS,	10
	.equ SPRGROUPTILECOUNTBITS,	3
	.equ SPRBLOCKCOUNT,			(1<<(SPRSRCTILECOUNTBITS - SPRGROUPTILECOUNTBITS))
	.equ SPRTILESIZEBITS,		5

	reptr		.req r12
						;@ RenegadeVideo.s
	.struct 0
scanline:		.long 0			;@ These 3 must be first in state.
nextLineChange:	.long 0
lineState:		.long 0

frameIrqFunc:	.long 0
periodicIrqFunc:.long 0
latchIrqFunc:	.long 0

rVideoState:					;@
rVideoRegs:						;@ 0-7
scrollXReg:		.short 0		;@
latchReg:		.byte 0			;@
flipReg:		.byte 0			;@ 
mcuReg:			.byte 0			;@
bankReg:		.byte 0			;@
ackFrameReg:	.byte 0			;@
ackPeriodReg:	.byte 0			;@

oldScrollX:		.short 0
padding0:		.space 2

gfxMemReload:
chrMemReload:	.byte 0
bgrMemReload:	.byte 0
sprMemReload:	.byte 0
padding1:		.space 1

chrMemAlloc:	.long 0
bgrMemAlloc:	.long 0
sprMemAlloc:	.long 0

chrRomBase:		.long 0
chrGfxDest:		.long 0
bgrRomBase:		.long 0
bgrGfxDest:		.long 0
spriteRomBase:	.long 0

dirtyMap:		.byte 0,0,0,0,0,0,0,0
gfxRAM:			.long 0
chrBlockLUT:	.long 0
bgrBlockLUT:	.long 0
sprBlockLUT:	.long 0

renegadeVideoSize:

;@----------------------------------------------------------------------------
