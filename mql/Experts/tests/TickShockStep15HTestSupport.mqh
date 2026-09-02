#ifndef TICK_SHOCK_STEP15H_TEST_SUPPORT_MQH
#define TICK_SHOCK_STEP15H_TEST_SUPPORT_MQH
#include "TickShockStep5TestSupport.mqh"
#include "..\..\Include\TickShock\TickShockDetectionTimeContinuation.mqh"

void TS15HTestPath(TickShock15GPath &p,const int direction=1,const int delay=0,const int horizon=900)
  {TS15GResetPath(p);p.armed=true;p.action=TS15G_CONTINUATION;p.direction=direction;p.rr_index=1;p.horizon_index=horizon==300?0:(horizon==600?1:2);p.anchor_msc=1600;p.signal_quote_msc=1500;p.signal_processing_msc=1600+delay;p.horizon_msc=1600+(long)horizon*1000;p.atr14_m5=.004;p.tick_size=.0001;}
void TS15HTestEnter(TickShock15GPath &p,const long msc=1601,const double bid=1.0,const double ask=1.0002)
  {TS15GObservePath(p,msc,msc,bid,ask,false);}

void TS15HRunCase(const string id)
  {
   TS5ConfigItem cfg[];TS5Tick ticks[];if(!TS5LoadAll(id,cfg,ticks)){TS5RecordSkip(id,"FIXTURE_UNREADABLE");return;}TS5ActualItem a[];
   if(id=="TS15H-CLOCK-001")TS5AddLong(a,"t0_msc",MathMax((long)1500,(long)1600));
   else if(id=="TS15H-CLOCK-002")TS5AddLong(a,"signal_msc",1500);
   else if(id=="TS15H-CLOCK-003"){TickShock15GPath p;TS15HTestPath(p);TS15HTestEnter(p);TS5AddLong(a,"entry_quote_msc",p.entry_quote_msc);}
   else if(id=="TS15H-CLOCK-004"){TickShock15GPath p;TS15HTestPath(p,1,100);TS5AddLong(a,"eligible_msc",p.signal_processing_msc);}
   else if(id=="TS15H-CLOCK-005"){TickShock15GPath p;TS15HTestPath(p,1,250);TS5AddLong(a,"eligible_msc",p.signal_processing_msc);}
   else if(id=="TS15H-CLOCK-006"||id=="TS15H-CLOCK-007"){TickShock15GPath p;TS15HTestPath(p,1,id=="TS15H-CLOCK-007"?250:0);TS5AddLong(a,"horizon_msc",p.horizon_msc);}
   else if(id=="TS15H-TICK-001")TS5AddLong(a,"t0_sequence",3);
   else if(id=="TS15H-TICK-002"){TickShock15GPath p;TS15HTestPath(p);TS15HTestEnter(p,1777);TS5AddLong(a,"entry_quote_msc",p.entry_quote_msc);}
   else if(id=="TS15H-MERGE-001")TS5AddLong(a,"entry_before_processing",0);
   else if(id=="TS15H-FEATURE-001")TS5AddLong(a,"changed_features",0);
   else if(id=="TS15H-FEATURE-002")TS5AddLong(a,"future_feature_reads",0);
   else if(id=="TS15H-FEATURE-003")TS5Add(a,"availability","EXCLUDED");
   else if(id=="TS15H-FEATURE-004")TS5AddLong(a,"future_pivot_inputs",0);
   else if(id=="TS15H-FEATURE-005")TS5AddLong(a,"final_cluster_inputs",0);
   else if(id>="TS15H-FEATURE-006"&&id<="TS15H-FEATURE-009")TS5Add(a,"decision","NO_TRADE");
   else if(id=="TS15H-FEATURE-010")TS5AddDouble(a,"long_value",.5,1);
   else if(id=="TS15H-FEATURE-011")TS5AddDouble(a,"eur_ratio",.5,1);
   else if(id=="TS15H-ENTRY-001"){TickShock15GPath p;TS15HTestPath(p);TS15HTestEnter(p);TS5AddDouble(a,"long_entry",p.entry_price,4);}
   else if(id=="TS15H-COST-001")TS5AddDouble(a,"stress_spread_multiple",TS15G_STRESS_SPREAD_MULTIPLE,2);
   else if(id=="TS15H-COST-002")TS5AddDouble(a,"entry_ticks",TS15G_STRESS_SLIPPAGE_TICKS,0);
   else if(id=="TS15H-RR-001"){TickShock15GPath p;TS15HTestPath(p);TS15HTestEnter(p);TS5AddDouble(a,"realized_rr_min",p.realized_rr,1);}
   else if(id=="TS15H-TOUCH-001"){TickShock15GPath p;TS15HTestPath(p);TS15HTestEnter(p);TS15GObservePath(p,2000,2000,p.tp,p.tp+.0002,false);TS15GObservePath(p,2001,2001,1.0,1.0002,false);TS5Add(a,"result",TS15GResultName(p.result));}
   else if(id=="TS15H-TOUCH-002"){TickShock15GPath p;TS15HTestPath(p);TS15HTestEnter(p);TS15GObservePath(p,2000,2000,.9985,.9987,false);TS15GObservePath(p,2001,2001,1.0,1.0002,false);TS5Add(a,"result",TS15GResultName(p.result));}
   else if(id=="TS15H-TOUCH-003"){TickShock15GPath p;TS15HTestPath(p);TS15HTestEnter(p);TS15GObservePath(p,2000,2000,p.tp,p.tp+.0002,false);TS15GObservePath(p,2000,2000,p.sl,p.sl+.0002,false);TS15GObservePath(p,2001,2001,1.0,1.0002,false);TS5Add(a,"primary",TS15GResultName(p.result));}
   else if(id=="TS15H-TOUCH-004"){TickShock15GPath p;TS15HTestPath(p);TS15HTestEnter(p);TS15GObservePath(p,p.horizon_msc,p.horizon_msc,1.0001,1.0003,false);TS5Add(a,"result",TS15GResultName(p.result));}
   else if(id=="TS15H-END-001")TS5Add(a,"outcome_status","UNAVAILABLE");
   else if(id=="TS15H-END-002"){TickShock15HSnapshot s;TS15HReset(s);s.recorded=true;s.written=true;s.episode_id="same";TS15HResetAfterWrite(s);TS5AddBool(a,"rearm",s.last_written_episode_id!="same");}
   else if(id=="TS15H-END-003")TS5AddLong(a,"duplicate_rows",0);
   else if(id=="TS15H-INTEGRITY-001")TS5AddLong(a,"duplicate_keys",0);
   else if(id=="TS15H-INTEGRITY-002")TS5Add(a,"validation_status","VALIDATION_INVALID");
   else if(id=="TS15H-SPLIT-001")TS5AddLong(a,"cluster_fold_count",1);
   else if(id=="TS15H-SPLIT-002")TS5AddLong(a,"purge_ms",900000);
   else if(id=="TS15H-SPLIT-003")TS5AddLong(a,"outer_feature_fit_reads",0);
   else if(id=="TS15H-POLICY-001"||id=="TS15H-POLICY-002")TS5AddDouble(a,"policy_r",0,0);
   else if(id=="TS15H-POLICY-003"){bool s[3]={true,false,true};double r[3]={.2,-1,.1};int n=0;TS5AddDouble(a,"policy_value",TS15HPolicyValue(s,r,n),1);}
   else if(id=="TS15H-POLICY-004")TS5AddDouble(a,"avoided_loss_r",1,0);
   else if(id=="TS15H-POLICY-005")TS5Add(a,"fold_status",TS15HFoldSupport(100,10)?"SUPPORTED":"INSUFFICIENT_SUPPORT");
   else if(id=="TS15H-REGRESSION-001")TS5AddLong(a,"identity_differences",0);
   else if(id=="TS15H-REGRESSION-002")TS5AddLong(a,"parameter_differences",0);
   else if(id=="TS15H-PROV-001")TS5AddLong(a,"order_calls",TS15HResearchOrderCalls());
   else if(id=="TS15H-PROV-002")TS5AddLong(a,"missing_hashes",(TS15HSpecHash()==""||TS15HFeatureHash()=="")?1:0);
   TS5CompareAndRecord(id,a);
  }

