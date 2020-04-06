;-------------------------------------------------------------------------
; Name: gamelogic.s
;-------------------------------------------------------------------------
; Author: Steve Monks
;-------------------------------------------------------------------------
; Description:
; Routines to control the top level flow of the game.
;-------------------------------------------------------------------------

curr_maze:              db 0    ; the index of the map we're currently playing (indexes into table below)
curr_maze_addr:         dw 0    ; the address of the maze we're currently playing (from the table below)

; table of map addresses - this table is indexed by the curr_maze variable
; to get the start address of the currently active maze. It contains the
; address of every playable maze. Changing the order here will change the
; order they are played in.

map_table:
    dw map0
    dw map1
    dw map2
    dw map3
    dw map4
    dw map5
    dw map6
    dw map7

    ; insert more mazes here!

            ; this address of zero terminates the list
    dw 0    ; ** very important this is here **


; update timers used to stagger the Updates
; of the various gameobjs

cheese_speed_counter:   db 0    ; used to moderate the speed of the cheese
cat_speed_counter:      db 0    ; used to moderate the speed of the cats
hole_speed_counter:     db 0    ; used to moderate the speed of the holes
player_hidden:          db 0    ; set to non zero when the player is hidden
holes_disabled:         db 0    ; set to non zero when the holes can't be entered
num_holes:              db 0    ; count of holes, used to cycle exit_hole_ix
exit_hole_ix:           db 0    ; cycles to a different hole index each frame. Used to determine which hole the mouse will reappear from.
num_lives:              db 0    ; number of lives remaining
player_dead:            db 0    ; set to non zero if the player is dead
num_cheese:             db 0    ; count of active cheese. When this reaches zero the level is complete
ScoreInc:               db 0    ; used to cache a value to be added to the score. If non zero the score is incremented and this is decremented once per frame.

player_pos_x:           db 0    ; the current location of the player. Used by AI to follow / avoid the player
player_pos_y:           db 0
hole_pos_x:             db 0    ; the position of the active hole. Used for location the mouse will reappear from.
hole_pos_y:             db 0

; various bits of text used throughout the game.
; the score and bonus values are stored here in ASCII
;
CatAndMouseText:
    db "CAT AND MOUSE",0

PressAnyKeyToPlayText:
    db "PRESS ANY KEY TO PLAY",0

GameOverText:
    db "GAME OVER",0    ; note ';' maps to the '!' tile
OopsText:
    db "OOPS;",0        ; note ';' maps to the '!' tile

GetReadyText:
    db "GET  READY;",0  ; note ';' maps to the '!' tile

ScoreText:
    db "SCORE:"
ScoreNumbers:
    db "000000",0
ResetScoreNumbers:
    db "000000"

BonusText:
    db "BONUS:"
BonusNumbers:
    db "1000",0

ResetBonusNumbers:
    db "1000"


;-------------------------------------------------------------------------
; AddScore
;
; call with score increment in 'b'
;-------------------------------------------------------------------------
AddScore:
    ld a,(ScoreInc)
    add a,b
    ld (ScoreInc),a
    ret


;-------------------------------------------------------------------------
; DrawScore
;-------------------------------------------------------------------------
DrawScore:
    ld ix,ScoreText
    ld b,(32-11)/2
    ld c,23
    call PrintText
    ret

;-------------------------------------------------------------------------
; UpdateScore
;-------------------------------------------------------------------------
UpdateScore:
    ld a,(ScoreInc)
    cp a,0
    jr z,NoScoreInc
    dec a
    ld (ScoreInc),a

    ld b,6                  ; max number of digits to update
    ld hl,ScoreNumbers+5    ; address of rightmost digit
UpdateScoreLoop:
    ld a,(hl)
    inc a
    cp a,'9'+1
    jr c,NoScoreOverflow
    ld a,'0'
NoScoreOverflow:
    ld (hl),a
    jr c,ExitScoreLoop
    dec hl
    djnz UpdateScoreLoop

ExitScoreLoop:
    call DrawScore
NoScoreInc:
    ret

;-------------------------------------------------------------------------
; DrawBonus
;-------------------------------------------------------------------------
DrawBonus:
    ld ix,BonusText
    ld b,(32-9)/2
    ld c,22
    call PrintText
    ret

;-------------------------------------------------------------------------
; UpdateBonus
;
; Counts down the bonus. Because we're using ASCII numbers to represent
; the bonus, a little jiggery pokery is required to handle the case
; when we reach zero. In this instance, having detected a wrap, we
; reset the value back to '0000'
; returns c=0 if the counter was decremented
;-------------------------------------------------------------------------

