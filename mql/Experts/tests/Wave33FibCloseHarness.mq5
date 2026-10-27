#property strict
#property version "1.00"
#property description "Actual-engine upper closed-price Fib-depth tests; synthetic OHLC, no orders."
#include "../../Include/Wave33Visual/Engine.mqh"
#include "../../Include/Wave33Visual/BarOrder.mqh"

input string InpRunTag="fib_close";
int g_file=INVALID_HANDLE,g_passed=0,g_failed=0;
datetime g_base=D'2025.06.02 00:00:00';

void Check(const string name,const bool passed,const string detail)
  {
   if(passed) g_passed++; else g_failed++;
   if(g_file!=INVALID_HANDLE) FileWrite(g_file,name,passed ? "PASS" : "FAIL",detail);
   Print("W33_FIB_CLOSE_TEST ",passed ? "PASS " : "FAIL ",name," ",detail);
  }
string Key(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  { return EnumToString(upper)+"_"+EnumToString(lower)+"_"+W33DirectionName(direction); }
void MakeBar(MqlRates &b,const datetime at,const double price,const int direction)
  {
   ZeroMemory(b);
   double p=direction>0 ? price : 220.0-price;
   b.time=at; b.open=p-0.1*direction; b.close=p;
   b.high=p+0.3; b.low=p-0.3; b.tick_volume=100; b.spread=10;
  }
void ActualBar(MqlRates &b,const datetime at,const double close,const double halfRange=0.3)
  {
   ZeroMemory(b);
   b.time=at; b.open=close; b.close=close;
   b.high=close+halfRange; b.low=close-halfRange; b.tick_volume=100; b.spread=10;
  }
void Configure(CWave33Engine &engine,const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,
               const bool closePolicy,const bool wickPolicy=false,const bool useSetter=true)
  {
   engine.Configure(upper,lower,2,2,0.382,0.618,96,wickPolicy,true);
   engine.SetPoint(0.01); engine.SetLifecyclePolicy(true);
   engine.SetLowerRecognition(W33_NORMALIZED_OR_SIMPLE); engine.SetTriggerMode(W33_PIVOT_BREAK);
   if(useSetter) engine.SetDeepFibClosePolicy(closePolicy);
   engine.Reset("FIB_CLOSE_SYNTHETIC");
  }
void UpperSeed(CWave33Engine &engine,const ENUM_TIMEFRAMES upper,const int direction,
               const int last=19,const int first=0)
  {
   double prices[]={110,112,115,112,108,105,108,110,112,109,104,100,104,107,110,114,117,120,118,116};
   for(int i=first;i<=last;i++)
     {
      MqlRates b;
      MakeBar(b,g_base+i*PeriodSeconds(upper),prices[i],direction);
      engine.Feed(upper,b,b.time+PeriodSeconds(upper));
     }
  }
void FeedPrice(CWave33Engine &engine,const ENUM_TIMEFRAMES tf,const datetime start,
               const int index,const double price,const int direction)
  {
   MqlRates b;
   MakeBar(b,start+index*PeriodSeconds(tf),price,direction);
   engine.Feed(tf,b,b.time+PeriodSeconds(tf));
  }
int Count(const W33Event &events[],const string type)
  {
   int n=0;
   for(int i=0;i<ArraySize(events);i++) if(events[i].event_type==type) n++;
   return n;
  }
void TestWickEqualityAndPolicy(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   for(int policy=0;policy<2;policy++)
     {
      CWave33Engine engine;
      Configure(engine,upper,lower,policy==1);
      UpperSeed(engine,upper,direction);
      W33Setup s;
      engine.GetActive(direction,s);
      double boundary=s.fib_618_price;
      MqlRates b;
      ActualBar(b,g_base+20*PeriodSeconds(upper),boundary+direction*0.5,1.0);
      engine.Feed(upper,b,b.time+PeriodSeconds(upper));
      bool active=engine.GetActive(direction,s);
      Check("wick_without_deep_close_policy"+IntegerToString(policy)+"_"+Key(upper,lower,direction),active && s.fib_close_bar_time==0,
            "A wick beyond 61.8% with the upper close inside is not a close-policy exclusion");
      ActualBar(b,g_base+21*PeriodSeconds(upper),boundary,0.5);
      engine.Feed(upper,b,b.time+PeriodSeconds(upper));
      Check("exact_boundary_allowed_policy"+IntegerToString(policy)+"_"+Key(upper,lower,direction),engine.GetActive(direction,s) && s.fib_close_bar_time==0,
            "An upper close exactly on the fixed boundary remains eligible");
      W33Event prior[];
      engine.Drain(prior);
      ActualBar(b,g_base+22*PeriodSeconds(upper),boundary-direction*0.01);
      datetime known=b.time+PeriodSeconds(upper);
      engine.Feed(upper,b,known);
      active=engine.GetActive(direction,s);
      W33Event events[];
      engine.Drain(events);
      string expectedKind=policy==1 ? "EXCLUSION" : "MEASUREMENT";
      bool reasonKind=false;
      for(int j=0;j<ArraySize(events);j++)
         if(events[j].event_type=="FIB_CLOSE_TOO_DEEP") reasonKind=events[j].reason_kind==expectedKind && events[j].reason=="FIB_CLOSE_TOO_DEEP";
      Check("strict_close_policy"+IntegerToString(policy)+"_"+Key(upper,lower,direction),active==(policy==0) && !s.signal_emitted &&
            (policy==0 || s.skip_reason=="FIB_CLOSE_TOO_DEEP") && Count(events,"FIB_CLOSE_TOO_DEEP")==1 && Count(events,"INVALIDATE")==policy && reasonKind,
            "One tradable point beyond the upper close boundary measures in control and excludes only with the new policy");
      Check("close_evidence_policy"+IntegerToString(policy)+"_"+Key(upper,lower,direction),s.fib_close_bar_time==b.time && s.fib_close_at==known && s.fib_close_known_at==known &&
            MathAbs(s.fib_close_price-b.close)<1e-10 && s.fib_close_ratio>0.618,
            "The first violating upper candle, close time, availability, price and retracement ratio are preserved");
      bool accepted=engine.Feed(upper,b,known+PeriodSeconds(upper));
      engine.GetActive(direction,s);
      W33Event duplicates[];
      engine.Drain(duplicates);
      Check("duplicate_close_no_repeat_policy"+IntegerToString(policy)+"_"+Key(upper,lower,direction),!accepted && Count(duplicates,"FIB_CLOSE_TOO_DEEP")==0 && s.fib_close_known_at==known,
            "A duplicate upper input cannot repeat or backdate the first close observation");
     }
  }
void TestLowerCloseAndOldWickPolicy(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   CWave33Engine engine;
   Configure(engine,upper,lower,true);
   UpperSeed(engine,upper,direction);
   W33Setup s;
   engine.GetActive(direction,s);
   MqlRates b;
   ActualBar(b,g_base+20*PeriodSeconds(upper),s.fib_618_price-direction*0.5);
   engine.Feed(lower,b,b.time+PeriodSeconds(lower));
   W33Event events[];
   engine.Drain(events);
   Check("lower_close_not_upper_rule_"+Key(upper,lower,direction),engine.GetActive(direction,s) && s.fib_close_bar_time==0 && Count(events,"FIB_CLOSE_TOO_DEEP")==0,
         "A lower-timeframe close deeper than 61.8% does not substitute for the selected upper close rule");

   CWave33Engine legacy;
   Configure(legacy,upper,lower,false,true);
   UpperSeed(legacy,upper,direction);
   legacy.GetActive(direction,s);
   ActualBar(b,g_base+20*PeriodSeconds(upper),s.fib_618_price+direction*0.5,1.0);
   legacy.Feed(lower,b,b.time+PeriodSeconds(lower));
   Check("legacy_wick_policy_unchanged_"+Key(upper,lower,direction),!legacy.GetActive(direction,s) && s.skip_reason=="FIB_TOO_DEEP" && s.fib_close_bar_time==0,
         "The existing rejectDeep=true still excludes lower-observed W2 wick depth independently of the new close policy");
  }
void TestProvisionalAndHistoricalClose(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   for(int policy=0;policy<2;policy++)
     {
      CWave33Engine engine;
      Configure(engine,upper,lower,policy==1);
      UpperSeed(engine,upper,direction,17);
      MqlRates b;
      MakeBar(b,g_base+18*PeriodSeconds(upper),106,direction);
      engine.Feed(upper,b,b.time+PeriodSeconds(upper));
      W33Setup s;
      bool active=engine.GetActive(direction,s);
      Check("provisional_no_fixed_fib_policy"+IntegerToString(policy)+"_"+Key(upper,lower,direction),active && !s.wave1_peak_fixed && s.fib_close_bar_time==0,
            "A deep close cannot be classified against a future W1 endpoint while that endpoint remains provisional");
      W33Event before[];
      engine.Drain(before);
      MakeBar(b,g_base+19*PeriodSeconds(upper),116,direction);
      datetime known=b.time+PeriodSeconds(upper);
      engine.Feed(upper,b,known);
      active=engine.GetActive(direction,s);
      W33Event events[];
      engine.Drain(events);
      int peakIndex=-1,breachIndex=-1,invalidationIndex=-1;
      for(int j=0;j<ArraySize(events);j++)
        {
         if(events[j].event_type=="WAVE1_PEAK_CONFIRMED") peakIndex=j;
         if(events[j].event_type=="FIB_CLOSE_TOO_DEEP") breachIndex=j;
         if(events[j].event_type=="INVALIDATE" && events[j].reason=="FIB_CLOSE_TOO_DEEP") invalidationIndex=j;
        }
      Check("historical_close_known_now_policy"+IntegerToString(policy)+"_"+Key(upper,lower,direction),active==(policy==0) && s.wave1_peak_fixed &&
            s.fib_close_bar_time==g_base+18*PeriodSeconds(upper) && s.fib_close_at==g_base+19*PeriodSeconds(upper) &&
            s.fib_close_known_at==known && s.fib_close_known_at==s.wave1_peak_known_at && s.fib_close_at<s.fib_close_known_at,
            "The earlier close breach is classified only now at peak confirmation, even when the latest close has returned inside");
      Check("historical_event_order_policy"+IntegerToString(policy)+"_"+Key(upper,lower,direction),Count(before,"FIB_CLOSE_TOO_DEEP")==0 && peakIndex>=0 && breachIndex>peakIndex &&
            (policy==0 || invalidationIndex>breachIndex) && Count(events,"SIGNAL")==0,
            "Fixed-peak availability precedes measurement/exclusion; historical candles never emit a retrospective signal");
     }
  }
void TestPeakCandleExcludedFromW2(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   CWave33Engine engine;
   Configure(engine,upper,lower,true);
   UpperSeed(engine,upper,direction,16);
   MqlRates b;
   MakeBar(b,g_base+17*PeriodSeconds(upper),106,direction);
   if(direction>0) b.high=120.3; else b.low=99.7;
   engine.Feed(upper,b,b.time+PeriodSeconds(upper));
   UpperSeed(engine,upper,direction,19,18);
   W33Setup s;
   Check("peak_candle_not_w2_close_"+Key(upper,lower,direction),engine.GetActive(direction,s) && s.wave1_peak_fixed && s.wave1_peak_time==g_base+17*PeriodSeconds(upper) && s.fib_close_bar_time==0,
         "The W1 peak candle's own deep body is not treated as a W2 close; W2 sources start one upper period later");
  }
void TestUnfinishedAndDelayedAvailability(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   CWave33Engine engine;
   Configure(engine,upper,lower,true);
   UpperSeed(engine,upper,direction);
   W33Setup s;
   engine.GetActive(direction,s);
   MqlRates b;
   ActualBar(b,g_base+20*PeriodSeconds(upper),s.fib_618_price-direction*0.1);
   datetime closedAt=b.time+PeriodSeconds(upper);
   bool accepted=engine.Feed(upper,b,closedAt-1);
   Check("forming_upper_rejected_"+Key(upper,lower,direction),!accepted && engine.GetActive(direction,s) && s.fib_close_bar_time==0,
         "The new condition cannot consume a forming or future upper candle");
   datetime known=closedAt+3*PeriodSeconds(upper);
   engine.Feed(upper,b,known);
   W33Event events[];
   engine.Drain(events);
   bool availability=true;
   for(int j=0;j<ArraySize(events);j++)
      if(events[j].event_type=="FIB_CLOSE_TOO_DEEP" || events[j].event_type=="INVALIDATE")
         availability=availability && events[j].at==known;
   Check("delayed_close_not_backdated_"+Key(upper,lower,direction),!engine.GetActive(direction,s) && s.skip_reason=="FIB_CLOSE_TOO_DEEP" &&
         s.fib_close_bar_time==b.time && s.fib_close_at==closedAt && s.fib_close_known_at==known && availability,
         "A delayed upper observation stores its original close time but publishes only at actual availability");
   datetime lowerStart=known+PeriodSeconds(upper);
   double later[]={116,114,110,111,113,115,113,112,113,116};
   for(int j=0;j<ArraySize(later);j++) FeedPrice(engine,lower,lowerStart,j,later[j],direction);
   engine.Drain(events);
   Check("deep_close_never_revives_"+Key(upper,lower,direction),!engine.GetActive(direction,s) && Count(events,"SIGNAL")==0 && s.fib_close_known_at==known,
         "Later lower reactions cannot revive a candidate terminated by the fixed upper close condition");
  }
void TestUpperBeforeSameTimeLowerTrigger(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   for(int policy=0;policy<2;policy++)
     {
      CWave33Engine engine;
      Configure(engine,upper,lower,policy==1);
      UpperSeed(engine,upper,direction);
      datetime simultaneous=g_base+24*PeriodSeconds(upper);
      datetime start=simultaneous-10*PeriodSeconds(lower);
      double prices[]={116,110,103,104,105,106,105,104,105,107};
      for(int j=0;j<9;j++) FeedPrice(engine,lower,start,j,prices[j],direction);
      W33Setup before;
      engine.GetActive(direction,before);
      Check("same_time_trigger_preknown_policy"+IntegerToString(policy)+"_"+Key(upper,lower,direction),before.lower_structure_confirmed && !before.signal_emitted && before.trigger_known_at<=start+9*PeriodSeconds(lower),
            "The synthetic same-availability scheduling test has a real pre-known lower reaction trigger");
      W33Event discarded[];
      engine.Drain(discarded);
      MqlRates pending[];
      ENUM_TIMEFRAMES periods[];
      ArrayResize(pending,2); ArrayResize(periods,2);
      MakeBar(pending[0],start+9*PeriodSeconds(lower),107,direction); periods[0]=lower;
      MakeBar(pending[1],simultaneous-PeriodSeconds(upper),107,direction); periods[1]=upper;
      W33SortClosedBars(pending,periods); // Same shared function as main FeedClosed.
      for(int j=0;j<2;j++) engine.Feed(periods[j],pending[j],simultaneous);
      W33Setup s;
      bool active=engine.GetActive(direction,s);
      W33Event events[];
      engine.Drain(events);
      Check("same_time_upper_close_priority_policy"+IntegerToString(policy)+"_"+Key(upper,lower,direction),active==(policy==0) && s.signal_emitted==(policy==0) &&
            Count(events,"SIGNAL")==(policy==0 ? 1 : 0) && (policy==0 || s.skip_reason=="FIB_CLOSE_TOO_DEEP"),
            "When upper and lower closes become available together, upper exclusion wins before the lower trigger; off control can signal");
     }
  }
void TestSignalAndPositionFrozen(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   for(int position=0;position<2;position++)
     {
      CWave33Engine engine;
      Configure(engine,upper,lower,true);
      UpperSeed(engine,upper,direction);
      datetime start=g_base+20*PeriodSeconds(upper);
      double prices[]={116,114,110,111,113,115,113,112,113,116};
      for(int j=0;j<ArraySize(prices);j++) FeedPrice(engine,lower,start,j,prices[j],direction);
      W33Setup before;
      engine.GetActive(direction,before);
      if(position==1) engine.MarkExecution(before.setup_id,true,before.signal_known_at);
      W33Event discarded[];
      engine.Drain(discarded);
      MqlRates b;
      ActualBar(b,g_base+26*PeriodSeconds(upper),before.fib_618_price-direction*0.1);
      engine.Feed(upper,b,b.time+PeriodSeconds(upper));
      W33Setup s;
      bool active=engine.GetActive(direction,s);
      W33Event events[];
      engine.Drain(events);
      Check("postsignal_fib_frozen_position"+IntegerToString(position)+"_"+Key(upper,lower,direction),before.signal_emitted && active && s.signal_emitted && s.position_open==(position==1) &&
            s.signal_at==before.signal_at && s.wave1_peak_known_at==before.wave1_peak_known_at && s.wave2_extreme_price==before.wave2_extreme_price &&
            s.fib_close_bar_time==0 && Count(events,"FIB_CLOSE_TOO_DEEP")==0 && Count(events,"INVALIDATE")==0,
            "A later deep upper close neither measures nor retroactively invalidates an existing signal or open position");
     }
  }
void TestDecimalEqualityAndDefaultOff(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   CWave33Engine engine;
   Configure(engine,upper,lower,true);
   double prices[]={110,112,115,112,108,105,108,110,112,109,104,100,104,107,110,114,117,120,118,116};
   for(int j=0;j<ArraySize(prices);j++)
     {
      MqlRates b;
      MakeBar(b,g_base+j*PeriodSeconds(upper),prices[j],1);
      double low=100.001+(b.low-99.7)*(0.5/20.6);
      double high=100.001+(b.high-99.7)*(0.5/20.6);
      double close=100.001+(b.close-99.7)*(0.5/20.6);
      double open=100.001+(b.open-99.7)*(0.5/20.6);
      if(j==11) low=100.001;
      if(j==17) high=100.501;
      b.low=direction>0 ? low : 200.502-high;
      b.high=direction>0 ? high : 200.502-low;
      b.close=direction>0 ? close : 200.502-close;
      b.open=direction>0 ? open : 200.502-open;
      engine.Feed(upper,b,b.time+PeriodSeconds(upper));
     }
   W33Setup s;
   engine.GetActive(direction,s);
   double equality=direction>0 ? 100.192 : 100.310;
   MqlRates b;
   ActualBar(b,g_base+20*PeriodSeconds(upper),equality,0.001);
   engine.Feed(upper,b,b.time+PeriodSeconds(upper));
   Check("decimal_equality_no_ulp_exclusion_"+Key(upper,lower,direction),engine.GetActive(direction,s) && s.wave1_peak_fixed && s.fib_close_bar_time==0 && MathAbs(s.fib_618_price-equality)<1e-10,
         "Decimal 61.8% equality is allowed even if floating-point multiplication differs by one binary unit");
   ActualBar(b,g_base+21*PeriodSeconds(upper),equality-direction*0.001,0.001);
   engine.Feed(upper,b,b.time+PeriodSeconds(upper));
   Check("decimal_real_breach_excluded_"+Key(upper,lower,direction),!engine.GetActive(direction,s) && s.skip_reason=="FIB_CLOSE_TOO_DEEP",
         "Arithmetic equality tolerance does not grant a tradable-point allowance beyond 61.8%");

   CWave33Engine control;
   Configure(control,upper,lower,false,false,false); // Deliberately do not invoke the new setter.
   UpperSeed(control,upper,direction);
   control.GetActive(direction,s);
   ActualBar(b,g_base+20*PeriodSeconds(upper),s.fib_618_price-direction*0.1);
   control.Feed(upper,b,b.time+PeriodSeconds(upper));
   W33Event events[];
   control.Drain(events);
   bool measurement=false;
   for(int j=0;j<ArraySize(events);j++)
      if(events[j].event_type=="FIB_CLOSE_TOO_DEEP") measurement=events[j].reason_kind=="MEASUREMENT";
   Check("constructor_close_policy_default_off_"+Key(upper,lower,direction),control.GetActive(direction,s) && measurement && Count(events,"INVALIDATE")==0,
         "Old callers that never set the new policy retain eligibility; the close breach is measurement only");
  }
void TestSharedBacklogSort()
  {
   ENUM_TIMEFRAMES frames[]={PERIOD_H1,PERIOD_M15,PERIOD_M5,PERIOD_M1};
   MqlRates pending[];
   ENUM_TIMEFRAMES periods[];
   for(int f=0;f<ArraySize(frames);f++)
     {
      int seconds=PeriodSeconds(frames[f]);
      for(int closed=seconds;closed<=7200;closed+=seconds)
        {
         int n=ArraySize(pending);
         ArrayResize(pending,n+1); ArrayResize(periods,n+1);
         ActualBar(pending[n],g_base+closed-seconds,100);
         periods[n]=frames[f];
        }
     }
   MqlRates old[];
   ENUM_TIMEFRAMES oldPeriods[];
   ArrayCopy(old,pending); ArrayCopy(oldPeriods,periods);
   // Reproduce the former close-time-only selection sort. Equal keys can be
   // reversed indirectly by swaps even though the input was upper-first.
   int n=ArraySize(old);
   for(int i=0;i<n;i++) for(int j=i+1;j<n;j++)
      if(old[j].time+PeriodSeconds(oldPeriods[j])<old[i].time+PeriodSeconds(oldPeriods[i]))
        {
         MqlRates tmp=old[i]; old[i]=old[j]; old[j]=tmp;
         ENUM_TIMEFRAMES tf=oldPeriods[i]; oldPeriods[i]=oldPeriods[j]; oldPeriods[j]=tf;
        }
   int oldFirst120=-1;
   for(int i=0;i<n;i++)
      if(old[i].time+PeriodSeconds(oldPeriods[i])==g_base+7200) { oldFirst120=i; break; }
   Check("backlog_old_sort_tie_regression",oldFirst120>=0 && oldPeriods[oldFirst120]==PERIOD_M5,
         "The actual two-hour grouped H1/M15/M5/M1 backlog reproduces the former M5-before-upper tie defect at minute 120");
   W33SortClosedBars(pending,periods);
   bool chronological=true,priority=true;
   for(int i=1;i<n;i++)
     {
      datetime previous=pending[i-1].time+PeriodSeconds(periods[i-1]);
      datetime current=pending[i].time+PeriodSeconds(periods[i]);
      chronological=chronological && previous<=current;
      if(previous==current) priority=priority && PeriodSeconds(periods[i-1])>=PeriodSeconds(periods[i]);
     }
   Check("backlog_shared_sort_chronological",chronological,
         "The shared main/harness sorter processes all two-hour backlog bars by ascending close time");
   Check("backlog_shared_sort_upper_priority",priority,
         "Every simultaneous close in the backlog is processed by descending timeframe duration");
   int first120=-1;
   for(int i=0;i<n;i++)
      if(pending[i].time+PeriodSeconds(periods[i])==g_base+7200) { first120=i; break; }
   bool finalOrder=first120>=0 && first120+3<n;
   if(finalOrder)
      finalOrder=periods[first120]==PERIOD_H1 && periods[first120+1]==PERIOD_M15 &&
                 periods[first120+2]==PERIOD_M5 && periods[first120+3]==PERIOD_M1;
   Check("backlog_shared_sort_minute120_exact",finalOrder,
         "At minute 120 the shared function returns H1 -> M15 -> M5 -> M1, including the original regression position");
  }
int OnInit()
  {
   g_file=FileOpen("W33Harness_"+InpRunTag+".csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(g_file==INVALID_HANDLE) return INIT_FAILED;
   FileWrite(g_file,"test","passed","detail");
   TestSharedBacklogSort();
   for(int pair=0;pair<2;pair++)
     {
      ENUM_TIMEFRAMES upper=pair==0 ? PERIOD_M15 : PERIOD_M5;
      ENUM_TIMEFRAMES lower=pair==0 ? PERIOD_M5 : PERIOD_M1;
      for(int direction=1;direction>=-1;direction-=2)
        {
         TestWickEqualityAndPolicy(upper,lower,direction);
         TestLowerCloseAndOldWickPolicy(upper,lower,direction);
         TestProvisionalAndHistoricalClose(upper,lower,direction);
         TestPeakCandleExcludedFromW2(upper,lower,direction);
         TestUnfinishedAndDelayedAvailability(upper,lower,direction);
         TestUpperBeforeSameTimeLowerTrigger(upper,lower,direction);
         TestSignalAndPositionFrozen(upper,lower,direction);
         TestDecimalEqualityAndDefaultOff(upper,lower,direction);
        }
     }
   FileWrite(g_file,"FINAL",g_failed==0 ? "PASS" : "FAIL",StringFormat("passed=%d failed=%d",g_passed,g_failed));
   FileFlush(g_file); FileClose(g_file); g_file=INVALID_HANDLE;
   PrintFormat("W33_FIB_CLOSE_HARNESS_FINAL passed=%d failed=%d",g_passed,g_failed);
   return INIT_SUCCEEDED;
  }
void OnTick() { if(MQLInfoInteger(MQL_TESTER)) TesterStop(); }
double OnTester() { return g_failed==0 ? 1.0 : 0.0; }
