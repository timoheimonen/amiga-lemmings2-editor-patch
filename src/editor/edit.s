; Lemmings 2: The Tribes In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; The edit view: the level in the game's own play view with the editor bar
; below the skill panel. This file has the view's entry and exit, its loop
; and frame interrupt, the fades, scrolling, the mouse and the keys, the
; Terrain mode (the brush, Pick and the pieces page), the frames drawn over
; the view, saving and the question before leaving, and the bar's help and
; status lines and widget states. The other modes and tools have files of
; their own: the Objects mode is objects.s, the Param mode (the level's
; parameters; MODE_LEVEL and the level_ routines in the code) is level.s,
; and undo, redo and test play are undo.s; bar.s draws the bar. editor.s
; includes this file.
;
; A level is opened for editing as it is opened for play (start_edit): the
; game builds it, and the first pass of its play loop jumps to the editor
; (hook_frame) instead of playing. The editor's loop then does what the
; play loop does for the display (scrolling, the view copy, the objects,
; the redraw of changed cells) but releases no lemmings, and its own frame
; interrupt swaps the display buffers without running the clock. Objects
; are made again from the record when the view opens (the build ran one
; update of them) and drawn as the game draws them while paused, without
; animation, so that nothing but the editor writes the play map. The
; Param mode's skill picker leaves the edit view and builds it again
; (edit_rebuild, level.s) with the editor's state kept.
;
; The record in edit_record is the level being edited; it is what is saved.
; A terrain edit writes cells into it, and the play map is made again from
; the record with the objects over it (objects_apply); the cells that
; changed carry bit 31, and the game's own pass ($21A4) redraws them. The
; play map is only the display: objects and their animations write it too.
;
; Game addresses are offsets in the game's hunk 0 unless another hunk is
; named; A5 is the game's globals, A6 $dff000. GCALL name calls the game
; routine G_NAME through g_name, its address in memory, which editor.s
; sets up.

; Game routines, hunk 0
G_WAIT_PLAY     equ $013a2      ; wait until the interrupt took the last pass
G_SCROLL        equ $02394      ; the play loop's scrolling
G_COPY_VIEW     equ $01f10      ; the view into the back display buffer
G_VIEW_DESC     equ $003f8      ; the play display descriptor follows the scroll
G_OBJECTS       equ $0ca62      ; the objects' animation and sprites
G_REDRAW        equ $021a4      ; draw the cells marked with bit 31
G_BUTTONS       equ $009a2      ; mouse buttons into A5+$1BC..$1C2
G_KEY           equ $00f54      ; the next key (its character), with repeat
G_PLAY_POINTER  equ $01798      ; pointer A5+$21E in the play display
G_PLANES        equ $0129c      ; the play display's plane pointers, a field
G_WAIT_FRAME    equ $0138a      ; wait for the next field
G_MUSIC_OFF     equ $13c10
G_MUSIC_ON      equ $13bea
G_IDLE          equ $00f88      ; rts: the frame callback outside play
G_VIDEO         equ $00cb6      ; Tab: the display and the clock to PAL or NTSC
R_LOOP_REST     equ $0014e      ; the play loop after its scrolling

; Patch points, hunk 0
P_FRAME         equ $00146      ; bsr.w G_WAIT_PLAY / bsr.w G_SCROLL
P_SPRITE_POS    equ $014ec      ; moveq #0,d0 / addi.w #$2c,d2 / lsl.w #8,d2

SCROLL_FLAGS    equ $1c662      ; hunk 0: scroll of each buffer's last pass

; Hunk 1: the play display's copper list, the play colours and pointer
COP_PLAY_COLOURS equ $00034     ; its first colour move
COP_DIWSTOP     equ $00100      ; move DIWSTOP,$f4c2
COP_PLAY_END    equ $001c4      ; its end, $fffffffe
PAL_PLAY        equ $00838      ; the colours play fades in to
PTR_CROSS       equ $0449c      ; the play pointer
DIWSTOP_PLAY    equ $f4c2
DIWSTOP_EDIT    equ $24c2       ; 48 more lines: line $124
COPJMP2         equ $008a0000   ; move COPJMP2: continue at COP2LC

; Game globals (A5)
G_FIELDS        equ $fc
G_SCROLL_X      equ $fe
G_SCROLL_Y      equ $100
G_COLUMNS       equ $10c
G_ROWS          equ $10e
G_BUFFER        equ $116
G_CURSOR_MAX_Y  equ $156
G_LEFT_DOWN     equ $1bc
G_LEFT_CLICK    equ $1be
G_RIGHT_DOWN    equ $1c0
G_RIGHT_CLICK   equ $1c2
G_PAUSE         equ $1c9
G_SCROLLED      equ $1ca
G_PASS_DONE     equ $1cb
G_NTSC          equ $1cf            ; set while Tab has chosen NTSC
G_REDRAW_ALL    equ $1e8
G_MUSIC         equ $1eb
G_FRONT         equ $1ee
G_BACK          equ $1f2
G_CALLBACK      equ $222
G_LEVEL_PASSES  equ $25e            ; passes since the level started ($196)
G_TILES         equ $24e
G_MAP           equ $262
G_MODIFIERS     equ $2aa            ; shift, alt, control, amiga
G_KEY_NEW       equ $2ae
G_HELD_KEY      equ $2af

; The display buffers: four planes of 44-byte rows, 352x192 pixels; the
; screen shows them from (16,16), the cursor's (0,0).
VIEW_ROW        equ 44
VIEW_PLANE      equ $2100
VIEW_ROWS       equ 192
VIEW_WORDS      equ 22
VIEW_EDGE       equ 16
SCREEN_ROWS     equ 160             ; the play area; then the panel and the bar
MENU_MAX_Y      equ $c9             ; the cursor's range in play ($E58A)
CURSOR_BOTTOM   equ BAR_CURSOR_Y+BAR_H-1
CELL_SHIFT_X    equ 4               ; cells are 16x8 pixels
CELL_SHIFT_Y    equ 3
FADE_STEPS      equ 16
MESSAGE_PASSES  equ 40              ; about three seconds

; The record
R_MAP           equ $74             ; L2MP payload: 1971 BE32 cells
CELL_TILE       equ $3ff
CELL_STEEL      equ 28              ; indestructible
CELL_DECOR      equ 30              ; non-colliding

; Keys: the characters of the game's key map ($38762)
KEY_UP          equ 1
KEY_DOWN        equ 2
KEY_LEFT        equ 3
KEY_RIGHT       equ 4
KEY_RETURN      equ 13
KEY_ESC         equ $11

; Pages of the edit view
PAGE_EDIT       equ 0
PAGE_PIECES     equ 1
PAGE_QUESTION   equ 2
PAGE_TYPES      equ 3

; The pieces page: the style's L2BE sheet, 20 cells wide
SHEET_COLS      equ 20
SHEET_MAX_ROWS  equ 96
SHEET_VIEW      equ SCREEN_ROWS>>CELL_SHIFT_Y
MAX_PIECES      equ 256
NO_PIECE        equ $ff
TILE_DEFAULTS   equ 1024            ; per style: a byte for each tile index
STYLE_COUNT     equ 12

; Widget ids
ID_TERRAIN      equ 1
ID_OBJECTS      equ 2
ID_LEVEL        equ 3
ID_TEST         equ 4
ID_UNDO         equ 5
ID_REDO         equ 6
ID_SAVE         equ 7
ID_MENU         equ 8
ID_PIECES       equ 9
ID_ERASE        equ 10
ID_PICK         equ 11
ID_DECOR        equ 12
ID_STEEL        equ 13
ID_BACK         equ 14
ID_UP           equ 15
ID_DOWN         equ 16
ID_Q_SAVE       equ 17
ID_Q_DISCARD    equ 18
ID_Q_CANCEL     equ 19
ID_TYPES        equ 20              ; the Objects mode's tools
ID_DELETE       equ 21
ID_WIDE_LESS    equ 22
ID_WIDE_MORE    equ 23
ID_HIGH_LESS    equ 24
ID_HIGH_MORE    equ 25
ID_PREVIOUS     equ 26
ID_NEXT         equ 27
ID_TITLE        equ 28              ; the Param mode's tools
ID_SKILLS       equ 29
ID_REMOVE       equ 30
ID_COUNT_LESS   equ 31
ID_COUNT_MORE   equ 32
ID_SLOT_PREV    equ 33
ID_SLOT_NEXT    equ 34
ID_VIEW         equ 35
ID_TIME_LESS    equ 36
ID_TIME_MORE    equ 37
ID_RATE_LESS    equ 38
ID_RATE_MORE    equ 39
ID_LOST_LESS    equ 40
ID_LOST_MORE    equ 41
ID_T_OK         equ 42              ; the title page
ID_T_CANCEL     equ 43
ID_Q_TEST       equ 44              ; the question before test play
ID_LIMITS       equ 45              ; the Param mode's Limits
ID_L_TOP        equ 46              ; the limits page
ID_L_BOTTOM     equ 47
ID_L_WHOLE      equ 48
ID_L_OK         equ 49
ID_L_CANCEL     equ 50
ID_BRUSH        equ W_TEXT+1
ID_QUESTION     equ W_TEXT+2
ID_SHEET        equ W_TEXT+3
ID_TYPE         equ W_TEXT+4
ID_WIDE         equ W_TEXT+5
ID_HIGH         equ W_TEXT+6
ID_TYPES_INFO   equ W_TEXT+7
ID_COUNT        equ W_TEXT+8
ID_TIME         equ W_TEXT+9
ID_RATE         equ W_TEXT+10
ID_LOST         equ W_TEXT+11
ID_TITLE_TEXT   equ W_TEXT+12
ID_LIMITS_TEXT  equ W_TEXT+13

