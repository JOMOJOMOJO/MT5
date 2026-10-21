#property strict
#property version "1.00"
#property description "Finite display lifecycle tests; synthetic events only, no orders."
#include "../../Include/Wave33Visual/Display.mqh"

input string InpRunTag="display_harness";
CWave33Display g_display;
int g_file=INVALID_HANDLE,g_passed=0,g_failed=0;
string g_prefix="W33DisplayTest_";
datetime g_base=D'2025.06.02 00:00:00';

string Obj(const string id,const string suffix){return g_prefix+W33Hash(id)+"_"+suffix;}
int Step(){return (int)MathMax(300,PeriodSeconds((ENUM_TIMEFRAMES)_Period));}
datetime End(const string name){return (datetime)ObjectGetInteger(0,name,OBJPROP_TIME,1);}
void Check(const string name,const bool pass,const string detail)
  {
   if(pass)g_passed++;else g_failed++;
   FileWrite(g_file,name,pass?"PASS":"FAIL",detail);
   Print("W33_DISPLAY_TEST ",pass?"PASS ":"FAIL ",name," ",detail);
  }
void Fixture(W33Setup &s,const string id,const int direction=1)
  {
   ZeroMemory(s);s.setup_id=id;s.symbol=_Symbol;s.upper_tf=PERIOD_M15;s.lower_tf=PERIOD_M5;
   s.direction=direction;s.active=true;s.upper_break_level=3000.0;s.wave1_start_time=g_base-900;
   s.wave1_start_price=2990;s.wave1_peak_time=g_base+600;s.wave1_peak_price=3020;
   s.wave1_peak_known_at=g_base+900;s.fib_382_price=3008.54;s.fib_618_price=3001.46;
   s.trigger_line_price=3006;s.entry_price=3007;s.sl_price=2997;s.tp_price=3017;
   s.nearest_obstacle_price=3020;s.nearest_obstacle_known_at=g_base-1800;
   s.lower_high1_time=g_base+300;s.lower_high2_time=g_base+600;
   s.lower_high1_price=3010;s.lower_high2_price=3008;
   s.lower_low1_time=g_base+300;s.lower_low2_time=g_base+600;
   s.lower_low1_price=2998;s.lower_low2_price=3000;
  }
void Emit(const W33Setup &s,const string type,const datetime at)
  {
   W33Event e;ZeroMemory(e);e.at=at;e.event_type=type;e.setup=s;
   g_display.Event(e);
  }
void ClockEvent(const datetime at)
  {
   W33Event e;ZeroMemory(e);e.at=at;e.event_type="OBSERVED_CLOCK";g_display.Event(e);
  }
