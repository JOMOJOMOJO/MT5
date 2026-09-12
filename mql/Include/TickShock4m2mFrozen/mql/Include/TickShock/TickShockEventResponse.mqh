#ifndef TICK_SHOCK_EVENT_RESPONSE_MQH
#define TICK_SHOCK_EVENT_RESPONSE_MQH

#define TS15C_HORIZON_COUNT 11
#define TS15C_BARRIER_COUNT 3
#define TS15C_STALE_LIMIT_MS 1000
#define TS15C_RESPONSE_WINDOW_MS 120000
#define TS15C_RR_COUNT 5

const int TS15C_HORIZONS_MS[TS15C_HORIZON_COUNT]={250,500,1000,2000,3000,5000,10000,15000,30000,60000,120000};
const double TS15C_LOCAL_BARRIERS[TS15C_BARRIER_COUNT]={0.5,1.0,2.0};
const double TS15C_RESEARCH_RR[TS15C_RR_COUNT]={0.8,1.0,1.2,1.5,2.0};

enum ENUM_TS15C_SNAPSHOT_STATUS
  {
   TS15C_SNAPSHOT_PENDING=0,
   TS15C_SNAPSHOT_VALID=1,
   TS15C_SNAPSHOT_STALE=2,
   TS15C_SNAPSHOT_MISSING_END=3
  };

enum ENUM_TS15C_BARRIER_RESULT
  {
   TS15C_BARRIER_NONE=0,
   TS15C_BARRIER_CONTINUATION=1,
   TS15C_BARRIER_REVERSAL=2,
   TS15C_BARRIER_AMBIGUOUS=3,
   TS15C_BARRIER_TIMEOUT=4
  };

struct TickShockResponseSnapshot
  {
   int horizon_ms;
   ENUM_TS15C_SNAPSHOT_STATUS status;
   long target_msc;
   long boundary_msc;
   long quote_msc;
   long target_lag_ms;
   int quote_age_ms;
   double bid;
   double ask;
   double mid;
   double raw_log_return;
   double continuation_return;
   double absolute_return;
   double spread;
  };

struct TickShockEventResponseState
  {
   bool initialized;
   int direction;
   long candidate_msc;
   long confirmed_msc;
   double reference_bid;
   double reference_ask;
   double reference_mid;
   long reference_quote_msc;
   double origin_mid;
   double local_sigma;
   double initial_shock_size;
   double point;
   double tick_size;
   TickShockResponseSnapshot snapshots[TS15C_HORIZON_COUNT];
   double mfe;
   double mae;
   long time_to_mfe_ms;
   long time_to_mae_ms;
   long origin_recross_msc;
   ENUM_TS15C_BARRIER_RESULT barrier_result[TS15C_BARRIER_COUNT];
   long continuation_hit_msc[TS15C_BARRIER_COUNT];
   long reversal_hit_msc[TS15C_BARRIER_COUNT];
   long observations;
   long duplicates;
   long drops;
   bool pending_valid;
   long pending_msc;
   double pending_bid;
   double pending_ask;
   bool censored;
   bool validation_invalid;
  };

string TS15CSnapshotStatusName(const ENUM_TS15C_SNAPSHOT_STATUS value)
  {
   if(value==TS15C_SNAPSHOT_VALID) return "VALID";
   if(value==TS15C_SNAPSHOT_STALE) return "STALE";
   if(value==TS15C_SNAPSHOT_MISSING_END) return "MISSING_END";
   return "PENDING";
  }

string TS15CBarrierResultName(const ENUM_TS15C_BARRIER_RESULT value)
  {
   if(value==TS15C_BARRIER_CONTINUATION) return "CONTINUATION_FIRST";
   if(value==TS15C_BARRIER_REVERSAL) return "REVERSAL_FIRST";
   if(value==TS15C_BARRIER_AMBIGUOUS) return "AMBIGUOUS";
   if(value==TS15C_BARRIER_TIMEOUT) return "TIMEOUT";
   return "NONE";
  }

int TS15CDirectionSign(const int direction)
  {
   if(direction>0) return 1;
   if(direction<0) return -1;
   return 0;
  }

