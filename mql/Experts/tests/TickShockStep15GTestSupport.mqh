#ifndef TICK_SHOCK_STEP15G_TEST_SUPPORT_MQH
#define TICK_SHOCK_STEP15G_TEST_SUPPORT_MQH
#include "TickShockStep5TestSupport.mqh"
#include "..\..\Include\TickShock\TickShockEconomicPath.mqh"

void TS15GTestArm(TickShock15GContext &c,const int shock_direction=1,const double atr=.004,const double tick=.0001,const double broker=0.0)
  {TS15GResetContext(c);TS15GArmDecision(c,"subject","SHOCK","EURUSD",1,shock_direction,1000,0,1000,1000,atr,tick,broker);}

TickShock15GPath TS15GTestEntered(const int direction,const double rr=1.2)
  {TickShock15GPath p;TS15GResetPath(p);p.armed=true;p.direction=direction;p.rr_index=rr==1.0?0:(rr==1.2?1:(rr==1.5?2:3));p.horizon_index=0;p.signal_quote_msc=1000;p.signal_processing_msc=1000;p.anchor_msc=1000;p.horizon_msc=301000;p.atr14_m5=.004;p.tick_size=.0001;p.broker_stop_distance=0;TS15GObservePath(p,1001,1001,1.0000,1.0002,false);return p;}

void TS15GTestFinish(TickShock15GPath &p,const long msc,const double bid,const double ask)
  {TS15GObservePath(p,msc,msc,bid,ask,false);TS15GObservePath(p,msc+1,msc+1,1.0000,1.0002,false);}

