# 1. Hardware

## What the Pi does

Two independent kernel drivers:

| Role | Overlay | GPIO | Device node |
|---|---|---|---|
| Transmit | `gpio-ir-tx` | 27 | `/dev/lirc0` |
| Receive | `gpio-ir` | 22 | `/dev/lirc1` |

The transmitter is the only mandatory part. The receiver is optional, but it
turns "did it work?" into a measurable question, so fit it if you can.

## Wiring

### IR LED (transmit)

The minimal version works and is what this project started with: LED between
GPIO 27 and ground, through a resistor.

```
GPIO 27 ──[ 33 Ω ]── IR LED anode (long leg)
                     IR LED cathode (flat side) ── GND
```

It emits, but only about 16 mA. A real remote pushes 100–300 mA. The LED works
at 20 cm and is unreliable at a metre or more. That matters because an
*under-driven* LED does not merely drop presses — it produces marginal frames
that the device decodes as **different keys**. See `06-troubleshooting.md`.

### IR LED (recommended, transistor driver)

```
GPIO 27 ──[ 1 kΩ ]── base (2N2222 / BC547)
                     collector ── IR LED cathode (flat side)
                     emitter   ── GND
5 V ──[ 22 Ω ]── IR LED anode
```

This delivers the ~100 mA a remote does, and every code becomes deterministic.
If you are only going to do one thing from this document differently, do this.

### IR receiver (optional, TSOP38238 / VS1838B)

```
TSOP OUT  ── GPIO 22
TSOP VCC  ── 3.3 V
TSOP GND  ── GND
```

A 100 nF capacitor across VCC/GND is good practice. The TSOP output is
open-collector with a pull-up, which is why an **unplugged** module still reads
`level=1` and looks perfectly healthy — see the troubleshooting doc.

## If you are using the ready-made Arduino modules

The common blue/black breakout boards — "IR transmitter module" and "IR receiver
module", sold as KY-005 and KY-022/HX1838 — work, and this build used them. They
have two traps.

### Pinout

**Check the silkscreen; pin order varies between batches.**

| Module | Pins (typical order) |
|---|---|
| Transmitter (KY-005) | `S` (signal) · middle `+5V` · `-` (GND) |
| Receiver (KY-022) | `OUT` · `GND` · `VCC` — often labelled `S` / `-` / `+` |

### Wiring

```
Transmitter:  S -> GPIO 27    middle -> 3.3 V    - -> GND
Receiver:     OUT -> GPIO 22  GND -> GND         VCC -> 3.3 V
```

### Trap 1 — do not power the receiver from 5 V

The receiver's `OUT` pin is pulled up to **its own VCC**. Power the module from
5 V and `OUT` sits at 5 V, which is above the Raspberry Pi's 3.3 V GPIO rating.
These modules work fine at 3.3 V, so power them from 3.3 V and the output swings
3.3 V. If you must run it at 5 V, put a divider or level shifter on `OUT`.

Symptom of getting this wrong: the Pi works for a while, then a GPIO or the SoC
dies for no apparent reason.

### Trap 2 — the transmitter module is an LED with a resistor, nothing more

There is no driver transistor on the board: `S` feeds a resistor and the LED.
Two consequences.

**Polarity.** Some batches wire the LED between VCC and `S`, so the LED lights
when `S` is pulled *low* (active-low). `gpio-ir-tx` drives the pin **high** for a
mark, so on an active-low board the optical signal is inverted and no receiver
will ever decode it — even though the GPIO is clearly toggling. If your device
never responds but `loopback.sh` shows nothing, this is the first thing to
check: meter the LED, or simply try a bare LED in place of the module.

**Current.** The resistor is sized for 5 V logic and for continuous use, so even
at 5 V the peak current is far below the 100–300 mA a real remote pushes. Driven
from a 3.3 V GPIO it is lower still. That shortfall is the most likely cause of
the frame corruption described in `06-troubleshooting.md`: the signal reaches the
device, but marginally, and marginal frames decode as the wrong key.

If you want dependable presses, either get the module's LED right against the
device's window (20 cm or less), or replace the transmitter board with the
transistor circuit above. The transistor version is three components and it is
what makes the difference between "works when I press twice" and "works".

### A note on the receiver module's AGC

These receivers auto-adjust gain. In a bright room, or with a strong IR source
nearby (sunlight, halogen, some LED bulbs), they desensitise and stop decoding
short bursts. If captures are erratic, test in dim light before assuming a
wiring fault.

## Enable the overlays

`/boot/config.txt` on older Raspberry Pi OS, `/boot/firmware/config.txt` on
Bookworm and later. Add:

```
dtoverlay=gpio-ir-tx,gpio_pin=27
dtoverlay=gpio-ir,gpio_pin=22
```

Then reboot and confirm:

```bash
ls -l /dev/lirc*
# crw-rw---- 1 root video 251, 0 ... /dev/lirc0
# crw-rw---- 1 root video 251, 1 ... /dev/lirc1
```

Your user needs to be in the `video` group:

```bash
sudo usermod -aG video "$USER"    # then log out and back in
```

## Do not run pigpiod

If `pigpiod` is running it will fight the kernel driver for the pin and can
flood the LED. Either remove it or disable it:

```bash
sudo systemctl disable --now pigpiod
```

Everything in this repository uses `ir-ctl` and the kernel driver. There is no
Python IR library and no daemon.

## Which node is which

`/dev/lirc0` is always the transmitter and `/dev/lirc1` the receiver **in this
configuration**, but the `/sys/class/rc/rcN` numbering is not stable across
reboots. Setting a protocol on the wrong node fails with `Invalid argument`.
Check with:

```bash
dmesg | grep -iE 'gpio-ir|lirc_dev'
```

```
rc rc1: ... GPIO IR Bit Banging Transmitter ... minor = 0   -> /dev/lirc0
rc rc0: ... gpio_ir_recv ... minor = 1                      -> /dev/lirc1
```

Notice the swap: `rc0` is the *receiver*, `rc1` the *transmitter*. Do not assume.

## Power

A Pi driving an IR LED from 5 V through a transistor, plus a USB audio device,
plus a display, can brown out. Check:

```bash
vcgencmd get_throttled
```

`throttled=0x0` is healthy. Anything with bit 0 or 16 set means undervoltage —
this project saw `0x50005` and reboots roughly every two hours, which is
maddening during long sweeps because it looks like the player stopped
responding. Use a good 5 V 3 A supply.

## NEC protocol in one paragraph

38 kHz carrier, 9 ms lead pulse, 4.5 ms lead space, then 32 data bits
LSB-first: address, inverted address, command, inverted command. A `0` bit is a
562 µs pulse and a 562 µs space; a `1` bit is a 562 µs pulse and a 1687 µs
space. Frames are ~110 ms apart when a key is held, and the repeat frame omits
the data entirely.

`ir-ctl` writes the whole thing for you: `--scancode=nec:0x52CC` produces a
complete frame, and `--gap=110000` sets the inter-frame spacing for repeats.
Note that `--duty-cycle` and `-c 38000` apply only to raw `--send`, not to
`--scancode` — the encoder picks 38 kHz itself.
