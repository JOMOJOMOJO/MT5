"""Verify engineering-only input guards without replacing frozen experiment files."""
import copy
import importlib.util
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
OUT = ROOT / "reports/qa/w33chop"
spec = importlib.util.spec_from_file_location("guarded_chop", ROOT / "tools/wave33_visual/chop_diagnostic.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def main():
    features_path, agreement_path = OUT / "features.json", OUT / "agreement.json"
    frozen_hashes = {str(p.relative_to(ROOT)): module.sha(p) for p in [features_path, agreement_path]}
    frozen = json.loads(features_path.read_text(encoding="utf-8"))
    reference = {(x["arm"], x["setup_id"]): x for x in frozen["cases"]}
    preserved = OUT / "audit/python_pre_guard.py"
    assert module.sha(preserved) == frozen["script_sha256"]
    reason_rename = {"AMBIGUOUS_SAME_BAR_HIGH_LOW": "SAME_TIME_HIGH_LOW_AMBIGUOUS"}
    cases, changed_counts = 0, []
    for arm in ("A", "B"):
        folder = module.ANNUAL / f"v180_{arm.lower()}_both"
        first = next(module.read(folder / "lower_bars.csv"))["bar_time"]
        published = []
        for seq, row in enumerate(module.read(folder / "events.csv")):
            if row["event_type"] == "ORDER":
                new = module.calculate(row, published, row["event_at"], first)
                old = reference[arm, row["setup_id"]]
                assert new["status"] == old["status"]
                assert new["reason"] == reason_rename.get(old["reason"], old["reason"])
                for name in ["span", "adverse", "ratio", "path", "normalized_count"]:
                    assert new[name] == old[name], (arm, row["setup_id"], name)
                if new["raw_count"] != old["raw_count"]:
                    assert new["status"] == "UNAVAILABLE" and new["reason"] == "SAME_TIME_HIGH_LOW_AMBIGUOUS"
                    assert new["raw_count"] < old["raw_count"]
                    changed_counts.append(dict(arm=arm, setup_id=row["setup_id"], before=old["raw_count"], after=new["raw_count"]))
                cases += 1
            if row["event_type"] == "PIVOT_CONFIRMED":
                published.append(dict(time=module.stamp(row["observed_pivot_time"]), known_at=module.stamp(row["observed_pivot_known_at"]),
                                      price=float(row["observed_pivot_price"]), tf=row["observed_pivot_tf"],
                                      is_high=row["observed_pivot_label"] in ("H", "HH", "LH"), event_sequence=seq))
    assert cases == 440
    base = dict(direction="LONG", wave1_start_time="2020-01-01 00:01:00", wave1_start_known_at="2020-01-01 00:02:00",
                wave1_start_price="100", wave1_peak_time="2020-01-01 00:10:00", wave1_peak_known_at="2020-01-01 00:13:00",
                wave1_peak_price="110", wave1_peak_fixed="1", wave1_extension_pending="0", lower_tf="PERIOD_M1")
    at, coverage = "2020-01-01 00:15:00", "2020-01-01 00:00:00"
    pivots = [dict(time="2020-01-01 00:03:00", known_at="2020-01-01 00:05:00", price=108., tf="PERIOD_M1", is_high=True, event_sequence=1),
              dict(time="2020-01-01 00:05:00", known_at="2020-01-01 00:07:00", price=103., tf="PERIOD_M1", is_high=False, event_sequence=2)]
    tests = []
    def check(name, expected, reason="", edits=None, points=None, first=coverage, ratio=None):
        s = dict(base, **(edits or {}))
        measured = module.calculate(s, copy.deepcopy(pivots if points is None else points), at, first)
        assert measured["status"] == expected and measured["reason"] == reason, (name, measured)
        if ratio is not None:
            assert math.isclose(measured["ratio"], ratio, abs_tol=1e-12)
        tests.append(dict(test=name, status="PASS", actual=measured["status"], reason=measured["reason"]))
    check("exact_half_boundary", "CHOPPY", ratio=.5)
    check("short_mirror", "CHOPPY", edits=dict(direction="SHORT", wave1_start_price="200", wave1_peak_price="190"),
          points=[dict(p, price=300-p["price"], is_high=not p["is_high"]) for p in pivots], ratio=.5)
    check("missing_anchor_known", "UNAVAILABLE", "FIXED_ANCHORS_MISSING", edits=dict(wave1_start_known_at=""))
    check("future_start_anchor_known", "UNAVAILABLE", "ANCHOR_NOT_KNOWN", edits=dict(wave1_start_known_at="2020-01-01 00:16:00"))
    check("future_peak_anchor_known", "UNAVAILABLE", "ANCHOR_NOT_KNOWN", edits=dict(wave1_peak_known_at="2020-01-01 00:16:00"))
    check("start_known_before_source", "UNAVAILABLE", "ANCHOR_KNOWN_BEFORE_SOURCE", edits=dict(wave1_start_known_at="2020-01-01 00:00:00"))
    check("peak_known_before_source", "UNAVAILABLE", "ANCHOR_KNOWN_BEFORE_SOURCE", edits=dict(wave1_peak_known_at="2020-01-01 00:09:00"))
    check("invalid_direction", "UNAVAILABLE", "INVALID_ANCHORS", edits=dict(direction="FLAT"))
    check("infinite_anchor_price", "UNAVAILABLE", "INVALID_ANCHORS", edits=dict(wave1_start_price="inf"))
    check("nonpositive_directional_span", "UNAVAILABLE", "NONPOSITIVE_DIRECTIONAL_SPAN", edits=dict(wave1_peak_price="99"))
    check("missing_coverage", "UNAVAILABLE", "LOWER_HISTORY_INCOMPLETE", first="")
    check("late_coverage", "UNAVAILABLE", "LOWER_HISTORY_INCOMPLETE", first="2020-01-01 00:02:00")
    check("exact_coverage", "CHOPPY", first=base["wave1_start_time"], ratio=.5)
    check("pivot_known_before_source", "UNAVAILABLE", "PIVOT_KNOWN_BEFORE_SOURCE", points=[dict(pivots[0], known_at="2020-01-01 00:02:00")])
    check("invalid_pivot_price", "UNAVAILABLE", "INVALID_PIVOT_PRICE", points=[dict(pivots[0], price=float("nan"))])
    check("zero_interior", "CLEAN", points=[], ratio=0.)
    check("future_pivot_ignored", "CLEAN", points=[pivots[0], dict(pivots[1], known_at="2020-01-01 00:16:00")], ratio=0.)
    check("source_order_invalid", "UNAVAILABLE", "PIVOT_CHRONOLOGY", points=list(reversed(pivots)))
    check("same_source_hl", "UNAVAILABLE", "SAME_TIME_HIGH_LOW_AMBIGUOUS", points=[pivots[0], dict(pivots[1], time=pivots[0]["time"], known_at=pivots[0]["known_at"])])
    for path, expected in frozen_hashes.items():
        assert module.sha(ROOT / path) == expected
    result = dict(status="PASS", scope="engineering input validation only; no threshold or valid formula changes", outcomes_used=False,
                  original_script_sha256=frozen["script_sha256"], guarded_script_sha256=module.sha(ROOT / "tools/wave33_visual/chop_diagnostic.py"),
                  frozen_experiment_files_unchanged=frozen_hashes, annual_status_numeric_path_identical=440,
                  changed_unavailable_raw_counts=changed_counts, reason_rename=reason_rename,
                  note="UNAVAILABLE raw_count now counts processed prefix through first ambiguity, matching MQL. Frozen experiment files retain original full eligible count.",
                  synthetic_guard_tests=tests)
    (OUT / "audit/guard_verification.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(dict(status="PASS", annual_identical=440, guard_tests=len(tests), unavailable_prefix_count_changes=len(changed_counts),
                          guarded_sha256=result["guarded_script_sha256"])))


if __name__ == "__main__":
    main()
