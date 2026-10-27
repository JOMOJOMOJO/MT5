#property strict
#property version "1.90"
#property description "Wave33 day trade: no fixed TP, step SL, 24h maximum, tester orders only."
#include "../Include/Wave33Visual/Engine.mqh"
#include "../Include/Wave33Visual/ChopDisplay.mqh"
#include "../Include/Wave33Visual/Ledger.mqh"
#include "../Include/Wave33Visual/Room.mqh"
#include "../Include/Wave33Visual/BarOrder.mqh"
#include "../Include/Wave33Visual/OppositeExit.mqh"
#include "../Include/Wave33Visual/TesterRun.mqh"
#include "../Include/Wave33Visual/Wave1Target.mqh"
#include "../Include/Wave33Visual/Chop.mqh"
#include "../Include/Wave33Visual/PriorContext.mqh"
#include "../Include/Wave33Visual/ScaleOut.mqh"
#include "../Include/Wave33Visual/DayTrade.mqh"

enum W33Pattern {M15_M5=0,M5_M1=1};
enum W33ObstacleMode {DISPLAY_ONLY=0,SKIP_IF_BLOCKED=1,CAP_TP=2};
input W33Pattern InpPattern=M15_M5;
input W33TriggerMode InpTriggerMode=W33_PIVOT_BREAK;
input int InpSwingLeft=2;
input int InpSwingRight=2;
input double InpFibMin=0.382;
input double InpFibMax=0.618;
input bool InpRequireFibTouch=true;
input bool InpExtendWave1BeforeFib=true; // シグナル前・初回Fib38.2%到達前の高安更新で①終点を再追跡
input bool InpRejectDeepFib=false;
input bool InpRejectDeepFibClose=true; // 上位足の確定終値がFib61.8%より深ければ候補終了（ヒゲは許容）
input bool InpStrictWaveLifecycle=true; // 同じ第2波に属する転換だけを使い、初動を逃した候補を終了
input W33LowerRecognitionMode InpLowerRecognition=W33_NORMALIZED_OR_SIMPLE; // 確定した山谷を整理し、短い押し・戻りの反応突破も区別して追跡
input double InpMinWave1RoomR=0.25; // ①終点まで残す最小余地（SL幅=1R、0で比較用OFF）
input int InpTimeoutUpperBars=96;
input W33ObstacleMode InpObstacleMode=DISPLAY_ONLY;
input double InpRewardR=1.0; // 診断用RR参照値。このEAの実注文に固定TPは設定しない。
input bool InpExtendTPToWave1=true; // 診断用①TP参照。実際の発注TPは常に0。
input bool InpScaleOut=false; // この新EAはfalse専用。部分利確は使わない。
input double InpTPWave1BufferPoints=10.0; // ①手前の追加余裕（ポイント。実際はスプレッド・1ティック以上）
input double InpRiskPercent=1.0;
input double InpSLExtraPoints=10.0;
input bool InpEnableTesterOrders=false; // 過去データで売買する（MT5テスター内のみ）
input bool InpAllowTesterBatchRuns=true; // 全銘柄一括テストなど、最適化扱いのテスター実行を許可
input bool InpCancelConnectedOpposite=true; // ①終点から逆方向①候補が出たら、古い未発注候補を終了
input bool InpSkipBothConnectedWave1=true; // 両方が未発注なら、接続する逆①の古い側・新しい側を両方見送る（優先）。
input bool InpExitOnOppositeWave1=true; // 保有後に逆方向の青い①が確定したら、推定コスト込み損益がプラスの最初のティックで決済
input bool InpAuditOppositeExitTicks=false; // 決済待ち全ティックの監査CSV（検証用）
input ulong InpMagic=3320261026;
input uint InpDeviationPoints=20;
input bool InpDraw=true;
input bool InpShowInfoPanel=false; // 左下の小さな凡例を表示
input bool InpDiagnosticLabels=false; // 詳細なスイング・診断文字を表示
input bool InpShowSwingPaths=true; // 確定した山谷を破線で結ぶ
input bool InpReadableLabels=true; // ラベルを短くして間隔を空け、元の判断位置へ有限引出線を表示。
input bool InpKeepObjects=true;
input bool InpScreenshots=false;
input int InpScreenshotLimit=12;
input string InpRunTag="wave33_day_v190";
input bool InpChopDiagnostic=true; // 往復指標を記録。除外ON時はfalseでも必要な観測を継続する。
input bool InpSkipChoppyWave1=false; // true: ①内部の逆行合計/①値幅が0.5以上なら未発注シグナルを見送る。
input bool InpChopLabels=true; // Compact labels at knowledge availability, no panel.
input bool InpPriorContext=true; // 以前のM15/H1高安帯との位置関係を記録・描画。除外ON時は必ず観測する。
input bool InpSkipPriorLevelRetest=false; // true: ①終点が未突破の既知高安帯に重なり、最終TPが帯の先なら見送る。
input double InpPriorContextBandFraction=0.05; // 高安帯の片幅/固定①値幅（0.05なら上下各5%、全幅10%）。
// Manual important zones intentionally remain outside the automatic signal engine.
input string InpManualLevels=""; // Semicolon-separated prices, display from attach time only.

// Day-trade mode: all TP/scale-out inputs below remain legacy diagnostics only.
input bool InpStepSL=true; // +2R: entry SL, then +1R SL per further +1R.
input double InpStepStartR=2.0;
input double InpStepSizeR=1.0;
input double InpStepLagR=2.0;
input double InpMaxHoldHours=24.0; // elapsed hours from FIRST actual fill; 0<hours<=24
input bool InpCloseBeforeWeekend=true;
input int InpWeekendBufferMinutes=5; // close before the final session preceding a >=24h scheduled gap

W33DayTradeConfig g_day_config;
int g_day_file=INVALID_HANDLE;
datetime g_session_cache_at=0;long g_weekend_end_msc=0;
CWave33ChopObserver g_chop;
CWave33PriorContext g_prior;
CWave33Engine g_engine;
CWave33ChopDisplay g_display;
CWave33Ledger g_ledger;
ENUM_TIMEFRAMES g_upper,g_lower,g_frames[4];
datetime g_lastOpen[4];
bool g_ready=false;
string g_prefix,g_lastReason="",g_tag;
int g_shots=0;
int g_exit_tick_file=INVALID_HANDLE;
int g_scale_file=INVALID_HANDLE,g_deal_file=INVALID_HANDLE;
ulong g_seen_deals[];
int g_run_claim=INVALID_HANDLE;
bool g_effective_draw=false;
string g_input_hash="";
ulong g_knowledge_order=0,g_tick_order=0;
W33Setup g_last;
struct W33Execution
  {
   W33Setup setup;
   ulong position_id;
   double initial_risk_money;
   double net_cash;
   double exit_volume;
   double filled_volume;
   bool pending;
   ulong fill_order_key;
   double entry_costs;
   W33OppositeExitState opposite;
   ulong close_order_ticket;
   uint close_request_id;
   double close_prior_exit_volume;
   W33DayTradeState day;
   long day_first_fill_msc;
   bool day_sl_pending,day_close_pending;
   double day_sl_target,day_close_prior_exit;
   uint day_sl_request_id,day_close_request_id;
   ulong day_close_order;
   datetime day_sl_sent_at,day_next_retry;
   string day_close_reason,day_last_wait;
   W33ScaleOutState scale;
   W33ScaleOutPlan scale_plan;
   bool scale_fallback,scale_be_request_pending;
   ulong entry_order_ticket;
   double initial_sl_price,scale_be_target;
   datetime scale_next_close_at,scale_next_be_at,scale_be_sent_at;
   uint scale_be_request_id;
   string scale_last_wait,scale_last_be_reason;
  };
W33Execution g_records[];
#include "../Include/Wave33Visual/ScaleOutExecution.mqh"
#include "../Include/Wave33Visual/DayTradeExecution.mqh"

bool TesterExecutionContext()
  {
   return W33TesterContextAllowed((bool)MQLInfoInteger(MQL_TESTER),(bool)MQLInfoInteger(MQL_OPTIMIZATION),InpAllowTesterBatchRuns);
  }
