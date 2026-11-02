#!/usr/bin/env bash
#
# Send one NEC scancode from the Pi's IR transmitter.
#
#   ./send.sh 0x520C          one frame - the correct default
#   ./send.sh 0x520C 3        three frames, a deliberate repeat
#   ./send.sh 0C              command byte only, address from IR_ADDR
#
# One frame per press matters: every frame is a separate key press to the
# device, and with a marginal LED the extra frames are where corruption turns
# into a *different* key. Repeat only when you want a bigger step.

set -euo pipefail

TX="${IR_TX:-/dev/lirc0}"
ADDR="${IR_ADDR:-0x52}"
GAP="${IR_GAP:-110000}"

usage() {
    echo "usage: $(basename "$0") <code> [frames]" >&2
    echo "  code   0x520C, 520C or 0C (last two use IR_ADDR as the address)" >&2
    echo "  frames frames to send, default 1" >&2
    exit 1
}

command -v ir-ctl >/dev/null 2>&1 || {
    echo "error: ir-ctl not found (install v4l-utils)" >&2
    exit 1
}

[ $# -ge 1 ] || usage
code="$1"
frames="${2:-1}"

case "$frames" in
    ''|*[!0-9]*) echo "error: frames must be a positive integer" >&2; exit 1 ;;
esac

# Normalise the hex: strip 0x, upper-case, pad the command byte to two digits.
hex="$(printf '%s' "$code" | sed 's/^0[xX]//' | tr '[:lower:]' '[:upper:]')"
addr_hex="$(printf '%s' "$ADDR" | sed 's/^0[xX]//' | tr '[:lower:]' '[:upper:]')"

if [ -z "$hex" ]; then
    echo "error: empty code" >&2
    exit 1
fi

case "$hex" in
    *[!0-9A-F]*) echo "error: '$code' is not hexadecimal" >&2; exit 1 ;;
esac

if [ "${#hex}" -le 2 ]; then
    hex="${addr_hex}$(printf '%02X' "$((16#$hex))")"
fi

if [ "${#hex}" -ne 4 ]; then
    echo "error: expected 1-2 or 4 hex digits, got '$code'" >&2
    exit 1
fi

args=()
for _ in $(seq 1 "$frames"); do
    args+=("--scancode=nec:0x${hex}")
done

printf '%s  send 0x%s%s\n' "$(date +%H:%M:%S)" "$hex" \
       "$([ "$frames" -gt 1 ] && echo " x$frames")"
ir-ctl -d "$TX" --gap="$GAP" "${args[@]}"
