// Bounded native execution QA. Includes the production EA unchanged, with only
// callback names redirected. No historical entry-performance claim is made.
bool qa_reject_close_once=false,qa_reject_be_once=false,qa_rejected_close=false,qa_rejected_be=false,qa_placed_be_unobserved=false;
datetime qa_placed_be_at=0;
bool qa_override_be_quote=false,qa_retreat_pending_checked=false;
double qa_override_entry=0;
int qa_override_direction=1;
bool QATick(const string symbol,MqlTick &tick)
  {
   bool ok=SymbolInfoTick(symbol,tick);if(ok && qa_override_be_quote){tick.bid=qa_override_entry-(qa_override_direction>0?0.2:0.0);tick.ask=qa_override_entry+(qa_override_direction>0?0.0:0.2);}return ok;
  }
bool QASend(const MqlTradeRequest &request,MqlTradeResult &result)
  {
   // Two controlled request failures exercise the actual manager retry paths.
   // Accepted requests still go to native MT5 OrderSend and native history.
   if(request.position>0 && PositionSelectByTicket(request.position))
     {
      if(qa_reject_close_once && !qa_rejected_close && request.action==TRADE_ACTION_DEAL && request.volume<PositionGetDouble(POSITION_VOLUME)-1e-8)
        {qa_rejected_close=true;ZeroMemory(result);result.retcode=TRADE_RETCODE_REQUOTE;result.comment="QA_INJECTED_REQUOTE_NO_DEAL";return false;}
      if(qa_reject_be_once && !qa_rejected_be && request.action==TRADE_ACTION_SLTP)
        {qa_rejected_be=true;ZeroMemory(result);result.retcode=TRADE_RETCODE_INVALID_STOPS;result.comment="QA_INJECTED_BE_STOPS_NO_MODIFICATION";return false;}
      if(qa_reject_be_once && qa_rejected_be && !qa_placed_be_unobserved && request.action==TRADE_ACTION_SLTP)
        {qa_placed_be_unobserved=true;qa_placed_be_at=TimeCurrent();ZeroMemory(result);result.retcode=TRADE_RETCODE_PLACED;result.request_id=987654321;result.comment="QA_ACCEPTED_BE_NOT_YET_OBSERVED";return true;}
     }
   MqlTradeRequest native_request=request;return OrderSend(native_request,result);
  }
#define OrderSend QASend
#define SymbolInfoTick QATick
#define OnInit W33BaseOnInit
#define OnTick W33BaseOnTick
#define OnDeinit W33BaseOnDeinit
#define OnTradeTransaction W33BaseOnTradeTransaction
#define OnChartEvent W33BaseOnChartEvent
#include "../Wave33ChopDiagnostic.mq5"
#undef OnInit
#undef OnTick
#undef OnDeinit
#undef OnTradeTransaction
#undef OnChartEvent
#undef OrderSend
#undef SymbolInfoTick

input int InpQADirection=1;
input bool InpQAInjectErrors=false;
input bool InpQAW1First=false;
input bool InpQAExpectSingle=false;
int qa_file=INVALID_HANDLE,qa_checks=0,qa_failures=0,qa_phase=0,qa_record=-1;
bool qa_done=false,qa_duplicate_checked=false,qa_partial_checked=false,qa_be_checked=false;
datetime qa_started=0,qa_phase_started=0;
double qa_frozen_risk=0,qa_initial_volume=0,qa_before_cash=0;
ulong qa_first_exit_deal=0;
void QA(const string name,const bool ok,const string detail="")
  {qa_checks++;if(!ok)qa_failures++;Print("SCALEOUT_QA ",name," ",ok?"PASS":"FAIL"," ",detail);FileWrite(qa_file,name,ok?"PASS":"FAIL",detail);FileFlush(qa_file);}
