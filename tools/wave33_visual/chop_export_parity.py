"""Export all 60 frozen shape cases for native MQL calculation parity."""
from __future__ import annotations
import csv
from pathlib import Path
import json
from chop_diagnostic import ANNUAL, OUT, read, stamp, sha

FIELDS = "scenario_id row_type direction upper_tf lower_tf start_time start_known_at start_price peak_time peak_known_at peak_price evaluation_at first_lower_bar_time revision pivot_time pivot_known_at pivot_price pivot_is_high expected_status expected_ratio".split()


def mqltime(s):
    return stamp(s)[:10].replace("-", ".") + stamp(s)[10:] if s else ""


def main():
    target = OUT / "parity_input.csv"
    if target.exists():
        raise SystemExit("Refusing to overwrite frozen native parity fixture.")
    cases = {c["setup_id"]: c for c in json.loads((OUT / "features.json").read_text())["cases"] if c["blind_id"]}
    output = []
    for arm in ("A", "B"):
        pivots = []
        for seq, r in enumerate(read(ANNUAL / f"v180_{arm.lower()}_both/events.csv")):
            if r["event_type"] == "ORDER" and r["setup_id"] in cases:
                c = cases[r["setup_id"]]
                assert c["arm"] == arm and c["evaluation_sequence"] == seq
                output.append(dict(scenario_id=c["blind_id"], row_type="SETUP", direction=c["direction"],
                    upper_tf=int(r["upper_tf"].removeprefix("PERIOD_M")), lower_tf=int(r["lower_tf"].removeprefix("PERIOD_M")),
                    start_time=mqltime(r["wave1_start_time"]), start_known_at=mqltime(r["wave1_start_known_at"]),
                    start_price=r["wave1_start_price"], peak_time=mqltime(r["wave1_peak_time"]),
                    peak_known_at=mqltime(r["wave1_peak_known_at"]), peak_price=r["wave1_peak_price"],
                    evaluation_at=mqltime(r["event_at"]), first_lower_bar_time=mqltime(c["first_lower_bar_time"]),
                    revision=c["wave1_revision"]))
                for p in pivots:
                    if p["tf"] == r["lower_tf"] and c["wave1_start_time"] < p["time"] < c["wave1_peak_time"]:
                        assert p["seq"] < seq and p["known"] <= c["evaluated_at"]
                        output.append(dict(scenario_id=c["blind_id"], row_type="PIVOT", pivot_time=mqltime(p["time"]),
                            pivot_known_at=mqltime(p["known"]), pivot_price=p["price"], pivot_is_high=p["high"]))
                output.append(dict(scenario_id=c["blind_id"], row_type="EVAL", expected_status=c["status"],
                                   expected_ratio="" if c["ratio"] is None else repr(c["ratio"])))
            if r["event_type"] == "PIVOT_CONFIRMED":
                pivots.append(dict(tf=r["observed_pivot_tf"], time=stamp(r["observed_pivot_time"]),
                    known=stamp(r["observed_pivot_known_at"]), price=r["observed_pivot_price"],
                    high=int(r["observed_pivot_label"] in ("H", "HH", "LH")), seq=seq))
    assert sum(r["row_type"] == "EVAL" for r in output) == 60
    with target.open("w", encoding="utf-8-sig", newline="") as stream:
        w = csv.DictWriter(stream, fieldnames=FIELDS, delimiter=";")
        w.writeheader()
        w.writerows(output)
    print(json.dumps(dict(cases=60, rows=len(output), path=str(target), sha256=sha(target))))


if __name__ == "__main__":
    main()
