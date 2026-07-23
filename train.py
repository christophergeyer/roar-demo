"""Fit the churn model.

Contains the planted defect for the Act 3 callback: the "feature scaling"
below is fit on train AND test. Nothing declares this. The only place it
shows up is in what the process actually read at runtime.
"""

import pickle

import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler

FEATURES = ["tenure_months", "monthly_charges", "support_calls"]


def main() -> None:
    train = pd.read_csv("data/train.csv")

    # --- the leak -------------------------------------------------------
    # Scaling statistics are fit over the full dataset "so the columns are
    # on a consistent scale at inference time." This reads the test set.
    # It looks reasonable in review. It is not declared anywhere.
    test = pd.read_csv("data/test.csv")
    scaler = StandardScaler().fit(pd.concat([train[FEATURES], test[FEATURES]]))
    # --------------------------------------------------------------------

    model = LogisticRegression(random_state=0, max_iter=1000)
    model.fit(scaler.transform(train[FEATURES]), train["churn"])

    with open("model.pkl", "wb") as fh:
        pickle.dump({"model": model, "scaler": scaler, "features": FEATURES}, fh, protocol=5)

    print(f"trained on {len(train)} rows, {len(FEATURES)} features")
    print("wrote model.pkl")


if __name__ == "__main__":
    main()
