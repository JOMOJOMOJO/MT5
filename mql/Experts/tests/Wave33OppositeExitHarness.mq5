#property strict
#property version "1.00"
#property description "Deterministic opposite-W1 exit policy tests; synthetic state, no orders."
#include "../../Include/Wave33Visual/OppositeExit.mqh"

input string InpRunTag="opposite_exit";
int g_file=INVALID_HANDLE,g_passed=0,g_failed=0;
datetime g_fill=D'2025.06.02 12:00:00';

void Check(const string name,const bool passed,const string detail)
  {
   if(passed) g_passed++; else g_failed++;
   // Native FileWrite does not CSV-quote delimiter characters inside strings.
   // Keep the complete detail in one semicolon-separated field.
   string csvDetail=detail;StringReplace(csvDetail,";"," / ");
   if(g_file!=INVALID_HANDLE) FileWrite(g_file,name,passed ? "PASS" : "FAIL",csvDetail);
   Print("W33_OPPOSITE_EXIT_TEST ",passed ? "PASS " : "FAIL ",name," ",detail);
  }

string Side(const int direction)
  {
   return direction==1 ? "LONG" : "SHORT";
  }

bool Arm(W33OppositeExitState &state,const int direction)
  {
   W33ResetOppositeExit(state);
   return W33ArmOppositeExit(state,direction,g_fill,100,"OPPOSITE_FIRST",-direction,g_fill+60,110);
  }

void TestArming(const int direction)
  {
   string key=Side(direction);
   W33OppositeExitState state;
   W33ResetOppositeExit(state);
   Check("reset_"+key,!state.armed && !state.request_pending && state.source_setup_id=="" && state.attempts==0,
         StringFormat("Fresh fill has no cause: armed=%d pending=%d source='%s' source_len=%d attempts=%d",
                      state.armed,state.request_pending,state.source_setup_id,StringLen(state.source_setup_id),state.attempts));
   Check("no_actual_fill_"+key,!W33ArmOppositeExit(state,direction,0,100,"OPP",-direction,g_fill+60,110) && !state.armed,
         "A signal without an actual fill cannot arm the exit");
   Check("no_fill_order_key_"+key,!W33ArmOppositeExit(state,direction,g_fill,0,"OPP",-direction,g_fill+60,110) && !state.armed,
         "Missing causal fill order is rejected");
   Check("prefill_time_"+key,!W33ArmOppositeExit(state,direction,g_fill,100,"OPP",-direction,g_fill-1,110) && !state.armed,
         "A source known before fill is rejected even if delivered in a later processing step");
   Check("prefill_order_"+key,!W33ArmOppositeExit(state,direction,g_fill,100,"OPP",-direction,g_fill+60,99) && !state.armed,
         "An event consumed before actual fill cannot be replayed into an armed exit");
   Check("same_fill_order_"+key,!W33ArmOppositeExit(state,direction,g_fill,100,"OPP",-direction,g_fill,100) && !state.armed,
         "The fill event itself is not a later opposite observation");
   Check("same_direction_"+key,!W33ArmOppositeExit(state,direction,g_fill,100,"SAME",direction,g_fill+60,110) && !state.armed,
         "A new first wave in the position direction cannot arm this exit");
   Check("missing_source_"+key,!W33ArmOppositeExit(state,direction,g_fill,100,"",-direction,g_fill+60,110) && !state.armed,
         "An unidentified source cannot arm the exit");
   Check("invalid_source_direction_"+key,!W33ArmOppositeExit(state,direction,g_fill,100,"OPP",0,g_fill+60,110) && !state.armed,
         "A non-directional event is rejected");
   Check("invalid_position_direction_"+key,!W33ArmOppositeExit(state,0,g_fill,100,"OPP",-direction,g_fill+60,110) && !state.armed,
         "A malformed position direction is rejected");
   Check("same_second_later_observation_"+key,W33ArmOppositeExit(state,direction,g_fill,100,"OPPOSITE_FIRST",-direction,g_fill,101) && state.armed &&
         state.detected_at==g_fill && state.detected_order_key==101 && state.source_direction==-direction,
         "A causally later opposite observation can arm within the same datetime second");
   Check("duplicate_does_not_rearm_"+key,!W33ArmOppositeExit(state,direction,g_fill,100,"OPPOSITE_FIRST",-direction,g_fill+1,102) &&
         state.source_setup_id=="OPPOSITE_FIRST" && state.detected_at==g_fill && state.detected_order_key==101,
         "A duplicate source leaves the first observation unchanged");
   Check("first_source_preserved_"+key,!W33ArmOppositeExit(state,direction,g_fill,100,"OPPOSITE_SECOND",-direction,g_fill+120,120) &&
         state.source_setup_id=="OPPOSITE_FIRST" && state.detected_at==g_fill,
         "Later opposite setups cannot replace the latched cause");
   W33ResetOppositeExit(state);
   Check("later_second_observation_"+key,W33ArmOppositeExit(state,direction,g_fill,100,"LATER_OPPOSITE",-direction,g_fill+60,110) &&
         state.detected_at==g_fill+60 && state.detected_order_key==110,
         "A source is dated at actual observation availability, not its older swing candle");
  }

