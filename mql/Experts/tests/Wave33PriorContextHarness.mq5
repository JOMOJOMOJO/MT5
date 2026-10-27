// Native fixture QA of the actual EA signal policy. No strategy performance claim.
#define OnInit W33BaseOnInit
#define OnTick W33BaseOnTick
#define OnDeinit W33BaseOnDeinit
#define OnTradeTransaction W33BaseOnTradeTransaction
#include "../Wave33ChopDiagnostic.mq5"
#undef OnInit
#undef OnTick
#undef OnDeinit
#undef OnTradeTransaction

int qa_file=INVALID_HANDLE,qa_checks=0,qa_failures=0,qa_serial=0;
datetime qa_base=D'2020.01.01 00:00:00';
void QA(const string name,const bool ok,const string detail="")
  {
   qa_checks++;if(!ok)qa_failures++;
   Print("PRIOR_CONTEXT_QA ",name," ",ok?"PASS":"FAIL"," ",detail);
   FileWrite(qa_file,name,ok?"PASS":"FAIL",detail);
  }
void QABase(W33Setup &s,const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int dir)
  {
   ZeroMemory(s);s.setup_id="QA";s.symbol=_Symbol;s.upper_tf=upper;s.lower_tf=lower;s.direction=dir;
   s.wave1_start_time=qa_base+6*3600;s.wave1_start_known_at=qa_base+7*3600;
   s.wave1_peak_time=qa_base+9*3600;s.wave1_peak_known_at=qa_base+10*3600;s.wave1_peak_fixed=true;
   s.wave1_start_price=dir>0?100:200;s.wave1_peak_price=dir>0?110:190;
   s.entry_price=dir>0?108:192;s.sl_price=dir>0?100:200;s.tp_price=dir>0?114:186;
  }
double QAMirror(const double p,const int dir){return dir>0?p:300-p;}
void QAPivot(W33Pivot &p[],const ENUM_TIMEFRAMES tf,const int dir,const double long_price=110.1)
  {
   int n=ArraySize(p);ArrayResize(p,n+1);ZeroMemory(p[n]);p[n].time=qa_base+3600;p[n].known_at=qa_base+4*3600;
   p[n].price=QAMirror(long_price,dir);p[n].is_high=dir>0;p[n].tf=tf;p[n].label=dir>0?"HH":"LL";
  }
void QABar(W33PriorContextBar &bars[],const ENUM_TIMEFRAMES tf,const int dir,const double long_close=109)
  {
   int n=ArraySize(bars);ArrayResize(bars,n+1);ZeroMemory(bars[n]);bars[n].tf=tf;bars[n].bar.time=qa_base+10*3600;
   bars[n].known_at=qa_base+11*3600;double p=QAMirror(long_close,dir);
   bars[n].bar.open=p;bars[n].bar.close=p;bars[n].bar.high=p+20;bars[n].bar.low=p-20;bars[n].bar.tick_volume=100;
  }
void QAPublish(CWave33PriorContext &observer,const W33Pivot &p)
  {W33Event e;ZeroMemory(e);e.at=p.known_at;e.event_type="PIVOT_CONFIRMED";e.has_pivot=true;e.pivot=p;observer.Event(e);}
bool QAEvaluate(const W33Setup &s,const W33Pivot &p[],const W33PriorContextBar &b[],W33PriorContextResult &r)
  {return W33PriorContextEvaluate(s,p,b,qa_base+12*3600,0.05,r);}