WIDGET  macro                       ; x, y, width, id, label, help
        dc.w \1,\2,\3,\4
        dc.l \5,\6
        endm

COMMON_ROW macro                    ; the modes and the common buttons
        WIDGET 2,ROW_A,46,ID_TERRAIN,s_terrain,h_terrain
        WIDGET 50,ROW_A,46,ID_OBJECTS,s_objects,h_objects
        WIDGET 98,ROW_A,34,ID_LEVEL,s_level_mode,h_level
        WIDGET 134,ROW_A,28,ID_TEST,s_test,h_test
        WIDGET 200,ROW_A,28,ID_UNDO,s_undo,h_undo
        WIDGET 230,ROW_A,28,ID_REDO,s_redo,h_redo
        WIDGET 260,ROW_A,28,ID_SAVE,s_save,h_save
        WIDGET 290,ROW_A,28,ID_MENU,s_menu,h_menu
        endm

        section editor,code

;============================================================================
; Opening a level for editing

; The selected entry: D0 = 0, or -1 when its file is not a valid record.
start_edit:
        bsr load_selected
        tst.w d0
        bmi.s .fail
        move.w d0,-(sp)
        lea record_buffer,a0
        lea edit_record,a1
        bsr copy_record
        lea path,a0
        lea edit_path,a1
.path:  move.b (a0)+,(a1)+
        bne.s .path
        sf dirty
        st editing
        bsr history_reset               ; undo starts at the file
        lea record_buffer,a0            ; a skill the style cannot use is
        bsr skills_fit                  ; taken out: undo starts without
        move.w d1,skills_fitted         ; it, and the file stays the saved
        beq.s .fits                     ; record, so the level is unsaved
        lea record_buffer,a0
        lea edit_record,a1
        bsr copy_record
        lea record_buffer,a0
        lea undo_base,a1
        bsr copy_record
        st dirty
.fits:  move.w (sp)+,d0
        bsr enter_level
        moveq #0,d0
        rts
.fail:  moveq #-1,d0
        rts

; Jumped to from P_FRAME on every pass of the play loop: the edit view
; instead of play when a level was opened for editing.
hook_frame:
        tst.b editing
        bne.s edit_enter
        move.l r_loop_rest,-(sp)        ; as the original: wait, scroll, go on
        move.l g_scroll,-(sp)
        move.l g_wait_play,-(sp)
        rts

; The first pass: the editor takes the frame interrupt and shows its bar.
; The bar lies below the play view, in lines only a PAL display shows: when
; Tab chose NTSC in the game's play, the game's own switch goes back to PAL
; (display and clock) first.
edit_enter:
        tst.b G_NTSC(a5)
        beq.s .pal
        GCALL video
.pal:   move.b #SCREEN_EDIT,screen
        sf leaving
        sf skills_wanted
        lea edit_irq(pc),a0
        move.l a0,G_CALLBACK(a5)
        move.w #FADE_STEPS,fade_in
        bsr bar_show
        move.w #CURSOR_BOTTOM,G_CURSOR_MAX_Y(a5)
        bsr view_limits
        bsr frame_colours
        tst.b resuming
        beq.s .fresh
        sf resuming                     ; built again (edit_rebuild): the
        move.w resume_x,jump_scroll_x   ; editor's state is kept, the view
        move.w resume_y,jump_scroll_y   ; moves back where it was
        st scroll_jump
        sf dragging                     ; no press goes on from before
        sf stroke
        bsr panel_highlight
        bra .scan
.fresh: clr.w message_passes
        bsr skills_fit_notice
        clr.w level_slot
        bsr pieces_find
        move.w #-1,brush_index
        tst.w piece_count
        beq.s .no_pieces
        moveq #1,d0                     ; the first piece of the sheet
        cmp.w piece_count,d0
        blo.s .first
        moveq #0,d0
.first: bsr brush_piece
        bra.s .brush
.no_pieces:
        moveq #1,d0                     ; no pieces: tile 1
        bsr brush_tile
.brush: sf erase
        sf pick
        sf mode                         ; Terrain first
        sf dragging
        sf scroll_jump
        clr.w obj_type
        move.w #-1,sel_slot
        move.w #-1,hover_slot
        clr.w anim_tick
        bsr types_init
.scan:  bsr objects_apply               ; the objects at their first frame:
        move.b #PAGE_EDIT,edit_page     ; the build ran their update ($118)
        bsr mode_widgets
        move.w #-1,pointer_shape
        tst.b ask_on_entry              ; Levels on test play's result page
        beq.s .loop                     ; with unsaved changes: the question
        sf ask_on_entry                 ; before leaving comes first
        bsr ask_leave
.loop:
        ; fall through

;============================================================================
; The edit view's loop: one pass per display buffer, as the play loop.

edit_loop:
        GCALL wait_play
        cmp.b #PAGE_PIECES,edit_page
        beq pieces_pass
        cmp.b #PAGE_TYPES,edit_page
        beq types_pass
        bsr edit_scroll
        GCALL copy_view
        GCALL view_desc
        st G_PAUSE(a5)                  ; objects drawn, not animated
        GCALL objects
        sf G_PAUSE(a5)
        GCALL redraw
        GCALL buttons
        tst.b G_LEFT_DOWN(a5)           ; released: no stroke and no held
        bne.s .pressed                  ; button goes on, whatever page the
        sf stroke                       ; press began on
        move.w #-1,held_widget
.pressed:
        bsr read_key
        bsr update_pointer
        cmp.b #PAGE_QUESTION,edit_page
        beq.s .question
        cmp.b #PAGE_TITLE,edit_page
        beq.s .title
        cmp.b #PAGE_LIMITS,edit_page
        beq.s .limits
        move.b mode,d0
        beq.s .terrain
        cmp.b #MODE_OBJECTS,d0
        beq.s .objects
        bsr level_input
        bsr draw_level_ui
        bra.s .bar
.terrain:
        bsr edit_input
        bsr draw_brush
        bra.s .bar
.objects:
        bsr objects_input
        bsr draw_objects_ui
        bra.s .bar
.title: bsr title_input
        bra.s .bar
.limits:
        bsr limits_input
        bsr draw_limits_ui
        bra.s .bar
.question:
        bsr question_input
.bar:   bsr edit_help
        bsr edit_status
        bsr bar_refresh
        bsr undo_settle
        st G_PASS_DONE(a5)
        tst.b leaving
        bne edit_exit
        tst.b skills_wanted
        bne skills_flow
        tst.b test_wanted
        bne test_flow
        bra edit_loop

; Leaving: the view fades out as play does, the game's copper list and
; frame interrupt are put back, then the list.
edit_exit:
        bsr view_fade_out
        bsr bar_hide
        move.l g_idle,G_CALLBACK(a5)
        GCALL music_off
        move.w #MENU_MAX_Y,G_CURSOR_MAX_Y(a5)
        sf editing
        clr.b screen
        bra list_flow

; The play colours and the bar faded to black, as play fades out.
view_fade_out:
        moveq #FADE_STEPS-1,d0
.fade:  move.w d0,-(sp)
        GCALL wait_frame
        bsr fade_down
        move.w (sp)+,d0
        dbra d0,.fade
        rts

; The frame interrupt while editing (A5+$222, from the game's vertical
; blank handler with D0 = the field count A5+$FC): the play interrupt
; ($11D0) without the clock and the level start's fade, which the editor
; does itself; COP2LC is set every field.
edit_irq:
        move.l bar_copper,$84(a6)
        cmp.w #4,d0
        blt.s .planes
        tst.b G_PASS_DONE(a5)
        beq.s .wait
        clr.b G_PASS_DONE(a5)           ; a pass is ready: show it
        clr.w G_FIELDS(a5)
        move.l G_BACK(a5),d1
        move.l G_FRONT(a5),G_BACK(a5)
        move.l d1,G_FRONT(a5)
        eori.w #1,G_BUFFER(a5)
        bra.s .planes
.wait:  move.w #4,G_FIELDS(a5)
.planes:
        GCALL planes
        tst.w fade_in
        beq.s .done
        subq.w #1,fade_in
        bsr fade_up
.done:  rts

;----------------------------------------------------------------------------
; The bar on the screen

; The play list jumps to the bar's list instead of ending, and the display
; window reaches line $124. COP2LC is set before the jump is written.
bar_show:
        bsr bar_init
        move.l bar_copper,$84(a6)
        movea.l hunk1,a0
        move.w #DIWSTOP_EDIT,COP_DIWSTOP+2(a0)
        move.l #COPJMP2,COP_PLAY_END(a0)
        rts

bar_hide:
        movea.l hunk1,a0
        move.l #$fffffffe,COP_PLAY_END(a0)
        move.w #DIWSTOP_PLAY,COP_DIWSTOP+2(a0)
        rts

; One step of the fade in: the play colours to the colours play fades in to
; (as the play interrupt does, $1286), the bar's to the UI palette.
fade_up:
        movea.l pal_play,a0
        bsr play_colours
        bsr fade_step
        lea ui_palette(pc),a0
        bra.s bar_colours

fade_down:
        lea black,a0
        bsr play_colours
        bsr fade_step
        lea black,a0
bar_colours:
        movea.l bar_copper,a1
        lea BAR_COLOURS_END(a1),a2
        lea BAR_COLOURS(a1),a1
        bra.s fade_step

play_colours:                           ; -> A1..A2 the play colour moves
        movea.l hunk1,a1
        lea COP_PLAY_END(a1),a2
        lea COP_PLAY_COLOURS(a1),a1
        rts

