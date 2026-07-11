import argparse
import csv
import importlib.util
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
EA_NAME = "ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader"
BACKTEST = REPO / "reports" / "backtest"
PRESETS = REPO / "reports" / "presets"
RUN_ROOT = BACKTEST / "runs" / "20260711_session_reversal_m5_micro_n_relaunch"
MATRIX = RUN_ROOT / "run_matrix.csv"


def load_previous_generator():
    path = REPO / "scripts" / "generate-session-reversal-m15-anchor-first-break-cycles.py"
    spec = importlib.util.spec_from_file_location("anchor_first_generator", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


previous = load_previous_generator()
DEFAULTS = dict(previous.DEFAULTS)
DEFAULTS.update({
    "InpUseM5PostAnchorRelaunch": "false",
    "InpM5PostAnchorRelaunchMode": "0",
    "InpM5MicroAnchorLookbackBars": "48",
    "InpM5MicroAnchorMinSwingStrength": "2",
    "InpM5RelaunchBreakUseClose": "true",
    "InpM5RelaunchBreakMinAtr": "0.05",
    "InpM5RelaunchMaxBarsAfterRetest": "12",
    "InpM5RelaunchFirstSignalMaxAgeBars": "1",
    "InpM5RequireNewMicroAnchorAfterM15Break": "true",
    "InpM5RelaunchRequireNormalBreakQuality": "false",
})

M15_DIAG = dict(previous.M15_DIAG_BASE)
ANCHOR_DIAG = {
    **M15_DIAG,
    "InpUseM15SwingAnchorBias": "true",
    "InpM15SwingAnchorMode": "1",
}
ANCHOR_PULLBACK_REQUIRED = {
    **ANCHOR_DIAG,
    "InpM15SwingAnchorMode": "4",
    "InpUseTruePostAnchorBreakPullback": "true",
    "InpPostAnchorPullbackMode": "3",
    "InpPostAnchorRequireM5Reconfirm": "false",
}
ANCHOR_OR = {
    **M15_DIAG,
    "InpUseM15SwingAnchorBias": "true",
    "InpM15SwingAnchorMode": "5",
    "InpUseTruePostAnchorBreakPullback": "true",
    "InpPostAnchorPullbackMode": "3",
    "InpPostAnchorRequireM5Reconfirm": "false",
}

VARIANTS = [
    ("base", "baseline_c10_reproduce", {
        "InpUseM5CorrectiveABC": "false", "InpM5CorrectiveMode": "0",
    }),
    ("light", "required_light_original_reproduce", {
        "InpM15WaveContextMode": "3",
        "InpUseM5CorrectiveABC": "true",
        "InpM5CorrectiveMode": "2",
    }),
    ("anchor_pullback", "anchor_first_break_pullback_reproduce", ANCHOR_PULLBACK_REQUIRED),
    ("micro_n_diag", "m5_micro_n_diagnostic", {
        **ANCHOR_DIAG,
        "InpUseTruePostAnchorBreakPullback": "true",
        "InpPostAnchorPullbackMode": "1",
        "InpPostAnchorRequireM5Reconfirm": "false",
        "InpUseM5PostAnchorRelaunch": "true",
        "InpM5PostAnchorRelaunchMode": "1",
    }),
    ("micro_n_required", "anchor_pullback_plus_m5_micro_n_required", {
        **ANCHOR_PULLBACK_REQUIRED,
        "InpUseM5PostAnchorRelaunch": "true",
        "InpM5PostAnchorRelaunchMode": "3",
    }),
    ("micro_n_first", "anchor_pullback_plus_m5_micro_n_first_signal", {
        **ANCHOR_PULLBACK_REQUIRED,
        "InpUseM5PostAnchorRelaunch": "true",
        "InpM5PostAnchorRelaunchMode": "4",
    }),
    ("micro_n_strong", "anchor_pullback_plus_m5_micro_n_strong_break", {
        **ANCHOR_PULLBACK_REQUIRED,
        "InpUseM5PostAnchorRelaunch": "true",
        "InpM5PostAnchorRelaunchMode": "4",
        "InpM5RelaunchRequireNormalBreakQuality": "true",
    }),
    ("light_or_micro_n", "required_light_OR_m5_micro_n_relaunch", {
        **ANCHOR_OR,
        "InpUseM5PostAnchorRelaunch": "true",
        "InpM5PostAnchorRelaunchMode": "3",
    }),
    ("light_or_micro_n_first", "required_light_OR_m5_micro_n_first_signal", {
        **ANCHOR_OR,
        "InpUseM5PostAnchorRelaunch": "true",
        "InpM5PostAnchorRelaunchMode": "4",
    }),
    ("light_or_micro_n_pattern", "required_light_OR_m5_micro_n_plus_pattern", {
        **ANCHOR_OR,
        "InpUseM5PostAnchorRelaunch": "true",
        "InpM5PostAnchorRelaunchMode": "4",
        "InpM15AnchorFlipRequireHighMediumM5Pattern": "true",
    }),
    ("light_or_micro_n_exhaustion", "required_light_OR_m5_micro_n_plus_exhaustion", {
        **ANCHOR_OR,
        "InpUseM5PostAnchorRelaunch": "true",
        "InpM5PostAnchorRelaunchMode": "4",
        "InpM15AnchorFlipRequireCorrectiveExhaustion": "true",
    }),
    ("one_micro_n_first", "one_symbol_m5_micro_n_first_signal", {
        **ANCHOR_PULLBACK_REQUIRED,
        "InpScenarioMode": "1",
        "InpUseM5PostAnchorRelaunch": "true",
        "InpM5PostAnchorRelaunchMode": "4",
    }),
    ("one_light_or_micro_n_first", "one_symbol_required_light_OR_m5_micro_n_first_signal", {
        **ANCHOR_OR,
        "InpScenarioMode": "1",
        "InpUseM5PostAnchorRelaunch": "true",
        "InpM5PostAnchorRelaunchMode": "4",
    }),
]


def scenario_from_values(values):
    mode = int(values.get("InpScenarioMode", DEFAULTS.get("InpScenarioMode", "0")))
    names = {
        0: "session_reversal_pullback_all_symbols_first120",
        1: "session_reversal_pullback_one_symbol_first120",
    }
    keys = {0: "all", 1: "one"}
    return keys.get(mode, "all"), mode, names.get(mode, names[0])


def build_runs(phase):
    periods = []
    if phase in {"q1", "all"}:
        periods.append(("q1", "q1_quick", "2025.01.01", "2025.03.31"))
    if phase in {"full", "all"}:
        periods.append(("full2025", "full2025_validation", "2025.01.01", "2025.12.31"))
    runs = []
    for prefix, period_id, from_date, to_date in periods:
        for short, name, values in VARIANTS:
            scenario_key, mode, scenario_name = scenario_from_values(values)
            runs.append((f"{prefix}_{short}", period_id, scenario_key, mode, scenario_name,
                         from_date, to_date, short, name, values))
    return runs


def tester_ini(run, preset_name):
    run_id, _, _, _, _, from_date, to_date, _, _, _ = run
    report_path = f"MQL5\\Experts\\dev\\reports\\backtest\\{EA_NAME}_micro_n_{run_id}_report.html"
    return "\n".join([
        "; First confirmed M5 micro-N relaunch after M15 anchor pullback.",
        "", "[Experts]", "Enabled=0", "AllowLiveTrading=0", "AllowDllImport=0",
        "Account=0", "Profile=0", "", "[Tester]",
        "Expert=dev\\mql\\Experts\\ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader.ex5",
        f"PresetSource=reports\\presets\\{preset_name}", f"PresetName={preset_name}",
        "Symbol=USDJPY", "Period=M15", "Model=4", "ExecutionMode=0", "Optimization=0",
        "OptimizationCriterion=6", f"FromDate={from_date}", f"ToDate={to_date}",
        "ForwardMode=0", "Deposit=10000", "Currency=USD", "Leverage=1:100",
        "UseLocal=1", "UseRemote=0", "UseCloud=0", "Visual=0", "ReplaceReport=1",
        "ShutdownTerminal=1", f"Report={report_path}",
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
        run_id, period_id, scenario_key, scenario_mode, scenario_name, from_date, to_date, variant, variant_name, variant_values = run
        values = dict(DEFAULTS)
        values["InpScenarioMode"] = str(scenario_mode)
        values["InpMagicNumber"] = str(202607111200 + index)
        values["InpLogFolder"] = f"fx_session_reversal_m5_micro_n_{run_id}"
        values.update(variant_values)
        preset_name = f"{EA_NAME}_micro_n_{run_id}.set"
        ini_name = f"{EA_NAME}_micro_n_{run_id}.ini"
        preset_text = "\n".join(f"{key}={value}" for key, value in values.items()) + "\n"
        ini_text = tester_ini(run, preset_name)
        (PRESETS / preset_name).write_text(preset_text, encoding="utf-8")
        (BACKTEST / ini_name).write_text(ini_text, encoding="utf-8")
        run_dir = RUN_ROOT / run_id
        run_dir.mkdir(parents=True, exist_ok=True)
        (run_dir / "preset.set").write_text(preset_text, encoding="utf-8")
        (run_dir / "tester.ini").write_text(ini_text, encoding="utf-8")
        row = {
            "run_id": run_id, "period_id": period_id, "scenario_key": scenario_key,
            "scenario_mode": scenario_mode, "scenario_name": scenario_name,
            "from_date": from_date, "to_date": to_date, "variant": variant,
            "variant_name": variant_name, "preset": f"reports/presets/{preset_name}",
            "tester_ini": f"reports/backtest/{ini_name}", "log_folder": values["InpLogFolder"],
        }
        for key in [
            "InpTopContextTF", "InpStructureTF", "InpPrimaryEntryTF", "InpM15WaveContextMode",
            "InpUseM15SwingAnchorBias", "InpM15SwingAnchorMode", "InpUseTruePostAnchorBreakPullback",
            "InpPostAnchorPullbackMode", "InpPostAnchorRequireM5Reconfirm", "InpUseM5PostAnchorRelaunch",
            "InpM5PostAnchorRelaunchMode", "InpM5MicroAnchorLookbackBars",
            "InpM5MicroAnchorMinSwingStrength", "InpM5RelaunchBreakUseClose",
            "InpM5RelaunchBreakMinAtr", "InpM5RelaunchMaxBarsAfterRetest",
            "InpM5RelaunchFirstSignalMaxAgeBars", "InpM5RequireNewMicroAnchorAfterM15Break",
            "InpM5RelaunchRequireNormalBreakQuality", "InpM15AnchorFlipRequireHighMediumM5Pattern",
            "InpM15AnchorFlipRequireCorrectiveExhaustion", "InpExitMode", "InpMaxHoldBars",
        ]:
            row[key] = values[key]
        rows.append(row)
    write_matrix(rows)
    print(f"Wrote {len(rows)} runs to {MATRIX}")


if __name__ == "__main__":
    main()
