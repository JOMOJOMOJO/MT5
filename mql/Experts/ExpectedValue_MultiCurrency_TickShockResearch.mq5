#property copyright "OpenAI"
#property version   "4.00"
#property strict

#include "..\Include\TickShockStateMachine.mqh"
#include "..\Include\TickShockResearchExecution.mqh"
#include "..\Include\TickShock\TickShockEngine.mqh"
#include "..\Include\TickShock\TickShockCsvSerializer.mqh"
#include "..\Include\TickShock\TickShockMt5Adapter.mqh"
#include "..\Include\TickShock\TickShockStatisticalCalibration.mqh"

// Research-only EA.  This file contains no OrderCheck/OrderSend call.
// IDEAL_EVENT_STUDY is event-time research only.  REALIZABLE_EA includes the
// actual global-watermark recognition time and is the only formal analysis mode.

input string InpSymbols = "EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD,USDCHF";
input ENUM_TS_V1_DETECTOR InpDetectorVersion = STRICT_V0;
input int InpGridMs = 250;
input int InpBaselineMinutes = 15;
input int InpBaselineExcludeMs = 2000;
input int InpMinBaselineSamples = 300;
input double InpShockPercentile = 99.5;
input double InpMinRobustZ = 3.5;
input double InpMinEfficiency = 0.65;
input double InpMinMoveSpreadRatio = 4.0;
input double InpMinTickIntensityRatio = 1.5;
input double InpMaxSpreadMedianRatio = 1.5;
input int InpMaxQuoteAgeMs = 500;
input double InpNoiseFloorTicks = 1.0;
input int InpBurstQuietMs = 300;
input int InpBurstMaxMs = 3000;
input double InpPullbackMinPct = 15.0;
input double InpPullbackMaxPct = 35.0;
input double InpContinuationInvalidPct = 50.0;
input int InpPullbackWaitMs = 10000;
input int InpReaccelerationConfirmTicks = 2;
input double InpRewardRisk = 1.2;
input int InpMaxHoldSeconds = 120;
input double InpShadowSlippageTicks = 1.0;
input double InpShadowExitSlippageTicks = 1.0;
input double InpCommissionPerLotRoundTurn = 0.0;
input string InpCommissionSource = "ORDER_HARNESS_REQUIRED";
input ENUM_TS_COMMISSION_EVIDENCE_STATUS InpCommissionEvidenceStatus = TS_COMMISSION_EVIDENCE_UNAVAILABLE;
input string InpCommissionSymbolScope = "ALL_CONFIGURED_SYMBOLS";
input string InpCommissionUnit = "ACCOUNT_CURRENCY_PER_LOT_ROUND_TURN";
input ENUM_TS_RESEARCH_EXECUTION_MODE InpExecutionMode = REALIZABLE_EA;
input int InpSubmitLatencyMs = 0;
input int InpTokyoStartHour = 0;
input int InpTokyoEndHour = 9;
input int InpLondonStartHour = 8;
input int InpLondonEndHour = 17;
input int InpNewYorkStartHour = 13;
input int InpNewYorkEndHour = 22;
input string InpRunId = "research_v2";
input string InpLogFolder = "tick_shock_research";
input bool InpResumeRun = false;
input string InpResumeCheckpoint = "";
input long InpResumeLastEventSequence = -1;
input long InpResumeCursorMsc = 0;
input string InpResearchPeriod = "UNSPECIFIED";
input string InpTesterModel = "REAL_TICKS";
input string InpSourceCommit = "UNSPECIFIED";
input string InpEx5Hash = "UNSPECIFIED";
input string InpSchemaVersion = "tickshock-event-v1";
input bool InpEnableDebug = false;
input string InpDebugSymbol = "EURUSD";
input int InpDebugMaxMessages = 200;

#define TSR_DETECTOR_COUNT 3
#define TSR_SAMPLE_CAPACITY 3612
#define TSR_MOVE_HIST_BINS 2048
#define TSR_TICK_HIST_BINS 1024
#define TSR_SPREAD_HIST_BINS 1024
#define TSR_TICK_CAPACITY 8192
#define TSR_TICK_RETENTION_MS 5000
#define TSR_GRID_CAPACITY 64
#define TSR_MAX_ACTIVE_EVENTS 64
#define TSR_PENDING_CAPACITY 65536
#define TSR_CHECKPOINT_COUNT 6
#define TSR_STRATEGY_COUNT 4
#define TSR_STOP_COUNT 23
#define TSR_DELAY_COUNT 3
#define TSR_SPREAD_COUNT 2
#define TSR_SCENARIO_COUNT 138
#define TSR_ALL_SCENARIOS 552
#define TSR_EXECUTION_GROUP_COUNT 24
#define TSR_MAX_COPY_TICKS 8192
#define TSR_PRE_SKIP_COUNT 10
#define TSR_SESSION_COUNT 5
#define TSR_GATE_COUNT 6
#define TSR_GATE_MASK_COUNT 64

const string TSR_NAME = "ExpectedValue_MultiCurrency_TickShockResearch";
const string TSR_IMPLEMENTATION_SCHEMA = "tickshock-research-step15a-v1";
const int TSR_CHECKPOINT_SECONDS[TSR_CHECKPOINT_COUNT] = {5,10,20,30,60,120};
const int TSR_DETECTOR_MS[TSR_DETECTOR_COUNT] = {250,500,1000};
const int TSR_DELAY_MS[TSR_DELAY_COUNT] = {0,100,250};
const double TSR_SPREAD_MULT[TSR_SPREAD_COUNT] = {1.0,1.25};

int TSRRequiredSampleCapacity(const int detector)
  {
   if(detector<0 || detector>=TSR_DETECTOR_COUNT) return 0;
   return TSBaselineRequiredCapacity(TSR_DETECTOR_MS[detector],InpBaselineMinutes,InpBaselineExcludeMs);
  }

int TSRSampleCapacity(const int detector)
  {
   return MathMin(TSR_SAMPLE_CAPACITY,TSRRequiredSampleCapacity(detector));
  }

enum ENUM_TSR_STRATEGY
  {
   TSR_DETECTION_CONTINUATION = 0,
   TSR_POST_BURST_CONTINUATION = 1,
   TSR_PULLBACK_CONTINUATION = 2,
   TSR_FAILED_SHOCK_REVERSAL = 3
  };

struct TSRShortTick
  {
   long time_msc;
   double bid;
   double ask;
   double mid;
  };

struct TSRGridPoint
  {
   long time_msc;
   long quote_msc;
   double bid;
   double ask;
   double mid;
   double robust_mid;
   bool robust_valid;
   int quote_age_ms;
   bool valid;
  };

struct TSRV1Candidate
  {
   bool active;
   long candidate_msc;
   int direction;
   int trigger_horizon_index;
   int horizon_mask;
   TSRGridPoint candidate_point;
   double anchor_mid;
   double estimator_anchor_mid;
   double raw_p[TSV1_HORIZON_COUNT];
   double adjusted_p[TSV1_HORIZON_COUNT];
   bool tail_valid[TSV1_HORIZON_COUNT];
   double score[TSV1_HORIZON_COUNT];
   double local_sigma[TSV1_HORIZON_COUNT];
   int baseline_count[TSV1_HORIZON_COUNT];
   int calibration_count[TSV1_HORIZON_COUNT];
   int tod_bucket;
   int volatility_regime;
   double noise_return;
   double efficiency;
   int tick_count;
   double tick_intensity_ratio;
   double spread_median;
   double move_spread_ratio;
   double spread_ratio;
   TickShockV1Diagnostics diagnostics;
  };

struct TSRSecondSample
  {
   long end_msc;
   double start_mid;
   double end_mid;
   double signed_log_return;
   double abs_log_return;
   double price_move;
   int tick_count;
   double spread;
   int quote_age_ms;
  };

struct TSRScenario
  {
   bool initialized;
   bool pending;
   bool active;
   bool done;
   int direction;
   TSResearchSignalClock signal_clock;
   TSResearchEntryClock entry_clock;
   long signal_event_msc;
   long signal_processing_msc;
   long entry_eligible_msc;
   long entry_quote_msc;
   long exit_msc;
   double spread_multiplier;
   double stop_multiple;
   double base_spread;
   double requested_risk;
   double entry;
   double sl;
   double tp;
   double risk;
   double requested_rr;
   double realized_rr;
   double stops_distance;
   double freeze_distance;
   bool freeze_clear;
   double commission_r;
   double gross_r;
   double result_r;
   double exit_price;
   double stop_gap;
   double exit_slippage;
   int policy_mask;
   ENUM_TS_SCENARIO_STATUS status;
  };

struct TSREvent
  {
   bool active;
   bool terminal;
   bool csv_written;
   int symbol_index;
   string event_id;
   int direction;
   int detector_window_ms;
   long symbol_cluster_id;
   long market_cluster_id;
   bool symbol_overlap_event;
   bool market_overlap_event;
   int shock_gate_mask;
   ENUM_TS_V1_DETECTOR detector_version;
   long detector_candidate_msc;
   long detector_confirmed_msc;
   int detector_trigger_horizon_ms;
   int detector_horizon_mask;
   double detector_raw_p[TSV1_HORIZON_COUNT];
   double detector_adjusted_p[TSV1_HORIZON_COUNT];
   bool detector_tail_valid[TSV1_HORIZON_COUNT];
   double detector_score;
   double detector_local_sigma;
   int detector_local_samples;
   int detector_calibration_samples;
   double detector_quantile_half_width;
   int detector_tod_bucket;
   int detector_volatility_regime;
   double detector_noise_return;
   TickShockV1Diagnostics detector_diagnostics;
   long detection_msc;
   long detection_grid_msc;
   long detection_quote_msc;
   int detection_quote_age_ms;
   long processing_msc;
   long decision_delay_ms;
   double detection_bid;
   double detection_ask;
   double detection_mid;
   double shock_start_mid;
   double detection_shock_range;
   double log_return_250;
   double log_return_500;
   double log_return_1000;
   bool log_return_250_valid;
   bool log_return_500_valid;
   bool log_return_1000_valid;
   double percentile_threshold;
   double median_abs_return;
   double mad_abs_return;
   double robust_scale;
   bool robust_scale_floored;
   double robust_z;
   double efficiency;
   int tick_count;
   double tick_intensity_ratio;
   double spread;
   double spread_median;
   double move_spread_ratio;
   int quote_age_ms;
   int baseline_samples;
   TickShockMachine machine;
   long burst_end_msc;
   double burst_end_bid;
   double burst_end_ask;
   double burst_end_mid;
   double burst_range;
   double max_retracement_pct;
   long pullback_msc;
   long reacceleration_msc;
   long reversal_arm_msc;
   long continuation_invalidated_msc;
   string state_status;
   string state_skip_reason;
   string m15_trend;
   string h1_trend;
   string htf_alignment;
   string session;
   string news_label;
   bool signal_started[TSR_STRATEGY_COUNT];
   long signal_arm_msc[TSR_STRATEGY_COUNT];
   long signal_event_msc[TSR_STRATEGY_COUNT];
   long signal_processing_msc[TSR_STRATEGY_COUNT];
   int signal_direction[TSR_STRATEGY_COUNT];
   double signal_bid[TSR_STRATEGY_COUNT];
   double signal_ask[TSR_STRATEGY_COUNT];
   TSRScenario scenarios[TSR_ALL_SCENARIOS];
   int next_active_stop[TSR_EXECUTION_GROUP_COUNT];
   bool detection_checkpoint_done[TSR_CHECKPOINT_COUNT];
   double detection_checkpoint_bid[TSR_CHECKPOINT_COUNT];
   double detection_checkpoint_ask[TSR_CHECKPOINT_COUNT];
   double detection_checkpoint_mfe[TSR_CHECKPOINT_COUNT];
   double detection_checkpoint_mae[TSR_CHECKPOINT_COUNT];
   double detection_best_mid;
   double detection_worst_mid;
   bool burst_checkpoint_started;
   bool burst_checkpoint_done[TSR_CHECKPOINT_COUNT];
   double burst_checkpoint_bid[TSR_CHECKPOINT_COUNT];
   double burst_checkpoint_ask[TSR_CHECKPOINT_COUNT];
   double burst_checkpoint_mfe[TSR_CHECKPOINT_COUNT];
   double burst_checkpoint_mae[TSR_CHECKPOINT_COUNT];
   double burst_best_mid;
   double burst_worst_mid;
  };

struct TSRSymbolContext
  {
   string symbol;
   int digits;
   double point;
   double tick_size;
   double tick_value;
   double contract_size;
   double volume_min;
   double volume_max;
   double volume_step;
   int stops_level;
   int freeze_level;
   int filling_mode;
   long last_time_msc;
   int processed_at_last_msc;
   TickShockSymbolFrontierState frontier;
   long duplicate_ticks_skipped;
   long ticks_processed;
   TSRShortTick ticks[];
   TickShockRingState tick_ring;
   TSRGridPoint grid[];
   TickShockRingState grid_ring;
   TSRSecondSample samples250[];
   TSRSecondSample samples500[];
   TSRSecondSample samples1000[];
   TickShockRingState sample_ring[TSR_DETECTOR_COUNT];
   TickShockGridRuntime grid_runtime;
   TickShockV1CalibrationContext v1_calibration;
   TSRV1Candidate v1_pending_candidate;
   int ticks_since_window[TSR_DETECTOR_COUNT];
   long baseline_cache_msc[TSR_DETECTOR_COUNT];
   int baseline_samples[TSR_DETECTOR_COUNT];
   double baseline_percentile[TSR_DETECTOR_COUNT];
   double baseline_median[TSR_DETECTOR_COUNT];
   double baseline_mad[TSR_DETECTOR_COUNT];
   double baseline_scale[TSR_DETECTOR_COUNT];
   bool baseline_scale_floored[TSR_DETECTOR_COUNT];
   double baseline_median_ticks[TSR_DETECTOR_COUNT];
   double spread_median_5m[TSR_DETECTOR_COUNT];
   long baseline_hist_msc[TSR_DETECTOR_COUNT];
   int baseline_hist_count[TSR_DETECTOR_COUNT];
   int spread_hist_count[TSR_DETECTOR_COUNT];
   int move_hist[TSR_DETECTOR_COUNT*TSR_MOVE_HIST_BINS];
   int tick_hist[TSR_DETECTOR_COUNT*TSR_TICK_HIST_BINS];
   int spread_hist[TSR_DETECTOR_COUNT*TSR_SPREAD_HIST_BINS];
   int move_hist_max[TSR_DETECTOR_COUNT];
   int tick_hist_max[TSR_DETECTOR_COUNT];
   int spread_hist_max[TSR_DETECTOR_COUNT];
   long histogram_overflow[TSR_DETECTOR_COUNT];
   int ema20_m15;
   int ema50_m15;
   int ema20_h1;
   int ema50_h1;
   long raw_candidates[TSR_DETECTOR_COUNT];
   long valid_events[TSR_DETECTOR_COUNT];
   long grid_missing[TSR_DETECTOR_COUNT];
   long scale_floor_uses[TSR_DETECTOR_COUNT];
   long baseline_refreshes[TSR_DETECTOR_COUNT];
   long evaluable_samples[TSR_DETECTOR_COUNT];
   long gate_true[TSR_DETECTOR_COUNT*TSR_GATE_COUNT];
   long gate_cumulative[TSR_DETECTOR_COUNT*TSR_GATE_COUNT];
   long gate_masks[TSR_DETECTOR_COUNT*TSR_GATE_MASK_COUNT];
   TickShockDetectorCounters detector_counters[TSR_DETECTOR_COUNT];
   TickShockSymbolClusterClock symbol_cluster_clock;
   long m1_minutes_seen;
   long last_m1_minute;
   long v1_boundary_count;
   long v1_tail_ready_count;
   long v1_statistical_candidates;
   long v1_persistence_rejections;
   long v1_integrity_rejections;
  };

TSRSymbolContext g_symbols[];
TSREvent g_events[TSR_MAX_ACTIVE_EVENTS];
long g_pre_skip[];
long g_scenario_valid[TSR_ALL_SCENARIOS];
long g_scenario_invalid[TSR_ALL_SCENARIOS];
double g_scenario_sum_r[TSR_ALL_SCENARIOS];
long g_event_rows = 0;
long g_total_ticks = 0;
long g_total_raw = 0;
long g_total_events = 0;
long g_valid_bursts = 0;
long g_valid_pullbacks = 0;
long g_reacceleration_signals = 0;
long g_detection_signals = 0;
long g_post_burst_signals = 0;
long g_pullback_signals = 0;
long g_reversal_signals = 0;
long g_entry_before_eligible = 0;
long g_entry_before_processing = 0;
long g_stale_detection_fills = 0;
long g_reversal_signal_overwrites = 0;
long g_rr_below_requested = 0;
long g_scenario_csv_recount_valid = 0;
long g_scenario_csv_recount_invalid = 0;
double g_scenario_csv_recount_sum_r = 0.0;
TickShockEventEngineContext g_event_engine;
TickShockPendingRepository g_pending_repository;
long g_memory_samples = 0;
double g_memory_sum_mb = 0.0;
long g_memory_max_mb = 0;
ulong g_started_tick_count = 0;
int g_event_file = INVALID_HANDLE;
int g_trade_file = INVALID_HANDLE;
int g_summary_file = INVALID_HANDLE;
int g_specs_file = INVALID_HANDLE;
int g_features_file = INVALID_HANDLE;
int g_debug_messages = 0;
bool g_is_tester = false;
double g_burst_spread_ratios[];
long g_scenario_status_counts[8];
TickShockConfig g_core_config;

void TSRLoadCoreConfig(TickShockConfig &config)
  {
   TSResetConfig(config);
   config.grid_ms=InpGridMs;
   config.baseline_minutes=InpBaselineMinutes;
   config.baseline_exclude_ms=InpBaselineExcludeMs;
   config.min_baseline_samples=InpMinBaselineSamples;
   config.shock_percentile=InpShockPercentile;
   config.min_robust_z=InpMinRobustZ;
   config.min_efficiency=InpMinEfficiency;
   config.min_move_spread_ratio=InpMinMoveSpreadRatio;
   config.min_tick_intensity_ratio=InpMinTickIntensityRatio;
   config.max_spread_median_ratio=InpMaxSpreadMedianRatio;
   config.max_quote_age_ms=InpMaxQuoteAgeMs;
   config.noise_floor_ticks=InpNoiseFloorTicks;
   config.burst_quiet_ms=InpBurstQuietMs;
   config.burst_max_ms=InpBurstMaxMs;
   config.pullback_min_pct=InpPullbackMinPct;
   config.pullback_max_pct=InpPullbackMaxPct;
   config.continuation_invalid_pct=InpContinuationInvalidPct;
   config.pullback_wait_ms=InpPullbackWaitMs;
   config.reacceleration_confirm_ticks=InpReaccelerationConfirmTicks;
   config.reward_risk=InpRewardRisk;
   config.max_hold_seconds=InpMaxHoldSeconds;
   config.shadow_slippage_ticks=InpShadowSlippageTicks;
   config.shadow_exit_slippage_ticks=InpShadowExitSlippageTicks;
   config.commission_per_lot_round_turn=InpCommissionPerLotRoundTurn;
   config.execution_mode=InpExecutionMode;
   config.submit_latency_ms=InpSubmitLatencyMs;
  }

