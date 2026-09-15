#ifndef TICK_SHOCK_TWO_STAGE_BARRIER_CANDIDATE_MQH
#define TICK_SHOCK_TWO_STAGE_BARRIER_CANDIDATE_MQH
#include "TickShockTwoStageModel.mqh"
#include "TickShockTwoStagePolicy.mqh"
#include "TickShockBarrierCore.mqh"
input double InpCandidateTpATR=0.68;
input double InpCandidateSlATR=0.55;
input double InpCandidateRiskMoney=10.0;
input int InpCandidateHoldSeconds=14400;
input int InpCandidateSpacingSeconds=900;
input long InpCandidateMagic=260914901;
struct TSGIntent {string episode,symbol;int direction;long t0,processing,quote;double atr;};
struct TSGTrade {
 TSGIntent intent;ulong identifier,ticket;long request_msc,quote_msc,entry_msc;
 double requested,filled,entry,sl,tp,risk;string reason;long last_close_attempt;
};
TSGTrade g_tsg_trades[];
TSGIntent g_tsg_queue[64],g_tsg_pending;
bool g_tsg_pending_valid=false,g_tsg_stopping=false,g_tsg_initialized=false;
int g_tsg_queue_count=0,g_tsg_signals=INVALID_HANDLE,g_tsg_actions=INVALID_HANDLE,g_tsg_csv=INVALID_HANDLE;
long g_tsg_last_fill=0,g_tsg_errors=0,g_tsg_closed=0,g_tsg_signal_count=0;
int g_tsg_peak_positions=0;double g_tsg_peak_risk=0;
string g_tsg_folder="";
long TSGNow(){MqlTick t;long n=(long)TimeCurrent()*1000;if(SymbolInfoTick(_Symbol,t))n=MathMax(n,t.time_msc);return n;}
void TSGAction(const TSGIntent &p,const string status,const uint retcode=0,const string detail="")
 {if(g_tsg_actions!=INVALID_HANDLE){FileWrite(g_tsg_actions,p.episode,p.symbol,p.direction,TSGNow(),status,retcode,detail);FileFlush(g_tsg_actions);}}
ENUM_ORDER_TYPE_FILLING TSGFilling(const string symbol)
 {long f=SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);return (f&SYMBOL_FILLING_FOK)!=0?ORDER_FILLING_FOK:ORDER_FILLING_IOC;}
bool TSGSend(MqlTradeRequest &r,MqlTradeResult &out,const TSGIntent &p,const string op)
 {
  if(!MQLInfoInteger(MQL_TESTER))return false;
  MqlTradeCheckResult c;ZeroMemory(c);ResetLastError();
  if(!OrderCheck(r,c)){TSGAction(p,op+"_CHECK_REJECT",c.retcode,c.comment);return false;}
  bool ok=OrderSend(r,out);TSGAction(p,op,out.retcode,"order="+(string)out.order+" deal="+(string)out.deal+" external="+(string)out.retcode_external);
  return ok&&(out.retcode==TRADE_RETCODE_DONE||out.retcode==TRADE_RETCODE_DONE_PARTIAL);
 }
bool TSGSelect(TSGTrade &t)
 {
  for(int i=0;i<PositionsTotal();++i){ulong ticket=PositionGetTicket(i);
   if(ticket>0&&(ulong)PositionGetInteger(POSITION_IDENTIFIER)==t.identifier&&PositionGetInteger(POSITION_MAGIC)==InpCandidateMagic&&PositionGetString(POSITION_SYMBOL)==t.intent.symbol){t.ticket=ticket;return true;}}
  return false;
 }
