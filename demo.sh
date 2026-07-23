#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# THE DEMO — three acts. Run ./demo.sh and press ENTER between beats,
# or just read the SAY lines and type the commands yourself.
#
#   ./demo.sh          # full run, ~4 min
#   ./demo.sh --90     # the 90-second cut: Act 1 + Act 2 only
#
# NETWORK BEATS are marked [NET]. Everything else is local.
# ---------------------------------------------------------------------------
set -uo pipefail
cd "$(dirname "$0")"
# shellcheck disable=SC1091
source .venv/bin/activate 2>/dev/null || true

HASH=$(cat ACT1_HASH.txt 2>/dev/null || echo "")
SHORT="${HASH:0:12}"
SHORT_CUT=false
[ "${1:-}" = "--90" ] && SHORT_CUT=true

if [ -z "$HASH" ]; then
  echo "No ACT1_HASH.txt — run ./prebake.sh first."
  exit 1
fi

c()   { printf '\n\033[1;36m%s\033[0m\n' "$1"; }              # act header
say() { printf '\033[0;33m  “%s”\033[0m\n' "$1"; }            # what to SAY
run() { printf '\n\033[1;32m$ %s\033[0m\n' "$*"; "$@"; }      # what to RUN
# Interactive by default. AUTO=1 advances on a timer instead of ENTER, which
# is what cast/record.sh uses to capture the fallback recording.
beat() {
  if [ -n "${AUTO:-}" ]; then
    printf '\n'; sleep "${AUTO_PAUSE:-2.5}"
  else
    printf '\n\033[2m── press ENTER ──\033[0m'; read -r _
  fi
}

clear

# ===========================================================================
c "ACT 1 — WONDER   (~2 min)   The record, and what anyone can do with it."
# ===========================================================================

# Before this script, in ~/Demo: b3sum unknown_model.pkl → look it up.
say "That was a bare file — no repo, no context. I hashed it and looked it up."
say "This model IS this hash. Now, back in the project, here's what it unfolds to."
printf '\n\033[1;37m  %s\033[0m\n' "$HASH"
beat

# --- BEAT 1.1 --------------------------------------------------------------
say "That hash isn't a checksum. It dereferences. Here's the whole record."
say "Inputs, git commit, environment, packages, timing, exit status."
run roar show "$SHORT"
beat

# --- BEAT 1.2 --------------------------------------------------------------
say "Every file this run actually read — observed at runtime, not declared."
say "Nobody wrote a config listing these. roar watched the process."
run roar inputs --all "$SHORT"
beat

# --- BEAT 1.3 --------------------------------------------------------------
say "And the shape of the pipeline it came from — inferred, not declared."
run roar dag
beat

# --- BEAT 1.4  [NET] -------------------------------------------------------
say "Same hash, in a browser. This is the AI Bill of Materials on glaas.ai —"
say "CycloneDX, downloadable, every input with its content hash."
printf '\n\033[1;32m$ open https://glaas.ai — paste the hash, click Audit (AI-BOM)\033[0m\n'
printf '\033[2m  [NET] fallback: cast/glaas-aibom.cast\033[0m\n'
beat

# --- BEAT 1.5 — the money beat  [NET] --------------------------------------
say "Now: you don't have to trust me. Rebuild it yourself from the hash alone."
say "First, what it WOULD do — the recorded plan. This is instant."
run roar reproduce "$SHORT"
beat

