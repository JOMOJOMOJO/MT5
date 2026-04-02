//+------------------------------------------------------------------+
//| USDJPY Round Continuation Long                                   |
//+------------------------------------------------------------------+
#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "1.11"
#property strict
#property description "USDJPY M15 long-only continuation prototype using EMA13/EMA100 trend, 50-pip anti-chop state, and wick-based pullback re-entry."

#include <Trade\Trade.mqh>

CTrade trade;

struct PivotPoint
  {
   bool     valid;
   int      shift;
   double   price;
   datetime time;
  };

enum SignalBucket
  {
   SIGNAL_NONE = 0,
   SIGNAL_ROUND = 1,
   SIGNAL_EMA = 2,
   SIGNAL_ROUND_LOOSE = 3,
   SIGNAL_BREAKOUT = 4,
   SIGNAL_RSI = 5,
   SIGNAL_COMPRESSION = 6
  };

input string          InpSymbol                   = "USDJPY";
input ENUM_TIMEFRAMES InpSignalTimeframe          = PERIOD_M15;
input int             InpFastEMAPeriod            = 13;
input int             InpSlowEMAPeriod            = 100;
input int             InpSlowSlopeLookback        = 5;
input int             InpPivotSpan                = 2;
input int             InpTrendScanBars            = 180;
input int             InpVolatilityLookbackBars   = 24;
input double          InpMinWindowRangePips       = 18.0;
input int             InpRoundStepPips            = 50;
input int             InpSessionStartHour         = 7;
input int             InpSessionEndHour           = 22;
input double          InpMaxEma13DistancePips     = 12.0;
input double          InpMinUpperWickShare        = 0.50;
input double          InpMaxLowerWickShare        = 0.10;
input double          InpMinSlowSlopePips         = 0.0;
input double          InpStopLossPips             = 22.0;
input double          InpTargetRMultiple          = 1.5;
input int             InpMaxHoldBars              = 18;
input bool            InpEnableRoundLooseBucket   = false;
input double          InpRoundLooseMaxEma13DistancePips = 18.0;
input double          InpRoundLooseStopLossPips   = 18.0;
input double          InpRoundLooseTargetRMultiple = 1.0;
input int             InpRoundLooseMaxHoldBars    = 12;
input bool            InpEnableEmaBucket          = false;
input int             InpAdxPeriod                = 14;
input double          InpEmaMaxAdx                = 30.0;
input int             InpEmaSessionStartHour      = 7;
input int             InpEmaSessionEndHour        = 16;
input double          InpEmaMaxEma13DistancePips  = 22.0;
input double          InpEmaMaxRet1               = 0.0004;
input double          InpEmaMinUpperWickShare     = 0.45;
input double          InpEmaMaxLowerWickShare     = 0.15;
input double          InpEmaMaxCloseLocation      = 0.45;
input double          InpEmaStopLossPips          = 15.0;
input double          InpEmaTargetRMultiple       = 1.2;
input int             InpEmaMaxHoldBars           = 12;
input bool            InpEnableCompressionBucket  = false;
input int             InpCompressionSessionStartHour = 23;
input int             InpCompressionSessionEndHour = 22;
input double          InpCompressionMaxAdx        = 20.5;
input double          InpCompressionMaxEma13DistancePips = 30.0;
input double          InpCompressionMinUpperWickShare = 0.45;
input double          InpCompressionMaxLowerWickShare = 0.07;
input double          InpCompressionStopLossPips  = 15.0;
input double          InpCompressionTargetRMultiple = 1.2;
input int             InpCompressionMaxHoldBars   = 12;
input bool            InpEnableRsiBucket          = false;
input int             InpRsiPeriod                = 3;
input double          InpRsiOversold              = 18.0;
input int             InpRsiSessionStartHour      = 7;
input int             InpRsiSessionEndHour        = 22;
input double          InpRsiMaxEma13DistancePips  = 25.0;
input double          InpRsiTouchBufferPips       = 1.0;
input double          InpRsiMinCloseLocation      = 0.55;
input double          InpRsiMinBodyPips           = 2.0;
input double          InpRsiMaxLowerWickShare     = 0.45;
input double          InpRsiStopLossPips          = 16.0;
input double          InpRsiTargetRMultiple       = 1.1;
input int             InpRsiMaxHoldBars           = 12;
input bool            InpEnableBreakoutBucket     = false;
input int             InpBreakoutSessionStartHour = 7;
input int             InpBreakoutSessionEndHour   = 22;
input int             InpBreakoutLookbackBars     = 12;
input double          InpBreakoutMidpointDistancePips = 25.0;
input double          InpBreakoutTouchTolerancePips = 0.5;
input double          InpBreakoutRetestBufferPips = 2.0;
input int             InpBreakoutRetestDelayBars  = 1;
input double          InpBreakoutMinCloseLocation = 0.55;
input double          InpBreakoutMinBodyPips      = 6.0;
input double          InpBreakoutMinBodyToRange   = 0.60;
input double          InpBreakoutMaxToEma13Pips   = 30.0;
input double          InpBreakoutMinRetestCloseLocation = 0.50;
input double          InpBreakoutMaxRetestDepthPips = 1.0;
input double          InpBreakoutStopLossPips     = 20.0;
input double          InpBreakoutTargetRMultiple  = 1.2;
input int             InpBreakoutMaxHoldBars      = 18;
input double          InpRiskPercent              = 2.0;
input bool            InpUseMicroCapRiskOverride  = true;
input double          InpMicroCapBalanceThreshold = 150.0;
input double          InpMicroCapRiskPercent      = 3.0;
input bool            InpSkipTradeWhenMinLotRiskTooHigh = true;
input double          InpMaxEffectiveRiskPercentAtMinLot = 3.0;
input bool            InpUseDailyLossCap          = true;
input double          InpDailyLossCapPercent      = 6.0;
input bool            InpFlattenOnDailyLossCap    = true;
input bool            InpUseEquityDrawdownCap     = true;
input double          InpEquityDrawdownCapPercent = 12.0;
input bool            InpFlattenOnEquityDrawdownCap = true;
input int             InpMaxTradesPerDay          = 2;
input double          InpMaxSpreadPips            = 2.0;
input string          InpAllowedWeekdays          = "1,2,3,4,5";
input bool            InpEnableTelemetry          = true;
input string          InpTelemetryFileName        = "mt5_company_usdjpy_20260402_round_continuation_long_quality12b_guarded.csv";
input bool            InpEnableOperatorControl    = true;
input string          InpOperatorCommandFile      = "mt5_company_usdjpy_20260402_round_continuation_long_operator.txt";
input bool            InpEnableStatusSnapshot     = true;
input string          InpStatusFileName           = "mt5_company_usdjpy_20260402_round_continuation_long_status.txt";
input int             InpStatusHeartbeatSeconds   = 60;
input long            InpMagicNumber              = 20260498;

