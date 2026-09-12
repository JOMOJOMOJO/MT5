#ifndef TICK_SHOCK_CONFIG_MQH
#define TICK_SHOCK_CONFIG_MQH

#include "TickShockTypes.mqh"

struct TickShockConfig
  {
   int grid_ms;
   int baseline_minutes;
   int baseline_exclude_ms;
   int min_baseline_samples;
   double shock_percentile;
   double min_robust_z;
   double min_efficiency;
   double min_move_spread_ratio;
   double min_tick_intensity_ratio;
   double max_spread_median_ratio;
   int max_quote_age_ms;
   double noise_floor_ticks;
   int burst_quiet_ms;
   int burst_max_ms;
   double pullback_min_pct;
   double pullback_max_pct;
   double continuation_invalid_pct;
   int pullback_wait_ms;
   int reacceleration_confirm_ticks;
   double reward_risk;
   int max_hold_seconds;
   double shadow_slippage_ticks;
   double shadow_exit_slippage_ticks;
   double commission_per_lot_round_turn;
   ENUM_TS_RESEARCH_EXECUTION_MODE execution_mode;
   int submit_latency_ms;
  };

struct TickShockSymbolSpec
  {
   string symbol;
   int digits;
   double point;
   double tick_size;
   double tick_value;
   double contract_size;
   double volume_min;
   double volume_max;
   double volume_step;
   int stops_level;
   int freeze_level;
   int filling_mode;
  };

void TSResetConfig(TickShockConfig &config)
  {
   ZeroMemory(config);
   config.grid_ms=250;
   config.baseline_minutes=15;
   config.baseline_exclude_ms=2000;
   config.min_baseline_samples=300;
   config.shock_percentile=99.5;
   config.min_robust_z=3.5;
   config.min_efficiency=0.65;
   config.min_move_spread_ratio=4.0;
   config.min_tick_intensity_ratio=1.5;
   config.max_spread_median_ratio=1.5;
   config.max_quote_age_ms=500;
   config.noise_floor_ticks=1.0;
   config.burst_quiet_ms=300;
   config.burst_max_ms=3000;
   config.pullback_min_pct=15.0;
   config.pullback_max_pct=35.0;
   config.continuation_invalid_pct=50.0;
   config.pullback_wait_ms=10000;
   config.reacceleration_confirm_ticks=2;
   config.reward_risk=1.2;
   config.max_hold_seconds=120;
   config.shadow_slippage_ticks=1.0;
   config.shadow_exit_slippage_ticks=1.0;
   config.commission_per_lot_round_turn=0.0;
   config.execution_mode=REALIZABLE_EA;
   config.submit_latency_ms=0;
  }

bool TSConfigValid(const TickShockConfig &config)
  {
   if(!MathIsValidNumber(config.shock_percentile) || !MathIsValidNumber(config.min_robust_z) ||
      !MathIsValidNumber(config.min_efficiency) || !MathIsValidNumber(config.min_move_spread_ratio) ||
      !MathIsValidNumber(config.min_tick_intensity_ratio) || !MathIsValidNumber(config.max_spread_median_ratio) ||
      !MathIsValidNumber(config.noise_floor_ticks) || !MathIsValidNumber(config.pullback_min_pct) ||
      !MathIsValidNumber(config.pullback_max_pct) || !MathIsValidNumber(config.continuation_invalid_pct) ||
      !MathIsValidNumber(config.reward_risk) || !MathIsValidNumber(config.shadow_slippage_ticks) ||
      !MathIsValidNumber(config.shadow_exit_slippage_ticks) || !MathIsValidNumber(config.commission_per_lot_round_turn)) return false;
   return config.grid_ms>0 && config.baseline_minutes>0 &&
          config.baseline_exclude_ms>=0 && config.min_baseline_samples>0 &&
          config.shock_percentile>0.0 && config.shock_percentile<=100.0 &&
          config.min_robust_z>0.0 && config.min_efficiency>0.0 && config.min_efficiency<=1.0 &&
          config.min_move_spread_ratio>0.0 && config.min_tick_intensity_ratio>0.0 &&
          config.max_spread_median_ratio>0.0 && config.max_quote_age_ms>=0 && config.noise_floor_ticks>=0.0 &&
          config.burst_quiet_ms>0 && config.burst_max_ms>=config.burst_quiet_ms &&
          config.pullback_min_pct>=0.0 && config.pullback_max_pct>=config.pullback_min_pct && config.pullback_max_pct<=100.0 &&
          config.continuation_invalid_pct>config.pullback_max_pct && config.continuation_invalid_pct<=100.0 &&
          config.pullback_wait_ms>0 && config.reacceleration_confirm_ticks>0 &&
          config.reward_risk>0.0 && config.max_hold_seconds>0 &&
          config.shadow_slippage_ticks>=0.0 && config.shadow_exit_slippage_ticks>=0.0 &&
          config.commission_per_lot_round_turn>=0.0 && config.submit_latency_ms>=0 &&
          (config.execution_mode==IDEAL_EVENT_STUDY || config.execution_mode==REALIZABLE_EA);
  }

bool TSSymbolSpecValid(const TickShockSymbolSpec &spec)
  {
   return spec.symbol!="" && spec.digits>=0 && spec.point>0.0 &&
          spec.tick_size>0.0 && spec.volume_min>0.0 && spec.volume_step>0.0;
  }

#endif
