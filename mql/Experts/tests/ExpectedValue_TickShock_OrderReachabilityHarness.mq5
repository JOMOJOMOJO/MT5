#property strict
#property version "3.00"

#include "../../Include/TickShock/TickShockOrderLifecycle.mqh"

input long InpMagicNumber=26082191;
input double InpVolume=0.01;
input int InpWaitTicksBeforeTimeClose=5;
input int InpBarrierTimeoutTicks=5000;
input int InpBarrierDistanceTicks=2;
input int InpFarBarrierTicks=1000;
input int InpEarliestServerHour=1;
input string InpRunId="order_harness_v3_observation_truth";
input string InpLogFolder="tick_shock_research";

enum ENUM_HARNESS_EXIT_PLAN
  {
   H_EXIT_SERVER_SL=0,
   H_EXIT_SERVER_TP=1,
   H_EXIT_TIME=2
  };

enum ENUM_HARNESS_STATE
  {
   H_SEND_ENTRY=0,
   H_WAIT_ENTRY_RESOLUTION,
   H_WAIT_PLANNED_EXIT,
   H_WAIT_EXIT_RESOLUTION,
   H_DONE,
   H_FAILED
  };

struct HarnessFillTracker
  {
   double requested_volume;
   double filled_volume;
   double weighted_value;
   bool residual_closed;
   int deal_count;
  };

ENUM_HARNESS_STATE g_state=H_SEND_ENTRY;
int g_file=INVALID_HANDLE;
int g_cycle=0;
int g_wait_ticks=0;
int g_direction=0;
ENUM_HARNESS_EXIT_PLAN g_plan=H_EXIT_SERVER_SL;
int g_passed=0;
int g_failed=0;
int g_skipped=0;
int g_unit_passed=0;
long g_signal_msc=0;
long g_request_msc=0;
long g_first_fill_msc=0;
long g_close_msc=0;
double g_requested_price=0.0;
double g_exit_volume=0.0;
double g_exit_value=0.0;
double g_commission_total=0.0;
double g_fee_total=0.0;
double g_swap_total=0.0;
ulong g_entry_order=0;
ulong g_entry_deal=0;
ulong g_exit_deal=0;
uint g_order_retcode=0;
uint g_order_retcode_external=0;
uint g_request_id=0;
ENUM_DEAL_REASON g_exit_reason=DEAL_REASON_CLIENT;
bool g_recovery_observed=false;
bool g_cleanup_after_skip=false;
bool g_partial_fill_observed=false;
bool g_direction_time_complete[2];
bool g_direction_restart_snapshot_complete[2];
int g_observed_deal_count=0;
int g_observed_entry_deal_count=0;
int g_observed_exit_deal_count=0;
ulong g_last_entry_deal_ticket=0;
ulong g_last_entry_order_ticket=0;
ulong g_last_entry_position_ticket=0;
double g_last_entry_deal_volume=0.0;
double g_last_entry_deal_price=0.0;
HarnessFillTracker g_entry_fill;
TickShockOrderFillState g_order_fill_state;

string DirectionName() { return g_direction>0?"LONG":"SHORT"; }

string PlanName()
  {
   if(g_plan==H_EXIT_SERVER_SL) return "SERVER_SL";
   if(g_plan==H_EXIT_SERVER_TP) return "SERVER_TP";
   return "TIME";
  }

string CycleName()
  {
   return DirectionName()+"_"+PlanName();
  }

void WriteRow(const string record_type,const string direction,const string phase,const string result,const string detail)
  {
   if(g_file!=INVALID_HANDLE) FileWrite(g_file,InpRunId,record_type,direction,phase,result,detail);
  }

void Assess(const string name,const string result,const string detail)
  {
   if(result=="PASS") ++g_passed;
   else if(result=="FAIL") ++g_failed;
   else if(result=="SKIP") ++g_skipped;
   else if(result=="UNIT_PASS") ++g_unit_passed;
   WriteRow("TEST","",name,result,detail);
  }

void ResetFillTracker(HarnessFillTracker &tracker,const double requested_volume)
  {
   tracker.requested_volume=requested_volume;
   tracker.filled_volume=0.0;
   tracker.weighted_value=0.0;
   tracker.residual_closed=false;
   tracker.deal_count=0;
  }

void AddFill(HarnessFillTracker &tracker,const double volume,const double price)
  {
   if(volume<=0.0 || price<=0.0) return;
   tracker.filled_volume+=volume;
   tracker.weighted_value+=volume*price;
   ++tracker.deal_count;
  }

