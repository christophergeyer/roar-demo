"""Split raw.csv into train/test. Drops the direct identifier columns.

Note what this does NOT do: dropping name/email/phone is not
anonymisation. The behavioural columns still carry the individual.
That is why the PII tag should — and does — keep propagating.
"""

import pandas as pd
from sklearn.model_selection import train_test_split

PII_COLUMNS = ["name", "email", "phone"]


def main() -> None:
    df = pd.read_csv("data/raw.csv")
    df = df.drop(columns=PII_COLUMNS)

    train, test = train_test_split(
        df, test_size=0.25, random_state=0, stratify=df["churn"]
    )

    train.to_csv("data/train.csv", index=False)
    test.to_csv("data/test.csv", index=False)

    print(f"dropped {len(PII_COLUMNS)} identifier columns")
    print(f"wrote data/train.csv  {len(train)} rows")
    print(f"wrote data/test.csv   {len(test)} rows")


if __name__ == "__main__":
    main()
