#property strict
#property version "1.00"
#property description "Deterministic tests of the actual causal Wave33 engine; synthetic OHLC, no orders."
#include "../../Include/Wave33Visual/Engine.mqh"

input string InpRunTag="harness";
int g_file=INVALID_HANDLE,g_passed=0,g_failed=0;
datetime g_base=D'2025.06.02 00:00:00';

void Check(const string name,const bool passed,const string detail)
  {
   if(passed) g_passed++; else g_failed++;
   if(g_file!=INVALID_HANDLE) FileWrite(g_file,name,passed ? "PASS" : "FAIL",detail);
   Print("W33_TEST ",passed ? "PASS " : "FAIL ",name," ",detail);
  }
void MakeBar(MqlRates &b,const datetime at,const double price,const int direction=1)
  {
   ZeroMemory(b);
   double p=direction>0 ? price : 220.0-price;
   b.time=at; b.open=p-0.1*direction; b.close=p;
   b.high=p+0.3; b.low=p-0.3;
   b.tick_volume=100; b.spread=10;
  }
void Configure(CWave33Engine &engine,const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,
               const W33TriggerMode mode=W33_PIVOT_BREAK,const int timeout=96,const bool rejectDeep=false)
  {
   engine.Configure(upper,lower,2,2,0.382,0.618,timeout,rejectDeep,true);
   engine.SetTriggerMode(mode); engine.SetPoint(0.01); engine.Reset("SYNTHETIC");
  }
void UpperSeed(CWave33Engine &engine,const ENUM_TIMEFRAMES upper,const int direction,const int last=19,const int first=0)
  {
   double prices[]={110,112,115,112,108,105,108,110,112,109,104,100,104,107,110,114,117,120,118,116};
   int seconds=PeriodSeconds(upper);
   for(int i=first;i<=last;i++)
     {
      MqlRates bar;
      MakeBar(bar,g_base+i*seconds,prices[i],direction);
      engine.Feed(upper,bar,bar.time+seconds);
     }
  }
void LowerSeed(CWave33Engine &engine,const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction)
  {
   double prices[]={117,118,119,117,115,113,114,115,116,114,112,110,111,112,114,117};
   datetime start=g_base+20*PeriodSeconds(upper);
   int seconds=PeriodSeconds(lower);
   for(int i=0;i<ArraySize(prices);i++)
     {
      MqlRates bar;
      MakeBar(bar,start+i*seconds,prices[i],direction);
      engine.Feed(lower,bar,bar.time+seconds);
     }
  }
void TestPivotDelay()
  {
   CWave33Series series;
   series.Reset(PERIOD_M5);
   double prices[]={110,111,115,112,111};
   W33Pivot confirmed[];
   for(int i=0;i<5;i++)
     {
      MqlRates bar;
      MakeBar(bar,g_base+i*300,prices[i]);
      series.Append(bar,bar.time+300,2,2,confirmed);
      if(i<4) Check("pivot_no_early_"+IntegerToString(i),ArraySize(confirmed)==0,"Right-hand candles not all closed");
     }
   bool good=ArraySize(confirmed)==1;
   if(good) good=confirmed[0].time==g_base+600 && confirmed[0].known_at==g_base+1500 && confirmed[0].is_high;
   Check("pivot_exact_delay",good,"Swing at index 2 first known at close of index 4");
   MqlRates unfinished;
   MakeBar(unfinished,g_base+1500,112);
   Check("unfinished_bar_rejected",!series.Append(unfinished,unfinished.time+299,2,2,confirmed),"No forming candle accepted");
   MakeBar(unfinished,g_base+1200,111);
   Check("duplicate_bar_rejected",!series.Append(unfinished,unfinished.time+300,2,2,confirmed),"No duplicate/out-of-order candle accepted");
  }
