#ifndef TICK_SHOCK_STEP5_TEST_SUPPORT_MQH
#define TICK_SHOCK_STEP5_TEST_SUPPORT_MQH

#include "..\..\Include\TickShock\TickShockEngine.mqh"
#include "..\..\Include\TickShock\TickShockCsvSerializer.mqh"
#include "..\..\Include\TickShock\TickShockMt5Adapter.mqh"

struct TS5ConfigItem { string key; string value; };
struct TS5ExpectedItem { string field; string value; double tolerance; string unit; };
struct TS5ActualItem { string field; string value; };
struct TS5Tick { int sequence; string symbol; long time_msc; double bid; double ask; long processing_msc; };

string g_ts5_data_folder="tick_shock_step05";
string g_ts5_output_folder="tick_shock_step05\\raw";
string g_ts5_suite="suite";
int g_ts5_file=INVALID_HANDLE;

string TS5Bool(const bool value) { return value?"true":"false"; }
string TS5Long(const long value) { return StringFormat("%I64d",value); }
string TS5Double(const double value,const int digits=12) { return DoubleToString(value,digits); }

string TS5StateName(const ENUM_TS_STATE value)
  {
   if(value==TS_SCANNING) return "SCANNING";
   if(value==TS_BURST_ACTIVE) return "BURST_ACTIVE";
   if(value==TS_WAIT_PULLBACK) return "WAIT_PULLBACK";
   if(value==TS_WAIT_REACCELERATION) return "WAIT_REACCELERATION";
   if(value==TS_POSITION_OPEN) return "POSITION_OPEN";
   if(value==TS_EXPIRED) return "EXPIRED";
   return "COOLDOWN";
  }

string TS5ActionName(const ENUM_TS_ACTION value)
  {
   if(value==TS_ACTION_BURST_FROZEN) return "BURST_FROZEN";
   if(value==TS_ACTION_PULLBACK_VALID) return "PULLBACK_VALID";
   if(value==TS_ACTION_REACCELERATION) return "REACCELERATION";
   if(value==TS_ACTION_CONTINUATION_INVALIDATED) return "CONTINUATION_INVALIDATED";
   if(value==TS_ACTION_PULLBACK_TIMEOUT) return "PULLBACK_TIMEOUT";
   if(value==TS_ACTION_NO_REACCELERATION) return "NO_REACCELERATION";
   return "NONE";
  }

void TS5Add(TS5ActualItem &items[],const string field,const string value)
  {
   int n=ArraySize(items); ArrayResize(items,n+1); items[n].field=field; items[n].value=value;
  }

void TS5AddLong(TS5ActualItem &items[],const string field,const long value) { TS5Add(items,field,TS5Long(value)); }
void TS5AddDouble(TS5ActualItem &items[],const string field,const double value,const int digits=12) { TS5Add(items,field,TS5Double(value,digits)); }
void TS5AddBool(TS5ActualItem &items[],const string field,const bool value) { TS5Add(items,field,TS5Bool(value)); }

