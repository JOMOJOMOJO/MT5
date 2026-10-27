#property strict
#property version "1.00"
#property description "DRAW ONLY: replay recorded event snapshots on a normal MT5 chart. NO trading code. Not a tester screenshot."
#include "../../Include/Wave33Visual/Display.mqh"
input string InpFixtureFile="wave33_render_A.csv";
input string InpRenderTag="wave33_render_A";
input bool InpCloseWhenDone=true;
input bool InpPrepareCustom=false;
input string InpSymbolPrefix="W33REVIEW_A";
input string InpSourceSymbol="XAUUSD";
input int InpStartCase=0;
input bool InpSingleCase=false;
input bool InpShowPanel=false;
input bool InpDiagnosticLabels=false;
input bool InpSwingPaths=true;
struct ReviewRow{int index;string id;datetime cutoff;W33Event event;};
ReviewRow rows[];
CWave33Display display;
int current=0,phase=0,tries=0,resultFile=INVALID_HANDLE;
string png="";
W33Setup snapshot;
datetime cutoff=0;
void IncludePrice(const double p,double &lo,double &hi){if(p>0){lo=MathMin(lo,p);hi=MathMax(hi,p);}}
ENUM_TIMEFRAMES TF(string v)
  {if(v=="PERIOD_M1")return PERIOD_M1;if(v=="PERIOD_M5")return PERIOD_M5;if(v=="PERIOD_M15")return PERIOD_M15;return PERIOD_H1;}
