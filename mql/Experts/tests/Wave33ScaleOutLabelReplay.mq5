// Draw-only normal-chart regression: changed risk labels must use the time at
// which the new line became available. No account, orders or strategy calls.
#property strict
#property version "1.00"
#include "../../Include/Wave33Visual/LabelLayout.mqh"
input string InpRunTag="scale_label";
CWave33LabelLayout qa_layout;
int qa_file=INVALID_HANDLE,qa_checks=0,qa_failures=0,qa_stage=0,qa_waits=0;
string qa_prefix="SO_L_",qa_names[4];
datetime qa_old_at=0,qa_new_at=0;
double qa_prices[4];
void QA(const string name,const bool ok,const string detail="")
  {qa_checks++;if(!ok)qa_failures++;FileWrite(qa_file,name,ok?"PASS":"FAIL",detail);FileFlush(qa_file);Print(name," ",ok?"PASS":"FAIL"," ",detail);}
datetime ExpectedTime(const int i){return i<2?qa_new_at:qa_old_at;}
void CheckAnchors(const string phase)
  {
   for(int i=0;i<4;i++){datetime at=0;double price=0;bool known=qa_layout.Anchor(qa_names[i],at,price);QA(phase+"_anchor_"+(string)i,known && at==ExpectedTime(i) && MathAbs(price-qa_prices[i])<1e-8,TimeToString(at,TIME_SECONDS));}
   int leaders=0;bool finite=true,source=true;
   for(int j=0;j<ObjectsTotal(0);j++)
     {string name=ObjectName(0,j);if(StringFind(name,"W33LL_")!=0)continue;leaders++;finite=finite && !ObjectGetInteger(0,name,OBJPROP_RAY_LEFT) && !ObjectGetInteger(0,name,OBJPROP_RAY_RIGHT);double price=ObjectGetDouble(0,name,OBJPROP_PRICE,0);int matched=-1;for(int i=0;i<4;i++)if(MathAbs(price-qa_prices[i])<1e-8)matched=i;source=source && matched>=0 && ObjectGetInteger(0,name,OBJPROP_TIME,0)==ExpectedTime(matched);}
   QA(phase+"_four_finite_leaders",leaders==4 && finite);QA(phase+"_leader_source_time_and_price",source);
  }
bool ScreenshotSaved(const string name)
  {if(!FileIsExist(name) && qa_waits++<30)return false;bool ok=FileIsExist(name) && FileMove(name,0,name,FILE_COMMON|FILE_REWRITE);QA(name+"_saved",ok);qa_waits=0;return true;}
