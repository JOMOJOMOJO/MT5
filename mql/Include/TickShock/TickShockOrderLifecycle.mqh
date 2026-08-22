#ifndef TICK_SHOCK_ORDER_LIFECYCLE_MQH
#define TICK_SHOCK_ORDER_LIFECYCLE_MQH

#include "TickShockTypes.mqh"

void TSResetOrderFillState(TickShockOrderFillState &state,const double requested_volume)
  {
   ZeroMemory(state);
   state.state=TS_ORDER_ENTRY_PENDING;
   state.requested_volume=MathMax(0.0,requested_volume);
   state.remaining_volume=state.requested_volume;
  }

bool TSApplyEntryDeal(TickShockOrderFillState &state,const double deal_volume,const double deal_price)
  {
   if(state.entry_resolved || state.requested_volume<=0.0 || deal_volume<=0.0 || deal_price<=0.0)
      return false;
   double epsilon=MathMax(1e-12,state.requested_volume*1e-9);
   if(deal_volume-state.remaining_volume>epsilon)
      return false;
   double accepted=MathMin(deal_volume,state.remaining_volume);
   state.filled_volume+=accepted;
   state.weighted_fill_value+=accepted*deal_price;
   ++state.deal_count;
   state.remaining_volume=MathMax(0.0,state.requested_volume-state.filled_volume-state.cancelled_volume);
   if(state.filled_volume>epsilon)
      state.average_fill=state.weighted_fill_value/state.filled_volume;
   if(state.remaining_volume<=epsilon)
     {
      state.remaining_volume=0.0;
      state.entry_resolved=true;
      state.state=state.filled_volume>epsilon?TS_ORDER_WAIT_EXIT:TS_ORDER_ENTRY_CANCELLED;
     }
   return true;
  }

bool TSResolveEntryRemainderCancel(TickShockOrderFillState &state,const double cancelled_volume)
  {
   if(state.entry_resolved || state.requested_volume<=0.0 || cancelled_volume<0.0)
      return false;
   double epsilon=MathMax(1e-12,state.requested_volume*1e-9);
   if(MathAbs(cancelled_volume-state.remaining_volume)>epsilon)
      return false;
   state.cancelled_volume+=state.remaining_volume;
   state.remaining_volume=0.0;
   state.entry_resolved=true;
   state.state=state.filled_volume>epsilon?TS_ORDER_WAIT_EXIT:TS_ORDER_ENTRY_CANCELLED;
   return true;
  }

#endif
