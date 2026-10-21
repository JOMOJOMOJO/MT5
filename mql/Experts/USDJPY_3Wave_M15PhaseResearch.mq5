#property strict
#property version "1.00"
#property description "Tester-only M15 phase and fixed RR shadow research. Never sends orders."
#include "../Include/PhaseResearchFrozen/ThreeWaveInputs.mqh"
#include "../Include/PhaseResearchFrozen/ThreeWaveStructure.mqh"
#include "../Include/ThreeWaveM15PhaseResearch.mqh"
input int InpResearchStopMode=2;
input int InpResearchBufferPoints=10;
input bool InpAuditFullRebuild=false; // QA only: compare cached parent engine with the original per-minute rebuild.
int fc=INVALID_HANDLE,fo=INVALID_HANDLE,ff=INVALID_HANDLE,fb=INVALID_HANDLE;
datetime last_bar=0,last_parent=0,last_export=0;
M5Setup cached[];
int candidates=0,skips=0;
double multiples[4]={1.0,1.2,1.5,2.0};
struct Shadow
{
   string id,ph,status[4];
   long start,exit[4];
   double entry,sl,risk,tp[4],result[4],mfe[4],mae[4],path_mfe,path_mae;
   bool done[4],path_done;
   long path_end;
};
Shadow shadows[];
string ID(const M5Setup &s,const M1Pattern &p)
{return IntegerToString((long)s.break_time)+"/"+IntegerToString((long)p.choch_time)+"/"+IntegerToString((long)p.ready_time);}
void WriteShadow(const Shadow &s)
{
   for(int j=0;j<4;j++) FileWrite(fo,s.id,s.ph,multiples[j],s.start,s.exit[j],s.entry,s.sl,s.tp[j],s.risk,
      s.status[j],s.done[j]?DoubleToString(s.result[j],12):"",s.mfe[j],s.mae[j],s.path_mfe,s.path_mae,s.path_done,s.path_end);
}
void TickShadows(const MqlTick &tick)
{
   for(int i=ArraySize(shadows)-1;i>=0;i--)
   {
      Shadow s=shadows[i];double r=(tick.bid-s.entry)/s.risk;
      if(!s.path_done)
      {
         if(tick.time_msc<=s.start+86400000)
         {s.path_mfe=MathMax(s.path_mfe,r);s.path_mae=MathMax(s.path_mae,-r);s.path_end=tick.time_msc;}
         if(tick.bid<=s.sl || tick.time_msc>=s.start+86400000) s.path_done=true;
      }
      bool all=true;
      for(int j=0;j<4;j++)
      {
         if(!s.done[j])
         {
            s.mfe[j]=MathMax(s.mfe[j],r);s.mae[j]=MathMax(s.mae[j],-r);
            if(tick.bid<=s.sl){s.status[j]="SL";s.result[j]=r;s.done[j]=true;}
            else if(tick.bid>=s.tp[j]){s.status[j]="TP";s.result[j]=(s.tp[j]-s.entry)/s.risk;s.done[j]=true;}
            if(s.done[j]) s.exit[j]=tick.time_msc;
         }
         if(!s.done[j]) all=false;
      }
      if(all && s.path_done)
      {WriteShadow(s);int n=ArraySize(shadows);if(i<n-1) shadows[i]=shadows[n-1];ArrayResize(shadows,n-1);}
      else shadows[i]=s;
   }
}
void Candidate(const M5Setup &s,const M1Pattern &p,const MqlTick &tick)
{
   double anchor=InpResearchStopMode==2?s.origin_low.price:(InpResearchStopMode==1?p.reversal_low.price:p.hl.price);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double sl=NormalizeDouble(MathFloor((anchor-InpResearchBufferPoints*_Point)/step)*step,_Digits);
   double risk=tick.ask-sl;
   string status="OK";
   double stops=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   if(tick.bid<p.hl.price || tick.bid<p.reversal_low.price || tick.bid<s.origin_low.price) status="STRUCTURE_BROKEN_ON_ENTRY_TICK";
   else if(risk<=0 || sl<=0) status="INVALID_GEOMETRY";
   else if(tick.bid-sl+step*1e-6<stops) status="BROKER_STOPS_DISTANCE";
   string id=ID(s,p);
   FileWrite(fc,id,(long)s.break_time,(long)p.choch_time,(long)(p.ready_time+60),tick.time_msc,phase.name,status,tick.ask,tick.bid,sl,risk,
      InpSkipLowerHL?"CHOCH":"READY",s.origin_low.price,(long)s.origin_low.bar_time,(long)s.origin_low.confirmed_time,
      s.wave1_high.price,(long)s.wave1_high.bar_time,(long)s.wave1_high.confirmed_time,
      p.reversal_low.price,(long)p.reversal_low.bar_time,(long)p.reversal_low.confirmed_time,
      p.hl.price,(long)p.hl.bar_time,(long)p.hl.confirmed_time,
      (long)phase.last,(long)phase.choch,phase.p0.price,(long)phase.p0.bar_time,(long)phase.p0.confirmed_time,
      phase.p1.price,(long)phase.p1.bar_time,(long)phase.p1.confirmed_time,
      phase.p2.price,(long)phase.p2.bar_time,(long)phase.p2.confirmed_time,(long)phase.w3);
   ENUM_TIMEFRAMES tfs[2]={PERIOD_H1,PERIOD_H4};
   for(int k=0;k<2;k++) for(int w=0;w<2;w++)
   {
      double price;datetime bar,confirmed;int available;
      Resistance(tfs[k],w==0?2:5,tick.ask,price,bar,confirmed,available);
      FileWrite(ff,id,EnumToString(tfs[k]),w==0?"SWING_2_2":"MAJOR_5_5",available,price>0?"FOUND":"NOT_FOUND_IN_800_BARS",
         price>0?DoubleToString(price,8):"",price>0 && risk>0?DoubleToString((price-tick.ask)/risk,12):"",(long)bar,(long)confirmed,tick.time_msc);
   }
   candidates++;
   if(status!="OK") return;
   Shadow x={};x.id=id;x.ph=phase.name;x.start=tick.time_msc;x.entry=tick.ask;x.sl=sl;x.risk=risk;
   for(int j=0;j<4;j++){x.tp[j]=NormalizeDouble(MathRound((x.entry+x.risk*multiples[j])/step)*step,_Digits);x.status[j]="END_CENSORED";}
   int n=ArraySize(shadows);ArrayResize(shadows,n+1);shadows[n]=x;
}
int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER) || _Symbol!="USDJPY" || _Period!=PERIOD_M1 || InpLowerTF!=PERIOD_M1 || InpHigherTF!=PERIOD_M5) return INIT_PARAMETERS_INCORRECT;
   fc=FileOpen("MP_candidates.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   fo=FileOpen("MP_outcomes.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   ff=FileOpen("MP_resistance.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   fb=FileOpen("MP_m1.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   phase_file=FileOpen("MP_phases.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(fc==INVALID_HANDLE || fo==INVALID_HANDLE || ff==INVALID_HANDLE || fb==INVALID_HANDLE || phase_file==INVALID_HANDLE) return INIT_FAILED;
   FileWrite(fc,"id","parent","attempt","signal_time","entry_msc","phase","status","entry","bid","sl","risk","stage",
      "m5_p0","m5_p0_bar","m5_p0_confirmed","m5_p1","m5_p1_bar","m5_p1_confirmed",
      "m1_l0","m1_l0_bar","m1_l0_confirmed","m1_l1","m1_l1_bar","m1_l1_confirmed",
      "phase_asof","phase_choch","phase_p0","phase_p0_bar","phase_p0_confirmed","phase_p1","phase_p1_bar","phase_p1_confirmed",
      "phase_p2","phase_p2_bar","phase_p2_confirmed","phase_w3");
   FileWrite(fo,"id","phase","rr","entry_msc","exit_msc","entry","sl","tp","risk","outcome","result_r","mfe_to_exit","mae_to_exit","mfe_until_sl_or_24h","mae_until_sl_or_24h","path_complete","path_last_msc");
   FileWrite(ff,"id","tf","kind","bars","status","price","distance_r","bar","confirmed","asof_msc");
   FileWrite(fb,"time","open","high","low","close");
   FileWrite(phase_file,"asof","phase","reason","bar","open","high","low","close","choch","p0","p0_bar","p0_confirmed","h0","h0_bar","h0_confirmed","p1","p1_bar","p1_confirmed","p2","p2_bar","p2_confirmed","w3");
   PhaseReset("INIT");last_bar=iTime(_Symbol,PERIOD_M1,0);
   return INIT_SUCCEEDED;
}
void OnTick()
{
   MqlTick tick={};if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0 || tick.ask<=0) return;
   TickShadows(tick);
   datetime now=iTime(_Symbol,PERIOD_M1,0);if(now==last_bar || now<=0) return;
   last_bar=now;
   if(!PhaseUpdate(now)){skips++;return;}
   MqlRates lower[],higher[];
   int n=CopyRates(_Symbol,PERIOD_M1,0,InpHistoryLowerBars,lower);
   if(n<100 || lower[n-1].time!=now){skips++;return;}
   for(int i=0;i<n-1;i++) if(lower[i].time>last_export)
      FileWrite(fb,(long)lower[i].time,lower[i].open,lower[i].high,lower[i].low,lower[i].close);
   last_export=lower[n-2].time;
   datetime parent=iTime(_Symbol,PERIOD_M5,0);
   if(parent!=last_parent || InpAuditFullRebuild)
   {
      int hn=CopyRates(_Symbol,PERIOD_M5,0,InpHistoryHigherBars,higher);
      if(hn<100 || higher[hn-1].time!=parent){skips++;return;}
      PivotPoint hp[];tw_trace_from=now;ArrayResize(tw_events,0);
      BuildPivots(higher,PERIOD_M5,InpHigherLeftBars,InpHigherRightBars,hp);
      BuildHigherSetups(higher,hp,cached);last_parent=parent;
   }
   PivotPoint lp[];BuildPivots(lower,PERIOD_M1,InpLowerLeftBars,InpLowerRightBars,lp);
   tw_trace_from=now;ArrayResize(tw_events,0);
   for(int i=0;i<ArraySize(cached);i++)
   {
      if(now>cached[i].wave1_high.bar_time+InpMaxSetupMinutes*60+60) continue;
      M1Pattern p;AnalyzeLowerPattern(lower,lp,cached[i],p);
      if(p.ready && p.ready_time+60==now) Candidate(cached[i],p,tick);
   }
   TickShadows(tick);
}
void OnDeinit(const int reason)
{
   for(int i=0;i<ArraySize(shadows);i++) WriteShadow(shadows[i]);
   FileClose(fc);FileClose(fo);FileClose(ff);FileClose(fb);FileClose(phase_file);
   Print("MP_RESULT candidates=",candidates," data_skips=",skips," orders_sent=0");
}
