#ifndef TICK_SHOCK_CLEAN_MOVE_FEATURES_MQH
#define TICK_SHOCK_CLEAN_MOVE_FEATURES_MQH

#include "TickShockContextFeatures.mqh"

#define TS15L_SECOND_CAPACITY 901
#define TS15L_FEATURES 38

struct TickShock15LSecond
  {
   long second_msc;
   long quote_msc;
   double mid;
   double spread;
   double high;
   double low;
   int ticks;
  };

struct TickShock15LState
  {
   TickShock15LSecond seconds[TS15L_SECOND_CAPACITY];
   int count;
   int next;
   TickShock15LSecond current;
   bool current_active;
   long quotes;
  };

struct TickShock15LSnapshot
  {
   bool recorded;
   string episode_id;
   string event_id;
   string symbol;
   long market_cluster_id;
   int direction;
   long t0_msc;
   long t0_quote_msc;
   double t0_mid;
   double atr14_m5;
   double values[TS15L_FEATURES];
   long source_msc[TS15L_FEATURES];
   bool available[TS15L_FEATURES];
   int available_count;
   long future_sources;
  };

string TS15LSchema(){return "tickshock-clean-move-causal-feature-v1";}
string TS15LFeatureSpecHash(){return "48B8F98EF55B57063E6977A18402955D8C2926029B1F8BDB91038FF4169C18CE";}

string TS15LFeatureName(const int index)
  {
   const string names[TS15L_FEATURES]={
      "return_5s_dir_atr","return_10s_dir_atr","return_30s_dir_atr","return_60s_dir_atr","return_120s_dir_atr","return_300s_dir_atr","return_900s_dir_atr",
      "spread_5s_atr","spread_10s_atr","spread_30s_atr","spread_change_5s_atr","spread_change_10s_atr","spread_change_30s_atr",
      "ticks_5s","ticks_10s","ticks_30s","ticks_60s","ticks_120s","tick_ratio_5s_prev5s","tick_ratio_30s_prev30s",
      "range_30s_atr","range_60s_atr","range_180s_atr","range_300s_atr","range_900s_atr","range_1800s_atr","range_3600s_atr",
      "realized_abs_30s_atr","realized_abs_60s_atr","realized_abs_180s_atr","realized_abs_300s_atr",
      "accel_10s_vs_prev30s","return_30s_vs_prev30s","direction_consistency_30s",
      "range_position_900s_dir","distance_high_900s_dir_atr","distance_low_900s_dir_atr","atr14_m5_slope_3bars"};
   return index>=0&&index<TS15L_FEATURES?names[index]:"INVALID";
  }

void TS15LResetState(TickShock15LState &state){ZeroMemory(state);}
void TS15LResetSnapshot(TickShock15LSnapshot &snapshot){ZeroMemory(snapshot);}

void TS15LStoreSecond(TickShock15LState &state,const TickShock15LSecond &sample)
  {
   if(sample.quote_msc<=0||sample.mid<=0.0||sample.spread<0.0||sample.ticks<=0)return;
   state.seconds[state.next]=sample;
   state.next=(state.next+1)%TS15L_SECOND_CAPACITY;
   if(state.count<TS15L_SECOND_CAPACITY)++state.count;
  }

void TS15LObserveQuote(TickShock15LState &state,const long quote_msc,const double bid,const double ask)
  {
   if(quote_msc<=0||bid<=0.0||ask<=bid)return;
   long second_msc=(quote_msc/1000)*1000;double mid=(bid+ask)*0.5,spread=ask-bid;
   if(!state.current_active||second_msc!=state.current.second_msc)
     {
      if(state.current_active)TS15LStoreSecond(state,state.current);
      ZeroMemory(state.current);state.current_active=true;state.current.second_msc=second_msc;state.current.quote_msc=quote_msc;
      state.current.mid=mid;state.current.spread=spread;state.current.high=mid;state.current.low=mid;state.current.ticks=1;
     }
   else
     {
      state.current.quote_msc=quote_msc;state.current.mid=mid;state.current.spread=spread;
      state.current.high=MathMax(state.current.high,mid);state.current.low=MathMin(state.current.low,mid);++state.current.ticks;
     }
   ++state.quotes;
  }

