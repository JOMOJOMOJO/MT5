#ifndef TICK_SHOCK_EXECUTION_MODEL_MQH
#define TICK_SHOCK_EXECUTION_MODEL_MQH

#include "TickShockConfig.mqh"
#include "TickShockStateMachine.mqh"

void TSResetResearchSignalClock(TSResearchSignalClock &clock)
  {
   clock.registered=false;
   clock.direction=0;
   clock.event_msc=0;
   clock.processing_msc=0;
  }

void TSResetResearchEntryClock(TSResearchEntryClock &clock)
  {
   clock.filled=false;
   clock.eligible_msc=0;
   clock.quote_msc=0;
  }

bool TSRegisterResearchSignal(TSResearchSignalClock &clock,
                              const int direction,
                              const long signal_event_msc,
                              const long signal_processing_msc)
  {
   if(clock.registered || direction==0 || signal_event_msc<=0 || signal_processing_msc<=0) return false;
   clock.registered=true;
   clock.direction=direction;
   clock.event_msc=signal_event_msc;
   clock.processing_msc=signal_processing_msc;
   return true;
  }

long TSResearchEntryEligibleMsc(const ENUM_TS_RESEARCH_EXECUTION_MODE mode,
                                const long signal_event_msc,
                                const long signal_processing_msc,
                                const int requested_delay_ms,
                                const int submit_latency_ms)
  {
   long event_due=signal_event_msc+(long)MathMax(0,requested_delay_ms);
   if(mode==IDEAL_EVENT_STUDY) return event_due;
   long processing_due=signal_processing_msc+(long)MathMax(0,submit_latency_ms);
   return MathMax(event_due,processing_due);
  }

bool TSResearchTryEntryClock(const TSResearchSignalClock &signal,
                             const ENUM_TS_RESEARCH_EXECUTION_MODE mode,
                             const int requested_delay_ms,
                             const int submit_latency_ms,
                             const long real_quote_msc,
                             TSResearchEntryClock &entry)
  {
   if(!signal.registered || entry.filled || real_quote_msc<=signal.event_msc) return false;
   entry.eligible_msc=TSResearchEntryEligibleMsc(mode,signal.event_msc,signal.processing_msc,
                                                requested_delay_ms,submit_latency_ms);
   if(real_quote_msc<entry.eligible_msc) return false;
   if(mode==REALIZABLE_EA && real_quote_msc<signal.processing_msc) return false;
   entry.filled=true;
   entry.quote_msc=real_quote_msc;
   return true;
  }

bool TSResearchEntryInvariant(const TSResearchSignalClock &signal,
                              const ENUM_TS_RESEARCH_EXECUTION_MODE mode,
                              const int requested_delay_ms,
                              const int submit_latency_ms,
                              const TSResearchEntryClock &entry)
  {
   if(!signal.registered || !entry.filled) return false;
   long eligible=TSResearchEntryEligibleMsc(mode,signal.event_msc,signal.processing_msc,
                                           requested_delay_ms,submit_latency_ms);
   if(entry.eligible_msc!=eligible || entry.quote_msc<eligible || entry.quote_msc<=signal.event_msc) return false;
   if(mode==REALIZABLE_EA && entry.quote_msc<signal.processing_msc) return false;
   return true;
  }

double TSRoundResearchTargetOutward(const int direction,const double raw_target,const double tick_size,const int digits)
  {
   if(direction==0 || raw_target<=0.0 || tick_size<=0.0) return 0.0;
   double units=raw_target/tick_size;
   double value=direction>0?MathCeil(units-1e-10)*tick_size:
                            MathFloor(units+1e-10)*tick_size;
   return NormalizeDouble(value,digits);
  }

double TSRoundEntryAdverse(const int direction,const double raw_entry,const double tick_size,const int digits)
  {
   if(direction==0 || raw_entry<=0.0 || tick_size<=0.0) return 0.0;
   double units=raw_entry/tick_size;
   double value=direction>0?MathCeil(units-1e-10)*tick_size:
                            MathFloor(units+1e-10)*tick_size;
   return NormalizeDouble(value,digits);
  }

double TSRoundStopOutward(const int direction,const double raw_stop,const double tick_size,const int digits)
  {
   if(direction==0 || raw_stop<=0.0 || tick_size<=0.0) return 0.0;
   double units=raw_stop/tick_size;
   double value=direction>0?MathFloor(units+1e-10)*tick_size:
                            MathCeil(units-1e-10)*tick_size;
   return NormalizeDouble(value,digits);
  }

