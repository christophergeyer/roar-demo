#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Record the fallback terminal captures. Run this AFTER ./prebake.sh,
# on the machine and terminal size you'll present with.
#
#   ./cast/record.sh
#
# Produces:
#   cast/demo.cast       whole three-act run
#   cast/reproduce.cast  just `roar reproduce --run` on a clean checkout
#
# Play back on stage with:
#   asciinema play cast/reproduce.cast
#
# NOTE: the glaas.ai AI-BOM beat is a BROWSER page — asciinema cannot capture
# it. Record that one with a screen recorder (macOS: Cmd-Shift-5) and save it
# as cast/glaas-aibom.mov. See README.
# ---------------------------------------------------------------------------
set -uo pipefail
cd "$(dirname "$0")/.."
export PATH="$HOME/.local/bin:$PATH"

command -v asciinema >/dev/null || { echo "need asciinema: uv tool install asciinema"; exit 1; }
[ -f ACT1_HASH.txt ] || { echo "run ./prebake.sh first"; exit 1; }
HASH=$(cat ACT1_HASH.txt)

# Keep the recording narrow enough to read from the back of a room.
export COLUMNS=100 LINES=32

echo "▸ recording the full demo → cast/demo.cast"
rm -f cast/demo.cast
AUTO=1 AUTO_PAUSE=3 asciinema rec cast/demo.cast \
  --cols 100 --rows 32 --overwrite \
  --title "roar — three-act demo" \
  -c "./demo.sh"

# --- the money beat, isolated ---------------------------------------------
# Reproduce runs in a throwaway copy so the presentation repo is untouched.
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp -R . "$WORK/repo" 2>/dev/null
rm -rf "$WORK/repo/.venv" "$WORK/repo/data" "$WORK/repo/model.pkl" "$WORK/repo/metrics.json" "$WORK/repo/cast"

echo "▸ recording reproduce --run → cast/reproduce.cast"
rm -f cast/reproduce.cast
asciinema rec cast/reproduce.cast \
  --cols 100 --rows 32 --overwrite \
  --title "roar reproduce — rebuild from the hash alone" \
  -c "cd '$WORK/repo' && roar reproduce ${HASH:0:12} && echo && roar reproduce ${HASH:0:12} --run -y"

echo
echo "done:"
ls -la cast/*.cast
echo
echo "play:  asciinema play cast/reproduce.cast"