bool QAEq(const double a,const double b,const double eps=1e-8){return MathAbs(a-b)<=eps;}
void QASummary()
  {if(qa_done)return;qa_done=true;FileWrite(qa_file,"SUMMARY",qa_failures==0?"PASS":"FAIL",IntegerToString(qa_checks)+" checks; "+IntegerToString(qa_failures)+" failures");FileFlush(qa_file);}
void QABar(MqlRates &b,const ENUM_TIMEFRAMES tf,const int i,const double v,const int d)
  {ZeroMemory(b);double p=d>0?v:220-v;b.time=D'2020.01.01'+i*PeriodSeconds(tf);b.open=p-0.1*d;b.close=p;b.high=p+0.3;b.low=p-0.3;b.tick_volume=100;b.spread=10;}
bool QASignalFixture(const int d,W33Event &signal)
  {
   g_engine.Configure(g_upper,g_lower,2,2,0.382,0.618,96,false,true);g_engine.SetPoint(0.01);g_engine.SetLifecyclePolicy(true);g_engine.SetDeepFibClosePolicy(false);g_engine.SetConnectedPairPolicy(false);g_engine.SetTriggerMode(W33_PIVOT_BREAK);g_engine.Reset("SCALEOUT_NATIVE");
   double u[]={110,112,115,112,108,105,108,110,112,109,104,100,104,107,110,114,117,120,118,116};
   for(int i=0;i<ArraySize(u);i++){MqlRates b;QABar(b,g_upper,i,u[i],d);g_engine.Feed(g_upper,b,b.time+PeriodSeconds(g_upper));}
   double l[]={116,114,110,111,113,115,113,112,113,116};int r=PeriodSeconds(g_upper)/PeriodSeconds(g_lower);
   for(int i=0;i<ArraySize(l);i++){MqlRates b;QABar(b,g_lower,20*r+i,l[i],d);g_engine.Feed(g_lower,b,b.time+PeriodSeconds(g_lower));}
   W33Event events[];g_engine.Drain(events);int count=0;for(int i=0;i<ArraySize(events);i++)if(events[i].event_type=="SIGNAL"){signal=events[i];count++;}return count==1;
  }
bool QAStartTrade(const int d)
  {
   W33Event signal;bool fixture=QASignalFixture(d,signal);QA("actual_engine_signal_fixture",fixture);if(!fixture)return false;
   MqlTick t;SymbolInfoTick(_Symbol,t);double quote=d>0?t.ask:t.bid;
   W33Setup s=signal.setup;s.symbol=_Symbol;s.direction=d;s.wave1_start_price=quote-d*8;
   double margin=MathMax(MathMax(t.ask-t.bid,InpTPWave1BufferPoints*_Point),SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE));
   s.wave1_peak_price=quote+d*(InpQAW1First?margin+0.2:3.0);
   s.wave1_peak_fixed=true;s.wave2_extreme_price=quote-d*10.0;s.signal_at=TimeCurrent();s.signal_known_at=TimeCurrent();
   signal.at=TimeCurrent();signal.setup=s;HandleSignal(signal);qa_record=RecordIndex(s.setup_id);
   QA("actual_handle_signal_record",qa_record>=0);if(qa_record<0)return false;
   QA("actual_order_submitted",g_records[qa_record].setup.order_sent_at>0 && g_records[qa_record].pending,g_records[qa_record].setup.entry_status+" "+g_records[qa_record].setup.skip_reason);
   return g_records[qa_record].setup.order_sent_at>0;
  }

