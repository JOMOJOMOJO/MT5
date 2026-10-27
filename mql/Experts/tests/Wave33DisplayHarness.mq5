#property strict
#property version "1.00"
#property description "Finite display lifecycle tests; synthetic events only, no orders."
#include "../../Include/Wave33Visual/Display.mqh"

input string InpRunTag="display_harness";
CWave33Display g_display;
int g_file=INVALID_HANDLE,g_passed=0,g_failed=0;
int g_unavailable=0;
bool g_tooltips_readable=false;
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
void Unavailable(const string name,const string detail)
  {
   g_unavailable++;
   FileWrite(g_file,name,"UNAVAILABLE",detail);
   Print("W33_DISPLAY_TEST UNAVAILABLE ",name," ",detail);
  }
void DetectTooltipReadback()
  {
   string name=g_prefix+"tooltip_probe";
   ObjectCreate(0,name,OBJ_TEXT,0,g_base,3000.0);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,"W33 tooltip probe");
   g_tooltips_readable=ObjectGetString(0,name,OBJPROP_TOOLTIP)=="W33 tooltip probe";
   ObjectDelete(0,name);
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
void TestOppositeWaveExit(const int direction,const int index)
  {
   int step=Step();datetime fill=g_base+step*(80+index*40),known=fill+step*2,actual=known+step*5;
   string id=direction>0?"OPP_LONG_POSITION":"OPP_SHORT_POSITION",suffix=direction>0?"_LONG":"_SHORT";
   W33Setup s;Fixture(s,id,direction);s.fill_at=fill;s.position_open=true;
   s.sl_price=s.entry_price-direction*10.0;s.tp_price=s.entry_price+direction*10.0;
   Emit(s,"SIGNAL",fill);Emit(s,"FILL",fill);
   string wait=Obj(id,"opposite_wait"),point=Obj(id,"opposite_known"),exitPoint=Obj(id,"opposite_exit"),caption=Obj(id,"opposite_exit_text");
   Check("no_opposite_cause_before_observation"+suffix,ObjectFind(0,wait)<0 && ObjectFind(0,point)<0,
         "An ordinary fill alone does not claim an opposite-wave decision existed");
   s.opposite_exit_armed=true;s.opposite_setup_id=direction>0?"SOURCE_SHORT_W1":"SOURCE_LONG_W1";
   s.opposite_wave_peak_time=fill-step*5;s.opposite_wave_known_at=known;s.opposite_wave_price=s.entry_price-direction*2.0;
   Emit(s,"OPPOSITE_WAVE1_ARMED",known);
   Check("opposite_wait_at_known_time"+suffix,ObjectFind(0,wait)>=0 &&
         (datetime)ObjectGetInteger(0,wait,OBJPROP_TIME,0)==known && known>s.opposite_wave_peak_time,
         "The warning is placed when the opposite first wave became known, not on its older swing candle");
   Check("opposite_observation_point_at_known_time"+suffix,ObjectFind(0,point)>=0 &&
         (datetime)ObjectGetInteger(0,point,OBJPROP_TIME,0)==known && MathAbs(ObjectGetDouble(0,point,OBJPROP_PRICE,0)-s.entry_price)<1e-9,
         "The knowledge-time marker identifies the existing position's entry level without backdating");
   string waitText=ObjectGetString(0,wait,OBJPROP_TEXT);
   Check("opposite_wait_caption_explains_pending_profit"+suffix,StringFind(waitText,"逆①")>=0 && StringFind(waitText,"プラス決済待ち")>=0 &&
         (color)ObjectGetInteger(0,wait,OBJPROP_COLOR)==clrGold && (color)ObjectGetInteger(0,point,OBJPROP_COLOR)==clrGold,
         "Gold identifies a pending positive-net exit and is distinct from a new green entry");
   if(g_tooltips_readable)
     {
      string tip=ObjectGetString(0,wait,OBJPROP_TOOLTIP);
      Check("opposite_wait_source_and_known_tooltip"+suffix,StringFind(tip,s.opposite_setup_id)>=0 &&
            StringFind(tip,"known "+TimeToString(known,TIME_DATE|TIME_SECONDS))>=0 &&
            StringFind(tip,TimeToString(s.opposite_wave_peak_time,TIME_DATE|TIME_SECONDS))>=0,
            "The warning exposes the source setup, original swing date and actual knowledge date separately");
     }
   else Unavailable("opposite_wait_source_and_known_tooltip"+suffix,
                    "This tester cannot read even a short TOOLTIP probe; verify source and full known time in normal-chart replay inventory");
   ClockEvent(known+step*3);
   Check("opposite_wait_keeps_original_protection"+suffix,End(Obj(id,"SL"))==known+step*3 && End(Obj(id,"TP"))==known+step*3 &&
         MathAbs(ObjectGetDouble(0,Obj(id,"SL"),OBJPROP_PRICE,0)-s.sl_price)<1e-9 &&
         MathAbs(ObjectGetDouble(0,Obj(id,"TP"),OBJPROP_PRICE,0)-s.tp_price)<1e-9 && ObjectFind(0,exitPoint)<0,
         "Arming leaves original stop/target prices active and creates no premature exit marker");
   s.exit_reason="OPPOSITE_WAVE1_PROFIT";s.exit_deal_reason="EXPERT";s.exit_price=s.entry_price+direction*0.25;
   s.exit_at=actual;s.opposite_exit_requested_at=known+step*3;s.realized_r=0.025;
   Emit(s,"PARTIAL_EXIT",actual-step);
   Check("partial_exit_does_not_claim_flat"+suffix,ObjectFind(0,exitPoint)<0 && End(Obj(id,"SL"))==actual-step,
         "A partial close does not draw the completed-position exit or end residual risk lines");
   Emit(s,"EXIT",actual);
   Check("opposite_exit_at_actual_fill"+suffix,ObjectFind(0,exitPoint)>=0 &&
         (datetime)ObjectGetInteger(0,exitPoint,OBJPROP_TIME,0)==actual && actual>s.opposite_exit_requested_at &&
         MathAbs(ObjectGetDouble(0,exitPoint,OBJPROP_PRICE,0)-s.exit_price)<1e-9 &&
         MathAbs(s.exit_price-s.sl_price)>1.0 && MathAbs(s.exit_price-s.tp_price)>1.0,
         "The exit point uses the actual close fill time and price rather than request time, entry, SL or TP");
   string exitText=ObjectGetString(0,caption,OBJPROP_TEXT);
   Check("opposite_exit_caption_causal_reason"+suffix,StringFind(exitText,"EXIT")>=0 && StringFind(exitText,"逆①")>=0 &&
         StringFind(exitText,"利益決済")>=0 && (color)ObjectGetInteger(0,caption,OBJPROP_COLOR)==clrGold &&
         (datetime)ObjectGetInteger(0,caption,OBJPROP_TIME,0)==actual &&
         MathAbs(ObjectGetDouble(0,caption,OBJPROP_PRICE,0)-s.exit_price)<1e-9,
         "The close caption explicitly gives the opposite-first-wave profit reason at the fill location");
   if(g_tooltips_readable)
     {
      string tip=ObjectGetString(0,caption,OBJPROP_TOOLTIP),fillTip=ObjectGetString(0,exitPoint,OBJPROP_TOOLTIP);
      Check("opposite_exit_tooltip_execution_trace"+suffix,StringFind(tip,s.opposite_setup_id)>=0 &&
            StringFind(tip,"actual "+DoubleToString(s.realized_r,4)+"R")>=0 &&
            StringFind(fillTip,"fill "+DoubleToString(s.exit_price,_Digits))>=0 && StringFind(fillTip,"broker EXPERT")>=0,
            "The exit trace retains the opposing source, realized R, actual fill price and broker reason");
     }
   else Unavailable("opposite_exit_tooltip_execution_trace"+suffix,
                    "This tester cannot read TOOLTIP; verify source, actual fill, realized R and broker reason in normal-chart replay inventory");
   ClockEvent(actual+step*20);Emit(s,"COMPLETED",actual+step*21);
   Check("opposite_exit_stops_risk_at_actual_fill"+suffix,End(Obj(id,"SL"))==actual && End(Obj(id,"TP"))==actual &&
         End(Obj(id,"obstacle"))==actual && End(Obj(id,"wave1_room"))==actual &&
         !ObjectGetInteger(0,Obj(id,"SL"),OBJPROP_RAY_RIGHT) && !ObjectGetInteger(0,Obj(id,"TP"),OBJPROP_RAY_RIGHT),
         "All position risk/reference lines stop at the actual close and remain finite after later observations");
  }