string RunInputHash()
  {
   string value="1.90|"+EnumToString(InpPattern)+"|"+EnumToString(InpTriggerMode);
   value+="|"+(string)InpSwingLeft+"|"+(string)InpSwingRight+"|"+DoubleToString(InpFibMin,16)+"|"+DoubleToString(InpFibMax,16);
   value+="|"+(string)InpRequireFibTouch+"|"+(string)InpExtendWave1BeforeFib+"|"+(string)InpRejectDeepFib+"|"+(string)InpRejectDeepFibClose;
   value+="|"+(string)InpStrictWaveLifecycle+"|"+EnumToString(InpLowerRecognition)+"|"+DoubleToString(InpMinWave1RoomR,16);
   value+="|"+(string)InpTimeoutUpperBars+"|"+EnumToString(InpObstacleMode)+"|"+DoubleToString(InpRewardR,16)+"|"+DoubleToString(InpRiskPercent,16);
   value+="|"+DoubleToString(InpSLExtraPoints,16)+"|"+(string)InpEnableTesterOrders+"|"+(string)InpAllowTesterBatchRuns;
   value+="|"+(string)InpCancelConnectedOpposite+"|"+(string)InpExtendTPToWave1+"|"+DoubleToString(InpTPWave1BufferPoints,16);
   value+="|"+(string)InpExitOnOppositeWave1+"|"+(string)InpAuditOppositeExitTicks+"|"+(string)InpMagic+"|"+(string)InpDeviationPoints;
   value+="|"+(string)InpDraw+"|"+(string)InpShowInfoPanel+"|"+(string)InpDiagnosticLabels+"|"+(string)InpShowSwingPaths;
   value+="|"+(string)InpKeepObjects+"|"+(string)InpScreenshots+"|"+(string)InpScreenshotLimit+"|"+InpManualLevels;
   value+="|"+(string)InpChopDiagnostic+"|"+(string)InpSkipChoppyWave1+"|"+(string)InpChopLabels+"|"+W33_CHOP_VERSION+"|0.5|UNAVAILABLE_ALLOW";
   value+="|"+(string)InpPriorContext+"|"+(string)InpSkipPriorLevelRetest+"|"+DoubleToString(InpPriorContextBandFraction,16)+"|"+W33_PRIOR_CONTEXT_VERSION+"|UNAVAILABLE_ALLOW";
   value+="|"+(string)InpSkipBothConnectedWave1+"|"+(string)InpReadableLabels;
   value+="|"+(string)InpScaleOut+"|FIXED_HALF_NEAR_THEN_FAR_V1";
   value+="|"+(string)InpStepSL+"|"+DoubleToString(InpStepStartR,16)+"|"+DoubleToString(InpStepSizeR,16)+"|"+DoubleToString(InpStepLagR,16);
   value+="|"+DoubleToString(InpMaxHoldHours,16)+"|"+(string)InpCloseBeforeWeekend+"|"+(string)InpWeekendBufferMinutes+"|NO_FIXED_TP";
   return W33Hash(value);
  }

int RecordIndex(const string id)
  {
   for(int i=0;i<ArraySize(g_records);i++)if(g_records[i].setup.setup_id==id)return i;
   return -1;
  }
void MergeExecution(W33Setup &s)
  {
   int i=RecordIndex(s.setup_id);if(i<0)return;
   W33Setup saved=g_records[i].setup;
   s.entry_price=saved.entry_price;s.sl_price=saved.sl_price;s.tp_price=saved.tp_price;
   s.tp_rr_price=saved.tp_rr_price;s.tp_wave1_target_price=saved.tp_wave1_target_price;
   s.tp_wave1_buffer_points=saved.tp_wave1_buffer_points;s.tp_extended_to_wave1=saved.tp_extended_to_wave1;
   s.tp_adjustment_reason=saved.tp_adjustment_reason;
   s.risk_points=saved.risk_points;s.intended_rr=saved.intended_rr;
   s.order_sent_at=saved.order_sent_at;s.fill_at=saved.fill_at;
   if(!s.connected_opposite_cancelled)s.entry_status=saved.entry_status;
   if(s.skip_reason=="")s.skip_reason=saved.skip_reason;s.exit_at=saved.exit_at;s.exit_reason=saved.exit_reason;
   s.realized_r=saved.realized_r;s.spread_points=saved.spread_points;
   s.nearest_obstacle_price=saved.nearest_obstacle_price;s.nearest_obstacle_tf=saved.nearest_obstacle_tf;
   s.nearest_obstacle_known_at=saved.nearest_obstacle_known_at;s.obstacle_distance_r=saved.obstacle_distance_r;
   s.nearest_obstacle_time=saved.nearest_obstacle_time;s.nearest_obstacle_source=saved.nearest_obstacle_source;
   s.nearest_obstacle_is_high=saved.nearest_obstacle_is_high;
   s.wave1_room_price=saved.wave1_room_price;s.wave1_room_r=saved.wave1_room_r;s.wave1_room_rejected=saved.wave1_room_rejected;
   s.h1_direction=saved.h1_direction;
   s.actual_rr=saved.actual_rr;s.candle_body_ratio=saved.candle_body_ratio;s.candle_body_atr=saved.candle_body_atr;
   s.exit_deal_reason=saved.exit_deal_reason;s.exit_price=saved.exit_price;
   s.opposite_exit_armed=saved.opposite_exit_armed;s.opposite_setup_id=saved.opposite_setup_id;
   s.opposite_wave_known_at=saved.opposite_wave_known_at;s.opposite_wave_peak_time=saved.opposite_wave_peak_time;s.opposite_wave_price=saved.opposite_wave_price;
   s.opposite_exit_requested_at=saved.opposite_exit_requested_at;s.opposite_exit_net_estimate=saved.opposite_exit_net_estimate;s.opposite_exit_cost_estimate=saved.opposite_exit_cost_estimate;
   s.execution_net_cash=saved.execution_net_cash;s.execution_initial_risk_money=saved.execution_initial_risk_money;
   s.execution_position_id=saved.execution_position_id;s.opposite_close_order_ticket=saved.opposite_close_order_ticket;
  }
double PriceRound(const double p,const int direction)
  {
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick<=0)tick=_Point;
   double v=p/tick;
   return NormalizeDouble((direction>0?MathCeil(v-1e-9):MathFloor(v+1e-9))*tick,_Digits);
  }
void Publish(W33Event &e)
  {
   g_chop.Event(e); // Observe exactly this published prefix; the entry policy runs separately.
   g_prior.Event(e);
   g_ledger.Write(e);g_display.Event(e);DayTradeHideTarget(e.setup);
   if(e.setup.setup_id!="")g_last=e.setup;
   if(e.reason_kind=="EXCLUSION")g_lastReason=e.reason;
  }
void Emit(W33Setup &s,const string event,const string kind,const string reason)
  {
   W33Event e;ZeroMemory(e);e.at=TimeCurrent();e.event_type=event;e.reason_kind=kind;e.reason=reason;e.setup=s;Publish(e);
  }
bool OwnedPosition(const int record,ulong &ticket)
  {
   ticket=0;
   if(record<0 || record>=ArraySize(g_records) || g_records[record].position_id==0)return false;
   for(int p=PositionsTotal()-1;p>=0;p--)
     {
      ulong candidate=PositionGetTicket(p);if(candidate==0)continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol || (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagic ||
         (ulong)PositionGetInteger(POSITION_IDENTIFIER)!=g_records[record].position_id)continue;
      long type=PositionGetInteger(POSITION_TYPE);
      if((type==POSITION_TYPE_BUY?1:-1)!=g_records[record].setup.direction)return false;
      ticket=candidate;return true;
     }
   return false;
  }
bool AcceptedDeal(const uint retcode)
  {return retcode==TRADE_RETCODE_DONE || retcode==TRADE_RETCODE_DONE_PARTIAL || retcode==TRADE_RETCODE_PLACED;}
void ArmOppositeExit(const W33Event &source,const ulong orderKey)
  {
   if(!InpExitOnOppositeWave1 || !InpEnableTesterOrders || !TesterExecutionContext() ||
      source.event_type!="WAVE1_PEAK_CONFIRMED")return;
   for(int i=0;i<ArraySize(g_records);i++)
     {
      ulong ticket;if(!OwnedPosition(i,ticket))continue;
      if(!W33ArmOppositeExit(g_records[i].opposite,g_records[i].setup.direction,g_records[i].setup.fill_at,g_records[i].fill_order_key,
                            source.setup.setup_id,source.setup.direction,source.at,orderKey))continue;
      W33Setup s=g_records[i].setup;s.opposite_exit_armed=true;s.opposite_setup_id=source.setup.setup_id;
      s.opposite_wave_known_at=source.at;s.opposite_wave_peak_time=source.setup.wave1_peak_time;s.opposite_wave_price=source.setup.wave1_peak_price;
      g_records[i].setup=s;
      Emit(s,"OPPOSITE_WAVE1_ARMED","OBSERVATION","source="+s.opposite_setup_id+" | first profitable executable quote after blue W1 confirmation");
     }
  }
void AuditOppositeTick(const int index,const ulong ticket,const MqlTick &tick,const double volume,
                       const double quoteProfit,const double swap,const double entryCostRate,const double net,const string status)
  {
   if(g_exit_tick_file==INVALID_HANDLE)return;
   FileWrite(g_exit_tick_file,g_records[index].setup.setup_id,W33Time(TimeCurrent()),(long)tick.time_msc,(long)g_tick_order,(long)g_knowledge_order,
      (long)ticket,(long)g_records[index].position_id,DoubleToString(tick.bid,10),DoubleToString(tick.ask,10),DoubleToString(volume,8),
      DoubleToString(quoteProfit,10),DoubleToString(g_records[index].net_cash,10),DoubleToString(swap,10),DoubleToString(entryCostRate,10),
      DoubleToString(entryCostRate*volume,10),DoubleToString(net,10),g_records[index].opposite.request_pending?1:0,
      g_records[index].opposite.attempts,status,g_records[index].setup.opposite_setup_id);
  }
void CloseOppositeRejected(const int index,const string reason)
  {
   W33ResolveOppositeExitRequest(g_records[index].opposite,true);
   W33Setup s=g_records[index].setup;Emit(s,"OPPOSITE_CLOSE_REJECTED","OBSERVATION",reason);
   g_records[index].close_order_ticket=0;g_records[index].close_request_id=0;
  }
