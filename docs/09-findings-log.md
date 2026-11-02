# 9. Findings log — everything observed, including what was wrong

This is the complete record of the two sessions: what was tried, what was seen,
what was believed at the time, and what was later disproved. It exists because
most of the false trails were convincing, and a reader who repeats them will
lose the same hours.

Times are local to the Raspberry Pi. Dates are session dates.

---

## Session 1 — 2026-11-01, evening

### Starting point

Player with no remote, Raspberry Pi 4, a KY-005-style transmitter module on
GPIO 27, a KY-022-style receiver on GPIO 22, kernel `gpio-ir-tx` / `gpio-ir`
overlays, `pigpiod` disabled.

### The geophone detour

An ADS1115 plus a geophone (vibration sensor) was set up to detect the tray
moving, because the tray was considered the clearest indicator and the player
had no camera aimed at it.

| Time | Observation | Conclusion drawn at the time |
|---|---|---|
| 20:36:55 | geophone peak 12 686 for `0x5205` | "tray moved" |
| 20:37:02 | geophone peak 7 624 for `0x5207` | "tray moved" |

**Both were wrong.** No one ever saw the tray move for those codes, and the
sensor later produced equally large peaks when nothing happened at all. The
geophone was rejected as a tray detector and never used again.

The mistake was trusting a sensor that had never been validated against a
known-good event.

### The unplugged receiver

Every loopback returned **0 bytes**, which reads as "the transmitter is dead".
It was not: the receiver module's data cable had come loose. Because the TSOP
output has a pull-up, the unplugged pin still read `level=1` and looked healthy.

Two hours were spent debugging a transmitter that was working the entire time.

### Proving the LED

| Step | Result |
|---|---|
| Manual GPIO blink, 2 s on / 1 s off | LED visible on a phone camera |
| Conclusion drawn | "the LED works" — **insufficient**: a TSOP ignores DC, so an unmodulated blink proves nothing about 38 kHz |
| Sampling GPIO 27 during a scancode send | mix of high and low, 300/300 samples low during bursts |
| Conclusion | the driver really modulates |

### First successful decode

With the cable back in, `decode_nec.py` returned for every frame:

```
addr=0x52 ~addr=0xAD cmd=0x05 ~cmd=0xFA OK
```

Correct complements on all four bytes. That fixed the protocol as **NEC,
address `0x52`, 38 kHz**, and proved encoder, pin and LED independent of the
player.

### Finding eject

A block sweep of `0x5200`–`0x521F` visibly opened the tray. Bisecting
32 → 16 → 8 → 4 → 1 landed on **`0x5204`** in five steps.

### First mapping pass

One-by-one scanning upward from `0x5200` with the MP3 file list on screen found
the transport, menu, power and volume keys (see `04-code-reference.md`).

### Late-night sweep windows (23:42–23:47)

| Window | Result |
|---|---|
| `0x520D`–`0x5215` | no volume drop |
| `0x521B`–`0x5222` (skipping `0x521C`) | no volume drop |
| `0x5226`–`0x5240` (skipping power/mute/source) | no volume drop |
| `0x5217` ×3, 2 s apart | settings list opened every time |

That last test is what **disproved `0x5217` = volume down**: three spaced presses
all opened the settings list, so it is MENU. Earlier it had been written off as
an "OSD-only key" precisely because it blinks the screen and changes nothing
audible.

---

## Session 2 — 2026-11-02

### Eject re-confirmed, single frame

`0x5204` with **one frame**, five open/close cycles, no misses:

| Time | Action | Result |
|---|---|---|
| 10:00:08 | open | worked |
| 10:00:26 | close | worked |
| 10:05:52 | open | worked |
| 10:06:22 | close | worked |
| 10:10:07 | open | worked |
| 10:10:35 | close | worked |

This is the evidence that single frames are reliable and that multi-frame bursts
are unnecessary.

### The near-miss wrong theories for volume down

| Hypothesis | Test | Result |
|---|---|---|
| V− is the twin of V+, i.e. `0x5236` (V+ + 0x20) | 10:11:39, one frame | no effect |
| V+ is really the ▲ arrow, so ▼ (`0x5215`) is volume down | 10:13:19, then ×6 at 10:55:07 and 10:57:53 | no effect, three times |
| V− is adjacent to V+ at `0x5217` | ×3 spaced | opens MENU |
| `0x525C` / `0x525D` are V− | multiple early hits | all confounded (see below) |

