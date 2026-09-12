#ifndef TICK_SHOCK_CORE_STATE_MACHINE_MQH
#define TICK_SHOCK_CORE_STATE_MACHINE_MQH

#include "TickShockConfig.mqh"

void TSReset(TickShockMachine &machine)
  {
   machine.state=TS_SCANNING;
   machine.direction=0;
   machine.detection_msc=0;
   machine.burst_end_msc=0;
   machine.last_extreme_msc=0;
   machine.pullback_msc=0;
   machine.cooldown_until_msc=0;
   machine.burst_start=0.0;
   machine.burst_extreme=0.0;
   machine.burst_range=0.0;
   machine.pullback_extreme=0.0;
   machine.max_retracement_pct=0.0;
   machine.last_mid=0.0;
   machine.reacceleration_ticks=0;
   machine.too_deep_seen=false;
  }

void TSStartBurst(TickShockMachine &machine,const int direction,const long detection_msc,const double start_mid,const double current_mid)
  {
   TSReset(machine);
   machine.state=TS_BURST_ACTIVE;
   machine.direction=direction;
   machine.detection_msc=detection_msc;
   machine.last_extreme_msc=detection_msc;
   machine.burst_start=start_mid;
   machine.burst_extreme=current_mid;
   machine.last_mid=current_mid;
  }

double TSRetracementPct(const TickShockMachine &machine,const double current_mid)
  {
   if(machine.burst_range<=0.0) return 0.0;
   double retracement=machine.direction>0?
                      (machine.burst_extreme-current_mid)/machine.burst_range:
                      (current_mid-machine.burst_extreme)/machine.burst_range;
   return retracement*100.0;
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
   if(machine.state==TS_BURST_ACTIVE)
     {
      bool new_extreme=(machine.direction>0 && mid>machine.burst_extreme) ||
                       (machine.direction<0 && mid<machine.burst_extreme);
      if(new_extreme)
        {
         machine.burst_extreme=mid;
         machine.last_extreme_msc=now_msc;
        }
      machine.last_mid=mid;
      if(now_msc-machine.last_extreme_msc>=burst_quiet_ms ||
         now_msc-machine.detection_msc>=burst_max_ms)
        {
         machine.burst_range=MathAbs(machine.burst_extreme-machine.burst_start);
         machine.burst_end_msc=now_msc;
         machine.state=TS_WAIT_PULLBACK;
         return TS_ACTION_BURST_FROZEN;
        }
      return TS_ACTION_NONE;
     }
   if(machine.state!=TS_WAIT_PULLBACK && machine.state!=TS_WAIT_REACCELERATION)
      return TS_ACTION_NONE;
   double retracement_pct=TSRetracementPct(machine,mid);
   machine.max_retracement_pct=MathMax(machine.max_retracement_pct,retracement_pct);
   if(retracement_pct>=continuation_invalid_pct)
     {
      machine.state=TS_EXPIRED;
      machine.last_mid=mid;
      return TS_ACTION_CONTINUATION_INVALIDATED;
     }
   if(machine.state==TS_WAIT_PULLBACK)
     {
      if(retracement_pct>pullback_max_pct) machine.too_deep_seen=true;
      if(retracement_pct>=pullback_min_pct && retracement_pct<=pullback_max_pct)
        {
         machine.pullback_extreme=mid;
         machine.pullback_msc=now_msc;
         machine.state=TS_WAIT_REACCELERATION;
         machine.reacceleration_ticks=0;
         machine.last_mid=mid;
         return TS_ACTION_PULLBACK_VALID;
        }
      if(now_msc-machine.burst_end_msc>=pullback_wait_ms)
        {
         machine.state=TS_EXPIRED;
         machine.last_mid=mid;
         return TS_ACTION_PULLBACK_TIMEOUT;
        }
      machine.last_mid=mid;
      return TS_ACTION_NONE;
     }
   if(machine.direction>0) machine.pullback_extreme=MathMin(machine.pullback_extreme,mid);
   else machine.pullback_extreme=MathMax(machine.pullback_extreme,mid);
   bool beyond_extreme=machine.direction>0?mid>machine.burst_extreme:mid<machine.burst_extreme;
   bool same_direction_update=machine.direction>0?mid>machine.last_mid:mid<machine.last_mid;
   if(beyond_extreme && same_direction_update) ++machine.reacceleration_ticks;
   else if(!beyond_extreme) machine.reacceleration_ticks=0;
   machine.last_mid=mid;
   if(machine.reacceleration_ticks>=reacceleration_confirm_ticks) return TS_ACTION_REACCELERATION;
   if(now_msc-machine.burst_end_msc>=pullback_wait_ms)
     {
      machine.state=TS_EXPIRED;
      return TS_ACTION_NO_REACCELERATION;
     }
   return TS_ACTION_NONE;
  }

bool TSCooldownComplete(const long now_msc,const long cooldown_until_msc)
  {
   return now_msc>=cooldown_until_msc;
  }

bool TSDailyLossBlocked(const double daily_result_r,const double daily_loss_limit_r)
  {
   return daily_loss_limit_r>0.0 && daily_result_r<=-daily_loss_limit_r;
  }

#endif
