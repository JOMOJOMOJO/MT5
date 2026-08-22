#property strict
#property version "5.00"
#include "TickShockStep5TestSupport.mqh"
input string InpDataFolder="tick_shock_step05";
input string InpOutputFolder="tick_shock_step05\\raw";
int OnInit(){g_ts5_data_folder=InpDataFolder;g_ts5_output_folder=InpOutputFolder;if(!TS5Init("multicurrency_merge"))return INIT_FAILED;string ids[7]={"TS-MERGE-001","TS-SAMEMSC-001","TS-MULTI-001","TS-MERGE-002","TS-CLUSTER-001","TS-CLUSTER-002","TS-DUP-001"};for(int i=0;i<7;++i)TS5RunMerge(ids[i]);TS5Close();return INIT_SUCCEEDED;}
void OnTick(){}
void OnDeinit(const int reason){TS5Close();}
