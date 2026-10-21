"""Recompute fixed synthetic cases through Python simulate, then compare MT5 CSV.

This proves limited arithmetic parity, not actual order execution, strategy
profitability, tick ordering, or historical spread/contract accuracy.
"""
from pathlib import Path
import hashlib
import json
import re
import sys

import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[4]
sys.path.insert(0, str(REPO))
from tools.entry_research.multiasset.execution import floor_volume, quote_to_usd, simulate


def fixture(symbol="EURUSD", side="LONG"):
    jpy = symbol == "USDJPY"
    price, atr = (150., .1) if jpy else (1.1, .001)
    times = 1704186000 + np.arange(6)*300
    bars = pd.DataFrame({"time": times, "open": price, "high": price+atr*.4,
                         "low": price-atr*.4, "close": price, "spread": 15 if jpy else 20})
    candidates = pd.DataFrame({"candidate_id": ["synthetic"], "method": ["fixture"], "side": [side],
        "symbol": [symbol], "signal_index": [0], "signal_time": [times[1]],
        "entry_index": [1], "entry_time": [times[1]], "atr14": [atr]})
    spec = {"symbol": symbol, "point": .001 if jpy else .00001, "pip_size": .01 if jpy else .0001,
        "contract_size": 100000, "volume_min": .01, "volume_step": .01, "volume_max": 100,
        "currency_profit": symbol[3:], "historical_spec_verified": False}
    config = {"max_hold_bars": 2, "timeframe_seconds": 300, "initial_equity": 10000,
        "risk_fraction": .001, "sl_atr": 1., "tp_atr": 1., "slippage_pips_per_side": .2,
        "commission_per_lot_roundtrip_usd": 0}
    return bars, candidates, spec, config


def main():
    bars, candidates, spec, config = fixture()
    bars.loc[1, ["high", "low"]] = [1.102, 1.098]
    results = simulate(bars, candidates, spec, config)["trades"].set_index("scenario")
    lo, hi = results.loc["stop_first_lower"], results.loc["target_first_upper"]
    rows = []

    def check(name, actual, expected):
        rows.append({"case": name, "actual": float(actual), "expected": float(expected),
                     "result": "PASS" if np.isclose(actual, expected, atol=1e-8, rtol=0) else "FAIL"})

    check("EURUSD_LONG_entry", lo.entry_fill, 1.10022)
    check("EURUSD_LONG_stop", lo.stop_price, 1.09922)
    check("EURUSD_LONG_target", lo.target_price, 1.10122)
    check("EURUSD_risk_per_lot", lo.planned_risk_usd/lo.volume, 102)
    check("floor_volume", lo.volume, .09)
    check("minimum_lot_rejected", floor_volume(10, 102, .1, .01, 100), 0)
    check("LONG_stop_net", lo.net_pnl_usd, -9.18)
    check("LONG_target_net", hi.net_pnl_usd, 8.82)
    check("LONG_stop_R", lo.result_r, -1)
    bars, candidates, spec, config = fixture()
    bars.loc[2, ["open", "high", "low", "close"]] = [1.098, 1.0985, 1.0975, 1.098]
    gap = simulate(bars, candidates, spec, config)["trades"].iloc[0]
    check("LONG_gap_stop_fill", gap.exit_fill, 1.09798)
    check("LONG_gap_stop_net", gap.net_pnl_usd, -20.16)
    check("same_bar_ambiguous", float(lo.ambiguous), 1)
    bars, candidates, spec, config = fixture(side="SHORT")
    bars.loc[1, ["high", "low"]] = [1.102, 1.098]
    shorts = simulate(bars, candidates, spec, config)["trades"].set_index("scenario")
    check("SHORT_entry", shorts.iloc[0].entry_fill, 1.09998)
    check("SHORT_stop_net", shorts.loc["stop_first_lower", "net_pnl_usd"], -9.18)
    check("SHORT_target_net", shorts.loc["target_first_upper", "net_pnl_usd"], 8.82)
    check("USDCHF_historical_conversion", quote_to_usd("USDCHF", .9), 1.111111111111)
    check("USDCAD_historical_conversion", quote_to_usd("USDCAD", 1.35), .740740740741)
    bars, candidates, spec, config = fixture("USDJPY")
    bars.loc[1, "high"] = 150.2
    yen = simulate(bars, candidates, spec, config)["trades"].iloc[0]
    check("USDJPY_floor_volume", yen.volume, .14)
    check("USDJPY_target_conversion", yen.exit_conversion_quote_to_usd, 1/150.1245)
    check("USDJPY_target_net", yen.net_pnl_usd, .098*100000*.14/150.1245)
    python = pd.DataFrame(rows)
    python.to_csv(HERE / "python_fixture.csv", index=False)
    summary = {"scope": "synthetic_arithmetic_parity_only_no_orders", "python_checks": len(python),
        "python_failures": int(python.result.ne("PASS").sum()), "mql_status": "not_collected",
        "strategy_profitability_evidence": False, "actual_fill_evidence": False,
        "same_bar_tick_sequence_verified": False, "historical_spec_verified": False,
        "fixture_date": "2024-01-02", "tester_transport_period": "2024-01-03 to 2024-01-04"}
    compile_log = HERE / "compile.log"
    summary["compile_zero_errors_warnings"] = compile_log.exists() and "Result: 0 errors, 0 warnings" in compile_log.read_text(encoding="utf-16")
    report = HERE / "MultiassetResearchParity_20261016.htm"
    if report.exists():
        raw = report.read_bytes()
        html = raw.decode("utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")
        plain = re.sub(r"<[^>]+>", " ", html)
        plain = re.sub(r"\s+", " ", plain)
        summary["native_tester_period_verified"] = "M5 (2024.01.03 - 2024.01.04)" in plain
        summary["native_tester_zero_trades_verified"] = bool(re.search(r"(?:取引数:|Total Trades:)\s+0(?:\s|$)", plain))
        summary["native_report_sha256"] = hashlib.sha256(raw).hexdigest()
    journals = list(HERE.glob("journal_*.txt"))
    summary["native_pass_marker_verified"] = any("MULTIASSET_PARITY result=PASS checks=20 failures=0" in p.read_text(encoding="utf-8-sig") for p in journals)
    for name, path in {"execution": REPO / "tools/entry_research/multiasset/execution.py",
                       "mql_source": REPO / "mql/Experts/Research/MultiassetResearchParity.mq5",
                       "mql_binary": REPO / "mql/Experts/Research/MultiassetResearchParity.ex5"}.items():
        summary[name+"_sha256"] = hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None
    fixture_paths = sorted(HERE.glob("fixture_*.csv"))
    if fixture_paths:
        mql = pd.read_csv(fixture_paths[-1])
        joined = python.merge(mql, on="case", suffixes=("_python", "_mql"), how="outer", validate="one_to_one")
        joined["difference"] = joined.actual_python-joined.actual_mql
        joined["parity_pass"] = joined.result_python.eq("PASS") & joined.result_mql.eq("PASS") & joined.difference.abs().le(1e-8)
        joined.to_csv(HERE / "comparison.csv", index=False)
        summary.update(mql_status="PASS" if len(joined)==20 and joined.parity_pass.all() else "FAIL",
            mql_checks=len(mql), parity_checks=len(joined), parity_failures=int((~joined.parity_pass).sum()),
            max_absolute_difference=float(joined.difference.abs().max()), mql_fixture=fixture_paths[-1].name)
    (HERE / "parity_summary.json").write_text(json.dumps(summary, indent=2)+"\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))
    if summary["python_failures"] or summary["mql_status"] == "FAIL":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
