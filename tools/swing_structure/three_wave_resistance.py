"""Causal resistance descriptors; inputs contain no future outcome labels."""
from pathlib import Path
import numpy as np
import pandas as pd

SECONDS={'M1':60,'M5':300,'M15':900,'H1':3600}
LOOKBACK={'M5':1800,'M15':800,'H1':800}
FMT='%Y.%m.%d %H:%M:%S'
TICK=.001
ROUND_TICKS=500
CLUSTER_TICKS=50
HORIZONS=[1.,1.2,1.5,2.]

def seconds(values):return pd.to_datetime(values,format=FMT).astype('datetime64[s]').astype('int64').to_numpy()
def ticks(value):return int(round(float(value)/TICK))
def ts(value):return pd.Timestamp(int(value),unit='s').strftime(FMT)

def swings(t,h,tf_seconds,asof,lookback,partial_peak):
    """Strict 2/2 high, still unbroken through asof, unique tick price (latest pivot)."""
    end=np.searchsorted(t+tf_seconds,asof,side='right');start=max(0,end-lookback)
    t=t[start:end];h=h[start:end]
    if len(t)<5:return [],len(t)
    is_high=np.zeros(len(h),dtype=bool)
    is_high[2:-2]=(h[2:-2]>h[:-4])&(h[2:-2]>h[1:-3])&(h[2:-2]>h[3:-1])&(h[2:-2]>h[4:])
    future_max=np.maximum.accumulate(h[::-1])[::-1]
    result={}
    for i in np.flatnonzero(is_high):
        if max(int(future_max[i+1]),int(partial_peak))>h[i]:continue
        result[int(h[i])]={'price_ticks':int(h[i]),'bar_time':ts(t[i]),'confirmed_time':ts(t[i+2]+tf_seconds)}
    return [result[k] for k in sorted(result)],len(t)

def group_clusters(levels):
    """Disjoint price-ordered bounded-span groups; no single-linkage chaining."""
    groups=[]
    for level in sorted(levels,key=lambda x:x['price_ticks']):
        if not groups or level['price_ticks']-groups[-1][0]['price_ticks']>CLUSTER_TICKS:groups.append([])
        groups[-1].append(level)
    return [g for g in groups if len(set().union(*(x['families'] for x in g)))>=2]

