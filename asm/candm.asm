;-------------------------------------------------------------------------
; Name: candm.asm
;-------------------------------------------------------------------------
; Description:
; Basic template for Zeus. This configures various Zeus parameters
; and controls the layout of code and data in memory. All code and data
; is added to the project here via the "include" directives below.
;-------------------------------------------------------------------------

AppFilename             equ "candm"                     ; What we're called (for file generation)

AppFirst                equ $8000                       ; First byte of code (uncontended memory)

                        zeusemulate "Next","RAW"        ; Set the model


; Start planting code here. (When generating a tape file we start saving from here)

                        org AppFirst                    ; Start of application

AppEntry                nop

                        include "nextreg.i"
                        include "next.s"
                        include "gamelogic.s"
                        include "gameobj.s"
                        include "ai.s"
                        include "SetupLevel.s"
                        include "tilewriter.s"
                        include "player.s"
                        include "cat.s"
                        include "cheese.s"
                        include "hole.s"
                        include "textwriter.s"

                        include "maps.s"
game_sprites:
                        include "gamesprites.s"

; set address of hardware tilemap memory in page 5 (the 16K bank from 16K to 32K)
; hardware requires this to be 256 byte aligned
                        org $6000
tile_map_data:          ds 1280                 ; reserve space for the 40x32 tilemap used by the hardware

; tile map patterns - these must start at a 256 byte aligned address.
; for convenience I'm sticking them immediately after the tilemap buffer
; which is 5x256 byte pages
tile_map_patterns:
                        include "backg.s"       ; tiles 256 byte aligned immediately following tile map
                        include "glyphs.s"      ; font glyph tiles, these follow on in memory from background ones
                        jp AppEntry             ; I suspect this isn't needed, particularly as I've stuffed a bunch of data right in front of it.


; Stop planting code after this. (When generating a tape file we save bytes below here)
AppLast                 equ *-1                         ; The last used byte's address

; Generate some useful debugging commands

                        profile AppFirst,AppLast-AppFirst+1     ; Enable profiling for all the code

; Setup the emulation registers, so Zeus can emulate this code correctly

Zeus_PC                 equ AppEntry                            ; Tell the emulator where to start
Zeus_SP                 equ $FF40                               ; Tell the emulator where to put the stack

; These generate some output files

                        ; Generate a SZX file
                        ;output_szx AppFilename+".szx",$0000,AppEntry    ; The szx file

                        ; If we want a fancy loader we need to load a loading screen
                        ;import_bin AppFilename+".scr",$4000            ; Load a loading screen

                        ; Now, also generate a tzx file using the loader
                        ;output_tzx AppFilename+".tzx",AppFilename,"",AppFirst,AppLast-AppFirst,1,AppEntry ; A tzx file using the loader

                        ; Now, also generate a tap file using the loader
                        ;output_tap AppFilename+".tap",AppFilename,"",AppFirst,AppLast-AppFirst,1,AppEntry ; A tap file using the loader

                        ; output a sna file as that seems to be the only thing CSpect can load
                        output_sna AppFilename+".snx"

                        ; output a .nex file. This is only supported in the test variants of Zeus at the time of writing.
                        ;output_nex AppFilename+".nex",$FF40,AppEntry

