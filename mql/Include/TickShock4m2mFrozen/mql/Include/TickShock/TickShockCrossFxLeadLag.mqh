#ifndef TICK_SHOCK_CROSS_FX_LEAD_LAG_MQH
#define TICK_SHOCK_CROSS_FX_LEAD_LAG_MQH

#define TS15O_SYMBOLS 6
#define TS15O_WINDOWS 4
#define TS15O_QUOTE_CAPACITY 16
#define TS15O_POOL_CAPACITY 8
#define TS15O_ACTIONS 2

const int TS15O_WINDOW_SECONDS[TS15O_WINDOWS]={1,3,5,10};

enum ENUM_TS15O_STATUS
  {
   TS15O_PENDING=0,
   TS15O_ELIGIBLE=1,
   TS15O_TARGET_STALE=2,
   TS15O_CROSS_SYMBOL_STALE=3,
   TS15O_CROSS_SYMBOL_MISSING=4,
   TS15O_DATA_INTEGRITY_INVALID=5,
   TS15O_PATH_CENSORED=6
  };

enum ENUM_TS15O_RESULT
  {TS15O_RESULT_PENDING=0,TS15O_TP_FIRST=1,TS15O_SL_FIRST=2,TS15O_TIMEOUT=3,TS15O_RESULT_INVALID=4};

struct TickShock15OSecond
  {long second_msc;long quote_msc;long processing_msc;double bid;double ask;double mid;};

struct TickShock15OQuoteState
  {
   TickShock15OSecond samples[TS15O_QUOTE_CAPACITY];int count;int next;
   TickShock15OSecond current;bool current_active;long observations;long backdates;
  };

struct TickShock15OSource
  {
   bool valid;string reason;string symbol;int window_seconds;
   long current_quote_msc;long current_processing_msc;long anchor_quote_msc;long anchor_processing_msc;
   long quote_age_ms;long anchor_age_ms;long atr_source_msc;long crossing_msc;int usd_orientation;
   double current_mid;double anchor_mid;double atr14_m5;double usd_return_atr;
  };

struct TickShock15OSnapshot
  {
   bool recorded;string episode_id;string event_id;string target_symbol;long market_cluster_id;int shock_direction;int target_usd_sign;
   long t0_msc;long t0_quote_msc;long t0_processing_msc;double atr14_m5;long atr_source_msc;
   ENUM_TS15O_STATUS status;string status_reason;
   double target_usd_return_atr[TS15O_WINDOWS];bool target_return_valid[TS15O_WINDOWS];
   int breadth_count[TS15O_WINDOWS];int valid_cross_symbols[TS15O_WINDOWS];double breadth[TS15O_WINDOWS];
   double consensus_median[TS15O_WINDOWS];double aligned_consensus[TS15O_WINDOWS];
   double target_residual[TS15O_WINDOWS];double aligned_residual[TS15O_WINDOWS];
   long median_cross_quote_age_ms;long max_cross_quote_age_ms;
   int num_prior_cross_fx_movers;long first_cross_fx_lead_ms;long median_cross_fx_lead_ms;
   int target_leader_rank;string target_lead_bucket;long crossing_msc[TS15O_SYMBOLS];
   bool h1;bool h2;bool h3;bool h4;
   TickShock15OSource sources[TS15O_SYMBOLS*TS15O_WINDOWS];long future_sources;
  };

struct TickShock15OAction
  {
   int direction;bool entered;bool done;ENUM_TS15O_RESULT result;
   long entry_eligible_msc;long entry_quote_msc;long entry_processing_msc;long exit_msc;
   double entry_bid;double entry_ask;double entry_price;double risk_distance;double tp_distance;double sl;double tp;
   double exit_price;double realized_r;double mfe_r;double mae_r;
  };

struct TickShock15ORecord
  {
   bool active;bool complete;bool write_pending;bool invalid;TickShock15OSnapshot snapshot;
   long deadline_msc;TickShock15OAction actions[TS15O_ACTIONS];
   bool pending_valid;long pending_quote_msc;long pending_processing_msc;double pending_bid;double pending_ask;bool pending_fallback;
  };

struct TickShock15OPool
  {TickShock15ORecord records[TS15O_POOL_CAPACITY];long armed;long completed;long capacity_hits;long invalid_paths;};

