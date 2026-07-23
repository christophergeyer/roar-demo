#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# PRE-BAKE — run this BEFORE the talk. Never on stage.
#
# Builds the pipeline under roar, tags the PII source, registers the lineage
# with GLaaS, and prints the hash you paste in Act 1.
#
#   ./prebake.sh                    # registers under the default scope below
#   SCOPE=treqs/other ./prebake.sh  # override the scope
#   SCOPE=none ./prebake.sh         # build locally, skip GLaaS registration
# ---------------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")"

# Where the Act 1 artifact gets registered so the hash resolves on glaas.ai.
# Defaults to the demo project; override with SCOPE=..., or SCOPE=none to skip.
SCOPE="${SCOPE:-treqs/roar-demo}"

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

# --- fresh seed ------------------------------------------------------------
# A new seed each bake gives a unique hash and a unique session. It MUST be
# committed: `roar reproduce` clones the recorded commit, so the seed has to
# travel with it — otherwise the rebuilt hash wouldn't match. Set FIXED_SEED
# to pin a value (e.g. for a scripted rehearsal); otherwise it's random.
SEED="${FIXED_SEED:-$(python -c 'import secrets; print(secrets.randbelow(2**31))')}"
say "Baking seed $SEED into make_data.py"
python - "$SEED" <<'PY'
import re, sys
seed = sys.argv[1]
path = "make_data.py"
src = open(path).read()
new, n = re.subn(r"^SEED = .*$", f"SEED = {seed}", src, count=1, flags=re.M)
if n != 1:
    sys.exit("could not find the 'SEED = ...' line in make_data.py")
open(path, "w").write(new)
PY
git commit -q -m "prebake: seed $SEED" -- make_data.py

if git remote get-url origin >/dev/null 2>&1; then
  echo "pushing seed commit so reproduce can clone it"
  git push -q origin HEAD || warn "push failed — cold 'reproduce --run' won't find this commit"
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
if [ "$SCOPE" != "none" ]; then
  say "Registering with GLaaS under scope: $SCOPE"
  roar scope use "$SCOPE"
  # Register by path, not by hash: under 0.4.1 a bare hash is read as a session
  # ref ("No local session matches ..."), whereas the path registers the
  # artifact and, per roar, implies binding its tags to cross-session scope.
  roar register model.pkl -y
  roar tag bind model.pkl metrics.json || true
else
  warn "SCOPE=none — skipping GLaaS registration (local build only)."
  warn "Act 1's browser beat needs registration. Re-run without SCOPE=none."
fi

# --- stage the "mystery file" ----------------------------------------------
# A naked copy of the model, no roar project around it, for the opening beat:
# b3sum it, paste the hash, watch it dereference. The dir is emptied to
# exactly one file so nothing else is on screen. Override with DEMO_DIR=...
DEMO_DIR="${DEMO_DIR:-$HOME/Demo}"
say "Staging the mystery file in $DEMO_DIR"
mkdir -p "$DEMO_DIR"
# Empty the CONTENTS (including dotfiles) but keep the dir itself, so a shell
# already sitting in $DEMO_DIR stays valid — it just needs to `ls` again.
# -mindepth 1 spares the dir; :? guards against an empty/unset expansion.
find "${DEMO_DIR:?}" -mindepth 1 -delete
cp model.pkl "$DEMO_DIR/unknown_model.pkl"
echo "  $DEMO_DIR/unknown_model.pkl  ($(b3sum "$DEMO_DIR/unknown_model.pkl" 2>/dev/null | cut -c1-12 || echo 'b3sum: install for the live hash'))"

# --- the hash --------------------------------------------------------------
cat <<EOF

$(printf '\033[1;32m')╔════════════════════════════════════════════════════════════════════╗
║  ACT 1 HASH — paste this on stage                                  ║
╚════════════════════════════════════════════════════════════════════╝$(printf '\033[0m')

  full   $MODEL_HASH
  short  ${MODEL_HASH:0:12}

  metrics: $(cat metrics.json | tr -d '\n ' )

  Saved to ACT1_HASH.txt
  Mystery file: $DEMO_DIR/unknown_model.pkl  (b3sum → this hash)
EOF

echo "$MODEL_HASH" > ACT1_HASH.txt
