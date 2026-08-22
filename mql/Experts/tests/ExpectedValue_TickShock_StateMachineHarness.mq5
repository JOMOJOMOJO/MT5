#property strict
#property version "5.00"
#include "TickShockStep5TestSupport.mqh"
input string InpDataFolder="tick_shock_step05";
input string InpOutputFolder="tick_shock_step05\\raw";
int OnInit(){g_ts5_data_folder=InpDataFolder;g_ts5_output_folder=InpOutputFolder;if(!TS5Init("state_machine"))return INIT_FAILED;TS5RunStatePath("TS-STATE-LONG-001");TS5RunStatePath("TS-STATE-SHORT-001");string ids[8]={"TS-BURST-001","TS-BURST-002","TS-PB-001","TS-PB-002","TS-PB-003","TS-INVALID-001","TS-TIMEOUT-001","TS-NOREACCEL-001"};for(int i=0;i<8;++i)TS5RunStateUnit(ids[i]);TS5Close();return INIT_SUCCEEDED;}
void OnTick(){}
void OnDeinit(const int reason){TS5Close();}
