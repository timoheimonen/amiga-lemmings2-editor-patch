; Lemmings 2: The Tribes In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; Deleting and renaming level files, from the list of custom levels in
; editor.s, which calls delete_page and rename_page. The pages use menu.s
; for their buttons and help line; the list's scan asks name_deleted which
; names to leave out.
;
; Delete asks first, naming the file and its title (or that it is damaged),
; then removes it with resload_DeleteFile. Rename types a new name on a page
; like New, with its rules; a name another file has is refused. WHDLoad has
; no call to rename a file, so the file is copied under the new name and
; then deleted; a damaged file is copied as it is, up to the size of the
; copy buffer. The undo history's room serves as that buffer: no level is
; open while the list is shown.
;
; Whether a file is gone is checked with resload_GetFileSize, since WHDLoad
; returns without deleting from a read-only file system. With WHDLoad's
; write cache (without NOWRITECACHE) a deleted file stays on the disk until
; WHDLoad quits, and resload_ListFiles goes on listing it, while
; resload_GetFileSize finds no such file at once. So the list leaves out a
; name deleted in this session that resload_GetFileSize does not find.
;
; Part of the editor's single assembly unit, included by editor.s. A5 is
; the game's globals.

DELETED_MAX     equ 128         ; names deleted in this session
DELETED_SIZE    equ NAME_MAX+1
FILE_BUFFER_SIZE equ STEP_SPACE
file_buffer     equ step_data   ; while the list is shown
FILE_LINE_1     equ $30         ; the name
FILE_VALUE_W    equ 320-NEW_VALUE_X-2   ; its room: a name of 31 characters may not fit
FILE_LINE_2     equ $40         ; the title
FILE_LINE_3     equ $60         ; Delete's warning
RENAME_Y        equ $58         ; the new name
SCREEN_DELETE   equ 6
SCREEN_RENAME   equ 7

        section editor,code

;----------------------------------------------------------------------------
; Delete

; The Delete page for the selected file. -> A0 a message for the list, or 0.
delete_page:
        GCALL show_menu
        bsr txt_start
        lea s_delete_title(pc),a0
        move.w #TITLE_Y,d1
        bsr txt_centred_line
        bsr file_lines
        lea s_delete_warning(pc),a0
        move.w #FILE_LINE_3,d1
        bsr txt_centred_line
        bsr txt_draw
        lea delete_buttons(pc),a0
        lea s_delete_help(pc),a1
        moveq #0,d0
        bsr menu_page
.wait:  move.b #SCREEN_DELETE,screen
        bsr menu_input
        cmp.w #MENU_RIGHT,d0
        beq.s .keep
        tst.w d0
        bmi.s .wait
        beq.s .delete
.keep:  clr.b screen
        suba.l a0,a0
        rts
.delete:
        clr.b screen
        bsr pointer_busy
        bsr selected_path
        bsr remove_file
        lea s_not_deleted(pc),a0
        tst.w d0
        bmi.s .listed
        lea message_build,a3
        lea s_deleted_file(pc),a0
        bsr put_str
        lea path+LEVELS_PREFIX,a0
        bsr put_str
        clr.b (a3)
        lea message_build,a0
.listed:
        move.l a0,-(sp)
        bsr scan_levels
        bsr pointer_normal
        movea.l (sp)+,a0
        rts

