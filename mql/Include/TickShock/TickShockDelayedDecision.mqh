#ifndef TICK_SHOCK_DELAYED_DECISION_MQH
#define TICK_SHOCK_DELAYED_DECISION_MQH

#define TS15N_CHECKPOINTS 4
#define TS15N_ACTIONS 2
#define TS15N_POOL_CAPACITY 8
#define TS15N_SECOND_CAPACITY 121

const int TS15N_DELAY_SECONDS[TS15N_CHECKPOINTS]={15,30,60,120};

enum ENUM_TS15N_STATUS
  {
   TS15N_PENDING=0,
   TS15N_ELIGIBLE=1,
   TS15N_NO_DECISION_QUOTE=2,
   TS15N_STALE_DECISION=3,
   TS15N_FEATURE_UNAVAILABLE=4,
   TS15N_ENTRY_QUOTE_UNAVAILABLE=5,
   TS15N_ENTRY_AFTER_DEADLINE=6,
   TS15N_PATH_CENSORED=7,
   TS15N_DATA_INTEGRITY_INVALID=8
  };

enum ENUM_TS15N_RESULT
  {TS15N_RESULT_PENDING=0,TS15N_TP_FIRST=1,TS15N_SL_FIRST=2,TS15N_TIMEOUT=3,TS15N_RESULT_INVALID=4};

struct TickShock15NSecond
  {long second_msc;double first_mid;double last_mid;double high_mid;double low_mid;double spread_sum;long ticks;double path_abs;};

struct TickShock15NAction
  {
   int direction;bool entered;bool done;ENUM_TS15N_RESULT result;
   long entry_eligible_msc;long entry_quote_msc;long entry_processing_msc;long exit_msc;
   double entry_bid;double entry_ask;double entry_price;double tp;double sl;double exit_price;
   double risk_distance;double tp_distance;double realized_r;double mfe_r;double mae_r;
  };

struct TickShock15NCheckpoint
  {
   int delay_seconds;long target_msc;ENUM_TS15N_STATUS status;bool decided;
   long decision_quote_msc;long decision_processing_msc;long feature_max_source_msc;long atr_source_msc;
   long checkpoint_quote_lag_ms;double decision_bid;double decision_ask;double decision_mid;double atr_decision;
   double postshock_return_atr;double postshock_mfe_atr;double postshock_mae_atr;double postshock_range_atr;
   double retracement_from_peak_pct;double retracement_from_trough_pct;double current_location_in_range;
   long new_extreme_count;long origin_recross_count;long time_since_last_extreme_ms;double distance_from_last_extreme_atr;
   double net_move_over_path_length;double shock_direction_tick_ratio;double direction_consistency;
   double realized_abs_move_atr;double realized_volatility;double recent_5s_acceleration;double recent_10s_acceleration;
   double peak_update_interval_ms;double extreme_update_rate;double path_contraction_ratio;double path_expansion_ratio;
   double decision_spread_atr;double spread_vs_t0_ratio;double spread_vs_postshock_mean;double spread_contraction_from_t0;
   long tick_count_postshock;double tick_rate_recent_5s;double tick_rate_recent_10s;double tick_activity_vs_t0;
   double activity_decay;double activity_acceleration;
   TickShock15NAction action[TS15N_ACTIONS];
  };

struct TickShock15NRecord
  {
   bool active;bool complete;bool write_pending;bool invalid;
   string episode_id;string event_id;string symbol;long market_cluster_id;int shock_direction;
   long t0_msc;long deadline_msc;long t0_quote_msc;long t0_processing_msc;
   double t0_bid;double t0_ask;double t0_mid;double atr_t0;double tick_size;double tick_activity_t0;
   double high_mid;double low_mid;double last_mid;double path_abs;double squared_move_sum;double spread_sum;
   long tick_count;long direction_ticks;long new_extreme_count;long origin_recross_count;long last_extreme_msc;long first_extreme_msc;
   int last_side;TickShock15NSecond seconds[TS15N_SECOND_CAPACITY];int second_count;int second_head;
   TickShock15NCheckpoint checkpoint[TS15N_CHECKPOINTS];
   bool pending_valid;long pending_quote_msc;long pending_processing_msc;double pending_bid;double pending_ask;double pending_atr;long pending_atr_source_msc;bool pending_fallback;
  };

