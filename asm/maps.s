;-------------------------------------------------------------------------
; Name: maps.s
;-------------------------------------------------------------------------
; Author: Steve Monks
;-------------------------------------------------------------------------
; Description:
; This file contains all of the mazes used in the game. Each maze is
; defined by a 16x11 block of ASCII characters, each one represents either
; a 16x16 pixel tile or 16x16 pixel sprite. The displayed screen is 15x11
; 16x16 pixel tiles, but these are padded out to 16 bytes wide to simplify
; indexing into them.
;
;
; The character assignment is;
; '*' - maze wall
; ' ' - maze floor
; 'c' - cheese
; 'm' - cat (c was already taken!)
; 'h' - hole
; 'p' - player start
; '.' - an blank location (used in row padding)
;-------------------------------------------------------------------------

MAPHEIGHT=11
MAPWIDTH=16
; Note: maps are padded to 16 chars to simplify tile lookup from
; pixel coords
map0:
	db  "***************."
	db  "* c    m    c *."
	db  "* *** *** *** *."
	db  "* *   h *   * *."
	db  "* * *** * * * *."
	db  "*h  *     *  h*."
	db  "* * * * *** * *."
	db  "* *   *p    * *."
	db  "* *** *** *** *."
	db  "* c    m    c *."
	db  "***************."


map1:
	db  "***************."
	db  "* c    *    c *."
	db  "* *** *** *** *."
	db  "*   *  h  *   *."
	db  "* * * * * * * *."
	db  "*h*m  * *  m*h*."
	db  "* * * * * * * *."
	db  "*   *  p  *   *."
	db  "* *** *** *** *."
	db  "* c    *    c *."
	db  "***************."

map2:
	db  "***************."
	db  "*      c      *."
	db  "*h* * * * *m*h*."
	db  "* * * * * * * *."
	db  "* * * * * * * *."
	db  "*c     p     c*."
	db  "* * * * * * * *."
	db  "* * * * * * * *."
	db  "*h*m* * * * *h*."
	db  "*      c      *."
	db  "***************."

map3:
	db  "***************."
	db  "*c     *h    c*."
	db  "* **** * **** *."
	db  "*    * *   ** *."
	db  "* ** * * * ** *."
	db  "*m**h* p *h**m*."
	db  "* ** * * * ** *."
	db  "* **   * *    *."
	db  "* **** * **** *."
	db  "*c    h*     c*."
	db  "***************."

map4:
	db  "***************."
	db  "* c    m    c *."
	db  "* *** *** *** *."
	db  "* *   h *   * *."
	db  "* * *** *** * *."
	db  "*h           h*."
	db  "* * *** *** * *."
	db  "* *   *p    * *."
	db  "* *** *** *** *."
	db  "*mc         cm*."
	db  "***************."


map5:
	db  "***************."
	db  "* c    *m   c *."
	db  "* *** *** *** *."
	db  "*   *  h  *   *."
	db  "* * * * * * * *."
	db  "*h*m  * *  m*h*."
	db  "* * * * * * * *."
	db  "*   *  p  *   *."
	db  "* *** *** *** *."
	db  "* c    *    c *."
	db  "***************."

map6:
	db  "***************."
	db  "*     mc      *."
	db  "*h* * * * *m*h*."
	db  "* * * * * * * *."
	db  "* * * * * * * *."
	db  "*c     p     c*."
	db  "* * * * * * * *."
	db  "* * * * * * * *."
	db  "*h*m* * * * *h*."
	db  "*      c      *."
	db  "***************."

map7:
	db  "***************."
	db  "*c     *h    c*."
	db  "* **** * **** *."
	db  "*    * *   ** *."
	db  "* ** * * *    *."
	db  "*m**h* p *h**m*."
	db  "*    * * * ** *."
	db  "* **   * *    *."
	db  "* **** * **** *."
	db  "*c    h*m    c*."
	db  "***************."

