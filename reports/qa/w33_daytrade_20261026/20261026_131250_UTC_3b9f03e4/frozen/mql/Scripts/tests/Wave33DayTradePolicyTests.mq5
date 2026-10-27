#property strict
#property script_show_inputs
#include "../../Include/Wave33Visual/DayTradePolicyTests.mqh"
input string InpPolicyTestTag="w33_day190_policy";
void OnStart(){int failures=W33RunDayTradePolicyTests(InpPolicyTestTag);Print("DAYTRADE_POLICY_SUMMARY checks=",g_dt_checks," failures=",failures);}
