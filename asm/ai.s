;-------------------------------------------------------------------------
; Name: ai.s
;-------------------------------------------------------------------------
; Author: Steve Monks
;-------------------------------------------------------------------------
; Description:
; Routines used to path follow the computer controlled characters around
; the maze.
;-------------------------------------------------------------------------


chase_run_ctl:      db 0    ; set to $0 to follow player, set to $f to run away from player
ai_map_id:          db 'x'  ; value written into AI map
combined_poss_dir:   db 0    ; tmp storage for combined map and AI possible directions
pref_dir:           db 0    ; preferred direction, given current direction
pref_dir2:          db 0    ; 2nd choice preference, has slightly more options
best_dir:           db 0    ; direction to / away from player


; list of preferred direction masks for a given current direction
; indexed by current direction value (0 to 15)
; essentially permits a change in direction other than an about turn

ai_pref_dir_table:
    db DIR_MASK     ; stopped, pick any
    db DIR_UP|DIR_DOWN              ; 1 - Right	-> Up or Down
    db DIR_UP|DIR_DOWN              ; 2 - Left	-> Up or Down
    db DIR_LEFT                     ; 3 X - don't care
    db DIR_LEFT|DIR_RIGHT           ; 4 - Down	-> Left or Right
    db DIR_DOWN                     ; 5 X
    db DIR_DOWN                     ; 6 X
    db DIR_DOWN                     ; 7 X
    db DIR_LEFT|DIR_RIGHT           ; 8 - Up    -> Left or Right
    db DIR_UP                       ; 9 X
    db DIR_UP                       ; A X
    db DIR_UP                       ; B X
    db DIR_UP                       ; C X
    db DIR_UP                       ; D X
    db DIR_UP                       ; E X
    db DIR_UP                       ; F X

; 2nd choice list of preferred direction masks for a given current direction
; indexed by current direction value (0 to 15)
; essentially permits a change in direction other than an about turn or
; continuing in the current direction

ai_pref2_dir_table:
    db DIR_MASK     ; stopped, pick any
    db DIR_RIGHT|DIR_UP|DIR_DOWN    ; 1 - Right	-> Right, Up or Down
    db DIR_LEFT|DIR_UP|DIR_DOWN     ; 2 - Left	-> Left, Up or Down
    db DIR_LEFT                     ; 3 X
    db DIR_DOWN|DIR_LEFT|DIR_RIGHT  ; 4 - Down	-> Down, Left or Right
    db DIR_DOWN                     ; 5 X
    db DIR_DOWN                     ; 6 X
    db DIR_DOWN                     ; 7 X
    db DIR_UP|DIR_LEFT|DIR_RIGHT    ; 8 - Up    -> Up, Left or Right
    db DIR_UP                       ; 9 X
    db DIR_UP                       ; A X
    db DIR_UP                       ; B X
    db DIR_UP                       ; C X
    db DIR_UP                       ; D X
    db DIR_UP                       ; E X
    db DIR_UP                       ; F X


; This area is used to keep track of the location of AI characters and stop them
; ending up on top of each other. Without this, the cats would likely end up
; on top of one another and once in that state, stay that way as they'd be
; receiving the same inputs to their motion logic. Similarly the cheese and
; holes might be affected the same way.
;
; As each character decides which 16x16 pixel maze tile it is going to
; move to next, it writes an 'x' into that location in this map. The logic
; that decides where an object is going to move to next check the surrounding
; tiles for any containing an 'x' and discounts them as possible locations to
; head for.

AIMap:              ds MAPWIDTH*MAPHEIGHT


;-------------------------------------------------------------------------
; ClearAIMap
; Clears the buffer used to map AI character movements.
;-------------------------------------------------------------------------
ClearAIMap: proc

    ld de,AIMap
    ld bc,MAPHEIGHT*MAPWIDTH
clearlp:
    sub a,a
    ld (de),a
    dec bc
    ld a,b
    or c
    jr nz, clearlp

    ret
    pend

;-------------------------------------------------------------------------
; ChasePlayer
; Configures the chase logic to follow the player and then jumps to it
;-------------------------------------------------------------------------
ChasePlayer:
    ld a,0
    ld (chase_run_ctl),a
    jp ChaseLogic

;-------------------------------------------------------------------------
; AvoidPlayer
; Configures the chase logic to avoid the player and then jumps to it
;-------------------------------------------------------------------------
AvoidPlayer:
    ld a,$f
    ld (chase_run_ctl),a
    jp ChaseLogic

