#property strict
#property version "1.00"
#property tester_file "M15EnvBars_0.csv"
#property tester_file "M15EnvBars_1.csv"
#property tester_file "M15EnvQueries_0.csv"
#property tester_file "M15EnvQueries_1.csv"
#include "../Include/M15Environment.mqh"
void Export(int file,int run,string id,long msc,double ask,const M15EnvSnapshot &s)
{
   FileWrite(file,run,id,msc,ask,s.regime,s.position,DoubleToString(s.raw,15),s.location,s.high,s.low,
      s.break_direction,(long)s.break_time,s.break_level,(long)s.break_bar,(long)s.break_confirmed,(long)s.asof);
}
int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER)) return INIT_FAILED;
   int out=FileOpen("M15EnvParity.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   int states=FileOpen("M15EnvStates.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(out==INVALID_HANDLE || states==INVALID_HANDLE) return INIT_FAILED;
   FileWrite(out,"run","id","time_msc","ask","regime","position","raw_position","range_location","structure_high","structure_low","last_break_direction","break_time","break_level","break_bar","break_confirmed","asof");
   FileWrite(states,"run","id","time_msc","ask","regime","position","raw_position","range_location","structure_high","structure_low","last_break_direction","break_time","break_level","break_bar","break_confirmed","asof");
   int queries=0;
   for(int run=0;run<2;run++)
   {
      string suffix=IntegerToString(run)+".csv";
      int file=FileOpen("M15EnvBars_"+suffix,FILE_READ|FILE_CSV|FILE_ANSI,',');
      if(file==INVALID_HANDLE) return INIT_FAILED;
      MqlRates bars[];int n=0;
      while(!FileIsEnding(file))
      {
         ArrayResize(bars,n+1,10000);ZeroMemory(bars[n]);bars[n].time=(datetime)FileReadNumber(file);
         bars[n].open=FileReadNumber(file);bars[n].high=FileReadNumber(file);bars[n].low=FileReadNumber(file);bars[n].close=FileReadNumber(file);n++;
      }
      FileClose(file);CM15Environment env;env.Reset();
      for(int i=0;i<n;i++)
      {
         env.Step(bars,i);M15EnvSnapshot s;env.Snapshot(bars[i].time+900,bars[i].close,s);
         Export(states,run,IntegerToString(i),(long)(bars[i].time+900)*1000,bars[i].close,s);
      }
      env.Reset();int cursor=0;
      file=FileOpen("M15EnvQueries_"+suffix,FILE_READ|FILE_CSV|FILE_ANSI,',');
      if(file==INVALID_HANDLE) return INIT_FAILED;
      while(!FileIsEnding(file))
      {
         string id=FileReadString(file);long msc=(long)FileReadNumber(file);double ask=FileReadNumber(file);
         while(cursor<n && (long)(bars[cursor].time+900)*1000<=msc) {env.Step(bars,cursor);cursor++;}
         M15EnvSnapshot s;env.Snapshot((datetime)(msc/1000),ask,s);Export(out,run,id,msc,ask,s);queries++;
      }
      FileClose(file);
   }
   FileClose(out);FileClose(states);Print("M15_REPLAY_COMPLETE queries=",queries," orders_sent=0");return INIT_SUCCEEDED;
}
void OnTick() {}
