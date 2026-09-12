#ifndef TICK_SHOCK_MERGE_SEQUENCER_MQH
#define TICK_SHOCK_MERGE_SEQUENCER_MQH

#include "TickShockClusterer.mqh"

struct TickShockMergedTick
  {
   int symbol_index;
   int sequence;
   MqlTick tick;
  };

// Quote freshness and history completeness are deliberately separate clocks.
// last_quote_msc may remain old during a quiet market while read_through_msc
// advances after CopyTicks has causally verified an empty range.
struct TickShockSymbolFrontierState
  {
   long last_quote_msc;
   long read_through_msc;
   long requested_from_msc;
   long requested_to_msc;
   int last_returned_count;
   long returned_ticks;
   long page_count;
   int last_copy_result;
   int last_copy_error;
   bool history_synchronized;
   bool current_read_incomplete;
   bool ever_read_failure;
   long read_failure_count;
   long quiet_range_count;
   long cursor_stall_count;
   long page_limit_count;
   long final_drain_count;
   bool currently_stale;
   bool ever_stale;
   long stale_episode_start_msc;
   long stale_episode_count;
   long max_stale_ms;
   string last_root_cause;
  };

struct TickShockPendingRepository
  {
   TickShockMergedTick items[];
   int next_sequence;
   long max_observed;
   long capacity_hits;
   long last_processed_msc;
   long order_violations;
   long same_msc_groups;
   long same_msc_ticks;
   long max_same_msc_group;
   ENUM_TS_PENDING_STATUS status;
   long dropped_ticks;
   long cursor_stalls;
   int stale_symbol_count;
   int ever_stale_symbol_count;
   long stale_instances;
   long max_frontier_lag_ms;
   bool incomplete_frontier;
   long incomplete_frontier_instances;
   long read_failures;
   long quiet_ranges;
   long copy_pages;
   long final_drains;
   bool validation_invalid;
   string fatal_reason;
  };

void TSResetPendingRepository(TickShockPendingRepository &repository)
  {
   ArrayResize(repository.items,0);
   repository.next_sequence=0;
   repository.max_observed=0;
   repository.capacity_hits=0;
   repository.last_processed_msc=0;
   repository.order_violations=0;
   repository.same_msc_groups=0;
   repository.same_msc_ticks=0;
   repository.max_same_msc_group=0;
   repository.status=TS_PENDING_OK;
   repository.dropped_ticks=0;repository.cursor_stalls=0;repository.stale_symbol_count=0;
   repository.ever_stale_symbol_count=0;repository.stale_instances=0;
   repository.max_frontier_lag_ms=0;repository.incomplete_frontier=false;repository.incomplete_frontier_instances=0;
   repository.read_failures=0;repository.quiet_ranges=0;repository.copy_pages=0;repository.final_drains=0;
   repository.validation_invalid=false;repository.fatal_reason="";
  }

void TSResetSymbolFrontier(TickShockSymbolFrontierState &state)
  {
   ZeroMemory(state);
   state.last_copy_result=0;
   state.last_copy_error=0;
   state.last_root_cause="";
  }

void TSFrontierBeginReadCycle(TickShockSymbolFrontierState &state,const long from_msc,const long to_msc,
                              const bool synchronized,const bool final_drain=false)
  {
   state.requested_from_msc=from_msc;
   state.requested_to_msc=MathMax(from_msc,to_msc);
   state.history_synchronized=synchronized;
   state.last_returned_count=0;
   state.last_copy_result=0;
   state.last_copy_error=0;
   state.current_read_incomplete=!synchronized;
   if(final_drain) ++state.final_drain_count;
   if(!synchronized)
     {
      state.ever_read_failure=true;++state.read_failure_count;
      state.last_root_cause="HISTORY_NOT_SYNCHRONIZED";
     }
  }

bool TSFrontierObserveCopyPage(TickShockSymbolFrontierState &state,const int copied_count,const int requested_count,
                               const int copy_error,const long last_quote_msc,const bool exhausted)
  {
   state.last_copy_result=copied_count;state.last_copy_error=copy_error;
   state.last_returned_count=copied_count; ++state.page_count;
   if(copied_count>0) state.returned_ticks+=copied_count;
   if(last_quote_msc>0) state.last_quote_msc=MathMax(state.last_quote_msc,last_quote_msc);
   if(copied_count<0 || copy_error!=0)
     {
      state.current_read_incomplete=true;state.ever_read_failure=true;++state.read_failure_count;
      state.last_root_cause="COPY_TICKS_FAILED";return false;
     }
   if(!state.history_synchronized)
     {
      state.current_read_incomplete=true;return false;
     }
   if(exhausted || (requested_count>0 && copied_count<requested_count))
     {
      if(copied_count==0) ++state.quiet_range_count;
      state.read_through_msc=MathMax(state.read_through_msc,state.requested_to_msc);
      state.current_read_incomplete=false;state.last_root_cause="";return true;
     }
   // A full page proves completeness only up to (but not including) the last
   // millisecond. Equality remains pending until the next page resolves all
   // same-millisecond quotes.
   if(state.last_quote_msc>0)
      state.read_through_msc=MathMax(state.read_through_msc,state.last_quote_msc);
   return true;
  }

