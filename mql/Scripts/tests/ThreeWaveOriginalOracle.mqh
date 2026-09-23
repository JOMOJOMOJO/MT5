// TEST ONLY: unmodified user v1.05 engine with renamed identifiers.
struct OriginalPivotPoint
{
   datetime bar_time;       // source timeframe bar open time
   datetime plot_time;      // actual lower-TF extreme time used only for drawing
   datetime confirmed_time;
   double   price;
   bool     high;
   int      bar_index;
};

struct OriginalM5Setup
{
   bool       valid;
   OriginalPivotPoint origin_low;
   OriginalPivotPoint broken_high;
   datetime   break_time;
   double     break_price;
   OriginalPivotPoint wave1_high;
};

struct OriginalM1Pattern
{
   bool       found_choch;
   OriginalPivotPoint downtrend_return_high;
   OriginalPivotPoint reversal_low;
   datetime   choch_time;
   double     choch_price;

   bool       found_wave1_high;
   OriginalPivotPoint wave1_high;

   bool       found_hl;
   OriginalPivotPoint hl;
   OriginalPivotPoint pullback_lh;
   double     retrace;
   bool       fib_ok;

   bool       ready;
   datetime   ready_time;
   double     ready_price;
   bool       early_break;
};

int OriginalTFSeconds(const ENUM_TIMEFRAMES tf)
{
   int s=PeriodSeconds(tf);
   if(s<=0) s=60;
   return s;
}

datetime OriginalBarCloseTime(const MqlRates &bar,const ENUM_TIMEFRAMES tf)
{
   return bar.time+OriginalTFSeconds(tf);
}

bool OriginalIsPivotHigh(const MqlRates &r[],const int i,const int left,const int right)
{
   const double p=r[i].high;
   for(int k=1;k<=left;k++)  if(p<=r[i-k].high) return false;
   for(int k=1;k<=right;k++) if(p< r[i+k].high) return false;
   return true;
}

bool OriginalIsPivotLow(const MqlRates &r[],const int i,const int left,const int right)
{
   const double p=r[i].low;
   for(int k=1;k<=left;k++)  if(p>=r[i-k].low) return false;
   for(int k=1;k<=right;k++) if(p> r[i+k].low) return false;
   return true;
}

void OriginalAddPivot(OriginalPivotPoint &out[],const OriginalPivotPoint &p)
{
   int n=ArraySize(out);
   ArrayResize(out,n+1);
   out[n]=p;
}

void OriginalBuildPivots(const MqlRates &r[],const ENUM_TIMEFRAMES tf,const int left,const int right,OriginalPivotPoint &out[])
{
   ArrayResize(out,0);
   int n=ArraySize(r);
   if(n<left+right+3) return;

   for(int i=left;i<n-right;i++)
   {
      if(OriginalIsPivotHigh(r,i,left,right))
      {
         OriginalPivotPoint p={};
         p.bar_time=r[i].time;
         p.plot_time=r[i].time;
         p.confirmed_time=r[i+right].time+OriginalTFSeconds(tf);
         p.price=r[i].high;
         p.high=true;
         p.bar_index=i;
         OriginalAddPivot(out,p);
      }
      if(OriginalIsPivotLow(r,i,left,right))
      {
         OriginalPivotPoint p={};
         p.bar_time=r[i].time;
         p.plot_time=r[i].time;
         p.confirmed_time=r[i+right].time+OriginalTFSeconds(tf);
         p.price=r[i].low;
         p.high=false;
         p.bar_index=i;
         OriginalAddPivot(out,p);
      }
   }
}


// M5 OHLC only tells us that the extreme occurred somewhere inside the 5-minute bar.
// On an M1 chart, drawing at the M5 bar open can therefore look shifted by up to 4 minutes.
// This function moves only the DRAWING timestamp to the M1 bar that actually made the M5 high/low.
// Structural/confirmation logic continues to use bar_time and confirmed_time, so this does not add look-ahead.
void OriginalAlignHigherPivotPlotTimes(OriginalPivotPoint &pivots[],const MqlRates &lower[])
{
   int ln=ArraySize(lower);
   if(ln<=0) return;

   int li=0;
   for(int p=0;p<ArraySize(pivots);p++)
   {
      datetime from=pivots[p].bar_time;
      datetime to=from+OriginalTFSeconds(InpHigherTF);

      while(li<ln && lower[li].time<from) li++;

      int j=li;
      bool found=false;
      datetime bestTime=from;
      double bestPrice=(pivots[p].high ? -DBL_MAX : DBL_MAX);

      while(j<ln && lower[j].time<to)
      {
         if(pivots[p].high)
         {
            if(!found || lower[j].high>bestPrice)
            {
               bestPrice=lower[j].high;
               bestTime=lower[j].time;
               found=true;
            }
         }
         else
         {
            if(!found || lower[j].low<bestPrice)
            {
               bestPrice=lower[j].low;
               bestTime=lower[j].time;
               found=true;
            }
         }
         j++;
      }

      if(found)
         pivots[p].plot_time=bestTime;
      else
         pivots[p].plot_time=from;
   }
}

