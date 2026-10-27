#ifndef WAVE33_SCALEOUT_EXECUTION_MQH
#define WAVE33_SCALEOUT_EXECUTION_MQH
// EA-local execution adapter. Included AFTER W33Execution and its globals.
struct W33ScaleOrder {ulong ticket;int record;double confirmed;};
W33ScaleOrder g_scale_orders[];
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
bool ScaleOutOpen()
  {
   ArrayResize(g_seen_deals,0);ArrayResize(g_scale_orders,0);
   g_deal_file=FileOpen(g_tag+"_raw_deals.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,';',CP_UTF8);
   if(g_deal_file==INVALID_HANDLE)return false;
   FileWrite(g_deal_file,"deal_ticket","order_ticket","position_id","time_msc","entry","type","volume","price","profit","commission","swap","fee","comment","reason","setup_id");FileFlush(g_deal_file);
   if(!InpScaleOut)return true;
   g_scale_file=FileOpen(g_tag+"_scaleout.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,';',CP_UTF8);
   if(g_scale_file==INVALID_HANDLE)return false;
   FileWrite(g_scale_file,"at","setup_id","symbol","direction","event","reason","entry_price","initial_sl","current_sl","base_rr_tp","wave1_inside_tp","first_tp","planned_final_tp","broker_tp","initial_volume","target_close_volume","confirmed_close_volume","total_exit_volume","filled_volume","pending","order_ticket","request_id","be_done","be_target","position_id","net_cash","initial_risk_money","first_kind","final_kind","single_fallback");FileFlush(g_scale_file);return true;
  }
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
void ScaleOutDraw(const int index,const string event)
  {
   if(!g_effective_draw)return;
   W33Execution r=g_records[index];string base=g_prefix+W33Hash(r.setup.setup_id)+"_";datetime now=TimeCurrent();int step=PeriodSeconds(g_lower);
   if(event=="SCALEOUT_PLAN" && r.scale_plan.enabled)
     {
      string line=base+"scale_tp1",label=base+"scale_tp1_label";
      ObjectCreate(0,line,OBJ_TREND,0,now,r.scale.first_tp,now+12*step,r.scale.first_tp);ObjectSetInteger(0,line,OBJPROP_COLOR,clrGold);ObjectSetInteger(0,line,OBJPROP_STYLE,STYLE_DASH);
      ObjectSetInteger(0,line,OBJPROP_RAY_LEFT,false);ObjectSetInteger(0,line,OBJPROP_RAY_RIGHT,false);
      ObjectCreate(0,label,OBJ_TEXT,0,now,r.scale.first_tp);ObjectSetString(0,label,OBJPROP_TEXT,"TP1 半分 #"+StringSubstr(W33Hash(r.setup.setup_id),0,4));ObjectSetInteger(0,label,OBJPROP_COLOR,clrGold);ObjectSetInteger(0,label,OBJPROP_FONTSIZE,9);
      ObjectSetString(0,label,OBJPROP_TOOLTIP,"TP1 "+DoubleToString(r.scale.first_tp,_Digits)+"; TP2 "+DoubleToString(r.scale.final_tp,_Digits)+"; fixed at "+W33Time(now));
     }
   if(event=="SCALEOUT_BE_CONFIRMED" || event=="SCALEOUT_FALLBACK_SINGLE")
     {
      bool be=event=="SCALEOUT_BE_CONFIRMED";string line=base+(be?"SL":"TP"),label=line+"_label";double price=be?r.setup.sl_price:r.setup.tp_price;
      if(!be && ObjectFind(0,base+"scale_tp1_label")>=0)
        {
         ObjectSetString(0,base+"scale_tp1_label",OBJPROP_TEXT,"TP 全量（分割不可） #"+StringSubstr(W33Hash(r.setup.setup_id),0,4));
         ObjectSetString(0,base+"scale_tp1_label",OBJPROP_TOOLTIP,"Full volume at near target; "+r.scale.fallback_reason+"; known "+W33Time(now));
        }
      if(ObjectFind(0,line)>=0)
        {
         datetime start=(datetime)ObjectGetInteger(0,line,OBJPROP_TIME,0);double old=ObjectGetDouble(0,line,OBJPROP_PRICE,0);
         if(MathAbs(old-price)>_Point*0.1)
           {string history=base+(be?"SL_initial_history":"TP_plan_history");ObjectCreate(0,history,OBJ_TREND,0,start,old,(datetime)MathMax((long)start+step,(long)now),old);ObjectSetInteger(0,history,OBJPROP_COLOR,be?clrTomato:clrLimeGreen);ObjectSetInteger(0,history,OBJPROP_STYLE,STYLE_DOT);ObjectSetInteger(0,history,OBJPROP_RAY_LEFT,false);ObjectSetInteger(0,history,OBJPROP_RAY_RIGHT,false);}
         ObjectMove(0,line,0,now,price);ObjectMove(0,line,1,now+step,price);
        }
      if(ObjectFind(0,label)>=0){ObjectMove(0,label,0,now,price);ObjectSetString(0,label,OBJPROP_TEXT,be?"SL 建値":"TP 全量（分割不可）");ObjectSetString(0,label,OBJPROP_TOOLTIP,event+" actual entry "+DoubleToString(r.setup.entry_price,_Digits)+"; initial risk retained "+DoubleToString(r.initial_risk_money,2));}
     }
  }
void ScaleOutEvent(const int index,const string event,const string reason)
  {
   if(index<0 || index>=ArraySize(g_records))return;
   W33Execution r=g_records[index];
   double brokerTP=r.setup.tp_price;ulong selected=0;if(OwnedPosition(index,selected))brokerTP=PositionGetDouble(POSITION_TP);
   if(g_scale_file!=INVALID_HANDLE)
     {
      FileWrite(g_scale_file,ScaleCSV(W33Time(TimeCurrent())),ScaleCSV(r.setup.setup_id),ScaleCSV(_Symbol),r.setup.direction,ScaleCSV(event),ScaleCSV(reason),
         DoubleToString(r.setup.entry_price,10),DoubleToString(r.initial_sl_price,10),DoubleToString(r.setup.sl_price,10),DoubleToString(r.setup.tp_rr_price,10),DoubleToString(r.setup.tp_wave1_target_price,10),
         DoubleToString(r.scale.first_tp,10),DoubleToString(r.scale_plan.final_tp,10),DoubleToString(brokerTP,10),DoubleToString(r.scale.initial_filled_volume,8),DoubleToString(r.scale.target_close_volume,8),DoubleToString(r.scale.confirmed_closed_volume,8),DoubleToString(r.exit_volume,8),DoubleToString(r.filled_volume,8),
         r.scale.request_pending,(long)r.scale.pending_order,(long)r.scale.pending_request_id,r.scale.break_even_done,DoubleToString(r.scale_be_target,10),(long)r.position_id,DoubleToString(r.net_cash,10),DoubleToString(r.initial_risk_money,10),ScaleCSV(r.scale_plan.first_kind),ScaleCSV(r.scale_plan.final_kind),r.scale.single_fallback);FileFlush(g_scale_file);
     }
   W33Setup copy=r.setup;Emit(copy,event,"OBSERVATION",reason);ScaleOutDraw(index,event);
  }
void PrepareScaleOut(const int index)
  {
   W33Setup s=g_records[index].setup;g_records[index].initial_sl_price=s.sl_price;
   if(!InpScaleOut)return;
   W33ScaleOutPlan p=W33BuildScaleOutPlan(true,s.direction,s.entry_price,s.tp_rr_price,s.tp_wave1_target_price,s.tp_price,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE));
   g_records[index].scale_plan=p;W33ResetScaleOutState(g_records[index].scale);
   g_records[index].scale.planned=p.enabled;g_records[index].scale.eligible=p.enabled;g_records[index].scale.first_tp=p.first_tp;g_records[index].scale.final_tp=p.final_tp;
   ScaleOutEvent(index,"SCALEOUT_PLAN",p.reason+" first="+DoubleToString(p.first_tp,_Digits)+" final="+DoubleToString(p.final_tp,_Digits));
  }
void ScaleOutFallback(const int index,const string reason)
  {
   g_records[index].scale.eligible=false;g_records[index].scale.single_fallback=true;g_records[index].scale_fallback=true;g_records[index].scale.fallback_reason=reason;
   g_records[index].scale.final_tp=g_records[index].scale.first_tp;g_records[index].setup.tp_price=g_records[index].scale.first_tp;
   double risk=g_records[index].setup.risk_points*_Point;
   if(risk>0)g_records[index].setup.actual_rr=g_records[index].setup.direction*(g_records[index].setup.tp_price-g_records[index].setup.entry_price)/risk;
   ScaleOutEvent(index,"SCALEOUT_FALLBACK_SINGLE",reason);
  }
void ScaleOutCheckOrderVolume(const int index,const double volume,W33Setup &s)
  {
   if(!InpScaleOut || !g_records[index].scale.planned)return;
   W33ScaleOutVolumePlan v=W33BuildScaleOutVolumePlan(volume,volume,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),0);
   if(!v.split_allowed){ScaleOutFallback(index,v.reason);s=g_records[index].setup;}
  }
