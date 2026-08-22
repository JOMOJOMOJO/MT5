#property copyright "OpenAI"
#property version   "1.00"
#property strict

#include "..\Include\TickShockStateMachine.mqh"

enum ENUM_TS_RUN_MODE
  {
   EVENT_STUDY = 0,
   BACKTEST_TRADE = 1,
   LIVE_TRADE = 2
  };

enum ENUM_TS_LOT_MODE
  {
   RISK_PERCENT = 0,
   FIXED_LOT = 1
  };

input ENUM_TS_RUN_MODE InpRunMode = EVENT_STUDY;
input bool InpEnableTrading = false;
input string InpSymbols = "EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD,USDCHF";
input int InpShockWindowMs = 1000;
input int InpBaselineMinutes = 15;
input int InpBaselineExcludeMs = 2000;
input int InpMinBaselineSamples = 300;
input double InpShockPercentile = 99.5;
input double InpMinRobustZ = 3.5;
input double InpMinEfficiency = 0.65;
input double InpMinMoveSpreadRatio = 4.0;
input double InpMinTickIntensityRatio = 1.5;
input double InpMaxSpreadMedianRatio = 1.5;
input int InpMaxQuoteAgeMs = 1500;
input int InpBurstQuietMs = 300;
input int InpBurstMaxMs = 3000;
input double InpPullbackMinPct = 15.0;
input double InpPullbackMaxPct = 35.0;
input double InpContinuationInvalidPct = 50.0;
input int InpPullbackWaitMs = 10000;
input int InpReaccelerationConfirmTicks = 2;
input double InpRewardRisk = 1.2;
input int InpMaxHoldSeconds = 120;
input int InpSymbolCooldownSeconds = 60;
input int InpGlobalCooldownSeconds = 5;
input long InpMagicNumber = 202608200101;
input string InpRolloverBlockStart = "23:55";
input string InpRolloverBlockEnd = "00:10";
input int InpTokyoStartHour = 0;
input int InpTokyoEndHour = 9;
input int InpLondonStartHour = 8;
input int InpLondonEndHour = 17;
input int InpNewYorkStartHour = 13;
input int InpNewYorkEndHour = 22;
input ENUM_TS_LOT_MODE InpLotMode = RISK_PERCENT;
input double InpRiskPercent = 0.25;
input double InpFixedLot = 0.01;
input double InpDailyLossLimitR = 3.0;
input int InpMaxTradesPerDay = 10;
input int InpMaxSlippagePoints = 20;
input double InpExecutionRiskTolerancePct = 10.0;
input double InpCommissionPerLotRoundTurn = 0.0;
input string InpRunId = "baseline";
input string InpLogFolder = "tick_shock_scalper";
input bool InpEnableDebug = false;
input string InpDebugSymbol = "EURUSD";
input datetime InpDebugStart = D'1970.01.01 00:00:00';
input datetime InpDebugEnd = D'2099.12.31 23:59:59';
input int InpDebugMaxMessages = 200;

#define TS_SECOND_CAPACITY 902
#define TS_TICK_CAPACITY 4096
#define TS_TICK_RETENTION_MS 5000
#define TS_MAX_ACTIVE_EVENTS 64
#define TS_CHECKPOINT_COUNT 6
#define TS_STRESS_COUNT 12
#define TS_MAX_COPY_TICKS 8192
#define TS_PRE_SKIP_COUNT 9
#define TS_SESSION_COUNT 5
#define TS_ALIGNMENT_COUNT 7

const string TS_STRATEGY_NAME = "ExpectedValue_MultiCurrency_TickShockScalper";
const int TS_CHECKPOINT_SECONDS[TS_CHECKPOINT_COUNT] = {5,10,20,30,60,120};
const int TS_DELAY_MS[TS_STRESS_COUNT] = {0,0,0,100,100,100,250,250,250,500,500,500};
const double TS_SPREAD_MULT[TS_STRESS_COUNT] = {1.0,1.25,1.5,1.0,1.25,1.5,1.0,1.25,1.5,1.0,1.25,1.5};

struct TSShortTick
  {
   long time_msc;
   double bid;
   double ask;
   double mid;
  };

struct TSSecondSample
  {
   long end_msc;
   double move;
   int tick_count;
   double spread;
  };

struct TSSymbolContext
  {
   string symbol;
   int digits;
   double point;
   double tick_size;
   double tick_value;
   double volume_min;
   double volume_max;
   double volume_step;
   int stops_level;
   int freeze_level;
   long last_time_msc;
   int processed_at_last_msc;
   TSShortTick ticks[];
   int tick_head;
   int tick_count;
   TSSecondSample seconds[];
   int second_head;
   int second_count;
   long bucket_second;
   double bucket_open;
   double bucket_close;
   double bucket_spread_sum;
   int bucket_ticks;
   TickShockMachine machine;
   int event_slot;
   long cooldown_until_msc;
   long last_fail_count_second;
   long last_shock_eval_msc;
   long last_raw_candidate_second;
   long baseline_cache_second;
   int baseline_samples;
   double baseline_percentile;
   double baseline_median_move;
   double baseline_mad_move;
   double baseline_median_ticks;
   double spread_median_5m;
   int ema20_m15;
   int ema50_m15;
   int ema20_h1;
   int ema50_h1;
   long ticks_processed;
   long duplicate_ticks_skipped;
   long raw_candidates;
   long events_detected;
   long bursts_frozen;
   long valid_pullbacks;
   long reacceleration_signals;
  };

struct TSShadowTrade
  {
   bool pending;
   bool active;
   bool finished;
   int direction;
   long due_msc;
   long entry_msc;
   long exit_msc;
   double entry;
   double sl;
   double tp;
   double risk;
   double result_r;
   string exit_reason;
  };

struct TSEventRecord
  {
   bool active;
   bool terminal;
   bool csv_written;
   int symbol_index;
   string event_id;
   string symbol;
   int direction;
   long detection_msc;
   long processing_msc;
   long decision_delay_ms;
   long burst_start_msc;
   long burst_end_msc;
   double start_mid;
   double initial_extreme;
   double burst_extreme;
   double burst_range;
   double move_250;
   double move_500;
   double move_1000;
   double move_2000;
   double percentile_threshold;
   double robust_z;
   double efficiency;
   int tick_count;
   double tick_intensity_ratio;
   double initial_spread;
   double spread_median;
   double move_spread_ratio;
   double max_retracement_pct;
   long pullback_msc;
   long reacceleration_msc;
   double pullback_extreme;
   string m15_trend;
   string h1_trend;
   string htf_alignment;
   string session;
   string news_label;
   bool continuation_eligible;
   double continuation_result_r;
   bool reversal_eligible;
   double reversal_result_r;
   double checkpoint_price[TS_CHECKPOINT_COUNT];
   double checkpoint_mfe[TS_CHECKPOINT_COUNT];
   double checkpoint_mae[TS_CHECKPOINT_COUNT];
   bool checkpoint_done[TS_CHECKPOINT_COUNT];
   double best_mid;
   double worst_mid;
   string final_status;
   string skip_reason;
   TSShadowTrade continuation;
   TSShadowTrade reversal;
   TSShadowTrade stress[TS_STRESS_COUNT];
  };

struct TSEntryCandidate
  {
   bool valid;
   int event_slot;
   int symbol_index;
   double score;
   long signal_msc;
   double signal_bid;
   double signal_ask;
  };

struct TSTradeRecord
  {
   bool active;
   bool entry_filled;
   string event_id;
   int event_slot;
   string symbol;
   int direction;
   long signal_msc;
   long request_msc;
   long fill_msc;
   long close_msc;
   long decision_delay_ms;
   long execution_delay_ms;
   double requested_price;
   double fill_price;
   double slippage;
   double initial_spread;
   double volume;
   double sl;
   double tp;
   double risk_distance;
   double risk_amount;
   double planned_rr;
   double close_price;
   double gross_profit;
   double commission;
   double swap;
   double net_profit;
   double gross_r;
   double net_r;
   ulong order_ticket;
   ulong position_id;
   ulong entry_deal;
   ulong exit_deal;
   uint order_retcode;
   int order_retcode_external;
   string exit_reason;
  };

struct TSAggregate
  {
   long count;
   long wins;
   long losses;
   long time_exits;
   double sum_r;
   double sum_wins_r;
   double sum_losses_r;
   double gross_positive_r;
   double gross_negative_r;
  };

TSSymbolContext g_symbols[];
TSEventRecord g_events[TS_MAX_ACTIVE_EVENTS];
TSTradeRecord g_trade;
long g_pre_skip[];
long g_skip_reason_count[];
string g_skip_reason_name[];
TSAggregate g_actual;
TSAggregate g_continuation_shadow;
TSAggregate g_reversal_shadow;
TSAggregate g_symbol_stats[];
TSAggregate g_symbol_continuation_shadow[];
TSAggregate g_symbol_reversal_shadow[];
TSAggregate g_session_stats[TS_SESSION_COUNT];
TSAggregate g_alignment_stats[TS_ALIGNMENT_COUNT];
TSAggregate g_session_continuation_shadow[TS_SESSION_COUNT];
TSAggregate g_session_reversal_shadow[TS_SESSION_COUNT];
TSAggregate g_alignment_continuation_shadow[TS_ALIGNMENT_COUNT];
TSAggregate g_alignment_reversal_shadow[TS_ALIGNMENT_COUNT];
long g_session_events[TS_SESSION_COUNT];
long g_session_bursts[TS_SESSION_COUNT];
long g_session_pullbacks[TS_SESSION_COUNT];
long g_session_reaccelerations[TS_SESSION_COUNT];
long g_alignment_events[TS_ALIGNMENT_COUNT];
long g_alignment_bursts[TS_ALIGNMENT_COUNT];
long g_alignment_pullbacks[TS_ALIGNMENT_COUNT];
long g_alignment_reaccelerations[TS_ALIGNMENT_COUNT];
long g_hold_histogram[121];
long g_raw_shock_candidates = 0;
long g_valid_shock_events = 0;
long g_valid_bursts = 0;
long g_valid_pullbacks = 0;
long g_reacceleration_signals = 0;
long g_total_ticks_processed = 0;
long g_event_rows = 0;
long g_trade_rows = 0;
long g_event_sequence = 0;
long g_global_cooldown_until_msc = 0;
int g_day_key = 0;
int g_daily_trades = 0;
double g_daily_result_r = 0.0;
double g_equity_curve_r = 0.0;
double g_peak_equity_curve_r = 0.0;
double g_max_drawdown_r = 0.0;
double g_actual_spread_sum = 0.0;
double g_actual_slippage_sum = 0.0;
double g_actual_hold_sum = 0.0;
long g_memory_samples = 0;
double g_memory_sum_mb = 0.0;
long g_memory_max_mb = 0;
ulong g_started_tick_count = 0;
int g_event_file = INVALID_HANDLE;
int g_trade_file = INVALID_HANDLE;
int g_summary_file = INVALID_HANDLE;
int g_debug_messages = 0;
bool g_is_tester = false;
bool g_close_requested = false;
int g_rollover_start_minute = -1;
int g_rollover_end_minute = -1;
string g_pending_exit_reason = "";

string TSBool(const bool value)
  {
   return value ? "true" : "false";
  }

string TSLong(const long value)
  {
   return StringFormat("%I64d", value);
  }

string TSUlong(const ulong value)
  {
   return StringFormat("%I64u", value);
  }

string TSDouble(const double value,const int digits=8)
  {
   if(!MathIsValidNumber(value))
      return "";
   return DoubleToString(value, digits);
  }

string TSCsvEscape(string value)
  {
   StringReplace(value, "\"", "\"\"");
   return "\"" + value + "\"";
  }

void TSCsvAppend(string &line,const string value)
  {
   if(line != "")
      line += ",";
   line += TSCsvEscape(value);
  }

string TSDirectionText(const int direction)
  {
   return direction > 0 ? "LONG" : "SHORT";
  }

string TSStateText(const ENUM_TS_STATE state)
  {
   switch(state)
     {
      case TS_SCANNING: return "SCANNING";
      case TS_BURST_ACTIVE: return "BURST_ACTIVE";
      case TS_WAIT_PULLBACK: return "WAIT_PULLBACK";
      case TS_WAIT_REACCELERATION: return "WAIT_REACCELERATION";
      case TS_POSITION_OPEN: return "POSITION_OPEN";
      case TS_EXPIRED: return "EXPIRED";
      case TS_COOLDOWN: return "COOLDOWN";
     }
   return "UNKNOWN";
  }

string TSModeText()
  {
   if(InpRunMode == EVENT_STUDY) return "EVENT_STUDY";
   if(InpRunMode == BACKTEST_TRADE) return "BACKTEST_TRADE";
   return "LIVE_TRADE";
  }

int TSDateKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool TSParseClock(const string text,int &minute_of_day)
  {
   string parts[];
   int count = StringSplit(text, ':', parts);
   if(count != 2)
      return false;
   int hour = (int)StringToInteger(parts[0]);
   int minute = (int)StringToInteger(parts[1]);
   if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
      return false;
   minute_of_day = hour * 60 + minute;
   return true;
  }

bool TSInHourWindow(const int hour,const int start_hour,const int end_hour)
  {
   if(start_hour == end_hour)
      return true;
   if(start_hour < end_hour)
      return hour >= start_hour && hour < end_hour;
   return hour >= start_hour || hour < end_hour;
  }

bool TSIsRolloverBlocked(const long time_msc)
  {
   MqlDateTime dt;
   TimeToStruct((datetime)(time_msc / 1000), dt);
   int minute = dt.hour * 60 + dt.min;
   if(g_rollover_start_minute == g_rollover_end_minute)
      return false;
   if(g_rollover_start_minute < g_rollover_end_minute)
      return minute >= g_rollover_start_minute && minute < g_rollover_end_minute;
   return minute >= g_rollover_start_minute || minute < g_rollover_end_minute;
  }

string TSSessionLabel(const long time_msc)
  {
   MqlDateTime dt;
   TimeToStruct((datetime)(time_msc / 1000), dt);
   bool tokyo = TSInHourWindow(dt.hour, InpTokyoStartHour, InpTokyoEndHour);
   bool london = TSInHourWindow(dt.hour, InpLondonStartHour, InpLondonEndHour);
   bool new_york = TSInHourWindow(dt.hour, InpNewYorkStartHour, InpNewYorkEndHour);
   if(london && new_york) return "OVERLAP";
   if(tokyo) return "TOKYO";
   if(london) return "LONDON";
   if(new_york) return "NEW_YORK";
   return "OTHER";
  }

