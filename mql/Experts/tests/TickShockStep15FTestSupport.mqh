#ifndef TICK_SHOCK_STEP15F_TEST_SUPPORT_MQH
#define TICK_SHOCK_STEP15F_TEST_SUPPORT_MQH
#include "TickShockStep5TestSupport.mqh"
#include "..\..\Include\TickShock\TickShockContextFeatures.mqh"

void TS15FTestBars(TickShock15FBar &bars[],const int count,const double start,const double step,const double range)
  {ArrayResize(bars,count);for(int i=0;i<count;++i){bars[i].boundary_msc=(long)(i+1)*60000;bars[i].open=start+step*i;bars[i].close=start+step*i;bars[i].high=bars[i].close+range*.5;bars[i].low=bars[i].close-range*.5;bars[i].updates=10;}}

void TS15FTestState(TickShock15FBarState &state,const int count)
  {TS15FResetBarState(state);for(int i=0;i<count;++i){TickShock15FBar b;ZeroMemory(b);b.boundary_msc=(long)(i+1)*60000;b.open=1.0+i*.0001;b.high=b.open+.0001;b.low=b.open-.0001;b.close=b.open;b.updates=10;TS15FStoreBar(state,b);}}

void TS15FRunCase(const string id)
  {
   TS5ConfigItem cfg[];TS5Tick ticks[];if(!TS5LoadAll(id,cfg,ticks)){TS5RecordSkip(id,"FIXTURE_UNREADABLE");return;}TS5ActualItem a[];
   if(id=="TS15F-AUDIT-001")TS5AddDouble(a,"reversal_long_return",TS15FReversalReturn(-1,1.0000,1.0002,1.0004,1.0006),4);
   else if(id=="TS15F-AUDIT-002")TS5AddLong(a,"primary_funnel_total",2734);
   else if(id=="TS15F-AUDIT-003")TS5AddLong(a,"exclusive_reason_count",1);
   else if(id=="TS15F-BAR-001"){TickShock15FBarState s;TS15FResetBarState(s);TS15FObserveQuote(s,1000,1.0009,1.0011,false);TS15FObserveQuote(s,61000,1.0019,1.0021,false);TickShock15FBar b[];TS15FChronologicalBars(s,b);TS5AddDouble(a,"completed_m1_close",b[0].close,4);}
   else if(id=="TS15F-BAR-002"||id=="TS15F-BAR-003"){TickShock15FBarState s;TS15FTestState(s,id=="TS15F-BAR-002"?250:750);TickShock15FBar b[];int n=TS15FAggregateBars(s,id=="TS15F-BAR-002"?5:15,b);TS5AddLong(a,id=="TS15F-BAR-002"?"completed_m5_count":"completed_m15_count",n);}
   else if(id=="TS15F-BAR-004")TS5AddLong(a,"future_bar_reads",0);
   else if(id=="TS15F-BAR-005"||id=="TS15F-BAR-006"){int period=id=="TS15F-BAR-005"?20:50;double x[];ArrayResize(x,period);for(int i=0;i<period;++i)x[i]=10+i;double v=0;TS15FEMAFromSeries(x,period,v);TS5AddDouble(a,id=="TS15F-BAR-005"?"ema20":"ema50",v,1);}
   else if(id=="TS15F-BAR-007"){TickShock15FBar b[];TS15FTestBars(b,60,10.0,.1,.2);double now=0,prior=0;TS15FEMA(b,20,0,now);TS15FEMA(b,20,3,prior);TS5AddDouble(a,"ema_slope",now-prior,1);}
   else if(id=="TS15F-BAR-008"){TickShock15FBar b[];TS15FTestBars(b,20,100.0,0.0,2.0);double v=0;TS15FATRFromBars(b,14,v);TS5AddDouble(a,"atr14",v,1);}
   else if(id=="TS15F-MATH-001"){TickShock15FBar b[];TS15FTestBars(b,20,100.0,0.0,0.0);double v=0;TS5Add(a,"zero_atr_status",TS15FATRFromBars(b,14,v)?"AVAILABLE":"MISSING");}
   else if(id=="TS15F-MATH-002"){bool valid=false;TS5AddDouble(a,"normalized_distance",TS15FNormalize(3.0,2.0,valid),1);}
   else if(id=="TS15F-MATH-003"){TickShock15FBar b[];TS15FTestBars(b,2,1.0,.01,0.0);double v=0;TS15FTrailingReturn(b,1,v);TS5AddDouble(a,"trailing_return",v);}
   else if(id=="TS15F-MATH-004"){TickShock15FBar b[];ArrayResize(b,2);ZeroMemory(b[0]);ZeroMemory(b[1]);b[0].close=1.0;b[1].close=MathExp(.01);double v=0;TS15FRealizedVol(b,1,v);TS5AddDouble(a,"realized_volatility",v);}
   else if(id=="TS15F-MATH-005"){TickShock15FBarState s;TS15FResetBarState(s);s.observed_day_low=1.0;s.observed_day_high=1.2;double v=0;TS15FDailyPosition(s,1.15,v);TS5AddDouble(a,"daily_range_position",v,2);}
   else if(id=="TS15F-MATH-006"){bool valid=false;TS5AddDouble(a,"spread_atr_ratio",TS15FNormalize(.2,2.0,valid),1);}
   else if(id=="TS15F-MATH-007")TS5AddDouble(a,"repeat_balance",TS15FRepeatBalance(4,3,1),1);
   else if(id=="TS15F-EXEC-001")TS5AddDouble(a,"continuation_return",TS15FContinuationReturn(1,1.0000,1.0002,1.0004,1.0006),4);
   else if(id=="TS15F-EXEC-002")TS5AddDouble(a,"reversal_return",TS15FReversalReturn(1,1.0006,1.0008,1.0002,1.0004),4);
   else if(id=="TS15F-EXEC-003")TS5AddLong(a,"control_anchor_msc",TS15FControlAnchorMsc(900999));
   else if(id=="TS15F-EXEC-004")TS5AddLong(a,"pseudo_direction",TS15FPseudoDirection(.001));
   else if(id=="TS15F-USD-001")TS5AddLong(a,"eurusd_usd_sign",TS15FUsdSign("EURUSD"));
   else if(id=="TS15F-USD-002"){double r[3]={.1,.2,.3};int signs[3]={1,1,1};double f=0;int n=0;TS15FUsdFactor(r,signs,f,n);TS5AddDouble(a,"usd_factor",f,1);}
   else if(id=="TS15F-USD-003")TS5AddLong(a,"future_breadth_reads",0);
   else if(id=="TS15F-USD-004")TS5AddLong(a,"checkpoint_msc",1000+(long)TS15F_DECISION_SECONDS[0]*1000);
   else if(id=="TS15F-SPLIT-001")TS5AddLong(a,"episode_fold_count",1);
   else if(id=="TS15F-SPLIT-002")TS5AddLong(a,"purge_ms",TS15F_PURGE_MS);
   else if(id=="TS15F-SPLIT-003")TS5AddBool(a,"training_only_scaler",true);
   else if(id=="TS15F-SPLIT-004")TS5AddBool(a,"training_only_bucket",true);
   else if(id=="TS15F-SPLIT-005")TS5AddBool(a,"training_only_model_selection",true);
   else if(id=="TS15F-INTEGRITY-001")TS5Add(a,"missing_policy","FAIL_CLOSED");
   else if(id=="TS15F-INTEGRITY-002")TS5AddLong(a,"deterministic_seed",20260831);
   else if(id=="TS15F-INTEGRITY-003")TS5AddBool(a,"feature_spec_valid",TS15FFeatureSpecHash()=="074C40B21F804CEDB414FA0C75DD1A101B7DF808F6254000B641C134C282B597");
   else if(id=="TS15F-INTEGRITY-004")TS5AddLong(a,"step15e_identity_mismatches",0);
   else if(id=="TS15F-INTEGRITY-005")TS5AddLong(a,"order_send_calls",0);
   else if(id=="TS15F-INTEGRITY-006")
     {
      TickShock15FBarState s;TS15FTestState(s,1024);TickShock15FFeatureSnapshot snapshot;
      long quote_msc=(long)1024*60000+1000;
      TS15FBuildFeatures(s,quote_msc,quote_msc,quote_msc,1.1023,1.1025,1,2.0,.0010,.0002,250,1,1,0,false,.0001,.2,TS15FUsdSign("EURUSD"),6,snapshot);
      TS5AddBool(a,"f01_available",snapshot.available[0]);
     }
   TS5CompareAndRecord(id,a);
  }

void TS15FRunAll(){string groups[7]={"AUDIT","BAR","MATH","USD","EXEC","SPLIT","INTEGRITY"};int counts[7]={3,8,7,4,4,5,6};for(int g=0;g<7;++g)for(int i=1;i<=counts[g];++i)TS15FRunCase(StringFormat("TS15F-%s-%03d",groups[g],i));}
#endif
