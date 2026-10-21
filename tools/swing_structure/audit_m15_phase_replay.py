"""Independent Python replay of the frozen close-break M15 definition."""
from pathlib import Path
import sys,json
import pandas as pd

BASE=Path(__file__).resolve().parents[2]/'reports/qa/three_wave/m15_phase_research'
def replay(bars):
    state='RANGE_UNKNOWN';hs=[];ls=[];p0=p1=p2=h0=None;choch=w3=0;out=[]
    prices=bars[['high','low','close']].to_numpy();times=bars.bar.to_numpy()
    for i,(high,low,close) in enumerate(prices):
        invalid=state.startswith('WAVE') and (close<p0[0] or (p2 is not None and close<p2[0]))
        if invalid:state='RANGE_UNKNOWN';hs=[];ls=[];p0=p1=p2=h0=None;choch=w3=0
        k=i-2
        if not invalid and k>=2:
            for side in [0,1]:
                x=prices[k,side]
                left=prices[k-2:k,side];right=prices[k+1:i+1,side]
                pivot=all(x>left) and all(x>=right) if side==0 else all(x<left) and all(x<=right)
                if not pivot:continue
                p=(x,times[k],times[i]+900)
                if side==0:hs=(hs+[p])[-2:]
                else:ls=(ls+[p])[-2:]
                if state=='WAVE1_UP' and side==0 and p[1]>choch and p[0]>h0[0]:p1=p;state='WAVE2_PULLBACK'
                elif state=='WAVE2_PULLBACK' and side==1 and p2 is None and p[1]>p1[1] and p[0]>p0[0]:
                    if all(prices[k+1:i+1,1]>=p[0]):p2=p
                elif state=='WAVE3_UP' and side==0 and p[1]>w3:
                    state='RANGE_UNKNOWN';hs=[];ls=[];p0=p1=p2=h0=None;choch=w3=0
        if not invalid and state=='WAVE2_PULLBACK' and close>p1[0]:
            if p2 is not None:state='WAVE3_UP';w3=times[i]
            else:state='RANGE_UNKNOWN';hs=[];ls=[];p0=p1=p2=h0=None;choch=w3=0
        if not invalid and state in ['DOWN','RANGE_UNKNOWN']:
            down=len(hs)==len(ls)==2 and hs[-1][0]<hs[-2][0] and ls[-1][0]<ls[-2][0]
            state='DOWN' if down else 'RANGE_UNKNOWN'
            if down and close>hs[-1][0] and close>=ls[-1][0]:
                p0=ls[-1];h0=hs[-1];p1=p2=None;choch=times[i];w3=0;state='WAVE1_UP'
        row={'phase':state,'choch':choch,'w3':w3}
        for name,p in [('p0',p0),('h0',h0),('p1',p1),('p2',p2)]:
            row[name]=p[0] if p else 0;row[name+'_bar']=p[1] if p else 0;row[name+'_confirmed']=p[2] if p else 0
        out.append(row)
    return pd.DataFrame(out)
def audit(run):
    p=BASE/run;bars=pd.read_csv(p/'MP_phases.csv');expected=replay(bars)
    for col in expected:
        if col=='phase':assert expected[col].eq(bars[col]).all(),col
        else:assert (expected[col]-bars[col]).abs().lt(1e-8).all(),col
    # Truncation invariance at several intermediate points, including nonterminal waves.
    cuts=sorted(set([min(len(bars),n) for n in [100,1000,8000,len(bars)//2,len(bars)-17]]))
    for cut in cuts:
        prefix=replay(bars.iloc[:cut]);pd.testing.assert_frame_equal(prefix,expected.iloc[:cut],check_dtype=False)
    result={'run':run,'bars':len(bars),'native_vs_python':'EXACT','prefix_lengths':cuts,'prefix_invariance':'PASS'}
    cfg=(p/'test.ini').read_text();date=next(x.split('=')[1] for x in cfg.splitlines() if x.startswith('FromDate='))
    first_test=int(bars['asof'].searchsorted(pd.Timestamp(date).timestamp()))
    warmup_checks={}
    for size in [2000,4000]:
        start=max(0,first_test-size);short=replay(bars.iloc[start:].reset_index(drop=True))
        tail=first_test-start
        warmup_checks[str(size)]=int((short.phase.iloc[tail:].to_numpy()!=expected.phase.iloc[first_test:].to_numpy()).sum())
    result['different_test_phase_bars_with_shorter_warmup']=warmup_checks
    (p/'independent_replay.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
if __name__=='__main__':
    for run in sys.argv[1:]:audit(run)
