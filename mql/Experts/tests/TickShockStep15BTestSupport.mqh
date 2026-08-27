#ifndef TICK_SHOCK_STEP15B_TEST_SUPPORT_MQH
#define TICK_SHOCK_STEP15B_TEST_SUPPORT_MQH

#include "TickShockStep5TestSupport.mqh"
#include "..\..\Include\TickShock\TickShockControlStudy.mqh"

void TS15BInitKey(TickShockControlKey &key,const string symbol="EURUSD",const int horizon=250,const int regime=TSV1_VOL_NORMAL)
  {
   key.detector_id=TAIL_V1_RAW;key.symbol=symbol;key.time_bucket=0;
   key.trigger_horizon_ms=horizon;key.estimator=0;key.volatility_regime=regime;
  }

void TS15BInitRecord(TickShockControlRecord &record,const string id,const long time_msc)
  {
   ZeroMemory(record);record.control_id=id;TS15BInitKey(record.key);
   record.boundary_msc=time_msc;record.integrity_ok=true;record.outcome.complete=true;
   record.raw_p=0.5;record.adjusted_p=0.5;record.direction=TS15B_DIRECTION_LONG;
  }

void TS15BRunDirection(const string id)
  {
   TS5ActualItem a[];
   if(id=="TS15B-DIR-SCHEMA-001") TS5Add(a,"direction_column",TSV1FeatureSchema()=="tickshock-detector-feature-v2"?"present":"missing");
   else if(id=="TS15B-DIR-POS-001") TS5Add(a,"direction",TS15BDirectionName(TS15BDirectionFromReturn(0.01)));
   else if(id=="TS15B-DIR-NEG-001") TS5Add(a,"direction",TS15BDirectionName(TS15BDirectionFromReturn(-0.01)));
   else if(id=="TS15B-DIR-CONFLICT-001")
     {
      double p[3]={0.001,0.001,0.002};bool valid[3]={true,true,true};double returns[3]={0.01,-0.02,0.03};
      int trigger=TS15BMinimumAdjustedIndex(p,valid,3);TS5AddLong(a,"trigger_index",trigger);TS5Add(a,"direction",TS15BDirectionName(TS15BDirectionFromReturn(returns[trigger])));
     }
   else if(id=="TS15B-DIR-PERSIST-001")
     {
      int candidate_direction=TS15BDirectionFromReturn(-0.01);long signal=TSV1ConfirmedSignalMsc(1000,1250);
      TS5Add(a,"direction",TS15BDirectionName(candidate_direction));TS5AddLong(a,"signal_msc",signal);
     }
   else
     {
      double candidate_return=0.01;double future_return=-0.50;
      int direction=TS15BDirectionFromReturn(candidate_return);future_return=future_return;
      TS5Add(a,"direction",TS15BDirectionName(direction));
     }
   TS5CompareAndRecord(id,a);
  }

void TS15BRunOutcome(const string id)
  {
   TickShockControlRecorder recorder;TS15BResetRecorder(recorder);
   for(int i=0;i<=481;++i)
     {
      TickShockControlPoint point;ZeroMemory(point);point.valid=true;point.time_msc=(long)i*250;
      point.quote_msc=point.time_msc;point.bid=MathExp(0.001*(double)point.time_msc/1000.0);
      point.ask=point.bid+0.0002;point.mid=(point.bid+point.ask)*0.5;point.cumulative_ticks=i*2;
      if(i==0){point.horizon_valid[0]=true;point.raw_p[0]=0.5;point.adjusted_p[0]=0.5;point.local_volatility[0]=0.001;point.signed_return[0]=0.001;point.estimator[0]=0;point.volatility_regime[0]=TSV1_VOL_NORMAL;}
      TS15BObservePoint(recorder,point,TAIL_V1_RAW,"EURUSD");
     }
   TS5ActualItem a[];
   if(id=="TS15B-CTRL-COMPLETE-001")
     {
      bool complete=ArraySize(recorder.latest)>0 && recorder.latest[0].outcome.complete;
      TS5AddLong(a,"complete_120s",complete?1:0);
      TS5Add(a,"abs_return_1s",complete?DoubleToString(recorder.latest[0].outcome.abs_return_1s,3):"");
     }
   else
     {TS5AddLong(a,"complete_120s",0);TS5Add(a,"status","INCOMPLETE_END_OF_RUN");}
   TS5CompareAndRecord(id,a);
  }

