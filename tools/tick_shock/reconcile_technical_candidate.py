"""Compare real tester fills with the frozen Python candidate, never refit."""
import argparse,json,re,html
from pathlib import Path
import numpy as np
import pandas as pd


def stats(t, cost=0.0):
    net=t.net_profit.to_numpy(float)-cost*t.pip_money.to_numpy(float)
    r=net/t.risk_amount.to_numpy(float)
    equity=np.r_[0.0,np.cumsum(r)];money=np.r_[0.0,np.cumsum(net)]
    positive=net[net>0].sum();negative=-net[net<0].sum()
    rpos=r[r>0].sum();rneg=-r[r<0].sum()
    return dict(trades=len(t),wins=int((net>0).sum()),win_rate=float((net>0).mean()),
        net_profit=float(net.sum()),total_r=float(r.sum()),expectancy_r=float(r.mean()),
        pf_money=float(positive/negative) if negative else None,pf_r=float(rpos/rneg) if rneg else None,
        maxdd_closed_r=float((np.maximum.accumulate(equity)-equity).max()),
        maxdd_closed_money=float((np.maximum.accumulate(money)-money).max()),
        long=int((t.direction==1).sum()),short=int((t.direction==-1).sum()),
        tp=int((t.exit_reason=='TP').sum()),sl=int((t.exit_reason=='SL').sum()),timeout=int((t.exit_reason=='TIME').sum()),
        hold_mean_seconds=float(t.hold_seconds.mean()),hold_max_seconds=float(t.hold_seconds.max()),
        commission=float(t.commission.sum()),fee=float(t.fee.sum()),swap=float(t.swap.sum()),
        extra_cost_pips=cost)


