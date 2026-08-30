#!/usr/bin/env python3
"""Generate frozen Step 15F registry, trial, fixtures and independent expected values."""
from __future__ import annotations
import csv, hashlib, json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'reports/analysis/tick_shock/step15f'
BASE=('test_id','requirement_id','defect_id','component','test_layer','direction','fixture_path','expected_path','current_expected_status','description')
FEATURES=[
('F01','ema20_distance_m1','(mid-EMA20_M1)/ATR14_M1','M1','50 closed bars','Mid','ATR14','decision quote','FAIL_CLOSED','continuous','trend'),
('F02','ema50_distance_m1','(mid-EMA50_M1)/ATR14_M1','M1','50 closed bars','Mid','ATR14','decision quote','FAIL_CLOSED','continuous','trend'),
('F03','ema20_slope_m1','(EMA20_0-EMA20_3)/ATR14_0','M1','53 closed bars','close','ATR14','decision quote','FAIL_CLOSED','continuous','trend'),
('F04','ema50_slope_m1','(EMA50_0-EMA50_3)/ATR14_0','M1','53 closed bars','close','ATR14','decision quote','FAIL_CLOSED','continuous','trend'),
('F05','ema_alignment_m1','sign(EMA20-EMA50)','M1','50 closed bars','close','none','decision quote','FAIL_CLOSED','{-1,0,1}','trend'),
('F06','ema_alignment_m5','sign(EMA20-EMA50)','M5','250 closed M1','close','none','decision quote','FAIL_CLOSED','{-1,0,1}','trend'),
('F07','ema_alignment_m15','sign(EMA20-EMA50)','M15','750 closed M1','close','none','decision quote','FAIL_CLOSED','{-1,0,1}','trend'),
('F08','shock_alignment_m5','alignment_M5*shock_direction','M5','250 closed M1','close','none','decision quote','FAIL_CLOSED','{-1,0,1}','trend'),
('F09','shock_alignment_m15','alignment_M15*shock_direction','M15','750 closed M1','close','none','decision quote','FAIL_CLOSED','{-1,0,1}','trend'),
('F10','return_1m','log(close0/close1)','M1','2 closed bars','close','none','decision quote','FAIL_CLOSED','continuous','momentum'),
('F11','return_5m','log(close0/close5)','M1','6 closed bars','close','none','decision quote','FAIL_CLOSED','continuous','momentum'),
('F12','return_15m','log(close0/close15)','M1','16 closed bars','close','none','decision quote','FAIL_CLOSED','continuous','momentum'),
('F13','shock_pre_momentum_5m','return_5m*shock_direction','M1','6 closed bars','close','none','decision quote','FAIL_CLOSED','continuous','momentum'),
('F14','trend_efficiency_15m','abs(close0-close15)/sum(abs(delta))','M1','16 closed bars','close','none','decision quote','FAIL_CLOSED','[0,1]','momentum'),
('F15','daily_range_position','(mid-observed_low)/(observed_high-observed_low)','tick','observed server day','Mid','range','decision quote','FAIL_CLOSED','[0,1]','position'),
('F16','atr14_m1','Wilder ATR14','M1','15 closed bars','OHLC','price','decision quote','FAIL_CLOSED','positive','volatility'),
('F17','atr14_m5','Wilder ATR14','M5','75 closed M1','OHLC','price','decision quote','FAIL_CLOSED','positive','volatility'),
('F18','atr14_m15','Wilder ATR14','M15','225 closed M1','OHLC','price','decision quote','FAIL_CLOSED','positive','volatility'),
('F19','realized_vol_1m','RMS completed M1 log return','M1','2 closed bars','close','none','decision quote','FAIL_CLOSED','nonnegative','volatility'),
('F20','realized_vol_5m','RMS completed M1 log returns','M1','6 closed bars','close','none','decision quote','FAIL_CLOSED','nonnegative','volatility'),
('F21','realized_vol_15m','RMS completed M1 log returns','M1','16 closed bars','close','none','decision quote','FAIL_CLOSED','nonnegative','volatility'),
('F22','short_long_vol_ratio','rv_1m/rv_15m','M1','16 closed bars','close','ratio','decision quote','FAIL_CLOSED','nonnegative','volatility'),
('F23','shock_pre_vol_ratio','initial_shock/(pre_m1_rms*anchor_mid)','mixed','10 pre returns','Mid','ratio','confirmed','FAIL_CLOSED','nonnegative','volatility'),
('F24','volatility_percentile','causal rank of rv15 in prior 128 samples','M1','128 prior values','close','percentile','decision quote','FAIL_CLOSED','[0,1]','volatility'),
('F25','entry_spread','ask-bid','tick','current quote','BidAsk','price','decision quote','FAIL_CLOSED','positive','liquidity'),
('F26','spread_atr_ratio','spread/ATR14_M1','mixed','15 closed M1','BidAsk','ratio','decision quote','FAIL_CLOSED','nonnegative','liquidity'),
('F27','spread_prevol_ratio','spread/(pre_m1_rms*mid)','mixed','10 pre returns','BidAsk','ratio','decision quote','FAIL_CLOSED','nonnegative','liquidity'),
('F28','tick_activity','updates in trailing completed minute','tick','1 closed minute','BidAsk','count','decision quote','FAIL_CLOSED','nonnegative','liquidity'),
('F29','quote_age_ms','processing_msc-quote_msc','tick','current quote','BidAsk','ms','decision quote','FAIL_CLOSED','nonnegative','liquidity'),
('F30','severity','frozen detector severity ordinal','shock','anchor','detector','ordinal','confirmed','FAIL_CLOSED','nonnegative','shock'),
('F31','initial_shock_spread_ratio','initial_shock/anchor_spread','shock','anchor','BidAsk','ratio','confirmed','FAIL_CLOSED','nonnegative','shock'),
('F32','confirmation_delay_ms','confirmed_msc-candidate_msc','shock','anchor','clock','ms','confirmed','FAIL_CLOSED','nonnegative','shock'),
('F33','repeat_count','causal repeats observed by checkpoint','shock','episode to checkpoint','detector','count','decision quote','ZERO_ALLOWED','nonnegative','shock'),
('F34','repeat_direction_balance','(same-opposite)/max(1,repeats)','shock','episode to checkpoint','detector','ratio','decision quote','ZERO_ALLOWED','[-1,1]','shock'),
('F35','origin_recross_available','causal recross by checkpoint','shock','anchor to checkpoint','Mid','binary','decision quote','ZERO_ALLOWED','{0,1}','shock'),
('F36','usd_factor_alignment','sign(USD factor)*pair shock USD sign','cross-symbol','latest closed M1','close','binary','decision quote','FAIL_CLOSED','{-1,0,1}','usd_context')]
CASES=[
('AUDIT',1,'reversal_long_return','0.0002','price'),('AUDIT',2,'primary_funnel_total','2734','count'),('AUDIT',3,'exclusive_reason_count','1','count'),
('BAR',1,'completed_m1_close','1.0010','price'),('BAR',2,'completed_m5_count','50','count'),('BAR',3,'completed_m15_count','50','count'),('BAR',4,'future_bar_reads','0','count'),
('BAR',5,'ema20','19.5','value'),('BAR',6,'ema50','34.5','value'),('BAR',7,'ema_slope','0.3','value'),('BAR',8,'atr14','2.0','value'),
('MATH',1,'zero_atr_status','MISSING','text'),('MATH',2,'normalized_distance','1.5','ratio'),('MATH',3,'trailing_return','0.009950330853','log_return'),
('MATH',4,'realized_volatility','0.01','log_return'),('MATH',5,'daily_range_position','0.75','ratio'),('MATH',6,'spread_atr_ratio','0.1','ratio'),('MATH',7,'repeat_balance','0.5','ratio'),
('USD',1,'eurusd_usd_sign','-1','sign'),('USD',2,'usd_factor','0.2','zscore'),('USD',3,'future_breadth_reads','0','count'),('USD',4,'checkpoint_msc','61000','ms'),
('EXEC',1,'continuation_return','0.0002','price'),('EXEC',2,'reversal_return','0.0002','price'),('EXEC',3,'control_anchor_msc','900000','ms'),('EXEC',4,'pseudo_direction','1','sign'),
('SPLIT',1,'episode_fold_count','1','count'),('SPLIT',2,'purge_ms','900000','ms'),('SPLIT',3,'training_only_scaler','true','bool'),('SPLIT',4,'training_only_bucket','true','bool'),('SPLIT',5,'training_only_model_selection','true','bool'),
('INTEGRITY',1,'missing_policy','FAIL_CLOSED','text'),('INTEGRITY',2,'deterministic_seed','20260831','seed'),('INTEGRITY',3,'feature_spec_valid','true','bool'),('INTEGRITY',4,'step15e_identity_mismatches','0','count'),('INTEGRITY',5,'order_send_calls','0','count')]

