#ifndef TICK_SHOCK_SCENARIO_ENGINE_MQH
#define TICK_SHOCK_SCENARIO_ENGINE_MQH

#include "TickShockExecutionModel.mqh"

struct TickShockExecutionRequest
  {
   TSResearchSignalClock signal_clock;
   TSResearchEntryClock prior_entry_clock;
   ENUM_TS_RESEARCH_EXECUTION_MODE mode;
   int direction;
   int requested_delay_ms;
   int submit_latency_ms;
   TickShockQuote quote;
   double spread_multiplier;
   double stop_multiple;
   double entry_slippage_ticks;
   double tick_size;
   int digits;
   double stops_distance;
   double freeze_distance;
   double requested_rr;
   double known_range;
  };

void TSResetExecutionResult(TickShockExecutionResult &result)
  {
   ZeroMemory(result);
   result.status=TS_SCENARIO_PENDING_ENTRY_QUOTE;
   result.pending=true;
   TSResetResearchEntryClock(result.entry_clock);
  }

ENUM_TS_SCENARIO_STATUS TSScenarioStatusFromFeasibility(const string reason)
  {
   if(reason=="INVALID_BROKER_STOP") return TS_SCENARIO_INVALID_BROKER_STOP;
   if(reason=="INVALID_PRICE") return TS_SCENARIO_INVALID_PRICE;
   if(reason=="INVALID_RISK_DISTANCE") return TS_SCENARIO_INVALID_RISK_DISTANCE;
   return TS_SCENARIO_INVALID_BROKER_TARGET;
  }

bool TSBuildScenarioEntry(const TickShockExecutionRequest &request,TickShockExecutionResult &result)
  {
   TSResetExecutionResult(result);
   result.entry_clock=request.prior_entry_clock;
   if(request.quote.bid<=0.0 || request.quote.ask<=request.quote.bid || !request.quote.real_tick)
     {
      result.status=TS_SCENARIO_INVALID_STALE_QUOTE;
      result.pending=false;result.done=true;
      return false;
     }
   if(!TSResearchTryEntryClock(request.signal_clock,request.mode,request.requested_delay_ms,
                               request.submit_latency_ms,request.quote.time_msc,result.entry_clock)) return false;
   result.base_spread=request.quote.ask-request.quote.bid;
   result.stressed_spread=result.base_spread*request.spread_multiplier;
   if(result.stressed_spread<=0.0)
     {
      result.status=TS_SCENARIO_INVALID_SPREAD;
      result.pending=false;result.done=true;
      return false;
     }
   result.stressed_bid=request.quote.mid-result.stressed_spread*0.5;
   result.stressed_ask=request.quote.mid+result.stressed_spread*0.5;
   double slip=MathMax(0.0,request.entry_slippage_ticks)*request.tick_size;
   double raw_entry=request.direction>0?result.stressed_ask+slip:result.stressed_bid-slip;
   result.entry=TSRoundEntryAdverse(request.direction,raw_entry,request.tick_size,request.digits);
   result.requested_risk=MathCeil(request.stop_multiple*result.base_spread/request.tick_size-1e-10)*request.tick_size;
   double raw_sl=request.direction>0?result.entry-result.requested_risk:result.entry+result.requested_risk;
   result.sl=TSRoundStopOutward(request.direction,raw_sl,request.tick_size,request.digits);
   result.risk=MathAbs(result.entry-result.sl);
   result.stops_distance=request.stops_distance;
   result.freeze_distance=request.freeze_distance;
   result.requested_rr=request.requested_rr;
   string feasibility_reason="";
   if(result.entry<=0.0 || result.sl<=0.0 ||
      !TSBuildResearchTarget(request.direction,result.entry,result.risk,request.requested_rr,
                             request.tick_size,request.digits,result.tp,result.realized_rr) ||
      !TSProtectiveOrderDistanceFeasible(request.direction,result.stressed_bid,result.stressed_ask,
                                         result.sl,result.tp,result.stops_distance,feasibility_reason))
     {
      result.status=TSScenarioStatusFromFeasibility(feasibility_reason);
      result.pending=false;result.done=true;
      return false;
     }
   result.freeze_clear=TSProtectiveFreezeDistanceClear(request.direction,result.stressed_bid,result.stressed_ask,
                                                       result.sl,result.tp,result.freeze_distance);
   result.policy_mask=TSResearchPolicyMask(result.stressed_spread,result.risk,request.known_range);
   result.status=TS_SCENARIO_ACTIVE;
   result.pending=false;result.active=true;result.done=false;
   return true;
  }

#endif
