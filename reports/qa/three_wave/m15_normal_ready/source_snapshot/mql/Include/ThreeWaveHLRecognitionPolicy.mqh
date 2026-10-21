#ifndef THREE_WAVE_HL_RECOGNITION_POLICY
#define THREE_WAVE_HL_RECOGNITION_POLICY
#include "ThreeWaveStructure.mqh"
enum HLRecognitionMode { HL_ORIGINAL=0, HL_RIGHT_ONE=1, HL_PRICE_REVERSAL=2 };
input HLRecognitionMode InpHLRecognitionMode=HL_RIGHT_ONE;

struct HLRecognitionEvent
{
   string event;
   datetime time,parent,choch,wave1,wave1_known,hl;
   double price,threshold,close;
};
HLRecognitionEvent hl_rec_events[];

void HLRecord(const string event,const datetime now,const M5Setup &s,const M1Pattern &p,
              const double threshold,const double close)
{
   if(now<tw_trace_from) return;
   int n=ArraySize(hl_rec_events); ArrayResize(hl_rec_events,n+1);
   hl_rec_events[n].event=event; hl_rec_events[n].time=now;
   hl_rec_events[n].parent=s.break_time; hl_rec_events[n].choch=p.choch_time;
   hl_rec_events[n].wave1=p.wave1_high.bar_time; hl_rec_events[n].wave1_known=p.wave1_high.confirmed_time;
   hl_rec_events[n].hl=p.hl.bar_time; hl_rec_events[n].price=p.hl.price;
   hl_rec_events[n].threshold=threshold; hl_rec_events[n].close=close;
}

// Only HL recognition differs. Generic pivots and all high recognition remain shared.
bool ResearchHL(const HLRecognitionMode mode,const MqlRates &r[],const int i,const M1Pattern &p,
                int &candidate,int &emitted,datetime &wave_key,PivotPoint &result,double &threshold)
{
   if(i<0 || i>=ArraySize(r)-1) return false;
   datetime now=BarCloseTime(r[i],InpLowerTF);
   if(!p.found_wave1_high || now<p.wave1_high.confirmed_time) return false;
   int j=-1;
   if(mode==HL_RIGHT_ONE)
   {
      j=i-1;
      // Match Shared tie policy: strictly lower than left, <= right.
      if(j<InpLowerLeftBars || r[j].time<=p.wave1_high.bar_time ||
         !IsPivotLow(r,j,InpLowerLeftBars,1)) return false;
      threshold=0;
   }
   else if(mode==HL_PRICE_REVERSAL)
   {
      if(wave_key!=p.wave1_high.bar_time)
      {
         wave_key=p.wave1_high.bar_time; candidate=-1; emitted=-1;
         for(int k=FindRateIndexAtOrAfter(r,wave_key)+1;k<=i;k++)
            if(k>=1 && (candidate<0 || r[k].low<r[candidate].low)) candidate=k;
      }
      else if(candidate<0 || r[i].low<r[candidate].low) candidate=i;
      j=candidate;
      if(j<1 || j==emitted) return false;
      // Freeze the high of the bar immediately before the candidate low.
      threshold=r[j-1].high;
      if(r[i].close<=threshold) return false;
   }
   else return false;
   if(r[j].time<=p.wave1_high.bar_time || r[j].low<=p.reversal_low.price) return false;
   ZeroMemory(result); result.bar_time=r[j].time; result.plot_time=r[j].time;
   result.confirmed_time=now; result.price=r[j].low; result.high=false; result.bar_index=j;
   if(mode==HL_PRICE_REVERSAL) emitted=j;
   return true;
}
#endif