; Moves each colour of the copper list A1..A2 one step toward its colour in
; A0 (one per colour move, in order), as the game's fade $E61C does.
fade_step:
.move:  cmpa.l a2,a1
        bhs.s .done
        move.w (a1)+,d0
        cmp.w #COLOR00,d0
        blo.s .next
        cmp.w #COLOR31,d0
        bhi.s .next
        move.w (a0)+,d1                 ; target
        move.w (a1),d2                  ; current
        moveq #2,d3
        moveq #$f,d4
        moveq #1,d5
.nibble:
        move.w d1,d6
        and.w d4,d6
        move.w d2,d7
        and.w d4,d7
        cmp.w d6,d7
        beq.s .same
        bhi.s .lower
        add.w d5,d2
        bra.s .same
.lower: sub.w d5,d2
.same:  lsl.w #4,d4
        lsl.w #4,d5
        dbra d3,.nibble
        move.w d2,(a1)
.next:  addq.l #2,a1
        bra.s .move
.done:  rts

;----------------------------------------------------------------------------
; Scrolling

; The scroll range of the whole map: the screen shows map pixels from the
; scroll position + 16 on, 320x160 of them, inside the map's border cells.
view_limits:
        move.w G_COLUMNS(a5),d0
        sub.w #VIEW_WORDS,d0
        lsl.w #CELL_SHIFT_X,d0
        move.w d0,max_scroll_x
        move.w G_ROWS(a5),d0
        lsl.w #CELL_SHIFT_Y,d0
        sub.w #VIEW_ROWS,d0
        move.w d0,max_scroll_y
        move.w G_SCROLL_X(a5),d0
        and.w #-16,d0
        cmp.w max_scroll_x,d0
        ble.s .x
        move.w max_scroll_x,d0
.x:     move.w d0,G_SCROLL_X(a5)
        move.w G_SCROLL_Y(a5),d0
        and.w #-16,d0
        cmp.w max_scroll_y,d0
        ble.s .y
        move.w max_scroll_y,d0
.y:     move.w d0,G_SCROLL_Y(a5)
        rts

; 16 pixels a pass while the pointer is at the left, right or top edge of
; the play area or at the bottom of its range, or a cursor key is held: the
; game's own scrolling ($2394) with the editor's limits. The flags tell
; the frame interrupt to scroll the display smoothly over the pass: the
; back buffer is drawn at the new scroll, and the interrupt shows it from
; the old one, 4 pixels on each field. $2394 leaves A5+$1CA clear (its
; tail call to $1F10 clears it), so that the view is copied on every
; pass; set, the copy is skipped and the display jumps back and forth.
edit_scroll:
        bsr scroll_flags_clear
        tst.b scroll_jump               ; the view moves to an object
        beq.s .wanted
        sf scroll_jump
        move.w jump_scroll_x,G_SCROLL_X(a5)
        move.w jump_scroll_y,G_SCROLL_Y(a5)
        bra.s .copy
.wanted:
        bsr scroll_wanted
        move.w G_SCROLL_X(a5),d1
        move.w G_SCROLL_Y(a5),d2
        btst #0,d3
        beq.s .right
        cmp.w #16,d1
        blt.s .vertical
        sub.w #16,d1
        st 1(a4)
        bra.s .vertical
.right: btst #1,d3
        beq.s .vertical
        move.w d1,d0
        add.w #16,d0
        cmp.w max_scroll_x,d0
        bgt.s .vertical
        move.w d0,d1
        st (a4)
.vertical:
        btst #2,d3
        beq.s .down
        cmp.w #16,d2
        blt.s .store
        sub.w #16,d2
        st 2(a4)
        bra.s .store
.down:  btst #3,d3
        beq.s .store
        move.w d2,d0
        add.w #16,d0
        cmp.w max_scroll_y,d0
        bgt.s .store
        move.w d0,d2
        st 3(a4)
.store: move.w d1,G_SCROLL_X(a5)
        move.w d2,G_SCROLL_Y(a5)
.copy:  sf G_SCROLLED(a5)
        rts

scroll_flags_clear:                     ; -> A4 the back buffer's flags
        move.w G_BUFFER(a5),d0
        lsl.w #2,d0
        movea.l scroll_flags,a4
        adda.w d0,a4
        clr.l (a4)
        rts

; -> D3: bit 0 left, 1 right, 2 up, 3 down.
scroll_wanted:
        moveq #0,d3
        move.b G_HELD_KEY(a5),d0        ; a held cursor key goes first: the
        cmp.b #KEY_LEFT,d0              ; pointer may rest on the other edge
        bne.s .key_right
        bset #0,d3
.key_right:
        cmp.b #KEY_RIGHT,d0
        bne.s .key_up
        bset #1,d3
.key_up:
        cmp.b #KEY_UP,d0
        bne.s .key_down
        bset #2,d3
.key_down:
        cmp.b #KEY_DOWN,d0
        bne.s .pointer
        bset #3,d3
.pointer:
        tst.w d3
        bne.s .done
        move.w G_CURSOR_X(a5),d0
        move.w G_CURSOR_Y(a5),d1
        cmp.w #SCREEN_ROWS,d1
        bhs.s .bottom
        tst.w d0
        bne.s .right
        bset #0,d3
.right: cmp.w #BAR_W-1,d0
        bne.s .top
        bset #1,d3
.top:   tst.w d1
        bne.s .done
        bset #2,d3
        bra.s .done
.bottom:
        cmp.w #CURSOR_BOTTOM,d1
        bne.s .done
        bset #3,d3
.done:  rts

;----------------------------------------------------------------------------
; Input

; The next key into D0 (lower case), 0 when none.
read_key:
        GCALL key
        and.w #$ff,d0
        move.w d0,key_char
        cmp.b #'A',d0
        blo.s .done
        cmp.b #'Z',d0
        bhi.s .done
        or.b #$20,d0
.done:  move.w d0,key
        rts

; The play pointer over the map, the arrow over the panel and the bar.
update_pointer:
        moveq #0,d0
        cmp.w #SCREEN_ROWS,G_CURSOR_Y(a5)
        blo.s .map
        moveq #1,d0
.map:   cmp.w pointer_shape,d0
        beq.s .done
        move.w d0,pointer_shape
        tst.w d0
        bne.s .arrow
        move.l ptr_cross,G_POINTER_DATA(a5)
        move.w #16,G_POINTER_H(a5)
        bra.s .show
.arrow: move.l ptr_normal,G_POINTER_DATA(a5)
        move.w #POINTER_HEIGHT,G_POINTER_H(a5)
.show:  GCALL play_pointer
.done:  rts

; Mouse and keys in the edit view.
edit_input:
        bsr widget_at
        move.w d0,hover
        move.w key,d0
        beq.s .mouse
        bsr edit_key
.mouse: tst.b G_LEFT_CLICK(a5)
        beq.s .held
        sf stroke                       ; a stroke starts only in the map
        cmp.w #SCREEN_ROWS,G_CURSOR_Y(a5)
        blo map_click
        move.w hover,d0
        bmi.s .done
        bra widget_click
.held:  tst.b G_LEFT_DOWN(a5)
        beq.s .right
        cmp.w #SCREEN_ROWS,G_CURSOR_Y(a5)
        blo map_stroke
.right: tst.b G_RIGHT_CLICK(a5)
        beq.s .done
        cmp.w #SCREEN_ROWS,G_CURSOR_Y(a5)
        bhs.s .done
        bra toggle_erase
.done:  rts

; A click on the button D0: its action unless it is disabled.
widget_click:
        bsr widget_state
        cmp.w #ST_DISABLED,d5
        beq.s .done
        move.w d0,-(sp)
        bsr bar_sound
        move.w (sp)+,d0
        bra widget_action
.done:  rts

widget_action:
        cmp.w #ID_Q_TEST,d0             ; above the Param mode's tools
        beq test_go
        cmp.w #ID_TITLE,d0
        bhs level_action
        cmp.w #ID_TERRAIN,d0
        beq set_terrain
        cmp.w #ID_OBJECTS,d0
        beq set_objects
        cmp.w #ID_LEVEL,d0
        beq set_level
        cmp.w #ID_TEST,d0
        beq test_ask
        cmp.w #ID_UNDO,d0
        beq undo
        cmp.w #ID_REDO,d0
        beq redo
        cmp.w #ID_SAVE,d0
        beq save_level
        cmp.w #ID_MENU,d0
        beq ask_leave
        cmp.w #ID_PIECES,d0
        beq open_pieces
        cmp.w #ID_ERASE,d0
        beq toggle_erase
        cmp.w #ID_PICK,d0
        beq toggle_pick
        cmp.w #ID_DECOR,d0
        beq toggle_decor
        cmp.w #ID_STEEL,d0
        beq toggle_steel
        cmp.b #PAGE_TYPES,edit_page
        beq.s .types_page
        cmp.w #ID_BACK,d0
        beq close_pieces
        cmp.w #ID_UP,d0
        beq sheet_up
        cmp.w #ID_DOWN,d0
        beq sheet_down
        bra.s .question
.types_page:
        cmp.w #ID_BACK,d0
        beq close_types
        cmp.w #ID_UP,d0
        beq types_up
        cmp.w #ID_DOWN,d0
        beq types_down
.question:
        cmp.w #ID_Q_SAVE,d0
        beq save_and_leave
        cmp.w #ID_Q_DISCARD,d0
        beq leave_now
        cmp.w #ID_Q_CANCEL,d0
        beq close_question
        cmp.w #ID_TYPES,d0
        beq open_types
        cmp.w #ID_DELETE,d0
        beq delete_selected
        cmp.w #ID_WIDE_LESS,d0
        beq wide_less
        cmp.w #ID_WIDE_MORE,d0
        beq wide_more
        cmp.w #ID_HIGH_LESS,d0
        beq high_less
        cmp.w #ID_HIGH_MORE,d0
        beq high_more
        cmp.w #ID_PREVIOUS,d0
        beq select_previous
        cmp.w #ID_NEXT,d0
        beq select_next
        rts

