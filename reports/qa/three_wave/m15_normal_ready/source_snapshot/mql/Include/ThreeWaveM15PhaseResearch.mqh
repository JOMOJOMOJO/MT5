// Research only. Persistent causal M15 state, fixed 2/2 wick pivots.
#ifndef TW_M15_PHASE_RESEARCH
#define TW_M15_PHASE_RESEARCH
struct PhaseState
{
   string name,reason;
   PivotPoint h1,h2,l1,l2,p0,h0,p1,p2;
   bool hh1,hh2,ll1,ll2;
   datetime choch,w3,last;
};
PhaseState phase;
int phase_file=INVALID_HANDLE;
void PhaseReset(const string why)
{
   datetime last=phase.last;
   ZeroMemory(phase);phase.name="RANGE_UNKNOWN";phase.reason=why;phase.last=last;
}
void PhaseBar(const MqlRates &r[],int i,bool write)
{
   datetime now=r[i].time+900;phase.last=now;phase.reason="HOLD";
   bool active=phase.name=="WAVE1_UP" || phase.name=="WAVE2_PULLBACK" || phase.name=="WAVE3_UP";
   bool invalid=active && (r[i].close<phase.p0.price || (phase.p2.bar_time>0 && r[i].close<phase.p2.price));
   if(invalid) PhaseReset("ORIGIN_OR_CONFIRMED_HL_BROKEN");
   int k=i-2;
   if(!invalid && k>=2)
   {
      for(int side=0;side<2;side++)
      {
         bool high=side==0;
         if(!(high?IsPivotHigh(r,k,2,2):IsPivotLow(r,k,2,2))) continue;
         PivotPoint p={};p.high=high;p.bar_time=r[k].time;p.confirmed_time=now;
         p.price=high?r[k].high:r[k].low;
         if(high) PushLastTwo(p,phase.h1,phase.h2,phase.hh1,phase.hh2);
         else PushLastTwo(p,phase.l1,phase.l2,phase.ll1,phase.ll2);
         if(phase.name=="WAVE1_UP" && high && p.bar_time>phase.choch && p.price>phase.h0.price)
         {phase.p1=p;phase.name="WAVE2_PULLBACK";phase.reason="P1_CONFIRMED";}
         else if(phase.name=="WAVE2_PULLBACK" && !high && phase.p2.bar_time==0 && p.bar_time>phase.p1.bar_time && p.price>phase.p0.price)
         {
            // A low already broken during its confirmation window is not a live HL.
            bool intact=true;for(int j=k+1;j<=i;j++) if(r[j].low<p.price) intact=false;
            if(intact){phase.p2=p;phase.reason="P2_CONFIRMED";}
         }
         else if(phase.name=="WAVE3_UP" && high && p.bar_time>phase.w3)
         {PhaseReset("WAVE3_FIRST_HIGH_CONFIRMED");}
      }
   }
   if(!invalid && phase.name=="WAVE2_PULLBACK" && r[i].close>phase.p1.price)
   {
      if(phase.p2.bar_time>0)
      {phase.name="WAVE3_UP";phase.w3=r[i].time;phase.reason="FIXED_P1_CLOSE_BREAK";}
      else PhaseReset("P1_BREAK_WITHOUT_CONFIRMED_P2");
   }
   if(!invalid && (phase.name=="DOWN" || phase.name=="RANGE_UNKNOWN" || phase.name==""))
   {
      bool down=phase.hh1 && phase.hh2 && phase.ll1 && phase.ll2 && phase.h2.price<phase.h1.price && phase.l2.price<phase.l1.price;
      phase.name=down?"DOWN":"RANGE_UNKNOWN";
      if(down && r[i].close>phase.h2.price && r[i].close>=phase.l2.price)
      {
         phase.p0=phase.l2;phase.h0=phase.h2;phase.choch=r[i].time;
         ZeroMemory(phase.p1);ZeroMemory(phase.p2);phase.w3=0;
         phase.name="WAVE1_UP";phase.reason="H0_CLOSE_BREAK";
      }
   }
   if(write) FileWrite(phase_file,(long)now,phase.name,phase.reason,(long)r[i].time,r[i].open,r[i].high,r[i].low,r[i].close,
      (long)phase.choch,phase.p0.price,(long)phase.p0.bar_time,(long)phase.p0.confirmed_time,
      phase.h0.price,(long)phase.h0.bar_time,(long)phase.h0.confirmed_time,
      phase.p1.price,(long)phase.p1.bar_time,(long)phase.p1.confirmed_time,
      phase.p2.price,(long)phase.p2.bar_time,(long)phase.p2.confirmed_time,(long)phase.w3);
}
bool PhaseUpdate(datetime now)
{
   if(phase.last>0 && now<phase.last+900) return true;
   MqlRates r[];int n=CopyRates(_Symbol,PERIOD_M15,1,phase.last==0?8000:16,r);
   if(n<8) return false;
   for(int i=0;i<n;i++) if(r[i].time+900>phase.last && r[i].time+900<=now) PhaseBar(r,i,true);
   // After weekends / quote gaps the previous bar's close need not equal
   // the current bar's open. Retain the latest genuinely closed state.
   return phase.last==r[n-1].time+900 && phase.last<=now;
}
// Nearest still-unbroken wick high, including the known partial bar high.
// 2/2 ordinary swing; 5/5 'major' is an explicit scale definition, not discretion.
void Resistance(ENUM_TIMEFRAMES tf,int width,double ask,double &price,datetime &bar,datetime &confirmed,int &available)
{
   price=0;bar=0;confirmed=0;MqlRates r[];int n=CopyRates(_Symbol,tf,0,800,r);available=n;
   double after=-DBL_MAX;
   for(int i=n-1;i>=0;i--)
   {
      if(i>=width && i+width<n-1 && IsPivotHigh(r,i,width,width) && r[i].high>=ask && after<=r[i].high)
      {
         if(price==0 || r[i].high<price)
         {price=r[i].high;bar=r[i].time;confirmed=r[i+width].time+PeriodSeconds(tf);}
      }
      after=MathMax(after,r[i].high);
   }
}
#endif
