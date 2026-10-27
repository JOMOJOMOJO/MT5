"""Recover a stopped local batch and audit its isolated, per-symbol CSVs.

This reads tester artifacts only. It never starts a terminal or changes a run's
original status; a timed-out batch remains incomplete even if some passes passed.
"""
from __future__ import annotations

import argparse
import collections
import csv
import hashlib
import json
from pathlib import Path
import re
import shutil
import os


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def rows(path):
    with Path(path).open(encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle, delimiter=";"))


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def dump(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def recover(package):
    provenance = read_json(package / "provenance.json")
    status = read_json(package / "status.json")
    if status["status"] in {"RUNNING", "COMPILING"}:
        raise ValueError("Only recover a stopped run; active files may be buffered")
    runtime = Path(provenance["runtime"])
    common = Path(os.environ["APPDATA"]) / "MetaQuotes/Terminal/Common/Files"
    tag = status["tag"]
    private = re.findall(r"(?m)^Login=(\d+)\s*$", (runtime / "config/common.ini").read_text(encoding="utf-8-sig"))
    for folder in ("logs", "Tester"):
        for source in (runtime / folder).rglob("*.log"):
            content = source.read_text(encoding="utf-16", errors="replace")
            for token in private:
                content = content.replace(token, "[ACCOUNT]")
            content = re.sub(r"'\d{5,}'", "'[ACCOUNT]'", content)
            content = re.sub(r"(?im)((?:password|login|account)\s*[=:]\s*)\S+", r"\1[REDACTED]", content)
            target = package / "journals" / source.relative_to(runtime)
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content, encoding="utf-8")
    for event_file in common.glob(tag + "*_events.csv"):
        resolved = event_file.name.removesuffix("_events.csv")
        config_path = common / (resolved + "_config.csv")
        config = {row["parameter"]: row["value"] for row in rows(config_path)}
        target = package / "passes" / config["symbol"]
        if target.exists():
            raise ValueError("Recovery refuses to replace existing pass directory")
        target.mkdir(parents=True)
        for kind in ("events", "config", "upper_bars", "lower_bars", "opposite_ticks"):
            source = common / (resolved + "_" + kind + ".csv")
            if source.exists():
                shutil.copy2(source, target / (kind + ".csv"))


