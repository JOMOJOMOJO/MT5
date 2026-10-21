#ifndef PORTABLE_ENVIRONMENT_AUDIT_MQH
#define PORTABLE_ENVIRONMENT_AUDIT_MQH
// Tester observer only. Does not submit orders or feed trading decisions.
int qeFile=INVALID_HANDLE,qeConversion=INVALID_HANDLE,qeHistory=INVALID_HANDLE;
string qeSymbols[],qePrevious[];
datetime qeMinute=0;
bool qeFinished=false,qeHaveBaseline=false;
int qeChanges=0;
string QENumber(const double value){return DoubleToString(value,16);}
string QESpec(const string symbol)
  {
   string s="account_currency="+AccountInfoString(ACCOUNT_CURRENCY)+"|account_leverage="+(string)AccountInfoInteger(ACCOUNT_LEVERAGE);
   s+="|account_margin_mode="+(string)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   ENUM_SYMBOL_INFO_STRING strings[]={SYMBOL_CURRENCY_BASE,SYMBOL_CURRENCY_PROFIT,SYMBOL_CURRENCY_MARGIN};
   for(int i=0;i<ArraySize(strings);i++)s+="|"+EnumToString(strings[i])+"="+SymbolInfoString(symbol,strings[i]);
   ENUM_SYMBOL_INFO_INTEGER integers[]={SYMBOL_DIGITS,SYMBOL_TRADE_CALC_MODE,SYMBOL_TRADE_MODE,SYMBOL_TRADE_EXEMODE,
      SYMBOL_TRADE_STOPS_LEVEL,SYMBOL_TRADE_FREEZE_LEVEL,SYMBOL_FILLING_MODE,SYMBOL_ORDER_MODE,SYMBOL_SWAP_MODE,SYMBOL_SWAP_ROLLOVER3DAYS};
   for(int i=0;i<ArraySize(integers);i++)s+="|"+EnumToString(integers[i])+"="+(string)SymbolInfoInteger(symbol,integers[i]);
   ENUM_SYMBOL_INFO_DOUBLE doubles[]={SYMBOL_POINT,SYMBOL_TRADE_TICK_SIZE,SYMBOL_TRADE_CONTRACT_SIZE,SYMBOL_VOLUME_MIN,
      SYMBOL_VOLUME_MAX,SYMBOL_VOLUME_STEP,SYMBOL_VOLUME_LIMIT,SYMBOL_MARGIN_INITIAL,SYMBOL_MARGIN_MAINTENANCE,
      SYMBOL_SWAP_LONG,SYMBOL_SWAP_SHORT,SYMBOL_SWAP_SUNDAY,SYMBOL_SWAP_MONDAY,SYMBOL_SWAP_TUESDAY,SYMBOL_SWAP_WEDNESDAY,
      SYMBOL_SWAP_THURSDAY,SYMBOL_SWAP_FRIDAY,SYMBOL_SWAP_SATURDAY};
   for(int i=0;i<ArraySize(doubles);i++)s+="|"+EnumToString(doubles[i])+"="+QENumber(SymbolInfoDouble(symbol,doubles[i]));
   return s;
  }
void QEWriteSpec(const string phase,const string symbol,const string spec)
  {
   string fields[];int n=StringSplit(spec,'|',fields);
   for(int i=0;i<n;i++)
     {
      int p=StringFind(fields[i],"=");
      FileWrite(qeFile,(long)TimeCurrent(),phase,symbol,StringSubstr(fields[i],0,p),StringSubstr(fields[i],p+1));
     }
   FileFlush(qeFile);
  }
void QEObserve(const string phase="POLL")
  {
   if(qeFile==INVALID_HANDLE)return;
   datetime minute=(datetime)((long)TimeCurrent()/60*60);
   if(phase=="POLL" && minute==qeMinute)return;
   qeMinute=minute;
   for(int i=0;i<ArraySize(qeSymbols);i++)
     {
      string value=QESpec(qeSymbols[i]);
      bool changed=qeHaveBaseline && qePrevious[i]!=value;
      if(changed){qeChanges++;QEWriteSpec("CHANGE",qeSymbols[i],value);Print("QE_SPEC_CHANGED ",qeSymbols[i]);}
      if(phase=="START" || phase=="END")QEWriteSpec(phase,qeSymbols[i],value);
      qePrevious[i]=value;
     }
   qeHaveBaseline=true;
  }
