#!/usr/bin/env bash
# Runs the bot behaviour benchmark across maps and seeds in parallel.
# Usage: tools/bench_bots.sh <label> [seconds] [seeds...]
set -euo pipefail
cd "$(dirname "$0")/.."
label="${1:-run}"; seconds="${2:-300}"; shift $(( $# > 1 ? 2 : $# )) || true
seeds=("${@:-76 971 2024}"); [ $# -eq 0 ] && seeds=(76 971 2024)
G="${GODOT_BIN:-.tools/godot/Godot_v4.7.2-stable_linux.x86_64}"
export XDG_DATA_HOME="$PWD/.tools/runtime" XDG_CONFIG_HOME="$PWD/.tools/runtime"
mkdir -p "artifacts/bench/$label"
pids=()
for map in city museum temple; do
  for s in "${seeds[@]}"; do
    "$G" --headless --path . --fixed-fps 60 --script res://tests/bot_behavior_benchmark.gd -- \
      --map=$map --seconds=$seconds --seed=$s --difficulty=${BOT_DIFFICULTY:-1} --out=res://artifacts/bench/$label/$map-$s.json \
      > "artifacts/bench/$label/$map-$s.log" 2>&1 &
    pids+=($!)
  done
done
fail=0; for p in "${pids[@]}"; do wait "$p" || fail=1; done
grep -h '^BENCH' artifacts/bench/$label/*.log
exit $fail
