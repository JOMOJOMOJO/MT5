#ifndef WAVE33_DAYTRADE_PARTIAL_POLICY_TESTS_MQH
#define WAVE33_DAYTRADE_PARTIAL_POLICY_TESTS_MQH
#include "DayTradePartial.mqh"
int w33_half_test_file=INVALID_HANDLE,w33_half_checks=0,w33_half_failures=0;
bool W33HalfEq(const double a,const double b){return MathAbs(a-b)<1e-8;}
void W33HalfCheck(const string name,const bool pass)
  {w33_half_checks++;if(!pass)w33_half_failures++;if(w33_half_test_file!=INVALID_HANDLE)FileWrite(w33_half_test_file,name,pass?"PASS":"FAIL");Print("HALF_POLICY ",name," ",pass?"PASS":"FAIL");}
int W33RunDayTradePartialPolicyTests(const string prefix)
  {
   w33_half_checks=0;w33_half_failures=0;
   w33_half_test_file=FileOpen(prefix+"_half_policy_tests.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,';',CP_UTF8);
   W33HalfCheck("report_open",w33_half_test_file!=INVALID_HANDLE);
   W33HalfCheck("round_down_odd",W33HalfEq(W33DayTradeSplittableVolumeDown(.05,.01,.01,100),.04));
   W33HalfCheck("minimum_two_legs",W33HalfEq(W33DayTradeSplittableVolumeDown(.01,.01,.01,100),0));
   W33HalfCheck("exact_even_preserved",W33HalfEq(W33DayTradeSplittableVolumeDown(.06,.01,.01,100),.06));
   W33HalfCheck("volume_max_even_floor",W33HalfEq(W33DayTradeSplittableVolumeDown(1,.01,.01,.09),.08));
   W33HalfCheck("no_risk_round_up",W33HalfEq(W33DayTradeSplittableVolumeDown(.039,.01,.01,100),.02));
   W33HalfCheck("min_gt_step",W33HalfEq(W33DayTradeSplittableVolumeDown(.05,.03,.01,100),0));
   W33HalfCheck("valid_legs_min_gt_step",W33HalfEq(W33DayTradeSplittableVolumeDown(.08,.03,.01,100),.08));
   W33HalfCheck("invalid_spec",W33HalfEq(W33DayTradeSplittableVolumeDown(.1,.01,0,100),0));
   W33HalfCheck("odd_actual_fill_rejected",!W33BuildDayTradeHalfPlan(.03,.01,.01,100).valid);
   W33HalfCheck("off_grid_actual_rejected",!W33BuildDayTradeHalfPlan(.041,.01,.01,100).valid);
   W33HalfCheck("actual_fill_too_small",!W33BuildDayTradeHalfPlan(.02,.02,.01,100).valid);
   W33HalfCheck("volume_tolerance_below_one_tiny_step",W33HalfVolumeTolerance(1e-8,2e-8)>0 && W33HalfVolumeTolerance(1e-8,2e-8)<1e-8);
   W33HalfCheck("volume_tolerance_relative_cap",W33HalfVolumeTolerance(1e-8,1e12)<1e-8);
   W33HalfCheck("invalid_step_tolerance_zero",W33HalfVolumeTolerance(0,.01)==0);
   W33HalfCheck("invalid_step_grid_rejected",!W33HalfOnGrid(.01,0));
   double tiny_sized=W33DayTradeSplittableVolumeDown(3e-8,1e-8,1e-8,1);
   W33HalfCheck("tiny_odd_risk_size_round_down",MathAbs(tiny_sized-2e-8)<1e-15 && tiny_sized<=3e-8);
   W33HalfCheck("tiny_minimum_two_legs",W33DayTradeSplittableVolumeDown(1e-8,1e-8,1e-8,1)==0);
   W33HalfCheck("tiny_half_below_min_rejected",!W33BuildDayTradeHalfPlan(2e-8,2e-8,1e-8,1).valid);
   W33HalfCheck("tiny_odd_actual_rejected",!W33BuildDayTradeHalfPlan(3e-8,1e-8,1e-8,1).valid);
   W33DayTradeConfig c;c.enable_step=true;c.start_r=1.5;c.step_r=.5;c.lag_r=.5;c.max_hold_hours=24;
   for(int d=-1;d<=1;d+=2)
     {
      string side=d>0?"LONG_":"SHORT_";W33DayTradeState day;ZeroMemory(day);
      W33HalfCheck(side+"init",W33InitDayTradeState(day,d,100000,100,100-d*10));
      W33DayTradePartialState half;ZeroMemory(half);
      W33HalfCheck(side+"half_init",W33InitDayTradePartialState(half,day,.08,.01,.01,100,1));
      W33HalfCheck(side+"exact_target",W33HalfEq(half.trigger_price,100+d*10) && W33HalfEq(half.target_close_volume,.04));
      double target=half.trigger_price;
      double bid=d>0?target-.01:target-.02,ask=d>0?target+.01:target+.01;
      W33HalfCheck(side+"spread_requires_close_side",!W33DayTradePartialQuoteHit(half,bid,ask));
      bid=d>0?target:target-.02;ask=d>0?target+.02:target;
      W33HalfCheck(side+"target_touch",W33ObserveDayTradePartialQuote(half,bid,ask));
      W33HalfCheck(side+"touch_once",!W33ObserveDayTradePartialQuote(half,bid,ask));
      W33HalfCheck(side+"bad_spread",!W33DayTradePartialQuoteHit(half,100,99));
      W33HalfCheck(side+"reinit_forbidden",!W33InitDayTradePartialState(half,day,.08,.01,.01,100,1));
      W33DayTradePartialRequest req=W33BuildDayTradePartialRequest(half,0,.08,.01,.01,100);
      W33HalfCheck(side+"first_half_request",req.valid && !req.complete && W33HalfEq(req.request_volume,.04));
      req=W33BuildDayTradePartialRequest(half,.02,.06,.01,.01,100);
      W33HalfCheck(side+"partial_fill_retry_residual",req.valid && W33HalfEq(req.request_volume,.02));
      req=W33BuildDayTradePartialRequest(half,.04,.04,.01,.01,100);
      W33HalfCheck(side+"half_complete_no_second_close",req.valid && req.complete && W33HalfEq(req.request_volume,0));
      W33HalfCheck(side+"acceptance_is_not_fill",!W33DayTradePartialComplete(half,0) && !W33DayTradePartialComplete(half,.02));
      W33HalfCheck(side+"confirmed_half",W33DayTradePartialComplete(half,.04));
      W33HalfCheck(side+"overclose_is_not_success",!W33DayTradePartialComplete(half,.05));
      W33HalfCheck(side+"mismatched_position",!W33BuildDayTradePartialRequest(half,.02,.05,.01,.01,100).valid);
      W33HalfCheck(side+"negative_confirmed",!W33BuildDayTradePartialRequest(half,-.01,.08,.01,.01,100).valid);
      W33HalfCheck(side+"nongrid_confirmed",!W33BuildDayTradePartialRequest(half,.005,.075,.01,.01,100).valid);
      W33HalfCheck(side+"overclose_rejected",!W33BuildDayTradePartialRequest(half,.05,.03,.01,.01,100).valid);
      W33DayTradePartialState tiny;ZeroMemory(tiny);
      W33HalfCheck(side+"tiny_half_init",W33InitDayTradePartialState(tiny,day,2e-8,1e-8,1e-8,1,1));
      W33HalfCheck(side+"tiny_step_frozen",MathAbs(tiny.volume_step-1e-8)<1e-15);
      W33HalfCheck(side+"tiny_zero_is_not_half",!W33DayTradePartialComplete(tiny,0));
      W33HalfCheck(side+"tiny_confirmed_half",W33DayTradePartialComplete(tiny,1e-8));
      W33HalfCheck(side+"tiny_one_step_overclose_not_half",!W33DayTradePartialComplete(tiny,2e-8));
      req=W33BuildDayTradePartialRequest(tiny,0,2e-8,1e-8,1e-8,1);
      W33HalfCheck(side+"tiny_first_half_request",req.valid && !req.complete && MathAbs(req.request_volume-1e-8)<1e-15);
      req=W33BuildDayTradePartialRequest(tiny,1e-8,1e-8,1e-8,1e-8,1);
      W33HalfCheck(side+"tiny_confirmed_no_second_order",req.valid && req.complete && req.request_volume==0);
      req=W33BuildDayTradePartialRequest(tiny,2e-8,1e-8,1e-8,1e-8,1);
      W33HalfCheck(side+"tiny_overclose_rejected",!req.valid);
      req=W33BuildDayTradePartialRequest(tiny,0,3e-8,1e-8,1e-8,1);
      W33HalfCheck(side+"tiny_one_step_ledger_mismatch",!req.valid);
      W33HalfCheck(side+"one_r_keeps_original_sl",!W33ObserveDayTradeQuote(day,c,100+d*10) && day.stage_reached==-1);
      W33HalfCheck(side+"below_1_5_r_wait",!W33ObserveDayTradeQuote(day,c,100+d*14.99));
      W33HalfCheck(side+"1_5_r_sl_1r",W33ObserveDayTradeQuote(day,c,100+d*15) && W33HalfEq(day.desired_sl_r,1));
      W33DayTradeSLPlan sl=W33BuildDayTradeSLPlan(day,c,day.original_sl,100+d*15,.01,.01,2,0,0);
      W33HalfCheck(side+"first_sl_price",sl.can_modify && W33HalfEq(sl.target_sl,100+d*10));
      W33HalfCheck(side+"2r_sl_1_5r",W33ObserveDayTradeQuote(day,c,100+d*20) && W33HalfEq(day.desired_sl_r,1.5));
      W33HalfCheck(side+"2_5r_sl_2r",W33ObserveDayTradeQuote(day,c,100+d*25) && W33HalfEq(day.desired_sl_r,2));
      W33HalfCheck(side+"3r_sl_2_5r",W33ObserveDayTradeQuote(day,c,100+d*30) && W33HalfEq(day.desired_sl_r,2.5));
      W33HalfCheck(side+"jump_5r_sl_4_5r",W33ObserveDayTradeQuote(day,c,100+d*50) && W33HalfEq(day.desired_sl_r,4.5));
      W33HalfCheck(side+"retrace_never_lower_stage",!W33ObserveDayTradeQuote(day,c,100+d*20) && W33HalfEq(day.desired_sl_r,4.5));
      sl=W33BuildDayTradeSLPlan(day,c,100+d*45,100+d*50,.01,.01,2,0,0);
      W33HalfCheck(side+"never_loosen_broker_sl",sl.already_protected && !sl.can_modify);
      W33HalfCheck(side+"fixed_original_r",W33HalfEq(day.risk_price,10) && W33HalfEq(half.risk_price,10) && W33HalfEq(day.entry,100));
      W33HalfCheck(side+"deadline_24h_unchanged",W33DayTradeDeadlineMSC(day,c)==86500000 && !W33DayTradeDeadlineDue(day,c,86499999) && W33DayTradeDeadlineDue(day,c,86500000));
     }
   if(w33_half_test_file!=INVALID_HANDLE){FileWrite(w33_half_test_file,"SUMMARY",w33_half_failures==0?"PASS":"FAIL",w33_half_checks,w33_half_failures);FileClose(w33_half_test_file);w33_half_test_file=INVALID_HANDLE;}
   return w33_half_failures;
  }
#endif