bool TS15CContinuationReturn(const double start_mid,const double end_mid,const int direction,double &result)
  {
   result=0.0;int sign=TS15CDirectionSign(direction);
   if(sign==0 || start_mid<=0.0 || end_mid<=0.0) return false;
   result=(double)sign*MathLog(end_mid/start_mid);
   return MathIsValidNumber(result);
  }

double TS15CEntryPrice(const int direction,const double bid,const double ask)
  { return direction>0?ask:(direction<0?bid:0.0); }

double TS15CExitPrice(const int direction,const double bid,const double ask)
  { return direction>0?bid:(direction<0?ask:0.0); }

void TS15CStressSpread(const double mid,const double base_spread,const double multiplier,double &bid,double &ask)
  { double spread=MathMax(0.0,base_spread)*MathMax(0.0,multiplier);bid=mid-spread*0.5;ask=mid+spread*0.5; }

double TS15CTimeoutR(const int direction,const double entry,const double exit_price,const double risk)
  { return TS15CDirectionSign(direction)==0 || risk<=0.0?0.0:(exit_price-entry)*(double)TS15CDirectionSign(direction)/risk; }

long TS15CEligibleMsc(const long signal_msc,const long processing_msc,const int delay_ms,const int submit_latency_ms)
  { return MathMax(signal_msc+(long)MathMax(0,delay_ms),processing_msc+(long)MathMax(0,submit_latency_ms)); }

bool TS15CWindowOverlaps(const long left_start,const long right_start,const long window_ms=TS15C_RESPONSE_WINDOW_MS)
  { return left_start>=0 && right_start>=0 && right_start<=left_start+window_ms; }

bool TS15CPreferRepresentative(const long candidate_msc,const string candidate_id,const long selected_msc,const string selected_id)
  { return selected_id=="" || candidate_msc<selected_msc || (candidate_msc==selected_msc && candidate_id<selected_id); }

string TS15CCandidateCanonical(const string detector,const string strategy,const double stop,const double rr,const int delay,const double spread)
  { return StringFormat("detector=%s;strategy=%s;stop=%.6f;rr=%.6f;delay=%d;spread=%.6f",detector,strategy,stop,rr,delay,spread); }

bool TS15CProvenanceMatches(const string schema,const string spec_hash)
  { return schema=="tickshock-event-response-v1" && StringLen(spec_hash)==64; }

int TS15CGateMask(const bool statistical_shock,const bool direction_available,const bool directional_burst,
                  const bool activity,const bool liquidity,const bool cost,const bool efficiency,const bool persistence)
  {
   int mask=0;if(statistical_shock)mask|=1;if(direction_available)mask|=2;if(directional_burst)mask|=4;
   if(activity)mask|=8;if(liquidity)mask|=16;if(cost)mask|=32;if(efficiency)mask|=64;if(persistence)mask|=128;
   return mask;
  }

bool TS15CLeaveOneGateOutReachable(const int mask,const int removed_bit,const int required_mask=255)
  { return (mask|(removed_bit&required_mask))==required_mask; }

ENUM_TS15C_BARRIER_RESULT TS15CResolveBarrierTouch(const bool continuation_touch,const bool reversal_touch)
  {
   if(continuation_touch && reversal_touch) return TS15C_BARRIER_AMBIGUOUS;
   if(continuation_touch) return TS15C_BARRIER_CONTINUATION;
   if(reversal_touch) return TS15C_BARRIER_REVERSAL;
   return TS15C_BARRIER_NONE;
  }

void TS15CResetResponse(TickShockEventResponseState &state)
  { ZeroMemory(state); }

