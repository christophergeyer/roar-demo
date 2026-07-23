#!/usr/bin/env python3
"""Render the blast radius of a compliance tag across the session DAG.

roar knows all of this — `roar tag show` will confirm any single artifact and
`roar tag why` explains any single inheritance path. What roar has no single
command for is the *downstream* view: one picture of everything a tag reached.
This reads `roar dag --json --show-artifacts` and draws it.

    python taint.py                     # contains_pii, painted step by step
    python taint.py --fast              # no animation
    python taint.py license --plain     # different tag, no colour
"""

import argparse
import json
import os
import subprocess
import sys
import time

RED = "\033[1;31m"
DIM = "\033[2m"
BOLD = "\033[1m"
OFF = "\033[0m"


def load_dag() -> dict:
    proc = subprocess.run(
        ["roar", "dag", "--json", "--show-artifacts"],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        sys.exit(f"roar dag failed:\n{proc.stderr.strip()}")
    return json.loads(proc.stdout)


def tag_values(artifact: dict, kind: str) -> list[str]:
    """Values of `kind` on this artifact, plus whether any was set by hand."""
    entry = artifact.get("labels", {}).get("tag", {}).get(kind)
    if not entry:
        return []
    return [v["value"] for v in entry.get("values", [])]


def is_origin(artifact: dict, kind: str) -> bool:
    entry = artifact.get("labels", {}).get("tag", {}).get(kind, {})
    return any(v.get("origin") == "user" for v in entry.get("values", []))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("kind", nargs="?", default="contains_pii")
    ap.add_argument("--fast", action="store_true", help="no animation")
    ap.add_argument("--plain", action="store_true", help="no colour")
    args = ap.parse_args()

    kind = args.kind
    dag = load_dag()
    colour = not args.plain and sys.stdout.isatty()
    red, dim, bold, off = (RED, DIM, BOLD, OFF) if colour else ("", "", "", "")
    pause = 0.0 if args.fast else 0.45

    steps = {n["step_number"]: n for n in dag["nodes"]}
    by_producer: dict[int, list[dict]] = {}
    for art in dag["artifacts"]:
        by_producer.setdefault(art.get("producer_step"), []).append(art)

    cwd = os.getcwd()
    tainted = clean = 0

    print()
    print(f"  {bold}BLAST RADIUS{off}   {kind}   ·   session {dag['session_id']}")
    print()
    sys.stdout.flush()

    for num in sorted(steps):
        step = steps[num]
        print(f"  {dim}@{num}{off} {step['step_name'] or step['command']}")
        sys.stdout.flush()
        time.sleep(pause * 0.4)

        for art in sorted(by_producer.get(num, []), key=lambda a: a["path"]):
            path = os.path.relpath(art["path"], cwd)
            values = tag_values(art, kind)

            if values:
                tainted += 1
                mark = "← tagged here" if is_origin(art, kind) else "inherited"
                label = f"{kind}={','.join(values)}"
                print(f"       {red}●{off} {path:<26}{red}{label:<24}{off}{dim}{mark}{off}")
            else:
                clean += 1
                print(f"       {dim}○ {path:<26}—{off}")
            sys.stdout.flush()
            time.sleep(pause)

    total = tainted + clean
    print()
    if tainted:
        print(f"  {red}{bold}{tainted} of {total} artifacts carry {kind}{off}")
        print(f"  {dim}nobody declared this. it followed the data.{off}")
    else:
        print(f"  {dim}no artifact carries {kind}{off}")
    print()


if __name__ == "__main__":
    main()
