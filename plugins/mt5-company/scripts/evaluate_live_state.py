from __future__ import annotations

import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any


STATUS_TIMESTAMP_FORMAT = "%Y.%m.%d %H:%M:%S"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate whether the live/demo operator should continue, pause, or flatten.")
    parser.add_argument("--telemetry-summary", required=True, help="Path to telemetry summary JSON.")
    parser.add_argument("--forward-gate", required=True, help="Path to forward gate JSON.")
    parser.add_argument("--status-file", required=True, help="Path to heartbeat status file.")
    parser.add_argument("--output", help="Optional JSON output path.")
    parser.add_argument("--markdown-output", help="Optional Markdown output path.")
    parser.add_argument("--label", default="", help="Optional review label.")
    parser.add_argument("--max-spread-pips", type=float, default=2500.0, help="Maximum acceptable live spread in pips.")
    parser.add_argument("--max-heartbeat-age-minutes", type=float, default=180.0, help="Maximum age of the heartbeat before review.")
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def load_status(path: Path) -> dict[str, str]:
    pairs: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        pairs[key.strip()] = value.strip()
    return pairs


def parse_bool(value: str) -> bool:
    return value.strip().lower() == "true"


def parse_int(value: str) -> int:
    return int(float(value)) if value else 0


def parse_float(value: str) -> float:
    return float(value) if value else 0.0


def add_check(checks: list[dict[str, str]], name: str, status: str, detail: str) -> None:
    checks.append({"name": name, "status": status, "detail": detail})


def merge_action(current: str, candidate: str) -> str:
    priority = {"continue": 0, "review": 1, "pause": 2, "flatten": 3}
    return candidate if priority[candidate] > priority[current] else current


def summarize_review(checks: list[dict[str, str]]) -> str:
    statuses = {check["status"] for check in checks}
    if "fail" in statuses:
        return "fail"
    if "review" in statuses:
        return "review"
    return "pass"


def evaluate(args: argparse.Namespace, telemetry: dict[str, Any], gate: dict[str, Any], status_map: dict[str, str]) -> dict[str, Any]:
    checks: list[dict[str, str]] = []
    recommended_action = "continue"

    heartbeat_timestamp_raw = status_map.get("timestamp", "")
    heartbeat_age_minutes: float | None = None
    if heartbeat_timestamp_raw:
        try:
            heartbeat_timestamp = datetime.strptime(heartbeat_timestamp_raw, STATUS_TIMESTAMP_FORMAT)
            heartbeat_age_minutes = round((datetime.now() - heartbeat_timestamp).total_seconds() / 60.0, 1)
            if heartbeat_age_minutes > args.max_heartbeat_age_minutes:
                add_check(
                    checks,
                    "heartbeat_freshness",
                    "review",
                    f"heartbeat age {heartbeat_age_minutes} minutes exceeds {args.max_heartbeat_age_minutes}",
                )
                recommended_action = merge_action(recommended_action, "review")
            else:
                add_check(checks, "heartbeat_freshness", "pass", f"heartbeat age {heartbeat_age_minutes} minutes")
        except ValueError:
            add_check(checks, "heartbeat_freshness", "review", f"could not parse heartbeat timestamp `{heartbeat_timestamp_raw}`")
            recommended_action = merge_action(recommended_action, "review")
    else:
        add_check(checks, "heartbeat_freshness", "review", "heartbeat timestamp missing")
        recommended_action = merge_action(recommended_action, "review")

    operator_mode = status_map.get("operator_mode", "")
    if operator_mode == "flatten":
        add_check(checks, "operator_mode", "review", "operator mode is already flatten")
        recommended_action = merge_action(recommended_action, "flatten")
    elif operator_mode == "pause":
        add_check(checks, "operator_mode", "review", "operator mode is pause")
        recommended_action = merge_action(recommended_action, "pause")
    else:
        add_check(checks, "operator_mode", "pass", f"operator mode is {operator_mode or 'normal'}")

    open_positions = parse_int(status_map.get("open_positions", "0"))
    daily_loss_blocked = parse_bool(status_map.get("daily_loss_cap_blocked", "false"))
    equity_blocked = parse_bool(status_map.get("equity_drawdown_blocked", "false"))
    loss_lock_active = parse_bool(status_map.get("loss_lock_active", "false"))
    trade_cap_blocked = parse_bool(status_map.get("trade_cap_blocked", "false"))
    spread_pips = parse_float(status_map.get("spread_pips", "0"))
    entry_state = status_map.get("entry_state", "")

    if daily_loss_blocked or equity_blocked:
        detail = f"daily_loss_blocked={daily_loss_blocked} equity_blocked={equity_blocked} open_positions={open_positions}"
        add_check(checks, "hard_blocks", "fail", detail)
        recommended_action = merge_action(recommended_action, "flatten" if open_positions > 0 else "pause")
    else:
        add_check(checks, "hard_blocks", "pass", "daily and equity hard blocks are inactive")

    if loss_lock_active or trade_cap_blocked:
        add_check(
            checks,
            "soft_blocks",
            "review",
            f"loss_lock_active={loss_lock_active} trade_cap_blocked={trade_cap_blocked} entry_state={entry_state}",
        )
        recommended_action = merge_action(recommended_action, "pause")
    else:
        add_check(checks, "soft_blocks", "pass", f"entry_state={entry_state}")

    if spread_pips > args.max_spread_pips:
        add_check(checks, "spread_now", "review", f"live spread {spread_pips} > threshold {args.max_spread_pips}")
        recommended_action = merge_action(recommended_action, "pause")
    else:
        add_check(checks, "spread_now", "pass", f"live spread {spread_pips} <= threshold {args.max_spread_pips}")

    gate_status = gate.get("status", "")
    same_gate_source = gate.get("baseline_path", "") == gate.get("candidate_path", "")
    if same_gate_source:
        add_check(checks, "forward_gate", "review", "forward gate still compares the baseline artifact to itself")
        recommended_action = merge_action(recommended_action, "review")
    elif gate_status == "fail":
        add_check(checks, "forward_gate", "fail", "forward gate status is fail")
        recommended_action = merge_action(recommended_action, "pause")
    elif gate_status == "review":
        add_check(checks, "forward_gate", "review", "forward gate status is review")
        recommended_action = merge_action(recommended_action, "review")
    else:
        add_check(checks, "forward_gate", "pass", f"forward gate status is {gate_status}")

    exits = telemetry.get("exits", {})
    daily = telemetry.get("daily", {})
    exit_count = int(exits.get("count", 0))
    profit_factor = float(exits.get("profit_factor", 0.0))
    blocked_spread = int(daily.get("blocked_totals", {}).get("blocked_spread", 0))
    active_days = int(daily.get("active_days", 0))

    if exit_count <= 0:
        add_check(checks, "telemetry_sample", "review", "telemetry summary contains no exits yet")
        recommended_action = merge_action(recommended_action, "review")
    else:
        add_check(checks, "telemetry_sample", "pass", f"exits={exit_count} active_days={active_days}")

    if profit_factor < 1.0:
        add_check(checks, "telemetry_quality", "fail", f"telemetry PF {profit_factor:.4f} < 1.0")
        recommended_action = merge_action(recommended_action, "pause")
    elif profit_factor < 1.2:
        add_check(checks, "telemetry_quality", "review", f"telemetry PF {profit_factor:.4f} is thin")
        recommended_action = merge_action(recommended_action, "review")
    else:
        add_check(checks, "telemetry_quality", "pass", f"telemetry PF {profit_factor:.4f}, blocked_spread={blocked_spread}")

    review_status = summarize_review(checks)
    return {
        "label": args.label,
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "recommended_action": recommended_action,
        "review_status": review_status,
        "inputs": {
            "telemetry_summary": str(Path(args.telemetry_summary).resolve()),
            "forward_gate": str(Path(args.forward_gate).resolve()),
            "status_file": str(Path(args.status_file).resolve()),
        },
        "status_snapshot": {
            "timestamp": heartbeat_timestamp_raw,
            "heartbeat_age_minutes": heartbeat_age_minutes,
            "operator_mode": operator_mode,
            "entry_state": entry_state,
            "open_positions": open_positions,
            "spread_pips": spread_pips,
            "daily_loss_cap_blocked": daily_loss_blocked,
            "equity_drawdown_blocked": equity_blocked,
            "loss_lock_active": loss_lock_active,
            "trade_cap_blocked": trade_cap_blocked,
        },
        "telemetry_snapshot": {
            "exit_count": exit_count,
            "profit_factor": profit_factor,
            "active_days": active_days,
            "blocked_spread": blocked_spread,
        },
        "forward_gate_status": gate_status,
        "checks": checks,
    }


