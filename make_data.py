"""Generate the raw customer dataset.

Deterministic *given the seed*. `prebake.sh` rewrites SEED below and commits
it, so each bake produces a fresh artifact (new hash, new session) while
`roar reproduce` still rebuilds any given hash bit-for-bit — it checks out the
commit that carries that seed.

This is the PII source. It writes real-looking personal columns
(name, email, phone) alongside the modelling features, which is what
makes `contains_pii=present` an honest tag rather than a demo prop.
"""

import os

import numpy as np
import pandas as pd

SEED = 1582741469
RNG = np.random.default_rng(SEED)
N = 400

FIRST = ["Ana", "Ben", "Cara", "Dev", "Eli", "Fay", "Gus", "Hana"]
LAST = ["Diaz", "Okafor", "Lindqvist", "Mehta", "Nakamura", "Rossi"]


def main() -> None:
    # data/ is gitignored — a fresh clone (or a `roar reproduce`) starts without it.
    os.makedirs("data", exist_ok=True)

    first = RNG.choice(FIRST, N)
    last = RNG.choice(LAST, N)

    tenure = RNG.integers(1, 72, N)
    monthly = np.round(RNG.uniform(20, 120, N), 2)
    support = RNG.poisson(1.5, N)

    # Churn is a function of standardised features plus seeded noise: real,
    # learnable signal (AUC ~0.85) so the eval numbers look like a model
    # someone would actually ship, and identical on every run.
    z = lambda a: (a - a.mean()) / a.std()
    logit = -0.6 + 0.9 * z(support) + 1.1 * z(monthly) - 1.4 * z(tenure)
    churn = (1 / (1 + np.exp(-logit)) > RNG.uniform(0, 1, N)).astype(int)

    df = pd.DataFrame(
        {
            "customer_id": [f"C{i:04d}" for i in range(N)],
            "name": [f"{f} {l}" for f, l in zip(first, last)],
            "email": [f"{f}.{l}@example.com".lower() for f, l in zip(first, last)],
            "phone": [f"555-01{RNG.integers(10, 99)}" for _ in range(N)],
            "tenure_months": tenure,
            "monthly_charges": monthly,
            "support_calls": support,
            "churn": churn,
        }
    )

    df.to_csv("data/raw.csv", index=False)
    print(f"wrote data/raw.csv  {len(df)} rows, {len(df.columns)} cols")
    print("  PII columns: name, email, phone")


if __name__ == "__main__":
    main()
