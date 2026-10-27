// Draw-only normal-chart UI fixture. No orders, account queries, or strategy evaluation.
#property strict
#property version "1.00"
#include "../../Include/Wave33Visual/ChopDisplay.mqh"
input string InpRunTag="label_replay";
bool InpQAVisual=true;
int qa_file=INVALID_HANDLE,qa_checks=0,qa_failures=0;
void QA(const string name,const bool ok,const string detail="")
  {qa_checks++;if(!ok)qa_failures++;Print("NORMAL_LAYOUT_QA ",name," ",ok?"PASS":"FAIL"," ",detail);FileWrite(qa_file,name,ok?"PASS":"FAIL",detail);FileFlush(qa_file);}
string qa_names[];
datetime qa_anchor_time;
double qa_anchor_price;
CWave33ChopDisplay qa_display;
bool qa_label_ready=false;
int qa_visual_stage=0;
int qa_capture_waits=0;
bool qa_stage_advance=true,qa_saved_scale_fixed=false;
double qa_saved_fixed_min=0,qa_saved_fixed_max=0;
string QALabelCaption(const int i)
  {if(i==0)return "①旧 第1波 r0 始点と終点の履歴を保持";return (i%2==0?"見送り: 接続する逆方向の第1波候補を認識したため終了 ":"抵抗候補 M15 高値 2025.01.14 21:35 known 21:50 ")+(string)i;}
void QACheckBoxes(CWave33ChopDisplay &display,const string phase,const bool require_all)
  {
   int count=ArraySize(qa_names),xs[],ys[],ws[],hs[];ArrayResize(xs,count);ArrayResize(ys,count);ArrayResize(ws,count);ArrayResize(hs,count);int placed=0;
   int width=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS),height=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);bool inside=true,anchors=true,spacing=true;
   for(int i=0;i<count;i++)
     {datetime at;double p;anchors=anchors && display.LabelAnchor(qa_names[i],at,p) && at==qa_anchor_time && MathAbs(p-qa_anchor_price)<1e-9;
      if(!display.LabelBounds(qa_names[i],xs[i],ys[i],ws[i],hs[i])){ws[i]=0;continue;}placed++;inside=inside && xs[i]>=8 && ys[i]>=24 && xs[i]+ws[i]<=width-72 && ys[i]+hs[i]<=height-8;}
   for(int i=0;i<count;i++)for(int j=i+1;j<count;j++)if(ws[i]>0 && ws[j]>0)spacing=spacing && (xs[i]+ws[i]<=xs[j] || xs[j]+ws[j]<=xs[i] || ys[i]+hs[i]<=ys[j] || ys[j]+hs[j]<=ys[i]);
   QA("label_logical_anchors_stable_"+phase,anchors);QA("label_boxes_clamped_"+phase,inside);QA("label_boxes_no_overlap_"+phase,spacing);QA("label_all_visible_"+phase,!require_all || placed==count,(string)placed+" / "+(string)count);
  }
