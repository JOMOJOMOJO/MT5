from __future__ import annotations

import argparse
import csv
import importlib.util
import json
import math
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[3]
COMMON_FILES_ROOT = Path(os.environ["APPDATA"]) / "MetaQuotes" / "Terminal" / "Common" / "Files"
SWEEP_ROOT = REPO_ROOT / "reports" / "backtest" / "sweeps" / "2026-04-15-usdjpy-dow-hs-fixed-tp-diagnostic"
RESULTS_ROOT = SWEEP_ROOT / "results"
CONFIGS_ROOT = SWEEP_ROOT / "configs"
PRESETS_ROOT = SWEEP_ROOT / "presets"
REPORTS_ROOT = SWEEP_ROOT / "reports"
BASE_PRESET = REPO_ROOT / "reports" / "presets" / "usdjpy_20260414_dow_fractal_head_shoulders_engine-tierA.set"
EXPERT_PATH = "dev\\mql\\Experts\\usdjpy_20260414_dow_fractal_head_shoulders_engine.ex5"
TERMINAL_DEFAULT = Path(r"C:\Program Files\XMTrading MT5\terminal64.exe")
BACKTEST_SCRIPT = REPO_ROOT / "scripts" / "backtest.ps1"
REPORT_TOOL_PATH = REPO_ROOT / "plugins" / "mt5-company" / "scripts" / "mt5_backtest_tools.py"

WINDOWS = {
    "train": ("2025.04.01", "2025.12.31"),
    "oos": ("2026.01.01", "2026.04.01"),
    "actual": ("2024.11.26", "2026.04.01"),
}

PAIR_SPECS: list[tuple[str, int, int, int]] = [
    ("m30_m15_m3", 30, 15, 3),
    ("m15_m10_m5", 15, 10, 5),
]

TRIGGERS: list[tuple[str, int]] = [
    ("neck_close_confirm", 0),
    ("recent_swing_break", 2),
]

TP_GRID = [2.0, 3.0, 4.0, 5.0, 6.0, 8.0]
HOLD_GRID = [16, 24, 32]
TP_LEVEL_COLUMNS = [
    ("2", "did_hit_tp_2_pips"),
    ("3", "did_hit_tp_3_pips"),
    ("4", "did_hit_tp_4_pips"),
    ("5", "did_hit_tp_5_pips"),
    ("6", "did_hit_tp_6_pips"),
    ("8", "did_hit_tp_8_pips"),
]

TIMEFRAME_LABELS = {
    3: "M3",
    5: "M5",
    10: "M10",
    15: "M15",
    30: "M30",
}


