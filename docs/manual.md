# Lemmings 2: The Tribes level editor: user's guide

The WHDLoad version of Lemmings 2: The Tribes with an in-game level
editor. You make your own levels in the game's own view, with the game's
terrain, objects and skills, test play them at once, and keep them as
files you can share. The game's own levels, the tribes' progress and your
saved positions are never changed.

## What you need

- An Amiga with Kickstart 3.1 and **at least 2 MiB of fast memory**, such
  as an A1200 with a memory expansion. The editor is tested on an emulated
  A1200 (68020, AGA) with 2 MiB chip and 4 MiB fast memory.
- A **PAL** display: the editor's bar lies below the game's view, on lines
  only PAL shows. The game's Tab, which switches between PAL and NTSC in
  play, does nothing while your own levels are played, and the editor
  goes back to PAL when it opens.
- WHDLoad 17 or later, and the install that `patch.py` makes from your
  own disk images of the US or the PAL release (see the README): the
  slave `Lemmings2.slave`, its icon `Lemmings2.info`, the game's files
  in `data/`, the editor in `data/Editor` and `data/EditorTiles`, and a
  `Levels` directory for your levels.
- Start it with the tool types **`PRELOAD NOWRITECACHE`**. With
  `NOWRITECACHE` a saved or deleted level is on the disk when the editor
  says so; each write then takes a few seconds with the screen blank.
  Without it WHDLoad keeps the changes in memory and writes them when it
  quits, and a reset or a power cut before that loses them.
- **F10** quits WHDLoad at once, also in the middle of editing: save first.

## Starting

On the title screen the crossed-out QUIT button of the original reads
**EDIT**. Click it for the list of your levels. Everything else on the
title screen works as in the original game.

## Pages on the menu screen

The list, the New, Rename and Delete pages and the result page have red
buttons in two rows. Every button has a key. The bottom line says what
the button under the pointer does and names its key; otherwise it says
what you can do on the page, or for a few seconds what just happened. A
dark button does nothing at the moment; clicking it says why.

### The list of levels

Your levels are the `.lvl` files in the `Levels` directory, sorted by
name, nine to a page, each with its title, time and style. A file that is
not one valid level is listed by its file name as **damaged**: it can be
renamed or deleted, but not played or edited. A level file made elsewhere
is damaged too when it holds something the game cannot take: a skill the
game does not have, a start view or scroll limits outside the map, or an
object of a type the style does not have, far outside the map, off the
grid of 16x8-pixel cells or with more than 40 copies.

| Button | Key | What it does |
| --- | --- | --- |
| Play | P | Play the selected level |
| Edit | E | Open the selected level in the editor |
| New | N | Make a new level |
| Rename | R | Give the selected file another name |
| Delete | Del | Delete the selected file, after a question |
| Back | Esc | Back to the title screen |

Click a level to select it, or move the selection with the cursor keys
Up and Down. "< Previous" and "Next >" (or the cursor keys Left and Right)
turn the pages and select the first level of the page. The list holds up
to 512 levels (with names of up to 31 characters; files beyond that are
not shown). Keep only level files in `Levels`: a directory there is not
listed, and New or Rename to a directory's name stops WHDLoad with an
error.

### New

The page shows the editor's version below its title. Type the file
name: letters, digits, `-` and `_`, up to 20 characters; Backspace takes
one back, and `.lvl` is added. Choose the style (the
twelve tribes' styles) and the size (seven map sizes, from 82x24 to 22x84
cells) by clicking the left or the right half of their rows, or with the
cursor keys: Left and Right for the style, Up and Down for the size.
**Create** (Return) writes the level and opens it in the editor;
**Cancel** (Esc or the right button) goes back. A name that a level or
another file has already is refused. The style and the size cannot be
changed later.

A new level has the file name as its title, the original Lemmings' eight
skills with ten of each (in every style but Classic without the Blocker,
which works only there), five minutes, an empty map and no objects.

### Rename

The page shows the file and its title and starts the new name from the
old one. The name follows the rules of New. **Rename** (Return) writes the
file under the new name and then deletes the old one; **Cancel** (Esc or
the right button) keeps the old name. A name another file has is refused,
and so is the file's own name in other letter case (Amiga file names
ignore case). A damaged file is renamed as it is, if it is not larger
than 96 KiB.

### Delete

The page names the file and its title (or that it is damaged). **Delete**
(Return) deletes the file; this cannot be undone. **Cancel** (Esc or the
right button) keeps it.

### Playing and the result page

A level plays in its own style with 60 lemmings, its own skills and its
own clock. At the end the result page shows how many you saved and the
grade by the game's rule, without changing any tribe's progress:
**Replay** (R) plays it again, **Edit** (E) opens it in the editor, and
**Levels** (Esc) goes back to the list.

## The editor

The level is shown in the game's own view with the game's skill panel,
and the **editor bar** below it:

```
Terrain Objects Param Test          Undo Redo Save Menu
(the tools of the mode)
(the status: what is under the pointer)              Unsaved
(help: the button under the pointer and its key, or a message)   V1.2 by Timo Heimonen
```

