#property strict
#property version "1.00"
#property description "Closed-bar Wave33 lifecycle and W2-membership tests; actual engine, synthetic OHLC, no orders."
#include "../../Include/Wave33Visual/Engine.mqh"

input string InpRunTag="lifecycle";
int g_file=INVALID_HANDLE,g_passed=0,g_failed=0;
datetime g_base=D'2025.06.02 00:00:00';

void Check(const string name,const bool passed,const string detail)
  {
   if(passed) g_passed++; else g_failed++;
   if(g_file!=INVALID_HANDLE) FileWrite(g_file,name,passed ? "PASS" : "FAIL",detail);
   Print("W33_LIFECYCLE_TEST ",passed ? "PASS " : "FAIL ",name," ",detail);
  }
string Key(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   return EnumToString(upper)+"_"+EnumToString(lower)+"_"+W33DirectionName(direction);
  }
void MakeBar(MqlRates &b,const datetime at,const double price,const int direction)
  {
   ZeroMemory(b);
   double p=direction>0 ? price : 220.0-price;
   b.time=at; b.open=p-0.1*direction; b.close=p;
   b.high=p+0.3; b.low=p-0.3;
   b.tick_volume=100; b.spread=10;
  }
void Configure(CWave33Engine &engine,const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,
               const bool strict=true,const bool requireFib=true)
  {
   engine.Configure(upper,lower,2,2,0.382,0.618,96,false,requireFib);
   engine.SetLifecyclePolicy(strict);
   engine.SetTriggerMode(W33_PIVOT_BREAK);
   engine.SetPoint(0.01);
   engine.Reset("LIFECYCLE_SYNTHETIC");
  }
void UpperSeed(CWave33Engine &engine,const ENUM_TIMEFRAMES upper,const int direction,const int last=19,
               const int first=0,const datetime delayedKnown=0)
  {
   double prices[]={110,112,115,112,108,105,108,110,112,109,104,100,104,107,110,114,117,120,118,116};
   int seconds=PeriodSeconds(upper);
   for(int i=first;i<=last;i++)
     {
      MqlRates bar;
      MakeBar(bar,g_base+i*seconds,prices[i],direction);
      engine.Feed(upper,bar,delayedKnown>0 ? delayedKnown : bar.time+seconds);
     }
  }
void FeedPrice(CWave33Engine &engine,const ENUM_TIMEFRAMES lower,const datetime start,
               const int index,const double price,const int direction)
  {
   MqlRates bar;
   MakeBar(bar,start+index*PeriodSeconds(lower),price,direction);
   engine.Feed(lower,bar,bar.time+PeriodSeconds(lower));
  }
void LowerSeed(CWave33Engine &engine,const ENUM_TIMEFRAMES lower,const datetime start,const int direction,const int last=13)
  {
   double prices[]={117,118,119,117,115,113,114,115,116,114,112,110,111,112,114,117};
   for(int i=0;i<=last;i++) FeedPrice(engine,lower,start,i,prices[i],direction);
  }
int EventCount(const W33Event &events[],const string type)
  {
   int count=0;
   for(int i=0;i<ArraySize(events);i++) if(events[i].event_type==type) count++;
   return count;
  }
void TestInitialSameBarSignal(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   CWave33Engine engine;
   Configure(engine,upper,lower);
   UpperSeed(engine,upper,direction);
   datetime start=g_base+20*PeriodSeconds(upper);
   LowerSeed(engine,lower,start,direction);
   W33Setup before;
   engine.GetActive(direction,before);
   Check("samebar_preknown_"+Key(upper,lower,direction),before.lower_structure_confirmed && before.lower_structure_known_at<=start+14*PeriodSeconds(lower),
         "The W2-bound countertrend exists before the first continuation candle opens");
   FeedPrice(engine,lower,start,14,121,direction);
   W33Event events[];
   engine.Drain(events);
   W33Setup s;
   bool active=engine.GetActive(direction,s);
   Check("first_progress_samebar_signal_"+Key(upper,lower,direction),active && s.signal_emitted && EventCount(events,"SIGNAL")==1 && s.first_progress_bar_time==s.trigger_bar_time,
         "The first closed W1 continuation may itself emit the valid initial reversal signal");
   bool snapshot=false;
   for(int i=0;i<ArraySize(events);i++)
      if(events[i].event_type=="SIGNAL") snapshot=events[i].setup.first_progress_known_at==events[i].at && events[i].setup.first_progress_close_at==events[i].setup.signal_at;
   Check("samebar_progress_in_signal_snapshot_"+Key(upper,lower,direction),snapshot && EventCount(events,"INVALIDATE")==0,
         "Progress timestamps are present in SIGNAL; the accepted trade is not invalidated");
  }
