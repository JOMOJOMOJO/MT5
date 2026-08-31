#ifndef TICK_SHOCK_ECONOMIC_PATH_MQH
#define TICK_SHOCK_ECONOMIC_PATH_MQH

#define TS15G_DECISIONS 2
#define TS15G_ACTIONS 2
#define TS15G_RRS 4
#define TS15G_HORIZONS 3
#define TS15G_PATHS 48

const int TS15G_DECISION_SECONDS[TS15G_DECISIONS]={60,120};
const int TS15G_HORIZON_SECONDS[TS15G_HORIZONS]={300,600,900};
const double TS15G_RR_VALUES[TS15G_RRS]={1.0,1.2,1.5,2.0};
const double TS15G_ATR_FRACTION=0.25;
const double TS15G_SPREAD_MULTIPLE=4.0;
const double TS15G_STRESS_SPREAD_MULTIPLE=1.25;
const double TS15G_STRESS_SLIPPAGE_TICKS=1.0;
const long TS15G_MAX_QUOTE_AGE_MS=1000;

enum ENUM_TS15G_ACTION { TS15G_CONTINUATION=0,TS15G_REVERSAL=1 };
enum ENUM_TS15G_RESULT { TS15G_PENDING=0,TS15G_TP_FIRST,TS15G_SL_FIRST,TS15G_TIMEOUT,TS15G_AMBIGUOUS_SAME_TICK,TS15G_INVALID_PATH };
enum ENUM_TS15G_RISK_SOURCE { TS15G_RISK_INVALID=0,TS15G_RISK_ATR14_M5,TS15G_RISK_ENTRY_SPREAD,TS15G_RISK_BROKER_STOP };
enum ENUM_TS15G_EPISODE_CLASS { TS15G_CLASS_INVALID=0,TS15G_CLASS_CONT_ONLY,TS15G_CLASS_REV_ONLY,TS15G_CLASS_BOTH,TS15G_CLASS_NEITHER,TS15G_CLASS_AMBIGUOUS };

struct TickShock15GPath
  {
   bool armed;bool entered;bool done;bool fallback;bool pending_touch;bool pending_tp;bool pending_sl;
   int decision_index;ENUM_TS15G_ACTION action;int direction;int rr_index;int horizon_index;
   long anchor_msc;long signal_quote_msc;long signal_processing_msc;long entry_quote_msc;long entry_processing_msc;long horizon_msc;
   long pending_touch_msc;long exit_msc;long quote_age_ms;long time_to_mfe_ms;long time_to_mae_ms;
   double entry_bid;double entry_ask;double entry_price;double entry_spread;double atr14_m5;double broker_stop_distance;double tick_size;
   double risk_distance;ENUM_TS15G_RISK_SOURCE risk_source;double sl;double tp;double realized_rr;
   double pending_bid;double pending_ask;double exit_bid;double exit_ask;double exit_price;double mfe;double mae;
   double gross_r;double spread_only_r;double stressed_r;double commission_r;double break_even_additional_cost_r;
   ENUM_TS15G_RESULT result;string invalid_reason;
  };

struct TickShock15GContext
  {
   bool active;bool write_pending;bool invalid;string subject_id;string subject_type;string symbol;long market_cluster_id;int shock_direction;long anchor_msc;
   bool decision_armed[TS15G_DECISIONS];TickShock15GPath paths[TS15G_PATHS];long rows_written;long future_reads;long backdates;long fallback_quotes;long stale_quotes;
  };

