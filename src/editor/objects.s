; Lemmings 2: The Tribes In-Game Level Editor V1.1
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; The Objects mode of the edit view: the level's object placements placed,
; moved and deleted in the game's own view, their repeat counts, the object
; page and the warnings about the level's objects. The edit view (edit.s)
; calls types_init when a level is opened for editing, and this file's
; input, drawing, status, help and button routines while the Objects mode
; or the object page is shown. objects_apply makes the game's objects again
; from the record when the view opens and after an object edit, a terrain
; edit (edit.s), an undo or a redo (undo.s); Save and Test name the level's
; first warning (first_warning).
;
; The record's L2BO holds 64 placements of five little-endian words: type
; (negative: an empty place), x, y and the two repeat counts. An object
; edit changes the record, then rebuilds what the game made of the
; placements (objects_apply): their big-endian copy in hunk 0 (as the
; level parser leaves it), the play map restored from the record's cells,
; the border cleared as the level start does ($D23A) and the game's own
; object expansion run again ($C584: link table and object pool cleared,
; placements expanded into the map and the pool, behaviours initialised).
; Cells that changed are marked with bit 31, and the game redraws them.
;
; The editor also expands placements itself (expand, the rules of $C5BC)
; to know what each object covers: outlines, the object under the pointer,
; previews, the limits and the warnings. Placement order matters to the
; game and is kept: entrances release lemmings in turn ($9AC2), teleporters
; pair in order ($C9C0) and switch n toggles switch target n ($C950, $C96A,
; $9F90). A new object takes the first empty place after the last object;
; a deleted one leaves its place empty.
;
; Each of the style's types gets a role from what the game's code does with
; it (classify); the roles group the object page and name the objects in
; the status line.
;
; The type that follows the pointer and the types on the object page are
; animated: each part shows frame anim_tick mod its frame count, as the
; game's $CA62 steps every animated component once a pass and wraps it at
; its count. anim_tick counts the passes that drew them. The level's own
; objects stay paused at the frame the build left them.
;
; Game addresses are offsets in the game's hunk 0. A5 is the game's globals
; and A6 $dff000, as everywhere in the editor.

; Game routines, hunk 0
G_FIND_TYPE     equ $0c67c      ; D0 a type -> A0 its L2OB definition
G_EXPAND_OBJECTS equ $0c584     ; link table and pool cleared, objects expanded
G_BORDER_CLEAR  equ $0d23a      ; the map's border cells cleared
PLACEMENTS      equ $1bdb4      ; the 64 placements the game expands

; Game globals (A5)
G_COMMON_SPRITES equ $23e       ; sprite animations of graphic bit 14
G_STYLE_SPRITES equ $246        ; the style's sprite animations (L2SI)
G_BLOCK_ANIMS   equ $252        ; the style's block animations (L2BI)

; The record's placements
R_OBJECTS       equ $1f48       ; L2BO payload
SLOTS           equ 64
SLOT_SIZE       equ 10
PLACEMENT_WORDS equ SLOTS*SLOT_SIZE/2
MAP_CELLS       equ 1971

; L2OB definitions: N, behaviour, eight parameter words, then N parts of
; flags, dx, dy, attributes (long), graphic.
DEF_BEHAVIOUR   equ 2
DEF_PARAM3      equ 10
DEF_PARTS       equ 20
PART_SIZE       equ 12
GRAPHIC_CELL    equ $8000       ; a part that only ORs attributes into a cell
PART_SPRITE     equ 13          ; graphic bit: a sprite, no cells
PART_COMMON     equ 14          ; graphic bit: from the common sprites

; The game's limits
POOL_SIZE       equ 4096        ; the object pool $1AC34..$1BC34
INSTANCE_SIZE   equ 22          ; an expanded object, then its components
COMPONENT_SIZE  equ 8
POOL_END        equ 4           ; the pool's end mark
LINKS_MAX       equ 64          ; $C74E
ENTRANCES_MAX   equ 4           ; $C8F6
SWITCHES_MAX    equ 32          ; $C954, $C96A

; Behaviour ids ($C7D4)
B_ENTRANCE      equ 2
B_LAUNCHER      equ 12
B_SWITCH        equ 13
B_TELEPORTER    equ 14
B_TARGET        equ 15

; The editor's limits
MAX_TYPES       equ 32          ; 12 to 23 in the shipped styles
MAX_PARTS       equ 512         ; parts of one expansion kept
MAX_STEPS       equ 4096        ; parts of one expansion counted
MAX_REPEAT      equ 40          ; the shipped levels use up to 18

; Roles, from the game's code that acts on a type (classify)
ROLE_ENTRANCE   equ 0
ROLE_EXIT       equ 1
ROLE_WATER      equ 2
ROLE_TRAP       equ 3
ROLE_HAZARD     equ 4
ROLE_LAUNCHER   equ 5
ROLE_BOUNCER    equ 6
ROLE_SWITCH     equ 7
ROLE_TARGET     equ 8
ROLE_TELEPORTER equ 9
ROLE_SWINGING   equ 10
ROLE_DEVICE     equ 11
ROLE_ICE        equ 12
ROLE_SCENERY    equ 13
NO_ROLE         equ $ff         ; an empty place
GROUPS          equ 5           ; the object page's groups

; What the game numbers or pairs
KIND_NONE       equ 0
KIND_ENTRANCE   equ 1
KIND_SWITCH     equ 2
KIND_TARGET     equ 3
KIND_TELEPORTER equ 4

; Warnings, bits of warnings
W_NO_ENTRANCE   equ 0
W_ENTRANCES     equ 1
W_NO_EXIT       equ 2
W_TELEPORTER    equ 3
W_SWITCH        equ 4
W_LINKS         equ 5
W_POOL          equ 6
WARNING_COUNT   equ 7

; A type's entry in types
T_DEF           equ 0           ; its definition
T_BOX           equ 4           ; x0, y0, x1, y1 from the origin, no repeats,
                                ; first frames
T_PAGE_X        equ 12          ; the object page: its box's left
T_ROW           equ 14          ; and row
T_ORG_X         equ 16          ; the origin in its page box, which holds
T_ORG_Y         equ 18          ; every frame
T_W             equ 20          ; the page box's size
T_H             equ 22
T_ROLE          equ 24
T_REPEAT        equ 25          ; bit 0 repeats across, bit 1 down
T_GROUP         equ 26
TYPE_SIZE       equ 28

; The object page
PAGE_LEFT       equ 16
PAGE_RIGHT      equ 304
PAGE_TOP        equ 8
TYPE_GAP        equ 16
GROUP_GAP       equ 32
ROW_GAP         equ 8
PAGE_ROWS_MAX   equ 32
HOLD_PASSES     equ 3           ; a held -/+ button repeats after these

        section editor,code

;============================================================================
; The style's object types

; At the start of editing: each type's definition, role, box, and the
; object page's layout.
types_init:
        movem.l d0-d7/a0-a4,-(sp)
        moveq #0,d0
        GCALL find_type                 ; -> A0 type 0, after L2OB's count
        move.w -2(a0),d7
        cmp.w #MAX_TYPES,d7
        bls .count
        moveq #MAX_TYPES,d7
.count: move.w d7,type_count
        lea types,a3
        subq.w #1,d7
        bmi .layout
.type:  move.l a0,T_DEF(a3)
        bsr classify                    ; -> D0 role, D1 repeat bits
        move.b d0,T_ROLE(a3)
        move.b d1,T_REPEAT(a3)
        lea role_groups(pc),a1
        move.b 0(a1,d0.w),T_GROUP(a3)
        moveq #0,d0
        moveq #0,d1
        moveq #0,d2
        moveq #0,d3
        bsr expand
        lea T_BOX(a3),a1
        bsr parts_box
        st all_frames                   ; the page box: room for every frame
        lea page_box,a1
        bsr parts_box
        sf all_frames
        ; in its page box: the origin's x on a word, its y on a cell row
        move.w (a1),d0
        and.w #-16,d0
        neg.w d0
        move.w d0,T_ORG_X(a3)
        add.w 4(a1),d0
        add.w #15,d0
        and.w #-16,d0
        move.w d0,T_W(a3)
        move.w 2(a1),d0
        and.w #-8,d0
        neg.w d0
        move.w d0,T_ORG_Y(a3)
        add.w 6(a1),d0
        addq.w #7,d0
        and.w #-8,d0
        move.w d0,T_H(a3)
        move.w (a0),d0                  ; the next definition
        mulu #PART_SIZE,d0
        lea DEF_PARTS(a0,d0.l),a0
        lea TYPE_SIZE(a3),a3
        dbra d7,.type
.layout:
        bsr types_layout
        movem.l (sp)+,d0-d7/a0-a4
        rts

; A0 a definition -> D0 its role, D1 bit 0: it repeats across, bit 1:
; down. The roles follow what the game's code does with a type: the
; entrance by its behaviour (2, registered at $C8F2); exit, water and ice
; by the direct effect of its cells (bit 12 alone, effect 0, 1 or 2 in
; bits 22..27, read at $9DCE); switch targets by their behaviour (15,
; $C96A); a type of behaviour 0 with links swings ($2F8C); then the lowest
; link effect the game dispatches ($9E3E).
classify:
        movem.l d2-d7/a0-a1,-(sp)
        moveq #0,d1
        moveq #0,d4                     ; link effects 0..15
        moveq #0,d5                     ; direct effects 0..15
        move.w DEF_BEHAVIOUR(a0),d6
        move.w (a0),d7
        lea DEF_PARTS(a0),a0
        subq.w #1,d7
        bmi .roles
.part:  move.w (a0),d2                  ; flags
        btst #13,d2
        beq .down
        bset #0,d1
.down:  btst #12,d2
        beq .link
        bset #1,d1
