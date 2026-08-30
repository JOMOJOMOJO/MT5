#ifndef TICK_SHOCK_CONTEXT_FEATURES_MQH
#define TICK_SHOCK_CONTEXT_FEATURES_MQH

#include "TickShockMediumHorizonResponse.mqh"

#define TS15F_BAR_CAPACITY 1024
#define TS15F_FEATURES 36
#define TS15F_DECISIONS 2
#define TS15F_OUTCOMES 3

const int TS15F_DECISION_SECONDS[TS15F_DECISIONS]={60,120};
const int TS15F_OUTCOME_SECONDS[TS15F_OUTCOMES]={300,600,900};
const long TS15F_CONTROL_GRID_MS=900000;
const long TS15F_PURGE_MS=900000;

struct TickShock15FBar
  {long boundary_msc;double open;double high;double low;double close;double spread_sum;long updates;bool fallback;};

struct TickShock15FBarState
  {
   TickShock15FBar bars[TS15F_BAR_CAPACITY];int count;int next;
   bool active;long current_minute;double open;double high;double low;double close;double spread_sum;long updates;bool fallback;
   long server_day;double observed_day_high;double observed_day_low;
  };

struct TickShock15FFeatureSnapshot
  {
   bool recorded;bool valid;long target_msc;long quote_msc;long processing_msc;string reason;
   double bid;double ask;
   double values[TS15F_FEATURES];bool available[TS15F_FEATURES];int usd_pair_count;double usd_factor;
  };

struct TickShock15FEpisodeFeatures
  {string episode_id;string symbol;long market_cluster_id;int direction;long candidate_msc;double severity_ordinal;TickShock15FFeatureSnapshot decisions[TS15F_DECISIONS];bool written;};

struct TickShock15FControl
  {
   bool active;bool invalid;bool write_pending;string control_id;string symbol;long anchor_msc;long processing_msc;int pseudo_direction;
   double anchor_bid;double anchor_ask;TickShock15FFeatureSnapshot decisions[TS15F_DECISIONS];
   bool outcome_valid[TS15F_OUTCOMES];long outcome_quote_msc[TS15F_OUTCOMES];double outcome_bid[TS15F_OUTCOMES];double outcome_ask[TS15F_OUTCOMES];string reason;
  };

struct TickShockContextFeatureState
  {TickShock15FBarState bars;TickShock15FEpisodeFeatures episode;TickShock15FControl control;long control_sequence;long controls_completed;long controls_invalidated;long future_reads;long backdates;};

string TS15FSchema(){return "tickshock-context-feature-v1";}
string TS15FFeatureSpecHash(){return "074C40B21F804CEDB414FA0C75DD1A101B7DF808F6254000B641C134C282B597";}
int TS15FUsdSign(const string symbol){if(symbol=="USDJPY"||symbol=="USDCHF"||symbol=="USDCAD")return 1;if(symbol=="EURUSD"||symbol=="GBPUSD"||symbol=="AUDUSD")return -1;return 0;}
double TS15FContinuationReturn(const int direction,const double entry_bid,const double entry_ask,const double exit_bid,const double exit_ask){if(direction>0)return exit_bid-entry_ask;if(direction<0)return entry_bid-exit_ask;return 0.0;}
double TS15FReversalReturn(const int shock_direction,const double entry_bid,const double entry_ask,const double exit_bid,const double exit_ask){return TS15FContinuationReturn(-shock_direction,entry_bid,entry_ask,exit_bid,exit_ask);}
double TS15FNormalize(const double numerator,const double denominator,bool &valid){valid=MathIsValidNumber(numerator)&&MathIsValidNumber(denominator)&&denominator>0.0;return valid?numerator/denominator:0.0;}
double TS15FRepeatBalance(const long repeats,const long same_direction,const long opposite_direction){long denominator=repeats>0?repeats:1;return (double)(same_direction-opposite_direction)/(double)denominator;}
long TS15FControlAnchorMsc(const long quote_msc){return quote_msc>0?(quote_msc/TS15F_CONTROL_GRID_MS)*TS15F_CONTROL_GRID_MS:0;}
int TS15FPseudoDirection(const double trailing_return){return trailing_return>0?1:(trailing_return<0?-1:0);}

