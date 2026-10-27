"""Fixed four-arm annual audit; partial exits are aggregated by position.

This file reads native exports only. It never generates entries or selects
parameters by results. The original event/deal exports remain unchanged.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import csv
from datetime import datetime, timezone
from decimal import Decimal as D, ROUND_FLOOR
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "tools/wave33_visual"))
from audit_opposite_exit import Cells, report_deals

RUN_IDS = [f"v185_{a}_scale_{p}" for a in ("a", "b") for p in ("off", "on")]
CHECKS = 0
FAILURES: list[dict] = []
SHORT_SMOKE = False


def check(ok, code, **context):
    global CHECKS
    CHECKS += 1
    if not ok:
        FAILURES.append(dict(check=code, **context))


def num(value, default=D(0)):
    try:
        return D(str(value).replace(" ", "").replace(",", "").replace("\xa0", ""))
    except Exception:
        return default


def first(row, *names, default=""):
    return next((row[n] for n in names if n in row and row[n] != ""), default)


def rows(path):
    raw = path.read_bytes()
    text = raw.decode("utf-16" if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else "utf-8-sig")
    sep = ";" if text.splitlines()[0].count(";") > text.splitlines()[0].count(",") else ","
    return list(csv.DictReader(text.splitlines(), delimiter=sep))


def stream_rows(path):
    # The annual event ledger can exceed 180 MB. Retain only execution rows,
    # while counting every event, rather than materializing all candidates.
    with path.open(encoding="utf-8-sig", newline="") as stream:
        yield from csv.DictReader(stream, delimiter=";")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def dump(value):
    if isinstance(value, D):
        return float(value)
    raise TypeError(type(value).__name__)


def save_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, default=dump) + "\n", encoding="utf-8")


def write_csv(path, values):
    if not values:
        path.write_text("", encoding="utf-8")
        return
    with path.open("w", encoding="utf-8-sig", newline="") as stream:
        fields = list(dict.fromkeys(k for row in values for k in row))
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(values)


def native_summary(path):
    raw = path.read_bytes()
    parser = Cells()
    parser.feed(raw.decode("utf-16" if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else "utf-8-sig"))
    pairs = {}
    for row in parser.rows:
        for i, cell in enumerate(row[:-1]):
            if cell.endswith(":"):
                pairs[cell[:-1]] = row[i + 1]
    labels = dict(period=("期間", "Period"), quality=("ヒストリー品質", "History Quality"),
                  bars=("バー", "Bars"), ticks=("ティック", "Ticks"),
                  deposit=("初期証拠金", "Initial Deposit"), net=("総損益", "Total Net Profit"),
                  pf=("プロフィットファクター", "Profit Factor"),
                  gross_profit=("総利益", "Gross Profit"), gross_loss=("総損失", "Gross Loss"),
                  trades=("取引数", "Total Trades"), deals=("約定数", "Total Deals"),
                  balance_dd=("残高最大ドローダウン", "Balance Drawdown Maximal"),
                  equity_dd=("証拠金最大ドローダウン", "Equity Drawdown Maximal"))
    found = {key: next((pairs[x] for x in choices if x in pairs), None) for key, choices in labels.items()}
    for key in ("bars", "ticks", "trades", "deals"):
        found[key] = int(found[key])
    for key in ("deposit", "net", "pf", "gross_profit", "gross_loss"):
        found[key] = num(found[key])
    return found


def canonical_deal(row):
    time_msc = first(row, "time_msc", "deal_time_msc")
    time = first(row, "time", "deal_time", "at", "deal_at")
    if not time and time_msc:
        time = datetime.fromtimestamp(int(time_msc) / 1000, tz=timezone.utc).strftime("%Y.%m.%d %H:%M:%S")
    return dict(
        deal=first(row, "deal_ticket", "deal", "ticket"),
        order=first(row, "order_ticket", "order"),
        position_id=first(row, "position_id", "position_identifier"),
        time=time,
        time_msc=time_msc,
        setup_id=first(row, "setup_id"),
        entry=first(row, "entry", "deal_entry"),
        type=first(row, "type", "deal_type"),
        volume=num(first(row, "volume")), price=num(first(row, "price")),
        profit=num(first(row, "profit")), commission=num(first(row, "commission")),
        swap=num(first(row, "swap")), fee=num(first(row, "fee")),
        comment=first(row, "comment"), reason=first(row, "reason", "deal_reason"))


def entry_kind(value):
    if value.upper() in ("IN", "DEAL_ENTRY_IN", "0"):
        return "in"
    if value.upper() in ("OUT", "DEAL_ENTRY_OUT", "1", "OUT BY", "DEAL_ENTRY_OUT_BY", "3"):
        return "out"
    return value


def max_streak(values, positive):
    current = best = 0
    for value in values:
        current = current + 1 if (value > 0 if positive else value < 0) else 0
        best = max(best, current)
    return best


def ratio(profit, loss):
    return profit / -loss if loss < 0 else None


def coverage(path, run_id):
    monthly = Counter()
    count = 0
    first_bar = last_bar = prior = None
    causal = ordered = True
    with path.open(encoding="utf-8-sig", newline="") as stream:
        for row in csv.DictReader(stream, delimiter=";"):
            bar, closed, known = (row[k] for k in ("bar_time", "closed_at", "known_at"))
            count += 1
            first_bar = first_bar or bar
            last_bar = bar
            causal &= bar < closed <= known
            ordered &= prior is None or prior < bar
            prior = bar
            if "2020.01.01" <= bar[:10] < "2021.01.01":
                monthly[bar[:7]] += 1
    check(causal, "closed_bar_known_order", run=run_id, file=path.name)
    check(ordered, "strict_bar_order", run=run_id, file=path.name)
    if not SHORT_SMOKE:
        check(set(monthly) == {f"2020.{m:02}" for m in range(1, 13)}, "twelve_months", run=run_id, file=path.name)
    return dict(count=count, first=first_bar, last=last_bar, monthly=dict(sorted(monthly.items())), sha256=sha(path))


def audit_scaleout(stages, raw, run_id, volume_step):
    by_setup = defaultdict(list)
    for stage in stages:
        by_setup[stage["setup_id"]].append(stage)
    result = []
    for setup, group in by_setup.items():
        plans = [r for r in group if r["event"] == "SCALEOUT_PLAN"]
        if not plans:
            continue
        plan = plans[0]
        side = 1 if first(plan, "direction") in ("LONG", "1") else -1
        first_tp = num(plan["first_tp"])
        filled = [r for r in group if r["event"] == "SCALEOUT_TP1_FILLED"]
        be = [r for r in group if r["event"] == "SCALEOUT_BE_CONFIRMED"]
        fallback = [r for r in group if r["event"] == "SCALEOUT_FALLBACK_SINGLE"]
        frozen = [r for r in group if r["event"] == "SCALEOUT_VOLUME_FROZEN"]
        target_volume = num(frozen[0]["target_close_volume"]) if frozen else D(0)
        if frozen and volume_step > 0:
            expected_half = (num(frozen[0]["initial_volume"])/volume_step/D(2)).to_integral_value(rounding=ROUND_FLOOR)*volume_step
            check(target_volume == expected_half, "half_volume_floor_on_step", run=run_id, setup=setup)
        for row in be:
            check(num(row["target_close_volume"]) > 0 and
                  num(row["confirmed_close_volume"]) >= num(row["target_close_volume"]),
                  "be_only_after_confirmed_half", run=run_id, setup=setup)
            check(side*(num(row["current_sl"])-num(row["entry_price"])) >= D("-0.0000001"),
                  "be_sl_not_worse_than_actual_entry", run=run_id, setup=setup)
        half_deals = [r for r in raw if r["setup_id"] == setup and r["comment"].startswith("W33_HALF_TP1")]
        half_volume = sum((r["volume"] for r in half_deals), D(0))
        if half_deals:
            check(bool(frozen), "half_deals_have_frozen_volume", run=run_id, setup=setup)
            if frozen and not fallback:
                check(half_volume <= num(frozen[0]["target_close_volume"]), "no_duplicate_half_volume", run=run_id, setup=setup)
        half_price = sum((r["price"]*r["volume"] for r in half_deals), D(0))/half_volume if half_volume else None
        result.append(dict(run=run_id, setup_id=setup, first_kind=plan["first_kind"], final_kind=plan["final_kind"],
            has_native_position=any(r["setup_id"]==setup for r in raw),
            first_tp=first_tp, final_tp=num(plan["planned_final_tp"]),
            tp1_touch=any(r["event"]=="SCALEOUT_TP1_TOUCH" for r in group),
            tp1_deals=len(half_deals), tp1_volume=half_volume,
            tp1_average_fill=half_price, tp1_signed_fill_drift=(side*(half_price-first_tp) if half_price is not None else None),
            half_confirmed=bool(filled) and target_volume > 0 and half_volume >= target_volume, be_confirmed=bool(be),
            be_deferred=any(r["event"]=="SCALEOUT_BE_DEFERRED" for r in group),
            be_rejected=any(r["event"]=="SCALEOUT_BE_REJECTED" for r in group),
            close_rejected=any(r["event"]=="SCALEOUT_CLOSE_REJECTED" for r in group),
            single_fallback=bool(fallback), fallback_reason=fallback[0]["reason"] if fallback else "",
            broker_final_before_half=any(r["event"]=="SCALEOUT_FINAL_BEFORE_TP1" for r in group)))
    return result


def audit_run(path):
    name = path.name
    event_counts = Counter()
    fill = defaultdict(list)
    close = defaultdict(list)
    for event in stream_rows(path / "events.csv"):
        event_counts[event["event_type"]] += 1
        if event["event_type"] == "FILL":
            fill[event["setup_id"]].append(event)
        if event["event_type"] == "EXIT":
            close[event["setup_id"]].append(event)
    config = {r["parameter"]: r["value"] for r in rows(path / "config.csv")}
    metadata=json.loads((path/"run.json").read_text(encoding="utf-8-sig"))
    check(config.get("ea_version")=="1.85", "actual_ea_version", run=name)
    check(config.get("scale_out", "").lower() in ({"true","1"} if name.endswith("_on") else {"false","0"}), "actual_scaleout_input", run=name)
    check(num(config.get("risk_percent"))==1 and num(config.get("reward_r"))==1, "actual_fixed_risk_rr", run=name)
    check(config.get("tester_orders", "").lower() in {"true","1"}, "actual_tester_orders_on", run=name)
    before=json.loads((path/"runtime_before.json").read_text(encoding="utf-8-sig"))
    after=json.loads((path/"runtime_after.json").read_text(encoding="utf-8-sig"))
    check(before==after, "runtime_did_not_change", run=name)
    native = native_summary(path / "report.htm")
    html_deals = report_deals(path / "report.htm")
    raw_path = path / "raw_deals.csv"
    check(raw_path.exists(), "raw_deal_ledger_exists", run=name)
    if not raw_path.exists():
        raise RuntimeError(f"raw_deals.csv missing: {name}")
    raw = [canonical_deal(r) for r in rows(raw_path)]
    raw.sort(key=lambda r:(int(r["time_msc"] or 0),int(r["deal"])))
    check(len(raw) == len({r["deal"] for r in raw}), "unique_raw_deal_tickets", run=name)
    check(len(raw) == len(html_deals) == native["deals"], "all_native_deals_accounted", run=name)
    native_by_ticket = {r["deal"]: r for r in html_deals}
    for deal in raw:
        other = native_by_ticket.get(deal["deal"])
        check(other is not None, "raw_deal_exists_in_native", run=name, deal=deal["deal"])
        if not other:
            continue
        for key in ("order", "price", "volume", "profit", "commission", "swap"):
            check(deal[key] == other[key], "raw_native_deal_match", run=name, deal=deal["deal"], field=key)
        check(entry_kind(deal["entry"]) == other["entry"], "raw_native_entry_match", run=name, deal=deal["deal"])
    cash = lambda d: sum(d[k] for k in ("profit", "commission", "swap", "fee"))
    check(abs(sum(map(cash, raw), D(0)) - native["net"]) <= D("0.011"), "native_cash_reconciliation", run=name)
    by_position = defaultdict(list)
    for deal in raw:
        by_position[deal["position_id"]].append(deal)
    contract = num(config.get("contract_size"))
    check(config.get("account_currency") == config.get("symbol_currency_profit") == "USD", "usd_quote_account", run=name)
    positions = []
    for pos, deals in by_position.items():
        setup_ids = {r["setup_id"] for r in deals if r["setup_id"]}
        check(len(setup_ids) == 1 and pos not in ("", "0"), "one_setup_per_position", run=name, position=pos)
        if len(setup_ids) != 1:
            continue
        setup = next(iter(setup_ids))
        ins = [d for d in deals if entry_kind(d["entry"]) == "in"]
        outs = [d for d in deals if entry_kind(d["entry"]) == "out"]
        check(len(ins) + len(outs) == len(deals), "supported_deal_entries", run=name, position=pos)
        in_volume = sum((d["volume"] for d in ins), D(0))
        out_volume = sum((d["volume"] for d in outs), D(0))
        check(in_volume == out_volume and in_volume > 0, "position_volume_reconciled", run=name, position=pos)
        check(bool(fill[setup]), "position_has_fill_event", run=name, setup=setup)
        check(len(close[setup]) == 1, "position_has_one_final_exit", run=name, setup=setup)
        if not fill[setup] or not ins or not outs:
            continue
        origin = fill[setup][0]
        end = close[setup][-1] if close[setup] else {}
        entry_price = sum((d["price"] * d["volume"] for d in ins), D(0)) / in_volume
        initial_sl = num(origin["sl_price"])
        independent_risk = abs(entry_price - initial_sl) * contract * in_volume
        risk = num(end.get("execution_initial_risk_money") or origin.get("execution_initial_risk_money"))
        net = sum(map(cash, deals), D(0))
        check(risk > 0 and abs(risk - independent_risk) <= D("0.0001"), "immutable_initial_risk", run=name, setup=setup)
        check(abs(net - num(end.get("execution_net_cash"))) <= D("0.0001"), "position_cash_matches_exit_ledger", run=name, setup=setup)
        realized = net / risk if risk else D(0)
        check(abs(realized - num(end.get("realized_r"))) <= D("0.000001"), "position_r_matches_exit_ledger", run=name, setup=setup)
        positions.append(dict(run=name, setup_id=setup, position_id=pos,
            direction=origin["direction"], entry_at=ins[0]["time"], exit_at=outs[-1]["time"],
            entry_price=entry_price, initial_sl=initial_sl, initial_volume=in_volume,
            exit_deals=len(outs), partial_exit_count=max(0, len(outs)-1),
            price_profit=sum((d["profit"] for d in deals), D(0)),
            commission=sum((d["commission"] for d in deals), D(0)),
            swap=sum((d["swap"] for d in deals), D(0)), fee=sum((d["fee"] for d in deals), D(0)),
            net_cash=net, risk_cash=risk, net_r=realized, exit_reason=end.get("exit_reason"),
            native_final_comment=outs[-1]["comment"],
            wave1_start_time=origin["wave1_start_time"], wave1_start_price=origin["wave1_start_price"],
            wave1_peak_time=origin["wave1_peak_time"], wave1_peak_price=origin["wave1_peak_price"],
            upper_break_bar_time=origin.get("upper_break_bar_time", ""),
            upper_break_level_time=origin.get("upper_break_level_time", ""),
            planned_tp=origin["tp_price"], intended_rr=origin["intended_rr"],
            forced_test_end=any("end of test" in d["comment"].lower() for d in outs)))
    positions.sort(key=lambda p: (p["exit_at"], p["position_id"]))
    check(len(positions) == len(fill) == len(close), "all_fills_closed_positions", run=name)
    check(abs(sum((p["net_cash"] for p in positions), D(0)) - native["net"]) <= D("0.011"), "grouped_position_net_matches_native", run=name)
    positives = sum((max(p["net_cash"], D(0)) for p in positions), D(0))
    negatives = sum((min(p["net_cash"], D(0)) for p in positions), D(0))
    balance = peak = native["deposit"]
    draw = D(0)
    for deal in raw:
        balance += cash(deal)
        peak = max(peak, balance)
        draw = max(draw, peak-balance)
    dd_native = num(native["balance_dd"].split(" (")[0])
    check(abs(draw-dd_native) <= D("0.011"), "native_balance_dd_recomputed", run=name)
    event_counts = dict(event_counts)
    stage_path = path / "scaleout.csv"
    stages = rows(stage_path) if stage_path.exists() else []
    stage_counts = dict(Counter(first(r, "event", "stage", "event_type", "action", "status") for r in stages))
    scale_positions = audit_scaleout(stages, raw, name, num(config.get("volume_step")))
    filled_scale_positions = [r for r in scale_positions if r["has_native_position"]]
    scale_metrics = {key:sum(bool(r[key]) for r in filled_scale_positions) for key in
        ("tp1_touch", "half_confirmed", "be_confirmed", "be_deferred", "be_rejected", "close_rejected", "single_fallback", "broker_final_before_half")}
    scale_metrics["plans"] = len(scale_positions)
    scale_metrics["plans_scope"] = "All SIGNAL records, including later skipped/unfilled candidates; action counts below use native-filled positions."
    scale_metrics["filled_plans"] = len(filled_scale_positions)
    scale_metrics["first_kind_counts"] = dict(Counter(r["first_kind"] for r in scale_positions))
    scale_metrics["half_confirmed_kind_counts"] = dict(Counter(r["first_kind"] for r in scale_positions if r["half_confirmed"]))
    scale_metrics["tp1_nonzero_fill_drift"] = sum(r["tp1_signed_fill_drift"] is not None and abs(r["tp1_signed_fill_drift"])>D("0.00000001") for r in scale_positions)
    scale_by_setup = {r["setup_id"]:r for r in scale_positions}
    for position in positions:
        stage = scale_by_setup.get(position["setup_id"], {})
        for key in ("first_kind", "final_kind", "first_tp", "final_tp", "tp1_volume", "tp1_average_fill", "tp1_signed_fill_drift", "half_confirmed", "be_confirmed", "single_fallback", "broker_final_before_half"):
            position["scale_"+key] = stage.get(key)
    journals = []
    for p in (path/"journals").rglob("*.log"):
        for line in p.read_text(encoding="utf-8-sig", errors="replace").splitlines():
            if "no real ticks, every tick generation used" in line or re.search(r"XAUUSD\+,(?:M1|M5):\s+\d+ ticks", line):
                journals.append(dict(file=str(p.relative_to(path)), text=line))
    result = dict(native=native, closed_positions=len(positions),
        position_net_profit=positives, position_net_loss=negatives, position_net_pf=ratio(positives, negatives),
        position_net_wins=sum(p["net_cash"]>0 for p in positions),
        position_net_losses=sum(p["net_cash"]<0 for p in positions),
        position_net_zero=sum(p["net_cash"]==0 for p in positions),
        sum_r=sum((p["net_r"] for p in positions), D(0)),
        mean_r=sum((p["net_r"] for p in positions), D(0))/len(positions) if positions else None,
        max_win_streak=max_streak([p["net_cash"] for p in positions], True),
        max_loss_streak=max_streak([p["net_cash"] for p in positions], False),
        price_profit=sum((p["price_profit"] for p in positions), D(0)),
        commission=sum((p["commission"] for p in positions), D(0)),
        swap=sum((p["swap"] for p in positions), D(0)), fee=sum((p["fee"] for p in positions), D(0)),
        independently_recomputed_balance_dd=draw, partial_exit_positions=sum(p["exit_deals"]>1 for p in positions),
        forced_test_end_positions=sum(p["forced_test_end"] for p in positions),
        event_counts=event_counts, scaleout_stage_counts=stage_counts, scaleout_position_metrics=scale_metrics, generated_tick_evidence=journals,
        coverage={p: coverage(path/p, name) for p in ("upper_bars.csv", "lower_bars.csv")},
        input_hashes={p:sha(path/p) for p in ("events.csv", "raw_deals.csv", "config.csv", "inputs.set", "report.htm")})
    write_csv(path/"audit_positions.csv", positions)
    write_csv(path/"audit_scaleout_positions.csv", scale_positions)
    write_csv(path/"audit_deals.csv", [dict(run=name, **d) for d in raw])
    save_json(path/"independent_audit.json", result)
    return result, positions


def identity(p):
    return tuple(p[k] for k in ("direction", "upper_break_bar_time", "upper_break_level_time",
                               "wave1_start_time", "wave1_start_price", "wave1_peak_time", "wave1_peak_price"))


def main():
    global SHORT_SMOKE
    parser=argparse.ArgumentParser()
    parser.add_argument("--batch", type=Path, required=True)
    parser.add_argument("--short-smoke", action="store_true")
    args=parser.parse_args()
    SHORT_SMOKE=args.short_smoke
    batch=args.batch.resolve()
    manifest=json.loads((batch/"deployment.json").read_text(encoding="utf-8-sig"))
    proof=json.loads((batch/"provenance.json").read_text(encoding="utf-8-sig"))
    for filename,expected in proof.get("method_sha256",{}).items():
        check(sha(batch/"method"/filename)==expected, "frozen_analysis_method_hash", file=filename)
    check(sha(batch/"deployment.json")==proof["deployment_sha256"], "frozen_deployment_manifest_hash")
    for filename,key in (("Wave33ChopDiagnostic.mq5","source_sha256"),("Wave33ChopDiagnostic.ex5","binary_sha256")):
        check(sha(batch/filename).lower()==manifest[key].lower(), "frozen_ea_matches_qa", file=filename)
    for filename,expected in manifest["header_sha256"].items():
        check(sha(batch/"frozen_include"/filename.replace("\\","/")).lower()==expected.lower(), "frozen_header_matches_qa", file=filename)
    results={}
    all_positions=[]
    per_run={}
    for name in RUN_IDS:
        results[name], per_run[name] = audit_run(batch/name)
        all_positions.extend(per_run[name])
    comparisons={}
    paired=[]
    for arm in ("a", "b"):
        off, on=(f"v185_{arm}_scale_{p}" for p in ("off", "on"))
        inputs=[]
        for name in (off,on):
            values={}
            for line in (batch/name/"inputs.set").read_text(encoding="utf-8-sig").splitlines():
                if "=" in line:
                    k,v=line.split("=",1);values[k]=v
            inputs.append(values)
        diff={k:[inputs[0].get(k),inputs[1].get(k)] for k in inputs[0].keys()|inputs[1].keys() if inputs[0].get(k)!=inputs[1].get(k)}
        check(set(diff)=={"InpScaleOut", "InpRunTag"}, "one_policy_input_changed", arm=arm, differences=diff)
        for filename in ("upper_bars.csv", "lower_bars.csv"):
            check(sha(batch/off/filename)==sha(batch/on/filename), "identical_accepted_source_bars", arm=arm, file=filename)
        check(results[off]["native"]["ticks"]==results[on]["native"]["ticks"], "same_native_tick_count", arm=arm)
        check(json.loads((batch/off/"runtime_before.json").read_text(encoding="utf-8-sig"))==json.loads((batch/on/"runtime_before.json").read_text(encoding="utf-8-sig")), "same_runtime_between_arms", arm=arm)
        off_map={identity(p):p for p in per_run[off]};on_map={identity(p):p for p in per_run[on]}
        check(len(off_map)==len(per_run[off]) and len(on_map)==len(per_run[on]), "unique_wave_identity", arm=arm)
        common=off_map.keys()&on_map.keys()
        for key in sorted(common):
            a,b=off_map[key],on_map[key]
            paired.append(dict(arm=arm.upper(), off_setup=a["setup_id"], on_setup=b["setup_id"],
                off_entry=a["entry_at"], on_entry=b["entry_at"], off_cash=a["net_cash"], on_cash=b["net_cash"],
                off_r=a["net_r"], on_r=b["net_r"], delta_r=b["net_r"]-a["net_r"]))
        comparisons[arm.upper()]=dict(input_differences=diff, common_wave_positions=len(common),
            off_only_positions=len(off_map.keys()-on_map.keys()), on_only_positions=len(on_map.keys()-off_map.keys()),
            net_cash_delta=results[on]["native"]["net"]-results[off]["native"]["net"],
            sum_r_delta=results[on]["sum_r"]-results[off]["sum_r"],
            caveat="Position sizing and later entry availability can differ after a partial exit; matched waves are descriptive only.")
    result=dict(status="PASS" if not FAILURES else "FAIL", scope="SHORT_EXECUTION_SMOKE" if SHORT_SMOKE else "FIXED_ANNUAL_2020",
        checks=CHECKS, failures=FAILURES,
        runs=results, comparisons=comparisons,
        limitations=["Known 2020 period; no out-of-sample or profitability promotion claim.",
                     "Requested Model4 may use generated ticks; see native quality and journal evidence.",
                     "Native equity DD is not independently rebuilt from the full tick equity path.",
                     "Twelve observed months do not independently distinguish every market closure from a missing historical bar.",
                     "Nominal entry-price SL is not cost-inclusive break-even; commission, swap, fee and slippage may leave a small loss.",
                     "Historical 2020 commission/swap accuracy is not independently established."])
    out=batch/"analysis";out.mkdir(exist_ok=True)
    save_json(out/"summary.json",result)
    write_csv(out/"positions.csv",all_positions)
    write_csv(out/"paired_positions.csv",paired)
    lines=["# v1.85 短期執行smoke" if SHORT_SMOKE else "# v1.85 固定年間比較", "", f"独立照合: **{result['status']} / {CHECKS}項目**。損益は部分決済をposition単位に合算。", "",
           "| 条件 | 完了position | 純損益 USD | position PF | 合計R | 平均R | 最大連敗 | native equity DD |", "|---|---:|---:|---:|---:|---:|---:|---|"]
    for name in RUN_IDS:
        r=results[name]
        fmt=lambda v: "—" if v is None else f"{v:.3f}"
        lines.append(f"| {name} | {r['closed_positions']} | {r['native']['net']:.2f} | {fmt(r['position_net_pf'])} | {r['sum_r']:.3f} | {fmt(r['mean_r'])} | {r['max_loss_streak']} | {r['native']['equity_dd']} |")
    period="2020.01.01〜2020.01.11（短期smoke、年間成績ではない）" if SHORT_SMOKE else "2020.01.01〜2021.01.01"
    lines += ["", f"検証期間{period}、XAUUSD+、5,000 USD、risk 1%、RR入力1.0、各組の差はScaleOutだけ。",
              "", "半分決済は銘柄の数量stepに切り下げるため、奇数stepでは厳密な50%にならない。最小数量で2分割できない場合は近いTPで全量決済し、リスクを増やして分割しない。建値SLは実約定価格が基準で、手数料・swap・fee・slippage込みの損益ゼロを保証するものではない。",
              "", "ティック品質・TP1/建値変更・拒否などの全件数は[summary.json](summary.json)。全positionは[positions.csv](positions.csv)、同一①の比較は[paired_positions.csv](paired_positions.csv)。",
              "", "実ティックの精度、未使用期間の有効性、live readinessは別の検証。勝率やPFだけで昇格しない。"]
    (out/"README.md").write_text("\n".join(lines)+"\n",encoding="utf-8")
    print(json.dumps(dict(status=result["status"],checks=CHECKS,failures=FAILURES,comparisons=comparisons),ensure_ascii=False,default=dump))
    return bool(FAILURES)


if __name__=="__main__":
    raise SystemExit(main())
