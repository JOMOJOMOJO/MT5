#ifndef WAVE33_DAYTRADE_PARTIAL_STOPS_MQH
#define WAVE33_DAYTRADE_PARTIAL_STOPS_MQH
// EA-local native execution adapter. Pure decisions live in DayTrade.mqh.
struct W33DayCloseOrder {ulong ticket;int record;string reason;};
W33DayCloseOrder g_day_close_orders[];
string DayTradeTimeReason(){return MathAbs(InpMaxHoldHours-24.0)<1e-9?"TIME_LIMIT_24H":"TIME_LIMIT_HOURS";}
bool DayTradeOpen()
  {
   g_day_file=FileOpen(g_tag+"_daytrade.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,';',CP_UTF8);
   if(g_day_file==INVALID_HANDLE)return false;
   FileWrite(g_day_file,"at","time_msc","setup_id","event","reason","direction","position_id","first_fill_msc","deadline_msc",
      "entry","original_sl","fixed_risk_price","initial_risk_money","max_favorable_r","stage","desired_sl_r","requested_sl","broker_sl",
      "broker_tp","remaining_volume","sl_pending","close_pending","close_order","net_cash");return true;
  }
void DayTradeClose(){if(g_day_file!=INVALID_HANDLE){FileClose(g_day_file);g_day_file=INVALID_HANDLE;}}
void DayTradeHideTarget(const W33Setup &s)
  {
   if(!g_effective_draw || s.setup_id=="" || s.tp_price>0)return;
   string base=g_prefix+W33Hash(s.setup_id)+"_";
   ObjectDelete(0,base+"TP");ObjectDelete(0,base+"TP_label");
  }
void DayTradeDrawSL(const int i,const double old_price)
  {
   if(!g_effective_draw)return;
   datetime now=TimeCurrent();int step=(int)MathMax(60,PeriodSeconds(g_lower));
   string base=g_prefix+W33Hash(g_records[i].setup.setup_id)+"_",line=base+"SL",label=base+"SL_label";
   if(ObjectFind(0,line)>=0)
     {
      datetime start=(datetime)ObjectGetInteger(0,line,OBJPROP_TIME,0);
      string history=base+"day_sl_history_"+(string)now+"_"+(string)g_records[i].day.stage_reached;
      if(old_price>0 && now>=start)
        {
         ObjectCreate(0,history,OBJ_TREND,0,start,old_price,(datetime)MathMax((long)start+1,(long)now),old_price);
         ObjectSetInteger(0,history,OBJPROP_COLOR,clrTomato);ObjectSetInteger(0,history,OBJPROP_STYLE,STYLE_DOT);
         ObjectSetInteger(0,history,OBJPROP_RAY_LEFT,false);ObjectSetInteger(0,history,OBJPROP_RAY_RIGHT,false);
         ObjectSetString(0,history,OBJPROP_TOOLTIP,"Previous SL; valid until broker confirmation "+W33Time(now));
        }
      ObjectMove(0,line,0,now,g_records[i].setup.sl_price);ObjectMove(0,line,1,now+step,g_records[i].setup.sl_price);
     }
   if(ObjectFind(0,label)>=0)
     {
      ObjectMove(0,label,0,now,g_records[i].setup.sl_price);
      ObjectSetString(0,label,OBJPROP_TEXT,"SL 段階 "+DoubleToString(g_records[i].day.desired_sl_r,1)+"R");
      ObjectSetString(0,label,OBJPROP_TOOLTIP,"Broker SL confirmed "+W33Time(now)+"; original risk remains fixed");
     }
  }
void DayTradeEvent(const int i,const string event,const string reason)
  {
   if(i<0 || i>=ArraySize(g_records))return;
   ulong ticket=0;double sl=0,tp=0,volume=0;
   if(OwnedPosition(i,ticket)){sl=PositionGetDouble(POSITION_SL);tp=PositionGetDouble(POSITION_TP);volume=PositionGetDouble(POSITION_VOLUME);}
   W33Execution r=g_records[i];MqlTick tick;ZeroMemory(tick);SymbolInfoTick(_Symbol,tick);
   long deadline=r.day_first_fill_msc+(long)MathRound(InpMaxHoldHours*3600000.0);
   if(g_day_file!=INVALID_HANDLE)
     {
      FileWrite(g_day_file,W33Time(TimeCurrent()),tick.time_msc,r.setup.setup_id,event,reason,r.setup.direction,(long)r.position_id,
         r.day_first_fill_msc,deadline,DoubleToString(r.setup.entry_price,10),DoubleToString(r.initial_sl_price,10),DoubleToString(r.day.risk_price,10),
         DoubleToString(r.initial_risk_money,10),DoubleToString(r.day.max_favorable_r,10),r.day.stage_reached,DoubleToString(r.day.desired_sl_r,10),
         DoubleToString(r.day_sl_target,10),DoubleToString(sl,10),DoubleToString(tp,10),DoubleToString(volume,8),r.day_sl_pending,r.day_close_pending,
         (long)r.day_close_order,DoubleToString(r.net_cash,10));FileFlush(g_day_file);
     }
   W33Setup copy=r.setup;Emit(copy,event,"OBSERVATION",reason);
  }
// Session clock is broker/source time, as are TimeCurrent and quote.time.
long DayTradeSessionStart(const datetime midnight,const datetime raw)
  {return (long)midnight+((long)raw%86400);}
void DayTradeRefreshSessions()
  {
   datetime now=TimeCurrent();if(g_session_cache_at>0 && now>=g_session_cache_at && now-g_session_cache_at<60)return;
   g_session_cache_at=now;g_weekend_end_msc=0;if(!InpCloseBeforeWeekend)return;
   MqlDateTime parts;TimeToStruct(now,parts);parts.hour=0;parts.min=0;parts.sec=0;datetime midnight=StructToTime(parts);
   long starts[],ends[];
   // Include yesterday for a session crossing midnight, and a full future week.
   for(int offset=-1;offset<=7;offset++)
     {
      datetime day=midnight+offset*86400;MqlDateTime d;TimeToStruct(day,d);
      for(uint index=0;index<32;index++)
        {
         datetime a,b;if(!SymbolInfoSessionTrade(_Symbol,(ENUM_DAY_OF_WEEK)d.day_of_week,index,a,b))break;
         long begin=DayTradeSessionStart(day,a),end=DayTradeSessionStart(day,b);if(end<=begin)end+=86400;
         int n=ArraySize(starts);ArrayResize(starts,n+1);ArrayResize(ends,n+1);starts[n]=begin;ends[n]=end;
        }
     }
   for(int i=0;i<ArraySize(ends);i++)
     {
      if(ends[i]<(long)now || starts[i]>(long)now)continue;
      long next=LONG_MAX;
      for(int j=0;j<ArraySize(starts);j++)if(starts[j]>=ends[i] && starts[j]<next)next=starts[j];
      if(next!=LONG_MAX && next-ends[i]>=86400)g_weekend_end_msc=ends[i]*1000;
     }
  }
bool DayTradeWeekendDue()
  {
   if(!InpCloseBeforeWeekend)return false;DayTradeRefreshSessions();
   return W33DayTradeWeekCloseDue((long)TimeCurrent()*1000,g_weekend_end_msc,InpWeekendBufferMinutes*60);
  }
void DayTradeRegisterClose(const int i,const ulong ticket)
  {
   if(ticket==0)return;
   for(int j=0;j<ArraySize(g_day_close_orders);j++)if(g_day_close_orders[j].ticket==ticket)return;
   int n=ArraySize(g_day_close_orders);ArrayResize(g_day_close_orders,n+1);
   g_day_close_orders[n].ticket=ticket;g_day_close_orders[n].record=i;g_day_close_orders[n].reason=g_records[i].day_close_reason;
  }
bool DayTradeAccountCloseDeal(const int i,const ulong deal,const ulong order)
  {
   for(int j=0;j<ArraySize(g_day_close_orders);j++)if(g_day_close_orders[j].ticket==order && g_day_close_orders[j].record==i)
     {g_records[i].day_close_reason=g_day_close_orders[j].reason;return true;}
   string comment=HistoryDealGetString(deal,DEAL_COMMENT);
   if(StringFind(comment,"W33_DT_TIME")==0 || StringFind(comment,"W33_DT_WEEKEND")==0)
     {
      g_records[i].day_close_reason=StringFind(comment,"W33_DT_TIME")==0?DayTradeTimeReason():"WEEKEND_SESSION_CLOSE";
      DayTradeRegisterClose(i,order);return true;
     }
   return false;
  }
bool DayTradeEnsureState(const int i)
  {
   if(g_records[i].day.initialized)return true;
   ulong ticket;if(!OwnedPosition(i,ticket) || !ScaleOutEntrySettled(i) || !ScaleOutLedgerMatchesPosition(i))return false;
   if(!W33InitDayTradeState(g_records[i].day,g_records[i].setup.direction,g_records[i].day_first_fill_msc,
      g_records[i].setup.entry_price,g_records[i].initial_sl_price))return false;
   DayTradeEvent(i,"DAYTRADE_RISK_FROZEN","actual weighted fill; first fill deadline; original SL and monetary R immutable");return true;
  }
void DayTradeReconcile()
  {
   if(!InpEnableTesterOrders || !TesterExecutionContext())return;
   for(int i=0;i<ArraySize(g_records);i++)
     {
      ulong ticket;if(!OwnedPosition(i,ticket))continue;
      if(g_records[i].day_sl_pending)
        {
         double actual=PositionGetDouble(POSITION_SL),tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
         if(actual>0 && g_records[i].setup.direction*(actual-g_records[i].day_sl_target)>=-MathMax(tick,_Point)*0.1)
           {
            double old=g_records[i].setup.sl_price;g_records[i].setup.sl_price=actual;g_records[i].day_sl_pending=false;
            DayTradeDrawSL(i,old);DayTradeEvent(i,"STEP_SL_CONFIRMED","observed broker position SL; no optimistic confirmation");
           }
        }
      if(g_records[i].day_sl_pending && TimeCurrent()>=g_records[i].day_sl_sent_at+5)
        {g_records[i].day_sl_pending=false;g_records[i].day_next_retry=TimeCurrent()+1;DayTradeEvent(i,"STEP_SL_RECHECK","not yet observed after 5 seconds; idempotent retry preserves current broker SL");}
      if(!g_records[i].day_close_pending || g_records[i].day_close_order==0)continue;
      ulong order=g_records[i].day_close_order;
      if(OrderSelect(order) || !HistoryOrderSelect(order))continue;
      ENUM_ORDER_STATE state=(ENUM_ORDER_STATE)HistoryOrderGetInteger(order,ORDER_STATE);
      if(state!=ORDER_STATE_FILLED && state!=ORDER_STATE_CANCELED && state!=ORDER_STATE_REJECTED && state!=ORDER_STATE_EXPIRED)continue;
      double executed=HistoryOrderGetDouble(order,ORDER_VOLUME_INITIAL)-HistoryOrderGetDouble(order,ORDER_VOLUME_CURRENT);
      if(g_records[i].exit_volume-g_records[i].day_close_prior_exit+HalfExecutionTolerance(i)<executed)continue;
      g_records[i].day_close_pending=false;g_records[i].day_next_retry=TimeCurrent()+1;
      DayTradeEvent(i,"DAYTRADE_CLOSE_SETTLED","remaining volume may retry; confirmed deals conserved");
     }
  }
void DayTradeRequestResult(const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   for(int i=0;i<ArraySize(g_records);i++)
     {
      if(g_records[i].day_sl_pending && request.action==TRADE_ACTION_SLTP && result.request_id==g_records[i].day_sl_request_id)
        {
         if(result.retcode!=TRADE_RETCODE_DONE && result.retcode!=TRADE_RETCODE_PLACED && result.retcode!=TRADE_RETCODE_NO_CHANGES)
           {g_records[i].day_sl_pending=false;g_records[i].day_next_retry=TimeCurrent()+2;DayTradeEvent(i,"STEP_SL_REJECTED","callback "+result.comment);}
        }
      if(g_records[i].day_close_pending && request.action==TRADE_ACTION_DEAL && result.request_id==g_records[i].day_close_request_id)
        {
         if(!AcceptedDeal(result.retcode))
           {g_records[i].day_close_pending=false;g_records[i].day_next_retry=TimeCurrent()+2;DayTradeEvent(i,"DAYTRADE_CLOSE_REJECTED","callback "+result.comment);}
         else {g_records[i].day_close_order=result.order;DayTradeRegisterClose(i,result.order);}
        }
     }
  }
void ManageDayTradeTimeExits()
  {
   if(!InpEnableTesterOrders || !TesterExecutionContext())return;
   MqlTick tick;if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0 || tick.ask<tick.bid)return;
   bool weekend=DayTradeWeekendDue();
   for(int i=0;i<ArraySize(g_records);i++)
     {
      ulong ticket;if(!OwnedPosition(i,ticket) || g_records[i].day_first_fill_msc<=0)continue;
      long deadline=g_records[i].day_first_fill_msc+(long)MathRound(InpMaxHoldHours*3600000.0);
      bool expired=tick.time_msc>=deadline;if(!expired && !weekend)continue;
      // An active entry remainder must not reopen volume after closing it.
      if(g_records[i].entry_order_ticket>0 && OrderSelect(g_records[i].entry_order_ticket))
        {
         MqlTradeRequest cancel;MqlTradeResult response;ZeroMemory(cancel);ZeroMemory(response);
         cancel.action=TRADE_ACTION_REMOVE;cancel.order=g_records[i].entry_order_ticket;cancel.symbol=_Symbol;cancel.magic=InpMagic;
         if(TimeCurrent()>=g_records[i].day_next_retry){bool sent=OrderSend(cancel,response);g_records[i].day_next_retry=TimeCurrent()+2;DayTradeEvent(i,"TIME_EXIT_CANCEL_ENTRY",(sent?"accepted ":"rejected ")+response.comment);}continue;
        }
      if(g_records[i].day_close_pending || g_records[i].opposite.request_pending || g_records[i].scale.request_pending || TimeCurrent()<g_records[i].day_next_retry)continue;
      if(!PositionSelectByTicket(ticket))continue;
      MqlTradeRequest request;MqlTradeResult result;MqlTradeCheckResult check;ZeroMemory(request);ZeroMemory(result);ZeroMemory(check);
      request.action=TRADE_ACTION_DEAL;request.position=ticket;request.symbol=_Symbol;request.magic=InpMagic;
      request.type=g_records[i].setup.direction>0?ORDER_TYPE_SELL:ORDER_TYPE_BUY;request.volume=PositionGetDouble(POSITION_VOLUME);
      request.price=g_records[i].setup.direction>0?tick.bid:tick.ask;request.deviation=InpDeviationPoints;
      request.comment=expired?"W33_DT_TIME":"W33_DT_WEEKEND";
      long fill=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);request.type_filling=(fill&SYMBOL_FILLING_FOK)!=0?ORDER_FILLING_FOK:((fill&SYMBOL_FILLING_IOC)!=0?ORDER_FILLING_IOC:ORDER_FILLING_RETURN);
      g_records[i].day_close_reason=expired?DayTradeTimeReason():"WEEKEND_SESSION_CLOSE";
      if(!OrderCheck(request,check)){g_records[i].day_next_retry=TimeCurrent()+2;DayTradeEvent(i,"DAYTRADE_CLOSE_REJECTED","check "+check.comment);continue;}
      g_records[i].day_close_pending=true;g_records[i].day_close_prior_exit=g_records[i].exit_volume;
      DayTradeEvent(i,"DAYTRADE_CLOSE_REQUEST",g_records[i].day_close_reason);
      bool sent=OrderSend(request,result);g_records[i].day_close_order=result.order;g_records[i].day_close_request_id=result.request_id;DayTradeRegisterClose(i,result.order);
      if(!sent || !AcceptedDeal(result.retcode)){g_records[i].day_close_pending=false;g_records[i].day_next_retry=TimeCurrent()+2;DayTradeEvent(i,"DAYTRADE_CLOSE_REJECTED",result.comment);}
      else DayTradeEvent(i,"DAYTRADE_CLOSE_ACCEPTED",result.comment);
     }
  }
