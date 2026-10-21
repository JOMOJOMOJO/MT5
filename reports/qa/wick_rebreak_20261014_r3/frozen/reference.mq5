#ifndef PORTABLE_ENVIRONMENT_AUDIT_MQH
#define PORTABLE_ENVIRONMENT_AUDIT_MQH
// Tester observer only. Does not submit orders or feed trading decisions.
int qeFile=INVALID_HANDLE,qeConversion=INVALID_HANDLE,qeHistory=INVALID_HANDLE;
string qeSymbols[],qePrevious[];
datetime qeMinute=0,qeTestStart=0;
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
   qeHaveBaseline=false;qeFinished=false;qeChanges=0;qeMinute=0;qeTestStart=TimeCurrent();
   qeFile=FileOpen(filename+".environment.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   qeConversion=FileOpen(filename+".conversion.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   qeHistory=FileOpen(filename+".history.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(qeFile==INVALID_HANDLE || qeConversion==INVALID_HANDLE || qeHistory==INVALID_HANDLE){Print("QE_FATAL_FILE");return false;}
   FileWrite(qeFile,"observed_time","phase","symbol","field","value");
   FileWrite(qeConversion,"deal","symbol","deal_time_msc","observed_time","quote_msc","bid","ask","tick_value_profit","tick_value_loss",
      "min_volume","probe_ticks","buy_calc_ok","buy_loss_account","sell_calc_ok","sell_loss_account","account_currency");
   FileWrite(qeHistory,"symbol","tf","from","to","count","first","last","fingerprint","algorithm","test_start","test_end","test_count","test_first","test_last","test_months");
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
   // The previous calendar year covers the preloaded warm-up. Nothing is read
   // for this fingerprint until OnTester, after all trading has finished.
   MqlDateTime start;TimeToStruct(qeTestStart,start);
   start.year--;start.mon=1;start.day=1;start.hour=0;start.min=0;start.sec=0;
   datetime begin=StructToTime(start),end=TimeCurrent();
   if(qeTestStart<=0 || end<qeTestStart){Print("QE_FATAL_HISTORY_CLOCK");return;}
   for(int i=0;i<ArraySize(qeSymbols);i++)
     for(int t=0;t<ArraySize(tfs);t++)
       {
        MqlRates rates[];ArraySetAsSeries(rates,false);ResetLastError();
        int n=CopyRates(qeSymbols[i],tfs[t],begin,end,rates);int error=GetLastError();
        double point=SymbolInfoDouble(qeSymbols[i],SYMBOL_POINT);ulong hash=14695981039346656037;
        if(n<=0 || point<=0){Print("QE_FATAL_HISTORY ",qeSymbols[i]," ",EnumToString(tfs[t]),
           " from=",TimeToString(begin)," to=",TimeToString(end)," count=",n," error=",error);continue;}
        int testCount=0,lastMonth=0;datetime testFirst=0,testLast=0;string months="";
        for(int j=0;j<n;j++)
          {
           QEHash(hash,(long)rates[j].time);
           QEHash(hash,(long)MathRound(rates[j].open/point));QEHash(hash,(long)MathRound(rates[j].high/point));
           QEHash(hash,(long)MathRound(rates[j].low/point));QEHash(hash,(long)MathRound(rates[j].close/point));
           QEHash(hash,rates[j].tick_volume);QEHash(hash,rates[j].real_volume);QEHash(hash,rates[j].spread);
           if(rates[j].time>=qeTestStart && rates[j].time<=end)
             {
              if(testCount==0)testFirst=rates[j].time;
              testCount++;testLast=rates[j].time;
              MqlDateTime stamp;TimeToStruct(rates[j].time,stamp);int month=stamp.year*100+stamp.mon;
              if(month!=lastMonth){if(months!="")months+=",";months+=(string)month;lastMonth=month;}
             }
          }
        FileWrite(qeHistory,qeSymbols[i],EnumToString(tfs[t]),(long)begin,(long)end,n,(long)rates[0].time,(long)rates[n-1].time,
                  StringFormat("%I64u",hash),"FNV64_INTEGER_WORDS_POINT_SCALED_OHLC_VOLUME_SPREAD",
                  (long)qeTestStart,(long)end,testCount,(long)testFirst,(long)testLast,months);
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

//+------------------------------------------------------------------+
//| Relative Continuation - ATR-scaled successor                      |
//+------------------------------------------------------------------+
#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "2.00"
#property strict
#property description "USDJPY multi-bucket continuation prototype using EMA13/EMA100 trend, 50-unit anti-chop state, and parallel bucket entries."

#include <Trade\Trade.mqh>
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

#ifndef PORTABLE_RISK_ADJUSTMENT_MQH
#define PORTABLE_RISK_ADJUSTMENT_MQH

// Opt-in research adapter. No orders, no increase of the original volume or risk budget.
struct PFAudit
  {
   string before_reason;
   double before_volume,before_loss;
   int checks;
  };
double PFNextSmallerVolume(const double volume,const double loss,const double budget,
                          const double minimum,const double maximum,const double step)
  {
   if(!MathIsValidNumber(volume)||!MathIsValidNumber(loss)||!MathIsValidNumber(budget)||
      volume<=0||loss<=0||budget<=0||step<=0||minimum<=0||maximum<minimum)return 0;
   if(loss<=budget+1e-7)return volume;
   double ceiling=MathMin(volume-step,volume*budget/loss);
   double next=PFFloorVolume(ceiling,minimum,maximum,step);
   if(next<=0||next>=volume-1e-10)return 0;
   return next;
  }
bool PFReduceRejectedPlan(const string symbol,const ENUM_ORDER_TYPE side,const double entry,const double sl,
                          const bool enabled,PFPlan &p,PFAudit &a)
  {
   ZeroMemory(a);a.before_reason=p.reason;a.before_volume=p.volume;a.before_loss=p.loss;
   if(p.reason=="OK")return true;
   if(!enabled||p.reason!="NORMALIZED_VOLUME_EXCEEDS_RISK")return false;
   if(p.min_loss>p.budget+1e-7){p.reason="MIN_VOLUME_EXCEEDS_RISK";return false;}
   // Bounded even for an unusual/non-linear contract. Every accepted value is re-priced.
   for(int i=0;i<32;i++)
     {
      double next=PFNextSmallerVolume(p.volume,p.loss,p.budget,p.min_volume,p.max_volume,p.step);
      if(next<=0||next>=p.volume-1e-10){p.reason="ADJUSTED_VOLUME_UNAVAILABLE";return false;}
      p.volume=next;a.checks++;
      double profit=0;p.reason="PROFIT_RECHECK_FAILED";
      if(!OrderCalcProfit(side,symbol,p.volume,entry,sl,profit)||!MathIsValidNumber(profit)||profit>=0)return false;
      p.loss=-profit;
      if(p.loss>p.budget+1e-7){p.reason="NORMALIZED_VOLUME_EXCEEDS_RISK";continue;}
      p.reason="MARGIN_CALC_FAILED";
      if(!OrderCalcMargin(side,symbol,p.volume,entry,p.margin)||!MathIsValidNumber(p.margin)||p.margin<0)return false;
      p.reason="INSUFFICIENT_MARGIN";
      if(p.margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE))return false;
      p.reason="OK";return true;
     }
   p.reason="RISK_ADJUSTMENT_LIMIT";return false;
  }
bool PFMakeAdjustedPlan(const string symbol,const ENUM_ORDER_TYPE side,const double entry,const double sl,
                        const double risk_percent,const double atr,const bool enabled,PFPlan &p,PFAudit &a)
  {
   PFMakePlan(symbol,side,entry,sl,risk_percent,atr,p);
   return PFReduceRejectedPlan(symbol,side,entry,sl,enabled,p,a);
  }
int pfaFile=INVALID_HANDLE;
bool PFAOpen(const string file)
  {
   pfaFile=FileOpen(file,FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');if(pfaFile==INVALID_HANDLE)return false;
   FileWrite(pfaFile,"time","symbol","side","enabled","entry","sl","budget","before_reason","before_volume","before_loss",
             "checks","after_reason","after_volume","after_loss","margin","min_volume","step","max_volume");return true;
  }
void PFAWrite(const string symbol,const ENUM_ORDER_TYPE side,const bool enabled,const double entry,const double sl,
              const PFPlan &p,const PFAudit &a)
  {
   if(pfaFile==INVALID_HANDLE)return;
   FileWrite(pfaFile,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),symbol,EnumToString(side),(int)enabled,entry,sl,
             p.budget,a.before_reason,a.before_volume,a.before_loss,a.checks,p.reason,p.volume,p.loss,p.margin,p.min_volume,p.step,p.max_volume);
  }
void PFAClose(){if(pfaFile!=INVALID_HANDLE){FileClose(pfaFile);pfaFile=INVALID_HANDLE;}}
#endif

input bool InpAdjustRoundedVolume=false;


CTrade trade;

// RELATIVE_CONTINUATION_MODULE_BEGIN Configuration
#ifndef RELATIVE_CONTINUATION_CONFIGURATION_MQH
#define RELATIVE_CONTINUATION_CONFIGURATION_MQH
struct PivotPoint
  {
   bool     valid;
   int      shift;
   double   price;
   datetime time;
  };

enum SignalBucket
  {
   SIGNAL_NONE = 0,
   SIGNAL_ROUND = 1,
   SIGNAL_EMA = 2,
   SIGNAL_ROUND_LOOSE = 3,
   SIGNAL_BREAKOUT = 4,
   SIGNAL_RSI = 5,
   SIGNAL_COMPRESSION = 6,
   SIGNAL_DOW_SWEEP = 7,
   SIGNAL_RANGE_RECLAIM = 8,
   SIGNAL_FRACTAL_TREND = 9,
   SIGNAL_ROUND_SHORT = 10,
   SIGNAL_RANGE_RECLAIM_SHORT = 11
  };

// Empty = chart symbol. Attach one instance per symbol and use unique magic.
input string          InpSymbol                   = "";
input int             InpDistanceATRPeriod        = 14;
input double          InpDeviationAtr             = 0.05;
input bool            InpWriteFunnel               = true;
input ENUM_TIMEFRAMES InpSignalTimeframe          = PERIOD_M15;
input int             InpFastEMAPeriod            = 13;
input int             InpSlowEMAPeriod            = 100;
input int             InpSlowSlopeLookback        = 5;
input int             InpPivotSpan                = 2;
input int             InpTrendScanBars            = 180;
input int             InpVolatilityLookbackBars   = 24;
input double InpMinWindowRangeAtr = 1.8;
input double InpGridStepAtr = 5;
input bool            InpEnableRoundBucket        = true;
input int             InpSessionStartHour         = 7;
input int             InpSessionEndHour           = 22;
input double InpMaxEma13DistanceAtr = 1.2;
input double          InpMinUpperWickShare        = 0.50;
input double          InpMaxLowerWickShare        = 0.10;
input double InpMinSlowSlopeAtr = 0;
input double InpStopLossAtr = 2.2;
input double          InpTargetRMultiple          = 1.5;
input int             InpMaxHoldBars              = 18;
input bool            InpAllowParallelBuckets     = false;
input int             InpMaxOpenPositions         = 1;
input bool            InpEnableRoundShortBucket   = false;
input int             InpRoundShortSessionStartHour = 7;
input int             InpRoundShortSessionEndHour = 22;
input double InpRoundShortMaxEma13DistanceAtr = 1.2;
input double          InpRoundShortMinLowerWickShare = 0.50;
input double          InpRoundShortMaxUpperWickShare = 0.10;
input double InpRoundShortMinSlowSlopeAtr = 0;
input double InpRoundShortStopLossAtr = 2.2;
input double          InpRoundShortTargetRMultiple = 1.5;
input int             InpRoundShortMaxHoldBars    = 18;
input bool            InpEnableRoundLooseBucket   = false;
input double InpRoundLooseMaxEma13DistanceAtr = 1.8;
input double InpRoundLooseStopLossAtr = 1.8;
input double          InpRoundLooseTargetRMultiple = 1.0;
input int             InpRoundLooseMaxHoldBars    = 12;
input bool            InpEnableEmaBucket          = false;
input int             InpAdxPeriod                = 14;
input double          InpEmaMaxAdx                = 30.0;
input int             InpEmaSessionStartHour      = 7;
input int             InpEmaSessionEndHour        = 16;
input double InpEmaMaxEma13DistanceAtr = 2.2;
input double          InpEmaMaxRet1               = 0.0004;
input double          InpEmaMinUpperWickShare     = 0.45;
input double          InpEmaMaxLowerWickShare     = 0.15;
input double          InpEmaMaxCloseLocation      = 0.45;
input double InpEmaStopLossAtr = 1.5;
input double          InpEmaTargetRMultiple       = 1.2;
input int             InpEmaMaxHoldBars           = 12;
input bool            InpEnableCompressionBucket  = false;
input int             InpCompressionSessionStartHour = 23;
input int             InpCompressionSessionEndHour = 22;
input double          InpCompressionMaxAdx        = 20.5;
input double InpCompressionMaxEma13DistanceAtr = 3;
input double          InpCompressionMinUpperWickShare = 0.45;
input double          InpCompressionMaxLowerWickShare = 0.07;
input double InpCompressionStopLossAtr = 1.5;
input double          InpCompressionTargetRMultiple = 1.2;
input int             InpCompressionMaxHoldBars   = 12;
input bool            InpEnableRsiBucket          = false;
input int             InpRsiPeriod                = 3;
input double          InpRsiOversold              = 18.0;
input int             InpRsiSessionStartHour      = 7;
input int             InpRsiSessionEndHour        = 22;
input double InpRsiMaxEma13DistanceAtr = 2.5;
input double InpRsiTouchBufferAtr = 0.1;
input double          InpRsiMinCloseLocation      = 0.55;
input double InpRsiMinBodyAtr = 0.2;
input double          InpRsiMaxLowerWickShare     = 0.45;
input double InpRsiStopLossAtr = 1.6;
input double          InpRsiTargetRMultiple       = 1.1;
input int             InpRsiMaxHoldBars           = 12;
input bool            InpEnableBreakoutBucket     = false;
input int             InpBreakoutSessionStartHour = 7;
input int             InpBreakoutSessionEndHour   = 22;
input int             InpBreakoutLookbackBars     = 12;
input double InpBreakoutMidpointDistanceAtr = 2.5;
input double InpBreakoutTouchToleranceAtr = 0.05;
input double InpBreakoutRetestBufferAtr = 0.2;
input int             InpBreakoutRetestDelayBars  = 1;
input double          InpBreakoutMinCloseLocation = 0.55;
input double InpBreakoutMinBodyAtr = 0.6;
input double          InpBreakoutMinBodyToRange   = 0.60;
input double InpBreakoutMaxToEma13Atr = 3;
input double          InpBreakoutMinRetestCloseLocation = 0.50;
input double InpBreakoutMaxRetestDepthAtr = 0.1;
input double InpBreakoutStopLossAtr = 2;
input double          InpBreakoutTargetRMultiple  = 1.2;
input int             InpBreakoutMaxHoldBars      = 18;
input bool            InpEnableDowSweepBucket     = false;
input ENUM_TIMEFRAMES InpDowSignalTimeframe       = PERIOD_M5;
input int             InpDowSessionStartHour      = 7;
input int             InpDowSessionEndHour        = 20;
input int             InpDowPivotSpan             = 2;
input int             InpDowTrendScanBars         = 120;
input double InpDowMinBreachAtr = 0.2;
input double InpDowMaxBreachAtr = 1.2;
input double          InpDowMinCloseLocation      = 0.65;
input double          InpDowMinLowerWickShare     = 0.35;
input double          InpDowMaxUpperWickShare     = 0.20;
input double InpDowStopBufferAtr = 0.2;
input double InpDowTargetBufferAtr = 0.3;
input double          InpDowMinTargetRMultiple    = 1.0;
input int             InpDowMaxHoldBars           = 24;
input bool            InpEnableRangeReclaimBucket = false;
input ENUM_TIMEFRAMES InpRangeSignalTimeframe     = PERIOD_M5;
input int             InpRangeSessionStartHour    = 7;
input int             InpRangeSessionEndHour      = 20;
input int             InpRangeLookbackBars        = 24;
input int             InpRangeAdxPeriod           = 14;
input double          InpRangeMaxAdx             = 20.0;
input int             InpRangeAtrPeriod           = 14;
input double          InpRangeMaxWidthAtrMultiple = 3.5;
input double InpRangeMinBreachAtr = 0.1;
input double InpRangeMaxBreachAtr = 0.7;
input double          InpRangeMinCloseLocation    = 0.55;
input double          InpRangeMinLowerWickShare   = 0.30;
input double          InpRangeMaxUpperWickShare   = 0.25;
input double InpRangeStopBufferAtr = 0.15;
input double InpRangeTargetBufferAtr = 0.2;
input double          InpRangeMinTargetRMultiple  = 1.0;
input int             InpRangeMaxHoldBars         = 20;
input bool            InpEnableRangeShortBucket   = false;
input bool            InpEnableFractalTrendBucket = false;
input ENUM_TIMEFRAMES InpFractalSignalTimeframe   = PERIOD_M5;
input int             InpFractalSessionStartHour  = 7;
input int             InpFractalSessionEndHour    = 20;
input int             InpFractalPivotSpan         = 2;
input int             InpFractalScanBars          = 120;
input int             InpFractalMidEMAPeriod      = 50;
input int             InpFractalSlowEMAPeriod     = 100;
input int             InpFractalStochKPeriod      = 5;
input int             InpFractalStochDPeriod      = 1;
input int             InpFractalStochSlowing      = 1;
input double          InpFractalStochBuyLevel     = 20.0;
input double InpFractalStopBufferAtr = 0.1;
input double InpFractalTargetBufferAtr = 0.2;
input double          InpFractalMinTargetRMultiple = 1.0;
input int             InpFractalMaxHoldBars       = 18;
input double          InpRiskPercent              = 0.65;
input bool            InpUseDailyLossCap          = true;
input double          InpDailyLossCapPercent      = 3.0;
input bool            InpFlattenOnDailyLossCap    = true;
input bool            InpUseEquityDrawdownCap     = true;
input double          InpEquityDrawdownCapPercent = 12.0;
input bool            InpFlattenOnEquityDrawdownCap = true;
input int             InpMaxTradesPerDay          = 2;
input double InpMaxSpreadAtr = 0.2;
input string          InpAllowedWeekdays          = "1,2,3,4,5";
input bool            InpEnableTelemetry          = true;
input string          InpTelemetryFileName        = "relative_continuation.csv";
input bool            InpEnableOperatorControl    = true;
input string          InpOperatorCommandFile      = "relative_continuation_operator.txt";
input bool            InpEnableStatusSnapshot     = true;
input string          InpStatusFileName           = "relative_continuation_status.txt";
input int             InpStatusHeartbeatSeconds   = 60;
input long            InpMagicNumber              = 2026100601;

int distanceAtrHandle = INVALID_HANDLE;
datetime distanceAtrBar = 0;
double distanceAtrValue = 0.0;
string roundDecision = "NOT_EVALUATED";
int funnelHandle = INVALID_HANDLE;
bool dailyCapLatched = false;
bool equityCapLatched = false;
bool uncertainSend = false;
datetime uncertainSince = 0;
ulong uncertainOrder = 0;
string riskStatePrefix = "";

int fastEmaHandle = INVALID_HANDLE;
int slowEmaHandle = INVALID_HANDLE;
int adxHandle = INVALID_HANDLE;
int rsiHandle = INVALID_HANDLE;
int dowFastEmaHandle = INVALID_HANDLE;
int dowSlowEmaHandle = INVALID_HANDLE;
int rangeFastEmaHandle = INVALID_HANDLE;
int rangeSlowEmaHandle = INVALID_HANDLE;
int rangeAdxHandle = INVALID_HANDLE;
int rangeAtrHandle = INVALID_HANDLE;
int fractalFastEmaHandle = INVALID_HANDLE;
int fractalMidEmaHandle = INVALID_HANDLE;
int fractalSlowEmaHandle = INVALID_HANDLE;
int fractalStochHandle = INVALID_HANDLE;
string runtimeSymbol = "";
string runtimeAllowedWeekdays = "";
string runtimeTelemetryFileName = "";
string runtimeOperatorCommandFile = "";
string runtimeStatusFileName = "";
bool runtimeOperatorControlEnabled = false;
bool runtimeStatusSnapshotEnabled = false;
bool allowedWeekdays[7];
datetime lastBarTime = 0;
datetime lastDowBarTime = 0;
datetime lastRangeBarTime = 0;
datetime lastFractalBarTime = 0;
datetime currentDayStart = 0;
int lastDayOfYear = -1;
double dailyStartBalance = 0.0;
double dailyStartEquity = 0.0;
double equityPeak = 0.0;
int dailyTradeCount = 0;
int dailyClosedTrades = 0;
int dailyEntriesBuy = 0;
int dailyEntriesSell = 0;
int consecutiveLosses = 0;
int dailyBlockedSpread = 0;
int dailyBlockedDailyLoss = 0;
int dailyBlockedTradeCap = 0;
int dailyBlockedEquityCap = 0;
int dailyLossLockActivations = 0;
int telemetryHandle = INVALID_HANDLE;
string operatorMode = "normal";
bool statusSnapshotErrorLogged = false;
bool timerStarted = false;
double dowPlannedStopPrice = 0.0;
double dowPlannedTargetPrice = 0.0;
double rangePlannedStopPrice = 0.0;
double rangePlannedTargetPrice = 0.0;
double rangeShortPlannedStopPrice = 0.0;
double rangeShortPlannedTargetPrice = 0.0;
double fractalPlannedStopPrice = 0.0;
double fractalPlannedTargetPrice = 0.0;

// RELATIVE_CONTINUATION_MODULE_END Configuration
#endif

// RELATIVE_CONTINUATION_MODULE_BEGIN RuntimeRisk
#ifndef RELATIVE_CONTINUATION_RUNTIMERISK_MQH
#define RELATIVE_CONTINUATION_RUNTIMERISK_MQH
string TrimSpaces(string value)
  {
   int start = 0;
   int finish = StringLen(value) - 1;
   while(start <= finish && StringGetCharacter(value, start) <= 32)
      start++;
   while(finish >= start && StringGetCharacter(value, finish) <= 32)
      finish--;
   if(finish < start)
      return "";
   return StringSubstr(value, 0 + start, finish - start + 1);
  }

string NormalizePresetString(string rawValue)
  {
   int marker = StringFind(rawValue, "||");
   if(marker < 0)
      return rawValue;
   return StringSubstr(rawValue, 0, marker);
  }

bool ParseWeekdays(string rawValue)
  {
   ArrayInitialize(allowedWeekdays, false);
   string items[];
   int count = StringSplit(rawValue, ',', items);
   if(count <= 0)
      return false;
   for(int i = 0; i < count; ++i)
     {
      string item = TrimSpaces(items[i]);
      if(item == "")
         continue;
      if(StringLen(item) != 1 || StringGetCharacter(item,0) < '0' || StringGetCharacter(item,0) > '6')
         return false;
      int day = (int)StringToInteger(item);
      if(day < 0 || day > 6)
         return false;
      allowedWeekdays[day] = true;
     }
   return true;
  }

bool IsAllowedWeekday(int dayOfWeek)
  {
   if(dayOfWeek < 0 || dayOfWeek > 6)
      return false;
   return allowedWeekdays[dayOfWeek];
  }

double GetDistanceUnit()
  {
   // All price-distance inputs share closed signal-TF ATR. Never bar 0.
   datetime stamp = iTime(runtimeSymbol, InpSignalTimeframe, 0);
   if(stamp <= 0 || distanceAtrHandle == INVALID_HANDLE) return 0.0;
   if(stamp == distanceAtrBar && distanceAtrValue > 0.0) return distanceAtrValue;
   double value[1];
   if(CopyBuffer(distanceAtrHandle,0,1,1,value) != 1 ||
      !MathIsValidNumber(value[0]) || value[0] <= 0.0) return 0.0;
   distanceAtrBar = stamp;
   distanceAtrValue = value[0];
   return distanceAtrValue;
  }

double NormalizePrice(double price)
  {
   int digits = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_DIGITS);
   double step = SymbolInfoDouble(runtimeSymbol, SYMBOL_TRADE_TICK_SIZE);
   if(step <= 0.0) return 0.0;
   return NormalizeDouble(MathRound(price / step) * step, digits);
  }

double GetCurrentSpreadAtr()
  {
   MqlTick tick;
   if(!SymbolInfoTick(runtimeSymbol, tick) || tick.bid <= 0.0 || tick.ask < tick.bid)
      return -1.0;
   double unit = GetDistanceUnit();
   if(unit <= 0.0)
      return -1.0;
   return (tick.ask - tick.bid) / unit;
  }

bool IsSpreadAllowed()
  {
   if(InpMaxSpreadAtr <= 0.0)
      return true;
   double spreadAtr = GetCurrentSpreadAtr();
   if(spreadAtr < 0.0)
      return false;
   // Tolerance for floating arithmetic only; does not grant an extra tick.
   return (spreadAtr <= InpMaxSpreadAtr + 1e-10);
  }

int VolumeDigits(double stepVolume)
  {
   int digits = 0;
   double scaled = stepVolume;
   while(digits < 8 && MathAbs(scaled - MathRound(scaled)) > 1e-8)
     {
      scaled *= 10.0;
      digits++;
     }
   return digits;
  }

double GetEffectiveRiskPercent(double equity)
  {
   return InpRiskPercent;
  }

double CalculateVolume(ENUM_ORDER_TYPE side,double entryPrice,double stopPrice)
  {
   PFPlan p;PFAudit a;bool ok=PFMakeAdjustedPlan(runtimeSymbol,side,entryPrice,stopPrice,InpRiskPercent,GetDistanceUnit(),InpAdjustRoundedVolume,p,a);
   PFWrite(runtimeSymbol,side,entryPrice,stopPrice,p);
   PFAWrite(runtimeSymbol,side,InpAdjustRoundedVolume,entryPrice,stopPrice,p,a);
   if(!ok){Print("ORDER_SKIPPED ",p.reason);return 0;}
   return p.volume;
  }

bool IsNewBarForTimeframe(ENUM_TIMEFRAMES timeframe, datetime &lastSeenBarTime, datetime &barTime)
  {
   datetime times[];
   ArraySetAsSeries(times, true);
   if(CopyTime(runtimeSymbol, timeframe, 0, 2, times) < 2)
      return false;
   if(times[0] == lastSeenBarTime)
      return false;
   lastSeenBarTime = times[0];
   barTime = times[0];
   return true;
  }

bool IsNewBar(datetime &barTime)
  {
   return IsNewBarForTimeframe(InpSignalTimeframe, lastBarTime, barTime);
  }

void ResetDailyCounters()
  {
   dailyTradeCount = 0;
   dailyClosedTrades = 0;
   dailyEntriesBuy = 0;
   dailyEntriesSell = 0;
   consecutiveLosses = 0;
   dailyBlockedSpread = 0;
   dailyBlockedDailyLoss = 0;
   dailyBlockedTradeCap = 0;
   dailyBlockedEquityCap = 0;
   dailyLossLockActivations = 0;
  }

void UpdateDailyAnchor()
  {
   datetime nowTime = TimeCurrent();
   MqlDateTime ts;
   TimeToStruct(nowTime, ts);
   datetime day = (datetime)(nowTime - ts.hour*3600 - ts.min*60 - ts.sec);
   if(day != currentDayStart)
     {
      if(currentDayStart > 0)
         FlushDailySummary(nowTime, "rollover");
      lastDayOfYear = ts.day_of_year;
      ts.hour = 0;
      ts.min = 0;
      ts.sec = 0;
      currentDayStart = StructToTime(ts);
      dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      dailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(equityPeak <= 0.0)
         equityPeak = dailyStartEquity;
      ResetDailyCounters();
      dailyCapLatched = false;
      RestoreRiskState();
      LogTelemetryEvent(nowTime, "day_reset", "", "", 0.0, 0.0, 0.0, "");
     }
  }

void UpdateEquityPeak()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equityPeak <= 0.0 || equity > equityPeak)
     {
      equityPeak = equity;
      SaveRiskState();
     }
  }

