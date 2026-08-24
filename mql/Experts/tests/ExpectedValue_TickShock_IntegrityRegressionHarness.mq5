#property strict
#property version "11.00"
#include "TickShockStep5TestSupport.mqh"
input string InpDataFolder="tick_shock_step05";
input string InpOutputFolder="tick_shock_step05\\raw";
int OnInit()
  {
   g_ts5_data_folder=InpDataFolder;g_ts5_output_folder=InpOutputFolder;
   if(!TS5Init("integrity_regression")) return INIT_FAILED;
   string ids[28]={"TS-CONFIG-001","TS-CONFIG-002","TS-CONFIG-003","TS-CONFIG-004","TS-CONFIG-005","TS-CONFIG-006",
                   "TS-COMM-002","TS-COMM-003","TS-COMM-004","TS-CSV-003","TS-CSV-004","TS-CSV-005","TS-CSV-006",
                   "TS-CAP-001","TS-CAP-002","TS-CAP-003","TS-CURSOR-001","TS-STATUS-001","TS-STATUS-002","TS-DIRECTION-001",
                   "TS-ORDER-004","TS-ORDER-005","TS-ORDER-006","TS-ORDER-007","TS-ORDER-008","TS-ORDER-009","TS-WATERMARK-001","TS-WATERMARK-002"};
   for(int i=0;i<28;++i) TS5RunIntegrityRegression(ids[i]);
   TS5Close();return INIT_SUCCEEDED;
  }
void OnTick(){}
void OnDeinit(const int reason){TS5Close();}
