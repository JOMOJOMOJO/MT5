#ifndef TICK_SHOCK_TECHNICAL_STUDY_MQH
#define TICK_SHOCK_TECHNICAL_STUDY_MQH
#include "TickShockTechnicalFeatures.mqh"

#define TSTD_DISTANCES 6
#define TSTD_POOL 8
const double TSTD_ATR_MULT[TSTD_DISTANCES]={0.25,0.50,0.75,1.00,1.50,2.00};
struct TSTDBarrier
  {
   string status;
   double distance,sl,tp,exit_price,gross_pips,gross_r,tp_touch_seconds,sl_touch_seconds;
   long exit_msc;
  };
struct TSTDRecord
  {
   bool active,entered;
   string episode_id,symbol;
   long cluster,t0,processing,quote,eligible,entry_msc,deadline,last_quote;
   double atr,pip,tick,stops,entry_bid,entry_ask;
   double mfe[2],mae[2],path_mfe[6],path_mae[6];
   bool checkpoints[3];
   TSTDBarrier barrier[12];
  };
struct TSTDPool {TSTDRecord records[TSTD_POOL];};
TSTDPool g_tstd_pools[];
int g_tstd_features=INVALID_HANDLE,g_tstd_outcomes=INVALID_HANDLE;
long g_tstd_episodes=0,g_tstd_censored=0,g_tstd_capacity=0,g_tstd_feature_invalid=0;
long g_tstd_latency=0;

string TSTDNumber(const double v){return MathIsValidNumber(v)?DoubleToString(v,12):"";}
void TSTDAdd(string &line,const string value){line+=","+value;}
string TSTDOutcomeHeader()
  {return "episode_id,symbol,market_cluster_id,t0_msc,signal_processing_msc,direction,distance_index,distance_atr,atr14_m5,entry_msc,entry_bid,entry_ask,entry_price,entry_spread,pip_size,tick_size,stops_distance,distance,sl,tp,status,exit_msc,exit_price,gross_pips,gross_r,mfe_60,mae_60,mfe_300,mae_300,mfe_900,mae_900,tp_touch_seconds,sl_touch_seconds,entry_eligible_msc,source_quote_msc";}

void TSTDWrite(const TSTDRecord &r,const bool censored)
  {
   for(int side=0;side<2;++side)for(int k=0;k<TSTD_DISTANCES;++k)
     {
      int d=side==0?1:-1;TSTDBarrier b=r.barrier[side*TSTD_DISTANCES+k];
      string status=b.status;
      if(!r.entered)status="NO_ENTRY";
      else if(status=="OPEN")status="CENSORED";
      string line=r.episode_id;TSTDAdd(line,r.symbol);TSTDAdd(line,(string)r.cluster);
      TSTDAdd(line,(string)r.t0);TSTDAdd(line,(string)r.processing);TSTDAdd(line,(string)d);
      TSTDAdd(line,(string)k);TSTDAdd(line,TSTDNumber(TSTD_ATR_MULT[k]));TSTDAdd(line,TSTDNumber(r.atr));
      TSTDAdd(line,(string)r.entry_msc);TSTDAdd(line,TSTDNumber(r.entry_bid));TSTDAdd(line,TSTDNumber(r.entry_ask));
      TSTDAdd(line,TSTDNumber(d>0?r.entry_ask:r.entry_bid));TSTDAdd(line,TSTDNumber(r.entry_ask-r.entry_bid));
      TSTDAdd(line,TSTDNumber(r.pip));TSTDAdd(line,TSTDNumber(r.tick));TSTDAdd(line,TSTDNumber(r.stops));
      TSTDAdd(line,TSTDNumber(b.distance));TSTDAdd(line,TSTDNumber(b.sl));TSTDAdd(line,TSTDNumber(b.tp));
      TSTDAdd(line,status);TSTDAdd(line,(string)b.exit_msc);TSTDAdd(line,TSTDNumber(b.exit_price));
      bool valid=status=="TP"||status=="SL"||status=="TIME";
      TSTDAdd(line,valid?TSTDNumber(b.gross_pips):"");TSTDAdd(line,valid?TSTDNumber(b.gross_r):"");
      for(int c=0;c<3;++c){TSTDAdd(line,r.checkpoints[c]?TSTDNumber(r.path_mfe[c*2+side]):"");TSTDAdd(line,r.checkpoints[c]?TSTDNumber(r.path_mae[c*2+side]):"");}
      TSTDAdd(line,r.entered&&b.tp_touch_seconds>=0?TSTDNumber(b.tp_touch_seconds):"");TSTDAdd(line,r.entered&&b.sl_touch_seconds>=0?TSTDNumber(b.sl_touch_seconds):"");
      TSTDAdd(line,(string)r.eligible);TSTDAdd(line,(string)r.quote);
      FileWriteString(g_tstd_outcomes,line+"\r\n");
     }
   FileFlush(g_tstd_outcomes);if(censored)++g_tstd_censored;
  }

