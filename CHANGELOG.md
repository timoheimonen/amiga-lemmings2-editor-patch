# Changelog

## V1.0 (2026-10-07)

- The first release: an in-game level editor for Lemmings 2: The Tribes,
  as a WHDLoad install for an Amiga with Kickstart 3.1 and at least 2 MiB
  of fast memory, on a PAL display.
- `patch.py` makes the install from your own images of the game's three
  disks (IPF or ADF, identified by their SHA-256): the slave, the game's
  files with the main program unpacked, the editor and its tile flags, the
  Workbench icon (`PRELOAD NOWRITECACHE`) and the directory `Levels`. Run
  again over an install, it keeps your levels and saved positions.
- EDIT on the title screen, in place of the crossed-out QUIT, opens the list
  of your levels (`.lvl` files in `Levels`, up to 512): Play, Edit, New,
  Rename and Delete, each with a key. A level plays in its own style with
  60 lemmings, its own skills and clock, and ends on the editor's result
  page (Replay, Edit, Levels), never touching the tribes' progress.
- The editor works in the game's own view with the editor bar below it:
  Terrain (the style's pieces or single tiles, erase, pick, Decor and
  Steel), Objects (place, move and delete them, their repeat counts, the
  object page by groups, warnings), Param (title, the eight skills with the
  game's own picker, counts, time, release rate, the best grade's limit,
  the start view and the scroll limits), test play, 32 steps of undo and
  redo, and saving. Every button has a key and help on the bar.
- Levels from elsewhere are checked before they are played or edited; a
  file the game could not take is listed as damaged and can still be
  renamed or deleted.
- LOAD and SAVE on the title screen use the install's saved positions
  without asking for their disk.
