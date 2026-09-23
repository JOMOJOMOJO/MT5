"""Check strategy invariants against MT5-produced diagnostic rows and event logs."""
import csv
import json
import re
from collections import Counter
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
QA = ROOT / "reports/qa/usdjpy_hl_fib50"


def stamp(value):
    return datetime.strptime(value, "%Y.%m.%d %H:%M:%S") if value != "-" else None


def audit(name):
    folder = QA / name
    with (folder / "diagnostics.csv").open(encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    log = (folder / "tester.log").read_text(encoding="utf-8-sig")
    orders = [r for r in rows if r["accepted"].lower() == "true"]
    issues = []

    def check(condition, message):
        if not condition:
            issues.append(message)

    check(len(rows) == len({r["time"] for r in rows}), "duplicate M1 decisions")
    check(all(stamp(r["time"]).second == 0 for r in rows), "decision not assigned to M1 open")
    check(len(orders) == len({r["structure_id"] for r in orders}), "duplicate structure order")
    check(all(int(r["orders"]) <= 1 and int(r["positions"]) <= 1 for r in rows), "multiple own exposures")
    check(bool(orders), "no order example")
    for row in orders:
        ident = row["structure_id"]
        low0, low1, high5, high1, entry, sl, tp, lots, loss, equity = (
            float(row[k]) for k in ("old_low", "new_low", "m5_high", "m1_high", "limit", "sl", "tp", "lots", "expected_loss", "equity")
        )
        now = stamp(row["time"])
        check(low0 < low1 < high5 < high1, f"{ident}: price order")
        check(stamp(row["old_low_time"]) < stamp(row["new_low_time"]), f"{ident}: M5 low chronology")
        check(stamp(row["m5_high_confirmed"]) <= stamp(row["new_low_confirmed"]), f"{ident}: reference high lookahead")
        check(stamp(row["cross_time"]) >= stamp(row["new_low_confirmed"]), f"{ident}: cross before M5 confirmation")
        check(stamp(row["m1_high_time"]) >= stamp(row["cross_time"]), f"{ident}: old M1 high used")
        check(stamp(row["m1_high_confirmed"]) == now, f"{ident}: confirmation timing")
        fib = (low1 + high1) / 2
        check(-1e-8 <= fib - entry < .001 + 1e-8, f"{ident}: Fibonacci/tick floor")
        check(abs(sl - (low1 - .010)) < 1e-7, f"{ident}: SL buffer")
        check(abs(tp - (entry + (entry - sl) * 1.2)) <= .00050001, f"{ident}: RR/tick rounding")
        check(0 < loss <= equity * .01 + 1e-7, f"{ident}: risk above 1 percent")
        check(lots >= .01 and abs(lots * 100 - round(lots * 100)) < 1e-6, f"{ident}: volume grid")
        last_fill = stamp(row["last_fill"])
        if last_fill:
            check((stamp(row["placed"]) - last_fill).total_seconds() >= 900, f"{ident}: cooldown violation")
    removals = re.findall(r"HF_REMOVE ticket=(\d+) reason=(\S+) placed=([\d.]+ [\d:]+) removed=([\d.]+ [\d:]+)", log)
    for ticket, why, placed, removed in removals:
        if "EXPIRED" in why:
            check((stamp(removed) - stamp(placed)).total_seconds() == 900, f"ticket {ticket}: expiry not 900 seconds")
    fills = len(re.findall(r"HF_FILL time=", log))
    protections = re.findall(r"HF_PROTECT ticket=\d+ sl=\S+ tp=\S+ retcode=(\d+)", log)
    if name == "deferred":
        check(fills > 0 and len(protections) == fills, "not every deferred fill has protection event")
        check(all(code == "10009" for code in protections), "deferred protection failure")
    reasons = Counter(r["reason"] for r in rows)
    selected = orders[:2]
    for why in ("NOT_HIGHER_LOW", "WAIT_POST_CONFIRM_CROSS", "WAIT_CONFIRMED_BREAKOUT_HIGH", "FILL_COOLDOWN_15_MINUTES", "STRUCTURE_ALREADY_USED_OR_INVALIDATED", "LIMIT_NOT_BELOW_ASK_OR_BROKER_DISTANCE"):
        example = next((r for r in rows if r["reason"] == why), None)
        if example:
            selected.append(example)
    with (folder / "examples.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(selected)
    result = {
        "variant": name, "decisions": len(rows), "orders": len(orders), "fills": fills,
        "removals": dict(Counter(x[1] for x in removals)),
        "protection_successes": len(protections), "reasons": dict(reasons),
        "max_expected_risk_fraction": max(float(r["expected_loss"]) / float(r["equity"]) for r in orders),
        "violations": issues,
    }
    (folder / "audit.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    return result


if __name__ == "__main__":
    results = [audit(name) for name in ("normal", "deferred")]
    (QA / "audit_summary.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
    for result in results:
        print(json.dumps({k: result[k] for k in ("variant", "decisions", "orders", "fills", "removals", "protection_successes", "violations")}, ensure_ascii=False))
    raise SystemExit(int(any(r["violations"] for r in results)))
