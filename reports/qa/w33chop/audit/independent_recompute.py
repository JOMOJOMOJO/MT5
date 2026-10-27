"""Independent Decimal implementation; no production or root-tool imports/outcomes."""
import csv
import hashlib
import json
from collections import Counter
from datetime import datetime
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / "reports/qa/w33chop/audit"
BASE = ROOT / "reports/backtest/runs/wave33_v180_2020/20261023_164915_831ff154"


def read(path):
    with path.open(encoding="utf-8-sig", newline="") as handle:
        yield from csv.DictReader(handle, delimiter=";")


def when(value):
    return datetime.fromisoformat(value.replace(".", "-"))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def evaluate(row, sequence, pivots, first):
    start = when(row["wave1_start_time"])
    peak = when(row["wave1_peak_time"])
    at = when(row["event_at"])
    direction = Decimal(1 if row["direction"] == "LONG" else -1)
    origin_price, peak_price = map(Decimal, [row["wave1_start_price"], row["wave1_peak_price"]])
    span = direction * (peak_price - origin_price)
    assert first <= start < peak <= at and span > 0
    assert when(row["wave1_start_known_at"]) <= at
    assert when(row["wave1_peak_known_at"]) <= at
    included = [p for p in pivots if p["seq"] < sequence and p["known"] <= at and start < p["time"] < peak]
    for a, b in zip(included, included[1:]):
        assert a["time"] <= b["time"] and a["known"] <= b["known"]
    ambiguous = any(a["time"] == b["time"] and a["high"] != b["high"] for a, b in zip(included, included[1:]))
    if ambiguous:
        return dict(status="UNAVAILABLE", reason="AMBIGUOUS_SAME_BAR_HIGH_LOW", raw_count=len(included), normalized_count=0,
                    span=float(span), adverse=None, ratio=None, sequences=[])
    normalized = []
    for p in included:
        if normalized and normalized[-1]["high"] == p["high"]:
            prior = normalized[-1]
            if (p["price"] > prior["price"] if p["high"] else p["price"] < prior["price"]):
                normalized[-1] = p
        else:
            normalized.append(p)
    prices = [origin_price] + [p["price"] for p in normalized] + [peak_price]
    adverse = sum((max(Decimal(0), -direction * (b - a)) for a, b in zip(prices, prices[1:])), Decimal(0))
    ratio = adverse / span
    return dict(status="CHOPPY" if ratio >= Decimal("0.5") else "CLEAN", reason="", raw_count=len(included),
                normalized_count=len(normalized), span=float(span), adverse=float(adverse), ratio=float(ratio),
                sequences=[p["seq"] for p in normalized])


def main():
    packets_path = ROOT / "reports/qa/w33entry60/data/blind/packets.json"
    packets = json.loads(packets_path.read_text(encoding="utf-8"))["cases"]
    selected = {p["snapshot"]["setup_id"]: p["blind_id"] for p in packets}
    labels = {}
    frozen = json.loads((ROOT / "reports/qa/w33entry60/reviews/blind_frozen.json").read_text(encoding="utf-8"))
    for path in [ROOT / "reports/qa/w33entry60/reviews/odd_annotations.json", ROOT / "reports/qa/w33entry60/audit/even_blind_review.json"]:
        expected = frozen["annotation_hashes"][str(path.relative_to(ROOT))]
        assert sha(path) == expected
        for item in json.loads(path.read_text(encoding="utf-8"))["cases"]:
            labels[item["blind_id"]] = "CHOPPY" if item["w1_progress"] == "CHOPPY_OR_MIXED" else item["w1_progress"]
    parent_features = json.loads((ROOT / "reports/qa/w33chop/features.json").read_text(encoding="utf-8"))
    reference = {(r["arm"], r["setup_id"]): r for r in parent_features["cases"]}
    result, signals, counters = [], {}, Counter()
    source_hashes = {}
    for arm, folder, tf in [("A", "v180_a_both", "PERIOD_M5"), ("B", "v180_b_both", "PERIOD_M1")]:
        source = BASE / folder / "events.csv"
        bars_path = BASE / folder / "lower_bars.csv"
        source_hashes[str(source.relative_to(ROOT))] = sha(source)
        source_hashes[str(bars_path.relative_to(ROOT))] = sha(bars_path)
        first_bar = next(read(bars_path))
        first = when(first_bar["bar_time"])
        pivots = []
        for sequence, row in enumerate(read(source)):
            kind = row["event_type"]
            if kind == "PIVOT_CONFIRMED" and row["observed_pivot_tf"] == tf:
                pivots.append(dict(seq=sequence, time=when(row["observed_pivot_time"]), known=when(row["observed_pivot_known_at"]),
                                   price=Decimal(row["observed_pivot_price"]), high=row["observed_pivot_label"] in ("H", "HH", "LH")))
            elif kind in ("SIGNAL", "ORDER"):
                # No profit, outcome, exit or order fill fields are accessed.
                assert when(first_bar["known_at"]) <= when(row["event_at"])
                measured = evaluate(row, sequence, pivots, first)
                key = (arm, row["setup_id"])
                if kind == "SIGNAL":
                    signals[key] = measured
                    continue
                ref = reference[key]
                for field in ["status", "reason", "raw_count", "normalized_count"]:
                    assert measured[field] == ref[field], (key, field, measured[field], ref[field])
                for field in ["span", "adverse", "ratio"]:
                    if measured[field] is not None:
                        assert abs(measured[field] - ref[field]) < 1e-9, (key, field)
                assert measured["sequences"] == [p["event_sequence"] for p in ref["path"][1:-1]]
                assert measured == signals[key], ("SIGNAL_ORDER_DIFFERENCE", key)
                counters[measured["status"]] += 1
                if row["setup_id"] in selected:
                    blind = selected[row["setup_id"]]
                    result.append(dict(blind_id=blind, human=labels[blind], arm=arm, sequence=sequence, **measured))
    confusion = {human: dict(Counter(r["status"] for r in result if r["human"] == human)) for human in ["CLEAN", "CHOPPY"]}
    recalls = {human: confusion[human].get(human, 0) / sum(confusion[human].values()) for human in confusion}
    parent_agreement = json.loads((ROOT / "reports/qa/w33chop/agreement.json").read_text(encoding="utf-8"))
    assert confusion == parent_agreement["confusion_matrix"]
    assert recalls == parent_agreement["recalls"]
    assert min(recalls.values()) < .7 and parent_agreement["passed"] is False
    baseline = json.loads((ROOT / "reports/qa/w33chop/baseline.json").read_text(encoding="utf-8"))
    assert sha(ROOT / baseline["plan"]) == baseline["plan_sha256"] == parent_agreement["plan_sha256"]
    protected = {path: sha(ROOT / path) == expected for path, expected in baseline["protected_sources"].items()}
    assert all(protected.values())
    final = dict(status="PASS", implementation="independent Decimal arithmetic, no root-tool/MQL imports", outcomes_used=False,
                 primary_event="ORDER", gate_passed=False, full_440_statuses=dict(counters), selected_cases=len(result),
                 confusion_matrix=confusion, recalls=recalls, signal_order_identical=440, source_hashes=source_hashes,
                 plan_sha256=baseline["plan_sha256"], protected_unchanged=protected, cases=sorted(result, key=lambda r:r["blind_id"]))
    (OUT / "independent_recompute.json").write_text(json.dumps(final, indent=2), encoding="utf-8")
    print(json.dumps({k:v for k,v in final.items() if k not in ("cases", "source_hashes", "protected_unchanged")}))


if __name__ == "__main__":
    main()
