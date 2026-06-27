import csv
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
EA_NAME = "ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader"
BACKTEST = REPO / "reports" / "backtest"
PRESETS = REPO / "reports" / "presets"
MATRIX = BACKTEST / f"{EA_NAME}_prefilter_score_run_matrix_2025.csv"


SCENARIOS = [
    ("all_symbols_first120", "all_first120", "session_reversal_pullback_all_symbols_first120", 0),
    ("one_symbol_first120", "one_first120", "session_reversal_pullback_one_symbol_first120", 1),
    ("clean_target_path_first120", "clean_first120", "session_reversal_pullback_clean_target_path_first120", 3),
    ("london_first120", "london_first120", "london_first120_reference", 6),
    ("tokyo_first120", "tokyo_first120", "tokyo_first120_reference", 5),
    ("newyork_first120", "newyork_first120", "newyork_first120_reference", 7),
]

EXPERIMENTS = [
    ("baseline_current", "baseline", 0, "current_post_filter", False),
    ("prefilter_h1_h4_notopp", "h1_h4_notopp", 1, "h1_direction_h4_not_opposite_pre_filter", True),
    ("prefilter_h4_bias_h1_reversal", "h4_bias_h1_rev", 2, "h4_bias_h1_reversal_pre_filter", True),
    ("prefilter_soft", "soft", 3, "soft_pre_filter", True),
]

BREAK_EVEN = [
    ("no_be", "no_break_even", 0),
    ("be_1_1r", "break_even_at_1_1r", 2),
]


def preset_text(run, magic):
    return "\n".join([
        "InpSymbols=USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD",
        f"InpScenarioMode={run['scenario_mode']}",
        "InpScanTF=15",
        "InpDiagnosticTF=5",
        "InpBrokerUtcOffsetHours=3",
        "InpATRPeriod=14",
        "InpMAPeriodFast=10",
        "InpMAPeriodSlow=30",
        "InpStructureLookbackBars=16",
        "InpPatternLookbackBars=36",
        "InpSwingDepth=3",
        "InpHTFLookbackBars=80",
        "InpHTFWaveLookbackBars=120",
        "InpHTFWaveBreakBufferATR=0.05",
        "InpRequireH4H1Wave3Alignment=true",
        "InpHTFAlignmentMode=0",
        f"InpHTFPermissionMode={run['htf_permission_value']}",
        f"InpFilterOrderableBeforeSessionSelection={'true' if run['filter_orderable_before_session_selection'] else 'false'}",
        "InpUseM5LowerTimeframeWave3=true",
        f"InpBreakEvenMode={run['break_even_value']}",
        "InpBreakEvenOffsetPoints=0.0",
        "InpOpeningRangeMinutes=30",
        "InpPreSessionMinutes=60",
        "InpTargetRewardMultiple=1.50",
        "InpUseSoftObstacleAsHardFilter=false",
        "InpRoundNumberStepPips=50.0",
        "InpEqualLevelTolerancePips=6.0",
        "InpEqualLevelToleranceATR=0.12",
        "InpRetestToleranceATR=0.28",
        "InpBreakBufferATR=0.08",
        "InpStopBufferATR=0.18",
        "InpMinSL_ATR=0.35",
        "InpMaxSL_ATR=3.00",
        "InpSessionInvalidationATR=0.85",
        "InpMaxHoldBars=24",
        "InpRiskPerTradePercent=0.25",
        "InpMaxTotalOpenRiskPercent=2.50",
        "InpMaxRiskPerSymbolPercent=0.50",
        "InpMaxPositions=6",
        "InpDailyMaxLossPercent=3.00",
        "InpMaxDrawdownPercent=15.00",
        "InpMaxSpreadATR=0.20",
        "InpFixedLotFallback=0.01",
        "InpMaxLotCap=1.00",
        "InpSlippagePoints=20",
        f"InpMagicNumber={magic}",
        "InpUseCommonFiles=true",
        f"InpLogFolder=fx_session_reversal_prefilter_{run['run_id']}_2025",
        "InpLogPrefix=fxsessionrev",
        "",
    ])


