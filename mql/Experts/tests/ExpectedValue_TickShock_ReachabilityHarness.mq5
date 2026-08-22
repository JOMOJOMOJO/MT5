#property strict
#property version "1.00"

#include "..\..\Include\TickShockStateMachine.mqh"

input string InpRunId = "stage1";
input string InpLogFolder = "tick_shock_scalper";

int g_handle = INVALID_HANDLE;
int g_passed = 0;
int g_failed = 0;

void RecordResult(const int id,const string name,const bool passed,const string detail)
  {
   if(passed) ++g_passed; else ++g_failed;
   if(g_handle != INVALID_HANDLE)
      FileWrite(g_handle, id, name, passed ? "PASS" : "FAIL", detail);
  }

void PrepareFrozen(TickShockMachine &machine,const int direction)
  {
   double start = 100.0;
   double first = direction > 0 ? 110.0 : 90.0;
   double extreme = direction > 0 ? 111.0 : 89.0;
   TSStartBurst(machine, direction, 1000, start, first);
   TSAdvance(machine, 1100, extreme, 300, 3000, 15.0, 35.0, 50.0, 10000, 2);
   TSAdvance(machine, 1401, extreme, 300, 3000, 15.0, 35.0, 50.0, 10000, 2);
  }

bool ReachabilityPath(const int direction)
  {
   TickShockMachine machine;
   PrepareFrozen(machine, direction);
   if(machine.state != TS_WAIT_PULLBACK)
      return false;
   double pullback = direction > 0 ? 108.8 : 91.2;
   ENUM_TS_ACTION action = TSAdvance(machine, 1500, pullback, 300, 3000, 15.0, 35.0, 50.0, 10000, 2);
   if(action != TS_ACTION_PULLBACK_VALID || machine.state != TS_WAIT_REACCELERATION)
      return false;
   double break_one = direction > 0 ? 111.1 : 88.9;
   double break_two = direction > 0 ? 111.2 : 88.8;
   action = TSAdvance(machine, 1600, break_one, 300, 3000, 15.0, 35.0, 50.0, 10000, 2);
   if(action != TS_ACTION_NONE)
      return false;
   action = TSAdvance(machine, 1650, break_two, 300, 3000, 15.0, 35.0, 50.0, 10000, 2);
   return action == TS_ACTION_REACCELERATION;
  }

