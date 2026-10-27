#property strict
#property script_show_inputs
#include "../../Include/Wave33Visual/H1EfficiencyTests.mqh"

input string InpPolicyTestTag="w33_h1eff_policy";

void OnStart()
  {
   int failures=W33RunH1EfficiencyTests(InpPolicyTestTag);
   Print("H1_EFFICIENCY_POLICY_SUMMARY checks=",g_h1eff_checks," failures=",failures);
  }
