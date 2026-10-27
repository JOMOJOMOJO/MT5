// Native tester QA wrapper: execute the REAL EA HandleSignal and observer.
// Test orders are disabled except the all-CHOPPY safety run, which must be gated.
#define OnInit W33BaseOnInit
#define OnTick W33BaseOnTick
#define OnDeinit W33BaseOnDeinit
#define OnTradeTransaction W33BaseOnTradeTransaction
#include "../Wave33ChopDiagnostic.mq5"
#undef OnInit
#undef OnTick
#undef OnDeinit
#undef OnTradeTransaction

int qa_file=INVALID_HANDLE,qa_checks=0,qa_failures=0,qa_observer_serial=0;
datetime qa_base=D'2020.01.01 00:00:00';
void QA(const string name,const bool ok,const string detail="")
  {
   qa_checks++;if(!ok)qa_failures++;
   Print("CHOP_FILTER_QA ",name," ",ok?"PASS":"FAIL"," ",detail);
   FileWrite(qa_file,name,ok?"PASS":"FAIL",detail);
  }
void QABase(W33Setup &s,const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int dir)
  {
   ZeroMemory(s);s.setup_id="QA";s.symbol=_Symbol;s.upper_tf=upper;s.lower_tf=lower;s.direction=dir;
   s.wave1_start_time=qa_base+60;s.wave1_start_known_at=qa_base+120;
   s.wave1_peak_time=qa_base+600;s.wave1_peak_known_at=qa_base+780;s.wave1_peak_fixed=true;
   s.wave1_start_price=dir>0?100:200;s.wave1_peak_price=dir>0?110:190;
  }
void QAPivot(W33Pivot &p[],const int src,const int known,const double price,const bool high,const ENUM_TIMEFRAMES tf)
  {
   int n=ArraySize(p);ArrayResize(p,n+1);ZeroMemory(p[n]);p[n].time=qa_base+src;p[n].known_at=qa_base+known;
   p[n].price=price;p[n].is_high=high;p[n].tf=tf;
  }
void QAPublish(CWave33ChopObserver &observer,const W33Pivot &p)
  {W33Event e;ZeroMemory(e);e.at=p.known_at;e.event_type="SWING_CONFIRMED";e.has_pivot=true;e.pivot=p;observer.Event(e);}
void QAMetric(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int dir)
  {
   W33Setup s;QABase(s,upper,lower,dir);W33Pivot p[];
   QAPivot(p,180,300,dir>0?108:192,dir>0,lower);
   QAPivot(p,300,420,dir>0?103:197,dir<0,lower);
   string key=EnumToString(upper)+"_"+EnumToString(lower)+"_"+W33DirectionName(dir);
   W33ChopResult r;W33ChopEvaluate(s,p,qa_base+900,qa_base,r);
   QA("exact_threshold_"+key,r.status=="CHOPPY" && MathAbs(r.ratio-0.5)<1e-12);
   QA("gate_on_threshold_"+key,W33ChopShouldSkip(true,r));
   QA("gate_off_identity_"+key,!W33ChopShouldSkip(false,r));
   p[1].price+=dir*0.01;W33ChopEvaluate(s,p,qa_base+900,qa_base,r);
   QA("below_threshold_"+key,r.status=="CLEAN" && MathAbs(r.ratio-0.499)<1e-12 && !W33ChopShouldSkip(true,r));
   p[1].known_at=qa_base+901;W33ChopEvaluate(s,p,qa_base+900,qa_base,r);
   QA("future_pivot_ignored_"+key,r.status=="CLEAN" && r.raw_pivots==1 && r.ratio==0);
   W33ChopEvaluate(s,p,qa_base+900,0,r);
   QA("unavailable_not_rejected_"+key,r.status=="UNAVAILABLE" && !W33ChopShouldSkip(true,r));
   CWave33ChopObserver observer;observer.Open(InpRunTag+"_p"+IntegerToString(++qa_observer_serial),"QA_",lower,true,false,true);
   observer.AcceptedLowerBar(qa_base);p[1].known_at=qa_base+900;
   QAPublish(observer,p[0]);observer.Evaluate(s,qa_base+900,r);
   QA("same_time_unpublished_excluded_"+key,r.status=="CLEAN" && r.normalized_pivots==1);
   QAPublish(observer,p[1]);observer.Evaluate(s,qa_base+900,r);
   QA("same_time_published_included_"+key,r.status=="CLEAN" && MathAbs(r.ratio-0.499)<1e-12 && r.normalized_pivots==2);
   observer.Close();
   s.wave1_peak_price=s.wave1_start_price+dir*6.07;p[0].price=s.wave1_start_price+dir*6.0;
   p[1].price=p[0].price-dir*5.61;p[1].known_at=qa_base+420;
   W33ChopEvaluate(s,p,qa_base+900,qa_base,r);
   QA("reported_example_arithmetic_"+key,r.status=="CHOPPY" && MathAbs(r.adverse-5.61)<1e-10 && MathAbs(r.ratio-5.61/6.07)<1e-10 &&
      W33ChopShouldSkip(true,r) && !W33ChopShouldSkip(false,r),DoubleToString(r.ratio,10));
  }