void TS15FResetBarState(TickShock15FBarState &s){ZeroMemory(s);}
void TS15FResetSnapshot(TickShock15FFeatureSnapshot &s){ZeroMemory(s);s.reason="PENDING";}
void TS15FResetEpisode(TickShock15FEpisodeFeatures &e){ZeroMemory(e);for(int i=0;i<TS15F_DECISIONS;++i)TS15FResetSnapshot(e.decisions[i]);}
void TS15FResetControl(TickShock15FControl &c){ZeroMemory(c);for(int i=0;i<TS15F_DECISIONS;++i)TS15FResetSnapshot(c.decisions[i]);}
void TS15FResetContext(TickShockContextFeatureState &s){ZeroMemory(s);TS15FResetBarState(s.bars);TS15FResetEpisode(s.episode);TS15FResetControl(s.control);}

void TS15FStoreBar(TickShock15FBarState &s,const TickShock15FBar &bar)
  {if(bar.boundary_msc<=0||bar.close<=0.0)return;s.bars[s.next]=bar;s.next=(s.next+1)%TS15F_BAR_CAPACITY;if(s.count<TS15F_BAR_CAPACITY)++s.count;}

void TS15FObserveQuote(TickShock15FBarState &s,const long quote_msc,const double bid,const double ask,const bool fallback)
  {
   if(quote_msc<=0||bid<=0.0||ask<bid)return;double mid=(bid+ask)*0.5,spread=ask-bid;long minute=quote_msc/60000,day=minute/1440;
   if(s.server_day!=day){s.server_day=day;s.observed_day_high=mid;s.observed_day_low=mid;}else{s.observed_day_high=MathMax(s.observed_day_high,mid);s.observed_day_low=MathMin(s.observed_day_low,mid);}
   if(!s.active){s.active=true;s.current_minute=minute;s.open=mid;s.high=mid;s.low=mid;s.close=mid;s.spread_sum=spread;s.updates=1;s.fallback=fallback;return;}
   if(minute<s.current_minute)return;
   if(minute==s.current_minute){s.high=MathMax(s.high,mid);s.low=MathMin(s.low,mid);s.close=mid;s.spread_sum+=spread;++s.updates;s.fallback=s.fallback||fallback;return;}
   TickShock15FBar b;b.boundary_msc=(s.current_minute+1)*60000;b.open=s.open;b.high=s.high;b.low=s.low;b.close=s.close;b.spread_sum=s.spread_sum;b.updates=s.updates;b.fallback=s.fallback;TS15FStoreBar(s,b);
   s.current_minute=minute;s.open=mid;s.high=mid;s.low=mid;s.close=mid;s.spread_sum=spread;s.updates=1;s.fallback=fallback;
  }

bool TS15FChronologicalBars(const TickShock15FBarState &s,TickShock15FBar &out[])
  {ArrayResize(out,s.count);int oldest=(s.next-s.count+TS15F_BAR_CAPACITY)%TS15F_BAR_CAPACITY;for(int i=0;i<s.count;++i)out[i]=s.bars[(oldest+i)%TS15F_BAR_CAPACITY];return s.count>0;}

int TS15FAggregateBars(const TickShock15FBarState &s,const int minutes,TickShock15FBar &out[])
  {
   TickShock15FBar src[];if(minutes<=0||!TS15FChronologicalBars(s,src)){ArrayResize(out,0);return 0;}ArrayResize(out,0);int n=ArraySize(src),i=0;
   while(i<n){long group=((src[i].boundary_msc-1)/(60000*minutes));long expected_start=group*minutes*60000;TickShock15FBar a;ZeroMemory(a);int count=0;
      while(i<n&&((src[i].boundary_msc-1)/(60000*minutes))==group){TickShock15FBar b=src[i];if(count==0){a.open=b.open;a.high=b.high;a.low=b.low;}a.high=MathMax(a.high,b.high);a.low=MathMin(a.low,b.low);a.close=b.close;a.spread_sum+=b.spread_sum;a.updates+=b.updates;a.fallback=a.fallback||b.fallback;a.boundary_msc=b.boundary_msc;++count;++i;}
      if(count==minutes&&a.boundary_msc==expected_start+minutes*60000){int k=ArraySize(out);ArrayResize(out,k+1);out[k]=a;}}
   return ArraySize(out);
  }