void QAPure()
  {
   for(int d=-1;d<=1;d+=2)
     {
      string k=W33DirectionName(d);double en=100,base=en+d*2,w1=en+d*4;W33ScaleOutPlan p;
      p=W33BuildScaleOutPlan(true,d,en,base,w1,0,0.01);QA("base_first_"+k,p.valid && p.enabled && p.first_tp==base && p.final_tp==w1 && p.first_kind=="BASE_RR");
      p=W33BuildScaleOutPlan(true,d,en,w1,base,0,0.01);QA("w1_first_"+k,p.valid && p.enabled && p.first_tp==base && p.final_tp==w1 && p.first_kind=="WAVE1_INSIDE");
      p=W33BuildScaleOutPlan(false,d,en,base,w1,0,0.01);QA("off_preserves_base_exact_"+k,p.valid && !p.enabled && p.final_tp==base && !p.requested);
      p=W33BuildScaleOutPlan(true,d,en,base,base,0,0.01);QA("equal_full_close_"+k,p.valid && p.collapsed && !p.enabled && p.first_tp==base && p.final_tp==base);
      p=W33BuildScaleOutPlan(true,d,en,base,base+d*0.0049,0,0.01);QA("subtick_pair_collapse_"+k,p.valid && p.collapsed && !p.enabled && p.final_tp==base);
      p=W33BuildScaleOutPlan(true,d,en,base,w1,en+d*3,0.01);QA("cap_between_targets_"+k,p.valid && p.enabled && p.first_tp==base && p.final_tp==en+d*3);
      p=W33BuildScaleOutPlan(true,d,en,base,w1,en+d*1,0.01);QA("cap_before_first_single_"+k,p.valid && p.collapsed && !p.enabled && p.first_tp==en+d && p.final_tp==p.first_tp);
      p=W33BuildScaleOutPlan(true,d,en,base,w1,en+d*2,0.01);QA("cap_at_first_single_"+k,p.valid && p.collapsed && !p.enabled && p.final_tp==base);
      p=W33BuildScaleOutPlan(true,d,en,base,0,0,0.01);QA("missing_w1_single_"+k,p.valid && p.collapsed && !p.enabled && p.final_tp==base);
      p=W33BuildScaleOutPlan(true,d,en,base,en-d,0,0.01);QA("unprofitable_w1_single_"+k,p.valid && p.collapsed && !p.enabled && p.final_tp==base);
      p=W33BuildScaleOutPlan(true,d,en,en-d,w1,0,0.01);QA("wrong_base_invalid_"+k,!p.valid && !p.enabled);
      p=W33BuildScaleOutPlan(true,d,en,base,w1,en-d,0.01);QA("wrong_cap_invalid_"+k,!p.valid && !p.enabled);
      // The wrong spread side alone must not trigger. At the executable side
      // equal is a valid touch; a gap beyond both levels is still one touch.
      QA("spread_wrong_side_no_touch_"+k,!W33ScaleOutPriceReached(d,d>0?101.9:97.8,d>0?102.2:98.1,base));
      QA("executable_equal_touch_"+k,W33ScaleOutPriceReached(d,d>0?102:97.8,d>0?102.2:98,base));
      QA("gap_beyond_far_touch_"+k,W33ScaleOutPriceReached(d,d>0?105:94.8,d>0?105.2:95,base));
      QA("crossed_quote_invalid_"+k,!W33ScaleOutPriceReached(d,102,101,base));
      double bid=d>0?101:98.8,ask=d>0?101.2:99;
      W33ScaleOutBEPlan b=W33BuildScaleOutBEPlan(d,en,en-d*2,bid,ask,0.01,0.01,2,20,10);
      QA("be_ready_"+k,b.valid && b.can_modify && b.target_sl==en && !b.already_protected);
      b=W33BuildScaleOutBEPlan(d,en,en+d*0.1,bid,ask,0.01,0.01,2,20,10);QA("be_never_loosen_"+k,b.valid && !b.can_modify && b.already_protected);
      bid=d>0?100.2:99.6;ask=d>0?100.4:99.8;
      b=W33BuildScaleOutBEPlan(d,en,en-d*2,bid,ask,0.01,0.01,2,20,0);QA("stops_equal_allowed_"+k,b.valid && b.can_modify);
      b=W33BuildScaleOutBEPlan(d,en,en-d*2,bid,ask,0.01,0.01,2,0,20);QA("freeze_equal_wait_"+k,b.valid && !b.can_modify && b.reason=="SCALEOUT_BE_FREEZE_LEVEL");
      bid=d>0?100.1:99.7;ask=d>0?100.3:99.9;
      b=W33BuildScaleOutBEPlan(d,en,en-d*2,bid,ask,0.01,0.01,2,20,0);QA("stops_not_safe_wait_"+k,b.valid && !b.can_modify);
      bid=d>0?99.8:100;ask=d>0?100:100.2;
      b=W33BuildScaleOutBEPlan(d,en,en-d*2,bid,ask,0.01,0.01,2,0,0);QA("spread_retrace_no_illegal_be_"+k,b.valid && !b.can_modify);
      b=W33BuildScaleOutBEPlan(d,100.005,en-d*2,d>0?101:98.8,d>0?101.2:99,0.01,0.01,2,0,0);QA("weighted_fill_favorable_tick_"+k,b.valid && b.can_modify && b.favorable_rounding && QAEq(b.target_sl,d>0?100.01:100));
      for(int st=0;st<2;st++)for(int gap=1;gap<=5;gap++)
        {double step=st==0?0.01:0.25;for(int units=1;units<=20;units++){double v=units*step;W33ScaleOutVolumePlan vp=W33BuildScaleOutVolumePlan(v,v,gap*step,step,0);string z=k+"_"+(string)st+"_"+(string)gap+"_"+(string)units;bool enough=(units/2)>=gap && units-units/2>=gap;QA("volume_grid_no_upsize_"+z,vp.valid && vp.split_allowed==enough && QAEq(vp.target_close_volume,MathFloor(units*0.5)*step) && vp.target_close_volume<=v*0.5+1e-10 && (!vp.split_allowed || (vp.remaining_to_close>=gap*step-1e-10 && vp.remainder>=gap*step-1e-10)));}}
     }
   W33ScaleOutVolumePlan v=W33BuildScaleOutVolumePlan(0.1,0.08,0.01,0.01,0.02);QA("partial_request_retries_only_residual",v.valid && v.split_allowed && !v.completed && QAEq(v.target_close_volume,0.05) && QAEq(v.remaining_to_close,0.03) && QAEq(v.remainder,0.05));
   v=W33BuildScaleOutVolumePlan(0.1,0.05,0.01,0.01,0.05);QA("confirmed_half_not_repeated",v.completed && v.split_allowed && QAEq(v.remaining_to_close,0));
   v=W33BuildScaleOutVolumePlan(0.03,0.03,0.01,0.01,0);QA("odd_lot_floor_half",v.valid && v.split_allowed && QAEq(v.target_close_volume,0.01) && QAEq(v.remainder,0.02));
   v=W33BuildScaleOutVolumePlan(0.01,0.01,0.01,0.01,0);QA("minimum_lot_no_risk_increase",v.valid && v.fallback_to_single && !v.split_allowed && QAEq(v.remainder,0.01));
   v=W33BuildScaleOutVolumePlan(0.1,0.1,0.01,0.01,0,false);QA("unsupported_partial_single_fallback",v.valid && v.fallback_to_single && !v.split_allowed);
   v=W33BuildScaleOutVolumePlan(0.1,0.12,0.01,0.01,0);QA("foreign_volume_not_merged",!v.valid && v.fallback_to_single);
   v=W33BuildScaleOutVolumePlan(0.1,0.08,0.01,0.01,0.025);QA("off_step_confirmation_invalid",!v.valid);
   v=W33BuildScaleOutVolumePlan(0.1,0.09,0.03,0.01,0.04);QA("unfillable_partial_residual_fallback",v.valid && v.fallback_to_single && !v.split_allowed);
   double nan=MathArcsin(2.0);W33ScaleOutPlan p=W33BuildScaleOutPlan(true,0,100,102,104,0,0.01);QA("invalid_direction",!p.valid);
   p=W33BuildScaleOutPlan(true,1,100,102,104,0,0);QA("zero_tick_invalid",!p.valid);p=W33BuildScaleOutPlan(true,1,nan,102,104,0,0.01);QA("nan_entry_invalid",!p.valid);
   W33ScaleOutBEPlan b=W33BuildScaleOutBEPlan(1,100,98,101,101.2,0.01,0.015,2,0,0);QA("unrepresentable_tick_precision",!b.valid);
   W33ScaleOutState state;ZeroMemory(state);state.request_pending=true;state.break_even_pending=true;state.confirmed_closed_volume=0.4;state.fallback_reason="old";W33ResetScaleOutState(state);QA("reset_clears_execution_latches",!state.request_pending && !state.break_even_pending && state.confirmed_closed_volume==0 && state.fallback_reason=="");
  }