def audit(package, single):
    provenance = read_json(package / "provenance.json")
    status = read_json(package / "status.json")
    if status["status"] in {"RUNNING", "COMPILING"}:
        raise ValueError("Do not audit active, potentially buffered files")
    passes, violations, tags = [], [], []
    for path in sorted((package / "passes").iterdir()):
        config = {row["parameter"]: row["value"] for row in rows(path / "config.csv")}
        events = rows(path / "events.csv")
        counts = dict(collections.Counter(row["event_type"] for row in events))
        symbols = sorted({row["symbol"] for row in events if row["symbol"]})
        tag = config["resolved_run_tag"]
        tags.append(tag)
        if symbols != [config["symbol"]] or counts.get("INIT") != 1:
            violations.append({"symbol": config["symbol"], "problem": "mixed symbol or missing INIT"})
        if config.get("optimization") != "1" or config.get("effective_draw") not in {"false", "0"}:
            violations.append({"symbol": config["symbol"], "problem": "wrong execution context"})
        missing = [kind for kind in ("events", "config", "upper_bars", "lower_bars", "opposite_ticks") if not (path / (kind + ".csv")).exists()]
        if missing:
            violations.append({"symbol": config["symbol"], "missing_csv": missing})
        passes.append({"symbol": config["symbol"], "path": str(path), "tag": tag, "event_counts": counts,
                       "last_event_at": events[-1]["event_at"] if events else None,
                       "sha256": {item.name: sha(item) for item in path.glob("*.csv")}})
    if len(set(tags)) != len(tags):
        violations.append({"problem": "duplicate resolved run tag"})
    native, rejected = [], []
    for source in (package / "journals/Tester").rglob("*.log"):
        current = None
        for line in source.read_text(encoding="utf-8-sig").splitlines():
            start = re.search(r"optimization pass (\d+) started", line)
            if start:
                current = {"pass": int(start[1]), "symbol": None, "native_completed": False}
                native.append(current)
            resolved = re.search(r"Wave33 resolved run tag: (\S+)", line)
            if resolved and current:
                matching = [item for item in passes if item["tag"] == resolved[1]]
                current["symbol"] = matching[0]["symbol"] if len(matching) == 1 else None
            completed = re.search(r"\t(\d+) : passed in ", line)
            if completed and current and int(completed[1]) == current["pass"]:
                current["native_completed"] = True
            if "OnInit returned non-zero" in line or "INIT_BATCH_" in line or "INIT_HISTORY_NOT_READY" in line:
                rejected.append(line)
    journal_text = "\n".join(source.read_text(encoding="utf-8-sig") for source in (package / "journals").rglob("*.log"))
    finished = re.search(r"testing on Market Watch symbols finished, total passes (\d+)", journal_text)
    native_total = int(finished[1]) if finished else 0
    completed_count = sum(item["native_completed"] for item in native)
    if status["status"] != "FAILED" and (native_total != len(passes) or completed_count != len(passes) or not passes):
        violations.append({"problem": "Native completion does not match observed CSV passes"})
    result = {"status": "PARTIAL_NATIVE_RUN" if status["status"] == "FAILED" else ("PASS_OBSERVED_NATIVE_PASSES" if not violations and not rejected else "FAIL"),
              "original_runner_status": status, "selected_symbols": provenance["selected_symbols"],
              "observed_passes": len(passes), "csv_integrity_violations": violations, "passes": passes,
              "native_passes": native, "native_completed_passes": completed_count, "native_finished_total": native_total,
              "initialization_error_lines": rejected, "model": provenance["model"],
              "orders": sum(item["event_counts"].get("ORDER", 0) for item in passes),
              "fills": sum(item["event_counts"].get("FILL", 0) for item in passes),
              "exits": sum(item["event_counts"].get("EXIT", 0) for item in passes),
              "profitability_assessed": False}
    dump(package / "independent_audit.json", result)
    if single:
        xau = [item for item in passes if item["symbol"] == "XAUUSD+"]
        if len(xau) != 1:
            raise ValueError("Expected exactly one XAUUSD+ pass")
        other = Path(xau[0]["path"])
        ignored = {"DRAWING_CAPTURE", "TEST_END"}
        left = [row for row in rows(single / "events.csv") if row["event_type"] not in ignored]
        right = [row for row in rows(other / "events.csv") if row["event_type"] not in ignored]
        checks = {"all_nonrender_events": left == right,
                  "upper_bars": rows(single / "upper_bars.csv") == rows(other / "upper_bars.csv"),
                  "lower_bars": rows(single / "lower_bars.csv") == rows(other / "lower_bars.csv"),
                  "opposite_ticks": rows(single / "opposite_ticks.csv") == rows(other / "opposite_ticks.csv")}
        differences = []
        for index, (before, after) in enumerate(zip(left, right)):
            changed = {key: {"single": before.get(key), "batch": after.get(key)} for key in set(before) | set(after) if before.get(key) != after.get(key)}
            if changed:
                differences.append({"index": index, "event": before["event_type"], "fields": changed})
        single_model = read_json(single / "run.json")["model"]
        same_model = single_model == provenance["model"]
        # Execution models may change intrabar SL/TP and quote sequences. Keep
        # the exact differences; never relabel them an exact regression PASS.
        comparison_status = "PASS" if all(checks.values()) else ("MODEL_DIFF_REQUIRES_SEPARATE_INTERPRETATION" if not same_model else "FAIL")
        comparison = {"status": comparison_status, "exact_equal": all(checks.values()), "checks": checks,
                      "single": str(single), "batch": str(other), "event_rows": [len(left), len(right)],
                      "differences": differences, "batch_model": provenance["model"], "single_model": single_model,
                      "scope": "All non-render/non-TEST_END event fields, raw bars, and inverse-W1 tick audit; no profitability assessment"}
        dump(package / "xau_single_comparison.json", comparison)
        print(json.dumps({"audit": result["status"], "passes": len(passes), "comparison": comparison["status"], "events": comparison["event_rows"]}))
    else:
        print(json.dumps({"audit": result["status"], "passes": len(passes)}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("package", type=Path)
    parser.add_argument("--recover-stopped", action="store_true")
    parser.add_argument("--single", type=Path)
    args = parser.parse_args()
    if args.recover_stopped:
        recover(args.package)
    audit(args.package, args.single)