bool IsDailyLossCapBlocked()
  {
   if(!InpUseDailyLossCap || InpDailyLossCapPercent <= 0.0 || dailyStartEquity <= 0.0)
      return false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= dailyStartEquity * (1.0 - InpDailyLossCapPercent / 100.0))
     {
      dailyCapLatched = true;
      SaveRiskState();
     }
   return dailyCapLatched;
  }

bool IsEquityDrawdownBlocked()
  {
   if(!InpUseEquityDrawdownCap || InpEquityDrawdownCapPercent <= 0.0 || equityPeak <= 0.0)
      return false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= equityPeak * (1.0 - InpEquityDrawdownCapPercent / 100.0))
     {
      equityCapLatched = true;
      SaveRiskState();
     }
   return equityCapLatched;
  }

bool IsTradeCountBlocked()
  {
   if(InpMaxTradesPerDay <= 0)
      return false;
   return (dailyTradeCount >= InpMaxTradesPerDay);
  }

bool IsWithinSession(datetime barTime, int sessionStartHour, int sessionEndHour)
  {
   MqlDateTime ts;
   TimeToStruct(barTime, ts);
   if(sessionStartHour < sessionEndHour)
      return ts.hour >= sessionStartHour && ts.hour < sessionEndHour;
   return ts.hour >= sessionStartHour || ts.hour < sessionEndHour;
  }

bool IsWithinActiveSession(datetime barTime)
  {
   return IsWithinSession(barTime, InpSessionStartHour, InpSessionEndHour);
  }

// RELATIVE_CONTINUATION_MODULE_END RuntimeRisk
#endif

#ifndef RELATIVE_CONTINUATION_EXECUTION_SAFETY_MQH
#define RELATIVE_CONTINUATION_EXECUTION_SAFETY_MQH
// Diagnostic-only core shared by the production display and research replay.
#ifndef M15_ENVIRONMENT_CORE
#define M15_ENVIRONMENT_CORE
struct M15EnvPivot { double price; datetime bar,confirmed; };
struct M15EnvSnapshot
{
   string regime,position,location,break_direction;
   double high,low,raw,normalized,break_level,break_minutes;
   datetime asof,break_time,break_bar,break_confirmed;
};
class CM15Environment
{
private:
   M15EnvPivot ho,hn,lo,ln;
   int highs,lows;
   datetime used_high,used_low,bull_time,bear_time;
   M15EnvPivot bull,bear;
public:
   datetime last;
   void Reset()
   {
      ZeroMemory(ho);ZeroMemory(hn);ZeroMemory(lo);ZeroMemory(ln);
      ZeroMemory(bull);ZeroMemory(bear);highs=0;lows=0;last=0;
      used_high=0;used_low=0;bull_time=0;bear_time=0;
   }
   void Step(const MqlRates &r[],const int i)
   {
      datetime known=r[i].time+900;if(known<=last) return;
      int k=i-2;
      if(k>=2)
      {
         bool h=true,l=true;
         for(int j=1;j<=2;j++)
         {
            if(r[k].high<=r[k-j].high || r[k].high<r[k+j].high) h=false;
            if(r[k].low>=r[k-j].low || r[k].low>r[k+j].low) l=false;
         }
         if(h){ho=hn;hn.price=r[k].high;hn.bar=r[k].time;hn.confirmed=known;highs++;}
         if(l){lo=ln;ln.price=r[k].low;ln.bar=r[k].time;ln.confirmed=known;lows++;}
      }
      if(highs>0 && hn.bar!=used_high && r[i].close>hn.price)
      {used_high=hn.bar;bull=hn;bull_time=known;}
      if(lows>0 && ln.bar!=used_low && r[i].close<ln.price)
      {used_low=ln.bar;bear=ln;bear_time=known;}
      last=known;
   }
   void Snapshot(const datetime when,const double ask,M15EnvSnapshot &s)
   {
      ZeroMemory(s);s.regime="UNKNOWN";s.position="UNKNOWN";s.location="UNKNOWN";
      s.break_direction="NONE";s.raw=EMPTY_VALUE;s.normalized=EMPTY_VALUE;s.break_minutes=EMPTY_VALUE;s.asof=last;
      if(highs>=2 && lows>=2)
      {
         s.regime=(hn.price>ho.price && ln.price>lo.price)?"UP":
                  ((hn.price<ho.price && ln.price<lo.price)?"DOWN":"RANGE");
         s.high=MathMax(ho.price,hn.price);s.low=MathMin(lo.price,ln.price);
         if(s.high>s.low && ask>0)
         {
            s.raw=(ask-s.low)/(s.high-s.low);s.normalized=MathMax(0.0,MathMin(1.0,s.raw));
            s.position=s.normalized<=1.0/3.0?"LOW":(s.normalized<=2.0/3.0?"MID":"HIGH");
            s.location=s.raw<0?"BELOW":(s.raw>1?"ABOVE":"INSIDE");
         }
      }
      if(bull_time>0 || bear_time>0)
      {
         bool up=bull_time>bear_time;M15EnvPivot p=up?bull:bear;
         s.break_direction=up?"BULLISH":"BEARISH";s.break_time=up?bull_time:bear_time;
         s.break_level=p.price;s.break_bar=p.bar;s.break_confirmed=p.confirmed;
         s.break_minutes=(double)(when-s.break_time)/60.0;
      }
   }
};
#endif

// Diagnostic-only core shared by the production display and research replay.
#ifndef HTF_RESEARCH_ENVIRONMENT_CORE
#define HTF_RESEARCH_ENVIRONMENT_CORE
struct HTFResearchPivot { double price; datetime bar,confirmed; };
struct HTFResearchSnapshot
{
   string regime,position,location,break_direction;
   double high,low,raw,normalized,break_level,break_minutes;
   datetime asof,break_time,break_bar,break_confirmed;
};
class CHTFResearchEnvironment
{
private:
   HTFResearchPivot ho,hn,lo,ln;
   int highs,lows;
   datetime used_high,used_low,bull_time,bear_time;
   HTFResearchPivot bull,bear;
public:
   datetime last;
   void Reset()
   {
      ZeroMemory(ho);ZeroMemory(hn);ZeroMemory(lo);ZeroMemory(ln);
      ZeroMemory(bull);ZeroMemory(bear);highs=0;lows=0;last=0;
      used_high=0;used_low=0;bull_time=0;bear_time=0;
   }
   void Step(const MqlRates &r[],const int i,const int seconds)
   {
      datetime known=r[i].time+seconds;if(known<=last) return;
      int k=i-2;
      if(k>=2)
      {
         bool h=true,l=true;
         for(int j=1;j<=2;j++)
         {
            if(r[k].high<=r[k-j].high || r[k].high<r[k+j].high) h=false;
            if(r[k].low>=r[k-j].low || r[k].low>r[k+j].low) l=false;
         }
         if(h){ho=hn;hn.price=r[k].high;hn.bar=r[k].time;hn.confirmed=known;highs++;}
         if(l){lo=ln;ln.price=r[k].low;ln.bar=r[k].time;ln.confirmed=known;lows++;}
      }
      if(highs>0 && hn.bar!=used_high && r[i].close>hn.price)
      {used_high=hn.bar;bull=hn;bull_time=known;}
      if(lows>0 && ln.bar!=used_low && r[i].close<ln.price)
      {used_low=ln.bar;bear=ln;bear_time=known;}
      last=known;
   }
   void Snapshot(const datetime when,const double ask,HTFResearchSnapshot &s)
   {
      ZeroMemory(s);s.regime="UNKNOWN";s.position="UNKNOWN";s.location="UNKNOWN";
      s.break_direction="NONE";s.raw=EMPTY_VALUE;s.normalized=EMPTY_VALUE;s.break_minutes=EMPTY_VALUE;s.asof=last;
      if(highs>=2 && lows>=2)
      {
         s.regime=(hn.price>ho.price && ln.price>lo.price)?"UP":
                  ((hn.price<ho.price && ln.price<lo.price)?"DOWN":"RANGE");
         s.high=MathMax(ho.price,hn.price);s.low=MathMin(lo.price,ln.price);
         if(s.high>s.low && ask>0)
         {
            s.raw=(ask-s.low)/(s.high-s.low);s.normalized=MathMax(0.0,MathMin(1.0,s.raw));
            s.position=s.normalized<=1.0/3.0?"LOW":(s.normalized<=2.0/3.0?"MID":"HIGH");
            s.location=s.raw<0?"BELOW":(s.raw>1?"ABOVE":"INSIDE");
         }
      }
      if(bull_time>0 || bear_time>0)
      {
         bool up=bull_time>bear_time;HTFResearchPivot p=up?bull:bear;
         s.break_direction=up?"BULLISH":"BEARISH";s.break_time=up?bull_time:bear_time;
         s.break_level=p.price;s.break_bar=p.bar;s.break_confirmed=p.confirmed;
         s.break_minutes=(double)(when-s.break_time)/60.0;
      }
   }
};
#endif

