#ifndef TICK_SHOCK_TWO_STAGE_TIME_LABELS_MQH
#define TICK_SHOCK_TWO_STAGE_TIME_LABELS_MQH
// Sidecar observer; original detector, entry and barrier code remains unchanged.
#define TSTDInit TSTDOriginalInit
#define TSTDObserve TSTDOriginalObserve
#define TSTDFinish TSTDOriginalFinish
#include "TickShock4m2mFrozen/mql/Include/TickShock/TickShockTechnicalStudy.mqh"
#undef TSTDInit
#undef TSTDObserve
#undef TSTDFinish

struct TSTimeRecord
  {
   bool active;
   string episode,symbol;
   long cluster,t0,processing,entry,last,time_mfe[2];
   double bid,ask,atr,pip,mfe[2],mae[2];
   bool done[3];
  };
struct TSTimePool {TSTimeRecord records[TSTD_POOL];};
TSTimePool g_tstime[];
int g_tstime_file=INVALID_HANDLE;
long g_tstime_rows=0,g_tstime_capacity=0,g_tstime_censored=0;

void TSTimeWrite(const TSTimeRecord &r,const int h,const long q,const double bid,const double ask,const bool valid)
  {
   int horizons[3]={300,600,900};
   for(int s=0;s<2;++s)
     {
      int d=s==0?1:-1;double entry=d>0?r.ask:r.bid,exit=d>0?bid:ask;
      string line=r.episode+","+r.symbol+","+(string)r.cluster+","+(string)r.t0+","+(string)r.processing;
      line+=","+(string)d+","+(string)horizons[h]+","+(string)r.entry+","+TSTDNumber(r.bid)+","+TSTDNumber(r.ask);
      line+=","+TSTDNumber(r.atr)+","+TSTDNumber(r.pip)+","+(valid?"TIME":"CENSORED");
      line+=","+(valid?(string)q:"")+","+(valid?TSTDNumber(exit):"");
      line+=","+(valid?TSTDNumber(d*(exit-entry)/r.atr):"")+","+(valid?TSTDNumber(d*(exit-entry)/r.pip):"");
      line+=","+TSTDNumber(r.mfe[s])+","+TSTDNumber(r.mae[s])+","+(string)r.time_mfe[s];
      FileWriteString(g_tstime_file,line+"\r\n");++g_tstime_rows;
     }
  }
void TSTimeAdvance(TSTimeRecord &r,const long q,const double bid,const double ask)
  {
   if(!r.active||q<=r.entry||q<r.last||bid<=0||ask<=bid)return;
   r.last=q;
   for(int s=0;s<2;++s)
     {
      double move=s==0?bid-r.ask:r.bid-ask;
      if(move>r.mfe[s]){r.mfe[s]=move;r.time_mfe[s]=q-r.entry;}
      r.mae[s]=MathMax(r.mae[s],-move);
     }
   int horizons[3]={300,600,900};
   for(int h=0;h<3;++h)if(!r.done[h]&&q>=r.entry+(long)horizons[h]*1000)
     {TSTimeWrite(r,h,q,bid,ask,true);r.done[h]=true;}
   if(r.done[2])r.active=false;
  }
bool TSTDInit(const string folder,const int symbols,const long latency)
  {
   string path=folder+"\\fixed_time_outcomes.csv";
   if(FileIsExist(path,FILE_COMMON))return false;
   if(!TSTDOriginalInit(folder,symbols,latency))return false;
   ArrayResize(g_tstime,symbols);for(int i=0;i<symbols;++i)ZeroMemory(g_tstime[i]);
   g_tstime_file=FileOpen(path,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
   if(g_tstime_file==INVALID_HANDLE)return false;
   FileWriteString(g_tstime_file,"episode_id,symbol,market_cluster_id,t0_msc,signal_processing_msc,direction,horizon_seconds,entry_msc,entry_bid,entry_ask,atr14_m5,pip_size,status,exit_msc,exit_price,gross_r,gross_pips,mfe,mae,time_to_mfe_ms\r\n");
   return true;
  }
void TSTDObserve(const int i,const long q,const double bid,const double ask)
  {
   for(int k=0;k<TSTD_POOL;++k)TSTimeAdvance(g_tstime[i].records[k],q,bid,ask);
   TSTDOriginalObserve(i,q,bid,ask);
   for(int k=0;k<TSTD_POOL;++k)
     {
      TSTDRecord original=g_tstd_pools[i].records[k];
      if(!original.active||!original.entered||original.entry_msc!=q)continue;
      bool seen=false;for(int j=0;j<TSTD_POOL;++j)if(g_tstime[i].records[j].episode==original.episode_id){seen=true;break;}
      if(seen)continue;
      int slot=-1;for(int j=0;j<TSTD_POOL;++j)if(!g_tstime[i].records[j].active){slot=j;break;}
      if(slot<0){++g_tstime_capacity;continue;}
      TSTimeRecord r;ZeroMemory(r);r.active=true;r.episode=original.episode_id;r.symbol=original.symbol;
      r.cluster=original.cluster;r.t0=original.t0;r.processing=original.processing;r.entry=q;r.last=q;
      r.bid=original.entry_bid;r.ask=original.entry_ask;r.atr=original.atr;r.pip=original.pip;
      g_tstime[i].records[slot]=r;
     }
  }
void TSTDFinish()
  {
   for(int i=0;i<ArraySize(g_tstime);++i)for(int k=0;k<TSTD_POOL;++k)
     {
      TSTimeRecord r=g_tstime[i].records[k];if(!r.active)continue;
      for(int h=0;h<3;++h)if(!r.done[h]){TSTimeWrite(r,h,0,0,0,false);++g_tstime_censored;}
     }
   if(g_tstime_file!=INVALID_HANDLE){FileFlush(g_tstime_file);FileClose(g_tstime_file);}
   PrintFormat("two_stage_time_labels rows=%I64d capacity=%I64d censored=%I64d orders=0",g_tstime_rows,g_tstime_capacity,g_tstime_censored);
   TSTDOriginalFinish();
  }
#endif
