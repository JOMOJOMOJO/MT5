#ifndef TICK_SHOCK_POST_SHOCK_EXCURSION_MQH
#define TICK_SHOCK_POST_SHOCK_EXCURSION_MQH

#include "TickShockEconomicPath.mqh"

#define TS15J_HORIZONS 8
#define TS15J_DISTANCES 8
#define TS15J_TP_CANDIDATES 4
#define TS15J_POOL_CAPACITY 8

const int TS15J_HORIZON_SECONDS[TS15J_HORIZONS]={30,60,120,300,600,900,1800,3600};
const double TS15J_DISTANCE_ATR[TS15J_DISTANCES]={0.10,0.20,0.30,0.40,0.50,0.75,1.00,1.50};
const double TS15J_TP_ATR[TS15J_TP_CANDIDATES]={0.20,0.30,0.40,0.50};

struct TickShock15JRecord
  {
   bool active;bool entered;bool complete;bool write_pending;bool written;bool invalid;bool censored;bool feature_valid;
   string episode_id;string event_id;string symbol;long market_cluster_id;int shock_direction;
   long statistical_msc;long confirmed_msc;long confirmed_quote_msc;long processing_msc;long t0_msc;
   long entry_quote_msc;long entry_processing_msc;double entry_bid;double entry_ask;double entry_spread;
   double atr14_m5;double spread_atr_t0;double tick_activity_ratio;long atr_source_msc;long feature_source_msc;
   double tick_size;double broker_stop_distance;double existing_risk;double existing_tp_distance;ENUM_TS15G_RISK_SOURCE existing_source;
   double continuation_mfe;double continuation_mae;double reversal_mfe;double reversal_mae;
   double continuation_mfe_h[TS15J_HORIZONS];double continuation_mae_h[TS15J_HORIZONS];
   double reversal_mfe_h[TS15J_HORIZONS];double reversal_mae_h[TS15J_HORIZONS];
   long horizon_quote_msc[TS15J_HORIZONS];bool horizon_done[TS15J_HORIZONS];
   long continuation_hit_ms[TS15J_DISTANCES];long reversal_hit_ms[TS15J_DISTANCES];
   double continuation_pre_tp_mae[TS15J_TP_CANDIDATES];double reversal_pre_tp_mae[TS15J_TP_CANDIDATES];
   bool pending_valid;long pending_quote_msc;long pending_processing_msc;double pending_bid;double pending_ask;bool pending_fallback;
   long quote_count;long duplicate_same_msc;long future_reads;long backdates;long fallback_quotes;
  };

struct TickShock15JPool
  {TickShock15JRecord records[TS15J_POOL_CAPACITY];long armed;long completed;long censored;long capacity_hits;long invalid_paths;};

string TS15JSchema(){return "tickshock-post-shock-excursion-v1";}
void TS15JResetRecord(TickShock15JRecord &r){ZeroMemory(r);r.existing_source=TS15G_RISK_INVALID;for(int i=0;i<TS15J_DISTANCES;++i){r.continuation_hit_ms[i]=-1;r.reversal_hit_ms[i]=-1;}}
void TS15JResetPool(TickShock15JPool &p){ZeroMemory(p);for(int i=0;i<TS15J_POOL_CAPACITY;++i)TS15JResetRecord(p.records[i]);}