.link:  btst #11,d2
        beq .direct
        moveq #0,d3
        move.b d2,d3
        cmp.w #16,d3
        bhs .direct
        bset d3,d4
.direct:
        move.l 6(a0),d3                 ; attributes
        move.l d3,d0
        and.l #$1800,d0
        cmp.l #$1000,d0
        bne .next
        moveq #22,d0
        lsr.l d0,d3
        and.w #63,d3
        cmp.w #16,d3
        bhs .next
        bset d3,d5
.next:  lea PART_SIZE(a0),a0
        dbra d7,.part
.roles: moveq #ROLE_ENTRANCE,d0
        cmp.w #B_ENTRANCE,d6
        beq .out
        moveq #ROLE_EXIT,d0
        btst #0,d5
        bne .out
        moveq #ROLE_WATER,d0
        btst #1,d5
        bne .out
        moveq #ROLE_ICE,d0
        btst #2,d5
        bne .out
        moveq #ROLE_TARGET,d0
        cmp.w #B_TARGET,d6
        beq .out
        moveq #ROLE_SWINGING,d0
        tst.w d6
        bne .links
        tst.w d4
        bne .out
.links: lea link_roles(pc),a1
        moveq #0,d2
.effect:
        btst d2,d4
        beq .effect_next
        moveq #0,d0
        move.b 0(a1,d2.w),d0
        bpl .out
.effect_next:
        addq.w #1,d2
        cmp.w #16,d2
        blo .effect
        moveq #ROLE_SCENERY,d0
.out:   movem.l (sp)+,d2-d7/a0-a1
        rts

; The object page: the types in rows, group after group (entrances, exits,
; water, traps and devices, scenery), each box at its own size.
types_layout:
        movem.l d0-d7/a0-a1,-(sp)
        clr.w page_top
        clr.w page_max_top
        clr.w page_rows
        tst.w type_count
        beq .out
        move.w #PAGE_LEFT,d4            ; x
        moveq #0,d5                     ; the row's y
        moveq #0,d6                     ; the row's height
        moveq #0,d7                     ; the row
        lea page_row_y,a1
        clr.w (a1)
        moveq #0,d3                     ; the group
.group: lea types,a0
        moveq #0,d2                     ; the type
        move.w #GROUP_GAP,d1            ; the gap before the group's first
.type:  cmp.w type_count,d2
        bhs .group_done
        cmp.b T_GROUP(a0),d3
        bne .next
.room:  cmp.w #PAGE_LEFT,d4
        bne .fits
        moveq #0,d1                     ; first in its row: no gap
.fits:  move.w d4,d0
        add.w d1,d0
        add.w T_W(a0),d0
        cmp.w #PAGE_RIGHT,d0
        bls .place
        cmp.w #PAGE_LEFT,d4
        beq .place                      ; wider than the page: alone
        cmp.w #PAGE_ROWS_MAX-1,d7
        bhs .place
        add.w d6,d5                     ; a new row
        addq.w #ROW_GAP,d5
        moveq #0,d6
        addq.w #1,d7
        move.w d7,d0
        add.w d0,d0
        move.w d5,0(a1,d0.w)
        move.w #PAGE_LEFT,d4
        bra .room
.place: add.w d1,d4
        move.w d4,T_PAGE_X(a0)
        move.w d7,T_ROW(a0)
        add.w T_W(a0),d4
        cmp.w T_H(a0),d6
        bhs .height
        move.w T_H(a0),d6
.height:
        move.w d7,d0
        add.w d0,d0
        move.w d6,2*PAGE_ROWS_MAX(a1,d0.w)      ; page_row_h
        move.w #TYPE_GAP,d1
.next:  addq.w #1,d2
        lea TYPE_SIZE(a0),a0
        bra .type
.group_done:
        addq.w #1,d3
        cmp.w #GROUPS,d3
        blo .group
        addq.w #1,d7
        move.w d7,page_rows
        ; the first row from which the rest fits on the page
        subq.w #1,d7
        add.w d7,d7
        move.w 0(a1,d7.w),d0
        add.w 2*PAGE_ROWS_MAX(a1,d7.w),d0       ; the bottom of the last row
        add.w #PAGE_TOP,d0
        moveq #0,d1
.fit:   move.w d0,d2
        move.w d1,d3
        add.w d3,d3
        sub.w 0(a1,d3.w),d2
        cmp.w #SCREEN_ROWS,d2
        bls .fitted
        addq.w #1,d1
        cmp.w page_rows,d1
        blo .fit
        subq.w #1,d1
.fitted:
        move.w d1,page_max_top
.out:   movem.l (sp)+,d0-d7/a0-a1
        rts

; D1 a type -> A0 its entry in types. Preserves all other registers.
type_entry:
        move.l d1,-(sp)
        mulu #TYPE_SIZE,d1
        lea types,a0
        adda.l d1,a0
        move.l (sp)+,d1
        rts

;============================================================================
; Expanding a placement as the game does

; A0 a definition, D0 x, D1 y, D2 and D3 the repeat counts across and down
; -> its parts in parts (x, y, graphic, flags each; at most MAX_PARTS
; kept, part_count counts all), the links its cells allocate in part_links.
; The rules of $C5BC, literally: flag bit 15 keeps x, bit 14 keeps y,
; bits 14 and 13 together skip dy, bit 13 repeats the part across, bit 12
; down (the across count restored for each row), and after a vertical
; repeat the same part is read again for the parts left. Preserves all.
expand:
        movem.l d0-d7/a0-a2,-(sp)
        clr.w part_count
        clr.w part_links
        lea parts,a1
        move.w d0,origin_x
        move.w d1,origin_y
        move.w d2,saved_across
        move.w d2,d5
        move.w d3,d6
        move.w #MAX_STEPS,steps_left
        move.w (a0),d7
        lea DEF_PARTS(a0),a0
        subq.w #1,d7
        bmi .done
.part:  subq.w #1,steps_left
        bmi .done
        move.w (a0)+,d2                 ; flags
        btst #15,d2
        bne .x
        move.w origin_x,d0
.x:     add.w (a0)+,d0
        btst #14,d2
        beq .y_reset
        btst #13,d2
        beq .y_add
        addq.l #2,a0
        bra .y_done
.y_reset:
        move.w origin_y,d1
.y_add: add.w (a0)+,d1
.y_done:
        addq.l #4,a0                    ; attributes
        move.w (a0)+,d4                 ; graphic
        bsr emit
        btst #13,d2
        beq .down
        subq.w #1,d5
        bmi .down
        lea -PART_SIZE(a0),a0
        bra .part
.down:  btst #12,d2
        beq .next
        move.w origin_x,d0
        lea -PART_SIZE(a0),a0
        btst #13,d2
        beq .again
        add.w 4(a0),d1
.again: move.w saved_across,d5
        subq.w #1,d6
        bpl .part
.next:  dbra d7,.part
.done:  movem.l (sp)+,d0-d7/a0-a2
        rts

; One part at D0 x, D1 y, graphic D4, flags D2 into parts (A1) while there
; is room; the links its cells allocate counted: $C71C allocates one for
; each cell written when flag bit 11 is set and bit 10 (reuse the last
; link) is not; sprites write no cells.
emit:
        addq.w #1,part_count
        cmp.w #MAX_PARTS,part_count
        bhi .links
        move.w d0,(a1)+
        move.w d1,(a1)+
        move.w d4,(a1)+
        move.w d2,(a1)+
.links: btst #PART_SPRITE,d4
        bne .out
        btst #10,d2
        bne .out
        btst #11,d2
        beq .out
        moveq #1,d3
        cmp.w #GRAPHIC_CELL,d4
        beq .add
        move.l a2,-(sp)
        bsr block_anim
        move.w 2(a2),d3
        mulu 4(a2),d3
        movea.l (sp)+,a2
.add:   add.w d3,part_links
.out:   rts

; -> D0 the parts of the last expansion kept in parts.
parts_kept:
        move.w part_count,d0
        cmp.w #MAX_PARTS,d0
        bls .out
        move.w #MAX_PARTS,d0
.out:   rts

; D4 a block animation's graphic -> A2 its L2BA record (frame count, width,
; height in cells, frame pointers), as $C6BA does. Preserves all else.
block_anim:
        move.l d4,-(sp)
        movea.l G_BLOCK_ANIMS(a5),a2
        and.w #$ff,d4
        lsl.w #2,d4
        movea.l 2(a2,d4.w),a2
        move.l (sp)+,d4
        rts

; D4 a sprite's graphic -> A2 its animation (frame count, frame pointers),
; as $CABC and $10ABC find it. Preserves all else.
sprite_anim:
        move.l d4,-(sp)
        movea.l G_STYLE_SPRITES(a5),a2
        btst #PART_COMMON,d4
        beq .style
        movea.l G_COMMON_SPRITES(a5),a2
.style: and.w #$ff,d4
        lsl.w #2,d4
        movea.l 0(a2,d4.w),a2
        move.l (sp)+,d4
        rts

; D4 a sprite's graphic -> A2 its first frame's descriptor (dx, dy, width,
; height, ...). Preserves all else.
sprite_frame:
        bsr sprite_anim
        movea.l 2(a2),a2
        rts

; D4 a sprite's graphic, D0 dx, D1 dy, D2 width, D3 height of its first
; frame -> the same for the rectangle all its frames cover. Preserves all
; else.
sprite_extent:
        movem.l d4-d7/a2-a3,-(sp)
        add.w d0,d2                     ; right
        add.w d1,d3                     ; bottom
        bsr sprite_anim
        move.w (a2),d7
        addq.l #6,a2                    ; the second frame's pointer
        subq.w #2,d7
        bmi .done
.frame: movea.l (a2)+,a3
        move.w (a3),d4
        cmp.w d4,d0
        ble .top
        move.w d4,d0