double RemainingVolume(const HarnessFillTracker &tracker)
  {
   return MathMax(0.0,tracker.requested_volume-tracker.filled_volume);
  }

bool FillResolved(const HarnessFillTracker &tracker,const double tolerance)
  {
   return RemainingVolume(tracker)<=tolerance || (tracker.filled_volume>0.0 && tracker.residual_closed);
  }

double AverageFill(const HarnessFillTracker &tracker)
  {
   return tracker.filled_volume>0.0?tracker.weighted_value/tracker.filled_volume:0.0;
  }

ENUM_ORDER_TYPE_FILLING FillingMode()
  {
   int filling=(int)SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   if((filling&SYMBOL_FILLING_FOK)==SYMBOL_FILLING_FOK) return ORDER_FILLING_FOK;
   if((filling&SYMBOL_FILLING_IOC)==SYMBOL_FILLING_IOC) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
  }

double HarnessVolume()
  {
   double minimum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maximum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(step<=0.0 || minimum<=0.0) return 0.0;
   double requested=MathMax(minimum,MathMin(maximum,InpVolume));
   return NormalizeDouble(MathFloor((requested+1e-12)/step)*step,8);
  }

double RoundDown(const double price)
  {
   double tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   return tick_size>0.0?NormalizeDouble(MathFloor(price/tick_size+1e-10)*tick_size,digits):0.0;
  }

double RoundUp(const double price)
  {
   double tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   return tick_size>0.0?NormalizeDouble(MathCeil(price/tick_size-1e-10)*tick_size,digits):0.0;
  }

void ResetCycle()
  {
   g_direction=g_cycle<3?1:-1;
   g_plan=(ENUM_HARNESS_EXIT_PLAN)(g_cycle%3);
   g_wait_ticks=0;
   g_signal_msc=0;
   g_request_msc=0;
   g_first_fill_msc=0;
   g_close_msc=0;
   g_requested_price=0.0;
   g_exit_volume=0.0;
   g_exit_value=0.0;
   g_commission_total=0.0;
   g_fee_total=0.0;
   g_swap_total=0.0;
   g_entry_order=0;
   g_entry_deal=0;
   g_exit_deal=0;
   g_order_retcode=0;
   g_order_retcode_external=0;
   g_request_id=0;
   g_exit_reason=DEAL_REASON_CLIENT;
   g_recovery_observed=false;
   g_cleanup_after_skip=false;
   g_last_entry_deal_ticket=0;
   g_last_entry_order_ticket=0;
   g_last_entry_position_ticket=0;
   g_last_entry_deal_volume=0.0;
   g_last_entry_deal_price=0.0;
   ResetFillTracker(g_entry_fill,HarnessVolume());
   TSResetOrderFillState(g_order_fill_state,g_entry_fill.requested_volume);
   TSConfigureOrderIdentity(g_order_fill_state,0,0,0,_Symbol,InpMagicNumber,g_direction);
  }

bool BuildProtection(const MqlTick &tick,double &sl,double &tp)
  {
   double tick_size=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   int stops=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double spread=tick.ask-tick.bid;
   double near_distance=MathMax((stops+2)*point,spread+MathMax(2,InpBarrierDistanceTicks)*tick_size);
   double far_distance=MathMax(near_distance*20.0,MathMax(10,InpFarBarrierTicks)*tick_size);
   if(g_direction>0)
     {
      sl=RoundDown(tick.bid-(g_plan==H_EXIT_SERVER_SL?near_distance:far_distance));
      tp=RoundUp(tick.bid+(g_plan==H_EXIT_SERVER_TP?near_distance:far_distance));
     }
   else
     {
      sl=RoundUp(tick.ask+(g_plan==H_EXIT_SERVER_SL?near_distance:far_distance));
      tp=RoundDown(tick.ask-(g_plan==H_EXIT_SERVER_TP?near_distance:far_distance));
     }
   return sl>0.0 && tp>0.0;
  }