;-------------------------------------------------------------------------
; ChaseLogic
;
; Logic used to move the AI characters around the maze.
; Do not call this directly, go through either ChasePlayer or AvoidPlayer
; as these set up various control parameters.
;
; The basic theory of operation is as follows;
;
; The AI characters should try to follow or avoid the player (depending on
; their type).
; They should not suddenly turn back on themselves.
; They should attempt to change direction where possible rather than
; carrying on in the same direction as long as this doesn't cause them to
; turn back on themselves.
; They should only turn back on themselves if there is no other option.
;
; To achieve this we do the following;
;
; * determine the relative direction from the gameobj to the player
; * determine direction flag towards or away from the player (best_dir)
; * determine the preferred direction to head given the current direction (pref_dir)
;   - this is done using a table. A change in direction is most preferable,
;     followed by continuing in the current direction and finally reversing
;     the current direction.
; * determine the possible directions to move from the current location (poss_dir)
;   - examines the surrounding maze and AI map for empty locations in all
;     four possible directions.
;
; Each of these pieces of information forms a 4 bit mask. Next we;
; logically and together; best_dir & poss_dir & pref_dir
; - any bits set? use this
; logically and together; best_dir & poss_dir & pref_dir2
; - any bits set? use this
; otherwise and together; poss_dir & pref_dir
; - any bits set? use this
; otherwise just use poss_dir
;
; having chosen our bitmask, run it through a filter table to ensure only
; one bit is set and save this as the gameobj's new direction.
;
; To switch between following and avoiding the player we XOR best_dir with
; %00001111
;
; This routine also updates the entries in the AI mask
;
;-------------------------------------------------------------------------
ChaseLogic proc
    ; check if we're centered on a tile and if so
    ; allow the gameobj to pick a new direction
    ld bc,(ix+gameobj_x)    ; load x and y
    ld a,b
    or c
    and a,$f
    jp nz,HoldCurrentDir

    ; get preferred directions for current direction
    ld e,(ix+gameobj_dir)
    ld d,0
    ld hl,ai_pref_dir_table
    add hl,de
    ld a,(hl)
    ld (pref_dir),a

    ; get 2nd choice preferred directions for current direction
    ld hl,ai_pref2_dir_table
    add hl,de
    ld a,(hl)
    ld (pref_dir2),a

    ; clear current location in AI map
    ld l,(ix+gameobj_old_ai_addr)
    ld h,(ix+gameobj_old_ai_addr+1)
    sub a,a
    ld (hl),a

    ; determine direction towards player
    ld hl,0
    ld de,(player_pos_x)
    ld a,d          ; player y
    cp b            ; -cat y
    jr nc,NotUp

    ld h,DIR_UP
    jr NotDown

NotUp:
    jr z,NotDown

    ld h,DIR_DOWN
NotDown:
    ld a,e          ; player x
    cp c            ; -cat x
    jr nc,NotLeft

    ld l,DIR_LEFT
    jr NotRight

NotLeft:
    jr z,NotRight

    ld l,DIR_RIGHT
NotRight:
    ld a,h
    or l
    ld hl,chase_run_ctl
    xor (hl)                ; invert best direction if chase_run_ctl is set to $f
    ld (best_dir),a         ; save direction to player (best_dir)

    ; get possible move directions, combining inputs from
    ; the maze and the AI map, store result in combined_poss_dir

    call GameObjPosDir      ; returns map pos mask in a
    push af                 ; save map pos mask
    call GameObjPosDirAI    ; returns ai pos mask in a
    pop de                  ; retrieve map pos mask in d
    and a,d                 ; combined possible dirs from both map and AI
    ld (combined_poss_dir),a; save this to save recalculating it later

    ld d,a                  ; d = combined_poss_dir
    ld a,(pref_dir)
    ld b,a                  ; b = pref_dir
    ld a,(pref_dir2)
    ld c,a                  ; c = pref_dir2

    ld a,(best_dir)         ; direction to player masked by combined_poss_dir
    ld e,a                  ; e = best_dir

    ld a,r                  ; load refresh register, this is effectively a random number
    and a,$1                ; select a bit.
    jr z,IgnoreFirstPref    ; skip first pref randomly. Makes AI characters a bit less predictable

    ld a,e                  ; direction to player masked by combined_poss_dir
    and a,d                 ; combined_poss_dir & best_dir
    and a,b                 ; combined_poss_dir & best_dir & pref_dir
    jr nz,UseDir            ; any bits set? Then use one of these

IgnoreFirstPref:
    ld a,e                  ; direction to player masked by combined_poss_dir
    and a,d                 ; combined_poss_dir & best_dir
    and a,c                 ; combined_poss_dir & best_dir & pref_dir2
    jr nz,UseDir            ; any bits set? Then use one of these

    ld a,d                  ; get possible directions
    and a,b                 ; combined_poss_dir & prefdir
    jr nz,UseDir            ; any bits set? Then use one of these

    ld a,d                  ; get possible directions
    and a,c                 ; combined_poss_dir & pref_dir2
    jr nz,UseDir            ; any bits set? Then use one of these

    ld a,(combined_poss_dir); get possible directions and just use one of these

UseDir:
    ; ensure only one direction is set
    ld e,a
    ld d,0
    ld hl,gameobj_dir_filter
    add hl,de
    ld a,(hl)

    ld (ix+gameobj_dir),a

    ; write target location into AI map
    call GameObjDirAddr
    ld a,(ai_map_id)
    ld (hl),a
    ld (ix+gameobj_old_ai_addr),l
    ld (ix+gameobj_old_ai_addr+1),h

HoldCurrentDir:

    ret

    pend