def main():
    p=argparse.ArgumentParser();p.add_argument('--run',type=Path,required=True);p.add_argument('--analysis',type=Path,required=True);p.add_argument('--research',type=Path,required=True);a=p.parse_args()
    t=pd.read_csv(a.run/'candidate_trades.csv');s=pd.read_csv(a.run/'candidate_signals.csv');actions=pd.read_csv(a.run/'candidate_actions.csv')
    f=pd.read_csv(a.research/'features.csv');actual_f=pd.read_csv(a.run/'features.csv')
    model=json.loads((a.analysis/'candidate_model.json').read_text());reference=pd.read_csv(a.analysis/'candidate_all_signals.csv')
    checks=[]
    def check(name,value,expected=0):
        checks.append(dict(check=name,actual=value,expected=expected,status='PASS' if value==expected else 'FAIL'))
    check('signal_key_duplicates',int(s.duplicated(['symbol','t0_msc']).sum()))
    check('trade_episode_duplicates',int(t.episode_id.duplicated().sum()))
    check('signal_population',set(map(tuple,s[['symbol','t0_msc']].values))==set(map(tuple,f[['symbol','t0_msc']].values)),True)
    combined=f.merge(actual_f,on=['symbol','t0_msc'],suffixes=('_reference','_actual'),validate='one_to_one')
    feature_mismatches=0
    for name in model['features']:
        l=combined[name+'_reference'].to_numpy(float);r=combined[name+'_actual'].to_numpy(float)
        feature_mismatches+=int((~np.isclose(l,r,rtol=0,atol=1e-11,equal_nan=True)).sum())
    check('formal_feature_value_mismatches',feature_mismatches)
    original_outcomes=pd.read_csv(a.research/'outcomes.csv')
    current_outcomes=pd.read_csv(a.run/'outcomes.csv')
    outcome_keys=['symbol','t0_msc','direction','distance_index']
    left=original_outcomes.drop(columns='episode_id').sort_values(outcome_keys).reset_index(drop=True)
    right=current_outcomes.drop(columns='episode_id').sort_values(outcome_keys).reset_index(drop=True)
    check('research_shadow_outcomes_preserved',left.equals(right),True)
    joined=s.merge(reference[['symbol','t0_msc','long_score','short_score','direction']],on=['symbol','t0_msc'],suffixes=('_actual','_reference'),validate='one_to_one')
    expected=np.where(np.maximum(joined.long_score_reference,joined.short_score_reference)>=model['threshold'],joined.direction_reference,0)
    check('model_direction_mismatches',int((joined.direction_actual!=expected).sum()))
    check('model_score_mismatches',int(((joined.long_score_actual-joined.long_score_reference).abs()>1e-10).sum()+((joined.short_score_actual-joined.short_score_reference).abs()>1e-10).sum()))
    check('entry_before_processing',int((t.entry_msc<t.processing_msc).sum()))
    check('entry_before_request',int((t.entry_msc<t.request_msc).sum()))
    check('request_quote_before_processing',int((t.quote_msc<t.processing_msc).sum()))
    check('request_future_quote',int((t.quote_msc>t.request_msc).sum()))
    check('exit_before_entry',int((t.exit_msc<t.entry_msc).sum()))
    check('unbalanced_entry_exit_volume',int(((t.filled_volume-t.closed_volume).abs()>1e-8).sum()))
    check('net_money_reconciliation',int(((t.net_profit-t.gross_profit-t.commission-t.fee-t.swap).abs()>1e-7).sum()))
    check('net_r_reconciliation',int(((t.net_profit/t.risk_amount-t.net_r).abs()>1e-7).sum()))
    risk=(t.entry_price-t.sl).abs();reward=(t.tp-t.entry_price).abs()
    check('rr_below_one',int((reward+1e-10<risk).sum()))
    chronological=t.sort_values('entry_msc')
    check('global_position_overlap',int((chronological.entry_msc.to_numpy()[1:]<chronological.exit_msc.to_numpy()[:-1]).sum()))
    spec=pd.read_csv(a.research/'outcomes.csv').groupby('symbol').pip_size.first()
    t['pip_size']=t.symbol.map(spec)
    # Stress uses entry risk conversion; actual broker commission stays separate.
    t['pip_money']=t.risk_amount*t.pip_size/risk
    t['price_r']=t.direction*(t.exit_price-t.entry_price)/risk
    py=pd.read_csv(a.analysis/'candidate_portfolio_trades.csv')
    t['t0_msc']=t.signal_msc
    match=t.merge(py,on=['symbol','t0_msc','direction'],suffixes=('_mt5','_python'),how='outer',indicator=True,validate='one_to_one')
    keep=['symbol','t0_msc','direction','_merge','entry_msc_mt5','entry_msc_python','entry_price_mt5','entry_price_python','exit_msc_mt5','exit_msc_python','exit_price_mt5','exit_price_python','exit_reason','status','net_r_mt5','net_r_python']
    match[keep].to_csv(a.run/'python_trade_comparison.csv',index=False)
    differences=[]
    for row in match[match['_merge']!='both'].itertuples(index=False):
        # Explicit dataframe lookup avoids pandas renaming the _merge tuple field.
        present=t[(t.symbol==row.symbol)&(t.t0_msc==row.t0_msc)&(t.direction==row.direction)]
        trace=actions[(actions.symbol==row.symbol)&(actions.t0_msc==row.t0_msc)]
        pr=reference[(reference.symbol==row.symbol)&(reference.t0_msc==row.t0_msc)&(reference.direction==row.direction)]
        processing=int(pr.signal_processing_msc.iloc[0])
        blocking=py[(py.signal_processing_msc<processing)&(py.exit_msc>=processing)]
        actual_blocking=t[(t.processing_msc<=processing)&(t.exit_msc>=processing)]
        pending_blocking=actions[(actions.processing_msc<=processing)&(actions.action_msc>=processing)
            &actions.status.isin(['ENTRY','COST_DISTANCE_REJECT','NO_ENTRY_TIMEOUT','BROKER_DISTANCE_REJECT'])]
        differences.append(dict(symbol=row.symbol,t0_msc=row.t0_msc,direction=row.direction,
            scope='MT5_ONLY' if len(present) else 'PYTHON_ONLY',
            mt5_actions=';'.join(trace.status.astype(str)),
            python_blocking_episode=';'.join(blocking.episode_id.astype(str)),
            python_blocking_exit_msc=';'.join(blocking.exit_msc.astype(str)),
            python_outcome_status=str(pr.status.iloc[0]),
            mt5_blocking_episode=';'.join(actual_blocking.episode_id.astype(str)),
            mt5_pending_blocker=';'.join(pending_blocking.episode_id.astype(str)),
            reason='Current-quote fills/server exit timing change cost/overlap eligibility; model is unchanged'))
    pd.DataFrame(differences).to_csv(a.run/'trade_difference_causes.csv',index=False)
    pd.DataFrame([stats(t,c) for c in (0,.1,.2,.5,1)]).to_csv(a.run/'candidate_cost_sensitivity.csv',index=False)
    pd.DataFrame([dict(symbol=name,**stats(g)) for name,g in t.groupby('symbol')]).to_csv(a.run/'candidate_symbol_results.csv',index=False)
    segments=np.minimum(3,((t.signal_msc-1743465600000)*4/(30*86400000)).astype(int))
    pd.DataFrame([dict(segment=int(n),**stats(g)) for n,g in t.groupby(segments)]).to_csv(a.run/'candidate_segment_results.csv',index=False)
    actions.groupby('status').size().rename('count').to_csv(a.run/'candidate_action_counts.csv')
    data=(a.run/'tester_report.html').read_bytes();text=data.decode('utf-16' if data[:2] in (b'\xff\xfe',b'\xfe\xff') else 'utf-8-sig')
    report_pairs=[]
    for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>',text,re.S|re.I):
        cells=[html.unescape(re.sub('<[^>]+>','',x)).strip() for x in re.findall(r'<td\b[^>]*>(.*?)</td>',row,re.S|re.I)]
        for i,v in enumerate(cells[:-1]):
            if v.endswith(':') or v.endswith('：'):
                report_pairs.append(dict(field=v,value=cells[i+1]))
    pd.DataFrame(report_pairs).to_csv(a.run/'tester_report_fields.csv',index=False)
    fields={x['field']:x['value'] for x in report_pairs}
    total_key=next((x for x in ('総損益:','Total Net Profit:') if x in fields),None)
    count_key=next((x for x in ('取引数:','Total Trades:') if x in fields),None)
    check('tester_report_profit_observed',total_key is not None,True)
    check('tester_report_trade_count_observed',count_key is not None,True)
    if total_key:
        total=float(fields[total_key].replace(' ','').replace(',',''))
        check('tester_report_profit_reconciliation',abs(total-float(t.net_profit.sum()))<.011,True)
    if count_key:
        check('tester_report_trade_count',int(fields[count_key].replace(' ','')),len(t))
    journal=(a.run/'tester_journal_excerpt.txt').read_text(encoding='utf-8-sig')
    observed=re.search(r'technical_candidate signals=(\d+) closed=(\d+) errors=(\d+) remaining_positions=(\d+)',journal)
    check('candidate_end_journal_observed',observed is not None,True)
    if observed:
        check('journal_signal_reconciliation',int(observed[1]),len(s))
        check('journal_trade_reconciliation',int(observed[2]),len(t))
        check('candidate_runtime_errors',int(observed[3]))
        check('remaining_positions',int(observed[4]))
    pd.DataFrame(checks).to_csv(a.run/'candidate_qa.csv',index=False)
    summary=dict(scope='APRIL_DEVELOPMENT_FITTED_MODEL_RETEST_NOT_OOS',actual=stats(t),stress_02=stats(t,.2),
        python_trades=len(py),matched_trade_keys=int((match['_merge']=='both').sum()),
        mt5_only=int((match['_merge']=='left_only').sum()),python_only=int((match['_merge']=='right_only').sum()),
        checks=len(checks),qa_failures=sum(x['status']=='FAIL' for x in checks),signal_rows=len(s),
        caveat='Model signals may match exactly while current-quote orders and server barriers differ from research replay')
    (a.run/'candidate_reconciliation.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8');print(json.dumps(summary,indent=2))
    if summary['qa_failures']:raise SystemExit(1)


if __name__=='__main__':main()
