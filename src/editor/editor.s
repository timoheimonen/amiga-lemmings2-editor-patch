; Lemmings 2: The Tribes In-Game Level Editor V1.2
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; The editor's main file. The editor puts an EDIT button on the game's
; title screen, over the QUIT button, which the game crosses out when there
; is no operating system to quit to (the PAL release always does). EDIT opens the list of the custom
; levels in the install's Levels directory, where a level is played,
; edited, made (the New page), renamed or deleted. A custom level plays in
; its own style with 60 lemmings and its own skills and clock, and ends in
; the editor's result page instead of the game's, which would change the
; tribes' progress.
;
; This file holds init and its patch points, the hooks into the game (the
; title, custom play and the end of play), the custom-level list, the
; result page, the New page and the text drawing through the game's text
; routine. It is assembled as one unit with the files it includes:
;   font.i     the editor's 5x7 font
;   bar.s      the editor bar below the play view and its drawing routines
;   edit.s     the edit view: scrolling, the Terrain mode and saving
;   objects.s  the Objects mode: the level's object placements
;   level.s    the Param mode: the level's parameters and the skill picker
;   undo.s     undo and redo, and test play
;   menu.s     the buttons and the help line of the menu-screen pages
;   files.s    deleting and renaming level files
; and, shared with the WHDLoad slave, whdload_api.i (the resload interface)
; and version.i (the editor's version).
;
; The WHDLoad slave loads this file (data/Editor) into ExpMem, relocates it
; and calls its first instruction once, before the game starts:
;   A0 = the slave's interface table: the resload base, hunks 0 to 3, then
;        the address and size of the editor's chip memory in BaseMem
;   returns D0 = 0, or a pointer to an error message for the slave to show.
; Init checks the original bytes at the editor's patch points and patches
; them; another version of the game is refused. Everything else runs from
; those hooks inside the game, with the game's A5 (its globals) and A6
; ($dff000), which the editor never changes. Game routines may change every
; other register; resload functions change D0/D1/A0/A1.
;
; The first instruction is followed by "L2ED" and the addresses of the
; editor's state block and main tables: a fixed header that external tools
; can find and read from memory. The state block's fields keep the offsets
; given at its definition.
;
; Game addresses are offsets in the game's hunk 0 unless another hunk is
; named; init adds the load address of the hunk, from the interface table
; (SETADDR). Hunk 3 holds the record of the selected level. The editor is
; assembled for one release of the game (release.i); GAME gives an address
; in the US release and in the PAL release. Addresses in the comments are
; the US release's.

        include "whdload_api.i"
        include "version.i"             ; EDITOR_VERSION
        include "release.i"             ; GAME

; Game routines, hunk 0
        GAME G_SOUND,$00602,$005fa              ; play the effect A5+$15c
        GAME G_STOP_SOUND,$165dc,$16310         ; what the title does before leaving
        GAME G_POINTER,$01712,$016f2            ; show the pointer sprite A5+$21e, height A5+$186
        GAME G_WAIT_PRESS,$0150e,$014ee         ; wait for the left mouse button
        GAME G_INIT_PLAY,$0151a,$014fa          ; entities, skills and clock from the header
        GAME G_LOAD_STYLE,$018ce,$018ae         ; style, tune and tribe art of tribe A5+$14c
        GAME G_SELECT_LEVEL,$019ae,$0198e       ; select level D0 and parse it
        GAME G_COUNT,$019e8,$019e0              ; lemming count of the selected level
        ifnd PAL_RELEASE
G_PROTECTION    equ $01b6e      ; the protection gate the title's buttons call
        endif
        GAME G_COPPER,$00fc8,$00fb8             ; show display D0
        GAME G_FADE,$0e5d8,$0e342               ; fade the copper colours from A1 to palette A0
        GAME G_UNPACK_MENU,$0e272,$0dfdc        ; unpack the menu background
        GAME G_SHOW_MENU,$0e286,$0dff0          ; copy it to the menu screen
        GAME G_RESTORE_RECT,$0e2aa,$0e014       ; D0 x, D1 y, D2 width, D3 height: background back
        GAME G_TEXT,$0f356,$0f0c0               ; draw the text stream A0
        GAME FONT_WIDTHS,$0f7ea,$0f554          ; the menu font's widths, ' ' to 'z' (data)
        GAME G_SPRITE,$10abc,$10826             ; draw a sprite

; Where the editor continues in the game, hunk 0
        GAME R_TITLE,$00080,$00078              ; show the title (as after play)
        GAME R_BUILD,$000b2,$000aa              ; build the selected level and play it
        GAME R_RESULT,$0033e,$00336             ; the game's own end of play
        GAME R_ESCAPE_TEST,$00be2,$00bda        ; Esc's ble.w: the level again after eight passes
        GAME R_AFTER_TAB,$00bb6,$00bae          ; the play keys after the Tab test
        GAME R_RELEASE,$09ade,$09876            ; the release countdown in ReleaseL2Lemming
        GAME R_OPENING,$001f2,$001ea            ; the entrances' next frame
        GAME R_OPENED,$0022e,$00226             ; past them
        GAME R_CROSSES_DONE,$0d91e,$0d6a4       ; after the title's QUIT crosses
        GAME R_TITLE_AGAIN,$0da68,$0d7e4        ; show the title again and wait (as after LOAD)
        ifd PAL_RELEASE
R_NEXT_COLUMN   equ $0d74c      ; the title's click test after the QUIT column
QUIT_RIGHT      equ $44         ; the QUIT column: x below this
        endif

; Patch points, hunk 0, with their original bytes in the check table
        GAME P_CROSSES,$0d8e4,$0d672            ; tst.l ($4).w / bne.w R_CROSSES_DONE
                                                ; (PAL: the crosses' first two instructions)
        GAME P_QUIT,$0dae8,$0d746               ; tst.l ($4).w / beq.w (title loop)
                                                ; (PAL: cmp.w #QUIT_RIGHT,d0 / blt.b (title loop))
        GAME P_COUNT,$019d4,$019cc              ; bsr.w G_COUNT / move.w d0,$124(a5)
        GAME P_PLAY_END,$00336,$0032e           ; tst.b $1e7(a5) / bne.w R_TITLE
        GAME P_ESCAPE,$00bd8,$00bd0             ; move.l $25e(a5),d0 / cmp.l #8,d0: Esc in play
        GAME P_TAB,$00bae,$00ba6                ; cmp.b #9,d0 / beq.w G_VIDEO: Tab in play
        GAME P_RELEASE,$09ad6,$0986e            ; tst.b $1de(a5) / bne.w (rts): a lemming out
        GAME P_OPENING,$001ea,$001e2            ; tst.b $1e6(a5) / beq.w: the entrances opening

; Data, hunk 0
        GAME HEADER,$18d16,$189de               ; the parsed header of the selected level
H_THRESHOLD     equ $4a         ; result threshold
        GAME STYLE_NAMES,$1c3e4,$1c0ac          ; twelve names of eight characters
        GAME DESCRIPTOR_6,$1c0ac,$1bd74         ; display descriptor of the title screen
        GAME DESCRIPTOR_7_ENTRY,$1c0c0,$1bd88   ; and of the menu screen
D_BITMAP        equ 16          ; its bitmap pointer

; Hunk 1
PAL_BLACK       equ $00904      ; 32 black colours
PAL_MENU        equ $00a04      ; the menu screen's palette (result screen)
COP_TITLE       equ $00220      ; colour moves of the title display
COP_MENU        equ $004a4      ; colour moves of the menu display
PTR_NORMAL      equ $04c2c      ; pointer sprites
PTR_BUSY        equ $04c88

; Hunk 2
TITLE_BITMAP    equ $446c0      ; title screen: 320x200, five planes
MENU_BITMAP     equ $0f400      ; menu screen, the same
PLANE           equ 8000

; Game globals (A5)
G_CURSOR_X      equ $106
G_CURSOR_Y      equ $108
G_INDEX         equ $120        ; selected level of the tribe
G_LEMMINGS      equ $124        ; lemmings of this level
G_SAVED         equ $12c
G_TRIBE         equ $14c
G_EFFECT        equ $15c
G_POINTER_H     equ $186
G_PRACTICE      equ $1e7
G_ENTRANCES     equ $194        ; entrances in the level's entrance table
G_RELEASE_HOLD  equ $1de        ; ReleaseL2Lemming releases nothing while set
G_OPENING       equ $1e6        ; the entrances are opening
        GAME G_POINTER_DATA,$21e,$21c
        GAME G_MENU_ART,$24a,$248               ; sprites of the menu screens

; The level record (the FORM/L2LV file)
RECORD_SIZE     equ $21c8
HEAD_SIZE       equ $74         ; up to the L2MP chunk's size
MAP_BYTES       equ 1971*4      ; the L2MP chunk's size
OBJECTS_BYTES   equ 64*10       ; the L2BO chunk's
R_TITLE_TEXT    equ $14         ; 24 characters
R_MINUTES       equ $44
R_SECONDS       equ $46
R_STYLE         equ $66         ; LE16
R_SHAPE         equ $68         ; LE16
STYLES          equ 12
SHAPES          equ 7
CUSTOM_COUNT    equ 60          ; the game's count without progress
SKILL_ID_MAX    equ 51          ; Blocker, in the Classic levels
PLACE_SLACK     equ 512         ; pixels an origin may lie outside the map

; The custom-level list
MAX_LEVELS      equ 512
NAME_MAX        equ 31
NAMES_SIZE      equ 16384       ; MAX_LEVELS names of NAME_MAX characters
ENTRY_SIZE      equ 64
E_NAME          equ 0           ; 32 bytes, zero-terminated
E_TITLE         equ 32          ; 24 bytes
E_STYLE         equ 56
E_MINUTES       equ 58
E_SECONDS       equ 59
E_OK            equ 60          ; a valid record

; The menu screen and its layout (descriptor 7, as LOAD and the results)
MENU            equ 7
COLOR00         equ $180
COLOR31         equ $1be
POINTER_HEIGHT  equ $15
CLICK_EFFECT    equ $34
ROWS            equ 9
ROW_Y           equ $14
ROW_H           equ 12
PAGE_Y          equ ROW_Y+ROWS*ROW_H
EMPTY_Y         equ $34
TITLE_Y         equ 0
HELP_Y          equ $b8
COLUMN_TITLE    equ 8
COLUMN_TIME     equ 204
COLUMN_STYLE    equ 244
COLUMN_NEXT     equ 248
COLUMN_GAP      equ 4           ; pixels kept free before the next column
RESULT_TITLE_Y  equ $1c
RESULT_SAVED_Y  equ $40
RESULT_GRADE_Y  equ $56
RESULT_HINT_Y   equ $66
SCREEN_LIST     equ 1           ; state: the page shown
SCREEN_RESULT   equ 2
SCREEN_EDIT     equ 3           ; the edit view runs
SCREEN_NEW      equ 4           ; the New page waits for a name
SCREEN_PICKER   equ 5           ; the skill picker runs
                                ; 6 Delete, 7 Rename (files.s)
LIST_PLAY       equ 1           ; what the list and the result page return
LIST_EDIT       equ 2
RESULT_EDIT     equ 2
BAR_EFFECT      equ 5           ; the panel's click
LEVELS_PREFIX   equ 7           ; "Levels/"

; The New page
NEW_NAME_MAX    equ 20          ; characters of a file name, before ".lvl"
NEW_LABEL_X     equ 40
NEW_VALUE_X     equ 112         ; a multiple of 16: G_RESTORE_RECT copies words
NEW_CREDIT_Y    equ $12         ; the editor's name and version, below the title
NEW_NAME_Y      equ $30
NEW_STYLE_Y     equ $48
NEW_SHAPE_Y     equ $5c
NEW_ROW_H       equ 12
NEW_MESSAGE_Y   equ $74
NEW_MIDDLE      equ 176         ; a click left of it: the previous style or size
NEW_STYLE       equ 1           ; Beach, until another is chosen
NEW_SHAPE       equ 3           ; 42x44 cells, the shipped levels' usual
NEW_MINUTES     equ 5

; The editor's chip memory
CHIP_BAR_COPPER equ 0
CHIP_BAR        equ $100        ; the bar's bitmap
CHIP_NEEDED     equ CHIP_BAR+BAR_PLANES*BAR_PLANE

; The EDIT label: the title's own letters, e, i and t from EXIT and d from
; LOAD, over the crossed-out button
LETTERS         equ 4
LETTER_Y        equ 181
LETTER_ROWS     equ 12
LABEL_LEFT      equ 4
LABEL_RIGHT     equ 66
LABEL_TOP       equ 178
LABEL_BOTTOM    equ 195
BUTTON_COLOUR   equ 29

GCALL   macro                   ; call the game routine g_\1
        movea.l g_\1,a4
        jsr (a4)
        endm

GJUMP   macro                   ; continue in the game at r_\1, registers kept
        move.l r_\1,-(sp)
        rts
        endm

SETADDR macro                   ; \1 = the address of offset \3 in hunk \2
        move.l \2,d0
        add.l #\3,d0
        move.l d0,\1
        endm

MBUTTON macro                   ; a button of a menu page (menu.s): x, y,
        dc.w \1,\2,MB_WIDTH,\3       ; key, label, help
        dc.l \4,\5
        endm

PATCH   macro                   ; \2 abs.l (jmp or jsr) \3 at hunk 0 + \1, nop
        movea.l hunk0,a1
        adda.l #\1,a1
        move.w #\2,(a1)+
        move.l #\3,(a1)+
        move.w #$4e71,(a1)
        endm

;============================================================================

        section editor,code

start:  bra.w init
        dc.b "L2ED"                     ; a fixed header for external tools:
        dc.l state                      ; the state block,
        dc.l entries                    ; the list's entries,
        dc.l edit_record                ; the record being edited,
        dc.l types                      ; the object types and their page,
        dc.l page_row_y                 ; the page's rows,
        dc.l order                      ; the listed names in order,
        dc.l names                      ; and the names

; Original bytes: hunk 0 offset, long word.
        ifnd PAL_RELEASE
checks: dc.l P_CROSSES,$4ab80004,P_CROSSES+4,$66000034
        dc.l P_QUIT,$4ab80004,P_QUIT+4,$6700fe7a
        dc.l P_COUNT,$61000012,P_COUNT+4,$3b400124
        dc.l P_PLAY_END,$4a2d01e7,P_PLAY_END+4,$6600fd44
        dc.l P_ESCAPE,$202d025e,P_ESCAPE+4,$b0bc0000
        dc.l P_TAB,$b03c0009,P_TAB+4,$67000102
        dc.l P_RELEASE,$4a2d01de,P_RELEASE+4,$66004aac
        dc.l P_OPENING,$4a2d01e6,P_OPENING+4,$6700003e
        else
checks: dc.l P_CROSSES,$206d0248        ; movea.l $248(a5),a0
        dc.l P_CROSSES+4,$303c0004      ; move.w #4,d0
        dc.l P_QUIT,$b07c0044           ; cmp.w #QUIT_RIGHT,d0
        dc.l P_QUIT+4,$6d9ab07c         ; blt.b (title loop) / cmp.w (next)
        dc.l P_COUNT,$61000012,P_COUNT+4,$3b400124
        dc.l P_PLAY_END,$4a2d01e7,P_PLAY_END+4,$6600fd44
        dc.l P_ESCAPE,$202d025c,P_ESCAPE+4,$b0bc0000
        dc.l P_TAB,$b03c0009,P_TAB+4,$67000102
        dc.l P_RELEASE,$4a2d01de,P_RELEASE+4,$66004a7e
        dc.l P_OPENING,$4a2d01e6,P_OPENING+4,$6700003e
        endif
        dc.l FONT_WIDTHS,$06050808      ; ' ', '!', '"' and '#'
        dc.l G_TEXT,$48e7e0fe           ; movem.l d0-d2/a0-a6,-(sp)
        dc.l G_PICKER,$426d014e,G_PICKER+4,$43ed01a0
        dc.l P_PICKER_ICON,PICKER_ICON_BSR      ; bsr.w G_SPRITE
        dc.l P_PICKER_ICON+4,$06400020  ; addi.w #32,d0
        dc.l P_PICKER_PICK,$52402f00    ; addq.w #1,d0 / move.l d0,-(sp)
        dc.l P_PICKER_PICK+4,$43ed01a0  ; lea $1a0(a5),a1
        dc.l P_PICKER_NAME-2,$d0415240  ; add.w d1,d0 / addq.w #1,d0
        dc.l G_PANEL,$6100028c          ; bsr.w $fad8
        dc.l G_PANEL_SLOT,$2f003200     ; move.l d0,-(sp) / move.w d0,d1
        dc.l G_PANEL_COUNT,$48e700f0    ; movem.l a0-a3,-(sp)
        dc.l G_CLOCK,$4a2d01db          ; tst.b $1db(a5)
        dc.l G_FRAME_END,$422d01c4      ; clr.b $1c4(a5)
        ifnd PAL_RELEASE
        dc.l P_FRAME,$6100125a,P_FRAME+4,$61002248
        else
        dc.l P_FRAME,$61001242,P_FRAME+4,$6100221c
        endif
        dc.l P_SPRITE_POS,$70000642,P_SPRITE_POS+4,$002ce14a
        dc.l -1

; Instructions with an absolute address, which the game's relocation set:
; hunk 0 offset, the opcode word and the hunk 0 offset it addresses. Patched
; only while the editor calls the Practice picker (level.s).
relocated_checks:
        dc.l P_PICKER_FRAME
        dc.w $4eb9                      ; jsr WaitFrame.l
        dc.l G_WAIT_FRAME
        dc.l P_PICKER_DONE
        dc.w $2079                      ; movea.l (descriptor 7).l,a0
        dc.l DESCRIPTOR_7
        dc.l P_PICKER_PROMPT
        dc.w $41f9                      ; lea (its prompt).l,a0
        dc.l PICKER_PROMPT
        dc.l P_PICKER_NAME+2
        dc.w $41f9                      ; lea (the skill names).l,a0
        dc.l SKILL_NAMES
        dc.l -1

; Hunk 1: the play display's copper list.
copper_checks:
        dc.l COP_DIWSTOP,$0090f4c2      ; move DIWSTOP,$f4c2
        dc.l COP_PLAY_END,$fffffffe
        dc.l -1

; The EDIT label: source x, source y, width, destination x.
letters:
        dc.w 15,181,14,13               ; e
        dc.w 294,147,14,26              ; d
        dc.w 40,181,6,39                ; i
        dc.w 45,181,14,44               ; t

;----------------------------------------------------------------------------
; Called by the slave once: copy the interface, check and patch.

init:
        movem.l d1-d7/a1-a6,-(sp)
        lea interface,a1
        moveq #7-1,d0
.copy:  move.l (a0)+,(a1)+
        dbra d0,.copy
        cmp.l #CHIP_NEEDED,chip_size
        blo .no_chip

        movea.l hunk0,a3
        lea checks(pc),a0
.check: move.l (a0)+,d0
        bmi.s .checked
        move.l (a0)+,d1
        cmp.l 0(a3,d0.l),d1
        bne .wrong
        bra.s .check
.checked:
        movea.l hunk1,a3
        lea copper_checks(pc),a0
.copper:
        move.l (a0)+,d0
        bmi.s .copper_checked
        move.l (a0)+,d1
        cmp.l 0(a3,d0.l),d1
        bne .wrong
        bra.s .copper
.copper_checked:
        movea.l hunk0,a3
        lea relocated_checks(pc),a0
.relocated:
        move.l (a0)+,d0
        bmi.s .relocated_checked
        move.w (a0)+,d1
        cmp.w 0(a3,d0.l),d1
        bne .wrong
        move.l (a0)+,d1
        add.l a3,d1
        cmp.l 2(a3,d0.l),d1
        bne .wrong
        bra.s .relocated
.relocated_checked:
        ; The title screen's descriptor must point at its bitmap.
        move.l hunk2,d0
        add.l #TITLE_BITMAP,d0
        movea.l a3,a0
        adda.l #DESCRIPTOR_6+D_BITMAP,a0
        cmp.l (a0),d0
        bne .wrong
        move.l d0,title_bitmap
        move.l hunk2,d0                 ; and the menu screen's
        add.l #MENU_BITMAP,d0
        movea.l a3,a0
        adda.l #DESCRIPTOR_7_ENTRY+D_BITMAP,a0
        cmp.l (a0),d0
        bne .wrong
        move.l d0,menu_bitmap

        SETADDR g_sound,hunk0,G_SOUND
        SETADDR g_stop_sound,hunk0,G_STOP_SOUND
        SETADDR g_pointer,hunk0,G_POINTER
        SETADDR g_wait_press,hunk0,G_WAIT_PRESS
        SETADDR g_init_play,hunk0,G_INIT_PLAY
        SETADDR g_load_style,hunk0,G_LOAD_STYLE
        SETADDR g_select_level,hunk0,G_SELECT_LEVEL
        SETADDR g_count,hunk0,G_COUNT
        ifnd PAL_RELEASE
        SETADDR g_protection,hunk0,G_PROTECTION
        endif
        SETADDR g_copper,hunk0,G_COPPER
        SETADDR g_fade,hunk0,G_FADE
        SETADDR g_unpack_menu,hunk0,G_UNPACK_MENU
        SETADDR g_show_menu,hunk0,G_SHOW_MENU
        SETADDR g_restore_rect,hunk0,G_RESTORE_RECT
        SETADDR g_text,hunk0,G_TEXT
        SETADDR g_sprite,hunk0,G_SPRITE
        SETADDR r_title,hunk0,R_TITLE
        SETADDR r_build,hunk0,R_BUILD
        SETADDR r_result,hunk0,R_RESULT
        SETADDR r_escape_test,hunk0,R_ESCAPE_TEST
        SETADDR r_after_tab,hunk0,R_AFTER_TAB
        SETADDR g_video,hunk0,G_VIDEO
        SETADDR r_release,hunk0,R_RELEASE
        SETADDR r_opening,hunk0,R_OPENING
        SETADDR r_opened,hunk0,R_OPENED
        SETADDR font_widths,hunk0,FONT_WIDTHS
        SETADDR r_crosses_done,hunk0,R_CROSSES_DONE
        SETADDR r_title_again,hunk0,R_TITLE_AGAIN
        ifd PAL_RELEASE
        SETADDR r_next_column,hunk0,R_NEXT_COLUMN
        endif
        SETADDR level_header,hunk0,HEADER
        SETADDR style_table,hunk0,STYLE_NAMES
        SETADDR pal_black,hunk1,PAL_BLACK
        SETADDR pal_menu,hunk1,PAL_MENU
        SETADDR cop_title,hunk1,COP_TITLE
        SETADDR cop_menu,hunk1,COP_MENU
        SETADDR ptr_normal,hunk1,PTR_NORMAL
        SETADDR ptr_busy,hunk1,PTR_BUSY
        SETADDR g_wait_play,hunk0,G_WAIT_PLAY
        SETADDR g_scroll,hunk0,G_SCROLL
        SETADDR g_copy_view,hunk0,G_COPY_VIEW
        SETADDR g_view_desc,hunk0,G_VIEW_DESC
        SETADDR g_objects,hunk0,G_OBJECTS
        SETADDR g_redraw,hunk0,G_REDRAW
        SETADDR g_buttons,hunk0,G_BUTTONS
        SETADDR g_key,hunk0,G_KEY
        SETADDR g_play_pointer,hunk0,G_PLAY_POINTER
        SETADDR g_planes,hunk0,G_PLANES
        SETADDR g_wait_frame,hunk0,G_WAIT_FRAME
        SETADDR g_music_off,hunk0,G_MUSIC_OFF
        SETADDR g_music_on,hunk0,G_MUSIC_ON
        SETADDR g_idle,hunk0,G_IDLE
        SETADDR r_loop_rest,hunk0,R_LOOP_REST
        SETADDR scroll_flags,hunk0,SCROLL_FLAGS
        SETADDR pal_play,hunk1,PAL_PLAY
        SETADDR ptr_cross,hunk1,PTR_CROSS
        SETADDR g_find_type,hunk0,G_FIND_TYPE
        SETADDR g_expand_objects,hunk0,G_EXPAND_OBJECTS
        SETADDR g_border_clear,hunk0,G_BORDER_CLEAR
        SETADDR placements,hunk0,PLACEMENTS
        SETADDR g_picker,hunk0,G_PICKER
        SETADDR g_panel,hunk0,G_PANEL
        SETADDR g_panel_slot,hunk0,G_PANEL_SLOT
        SETADDR g_panel_count,hunk0,G_PANEL_COUNT
        SETADDR g_clock,hunk0,G_CLOCK
        SETADDR g_frame_end,hunk0,G_FRAME_END
        move.w #NEW_STYLE,new_style
        move.w #NEW_SHAPE,new_shape
        SETADDR bar_copper,chip_base,CHIP_BAR_COPPER
        SETADDR bar_bitmap,chip_base,CHIP_BAR
        bsr load_tile_defaults

        PATCH P_CROSSES,$4ef9,hook_crosses      ; jmp
        ifnd PAL_RELEASE
        PATCH P_QUIT,$4ef9,hook_quit            ; jmp
        else
        movea.l hunk0,a1                ; jmp hook_quit_column, no NOP: the
        adda.l #P_QUIT,a1               ; next column's test follows at once
        move.w #$4ef9,(a1)+
        move.l #hook_quit_column,(a1)
        endif
        PATCH P_COUNT,$4eb9,hook_count          ; jsr
        PATCH P_PLAY_END,$4ef9,hook_play_end    ; jmp
        PATCH P_ESCAPE,$4ef9,hook_escape        ; jmp
        PATCH P_TAB,$4ef9,hook_tab              ; jmp
        PATCH P_RELEASE,$4ef9,hook_release      ; jmp
        PATCH P_OPENING,$4ef9,hook_opening      ; jmp
        PATCH P_FRAME,$4ef9,hook_frame          ; jmp
        PATCH P_SPRITE_POS,$4ef9,sprite_words   ; jmp
        moveq #0,d0
        bra.s .done
.no_chip:
        lea s_no_chip(pc),a0
        move.l a0,d0
        bra.s .done
.wrong: lea s_wrong_game(pc),a0
        move.l a0,d0
.done:  movem.l (sp)+,d1-d7/a1-a6
        rts

; The usual Decor and Steel flags of each style's tiles (data/EditorTiles),
; which the install tool computes from the game's own levels; without the
; file the editor starts with both off.
load_tile_defaults:
        movea.l resload_base,a2
        lea s_tiles_file(pc),a0
        jsr resload_GetFileSize(a2)
        cmp.l #STYLE_COUNT*TILE_DEFAULTS,d0
        bne.s .none
        lea s_tiles_file(pc),a0
        lea tile_defaults,a1
        jsr resload_LoadFile(a2)
.none:  rts

;============================================================================
; Hooks

; Jumped to from P_CROSSES while the title is drawn: the EDIT label instead
; of the crosses over the QUIT button, which needs an operating system.
hook_crosses:
        movem.l d0-d7/a0-a4,-(sp)
        bsr draw_edit_label
        movem.l (sp)+,d0-d7/a0-a4
        GJUMP crosses_done

        ifd PAL_RELEASE
; Jumped to from P_QUIT in the title's click tests: in the PAL release the
; QUIT button's column leads back to the title loop, as there is no QUIT;
; here it is the EDIT button. Other columns go on to the next test.
hook_quit_column:
        cmp.w #QUIT_RIGHT,d0
        blt.s hook_quit
        GJUMP next_column
        endif

; Jumped to from P_QUIT: the EDIT button was clicked. The return address of
; the title (to StartLemmings2) is on the stack.
hook_quit:
        GCALL stop_sound
        bsr pointer_busy
        bsr click_sound
        movea.l pal_black,a0            ; the title fades out
        movea.l cop_title,a1
        GCALL fade
        bsr session_begin
        st from_title
        ; fall through

; The list; a level to play or edit, or back to the title.
list_flow:
        bsr list_page
        tst.w d0
        beq.s .back
        cmp.w #LIST_EDIT,d0
        beq.s .edit
        bsr start_play
        bra.s .started
.edit:  bsr start_edit
.started:
        tst.w d0
        bne.s list_flow                 ; the file was not a valid record
        tst.b from_title
        beq.s .build
        sf from_title
        addq.l #4,sp                    ; as if the title had returned
.build: GJUMP build
.back:  bsr session_end
        bsr pointer_normal
        tst.b from_title
        beq.s .title
        sf from_title
        GJUMP title_again
.title: GJUMP title

; Called from P_COUNT in place of bsr.w G_COUNT / move.w d0,$124(a5): a
; custom level has the game's count for a level without progress.
hook_count:
        tst.b custom_active
        bne.s .custom
        pea .store(pc)
        move.l g_count,-(sp)
        rts
.custom:
        moveq #CUSTOM_COUNT,d0
.store: move.w d0,G_LEMMINGS(a5)
        rts

; Jumped to from P_TAB with the key in D0, in the play keys ($B4A). Tab
; switches the display between PAL and NTSC (G_VIDEO); the editor needs
; PAL, as its bar lies below the play view, so a custom level, played from
; the list or test played, ignores it. Elsewhere Tab works as in the game.
hook_tab:
        cmp.b #9,d0
        bne.s .other
        tst.b custom_active
        bne.s .other
        move.l g_video,-(sp)            ; as the original's beq.w
        rts
.other: move.l r_after_tab,-(sp)        ; the next key test
        rts

; Jumped to from P_PLAY_END when play ends. Practice and the tribes' levels
; continue as in the game; a custom level goes to the editor's result page,
; never to the game's, which writes the progress table ($E04E).
hook_play_end:
        tst.b G_PRACTICE(a5)
        beq.s .tribe
        GJUMP title
.tribe: tst.b custom_active
        bne.s .custom
        GJUMP result
.custom:
        bsr pointer_normal
        bsr result_page
        tst.b testing
        bne test_result
        tst.w d0
        beq.s .replay
        cmp.w #RESULT_EDIT,d0
        bne list_flow
        bsr start_edit                  ; the same level in the editor
        bra.s .started
.replay:
        bsr start_play                  ; the same level again
.started:
        tst.w d0
        bne list_flow
        GJUMP build

;============================================================================
; Custom play

; A level without an entrance: every shipped level has one, an editor
; level may not (the editor only warns). Two places of the game take the
; entrance count A5+$194 for at least one: the entrances' opening and the
; release of lemmings, the two hooks below.
;
; Jumped to from P_OPENING in AdvanceLevelLifecycle ($1EA): while the
; entrances open (A5+$1E6), each pass moves every entrance on a frame, in a
; dbf loop over count - 1, which with no entrance runs 65536 times through
; pointers read from past the entrance table ($13A92) and writes all over
; memory; the game crashes later. With none, the opening is over at once,
; as at its end ($22A). D0 (the passes, compared at $22E) is kept.
hook_opening:
        tst.b G_OPENING(a5)             ; the original test
        beq.s .opened
        tst.w G_ENTRANCES(a5)
        bne.s .open
        sf G_OPENING(a5)
.opened:
        move.l r_opened,-(sp)
        rts
.open:  move.l r_opening,-(sp)
        rts

; Jumped to from P_RELEASE in ReleaseL2Lemming ($9AC2), past its pause and
; count checks: no lemming comes out. The game takes the n-th lemming's
; place from the four-entry entrance table and goes back to the first when
; n reaches the count; with none it never does and reads on past the table
; into code.
hook_release:
        tst.w G_ENTRANCES(a5)
        beq.s .none
        tst.b G_RELEASE_HOLD(a5)        ; the two original instructions
        bne.s .none
        move.l r_release,-(sp)
.none:  rts

; The tribe, its selected level and the record in hunk 3 are kept aside
; while custom levels are played, and put back afterwards: the title resets
; the tribe when A5+$120 is negative ($D93A), and the game parses hunk 3
; again when the same level index is selected ($19AE).
session_begin:
        tst.b session_open
        bne.s .open
        move.w G_TRIBE(a5),saved_tribe
        move.w G_INDEX(a5),saved_index
        movea.l hunk3,a0
        lea saved_record,a1
        bsr copy_record
        st session_open
.open:  rts

session_end:
        tst.b session_open
        beq.s .done
        lea saved_record,a0
        movea.l hunk3,a1
        bsr copy_record
        move.w saved_index,G_INDEX(a5)
        move.w saved_tribe,d0
        cmp.w G_TRIBE(a5),d0
        beq.s .style
        move.w d0,G_TRIBE(a5)
        bsr pointer_busy
        GCALL load_style
.style: sf custom_active
        sf session_open
.done:  rts

copy_record:                            ; A0 -> A1, one record
        move.w #RECORD_SIZE/4-1,d0
.copy:  move.l (a0)+,(a1)+
        dbra d0,.copy
        rts

; Plays the selected entry: D0 = 0, or -1 when its file is not a valid
; record.
start_play:
        bsr load_selected
        tst.w d0
        bmi.s .fail
        lea record_buffer,a0            ; a skill its style cannot use is
        bsr skills_fit                  ; not played; the file keeps it
        sf editing
        bsr enter_level
        moveq #0,d0
.fail:  rts

; The selected entry's file into record_buffer, and path: D0 = its style,
; or -1 when it is not a valid record.
load_selected:
        bsr pointer_busy
        move.w selected,d0
        bmi .fail
        bsr entry_at
        tst.b E_OK(a2)
        beq .fail
        bsr make_path
        movea.l resload_base,a2
        lea path,a0
        jsr resload_GetFileSize(a2)
        cmp.l #RECORD_SIZE,d0
        bne .fail
        lea path,a0
        lea record_buffer,a1
        jsr resload_LoadFile(a2)
        lea record_buffer+R_OBJECTS-8,a0
        bsr check_objects_chunk
        bne .fail
        lea record_buffer,a0
        bsr check_record
        tst.w d0
        bmi .fail
        move.w record_buffer+R_SHAPE,d1
        ror.w #8,d1
        lea record_buffer+R_OBJECTS,a0
        bsr check_placements
        bne .fail
        rts
.fail:  bsr pointer_normal
        moveq #-1,d0
        rts

; record_buffer, of style D0, becomes the selected level: it goes into hunk
; 3 and is parsed there; its style is loaded first, as Practice does
; ($162A2), with the record's style as the tribe; then play is initialized
; as EnterPracticeMode does ($1616A).
enter_level:
        move.w d0,play_style
        ifnd PAL_RELEASE                ; the PAL release checks $B4 when it
        GCALL protection                ; selects the level
        endif
        lea record_buffer,a0
        movea.l hunk3,a1
        bsr copy_record
        move.w play_style,d0
        cmp.w G_TRIBE(a5),d0
        beq.s .style
        move.w d0,G_TRIBE(a5)
        GCALL load_style
.style: st custom_active
        move.w G_INDEX(a5),d0           ; the same index: no bank copy
        GCALL select_level
        GCALL init_play
        rts

; A0: a record, at least HEAD_SIZE bytes. D0 = its style, or -1.
check_record:
        cmp.l #'FORM',(a0)
        bne.s .bad
        cmp.l #RECORD_SIZE-8,4(a0)
        bne.s .bad
        cmp.l #'L2LV',8(a0)
        bne.s .bad
        cmp.l #'L2LH',$0c(a0)
        bne.s .bad
        cmp.l #74,$10(a0)
        bne.s .bad
        cmp.l #'L2MH',$5e(a0)
        bne.s .bad
        cmp.l #6,$62(a0)
        bne.s .bad
        cmp.l #'L2MP',$6c(a0)
        bne.s .bad
        cmp.l #MAP_BYTES,$70(a0)        ; the game copies what it says
        bne.s .bad
        moveq #0,d1
        move.b R_SHAPE+1(a0),d1
        lsl.w #8,d1
        move.b R_SHAPE(a0),d1
        cmp.w #SHAPES,d1
        bhs.s .bad
        moveq #0,d0
        move.b R_STYLE+1(a0),d0
        lsl.w #8,d0
        move.b R_STYLE(a0),d0
        cmp.w #STYLES,d0
        bhs.s .bad
        bsr.s check_values
        bne.s .bad
        rts
.bad:   moveq #-1,d0
        rts

; A0 a record, D1 its shape -> Z set when the fields that would make the
; game go wrong are as in every shipped level: the skill IDs 0 to 51 (a
; higher one is drawn from past the game's tables, and the game crashed
; at once), and on each axis the start view and the scroll limits inside
; the map, lower <= view <= upper, on 16-pixel steps from the view (play
; scrolls from the view and stops only where it meets a limit; a level
; from elsewhere with its view far outside the map crashed the game in
; play). Preserves D0 and A0.
check_values:
        movem.l d0-d6/a0-a1,-(sp)
        lea R_SKILLS(a0),a1
        moveq #SKILL_SLOTS-1,d6
.skill: moveq #0,d2
        move.b 1(a1),d2
        lsl.w #8,d2
        move.b (a1),d2
        cmp.w #SKILL_ID_MAX,d2
        bhi.s .bad
        addq.l #2,a1
        dbra d6,.skill
        movea.l hunk0,a1
        adda.l #G_SHAPES,a1
        lsl.w #2,d1
        move.w 0(a1,d1.w),d5            ; the largest scroll x
        sub.w #VIEW_WORDS,d5
        lsl.w #CELL_SHIFT_X,d5
        move.w 2(a1,d1.w),d6            ; and y
        lsl.w #CELL_SHIFT_Y,d6
        sub.w #VIEW_ROWS,d6
        lea R_VIEW(a0),a1
        move.w d5,d4
        bsr.s .axis
        bne.s .bad
        addq.l #2,a1
        move.w d6,d4
        bsr.s .axis
        bra.s .out
.bad:   moveq #1,d0                     ; Z clear
.out:   movem.l (sp)+,d0-d6/a0-a1       ; the flags stay
        rts
; A1 the view's LE word on an axis (its lower limit +4, upper +8), D4 the
; largest scroll -> Z set when valid.
.axis:  movea.l a1,a0
        bsr.s .le
        move.w d0,d1                    ; the view
        lea 4(a1),a0
        bsr.s .le
        move.w d0,d2                    ; the lower limit
        lea 8(a1),a0
        bsr.s .le
        move.w d0,d3                    ; the upper
        tst.w d2
        bmi.s .no
        cmp.w d2,d1
        blt.s .no
        cmp.w d1,d3
        blt.s .no
        cmp.w d4,d3
        bgt.s .no
        move.w d1,d0
        sub.w d2,d0
        and.w #15,d0
        bne.s .no
        move.w d3,d0
        sub.w d1,d0
        and.w #15,d0
        rts
.no:    moveq #1,d0                     ; Z clear
        rts
.le:    moveq #0,d0
        move.b 1(a0),d0
        lsl.w #8,d0
        move.b (a0),d0
        rts

; A0 the placements (64 of five LE16: type, x, y, copies across and down;
; type -1 an empty place, whose other words are anything), D0 the style,
; D1 the shape -> Z set when every type is one the style has (another one
; made the game's object expansion crash at once), the copies are 0 to 40
; (the editor's range; the shipped levels use up to 18), the origin is
; at most PLACE_SLACK pixels outside the map (the shipped levels' are
; inside; one far outside crashed the game in play) and on the 16x8 cell
; grid, as every shipped one and every one the editor places (the game's
; build, $C6E2, addresses a cell by x / 4 and y / 4 unmasked, so an
; origin off the grid had its tiles written across cells). Parts that a
; level from elsewhere repeats past the map are not checked: the game
; writes them without clipping, as it would in its own levels. Preserves
; D0/A0.
check_placements:
        movem.l d0-d7/a0-a1,-(sp)
        lea style_types(pc),a1
        moveq #0,d7
        move.b 0(a1,d0.w),d7            ; the style's types
        movea.l hunk0,a1
        adda.l #G_SHAPES,a1
        lsl.w #2,d1
        move.w 0(a1,d1.w),d5
        lsl.w #CELL_SHIFT_X,d5
        add.w #PLACE_SLACK,d5           ; the largest x
        move.w 2(a1,d1.w),d6
        lsl.w #CELL_SHIFT_Y,d6
        add.w #PLACE_SLACK,d6           ; and y
        moveq #64-1,d4
.place: bsr.s .le
        cmp.w #-1,d0
        beq.s .next
        cmp.w d7,d0
        bhs.s .bad
        bsr.s .le                       ; x
        cmp.w #-PLACE_SLACK,d0
        blt.s .bad
        cmp.w d5,d0
        bgt.s .bad
        moveq #(1<<CELL_SHIFT_X)-1,d1   ; on a cell column
        and.w d0,d1
        bne.s .bad
        bsr.s .le                       ; y
        cmp.w #-PLACE_SLACK,d0
        blt.s .bad
        cmp.w d6,d0
        bgt.s .bad
        moveq #(1<<CELL_SHIFT_Y)-1,d1   ; and row
        and.w d0,d1
        bne.s .bad
        bsr.s .le                       ; copies across
        cmp.w #MAX_REPEAT,d0
        bhi.s .bad
        bsr.s .le                       ; and down
        cmp.w #MAX_REPEAT,d0
        bhi.s .bad
        subq.l #8,a0
.next:  lea 10-2(a0),a0
        dbra d4,.place
        cmp.b d0,d0                     ; Z set
        bra.s .out
.bad:   moveq #1,d0                     ; Z clear
.out:   movem.l (sp)+,d0-d7/a0-a1       ; the flags stay
        rts
.le:    moveq #0,d0                     ; the next LE16 at A0
        move.b 1(a0),d0
        lsl.w #8,d0
        move.b (a0),d0
        addq.l #2,a0
        rts

; The object types of each style (the L2OB count of its astyle.dat, which
; the install checks by SHA-256 with the other game files), in style order.
style_types:
        dc.b 14,14,13,17,18,14,12,15,14,23,13,18
        even

; A0: the 8 bytes before R_OBJECTS -> Z set when they are the L2BO chunk's
; tag and size, as the game's parser walks to it.
check_objects_chunk:
        cmp.l #'L2BO',(a0)
        bne.s .done
        cmp.l #OBJECTS_BYTES,4(a0)
.done:  rts

; D0 = the result's grade by the game's rule ($E04E): 3 when no more were
; lost than the threshold, 2 when at most half, else 1; 0 when none saved.
grade:  move.w G_SAVED(a5),d1
        beq.s .none
        move.w G_LEMMINGS(a5),d0
        sub.w d1,d0                     ; lost
        movea.l level_header,a0
        cmp.w H_THRESHOLD(a0),d0
        ble.s .three
        move.w G_LEMMINGS(a5),d1
        lsr.w #1,d1
        cmp.w d1,d0
        bgt.s .one
        moveq #2,d0
        rts
.three: moveq #3,d0
        rts
.one:   moveq #1,d0
        rts
.none:  moveq #0,d0
        rts

;============================================================================
; The list of custom levels

; D0 = LIST_PLAY or LIST_EDIT: the selected entry; 0: back. New, Rename
; and Delete are pages of their own, from which the list comes back.
list_page:
        bsr pointer_busy
        bsr scan_levels
        bsr menu_open
        bsr list_draw
        bsr menu_fade_in
        bsr pointer_normal
.wait:  move.b #SCREEN_LIST,screen
        bsr list_off
        bsr menu_set_off
        bsr menu_input
        tst.w d0
        bpl .button
        cmp.w #MENU_CLICK,d0
        beq.s .click
        cmp.w #MENU_KEY,d0
        beq .key
        cmp.w #MENU_OFF,d0
        bne.s .wait
        lea s_no_level(pc),a0           ; a dimmed button
        tst.w entry_count
        beq.s .say
        lea s_damaged_only(pc),a0
.say:   bsr menu_say
        bra.s .wait
.click: move.w d1,d0
        move.w d2,d1
        cmp.w #ROW_Y,d1
        blo.s .wait
        cmp.w #PAGE_Y,d1
        bhs.s .below
        sub.w #ROW_Y,d1                 ; a row
        ext.l d1
        divu #ROW_H,d1
        move.w current_page,d2
        mulu #ROWS,d2
        add.w d1,d2
        cmp.w entry_count,d2
        bhs.s .wait
        move.w d2,selected
        bsr list_draw_rows
        bra.s .wait
.below: cmp.w #PAGE_Y+ROW_H,d1
        bhs .wait
        cmp.w #160,d0                   ; the page line
        bhs.s .next
.previous:
        tst.w current_page
        beq .wait
        subq.w #1,current_page
        bra.s .turned
.next:  move.w current_page,d2
        addq.w #1,d2
        move.w d2,d3
        mulu #ROWS,d3
        cmp.w entry_count,d3
        bhs .wait
        move.w d2,current_page
.turned:
        move.w current_page,d7          ; the page's first level selected, so
        mulu #ROWS,d7                   ; that Play and Edit take one shown
        bsr select_entry
        bsr click_sound
        bsr list_draw_rows
        bra .wait
.key:   cmp.b #KEY_LEFT,d1
        beq.s .previous
        cmp.b #KEY_RIGHT,d1
        beq.s .next
        moveq #-1,d0
        cmp.b #KEY_UP,d1
        beq.s .move
        moveq #1,d0
        cmp.b #KEY_DOWN,d1
        bne .wait
.move:  move.w selected,d7              ; the level above or below
        bmi .wait
        add.w d0,d7
        bmi .wait
        cmp.w entry_count,d7
        bhs .wait
        bsr select_entry
        bsr list_draw_rows
        bra .wait
.button:
        cmp.w #LIST_BUTTON_NEW,d0
        beq.s .new
        cmp.w #LIST_BUTTON_RENAME,d0
        beq.s .rename
        cmp.w #LIST_BUTTON_DELETE,d0
        beq.s .delete
        cmp.w #LIST_BUTTON_BACK,d0
        beq.s .back
        addq.w #1,d0                    ; LIST_PLAY, LIST_EDIT
        clr.b screen
        rts
.back:  clr.b screen
        bsr menu_fade_out
        moveq #0,d0
        rts
.new:   bsr new_page
        tst.w d0
        bmi.s .listed
        moveq #LIST_EDIT,d0             ; the new level, selected
        rts
.listed:
        suba.l a0,a0
        bra.s .again
.rename:
        bsr rename_page
        bra.s .again
.delete:
        bsr delete_page
.again: move.l a0,-(sp)                 ; the list again, with a message
        GCALL show_menu
        bsr list_draw
        move.l (sp)+,d0
        beq .wait
        movea.l d0,a0
        bsr menu_say
        bra .wait

; -> D0 the list's buttons that do nothing at the moment: Play and Edit
; without a valid level selected, Rename and Delete without any.
list_off:
        moveq #LIST_OFF_EMPTY,d0
        move.w selected,d1
        bmi.s .done
        move.w d1,d0
        bsr entry_at
        moveq #0,d0
        tst.b E_OK(a2)
        bne.s .done
        moveq #LIST_OFF_DAMAGED,d0
.done:  rts

LIST_BUTTON_NEW equ 2           ; the list's buttons, from 0
LIST_BUTTON_RENAME equ 3
LIST_BUTTON_DELETE equ 4
LIST_BUTTON_BACK equ 5
LIST_OFF_DAMAGED equ %00011     ; Play, Edit
LIST_OFF_EMPTY  equ %11011      ; and Rename, Delete

list_buttons:
        MBUTTON MB_COLUMN_1,MB_ROW_1,'p',s_play_label,h_play_level
        MBUTTON MB_COLUMN_2,MB_ROW_1,'e',s_edit_label,h_edit_level
        MBUTTON MB_COLUMN_3,MB_ROW_1,'n',s_new_label,h_new_level
        MBUTTON MB_COLUMN_1,MB_ROW_2,'r',s_rename_label,h_rename_level
        MBUTTON MB_COLUMN_2,MB_ROW_2,$7f,s_delete,h_delete_level
        MBUTTON MB_COLUMN_3,MB_ROW_2,KEY_ESC,s_back_label,h_back_title
        dc.w -1
result_buttons:
        MBUTTON MB_COLUMN_1,MB_ROW_2,'r',s_replay_label,h_replay
        MBUTTON MB_COLUMN_2,MB_ROW_2,'e',s_edit_label,h_edit_again
        MBUTTON MB_COLUMN_3,MB_ROW_2,KEY_ESC,s_levels_label,h_levels
        dc.w -1
new_buttons:
        MBUTTON MB_COLUMN_1,MB_ROW_2,KEY_RETURN,s_create_label,h_create
        MBUTTON MB_COLUMN_3,MB_ROW_2,KEY_ESC,s_cancel_label,h_no_new
        dc.w -1

; The .lvl files of Levels, sorted by name; not those deleted in this
; session (name_deleted). Only the names are read here: a level's title,
; style and time, or that it is damaged, are read from its file when its
; page is shown (entry_at), so that the list opens as fast with many
; files as with a few. The selection stays in range: the last level when
; the last one was deleted.
scan_levels:
        clr.w entry_count
        move.w #-1,page_read
        move.l #NAMES_SIZE,d0
        lea s_levels_dir(pc),a0
        lea names,a1
        movea.l resload_base,a2
        jsr resload_ListFiles(a2)
        move.w d0,names_left
        lea names,a4
.name:  subq.w #1,names_left
        bmi .listed
        movea.l a4,a0
.end:   tst.b (a0)+
        bne.s .end
        move.l a0,next_name
        move.l a0,d6
        sub.l a4,d6
        subq.l #1,d6                    ; the name's length
        cmp.w #5,d6
        blo.s .skip
        cmp.w #NAME_MAX,d6
        bhi.s .skip
        lea -5(a0),a1                   ; ".lvl", any case
        cmp.b #'.',(a1)+
        bne.s .skip
        move.b (a1)+,d0
        or.b #$20,d0
        cmp.b #'l',d0
        bne.s .skip
        move.b (a1)+,d0
        or.b #$20,d0
        cmp.b #'v',d0
        bne.s .skip
        move.b (a1)+,d0
        or.b #$20,d0
        cmp.b #'l',d0
        bne.s .skip
        bsr name_deleted
        bne.s .skip
        cmp.w #MAX_LEVELS,entry_count
        bhs.s .skip
        bsr add_name
.skip:  movea.l next_name,a4
        bra .name
.listed:
        move.w selected,d0
        bpl.s .high
        moveq #0,d0
.high:  cmp.w entry_count,d0
        blo.s .selected
        move.w entry_count,d0
        subq.w #1,d0                    ; -1: none
.selected:
        move.w d0,selected
        moveq #0,d1
        tst.w d0
        bmi.s .page
        ext.l d0
        divu #ROWS,d0
        move.w d0,d1
.page:  move.w d1,current_page
        rts

; A4: a name in names -> its place in order, by name with case ignored:
; found by halves, the later ones moved up by one.
add_name:
        moveq #0,d4                     ; the first place it may take
        move.w entry_count,d5           ; and the last
.half:  cmp.w d5,d4
        bhs.s .found
        move.w d4,d3
        add.w d5,d3
        lsr.w #1,d3
        move.w d3,d0
        bsr entry_name
        movea.l a4,a1
        bsr compare_names
        tst.w d0
        bgt.s .before
        move.w d3,d4
        addq.w #1,d4
        bra.s .half
.before:
        move.w d3,d5
        bra.s .half
.found: lea order,a0
        move.w entry_count,d0
        add.w d0,d0
        lea 0(a0,d0.w),a1               ; after the last
        add.w d4,d4
        lea 0(a0,d4.w),a2               ; the place
.up:    cmpa.l a2,a1
        beq.s .store
        move.w -(a1),2(a1)
        bra.s .up
.store: lea names,a0
        move.l a4,d0
        sub.l a0,d0
        move.w d0,(a2)
        addq.w #1,entry_count
        rts

; D0: an entry's index -> A0: its name. Changes D0.
entry_name:
        lea order,a0
        add.w d0,d0
        move.w 0(a0,d0.w),d0
        lea names,a0
        adda.w d0,a0
        rts

; D0: an entry's index -> A2: its entry, the name and what its file holds.
; The entries of a page are read from their files when one of them is
; asked for first after the list was read (load_page).
entry_at:
        move.l d1,-(sp)
        moveq #0,d1
        move.w d0,d1
        divu #ROWS,d1                   ; the page, the row in the high word
        cmp.w page_read,d1
        beq.s .read
        movem.l d0-d7/a0-a1/a3-a6,-(sp)
        move.w d1,d0
        bsr load_page
        movem.l (sp)+,d0-d7/a0-a1/a3-a6
.read:  swap d1
        mulu #ENTRY_SIZE,d1
        lea entries,a2
        adda.l d1,a2
        move.l (sp)+,d1
        rts

; D0: a page -> entries: its levels, each with its record's title, style
; and time, or marked damaged; page_read is the page once all are read.
load_page:
        move.w d0,-(sp)
        mulu #ROWS,d0
        move.w d0,d7                    ; the page's first entry
        lea entries,a2
        moveq #ROWS-1,d5
.entry: cmp.w entry_count,d7
        bhs.s .done
        move.w d7,d0
        bsr entry_name
        movem.l d5/d7/a2,-(sp)
        bsr read_entry
        movem.l (sp)+,d5/d7/a2
        lea ENTRY_SIZE(a2),a2
        addq.w #1,d7
        dbra d5,.entry
.done:  move.w (sp)+,page_read
        rts

; A0: a name, A2: its entry, filled from the file. The file is read whole
; into record_buffer, as Play and Edit read it (load_selected): two resload
; calls, which count when WHDLoad has to fetch the file from the disk.
; Nothing on the list needs record_buffer kept.
read_entry:
        movea.l a2,a1
        moveq #ENTRY_SIZE/4-1,d0
.clear: clr.l (a1)+
        dbra d0,.clear
        lea E_NAME(a2),a1
.copy:  move.b (a0)+,(a1)+
        bne.s .copy
        bsr make_path
        movea.l resload_base,a3
        lea path,a0
        jsr resload_GetFileSize(a3)
        cmp.l #RECORD_SIZE,d0
        bne .done
        lea path,a0
        lea record_buffer,a1
        jsr resload_LoadFile(a3)
        lea record_buffer,a0
        bsr check_record
        tst.w d0
        bmi .done
        move.w d0,E_STYLE(a2)
        lea record_buffer+R_OBJECTS-8,a0
        bsr check_objects_chunk
        bne .done
        lea record_buffer+R_OBJECTS,a0
        move.w E_STYLE(a2),d0
        move.w record_buffer+R_SHAPE,d1
        ror.w #8,d1                     ; little-endian
        bsr check_placements
        bne .done
        lea record_buffer+R_TITLE_TEXT,a0
        lea E_TITLE(a2),a1
        moveq #24-1,d0
.title: move.b (a0)+,(a1)+
        dbra d0,.title
        move.b record_buffer+R_MINUTES,E_MINUTES(a2)
        move.b record_buffer+R_SECONDS,E_SECONDS(a2)
        st E_OK(a2)
.done:  rts

; A2: an entry -> path = "Levels/" and its name.
make_path:
        lea s_levels_dir(pc),a0
        lea path,a1
.dir:   move.b (a0)+,(a1)+
        bne.s .dir
        move.b #'/',-1(a1)
        lea E_NAME(a2),a0
.name:  move.b (a0)+,(a1)+
        bne.s .name
        rts

; A0, A1: names -> D0 < 0, 0 or > 0.
compare_names:
        movem.l d1/a0-a1,-(sp)
.char:  move.b (a0)+,d0
        cmp.b #'A',d0
        blo.s .lower0
        cmp.b #'Z',d0
        bhi.s .lower0
        add.b #'a'-'A',d0
.lower0:
        move.b (a1)+,d1
        cmp.b #'A',d1
        blo.s .lower1
        cmp.b #'Z',d1
        bhi.s .lower1
        add.b #'a'-'A',d1
.lower1:
        cmp.b d1,d0
        bne.s .differ
        tst.b d0
        bne.s .char
        moveq #0,d0
        bra.s .out
.differ:
        bhi.s .greater
        moveq #-1,d0
        bra.s .out
.greater:
        moveq #1,d0
.out:   movem.l (sp)+,d1/a0-a1
        rts

; The whole list page on a fresh background.
list_draw:
        bsr txt_start
        lea s_list_title(pc),a0
        move.w #TITLE_Y,d1
        bsr txt_centred_line
        bsr txt_draw
        bsr list_off
        lea list_buttons(pc),a0
        lea s_list_help(pc),a1
        bsr menu_page
        ; fall through

; The rows of the current page and the page line.
list_draw_rows:
        moveq #0,d0
        move.w #ROW_Y,d1
        move.w #320,d2
        move.w #(ROWS+1)*ROW_H,d3
        GCALL restore_rect
        bsr txt_start
        tst.w entry_count
        bne.s .rows
        lea s_empty1(pc),a0
        move.w #EMPTY_Y,d1
        bsr txt_centred_line
        lea s_empty2(pc),a0
        move.w #EMPTY_Y+ROW_H,d1
        bsr txt_centred_line
        bra .draw
.rows:  move.w current_page,d7
        mulu #ROWS,d7                   ; the first entry of the page
        moveq #0,d6                     ; its row
.row:   cmp.w entry_count,d7
        bhs .paging
        move.w d7,d0
        bsr entry_at
        moveq #1,d2
        cmp.w selected,d7
        bne.s .colour
        moveq #0,d2
.colour:
        move.w d2,row_colour
        move.w d6,d1
        mulu #ROW_H,d1
        add.w #ROW_Y,d1
        move.w d1,row_y
        moveq #COLUMN_TITLE,d0
        bsr txt_left
        tst.b E_OK(a2)
        beq.s .damaged
        lea E_TITLE(a2),a0
        moveq #24,d2
        move.w #COLUMN_TIME-COLUMN_GAP-COLUMN_TITLE,d3
        bsr txt_fit
        move.w #COLUMN_TIME,d0
        move.w row_y,d1
        move.w row_colour,d2
        bsr txt_left
        moveq #0,d0
        move.b E_MINUTES(a2),d0
        bsr txt_number
        move.b #':',(a3)+
        moveq #0,d0
        move.b E_SECONDS(a2),d0
        cmp.w #10,d0
        bhs.s .seconds
        move.b #'0',(a3)+
.seconds:
        bsr txt_number
        move.w #COLUMN_STYLE,d0
        move.w row_y,d1
        move.w row_colour,d2
        bsr txt_left
        move.w E_STYLE(a2),d0
        bsr txt_style
        bra.s .next
.damaged:
        lea E_NAME(a2),a0
        moveq #NAME_MAX,d2
        move.w #COLUMN_TIME-COLUMN_GAP-COLUMN_TITLE,d3
        bsr txt_fit
        move.w #COLUMN_TIME,d0
        move.w row_y,d1
        move.w row_colour,d2
        bsr txt_left
        lea s_damaged(pc),a0
        bsr txt_str
.next:  addq.w #1,d7
        addq.w #1,d6
        cmp.w #ROWS,d6
        blo .row
.paging:
        cmp.w #ROWS,entry_count
        bls.s .draw
        tst.w current_page
        beq.s .first
        moveq #COLUMN_TITLE,d0
        move.w #PAGE_Y,d1
        moveq #1,d2
        bsr txt_left
        lea s_previous(pc),a0
        bsr txt_str
.first: move.w current_page,d0
        addq.w #1,d0
        mulu #ROWS,d0
        cmp.w entry_count,d0
        bhs.s .last
        move.w #COLUMN_NEXT,d0
        move.w #PAGE_Y,d1
        moveq #1,d2
        bsr txt_left
        lea s_next(pc),a0
        bsr txt_str
.last:  move.w #PAGE_Y,d1
        bsr txt_centre
        lea s_page_text(pc),a0
        bsr txt_str
        move.w current_page,d0
        addq.w #1,d0
        bsr txt_number
        lea s_of_text(pc),a0
        bsr txt_str
        moveq #0,d0
        move.w entry_count,d0
        add.w #ROWS-1,d0
        divu #ROWS,d0
        bsr txt_number
.draw:  bra txt_draw

;============================================================================
; The result page after a custom level. D0 = 0: replay; 1: the list;
; RESULT_EDIT: the editor.

result_page:
        bsr menu_open
        bsr txt_start
        move.w #RESULT_TITLE_Y,d1
        bsr txt_centre
        movea.l level_header,a0
        moveq #24,d2
        bsr txt_field
        move.w #RESULT_SAVED_Y,d1
        bsr txt_centre
        lea s_saved1(pc),a0
        bsr txt_str
        move.w G_SAVED(a5),d0
        bsr txt_number
        lea s_saved2(pc),a0
        bsr txt_str
        move.w G_LEMMINGS(a5),d0
        bsr txt_number
        lea s_saved3(pc),a0
        bsr txt_str
        move.w #RESULT_GRADE_Y,d1
        bsr txt_centre
        bsr grade
        move.b d0,result_grade
        move.w d0,d7
        bne.s .graded
        lea s_none_saved(pc),a0
        bsr txt_str
        bra.s .buttons
.graded:
        lea s_grade1(pc),a0
        bsr txt_str
        move.w d7,d0
        bsr txt_number
        lea s_grade2(pc),a0
        bsr txt_str
.buttons:
        move.w #RESULT_HINT_Y,d1
        bsr txt_centre
        lea s_hint1(pc),a0
        bsr txt_str
        movea.l level_header,a0
        move.w H_THRESHOLD(a0),d0
        bsr txt_number
        lea s_hint2(pc),a0
        bsr txt_str
        bsr txt_draw
        lea result_buttons(pc),a0
        lea s_result_help(pc),a1
        moveq #0,d0
        bsr menu_page
        bsr menu_fade_in
.wait:  move.b #SCREEN_RESULT,screen
        bsr menu_input
        tst.w d0
        bmi.s .wait
        clr.b screen
        move.w d0,-(sp)
        bsr menu_fade_out
        move.w (sp)+,d0
        lea result_choice(pc),a0
        move.b 0(a0,d0.w),d0
        ext.w d0
        rts

result_choice:                          ; the buttons Replay, Edit, Levels
        dc.b 0,RESULT_EDIT,1
        even

;============================================================================
; The New page: a level made from a file name, a style and a map shape,
; written as one record (new_record) and then opened for editing. D0 = 0:
; written, its entry selected; -1: cancelled.

new_page:
        clr.b new_length
        clr.l new_message
        GCALL show_menu
        bsr new_draw
        bsr pointer_normal
.wait:  move.b #SCREEN_NEW,screen
        bsr menu_input
        tst.w d0
        beq.s .create
        cmp.w #1,d0
        beq.s .cancel
        cmp.w #MENU_RIGHT,d0
        beq.s .cancel
        cmp.w #MENU_KEY,d0
        beq.s .key
        cmp.w #MENU_CLICK,d0
        bne.s .wait
        move.w d1,d0
        move.w d2,d1
        bsr new_click
        bra.s .wait
.key:   lea new_style,a0                ; the cursor keys step the style
        moveq #STYLES,d2                ; and the size
        moveq #-1,d0
        cmp.b #KEY_LEFT,d1
        beq.s .step
        moveq #1,d0
        cmp.b #KEY_RIGHT,d1
        beq.s .step
        lea new_shape,a0
        moveq #SHAPES,d2
        moveq #-1,d0
        cmp.b #KEY_UP,d1
        beq.s .step
        moveq #1,d0
        cmp.b #KEY_DOWN,d1
        beq.s .step
        move.w d1,d0
        bsr name_key
        beq.s .wait
        clr.l new_message
        bsr new_draw_fields
        bra.s .wait
.step:  bsr new_step
        bra.s .wait
.create:
        bsr new_create
        tst.w d0
        bmi .wait
        clr.b screen
        moveq #0,d0
        rts
.cancel:
        clr.b screen
        moveq #-1,d0
        rts

; D0 a key: a character of a file name is added to new_name, Backspace or
; Del takes the last off. -> Z clear when the name changed.
name_key:
        cmp.b #8,d0
        beq.s .delete
        cmp.b #$7f,d0
        beq.s .delete
        bsr name_char
        bne.s .same
        moveq #0,d1
        move.b new_length,d1
        cmp.w #NEW_NAME_MAX,d1
        bhs.s .same
        lea new_name,a0
        move.b d0,0(a0,d1.w)
        addq.b #1,new_length
        bra.s .changed
.delete:
        tst.b new_length
        beq.s .same
        subq.b #1,new_length
.changed:
        moveq #1,d0
        rts
.same:  moveq #0,d0
        rts

; D0 a character -> Z set when it may be in a file name: letters, digits,
; - and _.
name_char:
        cmp.b #'-',d0
        beq.s .yes
        cmp.b #'_',d0
        beq.s .yes
        cmp.b #'0',d0
        blo.s .no
        cmp.b #'9',d0
        bls.s .yes
        cmp.b #'A',d0
        blo.s .no
        cmp.b #'Z',d0
        bls.s .yes
        cmp.b #'a',d0
        blo.s .no
        cmp.b #'z',d0
        bhi.s .no
.yes:   ori #4,ccr
        rts
.no:    andi #$fb,ccr
        rts

; D0 x, D1 y of a click: the style and size rows step back on their left
; half and on on their right.
new_click:
        lea new_style,a0
        moveq #STYLES,d2
        cmp.w #NEW_STYLE_Y-2,d1
        blo.s .none
        cmp.w #NEW_STYLE_Y-2+NEW_ROW_H,d1
        blo.s .row
        lea new_shape,a0
        moveq #SHAPES,d2
        cmp.w #NEW_SHAPE_Y-2,d1
        blo.s .none
        cmp.w #NEW_SHAPE_Y-2+NEW_ROW_H,d1
        bhs.s .none
.row:   moveq #1,d1
        cmp.w #NEW_MIDDLE,d0
        bhs.s .step
        moveq #-1,d1
.step:  move.w d1,d0
        bra.s new_step
.none:  rts

; A0 the style or the shape, D2 how many there are, D0 1 or -1: the next
; or the previous one, round.
new_step:
        add.w (a0),d0
        bpl.s .low
        move.w d2,d0
        subq.w #1,d0
.low:   cmp.w d2,d0
        blo.s .set
        moveq #0,d0
.set:   move.w d0,(a0)
        bsr click_sound
        clr.l new_message
        bra new_draw_fields

; The page on the menu background: the title, the labels, the fields, the
; buttons and the help.
new_draw:
        bsr txt_start
        lea s_new_title(pc),a0
        move.w #TITLE_Y,d1
        bsr txt_centred_line
        move.w #NEW_CREDIT_Y,d1
        moveq #0,d2
        bsr txt_centre_colour
        lea s_new_credit(pc),a0
        bsr txt_str
        lea s_name_label(pc),a0
        move.w #NEW_NAME_Y,d1
        bsr new_label
        lea s_style_label(pc),a0
        move.w #NEW_STYLE_Y,d1
        bsr new_label
        lea s_size_label(pc),a0
        move.w #NEW_SHAPE_Y,d1
        bsr new_label
        bsr txt_draw
        bsr new_draw_fields
        lea new_buttons(pc),a0
        lea s_new_help(pc),a1
        moveq #0,d0
        bra menu_page

; The name, the style, the size and a message, on fresh background.
new_draw_fields:
        move.w #NEW_VALUE_X,d0
        move.w #NEW_NAME_Y,d1
        move.w #320-NEW_VALUE_X,d2
        move.w #NEW_SHAPE_Y+NEW_ROW_H-NEW_NAME_Y,d3
        GCALL restore_rect
        moveq #0,d0
        move.w #NEW_MESSAGE_Y,d1
        move.w #320,d2
        moveq #NEW_ROW_H,d3
        GCALL restore_rect
        bsr txt_start
        move.w #NEW_NAME_Y,d1
        bsr name_value
        move.w #NEW_STYLE_Y,d1
        bsr new_value
        lea s_left_arrow(pc),a0
        bsr txt_str
        move.w new_style,d0
        bsr txt_style
        lea s_right_arrow(pc),a0
        bsr txt_str
        move.w #NEW_SHAPE_Y,d1
        bsr new_value
        lea s_left_arrow(pc),a0
        bsr txt_str
        bsr new_dimensions              ; D2 columns, D3 rows
        move.w d2,d0
        bsr txt_number
        lea s_by(pc),a0
        bsr txt_str
        move.w d3,d0
        bsr txt_number
        lea s_right_arrow(pc),a0
        bsr txt_str
        ; fall through

; new_message, if any, on its line; the stream drawn.
new_message_line:
        move.l new_message,d0
        beq.s .draw
        move.w #NEW_MESSAGE_Y,d1
        bsr txt_centre
        movea.l d0,a0
        bsr txt_str
.draw:  bra txt_draw

; D1 y: the typed name, where the next character goes, and ".lvl".
name_value:
        bsr new_value
        lea new_name,a0
        moveq #0,d2
        move.b new_length,d2
        bra.s .test
.char:  move.b (a0)+,d0
        bsr txt_char
.test:  dbra d2,.char
        move.b #'_',(a3)+
        lea s_lvl(pc),a0
        bra txt_str

new_label:                              ; A0 text, D1 y
        moveq #NEW_LABEL_X,d0
        moveq #1,d2
        bsr txt_left
        bra txt_str

new_value:                              ; D1 y: a value from its column on
        move.w #NEW_VALUE_X,d0
        moveq #1,d2
        bra txt_left

; -> D2 columns, D3 rows of the chosen shape, from the game's table.
new_dimensions:
        movea.l hunk0,a0
        adda.l #G_SHAPES,a0
        move.w new_shape,d0
        lsl.w #2,d0
        move.w 0(a0,d0.w),d2
        move.w 2(a0,d0.w),d3
        rts

; Create: a name that no level has, room in the list; the record written to
; Levels/<name>.lvl, the list read again with it selected. D0 = 0, or -1
; with a message on the page.
new_create:
        lea s_need_name(pc),a0
        tst.b new_length
        beq .refuse
        lea s_list_full(pc),a0
        cmp.w #MAX_LEVELS,entry_count
        bhs .refuse
        bsr name_file
        bsr new_entry                   ; -> D7 its entry, or entry_count
        lea s_name_exists(pc),a0
        cmp.w entry_count,d7
        blo .refuse
        lea new_file,a0
        lea path,a1
        bsr levels_path
        movea.l resload_base,a2         ; nor a file the list does not show
        lea path,a0
        jsr resload_GetFileSize(a2)
        lea s_name_exists(pc),a0
        tst.l d0
        bne .refuse
        bsr new_record
        bsr pointer_busy
        movea.l resload_base,a2
        move.l #RECORD_SIZE,d0
        lea path,a0
        lea record_buffer,a1
        jsr resload_SaveFile(a2)
        bsr keys_cleared
        bsr scan_levels
        bsr new_entry
        bsr select_entry
        moveq #0,d0
        rts
.refuse:
        move.l a0,new_message
        bsr new_draw_fields
        moveq #-1,d0
        rts

; new_file = the typed name and ".lvl".
name_file:
        lea new_name,a0
        lea new_file,a1
        moveq #0,d0
        move.b new_length,d0
        bra.s .test
.copy:  move.b (a0)+,(a1)+
.test:  dbra d0,.copy
        lea s_lvl(pc),a0
.ext:   move.b (a0)+,(a1)+
        bne.s .ext
        rts

; -> D7 the entry named new_file, or entry_count when there is none.
new_entry:
        moveq #0,d7
.entry: cmp.w entry_count,d7
        bhs.s .done
        move.w d7,d0
        bsr entry_name
        lea new_file,a1
        bsr compare_names
        tst.w d0
        beq.s .done
        addq.w #1,d7
        bra.s .entry
.done:  rts

; record_buffer: a new level of the chosen style and shape, as the shipped
; records keep their fields: the file's name as its title, the original
; Lemmings' eight skills, ten of each (without the Blocker outside the
; Classic style, skills_fit), five minutes; an empty map (the border is
; cleared by the game), no objects, every place empty (-1); the start view
; at the top left and scrolling over the whole map; both style fields
; equal; the bytes the game does not read zero.
new_record:
        lea record_buffer,a0
        move.w #RECORD_SIZE/4-1,d0
.clear: clr.l (a0)+
        dbra d0,.clear
        lea record_buffer,a0
        move.l #'FORM',(a0)
        move.l #RECORD_SIZE-8,4(a0)
        move.l #'L2LV',8(a0)
        move.l #'L2LH',$c(a0)
        move.l #74,$10(a0)
        lea R_TITLE_TEXT(a0),a1
        lea new_name,a2
        moveq #0,d0
        move.b new_length,d0
        moveq #TITLE_SIZE-1,d1
.title: moveq #' ',d2
        subq.w #1,d0
        bmi.s .pad
        move.b (a2)+,d2
.pad:   move.b d2,(a1)+
        dbra d1,.title
        lea R_SKILLS(a0),a1
        lea R_COUNTS(a0),a2
        lea new_skills(pc),a3
        moveq #SKILL_SLOTS-1,d0
.skill: move.b (a3)+,(a1)               ; LE16, IDs below 256
        addq.l #2,a1
        move.b #NEW_COUNT,(a2)+
        dbra d0,.skill
        move.b #NEW_MINUTES,R_MINUTES(a0)
        move.b new_style+1,R_HEAD_STYLE(a0)
        bsr new_dimensions              ; the upper scroll limits: the map's
        sub.w #VIEW_WORDS,d2
        lsl.w #CELL_SHIFT_X,d2          ; (columns - 22) * 16
        lsl.w #CELL_SHIFT_Y,d3
        sub.w #VIEW_ROWS,d3             ; rows * 8 - 192
        lea record_buffer,a0
        move.b d2,R_VIEW+8(a0)
        lsr.w #8,d2
        move.b d2,R_VIEW+9(a0)
        move.b d3,R_VIEW+10(a0)
        lsr.w #8,d3
        move.b d3,R_VIEW+11(a0)
        move.l #'L2MH',$5e(a0)
        move.l #6,$62(a0)
        move.b new_style+1,R_STYLE(a0)
        move.b new_shape+1,R_SHAPE(a0)
        move.l #'L2MP',$6c(a0)
        move.l #R_CELLS_SIZE,$70(a0)
        lea R_OBJECTS-8(a0),a1
        move.l #'L2BO',(a1)+
        move.l #R_BO_SIZE,(a1)+
        move.w #R_BO_SIZE/2-1,d0
.empty: move.w #-1,(a1)+
        dbra d0,.empty
        bra skills_fit

new_skills:     ; Climber, Floater, Exploder, Blocker, Builder, Basher,
                ; Miner, Digger: the Classic tribe's
        dc.b 18,22,24,51,19,20,21,17

;============================================================================
; The menu screen, through the game's own routines

menu_open:                              ; background shown, colours black
        GCALL unpack_menu
        GCALL show_menu
        bsr menu_black
        moveq #MENU,d0
        GCALL copper
        rts

menu_fade_in:
        movea.l pal_menu,a0
        movea.l cop_menu,a1
        GCALL fade
        rts

menu_fade_out:
        movea.l pal_black,a0
        movea.l cop_menu,a1
        GCALL fade
        rts

pointer_normal:
        move.l ptr_normal,G_POINTER_DATA(a5)
        bra.s pointer
pointer_busy:
        move.l ptr_busy,G_POINTER_DATA(a5)
pointer:
        move.w #POINTER_HEIGHT,G_POINTER_H(a5)
        GCALL pointer
        rts

click_sound:
        move.w #CLICK_EFFECT,G_EFFECT(a5)
        GCALL sound
        rts

;============================================================================
; Text streams for the game's text routine (G_TEXT), built at A3: the
; display, then commands: 1 x y position, 4 left, 5 centred, 7 l t r b box
; (halved), 8 c colour, then characters; 0 ends. The font is proportional;
; '#' would print a number from the caller's stack, so it is never passed.

txt_start:
        lea stream,a3
        move.b #MENU,(a3)+
        rts

txt_box:                                ; the whole screen
        move.b #7,(a3)+
        clr.b (a3)+
        clr.b (a3)+
        move.b #320/2,(a3)+
        move.b #200/2,(a3)+
        rts

txt_left:                               ; D0 x, D1 y, D2 colour: left aligned
        bsr.s txt_box
        move.b #4,(a3)+
        move.b #1,(a3)+
        move.b d0,(a3)+
        move.b d1,(a3)+
        move.b #8,(a3)+
        move.b d2,(a3)+
        rts

txt_centre:                             ; D1 y: centred on the screen, colour 1
        move.l d2,-(sp)
        moveq #1,d2
        bsr.s txt_centre_colour
        move.l (sp)+,d2
        rts

txt_centre_colour:                      ; D1 y, D2 colour: centred on the screen
        move.b #7,(a3)+
        clr.b (a3)+
        lsr.w #1,d1
        move.b d1,(a3)+
        move.b #320/2,(a3)+
        move.b #200/2,(a3)+
        move.b #5,(a3)+
        move.b #8,(a3)+
        move.b d2,(a3)+
        rts

txt_centred_line:                       ; A0 text, D1 y
        bsr.s txt_centre
        ; fall through

txt_str:                                ; A0 zero-terminated text
.char:  move.b (a0)+,d0
        beq.s .end
        bsr.s txt_char
        bra.s .char
.end:   rts

txt_char:                               ; D0 a character the font has
        cmp.b #' ',d0
        blo.s .space
        cmp.b #'#',d0
        beq.s .space
        cmp.b #'z',d0
        bhi.s .space
        move.b d0,(a3)+
        rts
.space: move.b #' ',(a3)+
        rts

txt_field:                              ; A0 text of D2 characters, trailing spaces dropped
        movea.l a3,a1
        subq.w #1,d2
        bmi.s .trim
.char:  move.b (a0)+,d0
        beq.s .trim
        bsr.s txt_char
        dbra d2,.char
.trim:  cmpa.l a1,a3
        beq.s .done
        cmp.b #' ',-1(a3)
        bne.s .done
        subq.l #1,a3
        bra.s .trim
.done:  rts

; A0 text of D2 characters at most, as many as fit D3 pixels in the font
; (its widths at FONT_WIDTHS, as G_TEXT draws them), trailing spaces
; dropped. A longer text would run into the next column, or past the
; screen's right edge, where the game goes on at the left of the next line.
txt_fit:
        movem.l d4/a4,-(sp)
        movea.l font_widths,a4
        movea.l a3,a1
        subq.w #1,d2
        bmi.s .trim
.char:  move.b (a0)+,d0
        beq.s .trim
        bsr txt_char
        moveq #0,d4
        move.b -1(a3),d4
        sub.w #' ',d4
        move.b 0(a4,d4.w),d4
        sub.w d4,d3
        bmi.s .over
        dbra d2,.char
        bra.s .trim
.over:  subq.l #1,a3                    ; this one does not fit
.trim:  cmpa.l a1,a3
        beq.s .done
        cmp.b #' ',-1(a3)
        bne.s .done
        subq.l #1,a3
        bra.s .trim
.done:  movem.l (sp)+,d4/a4
        rts

txt_number:                             ; D0 an unsigned word, in decimal
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
        rts

txt_style:                              ; D0 a style: its name, capitalized
        movea.l style_table,a0
        lsl.w #3,d0
        adda.w d0,a0
        move.b (a0)+,d0
        cmp.b #'a',d0
        blo.s .first
        cmp.b #'z',d0
        bhi.s .first
        sub.b #'a'-'A',d0
.first: bsr txt_char
        moveq #7,d2
        bra txt_field

txt_draw:
        clr.b (a3)
        lea stream,a0
        GCALL text
        rts

;============================================================================
; The EDIT label on the title screen (five planes of 8000 bytes, 40 bytes a
; row): the four letters are copied out of the title's own buttons, the
; crossed-out button's face is cleared to its colour, and the letters are
; drawn back without their background.

draw_edit_label:
        movea.l title_bitmap,a0
        lea label_pixels,a2
        lea letters(pc),a3
        moveq #LETTERS-1,d7
.save:  movem.w (a3)+,d4-d6             ; source x, y, width
        addq.l #2,a3
        bsr copy_out
        dbra d7,.save
        moveq #BUTTON_COLOUR,d2
        move.w #LABEL_TOP,d1
.clear_row:
        moveq #LABEL_LEFT,d0
.clear: bsr set_pixel
        addq.w #1,d0
        cmp.w #LABEL_RIGHT+1,d0
        bne.s .clear
        addq.w #1,d1
        cmp.w #LABEL_BOTTOM+1,d1
        bne.s .clear_row
        lea label_pixels,a2
        lea letters(pc),a3
        moveq #LETTERS-1,d7
.paste: addq.l #4,a3
        move.w (a3)+,d6                 ; width
        move.w (a3)+,d4                 ; destination x
        move.w #LETTER_Y,d5
        bsr paste_in
        dbra d7,.paste
        rts

copy_out:                               ; D4 x, D5 y, D6 width: 12 rows to (A2)+
        move.l d7,-(sp)
        moveq #LETTER_ROWS-1,d7
.row:   move.w d4,d0
        movea.w d6,a4
.column:
        move.w d5,d1
        bsr get_pixel
        move.b d2,(a2)+
        addq.w #1,d0
        subq.w #1,a4
        cmpa.w #0,a4
        bne.s .column
        addq.w #1,d5
        dbra d7,.row
        move.l (sp)+,d7
        rts

paste_in:                               ; D4 x, D5 y, D6 width: 12 rows from (A2)+
        move.l d7,-(sp)
        moveq #LETTER_ROWS-1,d7
.row:   move.w d4,d0
        movea.w d6,a4
.column:
        move.w d5,d1
        move.b (a2)+,d2
        cmp.b #BUTTON_COLOUR,d2
        beq.s .skip
        bsr set_pixel
.skip:  addq.w #1,d0
        subq.w #1,a4
        cmpa.w #0,a4
        bne.s .column
        addq.w #1,d5
        dbra d7,.row
        move.l (sp)+,d7
        rts

pixel_address:                          ; D0 x, D1 y, A0 bitmap -> A1 byte, D3 bit
        move.w d1,d3
        mulu #40,d3
        movea.l a0,a1
        adda.l d3,a1
        move.w d0,d3
        lsr.w #3,d3
        adda.w d3,a1
        move.w d0,d3
        not.w d3
        and.w #7,d3
        rts

get_pixel:                              ; D0 x, D1 y, A0 bitmap -> D2 colour
        bsr.s pixel_address
        moveq #0,d2
        btst d3,4*PLANE(a1)
        beq.s .plane3
        bset #4,d2
.plane3:
        btst d3,3*PLANE(a1)
        beq.s .plane2
        bset #3,d2
.plane2:
        btst d3,2*PLANE(a1)
        beq.s .plane1
        bset #2,d2
.plane1:
        btst d3,PLANE(a1)
        beq.s .plane0
        bset #1,d2
.plane0:
        btst d3,(a1)
        beq.s .done
        bset #0,d2
.done:  rts

set_pixel:                              ; D0 x, D1 y, D2 colour, A0 bitmap
        bsr.s pixel_address
        btst #0,d2
        beq.s .clear0
        bset d3,(a1)
        bra.s .plane1
.clear0:
        bclr d3,(a1)
.plane1:
        btst #1,d2
        beq.s .clear1
        bset d3,PLANE(a1)
        bra.s .plane2
.clear1:
        bclr d3,PLANE(a1)
.plane2:
        btst #2,d2
        beq.s .clear2
        bset d3,2*PLANE(a1)
        bra.s .plane3
.clear2:
        bclr d3,2*PLANE(a1)
.plane3:
        btst #3,d2
        beq.s .clear3
        bset d3,3*PLANE(a1)
        bra.s .plane4
.clear3:
        bclr d3,3*PLANE(a1)
.plane4:
        btst #4,d2
        beq.s .clear4
        bset d3,4*PLANE(a1)
        rts
.clear4:
        bclr d3,4*PLANE(a1)
        rts

;============================================================================
; Texts

s_levels_dir:     dc.b "Levels",0
s_list_title:     dc.b "Custom Levels",0
s_list_help:      dc.b "Click a level, or use the cursor keys",0
s_no_level:       dc.b "There is no level yet: make one with New",0
s_damaged_only:   dc.b "A damaged file: only Rename or Delete",0
h_play_level:     dc.b "Play the selected level (P)",0
h_edit_level:     dc.b "Edit the selected level (E)",0
h_new_level:      dc.b "Make a new level (N)",0
h_rename_level:   dc.b "Give the selected file another name (R)",0
h_delete_level:   dc.b "Delete the selected file (Del)",0
h_back_title:     dc.b "Back to the title screen (Esc)",0
h_replay:         dc.b "Play the level again (R)",0
h_edit_again:     dc.b "Edit the level (E)",0
h_levels:         dc.b "Back to the list of levels (Esc)",0
h_create:         dc.b "Write the new level and edit it (Return)",0
h_no_new:         dc.b "Back to the list without a new level (Esc)",0
s_play_label:     dc.b "Play",0
s_new_label:      dc.b "New",0
s_create_label:   dc.b "Create",0
s_cancel_label:   dc.b "Cancel",0
s_new_title:      dc.b "New Level",0
s_new_credit:     dc.b "Editor "
                  EDITOR_VERSION
                  dc.b " by Timo Heimonen",0
s_name_label:     dc.b "File",0
s_style_label:    dc.b "Style",0
s_size_label:     dc.b "Size",0
s_lvl:            dc.b ".lvl",0
s_left_arrow:     dc.b "<  ",0
s_right_arrow:    dc.b "  >",0
s_by:             dc.b " x ",0
s_new_help:       dc.b "Type a name. Cursor keys: style and size",0
s_need_name:      dc.b "Type a name for the file first",0
s_list_full:      dc.b "The list is full: 512 levels",0
s_name_exists:    dc.b "There is a level of this name already",0
s_edit_label:     dc.b "Edit",0
s_back_label:     dc.b "Back",0
s_empty1:         dc.b "There are no levels in",0
s_empty2:         dc.b "the Levels directory yet",0
s_damaged:        dc.b "damaged",0
s_previous:       dc.b "< Previous",0
s_next:           dc.b "Next >",0
s_page_text:      dc.b "Page ",0
s_of_text:        dc.b " of ",0
s_saved1:         dc.b "You saved ",0
s_saved2:         dc.b " of ",0
s_saved3:         dc.b " Lemmings",0
s_none_saved:     dc.b "No Lemmings were saved",0
s_grade1:         dc.b "Grade ",0
s_grade2:         dc.b " of 3",0
s_hint1:          dc.b "Best grade: up to ",0
s_hint2:          dc.b " lost",0
s_replay_label:   dc.b "Replay",0
s_levels_label:   dc.b "Levels",0
s_result_help:    dc.b "Replay it, edit it, or back to the list",0
s_wrong_game:     dc.b "Editor: this is not the supported game",0
s_no_chip:        dc.b "Editor: not enough chip memory from the slave",0
s_tiles_file:     dc.b "data/EditorTiles",0
                even

; The game's sprite position words ($14DC) with the high bits of the
; first and last line, which the original leaves out: the pointer reaches
; the editor bar below line 255. Identical to the original above it.
; Jumped to from P_SPRITE_POS with D1 x, D2 y, D3 height and D1-D3 saved.
sprite_words:
        add.w #$2c,d2                   ; first line
        move.w d2,d0
        add.w d3,d0                     ; last line + 1
        add.w #$80,d1
        moveq #0,d3
        lsr.w #1,d1
        roxl.w #1,d3                    ; horizontal bit 0
        btst #8,d2
        beq.s .start
        addq.w #4,d3                    ; first line bit 8
.start: btst #8,d0
        beq.s .stop
        addq.w #2,d3                    ; last line bit 8
.stop:  lsl.w #8,d0
        or.w d0,d3                      ; SPRxCTL
        lsl.w #8,d2
        or.w d2,d1                      ; SPRxPOS
        move.w d1,d0
        swap d0
        move.w d3,d0
        movem.l (sp)+,d1-d3
        rts

        include "font.i"
        include "bar.s"
        include "edit.s"
        include "objects.s"
        include "level.s"
        include "undo.s"
        include "menu.s"
        include "files.s"

;============================================================================

        section editor_bss,bss

interface:                              ; as the slave passes it
resload_base:   ds.l 1
hunk0:          ds.l 1
hunk1:          ds.l 1
hunk2:          ds.l 1
hunk3:          ds.l 1
chip_base:      ds.l 1
chip_size:      ds.l 1

g_sound:        ds.l 1
g_stop_sound:   ds.l 1
g_pointer:      ds.l 1
g_wait_press:   ds.l 1
g_init_play:    ds.l 1
g_load_style:   ds.l 1
g_select_level: ds.l 1
g_count:        ds.l 1
g_protection:   ds.l 1
g_copper:       ds.l 1
g_fade:         ds.l 1
g_unpack_menu:  ds.l 1
g_show_menu:    ds.l 1
g_restore_rect: ds.l 1
g_text:         ds.l 1
g_sprite:       ds.l 1
r_title:        ds.l 1
r_build:        ds.l 1
r_result:       ds.l 1
r_escape_test:  ds.l 1
r_after_tab:    ds.l 1
g_video:        ds.l 1
r_release:      ds.l 1
r_opening:      ds.l 1
r_opened:       ds.l 1
font_widths:    ds.l 1
r_crosses_done: ds.l 1
r_title_again:  ds.l 1
        ifd PAL_RELEASE
r_next_column:  ds.l 1
        endif
level_header:   ds.l 1
style_table:    ds.l 1
pal_black:      ds.l 1
pal_menu:       ds.l 1
cop_title:      ds.l 1
cop_menu:       ds.l 1
ptr_normal:     ds.l 1
ptr_busy:       ds.l 1
title_bitmap:   ds.l 1
g_wait_play:    ds.l 1
g_scroll:       ds.l 1
g_copy_view:    ds.l 1
g_view_desc:    ds.l 1
g_objects:      ds.l 1
g_redraw:       ds.l 1
g_buttons:      ds.l 1
g_key:          ds.l 1
g_play_pointer: ds.l 1
g_planes:       ds.l 1
g_wait_frame:   ds.l 1
g_music_off:    ds.l 1
g_music_on:     ds.l 1
g_idle:         ds.l 1
r_loop_rest:    ds.l 1
scroll_flags:   ds.l 1
pal_play:       ds.l 1
ptr_cross:      ds.l 1
bar_copper:     ds.l 1
bar_bitmap:     ds.l 1
g_find_type:    ds.l 1
g_expand_objects: ds.l 1
g_border_clear: ds.l 1
placements:     ds.l 1
g_picker:       ds.l 1
g_panel:        ds.l 1
g_panel_slot:   ds.l 1
g_panel_count:  ds.l 1
g_clock:        ds.l 1
g_frame_end:    ds.l 1

; The state block, with its fields at fixed offsets, for external tools
; that read it from memory (its address follows "L2ED").
state:
custom_active:  ds.b 1                  ; +0 a custom level is being played
session_open:   ds.b 1                  ; +1 tribe, index and record kept aside
from_title:     ds.b 1                  ; +2 the list was opened from the title
screen:         ds.b 1                  ; +3 the page shown: SCREEN_LIST..SCREEN_RENAME
entry_count:    ds.w 1                  ; +4
selected:       ds.w 1                  ; +6
current_page:   ds.w 1                  ; +8
saved_tribe:    ds.w 1                  ; +10
saved_index:    ds.w 1                  ; +12
editing:        ds.b 1                  ; +14 a level is open in the edit view
edit_page:      ds.b 1                  ; +15 0 edit, 1 pieces, 2 question,
                                        ; 3 types, 4 title, 5 limits
dirty:          ds.b 1                  ; +16 unsaved changes
erase:          ds.b 1                  ; +17 the brush erases
pick:           ds.b 1                  ; +18 the next click picks a tile
brush_decor:    ds.b 1                  ; +19 the brush writes cell bit 30
brush_steel:    ds.b 1                  ; +20 the brush writes cell bit 28
leaving:        ds.b 1                  ; +21 the edit view ends after this pass
brush_index:    ds.w 1                  ; +22 the brush's piece, -1 a single tile
sheet_top:      ds.w 1                  ; +24 the pieces page's first row
cells_written:  ds.w 1                  ; +26 cells the tools changed
mode:           ds.b 1                  ; +28 0 Terrain, 1 Objects
dragging:       ds.b 1                  ; +29 the selected object follows the pointer
obj_type:       ds.w 1                  ; +30 the type a click places
sel_slot:       ds.w 1                  ; +32 the selected object's place, -1 none
hover_slot:     ds.w 1                  ; +34 the object under the pointer, -1 none
page_top:       ds.w 1                  ; +36 the object page's first row
object_count:   ds.w 1                  ; +38 places in use
warnings:       ds.w 1                  ; +40 bits W_NO_ENTRANCE..W_POOL
link_count:     ds.w 1                  ; +42 links the game will allocate
pool_total:     ds.l 1                  ; +44 bytes of the game's object pool
type_count:     ds.w 1                  ; +48 the style's object types
level_slot:     ds.w 1                  ; +50 the Param mode's skill slot
new_style:      ds.w 1                  ; +52 the New page's style
new_shape:      ds.w 1                  ; +54 and map shape
resuming:       ds.b 1                  ; +56 the edit view is built again
skills_wanted:  ds.b 1                  ; +57 the picker after this pass
new_length:     ds.b 1                  ; +58 the New page's name
                even
new_name:       ds.b NEW_NAME_MAX+2     ; +60
new_file:       ds.b NEW_NAME_MAX+6
new_message:    ds.l 1                  ; +108
result_grade:   ds.b 1                  ; +112 the result page's grade
touched:        ds.b 1                  ; +113 the record changed: a step
step_count:     ds.w 1                  ; +114 undo steps kept
hist_pos:       ds.w 1                  ; +116 the state shown: 0 the oldest
testing:        ds.b 1                  ; +118 test play of the edited record
test_wanted:    ds.b 1                  ; +119 test play after this pass
ask_on_entry:   ds.b 1                  ; +120 the leave question on return
question_kind:  ds.b 1                  ; +121 what the bar's question asks
limit_words:    ds.w 6                  ; +122 the limits page's scroll words
page_read:      ds.w 1                  ; +134 the list's page in entries, or -1
anim_tick:      ds.w 1                  ; +136 passes the preview or the object
                                        ; page has animated; frame = tick mod frames

play_style:     ds.w 1
names_left:     ds.w 1
row_y:          ds.w 1
row_colour:     ds.w 1
next_name:      ds.l 1
path:           ds.b 64
label_pixels:   ds.b (14+14+6+14)*LETTER_ROWS
                cnop 0,4
stream:         ds.b 2048
names:          ds.b NAMES_SIZE
order:          ds.w MAX_LEVELS             ; the listed names' offsets in names
entries:        ds.b ROWS*ENTRY_SIZE        ; the levels of the page page_read
record_buffer:  ds.b RECORD_SIZE
saved_record:   ds.b RECORD_SIZE
