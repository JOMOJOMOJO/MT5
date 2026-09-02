#ifndef TICK_SHOCK_DETECTION_TIME_CONTINUATION_MQH
#define TICK_SHOCK_DETECTION_TIME_CONTINUATION_MQH

#include "TickShockContextFeatures.mqh"
#include "TickShockEconomicPath.mqh"

#define TS15H_FEATURES 12
#define TS15H_DELAYS 3
#define TS15H_HORIZONS 3
#define TS15H_PATHS 9

const int TS15H_DELAY_MS[TS15H_DELAYS]={0,100,250};
const int TS15H_HORIZON_SECONDS[TS15H_HORIZONS]={300,600,900};

struct TickShock15HSnapshot
  {
   bool recorded;bool feature_valid;bool outcome_armed;bool write_pending;bool written;bool fallback_anchor;
   string episode_id;string event_id;string symbol;string last_written_episode_id;long market_cluster_id;int direction;
   long candidate_msc;long confirmed_msc;long confirmed_quote_msc;long processed_msc;long t0_msc;long t0_sequence;
   long quote_age_ms;double t0_bid;double t0_ask;double t0_mid;double atr14_m5;double broker_stop_distance;double tick_size;
   double features[TS15H_FEATURES];bool available[TS15H_FEATURES];long feature_source_msc[TS15H_FEATURES];string missing_reason;
   TickShock15GPath paths[TS15H_PATHS];long future_reads;long backdates;long duplicate_writes;
  };

string TS15HSchema(){return "tickshock-detection-time-continuation-v1";}
string TS15HSpecHash(){return "C823613E909385DA3A8A5E4FF34055CFEF91EA2F9E405159FB748205684E418A";}
string TS15HFeatureHash(){return "B2F2DA41E8BF0B9F1EFDA97660FC75C873AA744D49F8BA21C5F4F992A80B8B17";}
int TS15HPathIndex(const int delay_index,const int horizon_index){return delay_index*TS15H_HORIZONS+horizon_index;}

void TS15HReset(TickShock15HSnapshot &s)
  {ZeroMemory(s);s.missing_reason="PENDING";for(int i=0;i<TS15H_PATHS;++i)TS15GResetPath(s.paths[i]);}

void TS15HResetAfterWrite(TickShock15HSnapshot &s)
  {string last=s.episode_id;TS15HReset(s);s.last_written_episode_id=last;}

void TS15HSetFeature(TickShock15HSnapshot &s,const int index,const double value,const bool valid,const long source_msc)
  {if(index<0||index>=TS15H_FEATURES)return;s.features[index]=valid?value:0.0;s.available[index]=valid;s.feature_source_msc[index]=valid?source_msc:0;}

bool TS15HBuildCausalFeatures(const TickShock15FBarState &bars,
                              const long t0_msc,const double bid,const double ask,const int direction,
                              const double tick_activity_ratio,const double detection_efficiency,const double severity,
                              const double candidate_anchor_mid,const double candidate_mid,const double confirmed_mid,
                              TickShock15HSnapshot &s)
  {
   if(t0_msc<=0||bid<=0.0||ask<=bid||direction==0){s.missing_reason="INVALID_T0";return false;}
   TickShock15FBar m1[],m5[],m15[];TS15FChronologicalBars(bars,m1);TS15FAggregateBars(bars,5,m5);TS15FAggregateBars(bars,15,m15);
   double atr5=0.0,atr15=0.0;bool a5=TS15FATRFromBars(m5,14,atr5),a15=TS15FATRFromBars(m15,14,atr15);
   s.atr14_m5=a5?atr5:0.0;double spread=ask-bid;
   TS15HSetFeature(s,0,a5?spread/atr5:0.0,a5,t0_msc);
   TS15HSetFeature(s,1,tick_activity_ratio,MathIsValidNumber(tick_activity_ratio)&&tick_activity_ratio>=0.0,t0_msc);
   int n1=ArraySize(m1);double r5=0.0,r15=0.0;bool pr5=n1>5&&a5,pr15=n1>15&&a15;
   if(pr5)r5=(m1[n1-1].close-m1[n1-6].close)*(double)direction/atr5;
   if(pr15)r15=(m1[n1-1].close-m1[n1-16].close)*(double)direction/atr15;
   long last_bar_msc=n1>0?m1[n1-1].boundary_msc:0;
   TS15HSetFeature(s,2,r5,pr5,last_bar_msc);
   double m5e20=0.0,m5e20_3=0.0;bool m5s=a5&&TS15FEMA(m5,20,0,m5e20)&&TS15FEMA(m5,20,3,m5e20_3);
   TS15HSetFeature(s,3,m5s?(m5e20-m5e20_3)*(double)direction/atr5:0.0,m5s,last_bar_msc);
   double m15e20=0.0,m15e50=0.0;bool m15a=TS15FEMA(m15,20,0,m15e20)&&TS15FEMA(m15,50,0,m15e50);
   double alignment=m15a?(m15e20>m15e50?1.0:(m15e20<m15e50?-1.0:0.0))*(double)direction:0.0;
   TS15HSetFeature(s,4,alignment,m15a,last_bar_msc);
   TS15HSetFeature(s,5,r15,pr15,last_bar_msc);
   double day_position=0.0;bool day_ok=TS15FDailyPosition(bars,(bid+ask)*0.5,day_position);
   TS15HSetFeature(s,6,day_ok?(2.0*day_position-1.0)*(double)direction:0.0,day_ok,t0_msc);
   TS15HSetFeature(s,7,detection_efficiency,MathIsValidNumber(detection_efficiency)&&detection_efficiency>=0.0&&detection_efficiency<=1.0,t0_msc);
   TS15HSetFeature(s,8,severity,MathIsValidNumber(severity)&&severity>=0.0,t0_msc);
   double candidate_move=MathAbs(candidate_mid-candidate_anchor_mid);bool retain_ok=candidate_move>0.0&&MathIsValidNumber(confirmed_mid);
   TS15HSetFeature(s,9,retain_ok?(confirmed_mid-candidate_anchor_mid)*(double)direction/candidate_move:0.0,retain_ok,t0_msc);
   TS15HSetFeature(s,10,s.features[0]*s.features[7],s.available[0]&&s.available[7],t0_msc);
   TS15HSetFeature(s,11,s.features[2]*s.features[7],s.available[2]&&s.available[7],t0_msc);
   s.feature_valid=true;for(int i=0;i<TS15H_FEATURES;++i)if(!s.available[i]||s.feature_source_msc[i]>t0_msc){s.feature_valid=false;break;}
   s.missing_reason=s.feature_valid?"AVAILABLE":"FEATURE_MISSING";return s.feature_valid;
  }