void QALabels(const int stage)
  {
   if(stage==0)
     {
   ChartRedraw();int width=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS),height=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0),sub=0;
   double low=ChartGetDouble(0,CHART_PRICE_MIN,0),high=ChartGetDouble(0,CHART_PRICE_MAX,0);
   bool available=width>=500 && height>=300 && high>low && ChartXYToTimePrice(0,width/3,height/2,sub,qa_anchor_time,qa_anchor_price) && qa_anchor_price>0;
   FileWrite(qa_file,"LABEL_CHART_GEOMETRY",available?"AVAILABLE":"UNAVAILABLE","width="+(string)width+" height="+(string)height+"; headless absence is not visual proof");
   if(InpQAVisual)QA("visual_geometry_available",available);if(!available)return;
   qa_label_ready=true;string prefix="QA_FIXTURE_";qa_display.Init(prefix,true);qa_display.ConfigureReadability(false);
   string unrelated="EXTERNAL_FIXTURE";ObjectCreate(0,unrelated,OBJ_TEXT,0,qa_anchor_time,qa_anchor_price);ObjectSetString(0,unrelated,OBJPROP_TEXT,"unrelated");
   int count=20;ArrayResize(qa_names,count);
   for(int i=0;i<count;i++)
     {qa_names[i]=prefix+"fixture_"+(string)i;ObjectCreate(0,qa_names[i],OBJ_TEXT,0,qa_anchor_time,qa_anchor_price);ObjectSetString(0,qa_names[i],OBJPROP_TEXT,QALabelCaption(i));ObjectSetString(0,qa_names[i],OBJPROP_TOOLTIP,"Full fixture provenance "+(string)i);ObjectSetInteger(0,qa_names[i],OBJPROP_COLOR,i%2!=0?clrViolet:clrOrangeRed);ObjectSetInteger(0,qa_names[i],OBJPROP_FONTSIZE,10);ObjectSetInteger(0,qa_names[i],OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);}
   ChartRedraw();if(InpQAVisual)QA("before_screenshot_requested",ChartScreenShot(0,InpRunTag+"_dense_before.png",width,height,ALIGN_LEFT));return;
     }
   if(!qa_label_ready)return;
   string prefix="QA_FIXTURE_",unrelated="EXTERNAL_FIXTURE";int count=ArraySize(qa_names);
   if(stage==1)
     {
   string before=InpRunTag+"_dense_before.png";
   if(!FileIsExist(before) && qa_capture_waits++<30){qa_stage_advance=false;return;}
   QA("before_screenshot_saved",FileIsExist(before) && FileMove(before,0,before,FILE_COMMON|FILE_REWRITE));qa_capture_waits=0;
   qa_display.ConfigureReadability(true);qa_display.Layout(true);QACheckBoxes(qa_display,"initial",true);
   QA("label_ownership_excludes_unrelated",!qa_display.LabelManaged(unrelated) && ObjectGetString(0,unrelated,OBJPROP_TEXT)=="unrelated");
   bool finite=true,leader_anchor=true;int leaders=0;
   for(int i=0;i<ObjectsTotal(0);i++){string n=ObjectName(0,i);if(StringFind(n,"W33LL_")!=0)continue;leaders++;finite=finite && !ObjectGetInteger(0,n,OBJPROP_RAY_LEFT) && !ObjectGetInteger(0,n,OBJPROP_RAY_RIGHT);leader_anchor=leader_anchor && ObjectGetInteger(0,n,OBJPROP_TIME,0)==qa_anchor_time && MathAbs(ObjectGetDouble(0,n,OBJPROP_PRICE,0)-qa_anchor_price)<1e-9;}
   QA("label_finite_leaders",finite && leaders>=count,(string)leaders);QA("label_leader_true_source_anchors",leader_anchor);
   qa_display.Layout(true);QACheckBoxes(qa_display,"repeat",true);
   long scale=ChartGetInteger(0,CHART_SCALE);ChartSetInteger(0,CHART_SCALE,(scale+1)%6);ChartRedraw();qa_display.Layout(true);QACheckBoxes(qa_display,"zoom",false);ChartSetInteger(0,CHART_SCALE,scale);ChartRedraw();qa_display.Layout(true);
   qa_saved_scale_fixed=(bool)ChartGetInteger(0,CHART_SCALEFIX);qa_saved_fixed_min=ChartGetDouble(0,CHART_FIXED_MIN);qa_saved_fixed_max=ChartGetDouble(0,CHART_FIXED_MAX);
   ChartSetInteger(0,CHART_SCALEFIX,true);ChartSetDouble(0,CHART_FIXED_MAX,qa_anchor_price+150);ChartSetDouble(0,CHART_FIXED_MIN,qa_anchor_price+100);ChartRedraw();return;
     }
   if(stage==2)
     {
   qa_display.Layout(true);double low=ChartGetDouble(0,CHART_PRICE_MIN),high=ChartGetDouble(0,CHART_PRICE_MAX);
   QA("offscreen_viewport_applied",qa_anchor_price<low || qa_anchor_price>high,"min="+DoubleToString(low,2)+" max="+DoubleToString(high,2)+" anchor="+DoubleToString(qa_anchor_price,2));
   bool offscreen_style=true;for(int i=0;i<count;i++)offscreen_style=offscreen_style && ObjectGetInteger(0,qa_names[i],OBJPROP_FONTSIZE)==10 && ObjectGetInteger(0,qa_names[i],OBJPROP_COLOR)==(i%2!=0?clrViolet:clrOrangeRed);
   QA("offscreen_restores_original_font_colour",offscreen_style,"font0="+(string)ObjectGetInteger(0,qa_names[0],OBJPROP_FONTSIZE));
   ChartSetDouble(0,CHART_FIXED_MIN,qa_saved_fixed_min);ChartSetDouble(0,CHART_FIXED_MAX,qa_saved_fixed_max);ChartSetInteger(0,CHART_SCALEFIX,qa_saved_scale_fixed);ChartRedraw();return;
     }
   if(stage==3)
     {
   qa_display.Layout(true);QACheckBoxes(qa_display,"return_from_offscreen",true);
   if(InpQAVisual)QA("after_screenshot_requested",ChartScreenShot(0,InpRunTag+"_dense_after.png",(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS),(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0),ALIGN_LEFT));return;
     }
   string after=InpRunTag+"_dense_after.png";
   if(!FileIsExist(after) && qa_capture_waits++<30){qa_stage_advance=false;return;}
   QA("after_screenshot_saved",FileIsExist(after) && FileMove(after,0,after,FILE_COMMON|FILE_REWRITE));qa_capture_waits=0;
   qa_display.ConfigureReadability(false);bool restored=true;for(int i=0;i<count;i++)restored=restored && ObjectGetInteger(0,qa_names[i],OBJPROP_TIME,0)==qa_anchor_time && MathAbs(ObjectGetDouble(0,qa_names[i],OBJPROP_PRICE,0)-qa_anchor_price)<1e-9 && ObjectGetString(0,qa_names[i],OBJPROP_TEXT)==QALabelCaption(i) && ObjectGetInteger(0,qa_names[i],OBJPROP_FONTSIZE)==10 && ObjectGetInteger(0,qa_names[i],OBJPROP_COLOR)==(i%2!=0?clrViolet:clrOrangeRed);
   QA("label_off_restores_originals",restored);qa_display.Clear();ObjectsDeleteAll(0,prefix);ObjectDelete(0,unrelated);
  }
