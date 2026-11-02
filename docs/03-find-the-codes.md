# 3. Finding the codes

The device only listens, so there is nothing to capture. The only practical
route without the original remote is to **transmit plausible codes and watch the
device**. This is slow but completely reliable if you are disciplined about it.

## The structure of the search space

Almost every consumer remote is NEC with an 8-bit address and an 8-bit command.
The address is shared by every button on the remote, and the command varies. So
the problem is two-dimensional, but the first dimension is tiny:

1. Find the **address** — 256 candidates, but usually one of ~30 common ones.
2. Find the **commands** — 256 candidates once the address is known.

256 codes at one per second is about four minutes. That is the whole search. The
difficulty is not the search, it is *observing* the result.

## Step 1 — find the address

Sweep the 256 commands of a candidate address with a code every ~1 s while
watching the device for any reaction: tray opening, OSD message, front LED
change, power-up.

```bash
./scripts/sweep.sh 00 ff 1 1.0
```

Watch for something **unmistakable**. A tray opening beats a subtle screen
change every time. If nothing happens across a full address, try the next
candidate address.

When something happens, you know the address but not the command. `sweep.sh`
logs every code with a timestamp to `sweep.log`, so the reaction can be narrowed
down even after the fact — but only if you noted *when* it happened.

## Step 2 — bisect to the command

Suppose a 32-code block produced the reaction. Send its middle code. If the
device reacts, keep the lower half; if not, keep the upper half. 32 → 16 → 8 → 4
→ 2 → 1 takes five presses.

```
0x5200..0x521F reacted
  -> 0x5210 ? yes  -> 0x5200..0x521F ... repeat
```

In this project the tray opened during a 32-code block, and bisection landed on
`0x5204` in five steps.

**Always confirm with a single frame once you think you have it.** A winner that
works once and never again is a corrupted frame, not a code.

## Step 3 — map the rest

Once the address is known, walk the command byte and note what each one does.
Do it in small blocks with a stop-list, and keep a log.

```bash
./scripts/sweep.sh 00 1f 1 2.5
```

## The human-in-the-loop protocol

This is the part that makes it work, and the part most write-ups skip. Codes are
sent from the Pi over SSH; a person watches the device and reports back. That
coordination has rules:

### 1. One frame per press

```bash
./scripts/send.sh 0x5204        # one frame
```

More frames is not "more reliable". Each frame is a separate key press to the
device. Three frames of the next-track code skipped two tracks; three frames of
the power code powered the device off and back on.

And once frames start getting corrupted, extra frames are where a mangled one
turns into a *different key*. Send one, then send again if it was missed.

### 2. Space presses out

~2.5 s between codes for a sweep, ~3 s when testing one code by hand. The device
needs time to repaint its OSD and settle.

### 3. Establish a visible baseline

Pick an on-screen element whose state you can read at a glance, and park it
somewhere with headroom. For volume: **drive it to maximum first**, so every
step down is unambiguous and there is room to observe. Testing "does this raise
the volume" from an unknown level in a silent room teaches you nothing.

### 4. Skip modal keys

If a code opens a full-screen menu, every code after it is being judged against
a menu that is eating the input. `sweep.sh` takes a skip list for exactly this:

```bash
./scripts/sweep.sh 41 5f 1 2.5 "1c,25,3a"
```

`0x521C` and `0x5225` and `0x523A` in that example are a file-list menu, power
and mute. Add anything that changes the device's *mode*, not just its
appearance, and always re-check where the device actually is before believing a
"no".

### 5. Say what you see, not what you expect

"Something changed" is worth more than "that's probably the volume key". Ask for
the raw observation, then interpret.

## Calibrate your sensor before you trust it

This project lost hours to a sensor that produced plausible numbers from noise:
a geophone (vibration sensor) used to detect the tray moving. It confirmed
`0x5205` and `0x5207` as "tray" codes. Both were coincidences; the tray had not
moved at all.

The rule that came out of it: **never trust a sensor you have not tested against
a known-good event.** Make the event happen by hand, confirm the sensor fires,
and only then believe it. The Pi's IR receiver is the same story — unplugged, it
reports a clean, confident zero.

## Keep a log

Every script here appends timestamps. When three minutes later you ask "was it
before or after the menu opened?", the log answers it. Write down the codes you
sent, in order, with times — this document's code table exists because of that.

## When it goes quiet

If the device stops responding entirely despite having responded minutes ago,
do not change the code. In order:

1. Is a menu open? Press the menu key again / power cycle.
2. Is it muted, or at volume zero?
3. Is the tray still moving? It ignores input while it is.
4. Is the Pi alive? `vcgencmd get_throttled`, `uptime`.
5. Is the LED still emitting? `./scripts/loopback.sh`.

The answer is almost never "the code was wrong".