// Tester-only observer. No trade calls and no environment-based entry gate.
int dcContext=INVALID_HANDLE,dcPath=INVALID_HANDLE;
HTFResearchSnapshot dcPlan[3];
int dcCounts[3];bool dcComplete[3];
datetime dcDecision=0;string dcId="";
MqlTick dcQuote;
ENUM_TIMEFRAMES dcTF[3]={PERIOD_M15,PERIOD_H1,PERIOD_H4};
struct DCPath
  {
   string id;datetime entry,minute;long first_msc,last_msc;
   double open,high,low,close;bool started;
  };
DCPath dcPaths[];

string DCNumber(const double value)
  { return value==EMPTY_VALUE ? "" : DoubleToString(value,12); }

bool DCOpen()
  {
   dcContext=FileOpen(runtimeTelemetryFileName+".context.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   dcPath=FileOpen(runtimeTelemetryFileName+".path.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(dcContext==INVALID_HANDLE || dcPath==INVALID_HANDLE) return false;
   FileWrite(dcContext,"id","stage","time","decision_time","price","tf","closed_bars","history_complete",
      "asof","regime","position","raw_position","location","range_valid","structure_high","structure_low",
      "break_direction","break_time","break_bar","break_confirmed","break_level","break_minutes",
      "m15_reference_equal","bid","ask","spread_price","spread_points","spread_atr","atr",
      "server_hour","server_weekday","execution_gate","spread_allowed","positions","daily_entries",
      "daily_cap","equity_cap","uncertain_send","planned_sl","planned_tp","hold_bars");
   FileWrite(dcPath,"id","minute","first_msc","last_msc","open_bid","high_bid","low_bid","close_bid","horizon_end","end_censored");
   return true;
  }

void DCLoad(const datetime when,const double price)
  {
   for(int t=0;t<3;t++)
     {
      MqlRates r[];ArraySetAsSeries(r,false);
      int n=CopyRates(runtimeSymbol,dcTF[t],0,1200,r),secs=PeriodSeconds(dcTF[t]);
      CHTFResearchEnvironment env;env.Reset();CM15Environment original;original.Reset();dcCounts[t]=0;
      for(int i=0;i<n;i++)
        {
         if(r[i].time+secs>when) break;
         env.Step(r,i,secs);if(t==0) original.Step(r,i);dcCounts[t]++;
        }
      env.Snapshot(when,price,dcPlan[t]);dcComplete[t]=(n>=1199 && dcCounts[t]>=1198);
      if(t==0)
        {
         M15EnvSnapshot b;original.Snapshot(when,price,b);
         if(b.regime!=dcPlan[t].regime || b.position!=dcPlan[t].position || b.raw!=dcPlan[t].raw ||
            b.location!=dcPlan[t].location || b.high!=dcPlan[t].high || b.low!=dcPlan[t].low ||
            b.break_direction!=dcPlan[t].break_direction || b.break_time!=dcPlan[t].break_time ||
            b.break_confirmed!=dcPlan[t].break_confirmed || b.break_bar!=dcPlan[t].break_bar ||
            b.break_level!=dcPlan[t].break_level || b.break_minutes!=dcPlan[t].break_minutes)
               Print("DC_CAUSAL_OR_PARITY_FAILURE");
        }
      if(!dcComplete[t])
        {
         dcPlan[t].regime="UNKNOWN";dcPlan[t].position="UNKNOWN";dcPlan[t].location="UNKNOWN";
         dcPlan[t].raw=EMPTY_VALUE;dcPlan[t].normalized=EMPTY_VALUE;
        }
     }
  }

void DCWrite(const string stage,const datetime when,const double price,const bool gate)
  {
   MqlDateTime dt;TimeToStruct(dcDecision,dt);
   double atr=GetDistanceUnit(),point=SymbolInfoDouble(runtimeSymbol,SYMBOL_POINT);
   double sl=NormalizePrice(dcQuote.ask-InpStopLossAtr*atr);
   double tp=NormalizePrice(dcQuote.ask+InpStopLossAtr*atr*InpTargetRMultiple);
   for(int t=0;t<3;t++)
     {
      HTFResearchSnapshot s=dcPlan[t];
      if(s.asof>dcDecision || s.break_confirmed>dcDecision || s.break_time>dcDecision || dcDecision>when)
         Print("DC_CAUSAL_OR_PARITY_FAILURE");
      bool valid=dcComplete[t] && s.high>s.low && s.regime!="UNKNOWN";
      if(valid)
        {
         s.raw=(price-s.low)/(s.high-s.low);
         s.position=s.raw<=1.0/3.0?"LOW":(s.raw<=2.0/3.0?"MID":"HIGH");
         s.location=s.raw<0?"BELOW":(s.raw>1?"ABOVE":"INSIDE");
        }
      FileWrite(dcContext,dcId,stage,TimeToString(when,TIME_DATE|TIME_SECONDS),TimeToString(dcDecision,TIME_DATE|TIME_SECONDS),
         DCNumber(price),EnumToString(dcTF[t]),dcCounts[t],(int)dcComplete[t],TimeToString(s.asof,TIME_DATE|TIME_SECONDS),
         s.regime,s.position,DCNumber(s.raw),s.location,(int)valid,DCNumber(s.high),DCNumber(s.low),s.break_direction,
         TimeToString(s.break_time,TIME_DATE|TIME_SECONDS),TimeToString(s.break_bar,TIME_DATE|TIME_SECONDS),
         TimeToString(s.break_confirmed,TIME_DATE|TIME_SECONDS),DCNumber(s.break_level),DCNumber(s.break_minutes),1,
         DCNumber(dcQuote.bid),DCNumber(dcQuote.ask),DCNumber(dcQuote.ask-dcQuote.bid),
         DCNumber(point>0?(dcQuote.ask-dcQuote.bid)/point:EMPTY_VALUE),DCNumber(atr>0?(dcQuote.ask-dcQuote.bid)/atr:EMPTY_VALUE),
         DCNumber(atr),dt.hour,dt.day_of_week,(int)gate,(int)IsSpreadAllowed(),CountManagedPositions(),dailyTradeCount,
         (int)dailyCapLatched,(int)equityCapLatched,(int)uncertainSend,DCNumber(sl),DCNumber(tp),InpMaxHoldBars);
     }
  }

void DCFlush(const int i,const bool horizon,const bool censored)
  {
   if(!dcPaths[i].started) return;
   FileWrite(dcPath,dcPaths[i].id,TimeToString(dcPaths[i].minute,TIME_DATE|TIME_SECONDS),dcPaths[i].first_msc,dcPaths[i].last_msc,
      DCNumber(dcPaths[i].open),DCNumber(dcPaths[i].high),DCNumber(dcPaths[i].low),DCNumber(dcPaths[i].close),(int)horizon,(int)censored);
  }

void DCUpdate(const bool newBar)
  {
   if(ArraySize(dcPaths)==0) return;
   MqlTick t;if(!SymbolInfoTick(runtimeSymbol,t) || t.bid<=0) return;
   datetime minute=(datetime)((long)t.time/60*60);
   for(int i=ArraySize(dcPaths)-1;i>=0;i--)
     {
      if(t.time<dcPaths[i].entry) continue;
      if(!dcPaths[i].started || dcPaths[i].minute!=minute)
        {
         DCFlush(i,false,false);dcPaths[i].started=true;dcPaths[i].minute=minute;dcPaths[i].first_msc=t.time_msc;
         dcPaths[i].open=t.bid;dcPaths[i].high=t.bid;dcPaths[i].low=t.bid;
        }
      dcPaths[i].last_msc=t.time_msc;dcPaths[i].close=t.bid;
      dcPaths[i].high=MathMax(dcPaths[i].high,t.bid);dcPaths[i].low=MathMin(dcPaths[i].low,t.bid);
      if(newBar && iBarShift(runtimeSymbol,InpSignalTimeframe,dcPaths[i].entry,false)>=InpMaxHoldBars)
        {
         DCFlush(i,true,false);int lastIndex=ArraySize(dcPaths)-1;
         if(i!=lastIndex) dcPaths[i]=dcPaths[lastIndex];ArrayResize(dcPaths,lastIndex);
        }
     }
  }

void DCCandidate(const datetime barTime,const bool gate)
  {
   if(!SymbolInfoTick(runtimeSymbol,dcQuote)) return;
   dcDecision=TimeCurrent();dcId=TimeToString(barTime,TIME_DATE|TIME_SECONDS);
   DCLoad(dcDecision,dcQuote.ask);DCWrite("CANDIDATE",dcDecision,dcQuote.ask,gate);
   PCWrite(dcId,runtimeSymbol,dcDecision,dcPlan);
   int n=ArraySize(dcPaths);ArrayResize(dcPaths,n+1);ZeroMemory(dcPaths[n]);
   dcPaths[n].id=dcId;dcPaths[n].entry=dcDecision;DCUpdate(false);
  }

void DCEntry(const datetime when,const double fill)
  { DCWrite("ENTRY",when,fill,true); }

void DCClose()
  {
   for(int i=0;i<ArraySize(dcPaths);i++) DCFlush(i,false,true);
   if(dcContext!=INVALID_HANDLE) FileClose(dcContext);
   if(dcPath!=INVALID_HANDLE) FileClose(dcPath);
  }

#ifndef PORTABLE_CONTEXT_DIAGNOSTICS_MQH
#define PORTABLE_CONTEXT_DIAGNOSTICS_MQH
// Observations only. Closed bars, prior-bar normalization, no outcome/entry filter.
ENUM_TIMEFRAMES pcTF[4]={PERIOD_M5,PERIOD_M15,PERIOD_H1,PERIOD_H4};
int pcAtr[4]={INVALID_HANDLE,INVALID_HANDLE,INVALID_HANDLE,INVALID_HANDLE};
int pcEma[4]={INVALID_HANDLE,INVALID_HANDLE,INVALID_HANDLE,INVALID_HANDLE};
int pcFile=INVALID_HANDLE;
bool PCOpen(const string symbol,const string file)
  {
   ArrayInitialize(pcAtr,INVALID_HANDLE);ArrayInitialize(pcEma,INVALID_HANDLE);
   pcFile=FileOpen(file,FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');if(pcFile==INVALID_HANDLE)return false;
   FileWrite(pcFile,"id","symbol","decision","tf","closed_bar","available_at","history_ready","legacy_regime","legacy_position",
             "legacy_raw_position","legacy_break_direction","legacy_break_minutes","range_valid","asof","structure_high","structure_low",
             "closed_price_above_structure","closed_price_below_structure","range_atr_prior","body_atr_prior","gap_atr_prior",
             "tick_volume_ratio_prior20","real_volume_ratio_prior20","volume_source","ema20_slope3_atr","distance_ema20_atr",
             "spread_price","spread_atr","atr","atr_prior","min_lot","contract_size","return_3bars_atr");
   for(int i=0;i<4;i++)
     {
      pcAtr[i]=iATR(symbol,pcTF[i],14);pcEma[i]=iMA(symbol,pcTF[i],20,0,MODE_EMA,PRICE_CLOSE);
      if(pcAtr[i]==INVALID_HANDLE||pcEma[i]==INVALID_HANDLE)return false;
     }
   return true;
  }
string PCNum(const double n){return n==EMPTY_VALUE||!MathIsValidNumber(n)?"":DoubleToString(n,12);}
void PCWrite(const string id,const string symbol,const datetime decision,const HTFResearchSnapshot &context[])
  {
   MqlTick q;if(pcFile==INVALID_HANDLE||!SymbolInfoTick(symbol,q)||q.time>decision)return;
   for(int i=0;i<4;i++)
     {
      MqlRates r[];ArraySetAsSeries(r,true);double a[],e[];ArraySetAsSeries(a,true);ArraySetAsSeries(e,true);
      int seconds=PeriodSeconds(pcTF[i]);
      bool ready=CopyRates(symbol,pcTF[i],0,24,r)==24 && CopyBuffer(pcAtr[i],0,1,2,a)==2 && CopyBuffer(pcEma[i],0,1,4,e)==4;
      if(!ready || r[1].time+seconds>decision || a[0]<=0 || a[1]<=0)
        {
         FileWrite(pcFile,id,symbol,TimeToString(decision,TIME_DATE|TIME_SECONDS),EnumToString(pcTF[i]),"","",0);
         continue;
        }
      double ticks=0,real=0;bool allReal=true;
      for(int j=2;j<=21;j++){ticks+=(double)r[j].tick_volume;real+=(double)r[j].real_volume;if(r[j].real_volume<=0)allReal=false;}
      double tv=ticks>0?(double)r[1].tick_volume/(ticks/20):EMPTY_VALUE;
      double rv=allReal&&real>0&&r[1].real_volume>0?(double)r[1].real_volume/(real/20):EMPTY_VALUE;
      HTFResearchSnapshot s;ZeroMemory(s);s.regime="NA";s.position="NA";s.break_direction="NA";s.raw=EMPTY_VALUE;s.break_minutes=EMPTY_VALUE;
      if(i>0)s=context[i-1];
      if(s.asof>decision || s.break_confirmed>decision || s.break_time>decision){Print("PC_FATAL_FUTURE_CONTEXT");continue;}
      bool valid=i>0&&s.high>s.low&&s.regime!="UNKNOWN";
      FileWrite(pcFile,id,symbol,TimeToString(decision,TIME_DATE|TIME_SECONDS),EnumToString(pcTF[i]),
          TimeToString(r[1].time,TIME_DATE|TIME_SECONDS),TimeToString(r[1].time+seconds,TIME_DATE|TIME_SECONDS),1,
          s.regime,s.position,PCNum(s.raw),s.break_direction,PCNum(s.break_minutes),(int)valid,TimeToString(s.asof,TIME_DATE|TIME_SECONDS),
          PCNum(s.high),PCNum(s.low),(int)(valid&&r[1].close>s.high),(int)(valid&&r[1].close<s.low),
          PCNum((r[1].high-r[1].low)/a[1]),PCNum((r[1].close-r[1].open)/a[1]),PCNum((r[1].open-r[2].close)/a[1]),
          PCNum(tv),PCNum(rv),rv==EMPTY_VALUE?"TICK_ONLY":"REAL_AND_TICK",PCNum((e[0]-e[3])/a[0]),PCNum((r[1].close-e[0])/a[0]),
          PCNum(q.ask-q.bid),PCNum((q.ask-q.bid)/a[0]),PCNum(a[0]),PCNum(a[1]),SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN),
          SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE),PCNum((r[1].close-r[4].close)/a[1]));
     }
  }
void PCClose()
  {
   if(pcFile!=INVALID_HANDLE){FileClose(pcFile);pcFile=INVALID_HANDLE;}
   for(int i=0;i<4;i++){if(pcAtr[i]!=INVALID_HANDLE)IndicatorRelease(pcAtr[i]);if(pcEma[i]!=INVALID_HANDLE)IndicatorRelease(pcEma[i]);}
  }
#endif


bool PersistRiskState()
  {
   return !(bool)MQLInfoInteger(MQL_TESTER) && riskStatePrefix != "";
  }

void SaveRiskState()
  {
   if(!PersistRiskState()) return;
   GlobalVariableSet(riskStatePrefix+"day",(double)currentDayStart);
   GlobalVariableSet(riskStatePrefix+"equity",dailyStartEquity);
   GlobalVariableSet(riskStatePrefix+"balance",dailyStartBalance);
   GlobalVariableSet(riskStatePrefix+"peak",equityPeak);
   GlobalVariableSet(riskStatePrefix+"daily",dailyCapLatched ? 1.0 : 0.0);
   GlobalVariableSet(riskStatePrefix+"dd",equityCapLatched ? 1.0 : 0.0);
   GlobalVariableSet(riskStatePrefix+"send",uncertainSend ? (double)uncertainSince : 0.0);
   GlobalVariableSet(riskStatePrefix+"order",(double)uncertainOrder);
  }

void RestoreRiskState()
  {
   if(PersistRiskState())
     {
      if(GlobalVariableCheck(riskStatePrefix+"peak"))
         equityPeak = MathMax(equityPeak,GlobalVariableGet(riskStatePrefix+"peak"));
      equityCapLatched = GlobalVariableGet(riskStatePrefix+"dd") > 0.0;
      if((datetime)GlobalVariableGet(riskStatePrefix+"day") == currentDayStart)
        {
         dailyStartEquity = GlobalVariableGet(riskStatePrefix+"equity");
         dailyStartBalance = GlobalVariableGet(riskStatePrefix+"balance");
         dailyCapLatched = GlobalVariableGet(riskStatePrefix+"daily") > 0.0;
        }
      uncertainSince = (datetime)GlobalVariableGet(riskStatePrefix+"send");
      uncertainSend = uncertainSince > 0;
      uncertainOrder = (ulong)GlobalVariableGet(riskStatePrefix+"order");
     }
   SaveRiskState();
  }

bool RefreshDailyTradeCount()
  {
   if(!HistorySelect(currentDayStart,TimeCurrent())) return false;
   ulong ids[];
   for(int i=0;i<HistoryDealsTotal();i++)
     {
      ulong deal=HistoryDealGetTicket(i);
      if(HistoryDealGetString(deal,DEAL_SYMBOL)!=runtimeSymbol ||
         HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagicNumber ||
         HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_IN) continue;
      ulong order= (ulong)HistoryDealGetInteger(deal,DEAL_ORDER);
      bool found=false;
      for(int j=0;j<ArraySize(ids);j++) if(ids[j]==order) { found=true; break; }
      if(!found) { int n=ArraySize(ids); ArrayResize(ids,n+1); ids[n]=order; }
     }
   dailyTradeCount=ArraySize(ids); // one entry order, not one partial fill
   return true;
  }

bool HasPendingManagedOrder()
  {
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong id=OrderGetTicket(i);
      if(id>0 && OrderGetString(ORDER_SYMBOL)==runtimeSymbol &&
         OrderGetInteger(ORDER_MAGIC)==InpMagicNumber) return true;
     }
   return false;
  }