void ManageDayTradeStops()
  {
   if(!InpEnableTesterOrders || !TesterExecutionContext())return;
   MqlTick tick;if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0 || tick.ask<tick.bid)return;
   for(int i=0;i<ArraySize(g_records);i++)
     {
      ulong ticket;if(!OwnedPosition(i,ticket) || !DayTradeEnsureState(i))continue;
      double quote=g_records[i].setup.direction>0?tick.bid:tick.ask;
      bool newStage=W33ObserveDayTradeQuote(g_records[i].day,g_day_config,quote);
      if(newStage)DayTradeEvent(i,"STEP_SL_STAGE","desired SL "+DoubleToString(g_records[i].day.desired_sl_r,3)+"R");
      if(g_records[i].day_close_pending || g_records[i].opposite.request_pending || g_records[i].scale.request_pending || g_records[i].day_sl_pending || TimeCurrent()<g_records[i].day_next_retry)continue;
      if(InpScaleOut && (!DayPartialEnsure(i) || !W33DayTradePartialComplete(g_records[i].half,g_records[i].scale.confirmed_closed_volume)))continue;
      if(W33DayTradeDeadlineDue(g_records[i].day,g_day_config,tick.time_msc) || DayTradeWeekendDue())continue;
      if(!PositionSelectByTicket(ticket))continue;
      W33DayTradeSLPlan plan=W33BuildDayTradeSLPlan(g_records[i].day,g_day_config,PositionGetDouble(POSITION_SL),quote,_Point,
         SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),_Digits,SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL));
      if(!plan.can_modify)
        {if(plan.valid && !plan.already_protected && plan.reason!=g_records[i].day_last_wait){g_records[i].day_last_wait=plan.reason;DayTradeEvent(i,"STEP_SL_WAIT",plan.reason);}continue;}
      MqlTradeRequest request;MqlTradeResult result;MqlTradeCheckResult check;ZeroMemory(request);ZeroMemory(result);ZeroMemory(check);
      request.action=TRADE_ACTION_SLTP;request.position=ticket;request.symbol=_Symbol;request.magic=InpMagic;request.sl=plan.target_sl;request.tp=0;
      if(!OrderCheck(request,check)){g_records[i].day_next_retry=TimeCurrent()+2;DayTradeEvent(i,"STEP_SL_REJECTED","check "+check.comment);continue;}
      g_records[i].day_sl_target=plan.target_sl;g_records[i].day_sl_pending=true;g_records[i].day_sl_sent_at=TimeCurrent();
      DayTradeEvent(i,"STEP_SL_REQUEST","broker confirmation required");
      bool sent=OrderSend(request,result);g_records[i].day_sl_request_id=result.request_id;
      if(!sent || (result.retcode!=TRADE_RETCODE_DONE && result.retcode!=TRADE_RETCODE_PLACED && result.retcode!=TRADE_RETCODE_NO_CHANGES))
        {g_records[i].day_sl_pending=false;g_records[i].day_next_retry=TimeCurrent()+2;DayTradeEvent(i,"STEP_SL_REJECTED",result.comment);}
      else DayTradeEvent(i,"STEP_SL_ACCEPTED",result.comment);
     }
  }
void DayTradeAfterDeal(const int i,const ENUM_DEAL_ENTRY entry)
  {
   if(entry==DEAL_ENTRY_IN)DayTradeEnsureState(i);
   if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY)
     {
      bool closed=g_records[i].exit_volume>=g_records[i].filled_volume-HalfExecutionTolerance(i);
      DayTradeEvent(i,closed?"DAYTRADE_POSITION_CLOSED":"DAYTRADE_PARTIAL_CLOSE",g_records[i].setup.exit_reason);
      if(closed){g_records[i].day_close_pending=false;g_records[i].day_sl_pending=false;}
     }
  }
#endif