void TestMissedMove(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   CWave33Engine engine;
   Configure(engine,upper,lower);
   UpperSeed(engine,upper,direction);
   datetime start=g_base+20*PeriodSeconds(upper);
   FeedPrice(engine,lower,start,0,110,direction);
   FeedPrice(engine,lower,start,1,121,direction);
   W33Setup s;
   bool active=engine.GetActive(direction,s);
   Check("missed_initial_move_"+Key(upper,lower,direction),!active && !s.signal_emitted && s.skip_reason=="INITIAL_MOVE_MISSED" && s.first_progress_bar_time==start+PeriodSeconds(lower),
         "No pre-known countertrend at first closed continuation terminates this W1/W2 candidate");
   Check("missed_move_timestamps_"+Key(upper,lower,direction),s.first_progress_close_at==start+2*PeriodSeconds(lower) && s.first_progress_known_at==s.first_progress_close_at,
         "Source candle, close and availability are recorded separately");
   double later[]={118,116,113,115,117,115,112,110,111,112,114,117,121};
   for(int i=0;i<ArraySize(later);i++) FeedPrice(engine,lower,start,i+2,later[i],direction);
   W33Event events[];
   engine.Drain(events);
   Check("missed_move_never_reused_"+Key(upper,lower,direction),!engine.GetActive(direction,s) && EventCount(events,"SIGNAL")==0 && EventCount(events,"INVALIDATE")==1,
         "Later local pivots cannot resurrect the expired W1/W2 setup");
  }
void TestWickEqualAndBeforeFib(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   CWave33Engine engine;
   Configure(engine,upper,lower);
   UpperSeed(engine,upper,direction);
   datetime start=g_base+20*PeriodSeconds(upper);
   FeedPrice(engine,lower,start,0,121,direction);
   W33Setup s;
   bool active=engine.GetActive(direction,s);
   Check("extension_before_fib_allowed_"+Key(upper,lower,direction),active && !s.fib_touched && s.first_progress_bar_time==0,
         "Fixed-W1 extension without an earlier Fib touch is not treated as a missed third-wave move");
   FeedPrice(engine,lower,start,1,110,direction);
   FeedPrice(engine,lower,start,2,120.3,direction);
   active=engine.GetActive(direction,s);
   Check("equal_close_and_wick_allowed_"+Key(upper,lower,direction),active && s.fib_touched && s.first_progress_bar_time==0,
         "A wick beyond W1 and a close exactly at W1 do not expire the setup");
   MqlRates wick;
   MakeBar(wick,start+3*PeriodSeconds(lower),119,direction);
   if(direction>0) wick.high=122; else wick.low=98;
   engine.Feed(lower,wick,wick.time+PeriodSeconds(lower));
   Check("wick_only_allowed_"+Key(upper,lower,direction),engine.GetActive(direction,s) && s.first_progress_bar_time==0,
         "Only a strictly beyond-W1 closed price counts as continuation");
  }
void TestSameBarFibOrderUnknown(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   CWave33Engine engine;
   Configure(engine,upper,lower);
   UpperSeed(engine,upper,direction);
   datetime start=g_base+20*PeriodSeconds(upper);
   MqlRates bar;
   MakeBar(bar,start,121,direction);
   if(direction>0) bar.low=110; else bar.high=110;
   engine.Feed(lower,bar,bar.time+PeriodSeconds(lower));
   W33Setup s;
   bool active=engine.GetActive(direction,s);
   Check("samebar_first_fib_not_prior_"+Key(upper,lower,direction),active && s.fib_touched && s.first_progress_bar_time==0,
         "OHLC cannot establish whether the first Fib touch preceded this same candle's extension");
   FeedPrice(engine,lower,start,1,122,direction);
   Check("nextbar_after_fib_expires_"+Key(upper,lower,direction),!engine.GetActive(direction,s) && s.skip_reason=="INITIAL_MOVE_MISSED" && s.first_progress_bar_time==start+PeriodSeconds(lower),
         "The following continuation candle does have an earlier closed Fib observation");
  }
