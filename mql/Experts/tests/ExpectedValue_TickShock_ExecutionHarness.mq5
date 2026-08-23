#property strict
#property version "5.00"
#include "TickShockStep5TestSupport.mqh"
input string InpDataFolder="tick_shock_step05";
input string InpOutputFolder="tick_shock_step05\\raw";
int OnInit(){g_ts5_data_folder=InpDataFolder;g_ts5_output_folder=InpOutputFolder;if(!TS5Init("execution"))return INIT_FAILED;TS5RunScenario("TS-EXEC-LONG-001");TS5RunScenario("TS-EXEC-SHORT-001");string ids[8]={"TS-RR-001","TS-TP-001","TS-SL-001","TS-SL-002","TS-TIMEEXIT-001","TS-BROKER-001","TS-POLICY-001","TS-COMM-001"};for(int i=0;i<8;++i)TS5RunExecutionUnit(ids[i]);TS5Close();return INIT_SUCCEEDED;}
void OnTick(){}
void OnDeinit(const int reason){TS5Close();}
