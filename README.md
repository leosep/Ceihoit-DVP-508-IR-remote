# Controlling a no-name DVD player over IR from a Raspberry Pi

A complete, reproducible walk-through of how a Ceihoit **DVP-508** mini DVD player
was made controllable from a Raspberry Pi **without ever having its remote**, and
how a normal handheld remote was then re-created by teaching a learning remote
from the Pi.

The method is generic. The code table is specific to one player — but the
procedure works on any NEC-based appliance that no longer has a remote.

---

## The result, first

Protocol **NEC**, address **`0x52`**, 38 kHz. Every key is a single 32-bit NEC
frame of the form `nec:0x52CC`.

| Key | Code | Key | Code |
|---|---|---|---|
| Power (toggle) | `0x5225` | Volume up | `0x5216` |
| Standby | `0x5245` | Volume down | `0x525E` |
| Eject | `0x5204` | Mute (toggle) | `0x523A` |
| Play / pause | `0x520C` | Mute off | `0x523E` |
| Play | `0x5227` | MENU | `0x5217` |
| Stop | `0x5219` | SETUP | `0x521A` |
| Next track | `0x5203`, `0x5215` | Program / file menu | `0x521C` |
| Previous track | `0x520D`, `0x5257` | Audio channel | `0x5208` |
| Repeat folder | `0x5223` | Source select | `0x5224`, `0x5244` |
| Repeat single | `0x5243` | Mute (second) | `0x525A` |

That is a working CD player: load, play, skip, pause, stop, volume, mute.
Fast-forward / rewind is the one control still missing.

Send one with:

```bash
ir-ctl -d /dev/lirc0 --scancode=nec:0x520C
```

---

## Who this is for

You have an appliance whose remote is lost or broken, a Raspberry Pi, an IR LED,
and a screen you can watch. You do **not** need the original remote, a logic
analyser, or a receiver module — though a receiver makes life easier.

## What it costs

- 1 × Raspberry Pi (any model with GPIO; this was a Pi 4)
- 1 × IR LED, 940 nm — or the ready-made KY-005 transmitter module
- 1 × 2N2222 / BC547 transistor, 1 kΩ and 22 Ω resistors *(recommended, see below)*
- 1 × KY-022 / TSOP38238-style 38 kHz receiver *(optional but strongly recommended)*
- A phone camera, to confirm the LED is emitting

> These are the Arduino-style 3-pin modules: power the **receiver from 3.3 V**,
> never 5 V — its output is pulled up to its supply and 5 V will damage a Pi GPIO.
> See `docs/01-hardware.md`.

## The ten-minute version

```bash
# 1. enable the kernel IR transmitter on GPIO 27
echo 'dtoverlay=gpio-ir-tx,gpio_pin=27' | sudo tee -a /boot/firmware/config.txt
sudo reboot

# 2. prove the LED really emits (needs the optional receiver)
./scripts/loopback.sh

# 3. sweep a range while watching the device
./scripts/sweep.sh 00 1f 1 2.5

# 4. bisect the range that made it react
./scripts/send.sh 0x5204
```

## Repository layout

```
README.md                  this file
docs/
  01-hardware.md           wiring, overlays, why the LED driver matters
  02-verify-transmitter.md prove the LED works before blaming the device
  03-find-the-codes.md     the method: sweep, watch, bisect
  04-code-reference.md     the full confirmed table, with evidence
  05-learning-remote.md    teach a handheld remote from the Pi
  06-troubleshooting.md    symptom -> cause
  07-cd-player.md          the minimal button set for CD playback
  08-device-profile.md     everything specific to the DVP-508 (timings, OSD, quirks)
scripts/
  send.sh                  send one code (1 frame by default)
  sweep.sh                 timestamped sweep with skip list
  repeat.sh                repeat one code with a long gap
  teach.sh                 spaced taps, for learning remotes
  teach_hold.sh            held-button stream, for stubborn learning remotes
  loopback.sh              transmitter self-test
  decode_nec.py            decode a raw ir-ctl capture
codes/
  ceihoit-dvp-508.csv      the confirmed map, machine-readable
```

## The five things that cost the most time

Worth reading before you start, because each one produces convincing but false
results:

1. **A receiver with an unplugged data cable reads HIGH and looks healthy.**
   Zero captures looks like a dead transmitter. Check the cable first.
2. **A DC blink proves nothing.** A 38 kHz receiver ignores a steady light. You
   must modulate, and only a scancode send does that properly.
3. **A weak LED does not just lose presses — it corrupts them.** At the device's
   window only ~68 % of frames arrived intact here, and a damaged NEC frame
   decodes as a *different, valid-looking key*. That is why the same code seemed
   to do three different things.
4. **Any modal menu silently swallows the keys you are testing.** One sweep was
   run with a file-list menu open, which invalidated ten minutes of "no" answers.
5. **Never judge an audio key by ear.** A single volume step is inaudible, muted
   and zero-volume look identical, and only the device's own OSD tells the truth.

Each is expanded in `docs/06-troubleshooting.md`.

## License

Public domain / CC0. Do what you like with it.
