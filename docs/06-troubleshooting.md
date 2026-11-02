# 6. Troubleshooting

Ordered by how often each one fooled this project.

## The device ignores codes it answered a minute ago

Almost always state, not signal.

| Check | Why |
|---|---|
| Is a menu open? | A full-screen menu (here `0x521C`) swallows every other key. Press the menu key again or power-cycle |
| Is it muted? | Mute kills volume keys' audibility, not their behaviour — but you cannot observe them |
| Is it at volume zero? | Indistinguishable from mute by ear. Raise the level first |
| Is the tray moving / is it booting? | Both ignore input. Wait for it to settle |
| Is the Pi still up? | `uptime`, `vcgencmd get_throttled` |

The answer is rarely "the code was wrong".

## The same code does different things

This is the signature of **frame corruption**, and it is the single most
important thing to understand about this setup.

The Pi's transmitter is clean — you can prove it with `loopback.sh` at 1 cm:
7/10 to 10/10 frames decode perfectly. But at the device's window, only about
**68 %** of frames arrived intact here. That is a lost press in one of three
cases — and worse, a marginal frame is still a *structurally valid* NEC frame.
The device decodes it happily. The command byte is simply wrong.

Concretely, the same `0x5216` press sometimes raised the volume, sometimes
opened a settings screen (a different code), and sometimes did nothing. Real
observations caused by a corrupt link:

- `0x5216` x8 → settings list opened
- `0x5216` single → bar up, consistently
- `0x5217` single → settings list (that one is correct behaviour, it is MENU)

### What to do about it

1. **Send one frame, not a burst.** Extra frames are extra chances to send a
   wrong key. This contradicts a lot of advice you will find elsewhere.
2. **Shorten the distance** and aim squarely.
3. **Fix the drive current.** This is the real fix. A bare GPIO pin (~16 mA)
   produces a marginal optical signal; a transistor driver (~100 mA) produces
   what a remote does and makes every code deterministic. See `01-hardware.md`.
4. **Accept and confirm.** Anything that must be exact — eject, power, a single
   volume step — send once and visually confirm, rather than assuming.

### Why you cannot just repeat until it works

Because the failure mode is not "nothing happened". It is "something else
happened". Repeating a corrupted press makes the wrong action *more* likely,
which is exactly how two hours of contradictory volume results happened here.

## `loopback.sh` captures 0 bytes

1. **The receiver's data cable is unplugged.** The pin has a pull-up, so a
   disconnected module reads `level=1` and looks perfectly healthy. Check the
   physical connection first — this exact fault cost two hours.
2. Overlays not loaded: `dmesg | grep -i gpio-ir`.
3. Receiver on the wrong GPIO.
4. LED dead: check with a phone camera.

Remember that a dead receiver only breaks the *self-test*; transmission still
works and the device may respond fine.

## `ir-ctl` says `failed to send: Invalid argument`

Two causes:

- **Wrong node.** `/sys/class/rc/rcN` numbering swaps across reboots; setting a
  protocol on the receiver instead of the transmitter fails this way. Confirm
  with `dmesg | grep -i lirc_dev`.
- **Raw `--send` with an out-of-range value.** `--send` takes a *file* of
  pulse/space pairs, not a number. A 1 000 000 µs entry is rejected; values up
  to ~20 ms are accepted.

## The LED is invisible

940 nm is outside human vision. Use a phone camera: a dim purple glow. Note that
the Pi's green activity LED also blinks during a burst and is easy to mistake for
the IR LED.

## `pigpiod` breaks everything

If `pigpiod` is running it fights the kernel driver for the pin and can flood the
LED. Disable it: `sudo systemctl disable --now pigpiod`. Everything in this
repository uses `ir-ctl` and the kernel driver only.

## The Pi reboots every couple of hours

Undervoltage. Check `vcgencmd get_throttled` — `0x50005` means it is happening.
It looks like "the player stopped responding" but it is the Pi resetting
mid-sweep. Use a proper 5 V 3 A supply.

## The volume never seems to change

Three separate traps, all of which bit this project:

- **A single step is inaudible.** Watch the OSD bar, not your ears.
- **Muted and zero-level look identical.** Unmute *and* raise the level before
  testing anything that lowers volume.
- **No headroom.** Testing "does this lower the volume" when the level is already
  at zero cannot succeed. Drive it to maximum first, so a drop is unmistakable.

## A sensor that agrees with you is not a working sensor

A vibration sensor (geophone) was used here to detect the tray moving. It
produced confident, plausible numbers for codes `0x5205` and `0x5207`. Both were
noise; the tray never moved.

**Never trust a sensor you have not tested against a known-good event.** Make
the event happen by hand, confirm the sensor fires, and only then believe it.

## Sweep results are contradictory

Check, in order:

1. Was a modal menu open during part of the sweep? (Very likely.)
2. Was the device muted or at zero?
3. Was anything sent during a reboot or tray movement?
4. Did the Pi reboot mid-sweep? (`uptime` shorter than the sweep duration.)
5. Were bursts used instead of single frames?

If all five are clean, trust the result — and confirm the winner with a separate
single press before writing it down.
