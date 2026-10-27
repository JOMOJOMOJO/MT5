"""Read completed frozen native OFF/ON evidence; never launch or tune MT5."""
from __future__ import annotations

import csv
import json
from collections import Counter, defaultdict
from decimal import Decimal
from pathlib import Path
from statistics import mean

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from datetime import datetime, timedelta

ROOT = Path(__file__).resolve().parents[2]
BATCH = ROOT / "reports/backtest/runs/wave33_h1er_2025jan/20261027_005658_UTC_0796b021"
OUT = BATCH / "analysis"
DT = "%Y.%m.%d %H:%M:%S"
AUDIT = []


def check(name, ok, detail=None):
    AUDIT.append(dict(check=name, passed=bool(ok), detail=detail))
    if not ok:
        raise AssertionError((name, detail))


def rows(path, repair_reason_tail=None):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        source = list(csv.reader(stream, delimiter=";"))
    header = source[0]
    if repair_reason_tail is not None:
        # Existing MQL daytrade free-text reason is unquoted and may contain ';'.
        # The 19 typed columns following reason are delimiter-free.
        check(path.name + "_24_columns", len(header) == 24)
        fixed = [r[:4] + [";".join(r[4:len(r)-repair_reason_tail])] + r[-repair_reason_tail:] for r in source[1:]]
    else:
        fixed = source[1:]
    check(path.name + "_rectangular", all(len(r) == len(header) for r in fixed))
    return [dict(zip(header, row)) for row in fixed]


def save_csv(path, records):
    if not records:
        return
    keys = list(dict.fromkeys(k for r in records for k in r))
    with path.open("w", encoding="utf-8-sig", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=keys)
        writer.writeheader()
        writer.writerows(records)


def decimal(value):
    return Decimal(str(value))


def stats(records):
    cash = [r["net_cash"] for r in records]
    rr = [r["net_r"] for r in records]
    wins = [x for x in cash if x > 0]
    losses = [x for x in cash if x < 0]
    streak = best = 0
    for r in sorted(records, key=lambda r: (r["exit_msc"], r["setup_id"])):
        streak = streak + 1 if r["net_cash"] < 0 else 0
        best = max(streak, best)
    return dict(entries=len(records), wins=len(wins), losses=len(losses),
                flat=len(cash)-len(wins)-len(losses), net_cash=sum(cash),
                net_r=sum(rr), mean_r=mean(rr) if rr else None,
                net_r_per_original_29=sum(rr)/29,
                pf_net_position=sum(wins)/-sum(losses) if losses else None,
                win_rate=len(wins)/len(records) if records else None,
                max_loss_streak_final_exit_order=best,
                max_win_r=max(rr) if rr else None, max_loss_r=min(rr) if rr else None,
                active_entry_days=len(set(r["fill_at"][:10] for r in records)))