bool QEStart(const string symbols,const string filename)
  {
   if(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION))return false;
   int n=StringSplit(symbols,',',qeSymbols);if(n<1)return false;
   ArrayResize(qePrevious,n);
   for(int i=0;i<n;i++)qePrevious[i]="";
   qeHaveBaseline=false;qeFinished=false;qeChanges=0;qeMinute=0;
   qeFile=FileOpen(filename+".environment.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   qeConversion=FileOpen(filename+".conversion.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   qeHistory=FileOpen(filename+".history.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(qeFile==INVALID_HANDLE || qeConversion==INVALID_HANDLE || qeHistory==INVALID_HANDLE){Print("QE_FATAL_FILE");return false;}
   FileWrite(qeFile,"observed_time","phase","symbol","field","value");
   FileWrite(qeConversion,"deal","symbol","deal_time_msc","observed_time","quote_msc","bid","ask","tick_value_profit","tick_value_loss",
      "min_volume","probe_ticks","buy_calc_ok","buy_loss_account","sell_calc_ok","sell_loss_account","account_currency");
   FileWrite(qeHistory,"symbol","tf","from","to","count","first","last","fingerprint","algorithm");
   QEObserve("START");return true;
  }
void QEDeal(const ulong ticket)
  {
   if(qeConversion==INVALID_HANDLE || !HistoryDealSelect(ticket))return;
   string symbol=HistoryDealGetString(ticket,DEAL_SYMBOL);long stamp=HistoryDealGetInteger(ticket,DEAL_TIME_MSC);
   MqlTick q;ZeroMemory(q);SymbolInfoTick(symbol,q);
   double tick=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE),volume=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN),b=0,s=0;
   bool bok=false,sok=false;
   if(q.bid>0 && q.ask>=q.bid && tick>0 && volume>0 && q.ask>100*tick)
     {
      bok=OrderCalcProfit(ORDER_TYPE_BUY,symbol,volume,q.ask,q.ask-100*tick,b);
      sok=OrderCalcProfit(ORDER_TYPE_SELL,symbol,volume,q.bid,q.bid+100*tick,s);
     }
   FileWrite(qeConversion,ticket,symbol,stamp,(long)TimeCurrent(),q.time_msc,QENumber(q.bid),QENumber(q.ask),
      QENumber(SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE_PROFIT)),QENumber(SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE_LOSS)),
      QENumber(volume),100,(int)bok,QENumber(-b),(int)sok,QENumber(-s),AccountInfoString(ACCOUNT_CURRENCY));
   FileFlush(qeConversion);QEObserve();
  }
void QEHash(ulong &hash,const long value){hash=(hash^(ulong)value)*1099511628211;}
void QEEnd()
  {
   if(qeFinished || qeFile==INVALID_HANDLE)return;
   qeFinished=true;QEObserve("END");
   // Post-test diagnostic only; includes warm-up, never used by the EA.
   ENUM_TIMEFRAMES tfs[]={PERIOD_M1,PERIOD_M5,PERIOD_M15,PERIOD_H1,PERIOD_H4,PERIOD_D1};
   datetime begin=D'2021.01.01 00:00:00',end=D'2023.03.31 23:59:59';
   for(int i=0;i<ArraySize(qeSymbols);i++)
     for(int t=0;t<ArraySize(tfs);t++)
       {
        MqlRates rates[];int n=CopyRates(qeSymbols[i],tfs[t],begin,end,rates);
        double point=SymbolInfoDouble(qeSymbols[i],SYMBOL_POINT);ulong hash=14695981039346656037;
        if(n<=0 || point<=0){Print("QE_FATAL_HISTORY ",qeSymbols[i]," ",EnumToString(tfs[t]));continue;}
        for(int j=0;j<n;j++)
          {
           QEHash(hash,(long)rates[j].time);
           QEHash(hash,(long)MathRound(rates[j].open/point));QEHash(hash,(long)MathRound(rates[j].high/point));
           QEHash(hash,(long)MathRound(rates[j].low/point));QEHash(hash,(long)MathRound(rates[j].close/point));
           QEHash(hash,rates[j].tick_volume);QEHash(hash,rates[j].real_volume);QEHash(hash,rates[j].spread);
          }
        FileWrite(qeHistory,qeSymbols[i],EnumToString(tfs[t]),(long)begin,(long)end,n,(long)rates[0].time,(long)rates[n-1].time,
                  StringFormat("%I64u",hash),"FNV64_INTEGER_WORDS_POINT_SCALED_OHLC_VOLUME_SPREAD");
       }
   FileFlush(qeHistory);
  }
void QEClose()
  {
   if(qeFile!=INVALID_HANDLE){FileClose(qeFile);qeFile=INVALID_HANDLE;}
   if(qeConversion!=INVALID_HANDLE){FileClose(qeConversion);qeConversion=INVALID_HANDLE;}
   if(qeHistory!=INVALID_HANDLE){FileClose(qeHistory);qeHistory=INVALID_HANDLE;}
  }
