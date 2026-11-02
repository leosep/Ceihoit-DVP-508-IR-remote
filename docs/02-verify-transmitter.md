# 2. Prove the transmitter works

Do this **before** you sweep anything. Every hour spent wondering why the device
ignores you is wasted if the LED was never emitting in the first place — and
this project wasted several.

There are three levels of proof, cheapest first.

## Level 1 — a phone camera sees 940 nm

Human eyes cannot see 940 nm, but most phone cameras can. Point the camera at
the LED while sending:

```bash
./scripts/repeat.sh 0x5204 20 0.2
```

A dim purple glow on the screen means the LED is emitting. It does **not** prove
38 kHz modulation, which is what a receiver actually needs — a steady light is
invisible to an IR receiver. So this only rules out a dead LED or bad wiring.

Also: the Pi's green activity LED blinks during a burst. Do not mistake it for
the IR LED.

## Level 2 — the Pi's own receiver (definitive)

With a TSOP on GPIO 22, let the Pi listen to itself:

```bash
./scripts/loopback.sh
```

It starts a 10 s capture on the receiver, sends ten frames, then decodes them:

```
captured bytes: 21418
frame 1: addr=0x52 ~addr=0xAD cmd=0x1A ~cmd=0xE5 OK
...
valid NEC frames: 10/10
```

`OK` means the address and command match their inverses — a complete,
well-formed NEC frame. That proves the encoder, the GPIO, the transistor and
the LED all work, independently of the target device.

Expect nearly every frame at 1–2 cm from the LED. Anything less at that distance
means a hardware problem, not a code problem.

## Level 3 — sample the GPIO during a send

If you have no receiver, you can at least prove the pin is toggling:

```bash
./scripts/repeat.sh 0x5204 20 0.2 &
for i in $(seq 1 50); do
    echo "$(date +%s.%N) $(pinctrl get 27)"
    sleep 0.05
done
wait
```

You should see the level change within each burst. That proves modulation is
happening, though not that the timing is correct.

A simple `raspi-gpio set 27 op dh` / `dl` blink proves only the LED and wiring.
It says nothing about modulation: a TSOP ignores DC, and this was one of the
false trails in this project.

## What "0 bytes captured" actually means

If `loopback.sh` reports zero bytes, in order of likelihood:

1. **The receiver's data cable is loose or unplugged.** The pin has a pull-up,
   so a disconnected module still reads `level=1` and looks fine. This exact
   fault cost two hours here.
2. The overlays are not loaded. Check `dmesg | grep -i gpio-ir`.
3. The receiver is wired to the wrong GPIO.
4. The LED is not emitting at all (go back to Level 1).

Note that a dead receiver only breaks the *self-test*. Transmitting still works,
so the device may well respond even while `loopback.sh` reports zero.