void QAPure(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int dir)
  {
   string key=EnumToString(upper)+"_"+EnumToString(lower)+"_"+W33DirectionName(dir);
   W33Setup s;QABase(s,upper,lower,dir);W33Pivot p[];W33PriorContextBar b[];
   QAPivot(p,PERIOD_M15,dir);QABar(b,PERIOD_M15,dir);W33PriorContextResult r;
   QAEvaluate(s,p,b,r);QA("baseline_blocked_"+key,r.status=="BLOCKED" && r.blocked && r.near);
   QA("halfwidth_fixed_span_"+key,MathAbs(r.halfwidth-0.5)<1e-12);
   QA("filter_on_"+key,W33PriorContextShouldSkip(true,r));QA("filter_off_"+key,!W33PriorContextShouldSkip(false,r));
   QA("risk_room_signed_"+key,MathAbs(r.room_r-2.1/8.0)<1e-10,DoubleToString(r.room_r,12));
   s.wave1_peak_price=QAMirror(109.6,dir);QAEvaluate(s,p,b,r);
   // Recompute the exact boundary using the same fixed-span equation: level=(peak + 0.05*start)/1.05.
   QABase(s,upper,lower,dir);p[0].price=s.wave1_peak_price+dir*0.5;QAEvaluate(s,p,b,r);
   QA("band_exact_inclusive_"+key,r.near && r.blocked);
   p[0].price+=dir*0.000001;QAEvaluate(s,p,b,r);QA("band_just_outside_"+key,!r.near && !r.blocked);
   QAPivot(p,PERIOD_H1,dir);QABar(b,PERIOD_H1,dir);p[0].price=p[1].price;QAEvaluate(s,p,b,r);
   QA("same_level_H1_tie_"+key,r.selected.tf==PERIOD_H1 && r.blocked);
   // A closer clear level must never mask a farther blocking level.
   ArrayResize(p,1);ArrayResize(b,1);p[0].price=QAMirror(110,dir);b[0].bar.close=QAMirror(111,dir);
   QAPivot(p,PERIOD_H1,dir,110.4);QABar(b,PERIOD_H1,dir,109);QAEvaluate(s,p,b,r);
   QA("all_blocking_before_nearest_clear_"+key,r.blocked && r.selected.tf==PERIOD_H1 && MathAbs(r.selected.price-QAMirror(110.4,dir))<1e-10);
   b[0].tf=PERIOD_M5;QAEvaluate(s,p,b,r);QA("blocking_not_masked_by_closer_missing_close_"+key,r.blocked && r.selected.tf==PERIOD_H1);
   b[0].tf=PERIOD_M15;
   ArrayResize(p,1);ArrayResize(b,1);p[0].price=QAMirror(110.1,dir);b[0].bar.close=QAMirror(109,dir);
   double outer=p[0].price+dir*0.5;s.tp_price=outer;QAEvaluate(s,p,b,r);QA("TP_at_edge_allow_"+key,!r.blocked && !r.tp_beyond);
   s.tp_price=outer+dir*0.000001;QAEvaluate(s,p,b,r);QA("TP_beyond_edge_block_"+key,r.blocked && r.tp_beyond);
   b[0].bar.close=outer;QAEvaluate(s,p,b,r);QA("close_at_edge_block_"+key,r.blocked && !r.close_beyond);
   b[0].bar.close=outer+dir*0.000001;QAEvaluate(s,p,b,r);QA("close_beyond_edge_allow_"+key,!r.blocked && r.close_beyond);
   b[0].bar.close=QAMirror(109,dir);s.entry_price=outer;s.tp_price=QAMirror(114,dir);QAEvaluate(s,p,b,r);QA("quote_at_edge_block_"+key,r.blocked && !r.entry_passed);
   s.entry_price=outer+dir*0.000001;QAEvaluate(s,p,b,r);QA("quote_beyond_edge_allow_"+key,!r.blocked && r.entry_passed);
   QABase(s,upper,lower,dir);p[0].time=s.wave1_start_time;QAEvaluate(s,p,b,r);QA("source_at_start_excluded_"+key,r.status=="NO_PRIOR_LEVEL" && !r.blocked);
   p[0].time=s.wave1_start_time+1;QAEvaluate(s,p,b,r);QA("source_after_start_excluded_"+key,r.status=="NO_PRIOR_LEVEL");
   p[0].time=qa_base+3600;p[0].known_at=qa_base+12*3600+1;QAEvaluate(s,p,b,r);QA("future_known_pivot_excluded_"+key,r.status=="NO_PRIOR_LEVEL");
   p[0].known_at=qa_base+4*3600;p[0].tf=PERIOD_M5;QAEvaluate(s,p,b,r);QA("wrong_tf_pivot_excluded_"+key,r.status=="NO_PRIOR_LEVEL");
   p[0].tf=PERIOD_M15;p[0].is_high=dir<0;QAEvaluate(s,p,b,r);QA("wrong_role_pivot_excluded_"+key,r.status=="NO_PRIOR_LEVEL");
   p[0].is_high=dir>0;p[0].known_at=p[0].time+PeriodSeconds(p[0].tf)-1;QAEvaluate(s,p,b,r);QA("unclosed_pivot_excluded_"+key,r.status=="NO_PRIOR_LEVEL");
   p[0].known_at=qa_base+4*3600;b[0].bar.time=qa_base+60;b[0].known_at=qa_base+1800;QAEvaluate(s,p,b,r);QA("latest_close_predates_source_allow_"+key,r.status=="UNAVAILABLE" && !r.blocked);
   b[0].bar.time=qa_base+10*3600;b[0].known_at=qa_base+11*3600;
   p[0].is_high=dir>0;ArrayResize(b,0);QAEvaluate(s,p,b,r);QA("missing_close_allow_"+key,r.status=="UNAVAILABLE" && !W33PriorContextShouldSkip(true,r));
   QABar(b,PERIOD_M15,dir);b[0].bar.time=qa_base+12*3600-100;b[0].known_at=qa_base+12*3600;
   QAEvaluate(s,p,b,r);QA("forming_bar_ignored_"+key,r.status=="UNAVAILABLE" && !r.blocked);
   b[0].bar.time=qa_base+10*3600;b[0].known_at=qa_base+12*3600+1;QAEvaluate(s,p,b,r);QA("future_known_close_ignored_"+key,r.status=="UNAVAILABLE");
   b[0].known_at=qa_base+11*3600;b[0].bar.close=0;QAEvaluate(s,p,b,r);QA("invalid_close_allow_"+key,r.status=="UNAVAILABLE" && !r.blocked);
   b[0].bar.close=QAMirror(109,dir);s.wave1_peak_fixed=false;QAEvaluate(s,p,b,r);QA("unfixed_anchor_allow_"+key,r.status=="UNAVAILABLE");
   s.wave1_peak_fixed=true;s.wave1_extension_pending=true;QAEvaluate(s,p,b,r);QA("pending_revision_allow_"+key,r.status=="UNAVAILABLE");
   s.wave1_extension_pending=false;s.wave1_revision=1;s.wave1_peak_price+=dir*3;QAEvaluate(s,p,b,r);QA("revision_reevaluated_"+key,!r.near && !r.blocked);
   QABase(s,upper,lower,dir);ArrayResize(p,0);QAEvaluate(s,p,b,r);QA("no_level_allow_"+key,r.status=="NO_PRIOR_LEVEL" && !r.blocked);
   QAPivot(p,PERIOD_M15,dir);CWave33PriorContext observer;
   QA("observer_open_"+key,observer.Open(InpRunTag+"_p"+IntegerToString(++qa_serial),"QA_",true,false,false,0.05));
   observer.ClosedBar(b[0].tf,b[0].bar,b[0].known_at);observer.Evaluate(s,qa_base+12*3600,r);
   QA("unpublished_pivot_excluded_"+key,r.status=="NO_PRIOR_LEVEL");
   QAPublish(observer,p[0]);observer.Evaluate(s,qa_base+12*3600,r);QA("published_prefix_included_"+key,r.blocked);
   MqlRates later=b[0].bar;later.time=qa_base+11*3600;later.close=QAMirror(112,dir);later.high=250;later.low=1;
   observer.ClosedBar(PERIOD_M15,later,qa_base+13*3600);observer.Evaluate(s,qa_base+12*3600,r);
   QA("cached_future_known_close_not_leaked_"+key,r.blocked && r.latest_close_time==qa_base+10*3600);
   observer.Evaluate(s,qa_base+13*3600,r);QA("cached_close_available_later_"+key,!r.blocked && r.close_beyond);
   observer.Close();
   CWave33PriorContext drawing;string draw_prefix="QA_DRAW_"+key;
   QA("drawing_observer_open_"+key,drawing.Open(InpRunTag+"_d"+IntegerToString(++qa_serial),draw_prefix,true,true,false,0.05));
   QAPublish(drawing,p[0]);drawing.ClosedBar(b[0].tf,b[0].bar,b[0].known_at);
   W33Event de;ZeroMemory(de);de.at=qa_base+12*3600;de.event_type="SIGNAL";de.setup=s;drawing.Event(de);ChartRedraw();
   int draw_count=0,trend_count=0,band_count=0;bool finite=true,band_time=true;
   for(int oi=0;oi<ObjectsTotal(0,-1,-1);oi++)
     {
      string name=ObjectName(0,oi,-1,-1);if(StringFind(name,"W33PC_")!=0)continue;draw_count++;
      ENUM_OBJECT type=(ENUM_OBJECT)ObjectGetInteger(0,name,OBJPROP_TYPE);
      if(type==OBJ_TREND){trend_count++;finite=finite && !ObjectGetInteger(0,name,OBJPROP_RAY_LEFT) && !ObjectGetInteger(0,name,OBJPROP_RAY_RIGHT);}
      if(type==OBJ_RECTANGLE){band_count++;band_time=band_time && ObjectGetInteger(0,name,OBJPROP_TIME,0)==de.at && ObjectGetInteger(0,name,OBJPROP_TIME,1)==de.at+12*PeriodSeconds(lower);}
     }
   QA("drawing_objects_exist_"+key,draw_count==6 && trend_count==2 && band_count==1,IntegerToString(draw_count));
   QA("drawing_rays_disabled_"+key,finite);QA("drawing_band_starts_at_decision_and_finite_"+key,band_time);
   drawing.Clear();drawing.Close();
  }

