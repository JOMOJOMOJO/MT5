#ifndef TICK_SHOCK_ENGINE_MQH
#define TICK_SHOCK_ENGINE_MQH

#include "TickShockDetector.mqh"
#include "TickShockStateMachine.mqh"
#include "TickShockScenarioEngine.mqh"
#include "TickShockClusterer.mqh"
#include "TickShockOrderLifecycle.mqh"

bool TSBuildQuote(const string symbol,
                  const int symbol_index,
                  const int sequence,
                  const long time_msc,
                  const long processing_msc,
                  const double bid,
                  const double ask,
                  const bool real_tick,
                  TickShockQuote &quote)
  {
   ZeroMemory(quote);
   quote.symbol=symbol;
   quote.symbol_index=symbol_index;
   quote.sequence=sequence;
   quote.time_msc=time_msc;
   quote.processing_msc=processing_msc;
   quote.bid=bid;
   quote.ask=ask;
   quote.mid=(bid+ask)*0.5;
   quote.real_tick=real_tick;
   return time_msc>0 && bid>0.0 && ask>bid;
  }

void TSEngineStartBurst(TickShockMachine &machine,
                        const int direction,
                        const long detection_msc,
                        const double start_mid,
                        const double current_mid)
  {
   TSStartBurst(machine,direction,detection_msc,start_mid,current_mid);
  }

ENUM_TS_ACTION TSEngineAdvanceState(TickShockMachine &machine,
                                    const TickShockQuote &quote,
                                    const TickShockConfig &config,
                                    TickShockStateResult &result)
  {
   result.action=TSAdvance(machine,quote.time_msc,quote.mid,
                           config.burst_quiet_ms,config.burst_max_ms,
                           config.pullback_min_pct,config.pullback_max_pct,
                           config.continuation_invalid_pct,config.pullback_wait_ms,
                           config.reacceleration_confirm_ticks);
   result.state=machine.state;
   result.action_msc=quote.time_msc;
   result.burst_range=machine.burst_range;
   result.retracement_pct=machine.max_retracement_pct;
   return result.action;
  }

bool TSEngineEvaluateDetector(const double move,
                              const double percentile_threshold,
                              const double robust_z,
                              const double efficiency,
                              const double move_spread_ratio,
                              const double tick_intensity_ratio,
                              const double spread_ratio,
                              const TickShockConfig &config,
                              TickShockDetectorResult &result)
  {
   TSEvaluateDetectorGates(move,percentile_threshold,robust_z,efficiency,move_spread_ratio,
                          tick_intensity_ratio,spread_ratio,config,result);
   return result.accepted;
  }

bool TSEngineBuildScenarioEntry(const TickShockExecutionRequest &request,TickShockExecutionResult &result)
  {
   return TSBuildScenarioEntry(request,result);
  }

#endif
