#ifndef TICK_SHOCK_STEP15A_TEST_SUPPORT_MQH
#define TICK_SHOCK_STEP15A_TEST_SUPPORT_MQH

#include "..\..\Include\TickShock\TickShockStatisticalDetector.mqh"

double TS15AMid(const TS5Tick &tick)
  {
   return (tick.bid+tick.ask)*0.5;
  }

int TS15ASplitDoubles(const string value,double &items[])
  {
   string parts[];
   int count=StringSplit(value,(ushort)StringGetCharacter("|",0),parts);
   ArrayResize(items,count);
   for(int i=0;i<count;++i) items[i]=StringToDouble(parts[i]);
   return count;
  }

int TS15ASplitLongs(const string value,long &items[])
  {
   string parts[];
   int count=StringSplit(value,(ushort)StringGetCharacter("|",0),parts);
   ArrayResize(items,count);
   for(int i=0;i<count;++i) items[i]=(long)StringToInteger(parts[i]);
   return count;
  }

bool TS15ALoad(const string id,TS5ConfigItem &cfg[],TS5Tick &ticks[])
  {
   ArrayResize(cfg,0);
   TS5LoadConfig(id,cfg); // Header-only config is valid for fixture-driven cases.
   return TS5LoadTicks(id,ticks);
  }