UpdateBonus:
    ld b,5
    ld c,0
    ld hl,BonusNumbers+4
UpdateBonusLoop:
    dec hl
    dec b
    jr nz,NotLastDigit

    ; has the most significant digit wrapped?
    cp a,'9'
    ret nz

    ; yes! so reset bonus back to '0000' 
    ld hl,ResetScoreNumbers
    ld de,BonusNumbers
    ld bc,4
    ldir
    ld c,1
    ret

NotLastDigit:
    ld a,(hl)
    dec a
    cp a,'0'
    jr nc,NoBonusUnderflow
    ld a,'9'
NoBonusUnderflow:
    ld (hl),a
    jr c,UpdateBonusLoop
    ret


;-------------------------------------------------------------------------
; InitLives
;-------------------------------------------------------------------------
InitLives:
    ld a,(num_lives)
    cp a,0
    ret z

    ld b,0
    ld c,0
InitLivesLoop:
    push af

    ld ix,(gameobj_next)
    ld (ix+gameobj_x),b
    ld (ix+gameobj_y),11*16
    ld (ix+gameobj_vars),c
    inc c
    ld a,16
    add a,b
    ld b,a

    push bc
    ld bc,ProcessLife
    ld (ix+gameobj_process),c
    ld (ix+gameobj_process+1),b
    ld bc, mouse_anim_table
    ld (ix+gameobj_animtable),c
    ld (ix+gameobj_animtable+1),b
    ld a,0
    ld (ix+gameobj_speed),a
    ld a,GAMEOBJ_TYPE_LIFE
    ld (ix+gameobj_type),a

    call AddGameObj

    pop bc
    pop af
    cp a,c
    jr nz,InitLivesLoop

    ret


;-------------------------------------------------------------------------
; ProcessLife
;-------------------------------------------------------------------------
ProcessLife:
    ld a,(num_lives)
    ld c,(ix+gameobj_vars)
    cp a,c
    ret nc

    ld a,(1<<GAMEOBJ_STATE_HIDDEN)|(1<<GAMEOBJ_STATE_ALIVE)
    ld (ix+gameobj_state),a
    ret


;-------------------------------------------------------------------------
; KillPlayer
;-------------------------------------------------------------------------
KillPlayer:
    ld a,1
    ld (player_dead),a
    ret


;-------------------------------------------------------------------------
; ProcessCounters
;-------------------------------------------------------------------------
ProcessCounters:
    ld a,(cheese_speed_counter)
    dec a
    jp p,NoResetCheeseSpeedCounter
    ld a,(num_cheese)
    dec a
NoResetCheeseSpeedCounter:
    ld (cheese_speed_counter),a

    ld a,(cat_speed_counter)
    dec a
    and a,1
    ld (cat_speed_counter),a

    ld a,(hole_speed_counter)
    dec a
    and a,3
    ld (hole_speed_counter),a

    ld a,(holes_disabled)
    cp a,0
    jr z,HolesDisabled0

    dec a
    ld (holes_disabled),a

HolesDisabled0:
    ; cycle exit hole index
    ; effectively making it random which
    ; hole we'll pop up at
    ld a,(num_holes)
    ld l,a
    ld a,(exit_hole_ix)
    inc a
    cp a,l
    jr c,ExitHoleIxOk
    ld a,0
ExitHoleIxOk:
    ld (exit_hole_ix),a
    ret


;-------------------------------------------------------------------------
; GameLogic
;
; This manages the main, overriding logic of the game. The game is split
; into multiple distinct sections;
; * The title screen (press any key)
; * The pre level delay
; * The main game loop
; * The post game delay / bonus countdown
; * The player dead delay
; * The Game Over screen
;
; and the general flow between these sections is controlled here
;-------------------------------------------------------------------------
GameLogic:
    call ClearTileMap   ; completely clear the tile map
    call ResetGameObj   ; remove all sprites

    ld ix,CatAndMouseText
    ld b,(32-13)/2
    ld c,10
    call PrintText      ; print the title to the tilemap

    ld ix,PressAnyKeyToPlayText
    ld b,(32-21)/2
    ld c,12
    call PrintText      ; print "Press any key" to the tilemap

    ld b,50             ; a brief delay when the game is first booted
                        ; to allow things to stabilise
PreKeyWait:
    halt
    djnz PreKeyWait

    ; this loop waits until any key or the joystick fire button is pressed

    ld e,$1f            ; mask for a half row of keys (5 keys, bits 0 to 4)