bool TSGCollect(TSGTrade &t)
 {
  if(TSGSelect(t))return false;
  if(!HistorySelectByPosition(t.identifier))return false;
  double vin=0,vout=0,pin=0,pout=0,profit=0,commission=0,fee=0,swap=0;int ins=0,outs=0;long start=0,end=0;string reason=t.reason;
  for(int i=0;i<HistoryDealsTotal();++i){ulong d=HistoryDealGetTicket(i);if(d==0)continue;
   if(HistoryDealGetInteger(d,DEAL_MAGIC)!=InpCandidateMagic||HistoryDealGetString(d,DEAL_SYMBOL)!=t.intent.symbol){++g_tsg_errors;g_tsg_stopping=true;return false;}
   ENUM_DEAL_ENTRY kind=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(d,DEAL_ENTRY);double v=HistoryDealGetDouble(d,DEAL_VOLUME),p=HistoryDealGetDouble(d,DEAL_PRICE);long tm=HistoryDealGetInteger(d,DEAL_TIME_MSC);
   profit+=HistoryDealGetDouble(d,DEAL_PROFIT);commission+=HistoryDealGetDouble(d,DEAL_COMMISSION);fee+=HistoryDealGetDouble(d,DEAL_FEE);swap+=HistoryDealGetDouble(d,DEAL_SWAP);
   if(kind==DEAL_ENTRY_IN){vin+=v;pin+=v*p;++ins;if(start==0||tm<start)start=tm;}
   else if(kind==DEAL_ENTRY_OUT||kind==DEAL_ENTRY_OUT_BY){vout+=v;pout+=v*p;++outs;end=MathMax(end,tm);long dr=HistoryDealGetInteger(d,DEAL_REASON);if(dr==DEAL_REASON_TP)reason="TP";else if(dr==DEAL_REASON_SL)reason="SL";else if(reason=="")reason=EnumToString((ENUM_DEAL_REASON)dr);}
  }
  if(vin<=0||MathAbs(vin-vout)>1e-8||t.risk<=0)return false;
  double net=profit+commission+fee+swap;
  FileWrite(g_tsg_csv,t.intent.episode,t.intent.symbol,t.intent.direction,t.intent.t0,t.intent.processing,t.request_msc,t.quote_msc,start,end,t.requested,vin,vout,pin/vin,pout/vout,t.sl,t.tp,t.risk,profit,commission,fee,swap,net,profit/t.risk,net/t.risk,(end-start)/1000.0,reason,ins,outs,t.identifier,t.intent.atr,InpCandidateTpATR,InpCandidateSlATR);
  FileFlush(g_tsg_csv);++g_tsg_closed;return true;
 }
bool TSGClose(TSGTrade &t,const string reason)
 {
  if(!TSGSelect(t))return true;
  long now=TSGNow();if(t.last_close_attempt!=0&&now-t.last_close_attempt<1000)return false;
  t.last_close_attempt=now;t.reason=reason;
  MqlTick q;if(!SymbolInfoTick(t.intent.symbol,q)||q.bid<=0||q.ask<=q.bid)return false;
  MqlTradeRequest r;MqlTradeResult out;ZeroMemory(r);ZeroMemory(out);
  r.action=TRADE_ACTION_DEAL;r.position=t.ticket;r.symbol=t.intent.symbol;r.magic=InpCandidateMagic;r.volume=PositionGetDouble(POSITION_VOLUME);
  r.type=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?ORDER_TYPE_SELL:ORDER_TYPE_BUY;r.price=r.type==ORDER_TYPE_BUY?q.ask:q.bid;r.type_filling=TSGFilling(r.symbol);r.deviation=10;
  return TSGSend(r,out,t.intent,"CLOSE_"+reason);
 }
void TSTCManage()
 {
  if(!MQLInfoInteger(MQL_TESTER)||!g_tsg_initialized)return;
  for(int i=ArraySize(g_tsg_trades)-1;i>=0;--i){
   if(TSGSelect(g_tsg_trades[i])&&TSGNow()>=g_tsg_trades[i].entry_msc+(long)InpCandidateHoldSeconds*1000)TSGClose(g_tsg_trades[i],"TIME");
   if(TSGCollect(g_tsg_trades[i])){int last=ArraySize(g_tsg_trades)-1;if(i!=last)g_tsg_trades[i]=g_tsg_trades[last];ArrayResize(g_tsg_trades,last);}
  }
  double risk=0;for(int i=0;i<ArraySize(g_tsg_trades);++i)risk+=g_tsg_trades[i].risk;
  g_tsg_peak_risk=MathMax(g_tsg_peak_risk,risk);g_tsg_peak_positions=MathMax(g_tsg_peak_positions,ArraySize(g_tsg_trades));
 }
