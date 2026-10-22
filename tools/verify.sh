#!/usr/bin/env bash
# Linux/headless twin of verify.ps1 for the bot-relevant suites.
# Usage: tools/verify.sh [--full | suite_name ...]   (--full adds the slower map/navigation suites)
set -uo pipefail
cd "$(dirname "$0")/.."
G="${GODOT_BIN:-.tools/godot/Godot_v4.7.2-stable_linux.x86_64}"
export XDG_DATA_HOME="$PWD/.tools/runtime" XDG_CONFIG_HOME="$PWD/.tools/runtime"
mkdir -p artifacts/temple artifacts/slayer-integration artifacts/museum artifacts/city .tools/runtime .tools/logs
"$G" --headless --path . --editor --import --quit > .tools/logs/import.log 2>&1 || { echo "import failed"; exit 1; }
suites=(bot_tactics_test bot_integration_test bot_senses_test bot_aim_test bot_positioning_test bot_locomotion_test bot_team_test bot_personality_test traversal_links_test)
# Explicit suite names run only those suites.
if [ $# -gt 0 ] && [ "$1" != "--full" ]; then suites=("$@"); fi
[ "${1:-}" = "--full" ] && suites+=(city_navigation_regression city_integration_test museum_integration_test temple_integration_test temple_traversal_test full_roster_soak)
status=0
for t in "${suites[@]}"; do
  [ -f "tests/$t.gd" ] || continue
  limit=1500; [[ "$t" == *soak* ]] && limit=6000
  timeout $limit "$G" --headless --path . --fixed-fps 60 --script "res://tests/$t.gd" > ".tools/logs/$t.log" 2>&1
  code=$?
  pass=$(grep -c '^PASS' ".tools/logs/$t.log"); fail=$(grep -c '^FAIL' ".tools/logs/$t.log")
  errs=$(grep -c 'SCRIPT ERROR\|Parse Error' ".tools/logs/$t.log")
  printf '%-32s exit=%s pass=%s fail=%s script_errors=%s\n' "$t" "$code" "$pass" "$fail" "$errs"
  grep '^FAIL' ".tools/logs/$t.log" | head -5
  [ $code -ne 0 ] || [ "$fail" != 0 ] || [ "$errs" != 0 ] && status=1
done
exit $status
