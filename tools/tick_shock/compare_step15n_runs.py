#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd


KEY = ["symbol", "t0_msc", "checkpoint_seconds", "action"]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rejected", type=Path, required=True)
    parser.add_argument("--formal", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    old = pd.read_csv(args.rejected / "delayed_decision_actions.csv")
    new = pd.read_csv(args.formal / "delayed_decision_actions.csv")
    joined = old.merge(new, on=KEY, how="outer", suffixes=("_r1", "_r2"), indicator=True)
    both = joined[joined["_merge"] == "both"]
    comparisons = {
        "action_rows_r1": len(old),
        "action_rows_r2": len(new),
        "key_mismatch": int((joined["_merge"] != "both").sum()),
        "checkpoint_status_difference": int((both.checkpoint_status_r1 != both.checkpoint_status_r2).sum()),
        "decision_clock_difference": int((~np.isclose(both.decision_quote_msc_r1, both.decision_quote_msc_r2, equal_nan=True)).sum()),
        "entry_clock_difference": int((~np.isclose(both.entry_quote_msc_r1, both.entry_quote_msc_r2, equal_nan=True)).sum()),
        "exit_clock_difference": int((~np.isclose(both.exit_msc_r1, both.exit_msc_r2, equal_nan=True)).sum()),
        "result_label_difference": int((both.result_r1 != both.result_r2).sum()),
        "realized_r_difference": int((~np.isclose(both.realized_r_r1, both.realized_r_r2, equal_nan=True)).sum()),
        "r2_tp_r_violation": int(((new.result == "TP_FIRST") & ~np.isclose(new.realized_r, 1.6)).sum()),
        "r2_sl_r_violation": int(((new.result == "SL_FIRST") & ~np.isclose(new.realized_r, -1.0)).sum()),
    }
    rows = [{"check": key, "actual": value} for key, value in comparisons.items()]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    pd.DataFrame(rows).to_csv(args.output, index=False)


if __name__ == "__main__":
    main()
