#ifndef TICK_SHOCK_SYMMETRIC_OCO_MQH
#define TICK_SHOCK_SYMMETRIC_OCO_MQH

#define TS15P_OFFSET_COUNT 3
#define TS15P_TP_COUNT 6
#define TS15P_SL_COUNT 6
#define TS15P_SCENARIO_COUNT 36
#define TS15P_POOL_CAPACITY 16

const double TS15P_OFFSET_ATR[TS15P_OFFSET_COUNT]={0.02,0.05,0.10};
const double TS15P_TP_ATR[TS15P_TP_COUNT]={0.02,0.03,0.05,0.075,0.10,0.15};
const double TS15P_SL_ATR[TS15P_SL_COUNT]={0.10,0.20,0.30,0.50,0.75,1.00};

enum ENUM_TS15P_ENTRY_STATUS
  {
   TS15P_WAIT_TRIGGER=0,
   TS15P_TRIGGERED=1,
   TS15P_ENTERED=2,
   TS15P_NO_ENTRY=3,
   TS15P_AMBIGUOUS_TRIGGER=4,
   TS15P_INVALID_PATH=5,
   TS15P_CENSORED=6
  };

enum ENUM_TS15P_RESULT
  {
   TS15P_RESULT_PENDING=0,
   TS15P_TP_FIRST=1,
   TS15P_SL_FIRST=2,
   TS15P_TIMEOUT=3,
   TS15P_AMBIGUOUS_BARRIER=4,
   TS15P_RESULT_NO_ENTRY=5,
   TS15P_RESULT_INVALID=6,
   TS15P_RESULT_CENSORED=7,
   TS15P_AMBIGUOUS_TRIGGER_RESULT=8
  };

struct TickShock15PScenario
  {
   bool done;
   ENUM_TS15P_RESULT result;
   double tp_atr;
   double sl_atr;
   double tp_price;
   double sl_price;
   long exit_msc;
   double exit_bid;
   double exit_ask;
   double exit_price;
   double gross_price;
   double gross_pips;
   double gross_r;
   double mfe_price;
   double mae_price;
  };

struct TickShock15PLeg
  {
   ENUM_TS15P_ENTRY_STATUS status;
   double offset_atr;
   double upper_trigger;
   double lower_trigger;
   int direction;
   long trigger_msc;
   double trigger_bid;
   double trigger_ask;
   long entry_msc;
   long entry_processing_msc;
   double entry_bid;
   double entry_ask;
   double entry_price;
   double entry_spread;
   long deadline_msc;
   TickShock15PScenario scenarios[TS15P_SCENARIO_COUNT];
  };

struct TickShock15PRecord
  {
   bool active;
   bool complete;
   bool write_pending;
   bool invalid;
   bool censored;
   string episode_id;
   string event_id;
   string symbol;
   long market_cluster_id;
   int shock_direction;
   long t0_msc;
   long t0_quote_msc;
   long t0_processing_msc;
   double t0_bid;
   double t0_ask;
   double t0_mid;
   double atr14_m5;
   long atr_source_msc;
   double point;
   double pip_size;
   TickShock15PLeg legs[TS15P_OFFSET_COUNT];
   bool pending_valid;
   long pending_msc;
   long pending_processing_msc;
   double pending_last_bid;
   double pending_last_ask;
   double pending_max_bid;
   double pending_min_bid;
   double pending_max_ask;
   double pending_min_ask;
   bool pending_fallback;
   long quote_groups;
   long same_msc_ticks;
   long future_reads;
   long backdates;
   long fallback_quotes;
   long ambiguous_triggers;
  };

struct TickShock15PPool
  {
   TickShock15PRecord records[TS15P_POOL_CAPACITY];
   long armed;
   long completed;
   long capacity_hits;
   long invalid_paths;
   long ambiguous_triggers;
  };

string TS15PSchema(){return "tickshock-symmetric-oco-v1";}
int TS15PScenarioIndex(const int tp_index,const int sl_index){return tp_index*TS15P_SL_COUNT+sl_index;}

string TS15PEntryStatusName(const ENUM_TS15P_ENTRY_STATUS status)
  {
   if(status==TS15P_WAIT_TRIGGER)return "WAIT_TRIGGER";
   if(status==TS15P_TRIGGERED)return "TRIGGERED";
   if(status==TS15P_ENTERED)return "ENTERED";
   if(status==TS15P_NO_ENTRY)return "NO_ENTRY";
   if(status==TS15P_AMBIGUOUS_TRIGGER)return "AMBIGUOUS_TRIGGER";
   if(status==TS15P_INVALID_PATH)return "INVALID_PATH";
   return "CENSORED";
  }

