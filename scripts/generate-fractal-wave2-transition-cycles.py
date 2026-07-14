import argparse
import csv
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
EA_NAME = "ExpectedValue_MultiCurrency_FractalWave2TransitionTrader"
BACKTEST = REPO / "reports" / "backtest"
PRESETS = REPO / "reports" / "presets"
RUN_ROOT = BACKTEST / "runs" / "20260711_fractal_wave2_transition"
MATRIX = RUN_ROOT / "run_matrix.csv"

DEFAULTS = {
    "InpSymbols": "USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD",
    "InpTopContextTF": "16385",  # PERIOD_H1
    "InpParentTF": "15",         # PERIOD_M15
    "InpChildTF": "5",           # PERIOD_M5
    "InpRunMode": "4",
    "InpStopMode": "0",
    "InpPortfolioMode": "0",
    "InpPivotDepth": "2",
    "InpATRPeriod": "14",
    "InpParentLookbackBars": "160",
    "InpChildLookbackBars": "240",
    "InpParentWave1MaxBars": "32",
    "InpParentWave2MaxBars": "48",
    "InpParentWave2InvalidationUseClose": "true",
    "InpEntryOnFirstChildTrendFlip": "true",
    "InpChildFlipMaxSignalAgeBars": "1",
    "InpRequireChildTrendBeforeFlip": "true",
    "InpOneEntryPerParentWave2": "true",
    "InpConsumeSignalBeforePortfolioSelection": "true",
    "InpTargetR": "1.30",
    "InpMaxHoldBars": "30",
    "InpRiskPerTradePercent": "0.25",
    "InpMaxTotalOpenRiskPercent": "2.50",
    "InpMaxRiskPerSymbolPercent": "0.50",
    "InpMaxPositions": "6",
    "InpDailyMaxLossPercent": "3.00",
    "InpMaxDrawdownPercent": "15.00",
    "InpMaxSpreadATR": "0.20",
    "InpStopBufferATR": "0.10",
    "InpFixedLotFallback": "0.01",
    "InpMaxLotCap": "1.00",
    "InpSlippagePoints": "20",
    "InpBrokerUtcOffsetHours": "3",
    "InpUseCommonFiles": "true",
}

VARIANTS = [
    ("a_parent_flip", "parent_flip_only_diagnostic", {"InpRunMode": "0"}),
    ("b_parent_wave2", "parent_wave1_wave2_diagnostic", {"InpRunMode": "1"}),
    ("c_child_countertrend", "child_countertrend_diagnostic", {"InpRunMode": "2"}),
    ("d_child_flip", "child_flip_diagnostic", {"InpRunMode": "3"}),
    ("e_base_first_child_flip", "base_first_child_flip", {"InpRunMode": "4"}),
    ("f_child_stop", "child_flip_stop_child_extreme", {"InpRunMode": "4", "InpStopMode": "0"}),
    ("g_parent_stop", "child_flip_stop_parent_extreme", {"InpRunMode": "4", "InpStopMode": "1"}),
    ("h_one_symbol", "one_symbol_first_child_flip", {"InpRunMode": "4", "InpPortfolioMode": "1"}),
    ("i_h1_diag", "all_symbols_h1_alignment_diag", {"InpRunMode": "4"}),
    ("j_full_fractal_diag", "all_symbols_full_fractal_diag", {"InpRunMode": "4"}),
]


def build_runs(phase):
    periods = []
    if phase in {"q1", "all"}:
        periods.append(("q1", "q1_quick", "2025.01.01", "2025.03.31"))
    if phase in {"full", "all"}:
        periods.append(("full2025", "full2025_validation", "2025.01.01", "2025.12.31"))
    runs = []
    for prefix, period_id, from_date, to_date in periods:
        for short, variant_name, overrides in VARIANTS:
            runs.append({
                "run_id": f"{prefix}_{short}",
                "period_id": period_id,
                "from_date": from_date,
                "to_date": to_date,
                "variant": short,
                "variant_name": variant_name,
                "overrides": overrides,
            })
    return runs


def tester_ini(run, preset_name):
    report = f"MQL5\\Experts\\dev\\reports\\backtest\\{EA_NAME}_fw2t_{run['run_id']}_report.html"
    return "\n".join([
        "; Standalone M15 parent wave2 / first M5 child trend flip research.",
        "", "[Experts]", "Enabled=0", "AllowLiveTrading=0", "AllowDllImport=0",
        "Account=0", "Profile=0", "", "[Tester]",
        "Expert=dev\\mql\\Experts\\ExpectedValue_MultiCurrency_FractalWave2TransitionTrader.ex5",
        f"PresetSource=reports\\presets\\{preset_name}",
        f"PresetName={preset_name}",
        "Symbol=USDJPY", "Period=M15", "Model=4", "ExecutionMode=0", "Optimization=0",
        "OptimizationCriterion=6", f"FromDate={run['from_date']}", f"ToDate={run['to_date']}",
        "ForwardMode=0", "Deposit=10000", "Currency=USD", "Leverage=1:100",
        "UseLocal=1", "UseRemote=0", "UseCloud=0", "Visual=0", "ReplaceReport=1",
        "ShutdownTerminal=1", f"Report={report}",
    ]) + "\n"


def write_matrix(rows):
    fields = []
    for row in rows:
        for key in row:
            if key not in fields:
                fields.append(key)
    with MATRIX.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase", choices=["q1", "full", "all"], default="all")
    args = parser.parse_args()
    BACKTEST.mkdir(parents=True, exist_ok=True)
    PRESETS.mkdir(parents=True, exist_ok=True)
    RUN_ROOT.mkdir(parents=True, exist_ok=True)
    rows = []
    for index, run in enumerate(build_runs(args.phase), start=1):
        values = dict(DEFAULTS)
        values.update(run["overrides"])
        values["InpMagicNumber"] = str(202607112000 + index)
        values["InpRunId"] = run["run_id"]
        values["InpLogFolder"] = f"fractal_wave2_transition_{run['run_id']}"
        preset_name = f"{EA_NAME}_fw2t_{run['run_id']}.set"
        ini_name = f"{EA_NAME}_fw2t_{run['run_id']}.ini"
        preset_text = "\n".join(f"{key}={value}" for key, value in values.items()) + "\n"
        ini_text = tester_ini(run, preset_name)
        (PRESETS / preset_name).write_text(preset_text, encoding="utf-8")
        (BACKTEST / ini_name).write_text(ini_text, encoding="utf-8")
        run_dir = RUN_ROOT / run["run_id"]
        run_dir.mkdir(parents=True, exist_ok=True)
        (run_dir / "preset.set").write_text(preset_text, encoding="utf-8")
        (run_dir / "tester.ini").write_text(ini_text, encoding="utf-8")
        row = {key: value for key, value in run.items() if key != "overrides"}
        row.update({
            "preset": f"reports/presets/{preset_name}",
            "tester_ini": f"reports/backtest/{ini_name}",
            "log_folder": values["InpLogFolder"],
            "run_mode": values["InpRunMode"],
            "stop_mode": values["InpStopMode"],
            "portfolio_mode": values["InpPortfolioMode"],
            "parent_tf": values["InpParentTF"],
            "child_tf": values["InpChildTF"],
            "top_context_tf": values["InpTopContextTF"],
            "target_r": values["InpTargetR"],
            "max_hold_bars": values["InpMaxHoldBars"],
        })
        rows.append(row)
    write_matrix(rows)
    print(f"Wrote {len(rows)} runs to {MATRIX}")


if __name__ == "__main__":
    main()
