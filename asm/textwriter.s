;-------------------------------------------------------------------------
; Name: textwriter.s
;-------------------------------------------------------------------------
; Author: Steve Monks
;-------------------------------------------------------------------------
; Description:
; Routines to display text using the tilemap. This currently uses a cut
; down ASCII font. The glyphs are in ASCII order but they're numerically
; offset from actual ASCII values due to the index in the tile pattern
; memory that they start at.
; tile 16 = ' '
; tile 17 = '0' $30
;-------------------------------------------------------------------------


; b = x
; c = y
; ix = text

RowAddr = tile_map_data

text_row_table:
    loop 32
    dw RowAddr
    RowAddr = RowAddr + 40
    lend


;-------------------------------------------------------------------------
; PrintText
;-------------------------------------------------------------------------
PrintText:
    push ix
    ld ix,text_row_table
    ld a,c
    add a,a
    ld e,a
    ld d,0
    add ix,de   ; ix points to y'th row in text_row_table
    ld l,(ix+0)
    ld h,(ix+1) ; hl points to y'th row in tile_map_data
    ld e,b
    add hl,de   ; hl points to x'th character in y'th row of tile_map_data
    pop de
PrintLoop:
    ld a,(de)
    inc de
    cp a,0
    ret z
    cp a,' '
    jr nz,NotSpace
    add a,16-' '
    jr PrintChar
NotSpace:
    add a,17-'0'
PrintChar:
    ld (hl),a
    inc hl
    jr PrintLoop  
