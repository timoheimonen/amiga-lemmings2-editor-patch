; Lemmings 2: The Tribes In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; The WHDLoad slave for Lemmings 2: The Tribes with the in-game level
; editor. It runs only the supported version of the game, checked by its
; length and CRC16 (EXE_SIZE and EXE_CRC, defined when the slave is
; assembled) and then by the original bytes at every patch site.
;
; The slave loads the unpacked main program (data/Lemmings2) into ExpMem
; and relocates it: the two chip memory hunks into BaseMem, the others into
; ExpMem. It enters the program as the disk-2 loader does for a bare start
; (no ExecBase, the loader's memory values in D0-D2), replaces the game's
; disk selection and its private OFS file operations with WHDLoad file
; access to data/, puts the long word that the game's disk-3 check
; expects at $B4 (gate_value, copied in by the install tool), reads the
; saved positions without asking for their disk, and adds the quit key.
;
; The install requires fast memory (an A1200 with an expansion): ExpMem,
; which holds hunks 0 and 3, must not be chip memory. The chip memory this
; leaves free gives the game its extra chip pool for the extended sound
; effects, as the original disk-2 loader does on an expanded machine.
;
; The game's display calibration leaves the PAL countdown reload at 2, so
; a game second would pass every three fields; the slave sets the PAL value
; 49 that the game's own Tab handler uses (a game second every 50 fields),
; so that the game starts as if Tab had chosen PAL.
;
; The editor (data/Editor, assembled from editor.s) is loaded after the
; game into ExpMem, relocated there and initialized once; it checks and
; patches its own hooks in the game. Its interface is the resload base, the
; addresses of the game's four hunks and the editor's chip memory area in
; BaseMem (address and size).
;
; Offsets in the game are relative to the start of hunk 0. A5 is the
; game's globals.

        include "whdload_api.i"
        include "version.i"             ; EDITOR_VERSION

        ifnd EXE_SIZE
        fail "EXE_SIZE (length of the unpacked main program) must be defined"
        endif
        ifnd EXE_CRC
        fail "EXE_CRC (CRC16 of the unpacked main program) must be defined"
        endif

BASEMEM         equ $f0000              ; chip hunks, sound pool, editor, stack
CHIP_HUNKS      equ $2000               ; above WHDLoad's copper list at $1000
FX_POOL         equ $82000              ; the extra chip pool (loader D2), after
FX_POOL_SIZE    equ $64000              ; the chip hunks' end at $81438
EDITOR_CHIP     equ $e6000              ; the editor's chip memory: its bar, its
EDITOR_CHIP_SIZE equ $9000              ; copper list; the stack is above it
CHIP_END        equ $200000             ; AGA chip memory ends here
EXPMEM_SIZE     equ $c0000              ; the program's other hunks, then:
EDITOR          equ $80000              ; the editor, code and BSS
EDITOR_MAX      equ $40000
HUNKS           equ 4

; Hunk 0 offsets
SELECT_DISK     equ $11796              ; select logical disk D0 (0..2)
DISK_OP         equ $11b98              ; private OFS operation D0
KEY_STORE       equ $00e2e              ; keyboard interrupt: store raw key, ack
CALIBRATION     equ $0e550              ; move.w #2,$19a(a5): PAL countdown reload
PAL_RELOAD      equ 49                  ; what the Tab handler writes for PAL
POSITIONS       equ $16a64              ; read the saved positions (LOAD, SAVE)
POSITIONS_READ  equ $16aea              ; where Ready leads: the file is read
MENU_COLOURS    equ $16722              ; fade in the menu screen's colours
DISK3_TEXT      equ $16bb4              ; "Looking for Disk 3" after LOAD, SAVE

; Game globals (A5)
G_DRIVE         equ $1e3                ; drive digit used in "dfN:" names
G_DISK_STATE    equ $282                ; cleared after a disk change
G_DISK_FLAG     equ $1ea                ; cleared after a disk change
G_RAW_KEY       equ $2b0

ERROR_OBJECT_NOT_FOUND equ 205         ; what the game's OFS code returns
GATE_ADDRESS    equ $b4                 ; where the game's disk-3 check looks
GATE_SLOT       equ $34                 ; gate_value's place in the slave

;============================================================================

base:
        moveq #-1,d0                    ; ws_Security
        rts
        dc.b "WHDLOADS"                 ; ws_ID
        dc.w 17                         ; ws_Version
        dc.w WHDLF_NoError|WHDLF_EmulTrap|WHDLF_ClearMem
        dc.l BASEMEM                    ; ws_BaseMemSize
        dc.l 0                          ; ws_ExecInstall
        dc.w start-base                 ; ws_GameLoader
        dc.w 0                          ; ws_CurrentDir: the install
        dc.w 0                          ; ws_DontCache
        dc.b 0                          ; ws_keydebug
keyexit:
        dc.b $59                        ; ws_keyexit: F10
expmem:
        dc.l EXPMEM_SIZE                ; ws_ExpMem, replaced by its address
        dc.w name-base                  ; ws_name
        dc.w copy-base                  ; ws_copy
        dc.w info-base                  ; ws_info
        dc.w 0                          ; ws_kickname: no kickstart image
        dc.l 0                          ; ws_kicksize
        dc.w 0                          ; ws_kickcrc
        dc.w 0                          ; ws_config

; The long word that the game's disk-3 check (at $1B6E, before PRACTICE,
; MAP and PLAY) compares with the one at $B4, where the original disk 3
; leaves it. It is not part of this source: the install tool copies it from
; the user's own main program, the check's comparison at $1B7C, into this
; place, GATE_SLOT bytes into the slave. Without it the slave does not
; start, as the check would read the floppy drive.
gate_value:
        dc.l 0
        ifne gate_value-base-GATE_SLOT
        fail "gate_value must stay GATE_SLOT bytes into the slave"
        endif

