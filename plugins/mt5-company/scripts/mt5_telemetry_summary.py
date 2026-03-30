from __future__ import annotations

import argparse
import csv
import json
from collections import Counter
from datetime import datetime
from pathlib import Path
from typing import Any


TIMESTAMP_FORMAT = "%Y.%m.%d %H:%M:%S"
INT_FIELDS = (
    "daily_closed_trades",
    "daily_entries_buy",
    "daily_entries_sell",
    "consecutive_losses",
    "blocked_spread",
    "blocked_daily_loss",
    "blocked_trade_cap",
    "blocked_loss_lock",
    "blocked_equity_cap",
    "loss_lock_activations",
)
FLOAT_FIELDS = ("price", "volume", "net_profit", "balance", "equity")
DEFAULT_ENCODINGS = ("utf-8-sig", "utf-8", "cp932", "cp1252")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Summarize MT5 telemetry CSV into reusable JSON/Markdown.")
    parser.add_argument("--input", required=True, help="Path to telemetry CSV file.")
    parser.add_argument("--output", help="Optional JSON output path.")
    parser.add_argument("--markdown-output", help="Optional Markdown output path.")
    parser.add_argument("--label", default="", help="Optional label to carry in the summary.")
    parser.add_argument("--run-mode", choices=("all", "latest", "first"), default="all", help="Which run segment to summarize.")
    parser.add_argument("--run-index", type=int, help="Optional explicit run index. Overrides --run-mode.")
    return parser.parse_args()


def load_rows(path: Path) -> list[dict[str, Any]]:
    last_error: Exception | None = None
    for encoding in DEFAULT_ENCODINGS:
        try:
            with path.open("r", encoding=encoding, newline="") as handle:
                reader = csv.DictReader(handle, delimiter=";")
                rows = [dict(row) for row in reader]
            if rows:
                return rows
        except UnicodeDecodeError as exc:
            last_error = exc
            continue

    if last_error is not None:
        raise last_error
    return []


def parse_int(value: str) -> int:
    if value is None or value == "":
        return 0
    return int(float(value))


def parse_float(value: str) -> float:
    if value is None or value == "":
        return 0.0
    return float(value)


def parse_timestamp(value: str) -> datetime | None:
    if not value:
        return None
    return datetime.strptime(value, TIMESTAMP_FORMAT)


def normalize_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    normalized: list[dict[str, Any]] = []
    for row in rows:
        current = dict(row)
        current["timestamp"] = parse_timestamp(current.get("timestamp", ""))
        for field in INT_FIELDS:
            current[field] = parse_int(current.get(field, "0"))
        for field in FLOAT_FIELDS:
            current[field] = parse_float(current.get(field, "0"))
        normalized.append(current)
    return normalized


def split_runs(rows: list[dict[str, Any]]) -> list[list[dict[str, Any]]]:
    if not rows:
        return []

    runs: list[list[dict[str, Any]]] = [[]]
    previous_timestamp: datetime | None = None

    for row in rows:
        current_timestamp = row["timestamp"]
        if runs[-1] and current_timestamp is not None and previous_timestamp is not None and current_timestamp < previous_timestamp:
            runs.append([])
        runs[-1].append(row)
        previous_timestamp = current_timestamp

    return runs


def build_summary(rows: list[dict[str, Any]], source_path: Path, label: str) -> dict[str, Any]:
    if not rows:
        return {
            "label": label,
            "source_path": str(source_path),
            "generated_at": datetime.now().isoformat(timespec="seconds"),
            "row_count": 0,
            "note": "Telemetry file was empty.",
        }

    timestamps = [row["timestamp"] for row in rows if row["timestamp"] is not None]
    event_counts = Counter(row.get("event", "") for row in rows)

    exit_rows = [row for row in rows if row.get("event") == "exit"]
    profits = [row["net_profit"] for row in exit_rows if row["net_profit"] > 0.0]
    losses = [row["net_profit"] for row in exit_rows if row["net_profit"] < 0.0]
    gross_profit = sum(profits)
    gross_loss = abs(sum(losses))
    profit_factor = gross_profit / gross_loss if gross_loss > 0.0 else 0.0

    daily_rows = [row for row in rows if row.get("event") == "daily_summary"]
    entries_per_day = [row["daily_entries_buy"] + row["daily_entries_sell"] for row in daily_rows]
    active_days = [count for count in entries_per_day if count > 0]
    blocked_totals = {
        field: sum(row[field] for row in daily_rows)
        for field in (
            "blocked_spread",
            "blocked_daily_loss",
            "blocked_trade_cap",
            "blocked_loss_lock",
            "blocked_equity_cap",
            "loss_lock_activations",
        )
    }

    top_entry_days = sorted(
        (
            {
                "timestamp": row["timestamp"].isoformat(sep=" ", timespec="seconds") if row["timestamp"] else "",
                "entries": row["daily_entries_buy"] + row["daily_entries_sell"],
                "closed_trades": row["daily_closed_trades"],
                "net_profit": row["net_profit"],
            }
            for row in daily_rows
        ),
        key=lambda item: (item["entries"], item["net_profit"]),
        reverse=True,
    )[:5]

    top_spread_days = sorted(
        (
            {
                "timestamp": row["timestamp"].isoformat(sep=" ", timespec="seconds") if row["timestamp"] else "",
                "blocked_spread": row["blocked_spread"],
                "entries": row["daily_entries_buy"] + row["daily_entries_sell"],
                "net_profit": row["net_profit"],
            }
            for row in daily_rows
        ),
        key=lambda item: item["blocked_spread"],
        reverse=True,
    )[:5]

    return {
        "label": label,
        "source_path": str(source_path),
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "period": {
            "start": timestamps[0].isoformat(sep=" ", timespec="seconds") if timestamps else "",
            "end": timestamps[-1].isoformat(sep=" ", timespec="seconds") if timestamps else "",
        },
        "row_count": len(rows),
        "event_counts": dict(event_counts),
        "daily": {
            "summaries": len(daily_rows),
            "active_days": len(active_days),
            "avg_entries_per_day": round(sum(entries_per_day) / len(entries_per_day), 4) if entries_per_day else 0.0,
            "avg_entries_per_active_day": round(sum(active_days) / len(active_days), 4) if active_days else 0.0,
            "max_entries_per_day": max(entries_per_day) if entries_per_day else 0,
            "blocked_totals": blocked_totals,
        },
        "exits": {
            "count": len(exit_rows),
            "wins": len(profits),
            "losses": len(losses),
            "net_profit": round(sum(row["net_profit"] for row in exit_rows), 4),
            "gross_profit": round(gross_profit, 4),
            "gross_loss": round(-gross_loss, 4),
            "profit_factor": round(profit_factor, 4),
            "average_win": round(gross_profit / len(profits), 4) if profits else 0.0,
            "average_loss": round(sum(losses) / len(losses), 4) if losses else 0.0,
        },
        "top_days": {
            "entries": top_entry_days,
            "spread_blocked": top_spread_days,
        },
    }


