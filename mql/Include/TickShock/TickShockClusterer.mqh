#ifndef TICK_SHOCK_CLUSTERER_MQH
#define TICK_SHOCK_CLUSTERER_MQH

#include "TickShockTypes.mqh"

void TSResetResearchClusterClock(TSResearchClusterClock &clock)
  {
   clock.sequence=0;clock.current_id=0;clock.start_msc=0;clock.last_msc=0;
  }

long TSAssignResearchMarketCluster(TSResearchClusterClock &clock,const long event_msc,const int cluster_window_ms,bool &overlap)
  {
   overlap=false;
   if(event_msc<=0 || cluster_window_ms<0) return 0;
   if(clock.current_id>0 && event_msc>=clock.start_msc && event_msc-clock.start_msc<=(long)cluster_window_ms)
     {
      overlap=true;clock.last_msc=event_msc;return clock.current_id;
     }
   ++clock.sequence;
   clock.current_id=clock.sequence;
   clock.start_msc=event_msc;
   clock.last_msc=event_msc;
   return clock.current_id;
  }

void TSAssignMarketCluster(TSResearchClusterClock &clock,const long event_msc,const int cluster_window_ms,TickShockClusterAssignment &assignment)
  {
   assignment.cluster_id=TSAssignResearchMarketCluster(clock,event_msc,cluster_window_ms,assignment.overlap);
  }

bool TSResearchFinalQuoteInSameMscGroup(const long current_msc,const int current_symbol_index,const bool has_next,const long next_msc,const int next_symbol_index)
  {
   if(!has_next) return true;
   return next_msc!=current_msc || next_symbol_index!=current_symbol_index;
  }

bool TSChronologicalKeyLess(const long left_time_msc,const int left_symbol_index,const int left_sequence,
                            const long right_time_msc,const int right_symbol_index,const int right_sequence)
  {
   if(left_time_msc!=right_time_msc) return left_time_msc<right_time_msc;
   if(left_symbol_index!=right_symbol_index) return left_symbol_index<right_symbol_index;
   return left_sequence<right_sequence;
  }

#endif