bool SendEntry()
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.ask<=tick.bid || tick.bid<=0.0) return false;
   MqlTradeRequest request={};
   MqlTradeResult result={};
   MqlTradeCheckResult check={};
   request.action=TRADE_ACTION_DEAL;
   request.symbol=_Symbol;
   request.magic=InpMagicNumber;
   request.deviation=50;
   request.type_filling=FillingMode();
   request.comment="TSH_"+CycleName();
   request.volume=g_entry_fill.requested_volume;
   request.type=g_direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   request.price=request.type==ORDER_TYPE_BUY?tick.ask:tick.bid;
   if(request.volume<=0.0 || !BuildProtection(tick,request.sl,request.tp)) return false;
   g_signal_msc=(long)tick.time_msc;
   g_request_msc=(long)TimeCurrent()*1000;
   g_requested_price=request.price;
   ResetLastError();
   bool checked=OrderCheck(request,check);
   int check_terminal_error=GetLastError();
   WriteRow("ORDER",DirectionName(),PlanName()+"_ENTRY_CHECK",checked?"PASS":"FAIL",StringFormat("bool=%s;terminal_error=%d;retcode=%u;comment=%s;margin=%.8f;margin_free=%.8f;requested_volume=%.2f;symbol=%s;magic=%I64d;filling_mode=%d;sl=%.8f;tp=%.8f",checked?"true":"false",check_terminal_error,check.retcode,check.comment,check.margin,check.margin_free,request.volume,request.symbol,request.magic,(int)request.type_filling,request.sl,request.tp));
   Assess(CycleName()+"_OrderCheck",checked?"PASS":"FAIL",StringFormat("terminal_error=%d;retcode=%u",check_terminal_error,check.retcode));
   if(!checked) return false;
   ResetLastError();
   bool sent=OrderSend(request,result);
   int send_terminal_error=GetLastError();
   g_order_retcode=result.retcode;
   g_order_retcode_external=result.retcode_external;
   g_request_id=result.request_id;
   g_entry_order=result.order;
   bool accepted=sent && (result.retcode==TRADE_RETCODE_DONE || result.retcode==TRADE_RETCODE_PLACED || result.retcode==TRADE_RETCODE_DONE_PARTIAL);
   if(result.retcode==TRADE_RETCODE_DONE_PARTIAL) g_partial_fill_observed=true;
   WriteRow("ORDER",DirectionName(),PlanName()+"_ENTRY_SEND",accepted?"PASS":"FAIL",StringFormat("bool=%s;terminal_error=%d;retcode=%u;external=%u;order=%I64u;deal=%I64u;request_id=%u;symbol=%s;magic=%I64d;requested_volume=%.2f;filling_mode=%d",sent?"true":"false",send_terminal_error,result.retcode,result.retcode_external,result.order,result.deal,result.request_id,request.symbol,request.magic,g_entry_fill.requested_volume,(int)request.type_filling));
   Assess(CycleName()+"_OrderSend",accepted?"PASS":"FAIL",StringFormat("retcode=%u;order=%I64u;deal=%I64u",result.retcode,result.order,result.deal));
   return accepted;
  }

bool SendTimeOrCleanupClose()
  {
   if(!PositionSelect(_Symbol) || (long)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) return false;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.ask<=tick.bid || tick.bid<=0.0) return false;
   MqlTradeRequest request={};
   MqlTradeResult result={};
   MqlTradeCheckResult check={};
   request.action=TRADE_ACTION_DEAL;
   request.symbol=_Symbol;
   request.position=(ulong)PositionGetInteger(POSITION_TICKET);
   request.magic=InpMagicNumber;
   request.volume=PositionGetDouble(POSITION_VOLUME);
   request.type=g_direction>0?ORDER_TYPE_SELL:ORDER_TYPE_BUY;
   request.price=request.type==ORDER_TYPE_BUY?tick.ask:tick.bid;
   request.deviation=50;
   request.type_filling=FillingMode();
   request.comment=g_cleanup_after_skip?"TSH_CLEANUP":"TSH_TIME_EXIT";
   ResetLastError();
   bool checked=OrderCheck(request,check);
   int check_terminal_error=GetLastError();
   WriteRow("ORDER",DirectionName(),g_cleanup_after_skip?"CLEANUP_CHECK":"TIME_CLOSE_CHECK",checked?"PASS":"FAIL",StringFormat("bool=%s;terminal_error=%d;retcode=%u;comment=%s;margin=%.8f;margin_free=%.8f;volume=%.2f;symbol=%s;magic=%I64d;position=%I64u;filling_mode=%d",checked?"true":"false",check_terminal_error,check.retcode,check.comment,check.margin,check.margin_free,request.volume,request.symbol,request.magic,request.position,(int)request.type_filling));
   if(!g_cleanup_after_skip) Assess(CycleName()+"_TimeClose_OrderCheck",checked?"PASS":"FAIL",StringFormat("retcode=%u",check.retcode));
   if(!checked) return false;
   ResetLastError();
   bool sent=OrderSend(request,result);
   int send_terminal_error=GetLastError();
   bool accepted=sent && (result.retcode==TRADE_RETCODE_DONE || result.retcode==TRADE_RETCODE_PLACED || result.retcode==TRADE_RETCODE_DONE_PARTIAL);
   WriteRow("ORDER",DirectionName(),g_cleanup_after_skip?"CLEANUP_SEND":"TIME_CLOSE_SEND",accepted?"PASS":"FAIL",StringFormat("bool=%s;terminal_error=%d;retcode=%u;external=%u;order=%I64u;deal=%I64u;request_id=%u;symbol=%s;magic=%I64d;volume=%.2f;position=%I64u;filling_mode=%d",sent?"true":"false",send_terminal_error,result.retcode,result.retcode_external,result.order,result.deal,result.request_id,request.symbol,request.magic,request.volume,request.position,(int)request.type_filling));
   if(!g_cleanup_after_skip) Assess(CycleName()+"_TimeClose_OrderSend",accepted?"PASS":"FAIL",StringFormat("retcode=%u",result.retcode));
   return accepted;
  }