#endif

#property strict
#property version "1.02"
#ifndef PORTABLE_TRADING_RESEARCH_MQH
#define PORTABLE_TRADING_RESEARCH_MQH
// Research execution primitives. No trade sends; no minimum-lot risk override.
struct PFPlan
  {
   string reason,base_currency,profit_currency;
   double volume,raw_volume,min_volume,max_volume,step,unit_loss,min_loss,budget,loss,margin;
   double point,tick,contract,spread,spread_atr,spread_r,minimum_equity;
   int digits;long calc_mode;
  };
int PFUsdDirection(const string base,const string profit,const int side)
  {
   if(base=="USD" && profit!="USD")return side;
   if(profit=="USD" && base!="USD")return -side;
   return 0; // EURJPY and other crosses do not create a direct USD leg.
  }
double PFFloorVolume(const double raw,const double minimum,const double maximum,const double step)
  {
   if(!MathIsValidNumber(raw)||raw<=0||minimum<=0||maximum<minimum||step<=0)return 0;
   double v=NormalizeDouble(MathFloor(MathMin(raw,maximum)/step+1e-10)*step,8);
   if(v+1e-10<minimum || v>maximum+1e-10)return 0;
   return v;
  }
double PFPrice(const double raw,const double tick,const int digits,const int direction)
  {
   if(!MathIsValidNumber(raw)||raw<=0||tick<=0)return 0;
   double n=raw/tick;
   return NormalizeDouble((direction<0?MathFloor(n):direction>0?MathCeil(n):MathRound(n))*tick,digits);
  }
bool PFResolveSymbol(const string requested,string &resolved,string &reason)
  {
   resolved="";reason="";string key=requested;StringTrimLeft(key);StringTrimRight(key);
   bool custom=false;
   if(SymbolExist(key,custom)){resolved=key;return SymbolSelect(key,true);}
   if(StringLen(key)!=6){reason="SYMBOL_NOT_FOUND_USE_EXACT_BROKER_NAME";return false;}
   string base=StringSubstr(key,0,3),profit=StringSubstr(key,3,3);int matches=0;
   for(int i=0;i<SymbolsTotal(false);i++)
     {
      string s=SymbolName(i,false);
      if(SymbolInfoString(s,SYMBOL_CURRENCY_BASE)==base && SymbolInfoString(s,SYMBOL_CURRENCY_PROFIT)==profit)
        {resolved=s;matches++;}
     }
   if(matches!=1){resolved="";reason=matches>1?"AMBIGUOUS_SYMBOL_USE_EXACT_BROKER_NAME":"SYMBOL_NOT_FOUND";return false;}
   return SymbolSelect(resolved,true);
  }
bool PFMakePlan(const string symbol,const ENUM_ORDER_TYPE side,const double entry,const double sl,
                const double risk_percent,const double atr,PFPlan &p)
  {
   ZeroMemory(p);p.reason="INVALID_RISK_INPUT";
   if((side!=ORDER_TYPE_BUY && side!=ORDER_TYPE_SELL)||entry<=0||sl<=0||risk_percent<=0||risk_percent>100)return false;
   if((side==ORDER_TYPE_BUY && sl>=entry)||(side==ORDER_TYPE_SELL && sl<=entry))return false;
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);p.budget=equity*risk_percent/100.0;
   p.base_currency=SymbolInfoString(symbol,SYMBOL_CURRENCY_BASE);p.profit_currency=SymbolInfoString(symbol,SYMBOL_CURRENCY_PROFIT);
   p.min_volume=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);p.max_volume=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   p.step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);p.point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   p.tick=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);p.contract=SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);
   p.digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);p.calc_mode=SymbolInfoInteger(symbol,SYMBOL_TRADE_CALC_MODE);
   p.reason="INVALID_SYMBOL_SPEC";
   if(equity<=0||p.min_volume<=0||p.max_volume<p.min_volume||p.step<=0||p.point<=0||p.tick<=0||p.contract<=0)return false;
   // Use a valid minimum volume, not an assumed tradable 1.0 lot.
   double profit=0;p.reason="PROFIT_CALC_FAILED";
   if(!OrderCalcProfit(side,symbol,p.min_volume,entry,sl,profit)||!MathIsValidNumber(profit)||profit>=0)return false;
   p.min_loss=-profit;p.unit_loss=p.min_loss/p.min_volume;
   p.minimum_equity=p.min_loss*100.0/risk_percent;p.raw_volume=p.budget/p.unit_loss;
   MqlTick q;if(SymbolInfoTick(symbol,q)&&q.ask>=q.bid&&q.bid>0)p.spread=q.ask-q.bid;
   p.spread_atr=atr>0?p.spread/atr:EMPTY_VALUE;p.spread_r=p.spread/MathAbs(entry-sl);
   p.reason="MIN_VOLUME_EXCEEDS_RISK";
   if(p.min_loss>p.budget+1e-7)return false;
   p.volume=PFFloorVolume(p.raw_volume,p.min_volume,p.max_volume,p.step);
   if(p.volume<=0)return false;
   p.reason="PROFIT_RECHECK_FAILED";
   if(!OrderCalcProfit(side,symbol,p.volume,entry,sl,profit)||!MathIsValidNumber(profit)||profit>=0)return false;
   p.loss=-profit;p.reason="NORMALIZED_VOLUME_EXCEEDS_RISK";
   if(p.loss>p.budget+1e-7)return false;
   p.reason="MARGIN_CALC_FAILED";
   if(!OrderCalcMargin(side,symbol,p.volume,entry,p.margin)||!MathIsValidNumber(p.margin)||p.margin<0)return false;
   p.reason="INSUFFICIENT_MARGIN";if(p.margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE))return false;
   p.reason="OK";return true;
  }
