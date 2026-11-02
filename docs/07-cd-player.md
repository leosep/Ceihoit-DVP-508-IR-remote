# 7. The minimal set for CD playback

If the plan is to use the player as a CD player, this is everything that
matters — no menus, no DVD features.

| Need | Code | Notes |
|---|---|---|
| Power on / off | `0x5225` | One frame = one toggle. `0x5245` is standby |
| Eject / load disc | `0x5204` | Closing the tray starts playback automatically |
| Play | `0x520C` or `0x5227` | |
| Pause | `0x520C` | Toggle only, there is no separate pause code |
| Stop | `0x5219` | |
| Next track | `0x5203` or `0x5215` | |
| Previous track | `0x520D` or `0x5257` | |
| Volume up | `0x5216` | |
| Volume down | `0x525E` | |
| Mute | `0x523A` | Most reliable key on the player |
| Repeat one | `0x5243` | |
| Repeat all / folder | `0x5223` | Verified on an MP3 disc; untested on audio CD |

That is a complete CD player: load, play, skip, pause, stop, volume, mute.

## The one real gap: seeking

There is no fast-forward or rewind. Next/previous step whole tracks only, so you
cannot jump to 2:30 inside a five-minute track.

Where to look: `0x5205`–`0x520B`, then `0x520E`–`0x5214`, then `0x5261`–`0x527F`.
On the original remote these are the `◀◀` / `▶▶` keys, and `STEP/SLOW` is also
a candidate.

## Irrelevant for CD use

`SUBT`, `ANGLE`, `ZOOM`, `BAND`, `MODE`, `SETUP`, `MENU`, `SRC`, the
program/copy menu, and audio channel (`0x5208`, which cycles
STEREO/MONO/L/R — only useful for a disc with a mono track).

## A working control loop

Once the driver is reliable, a button becomes one command:

```bash
./scripts/send.sh 0x520C        # play / pause
./scripts/send.sh 0x5203        # next track
./scripts/send.sh 0x5216        # one step louder
```

Because power, play/pause and mute are toggles, the Pi has no way to *know* the
state — it is open-loop. Two mitigations:

- Send `0x5225` only when you know the state (e.g. track it in software, or check
  the front LED), otherwise a stray press toggles it the wrong way.
- For volume, send a fixed number of steps relative to a known starting point,
  and re-establish that point (drive to max) occasionally.

## What "reliable" requires

Roughly one press in three is lost or corrupted at the current drive current.
Before treating this as a remote replacement, fit the transistor driver from
`01-hardware.md`. It is three components and it is the difference between "works
when I try twice" and "works".

## Teaching the handheld remote

If the goal is to stop using SSH, see `05-learning-remote.md`. Ten keys, ten
learn cycles, and the Pi goes back in the drawer.