int fastEmaHandle = INVALID_HANDLE;
int slowEmaHandle = INVALID_HANDLE;
int adxHandle = INVALID_HANDLE;
int rsiHandle = INVALID_HANDLE;
string runtimeSymbol = "";
string runtimeAllowedWeekdays = "";
string runtimeTelemetryFileName = "";
string runtimeOperatorCommandFile = "";
string runtimeStatusFileName = "";
bool runtimeOperatorControlEnabled = false;
bool runtimeStatusSnapshotEnabled = false;
bool allowedWeekdays[7];
datetime lastBarTime = 0;
datetime currentDayStart = 0;
int lastDayOfYear = -1;
double dailyStartBalance = 0.0;
double dailyStartEquity = 0.0;
double equityPeak = 0.0;
int dailyTradeCount = 0;
int dailyClosedTrades = 0;
int dailyEntriesBuy = 0;
int dailyEntriesSell = 0;
int consecutiveLosses = 0;
int dailyBlockedSpread = 0;
int dailyBlockedDailyLoss = 0;
int dailyBlockedTradeCap = 0;
int dailyBlockedEquityCap = 0;
int dailyLossLockActivations = 0;
int telemetryHandle = INVALID_HANDLE;
string operatorMode = "normal";
bool statusSnapshotErrorLogged = false;
bool timerStarted = false;

string TrimSpaces(string value)
  {
   int start = 0;
   int finish = StringLen(value) - 1;
   while(start <= finish && StringGetCharacter(value, start) <= 32)
      start++;
   while(finish >= start && StringGetCharacter(value, finish) <= 32)
      finish--;
   if(finish < start)
      return "";
   return StringSubstr(value, 0 + start, finish - start + 1);
  }

string NormalizePresetString(string rawValue)
  {
   int marker = StringFind(rawValue, "||");
   if(marker < 0)
      return rawValue;
   return StringSubstr(rawValue, 0, marker);
  }

bool ParseWeekdays(string rawValue)
  {
   ArrayInitialize(allowedWeekdays, false);
   string items[];
   int count = StringSplit(rawValue, ',', items);
   if(count <= 0)
      return false;
   for(int i = 0; i < count; ++i)
     {
      string item = TrimSpaces(items[i]);
      if(item == "")
         continue;
      int day = (int)StringToInteger(item);
      if(day < 0 || day > 6)
         return false;
      allowedWeekdays[day] = true;
     }
   return true;
  }

bool IsAllowedWeekday(int dayOfWeek)
  {
   if(dayOfWeek < 0 || dayOfWeek > 6)
      return false;
   return allowedWeekdays[dayOfWeek];
  }