void TestOrdinaryExitCaption()
  {
   int step=Step();W33Setup s;Fixture(s,"ORDINARY_EXIT");datetime at=g_base+step*170;
   Emit(s,"FILL",at);s.exit_reason="TP";s.exit_price=s.tp_price;
   Emit(s,"EXIT",at+step*2);
   Check("ordinary_tp_not_labeled_opposite_exit",ObjectFind(0,Obj(s.setup_id,"opposite_exit"))<0 &&
         ObjectFind(0,Obj(s.setup_id,"opposite_exit_text"))<0,
         "A broker target close is not mislabeled as the new opposite-wave policy");
  }
void TestWave1Extension(const int direction,const int index)
  {
   int step=Step();string id=direction>0?"EXT_LONG":"EXT_SHORT",tag=direction>0?"_LONG":"_SHORT";
   datetime peak=g_base+step*(200+index*60),known=peak+step*3,started=known+step*3;
   W33Setup s;Fixture(s,id,direction);s.candidate_detected_at=peak-step*3;s.wave1_start_time=peak-step*6;
   s.wave1_start_price=3000;s.wave1_peak_time=peak;s.wave1_peak_price=3000+direction*30;
   s.wave1_peak_known_at=known;s.wave1_peak_fixed=true;
   s.fib_382_price=s.wave1_peak_price-direction*30*0.382;s.fib_618_price=s.wave1_peak_price-direction*30*0.618;
   s.wave2_extreme_time=known;s.wave2_extreme_price=s.wave1_peak_price-direction*3;
   g_display.SetTriggerMode(W33_PIVOT_BREAK);Emit(s,"WAVE1_BREAK",s.candidate_detected_at);
   Emit(s,"WAVE1_PEAK_CONFIRMED",known);Emit(s,"WAVE2_EXTREME",known+step);
   Emit(s,"LOWER_STRUCTURE_CONFIRMED",known+step*2);
   string oldLine=Obj(id,"W1"),oldCaption=Obj(id,"W1_known"),oldFib=Obj(id,"fib"),oldW2=Obj(id,"W2_leg");
   double originalPrice=ObjectGetDouble(0,oldLine,OBJPROP_PRICE,1),originalW2=ObjectGetDouble(0,oldW2,OBJPROP_PRICE,1);
   datetime originalEnd=End(oldLine);
   Emit(s,"WAVE1_EXTENSION_PREVIOUS_ANCHORS",started);
   Check("extension_archives_old_wave"+tag,ObjectFind(0,oldLine)>=0 && End(oldLine)==originalEnd &&
         MathAbs(ObjectGetDouble(0,oldLine,OBJPROP_PRICE,1)-originalPrice)<1e-9 &&
         (color)ObjectGetInteger(0,oldLine,OBJPROP_COLOR)==clrSlateGray && ObjectGetInteger(0,oldLine,OBJPROP_STYLE)==STYLE_DASH &&
         ObjectGetInteger(0,oldLine,OBJPROP_WIDTH)==1 && StringFind(ObjectGetString(0,oldCaption,OBJPROP_TEXT),"旧終点")>=0,
         "The original endpoint remains at its original time/price as gray dashed history, with an explicit superseded caption");
   Check("extension_closes_old_fib_at_observation"+tag,End(oldFib)==started &&
         (color)ObjectGetInteger(0,oldFib,OBJPROP_COLOR)==clrSlateGray &&
         (datetime)ObjectGetInteger(0,oldFib,OBJPROP_TIME,0)==known,
         "The previous band preserves its first availability and stops when the extension became known");
   Check("extension_archives_old_pullback"+tag,ObjectFind(0,oldW2)>=0 &&
         (color)ObjectGetInteger(0,oldW2,OBJPROP_COLOR)==clrSlateGray &&
         StringFind(ObjectGetString(0,Obj(id,"W2"),OBJPROP_TEXT),"旧観測")>=0 &&
         MathAbs(ObjectGetDouble(0,oldW2,OBJPROP_PRICE,1)-originalW2)<1e-9,
         "The abandoned W2 remains separate gray evidence rather than an orange current pullback");
   string lower="";for(int j=0;j<ObjectsTotal(0);j++){string n=ObjectName(0,j);if(StringFind(n,Obj(id,"lower_level_"))==0)lower=n;}
   Check("extension_closes_old_lower_trigger"+tag,lower!="" && End(lower)==started && !ObjectGetInteger(0,lower,OBJPROP_RAY_RIGHT),
         "A trigger derived from the old W2 stops at re-anchoring");
   s.wave1_previous_peak_time=s.wave1_peak_time;s.wave1_previous_peak_known_at=s.wave1_peak_known_at;s.wave1_previous_peak_price=s.wave1_peak_price;
   s.wave1_revision=1;s.wave1_extension_pending=true;s.wave1_extension_started_at=started;
   s.wave1_peak_fixed=false;s.wave1_peak_time=0;s.wave1_peak_price=0;s.wave1_peak_known_at=0;
   s.fib_382_price=0;s.fib_618_price=0;s.wave2_extreme_time=0;s.wave2_extreme_price=0;
   s.wave1_provisional_time=started-step;s.wave1_provisional_price=originalPrice+direction*4;
   Emit(s,"WAVE1_EXTENSION_STARTED",started);
   Check("extension_pending_has_no_fixed_anchors"+tag,ObjectFind(0,Obj(id,"provisional_r1"))>=0 &&
         (color)ObjectGetInteger(0,Obj(id,"provisional_r1"),OBJPROP_COLOR)==clrSlateGray &&
         StringFind(ObjectGetString(0,Obj(id,"extension_tracking_r1"),OBJPROP_TEXT),"延長中")>=0 &&
         ObjectFind(0,Obj(id,"W1_r1"))<0 && ObjectFind(0,Obj(id,"fib_r1"))<0 && ObjectFind(0,Obj(id,"W2_leg_r1"))<0,
         "A newly observed extension is visibly provisional and cannot imply confirmed W1, new Fib, or a completed correction");
   datetime tracking=started+step*2;s.wave1_provisional_time=tracking-step;s.wave1_provisional_price=originalPrice+direction*7;
   Emit(s,"WAVE1_EXTENSION_TRACKING",tracking);ClockEvent(tracking+step);
   Check("extension_provisional_updates_without_rewriting_history"+tag,End(Obj(id,"provisional_r1"))==s.wave1_provisional_time &&
         MathAbs(ObjectGetDouble(0,Obj(id,"provisional_r1"),OBJPROP_PRICE,1)-s.wave1_provisional_price)<1e-9 &&
         End(oldFib)==started && End(oldLine)==originalEnd && MathAbs(ObjectGetDouble(0,oldLine,OBJPROP_PRICE,1)-originalPrice)<1e-9,
         "Only the current provisional leg moves; old anchors and retired bands remain unchanged");
   datetime confirmed=tracking+step*3;s.wave1_peak_fixed=true;s.wave1_extension_pending=false;
   s.wave1_peak_time=s.wave1_provisional_time;s.wave1_peak_price=s.wave1_provisional_price;
   s.wave1_peak_known_at=confirmed;s.wave1_extension_known_at=confirmed;
   s.fib_382_price=s.wave1_peak_price-direction*37*0.382;s.fib_618_price=s.wave1_peak_price-direction*37*0.618;
   Emit(s,"WAVE1_EXTENDED_CONFIRMED",confirmed);
   string currentLine=Obj(id,"W1_r1"),currentFib=Obj(id,"fib_r1"),point=Obj(id,"ext_known_r1");
   Check("extension_confirmed_owns_new_blue_leg"+tag,ObjectFind(0,currentLine)>=0 && currentLine!=oldLine &&
         (color)ObjectGetInteger(0,currentLine,OBJPROP_COLOR)==clrDodgerBlue && ObjectGetInteger(0,currentLine,OBJPROP_WIDTH)==3 &&
         MathAbs(ObjectGetDouble(0,currentLine,OBJPROP_PRICE,1)-s.wave1_peak_price)<1e-9 &&
         ObjectFind(0,Obj(id,"provisional_r1"))<0 && ObjectFind(0,Obj(id,"extension_tracking_r1"))<0,
         "Only after confirmation is a new blue revision created and its temporary tracking caption removed");
   Check("extension_new_fib_starts_when_confirmed"+tag,ObjectFind(0,currentFib)>=0 &&
         (datetime)ObjectGetInteger(0,currentFib,OBJPROP_TIME,0)==confirmed && confirmed>s.wave1_peak_time && End(oldFib)==started &&
         (color)ObjectGetInteger(0,currentFib,OBJPROP_COLOR)==clrDarkOrange,
         "The recomputed band begins at the new knowledge time and does not fill the intervening unknown history");
   Check("extension_confirmation_has_separate_known_marker"+tag,ObjectFind(0,point)>=0 &&
         (datetime)ObjectGetInteger(0,point,OBJPROP_TIME,0)==confirmed &&
         (datetime)ObjectGetInteger(0,Obj(id,"W1_known_r1"),OBJPROP_TIME,0)==s.wave1_peak_time,
         "Retrospective swing location and actual confirmation availability are marked separately");
   if(g_tooltips_readable)
     Check("extension_tooltip_retains_provenance"+tag,StringFind(ObjectGetString(0,oldCaption,OBJPROP_TOOLTIP),"known "+TimeToString(known,TIME_DATE|TIME_SECONDS))>=0 &&
           StringFind(ObjectGetString(0,point,OBJPROP_TOOLTIP),"confirmed now "+TimeToString(confirmed,TIME_DATE|TIME_SECONDS))>=0,
           "Both old and revised source dates retain their actual knowledge-time provenance");
   else Unavailable("extension_tooltip_retains_provenance"+tag,"This tester cannot read TOOLTIP; old and revised confirmation timestamps require recorded normal-chart inventory");
   s.wave2_extreme_time=confirmed+step;s.wave2_extreme_price=s.wave1_peak_price-direction*4;
   Emit(s,"WAVE2_EXTREME",confirmed+step*2);
   Check("extension_new_pullback_is_distinct"+tag,ObjectFind(0,Obj(id,"W2_leg_r1"))>=0 &&
         (color)ObjectGetInteger(0,Obj(id,"W2_leg_r1"),OBJPROP_COLOR)==clrDarkOrange &&
         (color)ObjectGetInteger(0,oldW2,OBJPROP_COLOR)==clrSlateGray &&
         MathAbs(ObjectGetDouble(0,oldW2,OBJPROP_PRICE,1)-originalW2)<1e-9,
         "A correction under the new anchors cannot overwrite the retired correction");
   datetime secondStart=confirmed+step*4;Emit(s,"WAVE1_EXTENSION_PREVIOUS_ANCHORS",secondStart);
   s.wave1_revision=2;s.wave1_extension_pending=true;s.wave1_peak_fixed=false;s.wave1_peak_known_at=0;
   s.wave1_extension_started_at=secondStart;s.wave1_provisional_time=secondStart-step;s.wave1_provisional_price+=direction*4;
   Emit(s,"WAVE1_EXTENSION_STARTED",secondStart);
   s.wave1_peak_fixed=true;s.wave1_extension_pending=false;s.wave1_peak_time=s.wave1_provisional_time;
   s.wave1_peak_price=s.wave1_provisional_price;s.wave1_peak_known_at=secondStart+step*3;s.wave1_extension_known_at=s.wave1_peak_known_at;
   Emit(s,"WAVE1_EXTENDED_CONFIRMED",s.wave1_peak_known_at);ClockEvent(secondStart+step*10);
   Check("multiple_extensions_keep_each_revision_finite"+tag,ObjectFind(0,Obj(id,"W1_r2"))>=0 &&
         (color)ObjectGetInteger(0,currentLine,OBJPROP_COLOR)==clrSlateGray &&
         (color)ObjectGetInteger(0,Obj(id,"W1_r2"),OBJPROP_COLOR)==clrDodgerBlue &&
         End(oldFib)==started && End(currentFib)==secondStart && End(Obj(id,"fib_r2"))==secondStart+step*10 &&
         !ObjectGetInteger(0,oldLine,OBJPROP_RAY_RIGHT) && !ObjectGetInteger(0,currentLine,OBJPROP_RAY_RIGHT) &&
         !ObjectGetInteger(0,Obj(id,"W1_r2"),OBJPROP_RAY_RIGHT),
         "Repeated re-anchoring preserves separately dated finite revisions instead of rewriting one continuous band");
   Check("extension_events_cannot_create_trade"+tag,ObjectFind(0,Obj(id,"entry_text"))<0 && ObjectFind(0,Obj(id,"SL"))<0 &&
         ObjectFind(0,Obj(id,"TP"))<0 && ObjectFind(0,Obj(id,"opposite_wait"))<0,
         "Display-only extension events do not imply a signal, order, protection, or opposite-wave exit");
   Emit(s,"TEST_END",secondStart+step*11);datetime ended=End(Obj(id,"fib_r2"));ClockEvent(secondStart+step*20);
   Check("extended_candidate_terminal_stops_current_band"+tag,End(Obj(id,"fib_r2"))==ended && ended==secondStart+step*11 && End(currentFib)==secondStart,
         "Ending the setup stops only its current revision and cannot reopen any older Fib band");
  }