if [ "$SHORT_CUT" = false ]; then
  say "Now actually do it. Clone the commit, build the env, re-run the pipeline."
  say "Watch the hash at the end."
  printf '\033[2m  [NET] clones + pip installs. If wifi stalls: Ctrl-C, then\033[0m\n'
  printf '\033[2m        asciinema play cast/reproduce.cast\033[0m\n'

  # Reproduce in a throwaway copy, NOT in this repo. Two reasons: roar would
  # otherwise rebuild in place (overwriting outputs and opening a new session,
  # which would hijack Act 3's view), and a scratch dir makes the "clean
  # checkout" claim literally true rather than rhetorical.
  REPRO=$(mktemp -d)
  cp -R . "$REPRO/repo" 2>/dev/null
  rm -rf "$REPRO/repo/.venv" "$REPRO/repo/data" "$REPRO/repo/model.pkl" \
         "$REPRO/repo/metrics.json" "$REPRO/repo/cast"
  ( cd "$REPRO/repo" && run roar reproduce "$SHORT" --run -y )

  # roar reports which steps ran, but not "the artifact came out identical".
  # That comparison IS the point of the beat, so state it explicitly.
  REBUILT=$( cd "$REPRO/repo" && roar dag --json --show-artifacts 2>/dev/null | python -c "
import json,sys
try:
    d = json.load(sys.stdin)
    print(next(a['hash'] for a in d['artifacts'] if a['path'].endswith('model.pkl')))
except Exception:
    print('')")
  rm -rf "$REPRO"

  printf '\n  rebuilt  \033[1;37m%s\033[0m\n' "${REBUILT:-<none>}"
  printf   '  original \033[1;37m%s\033[0m\n' "$HASH"
  if [ "$REBUILT" = "$HASH" ]; then
    printf '\n\033[1;32m  ██  IDENTICAL  ██\033[0m\n'
  else
    printf '\n\033[1;31m  ✗ mismatch — fall back to cast/reproduce.cast\033[0m\n'
  fi
  beat
  say "Same hash. Bit for bit. That is what dereferenceable means."
else
  say "I can run that for real — it clones, rebuilds, and the hash matches."
fi

if [ "$SHORT_CUT" = true ]; then
  # =========================================================================
  c "ACT 2 — THE REVEAL   (~30 sec)"
  # =========================================================================
  say "Everything you just watched came from typing this in front of my"
  say "training command. No config. No instrumentation. No pipeline file."
  printf '\n\033[1;37m  $ roar run python train.py\033[0m\n'
  printf '\n\033[0;33m  “That is the whole integration. It was free.”\033[0m\n\n'
  exit 0
fi

beat

# ===========================================================================
c "ACT 2 — THE REVEAL   (~30 sec)   The kicker."
# ===========================================================================

say "Everything you just watched came from typing this in front of my"
say "training command. No config. No instrumentation. No pipeline file."
printf '\n\033[1;37m  $ roar run python train.py\033[0m\n'
beat
say "That's it. That's the whole integration. It was free."
beat

# --- BRIDGE — the bottleneck (optional, ~15s; cut when rushed) --------------
say "Free, but not fooled. Watch what happens if the tree is dirty."
run touch test.txt
# roar refuses: it tags every run with the commit SHA, and an untracked file
# means the commit alone can't explain what was on disk. That's the bottleneck.
run roar run python evaluate.py
rm -f test.txt
beat
say "It won't record a run it can't pin to exact code. Everything passes"
say "through the commit — that's the bottleneck. Which is why the record you're"
say "about to see is complete enough to catch what I never declared."
beat

# ===========================================================================
c "ACT 3 — PAYOFF   (~2 min)   The record surfaces what I never declared."
# ===========================================================================

# --- BEAT 3.1 — the hero ---------------------------------------------------
say "One human act. I marked the raw dataset as containing personal data."
run roar tag show data/raw.csv
beat

say "I never said anything about the other files. Watch where it went."
run python taint.py
beat

say "Five artifacts. One declaration. The tag followed the data, not a config."
say "That's a blast radius — and it's the answer to 'which models are affected?'"
beat

# --- BEAT 3.2 --------------------------------------------------------------
say "And it's not a guess. Ask the model why it's tainted, and it shows its work."
run roar tag why contains_pii model.pkl
beat

# --- BEAT 3.3 — OPTIONAL CALLBACK — CUT THIS FIRST IF RUSHED ---------------
say "One more thing, from the story I opened with."
say "Look at what train.py actually read."
run roar show @3
beat
say "data/test.csv. My training step read the test set — for scaling stats."
say "It passes code review. It's not in any config. Nobody declared it."
say "The run declared it, because the run couldn't lie about it."
beat

printf '\n\033[1;36m  Capture everything at runtime. Make every hash dereference.\033[0m\n\n'