double GetPipSize()
  {
   double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

double NormalizePrice(double price)
  {
   int digits = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
  }

double GetCurrentSpreadPips()
  {
   MqlTick tick;
   if(!SymbolInfoTick(runtimeSymbol, tick))
      return -1.0;
   double pip = GetPipSize();
   if(pip <= 0.0)
      return -1.0;
   return (tick.ask - tick.bid) / pip;
  }

bool IsSpreadAllowed()
  {
   if(InpMaxSpreadPips <= 0.0)
      return true;
   double spreadPips = GetCurrentSpreadPips();
   if(spreadPips < 0.0)
      return false;
   return (spreadPips <= InpMaxSpreadPips);
  }

int VolumeDigits(double stepVolume)
  {
   int digits = 0;
   double scaled = stepVolume;
   while(digits < 8 && MathAbs(scaled - MathRound(scaled)) > 1e-8)
     {
      scaled *= 10.0;
      digits++;
     }
   return digits;
  }

double GetEffectiveRiskPercent(double equity)
  {
   if(InpUseMicroCapRiskOverride && equity > 0.0 && equity <= InpMicroCapBalanceThreshold)
      return InpMicroCapRiskPercent;
   return InpRiskPercent;
  }

double CalculateVolume(double stopDistance)
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskPercent = GetEffectiveRiskPercent(equity);
   double riskAmount = equity * (riskPercent / 100.0);
   if(riskAmount <= 0.0)
      return 0.0;

   double tickSize = SymbolInfoDouble(runtimeSymbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(runtimeSymbol, SYMBOL_TRADE_TICK_VALUE);
   double minVolume = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_MAX);
   double stepVolume = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_STEP);
   if(tickSize <= 0.0 || tickValue <= 0.0 || minVolume <= 0.0 || maxVolume <= 0.0 || stepVolume <= 0.0)
      return 0.0;

   double moneyPerLot = (stopDistance / tickSize) * tickValue;
   if(moneyPerLot <= 0.0)
      return 0.0;

   double rawVolume = riskAmount / moneyPerLot;
   double normalized = MathFloor(rawVolume / stepVolume) * stepVolume;
   if(normalized < minVolume)
     {
      if(InpSkipTradeWhenMinLotRiskTooHigh && InpMaxEffectiveRiskPercentAtMinLot > 0.0)
        {
         double minLotRiskAmount = moneyPerLot * minVolume;
         double minLotRiskPercent = (equity > 0.0 ? (minLotRiskAmount / equity) * 100.0 : 0.0);
         if(minLotRiskPercent > InpMaxEffectiveRiskPercentAtMinLot)
            return 0.0;
        }
      normalized = minVolume;
     }

   if(normalized > maxVolume)
      normalized = maxVolume;
   return NormalizeDouble(normalized, VolumeDigits(stepVolume));
  }

bool IsNewBar(datetime &barTime)
  {
   datetime times[];
   ArraySetAsSeries(times, true);
   if(CopyTime(runtimeSymbol, InpSignalTimeframe, 0, 2, times) < 2)
      return false;
   if(times[0] == lastBarTime)
      return false;
   lastBarTime = times[0];
   barTime = times[0];
   return true;
  }

void ResetDailyCounters()
  {
   dailyTradeCount = 0;
   dailyClosedTrades = 0;
   dailyEntriesBuy = 0;
   dailyEntriesSell = 0;
   consecutiveLosses = 0;
   dailyBlockedSpread = 0;
   dailyBlockedDailyLoss = 0;
   dailyBlockedTradeCap = 0;
   dailyBlockedEquityCap = 0;
   dailyLossLockActivations = 0;
  }

void UpdateDailyAnchor()
  {
   datetime nowTime = TimeCurrent();
   MqlDateTime ts;
   TimeToStruct(nowTime, ts);
   if(ts.day_of_year != lastDayOfYear)
     {
      if(currentDayStart > 0)
         FlushDailySummary(nowTime, "rollover");
      lastDayOfYear = ts.day_of_year;
      ts.hour = 0;
      ts.min = 0;
      ts.sec = 0;
      currentDayStart = StructToTime(ts);
      dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      dailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(equityPeak <= 0.0)
         equityPeak = dailyStartEquity;
      ResetDailyCounters();
      LogTelemetryEvent(nowTime, "day_reset", "", "", 0.0, 0.0, 0.0, "");
     }
  }

void UpdateEquityPeak()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equityPeak <= 0.0 || equity > equityPeak)
      equityPeak = equity;
  }

bool IsDailyLossCapBlocked()
  {
   if(!InpUseDailyLossCap || InpDailyLossCapPercent <= 0.0 || dailyStartEquity <= 0.0)
      return false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   return (equity <= dailyStartEquity * (1.0 - InpDailyLossCapPercent / 100.0));
  }

bool IsEquityDrawdownBlocked()
  {
   if(!InpUseEquityDrawdownCap || InpEquityDrawdownCapPercent <= 0.0 || equityPeak <= 0.0)
      return false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   return (equity <= equityPeak * (1.0 - InpEquityDrawdownCapPercent / 100.0));
  }

bool IsTradeCountBlocked()
  {
   if(InpMaxTradesPerDay <= 0)
      return false;
   return (dailyTradeCount >= InpMaxTradesPerDay);
  }

bool IsWithinSession(datetime barTime, int sessionStartHour, int sessionEndHour)
  {
   MqlDateTime ts;
   TimeToStruct(barTime, ts);
   if(sessionStartHour < sessionEndHour)
      return ts.hour >= sessionStartHour && ts.hour < sessionEndHour;
   return ts.hour >= sessionStartHour || ts.hour < sessionEndHour;
  }

bool IsWithinActiveSession(datetime barTime)
  {
   return IsWithinSession(barTime, InpSessionStartHour, InpSessionEndHour);
  }