bool ScaleOutLedgerMatchesPosition(const int index)
  {double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);return MathAbs(PositionGetDouble(POSITION_VOLUME)-(g_records[index].filled_volume-g_records[index].exit_volume))<MathMax(1e-8,step*0.1);}
bool ScaleOutEntrySettled(const int index)
  {
   ulong order=g_records[index].entry_order_ticket;if(order==0 || OrderSelect(order))return false;
   if(!HistoryOrderSelect(order))return false;
   ENUM_ORDER_STATE st=(ENUM_ORDER_STATE)HistoryOrderGetInteger(order,ORDER_STATE);
   return st==ORDER_STATE_FILLED || st==ORDER_STATE_CANCELED || st==ORDER_STATE_REJECTED || st==ORDER_STATE_EXPIRED;
  }
void ReconcileScaleOuts()
  {
   if(!InpScaleOut)return;
   for(int i=0;i<ArraySize(g_records);i++)
     {
      if(!g_records[i].scale.request_pending || g_records[i].scale.pending_order==0)continue;
      ulong order=g_records[i].scale.pending_order;if(OrderSelect(order) || !HistoryOrderSelect(order))continue;
      ENUM_ORDER_STATE st=(ENUM_ORDER_STATE)HistoryOrderGetInteger(order,ORDER_STATE);
      if(st!=ORDER_STATE_FILLED && st!=ORDER_STATE_CANCELED && st!=ORDER_STATE_REJECTED && st!=ORDER_STATE_EXPIRED)continue;
      double executed=HistoryOrderGetDouble(order,ORDER_VOLUME_INITIAL)-HistoryOrderGetDouble(order,ORDER_VOLUME_CURRENT);int slot=ScaleOrderIndex(order);
      double accounted=slot>=0?g_scale_orders[slot].confirmed:0;
      if(accounted+1e-8<executed)continue; // Native position/history may lead the queued DEAL_ADD callback.
      g_records[i].scale.request_pending=false;
      ScaleOutEvent(i,"SCALEOUT_REQUEST_SETTLED","order="+(string)order+" confirmed="+DoubleToString(accounted,8));
     }
  }
