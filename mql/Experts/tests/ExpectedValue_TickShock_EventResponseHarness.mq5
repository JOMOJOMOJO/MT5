#property strict
#property version "15.30"

#include "TickShockStep15CTestSupport.mqh"

input string InpDataFolder="tick_shock_step05";
input string InpOutputFolder="tick_shock_step05/raw";

int OnInit()
  {
   g_ts5_data_folder=InpDataFolder;g_ts5_output_folder=InpOutputFolder;
   if(!TS5Init("event_response")) return INIT_FAILED;
   TS15CRunAll();TS5Close();return INIT_SUCCEEDED;
  }

void OnTick(){}
void OnDeinit(const int reason){TS5Close();}