string TS15PResultName(const ENUM_TS15P_RESULT result)
  {
   if(result==TS15P_TP_FIRST)return "TP_FIRST";
   if(result==TS15P_SL_FIRST)return "SL_FIRST";
   if(result==TS15P_TIMEOUT)return "TIMEOUT";
   if(result==TS15P_AMBIGUOUS_BARRIER)return "AMBIGUOUS_BARRIER";
   if(result==TS15P_RESULT_NO_ENTRY)return "NO_ENTRY";
   if(result==TS15P_RESULT_INVALID)return "INVALID_PATH";
   if(result==TS15P_RESULT_CENSORED)return "CENSORED";
   if(result==TS15P_AMBIGUOUS_TRIGGER_RESULT)return "AMBIGUOUS_TRIGGER";
   return "PENDING";
  }

void TS15PResetScenario(TickShock15PScenario &s)
  {ZeroMemory(s);s.result=TS15P_RESULT_PENDING;}

void TS15PResetRecord(TickShock15PRecord &r)
  {
   ZeroMemory(r);
   for(int o=0;o<TS15P_OFFSET_COUNT;++o)
     {
      r.legs[o].status=TS15P_WAIT_TRIGGER;
      for(int k=0;k<TS15P_SCENARIO_COUNT;++k)TS15PResetScenario(r.legs[o].scenarios[k]);
     }
  }

void TS15PResetPool(TickShock15PPool &pool)
  {ZeroMemory(pool);for(int i=0;i<TS15P_POOL_CAPACITY;++i)TS15PResetRecord(pool.records[i]);}

double TS15PPipSize(const int digits,const double point)
  {if(point<=0.0)return 0.0;return (digits==3||digits==5)?10.0*point:point;}

bool TS15PArm(TickShock15PPool &pool,const string episode_id,const string event_id,const string symbol,
              const long cluster_id,const int shock_direction,const long t0_msc,const long t0_quote_msc,
              const long processing_msc,const double bid,const double ask,const double atr14_m5,
              const long atr_source_msc,const int digits,const double point)
  {
   if(episode_id==""||event_id==""||symbol==""||shock_direction==0||t0_msc<=0||t0_quote_msc<=0||
      processing_msc<t0_msc||processing_msc<t0_quote_msc||bid<=0.0||ask<=bid||atr14_m5<=0.0||
      atr_source_msc<=0||atr_source_msc>processing_msc||point<=0.0)return false;
   for(int i=0;i<TS15P_POOL_CAPACITY;++i)
      if((pool.records[i].active||pool.records[i].write_pending)&&pool.records[i].episode_id==episode_id)return false;
   int slot=-1;for(int i=0;i<TS15P_POOL_CAPACITY;++i)if(!pool.records[i].active&&!pool.records[i].write_pending){slot=i;break;}
   if(slot<0){++pool.capacity_hits;return false;}
   TickShock15PRecord r;TS15PResetRecord(r);r.active=true;r.episode_id=episode_id;r.event_id=event_id;r.symbol=symbol;
   r.market_cluster_id=cluster_id;r.shock_direction=shock_direction>0?1:-1;r.t0_msc=t0_msc;r.t0_quote_msc=t0_quote_msc;
   r.t0_processing_msc=processing_msc;r.t0_bid=bid;r.t0_ask=ask;r.t0_mid=(bid+ask)*0.5;r.atr14_m5=atr14_m5;
   r.atr_source_msc=atr_source_msc;r.point=point;r.pip_size=TS15PPipSize(digits,point);
   for(int o=0;o<TS15P_OFFSET_COUNT;++o)
     {
      r.legs[o].status=TS15P_WAIT_TRIGGER;r.legs[o].offset_atr=TS15P_OFFSET_ATR[o];
      r.legs[o].upper_trigger=r.t0_mid+TS15P_OFFSET_ATR[o]*atr14_m5;r.legs[o].lower_trigger=r.t0_mid-TS15P_OFFSET_ATR[o]*atr14_m5;
      for(int tp=0;tp<TS15P_TP_COUNT;++tp)for(int sl=0;sl<TS15P_SL_COUNT;++sl)
        {int k=TS15PScenarioIndex(tp,sl);TS15PResetScenario(r.legs[o].scenarios[k]);r.legs[o].scenarios[k].tp_atr=TS15P_TP_ATR[tp];r.legs[o].scenarios[k].sl_atr=TS15P_SL_ATR[sl];}
     }
   pool.records[slot]=r;++pool.armed;return true;
  }

void TS15PFinishLeg(TickShock15PLeg &leg,const ENUM_TS15P_ENTRY_STATUS status,const ENUM_TS15P_RESULT result)
  {leg.status=status;for(int k=0;k<TS15P_SCENARIO_COUNT;++k){leg.scenarios[k].done=true;leg.scenarios[k].result=result;}}

