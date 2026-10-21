// Research-only observer around the unchanged production source.
#define OnInit ProductionInit
#define OnTick ProductionTick
#define OnDeinit ProductionDeinit
#define OnTradeTransaction ProductionTransaction
#include "USDJPY_M1_M5_3WaveIn3Wave_Long.mq5"
#undef OnInit
#undef OnTick
#undef OnDeinit
#undef OnTradeTransaction
struct AuditPath { ulong deal; long start,last; double entry,sl,risk,mfe,mae; bool done; };
AuditPath paths[];
int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER)) return INIT_FAILED;
   return ProductionInit();
}
void ObservePaths()
{
   MqlTick t; if(!SymbolInfoTick(_Symbol,t)) return;
   for(int i=0;i<ArraySize(paths);i++)
   {
      if(paths[i].done) continue;
      if(t.time_msc>paths[i].start+86400000) {paths[i].done=true;continue;}
      double r=(t.bid-paths[i].entry)/paths[i].risk;
      paths[i].mfe=MathMax(paths[i].mfe,r); paths[i].mae=MathMax(paths[i].mae,-r);
      paths[i].last=t.time_msc;
      if(t.bid<=paths[i].sl) paths[i].done=true;
   }
}
void OnTick() { ObservePaths(); ProductionTick(); }
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &req,const MqlTradeResult &res)
{
   ProductionTransaction(trans,req,res);
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD || trans.deal==0) return;
   if(HistoryDealGetInteger(trans.deal,DEAL_MAGIC)!=(long)InpMagicNumber ||
      HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=_Symbol ||
      HistoryDealGetInteger(trans.deal,DEAL_ENTRY)!=DEAL_ENTRY_IN ||
      HistoryDealGetInteger(trans.deal,DEAL_TYPE)!=DEAL_TYPE_BUY) return;
   for(int i=0;i<ArraySize(paths);i++) if(paths[i].deal==trans.deal) return;
   AuditPath p={};p.deal=trans.deal;p.start=HistoryDealGetInteger(trans.deal,DEAL_TIME_MSC);
   p.entry=HistoryDealGetDouble(trans.deal,DEAL_PRICE);p.sl=plan.sl;p.risk=p.entry-p.sl;
   if(p.risk<=0) return;
   int n=ArraySize(paths);ArrayResize(paths,n+1);paths[n]=p;ObservePaths();
}
void OnDeinit(const int why)
{
   int f=FileOpen("TW_ready_paths.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(f!=INVALID_HANDLE)
   {
      FileWrite(f,"deal","entry_msc","entry","sl","risk","mfe_until_sl_or_24h","mae_until_sl_or_24h","path_complete","last_msc");
      for(int i=0;i<ArraySize(paths);i++) FileWrite(f,paths[i].deal,paths[i].start,paths[i].entry,paths[i].sl,paths[i].risk,paths[i].mfe,paths[i].mae,paths[i].done,paths[i].last);
      FileClose(f);
   }
   ProductionDeinit(why);
}
