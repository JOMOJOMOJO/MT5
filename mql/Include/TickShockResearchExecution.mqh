#ifndef TICK_SHOCK_RESEARCH_EXECUTION_MQH
#define TICK_SHOCK_RESEARCH_EXECUTION_MQH

// This file is the shared production path for research execution clocks.
// The EA and deterministic harness must both call these functions.

enum ENUM_TS_RESEARCH_EXECUTION_MODE
  {
   IDEAL_EVENT_STUDY = 0,
   REALIZABLE_EA = 1
  };

struct TSResearchSignalClock
  {
   bool registered;
   int direction;
   long event_msc;
   long processing_msc;
  };

struct TSResearchEntryClock
  {
   bool filled;
   long eligible_msc;
   long quote_msc;
  };

struct TSResearchClusterClock
  {
   long sequence;
   long current_id;
   long start_msc;
   long last_msc;
  };

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

void TSResetResearchClusterClock(TSResearchClusterClock &clock)
  {
   clock.sequence=0;
   clock.current_id=0;
   clock.start_msc=0;
   clock.last_msc=0;
  }

// A signal clock is immutable after first registration.  This prevents the
// failed-shock reversal timestamp from being shifted to the next quote.
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

// Called once for every real quote by the EA.  A quote used to recognize the
// signal can never also be its entry quote, even when requested delay is zero.
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

// Exact window anchors are required.  The helper deliberately has no nearest
// or previous fallback.
bool TSResearchExactLogReturn(const long event_msc,
                              const double event_mid,
                              const int window_ms,
                              const long anchor_msc,
                              const double anchor_mid,
                              double &result)
  {
   result=0.0;
   if(window_ms<=0 || event_mid<=0.0 || anchor_mid<=0.0 ||
      anchor_msc!=event_msc-(long)window_ms) return false;
   result=MathLog(event_mid/anchor_mid);
   if(!MathIsValidNumber(result))
     {
      result=0.0;
      return false;
     }
   return true;
  }

// Global market clusters use the first event in a cluster as their anchor, so
// chained events cannot extend one cluster beyond the configured window.
long TSAssignResearchMarketCluster(TSResearchClusterClock &clock,
                                   const long event_msc,
                                   const int cluster_window_ms,
                                   bool &overlap)
  {
   overlap=false;
   if(event_msc<=0 || cluster_window_ms<0) return 0;
   if(clock.current_id>0 && event_msc>=clock.start_msc &&
      event_msc-clock.start_msc<=(long)cluster_window_ms)
     {
      overlap=true;
      clock.last_msc=event_msc;
      return clock.current_id;
     }
   ++clock.sequence;
   clock.current_id=clock.sequence;
   clock.start_msc=event_msc;
   clock.last_msc=event_msc;
   return clock.current_id;
  }

bool TSResearchFinalQuoteInSameMscGroup(const long current_msc,
                                        const int current_symbol_index,
                                        const bool has_next,
                                        const long next_msc,
                                        const int next_symbol_index)
  {
   if(!has_next) return true;
   return next_msc!=current_msc || next_symbol_index!=current_symbol_index;
  }

double TSRoundResearchTargetOutward(const int direction,
                                    const double raw_target,
                                    const double tick_size,
                                    const int digits)
  {
   if(direction==0 || raw_target<=0.0 || tick_size<=0.0) return 0.0;
   double units=raw_target/tick_size;
   double value=direction>0?MathCeil(units-1e-10)*tick_size:
                            MathFloor(units+1e-10)*tick_size;
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

// StopsLevel is an initial protective-order placement constraint and is
// checked from the executable Bid/Ask side, not from entry price.
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

// FreezeLevel is not treated as the initial StopsLevel.  It is reported as a
// separate modification/close-proximity diagnostic.
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

#endif