int PFCountPositions(const ulong magic)
  {
   int n=0;for(int i=PositionsTotal()-1;i>=0;i--)
      if(PositionGetTicket(i)>0 && (ulong)PositionGetInteger(POSITION_MAGIC)==magic)n++;
   return n;
  }
bool PFForeignPosition(const string symbol,const ulong magic)
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(PositionGetTicket(i)>0 && PositionGetString(POSITION_SYMBOL)==symbol && (ulong)PositionGetInteger(POSITION_MAGIC)!=magic)return true;
   return false;
  }
int pfRiskFile=INVALID_HANDLE;
bool PFOpen(const string file)
  {
   pfRiskFile=FileOpen(file,FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');if(pfRiskFile==INVALID_HANDLE)return false;
   FileWrite(pfRiskFile,"time","symbol","side","entry","sl","reason","volume","raw_volume","min_volume","max_volume","step",
             "min_loss","budget","planned_loss","margin","minimum_equity","point","tick_size","digits","contract_size","calc_mode",
             "base_currency","profit_currency","spread_price","spread_atr","spread_r");return true;
  }
void PFWrite(const string symbol,const ENUM_ORDER_TYPE side,const double entry,const double sl,const PFPlan &p)
  {
   if(pfRiskFile==INVALID_HANDLE)return;
   FileWrite(pfRiskFile,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),symbol,EnumToString(side),entry,sl,p.reason,p.volume,p.raw_volume,
             p.min_volume,p.max_volume,p.step,p.min_loss,p.budget,p.loss,p.margin,p.minimum_equity,p.point,p.tick,p.digits,p.contract,p.calc_mode,
             p.base_currency,p.profit_currency,p.spread,p.spread_atr,p.spread_r);
  }
void PFClose(){if(pfRiskFile!=INVALID_HANDLE){FileClose(pfRiskFile);pfRiskFile=INVALID_HANDLE;}}
#endif

input bool InpIndependentClock=true;
input double InpDeviationATR=0.05;
// Fixed research baseline; deliberately refuses attachment outside the tester.
#include <Trade/Trade.mqh>
// Read-only tester observer. Missing synchronous quotes are never interpolated.
#ifndef RESEARCH_DEAL_QUOTE_AUDIT
#define RESEARCH_DEAL_QUOTE_AUDIT
// Portable QA r2: end-of-test history is independent of the last tick clock.
int dqFile=INVALID_HANDLE;
ulong dqSeen[];
string dqName="";
void DQStart(const string filename)
  {
   dqName=filename;
   dqFile=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(dqFile==INVALID_HANDLE){Print("DQ_FATAL_FILE");return;}
   FileWrite(dqFile,"deal","position_id","order","symbol","entry_kind","type","time_msc","price","volume",
      "sl","tp","profit","commission","swap","fee","bid","ask","quote_msc","quote_status","reason");
  }