void TestSignal(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int direction,const W33TriggerMode mode)
  {
   CWave33Engine engine;
   Configure(engine,upper,lower,mode);
   UpperSeed(engine,upper,direction);
   LowerSeed(engine,upper,lower,direction);
   W33Event events[];
   engine.Drain(events);
   int signals=0,states=0;
   bool causal=true,foundPeak=false,foundFib=false,foundStructure=false,preSignalLine=false;
   W33Setup signal;
   ZeroMemory(signal);
   for(int i=0;i<ArraySize(events);i++)
     {
      if(events[i].event_type=="WAVE1_PEAK_CONFIRMED") foundPeak=true;
      if(events[i].event_type=="FIB_TOUCH") foundFib=true;
      if(events[i].event_type=="STATE") states++;
      if(events[i].event_type=="LOWER_STRUCTURE_CONFIRMED")
        {
         foundStructure=true;
         preSignalLine=events[i].setup.trigger_line_price>0 && events[i].setup.signal_at==0;
        }
      if(events[i].event_type!="SIGNAL") continue;
      signals++; signal=events[i].setup;
      if(signal.direction!=direction || signal.wave1_peak_known_at>signal.trigger_bar_time ||
         signal.lower_structure_known_at>signal.trigger_bar_time || signal.signal_at>signal.signal_known_at ||
         signal.signal_known_at!=events[i].at) causal=false;
     }
   string key=EnumToString(upper)+"_"+EnumToString(lower)+"_"+W33DirectionName(direction)+"_"+IntegerToString((int)mode);
   Check("signal_once_"+key,signals==1,"Actual CWave33Engine signal count="+IntegerToString(signals));
   Check("signal_causal_"+key,causal && signals==1,"Upper and lower anchors known before trigger candle opened");
   Check("state_path_"+key,foundPeak && foundFib && foundStructure && states>=5,"W1 peak, Fib touch, lower structure and reversal/risk states reached");
   Check("pre_signal_line_"+key,preSignalLine,"Pivot decision line exists in pre-signal snapshot");
   W33Setup finalSetup;
   engine.GetActive(direction,finalSetup);
   Check("both_triggers_"+key,finalSetup.pivot_trigger_at>0 && finalSetup.trendline_trigger_at>0 && finalSetup.trendline_trigger_at<finalSetup.pivot_trigger_at,"Same frozen anchors track TL first and later pivot");
   string expected=mode==W33_TRENDLINE_BREAK || mode==W33_FIRST_BREAK ? "TRENDLINE_BREAK" : "PIVOT_BREAK";
   Check("selected_trigger_"+key,signal.trigger_type==expected,"Expected "+expected+", actual "+signal.trigger_type);
   engine.MarkExecution(finalSetup.setup_id,true,finalSetup.signal_known_at+1);
   W33Setup tracking;
   engine.GetActive(direction,tracking);
   Check("position_state_"+key,tracking.state==POSITION_TRACKING && tracking.position_open,"Execution acknowledgement changes observation state");
   engine.MarkExecution(finalSetup.setup_id,false,finalSetup.signal_known_at+2);
   Check("completed_"+key,!engine.GetActive(direction,tracking),"Position completion releases direction lane");
  }
void TestInvalidation(const int direction,const bool rejectDeep,const bool origin)
  {
   CWave33Engine engine;
   Configure(engine,PERIOD_M15,PERIOD_M5,W33_PIVOT_BREAK,96,rejectDeep);
   UpperSeed(engine,PERIOD_M15,direction);
   MqlRates bar;
   MakeBar(bar,g_base+20*900,origin ? 98.0 : 103.0,direction);
   engine.Feed(PERIOD_M5,bar,bar.time+300);
   W33Setup s;
   bool active=engine.GetActive(direction,s);
   string key=W33DirectionName(direction)+(origin ? "_origin" : rejectDeep ? "_deep_reject" : "_deep_measure");
   Check("invalidation_"+key,origin || rejectDeep ? !active : active,"Default deep Fib is measurement; origin and opt-in deep rule exclude");
   Check("reason_"+key,origin ? s.skip_reason=="WAVE1_ORIGIN_BROKEN" : s.fib_too_deep_measured,"Explicit invalidation or deep-Fib measurement retained");
  }
void TestTimeout()
  {
   CWave33Engine engine;
   Configure(engine,PERIOD_M15,PERIOD_M5,W33_PIVOT_BREAK,2);
   UpperSeed(engine,PERIOD_M15,1,17);
   W33Setup s;
   bool active=engine.GetActive(1,s);
   Check("timeout",!active && StringFind(s.skip_reason,"TIMEOUT")>=0,"Two upper closed candles after candidate exhaust configured lifetime");
  }