void QARecordedCase()
  {
   // Recorded order/pivot fixture: reports/qa/w33context_20261025/case.json.
   // This is the classifier replay, not a whole historical EA replay.
   for(int dir=-1;dir<=1;dir+=2)
     {
      W33Setup s;ZeroMemory(s);s.setup_id="RECORDED_20240403";s.symbol="XAUUSD+";s.upper_tf=PERIOD_M15;s.lower_tf=PERIOD_M5;s.direction=dir;
      s.wave1_start_time=D'2024.04.03 04:15';s.wave1_start_known_at=D'2024.04.03 05:00';s.wave1_peak_time=D'2024.04.03 06:15';
      s.wave1_peak_known_at=D'2024.04.03 07:00';s.wave1_peak_fixed=true;
      double mirror=4560;s.wave1_start_price=dir>0?2276.72:mirror-2276.72;s.wave1_peak_price=dir>0?2287.99:mirror-2287.99;
      s.entry_price=dir>0?2286.14:mirror-2286.14;s.sl_price=dir>0?2282.83:mirror-2282.83;s.tp_price=dir>0?2290.12:mirror-2290.12;
      W33Pivot p[];ArrayResize(p,2);ZeroMemory(p[0]);ZeroMemory(p[1]);p[0].time=D'2024.04.03 01:15';p[0].known_at=D'2024.04.03 02:00';
      p[0].tf=PERIOD_M15;p[0].price=dir>0?2288.35:mirror-2288.35;p[0].is_high=dir>0;p[1]=p[0];
      p[1].tf=PERIOD_H1;p[1].time=D'2024.04.03 01:00';p[1].known_at=D'2024.04.03 04:00';
      W33PriorContextBar bars[];ArrayResize(bars,2);
      for(int i=0;i<2;i++){ZeroMemory(bars[i]);bars[i].tf=i==0?PERIOD_M15:PERIOD_H1;bars[i].bar.time=i==0?D'2024.04.03 06:45':D'2024.04.03 06:00';bars[i].known_at=D'2024.04.03 07:00';bars[i].bar.close=dir>0?2285.10:mirror-2285.10;bars[i].bar.open=bars[i].bar.close;bars[i].bar.high=bars[i].bar.close+1;bars[i].bar.low=bars[i].bar.close-1;}
      W33PriorContextResult r;W33PriorContextEvaluate(s,p,bars,D'2024.04.03 07:05',0.05,r);
      string key=dir>0?"recorded_LONG":"synthetic_recorded_SHORT_mirror";
      QA(key+"_blocked",r.blocked && r.status=="BLOCKED");QA(key+"_H1_same_level_tie",r.selected.tf==PERIOD_H1);
      QA(key+"_halfwidth",MathAbs(r.halfwidth-0.5635)<1e-9,DoubleToString(r.halfwidth,10));
      QA(key+"_room_R",MathAbs(r.room_r-2.21/3.31)<1e-9,DoubleToString(r.room_r,10));
      QA(key+"_not_completed_double_pattern",!r.close_beyond && !r.entry_passed && r.tp_beyond);
     }
  }