void TestCandidatesAndOrders()
  {
   int step=Step();W33Setup a,b;Fixture(a,"A");Fixture(b,"B",-1);
   Emit(a,"WAVE1_BREAK",g_base);Emit(b,"WAVE1_BREAK",g_base+step);
   ClockEvent(g_base+step*3);
   string upper=Obj("A","upper_break"),other=Obj("B","upper_break");
   Check("known_time_start",(datetime)ObjectGetInteger(0,upper,OBJPROP_TIME,0)==g_base,"Decision line starts when first observed");
   Check("live_line_finite",ObjectFind(0,upper)>=0 && !ObjectGetInteger(0,upper,OBJPROP_RAY_RIGHT) && End(upper)==g_base+step*3,"Candidate extends only through known event time");
   Emit(a,"INVALIDATE",g_base+step*4);datetime closed=End(upper);
   ClockEvent(g_base+step*7);
   Check("invalidated_candidate_stops",End(upper)==closed && closed==g_base+step*4,"Past decision evidence remains finite");
   Check("other_candidate_independent",End(other)==g_base+step*7,"Closing A leaves B tracking normally");

   b.wave1_peak_fixed=true;Emit(b,"WAVE1_PEAK_CONFIRMED",g_base+step*8);
   Emit(b,"LOWER_STRUCTURE_CONFIRMED",g_base+step*9);
   string lower="";
   for(int i=0;i<ObjectsTotal(0);i++){string n=ObjectName(0,i);if(StringFind(n,Obj("B","lower_level_"))==0)lower=n;}
   Emit(b,"SIGNAL",g_base+step*10);
   datetime signalEnd=End(other),lowerEnd=End(lower),fibEnd=End(Obj("B","fib")),diagnosticSL=End(Obj("B","SL"));
   Emit(b,"ORDER_DISABLED",g_base+step*10);ClockEvent(g_base+step*14);
   Check("signal_stops_structure",signalEnd==g_base+step*10 && End(other)==signalEnd && End(lower)==lowerEnd,"Signal closes upper and lower decision lines");
   Check("signal_stops_fib",End(Obj("B","fib"))==fibEnd && fibEnd==g_base+step*10,"Fib band stops at entry decision");
   Check("diagnostic_sltp_short",End(Obj("B","SL"))==diagnosticSL && diagnosticSL==g_base+step*11,"Unordered SL stays one chart bar wide");
   Check("diagnostic_obstacle_short",End(Obj("B","obstacle"))==g_base+step*11,"Unordered resistance stays a short marker");

   Emit(b,"ORDER",g_base+step*15);Emit(b,"FILL",g_base+step*15);ClockEvent(g_base+step*19);
   Check("ordered_sltp_track",End(Obj("B","SL"))==g_base+step*19 && End(Obj("B","TP"))==g_base+step*19,"Actual position risk lines follow known market time");
   Emit(b,"COMPLETED",g_base+step*20);ClockEvent(g_base+step*22);
   Check("monitor_end_keeps_position",End(Obj("B","SL"))==g_base+step*22,"Setup monitor ending cannot truncate an open position");
   Emit(b,"EXIT",g_base+step*23);datetime exitEnd=End(Obj("B","SL"));ClockEvent(g_base+step*30);
   Check("exit_stops_sltp",End(Obj("B","SL"))==exitEnd && exitEnd==g_base+step*23 && End(Obj("B","TP"))==exitEnd,"SL and TP end at the observed exit");
   Check("exit_stops_obstacle",End(Obj("B","obstacle"))==exitEnd,"Position resistance ends together with risk lines");
   Check("risk_color_retained",(color)ObjectGetInteger(0,Obj("B","SL"),OBJPROP_COLOR)==clrTomato && (color)ObjectGetInteger(0,Obj("B","TP"),OBJPROP_COLOR)==clrLimeGreen,"Historical stop and target keep their meaning");
   Emit(b,"TEST_END",g_base+step*30);
   Check("late_terminal_cannot_reextend",End(Obj("B","SL"))==exitEnd,"Repeated terminal observations preserve the original exit end");
   // Queued engine acknowledgements retain their earlier observation times
   // even when delivered after the synchronous FILL/EXIT callbacks.
   Emit(b,"POSITION_TRACKING",g_base+step*15);Emit(b,"COMPLETED",g_base+step*23);ClockEvent(g_base+step*30);
   Check("deferred_tracking_cannot_reopen",End(Obj("B","SL"))==exitEnd && End(Obj("B","TP"))==exitEnd,"Delayed engine position acknowledgement after EXIT cannot reopen closed risk lines");
  }
void TestTrendAndEnd()
  {
   int step=Step();W33Setup s;Fixture(s,"TL");g_display.SetTriggerMode(W33_TRENDLINE_BREAK);
   Emit(s,"WAVE1_BREAK",g_base+step*31);s.wave1_peak_fixed=true;
   Emit(s,"LOWER_STRUCTURE_CONFIRMED",g_base+step*32);
   string line="";
   for(int i=0;i<ObjectsTotal(0);i++){string n=ObjectName(0,i);if(StringFind(n,Obj("TL","trendline_"))==0)line=n;}
   ClockEvent(g_base+step*34);
   Check("trendline_finite",line!="" && !ObjectGetInteger(0,line,OBJPROP_RAY_RIGHT) && End(line)==g_base+step*34,"Projected diagonal is finite, too");
   Emit(s,"LOWER_STRUCTURE_LOST",g_base+step*35);datetime ended=End(line);ClockEvent(g_base+step*38);
   Check("lost_trend_stops",End(line)==ended && ended==g_base+step*35,"Replaced or lost trigger stops at its last valid time");
   Emit(s,"ORDER",g_base+step*39);Emit(s,"TEST_END",g_base+step*40);ClockEvent(g_base+step*45);
   Check("test_end_stops_all",End(Obj("TL","upper_break"))==g_base+step*40 && End(Obj("TL","SL"))==g_base+step*40,"Tester stop closes remaining live drawings");
   bool noRays=true;
   for(int i=0;i<ObjectsTotal(0);i++)
     {
      string n=ObjectName(0,i);if(StringFind(n,g_prefix)!=0)continue;
      if((ENUM_OBJECT)ObjectGetInteger(0,n,OBJPROP_TYPE)==OBJ_TREND && ObjectGetInteger(0,n,OBJPROP_RAY_RIGHT))noRays=false;
     }
   Check("all_lines_no_infinite_rays",noRays,"No candidate, trigger, obstacle, SL or TP can extend forever");
  }
