import csv
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
EA_NAME = "ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader"
BACKTEST = REPO / "reports" / "backtest"
PRESETS = REPO / "reports" / "presets"
RUN_ROOT = BACKTEST / "runs" / "20260702_session_reversal_nested_thirdwave_launch"
MATRIX = RUN_ROOT / "run_matrix.csv"


SCENARIOS = [
    ("all", 0, "session_reversal_pullback_all_symbols_first120"),
    ("one", 1, "session_reversal_pullback_one_symbol_first120"),
    ("ldn", 6, "london_first120_reference"),
    ("tky", 5, "tokyo_first120_reference"),
    ("ny", 7, "newyork_first120_reference"),
    ("clean", 3, "session_reversal_pullback_clean_target_path_first120"),
]


VARIANTS = [
    {
        "variant": "base",
        "note": "Previous c10 baseline: transcript context, relaxed retest, M5 failure exit.",
        "InpUseNestedThirdWaveLaunch": "false",
        "InpNestedThirdWaveMode": "0",
    },
    {
        "variant": "diag",
        "note": "Detect nested third-wave launch but do not use it for entry.",
        "InpUseNestedThirdWaveLaunch": "true",
        "InpNestedThirdWaveMode": "1",
    },
    {
        "variant": "score",
        "note": "Add nested structure score without required gates.",
        "InpUseNestedThirdWaveLaunch": "true",
        "InpNestedThirdWaveMode": "2",
        "InpUseSma75GranvilleScore": "true",
    },
    {
        "variant": "req_m5inv",
        "note": "Require M5 corrective wave and its invalidation; keep M15 diagnostics soft.",
        "InpUseNestedThirdWaveLaunch": "true",
        "InpNestedThirdWaveMode": "3",
        "InpRequireM5CorrectiveWave": "true",
        "InpRequireM5CorrectiveInvalidation": "true",
    },
    {
        "variant": "req_m15w2_m5inv",
        "note": "Require M15 wave2 candidate, M5 invalidation, and post-break acceptance.",
        "InpUseNestedThirdWaveLaunch": "true",
        "InpNestedThirdWaveMode": "3",
        "InpRequireM15Wave2Pullback": "true",
        "InpRequireM5CorrectiveWave": "true",
        "InpRequireM5CorrectiveInvalidation": "true",
        "InpRequirePostBreakAcceptance": "true",
    },
    {
        "variant": "score_fibroom",
        "note": "Score nested structure plus H1 context fib room.",
        "InpUseNestedThirdWaveLaunch": "true",
        "InpNestedThirdWaveMode": "2",
        "InpUseContextFibRoom": "true",
        "InpUseSma75GranvilleScore": "true",
    },
    {
        "variant": "req_fibroom",
        "note": "Restrictive fib-room diagnostic; not promotable if trade count dies.",
        "InpUseNestedThirdWaveLaunch": "true",
        "InpNestedThirdWaveMode": "3",
        "InpUseContextFibRoom": "true",
        "InpRequireContextFibRoom": "true",
        "InpUseM15Wave2FibZone": "true",
    },
]


DEFAULTS = {
    "InpRequireM15Wave1Candidate": "false",
    "InpRequireM15Wave2Pullback": "false",
    "InpRequireM5CorrectiveWave": "false",
    "InpRequireM5CorrectiveInvalidation": "false",
    "InpRequirePostBreakAcceptance": "false",
    "InpPostBreakAcceptanceBars": "1",
    "InpUseContextFibRoom": "false",
    "InpRequireContextFibRoom": "false",
    "InpUseM15Wave2FibZone": "false",
    "InpRequireM15Wave2FibZone": "false",
    "InpUseSma75GranvilleDiagnostic": "true",
    "InpUseSma75GranvilleScore": "false",
    "InpRequireSma75Granville": "false",
}


