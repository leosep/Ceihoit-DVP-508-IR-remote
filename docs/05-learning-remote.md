# 5. Teaching a handheld learning remote from the Pi

Once the codes are known, the Pi can play the part of the original remote and a
learning remote can copy it. That reverses the usual advice — a learning remote
is useless *without* a donor remote, but here the Pi is the donor.

The point is convenience: after ten minutes of teaching, you have a normal
handheld remote and the Pi is only needed for the occasional re-learn.

## You need

- A learning remote (One For All, Philips, RCA/GE, or any remote with a
  `LEARN`/`SETUP` button).
- Patience for **one key at a time**. There is no batch mode.
- A way to cover the target device's IR window (see the trap below).

## The two signal profiles

Learning remotes sample differently, so two scripts cover both:

```bash
./scripts/teach.sh 0x520C        # spaced single taps: 30 s, one frame every 2 s
./scripts/teach_hold.sh 0x520C   # continuous held-button stream, 110 ms frames
```

Try `teach.sh` first. If the remote never acknowledges, try `teach_hold.sh`.

Why both exist: a tap is a single frame, which is what a normal press is, and
most learning remotes latch onto it. But some only arm while a signal is
*continuously* present, and then the held-button stream is what they need.

Both scripts deliberately send **more than once** during the window. That is not
for the learning remote's benefit — it is because this link drops roughly one
press in three, so a single shot can be missed.

## Procedure

1. Select the device mode you want to teach (e.g. `DVD`). On many remotes a
   mode that is already configured refuses to learn.
2. Enter learn mode — usually hold `SETUP`/`LEARN` for ~3 s until the LED lights
   steady or blinks twice.
3. Press the target key (e.g. `PLAY`). The LED should blink once or stay on,
   meaning "waiting for a signal".
4. Hold the learning remote's **front** 1–2 cm from the Pi's IR LED, straight
   on, in dim light. On most learning remotes the transmit LED doubles as the
   receiver, so the front must face the Pi.
5. Run the script for that key.
6. Two blinks = stored. Repeat from step 3 for the next key; hold `SETUP` to exit.
7. **Verify**: point the learning remote at the device and press the key.

## Suggested order

Teach these first; they are the CD player's whole vocabulary:

| Order | Key | Code |
|---|---|---|
| 1 | Play / pause | `0x520C` |
| 2 | Stop | `0x5219` |
| 3 | Next track | `0x5203` |
| 4 | Previous track | `0x520D` |
| 5 | Volume up | `0x5216` |
| 6 | Volume down | `0x525E` |
| 7 | Mute | `0x523A` |
| 8 | Eject | `0x5204` |
| 9 | Power | `0x5225` |

Play/pause is the best first test to debug the procedure: a wrong result is
obvious and harmless.

## Traps

- **Aim at the Pi, not the device.** The learning remote's own LED is its
  receiver. Pointing it at the device while learning can store a reflected,
  corrupted signal — and then you will spend an hour blaming the code.
- **Cover the device when teaching a toggle.** `0x5225` is sent dozens of times
  during the window and will switch the device on and off repeatedly. Drape
  something over the device's window, or angle the Pi's LED away from it.
- **Do not teach into `TV` mode.** Most remotes reserve `TV` volume and power
  for "punch-through", so a learned `TV` power key gets silently overridden.
  Use `DVD`, `AUX`, or any empty mode.
- **The Pi's LED is weak.** ~16 mA against a real remote's 100–300 mA. Hold the
  remotes very close. If teaching fails repeatedly, confirm the LED emits with a
  phone camera, and consider the transistor driver in `01-hardware.md`.
- **Teach the toggle, not the state.** `0x5225` and `0x523A` are toggles. If the
  learned remote sometimes needs two presses, that is the device's state, not a
  bad learn.

## Verifying without the original remote

There is no need to trust the blink pattern — just use the learned remote on the
device. If play works, the learn worked. The Pi's receiver is another option
(`loopback.sh` shows you what that looks like) but it is easier to just watch the
device.

## If it never works

Work through these in order; each has a concrete test:

1. Does `./scripts/loopback.sh` decode frames? If not, the LED or wiring is the
   problem, not the learning remote.
2. Does the learning remote acknowledge *any* signal at all? Bounce a TV remote
   at it to prove the remote's learn mode works.
3. Is the distance wrong? Too far (>5 cm) fails; so does touching, on some
   models. Try 1 cm, 2 cm, 3 cm.
4. Is the remote actually a learning remote? Remotes that are *pre-programmed*
   universal (accepting a brand code like `0543`) cannot learn at all. Check for
   a `LEARN` button or a learn section in the manual.