def extract(arm):
    source = BATCH / arm / "source"
    find = lambda suffix: next(source.glob("*_" + suffix + ".csv"))
    raw = rows(find("raw_deals"))
    events = rows(find("events"))
    day = rows(find("daytrade"), repair_reason_tail=19)
    h1 = {r["setup_id"]: r for r in rows(find("h1_efficiency"))}
    fills = [r for r in events if r["event_type"] == "FILL"]
    exits = [r for r in events if r["event_type"] == "EXIT"]
    check(arm+"_unique_fill_exit", len(fills)==len({r["setup_id"] for r in fills}) and len(exits)==len({r["setup_id"] for r in exits}))
    fby = {r["setup_id"]: r for r in fills}
    eby = {r["setup_id"]: r for r in exits}
    check(arm+"_all_positions_closed", set(fby)==set(eby))
    frozen = [r for r in day if r["event"] == "DAYTRADE_RISK_FROZEN"]
    freeze = {r["setup_id"]: r for r in frozen}
    check(arm+"_risk_frozen_once_per_fill", len(frozen)==len(freeze) and set(freeze)==set(fby))
    check(arm+"_unique_deal_tickets", len(raw)==len({r["deal_ticket"] for r in raw}))
    grouped = defaultdict(list)
    for r in raw:
        check(arm+"_raw_deal_matched", r["setup_id"] in fby)
        grouped[r["setup_id"]].append(r)
    check(arm+"_raw_all_positions", set(grouped)==set(fby))
    records = []
    for sid, deals in grouped.items():
        f, e, risk = fby[sid], eby[sid], freeze[sid]
        entry_deals = [r for r in deals if r["entry"]=="DEAL_ENTRY_IN"]
        out_deals = [r for r in deals if r["entry"]=="DEAL_ENTRY_OUT"]
        check(sid+"_one_entry_no_reversal", len(entry_deals)==1 and len(deals)==len(entry_deals)+len(out_deals))
        volume_in = sum(decimal(r["volume"]) for r in entry_deals)
        volume_out = sum(decimal(r["volume"]) for r in out_deals)
        check(sid+"_flat_volume", volume_in==volume_out)
        money = sum(sum(decimal(r[k]) for k in ("profit","commission","swap","fee")) for r in deals)
        check(sid+"_cash_event_raw", abs(money-decimal(e["execution_net_cash"])) < Decimal("0.000001"))
        money_risk = decimal(risk["initial_risk_money"])
        check(sid+"_positive_original_risk", money_risk>0)
        rvalue = money/money_risk
        check(sid+"_immutable_r_matches_exit", abs(rvalue-decimal(e["realized_r"])) < Decimal("0.0000001"))
        check(sid+"_risk_matches_exit", abs(money_risk-decimal(e["execution_initial_risk_money"])) < Decimal("0.000001"))
        peak = max(float(r["max_favorable_r"]) for r in day if r["setup_id"]==sid)
        h = h1[sid]
        rec = dict(arm=arm, setup_id=sid, direction=f["direction"], fill_at=f["fill_at"], exit_at=e["exit_at"],
                   fill_msc=int(entry_deals[0]["time_msc"]), exit_msc=max(int(r["time_msc"]) for r in out_deals),
                   entry_price=float(risk["entry"]), initial_sl=float(risk["original_sl"]),
                   original_risk_price=float(risk["fixed_risk_price"]), initial_volume=float(volume_in),
                   initial_risk_money=float(money_risk), net_cash=float(money), net_r=float(rvalue),
                   price_profit=float(sum(decimal(r["profit"]) for r in deals)),
                   commission=float(sum(decimal(r["commission"]) for r in deals)),
                   swap=float(sum(decimal(r["swap"]) for r in deals)), fee=float(sum(decimal(r["fee"]) for r in deals)),
                   exit_reason=e["exit_reason"], exit_deals=len(out_deals),
                   max_favorable_r_logged=peak, er=float(h["er"]), roundtrip=float(h["roundtrip"]),
                   gap_count=int(h["gap_count"]), span_hours=int(h["span_seconds"])/3600)
        # A partial exit is visible directly as >1 outgoing deal; no reliance on free-text.
        rec["partial"] = len(out_deals)>1
        records.append(rec)
    records.sort(key=lambda r: (r["fill_msc"],r["setup_id"]))
    summary = stats(records)
    summary["sides"] = {side: stats([r for r in records if r["direction"]==side]) for side in ("LONG","SHORT")}
    summary["costs"] = {key: sum(r[key] for r in records) for key in ("price_profit","commission","swap","fee")}
    summary["partial_positions"] = sum(r["partial"] for r in records)
    summary["raw_deal_count"] = len(raw)
    summary["h1_observation_count"] = len(h1)
    summary["h1_outcomes"] = dict(Counter(r["outcome"] for r in h1.values()))
    raw_sorted = sorted(raw, key=lambda r: (int(r["time_msc"]), int(r["deal_ticket"])))
    balance = 5000.0
    cash_path = [(datetime(2025,1,1), balance)]
    for r in raw_sorted:
        balance += sum(float(r[k]) for k in ("profit","commission","swap","fee"))
        cash_path.append((datetime(1970,1,1)+timedelta(milliseconds=int(r["time_msc"])),balance))
    summary["final_balance_raw"] = balance
    return records, summary, cash_path, events


