#property strict
#property version "1.10"
#include "..\..\Include\TickShock\TickShockPostShockExcursion.mqh"

bool Check(const bool condition,const string name)
  {PrintFormat("TS15J %s %s",name,condition?"PASS":"FAIL");return condition;}

int OnInit()
  {
   TickShock15JPool pool;TS15JResetPool(pool);bool ok=true;
   ok=Check(TS15JArm(pool,"ep1","ev1","EURUSD",7,1,1000,1500,1400,2000,0.0010,0.10,2.0,1800,0.00001,0.00020),"arm")&&ok;
   TS15JObservePool(pool,1900,2000,1.10000,1.10010,false);
   ok=Check(!pool.records[0].entered,"pre_t0_not_entry")&&ok;
   TS15JObservePool(pool,2000,2050,1.10001,1.10011,false);
   TS15JObservePool(pool,2000,2050,1.10002,1.10012,false);
   TS15JObservePool(pool,2100,2100,1.10003,1.10013,false);
   ok=Check(pool.records[0].entered&&pool.records[0].entry_quote_msc==2000&&MathAbs(pool.records[0].entry_ask-1.10012)<1e-10,"same_msc_last_quote_entry")&&ok;
   TS15JObservePool(pool,32000,32000,1.10042,1.10052,false);
   TS15JObservePool(pool,32001,32001,1.10042,1.10052,false);
   ok=Check(pool.records[0].horizon_done[0]&&MathAbs(pool.records[0].continuation_mfe_h[0]-0.00030)<1e-10,"bid_ask_mfe_30s")&&ok;
   ok=Check(pool.records[0].horizon_target_msc[0]==32000&&pool.records[0].horizon_quote_msc[0]==32000&&pool.records[0].horizon_lag_ms[0]==0,"horizon_clock_recorded")&&ok;
   ok=Check(pool.records[0].continuation_hit_ms[1]>=0&&pool.records[0].reversal_hit_ms[1]<0,"directional_hit")&&ok;
   ok=Check(pool.records[0].existing_source==TS15G_RISK_ENTRY_SPREAD&&pool.records[0].existing_risk>0.0,"production_geometry")&&ok;
   TickShock15JPool allowed;TS15JResetPool(allowed);
   ok=Check(TS15JArm(allowed,"ep2","ev2","EURUSD",8,1,1000,1500,1400,2000,0.0010,0.10,2.0,1800,0.00001,0.00020),"lag_boundary_arm")&&ok;
   TS15JObservePool(allowed,2100,2100,1.10000,1.10010,false);TS15JObservePool(allowed,62000,62000,1.10020,1.10030,false);TS15JObservePool(allowed,62001,62001,1.10020,1.10030,false);
   ok=Check(allowed.records[0].horizon_done[0]&&!allowed.records[0].censored_horizon_lag&&allowed.records[0].horizon_lag_ms[0]==30000,"horizon_lag_equal_allowed")&&ok;
   TickShock15JPool rejected;TS15JResetPool(rejected);
   ok=Check(TS15JArm(rejected,"ep3","ev3","EURUSD",9,1,1000,1500,1400,2000,0.0010,0.10,2.0,1800,0.00001,0.00020),"lag_reject_arm")&&ok;
   TS15JObservePool(rejected,2100,2100,1.10000,1.10010,false);TS15JObservePool(rejected,62001,62001,1.10020,1.10030,false);TS15JObservePool(rejected,62002,62002,1.10020,1.10030,false);
   ok=Check(rejected.records[0].censored_horizon_lag&&rejected.records[0].censored_horizon_index==0&&!rejected.records[0].horizon_done[0]&&rejected.records[0].horizon_lag_ms[0]==30001,"horizon_lag_plus_one_censored")&&ok;
   return ok?INIT_SUCCEEDED:INIT_FAILED;
  }
void OnTick(){}
