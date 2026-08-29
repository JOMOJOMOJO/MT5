#ifndef TICK_SHOCK_STATE_CONDITIONED_RESPONSE_MQH
#define TICK_SHOCK_STATE_CONDITIONED_RESPONSE_MQH

#include "TickShockEventResponse.mqh"
#include "TickShockStatisticalDetector.mqh"

#define TS15D_FIXED_CHECKPOINTS 3
#define TS15D_CHECKPOINTS 7
#define TS15D_STRATEGIES 4
#define TS15D_INTERVAL_CAPACITY 64

const int TS15D_FIXED_OFFSETS_MS[TS15D_FIXED_CHECKPOINTS]={500,1000,3000};
const double TS15D_BARRIERS[3]={0.5,1.0,2.0};

enum ENUM_TS15D_AVAILABILITY { TS15D_PENDING=0,TS15D_AVAILABLE,TS15D_STALE,TS15D_MISSING };
enum ENUM_TS15D_PATH_CLASS { TS15D_CLASS_UNAVAILABLE=0,TS15D_CLEAN_CONTINUATION,TS15D_PULLBACK_CONTINUATION,TS15D_FAILED_SHOCK_REVERSAL,TS15D_TWO_SIDED_WHIPSAW,TS15D_DEAD_OR_TIMEOUT };
enum ENUM_TS15D_EXEC_RESULT { TS15D_EXEC_NONE=0,TS15D_EXEC_CONTINUATION,TS15D_EXEC_REVERSAL,TS15D_EXEC_AMBIGUOUS,TS15D_EXEC_TIMEOUT,TS15D_EXEC_CENSORED };

struct TickShock15DCheckpoint
  {
   bool recorded;int index;string name;long target_msc;long decision_quote_msc;long processing_msc;long target_lag_ms;long quote_age_ms;ENUM_TS15D_AVAILABILITY availability;
   double bid;double ask;double mid;double current_displacement;double max_extension;double max_retracement;double extension_ratio;double retracement_ratio;
   int origin_relation;bool origin_recross;long first_origin_recross_msc;long time_since_recross_ms;long origin_recross_count;long directional_extreme_count;long reversal_extreme_count;
   long nonzero_updates;long positive_updates;long negative_updates;long equal_updates;double directional_imbalance;long longest_run;long current_run;double median_interval_ms;long latest_interval_ms;
   double activity_ratio;double spread;double spread_confirmed_ratio;double realized_range;double realized_volatility;bool integrity_ok;
  };

struct TickShock15DStrategyPath
  {
   bool armed;bool entered;bool complete;int strategy;int direction;long signal_msc;long processing_msc;long eligible_msc;long entry_quote_msc;double entry_bid;double entry_ask;double entry_price;double local_scale;
   double mfe;double mae;long time_to_mfe_ms;long time_to_mae_ms;ENUM_TS15D_EXEC_RESULT result[3];long result_msc[3];double timeout_return;double max_tolerable_cost;bool censored;
  };

struct TickShockStateConditionedResponseState
  {
   bool initialized;bool invalid;int direction;long confirmed_msc;double origin_mid;double noise_floor;double initial_shock;double local_sigma;double reference_mid;double reference_spread;long reference_msc;
   double last_bid;double last_ask;double last_mid;long last_msc;double max_extension;double max_retracement;double high_mid;double low_mid;double realized_variance;long nonzero_updates;long positive_updates;long negative_updates;long equal_updates;
   int last_sign;long current_run;long longest_run;long directional_extreme_count;long reversal_extreme_count;long origin_recross_count;long first_origin_recross_msc;int prior_origin_side;
   long interval_ms[TS15D_INTERVAL_CAPACITY];int interval_count;int interval_next;long pre_shock_activity;long post_shock_activity;
   TickShock15DCheckpoint checkpoints[TS15D_CHECKPOINTS];TickShock15DStrategyPath strategies[TS15D_STRATEGIES];
   bool pending_valid;long pending_msc;long pending_processing_msc;double pending_bid;double pending_ask;long duplicates;long drops;
  };