void ReconcileUncertainSend()
  {
   if(!uncertainSend || HasPendingManagedOrder()) return;
   bool resolved=CountManagedPositions()>0;
   if(!resolved && HistorySelect(uncertainSince-60,TimeCurrent()))
     {
      for(int i=HistoryDealsTotal()-1;i>=0;i--)
        {
         ulong d=HistoryDealGetTicket(i);
         if(HistoryDealGetString(d,DEAL_SYMBOL)==runtimeSymbol && HistoryDealGetInteger(d,DEAL_MAGIC)==InpMagicNumber &&
            HistoryDealGetInteger(d,DEAL_ENTRY)==DEAL_ENTRY_IN &&
            HistoryDealGetInteger(d,DEAL_TIME)>=uncertainSince) { resolved=true; break; }
        }
      if(!resolved && uncertainOrder>0 && HistoryOrderSelect(uncertainOrder))
        {
         ENUM_ORDER_STATE state=(ENUM_ORDER_STATE)HistoryOrderGetInteger(uncertainOrder,ORDER_STATE);
         resolved=(state==ORDER_STATE_CANCELED || state==ORDER_STATE_REJECTED || state==ORDER_STATE_EXPIRED);
        }
     }
   if(resolved) { uncertainSend=false; uncertainOrder=0; SaveRiskState(); Print("SEND_RECONCILED"); }
   // No evidence of acceptance or rejection: fail closed; never blindly retry.
  }

bool CheckTradeResult(bool apiResult, string operation)
  {
   uint rc=trade.ResultRetcode();
   bool filled=apiResult && (rc==TRADE_RETCODE_DONE || rc==TRADE_RETCODE_DONE_PARTIAL);
   if(!filled) PrintFormat("TRADE_RESULT operation=%s retcode=%u order=%I64u deal=%I64u description=%s",
                          operation,rc,trade.ResultOrder(),trade.ResultDeal(),trade.ResultRetcodeDescription());
   return filled;
  }

bool RecordRoundDecision(string reason, bool passed=false)
  {
   roundDecision=reason;
   return passed;
  }

void RecordFunnel(datetime barTime, bool signal, bool gate)
  {
   if(signal) DCCandidate(barTime,gate);
   if(!InpWriteFunnel) return;
   if(funnelHandle==INVALID_HANDLE)
     {
      funnelHandle=FileOpen(runtimeTelemetryFileName+".funnel.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,';');
      if(funnelHandle==INVALID_HANDLE) return;
      FileWrite(funnelHandle,"time","signal","signal_reason","entry_gate","spread_atr","spread_allowed",
                "atr","positions","daily_entries","daily_cap","equity_cap","uncertain_send");
     }
   FileWrite(funnelHandle,TimeToString(barTime,TIME_DATE|TIME_SECONDS),signal,roundDecision,gate,
             GetCurrentSpreadAtr(),IsSpreadAllowed(),GetDistanceUnit(),CountManagedPositions(),dailyTradeCount,
             dailyCapLatched,equityCapLatched,uncertainSend);
   // Buffered; close flushes. Avoid per-bar forced disk sync in optimization.
  }
#endif

// RELATIVE_CONTINUATION_MODULE_BEGIN MarketData
#ifndef RELATIVE_CONTINUATION_MARKETDATA_MQH
#define RELATIVE_CONTINUATION_MARKETDATA_MQH
bool LoadSignalWindow(MqlRates &rates[], double &fastEma[], double &slowEma[], double &adxValues[], double &rsiValues[], int count)
  {
   count=MathMax(count,MathMax(InpTrendScanBars+InpPivotSpan+3,
         MathMax(InpSlowSlopeLookback+3,MathMax(InpVolatilityLookbackBars+3,
         MathMax(InpBreakoutLookbackBars+InpBreakoutRetestDelayBars+5,
         MathMax(InpDowTrendScanBars+InpDowPivotSpan+3,
         MathMax(InpRangeLookbackBars+5,InpFractalScanBars+InpFractalPivotSpan+3)))))));
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(fastEma, true);
   ArraySetAsSeries(slowEma, true);
   ArraySetAsSeries(adxValues, true);
   ArraySetAsSeries(rsiValues, true);
   int copiedRates = CopyRates(runtimeSymbol, InpSignalTimeframe, 0, count, rates);
   if(copiedRates != count)
      return false;
   int copiedFast = CopyBuffer(fastEmaHandle, 0, 0, count, fastEma);
   int copiedSlow = CopyBuffer(slowEmaHandle, 0, 0, count, slowEma);
   int copiedAdx = CopyBuffer(adxHandle, 0, 0, count, adxValues);
   int copiedRsi = CopyBuffer(rsiHandle, 0, 0, count, rsiValues);
   return copiedFast == copiedRates && copiedSlow == copiedRates && copiedAdx == copiedRates && copiedRsi == copiedRates;
  }

bool LoadDowSignalWindow(MqlRates &rates[], double &fastEma[], double &slowEma[], int count)
  {
   count=MathMax(count,MathMax(InpTrendScanBars+InpPivotSpan+3,
         MathMax(InpSlowSlopeLookback+3,MathMax(InpVolatilityLookbackBars+3,
         MathMax(InpBreakoutLookbackBars+InpBreakoutRetestDelayBars+5,
         MathMax(InpDowTrendScanBars+InpDowPivotSpan+3,
         MathMax(InpRangeLookbackBars+5,InpFractalScanBars+InpFractalPivotSpan+3)))))));
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(fastEma, true);
   ArraySetAsSeries(slowEma, true);
   int copiedRates = CopyRates(runtimeSymbol, InpDowSignalTimeframe, 0, count, rates);
   if(copiedRates != count)
      return false;
   int copiedFast = CopyBuffer(dowFastEmaHandle, 0, 0, count, fastEma);
   int copiedSlow = CopyBuffer(dowSlowEmaHandle, 0, 0, count, slowEma);
   return copiedFast == copiedRates && copiedSlow == copiedRates;
  }

bool LoadRangeSignalWindow(MqlRates &rates[], double &fastEma[], double &slowEma[], double &adxValues[], double &atrValues[], int count)
  {
   count=MathMax(count,MathMax(InpTrendScanBars+InpPivotSpan+3,
         MathMax(InpSlowSlopeLookback+3,MathMax(InpVolatilityLookbackBars+3,
         MathMax(InpBreakoutLookbackBars+InpBreakoutRetestDelayBars+5,
         MathMax(InpDowTrendScanBars+InpDowPivotSpan+3,
         MathMax(InpRangeLookbackBars+5,InpFractalScanBars+InpFractalPivotSpan+3)))))));
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(fastEma, true);
   ArraySetAsSeries(slowEma, true);
   ArraySetAsSeries(adxValues, true);
   ArraySetAsSeries(atrValues, true);
   int copiedRates = CopyRates(runtimeSymbol, InpRangeSignalTimeframe, 0, count, rates);
   if(copiedRates != count)
      return false;
   int copiedFast = CopyBuffer(rangeFastEmaHandle, 0, 0, count, fastEma);
   int copiedSlow = CopyBuffer(rangeSlowEmaHandle, 0, 0, count, slowEma);
   int copiedAdx = CopyBuffer(rangeAdxHandle, 0, 0, count, adxValues);
   int copiedAtr = CopyBuffer(rangeAtrHandle, 0, 0, count, atrValues);
   return copiedFast == copiedRates && copiedSlow == copiedRates && copiedAdx == copiedRates && copiedAtr == copiedRates;
  }

bool LoadFractalSignalWindow(MqlRates &rates[], double &fastEma[], double &midEma[], double &slowEma[],
                             double &stochK[], double &stochD[], int count)
  {
   count=MathMax(count,MathMax(InpTrendScanBars+InpPivotSpan+3,
         MathMax(InpSlowSlopeLookback+3,MathMax(InpVolatilityLookbackBars+3,
         MathMax(InpBreakoutLookbackBars+InpBreakoutRetestDelayBars+5,
         MathMax(InpDowTrendScanBars+InpDowPivotSpan+3,
         MathMax(InpRangeLookbackBars+5,InpFractalScanBars+InpFractalPivotSpan+3)))))));
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(fastEma, true);
   ArraySetAsSeries(midEma, true);
   ArraySetAsSeries(slowEma, true);
   ArraySetAsSeries(stochK, true);
   ArraySetAsSeries(stochD, true);
   int copiedRates = CopyRates(runtimeSymbol, InpFractalSignalTimeframe, 0, count, rates);
   if(copiedRates != count)
      return false;
   int copiedFast = CopyBuffer(fractalFastEmaHandle, 0, 0, count, fastEma);
   int copiedMid = CopyBuffer(fractalMidEmaHandle, 0, 0, count, midEma);
   int copiedSlow = CopyBuffer(fractalSlowEmaHandle, 0, 0, count, slowEma);
   int copiedK = CopyBuffer(fractalStochHandle, 0, 0, count, stochK);
   int copiedD = CopyBuffer(fractalStochHandle, 1, 0, count, stochD);
   return copiedFast == copiedRates && copiedMid == copiedRates && copiedSlow == copiedRates &&
          copiedK == copiedRates && copiedD == copiedRates;
  }

// RELATIVE_CONTINUATION_MODULE_END MarketData
#endif

// RELATIVE_CONTINUATION_MODULE_BEGIN PositionManagement
#ifndef RELATIVE_CONTINUATION_POSITIONMANAGEMENT_MQH
#define RELATIVE_CONTINUATION_POSITIONMANAGEMENT_MQH
int CountManagedPositions()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      count++;
     }
   return count;
  }

string BucketComment(SignalBucket bucket)
  {
   if(bucket == SIGNAL_ROUND_SHORT)
      return "round_continuation_short";
   if(bucket == SIGNAL_EMA)
      return "ema_sidecar_long";
   if(bucket == SIGNAL_COMPRESSION)
      return "compression_sidecar_long";
   if(bucket == SIGNAL_RSI)
      return "rsi_sidecar_long";
   if(bucket == SIGNAL_ROUND_LOOSE)
      return "round_loose_long";
   if(bucket == SIGNAL_BREAKOUT)
      return "breakout_sidecar_long";
   if(bucket == SIGNAL_DOW_SWEEP)
      return "dow_sweep_long";
   if(bucket == SIGNAL_RANGE_RECLAIM)
      return "range_reclaim_long";
   if(bucket == SIGNAL_RANGE_RECLAIM_SHORT)
      return "range_reclaim_short";
   if(bucket == SIGNAL_FRACTAL_TREND)
      return "fractal_trend_long";
   if(bucket == SIGNAL_ROUND)
      return "round_continuation_long";
   return "";
  }

ENUM_TIMEFRAMES BucketSignalTimeframe(SignalBucket bucket)
  {
   if(bucket == SIGNAL_DOW_SWEEP)
      return InpDowSignalTimeframe;
   if(bucket == SIGNAL_RANGE_RECLAIM)
      return InpRangeSignalTimeframe;
   if(bucket == SIGNAL_RANGE_RECLAIM_SHORT)
      return InpRangeSignalTimeframe;
   if(bucket == SIGNAL_FRACTAL_TREND)
      return InpFractalSignalTimeframe;
   return InpSignalTimeframe;
  }

bool BucketIsSell(SignalBucket bucket)
  {
   return (bucket == SIGNAL_ROUND_SHORT || bucket == SIGNAL_RANGE_RECLAIM_SHORT);
  }

int CountBucketPositions(SignalBucket bucket)
  {
   string bucketComment = BucketComment(bucket);
   if(bucketComment == "")
      return 0;

   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, bucketComment) >= 0)
         count++;
     }
   return count;
  }

bool ManageOpenPosition()
  {
   bool actionTaken = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      datetime openedAt = (datetime)PositionGetInteger(POSITION_TIME);
      string comment = PositionGetString(POSITION_COMMENT);
      int maxHoldBars = InpMaxHoldBars;
      if(StringFind(comment, "round_continuation_short") >= 0)
         maxHoldBars = InpRoundShortMaxHoldBars;
      else if(StringFind(comment, "ema_sidecar") >= 0)
         maxHoldBars = InpEmaMaxHoldBars;
      else if(StringFind(comment, "compression_sidecar") >= 0)
         maxHoldBars = InpCompressionMaxHoldBars;
      else if(StringFind(comment, "rsi_sidecar") >= 0)
         maxHoldBars = InpRsiMaxHoldBars;
      else if(StringFind(comment, "round_loose") >= 0)
         maxHoldBars = InpRoundLooseMaxHoldBars;
      else if(StringFind(comment, "breakout_sidecar") >= 0)
         maxHoldBars = InpBreakoutMaxHoldBars;
      else if(StringFind(comment, "dow_sweep") >= 0)
         maxHoldBars = InpDowMaxHoldBars;
      else if(StringFind(comment, "range_reclaim") >= 0)
         maxHoldBars = InpRangeMaxHoldBars;
      else if(StringFind(comment, "fractal_trend") >= 0)
         maxHoldBars = InpFractalMaxHoldBars;
      ENUM_TIMEFRAMES holdTimeframe = InpSignalTimeframe;
      if(StringFind(comment, "dow_sweep") >= 0)
         holdTimeframe = InpDowSignalTimeframe;
      else if(StringFind(comment, "range_reclaim") >= 0)
         holdTimeframe = InpRangeSignalTimeframe;
      else if(StringFind(comment, "fractal_trend") >= 0)
         holdTimeframe = InpFractalSignalTimeframe;
      int barsOpen = iBarShift(runtimeSymbol, holdTimeframe, openedAt, false);
      if(barsOpen < maxHoldBars)
         continue;
      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      if(CheckTradeResult(trade.PositionClose(ticket),"time_exit"))
         actionTaken = true;
     }
   return actionTaken;
  }

void FlattenManagedPositions(string reason)
  {
   int openCount = CountManagedPositions();
   if(openCount <= 0)
      return;

   int closedCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      if(CheckTradeResult(trade.PositionClose(ticket),"flatten"))
         closedCount++;
     }

   LogTelemetryEvent(TimeCurrent(), "protective_flatten", reason, "", 0.0, 0.0, 0.0,
                     StringFormat("closed=%d requested=%d", closedCount, openCount));
  }

bool CanOpenAnotherTrade(datetime barTime)
  {
   if(uncertainSend || HasPendingManagedOrder()) return false;
   if(IsDailyLossCapBlocked() || IsEquityDrawdownBlocked()) return false;
   // A netting symbol cannot safely share positions with another strategy.
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING &&
      PositionSelect(runtimeSymbol)) return false;
   if(!InpAllowParallelBuckets && CountManagedPositions() > 0)
      return false;
   if(InpMaxOpenPositions > 0 && CountManagedPositions() >= InpMaxOpenPositions)
      return false;
   if(IsTradeCountBlocked())
     {
      dailyBlockedTradeCap++;
      return false;
     }

   MqlDateTime ts;
   TimeToStruct(barTime, ts);
   if(!IsAllowedWeekday(ts.day_of_week))
      return false;
   if(!IsSpreadAllowed())
     {
      dailyBlockedSpread++;
      return false;
     }
   if(AreOperatorEntriesBlocked())
      return false;

   return true;
  }

bool CanOpenBucketTrade(SignalBucket bucket, int baseOpenCount, int pendingOpenCount)
  {
   if(bucket == SIGNAL_NONE)
      return false;
   if(uncertainSend || HasPendingManagedOrder()) return false;
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING &&
      (baseOpenCount+pendingOpenCount>0 || PositionSelect(runtimeSymbol))) return false;
   if(CountBucketPositions(bucket) > 0)
      return false;
   if(!InpAllowParallelBuckets && baseOpenCount + pendingOpenCount > 0)
      return false;
   if(InpMaxOpenPositions > 0 && baseOpenCount + pendingOpenCount >= InpMaxOpenPositions)
      return false;
   return true;
  }

// RELATIVE_CONTINUATION_MODULE_END PositionManagement
#endif

// RELATIVE_CONTINUATION_MODULE_BEGIN PriceStructure
#ifndef RELATIVE_CONTINUATION_PRICESTRUCTURE_MQH
#define RELATIVE_CONTINUATION_PRICESTRUCTURE_MQH
bool IsPivotHigh(const MqlRates &rates[], int shift, int span)
  {
   int size = ArraySize(rates);
   if(shift - span < 0 || shift + span >= size)
      return false;
   double center = rates[shift].high;
   for(int i = 1; i <= span; ++i)
     {
      if(center <= rates[shift - i].high || center < rates[shift + i].high)
         return false;
     }
   return true;
  }

bool IsPivotLow(const MqlRates &rates[], int shift, int span)
  {
   int size = ArraySize(rates);
   if(shift - span < 0 || shift + span >= size)
      return false;
   double center = rates[shift].low;
   for(int i = 1; i <= span; ++i)
     {
      if(center >= rates[shift - i].low || center > rates[shift + i].low)
         return false;
     }
   return true;
  }

void FindRecentPivotsWithSpan(const MqlRates &rates[], bool wantHigh, int span, int scanBars, PivotPoint &latest, PivotPoint &previous)
  {
   latest.valid = false;
   previous.valid = false;
   int size = ArraySize(rates);
   int maxShift = MathMin(size - 1 - span, scanBars);
   for(int shift = span + 1; shift <= maxShift; ++shift)
     {
      bool match = wantHigh ? IsPivotHigh(rates, shift, span) : IsPivotLow(rates, shift, span);
      if(!match)
         continue;
      PivotPoint point;
      point.valid = true;
      point.shift = shift;
      point.price = wantHigh ? rates[shift].high : rates[shift].low;
      point.time = rates[shift].time;
      if(!latest.valid)
         latest = point;
      else
        {
         previous = point;
         break;
        }
     }
  }

void FindRecentPivots(const MqlRates &rates[], bool wantHigh, PivotPoint &latest, PivotPoint &previous)
  {
   FindRecentPivotsWithSpan(rates, wantHigh, InpPivotSpan, InpTrendScanBars, latest, previous);
  }

double UpperWickShare(const MqlRates &bar)
  {
   double range = bar.high - bar.low;
   if(range <= 0.0)
      return 0.0;
   return (bar.high - MathMax(bar.open, bar.close)) / range;
  }

double LowerWickShare(const MqlRates &bar)
  {
   double range = bar.high - bar.low;
   if(range <= 0.0)
      return 0.0;
   return (MathMin(bar.open, bar.close) - bar.low) / range;
  }

