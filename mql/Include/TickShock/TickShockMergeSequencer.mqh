#ifndef TICK_SHOCK_MERGE_SEQUENCER_MQH
#define TICK_SHOCK_MERGE_SEQUENCER_MQH

#include "TickShockClusterer.mqh"

struct TickShockMergedTick
  {
   int symbol_index;
   int sequence;
   MqlTick tick;
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
  }

bool TSMergeAppend(TickShockPendingRepository &repository,const int symbol_index,const MqlTick &tick,const int capacity)
  {
   int size=ArraySize(repository.items);
   if(size>=capacity) {++repository.capacity_hits;return false;}
   ArrayResize(repository.items,size+1,capacity);
   repository.items[size].symbol_index=symbol_index;
   repository.items[size].sequence=repository.next_sequence++;
   repository.items[size].tick=tick;
   repository.max_observed=MathMax(repository.max_observed,(long)(size+1));
   return true;
  }

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
