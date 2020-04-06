;-------------------------------------------------------------------------
; Name: gameobj.s
;-------------------------------------------------------------------------
; Author: Steve Monks
;-------------------------------------------------------------------------
; Description:
; Routines that help to configure and manage game objects (gameobj).
; These are the underlying representation of the mobile characters in the
; game, i.e. the player, cats, cheese and holes. These are all handled
; via a consistent system defined here, with custom logic for each defined
; in their respective files.
;-------------------------------------------------------------------------

; direction flags
; these map onto the Kempston interface for simplicity
DIR_LEFT    = 2
DIR_RIGHT   = 1
DIR_UP      = 8
DIR_DOWN    = 4
DIR_MASK    = 15    ; all bits

DIR_RIGHT_BIT   = 0
DIR_LEFT_BIT    = 1
DIR_DOWN_BIT    = 2
DIR_UP_BIT      = 3

GAMEOBJ_TYPE_PLAYER = 0
GAMEOBJ_TYPE_CAT    = 1
GAMEOBJ_TYPE_HOLE   = 2
GAMEOBJ_TYPE_CHEESE = 3
GAMEOBJ_TYPE_LIFE   = 4

; bit indices for various flags
GAMEOBJ_STATE_ALIVE   = 0   ; bit to check if object is alive
GAMEOBJ_STATE_DYING   = 1   ; bit to check if object is dying
GAMEOBJ_STATE_CANMOVE = 2   ; bit to check if the object is allowed to move
GAMEOBJ_STATE_HIDDEN  = 3   ; bit to set to hide the object

MAXGAMEOBJ = 30

; define the structure of our gameobj in memory.
; each active character in the maze will be represented by one of these,
; so it contains all of the information required for it to function,
; including the subroutine to call for its special behaviour logic.

                    struct
gameobj_x           ds 1    ; x coord on screen (in pixels)
gameobj_y           ds 1    ; y coord on screen (in pixels)
gameobj_sprite      ds 1    ; assigned hardware sprite
gameobj_dir         ds 1    ; current direction (bitfield of DIR bits defined above)
gameobj_state       ds 1    ; state (bitfield of STATE values defined above)
gameobj_speed       ds 1    ; speed per frame (in pixels), must be an integer fraction of 16
gameobj_vars        ds 4    ; space for type specific variables
gameobj_process     ds 2    ; update function to control game obj
gameobj_animtable   ds 2    ; directional sprite pattern index table for gameobj
gameobj_old_ai_addr ds 2    ; address of last AI map location
gameobj_type        ds 1    ; type of gameobj this is
gameobj_len         equ .   ; length of gameobj structure (in bytes)
                    send


gameobj:            ds MAXGAMEOBJ * gameobj_len ; array of gameobj's
gameobj_cnt:        db 0                        ; number of active gameobj's
gameobj_next:       dw gameobj                  ; address of next free gameobj


; lookup table to filter multiple direction inputs down to a single direction.
; direction input from the AI and player can sometimes generate two directions
; at once, e.g. up and right. For this game, we only allow motion in a single
; direction at a time (up,down,left or right). 
; This table contains single direction values arranged in such a way that if
; we use the unfiltered 4 bit direction input as an index into it, we'll get
; back a value that contains just one bit from the index.
;
gameobj_dir_filter:
    db $0           ;$0
    db DIR_RIGHT    ;$1 right
    db DIR_LEFT     ;$2 left
    db DIR_RIGHT    ;$3 right+left
    db DIR_DOWN     ;$4 down
    db DIR_DOWN     ;$5 down+right
    db DIR_DOWN     ;$6 down+left
    db DIR_DOWN     ;$7 right+left+down
    db DIR_UP       ;$8 up
    db DIR_UP       ;$9 up+right
    db DIR_UP       ;$a up+left
    db DIR_UP       ;$b up+left+right
    db DIR_UP       ;$c up+down
    db DIR_UP       ;$d up+down+right
    db DIR_UP       ;$e up+down+left
    db DIR_UP       ;$f up+down+left+right


; This table contains the AI map offset for a given direction code.
; Using the current direction code as an index, this table provides
; the offset in bytes from the current cell to the cell pointed to
; by the direction.
; Note that it is only intended for direction values with a single
; bit set, hence entries other than 0,1,2,4 and 8 are set to zero
; and they should never be referenced.

dir_offset_table:
    db 0            ; 0 idle
    db 1            ; 1 right
    db -1           ; 2 left
    db 0            ; 3
    db MAPWIDTH     ; 4 down
    db 0            ; 5
    db 0            ; 6 
    db 0            ; 7
    db -MAPWIDTH    ; 8 up
    db 0
    db 0
    db 0
    db 0
    db 0
    db 0
    db 0


