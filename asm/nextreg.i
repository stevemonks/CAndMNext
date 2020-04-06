;-------------------------------------------------------------------------
; Name: nextreg.i
;-------------------------------------------------------------------------
; Author: Steve Monks
;-------------------------------------------------------------------------
; Description:
; Declares register addresses and various constants relating to the
; ZX Spectrum Next hardware
;-------------------------------------------------------------------------

TURBO_MODE_PORT = $07               ; $0 = 3.5MHz, $1 = 7MHz, $2 = 14MHz, $3 = 28MHz (possibly, not documented)
PALETTE_INDEX_PORT = $40            ; write index for palette
PALETTE_VALUE_PORT = $41            ; r/w value of palette at current index
PALETTE_CONTROL_PORT = $43          ; bit 7 - disable palette write auto inc
PALETTE_SELECT_ULA_1     = %00000000
PALETTE_SELECT_ULA_2     = %01000000
PALETTE_SELECT_LAYER2_1  = %00010000
PALETTE_SELECT_LAYER2_2  = %01010000
PALETTE_SELECT_SPRITE_1  = %00100000
PALETTE_SELECT_SPRITE_2  = %01100000
PALETTE_SELECT_TILEMAP_1 = %00110000
PALETTE_SELECT_TILEMAP_2 = %01110000
PALETTE_USE_SPRITES      = %00001000    ; if 1, use 2nd palette
PALETTE_USE_LAYER2       = %00000100    ; if 1, use 2nd palette
PALETTE_USE_ULA          = %00000010    ; if 1, use 2nd palette
PALETTE_ENABLE_ULANEXT   = %00000001    ; if 1, use 2nd palette

LAYER2_ACCESS_PORT = $123b                  ; controls write access and enabling of layer2
LAYER2_ACCESS_DISABLE_BANK0 = %00000001     ; disable layer2 screen and select bank 0 for write
LAYER2_ACCESS_DISABLE_BANK1 = %01000001     ; disable layer2 screen and select bank 1 for write
LAYER2_ACCESS_DISABLE_BANK2 = %10000001     ; disable layer2 screen and select bank 2 for write

LAYER2_ACCESS_ENABLE_BANK0 = %00000011     ; enable layer2 screen and select bank 0 for write
LAYER2_ACCESS_ENABLE_BANK1 = %01000011     ; enable layer2 screen and select bank 1 for write
LAYER2_ACCESS_ENABLE_BANK2 = %10000011     ; enable layer2 screen and select bank 2 for write

LAYER2_SCROLL_X_PORT = $16          
LAYER2_SCROLL_Y_PORT = $17
LAYER2_CLIP_PORT = $18              ; write here to adjust clip window, 1st write=left, 2nd=right, 3rd=top, 4th=bottom

SPRITE_SLOT_PORT = $303b
SPRITE_LAYERS_CONTROL_PORT = $15
SPRITE_CLIP_PORT = $19              ; write here to adjust clip window, 1st write=left, 2nd=right, 3rd=top, 4th=bottom
SPRITE_NUMBER_PORT = $34
SPRITE_ATTR_PORT = $57
SPRITE_PATTERN_PORT = $5b
SPRITE_TRANS_PORT = $4b

TILEMAP_CLIP_PORT = $1b             ; write here to adjust clip window, 1st write=left, 2nd=right, 3rd=top, 4th=bottom
TILEMAP_CONTROL_PORT = $6b
TILEMAP_DISABLE = $0
TILEMAP_40_NOATTR = %10100000
TILEMAP_40_ATTR   = %10000000
TILEMAP_ULA_CONTROL_PORT = $68
TILEMAP_ATTR_PORT = $6c

TILEMAP_BASE_ADDR_PORT = $6e            ; base addr of tile map
TILEMAP_PATTERN_BASE_ADDR_PORT = $6f    ; base addr of tile patterns

TILEMAP_TRANSPARENCY_PORT = $4c

TILEMAP_OFFSET_X_MSB_PORT = $2f
TILEMAP_OFFSET_X_LSB_PORT = $30
TILEMAP_OFFSET_Y_PORT = $31

RAM_BANK_PORT = $04     ; bank paged into 0x0000-0x3fff

CLIP_CONTROL_PORT = $1c             ; bit 3 = reset tilemap clip ix, 2 = reset ula/lores clip ix, 1 = reset sprite clip ix, 0 = reset layer 2 clip ix

; selects the layer2 bank to write to and controls if layer 2 is enabled or not
; bank = 0 - 3, enable = 0,1
Layer2SelectBank macro(bank,enable)
                sub a,a
                ld a,bank   ; bank = 0,1,2,3 - rotate to bits 6,7
                rr a
                rr a
                rr a
                ld b,enable ; enable = 0,1, rotate to bit 1
                add a,b
                add a,b
                or a,1      ; set write bit
                ld bc, LAYER2_ACCESS_PORT
                out (c),a
                mend