void TestGuardsAndProfit(const int direction)
  {
   string key=Side(direction);
   W33OppositeExitState state;
   W33ResetOppositeExit(state);
   Check("not_armed_"+key,!W33ShouldRequestOppositeExit(state,true,true,true,1.0),
         "Positive floating net alone is insufficient before an opposite observation");
   Arm(state,direction);
   Check("disabled_"+key,!W33ShouldRequestOppositeExit(state,false,true,true,1.0),"Disabled policy never requests an exit");
   Check("tester_only_"+key,!W33ShouldRequestOppositeExit(state,true,false,true,1.0),"A normal chart cannot request an exit");
   Check("no_owned_position_"+key,!W33ShouldRequestOppositeExit(state,true,true,false,1.0),"Missing, foreign or already-flat position cannot request an exit");
   Check("negative_net_waits_"+key,!W33ShouldRequestOppositeExit(state,true,true,true,-0.01) && state.armed,
         "A loss waits with the original protective exit levels managed by the caller");
   Check("zero_net_waits_"+key,!W33ShouldRequestOppositeExit(state,true,true,true,0.0) && state.armed,
         "Exactly zero is not strictly profitable");
   Check("first_positive_requests_"+key,W33ShouldRequestOppositeExit(state,true,true,true,0.01),
         "The first positive executable net estimate becomes eligible immediately");
   Check("positive_at_observation_"+key,W33ShouldRequestOppositeExit(state,true,true,true,10.0),
         "Already profitable at opposite recognition requires no extra candle or target");
   double invalid=MathArcsin(2.0);
   Check("invalid_net_waits_"+key,!MathIsValidNumber(invalid) && !W33ShouldRequestOppositeExit(state,true,true,true,invalid),
         "An invalid profit estimate never becomes an exit permission");
   double overflow=1e308;
   overflow*=10.0;
   Check("positive_infinity_waits_"+key,!MathIsValidNumber(overflow) && !W33ShouldRequestOppositeExit(state,true,true,true,overflow),
         "Positive infinity is not an executable profit estimate");
   Check("negative_infinity_waits_"+key,!W33ShouldRequestOppositeExit(state,true,true,true,-overflow),
         "Negative infinity cannot trigger an exit");
   Check("source_invalidation_sticky_"+key,W33ShouldRequestOppositeExit(state,true,true,true,0.1) && state.source_setup_id=="OPPOSITE_FIRST",
         "An unrelated engine source lifecycle change has no policy reset; arming survives until the position closes");
  }

