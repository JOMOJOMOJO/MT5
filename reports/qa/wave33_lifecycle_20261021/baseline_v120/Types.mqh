#ifndef WAVE33_VISUAL_TYPES_MQH
#define WAVE33_VISUAL_TYPES_MQH

// These are observation states, not profitability or promotion gates.
enum W33State
  {
   SEARCH_STRUCTURE=0,
   WAVE1_BREAK_CANDIDATE,
   WAVE1_TOP_TRACKING,
   WAVE2_RETRACEMENT,
   LOWER_COUNTERTREND,
   LOWER_REVERSAL_TRIGGER,
   RESISTANCE_AND_RISK_CHECK,
   POSITION_TRACKING
  };

enum W33TriggerMode
  {
   W33_PIVOT_BREAK=0,
   W33_TRENDLINE_BREAK=1,
   W33_FIRST_BREAK=2
  };

struct W33Pivot
  {
   datetime time;                 // Location of the swing candle.
   datetime known_at;             // First time all right-hand bars were closed.
   double price;
   ENUM_TIMEFRAMES tf;
   bool is_high;
   string label;
  };

struct W33Setup
  {
   string setup_id;
   string symbol;
   ENUM_TIMEFRAMES upper_tf;
   ENUM_TIMEFRAMES lower_tf;
   int direction;                 // +1 LONG, -1 SHORT.
   W33State state;
   bool active;
   datetime candidate_detected_at;
   double upper_break_level;
   datetime upper_break_confirmed_at;
   datetime upper_break_bar_time;
   datetime upper_break_level_time;
   datetime upper_break_level_known_at;
   datetime wave1_start_time;
   double wave1_start_price;
   datetime wave1_start_known_at;
   datetime wave1_peak_time;
   double wave1_peak_price;
   datetime wave1_peak_known_at;
   bool wave1_peak_fixed;
   datetime wave1_provisional_time;
   double wave1_provisional_price;
   double fib_382_price;
   double fib_618_price;
   datetime fib_touch_at;
   datetime fib_touch_known_at;
   datetime wave2_start_time;
   datetime wave2_extreme_time;
   double wave2_extreme_price;
   datetime wave2_extreme_known_at;
   double retracement_ratio;
   string lower_pivot_times;
   string lower_pivot_prices;
   datetime lower_structure_known_at;
   string lower_entry_stage;       // COUNTERTREND_NEGATION; no invented lower wave-3.
   datetime lower_high1_time;
   datetime lower_high2_time;
   double lower_high1_price;
   double lower_high2_price;
   datetime lower_low1_time;
   datetime lower_low2_time;
   double lower_low1_price;
   double lower_low2_price;
   string trigger_type;
   double trigger_line_price;
   datetime trigger_known_at;
   datetime signal_at;
   datetime signal_known_at;
   datetime trigger_bar_time;
   datetime pivot_trigger_at;
   datetime pivot_trigger_known_at;
   double pivot_trigger_price;
   datetime trendline_trigger_at;
   datetime trendline_trigger_known_at;
   double trendline_trigger_price;
   double trigger_delta_points;
   datetime order_sent_at;
   datetime fill_at;
   double entry_price;
   double sl_price;
   double tp_price;
   double risk_points;
   double intended_rr;
   double actual_rr;
   double candle_body_ratio;
   double candle_body_atr;
   double nearest_obstacle_price;
   ENUM_TIMEFRAMES nearest_obstacle_tf;
   datetime nearest_obstacle_time;
   datetime nearest_obstacle_known_at;
   double obstacle_distance_r;
   string h1_direction;
   string entry_status;
   string skip_reason;
   datetime exit_at;
   string exit_reason;
   double realized_r;
   double spread_points;
   bool fib_touched;
   bool fib_too_deep_measured;
   bool lower_structure_confirmed;
   bool signal_emitted;
   bool position_open;
   int upper_bars_elapsed;
   datetime last_updated_at;
  };

struct W33Event
  {
   datetime at;                   // Decision/observation availability time.
   string event_type;
   string reason_kind;            // OBSERVATION, MEASUREMENT or EXCLUSION.
   string reason;
   bool has_pivot;
   W33Pivot pivot;
   W33Setup setup;
  };

string W33StateName(const W33State state)
  {
   switch(state)
     {
      case SEARCH_STRUCTURE: return "SEARCH_STRUCTURE";
      case WAVE1_BREAK_CANDIDATE: return "WAVE1_BREAK_CANDIDATE";
      case WAVE1_TOP_TRACKING: return "WAVE1_TOP_TRACKING";
      case WAVE2_RETRACEMENT: return "WAVE2_RETRACEMENT";
      case LOWER_COUNTERTREND: return "LOWER_COUNTERTREND";
      case LOWER_REVERSAL_TRIGGER: return "LOWER_REVERSAL_TRIGGER";
      case RESISTANCE_AND_RISK_CHECK: return "RESISTANCE_AND_RISK_CHECK";
      case POSITION_TRACKING: return "POSITION_TRACKING";
     }
   return "UNKNOWN";
  }

string W33DirectionName(const int direction)
  {
   return direction>0 ? "LONG" : "SHORT";
  }

#endif