void Field(W33Setup &s,const string k,const string v)
  {
   if(k=="setup_id")s.setup_id=v;else if(k=="symbol")s.symbol=v;
   else if(k=="upper_tf")s.upper_tf=TF(v);else if(k=="lower_tf")s.lower_tf=TF(v);
   else if(k=="direction")s.direction=v=="LONG"?1:-1;
   else if(k=="upper_break_level")s.upper_break_level=StringToDouble(v);
   else if(k=="wave1_start_time")s.wave1_start_time=StringToTime(v);
   else if(k=="candidate_detected_at")s.candidate_detected_at=StringToTime(v);
   else if(k=="wave1_start_price")s.wave1_start_price=StringToDouble(v);
   else if(k=="wave1_peak_time")s.wave1_peak_time=StringToTime(v);
   else if(k=="wave1_peak_price")s.wave1_peak_price=StringToDouble(v);
   else if(k=="wave1_peak_known_at")s.wave1_peak_known_at=StringToTime(v);
   else if(k=="wave1_start_known_at")s.wave1_start_known_at=StringToTime(v);
   else if(k=="wave2_extreme_known_at")s.wave2_extreme_known_at=StringToTime(v);
   else if(k=="lower_structure_known_at")s.lower_structure_known_at=StringToTime(v);
   else if(k=="lower_entry_stage")s.lower_entry_stage=v;
   else if(k=="lower_recognition")s.lower_recognition=v;
   else if(k=="lower_unmet_reason")s.lower_unmet_reason=v;
   else if(k=="trigger_known_at")s.trigger_known_at=StringToTime(v);
   else if(k=="signal_at")s.signal_at=StringToTime(v);
   else if(k=="signal_known_at")s.signal_known_at=StringToTime(v);
   else if(k=="wave1_peak_fixed")s.wave1_peak_fixed=v=="1";
   else if(k=="fib_382_price")s.fib_382_price=StringToDouble(v);
   else if(k=="fib_618_price")s.fib_618_price=StringToDouble(v);
   else if(k=="wave2_extreme_time")s.wave2_extreme_time=StringToTime(v);
   else if(k=="wave2_extreme_price")s.wave2_extreme_price=StringToDouble(v);
   else if(k=="lower_wave2_time")s.lower_wave2_time=StringToTime(v);
   else if(k=="lower_wave2_price")s.lower_wave2_price=StringToDouble(v);
   else if(k=="first_progress_bar_time")s.first_progress_bar_time=StringToTime(v);
   else if(k=="first_progress_close_at")s.first_progress_close_at=StringToTime(v);
   else if(k=="first_progress_known_at")s.first_progress_known_at=StringToTime(v);
   else if(k=="first_progress_price")s.first_progress_price=StringToDouble(v);
   else if(k=="retracement_ratio")s.retracement_ratio=StringToDouble(v);
   else if(k=="trigger_line_price")s.trigger_line_price=StringToDouble(v);
   else if(k=="trigger_type")s.trigger_type=v;
   else if(k=="entry_status")s.entry_status=v;
   else if(k=="entry_price")s.entry_price=StringToDouble(v);
   else if(k=="sl_price")s.sl_price=StringToDouble(v);
   else if(k=="tp_price")s.tp_price=StringToDouble(v);
   else if(k=="risk_points")s.risk_points=StringToDouble(v);
   else if(k=="intended_rr")s.intended_rr=StringToDouble(v);
   else if(k=="obstacle_distance_r")s.obstacle_distance_r=StringToDouble(v);
   else if(k=="wave1_room_price")s.wave1_room_price=StringToDouble(v);
   else if(k=="wave1_room_r")s.wave1_room_r=StringToDouble(v);
   else if(k=="wave1_room_rejected")s.wave1_room_rejected=v=="1" || v=="true";
   else if(k=="fib_close_bar_time")s.fib_close_bar_time=StringToTime(v);
   else if(k=="fib_close_at")s.fib_close_at=StringToTime(v);
   else if(k=="fib_close_known_at")s.fib_close_known_at=StringToTime(v);
   else if(k=="fib_close_price")s.fib_close_price=StringToDouble(v);
   else if(k=="fib_close_ratio")s.fib_close_ratio=StringToDouble(v);
   else if(k=="nearest_obstacle_price")s.nearest_obstacle_price=StringToDouble(v);
   else if(k=="nearest_obstacle_tf")s.nearest_obstacle_tf=TF(v);
   else if(k=="nearest_obstacle_time")s.nearest_obstacle_time=StringToTime(v);
   else if(k=="nearest_obstacle_known_at")s.nearest_obstacle_known_at=StringToTime(v);
   else if(k=="nearest_obstacle_source")s.nearest_obstacle_source=v;
   else if(k=="nearest_obstacle_is_high")s.nearest_obstacle_is_high=v=="1" || v=="true";
   else if(k=="h1_direction")s.h1_direction=v;
   else if(k=="lower_pivot_times")s.lower_pivot_times=v;
   else if(k=="lower_pivot_prices")s.lower_pivot_prices=v;
  }
void PivotFields(W33Setup &s)
  {
   // Decode after the entire row, so direction/column order cannot swap the
   // SIMPLE extreme|reaction anchors. No first high/low is invented.
   string t[],p[];int nt=StringSplit(s.lower_pivot_times,'|',t),np=StringSplit(s.lower_pivot_prices,'|',p);
   if(nt==4){s.lower_high1_time=(datetime)StringToInteger(t[0]);s.lower_high2_time=(datetime)StringToInteger(t[1]);s.lower_low1_time=(datetime)StringToInteger(t[2]);s.lower_low2_time=(datetime)StringToInteger(t[3]);}
   else if(nt==2)
     {
      if(s.direction>0){s.lower_low2_time=(datetime)StringToInteger(t[0]);s.lower_high2_time=(datetime)StringToInteger(t[1]);}
      else {s.lower_high2_time=(datetime)StringToInteger(t[0]);s.lower_low2_time=(datetime)StringToInteger(t[1]);}
     }
   if(np==4){s.lower_high1_price=StringToDouble(p[0]);s.lower_high2_price=StringToDouble(p[1]);s.lower_low1_price=StringToDouble(p[2]);s.lower_low2_price=StringToDouble(p[3]);}
   else if(np==2)
     {
      if(s.direction>0){s.lower_low2_price=StringToDouble(p[0]);s.lower_high2_price=StringToDouble(p[1]);}
      else {s.lower_high2_price=StringToDouble(p[0]);s.lower_low2_price=StringToDouble(p[1]);}
     }
  }