int TS15LChronological(const TickShock15LState &state,TickShock15LSecond &out[])
  {
   int extra=state.current_active?1:0;ArrayResize(out,state.count+extra);int oldest=(state.next-state.count+TS15L_SECOND_CAPACITY)%TS15L_SECOND_CAPACITY;
   for(int i=0;i<state.count;++i)out[i]=state.seconds[(oldest+i)%TS15L_SECOND_CAPACITY];
   if(extra>0)out[state.count]=state.current;
   return ArraySize(out);
  }

bool TS15LAnchor(TickShock15LSecond &samples[],const long target_msc,TickShock15LSecond &anchor)
  {
   for(int i=ArraySize(samples)-1;i>=0;--i)if(samples[i].quote_msc<=target_msc){anchor=samples[i];return true;}
   return false;
  }

int TS15LTickCount(TickShock15LSecond &samples[],const long after_msc,const long through_msc)
  {int total=0;for(int i=0;i<ArraySize(samples);++i)if(samples[i].quote_msc>after_msc&&samples[i].quote_msc<=through_msc)total+=samples[i].ticks;return total;}

bool TS15LRange(TickShock15LSecond &samples[],const long after_msc,const long through_msc,double &low,double &high,long &source_msc)
  {
   bool found=false;low=0.0;high=0.0;source_msc=0;
   for(int i=0;i<ArraySize(samples);++i)if(samples[i].quote_msc>after_msc&&samples[i].quote_msc<=through_msc)
     {if(!found){low=samples[i].low;high=samples[i].high;found=true;}else{low=MathMin(low,samples[i].low);high=MathMax(high,samples[i].high);}source_msc=MathMax(source_msc,samples[i].quote_msc);}
   return found&&high>=low;
  }

bool TS15LRealizedAbs(TickShock15LSecond &samples[],const long after_msc,const long through_msc,double &value,long &source_msc)
  {
   bool found=false;double previous=0.0;value=0.0;source_msc=0;
   for(int i=0;i<ArraySize(samples);++i)if(samples[i].quote_msc>after_msc&&samples[i].quote_msc<=through_msc)
     {if(found)value+=MathAbs(samples[i].mid-previous);previous=samples[i].mid;source_msc=samples[i].quote_msc;found=true;}
   return found;
  }

void TS15LSet(TickShock15LSnapshot &snapshot,const int index,const double value,const bool valid,const long source_msc)
  {
   if(index<0||index>=TS15L_FEATURES)return;snapshot.values[index]=valid?value:0.0;snapshot.available[index]=valid;snapshot.source_msc[index]=valid?source_msc:0;
   if(valid){++snapshot.available_count;if(source_msc>snapshot.t0_msc)++snapshot.future_sources;}
  }

bool TS15LReturn(TickShock15LSecond &samples[],const long t0_msc,const long lookback_ms,const double current_mid,const double atr,const int direction,double &value,long &source_msc)
  {
   TickShock15LSecond anchor;if(atr<=0.0||direction==0||!TS15LAnchor(samples,t0_msc-lookback_ms,anchor)){value=0.0;source_msc=0;return false;}
   value=(current_mid-anchor.mid)*(double)direction/atr;source_msc=anchor.quote_msc;return MathIsValidNumber(value);
  }

bool TS15LBarRange(const TickShock15FBarState &bars,const long t0_msc,const long lookback_ms,const double current_mid,double &low,double &high,long &source_msc)
  {
   TickShock15FBar m1[];TS15FChronologicalBars(bars,m1);bool found=false;low=current_mid;high=current_mid;source_msc=0;
   for(int i=0;i<ArraySize(m1);++i)if(m1[i].boundary_msc<=t0_msc&&m1[i].boundary_msc>t0_msc-lookback_ms)
     {low=MathMin(low,m1[i].low);high=MathMax(high,m1[i].high);source_msc=MathMax(source_msc,m1[i].boundary_msc);found=true;}
   return found&&high>=low;
  }

