// QUALITY12B_MODULE_BEGIN Signals
#ifndef QUALITY12B_SIGNALS_MQH
#define QUALITY12B_SIGNALS_MQH
bool EvaluateRoundSignal(const MqlRates &rates[], const double &fastEma[], const double &slowEma[])
  {
   if(!InpEnableRoundBucket)
      return false;
   if(!PassesVolatilityState(rates))
      return false;

   PivotPoint latestHigh, previousHigh, latestLow, previousLow;
   FindRecentPivots(rates, true, latestHigh, previousHigh);
   FindRecentPivots(rates, false, latestLow, previousLow);
   if(!latestHigh.valid || !previousHigh.valid || !latestLow.valid || !previousLow.valid)
      return false;

   double pip = GetPipSize();
   if(pip <= 0.0)
      return false;
   if(!(latestHigh.price > previousHigh.price && latestLow.price > previousLow.price))
      return false;
   if(fastEma[1] <= slowEma[1])
      return false;
   if(rates[1].close <= slowEma[1])
      return false;

   double slowSlopePips = (slowEma[1] - slowEma[1 + InpSlowSlopeLookback]) / pip;
   if(slowSlopePips < InpMinSlowSlopePips)
      return false;
   if(rates[1].low <= latestLow.price)
      return false;

   double emaDistancePips = MathAbs(rates[1].close - fastEma[1]) / pip;
   if(emaDistancePips > InpMaxEma13DistancePips)
      return false;
   if(UpperWickShare(rates[1]) < InpMinUpperWickShare)
      return false;
   if(LowerWickShare(rates[1]) > InpMaxLowerWickShare)
      return false;
   return true;
  }

bool EvaluateRoundShortSignal(const MqlRates &rates[], const double &fastEma[], const double &slowEma[])
  {
   if(!InpEnableRoundShortBucket)
      return false;
   if(!PassesVolatilityState(rates))
      return false;

   datetime barTime = rates[1].time;
   if(!IsWithinSession(barTime, InpRoundShortSessionStartHour, InpRoundShortSessionEndHour))
      return false;

   PivotPoint latestHigh, previousHigh, latestLow, previousLow;
   FindRecentPivots(rates, true, latestHigh, previousHigh);
   FindRecentPivots(rates, false, latestLow, previousLow);
   if(!latestHigh.valid || !previousHigh.valid || !latestLow.valid || !previousLow.valid)
      return false;

   double pip = GetPipSize();
   if(pip <= 0.0)
      return false;
   if(!(latestHigh.price < previousHigh.price && latestLow.price < previousLow.price))
      return false;
   if(fastEma[1] >= slowEma[1])
      return false;
   if(rates[1].close >= slowEma[1])
      return false;

   double slowSlopePips = (slowEma[1] - slowEma[1 + InpSlowSlopeLookback]) / pip;
   if(slowSlopePips > -InpRoundShortMinSlowSlopePips)
      return false;
   if(rates[1].high >= latestHigh.price)
      return false;

   double emaDistancePips = MathAbs(rates[1].close - fastEma[1]) / pip;
   if(emaDistancePips > InpRoundShortMaxEma13DistancePips)
      return false;
   if(LowerWickShare(rates[1]) < InpRoundShortMinLowerWickShare)
      return false;
   if(UpperWickShare(rates[1]) > InpRoundShortMaxUpperWickShare)
      return false;
   return true;
  }