int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER) || !InpEnableTesterOrders || (InpQADirection!=1 && InpQADirection!=-1))return INIT_PARAMETERS_INCORRECT;
   int r=W33BaseOnInit();if(r!=INIT_SUCCEEDED)return r;
   qa_file=FileOpen(InpRunTag+"_assertions.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,';',CP_UTF8);if(qa_file==INVALID_HANDLE)return INIT_FAILED;
   FileWrite(qa_file,"test","result","detail");return INIT_SUCCEEDED;
  }
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   W33BaseOnTradeTransaction(trans,request,result);
   if(qa_record<0 || trans.type!=TRADE_TRANSACTION_DEAL_ADD || !HistoryDealSelect(trans.deal) || HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=_Symbol || (ulong)HistoryDealGetInteger(trans.deal,DEAL_MAGIC)!=InpMagic)return;
   double cash=g_records[qa_record].net_cash,closed=g_records[qa_record].exit_volume,filled=g_records[qa_record].filled_volume;
   // MT5 callback delivery order is not guaranteed. Replay an already processed
   // history-backed DEAL_ADD: financial accounting and half sizing stay fixed.
   W33BaseOnTradeTransaction(trans,request,result);
   QA("duplicate_native_deal_ignored_"+(string)trans.deal,QAEq(cash,g_records[qa_record].net_cash) && QAEq(closed,g_records[qa_record].exit_volume) && QAEq(filled,g_records[qa_record].filled_volume));
   if(HistoryDealGetInteger(trans.deal,DEAL_ENTRY)==DEAL_ENTRY_OUT && qa_first_exit_deal==0)qa_first_exit_deal=trans.deal;
  }
