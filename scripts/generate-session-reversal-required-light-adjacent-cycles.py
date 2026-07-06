import argparse
import csv
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
EA_NAME = "ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader"
BACKTEST = REPO / "reports" / "backtest"
PRESETS = REPO / "reports" / "presets"
RUN_ROOT = BACKTEST / "runs" / "20260707_session_reversal_required_light_adjacent_expansions"
MATRIX = RUN_ROOT / "run_matrix.csv"


DEFAULTS = {
    "InpSymbols": "USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD",
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
    "InpUseNestedThirdWaveLaunch": "false",
    "InpNestedThirdWaveMode": "0",
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
    "InpSessionGateMode": "0",
    "InpUseM5CorrectiveABC": "true",
    "InpM5CorrectiveMode": "1",
    "InpM5CorrectiveMinSwings": "3",
    "InpM5CorrectiveRequireTwoLegs": "true",
    "InpM5CorrectiveMaxAgeBars": "36",
    "InpM5CorrectiveMinPullbackAtr": "0.35",
    "InpM5CorrectiveMaxPullbackAtr": "3.0",
    "InpRequireM5InvalidationClose": "false",
    "InpM5InvalidationMinBodyAtr": "0.10",
    "InpM5InvalidationMinBreakAtr": "0.05",
    "InpUsePostBreakAcceptance": "false",
    "InpPostBreakMaxReturnAtr": "0.20",
    "InpRequireFirstRetestAfterInvalidation": "false",
    "InpFirstRetestMaxBars": "12",
    "InpM15WaveContextMode": "0",
    "InpM15Wave2MaxAgeBars": "24",
    "InpM15Wave2MinRetrace": "0.236",
    "InpM15Wave2PreferredMin": "0.382",
    "InpM15Wave2PreferredMax": "0.786",
    "InpM15Wave2ExpansionMode": "0",
    "InpM15Wave2GateMode": "0",
    "InpM15Wave2AdjacentMode": "0",
    "InpM15Wave2AdjacentFibSide": "0",
    "InpM15Wave2AdjacentAgeExtraBars": "4",
    "InpM15Wave2AdjacentCombineMask": "0",
    "InpExitMode": "1",
    "InpStructureTargetMode": "0",
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
    "InpUseCommonFiles": "true",
    "InpLogPrefix": "fxsessionrev",
}


BASE_VARIANTS = [
    ("base", "baseline_c10_reproduce", {"InpUseM5CorrectiveABC": "false", "InpM5CorrectiveMode": "0"}),
    ("light", "required_light_original_reproduce", {"InpM15WaveContextMode": "3", "InpUseM5CorrectiveABC": "true", "InpM5CorrectiveMode": "2"}),
    ("light_breakdown", "required_light_breakdown_only", {"InpM15WaveContextMode": "3", "InpUseM5CorrectiveABC": "true", "InpM5CorrectiveMode": "2"}),
    ("nearmiss_diag", "near_miss_diagnostic", {"InpM15Wave2ExpansionMode": "6", "InpM15Wave2GateMode": "5", "InpM15Wave2AdjacentMode": "9"}),
]


ADJACENT_VARIANTS = [
    ("relax_w1", "relax_wave1_age_only", {"InpM15Wave2AdjacentMode": "2"}),
    ("relax_w2", "relax_wave2_age_only", {"InpM15Wave2AdjacentMode": "3"}),
    ("fib_shallow", "relax_fib_neighbor_shallow_only", {"InpM15Wave2AdjacentMode": "4", "InpM15Wave2AdjacentFibSide": "1"}),
    ("fib_deep", "relax_fib_neighbor_deep_only", {"InpM15Wave2AdjacentMode": "4", "InpM15Wave2AdjacentFibSide": "2"}),
    ("breaktype", "allow_adjacent_break_type_only", {"InpM15Wave2AdjacentMode": "5"}),
    ("highq", "allow_high_quality_m5_near_miss_only", {"InpM15Wave2AdjacentMode": "6"}),
    ("context", "relax_context_fib_room_only", {
        "InpM15Wave2AdjacentMode": "7",
        "InpUseNestedThirdWaveLaunch": "true",
        "InpNestedThirdWaveMode": "1",
        "InpUseContextFibRoom": "true",
    }),
]


def adjacent_values(short, combine_mask):
    mapping = {short: values for short, _, values in ADJACENT_VARIANTS}
    if short == "combine":
        return {"InpM15Wave2AdjacentMode": "8", "InpM15Wave2AdjacentCombineMask": str(combine_mask)}
    return dict(mapping.get(short, {"InpM15Wave2AdjacentMode": "6"}))


def selected_variants(combine_mask, one_best):
    return [
        ("combine", "combine_best_two_adjacent", adjacent_values("combine", combine_mask)),
        ("one_light", "one_symbol_required_light_original", {
            "InpScenarioMode": "1",
            "InpM15WaveContextMode": "3",
            "InpUseM5CorrectiveABC": "true",
            "InpM5CorrectiveMode": "2",
        }),
        ("one_best", "one_symbol_best_adjacent", {"InpScenarioMode": "1", **adjacent_values(one_best, combine_mask)}),
        ("one_combine", "one_symbol_combine_best_two_adjacent", {
            "InpScenarioMode": "1",
            "InpM15Wave2AdjacentMode": "8",
            "InpM15Wave2AdjacentCombineMask": str(combine_mask),
        }),
    ]


