"""Separate causal-time features from retrospective price paths."""
import numpy as np
import pandas as pd

LOCK = 1767225600
FEATURES = ['signal_range_atr','signed_body_atr','rejection_wick_fraction',
            'signed_move12_atr','relative_vol','signed_ema_distance_atr',
            'breakout_margin_atr','signal_spread_proxy_atr']


def labels(trades):
    cash = trades.net_pnl_before_unknown_swap_usd
    early = trades.holding_bars.le(2)
    stop = trades.exit_reason.str.startswith('stop') & ~trades.ambiguous & cash.lt(-1e-10)
    return pd.Series(np.select([
        trades.ambiguous, stop & early, stop & ~early,
        cash.gt(1e-10) & early, cash.gt(1e-10) & ~early,
        cash.lt(-1e-10)], ['ambiguous','early_stop','late_stop','early_win','late_win','other_loss'],
        default='flat'), index=trades.index)


def pre_entry_features(trades, candidates, spec):
    """Only completed signal rows plus ledger identity; excludes entry-bar OHLC."""
    if candidates.candidate_id.duplicated().any():
        raise ValueError('Nonunique candidates')
    c = candidates.set_index('candidate_id').reindex(trades.candidate_id)
    if c.signal_time.isna().any():
        raise ValueError('Missing candidate context')
    c = c.reset_index()
    t = trades.reset_index(drop=True)
    if ((c.available_time > c.signal_time) | (c.signal_time > t.entry_time)).any():
        raise ValueError('Future signal')
    if (c.signal_time >= LOCK).any() or (t.entry_time >= LOCK).any():
        raise ValueError('2026 forbidden')
    if not np.allclose(c.atr14, t.atr14, atol=1e-12, rtol=0):
        raise ValueError('ATR identity mismatch')
    known = c.h4_trend.isin(['up','down','flat'])
    if (c.loc[known,'h4_available_time'].isna() | c.loc[known,'h4_available_time'].gt(c.loc[known,'signal_time'])).any():
        raise ValueError('Future H4')
    sign = np.where(t.side.eq('LONG'), 1., -1.)
    atr, span = c.atr14, c.high-c.low
    result = pd.DataFrame({
        'signal_range_atr': span/atr,
        'signed_body_atr': sign*(c.close-c.open)/atr,
        'rejection_wick_fraction': np.where(sign>0,c.high-c[['open','close']].max(axis=1),c[['open','close']].min(axis=1)-c.low)/span.replace(0,np.nan),
        'signed_move12_atr': sign*c.recent_move_atr,
        'relative_vol': c.relative_vol,
        'signed_ema_distance_atr': sign*(c.close-c.ema_fast)/atr,
        'signal_spread_proxy_atr': c.spread.where(c.spread.gt(0))*spec['point']/atr,
    })
    level = np.where(t.method.isin(['donchian','atr_breakout']),
                     np.where(sign>0,c.dc_high,c.dc_low),
                     np.where(t.method.eq('ichimoku_cloud'),np.where(sign>0,c.cloud_upper,c.cloud_lower),np.nan))
    result['breakout_margin_atr'] = sign*(c.close-level)/atr
    desired = np.where(sign>0,'up','down')
    for source, name in [('trend','h1_alignment'),('h4_trend','h4_alignment')]:
        result[name] = np.where(c[source].isin(['up','down']),np.where(c[source].eq(desired),'aligned','opposed'),c[source].fillna('unknown'))
    result['vol_bucket'] = c.vol_bucket.astype('string').fillna('unknown')
    result['cloud_position'] = c.cloud_position.fillna('unknown')
    result['signal_index'] = c.signal_index
    result['signal_time'] = c.signal_time
    result['signal_low'], result['signal_high'] = c.low, c.high
    return result


def valid_window(bars, entry, n):
    end = entry+n
    if end > len(bars) or int(bars.time.iloc[end-1])+3600 > LOCK:
        return False
    if bars.gap_before_status.iloc[entry+1:end].eq('unknown_gap').any():
        return False
    return bool(np.isfinite(bars[['open','high','low','close']].iloc[entry:end].to_numpy()).all())


def path_features(trade, feature, bars, spec):
    """After-entry descriptions, never eligible predictors or simulated PnL."""
    e, x, atr = int(trade.entry_index), int(trade.exit_index), float(trade.atr14)
    if int(bars.time.iloc[e]) != int(trade.entry_time):
        raise ValueError('Entry index/time mismatch')
    if int(bars.time.iloc[e]) >= LOCK or int(trade.exit_time) >= LOCK:
        raise ValueError('2026 forbidden')
    sign = 1 if trade.side == 'LONG' else -1
    opening = float(bars.open.iloc[e])
    spread = float(trade.entry_spread_pips)*spec['pip_size']
    quote = opening+(spread if sign<0 else 0)
    stop_bid = trade.stop_price-(spread if sign<0 else 0)
    row = dict(
        fill_stop_atr=sign*(trade.entry_fill-trade.stop_price)/atr,
        quote_stop_distance_atr=sign*(quote-trade.stop_price)/atr,
        quote_target_distance_atr=sign*(trade.target_price-quote)/atr,
        entry_spread_proxy_atr=spread/atr,
        proxy_stop_inside_signal_range=bool(feature.signal_low <= stop_bid <= feature.signal_high),
        stop_atr_pips=atr/spec['pip_size'])
    for h in [2,5,10]:
        valid = valid_window(bars,e,h)
        row[f'path_valid_h{h}'] = valid
        row[f'bid_close_return_atr_h{h}'] = sign*(float(bars.close.iloc[e+h-1])-opening)/atr if valid else np.nan
    for name, end in [('through_exit',x+1),('first2',e+2)]:
        if not valid_window(bars,e,end-e):
            row['neutral_stop_reached_'+name] = np.nan
        else:
            part = bars.iloc[e:end]
            row['neutral_stop_reached_'+name] = bool(part.low.min() <= opening-atr if sign>0 else part.high.max() >= opening+atr)
    return row


