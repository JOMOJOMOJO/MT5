from __future__ import annotations

import argparse
import csv
import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[3]
COMMON_FILES_ROOT = Path(os.environ["APPDATA"]) / "MetaQuotes" / "Terminal" / "Common" / "Files"
SWEEP_ROOT = REPO_ROOT / "reports" / "backtest" / "sweeps" / "2026-04-21-usdjpy-htf-swing-continuation-zero-trade-diagnostics"
RESULTS_ROOT = SWEEP_ROOT / "results"
CONFIGS_ROOT = SWEEP_ROOT / "configs"
PRESETS_ROOT = SWEEP_ROOT / "presets"
REPORTS_ROOT = SWEEP_ROOT / "reports"
BASE_PRESET = REPO_ROOT / "reports" / "presets" / "usdjpy_20260421_higher_timeframe_swing_continuation_engine-tierA.set"
EXPERT_PATH = "dev\\mql\\Experts\\usdjpy_20260421_higher_timeframe_swing_continuation_engine.ex5"
TERMINAL_PATH = Path(r"C:\Program Files\XMTrading MT5\terminal64.exe")
BACKTEST_SCRIPT = REPO_ROOT / "scripts" / "backtest.ps1"
REPORT_TOOL_PATH = REPO_ROOT / "plugins" / "mt5-company" / "scripts" / "mt5_backtest_tools.py"

WINDOW = ("2024.11.26", "2026.04.01")

