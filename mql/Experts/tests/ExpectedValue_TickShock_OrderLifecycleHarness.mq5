#property strict
#property version "5.00"
#include "TickShockStep5TestSupport.mqh"
input string InpDataFolder="tick_shock_step05";
input string InpOutputFolder="tick_shock_step05\\raw";
int OnInit(){g_ts5_data_folder=InpDataFolder;g_ts5_output_folder=InpOutputFolder;if(!TS5Init("order_lifecycle"))return INIT_FAILED;string ids[13]={"TS-ORDER-001","TS-ORDER-002","TS-PARTIAL-001","TS-ORDER-003","TS-SERVER-SL-LONG-001","TS-SERVER-SL-SHORT-001","TS-SERVER-TP-LONG-001","TS-SERVER-TP-SHORT-001","TS-TIME-CLOSE-LONG-001","TS-TIME-CLOSE-SHORT-001","TS-POSITION-001","TS-RESTART-001","TS-RESTART-002"};for(int i=0;i<13;++i){if(i<4){TS5RunOrderLifecycle(ids[i]);continue;}string reason="ORDER_LIFECYCLE_NOT_OBSERVED";if(StringFind(ids[i],"SERVER-")>=0)reason="SERVER_DEAL_NOT_OBSERVED";if(StringFind(ids[i],"RESTART-")>=0)reason="PROCESS_RESTART_NOT_OBSERVED";TS5RunUnsupported(ids[i],reason);}TS5Close();return INIT_SUCCEEDED;}
void OnTick(){}
void OnDeinit(const int reason){TS5Close();}
