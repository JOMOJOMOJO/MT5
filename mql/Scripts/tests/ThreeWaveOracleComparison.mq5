#property strict
#include "../../Include/ThreeWaveInputs.mqh"
#include "../../Include/ThreeWaveStructure.mqh"
#include "ThreeWaveOriginalOracle.mqh"
void OnStart()
{
   MqlRates all_lower[],all_higher[];
   datetime from=D'2025.03.03',to=D'2025.03.08';
   int lc=-1,hc=-1;
   for(int i=0;i<100 && (lc<6000 || hc<1800);i++)
   {
      lc=CopyRates("USDJPY",PERIOD_M1,from-20*86400,to,all_lower);
      hc=CopyRates("USDJPY",PERIOD_M5,from-20*86400,to,all_higher);
      if(lc<6000 || hc<1800) Sleep(100);
   }
   if(lc<6000 || hc<1800) { Print("TW_ORACLE_DATA_UNAVAILABLE"); return; }
   int out=FileOpen("TW_original_comparison.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   FileWrite(out,"engine","signal_time","m5_choch","m1_choch","m5_origin","m1_origin","hl","trigger");
   int hi=0,original_count=0,shared_count=0,decisions=0;
   for(int li=0;li<lc;li++)
   {
      datetime now=all_lower[li].time;
      if(now<from || now>=to) continue;
      while(hi+1<hc && all_higher[hi+1].time<=now) hi++;
      int ln=MathMin(InpHistoryLowerBars,li+1),hn=MathMin(InpHistoryHigherBars,hi+1);
      if(ln<100 || hn<100) continue;
      MqlRates lower[],higher[];
      ArrayCopy(lower,all_lower,0,li+1-ln,ln); ArrayCopy(higher,all_higher,0,hi+1-hn,hn);
      ArrayResize(tw_events,0); tw_trace_from=now;
      PivotPoint lp[],hp[]; M5Setup sets[];
      BuildPivots(lower,PERIOD_M1,2,2,lp); BuildPivots(higher,PERIOD_M5,2,2,hp); BuildHigherSetups(higher,hp,sets);
      for(int j=0;j<ArraySize(sets);j++)
      {
         M1Pattern p; AnalyzeLowerPattern(lower,lp,sets[j],p);
         if(!p.ready || p.ready_time+60!=now) continue;
         shared_count++;
         FileWrite(out,"shared",TimeToString(now,TIME_DATE|TIME_SECONDS),sets[j].break_time,p.choch_time,
                   sets[j].origin_low.price,p.reversal_low.price,p.hl.price,p.early_break?"return_high":"wave1_high");
      }
      OriginalPivotPoint olp[],ohp[]; OriginalM5Setup os[];
      OriginalBuildPivots(lower,PERIOD_M1,2,2,olp); OriginalBuildPivots(higher,PERIOD_M5,2,2,ohp); OriginalBuildHigherSetups(higher,ohp,os);
      for(int j=0;j<ArraySize(os);j++)
      {
         OriginalM1Pattern p; OriginalAnalyzeLowerPattern(lower,olp,os[j],p);
         if(!p.ready || p.ready_time+60!=now) continue;
         original_count++;
         FileWrite(out,"original",TimeToString(now,TIME_DATE|TIME_SECONDS),os[j].break_time,p.choch_time,
                   os[j].origin_low.price,p.reversal_low.price,p.hl.price,p.early_break?"return_high":"wave1_high");
      }
      decisions++;
   }
   FileClose(out);
   Print("TW_ORACLE_RESULT decisions=",decisions," original=",original_count," shared=",shared_count);
}