string TS15DSchema(){return "tickshock-state-conditioned-response-v1";}
long TS15DDecisionTarget(const long confirmed_msc,const int offset_ms){return confirmed_msc+(long)MathMax(0,offset_ms);}
long TS15DEntryEligible(const long signal_msc,const long processing_msc,const int delay_ms,const int latency_ms){return MathMax(signal_msc+(long)MathMax(0,delay_ms),processing_msc+(long)MathMax(0,latency_ms));}
bool TS15DDecisionQuoteEligible(const long target_msc,const long quote_msc){return target_msc>=0 && quote_msc>=target_msc;}
bool TS15DFillQuoteEligible(const long signal_msc,const long eligible_msc,const long quote_msc){return quote_msc>signal_msc && quote_msc>=eligible_msc;}

double TS15DScale(const double initial_shock,const double noise_floor){return MathMax(MathAbs(initial_shock),MathAbs(noise_floor));}
double TS15DExtensionRatio(const int direction,const double mid,const double reference_mid,const double initial_shock,const double noise_floor)
  {double scale=TS15DScale(initial_shock,noise_floor);return direction==0||scale<=0.0?0.0:(mid-reference_mid)*(double)(direction>0?1:-1)/scale;}
double TS15DRetracementRatio(const double mae,const double initial_shock,const double noise_floor)
  {double scale=TS15DScale(initial_shock,noise_floor);return scale<=0.0?0.0:MathMax(0.0,mae)/scale;}
double TS15DDirectionalImbalance(const long positive,const long negative)
  {long directional=positive+negative;return directional<=0?0.0:(double)(positive-negative)/(double)directional;}

int TS15DCanonicalUsdSign(const string symbol,const int direction)
  {
   int sign=direction>0?1:(direction<0?-1:0);if(sign==0)return 0;
   if(symbol=="USDJPY"||symbol=="USDCHF"||symbol=="USDCAD")return sign;
   if(symbol=="EURUSD"||symbol=="GBPUSD"||symbol=="AUDUSD")return -sign;
   return 0;
  }
double TS15DCausalCoherence(const int &signs[],const long &confirmed[],const int count,const long decision_msc,int &breadth,int &conflicts)
  {
   breadth=0;conflicts=0;int positive=0,negative=0;
   for(int i=0;i<count;++i)if(confirmed[i]<=decision_msc){++breadth;if(signs[i]>0)++positive;else if(signs[i]<0)++negative;}
   if(breadth<=0)return 0.0;conflicts=MathMin(positive,negative);return (double)MathMax(positive,negative)/(double)breadth;
  }

ENUM_TS15D_PATH_CLASS TS15DClassifyPath(const bool available,const bool both_sides,const bool recross,const bool valid_pullback,const bool reacceleration,const bool invalidated,const bool reversal_touch,const bool continuation_touch)
  {
   if(!available)return TS15D_CLASS_UNAVAILABLE;
   if(both_sides&&recross)return TS15D_TWO_SIDED_WHIPSAW;
   if(valid_pullback&&reacceleration&&continuation_touch)return TS15D_PULLBACK_CONTINUATION;
   if(invalidated&&reversal_touch)return TS15D_FAILED_SHOCK_REVERSAL;
   if(continuation_touch&&!valid_pullback)return TS15D_CLEAN_CONTINUATION;
   return TS15D_DEAD_OR_TIMEOUT;
  }
string TS15DPathClassName(const ENUM_TS15D_PATH_CLASS value)
  {if(value==TS15D_CLEAN_CONTINUATION)return "CLEAN_CONTINUATION";if(value==TS15D_PULLBACK_CONTINUATION)return "PULLBACK_CONTINUATION";if(value==TS15D_FAILED_SHOCK_REVERSAL)return "FAILED_SHOCK_REVERSAL";if(value==TS15D_TWO_SIDED_WHIPSAW)return "TWO_SIDED_WHIPSAW";if(value==TS15D_DEAD_OR_TIMEOUT)return "DEAD_OR_TIMEOUT";return "CLASS_UNAVAILABLE";}