bool TS15LATRAtOffset(const TickShock15FBarState &bars,const int offset,double &atr,long &source_msc)
  {
   TickShock15FBar m5[];TS15FAggregateBars(bars,5,m5);int size=ArraySize(m5)-offset;if(size<15){atr=0.0;source_msc=0;return false;}
   TickShock15FBar subset[];ArrayResize(subset,size);for(int i=0;i<size;++i)subset[i]=m5[i];source_msc=subset[size-1].boundary_msc;return TS15FATRFromBars(subset,14,atr);
  }

bool TS15LBuildSnapshot(const TickShock15LState &state,const TickShock15FBarState &bars,
                        const string episode_id,const string event_id,const string symbol,const long market_cluster_id,
                        const int direction,const long t0_msc,const double atr14_m5,TickShock15LSnapshot &snapshot)
  {
   TS15LResetSnapshot(snapshot);if(episode_id==""||event_id==""||symbol==""||direction==0||t0_msc<=0||atr14_m5<=0.0)return false;
   TickShock15LSecond samples[];if(TS15LChronological(state,samples)<=0)return false;TickShock15LSecond now;if(!TS15LAnchor(samples,t0_msc,now))return false;
   snapshot.recorded=true;snapshot.episode_id=episode_id;snapshot.event_id=event_id;snapshot.symbol=symbol;snapshot.market_cluster_id=market_cluster_id;snapshot.direction=direction>0?1:-1;snapshot.t0_msc=t0_msc;snapshot.t0_quote_msc=now.quote_msc;snapshot.t0_mid=now.mid;snapshot.atr14_m5=atr14_m5;
   const int return_seconds[7]={5,10,30,60,120,300,900};double returns[7];long return_sources[7];bool return_ok[7];
   for(int i=0;i<7;++i){return_ok[i]=TS15LReturn(samples,t0_msc,(long)return_seconds[i]*1000,now.mid,atr14_m5,snapshot.direction,returns[i],return_sources[i]);TS15LSet(snapshot,i,returns[i],return_ok[i],return_sources[i]);}
   const int spread_seconds[3]={5,10,30};double current_spread=now.spread;
   for(int i=0;i<3;++i){TickShock15LSecond anchor;bool ok=TS15LAnchor(samples,t0_msc-(long)spread_seconds[i]*1000,anchor);TS15LSet(snapshot,7+i,ok?anchor.spread/atr14_m5:0.0,ok,ok?anchor.quote_msc:0);TS15LSet(snapshot,10+i,ok?(current_spread-anchor.spread)/atr14_m5:0.0,ok,ok?MathMax(anchor.quote_msc,now.quote_msc):0);}
   const int tick_seconds[5]={5,10,30,60,120};int tick_counts[5];for(int i=0;i<5;++i){tick_counts[i]=TS15LTickCount(samples,t0_msc-(long)tick_seconds[i]*1000,t0_msc);TS15LSet(snapshot,13+i,(double)tick_counts[i],true,now.quote_msc);}
   int previous5=TS15LTickCount(samples,t0_msc-10000,t0_msc-5000),previous30=TS15LTickCount(samples,t0_msc-60000,t0_msc-30000);
   TS15LSet(snapshot,18,previous5>0?(double)tick_counts[0]/(double)previous5:0.0,previous5>0,now.quote_msc);TS15LSet(snapshot,19,previous30>0?(double)tick_counts[2]/(double)previous30:0.0,previous30>0,now.quote_msc);
   const int range_seconds[7]={30,60,180,300,900,1800,3600};double range_low[7],range_high[7];long range_source[7];bool range_ok[7];
   for(int i=0;i<7;++i){range_ok[i]=i<5?TS15LRange(samples,t0_msc-(long)range_seconds[i]*1000,t0_msc,range_low[i],range_high[i],range_source[i]):TS15LBarRange(bars,t0_msc,(long)range_seconds[i]*1000,now.mid,range_low[i],range_high[i],range_source[i]);TS15LSet(snapshot,20+i,range_ok[i]?(range_high[i]-range_low[i])/atr14_m5:0.0,range_ok[i],range_source[i]);}
   const int realized_seconds[4]={30,60,180,300};for(int i=0;i<4;++i){double rv=0.0;long src=0;bool ok=TS15LRealizedAbs(samples,t0_msc-(long)realized_seconds[i]*1000,t0_msc,rv,src);TS15LSet(snapshot,27+i,ok?rv/atr14_m5:0.0,ok,src);}
   double r_prev30=0.0,r_prev30b=0.0;long src=0,srcb=0;TickShock15LSecond a10,a40,a30,a60;bool a10ok=TS15LAnchor(samples,t0_msc-10000,a10),a40ok=TS15LAnchor(samples,t0_msc-40000,a40),a30ok=TS15LAnchor(samples,t0_msc-30000,a30),a60ok=TS15LAnchor(samples,t0_msc-60000,a60);
   if(a10ok&&a40ok){r_prev30=(a10.mid-a40.mid)*(double)snapshot.direction/atr14_m5;src=MathMax(a10.quote_msc,a40.quote_msc);}if(a30ok&&a60ok){r_prev30b=(a30.mid-a60.mid)*(double)snapshot.direction/atr14_m5;srcb=MathMax(a30.quote_msc,a60.quote_msc);}
   TS15LSet(snapshot,31,return_ok[1]&&a10ok&&a40ok?returns[1]-r_prev30:0.0,return_ok[1]&&a10ok&&a40ok,MathMax(return_sources[1],src));
   TS15LSet(snapshot,32,return_ok[2]&&a30ok&&a60ok?returns[2]-r_prev30b:0.0,return_ok[2]&&a30ok&&a60ok,MathMax(return_sources[2],srcb));
   int directional=0,moves=0;double previous=0.0;bool have=false;long consistency_source=0;for(int i=0;i<ArraySize(samples);++i)if(samples[i].quote_msc>t0_msc-30000&&samples[i].quote_msc<=t0_msc){if(have){double move=(samples[i].mid-previous)*(double)snapshot.direction;if(move>0.0)++directional;if(move!=0.0)++moves;}previous=samples[i].mid;have=true;consistency_source=samples[i].quote_msc;}
   TS15LSet(snapshot,33,moves>0?(double)directional/(double)moves:0.0,moves>0,consistency_source);
   bool structure_ok=range_ok[4]&&range_high[4]>range_low[4];double position=structure_ok?(now.mid-range_low[4])/(range_high[4]-range_low[4]):0.0;TS15LSet(snapshot,34,structure_ok?(2.0*position-1.0)*(double)snapshot.direction:0.0,structure_ok,range_source[4]);TS15LSet(snapshot,35,structure_ok?(range_high[4]-now.mid)*(double)snapshot.direction/atr14_m5:0.0,structure_ok,range_source[4]);TS15LSet(snapshot,36,structure_ok?(now.mid-range_low[4])*(double)snapshot.direction/atr14_m5:0.0,structure_ok,range_source[4]);
   double atr_now=0.0,atr_prev3=0.0;long atr_src=0,atr_prev_src=0;bool atr_now_ok=TS15LATRAtOffset(bars,0,atr_now,atr_src),atr_prev_ok=TS15LATRAtOffset(bars,3,atr_prev3,atr_prev_src);TS15LSet(snapshot,37,atr_now_ok&&atr_prev_ok&&atr_prev3>0.0?(atr_now-atr_prev3)/atr_prev3:0.0,atr_now_ok&&atr_prev_ok&&atr_prev3>0.0,MathMax(atr_src,atr_prev_src));
   return snapshot.recorded&&snapshot.future_sources==0;
  }

bool TS15LFeatureSourcesCausal(const TickShock15LSnapshot &snapshot)
  {for(int i=0;i<TS15L_FEATURES;++i)if(snapshot.available[i]&&snapshot.source_msc[i]>snapshot.t0_msc)return false;return snapshot.future_sources==0;}

long TS15LResearchOrderCalls(){return 0;}

#endif