.top:   move.w 2(a3),d5
        cmp.w d5,d1
        ble .right
        move.w d5,d1
.right: add.w 4(a3),d4
        cmp.w d4,d2
        bge .bottom
        move.w d4,d2
.bottom:
        add.w 6(a3),d5
        cmp.w d5,d3
        bge .next
        move.w d5,d3
.next:  dbra d7,.frame
.done:  sub.w d0,d2
        sub.w d1,d3
        movem.l (sp)+,d4-d7/a2-a3
        rts

; A2 an animation, its frame count first -> D5 the frame the preview and
; the object page show: anim_tick modulo the count. Preserves all else.
anim_frame:
        moveq #0,d5
        cmp.w #1,(a2)
        bls .out
        move.w anim_tick,d5
        divu (a2),d5
        clr.w d5
        swap d5
.out:   rts

; A1 a part -> D0 x, D1 y, D2 width, D3 height it covers in the map: the
; cells of a block animation's first frame, the cell of an attributes part,
; a sprite's first frame, or with all_frames set the rectangle all the
; sprite's frames cover (a block animation's frames are all one size).
; Preserves the other registers.
part_rect:
        movem.l d4/a2,-(sp)
        move.w 4(a1),d4
        btst #PART_SPRITE,d4
        bne .sprite
        move.w (a1),d0
        and.w #-16,d0
        move.w 2(a1),d1
        and.w #-8,d1
        moveq #16,d2
        moveq #8,d3
        cmp.w #GRAPHIC_CELL,d4
        beq .out
        bsr block_anim
        move.w 2(a2),d2
        lsl.w #CELL_SHIFT_X,d2
        move.w 4(a2),d3
        lsl.w #CELL_SHIFT_Y,d3
        bra .out
.sprite:
        bsr sprite_frame
        move.w (a2),d0
        move.w 2(a2),d1
        move.w 4(a2),d2
        move.w 6(a2),d3
        tst.b all_frames
        beq .place
        bsr sprite_extent
.place: add.w (a1),d0
        add.w 2(a1),d1
.out:   movem.l (sp)+,d4/a2
        rts

; The parts of the last expansion -> their bounding box at A1: x0, y0, x1,
; y1 (x1 and y1 past the end). Preserves all.
parts_box:
        movem.l d0-d7/a0-a1,-(sp)
        movea.l a1,a0
        move.w #$7fff,d4
        move.w d4,d5
        move.w #-$8000,d6
        move.w d6,d7
        lea parts,a1
        bsr parts_kept
        move.w d0,-(sp)
        bra .test
.part:  bsr part_rect
        cmp.w d4,d0
        bge .top
        move.w d0,d4
.top:   cmp.w d5,d1
        bge .right
        move.w d1,d5
.right: add.w d0,d2
        cmp.w d6,d2
        ble .bottom
        move.w d2,d6
.bottom:
        add.w d1,d3
        cmp.w d7,d3
        ble .next
        move.w d3,d7
.next:  addq.l #8,a1
.test:  subq.w #1,(sp)
        bpl .part
        addq.l #2,sp
        cmp.w #$7fff,d4
        bne .found
        moveq #0,d4                     ; nothing: one cell
        moveq #0,d5
        moveq #16,d6
        moveq #8,d7
.found: movem.w d4-d7,(a0)
        movem.l (sp)+,d0-d7/a0-a1
        rts

;============================================================================
; The record's placements

; D0 a place -> A0 its placement in the record. Preserves all else.
slot_address:
        move.l d0,-(sp)
        lea edit_record+R_OBJECTS,a0
        mulu #SLOT_SIZE,d0
        adda.l d0,a0
        move.l (sp)+,d0
        rts

; D0 a place -> D1 type (N set when the place is empty), D2 x, D3 y, D4
; and D5 the repeat counts across and down. Preserves all else.
get_slot:
        move.l a0,-(sp)
        bsr slot_address
        move.w (a0)+,d1
        rol.w #8,d1
        move.w (a0)+,d2
        rol.w #8,d2
        move.w (a0)+,d3
        rol.w #8,d3
        move.w (a0)+,d4
        rol.w #8,d4
        move.w (a0)+,d5
        rol.w #8,d5
        movea.l (sp)+,a0
        tst.w d1
        rts

; D0 a place, D1..D5 as get_slot returns them: into the record. Preserves
; all.
put_slot:
        movem.l d1-d5/a0,-(sp)
        bsr slot_address
        rol.w #8,d1
        move.w d1,(a0)+
        rol.w #8,d2
        move.w d2,(a0)+
        rol.w #8,d3
        move.w d3,(a0)+
        rol.w #8,d4
        move.w d4,(a0)+
        rol.w #8,d5
        move.w d5,(a0)+
        movem.l (sp)+,d1-d5/a0
        rts

; D0 a place -> its object's expansion in parts; none for an empty place
; or an unknown type. Preserves all.
expand_slot:
        movem.l d0-d5/a0,-(sp)
        clr.w part_count
        bsr get_slot
        bmi .out
        cmp.w type_count,d1
        bhs .out
        bsr type_entry
        movea.l T_DEF(a0),a0
        move.w d2,d0
        move.w d3,d1
        move.w d4,d2
        move.w d5,d3
        bsr expand
.out:   movem.l (sp)+,d0-d5/a0
        rts

; -> D0 the place for a new object: the first empty one after the last
; object, else the first empty one; -1 (N set) when all are used.
free_slot:
        movem.l d1-d5,-(sp)
        moveq #SLOTS-1,d0
.last:  bsr get_slot
        bpl .after
        dbra d0,.last
        moveq #0,d0                     ; no objects at all
        bra .out
.after: addq.w #1,d0
        cmp.w #SLOTS,d0
        blo .out
        moveq #0,d0
.first: bsr get_slot
        bmi .out
        addq.w #1,d0
        cmp.w #SLOTS,d0
        blo .first
        moveq #-1,d0
.out:   movem.l (sp)+,d1-d5
        tst.w d0
        rts

;============================================================================
; What the level's objects are

; Every place's object: its role, box and what the game numbers or pairs,
; the pool and links the game will need, and the warnings.
objects_scan:
        movem.l d0-d7/a0-a3,-(sp)
        clr.w object_count
        moveq #POOL_END,d0
        move.l d0,pool_total
        clr.w link_count
        clr.w entrance_count
        clr.w exit_count
        clr.w switch_count
        clr.w target_count
        move.w #-1,open_teleporter
        moveq #0,d7                     ; the place
.slot:  lea slot_role,a2
        move.b #NO_ROLE,0(a2,d7.w)
        lea slot_kind,a2
        clr.b 0(a2,d7.w)
        lea slot_number,a2
        clr.b 0(a2,d7.w)
        lea slot_partner,a2
        st 0(a2,d7.w)
        lea slot_box,a2
        move.w d7,d0
        lsl.w #3,d0
        clr.l 0(a2,d0.w)
        clr.l 4(a2,d0.w)
        move.w d7,d0
        bsr get_slot
        bmi .next
        cmp.w type_count,d1
        bhs .next
        move.w d1,d6                    ; the type
        bsr expand_slot
        addq.w #1,object_count
        moveq #0,d0
        move.w part_count,d0
        mulu #COMPONENT_SIZE,d0
        add.l #INSTANCE_SIZE,d0
        add.l d0,pool_total
        move.w part_links,d0
        add.w d0,link_count
        lea slot_box,a1
        move.w d7,d0
        lsl.w #3,d0
        adda.w d0,a1
        bsr parts_box
        move.w d6,d1
        bsr type_entry
        lea slot_role,a2
        move.b T_ROLE(a0),d0
        move.b d0,0(a2,d7.w)
        cmp.b #ROLE_EXIT,d0
        bne .behaviour
        addq.w #1,exit_count
.behaviour:
        movea.l T_DEF(a0),a1
        move.w DEF_BEHAVIOUR(a1),d0
        cmp.w #B_ENTRANCE,d0
        beq .entrance
        cmp.w #B_SWITCH,d0
        beq .switch
        cmp.w #B_TELEPORTER,d0
        beq .teleporter
        cmp.w #B_TARGET,d0
        beq .target
        cmp.w #B_LAUNCHER,d0
        bne .next
        btst #1,DEF_PARAM3+1(a1)        ; $CA08: bit 1 clear, a target too
        bne .next
        bra .target
.entrance:
        addq.w #1,entrance_count
        moveq #KIND_ENTRANCE,d1
        move.w entrance_count,d0
        bra .number
.switch:
        move.w switch_count,d0
        cmp.w #SWITCHES_MAX,d0
        bhs .next
        lea switch_slots,a2
        move.b d7,0(a2,d0.w)
        addq.w #1,switch_count
        moveq #KIND_SWITCH,d1
        bra .number
.target:
        move.w target_count,d0
        cmp.w #SWITCHES_MAX,d0
        bhs .next
        lea target_slots,a2
        move.b d7,0(a2,d0.w)
        addq.w #1,target_count
        moveq #KIND_TARGET,d1
.number:
        lea slot_number,a2
        move.b d0,0(a2,d7.w)
        lea slot_kind,a2
        move.b d1,0(a2,d7.w)
        bra .next
.teleporter:
        lea slot_kind,a2
        move.b #KIND_TELEPORTER,0(a2,d7.w)
        move.w open_teleporter,d0
        bpl .pair
        move.w d7,open_teleporter
        bra .next
.pair:  lea slot_partner,a2
        move.b d0,0(a2,d7.w)
        move.b d7,0(a2,d0.w)
        move.w #-1,open_teleporter
.next:  addq.w #1,d7
        cmp.w #SLOTS,d7
        blo .slot
        ; switch n and target n
        move.w switch_count,d0
        cmp.w target_count,d0
        bls .pairs
        move.w target_count,d0
