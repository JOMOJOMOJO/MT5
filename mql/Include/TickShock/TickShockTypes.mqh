#ifndef TICK_SHOCK_TYPES_MQH
#define TICK_SHOCK_TYPES_MQH

#define TS_CORE_GATE_COUNT 6

enum ENUM_TS_STATE
  {
   TS_SCANNING = 0,
   TS_BURST_ACTIVE,
   TS_WAIT_PULLBACK,
   TS_WAIT_REACCELERATION,
   TS_POSITION_OPEN,
   TS_EXPIRED,
   TS_COOLDOWN
  };

enum ENUM_TS_ACTION
  {
   TS_ACTION_NONE = 0,
   TS_ACTION_BURST_FROZEN,
   TS_ACTION_PULLBACK_VALID,
   TS_ACTION_REACCELERATION,
   TS_ACTION_CONTINUATION_INVALIDATED,
   TS_ACTION_PULLBACK_TIMEOUT,
   TS_ACTION_NO_REACCELERATION
  };

enum ENUM_TS_RESEARCH_EXECUTION_MODE
  {
   IDEAL_EVENT_STUDY = 0,
   REALIZABLE_EA = 1
  };

enum ENUM_TS_DETECTOR_REJECT
  {
   TS_DETECTOR_ACCEPT = 0,
   TS_DETECTOR_REJECT_PERCENTILE,
   TS_DETECTOR_REJECT_ROBUST_Z,
   TS_DETECTOR_REJECT_EFFICIENCY,
   TS_DETECTOR_REJECT_INTENSITY,
   TS_DETECTOR_REJECT_MOVE_SPREAD,
   TS_DETECTOR_REJECT_SPREAD
  };

enum ENUM_TS_SCENARIO_STATUS
  {
   TS_SCENARIO_NOT_SIGNALED = 0,
   TS_SCENARIO_PENDING_ENTRY_QUOTE,
   TS_SCENARIO_ACTIVE,
   TS_SCENARIO_TP_LIMIT,
   TS_SCENARIO_SL_GAP,
   TS_SCENARIO_TIME_MARKET,
   TS_SCENARIO_INVALID_STALE_QUOTE,
   TS_SCENARIO_INVALID_SPREAD,
   TS_SCENARIO_INVALID_BROKER_STOP,
   TS_SCENARIO_INVALID_BROKER_TARGET,
   TS_SCENARIO_INVALID_PRICE,
   TS_SCENARIO_INVALID_RISK_DISTANCE,
   TS_SCENARIO_NO_SIGNAL,
   TS_SCENARIO_INCOMPLETE_END_OF_RUN
  };

enum ENUM_TS_ORDER_ENTRY_STATE
  {
   TS_ORDER_ENTRY_PENDING = 0,
   TS_ORDER_WAIT_EXIT,
   TS_ORDER_ENTRY_CANCELLED
  };

enum ENUM_TS_CSV_OPEN_STATUS
  {
   TS_CSV_OPEN_CREATED = 0,
   TS_CSV_OPEN_RESUMED,
   TS_CSV_OPEN_RUN_ID_COLLISION,
   TS_CSV_OPEN_IO_ERROR
  };

struct TickShockMachine
  {
   ENUM_TS_STATE state;
   int direction;
   long detection_msc;
   long burst_end_msc;
   long last_extreme_msc;
   long pullback_msc;
   long cooldown_until_msc;
   double burst_start;
   double burst_extreme;
   double burst_range;
   double pullback_extreme;
   double max_retracement_pct;
   double last_mid;
   int reacceleration_ticks;
   bool too_deep_seen;
  };

struct TSResearchSignalClock
  {
   bool registered;
   int direction;
   long event_msc;
   long processing_msc;
  };

struct TSResearchEntryClock
  {
   bool filled;
   long eligible_msc;
   long quote_msc;
  };

struct TSResearchClusterClock
  {
   long sequence;
   long current_id;
   long start_msc;
   long last_msc;
  };

struct TickShockQuote
  {
   string symbol;
   int symbol_index;
   int sequence;
   long time_msc;
   long processing_msc;
   double bid;
   double ask;
   double mid;
   bool real_tick;
  };

struct TickShockDetectorResult
  {
   bool gates[TS_CORE_GATE_COUNT];
   int gate_mask;
   ENUM_TS_DETECTOR_REJECT reject;
   bool accepted;
  };

struct TickShockStateResult
  {
   ENUM_TS_ACTION action;
   ENUM_TS_STATE state;
   long action_msc;
   double burst_range;
   double retracement_pct;
  };

struct TickShockExecutionResult
  {
   ENUM_TS_SCENARIO_STATUS status;
   bool pending;
   bool active;
   bool done;
   TSResearchEntryClock entry_clock;
   double base_spread;
   double stressed_spread;
   double stressed_bid;
   double stressed_ask;
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
   int policy_mask;
  };

struct TickShockClusterAssignment
  {
   long cluster_id;
   bool overlap;
  };

struct TickShockOrderFillState
  {
   ENUM_TS_ORDER_ENTRY_STATE state;
   double requested_volume;
   double filled_volume;
   double remaining_volume;
   double cancelled_volume;
   double weighted_fill_value;
   double average_fill;
   int deal_count;
   bool entry_resolved;
  };

#endif
