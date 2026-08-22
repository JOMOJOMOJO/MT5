#ifndef TICK_SHOCK_DETECTOR_MQH
#define TICK_SHOCK_DETECTOR_MQH

#include "TickShockConfig.mqh"

bool TSFixedLogMidReturn(const double newer_mid,const double older_mid,double &result)
  {
   result=0.0;
   if(newer_mid<=0.0 || older_mid<=0.0) return false;
   result=MathLog(newer_mid/older_mid);
   if(!MathIsValidNumber(result))
     {
      result=0.0;
      return false;
     }
   return true;
  }

bool TSFixedMidMove(const double newer_mid,const double older_mid,double &signed_move,double &absolute_move)
  {
   signed_move=0.0;
   absolute_move=0.0;
   if(newer_mid<=0.0 || older_mid<=0.0) return false;
   signed_move=newer_mid-older_mid;
   absolute_move=MathAbs(signed_move);
   if(!MathIsValidNumber(signed_move) || !MathIsValidNumber(absolute_move))
     {
      signed_move=0.0;
      absolute_move=0.0;
      return false;
     }
   return true;
  }

bool TSExactAnchorTime(const long required_msc,const long available_msc)
  {
   return required_msc==available_msc;
  }

bool TSDetectorBoundary(const long boundary_msc,const int detector_window_ms)
  {
   return detector_window_ms>0 && boundary_msc%detector_window_ms==0;
  }

double TSRobustScaleWithNoiseFloor(const double mad_absolute_move,const double noise_floor_move,bool &floored)
  {
   double raw_scale=1.4826*MathMax(0.0,mad_absolute_move);
   double noise=MathMax(0.0,noise_floor_move);
   floored=raw_scale<noise;
   return MathMax(raw_scale,noise);
  }

void TSEvaluateDetectorGates(const double move,
                             const double percentile_threshold,
                             const double robust_z,
                             const double efficiency,
                             const double move_spread_ratio,
                             const double tick_intensity_ratio,
                             const double spread_ratio,
                             const TickShockConfig &config,
                             TickShockDetectorResult &result)
  {
   result.gates[0]=move>=percentile_threshold;
   result.gates[1]=robust_z>=config.min_robust_z;
   result.gates[2]=efficiency>=config.min_efficiency;
   result.gates[3]=tick_intensity_ratio>=config.min_tick_intensity_ratio;
   result.gates[4]=move_spread_ratio>=config.min_move_spread_ratio;
   result.gates[5]=spread_ratio<=config.max_spread_median_ratio;
   result.gate_mask=0;
   for(int i=0;i<TS_CORE_GATE_COUNT;++i)
      if(result.gates[i]) result.gate_mask|=(1<<i);
   result.reject=TS_DETECTOR_ACCEPT;
   if(!result.gates[0]) result.reject=TS_DETECTOR_REJECT_PERCENTILE;
   else if(!result.gates[1]) result.reject=TS_DETECTOR_REJECT_ROBUST_Z;
   else if(!result.gates[2]) result.reject=TS_DETECTOR_REJECT_EFFICIENCY;
   else if(!result.gates[3]) result.reject=TS_DETECTOR_REJECT_INTENSITY;
   else if(!result.gates[4]) result.reject=TS_DETECTOR_REJECT_MOVE_SPREAD;
   else if(!result.gates[5]) result.reject=TS_DETECTOR_REJECT_SPREAD;
   result.accepted=result.reject==TS_DETECTOR_ACCEPT;
  }

bool TSShockConditionsPass(const double move,
                           const double percentile_threshold,
                           const double robust_z,
                           const double efficiency,
                           const double move_spread_ratio,
                           const double tick_intensity_ratio,
                           const double spread_ratio,
                           const double min_robust_z,
                           const double min_efficiency,
                           const double min_move_spread_ratio,
                           const double min_tick_intensity_ratio,
                           const double max_spread_ratio,
                           string &reason)
  {
   reason="";
   if(move<percentile_threshold) reason="shock_percentile_failed";
   else if(robust_z<min_robust_z) reason="shock_z_failed";
   else if(efficiency<min_efficiency) reason="efficiency_failed";
   else if(tick_intensity_ratio<min_tick_intensity_ratio) reason="tick_intensity_failed";
   else if(move_spread_ratio<min_move_spread_ratio) reason="move_spread_failed";
   else if(spread_ratio>max_spread_ratio) reason="spread_too_wide";
   return reason=="";
  }

bool TSResearchExactLogReturn(const long event_msc,
                              const double event_mid,
                              const int window_ms,
                              const long anchor_msc,
                              const double anchor_mid,
                              double &result)
  {
   result=0.0;
   if(window_ms<=0 || event_mid<=0.0 || anchor_mid<=0.0 ||
      anchor_msc!=event_msc-(long)window_ms) return false;
   result=MathLog(event_mid/anchor_mid);
   if(!MathIsValidNumber(result))
     {
      result=0.0;
      return false;
     }
   return true;
  }

#endif