string TS15OSchema(){return "tickshock-cross-fx-lead-lag-v1";}
string TS15OFeatureSpecHash(){return "2CDB617B542C9E1801C205630ED7364796B5569E9D438BE957B243511201F17D";}
string TS15OStatusName(const ENUM_TS15O_STATUS s)
  {if(s==TS15O_ELIGIBLE)return "ELIGIBLE";if(s==TS15O_TARGET_STALE)return "TARGET_STALE";if(s==TS15O_CROSS_SYMBOL_STALE)return "CROSS_SYMBOL_STALE";if(s==TS15O_CROSS_SYMBOL_MISSING)return "CROSS_SYMBOL_MISSING";if(s==TS15O_DATA_INTEGRITY_INVALID)return "DATA_INTEGRITY_INVALID";if(s==TS15O_PATH_CENSORED)return "PATH_CENSORED";return "PENDING";}
string TS15OResultName(const ENUM_TS15O_RESULT r)
  {if(r==TS15O_TP_FIRST)return "TP_FIRST";if(r==TS15O_SL_FIRST)return "SL_FIRST";if(r==TS15O_TIMEOUT)return "TIMEOUT";if(r==TS15O_RESULT_INVALID)return "INVALID";return "PENDING";}
string TS15OActionName(const int index){return index==0?"CONTINUATION":"REVERSAL";}

int TS15OUsdOrientation(const string symbol)
  {
   string s=symbol;StringToUpper(s);
   if(StringFind(s,"USDJPY")>=0||StringFind(s,"USDCHF")>=0||StringFind(s,"USDCAD")>=0)return 1;
   if(StringFind(s,"EURUSD")>=0||StringFind(s,"GBPUSD")>=0||StringFind(s,"AUDUSD")>=0)return -1;
   return 0;
  }

void TS15OResetQuoteState(TickShock15OQuoteState &state){ZeroMemory(state);}
void TS15OStoreSecond(TickShock15OQuoteState &state,const TickShock15OSecond &sample)
  {if(sample.quote_msc<=0||sample.processing_msc<sample.quote_msc||sample.bid<=0.0||sample.ask<=sample.bid)return;state.samples[state.next]=sample;state.next=(state.next+1)%TS15O_QUOTE_CAPACITY;if(state.count<TS15O_QUOTE_CAPACITY)++state.count;}
void TS15OObserveQuote(TickShock15OQuoteState &state,const long quote_msc,const long processing_msc,const double bid,const double ask)
  {
   if(quote_msc<=0||processing_msc<quote_msc||bid<=0.0||ask<=bid)return;
   long sec=(quote_msc/1000)*1000;if(state.current_active&&sec<state.current.second_msc){++state.backdates;return;}
   if(!state.current_active||sec!=state.current.second_msc)
     {if(state.current_active)TS15OStoreSecond(state,state.current);ZeroMemory(state.current);state.current_active=true;state.current.second_msc=sec;}
   state.current.quote_msc=quote_msc;state.current.processing_msc=processing_msc;state.current.bid=bid;state.current.ask=ask;state.current.mid=(bid+ask)*0.5;++state.observations;
  }

int TS15OChronological(const TickShock15OQuoteState &state,TickShock15OSecond &out[])
  {int extra=state.current_active?1:0;ArrayResize(out,state.count+extra);int oldest=(state.next-state.count+TS15O_QUOTE_CAPACITY)%TS15O_QUOTE_CAPACITY;for(int i=0;i<state.count;++i)out[i]=state.samples[(oldest+i)%TS15O_QUOTE_CAPACITY];if(extra>0)out[state.count]=state.current;return ArraySize(out);}

bool TS15OAnchor(const TickShock15OQuoteState &state,const long target_msc,const long processing_limit,TickShock15OSecond &anchor)
  {TickShock15OSecond data[];TS15OChronological(state,data);for(int i=ArraySize(data)-1;i>=0;--i)if(data[i].quote_msc<=target_msc&&data[i].processing_msc<=processing_limit){anchor=data[i];return true;}return false;}

double TS15OMedian(double &values[],const int count)
  {if(count<=0)return 0.0;double copy[];ArrayResize(copy,count);for(int i=0;i<count;++i)copy[i]=values[i];ArraySort(copy);if((count%2)==1)return copy[count/2];return 0.5*(copy[count/2-1]+copy[count/2]);}