void QABar(MqlRates &b,const datetime at,const double value,const int dir)
  {
   ZeroMemory(b);double p=dir>0?value:220-value;b.time=at;b.open=p-0.1*dir;b.close=p;b.high=p+0.3;b.low=p-0.3;
   b.tick_volume=100;b.spread=10;
  }
bool QAEngineSignal(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int dir,W33Event &signal)
  {
   g_engine.Configure(upper,lower,2,2,0.382,0.618,96,false,true);g_engine.Reset("SYNTHETIC");
   g_engine.SetTriggerMode(W33_PIVOT_BREAK);g_engine.SetPoint(0.01);
   double u[]={110,112,115,112,108,105,108,110,112,109,104,100,104,107,110,114,117,120,118,116};
   for(int i=0;i<ArraySize(u);i++){MqlRates b;QABar(b,qa_base+i*PeriodSeconds(upper),u[i],dir);g_engine.Feed(upper,b,b.time+PeriodSeconds(upper));}
   double l[]={117,118,119,117,115,113,114,115,116,114,112,110,111,112,114,117};
   for(int i=0;i<ArraySize(l);i++){MqlRates b;QABar(b,qa_base+20*PeriodSeconds(upper)+i*PeriodSeconds(lower),l[i],dir);g_engine.Feed(lower,b,b.time+PeriodSeconds(lower));}
   W33Event events[];g_engine.Drain(events);int count=0;
   for(int i=0;i<ArraySize(events);i++)if(events[i].event_type=="SIGNAL"){signal=events[i];count++;}
   return count==1;
  }
void QAActualSignal(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int dir,const string mode)
  {
   string key=EnumToString(upper)+"_"+EnumToString(lower)+"_"+W33DirectionName(dir)+"_"+mode;
   W33Event signal;bool seeded=QAEngineSignal(upper,lower,dir,signal);QA("real_engine_fixture_"+key,seeded);if(!seeded)return;
   ArrayResize(g_records,0);g_upper=upper;g_lower=lower;
   W33Setup s;QABase(s,upper,lower,dir);s.setup_id=signal.setup.setup_id+"_"+mode;
   // Keep actual engine ID for FinishUnordered. The price/anchor injection is
   // deliberate: isolate the gate while Plan uses a genuine tester quote.
   s.setup_id=signal.setup.setup_id;s.signal_emitted=true;s.signal_at=signal.setup.signal_at;
   s.signal_known_at=signal.setup.signal_known_at;s.state=RESISTANCE_AND_RISK_CHECK;
   MqlTick tick;SymbolInfoTick(_Symbol,tick);double quote=dir>0?tick.ask:tick.bid;
   s.wave1_start_price=quote-dir*50;s.wave1_peak_price=quote+dir*50;s.wave2_extreme_price=quote-dir*20;
   s.wave2_extreme_time=qa_base+900;s.wave2_extreme_known_at=qa_base+960;
   g_chop.Close();bool effective=InpChopDiagnostic || InpSkipChoppyWave1;
   QA("observer_open_"+key,g_chop.Open(InpRunTag+"_c"+IntegerToString(++qa_observer_serial),"QA_",lower,effective,false,InpSkipChoppyWave1));
   if(mode!="UNAVAILABLE")g_chop.AcceptedLowerBar(qa_base);
   W33Pivot p[];QAPivot(p,180,300,quote+dir*30,dir>0,lower);
   QAPivot(p,300,420,quote-dir*(mode=="CLEAN"?19.9:20),dir<0,lower);
   for(int i=0;i<ArraySize(p);i++)QAPublish(g_chop,p[i]);
   W33ChopResult measured;g_chop.Evaluate(s,TimeCurrent(),measured);
   if(effective)QA("effective_measurement_"+key,measured.status==mode,"status="+measured.status+" ratio="+DoubleToString(measured.ratio,8));
   signal.setup=s;signal.at=TimeCurrent();signal.event_type="SIGNAL";signal.reason_kind="OBSERVATION";
   // Orders-enabled runs intentionally invoke ONLY a proven CHOPPY gate.
   if(InpEnableTesterOrders && (!InpSkipChoppyWave1 || mode!="CHOPPY"))return;
   HandleSignal(signal);int n=RecordIndex(s.setup_id);
   bool skip=InpSkipChoppyWave1 && mode=="CHOPPY";
   QA("actual_handle_record_"+key,n>=0);
   if(n<0)return;
   QA("actual_handle_decision_"+key,skip ? (g_records[n].setup.entry_status=="SKIPPED" && g_records[n].setup.skip_reason=="CHOPPY_WAVE1") :
      g_records[n].setup.entry_status=="DIAGNOSTIC_ONLY","status="+g_records[n].setup.entry_status+" reason="+g_records[n].setup.skip_reason);
   QA("no_order_sent_"+key,g_records[n].setup.order_sent_at==0 && !g_records[n].pending && g_records[n].position_id==0);
   W33Setup active;bool isactive=g_engine.GetActive(dir,active);
   QA("direction_lane_"+key,skip?!isactive:isactive,"active="+(string)isactive);
   int before=ArraySize(g_records);HandleSignal(signal);
   QA("duplicate_no_resurrection_"+key,ArraySize(g_records)==before && g_records[n].setup.order_sent_at==0);
   g_chop.Close();
  }