void TryScaleOutBE(const int index)
  {
   if(!InpScaleOut || !InpEnableTesterOrders || !TesterExecutionContext() || index<0 || index>=ArraySize(g_records))return;
   if(!g_records[index].scale.planned || g_records[index].scale.single_fallback || g_records[index].scale.break_even_done ||
      !g_records[index].scale.initial_volume_frozen || g_records[index].scale.target_close_volume<=0 ||
      g_records[index].scale.confirmed_closed_volume+1e-8<g_records[index].scale.target_close_volume)return;
   ulong ticket;if(!OwnedPosition(index,ticket) || !ScaleOutLedgerMatchesPosition(index))return;
   MqlTick tick;if(!SymbolInfoTick(_Symbol,tick))return;
   W33ScaleOutBEPlan b=W33BuildScaleOutBEPlan(g_records[index].setup.direction,PositionGetDouble(POSITION_PRICE_OPEN),PositionGetDouble(POSITION_SL),tick.bid,tick.ask,
      _Point,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),_Digits,(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL));
   g_records[index].scale_be_target=b.target_sl;
   if(b.already_protected)
     {
      g_records[index].scale.break_even_done=true;g_records[index].scale.break_even_pending=false;g_records[index].scale_be_request_pending=false;
      g_records[index].setup.sl_price=PositionGetDouble(POSITION_SL);
      ScaleOutEvent(index,"SCALEOUT_BE_CONFIRMED",b.reason+" SL="+DoubleToString(g_records[index].setup.sl_price,_Digits));return;
     }
   if(g_records[index].scale_be_request_pending)
     {if(TimeCurrent()<g_records[index].scale_be_sent_at+5)return;g_records[index].scale_be_request_pending=false;ScaleOutEvent(index,"SCALEOUT_BE_RECHECK","accepted modification not yet observed; idempotent retry");}
   if(!b.valid || !b.can_modify)
     {if(g_records[index].scale_last_be_reason!=b.reason){g_records[index].scale_last_be_reason=b.reason;ScaleOutEvent(index,"SCALEOUT_BE_DEFERRED",b.reason);}return;}
   if(TimeCurrent()<g_records[index].scale_next_be_at || g_records[index].opposite.request_pending)return;
   MqlTradeRequest req;MqlTradeResult result;MqlTradeCheckResult check;ZeroMemory(req);ZeroMemory(result);ZeroMemory(check);
   req.action=TRADE_ACTION_SLTP;req.symbol=_Symbol;req.position=ticket;req.magic=InpMagic;req.sl=b.target_sl;req.tp=PositionGetDouble(POSITION_TP);
   g_records[index].scale.be_attempts++;g_records[index].scale_next_be_at=TimeCurrent()+1;
   if(!OrderCheck(req,check)){ScaleOutEvent(index,"SCALEOUT_BE_REJECTED","ORDER_CHECK "+(string)check.retcode+" "+check.comment);return;}
   g_records[index].scale_be_request_pending=true;g_records[index].scale_be_sent_at=TimeCurrent();
   ScaleOutEvent(index,"SCALEOUT_BE_REQUEST",b.reason+" target="+DoubleToString(b.target_sl,_Digits));
   bool sent=OrderSend(req,result);g_records[index].scale_be_request_id=result.request_id;
   if(!sent || !AcceptedDeal(result.retcode)){g_records[index].scale_be_request_pending=false;ScaleOutEvent(index,"SCALEOUT_BE_REJECTED","ORDER_SEND "+(string)result.retcode+" "+result.comment);}
   else
     {
      ulong selected=0;if(OwnedPosition(index,selected) && PositionGetDouble(POSITION_SL)>0 && g_records[index].setup.direction*(PositionGetDouble(POSITION_SL)-b.target_sl)>=-SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)*1e-8)
        {g_records[index].scale.break_even_done=true;g_records[index].scale.break_even_pending=false;g_records[index].scale_be_request_pending=false;g_records[index].setup.sl_price=PositionGetDouble(POSITION_SL);ScaleOutEvent(index,"SCALEOUT_BE_CONFIRMED",b.reason+" actual_SL="+DoubleToString(g_records[index].setup.sl_price,_Digits));}
     }
  }
