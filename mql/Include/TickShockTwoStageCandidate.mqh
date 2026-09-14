#ifndef TICK_SHOCK_TECHNICAL_CANDIDATE_MQH
#define TICK_SHOCK_TECHNICAL_CANDIDATE_MQH
#include "TickShockTwoStageModel.mqh"
#include "TickShockTwoStagePolicy.mqh"

// Tester-only adapter. No orders are ever sent from a replayed historical tick.
input double InpTechnicalRiskMoney=10.0;
input long InpTechnicalMagic=260914521;
struct TSTCIntent {string episode,symbol;long t0,processing,quote;int direction;double atr;};
TSTCIntent g_tstc_queue[64],g_tstc_pending,g_tstc_trade;
int g_tstc_count=0,g_tstc_signals=INVALID_HANDLE,g_tstc_actions=INVALID_HANDLE,g_tstc_trades=INVALID_HANDLE;
bool g_tstc_stopping=false,g_tstc_has_pending=false,g_tstc_has_trade=false;
long g_tstc_errors=0,g_tstc_closed=0,g_tstc_signal_rows=0,g_tstc_request_msc=0,g_tstc_quote_msc=0,g_tstc_last_release=0;
ulong g_tstc_position=0,g_tstc_identifier=0;
double g_tstc_risk=0,g_tstc_sl=0,g_tstc_tp=0,g_tstc_requested=0,g_tstc_fill=0,g_tstc_expected_distance=0;
string g_tstc_close_reason="";

long TSTCNow()
  {MqlTick chart;long now=(long)TimeCurrent()*1000;if(SymbolInfoTick(_Symbol,chart))now=MathMax(now,chart.time_msc);return now;}
void TSTCAction(const TSTCIntent &p,const string status,const long q=0,const uint retcode=0,const string detail="")
  {if(g_tstc_actions!=INVALID_HANDLE){FileWrite(g_tstc_actions,p.episode,p.symbol,p.direction,p.t0,p.processing,TSTCNow(),q,status,retcode,detail);FileFlush(g_tstc_actions);}}

