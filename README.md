# Lemmings 2: The Tribes In-Game Level Editor

An in-game level editor for the Amiga game **Lemmings 2: The Tribes**, as a
WHDLoad install for a hard disk. You make your own levels in the game's own
view, with the game's terrain, objects and skills, test play them at once,
and keep them as files you can share.  
The editor integrates directly into the game engine, ensuring 100% authentic gameplay and physics.

`patch.py` makes the install from your own copy of the game, the US or the
PAL release: your images of its three disks, which it identifies by their
SHA-256. This repository holds
only the editor's and the slave's own code and the tools; it contains no
game files.

## Screenshots

Video: [See on YouTube](https://youtu.be/7S_ehwBR0Qw).

![The title screen with EDIT](docs/screenshots/Lemmings%202%20in-game%20editor%20-%20version%20main%20menu.png)

![The list of your levels](docs/screenshots/Lemmings%202%20in-game%20editor%20-%20custom%20menu.png)

![The editor in an Outdoor level: the Terrain mode](docs/screenshots/Lemmings%202%20in-game%20editor%20-%20outdoor.png)

More: [a new level](docs/screenshots/Lemmings%202%20in-game%20editor%20-%20new%20level.png),
[the pieces page](docs/screenshots/Lemmings%202%20in-game%20editor%20-%20terrain%20menu.png),
[the object page](docs/screenshots/Lemmings%202%20in-game%20editor%20-%20objects%20menu.png),
[the scroll limits](docs/screenshots/Lemmings%202%20in-game%20editor%20-%20set%20map%20limits.png),
[a Sports level](docs/screenshots/Lemmings%202%20in-game%20editor%20-%20sports.png),
[a Polar level](docs/screenshots/Lemmings%202%20in-game%20editor%20-%20polar1.png) and
[its test play](docs/screenshots/Lemmings%202%20in-game%20editor%20-%20polar2.png).

## Requirements

- An Amiga with Kickstart 3.1, WHDLoad 17 or later and **at least 2 MiB of
  fast memory**, such as an A1200 with a memory expansion. Tested on an
  emulated A1200 (68020, AGA, Kickstart 3.1, 2 MiB chip and 4 MiB fast
  memory).
- A **PAL** display: the editor's bar lies below the game's view, on lines
  only PAL shows.
- Python 3.8 or later (for `patch.py`).
- [vasm](http://sun.hasenbraten.de/vasm/) `vasmm68k_mot` (only for
  `build.py`).
- Your own copies of the game's three disks, all three of one release, as
  IPF or as ADF images with these SHA-256 hashes:

The US release (SPS 1976):

| Image | IPF SHA-256 | ADF SHA-256 |
| --- | --- | --- |
| Disk 1 | `24a005cca5ba97da00bd44233863b817f90b6a08906c65dba2fd1bcd20045509` | `d1b71a2a0d5797c3c185f4d939b9ad2416921a8370ee082f2bc9df0ee73ac181` |
| Disk 2 | `05b800affc4bcb5044f41606bc807d7efc5f0669b82abb1b9573f38631257965` | `fcbc1b870ae30bc5f79a58ee8bef81e1e7743472240de8896f21d9508abdff91` |
| Disk 3 | `e5cff8776a8a09a8fb1d1b7f23767ccab5c2acc6f06b10ee0f13f54dd57f5ce5` | `5219ae0d109ef94ce1eb84212024b83e929def0d2e8ea68fc5c0c4abd4589fb3` |

The PAL release (SPS 0351):

| Image | IPF SHA-256 | ADF SHA-256 |
| --- | --- | --- |
| Disk 1 | `d443e31c1021fdf96dcc9271486478854412748195debc111637b3300f76c2ac` | `0a634a5a8b36206a6478fda5218653acf6523e534372c670c56f78b607163508` |
| Disk 2 | `41a381621ee8e1b76763f20d2bacca446085033ac9bfde9492e963cb09509f7b` | `2c7bd93ed2c1bad612e83c5e2c749861419673139b32d1d7b2e2013c6e0007a0` |
| Disk 3 | `b24ced40bd23e1371ce75bad97195fa67471bcb4a7f7eff9a4f1860d935ca502` | `de1a9ef4aef4e46b5dd5f9899aaa84d0f6a9f00b72da1b9bafc0c724afcb917b` |

Other versions are refused, as are disks of the two releases mixed. An ADF
image holds only the standard AmigaDOS tracks; disk 3 has a track an ADF
cannot hold, and the ADF hashes above are the ones with its blocks as
zeros. The two releases differ only in the main program, so the install
has the slave and the editor for the release your disks are; the PAL
release's disk 1 has no saved positions, so the game starts with its
default positions and SAVE writes the file.

## Making the install

```sh
python3 patch.py "Disk 1.ipf" "Disk 2.ipf" "Disk 3.ipf" --out Lemmings2
```

The images can be given in any order, as IPF or ADF. `patch.py` checks
every image and every file it needs before it writes anything, and only
reads the images. It writes the directory `Lemmings2`:

| Path | Contents |
| --- | --- |
| `Lemmings2.slave` | The WHDLoad slave |
| `Lemmings2.info` | The Workbench icon, with the tool types `PRELOAD NOWRITECACHE` |
| `data/` | The game's files from your disks (the main program unpacked), the editor `Editor` and `EditorTiles`, the editor's tile flags worked out from the game's own levels |
| `Levels/` | Your levels |

Copy the directory to your hard disk and start the game from its icon. With
`NOWRITECACHE` a saved, renamed or deleted level is on the disk when the
editor says so; each write takes a few seconds with the screen blank.
Without it WHDLoad keeps the changes in memory and writes them when it
quits, and a reset or a power cut before that loses them. **F10** quits
WHDLoad at once, also in the middle of editing: save first.

To update an install, run `patch.py` again with the same `--out`: it
writes the program files again and keeps your levels and your saved
positions.

## Using the editor

The [user's guide](docs/manual.md) describes it all. In short: **EDIT** on
the title screen, in place of the crossed-out QUIT, opens the list of your
levels, the `.lvl` files in `Levels`, where you play, edit, make, rename
or delete them. A level plays in its own style with 60 lemmings, its own
skills and clock, and ends on the editor's result page; the tribes'
progress is never changed. The editor works in the game's own view with
the editor bar below it: **Terrain** (the style's pieces or single tiles,
erase, pick, Decor and Steel), **Objects** (place, move and delete them,
with warnings; the object to place and the object page show their
animations), **Param** (title, skills, time, release rate, grading, the
start view and the scroll limits), **Test**, **Undo** and **Redo** (32
steps) and **Save**. Every button has a key, and the bar's help line names
it. A level is one file of 8648 bytes, the game's own level record: copy
the files to share your levels.

## Limitations

- A PAL display only, with either release (see Requirements). The game's
  Tab, which switches between PAL
  and NTSC in play, does nothing while your own levels are played, and the
  editor goes back to PAL when it opens.
- The list holds up to 512 levels with names of up to 31 characters; with
  more `.lvl` files, which of them are listed depends on WHDLoad's order. A
  page of the list reads its levels' files when it is shown, which takes a
  moment when WHDLoad has to fetch them from the disk.
- Keep only level files in `Levels`: New or Rename to the name of a
  directory there stops WHDLoad with an error.
- With WHDLoad's write cache on (without `NOWRITECACHE`), more than 128
  deletions and renames in one session bring the 129th name back in the
  list as damaged until WHDLoad quits.
- A level file from elsewhere is checked for what makes the game crash
  (it is then listed as damaged); objects whose repeated copies reach past
  the map are not checked, as the game itself does not.
- F10 quits at once, also with unsaved changes.

## Build

```sh
python3 build.py
```

Assembles the slave (`src/whdload/slave.s`) and the editor
(`src/editor/editor.s`, which includes the other editor sources) for each
of the two releases (the PAL release's with `PAL_RELEASE`,
`src/whdload/release.i`), builds the install's icon and embeds the five in
the generated section of `patch.py`, so that users of `patch.py` need only
Python.

## How it works

- `src/whdload/slave.s`, the WHDLoad slave, loads the unpacked main program
  into fast memory and relocates it: its two chip memory hunks into chip
  memory, the other two in place. It starts the game as the game's own
  loader does without an operating system, replaces the game's floppy disk
  access with WHDLoad's file access to `data/`, reads the saved positions
  without asking for their disk and adds the quit key. The game checks for
  its original disk 3: the US release before PRACTICE, MAP and PLAY, the
  PAL release when a level is chosen and before PRACTICE. `patch.py` copies
  the long word that check expects from your own main program into the
  slave, which puts it where the check looks. The PAL release also reads
  disk 3 once, at its first title; as WHDLoad has no floppy drive to read,
  the slave lets that reading return at once. The slave then loads the
  editor. Each release has its own slave and editor, assembled from the
  same sources (`src/whdload/release.i` gives the game's addresses in
  both).
- `src/editor/editor.s` checks the game's original bytes at its patch points
  and hooks the title screen (EDIT in place of the crossed-out QUIT), the
  end of play, the play keys and the level start. The list, the New, Rename
  and Delete pages and the result page are drawn on the game's own menu
  screen. A custom level is the game's own level record, built and played
  by the game's own code in its own style, with 60 lemmings, and it never
  touches the tribes' progress.
- The edit view (`src/editor/edit.s`) runs instead of the game's play loop
  in the game's own play view, with the editor bar below it on its own copper
  list (`src/editor/bar.s`); `objects.s`, `level.s` and `undo.s` are the
  Objects and Param modes, and undo, redo and test play. After every change
  the game's own routines make the level's objects and map again from the
  record.

## Docs

- The [user's guide](docs/manual.md).
- The [level file format](docs/editor-lvl-format.md): every byte of the
  `.lvl` files the editor saves.
- The changes by version are in [CHANGELOG.md](CHANGELOG.md).

## Author

Timo Heimonen <timo.heimonen@proton.me>

## Legal

Lemmings 2: The Tribes is the property of its original rights holders (DMA
Design / Psygnosis). This project is not affiliated with them. The
repository contains no game files and no part of the game's code; you need
your own copy of the game. The project's own code is released under the
[MIT License](LICENSE), which covers only this project's code, not the
game.