void TSTDEnter(TSTDRecord &r,const long q,const double bid,const double ask)
  {
   r.entered=true;r.entry_msc=q;r.deadline=q+900000;r.entry_bid=bid;r.entry_ask=ask;
   double spread=ask-bid;
   for(int side=0;side<2;++side)for(int k=0;k<TSTD_DISTANCES;++k)
     {
      int d=side==0?1:-1;double entry=d>0?ask:bid;TSTDBarrier b;ZeroMemory(b);
      b.tp_touch_seconds=-1;b.sl_touch_seconds=-1;
      b.distance=MathCeil(TSTD_ATR_MULT[k]*r.atr/r.tick-1e-10)*r.tick;
      b.sl=entry-d*b.distance;b.tp=entry+d*b.distance;b.status="OPEN";
      if(b.distance<3.0*spread-1e-12)b.status="COST_DISTANCE_REJECT";
      else if((d>0&&(bid-b.sl<r.stops-1e-12||b.tp-bid<r.stops-1e-12))||
              (d<0&&(b.sl-ask<r.stops-1e-12||ask-b.tp<r.stops-1e-12)))b.status="BROKER_DISTANCE_REJECT";
      r.barrier[side*TSTD_DISTANCES+k]=b;
     }
  }

void TSTDAdvance(TSTDRecord &r,const long q,const double bid,const double ask)
  {
   if(!r.active||bid<=0||ask<=bid||q<r.last_quote)return;
   r.last_quote=q;
   if(!r.entered)
     {
      if(q<=r.t0||q<=r.quote||q<r.eligible)return;
      if(q>r.t0+30000){r.active=false;TSTDWrite(r,true);return;}
      TSTDEnter(r,q,bid,ask);return;
     }
   if(q<=r.entry_msc)return;
   for(int side=0;side<2;++side)
     {
      int d=side==0?1:-1;double entry=d>0?r.entry_ask:r.entry_bid,exit=d>0?bid:ask;
      double change=d*(exit-entry);r.mfe[side]=MathMax(r.mfe[side],change);r.mae[side]=MathMax(r.mae[side],-change);
      for(int k=0;k<TSTD_DISTANCES;++k)
        {
         int index=side*TSTD_DISTANCES+k;TSTDBarrier b=r.barrier[index];
         bool tp=d*(exit-b.tp)>=-1e-12,sl=d*(exit-b.sl)<=1e-12;
         if(tp&&b.tp_touch_seconds<0)b.tp_touch_seconds=(q-r.entry_msc)/1000.0;
         if(sl&&b.sl_touch_seconds<0)b.sl_touch_seconds=(q-r.entry_msc)/1000.0;
         if(b.status=="OPEN")
           {
            if(tp){b.status="TP";b.exit_price=b.tp;}
            else if(sl){b.status="SL";b.exit_price=exit;}
            else if(q>=r.deadline){b.status="TIME";b.exit_price=exit;}
            if(b.status!="OPEN")
              {b.exit_msc=q;b.gross_pips=d*(b.exit_price-entry)/r.pip;b.gross_r=d*(b.exit_price-entry)/b.distance;}
           }
         r.barrier[index]=b;
        }
     }
   int seconds[3]={60,300,900};
   for(int c=0;c<3;++c)if(!r.checkpoints[c]&&q>=r.entry_msc+seconds[c]*1000)
     {r.checkpoints[c]=true;for(int side=0;side<2;++side){r.path_mfe[c*2+side]=r.mfe[side];r.path_mae[c*2+side]=r.mae[side];}}
   if(q>=r.deadline){r.active=false;TSTDWrite(r,false);}
  }

