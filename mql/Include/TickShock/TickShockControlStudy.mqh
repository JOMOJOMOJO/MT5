#ifndef TICK_SHOCK_CONTROL_STUDY_MQH
#define TICK_SHOCK_CONTROL_STUDY_MQH

#include "TickShockStatisticalDetector.mqh"
#include "TickShockEngine.mqh"

#define TS15B_CONTROL_POINT_CAPACITY 512
#define TS15B_CONTROL_HORIZON_COUNT 3
#define TS15B_SHOCK_TIME_CAPACITY 64

enum ENUM_TS15B_DIRECTION
  {
   TS15B_DIRECTION_INVALID=0,
   TS15B_DIRECTION_LONG=1,
   TS15B_DIRECTION_SHORT=-1
  };

struct TickShockControlKey
  {
   int detector_id;
   string symbol;
   int time_bucket;
   int trigger_horizon_ms;
   int estimator;
   int volatility_regime;
  };

struct TickShockControlOutcome
  {
   bool complete;
   double abs_return_1s;
   double abs_return_3s;
   double abs_return_10s;
   double abs_return_30s;
   double abs_return_120s;
   double realized_volatility_120s;
   double mfe_120s;
   double mae_120s;
   double spread_change_120s;
   long tick_activity_120s;
   double quote_reversion_ratio;
   long cluster_duration_comparison_ms;
  };

struct TickShockControlRecord
  {
   string control_id;
   TickShockControlKey key;
   long boundary_msc;
   long quote_msc;
   int quote_age_ms;
   double raw_p;
   double adjusted_p;
   double local_volatility;
   int direction;
   double signed_return;
   double bid;
   double ask;
   double mid;
   double spread;
   long tick_activity;
   bool integrity_ok;
   bool shock_excluded;
   string integrity_status;
   TickShockControlOutcome outcome;
  };

struct TickShockControlPoint
  {
   bool valid;
   long time_msc;
   long quote_msc;
   int quote_age_ms;
   double bid;
   double ask;
   double mid;
   double cumulative_variance;
   long cumulative_ticks;
   bool shock_nearby;
   bool horizon_valid[TS15B_CONTROL_HORIZON_COUNT];
   double raw_p[TS15B_CONTROL_HORIZON_COUNT];
   double adjusted_p[TS15B_CONTROL_HORIZON_COUNT];
   double local_volatility[TS15B_CONTROL_HORIZON_COUNT];
   double signed_return[TS15B_CONTROL_HORIZON_COUNT];
   int estimator[TS15B_CONTROL_HORIZON_COUNT];
   int volatility_regime[TS15B_CONTROL_HORIZON_COUNT];
  };

struct TickShockControlRecorder
  {
   TickShockControlPoint points[];
   int head;
   int count;
   long sequence;
   TickShockControlRecord latest[];
   long observed_boundaries;
   long completed_controls;
   long incomplete_controls;
   long capacity_hits;
   long drops;
   long evictions;
   long duplicate_ids;
   long shock_times[TS15B_SHOCK_TIME_CAPACITY];
   int shock_time_head;
   int shock_time_count;
   bool validation_invalid;
  };

struct TickShockControlMatchRequest
  {
   TickShockControlKey key;
   long event_msc;
  };

struct TickShockControlMatchResult
  {
   bool matched;
   TickShockControlRecord control;
   long time_difference_ms;
   string unmatched_reason;
  };

struct TickShockFunnelObservation
  {
   bool statistical_shock;
   bool direction_available;
   bool directional_burst;
   bool activity_elevated;
   bool liquidity_normal;
   bool cost_feasible;
   bool common_strategy_eligible;
   bool detection_continuation_reachable;
   bool post_burst_continuation_reachable;
   bool pullback_continuation_reachable;
   bool failed_shock_reversal_reachable;
   bool strategy_signal;
  };

