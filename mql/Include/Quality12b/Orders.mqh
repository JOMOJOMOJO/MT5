// QUALITY12B_MODULE_BEGIN Orders
#ifndef QUALITY12B_ORDERS_MQH
#define QUALITY12B_ORDERS_MQH
bool OpenPosition(SignalBucket bucket)
  {
   double stopLossPips = InpStopLossPips;
   double targetRMultiple = InpTargetRMultiple;
   string comment = BucketComment(bucket);
   bool isSell = BucketIsSell(bucket);
   if(bucket == SIGNAL_ROUND_SHORT)
     {
      stopLossPips = InpRoundShortStopLossPips;
      targetRMultiple = InpRoundShortTargetRMultiple;
     }
   if(bucket == SIGNAL_EMA)
     {
      stopLossPips = InpEmaStopLossPips;
      targetRMultiple = InpEmaTargetRMultiple;
     }
   else if(bucket == SIGNAL_COMPRESSION)
     {
      stopLossPips = InpCompressionStopLossPips;
      targetRMultiple = InpCompressionTargetRMultiple;
     }
   else if(bucket == SIGNAL_RSI)
     {
      stopLossPips = InpRsiStopLossPips;
      targetRMultiple = InpRsiTargetRMultiple;
     }
   else if(bucket == SIGNAL_ROUND_LOOSE)
     {
      stopLossPips = InpRoundLooseStopLossPips;
      targetRMultiple = InpRoundLooseTargetRMultiple;
     }
   else if(bucket == SIGNAL_BREAKOUT)
     {
      stopLossPips = InpBreakoutStopLossPips;
      targetRMultiple = InpBreakoutTargetRMultiple;
     }
   else if(bucket == SIGNAL_RANGE_RECLAIM)
     {
      stopLossPips = 0.0;
      targetRMultiple = 0.0;
     }
   else if(bucket == SIGNAL_FRACTAL_TREND)
     {
      stopLossPips = 0.0;
      targetRMultiple = 0.0;
     }

   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   double pip = GetPipSize();
   double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   int stopsLevel = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   double entryPrice = isSell ? bid : ask;
   if(entryPrice <= 0.0 || pip <= 0.0 || point <= 0.0)
      return false;
   double stopDistance = stopLossPips * pip;
   double targetDistance = stopDistance * targetRMultiple;
   double sl = NormalizePrice(isSell ? entryPrice + stopDistance : entryPrice - stopDistance);
   double tp = NormalizePrice(isSell ? entryPrice - targetDistance : entryPrice + targetDistance);
   if(bucket == SIGNAL_DOW_SWEEP)
     {
      if(dowPlannedStopPrice <= 0.0 || dowPlannedTargetPrice <= 0.0)
         return false;
      sl = dowPlannedStopPrice;
      tp = dowPlannedTargetPrice;
      stopDistance = entryPrice - sl;
      targetDistance = tp - entryPrice;
     }
   else if(bucket == SIGNAL_RANGE_RECLAIM)
     {
      if(rangePlannedStopPrice <= 0.0 || rangePlannedTargetPrice <= 0.0)
         return false;
      sl = rangePlannedStopPrice;
      tp = rangePlannedTargetPrice;
      stopDistance = entryPrice - sl;
      targetDistance = tp - entryPrice;
     }
   else if(bucket == SIGNAL_RANGE_RECLAIM_SHORT)
     {
      if(rangeShortPlannedStopPrice <= 0.0 || rangeShortPlannedTargetPrice <= 0.0)
         return false;
      sl = rangeShortPlannedStopPrice;
      tp = rangeShortPlannedTargetPrice;
      stopDistance = sl - entryPrice;
      targetDistance = entryPrice - tp;
     }
   else if(bucket == SIGNAL_FRACTAL_TREND)
     {
      if(fractalPlannedStopPrice <= 0.0 || fractalPlannedTargetPrice <= 0.0)
         return false;
      sl = fractalPlannedStopPrice;
      tp = fractalPlannedTargetPrice;
      stopDistance = entryPrice - sl;
      targetDistance = tp - entryPrice;
     }
   if(isSell)
     {
      stopDistance = sl - entryPrice;
      targetDistance = entryPrice - tp;
     }
   if(stopDistance < stopsLevel * point)
      return false;
   if(targetDistance > 0.0 && targetDistance < stopsLevel * point)
      return false;

   double volume = CalculateVolume(stopDistance);
   if(volume <= 0.0)
      return false;
   if(isSell)
      return trade.Sell(volume, runtimeSymbol, 0.0, sl, tp, comment);
   return trade.Buy(volume, runtimeSymbol, 0.0, sl, tp, comment);
  }

// QUALITY12B_MODULE_END Orders
#endif