struct TickShock15NPool
  {TickShock15NRecord records[TS15N_POOL_CAPACITY];long armed;long completed;long capacity_hits;long invalid_paths;};

string TS15NSchema(){return "tickshock-delayed-decision-v1";}
string TS15NStatusName(const ENUM_TS15N_STATUS s)
  {
   if(s==TS15N_ELIGIBLE)return "ELIGIBLE";if(s==TS15N_NO_DECISION_QUOTE)return "NO_DECISION_QUOTE";
   if(s==TS15N_STALE_DECISION)return "STALE_DECISION";if(s==TS15N_FEATURE_UNAVAILABLE)return "FEATURE_UNAVAILABLE";
   if(s==TS15N_ENTRY_QUOTE_UNAVAILABLE)return "ENTRY_QUOTE_UNAVAILABLE";if(s==TS15N_ENTRY_AFTER_DEADLINE)return "ENTRY_AFTER_DEADLINE";
   if(s==TS15N_PATH_CENSORED)return "PATH_CENSORED";if(s==TS15N_DATA_INTEGRITY_INVALID)return "DATA_INTEGRITY_INVALID";return "PENDING";
  }
string TS15NResultName(const ENUM_TS15N_RESULT r)
  {if(r==TS15N_TP_FIRST)return "TP_FIRST";if(r==TS15N_SL_FIRST)return "SL_FIRST";if(r==TS15N_TIMEOUT)return "TIMEOUT";if(r==TS15N_RESULT_INVALID)return "INVALID";return "PENDING";}
string TS15NActionName(const int a){return a==0?"CONTINUATION":"REVERSAL";}

void TS15NResetRecord(TickShock15NRecord &r)
  {
   ZeroMemory(r);
   for(int c=0;c<TS15N_CHECKPOINTS;++c){r.checkpoint[c].delay_seconds=TS15N_DELAY_SECONDS[c];r.checkpoint[c].status=TS15N_PENDING;for(int a=0;a<TS15N_ACTIONS;++a)r.checkpoint[c].action[a].result=TS15N_RESULT_PENDING;}
  }
void TS15NResetPool(TickShock15NPool &p){ZeroMemory(p);for(int i=0;i<TS15N_POOL_CAPACITY;++i)TS15NResetRecord(p.records[i]);}

bool TS15NArm(TickShock15NPool &pool,const string episode_id,const string event_id,const string symbol,const long cluster_id,const int direction,
              const long t0_msc,const long t0_quote_msc,const long processing_msc,const double bid,const double ask,const double atr_t0,
              const double tick_size,const double tick_activity_t0)
  {
   if(episode_id==""||event_id==""||symbol==""||direction==0||t0_msc<=0||t0_quote_msc<=0||processing_msc<t0_quote_msc||bid<=0.0||ask<=bid||tick_size<=0.0)return false;
   for(int i=0;i<TS15N_POOL_CAPACITY;++i)if((pool.records[i].active||pool.records[i].write_pending)&&pool.records[i].episode_id==episode_id)return false;
   int slot=-1;for(int i=0;i<TS15N_POOL_CAPACITY;++i)if(!pool.records[i].active&&!pool.records[i].write_pending){slot=i;break;}
   if(slot<0){++pool.capacity_hits;return false;}
   TickShock15NRecord r;TS15NResetRecord(r);r.active=true;r.episode_id=episode_id;r.event_id=event_id;r.symbol=symbol;r.market_cluster_id=cluster_id;r.shock_direction=direction>0?1:-1;
   r.t0_msc=t0_msc;r.deadline_msc=t0_msc+900000;r.t0_quote_msc=t0_quote_msc;r.t0_processing_msc=processing_msc;r.t0_bid=bid;r.t0_ask=ask;r.t0_mid=(bid+ask)*0.5;
   r.atr_t0=atr_t0;r.tick_size=tick_size;r.tick_activity_t0=tick_activity_t0;r.high_mid=r.t0_mid;r.low_mid=r.t0_mid;r.last_mid=r.t0_mid;r.last_extreme_msc=t0_quote_msc;r.first_extreme_msc=t0_quote_msc;
   for(int c=0;c<TS15N_CHECKPOINTS;++c)r.checkpoint[c].target_msc=t0_msc+(long)TS15N_DELAY_SECONDS[c]*1000;
   pool.records[slot]=r;++pool.armed;return true;
  }

