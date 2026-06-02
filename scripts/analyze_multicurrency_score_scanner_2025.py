#!/usr/bin/env python3
from __future__ import annotations

import csv
import html
import json
import math
import re
from collections import Counter, defaultdict
from datetime import datetime, timedelta
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BACKTEST = ROOT / "reports" / "backtest"

STOP_ON_PREFIX = "ExpectedValue_MultiCurrency_ScoreScanner_2025"
STOP_OFF_PREFIX = "ExpectedValue_MultiCurrency_ScoreScanner_2025_no_stops"
OUT_PREFIX = "ExpectedValue_MultiCurrency_ScoreScanner_2025_failure"

INITIAL_BALANCE = 10000.0
STOP_ON_DD_STOP_TIME = datetime(2025, 2, 25, 3, 29, 59)


def parse_time(value: str) -> datetime:
    return datetime.strptime(value.strip(), "%Y.%m.%d %H:%M:%S")


def m5_bar(value: datetime) -> datetime:
    minute = value.minute - value.minute % 5
    return value.replace(minute=minute, second=0, microsecond=0)


def to_float(value: str) -> float:
    cleaned = value.replace("\xa0", "").replace(" ", "").replace(",", "").strip()
    if cleaned == "":
        return 0.0
    return float(cleaned)


def strip_tags(value: str) -> str:
    value = re.sub(r"<[^>]+>", "", value)
    return html.unescape(value).strip()


def cells_from_row(row_html: str) -> list[str]:
    cells = re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", row_html, flags=re.I | re.S)
    return [strip_tags(cell) for cell in cells]


def parse_mt5_deals(report_path: Path) -> list[dict[str, object]]:
    text = report_path.read_text(encoding="utf-16")
    marker = "<b>約定</b>"
    if marker not in text:
        raise RuntimeError(f"Deal table marker not found in {report_path}")
    deal_section = text.split(marker, 1)[1]

    active: list[dict[str, object]] = []
    trades: list[dict[str, object]] = []

    for row_html in re.findall(r"<tr[^>]*>(.*?)</tr>", deal_section, flags=re.I | re.S):
        cells = cells_from_row(row_html)
        if len(cells) != 13:
            continue
        if not re.match(r"^\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}$", cells[0]):
            continue

        deal_type = cells[3].lower()
        if deal_type == "balance":
            continue

        entry = cells[4].lower()
        if entry not in {"in", "out"}:
            continue

        deal = {
            "time": parse_time(cells[0]),
            "deal": cells[1],
            "symbol": cells[2],
            "type": deal_type,
            "entry": entry,
            "volume": to_float(cells[5]),
            "price": to_float(cells[6]),
            "order": cells[7],
            "commission": to_float(cells[8]),
            "swap": to_float(cells[9]),
            "profit": to_float(cells[10]),
            "balance": to_float(cells[11]),
            "comment": cells[12],
        }

        if entry == "in":
            active.append(deal)
            continue

        match_index = next((idx for idx, item in enumerate(active) if item["symbol"] == deal["symbol"]), None)
        if match_index is None:
            match_index = 0 if active else None
        if match_index is None:
            raise RuntimeError(f"Close deal without open deal: {deal}")

        open_deal = active.pop(match_index)
        direction = "LONG" if open_deal["type"] == "buy" else "SHORT"
        net_profit = (
            float(open_deal["commission"])
            + float(open_deal["swap"])
            + float(open_deal["profit"])
            + float(deal["commission"])
            + float(deal["swap"])
            + float(deal["profit"])
        )
        open_time = open_deal["time"]
        close_time = deal["time"]
        trades.append(
            {
                "open_time": open_time,
                "close_time": close_time,
                "symbol": open_deal["symbol"],
                "direction": direction,
                "volume": open_deal["volume"],
                "open_price": open_deal["price"],
                "close_price": deal["price"],
                "open_deal": open_deal["deal"],
                "close_deal": deal["deal"],
                "commission": float(open_deal["commission"]) + float(deal["commission"]),
                "swap": float(open_deal["swap"]) + float(deal["swap"]),
                "profit": float(open_deal["profit"]) + float(deal["profit"]),
                "net_profit": net_profit,
                "close_balance": deal["balance"],
                "close_comment": deal["comment"],
                "holding_minutes": round((close_time - open_time).total_seconds() / 60.0, 2),
                "open_bar_m5": m5_bar(open_time),
                "close_bar_m5": m5_bar(close_time),
            }
        )

    if active:
        raise RuntimeError(f"Unclosed active deals remained: {len(active)}")
    return trades


