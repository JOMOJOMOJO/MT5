// RELATIVE_CONTINUATION_MODULE_BEGIN MarketData
#ifndef RELATIVE_CONTINUATION_MARKETDATA_MQH
#define RELATIVE_CONTINUATION_MARKETDATA_MQH
bool LoadSignalWindow(MqlRates &rates[], double &fastEma[], double &slowEma[], double &adxValues[], double &rsiValues[], int count)
  {
   count=MathMax(count,MathMax(InpTrendScanBars+InpPivotSpan+3,
         MathMax(InpSlowSlopeLookback+3,MathMax(InpVolatilityLookbackBars+3,
         MathMax(InpBreakoutLookbackBars+InpBreakoutRetestDelayBars+5,
         MathMax(InpDowTrendScanBars+InpDowPivotSpan+3,
         MathMax(InpRangeLookbackBars+5,InpFractalScanBars+InpFractalPivotSpan+3)))))));
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(fastEma, true);
   ArraySetAsSeries(slowEma, true);
   ArraySetAsSeries(adxValues, true);
   ArraySetAsSeries(rsiValues, true);
   int copiedRates = CopyRates(runtimeSymbol, InpSignalTimeframe, 0, count, rates);
   if(copiedRates != count)
      return false;
   int copiedFast = CopyBuffer(fastEmaHandle, 0, 0, count, fastEma);
   int copiedSlow = CopyBuffer(slowEmaHandle, 0, 0, count, slowEma);
   int copiedAdx = CopyBuffer(adxHandle, 0, 0, count, adxValues);
   int copiedRsi = CopyBuffer(rsiHandle, 0, 0, count, rsiValues);
   return copiedFast == copiedRates && copiedSlow == copiedRates && copiedAdx == copiedRates && copiedRsi == copiedRates;
  }

bool LoadDowSignalWindow(MqlRates &rates[], double &fastEma[], double &slowEma[], int count)
  {
   count=MathMax(count,MathMax(InpTrendScanBars+InpPivotSpan+3,
         MathMax(InpSlowSlopeLookback+3,MathMax(InpVolatilityLookbackBars+3,
         MathMax(InpBreakoutLookbackBars+InpBreakoutRetestDelayBars+5,
         MathMax(InpDowTrendScanBars+InpDowPivotSpan+3,
         MathMax(InpRangeLookbackBars+5,InpFractalScanBars+InpFractalPivotSpan+3)))))));
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(fastEma, true);
   ArraySetAsSeries(slowEma, true);
   int copiedRates = CopyRates(runtimeSymbol, InpDowSignalTimeframe, 0, count, rates);
   if(copiedRates != count)
      return false;
   int copiedFast = CopyBuffer(dowFastEmaHandle, 0, 0, count, fastEma);
   int copiedSlow = CopyBuffer(dowSlowEmaHandle, 0, 0, count, slowEma);
   return copiedFast == copiedRates && copiedSlow == copiedRates;
  }

bool LoadRangeSignalWindow(MqlRates &rates[], double &fastEma[], double &slowEma[], double &adxValues[], double &atrValues[], int count)
  {
   count=MathMax(count,MathMax(InpTrendScanBars+InpPivotSpan+3,
         MathMax(InpSlowSlopeLookback+3,MathMax(InpVolatilityLookbackBars+3,
         MathMax(InpBreakoutLookbackBars+InpBreakoutRetestDelayBars+5,
         MathMax(InpDowTrendScanBars+InpDowPivotSpan+3,
         MathMax(InpRangeLookbackBars+5,InpFractalScanBars+InpFractalPivotSpan+3)))))));
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(fastEma, true);
   ArraySetAsSeries(slowEma, true);
   ArraySetAsSeries(adxValues, true);
   ArraySetAsSeries(atrValues, true);
   int copiedRates = CopyRates(runtimeSymbol, InpRangeSignalTimeframe, 0, count, rates);
   if(copiedRates != count)
      return false;
   int copiedFast = CopyBuffer(rangeFastEmaHandle, 0, 0, count, fastEma);
   int copiedSlow = CopyBuffer(rangeSlowEmaHandle, 0, 0, count, slowEma);
   int copiedAdx = CopyBuffer(rangeAdxHandle, 0, 0, count, adxValues);
   int copiedAtr = CopyBuffer(rangeAtrHandle, 0, 0, count, atrValues);
   return copiedFast == copiedRates && copiedSlow == copiedRates && copiedAdx == copiedRates && copiedAtr == copiedRates;
  }

bool LoadFractalSignalWindow(MqlRates &rates[], double &fastEma[], double &midEma[], double &slowEma[],
                             double &stochK[], double &stochD[], int count)
  {
   count=MathMax(count,MathMax(InpTrendScanBars+InpPivotSpan+3,
         MathMax(InpSlowSlopeLookback+3,MathMax(InpVolatilityLookbackBars+3,
         MathMax(InpBreakoutLookbackBars+InpBreakoutRetestDelayBars+5,
         MathMax(InpDowTrendScanBars+InpDowPivotSpan+3,
         MathMax(InpRangeLookbackBars+5,InpFractalScanBars+InpFractalPivotSpan+3)))))));
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(fastEma, true);
   ArraySetAsSeries(midEma, true);
   ArraySetAsSeries(slowEma, true);
   ArraySetAsSeries(stochK, true);
   ArraySetAsSeries(stochD, true);
   int copiedRates = CopyRates(runtimeSymbol, InpFractalSignalTimeframe, 0, count, rates);
   if(copiedRates != count)
      return false;
   int copiedFast = CopyBuffer(fractalFastEmaHandle, 0, 0, count, fastEma);
   int copiedMid = CopyBuffer(fractalMidEmaHandle, 0, 0, count, midEma);
   int copiedSlow = CopyBuffer(fractalSlowEmaHandle, 0, 0, count, slowEma);
   int copiedK = CopyBuffer(fractalStochHandle, 0, 0, count, stochK);
   int copiedD = CopyBuffer(fractalStochHandle, 1, 0, count, stochD);
   return copiedFast == copiedRates && copiedMid == copiedRates && copiedSlow == copiedRates &&
          copiedK == copiedRates && copiedD == copiedRates;
  }

// RELATIVE_CONTINUATION_MODULE_END MarketData
#endif