string TSRLong(const long value) { return StringFormat("%I64d", value); }
string TSRDouble(const double value,const int digits=10)
  {
   if(!MathIsValidNumber(value)) return "";
   return DoubleToString(value, digits);
  }
string TSRBool(const bool value) { return TSBoolName(value); }
string TSRDirection(const int direction) { return TSDirectionName(direction); }

string TSRExecutionModeName()
  {
   return InpExecutionMode==REALIZABLE_EA?"REALIZABLE_EA":"IDEAL_EVENT_STUDY";
  }

string TSRRunMetadataFingerprint()
  {
   TickShockRunIdentity identity;ZeroMemory(identity);
   identity.period=InpResearchPeriod;identity.model=InpTesterModel;
   identity.broker_server=AccountInfoString(ACCOUNT_SERVER);identity.terminal_build=(long)TerminalInfoInteger(TERMINAL_BUILD);
   identity.source_commit=InpSourceCommit;identity.ex5_hash=InpEx5Hash;identity.schema=InpSchemaVersion;
    identity.config="implementation_schema="+TSR_IMPLEMENTATION_SCHEMA;
   string value=TSMt5RunIdentityFingerprint(identity);
   value+="|symbols="+InpSymbols;
   value+="|detector_version="+TSV1DetectorName(InpDetectorVersion);
   value+="|detector_spec_sha256="+TSV1SpecSha256();
   value+="|grid_ms="+IntegerToString(InpGridMs);
   value+="|baseline_minutes="+IntegerToString(InpBaselineMinutes);
   value+="|baseline_exclude_ms="+IntegerToString(InpBaselineExcludeMs);
   value+="|min_baseline_samples="+IntegerToString(InpMinBaselineSamples);
   value+="|shock_percentile="+DoubleToString(InpShockPercentile,8);
   value+="|min_robust_z="+DoubleToString(InpMinRobustZ,8);
   value+="|min_efficiency="+DoubleToString(InpMinEfficiency,8);
   value+="|min_move_spread="+DoubleToString(InpMinMoveSpreadRatio,8);
   value+="|min_tick_intensity="+DoubleToString(InpMinTickIntensityRatio,8);
   value+="|max_spread_median="+DoubleToString(InpMaxSpreadMedianRatio,8);
   value+="|max_quote_age_ms="+IntegerToString(InpMaxQuoteAgeMs);
   value+="|noise_floor_ticks="+DoubleToString(InpNoiseFloorTicks,8);
   value+="|burst_quiet_ms="+IntegerToString(InpBurstQuietMs);
   value+="|burst_max_ms="+IntegerToString(InpBurstMaxMs);
   value+="|pullback_min="+DoubleToString(InpPullbackMinPct,8);
   value+="|pullback_max="+DoubleToString(InpPullbackMaxPct,8);
   value+="|continuation_invalid="+DoubleToString(InpContinuationInvalidPct,8);
   value+="|pullback_wait_ms="+IntegerToString(InpPullbackWaitMs);
   value+="|reacceleration_ticks="+IntegerToString(InpReaccelerationConfirmTicks);
   value+="|reward_risk="+DoubleToString(InpRewardRisk,8);
   value+="|max_hold_seconds="+IntegerToString(InpMaxHoldSeconds);
   value+="|entry_slippage_ticks="+DoubleToString(InpShadowSlippageTicks,8);
   value+="|exit_slippage_ticks="+DoubleToString(InpShadowExitSlippageTicks,8);
   value+="|commission="+DoubleToString(InpCommissionPerLotRoundTurn,8);
   value+="|commission_source="+InpCommissionSource;
   value+="|commission_evidence_status="+TSCommissionEvidenceStatusName(InpCommissionEvidenceStatus);
   value+="|commission_symbol_scope="+InpCommissionSymbolScope;
   value+="|commission_unit="+InpCommissionUnit;
   value+="|execution_mode="+TSRExecutionModeName();
   value+="|submit_latency_ms="+IntegerToString(InpSubmitLatencyMs);
   value+="|sessions="+IntegerToString(InpTokyoStartHour)+"-"+IntegerToString(InpTokyoEndHour)+"/"+
          IntegerToString(InpLondonStartHour)+"-"+IntegerToString(InpLondonEndHour)+"/"+
          IntegerToString(InpNewYorkStartHour)+"-"+IntegerToString(InpNewYorkEndHour);
   return value;
  }

string TSRStrategyName(const int strategy)
  {
   if(strategy == TSR_DETECTION_CONTINUATION) return "detection_time_continuation";
   if(strategy == TSR_POST_BURST_CONTINUATION) return "post_burst_continuation";
   if(strategy == TSR_PULLBACK_CONTINUATION) return "pullback_continuation";
   return "failed_shock_reversal";
  }

double TSRStopMultiple(const int index)
  {
   return 1.0+0.5*index;
  }

int TSRDetectorIndex(const int window_ms)
  {
   for(int i=0;i<TSR_DETECTOR_COUNT;++i) if(TSR_DETECTOR_MS[i]==window_ms) return i;
   return -1;
  }

int TSRScenarioLocalIndex(const int stop_index,const int delay_index,const int spread_index)
  {
   return (stop_index * TSR_DELAY_COUNT + delay_index) * TSR_SPREAD_COUNT + spread_index;
  }

int TSRScenarioIndex(const int strategy,const int stop_index,const int delay_index,const int spread_index)
  {
   return strategy * TSR_SCENARIO_COUNT + TSRScenarioLocalIndex(stop_index, delay_index, spread_index);
  }

int TSRExecutionGroupIndex(const int strategy,const int delay_index,const int spread_index)
  {
   return (strategy*TSR_DELAY_COUNT+delay_index)*TSR_SPREAD_COUNT+spread_index;
  }

void TSRCsvAppend(string &line,string value)
  {
   TSCsvAppendEscaped(line,value);
  }

void TSRDebug(const string symbol,const string message)
  {
   if(!InpEnableDebug || symbol != InpDebugSymbol || g_debug_messages >= InpDebugMaxMessages) return;
   ++g_debug_messages;
   PrintFormat("%s DEBUG %s %s", TSR_NAME, symbol, message);
  }

string TSRFileName(const string suffix)
  {
   return InpLogFolder + "\\" + TSR_NAME + "_" + InpRunId + "_" + suffix + ".csv";
  }

int TSROpenCsv(const string suffix,const string header)
  {
   ENUM_TS_CSV_OPEN_STATUS status=TS_CSV_OPEN_IO_ERROR;
   TickShockCsvOpenRequest request;ZeroMemory(request);
   request.mode=InpResumeRun?TS_CSV_EXPLICIT_RESUME:TS_CSV_FRESH_RUN;
   request.checkpoint=InpResumeCheckpoint;request.last_event_sequence=InpResumeLastEventSequence;request.cursor_msc=InpResumeCursorMsc;
   int handle=TSMt5OpenCsv(InpLogFolder,TSRFileName(suffix),header,
                           InpRunId,TSRRunMetadataFingerprint(),request,status);
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s FileOpen failed suffix=%s status=%s err=%d", TSR_NAME, suffix,
                  TSCsvOpenStatusName(status),GetLastError());
      return INVALID_HANDLE;
     }
   return handle;
  }

string TSREventHeader()
  {
   string h = "event_id,execution_mode,symbol,direction,detector_window_ms,symbol_cluster_id,market_cluster_id,symbol_overlap_event,market_overlap_event,shock_gate_mask,detection_time_msc,detection_grid_msc,detection_quote_msc,detection_quote_age_ms,signal_processing_msc,merge_lag_ms,detection_bid,detection_ask,detection_mid,shock_start_mid,detection_shock_range,log_return_250,log_return_250_valid,log_return_500,log_return_500_valid,log_return_1000,log_return_1000_valid,percentile_move,median_move,mad_move,robust_scale_move,robust_scale_floored,robust_z,efficiency,tick_count,tick_intensity_ratio,spread,spread_median,move_spread_ratio,quote_age_ms,baseline_samples,burst_end_time_msc,burst_end_bid,burst_end_ask,burst_end_mid,burst_range,burst_spread_ratio,max_retracement_pct,pullback_time_msc,reacceleration_time_msc,continuation_invalidated_msc,m15_trend,h1_trend,htf_alignment,session,news_label,state_status,state_skip_reason";
   for(int s=0;s<TSR_STRATEGY_COUNT;++s)
      h += ","+TSRStrategyName(s)+"_signal_event_msc,"+TSRStrategyName(s)+"_signal_processing_msc";
   for(int i=0;i<TSR_CHECKPOINT_COUNT;++i)
      h += StringFormat(",det_bid_%ds,det_ask_%ds,det_mfe_%ds,det_mae_%ds", TSR_CHECKPOINT_SECONDS[i],TSR_CHECKPOINT_SECONDS[i],TSR_CHECKPOINT_SECONDS[i],TSR_CHECKPOINT_SECONDS[i]);
   for(int i=0;i<TSR_CHECKPOINT_COUNT;++i)
      h += StringFormat(",burst_bid_%ds,burst_ask_%ds,burst_mfe_%ds,burst_mae_%ds", TSR_CHECKPOINT_SECONDS[i],TSR_CHECKPOINT_SECONDS[i],TSR_CHECKPOINT_SECONDS[i],TSR_CHECKPOINT_SECONDS[i]);
   h += ",scenario_grid_encoding,scenario_grid";
   return h;
  }

string TSRSummaryHeader()
  {
   return "run_id,record_type,key,events,raw_candidates,ticks,scenario_valid,scenario_invalid,scenario_expectancy_r,average_memory_mb,max_memory_mb,event_csv_rows,event_csv_bytes,trade_csv_rows,trade_csv_bytes,runtime_seconds,value";
  }

string TSRDetectorFeatureHeader()
  {
   return "event_id,symbol,detector_version,feature_schema,spec_sha256,candidate_time_msc,confirmed_time_msc,trigger_horizon_ms,horizons_triggered_mask,raw_p_250,raw_p_500,raw_p_1000,adjusted_p_250,adjusted_p_500,adjusted_p_1000,empirical_percentile,severity,local_score,local_sigma,baseline_samples,tail_calibration_samples,quantile_half_width,time_of_day_bucket,volatility_regime,noise_return,efficiency,tick_intensity_ratio,move_spread_ratio,spread_ratio,quote_age_ms,statistical_shock,directional_burst,activity_elevated,liquidity_normal,cost_feasible,strategy_signal";
  }

bool TSROpenLogs()
  {
   g_event_file = TSROpenCsv("events", TSREventHeader());
   g_trade_file = TSROpenCsv("trades", "event_id,note");
   g_summary_file = TSROpenCsv("summary", TSRSummaryHeader());
   g_specs_file = TSROpenCsv("symbol_specs", "run_id,symbol,digits,point,tick_size,tick_value,contract_size,stops_level,freeze_level,volume_min,volume_max,volume_step,filling_mode,commission_per_lot_round_turn,commission_source");
   g_features_file = TSROpenCsv("detector_features",TSRDetectorFeatureHeader());
   return g_event_file!=INVALID_HANDLE && g_trade_file!=INVALID_HANDLE && g_summary_file!=INVALID_HANDLE && g_specs_file!=INVALID_HANDLE && g_features_file!=INVALID_HANDLE;
  }

void TSRCloseLogs()
  {
   TSMt5Close(g_event_file);
   TSMt5Close(g_trade_file);
   TSMt5Close(g_summary_file);
   TSMt5Close(g_specs_file);
   TSMt5Close(g_features_file);
  }

double TSRPercentile(double &values[],const int count,const double percentile)
  {
   TickShockPercentileResult result;
   return TSEngineLinearPercentile(values,count,percentile,result)?result.value:0.0;
  }

double TSRMedian(double &values[],const int count)
  {
   return TSRPercentile(values,count,50.0);
  }

int TSROldestTick(const TSRSymbolContext &context)
  {
   return TSRingOldestIndex(context.tick_ring);
  }

int TSROldestGrid(const TSRSymbolContext &context)
  {
   return TSRingOldestIndex(context.grid_ring);
  }

int TSROldestSample(const TSRSymbolContext &context,const int detector)
  {
   if(detector<0 || detector>=TSR_DETECTOR_COUNT) return -1;
   return TSRingOldestIndex(context.sample_ring[detector]);
  }

void TSRAddTick(TSRSymbolContext &context,const MqlTick &source)
  {
   TSRShortTick tick;
   tick.time_msc=(long)source.time_msc;
   tick.bid=source.bid;
   tick.ask=source.ask;
   tick.mid=(source.bid+source.ask)*0.5;
   int write_index=TSRingReserveWrite(context.tick_ring);
   if(write_index<0) return;
   context.ticks[write_index]=tick;
   while(context.tick_ring.count>0)
     {
      int oldest=TSROldestTick(context);
      if(oldest<0 || tick.time_msc-context.ticks[oldest].time_msc<=TSR_TICK_RETENTION_MS) break;
      TSRingDropOldest(context.tick_ring);
     }
  }

void TSRAddGrid(TSRSymbolContext &context,const TSRGridPoint &point)
  {
   int write_index=TSRingReserveWrite(context.grid_ring);
   if(write_index>=0) context.grid[write_index]=point;
  }

void TSRSetSample(TSRSymbolContext &context,const int detector,const int index,const TSRSecondSample &sample)
  {
   if(detector==0) context.samples250[index]=sample;
   else if(detector==1) context.samples500[index]=sample;
   else context.samples1000[index]=sample;
  }

TSRSecondSample TSRGetSample(const TSRSymbolContext &context,const int detector,const int index)
  {
   if(detector==0) return context.samples250[index];
   if(detector==1) return context.samples500[index];
   return context.samples1000[index];
  }

void TSRAddSample(TSRSymbolContext &context,const int detector,const TSRSecondSample &sample)
  {
   int capacity=TSRSampleCapacity(detector);
   if(capacity<=0) return;
   int head=TSRingReserveWrite(context.sample_ring[detector]);
   if(head>=0) TSRSetSample(context,detector,head,sample);
  }

bool TSRFindGrid(const TSRSymbolContext &context,const long time_msc,TSRGridPoint &point)
  {
   int oldest=TSROldestGrid(context);
   if(oldest<0) return false;
   for(int i=0;i<context.grid_ring.count;++i)
     {
      int index=(oldest+i)%TSR_GRID_CAPACITY;
      if(TSExactAnchorTime(time_msc,context.grid[index].time_msc))
        {
         point=context.grid[index];
         return point.valid;
        }
     }
   return false;
  }

double TSRLogReturn(const double newer,const double older,bool &valid)
  {
   double value=0.0;
   valid=TSFixedLogMidReturn(newer,older,value);
   return value;
  }

bool TSRPathEfficiency(const TSRSymbolContext &context,
                       const long start_msc,
                       const long end_msc,
                       const double start_mid,
                       const double end_mid,
                       double &efficiency)
  {
   efficiency=0.0;
   if(end_msc<=start_msc || start_mid<=0.0 || end_mid<=0.0) return false;
   double mids[];
   ArrayResize(mids,1);
   mids[0]=start_mid;
   int oldest=TSROldestTick(context);
   if(oldest<0) return false;
   for(int i=0;i<context.tick_ring.count;++i)
     {
      int index=(oldest+i)%TSR_TICK_CAPACITY;
      TSRShortTick tick=context.ticks[index];
      if(tick.time_msc<=start_msc) continue;
      if(tick.time_msc>end_msc) break;
      int n=ArraySize(mids);ArrayResize(mids,n+1);mids[n]=tick.mid;
     }
   int n=ArraySize(mids);
   if(n<=0 || MathAbs(end_mid-mids[n-1])>0.0) {ArrayResize(mids,n+1);mids[n]=end_mid;}
   TickShockEfficiencyResult result;
   if(!TSEngineDirectionalEfficiency(mids,ArraySize(mids),result)) return false;
   efficiency=result.efficiency;
   return true;
  }

int TSRPreSkipIndex(const string reason)
  {
   if(reason=="insufficient_baseline") return 0;
   if(reason=="grid_missing") return 1;
   if(reason=="stale_quote") return 2;
   if(reason=="shock_percentile_failed") return 3;
   if(reason=="shock_z_failed") return 4;
   if(reason=="efficiency_failed") return 5;
   if(reason=="tick_intensity_failed") return 6;
   if(reason=="move_spread_failed") return 7;
   if(reason=="spread_too_wide") return 8;
   if(reason=="invalid_denominator") return 9;
   return -1;
  }

void TSRCountPreSkip(const int symbol_index,const string reason)
  {
   int index=TSRPreSkipIndex(reason);
   if(index<0) return;
   int flat=symbol_index*TSR_PRE_SKIP_COUNT+index;
   if(flat>=0 && flat<ArraySize(g_pre_skip)) ++g_pre_skip[flat];
  }

bool TSRFindSampleAt(const TSRSymbolContext &context,const int detector,const long target_msc,TSRSecondSample &sample)
  {
   int count=context.sample_ring[detector].count;
   int capacity=TSRSampleCapacity(detector);
   if(capacity<=0) return false;
   for(int i=0;i<count;++i)
     {
      int index=TSRingIndexFromNewest(context.sample_ring[detector],i);
      TSRSecondSample candidate=TSRGetSample(context,detector,index);
      if(candidate.end_msc==target_msc) {sample=candidate;return true;}
      if(candidate.end_msc<target_msc) return false;
     }
   return false;
  }

int TSRClampedBin(const double value,const double unit,const int bins,bool &overflow)
  {
   overflow=false;
   if(unit<=0.0 || bins<=1) return 0;
   int result=(int)MathRound(MathMax(0.0,value)/unit);
   if(result>=bins) {result=bins-1;overflow=true;}
   return result;
  }

void TSRAdjustMoveTickHistogram(TSRSymbolContext &context,const int detector,const TSRSecondSample &sample,const int delta)
  {
   if(sample.tick_count<=0 || sample.spread<=0.0) return;
   bool overflow=false;
   double half_tick=context.tick_size*0.5;
   int move_bin=TSRClampedBin(sample.price_move,half_tick,TSR_MOVE_HIST_BINS,overflow);
   if(overflow && delta>0) ++context.histogram_overflow[detector];
   int tick_bin=MathMin(MathMax(sample.tick_count,0),TSR_TICK_HIST_BINS-1);
   int move_flat=detector*TSR_MOVE_HIST_BINS+move_bin;
   int tick_flat=detector*TSR_TICK_HIST_BINS+tick_bin;
   context.move_hist[move_flat]=MathMax(0,context.move_hist[move_flat]+delta);
   context.tick_hist[tick_flat]=MathMax(0,context.tick_hist[tick_flat]+delta);
   context.baseline_hist_count[detector]=MathMax(0,context.baseline_hist_count[detector]+delta);
   if(delta>0)
     {
      context.move_hist_max[detector]=MathMax(context.move_hist_max[detector],move_bin);
      context.tick_hist_max[detector]=MathMax(context.tick_hist_max[detector],tick_bin);
     }
  }

