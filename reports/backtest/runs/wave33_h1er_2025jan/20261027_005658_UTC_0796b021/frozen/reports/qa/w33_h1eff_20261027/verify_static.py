"""Build/static gate only. Never starts MT5 or claims runtime tests passed."""
from pathlib import Path
import hashlib
import json
import py_compile
import re
from datetime import datetime, timezone

QA = Path(__file__).resolve().parent
ROOT = QA.parents[2]
checks = []


def check(name, condition, detail=None):
    checks.append({"check": name, "pass": bool(condition), "detail": detail})
    if not condition:
        raise AssertionError((name, detail))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def source_text(path):
    return path.read_text(encoding="utf-8-sig")


def compiled_log(path):
    raw = path.read_bytes()
    return raw.decode("utf-16" if raw[:2] in (b"\xff\xfe", b"\xfe\xff") else "utf-8-sig")


protected = json.loads((QA / "protected_before.json").read_text(encoding="utf-8-sig"))
drift = [name for name, value in protected.items() if sha(ROOT / name) != value]
check("previous_sources_presets_unchanged", not drift, {"count": len(protected), "changed": drift})
ea = ROOT / "mql/Experts/Wave33H1EfficiencyVerifier.mq5"
test = ROOT / "mql/Scripts/tests/Wave33H1EfficiencyTests.mq5"
closure = set()


def includes(path, tree):
    path = path.resolve()
    if path in tree:
        return
    tree.add(path)
    for name in re.findall(r'^\s*#include\s+"([^"]+)"', source_text(path), re.M):
        child = (path.parent / name.replace("\\", "/")).resolve()
        check("include_exists_" + child.name, child.is_file())
        check("include_inside_repository_" + child.name, child.is_relative_to(ROOT))
        includes(child, tree)


trees = {}
for path in (ea, test):
    trees[path] = set()
    includes(path, trees[path])
    closure |= trees[path]
for path, log in [(ea, QA / "compile/Wave33H1EfficiencyVerifier.log"),
                  (test, ROOT / "reports/compile/w33_h1eff_policy_20261027.log")]:
    check("compile_clean_" + path.stem, bool(re.search(r"Result:\s+0 errors,\s+0 warnings", compiled_log(log))))
    binary = path.with_suffix(".ex5")
    check("binary_exists_" + path.stem, binary.is_file())
    # The EA includes all policy tests; the isolated test includes the same math.
    check("binary_fresh_" + path.stem,
          binary.stat().st_mtime >= max(p.stat().st_mtime for p in trees[path]))

inputs = re.findall(r"^\s*input\s+\w+\s+(Inp\w+)\s*=", source_text(ea), re.M)
check("ea_exact_54_unique_inputs", len(inputs) == len(set(inputs)) == 54)
presets = []
for arm in ("OFF", "ON"):
    path = ROOT / f"presets/wave33/Wave33H1Efficiency_v192_B_{arm}.set"
    pairs = [line.split("=", 1) for line in source_text(path).splitlines() if line.startswith("Inp")]
    settings = dict(pairs)
    check("preset_inputs_" + arm, len(pairs) == len(settings) == 54 and set(settings) == set(inputs))
    check("tester_orders_enabled_" + arm, settings["InpEnableTesterOrders"] == "true")
    fixed = {"InpPattern": "1", "InpScaleOut": "true", "InpPartialAtR": "1.0", "InpStepSL": "true",
             "InpStepStartR": "1.5", "InpStepSizeR": "0.5", "InpStepLagR": "0.5", "InpMaxHoldHours": "24.0",
             "InpCloseBeforeWeekend": "true", "InpWeekendBufferMinutes": "5", "InpExitOnOppositeWave1": "true"}
    check("v191_exits_fixed_" + arm, all(settings[k] == v for k, v in fixed.items()))
    check("policy_flag_" + arm, settings["InpSkipH1LowEfficiency"] == str(arm == "ON").lower())
    presets.append(path)
    if arm == "OFF":
        control = settings
    else:
        delta = [k for k in inputs if k != "InpRunTag" and settings[k] != control[k]]
        check("one_decision_parameter_only", delta == ["InpSkipH1LowEfficiency"], delta)

check("default_policy_disabled", "input bool InpSkipH1LowEfficiency=false;" in source_text(ea))
policy_tests = source_text(ROOT / "mql/Include/Wave33Visual/H1EfficiencyTests.mqh")
check("45_runtime_checks_declared_not_executed", len(re.findall(r'W33H1EffCheck\("', policy_tests)) == 45)
script = ROOT / "tools/wave33_visual/h1_er_fixed_compare.py"
py_compile.compile(str(script), doraise=True)
check("offline_analysis_python_compiles", True)
run = ROOT / "reports/backtest/runs/wave33_h1er_2025jan"
ps = json.loads((QA / "powershell_syntax.json").read_text(encoding="utf-8-sig"))
check("powershell_syntax", ps["pass"] and ps["files"] == 2, ps)

status = {"qa_status": "BUILD_STATIC_PASS_NATIVE_PENDING", "created_at_utc": datetime.now(timezone.utc).isoformat(),
          "checks": checks, "protected_count": len(protected), "source_closure_count": len(closure),
          "policy_tests": "45 COMPILED; NATIVE EXECUTION PENDING", "native_performance": "NOT_STARTED",
          "independent_review": "reports/backtest/analysis/wave33_h1_er_compare_20261027/independent_definition_review.md"}
(QA / "build_static_verification.json").write_text(json.dumps(status, indent=2) + "\n", encoding="utf-8")
files = closure | {ea.with_suffix(".ex5"), test.with_suffix(".ex5"), *presets, script,
                  run / "prepare.ps1", run / "launch.ps1", run / "PLAN.md", Path(__file__).resolve()}
deployment = {"qa_status": status["qa_status"], "created_at_utc": status["created_at_utc"],
              "files_sha256": {p.relative_to(ROOT).as_posix(): sha(p) for p in sorted(files)}}
(QA / "deployment.json").write_text(json.dumps(deployment, indent=2) + "\n", encoding="utf-8")
print(f"BUILD_STATIC_PASS_NATIVE_PENDING: {len(checks)} checks, {len(protected)} protected unchanged; 45 runtime checks pending")
