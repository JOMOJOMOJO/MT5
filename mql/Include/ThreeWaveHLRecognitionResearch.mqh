#ifndef THREE_WAVE_HL_RECOGNITION_RESEARCH
#define THREE_WAVE_HL_RECOGNITION_RESEARCH
#include "ThreeWaveHLRecognitionPolicy.mqh"
// Frozen AnalyzeLowerPattern fork; generic Shared source remains unchanged.
bool AnalyzeLowerPatternHLResearch(const MqlRates &r[],const PivotPoint &pivots[],const M5Setup &s,M1Pattern &pat)
{
   ZeroMemory(pat);

   datetime start_time=s.wave1_high.bar_time;
   datetime knowledge_time=s.wave1_high.confirmed_time;
   datetime hard_end=start_time+InpMaxSetupMinutes*60;

   int start=FindRateIndexAtOrAfter(r,start_time);
   if(start<0) return false;

   // Closed M1 bars may reveal an origin break inside an unfinished M5 bar.
   // Scan the whole post-CHoCH interval BEFORE the M5 high knowledge gate.
   for(int j=0;j<ArraySize(r)-1;j++)
   {
      if(BarCloseTime(r[j],InpLowerTF)<=s.break_time+TFSeconds(InpHigherTF)) continue;
      if(BarCloseTime(r[j],InpLowerTF)>knowledge_time) break;
      if(r[j].low<s.origin_low.price)
      {
         TWTrace(BarCloseTime(r[j],InpLowerTF),s.break_time,"WAIT_M5_DOWNTREND","M5_ORIGIN_BROKEN_DURING_CONFIRMATION");
         return false;
      }
   }
   datetime m1_epoch=start_time;
   TWTrace(knowledge_time,s.break_time,"WAIT_M1_DOWNTREND","M5_WAVE2_KNOWN");
   // Generic M1 structure is maintained continuously, even while a candidate
   // CHoCH/Wave1/Wave2 pattern is active.  If that candidate is invalidated,
   // the same M5 Wave2 can immediately start searching for a NEW M1 downtrend.
   PivotPoint h1={};
   PivotPoint h2={};
   PivotPoint l1={};
   PivotPoint l2={};
   bool hh1=false,hh2=false,ll1=false,ll2=false;

   int pidx=0;
   while(pidx<ArraySize(pivots) && pivots[pidx].confirmed_time<start_time) pidx++;

   bool downtrend=false;
   PivotPoint currentReturnHigh={};
   PivotPoint currentLow={};
   bool haveReturnHigh=false,haveCurrentLow=false;

   // Latest lower high seen during the M1 Wave2 pullback.  When a newer
   // valid HL is confirmed, the last lower high BEFORE that low becomes the
   // Wave2 return-high trigger.
   PivotPoint latestPullbackHigh={};
   bool haveLatestPullbackHigh=false;

   int hl_candidate=-1,hl_emitted=-1; datetime hl_wave_key=0;
   datetime first_m5_break=0;
   for(int i=start;i<ArraySize(r)-1;i++)
   {
      datetime close_time=BarCloseTime(r[i],InpLowerTF);
      if(close_time<knowledge_time) continue;  // M5 Wave1 high was not knowable yet.
      // Latch across every M1 reset/continue path. A later pullback cannot
      // revive a parent wave whose first breakout has already been missed.
      if(first_m5_break>0)
      { TWTrace(first_m5_break,s.break_time,"WAIT_M5_DOWNTREND","M5_WAVE3_STARTED_BEFORE_M1_READY"); break; }
      if(r[i].time>hard_end)
      { TWTrace(close_time,s.break_time,"WAIT_M5_DOWNTREND","SETUP_240_MINUTE_EXPIRY"); break; }

      // M5 Wave1 origin broken => the whole M5 Wave2 thesis is invalid.
      if(r[i].low<s.origin_low.price)
      { ZeroMemory(pat); TWTrace(close_time,s.break_time,"WAIT_M5_DOWNTREND","M5_ORIGIN_BROKEN"); break; }

      // Once M5 Wave1 high is exceeded, M5 Wave3 is already underway.
      bool m5Wave3Already=PriceBreakUp(r[i],s.wave1_high.price);
      if(m5Wave3Already) first_m5_break=close_time;

      // Consume every M1 pivot confirmed by this bar.  The generic swing
      // history is ALWAYS updated so an invalidated M1 attempt can restart.
      while(pidx<ArraySize(pivots) && PivotConfirmedBy(pivots[pidx],close_time))
      {
         PivotPoint p=pivots[pidx];
         if(p.bar_time>=m1_epoch)
         {
            if(p.high) PushLastTwo(p,h1,h2,hh1,hh2);
            else       PushLastTwo(p,l1,l2,ll1,ll2);

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
                     TWTrace(close_time,s.break_time,"M1_WAVE2_ACTIVE","M1_WAVE1_HIGH_CONFIRMED");
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
                  if(InpHLRecognitionMode==HL_ORIGINAL && !p.high && p.bar_time>pat.wave1_high.bar_time && p.price>pat.reversal_low.price)
                  {
                     pat.hl=p;
                     pat.found_hl=true;
                     TWTrace(close_time,s.break_time,"M1_WAVE2_ACTIVE","M1_HL_CONFIRMED");

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

         // A fresh attempt must be built from pivots after this failure.
         // Previously confirmed lows may themselves already have been broken.
         m1_epoch=close_time;
         hh1=false; hh2=false; ll1=false; ll2=false;
         downtrend=false; haveReturnHigh=false; haveCurrentLow=false;
         TWTrace(close_time,s.break_time,"WAIT_M1_DOWNTREND","M1_REVERSAL_LOW_BROKEN_RESET");

         // Conservative: do not create a new CHoCH on the same bar that
         // invalidated the old reversal origin.
         if(m5Wave3Already)
         { TWTrace(close_time,s.break_time,"WAIT_M5_DOWNTREND","M5_WAVE3_STARTED_BEFORE_M1_READY"); break; }
         continue;
      }

      // A confirmed HL is only valid while price stays above that HL.
      // If Wave2 extends lower (but stays above reversal low), discard the
      // old HL and wait for a newer confirmed low before allowing READY.
      if(pat.found_hl && r[i].low<pat.hl.price)
      {
         TWTrace(close_time,s.break_time,"M1_WAVE2_ACTIVE","M1_HL_BROKEN_DISCARD_OLD_HL");
         HLRecord("BROKEN",close_time,s,pat,0,r[i].close);
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
            PriceBreakUp(r[i],currentReturnHigh.price) && close_time>=currentReturnHigh.confirmed_time)
         {
            if(r[i].low<currentLow.price)
            {
               m1_epoch=close_time; hh1=false; hh2=false; ll1=false; ll2=false;
               TWTrace(close_time,s.break_time,"WAIT_M1_DOWNTREND","M1_CHOCH_BAR_REVERSAL_BROKEN");
               if(m5Wave3Already)
               { TWTrace(close_time,s.break_time,"WAIT_M5_DOWNTREND","M5_WAVE3_STARTED_BEFORE_M1_READY"); break; }
               continue;
            }
            pat.found_choch=true;
            TWTrace(close_time,s.break_time,"M1_WAVE1_ACTIVE","M1_CLOSED_CHOCH");
            pat.downtrend_return_high=currentReturnHigh;
            pat.reversal_low=currentLow;
            pat.choch_time=r[i].time;
            pat.choch_price=r[i].close;

            ZeroMemory(latestPullbackHigh);
            haveLatestPullbackHigh=false;

            // HL skip mode: READY fires at CHoCH without requiring Wave1 or HL.
            if(InpSkipLowerHL)
            {
               // Use the reversal low as HL so MakePlan has a valid SL anchor.
               pat.hl=pat.reversal_low;
               pat.found_hl=true;
               pat.ready=true;
               pat.ready_time=r[i].time;
               pat.ready_price=r[i].close;
               pat.early_break=false;
               TWTrace(close_time,s.break_time,"LONG_READY","SKIP_HL_CHOCH_ONLY");
               return true;
            }
         }
      }

      if(InpHLRecognitionMode!=HL_ORIGINAL && pat.found_wave1_high)
      {
         PivotPoint recognized={}; double threshold=0;
         if(ResearchHL(InpHLRecognitionMode,r,i,pat,hl_candidate,hl_emitted,hl_wave_key,recognized,threshold))
         {
            pat.hl=recognized; pat.found_hl=true;
            double range=pat.wave1_high.price-pat.reversal_low.price;
            pat.retrace=(range>0 ? (pat.wave1_high.price-recognized.price)/range : 0);
            pat.fib_ok=(pat.retrace>=InpFibZoneLow && pat.retrace<=InpFibZoneHigh);
            ZeroMemory(pat.pullback_lh);
            if(haveLatestPullbackHigh && latestPullbackHigh.bar_time<recognized.bar_time)
               pat.pullback_lh=latestPullbackHigh;
            HLRecord("RECOGNIZED",close_time,s,pat,threshold,r[i].close);
            TWTrace(close_time,s.break_time,"M1_WAVE2_ACTIVE",InpHLRecognitionMode==HL_RIGHT_ONE ? "M1_HL_RIGHT1" : "M1_HL_PRICE_REVERSAL");
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

            if(haveEarly && PriceBreakUp(r[i],pat.pullback_lh.price) && close_time>=pat.hl.confirmed_time)
            {
               pat.ready=true;
               pat.ready_time=r[i].time;
               pat.ready_price=r[i].close;
               pat.early_break=true;
               TWTrace(close_time,s.break_time,"LONG_READY","WAVE2_RETURN_HIGH_CLOSE_BREAK");
               return true;
            }

            if(PriceBreakUp(r[i],pat.wave1_high.price) && close_time>=pat.hl.confirmed_time)
            {
               pat.ready=true;
               pat.ready_time=r[i].time;
               pat.ready_price=r[i].close;
               pat.early_break=false;
               TWTrace(close_time,s.break_time,"LONG_READY","WAVE1_HIGH_CLOSE_BREAK");
               return true;
            }
         }
      }

      // READY on this first breakout bar is allowed. If it did not complete,
      // the initial parent-wave opportunity ends regardless of M1 state.
      if(m5Wave3Already)
      { TWTrace(close_time,s.break_time,"WAIT_M5_DOWNTREND","M5_WAVE3_STARTED_BEFORE_M1_READY"); break; }
   }
   return pat.found_choch;
}
#endif
