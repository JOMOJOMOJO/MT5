#property strict
// Read-only history export for independent pre-signal M5-break auditing.
void OnStart()
{
   MqlRates rates[];
   int n=CopyRates("USDJPY",PERIOD_M1,D'2025.03.28',D'2025.05.01',rates);
   if(n<100) { Print("TW_EXPORT_FAILED n=",n); return; }
   int f=FileOpen("TW_april_rates.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(f==INVALID_HANDLE) { Print("TW_EXPORT_FAILED file"); return; }
   FileWrite(f,"time","open","high","low","close");
   for(int i=0;i<n;i++)
      FileWrite(f,TimeToString(rates[i].time,TIME_DATE|TIME_SECONDS),rates[i].open,rates[i].high,rates[i].low,rates[i].close);
   FileClose(f);
   Print("TW_EXPORT_RESULT bars=",n);
}