int OnInit()
  {
   if(MQLInfoInteger(MQL_TESTER))return INIT_PARAMETERS_INCORRECT;
   string custom="QA_SO_"+InpRunTag;
   if(_Symbol!=custom)
     {
      if(!SymbolInfoInteger(custom,SYMBOL_CUSTOM) && !CustomSymbolCreate(custom,"Codex QA",_Symbol))return INIT_FAILED;
      CustomSymbolSetInteger(custom,SYMBOL_DIGITS,2);CustomSymbolSetDouble(custom,SYMBOL_POINT,0.01);CustomSymbolSetInteger(custom,SYMBOL_TRADE_MODE,SYMBOL_TRADE_MODE_DISABLED);
      MqlRates bars[];ArrayResize(bars,1000);for(int i=0;i<1000;i++){ZeroMemory(bars[i]);bars[i].time=D'2025.01.06'+i*60;bars[i].open=1000+3*MathSin(i*0.07);bars[i].close=1000+3*MathSin((i+1)*0.07);bars[i].high=MathMax(bars[i].open,bars[i].close)+0.3;bars[i].low=MathMin(bars[i].open,bars[i].close)-0.3;bars[i].tick_volume=100;}
      if(CustomRatesReplace(custom,bars[0].time,bars[999].time,bars)!=1000 || !SymbolSelect(custom,true) || !ChartSetSymbolPeriod(0,custom,PERIOD_M1))return INIT_FAILED;return INIT_SUCCEEDED;
     }
   qa_file=FileOpen(InpRunTag+"_assertions.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,';',CP_UTF8);if(qa_file==INVALID_HANDLE)return INIT_FAILED;FileWrite(qa_file,"test","result","detail");
   ChartSetInteger(0,CHART_AUTOSCROLL,false);ChartSetInteger(0,CHART_SCALE,3);ChartSetInteger(0,CHART_SHOW_GRID,false);ChartNavigate(0,CHART_END,0);ChartRedraw();EventSetTimer(1);return INIT_SUCCEEDED;
  }
void OnTick(){}
void OnTimer()
  {
   if(qa_file==INVALID_HANDLE)return;
   if(qa_stage==0)
     {
      int w=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS),h=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS),sub=0;double price=0;bool geometry=w>=500 && h>=300 && ChartXYToTimePrice(0,w/3,h/2,sub,qa_old_at,price);QA("chart_geometry_available",geometry);if(!geometry){qa_stage=4;return;}
      qa_new_at=qa_old_at+3*60;qa_layout.Init(qa_prefix);qa_layout.Configure(true);
      for(int i=0;i<4;i++){string line=qa_prefix+(i<2?"changed_":"ordinary_")+(i%2==0?"SL":"TP");qa_names[i]=line+"_label";qa_prices[i]=price+(i-1.5)*0.3;ObjectCreate(0,line,OBJ_TREND,0,qa_old_at,qa_prices[i],qa_old_at+600,qa_prices[i]);ObjectSetInteger(0,line,OBJPROP_RAY_LEFT,false);ObjectSetInteger(0,line,OBJPROP_RAY_RIGHT,false);ObjectCreate(0,qa_names[i],OBJ_TEXT,0,qa_old_at,qa_prices[i]);ObjectSetString(0,qa_names[i],OBJPROP_TEXT,i%2==0?"SL":"TP");ObjectSetInteger(0,qa_names[i],OBJPROP_COLOR,i%2==0?clrTomato:clrLimeGreen);}
      qa_layout.Layout(true);for(int i=0;i<4;i++){datetime at;double p;QA("initial_anchor_"+(string)i,qa_layout.Anchor(qa_names[i],at,p) && at==qa_old_at && MathAbs(p-qa_prices[i])<1e-8);}
      QA("before_screenshot_requested",ChartScreenShot(0,InpRunTag+"_dense_before.png",w,h,ALIGN_LEFT));qa_stage++;return;
     }
   if(qa_stage==1)
     {
      if(!ScreenshotSaved(InpRunTag+"_dense_before.png"))return;
      for(int i=0;i<4;i++){qa_prices[i]+=0.1;string line=StringSubstr(qa_names[i],0,StringLen(qa_names[i])-6);ObjectMove(0,line,0,qa_new_at,qa_prices[i]);ObjectMove(0,line,1,qa_new_at+600,qa_prices[i]);ObjectMove(0,qa_names[i],0,qa_new_at,qa_prices[i]);ObjectSetString(0,qa_names[i],OBJPROP_TEXT,i==0?"SL 建値":(i==1?"TP 全量（分割不可）":(i==2?"SL":"TP")));qa_layout.Touch(qa_names[i]);}
      qa_layout.Layout(true);CheckAnchors("after_change");QA("after_screenshot_requested",ChartScreenShot(0,InpRunTag+"_dense_after.png",(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS),(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS),ALIGN_LEFT));qa_stage++;return;
     }
   if(qa_stage==2)
     {
      if(!ScreenshotSaved(InpRunTag+"_dense_after.png"))return;
      qa_layout.Layout(true);CheckAnchors("repeat_layout");qa_layout.Configure(false);for(int i=0;i<4;i++)QA("OFF_restores_correct_anchor_"+(string)i,ObjectGetInteger(0,qa_names[i],OBJPROP_TIME,0)==ExpectedTime(i) && MathAbs(ObjectGetDouble(0,qa_names[i],OBJPROP_PRICE,0)-qa_prices[i])<1e-8);
      int leaders=0;for(int j=0;j<ObjectsTotal(0);j++)if(StringFind(ObjectName(0,j),"W33LL_")==0)leaders++;QA("OFF_removes_visual_leaders",leaders==0);qa_stage=4;
     }
   if(qa_stage==4){EventKillTimer();FileWrite(qa_file,"SUMMARY",qa_failures==0?"PASS":"FAIL",(string)qa_checks+" checks, "+(string)qa_failures+" failures");FileClose(qa_file);qa_file=INVALID_HANDLE;TerminalClose(0);}
  }
void OnDeinit(const int reason){EventKillTimer();if(qa_file!=INVALID_HANDLE)FileClose(qa_file);}