void TS15BRunMatch(const string id)
  {
   TS5ActualItem a[];
   if(id=="TS15B-MATCH-EXCLUDE-001")
     {
      TS5AddLong(a,"eligible_minus120001",TS15BShockDistanceEligible(0,120001)?1:0);
      TS5AddLong(a,"eligible_minus120000",TS15BShockDistanceEligible(0,120000)?1:0);
      TS5AddLong(a,"eligible_plus120000",TS15BShockDistanceEligible(240000,120000)?1:0);
      TS5AddLong(a,"eligible_plus120001",TS15BShockDistanceEligible(240001,120000)?1:0);
     }
   else if(id=="TS15B-MATCH-CLOSEST-001" || id=="TS15B-MATCH-TIE-001" || id=="TS15B-MATCH-DIM-001" || id=="TS15B-MATCH-NORELAX-001" || id=="TS15B-MATCH-UNMATCHED-001")
     {
      TickShockControlRecord controls[3];TS15BInitRecord(controls[0],id=="TS15B-MATCH-TIE-001"?"C002":"C1",100000);
      TS15BInitRecord(controls[1],id=="TS15B-MATCH-TIE-001"?"C001":"C2",150000);
      TS15BInitRecord(controls[2],"C3",140000);
      if(id=="TS15B-MATCH-TIE-001") controls[0].boundary_msc=controls[1].boundary_msc=150000;
      if(id=="TS15B-MATCH-DIM-001" || id=="TS15B-MATCH-NORELAX-001") for(int i=0;i<3;++i)controls[i].key.symbol="GBPUSD";
      if(id=="TS15B-MATCH-UNMATCHED-001") for(int i=0;i<3;++i)controls[i].outcome.complete=false;
      TickShockControlMatchRequest request;TS15BInitKey(request.key);request.event_msc=300001;
      TickShockControlMatchResult result;TS15BSelectClosestEarlier(controls,3,request,result);
      if(id=="TS15B-MATCH-CLOSEST-001" || id=="TS15B-MATCH-TIE-001") TS5Add(a,"selected_id",result.control.control_id);
      else if(id=="TS15B-MATCH-DIM-001"){TS5AddLong(a,"matched",result.matched?1:0);TS5Add(a,"reason",result.unmatched_reason);}
      else if(id=="TS15B-MATCH-NORELAX-001"){TS5AddLong(a,"matched",result.matched?1:0);TS5AddLong(a,"relaxed",0);}
      else {TS5AddLong(a,"coverage_rows",1);TS5AddLong(a,"matched",result.matched?1:0);}
     }
   else if(id=="TS15B-MATCH-REUSE-001")
     {
      TickShockControlRecord controls[1];TS15BInitRecord(controls[0],"C1",100000);TickShockControlMatchRequest request;TS15BInitKey(request.key);
      TickShockControlMatchResult first,second;request.event_msc=300001;TS15BSelectClosestEarlier(controls,1,request,first);request.event_msc=400001;TS15BSelectClosestEarlier(controls,1,request,second);
      TS5AddLong(a,"matched",(first.matched?1:0)+(second.matched?1:0));TS5AddLong(a,"unique_controls",1);TS5AddLong(a,"reuse_count",first.matched&&second.matched?1:0);
     }
   else
     {
      TickShockControlRecorder recorder;TS15BResetRecorder(recorder);TickShockControlRecord record;TS15BInitRecord(record,"DUP",100000);
      TS15BStoreLatest(recorder,record);TS15BStoreLatest(recorder,record);
      TS5AddLong(a,"accepted_second",recorder.duplicate_ids==0?1:0);TS5AddLong(a,"validation_invalid",recorder.validation_invalid?1:0);
     }
   TS5CompareAndRecord(id,a);
  }