WaitKeyLoop:

    in a,(31)           ; read kempston joystick port
    bit 7,a             ; if the interface isn't present, this bit will be non zero
    jr nz, NoKempston2  ; if no interface is present the upper bits will float high
    and a,$10           ; mask for the fire button (bit 4)
    jr nz,StartGame     ; joystick inputs are true when pressed/active

NoKempston2:
    ; keyboard scanning routine. Reads every half row of the
    ; keyboard. Bits are set when keys are not pressed, so AND-ing
    ; them all together should give us $1f if nothing has been pressed
    ; any different value indicates a pressed key.
    ; This could be done with less code using a table of port addresses
    ; and a loop, but this approach is probably simpler to understand.
    ld bc,$fefe         ; 1st port to read
    in a,(bc)           ; read port value into a
    and a,e             ; mask off the key bits, the other 3 bits are effectively random
    ld e,a              ; save result in e
    ld bc,$fdfe         ; 2nd port to read
    in a,(bc)           ; read port value into a
    and a,e             ; and with previous result
    ld e,a              ; save result in e and repeat for remaining rows
    ld bc,$fbfe
    in a,(bc)
    and a,e
    ld e,a
    ld bc,$f7fe
    in a,(bc)
    and a,e
    ld e,a
    ld bc,$effe
    in a,(bc)
    and a,e
    ld e,a
    ld bc,$dffe
    in a,(bc)
    and a,e
    ld e,a
    ld bc,$bffe
    in a,(bc)
    and a,e
    ld e,a
    ld bc,$7ffe
    in a,(bc)
    and a,e
    cp a,$1f
    jr z,WaitKeyLoop        ; if the value in a doesn't equal $1f (%00011111) drop out of the loop and begin the game

; at this point we're going to start a new game, either because a key was pressed
; or the Kempston joystick fire button was pressed
StartGame:
    ld a,0                  ; index of initial maze to play
    ld (curr_maze),a        ; initialise the stored maze index
    ld a,3                  ; initial number of lives
    ld (num_lives),a        ; initialise the stored number of lives

    ld de,ScoreNumbers      ; reset the score by copying a '000000' string of numbers over the text
    ld hl,ResetScoreNumbers
    ld bc,6
    ldir

; at this point we're about to begin a level. We arrive here if;
; * the player has died and still has lives left,
; * the player has completed a level
; * a key was pressed on the start screen
;
; So we need to set everything up for the next level

StartLevel:
    call ResetGameObj           ; removes all sprites
    call InitLives              ; add the lives indicator sprites for the current value of num_lives

    ld de,BonusNumbers          ; reset the bonus by copying '1000' over the displayed text.
    ld hl,ResetBonusNumbers
    ld bc,4
    ldir

    ; reset a bunch of game variables
    ld a,0
    ld (player_pos_x),a         ; player position used to check for collision with cheese, cats and holes.
    ld (player_pos_y),a         ; initially set to a location outside the playable area to avoid false collisions.
    ld (holes_disabled),a       ; holes should be visible when added
    ld (num_holes),a            ; there are initially no holes until the level has been set up.
    ld (exit_hole_ix),a         ; reset to initial value
    ld (player_hidden),a        ; player should be visible when added
    ld (num_cheese),a           ; there are initially no cheese until the level has been set up.
    ld (player_dead),a          ; the player is not dead.
    ld a,(curr_maze)            ; fetch the current maze index
    add a,a                     ; double it as we're going to use it to index into the table of maze pointers which are two bytes apiece
    ld e,a                      ; copy index into de
    ld d,0
    ld ix,map_table             ; start of maze pointer table
    add ix,de                   ; add the index
    ld l,(ix+0)                 ; set hl to point to the first byte of the current maze
    ld h,(ix+1)

    ; now we setup the current level. The next two functions use the value in HL
    ; to initialise all of the game objects such as the player, holes, cheese and cats,
    ; then proceed to populate the tilemap with a visual representation of the maze

    call InitLevel              ; initialise all gameobj for current level
    call TileWriter             ; setup the hardware tilemap for the current level

    call ProcessGameObj         ; this will place all the gameobj sprites at their start position

    call ClearInfoArea          ; erase the two rows beneath the on screen maze
    ld ix,GetReadyText          ; display the "Get Ready" text
    ld b,(32-11)/2
    ld c,23
    call PrintText


    ld b,100                    ; wait for 100 frames
PreGameWait:
    ; halt stops the CPU until the next interrupt occurs
    ; its a simple way to synchronise with the vertical blank
    ; or time short delays by executing it multiple times.
    ; Each iteration of a loop like this will last about 20mS in PAL territories.
    halt
    djnz PreGameWait

    call ClearInfoArea  ; clear the info area
    call DrawScore      ; draw the current score