void DQCapture(const ulong ticket)
  {
   if(dqFile==INVALID_HANDLE || ticket==0)return;
   for(int j=0;j<ArraySize(dqSeen);j++)if(dqSeen[j]==ticket)return;
   if(!HistoryDealSelect(ticket))return;
   long type=HistoryDealGetInteger(ticket,DEAL_TYPE);
   if(type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL)return;
   string symbol=HistoryDealGetString(ticket,DEAL_SYMBOL);
   long stamp=HistoryDealGetInteger(ticket,DEAL_TIME_MSC);
   MqlTick q;ZeroMemory(q);string status="MISSING";
   if(SymbolInfoTick(symbol,q) && q.time_msc==stamp && q.bid>0 && q.ask>=q.bid)status="CURRENT_EXACT_MSC";
   else
     {
      ZeroMemory(q);MqlTick a[];
      int n=CopyTicksRange(symbol,a,COPY_TICKS_ALL,(ulong)stamp,(ulong)stamp);
      bool ambiguous=false;
      for(int j=0;j<n;j++)
        {
         if(a[j].time_msc!=stamp || a[j].bid<=0 || a[j].ask<a[j].bid)continue;
         if(q.bid>0 && (q.bid!=a[j].bid || q.ask!=a[j].ask))ambiguous=true;
         q=a[j];
        }
      if(ambiguous){status="AMBIGUOUS_MSC";ZeroMemory(q);}
      else if(q.bid>0)status="HISTORY_EXACT_MSC";
     }
   ulong order=(ulong)HistoryDealGetInteger(ticket,DEAL_ORDER);
   double sl=0,tp=0;
   if(HistoryOrderSelect(order)){sl=HistoryOrderGetDouble(order,ORDER_SL);tp=HistoryOrderGetDouble(order,ORDER_TP);}
   FileWrite(dqFile,ticket,HistoryDealGetInteger(ticket,DEAL_POSITION_ID),order,symbol,
      HistoryDealGetInteger(ticket,DEAL_ENTRY),type,stamp,DoubleToString(HistoryDealGetDouble(ticket,DEAL_PRICE),12),
      DoubleToString(HistoryDealGetDouble(ticket,DEAL_VOLUME),8),DoubleToString(sl,12),DoubleToString(tp,12),
      DoubleToString(HistoryDealGetDouble(ticket,DEAL_PROFIT),8),DoubleToString(HistoryDealGetDouble(ticket,DEAL_COMMISSION),8),
      DoubleToString(HistoryDealGetDouble(ticket,DEAL_SWAP),8),DoubleToString(HistoryDealGetDouble(ticket,DEAL_FEE),8),
      DoubleToString(q.bid,12),DoubleToString(q.ask,12),q.time_msc,status,HistoryDealGetInteger(ticket,DEAL_REASON));
   QEDeal(ticket);
   int size=ArraySize(dqSeen);ArrayResize(dqSeen,size+1);dqSeen[size]=ticket;FileFlush(dqFile);
  }
void DQDrain(const bool final_pass=false)
  {
   if(dqFile==INVALID_HANDLE)return;
   datetime quote_clock=TimeCurrent();
   bool terminal_pass=final_pass && (bool)MQLInfoInteger(MQL_TESTER);
   if(!HistorySelect(0,quote_clock)){Print("DQ_FATAL_HISTORY_NARROW");return;}
   int narrow=HistoryDealsTotal();
   // Only completed tester accounting requests the full already-created deal list.
   // No price data or result of this observer is consumed by signal/risk code.
   if(terminal_pass && !HistorySelect(0,D'3000.12.31 23:59:59'))
     {Print("DQ_FATAL_HISTORY_FINAL");return;}
   int n=HistoryDealsTotal();ulong ids[];ArrayResize(ids,n);long latest=0;
   for(int j=0;j<n;j++)
     {
      ids[j]=HistoryDealGetTicket(j);
      if(ids[j]>0){long stamp=HistoryDealGetInteger(ids[j],DEAL_TIME_MSC);if(stamp>latest)latest=stamp;}
     }
   // DQCapture calls HistoryDealSelect, so snapshot all tickets before capturing.
   for(int j=0;j<n;j++)DQCapture(ids[j]);
   if(terminal_pass)PrintFormat("DQ_FINAL quote_clock=%I64d server_clock=%I64d narrow=%d all=%d latest_msc=%I64d captured=%d",
      (long)quote_clock,(long)TimeTradeServer(),narrow,n,latest,ArraySize(dqSeen));
  }
void DQClose(){DQDrain(true);if(dqFile!=INVALID_HANDLE){FileClose(dqFile);dqFile=INVALID_HANDLE;}}
#endif