datetime OriginalPivotPlotTime(const OriginalPivotPoint &p)
{
   return (p.plot_time>0 ? p.plot_time : p.bar_time);
}

// A close-based break becomes knowable at the end of the signal bar.
// Keep the stored logical time unchanged, but draw it at the close boundary.
datetime OriginalCloseSignalPlotTime(const datetime bar_open,const ENUM_TIMEFRAMES tf)
{
   return bar_open+OriginalTFSeconds(tf);
}

void OriginalPushLastTwo(const OriginalPivotPoint &p,OriginalPivotPoint &older,OriginalPivotPoint &latest,bool &haveOlder,bool &haveLatest)
{
   if(haveLatest)
   {
      older=latest;
      haveOlder=true;
   }
   latest=p;
   haveLatest=true;
}

bool OriginalPriceBreakUp(const MqlRates &bar,const double level)
{
   if(InpRequireCloseBreak) return bar.close>level;
   return bar.high>level;
}

int OriginalFindRateIndexAtOrAfter(const MqlRates &r[],const datetime t)
{
   int n=ArraySize(r);
   for(int i=0;i<n;i++) if(r[i].time>=t) return i;
   return -1;
}

int OriginalFindRateIndexAtOrBefore(const MqlRates &r[],const datetime t)
{
   int n=ArraySize(r);
   for(int i=n-1;i>=0;i--) if(r[i].time<=t) return i;
   return -1;
}

void OriginalAddSetup(OriginalM5Setup &setups[],const OriginalM5Setup &s)
{
   int n=ArraySize(setups);
   ArrayResize(setups,n+1);
   setups[n]=s;
}

// M5 logic:
// 1) Require an objectively confirmed downtrend: latest two swing highs are lower AND latest two swing lows are lower.
// 2) A closed M5 bar breaks the latest confirmed lower high -> M5 Wave1 starts (CHoCH).
// 3) The first confirmed M5 swing high after that break is treated as the end of M5 Wave1 / start of Wave2.
void OriginalBuildHigherSetups(const MqlRates &r[],const OriginalPivotPoint &pivots[],OriginalM5Setup &setups[])
{
   ArrayResize(setups,0);
   OriginalPivotPoint h1={};
   OriginalPivotPoint h2={};
   OriginalPivotPoint l1={};
   OriginalPivotPoint l2={};
   bool hh1=false,hh2=false,ll1=false,ll2=false;
   int pidx=0;
   bool armed=false;
   OriginalPivotPoint armedOrigin={};
   OriginalPivotPoint armedBroken={};
   datetime armedBreak=0;
   double armedBreakPrice=0.0;

   int n=ArraySize(r);
   for(int i=0;i<n-1;i++) // ignore still-forming last bar
   {
      datetime close_time=OriginalBarCloseTime(r[i],InpHigherTF);

      while(pidx<ArraySize(pivots) && pivots[pidx].confirmed_time<=close_time)
      {
         const OriginalPivotPoint p=pivots[pidx];
         if(p.high) OriginalPushLastTwo(p,h1,h2,hh1,hh2);
         else       OriginalPushLastTwo(p,l1,l2,ll1,ll2);

         if(armed && p.high && p.bar_time>=armedBreak && p.price>armedBroken.price)
         {
            OriginalM5Setup s={};
            s.valid=true;
            s.origin_low=armedOrigin;
            s.broken_high=armedBroken;
            s.break_time=armedBreak;
            s.break_price=armedBreakPrice;
            s.wave1_high=p;
            OriginalAddSetup(setups,s);
            armed=false;
         }
         pidx++;
      }

      if(armed)
      {
         if(r[i].low<armedOrigin.price)
         {
            armed=false;
         }
         continue;
      }

      if(!(hh1 && hh2 && ll1 && ll2)) continue;
      bool downtrend=(h2.price<h1.price && l2.price<l1.price);
      if(!downtrend) continue;

      if(OriginalPriceBreakUp(r[i],h2.price) && close_time>=h2.confirmed_time)
      {
         armed=true;
         armedOrigin=l2;
         armedBroken=h2;
         armedBreak=r[i].time;
         armedBreakPrice=r[i].close;

         // Consume the current downtrend. A new setup requires a newly-established lower-high/lower-low structure.
         hh1=false; hh2=false; ll1=false; ll2=false;
      }
   }
}

