#property strict
// TESTER ONLY. One-ATR sizing normalization is not a loss cap; fixed-time exit, no TP/SL.
#define TS_TECH_DISCOVERY
#define TS_TECH_CANDIDATE
#include "../Include/TickShockTwoStageTimeLabels.mqh"
#define OnInit TS2ResearchInit
#define OnDeinit TS2ResearchDeinit
#define OnTick TS2ResearchTick
#define OnTimer TS2ResearchTimer
#include "../Include/TickShock4m2mFrozen/mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5"
#undef OnInit
#undef OnDeinit
#undef OnTick
#undef OnTimer
#include "../Include/TickShockTwoStageCandidate.mqh"
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER)){Print("Two-stage candidate: Strategy Tester only");return INIT_FAILED;}
   int result=TS2ResearchInit();if(result!=INIT_SUCCEEDED)return result;
   if(!TSTCInit(InpLogFolder))return INIT_FAILED;
   return INIT_SUCCEEDED;
  }
void OnTick(){TSTCManage();TS2ResearchTick();TSTCPump();}
void OnTimer(){TS2ResearchTimer();}
void OnDeinit(const int reason)
  {
   if(!MQLInfoInteger(MQL_TESTER))return;
   g_tstc_stopping=true;
   if(MQLInfoInteger(MQL_TESTER)){TSTCClose("END_OF_TEST");TSTCCollect();}
   TS2ResearchDeinit(reason);TSTCFinish();
  }
