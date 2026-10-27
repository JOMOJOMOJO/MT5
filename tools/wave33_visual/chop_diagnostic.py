"""One preregistered lower-pivot path diagnostic; no outcome inputs or tuning."""
from __future__ import annotations

import argparse
from bisect import bisect_right
from collections import Counter
import csv
from datetime import datetime
import hashlib
import html
import json
import math
from pathlib import Path

VERSION = "LOWER_PIVOT_BACKTRACK_V1"
THRESHOLD = 0.5
GATE = 0.70
ROOT = Path(__file__).resolve().parents[2]
ANNUAL = ROOT / "reports/backtest/runs/wave33_v180_2020/20261023_164915_831ff154"
PREVIOUS = ROOT / "reports/qa/w33entry60"
OUT = ROOT / "reports/qa/w33chop"


def read(path, sep=";"):
    with Path(path).open(encoding="utf-8-sig", newline="") as stream:
        yield from csv.DictReader(stream, delimiter=sep)


def sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def dump(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, indent=2, allow_nan=False), encoding="utf-8")


def stamp(value):
    return value.replace(".", "-") if value else ""


def calculate(snapshot, published, evaluated_at, first_lower_bar_time):
    """Published is an ordered prefix ending strictly before the evaluation row."""
    start = stamp(snapshot["wave1_start_time"])
    end = stamp(snapshot["wave1_peak_time"])
    known = stamp(snapshot["wave1_peak_known_at"])
    start_known = stamp(snapshot.get("wave1_start_known_at", ""))
    evaluated_at = stamp(evaluated_at)
    direction = {"LONG": 1, "SHORT": -1}.get(snapshot["direction"], 0)
    first = float(snapshot["wave1_start_price"])
    last = float(snapshot["wave1_peak_price"])
    span = 0.0
    result = dict(formula=VERSION, threshold=THRESHOLD, status="UNAVAILABLE", reason="",
                  evaluated_at=evaluated_at, first_lower_bar_time=stamp(first_lower_bar_time),
                  wave1_start_time=start, wave1_start_price=first, wave1_peak_time=end,
                  wave1_peak_price=last, wave1_peak_known_at=known,
                  wave1_revision=int(snapshot.get("wave1_revision") or 0), direction=direction,
                  span=span, adverse=None, ratio=None, raw_count=0, normalized_count=0, path=[])
    def unavailable(reason):
        result["reason"] = reason
        return result
    if (snapshot.get("wave1_peak_fixed") != "1" or snapshot.get("wave1_extension_pending") == "1"
            or not start or not end or start >= end or not start_known or not known):
        return unavailable("FIXED_ANCHORS_MISSING")
    if start_known > evaluated_at or known > evaluated_at:
        return unavailable("ANCHOR_NOT_KNOWN")
    if start_known < start or known < end:
        return unavailable("ANCHOR_KNOWN_BEFORE_SOURCE")
    if direction not in (-1, 1) or not all(math.isfinite(x) and x > 0 for x in (first, last)):
        return unavailable("INVALID_ANCHORS")
    span = direction * (last - first)
    result["span"] = span
    if span <= 0:
        return unavailable("NONPOSITIVE_DIRECTIONAL_SPAN")
    if not first_lower_bar_time or stamp(first_lower_bar_time) > start:
        return unavailable("LOWER_HISTORY_INCOMPLETE")
    raw = [p for p in published if p["tf"] == snapshot["lower_tf"]
           and p["known_at"] <= evaluated_at and start < p["time"] < end]
    normalized = []
    previous = None
    for p in raw:
        # Match MQL's validation order and the processed-prefix raw count.
        result["raw_count"] += 1
        if not p["known_at"] or p["known_at"] < p["time"]:
            return unavailable("PIVOT_KNOWN_BEFORE_SOURCE")
        if not math.isfinite(p["price"]) or p["price"] <= 0:
            return unavailable("INVALID_PIVOT_PRICE")
        if previous and (p["time"] < previous["time"] or p["known_at"] < previous["known_at"]):
            return unavailable("PIVOT_CHRONOLOGY")
        if previous and p["time"] == previous["time"] and p["is_high"] != previous["is_high"]:
            return unavailable("SAME_TIME_HIGH_LOW_AMBIGUOUS")
        previous = p
        if normalized and normalized[-1]["is_high"] == p["is_high"]:
            if (p["price"] > normalized[-1]["price"] if p["is_high"] else p["price"] < normalized[-1]["price"]):
                normalized[-1] = p
        else:
            normalized.append(p)
    result["normalized_count"] = len(normalized)
    start_node = dict(time=start, known_at=start_known,
                      price=first, kind="START", event_sequence=None)
    end_node = dict(time=end, known_at=known, price=last, kind="PEAK", event_sequence=None)
    result["path"] = [start_node] + [dict(p, kind="H" if p["is_high"] else "L") for p in normalized] + [end_node]
    adverse = sum(max(0.0, -direction * (b["price"] - a["price"]))
                  for a, b in zip(result["path"], result["path"][1:]))
    result.update(adverse=adverse, ratio=adverse / span,
                  status="CHOPPY" if adverse / span >= THRESHOLD else "CLEAN")
    return result


