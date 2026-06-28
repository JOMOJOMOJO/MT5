import csv
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
EA_NAME = "ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader"
BACKTEST = REPO / "reports" / "backtest"
PRESETS = REPO / "reports" / "presets"
MATRIX = BACKTEST / f"{EA_NAME}_timeframe_matrix_run_matrix_2025.csv"


SCENARIOS = [
    ("london_first120_reference", "london_first120", 6, True),
    ("all_symbols_first120", "all_first120", 0, False),
    ("one_symbol_first120", "one_first120", 1, False),
    ("tokyo_first120_reference", "tokyo_first120", 5, True),
    ("newyork_first120_reference", "newyork_first120", 7, True),
    ("clean_target_path_first120", "clean_first120", 3, False),
]

TIMEFRAME_CONFIGS = [
    {
        "timeframe_config_id": "current_default",
        "short": "current",
        "top_context_tf": "PERIOD_H4",
        "top_context_tf_value": 240,
        "structure_tf": "PERIOD_H1",
        "structure_tf_value": 60,
        "primary_entry_tf": "PERIOD_M15",
        "primary_entry_tf_value": 15,
        "secondary_entry_tf": "PERIOD_M5",
        "secondary_entry_tf_value": 5,
        "use_secondary_entry_tf": True,
        "require_structure_tf_confirmation": True,
        "use_top_tf_as_opposite_filter_only": False,
        "htf_permission_mode": "strict_pre_filter",
        "htf_permission_value": 4,
        "use_fib_pullback_score": False,
        "require_fib_pullback_zone": False,
    },
    {
        "timeframe_config_id": "h1_m15_m5_strict",
        "short": "h1_m15_m5_strict",
        "top_context_tf": "PERIOD_H1",
        "top_context_tf_value": 60,
        "structure_tf": "PERIOD_M15",
        "structure_tf_value": 15,
        "primary_entry_tf": "PERIOD_M5",
        "primary_entry_tf_value": 5,
        "secondary_entry_tf": "PERIOD_M5",
        "secondary_entry_tf_value": 5,
        "use_secondary_entry_tf": False,
        "require_structure_tf_confirmation": True,
        "use_top_tf_as_opposite_filter_only": False,
        "htf_permission_mode": "strict_pre_filter",
        "htf_permission_value": 4,
        "use_fib_pullback_score": False,
        "require_fib_pullback_zone": False,
    },
    {
        "timeframe_config_id": "h1_m15_m5_dual_entry",
        "short": "h1_m15_m5_dual",
        "top_context_tf": "PERIOD_H1",
        "top_context_tf_value": 60,
        "structure_tf": "PERIOD_M15",
        "structure_tf_value": 15,
        "primary_entry_tf": "PERIOD_M15",
        "primary_entry_tf_value": 15,
        "secondary_entry_tf": "PERIOD_M5",
        "secondary_entry_tf_value": 5,
        "use_secondary_entry_tf": True,
        "require_structure_tf_confirmation": True,
        "use_top_tf_as_opposite_filter_only": False,
        "htf_permission_mode": "strict_pre_filter",
        "htf_permission_value": 4,
        "use_fib_pullback_score": False,
        "require_fib_pullback_zone": False,
    },
    {
        "timeframe_config_id": "h1_m15_m5_top_opposite_only",
        "short": "h1_m15_m5_top_notopp",
        "top_context_tf": "PERIOD_H1",
        "top_context_tf_value": 60,
        "structure_tf": "PERIOD_M15",
        "structure_tf_value": 15,
        "primary_entry_tf": "PERIOD_M5",
        "primary_entry_tf_value": 5,
        "secondary_entry_tf": "PERIOD_M5",
        "secondary_entry_tf_value": 5,
        "use_secondary_entry_tf": False,
        "require_structure_tf_confirmation": True,
        "use_top_tf_as_opposite_filter_only": True,
        "htf_permission_mode": "structure_confirmed_top_not_opposite_pre_filter",
        "htf_permission_value": 1,
        "use_fib_pullback_score": False,
        "require_fib_pullback_zone": False,
    },
    {
        "timeframe_config_id": "h1_m15_m5_with_fib_score",
        "short": "h1_m15_m5_fib_score",
        "top_context_tf": "PERIOD_H1",
        "top_context_tf_value": 60,
        "structure_tf": "PERIOD_M15",
        "structure_tf_value": 15,
        "primary_entry_tf": "PERIOD_M5",
        "primary_entry_tf_value": 5,
        "secondary_entry_tf": "PERIOD_M5",
        "secondary_entry_tf_value": 5,
        "use_secondary_entry_tf": False,
        "require_structure_tf_confirmation": True,
        "use_top_tf_as_opposite_filter_only": False,
        "htf_permission_mode": "strict_pre_filter",
        "htf_permission_value": 4,
        "use_fib_pullback_score": True,
        "require_fib_pullback_zone": False,
    },
    {
        "timeframe_config_id": "h1_m15_m5_with_fib_required",
        "short": "h1_m15_m5_fib_req",
        "top_context_tf": "PERIOD_H1",
        "top_context_tf_value": 60,
        "structure_tf": "PERIOD_M15",
        "structure_tf_value": 15,
        "primary_entry_tf": "PERIOD_M5",
        "primary_entry_tf_value": 5,
        "secondary_entry_tf": "PERIOD_M5",
        "secondary_entry_tf_value": 5,
        "use_secondary_entry_tf": False,
        "require_structure_tf_confirmation": True,
        "use_top_tf_as_opposite_filter_only": False,
        "htf_permission_mode": "strict_pre_filter",
        "htf_permission_value": 4,
        "use_fib_pullback_score": True,
        "require_fib_pullback_zone": True,
    },
]

