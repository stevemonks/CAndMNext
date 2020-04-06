;-------------------------------------------------------------------------
; Name: cat.s
;-------------------------------------------------------------------------
; Author: Steve Monks
;-------------------------------------------------------------------------
; Description:
; Logic and data to initialise, control and animate a cat.
;-------------------------------------------------------------------------

; The anim table converts between a 4 bit direction value and
; a sprite pattern index. The table contains sprite pattern indices
; ordered in pairs for each direction value. Valid directions are
; 0 - not moving (idle)
; 1 - moving right
; 2 - moving left
; 4 - moving down
; 8 - moving up
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

cat_anim_table:
    db 12+0    ;gamesprites_cat_idle   ; 0
    db 12+0    ;gamesprites_cat_idle
    db 12+5    ;gamesprites_cat_right0  ; 1
    db 12+6    ;gamesprites_cat_right1
    db 12+5    ;gamesprites_cat_right0  ; 2
    db 12+6    ;gamesprites_cat_right1
    db 12+0
    db 12+0
    db 12+1    ;gamesprites_cat_down0  ; 4
    db 12+2    ;gamesprites_cat_down1
    db 12+0
    db 12+0
    db 12+0
    db 12+0
    db 12+0
    db 12+0
    db 12+3    ;gamesprites_cat_up0  ; 8
    db 12+4    ;gamesprites_cat_up1

;-------------------------------------------------------------------------
; InitCat
;-------------------------------------------------------------------------
InitCat:
    push af
    ld ix,(gameobj_next)

    ld bc,ProcessCat
    ld (ix+gameobj_process),c
    ld (ix+gameobj_process+1),b
    ld bc,cat_anim_table
    ld (ix+gameobj_animtable),c
    ld (ix+gameobj_animtable+1),b
    ld a,1
    ld (ix+gameobj_speed),a
    ld a,GAMEOBJ_TYPE_CAT
    ld (ix+gameobj_type),a

    pop af
    ret


;-------------------------------------------------------------------------
; ProcessCat
;-------------------------------------------------------------------------
ProcessCat: proc
    ; check for collision with the player.
    ; when the player is in a hole, his position is set
    ; outside the maze to prevent this test from succeeding.
    call GameObjCollidePlayer
    jr z,NotCollided

    ; the player collided with this cat, so kill him.
    call KillPlayer

NotCollided:
    ; a little jiggery pokery to make the cat move slower
    ; than once per frame depending on the value of
    ; cat_speed_counter.

    ld a,(cat_speed_counter)
    cp a,1      ; will set carry if a=0
    ld a,0
    sbc a,0     ; a=$ff if CatSpeedCounter = 0
    and a,1<<GAMEOBJ_STATE_CANMOVE
    res GAMEOBJ_STATE_CANMOVE,(ix+gameobj_state)
    or a,(ix+gameobj_state)
    ld (ix+gameobj_state),a

    ; only choose a new direction if we're allowed to move this frame
    and a,(1<<GAMEOBJ_STATE_CANMOVE)
    ret z

    call ChasePlayer

    ret

    pend