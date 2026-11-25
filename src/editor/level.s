; Lemmings 2: The Tribes In-Game Level Editor V1.2.3
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; The Param mode of the edit view (MODE_LEVEL; its button in the bar reads
; "Param"): the level's title, its eight skills and their counts, the time,
; the release rate, the best grade, the start view and the scroll limits:
; the record's fields the game reads, nothing else. A change goes into the
; record and at once into what the game made of it: the parsed header
; (hunk 0 $18D16), the skill counts and the clock (A5+$164, $176, $178)
; and the skill panel, drawn by the game's own routines. The title and the
; scroll limits are edited on pages of their own in the bar. The edit view
; (edit.s) calls the mode's input, key, action, state, text, help and
; drawing routines here; undo.s calls level_shown after an undo or redo.
;
; Skills are chosen on an in-view page (PAGE_SKILLS) drawn directly into
; the play area using the game's own panel sprites (A5+$23A, group 1) and
; Practice palette (hunk 1 + $A44), while the skill panel below stays live
; and interactive. The 50 style-valid skills fit on one 10x5 grid without
; scrolling, fading or rebuilding the level: clicking a skill replaces or
; fills the selected slot (swapping if it is already in another occupied
; slot), clicking any panel slot selects it (empty slots select the first
; empty one), right-clicking removes a skill, Clear empties all eight slots,
; OK keeps the changes as one undo step and Cancel restores the old skills.
;
; Two skills work only with some styles: the Attractor's tables have no
; Classic entry ($A720), and the Blocker's grid is cleared and read only
; in the Classic style ($D332, $9C8E). In a Classic-style level the Blocker
; takes the Attractor's place on the grid; a level opened or played loses a
; skill its style cannot use (skills_fit).
;
; Game addresses are offsets in the game's hunk 0 unless another hunk is
; named; so are the absolute operands of the game's instructions quoted
; below. A5 is the game's globals. The record's words are little-endian
; (get_le, put_le), the parsed header's big-endian.

; Game routines and data, hunk 0
        GAME G_PANEL,$0f84a,$0f5b4              ; the skill panel, drawn from the header
        GAME G_PANEL_SLOT,$0f8d8,$0f642         ; D0 a slot: its highlight and its name
        GAME G_PANEL_COUNT,$0f98c,$0f6f6        ; D0 a count, D1 a slot: its digits
        GAME G_CLOCK,$0fa14,$0f77e              ; the panel's clock, when A5+$1DB is set
        GAME SKILL_NAMES,$1c10c,$1bdd4          ; 14 bytes a skill ID
        GAME G_SHAPES,$1c5a2,$1c248             ; seven BE16 pairs: columns, rows

; Game globals (A5)
G_COUNTS        equ $164
G_MINUTES       equ $176
G_SECONDS       equ $178
G_CLOCK_DUE     equ $1db
        GAME G_PANEL_SPRITES,$23a,$238          ; panel sprites FORM (group 1: 51 skills)

; The parsed header (hunk 0 $18D16)
H_SKILLS        equ $18         ; eight BE16 IDs
H_COUNTS        equ $28         ; eight BE16 counts
H_MINUTES       equ $38         ; byte
H_SECONDS       equ $39         ; byte
H_VIEW          equ $3e         ; six BE16: scroll x, y, lower x, y, upper x, y
H_RATE          equ $4c

; The record (L2LH from $14)
R_SKILLS        equ $2c         ; eight LE16 IDs, 0 = none (always last)
R_COUNTS        equ $3c         ; eight bytes
R_HEAD_STYLE    equ $48         ; LE16, equal to L2MH's style
R_VIEW          equ $4a         ; six LE16: scroll x, y, lower x, y, upper x, y
R_LIMITS        equ R_VIEW+4    ; the four limits
R_LOST          equ $56         ; LE16: the best grade's limit
R_RATE          equ $58         ; LE16: the release interval is 22 - rate
                                ; passes, at least 1 ($9AEE)

; The editor's ranges
SKILL_SLOTS     equ 8
COUNT_MIN       equ 1
COUNT_MAX       equ 99          ; two digits in the panel
NEW_COUNT       equ 10          ; a skill the picker adds
SKILL_ATTRACTOR equ 6           ; not in the Classic style
SKILL_BLOCKER   equ 51          ; only in the Classic style
TIME_STEP       equ 15          ; seconds
TIME_MIN        equ 15
TIME_MAX        equ 9*60+45     ; the clock shows one digit of minutes
RATE_MAX        equ 21          ; interval 1, the fastest
LOST_MAX        equ 59          ; of the 60 lemmings
SKILL_AREA      equ 256         ; the panel's eight slots, 32 pixels each
TITLE_SIZE      equ 24

; Modes and pages
MODE_TERRAIN    equ 0
MODE_OBJECTS    equ 1
MODE_LEVEL      equ 2
PAGE_TITLE      equ 4
PAGE_LIMITS     equ 5
PAGE_SKILLS     equ 6

; The skills grid inside the 320x160 play area (10x5 of 32x24 pixels)
SKILLS_COLS     equ 10
SKILLS_ROWS     equ 5
SKILLS_CELL_W   equ 32
SKILLS_CELL_H   equ 24
SKILLS_TOP      equ 20          ; vertically centred (20..139)
SKILLS_COL_HOVER equ 8          ; PAL_PRACTICE: light grey/white
SKILLS_COL_SEL  equ 1           ; PAL_PRACTICE: bright gold
SKILLS_COL_USED equ 10          ; PAL_PRACTICE: medium plum

ROW_C           equ 26          ; the Param mode's second row of tools

        section editor,code

;============================================================================
; Input in the Param mode

level_input:
        bsr widget_at
        move.w key,d0
        beq .mouse
        bsr edit_key
.mouse: tst.b G_LEFT_CLICK(a5)
        beq held_repeat
        clr.w held_passes
        move.w hover,held_widget        ; only the button pressed repeats
        move.w G_CURSOR_Y(a5),d1
        cmp.w #SCREEN_ROWS,d1
        blo .done                       ; the map: nothing to click
        cmp.w #BAR_CURSOR_Y,d1
        blo panel_click
        move.w hover,d0
        bpl widget_click
.done:  rts

; D0 a key in the Param mode (edit_key has taken the common ones). R and G
; step the rate and the best grade's limit up, with Shift down, as U undoes
; and Shift+U redoes; V sets the start view, Shift+V opens the limits.
level_key:
        cmp.b #'v',d0
        bne.s .rate
        move.w #ID_VIEW,d0
        move.w key_char,d1
        cmp.b #'a',d1
        bhs.s .button
        move.w #ID_LIMITS,d0
        bra.s .button
.rate:  move.w #ID_RATE_MORE,d1
        cmp.b #'r',d0
        beq.s .shift
        move.w #ID_LOST_MORE,d1
        cmp.b #'g',d0
        bne.s .table
.shift: move.w d1,d0
        move.w key_char,d1
        cmp.b #'a',d1
        bhs.s .button
        subq.w #1,d0                    ; the button before: less
.button:
        bra.s button_pressed
.table: lea level_keys(pc),a0
        ; fall through

; D0 a key, A0 a table of key and button words (0 ends it): the key's
; button pressed.
key_button:
        move.w (a0)+,d1
        beq.s .done
        move.w (a0)+,d2
        cmp.b d1,d0
        bne.s key_button
        move.w d2,d0
        bra.s button_pressed
.done:  rts

; D0 a button: its action, unless it is disabled.
button_pressed:
        bsr widget_state
        cmp.w #ST_DISABLED,d5
        beq.s .done
        bra widget_action
.done:  rts

level_keys:                             ; key, button
        dc.w 'p',ID_SKILLS
        dc.w 'n',ID_TITLE
        dc.w $7f,ID_REMOVE
        dc.w '-',ID_COUNT_LESS
        dc.w '=',ID_COUNT_MORE
        dc.w '+',ID_COUNT_MORE
        dc.w ',',ID_SLOT_PREV
        dc.w '.',ID_SLOT_NEXT
        dc.w '[',ID_TIME_LESS
        dc.w ']',ID_TIME_MORE
        dc.w 0

