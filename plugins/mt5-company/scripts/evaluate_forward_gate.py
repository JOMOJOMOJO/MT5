from __future__ import annotations

import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate whether a demo-forward summary is promotable versus a baseline.")
    parser.add_argument("--baseline", required=True, help="Path to baseline telemetry summary JSON.")
    parser.add_argument("--candidate", required=True, help="Path to candidate forward telemetry summary JSON.")
    parser.add_argument("--output", help="Optional JSON output path.")
    parser.add_argument("--markdown-output", help="Optional Markdown output path.")
    parser.add_argument("--label", default="", help="Optional label for the gate report.")
    parser.add_argument("--min-exits", type=int, default=5, help="Minimum exit count required before judging promotion.")
    parser.add_argument("--min-active-days", type=int, default=5, help="Minimum active days required before judging promotion.")
    parser.add_argument("--min-profit-factor", type=float, default=1.0, help="Hard minimum forward profit factor.")
    parser.add_argument(
        "--min-relative-profit-factor",
        type=float,
        default=0.75,
        help="Minimum candidate PF as a multiple of baseline PF before pass.",
    )
    parser.add_argument(
        "--max-spread-block-ratio",
        type=float,
        default=1.25,
        help="Maximum allowed candidate spread-block-per-day ratio relative to baseline.",
    )
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def safe_divide(numerator: float, denominator: float) -> float:
    if denominator == 0:
        return 0.0
    return numerator / denominator


def add_check(checks: list[dict[str, Any]], name: str, status: str, detail: str) -> None:
    checks.append({"name": name, "status": status, "detail": detail})


def summarize_status(checks: list[dict[str, Any]]) -> str:
    statuses = {check["status"] for check in checks}
    if "fail" in statuses:
        return "fail"
    if "review" in statuses:
        return "review"
    if "insufficient_sample" in statuses:
        return "insufficient_sample"
    return "pass"