string TS15DAvailabilityName(const ENUM_TS15D_AVAILABILITY value){if(value==TS15D_AVAILABLE)return "AVAILABLE";if(value==TS15D_STALE)return "STALE";if(value==TS15D_MISSING)return "MISSING";return "PENDING";}
string TS15DExecResultName(const ENUM_TS15D_EXEC_RESULT value){if(value==TS15D_EXEC_CONTINUATION)return "CONTINUATION_FIRST";if(value==TS15D_EXEC_REVERSAL)return "REVERSAL_FIRST";if(value==TS15D_EXEC_AMBIGUOUS)return "AMBIGUOUS";if(value==TS15D_EXEC_TIMEOUT)return "TIMEOUT";if(value==TS15D_EXEC_CENSORED)return "CENSORED";return "NONE";}
string TS15DEntrySideName(const int direction){return direction>0?"ASK":(direction<0?"BID":"INVALID");}
ENUM_TS15D_EXEC_RESULT TS15DResolveExecutableTouch(const bool continuation,const bool reversal){if(continuation&&reversal)return TS15D_EXEC_AMBIGUOUS;if(continuation)return TS15D_EXEC_CONTINUATION;if(reversal)return TS15D_EXEC_REVERSAL;return TS15D_EXEC_NONE;}
double TS15DExecutableMove(const int direction,const double entry,const double exit_price){return direction==0?0.0:(exit_price-entry)*(double)(direction>0?1:-1);}
int TS15DNoiseRobustDirection(const double mid_change,const double half_tick){if(MathAbs(mid_change)<=MathAbs(half_tick))return 0;return mid_change>0?1:-1;}
string TS15DEntryStatusName(const bool armed,const bool entered,const bool censored){if(!armed)return "NO_SIGNAL";if(censored)return "CENSORED_END_OF_RUN";return entered?"ENTERED":"PENDING";}
bool TS15DPurgeValid(const long train_end_msc,const long validation_start_msc,const long purge_ms=120000){return validation_start_msc-train_end_msc>=purge_ms;}
bool TS15DCandidateBudgetValid(const int count){return count>=0&&count<=6;}
bool TS15DTrialRegistryComplete(const long registered,const long evaluated,const long discarded){return registered==evaluated+discarded;}
long TS15DIntegrityViolationCount(const long future_reads,const long backdates,const long drops,const long duplicates,const long cursor_stalls){return MathMax((long)0,future_reads)+MathMax((long)0,backdates)+MathMax((long)0,drops)+MathMax((long)0,duplicates)+MathMax((long)0,cursor_stalls);}

void TS15DResetStrategy(TickShock15DStrategyPath &path){ZeroMemory(path);for(int i=0;i<3;++i)path.result[i]=TS15D_EXEC_NONE;}
void TS15DReset(TickShockStateConditionedResponseState &state){ZeroMemory(state);for(int i=0;i<TS15D_STRATEGIES;++i)TS15DResetStrategy(state.strategies[i]);}

