;-------------------------------------------------------------------------
; Name: setuplevel.s
;-------------------------------------------------------------------------
; Author: Steve Monks
;-------------------------------------------------------------------------
; Description:
; Creates the game objects for the current level.
;-------------------------------------------------------------------------


;-------------------------------------------------------------------------
; InitLevel
;
; Sets up the current game level. Scans the current maze for each of
; the gameobj types in turn and creates an appropriate gameobj for each.
; Note that the maze is scanned once for each type, this is to allow us
; to easily control the render order of the gameobjs.
; This is quite inefficient, but as the map isn't very big and the Next is
; relatively fast it's not an overhead worth worrying about for a game such
; as this.
;
; input: hl - address of map to setup
; output:
;-------------------------------------------------------------------------
InitLevel: proc

    call ClearAIMap

    ld (curr_maze_addr),hl

    ; init holes
    ld a,'h'            ; hole
    ld de,InitHole
    call InitLevelForThing

    ld a,'c'            ; cheese
    ld de,InitCheese
    call InitLevelForThing

    ld a,'m'            ; meanie
    ld de,InitCat
    call InitLevelForThing

    ld a,'p'            ; player
    ld de,InitPlayer
    call InitLevelForThing

    ret
    pend


;-------------------------------------------------------------------------
; InitLevelForThing
;
; Scans the current maze for the specified type of "thing" and calls the
; appropriate initialisation for it.

; input:
; a - ASCII character representing the "thing" to setup
; hl - address of map to setup
; de - address of setup function to call for the "thing"
;
; Output: adds a correctly configured gameobj to the active gameobj array
; for any instances of the specified thing found in the maze.
;-------------------------------------------------------------------------

InitLevelForThing: proc
    push hl             ; preserve the maze address for calling code

    ; ** SELF MODIFYING CODE ** - sets up the comparison type and init call
    ; by patching the code below. This is faster than storing these values
    ; and retrieving them when needed.

    ld (PatchType+1),a  ; set the type we're going to be looking for
    ld a,e
    ld (PatchInit+1),a  ; set the low byte of the init function to call
    ld a,d
    ld (PatchInit+2),a  ; set the high byte of the init function to call

    ld d,0
ColLp:
    ld e,0
RowLp:
    ld a,(hl)
    inc hl
PatchType:              ; SMC - address of compare instruction to patch with "thing" type
    cp a,'0'            ; SMC - check for type we're initialising
    jr nz,NoInitThing

PatchInit:              ; SMC - address of call function to patch with init function address
    call 0              ; SMC - call relevant init subroutine

    ld ix,(gameobj_next)
    ; calculate and set initial screen coords from map coords
    ld a,d              ; d contains the row index
    add a,a             ; rows are 16 pixels high
    add a,a             ; so we need to multiply this by 16
    add a,a             ; by adding it to itself multiple times
    add a,a             ; to calculate the on screen Y coordinate
    ld (ix+gameobj_y),a ; set the gameobj's initial Y coordinate

    ld a,e              ; e contains the column index
    add a,a             ; column are 16 pixels wide
    add a,a             ; so we need to multiply this by 16
    add a,a             ; by adding it to itself multiple times
    add a,a             ; to calculate the on screen X coordinate
    ld (ix+gameobj_x),a ; set the gameobj's initial X coordinate

    push de
    push hl
    call AddGameObj     ; having set up the gameobject add it to the gameobj system
    pop hl
    pop de

NoInitThing:
    inc e
    ld a,e
    cp a,MAPWIDTH
    jr c,RowLp

    inc d
    ld a,d
    cp a,MAPHEIGHT
    jr c,ColLp

    pop hl                  ; restore maze address for calling code
    ret

    pend