; D0 a key in the edit view: the common keys, then the mode's.
edit_key:
        cmp.b #'t',d0
        beq set_terrain
        cmp.b #'o',d0
        beq set_objects
        cmp.b #'l',d0
        beq set_level
        cmp.b #'e',d0
        beq test_ask
        cmp.b #'u',d0
        beq undo_key
        cmp.b #'s',d0
        beq.s .save
        cmp.b #KEY_ESC,d0
        beq ask_leave
        cmp.b #'m',d0
        beq toggle_music
        cmp.b #MODE_OBJECTS,mode
        beq objects_key
        cmp.b #MODE_LEVEL,mode
        beq level_key
        cmp.b #'p',d0
        beq open_pieces
        cmp.b #'r',d0
        beq toggle_erase
        cmp.b #'k',d0
        beq toggle_pick
        cmp.b #'d',d0
        beq toggle_decor
        cmp.b #'i',d0
        beq toggle_steel
        rts
.save:  tst.b dirty
        bne save_level
        rts

; The Terrain, Objects and Param modes: their tools in the bar.
set_terrain:
        moveq #MODE_TERRAIN,d0
        bra.s set_mode
set_objects:
        moveq #MODE_OBJECTS,d0
        bra.s set_mode
set_level:
        moveq #MODE_LEVEL,d0
set_mode:
        cmp.b mode,d0
        beq.s mode_same
        move.b d0,mode
        sf dragging
        sf stroke
        clr.w anim_tick                 ; the preview from its first frame
        ; fall through

; The current mode's widgets in the bar; the Param mode's second row of
; tools takes the status line's place.
mode_widgets:
        lea edit_widgets(pc),a0
        sf status_hidden
        move.b mode,d0
        beq.s .table
        lea objects_widgets(pc),a0
        cmp.b #MODE_OBJECTS,d0
        beq.s .table
        lea level_widgets(pc),a0
        st status_hidden
.table: move.l a0,widgets
        move.w #-1,hover
        st bar_redraw
mode_same:
        rts

toggle_erase:
        not.b erase
        sf pick
        st fields_changed
        rts

toggle_pick:
        not.b pick
        st fields_changed
        rts

toggle_decor:
        not.b brush_decor
        rts

toggle_steel:
        not.b brush_steel
        rts

; As the game's M key ($B4A).
toggle_music:
        not.b G_MUSIC(a5)
        beq.s .on
        GCALL music_off
        rts
.on:    GCALL music_on
        rts

bar_sound:
        move.w #BAR_EFFECT,G_EFFECT(a5)
        GCALL sound
        rts

;----------------------------------------------------------------------------
; The terrain tools

; D0, D1: the map cell under the cursor.
cursor_cell:
        move.w G_CURSOR_X(a5),d0
        add.w G_SCROLL_X(a5),d0
        add.w #VIEW_EDGE,d0
        lsr.w #CELL_SHIFT_X,d0
        move.w G_CURSOR_Y(a5),d1
        add.w G_SCROLL_Y(a5),d1
        add.w #VIEW_EDGE,d1
        lsr.w #CELL_SHIFT_Y,d1
        rts

; D0 x, D1 y: Z set when the cell can be edited. The border cells, which
; the game clears before play ($D23A) and the screen never shows, cannot.
; Preserves all registers.
cell_editable:
        movem.l d2,-(sp)
        cmp.w #1,d0
        blt.s .no
        move.w G_COLUMNS(a5),d2
        subq.w #2,d2
        cmp.w d2,d0
        bgt.s .no
        cmp.w #2,d1
        blt.s .no
        move.w G_ROWS(a5),d2
        subq.w #3,d2
        cmp.w d2,d1
        bgt.s .no
        movem.l (sp)+,d2
        ori #4,ccr
        rts
.no:    movem.l (sp)+,d2
        andi #$fb,ccr
        rts

; D0 x, D1 y -> D3 the cell's byte offset in a map, A0 its record cell.
cell_offset:
        move.w d1,d3
        mulu G_COLUMNS(a5),d3
        add.w d0,d3
        lsl.l #2,d3
        lea edit_record+R_MAP,a0
        adda.l d3,a0
        rts

; Writes D2 into the cell D0 x, D1 y of the record, when it can be edited
; and differs; objects_apply puts it into the play map.
put_cell:
        movem.l d0-d4/a0,-(sp)
        bsr cell_editable
        bne.s .out
        bsr cell_offset
        cmp.l (a0),d2
        beq.s .out
        move.l d2,(a0)
        st dirty
        st touched                      ; a step for undo (undo.s)
        st cells_changed
        addq.w #1,cells_written
.out:   movem.l (sp)+,d0-d4/a0
        rts

; The brush at the cursor: its tiles, or empty cells when erasing. Tile 0
; in a piece is a hole and leaves the cell as it is.
brush_apply:
        bsr cursor_cell
        move.w d0,last_cell_x
        move.w d1,last_cell_y
        bsr brush_origin
        sf cells_changed
        movea.l brush_tiles,a1
        moveq #0,d6                     ; row
.row:   moveq #0,d5                     ; column
.cell:  move.w (a1)+,d2
        beq.s .next
        and.l #CELL_TILE,d2
        tst.b erase
        beq.s .draw
        moveq #0,d2
        bra.s .put
.draw:  tst.b brush_decor
        beq.s .steel
        bset #CELL_DECOR,d2
.steel: tst.b brush_steel
        beq.s .put
        bset #CELL_STEEL,d2
.put:   move.w brush_x,d0
        add.w d5,d0
        move.w brush_y,d1
        add.w d6,d1
        bsr put_cell
.next:  addq.w #1,d5
        cmp.w brush_w,d5
        blo.s .cell
        addq.w #1,d6
        cmp.w brush_h,d6
        blo.s .row
        tst.b cells_changed
        beq.s .done
        bsr objects_apply               ; the objects stay over the terrain
.done:  rts

; D0, D1 the cell under the cursor -> brush_x, brush_y: the brush's top
; left cell, the brush centred on the cursor.
brush_origin:
        move.w brush_w,d2
        subq.w #1,d2
        asr.w #1,d2
        sub.w d2,d0
        move.w d0,brush_x
        move.w brush_h,d2
        subq.w #1,d2
        asr.w #1,d2
        sub.w d2,d1
        move.w d1,brush_y
        rts

map_click:
        tst.b pick
        bne pick_cell
        st stroke
        bra brush_apply

; Holding the button draws on as the cursor moves to another cell: tiles
; and the eraser only, so that pieces are placed one click at a time. Only
; a press that drew in the map starts a stroke: a press on the panel, the
; bar or the pieces page (a 1x1 piece taken there) or a Pick draws nothing
; when the pointer moves on into the map with the button held.
map_stroke:
        tst.b stroke
        beq.s .done
        tst.b pick
        bne.s .done
        tst.b erase
        bne.s .stroke
        cmp.w #1,brush_w
        bne.s .done
        cmp.w #1,brush_h
        bne.s .done
.stroke:
        bsr cursor_cell
        cmp.w last_cell_x,d0
        bne brush_apply
        cmp.w last_cell_y,d1
        bne brush_apply
.done:  rts

; Pick: the tile under the cursor, with its two flags, becomes the brush.
pick_cell:
        sf pick
        st fields_changed
        bsr cursor_cell
        bsr cell_editable
        bne.s .nothing
        bsr cell_offset
        move.l (a0),d2
        move.w d2,d0
        and.w #CELL_TILE,d0
        beq.s .nothing
        bsr brush_tile
        btst #CELL_DECOR,d2
        sne brush_decor
        btst #CELL_STEEL,d2
        sne brush_steel
        sf erase
        rts
.nothing:
        lea s_nothing_here(pc),a0
        moveq #UI_WARN,d0
        bra set_message

; D0 a piece -> the brush; its flags from the usual flags of its tiles.
brush_piece:
        move.w d0,brush_index
        lsl.w #2,d0
        lea piece_table,a0
        movea.l 0(a0,d0.w),a0
        moveq #0,d0
        move.b 2(a0),d0
        move.w d0,brush_w
        move.b 3(a0),d0
        move.w d0,brush_h
        lea 6(a0),a0
        move.l a0,brush_tiles
        bra.s brush_flags

; D0 a tile -> the brush.
brush_tile:
        move.w #-1,brush_index
        move.w d0,brush_one
        move.w #1,brush_w
        move.w #1,brush_h
        move.l #brush_one,brush_tiles
        ; fall through

; The Decor and Steel switches from the tiles' usual flags: on when most of
; the brush's tiles have the flag in the game's own levels (tile_defaults,
; loaded from data/EditorTiles, which the install tool makes from them).
brush_flags:
        movem.l d0-d5/a0-a1,-(sp)
        st fields_changed
        movea.l brush_tiles,a0
        move.w brush_w,d0
        mulu brush_h,d0
        subq.w #1,d0
        lea tile_defaults,a1
        move.w G_TRIBE(a5),d1
        mulu #TILE_DEFAULTS,d1
        adda.l d1,a1
        moveq #0,d3                     ; tiles
        moveq #0,d4                     ; with Decor
        moveq #0,d5                     ; with Steel
.tile:  move.w (a0)+,d1
        and.w #CELL_TILE,d1
        beq.s .next
        addq.w #1,d3
        move.b 0(a1,d1.w),d2
        btst #0,d2
        beq.s .steel
        addq.w #1,d4
.steel: btst #1,d2
        beq.s .next
        addq.w #1,d5
.next:  dbra d0,.tile
        add.w d4,d4
        cmp.w d3,d4
        shi brush_decor
        add.w d5,d5
        cmp.w d3,d5
        shi brush_steel
        movem.l (sp)+,d0-d5/a0-a1
        rts