;-------------------------------------------------------------------------
; GameObjPosDir
;
; Checks surrounding tiles in the maze and returns a direction mask showing
; where there are no surrounding walls
; input:
; ix = address of game object
; output:
; returns possible direction mask in a
;-------------------------------------------------------------------------
GameObjPosDir:
    ; get y coord in character rows
    ld a,(ix+gameobj_y) ; get pixel Y coord.
    and a,$f0           ; mask off bottom four bits to get tile row offset
                        ; (each row is 16 bytes wide, so it's effectively
                        ; premultiplied as each row is 16 pixels high)

    ld d,a
    ld a,(ix+gameobj_x) ; divide pixel X coord by 16 to get the tile column
    srl a
    srl a
    srl a
    srl a

    add a,d
    ld e,a
    ld d,0
    ld iy,(curr_maze_addr)
    add iy,de   ; tile address of gameobj coords

    ld c,0

    ld a,(iy+1)
    cp a,'*'
    jr z,RightBlocked
    set DIR_RIGHT_BIT,c
RightBlocked:
    ld a,(iy-1)
    cp a,'*'
    jr z,LeftBlocked
    set DIR_LEFT_BIT,c
LeftBlocked:
    ld a,(iy+16)
    cp a,'*'
    jr z,DownBlocked
    set DIR_DOWN_BIT,c
DownBlocked:
    ld a,(iy-16)
    cp a,'*'
    jr z,UpBlocked
    set DIR_UP_BIT,c
UpBlocked:
    ld a,c
    ret

;-------------------------------------------------------------------------
; GameObjPosDirAI
;
; Checks surrounding tiles in the AI map and returns a direction mask where
; there are no surrounding AI objects (marked with an x in the map)
; input:
; ix = address of game object
; output:
; returns possible direction mask in a
;-------------------------------------------------------------------------
GameObjPosDirAI:
    ; get y coord in character rows
    ld a,(ix+gameobj_y) ; get pixel Y coord.
    and a,$f0           ; mask off bottom four bits to get tile row offset
                        ; (each row is 16 bytes wide, so it's effectively
                        ; premultiplied as each row is 16 pixels high)

    ld d,a
    ld a,(ix+gameobj_x) ; divide pixel X coord by 16 to get the tile column
    srl a
    srl a
    srl a
    srl a

    add a,d
    ld e,a
    ld d,0
    ld iy,AIMap
    add iy,de   ; tile address of gameobj coords

    ld c,0

    ld a,(iy+1)
    cp a,'x'
    jr z,RightBlocked2
    set DIR_RIGHT_BIT,c
RightBlocked2:
    ld a,(iy-1)
    cp a,'x'
    jr z,LeftBlocked2
    set DIR_LEFT_BIT,c
LeftBlocked2:
    ld a,(iy+16)
    cp a,'x'
    jr z,DownBlocked2
    set DIR_DOWN_BIT,c
DownBlocked2:
    ld a,(iy-16)
    cp a,'x'
    jr z,UpBlocked2
    set DIR_UP_BIT,c
UpBlocked2:
    ld a,c
    ret




;-------------------------------------------------------------------------
; GameObjDirAddr
; Calculates the address of the next tile / AI map cell for the gameobj's
; current location and direction. This is used to probe for maze wall
; collisions and collisions with other gameobj's
;
; input:
; ix = address of game object, used for x/y coords
; a = direction
; output:
; hl points to adjacent tile
;-------------------------------------------------------------------------
GameObjDirAddr:
    ; calculate map offset for direction flag
    ld hl,dir_offset_table
    and a,DIR_MASK
    ld e,a
    ld d,0
    add hl,de
    ld a,(hl)
    push af

    ; get y coord in character rows
    ld a,(ix+gameobj_y) ; get pixel Y coord.
    and a,$f0           ; mask off bottom four bits to get tile row offset
                        ; (each row is 16 bytes wide, so it's effectively
                        ; premultiplied as each row is 16 pixels high)

    ld d,a
    ld a,(ix+gameobj_x) ; divide pixel X coord by 16 to get the tile column
    srl a
    srl a
    srl a
    srl a

    add a,d
    ld e,a
    ld d,0
    ld hl,AIMap
    add hl,de           ; tile address of gameobj coords
    pop af
    ld e,a
    bit 7,a
    jr z,PositiveOffset
    ld d,$ff
PositiveOffset:
    add hl,de   ; add direction offset
    ret


;-------------------------------------------------------------------------
; GameObjMove
; updates gameobj_x and gameobj_y according to the value of gameobj_dir
; and gameobj_speed
;
; input:
; ix = address of game object
;-------------------------------------------------------------------------
GameObjMove:
    ld d,(ix+gameobj_speed)
    ld e,(ix+gameobj_dir)
    ld h,(ix+gameobj_x)
    ld l,(ix+gameobj_y)

    sub a,a
    bit DIR_LEFT_BIT,e
    jr z,NotMoveLeft
    sub a,d
