#property strict
#define TS_TECH_DISCOVERY
#include "../Include/TickShockTwoStageTimeLabels.mqh"
#define OnInit TSTwoStageResearchInit
#include "../Include/TickShock4m2mFrozen/mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5"
#undef OnInit
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER)){Print("Two-stage collector: Strategy Tester only");return INIT_FAILED;}
   return TSTwoStageResearchInit();
  }
