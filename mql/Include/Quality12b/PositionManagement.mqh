// QUALITY12B_MODULE_BEGIN PositionManagement
#ifndef QUALITY12B_POSITIONMANAGEMENT_MQH
#define QUALITY12B_POSITIONMANAGEMENT_MQH
int CountManagedPositions()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      count++;
     }
   return count;
  }

string BucketComment(SignalBucket bucket)
  {
   if(bucket == SIGNAL_ROUND_SHORT)
      return "round_continuation_short";
   if(bucket == SIGNAL_EMA)
      return "ema_sidecar_long";
   if(bucket == SIGNAL_COMPRESSION)
      return "compression_sidecar_long";
   if(bucket == SIGNAL_RSI)
      return "rsi_sidecar_long";
   if(bucket == SIGNAL_ROUND_LOOSE)
      return "round_loose_long";
   if(bucket == SIGNAL_BREAKOUT)
      return "breakout_sidecar_long";
   if(bucket == SIGNAL_DOW_SWEEP)
      return "dow_sweep_long";
   if(bucket == SIGNAL_RANGE_RECLAIM)
      return "range_reclaim_long";
   if(bucket == SIGNAL_RANGE_RECLAIM_SHORT)
      return "range_reclaim_short";
   if(bucket == SIGNAL_FRACTAL_TREND)
      return "fractal_trend_long";
   if(bucket == SIGNAL_ROUND)
      return "round_continuation_long";
   return "";
  }

ENUM_TIMEFRAMES BucketSignalTimeframe(SignalBucket bucket)
  {
   if(bucket == SIGNAL_DOW_SWEEP)
      return InpDowSignalTimeframe;
   if(bucket == SIGNAL_RANGE_RECLAIM)
      return InpRangeSignalTimeframe;
   if(bucket == SIGNAL_RANGE_RECLAIM_SHORT)
      return InpRangeSignalTimeframe;
   if(bucket == SIGNAL_FRACTAL_TREND)
      return InpFractalSignalTimeframe;
   return InpSignalTimeframe;
  }

bool BucketIsSell(SignalBucket bucket)
  {
   return (bucket == SIGNAL_ROUND_SHORT || bucket == SIGNAL_RANGE_RECLAIM_SHORT);
  }

int CountBucketPositions(SignalBucket bucket)
  {
   string bucketComment = BucketComment(bucket);
   if(bucketComment == "")
      return 0;

   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, bucketComment) >= 0)
         count++;
     }
   return count;
  }

bool ManageOpenPosition()
  {
   bool actionTaken = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      datetime openedAt = (datetime)PositionGetInteger(POSITION_TIME);
      string comment = PositionGetString(POSITION_COMMENT);
      int maxHoldBars = InpMaxHoldBars;
      if(StringFind(comment, "round_continuation_short") >= 0)
         maxHoldBars = InpRoundShortMaxHoldBars;
      else if(StringFind(comment, "ema_sidecar") >= 0)
         maxHoldBars = InpEmaMaxHoldBars;
      else if(StringFind(comment, "compression_sidecar") >= 0)
         maxHoldBars = InpCompressionMaxHoldBars;
      else if(StringFind(comment, "rsi_sidecar") >= 0)
         maxHoldBars = InpRsiMaxHoldBars;
      else if(StringFind(comment, "round_loose") >= 0)
         maxHoldBars = InpRoundLooseMaxHoldBars;
      else if(StringFind(comment, "breakout_sidecar") >= 0)
         maxHoldBars = InpBreakoutMaxHoldBars;
      else if(StringFind(comment, "dow_sweep") >= 0)
         maxHoldBars = InpDowMaxHoldBars;
      else if(StringFind(comment, "range_reclaim") >= 0)
         maxHoldBars = InpRangeMaxHoldBars;
      else if(StringFind(comment, "fractal_trend") >= 0)
         maxHoldBars = InpFractalMaxHoldBars;
      ENUM_TIMEFRAMES holdTimeframe = InpSignalTimeframe;
      if(StringFind(comment, "dow_sweep") >= 0)
         holdTimeframe = InpDowSignalTimeframe;
      else if(StringFind(comment, "range_reclaim") >= 0)
         holdTimeframe = InpRangeSignalTimeframe;
      else if(StringFind(comment, "fractal_trend") >= 0)
         holdTimeframe = InpFractalSignalTimeframe;
      int barsOpen = iBarShift(runtimeSymbol, holdTimeframe, openedAt, false);
      if(barsOpen < maxHoldBars)
         continue;
      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      if(trade.PositionClose(ticket))
         actionTaken = true;
     }
   return actionTaken;
  }

void FlattenManagedPositions(string reason)
  {
   int openCount = CountManagedPositions();
   if(openCount <= 0)
      return;

   int closedCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      if(trade.PositionClose(ticket))
         closedCount++;
     }

   LogTelemetryEvent(TimeCurrent(), "protective_flatten", reason, "", 0.0, 0.0, 0.0,
                     StringFormat("closed=%d requested=%d", closedCount, openCount));
  }

bool CanOpenAnotherTrade(datetime barTime)
  {
   if(!InpAllowParallelBuckets && CountManagedPositions() > 0)
      return false;
   if(InpMaxOpenPositions > 0 && CountManagedPositions() >= InpMaxOpenPositions)
      return false;
   if(IsTradeCountBlocked())
     {
      dailyBlockedTradeCap++;
      return false;
     }

   MqlDateTime ts;
   TimeToStruct(barTime, ts);
   if(!IsAllowedWeekday(ts.day_of_week))
      return false;
   if(!IsWithinActiveSession(barTime))
      return false;
   if(!IsSpreadAllowed())
     {
      dailyBlockedSpread++;
      return false;
     }
   if(AreOperatorEntriesBlocked())
      return false;

   return true;
  }

bool CanOpenBucketTrade(SignalBucket bucket, int baseOpenCount, int pendingOpenCount)
  {
   if(bucket == SIGNAL_NONE)
      return false;
   if(CountBucketPositions(bucket) > 0)
      return false;
   if(!InpAllowParallelBuckets && baseOpenCount + pendingOpenCount > 0)
      return false;
   if(InpMaxOpenPositions > 0 && baseOpenCount + pendingOpenCount >= InpMaxOpenPositions)
      return false;
   return true;
  }

// QUALITY12B_MODULE_END PositionManagement
#endif
