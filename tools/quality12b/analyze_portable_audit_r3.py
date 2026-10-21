"""Contemporaneous controls; old strict audits remain intact."""
import argparse,json,re
from pathlib import Path
from analyze_portable_audit_r2 import check_r2
from analyze_portable_audit import aggregate,portfolio_compare
from analyze_cost_channel import ROOT,read,native,save
from portable_pair_audit import check_environment,compare_pair,deal_difference
from tick_quality import execution_blocks

def check_r3(run,spec,package):
    spec=dict(spec)
    if spec['kind']!='harness':
        h,meta,_=native(run/'report.htm')
        symbols=meta['inputs'].get('InpSymbols',spec['symbol']).split(',')
        env=check_environment(run,symbols);save(run/'environment_audit.json',env);assert env['passed'],env
        block='\n'.join(execution_blocks(meta,run/'journals')[0])
        assert not re.search(r'QE_FATAL|QE_SPEC_CHANGED',block), 'Environment observer reported a failure'
        q=read(run/'cost.csv',';');conv=read(run/'conversion.csv',';')
        assert len(conv)==len(q) and {r['deal'] for r in conv}=={r['deal'] for r in q},'Conversion observation coverage'
        if spec.get('paired_reference'):
            base=run.parent/spec['paired_reference']
            result=compare_pair(base,run);save(run/'pair_audit.json',result);assert result['passed'],result
            if spec['kind']=='daily':spec['reference']=str((base/'report.htm').relative_to(ROOT))
        # Old historical comparison is attribution, not a substitute for the fresh paired gate.
        if spec.get('historical_reference'):
            base=(ROOT/spec['historical_reference']).parent
            old=portfolio_compare(base,run)
            old['split']=deal_difference(read(base/'cost.csv',';'),q)
            old['role']='Historical drift diagnostic; contemporaneous pair is required separately'
            save(run/'historical_comparison.json',old)
    check_r2(run,spec,package)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--package',type=Path,required=True);p.add_argument('--run',type=Path);p.add_argument('--run-id');p.add_argument('--batch',type=Path);a=p.parse_args()
    m=json.loads((a.package/'manifest.json').read_text(encoding='utf-8'))
    if a.run:check_r3(a.run,next(r for r in m['runs'] if r['run_id']==a.run_id),a.package)
    else:
        aggregate(a.batch,a.package)
        summary=a.batch/'summary.md'
        with summary.open('a',encoding='utf-8') as f:
            f.write('\n## r3追加監査\n\n日足は今回再実行した旧版と照合。各旧/新対で売買・費用・銘柄条件・価格履歴fingerprint・MT5ビルドの一致を要求。\n')
            f.write('静的仕様は開始・終了および各利用可能分で観測。分内で発生・復帰した変更まで証明するものではない。履歴fingerprintは2021-01-01〜2023-03-31のOHLC/volume/spreadであり、全tick列の暗号学的一致証明ではない。\n')
            f.write('換算観測は記録したobserved_time時点のtick valueとOrderCalcProfitの100tick試算。後から回収したdealについて約定時点の換算情報とは解釈しない。\n')