bool TS15HArm(TickShock15HSnapshot &s,const TickShock15FBarState &bars,
              const string episode_id,const string event_id,const string symbol,const long market_cluster_id,const int direction,
              const long candidate_msc,const long confirmed_msc,const long confirmed_quote_msc,const long processed_msc,const long sequence,
              const double bid,const double ask,const double tick_size,const double broker_stop_distance,const bool fallback,
              const double tick_activity_ratio,const double detection_efficiency,const double severity,
              const double candidate_anchor_mid,const double candidate_mid,const double confirmed_mid)
  {
   if(s.written)TS15HResetAfterWrite(s);
   if(s.recorded||episode_id==""||episode_id==s.last_written_episode_id||event_id==""||symbol==""||direction==0||candidate_msc<=0||confirmed_msc<candidate_msc||processed_msc<confirmed_msc||confirmed_quote_msc>confirmed_msc||bid<=0.0||ask<=bid||tick_size<=0.0)return false;
   string last=s.last_written_episode_id;TS15HReset(s);s.last_written_episode_id=last;s.recorded=true;s.episode_id=episode_id;s.event_id=event_id;s.symbol=symbol;s.market_cluster_id=market_cluster_id;s.direction=direction>0?1:-1;
   s.candidate_msc=candidate_msc;s.confirmed_msc=confirmed_msc;s.confirmed_quote_msc=confirmed_quote_msc;s.processed_msc=processed_msc;s.t0_msc=processed_msc;s.t0_sequence=sequence;
   s.quote_age_ms=processed_msc-confirmed_quote_msc;s.t0_bid=bid;s.t0_ask=ask;s.t0_mid=(bid+ask)*0.5;s.tick_size=tick_size;s.broker_stop_distance=MathMax(0.0,broker_stop_distance);s.fallback_anchor=fallback;
   TS15HBuildCausalFeatures(bars,s.t0_msc,bid,ask,s.direction,tick_activity_ratio,detection_efficiency,severity,candidate_anchor_mid,candidate_mid,confirmed_mid,s);
   for(int d=0;d<TS15H_DELAYS;++d)for(int h=0;h<TS15H_HORIZONS;++h)
     {
      int index=TS15HPathIndex(d,h);TickShock15GPath p;TS15GResetPath(p);p.armed=true;p.action=TS15G_CONTINUATION;p.direction=s.direction;p.rr_index=1;p.horizon_index=h;
      p.anchor_msc=s.t0_msc;p.signal_quote_msc=confirmed_quote_msc;p.signal_processing_msc=s.t0_msc+(long)TS15H_DELAY_MS[d];p.horizon_msc=s.t0_msc+(long)TS15H_HORIZON_SECONDS[h]*1000;
      p.atr14_m5=s.atr14_m5;p.tick_size=tick_size;p.broker_stop_distance=s.broker_stop_distance;s.paths[index]=p;
     }
   s.outcome_armed=true;return true;
  }

void TS15HObserve(TickShock15HSnapshot &s,const long quote_msc,const long processing_msc,const double bid,const double ask,const bool fallback)
  {
   if(!s.recorded||s.written||!s.outcome_armed)return;if(processing_msc<s.t0_msc){++s.backdates;return;}
   for(int i=0;i<TS15H_PATHS;++i)TS15GObservePath(s.paths[i],quote_msc,processing_msc,bid,ask,fallback);
   bool done=true;for(int i=0;i<TS15H_PATHS;++i)done=done&&s.paths[i].done;if(done)s.write_pending=true;
  }

void TS15HFinalize(TickShock15HSnapshot &s,const string reason)
  {if(!s.recorded||s.written)return;for(int i=0;i<TS15H_PATHS;++i){if(s.paths[i].pending_touch)TS15GFinalizePendingTouch(s.paths[i]);if(!s.paths[i].done)TS15GInvalidate(s.paths[i],reason);}s.write_pending=true;}

double TS15HPolicyValue(const bool &selected[],const double &returns[],int &eligible)
  {eligible=MathMin(ArraySize(selected),ArraySize(returns));if(eligible<=0)return 0.0;double sum=0.0;for(int i=0;i<eligible;++i)if(selected[i])sum+=returns[i];return sum/(double)eligible;}
bool TS15HFoldSupport(const int eligible,const int selected){return eligible>=200&&selected>=25;}
bool TS15HFeatureSourcesCausal(const TickShock15HSnapshot &s){for(int i=0;i<TS15H_FEATURES;++i)if(s.available[i]&&s.feature_source_msc[i]>s.t0_msc)return false;return true;}
long TS15HResearchOrderCalls(){return 0;}

#endif
