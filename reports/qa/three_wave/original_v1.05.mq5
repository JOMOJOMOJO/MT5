#property strict
#property version   "1.05"
#property description "Visual validator for M5 Wave1->Wave2 and M1 Wave1->Wave2->Wave3 long setups, with M1 invalidation/reset. No trading."
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_NONE
#property indicator_label1  "calc"

input ENUM_TIMEFRAMES InpLowerTF              = PERIOD_M1;
input ENUM_TIMEFRAMES InpHigherTF             = PERIOD_M5;
input int             InpLowerLeftBars        = 2;
input int             InpLowerRightBars       = 2;
input int             InpHigherLeftBars       = 2;
input int             InpHigherRightBars      = 2;
input int             InpHistoryLowerBars     = 6000;
input int             InpHistoryHigherBars    = 1800;
input int             InpMaxSetupMinutes      = 240;
input double          InpFibZoneLow           = 0.382;
input double          InpFibZoneHigh          = 0.618;
input bool            InpRequireFibZone       = false;
input bool            InpRequireCloseBreak    = true;
input bool            InpShowHigherPivots     = true;
input bool            InpShowRelevantM1Pivots = true;
input bool            InpShowFibZone          = true;
input bool            InpShowStructureLines   = true;
input bool            InpDiagnosticMode       = true;
input int             InpMaxDrawSetups        = 12;

struct PivotPoint
{
   datetime bar_time;       // source timeframe bar open time
   datetime plot_time;      // actual lower-TF extreme time used only for drawing
   datetime confirmed_time;
   double   price;
   bool     high;
   int      bar_index;
};

struct M5Setup
{
   bool       valid;
   PivotPoint origin_low;
   PivotPoint broken_high;
   datetime   break_time;
   double     break_price;
   PivotPoint wave1_high;
};

struct M1Pattern
{
   bool       found_choch;
   PivotPoint downtrend_return_high;
   PivotPoint reversal_low;
   datetime   choch_time;
   double     choch_price;

   bool       found_wave1_high;
   PivotPoint wave1_high;

   bool       found_hl;
   PivotPoint hl;
   PivotPoint pullback_lh;
   double     retrace;
   bool       fib_ok;

   bool       ready;
   datetime   ready_time;
   double     ready_price;
   bool       early_break;
};

string   g_prefix="W33_";
datetime g_last_lower_bar=0;
string   g_status="Waiting for data";
double   g_dummy[];
bool     g_force_rebuild=true;

int TFSeconds(const ENUM_TIMEFRAMES tf)
{
   int s=PeriodSeconds(tf);
   if(s<=0) s=60;
   return s;
}

datetime BarCloseTime(const MqlRates &bar,const ENUM_TIMEFRAMES tf)
{
   return bar.time+TFSeconds(tf);
}

bool IsPivotHigh(const MqlRates &r[],const int i,const int left,const int right)
{
   const double p=r[i].high;
   for(int k=1;k<=left;k++)  if(p<=r[i-k].high) return false;
   for(int k=1;k<=right;k++) if(p< r[i+k].high) return false;
   return true;
}

bool IsPivotLow(const MqlRates &r[],const int i,const int left,const int right)
{
   const double p=r[i].low;
   for(int k=1;k<=left;k++)  if(p>=r[i-k].low) return false;
   for(int k=1;k<=right;k++) if(p> r[i+k].low) return false;
   return true;
}

void AddPivot(PivotPoint &out[],const PivotPoint &p)
{
   int n=ArraySize(out);
   ArrayResize(out,n+1);
   out[n]=p;
}

void BuildPivots(const MqlRates &r[],const ENUM_TIMEFRAMES tf,const int left,const int right,PivotPoint &out[])
{
   ArrayResize(out,0);
   int n=ArraySize(r);
   if(n<left+right+3) return;

   for(int i=left;i<n-right;i++)
   {
      if(IsPivotHigh(r,i,left,right))
      {
         PivotPoint p={};
         p.bar_time=r[i].time;
         p.plot_time=r[i].time;
         p.confirmed_time=r[i+right].time+TFSeconds(tf);
         p.price=r[i].high;
         p.high=true;
         p.bar_index=i;
         AddPivot(out,p);
      }
      if(IsPivotLow(r,i,left,right))
      {
         PivotPoint p={};
         p.bar_time=r[i].time;
         p.plot_time=r[i].time;
         p.confirmed_time=r[i+right].time+TFSeconds(tf);
         p.price=r[i].low;
         p.high=false;
         p.bar_index=i;
         AddPivot(out,p);
      }
   }
}