double CloseLocation(const MqlRates &bar)
  {
   double range = bar.high - bar.low;
   if(range <= 0.0)
      return 0.5;
   return (bar.close - bar.low) / range;
  }

double BodyAtr(const MqlRates &bar)
  {
   double unit = GetDistanceUnit();
   if(unit <= 0.0)
      return 0.0;
   return MathAbs(bar.close - bar.open) / unit;
  }

double RangeAtr(const MqlRates &bar)
  {
   double unit = GetDistanceUnit();
   if(unit <= 0.0)
      return 0.0;
   return (bar.high - bar.low) / unit;
  }

double FindBreakoutLevel(const MqlRates &bar, double stepPrice)
  {
   int startIndex = (int)MathFloor(bar.low / stepPrice) - 1;
   int endIndex = (int)MathCeil(bar.high / stepPrice) + 1;
   for(int idx = startIndex; idx <= endIndex; ++idx)
     {
      double level = idx * stepPrice;
      if(bar.open < level && bar.close > level)
         return level;
     }
   return 0.0;
  }

double RecentHighBreakAtr(const MqlRates &rates[], int shift, int lookback)
  {
   double unit = GetDistanceUnit();
   if(unit <= 0.0)
      return 0.0;
   double priorHigh = rates[shift + 1].high;
   for(int i = shift + 1; i <= shift + lookback; ++i)
      priorHigh = MathMax(priorHigh, rates[i].high);
   return (rates[shift].close - priorHigh) / unit;
  }

bool PassesVolatilityState(const MqlRates &rates[])
  {
   int size = ArraySize(rates);
   if(size <= InpVolatilityLookbackBars + 1)
      return false;
   double highest = rates[1].high;
   double lowest = rates[1].low;
   for(int shift = 1; shift <= InpVolatilityLookbackBars; ++shift)
     {
      highest = MathMax(highest, rates[shift].high);
      lowest = MathMin(lowest, rates[shift].low);
     }
   double unit = GetDistanceUnit();
   if(unit <= 0.0 || (highest - lowest) / unit < InpMinWindowRangeAtr)
      return false;

   double zoneStep = InpGridStepAtr * unit;
   if(zoneStep <= 0.0)
      return false;
   return (long)MathFloor(highest / zoneStep) != (long)MathFloor(lowest / zoneStep);
  }

// RELATIVE_CONTINUATION_MODULE_END PriceStructure
#endif

// RELATIVE_CONTINUATION_MODULE_BEGIN Signals
#ifndef RELATIVE_CONTINUATION_SIGNALS_MQH
#define RELATIVE_CONTINUATION_SIGNALS_MQH
bool EvaluateRoundSignal(const MqlRates &rates[], const double &fastEma[], const double &slowEma[])
  {
   if(!InpEnableRoundBucket)
      return RecordRoundDecision("DISABLED");
   if(!IsWithinActiveSession(rates[0].time)) return RecordRoundDecision("SESSION");
   if(!PassesVolatilityState(rates))
      return RecordRoundDecision("VOLATILITY");

   PivotPoint latestHigh, previousHigh, latestLow, previousLow;
   FindRecentPivots(rates, true, latestHigh, previousHigh);
   FindRecentPivots(rates, false, latestLow, previousLow);
   if(!latestHigh.valid || !previousHigh.valid || !latestLow.valid || !previousLow.valid)
      return RecordRoundDecision("PIVOTS_NOT_READY");

   double unit = GetDistanceUnit();
   if(unit <= 0.0)
      return RecordRoundDecision("ATR_UNAVAILABLE");
   if(!(latestHigh.price > previousHigh.price && latestLow.price > previousLow.price))
      return RecordRoundDecision("STRUCTURE_NOT_UP");
   if(fastEma[1] <= slowEma[1])
      return RecordRoundDecision("EMA_ORDER");
   if(rates[1].close <= slowEma[1])
      return RecordRoundDecision("BELOW_SLOW_EMA");

   double slowSlopeAtr = (slowEma[1] - slowEma[1 + InpSlowSlopeLookback]) / unit;
   if(slowSlopeAtr < InpMinSlowSlopeAtr)
      return RecordRoundDecision("SLOPE");
   if(rates[1].low <= latestLow.price)
      return RecordRoundDecision("LOW_BROKEN");

   double emaDistanceAtr = MathAbs(rates[1].close - fastEma[1]) / unit;
   if(emaDistanceAtr > InpMaxEma13DistanceAtr)
      return RecordRoundDecision("EMA_DISTANCE");
   if(UpperWickShare(rates[1]) < InpMinUpperWickShare)
      return RecordRoundDecision("UPPER_WICK");
   if(LowerWickShare(rates[1]) > InpMaxLowerWickShare)
      return RecordRoundDecision("LOWER_WICK");
   return RecordRoundDecision("SIGNAL",true);
  }

bool EvaluateRoundShortSignal(const MqlRates &rates[], const double &fastEma[], const double &slowEma[])
  {
   if(!InpEnableRoundShortBucket)
      return false;
   if(!PassesVolatilityState(rates))
      return false;

   datetime barTime = rates[0].time;
   if(!IsWithinSession(barTime, InpRoundShortSessionStartHour, InpRoundShortSessionEndHour))
      return false;

   PivotPoint latestHigh, previousHigh, latestLow, previousLow;
   FindRecentPivots(rates, true, latestHigh, previousHigh);
   FindRecentPivots(rates, false, latestLow, previousLow);
   if(!latestHigh.valid || !previousHigh.valid || !latestLow.valid || !previousLow.valid)
      return false;

   double unit = GetDistanceUnit();
   if(unit <= 0.0)
      return false;
   if(!(latestHigh.price < previousHigh.price && latestLow.price < previousLow.price))
      return false;
   if(fastEma[1] >= slowEma[1])
      return false;
   if(rates[1].close >= slowEma[1])
      return false;

   double slowSlopeAtr = (slowEma[1] - slowEma[1 + InpSlowSlopeLookback]) / unit;
   if(slowSlopeAtr > -InpRoundShortMinSlowSlopeAtr)
      return false;
   if(rates[1].high >= latestHigh.price)
      return false;

   double emaDistanceAtr = MathAbs(rates[1].close - fastEma[1]) / unit;
   if(emaDistanceAtr > InpRoundShortMaxEma13DistanceAtr)
      return false;
   if(LowerWickShare(rates[1]) < InpRoundShortMinLowerWickShare)
      return false;
   if(UpperWickShare(rates[1]) > InpRoundShortMaxUpperWickShare)
      return false;
   return true;
  }

bool EvaluateRoundLooseSignal(const MqlRates &rates[], const double &fastEma[], const double &slowEma[])
  {
   if(!InpEnableRoundLooseBucket)
      return false;
   if(!IsWithinActiveSession(rates[0].time)) return false;
   if(!PassesVolatilityState(rates))
      return false;

   PivotPoint latestHigh, previousHigh, latestLow, previousLow;
   FindRecentPivots(rates, true, latestHigh, previousHigh);
   FindRecentPivots(rates, false, latestLow, previousLow);
   if(!latestHigh.valid || !previousHigh.valid || !latestLow.valid || !previousLow.valid)
      return false;

   double unit = GetDistanceUnit();
   if(unit <= 0.0)
      return false;
   if(!(latestHigh.price > previousHigh.price && latestLow.price > previousLow.price))
      return false;
   if(fastEma[1] <= slowEma[1])
      return false;
   if(rates[1].close <= slowEma[1])
      return false;

   double slowSlopeAtr = (slowEma[1] - slowEma[1 + InpSlowSlopeLookback]) / unit;
   if(slowSlopeAtr < InpMinSlowSlopeAtr)
      return false;
   if(rates[1].low <= latestLow.price)
      return false;

   double emaDistanceAtr = MathAbs(rates[1].close - fastEma[1]) / unit;
   if(emaDistanceAtr <= InpMaxEma13DistanceAtr)
      return false;
   if(emaDistanceAtr > InpRoundLooseMaxEma13DistanceAtr)
      return false;
   if(UpperWickShare(rates[1]) < InpMinUpperWickShare)
      return false;
   if(LowerWickShare(rates[1]) > InpMaxLowerWickShare)
      return false;
   return true;
  }

bool EvaluateEmaSignal(const MqlRates &rates[], const double &fastEma[], const double &slowEma[], const double &adxValues[])
  {
   if(!InpEnableEmaBucket)
      return false;

   datetime barTime = rates[0].time;
   if(!IsWithinSession(barTime, InpEmaSessionStartHour, InpEmaSessionEndHour))
      return false;

   double unit = GetDistanceUnit();
   if(unit <= 0.0)
      return false;
   if(fastEma[1] <= slowEma[1])
      return false;
   if(rates[1].close <= slowEma[1])
      return false;

   double slowSlopeAtr = (slowEma[1] - slowEma[1 + InpSlowSlopeLookback]) / unit;
   if(slowSlopeAtr < InpMinSlowSlopeAtr)
      return false;

   if(adxValues[1] <= 0.0 || adxValues[1] > InpEmaMaxAdx)
      return false;

   double emaDistanceAtr = MathAbs(rates[1].close - fastEma[1]) / unit;
   if(emaDistanceAtr > InpEmaMaxEma13DistanceAtr)
      return false;

   double ret1 = 0.0;
   if(rates[2].close > 0.0)
      ret1 = (rates[1].close - rates[2].close) / rates[2].close;
   if(ret1 > InpEmaMaxRet1)
      return false;

   if(UpperWickShare(rates[1]) < InpEmaMinUpperWickShare)
      return false;
   if(LowerWickShare(rates[1]) > InpEmaMaxLowerWickShare)
      return false;
   if(CloseLocation(rates[1]) > InpEmaMaxCloseLocation)
      return false;
   return true;
  }

bool EvaluateCompressionSignal(const MqlRates &rates[], const double &fastEma[], const double &slowEma[], const double &adxValues[])
  {
   if(!InpEnableCompressionBucket)
      return false;

   datetime barTime = rates[0].time;
   if(!IsWithinSession(barTime, InpCompressionSessionStartHour, InpCompressionSessionEndHour))
      return false;

   double unit = GetDistanceUnit();
   if(unit <= 0.0)
      return false;
   if(fastEma[1] <= slowEma[1])
      return false;
   if(rates[1].close <= slowEma[1])
      return false;

   double slowSlopeAtr = (slowEma[1] - slowEma[1 + InpSlowSlopeLookback]) / unit;
   if(slowSlopeAtr < InpMinSlowSlopeAtr)
      return false;

   if(adxValues[1] <= 0.0 || adxValues[1] > InpCompressionMaxAdx)
      return false;

   double emaDistanceAtr = MathAbs(rates[1].close - fastEma[1]) / unit;
   if(emaDistanceAtr > InpCompressionMaxEma13DistanceAtr)
      return false;

   if(UpperWickShare(rates[1]) < InpCompressionMinUpperWickShare)
      return false;
   if(LowerWickShare(rates[1]) > InpCompressionMaxLowerWickShare)
      return false;
   return true;
  }

bool EvaluateRsiSignal(const MqlRates &rates[], const double &fastEma[], const double &slowEma[], const double &rsiValues[])
  {
   if(!InpEnableRsiBucket)
      return false;

   datetime barTime = rates[0].time;
   if(!IsWithinSession(barTime, InpRsiSessionStartHour, InpRsiSessionEndHour))
      return false;

   double unit = GetDistanceUnit();
   if(unit <= 0.0)
      return false;
   if(fastEma[1] <= slowEma[1])
      return false;
   if(rates[1].close <= slowEma[1])
      return false;

   double slowSlopeAtr = (slowEma[1] - slowEma[1 + InpSlowSlopeLookback]) / unit;
   if(slowSlopeAtr < InpMinSlowSlopeAtr)
      return false;

   if(rsiValues[1] <= 0.0 || rsiValues[1] > InpRsiOversold)
      return false;

   double emaDistanceAtr = MathAbs(rates[1].close - fastEma[1]) / unit;
   if(emaDistanceAtr > InpRsiMaxEma13DistanceAtr)
      return false;

   if(rates[1].low > fastEma[1] + (InpRsiTouchBufferAtr * unit))
      return false;
   if(rates[1].close <= rates[1].open)
      return false;
   if(rates[1].close <= rates[2].close)
      return false;
   if(CloseLocation(rates[1]) < InpRsiMinCloseLocation)
      return false;
   if(BodyAtr(rates[1]) < InpRsiMinBodyAtr)
      return false;
   if(LowerWickShare(rates[1]) > InpRsiMaxLowerWickShare)
      return false;

   return true;
  }

bool EvaluateBreakoutSignal(const MqlRates &rates[], const double &fastEma[], const double &slowEma[])
  {
   if(!InpEnableBreakoutBucket)
      return false;

   const int signalShift = 1;
   int breakoutShift = signalShift + InpBreakoutRetestDelayBars;
   if(breakoutShift + MathMax(InpSlowSlopeLookback, InpBreakoutLookbackBars) >= ArraySize(rates))
      return false;

   datetime barTime = rates[signalShift].time;
   if(!IsWithinSession(barTime, InpBreakoutSessionStartHour, InpBreakoutSessionEndHour))
      return false;

   double unit = GetDistanceUnit();
   if(unit <= 0.0)
      return false;

   MqlRates breakout = rates[breakoutShift];
   MqlRates signalBar = rates[signalShift];
   double stepPrice = InpGridStepAtr * unit;
   double level = FindBreakoutLevel(breakout, stepPrice);
   if(level <= 0.0)
      return false;

   if(!(fastEma[breakoutShift] > slowEma[breakoutShift]))
      return false;
   if(!(breakout.close > slowEma[breakoutShift]))
      return false;
   if(!(slowEma[breakoutShift] > slowEma[breakoutShift + InpSlowSlopeLookback]))
      return false;
   if(RecentHighBreakAtr(rates, breakoutShift, InpBreakoutLookbackBars) <= 0.0)
      return false;
   if(((breakout.close - fastEma[breakoutShift]) / unit) > InpBreakoutMaxToEma13Atr)
      return false;

   double breakoutBodyAtr = BodyAtr(breakout);
   double breakoutRangeAtr = RangeAtr(breakout);
   if(breakoutBodyAtr < InpBreakoutMinBodyAtr || breakoutRangeAtr <= 0.0)
      return false;
   if((breakoutBodyAtr / breakoutRangeAtr) < InpBreakoutMinBodyToRange)
      return false;
   if(CloseLocation(breakout) < InpBreakoutMinCloseLocation)
      return false;

   double midpoint = level + (InpBreakoutMidpointDistanceAtr * unit);
   for(int shift = signalShift + 1; shift < breakoutShift; ++shift)
     {
      MqlRates followBar = rates[shift];
      if(followBar.high >= midpoint)
         return false;
      if(followBar.close < level)
         return false;
     }
   if(signalBar.high >= midpoint)
      return false;
   if(signalBar.close < level)
      return false;

   bool touchedEma = signalBar.low <= fastEma[signalShift] + (InpBreakoutTouchToleranceAtr * unit);
   bool touchedLevel = signalBar.low <= level + (InpBreakoutRetestBufferAtr * unit);
   if(!(touchedEma || touchedLevel))
      return false;
   double retestDepthAtr = MathMax(0.0, (level - signalBar.low) / unit);
   if(retestDepthAtr > InpBreakoutMaxRetestDepthAtr)
      return false;
   if(CloseLocation(signalBar) < InpBreakoutMinRetestCloseLocation)
      return false;
   if(signalBar.close <= fastEma[signalShift])
      return false;
   if(signalBar.close <= level)
      return false;

   return true;
  }

bool EvaluateDowSweepSignal(const MqlRates &envRates[], const double &envFastEma[], const double &envSlowEma[],
                            const MqlRates &signalRates[], const double &signalFastEma[], const double &signalSlowEma[])
  {
   dowPlannedStopPrice = 0.0;
   dowPlannedTargetPrice = 0.0;
   if(!InpEnableDowSweepBucket)
      return false;

   datetime signalBarTime = signalRates[0].time;
   if(!IsWithinSession(signalBarTime, InpDowSessionStartHour, InpDowSessionEndHour))
      return false;

   if(!PassesVolatilityState(envRates))
      return false;

   PivotPoint envLatestHigh, envPreviousHigh, envLatestLow, envPreviousLow;
   FindRecentPivots(envRates, true, envLatestHigh, envPreviousHigh);
   FindRecentPivots(envRates, false, envLatestLow, envPreviousLow);
   if(!envLatestHigh.valid || !envPreviousHigh.valid || !envLatestLow.valid || !envPreviousLow.valid)
      return false;
   if(!(envLatestHigh.price > envPreviousHigh.price && envLatestLow.price > envPreviousLow.price))
      return false;
   if(envFastEma[1] <= envSlowEma[1])
      return false;
   if(envRates[1].close <= envSlowEma[1])
      return false;

   double unit = GetDistanceUnit();
   if(unit <= 0.0)
      return false;

   PivotPoint signalLatestHigh, signalPreviousHigh, signalLatestLow, signalPreviousLow;
   FindRecentPivotsWithSpan(signalRates, true, InpDowPivotSpan, InpDowTrendScanBars, signalLatestHigh, signalPreviousHigh);
   FindRecentPivotsWithSpan(signalRates, false, InpDowPivotSpan, InpDowTrendScanBars, signalLatestLow, signalPreviousLow);
   if(!signalLatestHigh.valid || !signalLatestLow.valid)
      return false;
   if(!(signalLatestHigh.time < signalLatestLow.time))
      return false;

   double support = signalLatestLow.price;
   double priorHigh = signalLatestHigh.price;
   MqlRates signalBar = signalRates[1];
   double breachAtr = (support - signalBar.low) / unit;
   if(breachAtr < InpDowMinBreachAtr || breachAtr > InpDowMaxBreachAtr)
      return false;
   if(signalBar.close <= support)
      return false;
   if(signalBar.close <= signalBar.open)
      return false;
   if(CloseLocation(signalBar) < InpDowMinCloseLocation)
      return false;
   if(LowerWickShare(signalBar) < InpDowMinLowerWickShare)
      return false;
   if(UpperWickShare(signalBar) > InpDowMaxUpperWickShare)
      return false;
   if(signalFastEma[1] <= signalSlowEma[1])
      return false;
   if(signalBar.close <= signalSlowEma[1])
      return false;

   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   double plannedStop = signalBar.low - (InpDowStopBufferAtr * unit);
   double plannedTarget = priorHigh - (InpDowTargetBufferAtr * unit);
   double stopDistance = ask - plannedStop;
   double targetDistance = plannedTarget - ask;
   if(stopDistance <= 0.0 || targetDistance <= 0.0)
      return false;
   if((targetDistance / stopDistance) < InpDowMinTargetRMultiple)
      return false;

   dowPlannedStopPrice = NormalizePrice(plannedStop);
   dowPlannedTargetPrice = NormalizePrice(plannedTarget);
   return true;
  }