bool LoadSignalWindow(MqlRates &rates[], double &fastEma[], double &slowEma[], double &adxValues[], double &rsiValues[], int count)
  {
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(fastEma, true);
   ArraySetAsSeries(slowEma, true);
   ArraySetAsSeries(adxValues, true);
   ArraySetAsSeries(rsiValues, true);
   int copiedRates = CopyRates(runtimeSymbol, InpSignalTimeframe, 0, count, rates);
   if(copiedRates < 140)
      return false;
   int copiedFast = CopyBuffer(fastEmaHandle, 0, 0, count, fastEma);
   int copiedSlow = CopyBuffer(slowEmaHandle, 0, 0, count, slowEma);
   int copiedAdx = CopyBuffer(adxHandle, 0, 0, count, adxValues);
   int copiedRsi = CopyBuffer(rsiHandle, 0, 0, count, rsiValues);
   return copiedFast == copiedRates && copiedSlow == copiedRates && copiedAdx == copiedRates && copiedRsi == copiedRates;
  }

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

bool ManageOpenPosition()
  {
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
      if(StringFind(comment, "ema_sidecar") >= 0)
         maxHoldBars = InpEmaMaxHoldBars;
      else if(StringFind(comment, "compression_sidecar") >= 0)
         maxHoldBars = InpCompressionMaxHoldBars;
      else if(StringFind(comment, "rsi_sidecar") >= 0)
         maxHoldBars = InpRsiMaxHoldBars;
      else if(StringFind(comment, "round_loose") >= 0)
         maxHoldBars = InpRoundLooseMaxHoldBars;
      else if(StringFind(comment, "breakout_sidecar") >= 0)
         maxHoldBars = InpBreakoutMaxHoldBars;
      int barsOpen = iBarShift(runtimeSymbol, InpSignalTimeframe, openedAt, false);
      if(barsOpen < maxHoldBars)
         continue;
      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      if(trade.PositionClose(ticket))
         return true;
      return false;
     }
   return false;
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
   if(CountManagedPositions() > 0)
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