void TSRAdjustSpreadHistogram(TSRSymbolContext &context,const int detector,const TSRSecondSample &sample,const int delta)
  {
   if(sample.spread<=0.0) return;
   bool overflow=false;
   int bin=TSRClampedBin(sample.spread,context.tick_size*0.5,TSR_SPREAD_HIST_BINS,overflow);
   if(overflow && delta>0) ++context.histogram_overflow[detector];
   int flat=detector*TSR_SPREAD_HIST_BINS+bin;
   context.spread_hist[flat]=MathMax(0,context.spread_hist[flat]+delta);
   context.spread_hist_count[detector]=MathMax(0,context.spread_hist_count[detector]+delta);
   if(delta>0) context.spread_hist_max[detector]=MathMax(context.spread_hist_max[detector],bin);
  }

double TSRHistogramPercentile(const int &hist[],const int offset,const int max_bin,const int count,const double percentile)
  {
   return TSEngineHistogramPercentile(hist,offset,max_bin,count,percentile);
  }

double TSRHistogramMadBins(const TSRSymbolContext &context,const int detector,const double median_bin,const int count)
  {
   if(count<=0) return 0.0;
   int max_bin=context.move_hist_max[detector];
   int max_distance=2*max_bin+2;
   int deviations[];
   ArrayResize(deviations,max_distance+1);
   ArrayInitialize(deviations,0);
   int median2=(int)MathRound(median_bin*2.0);
   int offset=detector*TSR_MOVE_HIST_BINS;
   for(int bin=0;bin<=max_bin;++bin)
     {
      int distance2=MathAbs(2*bin-median2);
      deviations[distance2]+=context.move_hist[offset+bin];
     }
   return TSRHistogramPercentile(deviations,0,max_distance,count,50.0)*0.5;
  }

void TSRRebuildBaselineHistograms(TSRSymbolContext &context,const int detector,const long boundary_msc)
  {
   int move_offset=detector*TSR_MOVE_HIST_BINS;
   int tick_offset=detector*TSR_TICK_HIST_BINS;
   int spread_offset=detector*TSR_SPREAD_HIST_BINS;
   for(int i=0;i<TSR_MOVE_HIST_BINS;++i) context.move_hist[move_offset+i]=0;
   for(int i=0;i<TSR_TICK_HIST_BINS;++i) context.tick_hist[tick_offset+i]=0;
   for(int i=0;i<TSR_SPREAD_HIST_BINS;++i) context.spread_hist[spread_offset+i]=0;
   context.baseline_hist_count[detector]=0;context.spread_hist_count[detector]=0;
   context.move_hist_max[detector]=0;context.tick_hist_max[detector]=0;context.spread_hist_max[detector]=0;
   long baseline_end=boundary_msc-InpBaselineExcludeMs;
   long baseline_start=baseline_end-(long)InpBaselineMinutes*60*1000;
   int available=context.sample_ring[detector].count;
   int oldest=TSROldestSample(context,detector);
   int capacity=TSRSampleCapacity(detector);
   for(int i=0;i<available;++i)
     {
      int index=(oldest+i)%capacity;
      TSRSecondSample sample=TSRGetSample(context,detector,index);
      if(sample.end_msc>=baseline_start && sample.end_msc<=baseline_end)
         TSRAdjustMoveTickHistogram(context,detector,sample,1);
      if(sample.end_msc>=boundary_msc-300000 && sample.end_msc<boundary_msc)
         TSRAdjustSpreadHistogram(context,detector,sample,1);
     }
  }

bool TSRRefreshBaseline(TSRSymbolContext &context,const int detector,const long boundary_msc)
  {
   if(context.baseline_cache_msc[detector]==boundary_msc) return context.baseline_samples[detector]>=InpMinBaselineSamples;
   context.baseline_cache_msc[detector]=boundary_msc;
   ++context.baseline_refreshes[detector];
   int window_ms=TSR_DETECTOR_MS[detector];
   long baseline_end=boundary_msc-InpBaselineExcludeMs;
   long baseline_start=baseline_end-(long)InpBaselineMinutes*60*1000;
   if(context.baseline_hist_msc[detector]!=boundary_msc-window_ms)
      TSRRebuildBaselineHistograms(context,detector,boundary_msc);
   else
     {
      TSRSecondSample changed;
      if(TSRFindSampleAt(context,detector,baseline_end,changed)) TSRAdjustMoveTickHistogram(context,detector,changed,1);
      if(TSRFindSampleAt(context,detector,baseline_start-window_ms,changed)) TSRAdjustMoveTickHistogram(context,detector,changed,-1);
      if(TSRFindSampleAt(context,detector,boundary_msc-window_ms,changed)) TSRAdjustSpreadHistogram(context,detector,changed,1);
      if(TSRFindSampleAt(context,detector,boundary_msc-300000-window_ms,changed)) TSRAdjustSpreadHistogram(context,detector,changed,-1);
     }
   context.baseline_hist_msc[detector]=boundary_msc;
   int value_count=context.baseline_hist_count[detector];
   int spread_count=context.spread_hist_count[detector];
   context.baseline_samples[detector]=value_count;
   context.baseline_percentile[detector]=0.0;
   context.baseline_median[detector]=0.0;
   context.baseline_mad[detector]=0.0;
   context.baseline_scale[detector]=0.0;
   context.baseline_scale_floored[detector]=false;
   context.baseline_median_ticks[detector]=0.0;
   context.spread_median_5m[detector]=0.0;
   if(value_count>0)
     {
      double half_tick=context.tick_size*0.5;
      double median_bin=TSRHistogramPercentile(context.move_hist,detector*TSR_MOVE_HIST_BINS,context.move_hist_max[detector],value_count,50.0);
      double percentile_bin=TSRHistogramPercentile(context.move_hist,detector*TSR_MOVE_HIST_BINS,context.move_hist_max[detector],value_count,InpShockPercentile);
      context.baseline_median[detector]=median_bin*half_tick;
      context.baseline_percentile[detector]=percentile_bin*half_tick;
      context.baseline_median_ticks[detector]=TSRHistogramPercentile(context.tick_hist,detector*TSR_TICK_HIST_BINS,context.tick_hist_max[detector],value_count,50.0);
      context.baseline_mad[detector]=TSRHistogramMadBins(context,detector,median_bin,value_count)*half_tick;
      double noise_price=MathMax(InpNoiseFloorTicks,0.0)*context.tick_size;
      TickShockRobustStatistics robust;
      TSEngineRobustStatistics(context.baseline_median[detector],context.baseline_median[detector],context.baseline_mad[detector],noise_price,robust);
      context.baseline_scale[detector]=robust.robust_scale;
      context.baseline_percentile[detector]=MathMax(context.baseline_percentile[detector],noise_price);
      context.baseline_scale_floored[detector]=robust.scale_floored;
      if(context.baseline_scale_floored[detector]) ++context.scale_floor_uses[detector];
     }
   if(spread_count>0)
      context.spread_median_5m[detector]=TSRHistogramPercentile(context.spread_hist,detector*TSR_SPREAD_HIST_BINS,context.spread_hist_max[detector],spread_count,50.0)*context.tick_size*0.5;
   TickShockBaselineReadiness readiness;
   return TSEngineBaselineReadiness(value_count,InpMinBaselineSamples,readiness);
  }

string TSRSessionLabel(const long time_msc)
  {
   MqlDateTime parts;
   TimeToStruct((datetime)(time_msc/1000),parts);
   bool tokyo=parts.hour>=InpTokyoStartHour && parts.hour<InpTokyoEndHour;
   bool london=parts.hour>=InpLondonStartHour && parts.hour<InpLondonEndHour;
   bool ny=parts.hour>=InpNewYorkStartHour && parts.hour<InpNewYorkEndHour;
   if((london&&ny)||(tokyo&&london)||(tokyo&&ny)) return "OVERLAP";
   if(tokyo) return "TOKYO";
   if(london) return "LONDON";
   if(ny) return "NEW_YORK";
   return "OTHER";
  }

string TSRTrend(const int symbol_index,const ENUM_TIMEFRAMES timeframe)
  {
   if(symbol_index<0 || symbol_index>=ArraySize(g_symbols)) return "UNAVAILABLE";
   int e20=timeframe==PERIOD_M15?g_symbols[symbol_index].ema20_m15:g_symbols[symbol_index].ema20_h1;
   int e50=timeframe==PERIOD_M15?g_symbols[symbol_index].ema50_m15:g_symbols[symbol_index].ema50_h1;
   return TSMt5TrendLabel(g_symbols[symbol_index].symbol,timeframe,e20,e50);
  }

string TSRAlignment(const int direction,const string m15,const string h1)
  {
   if(m15=="UNAVAILABLE" || h1=="UNAVAILABLE") return "UNAVAILABLE";
   string wanted=direction>0?"UP":"DOWN";
   string opposite=direction>0?"DOWN":"UP";
   bool a=m15==wanted,b=h1==wanted;
   if(a&&b) return "BOTH_ALIGNED";
   if(a) return "M15_ONLY";
   if(b) return "H1_ONLY";
   if(m15==opposite || h1==opposite) return "CONFLICT";
   return "NEUTRAL";
  }

void TSRResetScenario(TSRScenario &scenario)
  {
   scenario.initialized=false;
   scenario.pending=false;
   scenario.active=false;
   scenario.done=false;
   scenario.direction=0;
   TSResetResearchSignalClock(scenario.signal_clock);
   TSResetResearchEntryClock(scenario.entry_clock);
   scenario.signal_event_msc=0;
   scenario.signal_processing_msc=0;
   scenario.entry_eligible_msc=0;
   scenario.entry_quote_msc=0;
   scenario.exit_msc=0;
   scenario.spread_multiplier=1.0;
   scenario.stop_multiple=0.0;
   scenario.base_spread=0.0;
   scenario.requested_risk=0.0;
   scenario.entry=0.0;
   scenario.sl=0.0;
   scenario.tp=0.0;
   scenario.risk=0.0;
   scenario.requested_rr=0.0;
   scenario.realized_rr=0.0;
   scenario.stops_distance=0.0;
   scenario.freeze_distance=0.0;
   scenario.freeze_clear=false;
   scenario.commission_r=0.0;
   scenario.gross_r=0.0;
   scenario.result_r=0.0;
   scenario.exit_price=0.0;
   scenario.stop_gap=0.0;
   scenario.exit_slippage=0.0;
   scenario.policy_mask=0;
   scenario.status=TS_SCENARIO_NOT_SIGNALED;
  }

bool TSRContainsSymbol(const string symbol,const int upto)
  {
   for(int i=0;i<upto;++i) if(g_symbols[i].symbol==symbol) return true;
   return false;
  }

bool TSRInitializeSymbol(TSRSymbolContext &context,const string symbol)
  {
   TickShockSymbolSpec spec;
   if(!TSMt5LoadSymbolSpec(symbol,spec))
     {
      PrintFormat("%s invalid symbol specification %s",TSR_NAME,symbol);
      return false;
     }
   context.symbol=spec.symbol;
   context.digits=spec.digits;
   context.point=spec.point;
   context.tick_size=spec.tick_size;
   context.tick_value=spec.tick_value;
   context.contract_size=spec.contract_size;
   context.volume_min=spec.volume_min;
   context.volume_max=spec.volume_max;
   context.volume_step=spec.volume_step;
   context.stops_level=spec.stops_level;
   context.freeze_level=spec.freeze_level;
   context.filling_mode=spec.filling_mode;
   TSResetSymbolFrontier(context.frontier);
   ArrayResize(context.ticks,TSR_TICK_CAPACITY);
   ArrayResize(context.grid,TSR_GRID_CAPACITY);
   ArrayResize(context.samples250,TSRSampleCapacity(0));
   ArrayResize(context.samples500,TSRSampleCapacity(1));
   ArrayResize(context.samples1000,TSRSampleCapacity(2));
   TSRingReset(context.tick_ring,TSR_TICK_CAPACITY);
   TSRingReset(context.grid_ring,TSR_GRID_CAPACITY);
   TSGridReset(context.grid_runtime);
   TSV1ResetCalibration(context.v1_calibration);
   ZeroMemory(context.v1_pending_candidate);
   context.v1_boundary_count=0;
   context.v1_tail_ready_count=0;
   context.v1_statistical_candidates=0;
   context.v1_persistence_rejections=0;
   context.v1_integrity_rejections=0;
   context.last_time_msc=0;context.processed_at_last_msc=0;
   TSResetSymbolClusterClock(context.symbol_cluster_clock);context.m1_minutes_seen=0;context.last_m1_minute=-1;
   for(int d=0;d<TSR_DETECTOR_COUNT;++d)
     {
      TSRingReset(context.sample_ring[d],TSRSampleCapacity(d));context.ticks_since_window[d]=0;
      context.baseline_cache_msc[d]=-1;
      context.baseline_hist_msc[d]=-1;
      TSResetDetectorCounters(context.detector_counters[d]);
     }
   return TSMt5CreateTrendHandles(symbol,context.ema20_m15,context.ema50_m15,context.ema20_h1,context.ema50_h1);
  }

bool TSRParseSymbols()
  {
   string parts[];
   int count=StringSplit(InpSymbols,',',parts);
   if(count<=0) return false;
   ArrayResize(g_symbols,count);
   for(int i=0;i<count;++i)
     {
      StringTrimLeft(parts[i]);StringTrimRight(parts[i]);
      if(parts[i]=="" || TSRContainsSymbol(parts[i],i) || !TSMt5SelectSymbol(parts[i]) || !TSRInitializeSymbol(g_symbols[i],parts[i]))
        {
         PrintFormat("%s symbol initialization failed token=%s",TSR_NAME,parts[i]);
         return false;
        }
     }
   ArrayResize(g_pre_skip,count*TSR_PRE_SKIP_COUNT);
   ArrayInitialize(g_pre_skip,0);
   return true;
  }

void TSRWriteSymbolSpecs()
  {
   for(int i=0;i<ArraySize(g_symbols);++i)
     {
      string line="";
      TSRCsvAppend(line,InpRunId);TSRCsvAppend(line,g_symbols[i].symbol);TSRCsvAppend(line,IntegerToString(g_symbols[i].digits));
      TSRCsvAppend(line,TSRDouble(g_symbols[i].point));TSRCsvAppend(line,TSRDouble(g_symbols[i].tick_size));TSRCsvAppend(line,TSRDouble(g_symbols[i].tick_value));
      TSRCsvAppend(line,TSRDouble(g_symbols[i].contract_size));TSRCsvAppend(line,IntegerToString(g_symbols[i].stops_level));TSRCsvAppend(line,IntegerToString(g_symbols[i].freeze_level));
      TSRCsvAppend(line,TSRDouble(g_symbols[i].volume_min,8));TSRCsvAppend(line,TSRDouble(g_symbols[i].volume_max,8));TSRCsvAppend(line,TSRDouble(g_symbols[i].volume_step,8));
      TSRCsvAppend(line,IntegerToString(g_symbols[i].filling_mode));TSRCsvAppend(line,TSRDouble(InpCommissionPerLotRoundTurn,4));TSRCsvAppend(line,InpCommissionSource);
      TSMt5WriteLine(g_specs_file,line);
     }
   TSMt5Flush(g_specs_file);
  }

double TSRNormalizeNearest(const int symbol_index,const double price)
  {
   double size=g_symbols[symbol_index].tick_size;
   if(size<=0.0) return 0.0;
   return NormalizeDouble(MathRound(price/size)*size,g_symbols[symbol_index].digits);
  }

double TSRNormalizeStopOutward(const int symbol_index,const int direction,const double price)
  {
   return TSRoundStopOutward(direction,price,g_symbols[symbol_index].tick_size,g_symbols[symbol_index].digits);
  }

bool TSRCommissionR(const int symbol_index,const int direction,const double entry,const double sl,double &commission_r,string &reason)
  {
   commission_r=0.0;reason="";
   TickShockCommissionResult result;
   if(InpCommissionPerLotRoundTurn==0.0)
     {
      bool valid=TSEngineCommissionWithProvenance(false,0.0,0.0,0.0,g_symbols[symbol_index].symbol,InpCommissionSource,result);
      reason=result.reason;return valid;
     }
   double loss=0.0;bool calculated=TSMt5CalcOneLotLoss(direction,g_symbols[symbol_index].symbol,entry,sl,loss);
   bool valid=TSEngineCommissionWithProvenance(calculated,loss,InpCommissionPerLotRoundTurn,0.0,g_symbols[symbol_index].symbol,InpCommissionSource,result);
   reason=result.reason;if(!valid) return false;commission_r=result.commission_r;return true;
  }

bool TSRRegisterStrategySignal(TSREvent &event,
                               const int strategy,
                               const int direction,
                               const long signal_event_msc,
                               const long signal_processing_msc,
                               const double signal_bid,
                               const double signal_ask)
  {
   if(strategy<0 || strategy>=TSR_STRATEGY_COUNT) return false;
   if(event.signal_started[strategy])
     {
      if(strategy==TSR_FAILED_SHOCK_REVERSAL && event.signal_event_msc[strategy]!=signal_event_msc)
         ++g_reversal_signal_overwrites;
      return false;
     }
   TSResearchSignalClock signal;
   TSResetResearchSignalClock(signal);
   if(!TSRegisterResearchSignal(signal,direction,signal_event_msc,signal_processing_msc)) return false;
   event.signal_started[strategy]=true;
   event.signal_arm_msc[strategy]=signal_event_msc;
   event.signal_event_msc[strategy]=signal_event_msc;
   event.signal_processing_msc[strategy]=signal_processing_msc;
   event.signal_direction[strategy]=direction;
   event.signal_bid[strategy]=signal_bid;
   event.signal_ask[strategy]=signal_ask;
   for(int w=0;w<TSR_STOP_COUNT;++w)
      for(int d=0;d<TSR_DELAY_COUNT;++d)
         for(int p=0;p<TSR_SPREAD_COUNT;++p)
           {
            int index=TSRScenarioIndex(strategy,w,d,p);
            TSRResetScenario(event.scenarios[index]);
            event.scenarios[index].initialized=true;
            event.scenarios[index].pending=true;
            event.scenarios[index].direction=direction;
            event.scenarios[index].signal_clock=signal;
            event.scenarios[index].signal_event_msc=signal_event_msc;
            event.scenarios[index].signal_processing_msc=signal_processing_msc;
            event.scenarios[index].entry_eligible_msc=TSResearchEntryEligibleMsc(InpExecutionMode,signal_event_msc,signal_processing_msc,TSR_DELAY_MS[d],InpSubmitLatencyMs);
            event.scenarios[index].spread_multiplier=TSR_SPREAD_MULT[p];
            event.scenarios[index].stop_multiple=TSRStopMultiple(w);
            event.scenarios[index].status=TS_SCENARIO_PENDING_ENTRY_QUOTE;
           }
   return true;
  }

void TSRInvalidateScenario(TSRScenario &scenario,const ENUM_TS_SCENARIO_STATUS reason)
  {
   scenario.pending=false;
   scenario.active=false;
   scenario.done=true;
   scenario.status=reason;
  }

double TSRNormalizeEntryAdverse(const int symbol_index,const int direction,const double price)
  {
   return TSRoundEntryAdverse(direction,price,g_symbols[symbol_index].tick_size,g_symbols[symbol_index].digits);
  }

double TSRKnownPolicyRange(const TSREvent &event,const int strategy)
  {
   if(strategy==TSR_DETECTION_CONTINUATION) return event.detection_shock_range;
   return event.burst_range;
  }