string TS15GSchema(){return "tickshock-economic-path-v1";}
string TS15GFeatureHash(){return "074C40B21F804CEDB414FA0C75DD1A101B7DF808F6254000B641C134C282B597";}
string TS15GLabelSpecHash(){return "0DDA57592D4B9067AD6CBC4386C257A1B4F6D8B81B7BFF6188B2919D1D10E072";}
string TS15GActionName(const ENUM_TS15G_ACTION value){return value==TS15G_REVERSAL?"REVERSAL":"CONTINUATION";}
string TS15GResultName(const ENUM_TS15G_RESULT value){if(value==TS15G_TP_FIRST)return "TP_FIRST";if(value==TS15G_SL_FIRST)return "SL_FIRST";if(value==TS15G_TIMEOUT)return "TIMEOUT";if(value==TS15G_AMBIGUOUS_SAME_TICK)return "AMBIGUOUS_SAME_TICK";if(value==TS15G_INVALID_PATH)return "INVALID_PATH";return "PENDING";}
string TS15GRiskSourceName(const ENUM_TS15G_RISK_SOURCE value){if(value==TS15G_RISK_ATR14_M5)return "ATR14_M5";if(value==TS15G_RISK_ENTRY_SPREAD)return "ENTRY_SPREAD";if(value==TS15G_RISK_BROKER_STOP)return "BROKER_STOP";return "INVALID";}
string TS15GEpisodeClassName(const ENUM_TS15G_EPISODE_CLASS value){if(value==TS15G_CLASS_CONT_ONLY)return "CONT_ONLY";if(value==TS15G_CLASS_REV_ONLY)return "REV_ONLY";if(value==TS15G_CLASS_BOTH)return "BOTH";if(value==TS15G_CLASS_NEITHER)return "NEITHER";if(value==TS15G_CLASS_AMBIGUOUS)return "AMBIGUOUS";return "INVALID";}

int TS15GPathIndex(const int decision_index,const int action,const int rr_index,const int horizon_index)
  {return (((decision_index*TS15G_ACTIONS+action)*TS15G_RRS+rr_index)*TS15G_HORIZONS+horizon_index);}
double TS15GRoundDown(const double price,const double tick_size){return tick_size>0.0?MathFloor((price+1e-12)/tick_size)*tick_size:0.0;}
double TS15GRoundUp(const double price,const double tick_size){return tick_size>0.0?MathCeil((price-1e-12)/tick_size)*tick_size:0.0;}
int TS15GActionDirection(const int shock_direction,const ENUM_TS15G_ACTION action){if(shock_direction==0)return 0;int d=shock_direction>0?1:-1;return action==TS15G_REVERSAL?-d:d;}

void TS15GResetPath(TickShock15GPath &path){ZeroMemory(path);path.result=TS15G_PENDING;path.risk_source=TS15G_RISK_INVALID;}
void TS15GResetContext(TickShock15GContext &context){ZeroMemory(context);for(int i=0;i<TS15G_PATHS;++i)TS15GResetPath(context.paths[i]);}

bool TS15GRiskDistance(const double atr14_m5,const double entry_spread,const double broker_stop_distance,double &risk,ENUM_TS15G_RISK_SOURCE &source)
  {
   risk=0.0;source=TS15G_RISK_INVALID;if(!MathIsValidNumber(atr14_m5)||!MathIsValidNumber(entry_spread)||!MathIsValidNumber(broker_stop_distance)||atr14_m5<=0.0||entry_spread<=0.0||broker_stop_distance<0.0)return false;
   double a=atr14_m5*TS15G_ATR_FRACTION,s=entry_spread*TS15G_SPREAD_MULTIPLE,b=broker_stop_distance;risk=a;source=TS15G_RISK_ATR14_M5;
   if(s>risk){risk=s;source=TS15G_RISK_ENTRY_SPREAD;}if(b>risk){risk=b;source=TS15G_RISK_BROKER_STOP;}return risk>0.0&&MathIsValidNumber(risk);
  }

bool TS15GBuildBarriers(TickShock15GPath &path)
  {
   double raw_risk=0.0;ENUM_TS15G_RISK_SOURCE source=TS15G_RISK_INVALID;
   if(path.direction==0||path.tick_size<=0.0||!TS15GRiskDistance(path.atr14_m5,path.entry_spread,path.broker_stop_distance,raw_risk,source)){path.invalid_reason="INVALID_RISK";return false;}
   if(path.direction>0){path.sl=TS15GRoundDown(path.entry_price-raw_risk,path.tick_size);path.risk_distance=path.entry_price-path.sl;path.tp=TS15GRoundUp(path.entry_price+path.risk_distance*TS15G_RR_VALUES[path.rr_index],path.tick_size);}
   else {path.sl=TS15GRoundUp(path.entry_price+raw_risk,path.tick_size);path.risk_distance=path.sl-path.entry_price;path.tp=TS15GRoundDown(path.entry_price-path.risk_distance*TS15G_RR_VALUES[path.rr_index],path.tick_size);}
   if(path.risk_distance<=0.0){path.invalid_reason="INVALID_ROUNDED_RISK";return false;}path.realized_rr=MathAbs(path.tp-path.entry_price)/path.risk_distance;path.risk_source=source;
   if(path.realized_rr+1e-9<TS15G_RR_VALUES[path.rr_index]){path.invalid_reason="RR_ROUNDING_VIOLATION";return false;}return true;
  }

