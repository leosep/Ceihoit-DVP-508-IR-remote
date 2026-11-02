# 4. Code reference — Ceihoit DVP-508

Protocol **NEC**, address **`0x52`** (sent with complement `0xAD`), 38 kHz.
Command byte varies; full scancode is `nec:0x52CC`.

Everything below was confirmed by watching the player react, most of it more
than once. Deferred / disproved codes are listed separately — they are as
useful as the confirmed ones.

Device-specific behaviour (timings, OSD layout, menu traps) is in
`08-device-profile.md`.

## Confirmed

| Code | Function | Evidence and caveats |
|---|---|---|
| `0x5203` | Next track | Moves the list forward. `0x5215` does the same |
| `0x5204` | **Eject** | Toggles tray open/closed. Five clean open/close cycles in a row with a single frame |
| `0x5208` | Audio channel | Cycles STEREO / MONO / L / R |
| `0x520C` | **Play / pause** | Toggle: stops when playing, resumes when paused |
| `0x520D` | Previous track | Three frames jumped two songs |
| `0x5215` | Next track | Same visible effect as `0x5203` |
| `0x5216` | **Volume up** | OSD bar rises one segment per press; repeated presses reach max |
| `0x5217` | **MENU** | Opens the settings list. Three spaced presses all opened it |
| `0x5219` | **Stop** | |
| `0x521A` | **SETUP** | Opens the settings list. Not a toggle |
| `0x521C` | Program / file-list menu | Toggles the "all select / all unselect / copy / exit" menu. **Eats every other key while open** |
| `0x5223` | Repeat folder | "Repeat folder" on screen |
| `0x5224` | Source select | "not find device" (tries USB/card) |
| `0x5225` | **Power** | Toggles standby <-> on. One frame = one toggle. LED red = standby, green = on |
| `0x5227` | Play | Second play key; `0x520C` is the toggle |
| `0x523A` | **Mute toggle** | Most reliable key on the player |
| `0x523E` | Mute **off** | Clears the mute icon when it works; frequently ignored |
| `0x5243` | Repeat **single** | Display shows `SINGLE` |
| `0x5244` | Source select | Same as `0x5224` |
| `0x5245` | **Standby** | Drops to red LED; back on with `0x5225` |
| `0x5257` | Previous track | Duplicate of `0x520D` |
| `0x525A` | **Mute** | `+0x20` twin of `0x523A`; behaves as a mute toggle |
| `0x525C` | No effect | Suspected V− three times; every hit followed an unmute or a track change. Re-tested with the bar at max: nothing |
| `0x525D` | No effect | Same as `0x525C` |
| `0x525E` | **Volume down** | Three presses gave an unmistakable drop; ten drove the bar almost to the bottom. A single press can move several segments |

## Volume keys, specifically

| Key | Code |
|---|---|
| Volume up | `0x5216` |
| Volume down | `0x525E` |
| Mute | `0x523A` (toggle), `0x525A` |

V+ and V− are **not neighbours**. Textbook guesses all failed here: `0x5217`
(adjacent to V+) is MENU, `0x5215` is next-track, `0x5236` (V+ + 0x20) does
nothing. V− sits in a different band entirely, next to mute.

## Tested, no reaction

```
0x5200-0x5202   0x5205-0x5207   0x5209-0x520B   0x520E-0x5214
0x5218          0x521B          0x521D-0x5222   0x5226
0x5228-0x5238   0x523B          0x523D          0x523F-0x5240
0x524D-0x5256   0x5258-0x5259   0x525B-0x525D   0x525F-0x5260
```

The `0x524D`–`0x5260` block was re-tested cleanly (unmuted, menu closed, volume
at max) and produced exactly three hits: `0x5257`, `0x525A`, `0x525E`.

Two codes remain unexplained: `0x523C` (once appeared to raise a quiet track to
full; never reproducible) and `0x5239`.

## Not found

| Missing | Notes |
|---|---|
| Fast forward / rewind | The only gap that matters for CD use. Candidates: `0x5205`–`0x520B`, `0x520E`–`0x5214`, `0x5261`–`0x527F`, then `0x5280`–`0x52FF` |
| Number keys 0–9 | Direct track access. Convenience only |
| Arrow keys / OK | Needed for on-screen menus. `0x5203`/`0x5215`/`0x520D` navigate the MP3 list |
| EXIT | Nothing found that closes the settings screen; only a power cycle does |
| SLEEP, GOTO, MODE, SUBT, A-B, DISP, ZOOM, ANGLE, BAND, STEP/SLOW, CLEAR/EQ, RANDOM, SHIFT | Unmapped |

## What the remote itself has

From a photo of the replacement remote sold for this model, so every one of
these functions exists in the player:

- Top: `SHIFT`, `SLEEP`, power
- `GOTO`, `SRC`, mute
- Number pad, dual function:
  `1 SETUP`, `2 MENU`, `3 EXIT`, `4 MODE`, `5 AUDIO`, `6 SUBT`,
  `7 REP`, `8 A-B`, `9 DISP`, `--`, `SEAR`, `0 ZOOM`, `I/ANGLE`
- `BAND`
- Transport: `STEP/SLOW` (rew), play, `CLEAR/EQ`, `RANDOM`, stop, next
- Bottom: **V+ / V−**, **▲ ▼ ◀ ▶**, **OK**

So the player is fully controllable — the missing entries are unfound codes, not
missing hardware features.

## Sweep progress

`0x5200`–`0x5260` covered. Next: `0x5261`–`0x527F`, then `0x5280`–`0x52FF`.

The machine-readable version of this table is in `codes/ceihoit-dvp-508.csv`.
