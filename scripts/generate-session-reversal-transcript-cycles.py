import csv
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
EA_NAME = "ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader"
BACKTEST = REPO / "reports" / "backtest"
PRESETS = REPO / "reports" / "presets"
RUN_ROOT = BACKTEST / "runs" / "20260702_session_reversal_transcript_nested_thirdwave"
MATRIX = RUN_ROOT / "run_matrix.csv"


CYCLES = [
    {
        "run_id": "c1_jan_counter_m15break_sma",
        "period_id": "jan_search",
        "from_date": "2025.01.01",
        "to_date": "2025.01.31",
        "note": "H1 counter-adjustment, M15 confirmed swing break, M5 first pullback, 75SMA hard context.",
        "InpTranscriptContextMode": 1,
        "InpTranscriptRequireStructureBreak": "true",
        "InpTranscriptRequireSmaReclaim": "true",
        "InpTranscriptRequirePriorImpulse": "false",
        "InpTranscriptUsePrimaryFailureExit": "false",
        "InpRetestToleranceATR": "0.28",
        "InpBreakBufferATR": "0.08",
        "InpTargetRewardMultiple": "1.40",
        "InpMaxHoldBars": "30",
    },
    {
        "run_id": "c2_jan_counter_m15break_no_sma_gate",
        "period_id": "jan_search",
        "from_date": "2025.01.01",
        "to_date": "2025.01.31",
        "note": "Same as c1, but 75SMA is diagnostic only to check whether it throttles good entries.",
        "InpTranscriptContextMode": 1,
        "InpTranscriptRequireStructureBreak": "true",
        "InpTranscriptRequireSmaReclaim": "false",
        "InpTranscriptRequirePriorImpulse": "false",
        "InpTranscriptUsePrimaryFailureExit": "false",
        "InpRetestToleranceATR": "0.28",
        "InpBreakBufferATR": "0.08",
        "InpTargetRewardMultiple": "1.40",
        "InpMaxHoldBars": "30",
    },
    {
        "run_id": "c3_jan_notopposite_m15break_sma",
        "period_id": "jan_search",
        "from_date": "2025.01.01",
        "to_date": "2025.01.31",
        "note": "Allow H1 continuation/range as long as H1 is not clearly opposite entry direction.",
        "InpTranscriptContextMode": 2,
        "InpTranscriptRequireStructureBreak": "true",
        "InpTranscriptRequireSmaReclaim": "true",
        "InpTranscriptRequirePriorImpulse": "false",
        "InpTranscriptUsePrimaryFailureExit": "false",
        "InpRetestToleranceATR": "0.28",
        "InpBreakBufferATR": "0.08",
        "InpTargetRewardMultiple": "1.40",
        "InpMaxHoldBars": "30",
    },
    {
        "run_id": "c4_jan_counter_sma_m5_failure_exit",
        "period_id": "jan_search",
        "from_date": "2025.01.01",
        "to_date": "2025.01.31",
        "note": "c1 plus M5 structure/neckline/MA failure exit, matching 'exit when the lower wave breaks'.",
        "InpTranscriptContextMode": 1,
        "InpTranscriptRequireStructureBreak": "true",
        "InpTranscriptRequireSmaReclaim": "true",
        "InpTranscriptRequirePriorImpulse": "false",
        "InpTranscriptUsePrimaryFailureExit": "true",
        "InpRetestToleranceATR": "0.28",
        "InpBreakBufferATR": "0.08",
        "InpTargetRewardMultiple": "1.40",
        "InpMaxHoldBars": "30",
    },
    {
        "run_id": "c5_jan_counter_sma_failure_exit_relaxed_retest",
        "period_id": "jan_search",
        "from_date": "2025.01.01",
        "to_date": "2025.01.31",
        "note": "c4 with wider retest tolerance and slightly smaller target to test acceptance without fine fitting.",
        "InpTranscriptContextMode": 1,
        "InpTranscriptRequireStructureBreak": "true",
        "InpTranscriptRequireSmaReclaim": "true",
        "InpTranscriptRequirePriorImpulse": "false",
        "InpTranscriptUsePrimaryFailureExit": "true",
        "InpRetestToleranceATR": "0.35",
        "InpBreakBufferATR": "0.05",
        "InpTargetRewardMultiple": "1.30",
        "InpMaxHoldBars": "30",
    },
    {
        "run_id": "c6_jan_counter_m15break_diagnostic_sma",
        "period_id": "jan_search",
        "from_date": "2025.01.01",
        "to_date": "2025.01.31",
        "note": "M15 break is diagnostic only; keeps H1 counter-adjustment and 75SMA context.",
        "InpTranscriptContextMode": 1,
        "InpTranscriptRequireStructureBreak": "false",
        "InpTranscriptRequireSmaReclaim": "true",
        "InpTranscriptRequirePriorImpulse": "false",
        "InpTranscriptUsePrimaryFailureExit": "false",
        "InpRetestToleranceATR": "0.28",
        "InpBreakBufferATR": "0.08",
        "InpTargetRewardMultiple": "1.40",
        "InpMaxHoldBars": "30",
    },
    {
        "run_id": "c7_jan_counter_m15break_diagnostic_no_sma_gate",
        "period_id": "jan_search",
        "from_date": "2025.01.01",
        "to_date": "2025.01.31",
        "note": "M15 break and 75SMA are diagnostic only; checks whether H1 counter context alone restores trade count.",
        "InpTranscriptContextMode": 1,
        "InpTranscriptRequireStructureBreak": "false",
        "InpTranscriptRequireSmaReclaim": "false",
        "InpTranscriptRequirePriorImpulse": "false",
        "InpTranscriptUsePrimaryFailureExit": "false",
        "InpRetestToleranceATR": "0.28",
        "InpBreakBufferATR": "0.08",
        "InpTargetRewardMultiple": "1.40",
        "InpMaxHoldBars": "30",
    },
    {
        "run_id": "c8_jan_notopposite_m15break_diagnostic_sma",
        "period_id": "jan_search",
        "from_date": "2025.01.01",
        "to_date": "2025.01.31",
        "note": "H1 not-opposite context, M15 break diagnostic only, 75SMA hard context.",
        "InpTranscriptContextMode": 2,
        "InpTranscriptRequireStructureBreak": "false",
        "InpTranscriptRequireSmaReclaim": "true",
        "InpTranscriptRequirePriorImpulse": "false",
        "InpTranscriptUsePrimaryFailureExit": "false",
        "InpRetestToleranceATR": "0.28",
        "InpBreakBufferATR": "0.08",
        "InpTargetRewardMultiple": "1.40",
        "InpMaxHoldBars": "30",
    },
    {
        "run_id": "c9_jan_counter_diag_sma_m5_failure_exit",
        "period_id": "jan_search",
        "from_date": "2025.01.01",
        "to_date": "2025.01.31",
        "note": "c6 plus lower-timeframe failure exit.",
        "InpTranscriptContextMode": 1,
        "InpTranscriptRequireStructureBreak": "false",
        "InpTranscriptRequireSmaReclaim": "true",
        "InpTranscriptRequirePriorImpulse": "false",
        "InpTranscriptUsePrimaryFailureExit": "true",
        "InpRetestToleranceATR": "0.28",
        "InpBreakBufferATR": "0.08",
        "InpTargetRewardMultiple": "1.40",
        "InpMaxHoldBars": "30",
    },
    {
        "run_id": "c10_jan_counter_diag_sma_failure_exit_relaxed_retest",
        "period_id": "jan_search",
        "from_date": "2025.01.01",
        "to_date": "2025.01.31",
        "note": "c9 with wider retest tolerance and 1.3R target.",
        "InpTranscriptContextMode": 1,
        "InpTranscriptRequireStructureBreak": "false",
        "InpTranscriptRequireSmaReclaim": "true",
        "InpTranscriptRequirePriorImpulse": "false",
        "InpTranscriptUsePrimaryFailureExit": "true",
        "InpRetestToleranceATR": "0.35",
        "InpBreakBufferATR": "0.05",
        "InpTargetRewardMultiple": "1.30",
        "InpMaxHoldBars": "30",
    },
]


