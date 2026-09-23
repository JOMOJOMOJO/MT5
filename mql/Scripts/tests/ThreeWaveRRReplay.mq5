#property strict
// Read-only paired exits. Never sends orders. Each candidate uses one fixed
// entry and SL, independent of account equity and position occupancy.
input string InpSourceCSV="TW_RR_source.csv";
input datetime InpEnd=D'2025.04.01';
void OnStart()
{
   Print("TW_RR_START source=",InpSourceCSV," end=",TimeToString(InpEnd,TIME_DATE|TIME_SECONDS));
   if(InpEnd<D'2000.01.01') { Print("TW_RR_INVALID_END_PARAMETER"); return; }
   int source=FileOpen(InpSourceCSV,FILE_READ|FILE_TXT|FILE_ANSI);
   int output=FileOpen("TW_RR_pairs.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(source==INVALID_HANDLE || output==INVALID_HANDLE) { Print("TW_RR_FILE_ERROR"); return; }
   FileReadString(source);
   FileWrite(output,"signal_id","signal_time","entry_time","entry","sl","tp1","tp12","outcome1","outcome12",
      "exit1","exit12","mfe_R","mae_R","m5_high","peak_bid","peak_time","ticks","first_tick","last_tick",
      "hl_time","hl_confirmed","ask_at_hl_confirmation","entry_after_hl_minutes","risk_pips","status");
   int count=0,failed=0;
   while(!FileIsEnding(source))
   {
      string line=FileReadString(source),f[];
      if(StringSplit(line,',',f)<49) continue;
      datetime entry_time=StringToTime(f[1]);
      if(entry_time>=InpEnd) { Print("TW_RR_ENTRY_OUTSIDE_WINDOW ",f[0]); failed++; continue; }
      double entry=StringToDouble(f[37]);
      double sl=StringToDouble(f[38]);
      double step=SymbolInfoDouble("USDJPY",SYMBOL_TRADE_TICK_SIZE);
      int digits=(int)SymbolInfoInteger("USDJPY",SYMBOL_DIGITS);
      double point=SymbolInfoDouble("USDJPY",SYMBOL_POINT);
      MqlTick ticks[];
      int n=CopyTicksRange("USDJPY",ticks,COPY_TICKS_ALL,(ulong)entry_time*1000,(ulong)(entry_time+60)*1000-1);
      if(n<=0) { Print("TW_RR_NO_ENTRY_TICKS ",f[0]); failed++; continue; }
      if(entry<=0) entry=ticks[0].ask;
      if(sl<=0) sl=NormalizeDouble(MathFloor((StringToDouble(f[27])-10*point)/step+1e-9)*step,digits);
      double risk=entry-sl;
      if(risk<=0) { Print("TW_RR_INVALID_GEOMETRY ",f[0]); failed++; continue; }
      double tp1=NormalizeDouble(MathRound((entry+risk)/step)*step,digits);
      double tp12=NormalizeDouble(MathRound((entry+1.2*risk)/step)*step,digits);
      datetime hc=StringToTime(f[29]);
      double confirm_ask=0;
      n=CopyTicksRange("USDJPY",ticks,COPY_TICKS_ALL,(ulong)hc*1000,(ulong)(hc+60)*1000-1);
      if(n>0) confirm_ask=ticks[0].ask;
      string o1="CENSORED",o12="CENSORED",status="OK";
      long t1=0,t12=0,peak_time=0,first_tick=0,last_tick=0,total_ticks=0;
      double peak=0,trough=entry;
      datetime end=(datetime)MathMin((long)InpEnd,(long)entry_time+7*86400);
      for(datetime from=entry_time;from<end && o12=="CENSORED";from+=3600)
      {
         datetime to=(datetime)MathMin((long)end,(long)from+3600);
         n=CopyTicksRange("USDJPY",ticks,COPY_TICKS_ALL,(ulong)from*1000,(ulong)to*1000-1);
         if(n<0) { status="TICK_COPY_ERROR"; failed++; break; }
         for(int k=0;k<n;k++)
         {
            if(ticks[k].bid<=0 || ticks[k].ask<=0) continue;
            if(first_tick==0) first_tick=ticks[k].time_msc;
            last_tick=ticks[k].time_msc; total_ticks++;
            double bid=ticks[k].bid;
            if(bid>peak) { peak=bid; peak_time=ticks[k].time_msc; }
            trough=MathMin(trough,bid);
            if(o1=="CENSORED")
            {
               if(bid<=sl) { o1="SL"; t1=ticks[k].time_msc; }
               else if(bid>=tp1) { o1="TP"; t1=ticks[k].time_msc; }
            }
            if(bid<=sl) { o12="SL"; t12=ticks[k].time_msc; break; }
            if(bid>=tp12) { o12="TP"; t12=ticks[k].time_msc; break; }
         }
      }
      FileWrite(output,f[2],f[0],f[1],entry,sl,tp1,tp12,o1,o12,t1,t12,(peak-entry)/risk,(entry-trough)/risk,
         f[14],peak,peak_time,total_ticks,first_tick,last_tick,f[28],f[29],confirm_ask,(entry_time-hc)/60.0,risk/0.01,status);
      FileFlush(output); count++;
   }
   FileClose(source); FileClose(output);
   MqlRates bars[];
   int n=CopyRates("USDJPY",PERIOD_M1,D'2024.12.25',InpEnd,bars);
   int b=FileOpen("TW_RR_bars.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(b!=INVALID_HANDLE)
   {
      FileWrite(b,"time","open","high","low","close");
      for(int i=0;i<n;i++) FileWrite(b,TimeToString(bars[i].time,TIME_DATE|TIME_SECONDS),bars[i].open,bars[i].high,bars[i].low,bars[i].close);
      FileClose(b);
   }
   Print("TW_RR_RESULT candidates=",count," failed=",failed," bars=",n);
}