void TestW2Membership(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   datetime start=g_base+20*PeriodSeconds(upper);
   double local[]={110,115,118,116,114,112,114,116,114,112.5,111.5,112,113,117};
   for(int legacy=0;legacy<2;legacy++)
     {
      CWave33Engine engine;
      Configure(engine,upper,lower,legacy==0);
      UpperSeed(engine,upper,direction);
      for(int i=0;i<ArraySize(local);i++) FeedPrice(engine,lower,start,i,local[i],direction);
      W33Setup s;
      engine.GetActive(direction,s);
      W33Event events[];
      engine.Drain(events);
      if(legacy==0)
        {
         Check("later_local_countertrend_rejected_"+Key(upper,lower,direction),!s.signal_emitted && !s.lower_structure_confirmed && EventCount(events,"LOWER_STRUCTURE_REJECTED")==1,
               "Local LH/LL or HH/HL above/below the true deepest W2 is measured once and cannot trigger");
         Check("rejected_structure_has_prices_"+Key(upper,lower,direction),StringLen(s.lower_pivot_prices)>0 && MathAbs((direction>0 ? s.lower_low2_price : s.lower_high2_price)-s.wave2_extreme_price)>0.005,
               "Rejected countertrend anchors remain available for explaining the membership mismatch");
        }
      else Check("legacy_membership_control_"+Key(upper,lower,direction),s.signal_emitted && EventCount(events,"SIGNAL")==1,
                 "Explicit legacy policy reproduces the formerly accepted unrelated local reversal");
     }
  }
void TestEqualPriceRetest(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   CWave33Engine engine;
   Configure(engine,upper,lower);
   UpperSeed(engine,upper,direction);
   datetime start=g_base+20*PeriodSeconds(upper);
   double prices[]={110,115,119,117,115,113,114,116,114,112,110,111,112,117};
   for(int i=0;i<13;i++) FeedPrice(engine,lower,start,i,prices[i],direction);
   W33Setup s;
   engine.GetActive(direction,s);
   Check("equal_w2_retest_binding_"+Key(upper,lower,direction),s.lower_structure_confirmed && s.wave2_extreme_time==start && s.lower_wave2_time==start+10*PeriodSeconds(lower) && MathAbs(s.lower_wave2_price-s.wave2_extreme_price)<0.000001,
         "A later equal-price extreme may bind the countertrend; first-W2 and binding times remain distinct");
   FeedPrice(engine,lower,start,13,117,direction);
   engine.GetActive(direction,s);
   Check("equal_w2_retest_signal_"+Key(upper,lower,direction),s.signal_emitted,
         "Time equality is not required for a genuine equal-price W2 retest reversal");
  }
void TestNewExtremeClearsBeforeTrigger(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   CWave33Engine engine;
   Configure(engine,upper,lower);
   UpperSeed(engine,upper,direction);
   datetime start=g_base+20*PeriodSeconds(upper);
   LowerSeed(engine,lower,start,direction);
   W33Event discarded[];
   engine.Drain(discarded);
   MqlRates outside;
   MakeBar(outside,start+14*PeriodSeconds(lower),117,direction);
   if(direction>0) outside.low=108; else outside.high=112;
   engine.Feed(lower,outside,outside.time+PeriodSeconds(lower));
   W33Setup s;
   engine.GetActive(direction,s);
   W33Event events[];
   engine.Drain(events);
   Check("new_w2_extreme_clears_old_trigger_"+Key(upper,lower,direction),!s.signal_emitted && !s.lower_structure_confirmed && EventCount(events,"SIGNAL")==0 && EventCount(events,"LOWER_STRUCTURE_LOST")==1,
         "A candle that changes W2 and crosses the old return level cannot use the stale structure");
  }
void TestHistoricalProgress(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   CWave33Engine engine;
   Configure(engine,upper,lower);
   UpperSeed(engine,upper,direction,17);
   datetime start=g_base+20*PeriodSeconds(upper);
   FeedPrice(engine,lower,start,0,110,direction);
   FeedPrice(engine,lower,start,1,121,direction);
   datetime knownNow=start+3*PeriodSeconds(upper);
   // Delayed upper history is received only now, after the lower stream. Its
   // retrospective W2 characterization may expire a setup but never execute.
   UpperSeed(engine,upper,direction,19,18,knownNow);
   W33Setup s;
   bool active=engine.GetActive(direction,s);
   W33Event events[];
   engine.Drain(events);
   Check("historical_progress_expires_now_"+Key(upper,lower,direction),!active && s.skip_reason=="INITIAL_MOVE_MISSED" && s.first_progress_bar_time==start+PeriodSeconds(lower) && s.first_progress_known_at==knownNow,
         "Previously closed progress discovered at W1 confirmation is recorded at current availability time");
   Check("historical_progress_never_signals_"+Key(upper,lower,direction),EventCount(events,"SIGNAL")==0 && s.first_progress_close_at<knownNow && s.last_updated_at==knownNow,
         "No replayed bar produces a past SIGNAL or a backdated invalidation");
  }
