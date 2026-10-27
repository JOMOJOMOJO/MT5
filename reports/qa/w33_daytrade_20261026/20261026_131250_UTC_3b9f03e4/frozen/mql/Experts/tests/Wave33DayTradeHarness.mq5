// Native plumbing QA, not a strategy-performance backtest. Canned stage and
// aged clock below are explicit fixtures; every fill/modification is native.
bool qa_dt_sl_rejected=false,qa_dt_close_rejected=false;
bool QADayTradeSend(MqlTradeRequest &request,MqlTradeResult &result)
  {
   if(request.action==TRADE_ACTION_SLTP && !qa_dt_sl_rejected)
     {qa_dt_sl_rejected=true;ZeroMemory(result);result.retcode=TRADE_RETCODE_INVALID_STOPS;result.comment="QA_INJECTED_SL_REJECTION";return false;}
   if(request.action==TRADE_ACTION_DEAL && request.position>0 && !qa_dt_close_rejected)
     {qa_dt_close_rejected=true;ZeroMemory(result);result.retcode=TRADE_RETCODE_REQUOTE;result.comment="QA_INJECTED_CLOSE_REJECTION";return false;}
   return OrderSend(request,result);
  }
#define OrderSend QADayTradeSend
#define OnInit W33DayBaseInit
#define OnTick W33DayBaseTick
#define OnDeinit W33DayBaseDeinit
#define OnTradeTransaction W33DayBaseTransaction
#define OnChartEvent W33DayBaseChart
#include "../Wave33DayTradeVerifier.mq5"
#undef OnInit
#undef OnTick
#undef OnDeinit
#undef OnTradeTransaction
#undef OnChartEvent
#undef OrderSend
#include "../../Include/Wave33Visual/DayTradePolicyTests.mqh"
int qa_dt_file=INVALID_HANDLE,qa_dt_phase=0,qa_dt_case=0,qa_dt_record=-1,qa_dt_native_checks=0,qa_dt_failures=0;
bool qa_dt_done=false;datetime qa_dt_started=0;double qa_dt_risk=0,qa_dt_expected_sl=0;
void DTNativeCheck(const string name,const bool ok)
  {qa_dt_native_checks++;if(!ok)qa_dt_failures++;Print("DAYTRADE_NATIVE ",name," ",ok?"PASS":"FAIL");if(qa_dt_file!=INVALID_HANDLE){FileWrite(qa_dt_file,name,ok?"PASS":"FAIL");FileFlush(qa_dt_file);}}
void DTNativeSummary()
  {
   if(qa_dt_done)return;qa_dt_done=true;
   if(qa_dt_file!=INVALID_HANDLE){FileWrite(qa_dt_file,"SUMMARY",qa_dt_failures==0?"PASS":"FAIL",qa_dt_native_checks,qa_dt_failures);FileFlush(qa_dt_file);}
   Print("DAYTRADE_NATIVE_SUMMARY checks=",qa_dt_native_checks," failures=",qa_dt_failures);TesterStop();
  }
bool DTNativeOpen(const int direction)
  {
   MqlTick tick;if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0 || tick.ask<tick.bid)return false;
   int i=ArraySize(g_records);ArrayResize(g_records,i+1);ZeroMemory(g_records[i]);
   W33Setup s;ZeroMemory(s);s.setup_id="W33_DAY190_QA_"+(direction>0?"LONG":"SHORT");s.symbol=_Symbol;s.direction=direction;s.upper_tf=g_upper;s.lower_tf=g_lower;
   s.entry_price=direction>0?tick.ask:tick.bid;s.sl_price=PriceRound(s.entry_price-direction*20.0,-direction);s.tp_price=0;
   s.wave1_start_price=s.entry_price-direction*30;s.wave1_peak_price=s.entry_price+direction*20;s.wave1_peak_fixed=true;
   s.wave2_extreme_price=s.sl_price;s.risk_points=MathAbs(s.entry_price-s.sl_price)/_Point;
   s.entry_status="QA_ORDER_SENT";s.order_sent_at=TimeCurrent();g_records[i].setup=s;g_records[i].initial_sl_price=s.sl_price;g_records[i].pending=true;
   double volume=MathMax(SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),0.02),loss=0;
   volume=NormalizeDouble(volume,8);
   if(!OrderCalcProfit(direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,volume,s.entry_price,s.sl_price,loss))
     {DTNativeCheck("fixture_risk_calc",false);g_records[i].pending=false;return false;}
   g_records[i].initial_risk_money=MathAbs(loss);
   MqlTradeRequest request;MqlTradeResult result;MqlTradeCheckResult check;ZeroMemory(request);ZeroMemory(result);ZeroMemory(check);
   request.action=TRADE_ACTION_DEAL;request.symbol=_Symbol;request.magic=InpMagic;request.type=direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   request.volume=volume;request.price=s.entry_price;request.sl=s.sl_price;request.tp=0;request.deviation=InpDeviationPoints;request.comment=s.setup_id;
   long fill=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);request.type_filling=(fill&SYMBOL_FILLING_FOK)!=0?ORDER_FILLING_FOK:((fill&SYMBOL_FILLING_IOC)!=0?ORDER_FILLING_IOC:ORDER_FILLING_RETURN);
   if(!OrderCheck(request,check)){DTNativeCheck("fixture_order_check",false);g_records[i].pending=false;return false;}
   bool sent=OrderSend(request,result);g_records[i].entry_order_ticket=result.order;
   if(!sent || !AcceptedDeal(result.retcode)){DTNativeCheck("fixture_order_send",false);g_records[i].pending=false;return false;}
   qa_dt_record=i;qa_dt_sl_rejected=false;qa_dt_close_rejected=false;return true;
  }
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER) || !InpEnableTesterOrders || InpScaleOut)return INIT_FAILED;
   int initialized=W33DayBaseInit();if(initialized!=INIT_SUCCEEDED)return initialized;
   qa_dt_file=FileOpen(g_tag+"_native_tests.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,';',CP_UTF8);
   DTNativeCheck("native_report_file",qa_dt_file!=INVALID_HANDLE);
   int policyFailures=W33RunDayTradePolicyTests(g_tag);DTNativeCheck("policy_checks",policyFailures==0);
   DTNativeCheck("production_defaults_24h",W33DTEq(InpMaxHoldHours,24));
   DTNativeCheck("production_default_stages",W33DTEq(InpStepStartR,2) && W33DTEq(InpStepSizeR,1) && W33DTEq(InpStepLagR,2));
   Print("DAYTRADE_QA_FIXTURES: canned MFE at2R with temporarylag2.5R for valid native SL; aged first-fill clock for timeout routing. Not performance evidence.");
   return INIT_SUCCEEDED;
  }