void FindRecentPivots(const MqlRates &rates[], bool wantHigh, PivotPoint &latest, PivotPoint &previous)
  {
   latest.valid = false;
   previous.valid = false;
   int size = ArraySize(rates);
   int maxShift = MathMin(size - 1 - InpPivotSpan, InpTrendScanBars);
   for(int shift = InpPivotSpan + 1; shift <= maxShift; ++shift)
     {
      bool match = wantHigh ? IsPivotHigh(rates, shift, InpPivotSpan) : IsPivotLow(rates, shift, InpPivotSpan);
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

bool EvaluateRoundSignal(const MqlRates &rates[], const double &fastEma[], const double &slowEma[])
  {
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

void OpenPosition(SignalBucket bucket)
  {
   double stopLossPips = InpStopLossPips;
   double targetRMultiple = InpTargetRMultiple;
   string comment = "round_continuation_long";
   if(bucket == SIGNAL_EMA)
     {
      stopLossPips = InpEmaStopLossPips;
      targetRMultiple = InpEmaTargetRMultiple;
      comment = "ema_sidecar_long";
     }
   else if(bucket == SIGNAL_COMPRESSION)
     {
      stopLossPips = InpCompressionStopLossPips;
      targetRMultiple = InpCompressionTargetRMultiple;
      comment = "compression_sidecar_long";
     }
   else if(bucket == SIGNAL_RSI)
     {
      stopLossPips = InpRsiStopLossPips;
      targetRMultiple = InpRsiTargetRMultiple;
      comment = "rsi_sidecar_long";
     }
   else if(bucket == SIGNAL_ROUND_LOOSE)
     {
      stopLossPips = InpRoundLooseStopLossPips;
      targetRMultiple = InpRoundLooseTargetRMultiple;
      comment = "round_loose_long";
     }
   else if(bucket == SIGNAL_BREAKOUT)
     {
      stopLossPips = InpBreakoutStopLossPips;
      targetRMultiple = InpBreakoutTargetRMultiple;
      comment = "breakout_sidecar_long";
     }

   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   double pip = GetPipSize();
   double stopDistance = stopLossPips * pip;
   double targetDistance = stopDistance * targetRMultiple;
   double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   int stopsLevel = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(ask <= 0.0 || pip <= 0.0 || point <= 0.0)
      return;
   if(stopDistance < stopsLevel * point)
      return;
   if(targetDistance > 0.0 && targetDistance < stopsLevel * point)
      return;

   double volume = CalculateVolume(stopDistance);
   if(volume <= 0.0)
      return;

   double sl = NormalizePrice(ask - stopDistance);
   double tp = NormalizePrice(ask + targetDistance);
   trade.Buy(volume, runtimeSymbol, 0.0, sl, tp, comment);
  }

bool OpenTelemetryFile()
  {
   if(!InpEnableTelemetry)
      return false;
   if(telemetryHandle != INVALID_HANDLE)
      return true;

   telemetryHandle = FileOpen(runtimeTelemetryFileName, FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_COMMON | FILE_ANSI, ';');
   if(telemetryHandle == INVALID_HANDLE)
     {
      PrintFormat("Telemetry open failed for '%s' (%d)", runtimeTelemetryFileName, GetLastError());
      return false;
     }

   if(FileSize(telemetryHandle) == 0)
     {
      FileWrite(telemetryHandle,
                "timestamp", "event", "reason", "side", "price", "volume", "net_profit", "balance", "equity",
                "daily_closed_trades", "daily_entries_buy", "daily_entries_sell", "consecutive_losses",
                "blocked_spread", "blocked_daily_loss", "blocked_trade_cap", "blocked_loss_lock", "blocked_equity_cap",
                "loss_lock_activations", "note");
     }

   FileSeek(telemetryHandle, 0, SEEK_END);
   return true;
  }

void CloseTelemetryFile()
  {
   if(telemetryHandle != INVALID_HANDLE)
     {
      FileClose(telemetryHandle);
      telemetryHandle = INVALID_HANDLE;
     }
  }

void LogTelemetryEvent(datetime stamp, string eventType, string reason, string side, double price, double volume, double netProfit, string note)
  {
   if(!InpEnableTelemetry)
      return;
   if(!OpenTelemetryFile())
      return;

   FileSeek(telemetryHandle, 0, SEEK_END);
   FileWrite(telemetryHandle,
             TimeToString(stamp, TIME_DATE | TIME_SECONDS),
             eventType,
             reason,
             side,
             price,
             volume,
             netProfit,
             AccountInfoDouble(ACCOUNT_BALANCE),
             AccountInfoDouble(ACCOUNT_EQUITY),
             dailyClosedTrades,
             dailyEntriesBuy,
             dailyEntriesSell,
             consecutiveLosses,
             dailyBlockedSpread,
             dailyBlockedDailyLoss,
             dailyBlockedTradeCap,
             0,
             dailyBlockedEquityCap,
             dailyLossLockActivations,
             note);
   FileFlush(telemetryHandle);
  }

void FlushDailySummary(datetime stamp, string trigger)
  {
   if(currentDayStart <= 0)
      return;
   LogTelemetryEvent(stamp, "daily_summary", trigger, "", 0.0, 0.0, AccountInfoDouble(ACCOUNT_BALANCE) - dailyStartBalance, "");
  }

void RegisterEntryDeal(datetime dealTime, string side, double price, double volume)
  {
   UpdateDailyAnchor();
   dailyTradeCount++;
   if(side == "buy")
      dailyEntriesBuy++;
   else if(side == "sell")
      dailyEntriesSell++;
   LogTelemetryEvent(dealTime, "entry", "", side, price, volume, 0.0, "");
  }

void RegisterClosedDeal(datetime dealTime, double netProfit, string side, double price, double volume)
  {
   UpdateDailyAnchor();
   MqlDateTime nowStruct, dealStruct;
   TimeToStruct(TimeCurrent(), nowStruct);
   TimeToStruct(dealTime, dealStruct);
   if(nowStruct.day_of_year != dealStruct.day_of_year)
      return;

   dailyClosedTrades++;
   if(netProfit >= 0.0)
     {
      consecutiveLosses = 0;
      LogTelemetryEvent(dealTime, "exit", "win", side, price, volume, netProfit, "");
      return;
     }

   consecutiveLosses++;
   LogTelemetryEvent(dealTime, "exit", "loss", side, price, volume, netProfit, "");
  }

string ReadOperatorModeFromFile()
  {
   if(!runtimeOperatorControlEnabled || runtimeOperatorCommandFile == "")
      return "normal";

   int handle = FileOpen(runtimeOperatorCommandFile, FILE_TXT | FILE_READ | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_COMMON | FILE_ANSI);
   if(handle == INVALID_HANDLE)
      return "normal";

   string command = "";
   if(!FileIsEnding(handle))
      command = FileReadString(handle);
   FileClose(handle);

   if(command == "")
      return "normal";
   if(StringCompare(command, "pause", false) == 0 || StringCompare(command, "pause_entries", false) == 0)
      return "pause";
   if(StringCompare(command, "flatten", false) == 0 ||
      StringCompare(command, "flatten_and_pause", false) == 0 ||
      StringCompare(command, "kill", false) == 0)
      return "flatten";
   return "normal";
  }

void RefreshOperatorMode()
  {
   string nextMode = ReadOperatorModeFromFile();
   if(nextMode == operatorMode)
      return;

   operatorMode = nextMode;
   PrintFormat("Operator mode changed to '%s'", operatorMode);
   LogTelemetryEvent(TimeCurrent(), "operator_mode", operatorMode, "", 0.0, 0.0, 0.0, runtimeOperatorCommandFile);
  }

bool AreOperatorEntriesBlocked()
  {
   return (operatorMode != "normal");
  }

string BoolText(bool value)
  {
   if(value)
      return "true";
   return "false";
  }

string DetermineEntryState()
  {
   if(operatorMode == "flatten")
      return "operator_flatten";
   if(operatorMode == "pause")
      return "operator_pause";
   if(IsDailyLossCapBlocked())
      return "daily_loss_cap";
   if(IsEquityDrawdownBlocked())
      return "equity_drawdown_cap";
   if(IsTradeCountBlocked())
      return "trade_cap";
   if(CountManagedPositions() > 0)
      return "position_open";

   datetime currentBar = iTime(runtimeSymbol, InpSignalTimeframe, 0);
   MqlDateTime ts;
   TimeToStruct(currentBar, ts);
   if(!IsAllowedWeekday(ts.day_of_week))
      return "weekday_blocked";
   if(!IsWithinActiveSession(currentBar))
      return "inactive_session";
   if(!IsSpreadAllowed())
      return "spread";
   return "ready";
  }

void WriteStatusSnapshot()
  {
   if(!runtimeStatusSnapshotEnabled || runtimeStatusFileName == "")
      return;

   int handle = FileOpen(runtimeStatusFileName, FILE_TXT | FILE_WRITE | FILE_COMMON | FILE_ANSI);
   if(handle == INVALID_HANDLE)
     {
      if(!statusSnapshotErrorLogged)
        {
         PrintFormat("Status snapshot open failed for '%s' (%d)", runtimeStatusFileName, GetLastError());
         statusSnapshotErrorLogged = true;
        }
      return;
     }

   statusSnapshotErrorLogged = false;
   string snapshot =
      "timestamp=" + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + "\r\n" +
      "symbol=" + runtimeSymbol + "\r\n" +
      "timeframe=" + EnumToString(InpSignalTimeframe) + "\r\n" +
      "operator_mode=" + operatorMode + "\r\n" +
      "entry_state=" + DetermineEntryState() + "\r\n" +
      "balance=" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\r\n" +
      "equity=" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "\r\n" +
      "equity_peak=" + DoubleToString(equityPeak, 2) + "\r\n" +
      "open_positions=" + IntegerToString(CountManagedPositions()) + "\r\n" +
      "daily_trades_opened=" + IntegerToString(dailyTradeCount) + "\r\n" +
      "daily_closed_trades=" + IntegerToString(dailyClosedTrades) + "\r\n" +
      "daily_entries_buy=" + IntegerToString(dailyEntriesBuy) + "\r\n" +
      "daily_entries_sell=" + IntegerToString(dailyEntriesSell) + "\r\n" +
      "consecutive_losses=" + IntegerToString(consecutiveLosses) + "\r\n" +
      "spread_pips=" + DoubleToString(GetCurrentSpreadPips(), 2) + "\r\n" +
      "daily_loss_cap_blocked=" + BoolText(IsDailyLossCapBlocked()) + "\r\n" +
      "equity_drawdown_blocked=" + BoolText(IsEquityDrawdownBlocked()) + "\r\n" +
      "trade_cap_blocked=" + BoolText(IsTradeCountBlocked()) + "\r\n" +
      "telemetry_file=" + runtimeTelemetryFileName + "\r\n";

   FileWriteString(handle, snapshot);
   FileClose(handle);
  }

int OnInit()
  {
   runtimeSymbol = NormalizePresetString(InpSymbol);
   runtimeAllowedWeekdays = NormalizePresetString(InpAllowedWeekdays);
   runtimeTelemetryFileName = NormalizePresetString(InpTelemetryFileName);
   runtimeOperatorCommandFile = NormalizePresetString(InpOperatorCommandFile);
   runtimeStatusFileName = NormalizePresetString(InpStatusFileName);
   bool isTesterRuntime = ((bool)MQLInfoInteger(MQL_TESTER) || (bool)MQLInfoInteger(MQL_OPTIMIZATION));
   runtimeOperatorControlEnabled = (InpEnableOperatorControl && !isTesterRuntime);
   runtimeStatusSnapshotEnabled = (InpEnableStatusSnapshot && !isTesterRuntime);

   if(
      InpFastEMAPeriod <= 0 || InpSlowEMAPeriod <= InpFastEMAPeriod || InpSlowSlopeLookback <= 0 ||
      InpPivotSpan <= 0 || InpTrendScanBars <= 20 || InpVolatilityLookbackBars <= 0 ||
      InpMinWindowRangePips <= 0.0 || InpRoundStepPips <= 0 || InpSessionStartHour < 0 || InpSessionStartHour > 23 ||
      InpSessionEndHour < 0 || InpSessionEndHour > 23 || InpSessionStartHour == InpSessionEndHour ||
      InpMaxEma13DistancePips <= 0.0 || InpMinUpperWickShare < 0.0 || InpMinUpperWickShare > 1.0 ||
      InpMaxLowerWickShare < 0.0 || InpMaxLowerWickShare > 1.0 || InpMinUpperWickShare <= InpMaxLowerWickShare ||
      InpRoundLooseMaxEma13DistancePips <= InpMaxEma13DistancePips || InpRoundLooseStopLossPips <= 0.0 ||
      InpRoundLooseTargetRMultiple <= 0.0 || InpRoundLooseMaxHoldBars < 1 ||
      InpAdxPeriod <= 1 || InpEmaMaxAdx <= 0.0 || InpEmaSessionStartHour < 0 || InpEmaSessionStartHour > 23 ||
      InpEmaSessionEndHour < 0 || InpEmaSessionEndHour > 23 || InpEmaSessionStartHour == InpEmaSessionEndHour ||
      InpEmaMaxEma13DistancePips <= 0.0 || InpEmaMaxRet1 < -0.01 || InpEmaMaxRet1 > 0.01 ||
      InpEmaMinUpperWickShare < 0.0 || InpEmaMinUpperWickShare > 1.0 || InpEmaMaxLowerWickShare < 0.0 ||
      InpEmaMaxLowerWickShare > 1.0 || InpEmaMaxCloseLocation < 0.0 || InpEmaMaxCloseLocation > 1.0 ||
      InpEmaMinUpperWickShare <= InpEmaMaxLowerWickShare || InpEmaStopLossPips <= 0.0 ||
      InpEmaTargetRMultiple <= 0.0 || InpEmaMaxHoldBars < 1 ||
      InpCompressionSessionStartHour < 0 || InpCompressionSessionStartHour > 23 || InpCompressionSessionEndHour < 0 ||
      InpCompressionSessionEndHour > 23 || InpCompressionSessionStartHour == InpCompressionSessionEndHour ||
      InpCompressionMaxAdx <= 0.0 || InpCompressionMaxEma13DistancePips <= 0.0 ||
      InpCompressionMinUpperWickShare < 0.0 || InpCompressionMinUpperWickShare > 1.0 ||
      InpCompressionMaxLowerWickShare < 0.0 || InpCompressionMaxLowerWickShare > 1.0 ||
      InpCompressionMinUpperWickShare <= InpCompressionMaxLowerWickShare ||
      InpCompressionStopLossPips <= 0.0 || InpCompressionTargetRMultiple <= 0.0 || InpCompressionMaxHoldBars < 1 ||
      InpRsiPeriod < 2 || InpRsiOversold <= 0.0 || InpRsiOversold >= 100.0 || InpRsiSessionStartHour < 0 ||
      InpRsiSessionStartHour > 23 || InpRsiSessionEndHour < 0 || InpRsiSessionEndHour > 23 ||
      InpRsiSessionStartHour == InpRsiSessionEndHour || InpRsiMaxEma13DistancePips <= 0.0 ||
      InpRsiTouchBufferPips < 0.0 || InpRsiMinCloseLocation < 0.0 || InpRsiMinCloseLocation > 1.0 ||
      InpRsiMinBodyPips <= 0.0 || InpRsiMaxLowerWickShare < 0.0 || InpRsiMaxLowerWickShare > 1.0 ||
      InpRsiStopLossPips <= 0.0 || InpRsiTargetRMultiple <= 0.0 || InpRsiMaxHoldBars < 1 ||
      InpBreakoutSessionStartHour < 0 || InpBreakoutSessionStartHour > 23 || InpBreakoutSessionEndHour < 0 ||
      InpBreakoutSessionEndHour > 23 || InpBreakoutSessionStartHour == InpBreakoutSessionEndHour ||
      InpBreakoutLookbackBars <= 0 || InpBreakoutMidpointDistancePips <= 0.0 || InpBreakoutTouchTolerancePips < 0.0 ||
      InpBreakoutRetestBufferPips < 0.0 || InpBreakoutRetestDelayBars < 1 || InpBreakoutMinCloseLocation < 0.0 ||
      InpBreakoutMinCloseLocation > 1.0 || InpBreakoutMinBodyPips <= 0.0 || InpBreakoutMinBodyToRange <= 0.0 ||
      InpBreakoutMinBodyToRange > 1.0 || InpBreakoutMaxToEma13Pips <= 0.0 ||
      InpBreakoutMinRetestCloseLocation < 0.0 || InpBreakoutMinRetestCloseLocation > 1.0 ||
      InpBreakoutMaxRetestDepthPips < 0.0 || InpBreakoutStopLossPips <= 0.0 ||
      InpBreakoutTargetRMultiple <= 0.0 || InpBreakoutMaxHoldBars < 1 ||
      InpStopLossPips <= 0.0 || InpTargetRMultiple <= 0.0 || InpMaxHoldBars < 1 || InpRiskPercent <= 0.0 ||
      InpMicroCapBalanceThreshold < 0.0 || InpMicroCapRiskPercent <= 0.0 || InpDailyLossCapPercent <= 0.0 ||
      InpEquityDrawdownCapPercent < 0.0 || InpMaxTradesPerDay < 0 || InpMaxSpreadPips <= 0.0 || InpMagicNumber <= 0 ||
      InpStatusHeartbeatSeconds < 0 || InpMaxEffectiveRiskPercentAtMinLot < 0.0
   )
      return INIT_PARAMETERS_INCORRECT;

   if(!ParseWeekdays(runtimeAllowedWeekdays))
      return INIT_PARAMETERS_INCORRECT;
   if(!SymbolInfoInteger(runtimeSymbol, SYMBOL_SELECT))
      if(!SymbolSelect(runtimeSymbol, true))
         return INIT_FAILED;

   fastEmaHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowEmaHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   adxHandle = iADX(runtimeSymbol, InpSignalTimeframe, InpAdxPeriod);
   rsiHandle = iRSI(runtimeSymbol, InpSignalTimeframe, InpRsiPeriod, PRICE_CLOSE);
   if(fastEmaHandle == INVALID_HANDLE || slowEmaHandle == INVALID_HANDLE || adxHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE)
      return INIT_FAILED;

   trade.SetExpertMagicNumber((ulong)InpMagicNumber);
   double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   double pip = GetPipSize();
   if(point > 0.0 && pip > 0.0)
     {
      int deviationPoints = (int)MathMax(10.0, MathRound(InpMaxSpreadPips * pip / point));
      trade.SetDeviationInPoints(deviationPoints);
     }

   UpdateDailyAnchor();
   dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   dailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);

   if(InpEnableTelemetry && !OpenTelemetryFile())
      Print("Telemetry file could not be opened. Continuing without telemetry.");

   if((runtimeOperatorControlEnabled || runtimeStatusSnapshotEnabled) && InpStatusHeartbeatSeconds > 0)
     {
      EventSetTimer(InpStatusHeartbeatSeconds);
      timerStarted = true;
     }

   RefreshOperatorMode();
   WriteStatusSnapshot();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   FlushDailySummary(TimeCurrent(), "deinit");
   WriteStatusSnapshot();
   if(timerStarted)
     {
      EventKillTimer();
      timerStarted = false;
     }
   CloseTelemetryFile();
   if(fastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(fastEmaHandle);
   if(slowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(slowEmaHandle);
   if(adxHandle != INVALID_HANDLE)
      IndicatorRelease(adxHandle);
   if(rsiHandle != INVALID_HANDLE)
      IndicatorRelease(rsiHandle);
  }

void OnTimer()
  {
   UpdateDailyAnchor();
   UpdateEquityPeak();
   RefreshOperatorMode();
   if(operatorMode == "flatten")
      FlattenManagedPositions("operator_flatten_timer");
   WriteStatusSnapshot();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != runtimeSymbol)
      return;

   long dealMagic = (long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if(dealMagic != InpMagicNumber)
      return;

   long dealEntry = (long)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   long dealType = (long)HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   string entrySide = (dealType == DEAL_TYPE_BUY) ? "buy" : "sell";
   string exitSide = (dealType == DEAL_TYPE_BUY) ? "sell" : "buy";
   double dealPrice = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   double dealVolume = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);

   if(dealEntry == (long)DEAL_ENTRY_IN)
     {
      RegisterEntryDeal((datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME), entrySide, dealPrice, dealVolume);
      return;
     }

   if(dealEntry != (long)DEAL_ENTRY_OUT &&
      dealEntry != (long)DEAL_ENTRY_OUT_BY &&
      dealEntry != (long)DEAL_ENTRY_INOUT)
      return;

   double netProfit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) +
                      HistoryDealGetDouble(trans.deal, DEAL_SWAP) +
                      HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   RegisterClosedDeal((datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME), netProfit, exitSide, dealPrice, dealVolume);
  }

void OnTick()
  {
   UpdateDailyAnchor();
   UpdateEquityPeak();
   RefreshOperatorMode();
   if(operatorMode == "flatten")
      FlattenManagedPositions("operator_flatten");

   datetime barTime = 0;
   if(!IsNewBar(barTime))
      return;

   if(CountManagedPositions() > 0)
     {
      if(ManageOpenPosition() || CountManagedPositions() > 0)
        {
         WriteStatusSnapshot();
         return;
        }
     }

   WriteStatusSnapshot();

   if(IsDailyLossCapBlocked())
     {
      dailyBlockedDailyLoss++;
      if(InpFlattenOnDailyLossCap)
         FlattenManagedPositions("daily_loss_cap");
      return;
     }

   if(IsEquityDrawdownBlocked())
     {
      dailyBlockedEquityCap++;
      if(InpFlattenOnEquityDrawdownCap)
         FlattenManagedPositions("equity_drawdown_cap");
      return;
     }

   if(!CanOpenAnotherTrade(barTime))
      return;

   MqlRates rates[];
   double fastEma[];
   double slowEma[];
   double adxValues[];
   double rsiValues[];
   if(!LoadSignalWindow(rates, fastEma, slowEma, adxValues, rsiValues, 260))
      return;

   SignalBucket bucket = SIGNAL_NONE;
   if(EvaluateRoundSignal(rates, fastEma, slowEma))
      bucket = SIGNAL_ROUND;
   else if(EvaluateEmaSignal(rates, fastEma, slowEma, adxValues))
      bucket = SIGNAL_EMA;
   else if(EvaluateCompressionSignal(rates, fastEma, slowEma, adxValues))
      bucket = SIGNAL_COMPRESSION;
   else if(EvaluateRsiSignal(rates, fastEma, slowEma, rsiValues))
      bucket = SIGNAL_RSI;
   else if(EvaluateBreakoutSignal(rates, fastEma, slowEma))
      bucket = SIGNAL_BREAKOUT;
   else if(EvaluateRoundLooseSignal(rates, fastEma, slowEma))
      bucket = SIGNAL_ROUND_LOOSE;

   if(bucket != SIGNAL_NONE)
      OpenPosition(bucket);
  }
