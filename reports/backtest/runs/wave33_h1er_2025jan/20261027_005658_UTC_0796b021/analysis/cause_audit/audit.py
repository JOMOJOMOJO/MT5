"""Bounded cause-path audit: saved native quotes MFE and loss paths only."""
from pathlib import Path
import csv,json,hashlib
import pandas as pd

OUT=Path(__file__).resolve().parent
BATCH=OUT.parents[1]
ROOT=next(p for p in OUT.parents if (p/'mql/Experts').exists())

def repair(path):
    with path.open(encoding='utf-8-sig',newline='') as f:rows=list(csv.reader(f,delimiter=';'))
    head=rows[0];i=head.index('reason');tail=len(head)-i-1
    body=[r[:i]+[';'.join(r[i:len(r)-tail])]+r[-tail:] for r in rows[1:]]
    assert all(len(r)==len(head) for r in body)
    return pd.DataFrame(body,columns=head),sum(len(r)!=len(head) for r in rows[1:])

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    positions=pd.read_csv(BATCH/'analysis/positions.csv');checks=[];rows=[];source_checks={};source_files=['mql/Experts/Wave33H1EfficiencyVerifier.mq5','mql/Include/Wave33Visual/DayTrade.mqh','mql/Include/Wave33Visual/DayTradePartialStops.mqh','mql/Include/Wave33Visual/DayTradePartialExecution.mqh','mql/Include/Wave33Visual/DayTradePartial.mqh']
    for path in source_files:
        frozen=BATCH/'frozen'/path
        source_checks[path]=dict(frozen_sha256=sha(frozen),current_matches_frozen=sha(frozen)==sha(ROOT/path))
    assert all(x['current_matches_frozen'] for x in source_checks.values())
    repair_counts={}
    for arm in ['off','on']:
        src=BATCH/arm/'source';day,drep=repair(next(src.glob('*daytrade.csv')));part,prep=repair(next(src.glob('*partial.csv')))
        repair_counts[arm]=dict(daytrade=drep,partial=prep)
        e=pd.read_csv(next(src.glob('*events.csv')),sep=';',low_memory=False).fillna('')
        g=positions[positions.arm==arm]
        touched=set(part.loc[part.event=='DAY_PARTIAL_TOUCH','setup_id']);filled=set(part.loc[part.event=='DAY_PARTIAL_FILLED','setup_id'])
        mfehit=set(g.loc[g.max_favorable_r_logged>=1-1e-9,'setup_id'])
        failures=part[part.event.str.contains('REJECTED|UNAVAILABLE|WAIT',regex=True)]
        assert len(failures)==0
        assert touched==filled==mfehit
        assert set(e.loc[e.event_type=='DAY_PARTIAL_TOUCH','setup_id'])==touched
        assert set(e.loc[e.event_type=='DAY_PARTIAL_FILLED','setup_id'])==filled
        assert set(g.loc[g.partial.astype(bool),'setup_id'])==filled
        for p in g.itertuples(index=False):
            d=day[day.setup_id==p.setup_id];f=d[d.event=='DAYTRADE_RISK_FROZEN'];c=d[d.event=='DAYTRADE_POSITION_CLOSED'];v=d.max_favorable_r.astype(float)
            assert len(f)==len(c)==1
            assert abs(float(c.iloc[0].max_favorable_r)-p.max_favorable_r_logged)<1e-9
            assert all(v.diff().fillna(0)>=-1e-9)
            assert abs(float(f.iloc[0].entry)-p.entry_price)<1e-7
            assert abs(float(f.iloc[0].original_sl)-p.initial_sl)<1e-7
            assert abs(float(f.iloc[0].fixed_risk_price)-p.original_risk_price)<1e-7
            assert abs(abs(p.entry_price-p.initial_sl)-p.original_risk_price)<1e-7
            assert int(f.iloc[0].first_fill_msc)==p.fill_msc
            assert int(f.iloc[0].time_msc)==p.fill_msc
            if p.net_r<0 and p.max_favorable_r_logged<1-1e-9:
                assert p.exit_reason=='DEAL_REASON_SL'
                assert set(d.stage.astype(int))=={-1}
                actual_sl=d.broker_sl.astype(float);actual_sl=actual_sl[actual_sl>0]
                assert all(abs(actual_sl-p.initial_sl)<1e-7)
                assert p.setup_id not in filled
            rows.append(dict(arm=arm,setup_id=p.setup_id,direction=p.direction,fill_at=p.fill_at,exit_at=p.exit_at,net_r=p.net_r,loss=p.net_r<0,max_favorable_r=p.max_favorable_r_logged,reached_1r=p.setup_id in touched,partial_filled=p.setup_id in filled,exit_reason=p.exit_reason,entry=p.entry_price,initial_sl=p.initial_sl,initial_risk_price=p.original_risk_price))
        for direction,subset in [('ALL',g),('LONG',g[g.direction=='LONG']),('SHORT',g[g.direction=='SHORT'])]:
            loss=subset[subset.net_r<0];below=loss[loss.max_favorable_r_logged<1-1e-9]
            checks.append(dict(arm=arm,direction=direction,positions=len(subset),losses=len(loss),losses_before_1r=len(below),losses_reached_1r=len(loss)-len(below),loss_mfe_median=float(loss.max_favorable_r_logged.median()),loss_mfe_max=float(loss.max_favorable_r_logged.max()),before_1r_loss_sum_r=float(below.net_r.sum()),all_net_r=float(subset.net_r.sum())))
    frame=pd.DataFrame(rows);frame.to_csv(OUT/'position_loss_paths.csv',index=False);pd.DataFrame(checks).to_csv(OUT/'counts.csv',index=False)
    reached_losses=frame[(frame.loss)&(frame.reached_1r)]
    reached_losses.to_csv(OUT/'losses_after_1r.csv',index=False)
    result=dict(scope='XAUUSD+ M5 x M1 native January 2025, fixed OFF/ON H1 filter comparison',source_checks=source_checks,csv_unquoted_semicolon_rows_repaired=repair_counts,position_audits=len(frame),all_mfe_final_rows_match=True,all_mfe_logged_sequences_nondecreasing=True,all_fixed_actual_fill_and_original_risk_match=True,all_state_initialized_on_first_fill_tick=True,all_mfe_1r_hit_sets_match_partial_touch_filled_and_raw_partial_flags=True,all_below_1r_losses_closed_original_unchanged_sl_without_partial=True,partial_rejected_unavailable_or_wait_rows=0,counts=checks,only_losing_position_reaching_1r=reached_losses.to_dict(orient='records'),mfe_definition='max(0, direction * (executable quote - actual weighted entry) / frozen original SL price distance), LONG Bid / SHORT Ask, updated on processed native OnTick while owned position and settled entry state exist',causal_boundary={'confirmed':['Dominant observed loss path is original SL before executable +1R partial trigger, not a large profitable run given back.','OFF removes 13 entries including 10 losses and 3 wins; common 16 retain same normalized execution schedules.','ON retained losing shorts all fail to reach +1R; their median MFE is only about 0.058R.'], 'not_proved':['A unique fundamental market cause, predictive causal effect outside January, or universal superiority of H1 filter.','That every loss is a false reversal, bad H1 direction, excessively wide SL, late entry, double top, or literal frequent oscillation.','That intrahour wick count is captured by H1 close ER.','That adjusting exits can rescue trades which never reached the proposed profitable exit level.']},limitations=['MFE is a native EA-processed executable-quote observation, not an independently exported complete tick-path supremum.','Time/opposite exits execute before MFE observation, and a broker stop may close a position before that tick is processed by the EA. No alternate realized fill is invented.','The price-distance R MFE includes Bid/Ask spread through executable quotes but excludes commissions/swap/fee; net outcome R includes those costs.','For this sample, partial-touch/fill and raw exit flags agree exactly with the logged 1R hit classification.','One known month and small directional samples; February/March comparison is required before broader inference.'])
    (OUT/'summary.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(dict(counts=checks,positions=len(frame),only_losing_position_reaching_1r=reached_losses.to_dict(orient='records'),csv_repairs=repair_counts),ensure_ascii=True,indent=2))

if __name__=='__main__':main()