def round_above(ask):return ((ask+ROUND_TICKS-1)//ROUND_TICKS)*ROUND_TICKS

class History:
    def __init__(self,root):
        self.raw={};self.t={};self.h={};self.cache={}
        for tf in SECONDS:
            d=pd.read_csv(Path(root)/('TW_resistance_'+tf+'.csv'))
            self.raw[tf]=d;self.t[tf]=seconds(d.time);self.h[tf]=np.rint(d.high/TICK).astype(np.int64).to_numpy()
            assert np.all(np.diff(self.t[tf])>0),tf+' unordered/duplicate bars'
    def peak_m1(self,from_time,asof,bid):
        a=np.searchsorted(self.t['M1'],from_time,side='left')
        b=np.searchsorted(self.t['M1']+60,asof,side='right')
        return max(bid,int(self.h['M1'][a:b].max()) if b>a else bid)
    def highs(self,tf,asof,bid):
        key=(tf,asof,bid)
        if key in self.cache:return self.cache[key]
        end=np.searchsorted(self.t[tf]+SECONDS[tf],asof,side='right')
        assert end>=LOOKBACK[tf],(tf,ts(asof),'incomplete lookback')
        last_close=int(self.t[tf][end-1]+SECONDS[tf])
        partial=self.peak_m1(last_close,asof,bid)
        out,n=swings(self.t[tf],self.h[tf],SECONDS[tf],asof,LOOKBACK[tf],partial)
        self.cache[key]=(out,n,last_close);return self.cache[key]

def snapshot(history,c,asof,basis):
    ask=ticks(c['entry_ask']);bid=ticks(c['entry_bid']);wave=ticks(c['m5_high'])
    anchor=c['m1_reversal'] if basis=='REVERSAL_CONTROL' or c['stage']=='CHOCH' else c['m1_hl']
    sl=int(np.floor(float(anchor)/TICK-10+1e-9));risk=ask-sl
    assert risk>0
    wave_bar=int(seconds(pd.Series([c['m5_high_time']]))[0]);wave_confirm=int(seconds(pd.Series([c['m5_high_confirmed']]))[0])
    assert wave_confirm<=asof
    broken=history.peak_m1(wave_bar+300,asof,bid)>wave
    active=not broken and wave>=ask
    out={'id':c['id'],'stop_basis':basis,'asof':ts(asof),'known_entry':ask*TICK,'known_sl':sl*TICK,'known_risk':risk*TICK,
         'wave1_price':wave*TICK,'wave1_room_R':(wave-ask)/risk,'wave1_broken':broken,'wave1_active':active,
         'wave1_status':'ACTIVE' if active else 'BROKEN' if broken else 'BELOW_ASK'}
    members=[]
    if active:members.append(dict(family='M5',kind='WAVE1',price_ticks=wave,bar_time=c['m5_high_time'],confirmed_time=c['m5_high_confirmed']))
    for tf,name in [('M5','m5_above_wave1'),('M15','m15'),('H1','h1')]:
        available,n,last_close=history.highs(tf,asof,bid)
        eligible=[v for v in available if v['price_ticks']>=ask and (tf!='M5' or v['price_ticks']>wave)]
        out[name+'_lookback_bars']=n;out[name+'_last_closed_time']=ts(last_close)
        out[name+'_status']='FOUND' if eligible else 'NOT_FOUND_WITHIN_LOOKBACK'
        out[name+'_unbroken_count']=len(eligible)
        if eligible:
            first=eligible[0]
            out[name+'_price']=first['price_ticks']*TICK;out[name+'_room_R']=(first['price_ticks']-ask)/risk
            out[name+'_bar_time']=first['bar_time'];out[name+'_confirmed_time']=first['confirmed_time']
        else:
            for col in ['price','room_R','bar_time','confirmed_time']:out[name+'_'+col]=np.nan
        members.extend(dict(family=tf,kind='SWING',**v) for v in eligible)
    rn=round_above(ask);out['round_price']=rn*TICK;out['round_room_R']=(rn-ask)/risk
    for value in range(rn,ask+max(int(np.ceil(2*risk))+CLUSTER_TICKS,ROUND_TICKS)+1,ROUND_TICKS):
        members.append(dict(family='RN',kind='ROUND',price_ticks=value,bar_time='',confirmed_time=''))
    by_price={}
    for member in members:
        price=member['price_ticks']
        if price not in by_price:by_price[price]={'price_ticks':price,'families':set(),'members':[]}
        by_price[price]['families'].add(member['family']);by_price[price]['members'].append(member)
    levels=[by_price[k] for k in sorted(by_price)]
    first=levels[0];out['first_price']=first['price_ticks']*TICK;out['first_room_R']=(first['price_ticks']-ask)/risk
    out['first_sources']='|'.join(sorted(first['families']))
    groups=group_clusters(levels)
    for bound in HORIZONS:
        tag=str(bound).replace('.','p')
        within=[v for v in levels if v['price_ticks']-ask<=bound*risk+1e-8]
        out['resistance_count_'+tag]=len(within)
        out['source_count_'+tag]=sum(len(v['families']) for v in within)
        out['cluster_count_'+tag]=sum(g[0]['price_ticks']-ask<=bound*risk+1e-8 for g in groups)
    level_rows=[]
    for level in levels:
        for member in level['members']:
            level_rows.append({'id':c['id'],'stop_basis':basis,'price':member['price_ticks']*TICK,
                'distance_R':(member['price_ticks']-ask)/risk,'family':member['family'],'kind':member['kind'],
                'bar_time':member['bar_time'],'confirmed_time':member['confirmed_time']})
    cluster_rows=[]
    for i,g in enumerate(groups):
        cluster_rows.append({'id':c['id'],'stop_basis':basis,'cluster':i,'low':g[0]['price_ticks']*TICK,'high':g[-1]['price_ticks']*TICK,
          'first_R':(g[0]['price_ticks']-ask)/risk,'last_R':(g[-1]['price_ticks']-ask)/risk,
          'levels':len(g),'families':'|'.join(sorted(set().union(*(x['families'] for x in g))))})
    return out,level_rows,cluster_rows

def unit_tests():
    checks=[]
    t=np.arange(9)*300;h=np.array([1,2,5,2,1,2,5,2,1])
    x,_=swings(t,h,300,1200,1800,0);assert not x;checks.append('right confirmation not closed')
    x,_=swings(t,h,300,1500,1800,0);assert len(x)==1 and x[0]['price_ticks']==5;checks.append('exact confirmation boundary')
    x,_=swings(t,h,300,2700,1800,0);assert len(x)==1 and x[0]['bar_time']==ts(1800);checks.append('equal touch and duplicate price keeps latest')
    h2=h.copy();h2[5]=6
    x,_=swings(t,h2,300,2700,1800,0);assert 5 not in [v['price_ticks'] for v in x];checks.append('broken then returned stays broken')
    x,_=swings(t,h,300,1500,1800,6);assert not x;checks.append('partial bar or current Bid breaks high')
    h2=h.copy();h2[3]=5
    x,_=swings(t,h2,300,1500,1800,0);assert not x;checks.append('equal neighbor rejects strict pivot')
    x,_=swings(t,h,300,1500,1800,0);y,_=swings(t[:5],h[:5],300,1500,1800,0);assert x==y;checks.append('future bars do not change prefix')
    assert round_above(150000)==150000 and round_above(150001)==150500;checks.append('round number equality and next half yen')
    levels=[{'price_ticks':p,'families':{f}} for p,f in [(100,'M5'),(140,'M15'),(180,'H1')]]
    groups=group_clusters(levels);assert len(groups)==1 and len(groups[0])==2;checks.append('cluster has bounded span without chaining')
    assert not group_clusters([{'price_ticks':100,'families':{'M5'}},{'price_ticks':120,'families':{'M5'}}]);checks.append('same TF alone is not confluence')
    assert len(group_clusters([{'price_ticks':100,'families':{'M5','RN'}}]))==1;checks.append('same price across families is one cluster')
    return {'passed':True,'cases':checks}