input string InpSymbols="USDJPY,EURUSD,GBPUSD,AUDUSD,XAUUSD";
input string InpTelemetryFileName="daily_channel.csv";
input ulong InpMagic=261008201;
input int InpEntryBars=20;
input int InpExitBars=10;
input int InpATRPeriod=14;
input double InpSLATR=2.0;
input double InpRiskPercent=0.25;
input double InpTotalRiskPercent=0.75;
input double InpUSDGroupRiskPercent=0.50;
input double InpDailyLossPercent=3.0;
input double InpPeakLossPercent=12.0;
CTrade dcTrade;
struct DCAsset{string name;int atr;datetime consumed;bool close_due;datetime retry_bar,retry_signal;};
DCAsset dcAssets[];
int dcLog=INVALID_HANDLE,dcDay=-1;
datetime dcMinute=0;
double dcPeak=0,dcDayStart=0;
bool dcDailyStop=false,dcPeakStop=false,dcUncertain=false;
int dcErrors=0;
void DCLog(const string symbol,const datetime bar,const string reason,const double price=0,const double atr=0,
           const double level=0,const double sl=0,const double volume=0,const double risk=0,const uint retcode=0)
  {
   FileWrite(dcLog,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),symbol,TimeToString(bar,TIME_DATE|TIME_SECONDS),
     reason,DoubleToString(price,12),DoubleToString(atr,12),DoubleToString(level,12),DoubleToString(sl,12),
     DoubleToString(volume,8),DoubleToString(risk,8),DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),8),retcode);
  }
int DCUSDGroup(const string symbol,const int side)
  {return PFUsdDirection(SymbolInfoString(symbol,SYMBOL_CURRENCY_BASE),SymbolInfoString(symbol,SYMBOL_CURRENCY_PROFIT),side);}
double DCRisk(const string symbol,const ENUM_ORDER_TYPE type,const double volume,const double entry,const double sl)
  {
   double value=0;
   if(sl<=0 || !OrderCalcProfit(type,symbol,volume,entry,sl,value))return DBL_MAX;
   return MathMax(0.0,-value);
  }
bool DCRiskRoom(const int group,const double proposed,const double equity)
  {
   double total=proposed,same=proposed;
   for(int j=PositionsTotal()-1;j>=0;j--)
     {
      if(PositionGetTicket(j)==0 || (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagic)continue;
      string symbol=PositionGetString(POSITION_SYMBOL);
      int side=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1;
      double risk=DCRisk(symbol,side>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,PositionGetDouble(POSITION_VOLUME),
                         PositionGetDouble(POSITION_PRICE_OPEN),PositionGetDouble(POSITION_SL));
      total+=risk;if(group!=0 && DCUSDGroup(symbol,side)==group)same+=risk;
     }
   return total<=equity*InpTotalRiskPercent/100.0+1e-7 && (group==0 || same<=equity*InpUSDGroupRiskPercent/100.0+1e-7);
  }
bool DCClose(const string symbol)
  {
   bool complete=true;
   for(int j=PositionsTotal()-1;j>=0;j--)
     {
      ulong ticket=PositionGetTicket(j);
      if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=symbol || (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagic)continue;
      bool ok=dcTrade.PositionClose(ticket);uint rc=dcTrade.ResultRetcode();DCLog(symbol,0,"CLOSE_RESULT",0,0,0,0,0,0,rc);
      if(!ok || rc!=TRADE_RETCODE_DONE || PositionSelectByTicket(ticket))complete=false;
     }
   return complete;
  }
int QABaseOnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER)||MQLInfoInteger(MQL_OPTIMIZATION))return INIT_FAILED;
   if(InpEntryBars<2||InpExitBars<1||InpExitBars>=InpEntryBars||InpATRPeriod<2||InpRiskPercent<=0||InpSLATR<=0)return INIT_PARAMETERS_INCORRECT;
   string names[];int n=StringSplit(InpSymbols,',',names);if(n<1)return INIT_PARAMETERS_INCORRECT;
   ArrayResize(dcAssets,n);
   for(int j=0;j<n;j++)
     {
      string resolved,why;
      if(!PFResolveSymbol(names[j],resolved,why)){Print("DC_FATAL_SYMBOL ",names[j]," ",why);return INIT_FAILED;}
      for(int k=0;k<j;k++)if(dcAssets[k].name==resolved)return INIT_PARAMETERS_INCORRECT;
      names[j]=resolved;dcAssets[j].name=resolved;dcAssets[j].consumed=0;dcAssets[j].close_due=false;
      dcAssets[j].retry_bar=0;dcAssets[j].retry_signal=0;
      if(!SymbolSelect(names[j],true)){Print("DC_FATAL_SYMBOL ",names[j]);return INIT_FAILED;}
      dcAssets[j].atr=iATR(names[j],PERIOD_D1,InpATRPeriod);
      if(dcAssets[j].atr==INVALID_HANDLE)return INIT_FAILED;
     }
   dcLog=FileOpen(InpTelemetryFileName,FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(dcLog==INVALID_HANDLE)return INIT_FAILED;
   FileWrite(dcLog,"time","symbol","signal_bar","event","price","atr","channel","sl","volume","risk_money","equity","retcode");
   DQStart(InpTelemetryFileName+".cost.csv");if(dqFile==INVALID_HANDLE)return INIT_FAILED;
   if(InpDeviationATR<0 || InpRiskPercent>100 || InpTotalRiskPercent<=0 || InpUSDGroupRiskPercent<=0 ||
         InpDailyLossPercent<=0 || InpDailyLossPercent>=100 || InpPeakLossPercent<=0 || InpPeakLossPercent>=100)return INIT_PARAMETERS_INCORRECT;
   if(!PFOpen(InpTelemetryFileName+".risk.csv"))return INIT_FAILED;
   if(InpIndependentClock && !EventSetTimer(10))return INIT_FAILED;
   dcTrade.SetExpertMagicNumber(InpMagic);dcTrade.SetAsyncMode(false);
   dcPeak=AccountInfoDouble(ACCOUNT_EQUITY);return INIT_SUCCEEDED;
  }