bool TSRTryStartScenario(TSREvent &event,const int scenario_index,const TSRShortTick &tick)
  {
   if(!event.scenarios[scenario_index].initialized || !event.scenarios[scenario_index].pending || event.scenarios[scenario_index].done) return false;
   int local=scenario_index%TSR_SCENARIO_COUNT;
   int delay_index=(local%(TSR_DELAY_COUNT*TSR_SPREAD_COUNT))/TSR_SPREAD_COUNT;
   TickShockExecutionRequest request;
   request.signal_clock=event.scenarios[scenario_index].signal_clock;
   request.prior_entry_clock=event.scenarios[scenario_index].entry_clock;
   request.mode=g_core_config.execution_mode;
   request.direction=event.scenarios[scenario_index].direction;
   request.requested_delay_ms=TSR_DELAY_MS[delay_index];
   request.submit_latency_ms=g_core_config.submit_latency_ms;
   TSBuildQuote(g_symbols[event.symbol_index].symbol,event.symbol_index,0,tick.time_msc,tick.time_msc,
                tick.bid,tick.ask,true,request.quote);
   request.spread_multiplier=event.scenarios[scenario_index].spread_multiplier;
   request.stop_multiple=event.scenarios[scenario_index].stop_multiple;
   request.entry_slippage_ticks=g_core_config.shadow_slippage_ticks;
   request.tick_size=g_symbols[event.symbol_index].tick_size;
   request.digits=g_symbols[event.symbol_index].digits;
   request.stops_distance=g_symbols[event.symbol_index].stops_level*g_symbols[event.symbol_index].point;
   request.freeze_distance=g_symbols[event.symbol_index].freeze_level*g_symbols[event.symbol_index].point;
   request.requested_rr=g_core_config.reward_risk;
   int strategy=scenario_index/TSR_SCENARIO_COUNT;
   request.known_range=TSRKnownPolicyRange(event,strategy);
   TickShockExecutionResult result;
   if(!TSEngineBuildScenarioEntry(request,result))
     {
      if(result.done) TSRInvalidateScenario(event.scenarios[scenario_index],result.status);
      return false;
     }
   if(result.realized_rr+1e-9<InpRewardRisk) ++g_rr_below_requested;
   event.scenarios[scenario_index].entry_clock=result.entry_clock;
   event.scenarios[scenario_index].pending=false;
   event.scenarios[scenario_index].active=true;
   event.scenarios[scenario_index].done=false;
   event.scenarios[scenario_index].entry_eligible_msc=result.entry_clock.eligible_msc;
   event.scenarios[scenario_index].entry_quote_msc=result.entry_clock.quote_msc;
   event.scenarios[scenario_index].base_spread=result.base_spread;
   event.scenarios[scenario_index].requested_risk=result.requested_risk;
   event.scenarios[scenario_index].entry=result.entry;
   event.scenarios[scenario_index].sl=result.sl;
   event.scenarios[scenario_index].tp=result.tp;
   event.scenarios[scenario_index].risk=result.risk;
   event.scenarios[scenario_index].requested_rr=InpRewardRisk;
   event.scenarios[scenario_index].realized_rr=result.realized_rr;
   event.scenarios[scenario_index].stops_distance=result.stops_distance;
   event.scenarios[scenario_index].freeze_distance=result.freeze_distance;
   event.scenarios[scenario_index].freeze_clear=result.freeze_clear;
   string commission_reason="";double commission_r=0.0;
   if(!TSRCommissionR(event.symbol_index,event.scenarios[scenario_index].direction,result.entry,result.sl,commission_r,commission_reason))
     {TSRInvalidateScenario(event.scenarios[scenario_index],TS_SCENARIO_INVALID_COMMISSION);return false;}
   event.scenarios[scenario_index].commission_r=commission_r;
   event.scenarios[scenario_index].policy_mask=result.policy_mask;
   if(!TSResearchEntryInvariant(event.scenarios[scenario_index].signal_clock,InpExecutionMode,TSR_DELAY_MS[delay_index],InpSubmitLatencyMs,event.scenarios[scenario_index].entry_clock))
      ++g_entry_before_eligible;
   if(InpExecutionMode==REALIZABLE_EA && event.scenarios[scenario_index].entry_quote_msc<event.scenarios[scenario_index].signal_processing_msc)
      ++g_entry_before_processing;
   if(strategy==TSR_DETECTION_CONTINUATION && event.detection_quote_age_ms>0 &&
      event.scenarios[scenario_index].entry_quote_msc==event.detection_grid_msc)
      ++g_stale_detection_fills;
   event.scenarios[scenario_index].status=result.status;
   return true;
  }

void TSRTryStartScenarioGroup(TSREvent &event,const int strategy,const int delay_index,const int spread_index,const TSRShortTick &tick)
  {
   int first=TSRScenarioIndex(strategy,0,delay_index,spread_index);
   if(!event.scenarios[first].initialized || !event.scenarios[first].pending ||
      tick.time_msc<=event.scenarios[first].signal_event_msc ||
      tick.time_msc<event.scenarios[first].entry_eligible_msc) return;
   for(int w=0;w<TSR_STOP_COUNT;++w)
     {
      int index=TSRScenarioIndex(strategy,w,delay_index,spread_index);
      if(event.scenarios[index].pending) TSRTryStartScenario(event,index,tick);
     }
  }

void TSRAdvanceScenario(TSREvent &event,const int scenario_index,const TSRShortTick &tick)
  {
   if(!event.scenarios[scenario_index].active || event.scenarios[scenario_index].done || tick.time_msc<=event.scenarios[scenario_index].entry_quote_msc) return;
   double raw_spread=tick.ask-tick.bid;
   if(raw_spread<=0.0) return;
   double stressed_spread=raw_spread*event.scenarios[scenario_index].spread_multiplier;
   double exit_bid=tick.mid-stressed_spread*0.5;
   double exit_ask=tick.mid+stressed_spread*0.5;
   double tradable_exit=event.scenarios[scenario_index].direction>0?exit_bid:exit_ask;
   double exit_slip=MathMax(0.0,InpShadowExitSlippageTicks)*g_symbols[event.symbol_index].tick_size;
   double fill=0.0,gross=0.0,gap=0.0;
   string reason="";
   if(!TSResolveShadowExitWithGap(event.scenarios[scenario_index].direction,
                                  event.scenarios[scenario_index].entry,
                                  event.scenarios[scenario_index].sl,
                                  event.scenarios[scenario_index].tp,
                                  tradable_exit,exit_slip,
                                  event.scenarios[scenario_index].entry_quote_msc,tick.time_msc,
                                  InpMaxHoldSeconds,fill,gross,gap,reason)) return;
   event.scenarios[scenario_index].gross_r=gross;
   event.scenarios[scenario_index].result_r=gross-event.scenarios[scenario_index].commission_r;
   event.scenarios[scenario_index].exit_price=fill;
   event.scenarios[scenario_index].stop_gap=gap;
   event.scenarios[scenario_index].exit_slippage=reason=="SL_GAP"?exit_slip:0.0;
   event.scenarios[scenario_index].status=TSScenarioStatusFromExitReason(reason);
   event.scenarios[scenario_index].exit_msc=tick.time_msc;
   event.scenarios[scenario_index].active=false;
   event.scenarios[scenario_index].done=true;
  }

void TSRAdvanceScenarioGroup(TSREvent &event,const int strategy,const int delay_index,const int spread_index,const TSRShortTick &tick)
  {
   int group=TSRExecutionGroupIndex(strategy,delay_index,spread_index);
   int w=event.next_active_stop[group];
   while(w<TSR_STOP_COUNT)
     {
      int index=TSRScenarioIndex(strategy,w,delay_index,spread_index);
      if(!event.scenarios[index].active)
        {
         if(event.scenarios[index].done) {++w;continue;}
         break;
        }
      TSRAdvanceScenario(event,index,tick);
      if(event.scenarios[index].done) {++w;continue;}
      // Stop and target distances are monotonic over this configured grid.
      // If the nearest unresolved barrier did not fire, no wider barrier in
      // the same signal/delay/spread group can fire on this quote.
      break;
     }
   event.next_active_stop[group]=w;
  }

void TSRUpdateCheckpoints(TSREvent &event,const TSRShortTick &tick)
  {
   event.detection_best_mid=MathMax(event.detection_best_mid,tick.mid);
   event.detection_worst_mid=MathMin(event.detection_worst_mid,tick.mid);
   for(int i=0;i<TSR_CHECKPOINT_COUNT;++i)
     {
      if(event.detection_checkpoint_done[i] || tick.time_msc-event.detection_msc<(long)TSR_CHECKPOINT_SECONDS[i]*1000) continue;
      event.detection_checkpoint_done[i]=true;
      event.detection_checkpoint_bid[i]=tick.bid;
      event.detection_checkpoint_ask[i]=tick.ask;
      if(event.direction>0)
        {
         event.detection_checkpoint_mfe[i]=MathMax(0.0,event.detection_best_mid-event.detection_mid);
         event.detection_checkpoint_mae[i]=MathMax(0.0,event.detection_mid-event.detection_worst_mid);
        }
      else
        {
         event.detection_checkpoint_mfe[i]=MathMax(0.0,event.detection_mid-event.detection_worst_mid);
         event.detection_checkpoint_mae[i]=MathMax(0.0,event.detection_best_mid-event.detection_mid);
        }
     }
   if(!event.burst_checkpoint_started) return;
   event.burst_best_mid=MathMax(event.burst_best_mid,tick.mid);
   event.burst_worst_mid=MathMin(event.burst_worst_mid,tick.mid);
   for(int i=0;i<TSR_CHECKPOINT_COUNT;++i)
     {
      if(event.burst_checkpoint_done[i] || tick.time_msc-event.burst_end_msc<(long)TSR_CHECKPOINT_SECONDS[i]*1000) continue;
      event.burst_checkpoint_done[i]=true;
      event.burst_checkpoint_bid[i]=tick.bid;
      event.burst_checkpoint_ask[i]=tick.ask;
      if(event.direction>0)
        {
         event.burst_checkpoint_mfe[i]=MathMax(0.0,event.burst_best_mid-event.burst_end_mid);
         event.burst_checkpoint_mae[i]=MathMax(0.0,event.burst_end_mid-event.burst_worst_mid);
        }
      else
        {
         event.burst_checkpoint_mfe[i]=MathMax(0.0,event.burst_end_mid-event.burst_worst_mid);
         event.burst_checkpoint_mae[i]=MathMax(0.0,event.burst_best_mid-event.burst_end_mid);
        }
     }
  }

bool TSRAllScenariosDone(const TSREvent &event)
  {
   for(int i=0;i<TSR_ALL_SCENARIOS;++i)
      if(event.scenarios[i].initialized && !event.scenarios[i].done) return false;
   return true;
  }

void TSRMarkUnsignaledDone(TSREvent &event)
  {
   if(!event.terminal) return;
   for(int strategy=0;strategy<TSR_STRATEGY_COUNT;++strategy)
     {
      if(event.signal_started[strategy]) continue;
      for(int w=0;w<TSR_STOP_COUNT;++w)
         for(int d=0;d<TSR_DELAY_COUNT;++d)
            for(int p=0;p<TSR_SPREAD_COUNT;++p)
              {
               int index=TSRScenarioIndex(strategy,w,d,p);
               if(!event.scenarios[index].initialized)
                 {
                  TSRResetScenario(event.scenarios[index]);
                  event.scenarios[index].initialized=true;
                  event.scenarios[index].done=true;
                  event.scenarios[index].status=TS_SCENARIO_NO_SIGNAL;
                 }
              }
     }
  }

void TSRProcessEventTick(TSREvent &event,const TSRShortTick &tick,const long processing_msc)
  {
   if(!event.active || event.csv_written || tick.time_msc<=event.detection_msc) return;
   TSRUpdateCheckpoints(event,tick);

   for(int strategy=0;strategy<TSR_STRATEGY_COUNT;++strategy)
      for(int d=0;d<TSR_DELAY_COUNT;++d)
         for(int p=0;p<TSR_SPREAD_COUNT;++p)
           {
            TSRTryStartScenarioGroup(event,strategy,d,p,tick);
            TSRAdvanceScenarioGroup(event,strategy,d,p,tick);
           }

   if(!event.terminal)
     {
      TickShockQuote core_quote;
      TSBuildQuote(g_symbols[event.symbol_index].symbol,event.symbol_index,0,tick.time_msc,processing_msc,
                   tick.bid,tick.ask,true,core_quote);
      TickShockStateResult transition;
      ENUM_TS_ACTION action=TSEngineAdvanceState(event.machine,core_quote,g_core_config,transition);
      event.max_retracement_pct=event.machine.max_retracement_pct;
      if(action==TS_ACTION_BURST_FROZEN)
        {
         event.burst_end_msc=event.machine.burst_end_msc;
         event.burst_end_bid=tick.bid;
         event.burst_end_ask=tick.ask;
         event.burst_end_mid=tick.mid;
         event.burst_range=event.machine.burst_range;
         event.burst_checkpoint_started=true;
         event.burst_best_mid=tick.mid;
         event.burst_worst_mid=tick.mid;
         event.state_status="WAIT_PULLBACK";
         TSRRegisterStrategySignal(event,TSR_POST_BURST_CONTINUATION,event.direction,tick.time_msc,processing_msc,tick.bid,tick.ask);
        }
      else if(action==TS_ACTION_PULLBACK_VALID)
        {
         event.pullback_msc=event.machine.pullback_msc;
         event.state_status="WAIT_REACCELERATION";
        }
      else if(action==TS_ACTION_REACCELERATION)
        {
         event.reacceleration_msc=tick.time_msc;
         TSRRegisterStrategySignal(event,TSR_PULLBACK_CONTINUATION,event.direction,tick.time_msc,processing_msc,tick.bid,tick.ask);
         event.terminal=true;
         event.state_status="PULLBACK_REACCELERATION";
        }
      else if(action==TS_ACTION_CONTINUATION_INVALIDATED)
        {
         event.reversal_arm_msc=tick.time_msc;
         event.continuation_invalidated_msc=tick.time_msc;
         TSRRegisterStrategySignal(event,TSR_FAILED_SHOCK_REVERSAL,-event.direction,tick.time_msc,processing_msc,tick.bid,tick.ask);
         event.terminal=true;
         event.state_status="FAILED_SHOCK_REVERSAL";
         event.state_skip_reason="continuation_invalidated";
        }
      else if(action==TS_ACTION_PULLBACK_TIMEOUT)
        {
         event.terminal=true;
         event.state_status="PULLBACK_TIMEOUT";
         event.state_skip_reason=event.machine.too_deep_seen?"pullback_too_deep":"pullback_too_shallow";
        }
      else if(action==TS_ACTION_NO_REACCELERATION)
        {
         event.terminal=true;
         event.state_status="NO_REACCELERATION";
         event.state_skip_reason="no_reacceleration";
        }
     }
   TSRMarkUnsignaledDone(event);
  }

bool TSRCanWriteEvent(const TSREvent &event)
  {
   return event.active && event.terminal &&
          event.detection_checkpoint_done[TSR_CHECKPOINT_COUNT-1] &&
          event.burst_checkpoint_started && event.burst_checkpoint_done[TSR_CHECKPOINT_COUNT-1] &&
          TSRAllScenariosDone(event);
  }

