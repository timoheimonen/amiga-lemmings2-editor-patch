; Lemmings 2: The Tribes In-Game Level Editor V1.2
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; The editor bar: 46 lines of 320 pixels below the game's skill panel,
; shown through the editor's own copper list, and the drawing routines for
; it: rectangles, the 5x7 font (font.i) in 6x8 cells and bevelled buttons,
; in fixed colour roles with the editor's own UI palette, so that the bar
; looks the same in every style.
;
; The bar bitmap has four planes of 40-byte rows, one after the other, in
; the editor's chip memory. Widgets are described by tables of 16-byte
; entries (x, y, width, id, label, help); the state of each widget comes
; from widget_state, and only widgets whose state changed are drawn again.
; Below the widgets are the status line and the help line (set_help), with
; the editor's version at the right end of the help line.
;
; Part of the editor's single assembly unit, included by editor.s. The edit
; view (edit.s, objects.s, level.s) sets the widget table in widgets and
; supplies widget_state and widget_text. A5 is the game's globals.

; Colour roles = colour indices of the bar
UI_BG           equ 0
UI_PANEL        equ 1
UI_FACE         equ 2
UI_FACE_HOVER   equ 3
UI_LIGHT        equ 4
UI_SHADOW       equ 5
UI_INK          equ 6
UI_DIM          equ 7
UI_ACCENT       equ 8
UI_SELECT       equ 9
UI_ERROR        equ 10
UI_OK           equ 11
UI_WARN         equ 12

; Widget states
ST_NORMAL       equ 0
ST_HOVER        equ 1
ST_ACTIVE       equ 2
ST_DISABLED     equ 3
ST_DEFAULT      equ 4
ST_DEFAULT_HOVER equ 5

; Geometry
BAR_W           equ 320
BAR_H           equ 46
BAR_ROW         equ 40              ; bytes per row
BAR_PLANE       equ BAR_ROW*BAR_H
BAR_PLANES      equ 4
BAR_LINE        equ $f6             ; first display line of the bar bitmap
BAR_CURSOR_Y    equ BAR_LINE-$2c    ; its row 0 in cursor coordinates (202)
CELL_W          equ 6
GLYPH_ROWS      equ 7
BUTTON_HEIGHT   equ 12
ROW_A           equ 0               ; modes and the common buttons
ROW_B           equ 13              ; the tools of the mode
STATUS_ROW      equ 28
HELP_ROW        equ 38
LINE_CELLS      equ (BAR_W-8)/CELL_W    ; characters of the status and help lines
UNSAVED_X       equ BAR_W-4-7*CELL_W    ; the unsaved mark, right on the status row

; Widget table entries
W_X             equ 0
W_Y             equ 2
W_W             equ 4
W_ID            equ 6
W_LABEL         equ 8
W_HELP          equ 12
W_SIZE          equ 16
W_TEXT          equ $8000           ; id flag: a text field, not a button
MAX_WIDGETS     equ 32

        section editor,code

;----------------------------------------------------------------------------
; The copper list of the bar, written into chip memory by bar_init. The play
; list jumps to it (COPJMP2) instead of ending; it ends the frame itself.
; The two lines before the bitmap show the bar's background while the
; colours, pointers and modulos are set.

bar_copper_template:
        dc.w ((BAR_LINE-2)<<8)!1,$ff00  ; wait for the line after the panel
        dc.w $0100,$0200                ; no planes
BAR_COLOURS     equ *-bar_copper_template
        dc.w $0180,0,$0182,0,$0184,0,$0186,0
        dc.w $0188,0,$018a,0,$018c,0,$018e,0
        dc.w $0190,0,$0192,0,$0194,0,$0196,0
        dc.w $0198,0,$019a,0,$019c,0,$019e,0
BAR_COLOURS_END equ *-bar_copper_template
        dc.w $0102,0                    ; no fine scroll
        dc.w $0092,$0038,$0094,$00d0    ; fetch as the panel does
        dc.w $0108,0,$010a,0            ; 40-byte rows
BAR_POINTERS    equ *-bar_copper_template
        dc.w $00e0,0,$00e2,0,$00e4,0,$00e6,0
        dc.w $00e8,0,$00ea,0,$00ec,0,$00ee,0
        dc.w (BAR_LINE<<8)!1,$ff00
        dc.w $0100,$4200                ; four planes
        dc.w $ffff,$fffe
