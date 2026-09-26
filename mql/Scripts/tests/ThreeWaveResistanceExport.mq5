#property strict
#property version "1.00"
#property description "Read-only native OHLC export for causal resistance research; no orders."
void OnStart()
{
   string symbol="USDJPY";
   datetime from=D'2024.10.01',until=D'2025.11.01'-1;
   ENUM_TIMEFRAMES frames[]={PERIOD_M1,PERIOD_M5,PERIOD_M15,PERIOD_H1};
   string names[]={"M1","M5","M15","H1"};
   int meta=FileOpen("TW_resistance_export.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(meta==INVALID_HANDLE)return;
   FileWrite(meta,"tf","count","first","last","point","tick_size","digits","ok");
   int failures=0;
   for(int f=0;f<4;f++)
   {
      MqlRates rates[];ArraySetAsSeries(rates,false);int n=-1;
      for(int retry=0;retry<30;retry++)
      {
         n=CopyRates(symbol,frames[f],from,until,rates);
         if(n>100 && rates[0].time<D'2024.10.03' && rates[n-1].time>=D'2025.10.31')break;
         Sleep(1000);
      }
      bool ok=n>100;
      if(ok)ok=rates[0].time<D'2024.10.03' && rates[n-1].time>=D'2025.10.31';
      int file=FileOpen("TW_resistance_"+names[f]+".csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
      if(file==INVALID_HANDLE)ok=false;
      if(file!=INVALID_HANDLE)
      {
         FileWrite(file,"time","open","high","low","close");
         for(int i=0;i<n;i++)FileWrite(file,TimeToString(rates[i].time,TIME_DATE|TIME_SECONDS),
             DoubleToString(rates[i].open,8),DoubleToString(rates[i].high,8),DoubleToString(rates[i].low,8),DoubleToString(rates[i].close,8));
         FileClose(file);
      }
      FileWrite(meta,names[f],n,n>0?TimeToString(rates[0].time,TIME_DATE|TIME_SECONDS):"",n>0?TimeToString(rates[n-1].time,TIME_DATE|TIME_SECONDS):"",
         DoubleToString(SymbolInfoDouble(symbol,SYMBOL_POINT),8),DoubleToString(SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE),8),SymbolInfoInteger(symbol,SYMBOL_DIGITS),ok);
      if(!ok)failures++;
      Print("TW_RESISTANCE_EXPORT tf=",names[f]," bars=",n," ok=",ok);
   }
   FileClose(meta);Print("TW_RESISTANCE_EXPORT_RESULT failures=",failures," orders_sent=0");
}
