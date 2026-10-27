// Native plumbing QA only. Trigger/MFE/clock fixtures below are explicit;
// native fills and SL acknowledgements are real tester transactions.
bool qa_dtp_half_rejected=false,qa_dtp_sl_rejected=false,qa_dtp_close_rejected=false;
bool QADayPartialSend(MqlTradeRequest &request,MqlTradeResult &result)
  {
   if(request.action==TRADE_ACTION_DEAL && request.position>0 && StringFind(request.comment,"HALF")>=0 && !qa_dtp_half_rejected)
     {qa_dtp_half_rejected=true;ZeroMemory(result);result.retcode=TRADE_RETCODE_REQUOTE;result.comment="QA_INJECTED_HALF_REJECTION";return false;}
   if(request.action==TRADE_ACTION_SLTP && !qa_dtp_sl_rejected)
     {qa_dtp_sl_rejected=true;ZeroMemory(result);result.retcode=TRADE_RETCODE_INVALID_STOPS;result.comment="QA_INJECTED_SL_REJECTION";return false;}
   if(request.action==TRADE_ACTION_DEAL && request.position>0 && StringFind(request.comment,"HALF")<0 && !qa_dtp_close_rejected)
     {qa_dtp_close_rejected=true;ZeroMemory(result);result.retcode=TRADE_RETCODE_REQUOTE;result.comment="QA_INJECTED_CLOSE_REJECTION";return false;}
   return OrderSend(request,result);
  }
#define OrderSend QADayPartialSend
#define OnInit W33PartialBaseInit
#define OnTick W33PartialBaseTick
#define OnDeinit W33PartialBaseDeinit
#define OnTradeTransaction W33PartialBaseTransaction
#define OnChartEvent W33PartialBaseChart
#include "../Wave33DayTradePartialVerifier.mq5"
#undef OnInit
#undef OnTick
#undef OnDeinit
#undef OnTradeTransaction
#undef OnChartEvent
#undef OrderSend
#include "../../Include/Wave33Visual/DayTradePartialPolicyTests.mqh"
int qa_dtp_file=INVALID_HANDLE,qa_dtp_phase=0,qa_dtp_case=0,qa_dtp_record=-1,qa_dtp_checks=0,qa_dtp_failures=0;
bool qa_dtp_done=false;
datetime qa_dtp_started=0,qa_dtp_open_retry=0;
double qa_dtp_risk=0,qa_dtp_expected_sl=0,qa_dtp_initial_volume=0;
string qa_dtp_readiness_reason="";
void DTPNativeCheck(const string name,const bool ok)
  {
   qa_dtp_checks++;if(!ok)qa_dtp_failures++;
   Print("DAYPARTIAL_NATIVE ",name," ",ok?"PASS":"FAIL");
   if(qa_dtp_file!=INVALID_HANDLE){FileWrite(qa_dtp_file,name,ok?"PASS":"FAIL");FileFlush(qa_dtp_file);}
  }
void DTPNativeWait(const string reason)
  {
   qa_dtp_open_retry=TimeCurrent()+1;
   if(reason==qa_dtp_readiness_reason)return;
   qa_dtp_readiness_reason=reason;Print("DAYPARTIAL_NATIVE WAIT_READINESS ",reason);
   if(qa_dtp_file!=INVALID_HANDLE){FileWrite(qa_dtp_file,"WAIT_READINESS",reason,W33Time(TimeCurrent()));FileFlush(qa_dtp_file);}
  }
void DTPNativeSummary()
  {
   if(qa_dtp_done)return;qa_dtp_done=true;
   if(qa_dtp_file!=INVALID_HANDLE){FileWrite(qa_dtp_file,"SUMMARY",qa_dtp_failures==0?"PASS":"FAIL",qa_dtp_checks,qa_dtp_failures);FileFlush(qa_dtp_file);}
   Print("DAYPARTIAL_NATIVE_SUMMARY checks=",qa_dtp_checks," failures=",qa_dtp_failures);TesterStop();
  }
