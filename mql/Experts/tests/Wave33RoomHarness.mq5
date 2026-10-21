#property strict
#property version "1.00"
#include "../../Include/Wave33Visual/Room.mqh"
input string InpRunTag="room_harness";
int g_file=INVALID_HANDLE,g_pass=0,g_fail=0;
void Check(const string name,const bool ok)
  {if(ok)g_pass++;else g_fail++;FileWrite(g_file,name,ok?"PASS":"FAIL","Executable quote to fixed W1 signed room");}
void Case(W33Setup &s,const int direction,const double entry,const double sl,const double peak)
  {ZeroMemory(s);s.direction=direction;s.entry_price=entry;s.sl_price=sl;s.wave1_peak_price=peak;}
int OnInit()
  {
   g_file=FileOpen("W33Harness_"+InpRunTag+".csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(g_file==INVALID_HANDLE)return INIT_FAILED;
   FileWrite(g_file,"test","passed","detail");W33Setup s;
   Case(s,1,111.577,111.435,111.639);Check("accepted_sep5_long",W33CheckWave1Room(s,0.25));
   Check("accepted_long_room",MathAbs(s.wave1_room_r-0.4366197183)<1e-8);
   Case(s,-1,111.529,111.598,111.427);Check("accepted_sep5_short",W33CheckWave1Room(s,0.25));
   Check("accepted_short_room",MathAbs(s.wave1_room_r-1.4782608696)<1e-8);
   Case(s,1,109.268,109.178,109.396);Check("accepted_apr26_long",W33CheckWave1Room(s,0.25));
   Case(s,1,111.398,111.234,111.419);Check("late_sep6_rejected",!W33CheckWave1Room(s,0.25));
   Check("late_sep6_room",MathAbs(s.wave1_room_r-0.1280487805)<1e-8);
   Case(s,1,112.074,111.902,112.083);Check("late_sep17_rejected",!W33CheckWave1Room(s,0.25));
   Case(s,1,112.681,112.513,112.676);Check("late_sep24_ask_beyond_peak",!W33CheckWave1Room(s,0.25));
   Check("beyond_peak_negative",s.wave1_room_price<0 && s.wave1_room_r<0);
   Case(s,1,100,96,101);Check("exact_boundary_long",W33CheckWave1Room(s,0.25));
   Case(s,-1,100,104,99);Check("exact_boundary_short",W33CheckWave1Room(s,0.25));
   Case(s,1,100.01,96,101);Check("spread_can_cross_boundary",!W33CheckWave1Room(s,0.25));
   Case(s,-1,99.99,104,99);Check("short_quote_can_cross_boundary",!W33CheckWave1Room(s,0.25));
   Case(s,1,100,96,100);Check("at_peak_rejected",!W33CheckWave1Room(s,0.25));
   Check("legacy_switch_allows_at_peak",W33CheckWave1Room(s,0));
   Case(s,-1,98,104,99);Check("short_past_endpoint_rejected",!W33CheckWave1Room(s,0.25));
   Check("legacy_allows_past_endpoint",W33CheckWave1Room(s,0));
   Case(s,1,100,100,101);Check("invalid_risk_rejected",!W33CheckWave1Room(s,0.25));
   FileWrite(g_file,"FINAL",g_fail==0?"PASS":"FAIL",StringFormat("passed=%d failed=%d",g_pass,g_fail));
   FileFlush(g_file);FileClose(g_file);g_file=INVALID_HANDLE;
   PrintFormat("W33_ROOM_HARNESS_FINAL passed=%d failed=%d",g_pass,g_fail);return INIT_SUCCEEDED;
  }
void OnTick(){if(MQLInfoInteger(MQL_TESTER))TesterStop();}
double OnTester(){return g_fail==0?1.0:0.0;}