string TS15BDirectionName(const int direction)
  {
   if(direction==TS15B_DIRECTION_LONG) return "LONG";
   if(direction==TS15B_DIRECTION_SHORT) return "SHORT";
   return "INVALID";
  }

int TS15BDirectionFromReturn(const double signed_return)
  {
   if(!MathIsValidNumber(signed_return) || signed_return==0.0) return TS15B_DIRECTION_INVALID;
   return signed_return>0.0?TS15B_DIRECTION_LONG:TS15B_DIRECTION_SHORT;
  }

int TS15BMinimumAdjustedIndex(const double &adjusted_p[],const bool &valid[],const int count)
  {
   int selected=-1;
   for(int i=0;i<count && i<ArraySize(adjusted_p) && i<ArraySize(valid);++i)
     {
      if(!valid[i] || !MathIsValidNumber(adjusted_p[i]) || adjusted_p[i]<0.0 || adjusted_p[i]>1.0) continue;
      if(selected<0 || adjusted_p[i]<adjusted_p[selected]) selected=i;
     }
   return selected;
  }

bool TS15BControlKeyEqual(const TickShockControlKey &left,const TickShockControlKey &right)
  {
   return left.detector_id==right.detector_id && left.symbol==right.symbol &&
          left.time_bucket==right.time_bucket &&
          left.trigger_horizon_ms==right.trigger_horizon_ms &&
          left.estimator==right.estimator &&
          left.volatility_regime==right.volatility_regime;
  }

bool TS15BShockDistanceEligible(const long boundary_msc,const long shock_msc,const long exclusion_ms=120000)
  {
   if(boundary_msc<0 || shock_msc<0 || exclusion_ms<0) return false;
   return MathAbs(boundary_msc-shock_msc)>(double)exclusion_ms;
  }

void TS15BResetOutcome(TickShockControlOutcome &outcome)
  {
   ZeroMemory(outcome);
  }

void TS15BResetRecorder(TickShockControlRecorder &recorder)
  {
   ArrayResize(recorder.points,TS15B_CONTROL_POINT_CAPACITY);
   for(int i=0;i<TS15B_CONTROL_POINT_CAPACITY;++i) ZeroMemory(recorder.points[i]);
   ArrayResize(recorder.latest,0);
   recorder.head=0;recorder.count=0;recorder.sequence=0;
   recorder.observed_boundaries=0;recorder.completed_controls=0;
   recorder.incomplete_controls=0;recorder.capacity_hits=0;recorder.drops=0;
   recorder.evictions=0;recorder.duplicate_ids=0;recorder.validation_invalid=false;
   ArrayInitialize(recorder.shock_times,0);recorder.shock_time_head=0;recorder.shock_time_count=0;
  }

int TS15BOldestPointIndex(const TickShockControlRecorder &recorder)
  {
   if(recorder.count<=0) return -1;
   return (recorder.head-recorder.count+TS15B_CONTROL_POINT_CAPACITY)%TS15B_CONTROL_POINT_CAPACITY;
  }

bool TS15BFindPoint(const TickShockControlRecorder &recorder,const long time_msc,TickShockControlPoint &point)
  {
   int oldest=TS15BOldestPointIndex(recorder);
   if(oldest<0) return false;
   for(int i=recorder.count-1;i>=0;--i)
     {
      int index=(oldest+i)%TS15B_CONTROL_POINT_CAPACITY;
      if(recorder.points[index].time_msc==time_msc){point=recorder.points[index];return true;}
      if(recorder.points[index].time_msc<time_msc) return false;
     }
   return false;
  }

