#ifndef TICK_SHOCK_STATISTICAL_CALIBRATION_MQH
#define TICK_SHOCK_STATISTICAL_CALIBRATION_MQH

#include "TickShockStatisticalDetector.mqh"

#define TSV1_HORIZON_COUNT 3
#define TSV1_ESTIMATOR_COUNT 2
#define TSV1_CHANNEL_COUNT 6
#define TSV1_TOD_BUCKET_COUNT 6
#define TSV1_VOL_REGIME_COUNT 3
#define TSV1_CALIBRATION_CELL_COUNT 108
#define TSV1_SCORE_BIN_COUNT 5001
#define TSV1_RETURN_CAPACITY 3612

const int TSV1_HORIZONS_MS[TSV1_HORIZON_COUNT]={250,500,1000};

struct TickShockV1ReturnRecord
  {
   long time_msc;
   double value[TSV1_CHANNEL_COUNT];
   bool value_valid[TSV1_CHANNEL_COUNT];
   double score[TSV1_CHANNEL_COUNT];
   bool score_valid[TSV1_CHANNEL_COUNT];
   int tod_bucket[TSV1_CHANNEL_COUNT];
   int volatility_regime[TSV1_CHANNEL_COUNT];
   double local_sigma[TSV1_CHANNEL_COUNT];
   int local_samples[TSV1_CHANNEL_COUNT];
  };

struct TickShockV1CalibrationContext
  {
   TickShockV1ReturnRecord records[];
   int head;
   int count;
   int capacity;
   double bipower_sum[TSV1_CHANNEL_COUNT];
   int bipower_pairs[TSV1_CHANNEL_COUNT];
   int histogram[];
   int calibration_count[TSV1_CALIBRATION_CELL_COUNT];
   long observations;
   long local_ready;
   long calibration_ready;
   long histogram_overflow;
   long invalid_scale;
  };

int TSV1Channel(const int estimator,const int horizon_index)
  {
   return estimator*TSV1_HORIZON_COUNT+horizon_index;
  }

int TSV1CalibrationCell(const int estimator,const int horizon_index,const int tod_bucket,const int volatility_regime)
  {
   if(estimator<0 || estimator>=TSV1_ESTIMATOR_COUNT || horizon_index<0 || horizon_index>=TSV1_HORIZON_COUNT ||
      tod_bucket<0 || tod_bucket>=TSV1_TOD_BUCKET_COUNT || volatility_regime<0 || volatility_regime>=TSV1_VOL_REGIME_COUNT)
      return -1;
   return (((estimator*TSV1_HORIZON_COUNT+horizon_index)*TSV1_TOD_BUCKET_COUNT+tod_bucket)*TSV1_VOL_REGIME_COUNT+volatility_regime);
  }

int TSV1ScoreBin(const double score)
  {
   if(!MathIsValidNumber(score) || score<0.0) return -1;
   int bin=(int)MathFloor(score/0.01+1e-12);
   return MathMin(TSV1_SCORE_BIN_COUNT-1,bin);
  }

void TSV1ResetCalibration(TickShockV1CalibrationContext &context)
  {
   context.capacity=TSV1_RETURN_CAPACITY;
   context.head=0;
   context.count=0;
   ArrayResize(context.records,context.capacity);
   ArrayResize(context.histogram,TSV1_CALIBRATION_CELL_COUNT*TSV1_SCORE_BIN_COUNT);
   ArrayInitialize(context.histogram,0);
   ArrayInitialize(context.calibration_count,0);
   ArrayInitialize(context.bipower_sum,0.0);
   ArrayInitialize(context.bipower_pairs,0);
   context.observations=0;
   context.local_ready=0;
   context.calibration_ready=0;
   context.histogram_overflow=0;
   context.invalid_scale=0;
  }

int TSV1OldestRecordIndex(const TickShockV1CalibrationContext &context)
  {
   if(context.count<=0 || context.capacity<=0) return -1;
   return (context.head-context.count+context.capacity)%context.capacity;
  }

