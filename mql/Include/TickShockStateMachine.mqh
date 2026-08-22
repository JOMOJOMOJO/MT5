#ifndef __TICK_SHOCK_STATE_MACHINE_MQH__
#define __TICK_SHOCK_STATE_MACHINE_MQH__

// Pure, deterministic state-transition helpers shared by the production EA
// and the separate reachability harness.  No tester-only branch exists here.

enum ENUM_TS_STATE
  {
   TS_SCANNING = 0,
   TS_BURST_ACTIVE,
   TS_WAIT_PULLBACK,
   TS_WAIT_REACCELERATION,
   TS_POSITION_OPEN,
   TS_EXPIRED,
   TS_COOLDOWN
  };

enum ENUM_TS_ACTION
  {
   TS_ACTION_NONE = 0,
   TS_ACTION_BURST_FROZEN,
   TS_ACTION_PULLBACK_VALID,
   TS_ACTION_REACCELERATION,
   TS_ACTION_CONTINUATION_INVALIDATED,
   TS_ACTION_PULLBACK_TIMEOUT,
   TS_ACTION_NO_REACCELERATION
  };

struct TickShockMachine
  {
   ENUM_TS_STATE state;
   int direction;
   long detection_msc;
   long burst_end_msc;
   long last_extreme_msc;
   long pullback_msc;
   long cooldown_until_msc;
   double burst_start;
   double burst_extreme;
   double burst_range;
   double pullback_extreme;
   double max_retracement_pct;
   double last_mid;
   int reacceleration_ticks;
   bool too_deep_seen;
  };

void TSReset(TickShockMachine &machine)
  {
   machine.state = TS_SCANNING;
   machine.direction = 0;
   machine.detection_msc = 0;
   machine.burst_end_msc = 0;
   machine.last_extreme_msc = 0;
   machine.pullback_msc = 0;
   machine.cooldown_until_msc = 0;
   machine.burst_start = 0.0;
   machine.burst_extreme = 0.0;
   machine.burst_range = 0.0;
   machine.pullback_extreme = 0.0;
   machine.max_retracement_pct = 0.0;
   machine.last_mid = 0.0;
   machine.reacceleration_ticks = 0;
   machine.too_deep_seen = false;
  }

void TSStartBurst(TickShockMachine &machine,
                  const int direction,
                  const long detection_msc,
                  const double start_mid,
                  const double current_mid)
  {
   TSReset(machine);
   machine.state = TS_BURST_ACTIVE;
   machine.direction = direction;
   machine.detection_msc = detection_msc;
   machine.last_extreme_msc = detection_msc;
   machine.burst_start = start_mid;
   machine.burst_extreme = current_mid;
   machine.last_mid = current_mid;
  }

double TSRetracementPct(const TickShockMachine &machine,const double current_mid)
  {
   if(machine.burst_range <= 0.0)
      return 0.0;
   double retracement = machine.direction > 0 ?
                        (machine.burst_extreme - current_mid) / machine.burst_range :
                        (current_mid - machine.burst_extreme) / machine.burst_range;
   return retracement * 100.0;
  }

