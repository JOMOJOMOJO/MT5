#ifndef SS_HL_FIB50_MQH
#define SS_HL_FIB50_MQH
#include "ConfirmedPivot.mqh"

enum HFState
{
   WAIT_FOR_STRUCTURE,BULLISH_STRUCTURE_CONFIRMED,WAIT_FOR_M1_BREAKOUT,
   BREAKOUT_CONFIRMED,WAIT_FOR_50_PERCENT_PULLBACK,BUY_LIMIT_PLACED,
   POSITION_OPEN,COOLDOWN,STRUCTURE_CONSUMED,INVALIDATED,RECOVERY_BLOCKED
};
struct HFStructure
{
   SSPivot old_low;
   SSPivot new_low;
   SSPivot reference_high;
   SSPivot breakout_high;
   datetime cross_time;
   datetime scanned;
   bool valid;
};
struct HFPlan
{
   datetime structure_id;
   datetime placed;
   double low;
   double entry;
   double sl;
   double tp;
   double volume;
   double loss;
   SSPivot old_low;
   SSPivot new_low;
   SSPivot reference_high;
   SSPivot breakout_high;
   datetime cross_time;
};

bool HFBuild(const SSPivot &p[],const datetime now,HFStructure &s,string &build_reason)
{
   ZeroMemory(s);
   int recent=-1,older=-1;
   for(int i=ArraySize(p)-1;i>=0;i--)
   {
      if(p[i].high || p[i].confirmed_time>now) continue;
      if(recent<0) recent=i;
      else { older=i; break; }
   }
   if(recent<0 || older<0) { build_reason="NEED_TWO_M5_LOWS"; return false; }
   s.old_low=p[older]; s.new_low=p[recent];
   // Freeze to information known when the newer low became available.
   for(int i=ArraySize(p)-1;i>=0;i--)
      if(p[i].high && p[i].confirmed_time<=s.new_low.confirmed_time)
      { s.reference_high=p[i]; break; }
   if(s.old_low.ambiguous || s.new_low.ambiguous || s.reference_high.ambiguous)
   { build_reason="AMBIGUOUS_M5_PIVOT"; return false; }
   if(s.new_low.price<=s.old_low.price) { build_reason="NOT_HIGHER_LOW"; return false; }
   if(s.reference_high.bar_time==0 || s.reference_high.price<=s.new_low.price)
   { build_reason="NO_VALID_REFERENCE_HIGH"; return false; }
   s.valid=true; build_reason="HIGHER_LOW_CONFIRMED";
   return true;
}

bool HFCross(const MqlRates &previous,const MqlRates &bar,const HFStructure &s)
{
   return bar.time>=s.new_low.confirmed_time &&
          bar.high>s.reference_high.price &&
          (bar.open<=s.reference_high.price || previous.close<=s.reference_high.price);
}

bool HFEligibleHigh(const SSPivot &p,const HFStructure &s,const datetime now)
{
   return p.high && !p.ambiguous && s.cross_time>0 &&
          p.bar_time>=s.cross_time && p.bar_time>=s.new_low.confirmed_time &&
          p.confirmed_time==now && p.price>s.reference_high.price;
}

double HFFloor(const double value,const double step)
{
   if(step<=0) return 0;
   return MathFloor(value/step+1e-9)*step;
}
#endif