bool TS15JArm(TickShock15JPool &pool,const string episode_id,const string event_id,const string symbol,const long cluster_id,const int direction,
              const long statistical_msc,const long confirmed_msc,const long confirmed_quote_msc,const long processing_msc,
              const double atr14_m5,const double spread_atr_t0,const double tick_activity_ratio,const long feature_source_msc,
              const double tick_size,const double broker_stop_distance)
  {
   if(episode_id==""||event_id==""||symbol==""||direction==0||statistical_msc<=0||confirmed_msc<statistical_msc||confirmed_quote_msc>confirmed_msc||processing_msc<confirmed_msc||tick_size<=0.0)return false;
   for(int i=0;i<TS15J_POOL_CAPACITY;++i)if((pool.records[i].active||pool.records[i].write_pending)&&pool.records[i].episode_id==episode_id)return false;
   int slot=-1;for(int i=0;i<TS15J_POOL_CAPACITY;++i)if(!pool.records[i].active&&!pool.records[i].write_pending){slot=i;break;}
   if(slot<0){++pool.capacity_hits;return false;}
   TickShock15JRecord r;TS15JResetRecord(r);r.active=true;r.episode_id=episode_id;r.event_id=event_id;r.symbol=symbol;r.market_cluster_id=cluster_id;r.shock_direction=direction>0?1:-1;
   r.statistical_msc=statistical_msc;r.confirmed_msc=confirmed_msc;r.confirmed_quote_msc=confirmed_quote_msc;r.processing_msc=processing_msc;r.t0_msc=processing_msc;
   r.atr14_m5=atr14_m5;r.spread_atr_t0=spread_atr_t0;r.tick_activity_ratio=tick_activity_ratio;r.atr_source_msc=feature_source_msc;r.feature_source_msc=feature_source_msc;r.feature_valid=atr14_m5>0.0&&feature_source_msc>0&&feature_source_msc<=processing_msc;
   r.tick_size=tick_size;r.broker_stop_distance=MathMax(0.0,broker_stop_distance);pool.records[slot]=r;++pool.armed;return true;
  }

double TS15JMove(const int direction,const double entry_bid,const double entry_ask,const double bid,const double ask)
  {return direction>0?bid-entry_ask:entry_bid-ask;}

void TS15JProcessQuote(TickShock15JRecord &r,const long quote_msc,const long processing_msc,const double bid,const double ask,const bool fallback)
  {
   if(!r.active||r.complete)return;
   if(quote_msc<=0||bid<=0.0||ask<bid){r.invalid=true;r.complete=true;r.write_pending=true;return;}
   if(processing_msc<quote_msc){++r.future_reads;r.invalid=true;return;}
   if(!r.entered)
     {
      if(quote_msc<=r.confirmed_quote_msc||quote_msc<r.t0_msc)return;
      if(fallback){++r.fallback_quotes;r.invalid=true;r.complete=true;r.write_pending=true;return;}
      r.entered=true;r.entry_quote_msc=quote_msc;r.entry_processing_msc=processing_msc;r.entry_bid=bid;r.entry_ask=ask;r.entry_spread=ask-bid;
      if(r.feature_valid)TS15GRiskDistance(r.atr14_m5,r.entry_spread,r.broker_stop_distance,r.existing_risk,r.existing_source);
      TickShock15GPath geometry;TS15GResetPath(geometry);geometry.direction=r.shock_direction;geometry.entry_price=r.shock_direction>0?ask:bid;geometry.entry_spread=r.entry_spread;geometry.atr14_m5=r.atr14_m5;geometry.broker_stop_distance=r.broker_stop_distance;geometry.tick_size=r.tick_size;geometry.rr_index=1;
      if(r.feature_valid&&TS15GBuildBarriers(geometry)){r.existing_risk=geometry.risk_distance;r.existing_tp_distance=MathAbs(geometry.tp-geometry.entry_price);r.existing_source=geometry.risk_source;}
      return;
     }
   if(quote_msc<r.entry_quote_msc){++r.backdates;r.invalid=true;return;}
   if(fallback){++r.fallback_quotes;r.invalid=true;return;}
   ++r.quote_count;double cm=TS15JMove(r.shock_direction,r.entry_bid,r.entry_ask,bid,ask);double rm=TS15JMove(-r.shock_direction,r.entry_bid,r.entry_ask,bid,ask);
   r.continuation_mfe=MathMax(r.continuation_mfe,cm);r.continuation_mae=MathMax(r.continuation_mae,-cm);r.reversal_mfe=MathMax(r.reversal_mfe,rm);r.reversal_mae=MathMax(r.reversal_mae,-rm);
   long elapsed=quote_msc-r.entry_quote_msc;
   for(int d=0;d<TS15J_DISTANCES;++d)
     {
      if(!r.feature_valid)continue;double target=TS15J_DISTANCE_ATR[d]*r.atr14_m5;
      if(r.continuation_hit_ms[d]<0&&cm>=target)r.continuation_hit_ms[d]=elapsed;
      if(r.reversal_hit_ms[d]<0&&rm>=target)r.reversal_hit_ms[d]=elapsed;
     }
   for(int t=0;t<TS15J_TP_CANDIDATES;++t){int d=t+1;if(r.continuation_hit_ms[d]<0)r.continuation_pre_tp_mae[t]=MathMax(r.continuation_pre_tp_mae[t],-cm);if(r.reversal_hit_ms[d]<0)r.reversal_pre_tp_mae[t]=MathMax(r.reversal_pre_tp_mae[t],-rm);}
   for(int h=0;h<TS15J_HORIZONS;++h)if(!r.horizon_done[h]&&quote_msc>=r.t0_msc+(long)TS15J_HORIZON_SECONDS[h]*1000)
     {r.horizon_done[h]=true;r.horizon_quote_msc[h]=quote_msc;r.continuation_mfe_h[h]=r.continuation_mfe;r.continuation_mae_h[h]=r.continuation_mae;r.reversal_mfe_h[h]=r.reversal_mfe;r.reversal_mae_h[h]=r.reversal_mae;}
   if(r.horizon_done[TS15J_HORIZONS-1]){r.complete=true;r.active=false;r.write_pending=true;}
  }

