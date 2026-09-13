"""Reconcile fixed USDJPY inference and actual tester deals; no refitting."""
import json
import re
import html
import numpy as np
import pandas as pd
import usdjpy_only_ml as u

BATCH=u.ROOT/'reports/backtest/batches/usdjpy_only_ml_20260912'


def journal_block(rid):
    agent=u.ROOT.parents[4]/'Tester'/u.ROOT.parents[2].name
    for path in sorted(agent.glob('Agent-*/logs/*.log'),key=lambda p:p.stat().st_mtime,reverse=True)[:64]:
        raw=path.read_bytes();lines=raw.decode('utf-16' if raw[:2] in (b'\xff\xfe',b'\xfe\xff') else 'utf-8-sig',errors='replace').splitlines()
        found=[i for i,line in enumerate(lines) if line.rstrip().endswith('InpRunId='+rid)]
        if not found:continue
        i=found[-1];start=next(j for j in range(i-1,-1,-1) if 'started with inputs:' in lines[j])
        end=next((j for j in range(i+1,len(lines)) if 'started with inputs:' in lines[j]),len(lines))
        return lines[max(0,start-8):end]
    raise RuntimeError('Matching journal not found: '+rid)


def money_stats(t):
    if not len(t):return dict(trades=0)
    money=t.net_profit.to_numpy();r=t.net_r.to_numpy();equity=np.r_[0,np.cumsum(money)];er=np.r_[0,np.cumsum(r)]
    return dict(trades=len(t),net_profit=float(money.sum()),expectancy_r=float(r.mean()),
        pf_money=float(money[money>0].sum()/-money[money<0].sum()),
        pf_r=float(r[r>0].sum()/-r[r<0].sum()),win_rate=float((money>0).mean()),
        maxdd_money=float((np.maximum.accumulate(equity)-equity).max()),
        maxdd_r=float((np.maximum.accumulate(er)-er).max()),commission=float(t.commission.sum()),
        fee=float(t.fee.sum()),swap=float(t.swap.sum()),long=int(t.direction.eq(1).sum()),short=int(t.direction.eq(-1).sum()),
        tp=int(t.exit_reason.eq('TP').sum()),sl=int(t.exit_reason.eq('SL').sum()),
        time=int(t.exit_reason.eq('TIME').sum()),hold_over_900=int(t.hold_seconds.gt(900).sum()),max_hold=float(t.hold_seconds.max()))


