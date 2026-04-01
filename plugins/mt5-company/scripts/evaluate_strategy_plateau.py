import argparse
import json
from datetime import datetime
from pathlib import Path
from typing import Any


def parse_range_days(tested_range: str) -> int | None:
    if not tested_range or " - " not in tested_range:
        return None
    left, right = [part.strip() for part in tested_range.split(" - ", 1)]
    try:
        start = datetime.strptime(left, "%Y.%m.%d")
        end = datetime.strptime(right, "%Y.%m.%d")
    except ValueError:
        return None
    return max(1, (end - start).days + 1)


def load_run(path: Path) -> dict[str, Any]:
    data = json.loads(path.read_text(encoding="utf-8"))
    metrics = data.get("metrics", {})
    days = parse_range_days(metrics.get("tested_range", ""))
    trades = float(metrics.get("total_trades", 0.0) or 0.0)
    trades_per_day = trades / days if days else None
    imported_at = data.get("imported_at", "")
    return {
        "path": str(path).replace("\\", "/"),
        "imported_at": imported_at,
        "profit_factor": float(metrics.get("profit_factor", 0.0) or 0.0),
        "net_profit": float(metrics.get("total_net_profit", 0.0) or 0.0),
        "drawdown_percent": float(metrics.get("maximal_drawdown_percent", 0.0) or 0.0),
        "trades": trades,
        "days": days,
        "trades_per_day": trades_per_day,
        "tested_range": metrics.get("tested_range", ""),
        "tags": data.get("tags", []),
    }


def sort_runs(runs: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return sorted(runs, key=lambda item: item.get("imported_at", ""))


def objective_score(run: dict[str, Any], objective: str) -> float:
    pf = run["profit_factor"]
    tpd = run["trades_per_day"] or 0.0
    dd = run["drawdown_percent"]
    if objective == "quality_first":
        return pf * 100.0 - dd * 3.0 + tpd
    if objective == "balanced":
        return pf * 70.0 + tpd * 10.0 - dd * 3.0
    return pf * 50.0 + tpd * 20.0 - dd * 3.0


def classify(
    runs: list[dict[str, Any]],
    objective: str,
    min_pf: float,
    min_trades_per_day: float,
    stagnation_window: int,
    min_relative_score_improvement: float,
) -> tuple[str, list[str]]:
    reasons: list[str] = []
    if not runs:
        return "continue", ["No runs were provided."]

    latest = runs[-1]
    latest_pf = latest["profit_factor"]
    latest_tpd = latest["trades_per_day"] or 0.0

    if latest_pf < 1.0 and len(runs) >= 2 and runs[-2]["profit_factor"] < 1.0:
        reasons.append("Latest two serious runs have PF below 1.0.")
        return "kill", reasons

    if objective == "high_turnover_compounding":
        recent = runs[-stagnation_window:] if len(runs) >= stagnation_window else runs
        all_below_turnover = all((run["trades_per_day"] or 0.0) < min_trades_per_day for run in recent)
        all_quality_positive = all(run["profit_factor"] >= min_pf for run in recent)

        if all_below_turnover and all_quality_positive and len(recent) >= 2:
            scores = [objective_score(run, objective) for run in recent]
            turnover_ratios = [
                ((run["trades_per_day"] or 0.0) / min_trades_per_day) if min_trades_per_day > 0 else 1.0
                for run in recent
            ]
            best_turnover_ratio = max(turnover_ratios) if turnover_ratios else 0.0
            best_before_latest = max(scores[:-1])
            latest_score = scores[-1]
            if best_before_latest <= 0:
                improvement = 0.0
            else:
                improvement = ((latest_score - best_before_latest) / abs(best_before_latest)) * 100.0

            reasons.append(
                f"Recent serious runs remain below the turnover objective ({latest_tpd:.2f} trades/day vs target {min_trades_per_day:.2f})."
            )
            if best_turnover_ratio < 0.50:
                reasons.append(
                    f"Best recent turnover reaches only {best_turnover_ratio * 100.0:.1f}% of the target, which suggests a structural mismatch."
                )
                return "park_secondary_and_open_new_family", reasons
            if improvement < min_relative_score_improvement:
                reasons.append(
                    f"Latest objective-score improvement is only {improvement:.2f}% versus the recent best run."
                )
                return "park_secondary_and_open_new_family", reasons

    if latest_pf < min_pf:
        reasons.append(f"Latest PF {latest_pf:.2f} is below the quality floor {min_pf:.2f}.")
        return "tighten", reasons

    reasons.append("Latest run still clears the quality floor.")
    return "continue", reasons


def render_markdown(
    family_label: str,
    objective: str,
    decision: str,
    reasons: list[str],
    runs: list[dict[str, Any]],
) -> str:
    lines = [
        f"# Strategy Plateau Review: {family_label}",
        "",
        f"- Objective: `{objective}`",
        f"- Decision: `{decision}`",
        "",
        "## Reasons",
        "",
    ]
    for reason in reasons:
        lines.append(f"- {reason}")

    lines.extend(["", "## Reviewed Runs", ""])
    for run in runs:
        tpd = run["trades_per_day"]
        tpd_text = "n/a" if tpd is None else f"{tpd:.2f}"
        lines.extend(
            [
                f"- `{Path(run['path']).name}`",
                f"  - range: `{run['tested_range']}`",
                f"  - PF: `{run['profit_factor']:.2f}`",
                f"  - net: `{run['net_profit']:.2f}`",
                f"  - trades/day: `{tpd_text}`",
                f"  - DD: `{run['drawdown_percent']:.2f}%`",
            ]
        )
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Evaluate whether a strategy family has plateaued.")
    parser.add_argument("--run", action="append", required=True, help="Path to an imported run JSON file.")
    parser.add_argument("--family-label", required=True, help="Human-readable family label.")
    parser.add_argument(
        "--objective",
        choices=["quality_first", "balanced", "high_turnover_compounding"],
        default="high_turnover_compounding",
    )
    parser.add_argument("--min-profit-factor", type=float, default=1.30)
    parser.add_argument("--min-trades-per-day", type=float, default=3.0)
    parser.add_argument("--stagnation-window", type=int, default=3)
    parser.add_argument("--min-relative-score-improvement", type=float, default=10.0)
    parser.add_argument("--output", help="Write JSON output to this path.")
    parser.add_argument("--markdown-output", help="Write Markdown output to this path.")
    args = parser.parse_args()

    runs = sort_runs([load_run(Path(run_path)) for run_path in args.run])
    decision, reasons = classify(
        runs=runs,
        objective=args.objective,
        min_pf=args.min_profit_factor,
        min_trades_per_day=args.min_trades_per_day,
        stagnation_window=args.stagnation_window,
        min_relative_score_improvement=args.min_relative_score_improvement,
    )

    payload = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "family_label": args.family_label,
        "objective": args.objective,
        "decision": decision,
        "reasons": reasons,
        "runs": runs,
    }

    if args.output:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    if args.markdown_output:
        markdown_path = Path(args.markdown_output)
        markdown_path.parent.mkdir(parents=True, exist_ok=True)
        markdown_path.write_text(
            render_markdown(args.family_label, args.objective, decision, reasons, runs),
            encoding="utf-8",
        )

    print(json.dumps(payload, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