void QAFinishGuards(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int dir)
  {
   W33Event signal;string key=EnumToString(upper)+"_"+W33DirectionName(dir);
   bool seeded=QAEngineSignal(upper,lower,dir,signal);QA("finish_guard_fixture_"+key,seeded);if(!seeded)return;
   QA("submitted_marks_"+key,g_engine.MarkOrderSubmitted(signal.setup.setup_id,true,TimeCurrent()));
   QA("accepted_pending_not_finished_"+key,!g_engine.FinishUnordered(signal.setup.setup_id,TimeCurrent(),"CHOPPY_WAVE1"));
   g_engine.MarkOrderSubmitted(signal.setup.setup_id,false,TimeCurrent());g_engine.MarkExecution(signal.setup.setup_id,true,TimeCurrent());
   QA("accepted_position_not_finished_"+key,!g_engine.FinishUnordered(signal.setup.setup_id,TimeCurrent(),"CHOPPY_WAVE1"));
   W33Setup active;QA("accepted_position_retained_"+key,g_engine.GetActive(dir,active) && active.position_open && active.state==POSITION_TRACKING);
  }
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;
   if(InpEnableTesterOrders && !InpSkipChoppyWave1){Print("Unsafe harness configuration refused");return INIT_PARAMETERS_INCORRECT;}
   int result=W33BaseOnInit();if(result!=INIT_SUCCEEDED)return result;
   qa_file=FileOpen(InpRunTag+"_assertions.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,';',CP_UTF8);
   if(qa_file==INVALID_HANDLE)return INIT_FAILED;FileWrite(qa_file,"test","result","detail");return INIT_SUCCEEDED;
  }
void OnTick()
  {
   static bool done=false;if(done)return;done=true;
   // Exercise the actual OnInit force-on branch before replacing the observer.
   W33Setup initial;QABase(initial,g_upper,g_lower,1);g_chop.AcceptedLowerBar(qa_base);W33ChopResult r;
   g_chop.Evaluate(initial,TimeCurrent(),r);
   QA("actual_oninit_effective_observer",(InpChopDiagnostic || InpSkipChoppyWave1)?r.status=="CLEAN":r.status=="UNAVAILABLE",r.status);
   ENUM_TIMEFRAMES upper[2]={PERIOD_M15,PERIOD_M5},lower[2]={PERIOD_M5,PERIOD_M1};
   for(int arm=0;arm<2;arm++)for(int dir=-1;dir<=1;dir+=2)
     {
      QAMetric(upper[arm],lower[arm],dir);
      QAActualSignal(upper[arm],lower[arm],dir,"CHOPPY");
      if(!InpEnableTesterOrders){QAActualSignal(upper[arm],lower[arm],dir,"CLEAN");QAActualSignal(upper[arm],lower[arm],dir,"UNAVAILABLE");}
      QAFinishGuards(upper[arm],lower[arm],dir);
     }
   QA("native_no_positions_or_orders",PositionsTotal()==0 && OrdersTotal()==0);
   Print("CHOP_FILTER_QA_SUMMARY checks=",qa_checks," failures=",qa_failures," orders=",OrdersTotal()," positions=",PositionsTotal());
   FileWrite(qa_file,"SUMMARY",qa_failures==0?"PASS":"FAIL",IntegerToString(qa_checks)+" checks; "+IntegerToString(qa_failures)+" failures; orders=0");
   FileClose(qa_file);qa_file=INVALID_HANDLE;ExpertRemove();
  }
void OnDeinit(const int reason)
  {if(qa_file!=INVALID_HANDLE)FileClose(qa_file);W33BaseOnDeinit(reason);}
