#property strict
#property version "1.00"
#property description "Actual-engine connected opposite W1 cancellation tests; closed synthetic OHLC, no orders."
#include "../../Include/Wave33Visual/Engine.mqh"

input string InpRunTag="connected";
int g_file=INVALID_HANDLE,g_passed=0,g_failed=0;
datetime g_base=D'2025.06.02 00:00:00';

void Check(const string name,const bool passed,const string detail)
  {
   if(passed) g_passed++; else g_failed++;
   if(g_file!=INVALID_HANDLE) FileWrite(g_file,name,passed ? "PASS" : "FAIL",detail);
   Print("W33_CONNECTED_TEST ",passed ? "PASS " : "FAIL ",name," ",detail);
  }
string Key(const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const int d)
  { return EnumToString(u)+"_"+EnumToString(l)+"_"+W33DirectionName(d); }
void Bar(MqlRates &b,const ENUM_TIMEFRAMES tf,const int index,const double price,const int d)
  {
   ZeroMemory(b);
   b.time=g_base+index*PeriodSeconds(tf);
   b.open=d>0 ? price-0.1 : 220-price+0.1;
   b.close=d>0 ? price : 220-price;
   b.high=d>0 ? price+0.3 : 220-price+0.3;
   b.low=d>0 ? price-0.3 : 220-price-0.3;
   b.tick_volume=100; b.spread=10;
  }
bool Feed(CWave33Engine &e,const ENUM_TIMEFRAMES tf,const int index,const double price,const int d,const datetime known=0)
  {
   MqlRates b; Bar(b,tf,index,price,d);
   return e.Feed(tf,b,known==0 ? b.time+PeriodSeconds(tf) : known);
  }
void Configure(CWave33Engine &e,const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const bool enabled=true,const bool setter=true)
  {
   e.Configure(u,l,2,2,0.382,0.618,96,false,true);
   e.SetPoint(0.01); e.SetLifecyclePolicy(true); e.SetDeepFibClosePolicy(false);
   e.SetLowerRecognition(W33_NORMALIZED_OR_SIMPLE); e.SetTriggerMode(W33_PIVOT_BREAK);
   if(setter) e.SetConnectedOppositePolicy(enabled);
   e.Reset("CONNECTED_SYNTHETIC");
  }
void Seed(CWave33Engine &e,const ENUM_TIMEFRAMES u,const int d)
  {
   double p[]={110,112,115,112,108,105,108,110,112,109,104,100,104,107,110,114,117,120,118,116};
   for(int i=0;i<ArraySize(p);i++) Feed(e,u,i,p[i],d);
  }
void ReversePrefix(CWave33Engine &e,const ENUM_TIMEFRAMES u,const int d)
  {
   double p[]={113,110,113,115};
   for(int i=0;i<ArraySize(p);i++) Feed(e,u,20+i,p[i],d);
  }
int Count(const W33Event &events[],const string type,const string id="",const string reason="")
  {
   int n=0;
   for(int i=0;i<ArraySize(events);i++)
      if(events[i].event_type==type && (id=="" || events[i].setup.setup_id==id) &&
         (reason=="" || events[i].reason==reason)) n++;
   return n;
  }
void Signal(CWave33Engine &e,const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const int d)
  {
   // Independent closed synthetic upper/lower fixtures exercise the real
   // recognizer. They make no claim to reconstruct a recorded tick path.
   double p[]={116,114,110,111,113,115,113,112,113,116};
   int r=PeriodSeconds(u)/PeriodSeconds(l);
   for(int i=0;i<ArraySize(p);i++) Feed(e,l,20*r+i,p[i],d);
  }