; This is the main game loop. Execution will remain in here until either;
; * The player dies.
; * All the cheeses are collected.
;
GameLoop:
    halt                    ; synchronise with the VBlank.
    call ProcessCounters    ; update various game logic counters.
    call UpdateScore        ; Animates the score and draws it if it changes.
    call UpdateBonus        ; Animate the bonus.
    call DrawBonus          ; Draw the bonus.

    ; This function executes the update function for each
    ; enabled game object (player, cat, cheese, holes)
    call ProcessGameObj 

    ; test if the player has been killed and exit the loop if so.
    ld a,(player_dead)
    cp 0
    jr nz,PlayerDead

    ; test if the player has collected all of the cheese and loop round again if not.
    ld a,(num_cheese)
    cp a,0
    jr nz,GameLoop

; When execution reaches this point the player has successfully collected all of the cheese.
; We now want to count down any remaining bonus and add it to the players score.
; We also want to wait a couple of seconds to give the player time to realise
; what's happened.

    ld b,100                ; nominal two second wait
PostGameWait:
    push bc                 ; preserve the wait counter value

    halt                    ; sync with the VBlank

    ; bonus addition takes too long if the player completes the level quickly
    ; and we copy it across to the score one unit at a time.
    ; So to speed things up we're going to repeat the calculation a number of times
    ; every time round this loop.

    ld b,4                  ; number of times to repeat the bonus transfer
BonusCalcLoop:
    push bc                 ; save the repeat counter

    call UpdateBonus        ; count down the bonus.
    ld a,c                  ; returns 0 in C if there is no bonus left.
    cp a,0
    jr nz,NoAddBonusToScore
    ld a,(ScoreInc)         ; increment score_inc, this will cause the score to increment the next time it is updated
    inc a
    ld (ScoreInc),a
NoAddBonusToScore:
    call UpdateScore        ; update and draw the score
    call DrawBonus          ; draw the bonus

    pop bc                  ; retrieve the repeat counter
    djnz BonusCalcLoop

    
    pop bc                  ; retrieve the wait counter

    ; see if we're still calculating the score
    ; and if so, extend the waitloop for another frame
    ; that way, once the bonus has finished transferring to the score
    ; we'll still wait for our full two seconds.
    ld a,(ScoreInc)
    cp a,0
    jr z,ScoreFinished
    inc b                   ; some score left to transfer, so increment the wait counter
ScoreFinished:
    djnz PostGameWait

; At this point the bonus transfer has finished and we've finished waiting.
; Now we need to move on to the next maze and reset everything to begin playing it.

    ld a,(curr_maze)        ; get the current maze index
    inc a                   ; increment it
    ld c,a                  ; save the new value
    add a,a                 ; double it as we're going to use it to index into the table of maze pointers which are two bytes apiece
    ld e,a                  ; copy index into de
    ld d,0
    ld ix,map_table         ; start of maze pointer table
    add ix,de               ; add the index
    ld a,(ix+0)             ; merge two bytes of pointer
    or a,(ix+1)             ; so we can test if it's zero or not
    ld a,c                  ; retrieve curr_maze+1, (doesn't affect flags)
    jr nz,NotFinished       ; not zero, so we've not run out of mazes yet

    ld a,0                  ; otherwise, reset the maze index back to the first one and start again.
NotFinished:
    ld (curr_maze),a        ; save the updated maze index
    jp StartLevel           ; start the next level

; If execution reaches this point, the player has died.
PlayerDead:
    call ClearInfoArea      ; clear the info area below the maze
    ld ix,OopsText          ; draw the 'Oops!" text
    ld b,(32-5)/2
    ld c,23
    call PrintText

; wait for a couple of seconds to give the player time to realise
; what's happening, also process any pending score_inc values.
    ld b,100
PlayerDeadWait:
    halt
    call UpdateScore
    djnz PlayerDeadWait

    ld a,(num_lives)            ; get the current number of lives count
    sub a,1                     ; decrement it
    ld (num_lives),a            ; save the new count (this doesn't affect flags)
    jp nc,StartLevel            ; if there was no carry, we've not run out of lives, so restart the current level

; If execution reaches here, we've run out of lives and the game is over

    call ClearInfoArea          ; clear the info area below the maze
    ld ix,GameOverText          ; draw the "Game Over" text.
    ld b,(32-9)/2
    ld c,22
    call PrintText
    call DrawScore
; wait for a couple of seconds

    ld b,100
GameOverWait:
    halt
    call UpdateScore
    djnz GameOverWait

    ; return to the start screen
    jp GameLogic