def main():
    OUT.mkdir(exist_ok=True)
    ledger, summary, paths, events = {}, {}, {}, {}
    for arm in ("off","on"):
        ledger[arm], summary[arm], paths[arm], events[arm] = extract(arm)
    original = len(ledger["off"])
    check("frozen_original_count_29", original==29)
    by = {a: {r["setup_id"]: r for r in records} for a,records in ledger.items()}
    retained = set(by["off"]) & set(by["on"])
    removed = set(by["off"]) - set(by["on"])
    added = set(by["on"]) - set(by["off"])
    pairs=[]
    for sid in sorted(set(by["off"])|set(by["on"])):
        off,on=by["off"].get(sid),by["on"].get(sid)
        pairs.append(dict(setup_id=sid, status="retained" if off and on else "removed" if off else "new",
                          direction=(off or on)["direction"], fill_at=(off or on)["fill_at"],
                          off_net_cash=off["net_cash"] if off else 0, on_net_cash=on["net_cash"] if on else 0,
                          off_net_r=off["net_r"] if off else 0, on_net_r=on["net_r"] if on else 0,
                          er=(off or on)["er"], roundtrip=(off or on)["roundtrip"],
                          off_exit_at=off["exit_at"] if off else "",on_exit_at=on["exit_at"] if on else ""))
    comparison = dict(original_entries=original, retained=len(retained), removed=len(removed), new=len(added),
                      removed_original_outcomes=stats([by["off"][sid] for sid in removed]),
                      new_on_outcomes=stats([by["on"][sid] for sid in added]),
                      delta_cash=summary["on"]["net_cash"]-summary["off"]["net_cash"],
                      delta_r=summary["on"]["net_r"]-summary["off"]["net_r"],
                      retained_changes=[dict(setup_id=sid, r_delta=by["on"][sid]["net_r"]-by["off"][sid]["net_r"],
                                             cash_delta=by["on"][sid]["net_cash"]-by["off"][sid]["net_cash"],
                                             same_entry=(by["on"][sid]["fill_msc"]==by["off"][sid]["fill_msc"] and by["on"][sid]["entry_price"]==by["off"][sid]["entry_price"]),
                                             same_exit=by["on"][sid]["exit_msc"]==by["off"][sid]["exit_msc"])
                                        for sid in sorted(retained)])
    day_rows=[]
    for day in sorted(set(r["fill_at"][:10] for r in ledger["off"]+ledger["on"])):
        rec = {"entry_day":day}
        for arm in ("off","on"):
            s=stats([r for r in ledger[arm] if r["fill_at"].startswith(day)])
            for key in ("entries","net_cash","net_r"):rec[arm+"_"+key]=s[key]
        rec["delta_cash"]=rec["on_net_cash"]-rec["off_net_cash"]
        rec["delta_r"]=rec["on_net_r"]-rec["off_net_r"]
        day_rows.append(rec)
    save_csv(OUT/"positions.csv",ledger["off"]+ledger["on"])
    save_csv(OUT/"matched_positions.csv",pairs)
    save_csv(OUT/"daily_entry_attribution.csv",day_rows)
    save_csv(OUT/"summary.csv",[dict(arm=arm,**{k:v for k,v in s.items() if not isinstance(v,dict)}) for arm,s in summary.items()])
    payload=dict(summary=summary,comparison=comparison,audit=AUDIT,
                 definitions=dict(R="net profit + commissions + swap + fee over immutable initial monetary risk",
                                  unit="one completed entry position; outgoing partial deals combined",
                                  clock="broker/source encoded timestamps; naive epoch arithmetic preserves source fields, no UTC offset claim",
                                  native_report_pf="native PF groups exit legs differently; separate from net-position PF here"))
    (OUT/"performance.json").write_text(json.dumps(payload,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
    plt.rcParams["font.family"]=["Meiryo","Yu Gothic","DejaVu Sans"]
    plt.rcParams["axes.unicode_minus"]=False
    fig,axes=plt.subplots(2,1,figsize=(11,7),dpi=140,constrained_layout=True)
    for arm,color,label in (("off","#9b4f33","OFF"),("on","#146b8c","ON")):
        x,y=zip(*paths[arm]); axes[0].step(x,y,where="post",color=color,label=label,lw=1.4)
        rr=0;xx=[datetime(2025,1,1)];yy=[0]
        for r in sorted(ledger[arm],key=lambda r:r["exit_msc"]):
            rr+=r["net_r"];xx.append(datetime.strptime(r["exit_at"],DT));yy.append(rr)
        axes[1].step(xx,yy,where="post",color=color,label=label,lw=1.4)
    axes[0].set_title("2025年1月 XAUUSD+ M5×M1：H1往復度フィルタだけを比較",loc="left")
    axes[0].set_ylabel("残高 USD（全約定・費用込み）");axes[0].axhline(5000,color="#888",lw=.7)
    axes[1].set_ylabel("累積R（ポジション決済単位）");axes[1].axhline(0,color="#888",lw=.7)
    axes[1].set_title("ON：往復度 ≥ 0.75（ER12 ≤ 0.25）を見送り。含み損益は表示しない。",fontsize=10,loc="left")
    for ax in axes:
        ax.legend();ax.grid(alpha=.2);ax.xaxis.set_major_formatter(mdates.DateFormatter("%m/%d"))
    fig.savefig(OUT/"off_on_outcomes.png");plt.close(fig)
    print(json.dumps(dict(summary=summary,comparison={k:v for k,v in comparison.items() if k!="retained_changes"},checks=len(AUDIT)),ensure_ascii=True))


if __name__=="__main__":
    main()