void TestCancellation(const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const int d,const bool signalled)
  {
   CWave33Engine e; Configure(e,u,l); Seed(e,u,d);
   if(signalled) Signal(e,u,l,d);
   W33Setup older; bool prior=e.GetActive(d,older);
   string key=Key(u,l,d)+(signalled ? "_signal" : "_candidate");
   Check("fixture_old_fixed_"+key,prior && older.wave1_peak_fixed && older.signal_emitted==signalled,
         "The original candidate and optional signal come from actual closed-bar engine processing");
   ReversePrefix(e,u,d);
   W33Event discarded[]; e.Drain(discarded);
   bool accepted=Feed(e,u,24,109,d);
   W33Setup oldAfter,newer; bool oldActive=e.GetActive(d,oldAfter),newActive=e.GetActive(-d,newer);
   W33Event events[]; e.Drain(events);
   datetime now=g_base+25*PeriodSeconds(u);
   Check("adopted_reverse_cancels_old_"+key,accepted && !oldActive && newActive && oldAfter.setup_id==older.setup_id &&
         oldAfter.connected_opposite_cancelled && oldAfter.skip_reason=="CONNECTED_OPPOSITE_W1_CANDIDATE",
         "A genuinely adopted opposite candidate invalidates only the old unordered setup");
   Check("shared_anchor_provenance_"+key,newer.wave1_start_time==older.wave1_peak_time &&
         MathAbs(newer.wave1_start_price-older.wave1_peak_price)<=0.005 &&
         oldAfter.connected_shared_time==older.wave1_peak_time && oldAfter.connected_shared_price==older.wave1_peak_price &&
         oldAfter.connected_opposite_setup_id==newer.setup_id && oldAfter.connected_opposite_known_at==now,
         "Cancellation links the two setup IDs and retains the shared candle, price and current availability");
   Check("candidate_not_future_peak_"+key,!newer.wave1_peak_fixed && newer.wave1_peak_known_at==0 &&
         newer.candidate_detected_at==now && oldAfter.last_updated_at==now,
         "Cancellation uses the already known origin at candidate detection and never waits for or invents its later endpoint");
   int breakIndex=-1,cancelIndex=-1;
   bool classification=false;
   for(int j=0;j<ArraySize(events);j++)
     {
      if(events[j].event_type=="WAVE1_BREAK" && events[j].setup.setup_id==newer.setup_id) breakIndex=j;
      if(events[j].event_type=="INVALIDATE" && events[j].setup.setup_id==older.setup_id)
        {
         cancelIndex=j;
         classification=events[j].at==now && events[j].reason_kind=="EXCLUSION" &&
                        events[j].reason=="CONNECTED_OPPOSITE_W1_CANDIDATE" && events[j].setup.entry_status=="INVALIDATED";
        }
     }
   Check("event_order_exclusion_"+key,breakIndex>=0 && cancelIndex>breakIndex && classification &&
         Count(events,"INVALIDATE",older.setup_id)==1 && Count(events,"COMPLETED",older.setup_id)==0,
         "The new break is published before exactly one explicit exclusion, even for an unordered diagnostic signal");
   int r=PeriodSeconds(u)/PeriodSeconds(l);
   double p[]={113,111,110,111,113,116,114,112,114,117};
   for(int j=0;j<ArraySize(p);j++) Feed(e,l,26*r+j,p[j],d);
   Feed(e,u,24,109,d,now+1);
   W33Event later[]; e.Drain(later);
   Check("cancelled_never_resignals_"+key,Count(later,"SIGNAL",older.setup_id)==0 && Count(later,"INVALIDATE",older.setup_id)==0 &&
         !e.MarkOrderSubmitted(older.setup_id,true,now+10*PeriodSeconds(u)),
         "Later lower bars and repeated upper delivery cannot create a second signal or submit the terminally cancelled setup");
  }
void TestPolicyOff(const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const int d)
  {
   for(int setter=0;setter<2;setter++)
     {
      CWave33Engine e; Configure(e,u,l,false,setter==1); Seed(e,u,d);
      W33Setup older; e.GetActive(d,older);
      ReversePrefix(e,u,d); Feed(e,u,24,109,d);
      W33Setup after,newer; bool active=e.GetActive(d,after),reverse=e.GetActive(-d,newer);
      W33Event events[]; e.Drain(events);
      Check("off_or_constructor_default"+IntegerToString(setter)+"_"+Key(u,l,d),active && reverse && after.setup_id==older.setup_id &&
            !after.connected_opposite_cancelled && Count(events,"INVALIDATE",older.setup_id,"CONNECTED_OPPOSITE_W1_CANDIDATE")==0,
            "Explicit OFF and the constructor default retain existing independent directional lanes");
     }
  }
void TestKnowledgeTime(const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const int d)
  {
   CWave33Engine e; Configure(e,u,l); Seed(e,u,d); ReversePrefix(e,u,d);
   W33Setup before; e.GetActive(d,before); W33Event discarded[]; e.Drain(discarded);
   datetime close=g_base+25*PeriodSeconds(u),delayed=close+2*PeriodSeconds(u);
   bool forming=Feed(e,u,24,109,d,close-1); W33Setup after;
   bool active=e.GetActive(d,after);
   Check("forming_break_no_cancel_"+Key(u,l,d),!forming && active && !after.connected_opposite_cancelled,
         "An unfinished upper break candle cannot adopt a reverse candidate or cancel an older setup");
   Feed(e,u,24,109,d,delayed); e.GetActive(d,after);
   W33Setup newer; e.GetActive(-d,newer); W33Event events[]; e.Drain(events);
   Check("late_delivery_not_backdated_"+Key(u,l,d),after.connected_opposite_known_at==delayed && after.last_updated_at==delayed &&
         newer.candidate_detected_at==delayed && newer.upper_break_confirmed_at==close &&
         Count(events,"INVALIDATE",before.setup_id,"CONNECTED_OPPOSITE_W1_CANDIDATE")==1,
         "Theoretical candle close and actual late knowledge remain distinct and cancellation is published only now");
  }