level_action:
        cmp.w #ID_TITLE,d0
        beq title_open
        cmp.w #ID_SKILLS,d0
        beq skills_open
        cmp.w #ID_REMOVE,d0
        beq skill_remove
        cmp.w #ID_COUNT_LESS,d0
        beq count_less
        cmp.w #ID_COUNT_MORE,d0
        beq count_more
        cmp.w #ID_SLOT_PREV,d0
        beq slot_previous
        cmp.w #ID_SLOT_NEXT,d0
        beq slot_next
        cmp.w #ID_VIEW,d0
        beq set_start_view
        cmp.w #ID_LIMITS,d0
        beq limits_open
        cmp.w #ID_TIME_LESS,d0
        beq time_less
        cmp.w #ID_TIME_MORE,d0
        beq time_more
        cmp.w #ID_RATE_LESS,d0
        beq rate_less
        cmp.w #ID_RATE_MORE,d0
        beq rate_more
        cmp.w #ID_LOST_LESS,d0
        beq lost_less
        cmp.w #ID_LOST_MORE,d0
        beq lost_more
        cmp.w #ID_T_OK,d0
        beq title_ok
        cmp.w #ID_T_CANCEL,d0
        beq mode_widgets
        cmp.w #ID_L_TOP,d0
        beq limits_top
        cmp.w #ID_L_BOTTOM,d0
        beq limits_bottom
        cmp.w #ID_L_WHOLE,d0
        beq limits_whole
        cmp.w #ID_L_OK,d0
        beq limits_ok
        cmp.w #ID_L_CANCEL,d0
        beq mode_widgets
        cmp.w #ID_S_PREV,d0
        beq skills_slot_prev
        cmp.w #ID_S_NEXT,d0
        beq skills_slot_next
        cmp.w #ID_S_REMOVE,d0
        beq skills_remove
        cmp.w #ID_S_CLEAR,d0
        beq skills_clear
        cmp.w #ID_S_OK,d0
        beq skills_ok
        cmp.w #ID_S_CANCEL,d0
        beq skills_cancel
        rts

; A click in the panel: an occupied slot is selected; an empty slot selects
; the first empty slot so Skills (P) can add a skill directly into it.
panel_click:
        move.w G_CURSOR_X(a5),d0
        cmp.w #SKILL_AREA,d0
        bhs .done
        lsr.w #5,d0
        bsr skill_id
        bne select_skill
        bsr skills_first_empty
        cmp.w #SKILL_SLOTS,d0
        blo select_skill
.done:  rts

;----------------------------------------------------------------------------
; The record's fields

; D0 a slot -> D1 its skill ID (Z set when none), A0 its record word.
; Preserves D0.
skill_id:
        lea edit_record+R_SKILLS,a0
        adda.w d0,a0
        adda.w d0,a0
        bsr get_le
        tst.w d1
        rts

; A0 a little-endian word -> D1. Preserves all else.
get_le:
        moveq #0,d1
        move.b 1(a0),d1
        lsl.w #8,d1
        move.b (a0),d1
        rts

; D1 -> the little-endian word at A0. Preserves all.
put_le:
        move.w d1,-(sp)
        move.b d1,(a0)
        lsr.w #8,d1
        move.b d1,1(a0)
        move.w (sp)+,d1
        rts

; A change was made: the record is unsaved and the fields show it.
level_changed:
        st dirty
        st touched
        st fields_changed
        rts

;----------------------------------------------------------------------------
; Skills and counts

; D0 a slot: selected, with the game's highlight and name in the panel.
select_skill:
        move.w d0,level_slot
        st fields_changed
        ; fall through

; The panel's highlight and name on the selected slot.
panel_highlight:
        movem.l d0-d7/a0-a3,-(sp)
        move.w level_slot,d0
        GCALL panel_slot
        movem.l (sp)+,d0-d7/a0-a3
        rts

slot_previous:
        bsr skill_before
        bpl select_skill
        rts

slot_next:
        bsr skill_after
        bpl select_skill
        rts

; The nearest slot with a skill before or after the selected one -> D0, or
; -1. The editor keeps the skills together, but a level from elsewhere may
; have empty slots between them. Changes D1/A0.
skill_before:
        move.w level_slot,d0
.slot:  subq.w #1,d0
        bmi.s .done
        bsr skill_id
        beq.s .slot
.done:  tst.w d0
        rts

skill_after:
        move.w level_slot,d0
.slot:  addq.w #1,d0
        cmp.w #SKILL_SLOTS,d0
        bhs.s .none
        bsr skill_id
        beq.s .slot
        tst.w d0
        rts
.none:  moveq #-1,d0
        rts

count_less:
        moveq #-1,d7
        bra.s count_change
count_more:
        moveq #1,d7
        ; fall through

; D7 +1 or -1: the selected skill's count, 1 to 99, into the record, the
; header, the play count and the panel's digits.
count_change:
        bsr selected_count              ; -> D1, A0 the record's counts
        beq .done
        move.w level_slot,d0
        add.w d7,d1
        tst.w d7
        bpl.s .more
        cmp.w #COUNT_MIN,d1
        blt .done
        cmp.w #COUNT_MAX,d1             ; a count from elsewhere over the
        bls.s .set                      ; range comes down into it at once
        moveq #COUNT_MAX,d1
        bra.s .set
.more:  cmp.w #COUNT_MAX,d1
        bgt .done
.set:   move.b d1,0(a0,d0.w)
        movea.l level_header,a0
        lea H_COUNTS(a0),a0
        move.w d0,d2
        add.w d2,d2
        move.w d1,0(a0,d2.w)
        lea G_COUNTS(a5),a0
        move.w d1,0(a0,d2.w)
        movem.l d0-d7/a0-a3,-(sp)
        exg d0,d1                       ; D0 the count, D1 the slot
        GCALL panel_count
        movem.l (sp)+,d0-d7/a0-a3
        bra level_changed
.done:  rts

; The selected skill removed; the later ones move forward, the last slot
; is empty, as in the shipped levels.
skill_remove:
        move.w level_slot,d0
        bsr skill_id
        beq .done
        bsr.s skill_shift_out
        move.w level_slot,d0            ; on the last skill when this was
        bsr skill_id
        bne .shown
        tst.w d0
        beq .shown
        subq.w #1,level_slot
.shown: bsr skills_shown
        lea s_skill_removed(pc),a0
        moveq #UI_INK,d0
        bsr set_message
        bra level_changed
.done:  rts

; D0 a slot: its skill removed, the later ones shifted left, slot 7 empty.
; Preserves D0.
skill_shift_out:
        movem.l d0-d1/a0-a1,-(sp)
        bsr skill_id                    ; -> A0 its record word
        lea edit_record+R_COUNTS,a1
        adda.w d0,a1
        moveq #SKILL_SLOTS-2,d1
        sub.w d0,d1
        bmi .last
.move:  move.b 2(a0),(a0)+
        move.b 2(a0),(a0)+
        move.b 1(a1),(a1)+
        dbra d1,.move
.last:  clr.w (a0)
        clr.b (a1)
        movem.l (sp)+,d0-d1/a0-a1
        rts

; After an undo or redo: the record's fields into the parsed header and the
; play state (the title, the time and clock, the scroll words, the best
; grade, the release rate), a selected skill the level has, and the skills
; and counts as below.
level_shown:
        movem.l d0-d7/a0-a3,-(sp)
        movea.l level_header,a2
        lea edit_record+R_TITLE_TEXT,a0
        movea.l a2,a1
        moveq #TITLE_SIZE-1,d0
.title: move.b (a0)+,(a1)+
        dbra d0,.title
        lea edit_record+R_VIEW,a0       ; six scroll words, the best grade
        lea H_VIEW(a2),a1               ; and the rate, in both in this order
        moveq #8-1,d0
.word:  bsr get_le
        move.w d1,(a1)+
        addq.l #2,a0
        dbra d0,.word
        move.w level_slot,d0
.slot:  bsr skill_id
        bne.s .chosen
        subq.w #1,d0
        bpl.s .slot
        moveq #0,d0
.chosen:
        move.w d0,level_slot
        bsr time_shown
        movem.l (sp)+,d0-d7/a0-a3
        ; fall through

; The record's skills and counts into the header and the play counts, and
; the panel drawn again from them, with the selected slot's highlight.
skills_shown:
        movem.l d0-d7/a0-a3,-(sp)
        lea edit_record+R_SKILLS,a0
        lea edit_record+R_COUNTS,a1
        movea.l level_header,a2
        lea G_COUNTS(a5),a3
        moveq #0,d0
.slot:  bsr get_le
        move.w d1,H_SKILLS(a2,d0.w)
        moveq #0,d1
        move.b (a1)+,d1
        move.w d1,H_COUNTS(a2,d0.w)
        move.w d1,0(a3,d0.w)
        addq.l #2,a0
        addq.w #2,d0
        cmp.w #2*SKILL_SLOTS,d0
        blo .slot
        GCALL panel
        movem.l (sp)+,d0-d7/a0-a3
        bra panel_highlight

; A0 a record -> the skill its style cannot use (the Attractor in the
; Classic style, the Blocker in the others) taken out, the later skills
; moved forward with their counts and the last slots empty, as Remove
; does. D1 = that skill's ID when it was there, else 0 (Z set). Preserves
; all else.
skills_fit:
        movem.l d0/d2-d3/a1-a4,-(sp)
        moveq #0,d0
        move.w #SKILL_BLOCKER,d3        ; the skill the style cannot use
        move.b R_STYLE(a0),d1           ; LE16
        or.b R_STYLE+1(a0),d1
        bne.s .style
        moveq #SKILL_ATTRACTOR,d3       ; Classic
.style: lea R_SKILLS(a0),a1             ; read
        lea R_COUNTS(a0),a2
        movea.l a1,a3                   ; and write
        movea.l a2,a4
        moveq #SKILL_SLOTS-1,d2