.pairs: lea switch_slots,a0
        lea target_slots,a1
        lea slot_partner,a2
        moveq #0,d1
        bra .pair_test
.pair_next:
        moveq #0,d2
        move.b 0(a0,d1.w),d2            ; the switch
        moveq #0,d3
        move.b 0(a1,d1.w),d3            ; its target
        move.b d3,0(a2,d2.w)
        move.b d2,0(a2,d3.w)
        addq.w #1,d1
.pair_test:
        cmp.w d0,d1
        blo .pair_next
        ; the warnings
        moveq #0,d0
        tst.w entrance_count
        bne .entrances
        bset #W_NO_ENTRANCE,d0
.entrances:
        cmp.w #ENTRANCES_MAX,entrance_count
        bls .exit
        bset #W_ENTRANCES,d0
.exit:  tst.w exit_count
        bne .teleporters
        bset #W_NO_EXIT,d0
.teleporters:
        tst.w open_teleporter
        bmi .switches
        bset #W_TELEPORTER,d0
.switches:
        move.w switch_count,d1
        cmp.w target_count,d1
        bls .links
        bset #W_SWITCH,d0
.links: cmp.w #LINKS_MAX,link_count
        bls .pool
        bset #W_LINKS,d0
.pool:  cmp.l #POOL_SIZE,pool_total
        bls .warned
        bset #W_POOL,d0
.warned:
        move.w d0,warnings
        ; a selected object or one under the pointer that is gone: none
        lea slot_role,a0
        move.w sel_slot,d0
        bmi.s .hover
        cmp.b #NO_ROLE,0(a0,d0.w)
        bne.s .hover
        move.w #-1,sel_slot
        sf dragging
.hover: move.w hover_slot,d0
        bmi.s .done
        cmp.b #NO_ROLE,0(a0,d0.w)
        bne.s .done
        move.w #-1,hover_slot
.done:  movem.l (sp)+,d0-d7/a0-a3
        rts

; -> A0 the text of the first warning, or 0 (Z set) when there is none.
first_warning:
        move.l d0,-(sp)
        move.w warnings,d0
        beq .none
        lea warning_texts(pc),a0
.bit:   lsr.w #1,d0
        bcs .found
        addq.l #4,a0
        bra .bit
.found: movea.l (a0),a0
        move.l (sp)+,d0
        cmpa.w #0,a0                    ; Z clear
        rts
.none:  suba.l a0,a0
        move.l (sp)+,d0
        cmpa.w #0,a0
        rts

;============================================================================
; The game's objects made again from the record

; The record's placements into the game's list, the play map from the
; record, the border cleared and the game's object expansion run; every
; cell that changed (or was still to be drawn) is marked for the redraw.
objects_apply:
        movem.l d0-d7/a0-a4,-(sp)
        lea edit_record+R_OBJECTS,a0
        movea.l placements,a1
        move.w #PLACEMENT_WORDS-1,d0
.swap:  move.w (a0)+,d1
        rol.w #8,d1
        move.w d1,(a1)+
        dbra d0,.swap
        movea.l G_MAP(a5),a0
        lea old_map,a1
        lea edit_record+R_MAP,a2
        move.w #MAP_CELLS-1,d0
.copy:  move.l (a0),(a1)+
        move.l (a2)+,(a0)+
        dbra d0,.copy
        GCALL border_clear
        GCALL expand_objects
        movea.l G_MAP(a5),a0
        lea old_map,a1
        move.w #MAP_CELLS-1,d0
.mark:  move.l (a0),d1
        move.l (a1)+,d2
        bmi .dirty                      ; it was still to be drawn
        eor.l d1,d2
        add.l d2,d2                     ; bit 31 does not count
        beq .same
.dirty: bset #31,d1
        move.l d1,(a0)
.same:  addq.l #4,a0
        dbra d0,.mark
        st G_REDRAW_ALL(a5)
        bsr objects_scan
        movem.l (sp)+,d0-d7/a0-a4
        rts

; D0 a place, D1..D5 its new type, x, y and repeat counts (type -1:
; empty). Written when the game can take it (the pool) and the object stays
; inside the map, and the game's objects are made again; otherwise the old
; values stay and the reason is shown. -> Z set when done. Preserves all.
commit_slot:
        movem.l d0-d7/a0,-(sp)
        move.w d0,d7
        movem.w d1-d5,new_values
        bsr get_slot
        movem.w d1-d5,old_values
        movem.w new_values,d1-d5
        bsr put_slot
        bsr objects_scan
        tst.w d1
        bmi .done                       ; emptying a place always works
        lea s_pool_full(pc),a0
        cmp.l #POOL_SIZE,pool_total
        bhi .refuse
        lea s_no_room(pc),a0
        move.w d7,d0
        bsr slot_inside
        bne .refuse
.done:  bsr objects_apply
        st dirty
        st touched
        st fields_changed
        movem.l (sp)+,d0-d7/a0
        ori #4,ccr
        rts
.refuse:
        move.w d7,d0
        movem.w old_values,d1-d5
        bsr put_slot
        bsr objects_scan
        moveq #UI_WARN,d0
        bsr set_message
        movem.l (sp)+,d0-d7/a0
        andi #$fb,ccr
        rts

; D0 a place -> Z set when its object lies inside the map's shown part
; (the cells the terrain tools edit). Preserves all.
slot_inside:
        movem.l d0-d1/a0,-(sp)
        lea slot_box,a0
        lsl.w #3,d0
        adda.w d0,a0
        cmp.w #VIEW_EDGE,(a0)
        blt .no
        cmp.w #VIEW_EDGE,2(a0)
        blt .no
        move.w G_COLUMNS(a5),d1
        lsl.w #CELL_SHIFT_X,d1
        sub.w #VIEW_EDGE,d1
        cmp.w 4(a0),d1
        blt .no
        move.w G_ROWS(a5),d1
        lsl.w #CELL_SHIFT_Y,d1
        sub.w #VIEW_EDGE,d1
        cmp.w 6(a0),d1
        blt .no
        movem.l (sp)+,d0-d1/a0
        ori #4,ccr
        rts
.no:    movem.l (sp)+,d0-d1/a0
        andi #$fb,ccr
        rts

; D0 x, D1 y of an origin, A0 the box from it (x0, y0, x1, y1) -> the
; origin moved by whole cells until the box lies inside the map's shown
; part; carry set when it cannot. Preserves the other registers.
clamp_origin:
        movem.l d2-d3,-(sp)
        move.w d0,d2
        add.w (a0),d2
        cmp.w #VIEW_EDGE,d2
        bge .right
        move.w #VIEW_EDGE+15,d0
        sub.w (a0),d0
        and.w #-16,d0
.right: move.w G_COLUMNS(a5),d3
        lsl.w #CELL_SHIFT_X,d3
        sub.w #VIEW_EDGE,d3
        move.w d0,d2
        add.w 4(a0),d2
        cmp.w d3,d2
        ble .top
        sub.w 4(a0),d3
        and.w #-16,d3
        move.w d3,d0
        move.w d0,d2
        add.w (a0),d2
        cmp.w #VIEW_EDGE,d2
        blt .no
.top:   move.w d1,d2
        add.w 2(a0),d2
        cmp.w #VIEW_EDGE,d2
        bge .bottom
        move.w #VIEW_EDGE+7,d1
        sub.w 2(a0),d1
        and.w #-8,d1
.bottom:
        move.w G_ROWS(a5),d3
        lsl.w #CELL_SHIFT_Y,d3
        sub.w #VIEW_EDGE,d3
        move.w d1,d2
        add.w 6(a0),d2
        cmp.w d3,d2
        ble .yes
        sub.w 6(a0),d3
        and.w #-8,d3
        move.w d3,d1
        move.w d1,d2
        add.w 2(a0),d2
        cmp.w #VIEW_EDGE,d2
        blt .no
.yes:   movem.l (sp)+,d2-d3
        andi #$fe,ccr
        rts
.no:    movem.l (sp)+,d2-d3
        ori #1,ccr
        rts

;============================================================================
; The pointer and the objects

; -> D0 x, D1 y: the map pixel under the pointer.
cursor_map:
        move.w G_CURSOR_X(a5),d0
        add.w G_SCROLL_X(a5),d0
        add.w #VIEW_EDGE,d0
        move.w G_CURSOR_Y(a5),d1
        add.w G_SCROLL_Y(a5),d1
        add.w #VIEW_EDGE,d1
        rts

; D0 x, D1 y in the map -> D0 the object there, the last placed first, or
; -1. Preserves the other registers.
object_at:
        movem.l d1-d7/a0-a1,-(sp)
        move.w d0,d6
        move.w d1,d7
        moveq #SLOTS-1,d5
.slot:  lea slot_role,a0
        cmp.b #NO_ROLE,0(a0,d5.w)
        beq .next
        lea slot_box,a0
        move.w d5,d0
        lsl.w #3,d0
        adda.w d0,a0
        cmp.w (a0),d6
        blt .next
        cmp.w 4(a0),d6
        bge .next
        cmp.w 2(a0),d7
        blt .next
        cmp.w 6(a0),d7
        bge .next
        move.w d5,d0
        bsr expand_slot
        bsr parts_kept
        move.w d0,d4
        lea parts,a1
        bra .test
.part:  bsr part_rect
        cmp.w d0,d6
        blt .miss
        add.w d0,d2
        cmp.w d2,d6
        bge .miss
        cmp.w d1,d7
        blt .miss
        add.w d1,d3
        cmp.w d3,d7
        bge .miss
        move.w d5,d0
        bra .out
.miss:  addq.l #8,a1
.test:  dbra d4,.part
.next:  dbra d5,.slot
        moveq #-1,d0
.out:   movem.l (sp)+,d1-d7/a0-a1
        rts