input string InpRollingSeedFile="two_stage_frozen_20260913\\rolling_seed.csv";
string g_ts2_folder="";
bool TS2ReadSeed()
  {
   TS2Reset();if(!TS2_ROLLING)return true;
   int file=FileOpen(InpRollingSeedFile,FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   if(file==INVALID_HANDLE)return false;
   FileReadString(file);FileReadString(file);long last=-1;
   while(!FileIsEnding(file))
     {
      string first=FileReadString(file);if(first==""&&FileIsEnding(file))break;
      string value=FileReadString(file);long time=StringToInteger(first);
      if(first==""||value==""||time<last){FileClose(file);return false;}
      last=time;TS2Append(time,StringToDouble(value));
     }
   FileClose(file);return g_ts2_policy_valid&&ArraySize(g_ts2_times)>0;
  }
void TS2WriteSeed()
  {
   if(g_ts2_folder==""||!MQLInfoInteger(MQL_TESTER))return;
   string path=g_ts2_folder+"\\rolling_state.csv";
   if(FileIsExist(path,FILE_COMMON)){++g_tstc_errors;return;}
   int file=FileOpen(path,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   if(file==INVALID_HANDLE){++g_tstc_errors;return;}
   FileWrite(file,"time_msc","score");
   for(int i=0;i<ArraySize(g_ts2_times);++i)FileWrite(file,g_ts2_times[i],DoubleToString(g_ts2_scores[i],17));
   FileClose(file);
  }

bool TSTCInit(const string folder)
  {
   if(!MQLInfoInteger(MQL_TESTER)||!MathIsValidNumber(InpTechnicalRiskMoney)||InpTechnicalRiskMoney<=0||InpTechnicalMagic<=0)return false;
   g_ts2_folder=folder;if(!TS2ReadSeed())return false;
   string base=folder+"\\candidate_";
   if(FileIsExist(base+"signals.csv",FILE_COMMON)||FileIsExist(base+"trades.csv",FILE_COMMON))return false;
   g_tstc_signals=FileOpen(base+"signals.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   g_tstc_actions=FileOpen(base+"actions.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   g_tstc_trades=FileOpen(base+"trades.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   if(g_tstc_signals==INVALID_HANDLE||g_tstc_actions==INVALID_HANDLE||g_tstc_trades==INVALID_HANDLE)return false;
   FileWrite(g_tstc_signals,"episode_id","symbol","t0_msc","processing_msc","source_quote_msc","long_score","short_score","direction","atr14_m5","stage1_score","decision_threshold");
   FileWrite(g_tstc_actions,"episode_id","symbol","direction","t0_msc","processing_msc","action_msc","quote_msc","status","retcode","detail");
   FileWrite(g_tstc_trades,"episode_id","symbol","direction","signal_msc","processing_msc","request_msc","quote_msc","entry_msc","exit_msc","requested_volume","filled_volume","closed_volume","entry_price","exit_price","sl","tp","risk_amount","gross_profit","commission","fee","swap","net_profit","gross_r","net_r","hold_seconds","exit_reason","entry_deals","exit_deals","position_identifier");
   return true;
  }
void TSTCOnSnapshot(const string episode,const string symbol,const long t0,const long processing,const long quote,const TSTechSnapshot &f)
  {
   double raw[];ArrayResize(raw,f.count);
   for(int i=0;i<f.count;++i)raw[i]=f.available[i]?StringToDouble(DoubleToString(f.values[i],12)):EMPTY_VALUE;
   double s1=0,ls=0,ss=0,threshold=0;int direction=TS2Decision(raw,processing,s1,ls,ss,threshold);
   if(g_tstc_signals!=INVALID_HANDLE)
     {FileWrite(g_tstc_signals,episode,symbol,t0,processing,quote,DoubleToString(ls,15),DoubleToString(ss,15),direction,DoubleToString(f.atr14_m5,12),DoubleToString(s1,15),threshold==DBL_MAX?"":DoubleToString(threshold,15));FileFlush(g_tstc_signals);++g_tstc_signal_rows;}
   if(!g_ts2_policy_valid){++g_tstc_errors;g_tstc_stopping=true;return;}
   if(direction==0||g_tstc_stopping)return;
   TSTCIntent p;p.episode=episode;p.symbol=symbol;p.t0=t0;p.processing=processing;p.quote=quote;p.direction=direction;p.atr=f.atr14_m5;
   if(g_tstc_count>=64){++g_tstc_errors;TSTCAction(p,"QUEUE_CAPACITY");return;}
   g_tstc_queue[g_tstc_count++]=p;
  }
ENUM_ORDER_TYPE_FILLING TSTCFilling(const string symbol)
  {long mode=SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);if((mode&SYMBOL_FILLING_FOK)!=0)return ORDER_FILLING_FOK;return ORDER_FILLING_IOC;}
bool TSTCOwnPosition()
  {
   if(g_tstc_position>0&&PositionSelectByTicket(g_tstc_position))return PositionGetInteger(POSITION_MAGIC)==InpTechnicalMagic;
   for(int i=0;i<PositionsTotal();++i){ulong ticket=PositionGetTicket(i);if(ticket>0&&PositionGetInteger(POSITION_MAGIC)==InpTechnicalMagic){g_tstc_position=ticket;return true;}}
   return false;
  }
void TSTCCollect()
  {
   if(!g_tstc_has_trade||TSTCOwnPosition())return;
   if(!HistorySelectByPosition(g_tstc_identifier)){++g_tstc_errors;return;}
   double in_volume=0,out_volume=0,in_value=0,out_value=0,profit=0,commission=0,fee=0,swap=0;long entry=0,exit=0;int ins=0,outs=0;string reason=g_tstc_close_reason;
   for(int i=0;i<HistoryDealsTotal();++i)
     {
      ulong ticket=HistoryDealGetTicket(i);if(ticket==0)continue;
      ENUM_DEAL_ENTRY kind=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket,DEAL_ENTRY);
      double volume=HistoryDealGetDouble(ticket,DEAL_VOLUME),price=HistoryDealGetDouble(ticket,DEAL_PRICE);long time=HistoryDealGetInteger(ticket,DEAL_TIME_MSC);
      profit+=HistoryDealGetDouble(ticket,DEAL_PROFIT);commission+=HistoryDealGetDouble(ticket,DEAL_COMMISSION);fee+=HistoryDealGetDouble(ticket,DEAL_FEE);swap+=HistoryDealGetDouble(ticket,DEAL_SWAP);
      if(kind==DEAL_ENTRY_IN){in_volume+=volume;in_value+=volume*price;++ins;if(entry==0||time<entry)entry=time;}
      else if(kind==DEAL_ENTRY_OUT||kind==DEAL_ENTRY_OUT_BY){out_volume+=volume;out_value+=volume*price;++outs;exit=MathMax(exit,time);ENUM_DEAL_REASON dr=(ENUM_DEAL_REASON)HistoryDealGetInteger(ticket,DEAL_REASON);if(dr==DEAL_REASON_SL)reason="SL";else if(dr==DEAL_REASON_TP)reason="TP";else if(reason=="")reason=EnumToString(dr);}
     }
   if(in_volume<=0||MathAbs(in_volume-out_volume)>1e-8||g_tstc_risk<=0){++g_tstc_errors;return;}
   double net=profit+commission+fee+swap;
   FileWrite(g_tstc_trades,g_tstc_trade.episode,g_tstc_trade.symbol,g_tstc_trade.direction,g_tstc_trade.t0,g_tstc_trade.processing,g_tstc_request_msc,g_tstc_quote_msc,entry,exit,g_tstc_requested,in_volume,out_volume,in_value/in_volume,out_value/out_volume,g_tstc_sl,g_tstc_tp,g_tstc_risk,profit,commission,fee,swap,net,profit/g_tstc_risk,net/g_tstc_risk,(exit-entry)/1000.0,reason,ins,outs,g_tstc_identifier);FileFlush(g_tstc_trades);
   ++g_tstc_closed;g_tstc_last_release=exit;g_tstc_has_trade=false;g_tstc_position=0;g_tstc_identifier=0;
  }
bool TSTCSend(MqlTradeRequest &request,MqlTradeResult &result,const TSTCIntent &p,const string operation,const long quote)
  {
   if(!MQLInfoInteger(MQL_TESTER)){++g_tstc_errors;return false;}
   MqlTradeCheckResult check;ZeroMemory(check);ResetLastError();
   if(!OrderCheck(request,check)){TSTCAction(p,operation+"_CHECK_REJECT",quote,check.retcode,check.comment);return false;}
   ResetLastError();bool sent=OrderSend(request,result);
   TSTCAction(p,operation,quote,result.retcode,"order="+(string)result.order+" deal="+(string)result.deal+" external="+(string)result.retcode_external+" request="+(string)result.request_id);
   return sent&&(result.retcode==TRADE_RETCODE_DONE||result.retcode==TRADE_RETCODE_DONE_PARTIAL);
  }
bool TSTCClose(const string reason)
  {
   if(!TSTCOwnPosition())return true;
   string symbol=PositionGetString(POSITION_SYMBOL);double volume=PositionGetDouble(POSITION_VOLUME);long type=PositionGetInteger(POSITION_TYPE);
   MqlTick q;if(!SymbolInfoTick(symbol,q))return false;
   MqlTradeRequest request;MqlTradeResult result;ZeroMemory(request);ZeroMemory(result);
   request.action=TRADE_ACTION_DEAL;request.symbol=symbol;request.position=g_tstc_position;request.magic=InpTechnicalMagic;request.volume=volume;
   request.type=type==POSITION_TYPE_BUY?ORDER_TYPE_SELL:ORDER_TYPE_BUY;request.price=type==POSITION_TYPE_BUY?q.bid:q.ask;request.type_filling=TSTCFilling(symbol);request.deviation=10;
   g_tstc_close_reason=reason;return TSTCSend(request,result,g_tstc_trade,"CLOSE_"+reason,q.time_msc);
  }
void TSTCManage()
  {
   if(!MQLInfoInteger(MQL_TESTER))return;
   TSTCCollect();
   if(TSTCOwnPosition())
     {
      long opened=PositionGetInteger(POSITION_TIME_MSC);
      if(TSTCNow()>=opened+(long)TS2_HOLD_SECONDS*1000)TSTCClose("TIME");
     }
   TSTCCollect();
  }
void TSTCTryEntry()
  {
   if(!g_tstc_has_pending||!MQLInfoInteger(MQL_TESTER))return;
   TSTCIntent p=g_tstc_pending;long now=TSTCNow();
   if(now>p.t0+30000){TSTCAction(p,"NO_ENTRY_TIMEOUT");g_tstc_has_pending=false;return;}
   MqlTick q;if(!SymbolInfoTick(p.symbol,q))return;
   if(q.time_msc<=p.t0||q.time_msc<=p.quote||q.time_msc<p.processing+InpSubmitLatencyMs||q.time_msc>now||now-q.time_msc>InpMaxQuoteAgeMs)return;
   g_tstc_has_pending=false;
   if(PositionsTotal()>0||OrdersTotal()>0){TSTCAction(p,"POSITION_CONFLICT",q.time_msc);return;}
   if(p.atr<=0||q.bid<=0||q.ask<=q.bid){TSTCAction(p,"INVALID_QUOTE",q.time_msc);return;}
   // One ATR is the normalization/sizing distance, NOT a broker-side protective stop.
   double price=p.direction>0?q.ask:q.bid;
   ENUM_ORDER_TYPE side=p.direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;double loss=0;
   if(!OrderCalcProfit(side,p.symbol,1.0,price,price-p.direction*p.atr,loss)||loss>=0){TSTCAction(p,"RISK_CALC_FAILED",q.time_msc);return;}
   double step=SymbolInfoDouble(p.symbol,SYMBOL_VOLUME_STEP),minimum=SymbolInfoDouble(p.symbol,SYMBOL_VOLUME_MIN),maximum=SymbolInfoDouble(p.symbol,SYMBOL_VOLUME_MAX);
   if(step<=0){++g_tstc_errors;return;}
   double budget=MathMin(InpTechnicalRiskMoney,AccountInfoDouble(ACCOUNT_EQUITY)*0.0025);
   double volume=MathFloor(MathMin(maximum,budget/(-loss))/step+1e-10)*step;
   if(volume<minimum-1e-10){TSTCAction(p,"VOLUME_BELOW_MINIMUM",q.time_msc);return;}
   MqlTradeRequest request;MqlTradeResult result;ZeroMemory(request);ZeroMemory(result);
   request.action=TRADE_ACTION_DEAL;request.symbol=p.symbol;request.magic=InpTechnicalMagic;request.type=side;request.volume=volume;request.price=price;
   request.sl=0;request.tp=0;request.type_filling=TSTCFilling(p.symbol);request.deviation=10;request.comment="TS2 diagnostic time";
   g_tstc_request_msc=now;g_tstc_quote_msc=q.time_msc;g_tstc_trade=p;g_tstc_requested=volume;g_tstc_close_reason="";
   if(!TSTCSend(request,result,p,"ENTRY",q.time_msc))return;
   if(!TSTCOwnPosition()){++g_tstc_errors;TSTCAction(p,"FILL_POSITION_NOT_OBSERVED",q.time_msc);return;}
   g_tstc_has_trade=true;g_tstc_identifier=(ulong)PositionGetInteger(POSITION_IDENTIFIER);g_tstc_fill=PositionGetDouble(POSITION_PRICE_OPEN);
   double filled=PositionGetDouble(POSITION_VOLUME);g_tstc_sl=0;g_tstc_tp=0;g_tstc_expected_distance=p.atr;
   double actual=0;
   if(!OrderCalcProfit(side,p.symbol,filled,g_tstc_fill,g_tstc_fill-p.direction*p.atr,actual)||actual>=0)
     {g_tstc_risk=-loss*filled;++g_tstc_errors;TSTCClose("EXECUTION_GUARD");return;}
   g_tstc_risk=-actual;
   if(g_tstc_risk>budget*1.05){TSTCClose("EXECUTION_GUARD");return;}
  }
void TSTCPump()
  {
   if(g_tstc_stopping||!MQLInfoInteger(MQL_TESTER))return;
   TSTCManage();
   for(int i=1;i<g_tstc_count;++i){TSTCIntent p=g_tstc_queue[i];int j=i-1;while(j>=0&&(g_tstc_queue[j].processing>p.processing||(g_tstc_queue[j].processing==p.processing&&(g_tstc_queue[j].t0>p.t0||(g_tstc_queue[j].t0==p.t0&&StringCompare(g_tstc_queue[j].episode,p.episode)>0))))){g_tstc_queue[j+1]=g_tstc_queue[j];--j;}g_tstc_queue[j+1]=p;}
   TSTCTryEntry();
   for(int i=0;i<g_tstc_count;++i)
     {
      TSTCIntent p=g_tstc_queue[i];
      if(g_tstc_has_pending||g_tstc_has_trade||TSTCOwnPosition()||p.processing<=g_tstc_last_release){TSTCAction(p,"OVERLAP_SKIP");continue;}
      g_tstc_pending=p;g_tstc_has_pending=true;TSTCTryEntry();
     }
   g_tstc_count=0;
  }
void TSTCFinish()
  {
   g_tstc_stopping=true;g_tstc_has_pending=false;
   if(MQLInfoInteger(MQL_TESTER)){TSTCClose("END_OF_TEST");TSTCCollect();}
   int remaining=0;for(int i=0;i<PositionsTotal();++i){ulong ticket=PositionGetTicket(i);if(ticket>0&&PositionGetInteger(POSITION_MAGIC)==InpTechnicalMagic)++remaining;}
   TS2WriteSeed();if(!g_ts2_policy_valid)++g_tstc_errors;
   if(remaining>0)++g_tstc_errors;
   PrintFormat("technical_candidate signals=%I64d closed=%I64d errors=%I64d remaining_positions=%d tester_only=true",g_tstc_signal_rows,g_tstc_closed,g_tstc_errors,remaining);
   if(g_tstc_signals!=INVALID_HANDLE)FileClose(g_tstc_signals);if(g_tstc_actions!=INVALID_HANDLE)FileClose(g_tstc_actions);if(g_tstc_trades!=INVALID_HANDLE)FileClose(g_tstc_trades);
  }
#endif