int TSSessionIndex(const string session)
  {
   if(session == "TOKYO") return 0;
   if(session == "LONDON") return 1;
   if(session == "NEW_YORK") return 2;
   if(session == "OVERLAP") return 3;
   return 4;
  }

int TSAlignmentIndex(const string alignment)
  {
   if(alignment == "BOTH_ALIGNED") return 0;
   if(alignment == "M15_ONLY") return 1;
   if(alignment == "H1_ONLY") return 2;
   if(alignment == "CONFLICT") return 3;
   if(alignment == "NEUTRAL") return 4;
   if(alignment == "UNAVAILABLE") return 5;
   return 6;
  }

void TSAggregateAdd(TSAggregate &aggregate,const double result_r,const bool time_exit=false)
  {
   ++aggregate.count;
   aggregate.sum_r += result_r;
   if(result_r > 0.0)
     {
      ++aggregate.wins;
      aggregate.sum_wins_r += result_r;
      aggregate.gross_positive_r += result_r;
     }
   else if(result_r < 0.0)
     {
      ++aggregate.losses;
      aggregate.sum_losses_r += result_r;
      aggregate.gross_negative_r += -result_r;
     }
   if(time_exit)
      ++aggregate.time_exits;
  }

int TSSkipReasonIndex(const string reason)
  {
   for(int i = 0; i < ArraySize(g_skip_reason_name); ++i)
      if(g_skip_reason_name[i] == reason)
         return i;
   int old_size = ArraySize(g_skip_reason_name);
   ArrayResize(g_skip_reason_name, old_size + 1);
   ArrayResize(g_skip_reason_count, old_size + 1);
   g_skip_reason_name[old_size] = reason;
   g_skip_reason_count[old_size] = 0;
   return old_size;
  }

void TSCountSkip(const string reason)
  {
   if(reason == "")
      return;
   int index = TSSkipReasonIndex(reason);
   ++g_skip_reason_count[index];
  }

int TSPreSkipIndex(const string reason)
  {
   if(reason == "insufficient_baseline") return 0;
   if(reason == "stale_quote") return 1;
   if(reason == "invalid_robust_scale") return 2;
   if(reason == "shock_percentile_failed") return 3;
   if(reason == "shock_z_failed") return 4;
   if(reason == "efficiency_failed") return 5;
   if(reason == "tick_intensity_failed") return 6;
   if(reason == "move_spread_failed") return 7;
   if(reason == "spread_too_wide") return 8;
   return -1;
  }

void TSCountPreSkip(const int symbol_index,const string reason,const long second_key)
  {
   if(symbol_index < 0 || symbol_index >= ArraySize(g_symbols))
      return;
   if(g_symbols[symbol_index].last_fail_count_second == second_key)
      return;
   int reason_index = TSPreSkipIndex(reason);
   if(reason_index < 0)
      return;
   int flat = symbol_index * TS_PRE_SKIP_COUNT + reason_index;
   if(flat >= 0 && flat < ArraySize(g_pre_skip))
      ++g_pre_skip[flat];
   g_symbols[symbol_index].last_fail_count_second = second_key;
  }

void TSDebug(const string symbol,const long time_msc,const string message)
  {
   if(!InpEnableDebug || g_debug_messages >= InpDebugMaxMessages || symbol != InpDebugSymbol)
      return;
   datetime when = (datetime)(time_msc / 1000);
   if(when < InpDebugStart || when > InpDebugEnd)
      return;
   ++g_debug_messages;
   PrintFormat("%s DEBUG %s %s", TS_STRATEGY_NAME, symbol, message);
  }

string TSLogFileName(const string suffix)
  {
   return InpLogFolder + "\\" + TS_STRATEGY_NAME + "_" + InpRunId + "_" + suffix + ".csv";
  }

int TSOpenCsv(const string suffix,const string header)
  {
   FolderCreate(InpLogFolder, FILE_COMMON);
   int flags = FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_COMMON;
   int handle = FileOpen(TSLogFileName(suffix), flags);
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s: FileOpen failed file=%s err=%d", TS_STRATEGY_NAME, suffix, GetLastError());
      return INVALID_HANDLE;
     }
   bool empty = FileSize(handle) == 0;
   FileSeek(handle, 0, SEEK_END);
   if(empty)
      FileWriteString(handle, header + "\r\n");
   return handle;
  }

string TSEventHeader()
  {
   string header = "event_id,symbol,direction,detection_time_msc,processing_time_msc,decision_delay_ms,burst_start_time_msc,burst_end_time_msc,burst_range,move_250ms,move_500ms,move_1000ms,move_2000ms,percentile_threshold,robust_z,efficiency,tick_count,tick_intensity_ratio,spread,spread_median,move_spread_ratio,max_retracement_pct,pullback_time_msc,reacceleration_time_msc,m15_trend,h1_trend,htf_alignment,session,news_label,continuation_eligible,continuation_result_r,reversal_eligible,reversal_result_r";
   for(int i = 0; i < TS_CHECKPOINT_COUNT; ++i)
      header += StringFormat(",price_%ds,mfe_%ds,mae_%ds", TS_CHECKPOINT_SECONDS[i], TS_CHECKPOINT_SECONDS[i], TS_CHECKPOINT_SECONDS[i]);
   header += ",stress_d0_s100_r,stress_d0_s125_r,stress_d0_s150_r,stress_d100_s100_r,stress_d100_s125_r,stress_d100_s150_r,stress_d250_s100_r,stress_d250_s125_r,stress_d250_s150_r,stress_d500_s100_r,stress_d500_s125_r,stress_d500_s150_r,final_event_status,skip_reason";
   return header;
  }

string TSTradeHeader()
  {
   return "event_id,symbol,direction,signal_time_msc,request_time_msc,fill_time_msc,decision_delay_ms,execution_delay_ms,requested_price,fill_price,slippage,initial_spread,volume,sl,tp,risk_distance,risk_amount,planned_rr,close_time_msc,close_price,holding_seconds,exit_reason,gross_profit,commission,swap,net_profit,gross_r,net_r,order_retcode,retcode_external,order_ticket,entry_deal_id,exit_deal_id";
  }

string TSSummaryHeader()
  {
   return "run_id,mode,record_type,key,events,valid_bursts,valid_pullbacks,reacceleration_entries,trades,wins,losses,time_exits,win_rate,average_win_r,average_loss_r,expectancy_r,pf,max_dd_r,avg_hold_seconds,median_hold_seconds,p95_hold_seconds,avg_spread,avg_slippage,continuation_shadow_trades,continuation_shadow_expectancy_r,reversal_shadow_trades,reversal_shadow_expectancy_r,average_memory_mb,max_memory_mb,event_csv_rows,event_csv_bytes,trade_csv_rows,trade_csv_bytes,runtime_seconds,value";
  }

bool TSOpenLogs()
  {
   g_event_file = TSOpenCsv("events", TSEventHeader());
   g_trade_file = TSOpenCsv("trades", TSTradeHeader());
   g_summary_file = TSOpenCsv("summary", TSSummaryHeader());
   return g_event_file != INVALID_HANDLE && g_trade_file != INVALID_HANDLE && g_summary_file != INVALID_HANDLE;
  }

void TSCloseLogs()
  {
   if(g_event_file != INVALID_HANDLE) { FileFlush(g_event_file); FileClose(g_event_file); g_event_file = INVALID_HANDLE; }
   if(g_trade_file != INVALID_HANDLE) { FileFlush(g_trade_file); FileClose(g_trade_file); g_trade_file = INVALID_HANDLE; }
   if(g_summary_file != INVALID_HANDLE) { FileFlush(g_summary_file); FileClose(g_summary_file); g_summary_file = INVALID_HANDLE; }
  }

double TSPercentile(double &values[],const int count,const double percentile)
  {
   if(count <= 0)
      return 0.0;
   ArrayResize(values, count);
   ArraySort(values);
   double rank = (percentile / 100.0) * (count - 1);
   int lower = (int)MathFloor(rank);
   int upper = (int)MathCeil(rank);
   if(lower == upper)
      return values[lower];
   double fraction = rank - lower;
   return values[lower] + (values[upper] - values[lower]) * fraction;
  }

double TSMedian(double &values[],const int count)
  {
   return TSPercentile(values, count, 50.0);
  }

int TSOldestTickIndex(const TSSymbolContext &context)
  {
   if(context.tick_count <= 0)
      return -1;
   int index = context.tick_head - context.tick_count;
   while(index < 0) index += TS_TICK_CAPACITY;
   return index;
  }

int TSOldestSecondIndex(const TSSymbolContext &context)
  {
   if(context.second_count <= 0)
      return -1;
   int index = context.second_head - context.second_count;
   while(index < 0) index += TS_SECOND_CAPACITY;
   return index;
  }

void TSAddSecondSample(TSSymbolContext &context,
                       const long end_msc,
                       const double move,
                       const int tick_count,
                       const double spread)
  {
   TSSecondSample sample;
   sample.end_msc = end_msc;
   sample.move = move;
   sample.tick_count = tick_count;
   sample.spread = spread;
   context.seconds[context.second_head] = sample;
   context.second_head = (context.second_head + 1) % TS_SECOND_CAPACITY;
   if(context.second_count < TS_SECOND_CAPACITY)
      ++context.second_count;
  }

void TSUpdateSecondAggregation(TSSymbolContext &context,const TSShortTick &tick)
  {
   long second_key = tick.time_msc / 1000;
   double spread = tick.ask - tick.bid;
   if(context.bucket_second == 0)
     {
      context.bucket_second = second_key;
      context.bucket_open = tick.mid;
      context.bucket_close = tick.mid;
      context.bucket_spread_sum = spread;
      context.bucket_ticks = 1;
      return;
     }
   if(second_key == context.bucket_second)
     {
      context.bucket_close = tick.mid;
      context.bucket_spread_sum += spread;
      ++context.bucket_ticks;
      return;
     }
   if(second_key > context.bucket_second && context.bucket_ticks > 0)
      TSAddSecondSample(context,
                        (context.bucket_second + 1) * 1000 - 1,
                        MathAbs(context.bucket_close - context.bucket_open),
                        context.bucket_ticks,
                        context.bucket_spread_sum / context.bucket_ticks);
   context.bucket_second = second_key;
   context.bucket_open = tick.mid;
   context.bucket_close = tick.mid;
   context.bucket_spread_sum = spread;
   context.bucket_ticks = 1;
  }

void TSAddShortTick(TSSymbolContext &context,const MqlTick &source)
  {
   TSShortTick tick;
   tick.time_msc = (long)source.time_msc;
   tick.bid = source.bid;
   tick.ask = source.ask;
   tick.mid = (source.bid + source.ask) * 0.5;
   context.ticks[context.tick_head] = tick;
   context.tick_head = (context.tick_head + 1) % TS_TICK_CAPACITY;
   if(context.tick_count < TS_TICK_CAPACITY)
      ++context.tick_count;
   while(context.tick_count > 0)
     {
      int oldest = TSOldestTickIndex(context);
      if(oldest < 0 || tick.time_msc - context.ticks[oldest].time_msc <= TS_TICK_RETENTION_MS)
         break;
      --context.tick_count;
     }
   TSUpdateSecondAggregation(context, tick);
  }

bool TSFindTickAtOrBefore(const TSSymbolContext &context,
                          const long target_msc,
                          TSShortTick &found)
  {
   int oldest = TSOldestTickIndex(context);
   if(oldest < 0)
      return false;
   bool available = false;
   for(int i = 0; i < context.tick_count; ++i)
     {
      int index = (oldest + i) % TS_TICK_CAPACITY;
      if(context.ticks[index].time_msc > target_msc)
         break;
      found = context.ticks[index];
      available = true;
     }
   return available;
  }

double TSMoveForWindow(const TSSymbolContext &context,
                       const TSShortTick &current,
                       const int window_ms,
                       bool &available)
  {
   TSShortTick prior;
   available = TSFindTickAtOrBefore(context, current.time_msc - window_ms, prior);
   if(!available)
      return 0.0;
   return MathAbs(current.mid - prior.mid);
  }

bool TSPathMetrics(const TSSymbolContext &context,
                   const TSShortTick &current,
                   const int window_ms,
                   double &signed_move,
                   double &efficiency,
                   int &tick_count)
  {
   TSShortTick prior;
   if(!TSFindTickAtOrBefore(context, current.time_msc - window_ms, prior))
      return false;
   signed_move = current.mid - prior.mid;
   double path = 0.0;
   double last_mid = prior.mid;
   tick_count = 0;
   int oldest = TSOldestTickIndex(context);
   for(int i = 0; i < context.tick_count; ++i)
     {
      int index = (oldest + i) % TS_TICK_CAPACITY;
      TSShortTick value = context.ticks[index];
      if(value.time_msc <= prior.time_msc)
         continue;
      if(value.time_msc > current.time_msc)
         break;
      path += MathAbs(value.mid - last_mid);
      last_mid = value.mid;
      ++tick_count;
     }
   if(path <= 0.0 || !MathIsValidNumber(path))
      return false;
   efficiency = MathAbs(signed_move) / path;
   return MathIsValidNumber(efficiency);
  }