void ManageOppositeExits()
  {
   // This guard also applies on normal demo/live charts: no closing or SL/TP changes there.
   if(!InpExitOnOppositeWave1 || !InpEnableTesterOrders || !TesterExecutionContext())return;
   MqlTick tick;if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0 || tick.ask<tick.bid)return;
   for(int i=0;i<ArraySize(g_records);i++)
     {
      if(!g_records[i].opposite.armed)continue;
      if(g_records[i].scale.request_pending || g_records[i].scale_be_request_pending || g_records[i].day_close_pending || g_records[i].day_sl_pending)continue;
      ulong ticket;if(!OwnedPosition(i,ticket))continue;
      if(!ScaleOutEntrySettled(i) || !ScaleOutLedgerMatchesPosition(i))continue;
      if(g_records[i].opposite.request_pending)
        {
         // An IOC partial fill may leave a remainder. An active close order still owns it.
         bool activeOrder=g_records[i].close_order_ticket>0 && OrderSelect(g_records[i].close_order_ticket);
         if(!activeOrder && g_records[i].exit_volume>g_records[i].close_prior_exit_volume+1e-8)
            W33ResolveOppositeExitRequest(g_records[i].opposite,true);
         else if(!activeOrder && g_records[i].close_order_ticket>0 && HistoryOrderSelect(g_records[i].close_order_ticket))
           {
            ENUM_ORDER_STATE state=(ENUM_ORDER_STATE)HistoryOrderGetInteger(g_records[i].close_order_ticket,ORDER_STATE);
            if(state==ORDER_STATE_CANCELED || state==ORDER_STATE_REJECTED || state==ORDER_STATE_EXPIRED)
               CloseOppositeRejected(i,"close order terminated "+EnumToString(state));
           }
        }
      // History/order selection does not change the selected position, but reselect the exact ticket explicitly.
      if(!PositionSelectByTicket(ticket))continue;
      double volume=PositionGetDouble(POSITION_VOLUME),open=PositionGetDouble(POSITION_PRICE_OPEN),swap=PositionGetDouble(POSITION_SWAP),quoteProfit=0;
      int direction=g_records[i].setup.direction;double closePrice=direction>0?tick.bid:tick.ask;
      if(!OrderCalcProfit(direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,volume,open,closePrice,quoteProfit))
        {AuditOppositeTick(i,ticket,tick,volume,0,swap,0,0,"PROFIT_CALC_FAILED");continue;}
      double entryCostRate=g_records[i].filled_volume>0?g_records[i].entry_costs/g_records[i].filled_volume:0;
      double net=W33OppositeNetEstimate(quoteProfit,g_records[i].net_cash,swap,entryCostRate,volume);
      g_records[i].setup.opposite_exit_net_estimate=net;g_records[i].setup.opposite_exit_cost_estimate=entryCostRate*volume;
      bool ready=W33ShouldRequestOppositeExit(g_records[i].opposite,true,true,true,net);
      AuditOppositeTick(i,ticket,tick,volume,quoteProfit,swap,entryCostRate,net,ready?"READY":(g_records[i].opposite.request_pending?"REQUEST_PENDING":"WAIT_PROFIT"));
      if(!ready)continue;
      MqlTradeRequest closeRequest;MqlTradeResult closeResult;MqlTradeCheckResult check;
      ZeroMemory(closeRequest);ZeroMemory(closeResult);ZeroMemory(check);
      closeRequest.action=TRADE_ACTION_DEAL;closeRequest.position=ticket;closeRequest.symbol=_Symbol;closeRequest.magic=InpMagic;
      closeRequest.type=direction>0?ORDER_TYPE_SELL:ORDER_TYPE_BUY;closeRequest.volume=volume;closeRequest.price=closePrice;
      closeRequest.deviation=InpDeviationPoints;closeRequest.comment="W33_OPPOSITE_W1_PROFIT";
      long filling=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
      closeRequest.type_filling=(filling&SYMBOL_FILLING_FOK)!=0?ORDER_FILLING_FOK:((filling&SYMBOL_FILLING_IOC)!=0?ORDER_FILLING_IOC:ORDER_FILLING_RETURN);
      W33MarkOppositeExitRequested(g_records[i].opposite,TimeCurrent(),++g_knowledge_order);
      g_records[i].close_prior_exit_volume=g_records[i].exit_volume;
      g_records[i].setup.opposite_exit_requested_at=TimeCurrent();
      W33Setup s=g_records[i].setup;
      if(!OrderCheck(closeRequest,check))
        {CloseOppositeRejected(i,"ORDER_CHECK "+IntegerToString((int)check.retcode)+" "+check.comment);continue;}
      Emit(s,"OPPOSITE_CLOSE_REQUEST","OBSERVATION","net_estimate="+DoubleToString(net,10)+" | bid="+DoubleToString(tick.bid,_Digits)+" ask="+DoubleToString(tick.ask,_Digits));
      bool sent=OrderSend(closeRequest,closeResult);
      g_records[i].close_order_ticket=closeResult.order;g_records[i].close_request_id=closeResult.request_id;
      if(!sent || !AcceptedDeal(closeResult.retcode))
         CloseOppositeRejected(i,"ORDER_SEND "+IntegerToString((int)closeResult.retcode)+" "+closeResult.comment);
      else {s.opposite_close_order_ticket=closeResult.order;g_records[i].setup.opposite_close_order_ticket=closeResult.order;
         Emit(s,"OPPOSITE_CLOSE_ACCEPTED","OBSERVATION","order="+IntegerToString((long)closeResult.order)+" | retcode="+IntegerToString((int)closeResult.retcode));}
     }
   if(g_exit_tick_file!=INVALID_HANDLE)FileFlush(g_exit_tick_file);
  }
void Screenshot(const W33Setup &s,const string event)
  {
   if(!InpScreenshots || !InpDraw || g_shots>=InpScreenshotLimit || !MQLInfoInteger(MQL_VISUAL_MODE))return;
   Panel();g_display.Layout(true);ChartRedraw();
   string name="W33_"+W33Hash(g_tag)+"_"+W33Hash(s.setup_id)+"_"+event+".png";
   bool ok=ChartScreenShot(0,name,1600,1000,ALIGN_RIGHT);g_shots++;
   W33Setup copy=s;Emit(copy,"DRAWING_CAPTURE","OBSERVATION",ok?name:"ChartScreenShot failed "+IntegerToString(GetLastError()));
  }
void Obstacle(W33Setup &s)
  {
   W33Pivot pivots[];g_engine.GetObstacles(pivots);
   double best=DBL_MAX;s.nearest_obstacle_price=0;s.nearest_obstacle_source="";
   s.nearest_obstacle_time=0;s.nearest_obstacle_known_at=0;s.nearest_obstacle_tf=PERIOD_CURRENT;s.nearest_obstacle_is_high=false;
   for(int i=0;i<ArraySize(pivots);i++)
     {
      double delta=s.direction*(pivots[i].price-s.entry_price);
      if(delta>0 && delta<best && pivots[i].known_at<=TimeCurrent())
        {
         best=delta;s.nearest_obstacle_price=pivots[i].price;s.nearest_obstacle_tf=pivots[i].tf;
         s.nearest_obstacle_time=pivots[i].time;s.nearest_obstacle_known_at=pivots[i].known_at;
         s.nearest_obstacle_is_high=pivots[i].is_high;
         s.nearest_obstacle_source=pivots[i].is_high?"SWING_HIGH":"SWING_LOW";
        }
     }
   double peakDelta=s.direction*(s.wave1_peak_price-s.entry_price);
   if(peakDelta>0 && peakDelta<best)
     {best=peakDelta;s.nearest_obstacle_price=s.wave1_peak_price;s.nearest_obstacle_tf=s.upper_tf;
      s.nearest_obstacle_time=s.wave1_peak_time;s.nearest_obstacle_known_at=s.wave1_peak_known_at;
      s.nearest_obstacle_is_high=s.direction>0;s.nearest_obstacle_source="WAVE1";}
   // An identical native swing can win the loop first. Preserve its W1 identity.
   if(s.nearest_obstacle_price>0 && MathAbs(s.nearest_obstacle_price-s.wave1_peak_price)<=_Point*0.5 &&
      s.nearest_obstacle_tf==s.upper_tf && s.nearest_obstacle_time==s.wave1_peak_time)
      s.nearest_obstacle_source="WAVE1";
   s.obstacle_distance_r=(s.nearest_obstacle_price>0 && s.risk_points>0)?best/(s.risk_points*_Point):-1;
   s.h1_direction=g_engine.H1Direction(s.direction);
  }