bool TS15GArmDecision(TickShock15GContext &context,const string subject_id,const string subject_type,const string symbol,const long market_cluster_id,const int shock_direction,const long anchor_msc,const int decision_index,const long signal_quote_msc,const long signal_processing_msc,const double atr14_m5,const double tick_size,const double broker_stop_distance)
  {
   if(subject_id==""||symbol==""||shock_direction==0||anchor_msc<=0||decision_index<0||decision_index>=TS15G_DECISIONS||signal_quote_msc<=0||signal_processing_msc<signal_quote_msc||tick_size<=0.0)return false;
   if(!context.active){TS15GResetContext(context);context.active=true;context.subject_id=subject_id;context.subject_type=subject_type;context.symbol=symbol;context.market_cluster_id=market_cluster_id;context.shock_direction=shock_direction>0?1:-1;context.anchor_msc=anchor_msc;}
   if(context.subject_id!=subject_id||context.symbol!=symbol||context.shock_direction!=(shock_direction>0?1:-1)||context.decision_armed[decision_index])return false;
   for(int action=0;action<TS15G_ACTIONS;++action)for(int rr=0;rr<TS15G_RRS;++rr)for(int horizon=0;horizon<TS15G_HORIZONS;++horizon)
     {int index=TS15GPathIndex(decision_index,action,rr,horizon);TickShock15GPath p;TS15GResetPath(p);p.armed=true;p.decision_index=decision_index;p.action=(ENUM_TS15G_ACTION)action;p.direction=TS15GActionDirection(context.shock_direction,p.action);p.rr_index=rr;p.horizon_index=horizon;p.anchor_msc=anchor_msc;p.signal_quote_msc=signal_quote_msc;p.signal_processing_msc=signal_processing_msc;p.horizon_msc=anchor_msc+(long)TS15G_HORIZON_SECONDS[horizon]*1000;p.atr14_m5=atr14_m5;p.tick_size=tick_size;p.broker_stop_distance=MathMax(0.0,broker_stop_distance);context.paths[index]=p;}
   context.decision_armed[decision_index]=true;return true;
  }

void TS15GInvalidate(TickShock15GPath &path,const string reason)
  {path.done=true;path.result=TS15G_INVALID_PATH;path.invalid_reason=reason;}

void TS15GInvalidateDecision(TickShock15GContext &context,const int decision_index,const string reason)
  {for(int action=0;action<TS15G_ACTIONS;++action)for(int rr=0;rr<TS15G_RRS;++rr)for(int horizon=0;horizon<TS15G_HORIZONS;++horizon){int index=TS15GPathIndex(decision_index,action,rr,horizon);if(context.paths[index].armed)TS15GInvalidate(context.paths[index],reason);}}

void TS15GFinalizePendingTouch(TickShock15GPath &path)
  {
   if(!path.pending_touch||path.done)return;path.exit_msc=path.pending_touch_msc;path.exit_bid=path.pending_bid;path.exit_ask=path.pending_ask;
   if(path.pending_sl){path.result=TS15G_SL_FIRST;path.exit_price=path.direction>0?path.pending_bid:path.pending_ask;path.gross_r=-MathAbs(path.exit_price-path.entry_price)/path.risk_distance;}
   else {path.result=TS15G_TP_FIRST;path.exit_price=path.tp;path.gross_r=path.realized_rr;}
   path.spread_only_r=path.gross_r;double exit_spread=MathMax(0.0,path.pending_ask-path.pending_bid);double extra_spread=(path.entry_spread+exit_spread)*(TS15G_STRESS_SPREAD_MULTIPLE-1.0)*0.5;double slippage=2.0*path.tick_size*TS15G_STRESS_SLIPPAGE_TICKS;path.stressed_r=path.gross_r-(extra_spread+slippage)/path.risk_distance-path.commission_r;path.break_even_additional_cost_r=MathMax(0.0,path.spread_only_r);path.done=true;path.pending_touch=false;
  }

