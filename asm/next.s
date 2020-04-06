;-------------------------------------------------------------------------
; Name: next.s
;-------------------------------------------------------------------------
; Author: Steve Monks
;-------------------------------------------------------------------------
; Description:
; This contains a chunk of code that configures the Next hardware
; ready for our game. It configures the following hardware systems that
; our game uses;
; * CPU speed
; * Sprites
; * Tilemap
;
; Once complete it passes control to the game logic.
;-------------------------------------------------------------------------


; *****************************************************
; System initialisation
; *****************************************************
    nextreg TURBO_MODE_PORT, $2       ; cpu to 14 mhz, although this game would run happily at 3.5MHz

    ; clear ULA attribute map to black on black, this will hide
    ; anything on the standard Spectrum screen
    ld hl,16384+6144
    ld bc,768
SetAttr:
    sub a,a
    ld (hl),a
    dec bc
    ld a,b
    or a,c
    jr nz,SetAttr



; *****************************************************
; sprite setup
; *****************************************************
    nextreg SPRITE_LAYERS_CONTROL_PORT,%00000001 ; enable sprites

    ; set sprite clipping
    nextreg SPRITE_CLIP_PORT, 0     ; x1
    nextreg SPRITE_CLIP_PORT, 255   ; x2
    nextreg SPRITE_CLIP_PORT, 0     ; y1
    nextreg SPRITE_CLIP_PORT, 191   ; y2


    ; copy sprite patterns from regular memory into sprite pattern memory

    ld bc,SPRITE_SLOT_PORT          ; hardware register to select sprite index and pattern index
    sub a,a
    out (bc),a                      ; select pattern to write to

    ld hl, game_sprites             ; base address of sprite patterns in memory (see gamesprites.s for definition)
    ld bc, SPRITE_PATTERN_PORT      ; we need to write each byte of the pattern to this port in order
    ld de,gamesprites_count*128     ; each sprite is 128 bytes in size
SetSpritePatternLoop:
    ld a,(hl)
    inc hl
    out(bc),a
    dec de
    ld a,e
    or a,d
    jr nz,SetSpritePatternLoop

    ; set up hardware ready to copy sprite palette
    nextreg SPRITE_TRANS_PORT,0                             ; colour ix 0 is the transparent colour
    nextreg PALETTE_CONTROL_PORT,PALETTE_SELECT_SPRITE_1    ; select palette to edit
    nextreg PALETTE_INDEX_PORT,0                            ; select index to edit

    ; copy the sprite palette from memory to the hardware palette
    ld b,16                                 ; our palette contains 16 RRRGGGBB encoded colours
    ld hl,gamesprites_palette
SpritePalLp:
    ld a,(hl)
    inc hl
    nextreg PALETTE_VALUE_PORT, a           ; write colour to hardware palette slot
    djnz SpritePalLp


; *****************************************************
; tilemap setup
; *****************************************************

;    Layer2SelectBank(0,0)  ; disable layer 2 as it draws over the tilemap

    nextreg TILEMAP_CONTROL_PORT,TILEMAP_40_NOATTR  ; configure tilemap as 40 column byte per tile (no attribute bytes)
    nextreg TILEMAP_ATTR_PORT,$0                    ; set global tile attr (using 8 bit rather than 16 bit tiles)
    nextreg TILEMAP_TRANSPARENCY_PORT,$0            ; select palette entry 0 as the transparent colour
    nextreg TILEMAP_ULA_CONTROL_PORT,$0             ; ULA enabled and ULA/Sprite blend mode

    ; configure tilemap clipping
    nextreg TILEMAP_CLIP_PORT,16            ; left
    nextreg TILEMAP_CLIP_PORT,143           ; right 
    nextreg TILEMAP_CLIP_PORT,32            ; top
    nextreg TILEMAP_CLIP_PORT,223           ; bottom

    ; set the tilemap hardware to point to our memory buffer
    ; (see tile_map_data defined in candm.asm)
    nextreg TILEMAP_BASE_ADDR_PORT,tile_map_data/256

    ; point tilemap hardware at our tile patterns in memory
    ; (see tile_map_patterns defined in candm.asm)
    nextreg TILEMAP_PATTERN_BASE_ADDR_PORT,tile_map_patterns/256

    ; Horizontal scroll range, 0-320.
    ; The tilemap normally begins 32 pixels above and to the left of the ULA
    ; screen as it's 320x256 pixels compared to the ULA screen which is 256x192.
    ; We want to compensate for this, so we need to scroll in the X by
    ; 320-32 = 288. The X scroll register is 16 bits split over two 8 bit ports,
    ; so in hex, 288 = $0120
    nextreg TILEMAP_OFFSET_X_MSB_PORT,$01
    nextreg TILEMAP_OFFSET_X_LSB_PORT,$20

    ; The Y scroll is simpler as it's just an 8 bit port
    nextreg TILEMAP_OFFSET_Y_PORT,-32

    ; set up a tilemap palette
    nextreg PALETTE_CONTROL_PORT, PALETTE_SELECT_TILEMAP_1   ; select palette to edit
    nextreg PALETTE_INDEX_PORT,0                            ; select index to edit

    ; send the tilemap palette colours to the hardware
    ld c,16
    ld hl,glyph_palette
TMPalLp:
    ld a,(hl)
    inc hl
    nextreg PALETTE_VALUE_PORT, a           ; write colour to palette slot
    djnz TMPalLp

    call ClearTileMap

    ; ** Start the game **
    jp GameLogic