bool EntryResidualClosed()
  {
   double tolerance=MathMax(1e-9,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)*0.5);
   if(RemainingVolume(g_entry_fill)<=tolerance) return true;
   if(g_entry_order>0 && OrderSelect(g_entry_order)) return false;
   if(g_entry_order>0 && HistoryOrderSelect(g_entry_order))
     {
      double remaining=HistoryOrderGetDouble(g_entry_order,ORDER_VOLUME_CURRENT);
      ENUM_ORDER_STATE state=(ENUM_ORDER_STATE)HistoryOrderGetInteger(g_entry_order,ORDER_STATE);
      bool terminal=state==ORDER_STATE_FILLED || state==ORDER_STATE_CANCELED || state==ORDER_STATE_REJECTED || state==ORDER_STATE_EXPIRED;
      if(terminal && remaining<=tolerance)
        {
         g_entry_fill.residual_closed=true;
         return true;
        }
     }
   return false;
  }

bool RecoverManagedPosition()
  {
   if(!PositionSelect(_Symbol) || (long)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) return false;
   ulong ticket=(ulong)PositionGetInteger(POSITION_TICKET);
   long opened=(long)PositionGetInteger(POSITION_TIME_MSC);
   double volume=PositionGetDouble(POSITION_VOLUME);
   double price=PositionGetDouble(POSITION_PRICE_OPEN);
   double sl=PositionGetDouble(POSITION_SL);
   double tp=PositionGetDouble(POSITION_TP);
   bool recovered=ticket>0 && opened>0 && volume>0.0 && price>0.0 && sl>0.0 && tp>0.0;
   WriteRow("RECOVERY",DirectionName(),PlanName()+"_POSITION_FIELDS",recovered?"PASS":"SKIP",StringFormat("ticket=%I64u;symbol=%s;magic=%I64d;direction=%d;open_msc=%I64d;volume=%.2f;price=%.8f;sl=%.8f;tp=%.8f",ticket,_Symbol,(long)PositionGetInteger(POSITION_MAGIC),g_direction,opened,volume,price,sl,tp));
   return recovered;
  }

void ObserveSimulatedRestartSnapshot()
  {
   int direction_index=g_direction>0?0:1;
   if(g_direction_restart_snapshot_complete[direction_index] || g_last_entry_deal_ticket==0) return;
   TickShockOrderFillState restored;
   TSRestoreOrderSnapshot(g_order_fill_state,restored);
   double before_volume=restored.filled_volume;
   int before_deals=restored.deal_count;
   int before_duplicates=restored.duplicate_deals;
   bool replayed=TSApplyOrderDeal(restored,g_last_entry_deal_ticket,0,g_last_entry_order_ticket,
                                  g_last_entry_position_ticket,_Symbol,InpMagicNumber,g_direction,
                                  DEAL_ENTRY_IN,g_last_entry_deal_volume,g_last_entry_deal_price);
   bool pass=!replayed && MathAbs(restored.filled_volume-before_volume)<=1e-12 &&
             restored.deal_count==before_deals && restored.duplicate_deals==before_duplicates+1;
   Assess(DirectionName()+"_simulated_restart_snapshot",pass?"PASS":"FAIL",
          StringFormat("deal=%I64u;replayed=%s;filled_before=%.2f;filled_after=%.2f;deals_before=%d;deals_after=%d;duplicates_before=%d;duplicates_after=%d",
                       g_last_entry_deal_ticket,replayed?"true":"false",before_volume,restored.filled_volume,before_deals,restored.deal_count,before_duplicates,restored.duplicate_deals));
   g_direction_restart_snapshot_complete[direction_index]=pass;
  }