bool ScaleOutOppositeHasPriority(const int index)
  {
   if(g_records[index].opposite.request_pending)return true;
   if(!InpExitOnOppositeWave1 || !g_records[index].opposite.armed)return false;
   MqlTick tick;if(!SymbolInfoTick(_Symbol,tick))return true;
   double volume=PositionGetDouble(POSITION_VOLUME),profit=0;int d=g_records[index].setup.direction;
   if(!OrderCalcProfit(d>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,volume,PositionGetDouble(POSITION_PRICE_OPEN),d>0?tick.bid:tick.ask,profit))return true;
   double rate=g_records[index].filled_volume>0?g_records[index].entry_costs/g_records[index].filled_volume:0;
   return W33ShouldRequestOppositeExit(g_records[index].opposite,true,true,true,W33OppositeNetEstimate(profit,g_records[index].net_cash,PositionGetDouble(POSITION_SWAP),rate,volume));
  }
void ManageScaleOuts()
  {
   if(!InpScaleOut || !InpEnableTesterOrders || !TesterExecutionContext())return;
   ReconcileScaleOuts();MqlTick tick;if(!SymbolInfoTick(_Symbol,tick))return;
   for(int i=0;i<ArraySize(g_records);i++)
     {
      if(!g_records[i].scale.planned)continue;
      ulong ticket;if(!OwnedPosition(i,ticket) || !ScaleOutLedgerMatchesPosition(i))continue;
      if(!g_records[i].scale.initial_volume_frozen)
        {
         if(!ScaleOutEntrySettled(i))continue;
         g_records[i].scale.initial_volume_frozen=true;g_records[i].scale.initial_filled_volume=g_records[i].filled_volume;
         W33ScaleOutVolumePlan initial=W33BuildScaleOutVolumePlan(g_records[i].filled_volume,PositionGetDouble(POSITION_VOLUME),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),0);
         g_records[i].scale.target_close_volume=initial.target_close_volume;
         if(!initial.split_allowed && !g_records[i].scale.single_fallback)ScaleOutFallback(i,initial.reason);
         ScaleOutEvent(i,"SCALEOUT_VOLUME_FROZEN",initial.reason);
        }
      if(!g_records[i].scale.single_fallback && g_records[i].scale.confirmed_closed_volume+1e-8>=g_records[i].scale.target_close_volume)
        {TryScaleOutBE(i);continue;}
      if(g_records[i].scale.request_pending || g_records[i].scale_be_request_pending || g_records[i].opposite.request_pending)continue;
      if(!W33ScaleOutPriceReached(g_records[i].setup.direction,tick.bid,tick.ask,g_records[i].scale.first_tp) || TimeCurrent()<g_records[i].scale_next_close_at)continue;
      if(ScaleOutOppositeHasPriority(i))continue;
      if(!g_records[i].scale.first_target_reached){g_records[i].scale.first_target_reached=true;g_records[i].scale.first_reached_at=TimeCurrent();ScaleOutEvent(i,"SCALEOUT_TP1_TOUCH","executable BID/ASK reached frozen TP1");}
      double current=PositionGetDouble(POSITION_VOLUME),volume=current;
      if(!g_records[i].scale.single_fallback)
        {
         W33ScaleOutVolumePlan v=W33BuildScaleOutVolumePlan(g_records[i].scale.initial_filled_volume,current,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),g_records[i].scale.confirmed_closed_volume);
         if(!v.split_allowed){ScaleOutFallback(i,v.reason);volume=current;}else volume=v.remaining_to_close;
        }
      if(volume<=0 || volume>current+1e-8)continue;
      MqlTradeRequest req;MqlTradeResult result;MqlTradeCheckResult check;ZeroMemory(req);ZeroMemory(result);ZeroMemory(check);
      req.action=TRADE_ACTION_DEAL;req.position=ticket;req.symbol=_Symbol;req.magic=InpMagic;req.type=g_records[i].setup.direction>0?ORDER_TYPE_SELL:ORDER_TYPE_BUY;
      req.volume=NormalizeDouble(volume,8);req.price=g_records[i].setup.direction>0?tick.bid:tick.ask;req.deviation=InpDeviationPoints;req.comment=g_records[i].scale.single_fallback?"W33_SINGLE_TP1":"W33_HALF_TP1";
      long filling=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);req.type_filling=(filling&SYMBOL_FILLING_FOK)!=0?ORDER_FILLING_FOK:((filling&SYMBOL_FILLING_IOC)!=0?ORDER_FILLING_IOC:ORDER_FILLING_RETURN);
      g_records[i].scale.close_attempts++;g_records[i].scale_next_close_at=TimeCurrent()+1;
      if(!OrderCheck(req,check))
        {ScaleOutEvent(i,"SCALEOUT_CLOSE_REJECTED","ORDER_CHECK "+(string)check.retcode+" "+check.comment);if(!g_records[i].scale.single_fallback && (check.retcode==TRADE_RETCODE_INVALID_VOLUME || check.retcode==TRADE_RETCODE_INVALID_CLOSE_VOLUME))ScaleOutFallback(i,"SCALEOUT_BROKER_REJECTED_PARTIAL_VOLUME");continue;}
      g_records[i].scale.request_pending=true;g_records[i].scale.pending_request_volume=req.volume;g_records[i].scale.pending_order=0;g_records[i].scale.pending_request_id=0;
      ScaleOutEvent(i,"SCALEOUT_CLOSE_REQUEST","volume="+DoubleToString(req.volume,8));
      bool sent=OrderSend(req,result);g_records[i].scale.pending_order=result.order;g_records[i].scale.pending_request_id=result.request_id;RegisterScaleOrder(i,result.order);
      if(!sent || !AcceptedDeal(result.retcode))
        {
         g_records[i].scale.request_pending=false;ScaleOutEvent(i,"SCALEOUT_CLOSE_REJECTED","ORDER_SEND "+(string)result.retcode+" "+result.comment);
         if(!g_records[i].scale.single_fallback && (result.retcode==TRADE_RETCODE_INVALID_VOLUME || result.retcode==TRADE_RETCODE_INVALID_CLOSE_VOLUME))ScaleOutFallback(i,"SCALEOUT_BROKER_REJECTED_PARTIAL_VOLUME");
        }
      else ScaleOutEvent(i,"SCALEOUT_CLOSE_ACCEPTED","order="+(string)result.order+" retcode="+(string)result.retcode);
     }
  }
