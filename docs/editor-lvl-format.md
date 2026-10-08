# Amiga Lemmings 2: The Tribes level file format (`.lvl`)

08.10.2026 Timo Heimonen (timo.heimonen@proton.me)

This document describes the `.lvl` files of the in-game level editor for
Amiga Lemmings 2: The Tribes. A level file holds one level: exactly 8648
bytes, an IFF-style `FORM` of type `L2LV` with four chunks and no
checksum. The format is the game's own level record, the one it keeps
for its own levels, so the game fixes it: it has no version and does not
change, the file holds no version field, and every version of the editor
reads and writes the same format. The document gives every byte of the
file: the fields, what the editor writes there, the values the game takes
and what each value does in the game. "The editor" below is that level
editor, and "the original levels" are the game's own 124 levels (120
tribe levels and 4 Practice levels).

Some of what a level needs is not in the file: the number of lemmings (a
tribe's first level, and every level the editor plays, has 60), and the
music, the tribe's art and the style's graphics, which come with the tribe
the level is played in.

## Overview

The `FORM` and chunk headers and the map are big-endian; the other three
chunks' words are little-endian. Offsets are hexadecimal and count from
the start of the file.

| Offset | Size | Content |
| --- | ---: | --- |
| `$0000` | 12 | `FORM`, size `$000021C0` (BE32, the file less 8), type `L2LV` |
| `$000C` | 8 | Chunk header `L2LH`, size 74 |
| `$0014` | 74 | Level header: title, skills, time, start view, scroll limits, grading, release rate |
| `$005E` | 8 | Chunk header `L2MH`, size 6 |
| `$0066` | 6 | Map header: style and map shape |
| `$006C` | 8 | Chunk header `L2MP`, size 7884 |
| `$0074` | 7884 | Map: 1971 cells of 4 bytes, BE32 |
| `$1F40` | 8 | Chunk header `L2BO`, size 640 |
| `$1F48` | 640 | Objects: 64 placements of five LE16 words |

The game does not use the word at `L2LH` +`$34` (a copy of the style),
the bytes at `L2LH` +`$31`, +`$33` and +`$46..$49`, the word at `L2MH` +4
and the map cells past the map's size; the tables below say what to write
there.

### The container

The file starts with `FORM`, the size of the rest of the file and the type
`L2LV`. Each chunk is a 4-byte tag, a BE32 size and the payload; sizes are
not rounded up to even. A level file must have exactly the four chunks of
the table, in that order and with those sizes: the game takes a chunk's
size as it is, so an `L2MP` of another size breaks the game, and the
editor lists a file whose tags or sizes differ as damaged.

## A file the editor writes

What the editor writes into the fields is the editor's behavior, not
part of the format. This section, the "The editor writes" columns and the
other notes on the editor below describe editor versions 1.0 to 1.2; a
later version that writes otherwise changes only them.

The editor saves the level it edits as one 8648-byte file in the layout
above. It changes only what is edited and keeps every other byte of the
file as it was, the unused bytes and the leftovers of a file from
elsewhere too; the tables below give what it writes in each field.

A **new level** (the New page: a file name, a style and a map shape) has
every byte 0 except:

- the `FORM` and chunk headers of [the overview](#overview);
- the title: the file name without `.lvl` (up to 20 letters, digits, `-`
  and `_`, as typed), padded with spaces to 24 bytes;
- the skills Climber (18), Floater (22), Exploder (24), Blocker (51),
  Builder (19), Basher (20), Miner (21) and Digger (17), ten of each; in
  any style but Classic without the Blocker, so that the last slot is
  empty (ID 0, count 0);
- the time 5:00;
- the style in both style words, and the shape;
- the highest scroll: the map's largest scroll (start view and lowest
  scroll 0, 0);
- every placement empty: the 640 bytes of `L2BO` all `$FF`.

The map is all 0 (empty cells), and the grading and the release rate are
0.

## Coordinates

A level's map is a grid of cells of 16 x 8 pixels. `L2MH` +2 selects one
of seven shapes:

| Shape | Columns x rows | Pixels | Largest scroll x, y | Original levels |
| ---: | --- | --- | --- | ---: |
| 0 | 82 x 24 | 1312 x 192 | 1120, 0 | 15 |
| 1 | 66 x 28 | 1056 x 224 | 704, 32 | 1 |
| 2 | 52 x 36 | 832 x 288 | 480, 96 | 11 |
| 3 | 42 x 44 | 672 x 352 | 320, 160 | 61 |
| 4 | 34 x 54 | 544 x 432 | 192, 240 | 20 |
| 5 | 26 x 68 | 416 x 544 | 64, 352 | 6 |
| 6 | 22 x 84 | 352 x 672 | 0, 480 | 10 |

Below, *x* and *y* are map pixels from the top left corner of the map:
0..*columns* * 16 - 1 and 0..*rows* * 8 - 1. Object origins, the start
view and the scroll limits use these coordinates. Cell (*column*, *row*)
covers *x* 16 * *column* .. + 15 and *y* 8 * *row* .. + 7, and is map cell
*row* * *columns* + *column*.

The screen shows 320 x 160 pixels of the map: from a scroll position
(*sx*, *sy*), map *x* *sx* + 16 .. *sx* + 335 and *y* *sy* + 16 .. *sy* +
175. The scroll moves in steps of 16 pixels; the largest scroll is
((*columns* - 22) * 16, *rows* * 8 - 192).

A lemming's position is the point it stands on: a lemming on a floor whose
top pixel row is at *y* has that *y*. The objects' contact points below
are given the same way.

**The border.** When a level starts, the first two and the last two cell
rows and the first and the last cell column of the map are emptied,
whatever the file holds there. Objects can still write there.

**The lemmings' box.** The scroll limits (header +`$3A..$40`) also bound
the lemmings: a lemming is lost when its *x* <= the lowest scroll *x* +
16, its *y* <= the lowest scroll *y* + 16, its *x* >= the highest scroll
*x* + 335 or its *y* >= the highest scroll *y* + 184, and terrain at or
past the right and bottom edges counts as empty. So the lemmings live in
the part of the map the level's views can show, plus 8 rows below the
lowest view, and narrowing the scroll limits shrinks the playfield, not
only the scrolling. With the whole map's limits the box is *x* 17 ..
*columns* * 16 - 18 and *y* 17 .. *rows* * 8 - 9.

## Level header (`L2LH`, `$0014..$005D`)

"+" offsets count from the start of the chunk's payload, at file offset
`$0014`.

| + | File | Size | Field | Values | The editor writes |
| --- | --- | --- | --- | --- | --- |
| `$00` | `$0014` | 24 | Title | See [the title](#title): no terminator, padded with spaces | The typed title, `$20..$7A` without `#`, padded with spaces |
| `$18` | `$002C` | 8 LE16 | Skill IDs | Slots 1..8 of the skill panel, left to right; 0 for an empty slot. See [skills](#skills) | The skills picked: eight distinct ones the style can use, the empty slots last after a removal. Opening a level takes out an Attractor in a Classic-style level and a Blocker in any other |
| `$28` | `$003C` | 8 bytes | Skill counts | The count of each slot: 1..99 for a used slot, 0 for an empty one | 1..99; 10 for a new skill; 0 for an empty slot |
| `$30` | `$0044` | byte | Minutes | Signed. See [the clock](#the-clock) | When changed, 0..9 |
| `$31` | `$0045` | byte | Unused | 0 | Kept |
| `$32` | `$0046` | byte | Seconds | Signed | When changed, 0, 15, 30 or 45 |
| `$33` | `$0047` | byte | Unused | 0 | Kept |
| `$34` | `$0048` | LE16 | Style copy | Not used: the map header's style counts. Write the same value | The style (a new level); kept |
| `$36` | `$004A` | LE16 | Start view *x* | The scroll position at the start. See [the start view](#the-start-view-and-the-scroll-limits) | By the rule below |
| `$38` | `$004C` | LE16 | Start view *y* | | By the rule below |
| `$3A` | `$004E` | LE16 | Lowest scroll *x* | Also the left edge of [the lemmings' box](#coordinates), + 16 | By the rule below |
| `$3C` | `$0050` | LE16 | Lowest scroll *y* | Also its top edge, + 16 | By the rule below |
| `$3E` | `$0052` | LE16 | Highest scroll *x* | Also its right edge, + 335 | By the rule below |
| `$40` | `$0054` | LE16 | Highest scroll *y* | Also its bottom edge, + 184 | By the rule below |
| `$42` | `$0056` | LE16 | Grading | Signed: the lemmings that may be lost for the best grade. See [grading](#grading) | 0..59 ("Lost"); 0 in a new level |
| `$44` | `$0058` | LE16 | Release rate | Signed. See [the release rate](#the-release-rate) | 0..20 ("Rate"); 0 in a new level |
| `$46` | `$005A` | 4 | Unused | 0 | Kept |

### The start view and the scroll limits

The view moves 16 pixels a step and stops only when it equals a limit, so
on each axis

    0 <= lowest <= start view <= highest <= the largest scroll

with the start view and both limits on one 16-pixel grid; otherwise the
view scrolls past a limit and off the map, and a start view or limits far
outside the map break the game. The original levels keep every word a
multiple of 16 (start views 0..960 and 0..352); the lowest scroll is 0, 0
in 119 of them, and the highest is the whole map's in 74.

The editor keeps this rule: when the start view or a limit is set, the
other limit on that axis moves to it if they would cross, onto its
16-pixel grid toward it, and the start view is put inside the limits on
the lower limit's grid; setting a start view outside the limits widens
them just enough.

### The clock

The minutes and seconds bytes are signed. The clock counts the seconds
down, taking a minute when they go below 0; the time is up when both are
0.

| Value | Result |
| --- | --- |
| 0:01 .. 9:59 | Counts down from it; the briefing and the panel show it. The original levels use 1:30 .. 9:59 |
| 0:00 | The time is up at once, before any lemming comes out |
| Minutes 10..127 | Counts down from it; the briefing and the panel show the minutes as one character, `'0'` + minutes: 10 is `:`, 12 `<` |
| Seconds 60..127 | Counts down from them before the first minute goes; 100 and more show a wrong tens character |
| Bytes `$80..$FF` | Negative: a negative minutes byte ends the level when its first second has run out |

A second of the clock is 50 fields on a PAL display. Write 0:01..9:59. The
editor steps the time in quarter minutes, 0:15..9:45, and keeps any value
from elsewhere until the time is changed.

### The release rate

After a lemming comes out, the next one comes 22 - *rate* passes of the
game's main loop later (a pass takes 4 fields at normal speed), and at
least one pass later: 21 and more release a lemming every pass.

| *rate* | Interval |
| ---: | --- |
| 0 | 22 passes |
| 20 | 2 passes |
| 21 | 1 pass |
| 30 | 1 pass |
| -10 (`$FFF6`) | 32 passes |

The original levels use 0, 5, 10, 12 and 15. The editor offers 0..20 as
"Rate".

### Grading

At the end of a level with at least one lemming saved, *lost* = the
level's lemmings - the saved ones, compared as signed numbers:

| Condition | Grade |
| --- | --- |
| *lost* <= this word | 3, the best |
| else *lost* <= lemmings / 2 | 2 |
| else | 1 |

The game keeps the saved count and the grade for the tribe and level when
the saved count is at least the kept one. A level with no lemming saved is
not graded. The original levels use 0..4; any value works, and a negative
one never gives the best grade. The editor calls it "Lost", 0..59. After
a tribe's level the game's result screen shows the grade as a place on a
podium: 3 is the first place ("a gold standard" rescue), 2 the second and
1 the third.

## Map header (`L2MH`, `$0066..$006B`)

| + | File | Size | Field | Values | The editor writes |
| --- | --- | --- | --- | --- | --- |
| 0 | `$0066` | LE16 | Style | 0..11, see the table below | The style chosen for a new level; never changed |
| 2 | `$0068` | LE16 | Map shape | 0..6, see [coordinates](#coordinates); a larger value breaks the game | The shape chosen for a new level; never changed |
| 4 | `$006A` | LE16 | Unused | 0 | Kept |

| Style | Name | Tiles | Object types | Original levels |
| ---: | --- | ---: | ---: | --- |
| 0 | classic | 542 | 14 | 10 |
| 1 | beach | 666 | 14 | 10 |
| 2 | cavelem | 721 | 13 | 10 |
| 3 | circus | 638 | 17 | 10 |
| 4 | egyptian | 613 | 18 | 10 + 1 Practice |
| 5 | highland | 655 | 14 | 10 |
| 6 | medieval | 601 | 12 | 10 + 1 Practice |
| 7 | outdoor | 613 | 15 | 10 |
| 8 | polar | 621 | 14 | 10 + 1 Practice |
| 9 | shadow | 554 | 23 | 10 |
| 10 | space | 762 | 13 | 10 + 1 Practice |
| 11 | sports | 472 | 18 | 10 |

The style selects the level's tiles and object types, and a level must
use tiles and object types of its style. The game shows the graphics,
tune and art of the tribe the level is played in, so a level's style must
be that tribe's: every original tribe level has its tribe's style, and the
editor plays a custom level with its style as the tribe. Two skills depend
on the style (see [skills](#skills)), and a Classic-style level (0) has no
clickable controls.

## Map (`L2MP`, `$0074..$1F3F`)

1971 cells of a BE32 each. Only the first *columns* * *rows* cells, in
row order, are the map; the rest are not used (seven original levels hold
leftovers there). Each cell:

| Bits | Field | Meaning |
| --- | --- | --- |
| 0..9 | Tile | The style's tile, 0..its count - 1 (table above); tile 0 is empty. A tile past the count draws whatever follows the style's tiles, and lemmings collide with that |
| 10 | Unused | No effect. Set in 1625 cells of 9 original levels, as leftovers. Write 0 |
| 11..12 | Interaction class | Written by objects. Bit 12 alone: a direct effect (bits 22..27); bit 11 alone: a link to an object; both: a clickable control. See [interaction](#interaction) |
| 13..16 | Point *x* | The interaction point's *x* in the cell, 0..15 |
| 17..19 | Point *y* | Its *y* in the cell, 0..7 |
| 20..21 | Match mode | 0 the whole cell; 1 the lemming exactly at the point; 2 within 2 pixels of it on both axes; 3 within 4, the limits included. The point is taken in the cell under the lemming, so the window ends at that cell's edges |
| 22..27 | Link or effect | With bit 11: the link number, 0..63, which the objects get when the level starts; with bit 12 alone: the direct effect, 0 exit, 1 water, 2 ice |
| 28 | Indestructible | The Digger, Basher, Miner, Scooper, Twister and Stomper stop at it, and explosions and other changes to the terrain leave its tile whole |
| 29 | Dance mark | Set by the game around an Attractor. Write 0 |
| 30 | Non-colliding | The tile is drawn, but lemmings pass through it |
| 31 | Redraw | Set by the game for cells to redraw. Write 0 |

**What to write.** A cell of a level file is a tile with bits 28 and 30 as
wanted; leave bits 10..27, 29 and 31 at 0, since the objects write the
interaction fields themselves. The editor writes a drawn cell whole: the
tile, bit 30 when the brush is Decor and bit 28 when it is Steel, and
every other bit 0; an erased cell is 0. A brush picks its Decor and Steel
from the bits its tiles usually have in the original levels. Tile 0 in a
terrain piece leaves the cell as it was. The editor never changes the
border cells or the cells past the map, so they keep what the file has (0
in a new level). Interaction bits in the file act without an
object: a direct effect works as such (Medieval 7 and 8 carry the cells of
exits that were moved, and three of Medieval 7's still save lemmings), a
link number refers to whatever object gets that link, and a direct effect
3..63 breaks the game.

**Tiles.** Most of the original levels' tiles come from the style's
terrain pieces; tiles past the pieces' ones are the frames of the style's
animated blocks. In the original levels a tile usually has the same bits
28 and 30 wherever it is used: 409 style and tile pairs are usually
non-colliding decoration (none in Classic and Sports), and one Cavelem
tile is usually indestructible. Objects write their own tiles over the
map cells when the level starts.

## Objects (`L2BO`, `$1F48..$21C7`)

64 placements of five LE16 words, ten bytes each:

| + | Field |
| --- | --- |
| 0 | Type, signed: the style's object type, or negative for an empty placement |
| 2 | *x*, signed: the type's origin in map pixels, a multiple of 16 |
| 4 | *y*, signed, a multiple of 8 |
| 6 | Repeats across, signed: the copies after the first |
| 8 | Repeats down, signed |

**Empty placements.** A placement with a negative type is skipped,
whatever its other words. The original levels hold `-1` in all five words
in 4279 of their 5212 empty places and leftovers in the rest. Write
`FF FF FF FF FF FF FF FF FF FF`. The editor lists a type other than `-1`
that the style lacks as damaged.

**What the editor writes.** A new object goes into the first empty place
after the last object, or into the first empty place when none is left
after it, as its type, its origin and repeats 0, 0. Its origin is on
the cell grid, and its cells stay inside the part of the map the editor
edits, 16 pixels from each edge. A moved object keeps its place and gets
its new origin; a deleted one becomes five `-1` words, so the other objects
keep their places. The repeats are 0..40, and an edit that would take an
object out of that part of the map or make the built objects larger than
4096 bytes is refused.

**Order matters.** The objects are built in placement order, and later
ones write over the cells of earlier ones. The order also numbers things:
entrances release lemmings in turn in placement order; teleporters pair in
placement order, the first with the second, the third with the fourth;
switches and switch targets are numbered in placement order, and switch
*n* toggles target *n* (see [switches and
teleporters](#switches-and-teleporters)). A tool must not compact or
reorder the placements.

**On the cell grid.** *x* must be a multiple of 16 and *y* of 8. Off the
grid the game writes the type's tiles and attributes across two cells
each, which damages the cells next to it and can turn them into links or
exits. Every original origin is on the grid, the editor places objects on
it, and it lists a file with an origin off it as damaged.

**Repeats.** A type is a list of parts, and a part may repeat across or
down: the [type tables](#object-types) give the axes each type uses, and
a count on another axis is ignored. A count *n* of 0 or more gives *n* + 1
copies, a negative count one copy, and -32768 gives 32769. The original
levels use 0..18 across and 0..16 down; the editor allows 0..40.

**Left of and above the map.** The type tables' *Offset* gives where a
type's first cells lie from its origin, and every other cell lies right of
or below it. The origin plus the offset must be 0 or more on both axes: a
cell left of or above the map is not clipped, and the game writes it far
from the map, into its own data or code. Left of the map it lands in the
packed original levels of the Classic and Beach tribes, and the game then
stops when it next starts one of those levels; above the map it lands
wherever a word of the game's code points. Every original level keeps
this; its origins with a negative *x* (-16 and -32) are types whose
offset brings their cells into the map.

**Below the map.** A part written past the map's last row goes on in the
1971 cells and past them into the game's other data, without clipping.
The original levels stay inside the 1971 cells.

**Limits.**

- At most 64 placements (the chunk's size).
- At most 64 links in a level: the cells of objects beyond the 64th link
  get no link.
- The built objects take 22 bytes each, 8 more for each part and repeat,
  and 4 at the end, and must fit 4096 bytes; nothing checks it, and past
  it the game writes over its own data. The original levels need at most
  2548.
- One to four entrances: a fifth and later ones are ignored, and a level
  without an entrance releases no lemming in the editor and breaks the
  unpatched game.
- At most 32 switches and 32 switch targets (see [switches and
  teleporters](#switches-and-teleporters)).
- At most five swinging objects, each with 0..7 repeats down (its rope).
  The original levels have at most two, with 1..7. Nothing checks it: a
  sixth swinging object breaks the first one's rope, and a rope with more
  than 7 repeats down hangs still and does not swing.
- A type the style lacks, or an origin far outside the map, breaks the
  game. The original levels have origins *x* -32..1248 and *y* 8..648.

### Entrances and exits

An entrance releases lemmings at a point from its origin that depends on
the style:

| Styles | Release point |
| --- | --- |
| Classic, Egyptian, Outdoor, Polar, Shadow | (22, 8) |
| Circus, Sports | (22, 9) |
| Cavelem, Space | (22, 10) |
| Beach | (20, 8) |
| Highland | (16, 28) |
| Medieval | (22, 29) |

Lemmings come from the entrances in turn.

An exit's trigger points lie on the floor's top row under its door, with
match mode 1 (Beach's with mode 2); the [type tables](#object-types) give
them. Classic, Beach, Highland, Outdoor, Polar, Shadow and Sports exits
have one point; Cavelem, Circus, Egyptian, Medieval and Space exits have
two side by side across a cell edge (*x* 15 and 16 from the origin), and
their tall exits (Cavelem 11, Medieval 10, Space 11) the same pair again
8 pixels lower. A lemming that reaches one walks in and is saved. Every
original tribe level has an exit; the four Practice levels have none.

### Interaction

A lemming acts on the cell under it when that cell has bit 11 or 12 and
the lemming matches the cell's point by its match mode. A lemming already
busy (one walking into an exit, for example) is not affected.

| Class | Effect | What happens |
| --- | --- | --- |
| Bit 12 alone | 0, exit | The lemming walks into the exit and is saved |
| | 1, water | A Swimmer swims; any other lemming drowns |
| | 2, ice (Polar's type 12) | A Skater skates; any other lemming slips, see [ice](#ice) |
| | 3..63 | Breaks the game; never write it |
| Bit 11 alone | Trap | The lemming is lost, one at a time: while the trap's animation runs, the next lemming passes |
| | Timed hazard | While its animation is in a window of frames, a lemming there is killed: by Classic 4 at once, by Sports 8 as by a long fall |
| | Launcher | Throws the lemming, with speeds of at most 8 pixels a step: Cavelem 3 up and to the left and Outdoor 3 up and to the right, both on contact; the Sports launchers 9 and 10 up or down in the lemming's direction and 11 and 12 to the left or right, while they are switched on |
| | Switch | Toggles its switch target, see [switches and teleporters](#switches-and-teleporters) |
| | Bouncer | A jumping, flying or falling lemming bounces up (a faller becomes a jumper) |
| | Teleporter | Moves the lemming to the partner, see [switches and teleporters](#switches-and-teleporters) |
| | Cannon, catapult, grabber | See [devices](#devices) |
| | Other links | Nothing: they tie a control or other cells to their object |
| Both bits | | Nothing on contact: a clickable control, see below |

### Ice

A lemming without the Skater skill that touches Polar ice slips: it slides
one pixel at a time for 16 steps, lies on the ice for a while, turns round
and slides back, each slide back ending one pixel short. A slide ends
where the ice ends or the ground rises, and the lemming walks on. Ice
wider than a slide (15 pixels) holds such lemmings for minutes.

### Clickable controls

In any style but Classic, holding the left button on a cell with bits 11
and 12 acts on its object (the type tables give the cells):

| Object | What the click does |
| --- | --- |
| Cannon (Circus 2, Highland 2, Polar 3, Shadow 3) | Moves the cannon one pixel left or right a pass, between the limits its placement sets |
| Catapult (Medieval 3) | The same for the catapult |
| Swinging object | The lemmings holding on to it let go and fly off with its swing |

### Devices

- **Cannon** (Circus 2, Highland 2, Polar 3, Shadow 3). A lemming exactly
  at the cannon's loading point, (20, 0) from its origin at the start,
  climbs in when the cannon is empty; the cannon fires it after 45 passes,
  during which the player can move it along its track with its controls,
  and the loading point moves with it. The track's repeats across lengthen
  the way it can move.
- **Catapult** (Medieval 3). The same, with the loading point at (40, 0)
  from its origin at the start, firing after 51 passes.
- **Grabber** (Medieval 4, Space 6, Space 7). A lemming at one of its
  points starts it; it opens, takes the lemmings that come while it is
  open (they are lost, not saved), and closes when none has come for 20
  of its updates. Medieval 4 and Space 6 are updated twice a pass, so they
  move twice as fast.

### Switches and teleporters

- **Switches** (Egyptian 3, Shadow 20, Sports 13) are numbered 0..31 in
  placement order; a 33rd and later switch acts as switch 0.
- **Switch targets** are Egyptian 4, Shadow 21 and the Sports launchers
  9..12, numbered 0..31 in placement order. A target starts on; a 33rd
  and later target is off and stays off, as no switch reaches it.
- A lemming at a switch's point works the switch, and target *n* of
  switch *n* turns off or on. A switch without a target of its number does
  nothing. A Sports launcher that is off shows nothing and throws nobody.
- **Egyptian 4 and Shadow 21 are pourers**: while on, from the first
  lemming's release, they pour a stream from (8, 8) of their origin that
  heaps up as terrain, as the Filler's does; off, they stop. They look the
  same on and off. No original level places them.
- **Teleporters** (Space 8) pair in placement order. A lemming at a
  teleporter's point is moved to its partner's point, (8, 16) from the
  partner's origin, and both teleporters rest until their animations have
  played. A last teleporter without a partner sends the lemmings to (0,
  0) under WHDLoad, where they stay stuck: always place teleporters in
  pairs. The original levels have 2, 4, 8 and 10 in a level.

### Object types

The object types of each style. *Size* is the size of the bounding box of
the type's tiles at no repeats; a type may also have sprites, drawn over
the map, from its style or common to all styles (such as the swings'
ropes). *Offset* is where the box's top left corner lies from the
placement's origin: most scenery and water types draw 16 or 32 pixels
right of their origin and several exits 8 pixels above it. *Contact* names
the type's [interaction](#interaction) effects with their match modes and
where they act from the origin: the point, or, for the mode *cell*, the
top left corner of the cell. *Click* names its
[controls](#clickable-controls) with the top left corners of their cells.
Contact points and cells move with the repeats like the parts that carry
them. *Repeats* gives the axes its repeat counts act on.

Roles: an **entrance** releases lemmings; an **exit** saves them;
**water** drowns all but Swimmers; a **trap** removes lemmings one at a
time; a **timed hazard** acts during part of its animation; a **launcher**
throws lemmings; a **bouncer** bounces jumping lemmings; a **swinging
object** carries a lemming that catches it; a **switch** toggles its
**switch target**; a **teleporter** moves lemmings to its partner; a
**device** is a cannon, a catapult or a grabber; **ice** is the Polar
type with direct effect 2; **scenery** does nothing to lemmings, and its
tiles are terrain unless they are non-colliding.

Classic (14 types):

| Type | Role | Size | Offset | Contact | Click | Repeats |
| ---: | --- | --- | --- | --- | --- | --- |
| 0 | entrance | 48 x 24 | (0, 0) | - | - | - |
| 1 | exit | 48 x 24 | (0, 0) | exit (exact) at (26, 24) | - | - |
| 2 | trap | 32 x 40 | (0, 0) | trap (exact) at (14, 40) | - | - |
| 3 | trap | 16 x 40 | (0, 0) | trap (exact) at (7, 40) | - | - |
| 4 | timed hazard | 80 x 24 | (0, 0) | timed hazard (cell) at (16, 16), (32, 16), (16, 24), (32, 24) | - | - |
| 5 | scenery | 16 x 8 | (16, 0) | - | - | across |
| 6 | water | 16 x 8 | (16, 0) | water (cell) at (16, 0) | - | across, down |
| 7 | scenery | 32 x 32 | (32, 0) | - | - | across, down |
| 8 | scenery | 16 x 32 | (16, 0) | - | - | across, down |
| 9 | scenery | 16 x 16 | (16, 0) | - | - | across, down |
| 10 | scenery | 16 x 8 | (16, 0) | - | - | across, down |
| 11 | scenery | 16 x 8 | (16, 0) | - | - | across, down |
| 12 | scenery | 16 x 8 | (16, 0) | - | - | across, down |
| 13 | exit | 48 x 32 | (0, 0) | exit (exact) at (26, 24) | - | - |

Beach (14 types):

| Type | Role | Size | Offset | Contact | Click | Repeats |
| ---: | --- | --- | --- | --- | --- | --- |
| 0 | entrance | 48 x 24 | (0, 0) | - | - | - |
| 1 | exit | 32 x 48 | (0, -8) | exit (2 px) at (12, 40) | - | - |
| 2 | trap | 32 x 24 | (0, 0) | trap (exact) at (15, 24) | - | - |
| 3 | trap | 32 x 56 + 1 style sprite | (0, 0) | trap (exact) at (15, 56) | - | - |
| 4 | scenery | 32 x 16 | (0, 0) | - | - | - |
| 5 | swinging object | 32 x 40 + 2 common sprites | (0, 0) | - | let go at (0, 24), (16, 24) | down |
| 6 | scenery | 16 x 8 | (16, 8) | - | - | across |
| 7 | water | 16 x 8 | (16, 0) | water (cell) at (16, 0) | - | across, down |
| 8 | scenery | 32 x 32 | (32, 0) | - | - | across, down |
| 9 | scenery | 32 x 16 | (32, 0) | - | - | across, down |
| 10 | scenery | 16 x 32 | (16, 0) | - | - | across, down |
| 11 | scenery | 16 x 16 | (16, 0) | - | - | across, down |
| 12 | scenery | 16 x 8 | (16, 0) | - | - | across, down |
| 13 | exit | 32 x 56 | (0, -8) | exit (2 px) at (12, 40) | - | - |

Cavelem (13 types):

| Type | Role | Size | Offset | Contact | Click | Repeats |
| ---: | --- | --- | --- | --- | --- | --- |
| 0 | entrance | 48 x 16 | (0, 0) | - | - | - |
| 1 | exit | 64 x 32 | (-16, -8) | exit (exact) at (15, 24), (16, 24) | - | - |
| 2 | trap | 32 x 24 | (0, 0) | trap (exact) at (15, 24) | - | - |
| 3 | launcher | 48 x 24 | (0, 0) | launcher (2 px) at (34, 24) | - | - |
| 4 | swinging object | 32 x 40 + 2 common sprites | (0, 0) | - | let go at (0, 24), (16, 24) | down |
| 5 | scenery | 16 x 8 | (16, 0) | - | - | across |
| 6 | water | 16 x 8 | (16, 0) | water (cell) at (16, 0) | - | across, down |
| 7 | scenery | 32 x 32 | (32, 0) | - | - | across, down |
| 8 | scenery | 16 x 16 | (16, 0) | - | - | across, down |
| 9 | scenery | 16 x 16 | (0, 0) | - | - | - |
| 10 | scenery | 16 x 16 | (0, 0) | - | - | - |
| 11 | exit | 64 x 48 | (-16, -8) | exit (exact) at (15, 24), (16, 24), (15, 32), (16, 32) | - | - |
| 12 | bouncer | 16 x 16 | (0, 0) | bouncer (cell) at (0, 8) | - | - |

Circus (17 types):

| Type | Role | Size | Offset | Contact | Click | Repeats |
| ---: | --- | --- | --- | --- | --- | --- |
| 0 | entrance | 48 x 24 | (0, 0) | - | - | - |
| 1 | exit | 32 x 32 | (0, -8) | exit (exact) at (15, 24), (16, 24) | - | - |
| 2 | device | 64 x 8 + 1 style sprite | (0, 0) | cannon (cell) at (16, 0), (32, 0) | move left at (0, 0); move right at (48, 0) | across |
| 3 | bouncer | 16 x 16 | (0, 0) | bouncer (cell) at (0, 8) | - | - |
| 4 | scenery | 16 x 8 | (0, 0) | - | - | - |
| 5 | scenery | 16 x 8 | (0, 0) | - | - | - |
| 6 | scenery | 16 x 8 | (0, 0) | - | - | - |
| 7 | scenery | 16 x 8 | (0, 0) | - | - | - |
| 8 | scenery | 32 x 40 | (0, 0) | - | - | down |
| 9 | scenery | 32 x 40 | (0, 0) | - | - | down |
| 10 | swinging object | 32 x 40 + 2 common sprites | (0, 0) | - | let go at (0, 24), (16, 24) | down |
| 11 | scenery | 32 x 32 | (32, 0) | - | - | across, down |
| 12 | scenery | 32 x 16 | (32, 0) | - | - | across, down |
| 13 | scenery | 16 x 8 | (16, 0) | - | - | across, down |
| 14 | scenery | 16 x 16 | (16, 0) | - | - | across, down |
| 15 | scenery | 16 x 32 | (16, 0) | - | - | across, down |
| 16 | exit | 32 x 40 | (0, -8) | exit (exact) at (15, 24), (16, 24) | - | - |

Egyptian (18 types):

| Type | Role | Size | Offset | Contact | Click | Repeats |
| ---: | --- | --- | --- | --- | --- | --- |
| 0 | entrance | 48 x 24 | (0, 0) | - | - | - |
| 1 | exit | 32 x 32 | (0, -8) | exit (exact) at (15, 24), (16, 24) | - | - |
| 2 | trap | 32 x 24 | (0, 0) | trap (exact) at (15, 24) | - | - |
| 3 | switch | 16 x 8 | (0, 0) | switch (exact) at (8, 8) | - | - |
| 4 | switch target | 16 x 8 | (0, 0) | - | - | - |
| 5 | scenery | 16 x 24 | (0, 0) | - | - | - |
| 6 | scenery | 16 x 8 | (0, 0) | - | - | - |
| 7 | scenery | 16 x 8 | (0, 0) | - | - | - |
| 8 | swinging object | 32 x 40 + 2 common sprites | (0, 0) | - | let go at (0, 24), (16, 24) | down |
| 9 | scenery | 16 x 8 | (16, 0) | - | - | across |
| 10 | water | 16 x 8 | (16, 0) | water (cell) at (16, 0) | - | across, down |
| 11 | scenery | 32 x 32 | (32, 0) | - | - | across, down |
| 12 | scenery | 32 x 16 | (32, 0) | - | - | across, down |
| 13 | scenery | 16 x 32 | (16, 0) | - | - | across, down |
| 14 | scenery | 16 x 16 | (16, 0) | - | - | across, down |
| 15 | scenery | 16 x 8 | (16, 0) | - | - | across, down |
| 16 | exit | 32 x 40 | (0, -8) | exit (exact) at (15, 24), (16, 24) | - | - |
| 17 | bouncer | 16 x 16 | (0, 0) | bouncer (cell) at (0, 8) | - | - |

Highland (14 types):

| Type | Role | Size | Offset | Contact | Click | Repeats |
| ---: | --- | --- | --- | --- | --- | --- |
| 0 | entrance | 32 x 40 | (0, 0) | - | - | - |
| 1 | exit | 32 x 40 | (0, 0) | exit (exact) at (22, 40) | - | - |
| 2 | device | 64 x 8 + 1 style sprite | (0, 0) | cannon (cell) at (16, 0), (32, 0) | move left at (0, 0); move right at (48, 0) | across |
| 3 | swinging object | 32 x 40 + 2 common sprites | (0, 0) | - | let go at (0, 24), (16, 24) | down |
| 4 | trap | 32 x 32 | (0, 0) | trap (exact) at (11, 32) | - | - |
| 5 | scenery | 16 x 24 | (0, 0) | - | - | - |
| 6 | scenery | 16 x 8 | (16, 0) | - | - | across |
| 7 | water | 16 x 8 | (16, 0) | water (cell) at (16, 0) | - | across, down |
| 8 | scenery | 32 x 16 | (32, 0) | - | - | across, down |
| 9 | scenery | 32 x 32 | (32, 0) | - | - | across, down |
| 10 | scenery | 16 x 16 | (16, 0) | - | - | across, down |
| 11 | scenery | 16 x 8 | (16, 0) | - | - | across, down |
| 12 | exit | 32 x 48 | (0, 0) | exit (exact) at (22, 40) | - | - |
| 13 | bouncer | 16 x 16 | (0, 0) | bouncer (cell) at (0, 8) | - | - |

Medieval (12 types):

| Type | Role | Size | Offset | Contact | Click | Repeats |
| ---: | --- | --- | --- | --- | --- | --- |
| 0 | entrance | 48 x 32 | (0, 0) | - | - | - |
| 1 | exit | 48 x 40 | (0, 0) | exit (exact) at (15, 40), (16, 40) | - | - |
| 2 | swinging object | 32 x 40 + 2 common sprites | (0, 0) | - | let go at (0, 24), (16, 24) | down |
| 3 | device | 64 x 8 + 2 style sprites | (0, 0) | catapult (cell) at (16, 0), (32, 0) | move left at (0, 0); move right at (48, 0) | across |
| 4 | device | 48 x 24 + 1 style sprite | (0, 0) | grabber (4 px) at (12, 24); grabber (2 px) at (18, 26) | - | - |
| 5 | scenery | 16 x 24 | (0, 0) | - | - | - |
| 6 | scenery | 16 x 8 | (16, 0) | - | - | across |
| 7 | water | 16 x 8 | (16, 0) | water (cell) at (16, 0) | - | across, down |
| 8 | scenery | 32 x 32 | (32, 0) | - | - | across, down |
| 9 | scenery | 16 x 16 | (16, 0) | - | - | across, down |
| 10 | exit | 48 x 56 | (0, 0) | exit (exact) at (15, 40), (16, 40), (15, 48), (16, 48) | - | - |
| 11 | bouncer | 16 x 16 | (0, 0) | bouncer (cell) at (0, 8) | - | - |

Outdoor (15 types):

| Type | Role | Size | Offset | Contact | Click | Repeats |
| ---: | --- | --- | --- | --- | --- | --- |
| 0 | entrance | 48 x 24 | (0, 0) | - | - | - |
| 1 | exit | 32 x 32 | (0, 0) | exit (exact) at (7, 32) | - | - |
| 2 | swinging object | 32 x 40 + 2 common sprites | (0, 0) | - | let go at (0, 24), (16, 24) | down |
| 3 | launcher | 32 x 24 | (0, 0) | launcher (4 px) at (4, 13) | - | - |
| 4 | trap | 32 x 24 | (0, 0) | trap (exact) at (10, 24) | - | - |
| 5 | scenery | 16 x 8 | (0, 0) | - | - | - |
| 6 | scenery | 64 x 16 | (0, 0) | - | - | - |
| 7 | scenery | 16 x 8 | (16, 0) | - | - | across |
| 8 | water | 16 x 8 | (16, 0) | water (cell) at (16, 0) | - | across, down |
| 9 | scenery | 16 x 8 | (16, 0) | - | - | across |
| 10 | water | 16 x 8 | (16, 0) | water (cell) at (16, 0) | - | across, down |
| 11 | scenery | 16 x 16 | (16, 0) | - | - | across, down |
| 12 | scenery | 16 x 8 | (16, 0) | - | - | across, down |
| 13 | scenery | 16 x 8 | (0, 0) | - | - | - |
| 14 | exit | 32 x 40 | (0, 0) | exit (exact) at (7, 32) | - | - |

Polar (14 types):

| Type | Role | Size | Offset | Contact | Click | Repeats |
| ---: | --- | --- | --- | --- | --- | --- |
| 0 | entrance | 48 x 24 | (0, 0) | - | - | - |
| 1 | exit | 32 x 32 | (0, 0) | exit (exact) at (8, 32) | - | - |
| 2 | swinging object | 32 x 40 + 2 common sprites | (0, 0) | - | let go at (0, 24), (16, 24) | down |
| 3 | device | 64 x 8 + 1 style sprite | (0, 0) | cannon (cell) at (16, 0), (32, 0) | move left at (0, 0); move right at (48, 0) | across |
| 4 | scenery | 32 x 32 | (32, 0) | - | - | across, down |
| 5 | scenery | 16 x 16 | (16, 0) | - | - | across, down |
| 6 | scenery | 16 x 8 | (16, 0) | - | - | across, down |
| 7 | trap | 48 x 40 | (0, 0) | trap (4 px) at (20, 11) | - | - |
| 8 | scenery | 16 x 8 | (16, 8) | - | - | across |
| 9 | water | 16 x 8 | (16, 0) | water (cell) at (16, 0) | - | across, down |
| 10 | scenery | 16 x 8 | (0, 0) | - | - | - |
| 11 | scenery | 16 x 8 | (0, 0) | - | - | - |
| 12 | ice | 16 x 8 | (16, 8) | ice (cell) at (16, 8) | - | across |
| 13 | exit | 32 x 40 | (0, 0) | exit (exact) at (8, 32) | - | - |

Shadow (23 types):

| Type | Role | Size | Offset | Contact | Click | Repeats |
| ---: | --- | --- | --- | --- | --- | --- |
| 0 | entrance | 48 x 24 | (0, 0) | - | - | - |
| 1 | exit | 32 x 40 | (0, 0) | exit (exact) at (20, 40) | - | - |
| 2 | swinging object | 32 x 40 + 2 common sprites | (0, 0) | - | let go at (0, 24), (16, 24) | down |
| 3 | device | 64 x 8 + 1 style sprite | (0, 0) | cannon (cell) at (16, 0), (32, 0) | move left at (0, 0); move right at (48, 0) | across |
| 4 | scenery | 32 x 32 | (32, 0) | - | - | across, down |
| 5 | scenery | 16 x 32 | (16, 0) | - | - | across, down |
| 6 | scenery | 16 x 16 | (16, 0) | - | - | across, down |
| 7 | scenery | 16 x 8 | (16, 0) | - | - | across, down |
| 8 | scenery | 16 x 8 | (16, 0) | - | - | across, down |
| 9 | trap | 16 x 32 | (0, 0) | trap (exact) at (9, 32) | - | - |
| 10 | scenery | 16 x 24 | (0, 0) | - | - | - |
| 11 | scenery | 16 x 24 | (0, 0) | - | - | - |
| 12 | scenery | 16 x 24 | (0, 0) | - | - | - |
| 13 | scenery | 16 x 24 | (0, 0) | - | - | - |
| 14 | scenery | 16 x 8 | (16, 8) | - | - | across |
| 15 | water | 16 x 8 | (16, 0) | water (cell) at (16, 0) | - | across, down |
| 16 | scenery | 16 x 16 | (0, 0) | - | - | - |
| 17 | scenery | 16 x 16 | (0, 0) | - | - | - |
| 18 | scenery | 16 x 16 | (0, 0) | - | - | - |
| 19 | exit | 32 x 48 | (0, 0) | exit (exact) at (20, 40) | - | - |
| 20 | switch | 16 x 8 | (0, 0) | switch (exact) at (8, 8) | - | - |
| 21 | switch target | 16 x 8 | (0, 0) | - | - | - |
| 22 | bouncer | 16 x 16 | (0, 0) | bouncer (cell) at (0, 8) | - | - |

Space (13 types):

| Type | Role | Size | Offset | Contact | Click | Repeats |
| ---: | --- | --- | --- | --- | --- | --- |
| 0 | entrance | 48 x 16 | (0, 0) | - | - | - |
| 1 | exit | 32 x 32 | (0, 0) | exit (exact) at (15, 32), (16, 32) | - | - |
| 2 | swinging object | 32 x 40 + 2 common sprites | (0, 0) | - | let go at (0, 24), (16, 24) | down |
| 3 | scenery | 16 x 16 | (0, 0) | - | - | - |
| 4 | scenery | 32 x 32 | (32, 0) | - | - | across, down |
| 5 | scenery | 16 x 16 | (16, 0) | - | - | across, down |
| 6 | device | 32 x 32 | (0, 0) | grabber (4 px) at (12, 32), (20, 32) | - | - |
| 7 | device | 64 x 64 | (0, 0) | grabber (cell) at (0, 64) | - | - |
| 8 | teleporter | 16 x 16 | (0, 0) | teleporter (exact) at (8, 16) | - | - |
| 9 | scenery | 16 x 16 | (0, 0) | - | - | - |
| 10 | scenery | 80 x 24 | (0, 0) | - | - | - |
| 11 | exit | 32 x 48 | (0, 0) | exit (exact) at (15, 32), (16, 32), (15, 40), (16, 40) | - | - |
| 12 | scenery | 16 x 8 | (0, 0) | - | - | - |

Sports (18 types):

| Type | Role | Size | Offset | Contact | Click | Repeats |
| ---: | --- | --- | --- | --- | --- | --- |
| 0 | entrance | 48 x 24 | (0, 0) | - | - | - |
| 1 | exit | 16 x 24 | (0, 0) | exit (exact) at (0, 24) | - | - |
| 2 | swinging object | 32 x 40 + 2 common sprites | (0, 0) | - | let go at (0, 24), (16, 24) | down |
| 3 | scenery | 32 x 32 | (32, 0) | - | - | across, down |
| 4 | scenery | 16 x 32 | (16, 0) | - | - | across, down |
| 5 | scenery | 16 x 16 | (16, 0) | - | - | across, down |
| 6 | scenery | 16 x 8 | (16, 0) | - | - | across, down |
| 7 | scenery | 32 x 16 | (32, 0) | - | - | across, down |
| 8 | timed hazard | 16 x 32 | (0, 0) | timed hazard (cell) at (0, 32) | - | - |
| 9 | launcher | 1 style sprite | - | launcher (4 px) at (24, 4), (24, 12), (24, 20), (24, 28), (24, 36), (24, 44) | - | - |
| 10 | launcher | 1 style sprite | - | launcher (4 px) at (24, 4), (24, 12), (24, 20), (24, 28), (24, 36), (24, 44) | - | - |
| 11 | launcher | 1 style sprite | - | launcher (cell) at (0, 8), (16, 8), (32, 8), (0, 16), (16, 16), (32, 16) | - | - |
| 12 | launcher | 1 style sprite | - | launcher (cell) at (0, 8), (16, 8), (32, 8), (0, 16), (16, 16), (32, 16) | - | - |
| 13 | switch | 16 x 8 | (0, 0) | switch (exact) at (8, 8) | - | - |
| 14 | scenery | 16 x 8 | (16, 8) | - | - | across |
| 15 | water | 16 x 8 | (16, 0) | water (cell) at (16, 0) | - | across, down |
| 16 | bouncer | 16 x 16 | (0, 0) | bouncer (cell) at (0, 8) | - | - |
| 17 | exit | 16 x 32 | (0, 0) | exit (exact) at (0, 24) | - | - |

## Skills

The header's eight slots, left to right on the skill panel. A slot with ID
0 is empty: the panel shows no icon there, and it cannot be selected. The
skill IDs:

| ID | Skill | ID | Skill | ID | Skill |
| ---: | --- | ---: | --- | ---: | --- |
| 1 | Jumper | 18 | Climber | 35 | Diver |
| 2 | Runner | 19 | Builder | 36 | Flame Thrower |
| 3 | Filler | 20 | Basher | 37 | Super Lem! |
| 4 | Ballooner | 21 | Miner | 38 | Surfer |
| 5 | Archer | 22 | Floater | 39 | Planter |
| 6 | Attractor | 23 | Laser Blaster | 40 | Parachute |
| 7 | Bomber | 24 | Exploder | 41 | Slider |
| 8 | Scooper | 25 | Magno Boots | 42 | Rock Climber |
| 9 | Hopper | 26 | Bazooker | 43 | Jet Pack |
| 10 | Skater | 27 | Spearer | 44 | Shimmier |
| 11 | Kayaker | 28 | Fencer | 45 | Roper |
| 12 | Swimmer | 29 | Stomper | 46 | Twister |
| 13 | Roller | 30 | Skier | 47 | Sand Pourer |
| 14 | Magic Carpet | 31 | Stacker | 48 | Glue Pourer |
| 15 | Club Basher | 32 | Pole Vaulter | 49 | Icarus Wings |
| 16 | Thrower | 33 | Mortar | 50 | Hang Glider |
| 17 | Digger | 34 | Platformer | 51 | Blocker |

- **IDs.** 0..51; an ID above 51 breaks the game. Two skills depend on the
  style: the **Attractor** (6) fails in a Classic-style level (it
  vanishes and leaves the walkers dancing where it stood), and the
  **Blocker** (51) works only in a Classic-style level (elsewhere it turns
  nobody and damages the style's data). The original levels have the
  Attractor in all eleven other tribes and the Blocker only in Classic.
  Every other skill works in every style. The original levels use 2 to 8
  distinct skills with their empty slots last; the game does not require
  that, and the same ID in two slots is two skills with their own counts.
- **Counts.** A byte, 0..255. The player can use a skill while its count is
  above 0, and each use takes one. The panel shows two digits: 1..99
  correctly, 0 as nothing, and 100 and more wrongly, while the count itself
  works. A slot whose count is 0 cannot be selected. Write 1..99 for a used
  slot and 0 for an empty one.

## Title

24 bytes at `L2LH` +0, with no terminator. The game shows the title only
in the briefing before a tribe's level, centred with word wrap in a box
176 pixels wide with two lines, in the game's proportional menu font. The
editor shows it in its list. Each byte:

| Bytes | Shown as |
| --- | --- |
| `$20..$7A` except `#` | The character (`$20` is a space of 6 pixels) |
| `#` (`$23`) | A number from the text routine's arguments: garbage |
| `$00` | Ends the title; the rest is not shown |
| `$0A` | A new line |
| `$01..$0B` other | Text commands that take the bytes after them: 1 *x* *y* moves (2 bytes), 4, 5 and 6 align left, centre and right, 7 sets a box (4 bytes), 8 a colour (1 byte), 9 and 11 turn word wrap on and off, 2 and 3 set and clear a flag |
| `$0C..$1F` | Nothing |
| `$7B..$7F` | Nothing, but `$7B..$7E` draw stray pixels |
| `$80..$FF` | **The game hangs** before the briefing appears, with the screen black |

A title wider than the box wraps at its spaces; a word wider than the box
runs past the screen's right edge and goes on at the left. The original
levels use letters, digits, spaces, `! & , - . / ?` and `` ` ``. Use
`$20..$7A` without `#`, padded with spaces, at most 176 pixels of text on
each of two lines. The editor types `$20..$7A` without `#` and shows any
other byte of a title from elsewhere as a space when it edits the title.

## Files

- A level file's name ends in `.lvl` (in any case) and the file holds
  exactly 8648 bytes, the record with nothing before or after it.
- The editor lists a file as damaged (never played or opened) when its
  `FORM` type, tags or sizes differ from [the overview](#overview), the
  style is not 0..11 or the shape 0..6, a skill ID is over 51, the start
  view and the scroll limits break the rule in
  [scrolling](#the-start-view-and-the-scroll-limits), a placement's type is
  neither `-1` nor one the style has, its repeats are over 40, or its
  origin is more than 512 pixels outside the map or off the 16 x 8 cell
  grid.
- A tool that rewrites a level should keep every byte it does not change,
  the unused ones too, and the order of the placements.

## Checklist for writing a level

A file that follows these rules plays in Lemmings 2, and the editor
accepts it:

1. 8648 bytes in the layout of [the overview](#overview): `FORM`,
   `$000021C0`, `L2LV`, then `L2LH` 74, `L2MH` 6, `L2MP` 7884 and `L2BO`
   640 with these tags and sizes.
2. Header: a title of `$20..$7A` without `#`, padded with spaces (a byte
   `$80..$FF` hangs the game in the briefing); skill IDs 1..51 with the
   empty slots (0) last, no Blocker unless the style is Classic and no
   Attractor if it is, counts 1..99 (0 for empty slots); time 0:01..9:59
   with the unused bytes 0; the style word equal to `L2MH`'s; on each axis
   0 <= lowest <= start view <= highest <= the largest scroll, all on one
   16-pixel grid; grading 0..59; release rate 0..21; the last four bytes 0.
3. Map header: style 0..11, shape 0..6, the last word 0.
4. Map: tiles below the style's tile count, bits 28 and 30 as wanted,
   bits 10..27, 29 and 31 zero; cells past *columns* * *rows* zero.
5. Objects: empty placements of five `-1` words; types the style has; one
   to four entrances; at most 64 links and 4096 bytes of built objects;
   origins near the map, *x* a multiple of 16 and *y* of 8, with the
   origin plus the type's offset 0 or more on both axes; repeats 0..40,
   and 0..7 down for a swinging object; at most five swinging objects;
   teleporters in pairs; at most 32 switches and 32 switch targets, in
   matching order.

## Example

A Beach (style 1) level on a 42 x 44 map (shape 3), its title `SAND`, 30
Jumpers and 20 Bombers, 4:30, the whole map's scroll limits, an entrance at
(64, 32) and an exit at (480, 288):

| Item | Stored | Bytes |
| --- | --- | --- |
| Title (`$0014`) | `SAND` and 20 spaces | `53 41 4E 44 20 ...` |
| Skill IDs (`$002C`) | 1, 7, then 0 | `01 00 07 00 00 00 ...` |
| Counts (`$003C`) | 30, 20, then 0 | `1E 14 00 00 00 00 00 00` |
| Time (`$0044`) | 4 minutes, 30 seconds | `04 00 1E 00` |
| Style (`$0048`) | 1 | `01 00` |
| View and limits (`$004A`) | 0, 0; 0, 0; 320, 160 | `00 00 00 00 00 00 00 00 40 01 A0 00` |
| Grading, rate (`$0056`) | 2; 5 | `02 00 05 00` |
| Map header (`$0066`) | style 1, shape 3 | `01 00 03 00 00 00` |
| A cell (`$0074` + 4 * cell) | tile 5, non-colliding | `40 00 00 05` |
| Placement 0 (`$1F48`) | type 0, (64, 32), no repeats | `00 00 40 00 20 00 00 00 00 00` |
| Placement 1 (`$1F52`) | type 1, (480, 288) | `01 00 E0 01 20 01 00 00 00 00` |

The exit's trigger point is then (492, 328), so the floor under it must
have its top row at *y* 328.