void TestOrderProtection(const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const int d)
  {
   for(int mode=0;mode<2;mode++)
     {
      CWave33Engine e; Configure(e,u,l); Seed(e,u,d); Signal(e,u,l,d);
      W33Setup older; e.GetActive(d,older);
      bool marked=e.MarkOrderSubmitted(older.setup_id,true,older.signal_known_at);
      if(mode==1) marked=marked && e.MarkExecution(older.setup_id,true,older.signal_known_at);
      ReversePrefix(e,u,d); Feed(e,u,24,109,d);
      W33Setup after,newer; bool active=e.GetActive(d,after),reverse=e.GetActive(-d,newer);
      W33Event events[]; e.Drain(events);
      Check("submitted_or_position_protected"+IntegerToString(mode)+"_"+Key(u,l,d),older.signal_emitted && marked && active && reverse &&
            !after.connected_opposite_cancelled && after.position_open==(mode==1) &&
            Count(events,"INVALIDATE",older.setup_id,"CONNECTED_OPPOSITE_W1_CANDIDATE")==0,
            "Neither a submitted order nor an actual open position is cancelled by the candidate-only policy");
      datetime now=g_base+25*PeriodSeconds(u);
      Check("finish_cannot_release_order"+IntegerToString(mode)+"_"+Key(u,l,d),!e.FinishUnordered(older.setup_id,now,"TEST_PENDING"),
            "A final unordered completion cannot release a submitted order or an open position");
      if(mode==0)
        {
         bool released=e.MarkOrderSubmitted(older.setup_id,false,now);
         Check("failed_submission_releases_guard_"+Key(u,l,d),released && e.FinishUnordered(older.setup_id,now,"TEST_REJECTED"),
               "A caller can explicitly release a rejected order's guard before completing that unordered setup");
        }
     }
   CWave33Engine rejected; Configure(rejected,u,l); Seed(rejected,u,d);
   W33Setup s; rejected.GetActive(d,s);
   Check("untriggered_cannot_be_submitted_"+Key(u,l,d),!rejected.MarkOrderSubmitted(s.setup_id,true,s.last_updated_at),
         "A fabricated submission cannot protect an untriggered candidate");
  }
void TestProvisionalLaneDoesNotCancel(const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const int d)
  {
   CWave33Engine e; Configure(e,u,l,false); Seed(e,u,d); Signal(e,u,l,d);
   W33Setup lane; e.GetActive(d,lane);
   bool marked=e.MarkOrderSubmitted(lane.setup_id,true,lane.signal_known_at);
   ReversePrefix(e,u,d); Feed(e,u,24,109,d);
   double p[]={106,104,108,110};
   for(int j=0;j<ArraySize(p);j++) Feed(e,u,25+j,p[j],d);
   W33Setup reverse; bool before=e.GetActive(-d,reverse);
   e.SetConnectedOppositePolicy(true);
   Feed(e,u,29,112,d);
   W33Event discarded[]; e.Drain(discarded);
   Feed(e,u,30,116,d);
   W33Setup after,original; bool reverseActive=e.GetActive(-d,after),laneActive=e.GetActive(d,original);
   W33Event events[]; e.Drain(events);
   Check("skipped_lane_break_no_side_effect_"+Key(u,l,d),before && reverse.wave1_peak_fixed && reverseActive && laneActive &&
         after.setup_id==reverse.setup_id && original.setup_id==lane.setup_id && !after.connected_opposite_cancelled &&
         Count(events,"SKIP","","ACTIVE_SETUP_SAME_DIRECTION")==1 &&
         Count(events,"INVALIDATE",reverse.setup_id,"CONNECTED_OPPOSITE_W1_CANDIDATE")==0,
         "A temporary break rejected by the occupied same-direction lane cannot cancel the opposite adopted setup");
   datetime now=g_base+31*PeriodSeconds(u);
   bool protectedLane=!e.FinishUnordered(lane.setup_id,now,"TEST_PENDING");
   bool released=e.MarkOrderSubmitted(lane.setup_id,false,now);
   Check("temporary_create_restores_submission_"+Key(u,l,d),marked && protectedLane && released &&
         e.FinishUnordered(lane.setup_id,now,"TEST_REJECTED"),
         "The temporary setup snapshot restores the original submitted-order guard as well as its strategy fields");
  }
