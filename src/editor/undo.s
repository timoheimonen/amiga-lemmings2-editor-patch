; Lemmings 2: The Tribes In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Undo and redo, and test play, for the edit view (edit.s). The edit view
; calls history_reset when a level is opened, record_saved after a save
; and undo_settle at the end of every pass; its Undo, Redo and Test buttons
; and their keys come to undo, redo, undo_key and test_ask, and undo_state
; disables Undo and Redo. editor.s calls test_result when test play ends
; and patches hook_escape into the game's play keys.
;
; Undo goes back through whole states of the record, 32 steps at most. A
; step is kept as the XOR of the record before and after it, in runs of
; long words (a step of a few cells takes a few dozen bytes, the largest
; possible one the record's size), so that the history fits the editor's
; room in ExpMem: 33 whole records would need an ExpMem of 960 KiB, with
; which the install does not start on 2 MiB of fast memory. undo_base is
; the state at hist_pos; applying step n turns state n into n + 1 and back.
; A step is over when no mouse button and no key is held: a record that
; changed by then becomes a new step (undo_settle, at the end of every pass
; of the edit view), so a stroke of the brush, a drag, a held -/+ button
; or key, a picker choice or a title is one step. After an undo or redo
; the play map and the objects are made again from the record, the parsed
; header, the play counts, the clock and the panel follow it, and the
; unsaved mark compares it with the record as last saved (saved_copy).
;
; Test plays the record being edited through the custom play path, as the
; list's Play does with a file (enter_level). The editor's state stays in
; its variables meanwhile; the result page's Edit builds the edit view
; again from the record (edit_rebuild), Replay plays it again, Levels
; leaves the editor (after its question when there are unsaved changes).
; Esc in test play goes back to the editor at once, as Edit does
; (hook_escape); in other play it starts the level again, as the game's.
; Play never writes the record: it plays a copy in hunk 3.
;
; Game addresses are offsets in the game's hunk 0; A5 is the game's
; globals.

UNDO_STEPS      equ 32
STEP_SPACE      equ $18000      ; for the steps
RECORD_LONGS    equ RECORD_SIZE/4
DIFF_MAX        equ RECORD_SIZE+16 ; the largest step: one run of all
RUN_GAP         equ 3           ; equal longs that end a run
QUESTION_LEAVE  equ 0           ; what the bar's question asks
QUESTION_TEST   equ 1

        section editor,code

;============================================================================
; The history

; When a level is opened: its record is the only state and the saved one.
history_reset:
        clr.w step_count
        clr.w hist_pos
        clr.l step_start
        sf touched
        lea edit_record,a0
        lea undo_base,a1
        bsr copy_record
        ; fall through

; The record as it is now is the one in its file.
record_saved:
        lea edit_record,a0
        lea saved_copy,a1
        bra copy_record

; D0 a step -> A2 its runs, D0 their offset in step_data.
step_address:
        lsl.w #2,d0
        lea step_start,a2
        move.l 0(a2,d0.w),d0
        lea step_data,a2
        adda.l d0,a2
        rts

; A0, A1 two records -> Z set when they are equal. Changes D0, A0, A1.
same_record:
        move.w #RECORD_LONGS-1,d0
.long:  cmpm.l (a0)+,(a1)+
        dbne d0,.long
        rts

; The unsaved mark: the record differs from the one last saved.
dirty_from_saved:
        lea edit_record,a0
        lea saved_copy,a1
        bsr same_record
        sne dirty
        rts

; At the end of a pass: when the record changed and nothing is held any
; more, the change is a step.
undo_settle:
        tst.b touched
        beq undo_done
        tst.b G_LEFT_DOWN(a5)
        bne undo_done
        tst.b G_RIGHT_DOWN(a5)
        bne undo_done
        tst.b G_HELD_KEY(a5)
        bne undo_done
        ; fall through

; A changed record becomes a new step after the current state; the steps
; that could be redone are dropped, and the oldest when there are 32 or
; their room is full.
undo_flush:
        tst.b touched
        beq undo_done
        sf touched
        lea undo_base,a0
        lea edit_record,a1
        bsr same_record
        beq.s .same                     ; changed and changed back
        move.w hist_pos,step_count
.room:  cmp.w #UNDO_STEPS,step_count
        bhs.s .drop
        move.w step_count,d0
        bsr step_address                ; the free room
        cmp.l #STEP_SPACE-DIFF_MAX,d0
        bls.s .write
.drop:  bsr step_drop
        bra.s .room
.write: bsr make_step
        move.w step_count,d0
        addq.w #1,d0
        move.w d0,step_count
        move.w d0,hist_pos
        lsl.w #2,d0
        lea step_start,a0
        suba.l #step_data,a2
        move.l a2,0(a0,d0.w)
        lea edit_record,a0
        lea undo_base,a1
        bsr copy_record
.same:  bsr dirty_from_saved            ; the tools mark every change unsaved
        st fields_changed
undo_done:
        rts

; The oldest step dropped: the others move to the front of step_data.
step_drop:
        move.l step_start+4,d1          ; its size
        move.w step_count,d0
        bsr step_address                ; D0 the end of the steps
        sub.l d1,d0                     ; bytes that move
        lea step_data,a1
        lea 0(a1,d1.l),a0
        lsr.l #2,d0
        bra.s .test
.move:  move.l (a0)+,(a1)+
.test:  subq.l #1,d0
        bpl.s .move
        lea step_start,a0               ; their offsets, one place down
        move.w step_count,d0
        subq.w #1,d0
.offset:
        move.l 4(a0),d2
        sub.l d1,d2
        move.l d2,(a0)+
        dbra d0,.offset
        subq.w #1,step_count
        subq.w #1,hist_pos
        rts

; The step from undo_base to edit_record at A2: runs of a long index, a
; count and the XOR longs, from the first that differs to the last before
; RUN_GAP equal ones; $FFFF ends. -> A2 after it.
make_step:
        lea undo_base,a0
        lea edit_record,a1
        moveq #0,d1                     ; the long looked at
.find:  cmp.w #RECORD_LONGS,d1
        bhs.s .end
        move.l (a0)+,d2
        move.l (a1)+,d3
        addq.w #1,d1
        cmp.l d2,d3
        beq.s .find
        subq.w #1,d1
        move.w d1,(a2)+                 ; a run from long D1
        movea.l a2,a3
        clr.w (a2)+
        moveq #0,d4                     ; its longs
        moveq #0,d5                     ; equal ones at its end
.add:   eor.l d2,d3
        move.l d3,(a2)+
        addq.w #1,d4
        addq.w #1,d5
        tst.l d3
        beq.s .next
        moveq #0,d5
.next:  addq.w #1,d1
        cmp.w #RECORD_LONGS,d1
        bhs.s .close
        cmp.w #RUN_GAP,d5
        bhs.s .close
        move.l (a0)+,d2
        move.l (a1)+,d3
        bra.s .add
.close: sub.w d5,d4                     ; without the equal ones at its end
        move.w d4,(a3)
        add.w d5,d5
        add.w d5,d5
        suba.w d5,a2
        bra.s .find
.end:   move.l #$ffff0000,(a2)+
        rts

; D0 a step: XORed into edit_record and undo_base.
step_apply:
        bsr step_address
.run:   move.w (a2)+,d1
        cmp.w #$ffff,d1
        beq.s .done
        move.w (a2)+,d2
        lsl.w #2,d1
        lea edit_record,a0
        adda.w d1,a0
        lea undo_base,a1
        adda.w d1,a1
        subq.w #1,d2
.long:  move.l (a2)+,d3
        eor.l d3,(a0)+
        eor.l d3,(a1)+
        dbra d2,.long
        bra.s .run
.done:  rts

; The U key: Shift+U redoes. Not while the mouse button is held in the map
; (a stroke or a drag).
undo_key:
        tst.b G_LEFT_DOWN(a5)
        bne undo_done
        cmp.w #'U',key_char
        beq.s redo
        ; fall through

undo:
        bsr undo_flush
        move.w hist_pos,d0
        beq undo_done
        subq.w #1,d0
        move.w d0,hist_pos
        bsr step_apply
        lea s_undone(pc),a0
        bra.s history_shown

redo:
        bsr undo_flush
        move.w hist_pos,d0
        cmp.w step_count,d0
        bhs undo_done
        bsr step_apply
        addq.w #1,hist_pos
        lea s_redone(pc),a0
        ; fall through

; A0 a message: the record after an undo or redo is shown.
history_shown:
        move.l a0,-(sp)
        bsr dirty_from_saved
        bsr objects_apply               ; the play map and the objects
        bsr level_shown                 ; the header, counts, clock, panel
        st fields_changed
        movea.l (sp)+,a0
        moveq #UI_INK,d0
        bra set_message

; D0 Undo or Redo -> D5 ST_DISABLED when there is nothing to undo or redo,
; else unchanged.
undo_state:
        cmp.w #ID_UNDO,d0
        bne.s .redo
        tst.b touched                   ; a change still to become a step
        bne.s .out
        tst.w hist_pos
        bne.s .out
        bra.s .disabled
.redo:  tst.b touched
        bne.s .disabled
        move.w hist_pos,d1
        cmp.w step_count,d1
        blo.s .out
.disabled:
        moveq #ST_DISABLED,d5
.out:   rts

;============================================================================
; Test play

; The Test button: test play at the end of the pass (edit_loop); when the
; level has a warning, the bar asks first.
test_ask:
        bsr first_warning               ; -> A0 its text, Z set when none
        beq.s test_go
        move.l a0,-(sp)
        move.b #QUESTION_TEST,question_kind
        lea test_question_widgets(pc),a0
        bsr question_open
        lea question_text,a3
        lea s_warning(pc),a0
        bsr put_str
        movea.l (sp)+,a0
        bsr put_str
        lea s_test_anyway(pc),a0
        bra put_str

; Test play, from the question too.
test_go:
        cmp.b #PAGE_QUESTION,edit_page
        bne.s .wanted
        bsr close_question
.wanted:
        st test_wanted
        rts

; Jumped to from edit_loop at the end of a pass: the edit view is left as
; the list's Menu leaves it, and the record played.
test_flow:
        sf test_wanted
        move.w G_SCROLL_X(a5),resume_x
        move.w G_SCROLL_Y(a5),resume_y
        bsr view_fade_out
        bsr bar_hide
        move.l g_idle,G_CALLBACK(a5)
        GCALL music_off
        move.w #MENU_MAX_Y,G_CURSOR_MAX_Y(a5)
        clr.b screen
        sf editing
        st testing
        ; fall through

; The record being edited played through the custom play path.
test_play:
        lea edit_record,a0
        lea record_buffer,a1
        bsr copy_record
        bsr pointer_busy
        lea edit_record+R_STYLE,a0
        bsr get_le
        move.w d1,d0
        bsr enter_level
        GJUMP build

; From hook_play_end after test play, D0 the result page's choice: Replay,
; Edit (the edit view again, as it was), or Levels (the list, after the
; editor's question when there are unsaved changes).
test_result:
        tst.w d0
        beq.s test_play
        sf testing
        cmp.w #RESULT_EDIT,d0
        beq.s .edit
        tst.b dirty
        beq list_flow
        st ask_on_entry
.edit:  st editing
        bra edit_rebuild

; Jumped to from P_ESCAPE: Esc in play (HandlePlayKeys $B4A, its return
; into the play loop on the stack). Esc counts once the level has run eight
; passes. Play starts the level again ($BE6); test play goes back to the
; editor as the result page's Edit does, after the same teardown (the
; colours faded, the frame callback idle, the music off, the return
; dropped), but to black, as the level's end fades ($30C).
hook_escape:
        tst.b testing
        bne.s .test
        move.l r_escape_test,-(sp)      ; the original's test, then its ble.w
        move.l G_LEVEL_PASSES(a5),d0
        cmp.l #8,d0
        rts
.test:  move.l G_LEVEL_PASSES(a5),d0
        cmp.l #8,d0
        ble.s .early
        movea.l pal_black,a0
        movea.l hunk1,a1
        lea COP_PLAY_COLOURS(a1),a1
        GCALL fade
        move.l g_idle,G_CALLBACK(a5)
        GCALL music_off
        addq.l #4,sp
        moveq #RESULT_EDIT,d0
        bra test_result
.early: rts

test_question_widgets:
        WIDGET 4,ROW_A,312,ID_QUESTION,0,0
        WIDGET 88,ROW_B,34,ID_Q_TEST,s_test,h_q_test
        WIDGET 128,ROW_B,46,ID_Q_CANCEL,s_cancel,h_cancel
        dc.w -1

h_test:         dc.b "Play the level as it is now (E)",0
h_undo:         dc.b "Undo the last change (U)",0
h_redo:         dc.b "Redo the change undone (Shift+U)",0
h_q_test:       dc.b "Test play it all the same (Return)",0
s_test_anyway:  dc.b ". Test?",0
s_test_help:    dc.b "Return: test    Esc: keep editing",0
s_undone:       dc.b "Undone",0
s_redone:       dc.b "Redone",0
                even

;============================================================================

        section editor_bss,bss

undo_base:      ds.b RECORD_SIZE        ; the state at hist_pos
saved_copy:     ds.b RECORD_SIZE        ; the record as in its file
step_start:     ds.l UNDO_STEPS+1       ; offsets of the steps, and their end
step_data:      ds.b STEP_SPACE
