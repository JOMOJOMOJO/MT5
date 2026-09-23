#property strict
// Read-only native M1 history for independent signal geometry checks.
void OnStart()
{
   MqlRates rates[]; int n=-1;
   for(int attempt=0;attempt<20;attempt++)
   {
      n=CopyRates("USDJPY",PERIOD_M1,D'2025.04.25',D'2025.08.01',rates);
      if(n>100) break;
      Sleep(500);
   }
   if(n<100) { Print("TW_HOLDOUT_EXPORT_FAILED n=",n); return; }
   int f=FileOpen("TW_holdout_bars.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(f==INVALID_HANDLE) { Print("TW_HOLDOUT_EXPORT_FAILED file"); return; }
   FileWrite(f,"time","open","high","low","close");
   for(int i=0;i<n;i++)
      FileWrite(f,TimeToString(rates[i].time,TIME_DATE|TIME_SECONDS),rates[i].open,rates[i].high,rates[i].low,rates[i].close);
   FileClose(f);
   Print("TW_HOLDOUT_EXPORT_RESULT bars=",n);
}