void AdvanceCycle()
  {
   ++g_cycle;
   if(g_cycle>=6)
     {
      g_state=H_DONE;
      return;
     }
   ResetCycle();
   g_state=H_SEND_ENTRY;
  }

void CompleteCycle()
  {
   double tolerance=MathMax(1e-9,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)*0.5);
   double entry_price=AverageFill(g_entry_fill);
   double exit_price=g_exit_volume>0.0?g_exit_value/g_exit_volume:0.0;
   bool aggregated=FillResolved(g_entry_fill,tolerance) && g_entry_fill.filled_volume>0.0 &&
                   g_exit_volume+1e-9>=g_entry_fill.filled_volume && entry_price>0.0 && exit_price>0.0;
   Assess(CycleName()+"_deal_aggregation",aggregated?"PASS":"FAIL",
          StringFormat("requested=%.2f;filled=%.2f;remaining=%.2f;entry_deals=%d;exit_volume=%.2f;entry=%.8f;exit=%.8f",
                       g_entry_fill.requested_volume,g_entry_fill.filled_volume,RemainingVolume(g_entry_fill),g_entry_fill.deal_count,g_exit_volume,entry_price,exit_price));
   if(g_plan==H_EXIT_SERVER_SL)
     {
      bool observed=g_exit_reason==DEAL_REASON_SL;
      Assess(CycleName()+"_server_SL",observed?"PASS":"SKIP",observed?"DEAL_REASON_SL observed":"NOT_OBSERVED; exit_reason="+IntegerToString((int)g_exit_reason));
     }
   else if(g_plan==H_EXIT_SERVER_TP)
     {
      bool observed=g_exit_reason==DEAL_REASON_TP;
      Assess(CycleName()+"_server_TP",observed?"PASS":"SKIP",observed?"DEAL_REASON_TP observed":"NOT_OBSERVED; exit_reason="+IntegerToString((int)g_exit_reason));
     }
   else
     {
      bool observed=!g_cleanup_after_skip && g_exit_reason==DEAL_REASON_EXPERT;
      Assess(CycleName()+"_time_exit",observed?"PASS":"SKIP",observed?"expert market close observed":"NOT_OBSERVED; exit_reason="+IntegerToString((int)g_exit_reason));
      if(observed) g_direction_time_complete[g_direction>0?0:1]=true;
     }
   WriteRow("TRADE",DirectionName(),PlanName()+"_CLOSED",aggregated?"PASS":"FAIL",
            StringFormat("signal=%I64d;request=%I64d;fill=%I64d;close=%I64d;requested_volume=%.2f;filled_volume=%.2f;remaining_volume=%.2f;entry=%.8f;exit=%.8f;commission=%.8f;fee=%.8f;swap=%.8f;exit_reason=%d;entry_order=%I64u;entry_deal=%I64u;exit_deal=%I64u",
                         g_signal_msc,g_request_msc,g_first_fill_msc,g_close_msc,g_entry_fill.requested_volume,g_entry_fill.filled_volume,RemainingVolume(g_entry_fill),entry_price,exit_price,g_commission_total,g_fee_total,g_swap_total,(int)g_exit_reason,g_entry_order,g_entry_deal,g_exit_deal));
   if(!aggregated) g_state=H_FAILED;
   else AdvanceCycle();
  }

void RunFillTrackerUnitTest()
  {
   HarnessFillTracker tracker;
   ResetFillTracker(tracker,0.10);
   AddFill(tracker,0.03,100.0);
   bool not_complete_after_first=!FillResolved(tracker,1e-9) && Almost(RemainingVolume(tracker),0.07,1e-9);
   AddFill(tracker,0.02,100.2);
   bool not_complete_after_second=!FillResolved(tracker,1e-9) && Almost(RemainingVolume(tracker),0.05,1e-9);
   AddFill(tracker,0.05,99.9);
   bool complete=FillResolved(tracker,1e-9) && Almost(AverageFill(tracker),99.99,1e-9);
   Assess("partial_fill_tracker_production_unit",not_complete_after_first && not_complete_after_second && complete?"UNIT_PASS":"FAIL",
          StringFormat("requested=%.2f;filled=%.2f;remaining=%.2f;average=%.8f",tracker.requested_volume,tracker.filled_volume,RemainingVolume(tracker),AverageFill(tracker)));
  }

