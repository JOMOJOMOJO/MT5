#!/usr/bin/env python3
"""Create Step 15E hash, QA, large-artifact, and manifest evidence."""
from __future__ import annotations
import csv, hashlib, re, subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'reports/backtest/runs/20260830_ts15e_tail_v1_persistent_medium_horizon_202503'
QA=ROOT/'reports/qa/tick_shock/step15e'
MAN=ROOT/'docs/research/tick_shock/00_artifact_manifest.md'
BASE='695c60177c8ddef1718e2fcc66505e88bc3a1e94'
RUNID='ts15e_medium_horizon_202503'
SOURCE_COMMIT='ce46a52204dae05dddff680bdc5f6d56907bb08e'
SCHEMA='tickshock-medium-horizon-response-v1'

def sha(p:Path)->str:
    h=hashlib.sha256()
    with p.open('rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''): h.update(block)
    return h.hexdigest().upper()

def rel(p:Path)->str:return p.relative_to(ROOT).as_posix()

def commit_for(path:str)->str:
    out=subprocess.run(['git','log','-1','--format=%H','--',path],cwd=ROOT,text=True,capture_output=True,check=True).stdout.strip()
    return out or 'SELF'

def main():
    QA.mkdir(parents=True,exist_ok=True)
    tracked=subprocess.run(['git','diff','--name-only',f'{BASE}..HEAD'],cwd=ROOT,text=True,capture_output=True,check=True).stdout.splitlines()
    final_paths=[
      'docs/research/tick_shock/02_function_catalog.md','docs/research/tick_shock/02_data_structures_and_globals.md',
      'docs/research/tick_shock/15e_final_qa.md','docs/devlog/2026-08-30-tickshock-step15e-medium-horizon.md',
      'reports/qa/tick_shock/step15e/step15e_final_qa.csv','reports/qa/tick_shock/step15e/step15e_artifact_hashes.csv',
      'reports/qa/tick_shock/step15e/step15e_large_artifacts.csv','tools/tick_shock/finalize_step15e.py'
    ]
    raw=[rel(p) for p in RUN.iterdir() if p.is_file() and rel(p) not in tracked]
    paths=sorted(set(tracked+final_paths+raw))
    with (QA/'step15e_artifact_hashes.csv').open('w',newline='',encoding='utf-8') as f:
        w=csv.writer(f);w.writerow(['path','size_bytes','sha256','classification','commit_target'])
        for path in paths:
            p=ROOT/path
            if p.exists():w.writerow([path,p.stat().st_size,sha(p),'source_or_evidence' if p.stat().st_size<=50_000_000 else 'large_generated_evidence','yes' if path in tracked or path in final_paths else 'no'])
    with (QA/'step15e_large_artifacts.csv').open('w',newline='',encoding='utf-8') as f:
        w=csv.writer(f);w.writerow(['path','size_bytes','sha256','run_id','source_commit','schema_version','regeneration_command','commit_target'])
        for p in sorted(RUN.iterdir()):
            if p.is_file() and p.stat().st_size>50_000_000:
                w.writerow([rel(p),p.stat().st_size,sha(p),RUNID,SOURCE_COMMIT,SCHEMA,'powershell -NoProfile -ExecutionPolicy Bypass -File tools/tick_shock/run_step15e_march.ps1 -TimeoutSeconds 2400','no'])
    checks=[
      ('S15E-QA-001','baseline_test_rollup','PASS','PASS248_FAIL0_XFAIL0_XPASS0_SKIP9_BLOCKED0','reports/tests/tick_shock/step15e_green/legacy_regression_summary.txt'),
      ('S15E-QA-002','new_production_path_tests','PASS','PASS28_FAIL0_XFAIL0_XPASS0_SKIP0_BLOCKED0','reports/tests/tick_shock/step15e_green/step15e_green_results.csv'),
      ('S15E-QA-003','compile','PASS','16_targets_0_errors_0_warnings','reports/tests/tick_shock/step15e_green/compile_results.csv'),
      ('S15E-QA-004','independent_oracle','PASS','28_rows_0_mismatches','reports/tests/tick_shock/step15e_green/independent_oracle.csv'),
      ('S15E-QA-005','step15d_identity','PASS','detector_path_cluster_mismatches_0','reports/analysis/tick_shock/step15e/step15d_behavior_comparison.csv'),
      ('S15E-QA-006','parameter_diff','PASS','differences_0','reports/analysis/tick_shock/step15e/parameter_diff.csv'),
      ('S15E-QA-007','causal_integrity','PASS','future_backdate_drop_capacity_duplicate_episode_0','reports/analysis/tick_shock/step15e/analysis_summary.json'),
      ('S15E-QA-008','orders','PASS','production_order_rows_0','reports/backtest/runs/20260830_ts15e_tail_v1_persistent_medium_horizon_202503/trades.csv'),
      ('S15E-QA-009','fallback_primary','PARTIAL','GBPUSD_179_of_30187_minutes_all_417_episodes_excluded','reports/backtest/runs/20260830_ts15e_tail_v1_persistent_medium_horizon_202503/tick_quality.csv'),
      ('S15E-QA-010','matched_control','NOT_ESTIMABLE','causal_15m_control_path_not_recorded','reports/analysis/tick_shock/step15e/matched_control_results.csv'),
      ('S15E-QA-011','formal_net','UNAVAILABLE','commission_and_slippage_incomplete','reports/analysis/tick_shock/step15e/cost_headroom.csv'),
      ('S15E-QA-012','candidate_gate','PASS','candidate_rows_0_no_hypothesis_frozen','reports/analysis/tick_shock/step15e/candidate_registry.csv'),
      ('S15E-QA-013','tick_accounting','PARTIAL','ea_summary_10587809_vs_tester_journal_10587807_definition_difference_2','reports/backtest/runs/20260830_ts15e_tail_v1_persistent_medium_horizon_202503/summary.md')]
    with (QA/'step15e_final_qa.csv').open('w',newline='',encoding='utf-8') as f:
        w=csv.writer(f);w.writerow(['check_id','category','status','actual','evidence_path']);w.writerows(checks)

    text=MAN.read_text(encoding='utf-8')
    text=re.sub(r'- branch: `[^`]+`','- branch: `research/tickshock-step15e-medium-horizon-response-20260830`',text,count=1)
    text=re.sub(r'- status: `[^`]+`','- status: `STEP15E_DEVELOPMENT_PATHS_CHARACTERIZED_NO_HYPOTHESIS_FROZEN`',text,count=1)
    text=re.sub(r'- manifest_revision: `[^`]+`','- manifest_revision: `15E`',text,count=1)
    text=re.sub(r'- covered_steps: `[^`]+`','- covered_steps: `01-15E`',text,count=1)
    text=re.sub(r'- last_updated_at: `[^`]+`','- last_updated_at: `2026-08-30T23:59:00+09:00`',text,count=1)
    marker='\n## Step 15E medium-horizon development rollup\n'
    if marker in text:text=text.split(marker,1)[0]
    text += marker+'\nThis rollup records the causal 15-minute episode engine, 28 RED-to-GREEN contracts, March development run, independent analysis and final QA. Raw run files above 50 MB remain local and are registered with hash and regeneration command. New artifact IDs are checked for uniqueness; path rows intentionally supersede older hashes when a current document or source was updated.\n\n| artifact ID | step | artifact relative path | type | purpose | source/generated | SHA-256 | commit | next Step | status | note | owning_commit |\n|---|---:|---|---|---|---|---|---|---|---|---|---|\n'
    existing=set(re.findall(r'^\|\s*([^|]+?)\s*\|\s*(?:\d+|15[A-Z])\s*\|',text,re.M))
    seq=1
    rows=[]
    for path in paths:
        p=ROOT/path
        if not p.exists():continue
        while f'TS-S15E-{seq:04d}' in existing:seq+=1
        aid=f'TS-S15E-{seq:04d}';seq+=1
        generated=path.startswith('reports/') or path.endswith('.ex5')
        committed=path in tracked or path in final_paths
        digest='SELF' if path==rel(MAN) else sha(p)
        owner=commit_for(path) if path in tracked else 'SELF'
        rows.append(f'| {aid} | 15E | `{path}` | {"evidence" if generated else "source/document"} | Step 15E medium-horizon study | {"generated evidence" if generated else "source"} | `{digest}` | {"yes" if committed else "no"} | stop after Step 15E | {"COMPLETE" if committed else "LOCAL_REPRODUCIBLE_EVIDENCE"} | {"versioned rollup" if committed else "not committed; exact local artifact registered"} | {owner} |')
    text += '\n'.join(rows)+'\n'
    MAN.write_text(text,encoding='utf-8')
    ids=[x.strip() for x in re.findall(r'^\|\s*([^|]+?)\s*\|\s*(?:\d+|15[A-Z])\s*\|',text,re.M)]
    dup=len(ids)-len(set(ids))
    if dup:raise SystemExit(f'manifest duplicate artifact IDs: {dup}')
    latest={};mismatches=[]
    for line in text.splitlines():
        fields=[x.strip() for x in line.split('|')]
        if len(fields)<13 or not fields[1].startswith('TS-S15E-'):continue
        path=fields[3].strip('`');expected=fields[7].strip('`');latest[path]=expected
    for path,expected in latest.items():
        p=ROOT/path
        if p.exists() and expected!='SELF' and sha(p)!=expected:mismatches.append(path)
    if mismatches:raise SystemExit(f'manifest Step15E SHA mismatches: {mismatches}')
    print(f'artifacts={len(paths)} manifest_ids={len(ids)} duplicates={dup} step15e_paths={len(latest)} sha_mismatches={len(mismatches)}')

if __name__=='__main__':main()