; -> D0 x, D1 y for a new object of the chosen type: its box centred on
; the pointer, on the cell grid, inside the map; carry set when it does not
; fit.
new_position:
        movem.l d2/a0,-(sp)
        move.w obj_type,d1
        bsr type_entry
        lea T_BOX(a0),a0
        bsr cursor_map
        move.w (a0),d2
        add.w 4(a0),d2
        asr.w #1,d2
        sub.w d2,d0
        addq.w #8,d0
        and.w #-16,d0
        move.w 2(a0),d2
        add.w 6(a0),d2
        asr.w #1,d2
        sub.w d2,d1
        addq.w #4,d1
        and.w #-8,d1
        bsr clamp_origin
        movem.l (sp)+,d2/a0
        rts

; D0 a place: its object is selected.
select_slot:
        move.w d0,sel_slot
        st fields_changed
        rts

;----------------------------------------------------------------------------
; Input in the Objects mode

objects_input:
        bsr widget_at
        move.w d0,hover
        move.w #-1,hover_slot
        cmp.w #SCREEN_ROWS,G_CURSOR_Y(a5)
        bhs .keys
        bsr cursor_map
        bsr object_at
        move.w d0,hover_slot
.keys:  move.w key,d0
        beq .drag
        tst.b dragging                  ; no key while an object is held: the
        beq.s .key                      ; selection, the counts, the object
        tst.b G_LEFT_DOWN(a5)           ; page and test play would leave the
        bne .drag                       ; drag with a stale object or box
.key:   bsr edit_key
.drag:  tst.b dragging
        beq .click
        tst.b G_LEFT_DOWN(a5)
        bne drag_move
        sf dragging
        rts
.click: tst.b G_LEFT_CLICK(a5)
        beq .held
        clr.w held_passes
        move.w hover,held_widget        ; only the button pressed repeats
        cmp.w #SCREEN_ROWS,G_CURSOR_Y(a5)
        blo object_click
        move.w hover,d0
        bpl widget_click
        rts
.held:  tst.b G_LEFT_DOWN(a5)           ; a held -/+ button repeats
        beq .right
        move.w hover,d0
        cmp.w held_widget,d0
        bne .right
        bsr repeat_button
        bne .right
        addq.w #1,held_passes
        cmp.w #HOLD_PASSES,held_passes
        blo .done
        bra widget_click
.right: tst.b G_RIGHT_CLICK(a5)
        beq .done
        move.w hover_slot,d0
        bpl delete_slot
.done:  rts

; D0 a widget -> Z set when it is one of the four -/+ buttons.
repeat_button:
        cmp.w #ID_WIDE_LESS,d0
        blo .no
        cmp.w #ID_HIGH_MORE,d0
        bhi .no
        ori #4,ccr
        rts
.no:    andi #$fb,ccr
        rts

; D0 a key in the Objects mode (edit_key has taken the common ones).
objects_key:
        moveq #ID_TYPES,d1
        cmp.b #'p',d0
        beq .widget
        moveq #ID_DELETE,d1
        cmp.b #$7f,d0                   ; Del
        beq .widget
        moveq #ID_WIDE_LESS,d1
        cmp.b #'-',d0
        beq .widget
        moveq #ID_WIDE_MORE,d1
        cmp.b #'=',d0
        beq .widget
        cmp.b #'+',d0
        beq .widget
        moveq #ID_HIGH_LESS,d1
        cmp.b #'[',d0
        beq .widget
        moveq #ID_HIGH_MORE,d1
        cmp.b #']',d0
        beq .widget
        moveq #ID_PREVIOUS,d1
        cmp.b #',',d0
        beq .widget
        moveq #ID_NEXT,d1
        cmp.b #'.',d0
        beq .widget
        rts
.widget:
        move.w d1,d0                    ; as its button, unless disabled
        bsr widget_state
        cmp.w #ST_DISABLED,d5
        beq .done
        bra widget_action
.done:  rts

; A click in the map: the object there is selected and follows the pointer
; while the button is held; elsewhere an object of the chosen type is
; placed, and follows the pointer as well.
object_click:
        move.w hover_slot,d0
        bpl .grab
        bsr place_object
        bmi .out
.grab:  bsr select_slot
        move.w d0,d7
        bsr get_slot                    ; D2 x, D3 y
        move.w d2,drag_x
        move.w d3,drag_y
        bsr cursor_map
        sub.w d2,d0
        move.w d0,grab_x
        sub.w d3,d1
        move.w d1,grab_y
        lea slot_box,a0                 ; its box from its origin
        move.w d7,d0
        lsl.w #3,d0
        adda.w d0,a0
        lea drag_box,a1
        move.w (a0)+,d0
        sub.w d2,d0
        move.w d0,(a1)+
        move.w (a0)+,d0
        sub.w d3,d0
        move.w d0,(a1)+
        move.w (a0)+,d0
        sub.w d2,d0
        move.w d0,(a1)+
        move.w (a0)+,d0
        sub.w d3,d0
        move.w d0,(a1)+
        st dragging
.out:   rts

; The selected object follows the pointer by whole cells, inside the map.
drag_move:
        cmp.w #SCREEN_ROWS,G_CURSOR_Y(a5)
        bhs .done
        bsr cursor_map
        sub.w grab_x,d0
        sub.w drag_x,d0
        addq.w #8,d0
        and.w #-16,d0
        add.w drag_x,d0
        sub.w grab_y,d1
        sub.w drag_y,d1
        addq.w #4,d1
        and.w #-8,d1
        add.w drag_y,d1
        lea drag_box,a0
        bsr clamp_origin
        bcs .done
        move.w d0,d6
        move.w d1,d7
        move.w sel_slot,d0
        bmi .done
        bsr get_slot
        cmp.w d2,d6
        bne .move
        cmp.w d3,d7
        beq .done
.move:  move.w d6,d2
        move.w d7,d3
        bra commit_slot
.done:  rts

; -> D0 the place of a new object of the chosen type at the pointer, or -1
; (N set).
place_object:
        bsr free_slot
        bmi .full
        move.w d0,d7
        bsr new_position                ; -> D0 x, D1 y
        bcs .no_room
        move.w d0,d2
        move.w d1,d3
        move.w d7,d0
        move.w obj_type,d1
        moveq #0,d4
        moveq #0,d5
        bsr commit_slot
        bne .none
        move.w d7,d0
        rts
.full:  lea s_slots_full(pc),a0
        bra .message
.no_room:
        lea s_no_room(pc),a0
.message:
        moveq #UI_WARN,d0
        bsr set_message
.none:  moveq #-1,d0
        rts

; D0 a place: its object deleted; its place stays empty.
delete_slot:
        move.w d0,d7
        moveq #-1,d1
        moveq #-1,d2
        moveq #-1,d3
        moveq #-1,d4
        moveq #-1,d5
        bsr commit_slot
        sf dragging
        cmp.w sel_slot,d7
        bne .message
        move.w #-1,sel_slot
.message:
        lea message_text,a3
        lea s_deleted(pc),a0
        bsr put_str
        move.w d7,d0
        addq.w #1,d0
        bsr put_number
        lea message_text,a0
        moveq #UI_INK,d0
        bra set_message

delete_selected:
        move.w sel_slot,d0
        bpl delete_slot
        rts

; The selected object's repeat counts: D6 0 across, 1 down; D7 +1 or -1.
repeat_change:
        move.w sel_slot,d0
        bmi .done
        bsr get_slot
        tst.w d6
        bne .down
        add.w d7,d4
        bra .commit
.down:  add.w d7,d5
.commit:
        bra commit_slot
.done:  rts

wide_less:
        moveq #0,d6
        moveq #-1,d7
        bra repeat_change
wide_more:
        moveq #0,d6
        moveq #1,d7
        bra repeat_change
high_less:
        moveq #1,d6
        moveq #-1,d7
        bra repeat_change
high_more:
        moveq #1,d6
        moveq #1,d7
        bra repeat_change

; D7 1 or -1: the next or previous object in placement order is selected
; and the view moves to it.
select_step:
        move.w sel_slot,d0
        bpl .from
        moveq #-1,d0
        tst.w d7
        bpl .from
        moveq #SLOTS,d0
.from:  moveq #SLOTS-1,d6
.slot:  add.w d7,d0
        and.w #SLOTS-1,d0
        lea slot_role,a0
        cmp.b #NO_ROLE,0(a0,d0.w)
        bne .found
        dbra d6,.slot
        rts
.found: bsr select_slot
        bra view_object

select_previous:
        moveq #-1,d7
        bra select_step
select_next:
        moveq #1,d7
        bra select_step

; D0 a place: the view is centred on its object, as far as the map allows;
; the scroll changes at the start of the next pass (edit_scroll).
view_object:
        movem.l d0-d1/a0,-(sp)
        lea slot_box,a0
        lsl.w #3,d0
        adda.w d0,a0
        move.w (a0),d0
        add.w 4(a0),d0
        asr.w #1,d0
        sub.w #VIEW_EDGE+BAR_W/2,d0
        and.w #-16,d0
        bpl .x_low
        moveq #0,d0
.x_low: cmp.w max_scroll_x,d0
        ble .x
        move.w max_scroll_x,d0
.x:     move.w 2(a0),d1
        add.w 6(a0),d1
        asr.w #1,d1
        sub.w #VIEW_EDGE+SCREEN_ROWS/2,d1
        and.w #-16,d1
        bpl .y_low
        moveq #0,d1
.y_low: cmp.w max_scroll_y,d1
        ble .y
        move.w max_scroll_y,d1
.y:     move.w d0,jump_scroll_x
        move.w d1,jump_scroll_y
        st scroll_jump
        movem.l (sp)+,d0-d1/a0
        rts

;----------------------------------------------------------------------------
; Drawing in the view