.slot:  move.b 1(a1),d1                 ; the LE16 ID
        lsl.w #8,d1
        move.b (a1),d1
        cmp.w d3,d1
        bne.s .keep
        move.w d1,d0
        bra.s .next
.keep:  move.b (a1),(a3)+
        move.b 1(a1),(a3)+
        move.b (a2),(a4)+
.next:  addq.l #2,a1
        addq.l #1,a2
        dbra d2,.slot
.empty: cmpa.l a1,a3                    ; A1 is past the last ID
        beq.s .done
        clr.b (a3)+
        clr.b (a3)+
        clr.b (a4)+
        bra.s .empty
.done:  move.w d0,d1
        movem.l (sp)+,d0/d2-d3/a1-a4    ; the flags stay
        rts

; When a level was opened (edit_enter): what skills_fit took out of it
; (skills_fitted, from start_edit), on the help line three times as long
; as a message.
skills_fit_notice:
        move.w skills_fitted,d1
        beq.s .done
        clr.w skills_fitted
        lea s_attractor_out(pc),a0
        cmp.w #SKILL_ATTRACTOR,d1
        beq.s .show
        lea s_blocker_out(pc),a0
.show:  moveq #UI_WARN,d0
        bsr set_message
        move.w #3*MESSAGE_PASSES,message_passes
.done:  rts

;----------------------------------------------------------------------------
; Time, release rate, best grade

time_less:
        moveq #-1,d7
        bra.s time_change
time_more:
        moveq #1,d7
        ; fall through

; D7 +1 or -1: the time to the next quarter minute up or down, 0:15 to
; 9:45, into the record (the low bytes of its two words), the header, the
; clock and the panel.
time_change:
        bsr level_time                  ; -> D0 seconds
        move.w d0,d2
        ext.l d0
        divu #TIME_STEP,d0
        tst.w d7
        bmi .down
        addq.w #1,d0                    ; the next step up
        bra .step
.down:  move.l d0,d1
        swap d1
        tst.w d1                        ; between two steps: the one below
        bne .step
        subq.w #1,d0
.step:  mulu #TIME_STEP,d0
        cmp.w #TIME_MIN,d0
        bge .low
        moveq #TIME_MIN,d0
.low:   cmp.w #TIME_MAX,d0
        ble .high
        move.w #TIME_MAX,d0
.high:  tst.w d7                        ; only the way of the button
        bmi .less
        cmp.w d2,d0
        ble .done
        bra .set
.less:  cmp.w d2,d0
        bge .done
.set:   ext.l d0
        divu #60,d0                     ; minutes, seconds in the high word
        move.b d0,edit_record+R_MINUTES
        swap d0
        move.b d0,edit_record+R_SECONDS
        bsr time_shown
        bra level_changed
.done:  rts

; The record's time into the header and the play clock, and the clock
; drawn. Preserves all.
time_shown:
        movem.l d0-d7/a0-a3,-(sp)
        movea.l level_header,a0
        moveq #0,d0
        move.b edit_record+R_MINUTES,d0
        move.b d0,H_MINUTES(a0)
        move.w d0,G_MINUTES(a5)
        move.b edit_record+R_SECONDS,d0
        move.b d0,H_SECONDS(a0)
        move.w d0,G_SECONDS(a5)
        st G_CLOCK_DUE(a5)
        GCALL clock
        movem.l (sp)+,d0-d7/a0-a3
        rts

; -> D0 the record's time in seconds.
level_time:
        moveq #0,d0
        move.b edit_record+R_MINUTES,d0
        mulu #60,d0
        moveq #0,d1
        move.b edit_record+R_SECONDS,d1
        add.w d1,d0
        rts

rate_less:
        moveq #-1,d7
        bra.s rate_change
rate_more:
        moveq #1,d7
rate_change:
        lea edit_record+R_RATE,a0
        moveq #RATE_MAX,d2
        moveq #H_RATE,d3
        bra.s word_change

lost_less:
        moveq #-1,d7
        bra.s lost_change
lost_more:
        moveq #1,d7
lost_change:
        lea edit_record+R_LOST,a0
        moveq #LOST_MAX,d2
        moveq #H_THRESHOLD,d3
        ; fall through

; D7 +1 or -1: the record's word at A0, 0 to D2, and the header's word at
; D3. A value from elsewhere over the range, a negative one too (shown as
; it is unsigned), comes down into it at once, as level_widget_state
; offers.
word_change:
        bsr get_le
        tst.w d7
        bmi.s .less
        cmp.w d2,d1
        bhs.s .done                     ; at the top or over it
        addq.w #1,d1
        bra.s .set
.less:  tst.w d1
        beq.s .done
        subq.w #1,d1
        cmp.w d2,d1
        bls.s .set
        move.w d2,d1
.set:   bsr put_le
        movea.l level_header,a0
        move.w d1,0(a0,d3.w)
        bra level_changed
.done:  rts

;----------------------------------------------------------------------------
; The start view and the scroll limits

; The view on the screen becomes the level's start view: the record's
; scroll words, and its scroll limits (the game stops scrolling when it
; meets a limit, in steps of 16 pixels) widened to reach it on a step when
; they do not.
set_start_view:
        move.l edit_record+R_LIMITS,d6  ; the limits before
        move.l edit_record+R_LIMITS+4,d7
        lea edit_record+R_VIEW,a1
        movea.l level_header,a2
        lea H_VIEW(a2),a2
        move.w G_SCROLL_X(a5),d4
        move.w max_scroll_x,d5
        bsr view_axis
        move.w G_SCROLL_Y(a5),d4
        move.w max_scroll_y,d5
        bsr view_axis
        lea s_view_set(pc),a0
        cmp.l edit_record+R_LIMITS,d6
        bne.s .widened
        cmp.l edit_record+R_LIMITS+4,d7
        beq.s .message
.widened:
        lea s_view_widened(pc),a0
.message:
        moveq #UI_OK,d0
        bsr set_message
        bra level_changed

; D4 the scroll on one axis, D5 the map's largest: into the record's words
; at A1, +4 and +8 (scroll, lower and upper limit) and the header's at A2.
; A1 and A2 move to the next axis.
view_axis:
        movea.l a1,a0
        move.w d4,d1
        bsr put_le
        lea 4(a1),a0                    ; the lower limit
        bsr get_le
        cmp.w d4,d1
        bgt .lower
        move.w d4,d0
        sub.w d1,d0
        and.w #15,d0
        beq .lower_ok
.lower: move.w d4,d1                    ; the lowest step below the view
        and.w #15,d1
        bsr put_le
.lower_ok:
        move.w d1,4(a2)
        lea 8(a1),a0                    ; the upper limit
        bsr get_le
        cmp.w d4,d1
        blt .upper
        move.w d1,d0
        sub.w d4,d0
        and.w #15,d0
        beq .upper_ok
.upper: move.w d5,d1                    ; the highest step the map allows
        sub.w d4,d1
        and.w #-16,d1
        add.w d4,d1
        bsr put_le
.upper_ok:
        move.w d1,8(a2)
        move.w d4,(a2)
        addq.l #2,a1
        addq.l #2,a2
        rts

; The record's start view and scroll limits in the view.
draw_level_ui:
        lea frame_words,a1
        bsr view_words
        lea frame_words,a0
        ; fall through

; A0 six words (the start view's scroll x and y, the lower limits, the
; upper limits): the start view as a frame, the screen's 320x160 pixels
; from its scroll position, and round it as a dotted frame the part of the
; map the level can show, from the lower limits' screen to the upper's.
view_frames:
        move.w (a0),d0
        move.w 2(a0),d1
        move.w #BAR_W,d2
        move.w #SCREEN_ROWS,d3
        bsr.s .place
        bsr outline_box
        move.w 4(a0),d0
        move.w 6(a0),d1
        move.w 8(a0),d2
        sub.w d0,d2
        add.w #BAR_W,d2
        and.w #-16,d2
        move.w 10(a0),d3
        sub.w d1,d3
        add.w #SCREEN_ROWS,d3
        bsr.s .place
        bra dotted_frame
.place: sub.w G_SCROLL_X(a5),d0         ; D0, D1 a scroll position -> its
        add.w #VIEW_EDGE,d0             ; screen in the back buffer
        and.w #-16,d0
        sub.w G_SCROLL_Y(a5),d1
        add.w #VIEW_EDGE,d1
        rts

; The record's six scroll words (R_VIEW, little-endian) to A1. Changes D0,
; D1, A0 and A1.
view_words:
        lea edit_record+R_VIEW,a0
        moveq #6-1,d0
.word:  bsr get_le
        move.w d1,(a1)+
        addq.l #2,a0
        dbra d0,.word
        rts

; The limits page: the view is scrolled to where the level's view may go
; no further, and Top left or Bottom right takes it as the lower or upper
; scroll limits, Whole map gives the map's; the start view and the other
; limits follow, so that the game can take them. Kept in limit_words until
; OK writes them into the record, one change.
limits_open:
        lea limit_words,a1
        bsr view_words
        moveq #PAGE_LIMITS,d0
        lea limits_widgets(pc),a0
        bra page_open