void DCStep(const int index)
  {
   string symbol=dcAssets[index].name;MqlTick q;
   if(!SymbolInfoTick(symbol,q)||q.bid<=0||q.ask<q.bid||q.time>TimeCurrent()||TimeCurrent()-q.time>60)return;
   dcTrade.SetTypeFillingBySymbol(symbol);
   if(dcAssets[index].close_due)
     {if(DCClose(symbol))dcAssets[index].close_due=false;return;}
   MqlRates r[];ArraySetAsSeries(r,true);int count=InpEntryBars+2;
   if(CopyRates(symbol,PERIOD_D1,0,count,r)!=count)return;
   if(r[0].time>TimeCurrent() || r[1].time>=r[0].time || dcAssets[index].consumed==r[0].time)return;
   double a[];if(CopyBuffer(dcAssets[index].atr,0,1,1,a)!=1 || a[0]<=0)return;
   if(dcAssets[index].retry_bar>0)
     {
      DCLog(symbol,dcAssets[index].retry_signal,dcAssets[index].retry_bar==r[0].time?"RETRY_RESUMED":"RETRY_EXPIRED");
      dcAssets[index].retry_bar=0;dcAssets[index].retry_signal=0;
     }
   dcAssets[index].consumed=r[0].time;
   DCLog(symbol,r[1].time,"BAR_EVALUATED",r[1].close,a[0]);
   // Exclude signal bar [1] from both channels; only indices [2..N+1].
   double high=r[2].high,low=r[2].low,exitHigh=high,exitLow=low;
   for(int j=3;j<count;j++){high=MathMax(high,r[j].high);low=MathMin(low,r[j].low);}
   for(int j=3;j<InpExitBars+2;j++){exitHigh=MathMax(exitHigh,r[j].high);exitLow=MathMin(exitLow,r[j].low);}
   if(PFForeignPosition(symbol,InpMagic)){DCLog(symbol,r[1].time,"FOREIGN_POSITION");return;}
   if(PositionSelect(symbol))
     {
      bool buy=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
      if((buy && r[1].close<exitLow)||(!buy && r[1].close>exitHigh))
        {DCLog(symbol,r[1].time,"CHANNEL_EXIT",r[1].close,a[0],buy?exitLow:exitHigh);dcAssets[index].close_due=!DCClose(symbol);}
      return; // No same-bar reversal or pyramiding.
     }
   int side=r[1].close>high?1:(r[1].close<low?-1:0);
   if(side==0){DCLog(symbol,r[1].time,"NO_SIGNAL");return;}
   double price=side>0?q.ask:q.bid,level=side>0?high:low;
   DCLog(symbol,r[1].time,"SIGNAL",price,a[0],level);
   if(dcDailyStop||dcPeakStop||dcUncertain||OrdersTotal()>0){DCLog(symbol,r[1].time,"RISK_LATCH");return;}
   double tick=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE),point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   if(tick<=0||point<=0){dcErrors++;return;}
   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   double raw=price-side*InpSLATR*a[0];
   double sl=NormalizeDouble((side>0?MathFloor(raw/tick):MathCeil(raw/tick))*tick,digits);
   double minStop=SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL)*point;
   if(sl<=0 || (side>0?q.bid-sl:sl-q.ask)<minStop){DCLog(symbol,r[1].time,"BROKER_STOP");return;}
   ENUM_ORDER_TYPE type=side>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   double equity=AccountInfoDouble(ACCOUNT_EQUITY),budget=equity*InpRiskPercent/100.0;
   PFPlan plan;bool planned=PFMakePlan(symbol,type,price,sl,InpRiskPercent,a[0],plan);PFWrite(symbol,type,price,sl,plan);
   if(!planned){DCLog(symbol,r[1].time,plan.reason,price,a[0],level,sl,plan.volume,plan.loss);return;}
   double volume=plan.volume,risk=plan.loss;
   dcTrade.SetDeviationInPoints((ulong)MathCeil(InpDeviationATR*a[0]/point));
   if(PFCountPositions(InpMagic)>=3 || !DCRiskRoom(DCUSDGroup(symbol,side),risk,equity))
     {DCLog(symbol,r[1].time,"PORTFOLIO_CAP");return;}
   double margin=0;
   if(!OrderCalcMargin(type,symbol,volume,price,margin)||margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE))
     {DCLog(symbol,r[1].time,"MARGIN");return;}
   DCLog(symbol,r[1].time,"RISK_PLAN",price,a[0],level,sl,volume,risk);
   bool sent=side>0?dcTrade.Buy(volume,symbol,price,sl,0,"D1 channel"):dcTrade.Sell(volume,symbol,price,sl,0,"D1 channel");
   uint rc=dcTrade.ResultRetcode();DCLog(symbol,r[1].time,sent?"SEND_RESULT":"SEND_FAILED",price,a[0],level,sl,volume,risk,rc);
   // MARKET_CLOSED is a definite rejection, not an uncertain send. Preserve this
   // closed-bar signal until a subsequent fresh quote in the same D1 bar.
   if(rc==TRADE_RETCODE_MARKET_CLOSED)
     {
      dcAssets[index].consumed=0;dcAssets[index].retry_bar=r[0].time;dcAssets[index].retry_signal=r[1].time;
      DCLog(symbol,r[1].time,"RETRY_MARKET_CLOSED",price,a[0],level,sl,volume,risk,rc);
      return;
     }
   if(rc==TRADE_RETCODE_TIMEOUT||rc==TRADE_RETCODE_CONNECTION||rc==TRADE_RETCODE_PLACED)dcUncertain=true;
   if(PositionSelect(symbol))
     {
      double actual=DCRisk(symbol,type,PositionGetDouble(POSITION_VOLUME),PositionGetDouble(POSITION_PRICE_OPEN),PositionGetDouble(POSITION_SL));
      if(actual>budget+0.01){dcErrors++;DCLog(symbol,r[1].time,"FILL_RISK_EXCEEDED");dcAssets[index].close_due=!DCClose(symbol);}
     }
  }