The active mode and the tools that are on are lit; a button that does
nothing at the moment is dark; "Unsaved" shows that the level has changes
that are not saved. Hold the pointer over a button to see what it does
and its key. The editor's version is at the right end of the help line,
in blue, when the help leaves room for it (shortened to "V1.2 by Timo
H." when only that fits); the help always comes first.

**Scrolling**: move the pointer to the left, right or top edge of the
level, or to the bottom of the screen below the bar's buttons, or hold a
cursor key.

### Terrain (T)

The brush, a piece of terrain or a single tile, follows the pointer on
the 16x8-pixel cells.

| Button | Key | What it does |
| --- | --- | --- |
| Pieces | P | Choose a piece from the style's pieces; a right click there takes one tile |
| Erase | R, or the right button in the level | Erase the cells of the brush's shape instead of drawing |
| Pick | K | Take a tile of the level, with its flags, as the brush |
| Decor | D | Lemmings pass through the cells drawn |
| Steel | I | The cells drawn cannot be dug or bashed away |

Click to draw; hold the button to draw on with a single tile or the
eraser. Decor and Steel start as the style's levels usually have them for
the brush's tiles.

### Objects (O)

| Button | Key | What it does |
| --- | --- | --- |
| Types | P | Choose the type of object to place: entrances, exits, water, traps and devices, scenery |
| Delete | Del, or the right button on an object | Delete the selected object |
| W - + | - and + (or =) | Fewer or more copies side by side, for objects that repeat |
| H - + | [ and ] | Fewer or more copies one under another |
| < > | , and . | Select the previous or next object in placement order |

The chosen type follows the pointer where no object is, and the object
page shows every type: both play their animations at the game's speed
(water and fires flow, an entrance opens, a trap springs), so you see what
each object does. The frame round the pointer's object is its size when
placed. The level's own objects stay still until you play it.

Click where no object is to place one; click an object to select it, and
hold the button to move it; while you hold it, the keys wait. The status line names the object under the
pointer and what the game does with it: an entrance's turn, a
teleporter's partner, a switch's target. The game takes their order from
the order of placing: entrances release lemmings in turn, teleporters pair
up first with second, third with fourth, and switch n works target n.

**Warnings** never stop you: the help line names the first problem, such
as no entrance, no exit, more than four entrances (only four work), a
teleporter without a partner or a switch without a target. Saving and
test play say so too. A level without an entrance plays with no lemming
coming out until its time is up.

### Param (L): the level's parameters

| Button | Key | What it does |
| --- | --- | --- |
| Title | N | Type the level's title, up to 24 characters (Return keeps it, Esc the old one) |
| Skills | P | Choose the eight skills with the game's own skill picker (Esc or the right button keeps the old ones); it offers only the skills the level's style can use |
| Remove | Del | Remove the selected skill |
| Count - + | - and + (or =) | The selected skill's count, 1 to 99 |
| < > | , and . | Select the skill to the left or right (or click it in the panel) |
| Start | V | Start the level with the view as it is now; a frame shows the start view |
| Limits | Shift+V | Set how far the level scrolls, which is also where its lemmings can go (below); a dotted frame shows it |
| Time - + | [ and ] | The time, in quarter minutes, 0:15 to 9:45 |
| Rate - + | Shift+R and R | How fast the lemmings come out, 0 to 20 |
| Lost - + | Shift+G and G | The best grade's limit: how many lemmings may be lost for grade 3, 0 to 59 |

A level always has 60 lemmings: the game takes the number from the
tribe's progress, and a custom level has none.

**Skills and the style.** Two skills work only in some styles: the
**Blocker** only in Classic levels, the **Attractor** in every style but
Classic. In a Classic level the picker shows the Blocker in the
Attractor's place; in the other styles it shows the Attractor and has no
Blocker. A level made elsewhere with such a skill loses it when it is
opened, with a message, and the level is unsaved until you save it; when
it is played from the list, it is played without that skill and its file
stays as it is.

**Scroll limits.** A level scrolls over the whole map unless you limit
it. **Limits** (Shift+V) opens a page of the bar whose first line names
the cells the level can show. Scroll the view to where the level's view
should go no further and click **Top left** (T) or **Bottom right** (B):
the level then scrolls no further up and left, or down and right, than
the view you see. **Whole map** (W) lets it scroll over the whole map
again. The dotted frame follows at once; the start view, and the other
corner when the two would cross, move along. **OK** (Return) keeps the
limits, **Cancel** (Esc) the old ones. A start view set outside the
limits widens them just enough.

The limits are also the edge of the level for the lemmings: the game
takes away a lemming that goes past the dotted frame's left, top or right
side, or falls 8 pixels below its bottom side, as if it had walked off
the map. With the whole map it lies just inside the map's own edge.

### Test, undo and saving

| Button | Key | What it does |
| --- | --- | --- |
| Test | E | Play the level as it is now, saved or not; Esc, or Edit at the end, returns to the editor as you left it |
| Undo | U | Undo the last change, up to 32 |
| Redo | Shift+U | Redo the change undone |
| Save | S | Save the level to its file |
| Menu | Esc | Back to the list; with unsaved changes it asks first: Save (Return), Discard (D) or Cancel (Esc) |

A change is everything done until you let go of the mouse button and the
keys: a stroke of the brush, a move of an object, a held + button. **M**
switches the music on or off.

## Files

- A level is one file of 8648 bytes, the game's own level record, with a
  name ending in `.lvl` in the `Levels` directory. Copy the files to share
  your levels; a level file from elsewhere can be put in `Levels` and
  appears in the list.
- The editor writes only your level files. The game's levels, the tribes'
  progress and the saved positions stay as they are.