void TestRequestsAndResidual(const int direction)
  {
   string key=Side(direction);
   W33OppositeExitState state;
   W33ResetOppositeExit(state);
   Check("unarmed_request_denied_"+key,!W33MarkOppositeExitRequested(state,g_fill+60,110) && state.attempts==0,
         "No request can be marked without a cause");
   Arm(state,direction);
   Check("backdated_request_denied_"+key,!W33MarkOppositeExitRequested(state,g_fill+59,110) && !state.request_pending,
         "A close request cannot precede its observed cause");
   Check("earlier_order_request_denied_"+key,!W33MarkOppositeExitRequested(state,g_fill+60,109) && !state.request_pending,
         "A request cannot use a processing order older than its cause");
   Check("immediate_request_"+key,W33MarkOppositeExitRequested(state,g_fill+60,110) && state.request_pending && state.attempts==1 &&
         state.requested_at==g_fill+60 && state.requested_order_key==110,
         "The observation tick may also submit the first profitable close request");
   Check("pending_blocks_duplicate_"+key,!W33ShouldRequestOppositeExit(state,true,true,true,100.0) &&
         !W33MarkOppositeExitRequested(state,g_fill+61,111) && state.attempts==1,
         "An outstanding request suppresses duplicate close submission");
   W33ResolveOppositeExitRequest(state,true);
   Check("rejection_reopens_retry_"+key,state.armed && !state.request_pending && state.attempts==1 &&
         state.source_setup_id=="OPPOSITE_FIRST" && W33ShouldRequestOppositeExit(state,true,true,true,1.0),
         "A rejected request retains the original source and permits a profitable retry");
   Check("retry_waits_if_negative_"+key,!W33ShouldRequestOppositeExit(state,true,true,true,-1.0),
         "A rejected request cannot force a later loss-taking retry");
   Check("retry_marked_"+key,W33MarkOppositeExitRequested(state,g_fill+61,111) && state.attempts==2,
         "The retry has its own observable request time and attempt count");
   W33ResolveOppositeExitRequest(state,true);
   Check("partial_fill_residual_"+key,state.armed && !state.request_pending && state.attempts==2 &&
         W33ShouldRequestOppositeExit(state,true,true,true,0.5),
         "A partially closed residual remains eligible at its next positive net estimate");
   W33MarkOppositeExitRequested(state,g_fill+62,112);
   W33ResolveOppositeExitRequest(state,false);
   Check("flat_clears_all_"+key,!state.armed && !state.request_pending && state.source_setup_id=="" && state.attempts==0 &&
         state.detected_at==0 && state.detected_order_key==0 && state.requested_at==0 && state.requested_order_key==0,
         StringFormat("Flat clears all fields: armed=%d pending=%d source='%s' attempts=%d detected=%I64d detected_key=%I64u requested=%I64d requested_key=%I64u",
                      state.armed,state.request_pending,state.source_setup_id,state.attempts,(long)state.detected_at,state.detected_order_key,
                      (long)state.requested_at,state.requested_order_key));
   Check("new_position_not_prearmed_"+key,!W33ShouldRequestOppositeExit(state,true,true,true,100.0),
         "A later position cannot inherit the previous position's exit cause");
  }