bool EvaluateRangeReclaimSignal(const MqlRates &envRates[], const double &envFastEma[], const double &envSlowEma[],
                                const MqlRates &signalRates[], const double &signalFastEma[], const double &signalSlowEma[],
                                const double &signalAdx[], const double &signalAtr[])
  {
   rangePlannedStopPrice = 0.0;
   rangePlannedTargetPrice = 0.0;
   if(!InpEnableRangeReclaimBucket)
      return false;

   datetime signalBarTime = signalRates[0].time;
   if(!IsWithinSession(signalBarTime, InpRangeSessionStartHour, InpRangeSessionEndHour))
      return false;
   if(!PassesVolatilityState(envRates))
      return false;

   PivotPoint envLatestHigh, envPreviousHigh, envLatestLow, envPreviousLow;
   FindRecentPivots(envRates, true, envLatestHigh, envPreviousHigh);
   FindRecentPivots(envRates, false, envLatestLow, envPreviousLow);
   if(!envLatestHigh.valid || !envPreviousHigh.valid || !envLatestLow.valid || !envPreviousLow.valid)
      return false;
   if(!(envLatestHigh.price > envPreviousHigh.price && envLatestLow.price > envPreviousLow.price))
      return false;
   if(envFastEma[1] <= envSlowEma[1])
      return false;
   if(envRates[1].close <= envSlowEma[1])
      return false;

   double unit = GetDistanceUnit();
   if(unit <= 0.0)
      return false;
   if(signalAdx[1] > InpRangeMaxAdx)
      return false;
   if(signalAtr[1] <= 0.0)
      return false;

   int size = ArraySize(signalRates);
   if(size <= InpRangeLookbackBars + 2)
      return false;

   double rangeHigh = -DBL_MAX;
   double rangeLow = DBL_MAX;
   for(int shift = 2; shift < 2 + InpRangeLookbackBars && shift < size; ++shift)
     {
      if(signalRates[shift].high > rangeHigh)
         rangeHigh = signalRates[shift].high;
      if(signalRates[shift].low < rangeLow)
         rangeLow = signalRates[shift].low;
     }
   if(rangeHigh <= rangeLow)
      return false;

   double rangeWidth = rangeHigh - rangeLow;
   if(rangeWidth > signalAtr[1] * InpRangeMaxWidthAtrMultiple)
      return false;

   MqlRates signalBar = signalRates[1];
   double breachAtr = (rangeLow - signalBar.low) / unit;
   if(breachAtr < InpRangeMinBreachAtr || breachAtr > InpRangeMaxBreachAtr)
      return false;
   if(signalBar.close <= rangeLow)
      return false;
   if(signalBar.close <= signalBar.open)
      return false;
   if(CloseLocation(signalBar) < InpRangeMinCloseLocation)
      return false;
   if(LowerWickShare(signalBar) < InpRangeMinLowerWickShare)
      return false;
   if(UpperWickShare(signalBar) > InpRangeMaxUpperWickShare)
      return false;
   if(signalFastEma[1] <= signalSlowEma[1])
      return false;
   if(signalBar.close <= signalSlowEma[1])
      return false;

   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   double plannedStop = signalBar.low - (InpRangeStopBufferAtr * unit);
   double plannedTarget = rangeHigh - (InpRangeTargetBufferAtr * unit);
   double stopDistance = ask - plannedStop;
   double targetDistance = plannedTarget - ask;
   if(stopDistance <= 0.0 || targetDistance <= 0.0)
      return false;
   if((targetDistance / stopDistance) < InpRangeMinTargetRMultiple)
      return false;

   rangePlannedStopPrice = NormalizePrice(plannedStop);
   rangePlannedTargetPrice = NormalizePrice(plannedTarget);
   return true;
  }

bool EvaluateRangeReclaimShortSignal(const MqlRates &envRates[], const double &envFastEma[], const double &envSlowEma[],
                                     const MqlRates &signalRates[], const double &signalFastEma[], const double &signalSlowEma[],
                                     const double &signalAdx[], const double &signalAtr[])
  {
   rangeShortPlannedStopPrice = 0.0;
   rangeShortPlannedTargetPrice = 0.0;
   if(!InpEnableRangeShortBucket)
      return false;

   datetime signalBarTime = signalRates[0].time;
   if(!IsWithinSession(signalBarTime, InpRangeSessionStartHour, InpRangeSessionEndHour))
      return false;
   if(!PassesVolatilityState(envRates))
      return false;

   PivotPoint envLatestHigh, envPreviousHigh, envLatestLow, envPreviousLow;
   FindRecentPivots(envRates, true, envLatestHigh, envPreviousHigh);
   FindRecentPivots(envRates, false, envLatestLow, envPreviousLow);
   if(!envLatestHigh.valid || !envPreviousHigh.valid || !envLatestLow.valid || !envPreviousLow.valid)
      return false;
   if(!(envLatestHigh.price < envPreviousHigh.price && envLatestLow.price < envPreviousLow.price))
      return false;
   if(envFastEma[1] >= envSlowEma[1])
      return false;
   if(envRates[1].close >= envSlowEma[1])
      return false;

   double unit = GetDistanceUnit();
   if(unit <= 0.0)
      return false;
   if(signalAdx[1] > InpRangeMaxAdx)
      return false;
   if(signalAtr[1] <= 0.0)
      return false;

   int size = ArraySize(signalRates);
   if(size <= InpRangeLookbackBars + 2)
      return false;

   double rangeHigh = -DBL_MAX;
   double rangeLow = DBL_MAX;
   for(int shift = 2; shift < 2 + InpRangeLookbackBars && shift < size; ++shift)
     {
      if(signalRates[shift].high > rangeHigh)
         rangeHigh = signalRates[shift].high;
      if(signalRates[shift].low < rangeLow)
         rangeLow = signalRates[shift].low;
     }
   if(rangeHigh <= rangeLow)
      return false;

   double rangeWidth = rangeHigh - rangeLow;
   if(rangeWidth > signalAtr[1] * InpRangeMaxWidthAtrMultiple)
      return false;

   MqlRates signalBar = signalRates[1];
   double breachAtr = (signalBar.high - rangeHigh) / unit;
   if(breachAtr < InpRangeMinBreachAtr || breachAtr > InpRangeMaxBreachAtr)
      return false;
   if(signalBar.close >= rangeHigh)
      return false;
   if(signalBar.close >= signalBar.open)
      return false;
   if(CloseLocation(signalBar) > (1.0 - InpRangeMinCloseLocation))
      return false;
   if(UpperWickShare(signalBar) < InpRangeMinLowerWickShare)
      return false;
   if(LowerWickShare(signalBar) > InpRangeMaxUpperWickShare)
      return false;
   if(signalFastEma[1] >= signalSlowEma[1])
      return false;
   if(signalBar.close >= signalSlowEma[1])
      return false;

   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;

   double plannedStop = signalBar.high + (InpRangeStopBufferAtr * unit);
   double plannedTarget = rangeLow + (InpRangeTargetBufferAtr * unit);
   double stopDistance = plannedStop - bid;
   double targetDistance = bid - plannedTarget;
   if(stopDistance <= 0.0 || targetDistance <= 0.0)
      return false;
   if((targetDistance / stopDistance) < InpRangeMinTargetRMultiple)
      return false;

   rangeShortPlannedStopPrice = NormalizePrice(plannedStop);
   rangeShortPlannedTargetPrice = NormalizePrice(plannedTarget);
   return true;
  }

bool EvaluateFractalTrendSignal(const MqlRates &envRates[], const double &envFastEma[], const double &envSlowEma[],
                                const MqlRates &signalRates[], const double &signalFastEma[], const double &signalMidEma[],
                                const double &signalSlowEma[], const double &stochK[], const double &stochD[])
  {
   fractalPlannedStopPrice = 0.0;
   fractalPlannedTargetPrice = 0.0;
   if(!InpEnableFractalTrendBucket)
      return false;

   datetime signalBarTime = signalRates[0].time;
   if(!IsWithinSession(signalBarTime, InpFractalSessionStartHour, InpFractalSessionEndHour))
      return false;
   if(!PassesVolatilityState(envRates))
      return false;

   PivotPoint envLatestHigh, envPreviousHigh, envLatestLow, envPreviousLow;
   FindRecentPivots(envRates, true, envLatestHigh, envPreviousHigh);
   FindRecentPivots(envRates, false, envLatestLow, envPreviousLow);
   if(!envLatestHigh.valid || !envPreviousHigh.valid || !envLatestLow.valid || !envPreviousLow.valid)
      return false;
   if(!(envLatestHigh.price > envPreviousHigh.price && envLatestLow.price > envPreviousLow.price))
      return false;
   if(envFastEma[1] <= envSlowEma[1])
      return false;
   if(envRates[1].close <= envSlowEma[1])
      return false;

   PivotPoint signalLatestHigh, signalPreviousHigh, signalLatestLow, signalPreviousLow;
   FindRecentPivotsWithSpan(signalRates, true, InpFractalPivotSpan, InpFractalScanBars, signalLatestHigh, signalPreviousHigh);
   FindRecentPivotsWithSpan(signalRates, false, InpFractalPivotSpan, InpFractalScanBars, signalLatestLow, signalPreviousLow);
   if(!signalLatestHigh.valid || !signalLatestLow.valid)
      return false;
   if(!(signalLatestHigh.time < signalLatestLow.time))
      return false;

   double unit = GetDistanceUnit();
   if(unit <= 0.0)
      return false;

   MqlRates signalBar = signalRates[1];
   if(signalFastEma[1] <= signalMidEma[1] || signalMidEma[1] <= signalSlowEma[1])
      return false;
   if(signalBar.close <= signalSlowEma[1])
      return false;
   if(signalBar.close <= signalBar.open)
      return false;
   if(signalBar.close <= signalRates[2].close)
      return false;

   bool betweenFastAndMid = (signalBar.close < signalFastEma[1] && signalBar.close > signalMidEma[1]);
   bool betweenMidAndSlow = (signalBar.close <= signalMidEma[1] && signalBar.close > signalSlowEma[1]);
   if(!(betweenFastAndMid || betweenMidAndSlow))
      return false;

   bool stochBuySignal = (stochK[2] < InpFractalStochBuyLevel &&
                          stochK[1] > stochK[2] &&
                          stochK[1] > InpFractalStochBuyLevel &&
                          stochK[1] >= stochD[1]);
   if(!stochBuySignal)
      return false;

   double priorHigh = signalLatestHigh.price;
   double stopAnchor = betweenFastAndMid ? signalMidEma[1] : signalSlowEma[1];
   stopAnchor = MathMin(stopAnchor, signalLatestLow.price);
   double plannedStop = stopAnchor - (InpFractalStopBufferAtr * unit);

   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;
   double plannedTarget = priorHigh - (InpFractalTargetBufferAtr * unit);
   double stopDistance = ask - plannedStop;
   double targetDistance = plannedTarget - ask;
   if(stopDistance <= 0.0 || targetDistance <= 0.0)
      return false;
   if((targetDistance / stopDistance) < InpFractalMinTargetRMultiple)
      return false;

   fractalPlannedStopPrice = NormalizePrice(plannedStop);
   fractalPlannedTargetPrice = NormalizePrice(plannedTarget);
   return true;
  }

// RELATIVE_CONTINUATION_MODULE_END Signals
#endif

// RELATIVE_CONTINUATION_MODULE_BEGIN Orders
#ifndef RELATIVE_CONTINUATION_ORDERS_MQH
#define RELATIVE_CONTINUATION_ORDERS_MQH
bool OpenPosition(SignalBucket bucket)
  {
   if(uncertainSend || HasPendingManagedOrder() || !IsSpreadAllowed()) return false;
   double stopLossAtr = InpStopLossAtr;
   double targetRMultiple = InpTargetRMultiple;
   string comment = BucketComment(bucket);
   bool isSell = BucketIsSell(bucket);
   if(bucket == SIGNAL_ROUND_SHORT)
     {
      stopLossAtr = InpRoundShortStopLossAtr;
      targetRMultiple = InpRoundShortTargetRMultiple;
     }
   if(bucket == SIGNAL_EMA)
     {
      stopLossAtr = InpEmaStopLossAtr;
      targetRMultiple = InpEmaTargetRMultiple;
     }
   else if(bucket == SIGNAL_COMPRESSION)
     {
      stopLossAtr = InpCompressionStopLossAtr;
      targetRMultiple = InpCompressionTargetRMultiple;
     }
   else if(bucket == SIGNAL_RSI)
     {
      stopLossAtr = InpRsiStopLossAtr;
      targetRMultiple = InpRsiTargetRMultiple;
     }
   else if(bucket == SIGNAL_ROUND_LOOSE)
     {
      stopLossAtr = InpRoundLooseStopLossAtr;
      targetRMultiple = InpRoundLooseTargetRMultiple;
     }
   else if(bucket == SIGNAL_BREAKOUT)
     {
      stopLossAtr = InpBreakoutStopLossAtr;
      targetRMultiple = InpBreakoutTargetRMultiple;
     }
   else if(bucket == SIGNAL_RANGE_RECLAIM)
     {
      stopLossAtr = 0.0;
      targetRMultiple = 0.0;
     }
   else if(bucket == SIGNAL_FRACTAL_TREND)
     {
      stopLossAtr = 0.0;
      targetRMultiple = 0.0;
     }

   MqlTick quote;
   if(!SymbolInfoTick(runtimeSymbol,quote) || quote.bid<=0.0 || quote.ask<quote.bid) return false;
   double ask = quote.ask;
   double bid = quote.bid;
   double unit = GetDistanceUnit();
   double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   int stopsLevel = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   double entryPrice = isSell ? bid : ask;
   if(entryPrice <= 0.0 || unit <= 0.0 || point <= 0.0)
      return false;
   double stopDistance = stopLossAtr * unit;
   double targetDistance = stopDistance * targetRMultiple;
   double sl = NormalizePrice(isSell ? entryPrice + stopDistance : entryPrice - stopDistance);
   double tp = NormalizePrice(isSell ? entryPrice - targetDistance : entryPrice + targetDistance);
   if(bucket == SIGNAL_DOW_SWEEP)
     {
      if(dowPlannedStopPrice <= 0.0 || dowPlannedTargetPrice <= 0.0)
         return false;
      sl = dowPlannedStopPrice;
      tp = dowPlannedTargetPrice;
      stopDistance = entryPrice - sl;
      targetDistance = tp - entryPrice;
     }
   else if(bucket == SIGNAL_RANGE_RECLAIM)
     {
      if(rangePlannedStopPrice <= 0.0 || rangePlannedTargetPrice <= 0.0)
         return false;
      sl = rangePlannedStopPrice;
      tp = rangePlannedTargetPrice;
      stopDistance = entryPrice - sl;
      targetDistance = tp - entryPrice;
     }
   else if(bucket == SIGNAL_RANGE_RECLAIM_SHORT)
     {
      if(rangeShortPlannedStopPrice <= 0.0 || rangeShortPlannedTargetPrice <= 0.0)
         return false;
      sl = rangeShortPlannedStopPrice;
      tp = rangeShortPlannedTargetPrice;
      stopDistance = sl - entryPrice;
      targetDistance = entryPrice - tp;
     }
   else if(bucket == SIGNAL_FRACTAL_TREND)
     {
      if(fractalPlannedStopPrice <= 0.0 || fractalPlannedTargetPrice <= 0.0)
         return false;
      sl = fractalPlannedStopPrice;
      tp = fractalPlannedTargetPrice;
      stopDistance = entryPrice - sl;
      targetDistance = tp - entryPrice;
     }
   // Recompute after tick-size normalization for BOTH directions.
   sl=NormalizePrice(sl);
   tp=NormalizePrice(tp);
   stopDistance=isSell ? sl-entryPrice : entryPrice-sl;
   targetDistance=isSell ? entryPrice-tp : tp-entryPrice;
   double closePrice=isSell ? ask : bid;
   double brokerStopDistance=isSell ? sl-closePrice : closePrice-sl;
   double brokerTargetDistance=isSell ? closePrice-tp : tp-closePrice;
   if(stopDistance<=0.0 || targetDistance<=0.0 || brokerStopDistance<=0.0 || brokerTargetDistance<=0.0 ||
      brokerStopDistance+point*1e-6<stopsLevel*point || brokerTargetDistance+point*1e-6<stopsLevel*point)
     {
      Print("ORDER_SKIPPED INVALID_OR_TOO_CLOSE_STOPS");
      return false;
     }
   double volume = CalculateVolume(isSell ? ORDER_TYPE_SELL : ORDER_TYPE_BUY,entryPrice,sl);
   if(volume <= 0.0)
      return false;
   trade.SetDeviationInPoints((ulong)MathCeil(InpDeviationAtr*unit/point));
   if(!trade.SetTypeFillingBySymbol(runtimeSymbol)) return false;
   trade.SetAsyncMode(false);
   // Persist before sending: an interrupted process must not blindly resend.
   uncertainSend=true;
   uncertainSince=TimeCurrent();
   uncertainOrder=0;
   SaveRiskState();
   if(PersistRiskState()) GlobalVariablesFlush();
   bool sent=isSell ? trade.Sell(volume,runtimeSymbol,entryPrice,sl,tp,comment) :
                      trade.Buy(volume,runtimeSymbol,entryPrice,sl,tp,comment);
   bool filled=CheckTradeResult(sent,"open");
   uint code=trade.ResultRetcode();
   uncertainOrder=trade.ResultOrder();
   // PLACED / timeout / connection errors require order/deal reconciliation.
   if(filled || (code!=TRADE_RETCODE_PLACED && code!=TRADE_RETCODE_TIMEOUT &&
                 code!=TRADE_RETCODE_CONNECTION && code!=0)) uncertainSend=false;
   SaveRiskState();
   return filled;
  }

// RELATIVE_CONTINUATION_MODULE_END Orders
#endif

