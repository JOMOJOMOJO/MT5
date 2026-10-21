#!/usr/bin/env python3
"""Audit MT5 HTML reports for an explicitly single-position strategy.

No terminal is invoked. Real-tick status is a *report header claim*, not proof
that every tick was authentic; journal/history checks remain the runner's job.
"""
from __future__ import annotations

import argparse
import csv
from datetime import datetime, timedelta
from decimal import Decimal, InvalidOperation
from hashlib import sha256
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import sys


class Rows(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.rows = []
        self.row = None
        self.cell = None

    def handle_starttag(self, tag, attrs):
        if tag == "tr":
            self.row = []
        elif tag in ("td", "th") and self.row is not None:
            self.cell = []
        elif tag == "br" and self.cell is not None:
            self.cell.append(" ")

    def handle_data(self, data):
        if self.cell is not None:
            self.cell.append(data)

    def handle_endtag(self, tag):
        if tag in ("td", "th") and self.cell is not None:
            self.row.append(" ".join("".join(self.cell).split()))
            self.cell = None
        elif tag == "tr" and self.row is not None:
            self.rows.append(self.row)
            self.row = None


def number(value):
    value = re.sub(r"[\s,\u00a0]", "", value)
    return Decimal(value) if value else None


def numeric(value):
    return float(value) if value is not None else None


def money(value):
    return float(value.quantize(Decimal("0.01")))


def stamp(value):
    return datetime.strptime(value, "%Y.%m.%d %H:%M:%S")


def decode_report(raw):
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
        return raw.decode("utf-16")
    if b"\x00" in raw[:100]:
        return raw.decode("utf-16-le")
    return raw.decode("utf-8-sig")


LABELS = {
    "expert": ("エキスパート", "Expert"),
    "symbol": ("銘柄", "Symbol"),
    "period": ("期間", "Period"),
    "broker": ("会社", "Company"),
    "currency": ("通貨", "Currency"),
    "initial_deposit": ("初期証拠金", "Initial Deposit"),
    "model_quality": ("ヒストリー品質", "History Quality"),
    "net_profit": ("総損益", "Total Net Profit"),
    "gross_profit": ("総利益", "Gross Profit"),
    "gross_loss": ("総損失", "Gross Loss"),
    "profit_factor": ("プロフィットファクター", "Profit Factor"),
    "expected_payoff": ("期待利得", "Expected Payoff"),
    "trade_count": ("取引数", "Total Trades"),
    "deal_count": ("約定数", "Total Deals"),
    "balance_drawdown_maximal": ("残高最大ドローダウン", "Balance Drawdown Maximal"),
    "equity_drawdown_maximal": ("証拠金最大ドローダウン", "Equity Drawdown Maximal"),
    "balance_drawdown_relative": ("残高相対ドローダウン", "Balance Drawdown Relative"),
    "equity_drawdown_relative": ("証拠金相対ドローダウン", "Equity Drawdown Relative"),
    "largest_profit_trade": ("最大 勝ちトレード", "Largest profit trade"),
    "largest_loss_trade": ("最大 負けトレード", "Largest loss trade"),
    "bars": ("バー", "Bars"),
    "ticks": ("ティック", "Ticks"),
}


def headers(rows):
    result = {}
    lookup = {label.casefold(): key for key, labels in LABELS.items() for label in labels}
    for row in rows:
        for i, cell in enumerate(row[:-1]):
            key = lookup.get(cell.rstrip(":：").strip().casefold())
            if key and key not in result:
                result[key] = row[i + 1]
    return result


def weekend_crossed(entry, exit_):
    """Calendar heuristic in the report's unspecified server timezone."""
    day = entry.date()
    while day <= exit_.date():
        if day.weekday() >= 5:
            return True
        day += timedelta(days=1)
    return False


def aggregate(trades):
    vals = [Decimal(str(t["net"])) for t in trades]
    positive = sum((v for v in vals if v > 0), Decimal(0))
    negative = sum((v for v in vals if v < 0), Decimal(0))
    total = sum(vals, Decimal(0))
    return {
        "trade_count": len(vals), "net_profit": money(total),
        "gross_profit": money(positive), "gross_loss": money(negative),
        "profit_factor": float(positive / -negative) if negative else None,
        "expected_payoff": float(total / len(vals)) if vals else None,
        "winning_trade_count": sum(v > 0 for v in vals),
        "losing_trade_count": sum(v < 0 for v in vals),
        "commission": money(sum((Decimal(str(t["commission"])) for t in trades), Decimal(0))),
        "swap": money(sum((Decimal(str(t["swap"])) for t in trades), Decimal(0))),
    }


def build_trade(entry, exit_, order, warnings):
    sign = Decimal(1) if entry["side"] == "buy" else Decimal(-1)
    risk = sign * (entry["price"] - order["sl"]) if order and order["sl"] else None
    tp = order["tp"] if order else None
    sl = order["sl"] if order else None
    if risk is not None and risk <= 0:
        warnings.append(f"Entry deal {entry['id']}: original SL is not on risk side")
        risk = None
    move = sign * (exit_["price"] - entry["price"])
    overshoot = max(Decimal(0), sign * (exit_["price"] - tp)) if tp else None
    gross = entry["profit"] + exit_["profit"]
    commission = entry["commission"] + exit_["commission"]
    swap = entry["swap"] + exit_["swap"]
    comment = exit_["comment"]
    reason = "tp" if re.match(r"^tp(?:\s|$)", comment, re.I) else "sl" if re.match(r"^sl(?:\s|$)", comment, re.I) else "unspecified"
    return {
        "entry_deal_id": entry["id"], "exit_deal_id": exit_["id"],
        "entry_order_id": entry["order_id"], "exit_order_id": exit_["order_id"],
        "symbol": entry["symbol"], "side": entry["side"],
        "entry_time": entry["time"].isoformat(sep=" "),
        "entry_price": numeric(entry["price"]), "volume": numeric(entry["volume"]),
        "initial_sl": numeric(sl), "initial_tp": numeric(tp),
        "exit_time": exit_["time"].isoformat(sep=" "), "exit_price": numeric(exit_["price"]),
        "exit_reason": reason, "exit_comment": comment,
        "profit": money(gross), "commission": money(commission), "swap": money(swap),
        "net": money(gross + commission + swap),
        "holding_seconds": int((exit_["time"] - entry["time"]).total_seconds()),
        "weekend_flag_calendar_heuristic": weekend_crossed(entry["time"], exit_["time"]),
        "initial_risk_price": numeric(risk),
        "implied_initial_r_price": numeric(move / risk) if risk else None,
        "planned_reward_r_price": numeric(sign * (tp - entry["price"]) / risk) if risk and tp else None,
        "tp_overshoot_price": numeric(overshoot),
        "tp_overshoot_initial_r": numeric(overshoot / risk) if overshoot is not None and risk else None,
        "tp_overshoot_pips_usdjpy": numeric(overshoot / Decimal("0.01")) if overshoot is not None and entry["symbol"] == "USDJPY" else None,
    }


def analyze_report(path, *, expect_symbol=None, expect_timeframe=None,
                   expect_from=None, expect_to=None, require_real_ticks=False):
    path = Path(path)
    raw = path.read_bytes()
    parser = Rows()
    parser.feed(decode_report(raw))
    rows = parser.rows
    echoed_inputs = {}
    for row in rows:
        for cell in row:
            match = re.fullmatch(r"(Inp\w+)=(.*)", cell.strip())
            if match:
                if match[1] in echoed_inputs:
                    raise ValueError("Duplicate echoed input: " + match[1])
                echoed_inputs[match[1]] = match[2].strip()
    hdr = headers(rows)
    errors, warnings = [], []
    period = re.fullmatch(r"(\S+)\s*\((\d{4}\.\d{2}\.\d{2})\s*-\s*(\d{4}\.\d{2}\.\d{2})\)", hdr.get("period", ""))
    quality = hdr.get("model_quality")
    real_claim = bool(re.search(r"リアルティック|real\s*ticks?", quality or "", re.I))
    percent_match = re.search(r"(\d+(?:\.\d+)?)\s*%", quality or "")
    real_percent = float(percent_match[1]) if real_claim and percent_match else None
    server = next((r[0] for r in rows if len(r) == 1 and re.search(r"\bBuild\s+\d+", r[0])), None)
    report = {k: hdr.get(k) for k in ("expert", "broker", "currency", "symbol", "model_quality")}
    report["inputs"] = echoed_inputs
    report.update({"server_build": server, "timeframe": period[1] if period else None,
                   "from_date": period[2] if period else None, "to_date": period[3] if period else None,
                   "real_ticks_claim": real_claim if quality else None,
                   "real_tick_percent": real_percent,
                   "real_ticks_evidence_scope": "HTML header claim only; journal fallback checks required separately",
                   "source_path": str(path.resolve()), "sha256": sha256(raw).hexdigest()})
    for key in ("symbol", "timeframe", "from_date", "to_date", "model_quality"):
        if not report.get(key):
            errors.append(f"Missing/unrecognized report header: {key}")
    for key, expected in (("symbol", expect_symbol), ("timeframe", expect_timeframe), ("from_date", expect_from), ("to_date", expect_to)):
        if expected is not None and report.get(key) != expected.replace("-", "."):
            errors.append(f"Header mismatch {key}: expected {expected}, found {report.get(key)}")
    if require_real_ticks and real_percent != 100:
        errors.append("Real-ticks report header must explicitly show 100%; journal audit is also required by the runner")
    reported = {}
    for key in ("initial_deposit", "net_profit", "gross_profit", "gross_loss", "profit_factor", "expected_payoff", "trade_count", "deal_count", "largest_profit_trade", "largest_loss_trade", "bars", "ticks"):
        try:
            reported[key] = numeric(number(hdr.get(key, "")))
        except InvalidOperation:
            reported[key] = None
            errors.append(f"Invalid numeric header {key}: {hdr.get(key)}")
    for key in ("balance_drawdown_maximal", "equity_drawdown_maximal", "balance_drawdown_relative", "equity_drawdown_relative"):
        reported[key] = hdr.get(key)

    orders, deals = {}, []
    section = None
    for row in rows:
        if len(row) == 1 and row[0] in ("注文", "Orders"):
            section = "orders"
            continue
        if len(row) == 1 and row[0] in ("約定", "Deals"):
            section = "deals"
            continue
        if not section or not row or not re.match(r"^\d{4}\.\d{2}\.\d{2}", row[0]):
            continue
        try:
            if section == "orders":
                if len(row) != 11:
                    raise ValueError(f"expected 11 order cells, found {len(row)}")
                if row[1] in orders:
                    raise ValueError(f"duplicate order id {row[1]}")
                orders[row[1]] = {"symbol": row[2], "side": row[3], "sl": number(row[6]), "tp": number(row[7])}
            else:
                if len(row) != 13:
                    raise ValueError(f"expected 13 deal cells, found {len(row)}")
                if row[3] == "balance":
                    continue
                if row[3] not in ("buy", "sell"):
                    raise ValueError(f"unsupported deal type {row[3]} (cashflow/fee cannot be allocated)")
                deals.append({"time": stamp(row[0]), "id": row[1], "symbol": row[2], "side": row[3],
                              "direction": row[4], "volume": number(row[5]), "price": number(row[6]),
                              "order_id": row[7], "commission": number(row[8]), "swap": number(row[9]),
                              "profit": number(row[10]), "comment": row[12]})
        except (ValueError, InvalidOperation) as exc:
            errors.append(f"Malformed {section} row {row[:2]}: {exc}")

    trades, paired_ids = [], set()
    active = None
    pairing_blocked = False
    seen_ids = set()
    previous_time = None
    for deal in deals:
        if deal["id"] in seen_ids:
            errors.append(f"Duplicate deal id {deal['id']}")
            pairing_blocked = True
        seen_ids.add(deal["id"])
        if previous_time and deal["time"] < previous_time:
            errors.append("Deals are not in chronological order")
            pairing_blocked = True
        previous_time = deal["time"]
        if deal["symbol"] != report["symbol"]:
            errors.append(f"Deal {deal['id']} symbol differs from report")
            pairing_blocked = True
        if any(deal[k] is None for k in ("volume", "price", "commission", "swap", "profit")):
            errors.append(f"Deal {deal['id']} missing numeric fields")
            pairing_blocked = True
        if pairing_blocked:
            continue
        if deal["direction"] == "in":
            if active is not None:
                errors.append("Overlapping entries: HTML lacks position IDs; refusing ambiguous pairing")
                pairing_blocked = True
            else:
                active = deal
        elif deal["direction"] == "out":
            if active is None:
                errors.append(f"Exit deal {deal['id']} has no unique open entry")
                pairing_blocked = True
            elif deal["side"] == active["side"] or deal["volume"] != active["volume"]:
                errors.append(f"Exit deal {deal['id']}: partial volume or invalid closing side; refusing pairing")
                pairing_blocked = True
            else:
                order = orders.get(active["order_id"])
                if order and (order["symbol"] != active["symbol"] or order["side"] != active["side"]):
                    errors.append(f"Entry order {active['order_id']} identity mismatch")
                    pairing_blocked = True
                    continue
                if not order:
                    warnings.append(f"Entry order {active['order_id']} absent: initial SL/TP unavailable")
                trades.append(build_trade(active, deal, order, warnings))
                paired_ids.update((active["id"], deal["id"]))
                active = None
        else:
            errors.append(f"Unsupported entry/exit direction {deal['direction']!r}; refusing reversal/partial pairing")
            pairing_blocked = True
    unpaired_entries = sum(d["direction"] == "in" and d["id"] not in paired_ids for d in deals)
    unpaired_exits = sum(d["direction"] == "out" and d["id"] not in paired_ids for d in deals)
    if unpaired_entries or unpaired_exits:
        errors.append(f"Unpaired deals: {unpaired_entries} entries, {unpaired_exits} exits")
    calculated = aggregate(trades)
    for key in ("trade_count", "net_profit", "gross_profit", "gross_loss"):
        if reported.get(key) is None:
            errors.append(f"Required reported metric unavailable: {key}")
        elif abs(Decimal(str(calculated[key])) - Decimal(str(reported[key]))) > Decimal("0.011"):
            errors.append(f"Reconciliation failed {key}: deals={calculated[key]}, header={reported[key]}")
    if reported.get("deal_count") is None or reported["deal_count"] != len(deals):
        errors.append(f"Deal count reconciliation failed: rows={len(deals)}, header={reported.get('deal_count')}")
    positive = [t for t in trades if t["net"] > 0]
    largest = max(positive, key=lambda t: t["net"]) if positive else None
    sensitivity = aggregate([t for t in trades if t is not largest]) if largest else aggregate(trades)
    sensitivity.update({"excluded_entry_deal_id": largest["entry_deal_id"] if largest else None,
                        "method": "Static deletion of one largest positive net trade; other recorded trades unchanged",
                        "is_backtest": False,
                        "limitation": "Does not resimulate equity, lot sizing, path dependence or TP execution"})
    concentration = {
        "largest_positive_share_of_gross_profit": largest["net"] / calculated["gross_profit"] if largest and calculated["gross_profit"] else None,
        "largest_positive_share_of_net_profit": largest["net"] / calculated["net_profit"] if largest and calculated["net_profit"] > 0 else None,
    }
    metrics = {"schema_version": 1, "report": report, "reported": reported,
               "calculated": calculated, "concentration": concentration,
               "largest_positive_trade": largest, "static_excluding_largest_trade": sensitivity,
               "audit": {"passed": not errors, "errors": errors, "warnings": warnings,
                         "pairing_method": "Strict chronological single open entry, exact symbol/volume, opposite-side full exit; entry order ID supplies original SL/TP",
                         "unpaired_entry_count": unpaired_entries, "unpaired_exit_count": unpaired_exits,
                         "parsed_deal_count": len(deals), "parsed_order_count": len(orders)},
               "definitions": {"net": "Entry and exit profit + commission + swap",
                               "implied_initial_r_price": "Signed entry-to-exit price movement divided by original entry-order SL distance; excludes cash costs and FX conversion",
                               "weekend_flag_calendar_heuristic": "Holding interval touches Saturday/Sunday in report timestamps; broker timezone/session not established",
                               "tp_overshoot_price": "Positive signed exit-price distance beyond original TP; not a simulated TP cap"}}
    return metrics, trades


TRADE_FIELDS = ["entry_deal_id", "exit_deal_id", "entry_order_id", "exit_order_id", "symbol", "side", "entry_time", "entry_price", "volume", "initial_sl", "initial_tp", "exit_time", "exit_price", "exit_reason", "exit_comment", "profit", "commission", "swap", "net", "holding_seconds", "weekend_flag_calendar_heuristic", "initial_risk_price", "implied_initial_r_price", "planned_reward_r_price", "tp_overshoot_price", "tp_overshoot_initial_r", "tp_overshoot_pips_usdjpy"]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--report", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--expect-symbol")
    ap.add_argument("--expect-timeframe")
    ap.add_argument("--expect-from")
    ap.add_argument("--expect-to")
    ap.add_argument("--require-real-ticks", action="store_true")
    ap.add_argument("--journal-dir", type=Path)
    args = ap.parse_args(argv)
    try:
        metrics, trades = analyze_report(args.report, expect_symbol=args.expect_symbol,
                                        expect_timeframe=args.expect_timeframe, expect_from=args.expect_from,
                                        expect_to=args.expect_to, require_real_ticks=args.require_real_ticks)
        if args.journal_dir:
            from tick_quality import audit
            metrics['tick_quality_audit'] = audit(metrics['report'], args.journal_dir)
            if args.require_real_ticks and not metrics['tick_quality_audit']['strict_real_tick_pass']:
                metrics['audit']['errors'].append('Strict real-tick journal audit failed: ' + metrics['tick_quality_audit']['category'])
                metrics['audit']['passed'] = False
    except (OSError, UnicodeError, ValueError) as exc:
        print(f"Report analysis failed: {exc}", file=sys.stderr)
        return 2
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "metrics.json").write_text(json.dumps(metrics, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")
    with (args.out / "trades.csv").open("w", newline="", encoding="utf-8-sig") as f:
        writer = csv.DictWriter(f, fieldnames=TRADE_FIELDS)
        writer.writeheader()
        writer.writerows(trades)
    print(json.dumps({"audit_passed": metrics["audit"]["passed"], "trade_count": len(trades), "net_profit": metrics["calculated"]["net_profit"], "out": str(args.out)}, ensure_ascii=False))
    return 0 if metrics["audit"]["passed"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