bool TS15FEMAFromSeries(double &values[],const int period,double &value)
  {value=0.0;int n=ArraySize(values);if(period<=0||n<period)return false;for(int i=0;i<period;++i){if(!MathIsValidNumber(values[i]))return false;value+=values[i];}value/=(double)period;double alpha=2.0/(period+1.0);for(int i=period;i<n;++i){if(!MathIsValidNumber(values[i]))return false;value=alpha*values[i]+(1.0-alpha)*value;}return MathIsValidNumber(value);}

bool TS15FEMA(TickShock15FBar &bars[],const int period,const int end_offset,double &value)
  {int n=ArraySize(bars)-end_offset;if(n<period)return false;double x[];ArrayResize(x,n);for(int i=0;i<n;++i)x[i]=bars[i].close;return TS15FEMAFromSeries(x,period,value);}

bool TS15FATRFromBars(TickShock15FBar &bars[],const int period,double &value)
  {value=0.0;int n=ArraySize(bars);if(period<=0||n<period+1)return false;double atr=0.0;for(int i=1;i<=period;++i){double tr=MathMax(bars[i].high-bars[i].low,MathMax(MathAbs(bars[i].high-bars[i-1].close),MathAbs(bars[i].low-bars[i-1].close)));atr+=tr;}atr/=(double)period;for(int i=period+1;i<n;++i){double tr=MathMax(bars[i].high-bars[i].low,MathMax(MathAbs(bars[i].high-bars[i-1].close),MathAbs(bars[i].low-bars[i-1].close)));atr=((period-1.0)*atr+tr)/(double)period;}value=atr;return MathIsValidNumber(value)&&value>0.0;}

bool TS15FTrailingReturn(TickShock15FBar &bars[],const int bars_back,double &value)
  {value=0.0;int n=ArraySize(bars);if(bars_back<=0||n<=bars_back||bars[n-1-bars_back].close<=0||bars[n-1].close<=0)return false;value=MathLog(bars[n-1].close/bars[n-1-bars_back].close);return MathIsValidNumber(value);}
bool TS15FRealizedVol(TickShock15FBar &bars[],const int returns,double &value)
  {value=0.0;int n=ArraySize(bars);if(returns<=0||n<=returns)return false;double sum=0;for(int i=n-returns;i<n;++i){if(bars[i-1].close<=0||bars[i].close<=0)return false;double r=MathLog(bars[i].close/bars[i-1].close);sum+=r*r;}value=MathSqrt(sum/returns);return MathIsValidNumber(value);}
bool TS15FDailyPosition(const TickShock15FBarState &s,const double mid,double &value){bool valid=false;value=TS15FNormalize(mid-s.observed_day_low,s.observed_day_high-s.observed_day_low,valid);return valid;}

bool TS15FVolatilityPercentile(TickShock15FBar &bars[],const int returns,const int prior_samples,double &value)
  {
   value=0.0;int n=ArraySize(bars);if(returns<=0||prior_samples<=0||n<=returns+1)return false;
   double current=0.0;if(!TS15FRealizedVol(bars,returns,current))return false;
   int first=MathMax(returns,n-1-prior_samples),observed=0,less_or_equal=0;
   for(int endpoint=first;endpoint<n-1;++endpoint)
     {
      double sum=0.0;bool valid=true;
      for(int i=endpoint-returns+1;i<=endpoint;++i)
        {if(i<=0||bars[i-1].close<=0.0||bars[i].close<=0.0){valid=false;break;}double r=MathLog(bars[i].close/bars[i-1].close);if(!MathIsValidNumber(r)){valid=false;break;}sum+=r*r;}
      if(!valid)continue;double historical=MathSqrt(sum/(double)returns);++observed;if(historical<=current)++less_or_equal;
     }
   if(observed<=0)return false;value=(double)less_or_equal/(double)observed;return true;
  }

bool TS15FMedian(double &values[],double &value)
  {int n=ArraySize(values);value=0.0;if(n<=0)return false;double x[];ArrayCopy(x,values);ArraySort(x);value=(n%2==1)?x[n/2]:(x[n/2-1]+x[n/2])*0.5;return true;}
bool TS15FUsdFactor(double &standardized_returns[],int &usd_signs[],double &factor,int &observed)
  {double x[];ArrayResize(x,0);int n=MathMin(ArraySize(standardized_returns),ArraySize(usd_signs));for(int i=0;i<n;++i)if(usd_signs[i]!=0&&MathIsValidNumber(standardized_returns[i])){int k=ArraySize(x);ArrayResize(x,k+1);x[k]=standardized_returns[i]*usd_signs[i];}observed=ArraySize(x);if(observed<3){factor=0;return false;}return TS15FMedian(x,factor);}

