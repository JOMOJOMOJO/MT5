#property copyright ""
#property version "1.00"
#property description "Confirmed lower/higher timeframe pivots; visualization only."
#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots 8

#include "../Include/SwingStructure/ConfirmedPivot.mqh"

input ENUM_TIMEFRAMES InpLowerTF=PERIOD_M1;
input ENUM_TIMEFRAMES InpHigherTF=PERIOD_M5;
input int InpLowerLeftBars=2;
input int InpLowerRightBars=2;
input int InpHigherLeftBars=2;
input int InpHigherRightBars=2;
input bool InpShowLowerSwings=true;
input bool InpShowHigherSwings=true;
input bool InpShowLowerLines=true;
input bool InpShowHigherLines=true;
input int InpInitialHistoryBars=5000; // Initial source bars per TF, including current
input bool InpShowDebug=true;
input int InpDebugTopPixels=20; // Change for multiple instances on one chart

double HigherHigh[],HigherLow[],LowerHigh[],LowerLow[];
double HigherHighConfirmed[],HigherLowConfirmed[],LowerHighConfirmed[],LowerLowConfirmed[];
SSPivot g_lower[],g_higher[];
datetime g_lower_processed=0,g_higher_processed=0;
datetime g_lower_open=0,g_higher_open=0,g_chart_open=0;
string g_prefix;
bool g_lower_ready=false,g_higher_ready=false;

string TFName(const ENUM_TIMEFRAMES tf)
{
   string name=EnumToString(tf);
   StringReplace(name,"PERIOD_","");
   return name;
}

string Stamp(const datetime t)
{
   return t==0 ? "-" : TimeToString(t,TIME_DATE|TIME_MINUTES);
}

bool Bind(const int index,double &buffer[],const string label)
{
   if(!SetIndexBuffer(index,buffer,INDICATOR_DATA)) return false;
   ArraySetAsSeries(buffer,true);
   PlotIndexSetInteger(index,PLOT_DRAW_TYPE,DRAW_NONE);
   PlotIndexSetDouble(index,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetString(index,PLOT_LABEL,label);
   // Timestamp buffers are available to CopyBuffer, omitted from the price window.
   PlotIndexSetInteger(index,PLOT_SHOW_DATA,index<4);
   return true;
}

int OnInit()
{
   if(_Period!=PERIOD_M1 || InpLowerTF==PERIOD_CURRENT || InpHigherTF==PERIOD_CURRENT ||
      PeriodSeconds(InpLowerTF)<60 || PeriodSeconds(InpHigherTF)<=PeriodSeconds(InpLowerTF) ||
      InpLowerLeftBars<1 || InpLowerRightBars<1 || InpHigherLeftBars<1 || InpHigherRightBars<1 ||
      InpLowerLeftBars>10000 || InpLowerRightBars>10000 ||
      InpHigherLeftBars>10000 || InpHigherRightBars>10000 ||
      InpInitialHistoryBars<MathMax(InpLowerLeftBars+InpLowerRightBars+2,
                                    InpHigherLeftBars+InpHigherRightBars+2) ||
      InpInitialHistoryBars>1000000 || InpDebugTopPixels<0)
   {
      Print("SwingStructure: use an M1 chart, explicit lower < higher TF, positive pivot windows and sufficient history limit.");
      return INIT_PARAMETERS_INCORRECT;
   }
   string h=TFName(InpHigherTF),l=TFName(InpLowerTF);
   if(!Bind(0,HigherHigh,h+" confirmed high") || !Bind(1,HigherLow,h+" confirmed low") ||
      !Bind(2,LowerHigh,l+" confirmed high") || !Bind(3,LowerLow,l+" confirmed low") ||
      !Bind(4,HigherHighConfirmed,h+" high confirmed time") ||
      !Bind(5,HigherLowConfirmed,h+" low confirmed time") ||
      !Bind(6,LowerHighConfirmed,l+" high confirmed time") ||
      !Bind(7,LowerLowConfirmed,l+" low confirmed time")) return INIT_FAILED;
   g_prefix="SSV_"+IntegerToString(ChartID())+"_"+IntegerToString((long)GetMicrosecondCount())+"_";
   // Reserve the namespace even if two instances report the same elapsed counter.
   while(ObjectFind(0,g_prefix+"owner")>=0) g_prefix+="x";
   if(!ObjectCreate(0,g_prefix+"owner",OBJ_LABEL,0,0,0)) return INIT_FAILED;
   ObjectSetString(0,g_prefix+"owner",OBJPROP_TEXT,"");
   ObjectSetInteger(0,g_prefix+"owner",OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,g_prefix+"owner",OBJPROP_SELECTABLE,false);
   IndicatorSetString(INDICATOR_SHORTNAME,"SwingStructure "+l+"/"+h);
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
   if(!EventSetTimer(1)) return INIT_FAILED;
   return INIT_SUCCEEDED;
}

string Tooltip(const SSPivot &p,const ENUM_TIMEFRAMES tf)
{
   return "pivot timeframe: "+TFName(tf)+"\npivot type: "+(p.high ? "HIGH" : "LOW")+
          "\npivot price: "+DoubleToString(p.price,_Digits)+
          "\npivot bar time: "+Stamp(p.bar_time)+"\nconfirmed time: "+Stamp(p.confirmed_time);
}

void DrawPivot(const SSPivot &p,const ENUM_TIMEFRAMES tf,const bool higher)
{
   const string name=g_prefix+(higher ? "H_" : "L_")+IntegerToString((long)p.bar_time)+(p.high ? "_high" : "_low");
   if(ObjectFind(0,name)>=0) return;
   if(!ObjectCreate(0,name,OBJ_ARROW,0,p.bar_time,p.price)) return;
   ObjectSetInteger(0,name,OBJPROP_ARROWCODE,p.high ? 234 : 233);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,p.high ? ANCHOR_BOTTOM : ANCHOR_TOP);
   ObjectSetInteger(0,name,OBJPROP_COLOR,higher ? (p.high ? clrOrange : clrAqua) : (p.high ? clrRed : clrBlue));
   ObjectSetInteger(0,name,OBJPROP_WIDTH,higher ? 4 : 1);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,Tooltip(p,tf));
}

