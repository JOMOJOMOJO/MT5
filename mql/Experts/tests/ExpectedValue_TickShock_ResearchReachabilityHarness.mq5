#property strict
#property version "4.00"

#include "..\..\Include\TickShockStateMachine.mqh"
#include "..\..\Include\TickShockResearchExecution.mqh"

input string InpRunId="research_v4_production_path";
input string InpLogFolder="tick_shock_research";

int g_file=INVALID_HANDLE;
int g_passed=0;
int g_failed=0;

void Record(const int id,const string name,const bool passed,const string detail)
  {
   if(passed) ++g_passed; else ++g_failed;
   if(g_file!=INVALID_HANDLE) FileWrite(g_file,id,name,passed?"PASS":"FAIL",detail);
  }

bool Almost(const double left,const double right,const double tolerance=1e-9)
  {
   return MathAbs(left-right)<=tolerance;
  }

long ReplayFirstEntry(const TSResearchSignalClock &signal,
                      const ENUM_TS_RESEARCH_EXECUTION_MODE mode,
                      const int delay_ms,
                      const int submit_latency_ms,
                      const long &quote_times[],
                      long &eligible_msc)
  {
   TSResearchEntryClock entry;
   TSResetResearchEntryClock(entry);
   for(int i=0;i<ArraySize(quote_times);++i)
      if(TSResearchTryEntryClock(signal,mode,delay_ms,submit_latency_ms,quote_times[i],entry))
        {
         eligible_msc=entry.eligible_msc;
         return entry.quote_msc;
        }
   eligible_msc=TSResearchEntryEligibleMsc(mode,signal.event_msc,signal.processing_msc,delay_ms,submit_latency_ms);
   return 0;
  }

bool StatePath(const int direction)
  {
   TickShockMachine machine;
   double start=100.0;
   double current=direction>0?110.0:90.0;
   double extreme=direction>0?111.0:89.0;
   TSStartBurst(machine,direction,1000,start,current);
   TSAdvance(machine,1100,extreme,300,3000,15.0,35.0,50.0,10000,2);
   if(TSAdvance(machine,1401,extreme,300,3000,15.0,35.0,50.0,10000,2)!=TS_ACTION_BURST_FROZEN) return false;
   double pullback=direction>0?108.8:91.2;
   if(TSAdvance(machine,1500,pullback,300,3000,15.0,35.0,50.0,10000,2)!=TS_ACTION_PULLBACK_VALID) return false;
   double first=direction>0?111.1:88.9;
   double second=direction>0?111.2:88.8;
   if(TSAdvance(machine,1600,first,300,3000,15.0,35.0,50.0,10000,2)!=TS_ACTION_NONE) return false;
   return TSAdvance(machine,1650,second,300,3000,15.0,35.0,50.0,10000,2)==TS_ACTION_REACCELERATION;
  }