void OnTick()
  {
   if(qa_dt_done)return;if(qa_dt_started==0)qa_dt_started=TimeCurrent();
   if(TimeCurrent()-qa_dt_started>600){DTNativeCheck("watchdog_completed_both_sides",false);DTNativeSummary();return;}
   g_tick_order++;DayTradeReconcile();
   if(qa_dt_phase==0)
     {if(DTNativeOpen(qa_dt_case==0?1:-1))qa_dt_phase=1;return;}
   int i=qa_dt_record;if(i<0)return;
   ulong ticket;
   if(qa_dt_phase==1)
     {
      if(!OwnedPosition(i,ticket) || !DayTradeEnsureState(i))return;
      DTNativeCheck("native_tp_zero_"+(string)qa_dt_case,W33DTEq(PositionGetDouble(POSITION_TP),0));
      DTNativeCheck("deadline_from_actual_fill_"+(string)qa_dt_case,W33DayTradeDeadlineMSC(g_records[i].day,g_day_config)==g_records[i].day_first_fill_msc+86400000);
      qa_dt_risk=g_records[i].initial_risk_money;g_day_config.lag_r=2.5;
      W33ObserveDayTradeQuote(g_records[i].day,g_day_config,g_records[i].day.entry+g_records[i].day.direction*2*g_records[i].day.risk_price);
      qa_dt_expected_sl=PriceRound(g_records[i].day.entry-g_records[i].day.direction*0.5*g_records[i].day.risk_price,g_records[i].day.direction);
      DayTradeEvent(i,"QA_CANNED_STAGE","native request plumbing only; synthetic 2R observation and temporary lag2.5R");qa_dt_phase=2;
     }
   if(qa_dt_phase==2)
     {
      ManageDayTradeStops();DayTradeReconcile();if(!OwnedPosition(i,ticket))return;
      if(MathAbs(PositionGetDouble(POSITION_SL)-qa_dt_expected_sl)>_Point*0.5 || g_records[i].day_sl_pending)return;
      DTNativeCheck("sl_rejection_and_retry_"+(string)qa_dt_case,qa_dt_sl_rejected);
      DTNativeCheck("native_sl_confirmed_"+(string)qa_dt_case,MathAbs(g_records[i].setup.sl_price-qa_dt_expected_sl)<=_Point*0.5);
      DTNativeCheck("monetary_r_unchanged_"+(string)qa_dt_case,W33DTEq(qa_dt_risk,g_records[i].initial_risk_money));
      g_day_config.lag_r=2;g_records[i].day_first_fill_msc-=86400001;
      DayTradeEvent(i,"QA_AGED_CLOCK","test-only first-fill clock minus24h+1ms to exercise timeout close, not elapsed historical holding");
      g_records[i].opposite.request_pending=true;ManageDayTradeTimeExits();
      DTNativeCheck("opposite_close_lock_"+(string)qa_dt_case,!g_records[i].day_close_pending);g_records[i].opposite.request_pending=false;
      g_records[i].day_sl_pending=true; // A deadline may close even while an unobserved SL request is outstanding.
      g_records[i].day_sl_target=g_records[i].day.entry+g_records[i].day.direction*40.0; // Deliberately unobserved fixture target.
      DayTradeEvent(i,"QA_STALE_SL_PENDING","test-only unconfirmed SL request; deadline close must still proceed");qa_dt_phase=3;
     }
   if(qa_dt_phase==3)
     {
      ManageDayTradeTimeExits();if(g_records[i].setup.entry_status!="CLOSED")return;
      DTNativeCheck("close_rejection_and_retry_"+(string)qa_dt_case,qa_dt_close_rejected);
      DTNativeCheck("timeout_reason_"+(string)qa_dt_case,g_records[i].setup.exit_reason=="TIME_LIMIT_24H");
      DTNativeCheck("full_volume_conserved_"+(string)qa_dt_case,W33DTEq(g_records[i].filled_volume,g_records[i].exit_volume));
      DTNativeCheck("no_pending_after_close_"+(string)qa_dt_case,!g_records[i].day_close_pending && !g_records[i].day_sl_pending);
      qa_dt_case++;qa_dt_phase=0;if(qa_dt_case>=2)DTNativeSummary();
     }
  }
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {W33DayBaseTransaction(trans,request,result);}
void OnDeinit(const int reason)
  {
   if(!qa_dt_done && qa_dt_file!=INVALID_HANDLE){DTNativeCheck("completed_before_tester_end",false);FileWrite(qa_dt_file,"SUMMARY","FAIL",qa_dt_native_checks,qa_dt_failures);}
   W33DayBaseDeinit(reason);if(qa_dt_file!=INVALID_HANDLE)FileClose(qa_dt_file);
  }