ENUM_TS_ACTION TSAdvance(TickShockMachine &machine,
                         const long now_msc,
                         const double mid,
                         const int burst_quiet_ms,
                         const int burst_max_ms,
                         const double pullback_min_pct,
                         const double pullback_max_pct,
                         const double continuation_invalid_pct,
                         const int pullback_wait_ms,
                         const int reacceleration_confirm_ticks)
  {
   if(machine.state == TS_BURST_ACTIVE)
     {
      bool new_extreme = (machine.direction > 0 && mid > machine.burst_extreme) ||
                         (machine.direction < 0 && mid < machine.burst_extreme);
      if(new_extreme)
        {
         machine.burst_extreme = mid;
         machine.last_extreme_msc = now_msc;
        }
      machine.last_mid = mid;
      if(now_msc - machine.last_extreme_msc >= burst_quiet_ms ||
         now_msc - machine.detection_msc >= burst_max_ms)
        {
         machine.burst_range = MathAbs(machine.burst_extreme - machine.burst_start);
         machine.burst_end_msc = now_msc;
         machine.state = TS_WAIT_PULLBACK;
         return TS_ACTION_BURST_FROZEN;
        }
      return TS_ACTION_NONE;
     }

   if(machine.state != TS_WAIT_PULLBACK && machine.state != TS_WAIT_REACCELERATION)
      return TS_ACTION_NONE;

   double retracement_pct = TSRetracementPct(machine, mid);
   machine.max_retracement_pct = MathMax(machine.max_retracement_pct, retracement_pct);

   if(retracement_pct >= continuation_invalid_pct)
     {
      machine.state = TS_EXPIRED;
      machine.last_mid = mid;
      return TS_ACTION_CONTINUATION_INVALIDATED;
     }

   if(machine.state == TS_WAIT_PULLBACK)
     {
      if(retracement_pct > pullback_max_pct)
         machine.too_deep_seen = true;
      if(retracement_pct >= pullback_min_pct && retracement_pct <= pullback_max_pct)
        {
         machine.pullback_extreme = mid;
         machine.pullback_msc = now_msc;
         machine.state = TS_WAIT_REACCELERATION;
         machine.reacceleration_ticks = 0;
         machine.last_mid = mid;
         return TS_ACTION_PULLBACK_VALID;
        }
      if(now_msc - machine.burst_end_msc >= pullback_wait_ms)
        {
         machine.state = TS_EXPIRED;
         machine.last_mid = mid;
         return TS_ACTION_PULLBACK_TIMEOUT;
        }
      machine.last_mid = mid;
      return TS_ACTION_NONE;
     }

   if(machine.direction > 0)
      machine.pullback_extreme = MathMin(machine.pullback_extreme, mid);
   else
      machine.pullback_extreme = MathMax(machine.pullback_extreme, mid);

   bool beyond_extreme = machine.direction > 0 ? mid > machine.burst_extreme : mid < machine.burst_extreme;
   bool same_direction_update = machine.direction > 0 ? mid > machine.last_mid : mid < machine.last_mid;
   if(beyond_extreme && same_direction_update)
      ++machine.reacceleration_ticks;
   else if(!beyond_extreme)
      machine.reacceleration_ticks = 0;
   machine.last_mid = mid;

   if(machine.reacceleration_ticks >= reacceleration_confirm_ticks)
      return TS_ACTION_REACCELERATION;
   if(now_msc - machine.burst_end_msc >= pullback_wait_ms)
     {
      machine.state = TS_EXPIRED;
      return TS_ACTION_NO_REACCELERATION;
     }
   return TS_ACTION_NONE;
  }

bool TSShockConditionsPass(const double move,
                           const double percentile_threshold,
                           const double robust_z,
                           const double efficiency,
                           const double move_spread_ratio,
                           const double tick_intensity_ratio,
                           const double spread_ratio,
                           const double min_robust_z,
                           const double min_efficiency,
                           const double min_move_spread_ratio,
                           const double min_tick_intensity_ratio,
                           const double max_spread_ratio,
                           string &reason)
  {
   reason = "";
   if(move < percentile_threshold) reason = "shock_percentile_failed";
   else if(robust_z < min_robust_z) reason = "shock_z_failed";
   else if(efficiency < min_efficiency) reason = "efficiency_failed";
   else if(tick_intensity_ratio < min_tick_intensity_ratio) reason = "tick_intensity_failed";
   else if(move_spread_ratio < min_move_spread_ratio) reason = "move_spread_failed";
   else if(spread_ratio > max_spread_ratio) reason = "spread_too_wide";
   return reason == "";
  }

