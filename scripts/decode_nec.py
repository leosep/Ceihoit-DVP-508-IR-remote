#!/usr/bin/env python3
"""Decode NEC frames from a raw `ir-ctl --receive` capture.

The capture format is one pulse/space pair per line, in microseconds, with the
sign giving direction: +pulse (carrier on), -space (carrier off).

Usage:
    ./decode_nec.py /tmp/rx.txt [--address 0x52]

Output is one line per frame:

    frame 1: addr=0x52 ~addr=0xAD cmd=0x1A ~cmd=0xE5 OK

"OK" means the address and command each match their bitwise inverse, which is
what NEC requires. A frame with a mismatch is either not NEC or corrupted -
which is the whole point of checking.
"""

from __future__ import annotations

import argparse
import re
import sys

LEAD_PULSE_MIN_US = 8000      # a NEC frame starts with a ~9 ms pulse
FRAME_GAP_MIN_US = 12000      # anything longer ends the frame
ONE_BIT_MIN_US = 1100         # a "1" bit space is ~1687 us, a "0" is ~562 us


def read_entries(path: str) -> list[int]:
    with open(path, "r", errors="ignore") as fh:
        text = fh.read()
    return [int(v) for v in re.findall(r"([+-]\d+)", text)]


def split_frames(entries: list[int]) -> list[list[int]]:
    """Split a stream of pulse/space values into per-frame lists."""
    frames: list[list[int]] = []
    current: list[int] = []

    for value in entries:
        if value > 0 and value >= LEAD_PULSE_MIN_US and current:
            frames.append(current)
            current = [value]
        else:
            current.append(value)

    if current:
        frames.append(current)
    return frames


def frame_bits(frame: list[int]) -> list[int]:
    """Extract up to 32 data bits, LSB first within each byte."""
    bits: list[int] = []
    # frame[0] is the lead pulse, frame[1] the lead space; data starts at 2.
    i = 2
    while i + 1 < len(frame) and len(bits) < 32:
        space = abs(frame[i + 1])
        if space > FRAME_GAP_MIN_US:
            break
        bits.append(1 if space > ONE_BIT_MIN_US else 0)
        i += 2
    return bits


def decode(bits: list[int]) -> tuple[int, int, int, int]:
    """Turn 32 LSB-first bits into (addr, ~addr, cmd, ~cmd)."""
    octets = []
    for start in (0, 8, 16, 24):
        value = 0
        for offset, bit in enumerate(bits[start:start + 8]):
            value |= bit << offset
        octets.append(value)
    return octets[0], octets[1], octets[2], octets[3]


def main() -> int:
    parser = argparse.ArgumentParser(description="Decode NEC frames from an ir-ctl capture")
    parser.add_argument("capture", nargs="?", default="/tmp/rx.txt",
                        help="raw capture file (default: /tmp/rx.txt)")
    args = parser.parse_args()

    entries = read_entries(args.capture)
    print(f"entries: {len(entries)}")

    frames = split_frames(entries)
    if not frames:
        print("no frames found - was the receiver connected and the LED sending?")
        return 1

    valid = 0
    for index, frame in enumerate(frames, 1):
        bits = frame_bits(frame)
        if len(bits) < 32:
            print(f"frame {index}: incomplete ({len(bits)} bits)")
            continue

        addr, addr_inv, cmd, cmd_inv = decode(bits)
        checks_out = (addr_inv == (~addr & 0xFF)) and (cmd_inv == (~cmd & 0xFF))
        status = "OK" if checks_out else "CHECKSUM MISMATCH"

        print(f"frame {index}: addr=0x{addr:02X} ~addr=0x{addr_inv:02X} "
              f"cmd=0x{cmd:02X} ~cmd=0x{cmd_inv:02X} {status}")
        if checks_out:
            valid += 1

    print(f"\nvalid NEC frames: {valid}/{len(frames)}")
    return 0 if valid else 2


if __name__ == "__main__":
    sys.exit(main())
