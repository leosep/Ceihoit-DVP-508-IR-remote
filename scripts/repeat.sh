#!/usr/bin/env bash
#
# Repeat one code with a controllable gap. Useful for:
#   - confirming a code reproducibly (send 3-5 times, watch for a repeated effect)
#   - making a volume change big enough to see
#
#   ./repeat.sh 0x5216 5           five presses, 0.5 s apart
#   ./repeat.sh 0x525E 10 0.3      ten presses, 0.3 s apart
#
# Note: this is not the same as frames in one send. Each iteration is a separate
# ir-ctl call with a real pause, so it looks like distinct presses, which is what
# you want for stepping and toggling keys.

set -euo pipefail

TX="${IR_TX:-/dev/lirc0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -lt 2 ]; then
    echo "usage: $(basename "$0") <code> <count> [gap_s]" >&2
    exit 1
fi

code="$1"
count="$2"
gap="${3:-0.5}"

printf '%s  repeat %s x%s, gap %ss\n' "$(date +%H:%M:%S)" "$code" "$count" "$gap"

for ((i = 1; i <= count; i++)); do
    "$SCRIPT_DIR/send.sh" "$code" 1 >/dev/null
    printf '  %s  %d/%d\n' "$(date +%H:%M:%S)" "$i" "$count"
    if [ "$i" -lt "$count" ]; then
        sleep "$gap"
    fi
done

printf '%s  done\n' "$(date +%H:%M:%S)"
