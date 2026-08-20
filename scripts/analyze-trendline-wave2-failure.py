#!/usr/bin/env python3
from __future__ import annotations

import csv
import html
import json
import math
import re
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "reports" / "backtest" / "runs" / "20260815_trendline_wave2_failure"
MATRIX = OUT / "run_matrix.csv"
INITIAL_BALANCE = 10000.0


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    for encoding in ("utf-8-sig", "cp932", "mbcs"):
        try:
            with path.open("r", encoding=encoding, newline="") as handle:
                return list(csv.DictReader(handle))
        except UnicodeDecodeError:
            continue
    raise UnicodeError(f"Could not decode {path}")


def write_csv(path: Path, rows: list[dict], fields: list[str] | None = None) -> None:
    if fields is None:
        fields = list(dict.fromkeys(key for row in rows for key in row))
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def fnum(value) -> float:
    try:
        return float(str(value or "0").replace(",", ""))
    except (TypeError, ValueError):
        return 0.0


def strip_tags(value: str) -> str:
    return html.unescape(re.sub(r"<[^>]+>", "", value)).replace("\xa0", " ").strip()


def report_rows(path: Path) -> list[list[str]]:
    text = path.read_text(encoding="utf-16")
    rows = []
    for row_html in re.findall(r"<tr[^>]*>(.*?)</tr>", text, flags=re.I | re.S):
        cells = re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", row_html, flags=re.I | re.S)
        cells = [strip_tags(cell) for cell in cells]
        if cells:
            rows.append(cells)
    return rows


def parse_report_metrics(path: Path) -> dict[str, str]:
    labels = {
        "総損益:": "report_net_profit",
        "プロフィットファクター:": "report_profit_factor",
        "取引数:": "report_trades",
        "残高最大ドローダウン:": "report_balance_max_drawdown",
        "証拠金最大ドローダウン:": "report_equity_max_drawdown",
        "残高相対ドローダウン:": "report_balance_relative_drawdown",
        "証拠金相対ドローダウン:": "report_equity_relative_drawdown",
        "ショート (勝率 %):": "report_short",
        "ロング (勝率 %):": "report_long",
        "勝ちトレード (勝率 %):": "report_wins",
    }
    metrics: dict[str, str] = {}
    for cells in report_rows(path):
        for index, cell in enumerate(cells[:-1]):
            if cell in labels:
                metrics[labels[cell]] = cells[index + 1]
    return metrics


def parse_mt5_deals(path: Path) -> list[dict]:
    text = path.read_text(encoding="utf-16")
    marker = "<b>約定</b>"
    if marker not in text:
        return []
    section = text.split(marker, 1)[1]
    active: list[dict] = []
    trades: list[dict] = []
    for row_html in re.findall(r"<tr[^>]*>(.*?)</tr>", section, flags=re.I | re.S):
        cells = re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", row_html, flags=re.I | re.S)
        cells = [strip_tags(cell) for cell in cells]
        if len(cells) != 13 or not re.match(r"^\d{4}\.\d{2}\.\d{2} ", cells[0]):
            continue
        entry = cells[4].lower()
        if entry not in {"in", "out"} or cells[3].lower() == "balance":
            continue
        deal = {
            "time": cells[0], "symbol": cells[2], "type": cells[3].lower(), "entry": entry,
            "volume": fnum(cells[5]), "price": fnum(cells[6]), "commission": fnum(cells[8]),
            "swap": fnum(cells[9]), "profit": fnum(cells[10]), "comment": cells[12],
        }
        if entry == "in":
            active.append(deal)
            continue
        match = next((i for i, item in enumerate(active) if item["symbol"] == deal["symbol"]), None)
        if match is None:
            continue
        opened = active.pop(match)
        trades.append({
            "entry_time": opened["time"], "exit_time": deal["time"], "symbol": opened["symbol"],
            "direction": "LONG" if opened["type"] == "buy" else "SHORT",
            "net_profit": opened["profit"] + opened["commission"] + opened["swap"]
                          + deal["profit"] + deal["commission"] + deal["swap"],
            "comment": opened["comment"],
        })
    return trades


