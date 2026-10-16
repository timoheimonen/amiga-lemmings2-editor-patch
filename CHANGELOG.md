# Changelog

## V1.2.2 (2026-10-16)

- More level files made elsewhere are listed as damaged, where the game
  would write over its own data or stop: objects whose copies reach below
  the map past the game's map memory, objects that need more than the
  game's 4096 bytes of object memory, more than five swinging objects, or
  a rope of more than 7 copies. A level an earlier version saved with
  more swinging objects or a longer rope is listed as damaged too: it can
  be renamed or deleted, not opened.
- The Objects mode refuses a sixth swinging object and a rope of more
  than 7 copies, and the help line says why: the game keeps five swinging
  objects with ropes of up to 7.
- A map cell with an effect or a link but without its object, which only
  a level file made elsewhere can hold, does nothing. Before, a lemming
  that reached it stopped the game.
- The release rate goes up to 21, the fastest: one lemming every pass.
  Before, it stopped at 20.
- Long names fit their place: "Deleted" with a long file name on the
  list's help line no longer runs past the screen, and the names on the
  New, Rename and Delete pages no longer push ".lvl" onto the next line.
- The user's guide says to keep the `Levels` directory: without it,
  Create on the New page stops WHDLoad with an error.

## V1.2.1 (2026-10-11)

- A release rate or best grade's limit below zero, in a level file made
  elsewhere, can now be changed: - brings it to the top of the range,
  as it does a value above the range. Before, neither button changed it.
- A level file made elsewhere is listed as damaged when one of its
  objects is drawn partly left of or above the map: the game would write
  those parts far from the map, into its packed levels or its code.
- The editor is smaller and the terrain brush faster: repeated code is
  shared and unused code is gone (38552 bytes instead of 42040 for the US
  release).

## V1.2 (2026-10-07)

- The PAL release of the game (SPS 0351) is supported besides the US
  release (SPS 1976). `patch.py` takes the images of either release, IPF
  or ADF, all three disks of one release, and installs the slave and the
  editor for that release; it names the release it installed. The PAL
  release's disk 1 has no saved positions: the game starts with its
  default positions, and SAVE writes the file.

## V1.1 (2026-10-07)

- The object that follows the pointer in the Objects mode and every type
  on the object page play their animations at the game's speed, all the
  frames of every part in a loop: water and fires flow, an entrance opens,
  a trap springs.

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