void DrawNew(const SSPivot &pivots[],const int from,const ENUM_TIMEFRAMES tf,const bool higher)
{
   for(int i=from;i<ArraySize(pivots);i++)
   {
      if(higher ? InpShowHigherSwings : InpShowLowerSwings) DrawPivot(pivots[i],tf,higher);
      if(!(higher ? InpShowHigherLines : InpShowLowerLines) || i==0) continue;
      if(!SSCanConnect(pivots[i-1],pivots[i])) continue;
      const string name=g_prefix+(higher ? "HL_" : "LL_")+IntegerToString((long)pivots[i].bar_time);
      if(!ObjectCreate(0,name,OBJ_TREND,0,pivots[i-1].bar_time,pivots[i-1].price,
                       pivots[i].bar_time,pivots[i].price)) continue;
      ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);
      ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,higher ? 3 : 1);
      ObjectSetInteger(0,name,OBJPROP_COLOR,higher ? clrDarkOrange : clrSlateGray);
      ObjectSetInteger(0,name,OBJPROP_BACK,true);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetString(0,name,OBJPROP_TOOLTIP,TFName(tf)+" confirmed pivot segment\navailable: "+Stamp(pivots[i].confirmed_time));
   }
}

bool UpdateSource(const ENUM_TIMEFRAMES tf,const int left,const int right,
                  datetime &processed,datetime &seen_open,SSPivot &pivots[],const bool higher)
{
   const datetime current=iTime(_Symbol,tf,0);
   if(current==0) return false;
   if(current==seen_open) return true;
   int wanted=InpInitialHistoryBars;
   if(processed>0)
   {
      const int shift=iBarShift(_Symbol,tf,processed,true);
      if(shift<0) return false; // Wait rather than silently skip an unavailable interval.
      wanted=shift+left+1;
   }
   MqlRates rates[];
   ArraySetAsSeries(rates,false);
   const int copied=CopyRates(_Symbol,tf,0,wanted,rates);
   if(copied<left+right+2 || !SeriesInfoInteger(_Symbol,tf,SERIES_SYNCHRONIZED)) return false;
   if(rates[copied-1].time!=current) return false;
   if(processed>0 && copied<wanted) return false;
   const int before=ArraySize(pivots);
   SSCollect(rates,copied,left,right,processed,pivots);
   seen_open=current;
   DrawNew(pivots,before,tf,higher);
   return true;
}

void Fill(const SSPivot &pivots[],const datetime &times[],const int count,
          double &hi[],double &lo[],double &hi_time[],double &lo_time[])
{
   ArrayInitialize(hi,EMPTY_VALUE);
   ArrayInitialize(lo,EMPTY_VALUE);
   ArrayInitialize(hi_time,EMPTY_VALUE);
   ArrayInitialize(lo_time,EMPTY_VALUE);
   for(int i=0;i<ArraySize(pivots);i++)
   {
      const int shift=SSChartIndex(times,count,pivots[i].bar_time);
      if(shift<0) continue;
      if(pivots[i].high)
      {
         hi[shift]=pivots[i].price;
         hi_time[shift]=(double)pivots[i].confirmed_time;
      }
      else
      {
         lo[shift]=pivots[i].price;
         lo_time[shift]=(double)pivots[i].confirmed_time;
      }
   }
}

