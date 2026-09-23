#property strict
#include "../../Include/ThreeWaveInputs.mqh"
#include "../../Include/ThreeWaveFeatureObserver.mqh"
datetime wanted=0,current=0;
int gap_found=0,gaps=0,errors=0,file=INVALID_HANDLE;
void TWFeatureCandidate(const M5Setup &s,const M1Pattern &p,datetime when,string stage)
{
   if(when!=wanted) return;
   gap_found++;
   FileWrite(file,TimeToString(current,TIME_DATE|TIME_SECONDS),TimeToString(when,TIME_DATE|TIME_SECONDS),stage,(long)s.break_time,(long)p.choch_time);
}
void ContextGapMain()
{
   MqlRates all[];int n=-1;
   for(int k=0;k<20;k++)
   {n=CopyRates("USDJPY",PERIOD_M1,D'2025.07.25',D'2025.11.01',all);if(n>100 && all[n-1].time>=D'2025.10.31')break;Sleep(500);}
   if(n<100 || all[n-1].time<D'2025.10.31'){Print("TW_FEATURE_GAP_FAILED data");return;}
   MqlRates warm[];int warm_count=-1;
   for(int k=0;k<20;k++)
   {warm_count=CopyRates("USDJPY",PERIOD_M5,D'2025.07.01',D'2025.11.01',warm);if(warm_count>100 && warm[warm_count-1].time>=D'2025.10.31')break;Sleep(500);}
   if(warm_count<100 || warm[warm_count-1].time<D'2025.10.31'){Print("TW_FEATURE_GAP_FAILED M5 data");return;}
   file=FileOpen("TW_context_gaps.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(file==INVALID_HANDLE)return;
   FileWrite(file,"new_bar","actual_previous_close","stage","parent","attempt");
   MqlRates lower[],higher[];PivotPoint lp[],hp[];M5Setup setups[];
   for(int i=1;i<n;i++)
   {
      current=all[i].time;wanted=all[i-1].time+60;
      if(current==wanted || current<D'2025.08.01' || current>=D'2025.11.01')continue;
      gaps++;
      int a=iBarShift("USDJPY",PERIOD_M1,current,true),b=iBarShift("USDJPY",PERIOD_M5,current,false);
      int lc=CopyRates("USDJPY",PERIOD_M1,a,6000,lower),hc=CopyRates("USDJPY",PERIOD_M5,b,1800,higher);
      if(lc<100 || hc<100 || lower[lc-1].time!=current){errors++;continue;}
      ArrayResize(tw_events,0);tw_trace_from=wanted;
      BuildPivots(lower,PERIOD_M1,2,2,lp);BuildPivots(higher,PERIOD_M5,2,2,hp);BuildHigherSetups(higher,hp,setups);
      for(int j=0;j<ArraySize(setups);j++)
      {M1Pattern p;AnalyzeLowerPattern(lower,lp,setups[j],p);if(p.ready&&p.ready_time+60==wanted)TWFeatureCandidate(setups[j],p,wanted,"READY");}
   }
   FileClose(file);Print("TW_FEATURE_GAP_RESULT gaps=",gaps," missed_candidates=",gap_found," errors=",errors);
}

void OnStart()
{
   ContextGapMain();
   int result=FileOpen("TW_context_gap_result.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(result!=INVALID_HANDLE)
   {
      FileWrite(result,"gaps","missed_candidates","errors","passed");
      FileWrite(result,gaps,gap_found,errors,gaps>0 && gap_found==0 && errors==0);
      FileClose(result);
   }
}