void TS15BMarkShock(TickShockControlRecorder &recorder,const long shock_msc,const long exclusion_ms=120000)
  {
   recorder.shock_times[recorder.shock_time_head]=shock_msc;
   recorder.shock_time_head=(recorder.shock_time_head+1)%TS15B_SHOCK_TIME_CAPACITY;
   if(recorder.shock_time_count<TS15B_SHOCK_TIME_CAPACITY) ++recorder.shock_time_count;
   int oldest=TS15BOldestPointIndex(recorder);
   for(int i=0;i<recorder.count;++i)
     {
      int index=(oldest+i)%TS15B_CONTROL_POINT_CAPACITY;
      if(MathAbs(recorder.points[index].time_msc-shock_msc)<=(double)exclusion_ms)
         recorder.points[index].shock_nearby=true;
     }
   for(int i=0;i<ArraySize(recorder.latest);++i)
      if(!TS15BShockDistanceEligible(recorder.latest[i].boundary_msc,shock_msc,exclusion_ms))
         recorder.latest[i].shock_excluded=true;
  }

bool TS15BPointNearRecordedShock(const TickShockControlRecorder &recorder,
                                 const long boundary_msc,
                                 const long exclusion_ms=120000)
  {
   for(int i=0;i<recorder.shock_time_count;++i)
     {
      int index=(recorder.shock_time_head-recorder.shock_time_count+i+TS15B_SHOCK_TIME_CAPACITY)%TS15B_SHOCK_TIME_CAPACITY;
      if(!TS15BShockDistanceEligible(boundary_msc,recorder.shock_times[index],exclusion_ms)) return true;
     }
   return false;
  }

bool TS15BLogAbs(const double end_mid,const double start_mid,double &result)
  {
   result=0.0;
   if(end_mid<=0.0 || start_mid<=0.0) return false;
   result=MathAbs(MathLog(end_mid/start_mid));
   return MathIsValidNumber(result);
  }

bool TS15BBuildMatureOutcome(const TickShockControlRecorder &recorder,
                             const TickShockControlPoint &start,
                             const int horizon_index,
                             TickShockControlOutcome &outcome)
  {
   TS15BResetOutcome(outcome);
   const int checkpoints[5]={1000,3000,10000,30000,120000};
   TickShockControlPoint points[5];
   for(int i=0;i<5;++i)
      if(!TS15BFindPoint(recorder,start.time_msc+(long)checkpoints[i],points[i]) || !points[i].valid)
         return false;
   if(!TS15BLogAbs(points[0].mid,start.mid,outcome.abs_return_1s) ||
      !TS15BLogAbs(points[1].mid,start.mid,outcome.abs_return_3s) ||
      !TS15BLogAbs(points[2].mid,start.mid,outcome.abs_return_10s) ||
      !TS15BLogAbs(points[3].mid,start.mid,outcome.abs_return_30s) ||
      !TS15BLogAbs(points[4].mid,start.mid,outcome.abs_return_120s)) return false;
   double variance=points[4].cumulative_variance-start.cumulative_variance;
   if(variance<0.0 || !MathIsValidNumber(variance)) return false;
   outcome.realized_volatility_120s=MathSqrt(variance);
   double best=0.0,worst=0.0;
   if(horizon_index<0 || horizon_index>=TS15B_CONTROL_HORIZON_COUNT) return false;
   int direction=TS15BDirectionFromReturn(start.signed_return[horizon_index]);
   if(direction==TS15B_DIRECTION_INVALID) return false;
   int oldest=TS15BOldestPointIndex(recorder);
   for(int i=0;i<recorder.count;++i)
     {
      TickShockControlPoint current=recorder.points[(oldest+i)%TS15B_CONTROL_POINT_CAPACITY];
      if(!current.valid || current.time_msc<=start.time_msc || current.time_msc>start.time_msc+120000) continue;
      double move=(current.mid-start.mid)*(double)direction;
      best=MathMax(best,move);worst=MathMin(worst,move);
     }
   outcome.mfe_120s=best;outcome.mae_120s=-worst;
   outcome.spread_change_120s=(points[4].ask-points[4].bid)-(start.ask-start.bid);
   outcome.tick_activity_120s=points[4].cumulative_ticks-start.cumulative_ticks;
   double initial=MathAbs(start.signed_return[horizon_index]);
   double signed_final=MathLog(points[4].mid/start.mid)*(double)direction;
   outcome.quote_reversion_ratio=initial>0.0?MathMax(0.0,-signed_final/initial):0.0;
   outcome.cluster_duration_comparison_ms=0;
   outcome.complete=true;
   return true;
  }

