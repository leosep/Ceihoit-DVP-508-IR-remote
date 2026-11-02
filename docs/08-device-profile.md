# 8. Device profile — Ceihoit DVP-508

Everything observed about this specific player. The rest of the documentation is
transferable to other devices; this page is not.

## Identity

| | |
|---|---|
| Model | Ceihoit **DVP-508** mini DVD player |
| IR protocol | NEC, address `0x52`, 38 kHz |
| Remote | Not supplied. Replacement remotes for this model ship pre-programmed; no published code list exists |
| Discs used here | Audio CD and MP3 CD-R |
| Used as | CD player, driven entirely from a Raspberry Pi |

The remote for this model has: `SHIFT`, `SLEEP`, power, `GOTO`, `SRC`, mute, a
dual-function number pad (`1 SETUP`, `2 MENU`, `3 EXIT`, `4 MODE`, `5 AUDIO`,
`6 SUBT`, `7 REP`, `8 A-B`, `9 DISP`, `--`, `SEAR`, `0 ZOOM`, `I/ANGLE`),
`BAND`, transport (`STEP/SLOW`, play, `CLEAR/EQ`, `RANDOM`, stop, next), and
V+/V−, arrows and `OK`.

## Timing

| Event | Observed |
|---|---|
| Tray open / close | 1–2 s. `0x5204` while it is still moving is ignored |
| Cold boot to ready | ~15–20 s. Codes sent while the LED is red are dropped |
| Volume step visible | Immediate, but the OSD bar is the only indication — a single step is inaudible |
| Menu open | Immediate |

Consequence for scripting: always `sleep` after a power or eject command.
There is no acknowledgement mechanism — the player never reports state.

## Front panel

- **Red LED** = standby, **green LED** = powered on. The LED colour is the only
  remote way to tell whether `0x5225` turned the player on or off.
- No IR activity indicator.

## On-screen display

- **Volume bar**: five segments, drawn under the kbps readout on the playback
  screen. The segment count only changes when the level actually moves, which
  makes it a usable test signal — unlike the sound.
- **Mute**: an icon appears; the audio cuts. `0x523E` clears the icon when it
  works, but it is frequently ignored, so mute is easiest toggled with `0x523A`.
- **Repeat**: `0x5243` shows `SINGLE`. `0x5223` shows "repeat folder".
- **Audio channel** (`0x5208`) cycles `STEREO` / `MONO` / `L` / `R`.
- **Source select** (`0x5224`, `0x5244`) shows "not find device" — it is trying to
  switch to USB/SD.

## Menus, and why they matter

This is the single biggest trap on this device.

| Menu | Opened by | How to close |
|---|---|---|
| Settings list | `0x521A` (SETUP) or `0x5217` (MENU) | **Only a power cycle.** No EXIT code was found |
| Program / file list | `0x521C` | `0x521C` again — it is a toggle |

While the **program menu** is open, every other key is swallowed: volume, mute,
transport, all of it. A sweep that passes through `0x521C` therefore produces a
run of false "no" answers. Always put `1c` in a sweep's skip list.

The settings list is nearly as bad: it covers the playback screen, so the volume
bar is invisible and nothing can be judged. `0x5217` and `0x521A` should be in
the skip list too when testing volume.

## Disc behaviour

- **Closing the tray starts playback by itself.** This is not an IR event, and it
  will look like a code worked when it did not. Wait for the disc to spin up
  before judging anything.
- An MP3 disc shows a file list; an audio CD enters playback directly. The
  transport keys behave slightly differently depending on which is loaded —
  `0x5203`/`0x5215` move the list on an MP3 disc.
- Repeat modes were verified on an MP3 disc and are **untested on an audio CD**.

## Observed link quality on this unit

| Condition | Frames decoded |
|---|---|
| Pi receiver 1 cm from LED | 7/10 (best case 10/10) |
| Player's IR window, LED driving directly from GPIO | ~68 % (28/41) |

The failures are not silent: a marginal frame is still a structurally valid NEC
frame, so the player decodes it as a **different key**. Observed consequence —
the same `0x5216` press raised the volume, opened SETUP, or did nothing.

This is a hardware limitation (≈16 mA of LED drive vs 100–300 mA for a real
remote), not a property of the codes.

## Codes proven on this unit

23 confirmed keys. See `04-code-reference.md` for the table and evidence, and
`../codes/ceihoit-dvp-508.csv` for the machine-readable version.

Two codes were suspected and then **disproved**, worth recording so nobody
re-tests them:

- `0x525C` and `0x525D` looked like volume down three times. Every hit turned out
  to follow an unmute or a track change. Re-tested cleanly with the bar at
  maximum — no effect. V− is `0x525E`.
- `0x523C` once appeared to raise a quiet track to full. Never reproducible; not
  V+ (that is `0x5216`).

`0x5239` has no confirmed function and was never systematically re-tested — it
is the one code near the mute block still worth a clean pass.

## Known gaps

| Missing | Notes |
|---|---|
| Fast forward / rewind | The only functional gap for CD use. Candidates: `0x5205`–`0x520B`, `0x520E`–`0x5214`, `0x5261`–`0x527F`, then `0x5280`–`0x52FF` |
| EXIT | Closing the settings screen currently requires a power cycle |
| Arrow keys / OK | `0x5203`/`0x5215`/`0x520D` navigate the MP3 list, but a real highlight-and-move arrow set was never identified |
| Number keys 0–9 | Direct track access; convenience only |
| SLEEP, GOTO, MODE, SUBT, A-B, DISP, ZOOM, ANGLE, BAND, STEP/SLOW, CLEAR/EQ, RANDOM, SHIFT | Unmapped |

Ranges already swept clean: `0x5200`–`0x5260`, excluding the hits above and
`0x521C`.

## Hardware actually used

- Raspberry Pi 4
- KY-005-style 38 kHz IR **transmitter module** (LED + resistor, no driver)
- KY-022-style 38 kHz IR **receiver module**
- GPIO 27 = transmit, GPIO 22 = receive
- Kernel `gpio-ir-tx` / `gpio-ir` overlays; `pigpiod` disabled

Two consequences worth repeating, because they shaped every result above: the
transmitter module is under-driven, and its polarity depends on the batch (see
`01-hardware.md`).
