"""Final evidence gates for the isolated HTF context study."""
from pathlib import Path
import json,hashlib,re
import pandas as pd
R=Path(__file__).resolve().parents[2]
O=R/'reports/qa/three_wave/context_research'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    baseline=json.loads((O/'baseline_manifest.json').read_text())
    result={'baseline_unchanged':{p:sha(R/p)==h for p,h in baseline.items()},'repeat':{},'audits':{},'compile':{}}
    for original,repeat in [('smoke','smoke_repeat'),('discovery','discovery_repeat')]:
        if not (O/repeat/'TW_context.csv').exists():continue
        for f in ['TW_features.csv','TW_feature_outcomes.csv','TW_context.csv','TW_context_bars.csv']:
            result['repeat'][original+'/'+f]=sha(O/original/f)==sha(O/repeat/f)
    for name in ['smoke','discovery','replication','extension','smoke_repeat','discovery_repeat']:
        p=O/name/'context_audit.json'
        result['audits'][name]=p.exists() and json.loads(p.read_text())['passed']
    for name in ['compile.log','compile_gap.log']:
        result['compile'][name]='Result: 0 errors, 0 warnings' in (O/name).read_text(encoding='utf-16')
    result['replay_unit']=json.loads((O/'replay_unit.json').read_text())['passed']
    gap=pd.read_csv(O/'TW_context_gap_result.csv')
    result['extension_gap_audit']=len(gap)==1 and gap.gaps.iloc[0]>0 and gap.missed_candidates.iloc[0]==0 and gap.errors.iloc[0]==0
    result['extension_gap_audit']=bool(result['extension_gap_audit'])
    boundary=json.loads((O/'boundary_audit.json').read_text())
    result['boundary_clear']=not boundary['shared_parents_at_contiguous_boundary'] and not boundary['previous_has_censored'] and boundary['separated_by_15min'] and boundary['position_clear']
    full=pd.read_csv(O/'candidates_with_context.csv');ledger=pd.read_csv(O/'execution_ledger.csv')
    gate_issues=[];checked=0
    for (period,stage,basis,stream),g in ledger.groupby(['period','stage','stop_basis','replay']):
        picks=g[g.accepted]
        d=full[(full.period==period)&(full.stage==stage)&(full.stop_basis==basis)]
        accepted=d.merge(picks[['id']],on='id',validate='one_to_one').sort_values('entry_msc')
        if accepted.parent.duplicated().any():gate_issues.append('duplicate parent '+str((period,stage,basis,stream)))
        for i in range(1,len(accepted)):
            before=accepted.iloc[i-1];now=accepted.iloc[i]
            if now.entry_msc<before.entry_msc+900000 or now.entry_msc<before.exit_msc or not before.closed:
                gate_issues.append('invalid chronological acceptance '+now.id)
        checked+=len(accepted)
    result['execution_invariants']={'checked_acceptances':checked,'issues':gate_issues,'passed':not gate_issues}
    # Context extension contains no trade calls. Shared structure is observational baseline.
    sources=[R/'mql/Experts/USDJPY_3Wave_ContextResearch.mq5',R/'mql/Include/ThreeWaveContextResearch.mqh']
    result['no_order_calls']=not any(re.search(r'\b(OrderSend|OrderSendAsync|CTrade)\s*\(',p.read_text(encoding='utf-8')) for p in sources)
    result['passed']=all(result['baseline_unchanged'].values()) and all(result['repeat'].values()) and len(result['repeat'])==8 and all(result['audits'].values()) and all(result['compile'].values()) and result['replay_unit'] and result['extension_gap_audit'] and result['boundary_clear'] and not gate_issues and result['no_order_calls']
    (O/'reproducibility.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    print(json.dumps(result,indent=2))
    files=[*sources,R/'mql/Experts/USDJPY_3Wave_ContextResearch.ex5',R/'mql/Scripts/tests/ThreeWaveContextGapAudit.mq5',R/'mql/Scripts/tests/ThreeWaveContextGapAudit.ex5']
    files+=list((R/'tools/swing_structure').glob('*context*.py'))+list((R/'tools/swing_structure').glob('*context*.ps1'))
    (O/'research_manifest.json').write_text(json.dumps({str(p.relative_to(R)).replace('\\','/'):sha(p) for p in files},indent=2))
    if not result['passed']:raise SystemExit(1)
if __name__=='__main__':main()