void TestNoHistoricalTrigger()
  {
   CWave33Engine engine;
   Configure(engine,PERIOD_M15,PERIOD_M1);
   UpperSeed(engine,PERIOD_M15,1,17);
   double prices[]={117,118,119,117,115,113,114,115,116,114,112,110,111,112,114};
   for(int i=0;i<ArraySize(prices);i++)
     {
      MqlRates lower;
      MakeBar(lower,g_base+18*900+i*60,prices[i]);
      engine.Feed(PERIOD_M1,lower,lower.time+60);
     }
   UpperSeed(engine,PERIOD_M15,1,19,18);
   W33Setup s;
   engine.GetActive(1,s);
   Check("historical_seed_current_knowledge",s.lower_structure_confirmed && s.lower_structure_known_at==g_base+20*900 && s.fib_touch_known_at==g_base+20*900,"Old W2 facts become known at peak confirmation, never at past timestamps");
   MqlRates closing;
   MakeBar(closing,g_base+20*900-60,117);
   engine.Feed(PERIOD_M1,closing,g_base+20*900);
   W33Event events[];
   engine.Drain(events);
   int signals=0;
   for(int i=0;i<ArraySize(events);i++) if(events[i].event_type=="SIGNAL") signals++;
   Check("new_peak_no_retroactive_signal",signals==0,"A lower candle closing when upper peak becomes known cannot use that anchor");
  }
void TestLatestPivotAfterOppositeSwing(const int direction)
  {
   CWave33Engine engine;
   Configure(engine,PERIOD_M15,PERIOD_M5);
   UpperSeed(engine,PERIOD_M15,direction);
   double prices[]={117,118,119,117,115,113,114,115,116,114,112,110,111,112,112.5,112,111.8};
   datetime start=g_base+20*900;
   for(int i=0;i<ArraySize(prices);i++)
     {
      MqlRates bar;
      MakeBar(bar,start+i*300,prices[i],direction);
      if(i==14)
        {
         if(direction>0) { bar.high=114.3; bar.low=112.1; }
         else { bar.high=107.9; bar.low=105.7; }
        }
      engine.Feed(PERIOD_M5,bar,bar.time+300);
     }
   W33Setup before;
   engine.GetActive(direction,before);
   double expected=direction>0 ? 114.3 : 105.7;
   string key=W33DirectionName(direction);
   Check("latest_pivot_after_opposite_"+key,before.lower_structure_confirmed && MathAbs(before.trigger_line_price-expected)<0.000001,
         "New LH after LL / new HL after HH updates the active return level");
   MqlRates trigger;
   MakeBar(trigger,start+17*300,115,direction);
   engine.Feed(PERIOD_M5,trigger,trigger.time+300);
   W33Event events[];
   engine.Drain(events);
   int signals=0;
   bool correct=false;
   for(int i=0;i<ArraySize(events);i++)
      if(events[i].event_type=="SIGNAL")
        {
         signals++;
         correct=MathAbs(events[i].setup.trigger_line_price-expected)<0.000001;
        }
   Check("latest_pivot_signal_"+key,signals==1 && correct,"Close beyond newest level signals before the superseded older level");
  }