The +0x20 twin rule *is* real — it holds for `0x5223`/`0x5243`,
`0x5224`/`0x5244`, `0x5225`/`0x5245` and `0x523A`/`0x525A` — but volume up
does not follow it.

### The program-menu disaster

| Time | Event |
|---|---|
| 10:49:25 | sweep `0x521B`–`0x5226` started, 6 frames per code |
| ~10:49:30 | `0x521C` sent → "all select / all unselect" menu opened |
| 10:50:20 | sweep ended |
| 10:52:42–10:54:55 | eleven codes tested one by one: `0x521B`, `0x521D`, `0x521E`, `0x521F`, `0x5220`, `0x5221`, `0x5222`, `0x5226`, `0x5228`, `0x5218` — **all "no"** |
| 10:55:25 | `0x5216` (known V+) ×6 — **no effect**, which made no sense |
| 10:55:44 | `0x523A` (most reliable key) — **no effect**, so the link looked dead |
| 10:56:17 | `0x521C` sent again → **menu closed** |
| 10:57:42 | `0x5216` ×6 → bar rises |

Conclusion: **while the program menu is open, every other key is swallowed.**
Everything tested between 10:49:30 and 10:56:17 was invalid — about ten minutes
of false "no" answers. Every sweep since then has `1c` in its skip list.

### The false volume-down sighting

| Time | Event |
|---|---|
| 11:00:46 | sweep `0x524D`–`0x5265` started, 3 frames per code |
| 11:01:52 | last code `0x5260`; sweep stopped |
| — | user reported "the volume dropped" |

Bisection then cleared the whole lower half:

| Time | Code | Result |
|---|---|---|
| 11:02:19 | `0x5256` ×3 | no |
| 11:02:37 | `0x5256` ×3 again | no |
| 11:02:49 | `0x5252` ×3 | no |
| 11:03:04 | `0x524F` ×3 | no |
| 11:03:17 | `0x524E` ×3 | no |
| 11:03:29 | `0x524D` ×3 | no |
| 11:04:33 | `0x5250` ×3 | no |
| 11:04:49 | `0x5251` ×3 | no |
| 11:05:01 | `0x5253` ×3 | no |
| 11:05:13 | `0x5254` ×3 | no |
| 11:05:26 | `0x5255` ×3 | no |

Before continuing, `0x5216` ×4 at 11:04:11 was used to drive the bar back to
**maximum**, so that any subsequent drop would be unmistakable and there was
headroom to observe.

### The hits

| Time | Code | Observed |
|---|---|---|
| 11:05:38 | `0x5257` | **previous track** (duplicate of `0x520D`) |
| 11:05:57 | `0x5258` | nothing |
| 11:06:38 | `0x5259` | nothing |
| 11:06:58 | `0x525A` | **mute** — the +0x20 twin of `0x523A` |
| 11:07:19 | `0x523E` | unmute (sent because `0x525A` ×3 left it muted) |
| 11:07:21 | `0x525B` | nothing |
| 11:07:38 | `0x525C` | nothing (with the bar at max and unmuted) |
| 11:07:51 | `0x525D` | nothing |
| 11:08:06 | `0x525E` | **the bar dropped** |
| 11:08:17 | `0x525E` | single press — dropped *several* segments |
| 11:08:32 | `0x525E` | single press — dropped again |
| 11:08:56 | `0x525E` ×10 | went down a lot |

**`0x525E` is volume down.**

Note the open question: a single press moved more than one segment. Either the
player ramps, or the preceding burst had not finished, or a corrupted frame
landed on another volume code. Not resolved; documented as observed.

### Learning remote attempts

| Time | Method | Result |
|---|---|---|
| 11:19:03–11:19:25 | 11 spaced single frames of `0x5225` | no acknowledgement from the learning remote |
| 11:20:18–11:21:04 | 152 frames, 110 ms apart (held-button stream) | result not recorded — session ended |

Not proven either way. See `05-learning-remote.md` for the procedure and the
two signal profiles.

---

## Claims that were made and then retracted

Kept deliberately: each one cost time, and each is a trap worth recognising.