bool EvaluateRoundLooseSignal(const MqlRates &rates[], const double &fastEma[], const double &slowEma[])
  {
   if(!InpEnableRoundLooseBucket)
      return false;
   if(!PassesVolatilityState(rates))
      return false;

   PivotPoint latestHigh, previousHigh, latestLow, previousLow;
   FindRecentPivots(rates, true, latestHigh, previousHigh);
   FindRecentPivots(rates, false, latestLow, previousLow);
   if(!latestHigh.valid || !previousHigh.valid || !latestLow.valid || !previousLow.valid)
      return false;

   double pip = GetPipSize();
   if(pip <= 0.0)
      return false;
   if(!(latestHigh.price > previousHigh.price && latestLow.price > previousLow.price))
      return false;
   if(fastEma[1] <= slowEma[1])
      return false;
   if(rates[1].close <= slowEma[1])
      return false;

   double slowSlopePips = (slowEma[1] - slowEma[1 + InpSlowSlopeLookback]) / pip;
   if(slowSlopePips < InpMinSlowSlopePips)
      return false;
   if(rates[1].low <= latestLow.price)
      return false;

   double emaDistancePips = MathAbs(rates[1].close - fastEma[1]) / pip;
   if(emaDistancePips <= InpMaxEma13DistancePips)
      return false;
   if(emaDistancePips > InpRoundLooseMaxEma13DistancePips)
      return false;
   if(UpperWickShare(rates[1]) < InpMinUpperWickShare)
      return false;
   if(LowerWickShare(rates[1]) > InpMaxLowerWickShare)
      return false;
   return true;
  }

bool EvaluateEmaSignal(const MqlRates &rates[], const double &fastEma[], const double &slowEma[], const double &adxValues[])
  {
   if(!InpEnableEmaBucket)
      return false;

   datetime barTime = rates[1].time;
   if(!IsWithinSession(barTime, InpEmaSessionStartHour, InpEmaSessionEndHour))
      return false;

   double pip = GetPipSize();
   if(pip <= 0.0)
      return false;
   if(fastEma[1] <= slowEma[1])
      return false;
   if(rates[1].close <= slowEma[1])
      return false;

   double slowSlopePips = (slowEma[1] - slowEma[1 + InpSlowSlopeLookback]) / pip;
   if(slowSlopePips < InpMinSlowSlopePips)
      return false;

   if(adxValues[1] <= 0.0 || adxValues[1] > InpEmaMaxAdx)
      return false;

   double emaDistancePips = MathAbs(rates[1].close - fastEma[1]) / pip;
   if(emaDistancePips > InpEmaMaxEma13DistancePips)
      return false;

   double ret1 = 0.0;
   if(rates[2].close > 0.0)
      ret1 = (rates[1].close - rates[2].close) / rates[2].close;
   if(ret1 > InpEmaMaxRet1)
      return false;

   if(UpperWickShare(rates[1]) < InpEmaMinUpperWickShare)
      return false;
   if(LowerWickShare(rates[1]) > InpEmaMaxLowerWickShare)
      return false;
   if(CloseLocation(rates[1]) > InpEmaMaxCloseLocation)
      return false;
   return true;
  }

bool EvaluateCompressionSignal(const MqlRates &rates[], const double &fastEma[], const double &slowEma[], const double &adxValues[])
  {
   if(!InpEnableCompressionBucket)
      return false;

   datetime barTime = rates[1].time;
   if(!IsWithinSession(barTime, InpCompressionSessionStartHour, InpCompressionSessionEndHour))
      return false;

   double pip = GetPipSize();
   if(pip <= 0.0)
      return false;
   if(fastEma[1] <= slowEma[1])
      return false;
   if(rates[1].close <= slowEma[1])
      return false;

   double slowSlopePips = (slowEma[1] - slowEma[1 + InpSlowSlopeLookback]) / pip;
   if(slowSlopePips < InpMinSlowSlopePips)
      return false;

   if(adxValues[1] <= 0.0 || adxValues[1] > InpCompressionMaxAdx)
      return false;

   double emaDistancePips = MathAbs(rates[1].close - fastEma[1]) / pip;
   if(emaDistancePips > InpCompressionMaxEma13DistancePips)
      return false;

   if(UpperWickShare(rates[1]) < InpCompressionMinUpperWickShare)
      return false;
   if(LowerWickShare(rates[1]) > InpCompressionMaxLowerWickShare)
      return false;
   return true;
  }