void TSRDetectShock(TSRSymbolContext &context,
                     const int symbol_index,
                     const int detector,
                     const TSRSecondSample &sample,
                     const TSRGridPoint &point,
                     const long processing_msc)
  {
   if(!TSRRefreshBaseline(context,detector,sample.end_msc))
     {
      TSRCountPreSkip(symbol_index,"insufficient_baseline");
      return;
     }
   if(!point.valid || sample.quote_age_ms>InpMaxQuoteAgeMs)
     {
      TSRCountPreSkip(symbol_index,"stale_quote");
      return;
     }
   if(context.baseline_scale[detector]<=0.0 || context.baseline_median_ticks[detector]<=0.0 ||
      context.spread_median_5m[detector]<=0.0 || sample.spread<=0.0)
     {
      TSRCountPreSkip(symbol_index,"invalid_denominator");
      return;
     }
   TickShockRobustStatistics robust_statistics;
   if(!TSEngineRobustStatistics(sample.price_move,context.baseline_median[detector],context.baseline_mad[detector],
                                MathMax(InpNoiseFloorTicks,0.0)*context.tick_size,robust_statistics))
     {
      TSRCountPreSkip(symbol_index,"invalid_denominator");
      return;
     }
   double robust_z=robust_statistics.robust_z;
   double efficiency=0.0;
   if(!TSRPathEfficiency(context,sample.end_msc-TSR_DETECTOR_MS[detector],sample.end_msc,sample.start_mid,sample.end_mid,efficiency))
     {
      TSRCountPreSkip(symbol_index,"efficiency_failed");
      return;
     }
   double intensity=sample.tick_count/context.baseline_median_ticks[detector];
   double move_spread=sample.price_move/sample.spread;
   double spread_ratio=sample.spread/context.spread_median_5m[detector];
   TickShockDetectorResult detector_result;
   TSEngineEvaluateDetector(sample.price_move,context.baseline_percentile[detector],robust_z,efficiency,
                            move_spread,intensity,spread_ratio,g_core_config,detector_result);
   TSObserveDetectorResult(context.detector_counters[detector],detector_result);
   bool cumulative=true;
   ++context.evaluable_samples[detector];
   for(int g=0;g<TSR_GATE_COUNT;++g)
     {
      if(detector_result.gates[g])
        {
         ++context.gate_true[detector*TSR_GATE_COUNT+g];
        }
      cumulative=cumulative && detector_result.gates[g];
      if(cumulative) ++context.gate_cumulative[detector*TSR_GATE_COUNT+g];
     }
   int mask=detector_result.gate_mask;
   ++context.gate_masks[detector*TSR_GATE_MASK_COUNT+mask];
   if(detector_result.gates[0]) { ++g_total_raw; ++context.raw_candidates[detector]; }
   string reason=TSDetectorRejectName(detector_result.reject);
   if(reason!="")
     {
      TSRCountPreSkip(symbol_index,reason);
      return;
     }
   TickShockEventKey event_key;
   event_key.symbol_index=symbol_index;
   event_key.detector_window_ms=TSR_DETECTOR_MS[detector];
   event_key.detection_msc=sample.end_msc;
   TickShockEventRegistration registration;
   if(!TSEngineRegisterResearchEvent(g_event_engine,context.symbol_cluster_clock,event_key,2000,registration))
     {
      if(registration.status==TS_EVENT_REGISTRATION_POOL_EXHAUSTED)
         PrintFormat("%s validation invalid: active event pool exhausted symbol=%s",TSR_NAME,context.symbol);
      return;
     }
   int slot=registration.slot;
   ZeroMemory(g_events[slot]);
   g_events[slot].active=true;
   for(int j=0;j<TSR_ALL_SCENARIOS;++j) TSRResetScenario(g_events[slot].scenarios[j]);
   g_events[slot].symbol_index=symbol_index;
   g_events[slot].detector_window_ms=TSR_DETECTOR_MS[detector];
   g_events[slot].event_id=StringFormat("%s_%s_w%d_%I64d_%I64d",InpRunId,context.symbol,TSR_DETECTOR_MS[detector],sample.end_msc,registration.event_sequence);
   g_events[slot].direction=sample.signed_log_return>0.0?1:-1;
   g_events[slot].shock_gate_mask=mask;
   g_events[slot].symbol_cluster_id=registration.symbol_cluster_id;
   g_events[slot].symbol_overlap_event=registration.symbol_overlap;
   g_events[slot].market_cluster_id=registration.market_cluster_id;
   g_events[slot].market_overlap_event=registration.market_overlap;
   g_events[slot].detection_msc=sample.end_msc;
   g_events[slot].detection_grid_msc=sample.end_msc;
   g_events[slot].detection_quote_msc=point.quote_msc;
   g_events[slot].detection_quote_age_ms=sample.quote_age_ms;
   g_events[slot].processing_msc=processing_msc;
   g_events[slot].decision_delay_ms=MathMax((long)0,processing_msc-sample.end_msc);
   g_events[slot].detection_bid=point.bid;
   g_events[slot].detection_ask=point.ask;
   g_events[slot].detection_mid=point.mid;
   g_events[slot].shock_start_mid=sample.start_mid;
   g_events[slot].detection_shock_range=sample.price_move;
   TSRGridPoint diagnostic_anchor;
   if(TSRFindGrid(context,sample.end_msc-250,diagnostic_anchor))
      g_events[slot].log_return_250_valid=TSResearchExactLogReturn(sample.end_msc,point.mid,250,diagnostic_anchor.time_msc,diagnostic_anchor.mid,g_events[slot].log_return_250);
   if(TSRFindGrid(context,sample.end_msc-500,diagnostic_anchor))
      g_events[slot].log_return_500_valid=TSResearchExactLogReturn(sample.end_msc,point.mid,500,diagnostic_anchor.time_msc,diagnostic_anchor.mid,g_events[slot].log_return_500);
   if(TSRFindGrid(context,sample.end_msc-1000,diagnostic_anchor))
      g_events[slot].log_return_1000_valid=TSResearchExactLogReturn(sample.end_msc,point.mid,1000,diagnostic_anchor.time_msc,diagnostic_anchor.mid,g_events[slot].log_return_1000);
   g_events[slot].percentile_threshold=context.baseline_percentile[detector];
   g_events[slot].median_abs_return=context.baseline_median[detector];
   g_events[slot].mad_abs_return=context.baseline_mad[detector];
   g_events[slot].robust_scale=context.baseline_scale[detector];
   g_events[slot].robust_scale_floored=context.baseline_scale_floored[detector];
   g_events[slot].robust_z=robust_z;
   g_events[slot].efficiency=efficiency;
   g_events[slot].tick_count=sample.tick_count;
   g_events[slot].tick_intensity_ratio=intensity;
   g_events[slot].spread=sample.spread;
   g_events[slot].spread_median=context.spread_median_5m[detector];
   g_events[slot].move_spread_ratio=move_spread;
   g_events[slot].quote_age_ms=sample.quote_age_ms;
   g_events[slot].baseline_samples=context.baseline_samples[detector];
   g_events[slot].detection_best_mid=point.mid;
   g_events[slot].detection_worst_mid=point.mid;
   g_events[slot].state_status="BURST_ACTIVE";
   g_events[slot].news_label="UNAVAILABLE";
   g_events[slot].m15_trend=TSRTrend(symbol_index,PERIOD_M15);
   g_events[slot].h1_trend=TSRTrend(symbol_index,PERIOD_H1);
   g_events[slot].htf_alignment=TSRAlignment(g_events[slot].direction,g_events[slot].m15_trend,g_events[slot].h1_trend);
   g_events[slot].session=TSRSessionLabel(sample.end_msc);
   TSEngineStartBurst(g_events[slot].machine,g_events[slot].direction,sample.end_msc,sample.start_mid,sample.end_mid);
   TSRRegisterStrategySignal(g_events[slot],TSR_DETECTION_CONTINUATION,g_events[slot].direction,sample.end_msc,processing_msc,point.bid,point.ask);
   ++g_total_events;
   ++context.valid_events[detector];
   TSRDebug(context.symbol,"independent detector shock event="+g_events[slot].event_id);
  }

int TSRV1TrailingTickCount(const TSRSymbolContext &context,const long start_msc,const long end_msc)
  {
   int count=0;
   int oldest=TSROldestTick(context);
   if(oldest<0) return 0;
   for(int i=0;i<context.tick_ring.count;++i)
     {
      int index=(oldest+i)%TSR_TICK_CAPACITY;
      if(context.ticks[index].time_msc>start_msc && context.ticks[index].time_msc<=end_msc) ++count;
     }
   return count;
  }

double TSRV1WilsonHalfWidth(const double p,const int count)
  {
   if(count<=0 || p<0.0 || p>1.0) return 0.0;
   return 1.96*MathSqrt(p*(1.0-p)/(double)(count+1));
  }

bool TSRV1RegisterCandidateEvent(TSRSymbolContext &context,
                                 const int symbol_index,
                                 const TSRV1Candidate &candidate,
                                 const TSRGridPoint &confirmed_point,
                                 const long confirmed_msc,
                                 const long processing_msc)
  {
   int trigger=candidate.trigger_horizon_index;
   if(trigger<0 || trigger>=TSV1_HORIZON_COUNT || candidate.direction==0) return false;
   TickShockEventKey event_key;
   event_key.symbol_index=symbol_index;
   event_key.detector_window_ms=TSV1_HORIZONS_MS[trigger];
   event_key.detection_msc=confirmed_msc;
   TickShockEventRegistration registration;
   if(!TSEngineRegisterResearchEvent(g_event_engine,context.symbol_cluster_clock,event_key,2000,registration))
     {
      if(registration.status==TS_EVENT_REGISTRATION_POOL_EXHAUSTED)
         PrintFormat("%s validation invalid: active event pool exhausted symbol=%s",TSR_NAME,context.symbol);
      return false;
     }
   int slot=registration.slot;
   TSREvent event;
   ZeroMemory(event);
   event.active=true;
   for(int j=0;j<TSR_ALL_SCENARIOS;++j) TSRResetScenario(event.scenarios[j]);
   event.symbol_index=symbol_index;
   event.detector_version=InpDetectorVersion;
   event.detector_window_ms=TSV1_HORIZONS_MS[trigger];
   event.event_id=StringFormat("%s_%s_%s_w%d_%I64d_%I64d",InpRunId,context.symbol,TSV1DetectorName(InpDetectorVersion),event.detector_window_ms,confirmed_msc,registration.event_sequence);
   event.direction=candidate.direction;
   event.shock_gate_mask=0;
   event.symbol_cluster_id=registration.symbol_cluster_id;
   event.symbol_overlap_event=registration.symbol_overlap;
   event.market_cluster_id=registration.market_cluster_id;
   event.market_overlap_event=registration.market_overlap;
   event.detector_candidate_msc=candidate.candidate_msc;
   event.detector_confirmed_msc=confirmed_msc;
   event.detector_trigger_horizon_ms=event.detector_window_ms;
   event.detector_horizon_mask=candidate.horizon_mask;
   for(int h=0;h<TSV1_HORIZON_COUNT;++h)
     {
      event.detector_raw_p[h]=candidate.raw_p[h];
      event.detector_adjusted_p[h]=candidate.adjusted_p[h];
      event.detector_tail_valid[h]=candidate.tail_valid[h];
     }
   event.detector_score=candidate.score[trigger];
   event.detector_local_sigma=candidate.local_sigma[trigger];
   event.detector_local_samples=candidate.baseline_count[trigger];
   event.detector_calibration_samples=candidate.calibration_count[trigger];
   event.detector_quantile_half_width=TSRV1WilsonHalfWidth(candidate.raw_p[trigger],candidate.calibration_count[trigger]);
   event.detector_tod_bucket=candidate.tod_bucket;
   event.detector_volatility_regime=candidate.volatility_regime;
   event.detector_noise_return=candidate.noise_return;
   event.detector_diagnostics=candidate.diagnostics;
   event.detection_msc=confirmed_msc;
   event.detection_grid_msc=confirmed_msc;
   event.detection_quote_msc=confirmed_point.quote_msc;
   event.detection_quote_age_ms=confirmed_point.quote_age_ms;
   event.processing_msc=processing_msc;
   event.decision_delay_ms=MathMax((long)0,processing_msc-confirmed_msc);
   event.detection_bid=confirmed_point.bid;
   event.detection_ask=confirmed_point.ask;
   event.detection_mid=confirmed_point.mid;
   event.shock_start_mid=candidate.anchor_mid;
   event.detection_shock_range=MathAbs(confirmed_point.mid-candidate.anchor_mid);
   TSRGridPoint diagnostic_anchor;
   if(TSRFindGrid(context,confirmed_msc-250,diagnostic_anchor))
      event.log_return_250_valid=TSResearchExactLogReturn(confirmed_msc,confirmed_point.mid,250,diagnostic_anchor.time_msc,diagnostic_anchor.mid,event.log_return_250);
   if(TSRFindGrid(context,confirmed_msc-500,diagnostic_anchor))
      event.log_return_500_valid=TSResearchExactLogReturn(confirmed_msc,confirmed_point.mid,500,diagnostic_anchor.time_msc,diagnostic_anchor.mid,event.log_return_500);
   if(TSRFindGrid(context,confirmed_msc-1000,diagnostic_anchor))
      event.log_return_1000_valid=TSResearchExactLogReturn(confirmed_msc,confirmed_point.mid,1000,diagnostic_anchor.time_msc,diagnostic_anchor.mid,event.log_return_1000);
   event.percentile_threshold=0.0;
   event.median_abs_return=0.0;
   event.mad_abs_return=0.0;
   event.robust_scale=candidate.local_sigma[trigger];
   event.robust_scale_floored=candidate.local_sigma[trigger]<=candidate.noise_return+1e-15;
   event.robust_z=candidate.score[trigger];
   event.efficiency=candidate.efficiency;
   event.tick_count=candidate.tick_count;
   event.tick_intensity_ratio=candidate.tick_intensity_ratio;
   event.spread=confirmed_point.ask-confirmed_point.bid;
   event.spread_median=candidate.spread_median;
   event.move_spread_ratio=candidate.move_spread_ratio;
   event.quote_age_ms=confirmed_point.quote_age_ms;
   event.baseline_samples=candidate.baseline_count[trigger];
   event.detection_best_mid=confirmed_point.mid;
   event.detection_worst_mid=confirmed_point.mid;
   event.state_status="BURST_ACTIVE";
   event.news_label="UNAVAILABLE";
   event.m15_trend=TSRTrend(symbol_index,PERIOD_M15);
   event.h1_trend=TSRTrend(symbol_index,PERIOD_H1);
   event.htf_alignment=TSRAlignment(event.direction,event.m15_trend,event.h1_trend);
   event.session=TSRSessionLabel(confirmed_msc);
   TSEngineStartBurst(event.machine,event.direction,confirmed_msc,candidate.anchor_mid,confirmed_point.mid);
   TSRRegisterStrategySignal(event,TSR_DETECTION_CONTINUATION,event.direction,confirmed_msc,processing_msc,confirmed_point.bid,confirmed_point.ask);
   g_events[slot]=event;
   ++g_total_events;
   ++context.valid_events[trigger];
   TSRDebug(context.symbol,"statistical detector event="+event.event_id);
   return true;
  }

bool TSRV1BuildCandidate(TSRSymbolContext &context,
                         const TSRGridPoint &point,
                         const TickShockV1ReturnRecord &record,
                         const double &raw_returns[],
                         const bool &raw_valid[],
                         const double &robust_returns[],
                         const bool &robust_valid[],
                         TSRV1Candidate &candidate)
  {
   ZeroMemory(candidate);
   int estimator=InpDetectorVersion==TAIL_V1_RAW?0:1;
   double p[TSV1_HORIZON_COUNT];bool valid[TSV1_HORIZON_COUNT];
   ArrayInitialize(p,1.0);ArrayInitialize(valid,false);
   for(int h=0;h<TSV1_HORIZON_COUNT;++h)
     {
      TickShockV1TailResult tail;int calibration_count=0;
      if(TSV1CalibrationTail(context.v1_calibration,estimator,h,record,10000,tail,calibration_count))
        {
         p[h]=tail.raw_p;valid[h]=true;++context.v1_tail_ready_count;
         if(tail.raw_p<=0.01){++g_total_raw;++context.raw_candidates[h];}
        }
      candidate.raw_p[h]=p[h];candidate.tail_valid[h]=valid[h];
      int channel=TSV1Channel(estimator,h);
      candidate.score[h]=record.score[channel];candidate.local_sigma[h]=record.local_sigma[channel];
      candidate.baseline_count[h]=record.local_samples[channel];candidate.calibration_count[h]=calibration_count;
     }
   double adjusted[];TSV1HolmAdjust(p,valid,TSV1_HORIZON_COUNT,adjusted);
   int trigger=TSV1TriggerIndex(adjusted,valid,TSV1_HORIZON_COUNT,0.01);
   for(int h=0;h<TSV1_HORIZON_COUNT;++h) candidate.adjusted_p[h]=h<ArraySize(adjusted)?adjusted[h]:1.0;
   if(trigger<0) return false;
   TSRGridPoint anchor;
   if(!TSRFindGrid(context,point.time_msc-TSV1_HORIZONS_MS[trigger],anchor)) return false;
   double chosen_return=estimator==0?raw_returns[trigger]:robust_returns[trigger];
   bool chosen_valid=estimator==0?raw_valid[trigger]:robust_valid[trigger];
   if(!chosen_valid || chosen_return==0.0) return false;
   candidate.active=true;
   candidate.candidate_msc=point.time_msc;
   candidate.direction=chosen_return>0.0?1:-1;
   candidate.trigger_horizon_index=trigger;
   candidate.horizon_mask=TSV1HorizonMask(adjusted,valid,TSV1_HORIZON_COUNT,0.01);
   candidate.candidate_point=point;
   candidate.anchor_mid=anchor.mid;
   candidate.estimator_anchor_mid=estimator==0?anchor.mid:anchor.robust_mid;
   candidate.tod_bucket=record.tod_bucket[TSV1Channel(estimator,trigger)];
   candidate.volatility_regime=record.volatility_regime[TSV1Channel(estimator,trigger)];
   candidate.noise_return=context.tick_size/MathMax(point.mid,context.tick_size);
   candidate.tick_count=TSRV1TrailingTickCount(context,point.time_msc-TSV1_HORIZONS_MS[trigger],point.time_msc);
   candidate.efficiency=0.0;
   TSRPathEfficiency(context,point.time_msc-TSV1_HORIZONS_MS[trigger],point.time_msc,anchor.mid,point.mid,candidate.efficiency);
   double median_ticks=context.baseline_median_ticks[trigger];
   candidate.tick_intensity_ratio=median_ticks>0.0?candidate.tick_count/median_ticks:0.0;
   candidate.spread_median=context.spread_median_5m[trigger];
   double spread=point.ask-point.bid;
   candidate.move_spread_ratio=spread>0.0?MathAbs(point.mid-anchor.mid)/spread:0.0;
   candidate.spread_ratio=candidate.spread_median>0.0?spread/candidate.spread_median:0.0;
   TSV1SeparateDiagnostics(true,candidate.efficiency,candidate.tick_intensity_ratio,candidate.move_spread_ratio,candidate.spread_ratio,candidate.diagnostics);
   ++context.v1_statistical_candidates;
   return true;
  }

void TSRV1EvaluateBoundary(TSRSymbolContext &context,
                           const int symbol_index,
                           const TSRGridPoint &point,
                           const long processing_msc)
  {
   ++context.v1_boundary_count;
   if(!point.valid || !TSV1QuoteIntegrity(point.time_msc,point.quote_msc,point.bid,point.ask,InpMaxQuoteAgeMs))
     {++context.v1_integrity_rejections;return;}
   double raw_returns[TSV1_HORIZON_COUNT],robust_returns[TSV1_HORIZON_COUNT];
   bool raw_valid[TSV1_HORIZON_COUNT],robust_valid[TSV1_HORIZON_COUNT];
   ArrayInitialize(raw_returns,0.0);ArrayInitialize(robust_returns,0.0);
   ArrayInitialize(raw_valid,false);ArrayInitialize(robust_valid,false);
   for(int h=0;h<TSV1_HORIZON_COUNT;++h)
     {
      TSRGridPoint anchor;
      if(!TSRFindGrid(context,point.time_msc-TSV1_HORIZONS_MS[h],anchor)) continue;
      raw_valid[h]=TSV1ExactLogReturn(point.time_msc,point.mid,TSV1_HORIZONS_MS[h],anchor.time_msc,anchor.mid,raw_returns[h]);
      if(point.robust_valid && anchor.robust_valid)
         robust_valid[h]=TSV1ExactLogReturn(point.time_msc,point.robust_mid,TSV1_HORIZONS_MS[h],anchor.time_msc,anchor.robust_mid,robust_returns[h]);
     }
   double noise_return=context.tick_size/MathMax(point.mid,context.tick_size);
   TickShockV1ReturnRecord record;
   TSV1ObserveBoundary(context.v1_calibration,point.time_msc,raw_returns,raw_valid,robust_returns,robust_valid,
                       noise_return,InpBaselineMinutes,InpBaselineExcludeMs,InpMinBaselineSamples,record);

   if(InpDetectorVersion==TAIL_V1_PERSISTENT && context.v1_pending_candidate.active)
     {
      TSRV1Candidate prior=context.v1_pending_candidate;
      bool confirmed=point.time_msc==prior.candidate_msc+250 && point.robust_valid && prior.candidate_point.robust_valid &&
                     TSV1PersistenceConfirmed(prior.direction,prior.estimator_anchor_mid,prior.candidate_point.robust_mid,point.robust_mid,0.50);
      if(confirmed) TSRV1RegisterCandidateEvent(context,symbol_index,prior,point,point.time_msc,processing_msc);
      else ++context.v1_persistence_rejections;
      ZeroMemory(context.v1_pending_candidate);
     }

   TSRV1Candidate candidate;
   if(!TSRV1BuildCandidate(context,point,record,raw_returns,raw_valid,robust_returns,robust_valid,candidate)) return;
   if(InpDetectorVersion==TAIL_V1_PERSISTENT) context.v1_pending_candidate=candidate;
   else TSRV1RegisterCandidateEvent(context,symbol_index,candidate,point,point.time_msc,processing_msc);
  }