void TestFibOffAndLegacy(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   datetime start=g_base+20*PeriodSeconds(upper);
   for(int mode=0;mode<3;mode++)
     {
      CWave33Engine engine;
      Configure(engine,upper,lower,mode!=2,mode!=0);
      UpperSeed(engine,upper,direction);
      FeedPrice(engine,lower,start,0,mode==0 ? 115 : 110,direction);
      FeedPrice(engine,lower,start,1,121,direction);
      W33Setup s;
      bool active=engine.GetActive(direction,s);
      if(mode==0) Check("fib_disabled_prior_pullback_"+Key(upper,lower,direction),!active && !s.fib_touched && s.skip_reason=="INITIAL_MOVE_MISSED",
                        "Fib-disabled research still expires after a previously observed positive retracement");
      if(mode==1) Check("strict_policy_default_behavior_"+Key(upper,lower,direction),!active && s.skip_reason=="INITIAL_MOVE_MISSED","Strict lifecycle closes the unentered initial move");
      if(mode==2) Check("legacy_expiry_control_"+Key(upper,lower,direction),active && s.first_progress_bar_time==0,
                        "Explicit legacy policy preserves the old indefinitely reusable candidate for comparison");
     }
  }
void TestExistingSignalsAndPositions(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   for(int withPosition=0;withPosition<2;withPosition++)
     {
      CWave33Engine engine;
      Configure(engine,upper,lower);
      UpperSeed(engine,upper,direction);
      datetime start=g_base+20*PeriodSeconds(upper);
      LowerSeed(engine,lower,start,direction,15);
      W33Setup before;
      engine.GetActive(direction,before);
      if(withPosition==1) engine.MarkExecution(before.setup_id,true,start+16*PeriodSeconds(lower));
      FeedPrice(engine,lower,start,16,121,direction);
      W33Setup s;
      bool active=engine.GetActive(direction,s);
      string prefix=withPosition==1 ? "open_position_not_expired_" : "existing_signal_not_expired_";
      Check(prefix+Key(upper,lower,direction),active && s.signal_emitted && s.signal_at==before.signal_at && s.wave2_extreme_time==before.wave2_extreme_time && s.first_progress_bar_time==0 && s.position_open==(withPosition==1),
            "Lifecycle correction changes unentered candidates only; original signal and risk anchors remain fixed");
     }
  }
int OnInit()
  {
   g_file=FileOpen("W33Harness_"+InpRunTag+".csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(g_file==INVALID_HANDLE) return INIT_FAILED;
   FileWrite(g_file,"test","passed","detail");
   for(int pair=0;pair<2;pair++)
     {
      ENUM_TIMEFRAMES upper=pair==0 ? PERIOD_M15 : PERIOD_M5;
      ENUM_TIMEFRAMES lower=pair==0 ? PERIOD_M5 : PERIOD_M1;
      for(int direction=1;direction>=-1;direction-=2)
        {
         TestInitialSameBarSignal(upper,lower,direction);
         TestMissedMove(upper,lower,direction);
         TestWickEqualAndBeforeFib(upper,lower,direction);
         TestSameBarFibOrderUnknown(upper,lower,direction);
         TestW2Membership(upper,lower,direction);
         TestEqualPriceRetest(upper,lower,direction);
         TestNewExtremeClearsBeforeTrigger(upper,lower,direction);
         TestHistoricalProgress(upper,lower,direction);
         TestFibOffAndLegacy(upper,lower,direction);
         TestExistingSignalsAndPositions(upper,lower,direction);
        }
     }
   FileWrite(g_file,"FINAL",g_failed==0 ? "PASS" : "FAIL",StringFormat("passed=%d failed=%d",g_passed,g_failed));
   FileFlush(g_file); FileClose(g_file); g_file=INVALID_HANDLE;
   PrintFormat("W33_LIFECYCLE_HARNESS_FINAL passed=%d failed=%d",g_passed,g_failed);
   return INIT_SUCCEEDED;
  }
void OnTick() { if(MQLInfoInteger(MQL_TESTER)) TesterStop(); }
double OnTester() { return g_failed==0 ? 1.0 : 0.0; }