bool TS15PLegDone(const TickShock15PLeg &leg)
  {for(int k=0;k<TS15P_SCENARIO_COUNT;++k)if(!leg.scenarios[k].done)return false;return true;}

void TS15PEnter(TickShock15PLeg &leg,const long q,const long p,const double bid,const double ask,const double atr)
  {
   leg.status=TS15P_ENTERED;leg.entry_msc=q;leg.entry_processing_msc=p;leg.entry_bid=bid;leg.entry_ask=ask;
   leg.entry_price=leg.direction>0?ask:bid;leg.entry_spread=ask-bid;leg.deadline_msc=q+300000;
   for(int tp=0;tp<TS15P_TP_COUNT;++tp)for(int sl=0;sl<TS15P_SL_COUNT;++sl)
     {
      int k=TS15PScenarioIndex(tp,sl);TickShock15PScenario s=leg.scenarios[k];
      double td=s.tp_atr*atr,sd=s.sl_atr*atr;
      if(leg.direction>0){s.tp_price=leg.entry_price+td;s.sl_price=leg.entry_price-sd;}
      else{s.tp_price=leg.entry_price-td;s.sl_price=leg.entry_price+sd;}
      leg.scenarios[k]=s;
     }
  }

void TS15PCompleteScenario(TickShock15PScenario &s,const ENUM_TS15P_RESULT result,const int direction,
                           const long q,const double bid,const double ask,const double entry,const double pip_size)
  {
   s.done=true;s.result=result;s.exit_msc=q;s.exit_bid=bid;s.exit_ask=ask;
   if(result==TS15P_TP_FIRST)s.exit_price=s.tp_price;
   else if(result==TS15P_SL_FIRST)s.exit_price=direction>0?bid:ask;
   else s.exit_price=direction>0?bid:ask;
   s.gross_price=(s.exit_price-entry)*(double)direction;
   s.gross_pips=pip_size>0.0?s.gross_price/pip_size:0.0;
   double risk=s.sl_atr>0.0?MathAbs(s.sl_price-entry):0.0;s.gross_r=risk>0.0?s.gross_price/risk:0.0;
  }

void TS15PEvaluateLeg(TickShock15PLeg &leg,const long q,const double last_bid,const double last_ask,
                      const double max_bid,const double min_bid,const double max_ask,const double min_ask,const double pip_size)
  {
   if(leg.status!=TS15P_ENTERED||q<=leg.entry_msc)return;
   if(q>=leg.deadline_msc)
     {
      for(int k=0;k<TS15P_SCENARIO_COUNT;++k)if(!leg.scenarios[k].done)
         TS15PCompleteScenario(leg.scenarios[k],TS15P_TIMEOUT,leg.direction,q,last_bid,last_ask,leg.entry_price,pip_size);
      return;
     }
   for(int k=0;k<TS15P_SCENARIO_COUNT;++k)
     {
      TickShock15PScenario s=leg.scenarios[k];if(s.done)continue;
      double favorable=leg.direction>0?max_bid-leg.entry_price:leg.entry_price-min_ask;
      double adverse=leg.direction>0?leg.entry_price-min_bid:max_ask-leg.entry_price;
      s.mfe_price=MathMax(s.mfe_price,favorable);s.mae_price=MathMax(s.mae_price,adverse);
      bool tp=leg.direction>0?max_bid>=s.tp_price:min_ask<=s.tp_price;
      bool sl=leg.direction>0?min_bid<=s.sl_price:max_ask>=s.sl_price;
      if(tp&&sl){s.done=true;s.result=TS15P_AMBIGUOUS_BARRIER;s.exit_msc=q;s.exit_bid=last_bid;s.exit_ask=last_ask;}
      else if(tp)TS15PCompleteScenario(s,TS15P_TP_FIRST,leg.direction,q,last_bid,last_ask,leg.entry_price,pip_size);
      else if(sl)TS15PCompleteScenario(s,TS15P_SL_FIRST,leg.direction,q,leg.direction>0?min_bid:last_bid,leg.direction<0?max_ask:last_ask,leg.entry_price,pip_size);
      leg.scenarios[k]=s;
     }
  }