void TS15NObserveSecond(TickShock15NRecord &r,const long q,const double mid,const double spread,const double increment)
  {
   long sec=(q/1000)*1000;int idx=-1;
   if(r.second_count>0){int last=(r.second_head+r.second_count-1)%TS15N_SECOND_CAPACITY;if(r.seconds[last].second_msc==sec)idx=last;}
   if(idx<0){if(r.second_count<TS15N_SECOND_CAPACITY){idx=(r.second_head+r.second_count)%TS15N_SECOND_CAPACITY;++r.second_count;}else{idx=r.second_head;r.second_head=(r.second_head+1)%TS15N_SECOND_CAPACITY;}ZeroMemory(r.seconds[idx]);r.seconds[idx].second_msc=sec;r.seconds[idx].first_mid=mid;r.seconds[idx].high_mid=mid;r.seconds[idx].low_mid=mid;}
   TickShock15NSecond s=r.seconds[idx];s.last_mid=mid;s.high_mid=MathMax(s.high_mid,mid);s.low_mid=s.low_mid<=0.0?mid:MathMin(s.low_mid,mid);s.spread_sum+=spread;++s.ticks;s.path_abs+=MathAbs(increment);r.seconds[idx]=s;
  }

void TS15NRecent(const TickShock15NRecord &r,const long q,const int seconds,double &ret,long &ticks,double &path)
  {
   ret=0.0;ticks=0;path=0.0;double first=0.0,last=0.0;long from=q-(long)seconds*1000;
   for(int i=0;i<r.second_count;++i){int k=(r.second_head+i)%TS15N_SECOND_CAPACITY;TickShock15NSecond s=r.seconds[k];if(s.second_msc+999<from)continue;if(first<=0.0)first=s.first_mid;last=s.last_mid;ticks+=s.ticks;path+=s.path_abs;}
   if(first>0.0&&last>0.0)ret=last-first;
  }