void TSRCloseGridBoundary(TSRSymbolContext &context,const int symbol_index,const long boundary_msc,const long processing_msc)
  {
   TSRGridPoint point;
   point.time_msc=boundary_msc;
   point.quote_msc=context.grid_runtime.quote_msc;
   point.bid=context.grid_runtime.bid;
   point.ask=context.grid_runtime.ask;
   point.mid=context.grid_runtime.mid;
   point.robust_mid=0.0;
   point.robust_valid=false;
   point.quote_age_ms=context.grid_runtime.quote_msc>0?(int)MathMax((long)0,boundary_msc-context.grid_runtime.quote_msc):2147483647;
   point.valid=context.grid_runtime.mid>0.0 && context.grid_runtime.ask>context.grid_runtime.bid && point.quote_age_ms<=InpMaxQuoteAgeMs;
   TSRGridPoint robust_250,robust_500;
   if(point.valid && TSRFindGrid(context,boundary_msc-250,robust_250) && TSRFindGrid(context,boundary_msc-500,robust_500))
      point.robust_valid=TSV1CausalPreaverage(point.mid,robust_250.mid,robust_500.mid,point.robust_mid);
   TSRAddGrid(context,point);
   for(int detector=0;detector<TSR_DETECTOR_COUNT;++detector)
     {
      int window_ms=TSR_DETECTOR_MS[detector];
      if(!TSDetectorBoundary(boundary_msc,window_ms)) continue;
      int ticks=context.ticks_since_window[detector];
      context.ticks_since_window[detector]=0;
      TSRGridPoint prior;
      if(!point.valid || !TSRFindGrid(context,boundary_msc-window_ms,prior))
        {
         ++context.grid_missing[detector];
         TSRCountPreSkip(symbol_index,"grid_missing");
         continue;
        }
      bool valid=false;
      double signed_return=TSRLogReturn(point.mid,prior.mid,valid);
      double signed_move=0.0;
      double absolute_move=0.0;
      if(!valid || !TSFixedMidMove(point.mid,prior.mid,signed_move,absolute_move))
        {
         TSRCountPreSkip(symbol_index,"invalid_denominator");
         continue;
        }
      TSRSecondSample sample;
      sample.end_msc=boundary_msc;
      sample.start_mid=prior.mid;
      sample.end_mid=point.mid;
      sample.signed_log_return=signed_return;
      sample.abs_log_return=MathAbs(signed_return);
      sample.price_move=absolute_move;
      sample.tick_count=ticks;
      sample.spread=point.ask-point.bid;
      sample.quote_age_ms=point.quote_age_ms;
      TSRAddSample(context,detector,sample);
      if(InpDetectorVersion==STRICT_V0)
         TSRDetectShock(context,symbol_index,detector,sample,point,processing_msc);
      else
         TSRRefreshBaseline(context,detector,sample.end_msc);
     }
   if(InpDetectorVersion!=STRICT_V0)
      TSRV1EvaluateBoundary(context,symbol_index,point,processing_msc);
  }

void TSRAdvanceGridBeforeTick(TSRSymbolContext &context,const int symbol_index,const long tick_msc,const long processing_msc)
  {
   if(context.grid_runtime.next_boundary_msc<=0) return;
   while(context.grid_runtime.next_boundary_msc<tick_msc)
     {
      TSRCloseGridBoundary(context,symbol_index,context.grid_runtime.next_boundary_msc,processing_msc);
      TSGridAdvanceBoundary(context.grid_runtime,InpGridMs);
     }
  }

void TSRAdvanceGridAtTick(TSRSymbolContext &context,const int symbol_index,const long tick_msc,const long processing_msc)
  {
   while(context.grid_runtime.next_boundary_msc>0 && context.grid_runtime.next_boundary_msc==tick_msc)
     {
      TSRCloseGridBoundary(context,symbol_index,context.grid_runtime.next_boundary_msc,processing_msc);
      TSGridAdvanceBoundary(context.grid_runtime,InpGridMs);
     }
  }

void TSRWriteDetectorFeature(const TSREvent &event)
  {
   if(g_features_file==INVALID_HANDLE) return;
   ENUM_TS_V1_DETECTOR detector=event.detector_version;
   long candidate_msc=event.detector_candidate_msc>0?event.detector_candidate_msc:event.detection_msc;
   long confirmed_msc=event.detector_confirmed_msc>0?event.detector_confirmed_msc:event.detection_msc;
   int trigger_horizon=event.detector_trigger_horizon_ms>0?event.detector_trigger_horizon_ms:event.detector_window_ms;
   int trigger=TSRDetectorIndex(trigger_horizon);
   TickShockV1Diagnostics diagnostics=event.detector_diagnostics;
   if(detector==STRICT_V0)
     {
      diagnostics.statistical_shock=true;
      diagnostics.directional_burst=(event.shock_gate_mask&(1<<2))!=0;
      diagnostics.activity_elevated=(event.shock_gate_mask&(1<<3))!=0;
      diagnostics.liquidity_normal=(event.shock_gate_mask&(1<<5))!=0;
      diagnostics.cost_feasible=(event.shock_gate_mask&(1<<4))!=0 && diagnostics.liquidity_normal;
     }
   diagnostics.strategy_signal=false;
   for(int s=0;s<TSR_STRATEGY_COUNT;++s) diagnostics.strategy_signal=diagnostics.strategy_signal || event.signal_started[s];
   double empirical_percentile=0.0;
   ENUM_TS_V1_SEVERITY severity=TSV1_SEVERITY_NONE;
   if(detector!=STRICT_V0 && trigger>=0 && event.detector_tail_valid[trigger])
     {
      empirical_percentile=100.0*(1.0-event.detector_raw_p[trigger]);
      severity=TSV1Severity(event.detector_adjusted_p[trigger],event.detector_calibration_samples);
     }
   string line="";
   TSRCsvAppend(line,event.event_id);TSRCsvAppend(line,g_symbols[event.symbol_index].symbol);TSRCsvAppend(line,TSV1DetectorName(detector));
   TSRCsvAppend(line,TSV1FeatureSchema());TSRCsvAppend(line,TSV1SpecSha256());TSRCsvAppend(line,TSRLong(candidate_msc));TSRCsvAppend(line,TSRLong(confirmed_msc));
   int strict_mask=trigger>=0?(1<<trigger):0;
   TSRCsvAppend(line,IntegerToString(trigger_horizon));TSRCsvAppend(line,IntegerToString(detector==STRICT_V0?strict_mask:event.detector_horizon_mask));
   for(int h=0;h<TSV1_HORIZON_COUNT;++h) TSRCsvAppend(line,detector!=STRICT_V0 && event.detector_tail_valid[h]?TSRDouble(event.detector_raw_p[h],12):"");
   for(int h=0;h<TSV1_HORIZON_COUNT;++h) TSRCsvAppend(line,detector!=STRICT_V0 && event.detector_tail_valid[h]?TSRDouble(event.detector_adjusted_p[h],12):"");
   TSRCsvAppend(line,detector!=STRICT_V0?TSRDouble(empirical_percentile,8):"");TSRCsvAppend(line,detector!=STRICT_V0?TSV1SeverityName(severity):"LEGACY_STRICT");
   TSRCsvAppend(line,detector!=STRICT_V0?TSRDouble(event.detector_score,10):TSRDouble(event.robust_z,10));
   TSRCsvAppend(line,detector!=STRICT_V0?TSRDouble(event.detector_local_sigma,12):TSRDouble(event.robust_scale,12));
   TSRCsvAppend(line,IntegerToString(detector!=STRICT_V0?event.detector_local_samples:event.baseline_samples));
   TSRCsvAppend(line,detector!=STRICT_V0?IntegerToString(event.detector_calibration_samples):"");
   TSRCsvAppend(line,detector!=STRICT_V0?TSRDouble(event.detector_quantile_half_width,12):"");
   TSRCsvAppend(line,detector!=STRICT_V0?IntegerToString(event.detector_tod_bucket):IntegerToString(TSV1TimeOfDayBucket(event.detection_msc)));
   TSRCsvAppend(line,detector!=STRICT_V0?TSV1VolatilityRegimeName((ENUM_TS_V1_VOLATILITY_REGIME)event.detector_volatility_regime):"LEGACY");
   TSRCsvAppend(line,detector!=STRICT_V0?TSRDouble(event.detector_noise_return,12):"");
   TSRCsvAppend(line,TSRDouble(event.efficiency,8));TSRCsvAppend(line,TSRDouble(event.tick_intensity_ratio,8));TSRCsvAppend(line,TSRDouble(event.move_spread_ratio,8));
   TSRCsvAppend(line,event.spread_median>0.0?TSRDouble(event.spread/event.spread_median,8):"");TSRCsvAppend(line,IntegerToString(event.quote_age_ms));
   TSRCsvAppend(line,TSRBool(diagnostics.statistical_shock));TSRCsvAppend(line,TSRBool(diagnostics.directional_burst));TSRCsvAppend(line,TSRBool(diagnostics.activity_elevated));
   TSRCsvAppend(line,TSRBool(diagnostics.liquidity_normal));TSRCsvAppend(line,TSRBool(diagnostics.cost_feasible));TSRCsvAppend(line,TSRBool(diagnostics.strategy_signal));
   TSMt5WriteLine(g_features_file,line);
   TSMt5Flush(g_features_file);
  }

void TSRWriteEvent(TSREvent &event)
  {
   if(event.csv_written || g_event_file==INVALID_HANDLE) return;
   string line="";
   TSRCsvAppend(line,event.event_id);TSRCsvAppend(line,TSRExecutionModeName());TSRCsvAppend(line,g_symbols[event.symbol_index].symbol);TSRCsvAppend(line,TSRDirection(event.direction));
   TSRCsvAppend(line,IntegerToString(event.detector_window_ms));TSRCsvAppend(line,TSRLong(event.symbol_cluster_id));TSRCsvAppend(line,TSRLong(event.market_cluster_id));TSRCsvAppend(line,TSRBool(event.symbol_overlap_event));TSRCsvAppend(line,TSRBool(event.market_overlap_event));TSRCsvAppend(line,IntegerToString(event.shock_gate_mask));
   TSRCsvAppend(line,TSRLong(event.detection_msc));TSRCsvAppend(line,TSRLong(event.detection_grid_msc));TSRCsvAppend(line,TSRLong(event.detection_quote_msc));TSRCsvAppend(line,IntegerToString(event.detection_quote_age_ms));TSRCsvAppend(line,TSRLong(event.processing_msc));TSRCsvAppend(line,TSRLong(event.decision_delay_ms));
   TSRCsvAppend(line,TSRDouble(event.detection_bid));TSRCsvAppend(line,TSRDouble(event.detection_ask));TSRCsvAppend(line,TSRDouble(event.detection_mid));TSRCsvAppend(line,TSRDouble(event.shock_start_mid));TSRCsvAppend(line,TSRDouble(event.detection_shock_range));
   TSRCsvAppend(line,event.log_return_250_valid?TSRDouble(event.log_return_250,12):"");TSRCsvAppend(line,TSRBool(event.log_return_250_valid));
   TSRCsvAppend(line,event.log_return_500_valid?TSRDouble(event.log_return_500,12):"");TSRCsvAppend(line,TSRBool(event.log_return_500_valid));
   TSRCsvAppend(line,event.log_return_1000_valid?TSRDouble(event.log_return_1000,12):"");TSRCsvAppend(line,TSRBool(event.log_return_1000_valid));
   TSRCsvAppend(line,TSRDouble(event.percentile_threshold,12));TSRCsvAppend(line,TSRDouble(event.median_abs_return,12));TSRCsvAppend(line,TSRDouble(event.mad_abs_return,12));TSRCsvAppend(line,TSRDouble(event.robust_scale,12));
   TSRCsvAppend(line,TSRBool(event.robust_scale_floored));TSRCsvAppend(line,TSRDouble(event.robust_z,6));TSRCsvAppend(line,TSRDouble(event.efficiency,6));TSRCsvAppend(line,IntegerToString(event.tick_count));
   TSRCsvAppend(line,TSRDouble(event.tick_intensity_ratio,6));TSRCsvAppend(line,TSRDouble(event.spread));TSRCsvAppend(line,TSRDouble(event.spread_median));TSRCsvAppend(line,TSRDouble(event.move_spread_ratio,6));
   TSRCsvAppend(line,IntegerToString(event.quote_age_ms));TSRCsvAppend(line,IntegerToString(event.baseline_samples));TSRCsvAppend(line,TSRLong(event.burst_end_msc));
   double burst_spread_ratio=event.spread>0.0?event.burst_range/event.spread:0.0;
   TSRCsvAppend(line,TSRDouble(event.burst_end_bid));TSRCsvAppend(line,TSRDouble(event.burst_end_ask));TSRCsvAppend(line,TSRDouble(event.burst_end_mid));TSRCsvAppend(line,TSRDouble(event.burst_range));TSRCsvAppend(line,TSRDouble(burst_spread_ratio,6));
   TSRCsvAppend(line,TSRDouble(event.max_retracement_pct,4));TSRCsvAppend(line,TSRLong(event.pullback_msc));TSRCsvAppend(line,TSRLong(event.reacceleration_msc));TSRCsvAppend(line,TSRLong(event.continuation_invalidated_msc));
   TSRCsvAppend(line,event.m15_trend);TSRCsvAppend(line,event.h1_trend);TSRCsvAppend(line,event.htf_alignment);TSRCsvAppend(line,event.session);TSRCsvAppend(line,event.news_label);
   TSRCsvAppend(line,event.state_status);TSRCsvAppend(line,event.state_skip_reason);
   for(int strategy=0;strategy<TSR_STRATEGY_COUNT;++strategy)
     {
      TSRCsvAppend(line,event.signal_started[strategy]?TSRLong(event.signal_event_msc[strategy]):"");
      TSRCsvAppend(line,event.signal_started[strategy]?TSRLong(event.signal_processing_msc[strategy]):"");
     }
   for(int i=0;i<TSR_CHECKPOINT_COUNT;++i)
     {
      TSRCsvAppend(line,event.detection_checkpoint_done[i]?TSRDouble(event.detection_checkpoint_bid[i]):"");
      TSRCsvAppend(line,event.detection_checkpoint_done[i]?TSRDouble(event.detection_checkpoint_ask[i]):"");
      TSRCsvAppend(line,event.detection_checkpoint_done[i]?TSRDouble(event.detection_checkpoint_mfe[i]):"");
      TSRCsvAppend(line,event.detection_checkpoint_done[i]?TSRDouble(event.detection_checkpoint_mae[i]):"");
     }
   for(int i=0;i<TSR_CHECKPOINT_COUNT;++i)
     {
      TSRCsvAppend(line,event.burst_checkpoint_done[i]?TSRDouble(event.burst_checkpoint_bid[i]):"");
      TSRCsvAppend(line,event.burst_checkpoint_done[i]?TSRDouble(event.burst_checkpoint_ask[i]):"");
      TSRCsvAppend(line,event.burst_checkpoint_done[i]?TSRDouble(event.burst_checkpoint_mfe[i]):"");
      TSRCsvAppend(line,event.burst_checkpoint_done[i]?TSRDouble(event.burst_checkpoint_mae[i]):"");
     }
   string grid="";
   for(int i=0;i<TSR_ALL_SCENARIOS;++i)
     {
      int strategy=i/TSR_SCENARIO_COUNT;
      int local=i%TSR_SCENARIO_COUNT;
      int stop_index=local/(TSR_DELAY_COUNT*TSR_SPREAD_COUNT);
      int rem=local%(TSR_DELAY_COUNT*TSR_SPREAD_COUNT);
      int delay_index=rem/TSR_SPREAD_COUNT;
      int spread_index=rem%TSR_SPREAD_COUNT;
      ENUM_TS_SCENARIO_STATUS scenario_status=event.scenarios[i].status;
      string scenario_status_name=TSScenarioStatusName(scenario_status);
      bool result_available=event.scenarios[i].done &&
                            (scenario_status==TS_SCENARIO_TP_LIMIT || scenario_status==TS_SCENARIO_SL_GAP || scenario_status==TS_SCENARIO_TIME_MARKET);
      long actual_delay=event.scenarios[i].entry_quote_msc>0 && event.scenarios[i].signal_event_msc>0?event.scenarios[i].entry_quote_msc-event.scenarios[i].signal_event_msc:-1;
      long processing_to_entry=event.scenarios[i].entry_quote_msc>0 && event.scenarios[i].signal_processing_msc>0?event.scenarios[i].entry_quote_msc-event.scenarios[i].signal_processing_msc:-1;
      string item=StringFormat("%s|w%.1f|d%d|s%d|%s|net=%s|gross=%s|signal_event=%I64d|signal_processing=%I64d|eligible=%I64d|entry_quote=%I64d|exit=%I64d|actual_delay=%I64d|processing_to_entry=%I64d|policy=%d|risk=%s|sl=%s|tp=%s|requested_rr=%s|realized_rr=%s|stops_distance=%s|freeze_distance=%s|freeze_clear=%s|exit_px=%s|stop_gap=%s|exit_slip=%s|commission_r=%s",
                               TSRStrategyName(strategy),TSRStopMultiple(stop_index),TSR_DELAY_MS[delay_index],(int)MathRound(TSR_SPREAD_MULT[spread_index]*100.0),
                               scenario_status_name,
                               result_available?TSRDouble(event.scenarios[i].result_r,6):"",
                               result_available?TSRDouble(event.scenarios[i].gross_r,6):"",
                               event.scenarios[i].signal_event_msc,event.scenarios[i].signal_processing_msc,event.scenarios[i].entry_eligible_msc,event.scenarios[i].entry_quote_msc,event.scenarios[i].exit_msc,actual_delay,processing_to_entry,event.scenarios[i].policy_mask,
                               TSRDouble(event.scenarios[i].risk),TSRDouble(event.scenarios[i].sl),TSRDouble(event.scenarios[i].tp),TSRDouble(event.scenarios[i].requested_rr,6),TSRDouble(event.scenarios[i].realized_rr,6),TSRDouble(event.scenarios[i].stops_distance),TSRDouble(event.scenarios[i].freeze_distance),TSRBool(event.scenarios[i].freeze_clear),
                               TSRDouble(event.scenarios[i].exit_price),TSRDouble(event.scenarios[i].stop_gap),TSRDouble(event.scenarios[i].exit_slippage),TSRDouble(event.scenarios[i].commission_r,6));
      if(grid!="") grid+=";";
      grid+=item;
      if(result_available)
        {
         ++g_scenario_valid[i];
         g_scenario_sum_r[i]+=event.scenarios[i].result_r;
         ++g_scenario_csv_recount_valid;
         g_scenario_csv_recount_sum_r+=event.scenarios[i].result_r;
         if(scenario_status==TS_SCENARIO_TP_LIMIT) ++g_scenario_status_counts[0];
         else if(scenario_status==TS_SCENARIO_SL_GAP) ++g_scenario_status_counts[1];
         else ++g_scenario_status_counts[2];
        }
      else if(TSScenarioStatusIsInvalid(scenario_status))
        {
         ++g_scenario_invalid[i];
         ++g_scenario_csv_recount_invalid;
         if(scenario_status==TS_SCENARIO_INVALID_BROKER_STOP) ++g_scenario_status_counts[3];
         else if(scenario_status==TS_SCENARIO_INVALID_BROKER_TARGET) ++g_scenario_status_counts[4];
         else if(scenario_status==TS_SCENARIO_INVALID_STALE_QUOTE) ++g_scenario_status_counts[5];
         else if(scenario_status==TS_SCENARIO_INVALID_SPREAD) ++g_scenario_status_counts[6];
         else ++g_scenario_status_counts[7];
        }
     }
   TSRCsvAppend(line,"strategy|stop_multiple_of_unstressed_fill_spread|requested_delay_ms|spread_pct|status|netR|grossR|signal_event_msc|signal_processing_msc|entry_eligible_msc|entry_quote_msc|exit_msc|actual_delay_ms|processing_to_entry_ms|policy_mask(cost=1,range=2)|risk|sl|tp|requested_rr|realized_rr|stops_distance|freeze_distance|freeze_clear_diagnostic|exit_price|stop_gap|exit_slippage|commissionR; policy does not invalidate outcomes");
   TSRCsvAppend(line,grid);
   TSMt5WriteLine(g_event_file,line);
   TSMt5Flush(g_event_file);
   TSRWriteDetectorFeature(event);
   if(event.burst_end_msc>0) ++g_valid_bursts;
   if(burst_spread_ratio>0.0)
     {
      int n=ArraySize(g_burst_spread_ratios);
      ArrayResize(g_burst_spread_ratios,n+1);
      g_burst_spread_ratios[n]=burst_spread_ratio;
     }
   if(event.pullback_msc>0) ++g_valid_pullbacks;
   if(event.reacceleration_msc>0) ++g_reacceleration_signals;
   if(event.signal_started[TSR_DETECTION_CONTINUATION]) ++g_detection_signals;
   if(event.signal_started[TSR_POST_BURST_CONTINUATION]) ++g_post_burst_signals;
   if(event.signal_started[TSR_PULLBACK_CONTINUATION]) ++g_pullback_signals;
   if(event.signal_started[TSR_FAILED_SHOCK_REVERSAL]) ++g_reversal_signals;
   TSRecordEventRow(g_event_engine);
   g_event_rows=g_event_engine.event_rows;
   event.csv_written=true;
  }

