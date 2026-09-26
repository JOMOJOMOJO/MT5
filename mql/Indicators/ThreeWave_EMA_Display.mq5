#property strict
#property version "1.01"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots 3
#property indicator_label1 "EMA 20"
#property indicator_type1 DRAW_LINE
#property indicator_color1 clrDeepPink
#property indicator_width1 2
#property indicator_label2 "EMA 50"
#property indicator_type2 DRAW_LINE
#property indicator_color2 clrDodgerBlue
#property indicator_width2 2
#property indicator_label3 "EMA 100"
#property indicator_type3 DRAW_LINE
#property indicator_color3 clrMediumPurple
#property indicator_width3 2

input string InpInstance="Standalone";
input int InpFastPeriod=20;
input int InpMiddlePeriod=50;
input int InpSlowPeriod=100;
double ema_fast[],ema_middle[],ema_slow[];
int OnInit()
{
   if(InpFastPeriod<1 || InpMiddlePeriod<=InpFastPeriod || InpSlowPeriod<=InpMiddlePeriod || InpSlowPeriod>10000)
      return INIT_PARAMETERS_INCORRECT;
   SetIndexBuffer(0,ema_fast,INDICATOR_DATA);
   SetIndexBuffer(1,ema_middle,INDICATOR_DATA);
   SetIndexBuffer(2,ema_slow,INDICATOR_DATA);
   ArraySetAsSeries(ema_fast,false);
   ArraySetAsSeries(ema_middle,false);
   ArraySetAsSeries(ema_slow,false);
   PlotIndexSetInteger(0,PLOT_DRAW_BEGIN,InpFastPeriod-1);
   PlotIndexSetInteger(1,PLOT_DRAW_BEGIN,InpMiddlePeriod-1);
   PlotIndexSetInteger(2,PLOT_DRAW_BEGIN,InpSlowPeriod-1);
   PlotIndexSetString(0,PLOT_LABEL,"EMA "+IntegerToString(InpFastPeriod));
   PlotIndexSetString(1,PLOT_LABEL,"EMA "+IntegerToString(InpMiddlePeriod));
   PlotIndexSetString(2,PLOT_LABEL,"EMA "+IntegerToString(InpSlowPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
   IndicatorSetString(INDICATOR_SHORTNAME,"TW EMA "+IntegerToString(InpFastPeriod)+"/"+
                      IntegerToString(InpMiddlePeriod)+"/"+IntegerToString(InpSlowPeriod)+" ["+InpInstance+"]");
   return INIT_SUCCEEDED;
}
int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],
                const double &open[],const double &high[],const double &low[],
                const double &close[],const long &tick_volume[],const long &volume[],const int &spread[])
{
   if(rates_total<1) return 0;
   ArraySetAsSeries(close,false);
   int start=prev_calculated-1;
   if(prev_calculated<=0 || prev_calculated>rates_total)
   {
      ema_fast[0]=close[0]; ema_middle[0]=close[0]; ema_slow[0]=close[0];
      start=1;
   }
   for(int i=MathMax(1,start);i<rates_total;i++)
   {
      ema_fast[i]=ema_fast[i-1]+(2.0/(InpFastPeriod+1.0))*(close[i]-ema_fast[i-1]);
      ema_middle[i]=ema_middle[i-1]+(2.0/(InpMiddlePeriod+1.0))*(close[i]-ema_middle[i-1]);
      ema_slow[i]=ema_slow[i-1]+(2.0/(InpSlowPeriod+1.0))*(close[i]-ema_slow[i-1]);
   }
   return rates_total;
}