bool TSRiskConditionsPass(const double spread,
                          const double risk_distance,
                          const double burst_range,
                          string &reason)
  {
   reason = "";
   if(risk_distance <= 0.0 || burst_range <= 0.0)
      reason = "invalid_risk_distance";
   else if(spread / risk_distance > 0.20)
      reason = "cost_too_large_vs_risk";
   else if(risk_distance / burst_range > 0.45)
      reason = "stop_too_wide_vs_burst";
   return reason == "";
  }

int TSSelectHighestScore(const double &scores[],const int count)
  {
   if(count <= 0)
      return -1;
   int best = 0;
   for(int i = 1; i < count; ++i)
      if(scores[i] > scores[best])
         best = i;
   return best;
  }

bool TSHardTimeExpired(const long entry_msc,const long now_msc,const int max_hold_seconds)
  {
   return entry_msc > 0 && max_hold_seconds > 0 && now_msc - entry_msc >= (long)max_hold_seconds * 1000;
  }

bool TSCooldownComplete(const long now_msc,const long cooldown_until_msc)
  {
   return now_msc >= cooldown_until_msc;
  }

bool TSDailyLossBlocked(const double daily_result_r,const double daily_loss_limit_r)
  {
   return daily_loss_limit_r > 0.0 && daily_result_r <= -daily_loss_limit_r;
  }

bool TSResolveShadowExit(const int direction,
                         const double entry,
                         const double sl,
                         const double tp,
                         const double exit_price,
                         const long entry_msc,
                         const long now_msc,
                         const int max_hold_seconds,
                         double &result_r,
                         string &reason)
  {
   double risk = direction > 0 ? entry - sl : sl - entry;
   if(risk <= 0.0)
      return false;
   bool stop_hit = direction > 0 ? exit_price <= sl : exit_price >= sl;
   bool target_hit = direction > 0 ? exit_price >= tp : exit_price <= tp;
   if(stop_hit)
     {
      result_r = -1.0;
      reason = "SL";
      return true;
     }
   if(target_hit)
     {
      result_r = direction > 0 ? (tp - entry) / risk : (entry - tp) / risk;
      reason = "TP";
      return true;
     }
   if(TSHardTimeExpired(entry_msc, now_msc, max_hold_seconds))
     {
      result_r = direction > 0 ? (exit_price - entry) / risk : (entry - exit_price) / risk;
      reason = "TIME";
      return true;
     }
   return false;
  }

bool TSFixedLogMidReturn(const double newer_mid,
                         const double older_mid,
                         double &result)
  {
   result=0.0;
   if(newer_mid<=0.0 || older_mid<=0.0) return false;
   result=MathLog(newer_mid/older_mid);
   if(!MathIsValidNumber(result))
     {
      result=0.0;
      return false;
     }
   return true;
  }

// Signal and baseline samples must use this same absolute-price definition.
// The signed value is retained only for direction; magnitude is the detector
// measure used by percentile, MAD/Z and Move/Spread.
bool TSFixedMidMove(const double newer_mid,
                    const double older_mid,
                    double &signed_move,
                    double &absolute_move)
  {
   signed_move=0.0;
   absolute_move=0.0;
   if(newer_mid<=0.0 || older_mid<=0.0) return false;
   signed_move=newer_mid-older_mid;
   absolute_move=MathAbs(signed_move);
   if(!MathIsValidNumber(signed_move) || !MathIsValidNumber(absolute_move))
     {
      signed_move=0.0;
      absolute_move=0.0;
      return false;
     }
   return true;
  }

bool TSExactAnchorTime(const long required_msc,const long available_msc)
  {
   return required_msc==available_msc;
  }

bool TSDetectorBoundary(const long boundary_msc,const int detector_window_ms)
  {
   return detector_window_ms>0 && boundary_msc%detector_window_ms==0;
  }

double TSRobustScaleWithNoiseFloor(const double mad_absolute_move,
                                   const double noise_floor_move,
                                   bool &floored)
  {
   double raw_scale=1.4826*MathMax(0.0,mad_absolute_move);
   double noise=MathMax(0.0,noise_floor_move);
   floored=raw_scale<noise;
   return MathMax(raw_scale,noise);
  }