def canonical_hash(rows):return hashlib.sha256(json.dumps(rows,separators=(',',':'),ensure_ascii=False).encode()).hexdigest().upper()
def main():
    assert len(FEATURES)==36 and len(CASES)==36;OUT.mkdir(parents=True,exist_ok=True)
    fh=canonical_hash(FEATURES);mh=canonical_hash({'seed':20260831,'folds':5,'purge_ms':900000,'embargo_ms':900000,'models':['elastic_net_regression','elastic_net_logistic','shallow_gradient_boosting']})
    with (OUT/'feature_registry.csv').open('w',encoding='utf-8',newline='') as h:
        cols=('feature_id','name','formula','timeframe','lookback','source_price','normalization','available_timestamp','missing_policy','expected_range','family','engineering_assumption','spec_hash');w=csv.writer(h);w.writerow(cols)
        for r in FEATURES:w.writerow((*r,'ENGINEERING_ASSUMPTION_TO_BE_VALIDATED' if 'ema' in r[1] or 'atr' in r[1] else 'FROZEN_CAUSAL_DEFINITION',fh))
    with (OUT/'trial_registry.csv').open('w',encoding='utf-8',newline='') as h:
        w=csv.writer(h);w.writerow(('trial_id','feature_spec_hash','model_family_hash','seed','period','status'));w.writerow(('TS15F-CONTEXT-V1',fh,mh,20260831,'2025-03-01_TO_2025-04-01','PREREGISTERED_DEVELOPMENT_ONLY'))
    registry=ROOT/'tests/tick_shock/spec/test_cases.csv'
    with registry.open(encoding='utf-8-sig',newline='') as h:rows=list(csv.DictReader(h))
    rows=[r for r in rows if not r['test_id'].startswith('TS15F-')];fixtures=ROOT/'tests/tick_shock/fixtures';expected=ROOT/'tests/tick_shock/expected'
    for group,num,field,value,unit in CASES:
        tid=f'TS15F-{group}-{num:03d}'
        with (fixtures/f'{tid}_ticks.csv').open('w',encoding='utf-8',newline='') as h:
            w=csv.writer(h);w.writerow(('sequence','symbol','time_msc','bid','ask','processing_msc','note'))
            w.writerows(((1,'EURUSD',1000,1.0000,1.0002,1010,'causal quote'),(2,'EURUSD',61000,1.0010,1.0012,61010,'later minute closes prior'),(3,'USDJPY',61000,150.00,150.02,61011,'causal USD peer')))
        with (fixtures/f'{tid}_config.csv').open('w',encoding='utf-8',newline='') as h:
            w=csv.writer(h);w.writerow(('key','value','unit','note'));w.writerows((('case',tid,'id','frozen'),('feature_spec_hash',fh,'sha256','canonical registry'),('model_family_hash',mh,'sha256','finite family'),('seed',20260831,'seed','deterministic'),('production_formula_used_for_expected','false','bool','independent oracle')))
        with (expected/f'{tid}_expected.csv').open('w',encoding='utf-8',newline='') as h:
            w=csv.writer(h);w.writerow(('field','expected_value','tolerance','unit','note'));w.writerow((field,value,'1e-9' if unit in ('price','value','ratio','log_return','zscore') else '0',unit,'frozen independent oracle'))
        rows.append(dict(zip(BASE,(tid,f'TS15F-REQ-{group}','STEP15F-PRE-FIX','causal_context_features','production_path_integration','BOTH',f'tests/tick_shock/fixtures/{tid}_ticks.csv',f'tests/tick_shock/expected/{tid}_expected.csv','XFAIL',f'{tid} frozen causal contract'))))
    rows.sort(key=lambda x:x['test_id'])
    with registry.open('w',encoding='utf-8-sig',newline='') as h:w=csv.DictWriter(h,fieldnames=BASE);w.writeheader();w.writerows(rows)
    print(f'features=36 tests=36 feature_hash={fh} model_hash={mh}')
if __name__=='__main__':main()
