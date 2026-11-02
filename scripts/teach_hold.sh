#!/usr/bin/env bash
#
# Send a code as a continuous held-button stream, for learning remotes that
# ignore spaced taps.
#
#   ./teach_hold.sh 0x520C          40 s of frames, 110 ms apart
#   ./teach_hold.sh 0x520C 60       60 s
#
# This mimics a real remote held down: identical frames at the NEC repeat
# interval. Use it only when teach.sh fails - a held stream is also what makes
# a toggle key (power, mute) fire over and over, so cover the target device.
#
# WARNING: teaching a power toggle this way will switch the device on and off
# dozens of times. Drape something over its IR window first.

set -euo pipefail

TX="${IR_TX:-/dev/lirc0}"

if [ $# -lt 1 ]; then
    echo "usage: $(basename "$0") <code> [seconds] [gap_us]" >&2
    exit 1
fi

code="$1"
secs="${2:-40}"
gapus="${3:-110000}"

# Normalise the same way send.sh does.
hex="$(printf '%s' "$code" | sed 's/^0[xX]//' | tr '[:lower:]' '[:upper:]')"
addr_hex="$(printf '%s' "${IR_ADDR:-0x52}" | sed 's/^0[xX]//' | tr '[:lower:]' '[:upper:]')"
if [ "${#hex}" -le 2 ]; then
    hex="${addr_hex}$(printf '%02X' "$((16#$hex))")"
fi

printf '%s  HOLD 0x%s for %ss (gap %sus)\n' "$(date +%H:%M:%S)" "$hex" "$secs" "$gapus"
echo "  hold the learning remote 1-2 cm from the Pi LED, straight on, steady"

end=$(( $(date +%s) + secs ))
n=0
while [ "$(date +%s)" -lt "$end" ]; do
    ir-ctl -d "$TX" --gap="$gapus" \
        --scancode=nec:0x"$hex" --scancode=nec:0x"$hex" \
        --scancode=nec:0x"$hex" --scancode=nec:0x"$hex" \
        --scancode=nec:0x"$hex" --scancode=nec:0x"$hex" \
        --scancode=nec:0x"$hex" --scancode=nec:0x"$hex" 2>/dev/null || true
    n=$((n + 8))
    sleep 1
    printf '  %s  %d frames sent\n' "$(date +%H:%M:%S)" "$n"
done

printf '%s  done - sent 0x%s %d times\n' "$(date +%H:%M:%S)" "$hex" "$n"