void QABaseOnTick()
  {
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);dcPeak=MathMax(dcPeak,equity);
   MqlDateTime t;TimeToStruct(TimeCurrent(),t);int day=t.year*1000+t.day_of_year;
   if(day!=dcDay){dcDay=day;dcDayStart=equity;dcDailyStop=false;}
   if(equity<=dcDayStart*(1-InpDailyLossPercent/100.0))dcDailyStop=true;
   if(equity<=dcPeak*(1-InpPeakLossPercent/100.0))dcPeakStop=true;
   datetime minute=(datetime)((long)TimeCurrent()/60*60);if(minute==dcMinute)return;dcMinute=minute;
   if(dcDailyStop||dcPeakStop)
     for(int j=0;j<ArraySize(dcAssets);j++)if(PositionSelect(dcAssets[j].name))dcAssets[j].close_due=true;
   // Deterministic rotating priority prevents a constant first-symbol advantage.
   int n=ArraySize(dcAssets),start=(int)((long)TimeCurrent()/86400%n);
   for(int j=0;j<n;j++)DCStep((j+start)%n);
  }
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {if(trans.type==TRADE_TRANSACTION_DEAL_ADD)DQCapture(trans.deal);}
double QABaseOnTester(){DQDrain(true);return (double)dcErrors;}
void QABaseOnDeinit(const int reason)
  {
   EventKillTimer();PFClose();
   for(int j=0;j<ArraySize(dcAssets);j++)
      if(dcAssets[j].retry_bar>0)DCLog(dcAssets[j].name,dcAssets[j].retry_signal,"RETRY_END_CENSORED");
   DQClose();if(dcLog!=INVALID_HANDLE)FileClose(dcLog);
   for(int j=0;j<ArraySize(dcAssets);j++)if(dcAssets[j].atr!=INVALID_HANDLE)IndicatorRelease(dcAssets[j].atr);
   PrintFormat("DC_FINISH errors=%d uncertain=%d peak_stop=%d",dcErrors,(int)dcUncertain,(int)dcPeakStop);
  }

void OnTimer(){if(InpIndependentClock)OnTick();}

int OnInit()
  {int rc=QABaseOnInit();if(rc==INIT_SUCCEEDED && !QEStart(InpSymbols,InpTelemetryFileName))return INIT_FAILED;return rc;}
void OnTick(){QEObserve();QABaseOnTick();}
double OnTester(){double result=QABaseOnTester();QEEnd();return result;}
void OnDeinit(const int reason){QABaseOnDeinit(reason);QEClose();}
