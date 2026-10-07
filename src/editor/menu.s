; Lemmings 2: The Tribes In-Game Level Editor V1.2
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; The buttons and the help line of the editor's pages on the game's menu
; screen: the list of custom levels, the New, Rename and Delete pages and
; the result page.
;
; The buttons look like the game's red buttons (sprite 51 of A5+$24A, 64x32:
; a face of colour 30, a light edge of colour 31 at the top and the left, a
; dark one of colour 29 at the right and the bottom) but are drawn by the
; editor, 96x18, in two rows of three below the page, so that the list's
; six fit the screen. A button that does nothing at the moment is dimmed.
; As in the editor bar, every button has a key, and the help line says what
; the button under the pointer does and names its key; otherwise it shows
; the page's help, or for a few seconds a message.
;
; A page (editor.s: the list, New and the result page; files.s: Delete and
; Rename) gives menu_page its table of buttons (MBUTTON entries) and its
; help, then calls menu_input once a field. Labels and the help line are
; drawn with the game's text routine through the editor's text streams
; (txt_start..txt_draw in editor.s), the buttons straight into the menu
; screen's planes. Part of the editor's single assembly unit, included by
; editor.s. A5 is the game's globals.

MB_X            equ 0           ; a button: x, y, width, key, label, help
MB_Y            equ 2
MB_W            equ 4
MB_KEY          equ 6
MB_LABEL        equ 8
MB_HELP         equ 12
MB_SIZE         equ 16
MB_SHIFT        equ 4           ; log2 MB_SIZE
MB_H            equ 18
MB_WIDTH        equ 96
MB_ROW_1        equ 142
MB_ROW_2        equ 162
MB_COLUMN_1     equ 8
MB_COLUMN_2     equ 112
MB_COLUMN_3     equ 216
MB_LABEL_Y      equ 4           ; the label below the top (even: the text
                                ; routine's boxes are halved)
MB_FACE         equ 30
MB_LIGHT        equ 31
MB_DARK         equ 29
MB_DIM_FACE     equ 28
MB_DIM_LIGHT    equ 29
MB_DIM_DARK     equ 15
MENU_ROW        equ 40          ; the menu screen: 320x200, five planes
MENU_PLANE      equ 8000
MENU_PLANES     equ 5
HELP_H          equ 12
HELP_COLOUR     equ 1           ; colours of the text routine's font
MESSAGE_COLOUR  equ 0
MENU_MESSAGE_FRAMES equ 150     ; three seconds
MENU_NONE       equ -1          ; what menu_input returns besides a button
MENU_CLICK      equ -2
MENU_KEY        equ -3
MENU_RIGHT      equ -4
MENU_OFF        equ -5

        section editor,code

; A0 the page's buttons (-1 ends), A1 the page's help, D0 the buttons that
; are dimmed (bit n: button n): the buttons and the help line are drawn.
; The click that opened the page must end first, and a key still held must
; not repeat into it.
menu_page:
        move.l a0,menu_table
        move.l a1,menu_help
        move.w d0,menu_off
        move.w #-1,menu_hover
        clr.l menu_shown
        clr.w menu_frames
        clr.w G_KEY_NEW(a5)
.release:
        btst #6,$bfe001
        beq.s .release
        GCALL buttons
        bsr menu_draw
        bra menu_help_line

; Every button of the page.
menu_draw:
        movea.l menu_table,a2
        moveq #0,d6
.face:  tst.w (a2)
        bmi.s .labels
        bsr button_face
        lea MB_SIZE(a2),a2
        addq.w #1,d6
        bra.s .face
.labels:
        bsr txt_start
        movea.l menu_table,a2
.label: tst.w (a2)
        bmi.s .draw
        bsr button_label
        lea MB_SIZE(a2),a2
        bra.s .label
.draw:  bra txt_draw

; D0 the buttons to dim: those that change are drawn again.
menu_set_off:
        move.w menu_off,d1
        eor.w d0,d1
        beq.s .done
        move.w d0,menu_off
        movea.l menu_table,a2
        moveq #0,d6
.button:
        tst.w (a2)
        bmi.s .done
        btst d6,d1
        beq.s .next
        movem.l d1/d6/a2,-(sp)
        bsr button_face
        bsr txt_start
        bsr button_label
        bsr txt_draw
        movem.l (sp)+,d1/d6/a2
.next:  lea MB_SIZE(a2),a2
        addq.w #1,d6
        bra.s .button
.done:  rts

; A2 a button, D6 its number: its face and edges, dimmed when it is off.
button_face:
        movem.l d0-d7/a0-a2,-(sp)
        moveq #MB_FACE,d4
        moveq #MB_LIGHT,d5
        moveq #MB_DARK,d7
        move.w menu_off,d0
        btst d6,d0
        beq.s .colours
        moveq #MB_DIM_FACE,d4
        moveq #MB_DIM_LIGHT,d5
        moveq #MB_DIM_DARK,d7
.colours:
        movem.w (a2),d0-d2              ; x, y, width
        move.w d2,d6
        moveq #MB_H,d3
        bsr fill_rect                   ; the face
        move.w d5,d4
        moveq #1,d3
        bsr fill_rect                   ; the top edge
        moveq #1,d2
        moveq #MB_H,d3
        bsr fill_rect                   ; the left edge
        move.w d7,d4
        add.w d6,d0
        subq.w #1,d0
        addq.w #1,d1
        moveq #MB_H-1,d3
        bsr fill_rect                   ; the right edge
        movem.w (a2),d0-d2
        addq.w #1,d0
        add.w #MB_H-1,d1
        subq.w #1,d2
        moveq #1,d3
        bsr fill_rect                   ; the bottom edge
        movem.l (sp)+,d0-d7/a0-a2
        rts

; A2 a button: its label into the text stream at A3, centred on it in the
; colour of the game's button labels.
button_label:
        move.b #7,(a3)+
        move.w MB_X(a2),d0
        lsr.w #1,d0
        move.b d0,(a3)+
        move.w MB_Y(a2),d0
        addq.w #MB_LABEL_Y,d0
        lsr.w #1,d0
        move.b d0,(a3)+
        move.w MB_X(a2),d0
        add.w MB_W(a2),d0
        lsr.w #1,d0
        move.b d0,(a3)+
        move.b #200/2,(a3)+
        move.b #5,(a3)+
        move.b #8,(a3)+
        clr.b (a3)+
        movea.l MB_LABEL(a2),a0
        bra txt_str

; One field of a page. D0 = the button clicked or whose key was pressed;
; MENU_OFF with D1 that button when it is dimmed; MENU_CLICK with D1 x and
; D2 y for a click elsewhere; MENU_KEY with D1 a key no button has, as
; typed; MENU_RIGHT for the right button; else MENU_NONE.
menu_input:
        GCALL wait_frame
        GCALL buttons
        bsr read_key
        move.w G_CURSOR_X(a5),d0
        move.w G_CURSOR_Y(a5),d1
        bsr menu_button_at
        move.w d0,menu_hover
        bsr menu_help_line
        move.w key,d1
        beq.s .mouse
        movea.l menu_table,a2
        moveq #0,d0
.key:   tst.w (a2)
        bmi.s .other
        cmp.w MB_KEY(a2),d1
        beq.s .button
        lea MB_SIZE(a2),a2
        addq.w #1,d0
        bra.s .key
.other: move.w key_char,d1
        moveq #MENU_KEY,d0
        rts
.mouse: moveq #MENU_RIGHT,d0
        tst.b G_RIGHT_CLICK(a5)
        bne.s .out
        moveq #MENU_NONE,d0
        tst.b G_LEFT_CLICK(a5)
        beq.s .out
        move.w menu_hover,d0
        bpl.s .button
        moveq #MENU_CLICK,d0
        move.w G_CURSOR_X(a5),d1
        move.w G_CURSOR_Y(a5),d2
.out:   rts
.button:
        move.w menu_off,d1
        btst d0,d1
        bne.s .off
        clr.w menu_frames               ; a message gives way
        move.w d0,-(sp)
        bsr click_sound
        move.w (sp)+,d0
        rts
.off:   move.w d0,d1
        moveq #MENU_OFF,d0
        rts

; D0 x, D1 y -> D0 the button there, or -1.
menu_button_at:
        movea.l menu_table,a2
        moveq #0,d2
.button:
        move.w MB_X(a2),d3
        bmi.s .none
        cmp.w d3,d0
        blo.s .next
        add.w MB_W(a2),d3
        cmp.w d3,d0
        bhs.s .next
        move.w MB_Y(a2),d3
        cmp.w d3,d1
        blo.s .next
        add.w #MB_H,d3
        cmp.w d3,d1
        bhs.s .next
        move.w d2,d0
        rts
.next:  lea MB_SIZE(a2),a2
        addq.w #1,d2
        bra.s .button
.none:  moveq #-1,d0
        rts

; A0 a message: on the help line for a few seconds.
menu_say:
        move.l a0,menu_message
        move.w #MENU_MESSAGE_FRAMES,menu_frames
        clr.l menu_shown
        rts

; The help line: a message, else the help of the button under the pointer,
; else the page's; drawn when it changes.
menu_help_line:
        tst.w menu_frames
        beq.s .hover
        subq.w #1,menu_frames
        movea.l menu_message,a0
        moveq #MESSAGE_COLOUR,d2
        bra.s .show
.hover: movea.l menu_help,a0
        move.w menu_hover,d0
        bmi.s .colour
        movea.l menu_table,a1
        lsl.w #MB_SHIFT,d0
        movea.l MB_HELP(a1,d0.w),a0
.colour:
        moveq #HELP_COLOUR,d2
.show:  cmpa.l menu_shown,a0
        beq.s .done
        move.l a0,menu_shown
        movem.l d2/a0,-(sp)
        moveq #0,d0
        move.w #HELP_Y,d1
        move.w #320,d2
        moveq #HELP_H,d3
        GCALL restore_rect
        movem.l (sp)+,d2/a0
        bsr txt_start
        move.b #7,(a3)+
        clr.b (a3)+
        move.b #HELP_Y/2,(a3)+
        move.b #320/2,(a3)+
        move.b #200/2,(a3)+
        move.b #5,(a3)+
        move.b #8,(a3)+
        move.b d2,(a3)+
        bsr txt_str
        bra txt_draw
.done:  rts

; D0 x, D1 y, D2 width, D3 height, D4 colour: a filled rectangle on the
; menu screen. Rows are the same in every plane: a mask for the first and
; the last byte, whole bytes between them.
fill_rect:
        movem.l d0-d7/a0-a2,-(sp)
        movea.l menu_bitmap,a0
        mulu #MENU_ROW,d1
        adda.l d1,a0
        move.w d0,d1
        lsr.w #3,d1
        adda.w d1,a0                    ; the first byte of the first row
        move.w d0,d5
        add.w d2,d5
        subq.w #1,d5                    ; the last x
        move.w d5,d7
        lsr.w #3,d7
        sub.w d1,d7                     ; bytes in a row - 1
        and.w #7,d0
        moveq #-1,d1
        lsr.b d0,d1                     ; the first byte's mask
        and.w #7,d5
        moveq #7,d0
        sub.w d5,d0
        moveq #-1,d2
        lsl.b d0,d2                     ; the last byte's mask
        tst.w d7
        bne.s .planes
        and.b d2,d1                     ; one byte: both masks
.planes:
        moveq #MENU_PLANES-1,d6
.plane: movea.l a0,a1
        move.w d3,d5
        subq.w #1,d5
.row:   movea.l a1,a2
        btst #0,d4
        beq.s .clear
        tst.w d7
        bne.s .set_bytes
        or.b d1,(a2)
        bra.s .next_row
.set_bytes:
        or.b d1,(a2)+
        move.w d7,d0
        subq.w #2,d0
        bmi.s .set_last
.set:   st (a2)+
        dbra d0,.set
.set_last:
        or.b d2,(a2)
        bra.s .next_row
.clear: not.b d1
        not.b d2
        tst.w d7
        bne.s .clear_bytes
        and.b d1,(a2)
        bra.s .cleared
.clear_bytes:
        and.b d1,(a2)+
        move.w d7,d0
        subq.w #2,d0
        bmi.s .clear_last
.zero:  sf (a2)+
        dbra d0,.zero
.clear_last:
        and.b d2,(a2)
.cleared:
        not.b d1
        not.b d2
.next_row:
        lea MENU_ROW(a1),a1
        dbra d5,.row
        lea MENU_PLANE(a0),a0
        lsr.w #1,d4                     ; the colour's next bit
        dbra d6,.plane
        movem.l (sp)+,d0-d7/a0-a2
        rts

;============================================================================

        section editor_bss,bss

menu_bitmap:    ds.l 1                  ; the menu screen's planes
menu_table:     ds.l 1                  ; the page's buttons
menu_help:      ds.l 1                  ; its help
menu_message:   ds.l 1
menu_shown:     ds.l 1                  ; the text on the help line
menu_off:       ds.w 1                  ; the dimmed buttons
menu_hover:     ds.w 1                  ; the button under the pointer, -1
menu_frames:    ds.w 1                  ; fields the message stays
