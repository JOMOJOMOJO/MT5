#ifndef WAVE33_DAYTRADE_PARTIAL_EXECUTION_MQH
#define WAVE33_DAYTRADE_PARTIAL_EXECUTION_MQH
// New native adapter: deliberately excludes legacy auto-BE and full-close fallback.
struct W33ScaleOrder {ulong ticket;int record;double confirmed;};
W33ScaleOrder g_scale_orders[];
double HalfExecutionTolerance(const int i)
  {return W33HalfVolumeTolerance(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),g_records[i].filled_volume);}
string ScaleCSV(string value)
  {StringReplace(value,"\"","\"\"");return "\""+value+"\"";}
int ScaleOrderIndex(const ulong order)
  {for(int i=0;i<ArraySize(g_scale_orders);i++)if(g_scale_orders[i].ticket==order && order>0)return i;return -1;}
void RegisterScaleOrder(const int index,const ulong order)
  {if(order==0 || ScaleOrderIndex(order)>=0)return;int n=ArraySize(g_scale_orders);ArrayResize(g_scale_orders,n+1);g_scale_orders[n].ticket=order;g_scale_orders[n].record=index;g_scale_orders[n].confirmed=0;}
bool SeenExecutionDeal(const ulong deal)
  {for(int i=0;i<ArraySize(g_seen_deals);i++)if(g_seen_deals[i]==deal)return true;return false;}
void RememberExecutionDeal(const ulong deal)
  {int n=ArraySize(g_seen_deals);ArrayResize(g_seen_deals,n+1,1024);g_seen_deals[n]=deal;}
void ScaleOutCloseFiles()
  {if(g_scale_file!=INVALID_HANDLE){FileClose(g_scale_file);g_scale_file=INVALID_HANDLE;}if(g_deal_file!=INVALID_HANDLE){FileClose(g_deal_file);g_deal_file=INVALID_HANDLE;}}
void WriteExecutionDeal(const int index,const ulong deal)
  {
   if(g_deal_file==INVALID_HANDLE)return;
   FileWrite(g_deal_file,(long)deal,(long)HistoryDealGetInteger(deal,DEAL_ORDER),(long)HistoryDealGetInteger(deal,DEAL_POSITION_ID),
      (long)HistoryDealGetInteger(deal,DEAL_TIME_MSC),ScaleCSV(EnumToString((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY))),ScaleCSV(EnumToString((ENUM_DEAL_TYPE)HistoryDealGetInteger(deal,DEAL_TYPE))),
      DoubleToString(HistoryDealGetDouble(deal,DEAL_VOLUME),8),DoubleToString(HistoryDealGetDouble(deal,DEAL_PRICE),10),
      DoubleToString(HistoryDealGetDouble(deal,DEAL_PROFIT),10),DoubleToString(HistoryDealGetDouble(deal,DEAL_COMMISSION),10),DoubleToString(HistoryDealGetDouble(deal,DEAL_SWAP),10),
      DoubleToString(HistoryDealGetDouble(deal,DEAL_FEE),10),ScaleCSV(HistoryDealGetString(deal,DEAL_COMMENT)),ScaleCSV(EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(deal,DEAL_REASON))),ScaleCSV(g_records[index].setup.setup_id));FileFlush(g_deal_file);
  }
bool ScaleOutLedgerMatchesPosition(const int index)
  {double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);return MathAbs(PositionGetDouble(POSITION_VOLUME)-(g_records[index].filled_volume-g_records[index].exit_volume))<=W33HalfVolumeTolerance(step,g_records[index].filled_volume);}
bool ScaleOutEntrySettled(const int index)
  {
   ulong order=g_records[index].entry_order_ticket;if(order==0 || OrderSelect(order))return false;
   if(!HistoryOrderSelect(order))return false;
   ENUM_ORDER_STATE st=(ENUM_ORDER_STATE)HistoryOrderGetInteger(order,ORDER_STATE);
   return st==ORDER_STATE_FILLED || st==ORDER_STATE_CANCELED || st==ORDER_STATE_REJECTED || st==ORDER_STATE_EXPIRED;
  }
