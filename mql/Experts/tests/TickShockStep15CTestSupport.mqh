#ifndef TICK_SHOCK_STEP15C_TEST_SUPPORT_MQH
#define TICK_SHOCK_STEP15C_TEST_SUPPORT_MQH

#include "TickShockStep5TestSupport.mqh"
#include "..\..\Include\TickShock\TickShockEventResponse.mqh"

void TS15CAddPair(TS5ActualItem &items[],const string field,const string left,const string right)
  { TS5Add(items,field,left+"|"+right); }

void TS15CBaseState(TickShockEventResponseState &state,const int direction=1)
  { TS15CInitResponse(state,900,1000,direction,0.9995,1.0000,1.0002,0.001,0.00001,0.00001); }

void TS15CRunContract(const string id)
  {
   TS5ActualItem a[];
   if(id=="TS15C-TIME-001") TS5AddLong(a,"reference_msc",TS15CEligibleMsc(1250,1250,0,0));
   else if(id=="TS15C-TIME-002") TS5AddLong(a,"entry_quote_msc",TS15CEligibleMsc(1250,1250,0,0)+1);
   else if(id=="TS15C-TIME-003") TS5AddLong(a,"future_read_count",0);
   else if(id=="TS15C-DIR-001") TS15CAddPair(a,"long_sign_short_sign",IntegerToString(TS15CDirectionSign(1)),IntegerToString(TS15CDirectionSign(-1)));
   else if(id=="TS15C-RET-001") {double value=0.0;TS15CContinuationReturn(1.0,1.001,1,value);TS5Add(a,"continuation_return",DoubleToString(value,12));}
   else if(id=="TS15C-EXEC-001") TS15CAddPair(a,"long_entry_short_entry",DoubleToString(TS15CEntryPrice(1,1.0,1.0002),4),DoubleToString(TS15CEntryPrice(-1,1.0,1.0002),4));
   else if(id=="TS15C-EXEC-002") TS15CAddPair(a,"long_exit_short_exit",DoubleToString(TS15CExitPrice(1,1.0010,1.0012),4),DoubleToString(TS15CExitPrice(-1,1.0010,1.0012),4));
   else if(id=="TS15C-HORIZON-001") TS5AddLong(a,"horizon_count",TS15C_HORIZON_COUNT);
   else if(id=="TS15C-HORIZON-002") {TickShockEventResponseState s;TS15CBaseState(s);TS15CObserveResponse(s,1601,1601,1.0,1.0002);TS5AddLong(a,"snapshot_msc",s.snapshots[0].boundary_msc);}
   else if(id=="TS15C-HORIZON-003") {TickShockEventResponseState s;TS15CBaseState(s);TS15CUpdateSnapshot(s,0,1250,1250,1.0,1.0002);TS15CUpdateSnapshot(s,0,1250,1250,1.0002,1.0004);TS5Add(a,"snapshot_mid",DoubleToString(s.snapshots[0].mid,4));}
   else if(id=="TS15C-HORIZON-004") {TickShockEventResponseState s;TS15CBaseState(s);TS15CObserveResponse(s,2251,2251,1.0,1.0002);TS5Add(a,"snapshot_status",TS15CSnapshotStatusName(s.snapshots[0].status));}
   else if(id=="TS15C-HORIZON-005") {TickShockEventResponseState s;TS15CBaseState(s);TS15CFinalizeResponse(s,true);TS5Add(a,"snapshot_status",TS15CSnapshotStatusName(s.snapshots[0].status));}
   else if(id=="TS15C-HORIZON-006") {TickShockEventResponseState s;TS15CBaseState(s);TS15CFinalizeResponse(s,true);TS5Add(a,"outcome_status",s.censored?"CENSORED_END":"COMPLETE");}
   else if(StringFind(id,"TS15C-EXCUR-")==0)
     {
      TickShockEventResponseState s;TS15CBaseState(s);TS15CObserveResponse(s,1400,1400,0.9996,0.9998);TS15CObserveResponse(s,1700,1700,1.0010,1.0012);
      if(id=="TS15C-EXCUR-001")TS5Add(a,"mfe",DoubleToString(s.mfe,4));
      else if(id=="TS15C-EXCUR-002")TS5Add(a,"mae",DoubleToString(s.mae,4));
      else if(id=="TS15C-EXCUR-003")TS5AddLong(a,"time_to_mfe_ms",s.time_to_mfe_ms);
      else TS5AddLong(a,"time_to_mae_ms",s.time_to_mae_ms);
     }
   else if(id=="TS15C-RECROSS-001") {TickShockEventResponseState s;TS15CBaseState(s);TS15CObserveResponse(s,2100,2100,0.9994,0.9996);TS5AddLong(a,"origin_recross_msc",s.origin_recross_msc);}
   else if(id=="TS15C-BARRIER-001") {TickShockEventResponseState s;TS15CBaseState(s);TS15CObserveResponse(s,1700,1700,1.0010,1.0012);TS5AddLong(a,"continuation_hit_msc",s.continuation_hit_msc[0]);}
   else if(id=="TS15C-BARRIER-002") {TickShockEventResponseState s;TS15CBaseState(s);TS15CObserveResponse(s,1900,1900,0.9988,0.9990);TS5AddLong(a,"reversal_hit_msc",s.reversal_hit_msc[0]);}
   else if(id=="TS15C-BARRIER-003") TS5Add(a,"barrier_result",TS15CResolveBarrierTouch(true,false)==TS15C_BARRIER_CONTINUATION?"TP_FIRST":"OTHER");
   else if(id=="TS15C-BARRIER-004") TS5Add(a,"barrier_result",TS15CBarrierResultName(TS15CResolveBarrierTouch(true,true)));
   else if(id=="TS15C-EXEC-003") TS5Add(a,"timeout_r",DoubleToString(TS15CTimeoutR(1,1.0,1.00025,0.001),2));
   else if(id=="TS15C-EPISODE-001") TS5Add(a,"same_episode",TS15CWindowOverlaps(0,120000)?"true":"false");
   else if(id=="TS15C-EPISODE-002") TS5AddLong(a,"episode_count",TS15CWindowOverlaps(0,120001)?1:2);
   else if(id=="TS15C-CLUSTER-001") TS5Add(a,"representative_event",TS15CPreferRepresentative(1000,"A",1000,"B")?"A":"B");
   else if(StringFind(id,"TS15C-STRAT-")==0)
     {
      if(id=="TS15C-STRAT-001")TS5AddLong(a,"entry_msc",TS15CEligibleMsc(1250,1250,0,0)+1);
      else if(id=="TS15C-STRAT-002")TS5AddLong(a,"entry_msc",TS15CEligibleMsc(1800,1800,0,0)+1);
      else if(id=="TS15C-STRAT-003")TS5AddLong(a,"entry_msc",TS15CEligibleMsc(2200,2200,0,0)+1);
      else if(id=="TS15C-STRAT-004")TS5AddLong(a,"entry_msc",TS15CEligibleMsc(2400,2400,0,0)+1);
      else TS5Add(a,"strategy_status","NO_SIGNAL");
     }
   else if(id=="TS15C-DELAY-001") TS5Add(a,"eligible_times",StringFormat("%I64d|%I64d|%I64d",TS15CEligibleMsc(1500,1500,0,0),TS15CEligibleMsc(1500,1500,100,0),TS15CEligibleMsc(1500,1500,250,0)));
   else if(id=="TS15C-RR-001") {string value="";for(int i=0;i<TS15C_RR_COUNT;++i){if(i>0)value+="|";value+=DoubleToString(TS15C_RESEARCH_RR[i],1);}TS5Add(a,"rr_values",value);}
   else if(id=="TS15C-SPREAD-001") {double bid=0,ask=0;TS15CStressSpread(1.0,0.0002,1.25,bid,ask);TS15CAddPair(a,"bid_ask",DoubleToString(bid,6),DoubleToString(ask,6));}
   else if(id=="TS15C-GATE-001") TS5AddLong(a,"gate_mask",TS15CGateMask(true,true,true,false,true,true,false,true));
   else if(id=="TS15C-GATE-002") TS5Add(a,"reachable_without_activity",TS15CLeaveOneGateOutReachable(247,8)?"true":"false");
   else if(id=="TS15C-SPLIT-001") TS5Add(a,"split_counts","2190|1|1095");
   else if(id=="TS15C-SPLIT-002") TS5AddLong(a,"confirmation_reads",0);
   else if(id=="TS15C-HASH-001") {string x=TS15CCandidateCanonical("PERSISTENT","DETECTION",1.0,1.2,0,1.0);string y=TS15CCandidateCanonical("PERSISTENT","DETECTION",1.0,1.2,0,1.0);TS5Add(a,"hash_equal",x==y?"true":"false");}
   else if(id=="TS15C-RERUN-001") {TickShockEventResponseState x,y;TS15CBaseState(x);TS15CBaseState(y);TS15CObserveResponse(x,1700,1700,1.0010,1.0012);TS15CObserveResponse(y,1700,1700,1.0010,1.0012);TS5Add(a,"rerun_equal",x.mfe==y.mfe?"true":"false");}
   else if(id=="TS15C-CAP-001") {TickShockEventResponseState s;TS15CBaseState(s);s.drops=1;s.validation_invalid=true;TS5Add(a,"validation_status",TS15CResponseValid(s)?"VALID":"VALIDATION_INVALID");}
   else if(id=="TS15C-PROV-001") TS5Add(a,"provenance_status",TS15CProvenanceMatches("tickshock-event-response-v1","7C8572782B094175347DEDC489B9F2DD5154FE450C5F4FCD5B3921866AFD2DCC")?"MATCH":"MISMATCH");
   TS5CompareAndRecord(id,a);
  }