; The Objects mode in the view: the chosen type at the pointer where no
; object is, the outlines of the selected object's parts and the outline
; of the object under the pointer.
draw_objects_ui:
        cmp.w #SCREEN_ROWS,G_CURSOR_Y(a5)
        bhs .outlines
        tst.b dragging
        bne .outlines
        tst.w hover_slot
        bpl .outlines
        bsr draw_preview
.outlines:
        bsr wait_blit
        move.w sel_slot,d0
        bmi .hover
        bsr frame_parts
.hover: move.w hover_slot,d0
        bmi .done
        cmp.w sel_slot,d0
        beq .done
        bsr frame_box
.done:  rts

; The chosen type where a click would place it, and its box.
draw_preview:
        bsr new_position
        bcs .done
        move.w d0,d6
        move.w d1,d7
        move.w obj_type,d1
        bsr type_entry
        movea.l a0,a3
        movea.l T_DEF(a3),a0
        move.w d6,d0
        move.w d7,d1
        bsr draw_type
        addq.w #1,anim_tick             ; the next frame in the next pass
        bsr wait_blit
        move.w T_BOX(a3),d0             ; the box round its first frames
        add.w d6,d0
        sub.w G_SCROLL_X(a5),d0
        move.w T_BOX+2(a3),d1
        add.w d7,d1
        sub.w G_SCROLL_Y(a5),d1
        move.w T_BOX+4(a3),d2
        sub.w T_BOX(a3),d2
        move.w T_BOX+6(a3),d3
        sub.w T_BOX+2(a3),d3
        bra outline_box
.done:  rts

; D0 a place: an outline round each part of its object.
frame_parts:
        movem.l d0-d4/a1,-(sp)
        bsr expand_slot
        bsr parts_kept
        move.w d0,d4
        lea parts,a1
        bra .test
.part:  bsr part_rect
        sub.w G_SCROLL_X(a5),d0
        sub.w G_SCROLL_Y(a5),d1
        bsr outline_box
        addq.l #8,a1
.test:  dbra d4,.part
        movem.l (sp)+,d0-d4/a1
        rts

; D0 a place: an outline round its object.
frame_box:
        movem.l d0-d3/a0,-(sp)
        lea slot_box,a0
        lsl.w #3,d0
        adda.w d0,a0
        move.w (a0),d0
        move.w 2(a0),d1
        move.w 4(a0),d2
        sub.w d0,d2
        move.w 6(a0),d3
        sub.w d1,d3
        sub.w G_SCROLL_X(a5),d0
        sub.w G_SCROLL_Y(a5),d1
        bsr outline_box
        movem.l (sp)+,d0-d3/a0
        rts

; A0 a definition, D0 x, D1 y in the map: the object without repeats in
; the back buffer, each part in the frame anim_frame gives: its block
; animations, then its sprites with the game's sprite routine ($10ABC) in
; the play view.
draw_type:
        movem.l d0-d7/a0-a4,-(sp)
        moveq #0,d2
        moveq #0,d3
        bsr expand
        bsr wait_blit
        lea parts,a3
        bsr parts_kept
        move.w d0,d7
        bra .tiles_test
.tiles: move.w 4(a3),d4
        btst #PART_SPRITE,d4
        bne .tiles_next
        cmp.w #GRAPHIC_CELL,d4
        beq .tiles_next
        bsr block_anim
        bsr anim_frame
        lsl.w #2,d5
        movea.l 6(a2,d5.w),a4           ; the frame's tiles
        move.w 4(a2),d6
        subq.w #1,d6
        move.w 2(a3),d1
        asr.w #CELL_SHIFT_Y,d1
.row:   move.w (a3),d0
        asr.w #CELL_SHIFT_X,d0
        move.w 2(a2),d5
        subq.w #1,d5
.cell:  move.w (a4)+,d2
        bsr view_tile
        addq.w #1,d0
        dbra d5,.cell
        addq.w #1,d1
        dbra d6,.row
.tiles_next:
        addq.l #8,a3
.tiles_test:
        dbra d7,.tiles
        lea parts,a3
        bsr parts_kept
        move.w d0,d7
        bra .sprites_test
.sprites:
        move.w 4(a3),d4
        btst #PART_SPRITE,d4
        beq .sprites_next
        bsr sprite_anim
        bsr anim_frame                  ; -> D5 the frame
        movea.l G_STYLE_SPRITES(a5),a0
        btst #PART_COMMON,d4
        beq .style
        movea.l G_COMMON_SPRITES(a5),a0
.style: and.w #$ff,d4
        move.w (a3),d0
        move.w 2(a3),d1
        move.w #$8000,d2                ; clipped to the view, masked
        moveq #0,d3                     ; the play view's descriptor
        GCALL sprite
.sprites_next:
        addq.l #8,a3
.sprites_test:
        dbra d7,.sprites
        movem.l (sp)+,d0-d7/a0-a4
        rts

; Waits until the blitter is done, before the processor draws.
wait_blit:
        tst.b 2(a6)
.wait:  btst #6,2(a6)
        bne .wait
        rts

; An outline in the back buffer: D0 x, D1 y, D2 width, D3 height in
; pixels, clipped to the buffer. Preserves all.
outline_box:
        movem.l d0-d7/a0,-(sp)
        tst.w d2
        ble .out
        tst.w d3
        ble .out
        movea.l G_BACK(a5),a0
        move.w d0,d4
        add.w d2,d4
        subq.w #1,d4                    ; the right column
        move.w d1,d5
        add.w d3,d5
        subq.w #1,d5                    ; the bottom row
        move.w d1,d6
        bsr outline_span
        cmp.w d1,d5
        beq .out
        move.w d5,d6
        bsr outline_span
        move.w d1,d6
.side:  addq.w #1,d6
        cmp.w d5,d6
        bge .out
        move.w d0,d7
        bsr outline_dot
        cmp.w d0,d4
        beq .side
        move.w d4,d7
        bsr outline_dot
        bra .side
.out:   movem.l (sp)+,d0-d7/a0
        rts

; Row D6, pixels D0..D4 of the buffer A0 in the frame colours. Preserves
; all.
outline_span:
        movem.l d0-d4,-(sp)
        tst.w d6
        bmi .out
        cmp.w #VIEW_ROWS,d6
        bhs .out
        tst.w d0
        bpl .left
        moveq #0,d0
.left:  cmp.w #VIEW_WORDS*16-1,d4
        ble .word
        move.w #VIEW_WORDS*16-1,d4
.word:  cmp.w d4,d0
        bgt .out
        move.w d0,d1
        and.w #15,d1
        moveq #-1,d2
        lsr.w d1,d2                     ; from pixel D0 to the word's end
        move.w d0,d3
        or.w #15,d3                     ; the word's last pixel
        cmp.w d4,d3
        ble .draw
        move.w d4,d1                    ; the span ends in this word
        not.w d1
        and.w #15,d1
        moveq #-1,d3
        lsl.w d1,d3
        and.w d3,d2
        move.w d4,d3
.draw:  bsr outline_word
        move.w d3,d0
        addq.w #1,d0
        bra .word
.out:   movem.l (sp)+,d0-d4
        rts

; Row D6, pixel D7 of the buffer A0 in the frame colours. Preserves all.
outline_dot:
        movem.l d0/d2,-(sp)
        tst.w d6
        bmi .out
        cmp.w #VIEW_ROWS,d6
        bhs .out
        tst.w d7
        bmi .out
        cmp.w #VIEW_WORDS*16,d7
        bhs .out
        move.w d7,d0
        and.w #15,d0
        move.w #$8000,d2
        lsr.w d0,d2
        move.w d7,d0
        bsr outline_word
.out:   movem.l (sp)+,d0/d2
        rts

; Row D6, the word of pixel D0 of the buffer A0: the pixels D2 in the frame
; colours (frame_word, edit.s). Preserves all.
outline_word:
        movem.l d1/d3/a1,-(sp)
        move.w d6,d1
        mulu #VIEW_ROW,d1
        movea.l a0,a1
        adda.l d1,a1
        move.w d0,d1
        lsr.w #4,d1
        add.w d1,d1
        adda.w d1,a1
        move.w d2,d3
        bsr frame_word
        movem.l (sp)+,d1/d3/a1
        rts

;----------------------------------------------------------------------------
; The status line in the Objects mode: the object under the pointer (its
; place in the order, type and role, what the game numbers or pairs it
; with), else how many there are.

objects_status:
        lea status_text,a3
        move.w hover_slot,d7
        bpl .object
        lea s_objects_count(pc),a0
        bsr put_str
        move.w object_count,d0
        bsr put_number
        lea s_of_64(pc),a0
        bsr put_str
        bra .done
.object:
        lea s_object(pc),a0
        bsr put_str
        move.w d7,d0
        addq.w #1,d0
        bsr put_number
        lea s_type_of(pc),a0
        bsr put_str
        move.w d7,d0
        bsr get_slot
        move.w d1,d0
        bsr put_number
        move.b #' ',(a3)+
        lea slot_role,a0
        moveq #0,d0
        move.b 0(a0,d7.w),d0
        move.w d0,d6                    ; the role
        bsr put_role
        lea slot_kind,a0
        moveq #0,d1
        move.b 0(a0,d7.w),d1
        lea slot_number,a0
        moveq #0,d2
        move.b 0(a0,d7.w),d2
        lea slot_partner,a0
        moveq #0,d3
        move.b 0(a0,d7.w),d3            ; $ff: none
        cmp.w #KIND_ENTRANCE,d1
        beq .entrance
        cmp.w #KIND_SWITCH,d1
        beq .switch
        cmp.w #KIND_TARGET,d1
        beq .target
        cmp.w #KIND_TELEPORTER,d1
        beq .teleporter
        bra .repeats
