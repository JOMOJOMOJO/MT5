#property strict
#property version "1.00"
#include "TickShockStep15FTestSupport.mqh"
input string InpDataFolder="tick_shock_step05";
input string InpOutputFolder="tick_shock_step05\\raw";
int OnInit(){g_ts5_data_folder=InpDataFolder;g_ts5_output_folder=InpOutputFolder;if(!TS5Init("context_feature"))return INIT_FAILED;TS15FRunAll();TS5Close();return INIT_SUCCEEDED;}
void OnTick(){}
void OnDeinit(const int reason){TS5Close();}