bool TSRefreshBaselineCache(TSSymbolContext &context,const long now_msc)
  {
   long cache_second = now_msc / 1000;
   if(context.baseline_cache_second == cache_second)
      return context.baseline_samples >= InpMinBaselineSamples;
   context.baseline_cache_second = cache_second;
   long baseline_end = now_msc - InpBaselineExcludeMs;
   long baseline_start = baseline_end - (long)InpBaselineMinutes * 60 * 1000;
   double moves[];
   double ticks[];
   double spreads[];
   ArrayResize(moves, context.second_count);
   ArrayResize(ticks, context.second_count);
   ArrayResize(spreads, context.second_count);
   int move_count = 0;
   int spread_count = 0;
   int oldest = TSOldestSecondIndex(context);
   for(int i = 0; i < context.second_count; ++i)
     {
      int index = (oldest + i) % TS_SECOND_CAPACITY;
      TSSecondSample sample = context.seconds[index];
      if(sample.end_msc >= baseline_start && sample.end_msc <= baseline_end &&
         sample.move >= 0.0 && sample.tick_count > 0 && sample.spread > 0.0)
        {
         moves[move_count] = sample.move;
         ticks[move_count] = (double)sample.tick_count;
         ++move_count;
        }
      if(sample.end_msc >= now_msc - 300000 && sample.end_msc < now_msc && sample.spread > 0.0)
        {
         spreads[spread_count] = sample.spread;
         ++spread_count;
        }
     }
   context.baseline_samples = move_count;
   context.baseline_percentile = 0.0;
   context.baseline_median_move = 0.0;
   context.baseline_mad_move = 0.0;
   context.baseline_median_ticks = 0.0;
   context.spread_median_5m = 0.0;
   if(move_count > 0)
     {
      double moves_for_median[];
      double moves_for_percentile[];
      double ticks_for_median[];
      ArrayCopy(moves_for_median, moves, 0, 0, move_count);
      ArrayCopy(moves_for_percentile, moves, 0, 0, move_count);
      ArrayCopy(ticks_for_median, ticks, 0, 0, move_count);
      context.baseline_median_move = TSMedian(moves_for_median, move_count);
      context.baseline_percentile = TSPercentile(moves_for_percentile, move_count, InpShockPercentile);
      context.baseline_median_ticks = TSMedian(ticks_for_median, move_count);
      double deviations[];
      ArrayResize(deviations, move_count);
      for(int i = 0; i < move_count; ++i)
         deviations[i] = MathAbs(moves[i] - context.baseline_median_move);
      context.baseline_mad_move = TSMedian(deviations, move_count);
     }
   if(spread_count > 0)
     {
      double spreads_for_median[];
      ArrayCopy(spreads_for_median, spreads, 0, 0, spread_count);
      context.spread_median_5m = TSMedian(spreads_for_median, spread_count);
     }
   return move_count >= InpMinBaselineSamples;
  }

bool TSContainsSymbol(const string symbol,const int upto)
  {
   for(int i = 0; i < upto; ++i)
      if(g_symbols[i].symbol == symbol)
         return true;
   return false;
  }

bool TSInitializeSymbol(TSSymbolContext &context,const string symbol)
  {
   context.symbol = symbol;
   context.digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   context.point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   context.tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   context.tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(context.tick_value <= 0.0)
      context.tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   context.volume_min = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   context.volume_max = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   context.volume_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   context.stops_level = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   context.freeze_level = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   if(context.point <= 0.0 || context.tick_size <= 0.0 || context.volume_min <= 0.0 ||
      context.volume_max < context.volume_min || context.volume_step <= 0.0)
     {
      PrintFormat("%s: invalid symbol specification for %s point=%g tick_size=%g min=%g max=%g step=%g",
                  TS_STRATEGY_NAME, symbol, context.point, context.tick_size,
                  context.volume_min, context.volume_max, context.volume_step);
      return false;
     }
   ArrayResize(context.ticks, TS_TICK_CAPACITY);
   ArrayResize(context.seconds, TS_SECOND_CAPACITY);
   context.tick_head = 0;
   context.tick_count = 0;
   context.second_head = 0;
   context.second_count = 0;
   context.bucket_second = 0;
   context.bucket_ticks = 0;
   context.last_time_msc = 0;
   context.processed_at_last_msc = 0;
   context.event_slot = -1;
   context.cooldown_until_msc = 0;
   context.last_fail_count_second = -1;
   context.last_shock_eval_msc = 0;
   context.baseline_cache_second = -1;
   context.baseline_samples = 0;
   TSReset(context.machine);
   context.ema20_m15 = iMA(symbol, PERIOD_M15, 20, 0, MODE_EMA, PRICE_CLOSE);
   context.ema50_m15 = iMA(symbol, PERIOD_M15, 50, 0, MODE_EMA, PRICE_CLOSE);
   context.ema20_h1 = iMA(symbol, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE);
   context.ema50_h1 = iMA(symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(context.ema20_m15 == INVALID_HANDLE || context.ema50_m15 == INVALID_HANDLE ||
      context.ema20_h1 == INVALID_HANDLE || context.ema50_h1 == INVALID_HANDLE)
     {
      PrintFormat("%s: indicator handle creation failed for %s err=%d", TS_STRATEGY_NAME, symbol, GetLastError());
      return false;
     }
   return true;
  }

void TSReleaseSymbols()
  {
   for(int i = 0; i < ArraySize(g_symbols); ++i)
     {
      if(g_symbols[i].ema20_m15 != INVALID_HANDLE) IndicatorRelease(g_symbols[i].ema20_m15);
      if(g_symbols[i].ema50_m15 != INVALID_HANDLE) IndicatorRelease(g_symbols[i].ema50_m15);
      if(g_symbols[i].ema20_h1 != INVALID_HANDLE) IndicatorRelease(g_symbols[i].ema20_h1);
      if(g_symbols[i].ema50_h1 != INVALID_HANDLE) IndicatorRelease(g_symbols[i].ema50_h1);
     }
  }

bool TSParseSymbols()
  {
   string parts[];
   int count = StringSplit(InpSymbols, ',', parts);
   if(count <= 0)
     {
      PrintFormat("%s: InpSymbols is empty", TS_STRATEGY_NAME);
      return false;
     }
   ArrayResize(g_symbols, count);
   int accepted = 0;
   for(int i = 0; i < count; ++i)
     {
      StringTrimLeft(parts[i]);
      StringTrimRight(parts[i]);
      string symbol = parts[i];
      if(symbol == "")
        {
         PrintFormat("%s: empty symbol token at index %d", TS_STRATEGY_NAME, i);
         return false;
        }
      if(TSContainsSymbol(symbol, accepted))
        {
         PrintFormat("%s: duplicate symbol %s", TS_STRATEGY_NAME, symbol);
         return false;
        }
      ResetLastError();
      if(!SymbolSelect(symbol, true))
        {
         PrintFormat("%s: SymbolSelect failed for %s err=%d; specify the broker's exact prefix/suffix name in InpSymbols",
                     TS_STRATEGY_NAME, symbol, GetLastError());
         return false;
        }
      if(!TSInitializeSymbol(g_symbols[accepted], symbol))
         return false;
      ++accepted;
     }
   ArrayResize(g_symbols, accepted);
   ArrayResize(g_pre_skip, accepted * TS_PRE_SKIP_COUNT);
   ArrayInitialize(g_pre_skip, 0);
   ArrayResize(g_symbol_stats, accepted);
   ArrayResize(g_symbol_continuation_shadow, accepted);
   ArrayResize(g_symbol_reversal_shadow, accepted);
   return accepted > 0;
  }

string TSTrendLabel(const int symbol_index,const ENUM_TIMEFRAMES timeframe)
  {
   if(symbol_index < 0 || symbol_index >= ArraySize(g_symbols))
      return "UNAVAILABLE";
   int ema20 = timeframe == PERIOD_M15 ? g_symbols[symbol_index].ema20_m15 : g_symbols[symbol_index].ema20_h1;
   int ema50 = timeframe == PERIOD_M15 ? g_symbols[symbol_index].ema50_m15 : g_symbols[symbol_index].ema50_h1;
   if(ema20 == INVALID_HANDLE || ema50 == INVALID_HANDLE || BarsCalculated(ema20) < 51 || BarsCalculated(ema50) < 51)
      return "UNAVAILABLE";
   double ema20_1[1], ema20_4[1], ema50_1[1];
   if(CopyBuffer(ema20, 0, 1, 1, ema20_1) != 1 ||
      CopyBuffer(ema20, 0, 4, 1, ema20_4) != 1 ||
      CopyBuffer(ema50, 0, 1, 1, ema50_1) != 1)
      return "UNAVAILABLE";
   double close_1 = iClose(g_symbols[symbol_index].symbol, timeframe, 1);
   if(close_1 <= 0.0)
      return "UNAVAILABLE";
   if(close_1 > ema20_1[0] && ema20_1[0] > ema50_1[0] && ema20_1[0] > ema20_4[0])
      return "UP";
   if(close_1 < ema20_1[0] && ema20_1[0] < ema50_1[0] && ema20_1[0] < ema20_4[0])
      return "DOWN";
   return "NEUTRAL";
  }

string TSAlignmentLabel(const int direction,const string m15,const string h1)
  {
   if(m15 == "UNAVAILABLE" || h1 == "UNAVAILABLE") return "UNAVAILABLE";
   string wanted = direction > 0 ? "UP" : "DOWN";
   string opposite = direction > 0 ? "DOWN" : "UP";
   bool m15_match = m15 == wanted;
   bool h1_match = h1 == wanted;
   if(m15_match && h1_match) return "BOTH_ALIGNED";
   if(m15_match) return "M15_ONLY";
   if(h1_match) return "H1_ONLY";
   if(m15 == opposite || h1 == opposite) return "CONFLICT";
   return "NEUTRAL";
  }

int TSAllocateEventSlot()
  {
   for(int i = 0; i < TS_MAX_ACTIVE_EVENTS; ++i)
      if(!g_events[i].active)
        {
         ZeroMemory(g_events[i]);
         g_events[i].active = true;
         return i;
        }
   TSCountSkip("active_event_capacity");
   return -1;
  }

void TSResetShadow(TSShadowTrade &shadow)
  {
   shadow.pending = false;
   shadow.active = false;
   shadow.finished = false;
   shadow.direction = 0;
   shadow.due_msc = 0;
   shadow.entry_msc = 0;
   shadow.exit_msc = 0;
   shadow.entry = 0.0;
   shadow.sl = 0.0;
   shadow.tp = 0.0;
   shadow.risk = 0.0;
   shadow.result_r = 0.0;
   shadow.exit_reason = "";
  }

void TSPrepareEvent(const int slot,
                    const int symbol_index,
                    const TSShortTick &tick,
                    const long processing_msc,
                    const double start_mid,
                    const double move250,
                    const double move500,
                    const double move1000,
                    const double move2000,
                    const double percentile_threshold,
                    const double robust_z,
                    const double efficiency,
                    const int tick_count,
                    const double tick_intensity_ratio,
                    const double spread_median,
                    const double move_spread_ratio,
                    const int direction)
  {
   ++g_event_sequence;
   g_events[slot].symbol_index = symbol_index;
   g_events[slot].event_id = StringFormat("%s_%s_%I64d_%I64d", InpRunId, g_symbols[symbol_index].symbol, tick.time_msc, g_event_sequence);
   g_events[slot].symbol = g_symbols[symbol_index].symbol;
   g_events[slot].direction = direction;
   g_events[slot].detection_msc = tick.time_msc;
   g_events[slot].processing_msc = processing_msc;
   g_events[slot].decision_delay_ms = MathMax((long)0, processing_msc - tick.time_msc);
   g_events[slot].burst_start_msc = tick.time_msc - InpShockWindowMs;
   g_events[slot].start_mid = start_mid;
   g_events[slot].initial_extreme = tick.mid;
   g_events[slot].burst_extreme = tick.mid;
   g_events[slot].move_250 = move250;
   g_events[slot].move_500 = move500;
   g_events[slot].move_1000 = move1000;
   g_events[slot].move_2000 = move2000;
   g_events[slot].percentile_threshold = percentile_threshold;
   g_events[slot].robust_z = robust_z;
   g_events[slot].efficiency = efficiency;
   g_events[slot].tick_count = tick_count;
   g_events[slot].tick_intensity_ratio = tick_intensity_ratio;
   g_events[slot].initial_spread = tick.ask - tick.bid;
   g_events[slot].spread_median = spread_median;
   g_events[slot].move_spread_ratio = move_spread_ratio;
   g_events[slot].m15_trend = TSTrendLabel(symbol_index, PERIOD_M15);
   g_events[slot].h1_trend = TSTrendLabel(symbol_index, PERIOD_H1);
   g_events[slot].htf_alignment = TSAlignmentLabel(direction, g_events[slot].m15_trend, g_events[slot].h1_trend);
   g_events[slot].session = TSSessionLabel(tick.time_msc);
   g_events[slot].news_label = "UNAVAILABLE";
   g_events[slot].best_mid = tick.mid;
   g_events[slot].worst_mid = tick.mid;
   g_events[slot].final_status = "ACTIVE";
   g_events[slot].skip_reason = "";
   TSResetShadow(g_events[slot].continuation);
   TSResetShadow(g_events[slot].reversal);
   for(int i = 0; i < TS_STRESS_COUNT; ++i)
      TSResetShadow(g_events[slot].stress[i]);
  }

double TSNormalizePrice(const int symbol_index,const double price)
  {
   double tick_size = g_symbols[symbol_index].tick_size;
   if(tick_size <= 0.0)
      return 0.0;
   double normalized = MathRound(price / tick_size) * tick_size;
   return NormalizeDouble(normalized, g_symbols[symbol_index].digits);
  }

double TSNormalizeStopTowardEntry(const int symbol_index,
                                  const int direction,
                                  const double raw_stop)
  {
   double tick_size = g_symbols[symbol_index].tick_size;
   if(tick_size <= 0.0)
      return 0.0;
   double units = raw_stop / tick_size;
   // Preserve at least the structural buffer.  This is the initial stop
   // construction, not a post-fill widening operation.
   double normalized = direction > 0 ? MathFloor(units + 1e-10) * tick_size : MathCeil(units - 1e-10) * tick_size;
   return NormalizeDouble(normalized, g_symbols[symbol_index].digits);
  }

bool TSStartShadow(TSShadowTrade &shadow,
                   const int symbol_index,
                   const int direction,
                   const long entry_msc,
                   const double bid,
                   const double ask,
                   const double structural_extreme,
                   const double spread_multiplier,
                   string &reason)
  {
   reason = "";
   double mid = (bid + ask) * 0.5;
   double spread = (ask - bid) * spread_multiplier;
   if(bid <= 0.0 || ask <= bid || spread <= 0.0)
     {
      reason = "stale_quote";
      return false;
     }
   double stressed_bid = mid - spread * 0.5;
   double stressed_ask = mid + spread * 0.5;
   double entry = direction > 0 ? stressed_ask : stressed_bid;
   double buffer = MathMax(spread * 0.5, g_symbols[symbol_index].tick_size * 2.0);
   double raw_sl = direction > 0 ? structural_extreme - buffer : structural_extreme + buffer;
   double sl = TSNormalizeStopTowardEntry(symbol_index, direction, raw_sl);
   double risk = direction > 0 ? entry - sl : sl - entry;
   if(risk <= 0.0)
     {
      reason = "invalid_risk_distance";
      return false;
     }
   double raw_tp = direction > 0 ? entry + risk * InpRewardRisk : entry - risk * InpRewardRisk;
   double tp = TSNormalizePrice(symbol_index, raw_tp);
   if(tp <= 0.0)
     {
      reason = "invalid_target";
      return false;
     }
   shadow.pending = false;
   shadow.active = true;
   shadow.finished = false;
   shadow.direction = direction;
   shadow.entry_msc = entry_msc;
   shadow.entry = entry;
   shadow.sl = sl;
   shadow.tp = tp;
   shadow.risk = risk;
   shadow.result_r = 0.0;
   shadow.exit_reason = "";
   return true;
  }

bool TSAdvanceShadow(TSShadowTrade &shadow,
                     const long time_msc,
                     const double bid,
                     const double ask,
                     const double spread_multiplier)
  {
   if(!shadow.active || shadow.finished)
      return false;
   double mid = (bid + ask) * 0.5;
   double spread = (ask - bid) * spread_multiplier;
   double exit_bid = mid - spread * 0.5;
   double exit_ask = mid + spread * 0.5;
   double exit_price = shadow.direction > 0 ? exit_bid : exit_ask;
   if(!TSResolveShadowExit(shadow.direction, shadow.entry, shadow.sl, shadow.tp, exit_price,
                           shadow.entry_msc, time_msc, InpMaxHoldSeconds,
                           shadow.result_r, shadow.exit_reason))
      return false;
   shadow.exit_msc = time_msc;
   shadow.active = false;
   shadow.finished = true;
   return true;
  }

void TSApplyShadowCommission(const string symbol,TSShadowTrade &shadow)
  {
   if(InpCommissionPerLotRoundTurn <= 0.0 || !shadow.finished || shadow.risk <= 0.0)
      return;
   double loss_one_lot = 0.0;
   ENUM_ORDER_TYPE type = shadow.direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcProfit(type, symbol, 1.0, shadow.entry, shadow.sl, loss_one_lot) || loss_one_lot >= 0.0)
      return;
   shadow.result_r -= InpCommissionPerLotRoundTurn / MathAbs(loss_one_lot);
  }