NotMoveLeft:
    bit DIR_RIGHT_BIT,e
    jr z,NotMoveRight
    add a,d
NotMoveRight:
    add a,h
    ld (ix+gameobj_x),a

    sub a,a
    bit DIR_UP_BIT,e
    jr z,NotMoveUp
    sub a,d
NotMoveUp:
    bit DIR_DOWN_BIT,e
    jr z,NotMoveDown
    add a,d
NotMoveDown:
    add a,l
    ld (ix+gameobj_y),a
    ret


;-------------------------------------------------------------------------
; GameObjUpdateSprite
; updates the registers of the gameobj's hardware sprite.
; sets the position, visibility, sprite pattern and mirroring for the sprite
;
; input:
; ix = address of game object
; output:
;-------------------------------------------------------------------------
GameObjUpdateSprite:
    ld a,(ix+gameobj_sprite)        ; select sprite 0 to modify
    ld bc,SPRITE_SLOT_PORT
    out (bc),a

    ld bc,SPRITE_ATTR_PORT      ; begin modifying sprite attr, each out write advances to next attr

    ld a,(ix+gameobj_state)
    ld l,a

    ; position the sprite
    ld a,(ix+gameobj_x)
    add a,32+8                  ; add offset for border + map offset

    bit GAMEOBJ_STATE_HIDDEN,l
    jr z,GameObjNotHidden
    ld a,0                      ; hide sprite in border (easier than switching it off)
GameObjNotHidden:
    out(bc),a  ; xpos low
    ld a,(ix+gameobj_y)
    add a,32                    ; add offset for border
    out(bc),a  ; ypos low

    ; animate the sprite, keyed by its direction and position
    ; system supports two frames per direction and two idle frames
    ld a,(ix+gameobj_dir)
    and a,DIR_LEFT
    ld a,0
    jr z,DontFlipSprite
    ld a,%00001000          ; use mirroring when moving left
DontFlipSprite:
    out(bc),a  ; palette, mirroring and rot

    ; lookup sprite pattern index
    ld l,(ix+gameobj_animtable)     ; get animation table base
    ld h,(ix+gameobj_animtable+1)
    ld a,(ix+gameobj_dir)           ; get the current direction, 0,1,2,4 or 8
    add a,a                         ; double it as each direction has two frames
    ld e,a
    ld d,0
    add hl,de
    ; determine if we want frame 0 or frame 1
    ld a,(ix+gameobj_x)
    or a,(ix+gameobj_y)
    and a,$8            ; animate every 8 pixels
    jr z, NoAnimate     ; use frame 0
    inc hl              ; use frame 1
NoAnimate:
    ld a,(hl)           ; get the sprite pattern index from the anim table
    srl a               ; divide by two as low order bit goes in attr4

    or a,%11000000
    out(bc),a           ; enable, enable attr4, pattern no bits [4:1]

    ld a,(hl)           ; get sprite pattern index from anim table again 
    rr a                ; isolate bit 0 and reposition it for the attr4 register
    rr a
    rr a
    and a,%01000000
    or a,%10000000
    out(bc),a           ; 4 bit sprite, bit 0 of pattern
    ret


;-------------------------------------------------------------------------
; ResetGameObj
; Disables all the active sprites and marks all gameobj's as free.
;-------------------------------------------------------------------------
ResetGameObj proc
    ld ix,gameobj
    ld a,(gameobj_cnt)
    cp a,0
    jr z,NoGameObjToReset
    ld e,a

ResetLp:
    call KillGameObj

    ld bc,gameobj_len   ; step to next object
    add ix,bc
    dec e
    jr nz,ResetLp

    ld a,0
    ld (gameobj_cnt),a
    ld ix,gameobj
    ld (gameobj_next),ix
NoGameObjToReset:
    ret

    pend

;-------------------------------------------------------------------------
; AddGameObj
; Performs some standard initialisation for the gameobj currently pointed
; at by gameobj_next. If the array isn't full it also increments gameobj_cnt
; and the moves gameobj_next onto the next free gameobj.
; This is called after the type specific initialisation for each special
; kind of gameobj to finalise the process.
;
; input:
; ix = address of game object
;-------------------------------------------------------------------------
AddGameObj:
    ld a,(gameobj_cnt)
    cp a,MAXGAMEOBJ
    ret nc              ; array full

    ld ix,(gameobj_next)
    push af
    ld (ix+gameobj_sprite),a
    pop af
    ld c,0
    ld (ix+gameobj_dir),c
    ld c,(1<<GAMEOBJ_STATE_ALIVE)|(1<<GAMEOBJ_STATE_CANMOVE)
    ld (ix+gameobj_state),c

    ; initialise a valid AI map address
    push af
    ld a,0
    call GameObjDirAddr
    ld (ix+gameobj_old_ai_addr),l
    ld (ix+gameobj_old_ai_addr+1),h
    pop af

    inc a
    ld (gameobj_cnt),a
    ld bc,gameobj_len
    add ix,bc
    ld (gameobj_next),ix

    ret



