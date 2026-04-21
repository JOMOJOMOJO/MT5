from __future__ import annotations

import argparse
import csv
import importlib.util
import json
import os
import subprocess
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any


SCRIPT_PATH = Path(__file__).resolve()
REPO_ROOT = SCRIPT_PATH.parents[3]
COMMON_FILES_ROOT = Path(os.environ["APPDATA"]) / "MetaQuotes" / "Terminal" / "Common" / "Files"
SWEEP_ROOT = REPO_ROOT / "reports" / "backtest" / "sweeps" / "2026-04-21-usdjpy-session-box-validation"
RESULTS_ROOT = SWEEP_ROOT / "results"
CONFIGS_ROOT = SWEEP_ROOT / "configs"
PRESETS_ROOT = SWEEP_ROOT / "presets"
REPORTS_ROOT = SWEEP_ROOT / "reports"
BASE_PRESET = REPO_ROOT / "reports" / "presets" / "usdjpy_20260421_tokyo_london_session_box_breakout_engine-strict.set"
EXPERT_PATH = "dev\\mql\\Experts\\usdjpy_20260421_tokyo_london_session_box_breakout_engine.ex5"
TERMINAL_DEFAULT = Path(r"C:\Program Files\XMTrading MT5\terminal64.exe")
BACKTEST_SCRIPT = REPO_ROOT / "scripts" / "backtest.ps1"
REPORT_TOOL_PATH = REPO_ROOT / "plugins" / "mt5-company" / "scripts" / "mt5_backtest_tools.py"

WINDOWS = {
    "train": ("2025.04.01", "2025.12.31"),
    "oos": ("2026.01.01", "2026.04.01"),
    "actual": ("2024.11.26", "2026.04.01"),
}

PAIRS: list[tuple[str, int, int]] = [
    ("m15_m5", 15, 5),
    ("m30_m5", 30, 5),
    ("m15_m3", 15, 3),
]

TRIGGERS: list[tuple[str, int]] = [
    ("range_close_confirm", 0),
    ("range_retest_confirm", 1),
    ("breakout_bar_continuation", 2),
]