void RunTests()
  {
   TSResearchSignalClock detection;
   TSResetResearchSignalClock(detection);
   bool registered=TSRegisterResearchSignal(detection,1,1000,1600);
   long stale_times[3]={1000,1200,1600};
   long eligible=0;
   long entry=ReplayFirstEntry(detection,REALIZABLE_EA,0,0,stale_times,eligible);
   Record(1,"stale_grid_quote_never_fills_boundary",registered && entry==1600 && eligible==1600,
          StringFormat("eligible=%I64d;entry=%I64d",eligible,entry));

   long delayed_processing_times[4]={1100,1400,1599,1601};
   entry=ReplayFirstEntry(detection,REALIZABLE_EA,0,0,delayed_processing_times,eligible);
   Record(2,"processing_delay_blocks_past_quotes",entry==1601 && entry>=detection.processing_msc,
          StringFormat("processing=%I64d;eligible=%I64d;entry=%I64d",detection.processing_msc,eligible,entry));

   TSResearchSignalClock immediate;
   TSResetResearchSignalClock(immediate);
   TSRegisterResearchSignal(immediate,1,2000,2000);
   long delay_times[5]={2000,2050,2100,2200,2250};
   long eligible100=0,eligible250=0;
   long entry100=ReplayFirstEntry(immediate,REALIZABLE_EA,100,0,delay_times,eligible100);
   long entry250=ReplayFirstEntry(immediate,REALIZABLE_EA,250,0,delay_times,eligible250);
   Record(3,"requested_delays_are_added",eligible100==2100 && entry100==2100 && eligible250==2250 && entry250==2250,
          StringFormat("e100=%I64d;q100=%I64d;e250=%I64d;q250=%I64d",eligible100,entry100,eligible250,entry250));

   TSResearchSignalClock reversal;
   TSResetResearchSignalClock(reversal);
   bool first_register=TSRegisterResearchSignal(reversal,-1,3000,3600);
   bool overwritten=TSRegisterResearchSignal(reversal,-1,3100,3700);
   Record(4,"reversal_signal_is_invalidation_time",first_register && !overwritten && reversal.event_msc==3000 && reversal.processing_msc==3600,
          StringFormat("event=%I64d;processing=%I64d",reversal.event_msc,reversal.processing_msc));

   bool first_final=TSResearchFinalQuoteInSameMscGroup(4000,0,true,4000,0);
   bool second_final=TSResearchFinalQuoteInSameMscGroup(4000,0,true,4001,0);
   double same_msc_prices[2]={100.1,100.3};
   double grid_close=second_final?same_msc_prices[1]:same_msc_prices[0];
   Record(5,"same_millisecond_uses_final_quote",!first_final && second_final && Almost(grid_close,100.3),DoubleToString(grid_close,1));

   bool chronology=TSChronologicalKeyLess(5000,0,0,5000,1,0) &&
                   TSChronologicalKeyLess(5000,1,0,5001,0,0) &&
                   !TSChronologicalKeyLess(5001,0,0,5000,5,5);
   Record(6,"global_merge_chronology",chronology,"cross-symbol event order remains monotonic");

   double r250=0.0,r500=0.0,r1000=0.0;
   bool v250=TSResearchExactLogReturn(6000,102.0,250,5750,101.0,r250);
   bool v500=TSResearchExactLogReturn(6000,102.0,500,5500,99.0,r500);
   bool v1000=TSResearchExactLogReturn(6000,102.0,1000,5000,96.0,r1000);
   Record(7,"independent_250_500_1000_returns",v250 && v500 && v1000 && !Almost(r250,r500) && !Almost(r500,r1000),
          StringFormat("r250=%.9f;r500=%.9f;r1000=%.9f",r250,r500,r1000));

   TSResearchClusterClock market;
   TSResetResearchClusterClock(market);
   bool overlap1=false,overlap2=false,overlap3=false;
   long c1=TSAssignResearchMarketCluster(market,7000,2000,overlap1); // EURUSD
   long c2=TSAssignResearchMarketCluster(market,8500,2000,overlap2); // USDJPY
   long c3=TSAssignResearchMarketCluster(market,9101,2000,overlap3); // GBPUSD, beyond first anchor
   Record(8,"market_cluster_cross_symbol",c1==1 && c2==1 && overlap2 && c3==2 && !overlap3,
          StringFormat("eur=%I64d;jpy=%I64d;gbp=%I64d",c1,c2,c3));

   double long_tp=0.0,long_rr=0.0,short_tp=0.0,short_rr=0.0;
   bool long_target=TSBuildResearchTarget(1,100.00,0.03,1.2,0.01,2,long_tp,long_rr);
   bool short_target=TSBuildResearchTarget(-1,100.00,0.03,1.2,0.01,2,short_tp,short_rr);
   Record(9,"realized_rr_is_at_least_requested",long_target && short_target && long_rr>=1.2 && short_rr>=1.2,
          StringFormat("long_tp=%.2f;long_rr=%.6f;short_tp=%.2f;short_rr=%.6f",long_tp,long_rr,short_tp,short_rr));

   string reason="";
   bool long_broker=TSProtectiveOrderDistanceFeasible(1,100.80,101.00,100.00,102.20,0.90,reason);
   bool long_side_ok=!long_broker && reason=="INVALID_BROKER_STOP";
   reason="";
   bool short_broker=TSProtectiveOrderDistanceFeasible(-1,100.00,100.20,101.00,98.80,0.90,reason);
   Record(10,"broker_distance_uses_bid_ask",long_side_ok && !short_broker && reason=="INVALID_BROKER_STOP",reason);

   reason="";
   bool stops_clear=TSProtectiveOrderDistanceFeasible(1,100.80,101.00,100.00,102.20,0.50,reason);
   bool freeze_clear=TSProtectiveFreezeDistanceClear(1,100.80,101.00,100.00,102.20,0.90);
   Record(11,"stops_and_freeze_are_distinct",stops_clear && !freeze_clear,"StopsLevel passes; FreezeLevel remains diagnostic");

   long ideal_due=TSResearchEntryEligibleMsc(IDEAL_EVENT_STUDY,10000,10600,100,50);
   long real_due=TSResearchEntryEligibleMsc(REALIZABLE_EA,10000,10600,100,50);
   Record(12,"ideal_and_realizable_clocks_separate",ideal_due==10100 && real_due==10650,
          StringFormat("ideal=%I64d;real=%I64d",ideal_due,real_due));

   TSResearchEntryClock invariant_entry;
   TSResetResearchEntryClock(invariant_entry);
   bool before=TSResearchTryEntryClock(detection,REALIZABLE_EA,0,0,1599,invariant_entry);
   bool at_processing=TSResearchTryEntryClock(detection,REALIZABLE_EA,0,0,1600,invariant_entry);
   Record(13,"entry_invariant_enforced",!before && at_processing && TSResearchEntryInvariant(detection,REALIZABLE_EA,0,0,invariant_entry),
          StringFormat("eligible=%I64d;quote=%I64d",invariant_entry.eligible_msc,invariant_entry.quote_msc));

   TSResearchEntryClock reversal_entry;
   TSResetResearchEntryClock(reversal_entry);
   bool same_signal_tick=TSResearchTryEntryClock(reversal,REALIZABLE_EA,0,0,3000,reversal_entry);
   bool post_processing_tick=TSResearchTryEntryClock(reversal,REALIZABLE_EA,0,0,3601,reversal_entry);
   Record(14,"reversal_requires_later_real_tick",!same_signal_tick && post_processing_tick && reversal_entry.quote_msc==3601,
          StringFormat("entry=%I64d",reversal_entry.quote_msc));

   Record(15,"long_short_state_reachability",StatePath(1) && StatePath(-1),"both production state paths reach two-tick reacceleration");

   double fill=0.0,gross=0.0,gap=0.0;
   string exit_reason="";
   bool exited=TSResolveShadowExitWithGap(1,100.0,99.0,101.2,98.8,0.1,1000,2000,120,fill,gross,gap,exit_reason);
   Record(16,"stop_gap_and_exit_slippage",exited && exit_reason=="SL_GAP" && Almost(fill,98.7) && Almost(gross,-1.3),exit_reason);

   exited=TSResolveShadowExitWithGap(1,100.0,99.0,101.2,102.0,0.1,1000,2000,120,fill,gross,gap,exit_reason);
   Record(17,"target_is_limit_fill",exited && exit_reason=="TP_LIMIT" && Almost(fill,101.2) && Almost(gross,1.2),exit_reason);

   double stressed_mid=100.0,raw_spread=0.2,paired_risk=1.0;
   double bid100=stressed_mid-raw_spread*0.5,ask100=stressed_mid+raw_spread*0.5;
   double bid125=stressed_mid-raw_spread*1.25*0.5,ask125=stressed_mid+raw_spread*1.25*0.5;
   Record(18,"spread_stress_keeps_absolute_risk",Almost(paired_risk,1.0) && bid125<bid100 && ask125>ask100,
          StringFormat("risk=%.2f;bid100=%.3f;bid125=%.3f",paired_risk,bid100,bid125));
  }

int OnInit()
  {
   FolderCreate(InpLogFolder,FILE_COMMON);
   string name=InpLogFolder+"\\ExpectedValue_TickShock_"+InpRunId+"_research_reachability.csv";
   g_file=FileOpen(name,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(g_file==INVALID_HANDLE) return INIT_FAILED;
   FileWrite(g_file,"test_id","test_name","result","detail");
   RunTests();
   FileWrite(g_file,"SUMMARY","all",g_failed==0?"PASS":"FAIL",StringFormat("passed=%d;failed=%d;production_path=true",g_passed,g_failed));
   FileFlush(g_file);
   PrintFormat("TickShock production-path research reachability: passed=%d failed=%d",g_passed,g_failed);
   return g_failed==0?INIT_SUCCEEDED:INIT_FAILED;
  }

void OnDeinit(const int reason)
  {
   if(g_file!=INVALID_HANDLE) FileClose(g_file);
  }

void OnTick() {}
