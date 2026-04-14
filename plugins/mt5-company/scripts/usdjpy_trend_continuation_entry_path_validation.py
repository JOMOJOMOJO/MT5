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
from datetime import datetime
from pathlib import Path
from typing import Any


SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[3]
COMMON_FILES_ROOT = Path(os.environ["APPDATA"]) / "MetaQuotes" / "Terminal" / "Common" / "Files"
SWEEP_ROOT = REPO_ROOT / "reports" / "backtest" / "sweeps" / "2026-04-14-usdjpy-continuation-entry-path-validation"
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

ENTRY_PATHS: list[tuple[str, int]] = [
    ("pullback_reclaim", 1),
    ("higher_low_break", 2),
    ("retest_continuation", 3),
]

TIMEFRAME_PAIRS: list[tuple[str, int, int, str]] = [
    ("m15_m5", 15, 5, "M5"),
    ("m30_m5", 30, 5, "M5"),
    ("m15_m1", 15, 1, "M1"),
    ("h1_m5", 60, 5, "M5"),
]

TARGET_MODES: list[tuple[str, int]] = [
    ("prior_swing", 0),
    ("fixed_r", 1),
    ("fib", 2),
]

STOP_BASIS: list[tuple[str, int]] = [
    ("stop_pullback_low", 0),
    ("stop_higher_low", 1),
]

PIP_SIZE_PRICE = 0.01


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
    entry_path_key: str
    entry_path_mode: int
    timeframe_key: str
    trend_tf: int
    signal_tf: int
    tester_period: str
    target_key: str
    target_mode: int
    stop_key: str
    stop_mode: int
    preset_path: Path
    config_path: Path
    report_path: Path
    telemetry_name: str
    telemetry_path: Path
    magic_number: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the USDJPY continuation entry-path isolation matrix.")
    parser.add_argument("--terminal-path", default=str(TERMINAL_DEFAULT))
    parser.add_argument("--timeout-seconds", type=int, default=900)
    parser.add_argument("--reuse-existing", action="store_true")
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
    return f"MQL5\\Experts\\dev\\reports\\backtest\\sweeps\\2026-04-14-usdjpy-continuation-entry-path-validation\\reports\\{slug}.htm"


def write_config(spec: RunSpec) -> None:
    from_date, to_date = WINDOWS[spec.window]
    relative_preset = spec.preset_path.relative_to(REPO_ROOT).as_posix().replace("/", "\\")
    config_lines = [
        "; auto-generated trend continuation path validation config",
        "",
        "[Tester]",
        f"Expert={EXPERT_PATH}",
        f"PresetSource={relative_preset}",
        f"PresetName={spec.preset_path.name}",
        "Symbol=USDJPY",
        f"Period={spec.tester_period}",
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
    entry_path_key: str,
    entry_path_mode: int,
    timeframe_key: str,
    trend_tf: int,
    signal_tf: int,
    tester_period: str,
    target_key: str,
    target_mode: int,
    stop_key: str,
    stop_mode: int,
    ordinal: int,
) -> RunSpec:
    slug = f"{window}-{entry_path_key}-{timeframe_key}-{target_key}-{stop_key}"
    telemetry_name = f"mt5_company_{slug}.csv"
    return RunSpec(
        slug=slug,
        window=window,
        entry_path_key=entry_path_key,
        entry_path_mode=entry_path_mode,
        timeframe_key=timeframe_key,
        trend_tf=trend_tf,
        signal_tf=signal_tf,
        tester_period=tester_period,
        target_key=target_key,
        target_mode=target_mode,
        stop_key=stop_key,
        stop_mode=stop_mode,
        preset_path=PRESETS_ROOT / f"{slug}.set",
        config_path=CONFIGS_ROOT / f"{slug}.ini",
        report_path=REPORTS_ROOT / f"{slug}.htm",
        telemetry_name=telemetry_name,
        telemetry_path=COMMON_FILES_ROOT / telemetry_name,
        magic_number=2026041400 + ordinal,
    )


