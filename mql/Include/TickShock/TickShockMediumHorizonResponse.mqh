#ifndef TICK_SHOCK_MEDIUM_HORIZON_RESPONSE_MQH
#define TICK_SHOCK_MEDIUM_HORIZON_RESPONSE_MQH

#define TS15E_CHECKPOINTS 9
#define TS15E_ENTRY_CLOCKS 5
#define TS15E_DIRECTIONS 2
#define TS15E_ENTRY_PATHS 10
#define TS15E_M1_CAPACITY 16

const int TS15E_CHECKPOINT_SECONDS[TS15E_CHECKPOINTS]={5,10,30,60,120,180,300,600,900};
const long TS15E_HORIZON_MS=900000;
const long TS15E_QUIET_MS=60000;

enum ENUM_TS15E_MODE { TS15E_IDLE=0,TS15E_ACTIVE_15M,TS15E_COOLDOWN };
enum ENUM_TS15E_AVAILABILITY { TS15E_PENDING=0,TS15E_AVAILABLE,TS15E_STALE,TS15E_MISSING,TS15E_MISSING_WEEKEND,TS15E_MISSING_BID_ASK,TS15E_EXCLUDED_FALLBACK };
enum ENUM_TS15E_TOUCH { TS15E_TOUCH_NONE=0,TS15E_TOUCH_CONTINUATION,TS15E_TOUCH_REVERSAL,TS15E_TOUCH_AMBIGUOUS };

struct TickShock15EM1Point
  {long boundary_msc;double mid;bool fallback;};

struct TickShock15EM1State
  {
   TickShock15EM1Point points[TS15E_M1_CAPACITY];int count;int next;
   long current_minute;double current_close;bool current_fallback;bool initialized;
  };

struct TickShock15ECheckpoint
  {
   bool recorded;long target_msc;long quote_msc;long processing_msc;long target_lag_ms;long quote_age_ms;ENUM_TS15E_AVAILABILITY availability;
   double bid;double ask;double mid;double signed_log_return;double absolute_log_return;double shock_direction_move;
   double long_executable_move;double short_executable_move;double mfe;double mae;long time_to_mfe_ms;long time_to_mae_ms;
   double spread;double point_multiple;double pip_multiple;double spread_multiple;double shock_multiple;double pre_vol_multiple;
  };

struct TickShock15EEntryPath
  {
   bool armed;bool entered;int direction;int clock_index;long signal_event_msc;long signal_quote_msc;long signal_processing_msc;long eligible_msc;
   long entry_quote_msc;double entry_bid;double entry_ask;double entry_mid;double executable_move[TS15E_CHECKPOINTS];double stressed_move[TS15E_CHECKPOINTS];bool exit_valid[TS15E_CHECKPOINTS];
  };

struct TickShock15EEpisode
  {
   ENUM_TS15E_MODE mode;bool initialized;bool invalid;bool write_pending;bool purged;string episode_id;string anchor_event_id;long market_cluster_id;string symbol;int direction;
   long anchor_msc;long anchor_processing_msc;double anchor_bid;double anchor_ask;double anchor_mid;double point;double tick_size;double initial_shock;double severity;
   bool pre_vol_valid;double pre_m1_rms;int pre_m1_count;bool fallback_anchor;string step15d_path_class;bool sr_clean;bool sr_rev;
   long repeat_count;long same_direction_repeats;long opposite_direction_repeats;double max_repeat_severity;long last_shock_msc;long cooldown_quiet_start_msc;
   double high_mid;double low_mid;double mfe;double mae;long time_to_mfe_ms;long time_to_mae_ms;long origin_recross_count;long first_origin_recross_msc;int prior_origin_side;
   long quote_count;long stale_count;long missing_count;long fallback_count;long duplicates;long drops;long capacity_losses;long future_reads;long backdates;
   double spread_sum;double realized_variance;double last_mid;long last_msc;double last_bid;double last_ask;
   TickShock15ECheckpoint checkpoints[TS15E_CHECKPOINTS];TickShock15EEntryPath entries[TS15E_ENTRY_PATHS];
   bool pending_valid;long pending_msc;long pending_processing_msc;double pending_bid;double pending_ask;bool pending_fallback;
  };

struct TickShockMediumHorizonContext
  {TickShock15EM1State m1;TickShock15EEpisode episode;long episode_sequence;long completed;long purged;long cooldown_repeats;};

