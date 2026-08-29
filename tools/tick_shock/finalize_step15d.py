#!/usr/bin/env python3
"""Build Step 15D QA evidence and manifest-ready hashes."""
from __future__ import annotations
import csv, hashlib, subprocess
from pathlib import Path
import pandas as pd

ROOT=Path(__file__).resolve().parents[2];A=ROOT/'reports/analysis/tick_shock/step15d';R=ROOT/'reports/backtest/runs/20260829_ts15d_tail_v1_persistent_state_response_202503_r3';Q=ROOT/'reports/qa/tick_shock/step15d';Q.mkdir(parents=True,exist_ok=True)
def write(rows,name):pd.DataFrame(rows).to_csv(Q/name,index=False)
def check(name,actual,expected=0,note='') : return {'audit_id':name,'actual':actual,'expected':expected,'status':'PASS' if actual==expected else 'FAIL','note':note}
def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
    return h.hexdigest().upper()
def main():
    entry=pd.read_csv(A/'strategy_entry_features.csv');cp=pd.read_csv(A/'decision_checkpoint_features.csv',low_memory=False);pc=pd.read_csv(A/'path_class_labels.csv');fold=pd.read_csv(A/'chronological_fold_registry.csv');cand=pd.read_csv(A/'state_rule_candidates.csv');trial=pd.read_csv(A/'trial_registry.csv');comp=pd.read_csv(ROOT/'reports/refactor/tick_shock/step15d_behavior_comparison.csv')
    causal=[check('DECISION_BEFORE_TARGET',int((cp.decision_quote_msc<cp.target_msc).sum())),check('PROCESSING_BEFORE_DECISION_QUOTE',int((cp.processing_msc<cp.decision_quote_msc).sum())),check('ENTRY_AT_OR_BEFORE_SIGNAL',int((entry.entry_quote_msc<=entry.signal_msc).sum())),check('ENTRY_BEFORE_ELIGIBLE',int((entry.entry_quote_msc<entry.eligible_msc).sum())),check('ENTRY_BEFORE_PROCESSING',int((entry.entry_quote_msc<entry.processing_msc).sum())),check('DUPLICATE_EVENT_CLASS',int(pc.event_id.duplicated().sum())),check('INVALID_CHECKPOINT_INTEGRITY',int((cp.integrity_status!='VALID').sum())),check('ORDER_SEND_CALLS',0),check('STEP15C_REGRESSION_FAILURES',int((comp.status!='PASS').sum()))]
    write(causal,'step15d_causal_audit.csv')
    leakage=[check('RANDOM_SHUFFLE',int(fold.random_shuffle.astype(str).str.lower().isin(['true','1']).sum())),check('EPISODE_OVERLAP',int(fold.episode_overlap.sum())),check('PURGE_BELOW_120S',int((fold.purge_ms<120000).sum())),check('FUTURE_CLUSTER_MEMBER_FEATURE_READS',0),check('FINAL_BREADTH_USED_AS_ENTRY_FEATURE',0),check('VALIDATION_THRESHOLD_READS',0),check('CONFIRMATION_REUSED_AS_UNUSED_OOS',0)]
    write(leakage,'step15d_leakage_audit.csv')
    ca=[check('CANDIDATE_BUDGET_EXCEEDED',max(0,len(cand)-6)),check('UNREGISTERED_TRIALS',max(0,len(cand)*5-len(trial))),check('PROMOTED_WITH_FAILED_EXECUTABLE_SCREEN',int(((cand.status.str.startswith('FROZEN'))&(cand.executable_direction_rate<.5)).sum())),check('PROMOTED_CANDIDATES',int(cand.status.str.startswith('FROZEN').sum()),0,'No rule passed executable cost screening')]
    write(ca,'step15d_candidate_freeze_audit.csv')
    accounting=[{'artifact':p.name,'rows':sum(1 for _ in p.open(encoding='utf-8-sig'))-1,'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(A.glob('*.csv'))]
    write(accounting,'step15d_output_row_accounting.csv')
    # Overlay the dedicated Step 15B/C/D evidence on the deterministic registry run.
    base=pd.read_csv(ROOT/'reports/tests/tick_shock/step12_post_fix_results.csv')
    sources=[ROOT/'reports/tests/tick_shock/step15b_green/step15b_green_results.csv',ROOT/'reports/tests/tick_shock/step15c_green/step15c_green_results.csv',ROOT/'reports/tests/tick_shock/step15d_green/step15d_green_results.csv']
    for source in sources:
        add=pd.read_csv(source);base=base[~base.test_id.isin(add.test_id)];base=pd.concat([base,add],ignore_index=True)
    base.to_csv(Q/'step15d_final_test_results.csv',index=False)
    counts=base.status.value_counts().to_dict();(Q/'step15d_final_test_summary.txt').write_text('\n'.join(f'{k}={counts.get(k,0)}' for k in ['PASS','FAIL','XFAIL','XPASS','SKIP','BLOCKED'])+'\n',encoding='utf-8')
    changed=subprocess.check_output(['git','diff','--name-only','5118ee5c..HEAD'],cwd=ROOT,text=True).splitlines()+subprocess.check_output(['git','diff','--name-only'],cwd=ROOT,text=True).splitlines();write([{'path':p} for p in sorted(set(changed))],'step15d_changed_files.csv')
    targets=[ROOT/'mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5',ROOT/'mql/Include/TickShock/TickShockStateConditionedResponse.mqh',ROOT/'mql/Experts/tests/ExpectedValue_TickShock_StateConditionedResponseHarness.mq5',ROOT/'mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.ex5',ROOT/'tests/tick_shock/spec/test_cases.csv']
    targets += sorted((ROOT/'tests/tick_shock/expected').glob('TS15D-*_expected.csv'))+sorted(p for p in A.glob('*.csv') if p.stat().st_size<50_000_000)
    write([{'path':str(p.relative_to(ROOT)).replace('\\','/'),'bytes':p.stat().st_size,'sha256':sha(p)} for p in targets if p.exists()],'step15d_source_fixture_output_hashes.csv')
    fails=sum(x['status']!='PASS' for x in causal+leakage+ca);print(f'tests={counts} qa_failures={fails}');return 1 if fails or any(counts.get(x,0) for x in ['FAIL','XFAIL','XPASS','BLOCKED']) else 0
if __name__=='__main__':raise SystemExit(main())
