#property strict
#property version "1.00"
#property description "Tester-only, no-order candidate feature and shadow-outcome recorder."
#include "../Include/ThreeWaveInputs.mqh"
#include "../Include/ThreeWaveFeatureObserver.mqh"

int f_candidates=INVALID_HANDLE,f_outcomes=INVALID_HANDLE;
int h_ema=INVALID_HANDLE,h_atr=INVALID_HANDLE,h_adx=INVALID_HANDLE,h_m1atr=INVALID_HANDLE;
datetime last_bar=0,observed_close=0;
MqlRates source_m1[],source_m5[];
PivotPoint source_hp[];
string seen[];
int candidates=0,feature_errors=0,data_skips=0;
struct Shadow
{
   string id,basis,outcome;
   long entry_msc,exit_msc,last60;
   double entry,sl,tp,risk,result,mfe,mae,mfe60,mae60;
   bool done,horizon_done;
};
Shadow active[];

string TS(datetime t) { return t>0 ? TimeToString(t,TIME_DATE|TIME_SECONDS) : ""; }
string V(double x) { return MathIsValidNumber(x) && MathAbs(x)<1e100 ? DoubleToString(x,12) : ""; }
double ReadValue(int handle,int buffer,int shift)
{
   double v[1];
   if(shift<1 || CopyBuffer(handle,buffer,shift,1,v)!=1 || !MathIsValidNumber(v[0])) return EMPTY_VALUE;
   return v[0];
}
bool Good(double x) { return MathIsValidNumber(x) && MathAbs(x)<1e100; }
double ER(const MqlRates &r[],datetime from,datetime to,double &net)
{
   net=EMPTY_VALUE; int a=-1,b=-1;
   for(int i=0;i<ArraySize(r)-1;i++)
   { if(r[i].time==from) a=i; if(r[i].time==to) b=i; }
   if(a<0 || b<=a) return EMPTY_VALUE;
   double path=0;
   for(int i=a+1;i<=b;i++) path+=MathAbs(r[i].close-r[i-1].close);
   net=r[b].close-r[a].close;
   return path>0 ? MathAbs(net)/path : EMPTY_VALUE;
}
void WriteOutcome(const Shadow &x,bool complete)
{
   FileWrite(f_outcomes,x.id,x.basis,x.entry_msc,x.exit_msc,V(x.entry),V(x.sl),V(x.tp),V(x.risk),
      x.outcome,V(x.done?x.result:EMPTY_VALUE),V(x.mfe),V(x.mae),
      V(complete?x.mfe60:EMPTY_VALUE),V(complete?x.mae60:EMPTY_VALUE),complete,x.last60);
}
void AddShadow(string id,string basis,double anchor,const MqlTick &tick)
{
   Shadow x={};x.id=id;x.basis=basis;x.outcome="OPEN";x.entry=tick.ask;x.entry_msc=tick.time_msc;
   double step=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   x.sl=NormalizeDouble(MathFloor((anchor-10*_Point)/step+1e-9)*step,_Digits);
   x.risk=x.entry-x.sl;x.tp=NormalizeDouble(MathRound((x.entry+x.risk)/step)*step,_Digits);
   if(anchor<=0 || x.risk<=0 || tick.bid<anchor || tick.bid<=x.sl)
   { x.outcome="INVALID_GEOMETRY";WriteOutcome(x,false);return; }
   int n=ArraySize(active);ArrayResize(active,n+1);active[n]=x;
}
void ObserveTick(const MqlTick &tick)
{
   for(int i=ArraySize(active)-1;i>=0;i--)
   {
      Shadow x=active[i];
      double up=(tick.bid-x.entry)/x.risk,down=-up;
      if(tick.time_msc<=x.entry_msc+3600000)
      { x.mfe60=MathMax(x.mfe60,up);x.mae60=MathMax(x.mae60,down);x.last60=tick.time_msc; }
      if(tick.time_msc>=x.entry_msc+3600000) x.horizon_done=true;
      if(!x.done)
      {
         x.mfe=MathMax(x.mfe,up);x.mae=MathMax(x.mae,down);
         if(tick.bid<=x.sl) { x.outcome="SL";x.result=up; }
         else if(tick.bid>=x.tp) { x.outcome="TP";x.result=(x.tp-x.entry)/x.risk; }
         else if(tick.time_msc>=x.entry_msc+14400000) { x.outcome="TIMEOUT";x.result=up; }
         if(x.outcome!="OPEN") { x.done=true;x.exit_msc=tick.time_msc; }
      }
      if(x.done && x.horizon_done)
      {
         WriteOutcome(x,true);
         int n=ArraySize(active);if(i<n-1) active[i]=active[n-1];ArrayResize(active,n-1);
      }
      else active[i]=x;
   }
}
void TWFeatureCandidate(const M5Setup &s,const M1Pattern &p,datetime close_time,string stage)
{
   if(close_time!=observed_close) return;
   string id=IntegerToString((long)s.break_time)+"/"+IntegerToString((long)p.choch_time)+"/"+stage+"/"+IntegerToString((long)close_time);
   for(int j=0;j<ArraySize(seen);j++) if(seen[j]==id) return;
   int ns=ArraySize(seen);ArrayResize(seen,ns+1);seen[ns]=id;
   MqlTick tick={};if(!SymbolInfoTick(_Symbol,tick)) return;
   int hc=ArraySize(source_m5),lc=ArraySize(source_m1);
   datetime feature_bar=source_m5[hc-2].time;
   int shift=iBarShift(_Symbol,PERIOD_M5,feature_bar,true);
   double ema=ReadValue(h_ema,0,shift),ema3=ReadValue(h_ema,0,shift+3),ema6=ReadValue(h_ema,0,shift+6);
   double atr=ReadValue(h_atr,0,shift),adx=ReadValue(h_adx,0,shift),plus=ReadValue(h_adx,1,shift),minus=ReadValue(h_adx,2,shift);
   double slope=EMPTY_VALUE,prior=EMPTY_VALUE,accel=EMPTY_VALUE,distance=EMPTY_VALUE;
   bool ok=shift>=1 && feature_bar+300<=close_time && Good(ema) && Good(ema3) && Good(ema6) && Good(atr) && atr>0 && Good(adx) && Good(plus) && Good(minus);
   if(ok)
   { slope=(ema-ema3)/(3*atr);prior=(ema3-ema6)/(3*atr);accel=slope-prior;distance=(source_m1[lc-2].close-ema)/atr; }
   int cs=iBarShift(_Symbol,PERIOD_M1,p.choch_time,true);
   double m1atr=ReadValue(h_m1atr,0,cs),strength=EMPTY_VALUE;
   if(Good(m1atr) && m1atr>0) strength=(p.choch_price-p.downtrend_return_high.price)/m1atr;
   else ok=false;
   datetime down_start=0;
   for(int j=0;j<ArraySize(source_hp);j++)
      if(source_hp[j].high && source_hp[j].bar_time<s.origin_low.bar_time && source_hp[j].confirmed_time<=close_time)
         down_start=source_hp[j].bar_time;
   double down_net,w1_net;
   double down_er=ER(source_m5,down_start,s.origin_low.bar_time,down_net);
   double w1_er=ER(source_m5,s.origin_low.bar_time,s.wave1_high.bar_time,w1_net);
   double low=DBL_MAX;
   for(int j=0;j<lc-1;j++)
      if(source_m1[j].time>=s.wave1_high.bar_time+300 && source_m1[j].time+60<=close_time)
         low=MathMin(low,source_m1[j].low);
   double range=s.wave1_high.price-s.origin_low.price;
   double retrace=(low<DBL_MAX && range>0 ? (s.wave1_high.price-low)/range : EMPTY_VALUE);
   double current_retrace=(range>0 ? (s.wave1_high.price-source_m1[lc-2].close)/range : EMPTY_VALUE);
   if(!ok) feature_errors++;
   FileWrite(f_candidates,id,stage,(long)s.break_time,(long)p.choch_time,TS(close_time),tick.time_msc,TS(feature_bar),TS(feature_bar+300),ok?"OK":"MISSING_INDICATOR",
      V(s.origin_low.price),TS(s.origin_low.bar_time),TS(s.origin_low.confirmed_time),V(s.wave1_high.price),TS(s.wave1_high.bar_time),TS(s.wave1_high.confirmed_time),
      V(p.downtrend_return_high.price),TS(p.downtrend_return_high.bar_time),TS(p.downtrend_return_high.confirmed_time),
      V(p.reversal_low.price),TS(p.reversal_low.bar_time),TS(p.reversal_low.confirmed_time),
      V(p.found_hl?p.hl.price:EMPTY_VALUE),TS(p.hl.bar_time),TS(p.hl.confirmed_time),TS(p.choch_time+60),
      V(tick.ask),V(tick.bid),V(ema),V(atr),V(slope),V(prior),V(accel),V(distance),V(adx),V(plus),V(minus),
      V(down_er),V(down_net),TS(down_start),V(w1_er),V(w1_net),V(retrace),V(current_retrace),
      (close_time-s.wave1_high.bar_time-300)/60.0,(close_time-s.wave1_high.confirmed_time)/60.0,V(strength),V(m1atr),V(ok?(tick.ask-tick.bid)/atr:EMPTY_VALUE),
      V(ema3),V(ema6),V(p.choch_price),V(source_m1[lc-2].close),V(p.found_wave1_high?p.wave1_high.price:EMPTY_VALUE),TS(p.wave1_high.bar_time),TS(p.wave1_high.confirmed_time));
   AddShadow(id,"STAGE",stage=="CHOCH"?p.reversal_low.price:p.hl.price,tick);
   AddShadow(id,"REVERSAL_CONTROL",p.reversal_low.price,tick);
   candidates++;
}
int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER) || _Symbol!="USDJPY" || _Period!=PERIOD_M1 || InpLowerTF!=PERIOD_M1 || InpHigherTF!=PERIOD_M5) return INIT_PARAMETERS_INCORRECT;
   h_ema=iMA(_Symbol,PERIOD_M5,20,0,MODE_EMA,PRICE_CLOSE);h_atr=iATR(_Symbol,PERIOD_M5,14);
   h_adx=iADX(_Symbol,PERIOD_M5,14);h_m1atr=iATR(_Symbol,PERIOD_M1,14);
   if(h_ema==INVALID_HANDLE || h_atr==INVALID_HANDLE || h_adx==INVALID_HANDLE || h_m1atr==INVALID_HANDLE) return INIT_FAILED;
   f_candidates=FileOpen("TW_features.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   f_outcomes=FileOpen("TW_feature_outcomes.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(f_candidates==INVALID_HANDLE || f_outcomes==INVALID_HANDLE) return INIT_FAILED;
   FileWrite(f_candidates,"id","stage","parent","attempt","signal_time","decision_msc","m5_feature_bar","m5_feature_close","feature_status",
      "m5_origin","m5_origin_time","m5_origin_confirmed","m5_high","m5_high_time","m5_high_confirmed",
      "m1_return","m1_return_time","m1_return_confirmed","m1_reversal","m1_reversal_time","m1_reversal_confirmed",
      "m1_hl","m1_hl_time","m1_hl_confirmed","choch_confirmed","entry_ask","entry_bid",
      "ema20","atr14","ema_slope_atr","ema_prior_slope_atr","ema_deceleration","ema_distance_atr","adx14","plus_di","minus_di",
      "down_er","down_net","down_start","wave1_er","wave1_net","wave2_retracement","wave2_current_retracement",
      "wave2_minutes","wave2_known_minutes","choch_break_strength","choch_atr_m1","spread_atr",
      "ema_lag3","ema_lag6","choch_close","signal_close","m1_wave1_high","m1_wave1_time","m1_wave1_confirmed");
   FileWrite(f_outcomes,"id","stop_basis","entry_msc","exit_msc","entry","sl","tp","risk","outcome","result_R","mfe_exit_R","mae_exit_R","mfe60_R","mae60_R","complete60","last_tick60");
   last_bar=iTime(_Symbol,PERIOD_M1,0);
   return INIT_SUCCEEDED;
}
void OnTick()
{
   MqlTick tick={};if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0 || tick.ask<=0) return;
   ObserveTick(tick);
   datetime now=iTime(_Symbol,PERIOD_M1,0);
   if(now==last_bar || now<=0) return;
   last_bar=now;observed_close=now;
   int lc=CopyRates(_Symbol,PERIOD_M1,0,InpHistoryLowerBars,source_m1);
   int hc=CopyRates(_Symbol,PERIOD_M5,0,InpHistoryHigherBars,source_m5);
   if(lc<100 || hc<100 || source_m1[lc-1].time!=now || source_m5[hc-1].time>now || now>=source_m5[hc-1].time+300)
   {data_skips++;return;}
   ArrayResize(tw_events,0);tw_trace_from=now;
   PivotPoint lp[];M5Setup setups[];
   BuildPivots(source_m1,PERIOD_M1,InpLowerLeftBars,InpLowerRightBars,lp);
   BuildPivots(source_m5,PERIOD_M5,InpHigherLeftBars,InpHigherRightBars,source_hp);
   BuildHigherSetups(source_m5,source_hp,setups);
   for(int i=0;i<ArraySize(setups);i++)
   {
      M1Pattern p;AnalyzeLowerPattern(source_m1,lp,setups[i],p);
      if(p.ready && p.ready_time+60==now) TWFeatureCandidate(setups[i],p,now,"READY");
   }
   ObserveTick(tick); // Include entry spread on the same tick, without affecting candidate generation.
}
void OnDeinit(const int reason)
{
   for(int i=0;i<ArraySize(active);i++)
   { if(!active[i].done) active[i].outcome="END_CENSORED";WriteOutcome(active[i],active[i].horizon_done); }
   if(f_candidates!=INVALID_HANDLE) FileClose(f_candidates);
   if(f_outcomes!=INVALID_HANDLE) FileClose(f_outcomes);
   if(h_ema!=INVALID_HANDLE) IndicatorRelease(h_ema);
   if(h_atr!=INVALID_HANDLE) IndicatorRelease(h_atr);
   if(h_adx!=INVALID_HANDLE) IndicatorRelease(h_adx);
   if(h_m1atr!=INVALID_HANDLE) IndicatorRelease(h_m1atr);
   Print("TW_FEATURE_RESULT candidates=",candidates," feature_errors=",feature_errors," data_skips=",data_skips," orders_sent=0");
}