bool TSBuildResearchTarget(const int direction,
                           const double entry,
                           const double risk_distance,
                           const double requested_rr,
                           const double tick_size,
                           const int digits,
                           double &target,
                           double &realized_rr)
  {
   target=0.0;
   realized_rr=0.0;
   if(direction==0 || entry<=0.0 || risk_distance<=0.0 || requested_rr<=0.0) return false;
   double raw=direction>0?entry+risk_distance*requested_rr:
                          entry-risk_distance*requested_rr;
   target=TSRoundResearchTargetOutward(direction,raw,tick_size,digits);
   if(target<=0.0) return false;
   realized_rr=MathAbs(target-entry)/risk_distance;
   return MathIsValidNumber(realized_rr) && realized_rr+1e-9>=requested_rr;
  }

bool TSProtectiveOrderDistanceFeasible(const int direction,
                                       const double current_bid,
                                       const double current_ask,
                                       const double sl,
                                       const double tp,
                                       const double stops_distance,
                                       string &reason)
  {
   reason="";
   if(direction==0 || current_bid<=0.0 || current_ask<=current_bid || sl<=0.0 || tp<=0.0)
      reason="INVALID_PRICE";
   else if(direction>0 && current_bid-sl+1e-12<MathMax(0.0,stops_distance))
      reason="INVALID_BROKER_STOP";
   else if(direction>0 && tp-current_bid+1e-12<MathMax(0.0,stops_distance))
      reason="INVALID_BROKER_TARGET";
   else if(direction<0 && sl-current_ask+1e-12<MathMax(0.0,stops_distance))
      reason="INVALID_BROKER_STOP";
   else if(direction<0 && current_ask-tp+1e-12<MathMax(0.0,stops_distance))
      reason="INVALID_BROKER_TARGET";
   return reason=="";
  }

bool TSProtectiveFreezeDistanceClear(const int direction,
                                     const double current_bid,
                                     const double current_ask,
                                     const double sl,
                                     const double tp,
                                     const double freeze_distance)
  {
   string reason="";
   return TSProtectiveOrderDistanceFeasible(direction,current_bid,current_ask,sl,tp,
                                            MathMax(0.0,freeze_distance),reason);
  }

bool TSRiskConditionsPass(const double spread,const double risk_distance,const double burst_range,string &reason)
  {
   reason="";
   if(risk_distance<=0.0 || burst_range<=0.0) reason="invalid_risk_distance";
   else if(spread/risk_distance>0.20) reason="cost_too_large_vs_risk";
   else if(risk_distance/burst_range>0.45) reason="stop_too_wide_vs_burst";
   return reason=="";
  }

bool TSBarrierBrokerFeasibility(const double risk_distance,const double target_distance,const double broker_min_distance,string &reason)
  {
   reason="";
   if(risk_distance<=0.0 || target_distance<=0.0 ||
      !MathIsValidNumber(risk_distance) || !MathIsValidNumber(target_distance))
      reason="INVALID_RISK_DISTANCE";
   else if(risk_distance+1e-12<MathMax(0.0,broker_min_distance)) reason="INVALID_BROKER_STOP";
   else if(target_distance+1e-12<MathMax(0.0,broker_min_distance)) reason="INVALID_BROKER_TARGET";
   return reason=="";
  }

int TSResearchPolicyMask(const double stressed_spread,const double risk_distance,const double known_range)
  {
   int mask=0;
   if(stressed_spread>0.0 && risk_distance>0.0 && stressed_spread/risk_distance<=0.20+1e-9) mask|=1;
   if(risk_distance>0.0 && known_range>0.0 && risk_distance/known_range<=0.45+1e-9) mask|=2;
   return mask;
  }

int TSSelectHighestScore(const double &scores[],const int count)
  {
   if(count<=0) return -1;
   int best=0;
   for(int i=1;i<count;++i) if(scores[i]>scores[best]) best=i;
   return best;
  }

bool TSHardTimeExpired(const long entry_msc,const long now_msc,const int max_hold_seconds)
  {
   return entry_msc>0 && max_hold_seconds>0 && now_msc-entry_msc>=(long)max_hold_seconds*1000;
  }

long TSExecutionDueMsc(const long signal_msc,const int requested_delay_ms)
  {
   return signal_msc+(long)MathMax(0,requested_delay_ms);
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
   double risk=direction>0?entry-sl:sl-entry;
   if(risk<=0.0) return false;
   bool stop_hit=direction>0?exit_price<=sl:exit_price>=sl;
   bool target_hit=direction>0?exit_price>=tp:exit_price<=tp;
   if(stop_hit){result_r=-1.0;reason="SL";return true;}
   if(target_hit){result_r=direction>0?(tp-entry)/risk:(entry-tp)/risk;reason="TP";return true;}
   if(TSHardTimeExpired(entry_msc,now_msc,max_hold_seconds))
     {
      result_r=direction>0?(exit_price-entry)/risk:(entry-exit_price)/risk;
      reason="TIME";
      return true;
     }
   return false;
  }

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
   fill_price=0.0;gross_r=0.0;stop_gap=0.0;reason="";
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
