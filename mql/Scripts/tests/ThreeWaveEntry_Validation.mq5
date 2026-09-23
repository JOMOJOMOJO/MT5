#property strict
#include "../../Include/ThreeWaveInputs.mqh"
int InpEntryResearchMode=0;
#include "../../Include/ThreeWaveEntryResearch.mqh"
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
void OnStart()
{
   MqlRates r[]; PivotPoint piv[]; M5Setup s; M1Pattern p;
   Fixture(r,piv,s); AnalyzeLowerPattern(r,piv,s,p);
   Check(p.ready && p.ready_time==base+11*60,"baseline retained");
   InpEntryResearchMode=1;
   Fixture(r,piv,s); AnalyzeLowerPattern(r,piv,s,p);
   Check(p.ready && p.ready_time==base+4*60 && !p.found_hl && !p.found_wave1_high,"fib50 CHoCH before future HL exists");
   Fixture(r,piv,s); ArrayResize(r,5); AnalyzeLowerPattern(r,piv,s,p);
   Check(!p.ready,"forming CHoCH excluded");
   Fixture(r,piv,s); s.origin_low.price=76; AnalyzeLowerPattern(r,piv,s,p);
   Check(p.ready,"exact 50 percent accepted");
   Fixture(r,piv,s); s.origin_low.price=75; AnalyzeLowerPattern(r,piv,s,p);
   Check(!p.ready,"less than 50 percent cannot fall back to old READY");
   Fixture(r,piv,s); r[2].low=89; AnalyzeLowerPattern(r,piv,s,p);
   Check(!p.ready,"origin breach before CHoCH blocks");
   Fixture(r,piv,s); r[1].close=121; AnalyzeLowerPattern(r,piv,s,p);
   Check(!p.ready,"prior M5 breakout blocks early CHoCH");
   Fixture(r,piv,s); piv[3].confirmed_time=base+6*60; AnalyzeLowerPattern(r,piv,s,p);
   Check(!p.ready,"unconfirmed downtrend low cannot trigger");
   InpEntryResearchMode=2;
   Fixture(r,piv,s); AnalyzeLowerPattern(r,piv,s,p);
   Check(p.ready && p.ready_time==base+10*60 && p.hl.confirmed_time==base+11*60,"HL entry at confirmation without price break");
   Fixture(r,piv,s); ArrayResize(r,11); AnalyzeLowerPattern(r,piv,s,p);
   Check(!p.ready,"HL confirmation forming bar excluded");
   Fixture(r,piv,s); r[10].low=102; AnalyzeLowerPattern(r,piv,s,p);
   Check(!p.ready,"broken HL cannot enter on confirmation");
   Fixture(r,piv,s); r[6].close=121; AnalyzeLowerPattern(r,piv,s,p);
   Check(!p.ready,"prior M5 breakout blocks HL entry");
   Fixture(r,piv,s); r[9].low=89; AnalyzeLowerPattern(r,piv,s,p);
   Check(!p.ready,"origin breach blocks HL entry");
   for(int mode=0;mode<=2;mode++)
   {
      InpEntryResearchMode=mode; Fixture(r,piv,s); AnalyzeLowerPattern(r,piv,s,p);
      datetime issued=p.ready_time;
      int n=ArraySize(r); ArrayResize(r,n+2); r[n]=r[n-1]; r[n].time+=60; r[n].low=80;
      r[n+1]=r[n]; r[n+1].time+=60; AnalyzeLowerPattern(r,piv,s,p);
      Check(p.ready && p.ready_time==issued,"future suffix cannot change issued signal mode="+IntegerToString(mode));
   }
   Print("TW_ENTRY_UNIT_RESULT checks=",checks," failures=",failures);
}