bool TSTDInit(const string folder,const int symbols,const long latency)
  {
   g_tstd_latency=latency;ArrayResize(g_tstd_pools,symbols);
   for(int i=0;i<symbols;++i)ZeroMemory(g_tstd_pools[i]);
   string base=folder+"\\technical_";
   if(FileIsExist(base+"features.csv",FILE_COMMON)||FileIsExist(base+"outcomes.csv",FILE_COMMON))return false;
   g_tstd_features=FileOpen(base+"features.csv",FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
   g_tstd_outcomes=FileOpen(base+"outcomes.csv",FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
   if(g_tstd_features==INVALID_HANDLE||g_tstd_outcomes==INVALID_HANDLE)return false;
   FileWriteString(g_tstd_features,"episode_id,event_id,market_cluster_id,symbol,event_shock_direction,t0_msc,t0_processing_msc,t0_quote_msc,feature_max_close_msc,feature_future_count,feature_available_count,atr14_m1,atr14_m5,"+TSTechSchemaNamesCsv()+"\r\n");
   FileWriteString(g_tstd_outcomes,TSTDOutcomeHeader()+"\r\n");return true;
  }

bool TSTDArm(const int symbol_index,const string episode,const string event_id,const string symbol,const long cluster,
              const int shock_direction,const long t0,const long quote,const long processing,const double bid,const double ask,
              const int digits,const double point,const double tick,const double stops)
  {
   TSTechSnapshot f;bool captured=TSTechCapture(symbol,t0,quote,(bid+ask)*.5,ask-bid,shock_direction,f);
   if(!captured||f.atr14_m5<=0||f.max_source_close_msc>t0||f.future_source_count>0){++g_tstd_feature_invalid;return true;}
   int slot=-1;for(int i=0;i<TSTD_POOL;++i)if(!g_tstd_pools[symbol_index].records[i].active){slot=i;break;}
   if(slot<0){++g_tstd_capacity;return false;}
   TSTDRecord r;ZeroMemory(r);r.active=true;r.episode_id=episode;r.symbol=symbol;r.cluster=cluster;
   r.t0=t0;r.quote=quote;r.processing=processing;r.eligible=MathMax(t0,processing+g_tstd_latency);
   r.atr=f.atr14_m5;r.pip=(digits==3||digits==5)?point*10:point;r.tick=tick;r.stops=stops;
   g_tstd_pools[symbol_index].records[slot]=r;
   string line=episode+","+event_id+","+(string)cluster+","+symbol+","+(string)shock_direction+","+(string)t0+","+(string)processing+","+(string)quote;
   TSTDAdd(line,(string)f.max_source_close_msc);TSTDAdd(line,(string)f.future_source_count);TSTDAdd(line,(string)f.available_count);
   TSTDAdd(line,TSTDNumber(f.atr14_m1));TSTDAdd(line,TSTDNumber(f.atr14_m5));TSTDAdd(line,TSTechValuesCsv(f));
   FileWriteString(g_tstd_features,line+"\r\n");FileFlush(g_tstd_features);++g_tstd_episodes;
#ifdef TS_TECH_CANDIDATE
   TSTCOnSnapshot(episode,symbol,t0,processing,quote,f);
#endif
   return true;
  }
void TSTDObserve(const int i,const long q,const double bid,const double ask)
  {for(int slot=0;slot<TSTD_POOL;++slot)if(g_tstd_pools[i].records[slot].active)TSTDAdvance(g_tstd_pools[i].records[slot],q,bid,ask);}
void TSTDFinish()
  {
   for(int i=0;i<ArraySize(g_tstd_pools);++i)for(int slot=0;slot<TSTD_POOL;++slot)
      if(g_tstd_pools[i].records[slot].active){TSTDWrite(g_tstd_pools[i].records[slot],true);g_tstd_pools[i].records[slot].active=false;}
   if(g_tstd_features!=INVALID_HANDLE)FileClose(g_tstd_features);
   if(g_tstd_outcomes!=INVALID_HANDLE)FileClose(g_tstd_outcomes);
   PrintFormat("technical_discovery episodes=%I64d censored=%I64d capacity=%I64d feature_invalid=%I64d orders=0",g_tstd_episodes,g_tstd_censored,g_tstd_capacity,g_tstd_feature_invalid);
  }
#endif
