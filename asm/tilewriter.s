;-------------------------------------------------------------------------
; Name: tilewriter.s
;-------------------------------------------------------------------------
; Author: Steve Monks
;-------------------------------------------------------------------------
; Description:
; Populates the 30x22 on screen tilemap from the 16x11 maze cells.
; Each character in the maze represents a cluster of 4 tiles in the tilemap.
;-------------------------------------------------------------------------

; this table maps the letter codes used in the maze maps to
; the index of the first of four 8x8 pixel tiles that represent the
; complete 16x16 tile. These have been exported from NextDes in groups
; of four in the order top left, top right, bottom left, bottom right.

CharMappings:
    db ' ',0*4  ; floor tile
    db '*',1*4  ; wall
    db '.',2*4  ; blank tile
    db 0,0

TileMapWidth = 40
TileMapHeight = 32
EmptyTile = 255

;-------------------------------------------------------------------------
; ClearTileMap
;
; fills the entire tilemap with blank tiles.
;-------------------------------------------------------------------------
ClearTileMap proc
    ld de,tile_map_data
    ld b,TileMapHeight
    ld a,EmptyTile
RowLp:
    ld c,TileMapWidth
ColLp:
    ld (de),a
    inc de
    dec c
    jr nz,ColLp
    dec b
    jr nz,RowLp
    ret
    endp

;-------------------------------------------------------------------------
; ClearInfoArea
;
; clears the two lines below the maze that we use to display info
; such as scores and lives
;-------------------------------------------------------------------------
ClearInfoArea proc

    ld de,tile_map_data+40*22
    ld b,2
    ld a,EmptyTile
RowLp:
    ld c,TileMapWidth
ColLp:
    ld (de),a
    inc de
    dec c
    jr nz,ColLp
    dec b
    jr nz,RowLp
    ret

    endp


;-------------------------------------------------------------------------
; TileWriter
;
; Populates the hardware tilemap from the current maze map.
; The hardware tilemap comprises a 40x32 array of 8x8 tiles, whereas the maze maps
; comprise a 16x11 array of 16x16 tiles. So each maze map tile represents
; four tilemap tiles. The tile patterns have been arranged in groups of four
; so we only need to calculate the index of the first tile in a set of four
; and then increment the index as we populate the 2x2 entry in the tilemap.
; input: hl - pointer to source map
; output: populates hardware tilemap
;-------------------------------------------------------------------------

TileWriter proc

    di          ; disable interrupts because we're going to use IY,
    push iy     ; better preserve IY too as the interrupt routine uses it

    ; address of tilemap used by hardware to generate display
    ; the +1 here is to offset the map 1 tile to the right as
    ; were displaying a 30 tile wide maze in a 32 tile wide screen,
    ; this effectively offsets the displayed maze 8 pixels to the right
    ; centering it on the screen.

    ld iy,tile_map_data+1
    ld b,MAPHEIGHT
RowLp:
    ld c,MAPWIDTH
ColLp:
    ld d,(hl)
    inc hl

    ; convert ASCII to tile index using the lookup table above
    ld ix,CharMappings

SearchLoop:
    ld a,(ix+0)
    cp a,0              ; 0 indicates the end of the table, if we find this
    jr z,ExitSearch     ; there is no tile for this character

    cp a,d
    jr z,ExitSearch
    inc ix
    inc ix
    jr SearchLoop

ExitSearch:
    ld e,(ix+1)         ; ix points to the ASCII chr in the table, the next byte is the tile pattern index
    ld (iy),e           ; write top left tile
    inc e
    ld (iy+1),e         ; write top right tile
    inc e
    ld (iy+40),e        ; write bottom left tile
    inc e
    ld (iy+41),e        ; write bottom right tile
    inc iy              ; step to next output tile address (two hardware tiles right)
    inc iy
    dec c
    jr nz, ColLp

    ld de,40+8          ; offset to two rows down from start of current row
    add iy,de
    dec b
    jr nz, RowLp

    pop iy              ; restore IY
    ei                  ; re-enable interrupts
    ret

    endp
