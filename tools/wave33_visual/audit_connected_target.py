"""Audit fixed native v1.80 evidence without invoking EA policy helpers."""
from __future__ import annotations
import argparse
import csv
import json
from collections import Counter
from decimal import Decimal as D, ROUND_FLOOR, ROUND_CEILING
from pathlib import Path


def rows(path):
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream, delimiter=";"))


def config(path):
    # MQL config descriptions may contain semicolons; numeric keys do not.
    with path.open(encoding="utf-8-sig", newline="") as stream:
        return {r[0]: ";".join(r[1:]) for r in list(csv.reader(stream, delimiter=";"))[1:]}


def audit(batch, out):
    failures, results, extensions, cancellations = [], [], [], []
    checks = 0

    def check(ok, run, rule, setup=""):
        nonlocal checks
        checks += 1
        if not ok:
            failures.append(dict(run=run, rule=rule, setup_id=setup))

    snapshots = {}
    for directory in sorted(batch.glob("v180_*")):
        name = directory.name
        events, cfg = rows(directory / "events.csv"), config(directory / "config.csv")
        point, tick = D(cfg["point"]), D(cfg["tick_size"])
        enabled = cfg["extend_tp_to_wave1"] == "true"
        cancel = cfg["cancel_connected_opposite"] == "true"
        signals = [r for r in events if r["event_type"] == "SIGNAL"]
        snapshots[name] = {r["setup_id"]: r for r in signals}
        cancelled = []
        for i, r in enumerate(events):
            sid = r["setup_id"]
            if r["event_type"] == "INVALIDATE" and r["reason"] == "CONNECTED_OPPOSITE_W1_CANDIDATE":
                cancelled.append(r)
                source = next((s for s in reversed(events[:i]) if s["setup_id"] == r["connected_opposite_setup_id"] and s["event_type"] == "WAVE1_BREAK"), None)
                check(cancel and source is not None, name, "accepted_source_exists_earlier_in_log", sid)
                if source:
                    check(source["direction"] != r["direction"] and source["symbol"] == r["symbol"] and source["upper_tf"] == r["upper_tf"] and source["lower_tf"] == r["lower_tf"], name, "same_context_opposite_direction", sid)
                    check(source["candidate_detected_at"] > r["candidate_detected_at"] and source["event_at"] == r["event_at"] == r["connected_opposite_known_at"], name, "cancel_at_candidate_availability", sid)
                    check(source["wave1_start_time"] == r["wave1_peak_time"] == r["connected_shared_time"] and abs(D(source["wave1_start_price"])-D(r["wave1_peak_price"])) <= point/2, name, "same_endpoint_time_price", sid)
                    check(source["wave1_start_known_at"] <= r["event_at"] and r["wave1_peak_known_at"] <= r["event_at"] and r["wave1_peak_fixed"] == "1", name, "all_sources_already_known", sid)
                check(not any(x["setup_id"] == sid and x["event_type"] in {"ORDER", "FILL"} for x in events), name, "no_order_before_or_after_cancellation", sid)
                cancellations.append({"run": name, **{k:r[k] for k in ("setup_id", "direction", "event_at", "connected_opposite_setup_id", "connected_shared_time", "connected_shared_price")}})
        for r in signals:
            sid, direction = r["setup_id"], 1 if r["direction"] == "LONG" else -1
            entry, sl, base, final, peak = (D(r[k]) for k in ("entry_price", "sl_price", "tp_rr_price", "tp_price", "wave1_peak_price"))
            risk = abs(entry-sl)
            check(risk > 0 and abs(risk/point-D(r["risk_points"])) < D("1e-7"), name, "structural_risk_width", sid)
            check(abs(D(direction)*(final-entry)/risk-D(r["actual_rr"])) < D("1e-8"), name, "final_actual_rr", sid)
            expected = base
            wanted = D(0)
            effective = D(0)
            if enabled:
                margin = max(D(cfg["tp_wave1_buffer_points"])*point, D(r["spread_points"])*point, tick)
                raw = peak-D(direction)*margin
                # A target behind the executable entry is intentionally unused.
                if raw > 0 and D(direction)*(raw-entry) > 0:
                    wanted = (raw/tick).to_integral_value(rounding=ROUND_FLOOR if direction > 0 else ROUND_CEILING)*tick
                    if wanted > 0 and D(direction)*(wanted-entry) > 0:
                        effective = D(direction)*(peak-wanted)/point
                        if D(direction)*(base-peak) < 0 and D(direction)*(wanted-base) > 0:
                            expected = wanted
                check(r["wave1_peak_fixed"] == "1" and r["wave1_peak_known_at"] <= r["event_at"], name, "target_uses_known_fixed_peak", sid)
                check(abs(wanted-D(r["tp_wave1_target_price"])) < D("1e-8") and abs(effective-D(r["tp_wave1_buffer_points"])) < D("1e-7"), name, "independent_target_margin_arithmetic", sid)
            check(final == expected, name, "only_extend_never_shorten_display_mode", sid)
            applied = final != base
            check(applied == (r["tp_extended_to_wave1"] == "1"), name, "extension_flag_matches_final", sid)
            check(final/tick == (final/tick).to_integral_value(), name, "final_target_on_tick_grid", sid)
            if applied:
                check(D(direction)*(final-base) > 0 and D(direction)*(peak-final) > 0, name, "extended_inside_w1_in_profit_direction", sid)
                extensions.append({"run": name, **{k:r[k] for k in ("setup_id", "direction", "event_at", "wave1_peak_time", "wave1_peak_known_at", "entry_price", "sl_price", "tp_rr_price", "tp_price", "actual_rr", "tp_wave1_buffer_points")}})
        ticks = rows(directory/"opposite_ticks.csv")
        for r in [r for r in events if r["event_type"] == "OPPOSITE_CLOSE_REQUEST"]:
            ready = [t for t in ticks if t["setup_id"] == r["setup_id"] and t["status"] == "READY" and D(t["net_estimate"]) > 0]
            check(bool(ready) and ready[0]["known_at"] == r["event_at"], name, "existing_opposite_exit_first_ready_tick", r["setup_id"])
        counts = Counter(r["event_type"] for r in events)
        results.append(dict(run=name, candidates=counts["WAVE1_BREAK"], cancelled=len(cancelled), cancellations_by_direction=dict(Counter(r["direction"] for r in cancelled)), extensions=sum(x["run"]==name for x in extensions), orders=counts["ORDER"], fills=counts["FILL"], ea_exits=counts["EXIT"], opposite_profit_exits=sum(r["event_type"]=="EXIT" and r["exit_reason"]=="OPPOSITE_WAVE1_PROFIT" for r in events), not_closed_in_ea_ledger=counts["FILL"]-counts["EXIT"]))
    invariant_fields = ("event_at", "entry_price", "sl_price", "risk_points", "intended_rr", "tp_rr_price", "wave1_peak_price", "wave1_peak_known_at")
    for arm in "ab":
        for first, second in (("base", "target"), ("cancel", "both")):
            left, right = (snapshots[f"v180_{arm}_{key}"] for key in (first, second))
            for sid in left.keys() & right.keys():
                check(all(left[sid][k] == right[sid][k] for k in invariant_fields), f"{arm}_{first}_vs_{second}", "common_signal_risk_unchanged", sid)
        flags = {"base":("false","false"),"cancel":("true","false"),"target":("false","true"),"both":("true","true")}
        base_cfg = config(batch/f"v180_{arm}_base/config.csv")
        allowed = {"cancel_connected_opposite", "extend_tp_to_wave1", "resolved_run_tag", "input_hash"}
        for suffix, expected_flags in flags.items():
            cfg = config(batch/f"v180_{arm}_{suffix}/config.csv")
            check((cfg["cancel_connected_opposite"], cfg["extend_tp_to_wave1"]) == expected_flags, arm+suffix, "four_fixed_flag_arms")
            check(all(cfg[k] == v for k,v in base_cfg.items() if k not in allowed), arm+suffix, "all_other_config_fixed")
    original = [r for r in cancellations if r["run"] == "v180_b_both" and r["connected_shared_time"] == "2023.01.05 17:35:00" and r["direction"] == "SHORT"]
    check(len(original) == 1 and original[0]["event_at"] == "2023.01.05 18:10:00", "user_image", "old_short_cancelled_at_1810")
    result = dict(status="PASS" if not failures else "FAIL", checks=checks, failures=failures, runs=results, cancellations=cancellations, extensions=extensions, limitations=["Fixed Jan1-Jan10 2023 engineering sample, not annual or profitability evidence.","Model4 requested but native journal reports no real ticks; generated every-tick fallback.","A had no applicable new-feature event; mirrored branches covered in native harnesses; native B supplied both directions.","B final position lacks an EA EXIT callback before test stop; exclude it from natural-exit outcome claims.","CAP_TP precedence reviewed in Plan; native eight-arm sample uses DISPLAY_ONLY."])
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    return result


if __name__ == "__main__":
    p=argparse.ArgumentParser();p.add_argument("--batch",type=Path,required=True);p.add_argument("--out",type=Path,required=True);args=p.parse_args()
    result=audit(args.batch,args.out)
    print(json.dumps({"status":result["status"],"checks":result["checks"],"failures":result["failures"],"runs":result["runs"]}, ensure_ascii=False))
    raise SystemExit(result["status"]!="PASS")