long TS15OMedianLong(long &values[],const int count)
  {if(count<=0)return 0;long copy[];ArrayResize(copy,count);for(int i=0;i<count;++i)copy[i]=values[i];ArraySort(copy);if((count%2)==1)return copy[count/2];return (copy[count/2-1]+copy[count/2])/2;}

bool TS15OReturn(const TickShock15OQuoteState &state,const string symbol,const int window_seconds,const long t0_msc,const long processing_msc,const double atr,TickShock15OSource &source)
  {
   ZeroMemory(source);source.symbol=symbol;source.window_seconds=window_seconds;source.atr14_m5=atr;
   TickShock15OSecond now,anchor;if(atr<=0.0||!MathIsValidNumber(atr)){source.reason="ATR_UNAVAILABLE";return false;}
   if(!TS15OAnchor(state,t0_msc,processing_msc,now)){source.reason="CURRENT_QUOTE_MISSING";return false;}
   if(!TS15OAnchor(state,t0_msc-(long)window_seconds*1000,processing_msc,anchor)){source.reason="ANCHOR_MISSING";return false;}
   int orientation=TS15OUsdOrientation(symbol);if(orientation==0){source.reason="INVALID_USD_ORIENTATION";return false;}
   source.current_quote_msc=now.quote_msc;source.current_processing_msc=now.processing_msc;source.anchor_quote_msc=anchor.quote_msc;source.anchor_processing_msc=anchor.processing_msc;
   source.current_mid=now.mid;source.anchor_mid=anchor.mid;source.usd_orientation=orientation;
   source.quote_age_ms=processing_msc-now.quote_msc;source.anchor_age_ms=t0_msc-(long)window_seconds*1000-anchor.quote_msc;
   source.usd_return_atr=(now.mid-anchor.mid)*(double)orientation/atr;
   source.valid=MathIsValidNumber(source.usd_return_atr)&&source.quote_age_ms>=0&&source.current_quote_msc<=t0_msc&&source.current_processing_msc<=processing_msc&&source.anchor_quote_msc<=t0_msc-(long)window_seconds*1000&&source.anchor_processing_msc<=processing_msc;
   source.reason=source.valid?"AVAILABLE":"CAUSALITY_INVALID";return source.valid;
  }

long TS15OFirstAlignedCrossing(const TickShock15OQuoteState &state,const string symbol,const long t0_msc,const long processing_msc,const double atr,const int target_usd_sign)
  {
   if(atr<=0.0||target_usd_sign==0)return 0;TickShock15OSecond data[];TS15OChronological(state,data);int orientation=TS15OUsdOrientation(symbol);
   for(int i=0;i<ArraySize(data);++i)
     {
      TickShock15OSecond now=data[i];if(now.quote_msc<t0_msc-10000||now.quote_msc>t0_msc||now.processing_msc>processing_msc)continue;
      TickShock15OSecond anchor;if(!TS15OAnchor(state,now.quote_msc-5000,processing_msc,anchor))continue;
      double aligned=(now.mid-anchor.mid)*(double)orientation*(double)target_usd_sign/atr;if(aligned>=0.10-1e-12)return now.quote_msc;
     }
   return 0;
  }

void TS15OResetSnapshot(TickShock15OSnapshot &snapshot){ZeroMemory(snapshot);snapshot.target_lead_bucket="NO_CROSSING";snapshot.status=TS15O_PENDING;}