BREAK_EVEN = [
    ("no_be", "no_break_even", 0),
    ("be_1_1r", "break_even_at_1_1r", 2),
]


def b(value):
    return "true" if value else "false"


def preset_text(run, magic):
    return "\n".join([
        "InpSymbols=USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD",
        f"InpScenarioMode={run['scenario_mode']}",
        f"InpScanTF={run['primary_entry_tf_value']}",
        f"InpDiagnosticTF={run['secondary_entry_tf_value']}",
        f"InpTopContextTF={run['top_context_tf_value']}",
        f"InpStructureTF={run['structure_tf_value']}",
        f"InpPrimaryEntryTF={run['primary_entry_tf_value']}",
        f"InpSecondaryEntryTF={run['secondary_entry_tf_value']}",
        f"InpUseSecondaryEntryTF={b(run['use_secondary_entry_tf'])}",
        f"InpRequireStructureTFConfirmation={b(run['require_structure_tf_confirmation'])}",
        f"InpUseTopTFAsOppositeFilterOnly={b(run['use_top_tf_as_opposite_filter_only'])}",
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
        "InpFilterOrderableBeforeSessionSelection=true",
        f"InpUseM5LowerTimeframeWave3={b(run['use_secondary_entry_tf'])}",
        f"InpUseFibPullbackScore={b(run['use_fib_pullback_score'])}",
        f"InpRequireFibPullbackZone={b(run['require_fib_pullback_zone'])}",
        "InpFibPreferredMin=0.382",
        "InpFibPreferredMax=0.618",
        "InpFibDeepMax=0.786",
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
        f"InpLogFolder=fx_session_reversal_timeframes_{run['run_id']}_2025",
        "InpLogPrefix=fxsessionrev",
        "",
    ])


def tester_ini_text(run):
    preset_path = f"reports\\presets\\{EA_NAME}_{run['run_id']}_2025.set"
    report_path = f"MQL5\\Experts\\dev\\reports\\backtest\\{EA_NAME}_{run['run_id']}_2025_report.html"
    return "\n".join([
        "; 2025 shallow diagnostic for FX session reversal fractal timeframe matrix.",
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
    for scenario_name, scenario_short, scenario_mode, diagnostic_only in SCENARIOS:
        for config in TIMEFRAME_CONFIGS:
            for break_even_id, break_even_mode, break_even_value in BREAK_EVEN:
                run_id = f"{scenario_short}__{config['short']}__{break_even_id}"
                row = {
                    **config,
                    "run_id": run_id,
                    "scenario_id": scenario_name,
                    "scenario_short": scenario_short,
                    "scenario_name": scenario_name,
                    "scenario_mode": scenario_mode,
                    "break_even_id": break_even_id,
                    "break_even_mode": break_even_mode,
                    "break_even_value": break_even_value,
                    "diagnostic_only": diagnostic_only,
                    "preset": f"reports/presets/{EA_NAME}_{run_id}_2025.set",
                    "tester_ini": f"reports/backtest/{EA_NAME}_{run_id}_2025.ini",
                }
                row.pop("short")
                runs.append(row)
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
        magic = 202606280100 + index
        (PRESETS / f"{EA_NAME}_{run['run_id']}_2025.set").write_text(preset_text(run, magic), encoding="utf-8")
        (BACKTEST / f"{EA_NAME}_{run['run_id']}_2025.ini").write_text(tester_ini_text(run), encoding="utf-8")

    print(f"Wrote {len(runs)} runs to {MATRIX}")


if __name__ == "__main__":
    main()