bool TS15CInitResponse(TickShockEventResponseState &state,const long candidate_msc,const long confirmed_msc,
                       const int direction,const double origin_mid,const double bid,const double ask,
                       const double local_sigma,const double point,const double tick_size)
  {
   TS15CResetResponse(state);int sign=TS15CDirectionSign(direction);
   if(sign==0 || candidate_msc<0 || confirmed_msc<candidate_msc || bid<=0.0 || ask<bid || local_sigma<=0.0) return false;
   state.initialized=true;state.direction=sign;state.candidate_msc=candidate_msc;state.confirmed_msc=confirmed_msc;
   state.reference_bid=bid;state.reference_ask=ask;state.reference_mid=(bid+ask)*0.5;state.origin_mid=origin_mid;
   state.reference_quote_msc=confirmed_msc;
   state.local_sigma=local_sigma;state.initial_shock_size=MathAbs(state.reference_mid-origin_mid);state.point=point;state.tick_size=tick_size;
   for(int i=0;i<TS15C_HORIZON_COUNT;++i)
     {state.snapshots[i].horizon_ms=TS15C_HORIZONS_MS[i];state.snapshots[i].target_msc=confirmed_msc+(long)TS15C_HORIZONS_MS[i];state.snapshots[i].status=TS15C_SNAPSHOT_PENDING;}
   return true;
  }

bool TS15CArmResponse(TickShockEventResponseState &state,const long candidate_msc,const long confirmed_msc,
                      const int direction,const double origin_mid,const double local_sigma,
                      const double point,const double tick_size)
  {
   TS15CResetResponse(state);int sign=TS15CDirectionSign(direction);
   if(sign==0 || candidate_msc<0 || confirmed_msc<candidate_msc || origin_mid<=0.0 || local_sigma<=0.0) return false;
   state.initialized=true;state.direction=sign;state.candidate_msc=candidate_msc;state.confirmed_msc=confirmed_msc;
   state.origin_mid=origin_mid;state.local_sigma=local_sigma;state.point=point;state.tick_size=tick_size;
   for(int i=0;i<TS15C_HORIZON_COUNT;++i)
     {state.snapshots[i].horizon_ms=TS15C_HORIZONS_MS[i];state.snapshots[i].target_msc=confirmed_msc+(long)TS15C_HORIZONS_MS[i];state.snapshots[i].status=TS15C_SNAPSHOT_PENDING;}
   return true;
  }

bool TS15CSetReferenceQuote(TickShockEventResponseState &state,const long quote_msc,const double bid,const double ask)
  {
   if(!state.initialized || quote_msc<=state.confirmed_msc || bid<=0.0 || ask<bid) return false;
   if(state.reference_mid>0.0 && quote_msc!=state.reference_quote_msc) return false;
   state.reference_quote_msc=quote_msc;state.reference_bid=bid;state.reference_ask=ask;state.reference_mid=(bid+ask)*0.5;
   state.initial_shock_size=MathAbs(state.reference_mid-state.origin_mid);
   return true;
  }

bool TS15CFlushPendingQuote(TickShockEventResponseState &state)
  {
   if(!state.pending_valid) return true;
   bool ok=state.reference_mid<=0.0?
           TS15CSetReferenceQuote(state,state.pending_msc,state.pending_bid,state.pending_ask):
           TS15CObserveResponse(state,state.pending_msc,state.pending_msc,state.pending_bid,state.pending_ask);
   state.pending_valid=false;
   return ok;
  }

bool TS15CQueueResponseQuote(TickShockEventResponseState &state,const long time_msc,const double bid,const double ask)
  {
   if(!state.initialized || time_msc<=state.confirmed_msc || bid<=0.0 || ask<bid) return false;
   if(!state.pending_valid)
     {state.pending_valid=true;state.pending_msc=time_msc;state.pending_bid=bid;state.pending_ask=ask;return true;}
   if(time_msc==state.pending_msc)
     {state.pending_bid=bid;state.pending_ask=ask;++state.duplicates;return true;}
   if(time_msc<state.pending_msc){++state.drops;state.validation_invalid=true;return false;}
   if(!TS15CFlushPendingQuote(state)) return false;
   state.pending_valid=true;state.pending_msc=time_msc;state.pending_bid=bid;state.pending_ask=ask;
   return true;
  }

