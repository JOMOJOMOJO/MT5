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
#property version "1.00"
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

input string InpTelemetryFileName="portable_harness.csv";
int qaFile=INVALID_HANDLE,qaErrors=0,qaCount=0;
void QACheck(const string name,const bool ok)
  {qaCount++;if(!ok)qaErrors++;FileWrite(qaFile,name,(int)ok);Print("PF_QA ",name," ",ok);}
void QAContext()
  {
   MqlRates r[18];ZeroMemory(r);
   double hi[18]={10,11,15,12,10,11,12,16,13,10,11,12,17,14,11,12,13,14};
   double lo[18]={8,9,10,9,6,8,9,11,10,7,9,10,12,11,8,9,10,11};
   for(int i=0;i<18;i++){r[i].time=D'2023.01.02'+i*900;r[i].high=hi[i];r[i].low=lo[i];r[i].close=(hi[i]+lo[i])/2;}
   CM15Environment a,b;a.Reset();b.Reset();M15EnvSnapshot waiting,known,mutated,outside;
   for(int i=0;i<=10;i++)a.Step(r,i);
   a.Snapshot(r[10].time+900,12,waiting);
   QACheck("RIGHT_CONFIRMATION_WAIT",waiting.regime=="UNKNOWN");
   a.Step(r,11);a.Snapshot(r[11].time+900,12,known);
   QACheck("CONFIRMED_STRUCTURE_UP",known.regime=="UP"&&known.position=="MID"&&MathAbs(known.raw-0.6)<1e-9);
   for(int i=12;i<18;i++){r[i].high=100000;r[i].low=0.01;r[i].close=90000;}
   for(int i=0;i<=11;i++)b.Step(r,i);
   b.Snapshot(r[11].time+900,12,mutated);
   QACheck("FUTURE_SUFFIX_INVARIANT",mutated.regime==known.regime&&mutated.raw==known.raw&&mutated.asof==known.asof&&mutated.break_time==known.break_time);
   b.Snapshot(r[11].time+900,20,outside);
   QACheck("RAW_POSITION_OUTSIDE",outside.location=="ABOVE"&&outside.raw>1&&outside.position=="HIGH");
  }
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER)||MQLInfoInteger(MQL_OPTIMIZATION))return INIT_FAILED;
   qaFile=FileOpen(InpTelemetryFileName,FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');if(qaFile==INVALID_HANDLE)return INIT_FAILED;
   FileWrite(qaFile,"test","passed");
   QACheck("USD_BASE_BUY",PFUsdDirection("USD","JPY",1)==1);
   QACheck("USD_BASE_SELL",PFUsdDirection("USD","JPY",-1)==-1);
   QACheck("USD_PROFIT_BUY",PFUsdDirection("EUR","USD",1)==-1);
   QACheck("GOLD_USD_BUY",PFUsdDirection("XAU","USD",1)==-1);
   QACheck("CROSS_NO_DIRECT_USD",PFUsdDirection("EUR","JPY",1)==0);
   QACheck("INVALID_VOLUME_SPEC",PFFloorVolume(1,0,10,0.01)==0);
   QACheck("NO_MINIMUM_UPSIZE",PFFloorVolume(0.009,0.01,10,0.01)==0);
   QACheck("DECIMAL_BOUNDARY",MathAbs(PFFloorVolume(0.03,0.01,10,0.01)-0.03)<1e-12);
   QACheck("QUARTER_LOT_STEP",MathAbs(PFFloorVolume(1.12,0.25,10,0.25)-1)<1e-12);
   QACheck("MAX_LOT_CAP",MathAbs(PFFloorVolume(3,0.1,0.5,0.1)-0.5)<1e-12);
   QACheck("OUTWARD_SL",MathAbs(PFPrice(157.1237,0.005,3,-1)-157.120)<1e-9);
   QACheck("UPWARD_SL",MathAbs(PFPrice(157.1237,0.005,3,1)-157.125)<1e-9);
   string resolved,reason;
   QACheck("EXACT_SYMBOL",PFResolveSymbol(_Symbol,resolved,reason)&&resolved==_Symbol);
   QACheck("BAD_ALIAS_REFUSED",!PFResolveSymbol("THIS_SYMBOL_DOES_NOT_EXIST",resolved,reason));
   QAContext();
   bool opened=QEStart(_Symbol,InpTelemetryFileName);
   QACheck("ENV_INITIAL_IS_BASELINE",opened && qeHaveBaseline && qeChanges==0);
   QEObserve("VERIFY_UNCHANGED");
   QACheck("ENV_UNCHANGED_IS_NOT_CHANGE",opened && qeChanges==0);
   string initial=qePrevious[0];qePrevious[0]="INJECTED_DIFFERENCE_FOR_FIXTURE";
   QEObserve("VERIFY_CHANGE");
   QACheck("ENV_REAL_DIFFERENCE_DETECTED",opened && qeChanges==1 && qePrevious[0]==initial);
   QEClose();
   FileFlush(qaFile);return INIT_SUCCEEDED;
  }
void OnTick(){}
double OnTester(){return qaErrors==0?(double)qaCount:-(double)qaErrors;}
void OnDeinit(const int reason)
  {if(qaFile!=INVALID_HANDLE)FileClose(qaFile);PrintFormat("PF_QA_FINISH tests=%d errors=%d",qaCount,qaErrors);}