void TestConnectedOppositeCandidate(const int direction,const int index)
  {
   int step=Step();datetime at=g_base+step*(500+index*30);
   string id=direction>0?"CONNECTED_CANCEL_LONG":"CONNECTED_CANCEL_SHORT",tag=direction>0?"_LONG":"_SHORT";
   W33Setup s;Fixture(s,id,direction);s.entry_price=0;s.sl_price=0;s.tp_price=0;
   s.wave1_peak_fixed=true;s.wave2_extreme_price=3008;s.wave2_extreme_time=at-step;
   Emit(s,"WAVE1_BREAK",at-step*3);Emit(s,"WAVE1_PEAK_CONFIRMED",at-step*2);
   string point=Obj(id,"opposite_cancel_known"),leader=Obj(id,"opposite_cancel_leader");
   Check("connected_cancel_not_drawn_before_candidate"+tag,ObjectFind(0,point)<0 && ObjectFind(0,leader)<0,
         "A known older W1 alone cannot claim that a future opposite candidate already existed");
   s.connected_opposite_cancelled=true;s.connected_opposite_setup_id="NEW_OPPOSITE_"+id;
   s.connected_opposite_known_at=at;s.connected_shared_time=s.wave1_peak_time;s.connected_shared_price=s.wave1_peak_price;
   W33Event e;ZeroMemory(e);e.at=at;e.event_type="INVALIDATE";e.reason_kind="EXCLUSION";
   e.reason="CONNECTED_OPPOSITE_W1_CANDIDATE";e.setup=s;g_display.Event(e);
   string caption="";
   for(int i=0;i<ObjectsTotal(0);i++){string n=ObjectName(0,i);if(StringFind(n,Obj(id,"skip_"))==0)caption=n;}
   Check("connected_cancel_marks_candidate_known_time"+tag,ObjectFind(0,point)>=0 &&
         (datetime)ObjectGetInteger(0,point,OBJPROP_TIME,0)==at && at>s.connected_shared_time,
         "The red observation point is at candidate availability, never its older shared swing");
   Check("connected_cancel_caption_explains_reason"+tag,caption!="" &&
         StringFind(ObjectGetString(0,caption,OBJPROP_TEXT),"接続する逆①候補")>=0 &&
         (color)ObjectGetInteger(0,caption,OBJPROP_COLOR)==clrIndianRed,
         "The cancelled old setup explicitly gives the connected opposite-candidate reason");
   Check("connected_cancel_leader_finite"+tag,ObjectFind(0,leader)>=0 &&
         (datetime)ObjectGetInteger(0,leader,OBJPROP_TIME,0)==at && End(leader)==at+step &&
         !ObjectGetInteger(0,leader,OBJPROP_RAY_RIGHT) && !ObjectGetInteger(0,leader,OBJPROP_RAY_LEFT),
         "The causal point and spaced caption use a finite one-bar leader");
   Check("connected_cancel_does_not_claim_trade"+tag,ObjectFind(0,Obj(id,"entry_text"))<0 && ObjectFind(0,Obj(id,"SL"))<0 &&
         ObjectFind(0,Obj(id,"TP"))<0 && ObjectFind(0,Obj(id,"opposite_wait"))<0,
         "Pre-order invalidation is distinct from an entry or the existing post-fill positive exit");
   if(g_tooltips_readable)
      Check("connected_cancel_provenance_tooltips"+tag,
            StringFind(ObjectGetString(0,caption,OBJPROP_TOOLTIP),s.connected_opposite_setup_id)>=0 &&
            StringFind(ObjectGetString(0,caption,OBJPROP_TOOLTIP),TimeToString(at,TIME_DATE|TIME_SECONDS))>=0 &&
            StringFind(ObjectGetString(0,point,OBJPROP_TOOLTIP),TimeToString(s.connected_shared_time,TIME_DATE|TIME_SECONDS))>=0 &&
            StringFind(ObjectGetString(0,point,OBJPROP_TOOLTIP),DoubleToString(s.connected_shared_price,_Digits))>=0,
            "Caption and point retain the opposite source ID, candidate known time and common native swing");
   else Unavailable("connected_cancel_provenance_tooltips"+tag,"This tester cannot read TOOLTIP; verify source and shared swing in recorded normal-chart inventory");
   ClockEvent(at+step*10);
   Check("connected_cancel_stays_closed"+tag,End(Obj(id,"upper_break"))==at && End(Obj(id,"fib"))==at && End(leader)==at+step,
         "Later observed market time cannot extend the cancelled setup or its cancellation leader");
   W33Setup future=s;future.setup_id=id+"_FUTURE";future.connected_opposite_known_at=at+step*20;e.setup=future;g_display.Event(e);
   Check("connected_future_source_not_drawn"+tag,ObjectFind(0,Obj(future.setup_id,"opposite_cancel_known"))<0 &&
         ObjectFind(0,Obj(future.setup_id,"opposite_cancel_leader"))<0,
         "An invalid snapshot cannot reveal an opposite source before its availability time");
  }