bool Plan(W33Setup &s,string &why)
  {
   MqlTick tick;if(!SymbolInfoTick(_Symbol,tick)){why="NO_QUOTE";return false;}
   s.entry_price=s.direction>0?tick.ask:tick.bid;s.spread_points=(tick.ask-tick.bid)/_Point;
   double minDist=(double)MathMax(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*_Point;
   double pad=(s.spread_points+InpSLExtraPoints)*_Point+minDist;
   s.sl_price=PriceRound(s.wave2_extreme_price-s.direction*pad,-s.direction);
   double risk=s.direction*(s.entry_price-s.sl_price);s.risk_points=risk/_Point;s.intended_rr=InpRewardR;
   if(s.wave2_extreme_price<=0 || risk<=0){why="INVALID_STRUCTURAL_SL";return false;}
   s.tp_price=PriceRound(s.entry_price+s.direction*risk*InpRewardR,s.direction);
   s.tp_rr_price=s.tp_price;
   W33Wave1TargetResult target=W33ExtendTargetToWave1(InpExtendTPToWave1 || InpScaleOut,s.direction,s.entry_price,s.tp_rr_price,
      s.wave1_peak_fixed,s.wave1_peak_price,_Point,SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE),_Digits,
      s.spread_points,InpTPWave1BufferPoints);
   s.tp_price=target.final_tp;s.tp_wave1_target_price=target.desired_target;
   s.tp_wave1_buffer_points=target.effective_buffer_points;s.tp_extended_to_wave1=target.applied;
   s.tp_adjustment_reason=target.reason;
   Obstacle(s);
   bool roomAllowed=W33CheckWave1Room(s,InpMinWave1RoomR);
   // This separate EA has no fixed TP or partial close. Legacy targets remain
   // available only as reference diagnostics; no target caps the broker order.
   s.tp_price=0;s.actual_rr=0;s.tp_extended_to_wave1=false;s.tp_adjustment_reason="DAYTRADE_NO_FIXED_TP";
   if(!roomAllowed){why="WAVE1_ROOM_TOO_SMALL";return false;}
   double reference=s.direction>0?tick.bid:tick.ask;
   if(s.direction*(reference-s.sl_price)<minDist){why="BROKER_STOPS_OR_FREEZE_LEVEL";return false;}
   return true;
  }
bool PositionBusy()
  {
   // Netting and hedging: never merge with or alter any other position on this symbol.
   for(int i=0;i<ArraySize(g_records);i++)if(g_records[i].pending || g_records[i].day_close_pending || g_records[i].day_sl_pending || g_records[i].opposite.request_pending)return true;
   return PositionSelect(_Symbol);
  }
void HandleSignal(W33Event &signal)
  {
   W33Setup s=signal.setup;if(RecordIndex(s.setup_id)>=0)return;
   // Snapshot before SIGNAL itself or later events in the engine drain are
   // published. Same timestamp alone cannot establish pivot availability.
   W33ChopResult chop;g_chop.Evaluate(s,signal.at,chop);
   bool chopRejected=W33ChopShouldSkip(InpSkipChoppyWave1,chop);
   MqlRates bars[];int count=CopyRates(_Symbol,g_lower,1,15,bars);
   if(count>=2)
     {
      int last=count-1;double span=bars[last].high-bars[last].low,body=MathAbs(bars[last].close-bars[last].open),atr=0;
      for(int j=1;j<count;j++)atr+=MathMax(bars[j].high-bars[j].low,MathMax(MathAbs(bars[j].high-bars[j-1].close),MathAbs(bars[j].low-bars[j-1].close)));
      atr/=(count-1);s.candle_body_ratio=span>0?body/span:0;s.candle_body_atr=atr>0?body/atr:0;
     }
   string reason="";bool valid=Plan(s,reason);
   // Use final TP and executable quote, but only already published pivots and
   // accepted closed source-TF bars. Later events in this drain are unknown.
   W33PriorContextResult context;g_prior.Evaluate(s,signal.at,context);
   bool contextRejected=W33PriorContextShouldSkip(InpSkipPriorLevelRetest,context);
   // Reuse the display's rejected-signal status so a filtered setup does not
   // paint a green ENTRY arrow. The canonical SKIP reason below identifies chop.
   s.entry_status=(chopRejected || contextRejected)?"SIGNAL_RISK_REJECTED":(valid?"DIAGNOSTIC_SIGNAL":"SIGNAL_RISK_REJECTED");
   signal.setup=s;Publish(signal); // Preserve the decision snapshot; rejected signals never paint a filled ENTRY.
   if(s.tp_extended_to_wave1)Emit(s,"TP_WAVE1_EXTENDED","OBSERVATION",s.tp_adjustment_reason);
   int n=ArraySize(g_records);ArrayResize(g_records,n+1);ZeroMemory(g_records[n]);g_records[n].setup=s;
   PrepareScaleOut(n);
   s.state=RESISTANCE_AND_RISK_CHECK;Emit(s,"RISK_CHECK","OBSERVATION","actual_rr="+DoubleToString(s.actual_rr,6));
   if(InpChopDiagnostic || InpSkipChoppyWave1)
     {
      string outcome=chopRejected?"SKIP":(chop.status=="UNAVAILABLE"?"ALLOW_UNAVAILABLE":"ALLOW");
      string measurement="status="+chop.status+" ratio="+(chop.status=="UNAVAILABLE"?"NA":DoubleToString(chop.ratio,16));
      measurement+=" threshold="+DoubleToString(W33_CHOP_THRESHOLD,16)+" adverse="+DoubleToString(chop.adverse,16)+" span="+DoubleToString(chop.span,16);
      measurement+=" start="+W33Time(s.wave1_start_time)+" start_known="+W33Time(s.wave1_start_known_at);
      measurement+=" peak="+W33Time(s.wave1_peak_time)+" peak_known="+W33Time(s.wave1_peak_known_at);
      measurement+=" evaluated_at="+W33Time(signal.at)+" published_pivots="+(string)chop.raw_pivots+" outcome="+outcome;
      measurement+=" filter="+(InpSkipChoppyWave1?"ON":"OFF")+" missing_policy=ALLOW reason="+chop.reason;
      Emit(s,"CHOP_ENTRY_FILTER","OBSERVATION",measurement);
     }
   if(InpPriorContext || InpSkipPriorLevelRetest)
     {
      string measurement="status="+context.status+" reason="+context.reason;
      measurement+=" filter="+(InpSkipPriorLevelRetest?"ON":"OFF")+" outcome="+(contextRejected?(chopRejected?"WOULD_SKIP_CHOP_PRECEDENCE":"SKIP"):(context.status=="UNAVAILABLE"?"ALLOW_UNAVAILABLE":"ALLOW"));
      measurement+=" band_halfwidth_fraction="+DoubleToString(InpPriorContextBandFraction,16);
      measurement+=" source_tf="+EnumToString(context.selected.tf)+" source_at="+W33Time(context.selected.time)+" source_known="+W33Time(context.selected.known_at);
      measurement+=" source_price="+DoubleToString(context.selected.price,16)+" band_low="+DoubleToString(context.band_low,16)+" band_high="+DoubleToString(context.band_high,16);
      measurement+=" entry="+DoubleToString(s.entry_price,16)+" final_tp="+DoubleToString(s.tp_price,16)+" room_r="+DoubleToString(context.room_r,16);
      measurement+=" latest_close_at="+W33Time(context.latest_close_time)+" latest_close_known="+W33Time(context.latest_close_known_at)+" latest_close="+DoubleToString(context.latest_close,16);
      measurement+=" candidates="+(string)context.candidate_count+" near="+(string)context.near_count+" missing_policy=ALLOW";
      Emit(s,"PRIOR_CONTEXT_FILTER","OBSERVATION",measurement);
     }
   if(chopRejected)
     {
      s.skip_reason="CHOPPY_WAVE1";s.entry_status="SKIPPED";g_records[n].setup=s;
      Emit(s,"SKIP","EXCLUSION",s.skip_reason);
      // No submission exists here. Release the lane immediately, retaining all
      // historical evidence and preventing a later retry of this setup ID.
      if(!g_engine.FinishUnordered(s.setup_id,TimeCurrent(),s.skip_reason))
         Emit(s,"CHOP_FINISH_REJECTED","OBSERVATION","unsubmitted setup could not be completed; no order attempted");
      Screenshot(s,"SKIP");return;
     }
   if(contextRejected)
     {
      s.skip_reason="PRIOR_LEVEL_RETEST";s.entry_status="SKIPPED";g_records[n].setup=s;
      Emit(s,"SKIP","EXCLUSION",s.skip_reason);
      if(!g_engine.FinishUnordered(s.setup_id,TimeCurrent(),s.skip_reason))
         Emit(s,"CONTEXT_FINISH_REJECTED","OBSERVATION","unsubmitted setup could not be completed; no order attempted");
      Screenshot(s,"SKIP");return;
     }
   if(!valid)
     {
      s.skip_reason=reason;s.entry_status="SKIPPED";Emit(s,"SKIP","EXCLUSION",reason);g_records[n].setup=s;
      // This signal has no order or position. The new room exclusion must not
      // hold the direction slot until timeout and suppress the next real wave.
      if(reason=="WAVE1_ROOM_TOO_SMALL")g_engine.FinishUnordered(s.setup_id,TimeCurrent(),reason);
      Screenshot(s,"SKIP");return;
     }
   if(!InpEnableTesterOrders)
     {s.entry_status="DIAGNOSTIC_ONLY";Emit(s,"ORDER_DISABLED","OBSERVATION","tester orders disabled");g_records[n].setup=s;Screenshot(s,"SIGNAL");return;}
   if(!TesterExecutionContext())reason="TESTER_ONLY_ORDER_GUARD";
   else if(DayTradeWeekendDue())reason="WEEKEND_ENTRY_GUARD";
   else if(PositionBusy())reason="SYMBOL_POSITION_BUSY";
   else if(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE)==SYMBOL_TRADE_MODE_DISABLED)reason="SYMBOL_TRADE_DISABLED";
   if(reason!="")
     {s.skip_reason=reason;s.entry_status="SKIPPED";Emit(s,"SKIP","EXCLUSION",reason);g_records[n].setup=s;
      if(reason=="WEEKEND_ENTRY_GUARD")g_engine.FinishUnordered(s.setup_id,TimeCurrent(),reason);
      Screenshot(s,"SKIP");return;}
   ENUM_ORDER_TYPE type=s.direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   double loss=0;
   if(!OrderCalcProfit(type,_Symbol,1.0,s.entry_price,s.sl_price,loss) || loss>=0)
     {s.skip_reason="ORDER_CALC_PROFIT_FAILED";s.entry_status="SKIPPED";Emit(s,"SKIP","EXCLUSION",s.skip_reason);g_records[n].setup=s;return;}
   double budget=AccountInfoDouble(ACCOUNT_EQUITY)*InpRiskPercent/100.0;
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),maxLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double volume=step>0?MathFloor(MathMin(budget/(-loss),maxLot)/step+1e-9)*step:0;
   volume=NormalizeDouble(volume,8);
   if(volume<minLot || volume<=0)
     {s.skip_reason="RISK_SIZE_BELOW_MIN_LOT";s.entry_status="SKIPPED";Emit(s,"SKIP","EXCLUSION",s.skip_reason);g_records[n].setup=s;return;}
   ScaleOutCheckOrderVolume(n,volume,s);
   MqlTradeRequest request;MqlTradeResult result;MqlTradeCheckResult check;
   ZeroMemory(request);ZeroMemory(result);ZeroMemory(check);
   request.action=TRADE_ACTION_DEAL;request.symbol=_Symbol;request.magic=InpMagic;request.type=type;
   request.volume=volume;request.price=s.entry_price;request.sl=s.sl_price;request.tp=s.tp_price;
   request.deviation=InpDeviationPoints;request.comment=StringSubstr(s.setup_id,0,31);
   long filling=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   request.type_filling=(filling&SYMBOL_FILLING_FOK)!=0?ORDER_FILLING_FOK:((filling&SYMBOL_FILLING_IOC)!=0?ORDER_FILLING_IOC:ORDER_FILLING_RETURN);
   if(!OrderCheck(request,check))
     {s.entry_status="SKIPPED";s.skip_reason="ORDER_CHECK "+IntegerToString((int)check.retcode)+" "+check.comment;
      Emit(s,"SKIP","EXCLUSION",s.skip_reason);g_records[n].setup=s;return;}
   bool marked=g_engine.MarkOrderSubmitted(s.setup_id,true,TimeCurrent());
   if(!marked && (InpCancelConnectedOpposite || InpSkipBothConnectedWave1))
     {
      s.entry_status="SKIPPED";s.skip_reason="SETUP_NOT_ACTIVE_AT_ORDER_SEND";
      Emit(s,"SKIP","EXCLUSION",s.skip_reason);g_records[n].setup=s;return;
     }
   s.order_sent_at=TimeCurrent();s.entry_status="ORDER_SENT";
   g_records[n].setup=s;g_records[n].initial_risk_money=(-loss)*volume;g_records[n].pending=true;
   Emit(s,"ORDER","OBSERVATION","volume="+DoubleToString(volume,8)+" risk_budget="+DoubleToString(budget,2));
   bool sent=OrderSend(request,result);
   g_records[n].entry_order_ticket=result.order;
   if(!sent || (result.retcode!=TRADE_RETCODE_DONE && result.retcode!=TRADE_RETCODE_DONE_PARTIAL && result.retcode!=TRADE_RETCODE_PLACED))
     {s.entry_status="ORDER_REJECTED";s.skip_reason="ORDER_SEND "+IntegerToString((int)result.retcode)+" "+result.comment;
      g_records[n].pending=false;g_engine.MarkOrderSubmitted(s.setup_id,false,TimeCurrent());
      Emit(s,"SKIP","EXCLUSION",s.skip_reason);g_records[n].setup=s;}
   Screenshot(s,"ORDER");
  }