bool TS15DArm(TickShockStateConditionedResponseState &state,const long confirmed_msc,const int direction,const double origin_mid,const double initial_shock,const double local_sigma,const double noise_floor,const long pre_activity)
  {
   TS15DReset(state);int sign=direction>0?1:(direction<0?-1:0);if(sign==0||confirmed_msc<0||origin_mid<=0.0||local_sigma<=0.0)return false;
   state.initialized=true;state.direction=sign;state.confirmed_msc=confirmed_msc;state.origin_mid=origin_mid;state.initial_shock=MathAbs(initial_shock);state.local_sigma=local_sigma;state.noise_floor=MathAbs(noise_floor);state.pre_shock_activity=MathMax((long)1,pre_activity);
   string names[TS15D_CHECKPOINTS]={"CONFIRMED_PLUS_500MS","CONFIRMED_PLUS_1000MS","CONFIRMED_PLUS_3000MS","BURST_END","PULLBACK_VALID","REACCELERATION","FAILED_SHOCK"};
   for(int i=0;i<TS15D_CHECKPOINTS;++i){state.checkpoints[i].index=i;state.checkpoints[i].name=names[i];state.checkpoints[i].availability=TS15D_PENDING;state.checkpoints[i].integrity_ok=true;}
   for(int i=0;i<TS15D_FIXED_CHECKPOINTS;++i)state.checkpoints[i].target_msc=TS15DDecisionTarget(confirmed_msc,TS15D_FIXED_OFFSETS_MS[i]);
   return true;
  }

double TS15DMedianInterval(const TickShockStateConditionedResponseState &state)
  {
   int n=MathMin(state.interval_count,TS15D_INTERVAL_CAPACITY);if(n<=0)return 0.0;long values[];ArrayResize(values,n);for(int i=0;i<n;++i)values[i]=state.interval_ms[i];ArraySort(values);if((n&1)==1)return (double)values[n/2];return ((double)values[n/2-1]+(double)values[n/2])*0.5;
  }

void TS15DCapture(TickShockStateConditionedResponseState &state,const int index,const long target_msc,const long quote_msc,const long processing_msc,const double bid,const double ask)
  {
   if(index<0||index>=TS15D_CHECKPOINTS||state.checkpoints[index].recorded)return;TickShock15DCheckpoint c=state.checkpoints[index];c.recorded=true;c.target_msc=target_msc;c.decision_quote_msc=quote_msc;c.processing_msc=processing_msc;c.target_lag_ms=quote_msc-target_msc;c.quote_age_ms=MathMax((long)0,processing_msc-quote_msc);c.availability=c.target_lag_ms>1000?TS15D_STALE:TS15D_AVAILABLE;c.bid=bid;c.ask=ask;c.mid=(bid+ask)*0.5;
   c.current_displacement=(c.mid-state.reference_mid)*(double)state.direction;c.max_extension=state.max_extension;c.max_retracement=state.max_retracement;c.extension_ratio=TS15DExtensionRatio(state.direction,c.mid,state.reference_mid,state.initial_shock,state.noise_floor);c.retracement_ratio=TS15DRetracementRatio(state.max_retracement,state.initial_shock,state.noise_floor);
   c.origin_relation=c.mid>state.origin_mid?1:(c.mid<state.origin_mid?-1:0);c.origin_recross=state.origin_recross_count>0;c.first_origin_recross_msc=state.first_origin_recross_msc;c.time_since_recross_ms=state.first_origin_recross_msc>0?quote_msc-state.first_origin_recross_msc:0;c.origin_recross_count=state.origin_recross_count;c.directional_extreme_count=state.directional_extreme_count;c.reversal_extreme_count=state.reversal_extreme_count;
   c.nonzero_updates=state.nonzero_updates;c.positive_updates=state.positive_updates;c.negative_updates=state.negative_updates;c.equal_updates=state.equal_updates;c.directional_imbalance=TS15DDirectionalImbalance(state.positive_updates,state.negative_updates);c.longest_run=state.longest_run;c.current_run=state.current_run;c.median_interval_ms=TS15DMedianInterval(state);c.latest_interval_ms=state.last_msc>0?quote_msc-state.last_msc:0;c.activity_ratio=(double)state.post_shock_activity/(double)MathMax((long)1,state.pre_shock_activity);c.spread=ask-bid;c.spread_confirmed_ratio=state.reference_spread>0.0?c.spread/state.reference_spread:0.0;c.realized_range=state.high_mid-state.low_mid;c.realized_volatility=MathSqrt(MathMax(0.0,state.realized_variance));c.integrity_ok=!state.invalid;state.checkpoints[index]=c;
  }