int TS15BLatestIndex(const TickShockControlRecorder &recorder,const TickShockControlKey &key)
  {
   for(int i=0;i<ArraySize(recorder.latest);++i)
      if(TS15BControlKeyEqual(recorder.latest[i].key,key)) return i;
   return -1;
  }

void TS15BStoreLatest(TickShockControlRecorder &recorder,const TickShockControlRecord &record)
  {
   int index=TS15BLatestIndex(recorder,record.key);
   if(index<0){index=ArraySize(recorder.latest);ArrayResize(recorder.latest,index+1);}
   else if(recorder.latest[index].boundary_msc>record.boundary_msc) return;
   else if(recorder.latest[index].control_id==record.control_id)
     {++recorder.duplicate_ids;recorder.validation_invalid=true;return;}
   recorder.latest[index]=record;
  }

void TS15BObservePoint(TickShockControlRecorder &recorder,
                       const TickShockControlPoint &source,
                       const int detector_id,
                       const string symbol)
  {
   TickShockControlPoint point=source;
   if(recorder.count>0)
     {
      int last_index=(recorder.head-1+TS15B_CONTROL_POINT_CAPACITY)%TS15B_CONTROL_POINT_CAPACITY;
      TickShockControlPoint last=recorder.points[last_index];
      if(point.time_msc==last.time_msc)
        {
         // Same-millisecond updates belong to one boundary. Preserve the
         // accumulated counters and replace the boundary with the last quote.
         point.cumulative_variance=last.cumulative_variance;
         point.cumulative_ticks=MathMax(point.cumulative_ticks,last.cumulative_ticks);
         point.shock_nearby=point.shock_nearby || last.shock_nearby;
         recorder.points[last_index]=point;
         return;
        }
      if(point.time_msc<last.time_msc)
        {
         ++recorder.drops;recorder.validation_invalid=true;return;
        }
     }
   if(recorder.count>0)
     {
      TickShockControlPoint prior=recorder.points[(recorder.head-1+TS15B_CONTROL_POINT_CAPACITY)%TS15B_CONTROL_POINT_CAPACITY];
      point.cumulative_variance=prior.cumulative_variance;
      if(prior.valid && point.valid && prior.mid>0.0 && point.mid>0.0)
        {double r=MathLog(point.mid/prior.mid);if(MathIsValidNumber(r))point.cumulative_variance+=r*r;}
      if(point.cumulative_ticks<prior.cumulative_ticks) point.cumulative_ticks=prior.cumulative_ticks;
     }
   if(recorder.count==TS15B_CONTROL_POINT_CAPACITY)
     {
      ++recorder.evictions;
      // Normal ring rotation is expected only after the evicted point has had
      // its 120-second maturity opportunity; otherwise it is fatal.
      TickShockControlPoint evicted=recorder.points[recorder.head];
      if(point.time_msc-evicted.time_msc<120250)
        {++recorder.capacity_hits;recorder.validation_invalid=true;}
     }
   else ++recorder.count;
   recorder.points[recorder.head]=point;
   recorder.head=(recorder.head+1)%TS15B_CONTROL_POINT_CAPACITY;
   ++recorder.observed_boundaries;

   TickShockControlPoint start;
   if(!TS15BFindPoint(recorder,point.time_msc-120250,start)) return;
   for(int h=0;h<TS15B_CONTROL_HORIZON_COUNT;++h)
     {
      if(!start.horizon_valid[h] || start.adjusted_p[h]<=0.01 || start.shock_nearby ||
         TS15BPointNearRecordedShock(recorder,start.time_msc)) continue;
      TickShockControlRecord record;ZeroMemory(record);
      record.control_id=StringFormat("%s_%s_ctrl_h%d_%I64d_%I64d",symbol,TSV1DetectorName((ENUM_TS_V1_DETECTOR)detector_id),h,start.time_msc,++recorder.sequence);
      record.key.detector_id=detector_id;record.key.symbol=symbol;
      record.key.time_bucket=TSV1TimeOfDayBucket(start.time_msc);
      record.key.trigger_horizon_ms=h==0?250:(h==1?500:1000);
      record.key.estimator=start.estimator[h];record.key.volatility_regime=start.volatility_regime[h];
      record.boundary_msc=start.time_msc;record.quote_msc=start.quote_msc;record.quote_age_ms=start.quote_age_ms;
      record.raw_p=start.raw_p[h];record.adjusted_p=start.adjusted_p[h];record.local_volatility=start.local_volatility[h];
      record.signed_return=start.signed_return[h];record.direction=TS15BDirectionFromReturn(record.signed_return);
      record.bid=start.bid;record.ask=start.ask;record.mid=start.mid;record.spread=start.ask-start.bid;
      record.tick_activity=start.cumulative_ticks;record.integrity_ok=start.valid;record.integrity_status=start.valid?"VALID":"INVALID";
      record.shock_excluded=false;
      if(!TS15BBuildMatureOutcome(recorder,start,h,record.outcome))
        {++recorder.incomplete_controls;continue;}
      ++recorder.completed_controls;TS15BStoreLatest(recorder,record);
     }
  }