def group_summary(df):
    early = df.label.eq('early_stop')
    wins = df.net_pnl_before_unknown_swap_usd.gt(1e-10)
    loses = df.net_pnl_before_unknown_swap_usd.lt(-1e-10)
    earlywins = wins & df.holding_bars.le(2)
    return dict(n=len(df), losses=int(loses.sum()), winners=int(wins.sum()),
        early_stops=int(early.sum()), early_wins=int(earlywins.sum()),
        early_stop_rate_all=float(early.mean()), early_stop_rate_losses=float(early.sum()/loses.sum()) if loses.any() else np.nan,
        early_win_rate_winners=float(earlywins.sum()/wins.sum()) if wins.any() else np.nan,
        early_stop_bar1=int((early & df.holding_bars.eq(1)).sum()),
        early_stop_bar2=int((early & df.holding_bars.eq(2)).sum()),
        ambiguous=int(df.ambiguous.sum()), mean_r=float(df.result_r.mean()))


def comparisons(df, reps=2000, seed=20261018):
    """Fixed cell weights, paired calendar moving block resampling, descriptive CIs."""
    cells = sorted(df.cell.unique())
    weeks = pd.date_range(df.week.min(),df.week.max(),freq='7D').strftime('%Y-%m-%d').tolist()
    ci, wi = {v:i for i,v in enumerate(cells)}, {v:i for i,v in enumerate(weeks)}
    shape = (len(weeks),len(cells),2,len(FEATURES))
    sums, counts = np.zeros(shape), np.zeros(shape)
    for row in df.itertuples(index=False):
        if row.label not in ['early_stop','early_win']:
            continue
        g = 0 if row.label == 'early_stop' else 1
        for f,name in enumerate(FEATURES):
            value = getattr(row,name)
            if np.isfinite(value):
                sums[wi[row.week],ci[row.cell],g,f] += value
                counts[wi[row.week],ci[row.cell],g,f] += 1
    weights = df.groupby('cell').size().reindex(cells).to_numpy()
    def diff(s,n):
        means = np.divide(s,n,out=np.full_like(s,np.nan),where=n>0)
        delta = means[:,0,:]-means[:,1,:]
        weighted = np.where(np.isfinite(delta), weights[:,None],0)
        return np.nansum(delta*weighted,axis=0)/weighted.sum(axis=0)
    observed = diff(sums.sum(axis=0),counts.sum(axis=0))
    rng = np.random.default_rng(seed)
    samples = []
    for _ in range(reps):
        starts = rng.integers(0,len(weeks)-3,size=(len(weeks)+3)//4)
        idx = (starts[:,None]+np.arange(4)).ravel()[:len(weeks)]
        samples.append(diff(sums[idx].sum(axis=0),counts[idx].sum(axis=0)))
    lower,upper = np.quantile(samples,[.025,.975],axis=0)
    rows=[]
    for i,feature in enumerate(FEATURES):
        row = dict(feature=feature,cell_weighted_mean_difference=float(observed[i]),ci95_lower=float(lower[i]),ci95_upper=float(upper[i]),
                   interpretation='early_stop_minus_early_win',multiple_comparisons_adjusted=False,bootstrap_reps=reps,block_weeks=4)
        for year in [2024,2025]:
            annual = df.loc[df.year.eq(year) & df.label.isin(['early_stop','early_win'])]
            avg = annual.groupby(['cell','label'])[feature].mean().unstack().reindex(cells)
            delta = avg['early_stop']-avg['early_win']
            good = delta.notna().to_numpy()
            row[f'difference_{year}']=float(np.average(delta.to_numpy()[good],weights=weights[good]))
        rows.append(row)
    # Same calendar blocks for proportion difference; no falsely independent binomial CI.
    totals=np.zeros((len(weeks),4))
    for row in df.itertuples(index=False):
        w=wi[row.week]
        totals[w,0]+=row.label=='early_stop'
        totals[w,1]+=row.net_pnl_before_unknown_swap_usd < -1e-10
        totals[w,2]+=row.net_pnl_before_unknown_swap_usd > 1e-10 and row.holding_bars<=2
        totals[w,3]+=row.net_pnl_before_unknown_swap_usd > 1e-10
    def rate(t):return t[0]/t[1]-t[2]/t[3]
    diffs=[]
    for _ in range(reps):
        starts=rng.integers(0,len(weeks)-3,size=(len(weeks)+3)//4)
        idx=(starts[:,None]+np.arange(4)).ravel()[:len(weeks)]
        diffs.append(rate(totals[idx].sum(axis=0)))
    l,u=np.quantile(diffs,[.025,.975])
    rate_ci=dict(difference=float(rate(totals.sum(axis=0))),ci95_lower=float(l),ci95_upper=float(u),block_weeks=4,reps=reps)
    return pd.DataFrame(rows), rate_ci