void QAEngineBar(MqlRates &b,const datetime at,const double value,const int dir)
  {ZeroMemory(b);double p=dir>0?value:220-value;b.time=at;b.open=p-0.1*dir;b.close=p;b.high=p+0.3;b.low=p-0.3;b.tick_volume=100;b.spread=10;}
bool QAEngineSignal(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int dir,W33Event &signal)
  {
   g_engine.Configure(upper,lower,2,2,0.382,0.618,96,false,true);g_engine.Reset("SYNTHETIC");g_engine.SetTriggerMode(W33_PIVOT_BREAK);g_engine.SetPoint(0.01);
   double u[]={110,112,115,112,108,105,108,110,112,109,104,100,104,107,110,114,117,120,118,116};
   for(int i=0;i<ArraySize(u);i++){MqlRates b;QAEngineBar(b,qa_base+i*PeriodSeconds(upper),u[i],dir);g_engine.Feed(upper,b,b.time+PeriodSeconds(upper));}
   double l[]={117,118,119,117,115,113,114,115,116,114,112,110,111,112,114,117};
   for(int i=0;i<ArraySize(l);i++){MqlRates b;QAEngineBar(b,qa_base+20*PeriodSeconds(upper)+i*PeriodSeconds(lower),l[i],dir);g_engine.Feed(lower,b,b.time+PeriodSeconds(lower));}
   W33Event events[];g_engine.Drain(events);int count=0;for(int i=0;i<ArraySize(events);i++)if(events[i].event_type=="SIGNAL"){signal=events[i];count++;}return count==1;
  }
