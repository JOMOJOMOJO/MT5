#property strict
#define TS_TECH_DISCOVERY
#define TS_TECH_CANDIDATE
#include "../Include/TickShockTwoStageTimeLabels.mqh"
#define OnInit TSGResearchInit
#define OnDeinit TSGResearchDeinit
#define OnTick TSGResearchTick
#define OnTimer TSGResearchTimer
#include "../Include/TickShock4m2mFrozen/mql/Experts/ExpectedValue_MultiCurrency_TickShockResearch.mq5"
#undef OnInit
#undef OnDeinit
#undef OnTick
#undef OnTimer
#include "../Include/TickShockTwoStageBarrierCandidate.mqh"
int OnInit(){if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;int r=TSGResearchInit();if(r!=INIT_SUCCEEDED)return r;return TSTCInit(InpLogFolder)?INIT_SUCCEEDED:INIT_FAILED;}
void OnTick(){TSTCManage();TSGResearchTick();TSTCPump();}
void OnTimer(){TSTCManage();TSGResearchTimer();}
void OnDeinit(const int reason){if(!MQLInfoInteger(MQL_TESTER))return;TSTCFinish();TSGResearchDeinit(reason);}
