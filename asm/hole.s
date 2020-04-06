;-------------------------------------------------------------------------
; Name: hole.s
;-------------------------------------------------------------------------
; Author: Steve Monks
;-------------------------------------------------------------------------
; Description:
; Logic and data to initialise, control and animate a hole.
;-------------------------------------------------------------------------

; The hole doesn't really animate, but uses the same system as
; everything else
hole_anim_table:
    db 7    ;gamesprites_hole   ; 0
    db 7    ;gamesprites_hole
    db 7    ;gamesprites_hole   ; 1
    db 7    ;gamesprites_hole
    db 7    ;gamesprites_hole   ; 2
    db 7    ;gamesprites_hole
    db 0
    db 0
    db 7    ;gamesprites_hole   ; 4
    db 7    ;gamesprites_hole
    db 0
    db 0
    db 0
    db 0
    db 0
    db 0
    db 7    ;gamesprites_hole   ; 8
    db 7    ;gamesprites_hole


;-------------------------------------------------------------------------
; InitHole
;-------------------------------------------------------------------------
InitHole:
    push af
    ld ix,(gameobj_next)

    ld bc,ProcessHole
    ld (ix+gameobj_process),c
    ld (ix+gameobj_process+1),b
    ld bc, hole_anim_table
    ld (ix+gameobj_animtable),c
    ld (ix+gameobj_animtable+1),b
    ld a,1
    ld (ix+gameobj_speed),a
    ld a,GAMEOBJ_TYPE_HOLE
    ld (ix+gameobj_type),a

    ld a,(num_holes)
    ld (ix+gameobj_vars),a
    inc a
    ld (num_holes),a
    pop af
    ret


;-------------------------------------------------------------------------
; ProcessHole
;-------------------------------------------------------------------------
ProcessHole: proc
    ; check if all holes are disabled, this happens when the player
    ; has just left a hole to stop him immediately re-entering the hole.

    ld a,(holes_disabled)
    cp a,0
    jr nz,NotCollided
    
    ; if the holes are not disabled, check if the player is currently hidden
    ; i.e if he's in a hole and if he isn't then perform a collision check
    ; against this hole.

    ld a,(player_hidden)
    cp a,0
    jr nz,NotCollided    ; player already hidden, so don't collide

    ; collide with player
    call GameObjCollidePlayer
    ld a,(player_hidden)
    jr z,NotCollided
   
   ; the player has collided with this hole, so we need to hide the player

    ld a,$ff
    ld (player_hidden),a    ; force player to be hidden

NotCollided:

    cp a,100
    jr nc,NotFlash

    ; the holes flash when the player is going to be forced out of the
    ; hole. We achieve this by setting the hidden flag of each holes
    ; game object periodically. To limit the speed of the flash
    ; we key it off bit 3 of the player_hidden value (which decrements every
    ; frame while it's not zero).

    and a,8
    jr z,Visible
    set GAMEOBJ_STATE_HIDDEN,(ix+gameobj_state)     ; set the holes "hidden" bit
    jr NotFlash
Visible:
    res GAMEOBJ_STATE_HIDDEN,(ix+gameobj_state)     ; clear the holes "hidden" bit
NotFlash:
    ; when the player reappears we want him to randomly appear at one of the
    ; holes. To achieve this, we have a counter (exit_hole_ix) that increments
    ; once per frame, cycling through the number of holes. If we're the currently
    ; indexed hole, we save our position in hole_pos_x/y. When the player
    ; reappears he picks up whatever the current value of these variables is.

    ld a,(exit_hole_ix)
    ld l,a
    ld a,(ix+gameobj_vars)  ; var0 is this holes index
    cp a,l                  ; does it match the current exit hole?
    jr nz,DontStashPosition

    ; stash current hole pos
    ld a,(ix+gameobj_x)
    ld (hole_pos_x),a
    ld a,(ix+gameobj_y)
    ld (hole_pos_y),a

DontStashPosition:
    ; a little jiggery pokery to make this gameobj move slower
    ; than once per frame depending on the current hole_speed_counter

    ld a,(hole_speed_counter)
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

    call AvoidPlayer

    ret    

    pend