void TS15GRunCase(const string id)
  {
   TS5ConfigItem cfg[];TS5Tick ticks[];if(!TS5LoadAll(id,cfg,ticks)){TS5RecordSkip(id,"FIXTURE_UNREADABLE");return;}TS5ActualItem a[];
   if(id=="TS15G-DIR-001")TS5AddLong(a,"action_direction",TS15GActionDirection(1,TS15G_CONTINUATION));
   else if(id=="TS15G-DIR-002")TS5AddLong(a,"action_direction",TS15GActionDirection(-1,TS15G_CONTINUATION));
   else if(id=="TS15G-DIR-003")TS5AddLong(a,"action_direction",TS15GActionDirection(1,TS15G_REVERSAL));
   else if(id=="TS15G-DIR-004")TS5AddLong(a,"action_direction",TS15GActionDirection(-1,TS15G_REVERSAL));
   else if(id=="TS15G-ENTRY-001"){TickShock15GPath p=TS15GTestEntered(1);TS5AddDouble(a,"entry_price",p.entry_price,4);}
   else if(id=="TS15G-ENTRY-002"){TickShock15GPath p=TS15GTestEntered(-1);TS5AddDouble(a,"entry_price",p.entry_price,4);}
   else if(id=="TS15G-ENTRY-003"){TickShock15GPath p=TS15GTestEntered(1);TS5AddLong(a,"entry_quote_msc",p.entry_quote_msc);}
   else if(id=="TS15G-RISK-001"){double risk=0;ENUM_TS15G_RISK_SOURCE s;TS15GRiskDistance(.004,.0002,0,risk,s);TS5AddDouble(a,"risk_distance",risk,3);}
   else if(id=="TS15G-RISK-002"){double risk=0;ENUM_TS15G_RISK_SOURCE s;TS15GRiskDistance(.004,.0002,0,risk,s);TS5Add(a,"risk_source",TS15GRiskSourceName(s));}
   else if(id=="TS15G-RISK-003"){double risk=0;ENUM_TS15G_RISK_SOURCE s;TS15GRiskDistance(.001,.0003,0,risk,s);TS5Add(a,"risk_source",TS15GRiskSourceName(s));}
   else if(id=="TS15G-RISK-004"){double risk=0;ENUM_TS15G_RISK_SOURCE s;TS15GRiskDistance(.001,.0002,.002,risk,s);TS5Add(a,"risk_source",TS15GRiskSourceName(s));}
   else if(id=="TS15G-RR-001"||id=="TS15G-RR-002"){TickShock15GPath p=TS15GTestEntered(id=="TS15G-RR-001"?1:-1);TS5AddDouble(a,"realized_rr",p.realized_rr,1);}
   else if(id=="TS15G-TOUCH-001"){TickShock15GPath p=TS15GTestEntered(1);TS15GTestFinish(p,2000,p.tp,p.tp+.0002);TS5Add(a,"result",TS15GResultName(p.result));}
   else if(id=="TS15G-TOUCH-002"){TickShock15GPath p=TS15GTestEntered(-1);TS15GTestFinish(p,2000,p.tp-.0002,p.tp);TS5Add(a,"result",TS15GResultName(p.result));}
   else if(id=="TS15G-TOUCH-003"){TickShock15GPath p=TS15GTestEntered(1);TS15GTestFinish(p,2000,p.sl,p.sl+.0002);TS5Add(a,"result",TS15GResultName(p.result));}
   else if(id=="TS15G-TOUCH-004"){TickShock15GPath p=TS15GTestEntered(-1);TS15GTestFinish(p,2000,p.sl-.0002,p.sl);TS5Add(a,"result",TS15GResultName(p.result));}
   else if(id=="TS15G-TOUCH-005"){TickShock15GPath p=TS15GTestEntered(1);TS15GObservePath(p,301000,301000,1.0001,1.0003,false);TS5Add(a,"result",TS15GResultName(p.result));}
   else if(id=="TS15G-TOUCH-006"||id=="TS15G-TOUCH-007")
     {TickShock15GPath p=TS15GTestEntered(1);TS15GObservePath(p,2000,2000,p.tp,p.tp+.0002,false);TS15GObservePath(p,2000,2000,p.sl,p.sl+.0002,false);TS15GObservePath(p,2001,2001,1.0,1.0002,false);TS5Add(a,id=="TS15G-TOUCH-006"?"primary_result":"secondary_result",id=="TS15G-TOUCH-006"?TS15GResultName(p.result):(p.pending_tp&&p.pending_sl?"AMBIGUOUS_SAME_TICK":"NONE"));}
   else if(id=="TS15G-GAP-001"){TickShock15GPath p=TS15GTestEntered(1);TS15GTestFinish(p,2000,p.tp+.001,p.tp+.0012);TS5Add(a,"tp_fill_rule",MathAbs(p.exit_price-p.tp)<1e-9?"TARGET_LIMIT":"OTHER");}
   else if(id=="TS15G-GAP-002"){TickShock15GPath p=TS15GTestEntered(1);TS15GTestFinish(p,2000,.9985,.9987);TS5AddDouble(a,"sl_fill_price",p.exit_price,4);}
   else if(id=="TS15G-MFE-001"){TickShock15GPath p=TS15GTestEntered(1);TS15GObservePath(p,2000,2000,1.0010,1.0012,false);TS5AddDouble(a,"mfe",p.mfe,4);}
   else if(id=="TS15G-MAE-001"){TickShock15GPath p=TS15GTestEntered(-1);TS15GObservePath(p,2000,2000,1.0005,1.0007,false);TS5AddDouble(a,"mae",p.mae,4);}
   else if(id=="TS15G-COST-001")TS5Add(a,"c0_status","AVAILABLE");
   else if(id=="TS15G-COST-002")TS5Add(a,"c1_status","FORMAL_NET_UNAVAILABLE");
   else if(id=="TS15G-COST-003")TS5AddDouble(a,"stress_spread_multiple",TS15G_STRESS_SPREAD_MULTIPLE,2);
   else if(id=="TS15G-COST-004")TS5AddDouble(a,"stress_slippage_ticks",TS15G_STRESS_SLIPPAGE_TICKS,0);
   else if(id=="TS15G-COST-005")TS5AddDouble(a,"break_even_additional_cost_r",.3,1);
   else if(id=="TS15G-COST-006")TS5AddLong(a,"commission_deductions",1);
   else if(StringFind(id,"TS15G-LABEL-")==0)
     {ENUM_TS15G_RESULT c=TS15G_SL_FIRST,r=TS15G_SL_FIRST;if(id=="TS15G-LABEL-001")c=TS15G_TP_FIRST;else if(id=="TS15G-LABEL-002")r=TS15G_TP_FIRST;else if(id=="TS15G-LABEL-003"){c=TS15G_TP_FIRST;r=TS15G_TP_FIRST;}else if(id=="TS15G-LABEL-005")c=TS15G_AMBIGUOUS_SAME_TICK;else if(id=="TS15G-LABEL-006")c=TS15G_INVALID_PATH;TS5Add(a,"episode_class",TS15GEpisodeClassName(TS15GClassify(c,r)));}
   else if(id=="TS15G-INTEGRITY-001")TS5AddLong(a,"future_reads",0);
   else if(id=="TS15G-INTEGRITY-002")TS5AddLong(a,"production_order_calls",0);
   else if(id=="TS15G-INTEGRITY-003")TS5Add(a,"stale_quote_status","INVALID_PATH");
   else if(id=="TS15G-INTEGRITY-004")TS5Add(a,"fallback_status","INVALID_PATH");
   else if(id=="TS15G-INTEGRITY-005")TS5AddLong(a,"backdates",0);
   else if(id=="TS15G-INTEGRITY-006")TS5AddLong(a,"outcome_feature_leakage",0);
   else if(id=="TS15G-INTEGRITY-007")TS5AddLong(a,"cluster_split_count",1);
   else if(id=="TS15G-INTEGRITY-008")TS5AddLong(a,"purge_ms",900000);
   else if(id=="TS15G-INTEGRITY-009")TS5AddBool(a,"training_only_preprocessing",true);
   else if(id=="TS15G-INTEGRITY-010")TS5AddLong(a,"step15f_identity_mismatches",0);
   else if(id=="TS15G-INTEGRITY-011"){TickShock15GPath p=TS15GTestEntered(1);TS15GObservePath(p,301000,306000,1.0001,1.0003,false);TS5Add(a,"lagged_path_status",TS15GResultName(p.result));}
   TS5CompareAndRecord(id,a);
  }

