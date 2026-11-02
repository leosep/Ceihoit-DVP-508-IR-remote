#!/usr/bin/env bash
#
# Make a code available to a learning remote as spaced single taps.
#
#   ./teach.sh 0x520C           30 s, one frame every 2 s
#   ./teach.sh 0x520C 45 3      45 s, one frame every 3 s
#
# Aim the learning remote's FRONT at the PI's LED, 1-2 cm, in dim light. Do not
# aim it at the target device: the remote's LED doubles as its receiver, and a
# reflection can store a corrupted signal.
#
# If the learning remote never acknowledges, try teach_hold.sh instead - some
# remotes only latch onto a continuously held signal.

set -euo pipefail

TX="${IR_TX:-/dev/lirc0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -lt 1 ]; then
    echo "usage: $(basename "$0") <code> [seconds] [interval_s]" >&2
    exit 1
fi

code="$1"
secs="${2:-30}"
iv="${3:-2}"

printf '%s  teaching %s for %ss, one frame every %ss\n' \
       "$(date +%H:%M:%S)" "$code" "$secs" "$iv"
echo "  hold the learning remote 1-2 cm from the Pi LED"

end=$(( $(date +%s) + secs ))
n=0
while [ "$(date +%s)" -lt "$end" ]; do
    "$SCRIPT_DIR/send.sh" "$code" 1 >/dev/null 2>&1 || true
    n=$((n + 1))
    printf '  %s  frame %d\n' "$(date +%H:%M:%S)" "$n"
    sleep "$iv"
done

printf '%s  done - sent %s %d times\n' "$(date +%H:%M:%S)" "$code" "$n"