void TSFrontierObserveCursorStall(TickShockSymbolFrontierState &state)
  {
   ++state.cursor_stall_count;state.current_read_incomplete=true;state.ever_read_failure=true;
   ++state.read_failure_count;state.last_root_cause="SAME_MSC_PAGE_SATURATED";
  }

void TSFrontierObservePageLimit(TickShockSymbolFrontierState &state)
  {
   ++state.page_limit_count;state.current_read_incomplete=true;state.ever_read_failure=true;
   ++state.read_failure_count;state.last_root_cause="COPY_PAGE_LIMIT_REACHED";
  }

bool TSMergeAppend(TickShockPendingRepository &repository,const int symbol_index,const MqlTick &tick,const int capacity)
  {
   int size=ArraySize(repository.items);
   if(size>=capacity)
     {++repository.capacity_hits;++repository.dropped_ticks;repository.status=TS_PENDING_TICK_CAPACITY_EXHAUSTED;repository.validation_invalid=true;repository.fatal_reason="PENDING_TICK_CAPACITY_EXHAUSTED";return false;}
   ArrayResize(repository.items,size+1,capacity);
   repository.items[size].symbol_index=symbol_index;
   repository.items[size].sequence=repository.next_sequence++;
   repository.items[size].tick=tick;
   repository.max_observed=MathMax(repository.max_observed,(long)(size+1));
   return true;
  }

string TSPendingStatusName(const ENUM_TS_PENDING_STATUS status)
  {
   if(status==TS_PENDING_TICK_CAPACITY_EXHAUSTED) return "PENDING_TICK_CAPACITY_EXHAUSTED";
   if(status==TS_PENDING_CURSOR_STALLED) return "SAME_MSC_PAGE_SATURATED";
   if(status==TS_PENDING_INCOMPLETE_FRONTIER) return "INCOMPLETE_GLOBAL_FRONTIER";
   return "OK";
  }

bool TSObserveCopyPageProgress(TickShockPendingRepository &repository,
                               const long before_time,const int before_count,
                               const long after_time,const int after_count,
                               const int copied_count,const int requested_count,
                               TickShockCursorProgress &result)
  {
   ZeroMemory(result);result.terminated=true;result.status=TS_PENDING_OK;
   if(copied_count>=requested_count && after_time==before_time && after_count==before_count)
     {
      ++repository.cursor_stalls;repository.status=TS_PENDING_CURSOR_STALLED;
      repository.validation_invalid=true;repository.fatal_reason="SAME_MSC_PAGE_SATURATED";
      result.status=TS_PENDING_CURSOR_STALLED;result.validation_invalid=true;return false;
     }
   return true;
  }

bool TSMergeObserveFrontier(TickShockPendingRepository &repository,const long now_msc,const long &frontiers[],const long stale_after_ms)
  {
   repository.stale_symbol_count=0;repository.max_frontier_lag_ms=0;repository.incomplete_frontier=false;
   for(int i=0;i<ArraySize(frontiers);++i)
     {
      if(frontiers[i]<=0){++repository.stale_symbol_count;repository.incomplete_frontier=true;continue;}
      long lag=MathMax((long)0,now_msc-frontiers[i]);repository.max_frontier_lag_ms=MathMax(repository.max_frontier_lag_ms,lag);
      if(lag>stale_after_ms) ++repository.stale_symbol_count;
     }
   if(repository.stale_symbol_count>0 || repository.incomplete_frontier)
     {repository.status=TS_PENDING_INCOMPLETE_FRONTIER;repository.validation_invalid=true;repository.fatal_reason="INCOMPLETE_GLOBAL_FRONTIER";return false;}
   return true;
  }