bool TSTCInit(const string folder)
 {
  if(!MQLInfoInteger(MQL_TESTER))return false;
  if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING){Print("barrier grid requires hedging accounting; no netting substitution");return false;}
  if(TS2_ROLLING||!MathIsValidNumber(InpCandidateTpATR)||!MathIsValidNumber(InpCandidateSlATR)||!MathIsValidNumber(InpCandidateRiskMoney)||InpCandidateTpATR<=0||InpCandidateSlATR<=0||InpCandidateRiskMoney<=0||InpCandidateHoldSeconds<=0||InpCandidateSpacingSeconds<900||InpCandidateMagic<=0||PositionsTotal()>0||OrdersTotal()>0)return false;
  g_tsg_folder=folder;TS2Reset();
  if(FileIsExist(folder+"\\candidate_trades.csv",FILE_COMMON)||FileIsExist(folder+"\\candidate_signals.csv",FILE_COMMON))return false;
  g_tsg_signals=FileOpen(folder+"\\candidate_signals.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
  g_tsg_actions=FileOpen(folder+"\\candidate_actions.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
  g_tsg_csv=FileOpen(folder+"\\candidate_trades.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
  if(g_tsg_signals==INVALID_HANDLE||g_tsg_actions==INVALID_HANDLE||g_tsg_csv==INVALID_HANDLE)return false;
  FileWrite(g_tsg_signals,"episode_id","symbol","t0_msc","processing_msc","source_quote_msc","long_score","short_score","direction","atr14_m5","stage1_score","decision_threshold");
  FileWrite(g_tsg_actions,"episode_id","symbol","direction","action_msc","status","retcode","detail");
  FileWrite(g_tsg_csv,"episode_id","symbol","direction","signal_msc","processing_msc","request_msc","quote_msc","entry_msc","exit_msc","requested_volume","filled_volume","closed_volume","entry_price","exit_price","sl","tp","risk_amount","gross_profit","commission","fee","swap","net_profit","gross_r","net_r","hold_seconds","exit_reason","entry_deals","exit_deals","position_identifier","atr14_m5","tp_atr","sl_atr");
  g_tsg_initialized=true;return true;
 }
void TSTCOnSnapshot(const string episode,const string symbol,const long t0,const long processing,const long quote,const TSTechSnapshot &f)
 {
  if(!g_tsg_initialized||g_tsg_stopping)return;
  double raw[];ArrayResize(raw,f.count);for(int i=0;i<f.count;++i)raw[i]=f.available[i]?StringToDouble(DoubleToString(f.values[i],12)):EMPTY_VALUE;
  double a=0,l=0,s=0,cut=0;int side=TS2Decision(raw,processing,a,l,s,cut);
  FileWrite(g_tsg_signals,episode,symbol,t0,processing,quote,DoubleToString(l,15),DoubleToString(s,15),side,DoubleToString(f.atr14_m5,12),DoubleToString(a,15),DoubleToString(cut,15));FileFlush(g_tsg_signals);++g_tsg_signal_count;
  if(!g_ts2_policy_valid){g_tsg_stopping=true;++g_tsg_errors;return;}
  if(side==0)return;
  TSGIntent p;p.episode=episode;p.symbol=symbol;p.t0=t0;p.processing=processing;p.quote=quote;p.direction=side;p.atr=f.atr14_m5;
  if(g_tsg_queue_count>=64){TSGAction(p,"QUEUE_CAPACITY");g_tsg_stopping=true;++g_tsg_errors;return;}
  g_tsg_queue[g_tsg_queue_count++]=p;
 }
void TSGTryEntry()
 {
  if(!g_tsg_pending_valid||g_tsg_stopping||!MQLInfoInteger(MQL_TESTER))return;
  TSGIntent p=g_tsg_pending;long now=TSGNow();
  if(now>p.t0+30000){TSGAction(p,"ENTRY_TIMEOUT");g_tsg_pending_valid=false;return;}
  MqlTick q;if(!SymbolInfoTick(p.symbol,q))return;
  if(q.time_msc<=p.t0||q.time_msc<=p.quote||q.time_msc<p.processing+InpSubmitLatencyMs||q.time_msc>now||now-q.time_msc>InpMaxQuoteAgeMs)return;
  g_tsg_pending_valid=false;
  if(!TSGSpacing(g_tsg_last_fill,now,InpCandidateSpacingSeconds)){TSGAction(p,"ENTRY_INTERVAL");return;}
  if(OrdersTotal()>0){TSGAction(p,"OUTSTANDING_ORDER");return;}
  double tick=SymbolInfoDouble(p.symbol,SYMBOL_TRADE_TICK_SIZE),point=SymbolInfoDouble(p.symbol,SYMBOL_POINT),price=p.direction>0?q.ask:q.bid,sl=0,tp=0;
  double stops=SymbolInfoInteger(p.symbol,SYMBOL_TRADE_STOPS_LEVEL)*point;
  if(!TSGBounds(p.direction,price,p.atr,InpCandidateTpATR,InpCandidateSlATR,tick,sl,tp)||!TSGBrokerBounds(p.direction,q.bid,q.ask,sl,tp,stops)){TSGAction(p,"BROKER_GEOMETRY_REJECT");return;}
  ENUM_ORDER_TYPE type=p.direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;double loss=0;
  if(!OrderCalcProfit(type,p.symbol,1,price,sl,loss)||loss>=0){TSGAction(p,"RISK_CALC_REJECT");return;}
  double step=SymbolInfoDouble(p.symbol,SYMBOL_VOLUME_STEP),minimum=SymbolInfoDouble(p.symbol,SYMBOL_VOLUME_MIN),maximum=SymbolInfoDouble(p.symbol,SYMBOL_VOLUME_MAX);
  if(step<=0||minimum<=0||maximum<minimum){TSGAction(p,"VOLUME_SPEC_REJECT");return;}
  double budget=MathMin(InpCandidateRiskMoney,AccountInfoDouble(ACCOUNT_EQUITY)*0.0025);
  double volume=MathFloor(MathMin(maximum,budget/(-loss))/step+1e-10)*step;
  if(volume<minimum-1e-10){TSGAction(p,"VOLUME_BELOW_MINIMUM");return;}
  int n=ArraySize(g_tsg_trades);if(ArrayResize(g_tsg_trades,n+1)!=n+1){g_tsg_stopping=true;++g_tsg_errors;return;}
  TSGTrade t;ZeroMemory(t);t.intent=p;t.request_msc=now;t.quote_msc=q.time_msc;t.requested=volume;t.sl=sl;t.tp=tp;
  MqlTradeRequest r;MqlTradeResult out;ZeroMemory(r);ZeroMemory(out);
  r.action=TRADE_ACTION_DEAL;r.symbol=p.symbol;r.magic=InpCandidateMagic;r.type=type;r.volume=volume;r.price=price;r.sl=sl;r.tp=tp;r.type_filling=TSGFilling(p.symbol);r.deviation=10;r.comment="TS2 barrier grid";
  if(!TSGSend(r,out,p,"ENTRY")){ArrayResize(g_tsg_trades,n);return;}
  // Resolve the newly created identity, never PositionSelect(symbol) or first magic match.
  if(out.deal>0&&HistoryDealSelect(out.deal)){t.identifier=(ulong)HistoryDealGetInteger(out.deal,DEAL_POSITION_ID);t.entry_msc=HistoryDealGetInteger(out.deal,DEAL_TIME_MSC);t.entry=HistoryDealGetDouble(out.deal,DEAL_PRICE);t.filled=HistoryDealGetDouble(out.deal,DEAL_VOLUME);}
  if(t.identifier==0&&out.order>0&&PositionSelectByTicket(out.order)){t.identifier=(ulong)PositionGetInteger(POSITION_IDENTIFIER);}
  if(t.identifier==0){TSGAction(p,"UNRESOLVED_FILL");g_tsg_stopping=true;++g_tsg_errors;ArrayResize(g_tsg_trades,n);return;}
  if(TSGSelect(t)){t.entry=PositionGetDouble(POSITION_PRICE_OPEN);t.filled=PositionGetDouble(POSITION_VOLUME);t.entry_msc=PositionGetInteger(POSITION_TIME_MSC);}
  g_tsg_last_fill=t.entry_msc;double actual=0;
  if(!OrderCalcProfit(type,p.symbol,t.filled,t.entry,sl,actual)||actual>=0){t.risk=-loss*t.filled;g_tsg_trades[n]=t;TSGClose(g_tsg_trades[n],"EXECUTION_GUARD");++g_tsg_errors;return;}
  t.risk=-actual;g_tsg_trades[n]=t;
  if(t.risk>budget*1.05){TSGClose(g_tsg_trades[n],"EXECUTION_GUARD");return;}
  // Re-anchor targets to actual fill, never widen the already protective SL.
  double newsl=0,newtp=0;
  if(!TSGBounds(p.direction,t.entry,p.atr,InpCandidateTpATR,InpCandidateSlATR,tick,newsl,newtp)){TSGClose(g_tsg_trades[n],"EXECUTION_GUARD");return;}
  newsl=p.direction>0?MathMax(sl,newsl):MathMin(sl,newsl);
  if(TSGSelect(g_tsg_trades[n])&&(MathAbs(newsl-sl)>tick*.1||MathAbs(newtp-tp)>tick*.1)){
   MqlTick current;double freeze=SymbolInfoInteger(p.symbol,SYMBOL_TRADE_FREEZE_LEVEL)*point;
   if(!SymbolInfoTick(p.symbol,current)||!TSGBrokerBounds(p.direction,current.bid,current.ask,newsl,newtp,stops)||!TSGBrokerBounds(p.direction,current.bid,current.ask,sl,tp,freeze)){TSGClose(g_tsg_trades[n],"EXECUTION_GUARD");return;}
   MqlTradeRequest modify;MqlTradeResult changed;ZeroMemory(modify);ZeroMemory(changed);
   modify.action=TRADE_ACTION_SLTP;modify.position=g_tsg_trades[n].ticket;modify.symbol=p.symbol;modify.magic=InpCandidateMagic;modify.sl=newsl;modify.tp=newtp;
   if(!TSGSend(modify,changed,p,"FILL_GEOMETRY_ADJUST")){TSGClose(g_tsg_trades[n],"EXECUTION_GUARD");return;}
   g_tsg_trades[n].sl=newsl;g_tsg_trades[n].tp=newtp;
   if(OrderCalcProfit(type,p.symbol,t.filled,t.entry,newsl,actual)&&actual<0)g_tsg_trades[n].risk=-actual;
  }
  TSTCManage();
 }
void TSTCPump()
 {
  if(g_tsg_stopping||!g_tsg_initialized)return;TSTCManage();TSGTryEntry();
  for(int i=1;i<g_tsg_queue_count;++i){TSGIntent p=g_tsg_queue[i];int j=i-1;while(j>=0&&(g_tsg_queue[j].processing>p.processing||(g_tsg_queue[j].processing==p.processing&&StringCompare(g_tsg_queue[j].episode,p.episode)>0))){g_tsg_queue[j+1]=g_tsg_queue[j];--j;}g_tsg_queue[j+1]=p;}
  for(int i=0;i<g_tsg_queue_count;++i){TSGIntent p=g_tsg_queue[i];if(g_tsg_pending_valid||!TSGSpacing(g_tsg_last_fill,p.processing,InpCandidateSpacingSeconds)){TSGAction(p,"ENTRY_INTERVAL");continue;}g_tsg_pending=p;g_tsg_pending_valid=true;TSGTryEntry();}
  g_tsg_queue_count=0;
 }
void TSTCFinish()
 {
  if(!MQLInfoInteger(MQL_TESTER)||!g_tsg_initialized)return;g_tsg_stopping=true;g_tsg_pending_valid=false;
  for(int i=0;i<ArraySize(g_tsg_trades);++i){g_tsg_trades[i].last_close_attempt=0;TSGClose(g_tsg_trades[i],"END_OF_TEST");}
  TSTCManage();int remaining=0;for(int i=0;i<PositionsTotal();++i){PositionGetTicket(i);if(PositionGetInteger(POSITION_MAGIC)==InpCandidateMagic)++remaining;}
  if(remaining>0||ArraySize(g_tsg_trades)>0)++g_tsg_errors;
  int f=FileOpen(g_tsg_folder+"\\candidate_summary.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
  if(f!=INVALID_HANDLE){FileWrite(f,"signals","closed","errors","remaining_positions","unreconciled_records","peak_positions","peak_sl_risk_money","margin_mode","tp_atr","sl_atr","spacing_seconds","hold_seconds");FileWrite(f,g_tsg_signal_count,g_tsg_closed,g_tsg_errors,remaining,ArraySize(g_tsg_trades),g_tsg_peak_positions,g_tsg_peak_risk,AccountInfoInteger(ACCOUNT_MARGIN_MODE),InpCandidateTpATR,InpCandidateSlATR,InpCandidateSpacingSeconds,InpCandidateHoldSeconds);FileClose(f);}
  PrintFormat("barrier_candidate closed=%I64d errors=%I64d remaining=%d peak=%d",g_tsg_closed,g_tsg_errors,remaining,g_tsg_peak_positions);
  FileClose(g_tsg_signals);FileClose(g_tsg_actions);FileClose(g_tsg_csv);g_tsg_initialized=false;
 }
#endif
