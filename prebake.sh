#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# PRE-BAKE — run this BEFORE the talk. Never on stage.
#
# Builds the pipeline under roar, tags the PII source, registers the lineage
# with GLaaS, and prints the hash you paste in Act 1.
#
#   ./prebake.sh                      # local only (no GLaaS registration)
#   SCOPE=treqs/roar-demo ./prebake.sh   # register under a TReqs project scope
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")"

say() { printf '\n\033[1;36m▸ %s\033[0m\n' "$1"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$1"; }

# --- preflight -------------------------------------------------------------
say "Preflight"

if [ ! -d .venv ]; then
  echo "creating .venv"
  uv venv --python 3.12 .venv >/dev/null 2>&1 || python3 -m venv .venv
  uv pip install -q -r requirements.txt --python .venv/bin/python 2>/dev/null \
    || .venv/bin/pip install -q -r requirements.txt
fi
# shellcheck disable=SC1091
source .venv/bin/activate

# Start from a pristine local db. Repeated rehearsals accumulate duplicate
# jobs, and `roar show` then reports "Produced by (4 jobs)" on stage. All of
# .roar/ is regenerated below; .roarconfig (path filters) is a separate file
# and survives. Set KEEP_DB=1 to skip.
if [ -d .roar ] && [ -z "${KEEP_DB:-}" ]; then
  echo "clearing .roar/ for a clean record (KEEP_DB=1 to skip)"
  rm -rf .roar
fi
[ -d .roar ] || roar init >/dev/null 2>&1
# Hints are great when learning, noise on a projector.
roar config set hints.enabled false >/dev/null 2>&1 || true

if ! git diff --quiet || ! git diff --cached --quiet; then
  warn "git tree is dirty — roar run requires a clean tree. Commit first."
  git status --short
  exit 1
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  warn "No git remote. 'roar reproduce --run' cannot clone on another machine."
  warn "Add one first:  git remote add origin git@github.com:treqs/roar-demo.git"
fi

echo "commit:  $(git rev-parse --short HEAD)"
echo "remote:  $(git remote get-url origin 2>/dev/null || echo 'none')"

# --- build -----------------------------------------------------------------
say "Building the pipeline under roar (fresh session)"
roar reset -y >/dev/null

# The PII tag is applied at the source, at ingestion. Everything downstream
# inherits it — that inheritance is the Act 3 hero.
roar run --add-tag contains_pii=present -n generate python make_data.py
roar run -n preprocess python preprocess.py
roar run -n train      python train.py
roar run -n evaluate   python evaluate.py

MODEL_HASH=$(roar dag --json --show-artifacts | python -c "
import json,sys
d = json.load(sys.stdin)
print(next(a['hash'] for a in d['artifacts'] if a['path'].endswith('model.pkl')))")

# --- enrich the AI-BOM -----------------------------------------------------
# These labels lift the AI-BOM completeness score on glaas.ai, so the Act 1
# page looks like a real bill of materials rather than a sparse stub.
say "Labelling for the AI-BOM"
roar label set artifact "$MODEL_HASH" \
  license.id=Apache-2.0 \
  documentation.url=https://glaas.ai/docs \
  description="Churn classifier — AI Camp demo" >/dev/null
echo "license.id, documentation.url, description"

# --- publish ---------------------------------------------------------------
if [ -n "${SCOPE:-}" ]; then
  say "Registering with GLaaS under scope: $SCOPE"
  roar scope use "$SCOPE"
  roar register "$MODEL_HASH" -y
  # Registering an artifact implies binding its tags to cross-session scope,
  # so the PII tag survives beyond this session. Explicit here for clarity.
  roar tag bind model.pkl metrics.json || true
else
  warn "SCOPE not set — skipping GLaaS registration."
  warn "Act 1's browser beat needs this. Re-run as: SCOPE=<org>/<project> ./prebake.sh"
fi

# --- the hash --------------------------------------------------------------
cat <<EOF

$(printf '\033[1;32m')╔════════════════════════════════════════════════════════════════════╗
║  ACT 1 HASH — paste this on stage                                  ║
╚════════════════════════════════════════════════════════════════════╝$(printf '\033[0m')

  full   $MODEL_HASH
  short  ${MODEL_HASH:0:12}

  metrics: $(cat metrics.json | tr -d '\n ' )

  Saved to ACT1_HASH.txt
EOF

echo "$MODEL_HASH" > ACT1_HASH.txt
