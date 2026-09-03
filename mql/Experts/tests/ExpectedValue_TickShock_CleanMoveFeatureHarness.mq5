#property copyright "OpenAI"
#property version   "1.00"
#property strict

#include "..\..\Include\TickShock\TickShockCleanMoveFeatures.mqh"

int g_pass=0;
int g_fail=0;

void Check(const string name,const bool condition)
  {if(condition){++g_pass;Print("TS15L ",name," PASS");}else{++g_fail;Print("TS15L ",name," FAIL");}}

int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER)){Print("TS15L tester_only FAIL");return INIT_FAILED;}
   TickShock15LState state;TS15LResetState(state);
   for(int i=0;i<=100;++i){long t=1000000+(long)i*1000;double bid=1.0000+(double)i*0.0001;TS15LObserveQuote(state,t,bid,bid+0.0002);}
   TickShock15FBarState bars;TS15FResetBarState(bars);TickShock15LSnapshot long_snapshot;
   bool built=TS15LBuildSnapshot(state,bars,"episode","event","EURUSD",1,1,1100000,0.0010,long_snapshot);
   Check("production_build",built);
   Check("return_5s",long_snapshot.available[0]&&MathAbs(long_snapshot.values[0]-0.5)<1e-9);
   Check("ticks_5s",long_snapshot.available[13]&&MathAbs(long_snapshot.values[13]-5.0)<1e-9);
   Check("range_30s",long_snapshot.available[20]&&long_snapshot.values[20]>=2.89&&long_snapshot.values[20]<=2.91);
   Check("causal_sources",TS15LFeatureSourcesCausal(long_snapshot)&&long_snapshot.future_sources==0);
   Check("ring_bounded",state.count<=TS15L_SECOND_CAPACITY);
   TickShock15LSnapshot short_snapshot;TS15LBuildSnapshot(state,bars,"episode2","event2","EURUSD",2,-1,1100000,0.0010,short_snapshot);
   Check("long_short_symmetry",short_snapshot.available[0]&&MathAbs(short_snapshot.values[0]+long_snapshot.values[0])<1e-9);
   Check("no_order_calls",TS15LResearchOrderCalls()==0);
   PrintFormat("TS15L RESULT pass=%d fail=%d",g_pass,g_fail);return g_fail==0?INIT_SUCCEEDED:INIT_FAILED;
  }

void OnTick(){}