def base_inputs(run, magic):
    values = {
        "InpSymbols": "USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD",
        "InpScenarioMode": str(run["scenario_mode"]),
        "InpScanTF": "15",
        "InpDiagnosticTF": "5",
        "InpTopContextTF": "16385",
        "InpStructureTF": "15",
        "InpPrimaryEntryTF": "5",
        "InpSecondaryEntryTF": "5",
        "InpUseSecondaryEntryTF": "false",
        "InpRequireStructureTFConfirmation": "false",
        "InpUseTopTFAsOppositeFilterOnly": "false",
        "InpBrokerUtcOffsetHours": "3",
        "InpATRPeriod": "14",
        "InpMAPeriodFast": "10",
        "InpMAPeriodSlow": "30",
        "InpStructureLookbackBars": "16",
        "InpPatternLookbackBars": "36",
        "InpSwingDepth": "3",
        "InpHTFLookbackBars": "80",
        "InpHTFWaveLookbackBars": "120",
        "InpHTFWaveBreakBufferATR": "0.05",
        "InpUseOrderedDowFractalStructure": "true",
        "InpTopContextTrendOnly": "true",
        "InpAllowStructureTrendBiasWhenNoWave3": "true",
        "InpDowMinSwingATR": "0.35",
        "InpDowStructureToleranceATR": "0.10",
        "InpDowMinPivotsForTrend": "4",
        "InpRequireH4H1Wave3Alignment": "true",
        "InpHTFAlignmentMode": "3",
        "InpHTFPermissionMode": "0",
        "InpUseM5LowerTimeframeWave3": "true",
        "InpFilterOrderableBeforeSessionSelection": "false",
        "InpUseFibPullbackScore": "false",
        "InpRequireFibPullbackZone": "false",
        "InpFibPreferredMin": "0.382",
        "InpFibPreferredMax": "0.618",
        "InpFibDeepMax": "0.786",
        "InpBreakEvenMode": "0",
        "InpBreakEvenOffsetPoints": "0.0",
        "InpOpeningRangeMinutes": "30",
        "InpPreSessionMinutes": "60",
        "InpTargetRewardMultiple": "1.30",
        "InpUseSoftObstacleAsHardFilter": "false",
        "InpRoundNumberStepPips": "50.0",
        "InpEqualLevelTolerancePips": "6.0",
        "InpEqualLevelToleranceATR": "0.12",
        "InpRetestToleranceATR": "0.35",
        "InpRequireRetestCloseBeyondNeckline": "true",
        "InpBreakBufferATR": "0.05",
        "InpStopBufferATR": "0.18",
        "InpMinSL_ATR": "0.35",
        "InpMaxSL_ATR": "3.00",
        "InpTranscriptContextMode": "1",
        "InpTranscriptSmaPeriod": "75",
        "InpTranscriptStructureBreakMaxBars": "24",
        "InpTranscriptPrimaryBreakMaxBars": "8",
        "InpTranscriptRequireStructureBreak": "false",
        "InpTranscriptRequireSmaReclaim": "true",
        "InpTranscriptRequirePriorImpulse": "false",
        "InpTranscriptPriorImpulseMinPivots": "5",
        "InpTranscriptUsePrimaryFailureExit": "true",
        "InpTranscriptExitLookbackBars": "10",
        **DEFAULTS,
        "InpSessionInvalidationATR": "0.85",
        "InpMaxHoldBars": "30",
        "InpRiskPerTradePercent": "0.25",
        "InpMaxTotalOpenRiskPercent": "2.50",
        "InpMaxRiskPerSymbolPercent": "0.50",
        "InpMaxPositions": "6",
        "InpDailyMaxLossPercent": "3.00",
        "InpMaxDrawdownPercent": "15.00",
        "InpMaxSpreadATR": "0.20",
        "InpFixedLotFallback": "0.01",
        "InpMaxLotCap": "1.00",
        "InpSlippagePoints": "20",
        "InpMagicNumber": str(magic),
        "InpUseCommonFiles": "true",
        "InpLogFolder": f"fx_session_reversal_nested_launch_{run['run_id']}",
        "InpLogPrefix": "fxsessionrev",
    }
    for key, value in run["variant_inputs"].items():
        if key.startswith("Inp"):
            values[key] = value
    return values


def preset_text(run, magic):
    values = base_inputs(run, magic)
    return "\n".join(f"{key}={value}" for key, value in values.items()) + "\n"