| Claim | Status | Why it was wrong |
|---|---|---|
| `0x5205` / `0x5207` move the tray | **false** | geophone noise; the tray never moved |
| The transmitter is dead | **false** | the receiver's cable was unplugged |
| A DC blink proves the LED works | **false for this purpose** | a TSOP ignores unmodulated light |
| `0x5217` is volume down | **false** | it is MENU; it only *looked* like a silent key because it changes nothing audible |
| `0x523C` is volume up | **false** | never reproducible; V+ is `0x5216` |
| `0x525C` / `0x525D` are volume down | **false** | every early hit followed an unmute or a track change; clean re-test showed no effect |
| `0x5215` is volume down because it is the ▼ arrow | **false** | three separate 6-press tests, no effect |
| `0x5236` is volume down (V+ + 0x20) | **false** | no effect |
| Three frames are more reliable than one | **false** | each frame is a separate key press; extra frames are where corruption becomes a wrong key |
| The Pi's volume tests were valid at 10:49–10:56 | **false** | the program menu was open and swallowing input |

## Hardware and measurement findings

| Finding | Value / detail |
|---|---|
| Protocol | NEC, address `0x52`, 38 kHz |
| Frame | 9 ms lead, 4.5 ms space, 32 bits LSB-first, ~110 ms between repeats |
| Loopback quality at 1 cm | 7/10 frames typically, 10/10 at best |
| Quality at the player's IR window | **28/41 ≈ 68 %** |
| Failure mode | a marginal frame still looks like a valid NEC frame and decodes as a **different key** |
| Transmitter module | LED + resistor only, no driver; ~16 mA vs 100–300 mA for a real remote |
| Receiver module | must be powered from **3.3 V**; its output is pulled up to its own supply |
| Transmitter module polarity | varies by batch; some are active-low, which inverts the signal and nothing decodes |
| Pi undervoltage | `throttled=0x50005`, reboots roughly every 2 h |
| `pigpiod` | conflicts with the kernel driver; must stay disabled |
| `/dev/lirc0` / `/dev/lirc1` | stable (TX / RX), but `/sys/class/rc/rcN` numbering **swaps** after reboot |
| GPIO 22 with the receiver unplugged | reads `level=1`, i.e. looks healthy |
| `ir-ctl --send` | takes a *file* of pulse/space pairs; entries above ~20 ms are rejected |
| Player boot | ~15–20 s; codes sent while the LED is red are dropped |
| Tray | 1–2 s per movement; ignores eject mid-motion |
| Closing the tray | starts the disc by itself — not an IR event |
| Settings screen | only a power cycle closes it; no EXIT code found |

## Where the search stands

**Swept clean:** `0x5200`–`0x5260`, excluding the confirmed hits and `0x521C`.

**Not yet swept:** `0x5261`–`0x527F`, then `0x5280`–`0x52FF`.

**Best leads for the missing controls:** `0x5205`–`0x520B` and
`0x520E`–`0x5214` (fast-forward/rewind, arrows, EXIT), and `0x5239` (never
cleanly tested).

## Every code mentioned in this document

| Code | Verdict |
|---|---|
| `0x5203` | next track |
| `0x5204` | **eject** |
| `0x5205`, `0x5207` | no effect (the geophone claim was false) |
| `0x5208` | audio channel |
| `0x520C` | **play / pause** |
| `0x520D` | previous track |
| `0x5215` | next track |
| `0x5216` | **volume up** |
| `0x5217` | **MENU** |
| `0x5218` | no effect |
| `0x5219` | **stop** |
| `0x521A` | **SETUP** |
| `0x521B` | no effect |
| `0x521C` | **program menu** — swallows all keys while open |
| `0x521D`–`0x5222` | no effect |
| `0x5223` | repeat folder |
| `0x5224` | source select |
| `0x5225` | **power** |
| `0x5226` | no effect |
| `0x5227` | play |
| `0x5228` | no effect |
| `0x5236` | no effect |
| `0x5239` | never cleanly tested |
| `0x523A` | **mute toggle** |
| `0x523C` | unexplained, not reproducible |
| `0x523E` | mute off |
| `0x5243` | repeat single |
| `0x5244` | source select |
| `0x5245` | **standby** |
| `0x524D`–`0x5256` | no effect |
| `0x5257` | **previous track** |
| `0x5258`, `0x5259` | no effect |
| `0x525A` | **mute** |
| `0x525B` | no effect |
| `0x525C`, `0x525D` | no effect (formerly suspected V−) |
| `0x525E` | **volume down** |
| `0x525F`, `0x5260` | no effect |