string TS15ESchema(){return "tickshock-medium-horizon-response-v1";}
string TS15EModeName(const ENUM_TS15E_MODE value){if(value==TS15E_ACTIVE_15M)return "ACTIVE_15M";if(value==TS15E_COOLDOWN)return "COOLDOWN";return "IDLE";}
string TS15EAvailabilityName(const ENUM_TS15E_AVAILABILITY value){if(value==TS15E_AVAILABLE)return "AVAILABLE";if(value==TS15E_STALE)return "STALE";if(value==TS15E_MISSING)return "MISSING";if(value==TS15E_MISSING_WEEKEND)return "MISSING_WEEKEND";if(value==TS15E_MISSING_BID_ASK)return "MISSING_BID_ASK";if(value==TS15E_EXCLUDED_FALLBACK)return "EXCLUDED_FALLBACK";return "PENDING";}
string TS15ETouchName(const ENUM_TS15E_TOUCH value){if(value==TS15E_TOUCH_CONTINUATION)return "CONTINUATION";if(value==TS15E_TOUCH_REVERSAL)return "REVERSAL";if(value==TS15E_TOUCH_AMBIGUOUS)return "AMBIGUOUS";return "NONE";}
long TS15ETarget(const long anchor_msc,const int checkpoint){return checkpoint<0||checkpoint>=TS15E_CHECKPOINTS?0:anchor_msc+(long)TS15E_CHECKPOINT_SECONDS[checkpoint]*1000;}
bool TS15ECompletedM1Eligible(const long boundary_msc,const long anchor_msc){return boundary_msc>0 && boundary_msc<=((anchor_msc/60000)*60000-60000);}
double TS15ESpreadOnlyMove(const int direction,const double entry_bid,const double entry_ask,const double exit_bid,const double exit_ask){if(direction>0)return exit_bid-entry_ask;if(direction<0)return entry_bid-exit_ask;return 0.0;}
ENUM_TS15E_TOUCH TS15EResolveTouch(const bool continuation,const bool reversal){if(continuation&&reversal)return TS15E_TOUCH_AMBIGUOUS;if(continuation)return TS15E_TOUCH_CONTINUATION;if(reversal)return TS15E_TOUCH_REVERSAL;return TS15E_TOUCH_NONE;}
long TS15EIntegrityViolations(const TickShock15EEpisode &e){return e.drops+e.capacity_losses+e.future_reads+e.backdates;}

void TS15EResetM1(TickShock15EM1State &state){ZeroMemory(state);}
void TS15EResetEntry(TickShock15EEntryPath &path){ZeroMemory(path);}
void TS15EResetEpisode(TickShock15EEpisode &episode){ZeroMemory(episode);episode.mode=TS15E_IDLE;for(int i=0;i<TS15E_CHECKPOINTS;++i)episode.checkpoints[i].availability=TS15E_PENDING;}
void TS15EResetContext(TickShockMediumHorizonContext &context){ZeroMemory(context);TS15EResetM1(context.m1);TS15EResetEpisode(context.episode);}

void TS15EStoreM1(TickShock15EM1State &state,const long boundary_msc,const double mid,const bool fallback)
  {if(mid<=0.0||boundary_msc<=0)return;state.points[state.next].boundary_msc=boundary_msc;state.points[state.next].mid=mid;state.points[state.next].fallback=fallback;state.next=(state.next+1)%TS15E_M1_CAPACITY;if(state.count<TS15E_M1_CAPACITY)++state.count;}

void TS15EObserveMinuteQuote(TickShock15EM1State &state,const long quote_msc,const double mid,const bool fallback)
  {
   if(quote_msc<=0||mid<=0.0)return;long minute=quote_msc/60000;
   if(!state.initialized){state.initialized=true;state.current_minute=minute;state.current_close=mid;state.current_fallback=fallback;return;}
   if(minute<state.current_minute)return;
   if(minute==state.current_minute){state.current_close=mid;state.current_fallback=state.current_fallback||fallback;return;}
   TS15EStoreM1(state,(state.current_minute+1)*60000,state.current_close,state.current_fallback);
   state.current_minute=minute;state.current_close=mid;state.current_fallback=fallback;
  }

