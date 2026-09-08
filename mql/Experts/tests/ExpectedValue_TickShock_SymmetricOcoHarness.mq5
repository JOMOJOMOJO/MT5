#property strict
#include "..\..\Include\TickShock\TickShockSymmetricOco.mqh"

int g_pass=0,g_fail=0,g_file=INVALID_HANDLE;
void Check(const bool ok,const string id,const string actual)
  {string status=ok?"PASS":"FAIL";if(ok)++g_pass;else ++g_fail;Print(status," ",id," ",actual);if(g_file!=INVALID_HANDLE)FileWrite(g_file,id,status,actual);}

TickShock15PRecord BaseRecord(const string id)
  {
   TickShock15PPool pool;TS15PResetPool(pool);
   bool armed=TS15PArm(pool,id,"V1","EURUSD",7,1,100000,99990,100000,1.00000,1.00002,0.00100,99000,5,0.00001);
   Check(armed,id+"-ARM",armed?"armed":"rejected");return pool.records[0];
  }

int OnInit()
  {
   FolderCreate("tick_shock_step15p",FILE_COMMON);g_file=FileOpen("tick_shock_step15p\\symmetric_oco_harness.csv",FILE_WRITE|FILE_CSV|FILE_COMMON,',');
   if(g_file==INVALID_HANDLE)return INIT_FAILED;FileWrite(g_file,"test_id","status","actual");

   TickShock15PRecord long_r=BaseRecord("TS15P-LONG");
   TS15PQueueQuote(long_r,100001,100001,1.00002,1.00004,false);
   TS15PQueueQuote(long_r,100002,100002,1.00004,1.00006,false);
   Check(long_r.legs[0].status==TS15P_TRIGGERED,"TS15P-TRIGGER-LONG","direction="+IntegerToString(long_r.legs[0].direction));
   TS15PQueueQuote(long_r,100003,100003,1.00009,1.00011,false);
   Check(long_r.legs[0].entry_msc==100002&&long_r.legs[0].entry_msc>long_r.legs[0].trigger_msc,"TS15P-ENTRY-AFTER-TRIGGER",StringFormat("trigger=%I64d entry=%I64d",long_r.legs[0].trigger_msc,long_r.legs[0].entry_msc));
   TS15PQueueQuote(long_r,100004,100004,1.00010,1.00012,false);TS15PFlushPending(long_r);
   Check(long_r.legs[0].scenarios[TS15PScenarioIndex(0,0)].result==TS15P_TP_FIRST,"TS15P-LONG-BID-TP",TS15PResultName(long_r.legs[0].scenarios[0].result));

   TickShock15PRecord short_r=BaseRecord("TS15P-SHORT");
   TS15PQueueQuote(short_r,100001,100001,0.99997,0.99999,false);TS15PQueueQuote(short_r,100002,100002,0.99995,0.99997,false);TS15PQueueQuote(short_r,100003,100003,0.99990,0.99992,false);TS15PQueueQuote(short_r,100004,100004,0.99989,0.99991,false);TS15PFlushPending(short_r);
   Check(short_r.legs[0].direction==-1,"TS15P-TRIGGER-SHORT","direction="+IntegerToString(short_r.legs[0].direction));
   Check(short_r.legs[0].scenarios[0].result==TS15P_TP_FIRST,"TS15P-SHORT-ASK-TP",TS15PResultName(short_r.legs[0].scenarios[0].result));

   TickShock15PRecord amb=BaseRecord("TS15P-AMB");
   TS15PQueueQuote(amb,100001,100001,1.00002,1.00004,false);TS15PQueueQuote(amb,100001,100002,0.99997,0.99999,false);TS15PQueueQuote(amb,100002,100002,1.00000,1.00002,false);
   Check(amb.legs[0].status==TS15P_AMBIGUOUS_TRIGGER&&amb.legs[0].direction==0,"TS15P-AMBIGUOUS-NO-SELECTION",TS15PEntryStatusName(amb.legs[0].status));

   TickShock15PRecord none=BaseRecord("TS15P-NONE");
   TS15PQueueQuote(none,130000,130000,1.00000,1.00002,false);TS15PQueueQuote(none,130001,130001,1.00000,1.00002,false);
   Check(none.legs[0].status==TS15P_NO_ENTRY,"TS15P-NO-ENTRY-30S",TS15PEntryStatusName(none.legs[0].status));

   TickShock15PRecord sl=BaseRecord("TS15P-SL");
   TS15PQueueQuote(sl,100001,100001,1.00002,1.00004,false);TS15PQueueQuote(sl,100002,100002,1.00004,1.00006,false);TS15PQueueQuote(sl,100003,100003,0.99994,0.99996,false);TS15PQueueQuote(sl,100004,100004,0.99990,0.99992,false);TS15PFlushPending(sl);
   TickShock15PScenario loss=sl.legs[0].scenarios[0];
   Check(loss.result==TS15P_SL_FIRST&&loss.gross_r<=-1.0,"TS15P-SL-GAP",StringFormat("result=%s r=%.6f",TS15PResultName(loss.result),loss.gross_r));

   TickShock15PRecord timed=BaseRecord("TS15P-TIME");
   TS15PQueueQuote(timed,100001,100001,1.00002,1.00004,false);TS15PQueueQuote(timed,100002,100002,1.00004,1.00006,false);TS15PQueueQuote(timed,100003,100003,1.00004,1.00006,false);TS15PQueueQuote(timed,400002,400002,1.00004,1.00006,false);TS15PQueueQuote(timed,400003,400003,1.00004,1.00006,false);
   Check(timed.legs[0].scenarios[0].result==TS15P_TIMEOUT,"TS15P-TIME-300S",TS15PResultName(timed.legs[0].scenarios[0].result));

   Check(TS15PPipSize(5,0.00001)==0.0001&&TS15PPipSize(3,0.001)==0.01,"TS15P-PIP-SIZE","5-digit and 3-digit");
   FileWrite(g_file,"TOTAL",g_fail==0?"PASS":"FAIL",StringFormat("PASS=%d;FAIL=%d",g_pass,g_fail));FileClose(g_file);g_file=INVALID_HANDLE;
   PrintFormat("TS15P harness pass=%d fail=%d",g_pass,g_fail);return g_fail==0?INIT_SUCCEEDED:INIT_FAILED;
  }
void OnTick(){}
void OnDeinit(const int reason){if(g_file!=INVALID_HANDLE)FileClose(g_file);}