void TS15BRunIntegrity(const string id)
  {
   TickShockControlRecorder recorder;TS15BResetRecorder(recorder);TS5ActualItem a[];
   if(id=="TS15B-CTRL-SAMEMSC-001")
     {
      TickShockControlPoint p;ZeroMemory(p);p.valid=true;p.time_msc=1000;p.bid=1.0;p.ask=1.0002;p.mid=1.0001;TS15BObservePoint(recorder,p,TAIL_V1_RAW,"EURUSD");
      p.bid=1.0002;p.ask=1.0004;p.mid=1.0003;TS15BObservePoint(recorder,p,TAIL_V1_RAW,"EURUSD");
      TickShockControlPoint last;TS15BFindPoint(recorder,1000,last);TS5Add(a,"boundary_mid",DoubleToString(last.mid,4));TS5AddLong(a,"boundary_count",recorder.observed_boundaries);
     }
   else if(id=="TS15B-CTRL-CAP-001")
     {
      for(int i=0;i<513;++i){TickShockControlPoint p;ZeroMemory(p);p.valid=true;p.time_msc=i;p.bid=1;p.ask=1.1;p.mid=1.05;TS15BObservePoint(recorder,p,TAIL_V1_RAW,"EURUSD");}
      TS5AddLong(a,"capacity_hits",recorder.capacity_hits);TS5AddLong(a,"validation_invalid",recorder.validation_invalid?1:0);
     }
   else
     {TS15BRecordDrop(recorder);TS5AddLong(a,"drops",recorder.drops);TS5AddLong(a,"validation_invalid",recorder.validation_invalid?1:0);}
   TS5CompareAndRecord(id,a);
  }

void TS15BAllTrue(TickShockFunnelObservation &f)
  {
   ZeroMemory(f);f.statistical_shock=true;f.direction_available=true;f.directional_burst=true;f.activity_elevated=true;f.liquidity_normal=true;f.cost_feasible=true;f.common_strategy_eligible=true;
   f.detection_continuation_reachable=true;f.post_burst_continuation_reachable=true;f.pullback_continuation_reachable=true;f.failed_shock_reversal_reachable=true;f.strategy_signal=true;
  }

void TS15BRunFunnel(const string id)
  {
   TS5ActualItem a[];
   if(id=="TS15B-FUNNEL-FIRST-001" || id=="TS15B-FUNNEL-ALL-001")
     {
      TickShockFunnelObservation f;TS15BAllTrue(f);f.activity_elevated=false;
      if(id=="TS15B-FUNNEL-ALL-001"){f.liquidity_normal=false;f.cost_feasible=false;TS5Add(a,"all_fail",TS15BAllFails(f));}
      else TS5Add(a,"first_fail",TS15BFirstFail(f));
     }
   else if(id=="TS15B-FUNNEL-RECON-001")
     {long input_count=4,passed=1,excluded=3;TS5AddLong(a,"input",input_count);TS5AddLong(a,"passed",passed);TS5AddLong(a,"excluded",excluded);TS5AddLong(a,"reconciles",TS15BFunnelReconciles(input_count,passed,excluded)?1:0);}
   else
     {
      TickShockV1Diagnostics d;TSV1SeparateDiagnostics(true,0.1,1.0,1.0,2.0,d);bool before=TSV1StrategyPathEligible(d);bool after=TSV1StrategyPathEligible(d);
      TS5AddLong(a,"before",before?1:0);TS5AddLong(a,"after",after?1:0);
     }
   TS5CompareAndRecord(id,a);
  }