void TSFinalizeBaseShadow(TSEventRecord &event,const bool continuation)
  {
   if(continuation)
      TSApplyShadowCommission(event.symbol, event.continuation);
   else
      TSApplyShadowCommission(event.symbol, event.reversal);
   TSShadowTrade shadow = continuation ? event.continuation : event.reversal;
   if(!shadow.finished)
      return;
   if(continuation)
     {
      event.continuation_result_r = shadow.result_r;
      TSAggregateAdd(g_continuation_shadow, shadow.result_r, shadow.exit_reason == "TIME");
      TSAggregateAdd(g_symbol_continuation_shadow[event.symbol_index], shadow.result_r, shadow.exit_reason == "TIME");
      TSAggregateAdd(g_session_continuation_shadow[TSSessionIndex(event.session)], shadow.result_r, shadow.exit_reason == "TIME");
      TSAggregateAdd(g_alignment_continuation_shadow[TSAlignmentIndex(event.htf_alignment)], shadow.result_r, shadow.exit_reason == "TIME");
     }
   else
     {
      event.reversal_result_r = shadow.result_r;
      TSAggregateAdd(g_reversal_shadow, shadow.result_r, shadow.exit_reason == "TIME");
      TSAggregateAdd(g_symbol_reversal_shadow[event.symbol_index], shadow.result_r, shadow.exit_reason == "TIME");
      TSAggregateAdd(g_session_reversal_shadow[TSSessionIndex(event.session)], shadow.result_r, shadow.exit_reason == "TIME");
      TSAggregateAdd(g_alignment_reversal_shadow[TSAlignmentIndex(event.htf_alignment)], shadow.result_r, shadow.exit_reason == "TIME");
      if(event.final_status == "REVERSAL_SHADOW_PENDING")
         event.final_status = "REVERSAL_SHADOW_COMPLETE";
     }
  }

bool TSAllEventTradesFinished(const TSEventRecord &event)
  {
   if(event.continuation.pending || event.continuation.active) return false;
   if(event.reversal.pending || event.reversal.active) return false;
   for(int i = 0; i < TS_STRESS_COUNT; ++i)
      if(event.stress[i].pending || event.stress[i].active)
         return false;
   if(g_trade.active && g_trade.event_slot >= 0 && g_trade.event_slot < TS_MAX_ACTIVE_EVENTS &&
      g_trade.event_id == event.event_id)
      return false;
   return true;
  }

void TSWriteEventRecord(TSEventRecord &event)
  {
   string line = "";
   TSCsvAppend(line, event.event_id);
   TSCsvAppend(line, event.symbol);
   TSCsvAppend(line, TSDirectionText(event.direction));
   TSCsvAppend(line, TSLong(event.detection_msc));
   TSCsvAppend(line, TSLong(event.processing_msc));
   TSCsvAppend(line, TSLong(event.decision_delay_ms));
   TSCsvAppend(line, TSLong(event.burst_start_msc));
   TSCsvAppend(line, TSLong(event.burst_end_msc));
   TSCsvAppend(line, TSDouble(event.burst_range));
   TSCsvAppend(line, TSDouble(event.move_250));
   TSCsvAppend(line, TSDouble(event.move_500));
   TSCsvAppend(line, TSDouble(event.move_1000));
   TSCsvAppend(line, TSDouble(event.move_2000));
   TSCsvAppend(line, TSDouble(event.percentile_threshold));
   TSCsvAppend(line, TSDouble(event.robust_z, 5));
   TSCsvAppend(line, TSDouble(event.efficiency, 5));
   TSCsvAppend(line, IntegerToString(event.tick_count));
   TSCsvAppend(line, TSDouble(event.tick_intensity_ratio, 5));
   TSCsvAppend(line, TSDouble(event.initial_spread));
   TSCsvAppend(line, TSDouble(event.spread_median));
   TSCsvAppend(line, TSDouble(event.move_spread_ratio, 5));
   TSCsvAppend(line, TSDouble(event.max_retracement_pct, 3));
   TSCsvAppend(line, TSLong(event.pullback_msc));
   TSCsvAppend(line, TSLong(event.reacceleration_msc));
   TSCsvAppend(line, event.m15_trend);
   TSCsvAppend(line, event.h1_trend);
   TSCsvAppend(line, event.htf_alignment);
   TSCsvAppend(line, event.session);
   TSCsvAppend(line, event.news_label);
   TSCsvAppend(line, TSBool(event.continuation_eligible));
   TSCsvAppend(line, event.continuation.finished && event.continuation.exit_reason != "" ? TSDouble(event.continuation_result_r, 6) : "");
   TSCsvAppend(line, TSBool(event.reversal_eligible));
   TSCsvAppend(line, event.reversal.finished ? TSDouble(event.reversal_result_r, 6) : "");
   for(int i = 0; i < TS_CHECKPOINT_COUNT; ++i)
     {
      TSCsvAppend(line, event.checkpoint_done[i] ? TSDouble(event.checkpoint_price[i]) : "");
      TSCsvAppend(line, event.checkpoint_done[i] ? TSDouble(event.checkpoint_mfe[i]) : "");
      TSCsvAppend(line, event.checkpoint_done[i] ? TSDouble(event.checkpoint_mae[i]) : "");
     }
   for(int i = 0; i < TS_STRESS_COUNT; ++i)
      TSCsvAppend(line, event.stress[i].finished ? TSDouble(event.stress[i].result_r, 6) : "");
   TSCsvAppend(line, event.final_status);
   TSCsvAppend(line, event.skip_reason);
   if(g_event_file != INVALID_HANDLE)
     {
      FileWriteString(g_event_file, line + "\r\n");
      FileFlush(g_event_file);
      ++g_event_rows;
     }
   event.csv_written = true;
  }

void TSWriteEventRow(const int slot)
  {
   if(slot < 0 || slot >= TS_MAX_ACTIVE_EVENTS || !g_events[slot].active || g_events[slot].csv_written)
      return;
   TSWriteEventRecord(g_events[slot]);
  }

void TSReleaseEventSlot(const int slot)
  {
   if(slot < 0 || slot >= TS_MAX_ACTIVE_EVENTS)
      return;
   g_events[slot].active = false;
  }

void TSUpdateEventTracking(const int symbol_index,const TSShortTick &tick)
  {
   for(int slot = 0; slot < TS_MAX_ACTIVE_EVENTS; ++slot)
     {
      if(!g_events[slot].active || g_events[slot].symbol_index != symbol_index)
         continue;
      g_events[slot].best_mid = MathMax(g_events[slot].best_mid, tick.mid);
      g_events[slot].worst_mid = MathMin(g_events[slot].worst_mid, tick.mid);
      for(int i = 0; i < TS_CHECKPOINT_COUNT; ++i)
        {
         if(g_events[slot].checkpoint_done[i] || tick.time_msc - g_events[slot].detection_msc < (long)TS_CHECKPOINT_SECONDS[i] * 1000)
            continue;
         g_events[slot].checkpoint_done[i] = true;
         g_events[slot].checkpoint_price[i] = tick.mid;
         if(g_events[slot].direction > 0)
           {
            g_events[slot].checkpoint_mfe[i] = MathMax(0.0, g_events[slot].best_mid - g_events[slot].start_mid);
            g_events[slot].checkpoint_mae[i] = MathMax(0.0, g_events[slot].start_mid - g_events[slot].worst_mid);
           }
         else
           {
            g_events[slot].checkpoint_mfe[i] = MathMax(0.0, g_events[slot].start_mid - g_events[slot].worst_mid);
            g_events[slot].checkpoint_mae[i] = MathMax(0.0, g_events[slot].best_mid - g_events[slot].start_mid);
           }
        }

      if(g_events[slot].reversal.pending && tick.time_msc > g_events[slot].reversal.due_msc)
        {
         string reason = "";
         if(TSStartShadow(g_events[slot].reversal, symbol_index, -g_events[slot].direction, tick.time_msc,
                          tick.bid, tick.ask, g_events[slot].burst_extreme, 1.0, reason))
            g_events[slot].reversal_eligible = true;
         else
           {
            g_events[slot].reversal.pending = false;
            g_events[slot].reversal.finished = true;
            g_events[slot].reversal.exit_reason = reason;
           }
        }
      if(TSAdvanceShadow(g_events[slot].continuation, tick.time_msc, tick.bid, tick.ask, 1.0))
         TSFinalizeBaseShadow(g_events[slot], true);
      if(TSAdvanceShadow(g_events[slot].reversal, tick.time_msc, tick.bid, tick.ask, 1.0))
         TSFinalizeBaseShadow(g_events[slot], false);

      for(int i = 0; i < TS_STRESS_COUNT; ++i)
        {
         if(g_events[slot].stress[i].pending && tick.time_msc >= g_events[slot].stress[i].due_msc)
           {
            string reason = "";
            if(!TSStartShadow(g_events[slot].stress[i], symbol_index, g_events[slot].direction, tick.time_msc,
                              tick.bid, tick.ask, g_events[slot].pullback_extreme, TS_SPREAD_MULT[i], reason))
              {
               g_events[slot].stress[i].pending = false;
               g_events[slot].stress[i].finished = true;
               g_events[slot].stress[i].exit_reason = reason;
              }
           }
         if(TSAdvanceShadow(g_events[slot].stress[i], tick.time_msc, tick.bid, tick.ask, TS_SPREAD_MULT[i]))
            TSApplyShadowCommission(g_events[slot].symbol, g_events[slot].stress[i]);
        }

      bool checkpoints_complete = g_events[slot].checkpoint_done[TS_CHECKPOINT_COUNT - 1];
      if(g_events[slot].terminal && checkpoints_complete && TSAllEventTradesFinished(g_events[slot]))
        {
         TSWriteEventRow(slot);
         TSReleaseEventSlot(slot);
        }
     }
  }

void TSMarkEventTerminal(const int symbol_index,
                         const int slot,
                         const long now_msc,
                         const string status,
                         const string reason)
  {
   if(slot < 0 || slot >= TS_MAX_ACTIVE_EVENTS || !g_events[slot].active)
      return;
   g_events[slot].terminal = true;
   g_events[slot].final_status = status;
   g_events[slot].skip_reason = reason;
   if(reason != "")
      TSCountSkip(reason);
   g_symbols[symbol_index].machine.state = TS_COOLDOWN;
   g_symbols[symbol_index].cooldown_until_msc = now_msc + (long)InpSymbolCooldownSeconds * 1000;
   g_symbols[symbol_index].event_slot = -1;
   TSDebug(g_symbols[symbol_index].symbol, now_msc, "terminal status=" + status + " reason=" + reason);
  }

