; Lemmings 2: The Tribes In-Game Level Editor V1.2
; Copyright (c) 2026 Timo Heimonen <timo.heimonen@proton.me>
; Licensed under the MIT License. See the LICENSE file for details.
;
; The two releases of the game that the slave and the editor support. They
; differ only in the main program (data/Lemmings2), whose hunk 0 has its
; code at other offsets and some of the game's globals (A5) two bytes lower
; in the PAL release:
;   SPS 1976, the US release: the main program of 394,024 bytes
;   SPS 0351, the PAL release: the main program of 393,068 bytes
; The slave and the editor are assembled for one of them: for the PAL
; release with PAL_RELEASE defined (vasm -DPAL_RELEASE=1), otherwise for
; the US release.
;
; GAME name,us,pal defines a game offset or value for both releases:
; name is us in the US release, pal in the PAL release.

GAME    macro
        ifd PAL_RELEASE
\1      equ \3
        else
\1      equ \2
        endif
        endm
