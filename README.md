# roar — live demo for "A Single Source of Truth for AI Builders"

A three-act demo of `roar`. **Lead with the noun** (the record, and what anyone
can do with it). **The verb — `roar run` — is the kicker.**

The v1 demo led with the mechanism, and the value of the catch was a
counterfactual the audience had to imagine. This one shows the artifact first
and the instrumentation last, so the payoff lands before the explanation. If
you get cut off after Act 2, the audience has already seen the whole value.

---

## Before the talk

```bash
git clone <this repo> && cd roar-demo
roar auth login          # once, so registration can publish to glaas.ai
./prebake.sh             # registers under treqs/roar-demo by default
```

`prebake.sh` defaults `SCOPE=treqs/roar-demo`, so a plain run registers the
artifact and the hash resolves on glaas.ai. Override with `SCOPE=treqs/other`,
or `SCOPE=none ./prebake.sh` to build locally without publishing.

Prints the hash you paste on stage and writes it to `ACT1_HASH.txt`.
**Never build the artifact live.** Each bake picks a fresh random seed, commits
it, pushes it, and produces a **new hash and a new session** — so rehearse
freely, then do one final bake right before you walk on. It clears `.roar/`
each time so `roar show` reports a single clean producer rather than "Produced
by (4 jobs)" from your rehearsals.

**Order matters, because the hash changes each bake:**

```
1. ./prebake.sh          ← final bake; note the hash
2. ./cast/record.sh      ← records fallbacks against THAT hash
3. don't bake again      ← or the recording won't match your slide
```

Then rehearse:

```bash
./demo.sh          # full run, press ENTER between beats
./demo.sh --90     # the 90-second cut
```

`demo.sh` leaves the repo pristine — git stays clean and the session is
untouched — so you can run it back to back.

---

## The arc

| Act | Time | Beat | Command | Net |
|---|---|---|---|---|
| **1 — Wonder** | ~2 min | "This model is this hash" | *(paste the hash)* | |
| | | The whole record | `roar show <hash>` | |
| | | What it actually read | `roar inputs --all <hash>` | |
| | | The pipeline shape | `roar dag` | |
| | | The AI-BOM in a browser | glaas.ai → **Audit (AI-BOM)** | **NET** |
| | | The recorded plan | `roar reproduce <hash>` | |
| | | Rebuild it for real | `roar reproduce <hash> --run` | **NET** |
| **2 — Reveal** | ~30 s | "It was free" | `roar run python train.py` | |
| **3 — Payoff** | ~2 min | One human act | `roar tag show data/raw.csv` | |
| | | **Blast radius** (hero) | `python taint.py` | |
| | | It shows its work | `roar tag why contains_pii model.pkl` | |
| | | *Optional callback* | `roar show @3` | |

### Act 1 — Wonder

Walk on stage with the model already made. The hash is the whole opening: it
isn't a checksum, it *dereferences*. `roar show` gives inputs, commit,
environment, packages, timing, exit status. `roar inputs` gives every file the
run actually read — observed at runtime, not declared in a config.

Then the money beat: **`roar reproduce` rebuilds the artifact from the hash
alone** and the rebuilt hash is bit-identical. You don't have to trust me.

### Act 2 — The reveal

One line, one breath:

```
$ roar run python train.py
```

Everything in Act 1 came from typing that in front of the training command. No
config, no instrumentation, no pipeline declaration. The reveal is that it was
free.

### Act 3 — Payoff

The hero is **PII propagation**. One human act — tagging the raw dataset —
and the tag follows the data through every derived artifact. `taint.py` paints
it down the screen, one artifact at a time: five of five, nobody declared it.
That's the answer to "which models are affected?", which is a question no
config file can answer.

`roar tag why` then proves it isn't a guess — it walks the inheritance path
back to the human act. Note it surfaces **two** paths into `model.pkl`
(train.csv *and* test.csv), which quietly sets up the callback.

**The optional callback** is the train-on-test catch: `roar show @3` lists
`data/test.csv` in train's inputs. `train.py` fits scaling statistics over
train + test — it passes code review, it's in no config, and the run recorded
it because the run couldn't lie about it. **Cut this first if you're rushed.**

---

## If you only have 90 seconds

```bash
./demo.sh --90
```

Act 1 + Act 2. Drops the live `--run` rebuild (shows the instant recorded plan
instead) and all of Act 3. You still land both principles: capture everything
at runtime, and every hash dereferences.

**Cut order when the clock moves on you:**
1. The train-on-test callback (Act 3 last beat)
2. `roar tag why` — the blast radius alone carries Act 3
3. `roar dag` in Act 1
4. The live `--run` — show the instant preview and say "I can run this for real"

