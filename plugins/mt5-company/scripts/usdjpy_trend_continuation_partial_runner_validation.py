from __future__ import annotations

import argparse
import csv
import importlib.util
import json
import os
import subprocess
import sys
from collections import defaultdict
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any


SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[3]
COMMON_FILES_ROOT = Path(os.environ["APPDATA"]) / "MetaQuotes" / "Terminal" / "Common" / "Files"
SWEEP_ROOT = REPO_ROOT / "reports" / "backtest" / "sweeps" / "2026-04-14-usdjpy-cont-partial"
RESULTS_ROOT = SWEEP_ROOT / "results"
CONFIGS_ROOT = SWEEP_ROOT / "configs"
PRESETS_ROOT = SWEEP_ROOT / "presets"
REPORTS_ROOT = SWEEP_ROOT / "reports"
BASE_PRESET = REPO_ROOT / "reports" / "presets" / "usdjpy_20260414_trend_continuation_pullback_engine-tierA.set"
EXPERT_PATH = "dev\\mql\\Experts\\usdjpy_20260414_trend_continuation_pullback_engine.ex5"
TERMINAL_DEFAULT = Path(r"C:\Program Files\XMTrading MT5\terminal64.exe")
BACKTEST_SCRIPT = REPO_ROOT / "scripts" / "backtest.ps1"
REPORT_TOOL_PATH = REPO_ROOT / "plugins" / "mt5-company" / "scripts" / "mt5_backtest_tools.py"

WINDOWS = {
    "train": ("2025.04.01", "2025.12.31"),
    "oos": ("2026.01.01", "2026.04.01"),
    "actual": ("2024.11.26", "2026.04.01"),
}

PARTIAL_LEVELS: list[tuple[str, int]] = [
    ("partial382", 382),
    ("partial500", 500),
]

RUNNER_TARGETS: list[tuple[str, int]] = [
    ("runner_fib618", 0),
    ("runner_prior_swing", 1),
    ("runner_fixed_r", 2),
]

ORDER_MODES: list[tuple[str, int]] = [
    ("ea_managed", 0),
    ("server_partial", 1),
]

HOLD_BARS = (16, 24, 32)


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
class RunSpec:
    slug: str
    window: str
    partial_key: str
    partial_mode: int
    runner_key: str
    runner_mode: int
    order_key: str
    order_mode: int
    hold_bars: int
    preset_path: Path
    config_path: Path
    report_path: Path
    telemetry_name: str
    telemetry_path: Path
    magic_number: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run higher-low-break partial/runner diagnostics for the continuation family.")
    parser.add_argument("--terminal-path", default=str(TERMINAL_DEFAULT))
    parser.add_argument("--timeout-seconds", type=int, default=900)
    parser.add_argument("--reuse-existing", action="store_true")
    parser.add_argument("--max-runs", type=int, default=0)
    return parser.parse_args()


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
    if len(parts) >= 1:
        parts[0] = replacement
    if len(parts) >= 2:
        parts[1] = replacement
    return "||".join(parts)


def write_preset(base_preset: Path, overrides: dict[str, Any], target_path: Path) -> None:
    base_values = read_preset_lines(base_preset)
    pending = dict(overrides)
    lines: list[str] = [f"; auto-generated from {base_preset.name}"]
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
    return f"MQL5\\Experts\\dev\\reports\\backtest\\sweeps\\2026-04-14-usdjpy-cont-partial\\reports\\{slug}.htm"


def write_config(spec: RunSpec) -> None:
    from_date, to_date = WINDOWS[spec.window]
    relative_preset = spec.preset_path.relative_to(REPO_ROOT).as_posix().replace("/", "\\")
    config_lines = [
        "; auto-generated partial/runner diagnostics config",
        "",
        "[Tester]",
        f"Expert={EXPERT_PATH}",
        f"PresetSource={relative_preset}",
        f"PresetName={spec.preset_path.name}",
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
        f"Report={build_report_relative_path(spec.slug)}",
    ]
    spec.config_path.write_text("\n".join(config_lines) + "\n", encoding="utf-8")