bool TSMergeObserveReadThroughFrontier(TickShockPendingRepository &repository,const long now_msc,
                                       TickShockSymbolFrontierState &states[],const long stale_after_ms,long &watermark)
  {
   repository.stale_symbol_count=0;repository.ever_stale_symbol_count=0;
   repository.max_frontier_lag_ms=0;repository.incomplete_frontier=false;watermark=0;
   repository.read_failures=0;repository.quiet_ranges=0;repository.copy_pages=0;repository.final_drains=0;
   for(int i=0;i<ArraySize(states);++i)
     {
      long quote_lag=states[i].last_quote_msc>0?MathMax((long)0,now_msc-states[i].last_quote_msc):now_msc;
      bool stale=states[i].last_quote_msc<=0 || quote_lag>stale_after_ms;
      if(stale)
        {
         ++repository.stale_symbol_count;
         if(!states[i].currently_stale)
           {states[i].currently_stale=true;states[i].ever_stale=true;states[i].stale_episode_start_msc=now_msc;++states[i].stale_episode_count;}
         states[i].max_stale_ms=MathMax(states[i].max_stale_ms,quote_lag);
        }
      else
        {states[i].currently_stale=false;states[i].stale_episode_start_msc=0;}
      if(states[i].ever_stale) ++repository.ever_stale_symbol_count;
      repository.stale_instances+=stale?1:0;
      repository.max_frontier_lag_ms=MathMax(repository.max_frontier_lag_ms,quote_lag);
      repository.read_failures+=states[i].read_failure_count;
      repository.quiet_ranges+=states[i].quiet_range_count;
      repository.copy_pages+=states[i].page_count;
      repository.final_drains+=states[i].final_drain_count;
      if(states[i].read_through_msc<=0 || states[i].current_read_incomplete)
        {
         repository.incomplete_frontier=true;
         if(repository.fatal_reason=="" && states[i].last_root_cause!="") repository.fatal_reason=states[i].last_root_cause;
        }
      else if(watermark==0 || states[i].read_through_msc<watermark)
         watermark=states[i].read_through_msc;
     }
   if(repository.incomplete_frontier)
     {
      ++repository.incomplete_frontier_instances;repository.status=TS_PENDING_INCOMPLETE_FRONTIER;
      repository.validation_invalid=true;
      if(repository.fatal_reason=="") repository.fatal_reason="INCOMPLETE_GLOBAL_FRONTIER";
      return false;
     }
   if(repository.status==TS_PENDING_INCOMPLETE_FRONTIER) repository.status=TS_PENDING_OK;
   // CopyTicks can fail transiently while the dispatcher is running. No tick is
   // released while a range is incomplete. If a later read causally proves the
   // same range for every symbol, retain the failed attempt as a diagnostic but
   // clear only the recoverable gap latch. Capacity loss, cursor stalls and page
   // limits remain permanently invalid.
   bool permanent_loss=repository.capacity_hits>0 || repository.dropped_ticks>0 || repository.cursor_stalls>0;
   string cause=repository.fatal_reason;
   bool recoverable_gap=cause=="COPY_TICKS_FAILED" || cause=="HISTORY_NOT_SYNCHRONIZED" || cause=="INCOMPLETE_GLOBAL_FRONTIER";
   if(repository.validation_invalid && recoverable_gap && !permanent_loss)
     {repository.validation_invalid=false;repository.fatal_reason="";}
   return true;
  }

string TSValidationStatus(const bool invalid) { return invalid?"VALIDATION_INVALID":"VALIDATED"; }

bool TSMergeLess(const TickShockMergedTick &left,const TickShockMergedTick &right)
  {
   return TSChronologicalKeyLess((long)left.tick.time_msc,left.symbol_index,left.sequence,
                                 (long)right.tick.time_msc,right.symbol_index,right.sequence);
  }

void TSMergeSort(TickShockMergedTick &values[],int left,int right)
  {
   int i=left,j=right;
   TickShockMergedTick pivot=values[(left+right)/2];
   while(i<=j)
     {
      while(TSMergeLess(values[i],pivot)) ++i;
      while(TSMergeLess(pivot,values[j])) --j;
      if(i<=j)
        {
         TickShockMergedTick temp=values[i];values[i]=values[j];values[j]=temp;
         ++i;--j;
        }
     }
   if(left<j) TSMergeSort(values,left,j);
   if(i<right) TSMergeSort(values,i,right);
  }

void TSMergeSortPending(TickShockPendingRepository &repository)
  {
   int count=ArraySize(repository.items);
   if(count>1) TSMergeSort(repository.items,0,count-1);
  }

int TSMergeReleasableCount(const TickShockPendingRepository &repository,const long watermark)
  {
   if(watermark<=0) return 0;
   int count=ArraySize(repository.items),released=0;
   while(released<count && (long)repository.items[released].tick.time_msc<watermark) ++released;
   while(released>0 && released<count &&
         repository.items[released-1].tick.time_msc==repository.items[released].tick.time_msc &&
         repository.items[released-1].symbol_index==repository.items[released].symbol_index) --released;
   return released;
  }

int TSMergeFinalReleasableCount(const TickShockPendingRepository &repository,const long watermark)
  {
   if(watermark<=0) return 0;
   int count=ArraySize(repository.items),released=0;
   while(released<count && (long)repository.items[released].tick.time_msc<=watermark) ++released;
   return released;
  }

void TSMergeObserveGroup(TickShockPendingRepository &repository,const int group_size)
  {
   if(group_size<=1) return;
   ++repository.same_msc_groups;
   repository.same_msc_ticks+=group_size;
   repository.max_same_msc_group=MathMax(repository.max_same_msc_group,(long)group_size);
  }

void TSMergeObserveProcessed(TickShockPendingRepository &repository,const long tick_msc)
  {
   if(repository.last_processed_msc>0 && tick_msc<repository.last_processed_msc) ++repository.order_violations;
   repository.last_processed_msc=MathMax(repository.last_processed_msc,tick_msc);
  }

void TSMergeRemovePrefix(TickShockPendingRepository &repository,const int released)
  {
   int count=ArraySize(repository.items);
   if(released<=0 || released>count) return;
   int remaining=count-released;
   for(int i=0;i<remaining;++i) repository.items[i]=repository.items[released+i];
   ArrayResize(repository.items,remaining);
  }

#endif
