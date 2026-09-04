#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--step15m-dir", type=Path, required=True)
    ap.add_argument("--step15l-dir", type=Path, required=True)
    args = ap.parse_args()
    out = args.step15m_dir
    action = pd.read_csv(out / "action_dataset.csv")
    pred = pd.read_csv(out / "action_oof_predictions.csv")
    saved = pd.read_csv(out / "action_selected_count_frontier.csv")
    saved = saved[saved.model_scope == "GLOBAL_NO_SYMBOL"]
    checks = []

    def add(name, expected, actual, tolerance=0.0):
        try:
            passed = abs(float(expected) - float(actual)) <= tolerance
        except (TypeError, ValueError):
            passed = expected == actual
        checks.append({"check": name, "expected": expected, "actual": actual,
                       "tolerance": tolerance, "status": "PASS" if passed else "FAIL"})

    add("episode_count", 2696, action.episode_id.nunique())
    add("action_rows", 5392, len(action))
    add("duplicate_action_key", 0, action.duplicated(["episode_id", "action"]).sum())
    counts = action.groupby("action").tp_first.sum()
    add("continuation_tp", 84, counts.get("CONTINUATION", -1))
    add("reversal_tp", 104, counts.get("REVERSAL", -1))
    pair = action.pivot(index="episode_id", columns="action", values="tp_first")
    add("both_tp", 0, ((pair.CONTINUATION == 1) & (pair.REVERSAL == 1)).sum())
    add("both_sl", 2508, ((pair.CONTINUATION == 0) & (pair.REVERSAL == 0)).sum())

    primary = pred[(pred.model == "LIGHTGBM") & (pred.feature_group == "E_FULL") &
                   (pred.with_symbol.astype(str).str.lower() == "false") &
                   (pred.symbol_scope == "ALL")]
    primary = (primary.sort_values(["episode_id", "score", "action"], ascending=[True, False, True])
               .drop_duplicates("episode_id").sort_values(["score", "t0_msc", "episode_id"],
                                                            ascending=[False, True, True]))
    add("oof_episode_count", 1620, primary.episode_id.nunique())
    for _, row in saved.iterrows():
        n = int(row.policy_value); z = primary.head(n)
        add(f"top{n}_trades", n, len(z))
        add(f"top{n}_tp", int(row.tp), int(z.tp_first.sum()))
        add(f"top{n}_mean_r", float(row.mean_r), float(z.realized_r.mean()), 1e-12)

    clean = pd.read_csv(args.step15l_dir / "model_oof_predictions.csv")
    clean = clean[(clean.model == "LIGHTGBM") & (clean.feature_group == "E_FULL") &
                  (clean.with_symbol.astype(str).str.lower() == "false")]
    ids = set(clean.sort_values(["score", "t0_msc", "episode_id"],
                                ascending=[False, True, True]).head(327).episode_id)
    audit = action[action.episode_id.isin(ids)].pivot(index="episode_id", columns="action", values="tp_first")
    add("step15l_top327_cont_tp", 23, audit.CONTINUATION.sum())
    add("step15l_top327_rev_tp", 22, audit.REVERSAL.sum())
    add("step15l_top327_both_sl", 282, ((audit.CONTINUATION == 0) & (audit.REVERSAL == 0)).sum())

    result = pd.DataFrame(checks)
    result.to_csv(out / "independent_recalculation.csv", index=False)
    failed = int((result.status != "PASS").sum())
    (out / "independent_recalculation.md").write_text(
        "# Step 15M independent recalculation\n\n"
        f"- Checks: {len(result)}\n- PASS: {len(result)-failed}\n- FAIL: {failed}\n"
        "- Oracle inputs: persisted action rows, persisted OOF scores, and frozen Step 15L scores.\n"
        "- No fitted model was called by this oracle.\n",
        encoding="utf-8",
    )
    if failed:
        raise SystemExit(f"independent QA failed: {failed}")
    print(f"independent_checks={len(result)} pass={len(result)} fail=0")


if __name__ == "__main__":
    main()
