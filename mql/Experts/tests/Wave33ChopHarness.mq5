#property strict
#property version "1.00"
#property description "No-order, tester-only synthetic tests for the fixed W1 chop observer."
#include "../../Include/Wave33Visual/Chop.mqh"
input string InpOutputTag="wave33_chop_harness";
input string InpParityFile=""; // Optional FILE_COMMON, UTF-8, semicolon, fixed 20 columns.
int g_checks=0,g_failures=0,g_file=INVALID_HANDLE;
datetime g_base=D'2020.01.01 00:00:00';
void Base(W33Setup &s)
  {
   ZeroMemory(s);s.setup_id="SYNTHETIC";s.symbol="SYNTHETIC";s.upper_tf=PERIOD_M5;s.lower_tf=PERIOD_M1;s.direction=1;
   s.wave1_start_time=g_base+60;s.wave1_start_known_at=g_base+120;s.wave1_start_price=100;
   s.wave1_peak_time=g_base+600;s.wave1_peak_known_at=g_base+780;s.wave1_peak_price=110;s.wave1_peak_fixed=true;
  }
void Add(W33Pivot &p[],const int seconds,const int known,const double price,const bool high)
  {
   int n=ArraySize(p);ArrayResize(p,n+1);ZeroMemory(p[n]);p[n].time=g_base+seconds;p[n].known_at=g_base+known;
   p[n].price=price;p[n].is_high=high;p[n].tf=PERIOD_M1;
  }
void Check(const string name,const W33Setup &s,const W33Pivot &p[],const datetime coverage,const datetime evaluate,
           const string expected_status,const string expected_reason,const double expected_ratio,const int expected_count)
  {
   W33ChopResult r;W33ChopEvaluate(s,p,evaluate,coverage,r);
   bool ok=r.status==expected_status && r.reason==expected_reason;
   if(expected_status!="UNAVAILABLE")ok=ok && MathAbs(r.ratio-expected_ratio)<1e-12 && r.normalized_pivots==expected_count;
   g_checks++;if(!ok)g_failures++;
   Print("CHOP_TEST ",name," ",ok?"PASS":"FAIL"," status=",r.status," reason=",r.reason," ratio=",DoubleToString(r.ratio,16)," pivots=",r.normalized_pivots);
   if(g_file!=INVALID_HANDLE)FileWrite(g_file,name,ok?"PASS":"FAIL",expected_status,r.status,r.reason,DoubleToString(r.ratio,16),r.raw_pivots,r.normalized_pivots,
      r.pivot_times,r.pivot_known_at,r.pivot_prices,r.pivot_types);
  }