def base_inputs(run, magic):
    values = {
        "InpSymbols": "USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD",
        "InpScenarioMode": "0",
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
        "InpTargetRewardMultiple": run["InpTargetRewardMultiple"],
        "InpUseSoftObstacleAsHardFilter": "false",
        "InpRoundNumberStepPips": "50.0",
        "InpEqualLevelTolerancePips": "6.0",
        "InpEqualLevelToleranceATR": "0.12",
        "InpRetestToleranceATR": run["InpRetestToleranceATR"],
        "InpRequireRetestCloseBeyondNeckline": "true",
        "InpBreakBufferATR": run["InpBreakBufferATR"],
        "InpStopBufferATR": "0.18",
        "InpMinSL_ATR": "0.35",
        "InpMaxSL_ATR": "3.00",
        "InpTranscriptContextMode": str(run["InpTranscriptContextMode"]),
        "InpTranscriptSmaPeriod": "75",
        "InpTranscriptStructureBreakMaxBars": "24",
        "InpTranscriptPrimaryBreakMaxBars": "8",
        "InpTranscriptRequireStructureBreak": run["InpTranscriptRequireStructureBreak"],
        "InpTranscriptRequireSmaReclaim": run["InpTranscriptRequireSmaReclaim"],
        "InpTranscriptRequirePriorImpulse": run["InpTranscriptRequirePriorImpulse"],
        "InpTranscriptPriorImpulseMinPivots": "5",
        "InpTranscriptUsePrimaryFailureExit": run["InpTranscriptUsePrimaryFailureExit"],
        "InpTranscriptExitLookbackBars": "10",
        "InpSessionInvalidationATR": "0.85",
        "InpMaxHoldBars": run["InpMaxHoldBars"],
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
        "InpLogFolder": f"fx_session_reversal_transcript_{run['run_id']}",
        "InpLogPrefix": "fxsessionrev",
    }
    return values


