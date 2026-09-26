"""Read-only audit of the native 2026-09-26 MT5 run; no strategy changes."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'reports/qa/three_wave/m4_review_20260926'
AGENT = Path('C:/Users/windows/AppData/Roaming/MetaQuotes/Tester/2FA8A7E69CED7DC259B1AD86A247F675/Agent-127.0.0.1-3001')
TERMINAL = ROOT.parents[2]
OUT.mkdir(parents=True, exist_ok=True)
log_path = AGENT / 'logs/20260926.log'
lines = log_path.read_text(encoding='utf-16').splitlines()
start = max(i for i, s in enumerate(lines) if 'started with inputs:' in s)
run = lines[start:]
params = dict(re.findall(r'\b(Inp\w+)=(\S+)', '\n'.join(run[:45])))
assert params['InpHigherTF'] == '4' and params['InpSkipLowerHL'] == 'true'
assert params['InpStopMode'] == '2' and params['InpUseEMAFilter'] == 'false'
(OUT / 'actual_inputs.json').write_text(json.dumps(params, indent=2), encoding='utf-8')
(OUT / 'selected_run_evidence.log').write_text('\n'.join(s for s in run if 'TW_M1 ' not in s), encoding='utf-8')
shutil.copy2(AGENT / 'MQL5/Files/TW_deals.csv', OUT / 'native_deals.csv')
risks, signals = {}, {}
for s in run:
    m = re.search(r'(2025\.\d\d\.\d\d \d\d:\d\d:\d\d)   TW_RISK (.*)', s)
    if m:
        risks[pd.Timestamp(m[1]).floor('min')] = {k: float(v) for k, v in re.findall(r'(entry|SL|TP|volume|expected_loss|budget)=([\d.eE+-]+)', m[2])}
    m = re.search(r'TW_SIGNAL id=(\d+)/(\d+)/(\d+) confirmed=(.*?) result=(\S+) sent=(\w+)', s)
    if m and m[6] == 'true':
        signals[pd.Timestamp(m[4])] = {'parent_break': pd.Timestamp(int(m[1]), unit='s'), 'signal_id': '/'.join(m.group(1, 2, 3))}
deals = pd.read_csv(OUT / 'native_deals.csv')
records = []
for pos, g in deals.groupby('position', sort=True):
    en, ex = g[g.entry == 0], g[g.entry == 1]
    assert len(en) == len(ex) == 1
    e, x = en.iloc[0], ex.iloc[0]
    t = pd.Timestamp(e.time).floor('min')
    risk = risks[t]
    pnl = g[['profit', 'commission', 'swap', 'fee']].to_numpy().sum()
    records.append(dict(position=pos, entry_time=pd.Timestamp(e.time), exit_time=pd.Timestamp(x.time),
                        entry_price=e.price, exit_price=x.price, pnl=pnl, win=pnl>0,
                        exit_reason=int(x.reason), net_r=pnl/risk['expected_loss'],
                        stop_pips=(risk['entry']-risk['SL'])/0.01,
                        hold_minutes=(pd.Timestamp(x.time)-pd.Timestamp(e.time)).total_seconds()/60,
                        **risk, **signals[t]))
tr = pd.DataFrame(records).sort_values('entry_time').reset_index(drop=True)
assert len(tr) == len(signals)
assert abs(tr.pnl.sum()-450.08) < 0.001
assert (tr.expected_loss <= tr.budget+1e-8).all()

# Existing same-broker M1 archive. This is explanatory context, not a replacement backtest.
bars_path = ROOT / 'reports/qa/three_wave/resistance_research/TW_resistance_M1.csv'
m1 = pd.read_csv(bars_path, parse_dates=['time']).set_index('time')
m4 = m1.resample('4min').agg({'open':'first','high':'max','low':'min','close':'last'}).dropna()
m4['ph'] = (m4.close > m4.close.shift(1)) & (m4.close >= m4.close.shift(-1))
m4['pl'] = (m4.close < m4.close.shift(1)) & (m4.close <= m4.close.shift(-1))
m4['confirmed'] = m4.index + pd.Timedelta(minutes=8)
for tf in ['4min', '1h']:
    b = m1.resample(tf).agg({'high':'max','low':'min','close':'last'}).dropna()
    b['ema20'] = b.close.ewm(span=20, adjust=False).mean()
    b['rising'] = b.ema20 > b.ema20.shift(1)
    b['above'] = b.close > b.ema20
    b.index = b.index + pd.Timedelta(tf)
    for i, row in tr.iterrows():
        past = b.loc[:row.entry_time]
        if len(past):
            tr.loc[i, tf+'_ema20_rising'] = bool(past.iloc[-1].rising)
            tr.loc[i, tf+'_above_ema20'] = bool(past.iloc[-1].above)
for i, row in tr.iterrows():
    known = m4[(m4.confirmed <= row.parent_break+pd.Timedelta(minutes=4)) & m4.pl]
    origin = known.iloc[-1]
    origin_time = known.index[-1]
    # Require independent price alignment before attributing a wick to the actual SL anchor.
    matched = abs(origin.close-(row.SL+0.01)) <= 0.00101
    tr.loc[i, 'origin_price_match'] = matched
    if matched:
        tr.loc[i, 'origin_time'] = origin_time
        tr.loc[i, 'origin_close'] = origin.close
        tr.loc[i, 'origin_wick_low'] = origin.low
        tr.loc[i, 'sl_above_origin_wick'] = row.SL > origin.low+1e-8
        tr.loc[i, 'close_wick_gap_pips'] = (origin.close-origin.low)/0.01
    known_highs = m4[m4.ph & (m4.confirmed <= row.parent_break+pd.Timedelta(minutes=4))]
    broken = known_highs.iloc[-1].close
    highs = m4[(m4.index >= row.parent_break) & m4.ph & (m4.confirmed <= row.entry_time) & (m4.close > broken)]
    if len(highs):
        wave = highs.iloc[0]
        tr.loc[i, 'wave1_time_inferred'] = highs.index[0]
        tr.loc[i, 'wave1_close_inferred'] = wave.close
        tr.loc[i, 'wave1_headroom_r_inferred'] = (wave.close-row.entry_price)/(row.entry_price-row.SL)
    tr.loc[i, 'entry_hour'] = row.entry_time.hour
    # Only full minutes entirely inside the holding interval; avoids post-exit bar extremes.
    held = m1[(m1.index >= row.entry_time.ceil('min')) & (m1.index+pd.Timedelta(minutes=1) <= row.exit_time)]
    if len(held):
        tr.loc[i, 'mfe_r_full_minutes'] = max(0, (held.high.max()-row.entry_price)/(row.entry_price-row.SL))
        tr.loc[i, 'mae_r_full_minutes'] = max(0, (row.entry_price-held.low.min())/(row.entry_price-row.SL))
tr['month'] = tr.entry_time.dt.strftime('%Y-%m')
tr['stop_bin'] = pd.cut(tr.stop_pips, [0,10,20,40,float('inf')], right=False).astype(str)
tr['session_server_time'] = pd.cut(tr.entry_hour, [-1,5,11,17,23], labels=['00-05','06-11','12-17','18-23']).astype(str)
tr['balance'] = 10000+tr.pnl.cumsum()
peak = tr.balance.cummax().clip(lower=10000)
tr['closed_balance_dd_pct'] = (peak-tr.balance)/peak*100
tr.to_csv(OUT/'trades_review.csv', index=False, encoding='utf-8-sig')
def stats(g):
    return dict(trades=len(g), wins=int(g.win.sum()), win_rate=float(g.win.mean()),
                pnl=float(g.pnl.sum()), mean_r=float(g.net_r.mean()),
                pf=float(g.loc[g.pnl>0,'pnl'].sum()/-g.loc[g.pnl<0,'pnl'].sum()) if (g.pnl<0).any() else None)
monthly = pd.DataFrame([dict(month=k, **stats(g)) for k,g in tr.groupby('month')])
monthly.to_csv(OUT/'monthly.csv', index=False, encoding='utf-8-sig')
features=[]
for col in ['stop_bin','session_server_time','4min_ema20_rising','4min_above_ema20','1h_ema20_rising','1h_above_ema20','sl_above_origin_wick']:
    for val,g in tr.groupby(col):
        features.append(dict(feature=col, value=str(val), **stats(g)))
pd.DataFrame(features).to_csv(OUT/'descriptive_groups.csv', index=False, encoding='utf-8-sig')
streaks=[]
for _,g in tr.groupby(tr.win.ne(tr.win.shift()).cumsum()):
    streaks.append(dict(kind='WIN' if g.win.iloc[0] else 'LOSS', count=len(g),
                        first=str(g.entry_time.iloc[0]),last=str(g.entry_time.iloc[-1]),pnl=float(g.pnl.sum())))
pd.DataFrame(streaks).to_csv(OUT/'streaks.csv', index=False, encoding='utf-8-sig')
overall=stats(tr)
overall.update(max_win_streak=max(x['count'] for x in streaks if x['kind']=='WIN'),
               max_loss_streak=max(x['count'] for x in streaks if x['kind']=='LOSS'),
               max_closed_balance_dd_pct=tr.closed_balance_dd_pct.max(),
               origin_price_matches=int(tr.origin_price_match.eq(True).sum()),
               sl_above_origin_wick=int(tr.sl_above_origin_wick.eq(True).sum()),
               risk_plan_count=len(risks), final_balance=tr.balance.iloc[-1])
rng=np.random.default_rng(260926)
means=tr.net_r.to_numpy()[rng.integers(0,len(tr),size=(20000,len(tr)))].mean(axis=1)
overall['iid_bootstrap_mean_r_95pct']=np.quantile(means,[.025,.975]).tolist()
overall['note']='IID interval ignores optimizer selection and temporal dependence; not proof of edge.'
(OUT/'statistics.json').write_text(json.dumps(overall,indent=2),encoding='utf-8')
sources=[log_path,AGENT/'MQL5/Files/TW_deals.csv',bars_path,ROOT/'mql/Experts/USDJPY_M1_M5_3WaveIn3Wave_Long.mq5',ROOT/'mql/Include/ThreeWaveStructure.mqh']
(OUT/'sources.json').write_text(json.dumps([dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in sources],indent=2),encoding='utf-8')
# Explicit half-period breakdown: description only, not an OOS split (both halves optimized).
half_groups=[]
for half,g in tr.groupby(tr.entry_time.dt.month.le(3).map({True:'Jan-Mar',False:'Apr-Jun'})):
    for value,h in g.groupby('1h_ema20_rising'):
        half_groups.append(dict(half=half,h1_ema20_rising=value,**stats(h)))
pd.DataFrame(half_groups).to_csv(OUT/'h1_half_period.csv',index=False,encoding='utf-8-sig')
optlog=TERMINAL/'Tester/logs/20260926.log'
optlines=optlog.read_text(encoding='utf-16').splitlines()
(OUT/'optimization_evidence.log').write_text('\n'.join(x for x in optlines if any(k in x for k in ['genetic optimization started','Best result','failed, genetic','genetic optimization finished','optimization done in'])),encoding='utf-8')
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
fig,axes=plt.subplots(2,1,figsize=(11,7),layout='constrained')
axes[0].plot(tr.exit_time,tr.balance,color='navy');axes[0].axhline(10000,color='gray',linestyle='--')
axes[0].set(title='Actual native MT5 trades: closed balance (USD)',ylabel='USD')
axes[1].bar(monthly.month,monthly.pnl,color=['seagreen' if x>0 else 'tomato' for x in monthly.pnl])
axes[1].set(title='Monthly realized P/L: selected optimized run',ylabel='USD')
fig.savefig(OUT/'balance_monthly.png',dpi=150);plt.close(fig)
fig,axes=plt.subplots(3,1,figsize=(13,11),layout='constrained')
for ax,day in zip(axes,['2025-01-16','2025-03-28','2025-05-08']):
    row=tr[tr.entry_time.dt.strftime('%Y-%m-%d')==day].iloc[0]
    window=m1.loc[row.origin_time-pd.Timedelta(minutes=10):row.entry_time+pd.Timedelta(minutes=35)]
    ax.vlines(window.index,window.low,window.high,color='slategray',linewidth=.7)
    ax.plot(window.index,window.close,color='slategray',linewidth=.7,label='M1 Bid close / high-low')
    ot=pd.Timestamp(row.origin_time);wt=pd.Timestamp(row.wave1_time_inferred)
    o=m1.loc[ot:ot+pd.Timedelta(minutes=3)].low.idxmin()
    w=m1.loc[wt:wt+pd.Timedelta(minutes=3)].high.idxmax()
    ax.plot([o,w],[row.origin_close,row.wave1_close_inferred],color='seagreen',linewidth=2,label='Current green line reconstruction (close prices)')
    ax.plot([ot+pd.Timedelta(minutes=3),wt+pd.Timedelta(minutes=3)],[row.origin_close,row.wave1_close_inferred],color='seagreen',linestyle=':',label='Close-price points at last M1 bar')
    ax.axhline(row.SL,color='red',linestyle='--',label='Actual SL')
    ax.axhline(row.origin_wick_low,color='darkorange',linestyle=':',label='Origin M4 wick low')
    ax.scatter([row.entry_time],[row.entry_price],color='blue',marker='^',s=65,label='Actual Ask entry')
    ax.set(title=f'{day} | position {row.position} | P/L {row.pnl:+.2f} USD | SL {row.SL:.3f}',ylabel='USDJPY')
    ax.xaxis.set_major_formatter(mdates.DateFormatter('%H:%M'))
axes[0].legend(fontsize=8,ncol=2)
fig.suptitle('Audit reconstruction from archived M1 bars; not an MT5 screenshot',fontsize=12)
fig.savefig(OUT/'wave_sl_examples.png',dpi=150);plt.close(fig)
print(json.dumps(overall,indent=2));print(monthly.to_string(index=False));print(pd.DataFrame(features).to_string(index=False))
