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
