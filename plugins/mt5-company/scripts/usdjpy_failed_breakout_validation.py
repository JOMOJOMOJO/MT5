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
SWEEP_ROOT = REPO_ROOT / "reports" / "backtest" / "sweeps" / "2026-04-14-usdjpy-failed-breakout-validation"
RESULTS_ROOT = SWEEP_ROOT / "results"
CONFIGS_ROOT = SWEEP_ROOT / "configs"
PRESETS_ROOT = SWEEP_ROOT / "presets"
REPORTS_ROOT = SWEEP_ROOT / "reports"
BASE_PRESET_A = REPO_ROOT / "reports" / "presets" / "usdjpy_20260413_failed_breakout_short_scaffold-tierA.set"
BASE_PRESET_AB = REPO_ROOT / "reports" / "presets" / "usdjpy_20260413_failed_breakout_short_scaffold-tierAB.set"
EXPERT_PATH = "dev\\mql\\Experts\\usdjpy_20260413_failed_breakout_short_scaffold.ex5"
TERMINAL_DEFAULT = Path(r"C:\Program Files\XMTrading MT5\terminal64.exe")
BACKTEST_SCRIPT = REPO_ROOT / "scripts" / "backtest.ps1"
REPORT_TOOL_PATH = REPO_ROOT / "plugins" / "mt5-company" / "scripts" / "mt5_backtest_tools.py"

WINDOWS = {
    "train": ("2025.04.01", "2025.12.31"),
    "oos": ("2026.01.01", "2026.04.01"),
    "actual": ("2024.11.26", "2026.04.01"),
}

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
    ("hybrid_partial", 3),
]

TIER_MODES: dict[str, int] = {
    "tier_a": 0,
    "tier_ab": 1,
}

STOP_BASIS: dict[str, int] = {
    "stop_sweep_high": 0,
    "stop_failure_pivot": 1,
}

MIN_SCREEN_TRADES = 20
FINALIST_COUNT = 2


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
    stage: str
    window: str
    timeframe_key: str
    trend_tf: int
    signal_tf: int
    tester_period: str
    target_key: str
    target_mode: int
    tier_key: str
    tier_mode: int
    stop_key: str
    stop_mode: int
    base_preset: Path
    preset_path: Path
    config_path: Path
    report_path: Path
    telemetry_name: str
    telemetry_path: Path
    magic_number: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run and analyze the USDJPY failed-breakout validation matrix.")
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
    lines: list[str] = [f"; auto-generated from {base_preset.name}"]
    for key, raw_value in base_values.items():
        if key in overrides:
            lines.append(f"{key}={format_preset_value(raw_value, overrides[key])}")
        else:
            lines.append(f"{key}={raw_value}")
    target_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build_report_relative_path(slug: str) -> str:
    return f"MQL5\\Experts\\dev\\reports\\backtest\\sweeps\\2026-04-14-usdjpy-failed-breakout-validation\\reports\\{slug}.htm"


def write_config(spec: RunSpec) -> None:
    from_date, to_date = WINDOWS[spec.window]
    relative_preset = spec.preset_path.relative_to(REPO_ROOT).as_posix().replace("/", "\\")
    config_lines = [
        "; auto-generated failed-breakout validation config",
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
    stage: str,
    window: str,
    timeframe_key: str,
    trend_tf: int,
    signal_tf: int,
    tester_period: str,
    target_key: str,
    target_mode: int,
    tier_key: str,
    stop_key: str,
    ordinal: int,
) -> RunSpec:
    tier_mode = TIER_MODES[tier_key]
    stop_mode = STOP_BASIS[stop_key]
    slug = f"{stage}-{window}-{timeframe_key}-{target_key}-{tier_key}-{stop_key}"
    telemetry_name = f"mt5_company_{slug}.csv"
    base_preset = BASE_PRESET_A if tier_key == "tier_a" else BASE_PRESET_AB
    return RunSpec(
        slug=slug,
        stage=stage,
        window=window,
        timeframe_key=timeframe_key,
        trend_tf=trend_tf,
        signal_tf=signal_tf,
        tester_period=tester_period,
        target_key=target_key,
        target_mode=target_mode,
        tier_key=tier_key,
        tier_mode=tier_mode,
        stop_key=stop_key,
        stop_mode=stop_mode,
        base_preset=base_preset,
        preset_path=PRESETS_ROOT / f"{slug}.set",
        config_path=CONFIGS_ROOT / f"{slug}.ini",
        report_path=REPORTS_ROOT / f"{slug}.htm",
        telemetry_name=telemetry_name,
        telemetry_path=COMMON_FILES_ROOT / telemetry_name,
        magic_number=202604130 + ordinal,
    )