def extract():
    target = OUT / "features.json"
    if target.exists():
        raise SystemExit("Frozen features already exist; refusing overwrite.")
    baseline = json.loads((OUT / "baseline.json").read_text(encoding="utf-8"))
    assert sha(ROOT / baseline["plan"]) == baseline["plan_sha256"]
    source_hashes = {str(ROOT / baseline["plan"]): baseline["plan_sha256"]}
    feature_path = PREVIOUS / "data/features_causal.csv"
    source_hashes[str(feature_path)] = sha(feature_path)
    identities = {(r["arm"], r["setup_id"]): r for r in read(feature_path, ",")}
    assert len(identities) == 440
    cases = []
    for arm in ("A", "B"):
        run = ANNUAL / f"v180_{arm.lower()}_both"
        events_path, bars_path = run / "events.csv", run / "lower_bars.csv"
        for p in (events_path, bars_path):
            source_hashes[str(p)] = sha(p)
        first_bar = next(read(bars_path))
        published = []
        for seq, row in enumerate(read(events_path)):
            if row["event_type"] == "ORDER" and (arm, row["setup_id"]) in identities:
                identity = identities[(arm, row["setup_id"])]
                assert seq == int(identity["order_sequence"])
                result = calculate(row, published, row["event_at"], first_bar["bar_time"])
                result.update(arm=arm, setup_id=row["setup_id"], blind_id=identity["blind_id"],
                              evaluation_sequence=seq, evaluation_event="ORDER", source_events=str(events_path))
                assert all(p["event_sequence"] < seq and p["known_at"] <= result["evaluated_at"]
                           for p in result["path"] if p["event_sequence"] is not None)
                cases.append(result)
            if row["event_type"] == "PIVOT_CONFIRMED":
                published.append(dict(time=stamp(row["observed_pivot_time"]),
                    known_at=stamp(row["observed_pivot_known_at"]),
                    price=float(row["observed_pivot_price"]), tf=row["observed_pivot_tf"],
                    is_high=row["observed_pivot_label"] in ("H", "HH", "LH"), event_sequence=seq))
    assert len(cases) == 440 and sum(bool(c["blind_id"]) for c in cases) == 60
    assert all(sha(Path(p)) == value for p, value in source_hashes.items())
    dump(target, dict(formula=VERSION, threshold=THRESHOLD, labels_read=False, cases=cases,
                     inputs=source_hashes, plan_sha256=baseline["plan_sha256"], script_sha256=sha(__file__)))
    print(json.dumps(dict(cases=len(cases), selected=60, status_counts=Counter(c["status"] for c in cases))))


def compare():
    target = OUT / "agreement.json"
    if target.exists():
        raise SystemExit("Frozen agreement exists; refusing overwrite.")
    features_path = OUT / "features.json"
    cases = json.loads(features_path.read_text(encoding="utf-8"))["cases"]
    review_paths = [PREVIOUS / "reviews/odd_annotations.json", PREVIOUS / "audit/even_blind_review.json"]
    humans = {}
    for p in review_paths:
        for c in json.loads(p.read_text(encoding="utf-8"))["cases"]:
            humans[c["blind_id"]] = "CLEAN" if c["w1_progress"] == "CLEAN" else "CHOPPY"
    assert Counter(humans.values()) == {"CLEAN": 35, "CHOPPY": 25}
    matrix = {h: {p: 0 for p in ("CLEAN", "CHOPPY", "UNAVAILABLE")} for h in ("CLEAN", "CHOPPY")}
    selected = []
    for c in sorted((c for c in cases if c["blind_id"]), key=lambda x: x["blind_id"]):
        human = humans[c["blind_id"]]
        matrix[human][c["status"]] += 1
        selected.append(dict(c, human=human, match=c["status"] == human))
    recalls = {h: matrix[h][h] / sum(matrix[h].values()) for h in matrix}
    result = dict(labels_read=False, metric=VERSION, threshold=THRESHOLD, gate=GATE,
                  plan_sha256=json.loads((OUT / "baseline.json").read_text())["plan_sha256"],
                  features_sha256=sha(features_path), reviews_sha256={str(p): sha(p) for p in review_paths},
                  confusion_matrix=matrix, recalls=recalls, min_recall=min(recalls.values()),
                  passed=min(recalls.values()) >= GATE,
                  accuracy=sum(c["match"] for c in selected) / 60,
                  available=sum(c["status"] != "UNAVAILABLE" for c in selected), cases=selected)
    dump(target, result)
    print(json.dumps({k: v for k, v in result.items() if k != "cases"}, ensure_ascii=False))


