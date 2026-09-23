// Ownership, inventory, filling, cancellation and emergency-close functions
// preserved from USDJPY_M1_M5_HL_Fib50_Long.mq5.
bool MineOrder()
{ return OrderGetString(ORDER_SYMBOL)==_Symbol && (ulong)OrderGetInteger(ORDER_MAGIC)==InpMagicNumber; }
bool MinePosition()
{ return PositionGetString(POSITION_SYMBOL)==_Symbol && (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber; }

void Counts(int &orders,int &positions,int &foreign,ulong &order,ulong &position)
{
   orders=0; positions=0; foreign=0; order=0; position=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i);
      if(t==0 || OrderGetString(ORDER_SYMBOL)!=_Symbol) continue;
      if(MineOrder()) { orders++; order=t; } else foreign++;
   }
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(t==0 || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(MinePosition()) { positions++; position=t; } else foreign++;
   }
}

bool ResultOK(const uint code)
{ return code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_PLACED || code==TRADE_RETCODE_DONE_PARTIAL; }

bool Cancel(const ulong ticket,const string why)
{
   if(!OrderSelect(ticket)) return true;
   if(!MineOrder()) return false;
   MqlTradeRequest req={}; MqlTradeResult res={};
   req.action=TRADE_ACTION_REMOVE; req.order=ticket; req.symbol=_Symbol; req.magic=InpMagicNumber;
   bool sent=OrderSend(req,res);
   Print("TW_CANCEL ticket=",ticket," reason=",why," retcode=",res.retcode," comment=",res.comment);

   return sent && ResultOK(res.retcode);
}

ENUM_ORDER_TYPE_FILLING MarketFilling()
{
   long flags=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   if((flags & SYMBOL_FILLING_FOK)!=0) return ORDER_FILLING_FOK;
   if((flags & SYMBOL_FILLING_IOC)!=0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

bool EmergencyClose(const ulong ticket,const string why)
{
   if(!PositionSelectByTicket(ticket) || !MinePosition()) return false;
   // Close an existing owned long only.
   if(PositionGetInteger(POSITION_TYPE)!=POSITION_TYPE_BUY) return false;
   MqlTick tick; if(!SymbolInfoTick(_Symbol,tick)) return false;
   MqlTradeRequest req={}; MqlTradeResult res={};
   req.action=TRADE_ACTION_DEAL; req.position=ticket; req.symbol=_Symbol;
   req.magic=InpMagicNumber; req.type=ORDER_TYPE_SELL;
   req.volume=PositionGetDouble(POSITION_VOLUME); req.price=tick.bid;
   req.type_filling=MarketFilling(); req.deviation=20;
   bool sent=OrderSend(req,res);
   Print("TW_EMERGENCY_CLOSE ticket=",ticket," reason=",why," retcode=",res.retcode);
   return sent && ResultOK(res.retcode);
}

bool PositionOwnedExclusively(const ulong ticket)
{
   if(!PositionSelectByTicket(ticket) || !MinePosition()) return false;
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) return true;
   const ulong identifier=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   if(!HistorySelectByPosition(identifier)) return false;
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong d=HistoryDealGetTicket(i);
      long type=HistoryDealGetInteger(d,DEAL_TYPE);
      if(type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL) continue;
      if((ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagicNumber) return false;
   }
   return PositionSelectByTicket(ticket);
}