bool TS15EPreM1Rms(const TickShock15EM1State &state,const long anchor_msc,double &value,int &returns_count)
  {
   value=0.0;returns_count=0;if(state.count<11)return false;TickShock15EM1Point eligible[TS15E_M1_CAPACITY];int n=0;int oldest=(state.next-state.count+TS15E_M1_CAPACITY)%TS15E_M1_CAPACITY;
   for(int i=0;i<state.count;++i){TickShock15EM1Point p=state.points[(oldest+i)%TS15E_M1_CAPACITY];if(TS15ECompletedM1Eligible(p.boundary_msc,anchor_msc))eligible[n++]=p;}
   if(n<11)return false;int start=n-11;double sum=0.0;
   for(int i=start+1;i<n;++i){if(eligible[i-1].fallback||eligible[i].fallback||eligible[i-1].mid<=0.0||eligible[i].mid<=0.0)return false;double r=MathLog(eligible[i].mid/eligible[i-1].mid);if(!MathIsValidNumber(r))return false;sum+=r*r;++returns_count;}
   if(returns_count<10)return false;value=MathSqrt(sum/(double)returns_count);return MathIsValidNumber(value)&&value>0.0;
  }

void TS15EArmEntry(TickShock15EEpisode &e,const int clock_index,const int direction,const long signal_event_msc,const long decision_quote_msc,const long processing_msc,const int latency_ms)
  {
   int side=direction>0?0:1;int index=clock_index*2+side;if(index<0||index>=TS15E_ENTRY_PATHS||e.entries[index].armed)return;TickShock15EEntryPath p;TS15EResetEntry(p);p.armed=true;p.direction=direction>0?1:-1;p.clock_index=clock_index;p.signal_event_msc=signal_event_msc;p.signal_quote_msc=decision_quote_msc;p.signal_processing_msc=processing_msc;p.eligible_msc=MathMax(signal_event_msc,processing_msc+(long)MathMax(0,latency_ms));e.entries[index]=p;
  }

bool TS15EArmEpisode(TickShockMediumHorizonContext &context,const string run_id,const string symbol,const string event_id,const long market_cluster_id,const int direction,const long confirmed_msc,const long processing_msc,const double bid,const double ask,const double point,const double tick_size,const double initial_shock,const double severity,const bool fallback_anchor,const int latency_ms)
  {
   TickShock15EEpisode e=context.episode;if(e.mode!=TS15E_IDLE||direction==0||confirmed_msc<=0||bid<=0.0||ask<bid||point<=0.0||tick_size<=0.0)return false;
   TS15EResetEpisode(e);e.initialized=true;e.mode=TS15E_ACTIVE_15M;e.episode_id=StringFormat("%s_%s_mh_%I64d",run_id,symbol,++context.episode_sequence);e.anchor_event_id=event_id;e.market_cluster_id=market_cluster_id;e.symbol=symbol;e.direction=direction>0?1:-1;e.anchor_msc=confirmed_msc;e.anchor_processing_msc=processing_msc;e.anchor_bid=bid;e.anchor_ask=ask;e.anchor_mid=(bid+ask)*0.5;e.point=point;e.tick_size=tick_size;e.initial_shock=MathAbs(initial_shock);e.severity=severity;e.fallback_anchor=fallback_anchor;e.last_shock_msc=confirmed_msc;e.high_mid=e.anchor_mid;e.low_mid=e.anchor_mid;e.last_mid=e.anchor_mid;e.last_msc=confirmed_msc;e.last_bid=bid;e.last_ask=ask;e.prior_origin_side=0;
   e.pre_vol_valid=TS15EPreM1Rms(context.m1,confirmed_msc,e.pre_m1_rms,e.pre_m1_count);
   for(int i=0;i<TS15E_CHECKPOINTS;++i){e.checkpoints[i].target_msc=TS15ETarget(confirmed_msc,i);e.checkpoints[i].availability=TS15E_PENDING;}
   TS15EArmEntry(e,0,1,confirmed_msc,confirmed_msc,processing_msc,latency_ms);TS15EArmEntry(e,0,-1,confirmed_msc,confirmed_msc,processing_msc,latency_ms);context.episode=e;return true;
  }

bool TS15ERegisterRepeat(TickShockMediumHorizonContext &context,const int direction,const long confirmed_msc,const double severity)
  {
   TickShock15EEpisode e=context.episode;if(e.mode==TS15E_IDLE)return false;e.last_shock_msc=confirmed_msc;
   if(e.mode==TS15E_COOLDOWN){++context.cooldown_repeats;e.cooldown_quiet_start_msc=confirmed_msc;context.episode=e;return true;}
   ++e.repeat_count;if((direction>0?1:-1)==e.direction)++e.same_direction_repeats;else ++e.opposite_direction_repeats;e.max_repeat_severity=MathMax(e.max_repeat_severity,severity);context.episode=e;return true;
  }

