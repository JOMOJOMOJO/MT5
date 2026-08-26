#ifndef TICK_SHOCK_STATISTICAL_DETECTOR_MQH
#define TICK_SHOCK_STATISTICAL_DETECTOR_MQH

// Step 15A statistical detector primitives.  This module contains no MT5 I/O
// and is called by both the production research EA and the detector harness.

enum ENUM_TS_V1_DETECTOR
  {
   STRICT_V0=0,
   TAIL_V1_RAW=1,
   TAIL_V1_NOISE_ROBUST=2,
   TAIL_V1_PERSISTENT=3
  };

enum ENUM_TS_V1_SEVERITY
  {
   TSV1_SEVERITY_NONE=0,
   TSV1_SEVERITY_P990,
   TSV1_SEVERITY_P995,
   TSV1_SEVERITY_P999
  };

enum ENUM_TS_V1_VOLATILITY_REGIME
  {
   TSV1_VOL_LOW=0,
   TSV1_VOL_NORMAL,
   TSV1_VOL_HIGH,
   TSV1_VOL_INVALID
  };

struct TickShockV1Diagnostics
  {
   bool statistical_shock;
   bool directional_burst;
   bool activity_elevated;
   bool liquidity_normal;
   bool cost_feasible;
   bool strategy_signal;
  };

struct TickShockV1ScaleResult
  {
   bool valid;
   int sample_count;
   double bipower_variance;
   double local_sigma;
   double score;
   bool noise_floor_used;
  };

struct TickShockV1TailResult
  {
   bool valid;
   int exceedances;
   double raw_p;
   double empirical_percentile;
  };

string TSV1SpecSha256()
  {
   return "53DB75EEE4641D98F4917E74B9C26B84D07533CE8EA1A6689AF7F36BAAEA64EA";
  }

string TSV1FeatureSchema()
  {
   return "tickshock-detector-feature-v1";
  }

int TSV1DetectorCount()
  {
   return 4;
  }

string TSV1DetectorName(const ENUM_TS_V1_DETECTOR detector)
  {
   if(detector==STRICT_V0) return "STRICT_V0";
   if(detector==TAIL_V1_RAW) return "TAIL_V1_RAW";
   if(detector==TAIL_V1_NOISE_ROBUST) return "TAIL_V1_NOISE_ROBUST";
   if(detector==TAIL_V1_PERSISTENT) return "TAIL_V1_PERSISTENT";
   return "INVALID_DETECTOR";
  }

bool TSV1DetectorValid(const ENUM_TS_V1_DETECTOR detector)
  {
   return detector>=STRICT_V0 && detector<=TAIL_V1_PERSISTENT;
  }

string TSV1SeverityName(const ENUM_TS_V1_SEVERITY severity)
  {
   if(severity==TSV1_SEVERITY_P990) return "P990";
   if(severity==TSV1_SEVERITY_P995) return "P995";
   if(severity==TSV1_SEVERITY_P999) return "P999";
   return "NONE";
  }

string TSV1VolatilityRegimeName(const ENUM_TS_V1_VOLATILITY_REGIME regime)
  {
   if(regime==TSV1_VOL_LOW) return "LOW";
   if(regime==TSV1_VOL_NORMAL) return "NORMAL";
   if(regime==TSV1_VOL_HIGH) return "HIGH";
   return "INVALID";
  }

bool TSV1MidAndLog(const double bid,const double ask,double &mid,double &log_mid)
  {
   mid=0.0;
   log_mid=0.0;
   if(!MathIsValidNumber(bid) || !MathIsValidNumber(ask) || bid<=0.0 || ask<bid)
      return false;
   mid=(bid+ask)*0.5;
   if(!MathIsValidNumber(mid) || mid<=0.0) return false;
   log_mid=MathLog(mid);
   if(!MathIsValidNumber(log_mid))
     {
      mid=0.0;
      log_mid=0.0;
      return false;
     }
   return true;
  }

bool TSV1ExactLogReturn(const long event_msc,
                        const double event_mid,
                        const int horizon_ms,
                        const long anchor_msc,
                        const double anchor_mid,
                        double &result)
  {
   result=0.0;
   if(horizon_ms<=0 || event_mid<=0.0 || anchor_mid<=0.0 ||
      anchor_msc!=event_msc-(long)horizon_ms)
      return false;
   result=MathLog(event_mid/anchor_mid);
   if(!MathIsValidNumber(result))
     {
      result=0.0;
      return false;
     }
   return true;
  }

bool TSV1QuoteIntegrity(const long grid_msc,
                        const long quote_msc,
                        const double bid,
                        const double ask,
                        const int max_quote_age_ms)
  {
   if(grid_msc<quote_msc || max_quote_age_ms<0) return false;
   if(grid_msc-quote_msc>(long)max_quote_age_ms) return false;
   if(!MathIsValidNumber(bid) || !MathIsValidNumber(ask)) return false;
   return bid>0.0 && ask>=bid;
  }