def trade_to_row(trade: dict[str, object]) -> dict[str, object]:
    row = dict(trade)
    for key in ("open_time", "close_time", "open_bar_m5", "close_bar_m5"):
        row[key] = row[key].strftime("%Y.%m.%d %H:%M:%S")
    return row


def write_trades(path: Path, trades: list[dict[str, object]]) -> None:
    fields = [
        "open_time",
        "close_time",
        "symbol",
        "direction",
        "volume",
        "open_price",
        "close_price",
        "open_deal",
        "close_deal",
        "commission",
        "swap",
        "profit",
        "net_profit",
        "close_balance",
        "close_comment",
        "holding_minutes",
        "open_bar_m5",
        "close_bar_m5",
    ]
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields)
        writer.writeheader()
        for trade in trades:
            writer.writerow(trade_to_row(trade))


def read_trades(path: Path) -> list[dict[str, object]]:
    trades: list[dict[str, object]] = []
    with path.open(newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            parsed = dict(row)
            for key in ("open_time", "close_time", "open_bar_m5", "close_bar_m5"):
                parsed[key] = parse_time(str(parsed[key]))
            for key in (
                "volume",
                "open_price",
                "close_price",
                "commission",
                "swap",
                "profit",
                "net_profit",
                "close_balance",
                "holding_minutes",
            ):
                parsed[key] = float(parsed[key])
            trades.append(parsed)
    return trades


def profit_factor(gross_profit: float, gross_loss: float) -> float | None:
    if gross_loss == 0:
        return None
    return gross_profit / abs(gross_loss)


def calc_stats(trades: list[dict[str, object]]) -> dict[str, object]:
    profits = [float(t["net_profit"]) for t in trades]
    wins = [p for p in profits if p > 0]
    losses = [p for p in profits if p < 0]
    gross_profit = sum(wins)
    gross_loss = sum(losses)

    balance = INITIAL_BALANCE
    peak = balance
    max_dd = 0.0
    max_dd_pct = 0.0
    max_dd_time = None
    for trade in trades:
        balance += float(trade["net_profit"])
        if balance > peak:
            peak = balance
        dd = peak - balance
        dd_pct = (dd / peak * 100.0) if peak else 0.0
        if dd > max_dd:
            max_dd = dd
            max_dd_pct = dd_pct
            max_dd_time = trade["close_time"]

    max_wins = {"count": 0, "amount": 0.0, "start": None, "end": None}
    max_losses = {"count": 0, "amount": 0.0, "start": None, "end": None}
    current_sign = None
    current_count = 0
    current_amount = 0.0
    current_start = None
    current_end = None

    def finalize(sign: str | None, count: int, amount: float, start, end) -> None:
        nonlocal max_wins, max_losses
        if sign == "win" and count > max_wins["count"]:
            max_wins = {"count": count, "amount": amount, "start": start, "end": end}
        if sign == "loss" and count > max_losses["count"]:
            max_losses = {"count": count, "amount": amount, "start": start, "end": end}

    for trade, profit in zip(trades, profits):
        sign = "win" if profit > 0 else "loss" if profit < 0 else "flat"
        if sign == "flat":
            finalize(current_sign, current_count, current_amount, current_start, current_end)
            current_sign = None
            current_count = 0
            current_amount = 0.0
            current_start = None
            current_end = None
            continue
        if sign != current_sign:
            finalize(current_sign, current_count, current_amount, current_start, current_end)
            current_sign = sign
            current_count = 0
            current_amount = 0.0
            current_start = trade["open_time"]
        current_count += 1
        current_amount += profit
        current_end = trade["close_time"]
    finalize(current_sign, current_count, current_amount, current_start, current_end)

    return {
        "trades": len(trades),
        "wins": len(wins),
        "losses": len(losses),
        "win_rate": (len(wins) / len(trades) * 100.0) if trades else 0.0,
        "net_profit": sum(profits),
        "gross_profit": gross_profit,
        "gross_loss": gross_loss,
        "profit_factor": profit_factor(gross_profit, gross_loss),
        "expected_payoff": (sum(profits) / len(trades)) if trades else 0.0,
        "avg_win": (gross_profit / len(wins)) if wins else 0.0,
        "avg_loss": (gross_loss / len(losses)) if losses else 0.0,
        "max_balance_dd": max_dd,
        "max_balance_dd_pct": max_dd_pct,
        "max_balance_dd_time": max_dd_time,
        "max_consecutive_wins": max_wins,
        "max_consecutive_losses": max_losses,
    }


def group_stats(trades: list[dict[str, object]], key_fn) -> list[dict[str, object]]:
    buckets: dict[str, list[dict[str, object]]] = defaultdict(list)
    for trade in trades:
        buckets[str(key_fn(trade))].append(trade)
    rows = []
    for key, bucket in sorted(buckets.items()):
        stats = calc_stats(bucket)
        rows.append(
            {
                "group": key,
                "trades": stats["trades"],
                "wins": stats["wins"],
                "losses": stats["losses"],
                "win_rate": round(float(stats["win_rate"]), 2),
                "net_profit": round(float(stats["net_profit"]), 2),
                "gross_profit": round(float(stats["gross_profit"]), 2),
                "gross_loss": round(float(stats["gross_loss"]), 2),
                "profit_factor": round(float(stats["profit_factor"]), 3) if stats["profit_factor"] is not None else "",
                "expected_payoff": round(float(stats["expected_payoff"]), 2),
                "avg_win": round(float(stats["avg_win"]), 2),
                "avg_loss": round(float(stats["avg_loss"]), 2),
            }
        )
    return rows


def score_band(score: float | None) -> str:
    if score is None or math.isnan(score):
        return "unmatched"
    if score < 60:
        return "<60"
    if score < 65:
        return "60-65"
    if score < 70:
        return "65-70"
    if score < 75:
        return "70-75"
    if score < 80:
        return "75-80"
    return "80+"


def scan_scores(path: Path) -> tuple[dict[str, object], list[dict[str, object]]]:
    flags = Counter()
    entry_by_symbol = Counter()
    entry_by_direction = Counter()
    best_by_symbol = Counter()
    best_by_direction = Counter()
    entries: list[dict[str, object]] = []
    row_count = 0
    unique_times = set()

    with path.open(newline="", encoding="utf-8-sig") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            row_count += 1
            unique_times.add(row["time"])
            reason = row.get("reason", "")
            for flag in (
                "best_candidate",
                "entry_score_ok",
                "below_threshold",
                "not_best",
                "max_drawdown_stop",
                "daily_loss_stop",
                "weekly_loss_stop",
                "max_positions_reached",
                "same_currency_group_limit",
            ):
                if flag in reason:
                    flags[flag] += 1

            if "best_candidate" in reason:
                best_by_symbol[row["symbol"]] += 1
                best_by_direction[row["direction"]] += 1

            if "entry_score_ok" in reason:
                entry_by_symbol[row["symbol"]] += 1
                entry_by_direction[row["direction"]] += 1
                entries.append(
                    {
                        "time": parse_time(row["time"]),
                        "symbol": row["symbol"],
                        "direction": row["direction"],
                        "totalScore": float(row["totalScore"]),
                        "trendScore": float(row["trendScore"]),
                        "setupScore": float(row["setupScore"]),
                        "volatilityScore": float(row["volatilityScore"]),
                        "costPenalty": float(row["costPenalty"]),
                        "riskPenalty": float(row["riskPenalty"]),
                        "reason": reason,
                    }
                )

    summary = {
        "rows": row_count,
        "unique_times": len(unique_times),
        "flags": dict(flags),
        "entry_by_symbol": dict(entry_by_symbol),
        "entry_by_direction": dict(entry_by_direction),
        "best_by_symbol": dict(best_by_symbol),
        "best_by_direction": dict(best_by_direction),
    }
    return summary, entries


def join_trades_to_scores(run_name: str, trades: list[dict[str, object]], score_entries: list[dict[str, object]]) -> list[dict[str, object]]:
    by_key: dict[tuple[str, str], list[dict[str, object]]] = defaultdict(list)
    for entry in score_entries:
        by_key[(entry["symbol"], entry["direction"])].append(entry)
    for entries in by_key.values():
        entries.sort(key=lambda item: item["time"])

    joined = []
    for index, trade in enumerate(trades, start=1):
        key = (str(trade["symbol"]), str(trade["direction"]))
        open_time = trade["open_time"]
        candidates = by_key.get(key, [])
        best = None
        best_delta = None
        for entry in candidates:
            delta = (open_time - entry["time"]).total_seconds()
            if -5 <= delta <= 300:
                if best_delta is None or abs(delta) < abs(best_delta):
                    best = entry
                    best_delta = delta
        total_score = float(best["totalScore"]) if best else None
        joined.append(
            {
                "run": run_name,
                "trade_index": index,
                "open_time": open_time.strftime("%Y.%m.%d %H:%M:%S"),
                "close_time": trade["close_time"].strftime("%Y.%m.%d %H:%M:%S"),
                "symbol": trade["symbol"],
                "direction": trade["direction"],
                "net_profit": round(float(trade["net_profit"]), 2),
                "close_comment": trade["close_comment"],
                "score_time": best["time"].strftime("%Y.%m.%d %H:%M:%S") if best else "",
                "score_delta_seconds": int(best_delta) if best_delta is not None else "",
                "totalScore": round(total_score, 2) if total_score is not None else "",
                "trendScore": round(float(best["trendScore"]), 2) if best else "",
                "setupScore": round(float(best["setupScore"]), 2) if best else "",
                "volatilityScore": round(float(best["volatilityScore"]), 2) if best else "",
                "costPenalty": round(float(best["costPenalty"]), 2) if best else "",
                "riskPenalty": round(float(best["riskPenalty"]), 2) if best else "",
                "score_band": score_band(total_score),
                "score_reason": best["reason"] if best else "",
            }
        )
    return joined


def write_rows(path: Path, rows: list[dict[str, object]]) -> None:
    if not rows:
        return
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def write_group_csv(path: Path, run_trades: dict[str, list[dict[str, object]]], key_fn) -> None:
    rows: list[dict[str, object]] = []
    for run_name, trades in run_trades.items():
        for row in group_stats(trades, key_fn):
            row = {"run": run_name, **row}
            rows.append(row)
    write_rows(path, rows)


def find_same_bar_reentries(trades: list[dict[str, object]]) -> int:
    count = 0
    for prev, current in zip(trades, trades[1:]):
        if prev["close_bar_m5"] == current["open_bar_m5"]:
            count += 1
    return count


def serialize_stats(stats: dict[str, object]) -> dict[str, object]:
    result = {}
    for key, value in stats.items():
        if isinstance(value, datetime):
            result[key] = value.strftime("%Y.%m.%d %H:%M:%S")
        elif isinstance(value, dict):
            nested = {}
            for nested_key, nested_value in value.items():
                nested[nested_key] = (
                    nested_value.strftime("%Y.%m.%d %H:%M:%S")
                    if isinstance(nested_value, datetime)
                    else nested_value
                )
            result[key] = nested
        else:
            result[key] = value
    return result


def main() -> None:
    stop_off_report = BACKTEST / f"{STOP_OFF_PREFIX}_report.html"
    stop_off_trades = parse_mt5_deals(stop_off_report)
    write_trades(BACKTEST / f"{STOP_OFF_PREFIX}_trades.csv", stop_off_trades)

    runs = {
        "stop_on": read_trades(BACKTEST / f"{STOP_ON_PREFIX}_trades.csv"),
        "stop_off": stop_off_trades,
    }

    score_summaries: dict[str, dict[str, object]] = {}
    score_entries: dict[str, list[dict[str, object]]] = {}
    for run_name, prefix in (("stop_on", STOP_ON_PREFIX), ("stop_off", STOP_OFF_PREFIX)):
        summary, entries = scan_scores(BACKTEST / f"{prefix}_scores.csv")
        score_summaries[run_name] = summary
        score_entries[run_name] = entries

    joined: list[dict[str, object]] = []
    for run_name, trades in runs.items():
        joined.extend(join_trades_to_scores(run_name, trades, score_entries[run_name]))
    write_rows(BACKTEST / f"{OUT_PREFIX}_trade_join.csv", joined)

    joined_by_run: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in joined:
        joined_by_run[str(row["run"])].append(row)

    comparison_rows = []
    for run_name, trades in runs.items():
        stats = calc_stats(trades)
        xau_trades = [t for t in trades if t["symbol"] == "XAUUSD"]
        short_trades = [t for t in trades if t["direction"] == "SHORT"]
        after_stop = [t for t in trades if t["open_time"] > STOP_ON_DD_STOP_TIME]
        comparison_rows.append(
            {
                "run": run_name,
                "trades": stats["trades"],
                "wins": stats["wins"],
                "losses": stats["losses"],
                "win_rate": round(float(stats["win_rate"]), 2),
                "net_profit": round(float(stats["net_profit"]), 2),
                "profit_factor": round(float(stats["profit_factor"]), 3) if stats["profit_factor"] is not None else "",
                "expected_payoff": round(float(stats["expected_payoff"]), 2),
                "gross_profit": round(float(stats["gross_profit"]), 2),
                "gross_loss": round(float(stats["gross_loss"]), 2),
                "avg_win": round(float(stats["avg_win"]), 2),
                "avg_loss": round(float(stats["avg_loss"]), 2),
                "max_balance_dd": round(float(stats["max_balance_dd"]), 2),
                "max_balance_dd_pct": round(float(stats["max_balance_dd_pct"]), 2),
                "max_balance_dd_time": stats["max_balance_dd_time"].strftime("%Y.%m.%d %H:%M:%S") if stats["max_balance_dd_time"] else "",
                "max_consecutive_wins": stats["max_consecutive_wins"]["count"],
                "max_consecutive_wins_amount": round(float(stats["max_consecutive_wins"]["amount"]), 2),
                "max_consecutive_losses": stats["max_consecutive_losses"]["count"],
                "max_consecutive_losses_amount": round(float(stats["max_consecutive_losses"]["amount"]), 2),
                "xauusd_trades": len(xau_trades),
                "xauusd_trade_share_pct": round(len(xau_trades) / len(trades) * 100.0, 2) if trades else 0.0,
                "xauusd_net_profit": round(sum(float(t["net_profit"]) for t in xau_trades), 2),
                "short_trades": len(short_trades),
                "short_net_profit": round(sum(float(t["net_profit"]) for t in short_trades), 2),
                "after_stop_time_trades": len(after_stop),
                "after_stop_time_net_profit": round(sum(float(t["net_profit"]) for t in after_stop), 2),
                "same_m5_bar_reentries": find_same_bar_reentries(trades),
                "score_rows": score_summaries[run_name]["rows"],
                "best_candidate_rows": score_summaries[run_name]["flags"].get("best_candidate", 0),
                "entry_score_ok_rows": score_summaries[run_name]["flags"].get("entry_score_ok", 0),
                "max_drawdown_stop_score_rows": score_summaries[run_name]["flags"].get("max_drawdown_stop", 0),
                "daily_stop_score_rows": score_summaries[run_name]["flags"].get("daily_loss_stop", 0),
                "weekly_stop_score_rows": score_summaries[run_name]["flags"].get("weekly_loss_stop", 0),
            }
        )
    write_rows(BACKTEST / f"{OUT_PREFIX}_run_comparison.csv", comparison_rows)

    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_symbol.csv", runs, lambda t: t["symbol"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_direction.csv", runs, lambda t: t["direction"])
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_symbol_direction.csv", runs, lambda t: f"{t['symbol']}:{t['direction']}")
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_month.csv", runs, lambda t: t["open_time"].strftime("%Y-%m"))
    write_group_csv(BACKTEST / f"{OUT_PREFIX}_by_hour.csv", runs, lambda t: f"{t['open_time'].hour:02d}")

    score_band_trades: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in joined:
        synthetic = {
            "net_profit": float(row["net_profit"]),
            "open_time": parse_time(str(row["open_time"])),
            "close_time": parse_time(str(row["close_time"])),
        }
        score_band_trades[f"{row['run']}|{row['score_band']}"].append(synthetic)
    score_band_rows = []
    for key, trades in sorted(score_band_trades.items()):
        run_name, band = key.split("|", 1)
        stats = calc_stats(trades)
        score_band_rows.append(
            {
                "run": run_name,
                "group": band,
                "trades": stats["trades"],
                "wins": stats["wins"],
                "losses": stats["losses"],
                "win_rate": round(float(stats["win_rate"]), 2),
                "net_profit": round(float(stats["net_profit"]), 2),
                "profit_factor": round(float(stats["profit_factor"]), 3) if stats["profit_factor"] is not None else "",
                "expected_payoff": round(float(stats["expected_payoff"]), 2),
                "avg_win": round(float(stats["avg_win"]), 2),
                "avg_loss": round(float(stats["avg_loss"]), 2),
            }
        )
    write_rows(BACKTEST / f"{OUT_PREFIX}_by_score_band.csv", score_band_rows)

    score_count_rows = []
    for run_name, summary in score_summaries.items():
        for kind in ("entry_by_symbol", "entry_by_direction", "best_by_symbol", "best_by_direction"):
            for key, value in sorted(summary[kind].items()):
                score_count_rows.append({"run": run_name, "kind": kind, "group": key, "rows": value})
    write_rows(BACKTEST / f"{OUT_PREFIX}_score_counts.csv", score_count_rows)

    drawdown_rows = []
    for run_name, trades in runs.items():
        balance = INITIAL_BALANCE
        peak = balance
        peak_time = None
        for idx, trade in enumerate(trades, start=1):
            balance += float(trade["net_profit"])
            if balance > peak:
                peak = balance
                peak_time = trade["close_time"]
            dd = peak - balance
            dd_pct = (dd / peak * 100.0) if peak else 0.0
            if dd_pct >= 5.0:
                drawdown_rows.append(
                    {
                        "run": run_name,
                        "trade_index": idx,
                        "close_time": trade["close_time"].strftime("%Y.%m.%d %H:%M:%S"),
                        "symbol": trade["symbol"],
                        "direction": trade["direction"],
                        "net_profit": round(float(trade["net_profit"]), 2),
                        "balance": round(balance, 2),
                        "peak_balance": round(peak, 2),
                        "peak_time": peak_time.strftime("%Y.%m.%d %H:%M:%S") if peak_time else "",
                        "drawdown": round(dd, 2),
                        "drawdown_pct": round(dd_pct, 2),
                    }
                )
    write_rows(BACKTEST / f"{OUT_PREFIX}_drawdown_events.csv", drawdown_rows)

    metrics = {
        "runs": {run_name: serialize_stats(calc_stats(trades)) for run_name, trades in runs.items()},
        "score_summaries": score_summaries,
        "comparison_rows": comparison_rows,
    }
    with (BACKTEST / f"{OUT_PREFIX}_metrics.json").open("w", encoding="utf-8") as fh:
        json.dump(metrics, fh, ensure_ascii=False, indent=2)

    print(json.dumps(comparison_rows, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