void Drain()
  {
   W33Event events[];g_engine.Drain(events);
   for(int i=0;i<ArraySize(events);i++)
     {
      ulong orderKey=++g_knowledge_order;
      if(events[i].event_type=="SIGNAL")HandleSignal(events[i]);
      else {MergeExecution(events[i].setup);Publish(events[i]);
         ArmOppositeExit(events[i],orderKey);
         if(events[i].event_type=="INVALIDATE" || events[i].event_type=="SKIP")Screenshot(events[i].setup,events[i].event_type);}
     }
  }
void FeedClosed()
  {
   // Merge every newly closed TF bar by close time. No old LTF replay against new upper anchors.
   MqlRates pending[];ENUM_TIMEFRAMES periods[];
   datetime now=TimeCurrent();
   for(int f=0;f<4;f++)
     {
      datetime current=iTime(_Symbol,g_frames[f],0);if(current==0 || current==g_lastOpen[f])continue;
      MqlRates bars[];int copied=CopyRates(_Symbol,g_frames[f],g_lastOpen[f],now,bars);
      if(copied<0)continue;
      for(int b=0;b<copied;b++)if(bars[b].time>=g_lastOpen[f] && bars[b].time+PeriodSeconds(g_frames[f])<=now)
        {int n=ArraySize(pending);ArrayResize(pending,n+1);ArrayResize(periods,n+1);pending[n]=bars[b];periods[n]=g_frames[f];}
      g_lastOpen[f]=current;
     }
   int n=ArraySize(pending);
   W33SortClosedBars(pending,periods);
   for(int i=0;i<n;i++)
     {
      bool accepted=g_engine.Feed(periods[i],pending[i],now);
      if(accepted)g_prior.ClosedBar(periods[i],pending[i],now);
      if(accepted && periods[i]==g_upper)g_ledger.WriteUpperBar(_Symbol,g_upper,pending[i],now);
      if(accepted && periods[i]==g_lower)
        {g_chop.AcceptedLowerBar(pending[i].time);g_ledger.WriteLowerBar(_Symbol,g_lower,pending[i],now);}
      Drain();
     }
  }
void Panel()
  {
   W33Setup a,b;g_engine.GetActive(1,a);g_engine.GetActive(-1,b);
   string text="Wave33 v1 | "+_Symbol+" "+EnumToString(g_upper)+" x "+EnumToString(g_lower)+" | orders="+(InpEnableTesterOrders?"TESTER ON":"OFF")+"\n";
   text+="LONG "+W33StateName(a.state)+" "+a.setup_id+"\nSHORT "+W33StateName(b.state)+" "+b.setup_id+"\n";
   text+="Last "+g_last.setup_id+" | "+g_last.entry_status+"\nW1 "+W33Time(g_last.wave1_start_time)+" @"+DoubleToString(g_last.wave1_start_price,_Digits)+" -> "+DoubleToString(g_last.wave1_peak_price,_Digits)+"\n";
   text+="Peak located "+W33Time(g_last.wave1_peak_time)+" | known "+W33Time(g_last.wave1_peak_known_at)+"\n";
   text+="Fib "+DoubleToString(g_last.retracement_ratio*100,1)+"% | trigger "+DoubleToString(g_last.trigger_line_price,_Digits)+"\n";
   text+="Initial risk "+DoubleToString(g_last.risk_points,1)+" pt | no fixed TP | hold "+DoubleToString(InpMaxHoldHours,1)+"h | W1 room "+DoubleToString(g_last.wave1_room_r,2)+"R\n";
   text+="Candidate "+W33Time(g_last.candidate_detected_at)+"\nSignal "+W33Time(g_last.signal_at)+" | known "+W33Time(g_last.signal_known_at)+"\n";
   text+="Order "+W33Time(g_last.order_sent_at)+" | fill "+W33Time(g_last.fill_at)+"\nH1 "+g_last.h1_direction+"\nLast skip "+g_lastReason;
   g_display.Panel(text);
  }