bool TSV1CausalPreaverage(const double mid_t,
                          const double mid_t_minus_250,
                          const double mid_t_minus_500,
                          double &result)
  {
   result=0.0;
   if(mid_t<=0.0 || mid_t_minus_250<=0.0 || mid_t_minus_500<=0.0) return false;
   if(!MathIsValidNumber(mid_t) || !MathIsValidNumber(mid_t_minus_250) ||
      !MathIsValidNumber(mid_t_minus_500)) return false;
   result=(mid_t+2.0*mid_t_minus_250+mid_t_minus_500)*0.25;
   return MathIsValidNumber(result) && result>0.0;
  }

bool TSV1PersistenceConfirmed(const int direction,
                              const double anchor_mid,
                              const double candidate_mid,
                              const double confirmed_mid,
                              const double retained_fraction)
  {
   if((direction!=1 && direction!=-1) || anchor_mid<=0.0 ||
      candidate_mid<=0.0 || confirmed_mid<=0.0 ||
      retained_fraction<0.0 || retained_fraction>1.0)
      return false;
   double candidate_move=(candidate_mid-anchor_mid)*(double)direction;
   double retained_move=(confirmed_mid-anchor_mid)*(double)direction;
   if(candidate_move<=0.0) return false;
   return retained_move>=candidate_move*retained_fraction;
  }

void TSV1SeparateDiagnostics(const bool statistical_shock,
                             const double efficiency,
                             const double tick_intensity_ratio,
                             const double move_spread_ratio,
                             const double spread_ratio,
                             TickShockV1Diagnostics &result)
  {
   result.statistical_shock=statistical_shock;
   result.directional_burst=MathIsValidNumber(efficiency) && efficiency>=0.65;
   result.activity_elevated=MathIsValidNumber(tick_intensity_ratio) && tick_intensity_ratio>=1.5;
   result.liquidity_normal=MathIsValidNumber(spread_ratio) && spread_ratio<=1.5;
   result.cost_feasible=MathIsValidNumber(move_spread_ratio) && move_spread_ratio>=4.0 && result.liquidity_normal;
   result.strategy_signal=result.statistical_shock && result.directional_burst &&
                          result.activity_elevated && result.cost_feasible;
  }

bool TSV1StrategyPathEligible(const TickShockV1Diagnostics &diagnostics)
  {
   return diagnostics.statistical_shock && diagnostics.strategy_signal;
  }

bool TSV1BipowerScale(const double &returns[],
                      const int count,
                      const double current_abs_return,
                      const double noise_return,
                      TickShockV1ScaleResult &result)
  {
   result.valid=false;
   result.sample_count=0;
   result.bipower_variance=0.0;
   result.local_sigma=0.0;
   result.score=0.0;
   result.noise_floor_used=false;
   if(count<2 || count>ArraySize(returns) || current_abs_return<0.0 || noise_return<=0.0)
      return false;
   double products=0.0;
   for(int i=1;i<count;++i)
     {
      if(!MathIsValidNumber(returns[i]) || !MathIsValidNumber(returns[i-1])) return false;
      products+=MathAbs(returns[i])*MathAbs(returns[i-1]);
     }
   result.sample_count=count;
   result.bipower_variance=(M_PI*0.5)*(products/(double)(count-1));
   if(!MathIsValidNumber(result.bipower_variance) || result.bipower_variance<0.0) return false;
   double raw_sigma=MathSqrt(result.bipower_variance);
   result.noise_floor_used=raw_sigma<noise_return;
   result.local_sigma=MathMax(raw_sigma,noise_return);
   if(result.local_sigma<=0.0 || !MathIsValidNumber(result.local_sigma)) return false;
   result.score=current_abs_return/result.local_sigma;
   result.valid=MathIsValidNumber(result.score);
   return result.valid;
  }

ENUM_TS_V1_VOLATILITY_REGIME TSV1VolatilityRegime(const double local_sigma,
                                                   const double noise_return)
  {
   if(local_sigma<=0.0 || noise_return<=0.0 || !MathIsValidNumber(local_sigma) ||
      !MathIsValidNumber(noise_return)) return TSV1_VOL_INVALID;
   double ratio=local_sigma/noise_return;
   if(ratio<2.0) return TSV1_VOL_LOW;
   if(ratio<5.0) return TSV1_VOL_NORMAL;
   return TSV1_VOL_HIGH;
  }

int TSV1TimeOfDayBucket(const long time_msc)
  {
   const long day_msc=86400000;
   long value=time_msc%day_msc;
   if(value<0) value+=day_msc;
   return (int)(value/14400000);
  }

bool TSV1CalibrationInsertEligible(const long sample_msc,
                                   const long boundary_msc,
                                   const int exclude_ms)
  {
   return sample_msc>=0 && exclude_ms>=0 && sample_msc<=boundary_msc-(long)exclude_ms;
  }

bool TSV1CalibrationReady(const int count,const int minimum)
  {
   return minimum>0 && count>=minimum;
  }