;----------------------------------------------------------------------------
; The brush in the view: drawn into the back buffer after the view copy,
; its tiles (or empty cells when erasing) and a frame.

draw_brush:
        cmp.w #SCREEN_ROWS,G_CURSOR_Y(a5)
        bhs.s .done
        bsr cursor_cell
        tst.b pick
        beq.s .brush
        moveq #1,d2                     ; picking: a frame round one cell
        moveq #1,d3
        bra frame_cells
.brush: bsr brush_origin
        movea.l brush_tiles,a1
        moveq #0,d6
.row:   moveq #0,d5
.cell:  move.w (a1)+,d2
        beq.s .next
        move.w brush_x,d0
        add.w d5,d0
        move.w brush_y,d1
        add.w d6,d1
        bsr cell_editable
        bne.s .next
        and.w #CELL_TILE,d2
        tst.b erase
        beq.s .tile
        moveq #0,d2
.tile:  bsr view_tile
.next:  addq.w #1,d5
        cmp.w brush_w,d5
        blo.s .cell
        addq.w #1,d6
        cmp.w brush_h,d6
        blo.s .row
        move.w brush_x,d0
        move.w brush_y,d1
        move.w brush_w,d2
        move.w brush_h,d3
        bra frame_cells
.done:  rts

; Tile D2 at the map cell D0, D1 in the back buffer, when it is there.
view_tile:
        movem.l d0-d3/a0-a2,-(sp)
        lsl.w #CELL_SHIFT_X,d0
        sub.w G_SCROLL_X(a5),d0
        bmi.s .out
        cmp.w #VIEW_WORDS*16,d0
        bhs.s .out
        lsl.w #CELL_SHIFT_Y,d1
        sub.w G_SCROLL_Y(a5),d1
        bmi.s .out
        cmp.w #VIEW_ROWS-8,d1
        bhi.s .out
        movea.l G_BACK(a5),a1
        mulu #VIEW_ROW,d1
        adda.l d1,a1
        lsr.w #3,d0
        adda.w d0,a1
        bsr tile_data                   ; -> A0
        bsr copy_tile
.out:   movem.l (sp)+,d0-d3/a0-a2
        rts

; D2 a tile -> A0 its 64 bytes (four planes of eight words).
tile_data:
        movea.l G_TILES(a5),a0
        and.l #CELL_TILE,d2
        lsl.l #6,d2
        adda.l d2,a0
        rts

; A0 a tile, A1 its place in a display buffer.
copy_tile:
        moveq #3,d0
.plane: movea.l a1,a2
        moveq #7,d1
.row:   move.w (a0)+,(a2)
        lea VIEW_ROW(a2),a2
        dbra d1,.row
        lea VIEW_PLANE(a1),a1
        dbra d0,.plane
        rts

; A frame round D2 x D3 cells from the map cell D0, D1.
frame_cells:
        lsl.w #CELL_SHIFT_X,d0
        sub.w G_SCROLL_X(a5),d0
        lsl.w #CELL_SHIFT_Y,d1
        sub.w G_SCROLL_Y(a5),d1
        lsl.w #CELL_SHIFT_X,d2
        lsl.w #CELL_SHIFT_Y,d3
        ; fall through

; A frame in the back buffer: D0 x (a multiple of 16), D1 y, D2 width (a
; multiple of 16), D3 height in pixels, clipped to the buffer.
solid_frame:
        movem.l d0-d7/a0-a2,-(sp)
        movea.l G_BACK(a5),a0
        asr.w #4,d0                     ; first word
        asr.w #4,d2
        add.w d0,d2
        subq.w #1,d2                    ; last word
        move.w d1,d4
        move.w d1,d5
        add.w d3,d5
        subq.w #1,d5                    ; last row
        ; top and bottom rows
        move.w d4,d6
        bsr.s .line
        move.w d5,d6
        bsr.s .line
        ; the left and right columns between them
        move.w d4,d6
        subq.w #1,d5
.column:
        addq.w #1,d6
        cmp.w d5,d6
        bgt.s .out
        tst.w d6
        bmi.s .below
        cmp.w #VIEW_ROWS,d6
        bhs.s .out
        move.w d0,d7
        move.w #$8000,d3
        bsr.s frame_bits
        move.w d2,d7
        moveq #1,d3
        bsr.s frame_bits
.below: bra.s .column
.out:   movem.l (sp)+,d0-d7/a0-a2
        rts
.line:  tst.w d6                        ; row D6, words D0..D2
        bmi.s .line_out
        cmp.w #VIEW_ROWS,d6
        bhs.s .line_out
        move.w d0,d7
.word:  cmp.w d2,d7
        bgt.s .line_out
        move.w #$ffff,d3
        bsr.s frame_bits
        addq.w #1,d7
        bra.s .word
.line_out:
        rts

; Word D7 of row D6 in the buffer at A0: the pixels D3 in the frame
; colours (frame_word), when it is in the buffer. Changes D1 and A1.
frame_bits:
        tst.w d7
        bmi.s .out
        cmp.w #VIEW_WORDS,d7
        bhs.s .out
        move.w d6,d1
        mulu #VIEW_ROW,d1
        movea.l a0,a1
        adda.l d1,a1
        move.w d7,d1
        add.w d1,d1
        adda.w d1,a1
        bra.s frame_word
.out:   rts

; The pixels D3 of the word at A1 in a display buffer's first plane in the
; frame colours (frame_colours): each the style's lightest colour where it
; is dark, its darkest where it is light, so that a frame shows over the
; empty background and over terrain in every style. Preserves all.
frame_word:
        movem.l d0-d7/a1-a2,-(sp)
        move.w (a1),d4                  ; the pixels' four planes
        move.w VIEW_PLANE(a1),d5
        move.w 2*VIEW_PLANE(a1),d6
        move.w 3*VIEW_PLANE(a1),d7
        lea dark_colours,a2
        moveq #0,d2                     ; the pixels that take the lightest
        moveq #15,d1
.pixel: btst d1,d3
        beq.s .next
        moveq #0,d0                     ; the pixel's colour
        btst d1,d7
        beq.s .plane2
        addq.w #8,d0
.plane2:
        btst d1,d6
        beq.s .plane1
        addq.w #4,d0
.plane1:
        btst d1,d5
        beq.s .plane0
        addq.w #2,d0
.plane0:
        btst d1,d4
        beq.s .colour
        addq.w #1,d0
.colour:
        tst.b 0(a2,d0.w)
        beq.s .next
        bset d1,d2
.next:  dbra d1,.pixel
        move.w d3,d1
        eor.w d2,d1                     ; the pixels that take the darkest
        not.w d3                        ; the pixels kept
        move.b frame_light,d6
        move.b frame_dark,d7
        moveq #3,d5
.plane: move.w (a1),d4
        and.w d3,d4
        lsr.b #1,d6
        bcc.s .not_light
        or.w d2,d4
.not_light:
        lsr.b #1,d7
        bcc.s .not_dark
        or.w d1,d4
.not_dark:
        move.w d4,(a1)
        lea VIEW_PLANE(a1),a1
        dbra d5,.plane
        movem.l (sp)+,d0-d7/a1-a2
        rts

; The frame colours from the level's palette (the 16 colours play fades in
; to): the lightest and the darkest by luminance, and the colours nearer
; the darkest (dark_colours), over which a frame takes the lightest.
; Inverting the four planes is not enough: it gives colour 15 over the
; background's colour 0, and in Medieval ($000 over $001), Polar and
; Shadow the two are nearly alike.
frame_colours:
        movem.l d0-d7/a0-a1,-(sp)
        movea.l pal_play,a0
        moveq #0,d3                     ; the colour
        moveq #-1,d5                    ; the lightest's luminance
        move.w #$7fff,d7                ; the darkest's
.find:  move.w (a0)+,d0
        bsr.s colour_luminance
        cmp.w d5,d1
        ble.s .not_lighter
        move.w d3,d4
        move.w d1,d5
.not_lighter:
        cmp.w d7,d1
        bge.s .not_darker
        move.w d3,d6
        move.w d1,d7
.not_darker:
        addq.w #1,d3
        cmp.w #16,d3
        blo.s .find
        move.b d4,frame_light
        move.b d6,frame_dark
        add.w d7,d5                     ; twice the luminance halfway
        movea.l pal_play,a0
        lea dark_colours,a1
        moveq #16-1,d3
.dark:  move.w (a0)+,d0
        bsr.s colour_luminance
        add.w d1,d1
        cmp.w d5,d1
        sls (a1)+
        dbra d3,.dark
        movem.l (sp)+,d0-d7/a0-a1
        rts

; D0 a colour ($0RGB) -> D1 its luminance, 3R + 6G + B (0 to 150, near
; the weights of Rec. 601). Changes D0 and D2.
colour_luminance:
        moveq #15,d1
        and.w d0,d1                     ; blue
        lsr.w #4,d0
        moveq #15,d2
        and.w d0,d2                     ; green
        mulu #6,d2
        add.w d2,d1
        lsr.w #4,d0
        and.w #15,d0                    ; red
        mulu #3,d0
        add.w d0,d1
        rts

; A dotted frame inside the rectangle solid_frame takes (the same
; registers), every other pixel and row: so that it stays apart from a
; frame where the two meet (the scroll limits round the start view), with
; a pixel of what is beneath between them, its rows and columns are two
; pixels in, which the screen still shows (it shows the back buffer's
; pixels from x 18 to 333).
dotted_frame:
        movem.l d0-d7/a0-a2,-(sp)
        movea.l G_BACK(a5),a0
        asr.w #4,d0                     ; first word
        asr.w #4,d2
        add.w d0,d2
        subq.w #1,d2                    ; last word
        move.w d1,d4
        addq.w #2,d4                    ; the top row
        move.w d1,d5
        add.w d3,d5
        subq.w #3,d5                    ; the bottom row
        move.w d4,d6
        bsr.s .line
        move.w d5,d6
        bsr.s .line
        move.w d4,d6                    ; the columns, every other row