void TestNetEstimate()
  {
   W33OppositeExitState state;
   Arm(state,1);
   double zero=W33OppositeNetEstimate(0.5,-0.25,0.0,0.125,2.0);
   Check("net_zero_after_cost_waits",zero==0.0 && !W33ShouldRequestOppositeExit(state,true,true,true,zero),
         "Quote profit exactly covering booked entry cost and estimated exit cost is not positive net");
   double positive=W33OppositeNetEstimate(0.5001,-0.25,0.0,0.125,2.0);
   Check("net_first_positive_after_cost",positive>0.0 && W33ShouldRequestOppositeExit(state,true,true,true,positive),
         "The first quote estimate strictly above both known and estimated costs requests an exit");
   double negative=W33OppositeNetEstimate(0.2,-0.25,0.0,0.125,2.0);
   Check("gross_positive_net_negative_waits",negative<0.0 && !W33ShouldRequestOppositeExit(state,true,true,true,negative),
         "A positive quote result is insufficient while total estimated net remains negative");
   Check("net_remaining_swap_included",MathAbs(W33OppositeNetEstimate(5.0,-1.0,-0.5,1.0,2.0)-1.5)<1e-12,
         "Open-volume swap and all booked cash are included once in total estimated net");
   Check("net_realized_partial_cash_included",MathAbs(W33OppositeNetEstimate(-0.5,2.0,0.0,0.5,1.0)-1.0)<1e-12,
         "Booked partial-exit cash participates in the remaining position's total scenario result");
   Check("net_remaining_volume_cost",MathAbs(W33OppositeNetEstimate(5.0,-1.0,0.0,0.5,0.5)-3.75)<1e-12,
         "Estimated exit cost scales with residual volume rather than original filled volume");
   Check("net_negative_cost_clamped",W33OppositeNetEstimate(1.0,0.0,0.0,-5.0,1.0)==1.0,
         "A negative estimated fee cannot manufacture extra profit by extrapolating rebates");
   Check("net_zero_volume_allowed",W33OppositeNetEstimate(1.0,0.0,0.0,5.0,0.0)==1.0,
         "Zero residual volume has no closing cost; the independent own-position guard prevents an order");
   Check("net_negative_volume_invalid",!MathIsValidNumber(W33OppositeNetEstimate(1.0,0.0,0.0,1.0,-1.0)),
         "Negative residual volume is invalid rather than an artificial profit rebate");
   double invalid=MathArcsin(2.0);
   Check("net_invalid_quote_rejected",!MathIsValidNumber(W33OppositeNetEstimate(invalid,0.0,0.0,1.0,1.0)),"Invalid quote profit propagates as unavailable net");
   Check("net_invalid_cash_rejected",!MathIsValidNumber(W33OppositeNetEstimate(1.0,invalid,0.0,1.0,1.0)),"Invalid booked cash propagates as unavailable net");
   Check("net_invalid_swap_rejected",!MathIsValidNumber(W33OppositeNetEstimate(1.0,0.0,invalid,1.0,1.0)),"Invalid open swap propagates as unavailable net");
   Check("net_invalid_cost_rejected",!MathIsValidNumber(W33OppositeNetEstimate(1.0,0.0,0.0,invalid,1.0)),"Invalid fee estimate propagates as unavailable net");
   Check("net_invalid_volume_rejected",!MathIsValidNumber(W33OppositeNetEstimate(1.0,0.0,0.0,1.0,invalid)),"Invalid residual volume propagates as unavailable net");
   Check("net_overflow_rejected",!MathIsValidNumber(W33OppositeNetEstimate(1.0,0.0,0.0,1e308,10.0)),"Overflowing closing-cost arithmetic cannot authorize an exit");
   Check("net_sum_overflow_rejected",!MathIsValidNumber(W33OppositeNetEstimate(1e308,1e308,0.0,0.0,1.0)),"Overflowing total profit arithmetic cannot authorize an exit");
   Check("net_no_cost_exact",W33OppositeNetEstimate(10.0,0.0,0.0,0.0,1.0)==10.0,
         "No observed commission or fee adds no invented fee estimate");
  }

int OnInit()
  {
   g_file=FileOpen("W33Harness_"+InpRunTag+".csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,';');
   if(g_file==INVALID_HANDLE) return INIT_FAILED;
   FileWrite(g_file,"test","passed","detail");
   TestNetEstimate();
   for(int direction=1;direction>=-1;direction-=2)
     {
      TestArming(direction);
      TestGuardsAndProfit(direction);
      TestRequestsAndResidual(direction);
     }
   FileWrite(g_file,"FINAL",g_failed==0 ? "PASS" : "FAIL",StringFormat("passed=%d failed=%d",g_passed,g_failed));
   FileFlush(g_file); FileClose(g_file); g_file=INVALID_HANDLE;
   PrintFormat("W33_OPPOSITE_EXIT_HARNESS_FINAL passed=%d failed=%d",g_passed,g_failed);
   return INIT_SUCCEEDED;
  }
void OnTick() { if(MQLInfoInteger(MQL_TESTER)) TesterStop(); }
double OnTester() { return g_failed==0 ? 1.0 : 0.0; }