bool Config()
  {
   int file=FileOpen(g_tag+"_config.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ';',CP_UTF8);
   if(file==INVALID_HANDLE){Print("Wave33 INIT_CONFIG_OPEN_FAILED symbol=",_Symbol," tag=",g_tag," error=",GetLastError());return false;}
   FileWrite(file,"parameter","value");
   FileWrite(file,"version","1.0");FileWrite(file,"ea_version","1.90");FileWrite(file,"symbol",_Symbol);FileWrite(file,"upper_tf",EnumToString(g_upper));FileWrite(file,"lower_tf",EnumToString(g_lower));
   FileWrite(file,"resolved_run_tag",g_tag);
   FileWrite(file,"chop_diagnostic",InpChopDiagnostic);FileWrite(file,"chop_labels",InpChopLabels);
   FileWrite(file,"skip_choppy_wave1",InpSkipChoppyWave1);
   FileWrite(file,"chop_effective_observation",InpChopDiagnostic || InpSkipChoppyWave1);
   FileWrite(file,"chop_observation_policy","filter ON forces causal pivot observation and CSV even if diagnostic OFF");
   FileWrite(file,"chop_formula_version",W33_CHOP_VERSION);FileWrite(file,"chop_threshold",W33_CHOP_THRESHOLD);
   FileWrite(file,"chop_policy","optional entry-only filter; known lower pivots strictly inside fixed W1 anchors; sum adverse moves / positive directional span");
   FileWrite(file,"chop_formula","sum(max(0,-direction*(path[i]-path[i-1]))) / (direction*(peak-start)); normalize same-side interior pivots to most extreme; fixed anchors");
   FileWrite(file,"chop_exclusion_policy","enabled AND status CHOPPY only; ratio >= fixed 0.5; SIGNAL prefix before any submission or ORDER_DISABLED; canonical SKIP CHOPPY_WAVE1; release unsubmitted lane");
   FileWrite(file,"chop_missing_policy","UNAVAILABLE allows entry with explicit measurement reason; numeric zero is never substituted for missing evidence");
   FileWrite(file,"prior_context",InpPriorContext);FileWrite(file,"skip_prior_level_retest",InpSkipPriorLevelRetest);
   FileWrite(file,"prior_context_band_fraction",InpPriorContextBandFraction);FileWrite(file,"prior_context_formula",W33_PRIOR_CONTEXT_VERSION);
   FileWrite(file,"prior_context_effective_observation",InpPriorContext || InpSkipPriorLevelRetest);
   FileWrite(file,"prior_context_source_policy","published M15/H1 HIGH for LONG or LOW for SHORT; source before W1 start; known by signal; all prospective observed history; no manual levels");
   FileWrite(file,"prior_context_band_policy","halfwidth=fraction*fixed directional W1 span; peak inside inclusive; executable entry not beyond outer edge; final TP strictly beyond; latest accepted source-TF close not beyond");
   FileWrite(file,"prior_context_selection_policy","evaluate all; blocking first, near next, closest peak next; ties H1 then newer source; same-move M15/H1 are not independent touches");
   FileWrite(file,"prior_context_missing_policy","UNAVAILABLE allows with explicit reason; no level allows; filter ON forces observation even diagnostic OFF; invalid fraction rejects init");
   FileWrite(file,"prior_context_exclusion_policy","optional entry-only PRIOR_LEVEL_RETEST; pre-submission skip and release; chop exclusion retains precedence; default OFF; not completed double-top prediction");
   FileWrite(file,"allow_tester_batch_runs",InpAllowTesterBatchRuns);FileWrite(file,"optimization",MQLInfoInteger(MQL_OPTIMIZATION));
   FileWrite(file,"effective_draw",g_effective_draw);FileWrite(file,"input_hash",g_input_hash);
   FileWrite(file,"batch_namespace",MQLInfoInteger(MQL_OPTIMIZATION)?"symbol/context hash + exclusive persistent claim":"single-run tag");
   FileWrite(file,"swing_left",InpSwingLeft);FileWrite(file,"swing_right",InpSwingRight);FileWrite(file,"fib_min",InpFibMin);FileWrite(file,"fib_max",InpFibMax);
   FileWrite(file,"require_fib_touch",InpRequireFibTouch);FileWrite(file,"reject_deep_fib",InpRejectDeepFib);FileWrite(file,"timeout_upper_bars",InpTimeoutUpperBars);
   FileWrite(file,"reject_deep_fib_close",InpRejectDeepFibClose);
   FileWrite(file,"extend_wave1_before_fib",InpExtendWave1BeforeFib);
   FileWrite(file,"wave1_extension_assumption","active pre-signal only; before first minimum Fib penetration; closed upper new extreme; re-confirm upper pivot; fixed origin; no revival");
   FileWrite(file,"wave1_extension_ambiguity","same upper candle new extreme and old minimum retracement: lock without extension; OHLC order unknown");
   FileWrite(file,"wave1_extension_exit_identity","extension confirmation has separate event type; never a fresh opposite W1 exit source");
   FileWrite(file,"deep_fib_close_basis","upper timeframe closed candle; strict beyond configured fib_max; wick alone allowed; pre-signal only");
   FileWrite(file,"equal_close_feed_order","H1 M15 M5 M1; upper before lower, including backlog");
   FileWrite(file,"strict_wave_lifecycle",InpStrictWaveLifecycle);FileWrite(file,"initial_move_boundary","strict lower close beyond fixed W1 after prior qualifying pullback; same-bar valid signal allowed");
   FileWrite(file,"lower_wave2_binding","countertrend extreme price matches current deepest W2 within half a point; equal-price retest allowed");
   FileWrite(file,"lower_recognition_mode",EnumToString(InpLowerRecognition));
   FileWrite(file,"simple_reaction_assumption","confirmed deepest W2 then first confirmed opposite reaction pivot; fresh close break, no invented lower wave count");
   FileWrite(file,"minimum_wave1_room_r",InpMinWave1RoomR);FileWrite(file,"wave1_room_assumption","signed executable quote to fixed W1 endpoint divided by rounded structural stop risk; zero disables");
   FileWrite(file,"obstacle_source_policy","all known swing highs and lows; source trace and W1 room separate; no claim of current importance");
   FileWrite(file,"trigger_mode",EnumToString(InpTriggerMode));FileWrite(file,"obstacle_mode",EnumToString(InpObstacleMode));FileWrite(file,"reward_r",InpRewardR);
   FileWrite(file,"cancel_connected_opposite",InpCancelConnectedOpposite);
   FileWrite(file,"skip_both_connected_wave1",InpSkipBothConnectedWave1);
   FileWrite(file,"connected_pair_policy","both ON overrides old-only flag; existing shared-endpoint predicate; both unordered only; invalidate each once and release both lanes; no future evidence");
   FileWrite(file,"connected_pair_position_policy","submitted/open prior trade protected; reverse candidate continues; existing post-fill opposite confirmation profit exit unchanged");
   FileWrite(file,"connected_opposite_policy","new accepted opposite W1_BREAK shares the old fixed endpoint; strictly older unsubmitted candidate only; submitted/open positions preserved");
   FileWrite(file,"extend_tp_to_wave1",InpExtendTPToWave1);FileWrite(file,"tp_wave1_buffer_points",InpTPWave1BufferPoints);
   FileWrite(file,"daytrade_mode","NO_FIXED_TP_NO_PARTIAL_CLOSE");
   FileWrite(file,"step_sl",InpStepSL);FileWrite(file,"step_start_r",InpStepStartR);FileWrite(file,"step_size_r",InpStepSizeR);FileWrite(file,"step_lag_r",InpStepLagR);
   FileWrite(file,"max_hold_hours",InpMaxHoldHours);FileWrite(file,"close_before_weekend",InpCloseBeforeWeekend);FileWrite(file,"weekend_buffer_minutes",InpWeekendBufferMinutes);
   FileWrite(file,"time_exit_policy","FIRST actual fill millisecond + elapsed hours; first executable tick; weekly session gap >=24h closes before session end; holidays may be unavailable");
   FileWrite(file,"fixed_tp","NONE; legacy RR/W1 targets diagnostic only");
   FileWrite(file,"scale_out",InpScaleOut);FileWrite(file,"scale_out_policy","fixed known RR/W1-inside near target closes floor(initial filled volume * 0.5 / step); confirmed half THEN BE; residual at far target; explicit obstacle cap first; OFF legacy extension");
   FileWrite(file,"scale_out_small_volume","never increase volume; if two valid legs unavailable, full close at near target; log fallback");
   FileWrite(file,"scale_out_break_even","actual weighted entry, favorable tick if off grid; never loosen SL; broker stops/freeze may defer; price break-even excludes fees; confirmed unique deals only");
   FileWrite(file,"tp_wave1_policy","REFERENCE_ONLY; no fixed TP is sent; intended_rr/legacy W1 reference are not executable exit targets");
   FileWrite(file,"risk_percent",InpRiskPercent);FileWrite(file,"sl_extra_points",InpSLExtraPoints);FileWrite(file,"tester_orders",InpEnableTesterOrders);
   FileWrite(file,"exit_on_opposite_wave1",InpExitOnOppositeWave1);FileWrite(file,"audit_opposite_exit_ticks",InpAuditOppositeExitTicks);
   FileWrite(file,"opposite_exit_trigger","WAVE1_PEAK_CONFIRMED known after actual fill; same upper/lower pair; sticky first opposite source");
   FileWrite(file,"opposite_exit_profit_basis","current executable bid/ask profit + booked cash + remaining swap - estimated exit commission/fee; strict >0; no SL/TP change");
   FileWrite(file,"opposite_exit_fee_estimate","remaining volume times observed negative entry commission+fee per filled volume; future fee/slippage unknown, actual net not guaranteed");
   FileWrite(file,"magic",InpMagic);FileWrite(file,"deviation_points",InpDeviationPoints);FileWrite(file,"manual_levels_display_only",InpManualLevels);
   FileWrite(file,"draw",InpDraw);FileWrite(file,"keep_objects",InpKeepObjects);FileWrite(file,"screenshots",InpScreenshots);FileWrite(file,"screenshot_limit",InpScreenshotLimit);
   FileWrite(file,"show_info_panel",InpShowInfoPanel);FileWrite(file,"diagnostic_labels",InpDiagnosticLabels);FileWrite(file,"show_swing_paths",InpShowSwingPaths);
   FileWrite(file,"readable_labels",InpReadableLabels);FileWrite(file,"label_layout_policy","display only; compact captions, full provenance in tips/logs; collision spacing from original anchors; finite leaders");
   FileWrite(file,"tester",MQLInfoInteger(MQL_TESTER));FileWrite(file,"visual",MQLInfoInteger(MQL_VISUAL_MODE));FileWrite(file,"terminal_build",TerminalInfoInteger(TERMINAL_BUILD));
   FileWrite(file,"chart_tf",EnumToString((ENUM_TIMEFRAMES)_Period));FileWrite(file,"point",_Point);FileWrite(file,"tick_size",SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE));
   FileWrite(file,"account_currency",AccountInfoString(ACCOUNT_CURRENCY));FileWrite(file,"symbol_currency_profit",SymbolInfoString(_Symbol,SYMBOL_CURRENCY_PROFIT));
   FileWrite(file,"symbol_calc_mode",SymbolInfoInteger(_Symbol,SYMBOL_TRADE_CALC_MODE));
   FileWrite(file,"volume_min",SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN));FileWrite(file,"volume_step",SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP));FileWrite(file,"contract_size",SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE));
   FileWrite(file,"stops_level",SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL));FileWrite(file,"freeze_level",SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL));
   FileClose(file);return true;
  }