; The selected entry's name and title, or that it is damaged, as two lines
; of labels and values (the New page's columns) into the stream at A3.
file_lines:
        lea s_name_label(pc),a0
        move.w #FILE_LINE_1,d1
        bsr new_label
        lea s_title_label(pc),a0
        move.w #FILE_LINE_2,d1
        bsr new_label
        move.w #FILE_LINE_1,d1
        bsr new_value
        move.w selected,d0
        bsr entry_at
        lea E_NAME(a2),a0
        moveq #NAME_MAX,d2
        move.w #FILE_VALUE_W,d3
        bsr txt_fit
        move.w #FILE_LINE_2,d1
        bsr new_value
        lea s_damaged_file(pc),a0
        tst.b E_OK(a2)
        beq txt_str
        lea E_TITLE(a2),a0
        moveq #TITLE_SIZE,d2
        move.w #FILE_VALUE_W,d3
        bra txt_fit

; path: the file deleted, its name kept for the list. D0 = 0, or -1 when it
; is still there.
remove_file:
        movem.l d1-d7/a1-a6,-(sp)
        movea.l resload_base,a2
        lea path,a0
        jsr resload_DeleteFile(a2)
        bsr keys_cleared
        lea path,a0
        jsr resload_GetFileSize(a2)
        tst.l d0
        bne.s .kept
        lea deleted_names,a3            ; a name kept already: not again (a
        move.w deleted_count,d7         ; file renamed back and forth)
        bra.s .test
.known: lea path+LEVELS_PREFIX,a0
        movea.l a3,a1
        bsr compare_names
        tst.w d0
        beq.s .done
        lea DELETED_SIZE(a3),a3
.test:  dbra d7,.known
        cmp.w #DELETED_MAX,deleted_count
        bhs.s .done                     ; listed as damaged until WHDLoad quits
        movea.l a3,a1                   ; the first free place
        lea path+LEVELS_PREFIX,a0
.copy:  move.b (a0)+,(a1)+
        bne.s .copy
        addq.w #1,deleted_count
.done:  moveq #0,d0
        bra.s .out
.kept:  moveq #-1,d0
.out:   movem.l (sp)+,d1-d7/a1-a6
        rts

; A4 a listed name -> Z clear when the list leaves it out: deleted in this
; session and not there (WHDLoad's write cache). Changes D0/D1/A0/A1.
name_deleted:
        move.w deleted_count,d1
        beq.s .listed
        lea deleted_names,a1
        subq.w #1,d1
.name:  movea.l a4,a0
        movem.l d1/a1,-(sp)
        bsr compare_names
        movem.l (sp)+,d1/a1
        tst.w d0
        beq.s .deleted
        lea DELETED_SIZE(a1),a1
        dbra d1,.name
.listed:
        cmp.b d0,d0                     ; Z set
        rts
.deleted:
        movea.l a4,a0
        lea path,a1
        bsr levels_path
        movem.l a2,-(sp)
        movea.l resload_base,a2
        lea path,a0
        jsr resload_GetFileSize(a2)
        movem.l (sp)+,a2
        tst.l d0
        seq d0                          ; no such file: Z clear
        tst.b d0
        rts

;----------------------------------------------------------------------------
; Rename

; The Rename page for the selected file: the new name is typed as on the
; New page, starting from the old one when it keeps the page's rules.
; -> A0 a message for the list, or 0.
rename_page:
        move.w selected,d0
        bsr entry_at
        lea E_NAME(a2),a1
        lea new_name,a2
        moveq #0,d1
.old:   move.b (a1)+,d0
        cmp.b #'.',d0
        bne.s .char
        tst.b 3(a1)                     ; ".lvl" ends the name
        beq.s .kept
.char:  bsr name_char
        bne.s .none
        cmp.w #NEW_NAME_MAX,d1
        bhs.s .none
        move.b d0,(a2)+
        addq.w #1,d1
        bra.s .old
.none:  moveq #0,d1
.kept:  move.b d1,new_length
        clr.l new_message
        GCALL show_menu
        bsr txt_start
        lea s_rename_title(pc),a0
        move.w #TITLE_Y,d1
        bsr txt_centred_line
        bsr file_lines
        lea s_new_name_label(pc),a0
        move.w #RENAME_Y,d1
        bsr new_label
        bsr txt_draw
        bsr rename_fields
        lea rename_buttons(pc),a0
        lea s_rename_help(pc),a1
        moveq #0,d0
        bsr menu_page
.wait:  move.b #SCREEN_RENAME,screen
        bsr menu_input
        cmp.w #MENU_RIGHT,d0
        beq.s .cancel
        cmp.w #MENU_KEY,d0
        bne.s .button
        move.w d1,d0
        bsr name_key
        beq.s .wait
        clr.l new_message
        bsr rename_fields
        bra.s .wait
.button:
        tst.w d0
        bmi.s .wait
        bne.s .cancel
        bsr rename_file
        tst.w d0
        bpl.s .done
        bsr rename_fields
        bra.s .wait
.cancel:
        suba.l a0,a0
.done:  clr.b screen
        rts

; The new name and a message, on fresh background.
rename_fields:
        move.w #NEW_VALUE_X,d0
        move.w #RENAME_Y,d1
        move.w #320-NEW_VALUE_X,d2
        moveq #NEW_ROW_H,d3
        GCALL restore_rect
        moveq #0,d0
        move.w #NEW_MESSAGE_Y,d1
        move.w #320,d2
        moveq #NEW_ROW_H,d3
        GCALL restore_rect
        bsr txt_start
        move.w #RENAME_Y,d1
        bsr name_value
        bra new_message_line

; The selected file under the typed name: written as Levels/<name>.lvl,
; checked, then the old file deleted and the list read again with the new
; one selected. D0 = 0 with A0 a message for the list, or -1 with the
; reason in new_message.
rename_file:
        lea s_need_name(pc),a0
        tst.b new_length
        beq .refuse
        bsr name_file
        move.w selected,d0
        bsr entry_at
        lea E_NAME(a2),a0
        lea new_file,a1
        bsr compare_names
        lea s_same_name(pc),a0
        tst.w d0
        beq .refuse                     ; the same, in any case
        bsr new_entry
        lea s_name_exists(pc),a0
        cmp.w entry_count,d7
        blo .refuse
        lea new_file,a0                 ; a file the list does not show
        lea path,a1
        bsr levels_path
        movea.l resload_base,a2
        lea path,a0
        jsr resload_GetFileSize(a2)
        lea s_name_exists(pc),a0
        tst.l d0
        bne .refuse
        bsr selected_path
        lea path,a0
        lea old_path,a1
.old:   move.b (a0)+,(a1)+
        bne.s .old
        movea.l resload_base,a2
        lea old_path,a0
        jsr resload_GetFileSize(a2)
        move.l d0,d7
        lea s_too_large(pc),a0
        cmp.l #FILE_BUFFER_SIZE,d7
        bhi .refuse
        move.l d7,-(sp)
        bsr pointer_busy                ; calls a game routine
        move.l (sp)+,d7
        movea.l resload_base,a2
        tst.l d7
        beq.s .write
        lea old_path,a0
        lea file_buffer,a1
        jsr resload_LoadFile(a2)
.write: lea new_file,a0
        lea path,a1
        bsr levels_path
        move.l d7,d0
        lea path,a0
        lea file_buffer,a1
        jsr resload_SaveFile(a2)
        bsr keys_cleared
        lea path,a0
        jsr resload_GetFileSize(a2)
        cmp.l d7,d0
        bne.s .not_written
        lea old_path,a0
        lea path,a1
.back:  move.b (a0)+,(a1)+
        bne.s .back
        bsr remove_file
        lea s_old_kept(pc),a0
        tst.w d0
        bmi.s .listed
        lea message_build,a3
        lea s_renamed(pc),a0
        bsr put_str
        lea new_file,a0
        bsr put_str
        clr.b (a3)
        lea message_build,a0
.listed:
        move.l a0,-(sp)
        bsr scan_levels
        bsr new_entry
        bsr select_entry
        bsr pointer_normal
        movea.l (sp)+,a0
        moveq #0,d0
        rts
.not_written:
        bsr pointer_normal
        lea s_not_written(pc),a0
.refuse:
        move.l a0,new_message
        moveq #-1,d0
        rts

;----------------------------------------------------------------------------

; path = the selected entry's file.
selected_path:
        move.w selected,d0
        bsr entry_at
        bra make_path

; A0 a file name -> A1 "Levels/" and the name.
levels_path:
        move.l a0,-(sp)
        lea s_levels_dir(pc),a0
.dir:   move.b (a0)+,(a1)+
        bne.s .dir
        move.b #'/',-1(a1)
        movea.l (sp)+,a0
.name:  move.b (a0)+,(a1)+
        bne.s .name
        rts

; D7 an entry, or entry_count: it is selected, its page shown.
select_entry:
        cmp.w entry_count,d7
        blo.s .entry
        move.w entry_count,d7
        subq.w #1,d7
.entry: move.w d7,selected
        bmi.s .none
        moveq #0,d0
        move.w d7,d0
        divu #ROWS,d0
        move.w d0,current_page
.none:  rts

; After a resload call: the system took the keyboard, so the release of a
; key never reached the game, whose key repeat would go on. Clear the
; game's modifiers and new key, as save_level does after saving.
keys_cleared:
        clr.l G_MODIFIERS(a5)
        clr.w G_KEY_NEW(a5)
        rts

delete_buttons:
        MBUTTON MB_COLUMN_1,MB_ROW_2,KEY_RETURN,s_delete,h_delete_file
        MBUTTON MB_COLUMN_3,MB_ROW_2,KEY_ESC,s_cancel_label,h_keep_file
        dc.w -1
rename_buttons:
        MBUTTON MB_COLUMN_1,MB_ROW_2,KEY_RETURN,s_rename_label,h_rename_file
        MBUTTON MB_COLUMN_3,MB_ROW_2,KEY_ESC,s_cancel_label,h_keep_name
        dc.w -1

s_delete_title:   dc.b "Delete Level",0
s_rename_title:   dc.b "Rename Level",0
s_rename_label:   dc.b "Rename",0
s_title_label:    dc.b "Title",0
s_new_name_label: dc.b "New",0
s_damaged_file:   dc.b "damaged",0
s_delete_warning: dc.b "Deleting cannot be undone.",0
s_delete_help:    dc.b "Return: delete    Esc: keep",0
s_rename_help:    dc.b "Type the new name of the file",0
h_delete_file:    dc.b "Delete the file for good (Return)",0
h_keep_file:      dc.b "Keep the file (Esc)",0
h_rename_file:    dc.b "Give the file this name (Return)",0
h_keep_name:      dc.b "Keep the old name (Esc)",0
s_deleted_file:   dc.b "Deleted ",0
s_not_deleted:    dc.b "The file could not be deleted",0
s_renamed:        dc.b "Renamed to ",0
s_same_name:      dc.b "The file has this name already",0
s_too_large:      dc.b "This file is too large to rename here",0
s_not_written:    dc.b "The new file could not be written",0
s_old_kept:       dc.b "Copied, but the old file is still there",0
                  even

;============================================================================

        section editor_bss,bss

deleted_count:  ds.w 1
old_path:       ds.b 64
message_build:  ds.b 64
deleted_names:  ds.b DELETED_MAX*DELETED_SIZE