.entrance:
        move.b #' ',(a3)+
        move.w d2,d0
        bsr put_number
        cmp.w #ENTRANCES_MAX,d2
        bhi .unused
        lea s_of(pc),a0
        bsr put_str
        move.w entrance_count,d0
        cmp.w #ENTRANCES_MAX,d0
        bls .entrances
        moveq #ENTRANCES_MAX,d0
.entrances:
        bsr put_number
        bra .done
.unused:
        lea s_not_used(pc),a0
        bsr put_str
        bra .done
.switch:
        move.b #' ',(a3)+
        move.w d2,d0
        addq.w #1,d0
        bsr put_number
        cmp.b #$ff,d3
        beq .no_target
        lea s_toggles(pc),a0
        bsr put_str
        move.w d3,d0
        addq.w #1,d0
        bsr put_number
        bra .done
.no_target:
        lea s_no_target(pc),a0
        bsr put_str
        bra .done
.target:
        cmp.b #$ff,d3
        beq .no_switch
        lea s_target_of(pc),a0
        cmp.w #ROLE_TARGET,d6
        beq .target_text
        lea s_also_target(pc),a0        ; a launcher a switch toggles
.target_text:
        bsr put_str
        move.w d2,d0
        addq.w #1,d0
        bsr put_number
        bra .done
.no_switch:
        lea s_no_switch(pc),a0
        bsr put_str
        bra .done
.teleporter:
        cmp.b #$ff,d3
        beq .alone
        lea s_pairs_with(pc),a0
        bsr put_str
        move.w d3,d0
        addq.w #1,d0
        bsr put_number
        bra .done
.alone: lea s_no_partner(pc),a0
        bsr put_str
        bra .done
.repeats:
        move.w d7,d0
        bsr get_slot
        bsr type_entry
        tst.b T_REPEAT(a0)
        beq .done
        lea s_repeat(pc),a0
        bsr put_str
        move.w d4,d0
        bsr put_number
        move.b #',',(a3)+
        move.w d5,d0
        bsr put_number
.done:  clr.b (a3)
        bra status_done

; D0 a role: its name at A3.
put_role:
        move.l a0,-(sp)
        cmp.w #ROLE_SCENERY,d0
        bhi.s .out
        lea role_names(pc),a0
        lsl.w #2,d0
        movea.l 0(a0,d0.w),a0
        bsr put_str
.out:   movea.l (sp)+,a0
        rts

; The help line over the map in the Objects mode.
objects_help:
        lea s_drop_help(pc),a0
        moveq #UI_DIM,d0
        tst.b dragging
        bne set_help
        bsr first_warning
        beq .actions
        lea help_build,a3
        move.l a0,-(sp)
        lea s_warning(pc),a0
        bsr put_str
        movea.l (sp)+,a0
        bsr put_str
        lea help_build,a0
        moveq #UI_WARN,d0
        bra set_help
.actions:
        lea s_objects_help(pc),a0
        moveq #UI_DIM,d0
        bra set_help

; D0 an Objects tool -> D5 ST_NORMAL or ST_DISABLED: Delete and -/+ need a
; selected object, -/+ a type that repeats that way and room in the count;
; < and > need objects. Preserves the other registers.
object_widget_state:
        movem.l d0-d4/d6-d7/a0,-(sp)
        moveq #ST_NORMAL,d7
        move.w d0,d6
        cmp.w #ID_PREVIOUS,d6
        blo .selected
        tst.w object_count
        bne .out
        bra .disabled
.selected:
        cmp.w #ID_DELETE,d6
        blo .out                        ; Types
        move.w sel_slot,d0
        bmi .disabled
        cmp.w #ID_DELETE,d6
        beq .out
        bsr get_slot                    ; D1 type, D4 across, D5 down
        bsr type_entry
        move.b T_REPEAT(a0),d2
        moveq #0,d3
        move.w d4,d0
        cmp.w #ID_HIGH_LESS,d6
        blo .way
        moveq #1,d3
        move.w d5,d0
.way:   btst d3,d2
        beq .disabled
        cmp.w #ID_WIDE_LESS,d6
        beq .less
        cmp.w #ID_HIGH_LESS,d6
        beq .less
        cmp.w #MAX_REPEAT,d0
        bge .disabled
        bra .out
.less:  tst.w d0
        bgt .out
.disabled:
        moveq #ST_DISABLED,d7
.out:   move.w d7,d5
        movem.l (sp)+,d0-d4/d6-d7/a0
        rts

; D0 an Objects text field -> its text at A3.
object_widget_text:
        movem.l d0-d6/a0,-(sp)
        cmp.w #ID_TYPE,d0
        bne .info
        move.w obj_type,d0
        bsr put_number
        move.b #' ',(a3)+
        move.w obj_type,d1
        bsr type_entry
        moveq #0,d0
        move.b T_ROLE(a0),d0
        bsr put_role
        bra .out
.info:  cmp.w #ID_TYPES_INFO,d0
        bne .repeat
        lea s_types_info(pc),a0
        bsr put_str
        move.w type_count,d0
        bsr put_number
        bra .out
.repeat:
        moveq #0,d6                     ; ID_WIDE: across
        move.b #'W',(a3)+
        cmp.w #ID_WIDE,d0
        beq .count
        moveq #1,d6                     ; down
        move.b #'H',-1(a3)
.count: move.b #' ',(a3)+
        move.w sel_slot,d0
        bmi .none
        bsr get_slot
        bsr type_entry
        btst d6,T_REPEAT(a0)
        beq .none
        move.w d4,d0
        tst.w d6
        beq .number
        move.w d5,d0
.number:
        bsr put_number
        bra .out
.none:  move.b #'-',(a3)+
.out:   movem.l (sp)+,d0-d6/a0
        rts

;============================================================================
; The object page: the style's types in rows by role, animated, each in a
; box that holds all its frames; a click chooses the type to place.

open_types:
        tst.w type_count
        beq .none
        sf dragging
        clr.w anim_tick                 ; every type from its first frame
        move.b #PAGE_TYPES,edit_page
        lea types_widgets(pc),a0
        move.l a0,widgets
        move.w #-1,hover
        st bar_redraw
        rts
.none:  lea s_no_types(pc),a0
        moveq #UI_ERROR,d0
        bra set_message

close_types:
        move.b #PAGE_EDIT,edit_page
        clr.w anim_tick                 ; the preview from its first frame
        bsr mode_widgets
        rts

types_up:
        move.w page_top,d0
        beq .same
        subq.w #1,d0
        move.w d0,page_top
        st fields_changed
.same:  rts

types_down:
        move.w page_top,d0
        cmp.w page_max_top,d0
        bhs .same
        addq.w #1,d0
        move.w d0,page_top
        st fields_changed
.same:  rts

; A pass of the object page.
types_pass:
        bsr scroll_flags_clear          ; the display does not scroll
        GCALL view_desc
        GCALL buttons
        bsr read_key
        bsr update_pointer
        bsr types_draw
        addq.w #1,anim_tick             ; the next frames in the next pass
        bsr types_input
        bsr types_frames
        bsr edit_help
        bsr types_status
        bsr bar_refresh
        st G_PASS_DONE(a5)
        bra edit_loop

types_input:
        bsr widget_at
        move.w d0,hover
        move.w key,d0
        cmp.b #KEY_ESC,d0
        beq close_types
        cmp.b #KEY_UP,d0
        beq types_up
        cmp.b #KEY_DOWN,d0
        beq types_down
        tst.b G_LEFT_CLICK(a5)
        beq .done
        cmp.w #SCREEN_ROWS,G_CURSOR_Y(a5)
        bhs .bar
        bsr type_at
        tst.w d0
        bmi .done
        move.w d0,obj_type
        st fields_changed
        bra close_types
.bar:   move.w hover,d0
        bpl widget_click
.done:  rts

; A0 a type's entry -> D1 x, D2 y of its box on the screen; carry set when
; it is not on the page as it is scrolled. Preserves the other registers.
type_place:
        move.l a1,-(sp)
        lea page_row_y,a1
        move.w T_ROW(a0),d2
        cmp.w page_top,d2
        blo .hidden
        add.w d2,d2
        move.w 0(a1,d2.w),d2
        move.w page_top,d1
        add.w d1,d1
        sub.w 0(a1,d1.w),d2
        add.w #PAGE_TOP,d2
        move.w d2,d1
        add.w T_H(a0),d1
        cmp.w #SCREEN_ROWS,d1
        bhi .hidden
        move.w T_PAGE_X(a0),d1
        movea.l (sp)+,a1
        andi #$fe,ccr
        rts
.hidden:
        movea.l (sp)+,a1
        ori #1,ccr
        rts

; -> D0 the type under the pointer on the page, or -1.
type_at:
        movem.l d1-d3/a0,-(sp)
        cmp.w #SCREEN_ROWS,G_CURSOR_Y(a5)
        bhs .none
        lea types,a0
        moveq #0,d0
.type:  cmp.w type_count,d0
        bhs .none
        bsr type_place
        bcs .next
        move.w G_CURSOR_X(a5),d3
        sub.w d1,d3
        bmi .next
        cmp.w T_W(a0),d3
        bhs .next
        move.w G_CURSOR_Y(a5),d3
        sub.w d2,d3
        bmi .next
        cmp.w T_H(a0),d3
        blo .out
.next:  addq.w #1,d0
        lea TYPE_SIZE(a0),a0
        bra .type
.none:  moveq #-1,d0
.out:   movem.l (sp)+,d1-d3/a0
        rts

; The page into the back buffer: the play area cleared, then every type
; whose row is shown.
types_draw:
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
        lea types,a3
        moveq #0,d7
