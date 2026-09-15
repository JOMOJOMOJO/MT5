// Jan-Apr 2025 trained; May-Jun locked diagnostic test. NOT a live EA.
#property strict
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
#include "../Include/TickShock4m2mFrozen/mql/Include/TickShock/TickShockTechnicalCandidate.mqh"

int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER)){Print("4m2m candidate: Strategy Tester only");return INIT_FAILED;}
   int result=TSTCResearchInit();if(result!=INIT_SUCCEEDED)return result;
   if(!TSTCInit(InpLogFolder))return INIT_FAILED;
   return INIT_SUCCEEDED;
  }
void OnTick(){TSTCManage();TSTCResearchTick();TSTCPump();}
void OnTimer(){TSTCResearchTimer();}
void OnDeinit(const int reason)
  {g_tstc_stopping=true;if(MQLInfoInteger(MQL_TESTER)){TSTCClose("END_OF_TEST");TSTCCollect();}TSTCResearchDeinit(reason);TSTCFinish();}