def load_report_tool() -> Any:
    spec = importlib.util.spec_from_file_location("mt5_backtest_tools", REPORT_TOOL_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Failed to load report tool: {REPORT_TOOL_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


REPORT_TOOL = load_report_tool()


@dataclass
class PairSpec:
    key: str
    context_tf: int
    pattern_tf: int
    execution_tf: int


@dataclass
class RunSpec:
    slug: str
    pair_key: str
    pair_label: str
    window: str
    trigger_key: str
    trigger_mode: int
    context_tf: int
    pattern_tf: int
    execution_tf: int
    tp_pips: float
    hold_bars: int
    preset_path: Path
    config_path: Path
    report_path: Path
    telemetry_name: str
    telemetry_path: Path
    magic_number: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run fixed-TP diagnostics for the USDJPY Dow HS family.")
    parser.add_argument("--terminal-path", default=str(TERMINAL_DEFAULT))
    parser.add_argument("--timeout-seconds", type=int, default=1200)
    parser.add_argument("--reuse-existing", action="store_true")
    parser.add_argument("--include-second-trigger", action="store_true")
    parser.add_argument("--max-runs", type=int, default=0)
    return parser.parse_args()


def ensure_dirs() -> None:
    for path in (SWEEP_ROOT, RESULTS_ROOT, CONFIGS_ROOT, PRESETS_ROOT, REPORTS_ROOT):
        path.mkdir(parents=True, exist_ok=True)


def timeframe_label(value: int) -> str:
    return TIMEFRAME_LABELS.get(value, str(value))


def pair_label(context_tf: int, pattern_tf: int, execution_tf: int) -> str:
    return f"{timeframe_label(context_tf)} x {timeframe_label(pattern_tf)} x {timeframe_label(execution_tf)}"


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


def write_preset(base_preset: Path, overrides: dict[str, Any], target_path: Path) -> None:
    base_values = read_preset_lines(base_preset)
    pending = dict(overrides)
    lines = [f"; auto-generated from {base_preset.name}"]
    for key, raw_value in base_values.items():
        if key in pending:
            lines.append(f"{key}={format_preset_value(raw_value, pending[key])}")
            pending.pop(key, None)
        else:
            lines.append(f"{key}={raw_value}")
    for key, value in pending.items():
        lines.append(f"{key}={value}")
    target_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build_report_relative_path(slug: str) -> str:
    return (
        "MQL5\\Experts\\dev\\reports\\backtest\\sweeps\\"
        "2026-04-15-usdjpy-dow-hs-fixed-tp-diagnostic\\reports\\"
        f"{slug}.htm"
    )


def write_config(spec: RunSpec) -> None:
    from_date, to_date = WINDOWS[spec.window]
    relative_preset = spec.preset_path.relative_to(REPO_ROOT).as_posix().replace("/", "\\")
    config_lines = [
        "; auto-generated fixed tp diagnostic config",
        "",
        "[Tester]",
        f"Expert={EXPERT_PATH}",
        f"PresetSource={relative_preset}",
        f"PresetName={spec.preset_path.name}",
        "Symbol=USDJPY",
        f"Period={timeframe_label(spec.execution_tf)}",
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
        f"Report={build_report_relative_path(spec.slug)}",
    ]
    spec.config_path.write_text("\n".join(config_lines) + "\n", encoding="utf-8")


def format_tp_slug(tp_pips: float) -> str:
    if abs(tp_pips - round(tp_pips)) < 1e-9:
        return f"tp{int(round(tp_pips))}"
    return f"tp{str(tp_pips).replace('.', 'p')}"


def build_run_spec(
    pair: PairSpec,
    window: str,
    trigger_key: str,
    trigger_mode: int,
    tp_pips: float,
    hold_bars: int,
    ordinal: int,
) -> RunSpec:
    slug = f"{window}-{pair.key}-{trigger_key}-{format_tp_slug(tp_pips)}-h{hold_bars}"
    telemetry_name = f"mt5_company_{slug}.csv"
    return RunSpec(
        slug=slug,
        pair_key=pair.key,
        pair_label=pair_label(pair.context_tf, pair.pattern_tf, pair.execution_tf),
        window=window,
        trigger_key=trigger_key,
        trigger_mode=trigger_mode,
        context_tf=pair.context_tf,
        pattern_tf=pair.pattern_tf,
        execution_tf=pair.execution_tf,
        tp_pips=tp_pips,
        hold_bars=hold_bars,
        preset_path=PRESETS_ROOT / f"{slug}.set",
        config_path=CONFIGS_ROOT / f"{slug}.ini",
        report_path=REPORTS_ROOT / f"{slug}.htm",
        telemetry_name=telemetry_name,
        telemetry_path=COMMON_FILES_ROOT / telemetry_name,
        magic_number=2026047000 + ordinal,
    )


def generate_run_files(spec: RunSpec) -> None:
    overrides = {
        "InpContextTimeframe": spec.context_tf,
        "InpPatternTimeframe": spec.pattern_tf,
        "InpExecutionTimeframe": spec.execution_tf,
        "InpTierMode": 0,
        "InpTradeBiasMode": 0,
        "InpExecutionTriggerMode": spec.trigger_mode,
        "InpExitMode": 1,
        "InpDiagnosticFixedTPPips": spec.tp_pips,
        "InpSetupExpiryBars": 24,
        "InpMaxHoldBars": spec.hold_bars,
        "InpTelemetryFileName": spec.telemetry_name,
        "InpMagicNumber": spec.magic_number,
    }
    write_preset(BASE_PRESET, overrides, spec.preset_path)
    write_config(spec)


def run_backtest(spec: RunSpec, terminal_path: str, timeout_seconds: int, reuse_existing: bool) -> None:
    meta_path = spec.report_path.with_name(spec.report_path.name + ".meta.json")
    if reuse_existing and spec.report_path.exists() and meta_path.exists():
        return

    if spec.telemetry_path.exists():
        spec.telemetry_path.unlink()

    command = [
        "powershell",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(BACKTEST_SCRIPT),
        "-TerminalPath",
        terminal_path,
        "-ConfigPath",
        str(spec.config_path),
        "-TimeoutSeconds",
        str(timeout_seconds),
        "-RestartExisting",
    ]
    subprocess.run(command, cwd=str(REPO_ROOT), check=True, timeout=timeout_seconds + 120)


def parse_report_metrics(report_path: Path) -> dict[str, Any]:
    fields, records, _, report_kind = REPORT_TOOL.parse_report(report_path)
    metrics = REPORT_TOOL.build_metrics(fields, records)
    return {
        "net_profit": float(metrics.get("total_net_profit", 0.0)),
        "profit_factor": float(metrics.get("profit_factor", 0.0)),
        "trades": int(metrics.get("total_trades", 0) or 0),
        "win_rate": float(metrics.get("win_rate_percent", 0.0)),
        "max_drawdown_percent": max(
            float(metrics.get("maximal_drawdown_percent", 0.0) or 0.0),
            float(metrics.get("relative_drawdown_percent", 0.0) or 0.0),
        ),
        "expected_payoff": float(metrics.get("expected_payoff", 0.0)),
        "average_win": float(metrics.get("average_profit_trade", 0.0)),
        "average_loss": float(metrics.get("average_loss_trade", 0.0)),
        "report_kind": report_kind,
    }


def read_telemetry_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    for encoding in ("utf-8-sig", "utf-8", "cp932", "cp1252"):
        try:
            with path.open("r", encoding=encoding, newline="") as handle:
                reader = csv.DictReader(handle, delimiter=";")
                return [dict(row) for row in reader]
        except UnicodeDecodeError:
            continue
    raise RuntimeError(f"Failed to decode telemetry: {path}")


def parse_float(value: str | None) -> float:
    if value in (None, ""):
        return 0.0
    return float(value)


def parse_int(value: str | None) -> int:
    if value in (None, ""):
        return -1
    return int(float(value))


def parse_bool(value: str | None) -> bool:
    if value is None:
        return False
    return value.strip().lower() in {"1", "true", "yes", "on"}


def average(values: list[float]) -> float:
    if not values:
        return 0.0
    return round(sum(values) / len(values), 4)


def percentile(values: list[float], quantile: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    if len(ordered) == 1:
        return round(ordered[0], 4)
    position = (len(ordered) - 1) * quantile
    lower = int(math.floor(position))
    upper = int(math.ceil(position))
    if lower == upper:
        return round(ordered[lower], 4)
    weight = position - lower
    interpolated = ordered[lower] * (1.0 - weight) + ordered[upper] * weight
    return round(interpolated, 4)


def init_rollup() -> dict[str, Any]:
    return {
        "trades": 0,
        "wins": 0,
        "losses": 0,
        "gross_profit": 0.0,
        "gross_loss_abs": 0.0,
        "net_profit": 0.0,
        "sum_realized_r": 0.0,
        "realized_r_count": 0,
    }


def add_trade_to_rollup(rollup: dict[str, Any], profit: float, realized_r: float | None) -> None:
    rollup["trades"] += 1
    rollup["net_profit"] += profit
    if profit > 0.0:
        rollup["wins"] += 1
        rollup["gross_profit"] += profit
    elif profit < 0.0:
        rollup["losses"] += 1
        rollup["gross_loss_abs"] += abs(profit)

    if realized_r is not None:
        rollup["sum_realized_r"] += realized_r
        rollup["realized_r_count"] += 1


def finalize_rollup(rollup: dict[str, Any]) -> dict[str, Any]:
    trades = int(rollup["trades"])
    wins = int(rollup["wins"])
    losses = int(rollup["losses"])
    gross_loss_abs = float(rollup["gross_loss_abs"])
    return {
        "trades": trades,
        "wins": wins,
        "losses": losses,
        "gross_profit": round(float(rollup["gross_profit"]), 4),
        "gross_loss": round(-gross_loss_abs, 4),
        "gross_loss_abs": round(gross_loss_abs, 4),
        "net_profit": round(float(rollup["net_profit"]), 4),
        "profit_factor": round(float(rollup["gross_profit"]) / gross_loss_abs, 4) if gross_loss_abs > 0.0 else 0.0,
        "win_rate": round((wins / trades) * 100.0, 2) if trades else 0.0,
        "avg_profit": round(float(rollup["net_profit"]) / trades, 4) if trades else 0.0,
        "avg_realized_r": round(float(rollup["sum_realized_r"]) / int(rollup["realized_r_count"]), 4)
        if int(rollup["realized_r_count"])
        else 0.0,
        "sum_realized_r": round(float(rollup["sum_realized_r"]), 4),
        "realized_r_count": int(rollup["realized_r_count"]),
    }


def summarize_telemetry(path: Path) -> dict[str, Any]:
    rows = read_telemetry_rows(path)
    if not rows:
        empty = finalize_rollup(init_rollup())
        empty.update(
            {
                "rows": 0,
                "closed_trades": 0,
                "avg_bars_from_setup_to_entry": 0.0,
                "avg_setup_to_entry_pips": 0.0,
                "avg_bars_to_mfe_peak": 0.0,
                "avg_bars_to_tp_hit": 0.0,
                "configured_tp_hit_rate": 0.0,
                "stop_before_tp_rate": 0.0,
                "acceptance_before_tp_rate": 0.0,
                "time_stop_before_tp_rate": 0.0,
                "mfe_distribution": {"mean": 0.0, "median": 0.0, "p25": 0.0, "p50": 0.0, "p75": 0.0},
                "mae_distribution": {"mean": 0.0, "median": 0.0, "p25": 0.0, "p50": 0.0, "p75": 0.0},
                "tp_hit_rates": {label: 0.0 for label, _ in TP_LEVEL_COLUMNS},
                "exit_reason_breakdown": {},
            }
        )
        return empty

    campaigns: dict[str, dict[str, Any]] = {}
    active_trade_key: str | None = None
    trade_sequence = 0

    for row in rows:
        event_type = row.get("event_type", "")
        position_id = row.get("position_id", "") or "0"

        if event_type == "entry":
            trade_sequence += 1
            active_trade_key = f"campaign_{trade_sequence}"

        trade_key = active_trade_key or f"orphan_{position_id}"
        trade = campaigns.setdefault(
            trade_key,
            {
                "trade_key": trade_key,
                "position_id": position_id,
                "side": row.get("side", ""),
                "tier": row.get("tier", ""),
                "context_phase": row.get("context_phase", ""),
                "context_bucket": row.get("context_bucket", ""),
                "wave_label": row.get("wave_label", ""),
                "pattern_label": row.get("pattern_label", ""),
                "pattern_state": row.get("pattern_state", ""),
                "execution_trigger": row.get("execution_trigger", ""),
                "pattern_tf": row.get("pattern_tf", ""),
                "execution_tf": row.get("execution_tf", ""),
                "exit_mode": row.get("exit_mode", ""),
                "configured_fixed_tp_pips": 0.0,
                "planned_risk_amount": 0.0,
                "bars_from_setup_to_entry": -1,
                "setup_to_entry_pips": 0.0,
                "bars_to_final": -1,
                "bars_to_time_stop": -1,
                "bars_to_mfe_peak": -1,
                "bars_to_tp_hit": -1,
                "mfe_pips": 0.0,
                "mae_pips": 0.0,
                "max_unrealized_r": 0.0,
                "min_unrealized_r": 0.0,
                "did_hit_configured_tp": False,
                "tp_hit_before_time_stop": False,
                "tp_hit_before_acceptance_exit": False,
                "did_hit_tp_levels": {label: False for label, _ in TP_LEVEL_COLUMNS},
                "net_profit": 0.0,
                "final_reason": "",
                "final_outcome": "",
                "has_exit": False,
                "total_realized_r": None,
            },
        )

        planned_risk_amount = parse_float(row.get("planned_risk_amount"))
        if planned_risk_amount > 0.0:
            trade["planned_risk_amount"] = planned_risk_amount

        configured_fixed_tp_pips = parse_float(row.get("configured_fixed_tp_pips"))
        if configured_fixed_tp_pips > 0.0:
            trade["configured_fixed_tp_pips"] = configured_fixed_tp_pips

        bars_from_setup = parse_int(row.get("bars_from_pattern_to_entry"))
        if bars_from_setup >= 0:
            trade["bars_from_setup_to_entry"] = bars_from_setup
        trade["setup_to_entry_pips"] = parse_float(row.get("setup_to_entry_pips"))
        trade["mfe_pips"] = max(trade["mfe_pips"], parse_float(row.get("mfe_pips")))
        trade["mae_pips"] = max(trade["mae_pips"], parse_float(row.get("mae_pips")))
        trade["max_unrealized_r"] = max(trade["max_unrealized_r"], parse_float(row.get("max_unrealized_r")))
        trade["min_unrealized_r"] = min(trade["min_unrealized_r"], parse_float(row.get("min_unrealized_r")))

        for label, column in TP_LEVEL_COLUMNS:
            trade["did_hit_tp_levels"][label] = parse_bool(row.get(column)) or trade["did_hit_tp_levels"][label]

        if event_type == "entry":
            trade["side"] = row.get("side", trade["side"])
            trade["tier"] = row.get("tier", trade["tier"])
            trade["context_phase"] = row.get("context_phase", trade["context_phase"])
            trade["context_bucket"] = row.get("context_bucket", trade["context_bucket"])
            trade["wave_label"] = row.get("wave_label", trade["wave_label"])
            trade["pattern_label"] = row.get("pattern_label", trade["pattern_label"])
            trade["pattern_state"] = row.get("pattern_state", trade["pattern_state"])
            trade["execution_trigger"] = row.get("execution_trigger", trade["execution_trigger"])
            trade["pattern_tf"] = row.get("pattern_tf", trade["pattern_tf"])
            trade["execution_tf"] = row.get("execution_tf", trade["execution_tf"])
            trade["exit_mode"] = row.get("exit_mode", trade["exit_mode"])
            continue

        if event_type == "partial_exit":
            trade["net_profit"] += parse_float(row.get("net_profit"))
            continue

        if event_type == "exit":
            profit = parse_float(row.get("net_profit"))
            trade["net_profit"] += profit
            trade["final_reason"] = row.get("reason", "")
            trade["final_outcome"] = row.get("outcome", "")
            bars_to_final = parse_int(row.get("bars_to_final"))
            if bars_to_final >= 0:
                trade["bars_to_final"] = bars_to_final
            bars_to_time_stop = parse_int(row.get("bars_to_time_stop"))
            if bars_to_time_stop >= 0:
                trade["bars_to_time_stop"] = bars_to_time_stop
            bars_to_mfe_peak = parse_int(row.get("bars_to_mfe_peak"))
            if bars_to_mfe_peak >= 0:
                trade["bars_to_mfe_peak"] = bars_to_mfe_peak
            bars_to_tp_hit = parse_int(row.get("bars_to_tp_hit"))
            if bars_to_tp_hit >= 0:
                trade["bars_to_tp_hit"] = bars_to_tp_hit
            trade["did_hit_configured_tp"] = parse_bool(row.get("did_hit_configured_tp"))
            trade["tp_hit_before_time_stop"] = parse_bool(row.get("tp_hit_before_time_stop"))
            trade["tp_hit_before_acceptance_exit"] = parse_bool(row.get("tp_hit_before_acceptance_exit"))
            trade["has_exit"] = True
            active_trade_key = None

    closed_trades = [trade for trade in campaigns.values() if trade["has_exit"]]
    summary_rollup = init_rollup()
    exit_reason_breakdown: dict[str, dict[str, Any]] = {}
    bars_from_setup_values: list[float] = []
    setup_to_entry_values: list[float] = []
    bars_to_mfe_peak_values: list[float] = []
    bars_to_tp_hit_values: list[float] = []
    mfe_values: list[float] = []
    mae_values: list[float] = []
    tp_hits: dict[str, int] = {label: 0 for label, _ in TP_LEVEL_COLUMNS}
    configured_tp_hits = 0
    stop_before_tp_count = 0
    acceptance_before_tp_count = 0
    time_stop_before_tp_count = 0

    for trade in closed_trades:
        planned_risk_amount = float(trade["planned_risk_amount"])
        realized_r = None
        if planned_risk_amount > 0.0:
            realized_r = float(trade["net_profit"]) / planned_risk_amount
            trade["total_realized_r"] = realized_r
        add_trade_to_rollup(summary_rollup, float(trade["net_profit"]), realized_r)

        if trade["bars_from_setup_to_entry"] >= 0:
            bars_from_setup_values.append(float(trade["bars_from_setup_to_entry"]))
        setup_to_entry_values.append(float(trade["setup_to_entry_pips"]))
        if trade["bars_to_mfe_peak"] >= 0:
            bars_to_mfe_peak_values.append(float(trade["bars_to_mfe_peak"]))
        if trade["bars_to_tp_hit"] >= 0:
            bars_to_tp_hit_values.append(float(trade["bars_to_tp_hit"]))
        mfe_values.append(float(trade["mfe_pips"]))
        mae_values.append(float(trade["mae_pips"]))

        if trade["did_hit_configured_tp"]:
            configured_tp_hits += 1

        final_reason = trade["final_reason"] or "unknown"
        if final_reason == "stop_loss" and not trade["did_hit_configured_tp"]:
            stop_before_tp_count += 1
        if final_reason.startswith("acceptance_") and not trade["did_hit_configured_tp"]:
            acceptance_before_tp_count += 1
        if final_reason == "time_stop" and not trade["did_hit_configured_tp"]:
            time_stop_before_tp_count += 1

        bucket = exit_reason_breakdown.setdefault(final_reason, {"count": 0, "net_profit": 0.0})
        bucket["count"] += 1
        bucket["net_profit"] += float(trade["net_profit"])

        for label, _ in TP_LEVEL_COLUMNS:
            if trade["did_hit_tp_levels"][label]:
                tp_hits[label] += 1

    summary = finalize_rollup(summary_rollup)
    closed_count = len(closed_trades)
    summary.update(
        {
            "rows": len(rows),
            "closed_trades": closed_count,
            "avg_bars_from_setup_to_entry": average(bars_from_setup_values),
            "avg_setup_to_entry_pips": average(setup_to_entry_values),
            "avg_bars_to_mfe_peak": average(bars_to_mfe_peak_values),
            "avg_bars_to_tp_hit": average(bars_to_tp_hit_values),
            "configured_tp_hit_rate": round((configured_tp_hits / closed_count) * 100.0, 2) if closed_count else 0.0,
            "stop_before_tp_rate": round((stop_before_tp_count / closed_count) * 100.0, 2) if closed_count else 0.0,
            "acceptance_before_tp_rate": round((acceptance_before_tp_count / closed_count) * 100.0, 2) if closed_count else 0.0,
            "time_stop_before_tp_rate": round((time_stop_before_tp_count / closed_count) * 100.0, 2) if closed_count else 0.0,
            "mfe_distribution": {
                "mean": average(mfe_values),
                "median": percentile(mfe_values, 0.50),
                "p25": percentile(mfe_values, 0.25),
                "p50": percentile(mfe_values, 0.50),
                "p75": percentile(mfe_values, 0.75),
            },
            "mae_distribution": {
                "mean": average(mae_values),
                "median": percentile(mae_values, 0.50),
                "p25": percentile(mae_values, 0.25),
                "p50": percentile(mae_values, 0.50),
                "p75": percentile(mae_values, 0.75),
            },
            "tp_hit_rates": {
                label: round((count / closed_count) * 100.0, 2) if closed_count else 0.0
                for label, count in tp_hits.items()
            },
            "exit_reason_breakdown": {
                reason: {
                    "count": values["count"],
                    "net_profit": round(values["net_profit"], 4),
                }
                for reason, values in sorted(exit_reason_breakdown.items(), key=lambda item: item[1]["count"], reverse=True)
            },
        }
    )
    return summary


def summarize_run(spec: RunSpec) -> dict[str, Any]:
    return {
        "slug": spec.slug,
        "pair_key": spec.pair_key,
        "pair_label": spec.pair_label,
        "window": spec.window,
        "trigger_key": spec.trigger_key,
        "tp_pips": spec.tp_pips,
        "hold_bars": spec.hold_bars,
        "preset_path": str(spec.preset_path),
        "config_path": str(spec.config_path),
        "report_path": str(spec.report_path),
        "telemetry_path": str(spec.telemetry_path),
        "report_metrics": parse_report_metrics(spec.report_path),
        "telemetry": summarize_telemetry(spec.telemetry_path),
    }


def build_matrix_specs(include_second_trigger: bool) -> list[RunSpec]:
    specs: list[RunSpec] = []
    triggers = TRIGGERS if include_second_trigger else TRIGGERS[:1]
    ordinal = 1
    for pair_key, context_tf, pattern_tf, execution_tf in PAIR_SPECS:
        pair = PairSpec(pair_key, context_tf, pattern_tf, execution_tf)
        for window in ("train", "oos", "actual"):
            for trigger_key, trigger_mode in triggers:
                for tp_pips in TP_GRID:
                    for hold_bars in HOLD_GRID:
                        specs.append(build_run_spec(pair, window, trigger_key, trigger_mode, tp_pips, hold_bars, ordinal))
                        ordinal += 1
    return specs


def build_summary_markdown(results: list[dict[str, Any]], include_second_trigger: bool) -> str:
    lines = [
        "# USDJPY Dow HS Fixed TP Diagnostic",
        "",
        f"- total runs: {len(results)}",
        f"- triggers: `{', '.join(trigger for trigger, _ in (TRIGGERS if include_second_trigger else TRIGGERS[:1]))}`",
        "- fixed slice: `Tier A strict`, `short-only`, structural stop intact, acceptance exit on, runner/BE off in diagnostic mode",
        "- pairs: `M30 x M15 x M3`, `M15 x M10 x M5`",
        "- TP grid: `2 / 3 / 4 / 5 / 6 / 8` pips",
        "- hold bars: `16 / 24 / 32`",
        "",
    ]

    for window in ("train", "oos", "actual"):
        window_runs = [item for item in results if item["window"] == window]
        if not window_runs:
            continue
        lines.extend(
            [
                f"## {window.upper()}",
                "",
                "| slug | pair | trigger | tp | hold | trades | pf | net | exp payoff | max dd % | win rate % | avg R | cfg tp hit % | mfe p50 | mfe p75 | stop<tp % | accept<tp % | time<tp % |",
                "|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|",
            ]
        )
        sort_key = lambda item: (item["pair_key"], item["trigger_key"], item["tp_pips"], item["hold_bars"])
        for item in sorted(window_runs, key=sort_key):
            report = item["report_metrics"]
            telemetry = item["telemetry"]
            lines.append(
                "| {slug} | {pair} | {trigger} | {tp:.0f} | {hold} | {trades} | {pf:.2f} | {net:.2f} | {exp:.2f} | {dd:.2f} | {win:.2f} | {avg_r:.4f} | {tp_hit:.2f} | {mfe_p50:.2f} | {mfe_p75:.2f} | {stop_rate:.2f} | {accept_rate:.2f} | {time_rate:.2f} |".format(
                    slug=item["slug"],
                    pair=item["pair_label"],
                    trigger=item["trigger_key"],
                    tp=item["tp_pips"],
                    hold=item["hold_bars"],
                    trades=report["trades"],
                    pf=report["profit_factor"],
                    net=report["net_profit"],
                    exp=report["expected_payoff"],
                    dd=report["max_drawdown_percent"],
                    win=report["win_rate"],
                    avg_r=telemetry["avg_realized_r"],
                    tp_hit=telemetry["configured_tp_hit_rate"],
                    mfe_p50=telemetry["mfe_distribution"]["p50"],
                    mfe_p75=telemetry["mfe_distribution"]["p75"],
                    stop_rate=telemetry["stop_before_tp_rate"],
                    accept_rate=telemetry["acceptance_before_tp_rate"],
                    time_rate=telemetry["time_stop_before_tp_rate"],
                )
            )
        lines.append("")

    return "\n".join(lines) + "\n"


def write_outputs(results: list[dict[str, Any]], include_second_trigger: bool) -> None:
    payload = {
        "runs": results,
        "matrix": {
            "pairs": [
                {
                    "key": pair_key,
                    "context_tf": context_tf,
                    "pattern_tf": pattern_tf,
                    "execution_tf": execution_tf,
                }
                for pair_key, context_tf, pattern_tf, execution_tf in PAIR_SPECS
            ],
            "triggers": [trigger for trigger, _ in (TRIGGERS if include_second_trigger else TRIGGERS[:1])],
            "tp_grid": TP_GRID,
            "hold_grid": HOLD_GRID,
            "windows": list(WINDOWS.keys()),
        },
    }
    (RESULTS_ROOT / "results.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
    (RESULTS_ROOT / "summary.md").write_text(build_summary_markdown(results, include_second_trigger), encoding="utf-8")


def main() -> None:
    args = parse_args()
    ensure_dirs()
    specs = build_matrix_specs(args.include_second_trigger)
    if args.max_runs > 0:
        specs = specs[: args.max_runs]

    results: list[dict[str, Any]] = []
    total_runs = len(specs)
    for index, spec in enumerate(specs, start=1):
        print(f"[{index}/{total_runs}] {spec.slug}", flush=True)
        generate_run_files(spec)
        run_backtest(spec, args.terminal_path, args.timeout_seconds, args.reuse_existing)
        results.append(summarize_run(spec))

    write_outputs(results, args.include_second_trigger)
    print(f"Wrote: {RESULTS_ROOT / 'results.json'}", flush=True)
    print(f"Wrote: {RESULTS_ROOT / 'summary.md'}", flush=True)


if __name__ == "__main__":
    main()