BAR_COPPER_SIZE equ *-bar_copper_template

; The fixed UI palette, colour index = role.
ui_palette:
        dc.w $000,$223,$345,$468,$9ab,$012,$dde,$889
        dc.w $fc3,$36a,$e55,$5c6,$eb4,$000,$000,$fff

; Copy the copper list into chip memory and point it at the bar bitmap.
bar_init:
        lea bar_copper_template(pc),a0
        movea.l bar_copper,a1
        move.w #BAR_COPPER_SIZE/2-1,d0
.copy:  move.w (a0)+,(a1)+
        dbra d0,.copy
        movea.l bar_copper,a1
        adda.w #BAR_POINTERS+2,a1
        move.l bar_bitmap,d0
        moveq #BAR_PLANES-1,d1
.plane: swap d0
        move.w d0,(a1)
        swap d0
        move.w d0,4(a1)
        addq.l #8,a1
        add.l #BAR_PLANE,d0
        dbra d1,.plane
        rts

;----------------------------------------------------------------------------
; Drawing into the bar bitmap

; D0 x, D1 y, D2 width, D3 height, D4 colour. Preserves all.
bar_rect:
        movem.l d0-d7/a0-a2,-(sp)
        tst.w d2
        ble .out
        tst.w d3
        ble .out
        move.w d0,d5
        add.w d2,d5
        subq.w #1,d5                    ; last x
        moveq #-1,d6
        move.w d0,d7
        and.w #15,d7
        lsr.w d7,d6                     ; the first word's mask
        move.w d5,d7
        and.w #15,d7
        eor.w #15,d7
        moveq #-1,d2
        lsl.w d7,d2                     ; the last word's mask
        lsr.w #4,d0                     ; first word
        lsr.w #4,d5
        sub.w d0,d5                     ; words - 1
        bne.s .masks
        and.w d2,d6                     ; one word: both masks
.masks: movea.l bar_bitmap,a0
        mulu #BAR_ROW,d1
        adda.l d1,a0
        add.w d0,d0
        adda.w d0,a0                    ; the first word of the first row
        subq.w #1,d3
.row:   movea.l a0,a1
        moveq #BAR_PLANES-1,d7
        move.w d4,d1
.plane: movea.l a1,a2
        lsr.w #1,d1
        bcc.s .clear
        or.w d6,(a2)+
        move.w d5,d0
        beq.s .next
        subq.w #1,d0                    ; the words between the first and last
        bra.s .fill_test
.fill:  move.w #-1,(a2)+
.fill_test:
        dbra d0,.fill
        or.w d2,(a2)
        bra.s .next
.clear: move.w d6,d0
        not.w d0
        and.w d0,(a2)+
        move.w d5,d0
        beq.s .next
        subq.w #1,d0
        bra.s .clear_test
.clear_word:
        clr.w (a2)+
.clear_test:
        dbra d0,.clear_word
        move.w d2,d0
        not.w d0
        and.w d0,(a2)
.next:  lea BAR_PLANE(a1),a1
        dbra d7,.plane
        lea BAR_ROW(a0),a0
        dbra d3,.row
.out:   movem.l (sp)+,d0-d7/a0-a2
        rts

; Character D0 at D1 x, D2 y in colour D3: only its ink. Preserves all.
bar_glyph:
        movem.l d0-d7/a0-a2,-(sp)
        cmp.b #' ',d0
        bls.s .out                      ; spaces and controls: nothing
        cmp.b #'~',d0
        bhi.s .out
        and.w #$ff,d0
        sub.w #' ',d0
        mulu #GLYPH_ROWS,d0
        lea font(pc),a0
        adda.w d0,a0
        movea.l bar_bitmap,a1
        mulu #BAR_ROW,d2
        adda.l d2,a1
        move.w d1,d0
        lsr.w #4,d0
        add.w d0,d0
        adda.w d0,a1                    ; the long word the glyph lies in
        moveq #27,d6
        and.w #15,d1
        sub.w d1,d6                     ; shift of the five bits
        moveq #GLYPH_ROWS-1,d5
.row:   moveq #0,d4
        move.b (a0)+,d4
        lsl.l d6,d4
        movea.l a1,a2
        move.w d3,d1
        moveq #BAR_PLANES-1,d7
.plane: lsr.w #1,d1
        bcc.s .clear
        or.l d4,(a2)
        bra.s .next