bool EvaluateRsiSignal(const MqlRates &rates[], const double &fastEma[], const double &slowEma[], const double &rsiValues[])
  {
   if(!InpEnableRsiBucket)
      return false;

   datetime barTime = rates[1].time;
   if(!IsWithinSession(barTime, InpRsiSessionStartHour, InpRsiSessionEndHour))
      return false;

   double pip = GetPipSize();
   if(pip <= 0.0)
      return false;
   if(fastEma[1] <= slowEma[1])
      return false;
   if(rates[1].close <= slowEma[1])
      return false;

   double slowSlopePips = (slowEma[1] - slowEma[1 + InpSlowSlopeLookback]) / pip;
   if(slowSlopePips < InpMinSlowSlopePips)
      return false;

   if(rsiValues[1] <= 0.0 || rsiValues[1] > InpRsiOversold)
      return false;

   double emaDistancePips = MathAbs(rates[1].close - fastEma[1]) / pip;
   if(emaDistancePips > InpRsiMaxEma13DistancePips)
      return false;

   if(rates[1].low > fastEma[1] + (InpRsiTouchBufferPips * pip))
      return false;
   if(rates[1].close <= rates[1].open)
      return false;
   if(rates[1].close <= rates[2].close)
      return false;
   if(CloseLocation(rates[1]) < InpRsiMinCloseLocation)
      return false;
   if(BodyPips(rates[1]) < InpRsiMinBodyPips)
      return false;
   if(LowerWickShare(rates[1]) > InpRsiMaxLowerWickShare)
      return false;

   return true;
  }

bool EvaluateBreakoutSignal(const MqlRates &rates[], const double &fastEma[], const double &slowEma[])
  {
   if(!InpEnableBreakoutBucket)
      return false;

   const int signalShift = 1;
   int breakoutShift = signalShift + InpBreakoutRetestDelayBars;
   if(breakoutShift + MathMax(InpSlowSlopeLookback, InpBreakoutLookbackBars) >= ArraySize(rates))
      return false;

   datetime barTime = rates[signalShift].time;
   if(!IsWithinSession(barTime, InpBreakoutSessionStartHour, InpBreakoutSessionEndHour))
      return false;

   double pip = GetPipSize();
   if(pip <= 0.0)
      return false;

   MqlRates breakout = rates[breakoutShift];
   MqlRates signalBar = rates[signalShift];
   double stepPrice = InpRoundStepPips * pip;
   double level = FindBreakoutLevel(breakout, stepPrice);
   if(level <= 0.0)
      return false;

   if(!(fastEma[breakoutShift] > slowEma[breakoutShift]))
      return false;
   if(!(breakout.close > slowEma[breakoutShift]))
      return false;
   if(!(slowEma[breakoutShift] > slowEma[breakoutShift + InpSlowSlopeLookback]))
      return false;
   if(RecentHighBreakPips(rates, breakoutShift, InpBreakoutLookbackBars) <= 0.0)
      return false;
   if(((breakout.close - fastEma[breakoutShift]) / pip) > InpBreakoutMaxToEma13Pips)
      return false;

   double breakoutBodyPips = BodyPips(breakout);
   double breakoutRangePips = RangePips(breakout);
   if(breakoutBodyPips < InpBreakoutMinBodyPips || breakoutRangePips <= 0.0)
      return false;
   if((breakoutBodyPips / breakoutRangePips) < InpBreakoutMinBodyToRange)
      return false;
   if(CloseLocation(breakout) < InpBreakoutMinCloseLocation)
      return false;

   double midpoint = level + (InpBreakoutMidpointDistancePips * pip);
   for(int shift = signalShift + 1; shift < breakoutShift; ++shift)
     {
      MqlRates followBar = rates[shift];
      if(followBar.high >= midpoint)
         return false;
      if(followBar.close < level)
         return false;
     }
   if(signalBar.high >= midpoint)
      return false;
   if(signalBar.close < level)
      return false;

   bool touchedEma = signalBar.low <= fastEma[signalShift] + (InpBreakoutTouchTolerancePips * pip);
   bool touchedLevel = signalBar.low <= level + (InpBreakoutRetestBufferPips * pip);
   if(!(touchedEma || touchedLevel))
      return false;
   double retestDepthPips = MathMax(0.0, (level - signalBar.low) / pip);
   if(retestDepthPips > InpBreakoutMaxRetestDepthPips)
      return false;
   if(CloseLocation(signalBar) < InpBreakoutMinRetestCloseLocation)
      return false;
   if(signalBar.close <= fastEma[signalShift])
      return false;
   if(signalBar.close <= level)
      return false;

   return true;
  }

