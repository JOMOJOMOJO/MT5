#ifndef TICK_SHOCK_BASELINE_MQH
#define TICK_SHOCK_BASELINE_MQH

#include "TickShockRing.mqh"

struct TickShockPercentileResult
  {
   bool valid;
   double rank;
   double lower;
   double upper;
   double value;
  };

struct TickShockRobustStatistics
  {
   bool valid;
   double raw_scale;
   double noise_floor;
   double robust_scale;
   double robust_z;
   bool scale_floored;
  };

struct TickShockBaselineReadiness
  {
   int valid_samples;
   int minimum_samples;
   bool ready;
  };

int TSBaselineRequiredCapacity(const int detector_window_ms,const int baseline_minutes,const int exclude_ms)
  {
   if(detector_window_ms<=0 || baseline_minutes<=0 || exclude_ms<0) return 0;
   long retained_msc=(long)baseline_minutes*60*1000+exclude_ms;
   return (int)(retained_msc/detector_window_ms)+2;
  }

int TSBaselineLogicalCapacity(const int detector_window_ms,const int baseline_minutes,const int exclude_ms,const int physical_cap)
  {
   return MathMin(MathMax(0,physical_cap),TSBaselineRequiredCapacity(detector_window_ms,baseline_minutes,exclude_ms));
  }

bool TSLinearPercentile(double &values[],const int count,const double percentile,TickShockPercentileResult &result)
  {
   ZeroMemory(result);
   if(count<=0 || count>ArraySize(values) || percentile<0.0 || percentile>100.0) return false;
   double sorted[];
   ArrayResize(sorted,count);
   for(int i=0;i<count;++i) sorted[i]=values[i];
   ArraySort(sorted);
   result.rank=(percentile/100.0)*(count-1);
   int lo=(int)MathFloor(result.rank),hi=(int)MathCeil(result.rank);
   result.lower=sorted[lo];
   result.upper=sorted[hi];
   result.value=result.lower+(result.upper-result.lower)*(result.rank-lo);
   result.valid=true;
   return true;
  }

double TSHistogramPercentile(const int &hist[],const int offset,const int max_bin,const int count,const double percentile)
  {
   if(count<=0 || offset<0 || max_bin<0 || offset+max_bin>=ArraySize(hist)) return 0.0;
   double rank=(percentile/100.0)*(count-1);
   int lo=(int)MathFloor(rank),hi=(int)MathCeil(rank);
   int cumulative=0,lo_value=0,hi_value=0;
   bool lo_found=false;
   for(int bin=0;bin<=max_bin;++bin)
     {
      cumulative+=hist[offset+bin];
      if(!lo_found && cumulative>lo) {lo_value=bin;lo_found=true;}
      if(cumulative>hi) {hi_value=bin;break;}
     }
   return lo_value+(hi_value-lo_value)*(rank-lo);
  }

bool TSComputeRobustStatistics(const double move,const double median_move,const double mad_move,const double noise_floor,TickShockRobustStatistics &result)
  {
   ZeroMemory(result);
   result.raw_scale=1.4826*MathMax(0.0,mad_move);
   result.noise_floor=MathMax(0.0,noise_floor);
   result.scale_floored=result.raw_scale<result.noise_floor;
   result.robust_scale=MathMax(result.raw_scale,result.noise_floor);
   if(result.robust_scale<=0.0 || !MathIsValidNumber(result.robust_scale)) return false;
   result.robust_z=(move-median_move)/result.robust_scale;
   result.valid=MathIsValidNumber(result.robust_z);
   return result.valid;
  }

bool TSEvaluateBaselineReadiness(const int valid_samples,const int minimum_samples,TickShockBaselineReadiness &result)
  {
   result.valid_samples=MathMax(0,valid_samples);
   result.minimum_samples=MathMax(0,minimum_samples);
   result.ready=result.minimum_samples>0 && result.valid_samples>=result.minimum_samples;
   return result.ready;
  }

#endif
