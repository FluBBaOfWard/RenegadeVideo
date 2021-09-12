// Renegade Video Chip emulation

#ifndef RENEGADEVIDEO_HEADER
#define RENEGADEVIDEO_HEADER

#ifdef __cplusplus
extern "C" {
#endif

/** \brief  Game screen height in pixels */
#define GAME_HEIGHT (232)
/** \brief  Game screen width in pixels */
#define GAME_WIDTH  (256)

typedef struct {
	u32 scanline;
	u32 nextLineChange;
	u32 lineState;

	void *frameIrqFunc;
	void *periodicIrqFunc;
	void *latchIrqFunc;

//renegadeVState:

//renegadeVRegs:					// 0-7
	u16 scrollXReg;				// Scroll X
	u8 latchReg;				// Sound latch
	u8 flipReg;					// Flip screen
	u8 mcuReg;					// Write to MCU
	u8 bankReg;					// Bankswitch
	u8 ackFrameReg;				// Acknowledge frame irq
	u8 ackPeriodReg;			// Acknowledge periodic irq

	u16 oldScrollX;				// Old scroll X
	u8 padding0[2];

	u8 chrMemReload;
	u8 bgrMemReload;
	u8 sprMemReload;
	u8 padding1;

	u32 chrMemAlloc;
	u32 bgrMemAlloc;
	u32 sprMemAlloc;

	u32 *chrRomBase;
	u32 *chrGfxDest;
	u32 *bgrRomBase;
	u32 *bgrGfxDest;
	u32 *spriteRomBase;

	u8 dirtyMap[8];
	u8 *gfxRAM;
	u32 *chrBlockLUT;
	u32 *bgrBlockLUT;
	u32 *sprBlockLUT;
} RenegadeVideo;

void renegadeVideoReset(void *frameIrqFunc(), void *periodicIrqFunc(), void *latchIrqFunc(), void *ram);

/**
 * Saves the state of the RenegadeVideo chip to the destination.
 * @param  *destination: Where to save the state.
 * @param  *chip: The RenegadeVideo chip to save.
 * @return The size of the state.
 */
int renegadeSaveState(void *destination, const RenegadeVideo *chip);

/**
 * Loads the state of the RenegadeVideo chip from the source.
 * @param  *chip: The RenegadeVideo chip to load a state into.
 * @param  *source: Where to load the state from.
 * @return The size of the state.
 */
int renegadeLoadState(RenegadeVideo *chip, const void *source);

/**
 * Gets the state size of a RenegadeVideo chip.
 * @return The size of the state.
 */
int renegadeGetStateSize(void);

void convertChrTileMap(void *destination);
void convertBgrTileMap(void *destination);
void convertSpritesRenegade(void *destination);
void doScanline(void);

#ifdef __cplusplus
}
#endif

#endif // RENEGADEVIDEO_HEADER