bool TS15OBuildSnapshot(const TickShock15OQuoteState &states[],const string &symbols[],const double &atrs[],const long &atr_sources[],
                        const int target_index,const string episode_id,const string event_id,const long market_cluster_id,const int shock_direction,
                        const long t0_msc,const long t0_quote_msc,const long t0_processing_msc,const int max_quote_age_ms,TickShock15OSnapshot &snapshot)
  {
   TS15OResetSnapshot(snapshot);int n=ArraySize(states);if(n!=TS15O_SYMBOLS||ArraySize(symbols)!=n||ArraySize(atrs)!=n||ArraySize(atr_sources)!=n||target_index<0||target_index>=n||shock_direction==0||t0_msc<=0||t0_processing_msc<t0_quote_msc){snapshot.status=TS15O_DATA_INTEGRITY_INVALID;snapshot.status_reason="INVALID_INPUT";return false;}
   snapshot.recorded=true;snapshot.episode_id=episode_id;snapshot.event_id=event_id;snapshot.target_symbol=symbols[target_index];snapshot.market_cluster_id=market_cluster_id;snapshot.shock_direction=shock_direction>0?1:-1;snapshot.target_usd_sign=TS15OUsdOrientation(symbols[target_index])*snapshot.shock_direction;snapshot.t0_msc=t0_msc;snapshot.t0_quote_msc=t0_quote_msc;snapshot.t0_processing_msc=t0_processing_msc;snapshot.atr14_m5=atrs[target_index];snapshot.atr_source_msc=atr_sources[target_index];
   if(snapshot.target_usd_sign==0||snapshot.atr14_m5<=0.0||snapshot.atr_source_msc<=0||snapshot.atr_source_msc>t0_processing_msc){snapshot.status=TS15O_DATA_INTEGRITY_INVALID;snapshot.status_reason="TARGET_ATR_OR_SIGN_INVALID";return false;}
   bool any_missing=false,any_stale=false;long ages[TS15O_SYMBOLS-1];int age_count=0;
   for(int w=0;w<TS15O_WINDOWS;++w)
     {
      double cross_values[TS15O_SYMBOLS-1];int cross_count=0;int same=0;
      for(int i=0;i<n;++i)
        {
         int flat=i*TS15O_WINDOWS+w;TickShock15OSource src;bool ok=TS15OReturn(states[i],symbols[i],TS15O_WINDOW_SECONDS[w],t0_msc,t0_processing_msc,atrs[i],src);src.atr_source_msc=atr_sources[i];snapshot.sources[flat]=src;
         if(ok&&src.current_quote_msc>t0_msc)++snapshot.future_sources;
         if(i==target_index){snapshot.target_return_valid[w]=ok;snapshot.target_usd_return_atr[w]=ok?src.usd_return_atr:0.0;continue;}
         if(!ok){any_missing=true;continue;}if(src.quote_age_ms>max_quote_age_ms){any_stale=true;continue;}
         cross_values[cross_count++]=src.usd_return_atr;if(src.usd_return_atr*(double)snapshot.target_usd_sign>0.0)++same;
         if(w==2&&age_count<TS15O_SYMBOLS-1)ages[age_count++]=src.quote_age_ms;
        }
      snapshot.valid_cross_symbols[w]=cross_count;snapshot.breadth_count[w]=same;snapshot.breadth[w]=cross_count>0?(double)same/(double)cross_count:0.0;
      if(cross_count>0){snapshot.consensus_median[w]=TS15OMedian(cross_values,cross_count);snapshot.aligned_consensus[w]=snapshot.consensus_median[w]*(double)snapshot.target_usd_sign;}
      if(snapshot.target_return_valid[w]&&cross_count>0){snapshot.target_residual[w]=snapshot.target_usd_return_atr[w]-snapshot.consensus_median[w];snapshot.aligned_residual[w]=snapshot.target_residual[w]*(double)snapshot.target_usd_sign;}
     }
   TickShock15OSecond target_now;if(!TS15OAnchor(states[target_index],t0_msc,t0_processing_msc,target_now)){snapshot.status=TS15O_DATA_INTEGRITY_INVALID;snapshot.status_reason="TARGET_QUOTE_MISSING";return false;}
   long target_age=t0_processing_msc-target_now.quote_msc;if(target_age>max_quote_age_ms){snapshot.status=TS15O_TARGET_STALE;snapshot.status_reason="TARGET_QUOTE_AGE";}
   else if(any_missing){snapshot.status=TS15O_CROSS_SYMBOL_MISSING;snapshot.status_reason="CROSS_RETURN_OR_ATR_MISSING";}
   else if(any_stale){snapshot.status=TS15O_CROSS_SYMBOL_STALE;snapshot.status_reason="CROSS_QUOTE_AGE";}
   else if(snapshot.future_sources>0){snapshot.status=TS15O_DATA_INTEGRITY_INVALID;snapshot.status_reason="FUTURE_SOURCE";}
   else{snapshot.status=TS15O_ELIGIBLE;snapshot.status_reason="AVAILABLE";}
   if(age_count>0){snapshot.median_cross_quote_age_ms=TS15OMedianLong(ages,age_count);snapshot.max_cross_quote_age_ms=ages[0];for(int i=1;i<age_count;++i)snapshot.max_cross_quote_age_ms=MathMax(snapshot.max_cross_quote_age_ms,ages[i]);}
   long lead_ages[TS15O_SYMBOLS-1];int lead_count=0;for(int i=0;i<n;++i){snapshot.crossing_msc[i]=TS15OFirstAlignedCrossing(states[i],symbols[i],t0_msc,t0_processing_msc,atrs[i],snapshot.target_usd_sign);if(i!=target_index&&snapshot.crossing_msc[i]>0){lead_ages[lead_count++]=t0_msc-snapshot.crossing_msc[i];}}
   snapshot.num_prior_cross_fx_movers=lead_count;if(lead_count>0){snapshot.first_cross_fx_lead_ms=lead_ages[0];for(int i=1;i<lead_count;++i)snapshot.first_cross_fx_lead_ms=MathMax(snapshot.first_cross_fx_lead_ms,lead_ages[i]);snapshot.median_cross_fx_lead_ms=TS15OMedianLong(lead_ages,lead_count);}
   if(snapshot.crossing_msc[target_index]>0){int rank=1;for(int i=0;i<n;++i)if(i!=target_index&&(snapshot.crossing_msc[i]>0)&&(snapshot.crossing_msc[i]<snapshot.crossing_msc[target_index]||(snapshot.crossing_msc[i]==snapshot.crossing_msc[target_index]&&i<target_index)))++rank;snapshot.target_leader_rank=rank;snapshot.target_lead_bucket=rank<=2?"EARLY":(rank<=4?"MIDDLE":"LATE");}
   for(int i=0;i<n;++i)for(int w=0;w<TS15O_WINDOWS;++w)snapshot.sources[i*TS15O_WINDOWS+w].crossing_msc=snapshot.crossing_msc[i];
   bool h_ready=snapshot.valid_cross_symbols[2]==5&&snapshot.target_return_valid[2];snapshot.h1=h_ready&&snapshot.breadth_count[2]>=4&&snapshot.aligned_consensus[2]>0.0;snapshot.h2=h_ready&&snapshot.breadth_count[2]<=1;snapshot.h3=h_ready&&snapshot.aligned_residual[2]<=-0.10+1e-12;snapshot.h4=h_ready&&snapshot.aligned_residual[2]>=0.10-1e-12;
   return snapshot.status!=TS15O_DATA_INTEGRITY_INVALID;
  }