def tester_ini_text(run):
    preset_path = f"reports\\presets\\{EA_NAME}_{run['run_id']}_2025.set"
    report_path = f"MQL5\\Experts\\dev\\reports\\backtest\\{EA_NAME}_{run['run_id']}_2025_report.html"
    return "\n".join([
        "; 2025 shallow diagnostic for FX session reversal HTF pre-filter and score components.",
        "",
        "[Experts]",
        "Enabled=1",
        "AllowLiveTrading=1",
        "AllowDllImport=0",
        "Account=0",
        "Profile=0",
        "",
        "[Tester]",
        "Expert=dev\\mql\\Experts\\ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader.ex5",
        f"PresetSource={preset_path}",
        f"PresetName={EA_NAME}_{run['run_id']}_2025.set",
        "Symbol=USDJPY",
        "Period=M15",
        "Model=4",
        "ExecutionMode=0",
        "Optimization=0",
        "OptimizationCriterion=6",
        "FromDate=2025.01.01",
        "ToDate=2025.12.31",
        "ForwardMode=0",
        "Deposit=10000",
        "Currency=USD",
        "Leverage=1:100",
        "UseLocal=1",
        "UseRemote=0",
        "UseCloud=0",
        "Visual=0",
        "ReplaceReport=1",
        "ShutdownTerminal=1",
        f"Report={report_path}",
        "",
    ])


def build_runs():
    runs = []
    for scenario_id, scenario_short, scenario_name, scenario_mode in SCENARIOS:
        for experiment_id, experiment_short, permission_value, permission_name, filter_orderable in EXPERIMENTS:
            for break_even_id, break_even_mode, break_even_value in BREAK_EVEN:
                run_id = f"{scenario_short}__{experiment_short}__{break_even_id}"
                runs.append({
                    "run_id": run_id,
                    "scenario_id": scenario_id,
                    "scenario_name": scenario_name,
                    "scenario_mode": scenario_mode,
                    "experiment_id": experiment_id,
                    "htf_permission_id": experiment_short,
                    "htf_permission_mode": permission_name,
                    "htf_permission_value": permission_value,
                    "htf_alignment_mode": "strict_h4_h1_alignment",
                    "htf_alignment_value": 0,
                    "break_even_id": break_even_id,
                    "break_even_mode": break_even_mode,
                    "break_even_value": break_even_value,
                    "filter_orderable_before_session_selection": filter_orderable,
                    "diagnostic_only": scenario_id in {"london_first120", "tokyo_first120", "newyork_first120"},
                    "preset": f"reports/presets/{EA_NAME}_{run_id}_2025.set",
                    "tester_ini": f"reports/backtest/{EA_NAME}_{run_id}_2025.ini",
                })
    runs.append({
        "run_id": "london_first120__london_focused_diagnostic__be_1_1r",
        "scenario_id": "london_first120",
        "scenario_name": "london_first120_reference",
        "scenario_mode": 6,
        "experiment_id": "london_focused_diagnostic",
        "htf_permission_id": "h1_h4_notopp",
        "htf_permission_mode": "h1_direction_h4_not_opposite_pre_filter",
        "htf_permission_value": 1,
        "htf_alignment_mode": "strict_h4_h1_alignment",
        "htf_alignment_value": 0,
        "break_even_id": "be_1_1r",
        "break_even_mode": "break_even_at_1_1r",
        "break_even_value": 2,
        "filter_orderable_before_session_selection": True,
        "diagnostic_only": True,
        "preset": f"reports/presets/{EA_NAME}_london_first120__london_focused_diagnostic__be_1_1r_2025.set",
        "tester_ini": f"reports/backtest/{EA_NAME}_london_first120__london_focused_diagnostic__be_1_1r_2025.ini",
    })
    return runs


def main():
    BACKTEST.mkdir(parents=True, exist_ok=True)
    PRESETS.mkdir(parents=True, exist_ok=True)
    runs = build_runs()
    fieldnames = list(runs[0].keys())
    with MATRIX.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(runs)

    for index, run in enumerate(runs, start=1):
        magic = 202606270100 + index
        (PRESETS / f"{EA_NAME}_{run['run_id']}_2025.set").write_text(preset_text(run, magic), encoding="utf-8")
        (BACKTEST / f"{EA_NAME}_{run['run_id']}_2025.ini").write_text(tester_ini_text(run), encoding="utf-8")

    print(f"Wrote {len(runs)} runs to {MATRIX}")


if __name__ == "__main__":
    main()