bool TSDetectShockContext(TSSymbolContext &context,
                          const int symbol_index,
                          const TSShortTick &tick,
                          const long processing_msc)
  {
   if(context.machine.state != TS_SCANNING || context.event_slot >= 0)
      return false;
   if(tick.time_msc - context.last_shock_eval_msc < 50)
      return false;
   context.last_shock_eval_msc = tick.time_msc;
   long second_key = tick.time_msc / 1000;
   if(!TSRefreshBaselineCache(context, tick.time_msc))
     {
      TSCountPreSkip(symbol_index, "insufficient_baseline", second_key);
      return false;
     }
   if(tick.bid <= 0.0 || tick.ask <= tick.bid || (!g_is_tester && processing_msc - tick.time_msc > InpMaxQuoteAgeMs))
     {
      TSCountPreSkip(symbol_index, "stale_quote", second_key);
      return false;
     }
   TSShortTick start_tick;
   if(!TSFindTickAtOrBefore(context, tick.time_msc - InpShockWindowMs, start_tick) ||
      tick.time_msc - start_tick.time_msc > InpShockWindowMs + 1000)
     {
      TSCountPreSkip(symbol_index, "insufficient_baseline", second_key);
      return false;
     }
   double signed_move = 0.0;
   double efficiency = 0.0;
   int current_tick_count = 0;
   if(!TSPathMetrics(context, tick, InpShockWindowMs, signed_move, efficiency, current_tick_count))
     {
      TSCountPreSkip(symbol_index, "efficiency_failed", second_key);
      return false;
     }
   double move = MathAbs(signed_move);
   double robust_scale = 1.4826 * context.baseline_mad_move;
   if(robust_scale <= context.tick_size * 0.01 || !MathIsValidNumber(robust_scale))
     {
      TSCountPreSkip(symbol_index, "invalid_robust_scale", second_key);
      return false;
     }
   double current_spread = tick.ask - tick.bid;
   if(current_spread <= 0.0 || context.baseline_median_ticks <= 0.0 || context.spread_median_5m <= 0.0)
     {
      TSCountPreSkip(symbol_index, "invalid_robust_scale", second_key);
      return false;
     }
   double robust_z = (move - context.baseline_median_move) / robust_scale;
   double tick_intensity_ratio = current_tick_count / context.baseline_median_ticks;
   double move_spread_ratio = move / current_spread;
   double spread_ratio = current_spread / context.spread_median_5m;
   string reason = "";
   if(move >= context.baseline_percentile && context.last_raw_candidate_second != second_key)
     {
      ++g_raw_shock_candidates;
      ++context.raw_candidates;
      context.last_raw_candidate_second = second_key;
     }
   if(!TSShockConditionsPass(move, context.baseline_percentile, robust_z, efficiency,
                             move_spread_ratio, tick_intensity_ratio, spread_ratio,
                             InpMinRobustZ, InpMinEfficiency, InpMinMoveSpreadRatio,
                             InpMinTickIntensityRatio, InpMaxSpreadMedianRatio, reason))
     {
      TSCountPreSkip(symbol_index, reason, second_key);
      return false;
     }
   int direction = signed_move > 0.0 ? 1 : -1;
   int slot = TSAllocateEventSlot();
   if(slot < 0)
      return false;
   bool ok250=false, ok500=false, ok1000=false, ok2000=false;
   double move250 = TSMoveForWindow(context, tick, 250, ok250);
   double move500 = TSMoveForWindow(context, tick, 500, ok500);
   double move1000 = TSMoveForWindow(context, tick, 1000, ok1000);
   double move2000 = TSMoveForWindow(context, tick, 2000, ok2000);
   TSPrepareEvent(slot, symbol_index, tick, processing_msc, start_tick.mid,
                  ok250 ? move250 : 0.0, ok500 ? move500 : 0.0,
                  ok1000 ? move1000 : move, ok2000 ? move2000 : 0.0,
                  context.baseline_percentile, robust_z, efficiency, current_tick_count,
                  tick_intensity_ratio, context.spread_median_5m, move_spread_ratio, direction);
   TSStartBurst(context.machine, direction, tick.time_msc, start_tick.mid, tick.mid);
   context.event_slot = slot;
   ++context.events_detected;
   ++g_valid_shock_events;
   ++g_session_events[TSSessionIndex(g_events[slot].session)];
   ++g_alignment_events[TSAlignmentIndex(g_events[slot].htf_alignment)];
   TSDebug(context.symbol, tick.time_msc, "SCANNING->BURST_ACTIVE event=" + g_events[slot].event_id);
   return true;
  }

bool TSDetectShock(const int symbol_index,
                   const TSShortTick &tick,
                   const long processing_msc)
  {
   return TSDetectShockContext(g_symbols[symbol_index], symbol_index, tick, processing_msc);
  }

void TSAppendCandidate(TSEntryCandidate &candidates[],
                       const int symbol_index,
                       const int event_slot,
                       const TSShortTick &tick)
  {
   int size = ArraySize(candidates);
   ArrayResize(candidates, size + 1);
   candidates[size].valid = true;
   candidates[size].symbol_index = symbol_index;
   candidates[size].event_slot = event_slot;
   candidates[size].score = g_events[event_slot].robust_z * g_events[event_slot].efficiency *
                            g_events[event_slot].tick_intensity_ratio * g_events[event_slot].move_spread_ratio;
   candidates[size].signal_msc = tick.time_msc;
   candidates[size].signal_bid = tick.bid;
   candidates[size].signal_ask = tick.ask;
  }

void TSAdvanceActiveState(TSSymbolContext &context,
                          TSEventRecord &event,
                          const int symbol_index,
                          const int slot,
                          const TSShortTick &tick,
                          TSEntryCandidate &candidates[])
  {
   ENUM_TS_ACTION action = TSAdvance(context.machine, tick.time_msc, tick.mid,
                                     InpBurstQuietMs, InpBurstMaxMs,
                                     InpPullbackMinPct, InpPullbackMaxPct,
                                     InpContinuationInvalidPct, InpPullbackWaitMs,
                                     InpReaccelerationConfirmTicks);
   if(action == TS_ACTION_NONE)
      return;
   event.burst_extreme = context.machine.burst_extreme;
   event.burst_range = context.machine.burst_range;
   event.max_retracement_pct = context.machine.max_retracement_pct;
   if(action == TS_ACTION_BURST_FROZEN)
     {
      event.burst_end_msc = context.machine.burst_end_msc;
      ++g_valid_bursts;
      ++context.bursts_frozen;
      ++g_session_bursts[TSSessionIndex(event.session)];
      ++g_alignment_bursts[TSAlignmentIndex(event.htf_alignment)];
      TSDebug(context.symbol, tick.time_msc, "BURST_ACTIVE->WAIT_PULLBACK");
      return;
     }
   if(action == TS_ACTION_PULLBACK_VALID)
     {
      event.pullback_msc = context.machine.pullback_msc;
      event.pullback_extreme = context.machine.pullback_extreme;
      ++g_valid_pullbacks;
      ++context.valid_pullbacks;
      ++g_session_pullbacks[TSSessionIndex(event.session)];
      ++g_alignment_pullbacks[TSAlignmentIndex(event.htf_alignment)];
      TSDebug(context.symbol, tick.time_msc, "WAIT_PULLBACK->WAIT_REACCELERATION");
      return;
     }
   if(action == TS_ACTION_REACCELERATION)
     {
      event.reacceleration_msc = tick.time_msc;
      event.pullback_extreme = context.machine.pullback_extreme;
      event.continuation_eligible = true;
      context.machine.state = TS_POSITION_OPEN;
      ++g_reacceleration_signals;
      ++context.reacceleration_signals;
      ++g_session_reaccelerations[TSSessionIndex(event.session)];
      ++g_alignment_reaccelerations[TSAlignmentIndex(event.htf_alignment)];
      TSAppendCandidate(candidates, symbol_index, slot, tick);
      TSDebug(context.symbol, tick.time_msc, "WAIT_REACCELERATION->candidate");
      return;
     }
   if(action == TS_ACTION_CONTINUATION_INVALIDATED)
     {
      event.reversal.pending = true;
      event.reversal.direction = -event.direction;
      event.reversal.due_msc = tick.time_msc;
      event.reversal_eligible = true;
      TSMarkEventTerminal(symbol_index, slot, tick.time_msc, "REVERSAL_SHADOW_PENDING", "continuation_invalidated");
      return;
     }
   if(action == TS_ACTION_PULLBACK_TIMEOUT)
     {
      string reason = context.machine.too_deep_seen ? "pullback_too_deep" :
                      (context.machine.max_retracement_pct > 0.0 ? "pullback_too_shallow" : "pullback_timeout");
      TSMarkEventTerminal(symbol_index, slot, tick.time_msc, "EXPIRED", reason);
      return;
     }
   if(action == TS_ACTION_NO_REACCELERATION)
      TSMarkEventTerminal(symbol_index, slot, tick.time_msc, "EXPIRED", "no_reacceleration");
  }

void TSAdvanceStateMachine(const int symbol_index,
                           const TSShortTick &tick,
                           TSEntryCandidate &candidates[])
  {
   if(g_symbols[symbol_index].machine.state == TS_COOLDOWN)
     {
      if(TSCooldownComplete(tick.time_msc, g_symbols[symbol_index].cooldown_until_msc))
         TSReset(g_symbols[symbol_index].machine);
      else
         return;
     }
   int slot = g_symbols[symbol_index].event_slot;
   if(slot < 0 || slot >= TS_MAX_ACTIVE_EVENTS || !g_events[slot].active)
      return;
   TSAdvanceActiveState(g_symbols[symbol_index], g_events[slot], symbol_index, slot, tick, candidates);
  }

int TSCountManagedPositions()
  {
   int count = 0;
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      if(PositionGetTicket(i) == 0)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         ++count;
     }
   return count;
  }

bool TSHasNettingConflict(const string symbol)
  {
   ENUM_ACCOUNT_MARGIN_MODE mode = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(mode != ACCOUNT_MARGIN_MODE_RETAIL_NETTING && mode != ACCOUNT_MARGIN_MODE_EXCHANGE)
      return false;
   if(!PositionSelect(symbol))
      return false;
   return (long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber;
  }

bool TSQuoteIsFresh(const MqlTick &quote,const long processing_msc)
  {
   if(quote.bid <= 0.0 || quote.ask <= quote.bid || quote.time_msc <= 0)
      return false;
   return processing_msc - (long)quote.time_msc <= InpMaxQuoteAgeMs;
  }

double TSFloorVolume(const int symbol_index,const double raw)
  {
   double step = g_symbols[symbol_index].volume_step;
   if(step <= 0.0 || raw < g_symbols[symbol_index].volume_min - 1e-12)
      return 0.0;
   double volume = MathFloor((raw + 1e-12) / step) * step;
   volume = MathMin(volume, g_symbols[symbol_index].volume_max);
   if(volume < g_symbols[symbol_index].volume_min - 1e-12)
      return 0.0;
   return NormalizeDouble(volume, 8);
  }

bool TSCalculateVolume(const int symbol_index,
                       const int direction,
                       const double entry,
                       const double sl,
                       double &volume,
                       double &risk_amount,
                       string &reason)
  {
   reason = "";
   risk_amount = 0.0;
   double requested = InpFixedLot;
   double loss_one_lot = 0.0;
   ENUM_ORDER_TYPE order_type = direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcProfit(order_type, g_symbols[symbol_index].symbol, 1.0, entry, sl, loss_one_lot) || loss_one_lot >= 0.0)
     {
      reason = "risk_calculation_failed";
      return false;
     }
   if(InpLotMode == RISK_PERCENT)
     {
      double risk_budget = AccountInfoDouble(ACCOUNT_EQUITY) * InpRiskPercent / 100.0;
      if(risk_budget <= 0.0)
        {
         reason = "risk_calculation_failed";
         return false;
        }
      requested = risk_budget / MathAbs(loss_one_lot);
     }
   volume = TSFloorVolume(symbol_index, requested);
   if(volume <= 0.0)
     {
      reason = "volume_below_minimum";
      return false;
     }
   double steps = volume / g_symbols[symbol_index].volume_step;
   if(MathAbs(steps - MathRound(steps)) > 1e-7)
     {
      reason = "volume_step_invalid";
      return false;
     }
   risk_amount = MathAbs(loss_one_lot) * volume;
   return true;
  }

ENUM_ORDER_TYPE_FILLING TSFillingMode(const string symbol)
  {
   int filling = (int)SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return ORDER_FILLING_FOK;
   if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
  }

bool TSPrepareContinuationShadowsForEvent(TSEventRecord &event,
                                          const TSEntryCandidate &candidate,
                                          string &reason)
  {
   reason = "";
   if(!TSStartShadow(event.continuation, candidate.symbol_index, event.direction,
                     candidate.signal_msc, candidate.signal_bid, candidate.signal_ask,
                     event.pullback_extreme, 1.0, reason))
      return false;
   for(int i = 0; i < TS_STRESS_COUNT; ++i)
     {
      event.stress[i].direction = event.direction;
      event.stress[i].due_msc = candidate.signal_msc + TS_DELAY_MS[i];
      if(TS_DELAY_MS[i] == 0)
        {
         string stress_reason = "";
         if(!TSStartShadow(event.stress[i], candidate.symbol_index, event.direction,
                           candidate.signal_msc, candidate.signal_bid, candidate.signal_ask,
                           event.pullback_extreme, TS_SPREAD_MULT[i], stress_reason))
           {
            event.stress[i].finished = true;
            event.stress[i].exit_reason = stress_reason;
           }
        }
      else
         event.stress[i].pending = true;
     }
   event.continuation_eligible = TSRiskConditionsPass(candidate.signal_ask - candidate.signal_bid,
                                                      event.continuation.risk, event.burst_range, reason);
   return event.continuation_eligible;
  }

bool TSPrepareContinuationShadows(const TSEntryCandidate &candidate,string &reason)
  {
   return TSPrepareContinuationShadowsForEvent(g_events[candidate.event_slot], candidate, reason);
  }

bool TSInitialTradeGuardsForEvent(TSEventRecord &event,
                                  const TSEntryCandidate &candidate,
                                  const long processing_msc,
                                  MqlTick &quote,
                                  double &sl,
                                  double &tp,
                                  double &risk_distance,
                                  double &volume,
                                  double &risk_amount,
                                  string &reason)
  {
   reason = "";
   int symbol_index = candidate.symbol_index;
   if(TSCountManagedPositions() > 0)
     {
      reason = "position_already_open";
      return false;
     }
   if(TSHasNettingConflict(event.symbol))
     {
      reason = "netting_position_conflict";
      return false;
     }
   if(candidate.signal_msc < g_symbols[symbol_index].cooldown_until_msc)
     {
      reason = "symbol_cooldown";
      return false;
     }
   if(candidate.signal_msc < g_global_cooldown_until_msc)
     {
      reason = "global_cooldown";
      return false;
     }
   if(TSDailyLossBlocked(g_daily_result_r, InpDailyLossLimitR))
     {
      reason = "daily_loss_limit";
      return false;
     }
   if(g_daily_trades >= InpMaxTradesPerDay)
     {
      reason = "daily_trade_limit";
      return false;
     }
   if(TSIsRolloverBlocked(processing_msc))
     {
      reason = "rollover_block";
      return false;
     }
   if(!SymbolInfoTick(event.symbol, quote) || !TSQuoteIsFresh(quote, processing_msc))
     {
      reason = "stale_quote";
      return false;
     }
   double spread = quote.ask - quote.bid;
   double entry = event.direction > 0 ? quote.ask : quote.bid;
   double buffer = MathMax(spread * 0.5, g_symbols[symbol_index].tick_size * 2.0);
   double raw_sl = event.direction > 0 ? event.pullback_extreme - buffer : event.pullback_extreme + buffer;
   sl = TSNormalizeStopTowardEntry(symbol_index, event.direction, raw_sl);
   risk_distance = event.direction > 0 ? entry - sl : sl - entry;
   if(!TSRiskConditionsPass(spread, risk_distance, event.burst_range, reason))
      return false;
   double minimum_distance = MathMax(g_symbols[symbol_index].stops_level,
                                     g_symbols[symbol_index].freeze_level) * g_symbols[symbol_index].point;
   if(risk_distance + 1e-12 < minimum_distance)
     {
      reason = "stop_too_narrow_for_broker";
      return false;
     }
   double tp_raw = event.direction > 0 ? entry + risk_distance * InpRewardRisk : entry - risk_distance * InpRewardRisk;
   tp = TSNormalizePrice(symbol_index, tp_raw);
   if(tp <= 0.0 || MathAbs(tp / g_symbols[symbol_index].tick_size - MathRound(tp / g_symbols[symbol_index].tick_size)) > 1e-7 ||
      MathAbs(sl / g_symbols[symbol_index].tick_size - MathRound(sl / g_symbols[symbol_index].tick_size)) > 1e-7)
     {
      reason = "price_tick_size_invalid";
      return false;
     }
   double tp_distance = MathAbs(tp - entry);
   if(tp_distance + 1e-12 < minimum_distance)
     {
      reason = "stop_too_narrow_for_broker";
      return false;
     }
   if(!TSCalculateVolume(symbol_index, event.direction, entry, sl, volume, risk_amount, reason))
      return false;
   double margin = 0.0;
   ENUM_ORDER_TYPE order_type = event.direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcMargin(order_type, event.symbol, volume, entry, margin) || margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
     {
      reason = "margin_rejected";
      return false;
     }
   return true;
  }