int OnInit()
  {
   if(InpSwingLeft<1 || InpSwingRight<1 || InpFibMin<=0 || InpFibMax<=InpFibMin || InpFibMax>=1 || InpRewardR<=0 || InpRiskPercent<=0 || InpRiskPercent>100 || InpTimeoutUpperBars<1 || InpSLExtraPoints<0 || InpMinWave1RoomR<0 || !MathIsValidNumber(InpTPWave1BufferPoints) || InpTPWave1BufferPoints<0 || !MathIsValidNumber(InpPriorContextBandFraction) || InpPriorContextBandFraction<0 || InpPriorContextBandFraction>1)
     {Print("Wave33 INIT_PARAMETERS_INCORRECT: check swings, Fib, RR, risk, timeout and SL/room inputs.");return INIT_PARAMETERS_INCORRECT;}
   g_day_config.enable_step=InpStepSL;g_day_config.start_r=InpStepStartR;g_day_config.step_r=InpStepSizeR;g_day_config.lag_r=InpStepLagR;g_day_config.max_hold_hours=InpMaxHoldHours;
   if(!W33DayTradeConfigValid(g_day_config) || InpScaleOut || InpObstacleMode!=DISPLAY_ONLY || InpSkipPriorLevelRetest || InpWeekendBufferMinutes<1 || InpWeekendBufferMinutes>120)
     {Print("Wave33 DayTrade invalid: maxHold (0,24], valid steps, scaleOut OFF, obstacle DISPLAY_ONLY, prior skip OFF, weekend buffer 1..120");return INIT_PARAMETERS_INCORRECT;}
   bool optimizing=(bool)MQLInfoInteger(MQL_OPTIMIZATION);
   if(optimizing && !InpAllowTesterBatchRuns)
     {Print("Wave33 INIT_BATCH_DISABLED: Market Watch all-symbol runs also use optimization mode. Set InpAllowTesterBatchRuns=true.");return INIT_FAILED;}
   g_tag=InpRunTag;if(g_tag=="")return INIT_PARAMETERS_INCORRECT;
   StringReplace(g_tag,"/","_");StringReplace(g_tag,"\\","_");StringReplace(g_tag,":","_");
   g_input_hash=RunInputHash();
   if(optimizing)
     {
      string requested=g_tag,problem="";
      string context=W33Hash(TerminalInfoString(TERMINAL_DATA_PATH)+"|"+g_input_hash+"|"+EnumToString((ENUM_TIMEFRAMES)_Period));
      if(!W33ReserveBatchRunTag(requested,_Symbol,context,g_tag,g_run_claim,problem))
        {Print("Wave33 INIT_BATCH_TAG_FAILED symbol=",_Symbol," ",problem);return INIT_FAILED;}
     }
   else if(FileIsExist(g_tag+"_events.csv",FILE_COMMON))
      g_tag+="_"+IntegerToString((long)TimeLocal())+"_"+IntegerToString((long)GetTickCount());
   Print("Wave33 resolved run tag: ",g_tag);
   g_upper=InpPattern==M15_M5?PERIOD_M15:PERIOD_M5;g_lower=InpPattern==M15_M5?PERIOD_M5:PERIOD_M1;
   g_frames[0]=PERIOD_H1;g_frames[1]=PERIOD_M15;g_frames[2]=PERIOD_M5;g_frames[3]=PERIOD_M1;
   for(int i=0;i<4;i++)
     {
      ResetLastError();g_lastOpen[i]=iTime(_Symbol,g_frames[i],0);
      if(g_lastOpen[i]==0){Print("Wave33 INIT_HISTORY_NOT_READY symbol=",_Symbol," tf=",EnumToString(g_frames[i])," error=",GetLastError());return INIT_FAILED;}
     }
   g_engine.Configure(g_upper,g_lower,InpSwingLeft,InpSwingRight,InpFibMin,InpFibMax,InpTimeoutUpperBars,InpRejectDeepFib,InpRequireFibTouch);
   g_engine.Reset(_Symbol);g_engine.SetTriggerMode(InpTriggerMode);g_engine.SetPoint(_Point);g_engine.SetLifecyclePolicy(InpStrictWaveLifecycle);
   g_engine.SetLowerRecognition(InpLowerRecognition);
   g_engine.SetDeepFibClosePolicy(InpRejectDeepFibClose);
   g_engine.SetWave1ExtensionPolicy(InpExtendWave1BeforeFib);
   g_engine.SetConnectedOppositePolicy(InpCancelConnectedOpposite);
   g_engine.SetConnectedPairPolicy(InpSkipBothConnectedWave1);
   g_effective_draw=InpDraw && !optimizing;
   ResetLastError();
   if(!g_ledger.Open(g_tag)){Print("Wave33 INIT_LEDGER_OPEN_FAILED symbol=",_Symbol," tag=",g_tag," error=",GetLastError());return INIT_FAILED;}
   if(!Config())return INIT_FAILED;
   if(InpAuditOppositeExitTicks)
     {
      g_exit_tick_file=FileOpen(g_tag+"_opposite_ticks.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,';',CP_UTF8);
      if(g_exit_tick_file==INVALID_HANDLE){Print("Wave33 INIT_TICK_AUDIT_OPEN_FAILED symbol=",_Symbol," tag=",g_tag," error=",GetLastError());g_ledger.Close();return INIT_FAILED;}
      FileWrite(g_exit_tick_file,"setup_id","known_at","tick_time_msc","tick_order","knowledge_order","position_ticket","position_id","bid","ask","volume",
         "quote_profit","booked_cash","remaining_swap","entry_cost_rate","estimated_exit_cost","net_estimate","request_pending","attempts","status","opposite_setup_id");
     }
   g_prefix="W33_"+W33Hash(g_tag)+"_"+IntegerToString((int)InpPattern)+"_";
   g_display.Init(g_prefix,g_effective_draw);ZeroMemory(g_last);
   g_display.ConfigureReadability(InpReadableLabels);
   if(!g_chop.Open(g_tag,g_prefix,g_lower,InpChopDiagnostic,g_effective_draw && InpChopLabels,InpSkipChoppyWave1))
     {Print("Wave33 INIT_CHOP_CSV_OPEN_FAILED tag=",g_tag," error=",GetLastError());g_ledger.Close();return INIT_FAILED;}
   if(!g_prior.Open(g_tag,g_prefix,InpPriorContext,g_effective_draw,InpSkipPriorLevelRetest,InpPriorContextBandFraction))
     {Print("Wave33 INIT_CONTEXT_CSV_OPEN_FAILED tag=",g_tag," error=",GetLastError());g_chop.Close();g_ledger.Close();return INIT_FAILED;}
   if(!ScaleOutOpen()){Print("Wave33 INIT_SCALEOUT_OR_RAW_DEALS_OPEN_FAILED tag=",g_tag," error=",GetLastError());return INIT_FAILED;}
   if(!DayTradeOpen())return INIT_FAILED;
   g_display.SetFrames(g_upper,g_lower);
   g_display.ConfigureVisuals(InpShowInfoPanel,InpDiagnosticLabels,InpShowSwingPaths);g_display.SetTriggerMode(InpTriggerMode);
   string levels[];int count=StringSplit(InpManualLevels,';',levels);
   for(int j=0;g_effective_draw && j<count;j++)
     {
      double p=StringToDouble(levels[j]);if(p<=0)continue;
      string name=g_prefix+"MANUAL_DISPLAY_ONLY_"+IntegerToString(j);
      ObjectCreate(0,name,OBJ_TREND,0,TimeCurrent(),p,TimeCurrent()+12*PeriodSeconds(g_lower),p);ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);ObjectSetInteger(0,name,OBJPROP_COLOR,clrViolet);
      ObjectSetString(0,name,OBJPROP_TOOLTIP,"MANUAL DISPLAY ONLY known since "+W33Time(TimeCurrent()));
     }
   Print("Wave33 starts without historical setup replay; warm-up pivots accrue prospectively. Tester orders ",InpEnableTesterOrders," visual ",MQLInfoInteger(MQL_VISUAL_MODE));
   W33Setup initial;ZeroMemory(initial);initial.symbol=_Symbol;initial.upper_tf=g_upper;initial.lower_tf=g_lower;initial.state=SEARCH_STRUCTURE;
   Emit(initial,"INIT","OBSERVATION","SEARCH_STRUCTURE | prospective warmup | max(stops,freeze) SL buffer | manual display only");
   g_ready=true;return INIT_SUCCEEDED;
  }