void TestPureBoundaries()
  {
   W33Setup old,newer; ZeroMemory(old); ZeroMemory(newer);
   datetime now=g_base+3600;
   old.setup_id="old"; old.symbol="X"; old.upper_tf=PERIOD_M15; old.lower_tf=PERIOD_M5;
   old.direction=1; old.active=true; old.wave1_peak_fixed=true; old.candidate_detected_at=g_base;
   old.wave1_peak_time=g_base+900; old.wave1_peak_price=120; old.wave1_peak_known_at=g_base+1800;
   old.last_updated_at=g_base+1800;
   newer.setup_id="new"; newer.symbol="X"; newer.upper_tf=PERIOD_M15; newer.lower_tf=PERIOD_M5;
   newer.direction=-1; newer.active=true; newer.candidate_detected_at=now;
   newer.wave1_start_time=old.wave1_peak_time; newer.wave1_start_price=old.wave1_peak_price;
   newer.wave1_start_known_at=old.wave1_peak_known_at; newer.upper_break_confirmed_at=now;
   Check("pure_matching_anchor",W33ConnectedOppositeUnordered(old,newer,false,now,0.01),"A known exact shared endpoint qualifies");
   for(int variant=0;variant<21;variant++)
     {
      W33Setup a=old,b=newer; bool submitted=false; datetime known=now; double point=0.01;
      switch(variant)
        {
         case 0: a.wave1_peak_fixed=false; break;
         case 1: a.position_open=true; break;
         case 2: submitted=true; break;
         case 3: a.order_sent_at=now; break;
         case 4: a.fill_at=now; break;
         case 5: a.active=false; break;
         case 6: b.active=false; break;
         case 7: b.direction=a.direction; break;
         case 8: b.symbol="Y"; break;
         case 9: b.upper_tf=PERIOD_M5; break;
         case 10: b.lower_tf=PERIOD_M1; break;
         case 11: b.candidate_detected_at=a.candidate_detected_at; break;
         case 12: a.wave1_peak_known_at=now+1; break;
         case 13: b.wave1_start_known_at=now+1; break;
         case 14: b.upper_break_confirmed_at=now+1; break;
         case 15: b.wave1_start_time++; break;
         case 16: b.wave1_start_price+=0.00501; break;
         case 17: known=now-1; break;
         case 18: a.connected_opposite_cancelled=true; break;
         case 19: a.last_updated_at=now+1; break;
         case 20: point=0; break;
        }
      Check("pure_reject_boundary_"+IntegerToString(variant),!W33ConnectedOppositeUnordered(a,b,submitted,known,point),
            "Unfixed, ordered, inactive, mismatched, same-age, future-known and disconnected snapshots cannot qualify");
     }
   newer.wave1_start_price=old.wave1_peak_price+0.005;
   Check("pure_half_point_inclusive",W33ConnectedOppositeUnordered(old,newer,false,now,0.01),
         "Exact half-point equality is accepted with arithmetic-only representation tolerance");
   old.signal_emitted=true;
   Check("pure_signal_without_order_allowed",W33ConnectedOppositeUnordered(old,newer,false,now,0.01),
         "An emitted diagnostic signal without any submission or fill is still unordered");
  }
int OnInit()
  {
   g_file=FileOpen("W33Harness_"+InpRunTag+".csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(g_file==INVALID_HANDLE) return INIT_FAILED;
   FileWrite(g_file,"test","passed","detail");
   TestPureBoundaries();
   for(int pair=0;pair<2;pair++)
     {
      ENUM_TIMEFRAMES u=pair==0 ? PERIOD_M15 : PERIOD_M5,l=pair==0 ? PERIOD_M5 : PERIOD_M1;
      for(int d=1;d>=-1;d-=2)
        {
         TestCancellation(u,l,d,false); TestCancellation(u,l,d,true);
         TestPolicyOff(u,l,d); TestKnowledgeTime(u,l,d); TestOrderProtection(u,l,d);
         TestProvisionalLaneDoesNotCancel(u,l,d);
        }
     }
   FileWrite(g_file,"FINAL",g_failed==0 ? "PASS" : "FAIL",StringFormat("passed=%d failed=%d",g_passed,g_failed));
   FileFlush(g_file); FileClose(g_file); g_file=INVALID_HANDLE;
   PrintFormat("W33_CONNECTED_HARNESS_FINAL passed=%d failed=%d",g_passed,g_failed);
   return INIT_SUCCEEDED;
  }
void OnTick() { if(MQLInfoInteger(MQL_TESTER)) TesterStop(); }
double OnTester() { return g_failed==0 ? 1.0 : 0.0; }