void RunTests()
  {
   RecordResult(1, "long_reachability", ReachabilityPath(1), "up shock -> pullback -> two confirming updates");
   RecordResult(2, "short_reachability", ReachabilityPath(-1), "down shock -> pullback -> two confirming updates");

   string reason = "";
   bool passed = !TSShockConditionsPass(0.5, 1.0, 4.0, 0.8, 5.0, 2.0, 1.0,
                                        3.5, 0.65, 4.0, 1.5, 1.5, reason) && reason == "shock_percentile_failed";
   RecordResult(3, "insufficient_shock_move", passed, reason);

   reason = "";
   passed = !TSShockConditionsPass(2.0, 1.0, 4.0, 0.50, 5.0, 2.0, 1.0,
                                   3.5, 0.65, 4.0, 1.5, 1.5, reason) && reason == "efficiency_failed";
   RecordResult(4, "efficiency_failed", passed, reason);

   reason = "";
   passed = !TSShockConditionsPass(2.0, 1.0, 4.0, 0.80, 5.0, 2.0, 1.6,
                                   3.5, 0.65, 4.0, 1.5, 1.5, reason) && reason == "spread_too_wide";
   RecordResult(5, "spread_abnormal", passed, reason);

   TickShockMachine machine;
   PrepareFrozen(machine, 1);
   TSAdvance(machine, 1500, 110.0, 300, 3000, 15.0, 35.0, 50.0, 10000, 2);
   ENUM_TS_ACTION action = TSAdvance(machine, 11402, 110.0, 300, 3000, 15.0, 35.0, 50.0, 10000, 2);
   RecordResult(6, "pullback_below_15pct", action == TS_ACTION_PULLBACK_TIMEOUT, "10 percent then timeout");

   PrepareFrozen(machine, 1);
   action = TSAdvance(machine, 1500, 106.6, 300, 3000, 15.0, 35.0, 50.0, 10000, 2);
   RecordResult(7, "pullback_above_35pct", action == TS_ACTION_NONE && machine.too_deep_seen, "diagnostic, continuation not forced");

   PrepareFrozen(machine, 1);
   action = TSAdvance(machine, 1500, 105.5, 300, 3000, 15.0, 35.0, 50.0, 10000, 2);
   RecordResult(8, "pullback_50pct_invalidation", action == TS_ACTION_CONTINUATION_INVALIDATED, "reversal shadow trigger");

   PrepareFrozen(machine, 1);
   TSAdvance(machine, 1500, 108.8, 300, 3000, 15.0, 35.0, 50.0, 10000, 2);
   action = TSAdvance(machine, 11402, 109.0, 300, 3000, 15.0, 35.0, 50.0, 10000, 2);
   RecordResult(9, "no_reacceleration_timeout", action == TS_ACTION_NO_REACCELERATION, "valid pullback without breakout");

   reason = "";
   passed = !TSRiskConditionsPass(1.0, 4.0, 20.0, reason) && reason == "cost_too_large_vs_risk";
   RecordResult(10, "spread_too_large_vs_stop", passed, reason);

   reason = "";
   passed = !TSRiskConditionsPass(0.1, 5.0, 10.0, reason) && reason == "stop_too_wide_vs_burst";
   RecordResult(11, "stop_too_wide_vs_burst", passed, reason);

   double scores[3] = {10.0,25.0,20.0};
   RecordResult(12, "highest_score_selection", TSSelectHighestScore(scores, 3) == 1, "candidate index 1");

   RecordResult(13, "hard_120_second_exit", TSHardTimeExpired(1000, 121000, 120), "exact boundary");

   double result_r = 0.0;
   string exit_reason = "";
   bool short_ok = TSResolveShadowExit(-1, 100.0, 101.0, 98.8, 98.8, 1000, 2000, 120, result_r, exit_reason) &&
                   MathAbs(result_r - 1.2) < 1e-9 && exit_reason == "TP";
   result_r = 0.0;
   exit_reason = "";
   bool long_ok = TSResolveShadowExit(1, 100.0, 99.0, 101.2, 101.2, 1000, 2000, 120, result_r, exit_reason) &&
                  MathAbs(result_r - 1.2) < 1e-9 && exit_reason == "TP";
   RecordResult(14, "reversal_shadow_long_short", short_ok && long_ok, "Bid/Ask-side direction resolver");

   RecordResult(15, "cooldown", !TSCooldownComplete(59999, 60000) && TSCooldownComplete(60000, 60000), "boundary");
   RecordResult(16, "daily_loss_stop", !TSDailyLossBlocked(-2.99, 3.0) && TSDailyLossBlocked(-3.0, 3.0), "3R boundary");
  }

int OnInit()
  {
   FolderCreate(InpLogFolder, FILE_COMMON);
   string file_name = InpLogFolder + "\\ExpectedValue_TickShock_" + InpRunId + "_reachability.csv";
   g_handle = FileOpen(file_name, FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_COMMON, ',');
   if(g_handle == INVALID_HANDLE)
      return INIT_FAILED;
   FileWrite(g_handle, "test_id", "test_name", "result", "detail");
   RunTests();
   FileWrite(g_handle, "SUMMARY", "all", g_failed == 0 ? "PASS" : "FAIL",
             "passed=" + IntegerToString(g_passed) + ";failed=" + IntegerToString(g_failed));
   FileFlush(g_handle);
   PrintFormat("TickShock reachability tests: passed=%d failed=%d", g_passed, g_failed);
   return g_failed == 0 ? INIT_SUCCEEDED : INIT_FAILED;
  }

void OnDeinit(const int reason)
  {
   if(g_handle != INVALID_HANDLE)
      FileClose(g_handle);
  }

void OnTick()
  {
  }