name:   dc.b "Lemmings 2: The Tribes",0
copy:   dc.b "1993 DMA Design / Psygnosis",0
info:   dc.b "Level Editor "
        EDITOR_VERSION
        dc.b 10,"by Timo Heimonen"
        dc.b 10,"https://github.com/timoheimonen/amiga-lemmings2-editor-patch",0
executable:
        dc.b "data/Lemmings2",0
editor_file:
        dc.b "data/Editor",0
unsupported:
        dc.b "Unsupported disk operation",0
needs_fast:
        dc.b "This install needs fast memory",0
not_completed:
        dc.b "The install tool has not completed this slave",0
editor_too_large:
        dc.b "data/Editor is too large",0
        even

interface:                              ; what the editor is given
resload:
        dc.l 0
hunks:  ds.l HUNKS
        dc.l EDITOR_CHIP,EDITOR_CHIP_SIZE
path:   dc.b "data/"                    ; the game's file names go here
path_name:
        ds.b 64
        even

; The original bytes at the patch sites, checked before patching: offset,
; long word. The CRC16 of the whole file is checked first; these guard the
; offsets themselves.
checks: dc.l SELECT_DISK,$4ab80004       ; tst.l ($4).w
        dc.l DISK_OP,$48e7fffe           ; movem.l d0-d7/a0-a6,-(sp)
        dc.l KEY_STORE,$1b4002b0         ; move.b d0,$2b0(a5)
        dc.l KEY_STORE+4,$13fc0000       ; move.b #0,$bfec01
        dc.l KEY_STORE+8,$00bfec01
        dc.l CALIBRATION,$3b7c0002       ; move.w #2,$19a(a5)
        dc.l CALIBRATION+4,$019a422d     ; / clr.b $1cf(a5)
        dc.l POSITIONS,$4ab80004         ; tst.l ($4).w
        dc.l POSITIONS+4,$660000e8       ; bne.w (the operating system's path)
        dc.l DISK3_TEXT,$610001ea        ; bsr.w (show a message)
        dc.l -1


;============================================================================
; Entry from WHDLoad, in supervisor mode. A0: resload base.

start:
        lea resload(pc),a1
        move.l a0,(a1)
        movea.l a0,a2

        ; Fast memory is required: ExpMem must not be chip memory.
        move.l expmem(pc),d0
        cmp.l #CHIP_END,d0
        bhs.s .fast
        pea needs_fast(pc)
        pea TDREASON_FAILMSG
        bra abort
.fast:

        ; The install tool fills in gate_value.
        move.l gate_value(pc),d0
        bne.s .completed
        pea not_completed(pc)
        pea TDREASON_FAILMSG
        bra abort
.completed:

        ; Only the supported main program: length and CRC16.
        lea executable(pc),a0
        movea.l expmem(pc),a1
        jsr resload_LoadFile(a2)
        cmp.l #EXE_SIZE,d0
        bne wrong_version
        movea.l expmem(pc),a0
        jsr resload_CRC16(a2)           ; D0 = length still
        cmp.w #EXE_CRC,d0
        bne wrong_version

        ; Relocate: chip hunks (1, 2) into BaseMem, hunks 0 and 3 in place
        ; in ExpMem, with a segment list to find them.
        movea.l expmem(pc),a0
        clr.l -(sp)                     ; TAG_DONE
        pea -1
        move.l #WHDLTAG_LOADSEG,-(sp)
        pea 8
        move.l #WHDLTAG_ALIGN,-(sp)
        pea CHIP_HUNKS
        move.l #WHDLTAG_CHIPPTR,-(sp)
        movea.l sp,a1
        jsr resload_Relocate(a2)
        lea 7*4(sp),sp

        ; The segment list starts at the second long word of the program's
        ; place; each segment is a link (BPTR) followed by the hunk.
        movea.l expmem(pc),a0
        addq.l #4,a0
        lea hunks(pc),a1
        moveq #HUNKS-1,d0
.hunk:  lea 4(a0),a3
        move.l a3,(a1)+
        move.l (a0),d1
        lsl.l #2,d1
        movea.l d1,a0
        dbra d0,.hunk
        cmpa.w #0,a0
        bne wrong_version
        movea.l hunks(pc),a3            ; hunk 0

        ; Check the patch sites before changing them.
        lea checks(pc),a0
.check: move.l (a0)+,d0
        bmi.s .patch
        move.l (a0)+,d1
        cmp.l (a3,d0.l),d1
        bne wrong_version
        bra.s .check

.patch: movea.l a3,a1
        adda.l #SELECT_DISK,a1
        move.w #$4ef9,(a1)+             ; JMP select_disk
        lea select_disk(pc),a0
        move.l a0,(a1)
        movea.l a3,a1
        adda.l #DISK_OP,a1
        move.w #$4ef9,(a1)+             ; JMP disk_op
        lea disk_op(pc),a0
        move.l a0,(a1)
        lea KEY_STORE(a3),a1
        move.w #$4eb9,(a1)+             ; JSR keyboard, NOPs to the 12-byte end
        lea keyboard(pc),a0
        move.l a0,(a1)+
        move.l #$4e714e71,(a1)+
        move.w #$4e71,(a1)
        movea.l a3,a1
        adda.l #CALIBRATION+2,a1
        move.w #PAL_RELOAD,(a1)         ; the immediate of move.w #2,$19a(a5)
        movea.l a3,a1
        adda.l #POSITIONS,a1
        move.w #$4ef9,(a1)+             ; JMP positions, a NOP to the 8-byte end
        lea positions(pc),a0
        move.l a0,(a1)+
        move.w #$4e71,(a1)
        ; Afterwards the game would say "Looking for Disk 3...." while it
        ; selects disk 3 and loads the tribe's style; the selection stays.
        movea.l a3,a1
        adda.l #DISK3_TEXT,a1
        move.l #$4e714e71,(a1)

        ; The editor: loaded into ExpMem after the game, relocated in place,
        ; then initialized; it returns 0 or an error message.
        lea editor_file(pc),a0
        movea.l expmem(pc),a4
        adda.l #EDITOR,a4
        movea.l a4,a1
        jsr resload_LoadFile(a2)
        movea.l a4,a0
        clr.l -(sp)                     ; TAG_DONE
        pea 8
        move.l #WHDLTAG_ALIGN,-(sp)
        movea.l sp,a1
        jsr resload_Relocate(a2)
        lea 3*4(sp),sp
        cmp.l #EDITOR_MAX,d0
        bls.s .editor_fits
        pea editor_too_large(pc)
        pea TDREASON_FAILMSG
        bra abort
.editor_fits:
        lea interface(pc),a0
        jsr (a4)
        tst.l d0
        beq.s .editor_ready
        move.l d0,-(sp)
        pea TDREASON_FAILMSG
        bra abort
.editor_ready:
        movea.l resload(pc),a2
        jsr resload_FlushCache(a2)

        ; Bare start: no ExecBase (WHDLoad leaves $f0000001 at $4), and in
        ; low memory the long word the original disk 3 leaves there.
        clr.l ($4).w
        move.l gate_value(pc),(GATE_ADDRESS).w

        ; The disk-2 loader's memory values: D2 the extra chip pool for the
        ; extended sound effects; no file cache area (D0/D1), because
        ; WHDLoad's PRELOAD keeps the files in memory instead.
        moveq #0,d0
        moveq #0,d1
        move.l #FX_POOL,d2
        suba.l a0,a0
        jmp (a3)

wrong_version:
        pea TDREASON_WRONGVER
        bra abort

;============================================================================
; Replaces the start of POSITIONS, which LOAD and SAVE call first. Without
; an operating system the game asks for the saved position disk, waits for
; Ready and makes sure that no game disk is in the drive; the install has
; the file. Do what the game does before it asks, fade in the colours, and
; go on where Ready leads, so that the file is read at once (and a missing
; file's message, "using defaults", can be seen).

positions:
        move.l hunks(pc),-(sp)
        addi.l #POSITIONS_READ,(sp)     ; then on where Ready leads
        move.l hunks(pc),-(sp)
        addi.l #MENU_COLOURS,(sp)       ; first the colours
        rts

;============================================================================
; Replaces SELECT_DISK. All files are in the install's data directory, so
; there is nothing to select; keep what the original leaves after it found
; the disk. A5: game globals.

select_disk:
        move.b #'0',G_DRIVE(a5)
        clr.l G_DISK_STATE(a5)
        sf G_DISK_FLAG(a5)
        rts

;============================================================================
; Replaces DISK_OP: D0 operation (0 read, 1 write), A0 "dfN:name", A1
; buffer, D1 length to write. Returns D0 = 0 with the flags set from it, D1
; the file length after a read; all other registers preserved, as the
; original. A missing file is not an error for WHDLoad: without
; L2-Saved-Positions the game takes its default positions and SAVE creates
; the file, so a read returns the game's own "object not found" code.

disk_op:
        movem.l d1-d7/a0-a6,-(sp)
        cmpi.b #':',3(a0)
        bne.s .name
        addq.l #4,a0                    ; skip "dfN:"
.name:  lea path_name(pc),a2            ; "data/" + name
        moveq #63-1,d2
.copy:  move.b (a0)+,(a2)+
        dbeq d2,.copy
        clr.b (a2)
        lea path(pc),a0
        movea.l resload(pc),a2
        tst.b d0
        beq.s .read
        cmpi.b #1,d0
        bne.s .unsupported
        move.l d1,d0                    ; length
        jsr resload_SaveFile(a2)
        bra.s .done
.read:  movea.l a0,a3
        movea.l a1,a4
        jsr resload_GetFileSize(a2)
        tst.l d0
        beq.s .missing
        movea.l a3,a0
        movea.l a4,a1
        jsr resload_LoadFile(a2)
        move.l d0,(sp)                  ; returned D1: the file length
.done:  movem.l (sp)+,d1-d7/a0-a6
        moveq #0,d0
        rts
.missing:
        movem.l (sp)+,d1-d7/a0-a6
        move.l #ERROR_OBJECT_NOT_FOUND,d0
        rts
.unsupported:
        pea unsupported(pc)
        pea TDREASON_FAILMSG
        bra abort

;============================================================================
; Replaces the 12 bytes at KEY_STORE in the level 2 interrupt: store the raw
; key and start the handshake as the original does, then check the quit key
; (WHDLoad checks it itself only when it has moved the VBR).

keyboard:
        move.b d0,G_RAW_KEY(a5)
        move.b #0,$bfec01
        cmp.b keyexit(pc),d0
        beq.s quit
        rts

quit:   pea TDREASON_OK
abort:  move.l resload(pc),-(sp)
        addq.l #resload_Abort,(sp)
        rts