bool TSV1FindReturnRecord(const TickShockV1CalibrationContext &context,const long time_msc,TickShockV1ReturnRecord &record)
  {
   int oldest=TSV1OldestRecordIndex(context);
   if(oldest<0) return false;
   for(int i=context.count-1;i>=0;--i)
     {
      int index=(oldest+i)%context.capacity;
      if(context.records[index].time_msc==time_msc){record=context.records[index];return true;}
      if(context.records[index].time_msc<time_msc) break;
     }
   return false;
  }

void TSV1AddReturnRecord(TickShockV1CalibrationContext &context,const TickShockV1ReturnRecord &record)
  {
   if(context.capacity<=0) return;
   context.records[context.head]=record;
   context.head=(context.head+1)%context.capacity;
   if(context.count<context.capacity) ++context.count;
  }

void TSV1AdjustBipowerPair(TickShockV1CalibrationContext &context,
                          const TickShockV1ReturnRecord &older,
                          const TickShockV1ReturnRecord &newer,
                          const int delta)
  {
   for(int channel=0;channel<TSV1_CHANNEL_COUNT;++channel)
     {
      if(!older.value_valid[channel] || !newer.value_valid[channel]) continue;
      double product=MathAbs(older.value[channel])*MathAbs(newer.value[channel]);
      context.bipower_sum[channel]+=delta*product;
      context.bipower_pairs[channel]+=delta;
      if(context.bipower_pairs[channel]<0 || context.bipower_sum[channel]<-1e-18)
        {
         context.bipower_pairs[channel]=0;
         context.bipower_sum[channel]=0.0;
         ++context.invalid_scale;
        }
      if(context.bipower_sum[channel]<0.0) context.bipower_sum[channel]=0.0;
     }
  }

void TSV1AdvanceLocalScale(TickShockV1CalibrationContext &context,
                           const long boundary_msc,
                           const int baseline_minutes,
                           const int exclude_ms)
  {
   TickShockV1ReturnRecord older,newer;
   long add_newer=boundary_msc-(long)exclude_ms;
   if(TSV1FindReturnRecord(context,add_newer-250,older) && TSV1FindReturnRecord(context,add_newer,newer))
      TSV1AdjustBipowerPair(context,older,newer,1);
   long baseline_start=add_newer-(long)baseline_minutes*60*1000;
   if(TSV1FindReturnRecord(context,baseline_start,older) && TSV1FindReturnRecord(context,baseline_start+250,newer))
      TSV1AdjustBipowerPair(context,older,newer,-1);
  }

void TSV1InsertMatureScores(TickShockV1CalibrationContext &context,const long boundary_msc,const int exclude_ms)
  {
   TickShockV1ReturnRecord mature;
   if(!TSV1FindReturnRecord(context,boundary_msc-(long)exclude_ms,mature)) return;
   for(int estimator=0;estimator<TSV1_ESTIMATOR_COUNT;++estimator)
      for(int horizon=0;horizon<TSV1_HORIZON_COUNT;++horizon)
        {
         int channel=TSV1Channel(estimator,horizon);
         if(!mature.score_valid[channel]) continue;
         int cell=TSV1CalibrationCell(estimator,horizon,mature.tod_bucket[channel],mature.volatility_regime[channel]);
         int bin=TSV1ScoreBin(mature.score[channel]);
         if(cell<0 || bin<0){++context.histogram_overflow;continue;}
         int base=cell*TSV1_SCORE_BIN_COUNT;
         // Fenwick representation of the fixed 0.01 score histogram permits
         // exact inclusive tail counts without a 5,001-bin scan per decision.
         for(int tree_index=bin+1;tree_index<=TSV1_SCORE_BIN_COUNT;tree_index+=tree_index&(-tree_index))
            ++context.histogram[base+tree_index-1];
         ++context.calibration_count[cell];
        }
  }