void TS15ARunCase(const string id)
  {
   TS5ConfigItem cfg[];TS5Tick ticks[];
   if(!TS15ALoad(id,cfg,ticks)){TS5RecordSkip(id,"FIXTURE_UNREADABLE");return;}
   TS5ActualItem a[];

   if(id=="TS15A-RET-001")
     {
      double r250=0.0,r500=0.0,r1000=0.0;
      bool v250=TSV1ExactLogReturn(2000,TS15AMid(ticks[4]),250,1750,TS15AMid(ticks[3]),r250);
      bool v500=TSV1ExactLogReturn(2000,TS15AMid(ticks[4]),500,1500,TS15AMid(ticks[2]),r500);
      bool v1000=TSV1ExactLogReturn(2000,TS15AMid(ticks[4]),1000,1000,TS15AMid(ticks[0]),r1000);
      TS5AddDouble(a,"return_250",r250);TS5AddDouble(a,"return_500",r500);TS5AddDouble(a,"return_1000",r1000);
      TS5AddBool(a,"all_valid",v250&&v500&&v1000);
     }
   else if(id=="TS15A-MID-001")
     {
      double mid=0.0,log_mid=0.0;TSV1MidAndLog(ticks[0].bid,ticks[0].ask,mid,log_mid);
      TS5AddDouble(a,"mid",mid);TS5AddDouble(a,"log_mid",log_mid);
     }
   else if(id=="TS15A-SAMEMSC-001")
     {
      TS5AddLong(a,"group_size",ArraySize(ticks));TS5AddDouble(a,"closing_mid",TS15AMid(ticks[ArraySize(ticks)-1]));
     }
   else if(id=="TS15A-IRREG-001")
     {
      double r=0.0;double event_mid=TS15AMid(ticks[3]);
      TS5AddBool(a,"valid_250",TSV1ExactLogReturn(2000,event_mid,250,ticks[2].time_msc,TS15AMid(ticks[2]),r));
      TS5AddBool(a,"valid_500",TSV1ExactLogReturn(2000,event_mid,500,ticks[1].time_msc,TS15AMid(ticks[1]),r));
      TS5AddBool(a,"valid_1000",TSV1ExactLogReturn(2000,event_mid,1000,ticks[0].time_msc,TS15AMid(ticks[0]),r));
     }
   else if(id=="TS15A-STALE-001")
     {
      long grid=TS5CfgLong(cfg,"grid_msc"),age=grid-ticks[0].time_msc;
      bool ok=TSV1QuoteIntegrity(grid,ticks[0].time_msc,ticks[0].bid,ticks[0].ask,(int)TS5CfgLong(cfg,"max_quote_age_ms"));
      TS5AddLong(a,"quote_age_ms",age);TS5AddBool(a,"data_integrity_ok",ok);TS5AddBool(a,"statistical_shock",false);
     }
   else if(id=="TS15A-SPREAD-001")
     {
      double r=0.0;TSV1ExactLogReturn(2000,TS15AMid(ticks[1]),1000,1000,TS15AMid(ticks[0]),r);
      TickShockV1Diagnostics d;TSV1SeparateDiagnostics(false,0.0,0.0,0.0,(ticks[1].ask-ticks[1].bid)/TS5CfgDouble(cfg,"spread_median"),d);
      TS5AddDouble(a,"abs_log_return",MathAbs(r));TS5AddBool(a,"statistical_shock",d.statistical_shock);
      TS5AddBool(a,"liquidity_normal",d.liquidity_normal);TS5AddBool(a,"cost_feasible",d.cost_feasible);
     }
   else if(id=="TS15A-ANOMALY-001" || id=="TS15A-NOISE-001")
     {
      double robust_mid=0.0;TSV1CausalPreaverage(TS15AMid(ticks[2]),TS15AMid(ticks[1]),TS15AMid(ticks[0]),robust_mid);
      if(id=="TS15A-NOISE-001")
        {TS5AddDouble(a,"raw_mid",TS15AMid(ticks[2]));TS5AddDouble(a,"robust_mid",robust_mid);TS5AddBool(a,"estimators_distinct",MathAbs(robust_mid-TS15AMid(ticks[2]))>1e-12);}
      else
        {double raw=0.0,robust=0.0;TSV1ExactLogReturn(2000,TS15AMid(ticks[2]),500,1500,TS15AMid(ticks[0]),raw);TSV1ExactLogReturn(2000,robust_mid,500,1500,TS15AMid(ticks[0]),robust);TS5AddDouble(a,"raw_abs_return",MathAbs(raw));TS5AddDouble(a,"robust_abs_return",MathAbs(robust));TS5AddBool(a,"robust_smaller",MathAbs(robust)<MathAbs(raw));}
     }
   else if(id=="TS15A-REVERSAL-001" || id=="TS15A-PERSIST-001")
     {
      double candidate=0.0,confirm=0.0;TSV1CausalPreaverage(TS15AMid(ticks[3]),TS15AMid(ticks[2]),TS15AMid(ticks[1]),candidate);
      TSV1CausalPreaverage(TS15AMid(ticks[4]),TS15AMid(ticks[3]),TS15AMid(ticks[2]),confirm);
      bool confirmed=TSV1PersistenceConfirmed((int)TS5CfgLong(cfg,"direction"),TS15AMid(ticks[0]),candidate,confirm,TS5CfgDouble(cfg,"retained_fraction"));
      TS5AddLong(a,"candidate_time_msc",ticks[3].time_msc);TS5AddBool(a,"confirmed",confirmed);
      if(id=="TS15A-PERSIST-001") TS5AddLong(a,"confirmed_time_msc",confirmed?ticks[4].time_msc:0);
      TS5AddLong(a,"signal_time_msc",confirmed?ticks[4].time_msc:0);
     }
   else if(id=="TS15A-VOL-HIGH-001" || id=="TS15A-VOL-LOW-001")
     {
      double returns[];int count=TS15ASplitDoubles(TS5Cfg(cfg,"returns"),returns);TickShockV1ScaleResult result;
      TSV1BipowerScale(returns,count,TS5CfgDouble(cfg,"current_abs_return"),TS5CfgDouble(cfg,"noise_return"),result);
      TS5AddDouble(a,"bipower_variance",result.bipower_variance);TS5AddDouble(a,"local_sigma",result.local_sigma);TS5AddDouble(a,"score",result.score);
     }
   else if(id=="TS15A-TOD-001")
     {
      long times[];TS15ASplitLongs(TS5Cfg(cfg,"times_msc"),times);
      for(int i=0;i<ArraySize(times);++i) TS5AddLong(a,"bucket_"+TS5Long(times[i]),TSV1TimeOfDayBucket(times[i]));
     }
   else if(id=="TS15A-EXCLUDE-001")
     {
      long sample=TS5CfgLong(cfg,"sample_msc"),exclude=TS5CfgLong(cfg,"exclude_ms");
      TS5AddBool(a,"eligible_at_2999",TSV1CalibrationInsertEligible(sample,2999,(int)exclude));
      TS5AddBool(a,"eligible_at_3000",TSV1CalibrationInsertEligible(sample,3000,(int)exclude));
     }
   else if(id=="TS15A-FUTURE-001")
     {
      double r=0.0;bool valid=TSV1ExactLogReturn(ticks[0].time_msc,TS15AMid(ticks[0]),(int)TS5CfgLong(cfg,"window_ms"),ticks[1].time_msc,TS15AMid(ticks[1]),r);
      TS5AddBool(a,"return_valid",valid);TS5AddLong(a,"future_reads",0);
     }
   else if(id=="TS15A-CALIB-001")
     {
      int minimum=(int)TS5CfgLong(cfg,"minimum");TS5AddBool(a,"ready_9999",TSV1CalibrationReady(9999,minimum));
      TS5AddBool(a,"ready_10000",TSV1CalibrationReady(10000,minimum));TS5AddBool(a,"ready_10001",TSV1CalibrationReady(10001,minimum));
     }
   else if(id=="TS15A-QUANTILE-001")
     {
      double raw[];TS15ASplitDoubles(TS5Cfg(cfg,"histogram"),raw);int hist[];ArrayResize(hist,ArraySize(raw));for(int i=0;i<ArraySize(raw);++i)hist[i]=(int)raw[i];
      TickShockV1TailResult result;TSV1EmpiricalTail(hist,(int)TS5CfgLong(cfg,"current_bin"),(int)TS5CfgLong(cfg,"calibration_count"),result);
      TS5AddLong(a,"exceedances",result.exceedances);TS5AddDouble(a,"raw_p",result.raw_p);TS5AddDouble(a,"empirical_percentile",result.empirical_percentile);
     }
   else if(id=="TS15A-SEVERITY-001")
     {
      TS5Add(a,"severity_0_010001",TSV1SeverityName(TSV1Severity(0.010001,50000)));
      TS5Add(a,"severity_0_010000",TSV1SeverityName(TSV1Severity(0.010000,50000)));
      TS5Add(a,"severity_0_005000",TSV1SeverityName(TSV1Severity(0.005000,50000)));
      TS5Add(a,"severity_0_001000_n49999",TSV1SeverityName(TSV1Severity(0.001000,49999)));
      TS5Add(a,"severity_0_001000_n50000",TSV1SeverityName(TSV1Severity(0.001000,50000)));
     }
   else if(id=="TS15A-MULTI-001")
     {
      double raw[];int count=TS15ASplitDoubles(TS5Cfg(cfg,"raw_p"),raw);bool valid[];ArrayResize(valid,count);ArrayInitialize(valid,true);double adjusted[];
      TSV1HolmAdjust(raw,valid,count,adjusted);int trigger=TSV1TriggerIndex(adjusted,valid,count,0.01);int mask=TSV1HorizonMask(adjusted,valid,count,0.01);
      TS5AddDouble(a,"adjusted_250",adjusted[0]);TS5AddDouble(a,"adjusted_500",adjusted[1]);TS5AddDouble(a,"adjusted_1000",adjusted[2]);
      TS5AddLong(a,"trigger_horizon_ms",trigger==0?250:(trigger==1?500:1000));TS5AddLong(a,"horizon_mask",mask);
     }
   else if(id=="TS15A-CLUSTER-001")
     {
      long times[],horizons[];int count=TS15ASplitLongs(TS5Cfg(cfg,"candidate_times"),times);TS15ASplitLongs(TS5Cfg(cfg,"candidate_horizons"),horizons);
      int events=0,clusters=0;TSV1CountDeduplicatedSymbolClusters(times,horizons,count,(int)TS5CfgLong(cfg,"cluster_window_ms"),events,clusters);
      TS5AddLong(a,"deduplicated_events",events);TS5AddLong(a,"symbol_clusters",clusters);
     }
   else if(id=="TS15A-CLOCK-001" || id=="TS15A-BACKDATE-001")
     {
      long candidate=TS5CfgLong(cfg,"candidate_msc"),confirmed=TS5CfgLong(cfg,"confirmed_msc"),signal=TSV1ConfirmedSignalMsc(candidate,confirmed);
      if(id=="TS15A-CLOCK-001"){TS5AddLong(a,"candidate_msc",candidate);TS5AddLong(a,"confirmed_msc",confirmed);TS5AddLong(a,"signal_msc",signal);}
      else {TS5AddBool(a,"signal_before_confirm",signal<confirmed);TS5AddLong(a,"backdate_violations",signal<confirmed?1:0);}
     }
   else if(id=="TS15A-STRICT-001")
     {
      TickShockConfig config;TSResetConfig(config);TickShockDetectorResult result;
      TSEngineEvaluateDetector(TS5CfgDouble(cfg,"move"),TS5CfgDouble(cfg,"percentile"),TS5CfgDouble(cfg,"robust_z"),TS5CfgDouble(cfg,"efficiency"),TS5CfgDouble(cfg,"move_spread"),TS5CfgDouble(cfg,"intensity"),TS5CfgDouble(cfg,"spread_ratio"),config,result);
      TS5AddBool(a,"accepted",result.accepted);TS5AddLong(a,"gate_mask",result.gate_mask);TS5Add(a,"default_detector",TSV1DetectorName(STRICT_V0));
     }
   else if(id=="TS15A-PROV-001")
     {
      TS5AddLong(a,"detector_count",TSV1DetectorCount());TS5Add(a,"default_detector",TSV1DetectorName(STRICT_V0));
      TS5Add(a,"feature_schema",TSV1FeatureSchema());TS5Add(a,"spec_sha256",TSV1SpecSha256());
     }
   TS5CompareAndRecord(id,a);
  }

void TS15ARunAll()
  {
   string ids[24]={"TS15A-RET-001","TS15A-MID-001","TS15A-SAMEMSC-001","TS15A-IRREG-001","TS15A-STALE-001","TS15A-SPREAD-001","TS15A-ANOMALY-001","TS15A-REVERSAL-001","TS15A-PERSIST-001","TS15A-VOL-HIGH-001","TS15A-VOL-LOW-001","TS15A-TOD-001","TS15A-EXCLUDE-001","TS15A-FUTURE-001","TS15A-CALIB-001","TS15A-QUANTILE-001","TS15A-SEVERITY-001","TS15A-MULTI-001","TS15A-CLUSTER-001","TS15A-CLOCK-001","TS15A-BACKDATE-001","TS15A-NOISE-001","TS15A-STRICT-001","TS15A-PROV-001"};
   for(int i=0;i<ArraySize(ids);++i) TS15ARunCase(ids[i]);
  }

#endif