bool TS15EArmCausalTransition(TickShockMediumHorizonContext &context,const string anchor_event_id,const long signal_msc,const long processing_msc,const int direction,const int latency_ms)
  {TickShock15EEpisode e=context.episode;if(e.mode!=TS15E_ACTIVE_15M||e.anchor_event_id!=anchor_event_id||signal_msc<e.anchor_msc)return false;TS15EArmEntry(e,4,direction,signal_msc,signal_msc,processing_msc,latency_ms);context.episode=e;return true;}

bool TS15ESetStep15DLabel(TickShockMediumHorizonContext &context,const string anchor_event_id,const string path_class)
  {TickShock15EEpisode e=context.episode;if(e.mode==TS15E_IDLE||e.anchor_event_id!=anchor_event_id)return false;e.step15d_path_class=path_class;e.sr_clean=path_class=="CLEAN_CONTINUATION";e.sr_rev=path_class=="FAILED_SHOCK_REVERSAL";context.episode=e;return true;}

void TS15EObserveEntry(TickShock15EEntryPath &p,const long quote_msc,const double bid,const double ask)
  {if(!p.armed||p.entered||quote_msc<=p.signal_quote_msc||quote_msc<p.eligible_msc)return;p.entered=true;p.entry_quote_msc=quote_msc;p.entry_bid=bid;p.entry_ask=ask;p.entry_mid=(bid+ask)*0.5;}

void TS15ECapture(TickShock15EEpisode &e,const int index,const long quote_msc,const long processing_msc,const double bid,const double ask,const bool fallback)
  {
   if(index<0||index>=TS15E_CHECKPOINTS||e.checkpoints[index].recorded)return;TickShock15ECheckpoint c=e.checkpoints[index];c.recorded=true;c.quote_msc=quote_msc;c.processing_msc=processing_msc;c.target_lag_ms=quote_msc-c.target_msc;c.quote_age_ms=MathMax((long)0,processing_msc-quote_msc);c.availability=fallback?TS15E_EXCLUDED_FALLBACK:((c.target_lag_ms>1000||c.quote_age_ms>1000)?TS15E_STALE:TS15E_AVAILABLE);c.bid=bid;c.ask=ask;c.mid=(bid+ask)*0.5;
   if(c.mid>0.0&&e.anchor_mid>0.0){double raw=MathLog(c.mid/e.anchor_mid);c.signed_log_return=raw*(double)e.direction;c.absolute_log_return=MathAbs(raw);}c.shock_direction_move=(c.mid-e.anchor_mid)*(double)e.direction;c.long_executable_move=bid-e.anchor_ask;c.short_executable_move=e.anchor_bid-ask;c.mfe=e.mfe;c.mae=e.mae;c.time_to_mfe_ms=e.time_to_mfe_ms;c.time_to_mae_ms=e.time_to_mae_ms;c.spread=ask-bid;c.point_multiple=e.point>0.0?c.shock_direction_move/e.point:0.0;double pip=e.point*10.0;c.pip_multiple=pip>0.0?c.shock_direction_move/pip:0.0;double spread=e.anchor_ask-e.anchor_bid;c.spread_multiple=spread>0.0?c.shock_direction_move/spread:0.0;c.shock_multiple=e.initial_shock>0.0?c.shock_direction_move/e.initial_shock:0.0;c.pre_vol_multiple=e.pre_vol_valid&&e.pre_m1_rms>0.0?c.signed_log_return/e.pre_m1_rms:0.0;e.checkpoints[index]=c;
   for(int p=0;p<TS15E_ENTRY_PATHS;++p)if(e.entries[p].entered){e.entries[p].executable_move[index]=TS15ESpreadOnlyMove(e.entries[p].direction,e.entries[p].entry_bid,e.entries[p].entry_ask,bid,ask);double mid=(bid+ask)*0.5,half=(ask-bid)*0.625;e.entries[p].stressed_move[index]=e.entries[p].direction>0?(mid-half)-e.entries[p].entry_ask:(e.entries[p].entry_bid-(mid+half));e.entries[p].exit_valid[index]=true;}
  }