bool TS15DArmStrategy(TickShockStateConditionedResponseState &state,const int strategy,const int direction,const long signal_msc,const long processing_msc,const int delay_ms,const int latency_ms)
  {if(strategy<0||strategy>=TS15D_STRATEGIES||direction==0||state.strategies[strategy].armed)return false;TickShock15DStrategyPath p;TS15DResetStrategy(p);p.armed=true;p.strategy=strategy;p.direction=direction>0?1:-1;p.signal_msc=signal_msc;p.processing_msc=processing_msc;p.eligible_msc=TS15DEntryEligible(signal_msc,processing_msc,delay_ms,latency_ms);p.local_scale=state.local_sigma*MathMax(state.origin_mid,1.0);state.strategies[strategy]=p;return true;}

void TS15DObserveStrategy(TickShock15DStrategyPath &p,const long quote_msc,const double bid,const double ask)
  {
   if(!p.armed||p.complete||bid<=0.0||ask<bid)return;if(!p.entered){if(!TS15DFillQuoteEligible(p.signal_msc,p.eligible_msc,quote_msc))return;p.entered=true;p.entry_quote_msc=quote_msc;p.entry_bid=bid;p.entry_ask=ask;p.entry_price=p.direction>0?ask:bid;return;}
   double exit=p.direction>0?bid:ask;double move=(exit-p.entry_price)*(double)p.direction;if(move>p.mfe){p.mfe=move;p.time_to_mfe_ms=quote_msc-p.entry_quote_msc;}if(-move>p.mae){p.mae=-move;p.time_to_mae_ms=quote_msc-p.entry_quote_msc;}
   for(int i=0;i<3;++i)if(p.result[i]==TS15D_EXEC_NONE){double barrier=TS15D_BARRIERS[i]*p.local_scale;bool cont=move>=barrier,rev=move<=-barrier;ENUM_TS15D_EXEC_RESULT r=TS15DResolveExecutableTouch(cont,rev);if(r!=TS15D_EXEC_NONE){p.result[i]=r;p.result_msc[i]=quote_msc;}}
   p.max_tolerable_cost=MathMax(0.0,p.mfe-p.mae);
  }

bool TS15DProcessQuote(TickShockStateConditionedResponseState &state,const long quote_msc,const long processing_msc,const double bid,const double ask)
  {
   if(!state.initialized||quote_msc<=state.confirmed_msc||bid<=0.0||ask<bid)return false;double mid=(bid+ask)*0.5;
   if(state.reference_mid<=0.0){state.reference_mid=mid;state.reference_spread=ask-bid;state.reference_msc=quote_msc;state.last_bid=bid;state.last_ask=ask;state.last_mid=mid;state.last_msc=quote_msc;state.high_mid=mid;state.low_mid=mid;state.prior_origin_side=mid>state.origin_mid?1:(mid<state.origin_mid?-1:0);for(int s=0;s<TS15D_STRATEGIES;++s)TS15DObserveStrategy(state.strategies[s],quote_msc,bid,ask);return true;}
   long interval=quote_msc-state.last_msc;if(interval<0){++state.drops;state.invalid=true;return false;}if(interval>0){state.interval_ms[state.interval_next]=interval;state.interval_next=(state.interval_next+1)%TS15D_INTERVAL_CAPACITY;++state.interval_count;}
   double delta=mid-state.last_mid;int raw_sign=delta>0?1:(delta<0?-1:0);if(raw_sign==0)++state.equal_updates;else{++state.nonzero_updates;if(raw_sign>0)++state.positive_updates;else ++state.negative_updates;int directional_sign=raw_sign*state.direction;if(directional_sign==state.last_sign)++state.current_run;else{state.current_run=1;state.last_sign=directional_sign;}state.longest_run=MathMax(state.longest_run,state.current_run);}
   double signed_move=(mid-state.reference_mid)*(double)state.direction;if(signed_move>state.max_extension){state.max_extension=signed_move;++state.directional_extreme_count;}if(-signed_move>state.max_retracement){state.max_retracement=-signed_move;++state.reversal_extreme_count;}
   state.high_mid=MathMax(state.high_mid,mid);state.low_mid=MathMin(state.low_mid,mid);if(state.last_mid>0.0){double r=MathLog(mid/state.last_mid);if(MathIsValidNumber(r))state.realized_variance+=r*r;}
   int side=mid>state.origin_mid?1:(mid<state.origin_mid?-1:0);if(side!=0&&state.prior_origin_side!=0&&side!=state.prior_origin_side){++state.origin_recross_count;if(state.first_origin_recross_msc==0)state.first_origin_recross_msc=quote_msc;}if(side!=0)state.prior_origin_side=side;++state.post_shock_activity;
   for(int i=0;i<TS15D_FIXED_CHECKPOINTS;++i)if(!state.checkpoints[i].recorded&&quote_msc>=state.checkpoints[i].target_msc)TS15DCapture(state,i,state.checkpoints[i].target_msc,quote_msc,processing_msc,bid,ask);
   for(int s=0;s<TS15D_STRATEGIES;++s)TS15DObserveStrategy(state.strategies[s],quote_msc,bid,ask);
   state.last_bid=bid;state.last_ask=ask;state.last_mid=mid;state.last_msc=quote_msc;return true;
  }