.clear: move.l d4,d0
        not.l d0
        and.l d0,(a2)
.next:  lea BAR_PLANE(a2),a2
        dbra d7,.plane
        lea BAR_ROW(a1),a1
        dbra d5,.row
.out:   movem.l (sp)+,d0-d7/a0-a2
        rts

; A0 zero-terminated text at D1 x, D2 y in colour D3, at most D4 characters.
; Preserves all.
bar_text:
        movem.l d0-d1/d4/a0,-(sp)
        subq.w #1,d4
        bmi.s .out
.char:  move.b (a0)+,d0
        beq.s .out
        bsr bar_glyph
        add.w #CELL_W,d1
        dbra d4,.char
.out:   movem.l (sp)+,d0-d1/d4/a0
        rts

; A0 text -> D0 its length in characters.
text_length:
        move.l a0,-(sp)
        moveq #-1,d0
.char:  addq.w #1,d0
        tst.b (a0)+
        bne.s .char
        movea.l (sp)+,a0
        rts

; Bevelled button: A1 widget, D5 state. Preserves all.
bar_button:
        movem.l d0-d7/a0,-(sp)
        move.w W_X(a1),d0
        move.w W_Y(a1),d1
        move.w W_W(a1),d2
        moveq #BUTTON_HEIGHT,d3
        moveq #UI_FACE,d4
        cmp.w #ST_HOVER,d5
        beq.s .hover
        cmp.w #ST_DEFAULT_HOVER,d5
        beq.s .hover
        cmp.w #ST_ACTIVE,d5
        bne.s .face
        moveq #UI_SELECT,d4
        bra.s .face
.hover: moveq #UI_FACE_HOVER,d4
.face:  bsr bar_rect
        moveq #UI_LIGHT,d4
        moveq #1,d3
        bsr bar_rect                    ; top
        moveq #1,d2
        moveq #BUTTON_HEIGHT,d3
        bsr bar_rect                    ; left
        moveq #UI_SHADOW,d4
        add.w W_W(a1),d0
        subq.w #1,d0
        bsr bar_rect                    ; right
        move.w W_X(a1),d0
        add.w #BUTTON_HEIGHT-1,d1
        move.w W_W(a1),d2
        moveq #1,d3
        bsr bar_rect                    ; bottom
        ; the label, centred
        moveq #UI_INK,d3
        cmp.w #ST_DISABLED,d5
        bne.s .enabled
        moveq #UI_DIM,d3
.enabled:
        cmp.w #ST_ACTIVE,d5
        bne.s .label
        moveq #UI_ACCENT,d3
.label: movea.l W_LABEL(a1),a0
        bsr text_length
        mulu #CELL_W,d0
        subq.w #1,d0
        move.w W_W(a1),d1
        sub.w d0,d1
        asr.w #1,d1
        add.w W_X(a1),d1
        move.w W_Y(a1),d2
        addq.w #(BUTTON_HEIGHT-GLYPH_ROWS)/2,d2
        moveq #40,d4
        bsr bar_text
        cmp.w #ST_DEFAULT,d5
        blo.s .out
        moveq #UI_ACCENT,d4             ; the default button: a frame
        move.w W_X(a1),d0
        subq.w #1,d0
        move.w W_Y(a1),d1
        subq.w #1,d1
        move.w W_W(a1),d2
        addq.w #2,d2
        moveq #1,d3
        bsr bar_rect
        add.w #BUTTON_HEIGHT+1,d1
        bsr bar_rect
        move.w W_Y(a1),d1
        moveq #1,d2
        moveq #BUTTON_HEIGHT,d3
        bsr bar_rect
        add.w W_W(a1),d0
        addq.w #1,d0
        bsr bar_rect
.out:   movem.l (sp)+,d0-d7/a0
        rts

; A text field: A1 widget; its text comes from widget_text. Preserves all.
bar_field:
        movem.l d0-d4/a0,-(sp)
        move.w W_X(a1),d0
        move.w W_Y(a1),d1
        move.w W_W(a1),d2
        moveq #BUTTON_HEIGHT,d3
        moveq #UI_PANEL,d4
        bsr bar_rect
        move.w W_ID(a1),d0
        bsr widget_text                 ; -> A0 text, D3 colour
        move.w W_X(a1),d1
        move.w W_Y(a1),d2
        addq.w #(BUTTON_HEIGHT-GLYPH_ROWS)/2,d2
        move.w W_W(a1),d4
        ext.l d4
        divu #CELL_W,d4
        bsr bar_text
        movem.l (sp)+,d0-d4/a0
        rts

