#property strict
#property version "5.00"
#include "TickShockStep5TestSupport.mqh"
input string InpDataFolder="tick_shock_step05";
input string InpOutputFolder="tick_shock_step05\\raw";
int OnInit(){g_ts5_data_folder=InpDataFolder;g_ts5_output_folder=InpOutputFolder;if(!TS5Init("synthetic_integration"))return INIT_FAILED;TS5RunClock("TS-TIME-001");TS5RunDetectionClock();TS5RunReversalClock();TS5Close();return INIT_SUCCEEDED;}
void OnTick(){}
void OnDeinit(const int reason){TS5Close();}