bool Load()
  {
   int f=FileOpen(InpFixtureFile,FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON,';',CP_UTF8);if(f==INVALID_HANDLE)return false;
   string keys[];while(!FileIsLineEnding(f)&&!FileIsEnding(f)){int n=ArraySize(keys);ArrayResize(keys,n+1);keys[n]=FileReadString(f);}
   bool hasRoomR=false;for(int i=0;i<ArraySize(keys);i++)if(keys[i]=="wave1_room_r")hasRoomR=true;
   while(!FileIsEnding(f))
     {
      ReviewRow row;ZeroMemory(row);
      for(int j=0;j<ArraySize(keys);j++)
        {
         string v=FileReadString(f),k=keys[j];
         if(k=="review_index")row.index=(int)StringToInteger(v);else if(k=="review_id")row.id=v;else if(k=="review_cutoff")row.cutoff=StringToTime(v);
         else if(k=="event_at")row.event.at=StringToTime(v);else if(k=="event_type")row.event.event_type=v;
         else if(k=="reason_kind")row.event.reason_kind=v;else if(k=="reason")row.event.reason=v;
         else if(k=="observed_pivot_time")row.event.pivot.time=StringToTime(v);
         else if(k=="observed_pivot_known_at")row.event.pivot.known_at=StringToTime(v);
         else if(k=="observed_pivot_price")row.event.pivot.price=StringToDouble(v);
         else if(k=="observed_pivot_tf")row.event.pivot.tf=TF(v);
         else if(k=="observed_pivot_label"){row.event.has_pivot=v!="";row.event.pivot.label=v;row.event.pivot.is_high=v=="H"||v=="HH"||v=="LH";}
         else Field(row.event.setup,k,v);
        }
      PivotFields(row.event.setup);
      // Display arithmetic for old CSVs only; a real v1.40 zero is preserved.
      // This replay cannot change strategy decisions or create orders.
      if(!hasRoomR && row.event.setup.entry_price>0 && row.event.setup.sl_price>0 && row.event.setup.wave1_peak_price>0)
        {
         double risk=MathAbs(row.event.setup.entry_price-row.event.setup.sl_price);
         if(risk>0)row.event.setup.wave1_room_r=row.event.setup.direction*(row.event.setup.wave1_peak_price-row.event.setup.entry_price)/risk;
        }
      if(row.event.at<=0)continue;
      int n=ArraySize(rows);ArrayResize(rows,n+1);rows[n]=row;
     }
   FileClose(f);return ArraySize(rows)>0;
  }
void Inventory()
  {
   string file=InpRenderTag+"_case"+IntegerToString(current)+"_objects.csv";
   int f=FileOpen(file,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,';',CP_UTF8);if(f==INVALID_HANDLE)return;
   FileWrite(f,"name","type","time1","price1","time2","price2","color","text","style","width","ray_right","ray_left","tooltip");
   for(int i=0;i<ObjectsTotal(0);i++)
     {
      string n=ObjectName(0,i);if(StringFind(n,"W33R_")!=0)continue;
      FileWrite(f,n,EnumToString((ENUM_OBJECT)ObjectGetInteger(0,n,OBJPROP_TYPE)),TimeToString((datetime)ObjectGetInteger(0,n,OBJPROP_TIME,0),TIME_DATE|TIME_SECONDS),ObjectGetDouble(0,n,OBJPROP_PRICE,0),TimeToString((datetime)ObjectGetInteger(0,n,OBJPROP_TIME,1),TIME_DATE|TIME_SECONDS),ObjectGetDouble(0,n,OBJPROP_PRICE,1),ObjectGetInteger(0,n,OBJPROP_COLOR),ObjectGetString(0,n,OBJPROP_TEXT),ObjectGetInteger(0,n,OBJPROP_STYLE),ObjectGetInteger(0,n,OBJPROP_WIDTH),ObjectGetInteger(0,n,OBJPROP_RAY_RIGHT),ObjectGetInteger(0,n,OBJPROP_RAY_LEFT),ObjectGetString(0,n,OBJPROP_TOOLTIP));
     }
   FileClose(f);
  }
