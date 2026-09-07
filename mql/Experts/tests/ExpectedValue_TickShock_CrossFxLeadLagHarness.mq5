#property strict
#include "..\..\Include\TickShock\TickShockCrossFxLeadLag.mqh"

int g_pass=0,g_fail=0;
void Check(const bool condition,const string name){if(condition)++g_pass;else{++g_fail;Print("FAIL "+name);}}

int OnInit()
  {
   const string names[TS15O_SYMBOLS]={"EURUSD","GBPUSD","USDJPY","AUDUSD","USDCAD","USDCHF"};
   TickShock15OQuoteState states[];string symbols[];double atrs[];long atr_sources[];
   ArrayResize(states,TS15O_SYMBOLS);ArrayResize(symbols,TS15O_SYMBOLS);ArrayResize(atrs,TS15O_SYMBOLS);ArrayResize(atr_sources,TS15O_SYMBOLS);
   for(int i=0;i<TS15O_SYMBOLS;++i){TS15OResetQuoteState(states[i]);symbols[i]=names[i];atrs[i]=0.001;atr_sources[i]=15000;}
   for(int sec=0;sec<=20;++sec)
     {
      long q=(long)sec*1000+900;
      for(int i=0;i<TS15O_SYMBOLS;++i)
        {
         int orientation=TS15OUsdOrientation(symbols[i]);double slope=i==0?0.00001:0.00003;
         double raw_slope=orientation<0?slope:-slope;double mid=(i==2?110.0:1.1)+raw_slope*(double)sec;
         TS15OObserveQuote(states[i],q,q,mid-0.00001,mid+0.00001);
        }
     }
   TickShock15OSnapshot s;bool built=TS15OBuildSnapshot(states,symbols,atrs,atr_sources,0,"EP1","EV1",7,1,20900,20900,20900,500,s);
   Check(built,"snapshot built");Check(s.status==TS15O_ELIGIBLE,"eligible");Check(s.target_usd_sign==-1,"EURUSD up is USD weakness");
   Check(s.valid_cross_symbols[2]==5&&s.breadth_count[2]==5,"five-pair breadth");Check(MathAbs(s.aligned_consensus[2]-0.15)<1e-9,"aligned consensus");
   Check(MathAbs(s.aligned_residual[2]+0.10)<1e-9,"lag residual");Check(s.h1&&s.h3&&!s.h2&&!s.h4,"frozen hypotheses");Check(s.future_sources==0,"causal sources");
   TickShock15OPool pool;TS15OResetPool(pool);Check(TS15OArm(pool,s),"arm production pool");TickShock15ORecord r=pool.records[0];
   TS15OQueueQuote(r,20901,20901,1.10020,1.10022,false);TS15OQueueQuote(r,20902,20902,1.10021,1.10023,false);
   TS15OQueueQuote(r,21500,21500,1.10063,1.10065,false);TS15OQueueQuote(r,21501,21501,1.10064,1.10066,false);TS15OFlushPending(r);
   Check(r.actions[0].entry_quote_msc>=r.actions[0].entry_eligible_msc&&r.actions[0].entry_quote_msc>s.t0_quote_msc,"entry causal");
   Check(r.actions[0].result==TS15O_TP_FIRST,"continuation TP");Check(r.actions[1].result==TS15O_SL_FIRST,"reversal SL");Check(TS15OResearchOrderCalls()==0,"research order calls zero");
   PrintFormat("TS15O harness PASS=%d FAIL=%d",g_pass,g_fail);return g_fail==0?INIT_SUCCEEDED:INIT_FAILED;
  }
void OnTick(){}