bool TSInitialTradeGuards(const TSEntryCandidate &candidate,
                          const long processing_msc,
                          MqlTick &quote,
                          double &sl,
                          double &tp,
                          double &risk_distance,
                          double &volume,
                          double &risk_amount,
                          string &reason)
  {
   return TSInitialTradeGuardsForEvent(g_events[candidate.event_slot], candidate, processing_msc,
                                       quote, sl, tp, risk_distance, volume, risk_amount, reason);
  }

bool TSSendEntryOrder(const TSEntryCandidate &candidate,const long processing_msc,string &reason)
  {
   MqlTick quote;
   double sl=0.0, tp=0.0, risk_distance=0.0, volume=0.0, risk_amount=0.0;
   if(!TSInitialTradeGuards(candidate, processing_msc, quote, sl, tp, risk_distance, volume, risk_amount, reason))
      return false;
   MqlTradeRequest request;
   MqlTradeResult result;
   MqlTradeCheckResult check;
   ZeroMemory(request);
   ZeroMemory(result);
   ZeroMemory(check);
   request.action = TRADE_ACTION_DEAL;
   request.magic = InpMagicNumber;
   request.symbol = g_events[candidate.event_slot].symbol;
   request.volume = volume;
   request.type = g_events[candidate.event_slot].direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price = g_events[candidate.event_slot].direction > 0 ? quote.ask : quote.bid;
   request.sl = sl;
   request.tp = tp;
   request.deviation = InpMaxSlippagePoints;
   request.type_filling = TSFillingMode(g_events[candidate.event_slot].symbol);
   request.comment = "TickShock";
   if(!OrderCheck(request, check) ||
      (check.retcode != TRADE_RETCODE_DONE && check.retcode != TRADE_RETCODE_PLACED))
     {
      reason = check.retcode == TRADE_RETCODE_NO_MONEY ? "margin_rejected" : "order_rejected";
      PrintFormat("%s: OrderCheck failed event=%s retcode=%u comment=%s",
                  TS_STRATEGY_NAME, g_events[candidate.event_slot].event_id, check.retcode, check.comment);
      return false;
     }
   ZeroMemory(g_trade);
   g_close_requested = false;
   g_trade.active = true;
   g_trade.event_id = g_events[candidate.event_slot].event_id;
   g_trade.event_slot = candidate.event_slot;
   g_trade.symbol = g_events[candidate.event_slot].symbol;
   g_trade.direction = g_events[candidate.event_slot].direction;
   g_trade.signal_msc = candidate.signal_msc;
   g_trade.request_msc = processing_msc;
   g_trade.decision_delay_ms = MathMax((long)0, processing_msc - candidate.signal_msc);
   g_trade.requested_price = request.price;
   g_trade.initial_spread = quote.ask - quote.bid;
   g_trade.volume = volume;
   g_trade.sl = sl;
   g_trade.tp = tp;
   g_trade.risk_distance = risk_distance;
   g_trade.risk_amount = risk_amount;
   g_trade.planned_rr = InpRewardRisk;
   if(!OrderSend(request, result))
     {
      g_trade.active = false;
      reason = "order_rejected";
      PrintFormat("%s: OrderSend transport failure event=%s err=%d retcode=%u external=%d",
                  TS_STRATEGY_NAME, g_events[candidate.event_slot].event_id, GetLastError(), result.retcode, result.retcode_external);
      return false;
     }
   g_trade.order_retcode = result.retcode;
   g_trade.order_retcode_external = result.retcode_external;
   g_trade.order_ticket = result.order;
   g_trade.entry_deal = result.deal;
   if(result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_DONE_PARTIAL && result.retcode != TRADE_RETCODE_PLACED)
     {
      g_trade.active = false;
      reason = "order_rejected";
      PrintFormat("%s: order rejected event=%s retcode=%u external=%d comment=%s",
                  TS_STRATEGY_NAME, g_events[candidate.event_slot].event_id, result.retcode, result.retcode_external, result.comment);
      return false;
     }
   ++g_daily_trades;
   TSSaveDailyState();
   g_global_cooldown_until_msc = processing_msc + (long)InpGlobalCooldownSeconds * 1000;
   return true;
  }

void TSProcessCandidates(TSEntryCandidate &candidates[],const long processing_msc)
  {
   int count = ArraySize(candidates);
   if(count <= 0)
      return;
   double scores[];
   ArrayResize(scores, count);
   for(int i = 0; i < count; ++i)
      scores[i] = candidates[i].score;
   int best = TSSelectHighestScore(scores, count);
   for(int i = 0; i < count; ++i)
     {
      int slot = candidates[i].event_slot;
      int symbol_index = candidates[i].symbol_index;
      if(i != best)
        {
         g_events[slot].continuation_eligible = false;
         TSMarkEventTerminal(symbol_index, slot, candidates[i].signal_msc,
                             "NOT_SELECTED", "lower_ranked_candidate");
         continue;
        }
      string reason = "";
      if(!TSPrepareContinuationShadows(candidates[i], reason))
        {
         g_events[slot].continuation_eligible = false;
         TSMarkEventTerminal(symbol_index, slot, candidates[i].signal_msc,
                             "EXECUTION_FILTERED", reason);
         continue;
        }
      if(InpRunMode == EVENT_STUDY)
        {
         TSMarkEventTerminal(symbol_index, slot, candidates[i].signal_msc,
                             "CONTINUATION_SHADOW", "");
         continue;
        }
      if(InpRunMode == LIVE_TRADE && !InpEnableTrading)
        {
         TSMarkEventTerminal(symbol_index, slot, candidates[i].signal_msc,
                             "LIVE_DISABLED_SHADOW", "trading_disabled");
         continue;
        }
      if(!TSSendEntryOrder(candidates[i], processing_msc, reason))
        {
         TSMarkEventTerminal(symbol_index, slot, candidates[i].signal_msc,
                             "ORDER_SKIPPED", reason);
         continue;
        }
      g_events[slot].final_status = "POSITION_OPEN";
      g_symbols[symbol_index].machine.state = TS_POSITION_OPEN;
     }
  }

bool TSFindManagedPosition(ulong &ticket,long &identifier)
  {
   ticket = 0;
   identifier = 0;
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      ulong position_ticket = PositionGetTicket(i);
      if(position_ticket == 0 || (long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      ticket = position_ticket;
      identifier = (long)PositionGetInteger(POSITION_IDENTIFIER);
      return true;
     }
   return false;
  }

bool TSManagedPositionStillExists(const long identifier)
  {
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      if(PositionGetTicket(i) == 0 || (long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if((long)PositionGetInteger(POSITION_IDENTIFIER) == identifier)
         return true;
     }
   return false;
  }

bool TSModifyProtection(const double sl,const double tp)
  {
   ulong ticket=0;
   long identifier=0;
   if(!TSFindManagedPosition(ticket, identifier))
      return false;
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   request.action = TRADE_ACTION_SLTP;
   request.magic = InpMagicNumber;
   request.position = ticket;
   request.symbol = g_trade.symbol;
   request.sl = sl;
   request.tp = tp;
   if(!OrderSend(request, result))
      return false;
   return result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_NO_CHANGES;
  }

bool TSCloseManagedPosition(const string reason)
  {
   if(g_close_requested)
      return true;
   ulong ticket=0;
   long identifier=0;
   if(!TSFindManagedPosition(ticket, identifier))
      return false;
   if(!PositionSelectByTicket(ticket))
      return false;
   string symbol = PositionGetString(POSITION_SYMBOL);
   double volume = PositionGetDouble(POSITION_VOLUME);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   MqlTick quote;
   if(!SymbolInfoTick(symbol, quote) || quote.bid <= 0.0 || quote.ask <= quote.bid)
      return false;
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   request.action = TRADE_ACTION_DEAL;
   request.magic = InpMagicNumber;
   request.position = ticket;
   request.symbol = symbol;
   request.volume = volume;
   request.type = type == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = type == POSITION_TYPE_BUY ? quote.bid : quote.ask;
   request.deviation = InpMaxSlippagePoints;
   request.type_filling = TSFillingMode(symbol);
   request.comment = "TickShockExit";
   g_pending_exit_reason = reason;
   g_close_requested = true;
   if(!OrderSend(request, result) ||
      (result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_DONE_PARTIAL && result.retcode != TRADE_RETCODE_PLACED))
     {
      PrintFormat("%s: close failed reason=%s retcode=%u external=%d", TS_STRATEGY_NAME, reason, result.retcode, result.retcode_external);
      g_close_requested = false;
      return false;
     }
   return true;
  }

void TSHandleEntryFill(const ulong deal_ticket)
  {
   if(!g_trade.active || !HistoryDealSelect(deal_ticket))
      return;
   long deal_time_msc = (long)HistoryDealGetInteger(deal_ticket, DEAL_TIME_MSC);
   double fill = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
   double commission = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION) + HistoryDealGetDouble(deal_ticket, DEAL_FEE);
   g_trade.entry_filled = true;
   g_trade.entry_deal = deal_ticket;
   g_trade.position_id = (ulong)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
   g_trade.fill_msc = deal_time_msc;
   g_trade.execution_delay_ms = MathMax((long)0, deal_time_msc - g_trade.request_msc);
   g_trade.fill_price = fill;
   g_trade.slippage = g_trade.direction > 0 ? fill - g_trade.requested_price : g_trade.requested_price - fill;
   g_trade.commission += commission;
   double actual_risk_distance = g_trade.direction > 0 ? fill - g_trade.sl : g_trade.sl - fill;
   if(actual_risk_distance <= 0.0)
     {
      g_trade.exit_reason = "execution_guard";
      TSCloseManagedPosition("execution_guard");
      return;
     }
   double actual_loss = 0.0;
   ENUM_ORDER_TYPE order_type = g_trade.direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   bool risk_ok = OrderCalcProfit(order_type, g_trade.symbol, g_trade.volume, fill, g_trade.sl, actual_loss);
   actual_loss = MathAbs(actual_loss);
   bool excessive = !risk_ok || actual_loss > g_trade.risk_amount * (1.0 + InpExecutionRiskTolerancePct / 100.0);
   g_trade.risk_distance = actual_risk_distance;
   g_trade.risk_amount = actual_loss;
   int symbol_index = -1;
   for(int i = 0; i < ArraySize(g_symbols); ++i)
      if(g_symbols[i].symbol == g_trade.symbol) { symbol_index = i; break; }
   if(symbol_index < 0)
      excessive = true;
   if(!excessive)
     {
      double raw_tp = g_trade.direction > 0 ? fill + actual_risk_distance * InpRewardRisk : fill - actual_risk_distance * InpRewardRisk;
      g_trade.tp = TSNormalizePrice(symbol_index, raw_tp);
      if(!TSModifyProtection(g_trade.sl, g_trade.tp))
         excessive = true;
     }
   if(excessive)
     {
      g_trade.exit_reason = "execution_guard";
      TSCountSkip("execution_guard");
      TSCloseManagedPosition("execution_guard");
     }
  }

string TSDealReasonText(const ENUM_DEAL_REASON reason)
  {
   if(reason == DEAL_REASON_SL) return "SL";
   if(reason == DEAL_REASON_TP) return "TP";
   if(reason == DEAL_REASON_EXPERT) return "EXPERT";
   if(reason == DEAL_REASON_SO) return "STOP_OUT";
   return EnumToString(reason);
  }

void TSWriteTradeRow()
  {
   if(!g_trade.active || !g_trade.entry_filled || g_trade.close_msc <= 0)
      return;
   double holding_seconds = MathMax(0.0, (g_trade.close_msc - g_trade.fill_msc) / 1000.0);
   string line = "";
   TSCsvAppend(line, g_trade.event_id);
   TSCsvAppend(line, g_trade.symbol);
   TSCsvAppend(line, TSDirectionText(g_trade.direction));
   TSCsvAppend(line, TSLong(g_trade.signal_msc));
   TSCsvAppend(line, TSLong(g_trade.request_msc));
   TSCsvAppend(line, TSLong(g_trade.fill_msc));
   TSCsvAppend(line, TSLong(g_trade.decision_delay_ms));
   TSCsvAppend(line, TSLong(g_trade.execution_delay_ms));
   TSCsvAppend(line, TSDouble(g_trade.requested_price));
   TSCsvAppend(line, TSDouble(g_trade.fill_price));
   TSCsvAppend(line, TSDouble(g_trade.slippage));
   TSCsvAppend(line, TSDouble(g_trade.initial_spread));
   TSCsvAppend(line, TSDouble(g_trade.volume, 8));
   TSCsvAppend(line, TSDouble(g_trade.sl));
   TSCsvAppend(line, TSDouble(g_trade.tp));
   TSCsvAppend(line, TSDouble(g_trade.risk_distance));
   TSCsvAppend(line, TSDouble(g_trade.risk_amount, 2));
   TSCsvAppend(line, TSDouble(g_trade.planned_rr, 3));
   TSCsvAppend(line, TSLong(g_trade.close_msc));
   TSCsvAppend(line, TSDouble(g_trade.close_price));
   TSCsvAppend(line, TSDouble(holding_seconds, 3));
   TSCsvAppend(line, g_trade.exit_reason);
   TSCsvAppend(line, TSDouble(g_trade.gross_profit, 2));
   TSCsvAppend(line, TSDouble(g_trade.commission, 2));
   TSCsvAppend(line, TSDouble(g_trade.swap, 2));
   TSCsvAppend(line, TSDouble(g_trade.net_profit, 2));
   TSCsvAppend(line, TSDouble(g_trade.gross_r, 6));
   TSCsvAppend(line, TSDouble(g_trade.net_r, 6));
   TSCsvAppend(line, IntegerToString((int)g_trade.order_retcode));
   TSCsvAppend(line, IntegerToString(g_trade.order_retcode_external));
   TSCsvAppend(line, TSUlong(g_trade.order_ticket));
   TSCsvAppend(line, TSUlong(g_trade.entry_deal));
   TSCsvAppend(line, TSUlong(g_trade.exit_deal));
   if(g_trade_file != INVALID_HANDLE)
     {
      FileWriteString(g_trade_file, line + "\r\n");
      FileFlush(g_trade_file);
      ++g_trade_rows;
     }
  }

void TSHandleExitDeal(const ulong deal_ticket)
  {
   if(!g_trade.active || !HistoryDealSelect(deal_ticket))
      return;
   long position_id = (long)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
   if(g_trade.position_id != 0 && (long)g_trade.position_id != position_id)
      return;
   g_trade.gross_profit += HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
   g_trade.commission += HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION) + HistoryDealGetDouble(deal_ticket, DEAL_FEE);
   g_trade.swap += HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
   if(TSManagedPositionStillExists(position_id))
      return;
   g_trade.exit_deal = deal_ticket;
   g_trade.close_msc = (long)HistoryDealGetInteger(deal_ticket, DEAL_TIME_MSC);
   g_trade.close_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
   if(g_trade.exit_reason == "")
     {
      ENUM_DEAL_REASON deal_reason = (ENUM_DEAL_REASON)HistoryDealGetInteger(deal_ticket, DEAL_REASON);
      g_trade.exit_reason = g_pending_exit_reason != "" ? g_pending_exit_reason : TSDealReasonText(deal_reason);
     }
   g_trade.net_profit = g_trade.gross_profit + g_trade.commission + g_trade.swap;
   if(g_trade.risk_distance > 0.0)
      g_trade.gross_r = g_trade.direction > 0 ? (g_trade.close_price - g_trade.fill_price) / g_trade.risk_distance :
                                                (g_trade.fill_price - g_trade.close_price) / g_trade.risk_distance;
   if(g_trade.risk_amount > 0.0)
      g_trade.net_r = g_trade.net_profit / g_trade.risk_amount;
   double holding_seconds = MathMax(0.0, (g_trade.close_msc - g_trade.fill_msc) / 1000.0);
   int hold_bucket = (int)MathMin(120.0, MathFloor(holding_seconds));
   ++g_hold_histogram[hold_bucket];
   TSAggregateAdd(g_actual, g_trade.net_r, g_trade.exit_reason == "time_exit");
   g_actual_spread_sum += g_trade.initial_spread;
   g_actual_slippage_sum += g_trade.slippage;
   g_actual_hold_sum += holding_seconds;
   g_daily_result_r += g_trade.net_r;
   TSSaveDailyState();
   g_equity_curve_r += g_trade.net_r;
   g_peak_equity_curve_r = MathMax(g_peak_equity_curve_r, g_equity_curve_r);
   g_max_drawdown_r = MathMax(g_max_drawdown_r, g_peak_equity_curve_r - g_equity_curve_r);
   int symbol_index = -1;
   for(int i = 0; i < ArraySize(g_symbols); ++i)
      if(g_symbols[i].symbol == g_trade.symbol) { symbol_index = i; break; }
   if(symbol_index >= 0)
      TSAggregateAdd(g_symbol_stats[symbol_index], g_trade.net_r, g_trade.exit_reason == "time_exit");
   if(g_trade.event_slot >= 0 && g_trade.event_slot < TS_MAX_ACTIVE_EVENTS && g_events[g_trade.event_slot].active)
     {
      int session_index = TSSessionIndex(g_events[g_trade.event_slot].session);
      int alignment_index = TSAlignmentIndex(g_events[g_trade.event_slot].htf_alignment);
      TSAggregateAdd(g_session_stats[session_index], g_trade.net_r, g_trade.exit_reason == "time_exit");
      TSAggregateAdd(g_alignment_stats[alignment_index], g_trade.net_r, g_trade.exit_reason == "time_exit");
      TSMarkEventTerminal(g_events[g_trade.event_slot].symbol_index, g_trade.event_slot,
                          g_trade.close_msc, "TRADE_CLOSED", "");
     }
   TSWriteTradeRow();
   g_trade.active = false;
   g_pending_exit_reason = "";
   g_close_requested = false;
  }