bool EvaluateDowSweepSignal(const MqlRates &envRates[], const double &envFastEma[], const double &envSlowEma[],
                            const MqlRates &signalRates[], const double &signalFastEma[], const double &signalSlowEma[])
  {
   dowPlannedStopPrice = 0.0;
   dowPlannedTargetPrice = 0.0;
   if(!InpEnableDowSweepBucket)
      return false;

   datetime signalBarTime = signalRates[1].time;
   if(!IsWithinSession(signalBarTime, InpDowSessionStartHour, InpDowSessionEndHour))
      return false;

   if(!PassesVolatilityState(envRates))
      return false;

   PivotPoint envLatestHigh, envPreviousHigh, envLatestLow, envPreviousLow;
   FindRecentPivots(envRates, true, envLatestHigh, envPreviousHigh);
   FindRecentPivots(envRates, false, envLatestLow, envPreviousLow);
   if(!envLatestHigh.valid || !envPreviousHigh.valid || !envLatestLow.valid || !envPreviousLow.valid)
      return false;
   if(!(envLatestHigh.price > envPreviousHigh.price && envLatestLow.price > envPreviousLow.price))
      return false;
   if(envFastEma[1] <= envSlowEma[1])
      return false;
   if(envRates[1].close <= envSlowEma[1])
      return false;

   double pip = GetPipSize();
   if(pip <= 0.0)
      return false;

   PivotPoint signalLatestHigh, signalPreviousHigh, signalLatestLow, signalPreviousLow;
   FindRecentPivotsWithSpan(signalRates, true, InpDowPivotSpan, InpDowTrendScanBars, signalLatestHigh, signalPreviousHigh);
   FindRecentPivotsWithSpan(signalRates, false, InpDowPivotSpan, InpDowTrendScanBars, signalLatestLow, signalPreviousLow);
   if(!signalLatestHigh.valid || !signalLatestLow.valid)
      return false;
   if(!(signalLatestHigh.time < signalLatestLow.time))
      return false;

   double support = signalLatestLow.price;
   double priorHigh = signalLatestHigh.price;
   MqlRates signalBar = signalRates[1];
   double breachPips = (support - signalBar.low) / pip;
   if(breachPips < InpDowMinBreachPips || breachPips > InpDowMaxBreachPips)
      return false;
   if(signalBar.close <= support)
      return false;
   if(signalBar.close <= signalBar.open)
      return false;
   if(CloseLocation(signalBar) < InpDowMinCloseLocation)
      return false;
   if(LowerWickShare(signalBar) < InpDowMinLowerWickShare)
      return false;
   if(UpperWickShare(signalBar) > InpDowMaxUpperWickShare)
      return false;
   if(signalFastEma[1] <= signalSlowEma[1])
      return false;
   if(signalBar.close <= signalSlowEma[1])
      return false;

   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   double plannedStop = signalBar.low - (InpDowStopBufferPips * pip);
   double plannedTarget = priorHigh - (InpDowTargetBufferPips * pip);
   double stopDistance = ask - plannedStop;
   double targetDistance = plannedTarget - ask;
   if(stopDistance <= 0.0 || targetDistance <= 0.0)
      return false;
   if((targetDistance / stopDistance) < InpDowMinTargetRMultiple)
      return false;

   dowPlannedStopPrice = NormalizePrice(plannedStop);
   dowPlannedTargetPrice = NormalizePrice(plannedTarget);
   return true;
  }