bool Almost(const double left,const double right,const double tolerance)
  {
   return MathAbs(left-right)<=tolerance;
  }

int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))
     {
      Print("Order reachability harness is Strategy Tester only");
      return INIT_FAILED;
     }
   FolderCreate(InpLogFolder,FILE_COMMON);
   string name=InpLogFolder+"\\ExpectedValue_TickShock_"+InpRunId+"_order_reachability.csv";
   g_file=FileOpen(name,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(g_file==INVALID_HANDLE) return INIT_FAILED;
   FileWrite(g_file,"run_id","record_type","direction","phase","result","detail");
   WriteRow("ENV","","TESTER_CONTEXT","OBSERVED",StringFormat("mql_tester=true;mql_optimization=%s;server=%s;account_currency=%s;account_trade_mode=%d;terminal_build=%I64d;symbol=%s;period=%s",
            MQLInfoInteger(MQL_OPTIMIZATION)?"true":"false",AccountInfoString(ACCOUNT_SERVER),AccountInfoString(ACCOUNT_CURRENCY),(int)AccountInfoInteger(ACCOUNT_TRADE_MODE),(long)TerminalInfoInteger(TERMINAL_BUILD),_Symbol,EnumToString((ENUM_TIMEFRAMES)_Period)));
   WriteRow("SPEC","","SYMBOL","OBSERVED",StringFormat("symbol=%s;digits=%d;point=%.10f;tick_size=%.10f;tick_value=%.10f;contract_size=%.2f;volume_min=%.8f;volume_max=%.8f;volume_step=%.8f;stops_level=%d;freeze_level=%d;filling_mode=%d",
            _Symbol,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS),SymbolInfoDouble(_Symbol,SYMBOL_POINT),SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE),SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL),(int)SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE)));
   RunFillTrackerUnitTest();
   Assess("tester_only_guard","PASS","harness refuses terminal/live execution");
   ResetCycle();
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   if(g_state==H_DONE || g_state==H_FAILED) return;
   MqlDateTime server_time;
   TimeToStruct(TimeCurrent(),server_time);
   if(server_time.hour<InpEarliestServerHour) return;
   if(g_state==H_SEND_ENTRY)
     {
      g_state=H_WAIT_ENTRY_RESOLUTION;
      if(!SendEntry()) g_state=H_FAILED;
      return;
     }
   if(g_state==H_WAIT_ENTRY_RESOLUTION)
     {
      if(!EntryResidualClosed()) return;
      double tolerance=MathMax(1e-9,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP)*0.5);
      g_entry_fill.residual_closed=true;
      bool resolved=FillResolved(g_entry_fill,tolerance) && g_entry_fill.filled_volume>0.0;
      Assess(CycleName()+"_entry_fill",resolved?"PASS":"FAIL",
             StringFormat("requested_volume=%.2f;filled_volume=%.2f;remaining_volume=%.2f;deal_count=%d;residual_closed=%s",g_entry_fill.requested_volume,g_entry_fill.filled_volume,RemainingVolume(g_entry_fill),g_entry_fill.deal_count,g_entry_fill.residual_closed?"true":"false"));
      if(!resolved) {g_state=H_FAILED;return;}
      g_recovery_observed=RecoverManagedPosition();
      Assess(CycleName()+"_position_field_recovery",g_recovery_observed?"PASS":"SKIP",g_recovery_observed?"magic/time/volume/open/sl/tp recovered":"NOT_OBSERVED; position already closed");
      ObserveSimulatedRestartSnapshot();
      g_wait_ticks=0;
      g_state=H_WAIT_PLANNED_EXIT;
      return;
     }
   if(g_state==H_WAIT_PLANNED_EXIT)
     {
      if(!PositionSelect(_Symbol) || (long)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber)
        {
         if(g_exit_volume+1e-9>=g_entry_fill.filled_volume) CompleteCycle();
         return;
        }
      ++g_wait_ticks;
      if(g_plan==H_EXIT_TIME && g_wait_ticks>=InpWaitTicksBeforeTimeClose)
        {
         g_state=H_WAIT_EXIT_RESOLUTION;
         if(!SendTimeOrCleanupClose()) g_state=H_FAILED;
         return;
        }
      if(g_plan!=H_EXIT_TIME && g_wait_ticks>=InpBarrierTimeoutTicks)
        {
         Assess(CycleName()+"_barrier_timeout","SKIP","NOT_OBSERVED within configured tick limit; closing cleanup position");
         g_cleanup_after_skip=true;
         g_state=H_WAIT_EXIT_RESOLUTION;
         if(!SendTimeOrCleanupClose()) g_state=H_FAILED;
        }
      return;
     }
   if(g_state==H_WAIT_EXIT_RESOLUTION)
     {
      if((!PositionSelect(_Symbol) || (long)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) &&
         g_exit_volume+1e-9>=g_entry_fill.filled_volume) CompleteCycle();
     }
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD || trans.deal==0 || !HistoryDealSelect(trans.deal)) return;
   if((long)HistoryDealGetInteger(trans.deal,DEAL_MAGIC)!=InpMagicNumber) return;
   ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   ulong deal_order=(ulong)HistoryDealGetInteger(trans.deal,DEAL_ORDER);
   ulong position_id=(ulong)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);
   string deal_symbol=HistoryDealGetString(trans.deal,DEAL_SYMBOL);
   long deal_magic=(long)HistoryDealGetInteger(trans.deal,DEAL_MAGIC);
   ENUM_DEAL_TYPE deal_type=(ENUM_DEAL_TYPE)HistoryDealGetInteger(trans.deal,DEAL_TYPE);
   double volume=HistoryDealGetDouble(trans.deal,DEAL_VOLUME);
   double price=HistoryDealGetDouble(trans.deal,DEAL_PRICE);
   long time_msc=(long)HistoryDealGetInteger(trans.deal,DEAL_TIME_MSC);
   double commission=HistoryDealGetDouble(trans.deal,DEAL_COMMISSION);
   double fee=HistoryDealGetDouble(trans.deal,DEAL_FEE);
   double swap=HistoryDealGetDouble(trans.deal,DEAL_SWAP);
   double profit=HistoryDealGetDouble(trans.deal,DEAL_PROFIT);
   ENUM_DEAL_REASON reason=(ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal,DEAL_REASON);
   bool applied=TSApplyOrderDeal(g_order_fill_state,trans.deal,0,0,position_id,deal_symbol,deal_magic,g_direction,entry,volume,price);
   if(!applied)
     {
      WriteRow("DEAL",DirectionName(),PlanName()+"_REJECTED_BY_PRODUCTION_STATE","FAIL",StringFormat("deal=%I64u;order=%I64u;position=%I64u;symbol=%s;magic=%I64d;entry=%d;type=%d;duplicates=%d;identity_rejections=%d",trans.deal,deal_order,position_id,deal_symbol,deal_magic,(int)entry,(int)deal_type,g_order_fill_state.duplicate_deals,g_order_fill_state.identity_rejections));
      ++g_failed;
      return;
     }
   if(entry==DEAL_ENTRY_IN && g_order_fill_state.position_ticket==0 && position_id>0)
      g_order_fill_state.position_ticket=position_id;
   ++g_observed_deal_count;
   if(entry==DEAL_ENTRY_IN) ++g_observed_entry_deal_count;
   else if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_INOUT || entry==DEAL_ENTRY_OUT_BY) ++g_observed_exit_deal_count;
   g_commission_total+=commission;
   g_fee_total+=fee;
   g_swap_total+=swap;
   if(entry==DEAL_ENTRY_IN)
     {
      AddFill(g_entry_fill,volume,price);
      if(g_entry_fill.deal_count>1) g_partial_fill_observed=true;
      if(g_first_fill_msc==0) g_first_fill_msc=time_msc;
      g_entry_deal=trans.deal;
      g_last_entry_deal_ticket=trans.deal;
      g_last_entry_order_ticket=deal_order;
      g_last_entry_position_ticket=position_id;
      g_last_entry_deal_volume=volume;
      g_last_entry_deal_price=price;
      WriteRow("DEAL",DirectionName(),PlanName()+"_ENTRY_FILL","OBSERVED",StringFormat("deal=%I64u;order=%I64u;position=%I64u;request_id=%u;symbol=%s;magic=%I64d;deal_type=%d;deal_entry=%d;deal_reason=%d;account_currency=%s;commission_source=MT5_STRATEGY_TESTER_HISTORY_DEAL_FIELDS;requested_volume=%.2f;deal_volume=%.2f;filled_volume=%.2f;remaining_volume=%.2f;price=%.8f;commission=%.8f;fee=%.8f;swap=%.8f;profit=%.8f",trans.deal,deal_order,position_id,g_request_id,deal_symbol,deal_magic,(int)deal_type,(int)entry,(int)reason,AccountInfoString(ACCOUNT_CURRENCY),g_entry_fill.requested_volume,volume,g_entry_fill.filled_volume,RemainingVolume(g_entry_fill),price,commission,fee,swap,profit));
     }
   else if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_INOUT || entry==DEAL_ENTRY_OUT_BY)
     {
      g_exit_volume+=volume;
      g_exit_value+=volume*price;
      g_close_msc=time_msc;
      g_exit_deal=trans.deal;
      g_exit_reason=reason;
      WriteRow("DEAL",DirectionName(),PlanName()+"_EXIT_FILL","OBSERVED",StringFormat("deal=%I64u;order=%I64u;position=%I64u;request_id=%u;symbol=%s;magic=%I64d;deal_type=%d;deal_entry=%d;deal_reason=%d;account_currency=%s;commission_source=MT5_STRATEGY_TESTER_HISTORY_DEAL_FIELDS;volume=%.2f;aggregated_exit_volume=%.2f;price=%.8f;commission=%.8f;fee=%.8f;swap=%.8f;profit=%.8f",trans.deal,deal_order,position_id,g_request_id,deal_symbol,deal_magic,(int)deal_type,(int)entry,(int)reason,AccountInfoString(ACCOUNT_CURRENCY),volume,g_exit_volume,price,commission,fee,swap,profit));
     }
  }

