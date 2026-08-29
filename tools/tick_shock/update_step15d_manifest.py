#!/usr/bin/env python3
"""Append an idempotent Step 15D manifest rollup and audit latest paths."""
from __future__ import annotations
import csv, hashlib, re, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];M=ROOT/'docs/research/tick_shock/00_artifact_manifest.md';AUD=ROOT/'reports/qa/tick_shock/step15d/step15d_manifest_audit.csv'
def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
    return h.hexdigest().upper()
def main():
    text=M.read_text(encoding='utf-8-sig');text='\n'.join(line for line in text.splitlines() if not line.startswith('| TS-S15D-'))+'\n'
    text=re.sub(r'- branch: `[^`]+`','- branch: `research/tickshock-step15d-state-conditioned-response-20260829`',text,count=1);text=re.sub(r'- status: `[^`]+`','- status: `STEP15D_DEVELOPMENT_STATE_RESPONSE_COMPLETE_NO_CANDIDATE_PROMOTED`',text,count=1);text=re.sub(r'- manifest_revision: `[^`]+`','- manifest_revision: `15D`',text,count=1);text=re.sub(r'- covered_steps: `[^`]+`','- covered_steps: `01-15D`',text,count=1);text=re.sub(r'- last_updated_at: `[^`]+`','- last_updated_at: `2026-08-30T12:00:00+09:00`',text,count=1)
    committed=subprocess.check_output(['git','diff','--name-only','5118ee5c..HEAD'],cwd=ROOT,text=True).splitlines()
    committed+=subprocess.check_output(['git','diff','--name-only'],cwd=ROOT,text=True).splitlines()
    committed+=subprocess.check_output(['git','diff','--cached','--name-only'],cwd=ROOT,text=True).splitlines()
    compile_rows=list(csv.DictReader((ROOT/'reports/compile/tick_shock/step15c_compile_results.csv').open(encoding='utf-8-sig')))
    extra=['docs/research/tick_shock/15d_final_qa.md','tools/tick_shock/finalize_step15d.py','tools/tick_shock/update_step15d_manifest.py','mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.ex5','mql/Experts/tests/ExpectedValue_TickShock_EventResponseHarness.ex5']+[r['log_path'] for r in compile_rows]+[str(p.relative_to(ROOT)).replace('\\','/') for p in (ROOT/'reports/qa/tick_shock/step15d').glob('*')]
    local_large=['reports/backtest/runs/20260829_ts15d_tail_v1_persistent_state_response_202503_r3/decision_checkpoint_features.csv','reports/backtest/runs/20260829_ts15d_tail_v1_persistent_state_response_202503_r3/event_response.csv','reports/analysis/tick_shock/step15d/decision_checkpoint_features.csv']
    paths=sorted(set(committed+extra+local_large));rows=[]
    for i,path in enumerate(paths,1):
        p=ROOT/path
        if not p.is_file() or p==M:continue
        owning=subprocess.check_output(['git','log','-1','--format=%H','--',path],cwd=ROOT,text=True).strip() or 'SELF'
        generated=path.startswith('reports/');commit='no' if path in local_large else 'yes';status='LOCAL_EXCLUDED_GT_50MB' if path in local_large else 'COMPLETE';digest='SELF_EXCLUDED' if p==AUD else sha(p)
        rows.append(f"| TS-S15D-{i:04d} | 15D | `{path}` | {'generated evidence' if generated else 'source/document'} | Step 15D state-response study | {'generated evidence' if generated else 'source'} | `{digest}` | {commit} | stop after Step 15D | {status} | versioned Step 15D rollup | {owning} |")
    text += '\nStep 15D rollup covers version-aware provenance, preregistration, RED/GREEN evidence, causal state/executable-path implementation, the accepted March r3 replay, development analysis and final QA. Large local CSV rows are hashed but explicitly excluded from normal Git.\n\n'+'\n'.join(rows)+'\n'
    M.write_text(text,encoding='utf-8')
    ids=re.findall(r'^\| (TS-[^| ]+) \|',text,re.M);latest={}
    for line in text.splitlines():
        if not line.startswith('| TS-'):continue
        cells=[c.strip() for c in line.strip('|').split('|')]
        if len(cells)>=7:latest[cells[2].strip('`')]=cells[6].strip('`')
    audit=[]
    for path,digest in latest.items():
        p=ROOT/path
        if path==str(M.relative_to(ROOT)).replace('\\','/') or digest in ('SELF_EXCLUDED',''):continue
        actual=sha(p) if p.is_file() else 'MISSING';audit.append({'path':path,'manifest_sha256':digest,'actual_sha256':actual,'status':'PASS' if actual==digest else 'FAIL'})
    AUD.parent.mkdir(parents=True,exist_ok=True)
    with AUD.open('w',encoding='utf-8',newline='') as f: w=csv.DictWriter(f,fieldnames=['path','manifest_sha256','actual_sha256','status']);w.writeheader();w.writerows(audit)
    print(f'step15d_rows={len(rows)} ids={len(ids)} duplicate_ids={len(ids)-len(set(ids))} latest_paths={len(latest)} sha_failures={sum(r["status"]!="PASS" for r in audit)}')
    return 1 if len(ids)!=len(set(ids)) or any(r['status']!='PASS' for r in audit) else 0
if __name__=='__main__':raise SystemExit(main())