bool EvaluateRangeReclaimSignal(const MqlRates &envRates[], const double &envFastEma[], const double &envSlowEma[],
                                const MqlRates &signalRates[], const double &signalFastEma[], const double &signalSlowEma[],
                                const double &signalAdx[], const double &signalAtr[])
  {
   rangePlannedStopPrice = 0.0;
   rangePlannedTargetPrice = 0.0;
   if(!InpEnableRangeReclaimBucket)
      return false;

   datetime signalBarTime = signalRates[1].time;
   if(!IsWithinSession(signalBarTime, InpRangeSessionStartHour, InpRangeSessionEndHour))
      return false;
   if(!PassesVolatilityState(envRates))
      return false;

   PivotPoint envLatestHigh, envPreviousHigh, envLatestLow, envPreviousLow;
   FindRecentPivots(envRates, true, envLatestHigh, envPreviousHigh);
   FindRecentPivots(envRates, false, envLatestLow, envPreviousLow);
   if(!envLatestHigh.valid || !envPreviousHigh.valid || !envLatestLow.valid || !envPreviousLow.valid)
      return false;
   if(!(envLatestHigh.price > envPreviousHigh.price && envLatestLow.price > envPreviousLow.price))
      return false;
   if(envFastEma[1] <= envSlowEma[1])
      return false;
   if(envRates[1].close <= envSlowEma[1])
      return false;

   double pip = GetPipSize();
   if(pip <= 0.0)
      return false;
   if(signalAdx[1] > InpRangeMaxAdx)
      return false;
   if(signalAtr[1] <= 0.0)
      return false;

   int size = ArraySize(signalRates);
   if(size <= InpRangeLookbackBars + 2)
      return false;

   double rangeHigh = -DBL_MAX;
   double rangeLow = DBL_MAX;
   for(int shift = 2; shift < 2 + InpRangeLookbackBars && shift < size; ++shift)
     {
      if(signalRates[shift].high > rangeHigh)
         rangeHigh = signalRates[shift].high;
      if(signalRates[shift].low < rangeLow)
         rangeLow = signalRates[shift].low;
     }
   if(rangeHigh <= rangeLow)
      return false;

   double rangeWidth = rangeHigh - rangeLow;
   if(rangeWidth > signalAtr[1] * InpRangeMaxWidthAtrMultiple)
      return false;

   MqlRates signalBar = signalRates[1];
   double breachPips = (rangeLow - signalBar.low) / pip;
   if(breachPips < InpRangeMinBreachPips || breachPips > InpRangeMaxBreachPips)
      return false;
   if(signalBar.close <= rangeLow)
      return false;
   if(signalBar.close <= signalBar.open)
      return false;
   if(CloseLocation(signalBar) < InpRangeMinCloseLocation)
      return false;
   if(LowerWickShare(signalBar) < InpRangeMinLowerWickShare)
      return false;
   if(UpperWickShare(signalBar) > InpRangeMaxUpperWickShare)
      return false;
   if(signalFastEma[1] <= signalSlowEma[1])
      return false;
   if(signalBar.close <= signalSlowEma[1])
      return false;

   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   double plannedStop = signalBar.low - (InpRangeStopBufferPips * pip);
   double plannedTarget = rangeHigh - (InpRangeTargetBufferPips * pip);
   double stopDistance = ask - plannedStop;
   double targetDistance = plannedTarget - ask;
   if(stopDistance <= 0.0 || targetDistance <= 0.0)
      return false;
   if((targetDistance / stopDistance) < InpRangeMinTargetRMultiple)
      return false;

   rangePlannedStopPrice = NormalizePrice(plannedStop);
   rangePlannedTargetPrice = NormalizePrice(plannedTarget);
   return true;
  }