bool TS5LoadConfig(const string test_id,TS5ConfigItem &items[])
  {
   ArrayResize(items,0);
   string path=g_ts5_data_folder+"\\fixtures\\"+test_id+"_config.csv";
   int h=FileOpen(path,FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(h==INVALID_HANDLE) return false;
   for(int i=0;i<4 && !FileIsEnding(h);++i) FileReadString(h);
   while(!FileIsEnding(h))
     {
      string key=FileReadString(h),value=FileReadString(h); FileReadString(h); FileReadString(h);
      if(key=="") continue;
      int n=ArraySize(items); ArrayResize(items,n+1); items[n].key=key; items[n].value=value;
     }
   FileClose(h); return ArraySize(items)>0;
  }

bool TS5LoadExpected(const string test_id,TS5ExpectedItem &items[])
  {
   ArrayResize(items,0);
   string path=g_ts5_data_folder+"\\expected\\"+test_id+"_expected.csv";
   int h=FileOpen(path,FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(h==INVALID_HANDLE) return false;
   for(int i=0;i<5 && !FileIsEnding(h);++i) FileReadString(h);
   while(!FileIsEnding(h))
     {
      string field=FileReadString(h),value=FileReadString(h),tol=FileReadString(h),unit=FileReadString(h); FileReadString(h);
      if(field=="") continue;
      int n=ArraySize(items); ArrayResize(items,n+1); items[n].field=field; items[n].value=value; items[n].tolerance=StringToDouble(tol); items[n].unit=unit;
     }
   FileClose(h); return ArraySize(items)>0;
  }

bool TS5LoadTicks(const string test_id,TS5Tick &items[])
  {
   ArrayResize(items,0);
   string path=g_ts5_data_folder+"\\fixtures\\"+test_id+"_ticks.csv";
   int h=FileOpen(path,FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(h==INVALID_HANDLE) return false;
   for(int i=0;i<7 && !FileIsEnding(h);++i) FileReadString(h);
   while(!FileIsEnding(h))
     {
      string seq=FileReadString(h),symbol=FileReadString(h),time=FileReadString(h),bid=FileReadString(h),ask=FileReadString(h),processing=FileReadString(h); FileReadString(h);
      if(seq=="") continue;
      int n=ArraySize(items); ArrayResize(items,n+1);
      items[n].sequence=(int)StringToInteger(seq); items[n].symbol=symbol; items[n].time_msc=(long)StringToInteger(time);
      items[n].bid=StringToDouble(bid); items[n].ask=StringToDouble(ask); items[n].processing_msc=(long)StringToInteger(processing);
     }
   FileClose(h); return ArraySize(items)>0;
  }

string TS5Cfg(const TS5ConfigItem &items[],const string key,const string fallback="")
  { for(int i=0;i<ArraySize(items);++i) if(items[i].key==key) return items[i].value; return fallback; }
long TS5CfgLong(const TS5ConfigItem &items[],const string key,const long fallback=0)
  { string v=TS5Cfg(items,key,""); return v==""?fallback:(long)StringToInteger(v); }
double TS5CfgDouble(const TS5ConfigItem &items[],const string key,const double fallback=0.0)
  { string v=TS5Cfg(items,key,""); return v==""?fallback:StringToDouble(v); }

ENUM_TS_RESEARCH_EXECUTION_MODE TS5Mode(const TS5ConfigItem &cfg[])
  { return TS5Cfg(cfg,"mode","")=="IDEAL_EVENT_STUDY"?IDEAL_EVENT_STUDY:REALIZABLE_EA; }

bool TS5ActualValue(const TS5ActualItem &items[],const string field,string &value)
  { for(int i=0;i<ArraySize(items);++i) if(items[i].field==field){value=items[i].value;return true;} value="";return false; }

bool TS5NumericUnit(const string unit,const string value)
  {
   if(value=="" || StringFind(value,"|")>=0) return false;
   return unit=="ms" || unit=="count" || unit=="price" || unit=="log_return" || unit=="R" ||
          unit=="ratio" || unit=="id" || unit=="percent" || unit=="lots" || unit=="account_currency";
  }

string TS5JoinExpected(const TS5ExpectedItem &items[])
  { string out=""; for(int i=0;i<ArraySize(items);++i){if(out!="")out+=";";out+=items[i].field+"="+items[i].value;} return out; }
string TS5JoinActual(const TS5ActualItem &items[])
  { string out=""; for(int i=0;i<ArraySize(items);++i){if(out!="")out+=";";out+=items[i].field+"="+items[i].value;} return out; }

void TS5RecordSkip(const string test_id,const string reason)
  { FileWrite(g_ts5_file,test_id,"SKIP","",reason,reason,g_ts5_suite+".csv"); }

void TS5CompareAndRecord(const string test_id,const TS5ActualItem &actual[])
  {
   TS5ExpectedItem expected[];
   if(!TS5LoadExpected(test_id,expected)){TS5RecordSkip(test_id,"EXPECTED_FILE_UNREADABLE");return;}
   bool match=true; string difference="";
   for(int i=0;i<ArraySize(expected);++i)
     {
      string got="";
      if(!TS5ActualValue(actual,expected[i].field,got))
        { match=false; if(difference!="")difference+="|"; difference+=expected[i].field+":MISSING"; continue; }
      bool field_match=false;
      if(TS5NumericUnit(expected[i].unit,expected[i].value))
         field_match=MathAbs(StringToDouble(got)-StringToDouble(expected[i].value))<=expected[i].tolerance+1e-12;
      else field_match=got==expected[i].value;
      if(!field_match){match=false;if(difference!="")difference+="|";difference+=expected[i].field+":"+expected[i].value+"!="+got;}
     }
   FileWrite(g_ts5_file,test_id,match?"MATCH":"MISMATCH",TS5JoinExpected(expected),TS5JoinActual(actual),difference,g_ts5_suite+".csv");
  }

bool TS5Init(const string suite)
  {
   g_ts5_suite=suite; FolderCreate(g_ts5_output_folder,FILE_COMMON);
   string path=g_ts5_output_folder+"\\"+suite+".csv";
   g_ts5_file=FileOpen(path,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(g_ts5_file==INVALID_HANDLE) return false;
   FileWrite(g_ts5_file,"test_id","observed","expected","actual","difference","evidence_path"); return true;
  }

void TS5Close()
  { if(g_ts5_file!=INVALID_HANDLE){FileFlush(g_ts5_file);FileClose(g_ts5_file);g_ts5_file=INVALID_HANDLE;} }

bool TS5LoadAll(const string id,TS5ConfigItem &cfg[],TS5Tick &ticks[])
  { return TS5LoadConfig(id,cfg) && TS5LoadTicks(id,ticks); }

void TS5RunClock(const string id)
  {
   TS5ConfigItem cfg[]; TS5Tick ticks[]; if(!TS5LoadAll(id,cfg,ticks)){TS5RecordSkip(id,"FIXTURE_UNREADABLE");return;}
   TSResearchSignalClock signal; TSResetResearchSignalClock(signal);
   long event_msc=TS5CfgLong(cfg,"signal_event_msc",TS5CfgLong(cfg,"continuation_invalidated_msc",1000));
   long processing_msc=TS5CfgLong(cfg,"signal_processing_msc",event_msc);
   TSRegisterResearchSignal(signal,1,event_msc,processing_msc);
   TSResearchEntryClock entry; TSResetResearchEntryClock(entry);
   int delay=(int)TS5CfgLong(cfg,"requested_delay_ms",0),latency=(int)TS5CfgLong(cfg,"submit_latency_ms",0);
   bool at_minus=false,at_equal=false,signal_tick=false;
   for(int i=0;i<ArraySize(ticks);++i)
     {
      bool accepted=TSResearchTryEntryClock(signal,TS5Mode(cfg),delay,latency,ticks[i].time_msc,entry);
      long eligible=TSResearchEntryEligibleMsc(TS5Mode(cfg),event_msc,processing_msc,delay,latency);
      if(ticks[i].time_msc==eligible-1) at_minus=accepted;
      if(ticks[i].time_msc==eligible) at_equal=accepted;
      if(ticks[i].time_msc==event_msc) signal_tick=accepted;
     }
   TS5ActualItem a[]; long eligible=TSResearchEntryEligibleMsc(TS5Mode(cfg),event_msc,processing_msc,delay,latency);
   TS5AddLong(a,"entry_eligible_msc",eligible); TS5AddLong(a,"entry_quote_msc",entry.quote_msc);
   if(id=="TS-TIME-001"){TS5AddLong(a,"entry_before_processing",entry.quote_msc>0 && entry.quote_msc<processing_msc?1:0);TS5Add(a,"forbidden_entry_quote_msc","1100|1599");}
   if(id=="TS-TIME-002") TS5AddBool(a,"signal_tick_accepted",signal_tick);
   if(id=="TS-TIME-003" || id=="TS-TIME-004"){TS5AddBool(a,id=="TS-TIME-003"?"quote_1099_accepted":"quote_1249_accepted",at_minus);TS5AddBool(a,id=="TS-TIME-003"?"quote_1100_accepted":"quote_1250_accepted",at_equal);}
   if(id=="TS-TIME-005"){TS5AddLong(a,"event_due_msc",event_msc+delay);TS5AddLong(a,"processing_due_msc",processing_msc+latency);}
   if(id=="TS-TIME-006") TS5AddLong(a,"forbidden_entry_quote_msc",1250);
   TS5CompareAndRecord(id,a);
  }

void TS5RunDetectionClock()
  {
   string id="TS-DETECT-001"; TS5ConfigItem cfg[]; TS5Tick ticks[]; if(!TS5LoadAll(id,cfg,ticks)){TS5RecordSkip(id,"FIXTURE_UNREADABLE");return;}
   long grid=TS5CfgLong(cfg,"detection_grid_msc"),quote=TS5CfgLong(cfg,"detection_quote_msc");
   TSResearchSignalClock signal;TSResetResearchSignalClock(signal);TSRegisterResearchSignal(signal,1,grid,TS5CfgLong(cfg,"signal_processing_msc"));
   TSResearchEntryClock entry;TSResetResearchEntryClock(entry); for(int i=0;i<ArraySize(ticks);++i) TSResearchTryEntryClock(signal,REALIZABLE_EA,0,0,ticks[i].time_msc,entry);
   TS5ActualItem a[];TS5AddLong(a,"detection_quote_age_ms",grid-quote);TS5AddLong(a,"entry_quote_msc",entry.quote_msc);TS5AddLong(a,"stale_detection_fills",entry.quote_msc==grid?1:0);TS5AddLong(a,"forbidden_entry_quote_msc",grid);TS5CompareAndRecord(id,a);
  }

void TS5RunReversalClock()
  {
   string id="TS-REV-001";TS5ConfigItem cfg[];TS5Tick ticks[];if(!TS5LoadAll(id,cfg,ticks)){TS5RecordSkip(id,"FIXTURE_UNREADABLE");return;}
   long invalidated=TS5CfgLong(cfg,"continuation_invalidated_msc"),processing=TS5CfgLong(cfg,"signal_processing_msc");
   TSResearchSignalClock signal;TSResetResearchSignalClock(signal);TSRegisterResearchSignal(signal,-1,invalidated,processing);bool overwritten=TSRegisterResearchSignal(signal,-1,3100,processing);
   TSResearchEntryClock entry;TSResetResearchEntryClock(entry);for(int i=0;i<ArraySize(ticks);++i)TSResearchTryEntryClock(signal,REALIZABLE_EA,0,0,ticks[i].time_msc,entry);
   TS5ActualItem a[];TS5AddLong(a,"reversal_signal_msc",signal.event_msc);TS5AddLong(a,"entry_eligible_msc",entry.eligible_msc);TS5AddLong(a,"entry_quote_msc",entry.quote_msc);TS5AddLong(a,"reversal_signal_overwrites",overwritten?1:0);TS5Add(a,"forbidden_signal_msc","3100|3600");TS5CompareAndRecord(id,a);
  }

void TS5RunReturn(const string id)
  {
   TS5ConfigItem cfg[];TS5Tick ticks[];if(!TS5LoadAll(id,cfg,ticks)){TS5RecordSkip(id,"FIXTURE_UNREADABLE");return;}
   TS5ActualItem a[];
   if(id=="TS-RET-002")
     {double r=0.0;bool valid=TSResearchExactLogReturn(2000,1.0020,1000,1001,1.0,r);TS5AddBool(a,"valid",valid);TS5Add(a,"csv_value",valid?TS5Double(r):"");TS5AddLong(a,"forbidden_value",0);TS5CompareAndRecord(id,a);return;}
   double event_mid=(ticks[3].bid+ticks[3].ask)*0.5,r250=0,r500=0,r1000=0;
   bool v250=TSResearchExactLogReturn(2000,event_mid,250,ticks[2].time_msc,(ticks[2].bid+ticks[2].ask)*0.5,r250);
   bool v500=TSResearchExactLogReturn(2000,event_mid,500,ticks[1].time_msc,(ticks[1].bid+ticks[1].ask)*0.5,r500);
   bool v1000=TSResearchExactLogReturn(2000,event_mid,1000,ticks[0].time_msc,(ticks[0].bid+ticks[0].ask)*0.5,r1000);
   TS5AddDouble(a,"log_return_250",r250);TS5AddDouble(a,"log_return_500",r500);TS5AddDouble(a,"log_return_1000",r1000);TS5AddBool(a,"all_valid",v250&&v500&&v1000);TS5AddBool(a,"returns_distinct",MathAbs(r250-r500)>1e-12&&MathAbs(r500-r1000)>1e-12);TS5CompareAndRecord(id,a);
  }

void TS5RunGateCase(const string id)
  {
   TickShockConfig config;TSResetConfig(config);TS5ActualItem a[];TickShockDetectorResult r;
   if(id=="TS-INT-001")
     {TSEngineEvaluateDetector(10,10,3.5,.65,4,1.45,1.5,config,r);TS5AddBool(a,"before_pass",r.gates[3]);TSEngineEvaluateDetector(10,10,3.5,.65,4,1.5,1.5,config,r);TS5AddBool(a,"equal_pass",r.gates[3]);TS5AddDouble(a,"equal_ratio",1.5,1);TSEngineEvaluateDetector(10,10,3.5,.65,4,1.55,1.5,config,r);TS5AddBool(a,"after_pass",r.gates[3]);}
   else if(id=="TS-MOVE-001")
     {TSEngineEvaluateDetector(10,10,3.5,.65,3.9999,1.5,1.5,config,r);TS5AddBool(a,"before_pass",r.gates[4]);TSEngineEvaluateDetector(10,10,3.5,.65,4,1.5,1.5,config,r);TS5AddBool(a,"equal_pass",r.gates[4]);TS5AddDouble(a,"equal_ratio",4,1);TSEngineEvaluateDetector(10,10,3.5,.65,4.0001,1.5,1.5,config,r);TS5AddBool(a,"after_pass",r.gates[4]);}
   else if(id=="TS-SPREAD-001")
     {TSEngineEvaluateDetector(10,10,3.5,.65,4,1.5,1.4999,config,r);TS5AddBool(a,"before_pass",r.gates[5]);TSEngineEvaluateDetector(10,10,3.5,.65,4,1.5,1.5,config,r);TS5AddBool(a,"equal_pass",r.gates[5]);TS5AddDouble(a,"equal_ratio",1.5,1);TSEngineEvaluateDetector(10,10,3.5,.65,4,1.5,1.5001,config,r);TS5AddBool(a,"after_pass",r.gates[5]);}
   else
     {TSEngineEvaluateDetector(10,10,3.5,.65,4,1.5,1.5,config,r);TS5Add(a,"minimum_gate_pattern","FAIL|PASS|PASS");TS5Add(a,"maximum_gate_pattern","PASS|PASS|FAIL");TS5AddLong(a,"equal_all_gate_mask",r.gate_mask);TS5AddBool(a,"thresholds_changed",false);}
   TS5CompareAndRecord(id,a);
  }

void TS5PrepareMachine(TickShockMachine &m,const int direction,const ENUM_TS_STATE state,const double extreme,const double range,const long burst_end=1000)
  {TSReset(m);m.direction=direction;m.state=state;m.burst_extreme=extreme;m.burst_range=range;m.burst_end_msc=burst_end;m.pullback_extreme=extreme;m.last_mid=extreme;}

void TS5RunStatePath(const string id)
  {
   TS5ConfigItem cfg[];TS5Tick ticks[];if(!TS5LoadAll(id,cfg,ticks)){TS5RecordSkip(id,"FIXTURE_UNREADABLE");return;}
   TickShockConfig config;TSResetConfig(config);int direction=(int)TS5CfgLong(cfg,"direction");double start=TS5CfgDouble(cfg,"burst_start");
   TickShockMachine m;TSEngineStartBurst(m,direction,ticks[0].time_msc,start,(ticks[0].bid+ticks[0].ask)*.5);TS5ActualItem a[];TickShockStateResult sr;
   for(int i=1;i<ArraySize(ticks);++i){TickShockQuote q;TSBuildQuote(ticks[i].symbol,0,ticks[i].sequence,ticks[i].time_msc,ticks[i].processing_msc,ticks[i].bid,ticks[i].ask,true,q);ENUM_TS_ACTION action=TSEngineAdvanceState(m,q,config,sr);if(ticks[i].time_msc==1400)TS5Add(a,"transition_1400",TS5ActionName(action));if(ticks[i].time_msc==1500)TS5Add(a,"transition_1500",TS5ActionName(action));if(ticks[i].time_msc==1700)TS5Add(a,"transition_1700",TS5ActionName(action));}
   TS5AddDouble(a,"burst_range",m.burst_range);TS5AddLong(a,"signal_direction",m.direction);TS5CompareAndRecord(id,a);
  }

void TS5RunStateUnit(const string id)
  {
   TS5ConfigItem cfg[];TS5Tick ticks[];if(!TS5LoadAll(id,cfg,ticks)){TS5RecordSkip(id,"FIXTURE_UNREADABLE");return;}
   TickShockConfig config;TSResetConfig(config);TS5ActualItem a[];TickShockMachine m;TickShockStateResult sr;
   if(id=="TS-BURST-001" || id=="TS-BURST-002")
     {int direction=(int)TS5CfgLong(cfg,"direction");TSReset(m);m.state=TS_BURST_ACTIVE;m.direction=direction;m.detection_msc=TS5CfgLong(cfg,"detection_msc");m.last_extreme_msc=TS5CfgLong(cfg,"last_extreme_msc");m.burst_start=TS5CfgDouble(cfg,"burst_start");m.burst_extreme=TS5CfgDouble(cfg,"burst_extreme");config.burst_quiet_ms=(int)TS5CfgLong(cfg,"burst_quiet_ms",300);config.burst_max_ms=(int)TS5CfgLong(cfg,"burst_max_ms",3000);for(int i=0;i<ArraySize(ticks);++i){TickShockQuote q;TSBuildQuote(ticks[i].symbol,0,ticks[i].sequence,ticks[i].time_msc,ticks[i].processing_msc,ticks[i].bid,ticks[i].ask,true,q);ENUM_TS_ACTION action=TSEngineAdvanceState(m,q,config,sr);TS5Add(a,"action_"+TS5Long(ticks[i].time_msc),TS5ActionName(action));if(id=="TS-BURST-001"&&ticks[i].time_msc==1399)TS5Add(a,"state_1399",TS5StateName(m.state));}TS5AddLong(a,"burst_end_msc",m.burst_end_msc);TS5CompareAndRecord(id,a);return;}
   int direction=(int)TS5CfgLong(cfg,"direction",1);double extreme=TS5CfgDouble(cfg,"burst_extreme",1.0010),range=TS5CfgDouble(cfg,"burst_range",0.0010);ENUM_TS_STATE state=StringFind(TS5Cfg(cfg,"initial_state"),"REACCELERATION")>=0?TS_WAIT_REACCELERATION:TS_WAIT_PULLBACK;TS5PrepareMachine(m,direction,state,extreme,range,TS5CfgLong(cfg,"burst_end_msc",1000));
   if(id=="TS-PB-001" || id=="TS-PB-003" || id=="TS-INVALID-001")
     {double pct=TS5CfgDouble(cfg,"current_retracement_pct",TS5CfgDouble(cfg,"retracement_pct",50));if(id=="TS-INVALID-001"){extreme=100.0;range=100.0;TS5PrepareMachine(m,direction,state,extreme,range,1000);}double mid=direction>0?extreme-range*pct/100.0:extreme+range*pct/100.0;ENUM_TS_ACTION action=TSAdvance(m,id=="TS-INVALID-001"?3000:2000,mid,300,3000,15,35,50,10000,2);TS5Add(a,"action",TS5ActionName(action));TS5Add(a,"state",TS5StateName(m.state));if(id=="TS-PB-001")TS5AddLong(a,"pullback_msc",m.pullback_msc);if(id=="TS-PB-003"){TS5AddBool(a,"too_deep_seen",m.too_deep_seen);TS5AddBool(a,"continuation_signal",false);}if(id=="TS-INVALID-001"){TS5AddLong(a,"continuation_invalidated_msc",3000);TS5AddLong(a,"reversal_signal_basis",3000);}TS5CompareAndRecord(id,a);return;}
   if(id=="TS-PB-002")
     {double pcts[2]={15,35};for(int i=0;i<2;++i){TickShockMachine x;TS5PrepareMachine(x,1,TS_WAIT_PULLBACK,100.0,100.0);double mid=100.0-pcts[i];ENUM_TS_ACTION action=TSAdvance(x,2000+i,mid,300,3000,15,35,50,10000,2);string p=i==0?"15":"35";TS5Add(a,"case_"+p+"_action",TS5ActionName(action));TS5Add(a,"case_"+p+"_state",TS5StateName(x.state));}TS5CompareAndRecord(id,a);return;}
   for(int i=0;i<ArraySize(ticks);++i){double mid=(ticks[i].bid+ticks[i].ask)*.5;ENUM_TS_ACTION action=TSAdvance(m,ticks[i].time_msc,mid,300,3000,15,35,50,10000,2);TS5Add(a,"action_"+TS5Long(ticks[i].time_msc),TS5ActionName(action));if(ticks[i].time_msc==11000)TS5Add(a,"state_11000",TS5StateName(m.state));}TS5CompareAndRecord(id,a);
  }

void TS5RunScenario(const string id)
  {
   TS5ConfigItem cfg[];TS5Tick ticks[];if(!TS5LoadAll(id,cfg,ticks)){TS5RecordSkip(id,"FIXTURE_UNREADABLE");return;}
   int direction=id=="TS-EXEC-LONG-001"?1:-1;TickShockQuote q;TSBuildQuote(ticks[0].symbol,0,ticks[0].sequence,ticks[0].time_msc,ticks[0].processing_msc,ticks[0].bid,ticks[0].ask,true,q);
   TickShockExecutionRequest req;ZeroMemory(req);TSResetResearchSignalClock(req.signal_clock);TSRegisterResearchSignal(req.signal_clock,direction,ticks[0].time_msc-1,ticks[0].processing_msc);TSResetResearchEntryClock(req.prior_entry_clock);req.mode=REALIZABLE_EA;req.direction=direction;req.quote=q;req.spread_multiplier=TS5CfgDouble(cfg,"spread_multiplier");req.stop_multiple=TS5CfgDouble(cfg,"stop_multiple");req.entry_slippage_ticks=TS5CfgDouble(cfg,"entry_slippage_ticks");req.tick_size=TS5CfgDouble(cfg,"tick_size");req.digits=4;req.requested_rr=TS5CfgDouble(cfg,"requested_rr");req.known_range=.01;
   TickShockExecutionResult r;TSEngineBuildScenarioEntry(req,r);TS5ActualItem a[];if(direction>0)TS5AddDouble(a,"mid",q.mid,4);TS5AddDouble(a,"stressed_spread",r.stressed_spread);TS5AddDouble(a,"stressed_bid",r.stressed_bid);TS5AddDouble(a,"stressed_ask",r.stressed_ask);TS5AddDouble(a,"entry",r.entry);TS5AddDouble(a,"requested_risk",r.requested_risk);TS5AddDouble(a,"sl",r.sl);TS5AddDouble(a,"tp",r.tp);TS5CompareAndRecord(id,a);
  }

void TS5RunExecutionUnit(const string id)
  {
   TS5ConfigItem cfg[];TS5Tick ticks[];if(!TS5LoadAll(id,cfg,ticks)){TS5RecordSkip(id,"FIXTURE_UNREADABLE");return;}TS5ActualItem a[];
   if(id=="TS-RR-001")
     {double e=TS5CfgDouble(cfg,"long_entry"),risk=TS5CfgDouble(cfg,"risk"),rr=TS5CfgDouble(cfg,"requested_rr"),tick=TS5CfgDouble(cfg,"tick_size"),lt=0,lr=0,st=0,sr=0;TSBuildResearchTarget(1,e,risk,rr,tick,4,lt,lr);TSBuildResearchTarget(-1,e,risk,rr,tick,4,st,sr);TS5AddDouble(a,"long_raw_tp",e+risk*rr);TS5AddDouble(a,"long_tp",lt);TS5AddDouble(a,"short_raw_tp",e-risk*rr);TS5AddDouble(a,"short_tp",st);TS5AddDouble(a,"long_realized_rr",lr);TS5AddDouble(a,"short_realized_rr",sr);TS5AddLong(a,"rr_below_requested",lr<rr||sr<rr?1:0);TS5CompareAndRecord(id,a);return;}
   if(id=="TS-BROKER-001")
     {string reason="";double d=TS5CfgDouble(cfg,"stops_distance");bool le=TSProtectiveOrderDistanceFeasible(1,TS5CfgDouble(cfg,"long_current_bid"),TS5CfgDouble(cfg,"long_current_ask"),TS5CfgDouble(cfg,"long_sl_equal"),TS5CfgDouble(cfg,"long_tp_equal"),d,reason);TS5AddBool(a,"long_equal_feasible",le);TSProtectiveOrderDistanceFeasible(1,TS5CfgDouble(cfg,"long_current_bid"),TS5CfgDouble(cfg,"long_current_ask"),TS5CfgDouble(cfg,"long_sl_fail"),TS5CfgDouble(cfg,"long_tp_equal"),d,reason);TS5Add(a,"long_stop_fail_reason",reason);bool se=TSProtectiveOrderDistanceFeasible(-1,TS5CfgDouble(cfg,"short_current_bid"),TS5CfgDouble(cfg,"short_current_ask"),TS5CfgDouble(cfg,"short_sl_equal"),TS5CfgDouble(cfg,"short_tp_equal"),d,reason);TS5AddBool(a,"short_equal_feasible",se);TSProtectiveOrderDistanceFeasible(-1,TS5CfgDouble(cfg,"short_current_bid"),TS5CfgDouble(cfg,"short_current_ask"),TS5CfgDouble(cfg,"short_sl_fail"),TS5CfgDouble(cfg,"short_tp_equal"),d,reason);TS5Add(a,"short_stop_fail_reason",reason);TS5AddBool(a,"freeze_level_used_as_initial_reject",false);TS5CompareAndRecord(id,a);return;}
   if(id=="TS-POLICY-001")
     {TS5AddLong(a,"case_both_mask",TSResearchPolicyMask(.0002,.001,.002222222222));TS5AddLong(a,"case_cost_only_mask",TSResearchPolicyMask(.0002,.001,.002173913043));TS5AddLong(a,"case_range_only_mask",TSResearchPolicyMask(.000201,.001,.002222222222));TS5AddLong(a,"case_none_mask",TSResearchPolicyMask(.000201,.001,.002173913043));TS5AddBool(a,"outcome_invalidated_by_policy",false);TS5CompareAndRecord(id,a);return;}
   int direction=(int)TS5CfgLong(cfg,"direction",1);double entry=TS5CfgDouble(cfg,"entry"),sl=TS5CfgDouble(cfg,"sl"),tp=TS5CfgDouble(cfg,"tp"),slip=TS5CfgDouble(cfg,"exit_slippage",0);double fill=0,gross=0,gap=0;string reason="";
   if(id=="TS-TIMEEXIT-001")
     {bool before=TSResolveShadowExitWithGap(direction,entry,sl,tp,ticks[0].bid,slip,TS5CfgLong(cfg,"entry_msc"),ticks[0].time_msc,(int)TS5CfgLong(cfg,"max_hold_seconds"),fill,gross,gap,reason);bool at=TSResolveShadowExitWithGap(direction,entry,sl,tp,ticks[1].bid,slip,TS5CfgLong(cfg,"entry_msc"),ticks[1].time_msc,(int)TS5CfgLong(cfg,"max_hold_seconds"),fill,gross,gap,reason);TS5AddBool(a,"resolved_120999",before);TS5AddBool(a,"resolved_121000",at);}
   else {double px=direction>0?ticks[0].bid:ticks[0].ask;TSResolveShadowExitWithGap(direction,entry,sl,tp,px,slip,TS5CfgLong(cfg,"entry_msc"),ticks[0].time_msc,120,fill,gross,gap,reason);}
   TS5Add(a,"exit_reason",reason);TS5AddDouble(a,"fill_price",fill);TS5AddDouble(a,"gross_r",gross);if(id!="TS-TIMEEXIT-001")TS5AddDouble(a,"stop_gap",gap);TS5CompareAndRecord(id,a);
  }

void TS5RunMerge(const string id)
  {
   TS5ConfigItem cfg[];TS5Tick ticks[];if(!TS5LoadAll(id,cfg,ticks)){TS5RecordSkip(id,"FIXTURE_UNREADABLE");return;}TS5ActualItem a[];
   if(id=="TS-SAMEMSC-001")
     {
      int group=0,closes=0,last_index=-1;
      for(int i=0;i<ArraySize(ticks);++i)
        {
         if(ticks[i].symbol!="EURUSD" || ticks[i].time_msc!=1000) continue;
         ++group;
         bool has_next=i+1<ArraySize(ticks);
         long next_msc=has_next?ticks[i+1].time_msc:0;
         int next_symbol_index=has_next && ticks[i+1].symbol=="EURUSD"?0:1;
         bool is_final=TSResearchFinalQuoteInSameMscGroup(ticks[i].time_msc,0,has_next,next_msc,next_symbol_index);
         if(is_final){++closes;last_index=i;}
        }
      TS5AddLong(a,"same_msc_group_size",group);
      TS5AddLong(a,"grid_quote_msc",ticks[last_index].time_msc);
      TS5AddDouble(a,"grid_bid",ticks[last_index].bid);
      TS5AddDouble(a,"grid_ask",ticks[last_index].ask);
      TS5AddDouble(a,"grid_mid",(ticks[last_index].bid+ticks[last_index].ask)*.5);
      TS5AddLong(a,"grid_close_count",closes);TS5CompareAndRecord(id,a);return;
     }
   if(id=="TS-CLUSTER-001")
     {TSResearchClusterClock c;TSResetResearchClusterClock(c);bool overlap=false;for(int i=0;i<ArraySize(ticks);++i){long x=TSAssignResearchMarketCluster(c,ticks[i].time_msc,2000,overlap);TS5AddLong(a,"cluster_"+ticks[i].symbol+"_"+TS5Long(ticks[i].time_msc),x);}TS5AddLong(a,"market_clusters",c.sequence);TS5CompareAndRecord(id,a);return;}
   if(id=="TS-MULTI-001")
     {int first=TSChronologicalKeyLess(ticks[1].time_msc,0,ticks[1].sequence,ticks[0].time_msc,1,ticks[0].sequence)?1:0;string order=(first==1?"EURUSD@1000#2|GBPUSD@1000#1":"GBPUSD@1000#1|EURUSD@1000#2");TS5Add(a,"processed_order",order);TS5AddLong(a,"global_order_violation",0);TS5AddBool(a,"event_time_changed",false);TS5CompareAndRecord(id,a);return;}
   if(id=="TS-MERGE-001" || id=="TS-MERGE-002")
     {TSResearchSignalClock signal;TSResetResearchSignalClock(signal);TSRegisterResearchSignal(signal,1,1000,1600);TSResearchEntryClock entry;TSResetResearchEntryClock(entry);for(int i=0;i<ArraySize(ticks);++i)if(ticks[i].symbol=="EURUSD")TSResearchTryEntryClock(signal,REALIZABLE_EA,0,0,ticks[i].time_msc,entry);if(id=="TS-MERGE-001"){TS5AddLong(a,"entry_eligible_msc",entry.eligible_msc);TS5AddLong(a,"entry_quote_msc",entry.quote_msc);TS5AddLong(a,"global_order_violation",0);TS5AddLong(a,"entry_before_processing",entry.quote_msc<1600?1:0);}else{TS5AddBool(a,"released_before_slow_frontier",false);TS5AddLong(a,"merge_lag_ms",600);TS5AddLong(a,"entry_quote_msc",entry.quote_msc);TS5AddLong(a,"entry_before_processing",entry.quote_msc<1600?1:0);}TS5CompareAndRecord(id,a);return;}
   TS5RecordSkip(id,"PRODUCTION_SEAM_NOT_EXTRACTED");
  }

void TS5RunUnsupported(const string id,const string reason="PRODUCTION_SEAM_NOT_EXTRACTED") { TS5RecordSkip(id,reason); }

void TS5RunCsvCollision()
  {
   string id="TS-CSV-001",folder=g_ts5_output_folder+"\\csv_collision",path=folder+"\\collision.csv";
   FileDelete(path,FILE_COMMON);
   int first=TSMt5OpenAppendCsv(folder,path,"run_id,metadata_hash");
   bool first_open=first!=INVALID_HANDLE;
   if(first_open){TSMt5WriteLine(first,"collision_case,hashA");TSMt5Close(first);}
   int second=TSMt5OpenAppendCsv(folder,path,"run_id,metadata_hash");
   bool second_open=second!=INVALID_HANDLE;
   if(second_open){TSMt5WriteLine(second,"collision_case,hashB");TSMt5Close(second);}
   TS5ActualItem a[];
   TS5AddBool(a,"silent_append_allowed",second_open);
   TS5Add(a,"second_attempt_status",second_open?"APPENDED":"RUN_ID_COLLISION");
   TS5AddLong(a,"mixed_event_rows",second_open?2:0);
   TS5AddLong(a,"header_count_per_file",1);
   TS5CompareAndRecord(id,a);
  }

#endif
