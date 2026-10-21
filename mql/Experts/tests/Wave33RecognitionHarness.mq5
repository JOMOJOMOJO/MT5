#property strict
#property version "1.00"
#property description "Actual-engine lower-swing recognition tests; synthetic closed OHLC, no orders."
#include "../../Include/Wave33Visual/Engine.mqh"

input string InpRunTag="recognition";
int g_file=INVALID_HANDLE,g_passed=0,g_failed=0;
datetime g_base=D'2025.06.02 00:00:00';

void Check(const string name,const bool passed,const string detail)
  {
   if(passed) g_passed++; else g_failed++;
   if(g_file!=INVALID_HANDLE) FileWrite(g_file,name,passed ? "PASS" : "FAIL",detail);
   Print("W33_RECOGNITION_TEST ",passed ? "PASS " : "FAIL ",name," ",detail);
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
void FeedRange(CWave33Engine &engine,const ENUM_TIMEFRAMES tf,const datetime at,
               const double close,const double high,const double low,const int direction)
  {
   MqlRates b;
   MakeBar(b,at,close,direction);
   b.high=direction>0 ? high : 220.0-low;
   b.low=direction>0 ? low : 220.0-high;
   engine.Feed(tf,b,at+PeriodSeconds(tf));
  }
void FeedPrice(CWave33Engine &engine,const ENUM_TIMEFRAMES tf,const datetime start,
               const int index,const double price,const int direction)
  {
   MqlRates b;
   MakeBar(b,start+index*PeriodSeconds(tf),price,direction);
   engine.Feed(tf,b,b.time+PeriodSeconds(tf));
  }
void Configure(CWave33Engine &engine,const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,
               const W33LowerRecognitionMode recognition,const W33TriggerMode trigger=W33_PIVOT_BREAK)
  {
   engine.Configure(upper,lower,2,2,0.382,0.618,96,false,true);
   engine.SetPoint(0.01); engine.SetLifecyclePolicy(true);
   engine.SetLowerRecognition(recognition); engine.SetTriggerMode(trigger);
   engine.Reset("RECOGNITION_SYNTHETIC");
  }
void UpperSeed(CWave33Engine &engine,const ENUM_TIMEFRAMES upper,const int direction,
               const int last=19,const int first=0,const datetime delayedKnown=0)
  {
   double prices[]={110,112,115,112,108,105,108,110,112,109,104,100,104,107,110,114,117,120,118,116};
   for(int i=first;i<=last;i++)
     {
      MqlRates b;
      MakeBar(b,g_base+i*PeriodSeconds(upper),prices[i],direction);
      engine.Feed(upper,b,delayedKnown>0 ? delayedKnown : b.time+PeriodSeconds(upper));
     }
  }
int Count(const W33Event &events[],const string type)
  {
   int n=0;
   for(int i=0;i<ArraySize(events);i++) if(events[i].event_type==type) n++;
   return n;
  }
void SimpleSeed(CWave33Engine &engine,const ENUM_TIMEFRAMES lower,const datetime start,
                const int direction,const int last=8)
  {
   double prices[]={116,114,110,111,113,115,113,112,113,116};
   for(int i=0;i<=last;i++) FeedPrice(engine,lower,start,i,prices[i],direction);
  }
void TestSimpleAndStrict(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   datetime start=g_base+20*PeriodSeconds(upper);
   for(int mode=0;mode<3;mode++)
     {
      CWave33Engine engine;
      Configure(engine,upper,lower,(W33LowerRecognitionMode)mode);
      UpperSeed(engine,upper,direction);
      SimpleSeed(engine,lower,start,direction,8);
      W33Setup s;
      engine.GetActive(direction,s);
      if(mode==2)
        {
         Check("simple_preknown_"+Key(upper,lower,direction),s.lower_structure_confirmed && s.lower_recognition=="SIMPLE_REACTION_BREAK" && s.lower_structure_known_at==start+8*PeriodSeconds(lower),
               "Confirmed W2 pivot and first reaction line are available one full candle before the eventual cross");
         Check("simple_two_pivots_only_"+Key(upper,lower,direction),s.lower_high1_time==0 && s.lower_low1_time==0 && s.lower_wave2_time==start+2*PeriodSeconds(lower),
               "No additional retest pivot or strict lower 1->2->3 count is fabricated");
        }
      FeedPrice(engine,lower,start,9,116,direction);
      engine.GetActive(direction,s);
      W33Event events[];
      engine.Drain(events);
      if(mode<2) Check("complete_only_no_simple_mode"+IntegerToString(mode)+"_"+Key(upper,lower,direction),!s.signal_emitted && Count(events,"SIGNAL")==0,
                       "Modes 0 and 1 retain complete-countertrend requirements for this short reaction");
      else
        {
         Check("simple_fresh_cross_signal_"+Key(upper,lower,direction),s.signal_emitted && Count(events,"SIGNAL")==1 && s.signal_at==start+10*PeriodSeconds(lower) && s.trigger_type=="PIVOT_BREAK",
               "A fresh closed cross of the pre-known first reaction level can enter before W1 is reached");
         Check("simple_stage_and_binding_"+Key(upper,lower,direction),s.lower_entry_stage=="SIMPLE_REACTION_BREAK" && s.lower_recognition=="SIMPLE_REACTION_BREAK" && MathAbs(s.lower_wave2_price-s.wave2_extreme_price)<0.000001 && s.lower_unmet_reason=="",
               "Signal snapshots identify the separate recognition assumption and its W2 membership");
         Check("simple_no_synthetic_trendline_"+Key(upper,lower,direction),s.trendline_trigger_at==0 && Count(events,"TRENDLINE_TRIGGER")==0,
               "The simple route has one reaction point, so it cannot produce a trendline event");
        }
     }
  }
void TestNormalization(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   datetime start=g_base+20*PeriodSeconds(upper);
   double highs[]={118,119,120,119,118,116,117,118,119,118,117,118.5,117,116,115,114,113,114,115};
   double lows[]={116,117,118,116,114,112,113,114,115,114,113,112,111,110,109,108,109,110,111};
   for(int mode=0;mode<2;mode++)
     {
      CWave33Engine engine;
      Configure(engine,upper,lower,(W33LowerRecognitionMode)mode);
      UpperSeed(engine,upper,direction);
      for(int i=0;i<ArraySize(highs);i++)
         FeedRange(engine,lower,start+i*PeriodSeconds(lower),(highs[i]+lows[i])*0.5,highs[i],lows[i],direction);
      W33Setup s;
      engine.GetActive(direction,s);
      if(mode==1)
        {
         datetime reactionTime=direction>0 ? s.lower_high2_time : s.lower_low2_time;
         Check("normalized_extreme_not_latest_"+Key(upper,lower,direction),s.lower_structure_confirmed && s.lower_recognition=="NORMALIZED_COUNTERTREND" && reactionTime==start+8*PeriodSeconds(lower),
               "Consecutive same-side pivots retain the most extreme confirmed pivot, not simply the most recent one");
        }
      FeedPrice(engine,lower,start,19,119.5,direction);
      engine.GetActive(direction,s);
      W33Event events[];
      engine.Drain(events);
      if(mode==0) Check("strict_raw_sequence_control_"+Key(upper,lower,direction),!s.signal_emitted,
                       "Unchanged mode 0 cannot use the nonalternating latest raw highs and lows");
      else
        {
         Check("normalized_complete_signal_"+Key(upper,lower,direction),s.signal_emitted && s.lower_entry_stage=="COUNTERTREND_NEGATION" && Count(events,"SIGNAL")==1,
               "An ordered normalized LH/LL or HH/HL structure can trigger with the same strict W2 membership");
         bool rawKept=false;
         for(int j=0;j<ArraySize(events);j++)
            if(events[j].event_type=="PIVOT_CONFIRMED" && events[j].pivot.time==start+11*PeriodSeconds(lower)) rawKept=true;
         Check("normalized_raw_events_unchanged_"+Key(upper,lower,direction),rawKept,
               "Compression is a current recognition view; the discarded same-side raw pivot still exists in causal history");
        }
     }
  }
void TestAmbiguousOutsidePivot(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   datetime start=g_base+20*PeriodSeconds(upper);
   for(int mode=1;mode<3;mode++)
     {
      CWave33Engine engine;
      Configure(engine,upper,lower,(W33LowerRecognitionMode)mode);
      UpperSeed(engine,upper,direction);
      double prices[]={116,115,114,113,112,113,112,113};
      for(int i=0;i<ArraySize(prices);i++)
        {
         if(i==5) FeedRange(engine,lower,start+i*PeriodSeconds(lower),113,119,108,direction);
         else FeedPrice(engine,lower,start,i,prices[i],direction);
        }
      W33Setup s;
      engine.GetActive(direction,s);
      Check("ambiguous_samebar_mode"+IntegerToString(mode)+"_"+Key(upper,lower,direction),!s.lower_structure_confirmed && s.lower_unmet_reason=="AMBIGUOUS_PIVOT_ORDER",
            "A candle confirmed as both high and low cannot invent intrabar order or a simple W2 anchor");
      FeedPrice(engine,lower,start,8,119.5,direction);
      W33Event events[];
      engine.Drain(events);
      Check("ambiguous_no_signal_mode"+IntegerToString(mode)+"_"+Key(upper,lower,direction),Count(events,"SIGNAL")==0,
            "A later close cannot turn an ambiguous two-sided swing into a historical trigger");
     }
  }
void TestSimpleNewExtreme(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   CWave33Engine engine;
   Configure(engine,upper,lower,W33_NORMALIZED_OR_SIMPLE);
   UpperSeed(engine,upper,direction);
   datetime start=g_base+20*PeriodSeconds(upper);
   SimpleSeed(engine,lower,start,direction,7);
   W33Setup before;
   engine.GetActive(direction,before);
   Check("simple_before_new_extreme_"+Key(upper,lower,direction),before.lower_structure_confirmed && before.lower_recognition=="SIMPLE_REACTION_BREAK",
         "The old first reaction line genuinely exists before this reset test");
   W33Event discarded[];
   engine.Drain(discarded);
   FeedRange(engine,lower,start+8*PeriodSeconds(lower),116,116.3,108,direction);
   W33Setup s;
   engine.GetActive(direction,s);
   W33Event events[];
   engine.Drain(events);
   Check("simple_new_extreme_before_trigger_"+Key(upper,lower,direction),!s.signal_emitted && !s.lower_structure_confirmed && Count(events,"LOWER_STRUCTURE_LOST")==1 && Count(events,"SIGNAL")==0,
         "A bar crossing the old reaction while setting a deeper W2 cannot use that stale line");
   FeedPrice(engine,lower,start,9,117,direction);
   FeedPrice(engine,lower,start,10,118,direction);
   engine.GetActive(direction,s);
   Check("simple_old_reaction_not_reused_"+Key(upper,lower,direction),!s.signal_emitted && !s.lower_structure_confirmed && s.lower_unmet_reason=="WAITING_REACTION_PIVOT",
         "Once the new W2 is confirmed, a reaction before that W2 is still ineligible");
  }
void TestDelayedKnowledgeAndFrozenReaction(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   CWave33Engine engine;
   Configure(engine,upper,lower,W33_NORMALIZED_OR_SIMPLE);
   UpperSeed(engine,upper,direction,17);
   datetime start=g_base+20*PeriodSeconds(upper);
   double prices[]={116,114,110,111,113,115,113,112,113,116,117,115,113,112};
   for(int i=0;i<ArraySize(prices);i++) FeedPrice(engine,lower,start,i,prices[i],direction);
   datetime knownNow=start+14*PeriodSeconds(lower);
   UpperSeed(engine,upper,direction,19,18,knownNow);
   W33Setup s;
   engine.GetActive(direction,s);
   double expected=direction>0 ? 115.3 : 104.7;
   Check("simple_first_reaction_frozen_"+Key(upper,lower,direction),s.lower_structure_confirmed && s.lower_recognition=="SIMPLE_REACTION_BREAK" && MathAbs(s.trigger_line_price-expected)<0.000001 && s.lower_structure_known_at==knownNow,
         "A later confirmed higher/lower reaction does not move the first line; its availability is the delayed W1 confirmation time");
   W33Event events[];
   engine.Drain(events);
   Check("simple_historical_cross_not_replayed_"+Key(upper,lower,direction),!s.signal_emitted && Count(events,"SIGNAL")==0 && s.trigger_bar_time==0,
         "Crosses before W1 and the reaction line were jointly knowable never execute retrospectively");
   FeedPrice(engine,lower,start,14,116,direction);
   engine.GetActive(direction,s);
   Check("simple_new_fresh_cross_after_known_"+Key(upper,lower,direction),s.signal_emitted && s.signal_at==start+15*PeriodSeconds(lower) && s.trigger_known_at==knownNow,
         "A later fresh cross uses the original known first reaction level, rather than the more distant later pivot");
  }
void TestNoFreshCrossAfterDelayedKnowledge(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   CWave33Engine engine;
   Configure(engine,upper,lower,W33_NORMALIZED_OR_SIMPLE);
   UpperSeed(engine,upper,direction,17);
   datetime start=g_base+20*PeriodSeconds(upper);
   SimpleSeed(engine,lower,start,direction,9);
   datetime knownNow=start+10*PeriodSeconds(lower);
   UpperSeed(engine,upper,direction,19,18,knownNow);
   FeedPrice(engine,lower,start,10,117,direction);
   W33Setup s;
   engine.GetActive(direction,s);
   Check("simple_already_beyond_line_no_entry_"+Key(upper,lower,direction),!s.signal_emitted && s.lower_structure_confirmed && s.lower_unmet_reason=="WAITING_FRESH_REACTION_CROSS",
         "Price already beyond the reaction when W1 became known is not a new cross on the following candle");
   FeedPrice(engine,lower,start,11,113,direction);
   FeedPrice(engine,lower,start,12,116,direction);
   engine.GetActive(direction,s);
   Check("simple_rearm_by_actual_recross_"+Key(upper,lower,direction),s.signal_emitted && s.signal_at==start+13*PeriodSeconds(lower),
         "Only an observable return below/above and subsequent fresh cross can enter this still-active candidate");
  }
void TestSimpleTrendlineMode(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   CWave33Engine engine;
   Configure(engine,upper,lower,W33_NORMALIZED_OR_SIMPLE,W33_TRENDLINE_BREAK);
   UpperSeed(engine,upper,direction);
   datetime start=g_base+20*PeriodSeconds(upper);
   SimpleSeed(engine,lower,start,direction,9);
   W33Setup s;
   engine.GetActive(direction,s);
   W33Event events[];
   engine.Drain(events);
   Check("simple_tl_mode_explicit_unmet_"+Key(upper,lower,direction),!s.signal_emitted && s.lower_structure_confirmed && s.lower_unmet_reason=="SIMPLE_REQUIRES_PIVOT_TRIGGER" && Count(events,"PIVOT_TRIGGER")==1,
         "A pivot diagnostic cannot silently substitute for the selected trendline arm");
   Check("simple_tl_mode_no_fake_line_"+Key(upper,lower,direction),s.trendline_trigger_at==0 && Count(events,"TRENDLINE_TRIGGER")==0 && Count(events,"SIGNAL")==0,
         "No trendline is extrapolated from zero-valued missing anchors");
  }
void TestCompleteStructurePriority(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   CWave33Engine engine;
   Configure(engine,upper,lower,W33_NORMALIZED_OR_SIMPLE);
   UpperSeed(engine,upper,direction);
   datetime start=g_base+20*PeriodSeconds(upper);
   double prices[]={117,118,119,117,115,113,114,115,116,114,112,110,111,112,114,117};
   for(int i=0;i<=13;i++) FeedPrice(engine,lower,start,i,prices[i],direction);
   W33Setup s;
   engine.GetActive(direction,s);
   Check("complete_structure_priority_"+Key(upper,lower,direction),s.lower_structure_confirmed && s.lower_recognition=="NORMALIZED_COUNTERTREND" && s.lower_entry_stage=="COUNTERTREND_NEGATION" && s.lower_high1_time>0 && s.lower_low1_time>0,
         "A complete W2-bound normalized countertrend takes priority over the simple fallback");
   for(int i=14;i<ArraySize(prices);i++) FeedPrice(engine,lower,start,i,prices[i],direction);
   engine.GetActive(direction,s);
   Check("complete_priority_valid_signal_"+Key(upper,lower,direction),s.signal_emitted && s.lower_recognition=="NORMALIZED_COUNTERTREND" && s.lower_entry_stage=="COUNTERTREND_NEGATION",
         "The shorter-reaction route preserves the earlier complete-structure valid entry");
  }
void TestUnrelatedCompleteDoesNotChurnSimple(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   CWave33Engine engine;
   Configure(engine,upper,lower,W33_NORMALIZED_OR_SIMPLE);
   UpperSeed(engine,upper,direction);
   datetime start=g_base+20*PeriodSeconds(upper);
   double prices[]={116,114,110,111,113,119,117,116,117,118,116,114,115,116,115,113,114,115,114};
   for(int i=0;i<=13;i++) FeedPrice(engine,lower,start,i,prices[i],direction);
   W33Setup before;
   engine.GetActive(direction,before);
   Check("simple_survives_unrelated_complete_"+Key(upper,lower,direction),before.lower_structure_confirmed && before.lower_recognition=="SIMPLE_REACTION_BREAK" && before.trigger_known_at==start+8*PeriodSeconds(lower),
         "A later complete countertrend away from the deepest W2 cannot replace the valid original simple reaction");
   W33Event discarded[];
   engine.Drain(discarded);
   for(int i=14;i<ArraySize(prices);i++) FeedPrice(engine,lower,start,i,prices[i],direction);
   W33Setup s;
   engine.GetActive(direction,s);
   W33Event events[];
   engine.Drain(events);
   Check("simple_no_rejection_churn_"+Key(upper,lower,direction),s.lower_structure_confirmed && s.lower_recognition=="SIMPLE_REACTION_BREAK" && s.trigger_line_price==before.trigger_line_price && s.trigger_known_at==before.trigger_known_at && Count(events,"LOWER_STRUCTURE_LOST")==0 && Count(events,"LOWER_STRUCTURE_CONFIRMED")==0,
         "Repeated rejection of unrelated full structures leaves first-reaction price, availability and state unchanged");
   Check("unrelated_complete_measured_once_per_key_"+Key(upper,lower,direction),Count(events,"LOWER_STRUCTURE_REJECTED")>0 && !s.signal_emitted,
         "Rejected alternative structures remain measured without silently replacing the accepted simple route");
  }
void TestFinishUnordered(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   // Generate an actual second upper structural break after the old signal.
   // This checks lane availability, not merely an active flag in isolation.
   double nextUpper[]={118,119,117,114,110,113,115,117,114,109,105,108,112,118};
   for(int mode=0;mode<3;mode++)
     {
      CWave33Engine engine;
      Configure(engine,upper,lower,W33_NORMALIZED_OR_SIMPLE);
      UpperSeed(engine,upper,direction);
      datetime start=g_base+20*PeriodSeconds(upper);
      if(mode==0)
        {
         W33Setup candidate;
         engine.GetActive(direction,candidate);
         Check("untriggered_not_finished_"+Key(upper,lower,direction),!engine.FinishUnordered(candidate.setup_id,start,"TEST_FINAL_RISK_SKIP"),
               "An ordinary untriggered candidate is not released by the final-order-failure API");
        }
      SimpleSeed(engine,lower,start,direction,9);
      W33Setup before;
      engine.GetActive(direction,before);
      datetime finishedAt=before.signal_known_at+PeriodSeconds(lower);
      W33Event discarded[];
      engine.Drain(discarded);
      bool released=false;
      if(mode==0)
        {
         Check("unordered_rejects_backdated_finish_"+Key(upper,lower,direction),!engine.FinishUnordered(before.setup_id,before.signal_known_at-1,"TEST_FINAL_RISK_SKIP"),
               "A final rejection cannot be published before the signal was known");
         released=engine.FinishUnordered(before.setup_id,finishedAt,"TEST_FINAL_RISK_SKIP");
         W33Setup ended;
         bool active=engine.GetActive(direction,ended);
         Check("unordered_release_once_"+Key(upper,lower,direction),before.signal_emitted && released && !active && !ended.position_open && ended.entry_status=="UNORDERED_COMPLETED",
               "A genuine signaled, unfilled final risk rejection ends the candidate and frees its direction lane");
         bool repeated=engine.FinishUnordered(before.setup_id,finishedAt+PeriodSeconds(lower),"TEST_REPEATED_SKIP");
         W33Event events[];
         engine.Drain(events);
         Check("unordered_finish_idempotent_"+Key(upper,lower,direction),!repeated && Count(events,"COMPLETED")==1,
               "Repeated handling of the same final rejection cannot publish another completion");
         bool knowledge=false;
         for(int j=0;j<ArraySize(events);j++)
            if(events[j].event_type=="COMPLETED")
               knowledge=events[j].at==finishedAt && events[j].reason=="TEST_FINAL_RISK_SKIP" &&
                         events[j].setup.signal_at==before.signal_at && events[j].setup.signal_known_at==before.signal_known_at &&
                         events[j].setup.trigger_known_at==before.trigger_known_at && events[j].setup.lower_pivot_times==before.lower_pivot_times &&
                         events[j].setup.wave1_peak_known_at==before.wave1_peak_known_at;
         Check("unordered_finish_preserves_knowledge_"+Key(upper,lower,direction),knowledge,
               "Completion is observed now while original signal, trigger, pivot and W1 availability remain historical facts");
        }
      if(mode==2)
        {
         engine.MarkExecution(before.setup_id,true,finishedAt);
         released=engine.FinishUnordered(before.setup_id,finishedAt+PeriodSeconds(lower),"TEST_FINAL_RISK_SKIP");
         W33Setup open;
         bool active=engine.GetActive(direction,open);
         Check("open_position_not_released_"+Key(upper,lower,direction),!released && active && open.position_open && open.setup_id==before.setup_id,
               "An open position is never completed or detached by the unordered-failure API");
        }
      // The future upper stream starts after all lower signal/rejection times.
      for(int j=0;j<ArraySize(nextUpper);j++)
        {
         MqlRates b;
         MakeBar(b,g_base+(26+j)*PeriodSeconds(upper),nextUpper[j],direction);
         engine.Feed(upper,b,b.time+PeriodSeconds(upper));
        }
      W33Setup after;
      bool active=engine.GetActive(direction,after);
      W33Event events[];
      engine.Drain(events);
      if(mode==0)
         Check("unordered_release_allows_new_candidate_"+Key(upper,lower,direction),active && after.setup_id!=before.setup_id && !after.signal_emitted && after.candidate_detected_at==g_base+40*PeriodSeconds(upper),
               "After final rejection, the next independent structural break can own the lane");
      else
        {
         string prefix=mode==1 ? "diagnostic_lane_held_" : "position_lane_held_";
         bool busySkip=false;
         for(int j=0;j<ArraySize(events);j++)
            if(events[j].event_type=="SKIP" && events[j].reason=="ACTIVE_SETUP_SAME_DIRECTION") busySkip=true;
         Check(prefix+Key(upper,lower,direction),active && after.setup_id==before.setup_id && busySkip && after.position_open==(mode==2),
               "Without final failure the diagnostic monitor or open position still owns its lane; no duplicate setup is adopted");
        }
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
         TestSimpleAndStrict(upper,lower,direction);
         TestNormalization(upper,lower,direction);
         TestAmbiguousOutsidePivot(upper,lower,direction);
         TestSimpleNewExtreme(upper,lower,direction);
         TestDelayedKnowledgeAndFrozenReaction(upper,lower,direction);
         TestNoFreshCrossAfterDelayedKnowledge(upper,lower,direction);
         TestSimpleTrendlineMode(upper,lower,direction);
         TestCompleteStructurePriority(upper,lower,direction);
         TestUnrelatedCompleteDoesNotChurnSimple(upper,lower,direction);
         TestFinishUnordered(upper,lower,direction);
        }
     }
   FileWrite(g_file,"FINAL",g_failed==0 ? "PASS" : "FAIL",StringFormat("passed=%d failed=%d",g_passed,g_failed));
   FileFlush(g_file); FileClose(g_file); g_file=INVALID_HANDLE;
   PrintFormat("W33_RECOGNITION_HARNESS_FINAL passed=%d failed=%d",g_passed,g_failed);
   return INIT_SUCCEEDED;
  }
void OnTick() { if(MQLInfoInteger(MQL_TESTER)) TesterStop(); }
double OnTester() { return g_failed==0 ? 1.0 : 0.0; }