def scenario_from_values(values):
    mode = int(values.get("InpScenarioMode", DEFAULTS.get("InpScenarioMode", "0")))
    names = {
        0: "session_reversal_pullback_all_symbols_first120",
        1: "session_reversal_pullback_one_symbol_first120",
        3: "session_reversal_pullback_clean_target_path_first120",
        5: "tokyo_first120_reference",
        6: "london_first120_reference",
        7: "newyork_first120_reference",
    }
    keys = {0: "all", 1: "one", 3: "clean", 5: "tky", 6: "ldn", 7: "ny"}
    return keys.get(mode, "all"), mode, names.get(mode, names[0])


def build_runs(phase, combine_mask, one_best):
    q1_variants = BASE_VARIANTS + ADJACENT_VARIANTS
    full_variants = BASE_VARIANTS + ADJACENT_VARIANTS + selected_variants(combine_mask, one_best)
    runs = []
    if phase in {"q1", "all"}:
        for short, name, values in q1_variants:
            scenario_key, mode, scenario_name = scenario_from_values(values)
            runs.append((f"q1_{short}", "q1_quick", scenario_key, mode, scenario_name, "2025.01.01", "2025.03.31", short, name, values))
    if phase in {"full", "all"}:
        for short, name, values in full_variants:
            scenario_key, mode, scenario_name = scenario_from_values(values)
            runs.append((f"full2025_{short}", "full2025_validation", scenario_key, mode, scenario_name, "2025.01.01", "2025.12.31", short, name, values))
    return runs


def inputs_for(run, magic):
    _, _, _, scenario_mode, _, _, _, _, _, variant_values = run
    values = dict(DEFAULTS)
    values["InpScenarioMode"] = str(scenario_mode)
    values["InpMagicNumber"] = str(magic)
    values["InpLogFolder"] = f"fx_session_reversal_req_light_adjacent_{run[0]}"
    values.update(variant_values)
    return values


def tester_ini(run, preset_name):
    run_id, _, _, _, _, from_date, to_date, _, _, _ = run
    report_path = f"MQL5\\Experts\\dev\\reports\\backtest\\{EA_NAME}_{run_id}_report.html"
    return "\n".join([
        "; Required-light M15 wave2 adjacent expansion validation.",
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
        f"PresetSource=reports\\presets\\{preset_name}",
        f"PresetName={preset_name}",
        "Symbol=USDJPY",
        "Period=M15",
        "Model=4",
        "ExecutionMode=0",
        "Optimization=0",
        "OptimizationCriterion=6",
        f"FromDate={from_date}",
        f"ToDate={to_date}",
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
    parser.add_argument("--combine-mask", type=int, default=17)
    parser.add_argument("--one-best", default="highq")
    args = parser.parse_args()

    BACKTEST.mkdir(parents=True, exist_ok=True)
    PRESETS.mkdir(parents=True, exist_ok=True)
    RUN_ROOT.mkdir(parents=True, exist_ok=True)

    rows = []
    for index, run in enumerate(build_runs(args.phase, args.combine_mask, args.one_best), start=1):
        run_id, period_id, scenario_key, scenario_mode, scenario_name, from_date, to_date, variant, variant_name, _ = run
        magic = 202607070700 + index
        preset_name = f"{EA_NAME}_{run_id}.set"
        ini_name = f"{EA_NAME}_{run_id}.ini"
        values = inputs_for(run, magic)
        preset_text = "\n".join(f"{key}={value}" for key, value in values.items()) + "\n"
        ini_text = tester_ini(run, preset_name)
        (PRESETS / preset_name).write_text(preset_text, encoding="utf-8")
        (BACKTEST / ini_name).write_text(ini_text, encoding="utf-8")
        run_dir = RUN_ROOT / run_id
        run_dir.mkdir(parents=True, exist_ok=True)
        (run_dir / "preset.set").write_text(preset_text, encoding="utf-8")
        (run_dir / "tester.ini").write_text(ini_text, encoding="utf-8")
        row = {
            "run_id": run_id,
            "period_id": period_id,
            "scenario_key": scenario_key,
            "scenario_mode": scenario_mode,
            "scenario_name": scenario_name,
            "from_date": from_date,
            "to_date": to_date,
            "variant": variant,
            "variant_name": variant_name,
            "preset": f"reports/presets/{preset_name}",
            "tester_ini": f"reports/backtest/{ini_name}",
            "log_folder": values["InpLogFolder"],
        }
        for key in [
            "InpTopContextTF", "InpStructureTF", "InpPrimaryEntryTF", "InpSessionGateMode",
            "InpUseM5CorrectiveABC", "InpM5CorrectiveMode", "InpM15WaveContextMode",
            "InpM15Wave2ExpansionMode", "InpM15Wave2GateMode", "InpM15Wave2AdjacentMode",
            "InpM15Wave2AdjacentFibSide", "InpM15Wave2AdjacentAgeExtraBars",
            "InpM15Wave2AdjacentCombineMask", "InpUseNestedThirdWaveLaunch",
            "InpNestedThirdWaveMode", "InpUseContextFibRoom", "InpExitMode", "InpMaxHoldBars",
        ]:
            row[key] = values[key]
        rows.append(row)

    write_matrix(rows)
    print(f"Wrote {len(rows)} runs to {MATRIX}")


if __name__ == "__main__":
    main()