void OnDeinit(const int reason)
  {
   Assess("actual_partial_fill_observation",g_partial_fill_observed?"PASS":"SKIP",g_partial_fill_observed?"multiple entry deals or DONE_PARTIAL observed":"NOT_OBSERVED; unit path is reported separately and is not counted as PASS");
   Assess("actual_process_restart", "SKIP", "NOT_OBSERVED; process restart was not injected");
   bool commission_fields_observed=g_observed_deal_count>0;
   string commission_observation=!commission_fields_observed?"NOT_OBSERVED":(MathAbs(g_commission_total)+MathAbs(g_fee_total)>1e-12?"OBSERVED_NONZERO":"OBSERVED_ZERO");
   Assess("tester_deal_commission_fields",commission_fields_observed?"PASS":"SKIP",StringFormat("status=%s;deal_count=%d;entry_deals=%d;exit_deals=%d;commission=%.8f;fee=%.8f;swap=%.8f;source=MT5_STRATEGY_TESTER_HISTORY_DEAL_FIELDS;live_broker_commission_not_validated=true",commission_observation,g_observed_deal_count,g_observed_entry_deal_count,g_observed_exit_deal_count,g_commission_total,g_fee_total,g_swap_total));
   bool owned_position_open=PositionSelect(_Symbol) && (long)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber;
   Assess("unclosed_harness_position_zero",owned_position_open?"FAIL":"PASS",owned_position_open?StringFormat("ticket=%I64u;volume=%.2f",(ulong)PositionGetInteger(POSITION_TICKET),PositionGetDouble(POSITION_VOLUME)):"harness-owned open positions=0");
   bool completed=g_state==H_DONE && g_direction_time_complete[0] && g_direction_time_complete[1];
   string result=g_failed==0 && completed?(g_skipped>0?"PASS_WITH_SKIPS":"PASS"):"FAIL";
   WriteRow("SUMMARY","","ALL",result,StringFormat("passed=%d;failed=%d;skipped=%d;unit_passed=%d;state=%d;long_time=%s;short_time=%s;unobserved_not_passed=true",g_passed,g_failed,g_skipped,g_unit_passed,(int)g_state,g_direction_time_complete[0]?"true":"false",g_direction_time_complete[1]?"true":"false"));
   if(g_file!=INVALID_HANDLE){FileFlush(g_file);FileClose(g_file);g_file=INVALID_HANDLE;}
  }

double OnTester()
  {
   return g_failed==0 && g_state==H_DONE?1.0:0.0;
  }