def generate_run_files(spec: RunSpec) -> None:
    overrides = {
        "InpTrendTimeframe": spec.trend_tf,
        "InpSignalTimeframe": spec.signal_tf,
        "InpTierMode": spec.tier_mode,
        "InpStopBasisMode": spec.stop_mode,
        "InpTargetMode": spec.target_mode,
        "InpTelemetryFileName": spec.telemetry_name,
        "InpMagicNumber": spec.magic_number,
    }
    write_preset(spec.base_preset, overrides, spec.preset_path)
    write_config(spec)


def run_backtest(spec: RunSpec, terminal_path: str, timeout_seconds: int, reuse_existing: bool) -> None:
    if reuse_existing and spec.report_path.exists() and spec.report_path.with_name(spec.report_path.name + ".meta.json").exists():
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
        return 0
    return int(float(value))


def aggregate_dimension(trades: list[dict[str, Any]], key: str) -> dict[str, Any]:
    groups: dict[str, dict[str, Any]] = defaultdict(lambda: {
        "trades": 0,
        "wins": 0,
        "losses": 0,
        "gross_profit": 0.0,
        "gross_loss": 0.0,
        "net_profit": 0.0,
        "avg_profit": 0.0,
    })

    for trade in trades:
        bucket = str(trade.get(key) or "unknown")
        group = groups[bucket]
        profit = float(trade.get("net_profit", 0.0))
        group["trades"] += 1
        group["net_profit"] += profit
        if profit > 0.0:
            group["wins"] += 1
            group["gross_profit"] += profit
        elif profit < 0.0:
            group["losses"] += 1
            group["gross_loss"] += abs(profit)

    for bucket, group in groups.items():
        trades_count = group["trades"]
        gross_loss = group["gross_loss"]
        group["profit_factor"] = round(group["gross_profit"] / gross_loss, 4) if gross_loss > 0.0 else 0.0
        group["win_rate"] = round((group["wins"] / trades_count) * 100.0, 2) if trades_count else 0.0
        group["avg_profit"] = round(group["net_profit"] / trades_count, 4) if trades_count else 0.0
        group["net_profit"] = round(group["net_profit"], 4)
        group["gross_profit"] = round(group["gross_profit"], 4)
        group["gross_loss"] = round(-group["gross_loss"], 4)

    return dict(sorted(groups.items(), key=lambda item: (item[1]["profit_factor"], item[1]["net_profit"], item[1]["trades"]), reverse=True))