; Keys on the limits page: T, B and W as their buttons, Return OK, Esc
; Cancel; the view scrolls as in the modes.
limits_input:
        bsr widget_at
        move.w key,d0
        beq.s .mouse
        moveq #ID_L_OK,d1
        cmp.b #KEY_RETURN,d0
        beq.s .button
        moveq #ID_L_CANCEL,d1
        cmp.b #KEY_ESC,d0
        beq.s .button
        moveq #ID_L_TOP,d1
        cmp.b #'t',d0
        beq.s .button
        moveq #ID_L_BOTTOM,d1
        cmp.b #'b',d0
        beq.s .button
        moveq #ID_L_WHOLE,d1
        cmp.b #'w',d0
        bne.s .mouse
.button:
        move.w d1,d0
        bra widget_action
.mouse: tst.b G_LEFT_CLICK(a5)
        beq.s .done
        move.w hover,d0
        bpl widget_click
.done:  rts

; The page's start view and limits in the view.
draw_limits_ui:
        lea limit_words,a0
        bra view_frames

limits_top:
        lea limit_words,a0
        move.w G_SCROLL_X(a5),d4
        bsr.s lower_axis
        addq.l #2,a0
        move.w G_SCROLL_Y(a5),d4
        bsr.s lower_axis
        st fields_changed
        rts

limits_bottom:
        lea limit_words,a0
        move.w G_SCROLL_X(a5),d4
        bsr.s upper_axis
        addq.l #2,a0
        move.w G_SCROLL_Y(a5),d4
        bsr.s upper_axis
        st fields_changed
        rts

limits_whole:
        lea limit_words,a0
        clr.w 4(a0)
        move.w max_scroll_x,8(a0)
        bsr.s view_inside
        addq.l #2,a0
        clr.w 4(a0)
        move.w max_scroll_y,8(a0)
        bsr.s view_inside
        st fields_changed
        rts

; D4 the lower limit of one axis of the words at A0 (scroll, lower and
; upper limit at +0, +4 and +8). An upper limit below it moves to it, one
; off its 16-pixel steps to the step below; the start view follows
; (view_inside).
lower_axis:
        move.w d4,4(a0)
        move.w 8(a0),d1
        cmp.w d4,d1
        bge.s .above
        move.w d4,d1
.above: sub.w d4,d1
        and.w #-16,d1
        add.w d4,d1
        move.w d1,8(a0)
        bra.s view_inside

; D4 the upper limit of one axis, as lower_axis.
upper_axis:
        move.w d4,8(a0)
        move.w 4(a0),d1
        cmp.w d4,d1
        ble.s .below
        move.w d4,d1
.below: move.w d4,d2
        sub.w d1,d2
        and.w #-16,d2
        move.w d4,d1
        sub.w d2,d1
        move.w d1,4(a0)
        ; fall through

; The start view of one axis at A0 inside its limits at +4 and +8, which
; lie on one grid of 16-pixel steps, and on a step from the lower one.
view_inside:
        move.w (a0),d1
        move.w 4(a0),d2
        cmp.w d2,d1
        bge.s .low
        move.w d2,d1
.low:   cmp.w 8(a0),d1
        ble.s .high
        move.w 8(a0),d1
.high:  sub.w d2,d1
        and.w #-16,d1
        add.w d2,d1
        move.w d1,(a0)
        rts

; OK: the page's start view and limits into the record and the header, a
; change when they differ from the record's.
limits_ok:
        lea limit_words,a1
        lea edit_record+R_VIEW,a0
        movea.l level_header,a2
        lea H_VIEW(a2),a2
        moveq #0,d2                     ; a word changed
        moveq #0,d3                     ; the start view changed
        moveq #6-1,d0
.word:  bsr get_le
        cmp.w (a1),d1
        beq.s .same
        moveq #1,d2
        cmp.w #4,d0                     ; words 5 and 4: the start view
        blo.s .limit
        moveq #1,d3
.limit: move.w (a1),d1
        bsr put_le
.same:  move.w d1,(a2)+
        addq.l #2,a0
        addq.l #2,a1
        dbra d0,.word
        tst.w d2
        beq mode_widgets
        lea s_limits_set(pc),a0
        tst.w d3
        beq.s .message
        lea s_limits_view(pc),a0
.message:
        moveq #UI_OK,d0
        bsr set_message
        bsr level_changed
        bra mode_widgets

;----------------------------------------------------------------------------
; The title

title_open:
        lea edit_record+R_TITLE_TEXT,a0
        lea title_text,a1
        moveq #TITLE_SIZE-1,d0
.copy:  move.b (a0)+,d1                 ; what the font cannot show: spaces
        cmp.b #' ',d1
        blo.s .space
        cmp.b #'z',d1
        bhi.s .space
        cmp.b #'#',d1
        bne.s .char
.space: moveq #' ',d1
.char:  move.b d1,(a1)+
        dbra d0,.copy
        lea title_text,a0               ; without its trailing spaces
        moveq #TITLE_SIZE,d0
.trim:  cmp.b #' ',-1(a0,d0.w)
        bne.s .length
        subq.w #1,d0
        bne.s .trim
.length:
        move.b d0,title_length
        moveq #PAGE_TITLE,d0
        lea title_widgets(pc),a0
        bra page_open

; The typed title, padded with spaces, into the record and the header.
title_ok:
        moveq #0,d0
        move.b title_length,d0
        lea title_text,a0
        moveq #TITLE_SIZE-1,d1
.pad:   cmp.w d1,d0
        bhi.s .padded
        move.b #' ',0(a0,d1.w)
        dbra d1,.pad
.padded:
        lea edit_record+R_TITLE_TEXT,a1
        movea.l level_header,a2
        moveq #0,d2                     ; changed
        moveq #TITLE_SIZE-1,d1
.copy:  move.b (a0)+,d0
        cmp.b (a1),d0
        beq.s .same
        moveq #1,d2
.same:  move.b d0,(a1)+
        move.b d0,(a2)+
        dbra d1,.copy
        tst.w d2
        beq mode_widgets
        bsr level_changed
        bra mode_widgets

; Keys on the title page: characters of the game's font (32 to 122, '#'
; aside, which its text streams take for a number) are added, Backspace
; and Del take the last off, Shift+Backspace/Del or Ctrl+U clears the title,
; Return keeps the title, Esc the old one.
title_input:
        bsr widget_at
        move.w key_char,d0
        beq .mouse
        cmp.b #KEY_RETURN,d0
        beq title_ok
        cmp.b #KEY_ESC,d0
        beq mode_widgets
        cmp.b #8,d0
        beq .bksp
        cmp.b #$7f,d0
        beq .bksp
        tst.b G_MODIFIERS+2(a5)         ; Control held
        beq .char
        cmp.b #'u',d0
        beq .clear
        cmp.b #'U',d0
        beq .clear
        bra .mouse
.char:  cmp.b #' ',d0
        blo .mouse
        cmp.b #'z',d0
        bhi .mouse
        cmp.b #'#',d0
        beq .mouse
        moveq #0,d1
        move.b title_length,d1
        cmp.w #TITLE_SIZE,d1
        bhs .mouse
        lea title_text,a0
        move.b d0,0(a0,d1.w)
        addq.b #1,title_length
        st fields_changed
        bra .mouse
.bksp:  tst.b G_MODIFIERS(a5)           ; Shift held: clear the title
        bne .clear
        tst.b title_length
        beq .mouse
        subq.b #1,title_length
        st fields_changed
        bra .mouse
.clear: tst.b title_length
        beq .mouse
        clr.b title_length
        st fields_changed
.mouse: tst.b G_LEFT_CLICK(a5)
        beq .done
        move.w hover,d0
        bpl widget_click
.done:  rts

;----------------------------------------------------------------------------
; The in-view skills page (PAGE_SKILLS)

; The edit view built again from the record as when it was opened, the
; editor's state (mode, view, brush, selections, unsaved changes) kept.
; Called by undo.s when returning from test play.
edit_rebuild:
        st resuming
        bra build_record

; Open PAGE_SKILLS: back up the current 8 skills and counts (for Cancel and
; for keeping old counts of re-picked skills), finish any entry fade, and
; open the bar page. The palette switches to PAL_PRACTICE on the exact VBlank
; that swaps the first drawn grid into the front buffer (sync_play_palette).
skills_open:
        lea edit_record+R_SKILLS,a0
        lea skills_backup,a1
        moveq #3*SKILL_SLOTS-1,d0
.keep:  move.b (a0)+,(a1)+
        dbra d0,.keep
        move.w level_slot,skills_old_slot
        lea edit_record+R_STYLE,a0
        bsr get_le
        tst.w d1
        seq skills_classic
        move.w fade_in,d0               ; finish any entry fade before the
        clr.w fade_in                   ; copper colours switch
        bra.s .fade_test
.fade:  move.w d0,-(sp)
        bsr fade_up
        move.w (sp)+,d0
.fade_test:
        dbra d0,.fade
        moveq #PAGE_SKILLS,d0
        lea skills_widgets(pc),a0
        bsr page_open
        bra panel_highlight