STAGE_KEYS = [
    "context_valid_count",
    "tierA_long_eligible_count",
    "tierB_long_eligible_count",
    "tierA_short_eligible_count",
    "tierB_short_eligible_count",
    "fib_filter_pass_count",
    "pullback_structure_built_count",
    "higher_low_formed_count",
    "lower_high_formed_count",
    "reclaim_confirmed_count",
    "setup_valid_count",
    "trigger_fired_count",
    "order_sent_count",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run single-slice HTF swing continuation diagnostics.")
    parser.add_argument("--tier-mode", choices=("a_only", "a_and_b"), default="a_only")
    parser.add_argument("--trade-bias", choices=("both", "long_only", "short_only"), default="both")
    return parser.parse_args()


def load_report_tool() -> Any:
    spec = importlib.util.spec_from_file_location("mt5_backtest_tools", REPORT_TOOL_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Failed to load report tool: {REPORT_TOOL_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


REPORT_TOOL = load_report_tool()


def ensure_dirs() -> None:
    for path in (SWEEP_ROOT, RESULTS_ROOT, CONFIGS_ROOT, PRESETS_ROOT, REPORTS_ROOT):
        path.mkdir(parents=True, exist_ok=True)


def read_preset_lines(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";") or line.startswith("#") or "=" not in line:
            continue
        key, raw_value = line.split("=", 1)
        values[key.strip()] = raw_value.strip()
    return values


def format_preset_value(raw_value: str, new_value: Any) -> str:
    replacement = str(new_value).lower() if isinstance(new_value, bool) else str(new_value)
    if "||" not in raw_value:
        return replacement
    parts = raw_value.split("||")
    parts[0] = replacement
    if len(parts) > 1:
        parts[1] = replacement
    return "||".join(parts)


def write_preset(
    target_path: Path,
    telemetry_name: str,
    magic_number: int,
    tier_mode_value: int,
    trade_bias_value: int,
) -> None:
    overrides = {
        "InpContextTimeframe": 30,
        "InpPatternTimeframe": 15,
        "InpExecutionTimeframe": 5,
        "InpTierMode": tier_mode_value,
        "InpTradeBiasMode": trade_bias_value,
        "InpExecutionTriggerMode": 0,
        "InpSessionStartHour": 0,
        "InpSessionEndHour": 0,
        "InpMaxManagedPositions": 2,
        "InpReentryCooldownBars": 3,
        "InpAllowSameDirectionReentry": True,
        "InpMaxTotalRiskPercent": 1.0,
        "InpFibEntryMinRatio": 0.382,
        "InpFibEntryMaxRatio": 0.618,
        "InpTelemetryFileName": telemetry_name,
        "InpMagicNumber": magic_number,
    }
    base_values = read_preset_lines(BASE_PRESET)
    pending = dict(overrides)
    lines = [f"; auto-generated from {BASE_PRESET.name}"]
    for key, raw_value in base_values.items():
        if key in pending:
            lines.append(f"{key}={format_preset_value(raw_value, pending[key])}")
            pending.pop(key, None)
        else:
            lines.append(f"{key}={raw_value}")
    for key, value in pending.items():
        lines.append(f"{key}={value}")
    target_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_config(config_path: Path, preset_path: Path, report_path: Path) -> None:
    from_date, to_date = WINDOW
    relative_preset = preset_path.relative_to(REPO_ROOT).as_posix().replace("/", "\\")
    relative_report = report_path.relative_to(REPO_ROOT).as_posix().replace("/", "\\")
    config_lines = [
        "; auto-generated htf swing continuation zero-trade diagnostics config",
        "",
        "[Tester]",
        f"Expert={EXPERT_PATH}",
        f"PresetSource={relative_preset}",
        f"PresetName={preset_path.name}",
        "Symbol=USDJPY",
        "Period=M5",
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
        f"Report=MQL5\\Experts\\dev\\{relative_report}",
    ]
    config_path.write_text("\n".join(config_lines) + "\n", encoding="utf-8")


def parse_report_metrics(report_path: Path) -> dict[str, Any]:
    fields, records, _, _ = REPORT_TOOL.parse_report(report_path)
    metrics = REPORT_TOOL.build_metrics(fields, records)
    return {
        "net_profit": float(metrics.get("total_net_profit", 0.0)),
        "profit_factor": float(metrics.get("profit_factor", 0.0)),
        "trades": int(metrics.get("total_trades", 0) or 0),
        "expected_payoff": float(metrics.get("expected_payoff", 0.0)),
        "win_rate": float(metrics.get("win_rate_percent", 0.0)),
        "average_win": float(metrics.get("average_profit_trade", 0.0)),
        "average_loss": float(metrics.get("average_loss_trade", 0.0)),
        "max_drawdown_percent": max(
            float(metrics.get("maximal_drawdown_percent", 0.0) or 0.0),
            float(metrics.get("relative_drawdown_percent", 0.0) or 0.0),
        ),
    }


def read_telemetry_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    for encoding in ("utf-8-sig", "utf-8", "cp932", "cp1252"):
        try:
            with path.open("r", encoding=encoding, newline="") as handle:
                return list(csv.DictReader(handle, delimiter=";"))
        except UnicodeDecodeError:
            continue
    raise RuntimeError(f"Failed to decode telemetry: {path}")


def parse_int(value: str | None) -> int:
    if value in (None, ""):
        return 0
    return int(float(value))


def parse_bool(value: str | None) -> bool:
    if value is None:
        return False
    return value.strip().lower() in {"1", "true", "yes", "on"}


def extract_stage_counts(path: Path) -> dict[str, int]:
    if not path.exists():
        return {key: 0 for key in STAGE_KEYS}
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle, delimiter=";")
        for row in reader:
            return {key: parse_int(row.get(key)) for key in STAGE_KEYS}
    return {key: 0 for key in STAGE_KEYS}


def extract_trade_flags(rows: list[dict[str, str]]) -> dict[str, int]:
    entries = 0
    partial_time_stops = 0
    runner_before_time_stop = 0
    for row in rows:
        if row.get("event_type") == "entry":
            entries += 1
        if row.get("event_type") == "exit":
            if row.get("reason") == "time_stop" and parse_bool(row.get("partial_hit")):
                partial_time_stops += 1
            if parse_bool(row.get("runner_target_hit")) and row.get("reason") == "runner_target":
                runner_before_time_stop += 1
    return {
        "entries": entries,
        "partial_time_stops": partial_time_stops,
        "runner_before_time_stop": runner_before_time_stop,
    }


def identify_bottleneck(stage_counts: dict[str, int]) -> str:
    if stage_counts["context_valid_count"] == 0:
        return "context"

    eligible_total = (
        stage_counts["tierA_long_eligible_count"]
        + stage_counts["tierB_long_eligible_count"]
        + stage_counts["tierA_short_eligible_count"]
        + stage_counts["tierB_short_eligible_count"]
    )
    structure_confirmation_total = stage_counts["higher_low_formed_count"] + stage_counts["lower_high_formed_count"]

    stage_chain = [
        ("context_to_eligibility", stage_counts["context_valid_count"], eligible_total),
        ("eligibility_to_fib", eligible_total, stage_counts["fib_filter_pass_count"]),
        ("fib_to_structure_confirmation", stage_counts["fib_filter_pass_count"], structure_confirmation_total),
        ("structure_confirmation_to_reclaim", structure_confirmation_total, stage_counts["reclaim_confirmed_count"]),
        ("reclaim_to_setup", stage_counts["reclaim_confirmed_count"], stage_counts["setup_valid_count"]),
        ("setup_to_trigger", stage_counts["setup_valid_count"], stage_counts["trigger_fired_count"]),
        ("trigger_to_order", stage_counts["trigger_fired_count"], stage_counts["order_sent_count"]),
    ]

    lowest_ratio = 10.0
    bottleneck = "no_clear_bottleneck"
    for label, previous_count, next_count in stage_chain:
        if previous_count <= 0:
            break
        ratio = next_count / previous_count
        if ratio < lowest_ratio:
            lowest_ratio = ratio
            bottleneck = label
    return bottleneck


def render_summary(metrics: dict[str, Any], stage_counts: dict[str, int], trade_flags: dict[str, int], settings: dict[str, Any], bottleneck: str) -> str:
    settings_lines = "\n".join(f"- `{key} = {value}`" for key, value in settings.items())
    stage_lines = "\n".join(f"- `{key}`: {value}" for key, value in stage_counts.items())
    return "\n".join(
        [
            "# USDJPY Higher-Timeframe Swing Continuation Zero-Trade Diagnostics",
            "",
            "## Scope",
            "- Pair: `M30 context x M15 pattern x M5 execution`",
            "- Trigger: `EXEC_RECLAIM_CLOSE_CONFIRM`",
            "- Window: `actual` (`2024-11-26` to `2026-04-01`)",
            "",
            "## Settings",
            settings_lines,
            "",
            "## Backtest Metrics",
            f"- Trades: `{metrics['trades']}`",
            f"- Profit factor: `{metrics['profit_factor']:.2f}`",
            f"- Net profit: `{metrics['net_profit']:.2f}`",
            f"- Expected payoff: `{metrics['expected_payoff']:.2f}`",
            f"- Win rate: `{metrics['win_rate']:.2f}`",
            f"- Max drawdown %: `{metrics['max_drawdown_percent']:.2f}`",
            "",
            "## Stage Pass Counts",
            stage_lines,
            "",
            "## Trade Flags",
            f"- Entry rows: `{trade_flags['entries']}`",
            f"- Time stop after partial: `{trade_flags['partial_time_stops']}`",
            f"- Runner hit before time stop: `{trade_flags['runner_before_time_stop']}`",
            "",
            "## Bottleneck",
            f"- `{bottleneck}`",
            "",
        ]
    )


def main() -> None:
    args = parse_args()
    ensure_dirs()
    tier_mode_value = 0 if args.tier_mode == "a_only" else 1
    tier_mode_label = "ENTRY_TIER_A_ONLY" if args.tier_mode == "a_only" else "ENTRY_TIER_A_AND_B"
    trade_bias_value = {"short_only": 0, "long_only": 1, "both": 2}[args.trade_bias]
    trade_bias_label = {
        "short_only": "TRADE_BIAS_SHORT_ONLY",
        "long_only": "TRADE_BIAS_LONG_ONLY",
        "both": "TRADE_BIAS_BOTH",
    }[args.trade_bias]
    slug = f"actual-m30-m15-m5-reclaim-diagnostics-{args.tier_mode}-{args.trade_bias}"
    telemetry_name = f"mt5_company_{slug}.csv"
    stage_count_name = f"mt5_company_{slug}_stage_counts.csv"
    magic_number = 2026042190 + (0 if args.tier_mode == "a_only" else 10) + trade_bias_value

    preset_path = PRESETS_ROOT / f"{slug}.set"
    config_path = CONFIGS_ROOT / f"{slug}.ini"
    report_path = REPORTS_ROOT / f"{slug}.htm"
    telemetry_path = COMMON_FILES_ROOT / telemetry_name
    stage_count_path = COMMON_FILES_ROOT / stage_count_name
    summary_path = RESULTS_ROOT / f"summary-{args.tier_mode}-{args.trade_bias}.md"
    result_json_path = RESULTS_ROOT / f"result-{args.tier_mode}-{args.trade_bias}.json"

    settings = {
        "InpContextTimeframe": "M30",
        "InpPatternTimeframe": "M15",
        "InpExecutionTimeframe": "M5",
        "InpExecutionTriggerMode": "EXEC_RECLAIM_CLOSE_CONFIRM",
        "InpTradeBiasMode": trade_bias_label,
        "InpTierMode": tier_mode_label,
        "InpSessionStartHour": 0,
        "InpSessionEndHour": 0,
        "InpMaxManagedPositions": 2,
        "InpReentryCooldownBars": 3,
        "InpAllowSameDirectionReentry": True,
        "InpMaxTotalRiskPercent": 1.0,
        "TierA Fib": "0.382..0.618",
        "TierB Fib": "0.236..0.786",
    }

    write_preset(preset_path, telemetry_name, magic_number, tier_mode_value, trade_bias_value)
    write_config(config_path, preset_path, report_path)
    if telemetry_path.exists():
        telemetry_path.unlink()
    if stage_count_path.exists():
        stage_count_path.unlink()

    command = [
        "powershell",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(BACKTEST_SCRIPT),
        "-TerminalPath",
        str(TERMINAL_PATH),
        "-ConfigPath",
        str(config_path),
        "-TimeoutSeconds",
        "1200",
        "-RestartExisting",
    ]
    subprocess.run(command, cwd=str(REPO_ROOT), check=True, timeout=1320)

    metrics = parse_report_metrics(report_path)
    rows = read_telemetry_rows(telemetry_path)
    stage_counts = extract_stage_counts(stage_count_path)
    trade_flags = extract_trade_flags(rows)
    bottleneck = identify_bottleneck(stage_counts)

    result = {
        "settings": settings,
        "metrics": metrics,
        "stage_counts": stage_counts,
        "trade_flags": trade_flags,
        "bottleneck": bottleneck,
        "telemetry_rows": len(rows),
        "report_path": str(report_path.relative_to(REPO_ROOT)),
        "telemetry_path": str(telemetry_path),
        "stage_count_path": str(stage_count_path),
    }
    summary_path.write_text(render_summary(metrics, stage_counts, trade_flags, settings, bottleneck), encoding="utf-8")
    result_json_path.write_text(json.dumps(result, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