void TS15OResetAction(TickShock15OAction &a){ZeroMemory(a);a.result=TS15O_RESULT_PENDING;}
void TS15OResetRecord(TickShock15ORecord &r){ZeroMemory(r);TS15OResetSnapshot(r.snapshot);for(int i=0;i<TS15O_ACTIONS;++i)TS15OResetAction(r.actions[i]);}
void TS15OResetPool(TickShock15OPool &pool){ZeroMemory(pool);for(int i=0;i<TS15O_POOL_CAPACITY;++i)TS15OResetRecord(pool.records[i]);}

bool TS15OArm(TickShock15OPool &pool,const TickShock15OSnapshot &snapshot)
  {
   if(!snapshot.recorded||snapshot.episode_id==""||snapshot.shock_direction==0||snapshot.t0_msc<=0||snapshot.atr14_m5<=0.0)return false;
   for(int i=0;i<TS15O_POOL_CAPACITY;++i)if((pool.records[i].active||pool.records[i].write_pending)&&pool.records[i].snapshot.episode_id==snapshot.episode_id)return false;
   int slot=-1;for(int i=0;i<TS15O_POOL_CAPACITY;++i)if(!pool.records[i].active&&!pool.records[i].write_pending){slot=i;break;}if(slot<0){++pool.capacity_hits;return false;}
   TickShock15ORecord r;TS15OResetRecord(r);r.active=true;r.snapshot=snapshot;r.deadline_msc=snapshot.t0_msc+900000;
   for(int a=0;a<TS15O_ACTIONS;++a){r.actions[a].direction=a==0?snapshot.shock_direction:-snapshot.shock_direction;r.actions[a].entry_eligible_msc=MathMax(snapshot.t0_msc,snapshot.t0_processing_msc);}
   pool.records[slot]=r;++pool.armed;return true;
  }

void TS15OEnter(TickShock15OAction &a,const long q,const long p,const double bid,const double ask,const double atr)
  {a.entered=true;a.entry_quote_msc=q;a.entry_processing_msc=p;a.entry_bid=bid;a.entry_ask=ask;a.risk_distance=0.25*atr;a.tp_distance=0.40*atr;if(a.direction>0){a.entry_price=ask;a.sl=ask-a.risk_distance;a.tp=ask+a.tp_distance;}else{a.entry_price=bid;a.sl=bid+a.risk_distance;a.tp=bid-a.tp_distance;}}
