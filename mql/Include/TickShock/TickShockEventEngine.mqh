#ifndef TICK_SHOCK_EVENT_ENGINE_MQH
#define TICK_SHOCK_EVENT_ENGINE_MQH

#include "TickShockClusterer.mqh"

struct TickShockEventKey
  {
   int symbol_index;
   int detector_window_ms;
   long detection_msc;
  };

struct TickShockSymbolClusterClock
  {
   long current_id;
   long start_msc;
  };

struct TickShockEventRegistration
  {
   bool accepted;
   bool duplicate;
   int slot;
   long event_sequence;
   long symbol_cluster_id;
   long market_cluster_id;
   bool symbol_overlap;
   bool market_overlap;
  };

struct TickShockEventEngineContext
  {
   int slot_capacity;
   bool slot_active[];
   TickShockEventKey slot_keys[];
   long event_sequence;
   long symbol_cluster_sequence;
   long symbol_overlap_events;
   TSResearchClusterClock market_cluster_clock;
   long market_overlap_events;
   long duplicate_events;
   long event_rows;
  };

void TSResetSymbolClusterClock(TickShockSymbolClusterClock &clock)
  {
   ZeroMemory(clock);
  }

void TSResetEventEngine(TickShockEventEngineContext &context,const int slot_capacity)
  {
   context.slot_capacity=MathMax(0,slot_capacity);
   ArrayResize(context.slot_active,context.slot_capacity);
   ArrayResize(context.slot_keys,context.slot_capacity);
   ArrayInitialize(context.slot_active,false);
   context.event_sequence=0;
   context.symbol_cluster_sequence=0;
   context.symbol_overlap_events=0;
   TSResetResearchClusterClock(context.market_cluster_clock);
   context.market_overlap_events=0;
   context.duplicate_events=0;
   context.event_rows=0;
  }

bool TSEventKeyEqual(const TickShockEventKey &left,const TickShockEventKey &right)
  {
   return left.symbol_index==right.symbol_index &&
          left.detector_window_ms==right.detector_window_ms &&
          left.detection_msc==right.detection_msc;
  }

void TSReleaseEventSlot(TickShockEventEngineContext &context,const int slot)
  {
   if(slot<0 || slot>=context.slot_capacity) return;
   context.slot_active[slot]=false;
   ZeroMemory(context.slot_keys[slot]);
  }

bool TSRegisterResearchEvent(TickShockEventEngineContext &context,
                             TickShockSymbolClusterClock &symbol_clock,
                             const TickShockEventKey &key,
                             const int cluster_window_ms,
                             TickShockEventRegistration &registration)
  {
   ZeroMemory(registration);
   registration.slot=-1;
   if(key.symbol_index<0 || key.detector_window_ms<=0 || key.detection_msc<=0) return false;
   for(int i=0;i<context.slot_capacity;++i)
      if(context.slot_active[i] && TSEventKeyEqual(context.slot_keys[i],key))
        {
         ++context.duplicate_events;
         registration.duplicate=true;
         return false;
        }
   for(int i=0;i<context.slot_capacity;++i)
      if(!context.slot_active[i]) {registration.slot=i;break;}
   if(registration.slot<0) return false;
   context.slot_active[registration.slot]=true;
   context.slot_keys[registration.slot]=key;
   registration.event_sequence=++context.event_sequence;
   if(symbol_clock.start_msc>0 && key.detection_msc>=symbol_clock.start_msc &&
      key.detection_msc-symbol_clock.start_msc<=(long)cluster_window_ms)
     {
      registration.symbol_cluster_id=symbol_clock.current_id;
      registration.symbol_overlap=true;
      ++context.symbol_overlap_events;
     }
   else
     {
      registration.symbol_cluster_id=++context.symbol_cluster_sequence;
      symbol_clock.current_id=registration.symbol_cluster_id;
      symbol_clock.start_msc=key.detection_msc;
     }
   registration.market_cluster_id=TSAssignResearchMarketCluster(context.market_cluster_clock,key.detection_msc,
                                                                 cluster_window_ms,registration.market_overlap);
   if(registration.market_overlap) ++context.market_overlap_events;
   registration.accepted=true;
   return true;
  }

void TSRecordEventRow(TickShockEventEngineContext &context)
  {
   ++context.event_rows;
  }

#endif
