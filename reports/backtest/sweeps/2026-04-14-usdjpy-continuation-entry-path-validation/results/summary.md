# USDJPY Continuation Entry Path Validation

## Matrix

- entry paths: pullback_reclaim / higher_low_break / retest_continuation
- timeframe pairs: M15xM5 / M30xM5 / M15xM1 / H1xM5
- target modes: prior_swing / fixed_r / fib
- stop basis: stop_pullback_low / stop_higher_low
- tier: Tier A strict only

## Path Highlights

### train
- `pullback_reclaim` PF=`0.0` trades=`0` net=`0.0` avgR=`0.0`
  - best `m15_m5` `prior_swing` `stop_pullback_low` PF=`0.0` trades=`0` net=`0.0`
  - best `m15_m5` `prior_swing` `stop_higher_low` PF=`0.0` trades=`0` net=`0.0`
  - best `m15_m5` `fixed_r` `stop_pullback_low` PF=`0.0` trades=`0` net=`0.0`
- `higher_low_break` PF=`0.733` trades=`216` net=`-552.47` avgR=`-0.0794`
  - best `m15_m1` `fib` `stop_pullback_low` PF=`1.18` trades=`29` net=`32.45`
  - best `m15_m1` `fixed_r` `stop_pullback_low` PF=`1.18` trades=`29` net=`31.98`
  - best `m15_m1` `fib` `stop_higher_low` PF=`1.05` trades=`29` net=`14.08`
- `retest_continuation` PF=`0.0` trades=`0` net=`0.0` avgR=`0.0`
  - best `m15_m5` `prior_swing` `stop_pullback_low` PF=`0.0` trades=`0` net=`0.0`
  - best `m15_m5` `prior_swing` `stop_higher_low` PF=`0.0` trades=`0` net=`0.0`
  - best `m15_m5` `fixed_r` `stop_pullback_low` PF=`0.0` trades=`0` net=`0.0`

### oos
- `pullback_reclaim` PF=`0.0` trades=`0` net=`0.0` avgR=`0.0`
  - best `m15_m5` `prior_swing` `stop_pullback_low` PF=`0.0` trades=`0` net=`0.0`
  - best `m15_m5` `prior_swing` `stop_higher_low` PF=`0.0` trades=`0` net=`0.0`
  - best `m15_m5` `fixed_r` `stop_pullback_low` PF=`0.0` trades=`0` net=`0.0`
- `higher_low_break` PF=`3.1378` trades=`24` net=`221.97` avgR=`0.2635`
  - best `m15_m1` `fib` `stop_higher_low` PF=`1.59` trades=`2` net=`12.58`
  - best `m15_m1` `fib` `stop_pullback_low` PF=`1.33` trades=`2` net=`4.33`
  - best `m15_m1` `prior_swing` `stop_higher_low` PF=`1.11` trades=`2` net=`2.42`
- `retest_continuation` PF=`0.0` trades=`0` net=`0.0` avgR=`0.0`
  - best `m15_m5` `prior_swing` `stop_pullback_low` PF=`0.0` trades=`0` net=`0.0`
  - best `m15_m5` `prior_swing` `stop_higher_low` PF=`0.0` trades=`0` net=`0.0`
  - best `m15_m5` `fixed_r` `stop_pullback_low` PF=`0.0` trades=`0` net=`0.0`

### actual
- `pullback_reclaim` PF=`0.0` trades=`0` net=`0.0` avgR=`0.0`
  - best `m15_m5` `prior_swing` `stop_pullback_low` PF=`0.0` trades=`0` net=`0.0`
  - best `m15_m5` `prior_swing` `stop_higher_low` PF=`0.0` trades=`0` net=`0.0`
  - best `m15_m5` `fixed_r` `stop_pullback_low` PF=`0.0` trades=`0` net=`0.0`
- `higher_low_break` PF=`0.6535` trades=`312` net=`-1249.52` avgR=`-0.1182`
  - best `m15_m5` `fib` `stop_higher_low` PF=`2.56` trades=`3` net=`62.28`
  - best `m15_m5` `fixed_r` `stop_pullback_low` PF=`2.29` trades=`3` net=`51.02`
  - best `m15_m5` `fib` `stop_pullback_low` PF=`2.29` trades=`3` net=`51.02`
- `retest_continuation` PF=`0.0` trades=`0` net=`0.0` avgR=`0.0`
  - best `m15_m5` `prior_swing` `stop_pullback_low` PF=`0.0` trades=`0` net=`0.0`
  - best `m15_m5` `prior_swing` `stop_higher_low` PF=`0.0` trades=`0` net=`0.0`
  - best `m15_m5` `fixed_r` `stop_pullback_low` PF=`0.0` trades=`0` net=`0.0`

## Telemetry Buckets

### train
- entry_type:
  - entry_on_higher_low_break: PF=0.733 trades=216 net=-552.47 avgR=-0.0794
- fib_depth_bucket:
  - natural: PF=0.733 trades=216 net=-552.47 avgR=-0.0794
- phase:
  - htf_up_pullback: PF=0.733 trades=216 net=-552.47 avgR=-0.0794
- final_reason:
  - time_stop: PF=1.6168 trades=174 net=486.29 avgR=0.0764
  - target: PF=0.0 trades=6 net=242.21 avgR=1.1528
  - stop_loss: PF=0.0 trades=36 net=-1280.97 avgR=-1.0378

### oos
- entry_type:
  - entry_on_higher_low_break: PF=3.1378 trades=24 net=221.97 avgR=0.2635
- fib_depth_bucket:
  - natural: PF=3.1378 trades=24 net=221.97 avgR=0.2635
- phase:
  - htf_up_pullback: PF=3.1378 trades=24 net=221.97 avgR=0.2635
- final_reason:
  - time_stop: PF=1.692 trades=20 net=71.85 avgR=0.1013
  - target: PF=0.0 trades=4 net=150.12 avgR=1.0745

### actual
- entry_type:
  - entry_on_higher_low_break: PF=0.6535 trades=312 net=-1249.52 avgR=-0.1182
- fib_depth_bucket:
  - natural: PF=0.6535 trades=312 net=-1249.52 avgR=-0.1182
- phase:
  - htf_up_pullback: PF=0.6535 trades=312 net=-1249.52 avgR=-0.1182
- final_reason:
  - time_stop: PF=1.3738 trades=236 net=440.53 avgR=0.0522
  - target: PF=0.0 trades=16 net=737.95 avgR=1.3573
  - acceptance_back_below: PF=0.0 trades=3 net=-93.96 avgR=-0.9519
  - stop_loss: PF=0.0 trades=57 net=-2334.04 avgR=-1.1942
