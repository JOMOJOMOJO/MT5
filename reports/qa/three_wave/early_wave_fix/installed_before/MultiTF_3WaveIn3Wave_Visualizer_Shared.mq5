#property strict
#property version   "1.06"
#property description "Visual validator for M5 Wave1->Wave2 and M1 Wave1->Wave2->Wave3 long setups, with M1 invalidation/reset. No trading."
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_type1   DRAW_NONE
#property indicator_label1 "ReadyCount"
#property indicator_type2 DRAW_NONE
#property indicator_label2 "ReadySetupDigest"

#include "../Include/ThreeWaveInputs.mqh"
#include "../Include/ThreeWaveStructure.mqh"
string g_prefix="W33_SHARED_";
datetime g_last_lower_bar=0;
string g_status="";
double g_dummy[],g_digest[];
bool g_force_rebuild=true;
#include "../Include/ThreeWaveDrawing.mqh"

void Rebuild()
{
   DeleteOurObjects();
   ArrayInitialize(g_dummy,0); ArrayInitialize(g_digest,0);
   ArrayResize(tw_events,0); tw_trace_from=iTime(_Symbol,InpLowerTF,0);

   MqlRates lower[],higher[];
   ArraySetAsSeries(lower,false);
   ArraySetAsSeries(higher,false);

   int lc=CopyRates(_Symbol,InpLowerTF,0,InpHistoryLowerBars,lower);
   int hc=CopyRates(_Symbol,InpHigherTF,0,InpHistoryHigherBars,higher);
   if(lc<100 || hc<100)
   {
      g_status="3x3 Visualizer: data not ready";
      return;
   }

   PivotPoint lp[],hp[];
   BuildPivots(lower,InpLowerTF,InpLowerLeftBars,InpLowerRightBars,lp);
   BuildPivots(higher,InpHigherTF,InpHigherLeftBars,InpHigherRightBars,hp);
   AlignHigherPivotPlotTimes(hp,lower);

   M5Setup setups[];
   BuildHigherSetups(higher,hp,setups);
   DrawHigherPivots(hp);
   DrawLowerPivots(lp);

   int total=ArraySize(setups);
   int first=MathMax(0,total-InpMaxDrawSetups);
   int readyCount=0,chochCount=0;
   string latest="No M5 setup";

   for(int i=0;i<total;i++)
   {
      M1Pattern p;
      AnalyzeLowerPattern(lower,lp,setups[i],p);
      if(i>=first) DrawSetup(setups[i],p,i);
      if(p.ready)
      {
         int shift=iBarShift(_Symbol,_Period,p.ready_time,true);
         if(shift>=0 && shift<ArraySize(g_dummy))
         { g_dummy[shift]+=1; g_digest[shift]+=(double)setups[i].break_time; }
      }
      if(p.found_choch) chochCount++;
      if(p.ready) readyCount++;

      if(i==total-1)
      {
         latest="Latest M5 break: "+TimeToString(setups[i].break_time,TIME_DATE|TIME_MINUTES);
         if(!p.found_choch) latest+=" | M1: waiting downtrend -> CHoCH";
         else if(!p.found_wave1_high) latest+=" | M1: CHoCH, waiting Wave1 high";
         else if(!p.found_hl) latest+=" | M1: waiting HL / Wave2";
         else if(!p.ready) latest+=" | M1: HL confirmed, waiting upside break";
         else latest+=" | 3x3 READY "+TimeToString(p.ready_time,TIME_DATE|TIME_MINUTES);
      }
   }

   g_status="3x3 Visualizer (NO TRADING)\n"
            "bars M1="+IntegerToString(lc)+" M5="+IntegerToString(hc)+
            " | pivots M1="+IntegerToString(ArraySize(lp))+" M5="+IntegerToString(ArraySize(hp))+"\n"
            "Higher="+EnumToString(InpHigherTF)+"  Lower="+EnumToString(InpLowerTF)+"\n"
            "M5 setups="+IntegerToString(total)+"  shown="+IntegerToString(total-first)+
            "  M1 CHoCH="+IntegerToString(chochCount)+"  READY="+IntegerToString(readyCount)+"\n"+latest+
            "\nDiagnosticMode="+(InpDiagnosticMode ? "ON" : "OFF")+
            " | Fib is a zone/filter only; NOT entry.";
   if(InpDiagnosticMode) Print("3x3 Visualizer rebuild: M1 bars=",lc," M5 bars=",hc," M1 pivots=",ArraySize(lp)," M5 pivots=",ArraySize(hp)," setups=",total," READY=",readyCount);
   ChartRedraw();
   g_force_rebuild=false;
}

int OnInit()
{
   if(InpLowerTF>=InpHigherTF ||
      InpLowerLeftBars<1 || InpLowerRightBars<1 || InpHigherLeftBars<1 || InpHigherRightBars<1 ||
      InpHistoryLowerBars<500 || InpHistoryHigherBars<200 || InpMaxSetupMinutes<30 ||
      InpFibZoneLow<=0.0 || InpFibZoneHigh>=1.0 || InpFibZoneLow>=InpFibZoneHigh ||
      InpMaxDrawSetups<1)
      return INIT_PARAMETERS_INCORRECT;

   IndicatorSetString(INDICATOR_SHORTNAME,"3Wave-in-3Wave Shared v1.06");
   SetIndexBuffer(0,g_dummy,INDICATOR_DATA);
   SetIndexBuffer(1,g_digest,INDICATOR_DATA);
   ArraySetAsSeries(g_digest,true);
   ArraySetAsSeries(g_dummy,true);
   PlotIndexSetInteger(0,PLOT_DRAW_TYPE,DRAW_NONE);

   g_last_lower_bar=0;
   g_force_rebuild=true;
   EventSetTimer(2);

   // OnInit can run before all history is synchronized. Rebuild once now;
   // OnTimer retries automatically if data was not ready yet.
   Rebuild();
   return INIT_SUCCEEDED;
}

void OnTimer()
{
   datetime current=iTime(_Symbol,InpLowerTF,0);
   if(g_force_rebuild || current<=0 || current!=g_last_lower_bar)
   {
      if(current>0) g_last_lower_bar=current;
      Rebuild();
   }
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total>0) { g_dummy[0]=0.0; g_digest[0]=0.0; }

   datetime current=iTime(_Symbol,InpLowerTF,0);
   if(g_force_rebuild || (current>0 && current!=g_last_lower_bar))
   {
      if(current>0) g_last_lower_bar=current;
      Rebuild();
   }
   return rates_total;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   DeleteOurObjects();
}