bool TS15DFlushPending(TickShockStateConditionedResponseState &state){if(!state.pending_valid)return true;bool ok=TS15DProcessQuote(state,state.pending_msc,state.pending_processing_msc,state.pending_bid,state.pending_ask);state.pending_valid=false;return ok;}
bool TS15DQueueQuote(TickShockStateConditionedResponseState &state,const long quote_msc,const long processing_msc,const double bid,const double ask)
  {if(!state.initialized||quote_msc<=state.confirmed_msc||bid<=0.0||ask<bid)return false;if(!state.pending_valid){state.pending_valid=true;state.pending_msc=quote_msc;state.pending_processing_msc=processing_msc;state.pending_bid=bid;state.pending_ask=ask;return true;}if(quote_msc==state.pending_msc){state.pending_processing_msc=processing_msc;state.pending_bid=bid;state.pending_ask=ask;++state.duplicates;return true;}if(quote_msc<state.pending_msc){++state.drops;state.invalid=true;return false;}if(!TS15DFlushPending(state))return false;state.pending_valid=true;state.pending_msc=quote_msc;state.pending_processing_msc=processing_msc;state.pending_bid=bid;state.pending_ask=ask;return true;}
void TS15DMarkStateCheckpoint(TickShockStateConditionedResponseState &state,const int index,const long event_msc,const long processing_msc,const double bid,const double ask){TS15DFlushPending(state);if(index>=TS15D_FIXED_CHECKPOINTS&&index<TS15D_CHECKPOINTS)TS15DCapture(state,index,event_msc,event_msc,processing_msc,bid,ask);}
void TS15DFinalize(TickShockStateConditionedResponseState &state,const bool censored){TS15DFlushPending(state);for(int i=0;i<TS15D_CHECKPOINTS;++i)if(!state.checkpoints[i].recorded)state.checkpoints[i].availability=TS15D_MISSING;for(int s=0;s<TS15D_STRATEGIES;++s){TickShock15DStrategyPath p=state.strategies[s];if(p.armed&&!p.complete){if(censored){p.censored=true;for(int b=0;b<3;++b)if(p.result[b]==TS15D_EXEC_NONE)p.result[b]=TS15D_EXEC_CENSORED;}else{for(int b=0;b<3;++b)if(p.result[b]==TS15D_EXEC_NONE)p.result[b]=TS15D_EXEC_TIMEOUT;if(p.entered&&p.entry_price>0.0){double exit_price=p.direction>0?state.last_bid:state.last_ask;p.timeout_return=TS15DExecutableMove(p.direction,p.entry_price,exit_price);}}p.complete=true;state.strategies[s]=p;}}}

#endif