void TSRReleaseWrittenEvents()
  {
   for(int i=0;i<TSR_MAX_ACTIVE_EVENTS;++i)
      if(TSRCanWriteEvent(g_events[i]))
        {
         TSRWriteEvent(g_events[i]);
         g_events[i].active=false;
         TSReleaseEventSlot(g_event_engine,i);
        }
  }

void TSRProcessOneTick(const int symbol_index,const MqlTick &source,const long processing_msc,const bool close_equal_boundary)
  {
   if(source.bid<=0.0 || source.ask<=source.bid || source.time_msc<=0) return;
   long time_msc=(long)source.time_msc;
   if(g_symbols[symbol_index].grid_runtime.next_boundary_msc<=0)
      g_symbols[symbol_index].grid_runtime.next_boundary_msc=((time_msc/InpGridMs)+1)*InpGridMs;
   TSRAdvanceGridBeforeTick(g_symbols[symbol_index],symbol_index,time_msc,processing_msc);
   TSGridObserveQuote(g_symbols[symbol_index].grid_runtime,time_msc,source.bid,source.ask,InpGridMs);
   TSRAddTick(g_symbols[symbol_index],source);
   for(int d=0;d<TSR_DETECTOR_COUNT;++d) ++g_symbols[symbol_index].ticks_since_window[d];
   long minute=time_msc/60000;
   if(minute!=g_symbols[symbol_index].last_m1_minute)
     {
      g_symbols[symbol_index].last_m1_minute=minute;
      ++g_symbols[symbol_index].m1_minutes_seen;
     }
   ++g_symbols[symbol_index].ticks_processed;
   ++g_total_ticks;
   TSRShortTick tick;
   tick.time_msc=time_msc;tick.bid=source.bid;tick.ask=source.ask;tick.mid=g_symbols[symbol_index].grid_runtime.mid;
   for(int i=0;i<TSR_MAX_ACTIVE_EVENTS;++i)
      if(g_events[i].active && g_events[i].symbol_index==symbol_index)
         TSRProcessEventTick(g_events[i],tick,processing_msc);
   if(close_equal_boundary) TSRAdvanceGridAtTick(g_symbols[symbol_index],symbol_index,time_msc,processing_msc);
   TSRReleaseWrittenEvents();
  }

void TSRCollectSymbolTicks(const int symbol_index,TickShockPendingRepository &repository,
                           const long requested_to_msc,const bool final_drain=false)
  {
   int loops=0;bool exhausted=false;bool last_page_full=false;
   long cycle_from=g_symbols[symbol_index].last_time_msc;
   bool synchronized=TSMt5SeriesSynchronized(g_symbols[symbol_index].symbol);
   TSFrontierBeginReadCycle(g_symbols[symbol_index].frontier,cycle_from,requested_to_msc,synchronized,final_drain);
   while(loops<64)
     {
      ++loops;
      MqlTick copied[];
      ulong from_msc=g_symbols[symbol_index].last_time_msc>0?(ulong)g_symbols[symbol_index].last_time_msc:0;
      int requested=g_symbols[symbol_index].last_time_msc>0?TSR_MAX_COPY_TICKS:1;
      ResetLastError();
      int count=TSMt5CopyInfoTicks(g_symbols[symbol_index].symbol,copied,from_msc,(uint)requested);
       if(count<=0)
         {
          int err=GetLastError();
          TSFrontierObserveCopyPage(g_symbols[symbol_index].frontier,count,requested,err,
                                    g_symbols[symbol_index].last_time_msc,true);
          if(err!=0) TSRDebug(g_symbols[symbol_index].symbol,"CopyTicks failed err="+IntegerToString(err));
          return;
        }
      long before_time=g_symbols[symbol_index].last_time_msc;
      int before_count=g_symbols[symbol_index].processed_at_last_msc;
      int seen_boundary=0,collected=0;
      for(int i=0;i<count;++i)
        {
         long t=(long)copied[i].time_msc;
         if(before_time>0 && t<before_time)
           {
            ++g_symbols[symbol_index].duplicate_ticks_skipped;
            continue;
           }
         if(before_time>0 && t==before_time)
           {
            ++seen_boundary;
            if(seen_boundary<=before_count)
              {
               ++g_symbols[symbol_index].duplicate_ticks_skipped;
               continue;
              }
           }
         if(!TSMergeAppend(repository,symbol_index,copied[i],TSR_PENDING_CAPACITY)) return;
         if(t!=g_symbols[symbol_index].last_time_msc)
           {
            g_symbols[symbol_index].last_time_msc=t;
            g_symbols[symbol_index].processed_at_last_msc=0;
           }
         ++g_symbols[symbol_index].processed_at_last_msc;
         ++collected;
        }
       exhausted=count<requested;last_page_full=!exhausted;
       TSFrontierObserveCopyPage(g_symbols[symbol_index].frontier,count,requested,0,
                                 g_symbols[symbol_index].last_time_msc,exhausted);
       if(exhausted) break;
       TickShockCursorProgress cursor_progress;
       if(!TSObserveCopyPageProgress(repository,before_time,before_count,g_symbols[symbol_index].last_time_msc,
                                    g_symbols[symbol_index].processed_at_last_msc,count,requested,cursor_progress))
         {TSFrontierObserveCursorStall(g_symbols[symbol_index].frontier);return;}
      }
   if(loops>=64 && last_page_full)
     {
      TSFrontierObservePageLimit(g_symbols[symbol_index].frontier);
      repository.validation_invalid=true;
      if(repository.fatal_reason=="") repository.fatal_reason="COPY_PAGE_LIMIT_REACHED";
     }
  }

long TSRProcessingMsc()
  {
   long result=TSMt5ServerNowMsc();
   for(int i=0;i<ArraySize(g_symbols);++i)
     {
      MqlTick quote;
      if(TSMt5VisibleQuote(g_symbols[i].symbol,quote)) result=MathMax(result,(long)quote.time_msc);
     }
   return result;
  }

void TSRSampleMemory()
  {
   long used=TSMt5MemoryUsedMb();
   if(used<0) return;
   ++g_memory_samples;
   g_memory_sum_mb+=(double)used;
   g_memory_max_mb=MathMax(g_memory_max_mb,used);
  }

void TSRProcessMergedPrefix(const int count,const long processing_msc)
  {
   int i=0;
   while(i<count)
     {
      int end=i+1;
      long group_msc=(long)g_pending_repository.items[i].tick.time_msc;
      int symbol_index=g_pending_repository.items[i].symbol_index;
      while(end<count && (long)g_pending_repository.items[end].tick.time_msc==group_msc &&
            g_pending_repository.items[end].symbol_index==symbol_index) ++end;
      int group_size=end-i;
      TSMergeObserveGroup(g_pending_repository,group_size);
      for(int j=i;j<end;++j)
        {
         long tick_msc=(long)g_pending_repository.items[j].tick.time_msc;
         TSMergeObserveProcessed(g_pending_repository,tick_msc);
         bool has_next=j+1<count;
         long next_msc=has_next?(long)g_pending_repository.items[j+1].tick.time_msc:0;
         int next_symbol=has_next?g_pending_repository.items[j+1].symbol_index:-1;
         bool final_quote=TSResearchFinalQuoteInSameMscGroup(tick_msc,symbol_index,has_next,next_msc,next_symbol);
         TSRProcessOneTick(symbol_index,g_pending_repository.items[j].tick,processing_msc,final_quote);
        }
      i=end;
     }
  }

void TSRDispatcher()
  {
   long processing_msc=TSRProcessingMsc();
   for(int i=0;i<ArraySize(g_symbols);++i) TSRCollectSymbolTicks(i,g_pending_repository,processing_msc,false);
   int count=ArraySize(g_pending_repository.items);
   TSMergeSortPending(g_pending_repository);

   // A tick is released only after every symbol has advanced beyond its
   // timestamp.  This watermark makes ordering global across dispatcher
   // calls, not merely within one CopyTicks batch.  Equality is retained so
   // another tick sharing the same time_msc cannot arrive after release.
   long watermark=0;
   bool ready=ArraySize(g_symbols)>0;
   TickShockSymbolFrontierState frontiers[];ArrayResize(frontiers,ArraySize(g_symbols));
   for(int i=0;i<ArraySize(g_symbols);++i)
      frontiers[i]=g_symbols[i].frontier;
   ready=ready && TSMergeObserveReadThroughFrontier(g_pending_repository,processing_msc,frontiers,InpMaxQuoteAgeMs,watermark);
   for(int i=0;i<ArraySize(g_symbols);++i) g_symbols[i].frontier=frontiers[i];

   int released=ready?TSMergeReleasableCount(g_pending_repository,watermark):0;
   if(released>0) TSRProcessMergedPrefix(released,processing_msc);
   if(released>0) TSMergeRemovePrefix(g_pending_repository,released);
   TSRSampleMemory();
  }

void TSRFlushPendingTicks()
  {
   long processing_msc=TSRProcessingMsc();
   for(int i=0;i<ArraySize(g_symbols);++i) TSRCollectSymbolTicks(i,g_pending_repository,processing_msc,true);
   TSMergeSortPending(g_pending_repository);
   TickShockSymbolFrontierState frontiers[];ArrayResize(frontiers,ArraySize(g_symbols));
   for(int i=0;i<ArraySize(g_symbols);++i) frontiers[i]=g_symbols[i].frontier;
   long watermark=0;bool complete=TSMergeObserveReadThroughFrontier(g_pending_repository,processing_msc,frontiers,InpMaxQuoteAgeMs,watermark);
   for(int i=0;i<ArraySize(g_symbols);++i) g_symbols[i].frontier=frontiers[i];
   int released=complete?TSMergeFinalReleasableCount(g_pending_repository,watermark):0;
   if(released>0) TSRProcessMergedPrefix(released,processing_msc);
   if(released>0) TSMergeRemovePrefix(g_pending_repository,released);
   if(ArraySize(g_pending_repository.items)>0)
     {
      g_pending_repository.incomplete_frontier=true;g_pending_repository.validation_invalid=true;
      if(g_pending_repository.fatal_reason=="") g_pending_repository.fatal_reason="FINAL_DRAIN_INCOMPLETE";
     }
  }

void TSRSummaryRow(const string record_type,const string key,const long events,const long raw,const long ticks,
                   const long valid,const long invalid,const double expectancy,const string value)
  {
   if(g_summary_file==INVALID_HANDLE) return;
   TSMt5Flush(g_event_file);TSMt5Flush(g_trade_file);
   string line="";
   TSRCsvAppend(line,InpRunId);TSRCsvAppend(line,record_type);TSRCsvAppend(line,key);TSRCsvAppend(line,TSRLong(events));TSRCsvAppend(line,TSRLong(raw));TSRCsvAppend(line,TSRLong(ticks));
   TSRCsvAppend(line,TSRLong(valid));TSRCsvAppend(line,TSRLong(invalid));TSRCsvAppend(line,valid>0?TSRDouble(expectancy,6):"");
   TSRCsvAppend(line,g_memory_samples>0?TSRDouble(g_memory_sum_mb/g_memory_samples,3):"0");TSRCsvAppend(line,TSRLong(g_memory_max_mb));
   TSRCsvAppend(line,TSRLong(g_event_rows));TSRCsvAppend(line,TSRLong(TSMt5FileSize(g_event_file)));TSRCsvAppend(line,"0");TSRCsvAppend(line,TSRLong(TSMt5FileSize(g_trade_file)));
   TSRCsvAppend(line,TSRDouble((TSMt5RuntimeTickCount()-g_started_tick_count)/1000.0,3));TSRCsvAppend(line,value);
   TSMt5WriteLine(g_summary_file,line);
  }

string TSRFrontierAffectedSymbols(const bool incomplete_only)
  {
   string result="";
   for(int i=0;i<ArraySize(g_symbols);++i)
     {
      bool affected=incomplete_only?(g_symbols[i].frontier.read_through_msc<=0 || g_symbols[i].frontier.current_read_incomplete):g_symbols[i].frontier.ever_stale;
      if(!affected) continue;
      if(result!="") result+="|";
      result+=g_symbols[i].symbol;
     }
   return result==""?"NONE":result;
  }