; Called from edit_irq right after swapping G_FRONT and G_BACK: updates the
; 16 play-area colour moves in hunk 1 when switching between the level view
; and PAGE_SKILLS, so neither view flashes in the other's palette.
sync_play_palette:
        movem.l d0/a0-a1,-(sp)
        move.b skills_pal_want,d0
        cmp.b skills_pal_shown,d0
        beq.s .done
        move.b d0,skills_pal_shown
        movea.l pal_play,a0
        tst.b d0
        beq.s .copy
        movea.l pal_practice,a0
.copy:  movea.l hunk1,a1
        move.w (a0),COP_PLAY_BG+2(a1)   ; play-area background colour 0
        lea COP_PLAY_COLOURS+2(a1),a1
        moveq #16-1,d0
.col:   move.w (a0)+,(a1)
        addq.l #4,a1
        dbra d0,.col
.done:  movem.l (sp)+,d0/a0-a1
        rts

; One pass of PAGE_SKILLS (dispatched from edit_loop).
skills_pass:
        bsr scroll_flags_clear          ; the display does not scroll
        GCALL view_desc
        GCALL buttons
        bsr read_key
        bsr update_pointer
        bsr skills_draw
        bsr skills_input
        bsr skills_frames
        bsr edit_help
        bsr skills_status
        bsr bar_refresh
        st skills_pal_want              ; G_BACK holds the skills grid
        st G_PASS_DONE(a5)
        bra edit_loop

; Clear the play area of G_BACK and draw the 50 style-valid skill icons in
; a 10x5 grid (32x24 pixels each) using the game's panel sprites (A5+$23A,
; group 1, mode 4 masked word-aligned CPU draw).
skills_draw:
        movem.l d0-d7/a0-a2,-(sp)
        bsr wait_blit
        movea.l G_BACK(a5),a0
        lea VIEW_EDGE*VIEW_ROW(a0),a0
        moveq #3,d1
.plane: movea.l a0,a1
        move.w #SCREEN_ROWS*VIEW_ROW/4-1,d0
.clear: clr.l (a1)+
        dbra d0,.clear
        lea VIEW_PLANE(a0),a0
        dbra d1,.plane
        movea.l G_PANEL_SPRITES(a5),a0
        move.w G_SCROLL_Y(a5),d1
        add.w #VIEW_EDGE+SKILLS_TOP,d1
        moveq #4,d2                     ; masked CPU draw, 4 planes
        moveq #0,d3                     ; play view descriptor (G_BACK)
        moveq #1,d4                     ; group 1: skill icons
        suba.l a2,a2                    ; place 0..49
        moveq #SKILLS_ROWS-1,d7
.row:   move.w G_SCROLL_X(a5),d0
        add.w #VIEW_EDGE,d0
        moveq #SKILLS_COLS-1,d6
.col:   move.w a2,d5
        tst.b skills_classic
        beq.s .icon
        cmp.w #SKILL_ATTRACTOR-1,d5
        bne.s .icon
        moveq #SKILL_BLOCKER-1,d5
.icon:  GCALL sprite
        addq.w #1,a2
        add.w #SKILLS_CELL_W,d0
        dbra d6,.col
        add.w #SKILLS_CELL_H,d1
        dbra d7,.row
        movem.l (sp)+,d0-d7/a0-a2
        rts

; Outlines on the skills grid: inner 30x22 boxes for skills currently in the
; level (gold for the selected slot, medium plum for the other slots), and an
; outer 32x24 white box around the skill under the pointer.
skills_frames:
        movem.l d0-d5,-(sp)
        moveq #0,d0
.slot:  bsr skill_id
        beq.s .next
        bsr skills_place_of
        bmi.s .next
        moveq #SKILLS_COL_USED,d4
        cmp.w level_slot,d0
        bne.s .draw
        moveq #SKILLS_COL_SEL,d4
.draw:  moveq #1,d5                     ; inner 30x22 box
        bsr skills_box
.next:  addq.w #1,d0
        cmp.w #SKILL_SLOTS,d0
        blo.s .slot
        bsr skills_hit
        tst.w d0
        bmi.s .done
        moveq #SKILLS_COL_HOVER,d4
        moveq #0,d5                     ; outer 32x24 box
        bsr skills_box
.done:  movem.l (sp)+,d0-d5
        rts

; Draw a 1-pixel frame in G_BACK at grid place D1 (0..49) in PAL_PRACTICE
; colour D4 (0..15): D5 = 0 outer 32x24, D5 = 1 inner 30x22. Preserves all.
skills_box:
        movem.l d0-d7/a0-a1,-(sp)
        ext.l d1
        divu #SKILLS_COLS,d1            ; D1.w = row, high word = col
        move.w d1,d0
        mulu #SKILLS_CELL_H,d0
        add.w #VIEW_EDGE+SKILLS_TOP,d0
        tst.w d5
        beq.s .y_ok
        addq.w #1,d0
.y_ok:  mulu #VIEW_ROW,d0
        swap d1                         ; col 0..9
        lsl.w #2,d1                     ; 4 bytes per 32-pixel column
        addq.w #VIEW_EDGE/8,d1
        movea.l G_BACK(a5),a0
        adda.l d0,a0
        adda.w d1,a0
        tst.w d5
        bne.s .inner
        moveq #-1,d0                    ; $FFFF
        moveq #-1,d1                    ; $FFFF
        move.w #$8000,d2
        moveq #1,d3
        moveq #SKILLS_CELL_H-3,d6       ; 22 middle rows
        bra.s .draw
.inner: move.w #$7fff,d0
        move.w #$fffe,d1
        move.w #$4000,d2
        moveq #2,d3
        moveq #SKILLS_CELL_H-5,d6       ; 20 middle rows
.draw:  bsr.s skills_box_row            ; top row
        exg d0,d2
        exg d1,d3
.mid:   lea VIEW_ROW(a0),a0
        bsr.s skills_box_row
        dbra d6,.mid
        lea VIEW_ROW(a0),a0
        move.w d2,d0
        move.w d3,d1
        bsr.s skills_box_row            ; bottom row
        movem.l (sp)+,d0-d7/a0-a1
        rts

; Write two word masks D0, D1 into four planes at A0 in colour D4. Preserves all.
skills_box_row:
        movem.l d4-d7/a1,-(sp)
        movea.l a0,a1
        move.w d0,d5
        not.w d5
        move.w d1,d6
        not.w d6
        moveq #3,d7
.plane: lsr.w #1,d4
        bcc.s .clear
        or.w d0,(a1)
        or.w d1,2(a1)
        bra.s .next
.clear: and.w d5,(a1)
        and.w d6,2(a1)
.next:  lea VIEW_PLANE(a1),a1
        dbra d7,.plane
        movem.l (sp)+,d4-d7/a1
        rts

; Input on PAGE_SKILLS.
skills_input:
        bsr widget_at
        move.w key,d0
        beq.s .mouse
        cmp.b #KEY_RETURN,d0
        beq skills_ok
        cmp.b #KEY_ESC,d0
        beq skills_cancel
        lea skills_keys(pc),a0
        bsr key_button
.mouse: tst.b G_LEFT_CLICK(a5)
        beq.s .right
        move.w G_CURSOR_Y(a5),d1
        cmp.w #SCREEN_ROWS,d1
        blo.s .grid
        cmp.w #BAR_CURSOR_Y,d1
        blo skills_panel_click
        move.w hover,d0
        bpl widget_click
        rts
.grid:  bsr skills_hit
        tst.w d0
        bpl skills_grid_click
        rts
.right: tst.b G_RIGHT_CLICK(a5)
        beq.s .done
        bra skills_right_click
.done:  rts

skills_keys:
        dc.w ',',ID_S_PREV
        dc.w '.',ID_S_NEXT
        dc.w $7f,ID_S_REMOVE
        dc.w 'c',ID_S_CLEAR
        dc.w 0

; Left click on skill ID D0 (1..51) in the grid.
skills_grid_click:
        move.w d0,d7                    ; chosen skill ID
        bsr bar_sound
        move.w d7,d0
        bsr skills_find                 ; -> D2 existing slot, or -1
        move.w level_slot,d0
        bsr skill_id                    ; -> D1 current skill in level_slot
        beq .empty
        cmp.w level_slot,d2
        beq .done                       ; already this skill in this slot
        tst.w d2
        bpl.s .swap
        ; Replace occupied slot with a skill not currently in the level
        move.w d7,d0
        bsr skills_backup_count         ; -> D2 count (old if backed up, else 10)
        move.w level_slot,d0
        bsr skill_id                    ; -> A0 its record word
        move.w d7,d1
        bsr put_le
        lea edit_record+R_COUNTS,a0
        move.b d2,0(a0,d0.w)
        bsr skills_shown
        st fields_changed
        rts
