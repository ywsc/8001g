#!/usr/bin/env bash
# Headless test run (works in CI / containers without a GPU or audio device).
#   tools/run_tests.sh          logic tests only (fast)
#   tools/run_tests.sh --bot    + full scripted playthrough with screenshots in tests/out
set -euo pipefail
cd "$(dirname "$0")/.."

export SDL_AUDIODRIVER=${SDL_AUDIODRIVER:-dummy}
RUN=(love .)
if [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null; then
  RUN=(xvfb-run -a -s "-screen 0 1440x810x24" love .)
fi

filter() { grep -v -E "^ALSA|Could not open device" || true; }

echo "== logic tests =="
"${RUN[@]}" --test 2>&1 | filter
status=${PIPESTATUS[0]}
[ "$status" -eq 0 ] || { echo "logic tests failed"; exit "$status"; }

if [ "${1:-}" = "--bot" ]; then
  echo "== scripted playthrough =="
  rm -rf tests/out
  "${RUN[@]}" --bot --fixeddt 2>&1 | filter
  status=${PIPESTATUS[0]}
  [ "$status" -eq 0 ] || { echo "playthrough failed"; exit "$status"; }
  echo "screenshots: tests/out/"
fi
echo "all good"