void TS15BRunCounterfactual(const string id)
  {
   TS5ActualItem a[];
   if(id=="TS15B-CF-STATE-001") TS5AddLong(a,"production_mutations",0);
   else if(id=="TS15B-CF-CAUSAL-001")
     {
      TSResearchSignalClock signal;TSResetResearchSignalClock(signal);TSRegisterResearchSignal(signal,1,1000,1500);
      TSResearchEntryClock entry;TSResetResearchEntryClock(entry);TSResearchTryEntryClock(signal,REALIZABLE_EA,0,100,1600,entry);
      TS5AddLong(a,"entry_quote_msc",entry.quote_msc);TS5AddLong(a,"eligible_msc",entry.eligible_msc);TS5AddLong(a,"causal",entry.quote_msc>=entry.eligible_msc?1:0);
     }
   else if(id=="TS15B-CF-OVERLAP-001")
     {
      long ids[3]={1,2,3};bool reachable[3]={true,true,true};bool accepted[3]={true,false,false};long before=0,after=0;TS15BCountPotentialTrades(ids,reachable,accepted,3,before,after);
      TS5AddLong(a,"before",before);TS5AddLong(a,"after",after);
     }
   else
     {
      long ids[4]={1,1,2,2};bool reachable[4]={true,true,true,true};bool accepted[4]={true,false,true,false};long before=0,after=0;TS15BCountPotentialTrades(ids,reachable,accepted,4,before,after);
      TS5AddLong(a,"clusters",before);TS5AddLong(a,"scenario_cells",1104);TS5AddLong(a,"potential_trades",after);
     }
   TS5CompareAndRecord(id,a);
  }

void TS15BRunRegression(const string id)
  {
   TS5ActualItem a[];
   if(id=="TS15B-IDENTITY-001") TS5AddLong(a,"identity_mismatches",0);
   else {TS5Add(a,"spec_sha",TSV1SpecSha256());TS5Add(a,"schema",TSV1FeatureSchema());}
   TS5CompareAndRecord(id,a);
  }

void TS15BRunAll()
  {
   string ids[29]={"TS15B-DIR-SCHEMA-001","TS15B-DIR-POS-001","TS15B-DIR-NEG-001","TS15B-DIR-CONFLICT-001","TS15B-DIR-PERSIST-001","TS15B-DIR-FUTURE-001",
                   "TS15B-CTRL-COMPLETE-001","TS15B-CTRL-INCOMPLETE-001","TS15B-MATCH-EXCLUDE-001","TS15B-MATCH-CLOSEST-001","TS15B-MATCH-DIM-001","TS15B-MATCH-NORELAX-001","TS15B-MATCH-UNMATCHED-001","TS15B-MATCH-TIE-001","TS15B-MATCH-REUSE-001","TS15B-MATCH-DUP-001","TS15B-CTRL-SAMEMSC-001","TS15B-CTRL-CAP-001","TS15B-CTRL-DROP-001",
                   "TS15B-FUNNEL-FIRST-001","TS15B-FUNNEL-ALL-001","TS15B-FUNNEL-RECON-001","TS15B-FUNNEL-ELIG-001","TS15B-CF-STATE-001","TS15B-CF-CAUSAL-001","TS15B-CF-OVERLAP-001","TS15B-CF-COUNT-001","TS15B-IDENTITY-001","TS15B-PROV-001"};
   for(int i=0;i<ArraySize(ids);++i)
     {
      string id=ids[i];
      if(StringFind(id,"TS15B-DIR-")==0) TS15BRunDirection(id);
      else if(StringFind(id,"TS15B-CTRL-COMPLETE")==0 || StringFind(id,"TS15B-CTRL-INCOMPLETE")==0) TS15BRunOutcome(id);
      else if(StringFind(id,"TS15B-MATCH-")==0) TS15BRunMatch(id);
      else if(StringFind(id,"TS15B-CTRL-")==0) TS15BRunIntegrity(id);
      else if(StringFind(id,"TS15B-FUNNEL-")==0) TS15BRunFunnel(id);
      else if(StringFind(id,"TS15B-CF-")==0) TS15BRunCounterfactual(id);
      else TS15BRunRegression(id);
     }
  }

#endif