void TS15PProcessGroup(TickShock15PRecord &r,const long q,const long p,const double last_bid,const double last_ask,
                       const double max_bid,const double min_bid,const double max_ask,const double min_ask,const bool fallback)
  {
   if(!r.active)return;++r.quote_groups;
   if(q<=0||p<q||last_bid<=0.0||last_ask<=last_bid){r.invalid=true;++r.future_reads;return;}
   if(q<=r.t0_quote_msc||q<r.t0_msc)return;
   if(fallback){r.invalid=true;++r.fallback_quotes;for(int o=0;o<TS15P_OFFSET_COUNT;++o)if(!TS15PLegDone(r.legs[o]))TS15PFinishLeg(r.legs[o],TS15P_INVALID_PATH,TS15P_RESULT_INVALID);}
   for(int o=0;o<TS15P_OFFSET_COUNT&&!r.invalid;++o)
     {
      TickShock15PLeg leg=r.legs[o];
      if(leg.status==TS15P_WAIT_TRIGGER)
        {
         bool upper=max_ask>=leg.upper_trigger,lower=min_bid<=leg.lower_trigger;
         if(upper&&lower){TS15PFinishLeg(leg,TS15P_AMBIGUOUS_TRIGGER,TS15P_AMBIGUOUS_TRIGGER_RESULT);++r.ambiguous_triggers;}
         else if(upper||lower){leg.status=TS15P_TRIGGERED;leg.direction=upper?1:-1;leg.trigger_msc=q;leg.trigger_bid=last_bid;leg.trigger_ask=last_ask;}
         else if(q>=r.t0_msc+30000)TS15PFinishLeg(leg,TS15P_NO_ENTRY,TS15P_RESULT_NO_ENTRY);
        }
      else if(leg.status==TS15P_TRIGGERED&&q>leg.trigger_msc)TS15PEnter(leg,q,p,last_bid,last_ask,r.atr14_m5);
      if(leg.status==TS15P_ENTERED)TS15PEvaluateLeg(leg,q,last_bid,last_ask,max_bid,min_bid,max_ask,min_ask,r.pip_size);
      r.legs[o]=leg;
     }
   bool all=true;for(int o=0;o<TS15P_OFFSET_COUNT;++o)if(!TS15PLegDone(r.legs[o]))all=false;
   if(all){r.active=false;r.complete=true;r.write_pending=true;}
  }

void TS15PFlushPending(TickShock15PRecord &r)
  {
   if(!r.pending_valid)return;long q=r.pending_msc,p=r.pending_processing_msc;double b=r.pending_last_bid,a=r.pending_last_ask,hb=r.pending_max_bid,lb=r.pending_min_bid,ha=r.pending_max_ask,la=r.pending_min_ask;bool f=r.pending_fallback;r.pending_valid=false;
   TS15PProcessGroup(r,q,p,b,a,hb,lb,ha,la,f);
  }

void TS15PQueueQuote(TickShock15PRecord &r,const long q,const long p,const double bid,const double ask,const bool fallback)
  {
   if(!r.active)return;
   if(!r.pending_valid){r.pending_valid=true;r.pending_msc=q;r.pending_processing_msc=p;r.pending_last_bid=bid;r.pending_last_ask=ask;r.pending_max_bid=bid;r.pending_min_bid=bid;r.pending_max_ask=ask;r.pending_min_ask=ask;r.pending_fallback=fallback;return;}
   if(q==r.pending_msc){r.pending_processing_msc=MathMax(r.pending_processing_msc,p);r.pending_last_bid=bid;r.pending_last_ask=ask;r.pending_max_bid=MathMax(r.pending_max_bid,bid);r.pending_min_bid=MathMin(r.pending_min_bid,bid);r.pending_max_ask=MathMax(r.pending_max_ask,ask);r.pending_min_ask=MathMin(r.pending_min_ask,ask);r.pending_fallback=r.pending_fallback||fallback;++r.same_msc_ticks;return;}
   if(q<r.pending_msc){r.invalid=true;++r.backdates;return;}
   TS15PFlushPending(r);if(!r.active)return;
   r.pending_valid=true;r.pending_msc=q;r.pending_processing_msc=p;r.pending_last_bid=bid;r.pending_last_ask=ask;r.pending_max_bid=bid;r.pending_min_bid=bid;r.pending_max_ask=ask;r.pending_min_ask=ask;r.pending_fallback=fallback;
  }

void TS15PObservePool(TickShock15PPool &pool,const long q,const long p,const double bid,const double ask,const bool fallback)
  {for(int i=0;i<TS15P_POOL_CAPACITY;++i)if(pool.records[i].active)TS15PQueueQuote(pool.records[i],q,p,bid,ask,fallback);}

void TS15PFinalizePool(TickShock15PPool &pool)
  {
   for(int i=0;i<TS15P_POOL_CAPACITY;++i)
     {
      TickShock15PRecord r=pool.records[i];if(!r.active)continue;TS15PFlushPending(r);
      if(r.active){r.censored=true;for(int o=0;o<TS15P_OFFSET_COUNT;++o)if(!TS15PLegDone(r.legs[o]))TS15PFinishLeg(r.legs[o],TS15P_CENSORED,TS15P_RESULT_CENSORED);r.active=false;r.complete=true;r.write_pending=true;}
      pool.records[i]=r;
     }
  }

#endif