bool EvaluateRangeReclaimShortSignal(const MqlRates &envRates[], const double &envFastEma[], const double &envSlowEma[],
                                     const MqlRates &signalRates[], const double &signalFastEma[], const double &signalSlowEma[],
                                     const double &signalAdx[], const double &signalAtr[])
  {
   rangeShortPlannedStopPrice = 0.0;
   rangeShortPlannedTargetPrice = 0.0;
   if(!InpEnableRangeShortBucket)
      return false;

   datetime signalBarTime = signalRates[1].time;
   if(!IsWithinSession(signalBarTime, InpRangeSessionStartHour, InpRangeSessionEndHour))
      return false;
   if(!PassesVolatilityState(envRates))
      return false;

   PivotPoint envLatestHigh, envPreviousHigh, envLatestLow, envPreviousLow;
   FindRecentPivots(envRates, true, envLatestHigh, envPreviousHigh);
   FindRecentPivots(envRates, false, envLatestLow, envPreviousLow);
   if(!envLatestHigh.valid || !envPreviousHigh.valid || !envLatestLow.valid || !envPreviousLow.valid)
      return false;
   if(!(envLatestHigh.price < envPreviousHigh.price && envLatestLow.price < envPreviousLow.price))
      return false;
   if(envFastEma[1] >= envSlowEma[1])
      return false;
   if(envRates[1].close >= envSlowEma[1])
      return false;

   double pip = GetPipSize();
   if(pip <= 0.0)
      return false;
   if(signalAdx[1] > InpRangeMaxAdx)
      return false;
   if(signalAtr[1] <= 0.0)
      return false;

   int size = ArraySize(signalRates);
   if(size <= InpRangeLookbackBars + 2)
      return false;

   double rangeHigh = -DBL_MAX;
   double rangeLow = DBL_MAX;
   for(int shift = 2; shift < 2 + InpRangeLookbackBars && shift < size; ++shift)
     {
      if(signalRates[shift].high > rangeHigh)
         rangeHigh = signalRates[shift].high;
      if(signalRates[shift].low < rangeLow)
         rangeLow = signalRates[shift].low;
     }
   if(rangeHigh <= rangeLow)
      return false;

   double rangeWidth = rangeHigh - rangeLow;
   if(rangeWidth > signalAtr[1] * InpRangeMaxWidthAtrMultiple)
      return false;

   MqlRates signalBar = signalRates[1];
   double breachPips = (signalBar.high - rangeHigh) / pip;
   if(breachPips < InpRangeMinBreachPips || breachPips > InpRangeMaxBreachPips)
      return false;
   if(signalBar.close >= rangeHigh)
      return false;
   if(signalBar.close >= signalBar.open)
      return false;
   if(CloseLocation(signalBar) > (1.0 - InpRangeMinCloseLocation))
      return false;
   if(UpperWickShare(signalBar) < InpRangeMinLowerWickShare)
      return false;
   if(LowerWickShare(signalBar) > InpRangeMaxUpperWickShare)
      return false;
   if(signalFastEma[1] >= signalSlowEma[1])
      return false;
   if(signalBar.close >= signalSlowEma[1])
      return false;

   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;

   double plannedStop = signalBar.high + (InpRangeStopBufferPips * pip);
   double plannedTarget = rangeLow + (InpRangeTargetBufferPips * pip);
   double stopDistance = plannedStop - bid;
   double targetDistance = bid - plannedTarget;
   if(stopDistance <= 0.0 || targetDistance <= 0.0)
      return false;
   if((targetDistance / stopDistance) < InpRangeMinTargetRMultiple)
      return false;

   rangeShortPlannedStopPrice = NormalizePrice(plannedStop);
   rangeShortPlannedTargetPrice = NormalizePrice(plannedTarget);
   return true;
  }

