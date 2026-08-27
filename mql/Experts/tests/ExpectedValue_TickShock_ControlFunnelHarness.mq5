#property strict
#property version "15.20"

#include "TickShockStep15BTestSupport.mqh"

input string InpDataFolder="tick_shock_step05";
input string InpOutputFolder="tick_shock_step05/raw";

int OnInit()
  {
   g_ts5_data_folder=InpDataFolder;
   g_ts5_output_folder=InpOutputFolder;
   if(!TS5Init("control_funnel")) return INIT_FAILED;
   TS15BRunAll();
   TS5Close();
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
  }

void OnDeinit(const int reason)
  {
   TS5Close();
  }