void TS15NBuildDecision(TickShock15NRecord &r,const int c,const long q,const long p,const double bid,const double ask,const double atr,const long atr_source,const int max_lag_ms,const int submit_latency_ms)
  {
   TickShock15NCheckpoint s=r.checkpoint[c];s.decided=true;s.decision_quote_msc=q;s.decision_processing_msc=p;s.feature_max_source_msc=q;s.atr_source_msc=atr_source;s.checkpoint_quote_lag_ms=q-s.target_msc;s.decision_bid=bid;s.decision_ask=ask;s.decision_mid=(bid+ask)*0.5;s.atr_decision=atr;
   if(s.checkpoint_quote_lag_ms>max_lag_ms)s.status=TS15N_STALE_DECISION;else if(atr<=0.0||atr_source<=0||atr_source>p)s.status=TS15N_FEATURE_UNAVAILABLE;else s.status=TS15N_ELIGIBLE;
   double d=(s.decision_mid-r.t0_mid)*(double)r.shock_direction,range=MathMax(r.high_mid-r.low_mid,r.tick_size),elapsed=MathMax(1.0,(double)(q-r.t0_msc));
   s.postshock_return_atr=d/MathMax(atr,r.tick_size);s.postshock_mfe_atr=((r.shock_direction>0?r.high_mid-r.t0_mid:r.t0_mid-r.low_mid))/MathMax(atr,r.tick_size);s.postshock_mae_atr=((r.shock_direction>0?r.t0_mid-r.low_mid:r.high_mid-r.t0_mid))/MathMax(atr,r.tick_size);s.postshock_range_atr=range/MathMax(atr,r.tick_size);
   s.retracement_from_peak_pct=(r.high_mid-s.decision_mid)/range;s.retracement_from_trough_pct=(s.decision_mid-r.low_mid)/range;s.current_location_in_range=(s.decision_mid-r.low_mid)/range;
   s.new_extreme_count=r.new_extreme_count;s.origin_recross_count=r.origin_recross_count;s.time_since_last_extreme_ms=q-r.last_extreme_msc;s.distance_from_last_extreme_atr=MathMin(MathAbs(s.decision_mid-r.high_mid),MathAbs(s.decision_mid-r.low_mid))/MathMax(atr,r.tick_size);
   s.net_move_over_path_length=r.path_abs>0.0?MathAbs(s.decision_mid-r.t0_mid)/r.path_abs:0.0;s.shock_direction_tick_ratio=r.tick_count>0?(double)r.direction_ticks/(double)r.tick_count:0.0;s.direction_consistency=2.0*s.shock_direction_tick_ratio-1.0;s.realized_abs_move_atr=r.path_abs/MathMax(atr,r.tick_size);s.realized_volatility=MathSqrt(MathMax(0.0,r.squared_move_sum))/MathMax(atr,r.tick_size);
   double r5=0,r10=0,p5=0;long t5=0,t10=0;TS15NRecent(r,q,5,r5,t5,p5);double p10=0;TS15NRecent(r,q,10,r10,t10,p10);s.recent_5s_acceleration=(r5-(r10-r5))*(double)r.shock_direction/MathMax(atr,r.tick_size);s.recent_10s_acceleration=r10*(double)r.shock_direction/MathMax(atr,r.tick_size);
   s.peak_update_interval_ms=r.new_extreme_count>0?(double)(q-r.first_extreme_msc)/(double)r.new_extreme_count:elapsed;s.extreme_update_rate=1000.0*(double)r.new_extreme_count/elapsed;s.path_contraction_ratio=p10>0.0?p5/p10:0.0;s.path_expansion_ratio=r.path_abs>0.0?range/r.path_abs:0.0;
   double spread=ask-bid,mean_spread=r.tick_count>0?r.spread_sum/(double)r.tick_count:ask-bid;s.decision_spread_atr=spread/MathMax(atr,r.tick_size);s.spread_vs_t0_ratio=(r.t0_ask-r.t0_bid)>0.0?spread/(r.t0_ask-r.t0_bid):0.0;s.spread_vs_postshock_mean=mean_spread>0.0?spread/mean_spread:0.0;s.spread_contraction_from_t0=((r.t0_ask-r.t0_bid)-spread)/MathMax(atr,r.tick_size);
   s.tick_count_postshock=r.tick_count;s.tick_rate_recent_5s=(double)t5/5.0;s.tick_rate_recent_10s=(double)t10/10.0;s.tick_activity_vs_t0=r.tick_activity_t0>0.0?s.tick_rate_recent_10s/r.tick_activity_t0:0.0;s.activity_decay=s.tick_rate_recent_10s>0.0?s.tick_rate_recent_5s/s.tick_rate_recent_10s:0.0;s.activity_acceleration=s.tick_rate_recent_5s-s.tick_rate_recent_10s;
   for(int a=0;a<TS15N_ACTIONS;++a){s.action[a].direction=(a==0?r.shock_direction:-r.shock_direction);s.action[a].entry_eligible_msc=MathMax(q,p+(long)MathMax(0,submit_latency_ms));}
   r.checkpoint[c]=s;
  }