void TestWave1TargetExtension(const int direction,const int index)
  {
   int step=Step();datetime at=g_base+step*(600+index*30);
   string id=direction>0?"TARGET_EXTEND_LONG":"TARGET_EXTEND_SHORT",tag=direction>0?"_LONG":"_SHORT";
   W33Setup s;Fixture(s,id,direction);s.wave1_peak_fixed=true;
   s.wave1_start_price=direction>0?2990:3024;s.wave1_peak_price=s.entry_price+direction*13;
   s.sl_price=s.entry_price-direction*10;s.tp_rr_price=s.entry_price+direction*10;
   s.tp_wave1_target_price=s.wave1_peak_price-direction*0.1;s.tp_price=s.tp_wave1_target_price;
   s.tp_wave1_buffer_points=0.1/_Point;s.tp_extended_to_wave1=true;s.actual_rr=1.29;s.tp_adjustment_reason="TP_WAVE1_EXTENDED";
   Emit(s,"TP_WAVE1_EXTENDED",at);
   Check("target_adjustment_alone_not_entry"+tag,ObjectFind(0,Obj(id,"TP"))<0 && ObjectFind(0,Obj(id,"entry_text"))<0,
         "A target adjustment diagnostic alone never draws an entry or an executable risk line");
   Emit(s,"SIGNAL",at);
   Check("extended_target_uses_final_fixed_price"+tag,ObjectFind(0,Obj(id,"TP"))>=0 &&
         MathAbs(ObjectGetDouble(0,Obj(id,"TP"),OBJPROP_PRICE,0)-s.tp_price)<1e-9 &&
         s.direction*(s.tp_price-s.tp_rr_price)>0 && !ObjectGetInteger(0,Obj(id,"TP"),OBJPROP_RAY_RIGHT),
         "The green target has the final W1-buffer price, rather than the original RR-only target");
   Check("extended_target_caption_identifies_w1"+tag,ObjectGetString(0,Obj(id,"TP_label"),OBJPROP_TEXT)=="TP ①手前" &&
         (datetime)ObjectGetInteger(0,Obj(id,"TP"),OBJPROP_TIME,0)==at,
         "The compact caption distinguishes the W1 target without adding a fixed chart panel");
   if(g_tooltips_readable)
      Check("extended_target_tooltips_separate_rr_source"+tag,
            StringFind(ObjectGetString(0,Obj(id,"TP"),OBJPROP_TOOLTIP),"RR-only "+DoubleToString(s.tp_rr_price,_Digits))>=0 &&
            StringFind(ObjectGetString(0,Obj(id,"TP"),OBJPROP_TOOLTIP),"actual 1.29R")>=0 &&
            StringFind(ObjectGetString(0,Obj(id,"TP_label"),OBJPROP_TOOLTIP),"known "+TimeToString(s.wave1_peak_known_at,TIME_DATE|TIME_SECONDS))>=0,
            "Risk tooltip records original RR-only target and actual RR; caption tooltip records known W1 source");
   else Unavailable("extended_target_tooltips_separate_rr_source"+tag,"This tester cannot read TOOLTIP; final/base prices and W1 known time require recorded normal-chart inventory");
   double fixed=s.tp_price;Emit(s,"FILL",at+step);s.tp_price+=direction*5;Emit(s,"TP_WAVE1_EXTENDED",at+step*2);
   Check("later_adjustment_event_cannot_reanchor_target"+tag,MathAbs(ObjectGetDouble(0,Obj(id,"TP"),OBJPROP_PRICE,0)-fixed)<1e-9 &&
         ObjectGetString(0,Obj(id,"TP_label"),OBJPROP_TEXT)=="TP ①手前",
         "A supplementary diagnostic after fill cannot rewrite the original target");
   Emit(s,"EXIT",at+step*3);ClockEvent(at+step*8);
   Check("extended_target_line_ends_at_exit"+tag,End(Obj(id,"TP"))==at+step*3 && !ObjectGetInteger(0,Obj(id,"TP"),OBJPROP_RAY_RIGHT),
         "Extended targets retain the ordinary finite position lifecycle");
   W33Setup ordinary=s;ordinary.setup_id=id+"_CAPPED";ordinary.tp_extended_to_wave1=false;
   ordinary.tp_price=ordinary.tp_rr_price-direction;ordinary.tp_adjustment_reason="CAP_TP";Emit(ordinary,"SIGNAL",at+step*9);
   Check("cancelled_extension_keeps_plain_tp_caption"+tag,ObjectGetString(0,Obj(ordinary.setup_id,"TP_label"),OBJPROP_TEXT)=="TP" &&
         MathAbs(ObjectGetDouble(0,Obj(ordinary.setup_id,"TP"),OBJPROP_PRICE,0)-ordinary.tp_price)<1e-9,
         "A final cap below the RR target is not misleadingly labelled as a W1 extension");
   W33Setup future=s;future.setup_id=id+"_UNKNOWN";future.wave1_peak_known_at=at+step*20;Emit(future,"SIGNAL",at+step*10);
   Check("future_w1_not_claimed_as_target_source"+tag,ObjectGetString(0,Obj(future.setup_id,"TP_label"),OBJPROP_TEXT)=="TP",
         "Unknown W1 provenance cannot be presented as a known W1 target source");
  }