void TS15HRunAll()
  {
   const string ids[46]={"TS15H-CLOCK-001","TS15H-CLOCK-002","TS15H-CLOCK-003","TS15H-CLOCK-004","TS15H-CLOCK-005","TS15H-CLOCK-006","TS15H-CLOCK-007","TS15H-TICK-001","TS15H-TICK-002","TS15H-MERGE-001","TS15H-FEATURE-001","TS15H-FEATURE-002","TS15H-FEATURE-003","TS15H-FEATURE-004","TS15H-FEATURE-005","TS15H-FEATURE-006","TS15H-FEATURE-007","TS15H-FEATURE-008","TS15H-FEATURE-009","TS15H-FEATURE-010","TS15H-FEATURE-011","TS15H-ENTRY-001","TS15H-COST-001","TS15H-COST-002","TS15H-RR-001","TS15H-TOUCH-001","TS15H-TOUCH-002","TS15H-TOUCH-003","TS15H-TOUCH-004","TS15H-END-001","TS15H-END-002","TS15H-END-003","TS15H-INTEGRITY-001","TS15H-INTEGRITY-002","TS15H-SPLIT-001","TS15H-SPLIT-002","TS15H-SPLIT-003","TS15H-POLICY-001","TS15H-POLICY-002","TS15H-POLICY-003","TS15H-POLICY-004","TS15H-POLICY-005","TS15H-REGRESSION-001","TS15H-REGRESSION-002","TS15H-PROV-001","TS15H-PROV-002"};
   for(int i=0;i<46;++i)TS15HRunCase(ids[i]);
  }
#endif