def gallery():
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    result = json.loads((OUT / "agreement.json").read_text(encoding="utf-8"))
    charts = OUT / "charts"
    charts.mkdir(exist_ok=True)
    cards = []
    for c in result["cases"]:
        case_id = c["blind_id"]
        fig, ax = plt.subplots(figsize=(7.0, 3.2), dpi=130)
        ax.axhline(0, color="#aaaaaa", lw=.6)
        ax.axhline(1, color="#aaaaaa", lw=.6)
        if c["path"]:
            origin = datetime.fromisoformat(c["wave1_start_time"])
            xs = [(datetime.fromisoformat(p["time"]) - origin).total_seconds() / 60 for p in c["path"]]
            ys = [c["direction"] * (p["price"] - c["wave1_start_price"]) / c["span"] for p in c["path"]]
            for i in range(len(xs) - 1):
                ax.plot(xs[i:i+2], ys[i:i+2], marker="o", markersize=3,
                        color="#d34848" if ys[i+1] < ys[i] else "#147da0", lw=1.5)
            for i in (0, len(xs)-1):
                ax.annotate(c["path"][i]["kind"], (xs[i], ys[i]), xytext=(3, 5), textcoords="offset points", fontsize=8)
        else:
            ax.text(.5, .5, c["reason"], transform=ax.transAxes, ha="center", fontsize=9, wrap=True)
        ratio = "N/A" if c["ratio"] is None else f'{c["ratio"]:.3f}'
        ax.set_title(f'{case_id} | human {c["human"]} / metric {c["status"]} | backtrack {ratio}', fontsize=10)
        ax.set_xlabel("Minutes from fixed W1 start (source time)", fontsize=8)
        ax.set_ylabel("Directional distance / W1 span", fontsize=8)
        ax.tick_params(labelsize=8)
        ax.grid(alpha=.15)
        fig.tight_layout()
        fig.savefig(charts / f"{case_id}.png")
        plt.close(fig)
        cls = "match" if c["match"] else "mismatch"
        detail = html.escape(f'{c["arm"]} | ORDER known {c["evaluated_at"]} | r{c["wave1_revision"]} | lower pivots {c["normalized_count"]} | {c["reason"]}')
        cards.append(f'<article class="{cls}"><h2>{case_id} {cls}</h2><p>{detail}</p>'
            f'<a href="charts/{case_id}.png"><img loading="lazy" src="charts/{case_id}.png"></a>'
            f'<details><summary>元のエントリー前画像</summary><a href="../w33entry60/charts/{case_id}.png">'
            f'<img loading="lazy" src="../w33entry60/charts/{case_id}.png"></a></details></article>')
    summary = "通過" if result["passed"] else "未通過"
    page = f'''<!doctype html><html lang="ja"><meta charset="utf-8"><title>①内部の往復診断</title>
<style>body{{font-family:system-ui;background:#f4f6fa;color:#182838;margin:24px}}main{{display:grid;grid-template-columns:repeat(auto-fit,minmax(500px,1fr));gap:16px}}article{{background:white;padding:14px;border-radius:8px;border-left:5px solid #44877b}}article.mismatch{{border-color:#cc7565}}img{{width:100%;height:auto}}h2{{font-size:18px}}p{{font-size:13px;overflow-wrap:anywhere}}summary{{cursor:pointer;padding:8px}}button{{padding:8px;margin-bottom:15px}}</style>
<h1>①内部の往復診断：固定60件</h1><p>逆行幅合計÷①幅 ≥0.5 をCHOPPY。赤線は①と逆方向への移動。起点・終点は既存EAのまま。</p>
<p>人判定再現ゲート：{summary}。CLEAN {result['recalls']['CLEAN']:.1%}、CHOPPY {result['recalls']['CHOPPY']:.1%}。必要基準は両方70%以上。取引除外には使っていません。</p>
<p>全440件の原本履歴から復元。元画像の表示窓より前の既知pivotも含みます。損益・決済情報は判定・集計に使っていません。横軸の時間空白には休場時間も含みます。</p>
<button onclick="document.querySelectorAll('article.match').forEach(x=>x.hidden=!x.hidden)">一致した事例を表示／非表示</button><main>{''.join(cards)}</main></html>'''
    (OUT / "index.html").write_text(page, encoding="utf-8")
    print(json.dumps(dict(charts=60, gallery=str(OUT / "index.html"))))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=("extract", "compare", "gallery"))
    args = parser.parse_args()
    {"extract": extract, "compare": compare, "gallery": gallery}[args.stage]()