.swap:  ; Skill D7 is already in slot D2: swap slots level_slot and D2
        move.w level_slot,d0
        bsr skill_id                    ; -> D1 id_a, A0 ptr_a
        move.w d1,d5
        movea.l a0,a1
        move.w d2,d0
        bsr skill_id                    ; -> D1 id_b, A0 ptr_b
        move.w d1,d6
        move.w d5,d1
        bsr put_le                      ; slot D2 <- id_a
        movea.l a1,a0
        move.w d6,d1
        bsr put_le                      ; level_slot <- id_b
        lea edit_record+R_COUNTS,a0
        move.w level_slot,d0
        move.b 0(a0,d0.w),d5
        move.b 0(a0,d2.w),0(a0,d0.w)
        move.b d5,0(a0,d2.w)
        bsr skills_shown
        st fields_changed
        lea message_text,a3
        lea s_swapped(pc),a0
        bsr put_str
        move.w d2,d0
        addq.w #1,d0
        bsr put_number
        lea message_text,a0
        moveq #UI_INK,d0
        bra set_message
.empty: tst.w d2
        bmi.s .add
        ; level_slot is empty and D7 is already in slot D2: refuse duplicate
        lea message_text,a3
        lea s_already_slot(pc),a0
        bsr put_str
        move.w d2,d0
        addq.w #1,d0
        bsr put_number
        lea message_text,a0
        moveq #UI_WARN,d0
        bra set_message
.add:   ; Fill empty level_slot and advance to the next slot for rapid picking
        move.w d7,d0
        bsr skills_backup_count         ; -> D2 count
        move.w level_slot,d0
        bsr skill_id                    ; -> A0 its record word
        move.w d7,d1
        bsr put_le
        lea edit_record+R_COUNTS,a0
        move.b d2,0(a0,d0.w)
        cmp.w #SKILL_SLOTS-1,d0
        bhs.s .added
        addq.w #1,level_slot
.added: bsr skills_shown
        st fields_changed
.done:  rts

; Click in the skill panel while on PAGE_SKILLS: selects the slot (an empty
; slot selects the first empty slot so empty slots stay last).
skills_panel_click:
        move.w G_CURSOR_X(a5),d0
        cmp.w #SKILL_AREA,d0
        bhs.s .done
        lsr.w #5,d0
        bsr skill_id
        bne.s .sel
        bsr skills_first_empty
        cmp.w #SKILL_SLOTS,d0
        bhs.s .done
.sel:   bsr bar_sound
        bra select_skill
.done:  rts

; Right click on PAGE_SKILLS: removes the clicked skill (in the grid or panel).
skills_right_click:
        move.w G_CURSOR_Y(a5),d1
        cmp.w #SCREEN_ROWS,d1
        blo.s .grid
        cmp.w #BAR_CURSOR_Y,d1
        bhs.s .done
        move.w G_CURSOR_X(a5),d0
        cmp.w #SKILL_AREA,d0
        bhs.s .done
        lsr.w #5,d0
        bsr skill_id
        beq.s .done
        bra.s .rem
.grid:  bsr skills_hit
        tst.w d0
        bmi.s .done
        bsr skills_find
        move.w d2,d0
        bmi.s .done
.rem:   bsr bar_sound
        bra.s skills_remove_at
.done:  rts

skills_slot_prev:
        tst.w level_slot
        beq.s .done
        subq.w #1,level_slot
        st fields_changed
        bra panel_highlight
.done:  rts

skills_slot_next:
        bsr skills_can_next
        beq.s .done
        addq.w #1,level_slot
        st fields_changed
        bra panel_highlight
.done:  rts

skills_remove:
        move.w level_slot,d0
        bsr skill_id
        beq.s skills_remove_done
        ; fall through

; D0 a slot: removed on PAGE_SKILLS, keeping level_slot at or before the
; first empty slot.
skills_remove_at:
        bsr skill_shift_out
        bsr skills_first_empty          ; -> D0 first empty (0..8)
        cmp.w #SKILL_SLOTS,d0
        blo.s .clamp
        moveq #SKILL_SLOTS-1,d0
.clamp: cmp.w level_slot,d0
        bhs.s .show
        move.w d0,level_slot
.show:  bsr skills_shown
        st fields_changed
skills_remove_done:
        rts

; Clear all eight slots on PAGE_SKILLS and select slot 0.
skills_clear:
        lea edit_record+R_SKILLS,a0
        moveq #3*SKILL_SLOTS-1,d0
.zero:  clr.b (a0)+
        dbra d0,.zero
        clr.w level_slot
        bsr skills_shown
        st fields_changed
        rts

; OK: keep the skills; mark dirty/touched as one undo step when they changed,
; ensure Param mode lands on an occupied slot if any exist.
skills_ok:
        lea edit_record+R_SKILLS,a0
        lea skills_backup,a1
        moveq #3*SKILL_SLOTS-1,d0
.cmp:   cmpm.b (a0)+,(a1)+
        dbne d0,.cmp
        beq.s .same
        bsr level_changed
.same:  move.w level_slot,d0
.slot:  bsr skill_id
        bne.s .chosen
        subq.w #1,d0
        bpl.s .slot
        moveq #0,d0
.chosen:
        move.w d0,level_slot
        bsr panel_highlight
        bra mode_widgets

; Cancel: restore the backed-up skills, counts and selected slot.
skills_cancel:
        lea skills_backup,a0
        lea edit_record+R_SKILLS,a1
        moveq #3*SKILL_SLOTS-1,d0
.copy:  move.b (a0)+,(a1)+
        dbra d0,.copy
        move.w skills_old_slot,level_slot
        bsr skills_shown
        lea s_skills_kept(pc),a0
        moveq #UI_INK,d0
        bsr set_message
        bra mode_widgets

; -> D0 skill ID (1..51) and D1 grid place (0..49) under pointer, or D0 = -1.
skills_hit:
        moveq #-1,d0
        move.w G_CURSOR_Y(a5),d1
        sub.w #SKILLS_TOP,d1
        bmi.s .out
        cmp.w #SKILLS_ROWS*SKILLS_CELL_H,d1
        bhs.s .out
        ext.l d1
        divu #SKILLS_CELL_H,d1
        mulu #SKILLS_COLS,d1
        move.w G_CURSOR_X(a5),d0
        lsr.w #5,d0
        cmp.w #SKILLS_COLS,d0
        bhs.s .none
        add.w d0,d1                     ; D1 = place 0..49
        move.w d1,d0
        addq.w #1,d0                    ; 1..50
        tst.b skills_classic
        beq.s .out
        cmp.w #SKILL_ATTRACTOR,d0
        bne.s .out
        moveq #SKILL_BLOCKER,d0
        rts
.none:  moveq #-1,d0
.out:   rts

; D1 a skill ID -> D1 its grid place (0..49), or -1 (N set) if not on grid.
skills_place_of:
        tst.b skills_classic
        beq.s .other
        cmp.w #SKILL_BLOCKER,d1
        beq.s .attractor
        cmp.w #SKILL_ATTRACTOR,d1
        beq.s .none
        bra.s .range
.other: cmp.w #SKILL_BLOCKER,d1
        beq.s .none
.range: tst.w d1
        ble.s .none
        cmp.w #50,d1
        bhi.s .none
        subq.w #1,d1
        rts
.attractor:
        moveq #SKILL_ATTRACTOR-1,d1
        rts
.none:  moveq #-1,d1
        rts

; D0 a skill ID -> D2 the slot (0..7) holding it, or -1 (N set). Preserves D0.
skills_find:
        movem.l d0-d1/a0,-(sp)
        move.w d0,d2
        moveq #0,d0
.slot:  bsr skill_id
        cmp.w d2,d1
        beq.s .found
        addq.w #1,d0
        cmp.w #SKILL_SLOTS,d0
        blo.s .slot
        moveq #-1,d2
        bra.s .out
.found: move.w d0,d2
.out:   movem.l (sp)+,d0-d1/a0
        tst.w d2
        rts

; -> D0 the first empty slot (0..7), or 8 when all slots are filled.
skills_first_empty:
        movem.l d1/a0,-(sp)
        moveq #0,d0
.slot:  bsr skill_id
        beq.s .out
        addq.w #1,d0
        cmp.w #SKILL_SLOTS,d0
        blo.s .slot
.out:   movem.l (sp)+,d1/a0
        rts

; -> D0 number of occupied skill slots (0..8). Preserves all else.
skills_count:
        movem.l d1-d2/a0,-(sp)
        moveq #0,d2
        moveq #0,d0
.slot:  bsr skill_id
        beq.s .next
        addq.w #1,d2
.next:  addq.w #1,d0
        cmp.w #SKILL_SLOTS,d0
        blo.s .slot
        move.w d2,d0
        movem.l (sp)+,d1-d2/a0
        rts

; Z clear when > on PAGE_SKILLS can step right (level_slot < 7 and some slot
; at or after level_slot is occupied). Preserves all else.
skills_can_next:
        movem.l d0-d1/a0,-(sp)
        move.w level_slot,d0
        cmp.w #SKILL_SLOTS-1,d0
        bhs.s .no
.slot:  bsr skill_id
        bne.s .yes
        addq.w #1,d0
        cmp.w #SKILL_SLOTS,d0
        blo.s .slot
.no:    moveq #0,d0
        bra.s .out
.yes:   moveq #1,d0
.out:   movem.l (sp)+,d0-d1/a0
        rts