def generate_run_files(spec: RunSpec) -> None:
    overrides = {
        "InpTrendTimeframe": spec.trend_tf,
        "InpSignalTimeframe": spec.signal_tf,
        "InpTierMode": 0,
        "InpEntryPathMode": spec.entry_path_mode,
        "InpStopBasisMode": spec.stop_mode,
        "InpTargetMode": spec.target_mode,
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
        add_trade_to_rollup(groups[bucket], float(trade.get("net_profit", 0.0)), trade.get("realized_r_multiple"))
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
                "exit_reason_breakdown": {},
                "target_hit_count": 0,
                "stop_loss_count": 0,
                "time_stop_count": 0,
                "acceptance_exit_count": 0,
                "partial_exit_count": 0,
                "partial_exit_trade_count": 0,
                "dimensions": {},
            }
        )
        return empty

    positions: dict[str, dict[str, Any]] = {}

    for row in rows:
        event_type = row.get("event_type", "")
        position_id = row.get("position_id", "") or "0"
        trade = positions.setdefault(
            position_id,
            {
                "position_id": position_id,
                "entry_type": row.get("entry_type", ""),
                "phase": row.get("phase", ""),
                "wave_label": row.get("wave_label", ""),
                "context_bucket": row.get("context_bucket", ""),
                "fib_depth_bucket": row.get("fib_depth_bucket", ""),
                "ltf_state": row.get("ltf_state", ""),
                "setup_type": row.get("setup_type", ""),
                "stop_basis": row.get("stop_basis", ""),
                "target_type": row.get("target_type", ""),
                "volatility_bucket": row.get("volatility_bucket", ""),
                "hour_bucket": row.get("hour", ""),
                "tier": row.get("tier", ""),
                "entry_price": 0.0,
                "exit_price": 0.0,
                "stop_distance_pips": 0.0,
                "net_profit": 0.0,
                "partial_exit_count": 0,
                "final_reason": "",
                "final_outcome": "",
                "has_exit": False,
                "realized_r_multiple": None,
            },
        )

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
            trade["volatility_bucket"] = row.get("volatility_bucket", trade["volatility_bucket"])
            trade["hour_bucket"] = row.get("hour", trade["hour_bucket"])
            trade["tier"] = row.get("tier", trade["tier"])
            trade["entry_price"] = parse_float(row.get("price"))
            trade["stop_distance_pips"] = parse_float(row.get("stop_distance_pips"))
            continue

        if event_type in {"partial_exit", "exit"}:
            trade["net_profit"] += parse_float(row.get("net_profit"))
            if event_type == "partial_exit":
                trade["partial_exit_count"] += 1
            else:
                trade["exit_price"] = parse_float(row.get("price"))
                trade["final_reason"] = row.get("reason", "")
                trade["final_outcome"] = row.get("outcome", "")
                trade["has_exit"] = True

    closed_trades = [trade for trade in positions.values() if trade["has_exit"]]
    summary_rollup = init_rollup()
    exit_reason_breakdown: dict[str, dict[str, Any]] = defaultdict(lambda: {"count": 0, "net_profit": 0.0})
    target_hit_count = 0
    stop_loss_count = 0
    time_stop_count = 0
    acceptance_exit_count = 0
    partial_exit_count = 0
    partial_exit_trade_count = 0

    for trade in closed_trades:
        realized_r = None
        if trade["partial_exit_count"] == 0 and trade["entry_price"] > 0.0 and trade["exit_price"] > 0.0 and trade["stop_distance_pips"] > 0.0:
            risk_price = trade["stop_distance_pips"] * PIP_SIZE_PRICE
            if risk_price > 0.0:
                realized_r = (trade["exit_price"] - trade["entry_price"]) / risk_price
                trade["realized_r_multiple"] = realized_r

        add_trade_to_rollup(summary_rollup, float(trade["net_profit"]), realized_r)

        final_reason = trade["final_reason"] or "unknown"
        exit_reason_breakdown[final_reason]["count"] += 1
        exit_reason_breakdown[final_reason]["net_profit"] += float(trade["net_profit"])
        partial_exit_count += int(trade["partial_exit_count"])
        if trade["partial_exit_count"] > 0:
            partial_exit_trade_count += 1
        if final_reason == "target":
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
        "target_type",
        "stop_basis",
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
    summary.update(
        {
            "rows": len(rows),
            "closed_trades": len(closed_trades),
            "exit_reason_breakdown": normalized_exit_breakdown,
            "target_hit_count": target_hit_count,
            "stop_loss_count": stop_loss_count,
            "time_stop_count": time_stop_count,
            "acceptance_exit_count": acceptance_exit_count,
            "partial_exit_count": partial_exit_count,
            "partial_exit_trade_count": partial_exit_trade_count,
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
        "entry_path": spec.entry_path_key,
        "timeframe_pair": spec.timeframe_key,
        "trend_tf": spec.trend_tf,
        "signal_tf": spec.signal_tf,
        "target_mode": spec.target_key,
        "stop_basis": spec.stop_key,
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
        for entry_path_key, entry_path_mode in ENTRY_PATHS:
            for timeframe_key, trend_tf, signal_tf, tester_period in TIMEFRAME_PAIRS:
                for target_key, target_mode in TARGET_MODES:
                    for stop_key, stop_mode in STOP_BASIS:
                        specs.append(
                            build_run_spec(
                                window=window,
                                entry_path_key=entry_path_key,
                                entry_path_mode=entry_path_mode,
                                timeframe_key=timeframe_key,
                                trend_tf=trend_tf,
                                signal_tf=signal_tf,
                                tester_period=tester_period,
                                target_key=target_key,
                                target_mode=target_mode,
                                stop_key=stop_key,
                                stop_mode=stop_mode,
                                ordinal=ordinal,
                            )
                        )
                        ordinal += 1
    return specs


def execute_specs(specs: list[RunSpec], terminal_path: str, timeout_seconds: int, reuse_existing: bool) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    total = len(specs)
    for index, spec in enumerate(specs, start=1):
        print(f"[{index}/{total}] {spec.slug}", flush=True)
        generate_run_files(spec)
        run_backtest(spec, terminal_path, timeout_seconds, reuse_existing)
        results.append(summarize_run(spec))
    return results


def combine_rollups(items: list[dict[str, Any]]) -> dict[str, Any]:
    combined = init_rollup()
    for item in items:
        combined["trades"] += item.get("trades", 0)
        combined["wins"] += item.get("wins", 0)
        combined["losses"] += item.get("losses", 0)
        combined["gross_profit"] += item.get("gross_profit", 0.0)
        combined["gross_loss_abs"] += item.get("gross_loss_abs", 0.0)
        combined["net_profit"] += item.get("net_profit", 0.0)
        combined["sum_realized_r"] += item.get("sum_realized_r", 0.0)
        combined["realized_r_count"] += item.get("realized_r_count", 0)
        combined["sum_win_r"] += item.get("sum_win_r", 0.0)
        combined["win_r_count"] += item.get("win_r_count", 0)
        combined["sum_loss_r"] += item.get("sum_loss_r", 0.0)
        combined["loss_r_count"] += item.get("loss_r_count", 0)
    return finalize_rollup(combined)


def aggregate_dimension_across_runs(rows: list[dict[str, Any]], window: str) -> dict[str, Any]:
    combined: dict[str, dict[str, list[dict[str, Any]]]] = defaultdict(lambda: defaultdict(list))
    for row in rows:
        if row["window"] != window:
            continue
        dimensions = row["telemetry"]["dimensions"]
        for dimension_name, buckets in dimensions.items():
            for bucket_name, bucket_values in buckets.items():
                combined[dimension_name][bucket_name].append(bucket_values)

    output: dict[str, Any] = {}
    for dimension_name, buckets in combined.items():
        output[dimension_name] = dict(
            sorted(
                (
                    (bucket_name, combine_rollups(bucket_values))
                    for bucket_name, bucket_values in buckets.items()
                ),
                key=lambda item: (item[1]["profit_factor"], item[1]["net_profit"], item[1]["trades"]),
                reverse=True,
            )
        )
    return output


def aggregate_exit_breakdown(rows: list[dict[str, Any]], window: str, entry_path: str | None = None) -> dict[str, Any]:
    totals: dict[str, dict[str, Any]] = defaultdict(lambda: {"count": 0, "net_profit": 0.0})
    for row in rows:
        if row["window"] != window:
            continue
        if entry_path and row["entry_path"] != entry_path:
            continue
        for reason, values in row["telemetry"]["exit_reason_breakdown"].items():
            totals[reason]["count"] += values["count"]
            totals[reason]["net_profit"] += values["net_profit"]
    return {
        reason: {"count": values["count"], "net_profit": round(values["net_profit"], 4)}
        for reason, values in sorted(totals.items(), key=lambda item: item[1]["count"], reverse=True)
    }


def aggregate_path_summaries(rows: list[dict[str, Any]], window: str) -> dict[str, Any]:
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        if row["window"] == window:
            grouped[row["entry_path"]].append(row)

    output: dict[str, Any] = {}
    for entry_path, items in grouped.items():
        telemetry_rollups = [item["telemetry"] for item in items]
        combined = combine_rollups(telemetry_rollups)
        combined["runs"] = len(items)
        combined["target_hit_count"] = sum(item["telemetry"]["target_hit_count"] for item in items)
        combined["stop_loss_count"] = sum(item["telemetry"]["stop_loss_count"] for item in items)
        combined["time_stop_count"] = sum(item["telemetry"]["time_stop_count"] for item in items)
        combined["acceptance_exit_count"] = sum(item["telemetry"]["acceptance_exit_count"] for item in items)
        combined["partial_exit_count"] = sum(item["telemetry"]["partial_exit_count"] for item in items)
        combined["partial_exit_trade_count"] = sum(item["telemetry"]["partial_exit_trade_count"] for item in items)
        combined["exit_reason_breakdown"] = aggregate_exit_breakdown(rows, window, entry_path)
        best_actual = sorted(
            items,
            key=lambda item: (
                item["report_metrics"]["profit_factor"],
                item["report_metrics"]["net_profit"],
                item["report_metrics"]["trades"],
            ),
            reverse=True,
        )[:5]
        combined["best_runs"] = [
            {
                "timeframe_pair": item["timeframe_pair"],
                "target_mode": item["target_mode"],
                "stop_basis": item["stop_basis"],
                "profit_factor": item["report_metrics"]["profit_factor"],
                "net_profit": item["report_metrics"]["net_profit"],
                "trades": item["report_metrics"]["trades"],
                "expected_payoff": item["report_metrics"]["expected_payoff"],
                "avg_win": item["report_metrics"]["average_win"],
                "avg_loss": item["report_metrics"]["average_loss"],
                "avg_realized_r": item["telemetry"]["avg_realized_r"],
            }
            for item in best_actual
        ]
        output[entry_path] = combined
    return output


def best_rows(rows: list[dict[str, Any]], window: str) -> list[dict[str, Any]]:
    subset = [row for row in rows if row["window"] == window]
    return sorted(
        subset,
        key=lambda item: (
            item["report_metrics"]["profit_factor"],
            item["report_metrics"]["net_profit"],
            item["report_metrics"]["trades"],
        ),
        reverse=True,
    )


def build_markdown(results: dict[str, Any]) -> str:
    lines = [
        "# USDJPY Continuation Entry Path Validation",
        "",
        "## Matrix",
        "",
        "- entry paths: pullback_reclaim / higher_low_break / retest_continuation",
        "- timeframe pairs: M15xM5 / M30xM5 / M15xM1 / H1xM5",
        "- target modes: prior_swing / fixed_r / fib",
        "- stop basis: stop_pullback_low / stop_higher_low",
        "- tier: Tier A strict only",
        "",
        "## Path Highlights",
        "",
    ]

    for window in ("train", "oos", "actual"):
        lines.append(f"### {window}")
        for entry_path, summary in results["path_summaries"][window].items():
            lines.append(
                f"- `{entry_path}` PF=`{summary['profit_factor']}` trades=`{summary['trades']}` net=`{summary['net_profit']}` avgR=`{summary['avg_realized_r']}`"
            )
            for run in summary["best_runs"][:3]:
                lines.append(
                    f"  - best `{run['timeframe_pair']}` `{run['target_mode']}` `{run['stop_basis']}` PF=`{run['profit_factor']}` trades=`{run['trades']}` net=`{run['net_profit']}`"
                )
        lines.append("")

    lines.extend(["## Telemetry Buckets", ""])
    for window in ("train", "oos", "actual"):
        lines.append(f"### {window}")
        dims = results["telemetry_aggregate"][window]
        for dimension_name in ("entry_type", "fib_depth_bucket", "phase", "final_reason"):
            lines.append(f"- {dimension_name}:")
            buckets = dims.get(dimension_name, {})
            if not buckets:
                lines.append("  - no data")
                continue
            for bucket_name, bucket in list(buckets.items())[:6]:
                lines.append(
                    f"  - {bucket_name}: PF={bucket['profit_factor']} trades={bucket['trades']} net={bucket['net_profit']} avgR={bucket['avg_realized_r']}"
                )
        lines.append("")

    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    ensure_dirs()

    specs = build_matrix_specs()
    results = execute_specs(specs, args.terminal_path, args.timeout_seconds, args.reuse_existing)

    payload = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "terminal_path": args.terminal_path,
        "matrix": [asdict(spec) for spec in specs],
        "all_runs": results,
        "path_summaries": {
            window: aggregate_path_summaries(results, window)
            for window in ("train", "oos", "actual")
        },
        "telemetry_aggregate": {
            window: aggregate_dimension_across_runs(results, window)
            for window in ("train", "oos", "actual")
        },
        "highlights": {
            window: best_rows(results, window)[:18]
            for window in ("train", "oos", "actual")
        },
        "exit_reason_aggregate": {
            window: aggregate_exit_breakdown(results, window)
            for window in ("train", "oos", "actual")
        },
    }

    json_path = RESULTS_ROOT / "results.json"
    markdown_path = RESULTS_ROOT / "summary.md"
    json_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False, default=str), encoding="utf-8")
    markdown_path.write_text(build_markdown(payload), encoding="utf-8")

    print(f"Results JSON: {json_path}")
    print(f"Results MD  : {markdown_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