int OnInit()
  {
   g_file=FileOpen("W33Harness_"+InpRunTag+".csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(g_file==INVALID_HANDLE)return INIT_FAILED;
   FileWrite(g_file,"test","passed","detail");
   DetectTooltipReadback();
   g_display.Init(g_prefix,true);g_display.SetFrames(PERIOD_M15,PERIOD_M5);g_display.SetTriggerMode(W33_PIVOT_BREAK);
   TestCandidatesAndOrders();TestTrendAndEnd();TestSourceTraceAndRoomRejection();
   TestOppositeWaveExit(1,0);TestOppositeWaveExit(-1,1);TestOrdinaryExitCaption();
   TestWave1Extension(1,0);TestWave1Extension(-1,1);
   TestConnectedOppositeCandidate(1,0);TestConnectedOppositeCandidate(-1,1);
   TestWave1TargetExtension(1,0);TestWave1TargetExtension(-1,1);
   FileWrite(g_file,"FINAL",g_failed==0?"PASS":"FAIL",StringFormat("passed=%d failed=%d unavailable=%d",g_passed,g_failed,g_unavailable));
   FileFlush(g_file);FileClose(g_file);g_file=INVALID_HANDLE;
   PrintFormat("W33_DISPLAY_HARNESS_FINAL passed=%d failed=%d unavailable=%d",g_passed,g_failed,g_unavailable);
   return INIT_SUCCEEDED;
  }
void OnTick(){if(MQLInfoInteger(MQL_TESTER))TesterStop();}
double OnTester(){return g_failed==0?1.0:0.0;}