bool TSV1EmpiricalTail(const int &histogram[],
                       const int current_bin,
                       const int calibration_count,
                       TickShockV1TailResult &result)
  {
   result.valid=false;
   result.exceedances=0;
   result.raw_p=1.0;
   result.empirical_percentile=0.0;
   if(calibration_count<=0 || current_bin<0 || current_bin>=ArraySize(histogram)) return false;
   long exceedances=0;
   for(int i=current_bin;i<ArraySize(histogram);++i)
     {
      if(histogram[i]<0) return false;
      exceedances+=(long)histogram[i];
     }
   if(exceedances>calibration_count) return false;
   result.exceedances=(int)exceedances;
   result.raw_p=(1.0+(double)exceedances)/(1.0+(double)calibration_count);
   // Percentile is reported on the 0..100 scale and uses the same finite-
   // sample plus-one rank as raw_p.
   result.empirical_percentile=100.0*(1.0-result.raw_p);
   result.valid=true;
   return true;
  }

ENUM_TS_V1_SEVERITY TSV1Severity(const double adjusted_p,const int calibration_count)
  {
   if(!MathIsValidNumber(adjusted_p) || adjusted_p<0.0 || adjusted_p>1.0)
      return TSV1_SEVERITY_NONE;
   if(adjusted_p<=0.001 && calibration_count>=50000) return TSV1_SEVERITY_P999;
   if(adjusted_p<=0.005) return TSV1_SEVERITY_P995;
   if(adjusted_p<=0.01) return TSV1_SEVERITY_P990;
   return TSV1_SEVERITY_NONE;
  }

void TSV1HolmAdjust(const double &raw_p[],
                    const bool &valid[],
                    const int count,
                    double &adjusted[])
  {
   ArrayResize(adjusted,count);
   ArrayInitialize(adjusted,1.0);
   int indices[];
   ArrayResize(indices,0);
   for(int i=0;i<count && i<ArraySize(raw_p) && i<ArraySize(valid);++i)
     {
      if(!valid[i] || !MathIsValidNumber(raw_p[i]) || raw_p[i]<0.0 || raw_p[i]>1.0) continue;
      int size=ArraySize(indices);
      ArrayResize(indices,size+1);
      indices[size]=i;
     }
   int m=ArraySize(indices);
   for(int i=0;i<m-1;++i)
      for(int j=i+1;j<m;++j)
         if(raw_p[indices[j]]<raw_p[indices[i]] ||
            (raw_p[indices[j]]==raw_p[indices[i]] && indices[j]<indices[i]))
           {
            int swap=indices[i];indices[i]=indices[j];indices[j]=swap;
           }
   double previous=0.0;
   for(int rank=0;rank<m;++rank)
     {
      int index=indices[rank];
      double value=MathMin(1.0,(double)(m-rank)*raw_p[index]);
      value=MathMax(previous,value);
      adjusted[index]=value;
      previous=value;
     }
  }

int TSV1TriggerIndex(const double &adjusted[],
                     const bool &valid[],
                     const int count,
                     const double alpha)
  {
   int selected=-1;
   for(int i=0;i<count && i<ArraySize(adjusted) && i<ArraySize(valid);++i)
     {
      if(!valid[i] || adjusted[i]>alpha) continue;
      if(selected<0 || adjusted[i]<adjusted[selected]) selected=i;
     }
   return selected;
  }

int TSV1HorizonMask(const double &adjusted[],
                    const bool &valid[],
                    const int count,
                    const double alpha)
  {
   int mask=0;
   for(int i=0;i<count && i<ArraySize(adjusted) && i<ArraySize(valid);++i)
      if(valid[i] && adjusted[i]<=alpha) mask|=(1<<i);
   return mask;
  }

void TSV1CountDeduplicatedSymbolClusters(const long &candidate_times[],
                                         const long &candidate_horizons[],
                                         const int count,
                                         const int cluster_window_ms,
                                         int &deduplicated_events,
                                         int &symbol_clusters)
  {
   deduplicated_events=0;
   symbol_clusters=0;
   if(count<=0 || cluster_window_ms<0) return;
   long unique[];
   ArrayResize(unique,0);
   for(int i=0;i<count && i<ArraySize(candidate_times) && i<ArraySize(candidate_horizons);++i)
     {
      long value=candidate_times[i];
      bool found=false;
      for(int j=0;j<ArraySize(unique);++j) if(unique[j]==value){found=true;break;}
      if(!found)
        {
         int size=ArraySize(unique);ArrayResize(unique,size+1);unique[size]=value;
        }
     }
   ArraySort(unique);
   deduplicated_events=ArraySize(unique);
   long cluster_start=0;
   for(int i=0;i<ArraySize(unique);++i)
     {
      if(i==0 || unique[i]-cluster_start>(long)cluster_window_ms)
        {
         ++symbol_clusters;
         cluster_start=unique[i];
        }
     }
  }

long TSV1ConfirmedSignalMsc(const long candidate_msc,const long confirmed_msc)
  {
   if(candidate_msc<0 || confirmed_msc<candidate_msc) return 0;
   return confirmed_msc;
  }

#endif