void TS15BRecordDrop(TickShockControlRecorder &recorder)
  {
   ++recorder.drops;recorder.validation_invalid=true;
  }

void TS15BMatchControl(const TickShockControlRecorder &recorder,
                       const TickShockControlMatchRequest &request,
                       TickShockControlMatchResult &result)
  {
   ZeroMemory(result);result.unmatched_reason="UNMATCHED_EXACT_KEY";
   int index=TS15BLatestIndex(recorder,request.key);
   if(index<0) return;
   TickShockControlRecord candidate=recorder.latest[index];
   if(!candidate.integrity_ok || !candidate.outcome.complete)
     {result.unmatched_reason="UNMATCHED_INTEGRITY";return;}
   if(candidate.shock_excluded)
     {result.unmatched_reason="UNMATCHED_SHOCK_EXCLUSION";return;}
   if(candidate.boundary_msc>=request.event_msc-120000)
     {result.unmatched_reason="UNMATCHED_NO_COMPLETE_PRIOR";return;}
   result.matched=true;result.control=candidate;
   result.time_difference_ms=request.event_msc-candidate.boundary_msc;
   result.unmatched_reason="";
  }

void TS15BSelectClosestEarlier(const TickShockControlRecord &controls[],
                               const int count,
                               const TickShockControlMatchRequest &request,
                               TickShockControlMatchResult &result)
  {
   ZeroMemory(result);result.unmatched_reason="UNMATCHED_EXACT_KEY";
   int selected=-1;
   for(int i=0;i<count && i<ArraySize(controls);++i)
     {
      TickShockControlRecord c=controls[i];
      if(!TS15BControlKeyEqual(c.key,request.key) || !c.integrity_ok || !c.outcome.complete || c.shock_excluded || c.boundary_msc>=request.event_msc-120000) continue;
      if(selected<0 || c.boundary_msc>controls[selected].boundary_msc ||
         (c.boundary_msc==controls[selected].boundary_msc && c.control_id<controls[selected].control_id)) selected=i;
     }
   if(selected<0) return;
   result.matched=true;result.control=controls[selected];result.time_difference_ms=request.event_msc-controls[selected].boundary_msc;result.unmatched_reason="";
  }

