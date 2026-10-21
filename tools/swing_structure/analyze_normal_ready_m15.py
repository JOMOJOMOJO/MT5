"""Production READY executions; never pool with the earlier CHoCH shadows."""
from pathlib import Path
import hashlib,json,re
import numpy as np
import pandas as pd
from analyze_m15_regime_position import replay,annotate
from verify_m15_display import compare

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports/qa/three_wave/m15_normal_ready'
CATS=[a+'_'+b for a in ['UP','DOWN','RANGE'] for b in ['LOW','MID','HIGH']]+['UNKNOWN_UNKNOWN']
RUNS={'known_2025h1':pd.period_range('2025-01','2025-06',freq='M'),
      'known_2024q3':pd.period_range('2024-07','2024-09',freq='M')}

def markdown(df):
    def value(x):
        if pd.isna(x):return 'NA'
        return f'{x:.4f}' if isinstance(x,float) else str(x)
    return '\n'.join(['| '+' | '.join(map(str,df.columns))+' |',
                      '| '+' | '.join(['---']*len(df.columns))+' |']+
                     ['| '+' | '.join(value(x) for x in row)+' |' for row in df.itertuples(index=False,name=None)])

def stats(g):
    r=g.net_r.dropna(); losses=-r[r<0].sum()
    q=g[g.path_complete.eq(True)]
    ans=dict(executions=len(g),closed=len(r),win_rate=(r>0).mean(),expectancy_r=r.mean(),
             pf=r[r>0].sum()/losses if losses else np.nan,
             mean_price_r=g.price_r.mean(),path_complete_count=len(q),
             mfe=q.mfe_until_sl_or_24h.mean(),mae=q.mae_until_sl_or_24h.mean())
    for rr in [1.,1.2,1.5,2.]:ans[f'reach_{rr}r']=(q.mfe_until_sl_or_24h>=rr-1e-9).mean()
    return ans