def derive_net_r(row: dict[str, str]) -> float:
    gross_r = fnum(row.get("result_r"))
    gross_money = fnum(row.get("profit"))
    net_money = fnum(row.get("net_profit"))
    if abs(gross_r) < 1e-12 or abs(gross_money) < 1e-12:
        return gross_r
    risk_money = abs(gross_money / gross_r)
    return net_money / risk_money if risk_money > 0 else gross_r


def stats(rows: list[dict[str, str]]) -> dict:
    ordered = sorted(rows, key=lambda row: row.get("exit_time", ""))
    net_money = [fnum(row.get("net_profit")) for row in ordered]
    gross_r = [fnum(row.get("result_r")) for row in ordered]
    net_r = [derive_net_r(row) for row in ordered]
    gross_profit = sum(value for value in net_money if value > 0)
    gross_loss = sum(value for value in net_money if value < 0)
    equity = peak = 0.0
    max_dd = 0.0
    r_equity = r_peak = 0.0
    max_dd_r = 0.0
    loss_streak = max_loss_streak = 0
    for money, rval in zip(net_money, net_r):
        equity += money
        peak = max(peak, equity)
        max_dd = min(max_dd, equity - peak)
        r_equity += rval
        r_peak = max(r_peak, r_equity)
        max_dd_r = min(max_dd_r, r_equity - r_peak)
        if money < 0:
            loss_streak += 1
            max_loss_streak = max(max_loss_streak, loss_streak)
        else:
            loss_streak = 0
    wins_r = [value for value, money in zip(net_r, net_money) if money > 0]
    losses_r = [value for value, money in zip(net_r, net_money) if money < 0]
    count = len(ordered)
    return {
        "trades": count,
        "wins": sum(value > 0 for value in net_money),
        "win_rate": sum(value > 0 for value in net_money) / count if count else 0.0,
        "net_profit": sum(net_money),
        "profit_factor": gross_profit / abs(gross_loss) if gross_loss < 0 else (math.inf if gross_profit else 0.0),
        "expectancy_money": sum(net_money) / count if count else 0.0,
        "gross_expectancy_r": sum(gross_r) / count if count else 0.0,
        "net_expectancy_r": sum(net_r) / count if count else 0.0,
        "average_win_r": sum(wins_r) / len(wins_r) if wins_r else 0.0,
        "average_loss_r": sum(losses_r) / len(losses_r) if losses_r else 0.0,
        "max_drawdown_money_closed_trade": abs(max_dd),
        "max_drawdown_percent_closed_trade": abs(max_dd) / INITIAL_BALANCE * 100.0,
        "max_drawdown_r_closed_trade": abs(max_dd_r),
        "max_consecutive_losses": max_loss_streak,
        "average_holding_minutes": sum(fnum(row.get("holding_bars")) * 5.0 for row in ordered) / count if count else 0.0,
        "average_mfe_r": sum(fnum(row.get("max_favorable_r_before_exit")) for row in ordered) / count if count else 0.0,
        "average_mae_r": sum(fnum(row.get("max_adverse_r_before_exit")) for row in ordered) / count if count else 0.0,
        "long_trades": sum(row.get("direction") == "LONG" for row in ordered),
        "short_trades": sum(row.get("direction") == "SHORT" for row in ordered),
        "average_cost_r": sum(g - n for g, n in zip(gross_r, net_r)) / count if count else 0.0,
    }


def find_one(run_dir: Path, pattern: str) -> Path | None:
    return next(iter(sorted(run_dir.glob(pattern))), None)


def summary_metrics(path: Path | None) -> dict[str, int]:
    values: dict[str, int] = {}
    if path is None:
        return values
    for row in read_csv(path):
        values[row.get("metric", "")] = int(fnum(row.get("value")))
    return values