.column:
        addq.w #2,d6
        cmp.w d5,d6
        bge.s .out
        tst.w d6
        bmi.s .column
        cmp.w #VIEW_ROWS,d6
        bhs.s .out
        move.w d0,d7
        move.w #$2000,d3                ; pixel 2 of the first word
        bsr frame_bits
        move.w d2,d7
        moveq #4,d3                     ; pixel 13 of the last word
        bsr frame_bits
        bra.s .column
.out:   movem.l (sp)+,d0-d7/a0-a2
        rts
.line:  tst.w d6                        ; row D6, words D0..D2
        bmi.s .line_out
        cmp.w #VIEW_ROWS,d6
        bhs.s .line_out
        move.w d0,d7
        move.w #$0aaa,d3                ; from pixel 4 of the first word
.word:  cmp.w d2,d7
        beq.s .last
        bsr frame_bits
        move.w #$aaaa,d3
        addq.w #1,d7
        bra.s .word
.last:  and.w #$aaa8,d3                 ; to pixel 12 of the last
        bra frame_bits
.line_out:
        rts

;----------------------------------------------------------------------------
; Saving and leaving

; The record into its file. WHDLoad quits with a requester if it cannot
; write (the slave sets WHDLF_NoError). It writes through the operating
; system, which takes the keyboard meanwhile: the release of the key that
; saved never reaches the game, whose key repeat would then go on, so the
; game's key state is cleared afterwards.
save_level:
        movea.l resload_base,a2
        move.l #RECORD_SIZE,d0
        lea edit_path,a0
        lea edit_record,a1
        jsr resload_SaveFile(a2)
        clr.l G_MODIFIERS(a5)
        clr.w G_KEY_NEW(a5)             ; and the held key
        sf dirty
        bsr record_saved
        lea message_text,a3
        bsr first_warning
        bne.s .warning
        lea s_saved(pc),a0
        bsr put_str
        lea edit_path,a0
        bsr put_str
        lea message_text,a0
        moveq #UI_OK,d0
        bra set_message
.warning:                               ; saved all the same
        move.l a0,-(sp)
        lea s_saved_warning(pc),a0
        bsr put_str
        movea.l (sp)+,a0
        bsr put_str
        lea message_text,a0
        moveq #UI_WARN,d0
        bra set_message

; Menu: back to the list, after a question when there are unsaved changes.
ask_leave:
        tst.b dirty
        beq.s leave_now
        move.b #QUESTION_LEAVE,question_kind
        lea question_widgets(pc),a0
        bsr question_open
        lea question_text,a3
        lea s_question1(pc),a0
        bsr put_str
        lea edit_path+LEVELS_PREFIX,a0
        bsr put_str
        lea s_question2(pc),a0
        bra put_str

save_and_leave:
        bsr save_level
leave_now:
        st leaving
        rts

close_question:
        move.b #PAGE_EDIT,edit_page
        bra mode_widgets

; A0 a question's widgets: the bar asks it (question_text).
question_open:
        move.b #PAGE_QUESTION,edit_page
        move.l a0,widgets
        sf status_hidden
        move.w #-1,hover
        st bar_redraw
        rts

question_input:
        bsr widget_at
        move.w d0,hover
        move.w key,d0
        cmp.b #KEY_RETURN,d0            ; the default answer
        bne.s .esc
        tst.b question_kind
        bne test_go
        bra save_and_leave
.esc:
        cmp.b #KEY_ESC,d0
        beq close_question
        cmp.b #'d',d0                   ; Discard
        bne.s .click
        tst.b question_kind
        beq leave_now
.click: tst.b G_LEFT_CLICK(a5)
        beq.s .done
        move.w hover,d0
        bpl widget_click
.done:  rts

; A0 text, D0 colour: shown on the help line for a few seconds.
set_message:
        move.w d0,message_colour
        lea message_text,a1
        cmpa.l a0,a1
        beq.s .shown
.copy:  move.b (a0)+,(a1)+
        bne.s .copy
.shown: move.w #MESSAGE_PASSES,message_passes
        rts

;----------------------------------------------------------------------------
; The bar's lines

; The help line: a message, else what the button under the pointer does,
; else what the mouse does in the map.
edit_help:
        tst.w message_passes
        beq.s .hover
        subq.w #1,message_passes
        lea message_text,a0
        move.w message_colour,d0
        bra set_help
.hover: move.w hover,d0
        bmi.s .map
        cmp.w #ID_SAVE,d0
        bne.s .button
        bsr first_warning               ; Save names a warning
        beq.s .button
        lea help_build,a3
        move.l a0,-(sp)
        lea s_save_warning(pc),a0
        bsr put_str
        movea.l (sp)+,a0
        bsr put_str
        lea help_build,a0
        moveq #UI_WARN,d0
        bra set_help
.button:
        move.w hover,d0
        bsr widget_find
        movea.l W_HELP(a1),a0
        moveq #UI_INK,d0
        bra set_help
.map:   lea s_empty(pc),a0
        cmp.b #PAGE_QUESTION,edit_page
        bne.s .typing
        lea s_question_help(pc),a0
        tst.b question_kind
        beq .show
        lea s_test_help(pc),a0
        bra .show
.typing:
        cmp.b #PAGE_TITLE,edit_page
        bne.s .limits
        lea s_title_help(pc),a0
        bra.s .show
.limits:
        cmp.b #PAGE_LIMITS,edit_page
        bne.s .tools
        lea s_limits_help(pc),a0
        bra.s .show
.tools: cmp.b #PAGE_PIECES,edit_page
        beq.s .page
        cmp.b #PAGE_TYPES,edit_page
        bne.s .edit
        lea s_types_help(pc),a0
        bra.s .page_help
.page:  lea s_pieces_help(pc),a0
.page_help:
        cmp.w #SCREEN_ROWS,G_CURSOR_Y(a5)
        blo.s .show
        lea s_empty(pc),a0
        bra.s .show
.edit:  cmp.b #MODE_LEVEL,mode
        beq level_help
        cmp.w #SCREEN_ROWS,G_CURSOR_Y(a5)
        bhs.s .show
        tst.b mode
        bne objects_help
        lea s_draw_help(pc),a0
        tst.b erase
        beq.s .pick
        lea s_erase_help(pc),a0
.pick:  tst.b pick
        beq.s .show
        lea s_pick_help(pc),a0
.show:  moveq #UI_DIM,d0
        bra set_help

; The status line: the cell under the pointer, else the level's title.
edit_status:
        lea status_text,a3
        tst.b status_hidden             ; the Param mode: no status line
        bne .done
        cmp.b #PAGE_TITLE,edit_page
        beq.s .title
        cmp.w #SCREEN_ROWS,G_CURSOR_Y(a5)
        bhs.s .title
        cmp.b #MODE_OBJECTS,mode
        beq objects_status
        bsr cursor_cell
        move.w d0,d4
        move.w d1,d5
        lea s_cell(pc),a0
        bsr put_str
        bsr put_number
        move.b #',',(a3)+
        move.w d5,d0
        bsr put_number
        move.b #' ',(a3)+
        move.b #' ',(a3)+
        move.w d4,d0
        move.w d5,d1
        bsr cell_editable
        bne.s .border
        bsr cell_offset
        move.l (a0),d2
        bsr put_cell_info
        bra.s .done
.border:
        lea s_border(pc),a0
        bsr put_str
        bra.s .done
.title: lea s_level(pc),a0
        bsr put_str
        lea edit_record+R_TITLE_TEXT,a0
        moveq #24-1,d0
        movea.l a3,a1
.char:  move.b (a0)+,d1
        beq.s .trim
        move.b d1,(a3)+
        dbra d0,.char
.trim:  cmpa.l a1,a3
        beq.s .done
        cmp.b #' ',-1(a3)
        bne.s .done
        subq.l #1,a3
        bra.s .trim
.done:  clr.b (a3)
        bra status_done

; D2 a cell -> its tile and flags in words, at A3.
put_cell_info:
        move.w d2,d0
        and.w #CELL_TILE,d0
        bne.s .tile
        lea s_cell_empty(pc),a0
        bra put_str
.tile:  lea s_tile(pc),a0
        bsr put_str
        bsr put_number
        btst #CELL_DECOR,d2
        bne.s .decor
        btst #CELL_STEEL,d2
        bne.s .steel
        lea s_cell_solid(pc),a0
        bra put_str
.decor: lea s_cell_decor(pc),a0
        bsr put_str
        btst #CELL_STEEL,d2
        beq.s .done
.steel: lea s_cell_steel(pc),a0
        bra put_str
.done:  rts

;----------------------------------------------------------------------------
; Widget states and texts

; D0 a widget id -> D5 its state. Preserves all other registers.
widget_state:
        move.l d1,-(sp)
        moveq #ST_NORMAL,d5
        cmp.w #ID_LEVEL,d0
        bhi.s .later
        move.w d0,d1                    ; the modes' buttons
        subq.w #ID_TERRAIN,d1
        cmp.b mode,d1
        beq .active
        bra .hover
.later: cmp.w #ID_TEST,d0
        beq .hover
        cmp.w #ID_REDO,d0
        bhi.s .save
        bsr undo_state                  ; Undo, Redo
        cmp.w #ST_DISABLED,d5
        beq .out
        bra .hover
.save:
        cmp.w #ID_SAVE,d0
        bne.s .erase
        tst.b dirty
        beq .disabled
        bra .hover