bool DTPNativeOpen(const int direction)
  {
   if(TimeCurrent()<qa_dtp_open_retry)return false;
   MqlTick tick;if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0 || tick.ask<tick.bid){DTPNativeWait("QUOTE_NOT_READY");return false;}
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),minlot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),maxlot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   if(step<=0 || minlot<=0){DTPNativeWait("VOLUME_SPEC_NOT_READY");return false;}
   // Each half is valid without rounding up a risk-sized production order.
   double leg_units=MathMax(MathCeil(minlot/step-1e-9),MathCeil(0.02/step-1e-9));
   double volume=NormalizeDouble(2*leg_units*step,8);
   if(volume>maxlot+1e-8){DTPNativeCheck("fixture_divisible_volume",false);DTPNativeSummary();return false;}
   W33Setup s;ZeroMemory(s);s.setup_id="W33_DAY191_QA_"+(direction>0?"LONG":"SHORT");s.symbol=_Symbol;s.direction=direction;s.upper_tf=g_upper;s.lower_tf=g_lower;
   s.entry_price=direction>0?tick.ask:tick.bid;s.sl_price=PriceRound(s.entry_price-direction*20.0,-direction);s.tp_price=0;
   s.wave1_start_price=s.entry_price-direction*30;s.wave1_peak_price=s.entry_price+direction*20;s.wave1_peak_fixed=true;
   s.wave2_extreme_price=s.sl_price;s.risk_points=MathAbs(s.entry_price-s.sl_price)/_Point;
   s.entry_status="QA_ORDER_SENT";s.order_sent_at=TimeCurrent();
   double loss=0;if(!OrderCalcProfit(direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,volume,s.entry_price,s.sl_price,loss))
     {DTPNativeCheck("fixture_risk_calc",false);DTPNativeSummary();return false;}
   MqlTradeRequest request;MqlTradeResult result;MqlTradeCheckResult check;ZeroMemory(request);ZeroMemory(result);ZeroMemory(check);
   request.action=TRADE_ACTION_DEAL;request.symbol=_Symbol;request.magic=InpMagic;request.type=direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   request.volume=volume;request.price=s.entry_price;request.sl=s.sl_price;request.tp=0;request.deviation=InpDeviationPoints;request.comment=s.setup_id;
   long fill=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);request.type_filling=(fill&SYMBOL_FILLING_FOK)!=0?ORDER_FILLING_FOK:((fill&SYMBOL_FILLING_IOC)!=0?ORDER_FILLING_IOC:ORDER_FILLING_RETURN);
   if(!OrderCheck(request,check))
     {
      string detail="ORDER_CHECK "+(string)check.retcode+" "+check.comment;
      if(check.retcode==TRADE_RETCODE_MARKET_CLOSED){DTPNativeWait(detail);return false;}
      DTPNativeCheck("fixture_order_check_"+detail,false);DTPNativeSummary();return false;
     }
   int i=ArraySize(g_records);ArrayResize(g_records,i+1);ZeroMemory(g_records[i]);
   g_records[i].setup=s;PrepareDayPartial(i);g_records[i].pending=true;g_records[i].initial_risk_money=MathAbs(loss);
   bool sent=OrderSend(request,result);g_records[i].entry_order_ticket=result.order;
   if(!sent || !AcceptedDeal(result.retcode))
     {
      g_records[i].pending=false;ArrayResize(g_records,i);
      string detail="ORDER_SEND "+(string)result.retcode+" "+result.comment;
      if(result.retcode==TRADE_RETCODE_MARKET_CLOSED){DTPNativeWait(detail);return false;}
      DTPNativeCheck("fixture_order_send_"+detail,false);DTPNativeSummary();return false;
     }
   qa_dtp_record=i;qa_dtp_initial_volume=volume;qa_dtp_half_rejected=false;qa_dtp_sl_rejected=false;qa_dtp_close_rejected=false;
   qa_dtp_readiness_reason="";return true;
  }
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER) || !InpEnableTesterOrders || !InpScaleOut)return INIT_FAILED;
   int initialized=W33PartialBaseInit();if(initialized!=INIT_SUCCEEDED)return initialized;
   qa_dtp_file=FileOpen(g_tag+"_native_tests.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,';',CP_UTF8);
   DTPNativeCheck("native_report_file",qa_dtp_file!=INVALID_HANDLE);
   DTPNativeCheck("pure_policy_checks",W33RunDayTradePartialPolicyTests(g_tag)==0);
   DTPNativeCheck("production_default_half_trigger",MathAbs(InpPartialAtR-1)<1e-9);
   DTPNativeCheck("production_defaults_24h",MathAbs(InpMaxHoldHours-24)<1e-9);
   DTPNativeCheck("production_default_stages",MathAbs(InpStepStartR-1.5)<1e-9 && MathAbs(InpStepSizeR-0.5)<1e-9 && MathAbs(InpStepLagR-0.5)<1e-9);
   Print("DAYPARTIAL_QA_FIXTURES: force half trigger to current executable quote; synthetic MFE1.5R/temporarylag2.0R for valid native SL; age clock24h. Not strategy/performance or full-hold evidence.");
   return INIT_SUCCEEDED;
  }