int OnInit()
  {
   if(MQLInfoInteger(MQL_TESTER) || !Load())return INIT_FAILED;
   current=InpStartCase;
   resultFile=FileOpen(InpRenderTag+"_render.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,';',CP_UTF8);
   if(resultFile==INVALID_HANDLE)return INIT_FAILED;
   FileWrite(resultFile,"case","setup_id","cutoff","kind","objects","chart_bar_shift","image","saved");FileFlush(resultFile);
   ChartSetInteger(0,CHART_AUTOSCROLL,false);ChartSetInteger(0,CHART_SHOW_GRID,false);ChartSetInteger(0,CHART_MODE,CHART_CANDLES);
   ChartSetInteger(0,CHART_SHIFT,true);ChartSetDouble(0,CHART_SHIFT_SIZE,25.0);ChartSetInteger(0,CHART_SCALE,1);
   ChartSetInteger(0,CHART_COLOR_BACKGROUND,clrBlack);ChartSetInteger(0,CHART_COLOR_FOREGROUND,clrWhite);
   EventSetTimer(1);return INIT_SUCCEEDED;
  }
void OnTick(){}
void OnTimer()
  {
   if(phase==0)
     {
      if(InpSingleCase && current>InpStartCase){EventKillTimer();FileClose(resultFile);resultFile=INVALID_HANDLE;if(InpCloseWhenDone)TerminalClose(0);return;}
      bool found=false;ZeroMemory(snapshot);
      for(int i=0;i<ArraySize(rows);i++)if(rows[i].index==current){found=true;cutoff=rows[i].cutoff;if(rows[i].event.setup.setup_id!="")snapshot=rows[i].event.setup;}
      if(!found){EventKillTimer();FileClose(resultFile);resultFile=INVALID_HANDLE;if(InpCloseWhenDone)TerminalClose(0);else ExpertRemove();return;}
      datetime from=cutoff-86400;
      if(snapshot.wave1_start_time>0)from=(datetime)MathMin((long)from,(long)snapshot.wave1_start_time-14400);
      MqlRates history[];
      if(InpPrepareCustom)
        {
         int copied=CopyRates(InpSourceSymbol,PERIOD_M1,from,cutoff-1,history);
         if(copied<1&&tries++<30)return;
         string custom=InpSymbolPrefix+"_"+IntegerToString(current);
         bool created=CustomSymbolCreate(custom,"Wave33RecordedReview",InpSourceSymbol);
         if(!created&&!SymbolInfoInteger(custom,SYMBOL_CUSTOM)){Print("Custom symbol preparation failed ",custom);TerminalClose(1);return;}
         int updated=CustomRatesReplace(custom,from,cutoff-1,history);
         bool selected=SymbolSelect(custom,true);
         Print("DRAW_ONLY custom ",custom," bars=",copied," updated=",updated," selected=",selected," last=",TimeToString(cutoff));
         FileWrite(resultFile,current,snapshot.setup_id,TimeToString(cutoff,TIME_DATE|TIME_SECONDS),"CUSTOM_SYMBOL_PREPARATION_NO_FUTURE_BARS",updated,0,custom,updated>0?1:0);FileFlush(resultFile);
         current++;tries=0;return;
        }
      int copied=CopyRates(_Symbol,(ENUM_TIMEFRAMES)_Period,from,cutoff-1,history);
      int shift=iBarShift(_Symbol,(ENUM_TIMEFRAMES)_Period,cutoff,false);
      if((copied<1||shift<0)&&tries++<30)return;
      if(current>0)display.Clear();display.Init("W33R_"+W33Hash(InpRenderTag)+"_",true);display.SetFrames(snapshot.upper_tf,snapshot.lower_tf);
      display.ConfigureVisuals(InpShowPanel,InpDiagnosticLabels,InpSwingPaths);
      display.SetTriggerMode(snapshot.trigger_type=="TRENDLINE_BREAK"?W33_TRENDLINE_BREAK:W33_PIVOT_BREAK);
      // Fit W1 through the decision into the available chart width.
      int focus_bars=1+(int)((cutoff-snapshot.wave1_start_time)/PeriodSeconds((ENUM_TIMEFRAMES)_Period));
      double room=ChartGetInteger(0,CHART_WIDTH_IN_PIXELS)*0.70/MathMax(20,focus_bars);
      int scale=0;double bar_pixels=1;
      while(scale<5 && bar_pixels*2<=room){scale++;bar_pixels*=2;}
      ChartSetInteger(0,CHART_SCALE,scale);
      for(int i=0;i<ArraySize(rows);i++)if(rows[i].index==current)display.Event(rows[i].event);
      display.Panel("RECORDED EVENT DRAWING REPLAY - NORMAL MT5 CHART\nNot a tester screenshot; no trading or signal recalculation\n"+snapshot.setup_id+"\nKnown through "+TimeToString(cutoff,TIME_DATE|TIME_SECONDS)+"\nW1 "+DoubleToString(snapshot.wave1_start_price,_Digits)+" -> "+DoubleToString(snapshot.wave1_peak_price,_Digits)+"\nDeepest Fib "+DoubleToString(snapshot.retracement_ratio*100,1)+"% | "+snapshot.trigger_type+"\nENTRY "+DoubleToString(snapshot.entry_price,_Digits)+" SL "+DoubleToString(snapshot.sl_price,_Digits)+" TP "+DoubleToString(snapshot.tp_price,_Digits));
      if(shift>=0){bool nav=ChartNavigate(0,CHART_END,-shift);if(!nav)Print("Replay navigate failed ",GetLastError());}
      double lo=DBL_MAX,hi=0;
      IncludePrice(snapshot.wave1_start_price,lo,hi);IncludePrice(snapshot.wave1_peak_price,lo,hi);
      IncludePrice(snapshot.wave2_extreme_price,lo,hi);IncludePrice(snapshot.upper_break_level,lo,hi);
      IncludePrice(snapshot.entry_price,lo,hi);IncludePrice(snapshot.sl_price,lo,hi);IncludePrice(snapshot.tp_price,lo,hi);
      IncludePrice(snapshot.first_progress_price,lo,hi);
      IncludePrice(snapshot.nearest_obstacle_price,lo,hi);
      if(hi>lo){double pad=(hi-lo)*0.08;ChartSetInteger(0,CHART_SCALEFIX,true);ChartSetDouble(0,CHART_FIXED_MIN,lo-pad);ChartSetDouble(0,CHART_FIXED_MAX,hi+pad);}
      ChartRedraw();phase=1;tries=0;return;
     }
   if(phase==1)
     {
      png="W33R_"+W33Hash(InpRenderTag)+"_"+IntegerToString(current)+".png";
      bool ok=ChartScreenShot(0,png,1600,1000,ALIGN_RIGHT);
      Print("Replay capture request ",ok," ",png);phase=2;return;
     }
   bool saved=false;
   if(FileIsExist(png))saved=FileMove(png,0,png,FILE_COMMON|FILE_REWRITE);
   if(!saved&&tries++<10)return;
   Inventory();int shift=iBarShift(_Symbol,(ENUM_TIMEFRAMES)_Period,cutoff,false);
   FileWrite(resultFile,current,snapshot.setup_id,TimeToString(cutoff,TIME_DATE|TIME_SECONDS),"NORMAL_CHART_RECORDED_EVENT_REPLAY",ObjectsTotal(0),shift,png,saved?1:0);FileFlush(resultFile);
   current++;phase=0;tries=0;
  }
void OnDeinit(const int reason){EventKillTimer();if(resultFile!=INVALID_HANDLE)FileClose(resultFile);}