def build_markdown(summary: dict[str, Any]) -> str:
    daily = summary.get("daily", {})
    exits = summary.get("exits", {})
    lines = [
        "# MT5 Telemetry Summary",
        "",
        f"- Label: `{summary.get('label', '')}`",
        f"- Source: `{summary.get('source_path', '')}`",
        f"- Run count in file: `{summary.get('run_count', 0)}`",
        f"- Selected run index: `{summary.get('selected_run_index', 'all')}`",
        f"- Period: `{summary.get('period', {}).get('start', '')}` -> `{summary.get('period', {}).get('end', '')}`",
        f"- Rows: `{summary.get('row_count', 0)}`",
        "",
        "## Daily",
        "",
        f"- Summary rows: `{daily.get('summaries', 0)}`",
        f"- Active days: `{daily.get('active_days', 0)}`",
        f"- Avg entries/day: `{daily.get('avg_entries_per_day', 0.0)}`",
        f"- Avg entries/active day: `{daily.get('avg_entries_per_active_day', 0.0)}`",
        f"- Max entries/day: `{daily.get('max_entries_per_day', 0)}`",
        "",
        "## Exits",
        "",
        f"- Exit count: `{exits.get('count', 0)}`",
        f"- Wins: `{exits.get('wins', 0)}`",
        f"- Losses: `{exits.get('losses', 0)}`",
        f"- Net profit: `{exits.get('net_profit', 0.0)}`",
        f"- Profit factor: `{exits.get('profit_factor', 0.0)}`",
        f"- Average win: `{exits.get('average_win', 0.0)}`",
        f"- Average loss: `{exits.get('average_loss', 0.0)}`",
        "",
        "## Blockers",
        "",
    ]

    for field, value in daily.get("blocked_totals", {}).items():
        lines.append(f"- {field}: `{value}`")

    lines.extend(["", "## Event Counts", ""])
    for field, value in summary.get("event_counts", {}).items():
        lines.append(f"- {field}: `{value}`")

    lines.extend(["", "## Top Entry Days", ""])
    for item in summary.get("top_days", {}).get("entries", []):
        lines.append(
            f"- `{item['timestamp']}` entries=`{item['entries']}` closed=`{item['closed_trades']}` net=`{item['net_profit']}`"
        )

    lines.extend(["", "## Top Spread-Blocked Days", ""])
    for item in summary.get("top_days", {}).get("spread_blocked", []):
        lines.append(
            f"- `{item['timestamp']}` blocked_spread=`{item['blocked_spread']}` entries=`{item['entries']}` net=`{item['net_profit']}`"
        )

    lines.append("")
    return "\n".join(lines)


def write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def main() -> None:
    args = parse_args()
    source_path = Path(args.input).resolve()
    rows = normalize_rows(load_rows(source_path))
    runs = split_runs(rows)

    if args.run_index is not None:
        selected_index = args.run_index
        selected_rows = runs[selected_index]
    elif args.run_mode == "latest":
        selected_index = len(runs) - 1
        selected_rows = runs[-1]
    elif args.run_mode == "first":
        selected_index = 0
        selected_rows = runs[0]
    else:
        selected_index = None
        selected_rows = rows

    summary = build_summary(selected_rows, source_path, args.label)
    summary["run_count"] = len(runs)
    summary["selected_run_index"] = selected_index

    if args.output:
        output_path = Path(args.output).resolve()
        write_text(output_path, json.dumps(summary, indent=2, ensure_ascii=False))

    if args.markdown_output:
        markdown_path = Path(args.markdown_output).resolve()
        write_text(markdown_path, build_markdown(summary))

    print(
        json.dumps(
            {
                "label": summary.get("label", ""),
                "row_count": summary.get("row_count", 0),
                "avg_entries_per_day": summary.get("daily", {}).get("avg_entries_per_day", 0.0),
                "profit_factor": summary.get("exits", {}).get("profit_factor", 0.0),
                "blocked_spread": summary.get("daily", {}).get("blocked_totals", {}).get("blocked_spread", 0),
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