def tester_ini_text(run, preset_name):
    report_path = f"MQL5\\Experts\\dev\\reports\\backtest\\{EA_NAME}_{run['run_id']}_report.html"
    preset_path = f"reports\\presets\\{preset_name}"
    return "\n".join([
        "; Nested third-wave launch and M5 corrective invalidation diagnostic.",
        "",
        "[Experts]",
        "Enabled=0",
        "AllowLiveTrading=0",
        "AllowDllImport=0",
        "Account=0",
        "Profile=0",
        "",
        "[Tester]",
        "Expert=dev\\mql\\Experts\\ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader.ex5",
        f"PresetSource={preset_path}",
        f"PresetName={preset_name}",
        "Symbol=USDJPY",
        "Period=M15",
        "Model=4",
        "ExecutionMode=0",
        "Optimization=0",
        "OptimizationCriterion=6",
        f"FromDate={run['from_date']}",
        f"ToDate={run['to_date']}",
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
    for idx, variant in enumerate(VARIANTS, start=1):
        runs.append({
            "run_id": f"q1_{variant['variant']}",
            "period_id": "q1_quick",
            "from_date": "2025.01.01",
            "to_date": "2025.03.31",
            "scenario_key": "all_symbols_first120",
            "scenario_mode": 0,
            "scenario_name": "session_reversal_pullback_all_symbols_first120",
            "variant": variant["variant"],
            "variant_inputs": variant,
            "note": variant["note"],
        })
    for scenario_key, scenario_mode, scenario_name in SCENARIOS:
        for variant in VARIANTS:
            runs.append({
                "run_id": f"full2025_{scenario_key}_{variant['variant']}",
                "period_id": "full2025_validation",
                "from_date": "2025.01.01",
                "to_date": "2025.12.31",
                "scenario_key": scenario_key,
                "scenario_mode": scenario_mode,
                "scenario_name": scenario_name,
                "variant": variant["variant"],
                "variant_inputs": variant,
                "note": variant["note"],
            })
    return runs


def main():
    BACKTEST.mkdir(parents=True, exist_ok=True)
    PRESETS.mkdir(parents=True, exist_ok=True)
    RUN_ROOT.mkdir(parents=True, exist_ok=True)
    rows = []
    for index, run in enumerate(build_runs(), start=1):
        preset_name = f"{EA_NAME}_{run['run_id']}.set"
        ini_name = f"{EA_NAME}_{run['run_id']}.ini"
        magic = 202607020300 + index
        text = preset_text(run, magic)
        ini_text = tester_ini_text(run, preset_name)
        (PRESETS / preset_name).write_text(text, encoding="utf-8")
        (BACKTEST / ini_name).write_text(ini_text, encoding="utf-8")
        run_dir = RUN_ROOT / run["run_id"]
        run_dir.mkdir(parents=True, exist_ok=True)
        (run_dir / "preset.set").write_text(text, encoding="utf-8")
        (run_dir / "tester.ini").write_text(ini_text, encoding="utf-8")
        row = {
            "run_id": run["run_id"],
            "period_id": run["period_id"],
            "variant": run["variant"],
            "scenario_key": run["scenario_key"],
            "scenario_mode": run["scenario_mode"],
            "scenario_name": run["scenario_name"],
            "from_date": run["from_date"],
            "to_date": run["to_date"],
            "preset": f"reports/presets/{preset_name}",
            "tester_ini": f"reports/backtest/{ini_name}",
            "log_folder": f"fx_session_reversal_nested_launch_{run['run_id']}",
            "note": run["note"],
        }
        for key, value in base_inputs(run, magic).items():
            if key.startswith("InpNested") or key.startswith("InpRequire") or key in {
                "InpUseNestedThirdWaveLaunch",
                "InpUseContextFibRoom",
                "InpUseM15Wave2FibZone",
                "InpUseSma75GranvilleDiagnostic",
                "InpUseSma75GranvilleScore",
                "InpTopContextTF",
                "InpStructureTF",
                "InpPrimaryEntryTF",
                "InpSecondaryEntryTF",
            }:
                row[key] = value
        rows.append(row)

    fieldnames = []
    for row in rows:
        for key in row:
            if key not in fieldnames:
                fieldnames.append(key)
    with MATRIX.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {len(rows)} nested launch runs to {MATRIX}")


if __name__ == "__main__":
    main()