void TSRWriteSummary()
  {
   long all_valid=0,all_invalid=0;
   double all_sum_r=0.0;
   for(int i=0;i<TSR_ALL_SCENARIOS;++i)
     {
      all_valid+=g_scenario_valid[i];
      all_invalid+=g_scenario_invalid[i];
      all_sum_r+=g_scenario_sum_r[i];
     }
   bool validation_invalid=g_event_engine.validation_invalid || g_pending_repository.validation_invalid;
   bool formal_analysis_eligible=InpExecutionMode==REALIZABLE_EA && !validation_invalid;
   string execution_status=(InpExecutionMode==REALIZABLE_EA && g_entry_before_eligible==0 && g_entry_before_processing==0 && g_stale_detection_fills==0 && g_pending_repository.order_violations==0)?"EXECUTION_MODEL_CAUSALLY_VALIDATED_FOR_SHADOW_REPLAY":"EXECUTION_MODEL_NOT_CAUSALLY_VALIDATED";
   string cost_status=InpCommissionEvidenceStatus==TS_COMMISSION_BROKER_VERIFIED?"COST_MODEL_COMPLETE":"COST_MODEL_INCOMPLETE";
   TSRSummaryRow("OVERALL","ALL",g_total_events,g_total_raw,g_total_ticks,all_valid,all_invalid,all_valid>0?all_sum_r/all_valid:0.0,
                  "pipeline_validation="+(validation_invalid?"RESEARCH_PIPELINE_PARTIALLY_VALIDATED":"RESEARCH_PIPELINE_VALIDATED_FOR_MARCH_RESEARCH")+
                  ";execution_status="+execution_status+";cost_status="+cost_status+";formal_analysis_eligible="+TSRBool(formal_analysis_eligible)+
                  ";edge_status=EDGE_UNDETERMINED;production_eligible=false;research_only=true;execution_mode="+TSRExecutionModeName()+
                  ";market_clusters="+TSRLong(g_event_engine.market_cluster_clock.sequence)+";commission_evidence_status="+TSCommissionEvidenceStatusName(InpCommissionEvidenceStatus));
   TSRSummaryRow("FUNNEL","valid_bursts",g_valid_bursts,0,0,0,0,0.0,TSRLong(g_valid_bursts));
   TSRSummaryRow("FUNNEL","valid_pullbacks",g_valid_pullbacks,0,0,0,0,0.0,TSRLong(g_valid_pullbacks));
   TSRSummaryRow("FUNNEL","reacceleration_signals",g_reacceleration_signals,0,0,0,0,0.0,TSRLong(g_reacceleration_signals));
   TSRSummaryRow("FUNNEL","detection_time_continuation_signals",g_detection_signals,0,0,0,0,0.0,TSRLong(g_detection_signals));
   TSRSummaryRow("FUNNEL","post_burst_continuation_signals",g_post_burst_signals,0,0,0,0,0.0,TSRLong(g_post_burst_signals));
   TSRSummaryRow("FUNNEL","pullback_continuation_signals",g_pullback_signals,0,0,0,0,0.0,TSRLong(g_pullback_signals));
   TSRSummaryRow("FUNNEL","failed_shock_reversal_signals",g_reversal_signals,0,0,0,0,0.0,TSRLong(g_reversal_signals));
   string gate_names[TSR_GATE_COUNT]={"percentile","robust_z","efficiency","tick_intensity","move_spread","spread_ok"};
   for(int i=0;i<ArraySize(g_symbols);++i)
     {
      long symbol_events=0,symbol_raw=0;
      for(int d=0;d<TSR_DETECTOR_COUNT;++d) {symbol_events+=g_symbols[i].valid_events[d];symbol_raw+=g_symbols[i].raw_candidates[d];}
      TSRSummaryRow("SYMBOL",g_symbols[i].symbol,symbol_events,symbol_raw,g_symbols[i].ticks_processed,0,0,0.0,
                     StringFormat("copy_duplicates=%I64d;m1_minutes_seen=%I64d;last_quote_msc=%I64d;read_through_msc=%I64d;requested_from_msc=%I64d;requested_to_msc=%I64d;last_returned_count=%d;copy_pages=%I64d;last_copy_result=%d;last_copy_error=%d;history_synchronized=%s;stale_episodes=%I64d;max_stale_ms=%I64d;quiet_ranges=%I64d;read_failures=%I64d;cursor_stalls=%I64d;page_limits=%I64d;final_drains=%I64d;root_cause=%s",
                                  g_symbols[i].duplicate_ticks_skipped,g_symbols[i].m1_minutes_seen,g_symbols[i].frontier.last_quote_msc,g_symbols[i].frontier.read_through_msc,
                                  g_symbols[i].frontier.requested_from_msc,g_symbols[i].frontier.requested_to_msc,g_symbols[i].frontier.last_returned_count,g_symbols[i].frontier.page_count,
                                  g_symbols[i].frontier.last_copy_result,g_symbols[i].frontier.last_copy_error,TSRBool(g_symbols[i].frontier.history_synchronized),g_symbols[i].frontier.stale_episode_count,
                                  g_symbols[i].frontier.max_stale_ms,g_symbols[i].frontier.quiet_range_count,g_symbols[i].frontier.read_failure_count,g_symbols[i].frontier.cursor_stall_count,
                                  g_symbols[i].frontier.page_limit_count,g_symbols[i].frontier.final_drain_count,g_symbols[i].frontier.last_root_cause));
      for(int d=0;d<TSR_DETECTOR_COUNT;++d)
        {
         string prefix=g_symbols[i].symbol+":w"+IntegerToString(TSR_DETECTOR_MS[d]);
         double floor_rate=g_symbols[i].baseline_refreshes[d]>0?(double)g_symbols[i].scale_floor_uses[d]/g_symbols[i].baseline_refreshes[d]:0.0;
         TSRSummaryRow("DETECTOR",prefix,g_symbols[i].valid_events[d],g_symbols[i].raw_candidates[d],0,0,0,0.0,
                       StringFormat("evaluable=%I64d;grid_missing=%I64d;noise_floor_uses=%I64d;baseline_refreshes=%I64d;noise_floor_rate=%.8f;histogram_overflow=%I64d",
                                    g_symbols[i].evaluable_samples[d],g_symbols[i].grid_missing[d],g_symbols[i].scale_floor_uses[d],g_symbols[i].baseline_refreshes[d],floor_rate,g_symbols[i].histogram_overflow[d]));
         for(int g=0;g<TSR_GATE_COUNT;++g)
            TSRSummaryRow("GATE",prefix+":"+gate_names[g],0,0,0,0,0,0.0,
                          StringFormat("true=%I64d;cumulative=%I64d;evaluable=%I64d",
                                       g_symbols[i].gate_true[d*TSR_GATE_COUNT+g],g_symbols[i].gate_cumulative[d*TSR_GATE_COUNT+g],g_symbols[i].evaluable_samples[d]));
         for(int mask=0;mask<TSR_GATE_MASK_COUNT;++mask)
            if(g_symbols[i].gate_masks[d*TSR_GATE_MASK_COUNT+mask]>0)
               TSRSummaryRow("GATE_MASK",prefix+":mask="+IntegerToString(mask),0,0,0,0,0,0.0,TSRLong(g_symbols[i].gate_masks[d*TSR_GATE_MASK_COUNT+mask]));
         TSRSummaryRow("TICK_QUALITY",prefix,0,0,0,0,0,0.0,"generated_fallback_requires_tester_journal_parse;m1_minutes_seen="+TSRLong(g_symbols[i].m1_minutes_seen));
        }
      TSRSummaryRow("STATISTICAL_DETECTOR",g_symbols[i].symbol,0,0,0,0,0,0.0,
                    StringFormat("version=%s;boundaries=%I64d;tail_ready=%I64d;statistical_candidates=%I64d;persistence_rejections=%I64d;integrity_rejections=%I64d;calibration_observations=%I64d;local_ready=%I64d;histogram_overflow=%I64d;invalid_scale=%I64d",
                                 TSV1DetectorName(InpDetectorVersion),g_symbols[i].v1_boundary_count,g_symbols[i].v1_tail_ready_count,g_symbols[i].v1_statistical_candidates,
                                 g_symbols[i].v1_persistence_rejections,g_symbols[i].v1_integrity_rejections,g_symbols[i].v1_calibration.observations,
                                 g_symbols[i].v1_calibration.local_ready,g_symbols[i].v1_calibration.histogram_overflow,g_symbols[i].v1_calibration.invalid_scale));
     }
   for(int strategy=0;strategy<TSR_STRATEGY_COUNT;++strategy)
      for(int w=0;w<TSR_STOP_COUNT;++w)
         for(int d=0;d<TSR_DELAY_COUNT;++d)
            for(int p=0;p<TSR_SPREAD_COUNT;++p)
              {
               int index=TSRScenarioIndex(strategy,w,d,p);
               string key=StringFormat("%s:%s:w%s:d%d:s%d",TSRExecutionModeName(),TSRStrategyName(strategy),DoubleToString(TSRStopMultiple(w),1),TSR_DELAY_MS[d],(int)MathRound(TSR_SPREAD_MULT[p]*100.0));
               double expectancy=g_scenario_valid[index]>0?g_scenario_sum_r[index]/g_scenario_valid[index]:0.0;
               TSRSummaryRow("SCENARIO",key,0,0,0,g_scenario_valid[index],g_scenario_invalid[index],expectancy,"");
              }
    string reasons[TSR_PRE_SKIP_COUNT]={"insufficient_baseline","grid_missing","stale_quote","shock_percentile_failed","shock_z_failed","efficiency_failed","tick_intensity_failed","move_spread_failed","spread_too_wide","invalid_denominator"};
   for(int s=0;s<ArraySize(g_symbols);++s)
      for(int r=0;r<TSR_PRE_SKIP_COUNT;++r)
         TSRSummaryRow("PRE_SHOCK_SKIP",g_symbols[s].symbol+":"+reasons[r],0,0,0,0,0,0.0,TSRLong(g_pre_skip[s*TSR_PRE_SKIP_COUNT+r]));
   string status_names[8]={"TP_LIMIT","SL_GAP","TIME_MARKET","INVALID_BROKER_STOP","INVALID_BROKER_TARGET","INVALID_STALE_QUOTE","INVALID_SPREAD","OTHER_INVALID"};
   for(int i=0;i<8;++i) TSRSummaryRow("SCENARIO_STATUS",status_names[i],0,0,0,0,0,0.0,TSRLong(g_scenario_status_counts[i]));
   int ratio_count=ArraySize(g_burst_spread_ratios);
   if(ratio_count>0)
     {
      double ratios[];
      ArrayCopy(ratios,g_burst_spread_ratios);
      double min_v=ratios[0],max_v=ratios[0];
      for(int i=1;i<ratio_count;++i){min_v=MathMin(min_v,ratios[i]);max_v=MathMax(max_v,ratios[i]);}
      double p25a[],p50a[],p75a[],p95a[];ArrayCopy(p25a,ratios);ArrayCopy(p50a,ratios);ArrayCopy(p75a,ratios);ArrayCopy(p95a,ratios);
      TSRSummaryRow("DISTRIBUTION","burst_spread_ratio",0,0,0,0,0,0.0,
                    StringFormat("n=%d;min=%.6f;p25=%.6f;median=%.6f;p75=%.6f;p95=%.6f;max=%.6f",ratio_count,min_v,TSRPercentile(p25a,ratio_count,25.0),TSRPercentile(p50a,ratio_count,50.0),TSRPercentile(p75a,ratio_count,75.0),TSRPercentile(p95a,ratio_count,95.0),max_v));
     }
   TSRSummaryRow("CLUSTER","counts",g_total_events,0,0,0,0,0.0,StringFormat("event_rows=%I64d;symbol_clusters=%I64d;market_clusters=%I64d;symbol_overlap_events=%I64d;market_overlap_events=%I64d;duplicate_events=%I64d",g_event_rows,g_event_engine.symbol_cluster_sequence,g_event_engine.market_cluster_clock.sequence,g_event_engine.symbol_overlap_events,g_event_engine.market_overlap_events,g_event_engine.duplicate_events));
   TSRSummaryRow("INVARIANT","entry_before_eligible",0,0,0,0,0,0.0,TSRLong(g_entry_before_eligible));
   TSRSummaryRow("INVARIANT","entry_before_processing",0,0,0,0,0,0.0,TSRLong(g_entry_before_processing));
   TSRSummaryRow("INVARIANT","stale_detection_fill",0,0,0,0,0,0.0,TSRLong(g_stale_detection_fills));
   TSRSummaryRow("INVARIANT","reversal_signal_overwrite",0,0,0,0,0,0.0,TSRLong(g_reversal_signal_overwrites));
   TSRSummaryRow("INVARIANT","realized_rr_below_requested",0,0,0,0,0,0.0,TSRLong(g_rr_below_requested));
   TSRSummaryRow("INVARIANT","writer_scenario_recount",0,0,0,0,0,0.0,StringFormat("valid=%I64d;invalid=%I64d;sum_r=%.10f;matches=%s",g_scenario_csv_recount_valid,g_scenario_csv_recount_invalid,g_scenario_csv_recount_sum_r,TSRBool(g_scenario_csv_recount_valid==all_valid && g_scenario_csv_recount_invalid==all_invalid && MathAbs(g_scenario_csv_recount_sum_r-all_sum_r)<1e-7)));
   TSRSummaryRow("BUFFER","window_samples_per_detector_per_symbol_max",0,0,0,0,0,0.0,
                 StringFormat("w250=%d;w500=%d;w1000=%d;physical_compile_cap=%d",TSRSampleCapacity(0),TSRSampleCapacity(1),TSRSampleCapacity(2),TSR_SAMPLE_CAPACITY));
   TSRSummaryRow("BUFFER","one_second_samples_per_symbol_max",0,0,0,0,0,0.0,IntegerToString(TSRSampleCapacity(2)));
   TSRSummaryRow("BUFFER","tick_samples_per_symbol_max",0,0,0,0,0,0.0,IntegerToString(TSR_TICK_CAPACITY));
   TSRSummaryRow("BUFFER","tick_retention",0,0,0,0,0,0.0,"older_than_5000ms_or_capacity_8192");
   TSRSummaryRow("BUFFER","active_event_slots_max",0,0,0,0,0,0.0,IntegerToString(TSR_MAX_ACTIVE_EVENTS));
   TSRSummaryRow("BUFFER","global_pending_ticks",0,0,0,0,0,0.0,StringFormat("capacity=%d;max_observed=%I64d;capacity_hits=%I64d",TSR_PENDING_CAPACITY,g_pending_repository.max_observed,g_pending_repository.capacity_hits));
    TSRSummaryRow("INTEGRITY","fail_closed",0,0,0,0,0,0.0,StringFormat("validation=%s;current_state=%s;ever_failure=%s;event_pool_exhaustions=%I64d;pending_capacity_hits=%I64d;dropped_ticks=%I64d;cursor_stalls=%I64d;current_stale_symbols=%d;ever_stale_symbols=%d;stale_instances=%I64d;max_quote_stale_ms=%I64d;incomplete_frontier=%s;incomplete_frontier_instances=%I64d;read_failures=%I64d;quiet_ranges=%I64d;copy_pages=%I64d;final_drains=%I64d;root_cause=%s;affected_symbols=%s;stale_symbols=%s",
                  TSValidationStatus(validation_invalid),g_pending_repository.incomplete_frontier?"INCOMPLETE":"COMPLETE",TSRBool(validation_invalid),g_event_engine.pool_exhaustions,
                  g_pending_repository.capacity_hits,g_pending_repository.dropped_ticks,g_pending_repository.cursor_stalls,g_pending_repository.stale_symbol_count,g_pending_repository.ever_stale_symbol_count,
                  g_pending_repository.stale_instances,g_pending_repository.max_frontier_lag_ms,TSRBool(g_pending_repository.incomplete_frontier),g_pending_repository.incomplete_frontier_instances,
                  g_pending_repository.read_failures,g_pending_repository.quiet_ranges,g_pending_repository.copy_pages,g_pending_repository.final_drains,
                  g_pending_repository.fatal_reason,TSRFrontierAffectedSymbols(true),TSRFrontierAffectedSymbols(false)));
   TSRSummaryRow("BUFFER","same_millisecond_groups",0,0,0,0,0,0.0,StringFormat("groups=%I64d;ticks=%I64d;max_group=%I64d",g_pending_repository.same_msc_groups,g_pending_repository.same_msc_ticks,g_pending_repository.max_same_msc_group));
   TSRSummaryRow("LOG_POLICY","tick_or_grid_csv",0,0,0,0,0,0.0,"disabled");
   TSRSummaryRow("LOG_POLICY","detector_feature_csv",0,0,0,0,0,0.0,StringFormat("one_row_per_event;bytes=%I64d",TSMt5FileSize(g_features_file)));
   TSRSummaryRow("MODEL","shock_detector",0,0,0,0,0,0.0,"version="+TSV1DetectorName(InpDetectorVersion)+";feature_schema="+TSV1FeatureSchema()+";spec_sha256="+TSV1SpecSha256()+";default=STRICT_V0");
   TSRSummaryRow("MODEL","return_definition",0,0,0,0,0,0.0,"independent_250_500_1000ms_detectors;signal_and_baseline_use_same_absolute_mid Move;rolling half-tick histogram;exclude_2000ms;log returns diagnostic only");
   TSRSummaryRow("MODEL","execution_mode",0,0,0,0,0,0.0,TSRExecutionModeName()+";formal_expectancy="+TSRBool(InpExecutionMode==REALIZABLE_EA));
   TSRSummaryRow("MODEL","execution_clock",0,0,0,0,0,0.0,"REALIZABLE_EA entry_eligible=max(signal_event+requested_delay,signal_processing+submit_latency);entry=first_strictly_later_same_symbol_real_tick;global_watermark_latency_included");
   TSRSummaryRow("MODEL","stop_grid",0,0,0,0,0,0.0,"configured_exhaustive_grid=1.0_to_12.0_unstressed_fill_spread_in_0.5_steps;broker_feasibility_only_invalidates;policy_mask_diagnostic");
   TSRSummaryRow("MODEL","spread_stress",0,0,0,0,0,0.0,"BidAsk widened around Mid;absolute risk distance fixed from unstressed spread for paired spread scenarios");
   TSRSummaryRow("MODEL","exit_execution",0,0,0,0,0,0.0,"TP_limit_at_barrier;SL_first_tradable_side_plus_adverse_slippage;TIME_current_tradable_side");
   TSRSummaryRow("MODEL","protective_distance",0,0,0,0,0,0.0,"StopsLevel checked from current stressed Bid/Ask;FreezeLevel recorded separately as modification diagnostic;TP rounded outward so realized_rr>=requested_rr");
    TSRSummaryRow("MODEL","global_merge",0,0,0,0,0,0.0,StringFormat("semantics=min_read_through_msc;quote_freshness_separate=true;order_violations=%I64d;max_pending=%I64d;pending_at_summary=%d",g_pending_repository.order_violations,g_pending_repository.max_observed,ArraySize(g_pending_repository.items)));
    TSRSummaryRow("MODEL","provenance",0,0,0,0,0,0.0,"implementation_schema="+TSR_IMPLEMENTATION_SCHEMA+";git_commit="+InpSourceCommit+";ex5_hash="+InpEx5Hash+";schema="+InpSchemaVersion+";tester_period="+InpResearchPeriod+";tester_model="+InpTesterModel+";build_timestamp=UNAVAILABLE;build_timestamp_reason=not_injected_by_compile_script");
    TSRSummaryRow("MODEL","commission",0,0,0,0,0,0.0,StringFormat("amount_round_turn=%.8f;evidence_status=%s;source=%s;symbol_scope=%s;unit=%s;formal_net_expectancy=%s",InpCommissionPerLotRoundTurn,TSCommissionEvidenceStatusName(InpCommissionEvidenceStatus),InpCommissionSource,InpCommissionSymbolScope,InpCommissionUnit,InpCommissionEvidenceStatus==TS_COMMISSION_BROKER_VERIFIED?"AVAILABLE":"UNAVAILABLE"));
   TSMt5Flush(g_summary_file);
  }

void TSRFlushIncompleteEvents()
  {
   for(int i=0;i<TSR_MAX_ACTIVE_EVENTS;++i)
     {
      if(!g_events[i].active || g_events[i].csv_written) continue;
      if(g_events[i].state_status=="") g_events[i].state_status="INCOMPLETE_END_OF_RUN";
      else g_events[i].state_status+="|INCOMPLETE_END_OF_RUN";
      for(int j=0;j<TSR_ALL_SCENARIOS;++j)
        {
         if(!g_events[i].scenarios[j].initialized)
           {
            TSRResetScenario(g_events[i].scenarios[j]);
            g_events[i].scenarios[j].initialized=true;g_events[i].scenarios[j].done=true;g_events[i].scenarios[j].status=TS_SCENARIO_NO_SIGNAL;
           }
         else if(!g_events[i].scenarios[j].done)
           {
            g_events[i].scenarios[j].pending=false;g_events[i].scenarios[j].active=false;g_events[i].scenarios[j].done=true;g_events[i].scenarios[j].status=TS_SCENARIO_INCOMPLETE_END_OF_RUN;
           }
        }
      TSRWriteEvent(g_events[i]);
      g_events[i].active=false;
      TSReleaseEventSlot(g_event_engine,i);
     }
  }

void TSRReleaseSymbols()
  {
   for(int i=0;i<ArraySize(g_symbols);++i)
     {
      TSMt5ReleaseIndicator(g_symbols[i].ema20_m15);
      TSMt5ReleaseIndicator(g_symbols[i].ema50_m15);
      TSMt5ReleaseIndicator(g_symbols[i].ema20_h1);
      TSMt5ReleaseIndicator(g_symbols[i].ema50_h1);
     }
  }

int OnInit()
  {
   g_is_tester=TSMt5IsTester();
   TSRLoadCoreConfig(g_core_config);
   if(!TSConfigValid(g_core_config) || !TSV1DetectorValid(InpDetectorVersion))
     {PrintFormat("%s invalid configuration",TSR_NAME);return INIT_PARAMETERS_INCORRECT;}
   if(InpGridMs!=250 || InpBaselineExcludeMs<2000 ||
      InpMinBaselineSamples<=0 || InpMinBaselineSamples>TSR_SAMPLE_CAPACITY || InpRewardRisk<1.2 || InpMaxHoldSeconds<=0 || InpSubmitLatencyMs<0)
     {
      PrintFormat("%s invalid fixed-grid or feasibility inputs",TSR_NAME);
      return INIT_PARAMETERS_INCORRECT;
     }
   if(InpDetectorVersion!=STRICT_V0 && (InpBaselineMinutes!=15 || InpBaselineExcludeMs!=2000 ||
      InpMinBaselineSamples!=300 || InpMaxQuoteAgeMs!=500 || MathAbs(InpNoiseFloorTicks-1.0)>1e-12))
     {
      PrintFormat("%s statistical detector V1 requires frozen Step 15A constants",TSR_NAME);
      return INIT_PARAMETERS_INCORRECT;
     }
   for(int detector=0;detector<TSR_DETECTOR_COUNT;++detector)
      if(TSRRequiredSampleCapacity(detector)>TSR_SAMPLE_CAPACITY)
        {
         PrintFormat("%s baseline exceeds sample capacity detector=%d required=%d cap=%d",TSR_NAME,detector,TSRRequiredSampleCapacity(detector),TSR_SAMPLE_CAPACITY);
         return INIT_PARAMETERS_INCORRECT;
        }
   TSResetEventEngine(g_event_engine,TSR_MAX_ACTIVE_EVENTS);
   TSResetPendingRepository(g_pending_repository);
   if(!TSRParseSymbols()) return INIT_FAILED;
   if(!TSROpenLogs())
     {
      TSRCloseLogs();TSRReleaseSymbols();return INIT_FAILED;
     }
   TSRWriteSymbolSpecs();
   g_started_tick_count=TSMt5RuntimeTickCount();
   if(!g_is_tester && !TSMt5StartTimer(50))
     {
      PrintFormat("%s EventSetMillisecondTimer failed err=%d",TSR_NAME,GetLastError());
      TSRCloseLogs();TSRReleaseSymbols();return INIT_FAILED;
     }
   PrintFormat("%s initialized research_only symbols=%d grid_ms=%d detector=%s horizons=250,500,1000 execution_mode=%s submit_latency_ms=%d",TSR_NAME,ArraySize(g_symbols),InpGridMs,TSV1DetectorName(InpDetectorVersion),TSRExecutionModeName(),InpSubmitLatencyMs);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(!g_is_tester) TSMt5StopTimer();
   TSRFlushPendingTicks();
   TSRFlushIncompleteEvents();
   TSRWriteSummary();
   PrintFormat("%s deinitialized reason=%d events=%I64d rows=%I64d",TSR_NAME,reason,g_total_events,g_event_rows);
   TSRCloseLogs();
   TSRReleaseSymbols();
  }

void OnTick()
  {
   if(g_is_tester) TSRDispatcher();
  }

void OnTimer()
  {
   if(!g_is_tester) TSRDispatcher();
  }