void TSManageOpenPosition(const long processing_msc)
  {
   if(InpRunMode == EVENT_STUDY)
      return;
   if(!g_trade.active || !g_trade.entry_filled)
      return;
   if(TSHardTimeExpired(g_trade.fill_msc, processing_msc, InpMaxHoldSeconds))
      TSCloseManagedPosition("time_exit");
  }

string TSDailyStateKey(const string suffix)
  {
   return "TickShock." + TSLong(InpMagicNumber) + "." + suffix;
  }

void TSSaveDailyState()
  {
   if(g_is_tester)
      return;
   GlobalVariableSet(TSDailyStateKey("day"), (double)g_day_key);
   GlobalVariableSet(TSDailyStateKey("trades"), (double)g_daily_trades);
   GlobalVariableSet(TSDailyStateKey("result_r"), g_daily_result_r);
  }

void TSLoadDailyState()
  {
   if(g_is_tester || !GlobalVariableCheck(TSDailyStateKey("day")))
      return;
   int saved_day = (int)GlobalVariableGet(TSDailyStateKey("day"));
   if(saved_day != g_day_key)
      return;
   g_daily_trades = (int)GlobalVariableGet(TSDailyStateKey("trades"));
   g_daily_result_r = GlobalVariableGet(TSDailyStateKey("result_r"));
  }

void TSResetDailyState(const long processing_msc)
  {
   int key = TSDateKey((datetime)(processing_msc / 1000));
   if(key == g_day_key)
      return;
   g_day_key = key;
   g_daily_trades = 0;
   g_daily_result_r = 0.0;
   TSSaveDailyState();
  }

long TSCurrentProcessingMsc()
  {
   long latest = (long)TimeCurrent() * 1000;
   for(int i = 0; i < ArraySize(g_symbols); ++i)
     {
      MqlTick quote;
      if(SymbolInfoTick(g_symbols[i].symbol, quote))
         latest = MathMax(latest, (long)quote.time_msc);
     }
   return latest;
  }

void TSProcessOneTickForContext(TSSymbolContext &context,
                                const int symbol_index,
                                const MqlTick &source,
                                const long processing_msc,
                                TSEntryCandidate &candidates[])
  {
   if(source.bid <= 0.0 || source.ask <= source.bid || source.time_msc <= 0)
      return;
   TSAddShortTick(context, source);
   ++context.ticks_processed;
   ++g_total_ticks_processed;
   TSShortTick tick;
   tick.time_msc = (long)source.time_msc;
   tick.bid = source.bid;
   tick.ask = source.ask;
   tick.mid = (source.bid + source.ask) * 0.5;
   TSUpdateEventTracking(symbol_index, tick);
   if(context.machine.state == TS_COOLDOWN && TSCooldownComplete(tick.time_msc, context.cooldown_until_msc))
      TSReset(context.machine);
   if(context.machine.state == TS_SCANNING)
      TSDetectShock(symbol_index, tick, processing_msc);
   else
      TSAdvanceStateMachine(symbol_index, tick, candidates);
  }

void TSProcessOneTick(const int symbol_index,
                      const MqlTick &source,
                      const long processing_msc,
                      TSEntryCandidate &candidates[])
  {
   TSProcessOneTickForContext(g_symbols[symbol_index], symbol_index, source, processing_msc, candidates);
  }

void TSDrainSymbolContext(TSSymbolContext &context,
                          const int symbol_index,
                          const long processing_msc,
                          TSEntryCandidate &candidates[])
  {
   int loops = 0;
   while(loops < 64)
     {
      ++loops;
      MqlTick copied[];
      ulong from_msc = context.last_time_msc > 0 ? (ulong)context.last_time_msc : 0;
      int requested = context.last_time_msc > 0 ? TS_MAX_COPY_TICKS : 1;
      ResetLastError();
      int count = CopyTicks(context.symbol, copied, COPY_TICKS_INFO, from_msc, requested);
      if(count <= 0)
        {
         int error = GetLastError();
         if(error != 0)
            TSDebug(context.symbol, processing_msc, "CopyTicks failed err=" + IntegerToString(error));
         return;
        }
      int seen_at_boundary = 0;
      int processed = 0;
      long before_time = context.last_time_msc;
      int before_count = context.processed_at_last_msc;
      for(int i = 0; i < count; ++i)
        {
         long time_msc = (long)copied[i].time_msc;
         if(before_time > 0 && time_msc < before_time)
           {
            ++context.duplicate_ticks_skipped;
            continue;
           }
         if(before_time > 0 && time_msc == before_time)
           {
            ++seen_at_boundary;
            if(seen_at_boundary <= before_count)
              {
               ++context.duplicate_ticks_skipped;
               continue;
              }
           }
         if(time_msc != context.last_time_msc)
           {
            context.last_time_msc = time_msc;
            context.processed_at_last_msc = 0;
           }
         TSProcessOneTick(symbol_index, copied[i], processing_msc, candidates);
         ++context.processed_at_last_msc;
         ++processed;
        }
      if(count < requested)
         break;
      if(processed == 0 && context.last_time_msc == before_time && context.processed_at_last_msc == before_count)
         break;
     }
  }

void TSDrainSymbol(const int symbol_index,
                   const long processing_msc,
                   TSEntryCandidate &candidates[])
  {
   TSDrainSymbolContext(g_symbols[symbol_index], symbol_index, processing_msc, candidates);
  }

void TSSampleMemory()
  {
   long used_mb = (long)MQLInfoInteger(MQL_MEMORY_USED);
   if(used_mb < 0)
      return;
   ++g_memory_samples;
   g_memory_sum_mb += (double)used_mb;
   g_memory_max_mb = MathMax(g_memory_max_mb, used_mb);
  }

void TSDispatcher()
  {
   long processing_msc = TSCurrentProcessingMsc();
   TSResetDailyState(processing_msc);
   TSEntryCandidate candidates[];
   ArrayResize(candidates, 0);
   for(int i = 0; i < ArraySize(g_symbols); ++i)
      TSDrainSymbol(i, processing_msc, candidates);
   TSProcessCandidates(candidates, processing_msc);
   TSManageOpenPosition(processing_msc);
   TSSampleMemory();
  }

double TSHoldPercentile(const double percentile)
  {
   if(g_actual.count <= 0)
      return 0.0;
   long target = (long)MathCeil(g_actual.count * percentile / 100.0);
   long cumulative = 0;
   for(int second = 0; second <= 120; ++second)
     {
      cumulative += g_hold_histogram[second];
      if(cumulative >= target)
         return second;
     }
   return 120.0;
  }

void TSWriteSummaryRow(const string record_type,
                       const string key,
                       const TSAggregate &aggregate,
                       const string value="")
  {
   if(g_summary_file == INVALID_HANDLE)
      return;
   double win_rate = aggregate.count > 0 ? (double)aggregate.wins / aggregate.count * 100.0 : 0.0;
   double avg_win = aggregate.wins > 0 ? aggregate.sum_wins_r / aggregate.wins : 0.0;
   double avg_loss = aggregate.losses > 0 ? aggregate.sum_losses_r / aggregate.losses : 0.0;
   double expectancy = aggregate.count > 0 ? aggregate.sum_r / aggregate.count : 0.0;
   double pf = aggregate.gross_negative_r > 0.0 ? aggregate.gross_positive_r / aggregate.gross_negative_r : 0.0;
   double avg_memory = g_memory_samples > 0 ? g_memory_sum_mb / g_memory_samples : 0.0;
   double avg_hold = aggregate.count > 0 && record_type == "OVERALL" ? g_actual_hold_sum / aggregate.count : 0.0;
   double avg_spread = aggregate.count > 0 && record_type == "OVERALL" ? g_actual_spread_sum / aggregate.count : 0.0;
   double avg_slippage = aggregate.count > 0 && record_type == "OVERALL" ? g_actual_slippage_sum / aggregate.count : 0.0;
   TSAggregate continuation_aggregate = g_continuation_shadow;
   TSAggregate reversal_aggregate = g_reversal_shadow;
   if(record_type == "SYMBOL")
     {
      for(int i = 0; i < ArraySize(g_symbols); ++i)
         if(g_symbols[i].symbol == key)
           {
            continuation_aggregate = g_symbol_continuation_shadow[i];
            reversal_aggregate = g_symbol_reversal_shadow[i];
            break;
           }
     }
   else if(record_type == "SESSION")
     {
      int index = TSSessionIndex(key);
      continuation_aggregate = g_session_continuation_shadow[index];
      reversal_aggregate = g_session_reversal_shadow[index];
     }
   else if(record_type == "HTF_ALIGNMENT")
     {
      int index = TSAlignmentIndex(key);
      continuation_aggregate = g_alignment_continuation_shadow[index];
      reversal_aggregate = g_alignment_reversal_shadow[index];
     }
   else if(record_type != "OVERALL")
     {
      ZeroMemory(continuation_aggregate);
      ZeroMemory(reversal_aggregate);
     }
   double cont_expectancy = continuation_aggregate.count > 0 ? continuation_aggregate.sum_r / continuation_aggregate.count : 0.0;
   double rev_expectancy = reversal_aggregate.count > 0 ? reversal_aggregate.sum_r / reversal_aggregate.count : 0.0;
   ulong event_bytes = g_event_file != INVALID_HANDLE ? FileSize(g_event_file) : 0;
   ulong trade_bytes = g_trade_file != INVALID_HANDLE ? FileSize(g_trade_file) : 0;
   double runtime_seconds = (GetTickCount64() - g_started_tick_count) / 1000.0;
   long row_events = 0;
   long row_bursts = 0;
   long row_pullbacks = 0;
   long row_reaccelerations = 0;
   if(record_type == "OVERALL")
     {
      row_events = g_valid_shock_events;
      row_bursts = g_valid_bursts;
      row_pullbacks = g_valid_pullbacks;
      row_reaccelerations = g_reacceleration_signals;
     }
   else if(record_type == "SYMBOL")
     {
      for(int i = 0; i < ArraySize(g_symbols); ++i)
         if(g_symbols[i].symbol == key)
           {
            row_events = g_symbols[i].events_detected;
            row_bursts = g_symbols[i].bursts_frozen;
            row_pullbacks = g_symbols[i].valid_pullbacks;
            row_reaccelerations = g_symbols[i].reacceleration_signals;
            break;
           }
     }
   else if(record_type == "SESSION")
     {
      int index = TSSessionIndex(key);
      row_events = g_session_events[index];
      row_bursts = g_session_bursts[index];
      row_pullbacks = g_session_pullbacks[index];
      row_reaccelerations = g_session_reaccelerations[index];
     }
   else if(record_type == "HTF_ALIGNMENT")
     {
      int index = TSAlignmentIndex(key);
      row_events = g_alignment_events[index];
      row_bursts = g_alignment_bursts[index];
      row_pullbacks = g_alignment_pullbacks[index];
      row_reaccelerations = g_alignment_reaccelerations[index];
     }
   string line = "";
   TSCsvAppend(line, InpRunId);
   TSCsvAppend(line, TSModeText());
   TSCsvAppend(line, record_type);
   TSCsvAppend(line, key);
   TSCsvAppend(line, TSLong(row_events));
   TSCsvAppend(line, TSLong(row_bursts));
   TSCsvAppend(line, TSLong(row_pullbacks));
   TSCsvAppend(line, TSLong(row_reaccelerations));
   TSCsvAppend(line, TSLong(aggregate.count));
   TSCsvAppend(line, TSLong(aggregate.wins));
   TSCsvAppend(line, TSLong(aggregate.losses));
   TSCsvAppend(line, TSLong(aggregate.time_exits));
   TSCsvAppend(line, TSDouble(win_rate, 4));
   TSCsvAppend(line, TSDouble(avg_win, 6));
   TSCsvAppend(line, TSDouble(avg_loss, 6));
   TSCsvAppend(line, TSDouble(expectancy, 6));
   TSCsvAppend(line, TSDouble(pf, 6));
   TSCsvAppend(line, TSDouble(g_max_drawdown_r, 6));
   TSCsvAppend(line, TSDouble(avg_hold, 3));
   TSCsvAppend(line, record_type == "OVERALL" ? TSDouble(TSHoldPercentile(50.0), 1) : "");
   TSCsvAppend(line, record_type == "OVERALL" ? TSDouble(TSHoldPercentile(95.0), 1) : "");
   TSCsvAppend(line, TSDouble(avg_spread));
   TSCsvAppend(line, TSDouble(avg_slippage));
   TSCsvAppend(line, TSLong(continuation_aggregate.count));
   TSCsvAppend(line, TSDouble(cont_expectancy, 6));
   TSCsvAppend(line, TSLong(reversal_aggregate.count));
   TSCsvAppend(line, TSDouble(rev_expectancy, 6));
   TSCsvAppend(line, TSDouble(avg_memory, 3));
   TSCsvAppend(line, TSLong(g_memory_max_mb));
   TSCsvAppend(line, TSLong(g_event_rows));
   TSCsvAppend(line, TSUlong(event_bytes));
   TSCsvAppend(line, TSLong(g_trade_rows));
   TSCsvAppend(line, TSUlong(trade_bytes));
   TSCsvAppend(line, TSDouble(runtime_seconds, 3));
   TSCsvAppend(line, value);
   FileWriteString(g_summary_file, line + "\r\n");
  }

