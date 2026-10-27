#property strict
#property version "1.00"
#property description "Actual-engine conditional W1 extension tests; closed synthetic OHLC, no orders."
#include "../../Include/Wave33Visual/Engine.mqh"
#include "../../Include/Wave33Visual/BarOrder.mqh"

input string InpRunTag="extension";
int g_file=INVALID_HANDLE,g_passed=0,g_failed=0;
datetime g_base=D'2025.06.02 00:00:00';

void Check(const string name,const bool passed,const string detail)
  {
   if(passed) g_passed++; else g_failed++;
   if(g_file!=INVALID_HANDLE) FileWrite(g_file,name,passed ? "PASS" : "FAIL",detail);
   Print("W33_EXTENSION_TEST ",passed ? "PASS " : "FAIL ",name," ",detail);
  }
string Key(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  { return EnumToString(upper)+"_"+EnumToString(lower)+"_"+W33DirectionName(direction); }
void Bar(MqlRates &b,const datetime at,const double price,const int direction,
         const double high=0,const double low=0)
  {
   ZeroMemory(b);
   double h=high==0 ? price+0.3 : high,l=low==0 ? price-0.3 : low;
   b.time=at; b.open=direction>0 ? price-0.1 : 220-price+0.1;
   b.close=direction>0 ? price : 220-price;
   b.high=direction>0 ? h : 220-l; b.low=direction>0 ? l : 220-h;
   b.tick_volume=100; b.spread=10;
  }
void Configure(CWave33Engine &e,const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,
               const bool enabled=true,const bool setter=true)
  {
   e.Configure(u,l,2,2,0.382,0.618,96,false,true);
   e.SetPoint(0.01); e.SetLifecyclePolicy(true);
   e.SetLowerRecognition(W33_NORMALIZED_OR_SIMPLE); e.SetTriggerMode(W33_PIVOT_BREAK);
   e.SetDeepFibClosePolicy(false);
   if(setter) e.SetWave1ExtensionPolicy(enabled);
   e.Reset("EXTENSION_SYNTHETIC");
  }
void Feed(CWave33Engine &e,const ENUM_TIMEFRAMES tf,const int index,const double price,
          const int direction,const datetime known=0,const double high=0,const double low=0)
  {
   MqlRates b; Bar(b,g_base+index*PeriodSeconds(tf),price,direction,high,low);
   e.Feed(tf,b,known==0 ? b.time+PeriodSeconds(tf) : known);
  }
void Seed(CWave33Engine &e,const ENUM_TIMEFRAMES u,const int d,const int last=19,const int first=0)
  {
   double p[]={110,112,115,112,108,105,108,110,112,109,104,100,104,107,110,114,117,120,118,116};
   for(int i=first;i<=last;i++) Feed(e,u,i,p[i],d);
  }
int Count(const W33Event &events[],const string type,const string id="")
  {
   int n=0;
   for(int i=0;i<ArraySize(events);i++)
      if(events[i].event_type==type && (id=="" || events[i].setup.setup_id==id)) n++;
   return n;
  }
bool Cleared(const W33Setup &s)
  {
   return !s.wave1_peak_fixed && s.wave1_peak_time==0 && s.wave1_peak_price==0 && s.wave1_peak_known_at==0 &&
          s.fib_382_price==0 && s.fib_618_price==0 && !s.fib_touched && s.fib_touch_at==0 && s.fib_close_bar_time==0 &&
          s.wave2_start_time==0 && s.wave2_extreme_time==0 && s.wave2_extreme_price==0 && s.retracement_ratio==0 &&
          !s.lower_structure_confirmed && s.lower_structure_known_at==0 && s.lower_wave2_time==0 &&
          s.trigger_known_at==0 && s.trigger_line_price==0 && s.pivot_trigger_at==0 && s.trendline_trigger_at==0 &&
          !s.signal_emitted && s.signal_at==0 && s.entry_price==0 && s.sl_price==0 && s.tp_price==0;
  }
void TestExtensionAndRepeat(const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const int d)
  {
   CWave33Engine e; Configure(e,u,l); Seed(e,u,d);
   W33Setup initial; bool seeded=e.GetActive(d,initial);
   Check("initial_fixed_"+Key(u,l,d),seeded && initial.wave1_peak_fixed && !initial.wave1_extension_locked && initial.wave1_revision==0,
         "The known upper pivot fixes one initial endpoint while all closed pullbacks remain shallower than minimum Fib");
   int ratio=PeriodSeconds(u)/PeriodSeconds(l);
   for(int j=0;j<ratio;j++) Feed(e,l,19*ratio+j,116.0+0.1*(j%2),d,g_base+20*PeriodSeconds(u));
   W33Setup prior; e.GetActive(d,prior);
   W33Event discarded[]; e.Drain(discarded);
   Feed(e,u,20,123,d);
   W33Setup pending; bool active=e.GetActive(d,pending);
   W33Event started[]; e.Drain(started);
   Check("shallow_new_extreme_starts_"+Key(u,l,d),active && pending.wave1_revision==1 && pending.wave1_extension_pending &&
         pending.wave1_extension_started_at==g_base+21*PeriodSeconds(u) && pending.wave1_extension_known_at==0,
         "A later closed upper directional extreme starts one extension at current availability");
   Check("identity_origin_age_preserved_"+Key(u,l,d),pending.setup_id==initial.setup_id && pending.wave1_start_time==initial.wave1_start_time &&
         pending.wave1_start_price==initial.wave1_start_price && pending.candidate_detected_at==initial.candidate_detected_at &&
         pending.upper_bars_elapsed==prior.upper_bars_elapsed+1,
         "Extending an endpoint does not invent a new setup, origin, candidate time or timeout budget");
   Check("old_anchor_evidence_"+Key(u,l,d),pending.wave1_previous_peak_time==initial.wave1_peak_time &&
         pending.wave1_previous_peak_known_at==initial.wave1_peak_known_at && pending.wave1_previous_peak_price==initial.wave1_peak_price &&
         Count(started,"WAVE1_EXTENSION_PREVIOUS_ANCHORS",initial.setup_id)==1 && Count(started,"WAVE1_EXTENSION_STARTED",initial.setup_id)==1,
         "The old full snapshot is emitted once and its endpoint remains separately identifiable");
   Check("pending_reset_"+Key(u,l,d),Cleared(pending),
         "A pending extension clears old fixed Fib, W2, lower-trigger and risk anchors rather than reusing them");
   bool ordered=false;
   for(int j=1;j<ArraySize(started);j++)
      if(started[j].event_type=="WAVE1_EXTENSION_STARTED")
         ordered=started[j-1].event_type=="WAVE1_EXTENSION_PREVIOUS_ANCHORS" && started[j-1].setup.wave1_revision==0 &&
                 started[j-1].setup.wave1_peak_price==initial.wave1_peak_price && started[j].setup.wave1_revision==1;
   Check("snapshot_before_revision_"+Key(u,l,d),ordered,"Old anchors precede the new revision in actual event order");
   Feed(e,u,21,122,d); e.GetActive(d,pending);
   Check("right_bars_not_yet_closed_"+Key(u,l,d),pending.wave1_extension_pending && !pending.wave1_peak_fixed,
         "One closed right candle cannot establish a two-right-candle endpoint");
   Feed(e,u,22,121,d);
   W33Setup fixed; e.GetActive(d,fixed);
   W33Event confirmed[]; e.Drain(confirmed);
   Check("extension_confirmed_causally_"+Key(u,l,d),fixed.wave1_peak_fixed && !fixed.wave1_extension_pending && fixed.wave1_revision==1 &&
         fixed.wave1_peak_time==g_base+20*PeriodSeconds(u) && fixed.wave1_peak_known_at==g_base+23*PeriodSeconds(u) &&
         fixed.wave1_extension_known_at==fixed.wave1_peak_known_at && MathAbs(fixed.wave1_peak_price-(d>0 ? 123.3 : 96.7))<1e-9,
         "The new candle location and actual two-right-candle availability are distinct");
   double span=d*(fixed.wave1_peak_price-fixed.wave1_start_price);
   Check("fib_recomputed_from_same_origin_"+Key(u,l,d),MathAbs(fixed.fib_382_price-(fixed.wave1_peak_price-d*span*0.382))<1e-9 &&
         MathAbs(fixed.fib_618_price-(fixed.wave1_peak_price-d*span*0.618))<1e-9 &&
         fixed.wave2_start_time==g_base+21*PeriodSeconds(u) && fixed.wave2_extreme_time==0 && fixed.trigger_known_at==0,
         "A new Fib/W2 epoch begins after the new peak candle; old lower candles cannot populate it");
   Check("extension_not_new_opposite_wave_event_"+Key(u,l,d),Count(confirmed,"WAVE1_EXTENDED_CONFIRMED",initial.setup_id)==1 &&
         Count(confirmed,"WAVE1_PEAK_CONFIRMED",initial.setup_id)==0 && Count(started,"WAVE1_PEAK_CONFIRMED",initial.setup_id)==0,
         "Reconfirmation has a distinct event type and cannot masquerade as a newly confirmed opposite first wave");
   Feed(e,u,23,126,d); Feed(e,u,24,125,d); Feed(e,u,25,124,d); e.GetActive(d,fixed);
   Check("repeated_extension_"+Key(u,l,d),fixed.wave1_revision==2 && fixed.wave1_peak_fixed &&
         fixed.wave1_peak_time==g_base+23*PeriodSeconds(u) && fixed.wave1_peak_known_at==g_base+26*PeriodSeconds(u) &&
         fixed.setup_id==initial.setup_id && fixed.wave1_start_price==initial.wave1_start_price,
         "A second shallow continuation can extend again without changing setup identity or origin");
  }
void TestOffAndInputSafety(const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const int d)
  {
   for(int setter=0;setter<2;setter++)
     {
      CWave33Engine e; Configure(e,u,l,false,setter==1); Seed(e,u,d);
      W33Setup before; e.GetActive(d,before);
      W33Event discarded[]; e.Drain(discarded);
      Feed(e,u,20,123,d); Feed(e,u,21,122,d); Feed(e,u,22,121,d);
      W33Setup after; e.GetActive(d,after);
      W33Event events[]; e.Drain(events);
      Check("off_control_setter"+IntegerToString(setter)+"_"+Key(u,l,d),after.wave1_revision==0 && !after.wave1_extension_pending &&
            after.wave1_peak_price==before.wave1_peak_price && after.wave1_peak_known_at==before.wave1_peak_known_at &&
            Count(events,"WAVE1_EXTENSION_STARTED")==0 && Count(events,"WAVE1_EXTENSION_LOCKED")==0,
            "Both an explicit OFF and the constructor default preserve the existing fixed-anchor behavior");
     }
   CWave33Engine e; Configure(e,u,l); Seed(e,u,d);
   MqlRates b; Bar(b,g_base+20*PeriodSeconds(u),123,d);
   bool forming=e.Feed(u,b,b.time+PeriodSeconds(u)-1);
   W33Setup s; e.GetActive(d,s);
   Check("forming_upper_rejected_"+Key(u,l,d),!forming && s.wave1_revision==0,"A forming upper candle cannot start an extension");
   datetime delayed=b.time+4*PeriodSeconds(u); e.Feed(u,b,delayed);
   e.GetActive(d,s);
   Check("delayed_extension_not_backdated_"+Key(u,l,d),s.wave1_extension_started_at==delayed && s.wave1_revision==1,
         "Late delivery of an already closed upper bar publishes the extension only at current knowledge time");
   bool duplicate=e.Feed(u,b,delayed+1); e.GetActive(d,s);
   Check("duplicate_upper_no_revision_"+Key(u,l,d),!duplicate && s.wave1_revision==1 && s.wave1_extension_started_at==delayed,
         "Replayed upper input cannot increment or backdate a revision");
   Feed(e,u,21,122,d,delayed+PeriodSeconds(u)); Feed(e,u,22,121,d,delayed+2*PeriodSeconds(u));
   e.GetActive(d,s);
   Check("delayed_confirmation_current_known_"+Key(u,l,d),s.wave1_peak_known_at==delayed+2*PeriodSeconds(u) &&
         s.wave1_peak_time==b.time && s.wave1_extension_known_at==s.wave1_peak_known_at,
         "A delayed pivot uses the actual last right-candle availability rather than its theoretical close time");
  }
void TestFibLocks(const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const int d)
  {
   for(int source=0;source<4;source++)
     {
      CWave33Engine e; Configure(e,u,l); Seed(e,u,d);
      W33Setup before; e.GetActive(d,before);
      int r=PeriodSeconds(u)/PeriodSeconds(l);
      if(source<2) Feed(e,l,20*r,source==0 ? 112 : 105,d);
      else Feed(e,u,20,source==2 ? 112 : 123,d,0,123.3,112.0);
      W33Setup locked; bool active=e.GetActive(d,locked);
      datetime lockKnown=locked.wave1_extension_lock_known_at;
      Check("qualifying_fib_lock_source"+IntegerToString(source)+"_"+Key(u,l,d),active && locked.wave1_extension_locked && lockKnown>0 &&
            locked.wave1_revision==0 && locked.wave1_peak_price==before.wave1_peak_price,
            "Lower band touch, lower gap beyond band, upper touch and ambiguous upper extreme all stop future extension");
      if(source==3)
         Check("ambiguous_ohlc_no_assumed_order_"+Key(u,l,d),locked.wave1_extension_lock_reason=="AMBIGUOUS_EXTREME_AND_FIB_TOUCH" && !locked.wave1_extension_pending,
               "A single upper candle containing both old minimum Fib and a new extreme never invents their intrabar order");
      Feed(e,u,21,124,d); Feed(e,u,22,123,d); Feed(e,u,23,122,d);
      W33Setup after; e.GetActive(d,after);
      Check("fib_lock_sticky_source"+IntegerToString(source)+"_"+Key(u,l,d),after.wave1_extension_locked && after.wave1_extension_lock_known_at==lockKnown &&
            after.wave1_revision==0 && after.wave1_peak_price==before.wave1_peak_price,
            "Once a meaningful pullback was observable, later directional continuation cannot relabel the potential third wave as W1");
     }
  }
void TestHistoricalKnowledge(const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const int d)
  {
   for(int source=0;source<2;source++)
     {
      CWave33Engine e; Configure(e,u,l); Seed(e,u,d,17);
      int ratio=PeriodSeconds(u)/PeriodSeconds(l);
      if(source==0) Feed(e,l,18*ratio,112,d);
      Feed(e,u,18,118,d,0,118.3,source==1 ? 112 : 117.7); Seed(e,u,d,19,19);
      W33Setup s; e.GetActive(d,s);
      Check("old_history_lock_known_after_peak_source"+IntegerToString(source)+"_"+Key(u,l,d),s.wave1_peak_fixed && s.wave1_extension_locked &&
            s.wave1_extension_lock_bar_time==g_base+18*PeriodSeconds(u) && s.wave1_extension_lock_known_at==g_base+20*PeriodSeconds(u),
            "A source candle preceding endpoint confirmation is classified only when that anchor becomes knowable");
      Feed(e,u,20,123,d); e.GetActive(d,s);
      Check("old_history_prevents_extension_source"+IntegerToString(source)+"_"+Key(u,l,d),s.wave1_revision==0 && !s.wave1_extension_pending,
            "Pre-confirmation source history is not omitted from the first-touch lock");
     }
   CWave33Engine e; Configure(e,u,l); Seed(e,u,d); Feed(e,u,20,123,d);
   int ratio=PeriodSeconds(u)/PeriodSeconds(l);
   Feed(e,l,21*ratio,114,d); Feed(e,u,21,122,d); Feed(e,u,22,121,d);
   W33Setup s; e.GetActive(d,s); W33Event events[]; e.Drain(events);
   bool noHistoricalSignal=true;
   for(int j=0;j<ArraySize(events);j++) if(events[j].event_type=="SIGNAL") noHistoricalSignal=false;
   Check("new_epoch_history_classified_now_"+Key(u,l,d),s.wave1_revision==1 && s.wave1_peak_fixed && s.wave1_extension_locked &&
         s.wave1_extension_lock_bar_time==g_base+21*PeriodSeconds(u) && s.wave1_extension_lock_known_at==g_base+23*PeriodSeconds(u) &&
         s.wave2_extreme_time==g_base+21*PeriodSeconds(u) && s.wave2_extreme_known_at==g_base+23*PeriodSeconds(u) && noHistoricalSignal,
         "A pullback observed while the new peak was provisional is characterized against the new anchor only now, with no retroactive signal");
  }
void TestSignalPositionAndExpired(const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const int d)
  {
   for(int mode=0;mode<3;mode++)
     {
      CWave33Engine e; Configure(e,u,l); Seed(e,u,d);
      double p[]={116,114,110,111,113,115,113,112,113,116};
      int ratio=PeriodSeconds(u)/PeriodSeconds(l);
      for(int j=0;j<ArraySize(p);j++) Feed(e,l,20*ratio+j,p[j],d);
      W33Setup before; e.GetActive(d,before);
      Check("real_signal_precondition_mode"+IntegerToString(mode)+"_"+Key(u,l,d),before.signal_emitted,
            "Signal/position tests use the actual lower reversal engine rather than fabricated snapshots");
      if(mode>0) e.MarkExecution(before.setup_id,mode==1,before.signal_known_at);
      W33Event discarded[]; e.Drain(discarded);
      Feed(e,u,26,123,d); Feed(e,u,27,122,d); Feed(e,u,28,121,d);
      W33Setup after; bool active=e.GetActive(d,after); W33Event events[]; e.Drain(events);
      Check("postsignal_or_completed_anchor_frozen_mode"+IntegerToString(mode)+"_"+Key(u,l,d),active==(mode!=2) &&
            after.wave1_peak_price==before.wave1_peak_price && after.wave1_peak_known_at==before.wave1_peak_known_at && after.wave1_revision==0 &&
            Count(events,"WAVE1_EXTENSION_STARTED",before.setup_id)==0,
            "An emitted signal, an open position and a completed setup retain their original trading anchors");
     }
   CWave33Engine e; Configure(e,u,l); Seed(e,u,d);
   W33Setup before; e.GetActive(d,before);
   Feed(e,u,20,99,d); W33Setup expired; bool active=e.GetActive(d,expired);
   Feed(e,u,21,123,d); W33Event events[]; e.Drain(events);
   Check("invalidated_not_resurrected_"+Key(u,l,d),!active && expired.skip_reason=="WAVE1_ORIGIN_BROKEN" &&
         Count(events,"WAVE1_EXTENSION_STARTED",before.setup_id)==0,
         "A terminally broken origin cannot be resurrected through endpoint extension");
  }
void TestSameClockUpperPriority(const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const int d)
  {
   CWave33Engine e; Configure(e,u,l); Seed(e,u,d);
   MqlRates b[]; ENUM_TIMEFRAMES frames[]; ArrayResize(b,2); ArrayResize(frames,2);
   datetime known=g_base+21*PeriodSeconds(u);
   Bar(b[0],known-PeriodSeconds(l),112,d); frames[0]=l;
   Bar(b[1],known-PeriodSeconds(u),123,d,123.3,112); frames[1]=u;
   W33SortClosedBars(b,frames);
   for(int j=0;j<2;j++) e.Feed(frames[j],b[j],known);
   W33Setup s; e.GetActive(d,s);
   Check("same_clock_shared_upper_first_"+Key(u,l,d),frames[0]==u && s.wave1_extension_locked && s.wave1_revision==0 &&
         s.wave1_extension_lock_known_at==known && s.wave1_extension_lock_reason=="AMBIGUOUS_EXTREME_AND_FIB_TOUCH",
         "The shared scheduler inspects the full upper OHLC before the simultaneous lower close can alter the epoch");
  }
void TestPendingTrackingAndConfiguredMinimum(const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const int d)
  {
   CWave33Engine e; Configure(e,u,l); Seed(e,u,d); Feed(e,u,20,123,d);
   W33Event discarded[]; e.Drain(discarded);
   Feed(e,u,21,124,d); Feed(e,u,22,123,d);
   W33Setup tracking; e.GetActive(d,tracking);
   W33Event events[]; e.Drain(events);
   Check("pending_new_extreme_restarts_right_window_"+Key(u,l,d),tracking.wave1_extension_pending && !tracking.wave1_peak_fixed &&
         tracking.wave1_revision==1 && tracking.wave1_provisional_time==g_base+21*PeriodSeconds(u) &&
         Count(events,"WAVE1_EXTENSION_TRACKING")==1 && Count(events,"WAVE1_EXTENDED_CONFIRMED")==0,
         "A more extreme closed upper candle during pending tracking moves only the provisional endpoint and restarts its confirmation window");
   Feed(e,u,23,122,d); e.GetActive(d,tracking);
   Check("tracked_peak_confirms_at_actual_right_close_"+Key(u,l,d),tracking.wave1_peak_fixed && tracking.wave1_peak_time==g_base+21*PeriodSeconds(u) &&
         tracking.wave1_peak_known_at==g_base+24*PeriodSeconds(u) && tracking.wave1_revision==1,
         "The eventual fixed endpoint uses the most extreme tracked candle and waits for both following closed candles");
   CWave33Engine custom; Configure(custom,u,l); custom.Configure(u,l,2,2,0.5,0.7,96,false,true); Seed(custom,u,d);
   int r=PeriodSeconds(u)/PeriodSeconds(l);
   Feed(custom,l,20*r,112,d); W33Setup s; custom.GetActive(d,s);
   Check("configured_minimum_not_hardcoded_"+Key(u,l,d),!s.wave1_extension_locked && !s.fib_touched,
         "A 41 percent pullback remains shallow when the user explicitly configures minimum Fib at 50 percent");
   Feed(custom,u,21,123,d); custom.GetActive(d,s);
   Check("configured_minimum_extension_allowed_"+Key(u,l,d),s.wave1_revision==1 && s.wave1_extension_pending,
         "The extension gate follows the configured minimum rather than silently fixing a new 38.2 percent trading rule");
   for(int near=0;near<2;near++)
     {
      CWave33Engine boundary; Configure(boundary,u,l); Seed(boundary,u,d); boundary.GetActive(d,s);
      double normalized=d>0 ? s.fib_382_price : 220-s.fib_382_price;
      double low=normalized+(near==0 ? 0.0 : 0.00001);
      Feed(boundary,l,20*r,low+0.3,d,0,low+0.6,low); boundary.GetActive(d,s);
      Check("minimum_boundary_near"+IntegerToString(near)+"_"+Key(u,l,d),s.wave1_extension_locked==(near==0),
            "Exact minimum-Fib equality locks; a genuinely shallower tradable difference remains eligible");
     }
  }
int OnInit()
  {
   g_file=FileOpen("W33Harness_"+InpRunTag+".csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(g_file==INVALID_HANDLE) return INIT_FAILED;
   FileWrite(g_file,"test","passed","detail");
   for(int pair=0;pair<2;pair++)
     {
      ENUM_TIMEFRAMES u=pair==0 ? PERIOD_M15 : PERIOD_M5,l=pair==0 ? PERIOD_M5 : PERIOD_M1;
      for(int d=1;d>=-1;d-=2)
        {
         TestExtensionAndRepeat(u,l,d); TestOffAndInputSafety(u,l,d); TestFibLocks(u,l,d);
         TestHistoricalKnowledge(u,l,d); TestSignalPositionAndExpired(u,l,d); TestSameClockUpperPriority(u,l,d);
         TestPendingTrackingAndConfiguredMinimum(u,l,d);
        }
     }
   FileWrite(g_file,"FINAL",g_failed==0 ? "PASS" : "FAIL",StringFormat("passed=%d failed=%d",g_passed,g_failed));
   FileFlush(g_file); FileClose(g_file); g_file=INVALID_HANDLE;
   PrintFormat("W33_EXTENSION_HARNESS_FINAL passed=%d failed=%d",g_passed,g_failed);
   return INIT_SUCCEEDED;
  }
void OnTick() { if(MQLInfoInteger(MQL_TESTER)) TesterStop(); }
double OnTester() { return g_failed==0 ? 1.0 : 0.0; }