void TS15FSet(TickShock15FFeatureSnapshot &s,const int index,const double value,const bool valid){if(index<0||index>=TS15F_FEATURES)return;s.values[index]=valid?value:0.0;s.available[index]=valid;}
void TS15FSetNormalized(TickShock15FFeatureSnapshot &s,const int index,const double numerator,const double denominator,const bool prerequisite)
  {
   double value=0.0;bool valid=false;
   if(prerequisite)value=TS15FNormalize(numerator,denominator,valid);
   TS15FSet(s,index,value,prerequisite&&valid);
  }

bool TS15FBuildFeatures(const TickShock15FBarState &state,const long target_msc,const long quote_msc,const long processing_msc,const double bid,const double ask,const int shock_direction,const double severity,const double initial_shock,const double anchor_spread,const long confirmation_delay_ms,const long repeat_count,const long same_repeats,const long opposite_repeats,const bool origin_recross,const double pre_m1_rms,const double usd_factor,const int usd_sign,const int usd_pairs,TickShock15FFeatureSnapshot &s)
  {
   TS15FResetSnapshot(s);s.recorded=true;s.target_msc=target_msc;s.quote_msc=quote_msc;s.processing_msc=processing_msc;s.bid=bid;s.ask=ask;s.usd_factor=usd_factor;s.usd_pair_count=usd_pairs;if(quote_msc<target_msc){s.reason="BACKDATE";return false;}if(bid<=0||ask<=bid||processing_msc-quote_msc>1000){s.reason="STALE_OR_INVALID_QUOTE";return false;}
   TickShock15FBar m1[],m5[],m15[];TS15FChronologicalBars(state,m1);TS15FAggregateBars(state,5,m5);TS15FAggregateBars(state,15,m15);double mid=(bid+ask)*.5,spread=ask-bid,atr1=0,atr5=0,atr15=0,e20=0,e50=0,e20_3=0,e50_3=0,r1=0,r5=0,r15=0,rv1=0,rv5=0,rv15=0,pos=0,vol_pct=0;bool a1=TS15FATRFromBars(m1,14,atr1),a5=TS15FATRFromBars(m5,14,atr5),a15=TS15FATRFromBars(m15,14,atr15),v20=TS15FEMA(m1,20,0,e20),v50=TS15FEMA(m1,50,0,e50),v203=TS15FEMA(m1,20,3,e20_3),v503=TS15FEMA(m1,50,3,e50_3),vr1=TS15FTrailingReturn(m1,1,r1),vr5=TS15FTrailingReturn(m1,5,r5),vr15=TS15FTrailingReturn(m1,15,r15),vv1=TS15FRealizedVol(m1,1,rv1),vv5=TS15FRealizedVol(m1,5,rv5),vv15=TS15FRealizedVol(m1,15,rv15),vp=TS15FDailyPosition(state,mid,pos),vpercent=TS15FVolatilityPercentile(m1,15,128,vol_pct);double m5e20=0,m5e50=0,m15e20=0,m15e50=0;bool m5a=TS15FEMA(m5,20,0,m5e20)&&TS15FEMA(m5,50,0,m5e50),m15a=TS15FEMA(m15,20,0,m15e20)&&TS15FEMA(m15,50,0,m15e50);
   TS15FSetNormalized(s,0,mid-e20,atr1,v20&&a1);TS15FSetNormalized(s,1,mid-e50,atr1,v50&&a1);TS15FSetNormalized(s,2,e20-e20_3,atr1,v20&&v203&&a1);TS15FSetNormalized(s,3,e50-e50_3,atr1,v50&&v503&&a1);double al1=v20&&v50?(e20>e50?1:(e20<e50?-1:0)):0,al5=m5a?(m5e20>m5e50?1:(m5e20<m5e50?-1:0)):0,al15=m15a?(m15e20>m15e50?1:(m15e20<m15e50?-1:0)):0;TS15FSet(s,4,al1,v20&&v50);TS15FSet(s,5,al5,m5a);TS15FSet(s,6,al15,m15a);TS15FSet(s,7,al5*shock_direction,m5a&&shock_direction!=0);TS15FSet(s,8,al15*shock_direction,m15a&&shock_direction!=0);TS15FSet(s,9,r1,vr1);TS15FSet(s,10,r5,vr5);TS15FSet(s,11,r15,vr15);TS15FSet(s,12,r5*shock_direction,vr5&&shock_direction!=0);
   double eff=0;if(ArraySize(m1)>15){double den=0;for(int i=ArraySize(m1)-15;i<ArraySize(m1);++i)den+=MathAbs(m1[i].close-m1[i-1].close);eff=den>0?MathAbs(m1[ArraySize(m1)-1].close-m1[ArraySize(m1)-16].close)/den:0;}TS15FSet(s,13,eff,ArraySize(m1)>15);TS15FSet(s,14,pos,vp);TS15FSet(s,15,atr1,a1);TS15FSet(s,16,atr5,a5);TS15FSet(s,17,atr15,a15);TS15FSet(s,18,rv1,vv1);TS15FSet(s,19,rv5,vv5);TS15FSet(s,20,rv15,vv15);TS15FSetNormalized(s,21,rv1,rv15,vv1&&vv15);TS15FSetNormalized(s,22,initial_shock,pre_m1_rms*mid,pre_m1_rms>0);TS15FSet(s,23,vol_pct,vpercent);TS15FSet(s,24,spread,true);TS15FSetNormalized(s,25,spread,atr1,a1);TS15FSetNormalized(s,26,spread,pre_m1_rms*mid,pre_m1_rms>0);TS15FSet(s,27,ArraySize(m1)>0?m1[ArraySize(m1)-1].updates:0,ArraySize(m1)>0);TS15FSet(s,28,processing_msc-quote_msc,true);TS15FSet(s,29,severity,true);TS15FSetNormalized(s,30,initial_shock,anchor_spread,true);TS15FSet(s,31,confirmation_delay_ms,confirmation_delay_ms>=0);TS15FSet(s,32,repeat_count,true);TS15FSet(s,33,TS15FRepeatBalance(repeat_count,same_repeats,opposite_repeats),true);TS15FSet(s,34,origin_recross?1:0,true);double usd_alignment=usd_factor>0?1:(usd_factor<0?-1:0);TS15FSet(s,35,usd_alignment*(double)usd_sign*(double)shock_direction,usd_pairs>=3&&usd_sign!=0&&shock_direction!=0);s.valid=true;for(int i=0;i<TS15F_FEATURES;++i)if(!s.available[i]){s.valid=false;break;}s.reason=s.valid?"AVAILABLE":"FEATURE_UNAVAILABLE";return s.valid;
  }