;-------------------------------------------------------------------------
; ProcessGameObj
; Iterates over the array of gameobj's, performing various standard
; operations on them such as moving them and animating their sprites.
; Also calls the gameobj's custom Process function.
; input:
; ix = address of game object
;-------------------------------------------------------------------------
ProcessGameObj:
        ld ix,gameobj
        ld a,(gameobj_cnt)
ProcessGameObjLoop:
        push af
        ld a,(ix+gameobj_state)
        bit GAMEOBJ_STATE_ALIVE,a
        jr z,GameObjIsDead          ; if gameobj is already dead skip all processing on it

        ; call the gameobj's custom process subroutine.
        ; Z80 doesn't have a call (hl) opcode, so as we're
        ; using jp (hl) we have to load hl with the function
        ; address and push the return address onto the stack
        ; so the custom subroutine can return here when it's
        ; done.

        ld l,(ix+gameobj_process)
        ld h,(ix+gameobj_process+1)
        ld bc,ProcessGameObjRet
        push bc
        jp (hl)   ; call the object specific process subroutine

ProcessGameObjRet:                  ; return address after calling custom process subroutine
        ld a,(ix+gameobj_state)
        bit GAMEOBJ_STATE_ALIVE,a   ; check gameobj alive status after process subroutine
        jr z,GameObjIsDead          ; if gameobj is dead skip the move and sprite update
        bit GAMEOBJ_STATE_CANMOVE,a
        jr z,GameObjSkipMove        ; if gameobj movement is disabled, skip the move function
        call GameObjMove

GameObjSkipMove:        
        call GameObjUpdateSprite    ; animate the gameobj's sprite
GameObjIsDead:
        ld bc,gameobj_len           ; advance to next gameobj
        add ix,bc

        pop af
        dec a
        jr nz,ProcessGameObjLoop
        ret


;-------------------------------------------------------------------------
; GameObjCollidePlayer
; This subroutine performs a simple box to box collision check between
; the player and the current gameobj. Each sprite is 16x16, so we determine
; a collision if the difference between each gameobj's position is 12
; in each axis. This gives us a crude overlap test which is fine for a
; simple game like this.
;
; input: ix points to gameobj
; output: sets the nz flag if a collision is detected
;-------------------------------------------------------------------------
GameObjCollidePlayer:
        ld a,(player_hidden)
        cp a,0
        jr z,GameObjPlayerNotHidden
        ld a,0
        add a,a ; clear z flag to indicate no collision because player hidden
        ret

GameObjPlayerNotHidden:        
        ld bc,(player_pos_x)    ; load x and y
        ld a,(ix+gameobj_x)
        sub a,c
        jr nc,CollidePosX
        neg
CollidePosX:
        cp a,12
        jr nc,NoCollide

        ld a,(ix+gameobj_y)
        sub a,b
        jr nc,CollidePosY
        neg
CollidePosY:
        cp a,12
        jr nc,NoCollide

        ld a,1
        add a,a ; set z flag to indicate collision
        ret
NoCollide:
        ld a,0
        add a,a ; clear z flag to indicate no collision
        ret


;-------------------------------------------------------------------------
; KillGameObj
; Marks a gameobj as dead and disables its sprite.
;
; input: ix points to gameobj
; output: gameobj is marked as dead and sprite is disabled
;-------------------------------------------------------------------------
KillGameObj:
        ld a,NOT((1<<GAMEOBJ_STATE_ALIVE)|(1<<GAMEOBJ_STATE_DYING))
        and a,(ix+gameobj_state)
        ld (ix+gameobj_state),a     ; kill the gameobj

        ; select the sprite to modify
        ld a,(ix+gameobj_sprite)
        ld bc,SPRITE_SLOT_PORT
        out (bc),a

        ; turn off the sprite
        ld bc,SPRITE_ATTR_PORT      ; begin modifying sprite attr, each out write advances to next attr
        ld a,0
        out(bc),a  ; xpos low
        out(bc),a  ; ypos low
        out(bc),a  ; palette and mirroring
        out(bc),a  ; visible and pattern select

        ; clear current location in AI map
        ld l,(ix+gameobj_old_ai_addr)
        ld h,(ix+gameobj_old_ai_addr+1)
        ld a,l
        or a,h
        jr z,NoAIMapEntry
        sub a,a
        ld (hl),a
        ld (ix+gameobj_old_ai_addr),a
        ld (ix+gameobj_old_ai_addr+1),a
NoAIMapEntry:
        ret