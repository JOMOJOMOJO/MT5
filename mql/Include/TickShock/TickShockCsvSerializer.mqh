#ifndef TICK_SHOCK_CSV_SERIALIZER_MQH
#define TICK_SHOCK_CSV_SERIALIZER_MQH

#include "TickShockTypes.mqh"

string TSScenarioStatusName(const ENUM_TS_SCENARIO_STATUS status)
  {
   if(status==TS_SCENARIO_PENDING_ENTRY_QUOTE) return "PENDING_ENTRY_QUOTE";
   if(status==TS_SCENARIO_ACTIVE) return "ACTIVE";
   if(status==TS_SCENARIO_TP_LIMIT) return "TP_LIMIT";
   if(status==TS_SCENARIO_SL_GAP) return "SL_GAP";
   if(status==TS_SCENARIO_TIME_MARKET) return "TIME_MARKET";
   if(status==TS_SCENARIO_INVALID_STALE_QUOTE) return "INVALID_STALE_QUOTE";
   if(status==TS_SCENARIO_INVALID_SPREAD) return "INVALID_SPREAD";
   if(status==TS_SCENARIO_INVALID_BROKER_STOP) return "INVALID_BROKER_STOP";
   if(status==TS_SCENARIO_INVALID_BROKER_TARGET) return "INVALID_BROKER_TARGET";
   if(status==TS_SCENARIO_INVALID_PRICE) return "INVALID_PRICE";
   if(status==TS_SCENARIO_INVALID_RISK_DISTANCE) return "INVALID_RISK_DISTANCE";
   if(status==TS_SCENARIO_NO_SIGNAL) return "NO_SIGNAL";
   if(status==TS_SCENARIO_INCOMPLETE_END_OF_RUN) return "INCOMPLETE_END_OF_RUN";
   return "NOT_SIGNALED";
  }

ENUM_TS_SCENARIO_STATUS TSScenarioStatusFromExitReason(const string reason)
  {
   if(reason=="TP_LIMIT") return TS_SCENARIO_TP_LIMIT;
   if(reason=="SL_GAP") return TS_SCENARIO_SL_GAP;
   if(reason=="TIME_MARKET") return TS_SCENARIO_TIME_MARKET;
   return TS_SCENARIO_NOT_SIGNALED;
  }

bool TSScenarioStatusIsInvalid(const ENUM_TS_SCENARIO_STATUS status)
  {
   return status==TS_SCENARIO_INVALID_STALE_QUOTE ||
          status==TS_SCENARIO_INVALID_SPREAD ||
          status==TS_SCENARIO_INVALID_BROKER_STOP ||
          status==TS_SCENARIO_INVALID_BROKER_TARGET ||
          status==TS_SCENARIO_INVALID_PRICE ||
          status==TS_SCENARIO_INVALID_RISK_DISTANCE;
  }

string TSDetectorRejectName(const ENUM_TS_DETECTOR_REJECT reject)
  {
   if(reject==TS_DETECTOR_REJECT_PERCENTILE) return "shock_percentile_failed";
   if(reject==TS_DETECTOR_REJECT_ROBUST_Z) return "shock_z_failed";
   if(reject==TS_DETECTOR_REJECT_EFFICIENCY) return "efficiency_failed";
   if(reject==TS_DETECTOR_REJECT_INTENSITY) return "tick_intensity_failed";
   if(reject==TS_DETECTOR_REJECT_MOVE_SPREAD) return "move_spread_failed";
   if(reject==TS_DETECTOR_REJECT_SPREAD) return "spread_too_wide";
   return "";
  }

string TSBoolName(const bool value)
  {
   return value?"true":"false";
  }

string TSDirectionName(const int direction)
  {
   return direction>0?"LONG":"SHORT";
  }

void TSCsvAppendEscaped(string &line,string value)
  {
   StringReplace(value,"\"","\"\"");
   if(line!="") line+=",";
   line+="\""+value+"\"";
  }

#endif