bool EvaluateFractalTrendSignal(const MqlRates &envRates[], const double &envFastEma[], const double &envSlowEma[],
                                const MqlRates &signalRates[], const double &signalFastEma[], const double &signalMidEma[],
                                const double &signalSlowEma[], const double &stochK[], const double &stochD[])
  {
   fractalPlannedStopPrice = 0.0;
   fractalPlannedTargetPrice = 0.0;
   if(!InpEnableFractalTrendBucket)
      return false;

   datetime signalBarTime = signalRates[1].time;
   if(!IsWithinSession(signalBarTime, InpFractalSessionStartHour, InpFractalSessionEndHour))
      return false;
   if(!PassesVolatilityState(envRates))
      return false;

   PivotPoint envLatestHigh, envPreviousHigh, envLatestLow, envPreviousLow;
   FindRecentPivots(envRates, true, envLatestHigh, envPreviousHigh);
   FindRecentPivots(envRates, false, envLatestLow, envPreviousLow);
   if(!envLatestHigh.valid || !envPreviousHigh.valid || !envLatestLow.valid || !envPreviousLow.valid)
      return false;
   if(!(envLatestHigh.price > envPreviousHigh.price && envLatestLow.price > envPreviousLow.price))
      return false;
   if(envFastEma[1] <= envSlowEma[1])
      return false;
   if(envRates[1].close <= envSlowEma[1])
      return false;

   PivotPoint signalLatestHigh, signalPreviousHigh, signalLatestLow, signalPreviousLow;
   FindRecentPivotsWithSpan(signalRates, true, InpFractalPivotSpan, InpFractalScanBars, signalLatestHigh, signalPreviousHigh);
   FindRecentPivotsWithSpan(signalRates, false, InpFractalPivotSpan, InpFractalScanBars, signalLatestLow, signalPreviousLow);
   if(!signalLatestHigh.valid || !signalLatestLow.valid)
      return false;
   if(!(signalLatestHigh.time < signalLatestLow.time))
      return false;

   double pip = GetPipSize();
   if(pip <= 0.0)
      return false;

   MqlRates signalBar = signalRates[1];
   if(signalFastEma[1] <= signalMidEma[1] || signalMidEma[1] <= signalSlowEma[1])
      return false;
   if(signalBar.close <= signalSlowEma[1])
      return false;
   if(signalBar.close <= signalBar.open)
      return false;
   if(signalBar.close <= signalRates[2].close)
      return false;

   bool betweenFastAndMid = (signalBar.close < signalFastEma[1] && signalBar.close > signalMidEma[1]);
   bool betweenMidAndSlow = (signalBar.close <= signalMidEma[1] && signalBar.close > signalSlowEma[1]);
   if(!(betweenFastAndMid || betweenMidAndSlow))
      return false;

   bool stochBuySignal = (stochK[2] < InpFractalStochBuyLevel &&
                          stochK[1] > stochK[2] &&
                          stochK[1] > InpFractalStochBuyLevel &&
                          stochK[1] >= stochD[1]);
   if(!stochBuySignal)
      return false;

   double priorHigh = signalLatestHigh.price;
   double stopAnchor = betweenFastAndMid ? signalMidEma[1] : signalSlowEma[1];
   stopAnchor = MathMin(stopAnchor, signalLatestLow.price);
   double plannedStop = stopAnchor - (InpFractalStopBufferPips * pip);

   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;
   double plannedTarget = priorHigh - (InpFractalTargetBufferPips * pip);
   double stopDistance = ask - plannedStop;
   double targetDistance = plannedTarget - ask;
   if(stopDistance <= 0.0 || targetDistance <= 0.0)
      return false;
   if((targetDistance / stopDistance) < InpFractalMinTargetRMultiple)
      return false;

   fractalPlannedStopPrice = NormalizePrice(plannedStop);
   fractalPlannedTargetPrice = NormalizePrice(plannedTarget);
   return true;
  }

// QUALITY12B_MODULE_END Signals
#endif