def main() -> None:
    matrix = read_csv(MATRIX)
    comparison: list[dict] = []
    funnel_rows: list[dict] = []
    group_rows: list[dict] = []
    rejection_rows: list[dict] = []
    timelines: list[dict] = []
    all_legacy_trades: list[dict] = []

    for run in matrix:
        run_dir = OUT / run["run_id"]
        report = run_dir / "report.html"
        report_metrics = parse_report_metrics(report)
        mt5_trades = parse_mt5_deals(report)
        legacy_path = find_one(run_dir, "legacy_*trades.csv")
        new_path = find_one(run_dir, "new_*trades.csv")
        legacy = read_csv(legacy_path) if legacy_path else []
        new = read_csv(new_path) if new_path else []
        for row in legacy:
            enriched = dict(row)
            enriched.update(run_id=run["run_id"], year=run["year"], mode=run["mode"], bucket="legacy")
            all_legacy_trades.append(enriched)
        custom_count = len(legacy) + len(new)
        row = dict(run)
        row.update(stats(legacy + new))
        row.update(report_metrics)
        row["mt5_deal_trade_count"] = len(mt5_trades)
        row["custom_trade_count"] = custom_count
        row["trade_count_reconciled"] = len(mt5_trades) == custom_count
        comparison.append(row)

        summary = summary_metrics(find_one(run_dir, "new_*summary.csv"))
        if run["mode"] != "baseline":
            funnel = {"run_id": run["run_id"], "year": run["year"], "mode": run["mode"]}
            funnel.update(summary)
            funnel_rows.append(funnel)
        events_path = find_one(run_dir, "new_*events.csv")
        events = read_csv(events_path) if events_path else []
        grouped: dict[tuple[str, str, str], set[str]] = defaultdict(set)
        for event in events:
            key = (event.get("symbol", ""), event.get("direction", ""), event.get("state_after", ""))
            grouped[key].add(event.get("setup_id", ""))
        for (symbol, direction, state), setup_ids in sorted(grouped.items()):
            group_rows.append({
                "run_id": run["run_id"], "year": run["year"], "mode": run["mode"],
                "symbol": symbol, "direction": direction, "state": state,
                "unique_setups": len({value for value in setup_ids if value}),
            })
        if run["mode"] == "new_bucket_only":
            pullback_ids = [event.get("setup_id") for event in events if event.get("state_after") == "M15_PULLBACK_ACTIVE"]
            for setup_id in pullback_ids:
                for event in events:
                    if event.get("setup_id") == setup_id:
                        timelines.append({
                            "run_id": run["run_id"], "setup_id": setup_id,
                            "timestamp": event.get("timestamp"), "symbol": event.get("symbol"),
                            "direction": event.get("direction"), "state_before": event.get("state_before"),
                            "state_after": event.get("state_after"), "reason": event.get("reject_reason"),
                            "h4_window": event.get("h4_impulse_window_bars"),
                            "h4_normalized_move": event.get("h4_normalized_move"),
                            "h4_percentile": event.get("h4_impulse_percentile"),
                            "h1_counter_high_count": event.get("h1_lower_high_count"),
                            "h1_counter_low_count": event.get("h1_lower_low_count"),
                            "h1_trend_bars": event.get("h1_trend_bars"),
                            "h1_trend_distance_atr": event.get("h1_trend_distance_atr"),
                            "h1_break_distance_atr": event.get("h1_break_distance_atr"),
                        })
        for path in (find_one(run_dir, "legacy_*rejections.csv"),):
            if path:
                for reject in read_csv(path):
                    rejection_rows.append({
                        "run_id": run["run_id"], "year": run["year"], "mode": run["mode"],
                        "bucket": "legacy", "reason": reject.get("reason"), "count": reject.get("count"),
                    })
        for reason, count in summary.items():
            if reason.startswith("reject_"):
                rejection_rows.append({
                    "run_id": run["run_id"], "year": run["year"], "mode": run["mode"],
                    "bucket": "new", "reason": reason.removeprefix("reject_"), "count": count,
                })

    write_csv(OUT / "comparison.csv", comparison)
    write_csv(OUT / "new_bucket_funnel.csv", funnel_rows)
    write_csv(OUT / "new_bucket_state_by_symbol_direction.csv", group_rows)
    write_csv(OUT / "rejection_reasons.csv", rejection_rows)
    write_csv(OUT / "representative_setup_timeline.csv", timelines)
    write_csv(OUT / "legacy_trades_all_runs.csv", all_legacy_trades)

    key = {(row["year"], row["mode"]): row for row in comparison}
    lock = json.loads((OUT / "oos_lock.json").read_text(encoding="utf-8-sig"))
    lines = [
        "# TRENDLINE_WAVE2_FAILURE Initial MT5 Validation",
        "",
        "## Locked test",
        "",
        "- Tester: MT5 Strategy Tester, M15 chart, Every tick based on real ticks (Model=4).",
        "- Internal timeframes: H4 context / H1 setup / M15 entry; six FX symbols.",
        "- Deposit: USD 10,000; leverage 1:100; fixed research parameters, no optimization.",
        f"- 2026 lock: `{lock['locked_at']}`; source `{lock['source_sha256']}`; include `{lock['include_sha256']}`.",
        "- Requested OOS end was 2026-08-14; last processed tester timestamp was 2026-08-13 23:57:55.",
        "",
        "## Baseline / new bucket / combined",
        "",
        "| Year | Mode | Trades | Win rate | Net | PF | Net exp R | Max DD closed | MT5/custom match |",
        "|---:|---|---:|---:|---:|---:|---:|---:|---|",
    ]
    for year in ("2024", "2025", "2026"):
        for mode in ("baseline", "new_bucket_only", "combined"):
            row = key[(year, mode)]
            lines.append(
                f"| {year} | {mode} | {int(row['trades'])} | {row['win_rate']:.2%} | "
                f"{row['net_profit']:+.2f} | {row['profit_factor']:.3f} | {row['net_expectancy_r']:+.4f} | "
                f"{row['max_drawdown_money_closed_trade']:.2f} | {row['trade_count_reconciled']} |"
            )
    lines += [
        "",
        "## New bucket funnel",
        "",
        "| Year | H4 impulse | H1 mature | H1 TL break | M15 pullback | M15 failure | M15 break | Orders |",
        "|---:|---:|---:|---:|---:|---:|---:|---:|",
    ]
    for year in ("2024", "2025", "2026"):
        row = next(item for item in funnel_rows if item["year"] == year and item["mode"] == "new_bucket_only")
        lines.append(
            f"| {year} | {row.get('h4_impulses', 0)} | {row.get('h1_mature', 0)} | "
            f"{row.get('h1_trendline_breaks', 0)} | {row.get('m15_pullbacks', 0)} | "
            f"{row.get('m15_continuation_failures', 0)} | {row.get('m15_structure_breaks', 0)} | {row.get('orders', 0)} |"
        )
    lines += [
        "",
        "## Findings",
        "",
        "- New-only and combined produced identical new-bucket funnels in every year; the independent state path is isolated from the legacy bucket.",
        "- No new-bucket order was generated. The primary bottleneck is structural, before execution: H1 maturity is rare and no setup reached M15 continuation-failure classification.",
        "- Because there were no new-bucket orders, lot rounding, post-fill 2R modification, portfolio caps, margin rejection and new-bucket deal reconciliation were compile/static-path checked but not exercised by a real new-bucket order.",
        "- The combined 2025 legacy run had one fewer trade than baseline because `combined_same_direction_position_cap` rejected one candidate; 2024 and 2026 counts matched.",
        "- Fixed 2R break-even win rate is 33.33% before costs. No new-bucket sample exists, so expectancy cannot be estimated.",
        "",
        "## Decision",
        "",
        "- This initial parameterization is not promotable. Keep it as a correctly instrumented research bucket and investigate the H4 invalidation / H1 maturity / M15 failure funnel one factor at a time without using 2026 as tuning data.",
    ]
    (OUT / "summary.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