; A line of text across the bar: A0 text, D2 row, D3 colour. Preserves all.
bar_line:
        movem.l d0-d4,-(sp)
        moveq #0,d0
        move.w d2,d1
        move.w #BAR_W,d2
        moveq #8,d3
        moveq #UI_PANEL,d4
        bsr bar_rect
        movem.l (sp),d0-d4
        moveq #4,d1
        moveq #LINE_CELLS,d4
        bsr bar_text
        movem.l (sp)+,d0-d4
        rts

;----------------------------------------------------------------------------
; The bar's content: the current widget table, the status and help lines.

; Draw everything again.
bar_draw_all:
        moveq #0,d0
        moveq #0,d1
        move.w #BAR_W,d2
        moveq #BAR_H,d3
        moveq #UI_PANEL,d4
        bsr bar_rect
        lea widget_shown,a0
        moveq #MAX_WIDGETS-1,d0
.forget:
        move.w #-1,(a0)+
        dbra d0,.forget
        st status_changed               ; status_text and help_text again
        st help_changed
        st fields_changed
        clr.b bar_redraw
        ; fall through

; Draw the widgets whose state or text changed, and changed lines.
bar_refresh:
        tst.b bar_redraw
        bne bar_draw_all
        movea.l widgets,a1
        lea widget_shown,a2
.widget:
        move.w W_X(a1),d0
        bmi.s .lines
        move.w W_ID(a1),d0
        bsr widget_state                ; -> D5
        tst.w W_ID(a1)
        bpl.s .button
        tst.b fields_changed
        beq.s .next
        bsr bar_field
        bra.s .next
.button:
        cmp.w (a2),d5
        beq.s .next
        bsr bar_button
.next:  move.w d5,(a2)+
        lea W_SIZE(a1),a1
        bra.s .widget
.lines: clr.b fields_changed
        tst.b status_changed
        beq.s .help
        clr.b status_changed
        tst.b status_hidden             ; tools in its place: only the mark
        bne.s .mark
        lea status_text,a0
        moveq #STATUS_ROW,d2
        moveq #UI_INK,d3
        bsr bar_line
        bra.s .unsaved
.mark:  move.w #UNSAVED_X,d0
        moveq #STATUS_ROW,d1
        moveq #7*CELL_W,d2
        moveq #8,d3
        moveq #UI_PANEL,d4
        bsr bar_rect
.unsaved:
        tst.b dirty
        beq.s .help
        lea s_unsaved(pc),a0            ; the unsaved mark, right
        move.w #UNSAVED_X,d1
        moveq #STATUS_ROW,d2
        moveq #UI_WARN,d3
        moveq #7,d4
        bsr bar_text
.help:  tst.b help_changed
        beq.s .done
        clr.b help_changed
        lea help_text,a0
        moveq #HELP_ROW,d2
        move.w help_colour,d3
        bsr bar_line
        bsr help_version
.done:  rts