def main():
    candidates=[];trades=[];monthly=[];audit={}
    for run,months in RUNS.items():
        base=OUT/run
        sig=pd.read_csv(base/'TW_signals.csv')
        assert sig.stop_mode.eq('STOP_M1_REVERSAL_LOW').all()
        assert np.allclose(sig.rr,1.2)
        for col in ['m1_wave1_confirmed','m1_wave2_confirmed','m1_reversal_confirmed']:
            assert (pd.to_datetime(sig[col])<=pd.to_datetime(sig.decision_tick)).all()
        assert (sig.m1_wave1_high>0).all() and (sig.m1_wave2_low>0).all()
        env=pd.read_csv(base/'TW_M15_environment_USDJPY_260922331.csv',dtype={'id':str})
        oldrun='known_close_2025h1' if run=='known_2025h1' else 'holdout_close_2024q3'
        bars=pd.read_csv(ROOT/'reports/qa/three_wave/m15_phase_research'/oldrun/'MP_phases.csv')
        states,_=replay(bars)
        query=env.rename(columns={'time_msc':'entry_msc','ask':'entry'}).copy();query['risk']=1.0
        expected=annotate(query[['id','entry_msc','entry','risk']],states)
        compare(env.sort_values('time_msc',kind='stable').reset_index(drop=True),expected.reset_index(drop=True))
        deals=pd.read_csv(base/'TW_deals.csv')
        paths=pd.read_csv(base/'TW_ready_paths.csv')
        journal=(base/'tester.log').read_text(encoding='utf-8-sig')
        warning_days=sorted(set(re.findall(r'(\d{4}\.\d{2}\.\d{2}) 23:59 - .*real ticks (?:absent|discarded)',journal)))
        quality_lines=[line for line in journal.splitlines() if 'real ticks absent' in line or 'real ticks discarded' in line]
        (base/'tick_quality.json').write_text(json.dumps(dict(warning_days=warning_days,journal_warnings=quality_lines),indent=2))
        ready=env[env.event.eq('READY')].copy()
        c=sig.merge(ready,left_on='signal_id',right_on='id',validate='one_to_one')
        assert len(c)==len(sig)
        assert not c.state_transition_reason.eq('SKIP_HL_CHOCH_ONLY').any()
        c['category']=c.regime+'_'+c.position
        c['month']=pd.to_datetime(c.time_msc,unit='ms').dt.to_period('M').astype(str)
        c['run']=run;candidates.append(c)
        entries=deals[deals.entry.eq(0)&deals.type.eq(0)].copy()
        final_balance=float(re.findall(r'final balance ([0-9.]+) USD',journal)[-1])
        forced=re.findall(r'(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})\s+position closed due end of test at ([0-9.]+) \[#(\d+) buy',journal)
        terminal_residual=final_balance-10000-deals[['profit','commission','swap','fee']].sum().sum()
        rows=[]
        for _,d in entries.iterrows():
            s=sig[sig.order.eq(d.order)&sig.sent.eq(True)]
            assert len(s)==1
            s=s.iloc[0]
            e=env[env.event.eq('ENTRY')&env.id.eq(str(int(d.deal)))]
            assert len(e)==1
            e=e.iloc[0]
            p=paths[paths.deal.eq(d.deal)]
            assert len(p)==1
            p=p.iloc[0]
            assert abs(p.sl-s.sl)<1e-8
            assert abs(s.sl-(s.m1_reversal_low-0.01))<0.00101
            assert abs(s.tp-(s.entry_price+(s.entry_price-s.sl)*1.2))<=0.00101
            assert e['valid'] and e['asof']<=d.time_msc/1000
            assert e.break_confirmed<=d.time_msc/1000
            assert p.risk>0
            exits=deals[deals.position.eq(d.position)&deals.entry.isin([1,3])]
            closed=abs(exits.volume.sum()-d.volume)<1e-8
            cash=deals[deals.position.eq(d.position)][['profit','commission','swap','fee']].sum().sum()
            px=(exits.price*exits.volume).sum()/exits.volume.sum() if len(exits) else np.nan
            exit_msc=exits.time_msc.max() if len(exits) else np.nan
            result_source='DEAL_LEDGER';end_forced=False
            if not closed:
                # MT5 closes remaining positions after EA OnDeinit has exported history.
                # Reconcile only the unique, explicitly logged test-end close.
                assert len(forced)==1 and int(forced[0][2])==int(d.position)
                cash+=terminal_residual;px=float(forced[0][1]);closed=True;end_forced=True
                exit_msc=int(pd.Timestamp(forced[0][0]).timestamp()*1000)
                result_source='TEST_END_JOURNAL_AND_BALANCE_RESIDUAL'
            row=e.to_dict();row.update(p.to_dict())
            row.update(run=run,signal_id=s.signal_id,position_id=int(d.position),month=str(pd.to_datetime(d.time_msc,unit='ms').to_period('M')),
                       category=e.regime+'_'+e.position,net_profit=cash,expected_loss=s.expected_loss,
                       net_r=cash/s.expected_loss if closed else np.nan,
                       price_r=(px-d.price)/p.risk if closed else np.nan,closed=closed,
                       exit_msc=exit_msc,test_end_forced=end_forced,result_source=result_source)
            entry_day=pd.to_datetime(d.time_msc,unit='ms').strftime('%Y.%m.%d')
            last_day=pd.to_datetime(p.last_msc,unit='ms').strftime('%Y.%m.%d')
            row['entry_on_tick_warning_day']=entry_day in warning_days
            row['path_overlaps_tick_warning_day']=any(entry_day<=day<=last_day for day in warning_days)
            rows.append(row)
        t=pd.DataFrame(rows);trades.append(t)
        assert abs(t.net_profit.sum()-(final_balance-10000))<1e-6
        for month in months.astype(str):
            for cat in CATS:
                cg=c[c.month.eq(month)&c.category.eq(cat)];tg=t[t.month.eq(month)&t.category.eq(cat)]
                monthly.append(dict(run=run,month=month,category=cat,ready_candidates=len(cg),executions=len(tg)))
        audit[run]=dict(ready_candidates=len(c),executions=len(t),all_paths_matched=True,
                        m15_research_parity='PASS',
                        final_balance=final_balance,ledger_balance_reconciled=True,test_end_forced=int(t.test_end_forced.sum()),
                        tick_warning_days=warning_days,
                        categories_valid=bool(t.category.isin(CATS).all()),
                        signal_reasons=c.reason.value_counts().to_dict())
    c=pd.concat(candidates,ignore_index=True);t=pd.concat(trades,ignore_index=True)
    c.to_csv(OUT/'ready_candidates_with_context.csv',index=False)
    t.to_csv(OUT/'executions_with_context.csv',index=False)
    c[['run','signal_id','signal_time','category','reason','sent']].merge(
        t[['run','signal_id','deal','net_r','price_r','test_end_forced']],on=['run','signal_id'],how='left',validate='one_to_one'
    ).to_csv(OUT/'execution_ledger.csv',index=False)
    pd.DataFrame(monthly).to_csv(OUT/'monthly_counts.csv',index=False)
    rows=[]
    for run in [*RUNS,'ALL_PERIODS']:
        x=t if run=='ALL_PERIODS' else t[t.run.eq(run)]
        y=c if run=='ALL_PERIODS' else c[c.run.eq(run)]
        for cat in CATS:
            rows.append(dict(run=run,category=cat,ready_candidates=int(y.category.eq(cat).sum()),**stats(x[x.category.eq(cat)])))
        rows.append(dict(run=run,category='ALL',ready_candidates=len(y),**stats(x)))
    st=pd.DataFrame(rows);st.to_csv(OUT/'category_statistics.csv',index=False)
    natural=t[~t.test_end_forced]
    pd.DataFrame([dict(category=cat,**stats(natural[natural.category.eq(cat)])) for cat in CATS]).to_csv(OUT/'natural_exit_sensitivity.csv',index=False)
    old=pd.read_csv(ROOT/'reports/qa/three_wave/m15_regime_position_research/category_statistics.csv')
    old=old[old.run.eq('ALL_PERIODS')&old.scope.eq('ALL_CANDIDATES')&old.rr.eq(1.2)&old.category.isin(CATS)]
    comparison=old[['category','count','expectancy_r']].rename(columns={'count':'choch_candidates','expectancy_r':'choch_price_expectancy_r'}).merge(st[st.run.eq('ALL_PERIODS')&st.category.isin(CATS)],on='category',how='outer')
    comparison['same_sign_price_r']=np.where(comparison.choch_price_expectancy_r.notna()&comparison.mean_price_r.notna(),np.sign(comparison.choch_price_expectancy_r)==np.sign(comparison.mean_price_r),None)
    comparison['choch_share']=comparison.choch_candidates/comparison.choch_candidates.sum()
    comparison['ready_candidate_share']=comparison.ready_candidates/comparison.ready_candidates.sum()
    comparison['ready_execution_share']=comparison.executions/comparison.executions.sum()
    comparison.to_csv(OUT/'choch_vs_normal_ready.csv',index=False)
    tables=['# Normal READY: all fixed categories','',
            'Expectancy/PF: net realized R. MFE/MAE/reach: initial SL or 24h, including post-TP path; incomplete paths excluded.','']
    for run in [*RUNS,'ALL_PERIODS']:
        tables.extend(['## '+run,'',markdown(st[st.run.eq(run)].drop(columns='run')),''])
    tables.extend(['## Monthly counts (includes zero categories)','',markdown(pd.DataFrame(monthly)),''])
    (OUT/'tables.md').write_text('\n'.join(tables),encoding='utf-8')
    hashes=json.loads((OUT/'source_hashes_before.json').read_text())
    audit['production_source_unchanged']=all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in hashes.items())
    assert audit['production_source_unchanged']
    (OUT/'audit.json').write_text(json.dumps(audit,indent=2))
    print(st[st.run.eq('ALL_PERIODS')].to_string(index=False))
    print(pd.DataFrame(monthly).groupby('month')[['ready_candidates','executions']].sum().to_string())

if __name__=='__main__':main()