Never cut: the hash, `roar show`, and Act 2.

---

## Network beats and fallbacks

Only two beats touch the network. Both have a recorded fallback.

| Beat | Risk | Fallback |
|---|---|---|
| glaas.ai AI-BOM page | Browser + API | `cast/glaas-aibom.mov` |
| `roar reproduce --run` | git clone + pip install | `cast/reproduce.cast` |

Everything else — `show`, `inputs`, `dag`, `tag show`, `tag why`, `taint.py`,
and the `reproduce` preview — is **entirely local**. If the wifi dies you lose
one browser page and one rebuild, and the demo still works.

Record the fallbacks on your presentation machine, at your presentation
terminal size:

```bash
./cast/record.sh          # → cast/demo.cast, cast/reproduce.cast
asciinema play cast/reproduce.cast
```

`record.sh` cannot capture the glaas.ai page — that's a browser. Record it
with a screen recorder (macOS: Cmd-Shift-5) and save as `cast/glaas-aibom.mov`.

---

## Legibility from the back of the room

- **Run from a short path.** `roar` prints absolute paths. From
  `~/Documents/Program/roar-demo` they wrap; from `~/demo` they don't.
  Clone to `~/demo` for the talk.
- Hints are disabled by `prebake.sh` (`roar config set hints.enabled false`).
- macOS noise (`~/.CFUserTextEncoding`) is filtered via `.roarconfig` so it
  doesn't appear in `roar inputs`.
- `taint.py` animates by default (~0.45s per artifact) — that pacing is the
  "motion". `--fast` disables it, `--plain` drops colour.

---

## The pipeline

Four steps, CPU-only, ~6 seconds total, deterministic given the baked seed.

```
@1 generate    make_data.py    → data/raw.csv       [tagged contains_pii]
@2 preprocess  preprocess.py   → data/train.csv, data/test.csv
@3 train       train.py        → model.pkl          [reads test.csv — the leak]
@4 evaluate    evaluate.py     → metrics.json
```

Deterministic *given a seed*. `prebake.sh` picks a fresh random seed each bake,
writes it into `make_data.py`, and commits it — so **every bake yields a unique
hash and a unique session**, while `roar reproduce` still rebuilds any given
hash bit-for-bit, because it checks out the commit that carries that seed. Set
`FIXED_SEED=<n> ./prebake.sh` to pin a value for a scripted rehearsal.

Two consequences of per-bake hashes:
- **The metrics move a little each bake** (~`accuracy 0.7x`, `roc_auc 0.8x`) —
  stable within one artifact, not across bakes.
- **The fallback casts are only valid for the most recent bake.** Record them
  *after* your final pre-talk prebake, or the hash in the recording won't match
  the one you paste. See below.

`data/`, `model.pkl` and `metrics.json` are gitignored: everything is derived,
and reproduction regenerates it all from code.

**The planted leak** is in `train.py` — scaling statistics are fit over
`concat([train, test])`. It's deliberately reasonable-looking. Nothing declares
it; only the runtime record catches it.

**The PII** is real, not a prop: `make_data.py` writes `name`, `email` and
`phone` columns. `preprocess.py` drops those three columns — and the tag
*still* propagates, correctly, because dropping identifiers is not
anonymisation. That's the honest version of the story.

---

## Setup

Python 3.10+, `roar-cli` (tested against **0.4.0**).

```bash
uv tool install roar-cli     # or: pipx install roar-cli
uv venv --python 3.12 .venv && uv pip install -r requirements.txt --python .venv/bin/python
```

`prebake.sh` creates the venv if it's missing.

---

## Two things this repo needs from you

1. **A git remote.** `roar reproduce` records the clone URL at pre-bake time,
   so this must be set *before* the hash is minted:
   ```bash
   git remote add origin git@github.com:treqs/roar-demo.git && git push -u origin main
   ```
   Without a reachable remote, roar's reproducibility scorecard shows **4/5**
   with `[❌] commit reachable on a remote`. With one it shows **5/5** — a
   better thing to have on screen.

2. **A TReqs project scope**, for the AI-BOM page:
   ```bash
   roar auth login
   roar scope use treqs/<project>
   SCOPE=treqs/<project> ./prebake.sh
   ```
   The AI-BOM view requires an organisation scope. Without it, `prebake.sh`
   still builds everything and prints the hash, but the browser beat won't
   resolve and `roar reproduce` from a *fresh* machine won't find the artifact
   (it falls back to the local `.roar` db, which only exists on your laptop).