void TSWriteFinalSummary()
  {
   for(int slot = 0; slot < TS_MAX_ACTIVE_EVENTS; ++slot)
     {
      if(!g_events[slot].active || g_events[slot].csv_written)
         continue;
      if(!g_events[slot].terminal)
        {
         g_events[slot].terminal = true;
         g_events[slot].final_status = "DEINIT_INCOMPLETE";
         if(g_events[slot].skip_reason == "") g_events[slot].skip_reason = "deinit_incomplete";
        }
      TSWriteEventRow(slot);
     }
   FileFlush(g_event_file);
   FileFlush(g_trade_file);
   TSWriteSummaryRow("OVERALL", "ALL", g_actual,
                     "raw_shock_candidates=" + TSLong(g_raw_shock_candidates) +
                     ";ticks_processed=" + TSLong(g_total_ticks_processed));
   for(int i = 0; i < ArraySize(g_symbols); ++i)
      TSWriteSummaryRow("SYMBOL", g_symbols[i].symbol, g_symbol_stats[i],
                        "raw_candidates=" + TSLong(g_symbols[i].raw_candidates) +
                        ";ticks=" + TSLong(g_symbols[i].ticks_processed) +
                        ";duplicates=" + TSLong(g_symbols[i].duplicate_ticks_skipped) +
                        ";events=" + TSLong(g_symbols[i].events_detected));
   string sessions[TS_SESSION_COUNT] = {"TOKYO","LONDON","NEW_YORK","OVERLAP","OTHER"};
   for(int i = 0; i < TS_SESSION_COUNT; ++i)
      TSWriteSummaryRow("SESSION", sessions[i], g_session_stats[i]);
   string alignments[TS_ALIGNMENT_COUNT] = {"BOTH_ALIGNED","M15_ONLY","H1_ONLY","CONFLICT","NEUTRAL","UNAVAILABLE","OTHER"};
   for(int i = 0; i < TS_ALIGNMENT_COUNT; ++i)
      TSWriteSummaryRow("HTF_ALIGNMENT", alignments[i], g_alignment_stats[i]);
   string pre_names[TS_PRE_SKIP_COUNT] = {"insufficient_baseline","stale_quote","invalid_robust_scale","shock_percentile_failed","shock_z_failed","efficiency_failed","tick_intensity_failed","move_spread_failed","spread_too_wide"};
   for(int s = 0; s < ArraySize(g_symbols); ++s)
      for(int r = 0; r < TS_PRE_SKIP_COUNT; ++r)
        {
         TSAggregate empty;
         ZeroMemory(empty);
         TSWriteSummaryRow("PRE_SHOCK_SKIP", g_symbols[s].symbol + ":" + pre_names[r], empty,
                           TSLong(g_pre_skip[s * TS_PRE_SKIP_COUNT + r]));
        }
   for(int i = 0; i < ArraySize(g_skip_reason_name); ++i)
     {
      TSAggregate empty;
      ZeroMemory(empty);
      TSWriteSummaryRow("EVENT_SKIP", g_skip_reason_name[i], empty, TSLong(g_skip_reason_count[i]));
     }
   TSAggregate empty;
   ZeroMemory(empty);
   TSWriteSummaryRow("BUFFER", "second_samples_per_symbol_max", empty, IntegerToString(TS_SECOND_CAPACITY));
   TSWriteSummaryRow("BUFFER", "tick_samples_per_symbol_max", empty, IntegerToString(TS_TICK_CAPACITY));
   TSWriteSummaryRow("BUFFER", "tick_retention_condition", empty, "older_than_5000ms_or_capacity_4096");
   TSWriteSummaryRow("BUFFER", "active_event_slots_max", empty, IntegerToString(TS_MAX_ACTIVE_EVENTS));
   TSWriteSummaryRow("LOG_POLICY", "tick_or_second_csv", empty, "disabled");
   FileFlush(g_summary_file);
  }

void TSInitializeSkipReasons()
  {
   string required[] = {
      "pullback_too_shallow","pullback_too_deep","pullback_timeout","no_reacceleration",
      "continuation_invalidated","stop_too_narrow_for_broker","stop_too_wide_vs_burst",
      "cost_too_large_vs_risk","volume_below_minimum","margin_rejected","position_already_open",
      "netting_position_conflict","lower_ranked_candidate","symbol_cooldown","global_cooldown",
      "daily_loss_limit","daily_trade_limit","rollover_block","order_rejected","execution_guard"
   };
   for(int i = 0; i < ArraySize(required); ++i)
      TSSkipReasonIndex(required[i]);
  }

bool TSRestoreExistingPosition()
  {
   int managed_count = TSCountManagedPositions();
   if(managed_count > 1)
     {
      PrintFormat("%s: %d managed positions found although the design cap is one; new entries remain blocked",
                  TS_STRATEGY_NAME, managed_count);
      return false;
     }
   ulong ticket=0;
   long identifier=0;
   if(!TSFindManagedPosition(ticket, identifier))
      return true;
   if(!PositionSelectByTicket(ticket))
      return false;
   ZeroMemory(g_trade);
   g_close_requested = false;
   g_trade.active = true;
   g_trade.entry_filled = true;
   g_trade.event_id = "RECOVERED_" + TSUlong(ticket);
   g_trade.event_slot = -1;
   g_trade.symbol = PositionGetString(POSITION_SYMBOL);
   ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   g_trade.direction = type == POSITION_TYPE_BUY ? 1 : -1;
   g_trade.fill_msc = (long)PositionGetInteger(POSITION_TIME_MSC);
   g_trade.signal_msc = g_trade.fill_msc;
   g_trade.request_msc = g_trade.fill_msc;
   g_trade.fill_price = PositionGetDouble(POSITION_PRICE_OPEN);
   g_trade.requested_price = g_trade.fill_price;
   g_trade.volume = PositionGetDouble(POSITION_VOLUME);
   g_trade.sl = PositionGetDouble(POSITION_SL);
   g_trade.tp = PositionGetDouble(POSITION_TP);
   g_trade.position_id = (ulong)identifier;
   g_trade.order_ticket = ticket;
   g_trade.risk_distance = g_trade.direction > 0 ? g_trade.fill_price - g_trade.sl : g_trade.sl - g_trade.fill_price;
   double loss = 0.0;
   ENUM_ORDER_TYPE order_type = g_trade.direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(g_trade.sl > 0.0 && !OrderCalcProfit(order_type, g_trade.symbol, g_trade.volume, g_trade.fill_price, g_trade.sl, loss))
      loss = 0.0;
   g_trade.risk_amount = MathAbs(loss);
   MqlTick quote;
   if(SymbolInfoTick(g_trade.symbol, quote)) g_trade.initial_spread = quote.ask - quote.bid;
   if(g_trade.sl <= 0.0 || g_trade.tp <= 0.0 || g_trade.risk_distance <= 0.0 || g_trade.risk_amount <= 0.0)
     {
      PrintFormat("%s: recovered position %I64u lacks reconstructable protection; close requested when trading mode permits",
                  TS_STRATEGY_NAME, ticket);
      if(InpRunMode != EVENT_STUDY)
         TSCloseManagedPosition("restart_recovery_failure");
     }
   else
      PrintFormat("%s: recovered managed position ticket=%I64u symbol=%s", TS_STRATEGY_NAME, ticket, g_trade.symbol);
   return true;
  }

bool TSInputsValid()
  {
   return InpShockWindowMs > 0 && InpBaselineMinutes > 0 && InpBaselineExcludeMs >= 0 &&
          InpMinBaselineSamples > 0 && InpMinBaselineSamples <= TS_SECOND_CAPACITY &&
          InpShockPercentile > 0.0 && InpShockPercentile < 100.0 && InpMinRobustZ > 0.0 &&
          InpMinEfficiency > 0.0 && InpMinEfficiency <= 1.0 && InpMinMoveSpreadRatio > 0.0 &&
          InpMinTickIntensityRatio > 0.0 && InpMaxSpreadMedianRatio > 0.0 &&
          InpBurstQuietMs > 0 && InpBurstMaxMs >= InpBurstQuietMs &&
          InpPullbackMinPct > 0.0 && InpPullbackMaxPct > InpPullbackMinPct &&
          InpContinuationInvalidPct > InpPullbackMaxPct && InpPullbackWaitMs > 0 &&
          InpReaccelerationConfirmTicks > 0 && InpRewardRisk > 0.0 && InpMaxHoldSeconds > 0 &&
          InpSymbolCooldownSeconds >= 0 && InpGlobalCooldownSeconds >= 0 && InpMagicNumber > 0 &&
          InpRiskPercent > 0.0 && InpFixedLot > 0.0 && InpDailyLossLimitR > 0.0 &&
          InpMaxTradesPerDay > 0 && InpCommissionPerLotRoundTurn >= 0.0 && InpDebugMaxMessages >= 0;
  }

int OnInit()
  {
   g_started_tick_count = GetTickCount64();
   g_is_tester = (bool)MQLInfoInteger(MQL_TESTER);
   if(!TSInputsValid() || !TSParseClock(InpRolloverBlockStart, g_rollover_start_minute) ||
      !TSParseClock(InpRolloverBlockEnd, g_rollover_end_minute))
     {
      PrintFormat("%s: invalid inputs", TS_STRATEGY_NAME);
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpRunMode == LIVE_TRADE && g_is_tester)
     {
      PrintFormat("%s: LIVE_TRADE is not valid in Strategy Tester", TS_STRATEGY_NAME);
      return INIT_PARAMETERS_INCORRECT;
     }
   if(!TSParseSymbols())
      return INIT_FAILED;
   TSInitializeSkipReasons();
   if(!TSOpenLogs())
     {
      TSReleaseSymbols();
      return INIT_FAILED;
     }
   g_day_key = TSDateKey(TimeCurrent());
   TSLoadDailyState();
   if(!TSRestoreExistingPosition())
     {
      TSCloseLogs();
      TSReleaseSymbols();
      return INIT_FAILED;
     }
   if(!g_is_tester && !EventSetMillisecondTimer(50))
     {
      PrintFormat("%s: EventSetMillisecondTimer(50) failed err=%d", TS_STRATEGY_NAME, GetLastError());
      TSCloseLogs();
      TSReleaseSymbols();
      return INIT_FAILED;
     }
   PrintFormat("%s initialized mode=%s symbols=%d timer=%s second_cap=%d tick_cap=%d",
               TS_STRATEGY_NAME, TSModeText(), ArraySize(g_symbols), g_is_tester ? "tester_OnTick_dispatch" : "50ms", TS_SECOND_CAPACITY, TS_TICK_CAPACITY);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(!g_is_tester)
      EventKillTimer();
   TSWriteFinalSummary();
   TSCloseLogs();
   TSReleaseSymbols();
   if(g_trade.active)
      PrintFormat("%s: deinit with protected managed position still open; it will be recovered by magic number on restart", TS_STRATEGY_NAME);
   PrintFormat("%s deinitialized reason=%d event_rows=%I64d trade_rows=%I64d", TS_STRATEGY_NAME, reason, g_event_rows, g_trade_rows);
  }

void OnTick()
  {
   if(g_is_tester)
      TSDispatcher();
  }

void OnTimer()
  {
   if(!g_is_tester)
      TSDispatcher();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0 || !HistoryDealSelect(trans.deal))
      return;
   if((long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagicNumber)
      return;
   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry == DEAL_ENTRY_IN)
      TSHandleEntryFill(trans.deal);
   else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT || entry == DEAL_ENTRY_OUT_BY)
      TSHandleExitDeal(trans.deal);
  }