void HandleScaleOutRequest(const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(!InpScaleOut)return;
   for(int i=0;i<ArraySize(g_records);i++)
     {
      if(g_records[i].scale.request_pending && result.request_id==g_records[i].scale.pending_request_id)
        {if(result.order>0){g_records[i].scale.pending_order=result.order;RegisterScaleOrder(i,result.order);}if(!AcceptedDeal(result.retcode)){g_records[i].scale.request_pending=false;ScaleOutEvent(i,"SCALEOUT_CLOSE_REJECTED","REQUEST callback "+(string)result.retcode);if(!g_records[i].scale.single_fallback && (result.retcode==TRADE_RETCODE_INVALID_VOLUME || result.retcode==TRADE_RETCODE_INVALID_CLOSE_VOLUME))ScaleOutFallback(i,"SCALEOUT_BROKER_REJECTED_PARTIAL_VOLUME");}}
      if(g_records[i].scale_be_request_pending && result.request_id==g_records[i].scale_be_request_id && !AcceptedDeal(result.retcode))
        {g_records[i].scale_be_request_pending=false;ScaleOutEvent(i,"SCALEOUT_BE_REJECTED","REQUEST callback "+(string)result.retcode);}
     }
  }
bool AccountScaleOutDeal(const int index,const ulong deal,const double volume)
  {
   if(!InpScaleOut || !g_records[index].scale.planned)return false;
   ulong order=(ulong)HistoryDealGetInteger(deal,DEAL_ORDER);int slot=ScaleOrderIndex(order);
   string comment=HistoryDealGetString(deal,DEAL_COMMENT);if(comment=="")comment=HistoryOrderGetString(order,ORDER_COMMENT);
   if(slot<0 && (StringFind(comment,"W33_HALF_TP1")==0 || StringFind(comment,"W33_SINGLE_TP1")==0)){RegisterScaleOrder(index,order);slot=ScaleOrderIndex(order);g_records[index].scale.pending_order=order;}
   if(slot<0 || g_scale_orders[slot].record!=index)return false;
   g_scale_orders[slot].confirmed+=volume;g_records[index].scale.confirmed_closed_volume+=volume;g_records[index].scale.last_confirmed_deal=deal;
   if(g_records[index].scale.first_confirmed_at==0)g_records[index].scale.first_confirmed_at=TimeCurrent();
   g_records[index].scale.break_even_pending=!g_records[index].scale.single_fallback && g_records[index].scale.confirmed_closed_volume+1e-8>=g_records[index].scale.target_close_volume;
   return true;
  }
#endif