bool TS15EProcessQuote(TickShockMediumHorizonContext &context,const long quote_msc,const long processing_msc,const double bid,const double ask,const bool fallback,const int latency_ms)
  {
   TickShock15EEpisode e=context.episode;if(e.mode==TS15E_IDLE)return false;if(e.mode==TS15E_COOLDOWN){if(quote_msc-e.cooldown_quiet_start_msc>=TS15E_QUIET_MS){TS15EResetEpisode(e);context.episode=e;}return true;}
   if(quote_msc<=e.anchor_msc||bid<=0.0||ask<bid)return false;if(quote_msc<e.last_msc){++e.drops;e.invalid=true;context.episode=e;return false;}double mid=(bid+ask)*0.5,move=(mid-e.anchor_mid)*(double)e.direction;if(move>e.mfe){e.mfe=move;e.time_to_mfe_ms=quote_msc-e.anchor_msc;}if(-move>e.mae){e.mae=-move;e.time_to_mae_ms=quote_msc-e.anchor_msc;}e.high_mid=MathMax(e.high_mid,mid);e.low_mid=MathMin(e.low_mid,mid);if(e.last_mid>0.0){double r=MathLog(mid/e.last_mid);if(MathIsValidNumber(r))e.realized_variance+=r*r;}int side=mid>e.anchor_mid?1:(mid<e.anchor_mid?-1:0);if(side!=0&&e.prior_origin_side!=0&&side!=e.prior_origin_side){++e.origin_recross_count;if(e.first_origin_recross_msc==0)e.first_origin_recross_msc=quote_msc;}if(side!=0)e.prior_origin_side=side;++e.quote_count;if(fallback)++e.fallback_count;e.spread_sum+=ask-bid;
   const int entry_offsets[4]={0,30,60,120};for(int clock=1;clock<4;++clock){long target=e.anchor_msc+(long)entry_offsets[clock]*1000;if(quote_msc>=target&&!e.entries[clock*2].armed){TS15EArmEntry(e,clock,1,target,quote_msc,processing_msc,latency_ms);TS15EArmEntry(e,clock,-1,target,quote_msc,processing_msc,latency_ms);}}
   for(int p=0;p<TS15E_ENTRY_PATHS;++p)TS15EObserveEntry(e.entries[p],quote_msc,bid,ask);
   for(int i=0;i<TS15E_CHECKPOINTS;++i)if(!e.checkpoints[i].recorded&&quote_msc>=e.checkpoints[i].target_msc)TS15ECapture(e,i,quote_msc,processing_msc,bid,ask,fallback);
   e.last_mid=mid;e.last_msc=quote_msc;e.last_bid=bid;e.last_ask=ask;if(quote_msc>=e.anchor_msc+TS15E_HORIZON_MS){e.mode=TS15E_COOLDOWN;e.cooldown_quiet_start_msc=quote_msc;e.write_pending=true;++context.completed;}context.episode=e;return true;
  }

bool TS15EFlushPending(TickShockMediumHorizonContext &context,const int latency_ms){TickShock15EEpisode e=context.episode;if(!e.pending_valid)return true;long m=e.pending_msc,p=e.pending_processing_msc;double b=e.pending_bid,a=e.pending_ask;bool f=e.pending_fallback;e.pending_valid=false;context.episode=e;return TS15EProcessQuote(context,m,p,b,a,f,latency_ms);}
bool TS15EQueueQuote(TickShockMediumHorizonContext &context,const long quote_msc,const long processing_msc,const double bid,const double ask,const bool fallback,const int latency_ms)
  {TickShock15EEpisode e=context.episode;if(e.mode==TS15E_IDLE)return false;if(!e.pending_valid){e.pending_valid=true;e.pending_msc=quote_msc;e.pending_processing_msc=processing_msc;e.pending_bid=bid;e.pending_ask=ask;e.pending_fallback=fallback;context.episode=e;return true;}if(quote_msc==e.pending_msc){e.pending_processing_msc=processing_msc;e.pending_bid=bid;e.pending_ask=ask;e.pending_fallback=e.pending_fallback||fallback;++e.duplicates;context.episode=e;return true;}if(quote_msc<e.pending_msc){++e.drops;e.invalid=true;context.episode=e;return false;}context.episode=e;if(!TS15EFlushPending(context,latency_ms))return false;e=context.episode;e.pending_valid=true;e.pending_msc=quote_msc;e.pending_processing_msc=processing_msc;e.pending_bid=bid;e.pending_ask=ask;e.pending_fallback=fallback;context.episode=e;return true;}

void TS15EFinalizeEndOfData(TickShockMediumHorizonContext &context,const int latency_ms)
  {TS15EFlushPending(context,latency_ms);TickShock15EEpisode e=context.episode;if(e.mode==TS15E_ACTIVE_15M){e.purged=true;e.write_pending=true;e.invalid=true;++context.purged;}context.episode=e;}

#endif
