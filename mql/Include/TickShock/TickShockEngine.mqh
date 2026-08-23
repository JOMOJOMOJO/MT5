#ifndef TICK_SHOCK_ENGINE_MQH
#define TICK_SHOCK_ENGINE_MQH

#include "TickShockResearchEngine.mqh"
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

bool TSEngineLinearPercentile(double &values[],const int count,const double percentile,TickShockPercentileResult &result)
  {
   return TSLinearPercentile(values,count,percentile,result);
  }

double TSEngineHistogramPercentile(const int &hist[],const int offset,const int max_bin,const int count,const double percentile)
  {
   return TSHistogramPercentile(hist,offset,max_bin,count,percentile);
  }

bool TSEngineRobustStatistics(const double move,const double median_move,const double mad_move,const double noise_floor,TickShockRobustStatistics &result)
  {
   return TSComputeRobustStatistics(move,median_move,mad_move,noise_floor,result);
  }

bool TSEngineDirectionalEfficiency(const double &mids[],const int count,TickShockEfficiencyResult &result)
  {
   return TSComputeDirectionalEfficiency(mids,count,result);
  }

bool TSEngineBaselineReadiness(const int valid_samples,const int minimum_samples,TickShockBaselineReadiness &result)
  {
   return TSEvaluateBaselineReadiness(valid_samples,minimum_samples,result);
  }

bool TSEngineCommissionFromKnownLoss(const bool calculation_success,const double one_lot_profit_or_loss,const double commission_amount,const double gross_r,TickShockCommissionResult &result)
  {
   return TSBuildCommissionResult(calculation_success,one_lot_profit_or_loss,commission_amount,gross_r,result);
  }

bool TSEngineRegisterResearchEvent(TickShockEventEngineContext &context,
                                   TickShockSymbolClusterClock &symbol_clock,
                                   const TickShockEventKey &key,
                                   const int cluster_window_ms,
                                   TickShockEventRegistration &registration)
  {
   return TSRegisterResearchEvent(context,symbol_clock,key,cluster_window_ms,registration);
  }

bool TSEngineBuildScenarioEntry(const TickShockExecutionRequest &request,TickShockExecutionResult &result)
  {
   return TSBuildScenarioEntry(request,result);
  }

#endif
