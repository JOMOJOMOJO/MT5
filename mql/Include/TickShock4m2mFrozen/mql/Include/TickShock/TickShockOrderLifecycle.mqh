#ifndef TICK_SHOCK_ORDER_LIFECYCLE_MQH
#define TICK_SHOCK_ORDER_LIFECYCLE_MQH

#include "TickShockTypes.mqh"

void TSResetOrderFillState(TickShockOrderFillState &state,const double requested_volume)
  {
   ZeroMemory(state);
   state.state=TS_ORDER_ENTRY_PENDING;
   state.requested_volume=MathMax(0.0,requested_volume);
   state.remaining_volume=state.requested_volume;
   state.request_ticket=0;state.order_ticket=0;state.position_ticket=0;state.position_identifier=0;
   state.last_deal_order_ticket=0;state.entry_request_ticket=0;state.exit_request_ticket=0;
   state.entry_order_ticket=0;state.exit_order_ticket=0;state.entry_operation_id=0;state.exit_operation_id=0;
   state.symbol="";state.magic=0;state.direction=0;state.identity_rejections=0;state.duplicate_deals=0;
   ArrayResize(state.seen_deal_tickets,0);
  }

bool TSConfigureOrderIdentity(TickShockOrderFillState &state,const ulong request_ticket,const ulong order_ticket,
                              const ulong position_ticket,const string symbol,const long magic,const int direction)
  {
   bool identity_matches=(state.request_ticket==0 || request_ticket==0 || request_ticket==state.request_ticket) &&
      (state.order_ticket==0 || order_ticket==0 || order_ticket==state.order_ticket) &&
      (state.position_ticket==0 || position_ticket==0 || position_ticket==state.position_ticket) &&
      (state.symbol=="" || symbol=="" || symbol==state.symbol) && (state.magic==0 || magic==0 || magic==state.magic) &&
      (state.direction==0 || direction==0 || direction==state.direction);
   if(!identity_matches){++state.identity_rejections;return false;}
   if(request_ticket>0){state.request_ticket=request_ticket;if(state.entry_request_ticket==0)state.entry_request_ticket=request_ticket;}
   if(order_ticket>0){state.order_ticket=order_ticket;if(state.entry_order_ticket==0)state.entry_order_ticket=order_ticket;}
   if(position_ticket>0){state.position_ticket=position_ticket;state.position_identifier=position_ticket;}
   if(symbol!="") state.symbol=symbol;if(magic!=0) state.magic=magic;if(direction!=0) state.direction=direction;
   return true;
  }

bool TSOrderDealSeen(const TickShockOrderFillState &state,const ulong deal_ticket)
  { for(int i=0;i<ArraySize(state.seen_deal_tickets);++i) if(state.seen_deal_tickets[i]==deal_ticket) return true;return false; }

void TSRememberOrderDeal(TickShockOrderFillState &state,const ulong deal_ticket)
  { int n=ArraySize(state.seen_deal_tickets);ArrayResize(state.seen_deal_tickets,n+1);state.seen_deal_tickets[n]=deal_ticket; }

bool TSOrderIdentityMatches(const TickShockOrderFillState &state,const ulong request_ticket,const ulong order_ticket,
                            const ulong position_ticket,const string symbol,const long magic,const int direction)
  {
   return (state.request_ticket==0 || request_ticket==0 || request_ticket==state.request_ticket) &&
           (state.order_ticket==0 || order_ticket==0 || order_ticket==state.order_ticket) &&
           (state.position_ticket==0 || position_ticket==0 || position_ticket==state.position_ticket) &&
           (state.symbol=="" || symbol=="" || symbol==state.symbol) && (state.magic==0 || magic==0 || magic==state.magic) &&
           (state.direction==0 || direction==0 || direction==state.direction);
  }

bool TSApplyOrderDeal(TickShockOrderFillState &state,const ulong deal_ticket,const ulong request_ticket,const ulong order_ticket,
                      const ulong position_ticket,const string symbol,const long magic,const int direction,
                      const ENUM_DEAL_ENTRY entry_kind,const double deal_volume,const double deal_price)
  {
   if(deal_ticket==0 || deal_volume<=0.0 || deal_price<=0.0) return false;
   if(TSOrderDealSeen(state,deal_ticket)){++state.duplicate_deals;return false;}
   bool is_exit=entry_kind==DEAL_ENTRY_OUT || entry_kind==DEAL_ENTRY_OUT_BY;
   bool identity_matches=is_exit?
      ((state.position_ticket==0 || position_ticket==0 || position_ticket==state.position_ticket) &&
       (state.symbol=="" || symbol=="" || symbol==state.symbol) && (state.magic==0 || magic==0 || magic==state.magic) &&
       (state.direction==0 || direction==0 || direction==state.direction)):
      TSOrderIdentityMatches(state,request_ticket,order_ticket,position_ticket,symbol,magic,direction);
   if(!identity_matches){++state.identity_rejections;return false;}
   // Bind identity from the first authoritative transaction. This supports the
   // documented MT5 ordering where DEAL_ADD can be observed before the caller
   // has consumed the corresponding OrderSend result.
   if(state.request_ticket==0 && request_ticket>0) state.request_ticket=request_ticket;
   if(state.order_ticket==0 && order_ticket>0) state.order_ticket=order_ticket;
   if(state.position_ticket==0 && position_ticket>0) state.position_ticket=position_ticket;
   if(state.position_identifier==0 && position_ticket>0) state.position_identifier=position_ticket;
   if(state.symbol=="" && symbol!="") state.symbol=symbol;
   if(state.magic==0 && magic!=0) state.magic=magic;
   if(state.direction==0 && direction!=0) state.direction=direction;
   state.last_deal_order_ticket=order_ticket;
   if(is_exit)
     {
      if(state.exit_order_ticket==0 && order_ticket>0) state.exit_order_ticket=order_ticket;
      if(state.exit_request_ticket==0 && request_ticket>0) state.exit_request_ticket=request_ticket;
      TSRememberOrderDeal(state,deal_ticket);state.exit_volume+=deal_volume;
      state.weighted_exit_value+=deal_volume*deal_price;++state.exit_deal_count;
      state.average_exit=state.weighted_exit_value/state.exit_volume;return true;
     }
   if(entry_kind!=DEAL_ENTRY_IN && entry_kind!=DEAL_ENTRY_INOUT) return false;
   if(state.entry_order_ticket==0 && order_ticket>0) state.entry_order_ticket=order_ticket;
   if(state.entry_request_ticket==0 && request_ticket>0) state.entry_request_ticket=request_ticket;
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

bool TSAttachExitOperationIdentity(TickShockOrderFillState &state,const ulong request_ticket,const ulong order_ticket,
                                   const long operation_id)
  {
   if(request_ticket==0 || order_ticket==0 || operation_id<=0) return false;
   if(state.exit_order_ticket!=0 && state.exit_order_ticket!=order_ticket)
     {++state.identity_rejections;return false;}
   if(state.exit_request_ticket!=0 && state.exit_request_ticket!=request_ticket)
     {++state.identity_rejections;return false;}
   if(state.exit_operation_id!=0 && state.exit_operation_id!=operation_id)
     {++state.identity_rejections;return false;}
   state.exit_request_ticket=request_ticket;
   state.exit_order_ticket=order_ticket;
   state.exit_operation_id=operation_id;
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