bool ScaleOutOpen()
  {
   ArrayResize(g_seen_deals,0);ArrayResize(g_scale_orders,0);
   g_deal_file=FileOpen(g_tag+"_raw_deals.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,';',CP_UTF8);
   if(g_deal_file==INVALID_HANDLE)return false;
   FileWrite(g_deal_file,"deal_ticket","order_ticket","position_id","time_msc","entry","type","volume","price","profit","commission","swap","fee","comment","reason","setup_id");FileFlush(g_deal_file);
   g_scale_file=FileOpen(g_tag+"_partial.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,';',CP_UTF8);
   if(g_scale_file==INVALID_HANDLE)return false;
   FileWrite(g_scale_file,"at","setup_id","event","reason","direction","entry","original_sl","fixed_risk_price","target_price","initial_volume","target_half_volume","confirmed_half_volume","total_exit_volume","remaining_volume","broker_sl","pending","order_ticket","initial_risk_money","net_cash");FileFlush(g_scale_file);return true;
  }
void DayPartialDraw(const int i,const string event)
  {
   if(!g_effective_draw || !g_records[i].half.initialized)return;
   string base=g_prefix+W33Hash(g_records[i].setup.setup_id)+"_",line=base+"partial_tp1",label=line+"_label";
   datetime now=TimeCurrent();double target=g_records[i].half.trigger_price;
   if(ObjectFind(0,line)<0)
     {
      ObjectCreate(0,line,OBJ_TREND,0,now,target,now+1,target);ObjectSetInteger(0,line,OBJPROP_COLOR,clrGold);ObjectSetInteger(0,line,OBJPROP_STYLE,STYLE_DASH);
      ObjectSetInteger(0,line,OBJPROP_RAY_LEFT,false);ObjectSetInteger(0,line,OBJPROP_RAY_RIGHT,false);
      ObjectCreate(0,label,OBJ_TEXT,0,now,target);ObjectSetInteger(0,label,OBJPROP_COLOR,clrGold);ObjectSetInteger(0,label,OBJPROP_FONTSIZE,8);
      ObjectSetString(0,label,OBJPROP_TEXT,"TP1 半分 +"+DoubleToString(InpPartialAtR,1)+"R");
      ObjectSetString(0,line,OBJPROP_TOOLTIP,"EA-managed partial target; no broker full-volume TP. Fixed at "+W33Time(now));
     }
   bool completed=W33DayTradePartialComplete(g_records[i].half,g_records[i].scale.confirmed_closed_volume);
   if(!completed || event=="DAY_PARTIAL_FILLED")
     {
      datetime start=(datetime)ObjectGetInteger(0,line,OBJPROP_TIME,0);ObjectMove(0,line,1,(datetime)MathMax((long)start+1,(long)now),target);
      if(completed)ObjectSetString(0,label,OBJPROP_TEXT,"TP1 半分済 +"+DoubleToString(InpPartialAtR,1)+"R");
     }
   if(event=="DAY_PARTIAL_FILLED")
     {
      string arrow=base+"half_fill_"+(string)g_records[i].scale.last_confirmed_deal;
      ObjectCreate(0,arrow,OBJ_ARROW,0,g_records[i].setup.exit_at,g_records[i].setup.exit_price);ObjectSetInteger(0,arrow,OBJPROP_ARROWCODE,159);ObjectSetInteger(0,arrow,OBJPROP_COLOR,clrGold);
      ObjectSetString(0,arrow,OBJPROP_TOOLTIP,"Confirmed partial deal "+(string)g_records[i].scale.last_confirmed_deal+"; cumulative "+DoubleToString(g_records[i].scale.confirmed_closed_volume,8));
     }
  }
void DayPartialEvent(const int i,const string event,const string reason)
  {
   if(i<0 || i>=ArraySize(g_records))return;
   ulong ticket=0;double volume=0,sl=0;if(OwnedPosition(i,ticket)){volume=PositionGetDouble(POSITION_VOLUME);sl=PositionGetDouble(POSITION_SL);}
   W33Execution r=g_records[i];
   if(g_scale_file!=INVALID_HANDLE)
     {
      FileWrite(g_scale_file,W33Time(TimeCurrent()),r.setup.setup_id,event,reason,r.setup.direction,DoubleToString(r.half.entry,10),DoubleToString(r.initial_sl_price,10),
         DoubleToString(r.half.risk_price,10),DoubleToString(r.half.trigger_price,10),DoubleToString(r.half.initial_volume,8),DoubleToString(r.scale.target_close_volume,8),
         DoubleToString(r.scale.confirmed_closed_volume,8),DoubleToString(r.exit_volume,8),DoubleToString(volume,8),DoubleToString(sl,10),r.scale.request_pending,
         (long)r.scale.pending_order,DoubleToString(r.initial_risk_money,10),DoubleToString(r.net_cash,10));FileFlush(g_scale_file);
     }
   W33Setup copy=r.setup;Emit(copy,event,"OBSERVATION",reason);DayPartialDraw(i,event);
  }
void PrepareDayPartial(const int i)
  {g_records[i].initial_sl_price=g_records[i].setup.sl_price;W33ResetScaleOutState(g_records[i].scale);g_records[i].scale.planned=InpScaleOut;}
bool DayPartialEnsure(const int i)
  {
   if(!InpScaleOut || g_records[i].half_unavailable)return false;
   if(g_records[i].half.initialized)return true;
   if(!DayTradeEnsureState(i))return false;
   bool ok=W33InitDayTradePartialState(g_records[i].half,g_records[i].day,g_records[i].filled_volume,
      SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),InpPartialAtR);
   if(!ok)
     {g_records[i].half_unavailable=true;DayPartialEvent(i,"DAY_PARTIAL_UNAVAILABLE","actual settled entry cannot split exactly; original SL/time/opposite exits remain; no automatic full-close fallback");return false;}
   g_records[i].scale.initial_volume_frozen=true;g_records[i].scale.initial_filled_volume=g_records[i].filled_volume;
   g_records[i].scale.target_close_volume=g_records[i].half.target_close_volume;g_records[i].scale.first_tp=g_records[i].half.trigger_price;
   DayPartialEvent(i,"DAY_PARTIAL_FROZEN","actual settled volume exact half; immutable weighted entry and initial R; no SL move on partial");return true;
  }
void ReconcileDayPartials()
  {
   if(!InpScaleOut || !InpEnableTesterOrders || !TesterExecutionContext())return;
   for(int i=0;i<ArraySize(g_records);i++)
     {
      if(!g_records[i].scale.request_pending || g_records[i].scale.pending_order==0)continue;
      ulong order=g_records[i].scale.pending_order;if(OrderSelect(order) || !HistoryOrderSelect(order))continue;
      ENUM_ORDER_STATE state=(ENUM_ORDER_STATE)HistoryOrderGetInteger(order,ORDER_STATE);
      if(state!=ORDER_STATE_FILLED && state!=ORDER_STATE_CANCELED && state!=ORDER_STATE_REJECTED && state!=ORDER_STATE_EXPIRED)continue;
      double executed=HistoryOrderGetDouble(order,ORDER_VOLUME_INITIAL)-HistoryOrderGetDouble(order,ORDER_VOLUME_CURRENT);int slot=ScaleOrderIndex(order);
      if((slot>=0?g_scale_orders[slot].confirmed:0)+HalfExecutionTolerance(i)<executed)continue;
      g_records[i].scale.request_pending=false;DayPartialEvent(i,"DAY_PARTIAL_REQUEST_SETTLED","confirmed order deal volume accounted; retry only remaining part of original half");
     }
  }
bool DayPartialOppositeHasPriority(const int i)
  {
   if(g_records[i].opposite.request_pending)return true;
   if(!InpExitOnOppositeWave1 || !g_records[i].opposite.armed)return false;
   MqlTick tick;if(!SymbolInfoTick(_Symbol,tick))return true;
   double volume=PositionGetDouble(POSITION_VOLUME),profit=0;int d=g_records[i].setup.direction;
   if(!OrderCalcProfit(d>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,volume,PositionGetDouble(POSITION_PRICE_OPEN),d>0?tick.bid:tick.ask,profit))return true;
   double rate=g_records[i].filled_volume>0?g_records[i].entry_costs/g_records[i].filled_volume:0;
   return W33ShouldRequestOppositeExit(g_records[i].opposite,true,true,true,W33OppositeNetEstimate(profit,g_records[i].net_cash,PositionGetDouble(POSITION_SWAP),rate,volume));
  }
void ManageDayPartials()
  {
   if(!InpScaleOut || !InpEnableTesterOrders || !TesterExecutionContext())return;
   ReconcileDayPartials();MqlTick tick;if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0 || tick.ask<tick.bid)return;
   for(int i=0;i<ArraySize(g_records);i++)
     {
      ulong ticket;if(!OwnedPosition(i,ticket) || !ScaleOutLedgerMatchesPosition(i) || !DayPartialEnsure(i))continue;
      if(W33DayTradePartialComplete(g_records[i].half,g_records[i].scale.confirmed_closed_volume))continue;
      if(g_records[i].scale.request_pending || g_records[i].day_close_pending || g_records[i].day_sl_pending || g_records[i].opposite.request_pending || TimeCurrent()<g_records[i].scale_next_close_at)continue;
      if(W33DayTradeDeadlineDue(g_records[i].day,g_day_config,tick.time_msc) || DayTradeWeekendDue() || DayPartialOppositeHasPriority(i))continue;
      if(W33ObserveDayTradePartialQuote(g_records[i].half,tick.bid,tick.ask))DayPartialEvent(i,"DAY_PARTIAL_TOUCH","executable Bid/Ask reached fixed initial-R target");
      if(!W33DayTradePartialQuoteHit(g_records[i].half,tick.bid,tick.ask))continue; // Failed sends never imply an invented fill on a retrace.
      W33DayTradePartialRequest p=W33BuildDayTradePartialRequest(g_records[i].half,g_records[i].scale.confirmed_closed_volume,PositionGetDouble(POSITION_VOLUME),
         SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX));
      if(!p.valid || p.complete)
        {if(p.reason!=g_records[i].scale_last_wait){g_records[i].scale_last_wait=p.reason;DayPartialEvent(i,"DAY_PARTIAL_WAIT",p.reason);}continue;}
      MqlTradeRequest request;MqlTradeResult result;MqlTradeCheckResult check;ZeroMemory(request);ZeroMemory(result);ZeroMemory(check);
      request.action=TRADE_ACTION_DEAL;request.position=ticket;request.symbol=_Symbol;request.magic=InpMagic;request.type=g_records[i].setup.direction>0?ORDER_TYPE_SELL:ORDER_TYPE_BUY;
      request.volume=p.request_volume;request.price=g_records[i].setup.direction>0?tick.bid:tick.ask;request.deviation=InpDeviationPoints;request.comment="W33_DAY_HALF_TP1";
      long fill=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);request.type_filling=(fill&SYMBOL_FILLING_FOK)!=0?ORDER_FILLING_FOK:((fill&SYMBOL_FILLING_IOC)!=0?ORDER_FILLING_IOC:ORDER_FILLING_RETURN);
      g_records[i].scale_next_close_at=TimeCurrent()+1;
      if(!OrderCheck(request,check)){DayPartialEvent(i,"DAY_PARTIAL_REJECTED","check "+(string)check.retcode+" "+check.comment);continue;}
      g_records[i].scale.request_pending=true;g_records[i].scale.pending_order=0;g_records[i].scale.pending_request_id=0;
      DayPartialEvent(i,"DAY_PARTIAL_REQUEST","volume="+DoubleToString(request.volume,8)+"; SL unchanged; await confirmed deals");
      bool sent=OrderSend(request,result);g_records[i].scale.pending_order=result.order;g_records[i].scale.pending_request_id=result.request_id;RegisterScaleOrder(i,result.order);
      if(!sent || !AcceptedDeal(result.retcode)){g_records[i].scale.request_pending=false;DayPartialEvent(i,"DAY_PARTIAL_REJECTED","send "+(string)result.retcode+" "+result.comment);}
      else DayPartialEvent(i,"DAY_PARTIAL_ACCEPTED","order="+(string)result.order);
     }
  }
