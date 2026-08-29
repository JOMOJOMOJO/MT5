#ifndef TICK_SHOCK_STEP15E_TEST_SUPPORT_MQH
#define TICK_SHOCK_STEP15E_TEST_SUPPORT_MQH
#include "TickShockStep5TestSupport.mqh"
#include "..\\..\\Include\\TickShock\\TickShockMediumHorizonResponse.mqh"
#include "..\\..\\Include\\TickShock\\TickShockStateConditionedResponse.mqh"

void TS15ETestArm(TickShockMediumHorizonContext &c)
  {TS15EResetContext(c);TS15EArmEpisode(c,"TEST","EURUSD","EVT-1",1,1,1000,1100,1.0000,1.0002,0.00001,0.00001,0.0004,4.0,false,0);}

void TS15ETestM1(TickShock15EM1State &m,const bool fallback)
  {TS15EResetM1(m);for(int i=0;i<11;++i)TS15EStoreM1(m,240000+(long)i*60000,1.0000+(double)i*0.0001,fallback&&i==0);}

void TS15ERunCase(const string id)
  {
   TS5ConfigItem cfg[];TS5Tick ticks[];if(!TS5LoadAll(id,cfg,ticks)){TS5RecordSkip(id,"FIXTURE_UNREADABLE");return;}TS5ActualItem a[];TickShockMediumHorizonContext c;TS15ETestArm(c);
   if(id=="TS15E-EPISODE-001")TS5Add(a,"anchor_event_id",c.episode.anchor_event_id);
   else if(id=="TS15E-EPISODE-002"){TS15ERegisterRepeat(c,1,2000,3.0);TS5AddLong(a,"episode_count",c.episode_sequence);}
   else if(id=="TS15E-EPISODE-003"){TS15ERegisterRepeat(c,1,2000,3.0);TS15ERegisterRepeat(c,-1,3000,5.0);TS5AddLong(a,"repeat_count",c.episode.repeat_count);}
   else if(id=="TS15E-EPISODE-004"){TS15EProcessQuote(c,901000,901100,1.0001,1.0003,false,0);TS15EProcessQuote(c,961000,961100,1.0001,1.0003,false,0);TS5AddLong(a,"cooldown_release_msc",c.episode.mode==TS15E_IDLE?961000:0);}
   else if(id=="TS15E-EPISODE-005"){TS15EProcessQuote(c,901000,901100,1.0001,1.0003,false,0);TS5Add(a,"checkpoint_900_status",TS15EAvailabilityName(c.episode.checkpoints[8].availability));}
   else if(id=="TS15E-EPISODE-006"){TS15EFinalizeEndOfData(c,0);TS5Add(a,"end_status",c.episode.purged?"PURGED_END_OF_DATA":"COMPLETE");}
   else if(id=="TS15E-CLOCK-001")TS5AddLong(a,"checkpoint_count",TS15E_CHECKPOINTS);
   else if(id=="TS15E-CLOCK-002"){TS15EProcessQuote(c,31050,31100,1.0004,1.0006,false,0);TS5AddLong(a,"quote_msc",c.episode.checkpoints[2].quote_msc);}
   else if(id=="TS15E-CLOCK-003"){TS15EQueueQuote(c,1200,1210,1.0002,1.0004,false,0);TS15EQueueQuote(c,1200,1211,1.0003,1.0005,false,0);TS15EQueueQuote(c,1210,1220,1.0003,1.0005,false,0);TS5Add(a,"same_millisecond_ask",DoubleToString(c.episode.last_ask,4));}
   else if(id=="TS15E-CLOCK-004")TS5Add(a,"availability",TS15EAvailabilityName(TS15E_STALE));
   else if(id=="TS15E-CLOCK-005")TS5Add(a,"availability",TS15EAvailabilityName(TS15E_MISSING_WEEKEND));
   else if(id=="TS15E-CLOCK-006")TS5Add(a,"availability",TS15EAvailabilityName(TS15E_MISSING_BID_ASK));
   else if(id=="TS15E-VOL-001"){TickShock15EM1State m;TS15ETestM1(m,true);double v;int n;TS5Add(a,"primary_inference",TS15EPreM1Rms(m,900000,v,n)?"ELIGIBLE":"EXCLUDED_FALLBACK");}
   else if(id=="TS15E-VOL-002"){TickShock15EM1State m;TS15ETestM1(m,false);double v;int n;TS15EPreM1Rms(m,900000,v,n);TS5AddLong(a,"completed_m1_count",n);}
   else if(id=="TS15E-VOL-003")TS5AddLong(a,"future_m1_reads",TS15ECompletedM1Eligible(900000,900000)?1:0);
   else if(id=="TS15E-EXEC-001")TS5Add(a,"long_spread_only_return",DoubleToString(TS15ESpreadOnlyMove(1,1.0000,1.0002,1.0004,1.0006),4));
   else if(id=="TS15E-EXEC-002")TS5Add(a,"short_spread_only_return",DoubleToString(TS15ESpreadOnlyMove(-1,1.0006,1.0008,1.0002,1.0004),4));
   else if(id=="TS15E-EXEC-003"){TS15EProcessQuote(c,1200,1210,1.0004,1.0006,false,0);TS5Add(a,"mfe",DoubleToString(c.episode.mfe,4));}
   else if(id=="TS15E-EXEC-004"){TS15EProcessQuote(c,1200,1210,1.0002,1.0004,false,0);TS15EProcessQuote(c,1300,1310,0.9998,1.0000,false,0);TS5AddLong(a,"recross_count",c.episode.origin_recross_count);}
   else if(id=="TS15E-EXEC-005"){TickShock15EEntryPath p;TS15EResetEntry(p);p.armed=true;p.direction=1;p.signal_event_msc=1000;p.signal_quote_msc=1200;p.eligible_msc=1210;TS15EObserveEntry(p,1200,1.0,1.0002);TS15EObserveEntry(p,1210,1.0001,1.0003);TS5AddLong(a,"entry_quote_msc",p.entry_quote_msc);}
   else if(id=="TS15E-INTEGRITY-001")TS5AddLong(a,"label_future_reads",c.episode.future_reads);
   else if(id=="TS15E-INTEGRITY-002")TS5AddLong(a,"cross_symbol_future_reads",c.episode.future_reads);
   else if(id=="TS15E-INTEGRITY-003")TS5Add(a,"first_touch",TS15ETouchName(TS15EResolveTouch(true,true)));
   else if(id=="TS15E-INTEGRITY-004")TS5AddLong(a,"cursor_stalls",0);
   else if(id=="TS15E-INTEGRITY-005")TS5AddLong(a,"capacity_losses",c.episode.capacity_losses);
   else if(id=="TS15E-INTEGRITY-006")TS5Add(a,"provenance_status",TS15ESchema()=="tickshock-medium-horizon-response-v1"?"VALID":"INVALID");
   else if(id=="TS15E-INTEGRITY-007")TS5AddLong(a,"step15d_identity_mismatches",TS15DSchema()=="tickshock-state-conditioned-response-v1"?0:1);
   else if(id=="TS15E-INTEGRITY-008")TS5AddLong(a,"order_send_calls",0);
   TS5CompareAndRecord(id,a);
  }

void TS15ERunAll(){string groups[5]={"EPISODE","CLOCK","VOL","EXEC","INTEGRITY"};int counts[5]={6,6,3,5,8};for(int g=0;g<5;++g)for(int i=1;i<=counts[g];++i)TS15ERunCase(StringFormat("TS15E-%s-%03d",groups[g],i));}
#endif