bool TSV1BuildReturnRecord(TickShockV1CalibrationContext &context,
                           const long boundary_msc,
                           const double &raw_returns[],
                           const bool &raw_valid[],
                           const double &robust_returns[],
                           const bool &robust_valid[],
                           const double noise_return,
                           const int min_local_samples,
                           TickShockV1ReturnRecord &record)
  {
   ZeroMemory(record);
   record.time_msc=boundary_msc;
   int tod=TSV1TimeOfDayBucket(boundary_msc);
   bool any=false;
   for(int estimator=0;estimator<TSV1_ESTIMATOR_COUNT;++estimator)
      for(int horizon=0;horizon<TSV1_HORIZON_COUNT;++horizon)
        {
         int channel=TSV1Channel(estimator,horizon);
         bool valid=estimator==0?(horizon<ArraySize(raw_valid) && raw_valid[horizon]):(horizon<ArraySize(robust_valid) && robust_valid[horizon]);
         double value=estimator==0?(horizon<ArraySize(raw_returns)?raw_returns[horizon]:0.0):(horizon<ArraySize(robust_returns)?robust_returns[horizon]:0.0);
         record.value[channel]=value;
         record.value_valid[channel]=valid && MathIsValidNumber(value);
         record.tod_bucket[channel]=tod;
         record.volatility_regime[channel]=TSV1_VOL_INVALID;
         record.local_samples[channel]=context.bipower_pairs[channel]+1;
         if(!record.value_valid[channel] || context.bipower_pairs[channel]<min_local_samples-1 || noise_return<=0.0) continue;
         double variance=(M_PI*0.5)*(context.bipower_sum[channel]/(double)context.bipower_pairs[channel]);
         if(!MathIsValidNumber(variance) || variance<0.0){++context.invalid_scale;continue;}
         record.local_sigma[channel]=MathMax(MathSqrt(variance),noise_return);
         ENUM_TS_V1_VOLATILITY_REGIME regime=TSV1VolatilityRegime(record.local_sigma[channel],noise_return);
         if(regime==TSV1_VOL_INVALID) continue;
         record.volatility_regime[channel]=(int)regime;
         record.score[channel]=MathAbs(value)/record.local_sigma[channel];
         record.score_valid[channel]=MathIsValidNumber(record.score[channel]);
         any=any || record.score_valid[channel];
        }
   if(any) ++context.local_ready;
   ++context.observations;
   return any;
  }

bool TSV1CalibrationTail(const TickShockV1CalibrationContext &context,
                         const int estimator,
                         const int horizon,
                         const TickShockV1ReturnRecord &record,
                         const int min_calibration_samples,
                         TickShockV1TailResult &tail,
                         int &calibration_count)
  {
   ZeroMemory(tail);
   calibration_count=0;
   int channel=TSV1Channel(estimator,horizon);
   if(channel<0 || channel>=TSV1_CHANNEL_COUNT || !record.score_valid[channel]) return false;
   int cell=TSV1CalibrationCell(estimator,horizon,record.tod_bucket[channel],record.volatility_regime[channel]);
   if(cell<0) return false;
   calibration_count=context.calibration_count[cell];
   if(!TSV1CalibrationReady(calibration_count,min_calibration_samples)) return false;
   int bin=TSV1ScoreBin(record.score[channel]);
   if(bin<0) return false;
   long below=0;
   int offset=cell*TSV1_SCORE_BIN_COUNT;
   for(int tree_index=bin;tree_index>0;tree_index-=tree_index&(-tree_index))
      below+=(long)context.histogram[offset+tree_index-1];
   long exceedances=(long)calibration_count-below;
   if(exceedances>calibration_count) return false;
   tail.valid=true;
   tail.exceedances=(int)exceedances;
   tail.raw_p=(1.0+(double)exceedances)/(1.0+(double)calibration_count);
   tail.empirical_percentile=100.0*(1.0-tail.raw_p);
   return true;
  }

void TSV1ObserveBoundary(TickShockV1CalibrationContext &context,
                         const long boundary_msc,
                         const double &raw_returns[],
                         const bool &raw_valid[],
                         const double &robust_returns[],
                         const bool &robust_valid[],
                         const double noise_return,
                         const int baseline_minutes,
                         const int exclude_ms,
                         const int min_local_samples,
                         TickShockV1ReturnRecord &record)
  {
   TSV1AdvanceLocalScale(context,boundary_msc,baseline_minutes,exclude_ms);
   TSV1InsertMatureScores(context,boundary_msc,exclude_ms);
   TSV1BuildReturnRecord(context,boundary_msc,raw_returns,raw_valid,robust_returns,robust_valid,noise_return,min_local_samples,record);
   TSV1AddReturnRecord(context,record);
  }

#endif
