"""Observed annual v1.70/v1.80 feature cohorts; no counterfactual price replay."""
from __future__ import annotations
import csv
from collections import Counter, defaultdict
from decimal import Decimal, ROUND_FLOOR, ROUND_CEILING
from datetime import datetime
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[6]
sys.path.insert(0, str(ROOT / 'tools/wave33_visual'))
from annual_cost_decomposition import native_pairs

OLD = ROOT / 'reports/backtest/runs/wave33_v170_2020/20261022_161002_0ef87d9b'
NEW = ROOT / 'reports/backtest/runs/wave33_v180_2020/20261023_164915_831ff154'
OUT = Path(__file__).resolve().parent


def rows(path):
    with path.open(encoding='utf-8-sig', newline='') as f:
        yield from csv.DictReader(f, delimiter=';')


def config(path):
    with path.open(encoding='utf-8-sig', newline='') as f:
        return {r[0]: ';'.join(r[1:]) for r in list(csv.reader(f, delimiter=';'))[1:]}


def dec(v):
    return str(Decimal(v).normalize())


def candidate_key(r):
    return (r['direction'], r['wave1_start_time'], dec(r['wave1_start_price']), r['upper_break_bar_time'])


def trade_key(r):
    return candidate_key(r) + (r['fill_at'] or r['event_at'],)


def stamp(v):
    return v[:10].replace('.', '-') + v[10:]