void OnTick()
  {
   if(qa_dtp_done)return;if(qa_dtp_started==0)qa_dtp_started=TimeCurrent();
   if(TimeCurrent()-qa_dtp_started>600){DTPNativeCheck("watchdog_completed_both_sides",false);DTPNativeSummary();return;}
   g_tick_order++;DayTradeReconcile();ReconcileDayPartials();
   if(qa_dtp_phase==0){if(DTPNativeOpen(qa_dtp_case==0?1:-1))qa_dtp_phase=1;return;}
   int i=qa_dtp_record;if(i<0)return;ulong ticket;string suffix="_"+(string)qa_dtp_case;
   if(qa_dtp_phase==1)
     {
      if(!OwnedPosition(i,ticket) || !DayTradeEnsureState(i) || !DayPartialEnsure(i))return;
      DTPNativeCheck("native_tp_zero"+suffix,MathAbs(PositionGetDouble(POSITION_TP))<1e-9);
      DTPNativeCheck("actual_fill_deadline"+suffix,W33DayTradeDeadlineMSC(g_records[i].day,g_day_config)==g_records[i].day_first_fill_msc+86400000);
      DTPNativeCheck("half_target_exact"+suffix,MathAbs(g_records[i].scale.target_close_volume-g_records[i].filled_volume*0.5)<1e-8);
      qa_dtp_risk=g_records[i].initial_risk_money;
      MqlTick tick;if(!SymbolInfoTick(_Symbol,tick))return;
      g_records[i].half.trigger_price=g_records[i].setup.direction>0?tick.bid:tick.ask;
      DayTradeEvent(i,"QA_CANNED_HALF_TRIGGER","test-only trigger at current executable quote; native half fill routing, not 1R performance evidence");
      qa_dtp_phase=2;
     }
   if(qa_dtp_phase==2)
     {
      // Keep only this declared trigger fixture executable during rejection retries.
      // Production freezes the +1R price; the pure policy suite tests that boundary.
      MqlTick fixture;if(SymbolInfoTick(_Symbol,fixture))g_records[i].half.trigger_price=g_records[i].setup.direction>0?fixture.bid:fixture.ask;
      ManageDayPartials();ReconcileDayPartials();
      if(g_records[i].scale.request_pending || g_records[i].scale.target_close_volume<=0 ||
         g_records[i].scale.confirmed_closed_volume+1e-8<g_records[i].scale.target_close_volume)return;
      if(!OwnedPosition(i,ticket) || !ScaleOutLedgerMatchesPosition(i))return;
      DTPNativeCheck("half_rejection_retry"+suffix,qa_dtp_half_rejected);
      DTPNativeCheck("native_half_remaining"+suffix,MathAbs(PositionGetDouble(POSITION_VOLUME)-qa_dtp_initial_volume*0.5)<1e-8);
      DTPNativeCheck("half_no_initial_sl_move"+suffix,MathAbs(PositionGetDouble(POSITION_SL)-g_records[i].initial_sl_price)<=_Point*0.5);
      DTPNativeCheck("half_original_monetary_r_retained"+suffix,MathAbs(qa_dtp_risk-g_records[i].initial_risk_money)<1e-8);
      double before=g_records[i].scale.confirmed_closed_volume;ManageDayPartials();
      DTPNativeCheck("half_completion_idempotent"+suffix,!g_records[i].scale.request_pending && MathAbs(before-g_records[i].scale.confirmed_closed_volume)<1e-8);
      g_day_config.lag_r=2.0;
      W33ObserveDayTradeQuote(g_records[i].day,g_day_config,g_records[i].day.entry+g_records[i].day.direction*1.5*g_records[i].day.risk_price);
      qa_dtp_expected_sl=PriceRound(g_records[i].day.entry-g_records[i].day.direction*0.5*g_records[i].day.risk_price,g_records[i].day.direction);
      DayTradeEvent(i,"QA_CANNED_STAGE","test-only MFE1.5R and temporarylag2.0R for valid native SL; pure tests cover productionlag0.5R");qa_dtp_phase=3;
     }
   if(qa_dtp_phase==3)
     {
      ManageDayTradeStops();DayTradeReconcile();if(!OwnedPosition(i,ticket))return;
      if(MathAbs(PositionGetDouble(POSITION_SL)-qa_dtp_expected_sl)>_Point*0.5 || g_records[i].day_sl_pending)return;
      DTPNativeCheck("sl_rejection_retry"+suffix,qa_dtp_sl_rejected);
      DTPNativeCheck("native_sl_confirmed"+suffix,MathAbs(g_records[i].setup.sl_price-qa_dtp_expected_sl)<=_Point*0.5);
      DTPNativeCheck("step_original_monetary_r_retained"+suffix,MathAbs(qa_dtp_risk-g_records[i].initial_risk_money)<1e-8);
      g_day_config.lag_r=0.5;g_records[i].day_first_fill_msc-=86400001;
      DayTradeEvent(i,"QA_AGED_CLOCK","test-only first fill minus24h+1ms; native timeout close routing, not real holding duration");
      g_records[i].opposite.request_pending=true;ManageDayTradeTimeExits();
      DTPNativeCheck("opposite_close_lock"+suffix,!g_records[i].day_close_pending);g_records[i].opposite.request_pending=false;
      g_records[i].scale.request_pending=true;ManageDayTradeTimeExits();
      DTPNativeCheck("half_close_lock"+suffix,!g_records[i].day_close_pending);g_records[i].scale.request_pending=false;
      g_records[i].day_sl_pending=true;g_records[i].day_sl_target=g_records[i].day.entry+g_records[i].day.direction*40.0;
      DayTradeEvent(i,"QA_STALE_SL_PENDING","test-only unobserved SL request; deadline may still close");qa_dtp_phase=4;
     }
   if(qa_dtp_phase==4)
     {
      ManageDayTradeTimeExits();if(g_records[i].setup.entry_status!="CLOSED")return;
      DTPNativeCheck("deadline_rejection_retry"+suffix,qa_dtp_close_rejected);
      DTPNativeCheck("deadline_reason"+suffix,g_records[i].setup.exit_reason=="TIME_LIMIT_24H");
      DTPNativeCheck("full_volume_conserved"+suffix,MathAbs(g_records[i].filled_volume-g_records[i].exit_volume)<1e-8);
      DTPNativeCheck("half_confirmed_volume_conserved"+suffix,MathAbs(g_records[i].scale.confirmed_closed_volume-qa_dtp_initial_volume*0.5)<1e-8);
      DTPNativeCheck("no_pending_after_final_exit"+suffix,!g_records[i].day_close_pending && !g_records[i].day_sl_pending && !g_records[i].scale.request_pending);
      qa_dtp_case++;qa_dtp_phase=0;if(qa_dtp_case>=2)DTPNativeSummary();
     }
  }
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {W33PartialBaseTransaction(trans,request,result);}
void OnDeinit(const int reason)
  {
   if(!qa_dtp_done && qa_dtp_file!=INVALID_HANDLE){DTPNativeCheck("completed_before_tester_end",false);FileWrite(qa_dtp_file,"SUMMARY","FAIL",qa_dtp_checks,qa_dtp_failures);}
   W33PartialBaseDeinit(reason);if(qa_dtp_file!=INVALID_HANDLE)FileClose(qa_dtp_file);
  }