.type:  cmp.w type_count,d7
        bhs .done
        movea.l a3,a0
        bsr type_place
        bcs .next
        add.w T_ORG_X(a3),d1            ; its origin, in the map
        add.w G_SCROLL_X(a5),d1
        add.w #VIEW_EDGE,d1
        add.w T_ORG_Y(a3),d2
        add.w G_SCROLL_Y(a5),d2
        add.w #VIEW_EDGE,d2
        move.w d1,d0
        move.w d2,d1
        movea.l T_DEF(a3),a0
        bsr draw_type
.next:  addq.w #1,d7
        lea TYPE_SIZE(a3),a3
        bra .type
.done:  rts

; Outlines round the chosen type and the type under the pointer.
types_frames:
        bsr wait_blit
        move.w obj_type,d0
        bsr frame_type
        bsr type_at
        tst.w d0
        bmi .done
        cmp.w obj_type,d0
        beq .done
        bsr frame_type
.done:  rts

; D0 a type: an outline round its box on the page, when it is shown.
frame_type:
        movem.l d0-d3/a0,-(sp)
        move.w d0,d1
        bsr type_entry
        bsr type_place
        bcs .out
        move.w d1,d0
        add.w #VIEW_EDGE,d0
        move.w d2,d1
        add.w #VIEW_EDGE,d1
        move.w T_W(a0),d2
        move.w T_H(a0),d3
        bsr outline_box
.out:   movem.l (sp)+,d0-d3/a0
        rts

; The status line on the object page: the type under the pointer.
types_status:
        lea status_text,a3
        bsr type_at
        tst.w d0
        bmi .done
        move.w d0,d1
        lea s_type(pc),a0
        bsr put_str
        bsr put_number
        move.b #' ',(a3)+
        move.b #' ',(a3)+
        bsr type_entry
        moveq #0,d0
        move.b T_ROLE(a0),d0
        bsr put_role
        moveq #0,d0
        move.b T_REPEAT(a0),d0
        beq .done
        lsl.w #2,d0
        lea repeat_texts-4(pc),a0
        movea.l 0(a0,d0.w),a0
        bsr put_str
.done:  clr.b (a3)
        bra status_done

;============================================================================
; Tables and texts of the Objects mode

link_roles:                             ; link effect -> role ($9E3E)
        dc.b -1,-1,ROLE_DEVICE,-1,-1,ROLE_DEVICE,ROLE_TRAP,ROLE_DEVICE
        dc.b ROLE_HAZARD,ROLE_LAUNCHER,ROLE_SWITCH,ROLE_BOUNCER
        dc.b ROLE_TELEPORTER,-1,-1,-1
role_groups:                            ; role -> group on the object page
        dc.b 0,1,2,3,3,3,3,3,3,3,3,3,3,4
        even
role_names:
        dc.l r_entrance,r_exit,r_water,r_trap,r_hazard,r_launcher
        dc.l r_bouncer,r_switch,r_target,r_teleporter,r_swinging
        dc.l r_device,r_ice,r_scenery
warning_texts:
        dc.l w_no_entrance,w_entrances,w_no_exit,w_teleporter,w_switch
        dc.l w_links,w_pool
repeat_texts:
        dc.l s_repeats_across,s_repeats_down,s_repeats_both

objects_widgets:
        COMMON_ROW
        WIDGET 2,ROW_B,34,ID_TYPES,s_types,h_types
        WIDGET 39,ROW_B,94,ID_TYPE,0,0
        WIDGET 136,ROW_B,40,ID_DELETE,s_delete,h_delete
        WIDGET 179,ROW_B,24,ID_WIDE,0,0
        WIDGET 205,ROW_B,12,ID_WIDE_LESS,s_minus,h_wide_less
        WIDGET 219,ROW_B,12,ID_WIDE_MORE,s_plus,h_wide_more
        WIDGET 234,ROW_B,24,ID_HIGH,0,0
        WIDGET 260,ROW_B,12,ID_HIGH_LESS,s_minus,h_high_less
        WIDGET 274,ROW_B,12,ID_HIGH_MORE,s_plus,h_high_more
        WIDGET 289,ROW_B,14,ID_PREVIOUS,s_prev_object,h_previous
        WIDGET 305,ROW_B,14,ID_NEXT,s_next_object,h_next
        dc.w -1

types_widgets:
        WIDGET 2,ROW_A,34,ID_BACK,s_back,h_types_back
        WIDGET 40,ROW_A,186,ID_TYPES_INFO,0,0
        WIDGET 230,ROW_A,28,ID_UP,s_up,h_up
        WIDGET 260,ROW_A,34,ID_DOWN,s_down,h_down
        dc.w -1

r_entrance:     dc.b "Entrance",0
r_exit:         dc.b "Exit",0
r_water:        dc.b "Water",0
r_trap:         dc.b "Trap",0
r_hazard:       dc.b "Hazard",0
r_launcher:     dc.b "Launcher",0
r_bouncer:      dc.b "Bouncer",0
r_switch:       dc.b "Switch",0
r_target:       dc.b "Target",0
r_teleporter:   dc.b "Teleporter",0
r_swinging:     dc.b "Swinging",0
r_device:       dc.b "Device",0
r_ice:          dc.b "Ice",0
r_scenery:      dc.b "Scenery",0
w_no_entrance:  dc.b "there is no entrance",0
w_entrances:    dc.b "only four entrances work",0
w_no_exit:      dc.b "there is no exit",0
w_teleporter:   dc.b "a teleporter has no partner",0
w_switch:       dc.b "a switch has no target",0
w_links:        dc.b "traps and devices over the limit",0
w_pool:         dc.b "too many object parts for the game",0
s_types:        dc.b "Types",0
s_delete:       dc.b "Delete",0
s_minus:        dc.b "-",0
s_plus:         dc.b "+",0
s_prev_object:     dc.b "<",0
s_next_object:         dc.b ">",0
h_objects:      dc.b "Objects: place, move and delete objects (O)",0
h_types:        dc.b "Choose the type of object to place (P)",0
h_delete:       dc.b "Delete the selected object (Del, right click)",0
h_wide_less:    dc.b "Fewer copies side by side (-)",0
h_wide_more:    dc.b "More copies side by side (+)",0
h_high_less:    dc.b "Fewer copies one under another ([)",0
h_high_more:    dc.b "More copies one under another (])",0
h_previous:     dc.b "Select the previous object in order (,)",0
h_next:         dc.b "Select the next object in order (.)",0
h_types_back:   dc.b "Back to the level, the type as it was (Esc)",0
s_objects_help: dc.b "Click: place/select  Drag: move  Right click: delete",0
s_drop_help:    dc.b "Release the button to put the object down",0
s_types_help:   dc.b "Click: place objects of this type",0
s_warning:      dc.b "Warning: ",0
s_save_warning: dc.b "Save (S); warning: ",0
s_saved_warning: dc.b "Saved; warning: ",0
s_objects_count: dc.b "Objects ",0
s_of_64:        dc.b " of 64",0
s_object:       dc.b "Object ",0
s_type:         dc.b "Type ",0
s_of:           dc.b " of ",0
s_type_of:      dc.b "  Type ",0
s_not_used:     dc.b ", not used",0
s_toggles:      dc.b ", toggles ",0
s_no_target:    dc.b ", no target",0
s_target_of:    dc.b " of switch ",0
s_also_target:  dc.b ", target of switch ",0
s_no_switch:    dc.b ", no switch",0
s_pairs_with:   dc.b ", pairs with ",0
s_no_partner:   dc.b ", no partner",0
s_repeat:       dc.b "  Repeat ",0
s_repeats_across: dc.b "  repeats side by side",0
s_repeats_down: dc.b "  repeats one under another",0
s_repeats_both: dc.b "  repeats both ways",0
s_types_info:   dc.b "Object types of this style: ",0
s_deleted:      dc.b "Deleted object ",0
s_no_room:      dc.b "No room: the object would leave the map",0
s_pool_full:    dc.b "No room: the game's object memory is full",0
s_slots_full:   dc.b "All 64 places for objects are used",0
s_no_types:     dc.b "This style has no objects",0
                even

;============================================================================

        section editor_bss,bss

types:          ds.b MAX_TYPES*TYPE_SIZE
page_row_y:     ds.w PAGE_ROWS_MAX
page_row_h:     ds.w PAGE_ROWS_MAX      ; must follow page_row_y
page_rows:      ds.w 1
page_max_top:   ds.w 1
slot_box:       ds.w 4*SLOTS            ; x0, y0, x1, y1 of each object
slot_role:      ds.b SLOTS
slot_kind:      ds.b SLOTS
slot_number:    ds.b SLOTS              ; entrance 1.., switch or target 0..
slot_partner:   ds.b SLOTS              ; teleporter, switch, target; $ff
switch_slots:   ds.b SWITCHES_MAX
target_slots:   ds.b SWITCHES_MAX
help_build:     ds.b 64
                even
entrance_count: ds.w 1
exit_count:     ds.w 1
switch_count:   ds.w 1
target_count:   ds.w 1
open_teleporter: ds.w 1
page_box:       ds.w 4                  ; types_init: all frames' x0, y0, x1, y1
part_count:     ds.w 1
part_links:     ds.w 1
steps_left:     ds.w 1
origin_x:       ds.w 1
origin_y:       ds.w 1
saved_across:   ds.w 1
new_values:     ds.w 5
old_values:     ds.w 5
drag_x:         ds.w 1
drag_y:         ds.w 1
grab_x:         ds.w 1
grab_y:         ds.w 1
drag_box:       ds.w 4
held_passes:    ds.w 1
held_widget:    ds.w 1                  ; the button the held press began on
jump_scroll_x:  ds.w 1
jump_scroll_y:  ds.w 1
scroll_jump:    ds.b 1
all_frames:     ds.b 1                  ; part_rect: a sprite's every frame
                even
parts:          ds.w 4*MAX_PARTS
old_map:        ds.l MAP_CELLS