; The editor's version at the right end of the help line, in the
; selection blue (no help or message uses it; the map's help is dim), where
; the help leaves room for it after a space: the long form, else the short
; one, else none. The help always comes first.
help_version:
        lea help_text,a0
        bsr text_length
        moveq #LINE_CELLS-1,d1          ; the cells after the help and a space
        sub.w d0,d1
        lea s_version_long(pc),a0
        bsr text_length
        cmp.w d0,d1
        bge.s .draw
        lea s_version_short(pc),a0
        bsr text_length
        cmp.w d0,d1
        blt.s .done
.draw:  move.w d0,d4
        mulu #CELL_W,d0
        move.w #BAR_W-4,d1              ; right aligned, as the help is left
        sub.w d0,d1
        moveq #HELP_ROW,d2
        moveq #UI_SELECT,d3
        bsr bar_text
.done:  rts

; The widget under the cursor: D0 = its id, or -1. Only buttons count.
widget_at:
        move.w G_CURSOR_Y(a5),d1
        sub.w #BAR_CURSOR_Y,d1
        bmi.s .none
        move.w G_CURSOR_X(a5),d0
        movea.l widgets,a1
.widget:
        tst.w W_X(a1)
        bmi.s .none
        tst.w W_ID(a1)
        bmi.s .next
        cmp.w W_X(a1),d0
        blo.s .next
        move.w W_X(a1),d2
        add.w W_W(a1),d2
        cmp.w d2,d0
        bhs.s .next
        cmp.w W_Y(a1),d1
        blo.s .next
        move.w W_Y(a1),d2
        add.w #BUTTON_HEIGHT,d2
        cmp.w d2,d1
        bhs.s .next
        move.w W_ID(a1),d0
        rts
.next:  lea W_SIZE(a1),a1
        bra.s .widget
.none:  moveq #-1,d0
        rts

; D0 an id -> A1 its widget in the current table, or 0.
widget_find:
        movea.l widgets,a1
.widget:
        tst.w W_X(a1)
        bmi.s .none
        cmp.w W_ID(a1),d0
        beq.s .found
        lea W_SIZE(a1),a1
        bra.s .widget
.none:  suba.l a1,a1
.found: rts

; Set the help line: A0 text, D0 colour. Copies it, marks it changed when
; it differs from what is shown. Preserves all.
set_help:
        movem.l d0-d1/a0-a1,-(sp)
        move.w d0,d1
        lea help_text,a1
        moveq #0,d0
.copy:  move.b (a0)+,(a1)+
        beq.s .copied
        addq.w #1,d0
        cmp.w #LINE_MAX,d0
        blo.s .copy
        clr.b (a1)
.copied:
        cmp.w help_colour,d1
        bne.s .changed
        lea help_text,a0
        lea help_shown,a1
.compare:
        move.b (a0)+,d0
        cmp.b (a1)+,d0
        bne.s .changed
        tst.b d0
        bne.s .compare
        bra.s .out
.changed:
        move.w d1,help_colour
        lea help_text,a0
        lea help_shown,a1
.keep:  move.b (a0)+,(a1)+
        bne.s .keep
        st help_changed
.out:   movem.l (sp)+,d0-d1/a0-a1
        rts

; The status line was built in status_text; mark it changed when it differs.
status_done:
        lea status_text,a0
        lea status_shown,a1
.compare:
        move.b (a0)+,d0
        cmp.b (a1)+,d0
        bne.s .changed
        tst.b d0
        bne.s .compare
        move.b dirty,d0
        cmp.b dirty_shown,d0
        bne.s .changed
        rts
.changed:
        lea status_text,a0
        lea status_shown,a1
.keep:  move.b (a0)+,(a1)+
        bne.s .keep
        move.b dirty,dirty_shown
        st status_changed
        rts

;----------------------------------------------------------------------------
; Building text in a buffer at A3

; A0 zero-terminated text.
put_str:
        move.b (a0)+,(a3)+
        bne.s put_str
        subq.l #1,a3
        rts

; D0 an unsigned word in decimal.
put_number:
        movem.l d0-d2,-(sp)
        and.l #$ffff,d0
        moveq #0,d2
.divide:
        divu #10,d0
        swap d0
        add.b #'0',d0
        move.w d0,-(sp)
        addq.w #1,d2
        clr.w d0
        swap d0
        tst.w d0
        bne.s .divide
.digit: move.w (sp)+,d0
        move.b d0,(a3)+
        subq.w #1,d2
        bne.s .digit
        clr.b (a3)
        movem.l (sp)+,d0-d2
        rts

s_version_long: EDITOR_VERSION
                dc.b " by Timo Heimonen",0
s_version_short: EDITOR_VERSION
                dc.b " by Timo H.",0
                even

        section editor_bss,bss

LINE_MAX        equ 53                  ; characters on a line of the bar

widgets:        ds.l 1                  ; the current widget table
widget_shown:   ds.w MAX_WIDGETS        ; the state each widget was drawn in
help_colour:    ds.w 1
bar_redraw:     ds.b 1                  ; draw the whole bar on the next pass
fields_changed: ds.b 1                  ; text fields must be drawn again
status_changed: ds.b 1
help_changed:   ds.b 1
dirty_shown:    ds.b 1
status_hidden:  ds.b 1                  ; the Param mode's tools are there
                even
status_text:    ds.b LINE_MAX+1
status_shown:   ds.b LINE_MAX+1
help_text:      ds.b LINE_MAX+1
help_shown:     ds.b LINE_MAX+1
                even
