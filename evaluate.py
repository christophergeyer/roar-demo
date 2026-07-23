"""Score the model on the held-out test set. Deterministic output."""

import json
import pickle

import pandas as pd
from sklearn.metrics import accuracy_score, roc_auc_score


def main() -> None:
    with open("model.pkl", "rb") as fh:
        bundle = pickle.load(fh)

    model, scaler, features = bundle["model"], bundle["scaler"], bundle["features"]
    test = pd.read_csv("data/test.csv")

    X = scaler.transform(test[features])
    pred = model.predict(X)
    prob = model.predict_proba(X)[:, 1]

    metrics = {
        "accuracy": round(float(accuracy_score(test["churn"], pred)), 4),
        "roc_auc": round(float(roc_auc_score(test["churn"], prob)), 4),
        "n_test": int(len(test)),
    }

    with open("metrics.json", "w") as fh:
        json.dump(metrics, fh, indent=2)
        fh.write("\n")

    print(f"accuracy {metrics['accuracy']}   roc_auc {metrics['roc_auc']}")
    print("wrote metrics.json")


if __name__ == "__main__":
    main()
