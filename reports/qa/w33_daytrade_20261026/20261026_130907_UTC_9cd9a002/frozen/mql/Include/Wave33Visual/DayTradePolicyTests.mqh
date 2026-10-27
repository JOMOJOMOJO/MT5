#ifndef W33_DAY_POLICY_TESTS
#define W33_DAY_POLICY_TESTS
#include "DayTrade.mqh"
int g_dt_checks=0,g_dt_failures=0,g_dt_test_file=INVALID_HANDLE;
void W33DTCheck(const string name,const bool ok)
  {g_dt_checks++;if(!ok)g_dt_failures++;Print("DAYTRADE_POLICY ",name," ",ok?"PASS":"FAIL");if(g_dt_test_file!=INVALID_HANDLE)FileWrite(g_dt_test_file,name,ok?"PASS":"FAIL");}
bool W33DTEq(const double a,const double b){return MathAbs(a-b)<1e-8;}
int W33RunDayTradePolicyTests(const string tag)
  {
   g_dt_checks=0;g_dt_failures=0;g_dt_test_file=FileOpen(tag+"_policy_tests.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,';',CP_UTF8);
   W33DTCheck("report_file",g_dt_test_file!=INVALID_HANDLE);
   W33DayTradeConfig c;c.enable_step=true;c.start_r=2;c.step_r=1;c.lag_r=2;c.max_hold_hours=24;
   W33DTCheck("default_config",W33DayTradeConfigValid(c));
   for(int direction=-1;direction<=1;direction+=2)
     {
      string prefix=direction>0?"LONG_":"SHORT_";W33DayTradeState s;ZeroMemory(s);
      W33DTCheck(prefix+"init",W33InitDayTradeState(s,direction,1600000000000,100,100-direction));
      W33DTCheck(prefix+"immutable_reinit",!W33InitDayTradeState(s,-direction,1700000000000,90,91));
      W33DTCheck(prefix+"risk_frozen",W33DTEq(s.risk_price,1) && s.first_fill_msc==1600000000000);
      W33DTCheck(prefix+"one_r_no_move",!W33ObserveDayTradeQuote(s,c,100+direction) && s.stage_reached==-1);
      W33DTCheck(prefix+"two_r_stage",W33ObserveDayTradeQuote(s,c,100+2*direction) && W33DTEq(s.desired_sl_r,0));
      W33DayTradeSLPlan p=W33BuildDayTradeSLPlan(s,c,100-direction,100+2*direction,0.01,0.01,2,20,0);
      W33DTCheck(prefix+"two_r_entry_sl",p.can_modify && W33DTEq(p.target_sl,100));
      W33DTCheck(prefix+"repeat_no_stage",!W33ObserveDayTradeQuote(s,c,100+2*direction));
      W33DTCheck(prefix+"three_r",W33ObserveDayTradeQuote(s,c,100+3*direction) && W33DTEq(s.desired_sl_r,1));
      p=W33BuildDayTradeSLPlan(s,c,100,100+3*direction,0.01,0.01,2,20,30);
      W33DTCheck(prefix+"three_r_sl",p.can_modify && W33DTEq(p.target_sl,100+direction));
      W33ObserveDayTradeQuote(s,c,100+1.1*direction);
      p=W33BuildDayTradeSLPlan(s,c,100,100+1.1*direction,0.01,0.01,2,20,30);
      W33DTCheck(prefix+"pullback_wait",p.valid && !p.can_modify && W33DTEq(s.max_favorable_r,3));
      p=W33BuildDayTradeSLPlan(s,c,100,100+3*direction,0.01,0.01,2,20,30);
      W33DTCheck(prefix+"pending_stage_retained",p.can_modify && W33DTEq(p.target_sl,100+direction));
      p=W33BuildDayTradeSLPlan(s,c,100+2*direction,100+4*direction,0.01,0.01,2,20,30);
      W33DTCheck(prefix+"never_loosen_broker_sl",p.already_protected && !p.can_modify);
      W33ObserveDayTradeQuote(s,c,100+8.9*direction);
      W33DTCheck(prefix+"jump_stages",W33DTEq(s.desired_sl_r,6));
      W33DTCheck(prefix+"initial_r_unchanged",W33DTEq(s.risk_price,1) && W33DTEq(s.original_sl,100-direction));
      W33DTCheck(prefix+"deadline",W33DayTradeDeadlineMSC(s,c)==1600086400000);
      W33DTCheck(prefix+"deadline_before",!W33DayTradeDeadlineDue(s,c,1600086399999));
      W33DTCheck(prefix+"deadline_equal",W33DayTradeDeadlineDue(s,c,1600086400000));
      W33DTCheck(prefix+"deadline_after",W33DayTradeDeadlineDue(s,c,1600086400001));
      W33DayTradeState grid;ZeroMemory(grid);W33InitDayTradeState(grid,direction,1600000000000,100.1,100.1-direction);
      W33ObserveDayTradeQuote(grid,c,100.1+2*direction);p=W33BuildDayTradeSLPlan(grid,c,grid.original_sl,100.1+2*direction,0.01,0.25,2,20,0);
      W33DTCheck(prefix+"favorable_grid_round",p.can_modify && W33DTEq(p.target_sl,direction>0?100.25:100.0));
      p=W33BuildDayTradeSLPlan(grid,c,grid.original_sl,100.1+2*direction,0.01,0,2,20,0);
      W33DTCheck(prefix+"invalid_tick",!p.valid && !p.can_modify);
     }
   W33DayTradeConfig bad=c;bad.step_r=0;W33DTCheck("invalid_step",!W33DayTradeConfigValid(bad));
   bad=c;bad.start_r=0;W33DTCheck("invalid_start",!W33DayTradeConfigValid(bad));
   bad=c;bad.lag_r=-1;W33DTCheck("invalid_lag",!W33DayTradeConfigValid(bad));
   bad=c;bad.max_hold_hours=25;W33DTCheck("reject_over_24h",!W33DayTradeConfigValid(bad));
   bad=c;bad.max_hold_hours=0;W33DTCheck("reject_zero_hold",!W33DayTradeConfigValid(bad));
   W33DayTradeState off;ZeroMemory(off);W33InitDayTradeState(off,1,1600000000000,100,99);bad=c;bad.enable_step=false;
   W33DTCheck("step_off",!W33ObserveDayTradeQuote(off,bad,110) && off.stage_reached==-1);
   W33DTCheck("weekend_before",!W33DayTradeWeekCloseDue(999699999,1000000000,300));
   W33DTCheck("weekend_equal",W33DayTradeWeekCloseDue(999700000,1000000000,300));
   W33DTCheck("weekend_unknown",!W33DayTradeWeekCloseDue(1000000000,0,300));
   W33DTCheck("weekend_after_session",!W33DayTradeWeekCloseDue(1000000001,1000000000,300));
   if(g_dt_test_file!=INVALID_HANDLE){FileWrite(g_dt_test_file,"SUMMARY",g_dt_failures==0?"PASS":"FAIL",g_dt_checks,g_dt_failures);FileClose(g_dt_test_file);g_dt_test_file=INVALID_HANDLE;}
   return g_dt_failures;
  }
#endif