void TestSourceTraceAndRoomRejection()
  {
   int step=Step();datetime at=g_base+step*50;W33Setup s;Fixture(s,"TRACE");
   s.candidate_detected_at=g_base;s.nearest_obstacle_time=g_base-3600;
   s.nearest_obstacle_known_at=g_base-2700;s.nearest_obstacle_tf=PERIOD_M5;
   s.nearest_obstacle_source="SWING_LOW";s.nearest_obstacle_is_high=false;s.wave1_room_r=0.10;
   s.wave1_room_rejected=true;s.entry_status="SIGNAL_RISK_REJECTED";
   Emit(s,"SIGNAL",at);Emit(s,"RISK_CHECK",at);
   string obstacle=Obj("TRACE","obstacle"),w1=Obj("TRACE","wave1_room");
   Check("rejected_signal_no_green_entry",ObjectFind(0,Obj("TRACE","entry_text"))<0,"Room rejection is not drawn as an executed entry");
   Check("source_trace_marker_exists",ObjectFind(0,Obj("TRACE","obstacle_source"))>=0,"Selected native source is marked separately");
   Check("ancient_source_line_adoption_start",(datetime)ObjectGetInteger(0,obstacle,OBJPROP_TIME,0)==at,"Old source does not extend through the entire history");
   // This build's nonvisual tester acknowledges TOOLTIP writes but reads an
   // empty string even for a 20-character probe. Verify all three timestamps
   // in the normal-chart recorded replay object inventory, not this harness.
   Check("past_low_labeled_reference",StringFind(ObjectGetString(0,Obj("TRACE","obstacle_label"),OBJPROP_TEXT),"参考")>=0,"An old low above price is not asserted to be important resistance");
   Check("wave1_room_separate",ObjectFind(0,w1)>=0 && StringFind(ObjectGetString(0,Obj("TRACE","wave1_room_label"),OBJPROP_TEXT),"0.10R")>=0,"Fixed W1 boundary has its own room display");
   ClockEvent(at+step*3);
   Check("rejected_references_finite",End(obstacle)==at+step && End(w1)==at+step,"Unordered references stay finite");
   W33Setup future;Fixture(future,"FUTURE");future.nearest_obstacle_time=at+step;
   future.nearest_obstacle_known_at=at+step*2;Emit(future,"RISK_CHECK",at);
   Check("future_obstacle_not_drawn",ObjectFind(0,Obj("FUTURE","obstacle"))<0,"Unknown future source is not drawn");
   W33Setup own;Fixture(own,"OWN_W1");own.nearest_obstacle_source="WAVE1";Emit(own,"SIGNAL",at+step*4);
   Check("wave1_not_duplicated",ObjectFind(0,Obj("OWN_W1","wave1_room"))>=0 && ObjectFind(0,Obj("OWN_W1","obstacle"))<0,"W1 is not repeated as unrelated purple resistance");
   own.entry_status="FILLED";Emit(own,"ORDER",at+step*5);Emit(own,"FILL",at+step*5);
   ClockEvent(at+step*7);Emit(own,"EXIT",at+step*8);datetime ended=End(Obj("OWN_W1","wave1_room"));
   ClockEvent(at+step*11);
   Check("wave1_reference_stops_at_exit",End(Obj("OWN_W1","wave1_room"))==ended && ended==at+step*8,"W1 reference follows and ends with the real position");
  }
int OnInit()
  {
   g_file=FileOpen("W33Harness_"+InpRunTag+".csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(g_file==INVALID_HANDLE)return INIT_FAILED;
   FileWrite(g_file,"test","passed","detail");
   g_display.Init(g_prefix,true);g_display.SetFrames(PERIOD_M15,PERIOD_M5);g_display.SetTriggerMode(W33_PIVOT_BREAK);
   TestCandidatesAndOrders();TestTrendAndEnd();TestSourceTraceAndRoomRejection();
   FileWrite(g_file,"FINAL",g_failed==0?"PASS":"FAIL",StringFormat("passed=%d failed=%d",g_passed,g_failed));
   FileFlush(g_file);FileClose(g_file);g_file=INVALID_HANDLE;
   PrintFormat("W33_DISPLAY_HARNESS_FINAL passed=%d failed=%d",g_passed,g_failed);
   return INIT_SUCCEEDED;
  }
void OnTick(){if(MQLInfoInteger(MQL_TESTER))TesterStop();}
double OnTester(){return g_failed==0?1.0:0.0;}
