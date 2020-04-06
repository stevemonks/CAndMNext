;-------------------------------------------------------------------------
; Name: cheese.s
;-------------------------------------------------------------------------
; Author: Steve Monks
;-------------------------------------------------------------------------
; Description:
; Logic and data to initialise, control and animate a cheese.
;-------------------------------------------------------------------------

cheese_anim_table:
    db 8    ;gamesprites_cheese0   ; 0
    db 9    ;gamesprites_cheese1
    db 8    ;gamesprites_cheese0   ; 1
    db 9    ;gamesprites_cheese1
    db 8    ;gamesprites_cheese0   ; 2
    db 9    ;gamesprites_cheese1
    db 0
    db 0
    db 8    ;gamesprites_cheese0   ; 4
    db 9    ;gamesprites_cheese1
    db 0
    db 0
    db 0
    db 0
    db 0
    db 0
    db 8    ;gamesprites_cheese0   ; 8
    db 9    ;gamesprites_cheese1


;-------------------------------------------------------------------------
; InitCheese
;-------------------------------------------------------------------------
InitCheese:
    push af
    ld ix,(gameobj_next)

    ld bc,ProcessCheese
    ld (ix+gameobj_process),c
    ld (ix+gameobj_process+1),b
    ld bc, cheese_anim_table
    ld (ix+gameobj_animtable),c
    ld (ix+gameobj_animtable+1),b
    ld a,1
    ld (ix+gameobj_speed),a
    ld a,GAMEOBJ_TYPE_CHEESE
    ld (ix+gameobj_type),a

    ld a,(num_cheese)
    inc a
    ld (num_cheese),a

    pop af
    ret


;-------------------------------------------------------------------------
; ProcessCheese
;-------------------------------------------------------------------------
ProcessCheese: proc
    call GameObjCollidePlayer   ; test if we've collided with the player
    jr z,NotDead
    ld a,(num_cheese)           ; if so decrement the number of active cheese
    dec a
    ld (num_cheese),a
    ld b,10                     ; add a value to the score
    call AddScore
    call KillGameObj            ; kill this game object
    ret                         ; no further processing

NotDead:
    ; not collided with player, so a little jiggery pokery
    ; to make this gameobj move slower than once per frame
    ; depending on the current cheese_speed_counter

    ld a,(cheese_speed_counter)
    cp a,1      ; will set carry if a=0
    ld a,0
    sbc a,0     ; a=$ff if cheese_speed_counter = 0
    and a,1<<GAMEOBJ_STATE_CANMOVE
    res GAMEOBJ_STATE_CANMOVE,(ix+gameobj_state)
    or a,(ix+gameobj_state)
    ld (ix+gameobj_state),a

    ; only choose a new direction if we're allowed to move this frame
    and a,(1<<GAMEOBJ_STATE_CANMOVE)
    ret z

    ; run the avoidance logic to pick a new direction
    call AvoidPlayer

    ret    

    pend