TIMEFRAME_LABELS = {
    3: "M3",
    5: "M5",
    10: "M10",
    15: "M15",
    30: "M30",
    60: "H1",
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
    range_tf: int
    execution_tf: int


@dataclass
class RunSpec:
    slug: str
    pair_key: str
    pair_label: str
    window: str
    trigger_key: str
    trigger_mode: int
    range_tf: int
    execution_tf: int
    preset_path: Path
    config_path: Path
    report_path: Path
    telemetry_name: str
    telemetry_path: Path
    magic_number: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate the USDJPY Tokyo-London session box breakout family.")
    parser.add_argument("--terminal-path", default=str(TERMINAL_DEFAULT))
    parser.add_argument("--timeout-seconds", type=int, default=1200)
    parser.add_argument("--reuse-existing", action="store_true")
    parser.add_argument("--max-runs", type=int, default=0)
    return parser.parse_args()


def ensure_dirs() -> None:
    for path in (SWEEP_ROOT, RESULTS_ROOT, CONFIGS_ROOT, PRESETS_ROOT, REPORTS_ROOT):
        path.mkdir(parents=True, exist_ok=True)


def timeframe_label(value: int) -> str:
    return TIMEFRAME_LABELS.get(value, str(value))


def pair_label(range_tf: int, execution_tf: int) -> str:
    return f"{timeframe_label(range_tf)} range x {timeframe_label(execution_tf)} execution"


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
    return f"MQL5\\Experts\\dev\\reports\\backtest\\sweeps\\2026-04-21-usdjpy-session-box-validation\\reports\\{slug}.htm"


def write_config(spec: RunSpec) -> None:
    from_date, to_date = WINDOWS[spec.window]
    relative_preset = spec.preset_path.relative_to(REPO_ROOT).as_posix().replace("/", "\\")
    config_lines = [
        "; auto-generated session breakout validation config",
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


def build_run_spec(pair: PairSpec, window: str, trigger_key: str, trigger_mode: int, ordinal: int) -> RunSpec:
    trigger_slug = {
        "range_close_confirm": "close",
        "range_retest_confirm": "retest",
        "breakout_bar_continuation": "continuation",
    }[trigger_key]
    slug = f"{window}-{pair.key}-{trigger_slug}"
    telemetry_name = f"mt5_company_session_box_{slug}.csv"
    return RunSpec(
        slug=slug,
        pair_key=pair.key,
        pair_label=pair_label(pair.range_tf, pair.execution_tf),
        window=window,
        trigger_key=trigger_key,
        trigger_mode=trigger_mode,
        range_tf=pair.range_tf,
        execution_tf=pair.execution_tf,
        preset_path=PRESETS_ROOT / f"{slug}.set",
        config_path=CONFIGS_ROOT / f"{slug}.ini",
        report_path=REPORTS_ROOT / f"{slug}.htm",
        telemetry_name=telemetry_name,
        telemetry_path=COMMON_FILES_ROOT / telemetry_name,
        magic_number=2026047000 + ordinal,
    )


def generate_run_files(spec: RunSpec) -> None:
    overrides = {
        "InpRangeTimeframe": spec.range_tf,
        "InpExecutionTimeframe": spec.execution_tf,
        "InpTradeBiasMode": 2,
        "InpBreakoutTriggerMode": spec.trigger_mode,
        "InpPartialTargetLevel": 382,
        "InpFinalTargetMode": 0,
        "InpMaxHoldBars": 24,
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
    result["net_profit"] = round(result["net_profit"], 4)
    result["gross_profit"] = round(result["gross_profit"], 4)
    result["gross_loss"] = round(-gross_loss_abs, 4)
    return result


def average(values: list[float]) -> float:
    if not values:
        return 0.0
    return round(sum(values) / len(values), 4)


def aggregate_dimension(trades: list[dict[str, Any]], key: str) -> dict[str, Any]:
    groups: dict[str, dict[str, Any]] = defaultdict(init_rollup)
    for trade in trades:
        bucket = str(trade.get(key) or "unknown")
        add_trade_to_rollup(groups[bucket], float(trade.get("net_profit", 0.0)), trade.get("total_realized_r"))
    return dict(
        sorted(
            ((bucket, finalize_rollup(rollup)) for bucket, rollup in groups.items()),
            key=lambda item: (item[1]["trades"], item[1]["profit_factor"], item[1]["net_profit"]),
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
                "avg_bars_from_setup_to_entry": 0.0,
                "avg_setup_to_entry_pips": 0.0,
                "avg_bars_to_partial": 0.0,
                "avg_bars_to_final": 0.0,
                "avg_bars_to_time_stop": 0.0,
                "avg_mfe_pips": 0.0,
                "avg_mae_pips": 0.0,
                "avg_max_unrealized_r": 0.0,
                "avg_min_unrealized_r": 0.0,
                "exit_reason_breakdown": {},
                "dimensions": {},
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
                "session_type": row.get("session_type", ""),
                "breakout_type": row.get("breakout_type", ""),
                "breakout_state": row.get("breakout_state", ""),
                "execution_trigger": row.get("execution_trigger", ""),
                "range_tf": row.get("range_tf", ""),
                "execution_tf": row.get("execution_tf", ""),
                "partial_target_label": row.get("partial_target_label", ""),
                "final_target_label": row.get("final_target_label", ""),
                "volatility_bucket": row.get("volatility_bucket", ""),
                "planned_risk_amount": 0.0,
                "bars_from_setup_to_entry": -1,
                "setup_to_entry_pips": 0.0,
                "bars_to_partial": -1,
                "bars_to_final": -1,
                "bars_to_time_stop": -1,
                "mfe_pips": 0.0,
                "mae_pips": 0.0,
                "max_unrealized_r": 0.0,
                "min_unrealized_r": 0.0,
                "net_profit": 0.0,
                "partial_hit": False,
                "be_move": False,
                "runner_target_enabled": False,
                "runner_target_hit": False,
                "runner_stop_at_breakeven": False,
                "final_reason": "",
                "final_outcome": "",
                "has_exit": False,
                "total_realized_r": None,
                "subtype": "",
            },
        )

        planned_risk_amount = parse_float(row.get("planned_risk_amount"))
        if planned_risk_amount > 0.0:
            trade["planned_risk_amount"] = planned_risk_amount

        bars_from_setup = parse_int(row.get("bars_from_setup_to_entry"))
        if bars_from_setup >= 0:
            trade["bars_from_setup_to_entry"] = bars_from_setup
        trade["setup_to_entry_pips"] = parse_float(row.get("setup_to_entry_pips"))
        trade["mfe_pips"] = max(trade["mfe_pips"], parse_float(row.get("mfe_pips")))
        trade["mae_pips"] = max(trade["mae_pips"], parse_float(row.get("mae_pips")))
        trade["max_unrealized_r"] = max(trade["max_unrealized_r"], parse_float(row.get("max_unrealized_r")))
        trade["min_unrealized_r"] = min(trade["min_unrealized_r"], parse_float(row.get("min_unrealized_r")))

        if event_type == "entry":
            trade["side"] = row.get("side", trade["side"])
            trade["session_type"] = row.get("session_type", trade["session_type"])
            trade["breakout_type"] = row.get("breakout_type", trade["breakout_type"])
            trade["breakout_state"] = row.get("breakout_state", trade["breakout_state"])
            trade["execution_trigger"] = row.get("execution_trigger", trade["execution_trigger"])
            trade["range_tf"] = row.get("range_tf", trade["range_tf"])
            trade["execution_tf"] = row.get("execution_tf", trade["execution_tf"])
            trade["partial_target_label"] = row.get("partial_target_label", trade["partial_target_label"])
            trade["final_target_label"] = row.get("final_target_label", trade["final_target_label"])
            trade["volatility_bucket"] = row.get("volatility_bucket", trade["volatility_bucket"])
            trade["runner_target_enabled"] = parse_bool(row.get("runner_target_enabled"))
            continue

        if event_type == "partial_exit":
            profit = parse_float(row.get("net_profit"))
            trade["net_profit"] += profit
            trade["partial_hit"] = True
            trade["be_move"] = parse_bool(row.get("be_move")) or trade["be_move"]
            if parse_int(row.get("bars_to_partial")) >= 0:
                trade["bars_to_partial"] = parse_int(row.get("bars_to_partial"))
            continue

        if event_type == "exit":
            profit = parse_float(row.get("net_profit"))
            trade["net_profit"] += profit
            trade["be_move"] = parse_bool(row.get("be_move")) or trade["be_move"]
            trade["runner_target_hit"] = parse_bool(row.get("runner_target_hit"))
            trade["runner_stop_at_breakeven"] = parse_bool(row.get("runner_stop_at_breakeven"))
            trade["final_reason"] = row.get("reason", "")
            trade["final_outcome"] = row.get("outcome", "")
            if parse_int(row.get("bars_to_final")) >= 0:
                trade["bars_to_final"] = parse_int(row.get("bars_to_final"))
            if parse_int(row.get("bars_to_time_stop")) >= 0:
                trade["bars_to_time_stop"] = parse_int(row.get("bars_to_time_stop"))
            trade["has_exit"] = True
            active_trade_key = None

    closed_trades = [trade for trade in campaigns.values() if trade["has_exit"]]
    summary_rollup = init_rollup()
    exit_reason_breakdown: dict[str, dict[str, Any]] = defaultdict(lambda: {"count": 0, "net_profit": 0.0})

    partial_hit_count = 0
    be_move_count = 0
    runner_target_hit_count = 0
    runner_breakeven_stop_count = 0
    bars_from_setup_values: list[float] = []
    setup_to_entry_values: list[float] = []
    bars_to_partial_values: list[float] = []
    bars_to_final_values: list[float] = []
    bars_to_time_stop_values: list[float] = []
    mfe_values: list[float] = []
    mae_values: list[float] = []
    max_unrealized_r_values: list[float] = []
    min_unrealized_r_values: list[float] = []

    for trade in closed_trades:
        planned_risk_amount = float(trade["planned_risk_amount"])
        total_realized_r = None
        if planned_risk_amount > 0.0:
            total_realized_r = float(trade["net_profit"]) / planned_risk_amount
            trade["total_realized_r"] = total_realized_r

        trade["subtype"] = "|".join(
            [
                str(trade["side"] or "unknown"),
                str(trade["session_type"] or "unknown"),
                str(trade["breakout_type"] or "unknown"),
                str(trade["execution_trigger"] or "unknown"),
            ]
        )

        add_trade_to_rollup(summary_rollup, float(trade["net_profit"]), total_realized_r)
        if trade["partial_hit"]:
            partial_hit_count += 1
        if trade["be_move"]:
            be_move_count += 1
        if trade["runner_target_hit"]:
            runner_target_hit_count += 1
        if trade["runner_stop_at_breakeven"]:
            runner_breakeven_stop_count += 1

        if trade["bars_from_setup_to_entry"] >= 0:
            bars_from_setup_values.append(float(trade["bars_from_setup_to_entry"]))
        setup_to_entry_values.append(float(trade["setup_to_entry_pips"]))
        if trade["bars_to_partial"] >= 0:
            bars_to_partial_values.append(float(trade["bars_to_partial"]))
        if trade["bars_to_final"] >= 0:
            bars_to_final_values.append(float(trade["bars_to_final"]))
        if trade["bars_to_time_stop"] >= 0:
            bars_to_time_stop_values.append(float(trade["bars_to_time_stop"]))
        mfe_values.append(float(trade["mfe_pips"]))
        mae_values.append(float(trade["mae_pips"]))
        max_unrealized_r_values.append(float(trade["max_unrealized_r"]))
        min_unrealized_r_values.append(float(trade["min_unrealized_r"]))

        final_reason = trade["final_reason"] or "unknown"
        exit_reason_breakdown[final_reason]["count"] += 1
        exit_reason_breakdown[final_reason]["net_profit"] += float(trade["net_profit"])

    dimensions = {}
    for key in (
        "subtype",
        "session_type",
        "breakout_type",
        "breakout_state",
        "execution_trigger",
        "final_reason",
        "range_tf",
        "execution_tf",
        "side",
    ):
        dimensions[key] = aggregate_dimension(closed_trades, key)

    summary = finalize_rollup(summary_rollup)
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
            "avg_bars_from_setup_to_entry": average(bars_from_setup_values),
            "avg_setup_to_entry_pips": average(setup_to_entry_values),
            "avg_bars_to_partial": average(bars_to_partial_values),
            "avg_bars_to_final": average(bars_to_final_values),
            "avg_bars_to_time_stop": average(bars_to_time_stop_values),
            "avg_mfe_pips": average(mfe_values),
            "avg_mae_pips": average(mae_values),
            "avg_max_unrealized_r": average(max_unrealized_r_values),
            "avg_min_unrealized_r": average(min_unrealized_r_values),
            "exit_reason_breakdown": {
                reason: {"count": values["count"], "net_profit": round(values["net_profit"], 4)}
                for reason, values in sorted(exit_reason_breakdown.items(), key=lambda item: item[1]["count"], reverse=True)
            },
            "dimensions": dimensions,
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
        "range_tf": spec.range_tf,
        "execution_tf": spec.execution_tf,
        "report_path": str(spec.report_path),
        "telemetry_path": str(spec.telemetry_path),
        "metrics": parse_report_metrics(spec.report_path),
        "telemetry": summarize_telemetry(spec.telemetry_path),
    }


def build_run_specs(max_runs: int) -> list[RunSpec]:
    specs: list[RunSpec] = []
    ordinal = 1
    for pair_key, range_tf, execution_tf in PAIRS:
        pair = PairSpec(pair_key, range_tf, execution_tf)
        for trigger_key, trigger_mode in TRIGGERS:
            for window in WINDOWS:
                specs.append(build_run_spec(pair, window, trigger_key, trigger_mode, ordinal))
                ordinal += 1
    if max_runs > 0:
        return specs[:max_runs]
    return specs


def aggregate_run_items(items: list[dict[str, Any]], dimension: str) -> dict[str, dict[str, Any]]:
    buckets: dict[str, dict[str, Any]] = defaultdict(
        lambda: {
            "trades": 0,
            "wins": 0,
            "losses": 0,
            "gross_profit": 0.0,
            "gross_loss_abs": 0.0,
            "net_profit": 0.0,
            "sum_realized_r": 0.0,
            "realized_r_count": 0,
            "partial_hits": 0,
            "be_moves": 0,
            "runner_hits": 0,
        }
    )

    for item in items:
        bucket = str(item[dimension])
        telemetry = item["telemetry"]
        data = buckets[bucket]
        data["trades"] += int(telemetry["closed_trades"])
        data["wins"] += int(telemetry["wins"])
        data["losses"] += int(telemetry["losses"])
        data["gross_profit"] += float(telemetry["gross_profit"])
        data["gross_loss_abs"] += float(telemetry["gross_loss_abs"])
        data["net_profit"] += float(telemetry["net_profit"])
        data["sum_realized_r"] += float(telemetry["sum_realized_r"])
        data["realized_r_count"] += int(telemetry["realized_r_count"])
        data["partial_hits"] += int(telemetry["partial_hit_count"])
        data["be_moves"] += int(telemetry["be_move_count"])
        data["runner_hits"] += int(telemetry["runner_target_hit_count"])

    result: dict[str, dict[str, Any]] = {}
    for bucket, data in sorted(buckets.items(), key=lambda item: (item[1]["trades"], item[1]["net_profit"]), reverse=True):
        trades = data["trades"]
        gross_loss_abs = data["gross_loss_abs"]
        result[bucket] = {
            "trades": trades,
            "profit_factor": round(data["gross_profit"] / gross_loss_abs, 4) if gross_loss_abs > 0.0 else 0.0,
            "net_profit": round(data["net_profit"], 4),
            "avg_realized_r": round(data["sum_realized_r"] / data["realized_r_count"], 4) if data["realized_r_count"] else 0.0,
            "partial_hit_rate": round((data["partial_hits"] / trades) * 100.0, 2) if trades else 0.0,
            "be_move_rate": round((data["be_moves"] / data["partial_hits"]) * 100.0, 2) if data["partial_hits"] else 0.0,
            "runner_hit_rate": round((data["runner_hits"] / data["partial_hits"]) * 100.0, 2) if data["partial_hits"] else 0.0,
        }
    return result


def aggregate_dimension_summaries(items: list[dict[str, Any]], dimension_key: str) -> dict[str, dict[str, Any]]:
    buckets: dict[str, dict[str, Any]] = defaultdict(init_rollup)
    for item in items:
        for bucket, values in item["telemetry"]["dimensions"].get(dimension_key, {}).items():
            data = buckets[bucket]
            data["trades"] += int(values.get("trades", 0))
            data["wins"] += int(values.get("wins", 0))
            data["losses"] += int(values.get("losses", 0))
            data["gross_profit"] += float(values.get("gross_profit", 0.0))
            data["gross_loss_abs"] += abs(float(values.get("gross_loss", 0.0)))
            data["net_profit"] += float(values.get("net_profit", 0.0))
            realized_r_count = int(values.get("realized_r_count", 0))
            data["sum_realized_r"] += float(values.get("avg_realized_r", 0.0)) * realized_r_count
            data["realized_r_count"] += realized_r_count
            data["sum_win_r"] += float(values.get("avg_win_r", 0.0)) * int(values.get("win_r_count", 0))
            data["win_r_count"] += int(values.get("win_r_count", 0))
            data["sum_loss_r"] += float(values.get("avg_loss_r", 0.0)) * int(values.get("loss_r_count", 0))
            data["loss_r_count"] += int(values.get("loss_r_count", 0))

    result: dict[str, dict[str, Any]] = {}
    for bucket, data in sorted(buckets.items(), key=lambda item: (item[1]["trades"], item[1]["net_profit"]), reverse=True):
        result[bucket] = finalize_rollup(data)
    return result


def write_results_json(results: list[dict[str, Any]]) -> Path:
    path = RESULTS_ROOT / "results.json"
    path.write_text(json.dumps(results, indent=2), encoding="utf-8")
    return path


def write_summary_markdown(results: list[dict[str, Any]]) -> Path:
    path = RESULTS_ROOT / "summary.md"
    lines: list[str] = []
    lines.append("# USDJPY Tokyo-London Session Box Breakout Validation")
    lines.append("")
    lines.append(f"- total runs: {len(results)}")
    lines.append("- fixed slice: `both directions`, `Tokyo range -> London breakout`, `partial 38.2`, `final session extension`, `hold 24`, `EA managed exits`")

    for window in ("train", "oos", "actual"):
        window_items = [item for item in results if item["window"] == window]
        lines.append("")
        lines.append(f"## {window.upper()}")
        lines.append("")
        lines.append("| slug | pair | trigger | trades | pf | net | exp payoff | max dd % | win rate % | avg win | avg loss | avg R |")
        lines.append("|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
        for item in sorted(
            window_items,
            key=lambda run: (run["telemetry"]["closed_trades"], run["metrics"]["profit_factor"], run["metrics"]["net_profit"]),
            reverse=True,
        ):
            metrics = item["metrics"]
            telemetry = item["telemetry"]
            lines.append(
                f"| {item['slug']} | {item['pair_label']} | {item['trigger_key']} | "
                f"{telemetry['closed_trades']} | {metrics['profit_factor']:.2f} | {metrics['net_profit']:.2f} | "
                f"{metrics['expected_payoff']:.2f} | {metrics['max_drawdown_percent']:.2f} | {metrics['win_rate']:.2f} | "
                f"{metrics['average_win']:.2f} | {metrics['average_loss']:.2f} | {telemetry['avg_realized_r']:.4f} |"
            )

        for title, dimension in (
            ("Aggregate By Pair", "pair_label"),
            ("Aggregate By Trigger", "trigger_key"),
        ):
            lines.append("")
            lines.append(f"### {title}")
            lines.append("")
            lines.append("| bucket | trades | pf | net | avg R | partial hit % | be move % | runner hit % |")
            lines.append("|---|---:|---:|---:|---:|---:|---:|---:|")
            for bucket, values in aggregate_run_items(window_items, dimension).items():
                lines.append(
                    f"| {bucket} | {values['trades']} | {values['profit_factor']:.2f} | {values['net_profit']:.2f} | "
                    f"{values['avg_realized_r']:.4f} | {values['partial_hit_rate']:.2f} | {values['be_move_rate']:.2f} | "
                    f"{values['runner_hit_rate']:.2f} |"
                )

        lines.append("")
        lines.append("### Aggregate By Breakout Type")
        lines.append("")
        lines.append("| breakout type | trades | pf | net | avg R |")
        lines.append("|---|---:|---:|---:|---:|")
        breakout_agg = aggregate_dimension_summaries(window_items, "breakout_type")
        if breakout_agg:
            for bucket, values in breakout_agg.items():
                lines.append(
                    f"| {bucket} | {values['trades']} | {values['profit_factor']:.2f} | {values['net_profit']:.2f} | {values['avg_realized_r']:.4f} |"
                )
        else:
            lines.append("| none | 0 | 0.00 | 0.00 | 0.0000 |")

        lines.append("")
        lines.append("### Aggregate By Session Type")
        lines.append("")
        lines.append("| session type | trades | pf | net | avg R |")
        lines.append("|---|---:|---:|---:|---:|")
        session_agg = aggregate_dimension_summaries(window_items, "session_type")
        if session_agg:
            for bucket, values in session_agg.items():
                lines.append(
                    f"| {bucket} | {values['trades']} | {values['profit_factor']:.2f} | {values['net_profit']:.2f} | {values['avg_realized_r']:.4f} |"
                )
        else:
            lines.append("| none | 0 | 0.00 | 0.00 | 0.0000 |")

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path


def main() -> None:
    args = parse_args()
    ensure_dirs()
    run_specs = build_run_specs(args.max_runs)
    for spec in run_specs:
        generate_run_files(spec)
        run_backtest(spec, args.terminal_path, args.timeout_seconds, args.reuse_existing)

    results = [summarize_run(spec) for spec in run_specs]
    write_results_json(results)
    write_summary_markdown(results)


if __name__ == "__main__":
    main()