; D0 a skill ID -> D2 its count in skills_backup when present and non-zero,
; else NEW_COUNT. Preserves D0.
skills_backup_count:
        movem.l d0-d1/d3/a0-a1,-(sp)
        moveq #NEW_COUNT,d2
        lea skills_backup,a0
        lea skills_backup+2*SKILL_SLOTS,a1
        moveq #SKILL_SLOTS-1,d3
.find:  bsr get_le
        addq.l #2,a0
        cmp.w d0,d1
        bne.s .next
        tst.b (a1)
        beq.s .next
        moveq #0,d2
        move.b (a1),d2
        bra.s .done
.next:  addq.l #1,a1
        dbra d3,.find
.done:  movem.l (sp)+,d0-d1/d3/a0-a1
        rts

; D0 a skill ID (1..51) -> its trimmed name from skill_names at A3.
put_skill_name:
        movem.l d0-d1/a0-a1,-(sp)
        mulu #14,d0
        movea.l skill_names,a0
        adda.w d0,a0
        movea.l a3,a1
        moveq #14-1,d1
.copy:  move.b (a0)+,(a3)+
        dbra d1,.copy
.trim:  cmpa.l a1,a3
        beq.s .done
        cmp.b #' ',-1(a3)
        bne.s .done
        subq.l #1,a3
        bra.s .trim
.done:  movem.l (sp)+,d0-d1/a0-a1
        rts

; Status line on PAGE_SKILLS: the hovered skill's name (and slot if already
; equipped), else how many skills the level has.
skills_status:
        lea status_text,a3
        bsr skills_hit
        tst.w d0
        bmi.s .count
        bsr put_skill_name
        bsr skills_find
        bmi.s .done
        lea s_in_slot(pc),a0
        bsr put_str
        move.w d2,d0
        addq.w #1,d0
        bsr put_number
        move.b #')',(a3)+
        bra.s .done
.count: lea s_skills_count(pc),a0
        bsr put_str
        bsr skills_count
        bsr put_number
        lea s_of_8(pc),a0
        bsr put_str
.done:  clr.b (a3)
        bra status_done

; Help line on PAGE_SKILLS when no button is under the pointer.
skills_help:
        lea s_skills_grid_help(pc),a0
        move.w G_CURSOR_Y(a5),d1
        cmp.w #SCREEN_ROWS,d1
        blo.s .show
        lea s_skills_panel_help(pc),a0
        cmp.w #BAR_CURSOR_Y,d1
        blo.s .show
        lea s_skills_bar_help(pc),a0
.show:  moveq #UI_DIM,d0
        bra set_help

;----------------------------------------------------------------------------
; The bar in the Param mode

; The help line over the map and the panel.
level_help:
        lea s_level_map_help(pc),a0
        move.w G_CURSOR_Y(a5),d1
        cmp.w #SCREEN_ROWS,d1
        blo.s .show
        lea s_level_panel_help(pc),a0
        cmp.w #BAR_CURSOR_Y,d1
        blo.s .show
        lea s_empty(pc),a0
.show:  moveq #UI_DIM,d0
        bra set_help

; -> D1 the selected skill's count and A0 the record's counts; Z set when
; its slot has no skill. Preserves D0.
selected_count:
        move.l d0,-(sp)
        move.w level_slot,d0
        bsr skill_id
        beq.s .none
        lea edit_record+R_COUNTS,a0
        moveq #0,d1
        move.b 0(a0,d0.w),d1
        andi #$fb,ccr
.none:  movem.l (sp)+,d0                ; the flags stay
        rts

; D0 a Param tool -> D5 ST_NORMAL or ST_DISABLED: Remove and the count
; need a skill in the selected slot; -/+ stop at their range; < and > at
; the first and the last skill. Preserves the other registers.
level_widget_state:
        movem.l d0-d2/d6/a0,-(sp)
        moveq #ST_NORMAL,d5
        move.w d0,d6
        cmp.w #ID_REMOVE,d6
        beq .used
        cmp.w #ID_S_REMOVE,d6
        beq .used
        cmp.w #ID_S_PREV,d6
        beq .s_prev
        cmp.w #ID_S_NEXT,d6
        beq .s_next
        cmp.w #ID_S_CLEAR,d6
        beq .s_clear
        cmp.w #ID_COUNT_LESS,d6
        beq .count_less
        cmp.w #ID_COUNT_MORE,d6
        beq .count_more
        cmp.w #ID_SLOT_PREV,d6
        beq .previous
        cmp.w #ID_SLOT_NEXT,d6
        beq .next
        cmp.w #ID_TIME_LESS,d6
        beq .time_less
        cmp.w #ID_TIME_MORE,d6
        beq .time_more
        moveq #RATE_MAX,d2
        lea edit_record+R_RATE,a0
        cmp.w #ID_RATE_LESS,d6
        beq .less
        cmp.w #ID_RATE_MORE,d6
        beq .more
        moveq #LOST_MAX,d2
        lea edit_record+R_LOST,a0
        cmp.w #ID_LOST_LESS,d6
        beq .less
        cmp.w #ID_LOST_MORE,d6
        beq .more
        bra .out
.used:  move.w level_slot,d0
        bsr skill_id
        beq .disabled
        bra .out
.s_prev:
        tst.w level_slot
        beq .disabled
        bra .out
.s_next:
        bsr skills_can_next
        beq .disabled
        bra .out
.s_clear:
        bsr skills_count
        tst.w d0
        beq .disabled
        bra .out
.count_less:
        bsr selected_count
        beq .disabled
        cmp.w #COUNT_MIN,d1
        bls .disabled
        bra .out
.count_more:
        bsr selected_count
        beq .disabled
        cmp.w #COUNT_MAX,d1
        bhs .disabled
        bra .out
.previous:
        bsr skill_before
        bmi .disabled
        bra .out
.next:  bsr skill_after
        bmi .disabled
        bra .out
.time_less:
        bsr level_time
        cmp.w #TIME_MIN,d0
        bls .disabled
        bra .out
.time_more:
        bsr level_time
        cmp.w #TIME_MAX,d0
        bhs .disabled
        bra .out
.less:  bsr get_le
        tst.w d1
        beq .disabled
        bra .out
.more:  bsr get_le
        cmp.w d2,d1
        bhs .disabled
        bra .out
.disabled:
        moveq #ST_DISABLED,d5
.out:   movem.l (sp)+,d0-d2/d6/a0
        rts

; D0 a Param text field -> its text at A3 (widget_text ends it). Changes
; D0-D2/A0.
level_widget_text:
        cmp.w #ID_COUNT,d0
        bne .time
        lea s_count(pc),a0
        bsr put_str
        bsr selected_count
        beq .none
        move.w d1,d0
        bsr put_number
        bra .out
.none:  move.b #'-',(a3)+
        bra .out
.time:  cmp.w #ID_TIME,d0
        bne .rate
        lea s_time(pc),a0
        bsr put_str
        moveq #0,d0
        move.b edit_record+R_MINUTES,d0
        moveq #0,d2
        move.b edit_record+R_SECONDS,d2
        bra put_time
.rate:  cmp.w #ID_RATE,d0
        bne .lost
        lea s_rate(pc),a0
        bsr put_str
        lea edit_record+R_RATE,a0
        bra .word
.lost:  cmp.w #ID_LOST,d0
        bne .limits
        lea s_lost(pc),a0
        bsr put_str
        lea edit_record+R_LOST,a0
.word:  bsr get_le
        move.w d1,d0
        bsr put_number
        bra .out
.limits:
        cmp.w #ID_LIMITS_TEXT,d0
        bne .skills_info
        lea s_limits_text(pc),a0        ; the cells the level can show: from
        bsr put_str                     ; the lower limits' screen's first
        lea limit_words+4,a0            ; to the upper limits' last
        moveq #VIEW_EDGE,d1
        moveq #VIEW_EDGE,d2
        bsr.s .cell
        lea s_limits_to(pc),a0
        bsr put_str
        lea limit_words+8,a0
        move.w #VIEW_EDGE+BAR_W-1,d1
        move.w #VIEW_EDGE+SCREEN_ROWS-1,d2
        bsr.s .cell
        bra .out
.cell:  move.w (a0)+,d0                 ; A0 a scroll x and y, D1 and D2 the
        add.w d1,d0                     ; pixel's place from it
        lsr.w #CELL_SHIFT_X,d0
        bsr put_number
        move.b #',',(a3)+
        move.w (a0),d0
        add.w d2,d0
        lsr.w #CELL_SHIFT_Y,d0
        bra put_number
.skills_info:
        cmp.w #ID_SKILLS_INFO,d0
        bne .title
        lea s_slot_prefix(pc),a0
        bsr put_str
        move.w level_slot,d0
        addq.w #1,d0
        bsr put_number
        lea s_of_8_colon(pc),a0
        bsr put_str
        move.w level_slot,d0
        bsr skill_id
        beq.s .slot_empty
        move.w d1,d0
        bsr put_skill_name
        move.b #' ',(a3)+
        move.b #'(',(a3)+
        bsr selected_count
        move.w d1,d0
        bsr put_number
        move.b #')',(a3)+
        bra .out
