#!/usr/bin/env bash
#
# Sweep a range of command bytes, logging every code with a timestamp.
#
#   ./sweep.sh 00 1f                 one frame each, 2.5 s apart
#   ./sweep.sh 00 1f 1 2.5           same, explicit
#   ./sweep.sh 41 5f 1 2.5 "1c,25"   skip codes 0x1C and 0x25
#
# Args:
#   start    first command byte, hex, no prefix       (00)
#   end      last command byte, hex, no prefix        (1f)
#   frames   frames per code, default 1
#   delay    seconds between codes, default 2.5
#   skip     comma-separated hex command bytes to skip
#
# Watch the device while this runs. When something happens, note *when*, then
# read sweep.log and bisect. Always put modal codes in the skip list: a menu
# opening mid-sweep makes every later result meaningless.

set -euo pipefail

TX="${IR_TX:-/dev/lirc0}"
ADDR="${IR_ADDR:-0x52}"
LOG="${IR_LOG:-sweep.log}"

if [ $# -lt 2 ]; then
    echo "usage: $(basename "$0") <start_hex> <end_hex> [frames] [delay_s] [skip_csv]" >&2
    exit 1
fi

start=$((16#$1))
end=$((16#$2))
frames="${3:-1}"
delay="${4:-2.5}"
skip="${5:-}"

if [ "$start" -gt "$end" ]; then
    echo "error: start > end" >&2
    exit 1
fi

addr_hex="$(printf '%s' "$ADDR" | sed 's/^0[xX]//' | tr '[:lower:]' '[:upper:]')"

: > "$LOG"
printf '%s  sweep 0x%s%02X-0x%s%02X  frames=%s delay=%s skip=%s\n' \
       "$(date +%H:%M:%S)" "$addr_hex" "$start" "$addr_hex" "$end" \
       "$frames" "$delay" "${skip:-none}" | tee -a "$LOG"

count=0
skipped=0
for ((c = start; c <= end; c++)); do
    h=$(printf '%02x' "$c")
    case ",$(printf '%s' "$skip" | tr '[:upper:]' '[:lower:]')," in
        *",$h,"*) skipped=$((skipped + 1)); continue ;;
    esac

    hh=$(printf '%02X' "$c")
    printf '%s  %s%02X\n' "$(date +%H:%M:%S)" "$addr_hex" "$c" >> "$LOG"

    args=()
    for ((i = 0; i < frames; i++)); do
        args+=("--scancode=nec:0x${addr_hex}${hh}")
    done
    ir-ctl -d "$TX" --gap=110000 "${args[@]}" 2>/dev/null || true

    count=$((count + 1))
    sleep "$delay"
done

printf '%s  END  %d sent, %d skipped\n' "$(date +%H:%M:%S)" "$count" "$skipped" | tee -a "$LOG"
