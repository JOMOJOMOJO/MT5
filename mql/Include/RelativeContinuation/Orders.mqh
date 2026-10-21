// RELATIVE_CONTINUATION_MODULE_BEGIN Orders
#ifndef RELATIVE_CONTINUATION_ORDERS_MQH
#define RELATIVE_CONTINUATION_ORDERS_MQH
bool OpenPosition(SignalBucket bucket)
  {
   if(uncertainSend || HasPendingManagedOrder() || !IsSpreadAllowed()) return false;
   double stopLossAtr = InpStopLossAtr;
   double targetRMultiple = InpTargetRMultiple;
   string comment = BucketComment(bucket);
   bool isSell = BucketIsSell(bucket);
   if(bucket == SIGNAL_ROUND_SHORT)
     {
      stopLossAtr = InpRoundShortStopLossAtr;
      targetRMultiple = InpRoundShortTargetRMultiple;
     }
   if(bucket == SIGNAL_EMA)
     {
      stopLossAtr = InpEmaStopLossAtr;
      targetRMultiple = InpEmaTargetRMultiple;
     }
   else if(bucket == SIGNAL_COMPRESSION)
     {
      stopLossAtr = InpCompressionStopLossAtr;
      targetRMultiple = InpCompressionTargetRMultiple;
     }
   else if(bucket == SIGNAL_RSI)
     {
      stopLossAtr = InpRsiStopLossAtr;
      targetRMultiple = InpRsiTargetRMultiple;
     }
   else if(bucket == SIGNAL_ROUND_LOOSE)
     {
      stopLossAtr = InpRoundLooseStopLossAtr;
      targetRMultiple = InpRoundLooseTargetRMultiple;
     }
   else if(bucket == SIGNAL_BREAKOUT)
     {
      stopLossAtr = InpBreakoutStopLossAtr;
      targetRMultiple = InpBreakoutTargetRMultiple;
     }
   else if(bucket == SIGNAL_RANGE_RECLAIM)
     {
      stopLossAtr = 0.0;
      targetRMultiple = 0.0;
     }
   else if(bucket == SIGNAL_FRACTAL_TREND)
     {
      stopLossAtr = 0.0;
      targetRMultiple = 0.0;
     }

   MqlTick quote;
   if(!SymbolInfoTick(runtimeSymbol,quote) || quote.bid<=0.0 || quote.ask<quote.bid) return false;
   double ask = quote.ask;
   double bid = quote.bid;
   double unit = GetDistanceUnit();
   double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   int stopsLevel = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   double entryPrice = isSell ? bid : ask;
   if(entryPrice <= 0.0 || unit <= 0.0 || point <= 0.0)
      return false;
   double stopDistance = stopLossAtr * unit;
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
   // Recompute after tick-size normalization for BOTH directions.
   sl=NormalizePrice(sl);
   tp=NormalizePrice(tp);
   stopDistance=isSell ? sl-entryPrice : entryPrice-sl;
   targetDistance=isSell ? entryPrice-tp : tp-entryPrice;
   double closePrice=isSell ? ask : bid;
   double brokerStopDistance=isSell ? sl-closePrice : closePrice-sl;
   double brokerTargetDistance=isSell ? closePrice-tp : tp-closePrice;
   if(stopDistance<=0.0 || targetDistance<=0.0 || brokerStopDistance<=0.0 || brokerTargetDistance<=0.0 ||
      brokerStopDistance+point*1e-6<stopsLevel*point || brokerTargetDistance+point*1e-6<stopsLevel*point)
     {
      Print("ORDER_SKIPPED INVALID_OR_TOO_CLOSE_STOPS");
      return false;
     }
   double volume = CalculateVolume(isSell ? ORDER_TYPE_SELL : ORDER_TYPE_BUY,entryPrice,sl);
   if(volume <= 0.0)
      return false;
   trade.SetDeviationInPoints((ulong)MathCeil(InpDeviationAtr*unit/point));
   if(!trade.SetTypeFillingBySymbol(runtimeSymbol)) return false;
   trade.SetAsyncMode(false);
   // Persist before sending: an interrupted process must not blindly resend.
   uncertainSend=true;
   uncertainSince=TimeCurrent();
   uncertainOrder=0;
   SaveRiskState();
   if(PersistRiskState()) GlobalVariablesFlush();
   bool sent=isSell ? trade.Sell(volume,runtimeSymbol,entryPrice,sl,tp,comment) :
                      trade.Buy(volume,runtimeSymbol,entryPrice,sl,tp,comment);
   bool filled=CheckTradeResult(sent,"open");
   uint code=trade.ResultRetcode();
   uncertainOrder=trade.ResultOrder();
   // PLACED / timeout / connection errors require order/deal reconciliation.
   if(filled || (code!=TRADE_RETCODE_PLACED && code!=TRADE_RETCODE_TIMEOUT &&
                 code!=TRADE_RETCODE_CONNECTION && code!=0)) uncertainSend=false;
   SaveRiskState();
   return filled;
  }

// RELATIVE_CONTINUATION_MODULE_END Orders
#endif