void TS15GObservePath(TickShock15GPath &path,const long quote_msc,const long processing_msc,const double bid,const double ask,const bool fallback)
  {
   if(!path.armed||path.done)return;if(quote_msc<=0||bid<=0.0||ask<=bid){TS15GInvalidate(path,"INVALID_QUOTE");return;}if(processing_msc<quote_msc){TS15GInvalidate(path,"FUTURE_READ");return;}
   if(path.pending_touch&&quote_msc>path.pending_touch_msc){TS15GFinalizePendingTouch(path);if(path.done)return;}
   if(!path.entered)
     {
      if(quote_msc<=path.signal_quote_msc||quote_msc<path.signal_processing_msc)return;if(fallback){path.fallback=true;TS15GInvalidate(path,"FALLBACK_ENTRY_QUOTE");return;}
      path.entered=true;path.entry_quote_msc=quote_msc;path.entry_processing_msc=processing_msc;path.quote_age_ms=processing_msc-quote_msc;path.entry_bid=bid;path.entry_ask=ask;path.entry_spread=ask-bid;path.entry_price=path.direction>0?ask:bid;if(!TS15GBuildBarriers(path)){TS15GInvalidate(path,path.invalid_reason);return;}return;
     }
   if(quote_msc<path.entry_quote_msc){TS15GInvalidate(path,"BACKDATE");return;}if(fallback){path.fallback=true;TS15GInvalidate(path,"FALLBACK_PATH_QUOTE");return;}path.quote_age_ms=MathMax(path.quote_age_ms,processing_msc-quote_msc);
   double side=path.direction>0?bid:ask;double move=(side-path.entry_price)*(double)path.direction;if(move>path.mfe){path.mfe=move;path.time_to_mfe_ms=quote_msc-path.entry_quote_msc;}if(-move>path.mae){path.mae=-move;path.time_to_mae_ms=quote_msc-path.entry_quote_msc;}
   bool tp=path.direction>0?side>=path.tp:side<=path.tp;bool sl=path.direction>0?side<=path.sl:side>=path.sl;
   if(tp||sl){if(!path.pending_touch){path.pending_touch=true;path.pending_touch_msc=quote_msc;}if(quote_msc==path.pending_touch_msc){path.pending_tp=path.pending_tp||tp;path.pending_sl=path.pending_sl||sl;path.pending_bid=bid;path.pending_ask=ask;}return;}
   if(quote_msc>=path.horizon_msc){path.exit_msc=quote_msc;path.exit_bid=bid;path.exit_ask=ask;path.exit_price=side;path.gross_r=move/path.risk_distance;path.spread_only_r=path.gross_r;double extra_spread=(path.entry_spread+(ask-bid))*(TS15G_STRESS_SPREAD_MULTIPLE-1.0)*0.5;double slippage=2.0*path.tick_size*TS15G_STRESS_SLIPPAGE_TICKS;path.stressed_r=path.gross_r-(extra_spread+slippage)/path.risk_distance-path.commission_r;path.break_even_additional_cost_r=MathMax(0.0,path.spread_only_r);path.result=TS15G_TIMEOUT;path.done=true;}
  }

void TS15GObserveContext(TickShock15GContext &context,const long quote_msc,const long processing_msc,const double bid,const double ask,const bool fallback)
  {if(!context.active)return;for(int i=0;i<TS15G_PATHS;++i)TS15GObservePath(context.paths[i],quote_msc,processing_msc,bid,ask,fallback);}

void TS15GFinalizeContext(TickShock15GContext &context,const string reason)
  {if(!context.active)return;for(int i=0;i<TS15G_PATHS;++i){if(context.paths[i].pending_touch)TS15GFinalizePendingTouch(context.paths[i]);if(context.paths[i].armed&&!context.paths[i].done)TS15GInvalidate(context.paths[i],reason);}context.write_pending=true;}

ENUM_TS15G_EPISODE_CLASS TS15GClassify(const ENUM_TS15G_RESULT continuation,const ENUM_TS15G_RESULT reversal)
  {
   if(continuation==TS15G_INVALID_PATH||reversal==TS15G_INVALID_PATH)return TS15G_CLASS_INVALID;if(continuation==TS15G_AMBIGUOUS_SAME_TICK||reversal==TS15G_AMBIGUOUS_SAME_TICK)return TS15G_CLASS_AMBIGUOUS;bool c=continuation==TS15G_TP_FIRST,r=reversal==TS15G_TP_FIRST;if(c&&r)return TS15G_CLASS_BOTH;if(c)return TS15G_CLASS_CONT_ONLY;if(r)return TS15G_CLASS_REV_ONLY;return TS15G_CLASS_NEITHER;
  }

#endif
