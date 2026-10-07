; Lemmings 2: The Tribes In-Game Level Editor V1.0
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; This project's own subset of the WHDLoad slave interface: the values the
; slave and the editor use, as the WHDLoad 20.0 autodoc and include file
; define them: slave flags, termination reasons, the offsets of the resload
; functions from the resload base passed to the slave in A0, and the tags
; of resload_Relocate. WHDLoad's own include files are not needed.
; Resload functions may change D0/D1/A0/A1.

WHDLF_NoError           equ 1<<1        ; resload errors quit with a requester
WHDLF_EmulTrap          equ 1<<2        ; forward TRAP #n to the program's vectors
WHDLF_ClearMem          equ 1<<12       ; clear BaseMem and ExpMem

TDREASON_OK             equ -1
TDREASON_WRONGVER       equ 9
TDREASON_FAILMSG        equ 43

resload_Abort           equ $04
resload_LoadFile        equ $08
resload_SaveFile        equ $0c
resload_ListFiles       equ $14         ; D0 size, A0 directory, A1 buffer
resload_FlushCache      equ $20
resload_GetFileSize     equ $24         ; 0 if the file does not exist
resload_CRC16           equ $30
resload_LoadFileOffset  equ $4c         ; D0 size, D1 offset, A0 name, A1 buffer
resload_Relocate        equ $50
resload_DeleteFile      equ $58         ; A0 name (ws_Version 8)

WHDLTAG_CHIPPTR         equ $88100000   ; resload_Relocate: chip hunks go here
WHDLTAG_ALIGN           equ $88100002   ; hunk lengths rounded up to this
WHDLTAG_LOADSEG         equ $88100003   ; build a segment list like LoadSeg