void TS15FObserveControl(TickShockContextFeatureState &s,const string run_id,const string symbol,const long quote_msc,const long processing_msc,const double bid,const double ask,const bool shock_active)
  {
   TickShock15FControl c=s.control;if(c.active&&shock_active){c.invalid=true;c.reason="SHOCK_PURGE";c.write_pending=true;c.active=false;++s.controls_invalidated;s.control=c;return;}
   if(c.active){for(int i=0;i<TS15F_OUTCOMES;++i)if(!c.outcome_valid[i]&&quote_msc>=c.anchor_msc+(long)TS15F_OUTCOME_SECONDS[i]*1000){c.outcome_valid[i]=true;c.outcome_quote_msc[i]=quote_msc;c.outcome_bid[i]=bid;c.outcome_ask[i]=ask;}if(quote_msc>=c.anchor_msc+900000){c.active=false;c.write_pending=true;++s.controls_completed;}s.control=c;return;}
   long grid=TS15FControlAnchorMsc(quote_msc);if(shock_active||quote_msc-grid>1000||grid<=0)return;TickShock15FBar bars[];TS15FChronologicalBars(s.bars,bars);double r5=0;if(ArraySize(bars)<750||!TS15FTrailingReturn(bars,5,r5)||TS15FPseudoDirection(r5)==0)return;TS15FResetControl(c);c.active=true;c.control_id=StringFormat("%s_%s_ctrl_%I64d",run_id,symbol,++s.control_sequence);c.symbol=symbol;c.anchor_msc=grid;c.processing_msc=processing_msc;c.pseudo_direction=TS15FPseudoDirection(r5);c.anchor_bid=bid;c.anchor_ask=ask;c.reason="ACTIVE";s.control=c;
  }

#endif