void QAFinalAccounting()
  {
   W33Execution r=g_records[qa_record];double cash=0,volume=0;int exits=0,entries=0;
   HistorySelect(qa_started-1,TimeCurrent()+1);
   for(int i=0;i<HistoryDealsTotal();i++){ulong id=HistoryDealGetTicket(i);if((ulong)HistoryDealGetInteger(id,DEAL_POSITION_ID)!=r.position_id)continue;cash+=HistoryDealGetDouble(id,DEAL_PROFIT)+HistoryDealGetDouble(id,DEAL_COMMISSION)+HistoryDealGetDouble(id,DEAL_FEE)+HistoryDealGetDouble(id,DEAL_SWAP);if(HistoryDealGetInteger(id,DEAL_ENTRY)==DEAL_ENTRY_OUT){exits++;volume+=HistoryDealGetDouble(id,DEAL_VOLUME);}else if(HistoryDealGetInteger(id,DEAL_ENTRY)==DEAL_ENTRY_IN)entries++;}
   QA("native_history_net_cash_matches_record",QAEq(cash,r.net_cash,1e-6),DoubleToString(cash,8)+" / "+DoubleToString(r.net_cash,8));
   QA("native_history_volume_matches_entry",QAEq(volume,r.filled_volume) && QAEq(volume,r.exit_volume));
   QA("realized_R_uses_original_total_risk",qa_frozen_risk>0 && QAEq(r.initial_risk_money,qa_frozen_risk,1e-6) && QAEq(r.setup.realized_r,cash/qa_frozen_risk,1e-8),DoubleToString(r.setup.realized_r,10));
   QA("setup_closed_once_not_per_deal_winrate",r.setup.entry_status=="CLOSED" && entries>=1 && exits==((InpScaleOut && !InpQAExpectSingle)?2:1),"entry deals="+(string)entries+" exit deals="+(string)exits);
   QA("flat_position",!PositionSelect(_Symbol));
   if(InpQAInjectErrors){QA("injected_partial_requote_retried",qa_rejected_close);QA("injected_BE_rejection_retried",qa_rejected_be);QA("accepted_BE_not_visible_retried_after_timeout",qa_placed_be_unobserved && TimeCurrent()>=qa_placed_be_at+5 && r.scale.be_attempts>=3);QA("accepted_BE_timeout_under_quote_retreat_covered",qa_retreat_pending_checked);}
   QASummary();TesterStop();
  }