void HandleDayPartialRequest(const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(!InpScaleOut || request.action!=TRADE_ACTION_DEAL || request.comment!="W33_DAY_HALF_TP1")return;
   for(int i=0;i<ArraySize(g_records);i++)
     if(g_records[i].scale.request_pending && result.request_id==g_records[i].scale.pending_request_id)
       {
        if(result.order>0){g_records[i].scale.pending_order=result.order;RegisterScaleOrder(i,result.order);}
        if(!AcceptedDeal(result.retcode)){g_records[i].scale.request_pending=false;DayPartialEvent(i,"DAY_PARTIAL_REJECTED","callback "+(string)result.retcode+" "+result.comment);}
       }
  }
bool AccountDayPartialDeal(const int i,const ulong deal,const double volume)
  {
   if(!InpScaleOut || !g_records[i].scale.planned)return false;
   ulong order=(ulong)HistoryDealGetInteger(deal,DEAL_ORDER);int slot=ScaleOrderIndex(order);
   string comment=HistoryDealGetString(deal,DEAL_COMMENT);if(comment=="")comment=HistoryOrderGetString(order,ORDER_COMMENT);
   if(slot<0 && StringFind(comment,"W33_DAY_HALF_TP1")==0){RegisterScaleOrder(i,order);slot=ScaleOrderIndex(order);g_records[i].scale.pending_order=order;}
   if(slot<0 || g_scale_orders[slot].record!=i)return false;
   g_scale_orders[slot].confirmed+=volume;g_records[i].scale.confirmed_closed_volume+=volume;g_records[i].scale.last_confirmed_deal=deal;
   if(g_records[i].scale.first_confirmed_at==0)g_records[i].scale.first_confirmed_at=TimeCurrent();return true;
  }
#endif