def build_markdown(report: dict[str, Any]) -> str:
    status = report["status_snapshot"]
    telemetry = report["telemetry_snapshot"]
    lines = [
        "# Live Ops Review",
        "",
        f"- Label: `{report.get('label', '')}`",
        f"- Review status: `{report.get('review_status', '')}`",
        f"- Recommended action: `{report.get('recommended_action', '')}`",
        "",
        "## Status Snapshot",
        "",
        f"- Timestamp: `{status.get('timestamp', '')}`",
        f"- Heartbeat age minutes: `{status.get('heartbeat_age_minutes', '')}`",
        f"- Operator mode: `{status.get('operator_mode', '')}`",
        f"- Entry state: `{status.get('entry_state', '')}`",
        f"- Open positions: `{status.get('open_positions', 0)}`",
        f"- Spread pips: `{status.get('spread_pips', 0.0)}`",
        "",
        "## Telemetry Snapshot",
        "",
        f"- Exit count: `{telemetry.get('exit_count', 0)}`",
        f"- Profit factor: `{telemetry.get('profit_factor', 0.0)}`",
        f"- Active days: `{telemetry.get('active_days', 0)}`",
        f"- Blocked spread: `{telemetry.get('blocked_spread', 0)}`",
        "",
        "## Checks",
        "",
    ]
    for check in report["checks"]:
        lines.append(f"- `{check['name']}` `{check['status']}`: {check['detail']}")
    lines.append("")
    return "\n".join(lines)


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def main() -> None:
    args = parse_args()
    telemetry = load_json(Path(args.telemetry_summary).resolve())
    gate = load_json(Path(args.forward_gate).resolve())
    status_map = load_status(Path(args.status_file).resolve())
    report = evaluate(args, telemetry, gate, status_map)

    if args.output:
        write_text(Path(args.output).resolve(), json.dumps(report, indent=2, ensure_ascii=False))
    if args.markdown_output:
        write_text(Path(args.markdown_output).resolve(), build_markdown(report))

    print(json.dumps({"review_status": report["review_status"], "recommended_action": report["recommended_action"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
