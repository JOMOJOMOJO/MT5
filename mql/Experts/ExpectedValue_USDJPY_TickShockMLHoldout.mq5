// USDJPY-only frozen diagnostic. Strategy Tester only, never live trading.
#property strict
#include "../Include/TickShockUSDJPYOnlyModel.mqh"
#define TS_TECH_DISCOVERY
#define TS_TECH_CANDIDATE
#define OnInit TSTCResearchInit
#define OnDeinit TSTCResearchDeinit
#define OnTick TSTCResearchTick
#define OnTimer TSTCResearchTimer
#include "../Include/TickShock4m2mFrozen/mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5"
#undef OnInit
#undef OnDeinit
#undef OnTick
#undef OnTimer
#define TSTCOnSnapshot TSTCBaseOnSnapshot
#include "../Include/TickShock4m2mFrozen/mql/Include/TickShock/TickShockTechnicalCandidate.mqh"
#undef TSTCOnSnapshot

void TSTCOnSnapshot(const string episode,const string symbol,const long t0,const long processing,const long quote,const TSTechSnapshot &f)
  {
   // Preserve collection dispatcher clocks, but never score/order other symbols.
   if(symbol!="USDJPY")return;
   TSTCBaseOnSnapshot(episode,symbol,t0,processing,quote,f);
  }
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER)){Print("USDJPY ML: Strategy Tester only");return INIT_FAILED;}
   int result=TSTCResearchInit();if(result!=INIT_SUCCEEDED)return result;
   if(!TSTCInit(InpLogFolder))return INIT_FAILED;
   return INIT_SUCCEEDED;
  }
void OnTick(){TSTCManage();TSTCResearchTick();TSTCPump();}
void OnTimer(){TSTCResearchTimer();}
void OnDeinit(const int reason)
  {
   g_tstc_stopping=true;
   if(MQLInfoInteger(MQL_TESTER)){TSTCClose("END_OF_TEST");TSTCCollect();}
   TSTCResearchDeinit(reason);TSTCFinish();
  }