void Parity()
  {
   if(InpParityFile=="")return;
   int source=FileOpen(InpParityFile,FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON,';',CP_UTF8);
   if(source==INVALID_HANDLE){g_checks++;g_failures++;Print("CHOP_PARITY INPUT_OPEN_FAILED ",GetLastError());return;}
   int output=FileOpen(InpOutputTag+"_parity.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,';',CP_UTF8);
   if(output==INVALID_HANDLE){FileClose(source);g_checks++;g_failures++;return;}
   FileWrite(output,"scenario_id","result","status","reason","ratio","adverse","span","raw_pivots","normalized_pivots","path_times","path_known_at","path_prices","path_types");
   string cells[20],current="";W33Setup s;ZeroMemory(s);W33Pivot p[];datetime evaluated=0,coverage=0;
   for(int c=0;c<20 && !FileIsEnding(source);c++)cells[c]=FileReadString(source); // Header.
   while(!FileIsEnding(source))
     {
      for(int c=0;c<20;c++)cells[c]=FileReadString(source);
      if(cells[0]=="")continue;
      if(cells[1]=="SETUP")
        {
         current=cells[0];ZeroMemory(s);ArrayResize(p,0);s.setup_id=current;s.symbol="PARITY";
         s.direction=(int)StringToInteger(cells[2]);s.upper_tf=(ENUM_TIMEFRAMES)StringToInteger(cells[3]);s.lower_tf=(ENUM_TIMEFRAMES)StringToInteger(cells[4]);
         s.wave1_start_time=StringToTime(cells[5]);s.wave1_start_known_at=StringToTime(cells[6]);s.wave1_start_price=StringToDouble(cells[7]);
         s.wave1_peak_time=StringToTime(cells[8]);s.wave1_peak_known_at=StringToTime(cells[9]);s.wave1_peak_price=StringToDouble(cells[10]);
         s.wave1_peak_fixed=true;s.wave1_revision=(int)StringToInteger(cells[13]);evaluated=StringToTime(cells[11]);coverage=StringToTime(cells[12]);
        }
      else if(cells[1]=="PIVOT" && current==cells[0])
        {
         int n=ArraySize(p);ArrayResize(p,n+1);ZeroMemory(p[n]);p[n].tf=s.lower_tf;
         p[n].time=StringToTime(cells[14]);p[n].known_at=StringToTime(cells[15]);p[n].price=StringToDouble(cells[16]);p[n].is_high=StringToInteger(cells[17])!=0;
        }
      else if(cells[1]=="EVAL" && current==cells[0])
        {
         W33ChopResult r;W33ChopEvaluate(s,p,evaluated,coverage,r);
         bool ok=r.status==cells[18] && (r.status=="UNAVAILABLE" || MathAbs(r.ratio-StringToDouble(cells[19]))<1e-10);
         g_checks++;if(!ok)g_failures++;
         FileWrite(output,current,ok?"PASS":"FAIL",r.status,r.reason,DoubleToString(r.ratio,16),DoubleToString(r.adverse,16),DoubleToString(r.span,16),
            r.raw_pivots,r.normalized_pivots,r.pivot_times,r.pivot_known_at,r.pivot_prices,r.pivot_types);
         Print("CHOP_PARITY ",current," ",ok?"PASS":"FAIL"," ",r.status," ",DoubleToString(r.ratio,16));
        }
      else {g_checks++;g_failures++;Print("CHOP_PARITY INVALID_ROW type=",cells[1]," scenario=",cells[0]);}
     }
   FileClose(output);FileClose(source);
  }
void UIAssert(const string name,const bool ok)
  {
   g_checks++;if(!ok)g_failures++;
   Print("CHOP_UI_TEST ",name," ",ok?"PASS":"FAIL");
   if(g_file!=INVALID_HANDLE)FileWrite(g_file,name,ok?"PASS":"FAIL","UI","UI","",0,0,0,"","","","");
  }
void ObjectsTest()
  {
   Print("CHOP_UI_CONTEXT event=OnTick visual=",MQLInfoInteger(MQL_VISUAL_MODE)," chart_id=",ChartID());
   W33Setup s;Base(s);s.setup_id="SYNTHETIC_LONG_SETUP_ID_123456789012345678901234567890123456789012345678901234567890";
   s.entry_price=106;s.wave2_extreme_price=102;
   W33Event e;ZeroMemory(e);e.setup=s;e.at=g_base+900;e.event_type="WAVE1_PEAK_CONFIRMED";
   CWave33ChopObserver observer;
   bool opened=observer.Open(InpOutputTag+"_ui","W33_CHOP_UI_",PERIOD_M1,true,true);
   UIAssert("observer_csv_open",opened);observer.AcceptedLowerBar(g_base);observer.Event(e);
   string name=W33ChopLabelName("W33_CHOP_UI_",s.setup_id,0,1);
   UIAssert("long_setup_id_compact_object_exists",StringLen(name)<=63 && ObjectFind(0,name)>=0);
   UIAssert("label_at_knowledge_time",(datetime)ObjectGetInteger(0,name,OBJPROP_TIME,0)==e.at);
   ChartRedraw(0);ResetLastError();string observed_tooltip=ObjectGetString(0,name,OBJPROP_TOOLTIP);
   Print("CHOP_TOOLTIP_AUDIT length=",StringLen(observed_tooltip)," error=",GetLastError()," value=",observed_tooltip);
   UIAssert("tooltip_retains_full_setup_id",StringFind(observed_tooltip,s.setup_id)>=0);
   UIAssert("peak_label_at_fixed_peak",MathAbs(ObjectGetDouble(0,name,OBJPROP_PRICE,0)-110)<1e-12);
   int before=ObjectsTotal(0);e.event_type="SIGNAL";e.at++;observer.Event(e);
   UIAssert("signal_does_not_duplicate_label",ObjectsTotal(0)==before);
   e.event_type="ORDER";e.at++;observer.Event(e);
   string order_name=W33ChopLabelName("W33_CHOP_UI_",s.setup_id,0,3);
   UIAssert("order_label_at_entry_quote",ObjectFind(0,order_name)>=0 && MathAbs(ObjectGetDouble(0,order_name,OBJPROP_PRICE,0)-106)<1e-12);
   UIAssert("text_objects_no_horizontal_rays",(ENUM_OBJECT)ObjectGetInteger(0,name,OBJPROP_TYPE)==OBJ_TEXT && (ENUM_OBJECT)ObjectGetInteger(0,order_name,OBJPROP_TYPE)==OBJ_TEXT);
   observer.Close();UIAssert("close_preserves_review_objects",ObjectFind(0,name)>=0);observer.Clear();
   UIAssert("explicit_cleanup_removes_objects",ObjectFind(0,name)<0 && ObjectFind(0,order_name)<0);
   CWave33ChopObserver off;off.Open(InpOutputTag+"_ui_off","W33_CHOP_OFF_",PERIOD_M1,true,false);off.AcceptedLowerBar(g_base);off.Event(e);
   string off_name=W33ChopLabelName("W33_CHOP_OFF_",s.setup_id,0,1);
   UIAssert("draw_disabled_creates_no_objects",ObjectFind(0,off_name)<0);off.Close();off.Clear();
  }
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER)){Print("CHOP_HARNESS TESTER_ONLY; no orders are implemented.");return INIT_FAILED;}
   g_file=FileOpen(InpOutputTag+".csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,';',CP_UTF8);
   if(g_file==INVALID_HANDLE)return INIT_FAILED;
   FileWrite(g_file,"test","result","expected_status","actual_status","reason","ratio","raw_pivots","normalized_pivots","path_times","path_known_at","path_prices","path_types");
   W33Setup s;Base(s);W33Pivot p[];
   Add(p,180,300,108,true);Add(p,300,420,103,false);Add(p,420,540,109,true);Add(p,480,600,106,false);
   Check("long_backtrack",s,p,g_base,g_base+900,"CHOPPY","",0.8,4);
   s.direction=-1;s.wave1_start_price=200;s.wave1_peak_price=190;
   for(int i=0;i<ArraySize(p);i++){p[i].price=300-p[i].price;p[i].is_high=!p[i].is_high;}
   Check("short_mirror",s,p,g_base,g_base+900,"CHOPPY","",0.8,4);
   Base(s);ArrayResize(p,0);
   Check("zero_interior_valid",s,p,g_base,g_base+900,"CLEAN","",0,0);
   Check("coverage_missing",s,p,0,g_base+900,"UNAVAILABLE","LOWER_HISTORY_INCOMPLETE",0,0);
   Check("coverage_starts_late",s,p,g_base+61,g_base+900,"UNAVAILABLE","LOWER_HISTORY_INCOMPLETE",0,0);
   Check("coverage_exact_start",s,p,g_base+60,g_base+900,"CLEAN","",0,0);
   Add(p,180,300,107,true);Add(p,240,360,108,true);Add(p,300,420,103,false);
   Check("same_type_collapse_exact_threshold",s,p,g_base,g_base+900,"CHOPPY","",0.5,2);
   p[2].price=103.01;
   Check("just_below_threshold",s,p,g_base,g_base+900,"CLEAN","",0.499,2);
   p[2].price=102.99;
   Check("just_above_threshold",s,p,g_base,g_base+900,"CHOPPY","",0.501,2);
   p[2].known_at=g_base+901;
   Check("future_pivot_excluded",s,p,g_base,g_base+900,"CLEAN","",0,1);
   p[2].known_at=g_base+900;
   Check("known_exact_evaluation_included_if_previously_published",s,p,g_base,g_base+900,"CHOPPY","",0.501,2);
   ArrayResize(p,0);Add(p,300,420,108,true);Add(p,300,420,102,false);
   Check("same_source_high_low_ambiguous",s,p,g_base,g_base+900,"UNAVAILABLE","SAME_TIME_HIGH_LOW_AMBIGUOUS",0,0);
   p[1].known_at=g_base+901;
   Check("future_collision_excluded",s,p,g_base,g_base+900,"CLEAN","",0,1);
   ArrayResize(p,0);Add(p,300,420,108,true);Add(p,180,500,102,false);
   Check("source_order_invalid",s,p,g_base,g_base+900,"UNAVAILABLE","PIVOT_CHRONOLOGY",0,0);
   p[1].time=g_base+360;p[1].known_at=g_base+400;
   Check("known_order_invalid",s,p,g_base,g_base+900,"UNAVAILABLE","PIVOT_CHRONOLOGY",0,0);
   ArrayResize(p,0);Add(p,180,100,108,true);
   Check("known_before_source",s,p,g_base,g_base+900,"UNAVAILABLE","PIVOT_KNOWN_BEFORE_SOURCE",0,0);
   ArrayResize(p,0);Add(p,60,180,90,false);Add(p,600,780,120,true);
   Check("source_at_anchors_excluded",s,p,g_base,g_base+900,"CLEAN","",0,0);
   ArrayResize(p,0);Add(p,180,300,90,true);Add(p,300,420,95,false);
   Check("relative_high_low_gap_allowed",s,p,g_base,g_base+900,"CHOPPY","",1,2);
   ArrayResize(p,0);Add(p,180,300,108,true);Add(p,300,420,103,false);
   Check("revision_zero",s,p,g_base,g_base+900,"CHOPPY","",0.5,2);
   s.wave1_revision=1;s.wave1_peak_time=g_base+900;s.wave1_peak_known_at=g_base+1080;s.wave1_peak_price=115;
   Add(p,660,780,111,true);Add(p,780,900,108,false);
   Check("extension_revision_recomputed",s,p,g_base,g_base+1200,"CHOPPY","",8.0/15.0,4);
   s.wave1_extension_pending=true;
   Check("extension_not_fixed",s,p,g_base,g_base+1200,"UNAVAILABLE","FIXED_ANCHORS_MISSING",0,0);
   Base(s);s.wave1_peak_price=99;
   Check("wrong_direction_span",s,p,g_base,g_base+1200,"UNAVAILABLE","NONPOSITIVE_DIRECTIONAL_SPAN",0,0);
   Base(s);s.wave1_start_known_at=0;
   Check("missing_anchor_known_time",s,p,g_base,g_base+1200,"UNAVAILABLE","FIXED_ANCHORS_MISSING",0,0);
   Base(s);
   Check("endpoint_not_yet_known",s,p,g_base,g_base+700,"UNAVAILABLE","ANCHOR_NOT_KNOWN",0,0);
   Parity();
   Print("CHOP_HARNESS_CORE_COMPLETE checks=",g_checks," failures=",g_failures," awaiting first OnTick for initialized chart properties");
   return INIT_SUCCEEDED;
  }
void OnTick()
  {
   static bool finished=false;if(finished)return;finished=true;ObjectsTest();
   Print("CHOP_HARNESS_SUMMARY checks=",g_checks," failures=",g_failures," orders=0 result=",g_failures==0?"PASS":"FAIL");
   FileWrite(g_file,"SUMMARY",g_failures==0?"PASS":"FAIL",g_checks,g_failures,"orders=0");FileClose(g_file);g_file=INVALID_HANDLE;
   ExpertRemove();
  }
void OnDeinit(const int reason){if(g_file!=INVALID_HANDLE)FileClose(g_file);}