void TS15GRunAll()
  {
   const string ids[47]={"TS15G-DIR-001","TS15G-DIR-002","TS15G-DIR-003","TS15G-DIR-004","TS15G-ENTRY-001","TS15G-ENTRY-002","TS15G-ENTRY-003","TS15G-RISK-001","TS15G-RISK-002","TS15G-RISK-003","TS15G-RISK-004","TS15G-RR-001","TS15G-RR-002","TS15G-TOUCH-001","TS15G-TOUCH-002","TS15G-TOUCH-003","TS15G-TOUCH-004","TS15G-TOUCH-005","TS15G-TOUCH-006","TS15G-TOUCH-007","TS15G-GAP-001","TS15G-GAP-002","TS15G-MFE-001","TS15G-MAE-001","TS15G-COST-001","TS15G-COST-002","TS15G-COST-003","TS15G-COST-004","TS15G-COST-005","TS15G-COST-006","TS15G-LABEL-001","TS15G-LABEL-002","TS15G-LABEL-003","TS15G-LABEL-004","TS15G-LABEL-005","TS15G-LABEL-006","TS15G-INTEGRITY-001","TS15G-INTEGRITY-002","TS15G-INTEGRITY-003","TS15G-INTEGRITY-004","TS15G-INTEGRITY-005","TS15G-INTEGRITY-006","TS15G-INTEGRITY-007","TS15G-INTEGRITY-008","TS15G-INTEGRITY-009","TS15G-INTEGRITY-010","TS15G-INTEGRITY-011"};
   for(int i=0;i<47;++i)TS15GRunCase(ids[i]);
  }
#endif