// M5 OHLC only tells us that the extreme occurred somewhere inside the 5-minute bar.
// On an M1 chart, drawing at the M5 bar open can therefore look shifted by up to 4 minutes.
// This function moves only the DRAWING timestamp to the M1 bar that actually made the M5 high/low.
// Structural/confirmation logic continues to use bar_time and confirmed_time, so this does not add look-ahead.
void AlignHigherPivotPlotTimes(PivotPoint &pivots[],const MqlRates &lower[])
{
   int ln=ArraySize(lower);
   if(ln<=0) return;

   int li=0;
   for(int p=0;p<ArraySize(pivots);p++)
   {
      datetime from=pivots[p].bar_time;
      datetime to=from+TFSeconds(InpHigherTF);

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

datetime PivotPlotTime(const PivotPoint &p)
{
   return (p.plot_time>0 ? p.plot_time : p.bar_time);
}

// A close-based break becomes knowable at the end of the signal bar.
// Keep the stored logical time unchanged, but draw it at the close boundary.
datetime CloseSignalPlotTime(const datetime bar_open,const ENUM_TIMEFRAMES tf)
{
   return bar_open+TFSeconds(tf);
}

void PushLastTwo(const PivotPoint &p,PivotPoint &older,PivotPoint &latest,bool &haveOlder,bool &haveLatest)
{
   if(haveLatest)
   {
      older=latest;
      haveOlder=true;
   }
   latest=p;
   haveLatest=true;
}

bool PriceBreakUp(const MqlRates &bar,const double level)
{
   if(InpRequireCloseBreak) return bar.close>level;
   return bar.high>level;
}

int FindRateIndexAtOrAfter(const MqlRates &r[],const datetime t)
{
   int n=ArraySize(r);
   for(int i=0;i<n;i++) if(r[i].time>=t) return i;
   return -1;
}

int FindRateIndexAtOrBefore(const MqlRates &r[],const datetime t)
{
   int n=ArraySize(r);
   for(int i=n-1;i>=0;i--) if(r[i].time<=t) return i;
   return -1;
}

void AddSetup(M5Setup &setups[],const M5Setup &s)
{
   int n=ArraySize(setups);
   ArrayResize(setups,n+1);
   setups[n]=s;
}

// M5 logic:
// 1) Require an objectively confirmed downtrend: latest two swing highs are lower AND latest two swing lows are lower.
// 2) A closed M5 bar breaks the latest confirmed lower high -> M5 Wave1 starts (CHoCH).
// 3) The first confirmed M5 swing high after that break is treated as the end of M5 Wave1 / start of Wave2.
void BuildHigherSetups(const MqlRates &r[],const PivotPoint &pivots[],M5Setup &setups[])
{
   ArrayResize(setups,0);
   PivotPoint h1={};
   PivotPoint h2={};
   PivotPoint l1={};
   PivotPoint l2={};
   bool hh1=false,hh2=false,ll1=false,ll2=false;
   int pidx=0;
   bool armed=false;
   PivotPoint armedOrigin={};
   PivotPoint armedBroken={};
   datetime armedBreak=0;
   double armedBreakPrice=0.0;

   int n=ArraySize(r);
   for(int i=0;i<n-1;i++) // ignore still-forming last bar
   {
      datetime close_time=BarCloseTime(r[i],InpHigherTF);

      while(pidx<ArraySize(pivots) && pivots[pidx].confirmed_time<=close_time)
      {
         const PivotPoint p=pivots[pidx];
         if(p.high) PushLastTwo(p,h1,h2,hh1,hh2);
         else       PushLastTwo(p,l1,l2,ll1,ll2);

         if(armed && p.high && p.bar_time>=armedBreak && p.price>armedBroken.price)
         {
            M5Setup s={};
            s.valid=true;
            s.origin_low=armedOrigin;
            s.broken_high=armedBroken;
            s.break_time=armedBreak;
            s.break_price=armedBreakPrice;
            s.wave1_high=p;
            AddSetup(setups,s);
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

      if(PriceBreakUp(r[i],h2.price) && close_time>=h2.confirmed_time)
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

bool PivotConfirmedBy(const PivotPoint &p,const datetime t)
{
   return p.confirmed_time<=t;
}

bool IsAfter(const PivotPoint &p,const datetime t)
{
   return p.bar_time>t;
}

// Analyze M1 only while the M5 Wave2 idea remains alive.
// We explicitly do NOT buy merely because price reaches 50%.
// Long-ready requires: M1 downtrend -> CHoCH -> M1 Wave1 high -> HL -> renewed upside break.
bool AnalyzeLowerPattern(const MqlRates &r[],const PivotPoint &pivots[],const M5Setup &s,M1Pattern &pat)
{
   ZeroMemory(pat);

   datetime start_time=s.wave1_high.bar_time;
   datetime knowledge_time=s.wave1_high.confirmed_time;
   datetime hard_end=start_time+InpMaxSetupMinutes*60;

   int start=FindRateIndexAtOrAfter(r,start_time);
   if(start<0) return false;

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

   for(int i=start;i<ArraySize(r)-1;i++)
   {
      datetime close_time=BarCloseTime(r[i],InpLowerTF);
      if(close_time<knowledge_time) continue;  // M5 Wave1 high was not knowable yet.
      if(r[i].time>hard_end) break;

      // M5 Wave1 origin broken => the whole M5 Wave2 thesis is invalid.
      if(r[i].low<s.origin_low.price) break;

      // Once M5 Wave1 high is exceeded, M5 Wave3 is already underway.
      bool m5Wave3Already=PriceBreakUp(r[i],s.wave1_high.price);

      // Consume every M1 pivot confirmed by this bar.  The generic swing
      // history is ALWAYS updated so an invalidated M1 attempt can restart.
      while(pidx<ArraySize(pivots) && PivotConfirmedBy(pivots[pidx],close_time))
      {
         PivotPoint p=pivots[pidx];
         if(p.bar_time>=start_time)
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
            PriceBreakUp(r[i],currentReturnHigh.price) && close_time>=currentReturnHigh.confirmed_time)
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

            if(haveEarly && PriceBreakUp(r[i],pat.pullback_lh.price) && close_time>=pat.hl.confirmed_time)
            {
               pat.ready=true;
               pat.ready_time=r[i].time;
               pat.ready_price=r[i].close;
               pat.early_break=true;
               return true;
            }

            if(PriceBreakUp(r[i],pat.wave1_high.price) && close_time>=pat.hl.confirmed_time)
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

void DeleteOurObjects()
{
   for(int i=ObjectsTotal(0)-1;i>=0;i--)
   {
      string name=ObjectName(0,i);
      if(StringFind(name,g_prefix)==0) ObjectDelete(0,name);
   }
}

string ObjName(const string kind,const datetime t,const int serial=0)
{
   return g_prefix+kind+"_"+IntegerToString((long)t)+"_"+IntegerToString(serial);
}

void TextAt(const string name,const datetime t,const double price,const string text,const color c,const int anchor=ANCHOR_LEFT_LOWER,const int font=8)
{
   if(!ObjectCreate(0,name,OBJ_TEXT,0,t,price)) return;
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,c);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,font);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,anchor);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
}

void ArrowAt(const string name,const datetime t,const double price,const color c,const int code,const int width=2)
{
   if(!ObjectCreate(0,name,OBJ_ARROW,0,t,price)) return;
   ObjectSetInteger(0,name,OBJPROP_ARROWCODE,code);
   ObjectSetInteger(0,name,OBJPROP_COLOR,c);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
}

void Segment(const string name,const datetime t1,const double p1,const datetime t2,const double p2,const color c,const ENUM_LINE_STYLE style=STYLE_SOLID,const int width=1)
{
   if(!ObjectCreate(0,name,OBJ_TREND,0,t1,p1,t2,p2)) return;
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_COLOR,c);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
}

void HLineSegment(const string name,const datetime t1,const datetime t2,const double p,const color c,const ENUM_LINE_STYLE style=STYLE_DOT)
{
   Segment(name,t1,p,t2,p,c,style,1);
}

void FibZone(const string base,const datetime t1,const datetime t2,const double low,const double high)
{
   if(!InpShowFibZone || high<=low) return;
   double zHigh=high-(high-low)*InpFibZoneLow;
   double zLow =high-(high-low)*InpFibZoneHigh;
   string box=base+"_FIBBOX";
   if(ObjectCreate(0,box,OBJ_RECTANGLE,0,t1,zHigh,t2,zLow))
   {
      ObjectSetInteger(0,box,OBJPROP_COLOR,clrDarkSlateGray);
      ObjectSetInteger(0,box,OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(0,box,OBJPROP_FILL,false);
      ObjectSetInteger(0,box,OBJPROP_BACK,true);
      ObjectSetInteger(0,box,OBJPROP_SELECTABLE,false);
   }
   double f50=(low+high)*0.5;
   HLineSegment(base+"_FIB50",t1,t2,f50,clrSilver,STYLE_DOT);
}

void DrawHigherPivots(const PivotPoint &pivots[])
{
   if(!InpShowHigherPivots) return;
   int start=MathMax(0,ArraySize(pivots)-80);
   PivotPoint prev={};
   bool havePrev=false;
   for(int i=start;i<ArraySize(pivots);i++)
   {
      PivotPoint p=pivots[i];
      string tag=(p.high ? "M5 H" : "M5 L");
      color c=(p.high ? clrTomato : clrDodgerBlue);
      datetime pt=PivotPlotTime(p);
      TextAt(ObjName("M5P",p.bar_time,i),pt,p.price,tag,c,p.high?ANCHOR_LEFT_LOWER:ANCHOR_LEFT_UPPER,7);
      if(InpShowStructureLines && havePrev && prev.high!=p.high)
         Segment(ObjName("M5ZZ",p.bar_time,i),PivotPlotTime(prev),prev.price,pt,p.price,clrSlateGray,STYLE_DOT,1);
      prev=p; havePrev=true;
   }
}

void DrawLowerPivots(const PivotPoint &pivots[])
{
   if(!InpDiagnosticMode) return;
   int start=MathMax(0,ArraySize(pivots)-120);
   for(int i=start;i<ArraySize(pivots);i++)
   {
      PivotPoint p=pivots[i];
      string tag=(p.high ? "M1 H" : "M1 L");
      color c=(p.high ? clrLightCoral : clrDeepSkyBlue);
      TextAt(ObjName("M1P",p.bar_time,i),p.bar_time,p.price,tag,c,
             p.high ? ANCHOR_LEFT_LOWER : ANCHOR_LEFT_UPPER,6);
   }
}

void DrawSetup(const M5Setup &s,const M1Pattern &p,const int serial)
{
   string base=g_prefix+"S"+IntegerToString(serial)+"_"+IntegerToString((long)s.break_time);

   datetime m5BreakPlot=CloseSignalPlotTime(s.break_time,InpHigherTF);
   datetime brokenPlot=PivotPlotTime(s.broken_high);
   datetime originPlot=PivotPlotTime(s.origin_low);
   datetime wave1Plot=PivotPlotTime(s.wave1_high);

   ArrowAt(base+"_M5BREAK",m5BreakPlot,s.break_price,clrLimeGreen,233,2);
   TextAt(base+"_M5BREAK_TXT",m5BreakPlot,s.break_price,"M5 CHoCH / Wave1 start",clrLimeGreen,ANCHOR_LEFT_LOWER,8);
   HLineSegment(base+"_BROKEN",brokenPlot,s.wave1_high.confirmed_time,s.broken_high.price,clrDarkOrange,STYLE_DASH);
   TextAt(base+"_BROKEN_TXT",brokenPlot,s.broken_high.price,"M5 return high",clrDarkOrange,ANCHOR_LEFT_LOWER,7);

   ArrowAt(base+"_M5W1H",wave1Plot,s.wave1_high.price,clrGold,234,2);
   TextAt(base+"_M5W1H_TXT",wave1Plot,s.wave1_high.price,"M5 Wave1 high -> Wave2",clrGold,ANCHOR_LEFT_LOWER,8);

   if(InpShowStructureLines)
      Segment(base+"_M5W1",originPlot,s.origin_low.price,wave1Plot,s.wave1_high.price,clrMediumSeaGreen,STYLE_SOLID,2);

   if(!p.found_choch) return;

   datetime m1ChochPlot=CloseSignalPlotTime(p.choch_time,InpLowerTF);
   ArrowAt(base+"_M1CHOCH",m1ChochPlot,p.choch_price,clrAqua,233,2);
   TextAt(base+"_M1CHOCH_TXT",m1ChochPlot,p.choch_price,"M1 CHoCH",clrAqua,ANCHOR_LEFT_LOWER,8);
   HLineSegment(base+"_M1RET",p.downtrend_return_high.bar_time,m1ChochPlot,p.downtrend_return_high.price,clrAqua,STYLE_DOT);

   if(InpShowRelevantM1Pivots)
   {
      TextAt(base+"_M1RL",p.reversal_low.bar_time,p.reversal_low.price,"M1 reversal low",clrDeepSkyBlue,ANCHOR_LEFT_UPPER,7);
      TextAt(base+"_M1RH",p.downtrend_return_high.bar_time,p.downtrend_return_high.price,"M1 return high",clrDeepSkyBlue,ANCHOR_LEFT_LOWER,7);
   }

   if(!p.found_wave1_high) return;
   ArrowAt(base+"_M1W1H",p.wave1_high.bar_time,p.wave1_high.price,clrYellow,234,1);
   TextAt(base+"_M1W1H_TXT",p.wave1_high.bar_time,p.wave1_high.price,"M1 Wave1 high",clrYellow,ANCHOR_LEFT_LOWER,7);

   datetime fibEnd=p.found_hl ? p.hl.confirmed_time+15*60 : p.wave1_high.confirmed_time+15*60;
   if(p.ready) fibEnd=p.ready_time;
   FibZone(base,p.wave1_high.bar_time,fibEnd,p.reversal_low.price,p.wave1_high.price);

   if(InpShowStructureLines)
      Segment(base+"_M1W1",p.reversal_low.bar_time,p.reversal_low.price,p.wave1_high.bar_time,p.wave1_high.price,clrAqua,STYLE_SOLID,2);

   if(!p.found_hl) return;

   color hlc=(p.fib_ok ? clrLime : clrOrangeRed);
   ArrowAt(base+"_HL",p.hl.bar_time,p.hl.price,hlc,233,1);
   TextAt(base+"_HL_TXT",p.hl.bar_time,p.hl.price,
          "M1 HL  retrace="+DoubleToString(p.retrace*100.0,1)+"%"+(p.fib_ok?" [Fib OK]":" [outside Fib]"),
          hlc,ANCHOR_LEFT_UPPER,7);
   if(InpShowStructureLines)
      Segment(base+"_M1W2",p.wave1_high.bar_time,p.wave1_high.price,p.hl.bar_time,p.hl.price,clrOrange,STYLE_SOLID,2);

   if(p.pullback_lh.bar_time>0)
   {
      HLineSegment(base+"_PBLH",p.pullback_lh.bar_time,p.ready ? p.ready_time : p.hl.confirmed_time+20*60,
                   p.pullback_lh.price,clrViolet,STYLE_DOT);
      TextAt(base+"_PBLH_TXT",p.pullback_lh.bar_time,p.pullback_lh.price,"M1 Wave2 return high",clrViolet,ANCHOR_LEFT_LOWER,7);
   }

   if(!p.ready) return;
   datetime readyPlot=CloseSignalPlotTime(p.ready_time,InpLowerTF);
   ArrowAt(base+"_READY",readyPlot,p.ready_price,clrLime,241,3);
   TextAt(base+"_READY_TXT",readyPlot,p.ready_price,
          p.early_break ? "3x3 LONG READY (Wave2 return-high break)" : "3x3 LONG READY (Wave1-high break)",
          clrLime,ANCHOR_LEFT_LOWER,9);
   if(InpShowStructureLines)
      Segment(base+"_M1W3START",p.hl.bar_time,p.hl.price,readyPlot,p.ready_price,clrLime,STYLE_SOLID,2);
}

void Rebuild()
{
   DeleteOurObjects();

   MqlRates lower[],higher[];
   ArraySetAsSeries(lower,false);
   ArraySetAsSeries(higher,false);

   int lc=CopyRates(_Symbol,InpLowerTF,0,InpHistoryLowerBars,lower);
   int hc=CopyRates(_Symbol,InpHigherTF,0,InpHistoryHigherBars,higher);
   if(lc<100 || hc<100)
   {
      g_status="3x3 Visualizer: data not ready";
      return;
   }

   PivotPoint lp[],hp[];
   BuildPivots(lower,InpLowerTF,InpLowerLeftBars,InpLowerRightBars,lp);
   BuildPivots(higher,InpHigherTF,InpHigherLeftBars,InpHigherRightBars,hp);
   AlignHigherPivotPlotTimes(hp,lower);

   M5Setup setups[];
   BuildHigherSetups(higher,hp,setups);
   DrawHigherPivots(hp);
   DrawLowerPivots(lp);

   int total=ArraySize(setups);
   int first=MathMax(0,total-InpMaxDrawSetups);
   int readyCount=0,chochCount=0;
   string latest="No M5 setup";

   for(int i=first;i<total;i++)
   {
      M1Pattern p;
      AnalyzeLowerPattern(lower,lp,setups[i],p);
      DrawSetup(setups[i],p,i);
      if(p.found_choch) chochCount++;
      if(p.ready) readyCount++;

      if(i==total-1)
      {
         latest="Latest M5 break: "+TimeToString(setups[i].break_time,TIME_DATE|TIME_MINUTES);
         if(!p.found_choch) latest+=" | M1: waiting downtrend -> CHoCH";
         else if(!p.found_wave1_high) latest+=" | M1: CHoCH, waiting Wave1 high";
         else if(!p.found_hl) latest+=" | M1: waiting HL / Wave2";
         else if(!p.ready) latest+=" | M1: HL confirmed, waiting upside break";
         else latest+=" | 3x3 READY "+TimeToString(p.ready_time,TIME_DATE|TIME_MINUTES);
      }
   }

   g_status="3x3 Visualizer (NO TRADING)\n"
            "bars M1="+IntegerToString(lc)+" M5="+IntegerToString(hc)+
            " | pivots M1="+IntegerToString(ArraySize(lp))+" M5="+IntegerToString(ArraySize(hp))+"\n"
            "Higher="+EnumToString(InpHigherTF)+"  Lower="+EnumToString(InpLowerTF)+"\n"
            "M5 setups="+IntegerToString(total)+"  shown="+IntegerToString(total-first)+
            "  M1 CHoCH="+IntegerToString(chochCount)+"  READY="+IntegerToString(readyCount)+"\n"+latest+
            "\nDiagnosticMode="+(InpDiagnosticMode ? "ON" : "OFF")+
            " | Fib is a zone/filter only; NOT entry.";
   Print("3x3 Visualizer rebuild: M1 bars=",lc," M5 bars=",hc," M1 pivots=",ArraySize(lp)," M5 pivots=",ArraySize(hp)," setups=",total," READY=",readyCount);
   ChartRedraw();
   g_force_rebuild=false;
}

int OnInit()
{
   if(InpLowerTF>=InpHigherTF ||
      InpLowerLeftBars<1 || InpLowerRightBars<1 || InpHigherLeftBars<1 || InpHigherRightBars<1 ||
      InpHistoryLowerBars<500 || InpHistoryHigherBars<200 || InpMaxSetupMinutes<30 ||
      InpFibZoneLow<=0.0 || InpFibZoneHigh>=1.0 || InpFibZoneLow>=InpFibZoneHigh ||
      InpMaxDrawSetups<1)
      return INIT_PARAMETERS_INCORRECT;

   IndicatorSetString(INDICATOR_SHORTNAME,"3Wave-in-3Wave Visualizer v1.05");
   SetIndexBuffer(0,g_dummy,INDICATOR_DATA);
   ArraySetAsSeries(g_dummy,true);
   PlotIndexSetInteger(0,PLOT_DRAW_TYPE,DRAW_NONE);

   g_last_lower_bar=0;
   g_force_rebuild=true;
   EventSetTimer(2);

   // OnInit can run before all history is synchronized. Rebuild once now;
   // OnTimer retries automatically if data was not ready yet.
   Rebuild();
   return INIT_SUCCEEDED;
}

void OnTimer()
{
   datetime current=iTime(_Symbol,InpLowerTF,0);
   if(g_force_rebuild || current<=0 || current!=g_last_lower_bar)
   {
      if(current>0) g_last_lower_bar=current;
      Rebuild();
   }
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total>0)
      g_dummy[0]=0.0;

   datetime current=iTime(_Symbol,InpLowerTF,0);
   if(g_force_rebuild || (current>0 && current!=g_last_lower_bar))
   {
      if(current>0) g_last_lower_bar=current;
      Rebuild();
   }
   return rates_total;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteOurObjects();
}