void TS15NEnterAction(TickShock15NAction &a,const long q,const long p,const double bid,const double ask,const double atr)
  {
   a.entered=true;a.entry_quote_msc=q;a.entry_processing_msc=p;a.entry_bid=bid;a.entry_ask=ask;a.risk_distance=0.25*atr;a.tp_distance=0.40*atr;
   if(a.direction>0){a.entry_price=ask;a.tp=ask+a.tp_distance;a.sl=ask-a.risk_distance;}else{a.entry_price=bid;a.tp=bid-a.tp_distance;a.sl=bid+a.risk_distance;}
  }

void TS15NEvaluateAction(TickShock15NAction &a,const long q,const double bid,const double ask,const long deadline)
  {
   if(!a.entered||a.done||q<=a.entry_quote_msc)return;double exit_side=a.direction>0?bid:ask;double move=(a.direction>0?exit_side-a.entry_price:a.entry_price-exit_side);a.mfe_r=MathMax(a.mfe_r,move/a.risk_distance);a.mae_r=MathMax(a.mae_r,-move/a.risk_distance);
   if(move>=a.tp_distance){a.done=true;a.result=TS15N_TP_FIRST;a.exit_msc=q;a.exit_price=a.direction>0?a.tp:a.tp;a.realized_r=1.6;return;}
   if(move<=-a.risk_distance){a.done=true;a.result=TS15N_SL_FIRST;a.exit_msc=q;a.exit_price=exit_side;a.realized_r=move/a.risk_distance;return;}
   if(q>=deadline){a.done=true;a.result=TS15N_TIMEOUT;a.exit_msc=q;a.exit_price=exit_side;a.realized_r=move/a.risk_distance;}
  }

void TS15NProcessQuote(TickShock15NRecord &r,const long q,const long p,const double bid,const double ask,const double atr,const long atr_source,const bool fallback,const int max_lag_ms,const int submit_latency_ms)
  {
   if(!r.active||r.complete)return;if(q<=0||p<q||bid<=0.0||ask<=bid||fallback){r.invalid=true;return;}double mid=(bid+ask)*0.5,inc=mid-r.last_mid;r.path_abs+=MathAbs(inc);r.squared_move_sum+=inc*inc;r.spread_sum+=ask-bid;++r.tick_count;if(inc*(double)r.shock_direction>0.0)++r.direction_ticks;
   int side=mid>r.t0_mid?1:(mid<r.t0_mid?-1:0);if(r.last_side!=0&&side!=0&&side!=r.last_side)++r.origin_recross_count;if(side!=0)r.last_side=side;
   if(mid>r.high_mid){r.high_mid=mid;++r.new_extreme_count;r.last_extreme_msc=q;if(r.first_extreme_msc<=r.t0_msc)r.first_extreme_msc=q;}if(mid<r.low_mid){r.low_mid=mid;++r.new_extreme_count;r.last_extreme_msc=q;if(r.first_extreme_msc<=r.t0_msc)r.first_extreme_msc=q;}TS15NObserveSecond(r,q,mid,ask-bid,inc);r.last_mid=mid;
   for(int c=0;c<TS15N_CHECKPOINTS;++c)
     {
      TickShock15NCheckpoint s=r.checkpoint[c];if(!s.decided&&q>=s.target_msc)TS15NBuildDecision(r,c,q,p,bid,ask,atr,atr_source,max_lag_ms,submit_latency_ms);s=r.checkpoint[c];
      if(s.decided&&s.status==TS15N_ELIGIBLE)
        {
         for(int a=0;a<TS15N_ACTIONS;++a){TickShock15NAction path=s.action[a];if(!path.entered&&q> s.decision_quote_msc&&q>=path.entry_eligible_msc){if(q>=r.deadline_msc){s.status=TS15N_ENTRY_AFTER_DEADLINE;break;}TS15NEnterAction(path,q,p,bid,ask,s.atr_decision);}TS15NEvaluateAction(path,q,bid,ask,r.deadline_msc);s.action[a]=path;}
         r.checkpoint[c]=s;
        }
     }
   if(q>=r.deadline_msc)
     {
      for(int c=0;c<TS15N_CHECKPOINTS;++c){TickShock15NCheckpoint s=r.checkpoint[c];if(!s.decided)s.status=TS15N_NO_DECISION_QUOTE;else if(s.status==TS15N_ELIGIBLE)for(int a=0;a<TS15N_ACTIONS;++a)if(!s.action[a].entered)s.status=TS15N_ENTRY_QUOTE_UNAVAILABLE;r.checkpoint[c]=s;}
      r.active=false;r.complete=true;r.write_pending=true;
     }
  }

