;-------------------------------------------------------------------------
; Name: player.s
;-------------------------------------------------------------------------
; Author: Steve Monks
;-------------------------------------------------------------------------
; Description:
; Routines related to the initialisation and control of the player
; character.
;-------------------------------------------------------------------------

; The anim table converts between a 4 bit direction value and
; a sprite pattern index. The table contains sprite pattern indices
; ordered in pairs for each direction value. Valid directions are
; 0 - not moving
; 1 - moving right
; 2 - moving left
; 4 - moving down
; 8 - moving up
; (these number match the Kempston joystick bit assignment so that can be
; used directly to control player direction).
; Each direction supports two frames of animation, so to index into the table
; the current direction value needs to be doubled and the current animation frame
; (which is 0 or 1) added to the result. Using this to index into the table
; gets the correct sprite pattern index to use.
; Each game object uses a similar table, although the cheese only
; have two frames that are used for each direction, so you'll see they repeat
; the same pair of numbers throughout the table
; Note that left and right here use the same pair of sprite patterns and
; instead we rely on sprite mirroring to draw the left pointing mouse using
; the same set of sprites.

mouse_anim_table:
    db 0    ;gamesprites_mouse_idle   ; 0
    db 0    ;gamesprites_mouse_idle
    db 5    ;gamesprites_mouse_right0  ; 1
    db 6    ;gamesprites_mouse_right1
    db 5    ;gamesprites_mouse_right0  ; 2
    db 6    ;gamesprites_mouse_right1
    db 0
    db 0
    db 1    ;gamesprites_mouse_down0  ; 4
    db 2    ;gamesprites_mouse_down1
    db 0
    db 0
    db 0
    db 0
    db 0
    db 0
    db 3    ;gamesprites_mouse_up0  ; 8
    db 4    ;gamesprites_mouse_up1


;-------------------------------------------------------------------------
; InitPlayer
;-------------------------------------------------------------------------
InitPlayer:
    push af
    ld ix,(gameobj_next)

    ld bc,ProcessPlayer
    ld (ix+gameobj_process),c
    ld (ix+gameobj_process+1),b
    ld bc, mouse_anim_table
    ld (ix+gameobj_animtable),c
    ld (ix+gameobj_animtable+1),b
    ld a,2
    ld (ix+gameobj_speed),a
    ld a,GAMEOBJ_TYPE_PLAYER
    ld (ix+gameobj_type),a

    pop af
    ret


;-------------------------------------------------------------------------
; ProcessPlayer
;-------------------------------------------------------------------------
ProcessPlayer: proc
    ld a,(ix+gameobj_state)
    and a,$ff^(1<<GAMEOBJ_STATE_HIDDEN)
    ld l,a      ; copy of state with hidden bit unset

    ld a,(player_hidden)
    cp a,0
    jr z,PlayerNotHidden

    sub a,1
    ld (player_hidden),a
    jr nz,NoFlashHoles

    ; player about to reappear, so need to
    ; place him at the location of a hole
    ; rounded to 16x16 pixel granularity
    ld a,(hole_pos_x)
    and a,$f0
    ld (ix+gameobj_x),a
    ld (player_pos_x),a

    ld a,(hole_pos_y)
    and a,$f0
    ld (ix+gameobj_y),a
    ld (player_pos_y),a
    ld a,0
    ld (ix+gameobj_dir),a

    ld a,100
    ld (holes_disabled),a

NoFlashHoles:
    ; set hidden bit
    ld a,1<<GAMEOBJ_STATE_HIDDEN

PlayerNotHidden:
    or a,l                      ; combine hidden bit with rest of state
    ld (ix+gameobj_state),a     ; write back to gameobj

    ; disable player movement if hidden
    and a,1<<GAMEOBJ_STATE_HIDDEN
    jp nz, PlayerHidden

    ; check if we're centred on a tile and if so
    ; allow the player to pick a new direction
    ld bc,(ix+gameobj_x)    ; load x and y
    ld (player_pos_x),bc        ; save current player position so enemies can seek it
    ld a,b
    or c
    and a,$f
    jr nz,HoldCurrentDir

    call GetPlayerInput
    push af
    ; get possible move directions
    call GameObjPosDir
    pop de
    and a,d         ; inputs masked by possible directions

    ; ensure only one direction is set
    ld e,a
    ld d,0
    ld hl,gameobj_dir_filter
    add hl,de
    ld a,(hl)

    ld (ix+gameobj_dir),a
HoldCurrentDir:
    ret

PlayerHidden:
    call GetPlayerInput
    bit 4,a
    ret z

    ld a,(player_hidden)
    cp a,0
    ret z

    ; button pressed while player hidden, unhide player next frame
    ld a,1
    ld (player_hidden),a
    ld a,50
    ld (holes_disabled),a
    ret

    pend


;-------------------------------------------------------------------------
; GetPlayerInput
;
; scans the keyboard and Kempston joystick port (if attached)
; for player input and returns it in 'a' and with the following encoding;
; Bit Joystick  Key
; 0 - Right     (X)
; 1 - Left      (Z)
; 2 - Down      (K)
; 3 - Up        (O)
; 4 - Fire      (P)
;
; Note this bit assignment matches the input from the Kempston port.
;-------------------------------------------------------------------------

GetPlayerInput: proc
; read keyboard - note that bits are 0 when pressed
; read in direction order, highest bit value first
    ld e,0      ; accumulate keypresses in e
    ld d,1

    ld bc,$dffe
    in a,(bc)
    and a,$01   ; P key
    sub a,d
    rl e


    ld bc,$dffe
    in a,(bc)
    and a,$02   ; O key
    sub a,d
    rl e

    ld bc,$bffe
    in a,(bc)
    and a,$04   ; k key
    sub a,d
    rl e

    ld bc,$fefe
    in a,(bc)    ; read [cs]zxcv
    and a,$02        ; z key
    sub a,d
    rl e

    in a,(bc)    ; read [cs]zxcv
    and a,$04        ; x key
    sub a,d
    rl e

    in a,(31)           ; read kempston joystick port
    bit 7,a
    jr nz, NoKempston   ; if no interface is present the upper bits will float high
    and a,$1f
    or e
NoKempston:
    ret

    pend