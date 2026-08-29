#property strict
#property version "1.00"
#include "TickShockStep5TestSupport.mqh"
#include "TickShockStep15ETestSupport.mqh"
input string InpDataFolder="tick_shock_step05";
input string InpOutputFolder="tick_shock_step05\\raw";
int OnInit(){g_ts5_data_folder=InpDataFolder;g_ts5_output_folder=InpOutputFolder;if(!TS5Init("medium_horizon_response"))return INIT_FAILED;TS15ERunAll();TS5Close();return INIT_SUCCEEDED;}
void OnTick(){}
void OnDeinit(const int reason){TS5Close();}