void TS15JFlushPending(TickShock15JRecord &r)
  {if(!r.pending_valid)return;long q=r.pending_quote_msc,p=r.pending_processing_msc;double b=r.pending_bid,a=r.pending_ask;bool f=r.pending_fallback;r.pending_valid=false;TS15JProcessQuote(r,q,p,b,a,f);}

void TS15JQueueQuote(TickShock15JRecord &r,const long quote_msc,const long processing_msc,const double bid,const double ask,const bool fallback)
  {
   if(!r.active)return;if(!r.pending_valid){r.pending_valid=true;r.pending_quote_msc=quote_msc;r.pending_processing_msc=processing_msc;r.pending_bid=bid;r.pending_ask=ask;r.pending_fallback=fallback;return;}
   if(quote_msc==r.pending_quote_msc){r.pending_processing_msc=processing_msc;r.pending_bid=bid;r.pending_ask=ask;r.pending_fallback=r.pending_fallback||fallback;++r.duplicate_same_msc;return;}
   if(quote_msc<r.pending_quote_msc){++r.backdates;r.invalid=true;return;}TS15JFlushPending(r);if(!r.active)return;r.pending_valid=true;r.pending_quote_msc=quote_msc;r.pending_processing_msc=processing_msc;r.pending_bid=bid;r.pending_ask=ask;r.pending_fallback=fallback;
  }

void TS15JObservePool(TickShock15JPool &pool,const long quote_msc,const long processing_msc,const double bid,const double ask,const bool fallback)
  {for(int i=0;i<TS15J_POOL_CAPACITY;++i)if(pool.records[i].active)TS15JQueueQuote(pool.records[i],quote_msc,processing_msc,bid,ask,fallback);}

void TS15JFinalizePool(TickShock15JPool &pool)
  {for(int i=0;i<TS15J_POOL_CAPACITY;++i){TickShock15JRecord r=pool.records[i];if(!r.active)continue;TS15JFlushPending(r);if(r.active){r.active=false;r.complete=true;r.censored=true;r.write_pending=true;++pool.censored;}pool.records[i]=r;}}

#endif
