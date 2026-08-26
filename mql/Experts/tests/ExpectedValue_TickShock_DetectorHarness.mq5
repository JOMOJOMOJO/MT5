#property strict
#property version "5.00"
#include "TickShockStep5TestSupport.mqh"
#include "TickShockStep15ATestSupport.mqh"
input string InpDataFolder="tick_shock_step05";
input string InpOutputFolder="tick_shock_step05\\raw";
int OnInit(){g_ts5_data_folder=InpDataFolder;g_ts5_output_folder=InpOutputFolder;if(!TS5Init("detector"))return INIT_FAILED;TS5RunReturn("TS-RET-001");TS5RunReturn("TS-RET-002");string gates[4]={"TS-INT-001","TS-MOVE-001","TS-SPREAD-001","TS-GATE-001"};for(int i=0;i<4;++i)TS5RunGateCase(gates[i]);string extracted[7]={"TS-PCT-001","TS-Z-001","TS-Z-002","TS-EFF-001","TS-EFF-002","TS-BASE-001","TS-BASE-002"};for(int i=0;i<7;++i)TS5RunBaselineAndMetric(extracted[i]);TS15ARunAll();TS5Close();return INIT_SUCCEEDED;}
void OnTick(){}
void OnDeinit(const int reason){TS5Close();}