void QAActualSignal(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int dir,const string mode)
  {
   if(InpEnableTesterOrders && (!InpSkipPriorLevelRetest || mode!="BLOCKED"))return;
   string key=EnumToString(upper)+"_"+EnumToString(lower)+"_"+W33DirectionName(dir)+"_"+mode;
   W33Event signal;bool seeded=QAEngineSignal(upper,lower,dir,signal);QA("real_engine_fixture_"+key,seeded);if(!seeded)return;
   ArrayResize(g_records,0);g_upper=upper;g_lower=lower;W33Setup s;QABase(s,upper,lower,dir);s.setup_id=signal.setup.setup_id;
   s.signal_emitted=true;s.signal_at=signal.setup.signal_at;s.signal_known_at=signal.setup.signal_known_at;s.state=RESISTANCE_AND_RISK_CHECK;
   MqlTick tick;SymbolInfoTick(_Symbol,tick);double quote=dir>0?tick.ask:tick.bid;
   s.wave1_start_price=quote-dir*50;s.wave1_peak_price=quote+dir*50;s.wave2_extreme_price=quote-dir*70;
   s.wave2_extreme_time=qa_base+10*3600;s.wave2_extreme_known_at=qa_base+11*3600;
   g_prior.Close();QA("real_observer_open_"+key,g_prior.Open(InpRunTag+"_c"+IntegerToString(++qa_serial),"QA_",InpPriorContext,false,InpSkipPriorLevelRetest,InpPriorContextBandFraction));
   W33Pivot p;ZeroMemory(p);p.tf=PERIOD_H1;p.time=qa_base+3600;p.known_at=qa_base+4*3600;p.is_high=dir>0;
   p.price=s.wave1_peak_price+(mode=="CLEAR"?dir*20:0);QAPublish(g_prior,p);
   if(mode!="UNAVAILABLE"){MqlRates b;ZeroMemory(b);b.time=qa_base+10*3600;b.open=quote;b.close=quote;b.high=quote+1;b.low=quote-1;g_prior.ClosedBar(PERIOD_H1,b,qa_base+11*3600);}
   string why="";W33Setup expected=s;QA("plan_valid_"+key,Plan(expected,why),why);
   W33PriorContextResult r;g_prior.Evaluate(expected,TimeCurrent(),r);
   if(InpPriorContext || InpSkipPriorLevelRetest)QA("effective_measurement_"+key,r.status==mode,"status="+r.status+" reason="+r.reason);
   signal.setup=s;signal.at=TimeCurrent();signal.event_type="SIGNAL";signal.reason_kind="OBSERVATION";
   HandleSignal(signal);int n=RecordIndex(s.setup_id);bool skip=InpSkipPriorLevelRetest && mode=="BLOCKED";
   QA("actual_record_"+key,n>=0);if(n<0)return;
   QA("actual_handle_decision_"+key,skip?(g_records[n].setup.entry_status=="SKIPPED" && g_records[n].setup.skip_reason=="PRIOR_LEVEL_RETEST"):g_records[n].setup.entry_status=="DIAGNOSTIC_ONLY",g_records[n].setup.entry_status+" "+g_records[n].setup.skip_reason);
   QA("planned_prices_unchanged_"+key,MathAbs(g_records[n].setup.entry_price-expected.entry_price)<1e-10 && MathAbs(g_records[n].setup.sl_price-expected.sl_price)<1e-10 && MathAbs(g_records[n].setup.tp_price-expected.tp_price)<1e-10);
   QA("no_order_sent_"+key,g_records[n].setup.order_sent_at==0 && !g_records[n].pending && g_records[n].position_id==0);
   W33Setup active;bool isactive=g_engine.GetActive(dir,active);QA("direction_lane_"+key,skip?!isactive:isactive,"active="+(string)isactive);
   int count=ArraySize(g_records);HandleSignal(signal);QA("duplicate_no_resurrection_"+key,ArraySize(g_records)==count && g_records[n].setup.order_sent_at==0);
   g_prior.Close();
  }