def summarize_telemetry(path: Path) -> dict[str, Any]:
    rows = read_telemetry_rows(path)
    if not rows:
        return {
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

    positions: dict[str, dict[str, Any]] = {}

    for row in rows:
        event_type = row.get("event_type", "")
        position_id = row.get("position_id", "") or "0"
        trade = positions.setdefault(position_id, {
            "position_id": position_id,
            "entry_type": row.get("entry_type", ""),
            "phase": row.get("phase", ""),
            "wave_label": row.get("wave_label", ""),
            "context_bucket": row.get("context_bucket", ""),
            "fib_depth_bucket": row.get("fib_depth_bucket", ""),
            "ltf_state": row.get("ltf_state", ""),
            "failure_type": row.get("failure_type", ""),
            "stop_basis": row.get("stop_basis", ""),
            "target_type": row.get("target_type", ""),
            "volatility_bucket": row.get("volatility_bucket", ""),
            "hour_bucket": row.get("hour", ""),
            "tier": row.get("tier", ""),
            "net_profit": 0.0,
            "partial_exit_count": 0,
            "final_reason": "",
            "final_outcome": "",
            "has_exit": False,
        })

        if event_type == "entry":
            trade["entry_type"] = row.get("entry_type", trade["entry_type"])
            trade["phase"] = row.get("phase", trade["phase"])
            trade["wave_label"] = row.get("wave_label", trade["wave_label"])
            trade["context_bucket"] = row.get("context_bucket", trade["context_bucket"])
            trade["fib_depth_bucket"] = row.get("fib_depth_bucket", trade["fib_depth_bucket"])
            trade["ltf_state"] = row.get("ltf_state", trade["ltf_state"])
            trade["failure_type"] = row.get("failure_type", trade["failure_type"])
            trade["stop_basis"] = row.get("stop_basis", trade["stop_basis"])
            trade["target_type"] = row.get("target_type", trade["target_type"])
            trade["volatility_bucket"] = row.get("volatility_bucket", trade["volatility_bucket"])
            trade["hour_bucket"] = row.get("hour", trade["hour_bucket"])
            trade["tier"] = row.get("tier", trade["tier"])
            continue

        if event_type in {"partial_exit", "exit"}:
            profit = parse_float(row.get("net_profit"))
            trade["net_profit"] += profit
            if event_type == "partial_exit":
                trade["partial_exit_count"] += 1
            else:
                trade["final_reason"] = row.get("reason", "")
                trade["final_outcome"] = row.get("outcome", "")
                trade["has_exit"] = True

    closed_trades = [trade for trade in positions.values() if trade["has_exit"]]
    exit_reason_breakdown: dict[str, dict[str, Any]] = defaultdict(lambda: {"count": 0, "net_profit": 0.0})
    target_hit_count = 0
    stop_loss_count = 0
    time_stop_count = 0
    acceptance_exit_count = 0
    partial_exit_count = 0
    partial_exit_trade_count = 0

    for trade in closed_trades:
        final_reason = trade["final_reason"] or "unknown"
        exit_reason_breakdown[final_reason]["count"] += 1
        exit_reason_breakdown[final_reason]["net_profit"] += trade["net_profit"]
        partial_exit_count += trade["partial_exit_count"]
        if trade["partial_exit_count"] > 0:
            partial_exit_trade_count += 1
        if final_reason == "target":
            target_hit_count += 1
        elif final_reason == "stop_loss":
            stop_loss_count += 1
        elif final_reason == "time_stop":
            time_stop_count += 1
        elif final_reason == "acceptance_back_above":
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
        reason: {
            "count": values["count"],
            "net_profit": round(values["net_profit"], 4),
        }
        for reason, values in sorted(exit_reason_breakdown.items(), key=lambda item: item[1]["count"], reverse=True)
    }

    return {
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


def summarize_run(spec: RunSpec) -> dict[str, Any]:
    metrics = parse_report_metrics(spec.report_path)
    telemetry = summarize_telemetry(spec.telemetry_path)
    meta = load_meta(spec.report_path)
    return {
        "slug": spec.slug,
        "stage": spec.stage,
        "window": spec.window,
        "timeframe_pair": spec.timeframe_key,
        "trend_tf": spec.trend_tf,
        "signal_tf": spec.signal_tf,
        "target_mode": spec.target_key,
        "tier_mode": spec.tier_key,
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
        "meta": meta,
    }


def screening_specs() -> list[RunSpec]:
    specs: list[RunSpec] = []
    ordinal = 1
    for timeframe_key, trend_tf, signal_tf, tester_period in TIMEFRAME_PAIRS:
        for target_key, target_mode in TARGET_MODES:
            spec = build_run_spec(
                stage="screen",
                window="train",
                timeframe_key=timeframe_key,
                trend_tf=trend_tf,
                signal_tf=signal_tf,
                tester_period=tester_period,
                target_key=target_key,
                target_mode=target_mode,
                tier_key="tier_a",
                stop_key="stop_sweep_high",
                ordinal=ordinal,
            )
            specs.append(spec)
            ordinal += 1
    return specs


def pick_timeframe_winners(screen_results: list[dict[str, Any]]) -> list[tuple[str, str]]:
    winners: list[tuple[str, str]] = []
    by_timeframe: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in screen_results:
        by_timeframe[row["timeframe_pair"]].append(row)

    for timeframe_key, rows in by_timeframe.items():
        ranked = sorted(
            rows,
            key=lambda item: (
                item["report_metrics"]["profit_factor"],
                item["report_metrics"]["trades"] >= MIN_SCREEN_TRADES,
                item["report_metrics"]["trades"],
                item["report_metrics"]["expected_payoff"],
                item["report_metrics"]["net_profit"],
            ),
            reverse=True,
        )
        best = ranked[0]
        winners.append((timeframe_key, best["target_mode"]))
    return winners


def validation_specs(finalists: list[tuple[str, str]]) -> list[RunSpec]:
    specs: list[RunSpec] = []
    ordinal = 100
    timeframe_lookup = {item[0]: item for item in TIMEFRAME_PAIRS}
    target_lookup = {item[0]: item for item in TARGET_MODES}

    for timeframe_key, target_key in finalists:
        _, trend_tf, signal_tf, tester_period = timeframe_lookup[timeframe_key]
        _, target_mode = target_lookup[target_key]
        for window in ("train", "oos", "actual"):
            specs.append(
                build_run_spec(
                    stage="validate",
                    window=window,
                    timeframe_key=timeframe_key,
                    trend_tf=trend_tf,
                    signal_tf=signal_tf,
                    tester_period=tester_period,
                    target_key=target_key,
                    target_mode=target_mode,
                    tier_key="tier_a",
                    stop_key="stop_sweep_high",
                    ordinal=ordinal,
                )
            )
            ordinal += 1
    return specs


def tierab_matrix_specs() -> list[RunSpec]:
    specs: list[RunSpec] = []
    ordinal = 200
    for timeframe_key, trend_tf, signal_tf, tester_period in TIMEFRAME_PAIRS:
        for target_key, target_mode in TARGET_MODES:
            for window in ("train", "oos", "actual"):
                specs.append(
                    build_run_spec(
                        stage="tierab",
                        window=window,
                        timeframe_key=timeframe_key,
                        trend_tf=trend_tf,
                        signal_tf=signal_tf,
                        tester_period=tester_period,
                        target_key=target_key,
                        target_mode=target_mode,
                        tier_key="tier_ab",
                        stop_key="stop_sweep_high",
                        ordinal=ordinal,
                    )
                )
                ordinal += 1
    return specs


def select_finalists(validation_results: list[dict[str, Any]]) -> list[tuple[str, str]]:
    actual_rows = [row for row in validation_results if row["window"] == "actual"]
    ranked = sorted(
        actual_rows,
        key=lambda item: (
            item["report_metrics"]["profit_factor"],
            item["report_metrics"]["net_profit"],
            item["report_metrics"]["trades"],
        ),
        reverse=True,
    )
    picked: list[tuple[str, str]] = []
    for row in ranked[:FINALIST_COUNT]:
        picked.append((row["timeframe_pair"], row["target_mode"]))
    if picked:
        return picked

    fallback = sorted(
        validation_results,
        key=lambda item: (
            item["report_metrics"]["profit_factor"],
            item["report_metrics"]["net_profit"],
            item["report_metrics"]["trades"],
        ),
        reverse=True,
    )
    for row in fallback[:FINALIST_COUNT]:
        picked.append((row["timeframe_pair"], row["target_mode"]))
    return picked


def comparison_specs(finalists: list[tuple[str, str]]) -> list[RunSpec]:
    specs: list[RunSpec] = []
    ordinal = 300
    timeframe_lookup = {item[0]: item for item in TIMEFRAME_PAIRS}
    target_lookup = {item[0]: item for item in TARGET_MODES}
    for timeframe_key, target_key in finalists:
        _, trend_tf, signal_tf, tester_period = timeframe_lookup[timeframe_key]
        _, target_mode = target_lookup[target_key]
        for tier_key, stop_key in (
            ("tier_a", "stop_failure_pivot"),
            ("tier_ab", "stop_sweep_high"),
            ("tier_ab", "stop_failure_pivot"),
        ):
            for window in ("train", "oos", "actual"):
                specs.append(
                    build_run_spec(
                        stage="compare",
                        window=window,
                        timeframe_key=timeframe_key,
                        trend_tf=trend_tf,
                        signal_tf=signal_tf,
                        tester_period=tester_period,
                        target_key=target_key,
                        target_mode=target_mode,
                        tier_key=tier_key,
                        stop_key=stop_key,
                        ordinal=ordinal,
                    )
                )
                ordinal += 1
    return specs


def execute_specs(specs: list[RunSpec], terminal_path: str, timeout_seconds: int, reuse_existing: bool) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    for spec in specs:
        generate_run_files(spec)
        run_backtest(spec, terminal_path, timeout_seconds, reuse_existing)
        results.append(summarize_run(spec))
    return results


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


def aggregate_telemetry_across_runs(rows: list[dict[str, Any]], window: str) -> dict[str, Any]:
    combined: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        if row["window"] != window:
            continue
        for key, buckets in row["telemetry"]["dimensions"].items():
            for bucket_name, bucket_values in buckets.items():
                combined_key = f"{key}:{bucket_name}"
                combined[combined_key].append(bucket_values)

    dimensions: dict[str, dict[str, Any]] = defaultdict(dict)
    for combined_key, bucket_values in combined.items():
        dimension, bucket_name = combined_key.split(":", 1)
        summary = {
            "trades": sum(item["trades"] for item in bucket_values),
            "wins": sum(item["wins"] for item in bucket_values),
            "losses": sum(item["losses"] for item in bucket_values),
            "gross_profit": sum(item["gross_profit"] for item in bucket_values if item["gross_profit"] > 0),
            "gross_loss_abs": sum(abs(item["gross_loss"]) for item in bucket_values if item["gross_loss"] < 0),
            "net_profit": sum(item["net_profit"] for item in bucket_values),
        }
        summary["profit_factor"] = round(summary["gross_profit"] / summary["gross_loss_abs"], 4) if summary["gross_loss_abs"] > 0 else 0.0
        summary["avg_profit"] = round(summary["net_profit"] / summary["trades"], 4) if summary["trades"] else 0.0
        summary["win_rate"] = round((summary["wins"] / summary["trades"]) * 100.0, 2) if summary["trades"] else 0.0
        summary["gross_profit"] = round(summary["gross_profit"], 4)
        summary["gross_loss"] = round(-summary["gross_loss_abs"], 4)
        summary["net_profit"] = round(summary["net_profit"], 4)
        del summary["gross_loss_abs"]
        dimensions[dimension][bucket_name] = summary

    return {key: dict(sorted(value.items(), key=lambda item: (item[1]["profit_factor"], item[1]["net_profit"], item[1]["trades"]), reverse=True)) for key, value in dimensions.items()}


def build_markdown(results: dict[str, Any]) -> str:
    lines = [
        "# USDJPY Failed Breakout Validation Matrix",
        "",
        "## Matrix",
        "",
    ]

    for row in results["screening"]:
        metrics = row["report_metrics"]
        lines.append(
            f"- screen `{row['timeframe_pair']}` `{row['target_mode']}` PF=`{metrics['profit_factor']}` trades=`{metrics['trades']}` net=`{metrics['net_profit']}`"
        )

    lines.extend(["", "## Validation Highlights", ""])
    for window in ("train", "oos", "actual"):
        lines.append(f"### {window}")
        for row in results["highlights"][window]:
            metrics = row["report_metrics"]
            lines.append(
                f"- `{row['timeframe_pair']}` `{row['target_mode']}` `{row['tier_mode']}` `{row['stop_basis']}` PF=`{metrics['profit_factor']}` trades=`{metrics['trades']}` net=`{metrics['net_profit']}` dd=`{metrics['max_drawdown_percent']}`"
            )
        lines.append("")

    lines.extend(["## Telemetry Buckets", ""])
    for window in ("oos", "actual"):
        lines.append(f"### {window}")
        dimensions = results["telemetry_aggregate"].get(window, {})
        for dimension_name in ("phase", "entry_type", "fib_depth_bucket", "target_type", "stop_basis", "final_reason"):
            lines.append(f"- {dimension_name}:")
            buckets = dimensions.get(dimension_name, {})
            if not buckets:
                lines.append("  - no data")
                continue
            for bucket_name, bucket in list(buckets.items())[:6]:
                lines.append(
                    f"  - {bucket_name}: PF={bucket['profit_factor']} trades={bucket['trades']} net={bucket['net_profit']} avg={bucket['avg_profit']}"
                )
        lines.append("")

    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    ensure_dirs()

    screen_specs = screening_specs()
    screen_results = execute_specs(screen_specs, args.terminal_path, args.timeout_seconds, args.reuse_existing)
    winners = pick_timeframe_winners(screen_results)

    validation_results = execute_specs(validation_specs(winners), args.terminal_path, args.timeout_seconds, args.reuse_existing)
    tierab_results = execute_specs(tierab_matrix_specs(), args.terminal_path, args.timeout_seconds, args.reuse_existing)
    finalists = select_finalists(tierab_results)
    comparison_results = execute_specs(comparison_specs(finalists), args.terminal_path, args.timeout_seconds, args.reuse_existing)

    all_results = screen_results + validation_results + tierab_results + comparison_results
    payload = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "terminal_path": args.terminal_path,
        "screening": screen_results,
        "validation": validation_results,
        "tierab_matrix": tierab_results,
        "comparison": comparison_results,
        "timeframe_winners": winners,
        "finalists": finalists,
        "highlights": {
            window: best_rows(validation_results + tierab_results + comparison_results, window)[:12]
            for window in ("train", "oos", "actual")
        },
        "telemetry_aggregate": {
            window: aggregate_telemetry_across_runs(validation_results + tierab_results + comparison_results, window)
            for window in ("train", "oos", "actual")
        },
        "all_runs": all_results,
    }

    json_path = RESULTS_ROOT / "results.json"
    markdown_path = RESULTS_ROOT / "summary.md"
    json_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    markdown_path.write_text(build_markdown(payload), encoding="utf-8")

    print(f"Results JSON: {json_path}")
    print(f"Results MD  : {markdown_path}")
    print(f"Timeframe winners: {winners}")
    print(f"Finalists: {finalists}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
