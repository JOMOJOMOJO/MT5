#ifndef WAVE33_LEDGER_MQH
#define WAVE33_LEDGER_MQH
#include "Types.mqh"
string W33Time(const datetime value){return value>0?TimeToString(value,TIME_DATE|TIME_SECONDS):"";}
class CWave33Ledger
  {
private:
   int m_file;
   int m_upper_file;
   int m_lower_file;
   string m_row;
   void C(string value){StringReplace(value,"\"","\"\"");if(m_row!="")m_row+=";";m_row+="\""+value+"\"";}
   void T(datetime v){C(W33Time(v));}
   void D(double v){C(DoubleToString(v,10));}
public:
   CWave33Ledger(){m_file=INVALID_HANDLE;m_upper_file=INVALID_HANDLE;m_lower_file=INVALID_HANDLE;}
   bool Open(const string tag)
     {
      m_file=FileOpen(tag+"_events.csv",FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,0,CP_UTF8);
      if(m_file==INVALID_HANDLE)return false;
      string header="event_at;event_type;reason_kind;reason;setup_id;symbol;upper_tf;lower_tf;direction;state;candidate_detected_at;upper_break_level;upper_break_confirmed_at;wave1_start_time;wave1_start_price;wave1_peak_time;wave1_peak_price;wave1_peak_known_at;fib_382_price;fib_618_price;wave2_extreme_time;wave2_extreme_price;retracement_ratio;lower_pivot_times;lower_pivot_prices;trigger_type;trigger_line_price;trigger_known_at;signal_at;order_sent_at;fill_at;entry_price;sl_price;tp_price;risk_points;intended_rr;nearest_obstacle_price;nearest_obstacle_tf;nearest_obstacle_known_at;obstacle_distance_r;h1_direction;entry_status;skip_reason;exit_at;exit_reason;realized_r;spread_points;upper_break_bar_time;upper_break_level_time;upper_break_level_known_at;wave1_start_known_at;wave1_peak_fixed;wave2_extreme_known_at;fib_touch_at;fib_touch_known_at;lower_structure_known_at;lower_entry_stage;signal_known_at;pivot_trigger_at;pivot_trigger_known_at;pivot_trigger_price;trendline_trigger_at;trendline_trigger_known_at;trendline_trigger_price;trigger_delta_points;observed_pivot_time;observed_pivot_known_at;observed_pivot_price;observed_pivot_tf;observed_pivot_label";
      header+=";actual_rr;candle_body_ratio;candle_body_atr;trigger_bar_time;wave2_start_time";
      header+=";lower_wave2_time;lower_wave2_price;first_progress_bar_time;first_progress_close_at;first_progress_known_at;first_progress_price";
      header+=";nearest_obstacle_time;nearest_obstacle_source;nearest_obstacle_is_high;wave1_room_price;wave1_room_r;wave1_room_rejected;lower_recognition;lower_unmet_reason";
      header+=";fib_close_bar_time;fib_close_at;fib_close_known_at;fib_close_price;fib_close_ratio";
      header+=";exit_deal_reason;exit_price;opposite_exit_armed;opposite_setup_id;opposite_wave_known_at;opposite_wave_peak_time;opposite_wave_price;opposite_exit_requested_at;opposite_exit_net_estimate;opposite_exit_cost_estimate";
      header+=";execution_net_cash;execution_initial_risk_money;execution_position_id;opposite_close_order_ticket";
      header+=";wave1_revision;wave1_extension_pending;wave1_extension_started_at;wave1_extension_known_at;wave1_previous_peak_time;wave1_previous_peak_known_at;wave1_previous_peak_price;wave1_extension_locked;wave1_extension_lock_bar_time;wave1_extension_lock_known_at;wave1_extension_lock_reason;wave1_provisional_time;wave1_provisional_price";
      header+=";tp_rr_price;tp_wave1_target_price;tp_wave1_buffer_points;tp_extended_to_wave1;tp_adjustment_reason";
      header+=";connected_opposite_cancelled;connected_opposite_setup_id;connected_opposite_known_at;connected_shared_time;connected_shared_price";
      FileWriteString(m_file,header+"\r\n");FileFlush(m_file);
      m_upper_file=FileOpen(tag+"_upper_bars.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,';',CP_UTF8);
      if(m_upper_file==INVALID_HANDLE){Close();return false;}
      FileWrite(m_upper_file,"symbol","tf","bar_time","closed_at","known_at","open","high","low","close");FileFlush(m_upper_file);
      m_lower_file=FileOpen(tag+"_lower_bars.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,';',CP_UTF8);
      if(m_lower_file==INVALID_HANDLE){Close();return false;}
      FileWrite(m_lower_file,"symbol","tf","bar_time","closed_at","known_at","open","high","low","close");FileFlush(m_lower_file);return true;
     }
   void WriteLowerBar(const string symbol,const ENUM_TIMEFRAMES tf,const MqlRates &bar,const datetime knownAt)
     {
      if(m_lower_file==INVALID_HANDLE)return;
      FileWrite(m_lower_file,symbol,EnumToString(tf),W33Time(bar.time),W33Time(bar.time+PeriodSeconds(tf)),W33Time(knownAt),
                DoubleToString(bar.open,10),DoubleToString(bar.high,10),DoubleToString(bar.low,10),DoubleToString(bar.close,10));
      FileFlush(m_lower_file);
     }
   void WriteUpperBar(const string symbol,const ENUM_TIMEFRAMES tf,const MqlRates &bar,const datetime knownAt)
     {
      if(m_upper_file==INVALID_HANDLE)return;
      FileWrite(m_upper_file,symbol,EnumToString(tf),W33Time(bar.time),W33Time(bar.time+PeriodSeconds(tf)),W33Time(knownAt),
                DoubleToString(bar.open,10),DoubleToString(bar.high,10),DoubleToString(bar.low,10),DoubleToString(bar.close,10));
      FileFlush(m_upper_file);
     }
   void Write(const W33Event &e)
     {
      if(m_file==INVALID_HANDLE)return;
      W33Setup s=e.setup;m_row="";
      T(e.at);C(e.event_type);C(e.reason_kind);C(e.reason);C(s.setup_id);C(s.symbol);
      C(EnumToString(s.upper_tf));C(EnumToString(s.lower_tf));C(s.direction==0?"":W33DirectionName(s.direction));C(W33StateName(s.state));
      T(s.candidate_detected_at);D(s.upper_break_level);T(s.upper_break_confirmed_at);T(s.wave1_start_time);D(s.wave1_start_price);
      T(s.wave1_peak_time);D(s.wave1_peak_price);T(s.wave1_peak_known_at);D(s.fib_382_price);D(s.fib_618_price);
      T(s.wave2_extreme_time);D(s.wave2_extreme_price);D(s.retracement_ratio);C(s.lower_pivot_times);C(s.lower_pivot_prices);
      C(s.trigger_type);D(s.trigger_line_price);T(s.trigger_known_at);T(s.signal_at);T(s.order_sent_at);T(s.fill_at);
      D(s.entry_price);D(s.sl_price);D(s.tp_price);D(s.risk_points);D(s.intended_rr);D(s.nearest_obstacle_price);
      C(EnumToString(s.nearest_obstacle_tf));T(s.nearest_obstacle_known_at);D(s.obstacle_distance_r);C(s.h1_direction);
      C(s.entry_status);C(s.skip_reason);T(s.exit_at);C(s.exit_reason);D(s.realized_r);D(s.spread_points);
      T(s.upper_break_bar_time);T(s.upper_break_level_time);T(s.upper_break_level_known_at);T(s.wave1_start_known_at);
      C(s.wave1_peak_fixed?"1":"0");T(s.wave2_extreme_known_at);T(s.fib_touch_at);T(s.fib_touch_known_at);
      T(s.lower_structure_known_at);C(s.lower_entry_stage);T(s.signal_known_at);
      T(s.pivot_trigger_at);T(s.pivot_trigger_known_at);D(s.pivot_trigger_price);
      T(s.trendline_trigger_at);T(s.trendline_trigger_known_at);D(s.trendline_trigger_price);D(s.trigger_delta_points);
      T(e.has_pivot?e.pivot.time:0);T(e.has_pivot?e.pivot.known_at:0);D(e.has_pivot?e.pivot.price:0);
      C(e.has_pivot?EnumToString(e.pivot.tf):"");C(e.has_pivot?e.pivot.label:"");
      D(s.actual_rr);D(s.candle_body_ratio);D(s.candle_body_atr);T(s.trigger_bar_time);T(s.wave2_start_time);
      T(s.lower_wave2_time);D(s.lower_wave2_price);T(s.first_progress_bar_time);T(s.first_progress_close_at);T(s.first_progress_known_at);D(s.first_progress_price);
      T(s.nearest_obstacle_time);C(s.nearest_obstacle_source);C(s.nearest_obstacle_is_high?"1":"0");D(s.wave1_room_price);D(s.wave1_room_r);C(s.wave1_room_rejected?"1":"0");C(s.lower_recognition);C(s.lower_unmet_reason);
      T(s.fib_close_bar_time);T(s.fib_close_at);T(s.fib_close_known_at);D(s.fib_close_price);D(s.fib_close_ratio);
      C(s.exit_deal_reason);D(s.exit_price);C(s.opposite_exit_armed?"1":"0");C(s.opposite_setup_id);T(s.opposite_wave_known_at);T(s.opposite_wave_peak_time);D(s.opposite_wave_price);
      T(s.opposite_exit_requested_at);D(s.opposite_exit_net_estimate);D(s.opposite_exit_cost_estimate);
      D(s.execution_net_cash);D(s.execution_initial_risk_money);C(IntegerToString((long)s.execution_position_id));C(IntegerToString((long)s.opposite_close_order_ticket));
      C(IntegerToString(s.wave1_revision));C(s.wave1_extension_pending?"1":"0");T(s.wave1_extension_started_at);T(s.wave1_extension_known_at);
      T(s.wave1_previous_peak_time);T(s.wave1_previous_peak_known_at);D(s.wave1_previous_peak_price);C(s.wave1_extension_locked?"1":"0");
      T(s.wave1_extension_lock_bar_time);T(s.wave1_extension_lock_known_at);C(s.wave1_extension_lock_reason);T(s.wave1_provisional_time);D(s.wave1_provisional_price);
      D(s.tp_rr_price);D(s.tp_wave1_target_price);D(s.tp_wave1_buffer_points);C(s.tp_extended_to_wave1?"1":"0");C(s.tp_adjustment_reason);
      C(s.connected_opposite_cancelled?"1":"0");C(s.connected_opposite_setup_id);T(s.connected_opposite_known_at);T(s.connected_shared_time);D(s.connected_shared_price);
      FileWriteString(m_file,m_row+"\r\n");FileFlush(m_file);
      if(e.event_type!="PIVOT_CONFIRMED" && e.event_type!="WAVE2_EXTREME")
         Print("W33 ",W33Time(e.at)," ",s.setup_id," ",e.event_type," ",e.reason_kind," ",e.reason);
     }
   void Close(){if(m_file!=INVALID_HANDLE){FileClose(m_file);m_file=INVALID_HANDLE;}if(m_upper_file!=INVALID_HANDLE){FileClose(m_upper_file);m_upper_file=INVALID_HANDLE;}if(m_lower_file!=INVALID_HANDLE){FileClose(m_lower_file);m_lower_file=INVALID_HANDLE;}}
  };
#endif