.erase: lea erase,a0
        cmp.w #ID_ERASE,d0
        beq .switch
        lea pick,a0
        cmp.w #ID_PICK,d0
        beq .switch
        lea brush_decor,a0
        cmp.w #ID_DECOR,d0
        beq .switch
        lea brush_steel,a0
        cmp.w #ID_STEEL,d0
        beq .switch
        cmp.w #ID_UP,d0
        bne.s .down
        cmp.b #PAGE_TYPES,edit_page
        beq.s .types_up
        tst.w sheet_top
        beq .disabled
        bra .hover
.types_up:
        tst.w page_top
        beq .disabled
        bra .hover
.down:  cmp.w #ID_DOWN,d0
        bne.s .default
        cmp.b #PAGE_TYPES,edit_page
        beq.s .types_down
        move.w sheet_top,d1
        cmp.w sheet_max_top,d1
        bhs .disabled
        bra .hover
.types_down:
        move.w page_top,d1
        cmp.w page_max_top,d1
        bhs .disabled
        bra .hover
.default:
        cmp.w #ID_Q_SAVE,d0
        beq.s .default_button
        cmp.w #ID_T_OK,d0
        beq.s .default_button
        cmp.w #ID_L_OK,d0
        beq.s .default_button
        cmp.w #ID_Q_TEST,d0
        bne.s .tools
.default_button:
        moveq #ST_DEFAULT,d5
        bra.s .hover
.tools: cmp.w #ID_TYPES,d0
        blo.s .hover
        cmp.w #ID_TITLE,d0
        blo.s .objects_tool
        bsr level_widget_state
        bra.s .tool_state
.objects_tool:
        bsr object_widget_state
.tool_state:
        cmp.w #ST_DISABLED,d5
        beq.s .out
        bra.s .hover
.switch:
        tst.b (a0)
        bne.s .active
.hover: cmp.w hover,d0
        bne.s .out
        addq.w #1,d5                    ; the hover state of normal or default
        bra.s .out
.active:
        moveq #ST_ACTIVE,d5
        bra.s .out
.disabled:
        moveq #ST_DISABLED,d5
.out:   move.l (sp)+,d1
        rts

; D0 a text field's id -> A0 its text, D3 its colour.
widget_text:
        movem.l d0-d2/a3,-(sp)
        moveq #UI_INK,d3
        cmp.w #ID_QUESTION,d0
        bne.s .sheet
        lea question_text,a0
        moveq #UI_ACCENT,d3
        bra .out
.sheet: lea field_text,a3
        cmp.w #ID_COUNT,d0
        blo.s .objects
        bsr level_widget_text
        bra .text
.objects:
        cmp.w #ID_TYPE,d0
        blo.s .pieces
        bsr object_widget_text
        bra .text
.pieces:
        cmp.w #ID_SHEET,d0
        bne.s .brush
        lea s_rows(pc),a0
        bsr put_str
        move.w sheet_top,d0
        addq.w #1,d0
        bsr put_number
        move.b #'-',(a3)+
        add.w #SHEET_VIEW-1,d0
        cmp.w sheet_rows,d0
        bls.s .last
        move.w sheet_rows,d0
.last:  bsr put_number
        lea s_of_text(pc),a0
        bsr put_str
        move.w sheet_rows,d0
        bsr put_number
        bra.s .text
.brush: tst.w brush_index
        bmi.s .one
        lea s_piece(pc),a0
        bsr put_str
        move.w brush_index,d0
        bsr put_number
        move.b #' ',(a3)+
        move.w brush_w,d0
        bsr put_number
        move.b #'x',(a3)+
        move.w brush_h,d0
        bsr put_number
        bra.s .text
.one:   lea s_tile(pc),a0
        bsr put_str
        move.w brush_one,d0
        and.w #CELL_TILE,d0
        bsr put_number
.text:  clr.b (a3)
        lea field_text,a0
.out:   movem.l (sp)+,d0-d2/a3
        rts

;============================================================================
; The pieces page: the style's terrain pieces (L2BE) as they lie on their
; sheet, in the play area; a click takes a piece, a right click one tile.

; Finds L2BE in the loaded style file, after L2BL (A5+$24E points to L2BL's
; tiles, after their count), and lays the pieces out on the sheet.
pieces_find:
        clr.w piece_count
        clr.w sheet_rows
        clr.w sheet_top
        lea sheet_piece,a0
        move.w #SHEET_COLS*SHEET_MAX_ROWS/4-1,d0
.clear: move.l #NO_PIECE<<24!NO_PIECE<<16!NO_PIECE<<8!NO_PIECE,(a0)+
        dbra d0,.clear
        lea sheet_tile,a0
        move.w #SHEET_COLS*SHEET_MAX_ROWS/2-1,d0
.clear_tiles:
        clr.l (a0)+
        dbra d0,.clear_tiles
        movea.l G_TILES(a5),a0
        cmp.l #'L2BL',-10(a0)
        bne .none
        subq.l #2,a0
        adda.l -4(a0),a0                ; the chunk after L2BL
        cmp.l #'L2BE',(a0)
        bne .none
        move.l 4(a0),d7                 ; its size
        lea 8(a0),a0
        lea 0(a0,d7.l),a2               ; its end
        move.w (a0)+,d6                 ; pieces
        subq.w #1,d6
        bmi .none
        lea piece_table,a1
        moveq #0,d5                     ; piece number
.piece: cmpa.l a2,a0
        bhs .done
        cmp.w #MAX_PIECES,d5
        bhs .done
        move.l a0,(a1)+
        bsr sheet_place
        moveq #0,d0
        move.w 4(a0),d0
        beq .done
        adda.l d0,a0
        addq.w #1,d5
        dbra d6,.piece
.done:  move.w d5,piece_count
        move.w sheet_rows,d0
        sub.w #SHEET_VIEW,d0
        bpl.s .max
        moveq #0,d0
.max:   move.w d0,sheet_max_top
        rts
.none:  clr.w sheet_max_top
        rts

; A0 the piece D5: its cells on the sheet (pieces outside it are left out).
sheet_place:
        movem.l d0-d7/a0-a3,-(sp)
        moveq #0,d0
        move.b (a0),d0                  ; x
        moveq #0,d1
        move.b 1(a0),d1                 ; y
        moveq #0,d2
        move.b 2(a0),d2                 ; width
        moveq #0,d3
        move.b 3(a0),d3                 ; height
        lea 6(a0),a3
        move.w d0,d4
        add.w d2,d4
        cmp.w #SHEET_COLS,d4
        bhi.s .out
        move.w d1,d4
        add.w d3,d4
        cmp.w #SHEET_MAX_ROWS,d4
        bhi.s .out
        cmp.w sheet_rows,d4
        bls.s .rows
        move.w d4,sheet_rows
.rows:  subq.w #1,d3
.row:   move.w d1,d6
        mulu #SHEET_COLS,d6
        add.w d0,d6                     ; the first cell of the row
        move.w d2,d7
        subq.w #1,d7
.cell:  lea sheet_piece,a1
        move.b d5,0(a1,d6.w)
        lea sheet_tile,a1
        move.w d6,d4
        add.w d4,d4
        move.w (a3)+,0(a1,d4.w)
        addq.w #1,d6
        dbra d7,.cell
        addq.w #1,d1
        dbra d3,.row
.out:   movem.l (sp)+,d0-d7/a0-a3
        rts

open_pieces:
        tst.w piece_count
        beq.s .none
        move.b #PAGE_PIECES,edit_page
        lea pieces_widgets(pc),a0
        move.l a0,widgets
        move.w #-1,hover
        st bar_redraw
        rts
.none:  lea s_no_pieces(pc),a0
        moveq #UI_ERROR,d0
        bra set_message

close_pieces:
        move.b #PAGE_EDIT,edit_page
        sf stroke                       ; the press that took a piece
        bra mode_widgets

sheet_up:
        move.w sheet_top,d0
        subq.w #2,d0
        bpl.s sheet_set
        moveq #0,d0
        bra.s sheet_set
sheet_down:
        move.w sheet_top,d0
        addq.w #2,d0
        cmp.w sheet_max_top,d0
        ble.s sheet_set
        move.w sheet_max_top,d0
sheet_set:
        cmp.w sheet_top,d0
        beq.s .same
        move.w d0,sheet_top
        st fields_changed
.same:  rts

; A pass of the pieces page.
pieces_pass:
        bsr scroll_flags_clear          ; the display does not scroll
        GCALL view_desc
        GCALL buttons
        bsr read_key
        bsr update_pointer
        bsr sheet_scroll
        bsr sheet_draw
        bsr pieces_input
        bsr sheet_frame
        bsr edit_help
        bsr pieces_status
        bsr bar_refresh
        st G_PASS_DONE(a5)
        bra edit_loop

; The pointer at the top of the screen or the bottom of its range, the
; cursor keys: two rows a pass.
sheet_scroll:
        bsr scroll_wanted
        btst #2,d3
        bne sheet_up
        btst #3,d3
        bne sheet_down
        rts

; The visible rows of the sheet into the back buffer.
sheet_draw:
        movea.l G_BACK(a5),a1
        lea VIEW_EDGE*VIEW_ROW+VIEW_EDGE/8(a1),a1
        move.w sheet_top,d6
        moveq #SHEET_VIEW-1,d7
.row:   move.w d6,d4
        mulu #SHEET_COLS*2,d4
        lea sheet_tile,a3
        adda.l d4,a3
        moveq #SHEET_COLS-1,d5
        movea.l a1,a4
.cell:  moveq #0,d2
        cmp.w sheet_rows,d6
        bhs.s .blank
        move.w (a3)+,d2
