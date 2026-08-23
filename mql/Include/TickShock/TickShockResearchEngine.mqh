#ifndef TICK_SHOCK_RESEARCH_ENGINE_MQH
#define TICK_SHOCK_RESEARCH_ENGINE_MQH

#include "TickShockGrid.mqh"
#include "TickShockMetrics.mqh"
#include "TickShockEventEngine.mqh"
#include "TickShockMergeSequencer.mqh"

struct TickShockDetectorCounters
  {
   long evaluable;
   long raw_candidates;
   long valid_events;
   long gate_true[TS_CORE_GATE_COUNT];
   long gate_cumulative[TS_CORE_GATE_COUNT];
  };

void TSResetDetectorCounters(TickShockDetectorCounters &counters)
  {
   ZeroMemory(counters);
  }

void TSObserveDetectorResult(TickShockDetectorCounters &counters,const TickShockDetectorResult &result)
  {
   ++counters.evaluable;
   bool cumulative=true;
   for(int i=0;i<TS_CORE_GATE_COUNT;++i)
     {
      if(result.gates[i]) ++counters.gate_true[i];
      cumulative=cumulative && result.gates[i];
      if(cumulative) ++counters.gate_cumulative[i];
     }
   if(result.gates[0]) ++counters.raw_candidates;
   if(result.accepted) ++counters.valid_events;
  }

#endif