// RELATIVE_CONTINUATION_MODULE_BEGIN TelemetryControl
#ifndef RELATIVE_CONTINUATION_TELEMETRYCONTROL_MQH
#define RELATIVE_CONTINUATION_TELEMETRYCONTROL_MQH
bool OpenTelemetryFile()
  {
   if(!InpEnableTelemetry)
      return false;
   if(telemetryHandle != INVALID_HANDLE)
      return true;

   telemetryHandle = FileOpen(runtimeTelemetryFileName, FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_COMMON | FILE_ANSI, ';');
   if(telemetryHandle == INVALID_HANDLE)
     {
      PrintFormat("Telemetry open failed for '%s' (%d)", runtimeTelemetryFileName, GetLastError());
      return false;
     }

   if(FileSize(telemetryHandle) == 0)
     {
      FileWrite(telemetryHandle,
                "timestamp", "event", "reason", "side", "price", "volume", "net_profit", "balance", "equity",
                "daily_closed_trades", "daily_entries_buy", "daily_entries_sell", "consecutive_losses",
                "blocked_spread", "blocked_daily_loss", "blocked_trade_cap", "blocked_loss_lock", "blocked_equity_cap",
                "loss_lock_activations", "note");
     }

   FileSeek(telemetryHandle, 0, SEEK_END);
   return true;
  }

void CloseTelemetryFile()
  {
   if(telemetryHandle != INVALID_HANDLE)
     {
      FileClose(telemetryHandle);
      telemetryHandle = INVALID_HANDLE;
     }
  }

void LogTelemetryEvent(datetime stamp, string eventType, string reason, string side, double price, double volume, double netProfit, string note)
  {
   if(!InpEnableTelemetry)
      return;
   if(!OpenTelemetryFile())
      return;

   FileSeek(telemetryHandle, 0, SEEK_END);
   FileWrite(telemetryHandle,
             TimeToString(stamp, TIME_DATE | TIME_SECONDS),
             eventType,
             reason,
             side,
             price,
             volume,
             netProfit,
             AccountInfoDouble(ACCOUNT_BALANCE),
             AccountInfoDouble(ACCOUNT_EQUITY),
             dailyClosedTrades,
             dailyEntriesBuy,
             dailyEntriesSell,
             consecutiveLosses,
             dailyBlockedSpread,
             dailyBlockedDailyLoss,
             dailyBlockedTradeCap,
             0,
             dailyBlockedEquityCap,
             dailyLossLockActivations,
             note);
   FileFlush(telemetryHandle);
  }

void FlushDailySummary(datetime stamp, string trigger)
  {
   if(currentDayStart <= 0)
      return;
   LogTelemetryEvent(stamp, "daily_summary", trigger, "", 0.0, 0.0, AccountInfoDouble(ACCOUNT_BALANCE) - dailyStartBalance, "");
  }

void RegisterEntryDeal(datetime dealTime, string side, double price, double volume)
  {
   DCEntry(dealTime,price);
   UpdateDailyAnchor();
   RefreshDailyTradeCount();
   if(side == "buy")
      dailyEntriesBuy++;
   else if(side == "sell")
      dailyEntriesSell++;
   LogTelemetryEvent(dealTime, "entry", "", side, price, volume, 0.0, "");
  }

void RegisterClosedDeal(datetime dealTime, double netProfit, string side, double price, double volume)
  {
   UpdateDailyAnchor();
   MqlDateTime nowStruct, dealStruct;
   TimeToStruct(TimeCurrent(), nowStruct);
   TimeToStruct(dealTime, dealStruct);
   if(nowStruct.day_of_year != dealStruct.day_of_year)
      return;

   dailyClosedTrades++;
   if(netProfit >= 0.0)
     {
      consecutiveLosses = 0;
      LogTelemetryEvent(dealTime, "exit", "win", side, price, volume, netProfit, "");
      return;
     }

   consecutiveLosses++;
   LogTelemetryEvent(dealTime, "exit", "loss", side, price, volume, netProfit, "");
  }

string ReadOperatorModeFromFile()
  {
   if(!runtimeOperatorControlEnabled || runtimeOperatorCommandFile == "")
      return "normal";

   int handle = FileOpen(runtimeOperatorCommandFile, FILE_TXT | FILE_READ | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_COMMON | FILE_ANSI);
   if(handle == INVALID_HANDLE)
      return "normal";

   string command = "";
   if(!FileIsEnding(handle))
      command = FileReadString(handle);
   FileClose(handle);

   if(command == "")
      return "normal";
   if(StringCompare(command, "pause", false) == 0 || StringCompare(command, "pause_entries", false) == 0)
      return "pause";
   if(StringCompare(command, "flatten", false) == 0 ||
      StringCompare(command, "flatten_and_pause", false) == 0 ||
      StringCompare(command, "kill", false) == 0)
      return "flatten";
   return "normal";
  }

void RefreshOperatorMode()
  {
   string nextMode = ReadOperatorModeFromFile();
   if(nextMode == operatorMode)
      return;

   operatorMode = nextMode;
   PrintFormat("Operator mode changed to '%s'", operatorMode);
   LogTelemetryEvent(TimeCurrent(), "operator_mode", operatorMode, "", 0.0, 0.0, 0.0, runtimeOperatorCommandFile);
  }

bool AreOperatorEntriesBlocked()
  {
   return (operatorMode != "normal");
  }

string BoolText(bool value)
  {
   if(value)
      return "true";
   return "false";
  }

string DetermineEntryState()
  {
   if(operatorMode == "flatten")
      return "operator_flatten";
   if(operatorMode == "pause")
      return "operator_pause";
   if(IsDailyLossCapBlocked())
      return "daily_loss_cap";
   if(IsEquityDrawdownBlocked())
      return "equity_drawdown_cap";
   if(IsTradeCountBlocked())
      return "trade_cap";
   if(!InpAllowParallelBuckets && CountManagedPositions() > 0)
      return "position_open";
   if(InpMaxOpenPositions > 0 && CountManagedPositions() >= InpMaxOpenPositions)
      return "position_cap";

   datetime currentBar = iTime(runtimeSymbol, InpSignalTimeframe, 0);
   MqlDateTime ts;
   TimeToStruct(currentBar, ts);
   if(!IsAllowedWeekday(ts.day_of_week))
      return "weekday_blocked";
   if(!IsWithinActiveSession(currentBar))
      return "inactive_session";
   if(!IsSpreadAllowed())
      return "spread";
   return "ready";
  }

void WriteStatusSnapshot()
  {
   if(!runtimeStatusSnapshotEnabled || runtimeStatusFileName == "")
      return;

   int handle = FileOpen(runtimeStatusFileName, FILE_TXT | FILE_WRITE | FILE_COMMON | FILE_ANSI);
   if(handle == INVALID_HANDLE)
     {
      if(!statusSnapshotErrorLogged)
        {
         PrintFormat("Status snapshot open failed for '%s' (%d)", runtimeStatusFileName, GetLastError());
         statusSnapshotErrorLogged = true;
        }
      return;
     }

   statusSnapshotErrorLogged = false;
   string snapshot =
      "timestamp=" + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + "\r\n" +
      "symbol=" + runtimeSymbol + "\r\n" +
      "timeframe=" + EnumToString(InpSignalTimeframe) + "\r\n" +
      "operator_mode=" + operatorMode + "\r\n" +
      "entry_state=" + DetermineEntryState() + "\r\n" +
      "balance=" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\r\n" +
      "equity=" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "\r\n" +
      "equity_peak=" + DoubleToString(equityPeak, 2) + "\r\n" +
      "open_positions=" + IntegerToString(CountManagedPositions()) + "\r\n" +
      "daily_trades_opened=" + IntegerToString(dailyTradeCount) + "\r\n" +
      "daily_closed_trades=" + IntegerToString(dailyClosedTrades) + "\r\n" +
      "daily_entries_buy=" + IntegerToString(dailyEntriesBuy) + "\r\n" +
      "daily_entries_sell=" + IntegerToString(dailyEntriesSell) + "\r\n" +
      "consecutive_losses=" + IntegerToString(consecutiveLosses) + "\r\n" +
      "spread_atr=" + DoubleToString(GetCurrentSpreadAtr(), 2) + "\r\n" +
      "daily_loss_cap_blocked=" + BoolText(IsDailyLossCapBlocked()) + "\r\n" +
      "equity_drawdown_blocked=" + BoolText(IsEquityDrawdownBlocked()) + "\r\n" +
      "trade_cap_blocked=" + BoolText(IsTradeCountBlocked()) + "\r\n" +
      "telemetry_file=" + runtimeTelemetryFileName + "\r\n";

   FileWriteString(handle, snapshot);
   FileClose(handle);
  }

// RELATIVE_CONTINUATION_MODULE_END TelemetryControl
#endif

int BaseOnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION)) return INIT_FAILED; // Parallel logs require a pass-specific optimization adapter.
   runtimeSymbol = NormalizePresetString(InpSymbol);
   if(runtimeSymbol=="") runtimeSymbol=_Symbol;
   if(runtimeSymbol!=_Symbol) { Print("Attach to requested symbol chart: OnTick belongs to chart symbol"); return INIT_PARAMETERS_INCORRECT; }
   uint serverHash=2166136261;
   string server=AccountInfoString(ACCOUNT_SERVER);
   for(int i=0;i<StringLen(server);i++) serverHash=(serverHash^(uint)StringGetCharacter(server,i))*16777619;
   riskStatePrefix=StringFormat("RC2.%u.%I64d.%I64d.%s.",serverHash,AccountInfoInteger(ACCOUNT_LOGIN),InpMagicNumber,runtimeSymbol);
   if(StringLen(riskStatePrefix)>52) return INIT_PARAMETERS_INCORRECT;
   runtimeAllowedWeekdays = NormalizePresetString(InpAllowedWeekdays);
   runtimeTelemetryFileName = NormalizePresetString(InpTelemetryFileName);
   runtimeOperatorCommandFile = NormalizePresetString(InpOperatorCommandFile);
   runtimeStatusFileName = NormalizePresetString(InpStatusFileName);
   bool isTesterRuntime = ((bool)MQLInfoInteger(MQL_TESTER) || (bool)MQLInfoInteger(MQL_OPTIMIZATION));
   if(!isTesterRuntime)
     {
      string suffix=StringFormat("_%s_%I64d",runtimeSymbol,InpMagicNumber);
      if(runtimeTelemetryFileName=="relative_continuation.csv") runtimeTelemetryFileName="relative_continuation"+suffix+".csv";
      if(runtimeOperatorCommandFile=="relative_continuation_operator.txt") runtimeOperatorCommandFile="relative_continuation_operator"+suffix+".txt";
      if(runtimeStatusFileName=="relative_continuation_status.txt") runtimeStatusFileName="relative_continuation_status"+suffix+".txt";
     }
   runtimeOperatorControlEnabled = (InpEnableOperatorControl && !isTesterRuntime);
   runtimeStatusSnapshotEnabled = (InpEnableStatusSnapshot && !isTesterRuntime);

   if(
      InpFastEMAPeriod <= 0 || InpSlowEMAPeriod <= InpFastEMAPeriod || InpSlowSlopeLookback <= 0 ||
      InpPivotSpan <= 0 || InpTrendScanBars <= 20 || InpVolatilityLookbackBars <= 0 ||
      InpMinWindowRangeAtr <= 0.0 || InpGridStepAtr <= 0 || InpSessionStartHour < 0 || InpSessionStartHour > 23 ||
      InpSessionEndHour < 0 || InpSessionEndHour > 23 || InpSessionStartHour == InpSessionEndHour ||
      InpMaxEma13DistanceAtr <= 0.0 || InpMinUpperWickShare < 0.0 || InpMinUpperWickShare > 1.0 ||
      InpMaxLowerWickShare < 0.0 || InpMaxLowerWickShare > 1.0 || InpMinUpperWickShare <= InpMaxLowerWickShare ||
      InpRoundShortSessionStartHour < 0 || InpRoundShortSessionStartHour > 23 || InpRoundShortSessionEndHour < 0 ||
      InpRoundShortSessionEndHour > 23 || InpRoundShortSessionStartHour == InpRoundShortSessionEndHour ||
      InpRoundShortMaxEma13DistanceAtr <= 0.0 || InpRoundShortMinLowerWickShare < 0.0 ||
      InpRoundShortMinLowerWickShare > 1.0 || InpRoundShortMaxUpperWickShare < 0.0 ||
      InpRoundShortMaxUpperWickShare > 1.0 || InpRoundShortMinLowerWickShare <= InpRoundShortMaxUpperWickShare ||
      InpRoundShortStopLossAtr <= 0.0 || InpRoundShortTargetRMultiple <= 0.0 || InpRoundShortMaxHoldBars < 1 ||
      InpRoundLooseMaxEma13DistanceAtr <= InpMaxEma13DistanceAtr || InpRoundLooseStopLossAtr <= 0.0 ||
      InpRoundLooseTargetRMultiple <= 0.0 || InpRoundLooseMaxHoldBars < 1 ||
      InpAdxPeriod <= 1 || InpEmaMaxAdx <= 0.0 || InpEmaSessionStartHour < 0 || InpEmaSessionStartHour > 23 ||
      InpEmaSessionEndHour < 0 || InpEmaSessionEndHour > 23 || InpEmaSessionStartHour == InpEmaSessionEndHour ||
      InpEmaMaxEma13DistanceAtr <= 0.0 || InpEmaMaxRet1 < -0.01 || InpEmaMaxRet1 > 0.01 ||
      InpEmaMinUpperWickShare < 0.0 || InpEmaMinUpperWickShare > 1.0 || InpEmaMaxLowerWickShare < 0.0 ||
      InpEmaMaxLowerWickShare > 1.0 || InpEmaMaxCloseLocation < 0.0 || InpEmaMaxCloseLocation > 1.0 ||
      InpEmaMinUpperWickShare <= InpEmaMaxLowerWickShare || InpEmaStopLossAtr <= 0.0 ||
      InpEmaTargetRMultiple <= 0.0 || InpEmaMaxHoldBars < 1 ||
      InpCompressionSessionStartHour < 0 || InpCompressionSessionStartHour > 23 || InpCompressionSessionEndHour < 0 ||
      InpCompressionSessionEndHour > 23 || InpCompressionSessionStartHour == InpCompressionSessionEndHour ||
      InpCompressionMaxAdx <= 0.0 || InpCompressionMaxEma13DistanceAtr <= 0.0 ||
      InpCompressionMinUpperWickShare < 0.0 || InpCompressionMinUpperWickShare > 1.0 ||
      InpCompressionMaxLowerWickShare < 0.0 || InpCompressionMaxLowerWickShare > 1.0 ||
      InpCompressionMinUpperWickShare <= InpCompressionMaxLowerWickShare ||
      InpCompressionStopLossAtr <= 0.0 || InpCompressionTargetRMultiple <= 0.0 || InpCompressionMaxHoldBars < 1 ||
      InpRsiPeriod < 2 || InpRsiOversold <= 0.0 || InpRsiOversold >= 100.0 || InpRsiSessionStartHour < 0 ||
      InpRsiSessionStartHour > 23 || InpRsiSessionEndHour < 0 || InpRsiSessionEndHour > 23 ||
      InpRsiSessionStartHour == InpRsiSessionEndHour || InpRsiMaxEma13DistanceAtr <= 0.0 ||
      InpRsiTouchBufferAtr < 0.0 || InpRsiMinCloseLocation < 0.0 || InpRsiMinCloseLocation > 1.0 ||
      InpRsiMinBodyAtr <= 0.0 || InpRsiMaxLowerWickShare < 0.0 || InpRsiMaxLowerWickShare > 1.0 ||
      InpRsiStopLossAtr <= 0.0 || InpRsiTargetRMultiple <= 0.0 || InpRsiMaxHoldBars < 1 ||
      InpBreakoutSessionStartHour < 0 || InpBreakoutSessionStartHour > 23 || InpBreakoutSessionEndHour < 0 ||
      InpBreakoutSessionEndHour > 23 || InpBreakoutSessionStartHour == InpBreakoutSessionEndHour ||
      InpBreakoutLookbackBars <= 0 || InpBreakoutMidpointDistanceAtr <= 0.0 || InpBreakoutTouchToleranceAtr < 0.0 ||
      InpBreakoutRetestBufferAtr < 0.0 || InpBreakoutRetestDelayBars < 1 || InpBreakoutMinCloseLocation < 0.0 ||
      InpBreakoutMinCloseLocation > 1.0 || InpBreakoutMinBodyAtr <= 0.0 || InpBreakoutMinBodyToRange <= 0.0 ||
      InpBreakoutMinBodyToRange > 1.0 || InpBreakoutMaxToEma13Atr <= 0.0 ||
      InpBreakoutMinRetestCloseLocation < 0.0 || InpBreakoutMinRetestCloseLocation > 1.0 ||
      InpBreakoutMaxRetestDepthAtr < 0.0 || InpBreakoutStopLossAtr <= 0.0 ||
      InpBreakoutTargetRMultiple <= 0.0 || InpBreakoutMaxHoldBars < 1 ||
      InpDowSessionStartHour < 0 || InpDowSessionStartHour > 23 || InpDowSessionEndHour < 0 ||
      InpDowSessionEndHour > 23 || InpDowSessionStartHour == InpDowSessionEndHour ||
      InpDowPivotSpan <= 0 || InpDowTrendScanBars <= 20 ||
      InpDowMinBreachAtr < 0.0 || InpDowMaxBreachAtr < InpDowMinBreachAtr ||
      InpDowMinCloseLocation < 0.0 || InpDowMinCloseLocation > 1.0 ||
      InpDowMinLowerWickShare < 0.0 || InpDowMinLowerWickShare > 1.0 ||
      InpDowMaxUpperWickShare < 0.0 || InpDowMaxUpperWickShare > 1.0 ||
      InpDowStopBufferAtr < 0.0 || InpDowTargetBufferAtr < 0.0 ||
      InpDowMinTargetRMultiple <= 0.0 || InpDowMaxHoldBars < 1 ||
      InpRangeSessionStartHour < 0 || InpRangeSessionStartHour > 23 || InpRangeSessionEndHour < 0 ||
      InpRangeSessionEndHour > 23 || InpRangeSessionStartHour == InpRangeSessionEndHour ||
      InpRangeLookbackBars < 5 || InpRangeAdxPeriod < 2 || InpRangeMaxAdx <= 0.0 ||
      InpRangeAtrPeriod < 2 || InpRangeMaxWidthAtrMultiple <= 0.0 ||
      InpRangeMinBreachAtr < 0.0 || InpRangeMaxBreachAtr < InpRangeMinBreachAtr ||
      InpRangeMinCloseLocation < 0.0 || InpRangeMinCloseLocation > 1.0 ||
      InpRangeMinLowerWickShare < 0.0 || InpRangeMinLowerWickShare > 1.0 ||
      InpRangeMaxUpperWickShare < 0.0 || InpRangeMaxUpperWickShare > 1.0 ||
      InpRangeStopBufferAtr < 0.0 || InpRangeTargetBufferAtr < 0.0 ||
      InpRangeMinTargetRMultiple <= 0.0 || InpRangeMaxHoldBars < 1 ||
      InpFractalSessionStartHour < 0 || InpFractalSessionStartHour > 23 || InpFractalSessionEndHour < 0 ||
      InpFractalSessionEndHour > 23 || InpFractalSessionStartHour == InpFractalSessionEndHour ||
      InpFractalPivotSpan <= 0 || InpFractalScanBars <= 20 || InpFractalMidEMAPeriod <= InpFastEMAPeriod ||
      InpFractalSlowEMAPeriod <= InpFractalMidEMAPeriod || InpFractalStochKPeriod < 2 ||
      InpFractalStochDPeriod < 1 || InpFractalStochSlowing < 1 ||
      InpFractalStochBuyLevel <= 0.0 || InpFractalStochBuyLevel >= 100.0 ||
      InpFractalStopBufferAtr < 0.0 || InpFractalTargetBufferAtr < 0.0 ||
      InpFractalMinTargetRMultiple <= 0.0 || InpFractalMaxHoldBars < 1 ||
      InpStopLossAtr <= 0.0 || InpTargetRMultiple <= 0.0 || InpMaxHoldBars < 1 ||
      InpMaxOpenPositions < 1 || InpRiskPercent <= 0.0 ||
      InpDistanceATRPeriod<2 || InpDeviationAtr<0.0 || InpRiskPercent>100.0 ||
      InpDailyLossCapPercent<=0.0 || InpDailyLossCapPercent>=100.0 ||
      InpEquityDrawdownCapPercent < 0.0 || InpMaxTradesPerDay < 0 || InpMaxSpreadAtr <= 0.0 || InpMagicNumber <= 0 ||
      InpStatusHeartbeatSeconds < 0 || InpEquityDrawdownCapPercent>=100.0
   )
      return INIT_PARAMETERS_INCORRECT;

   if(!ParseWeekdays(runtimeAllowedWeekdays))
      return INIT_PARAMETERS_INCORRECT;
   if(!SymbolInfoInteger(runtimeSymbol, SYMBOL_SELECT))
      if(!SymbolSelect(runtimeSymbol, true))
         return INIT_FAILED;

   distanceAtrHandle=iATR(runtimeSymbol,InpSignalTimeframe,InpDistanceATRPeriod);
   fastEmaHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowEmaHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   adxHandle = iADX(runtimeSymbol, InpSignalTimeframe, InpAdxPeriod);
   rsiHandle = iRSI(runtimeSymbol, InpSignalTimeframe, InpRsiPeriod, PRICE_CLOSE);
   dowFastEmaHandle = iMA(runtimeSymbol, InpDowSignalTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   dowSlowEmaHandle = iMA(runtimeSymbol, InpDowSignalTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   rangeFastEmaHandle = iMA(runtimeSymbol, InpRangeSignalTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   rangeSlowEmaHandle = iMA(runtimeSymbol, InpRangeSignalTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   rangeAdxHandle = iADX(runtimeSymbol, InpRangeSignalTimeframe, InpRangeAdxPeriod);
   rangeAtrHandle = iATR(runtimeSymbol, InpRangeSignalTimeframe, InpRangeAtrPeriod);
   fractalFastEmaHandle = iMA(runtimeSymbol, InpFractalSignalTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   fractalMidEmaHandle = iMA(runtimeSymbol, InpFractalSignalTimeframe, InpFractalMidEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   fractalSlowEmaHandle = iMA(runtimeSymbol, InpFractalSignalTimeframe, InpFractalSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   fractalStochHandle = iStochastic(runtimeSymbol, InpFractalSignalTimeframe, InpFractalStochKPeriod, InpFractalStochDPeriod,
                                    InpFractalStochSlowing, MODE_SMA, STO_LOWHIGH);
   if(distanceAtrHandle == INVALID_HANDLE || fastEmaHandle == INVALID_HANDLE || slowEmaHandle == INVALID_HANDLE || adxHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE ||
      dowFastEmaHandle == INVALID_HANDLE || dowSlowEmaHandle == INVALID_HANDLE ||
      rangeFastEmaHandle == INVALID_HANDLE || rangeSlowEmaHandle == INVALID_HANDLE ||
      rangeAdxHandle == INVALID_HANDLE || rangeAtrHandle == INVALID_HANDLE ||
      fractalFastEmaHandle == INVALID_HANDLE || fractalMidEmaHandle == INVALID_HANDLE ||
      fractalSlowEmaHandle == INVALID_HANDLE || fractalStochHandle == INVALID_HANDLE)
      return INIT_FAILED;

   trade.SetExpertMagicNumber((ulong)InpMagicNumber);
   trade.SetAsyncMode(false);
   if(!trade.SetTypeFillingBySymbol(runtimeSymbol)) return INIT_FAILED;
   UpdateDailyAnchor();
   if(!RefreshDailyTradeCount()) return INIT_FAILED;
   ReconcileUncertainSend();

   if(InpEnableTelemetry && !OpenTelemetryFile())
      Print("Telemetry file could not be opened. Continuing without telemetry.");

   if((runtimeOperatorControlEnabled || runtimeStatusSnapshotEnabled) && InpStatusHeartbeatSeconds > 0)
     {
      EventSetTimer(InpStatusHeartbeatSeconds);
      timerStarted = true;
     }

   if(!DCOpen() || !PFOpen(runtimeTelemetryFileName+".risk.csv") || !PFAOpen(runtimeTelemetryFileName+".adjustment.csv") || !PCOpen(runtimeSymbol,runtimeTelemetryFileName+".portable_context.csv")) return INIT_FAILED;
   RefreshOperatorMode();
   WriteStatusSnapshot();
   return INIT_SUCCEEDED;
  }

void BaseOnDeinit(const int reason)
  {
   FlushDailySummary(TimeCurrent(), "deinit");
   WriteStatusSnapshot();
   if(timerStarted)
     {
      EventKillTimer();
      timerStarted = false;
     }
   PFAClose();PFClose();PCClose();
   DCClose();
   CloseTelemetryFile();
   if(funnelHandle!=INVALID_HANDLE) FileClose(funnelHandle);
   SaveRiskState();
   if(PersistRiskState()) GlobalVariablesFlush();
   if(distanceAtrHandle!=INVALID_HANDLE) IndicatorRelease(distanceAtrHandle);
   if(fastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(fastEmaHandle);
   if(slowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(slowEmaHandle);
   if(adxHandle != INVALID_HANDLE)
      IndicatorRelease(adxHandle);
   if(rsiHandle != INVALID_HANDLE)
      IndicatorRelease(rsiHandle);
   if(dowFastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(dowFastEmaHandle);
   if(dowSlowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(dowSlowEmaHandle);
   if(rangeFastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(rangeFastEmaHandle);
   if(rangeSlowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(rangeSlowEmaHandle);
   if(rangeAdxHandle != INVALID_HANDLE)
      IndicatorRelease(rangeAdxHandle);
   if(rangeAtrHandle != INVALID_HANDLE)
      IndicatorRelease(rangeAtrHandle);
   if(fractalFastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(fractalFastEmaHandle);
   if(fractalMidEmaHandle != INVALID_HANDLE)
      IndicatorRelease(fractalMidEmaHandle);
   if(fractalSlowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(fractalSlowEmaHandle);
   if(fractalStochHandle != INVALID_HANDLE)
      IndicatorRelease(fractalStochHandle);
  }

void OnTimer()
  {
   UpdateDailyAnchor();
   UpdateEquityPeak();
   RefreshOperatorMode();
   if(operatorMode == "flatten")
      FlattenManagedPositions("operator_flatten_timer");
   WriteStatusSnapshot();
  }

void BaseOnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != runtimeSymbol)
      return;

   long dealMagic = (long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if(dealMagic != InpMagicNumber)
      return;

   long dealEntry = (long)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   long dealType = (long)HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   string entrySide = (dealType == DEAL_TYPE_BUY) ? "buy" : "sell";
   string exitSide = (dealType == DEAL_TYPE_BUY) ? "sell" : "buy";
   double dealPrice = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   double dealVolume = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);

   if(dealEntry == (long)DEAL_ENTRY_IN)
     {
      RegisterEntryDeal((datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME), entrySide, dealPrice, dealVolume);
      return;
     }

   if(dealEntry != (long)DEAL_ENTRY_OUT &&
      dealEntry != (long)DEAL_ENTRY_OUT_BY &&
      dealEntry != (long)DEAL_ENTRY_INOUT)
      return;

   double netProfit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) +
                      HistoryDealGetDouble(trans.deal, DEAL_SWAP) +
                      HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   RegisterClosedDeal((datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME), netProfit, exitSide, dealPrice, dealVolume);
  }

void QABaseOnTick()
  {
   UpdateDailyAnchor();
   UpdateEquityPeak();
   RefreshOperatorMode();
   if(operatorMode == "flatten")
      FlattenManagedPositions("operator_flatten");

   ReconcileUncertainSend();
   bool dailyBlocked=IsDailyLossCapBlocked();
   bool equityBlocked=IsEquityDrawdownBlocked();
   if(dailyBlocked && InpFlattenOnDailyLossCap) FlattenManagedPositions("daily_loss_cap_tick");
   if(equityBlocked && InpFlattenOnEquityDrawdownCap) FlattenManagedPositions("equity_drawdown_cap_tick");

   datetime barTime = 0;
   bool newMainBar = IsNewBar(barTime);
   DCUpdate(newMainBar);
   datetime dowBarTime = 0;
   bool newDowBar = false;
   if(InpEnableDowSweepBucket)
      newDowBar = IsNewBarForTimeframe(InpDowSignalTimeframe, lastDowBarTime, dowBarTime);
   datetime rangeBarTime = 0;
   bool newRangeBar = false;
   if(InpEnableRangeReclaimBucket || InpEnableRangeShortBucket)
      newRangeBar = IsNewBarForTimeframe(InpRangeSignalTimeframe, lastRangeBarTime, rangeBarTime);
   datetime fractalBarTime = 0;
   bool newFractalBar = false;
   if(InpEnableFractalTrendBucket)
      newFractalBar = IsNewBarForTimeframe(InpFractalSignalTimeframe, lastFractalBarTime, fractalBarTime);
   if(!newMainBar && !newDowBar && !newRangeBar && !newFractalBar)
      return;

   if(CountManagedPositions() > 0)
      ManageOpenPosition();

   WriteStatusSnapshot();

   // Record raw signals even when an execution gate rejects them.
   if(dailyBlocked) dailyBlockedDailyLoss++;
   if(equityBlocked) dailyBlockedEquityCap++;
   if(!RefreshDailyTradeCount()) return;

   int baseOpenCount = CountManagedPositions();
   int pendingOpenCount = 0;

   if(newMainBar)
     {
      MqlRates rates[];
      double fastEma[];
      double slowEma[];
      double adxValues[];
      double rsiValues[];
      roundDecision="DATA_UNAVAILABLE";
      if(LoadSignalWindow(rates, fastEma, slowEma, adxValues, rsiValues, 260))
        {
         SignalBucket buckets[7];
         int bucketCount = 0;
         bool roundSignal=EvaluateRoundSignal(rates,fastEma,slowEma);
         bool executionGate=CanOpenAnotherTrade(barTime);
         RecordFunnel(barTime,roundSignal,executionGate);
         if(roundSignal) buckets[bucketCount++] = SIGNAL_ROUND;
         if(EvaluateRoundShortSignal(rates, fastEma, slowEma))
            buckets[bucketCount++] = SIGNAL_ROUND_SHORT;
         if(EvaluateEmaSignal(rates, fastEma, slowEma, adxValues))
            buckets[bucketCount++] = SIGNAL_EMA;
         if(EvaluateCompressionSignal(rates, fastEma, slowEma, adxValues))
            buckets[bucketCount++] = SIGNAL_COMPRESSION;
         if(EvaluateRsiSignal(rates, fastEma, slowEma, rsiValues))
            buckets[bucketCount++] = SIGNAL_RSI;
         if(EvaluateBreakoutSignal(rates, fastEma, slowEma))
            buckets[bucketCount++] = SIGNAL_BREAKOUT;
         if(EvaluateRoundLooseSignal(rates, fastEma, slowEma))
            buckets[bucketCount++] = SIGNAL_ROUND_LOOSE;

         for(int i = 0; executionGate && i < bucketCount; ++i)
           {
            SignalBucket bucket = buckets[i];
            if(InpMaxTradesPerDay > 0 && dailyTradeCount + pendingOpenCount >= InpMaxTradesPerDay)
               break;
            if(!CanOpenBucketTrade(bucket, baseOpenCount, pendingOpenCount))
               continue;
            if(OpenPosition(bucket))
               pendingOpenCount++;
           }
        }
     }

   if(newDowBar && CanOpenAnotherTrade(dowBarTime))
     {
      if(InpMaxTradesPerDay <= 0 || dailyTradeCount + pendingOpenCount < InpMaxTradesPerDay)
        {
         MqlRates envRates[];
         double envFastEma[];
         double envSlowEma[];
         double envAdxValues[];
         double envRsiValues[];
         MqlRates dowRates[];
         double dowFastEma[];
         double dowSlowEma[];
         if(LoadSignalWindow(envRates, envFastEma, envSlowEma, envAdxValues, envRsiValues, 260) &&
            LoadDowSignalWindow(dowRates, dowFastEma, dowSlowEma, 220))
           {
            if(CanOpenBucketTrade(SIGNAL_DOW_SWEEP, baseOpenCount, pendingOpenCount) &&
               EvaluateDowSweepSignal(envRates, envFastEma, envSlowEma, dowRates, dowFastEma, dowSlowEma))
              {
               if(OpenPosition(SIGNAL_DOW_SWEEP))
                  pendingOpenCount++;
              }
           }
        }
     }

   if(newRangeBar && CanOpenAnotherTrade(rangeBarTime))
     {
      if(InpMaxTradesPerDay <= 0 || dailyTradeCount + pendingOpenCount < InpMaxTradesPerDay)
        {
         MqlRates envRates[];
         double envFastEma[];
         double envSlowEma[];
         double envAdxValues[];
         double envRsiValues[];
         MqlRates rangeRates[];
         double rangeFastEma[];
         double rangeSlowEma[];
         double rangeAdx[];
         double rangeAtr[];
         if(LoadSignalWindow(envRates, envFastEma, envSlowEma, envAdxValues, envRsiValues, 260) &&
            LoadRangeSignalWindow(rangeRates, rangeFastEma, rangeSlowEma, rangeAdx, rangeAtr, 220))
           {
            if(CanOpenBucketTrade(SIGNAL_RANGE_RECLAIM, baseOpenCount, pendingOpenCount) &&
               EvaluateRangeReclaimSignal(envRates, envFastEma, envSlowEma, rangeRates, rangeFastEma, rangeSlowEma, rangeAdx, rangeAtr))
              {
               if(OpenPosition(SIGNAL_RANGE_RECLAIM))
                  pendingOpenCount++;
              }
            if(CanOpenBucketTrade(SIGNAL_RANGE_RECLAIM_SHORT, baseOpenCount, pendingOpenCount) &&
               EvaluateRangeReclaimShortSignal(envRates, envFastEma, envSlowEma, rangeRates, rangeFastEma, rangeSlowEma, rangeAdx, rangeAtr))
              {
               if(OpenPosition(SIGNAL_RANGE_RECLAIM_SHORT))
                  pendingOpenCount++;
              }
           }
        }
     }

   if(newFractalBar && CanOpenAnotherTrade(fractalBarTime))
     {
      if(InpMaxTradesPerDay <= 0 || dailyTradeCount + pendingOpenCount < InpMaxTradesPerDay)
        {
         MqlRates envRates[];
         double envFastEma[];
         double envSlowEma[];
         double envAdxValues[];
         double envRsiValues[];
         MqlRates fractalRates[];
         double fractalFastEma[];
         double fractalMidEma[];
         double fractalSlowEma[];
         double stochK[];
         double stochD[];
         if(LoadSignalWindow(envRates, envFastEma, envSlowEma, envAdxValues, envRsiValues, 260) &&
            LoadFractalSignalWindow(fractalRates, fractalFastEma, fractalMidEma, fractalSlowEma, stochK, stochD, 220))
           {
            if(CanOpenBucketTrade(SIGNAL_FRACTAL_TREND, baseOpenCount, pendingOpenCount) &&
               EvaluateFractalTrendSignal(envRates, envFastEma, envSlowEma, fractalRates, fractalFastEma, fractalMidEma, fractalSlowEma, stochK, stochD))
              {
               if(OpenPosition(SIGNAL_FRACTAL_TREND))
                  pendingOpenCount++;
              }
           }
        }
     }
  }

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

int QABaseOnInit(){int rc=BaseOnInit();if(rc==INIT_SUCCEEDED){DQStart(runtimeTelemetryFileName+".cost.csv");if(dqFile==INVALID_HANDLE)return INIT_FAILED;}return rc;}
void QABaseOnDeinit(const int reason){DQClose();BaseOnDeinit(reason);}
double QABaseOnTester(){DQDrain(true);return 0;}
void OnTradeTransaction(const MqlTradeTransaction &t,const MqlTradeRequest &q,const MqlTradeResult &r)
{BaseOnTradeTransaction(t,q,r);if(t.type==TRADE_TRANSACTION_DEAL_ADD)DQCapture(t.deal);}

int OnInit()
  {int rc=QABaseOnInit();if(rc==INIT_SUCCEEDED && !QEStart(runtimeSymbol,runtimeTelemetryFileName))return INIT_FAILED;return rc;}
void OnTick(){QEObserve();QABaseOnTick();}
double OnTester(){double result=QABaseOnTester();QEEnd();return result;}
void OnDeinit(const int reason){QABaseOnDeinit(reason);QEClose();}
