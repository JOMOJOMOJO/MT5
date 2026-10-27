#property strict
#property script_show_inputs
#include "../../Include/Wave33Visual/DayTradePartialPolicyTests.mqh"
input string InpPrefix="w33_daypartial_policy";
void OnStart(){W33RunDayTradePartialPolicyTests(InpPrefix);}