bool TSBarrierBrokerFeasibility(const double risk_distance,
                                const double target_distance,
                                const double broker_min_distance,
                                string &reason)
  {
   reason="";
   if(risk_distance<=0.0 || target_distance<=0.0 ||
      !MathIsValidNumber(risk_distance) || !MathIsValidNumber(target_distance))
      reason="INVALID_RISK_DISTANCE";
   else if(risk_distance+1e-12<MathMax(0.0,broker_min_distance))
      reason="INVALID_BROKER_STOP";
   else if(target_distance+1e-12<MathMax(0.0,broker_min_distance))
      reason="INVALID_BROKER_TARGET";
   return reason=="";
  }

// Policy gates are research labels only.  They must never erase a barrier
// outcome that was broker-feasible at the signal time.
int TSResearchPolicyMask(const double stressed_spread,
                         const double risk_distance,
                         const double known_range)
  {
   int mask=0;
   if(stressed_spread>0.0 && risk_distance>0.0 &&
      stressed_spread/risk_distance<=0.20+1e-9)
      mask|=1;
   if(risk_distance>0.0 && known_range>0.0 &&
      risk_distance/known_range<=0.45+1e-9)
      mask|=2;
   return mask;
  }

bool TSChronologicalKeyLess(const long left_time_msc,
                            const int left_symbol_index,
                            const int left_sequence,
                            const long right_time_msc,
                            const int right_symbol_index,
                            const int right_sequence)
  {
   if(left_time_msc!=right_time_msc) return left_time_msc<right_time_msc;
   if(left_symbol_index!=right_symbol_index) return left_symbol_index<right_symbol_index;
   return left_sequence<right_sequence;
  }

long TSExecutionDueMsc(const long signal_msc,
                       const int requested_delay_ms)
  {
   return signal_msc+(long)MathMax(0,requested_delay_ms);
  }

// A stop is a market-style exit: when the quote gaps beyond the barrier, the
// first tradable side plus adverse exit slippage determines the realised R.
// A target remains limit-like and is filled at its barrier price.
bool TSResolveShadowExitWithGap(const int direction,
                                const double entry,
                                const double sl,
                                const double tp,
                                const double tradable_exit_price,
                                const double adverse_exit_slippage,
                                const long entry_msc,
                                const long now_msc,
                                const int max_hold_seconds,
                                double &fill_price,
                                double &gross_r,
                                double &stop_gap,
                                string &reason)
  {
   fill_price=0.0;
   gross_r=0.0;
   stop_gap=0.0;
   reason="";
   double risk=direction>0?entry-sl:sl-entry;
   if(risk<=0.0 || tradable_exit_price<=0.0) return false;
   bool stop_hit=direction>0?tradable_exit_price<=sl:tradable_exit_price>=sl;
   bool target_hit=direction>0?tradable_exit_price>=tp:tradable_exit_price<=tp;
   if(stop_hit)
     {
      fill_price=direction>0?tradable_exit_price-MathMax(0.0,adverse_exit_slippage):
                             tradable_exit_price+MathMax(0.0,adverse_exit_slippage);
      stop_gap=direction>0?MathMax(0.0,sl-fill_price):MathMax(0.0,fill_price-sl);
      gross_r=direction>0?(fill_price-entry)/risk:(entry-fill_price)/risk;
      reason="SL_GAP";
      return true;
     }
   if(target_hit)
     {
      fill_price=tp;
      gross_r=direction>0?(tp-entry)/risk:(entry-tp)/risk;
      reason="TP_LIMIT";
      return true;
     }
   if(TSHardTimeExpired(entry_msc,now_msc,max_hold_seconds))
     {
      fill_price=tradable_exit_price;
      gross_r=direction>0?(fill_price-entry)/risk:(entry-fill_price)/risk;
      reason="TIME_MARKET";
      return true;
     }
   return false;
  }

#endif
