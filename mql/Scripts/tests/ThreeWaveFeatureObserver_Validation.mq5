#property strict
#include "../../Include/ThreeWaveInputs.mqh"
#include "../../Include/ThreeWaveFeatureObserver.mqh"
#include "ThreeWaveOriginalOracle.mqh"
int checks=0,failures=0;
datetime base=D'2025.03.03 00:00';
void Check(const bool ok,const string label)
{ checks++; if(!ok) failures++; Print(ok ? "PASS " : "FAIL ",label); }
PivotPoint P(const int at,const int confirmed,const double price,const bool high,const int seconds=60)
{
   PivotPoint p={}; p.bar_time=base+at*seconds; p.plot_time=p.bar_time;
   p.confirmed_time=base+confirmed*seconds; p.price=price; p.high=high; return p;
}
void Rates(MqlRates &r[],const int n,const int seconds=60)
{
   ArrayResize(r,n);
   for(int i=0;i<n;i++) { ZeroMemory(r[i]); r[i].time=base+i*seconds; r[i].open=105; r[i].high=107; r[i].low=104; r[i].close=105; }
}
void Fixture(MqlRates &r[],PivotPoint &p[],M5Setup &s)
{
   Rates(r,13); ArrayResize(p,7);
   p[0]=P(0,1,110,true); p[1]=P(1,2,100,false); p[2]=P(2,3,108,true); p[3]=P(3,4,98,false);
   p[4]=P(5,8,112,true); p[5]=P(7,10,110,true); p[6]=P(8,11,103,false);
   r[4].close=109; r[4].high=110; r[5].high=112; r[7].high=110; r[8].low=103;
   r[11].close=111; r[11].high=111;
   ZeroMemory(s); s.valid=true; s.break_time=base-300; s.origin_low=P(-5,-3,90,false);
   s.wave1_high=P(0,1,120,true); s.broken_high=P(-10,-8,115,true);
}
void TWFeatureCandidate(const M5Setup &s,const M1Pattern &p,datetime when,string stage) {}
void OnStart()
{
   MqlRates r[]; PivotPoint piv[]; M5Setup s; M1Pattern p;
   Fixture(r,piv,s); AnalyzeLowerPattern(r,piv,s,p);
   Check(p.ready && p.early_break && p.ready_time==base+11*60,"closed Wave2 return-high break READY");
   Check(p.reversal_low.price==98 && p.hl.price==103,"frozen reversal and current HL retained");
   Check(p.hl.confirmed_time<=p.ready_time+60,"HL available by READY close");
   Fixture(r,piv,s); r[1].close=121; r[1].high=121;
   AnalyzeLowerPattern(r,piv,s,p);
   Check(!p.ready,"M5 breakout before M1 CHoCH permanently expires setup");
   Fixture(r,piv,s); r[6].close=121; r[6].high=121;
   AnalyzeLowerPattern(r,piv,s,p);
   Check(!p.ready,"M5 breakout while waiting HL expires setup");
   Fixture(r,piv,s); s.wave1_high.price=109; r[10].close=110; r[10].high=110;
   AnalyzeLowerPattern(r,piv,s,p);
   Check(!p.ready,"M5 breakout after HL but before M1 trigger expires setup");
   Fixture(r,piv,s); r[11].close=121; r[11].high=121;
   AnalyzeLowerPattern(r,piv,s,p);
   Check(p.ready,"first M5 breakout simultaneous with M1 READY is allowed");
   Fixture(r,piv,s); r[1].high=121;
   AnalyzeLowerPattern(r,piv,s,p);
   Check(p.ready,"wick-only M5 touch does not expire close-break setup");
   Fixture(r,piv,s); r[1].close=120; r[1].high=120;
   AnalyzeLowerPattern(r,piv,s,p);
   Check(p.ready,"equal M5 close is not a strict breakout");
   Fixture(r,piv,s); r[6].close=121; r[6].high=121; r[6].low=97;
   AnalyzeLowerPattern(r,piv,s,p);
   Check(!p.ready,"M1 reversal reset cannot bypass simultaneous M5 breakout");
   Fixture(r,piv,s);
   r[11].close=109; AnalyzeLowerPattern(r,piv,s,p);
   Check(!p.ready,"intrabar high alone cannot produce close-break READY");
   Fixture(r,piv,s); piv[5].price=113; r[11].close=113; r[11].high=114;
   AnalyzeLowerPattern(r,piv,s,p); Check(p.ready && !p.early_break,"no lower return high uses Wave1-high fallback");
   Fixture(r,piv,s); ArrayResize(r,12); AnalyzeLowerPattern(r,piv,s,p);
   Check(!p.ready,"forming signal bar is excluded");
   Fixture(r,piv,s); piv[6].confirmed_time=base+13*60; AnalyzeLowerPattern(r,piv,s,p);
   Check(!p.ready,"unconfirmed HL cannot trigger READY");
   Fixture(r,piv,s); r[11].low=102; AnalyzeLowerPattern(r,piv,s,p);
   Check(!p.ready && !p.found_hl,"HL breach clears stale HL before same-bar breakout");
   ArrayResize(r,16);
   for(int i=13;i<16;i++) { r[i]=r[10]; r[i].time=base+i*60; }
   ArrayResize(piv,8); piv[7]=P(11,14,102,false);
   r[14].close=111; r[14].high=111;
   AnalyzeLowerPattern(r,piv,s,p);
   Check(p.ready && p.hl.price==102 && p.ready_time==base+14*60,"HL breach permits a NEW confirmed deeper HL");
   Fixture(r,piv,s); r[8].low=97; AnalyzeLowerPattern(r,piv,s,p);
   Check(!p.ready && !p.found_choch,"reversal breach cannot reuse old Wave1 or old downtrend");
   ArrayResize(r,24);
   for(int i=9;i<24;i++) { r[i]=r[0]; r[i].time=base+i*60; }
   ArrayResize(piv,14);
   piv[7]=P(9,12,111,true); piv[8]=P(10,13,95,false);
   piv[9]=P(11,14,109,true); piv[10]=P(12,15,94,false);
   piv[11]=P(16,19,113,true); piv[12]=P(18,21,111,true); piv[13]=P(19,22,98,false);
   r[10].low=95; r[12].low=94; r[15].close=110; r[15].high=111;
   r[16].high=113; r[18].high=111; r[19].low=98; r[22].close=112; r[22].high=112;
   AnalyzeLowerPattern(r,piv,s,p);
   Check(p.ready && p.reversal_low.price==94 && p.hl.price==98 && p.choch_time==base+15*60,
         "same valid M5 Wave2 restarts from fresh M1 downtrend after reversal failure");
   Fixture(r,piv,s); r[4].low=97; AnalyzeLowerPattern(r,piv,s,p);
   Check(!p.ready && !p.found_choch,"CHoCH bar that breaks reversal origin cannot arm");
   Fixture(r,piv,s); r[9].low=89; AnalyzeLowerPattern(r,piv,s,p);
   Check(!p.ready && !p.found_choch,"M5 origin breach clears lower setup");
   Fixture(r,piv,s); s.wave1_high.confirmed_time=base+5*60; r[2].low=89;
   AnalyzeLowerPattern(r,piv,s,p);
   Check(!p.ready && !p.found_choch,"M5 origin breached during high confirmation cannot resurrect");

   Rates(r,5); r[2].high=115; BuildPivots(r,PERIOD_M1,2,2,piv);
   Check(ArraySize(piv)==0,"right confirmation forming bar excluded from pivot engine");
   Rates(r,7); r[2].high=115; r[3].high=115; BuildPivots(r,PERIOD_M1,2,2,piv);
   Check(ArraySize(piv)==1 && piv[0].bar_time==base+120 && piv[0].confirmed_time==base+300,"v1.05 right-side equal tie policy preserved");

   Rates(r,10,300); ArrayResize(piv,5);
   piv[0]=P(0,1,110,true,300); piv[1]=P(1,2,100,false,300);
   piv[2]=P(2,3,108,true,300); piv[3]=P(3,4,95,false,300); piv[4]=P(5,8,112,true,300);
   r[4].close=109; r[4].high=110; r[7].low=94;
   M5Setup setups[]; BuildHigherSetups(r,piv,setups);
   Check(ArraySize(setups)==0,"M5 origin invalidation precedes Wave1 confirmation on same close");
   r[7].low=104; BuildHigherSetups(r,piv,setups);
   Check(ArraySize(setups)==1,"valid M5 downtrend CHoCH high creates Wave2");

   // Append-only causality: future suffix cannot move an already-issued signal.
   Fixture(r,piv,s); AnalyzeLowerPattern(r,piv,s,p); datetime issued=p.ready_time;
   int n=ArraySize(r); ArrayResize(r,n+2); r[n]=r[n-1]; r[n].time=base+n*60; r[n].low=80;
   r[n+1]=r[n]; r[n+1].time+=60; AnalyzeLowerPattern(r,piv,s,p);
   Check(p.ready && p.ready_time==issued,"future invalidation does not erase an issued historical signal");
   Print("TW_FEATURE_OBSERVER_UNIT_RESULT checks=",checks," failures=",failures);
}
