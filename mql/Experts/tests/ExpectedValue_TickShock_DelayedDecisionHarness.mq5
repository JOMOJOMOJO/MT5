#property strict
#include "..\..\Include\TickShock\TickShockDelayedDecision.mqh"

int g_pass=0,g_fail=0;
void Check(const bool ok,const string name){if(ok){++g_pass;Print("PASS ",name);}else{++g_fail;Print("FAIL ",name);}}

int OnInit()
  {
   TickShock15NPool pool;TS15NResetPool(pool);
   Check(TS15NArm(pool,"E1","V1","EURUSD",7,1,100000,99990,100000,1.10000,1.10002,0.00100,0.00001,10.0),"arm");
   TickShock15NRecord r=pool.records[0];
   TS15NQueueQuote(r,115010,115010,1.10020,1.10022,0.00100,114999,false,500,0);
   TS15NQueueQuote(r,115010,115011,1.10021,1.10023,0.00100,114999,false,500,0);
   TS15NQueueQuote(r,115011,115011,1.10022,1.10024,0.00100,114999,false,500,0);
   Check(r.checkpoint[0].decided,"decision created from grouped final quote");
   Check(MathAbs(r.checkpoint[0].decision_bid-1.10021)<1e-10,"same millisecond final quote");
   Check(!r.checkpoint[0].action[0].entered,"decision tick cannot fill");
   TS15NQueueQuote(r,115012,115012,1.10023,1.10025,0.00100,114999,false,500,0);
   Check(r.checkpoint[0].action[0].entered,"strictly later entry");
   Check(r.checkpoint[0].action[0].entry_quote_msc==115011,"first later real tick");
   Check(r.checkpoint[0].action[0].entry_quote_msc>r.checkpoint[0].feature_max_source_msc,"entry after feature source");
   TS15NQueueQuote(r,115013,115013,1.10066,1.10068,0.00100,114999,false,500,0);TS15NFlushPending(r,500,0);
   Check(r.checkpoint[0].action[0].result==TS15N_TP_FIRST,"long continuation TP");
   Check(MathAbs(r.checkpoint[0].action[0].realized_r-1.6)<1e-10,"TP R 1.6");

   TickShock15NPool latency;TS15NResetPool(latency);TS15NArm(latency,"E2","V2","GBPUSD",8,-1,200000,199990,200000,1.25000,1.25002,0.00100,0.00001,10.0);
   TickShock15NRecord z=latency.records[0];TS15NQueueQuote(z,215000,215600,1.24980,1.24982,0.00100,214999,false,500,100);TS15NQueueQuote(z,215650,215650,1.24979,1.24981,0.00100,214999,false,500,100);TS15NQueueQuote(z,215700,215700,1.24978,1.24980,0.00100,214999,false,500,100);TS15NQueueQuote(z,215701,215701,1.24977,1.24979,0.00100,214999,false,500,100);
   Check(z.checkpoint[0].action[0].entry_eligible_msc==215700,"processing plus submit latency");
   Check(z.checkpoint[0].action[0].entry_quote_msc==215700,"no entry before eligible");
   PrintFormat("TS15N harness pass=%d fail=%d",g_pass,g_fail);return g_fail==0?INIT_SUCCEEDED:INIT_FAILED;
  }
void OnTick(){}