def evaluate(args: argparse.Namespace, baseline: dict[str, Any], candidate: dict[str, Any]) -> dict[str, Any]:
    baseline_exits = baseline.get("exits", {})
    baseline_daily = baseline.get("daily", {})
    candidate_exits = candidate.get("exits", {})
    candidate_daily = candidate.get("daily", {})

    baseline_pf = float(baseline_exits.get("profit_factor", 0.0))
    candidate_pf = float(candidate_exits.get("profit_factor", 0.0))
    baseline_net = float(baseline_exits.get("net_profit", 0.0))
    candidate_net = float(candidate_exits.get("net_profit", 0.0))
    baseline_exit_count = int(baseline_exits.get("count", 0))
    candidate_exit_count = int(candidate_exits.get("count", 0))
    baseline_active_days = int(baseline_daily.get("active_days", 0))
    candidate_active_days = int(candidate_daily.get("active_days", 0))

    baseline_spread_blocks = int(baseline_daily.get("blocked_totals", {}).get("blocked_spread", 0))
    candidate_spread_blocks = int(candidate_daily.get("blocked_totals", {}).get("blocked_spread", 0))
    baseline_summary_days = max(int(baseline_daily.get("summaries", 0)), 1)
    candidate_summary_days = max(int(candidate_daily.get("summaries", 0)), 1)
    baseline_spread_per_day = safe_divide(baseline_spread_blocks, baseline_summary_days)
    candidate_spread_per_day = safe_divide(candidate_spread_blocks, candidate_summary_days)

    blocked_daily_loss = int(candidate_daily.get("blocked_totals", {}).get("blocked_daily_loss", 0))
    blocked_equity_cap = int(candidate_daily.get("blocked_totals", {}).get("blocked_equity_cap", 0))
    loss_lock_activations = int(candidate_daily.get("blocked_totals", {}).get("loss_lock_activations", 0))

    checks: list[dict[str, Any]] = []

    same_source = (
        baseline.get("source_path", "") == candidate.get("source_path", "") and
        baseline.get("period", {}) == candidate.get("period", {}) and
        int(baseline.get("row_count", 0)) == int(candidate.get("row_count", 0))
    )
    if same_source:
        add_check(
            checks,
            "evidence_source",
            "review",
            "candidate summary appears to be built from the same telemetry source as the baseline",
        )
    else:
        add_check(checks, "evidence_source", "pass", "candidate summary is sourced from a different telemetry artifact")

    if candidate_exit_count < args.min_exits:
        add_check(
            checks,
            "sample_exits",
            "insufficient_sample",
            f"candidate exits {candidate_exit_count} < minimum {args.min_exits}",
        )
    else:
        add_check(checks, "sample_exits", "pass", f"candidate exits {candidate_exit_count}")

    if candidate_active_days < args.min_active_days:
        add_check(
            checks,
            "sample_active_days",
            "insufficient_sample",
            f"candidate active days {candidate_active_days} < minimum {args.min_active_days}",
        )
    else:
        add_check(checks, "sample_active_days", "pass", f"candidate active days {candidate_active_days}")

    if candidate_net <= 0.0:
        add_check(checks, "net_profit", "fail", f"candidate net {candidate_net:.4f} <= 0")
    else:
        net_ratio = safe_divide(candidate_net, baseline_net) if baseline_net != 0 else 0.0
        status = "pass" if net_ratio >= 0.5 else "review"
        add_check(checks, "net_profit", status, f"candidate net {candidate_net:.4f}, baseline net {baseline_net:.4f}, ratio {net_ratio:.4f}")

    pf_floor = max(args.min_profit_factor, baseline_pf * args.min_relative_profit_factor)
    if candidate_pf < args.min_profit_factor:
        add_check(checks, "profit_factor", "fail", f"candidate PF {candidate_pf:.4f} < hard floor {args.min_profit_factor:.4f}")
    elif candidate_pf < pf_floor:
        add_check(checks, "profit_factor", "review", f"candidate PF {candidate_pf:.4f} < relative floor {pf_floor:.4f}")
    else:
        add_check(checks, "profit_factor", "pass", f"candidate PF {candidate_pf:.4f}, baseline PF {baseline_pf:.4f}")

    if blocked_daily_loss > 0 or blocked_equity_cap > 0:
        add_check(
            checks,
            "kill_switches",
            "fail",
            f"daily cap blocks {blocked_daily_loss}, equity cap blocks {blocked_equity_cap}",
        )
    elif loss_lock_activations > 0:
        add_check(checks, "kill_switches", "review", f"loss-lock activations {loss_lock_activations}")
    else:
        add_check(checks, "kill_switches", "pass", "no daily/equity cap triggers and no loss-lock activations")

    if baseline_spread_per_day <= 0.0:
        spread_ratio = 0.0
        add_check(checks, "spread_pressure", "review", "baseline spread/day is zero; ratio comparison unavailable")
    else:
        spread_ratio = candidate_spread_per_day / baseline_spread_per_day
        if spread_ratio > args.max_spread_block_ratio:
            add_check(
                checks,
                "spread_pressure",
                "review",
                f"candidate spread/day {candidate_spread_per_day:.4f} exceeds ratio {spread_ratio:.4f} of baseline",
            )
        else:
            add_check(
                checks,
                "spread_pressure",
                "pass",
                f"candidate spread/day {candidate_spread_per_day:.4f}, baseline {baseline_spread_per_day:.4f}, ratio {spread_ratio:.4f}",
            )

    overall_status = summarize_status(checks)
    return {
        "label": args.label,
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "status": overall_status,
        "baseline_path": str(Path(args.baseline).resolve()),
        "candidate_path": str(Path(args.candidate).resolve()),
        "thresholds": {
            "min_exits": args.min_exits,
            "min_active_days": args.min_active_days,
            "min_profit_factor": args.min_profit_factor,
            "min_relative_profit_factor": args.min_relative_profit_factor,
            "max_spread_block_ratio": args.max_spread_block_ratio,
        },
        "baseline_snapshot": {
            "net_profit": baseline_net,
            "profit_factor": baseline_pf,
            "exit_count": baseline_exit_count,
            "active_days": baseline_active_days,
            "spread_blocks_per_day": round(baseline_spread_per_day, 4),
        },
        "candidate_snapshot": {
            "net_profit": candidate_net,
            "profit_factor": candidate_pf,
            "exit_count": candidate_exit_count,
            "active_days": candidate_active_days,
            "spread_blocks_per_day": round(candidate_spread_per_day, 4),
        },
        "checks": checks,
    }


def build_markdown(report: dict[str, Any]) -> str:
    baseline = report["baseline_snapshot"]
    candidate = report["candidate_snapshot"]
    lines = [
        "# Forward Gate Evaluation",
        "",
        f"- Label: `{report.get('label', '')}`",
        f"- Status: `{report.get('status', '')}`",
        f"- Baseline: `{report.get('baseline_path', '')}`",
        f"- Candidate: `{report.get('candidate_path', '')}`",
        "",
        "## Baseline Snapshot",
        "",
        f"- Net profit: `{baseline['net_profit']}`",
        f"- Profit factor: `{baseline['profit_factor']}`",
        f"- Exit count: `{baseline['exit_count']}`",
        f"- Active days: `{baseline['active_days']}`",
        f"- Spread blocks/day: `{baseline['spread_blocks_per_day']}`",
        "",
        "## Candidate Snapshot",
        "",
        f"- Net profit: `{candidate['net_profit']}`",
        f"- Profit factor: `{candidate['profit_factor']}`",
        f"- Exit count: `{candidate['exit_count']}`",
        f"- Active days: `{candidate['active_days']}`",
        f"- Spread blocks/day: `{candidate['spread_blocks_per_day']}`",
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
    baseline = load_json(Path(args.baseline).resolve())
    candidate = load_json(Path(args.candidate).resolve())
    report = evaluate(args, baseline, candidate)

    if args.output:
        write_text(Path(args.output).resolve(), json.dumps(report, indent=2, ensure_ascii=False))
    if args.markdown_output:
        write_text(Path(args.markdown_output).resolve(), build_markdown(report))

    print(json.dumps({"label": report["label"], "status": report["status"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
