import argparse
import csv
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
EA_NAME = "ExpectedValue_MultiCurrency_FractalWave2TransitionTrader"
BACKTEST = REPO / "reports" / "backtest"
PRESETS = REPO / "reports" / "presets"
RUN_ROOT = BACKTEST / "runs" / "20260714_fractal_wave2_transition_state_review"
MATRIX = RUN_ROOT / "run_matrix.csv"

DEFAULTS = {
    "InpSymbols": "USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD",
    "InpTopContextTF": "16385",
    "InpParentTF": "15",
    "InpChildTF": "5",
    "InpRunMode": "4",
    "InpStopMode": "0",
    "InpPortfolioMode": "0",
    "InpParentWave2StartMode": "2",
    "InpChildAnchorMode": "1",
    "InpLegacyCurrentCodeDiagnostic": "false",
    "InpPivotDepth": "2",
    "InpATRPeriod": "14",
    "InpParentLookbackBars": "160",
    "InpChildLookbackBars": "240",
    "InpParentWave1MaxBars": "32",
    "InpParentWave2MaxBars": "48",
    "InpChildStructureMaxAgeBars": "144",
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
    ("a_diagnostic_current_code", "diagnostic_current_code", {
        "InpRunMode": "3", "InpParentWave2StartMode": "0",
        "InpChildAnchorMode": "0", "InpLegacyCurrentCodeDiagnostic": "true"}),
    ("b_wave2_start_first_close", "wave2_start_first_opposite_close", {
        "InpRunMode": "2", "InpParentWave2StartMode": "0"}),
    ("c_wave2_start_confirmed_pivot", "wave2_start_confirmed_parent_pivot", {
        "InpRunMode": "2", "InpParentWave2StartMode": "1"}),
    ("d_wave2_start_child_countertrend", "wave2_start_child_countertrend", {
        "InpRunMode": "2", "InpParentWave2StartMode": "2"}),
    ("e_latest_child_anchor_diagnostic", "latest_child_anchor_diagnostic", {
        "InpRunMode": "3", "InpParentWave2StartMode": "2"}),
    ("f_base_first_child_flip_mode0", "base_first_child_flip_mode0", {
        "InpRunMode": "4", "InpParentWave2StartMode": "0"}),
    ("g_base_first_child_flip_mode1", "base_first_child_flip_mode1", {
        "InpRunMode": "4", "InpParentWave2StartMode": "1"}),
    ("h_base_first_child_flip_mode2", "base_first_child_flip_mode2", {
        "InpRunMode": "4", "InpParentWave2StartMode": "2"}),
    ("i_child_stop_extreme_mode2", "child_stop_extreme_mode2", {
        "InpRunMode": "4", "InpParentWave2StartMode": "2", "InpStopMode": "0"}),
    ("j_parent_stop_extreme_mode2", "parent_stop_extreme_mode2", {
        "InpRunMode": "4", "InpParentWave2StartMode": "2", "InpStopMode": "1"}),
    ("k_one_symbol_mode2", "one_symbol_mode2", {
        "InpRunMode": "4", "InpParentWave2StartMode": "2", "InpPortfolioMode": "1"}),
]


def build_runs(phase):
    periods = []
    if phase in {"q1", "all"}:
        periods.append(("q1", "q1_quick", "2025.01.01", "2025.03.31"))
    if phase in {"full", "all"}:
        periods.append(("full2025", "full2025_validation", "2025.01.01", "2025.12.31"))
    return [
        {
            "run_id": f"{prefix}_{short}", "period_id": period_id,
            "from_date": from_date, "to_date": to_date,
            "variant": short, "variant_name": name, "overrides": overrides,
        }
        for prefix, period_id, from_date, to_date in periods
        for short, name, overrides in VARIANTS
    ]


def tester_ini(run, preset_name):
    report = f"MQL5\\Experts\\dev\\reports\\backtest\\{EA_NAME}_fw2sr_{run['run_id']}_report.html"
    return "\n".join([
        "; Fixed state-machine and latest-child-anchor review.", "", "[Experts]",
        "Enabled=0", "AllowLiveTrading=0", "AllowDllImport=0", "Account=0", "Profile=0",
        "", "[Tester]",
        "Expert=dev\\mql\\Experts\\ExpectedValue_MultiCurrency_FractalWave2TransitionTrader.ex5",
        f"PresetSource=reports\\presets\\{preset_name}", f"PresetName={preset_name}",
        "Symbol=USDJPY", "Period=M15", "Model=4", "ExecutionMode=0", "Optimization=0",
        "OptimizationCriterion=6", f"FromDate={run['from_date']}", f"ToDate={run['to_date']}",
        "ForwardMode=0", "Deposit=10000", "Currency=USD", "Leverage=1:100",
        "UseLocal=1", "UseRemote=0", "UseCloud=0", "Visual=0", "ReplaceReport=1",
        "ShutdownTerminal=1", f"Report={report}",
    ]) + "\n"


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
        values["InpMagicNumber"] = str(202607140000 + index)
        values["InpRunId"] = run["run_id"]
        values["InpLogFolder"] = f"fractal_wave2_state_review_{run['run_id']}"
        preset_name = f"{EA_NAME}_fw2sr_{run['run_id']}.set"
        ini_name = f"{EA_NAME}_fw2sr_{run['run_id']}.ini"
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
            "run_mode": values["InpRunMode"], "stop_mode": values["InpStopMode"],
            "portfolio_mode": values["InpPortfolioMode"],
            "parent_wave2_start_mode": values["InpParentWave2StartMode"],
            "child_anchor_mode": values["InpChildAnchorMode"],
            "legacy_current_code": values["InpLegacyCurrentCodeDiagnostic"],
            "parent_tf": values["InpParentTF"], "child_tf": values["InpChildTF"],
            "top_context_tf": values["InpTopContextTF"],
            "target_r": values["InpTargetR"], "max_hold_bars": values["InpMaxHoldBars"],
        })
        rows.append(row)
    fields = list(dict.fromkeys(key for row in rows for key in row))
    with MATRIX.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {len(rows)} fixed runs to {MATRIX}")


if __name__ == "__main__":
    main()
