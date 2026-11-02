#!/usr/bin/env bash
#
# Transmitter self-test: listen on the Pi's own IR receiver while sending.
#
#   ./loopback.sh            ten frames of 0x521A
#   ./loopback.sh 0x5204     any code
#
# Expected output:
#
#   captured bytes: 21418
#   frame 1: addr=0x52 ~addr=0xAD cmd=0x1A ~cmd=0xE5 OK
#   valid NEC frames: 10/10
#
# "OK" means address and command match their inverses, i.e. a well-formed NEC
# frame. That proves encoder, GPIO, transistor and LED all work, without
# involving the target device at all.
#
# Zero bytes captured almost always means the receiver's data cable is loose:
# the pin has a pull-up, so a disconnected module still reads level=1 and looks
# perfectly healthy.

set -euo pipefail

TX="${IR_TX:-/dev/lirc0}"
RX="${IR_RX:-/dev/lirc1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
code="${1:-0x521A}"
tmp="$(mktemp /tmp/ir-loopback.XXXXXX.txt)"
trap 'rm -f "$tmp"' EXIT

command -v ir-ctl >/dev/null 2>&1 || {
    echo "error: ir-ctl not found (install v4l-utils)" >&2
    exit 1
}

hex="$(printf '%s' "$code" | sed 's/^0[xX]//' | tr '[:lower:]' '[:upper:]')"
addr_hex="$(printf '%s' "${IR_ADDR:-0x52}" | sed 's/^0[xX]//' | tr '[:lower:]' '[:upper:]')"

if [ "${#hex}" -le 2 ]; then
    hex="${addr_hex}$(printf '%02X' "$((16#$hex))")"
fi

echo "listening on $RX, sending 0x$hex on $TX ..."
timeout 10 ir-ctl -d "$RX" --receive --timeout 8000 > "$tmp" 2>/dev/null &
rx=$!
sleep 1

for _ in $(seq 1 10); do
    ir-ctl -d "$TX" --scancode="nec:0x$hex" 2>/dev/null || true
    sleep 0.25
done

wait "$rx" 2>/dev/null || true

echo "captured bytes: $(wc -c < "$tmp")"
python3 "$SCRIPT_DIR/decode_nec.py" "$tmp"
