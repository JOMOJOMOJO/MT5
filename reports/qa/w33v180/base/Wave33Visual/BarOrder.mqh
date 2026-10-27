#ifndef WAVE33_BAR_ORDER_MQH
#define WAVE33_BAR_ORDER_MQH
// A close known on the same tick must invalidate its upper setup before a
// lower-frame signal can execute, including batches after missing ticks.
void W33SortClosedBars(MqlRates &bars[],ENUM_TIMEFRAMES &periods[])
  {
   int n=ArraySize(bars);
   for(int i=0;i<n;i++)for(int j=i+1;j<n;j++)
     {
      datetime a=bars[i].time+PeriodSeconds(periods[i]),b=bars[j].time+PeriodSeconds(periods[j]);
      if(b<a || (b==a && PeriodSeconds(periods[j])>PeriodSeconds(periods[i])))
        {MqlRates tmp=bars[i];bars[i]=bars[j];bars[j]=tmp;ENUM_TIMEFRAMES tf=periods[i];periods[i]=periods[j];periods[j]=tf;}
     }
  }
#endif
