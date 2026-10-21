// Research-only observer around the unchanged production source.
#define OnInit ProductionInit
#define OnTick ProductionTick
#define OnDeinit ProductionDeinit
#define OnTradeTransaction ProductionTransaction
#include "../Include/ReadyM15EMAOffFrozen/Production.mqh"
#undef OnInit
#undef OnTick
#undef OnDeinit
#undef OnTradeTransaction
struct AuditPath { ulong deal; long start,last; double entry,sl,risk,mfe,mae; bool done; };
AuditPath paths[];
int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER) || InpUseEMAFilter || InpHLEntryMode!=HL_ENTRY_READY || InpSkipLowerHL || InpStopMode!=STOP_M1_REVERSAL_LOW) return INIT_PARAMETERS_INCORRECT;
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
void OnTick() { ObserveShadows(); ObservePaths(); ProductionTick(); }
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
   ExportShadows();
   ProductionDeinit(why);
}

struct ReadyShadow {
 string id; long start,last,exit_time; double entry,sl,tp,risk,mfe,mae,result;
 double mfe_exit,mae_exit; bool done,path_done; string outcome;
 datetime wave1_confirmed,hl_confirmed;
};
ReadyShadow shadows[];
void ObserveShadow(ReadyShadow &x,const MqlTick &t)
{
 if(t.time_msc<x.start) return;
 double r=(t.bid-x.entry)/x.risk;
 if(!x.path_done) {
  if(t.time_msc<=x.start+86400000) {x.mfe=MathMax(x.mfe,r);x.mae=MathMax(x.mae,-r);x.last=t.time_msc;}
  if(t.bid<=x.sl || t.time_msc>=x.start+86400000) x.path_done=true;
 }
 if(!x.done) {
  x.mfe_exit=MathMax(x.mfe_exit,r);x.mae_exit=MathMax(x.mae_exit,-r);
  if(t.bid<=x.sl) {x.done=true;x.result=r;x.outcome="SL";}
  else if(t.bid>=x.tp) {x.done=true;x.result=(x.tp-x.entry)/x.risk;x.outcome="TP";}
  if(x.done) x.exit_time=t.time_msc;
 }
}
void ObserveShadows()
{
 MqlTick t; if(!SymbolInfoTick(_Symbol,t)) return;
 for(int i=0;i<ArraySize(shadows);i++) if(!shadows[i].done || !shadows[i].path_done) ObserveShadow(shadows[i],t);
}
void AuditShadowReady(const M5Setup &s,const M1Pattern &p)
{
 string id=SignalID(s,p);
 for(int i=0;i<ArraySize(shadows);i++) if(shadows[i].id==id) return;
 MqlTick t; if(!SymbolInfoTick(_Symbol,t) || t.ask<=0 || t.bid<=0) return;
 ReadyShadow x={}; x.id=id;x.start=t.time_msc;x.entry=t.ask;
 double step=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
 if(step<=0) return;
 x.sl=Price(FloorStep(p.reversal_low.price-InpSLBufferPoints*_Point,step));x.risk=x.entry-x.sl;
 x.tp=Price(MathRound((x.entry+x.risk*InpRewardRisk)/step)*step);
 x.wave1_confirmed=p.wave1_high.confirmed_time;x.hl_confirmed=p.hl.confirmed_time;
 x.outcome=x.risk>0 ? "END_CENSORED" : "INVALID_RISK";
 if(x.risk>0) ObserveShadow(x,t);else {x.done=true;x.path_done=true;}
 int n=ArraySize(shadows);ArrayResize(shadows,n+1);shadows[n]=x;
}
void ExportShadows()
{
 int f=FileOpen("TW_ready_shadows.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
 if(f==INVALID_HANDLE) {Print("SHADOW_EXPORT_FAILED ",GetLastError());return;}
 FileWrite(f,"signal_id","entry_msc","entry","sl","tp","risk","outcome","exit_msc","result_r","mfe_to_exit","mae_to_exit","mfe_until_sl_or_24h","mae_until_sl_or_24h","path_complete","last_msc","wave1_confirmed","hl_confirmed");
 for(int i=0;i<ArraySize(shadows);i++) {
  ReadyShadow x=shadows[i];
  FileWrite(f,x.id,x.start,x.entry,x.sl,x.tp,x.risk,x.outcome,x.exit_time,
   x.done && x.risk>0 ? DoubleToString(x.result,12):"",x.mfe_exit,x.mae_exit,x.mfe,x.mae,x.path_done,x.last,(long)x.wave1_confirmed,(long)x.hl_confirmed);
 }
 FileClose(f);
}