void TS15NFlushPending(TickShock15NRecord &r,const int max_lag_ms,const int submit_latency_ms)
  {if(!r.pending_valid)return;long q=r.pending_quote_msc,p=r.pending_processing_msc,src=r.pending_atr_source_msc;double b=r.pending_bid,a=r.pending_ask,atr=r.pending_atr;bool f=r.pending_fallback;r.pending_valid=false;TS15NProcessQuote(r,q,p,b,a,atr,src,f,max_lag_ms,submit_latency_ms);}
void TS15NQueueQuote(TickShock15NRecord &r,const long q,const long p,const double bid,const double ask,const double atr,const long atr_source,const bool fallback,const int max_lag_ms,const int submit_latency_ms)
  {
   if(!r.active)return;if(!r.pending_valid){r.pending_valid=true;r.pending_quote_msc=q;r.pending_processing_msc=p;r.pending_bid=bid;r.pending_ask=ask;r.pending_atr=atr;r.pending_atr_source_msc=atr_source;r.pending_fallback=fallback;return;}
   if(q==r.pending_quote_msc){r.pending_processing_msc=MathMax(r.pending_processing_msc,p);r.pending_bid=bid;r.pending_ask=ask;r.pending_atr=atr;r.pending_atr_source_msc=atr_source;r.pending_fallback=r.pending_fallback||fallback;return;}if(q<r.pending_quote_msc){r.invalid=true;return;}TS15NFlushPending(r,max_lag_ms,submit_latency_ms);if(!r.active)return;r.pending_valid=true;r.pending_quote_msc=q;r.pending_processing_msc=p;r.pending_bid=bid;r.pending_ask=ask;r.pending_atr=atr;r.pending_atr_source_msc=atr_source;r.pending_fallback=fallback;
  }
void TS15NObservePool(TickShock15NPool &pool,const long q,const long p,const double bid,const double ask,const double atr,const long atr_source,const bool fallback,const int max_lag_ms,const int submit_latency_ms)
  {for(int i=0;i<TS15N_POOL_CAPACITY;++i)if(pool.records[i].active)TS15NQueueQuote(pool.records[i],q,p,bid,ask,atr,atr_source,fallback,max_lag_ms,submit_latency_ms);}
void TS15NFinalizePool(TickShock15NPool &pool,const int max_lag_ms,const int submit_latency_ms)
  {for(int i=0;i<TS15N_POOL_CAPACITY;++i){TickShock15NRecord r=pool.records[i];if(!r.active)continue;TS15NFlushPending(r,max_lag_ms,submit_latency_ms);if(r.active){for(int c=0;c<TS15N_CHECKPOINTS;++c){TickShock15NCheckpoint s=r.checkpoint[c];if(!s.decided)s.status=TS15N_NO_DECISION_QUOTE;else if(s.status==TS15N_ELIGIBLE){bool missing=false;for(int a=0;a<TS15N_ACTIONS;++a)if(!s.action[a].done)missing=true;if(missing)s.status=TS15N_PATH_CENSORED;}r.checkpoint[c]=s;}r.active=false;r.complete=true;r.write_pending=true;}pool.records[i]=r;}}

#endif