bool OriginalPivotConfirmedBy(const OriginalPivotPoint &p,const datetime t)
{
   return p.confirmed_time<=t;
}

bool OriginalIsAfter(const OriginalPivotPoint &p,const datetime t)
{
   return p.bar_time>t;
}

// Analyze M1 only while the M5 Wave2 idea remains alive.
// We explicitly do NOT buy merely because price reaches 50%.
// Long-ready requires: M1 downtrend -> CHoCH -> M1 Wave1 high -> HL -> renewed upside break.
bool OriginalAnalyzeLowerPattern(const MqlRates &r[],const OriginalPivotPoint &pivots[],const OriginalM5Setup &s,OriginalM1Pattern &pat)
{
   ZeroMemory(pat);

   datetime start_time=s.wave1_high.bar_time;
   datetime knowledge_time=s.wave1_high.confirmed_time;
   datetime hard_end=start_time+InpMaxSetupMinutes*60;

   int start=OriginalFindRateIndexAtOrAfter(r,start_time);
   if(start<0) return false;

   // Generic M1 structure is maintained continuously, even while a candidate
   // CHoCH/Wave1/Wave2 pattern is active.  If that candidate is invalidated,
   // the same M5 Wave2 can immediately start searching for a NEW M1 downtrend.
   OriginalPivotPoint h1={};
   OriginalPivotPoint h2={};
   OriginalPivotPoint l1={};
   OriginalPivotPoint l2={};
   bool hh1=false,hh2=false,ll1=false,ll2=false;

   int pidx=0;
   while(pidx<ArraySize(pivots) && pivots[pidx].confirmed_time<start_time) pidx++;

   bool downtrend=false;
   OriginalPivotPoint currentReturnHigh={};
   OriginalPivotPoint currentLow={};
   bool haveReturnHigh=false,haveCurrentLow=false;

   // Latest lower high seen during the M1 Wave2 pullback.  When a newer
   // valid HL is confirmed, the last lower high BEFORE that low becomes the
   // Wave2 return-high trigger.
   OriginalPivotPoint latestPullbackHigh={};
   bool haveLatestPullbackHigh=false;

   for(int i=start;i<ArraySize(r)-1;i++)
   {
      datetime close_time=OriginalBarCloseTime(r[i],InpLowerTF);
      if(close_time<knowledge_time) continue;  // M5 Wave1 high was not knowable yet.
      if(r[i].time>hard_end) break;

      // M5 Wave1 origin broken => the whole M5 Wave2 thesis is invalid.
      if(r[i].low<s.origin_low.price) break;

      // Once M5 Wave1 high is exceeded, M5 Wave3 is already underway.
      bool m5Wave3Already=OriginalPriceBreakUp(r[i],s.wave1_high.price);

      // Consume every M1 pivot confirmed by this bar.  The generic swing
      // history is ALWAYS updated so an invalidated M1 attempt can restart.
      while(pidx<ArraySize(pivots) && OriginalPivotConfirmedBy(pivots[pidx],close_time))
      {
         OriginalPivotPoint p=pivots[pidx];
         if(p.bar_time>=start_time)
         {
            if(p.high) OriginalPushLastTwo(p,h1,h2,hh1,hh2);
            else       OriginalPushLastTwo(p,l1,l2,ll1,ll2);

            if(pat.found_choch)
            {
               if(!pat.found_wave1_high)
               {
                  // First confirmed swing high above the broken return high
                  // becomes M1 Wave1 high.
                  if(p.high && p.bar_time>=pat.choch_time && p.price>pat.downtrend_return_high.price)
                  {
                     pat.wave1_high=p;
                     pat.found_wave1_high=true;
                     ZeroMemory(latestPullbackHigh);
                     haveLatestPullbackHigh=false;
                  }
               }
               else
               {
                  // Track lower highs during the Wave2 pullback.
                  if(p.high && p.bar_time>pat.wave1_high.bar_time && p.price<pat.wave1_high.price)
                  {
                     latestPullbackHigh=p;
                     haveLatestPullbackHigh=true;
                  }

                  // A newer confirmed low above the reversal origin replaces
                  // the previous HL.  This prevents a stale, shallow HL from
                  // surviving while Wave2 continues deeper.
                  if(!p.high && p.bar_time>pat.wave1_high.bar_time && p.price>pat.reversal_low.price)
                  {
                     pat.hl=p;
                     pat.found_hl=true;

                     double range=pat.wave1_high.price-pat.reversal_low.price;
                     pat.retrace=(range>0.0 ? (pat.wave1_high.price-p.price)/range : 0.0);
                     pat.fib_ok=(pat.retrace>=InpFibZoneLow && pat.retrace<=InpFibZoneHigh);

                     ZeroMemory(pat.pullback_lh);
                     if(haveLatestPullbackHigh && latestPullbackHigh.bar_time<p.bar_time)
                        pat.pullback_lh=latestPullbackHigh;
                  }
               }
            }
         }
         pidx++;
      }

      // -------- M1 INVALIDATION --------
      // CHoCH/Wave1 is invalid if price trades below the reversal low.
      // Do NOT kill the M5 setup: reset only M1 and search for a new M1
      // downtrend/CHoCH within the same M5 Wave2.
      if(pat.found_choch && r[i].low<pat.reversal_low.price)
      {
         ZeroMemory(pat);
         ZeroMemory(latestPullbackHigh);
         haveLatestPullbackHigh=false;

         downtrend=(hh1 && hh2 && ll1 && ll2 && h2.price<h1.price && l2.price<l1.price);
         haveReturnHigh=false;
         haveCurrentLow=false;
         if(downtrend)
         {
            currentReturnHigh=h2;
            currentLow=l2;
            haveReturnHigh=true;
            haveCurrentLow=true;
         }

         // Conservative: do not create a new CHoCH on the same bar that
         // invalidated the old reversal origin.
         continue;
      }

      // A confirmed HL is only valid while price stays above that HL.
      // If Wave2 extends lower (but stays above reversal low), discard the
      // old HL and wait for a newer confirmed low before allowing READY.
      if(pat.found_hl && r[i].low<pat.hl.price)
      {
         pat.found_hl=false;
         ZeroMemory(pat.hl);
         ZeroMemory(pat.pullback_lh);
         pat.retrace=0.0;
         pat.fib_ok=false;
      }

      // When no active M1 reversal attempt exists, derive the latest objective
      // downtrend from the continuously-maintained pivot history.
      if(!pat.found_choch)
      {
         downtrend=(hh1 && hh2 && ll1 && ll2 && h2.price<h1.price && l2.price<l1.price);
         if(downtrend)
         {
            currentReturnHigh=h2;
            currentLow=l2;
            haveReturnHigh=true;
            haveCurrentLow=true;
         }
         else
         {
            haveReturnHigh=false;
            haveCurrentLow=false;
         }

         if(downtrend && haveReturnHigh && haveCurrentLow &&
            OriginalPriceBreakUp(r[i],currentReturnHigh.price) && close_time>=currentReturnHigh.confirmed_time)
         {
            pat.found_choch=true;
            pat.downtrend_return_high=currentReturnHigh;
            pat.reversal_low=currentLow;
            pat.choch_time=r[i].time;
            pat.choch_price=r[i].close;

            ZeroMemory(latestPullbackHigh);
            haveLatestPullbackHigh=false;
         }
      }

      // READY requires a currently-valid confirmed HL and a renewed upside
      // break.  Because stale HLs are cleared above, a deeper Wave2 cannot
      // trigger from an obsolete low.
      if(pat.found_hl && !pat.ready)
      {
         bool fibPass=(!InpRequireFibZone || pat.fib_ok);
         if(fibPass)
         {
            bool haveEarly=(pat.pullback_lh.bar_time>0 &&
                            pat.pullback_lh.bar_time>pat.wave1_high.bar_time &&
                            pat.pullback_lh.bar_time<pat.hl.bar_time);

            if(haveEarly && OriginalPriceBreakUp(r[i],pat.pullback_lh.price) && close_time>=pat.hl.confirmed_time)
            {
               pat.ready=true;
               pat.ready_time=r[i].time;
               pat.ready_price=r[i].close;
               pat.early_break=true;
               return true;
            }

            if(OriginalPriceBreakUp(r[i],pat.wave1_high.price) && close_time>=pat.hl.confirmed_time)
            {
               pat.ready=true;
               pat.ready_time=r[i].time;
               pat.ready_price=r[i].close;
               pat.early_break=false;
               return true;
            }
         }
      }

      // If M5 Wave3 has already begun before we even confirmed an M1 HL,
      // this particular "3 inside 3" opportunity has been missed.
      if(m5Wave3Already && pat.found_choch && !pat.found_hl)
         break;
   }
   return pat.found_choch;
}