string TS15BFirstFail(const TickShockFunnelObservation &f)
  {
   if(!f.statistical_shock) return "STATISTICAL_SHOCK";
   if(!f.direction_available) return "DIRECTION_AVAILABLE";
   if(!f.directional_burst) return "DIRECTIONAL_BURST";
   if(!f.activity_elevated) return "ACTIVITY_ELEVATED";
   if(!f.liquidity_normal) return "LIQUIDITY_NORMAL";
   if(!f.cost_feasible) return "COST_FEASIBLE";
   if(!f.common_strategy_eligible) return "COMMON_STRATEGY_ELIGIBLE";
   if(!f.detection_continuation_reachable && !f.post_burst_continuation_reachable &&
      !f.pullback_continuation_reachable && !f.failed_shock_reversal_reachable) return "STRATEGY_REACHABLE";
   if(!f.strategy_signal) return "STRATEGY_SIGNAL";
   return "";
  }

void TS15BAppendFail(string &value,const string reason)
  {
   if(value!="") value+="|";value+=reason;
  }

string TS15BAllFails(const TickShockFunnelObservation &f)
  {
   string value="";
   if(!f.statistical_shock) TS15BAppendFail(value,"STATISTICAL_SHOCK");
   if(!f.direction_available) TS15BAppendFail(value,"DIRECTION_AVAILABLE");
   if(!f.directional_burst) TS15BAppendFail(value,"DIRECTIONAL_BURST");
   if(!f.activity_elevated) TS15BAppendFail(value,"ACTIVITY_ELEVATED");
   if(!f.liquidity_normal) TS15BAppendFail(value,"LIQUIDITY_NORMAL");
   if(!f.cost_feasible) TS15BAppendFail(value,"COST_FEASIBLE");
   if(!f.common_strategy_eligible) TS15BAppendFail(value,"COMMON_STRATEGY_ELIGIBLE");
   if(!f.detection_continuation_reachable) TS15BAppendFail(value,"DETECTION_CONTINUATION_REACHABLE");
   if(!f.post_burst_continuation_reachable) TS15BAppendFail(value,"POST_BURST_CONTINUATION_REACHABLE");
   if(!f.pullback_continuation_reachable) TS15BAppendFail(value,"PULLBACK_CONTINUATION_REACHABLE");
   if(!f.failed_shock_reversal_reachable) TS15BAppendFail(value,"FAILED_SHOCK_REVERSAL_REACHABLE");
   if(!f.strategy_signal) TS15BAppendFail(value,"STRATEGY_SIGNAL");
   return value;
  }

bool TS15BFunnelReconciles(const long input_count,const long passed,const long excluded)
  {
   return input_count>=0 && passed>=0 && excluded>=0 && input_count==passed+excluded;
  }

void TS15BCountPotentialTrades(const long &cluster_ids[],
                               const bool &reachable[],
                               const bool &accepted_after_overlap[],
                               const int count,
                               long &before_overlap,
                               long &after_overlap)
  {
   before_overlap=0;after_overlap=0;
   long before_ids[],after_ids[];ArrayResize(before_ids,0);ArrayResize(after_ids,0);
   for(int i=0;i<count && i<ArraySize(cluster_ids) && i<ArraySize(reachable) && i<ArraySize(accepted_after_overlap);++i)
     {
      if(!reachable[i]) continue;
      bool known=false;for(int j=0;j<ArraySize(before_ids);++j)if(before_ids[j]==cluster_ids[i]){known=true;break;}
      if(!known){int n=ArraySize(before_ids);ArrayResize(before_ids,n+1);before_ids[n]=cluster_ids[i];}
      if(!accepted_after_overlap[i]) continue;
      known=false;for(int j=0;j<ArraySize(after_ids);++j)if(after_ids[j]==cluster_ids[i]){known=true;break;}
      if(!known){int n=ArraySize(after_ids);ArrayResize(after_ids,n+1);after_ids[n]=cluster_ids[i];}
     }
   before_overlap=ArraySize(before_ids);after_overlap=ArraySize(after_ids);
  }

#endif
