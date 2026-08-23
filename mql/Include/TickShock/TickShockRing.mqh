#ifndef TICK_SHOCK_RING_MQH
#define TICK_SHOCK_RING_MQH

struct TickShockRingState
  {
   int head;
   int count;
   int capacity;
  };

void TSRingReset(TickShockRingState &state,const int capacity)
  {
   state.head=0;
   state.count=0;
   state.capacity=MathMax(0,capacity);
  }

int TSRingOldestIndex(const TickShockRingState &state)
  {
   if(state.count<=0 || state.capacity<=0) return -1;
   int index=state.head-state.count;
   while(index<0) index+=state.capacity;
   return index;
  }

int TSRingReserveWrite(TickShockRingState &state)
  {
   if(state.capacity<=0) return -1;
   int index=state.head;
   state.head=(state.head+1)%state.capacity;
   if(state.count<state.capacity) ++state.count;
   return index;
  }

bool TSRingDropOldest(TickShockRingState &state)
  {
   if(state.count<=0) return false;
   --state.count;
   return true;
  }

int TSRingIndexFromNewest(const TickShockRingState &state,const int offset)
  {
   if(offset<0 || offset>=state.count || state.capacity<=0) return -1;
   int index=state.head-1-offset;
   while(index<0) index+=state.capacity;
   return index;
  }

#endif