void TestFutureSuffixInvariance(const int direction)
  {
   CWave33Engine engine;
   Configure(engine,PERIOD_M5,PERIOD_M1);
   UpperSeed(engine,PERIOD_M5,direction);
   LowerSeed(engine,PERIOD_M5,PERIOD_M1,direction);
   W33Event prefix[];
   engine.Drain(prefix);
   W33Setup original;
   engine.GetActive(direction,original);
   string key=W33DirectionName(direction);
   Check("suffix_prefix_has_signal_"+key,original.signal_emitted,"Invariant test starts with an actual emitted engine signal");
   MqlRates duplicate;
   MakeBar(duplicate,g_base+20*300+15*60,117,direction);
   bool accepted=engine.Feed(PERIOD_M1,duplicate,duplicate.time+60);
   W33Event duplicateEvents[];
   int duplicateCount=engine.Drain(duplicateEvents);
   Check("duplicate_trigger_no_event_"+key,!accepted && duplicateCount==0,"Refeeding exact trigger candle cannot emit another decision");
   // Supply genuine future upper extensions that would repaint W1 if peak
   // anchors were still provisional, then break the origin with future LTF data.
   for(int i=23;i<=24;i++)
     {
      MqlRates future;
      MakeBar(future,g_base+i*300,125+(i-23)*5,direction);
      engine.Feed(PERIOD_M5,future,future.time+300);
     }
   W33Setup extended;
   engine.GetActive(direction,extended);
   bool fixed=extended.setup_id==original.setup_id &&
              extended.wave1_peak_time==original.wave1_peak_time &&
              extended.wave1_peak_known_at==original.wave1_peak_known_at &&
              extended.wave1_peak_price==original.wave1_peak_price &&
              extended.wave2_extreme_time==original.wave2_extreme_time &&
              extended.wave2_extreme_price==original.wave2_extreme_price &&
              extended.signal_at==original.signal_at && extended.trigger_bar_time==original.trigger_bar_time;
   Check("future_extension_keeps_anchors_"+key,fixed,"Later higher/lower prices do not rewrite fixed W1, W2, ID or signal timestamps");
   MqlRates opposite;
   MakeBar(opposite,g_base+25*300,98,direction);
   engine.Feed(PERIOD_M1,opposite,opposite.time+60);
   W33Event suffix[];
   engine.Drain(suffix);
   bool noReplay=true;
   for(int i=0;i<ArraySize(suffix);i++)
      if(suffix[i].setup.setup_id==original.setup_id && suffix[i].event_type=="SIGNAL") noReplay=false;
   W33Setup terminal;
   bool terminalActive=engine.GetActive(direction,terminal);
   bool preserved=!terminalActive && terminal.wave1_peak_price==original.wave1_peak_price &&
                  terminal.wave1_peak_known_at==original.wave1_peak_known_at &&
                  terminal.wave2_extreme_price==original.wave2_extreme_price && terminal.signal_at==original.signal_at;
   Check("future_opposite_no_repeat_signal_"+key,noReplay && preserved,"Future origin failure closes monitor and preserves original decision evidence");
   bool prefixPreserved=false;
   for(int i=0;i<ArraySize(prefix);i++)
      if(prefix[i].event_type=="SIGNAL" && prefix[i].setup.setup_id==original.setup_id)
         prefixPreserved=prefix[i].setup.signal_at==original.signal_at && prefix[i].setup.wave1_peak_known_at==original.wave1_peak_known_at &&
                         prefix[i].setup.wave1_peak_price==original.wave1_peak_price && prefix[i].setup.entry_status=="SIGNAL";
   Check("emitted_prefix_snapshot_preserved_"+key,prefixPreserved,"Stored pre-suffix event remains the original SIGNAL after terminal transition");
  }
int OnInit()
  {
   g_file=FileOpen("W33Harness_"+InpRunTag+".csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(g_file==INVALID_HANDLE) { Print("W33 harness cannot create CSV ",GetLastError()); return INIT_FAILED; }
   FileWrite(g_file,"test","passed","detail");
   TestPivotDelay();
   for(int direction=1;direction>=-1;direction-=2)
     {
      TestSignal(PERIOD_M15,PERIOD_M5,direction,W33_PIVOT_BREAK);
      TestSignal(PERIOD_M5,PERIOD_M1,direction,W33_PIVOT_BREAK);
      TestSignal(PERIOD_M5,PERIOD_M1,direction,W33_TRENDLINE_BREAK);
      TestSignal(PERIOD_M5,PERIOD_M1,direction,W33_FIRST_BREAK);
      TestInvalidation(direction,false,false);
      TestInvalidation(direction,true,false);
      TestInvalidation(direction,false,true);
      TestLatestPivotAfterOppositeSwing(direction);
      TestFutureSuffixInvariance(direction);
     }
   TestTimeout();
   TestNoHistoricalTrigger();
   FileWrite(g_file,"FINAL",g_failed==0 ? "PASS" : "FAIL",StringFormat("passed=%d failed=%d",g_passed,g_failed));
   FileFlush(g_file); FileClose(g_file); g_file=INVALID_HANDLE;
   PrintFormat("W33_HARNESS_FINAL passed=%d failed=%d",g_passed,g_failed);
   return INIT_SUCCEEDED;
  }
void OnTick() { if(MQLInfoInteger(MQL_TESTER)) TesterStop(); }
double OnTester() { return g_failed==0 ? 1.0 : 0.0; }