void QAFinishGuards(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int dir)
  {
   W33Event signal;string key=EnumToString(upper)+"_"+W33DirectionName(dir);bool seeded=QAEngineSignal(upper,lower,dir,signal);QA("finish_guard_fixture_"+key,seeded);if(!seeded)return;
   QA("submitted_marks_"+key,g_engine.MarkOrderSubmitted(signal.setup.setup_id,true,TimeCurrent()));
   QA("accepted_pending_not_finished_"+key,!g_engine.FinishUnordered(signal.setup.setup_id,TimeCurrent(),"PRIOR_LEVEL_RETEST"));
   g_engine.MarkOrderSubmitted(signal.setup.setup_id,false,TimeCurrent());g_engine.MarkExecution(signal.setup.setup_id,true,TimeCurrent());
   QA("accepted_position_not_finished_"+key,!g_engine.FinishUnordered(signal.setup.setup_id,TimeCurrent(),"PRIOR_LEVEL_RETEST"));
   W33Setup active;QA("accepted_position_retained_"+key,g_engine.GetActive(dir,active) && active.position_open && active.state==POSITION_TRACKING);
  }
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;
   if(InpEnableTesterOrders && !InpSkipPriorLevelRetest){Print("Unsafe harness configuration refused");return INIT_PARAMETERS_INCORRECT;}
   if(!MathIsValidNumber(InpPriorContextBandFraction) || InpPriorContextBandFraction<0 || InpPriorContextBandFraction>1)
     {
      qa_file=FileOpen(InpRunTag+"_assertions.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,';',CP_UTF8);
      if(qa_file==INVALID_HANDLE)return INIT_FAILED;FileWrite(qa_file,"test","result","detail");
      int invalid_result=W33BaseOnInit();QA("actual_oninit_invalid_context_fraction_rejected",invalid_result==INIT_PARAMETERS_INCORRECT,IntegerToString(invalid_result));
      FileWrite(qa_file,"SUMMARY",qa_failures==0?"PASS":"FAIL",IntegerToString(qa_checks)+" checks; "+IntegerToString(qa_failures)+" failures; invalid init verified");
      FileClose(qa_file);qa_file=INVALID_HANDLE;return invalid_result;
     }
   int result=W33BaseOnInit();if(result!=INIT_SUCCEEDED)return result;
   qa_file=FileOpen(InpRunTag+"_assertions.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,';',CP_UTF8);if(qa_file==INVALID_HANDLE)return INIT_FAILED;
   FileWrite(qa_file,"test","result","detail");return INIT_SUCCEEDED;
  }
void OnTick()
  {
   static bool done=false;if(done)return;done=true;
   W33Setup initial;QABase(initial,g_upper,g_lower,1);W33Pivot ip[];W33PriorContextBar ib[];QAPivot(ip,PERIOD_H1,1);QABar(ib,PERIOD_H1,1);
   QAPublish(g_prior,ip[0]);g_prior.ClosedBar(ib[0].tf,ib[0].bar,ib[0].known_at);W33PriorContextResult ir;g_prior.Evaluate(initial,TimeCurrent(),ir);
   QA("actual_oninit_effective_observer",(InpPriorContext || InpSkipPriorLevelRetest)?ir.status=="BLOCKED":ir.status=="UNAVAILABLE",ir.status);
   QARecordedCase();
   ENUM_TIMEFRAMES upper[2]={PERIOD_M15,PERIOD_M5},lower[2]={PERIOD_M5,PERIOD_M1};
   for(int arm=0;arm<2;arm++)for(int dir=-1;dir<=1;dir+=2)
     {
      QAPure(upper[arm],lower[arm],dir);QAActualSignal(upper[arm],lower[arm],dir,"BLOCKED");
      if(!InpEnableTesterOrders){QAActualSignal(upper[arm],lower[arm],dir,"CLEAR");QAActualSignal(upper[arm],lower[arm],dir,"UNAVAILABLE");}
      QAFinishGuards(upper[arm],lower[arm],dir);
     }
   QA("native_no_positions_or_orders",PositionsTotal()==0 && OrdersTotal()==0);
   Print("PRIOR_CONTEXT_QA_SUMMARY checks=",qa_checks," failures=",qa_failures," orders=",OrdersTotal()," positions=",PositionsTotal());
   FileWrite(qa_file,"SUMMARY",qa_failures==0?"PASS":"FAIL",IntegerToString(qa_checks)+" checks; "+IntegerToString(qa_failures)+" failures; orders=0");
   FileClose(qa_file);qa_file=INVALID_HANDLE;ExpertRemove();
  }
void OnDeinit(const int reason){if(qa_file!=INVALID_HANDLE)FileClose(qa_file);W33BaseOnDeinit(reason);}