def dump_csv(name, data):
    if not data:
        (OUT/name).write_text('', encoding='utf-8')
        return
    keys = list(dict.fromkeys(k for r in data for k in r))
    with (OUT/name).open('w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=keys)
        w.writeheader(); w.writerows(data)


def stats(items):
    n=len(items)
    wins=sum(x['net_cash']>0 for x in items)
    losses=sum(x['net_cash']<0 for x in items)
    gross_win=sum(x['net_cash'] for x in items if x['net_cash']>0)
    gross_loss=-sum(x['net_cash'] for x in items if x['net_cash']<0)
    return dict(n=n, wins=wins, losses=losses, breakeven=n-wins-losses,
                net_cash=sum(x['net_cash'] for x in items), net_r=sum(x['net_r'] for x in items),
                mean_r=sum(x['net_r'] for x in items)/n if n else None,
                profit_factor=gross_win/gross_loss if gross_loss else None,
                intended_actual_rr_mean=sum(x['actual_rr'] for x in items)/n if n else None)


def load(run, arm, version):
    cfg=config(run/'config.csv')
    setups=defaultdict(list); counts=Counter()
    for n,r in enumerate(rows(run/'events.csv'), 2):
        counts[r['event_type']]+=1
        r['_row']=n
        if r['setup_id']:
            setups[r['setup_id']].append(r)
    fills={}; closes={}; cancels=[]; signals=[]
    for sid, events in setups.items():
        for r in events:
            if r['event_type']=='FILL':
                assert sid not in fills
                fills[sid]=r
            elif r['event_type']=='EXIT':
                assert sid not in closes
                closes[sid]=r
            elif r['event_type']=='SIGNAL':
                signals.append(r)
            elif r['event_type']=='INVALIDATE' and r['reason']=='CONNECTED_OPPOSITE_W1_CANDIDATE':
                assert sid not in fills
                assert not any(x['event_type'] in ('ORDER', 'FILL') for x in events)
                source=next(x for x in setups[r['connected_opposite_setup_id']] if x['event_type']=='WAVE1_BREAK')
                assert source['_row']<r['_row']
                assert source['wave1_start_time']==r['wave1_peak_time']==r['connected_shared_time']
                assert abs(float(source['wave1_start_price'])-float(r['wave1_peak_price']))<=float(cfg['point'])/2+1e-9
                assert source['direction']!=r['direction']
                assert all(source[k]==r[k] for k in ('symbol','upper_tf','lower_tf'))
                assert source['candidate_detected_at']>r['candidate_detected_at']
                assert source['event_at']==r['event_at']==r['connected_opposite_known_at']
                assert r['wave1_peak_known_at']<=r['event_at']
                assert r['wave1_peak_fixed']=='1'
                assert source['wave1_start_known_at']<=r['event_at']
                assert not any(x['event_type']=='SKIP' and x['reason']=='ACTIVE_SETUP_SAME_DIRECTION'
                               for x in setups[source['setup_id']])
                cancels.append(dict(arm=arm, setup_id=sid, direction=r['direction'],
                    cancelled_at=r['event_at'], source_setup_id=r['connected_opposite_setup_id'],
                    source_break_at=source['event_at'], origin_time=r['wave1_start_time'],
                    origin_price=float(r['wave1_start_price']), break_bar=r['upper_break_bar_time'],
                    shared_time=r['connected_shared_time'], shared_price=float(r['connected_shared_price']),
                    _candidate_key=candidate_key(r)))
    native={x[0]['at']:x for x in native_pairs(run/'report.htm')}
    assert len(native)==counts['FILL']==counts['EXIT']
    trades=[]
    for sid, fill in fills.items():
        close=closes[sid]
        entry, exit=native.pop(stamp(fill['fill_at']))
        assert stamp(close['exit_at'])==exit['at']
        assert abs(entry['price']-float(fill['entry_price']))<1e-7
        assert abs(exit['price']-float(close['exit_price']))<1e-7
        net=sum(d['profit']+d['commission']+d['swap'] for d in (entry,exit))
        risk=entry['volume']*float(cfg['contract_size'])*abs(entry['price']-float(fill['sl_price']))
        assert abs(net-float(close['execution_net_cash']))<1e-6
        assert abs(risk-float(close['execution_initial_risk_money']))<1e-6
        assert abs(net/risk-float(close['realized_r']))<1e-8
        order=next(x for x in setups[sid] if x['event_type']=='ORDER')
        sig=next(x for x in setups[sid] if x['event_type']=='SIGNAL')
        t=dict(arm=arm, version=version, setup_id=sid, direction=fill['direction'],
            entry_at=fill['fill_at'], exit_at=close['exit_at'], entry_price=entry['price'],
            sl_price=float(fill['sl_price']), tp_price=float(fill['tp_price']),
            tp_rr_price=float(fill.get('tp_rr_price') or fill['tp_price']),
            actual_rr=float(fill['actual_rr']), extended=fill.get('tp_extended_to_wave1')=='1',
            tp_adjustment_reason=fill.get('tp_adjustment_reason',''),
            origin_time=fill['wave1_start_time'], origin_price=float(fill['wave1_start_price']),
            break_bar=fill['upper_break_bar_time'], wave1_peak_time=fill['wave1_peak_time'],
            wave1_peak_price=float(fill['wave1_peak_price']), wave1_peak_known_at=fill['wave1_peak_known_at'],
            wave1_revision=int(fill['wave1_revision']), risk_points=float(fill['risk_points']),
            signal_at=sig['event_at'], order_at=order['event_at'],
            volume=entry['volume'], risk_cash=risk, net_cash=net, net_r=net/risk,
            price_profit_cash=sum(d['profit'] for d in (entry,exit)),
            commission_cash=sum(d['commission'] for d in (entry,exit)),swap_cash=sum(d['swap'] for d in (entry,exit)),
            holding_minutes=(datetime.fromisoformat(exit['at'])-datetime.fromisoformat(entry['at'])).total_seconds()/60,
            exit_reason=close['exit_reason'], _trade_key=trade_key(fill), _candidate_key=candidate_key(fill))
        trades.append(t)
    assert not native
    sig_extended=[x for x in signals if x.get('tp_extended_to_wave1')=='1']
    for sig in sig_extended:
        d=1 if sig['direction']=='LONG' else -1
        assert d*(float(sig['tp_price'])-float(sig['tp_rr_price']))>0
        assert d*(float(sig['wave1_peak_price'])-float(sig['tp_price']))>0
        assert sig['wave1_peak_known_at']<=sig['event_at']
        point,tick=Decimal(cfg['point']),Decimal(cfg['tick_size'])
        margin=max(Decimal(cfg['tp_wave1_buffer_points'])*point,Decimal(sig['spread_points'])*point,tick)
        raw=Decimal(sig['wave1_peak_price'])-Decimal(d)*margin
        expected=(raw/tick).to_integral_value(rounding=ROUND_FLOOR if d>0 else ROUND_CEILING)*tick
        assert expected==Decimal(sig['tp_price'])==Decimal(sig['tp_wave1_target_price'])
        assert abs(Decimal(d)*(Decimal(sig['wave1_peak_price'])-expected)/point-Decimal(sig['tp_wave1_buffer_points']))<Decimal('1e-7')
    source_hashes={str((run/f).relative_to(ROOT)):hashlib.sha256((run/f).read_bytes()).hexdigest()
                   for f in ('events.csv','report.htm','config.csv','inputs.set','lower_bars.csv','upper_bars.csv')}
    return dict(trades=trades, cancels=cancels, signals=signals, counts=dict(counts), cfg=cfg,
                signal_extended_n=len(sig_extended), signal_extended_directions=dict(Counter(x['direction'] for x in sig_extended)),
                hashes=source_hashes)


def clean(r):
    return {k:v for k,v in r.items() if not k.startswith('_')}


def main():
    audit={}; alltrades=[]; cancellations=[]; matches=[]; unmatched=[]; cohorts=[]; config_diffs={}; summaries={}
    for arm,oldname,newname in [('A','a_extension_on','v180_a_both'),('B','b_extension_on','v180_b_both')]:
        old=load(OLD/oldname,arm,'1.70'); new=load(NEW/newname,arm,'1.80')
        audit[arm]={'source_hashes':{**old['hashes'],**new['hashes']},'old_event_counts':old['counts'],'new_event_counts':new['counts']}
        alltrades += old['trades']+new['trades']; cancellations += new['cancels']
        config_diffs[arm]={k:dict(old=old['cfg'].get(k),new=new['cfg'].get(k)) for k in old['cfg'].keys() | new['cfg'].keys() if old['cfg'].get(k)!=new['cfg'].get(k)}
        left={x['_trade_key']:x for x in old['trades']}; right={x['_trade_key']:x for x in new['trades']}
        assert len(left)==len(old['trades']) and len(right)==len(new['trades'])
        common=left.keys() & right.keys(); removed=left.keys()-right.keys(); added=right.keys()-left.keys()
        for key in sorted(common):
            a,b=left[key],right[key]
            same_sl=abs(a['sl_price']-b['sl_price'])<1e-7
            same_entry=abs(a['entry_price']-b['entry_price'])<1e-7
            matches.append(dict(arm=arm,direction=a['direction'],entry_at=a['entry_at'],origin_time=a['origin_time'],origin_price=a['origin_price'],break_bar=a['break_bar'],
                old_setup_id=a['setup_id'],new_setup_id=b['setup_id'],old_net_r=a['net_r'],new_net_r=b['net_r'],delta_r=b['net_r']-a['net_r'],
                old_net_cash=a['net_cash'],new_net_cash=b['net_cash'],delta_cash=b['net_cash']-a['net_cash'],
                old_entry_price=a['entry_price'],new_entry_price=b['entry_price'],same_entry_price=same_entry,
                old_sl=a['sl_price'],new_sl=b['sl_price'],same_sl=same_sl,
                old_peak=a['wave1_peak_price'],new_peak=b['wave1_peak_price'],same_peak=a['wave1_peak_time']==b['wave1_peak_time'] and a['wave1_peak_price']==b['wave1_peak_price'],
                old_tp=a['tp_price'],new_tp=b['tp_price'],tp_extended=b['extended'],old_actual_rr=a['actual_rr'],new_actual_rr=b['actual_rr'],
                old_exit_at=a['exit_at'],new_exit_at=b['exit_at'],old_exit_reason=a['exit_reason'],new_exit_reason=b['exit_reason'],
                old_volume=a['volume'],new_volume=b['volume'],old_swap_cash=a['swap_cash'],new_swap_cash=b['swap_cash'],
                old_holding_minutes=a['holding_minutes'],new_holding_minutes=b['holding_minutes']))
        old_by_candidate={x['_candidate_key']:x for x in old['trades']}
        new_by_candidate={x['_candidate_key']:x for x in new['trades']}
        cancel_keys={x['_candidate_key'] for x in new['cancels']}
        for status, keys, source, other in [('REMOVED',removed,left,new_by_candidate),('ADDED',added,right,old_by_candidate)]:
            for key in sorted(keys):
                t=source[key]
                unmatched.append(dict(status=status,**clean(t),same_candidate_other_fill_exists=t['_candidate_key'] in other,
                    new_connected_cancellation=t['_candidate_key'] in cancel_keys))
        for c in new['cancels']:
            c['old_observed_trade_exists']=c['_candidate_key'] in old_by_candidate
            # Retain an observed baseline reference, never label this a foregone new-version P/L.
            c['old_observed_setup_id']=old_by_candidate.get(c['_candidate_key'],{}).get('setup_id','')
        for version,items in [('1.70',old['trades']),('1.80',new['trades'])]:
            for label,part in [('ALL',items),('TP_EXTENDED',[x for x in items if x['extended']]),('TP_NOT_EXTENDED',[x for x in items if not x['extended']])]:
                cohorts.append(dict(arm=arm,version=version,cohort=label,**stats(part)))
        mc=[x for x in matches if x['arm']==arm]
        common_effects=[]
        for label,subset in [('EXTENDED',[x for x in mc if x['tp_extended']]),('UNCHANGED_TP',[x for x in mc if not x['tp_extended']])]:
            common_effects.append(dict(cohort=label,n=len(subset),old_net_r=sum(x['old_net_r'] for x in subset),new_net_r=sum(x['new_net_r'] for x in subset),
                delta_r=sum(x['delta_r'] for x in subset),old_net_cash=sum(x['old_net_cash'] for x in subset),new_net_cash=sum(x['new_net_cash'] for x in subset),
                win_to_loss=sum(x['old_net_r']>0>x['new_net_r'] for x in subset),loss_to_win=sum(x['old_net_r']<0<x['new_net_r'] for x in subset)))
        summaries[arm]=dict(old=stats(old['trades']),new=stats(new['trades']),connected_cancellations=len(new['cancels']),
            cancellations_by_direction=dict(Counter(x['direction'] for x in new['cancels'])),
            cancellations_with_baseline_observed_fill=sum(x['old_observed_trade_exists'] for x in new['cancels']),
            cancelled_candidates_baseline_observed_fills=stats([x for x in old['trades'] if x['_candidate_key'] in cancel_keys]),
            signal_count=len(new['signals']),signal_extended_count=new['signal_extended_n'],signal_extended_directions=new['signal_extended_directions'],
            filled_extensions=sum(x['extended'] for x in new['trades']),filled_extension_directions=dict(Counter(x['direction'] for x in new['trades'] if x['extended'])),
            common=len(common),removed=len(removed),added=len(added),
            removed_exact_fill_matched_to_connected_cancel=sum(x['_candidate_key'] in cancel_keys for x in old['trades'] if x['_trade_key'] in removed),
            common_tp_changes=sum(abs(x['new_tp']-x['old_tp'])>1e-7 for x in mc),
            common_same_entry_and_sl=sum(x['same_entry_price'] and x['same_sl'] for x in mc),
            common_r_sum_old=sum(x['old_net_r'] for x in mc),common_r_sum_new=sum(x['new_net_r'] for x in mc),
            common_win_to_loss=sum(x['old_net_r']>0 and x['new_net_r']<0 for x in mc),
            common_loss_to_win=sum(x['old_net_r']<0 and x['new_net_r']>0 for x in mc),
            common_effects=common_effects,
            old_removed_observed=stats([left[k] for k in removed]),new_added_observed=stats([right[k] for k in added]))
    changed=[x for x in matches if x['tp_extended'] and x['same_entry_price'] and x['same_sl'] and x['same_peak'] and abs(x['delta_r'])>.05]
    # Fixed descriptive selection: largest observed R improvement and deterioration among identical-geometry common fills.
    examples=([dict(selection='MAX_OBSERVED_R_IMPROVEMENT',**max(changed,key=lambda x:x['delta_r'])),
               dict(selection='MAX_OBSERVED_R_DETERIORATION',**min(changed,key=lambda x:x['delta_r']))] if changed else [])
    dump_csv('trades.csv',[clean(x) for x in alltrades]); dump_csv('cancellations.csv',[clean(x) for x in cancellations])
    dump_csv('common_trades.csv',matches); dump_csv('unmatched_trades.csv',unmatched); dump_csv('cohorts.csv',cohorts); dump_csv('examples.csv',examples)
    result=dict(status='PASS',definitions=dict(match='direction + W1 origin time/price + upper break bar time + actual fill time, not setup ID',
        realized_r='native net cash (price profit + commission + swap) / initial fill-to-SL monetary risk',
        cohorts='extension flag frozen in actual FILL snapshot; signal-only extension counts reported separately',
        tp_policy='max(additional10 points, current spread, one tick), inward tick rounding inside known fixed W1 endpoint; farther original target preserved; SL unchanged',
        examples='largest observed R improvement and deterioration among common entries with identical fill price, SL, W1 endpoint and extended TP'),
        summaries=summaries,config_differences=config_diffs,cohorts=cohorts,examples=examples,audit=audit,
        limitations=['Annual comparison has both cancellation and TP extension active; it is not an isolated causal A/B test.',
          'Earlier cancellations and longer holding can change subsequent candidate lanes, position availability, exits, equity and lot size.',
          'No hypothetical result is assigned to canceled or otherwise unfilled candidates. Old observed fills are references only.',
          'Cash differences include equity-based sizing feedback. R is normalized per actual initial risk.',
          'All 2020 data were previously observed. This is descriptive in-sample research, not an OOS or profitability promotion.'])
    (OUT/'summary.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(summaries=summaries,examples=examples,config_differences=config_diffs),ensure_ascii=False,indent=2))


if __name__=='__main__':
    main()