def build_run_spec(
    window: str,
    partial_key: str,
    partial_mode: int,
    runner_key: str,
    runner_mode: int,
    order_key: str,
    order_mode: int,
    hold_bars: int,
    ordinal: int,
) -> RunSpec:
    slug = f"{window}-{partial_key}-{runner_key}-{order_key}-h{hold_bars}"
    telemetry_name = f"mt5_company_{slug}.csv"
    return RunSpec(
        slug=slug,
        window=window,
        partial_key=partial_key,
        partial_mode=partial_mode,
        runner_key=runner_key,
        runner_mode=runner_mode,
        order_key=order_key,
        order_mode=order_mode,
        hold_bars=hold_bars,
        preset_path=PRESETS_ROOT / f"{slug}.set",
        config_path=CONFIGS_ROOT / f"{slug}.ini",
        report_path=REPORTS_ROOT / f"{slug}.htm",
        telemetry_name=telemetry_name,
        telemetry_path=COMMON_FILES_ROOT / telemetry_name,
        magic_number=2026042400 + ordinal,
    )


def generate_run_files(spec: RunSpec) -> None:
    overrides = {
        "InpTrendTimeframe": 15,
        "InpSignalTimeframe": 5,
        "InpTierMode": 0,
        "InpEntryPathMode": 2,
        "InpStopBasisMode": 0,
        "InpTargetMode": 3,
        "InpHybridPartialTargetLevel": spec.partial_mode,
        "InpHybridRunnerTargetMode": spec.runner_mode,
        "InpExitExecutionMode": spec.order_mode,
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
    metrics["report_kind"] = report_kind
    return metrics


def load_meta(path: Path) -> dict[str, Any]:
    meta_path = path.with_name(path.name + ".meta.json")
    if meta_path.exists():
        return json.loads(meta_path.read_text(encoding="utf-8-sig"))
    return {}


def read_telemetry_rows(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    encodings = ("utf-8-sig", "utf-8", "cp932", "cp1252")
    for encoding in encodings:
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
    lowered = value.strip().lower()
    return lowered in {"1", "true", "yes", "on"}


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
        "sum_win_r": 0.0,
        "win_r_count": 0,
        "sum_loss_r": 0.0,
        "loss_r_count": 0,
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
        if realized_r > 0.0:
            rollup["sum_win_r"] += realized_r
            rollup["win_r_count"] += 1
        elif realized_r < 0.0:
            rollup["sum_loss_r"] += realized_r
            rollup["loss_r_count"] += 1


def finalize_rollup(rollup: dict[str, Any]) -> dict[str, Any]:
    trades = rollup["trades"]
    wins = rollup["wins"]
    losses = rollup["losses"]
    gross_loss_abs = rollup["gross_loss_abs"]
    result = dict(rollup)
    result["profit_factor"] = round(result["gross_profit"] / gross_loss_abs, 4) if gross_loss_abs > 0.0 else 0.0
    result["win_rate"] = round((wins / trades) * 100.0, 2) if trades else 0.0
    result["avg_profit"] = round(result["net_profit"] / trades, 4) if trades else 0.0
    result["avg_win_amount"] = round(result["gross_profit"] / wins, 4) if wins else 0.0
    result["avg_loss_amount"] = round((-gross_loss_abs) / losses, 4) if losses else 0.0
    result["avg_realized_r"] = round(result["sum_realized_r"] / result["realized_r_count"], 4) if result["realized_r_count"] else 0.0
    result["avg_win_r"] = round(result["sum_win_r"] / result["win_r_count"], 4) if result["win_r_count"] else 0.0
    result["avg_loss_r"] = round(result["sum_loss_r"] / result["loss_r_count"], 4) if result["loss_r_count"] else 0.0
    result["net_profit"] = round(result["net_profit"], 4)
    result["gross_profit"] = round(result["gross_profit"], 4)
    result["gross_loss"] = round(-gross_loss_abs, 4)
    return result


def aggregate_dimension(trades: list[dict[str, Any]], key: str) -> dict[str, Any]:
    groups: dict[str, dict[str, Any]] = defaultdict(init_rollup)
    for trade in trades:
        bucket = str(trade.get(key) or "unknown")
        add_trade_to_rollup(groups[bucket], float(trade.get("net_profit", 0.0)), trade.get("total_realized_r"))
    return dict(
        sorted(
            ((bucket, finalize_rollup(rollup)) for bucket, rollup in groups.items()),
            key=lambda item: (item[1]["profit_factor"], item[1]["net_profit"], item[1]["trades"]),
            reverse=True,
        )
    )


def summarize_telemetry(path: Path) -> dict[str, Any]:
    rows = read_telemetry_rows(path)
    if not rows:
        empty = finalize_rollup(init_rollup())
        empty.update(
            {
                "rows": 0,
                "closed_trades": 0,
                "partial_hit_count": 0,
                "partial_hit_rate": 0.0,
                "be_move_count": 0,
                "be_move_rate": 0.0,
                "runner_target_hit_count": 0,
                "runner_target_hit_rate": 0.0,
                "runner_breakeven_stop_count": 0,
                "target_before_timeout_count": 0,
                "target_before_timeout_rate": 0.0,
                "exit_reason_breakdown": {},
                "target_hit_count": 0,
                "stop_loss_count": 0,
                "time_stop_count": 0,
                "acceptance_exit_count": 0,
                "partial_exit_count": 0,
                "avg_realized_r_after_partial": 0.0,
                "avg_realized_r_without_partial": 0.0,
                "avg_runner_realized_r": 0.0,
                "avg_loss_r": 0.0,
                "avg_bars_to_partial": 0.0,
                "avg_bars_to_final": 0.0,
                "avg_bars_to_time_stop": 0.0,
                "dimensions": {},
            }
        )
        return empty

    positions: dict[str, dict[str, Any]] = {}
    active_trade_key: str | None = None
    trade_sequence = 0

    for row in rows:
        event_type = row.get("event_type", "")
        position_id = row.get("position_id", "") or "0"

        if event_type == "entry":
            trade_sequence += 1
            active_trade_key = f"campaign_{trade_sequence}"
        trade_key = active_trade_key or f"orphan_{position_id}"

        trade = positions.setdefault(
            trade_key,
            {
                "position_id": position_id,
                "trade_key": trade_key,
                "entry_type": row.get("entry_type", ""),
                "phase": row.get("phase", ""),
                "wave_label": row.get("wave_label", ""),
                "context_bucket": row.get("context_bucket", ""),
                "fib_depth_bucket": row.get("fib_depth_bucket", ""),
                "ltf_state": row.get("ltf_state", ""),
                "setup_type": row.get("setup_type", ""),
                "stop_basis": row.get("stop_basis", ""),
                "target_type": row.get("target_type", ""),
                "order_mode": row.get("order_mode", ""),
                "partial_target_label": row.get("partial_target_label", ""),
                "runner_target_label": row.get("runner_target_label", ""),
                "volatility_bucket": row.get("volatility_bucket", ""),
                "hour_bucket": row.get("hour", ""),
                "tier": row.get("tier", ""),
                "planned_risk_amount": 0.0,
                "net_profit": 0.0,
                "partial_profit": 0.0,
                "final_profit": 0.0,
                "partial_hit": False,
                "partial_exit_count": 0,
                "be_moved": False,
                "partial_order_armed": False,
                "runner_target_enabled": False,
                "runner_target_hit": False,
                "runner_stop_at_breakeven": False,
                "bars_to_partial": -1,
                "bars_to_final": -1,
                "bars_to_time_stop": -1,
                "target_reached_before_timeout": False,
                "final_reason": "",
                "final_outcome": "",
                "has_exit": False,
                "total_realized_r": None,
                "runner_realized_r": None,
            },
        )

        if parse_float(row.get("planned_risk_amount")) > 0.0:
            trade["planned_risk_amount"] = parse_float(row.get("planned_risk_amount"))

        if event_type == "entry":
            trade["entry_type"] = row.get("entry_type", trade["entry_type"])
            trade["phase"] = row.get("phase", trade["phase"])
            trade["wave_label"] = row.get("wave_label", trade["wave_label"])
            trade["context_bucket"] = row.get("context_bucket", trade["context_bucket"])
            trade["fib_depth_bucket"] = row.get("fib_depth_bucket", trade["fib_depth_bucket"])
            trade["ltf_state"] = row.get("ltf_state", trade["ltf_state"])
            trade["setup_type"] = row.get("setup_type", trade["setup_type"])
            trade["stop_basis"] = row.get("stop_basis", trade["stop_basis"])
            trade["target_type"] = row.get("target_type", trade["target_type"])
            trade["order_mode"] = row.get("order_mode", trade["order_mode"])
            trade["partial_target_label"] = row.get("partial_target_label", trade["partial_target_label"])
            trade["runner_target_label"] = row.get("runner_target_label", trade["runner_target_label"])
            trade["volatility_bucket"] = row.get("volatility_bucket", trade["volatility_bucket"])
            trade["hour_bucket"] = row.get("hour", trade["hour_bucket"])
            trade["tier"] = row.get("tier", trade["tier"])
            trade["partial_order_armed"] = parse_bool(row.get("partial_order_armed"))
            trade["runner_target_enabled"] = parse_bool(row.get("runner_target_enabled"))
            continue

        if event_type == "partial_exit":
            trade["net_profit"] += parse_float(row.get("net_profit"))
            trade["partial_profit"] += parse_float(row.get("net_profit"))
            trade["partial_hit"] = True
            trade["partial_exit_count"] += 1
            trade["be_moved"] = parse_bool(row.get("be_moved")) or trade["be_moved"]
            if parse_int(row.get("bars_to_partial")) >= 0:
                trade["bars_to_partial"] = parse_int(row.get("bars_to_partial"))
            continue

        if event_type == "exit":
            trade["net_profit"] += parse_float(row.get("net_profit"))
            trade["final_profit"] += parse_float(row.get("net_profit"))
            trade["final_reason"] = row.get("reason", "")
            trade["final_outcome"] = row.get("outcome", "")
            trade["runner_target_hit"] = parse_bool(row.get("runner_target_hit"))
            trade["runner_stop_at_breakeven"] = parse_bool(row.get("runner_stop_at_breakeven"))
            trade["target_reached_before_timeout"] = parse_bool(row.get("target_reached_before_timeout"))
            if parse_int(row.get("bars_to_final")) >= 0:
                trade["bars_to_final"] = parse_int(row.get("bars_to_final"))
            if parse_int(row.get("bars_to_time_stop")) >= 0:
                trade["bars_to_time_stop"] = parse_int(row.get("bars_to_time_stop"))
            trade["has_exit"] = True
            active_trade_key = None

    closed_trades = [trade for trade in positions.values() if trade["has_exit"]]
    summary_rollup = init_rollup()
    partial_rollup = init_rollup()
    no_partial_rollup = init_rollup()
    runner_rollup = init_rollup()
    exit_reason_breakdown: dict[str, dict[str, Any]] = defaultdict(lambda: {"count": 0, "net_profit": 0.0})

    partial_hit_count = 0
    be_move_count = 0
    runner_target_hit_count = 0
    runner_breakeven_stop_count = 0
    target_before_timeout_count = 0
    target_hit_count = 0
    stop_loss_count = 0
    time_stop_count = 0
    acceptance_exit_count = 0
    partial_exit_count = 0
    bars_to_partial_values: list[int] = []
    bars_to_final_values: list[int] = []
    bars_to_time_stop_values: list[int] = []

    for trade in closed_trades:
        planned_risk_amount = float(trade["planned_risk_amount"])
        total_realized_r = None
        runner_realized_r = None
        if planned_risk_amount > 0.0:
            total_realized_r = float(trade["net_profit"]) / planned_risk_amount
            trade["total_realized_r"] = total_realized_r
            runner_realized_r = float(trade["final_profit"]) / planned_risk_amount
            trade["runner_realized_r"] = runner_realized_r

        add_trade_to_rollup(summary_rollup, float(trade["net_profit"]), total_realized_r)

        if trade["partial_hit"]:
            partial_hit_count += 1
            add_trade_to_rollup(partial_rollup, float(trade["net_profit"]), total_realized_r)
            partial_exit_count += int(trade["partial_exit_count"])
            if trade["be_moved"]:
                be_move_count += 1
            if trade["runner_target_hit"]:
                runner_target_hit_count += 1
            if trade["runner_stop_at_breakeven"]:
                runner_breakeven_stop_count += 1
            if runner_realized_r is not None:
                add_trade_to_rollup(runner_rollup, float(trade["final_profit"]), runner_realized_r)
            if trade["bars_to_partial"] >= 0:
                bars_to_partial_values.append(int(trade["bars_to_partial"]))
        else:
            add_trade_to_rollup(no_partial_rollup, float(trade["net_profit"]), total_realized_r)

        if trade["bars_to_final"] >= 0:
            bars_to_final_values.append(int(trade["bars_to_final"]))
        if trade["bars_to_time_stop"] >= 0:
            bars_to_time_stop_values.append(int(trade["bars_to_time_stop"]))

        if trade["target_reached_before_timeout"]:
            target_before_timeout_count += 1

        final_reason = trade["final_reason"] or "unknown"
        exit_reason_breakdown[final_reason]["count"] += 1
        exit_reason_breakdown[final_reason]["net_profit"] += float(trade["net_profit"])

        if final_reason in {"target", "runner_target"}:
            target_hit_count += 1
        elif final_reason == "stop_loss":
            stop_loss_count += 1
        elif final_reason == "time_stop":
            time_stop_count += 1
        elif final_reason == "acceptance_back_below":
            acceptance_exit_count += 1

    dimensions = {}
    for key in (
        "phase",
        "context_bucket",
        "wave_label",
        "fib_depth_bucket",
        "ltf_state",
        "entry_type",
        "stop_basis",
        "target_type",
        "order_mode",
        "partial_target_label",
        "runner_target_label",
        "volatility_bucket",
        "hour_bucket",
        "final_reason",
    ):
        dimensions[key] = aggregate_dimension(closed_trades, key)

    normalized_exit_breakdown = {
        reason: {"count": values["count"], "net_profit": round(values["net_profit"], 4)}
        for reason, values in sorted(exit_reason_breakdown.items(), key=lambda item: item[1]["count"], reverse=True)
    }

    summary = finalize_rollup(summary_rollup)
    partial_summary = finalize_rollup(partial_rollup)
    no_partial_summary = finalize_rollup(no_partial_rollup)
    runner_summary = finalize_rollup(runner_rollup)

    summary.update(
        {
            "rows": len(rows),
            "closed_trades": len(closed_trades),
            "partial_hit_count": partial_hit_count,
            "partial_hit_rate": round((partial_hit_count / len(closed_trades)) * 100.0, 2) if closed_trades else 0.0,
            "be_move_count": be_move_count,
            "be_move_rate": round((be_move_count / partial_hit_count) * 100.0, 2) if partial_hit_count else 0.0,
            "runner_target_hit_count": runner_target_hit_count,
            "runner_target_hit_rate": round((runner_target_hit_count / partial_hit_count) * 100.0, 2) if partial_hit_count else 0.0,
            "runner_breakeven_stop_count": runner_breakeven_stop_count,
            "target_before_timeout_count": target_before_timeout_count,
            "target_before_timeout_rate": round((target_before_timeout_count / len(closed_trades)) * 100.0, 2) if closed_trades else 0.0,
            "exit_reason_breakdown": normalized_exit_breakdown,
            "target_hit_count": target_hit_count,
            "stop_loss_count": stop_loss_count,
            "time_stop_count": time_stop_count,
            "acceptance_exit_count": acceptance_exit_count,
            "partial_exit_count": partial_exit_count,
            "avg_realized_r_after_partial": partial_summary["avg_realized_r"],
            "avg_realized_r_without_partial": no_partial_summary["avg_realized_r"],
            "avg_runner_realized_r": runner_summary["avg_realized_r"],
            "avg_loss_r": summary["avg_loss_r"],
            "avg_bars_to_partial": round(sum(bars_to_partial_values) / len(bars_to_partial_values), 2) if bars_to_partial_values else 0.0,
            "avg_bars_to_final": round(sum(bars_to_final_values) / len(bars_to_final_values), 2) if bars_to_final_values else 0.0,
            "avg_bars_to_time_stop": round(sum(bars_to_time_stop_values) / len(bars_to_time_stop_values), 2) if bars_to_time_stop_values else 0.0,
            "dimensions": dimensions,
        }
    )
    return summary


def summarize_run(spec: RunSpec) -> dict[str, Any]:
    metrics = parse_report_metrics(spec.report_path)
    telemetry = summarize_telemetry(spec.telemetry_path)
    meta = load_meta(spec.report_path)
    return {
        "slug": spec.slug,
        "window": spec.window,
        "partial_level": spec.partial_key,
        "runner_target": spec.runner_key,
        "order_mode": spec.order_key,
        "hold_bars": spec.hold_bars,
        "preset_path": str(spec.preset_path),
        "config_path": str(spec.config_path),
        "report_path": str(spec.report_path),
        "telemetry_path": str(spec.telemetry_path),
        "report_metrics": {
            "net_profit": metrics.get("total_net_profit", 0.0),
            "profit_factor": metrics.get("profit_factor", 0.0),
            "trades": metrics.get("total_trades", 0),
            "win_rate": metrics.get("win_rate_percent", 0.0),
            "max_drawdown_percent": max(
                metrics.get("maximal_drawdown_percent", 0.0) or 0.0,
                metrics.get("relative_drawdown_percent", 0.0) or 0.0,
            ),
            "expected_payoff": metrics.get("expected_payoff", 0.0),
            "average_win": metrics.get("average_profit_trade", 0.0),
            "average_loss": metrics.get("average_loss_trade", 0.0),
        },
        "telemetry": telemetry,
        "report_meta": meta,
    }


def build_matrix_specs() -> list[RunSpec]:
    specs: list[RunSpec] = []
    ordinal = 1
    for window in ("train", "oos", "actual"):
        for partial_key, partial_mode in PARTIAL_LEVELS:
            for runner_key, runner_mode in RUNNER_TARGETS:
                for order_key, order_mode in ORDER_MODES:
                    for hold_bars in HOLD_BARS:
                        specs.append(
                            build_run_spec(
                                window=window,
                                partial_key=partial_key,
                                partial_mode=partial_mode,
                                runner_key=runner_key,
                                runner_mode=runner_mode,
                                order_key=order_key,
                                order_mode=order_mode,
                                hold_bars=hold_bars,
                                ordinal=ordinal,
                            )
                        )
                        ordinal += 1
    return specs


def sort_runs_for_display(runs: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(
        runs,
        key=lambda item: (
            item["report_metrics"]["profit_factor"],
            item["report_metrics"]["net_profit"],
            item["report_metrics"]["trades"],
            item["telemetry"]["avg_realized_r"],
        ),
        reverse=True,
    )


def write_results(results: list[dict[str, Any]]) -> None:
    payload = {
        "generated_at": Path(__file__).stat().st_mtime,
        "matrix": {
            "windows": list(WINDOWS.keys()),
            "partial_levels": [key for key, _ in PARTIAL_LEVELS],
            "runner_targets": [key for key, _ in RUNNER_TARGETS],
            "order_modes": [key for key, _ in ORDER_MODES],
            "hold_bars": list(HOLD_BARS),
        },
        "results": results,
    }
    results_path = RESULTS_ROOT / "results.json"
    results_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    lines: list[str] = [
        "# USDJPY Trend Continuation Partial/Runner Diagnostics",
        "",
        f"- total runs: {len(results)}",
        "- fixed inputs: `ENTRY_ON_HIGHER_LOW_BREAK only`, `M15 x M5`, `Tier A strict`, `STOP_PULLBACK_LOW`, `TARGET_HYBRID_PARTIAL`",
        "",
    ]
    for window in ("train", "oos", "actual"):
        lines.append(f"## {window.upper()}")
        lines.append("")
        lines.append("| slug | net | pf | trades | partial hit % | be move % | runner hit % | avg R | avg R after partial | avg runner R | avg loss R |")
        lines.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
        for item in sort_runs_for_display([run for run in results if run["window"] == window]):
            telemetry = item["telemetry"]
            metrics = item["report_metrics"]
            lines.append(
                f"| {item['slug']} | {metrics['net_profit']:.2f} | {metrics['profit_factor']:.2f} | {metrics['trades']} | "
                f"{telemetry['partial_hit_rate']:.2f} | {telemetry['be_move_rate']:.2f} | {telemetry['runner_target_hit_rate']:.2f} | "
                f"{telemetry['avg_realized_r']:.4f} | {telemetry['avg_realized_r_after_partial']:.4f} | "
                f"{telemetry['avg_runner_realized_r']:.4f} | {telemetry['avg_loss_r']:.4f} |"
            )
        lines.append("")

    (RESULTS_ROOT / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    args = parse_args()
    ensure_dirs()

    specs = build_matrix_specs()
    if args.max_runs > 0:
        specs = specs[: args.max_runs]

    results: list[dict[str, Any]] = []
    for spec in specs:
        generate_run_files(spec)
        run_backtest(spec, args.terminal_path, args.timeout_seconds, args.reuse_existing)
        results.append(summarize_run(spec))

    write_results(results)


if __name__ == "__main__":
    main()
