#property strict
#property version "5.00"
#include "TickShockStep5TestSupport.mqh"
input string InpDataFolder="tick_shock_step05";
input string InpOutputFolder="tick_shock_step05\\raw";
int OnInit(){g_ts5_data_folder=InpDataFolder;g_ts5_output_folder=InpOutputFolder;if(!TS5Init("domain_unit"))return INIT_FAILED;string ids[5]={"TS-TIME-002","TS-TIME-003","TS-TIME-004","TS-TIME-005","TS-TIME-006"};for(int i=0;i<5;++i)TS5RunClock(ids[i]);TS5RunCsvCollision();TS5Close();return INIT_SUCCEEDED;}
void OnTick(){}
void OnDeinit(const int reason){TS5Close();}