def preset_text(run, magic):
    values = base_inputs(run, magic)
    return "\n".join(f"{key}={value}" for key, value in values.items()) + "\n"


def tester_ini_text(run, preset_name):
    report_path = f"MQL5\\Experts\\dev\\reports\\backtest\\{EA_NAME}_{run['run_id']}_report.html"
    preset_path = f"reports\\presets\\{preset_name}"
    return "\n".join([
        "; Transcript-style H1/M15/M5 nested third-wave diagnostic.",
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


def main():
    BACKTEST.mkdir(parents=True, exist_ok=True)
    PRESETS.mkdir(parents=True, exist_ok=True)
    RUN_ROOT.mkdir(parents=True, exist_ok=True)
    rows = []
    for index, run in enumerate(CYCLES, start=1):
        preset_name = f"{EA_NAME}_{run['run_id']}.set"
        ini_name = f"{EA_NAME}_{run['run_id']}.ini"
        magic = 202607020100 + index
        (PRESETS / preset_name).write_text(preset_text(run, magic), encoding="utf-8")
        (BACKTEST / ini_name).write_text(tester_ini_text(run, preset_name), encoding="utf-8")
        run_dir = RUN_ROOT / run["run_id"]
        run_dir.mkdir(parents=True, exist_ok=True)
        (run_dir / "preset.set").write_text(preset_text(run, magic), encoding="utf-8")
        (run_dir / "tester.ini").write_text(tester_ini_text(run, preset_name), encoding="utf-8")
        rows.append({
            "run_id": run["run_id"],
            "period_id": run["period_id"],
            "from_date": run["from_date"],
            "to_date": run["to_date"],
            "preset": f"reports/presets/{preset_name}",
            "tester_ini": f"reports/backtest/{ini_name}",
            "log_folder": f"fx_session_reversal_transcript_{run['run_id']}",
            "note": run["note"],
            **{k: v for k, v in run.items() if k.startswith("Inp")},
        })

    with MATRIX.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    print(f"Wrote {len(rows)} transcript cycle runs to {MATRIX}")


if __name__ == "__main__":
    main()
