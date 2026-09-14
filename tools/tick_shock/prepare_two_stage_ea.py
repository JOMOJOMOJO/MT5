"""Derive a separate tester-only fixed-time adapter; never edit the frozen original."""
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[2]

def replace_function(text,name,body):
    match=re.search(r'(?:void|bool) '+name+r'\(',text)
    if not match:raise ValueError(name)
    start=text.index('{',match.start());depth=1;end=start+1
    while depth:
        depth+=(text[end]=='{')-(text[end]=='}');end+=1
    return text[:match.start()]+body.strip()+text[end:]

SNAPSHOT=r'''
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
'''

ENTRY=r'''
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
'''

SEED=r'''
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
'''

def main():
    original=ROOT/'mql/Include/TickShock4m2mFrozen/mql/Include/TickShock/TickShockTechnicalCandidate.mqh'
    dest=ROOT/'mql/Include/TickShockTwoStageCandidate.mqh'
    if dest.exists():raise FileExistsError(dest)
    text=original.read_text(encoding='utf-8')
    text=text.replace('#include "TickShockTechnicalModel.mqh"','#include "TickShockTwoStageModel.mqh"\n#include "TickShockTwoStagePolicy.mqh"')
    text=text.replace('260909731','260914521')
    text=text.replace('bool TSTCInit(const string folder)',SEED+'\nbool TSTCInit(const string folder)')
    text=text.replace('   string base=folder+"\\\\candidate_";', '   g_ts2_folder=folder;if(!TS2ReadSeed())return false;\n   string base=folder+"\\\\candidate_";')
    assert 'if(!TS2ReadSeed())' in text
    text=text.replace('"direction","atr14_m5");','"direction","atr14_m5","stage1_score","decision_threshold");')
    text=replace_function(text,'TSTCOnSnapshot',SNAPSHOT)
    text=replace_function(text,'TSTCTryEntry',ENTRY)
    assert text.count('opened+900000')==1
    text=text.replace('opened+900000','opened+(long)TS2_HOLD_SECONDS*1000')
    text=text.replace('   if(remaining>0)++g_tstc_errors;','   TS2WriteSeed();if(!g_ts2_policy_valid)++g_tstc_errors;\n   if(remaining>0)++g_tstc_errors;')
    dest.write_text(text,encoding='utf-8')
    print(dest)

if __name__=='__main__':main()