.slot_empty:
        lea s_cell_empty(pc),a0
        bra put_str
.title: lea s_title_prefix(pc),a0
        bsr put_str
        lea title_text,a0
        moveq #0,d0
        move.b title_length,d0
        bra .test
.char:  move.b (a0)+,(a3)+
.test:  dbra d0,.char
        move.b #'_',(a3)+
.out:   rts

;============================================================================
; The Param mode's widgets: two rows of tools; the status line's place is
; the second, and only the unsaved mark stays at its right end.

level_widgets:
        COMMON_ROW
        WIDGET 2,ROW_B,34,ID_TITLE,s_title,h_title
        WIDGET 39,ROW_B,40,ID_SKILLS,s_skills,h_skills
        WIDGET 82,ROW_B,40,ID_REMOVE,s_remove,h_remove
        WIDGET 125,ROW_B,52,ID_COUNT,0,0
        WIDGET 179,ROW_B,12,ID_COUNT_LESS,s_minus,h_count_less
        WIDGET 193,ROW_B,12,ID_COUNT_MORE,s_plus,h_count_more
        WIDGET 208,ROW_B,14,ID_SLOT_PREV,s_prev_object,h_slot_prev
        WIDGET 224,ROW_B,14,ID_SLOT_NEXT,s_next_object,h_slot_next
        WIDGET 241,ROW_B,34,ID_VIEW,s_start,h_view
        WIDGET 277,ROW_B,40,ID_LIMITS,s_limits,h_limits
        WIDGET 2,ROW_C,58,ID_TIME,0,0
        WIDGET 62,ROW_C,12,ID_TIME_LESS,s_minus,h_time_less
        WIDGET 76,ROW_C,12,ID_TIME_MORE,s_plus,h_time_more
        WIDGET 92,ROW_C,46,ID_RATE,0,0
        WIDGET 140,ROW_C,12,ID_RATE_LESS,s_minus,h_rate_less
        WIDGET 154,ROW_C,12,ID_RATE_MORE,s_plus,h_rate_more
        WIDGET 170,ROW_C,46,ID_LOST,0,0
        WIDGET 218,ROW_C,12,ID_LOST_LESS,s_minus,h_lost_less
        WIDGET 232,ROW_C,12,ID_LOST_MORE,s_plus,h_lost_more
        dc.w -1

title_widgets:
        WIDGET 4,ROW_A,312,ID_TITLE_TEXT,0,0
        WIDGET 88,ROW_B,34,ID_T_OK,s_ok,h_t_ok
        WIDGET 128,ROW_B,46,ID_T_CANCEL,s_cancel,h_t_cancel
        dc.w -1

limits_widgets:
        WIDGET 4,ROW_A,312,ID_LIMITS_TEXT,0,0
        WIDGET 4,ROW_B,52,ID_L_TOP,s_top_left,h_top_left
        WIDGET 58,ROW_B,76,ID_L_BOTTOM,s_bottom_right,h_bottom_right
        WIDGET 136,ROW_B,58,ID_L_WHOLE,s_whole_map,h_whole_map
        WIDGET 220,ROW_B,34,ID_L_OK,s_ok,h_l_ok
        WIDGET 260,ROW_B,46,ID_L_CANCEL,s_cancel,h_l_cancel
        dc.w -1

skills_widgets:
        WIDGET 4,ROW_A,312,ID_SKILLS_INFO,0,0
        WIDGET 4,ROW_B,14,ID_S_PREV,s_prev_object,h_s_prev
        WIDGET 20,ROW_B,14,ID_S_NEXT,s_next_object,h_s_next
        WIDGET 38,ROW_B,40,ID_S_REMOVE,s_remove,h_s_remove
        WIDGET 82,ROW_B,34,ID_S_CLEAR,s_clear,h_s_clear
        WIDGET 220,ROW_B,34,ID_S_OK,s_ok,h_s_ok
        WIDGET 260,ROW_B,46,ID_S_CANCEL,s_cancel,h_s_cancel
        dc.w -1

s_title:        dc.b "Title",0
s_skills:       dc.b "Skills",0
s_remove:       dc.b "Remove",0
s_clear:        dc.b "Clear",0
s_start:        dc.b "Start",0
s_limits:       dc.b "Limits",0
s_top_left:     dc.b "Top left",0
s_bottom_right: dc.b "Bottom right",0
s_whole_map:    dc.b "Whole map",0
s_ok:           dc.b "OK",0
s_count:        dc.b "Count ",0
s_time:         dc.b "Time ",0
s_rate:         dc.b "Rate ",0
s_lost:         dc.b "Lost ",0
s_title_prefix: dc.b "Title: ",0
s_limits_text:  dc.b "Scroll limits: cells ",0
s_limits_to:    dc.b " to ",0
s_slot_prefix:  dc.b "Slot ",0
s_of_8_colon:   dc.b " of 8: ",0
s_skills_count: dc.b "Skills: ",0
s_of_8:         dc.b " of 8",0
s_in_slot:      dc.b "  (slot ",0
s_swapped:      dc.b "Swapped with slot ",0
s_already_slot: dc.b "Already in slot ",0
h_level:        dc.b "Parameters: title, skills, time and grading (L)",0
h_title:        dc.b "Type the level's title (N)",0
h_skills:       dc.b "Choose or change the level's skills (P)",0
h_remove:       dc.b "Remove the selected skill (Del)",0
h_s_prev:       dc.b "Previous skill slot (,)",0
h_s_next:       dc.b "Next skill slot (.)",0
h_s_remove:     dc.b "Remove the selected slot's skill (Del)",0
h_s_clear:      dc.b "Clear all eight skill slots (C)",0
h_s_ok:         dc.b "Keep these skills (Return)",0
h_s_cancel:     dc.b "Keep the old skills (Esc)",0
h_count_less:   dc.b "Fewer of the selected skill (-)",0
h_count_more:   dc.b "More of the selected skill (+)",0
h_slot_prev:    dc.b "Select the skill to the left (,)",0
h_slot_next:    dc.b "Select the skill to the right (.)",0
h_view:         dc.b "Start the level with this view (V)",0
h_limits:       dc.b "Limit the scrolling and the lemmings' area (Shift+V)",0
h_top_left:     dc.b "The level scrolls up and left to this view (T)",0
h_bottom_right: dc.b "The level scrolls down and right to this view (B)",0
h_whole_map:    dc.b "The level scrolls over the whole map (W)",0
h_l_ok:         dc.b "Use these limits (Return)",0
h_l_cancel:     dc.b "Keep the old limits (Esc)",0
h_time_less:    dc.b "15 seconds less ([)",0
h_time_more:    dc.b "15 seconds more (])",0
h_rate_less:    dc.b "Lemmings come out more slowly (Shift+R)",0
h_rate_more:    dc.b "Lemmings come out faster (R)",0
h_lost_less:    dc.b "Best grade: fewer may be lost (Shift+G)",0
h_lost_more:    dc.b "Best grade: more may be lost (G)",0
h_t_ok:         dc.b "Use this title (Return)",0
h_t_cancel:     dc.b "Keep the old title (Esc)",0
s_title_help:   dc.b "Type the title   Backspace: delete   Return: done",0
s_level_map_help: dc.b "Frame: start view (V). Dotted: limits (Shift+V)",0
s_limits_help:  dc.b "Scroll the view, then set Top left or Bottom right",0
s_level_panel_help: dc.b "Click a skill in the panel to select it",0
s_skills_grid_help: dc.b "Click: set skill   Right click: remove",0
s_skills_panel_help: dc.b "Click: select slot   Right click: remove",0
s_skills_bar_help: dc.b "Return: keep   Esc: cancel",0
s_view_set:     dc.b "The level now starts with this view",0
s_view_widened: dc.b "Start view set; the scroll limits were widened",0
s_limits_set:   dc.b "Limits set; lemmings that leave the dotted frame die",0
s_limits_view:  dc.b "Limits set; the start view moved inside them",0
s_skills_kept:  dc.b "The skills are as they were",0
s_skill_removed: dc.b "Skill removed; the later ones moved left",0
s_attractor_out: dc.b "Attractor removed: it fails in the Classic style",0
s_blocker_out:  dc.b "Blocker removed: it works only in the Classic style",0
                even

;============================================================================

        section editor_bss,bss

skills_backup:  ds.b 3*SKILL_SLOTS      ; the IDs (LE16) and counts on open
title_text:     ds.b TITLE_SIZE
title_length:   ds.b 1
skills_classic: ds.b 1                  ; the grid offers the Blocker
skills_pal_want: ds.b 1                 ; back buffer wants PAL_PRACTICE
skills_pal_shown: ds.b 1                ; COP_PLAY_COLOURS holds PAL_PRACTICE
                even
skills_old_slot: ds.w 1
skills_fitted:  ds.w 1                  ; the skill skills_fit took out
resume_x:       ds.w 1
resume_y:       ds.w 1
frame_words:    ds.w 6                  ; the record's scroll words, to draw