void TS15OEvaluate(TickShock15OAction &a,const long q,const double bid,const double ask,const long deadline)
  {if(!a.entered||a.done||q<=a.entry_quote_msc)return;double side=a.direction>0?bid:ask;double move=a.direction>0?side-a.entry_price:a.entry_price-side;a.mfe_r=MathMax(a.mfe_r,move/a.risk_distance);a.mae_r=MathMax(a.mae_r,-move/a.risk_distance);if(move>=a.tp_distance){a.done=true;a.result=TS15O_TP_FIRST;a.exit_msc=q;a.exit_price=a.tp;a.realized_r=1.6;return;}if(move<=-a.risk_distance){a.done=true;a.result=TS15O_SL_FIRST;a.exit_msc=q;a.exit_price=side;a.realized_r=move/a.risk_distance;return;}if(q>=deadline){a.done=true;a.result=TS15O_TIMEOUT;a.exit_msc=q;a.exit_price=side;a.realized_r=move/a.risk_distance;}}
void TS15OProcessQuote(TickShock15ORecord &r,const long q,const long p,const double bid,const double ask,const bool fallback)
  {
   if(!r.active||r.complete)return;if(q<=0||p<q||bid<=0.0||ask<=bid||fallback){r.invalid=true;return;}
   for(int a=0;a<TS15O_ACTIONS;++a){TickShock15OAction x=r.actions[a];if(!x.entered&&q>r.snapshot.t0_quote_msc&&q>=x.entry_eligible_msc&&q<r.deadline_msc)TS15OEnter(x,q,p,bid,ask,r.snapshot.atr14_m5);TS15OEvaluate(x,q,bid,ask,r.deadline_msc);r.actions[a]=x;}
   if(q>=r.deadline_msc){for(int a=0;a<TS15O_ACTIONS;++a)if(!r.actions[a].done){r.actions[a].result=TS15O_RESULT_INVALID;r.invalid=true;}r.active=false;r.complete=true;r.write_pending=true;}
  }
void TS15OFlushPending(TickShock15ORecord &r){if(!r.pending_valid)return;long q=r.pending_quote_msc,p=r.pending_processing_msc;double b=r.pending_bid,a=r.pending_ask;bool f=r.pending_fallback;r.pending_valid=false;TS15OProcessQuote(r,q,p,b,a,f);}
void TS15OQueueQuote(TickShock15ORecord &r,const long q,const long p,const double bid,const double ask,const bool fallback)
  {if(!r.active)return;if(!r.pending_valid){r.pending_valid=true;r.pending_quote_msc=q;r.pending_processing_msc=p;r.pending_bid=bid;r.pending_ask=ask;r.pending_fallback=fallback;return;}if(q==r.pending_quote_msc){r.pending_processing_msc=MathMax(r.pending_processing_msc,p);r.pending_bid=bid;r.pending_ask=ask;r.pending_fallback=r.pending_fallback||fallback;return;}if(q<r.pending_quote_msc){r.invalid=true;return;}TS15OFlushPending(r);if(!r.active)return;r.pending_valid=true;r.pending_quote_msc=q;r.pending_processing_msc=p;r.pending_bid=bid;r.pending_ask=ask;r.pending_fallback=fallback;}
void TS15OObservePool(TickShock15OPool &pool,const long q,const long p,const double bid,const double ask,const bool fallback)
  {for(int i=0;i<TS15O_POOL_CAPACITY;++i)if(pool.records[i].active)TS15OQueueQuote(pool.records[i],q,p,bid,ask,fallback);}
void TS15OFinalizePool(TickShock15OPool &pool)
  {for(int i=0;i<TS15O_POOL_CAPACITY;++i){TickShock15ORecord r=pool.records[i];if(!r.active)continue;TS15OFlushPending(r);if(r.active){for(int a=0;a<TS15O_ACTIONS;++a)if(!r.actions[a].done)r.actions[a].result=TS15O_RESULT_INVALID;r.snapshot.status=TS15O_PATH_CENSORED;r.snapshot.status_reason="END_OF_DATA";r.active=false;r.complete=true;r.write_pending=true;}pool.records[i]=r;}}

long TS15OResearchOrderCalls(){return 0;}

#endif