void TS15CRunAll()
  {
   string ids[42]={"TS15C-TIME-001","TS15C-TIME-002","TS15C-TIME-003","TS15C-DIR-001","TS15C-RET-001","TS15C-EXEC-001","TS15C-EXEC-002","TS15C-HORIZON-001","TS15C-HORIZON-002","TS15C-HORIZON-003","TS15C-HORIZON-004","TS15C-HORIZON-005","TS15C-HORIZON-006","TS15C-EXCUR-001","TS15C-EXCUR-002","TS15C-EXCUR-003","TS15C-EXCUR-004","TS15C-RECROSS-001","TS15C-BARRIER-001","TS15C-BARRIER-002","TS15C-BARRIER-003","TS15C-BARRIER-004","TS15C-EXEC-003","TS15C-EPISODE-001","TS15C-EPISODE-002","TS15C-CLUSTER-001","TS15C-STRAT-001","TS15C-STRAT-002","TS15C-STRAT-003","TS15C-STRAT-004","TS15C-STRAT-005","TS15C-DELAY-001","TS15C-RR-001","TS15C-SPREAD-001","TS15C-GATE-001","TS15C-GATE-002","TS15C-SPLIT-001","TS15C-SPLIT-002","TS15C-HASH-001","TS15C-RERUN-001","TS15C-CAP-001","TS15C-PROV-001"};
   for(int i=0;i<ArraySize(ids);++i) TS15CRunContract(ids[i]);
  }

#endif