void QAFinish()
  {FileWrite(qa_file,"SUMMARY",qa_failures?"FAIL":"PASS",(string)qa_checks+" checks; "+(string)qa_failures+" failures");FileClose(qa_file);qa_file=INVALID_HANDLE;TerminalClose(0);}
int OnInit()
  {
   if(MQLInfoInteger(MQL_TESTER))return INIT_PARAMETERS_INCORRECT;
   string custom="QA_PL_"+InpRunTag;
   if(_Symbol!=custom)
     {
      if(!SymbolInfoInteger(custom,SYMBOL_CUSTOM) && !CustomSymbolCreate(custom,"Codex QA",_Symbol))return INIT_FAILED;
      CustomSymbolSetInteger(custom,SYMBOL_DIGITS,2);CustomSymbolSetDouble(custom,SYMBOL_POINT,0.01);CustomSymbolSetInteger(custom,SYMBOL_TRADE_MODE,SYMBOL_TRADE_MODE_DISABLED);
      MqlRates bars[];ArrayResize(bars,1000);
      for(int i=0;i<1000;i++){ZeroMemory(bars[i]);bars[i].time=D'2025.01.06 00:00'+i*60;bars[i].open=1000+3*MathSin(i*0.07);bars[i].close=1000+3*MathSin((i+1)*0.07);bars[i].high=MathMax(bars[i].open,bars[i].close)+0.3;bars[i].low=MathMin(bars[i].open,bars[i].close)-0.3;bars[i].tick_volume=100;bars[i].spread=10;}
      if(CustomRatesReplace(custom,bars[0].time,bars[999].time,bars)!=1000 || !SymbolSelect(custom,true) || !ChartSetSymbolPeriod(0,custom,PERIOD_M1))return INIT_FAILED;
      return INIT_SUCCEEDED;
     }
   qa_file=FileOpen(InpRunTag+"_assertions.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,';',CP_UTF8);if(qa_file==INVALID_HANDLE)return INIT_FAILED;FileWrite(qa_file,"test","result","detail");
   ChartSetInteger(0,CHART_AUTOSCROLL,false);ChartSetInteger(0,CHART_SCALE,3);ChartSetInteger(0,CHART_SHOW_GRID,false);ChartNavigate(0,CHART_END,0);ChartRedraw();EventSetTimer(1);return INIT_SUCCEEDED;
  }
void OnTick(){}
void OnTimer(){if(qa_file==INVALID_HANDLE)return;qa_stage_advance=true;QALabels(qa_visual_stage);if(qa_stage_advance)qa_visual_stage++;if(qa_visual_stage>=5){EventKillTimer();QAFinish();}}
void OnDeinit(const int reason){EventKillTimer();if(qa_file!=INVALID_HANDLE)FileClose(qa_file);}