void OnTick()
  {
   if(!g_ready)return;g_tick_order++;DayTradeReconcile();ManageDayTradeTimeExits();
   FeedClosed();ManageOppositeExits();ManageDayTradeStops();
   static datetime last=0;if(last!=TimeCurrent()){last=TimeCurrent();Panel();g_display.Layout();}
  }
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {if(g_ready && id==CHARTEVENT_CHART_CHANGE)g_display.Layout(true);}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(g_ready && trans.type==TRADE_TRANSACTION_REQUEST && request.magic==InpMagic && request.symbol==_Symbol)
     {
      HandleScaleOutRequest(request,result);DayTradeRequestResult(request,result);
      for(int i=0;i<ArraySize(g_records);i++)
         if(g_records[i].opposite.request_pending && result.request_id==g_records[i].close_request_id)
           {
            if(!AcceptedDeal(result.retcode))CloseOppositeRejected(i,"TRADE_TRANSACTION_REQUEST "+IntegerToString((int)result.retcode)+" "+result.comment);
            else if(result.order>0){g_records[i].close_order_ticket=result.order;g_records[i].setup.opposite_close_order_ticket=result.order;}
           }
     }
   if(!g_ready || trans.type!=TRADE_TRANSACTION_DEAL_ADD || !HistoryDealSelect(trans.deal))return;
   if(SeenExecutionDeal(trans.deal))return;
   if(HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=_Symbol || (ulong)HistoryDealGetInteger(trans.deal,DEAL_MAGIC)!=InpMagic)return;
   ulong pos=(ulong)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);
   ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   int index=-1;
   for(int i=0;i<ArraySize(g_records);i++)if(g_records[i].position_id==pos && pos>0){index=i;break;}
   if(index<0 && entry==DEAL_ENTRY_IN)
      for(int i=ArraySize(g_records)-1;i>=0;i--)if(g_records[i].pending){index=i;break;}
   if(index<0)return;
   RememberExecutionDeal(trans.deal);WriteExecutionDeal(index,trans.deal);
   W33Setup s=g_records[index].setup;
   double price=HistoryDealGetDouble(trans.deal,DEAL_PRICE),volume=HistoryDealGetDouble(trans.deal,DEAL_VOLUME);
   datetime when=(datetime)HistoryDealGetInteger(trans.deal,DEAL_TIME);
   g_records[index].net_cash+=HistoryDealGetDouble(trans.deal,DEAL_PROFIT)+HistoryDealGetDouble(trans.deal,DEAL_COMMISSION)+HistoryDealGetDouble(trans.deal,DEAL_SWAP)+HistoryDealGetDouble(trans.deal,DEAL_FEE);
   if(entry==DEAL_ENTRY_IN)
     {
      if(g_records[index].fill_order_key==0)g_records[index].fill_order_key=++g_knowledge_order;
      g_records[index].entry_costs+=MathMax(0,-HistoryDealGetDouble(trans.deal,DEAL_COMMISSION))+MathMax(0,-HistoryDealGetDouble(trans.deal,DEAL_FEE));
      g_records[index].position_id=pos;double prior=g_records[index].filled_volume;
      g_records[index].entry_order_ticket=(ulong)HistoryDealGetInteger(trans.deal,DEAL_ORDER);
      s.entry_price=(s.entry_price*prior+price*volume)/(prior+volume);g_records[index].filled_volume+=volume;
      long fillMSC=(long)HistoryDealGetInteger(trans.deal,DEAL_TIME_MSC);
      if(g_records[index].day_first_fill_msc==0 || fillMSC<g_records[index].day_first_fill_msc)g_records[index].day_first_fill_msc=fillMSC;
      s.fill_at=(datetime)(g_records[index].day_first_fill_msc/1000);s.risk_points=MathAbs(s.entry_price-s.sl_price)/_Point;s.entry_status="FILLED";s.state=POSITION_TRACKING;
      s.actual_rr=0; // No fixed TP in this EA.
      // A fill may differ from the checked executable quote. Record the actual
      // room without pretending an already-filled order was rejected.
      bool preOrderRejected=s.wave1_room_rejected;
      bool fillRoom=W33CheckWave1Room(s,InpMinWave1RoomR);s.wave1_room_rejected=preOrderRejected;
      if(!fillRoom)Emit(s,"FILL_ROOM_DRIFT","MEASUREMENT","actual fill room below pre-order minimum");
      double risk=0;
      if(OrderCalcProfit(s.direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,g_records[index].filled_volume,s.entry_price,g_records[index].initial_sl_price,risk))
         g_records[index].initial_risk_money=MathAbs(risk);
      else Emit(s,"RISK_RECALC_FAILED","MEASUREMENT","fill risk uses pre-order estimate error="+IntegerToString(GetLastError()));
      s.execution_net_cash=g_records[index].net_cash;s.execution_initial_risk_money=g_records[index].initial_risk_money;s.execution_position_id=pos;
      g_records[index].pending=false;
      g_engine.MarkExecution(s.setup_id,true,TimeCurrent());Emit(s,"FILL","OBSERVATION","position filled");
     }
   else if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY)
     {
      g_records[index].exit_volume+=volume;
      bool closed=g_records[index].exit_volume>=g_records[index].filled_volume-1e-8;
      s.exit_at=when;s.exit_price=price;s.exit_deal_reason=EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal,DEAL_REASON));
      ulong dealOrder=(ulong)HistoryDealGetInteger(trans.deal,DEAL_ORDER);
      bool scaleDeal=AccountScaleOutDeal(index,trans.deal,volume);
      // Transaction delivery order is not guaranteed. A deal can arrive before
      // the REQUEST callback that supplies a previously unassigned order ticket.
      if(g_records[index].opposite.request_pending && g_records[index].close_order_ticket==0 &&
         (StringFind(HistoryDealGetString(trans.deal,DEAL_COMMENT),"W33_OPPOSITE_W1_PROFIT")==0 ||
          StringFind(HistoryOrderGetString(dealOrder,ORDER_COMMENT),"W33_OPPOSITE_W1_PROFIT")==0))
         g_records[index].close_order_ticket=dealOrder;
      bool oppositeDeal=g_records[index].close_order_ticket>0 && dealOrder==g_records[index].close_order_ticket;
      bool dayDeal=DayTradeAccountCloseDeal(index,trans.deal,dealOrder);
      s.exit_reason=dayDeal?g_records[index].day_close_reason:(oppositeDeal?"OPPOSITE_WAVE1_PROFIT":(scaleDeal?(g_records[index].scale.single_fallback?"SCALEOUT_SINGLE_TP1":"SCALEOUT_TP1"):s.exit_deal_reason));
      s.realized_r=g_records[index].initial_risk_money>0?g_records[index].net_cash/g_records[index].initial_risk_money:0;
      s.execution_net_cash=g_records[index].net_cash;s.execution_initial_risk_money=g_records[index].initial_risk_money;s.execution_position_id=pos;
      s.opposite_close_order_ticket=g_records[index].close_order_ticket;
      s.entry_status=closed?"CLOSED":"PARTIAL_EXIT";
      Emit(s,closed?"EXIT":"PARTIAL_EXIT","OBSERVATION",s.exit_reason);
      g_records[index].setup=s;
      if(scaleDeal)ScaleOutEvent(index,"SCALEOUT_TP1_FILLED","deal="+(string)trans.deal+" volume="+DoubleToString(volume,8)+" confirmed="+DoubleToString(g_records[index].scale.confirmed_closed_volume,8));
      else if(closed && InpScaleOut && g_records[index].scale.planned && g_records[index].scale.confirmed_closed_volume==0 && !g_records[index].scale.single_fallback && s.exit_deal_reason=="DEAL_REASON_TP")
         ScaleOutEvent(index,"SCALEOUT_FINAL_BEFORE_TP1","broker TP filled before half-close confirmation; no invented intermediate execution");
      if(closed){g_engine.MarkExecution(s.setup_id,false,TimeCurrent());W33ResolveOppositeExitRequest(g_records[index].opposite,false);}
     }
   // MarkExecution queues observations at the actual callback time. Publish
   // them now: a fast SL/TP may arrive before the next closed candle, and
   // deferring the fill acknowledgement would backdate rows after that EXIT.
   g_records[index].setup=s;DayTradeAfterDeal(index,entry);Drain();Panel();g_display.Layout();
  }
void OnDeinit(const int reason)
  {
   if(!g_ready)
     {
      DayTradeClose();ScaleOutCloseFiles();
      g_prior.Close();g_chop.Close();g_ledger.Close();if(g_exit_tick_file!=INVALID_HANDLE){FileClose(g_exit_tick_file);g_exit_tick_file=INVALID_HANDLE;}
      W33ReleaseBatchRunTag(g_run_claim);return;
     }
   Drain();
   for(int d=-1;d<=1;d+=2)
     {
      W33Setup s;g_engine.GetActive(d,s);if(s.setup_id=="" || !s.active)continue;
      MergeExecution(s);Emit(s,"TEST_END","OBSERVATION","CENSORED_AT_STOP reason="+IntegerToString(reason));
     }
   g_prior.Close();g_chop.Close();g_ledger.Close();if(g_exit_tick_file!=INVALID_HANDLE){FileClose(g_exit_tick_file);g_exit_tick_file=INVALID_HANDLE;}
   DayTradeClose();ScaleOutCloseFiles();
   W33ReleaseBatchRunTag(g_run_claim);
   if(!InpKeepObjects){g_prior.Clear();g_chop.Clear();g_display.Clear();}ChartRedraw();g_ready=false;
  }