string Latest(const SSPivot &pivots[],const bool high)
{
   for(int i=ArraySize(pivots)-1;i>=0;i--)
      if(pivots[i].high==high)
         return Stamp(pivots[i].bar_time)+" / confirmed "+Stamp(pivots[i].confirmed_time);
   return "-";
}

void DebugRow(const int row,const string value)
{
   const string name=g_prefix+"debug_"+IntegerToString(row);
   if(ObjectFind(0,name)<0)
   {
      if(!ObjectCreate(0,name,OBJ_LABEL,0,0,0)) return;
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,10);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,InpDebugTopPixels+row*17);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   }
   ObjectSetInteger(0,name,OBJPROP_COLOR,ChartGetInteger(0,CHART_COLOR_FOREGROUND));
   ObjectSetString(0,name,OBJPROP_TEXT,value);
}

void ShowDebug()
{
   if(!InpShowDebug) return;
   const string l=TFName(InpLowerTF),h=TFName(InpHigherTF);
   DebugRow(0,"Lower TF: "+l+" | Higher TF: "+h);
   DebugRow(1,l+" swing count: "+IntegerToString(ArraySize(g_lower))+(g_lower_ready ? "" : " (waiting for data)"));
   DebugRow(2,h+" swing count: "+IntegerToString(ArraySize(g_higher))+(g_higher_ready ? "" : " (waiting for data)"));
   DebugRow(3,"Latest "+l+" high: "+Latest(g_lower,true));
   DebugRow(4,"Latest "+l+" low: "+Latest(g_lower,false));
   DebugRow(5,"Latest "+h+" high: "+Latest(g_higher,true));
   DebugRow(6,"Latest "+h+" low: "+Latest(g_higher,false));
}

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],
                const double &open[],const double &high[],const double &low[],const double &close[],
                const long &tick_volume[],const long &volume[],const int &spread[])
{
   if(rates_total<1) return 0;
   ArraySetAsSeries(time,true);
   const int before=ArraySize(g_lower)+ArraySize(g_higher);
   const bool was_ready=g_lower_ready && g_higher_ready;
   g_lower_ready=UpdateSource(InpLowerTF,InpLowerLeftBars,InpLowerRightBars,
                              g_lower_processed,g_lower_open,g_lower,false);
   g_higher_ready=UpdateSource(InpHigherTF,InpHigherLeftBars,InpHigherRightBars,
                               g_higher_processed,g_higher_open,g_higher,true);
   if(prev_calculated==0 || rates_total!=prev_calculated || time[0]!=g_chart_open ||
      before!=ArraySize(g_lower)+ArraySize(g_higher))
   {
      Fill(g_higher,time,rates_total,HigherHigh,HigherLow,HigherHighConfirmed,HigherLowConfirmed);
      Fill(g_lower,time,rates_total,LowerHigh,LowerLow,LowerHighConfirmed,LowerLowConfirmed);
      g_chart_open=time[0];
      ShowDebug();
   }
   else if(was_ready!=(g_lower_ready && g_higher_ready)) ShowDebug();
   return rates_total;
}

// CopyRates can initially return -1 while another timeframe is being built.
// Retry without requiring a market tick (weekends and offline charts included).
void OnTimer()
{
   if(g_lower_ready && g_higher_ready) return;
   const int count=ArraySize(HigherHigh);
   if(count<1) return;
   g_lower_ready=UpdateSource(InpLowerTF,InpLowerLeftBars,InpLowerRightBars,
                              g_lower_processed,g_lower_open,g_lower,false);
   g_higher_ready=UpdateSource(InpHigherTF,InpHigherLeftBars,InpHigherRightBars,
                               g_higher_processed,g_higher_open,g_higher,true);
   datetime times[];
   ArraySetAsSeries(times,true);
   if(CopyTime(_Symbol,PERIOD_M1,0,count,times)==count && times[0]==g_chart_open)
   {
      Fill(g_higher,times,count,HigherHigh,HigherLow,HigherHighConfirmed,HigherLowConfirmed);
      Fill(g_lower,times,count,LowerHigh,LowerLow,LowerHighConfirmed,LowerLowConfirmed);
   }
   ShowDebug();
   ChartRedraw();
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(g_prefix=="") return;
   // Enumerate and delete only this instance's namespace, never the whole chart.
   for(int i=ObjectsTotal(0)-1;i>=0;i--)
   {
      const string name=ObjectName(0,i);
      if(StringFind(name,g_prefix)==0) ObjectDelete(0,name);
   }
   ChartRedraw();
}