.blank: movem.l a1/d5,-(sp)
        movea.l a4,a1
        bsr tile_data
        bsr copy_tile
        movem.l (sp)+,a1/d5
        addq.l #2,a4
        dbra d5,.cell
        lea 8*VIEW_ROW(a1),a1
        addq.w #1,d6
        dbra d7,.row
        rts

; -> D0 the piece under the cursor (or -1), D2 its tile.
sheet_hit:
        moveq #-1,d0
        moveq #0,d2
        move.w G_CURSOR_Y(a5),d1
        cmp.w #SCREEN_ROWS,d1
        bhs.s .out
        lsr.w #CELL_SHIFT_Y,d1
        add.w sheet_top,d1
        cmp.w sheet_rows,d1
        bhs.s .out
        mulu #SHEET_COLS,d1
        move.w G_CURSOR_X(a5),d2
        lsr.w #CELL_SHIFT_X,d2
        add.w d2,d1
        lea sheet_piece,a0
        moveq #0,d0
        move.b 0(a0,d1.w),d0
        cmp.b #NO_PIECE,d0
        bne.s .tile
        moveq #-1,d0
.tile:  lea sheet_tile,a0
        add.w d1,d1
        move.w 0(a0,d1.w),d2
.out:   rts

pieces_input:
        bsr widget_at
        move.w d0,hover
        move.w key,d0
        cmp.b #KEY_ESC,d0
        beq close_pieces
        tst.b G_LEFT_CLICK(a5)
        beq.s .right
        cmp.w #SCREEN_ROWS,G_CURSOR_Y(a5)
        bhs.s .bar
        bsr sheet_hit
        tst.w d0
        bmi.s .done
        bsr brush_piece
        sf erase
        sf pick
        bra close_pieces
.bar:   move.w hover,d0
        bpl widget_click
        rts
.right: tst.b G_RIGHT_CLICK(a5)
        beq.s .done
        bsr sheet_hit
        move.w d2,d0
        and.w #CELL_TILE,d0
        beq.s .done
        bsr brush_tile
        sf erase
        sf pick
        bra close_pieces
.done:  rts

; A frame round the piece under the cursor.
sheet_frame:
        bsr sheet_hit
        tst.w d0
        bmi.s .done
        lsl.w #2,d0
        lea piece_table,a0
        movea.l 0(a0,d0.w),a0
        moveq #0,d0
        move.b (a0),d0
        lsl.w #CELL_SHIFT_X,d0
        add.w #VIEW_EDGE,d0
        moveq #0,d1
        move.b 1(a0),d1
        sub.w sheet_top,d1
        lsl.w #CELL_SHIFT_Y,d1
        add.w #VIEW_EDGE,d1
        moveq #0,d2
        move.b 2(a0),d2
        lsl.w #CELL_SHIFT_X,d2
        moveq #0,d3
        move.b 3(a0),d3
        lsl.w #CELL_SHIFT_Y,d3
        bra solid_frame
.done:  rts

; The piece under the cursor.
pieces_status:
        lea status_text,a3
        bsr sheet_hit
        tst.w d0
        bmi.s .done
        move.w d0,d4
        move.w d2,d5
        lea s_piece(pc),a0
        bsr put_str
        move.w d4,d0
        bsr put_number
        lsl.w #2,d4
        lea piece_table,a0
        movea.l 0(a0,d4.w),a0
        move.b #' ',(a3)+
        moveq #0,d0
        move.b 2(a0),d0
        bsr put_number
        move.b #'x',(a3)+
        move.b 3(a0),d0
        bsr put_number
        move.b #' ',(a3)+
        move.b #' ',(a3)+
        move.w d5,d0
        and.w #CELL_TILE,d0
        beq.s .done
        lea s_tile(pc),a0
        bsr put_str
        bsr put_number
.done:  clr.b (a3)
        bra status_done

;============================================================================
; The bar's widgets

edit_widgets:
        COMMON_ROW
        WIDGET 2,ROW_B,40,ID_PIECES,s_pieces,h_pieces
        WIDGET 46,ROW_B,96,ID_BRUSH,0,0
        WIDGET 146,ROW_B,34,ID_ERASE,s_erase,h_erase
        WIDGET 182,ROW_B,28,ID_PICK,s_pick,h_pick
        WIDGET 212,ROW_B,34,ID_DECOR,s_decor,h_decor
        WIDGET 248,ROW_B,34,ID_STEEL,s_steel,h_steel
        dc.w -1

pieces_widgets:
        WIDGET 2,ROW_A,34,ID_BACK,s_back,h_back
        WIDGET 230,ROW_A,28,ID_UP,s_up,h_up
        WIDGET 260,ROW_A,34,ID_DOWN,s_down,h_down
        WIDGET 40,ROW_A,186,ID_SHEET,0,0
        dc.w -1

question_widgets:
        WIDGET 4,ROW_A,312,ID_QUESTION,0,0
        WIDGET 88,ROW_B,34,ID_Q_SAVE,s_save,h_q_save
        WIDGET 128,ROW_B,52,ID_Q_DISCARD,s_discard,h_discard
        WIDGET 186,ROW_B,46,ID_Q_CANCEL,s_cancel,h_cancel
        dc.w -1

;============================================================================
; Texts of the edit view

s_terrain:      dc.b "Terrain",0
s_objects:      dc.b "Objects",0
s_level_mode:   dc.b "Param",0
s_test:         dc.b "Test",0
s_undo:         dc.b "Undo",0
s_redo:         dc.b "Redo",0
s_save:         dc.b "Save",0
s_menu:         dc.b "Menu",0
s_pieces:       dc.b "Pieces",0
s_erase:        dc.b "Erase",0
s_pick:         dc.b "Pick",0
s_decor:        dc.b "Decor",0
s_steel:        dc.b "Steel",0
s_back:         dc.b "Back",0
s_up:           dc.b "Up",0
s_down:         dc.b "Down",0
s_discard:      dc.b "Discard",0
s_cancel:       dc.b "Cancel",0
s_unsaved:      dc.b "Unsaved",0
h_terrain:      dc.b "Terrain: draw the level's ground (T)",0
h_save:         dc.b "Save the level to its file (S)",0
h_menu:         dc.b "Back to the list of levels (Esc)",0
h_pieces:       dc.b "Choose a terrain piece or tile (P)",0
h_erase:        dc.b "Erase with the brush's shape (R, right click)",0
h_pick:         dc.b "Take a tile from the level as the brush (K)",0
h_decor:        dc.b "Decor: lemmings pass through the cells (D)",0
h_steel:        dc.b "Steel: cannot be dug or bashed away (I)",0
h_back:         dc.b "Back to the level without choosing (Esc)",0
h_up:           dc.b "Show the rows above (cursor up)",0
h_down:         dc.b "Show the rows below (cursor down)",0
h_q_save:       dc.b "Save the changes, then the list (Return)",0
h_discard:      dc.b "Leave the changes unsaved, then the list (D)",0
h_cancel:       dc.b "Keep editing (Esc)",0
s_draw_help:    dc.b "Click: draw    Right click: erase",0
s_erase_help:   dc.b "Click: erase    Right click: draw",0
s_pick_help:    dc.b "Click: take this tile as the brush",0
s_pieces_help:  dc.b "Click: take the piece    Right click: one tile",0
s_question_help: dc.b "Return: save   D: discard   Esc: keep editing",0
s_question1:    dc.b "Save the changes to ",0
s_question2:    dc.b "?",0
s_saved:        dc.b "Saved ",0
s_nothing_here: dc.b "There is no tile to take here",0
s_no_pieces:    dc.b "This style has no terrain pieces",0
s_cell:         dc.b "Cell ",0
s_border:       dc.b "Border, not editable",0
s_level:        dc.b "Level: ",0
s_tile:         dc.b "Tile ",0
s_piece:        dc.b "Piece ",0
s_rows:         dc.b "Rows ",0
s_cell_empty:   dc.b "Empty",0
s_cell_solid:   dc.b " Solid",0
s_cell_decor:   dc.b " Decor",0
s_cell_steel:   dc.b " Steel",0
s_empty:        dc.b 0
                even

;============================================================================

        section editor_bss,bss

edit_record:    ds.b RECORD_SIZE        ; the level being edited
edit_path:      ds.b 64                 ; its file
tile_defaults:  ds.b STYLE_COUNT*TILE_DEFAULTS ; bit 0 Decor, bit 1 Steel
black:          ds.w 64
piece_table:    ds.l MAX_PIECES
sheet_tile:     ds.w SHEET_COLS*SHEET_MAX_ROWS
sheet_piece:    ds.b SHEET_COLS*SHEET_MAX_ROWS
question_text:  ds.b 80
field_text:     ds.b 40
message_text:   ds.b 64
dark_colours:   ds.b 16                 ; set: a frame over the colour takes
frame_light:    ds.b 1                  ; the lightest colour, else the
frame_dark:     ds.b 1                  ; darkest (frame_colours)
                even
max_scroll_x:   ds.w 1
max_scroll_y:   ds.w 1
fade_in:        ds.w 1
key:            ds.w 1
key_char:       ds.w 1                  ; the key as typed, not lowered
hover:          ds.w 1
pointer_shape:  ds.w 1
message_passes: ds.w 1
message_colour: ds.w 1
brush_w:        ds.w 1
brush_h:        ds.w 1
brush_x:        ds.w 1
brush_y:        ds.w 1
brush_one:      ds.w 1
brush_tiles:    ds.l 1
stroke:         ds.b 1                  ; the held button draws on (map_stroke)
                even
last_cell_x:    ds.w 1
last_cell_y:    ds.w 1
piece_count:    ds.w 1
sheet_rows:     ds.w 1
sheet_max_top:  ds.w 1
cells_changed:  ds.b 1
                even
