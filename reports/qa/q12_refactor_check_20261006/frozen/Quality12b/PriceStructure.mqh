// QUALITY12B_MODULE_BEGIN PriceStructure
#ifndef QUALITY12B_PRICESTRUCTURE_MQH
#define QUALITY12B_PRICESTRUCTURE_MQH
bool IsPivotHigh(const MqlRates &rates[], int shift, int span)
  {
   int size = ArraySize(rates);
   if(shift - span < 0 || shift + span >= size)
      return false;
   double center = rates[shift].high;
   for(int i = 1; i <= span; ++i)
     {
      if(center <= rates[shift - i].high || center < rates[shift + i].high)
         return false;
     }
   return true;
  }

bool IsPivotLow(const MqlRates &rates[], int shift, int span)
  {
   int size = ArraySize(rates);
   if(shift - span < 0 || shift + span >= size)
      return false;
   double center = rates[shift].low;
   for(int i = 1; i <= span; ++i)
     {
      if(center >= rates[shift - i].low || center > rates[shift + i].low)
         return false;
     }
   return true;
  }

void FindRecentPivotsWithSpan(const MqlRates &rates[], bool wantHigh, int span, int scanBars, PivotPoint &latest, PivotPoint &previous)
  {
   latest.valid = false;
   previous.valid = false;
   int size = ArraySize(rates);
   int maxShift = MathMin(size - 1 - span, scanBars);
   for(int shift = span + 1; shift <= maxShift; ++shift)
     {
      bool match = wantHigh ? IsPivotHigh(rates, shift, span) : IsPivotLow(rates, shift, span);
      if(!match)
         continue;
      PivotPoint point;
      point.valid = true;
      point.shift = shift;
      point.price = wantHigh ? rates[shift].high : rates[shift].low;
      point.time = rates[shift].time;
      if(!latest.valid)
         latest = point;
      else
        {
         previous = point;
         break;
        }
     }
  }

void FindRecentPivots(const MqlRates &rates[], bool wantHigh, PivotPoint &latest, PivotPoint &previous)
  {
   FindRecentPivotsWithSpan(rates, wantHigh, InpPivotSpan, InpTrendScanBars, latest, previous);
  }

double UpperWickShare(const MqlRates &bar)
  {
   double range = bar.high - bar.low;
   if(range <= 0.0)
      return 0.0;
   return (bar.high - MathMax(bar.open, bar.close)) / range;
  }

double LowerWickShare(const MqlRates &bar)
  {
   double range = bar.high - bar.low;
   if(range <= 0.0)
      return 0.0;
   return (MathMin(bar.open, bar.close) - bar.low) / range;
  }

double CloseLocation(const MqlRates &bar)
  {
   double range = bar.high - bar.low;
   if(range <= 0.0)
      return 0.5;
   return (bar.close - bar.low) / range;
  }

double BodyPips(const MqlRates &bar)
  {
   double pip = GetPipSize();
   if(pip <= 0.0)
      return 0.0;
   return MathAbs(bar.close - bar.open) / pip;
  }

double RangePips(const MqlRates &bar)
  {
   double pip = GetPipSize();
   if(pip <= 0.0)
      return 0.0;
   return (bar.high - bar.low) / pip;
  }

double FindBreakoutLevel(const MqlRates &bar, double stepPrice)
  {
   int startIndex = (int)MathFloor(bar.low / stepPrice) - 1;
   int endIndex = (int)MathCeil(bar.high / stepPrice) + 1;
   for(int idx = startIndex; idx <= endIndex; ++idx)
     {
      double level = idx * stepPrice;
      if(bar.open < level && bar.close > level)
         return level;
     }
   return 0.0;
  }

double RecentHighBreakPips(const MqlRates &rates[], int shift, int lookback)
  {
   double pip = GetPipSize();
   if(pip <= 0.0)
      return 0.0;
   double priorHigh = rates[shift + 1].high;
   for(int i = shift + 1; i <= shift + lookback; ++i)
      priorHigh = MathMax(priorHigh, rates[i].high);
   return (rates[shift].close - priorHigh) / pip;
  }

bool PassesVolatilityState(const MqlRates &rates[])
  {
   int size = ArraySize(rates);
   if(size <= InpVolatilityLookbackBars + 1)
      return false;
   double highest = rates[1].high;
   double lowest = rates[1].low;
   for(int shift = 1; shift <= InpVolatilityLookbackBars; ++shift)
     {
      highest = MathMax(highest, rates[shift].high);
      lowest = MathMin(lowest, rates[shift].low);
     }
   double pip = GetPipSize();
   if(pip <= 0.0 || (highest - lowest) / pip < InpMinWindowRangePips)
      return false;

   double zoneStep = InpRoundStepPips * pip;
   if(zoneStep <= 0.0)
      return false;
   return (long)MathFloor(highest / zoneStep) != (long)MathFloor(lowest / zoneStep);
  }

// QUALITY12B_MODULE_END PriceStructure
#endif
