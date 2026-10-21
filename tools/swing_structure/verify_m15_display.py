"""Golden Python research vs shared MQL core and production telemetry."""
from pathlib import Path
import json,re
import numpy as np
import pandas as pd
from analyze_m15_regime_position import replay,annotate
ROOT=Path(__file__).resolve().parents[2]
B=ROOT/'reports/qa/three_wave/m15_display_integration'
R=ROOT/'reports/qa/three_wave/m15_phase_research'
RUNS=['known_close_2025h1','holdout_close_2024q3']

def compare(native,expected):
    for col in ['regime','position','range_location']:
        assert native[col].to_list()==expected[col].to_list(),col
    assert native.last_break_direction.to_list()==expected.last_break_direction.str.upper().to_list()
    for col in ['raw_position','structure_high','structure_low','break_time','break_level','break_bar','break_confirmed','asof']:
        reference={'raw_position':'raw_position','break_time':'last_break_asof','break_level':'last_break_level',
                   'break_bar':'last_break_level_bar','break_confirmed':'last_break_level_confirmed'}.get(col,col)
        expected_col=expected[reference] if col=='raw_position' else expected[reference].fillna(0)
        observed=native[col].mask(native[col]>1e300) if col=='raw_position' else native[col]
        assert np.allclose(observed,expected_col,rtol=0,atol=2e-11,equal_nan=True),col

def main():
    checks={};native=pd.read_csv(B/'native_parity/M15EnvParity.csv')
    states=pd.read_csv(B/'native_parity/M15EnvStates.csv')
    golden=pd.read_csv(ROOT/'reports/qa/three_wave/m15_regime_position_research/candidates_with_environment.csv')
    for index,run in enumerate(RUNS):
        got=native[native.run==index].sort_values('id').reset_index(drop=True)
        expected=golden[golden.run==run].sort_values('id').reset_index(drop=True)
        expected=expected.rename(columns={'raw_position':'raw_position'})
        assert got.id.to_list()==expected.id.to_list();compare(got,expected)
        b=pd.read_csv(R/run/'MP_phases.csv');frame,_=replay(b)
        g=states[states.run==index].reset_index(drop=True)
        assert len(g)==len(frame) and g.regime.eq(frame.regime).all()
        assert np.array_equal(g['asof'],frame['asof'])
        # Warmup UNKNOWN has no price range; all identified states must match.
        q=frame.regime.ne('UNKNOWN')
        synthetic=pd.DataFrame(dict(id=b.index.astype(str),entry_msc=b['asof']*1000,entry=b.close,risk=1.0))
        a=annotate(synthetic,frame)
        a['raw_position']=a.raw_position
        compare(g[q].reset_index(drop=True),a[q].reset_index(drop=True))
        checks[run]=dict(candidates=len(got),closed_bars=len(g),shared_core_parity='PASS',raw_tolerance=2e-11)
    for mode,after in [('ready','after_ready_final'),('retest','after_retest')]:
        before=B/('before_'+mode);end=B/after
        if not (end/'TW_deals.csv').exists():continue
        result={}
        for filename in ['TW_signals.csv','TW_deals.csv','TW_exits.csv']:
            x=pd.read_csv(before/filename);y=pd.read_csv(end/filename);pd.testing.assert_frame_equal(x,y)
            result[filename]=dict(rows=len(x),exact=True)
        def balance(p):
            return re.findall(r'final balance ([^\r\n]+)',(p/'tester.log').read_text(encoding='utf-8-sig'))
        assert balance(before)==balance(end);result['final_balance']=balance(end)
        d=pd.read_csv(next(end.glob('TW_M15_environment_*.csv')))
        assert not d.duplicated(['event','id']).any()
        assert d.valid.all() and d.quote_source.ne('FILL_FALLBACK_NO_QUOTE').all()
        trades=pd.read_csv(end/'TW_deals.csv');entries=trades[(trades.entry==0)&(trades.type==0)]
        assert set(d.loc[d.event=='ENTRY','id'].astype(str))==set(entries.deal.astype(str))
        b=pd.read_csv(R/'known_close_2025h1/MP_phases.csv');f,_=replay(b)
        q=d.rename(columns={'time_msc':'entry_msc','ask':'entry'}).copy();q['risk']=1.0
        a=annotate(q[['id','entry_msc','entry','risk']],f)
        # merge_asof stable ordering: both inputs sorted by time with READY before ENTRY.
        g=d.sort_values('time_msc',kind='stable').reset_index(drop=True)
        a=a.reset_index(drop=True)
        assert g.id.astype(str).to_list()==a.id.astype(str).to_list()
        compare(g,a)
        result['diagnostic_rows']=len(d);result['production_python_parity']='PASS';checks[mode]=result
    (B/'verification.json').write_text(json.dumps(checks,indent=2));print(json.dumps(checks,indent=2))

if __name__=='__main__':main()
