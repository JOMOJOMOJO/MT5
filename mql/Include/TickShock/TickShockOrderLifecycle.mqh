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

void TSConfigureOrderIdentity(TickShockOrderFillState &state,const ulong request_ticket,const ulong order_ticket,
                              const ulong position_ticket,const string symbol,const long magic,const int direction)
  {
   state.request_ticket=request_ticket;state.order_ticket=order_ticket;state.position_ticket=position_ticket;
   state.symbol=symbol;state.magic=magic;state.direction=direction;
  }

bool TSOrderDealSeen(const TickShockOrderFillState &state,const ulong deal_ticket)
  { for(int i=0;i<ArraySize(state.seen_deal_tickets);++i) if(state.seen_deal_tickets[i]==deal_ticket) return true;return false; }

void TSRememberOrderDeal(TickShockOrderFillState &state,const ulong deal_ticket)
  { int n=ArraySize(state.seen_deal_tickets);ArrayResize(state.seen_deal_tickets,n+1);state.seen_deal_tickets[n]=deal_ticket; }

bool TSOrderIdentityMatches(const TickShockOrderFillState &state,const ulong request_ticket,const ulong order_ticket,
                            const ulong position_ticket,const string symbol,const long magic,const int direction)
  {
   return (state.request_ticket==0 || request_ticket==state.request_ticket) &&
          (state.order_ticket==0 || order_ticket==state.order_ticket) &&
          (state.position_ticket==0 || position_ticket==state.position_ticket) &&
          (state.symbol=="" || symbol==state.symbol) && (state.magic==0 || magic==state.magic) &&
          (state.direction==0 || direction==state.direction);
  }

bool TSApplyOrderDeal(TickShockOrderFillState &state,const ulong deal_ticket,const ulong request_ticket,const ulong order_ticket,
                      const ulong position_ticket,const string symbol,const long magic,const int direction,
                      const ENUM_DEAL_ENTRY entry_kind,const double deal_volume,const double deal_price)
  {
   if(deal_ticket==0 || deal_volume<=0.0 || deal_price<=0.0) return false;
   if(TSOrderDealSeen(state,deal_ticket)){++state.duplicate_deals;return false;}
   if(!TSOrderIdentityMatches(state,request_ticket,order_ticket,position_ticket,symbol,magic,direction))
     {++state.identity_rejections;return false;}
   if(entry_kind==DEAL_ENTRY_OUT || entry_kind==DEAL_ENTRY_OUT_BY)
     {
      TSRememberOrderDeal(state,deal_ticket);state.exit_volume+=deal_volume;
      state.weighted_exit_value+=deal_volume*deal_price;++state.exit_deal_count;
      state.average_exit=state.weighted_exit_value/state.exit_volume;return true;
     }
   if(entry_kind!=DEAL_ENTRY_IN && entry_kind!=DEAL_ENTRY_INOUT) return false;
   if(state.entry_resolved || state.requested_volume<=0.0) return false;
   double epsilon=MathMax(1e-12,state.requested_volume*1e-9);
   if(deal_volume-state.remaining_volume>epsilon) return false;
   TSRememberOrderDeal(state,deal_ticket);
   double accepted=MathMin(deal_volume,state.remaining_volume);
   state.filled_volume+=accepted;state.weighted_fill_value+=accepted*deal_price;++state.deal_count;
   state.remaining_volume=MathMax(0.0,state.requested_volume-state.filled_volume-state.cancelled_volume);
   if(state.filled_volume>epsilon) state.average_fill=state.weighted_fill_value/state.filled_volume;
   if(state.remaining_volume<=epsilon)
     {state.remaining_volume=0.0;state.entry_resolved=true;state.state=state.filled_volume>epsilon?TS_ORDER_WAIT_EXIT:TS_ORDER_ENTRY_CANCELLED;}
   return true;
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

void TSRestoreOrderSnapshot(const TickShockOrderFillState &snapshot,TickShockOrderFillState &state)
  {
   state=snapshot;
   ArrayCopy(state.seen_deal_tickets,snapshot.seen_deal_tickets);
  }

#endif