void TS15CUpdateSnapshot(TickShockEventResponseState &state,const int index,const long boundary_msc,const long quote_msc,
                         const double bid,const double ask)
  {
   TickShockResponseSnapshot snapshot=state.snapshots[index];
   if(snapshot.status!=TS15C_SNAPSHOT_PENDING && boundary_msc!=snapshot.boundary_msc) return;
   snapshot.boundary_msc=boundary_msc;snapshot.quote_msc=quote_msc;snapshot.target_lag_ms=boundary_msc-snapshot.target_msc;
   snapshot.quote_age_ms=(int)MathMax((long)0,boundary_msc-quote_msc);snapshot.bid=bid;snapshot.ask=ask;snapshot.mid=(bid+ask)*0.5;snapshot.spread=ask-bid;
   snapshot.status=snapshot.target_lag_ms>TS15C_STALE_LIMIT_MS?TS15C_SNAPSHOT_STALE:TS15C_SNAPSHOT_VALID;
   if(state.reference_mid>0.0 && snapshot.mid>0.0)
     {snapshot.raw_log_return=MathLog(snapshot.mid/state.reference_mid);snapshot.continuation_return=snapshot.raw_log_return*(double)state.direction;snapshot.absolute_return=MathAbs(snapshot.raw_log_return);}
   state.snapshots[index]=snapshot;
  }

bool TS15CObserveResponse(TickShockEventResponseState &state,const long boundary_msc,const long quote_msc,const double bid,const double ask)
  {
   if(!state.initialized || state.reference_mid<=0.0 || boundary_msc<=state.reference_quote_msc || bid<=0.0 || ask<bid){++state.drops;state.validation_invalid=true;return false;}
   ++state.observations;double mid=(bid+ask)*0.5;double signed_move=(mid-state.reference_mid)*(double)state.direction;
   if(signed_move>state.mfe){state.mfe=signed_move;state.time_to_mfe_ms=boundary_msc-state.confirmed_msc;}
   double adverse=-signed_move;if(adverse>state.mae){state.mae=adverse;state.time_to_mae_ms=boundary_msc-state.confirmed_msc;}
   if(state.origin_recross_msc==0 && ((state.direction>0 && mid<=state.origin_mid)||(state.direction<0 && mid>=state.origin_mid)))state.origin_recross_msc=boundary_msc;
   for(int b=0;b<TS15C_BARRIER_COUNT;++b)
     {
      if(state.barrier_result[b]!=TS15C_BARRIER_NONE) continue;
      double barrier=TS15C_LOCAL_BARRIERS[b]*state.local_sigma*state.reference_mid;
      bool cont=signed_move>=barrier;bool rev=signed_move<=-barrier;
      ENUM_TS15C_BARRIER_RESULT result=TS15CResolveBarrierTouch(cont,rev);
      if(result!=TS15C_BARRIER_NONE){state.barrier_result[b]=result;if(cont)state.continuation_hit_msc[b]=boundary_msc;if(rev)state.reversal_hit_msc[b]=boundary_msc;}
     }
   for(int i=0;i<TS15C_HORIZON_COUNT;++i)
      if(boundary_msc>=state.snapshots[i].target_msc && (state.snapshots[i].status==TS15C_SNAPSHOT_PENDING || boundary_msc==state.snapshots[i].boundary_msc))
         TS15CUpdateSnapshot(state,i,boundary_msc,quote_msc,bid,ask);
   return true;
  }

void TS15CFinalizeResponse(TickShockEventResponseState &state,const bool end_of_run)
  {
   TS15CFlushPendingQuote(state);
   for(int i=0;i<TS15C_HORIZON_COUNT;++i)
      if(state.snapshots[i].status==TS15C_SNAPSHOT_PENDING) state.snapshots[i].status=TS15C_SNAPSHOT_MISSING_END;
   for(int b=0;b<TS15C_BARRIER_COUNT;++b)
      if(state.barrier_result[b]==TS15C_BARRIER_NONE) state.barrier_result[b]=TS15C_BARRIER_TIMEOUT;
   state.censored=end_of_run;
  }

bool TS15CResponseValid(const TickShockEventResponseState &state)
  { return state.initialized && !state.validation_invalid && state.drops==0; }

#endif