def main():
    u.check_freeze();spec=json.loads((u.OUT/'frozen_model.json').read_text());rows=[];qa=[];alltr=[]
    def check(month,name,condition,detail=''):
        qa.append(dict(month=month,check=name,status='PASS' if condition else 'FAIL',detail=detail))
    for month in (202505,202506):
        folder=BATCH/str(month)
        if not (folder/'candidate_trades.csv').exists():continue
        sig=pd.read_csv(folder/'candidate_signals.csv');feat=pd.read_csv(folder/'technical_features.csv');feat=feat[feat.symbol.eq('USDJPY')]
        old=pd.read_csv(u.BATCH/str(month)/'technical_features.csv');old=old[old.symbol.eq('USDJPY')]
        check(month,'snapshot_count',len(sig)==len(feat)==len(old),f'{len(sig)}/{len(feat)}/{len(old)}')
        check(month,'only_usdjpy_signals',sig.symbol.eq('USDJPY').all())
        check(month,'unique_signal',not sig.duplicated(['symbol','t0_msc']).any())
        a=feat.merge(old,on=['symbol','t0_msc'],suffixes=('_mt5','_original'),validate='one_to_one')
        differences=[]
        for name in spec['features']:
            x=pd.to_numeric(a[name+'_mt5'],errors='coerce').to_numpy();y=pd.to_numeric(a[name+'_original'],errors='coerce').to_numpy()
            ok=np.isclose(x,y,atol=1e-10,rtol=0,equal_nan=True)
            if not ok.all(): differences.append(dict(feature=name,rows=int((~ok).sum()),max_difference=float(np.nanmax(np.abs(x-y)))))
        check(month,'features_match_original',not differences,str(differences[:5]))
        pd.DataFrame(differences,columns=['feature','rows','max_difference']).to_csv(folder/'feature_differences.csv',index=False)
        joined=sig.merge(feat,on=['symbol','t0_msc'],suffixes=('_signal','_feature'),validate='one_to_one')
        x=joined[spec['features']].to_numpy(float)
        ls=u.export_predict(spec['models']['1'],x);ss=u.export_predict(spec['models']['-1'],x)
        d=np.where(ls>ss,1,np.where(ss>ls,-1,0));d[np.maximum(ls,ss)<spec['threshold']]=0
        dl=ls-joined.long_score.to_numpy();ds=ss-joined.short_score.to_numpy()
        check(month,'long_inference',np.abs(dl).max()<1e-10,str(np.abs(dl).max()))
        check(month,'short_inference',np.abs(ds).max()<1e-10,str(np.abs(ds).max()))
        check(month,'direction_parity',np.array_equal(d,joined.direction.to_numpy()))
        pd.DataFrame(dict(t0_msc=joined.t0_msc,expected_direction=d,actual_direction=joined.direction,long_error=dl,short_error=ds)).to_csv(folder/'inference_parity.csv',index=False)
        tr=pd.read_csv(folder/'candidate_trades.csv');tr['month']=month;alltr.append(tr)
        check(month,'only_usdjpy_orders',tr.symbol.eq('USDJPY').all())
        check(month,'entry_after_processing',tr.entry_msc.ge(tr.processing_msc).all())
        check(month,'entry_after_request',tr.entry_msc.ge(tr.request_msc).all())
        check(month,'quote_after_processing',tr.quote_msc.ge(tr.processing_msc).all())
        check(month,'no_future_quote',tr.quote_msc.le(tr.request_msc).all())
        check(month,'entry_quote_not_stale',(tr.request_msc-tr.quote_msc).le(500).all())
        sq=tr.merge(sig[['episode_id','source_quote_msc']],on='episode_id',validate='one_to_one')
        check(month,'quote_strictly_after_source',sq.quote_msc.gt(sq.source_quote_msc).all())
        check(month,'exit_after_entry',tr.exit_msc.ge(tr.entry_msc).all())
        check(month,'volume_closed',np.allclose(tr.filled_volume,tr.closed_volume,atol=1e-8,rtol=0))
        check(month,'unique_position',not tr.position_identifier.duplicated().any())
        check(month,'pnl_components',np.allclose(tr.gross_profit+tr.commission+tr.fee+tr.swap,tr.net_profit,atol=1e-8,rtol=0))
        check(month,'r_accounting',np.allclose(tr.net_profit/tr.risk_amount,tr.net_r,atol=1e-10,rtol=0))
        check(month,'risk_positive',tr.risk_amount.gt(0).all())
        risk=(tr.entry_price-tr.sl).abs()
        check(month,'actual_rr_at_least_one',((tr.tp-tr.entry_price).abs()+1e-10>=risk).all())
        chron=tr.sort_values('entry_msc')
        check(month,'positions_do_not_overlap',(chron.entry_msc.to_numpy()[1:]>=chron.exit_msc.to_numpy()[:-1]).all())
        specs=pd.read_csv(folder/'symbol_specs.csv');sp=specs[specs.symbol.eq('USDJPY')].iloc[0]
        check(month,'volume_step',np.allclose(tr.requested_volume/sp.volume_step,np.round(tr.requested_volume/sp.volume_step),atol=1e-8,rtol=0))
        check(month,'minimum_volume',tr.requested_volume.ge(sp.volume_min).all())
        for col in ('sl','tp'):
            check(month,col+'_tick_size',np.allclose(tr[col]/sp.tick_size,np.round(tr[col]/sp.tick_size),atol=1e-7,rtol=0))
        offline=pd.read_csv(u.OUT/f'holdout_{month}_trades.csv')
        matched=tr.merge(offline,left_on=['symbol','signal_msc','direction'],right_on=['symbol','t0_msc','direction'],suffixes=('_mt5','_python'),how='outer',indicator=True)
        u.s.dump(matched,folder/'trade_comparison.csv')
        r=money_stats(tr);r.update(month=month,matched=int(matched._merge.eq('both').sum()),
            mt5_only=int(matched._merge.eq('left_only').sum()),python_only=int(matched._merge.eq('right_only').sum()))
        rows.append(r)
        # Every residual queue/order issue is preserved, not erased by parity.
        actions=pd.read_csv(folder/'candidate_actions.csv')
        actions.groupby('status').size().rename('rows').to_csv(folder/'action_status_counts.csv')
        bad=matched[~matched._merge.eq('both')].copy();causes=[]
        for z in bad.to_dict('records'):
            t0=z['signal_msc'] if pd.notna(z['signal_msc']) else z['t0_msc']
            aa=actions[actions.t0_msc.eq(t0)]
            causes.append(dict(t0_msc=t0,presence=z['_merge'],actions=';'.join(aa.status.astype(str))))
        pd.DataFrame(causes,columns=['t0_msc','presence','actions']).to_csv(folder/'trade_difference_causes.csv',index=False)
        block=journal_block(f'usdjpy_only_ml_{month}_20260912')
        end=[line for line in block if 'technical_candidate signals=' in line]
        check(month,'one_end_summary',len(end)==1)
        if len(end)==1:
            counters=dict(re.findall(r'(signals|closed|errors|remaining_positions)=(\d+)',end[0]))
            check(month,'remaining_positions_zero',int(counters['remaining_positions'])==0)
            check(month,'candidate_errors_zero',int(counters['errors'])==0)
            check(month,'journal_closed_count',int(counters['closed'])==len(tr))
        safe=[line for line in block if any(k in line for k in ('technical_candidate signals=','technical_discovery episodes=',
            'Test passed in ','memory used','generating based on real ticks','real ticks discarded','final balance'))]
        (folder/'execution_journal_excerpt.txt').write_text('\n'.join(safe)+'\n',encoding='utf-8')
        raw=(folder/'tester_report.html').read_bytes();ht=raw.decode('utf-16' if raw[:2] in (b'\xff\xfe',b'\xfe\xff') else 'utf-8-sig',errors='replace')
        fields=[]
        for line in re.findall(r'<tr\b[^>]*>(.*?)</tr>',ht,re.S|re.I):
            cells=[html.unescape(re.sub('<[^>]+>','',v)).strip() for v in re.findall(r'<td\b[^>]*>(.*?)</td>',line,re.S|re.I)]
            for i,c in enumerate(cells[:-1]):
                if any(k in c for k in ('Total Net Profit','Total Trades','Profit Factor','Drawdown','総損益','総取引数','プロフィットファクター','ドローダウン')):
                    fields.append(dict(field=c,value=cells[i+1]))
        pd.DataFrame(fields).to_csv(folder/'tester_financial_fields.csv',index=False)
        netfield=next((z['value'] for z in fields if 'Total Net Profit' in z['field'] or '総損益' in z['field']),None)
        check(month,'tester_net_observed',netfield is not None)
        if netfield is not None:
            net=float(re.sub(r'[^0-9.\-]','',netfield));check(month,'tester_net_reconciles',abs(net-tr.net_profit.sum())<.011)
        costs=[]
        for c in (0,.1,.2,.4,.5,1):
            t=tr.copy();money=c*.01/risk*t.risk_amount
            t.net_profit-=money;t.net_r=t.net_profit/t.risk_amount
            costs.append(dict(extra_pips=c,scope='STRESS_ON_ACTUAL_OBSERVED_COSTS',**money_stats(t)))
        u.s.dump(costs,folder/'actual_cost_sensitivity.csv')
        overruns=tr[tr.hold_seconds.gt(900)].copy();u.s.dump(overruns,folder/'hold_overruns.csv')
        u.s.write_json(r,folder/'reconciliation.json')
    u.s.dump(qa,BATCH/'qa_checks.csv');u.s.dump(rows,BATCH/'actual_monthly.csv')
    if len(rows)==2:
        combined=pd.concat(alltr).sort_values(['month','entry_msc'])
        u.s.dump(combined,BATCH/'all_trades.csv')
        u.s.write_json(dict(completed=u.stamp(),actual=money_stats(combined),qa_failures=sum(x['status']=='FAIL' for x in qa),
            model_unchanged=True,production_eligible=False,hold_limit_is_first_observable_quote_not_strict_900=True),BATCH/'summary.json')
    print(json.dumps(u.s.core.clean_json(rows),indent=2))
    assert all(q['status']=='PASS' for q in qa)


if __name__=='__main__':main()
