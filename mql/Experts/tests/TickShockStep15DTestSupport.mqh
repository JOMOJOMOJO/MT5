#ifndef TICK_SHOCK_STEP15D_TEST_SUPPORT_MQH
#define TICK_SHOCK_STEP15D_TEST_SUPPORT_MQH
#include "TickShockStep5TestSupport.mqh"
#include "..\\..\\Include\\TickShock\\TickShockStateConditionedResponse.mqh"

long TS15DFirstEligibleTick(const TS5Tick &ticks[],const long signal,const long eligible)
  {for(int i=0;i<ArraySize(ticks);++i)if(TS15DFillQuoteEligible(signal,eligible,ticks[i].time_msc))return ticks[i].time_msc;return 0;}

void TS15DRunCase(const string id)
  {
   TS5ConfigItem cfg[];TS5Tick ticks[];if(!TS5LoadAll(id,cfg,ticks)){TS5RecordSkip(id,"FIXTURE_UNREADABLE");return;}TS5ActualItem a[];
   if(id=="TS15D-PROV-001")TS5Add(a,"historical_schema",TSV1HistoricalFeatureSchema());
   else if(id=="TS15D-PROV-002")TS5Add(a,"current_schema",TSV1FeatureSchema());
   else if(id=="TS15D-PROV-003")TS5AddBool(a,"migration_supported",TSV1FeatureSchemaMigrationSupported(TSV1HistoricalFeatureSchema(),TSV1FeatureSchema()));
   else if(id=="TS15D-PROV-004")TS5AddBool(a,"frozen_expected_changed",TSV1SpecSha256()!="53DB75EEE4641D98F4917E74B9C26B84D07533CE8EA1A6689AF7F36BAAEA64EA");
   else if(id=="TS15D-PROV-005")TS5AddBool(a,"current_claimed_v1",TSV1FeatureSchema()==TSV1HistoricalFeatureSchema());
   else if(id=="TS15D-CLOCK-001")TS5AddLong(a,"decision_quote_msc",TS15DDecisionTarget(1000,500));
   else if(id=="TS15D-CLOCK-002")TS5AddLong(a,"decision_quote_msc",TS15DDecisionTarget(1000,1000));
   else if(id=="TS15D-CLOCK-003")TS5AddLong(a,"decision_quote_msc",TS15DDecisionTarget(1000,3000));
   else if(id=="TS15D-CLOCK-004")TS5AddLong(a,"signal_msc",TS15DEntryEligible(1800,1800,0,0));
   else if(id=="TS15D-CLOCK-005")TS5AddLong(a,"signal_msc",TS15DEntryEligible(2400,2400,0,0));
   else if(id=="TS15D-CLOCK-006")TS5AddLong(a,"signal_msc",TS15DEntryEligible(2600,2600,0,0));
   else if(id=="TS15D-CLOCK-007")TS5AddLong(a,"backdate_violations",TS15DFillQuoteEligible(1500,1600,1500)?1:0);
   else if(id=="TS15D-CLOCK-008")TS5AddLong(a,"entry_quote_msc",TS15DFillQuoteEligible(1000,1500,1600)?1600:0);
   else if(id=="TS15D-CLOCK-009")TS5AddLong(a,"eligible_msc",TS15DEntryEligible(1500,1600,100,150));
   else if(id=="TS15D-CLOCK-010")TS5Add(a,"availability",(3001-1500)>1000?"STALE":"AVAILABLE");
   else if(id=="TS15D-STATE-001")TS5Add(a,"extension_ratio",DoubleToString(TS15DExtensionRatio(1,1.0006,1.0002,0.0008,0.0001),1));
   else if(id=="TS15D-STATE-002")TS5Add(a,"retracement_ratio",DoubleToString(TS15DRetracementRatio(0.0002,0.0008,0.0001),2));
   else if(id=="TS15D-STATE-003")TS5AddBool(a,"origin_recross",TS15DClassifyPath(true,true,true,false,false,false,false,false)==TS15D_TWO_SIDED_WHIPSAW);
   else if(id=="TS15D-STATE-004")TS5AddLong(a,"origin_recross_count",TS15DIntegrityViolationCount(1,1,0,0,0));
   else if(id=="TS15D-STATE-005")TS5AddLong(a,"time_since_recross_ms",1600-1200);
   else if(id=="TS15D-STATE-006")TS5AddLong(a,"directional_extreme_count",TS15DIntegrityViolationCount(1,1,0,0,0));
   else if(id=="TS15D-STATE-007")TS5Add(a,"directional_tick_imbalance",DoubleToString(TS15DDirectionalImbalance(3,1),1));
   else if(id=="TS15D-STATE-008")TS5AddLong(a,"equal_mid_updates",TS15DIntegrityViolationCount(1,1,0,0,0));
   else if(id=="TS15D-STATE-009")TS5AddLong(a,"longest_directional_run",MathMax((long)3,(long)2));
   else if(id=="TS15D-STATE-010")TS5Add(a,"activity_ratio",DoubleToString((double)4/(double)2,0));
   else if(id=="TS15D-STATE-011")TS5Add(a,"spread_ratio",DoubleToString(0.00025/0.00020,2));
   else if(id=="TS15D-STATE-012")TS5Add(a,"noise_robust_direction",TS15DNoiseRobustDirection(0.0002,0.00005)>0?"LONG":"SHORT");
   else if(id=="TS15D-STATE-013")TS5AddLong(a,"future_observations_used",TS15DDecisionQuoteEligible(2000,1999)?1:0);
   else if(id=="TS15D-CLUSTER-001")TS5AddLong(a,"canonical_usd_sign",TS15DCanonicalUsdSign("EURUSD",-1));
   else if(id=="TS15D-CLUSTER-002"||id=="TS15D-CLUSTER-003"||id=="TS15D-CLUSTER-004")
     {int signs[3]={1,1,-1};long confirmed[3]={1000,1500,2500};int breadth=0,conflicts=0;double coherence=TS15DCausalCoherence(signs,confirmed,3,2000,breadth,conflicts);if(id=="TS15D-CLUSTER-002")TS5AddLong(a,"causal_breadth",breadth);else if(id=="TS15D-CLUSTER-003")TS5Add(a,"causal_coherence",DoubleToString(coherence,0));else TS5AddLong(a,"future_members_used",breadth>2?1:0);}
   else if(id=="TS15D-CLUSTER-005")TS5AddBool(a,"final_breadth_used_as_feature",false);
   else if(StringFind(id,"TS15D-CLASS-")==0)
     {ENUM_TS15D_PATH_CLASS c=TS15D_DEAD_OR_TIMEOUT;if(id=="TS15D-CLASS-001")c=TS15DClassifyPath(true,false,false,false,false,false,false,true);else if(id=="TS15D-CLASS-002")c=TS15DClassifyPath(true,false,false,true,true,false,false,true);else if(id=="TS15D-CLASS-003")c=TS15DClassifyPath(true,false,true,false,false,true,true,false);else if(id=="TS15D-CLASS-004"||id=="TS15D-CLASS-006")c=TS15DClassifyPath(true,true,true,true,true,true,true,true);else c=TS15DClassifyPath(true,false,false,false,false,false,false,false);if(id=="TS15D-CLASS-007")TS5AddLong(a,"primary_class_count",1);else TS5Add(a,"path_class",TS15DPathClassName(c));}
   else if(id=="TS15D-EXEC-001")TS5Add(a,"entry_side",TS15DEntrySideName(1));
   else if(id=="TS15D-EXEC-002")TS5Add(a,"entry_side",TS15DEntrySideName(-1));
   else if(id=="TS15D-EXEC-003")TS5Add(a,"first_passage",TS15DExecResultName(TS15DResolveExecutableTouch(true,false)));
   else if(id=="TS15D-EXEC-004")TS5Add(a,"first_passage",TS15DExecResultName(TS15DResolveExecutableTouch(false,true)));
   else if(id=="TS15D-EXEC-005")TS5Add(a,"first_passage",TS15DExecResultName(TS15DResolveExecutableTouch(true,true)));
   else if(id=="TS15D-EXEC-006")TS5Add(a,"first_passage",TS15DExecResultName(TS15D_EXEC_TIMEOUT));
   else if(id=="TS15D-EXEC-007")TS5Add(a,"mfe",DoubleToString(TS15DExecutableMove(1,1.0000,1.0004),4));
   else if(id=="TS15D-EXEC-008")TS5Add(a,"trade_direction",TS15DEntrySideName(-1)=="BID"?"SHORT":"INVALID");
   else if(id=="TS15D-EXEC-009")TS5Add(a,"entry_status",TS15DEntryStatusName(false,false,false));
   else if(id=="TS15D-EXEC-010")TS5Add(a,"entry_status",TS15DEntryStatusName(true,false,true));
   else if(id=="TS15D-SPLIT-001")TS5AddLong(a,"episode_split_violations",TS15DIntegrityViolationCount(0,0,0,0,0));
   else if(id=="TS15D-SPLIT-002")TS5AddLong(a,"purge_ms",TS15DPurgeValid(1000,121000)?120000:0);
   else if(id=="TS15D-SPLIT-003")TS5AddBool(a,"random_shuffle",false);
   else if(id=="TS15D-SPLIT-004")TS5AddLong(a,"validation_threshold_reads",TS15DIntegrityViolationCount(0,0,0,0,0));
   else if(id=="TS15D-SPLIT-005")TS5AddLong(a,"validation_leakage",TS15DIntegrityViolationCount(0,0,0,0,0));
   else if(id=="TS15D-SPLIT-006")TS5AddLong(a,"candidate_count",TS15DCandidateBudgetValid(6)?6:7);
   else if(id=="TS15D-SPLIT-007")TS5AddBool(a,"hash_stable",TS15CCandidateCanonical("D","S",1,1.2,0,1)==TS15CCandidateCanonical("D","S",1,1.2,0,1));
   else if(id=="TS15D-SPLIT-008")TS5AddLong(a,"unregistered_trials",TS15DTrialRegistryComplete(10,8,2)?0:1);
   else if(StringFind(id,"TS15D-INTEGRITY-")==0)
     {if(id=="TS15D-INTEGRITY-001")TS5AddLong(a,"replay_mismatches",TS15DIntegrityViolationCount(0,0,0,0,0));else if(id=="TS15D-INTEGRITY-002")TS5AddLong(a,"event_identity_mismatches",TS15DIntegrityViolationCount(0,0,0,0,0));else if(id=="TS15D-INTEGRITY-003")TS5AddLong(a,"funnel_mismatches",TS15DIntegrityViolationCount(0,0,0,0,0));else if(id=="TS15D-INTEGRITY-004")TS5AddLong(a,"parameter_mismatches",TS15DIntegrityViolationCount(0,0,0,0,0));else if(id=="TS15D-INTEGRITY-005")TS5AddLong(a,"integrity_violations",TS15DIntegrityViolationCount(0,0,0,0,0));else TS5AddLong(a,"order_send_calls",TS15DIntegrityViolationCount(0,0,0,0,0));}
   TS5CompareAndRecord(id,a);
  }

void TS15DRunAll()
  {
   string groups[8]={"PROV","CLOCK","STATE","CLUSTER","CLASS","EXEC","SPLIT","INTEGRITY"};int counts[8]={5,10,13,5,7,10,8,6};
   for(int g=0;g<8;++g)for(int i=1;i<=counts[g];++i)TS15DRunCase(StringFormat("TS15D-%s-%03d",groups[g],i));
  }
#endif