void OnTick()
  {
   if(qa_done)return;g_tick_order++;
   MqlDateTime clock;TimeToStruct(TimeCurrent(),clock);if(qa_started==0 && clock.hour<2)return; // Source sessions open after the first quoted tick.
   if(qa_started==0)
     {qa_started=TimeCurrent();qa_reject_close_once=InpQAInjectErrors;qa_reject_be_once=InpQAInjectErrors;QA("account_margin_mode_reported",true,EnumToString((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)));QA("tester_orders_only",TesterExecutionContext());QAPure();if(!QAStartTrade(InpQADirection)){QASummary();TesterStop();return;}qa_phase_started=TimeCurrent();qa_phase=1;return;}
   if(qa_record<0)return;
   if(qa_phase==1 && g_records[qa_record].filled_volume>0)
     {
      qa_frozen_risk=g_records[qa_record].initial_risk_money;qa_initial_volume=g_records[qa_record].filled_volume;
      QA("native_fill_confirmed",g_records[qa_record].setup.fill_at>0 && !g_records[qa_record].pending && qa_frozen_risk>0);
      QA("native_no_BE_before_partial",!g_records[qa_record].scale.break_even_done && g_records[qa_record].exit_volume==0);
      if(InpScaleOut){QA("native_two_targets_distinct",g_records[qa_record].scale_plan.enabled && g_records[qa_record].setup.direction*(g_records[qa_record].scale_plan.final_tp-g_records[qa_record].scale_plan.first_tp)>0);QA("native_first_target_kind",g_records[qa_record].scale_plan.first_kind==(InpQAW1First?"WAVE1_INSIDE":"BASE_RR"));}
      qa_phase=2;qa_phase_started=TimeCurrent();
     }
   if(InpQAInjectErrors && qa_placed_be_unobserved && !qa_retreat_pending_checked && TimeCurrent()>=qa_placed_be_at+5 && g_records[qa_record].scale_be_request_pending)
     {
      ulong ticket=0;bool own=OwnedPosition(qa_record,ticket);double oldSL=own?PositionGetDouble(POSITION_SL):0;
      qa_override_entry=g_records[qa_record].setup.entry_price;qa_override_direction=g_records[qa_record].setup.direction;qa_override_be_quote=true;TryScaleOutBE(qa_record);qa_override_be_quote=false;
      qa_retreat_pending_checked=true;QA("BE_pending_timeout_clears_even_quote_retraced",own && !g_records[qa_record].scale_be_request_pending && !g_records[qa_record].scale.break_even_done && QAEq(PositionGetDouble(POSITION_SL),oldSL));
     }
   ManageOppositeExits();ManageScaleOuts();
   if(qa_phase==2 && InpScaleOut && !InpQAExpectSingle && !qa_partial_checked && g_records[qa_record].exit_volume>0 && g_records[qa_record].exit_volume<qa_initial_volume)
     {
      qa_partial_checked=true;W33Execution r=g_records[qa_record];double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),target=MathFloor(qa_initial_volume/step*0.5+1e-8)*step;
      QA("native_actual_half_closed",QAEq(r.exit_volume,target),DoubleToString(r.exit_volume,8)+" / "+DoubleToString(target,8));
      QA("native_half_confirmed_not_touch",r.scale.confirmed_closed_volume>0 && r.scale.first_confirmed_at>0 && qa_first_exit_deal>0);
      QA("native_half_does_not_change_initial_risk",QAEq(r.initial_risk_money,qa_frozen_risk,1e-6));
      ulong ticket=0;bool own=OwnedPosition(qa_record,ticket);double volume=own?PositionGetDouble(POSITION_VOLUME):0;
      QA("native_remaining_half_volume",own && QAEq(volume,qa_initial_volume-target));
      QA("native_far_TP_kept",own && QAEq(PositionGetDouble(POSITION_TP),r.scale_plan.final_tp,_Point*0.5));
     }
   if(qa_phase==2 && InpScaleOut && qa_partial_checked && !qa_be_checked && g_records[qa_record].scale.break_even_done)
     {
      qa_be_checked=true;W33Execution r=g_records[qa_record];ulong ticket=0;bool own=OwnedPosition(qa_record,ticket);double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      QA("native_BE_confirmed_in_position",own && r.setup.direction*(PositionGetDouble(POSITION_SL)-r.setup.entry_price)>=-tick*1e-8 && MathAbs(PositionGetDouble(POSITION_SL)-r.setup.entry_price)<=tick+tick*1e-8);
      QA("native_BE_only_after_half_fill",qa_first_exit_deal>0 && r.scale.confirmed_closed_volume>=r.scale.target_close_volume-1e-8);
      bool armed=W33ArmOppositeExit(g_records[qa_record].opposite,r.setup.direction,r.setup.fill_at,r.fill_order_key,"QA_OPPOSITE_AFTER_SCALEOUT",-r.setup.direction,TimeCurrent(),++g_knowledge_order);
      QA("native_opposite_armed_on_residual",armed);g_records[qa_record].setup.opposite_exit_armed=true;g_records[qa_record].setup.opposite_setup_id="QA_OPPOSITE_AFTER_SCALEOUT";
      qa_phase=3;qa_phase_started=TimeCurrent();
     }
   if(g_records[qa_record].setup.entry_status=="CLOSED")
     {
      if(InpQAExpectSingle){QA("native_minlot_fallback_one_close",g_records[qa_record].scale.single_fallback && !qa_partial_checked && !g_records[qa_record].scale.break_even_done && QAEq(qa_initial_volume,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN)));QA("native_minlot_fallback_closed_at_near_target",g_records[qa_record].setup.exit_reason=="DEAL_REASON_TP" || g_records[qa_record].setup.exit_reason=="SCALEOUT_SINGLE_TP1",g_records[qa_record].setup.exit_reason);}
      else if(InpScaleOut){QA("native_partial_observed_before_close",qa_partial_checked);QA("native_BE_observed_before_close",qa_be_checked);QA("native_opposite_full_residual_priority",g_records[qa_record].setup.exit_reason=="OPPOSITE_WAVE1_PROFIT",g_records[qa_record].setup.exit_reason);}
      else QA("OFF_native_single_close_no_half",!g_records[qa_record].scale.planned && !qa_partial_checked);
      QAFinalAccounting();return;
     }
   if(TimeCurrent()-qa_started>6*3600){QA("native_bounded_fixture_timeout",false,"phase="+(string)qa_phase+" partial="+(string)qa_partial_checked+" BE="+(string)qa_be_checked);QASummary();TesterStop();}
  }
void OnDeinit(const int reason)
  {if(!qa_done){QA("completed_before_test_end",false,IntegerToString(qa_phase));QASummary();}W33BaseOnDeinit(reason);if(qa_file!=INVALID_HANDLE){FileClose(qa_file);qa_file=INVALID_HANDLE;}}
