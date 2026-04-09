//+------------------------------------------------------------------+
//| USDJPY Round Quality Guarded Stack                               |
//+------------------------------------------------------------------+
#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "1.20"
#property strict
#property description "USDJPY guarded multi-timeframe round continuation stack using M15/M3/M1 long buckets, parallel entries, and live-operation guard rails."

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
   SIGNAL_COMPRESSION = 6,
   SIGNAL_DOW_SWEEP = 7,
   SIGNAL_RANGE_RECLAIM = 8,
   SIGNAL_FRACTAL_TREND = 9,
   SIGNAL_ROUND_SHORT = 10,
   SIGNAL_RANGE_RECLAIM_SHORT = 11
  };

input string          InpSymbol                   = "USDJPY";
input ENUM_TIMEFRAMES InpSignalTimeframe          = PERIOD_M15;
input int             InpFastEMAPeriod            = 13;
input int             InpSlowEMAPeriod            = 100;
input int             InpSlowSlopeLookback        = 5;
input int             InpPivotSpan                = 2;
input int             InpTrendScanBars            = 180;
input int             InpVolatilityLookbackBars   = 24;
input double          InpMinWindowRangePips       = 15.0;
input int             InpRoundStepPips            = 50;
input bool            InpEnableRoundBucket        = true;
input int             InpSessionStartHour         = 7;
input int             InpSessionEndHour           = 22;
input double          InpMaxEma13DistancePips     = 12.0;
input double          InpMinUpperWickShare        = 0.50;
input double          InpMaxLowerWickShare        = 0.10;
input double          InpMinSlowSlopePips         = 0.0;
input double          InpStopLossPips             = 22.0;
input double          InpTargetRMultiple          = 1.5;
input int             InpMaxHoldBars              = 18;
input bool            InpAllowParallelBuckets     = true;
input int             InpMaxOpenPositions         = 3;
input bool            InpEnableRoundShortBucket   = false;
input int             InpRoundShortSessionStartHour = 7;
input int             InpRoundShortSessionEndHour = 22;
input double          InpRoundShortMaxEma13DistancePips = 12.0;
input double          InpRoundShortMinLowerWickShare = 0.50;
input double          InpRoundShortMaxUpperWickShare = 0.10;
input double          InpRoundShortMinSlowSlopePips = 0.0;
input double          InpRoundShortStopLossPips   = 22.0;
input double          InpRoundShortTargetRMultiple = 1.5;
input int             InpRoundShortMaxHoldBars    = 18;
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
input bool            InpEnableDowSweepBucket     = false;
input ENUM_TIMEFRAMES InpDowSignalTimeframe       = PERIOD_M3;
input int             InpDowSessionStartHour      = 7;
input int             InpDowSessionEndHour        = 22;
input int             InpDowPivotSpan             = 2;
input int             InpDowTrendScanBars         = 150;
input double          InpDowMinBreachPips         = 2.0;
input double          InpDowMaxBreachPips         = 12.0;
input double          InpDowMinCloseLocation      = 0.65;
input double          InpDowMinLowerWickShare     = 0.35;
input double          InpDowMaxUpperWickShare     = 0.20;
input double          InpDowStopBufferPips        = 2.0;
input double          InpDowTargetBufferPips      = 3.0;
input double          InpDowMinTargetRMultiple    = 1.0;
input int             InpDowMaxHoldBars           = 24;
input int             InpDowVolatilityLookbackBars = 80;
input double          InpDowMinWindowRangePips    = 12.0;
input int             InpDowRoundStepPips         = 50;
input double          InpDowMaxEma13DistancePips  = 6.0;
input double          InpDowMinUpperWickShare     = 0.42;
input double          InpDowMaxLowerWickShare     = 0.18;
input double          InpDowMinSlowSlopePips      = 0.0;
input double          InpDowStopLossPips          = 10.0;
input double          InpDowTargetRMultiple       = 1.2;
input double          InpDowRiskMultiplier        = 0.80;
input bool            InpDowRequireMainTrendContext = true;
input bool            InpEnableRangeReclaimBucket = false;
input ENUM_TIMEFRAMES InpRangeSignalTimeframe     = PERIOD_M1;
input int             InpRangeSessionStartHour    = 7;
input int             InpRangeSessionEndHour      = 22;
input int             InpRangeLookbackBars        = 24;
input int             InpRangeAdxPeriod           = 14;
input double          InpRangeMaxAdx             = 20.0;
input int             InpRangeAtrPeriod           = 14;
input double          InpRangeMaxWidthAtrMultiple = 3.5;
input double          InpRangeMinBreachPips       = 1.0;
input double          InpRangeMaxBreachPips       = 7.0;
input double          InpRangeMinCloseLocation    = 0.55;
input double          InpRangeMinLowerWickShare   = 0.30;
input double          InpRangeMaxUpperWickShare   = 0.25;
input double          InpRangeStopBufferPips      = 1.5;
input double          InpRangeTargetBufferPips    = 2.0;
input double          InpRangeMinTargetRMultiple  = 1.0;
input int             InpRangeMaxHoldBars         = 30;
input int             InpRangePivotSpan           = 1;
input int             InpRangeTrendScanBars       = 120;
input int             InpRangeVolatilityLookbackBars = 120;
input double          InpRangeMinWindowRangePips  = 10.0;
input int             InpRangeRoundStepPips       = 50;
input double          InpRangeMaxEma13DistancePips = 4.0;
input double          InpRangeMinUpperWickShare   = 0.35;
input double          InpRangeRoundMaxLowerWickShare = 0.22;
input double          InpRangeMinSlowSlopePips    = 0.0;
input double          InpRangeStopLossPips        = 7.0;
input double          InpRangeTargetRMultiple     = 1.0;
input double          InpRangeRiskMultiplier      = 0.60;
input bool            InpRangeRequireMainTrendContext = true;
input bool            InpRangeRequireDowTrendContext = true;
input bool            InpEnableRangeShortBucket   = false;
input bool            InpEnableFractalTrendBucket = false;
input ENUM_TIMEFRAMES InpFractalSignalTimeframe   = PERIOD_M5;
input int             InpFractalSessionStartHour  = 7;
input int             InpFractalSessionEndHour    = 20;
input int             InpFractalPivotSpan         = 2;
input int             InpFractalScanBars          = 120;
input int             InpFractalMidEMAPeriod      = 50;
input int             InpFractalSlowEMAPeriod     = 100;
input int             InpFractalStochKPeriod      = 5;
input int             InpFractalStochDPeriod      = 1;
input int             InpFractalStochSlowing      = 1;
input double          InpFractalStochBuyLevel     = 20.0;
input double          InpFractalStopBufferPips    = 1.0;
input double          InpFractalTargetBufferPips  = 2.0;
input double          InpFractalMinTargetRMultiple = 1.0;
input int             InpFractalMaxHoldBars       = 18;
input double          InpRiskPercent              = 0.30;
input bool            InpUseMicroCapRiskOverride  = true;
input double          InpMicroCapBalanceThreshold = 150.0;
input double          InpMicroCapRiskPercent      = 0.75;
input bool            InpSkipTradeWhenMinLotRiskTooHigh = true;
input double          InpMaxEffectiveRiskPercentAtMinLot = 2.0;
input bool            InpUseDailyLossCap          = true;
input double          InpDailyLossCapPercent      = 3.0;
input bool            InpFlattenOnDailyLossCap    = true;
input bool            InpUseEquityDrawdownCap     = true;
input double          InpEquityDrawdownCapPercent = 8.0;
input bool            InpFlattenOnEquityDrawdownCap = true;
input bool            InpUseConsecutiveLossCooldown = true;
input int             InpMaxConsecutiveLosses     = 3;
input int             InpLossCooldownBars         = 12;
input int             InpMaxTradesPerDay          = 6;
input double          InpMaxSpreadPips            = 2.0;
input string          InpAllowedWeekdays          = "1,2,3,4,5";
input bool            InpEnableTelemetry          = true;
input string          InpTelemetryFileName        = "mt5_company_usdjpy_20260409_round_quality_stack_guarded.csv";
input bool            InpEnableOperatorControl    = true;
input string          InpOperatorCommandFile      = "mt5_company_usdjpy_20260409_round_quality_stack_operator.txt";
input bool            InpEnableStatusSnapshot     = true;
input string          InpStatusFileName           = "mt5_company_usdjpy_20260409_round_quality_stack_status.txt";
input int             InpStatusHeartbeatSeconds   = 60;
input long            InpMagicNumber              = 20260491;

int fastEmaHandle = INVALID_HANDLE;
int slowEmaHandle = INVALID_HANDLE;
int adxHandle = INVALID_HANDLE;
int rsiHandle = INVALID_HANDLE;
int dowFastEmaHandle = INVALID_HANDLE;
int dowSlowEmaHandle = INVALID_HANDLE;
int rangeFastEmaHandle = INVALID_HANDLE;
int rangeSlowEmaHandle = INVALID_HANDLE;
int rangeAdxHandle = INVALID_HANDLE;
int rangeAtrHandle = INVALID_HANDLE;
int fractalFastEmaHandle = INVALID_HANDLE;
int fractalMidEmaHandle = INVALID_HANDLE;
int fractalSlowEmaHandle = INVALID_HANDLE;
int fractalStochHandle = INVALID_HANDLE;
string runtimeSymbol = "";
string runtimeAllowedWeekdays = "";
string runtimeTelemetryFileName = "";
string runtimeOperatorCommandFile = "";
string runtimeStatusFileName = "";
bool runtimeOperatorControlEnabled = false;
bool runtimeStatusSnapshotEnabled = false;
bool allowedWeekdays[7];
datetime lastBarTime = 0;
datetime lastDowBarTime = 0;
datetime lastRangeBarTime = 0;
datetime lastFractalBarTime = 0;
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
datetime lossCooldownUntil = 0;
double dowPlannedStopPrice = 0.0;
double dowPlannedTargetPrice = 0.0;
double rangePlannedStopPrice = 0.0;
double rangePlannedTargetPrice = 0.0;
double rangeShortPlannedStopPrice = 0.0;
double rangeShortPlannedTargetPrice = 0.0;
double fractalPlannedStopPrice = 0.0;
double fractalPlannedTargetPrice = 0.0;

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

double CalculateVolume(double stopDistance, double riskMultiplier)
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskPercent = GetEffectiveRiskPercent(equity) * MathMax(0.0, riskMultiplier);
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

bool IsNewBarForTimeframe(ENUM_TIMEFRAMES timeframe, datetime &lastSeenBarTime, datetime &barTime)
  {
   datetime times[];
   ArraySetAsSeries(times, true);
   if(CopyTime(runtimeSymbol, timeframe, 0, 2, times) < 2)
      return false;
   if(times[0] == lastSeenBarTime)
      return false;
   lastSeenBarTime = times[0];
   barTime = times[0];
   return true;
  }

bool IsNewBar(datetime &barTime)
  {
   return IsNewBarForTimeframe(InpSignalTimeframe, lastBarTime, barTime);
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
   lossCooldownUntil = 0;
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

bool IsLossCooldownBlocked()
  {
   if(!InpUseConsecutiveLossCooldown || InpMaxConsecutiveLosses <= 0 || InpLossCooldownBars <= 0)
      return false;
   return (lossCooldownUntil > TimeCurrent());
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

bool LoadDowSignalWindow(MqlRates &rates[], double &fastEma[], double &slowEma[], int count)
  {
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(fastEma, true);
   ArraySetAsSeries(slowEma, true);
   int copiedRates = CopyRates(runtimeSymbol, InpDowSignalTimeframe, 0, count, rates);
   if(copiedRates < 80)
      return false;
   int copiedFast = CopyBuffer(dowFastEmaHandle, 0, 0, count, fastEma);
   int copiedSlow = CopyBuffer(dowSlowEmaHandle, 0, 0, count, slowEma);
   return copiedFast == copiedRates && copiedSlow == copiedRates;
  }

bool LoadRangeSignalWindow(MqlRates &rates[], double &fastEma[], double &slowEma[], double &adxValues[], double &atrValues[], int count)
  {
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(fastEma, true);
   ArraySetAsSeries(slowEma, true);
   ArraySetAsSeries(adxValues, true);
   ArraySetAsSeries(atrValues, true);
   int copiedRates = CopyRates(runtimeSymbol, InpRangeSignalTimeframe, 0, count, rates);
   if(copiedRates < 80)
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
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(fastEma, true);
   ArraySetAsSeries(midEma, true);
   ArraySetAsSeries(slowEma, true);
   ArraySetAsSeries(stochK, true);
   ArraySetAsSeries(stochD, true);
   int copiedRates = CopyRates(runtimeSymbol, InpFractalSignalTimeframe, 0, count, rates);
   if(copiedRates < 80)
      return false;
   int copiedFast = CopyBuffer(fractalFastEmaHandle, 0, 0, count, fastEma);
   int copiedMid = CopyBuffer(fractalMidEmaHandle, 0, 0, count, midEma);
   int copiedSlow = CopyBuffer(fractalSlowEmaHandle, 0, 0, count, slowEma);
   int copiedK = CopyBuffer(fractalStochHandle, 0, 0, count, stochK);
   int copiedD = CopyBuffer(fractalStochHandle, 1, 0, count, stochD);
   return copiedFast == copiedRates && copiedMid == copiedRates && copiedSlow == copiedRates &&
          copiedK == copiedRates && copiedD == copiedRates;
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
      return "round_quality_m3";
   if(bucket == SIGNAL_RANGE_RECLAIM)
      return "round_quality_m1";
   if(bucket == SIGNAL_RANGE_RECLAIM_SHORT)
      return "range_reclaim_short";
   if(bucket == SIGNAL_FRACTAL_TREND)
      return "fractal_trend_long";
   if(bucket == SIGNAL_ROUND)
      return "round_quality_m15";
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

SignalBucket GetBucketFromComment(string comment)
  {
   if(StringFind(comment, "round_quality_m3") >= 0)
      return SIGNAL_DOW_SWEEP;
   if(StringFind(comment, "round_quality_m1") >= 0)
      return SIGNAL_RANGE_RECLAIM;
   if(StringFind(comment, "round_quality_m15") >= 0)
      return SIGNAL_ROUND;
   if(StringFind(comment, "round_continuation_short") >= 0)
      return SIGNAL_ROUND_SHORT;
   if(StringFind(comment, "ema_sidecar") >= 0)
      return SIGNAL_EMA;
   if(StringFind(comment, "compression_sidecar") >= 0)
      return SIGNAL_COMPRESSION;
   if(StringFind(comment, "rsi_sidecar") >= 0)
      return SIGNAL_RSI;
   if(StringFind(comment, "round_loose") >= 0)
      return SIGNAL_ROUND_LOOSE;
   if(StringFind(comment, "breakout_sidecar") >= 0)
      return SIGNAL_BREAKOUT;
   if(StringFind(comment, "range_reclaim_short") >= 0)
      return SIGNAL_RANGE_RECLAIM_SHORT;
   if(StringFind(comment, "fractal_trend") >= 0)
      return SIGNAL_FRACTAL_TREND;
   return SIGNAL_NONE;
  }

int BucketMaxHoldBars(SignalBucket bucket)
  {
   if(bucket == SIGNAL_DOW_SWEEP)
      return InpDowMaxHoldBars;
   if(bucket == SIGNAL_RANGE_RECLAIM || bucket == SIGNAL_RANGE_RECLAIM_SHORT)
      return InpRangeMaxHoldBars;
   if(bucket == SIGNAL_FRACTAL_TREND)
      return InpFractalMaxHoldBars;
   if(bucket == SIGNAL_ROUND_SHORT)
      return InpRoundShortMaxHoldBars;
   if(bucket == SIGNAL_EMA)
      return InpEmaMaxHoldBars;
   if(bucket == SIGNAL_COMPRESSION)
      return InpCompressionMaxHoldBars;
   if(bucket == SIGNAL_RSI)
      return InpRsiMaxHoldBars;
   if(bucket == SIGNAL_ROUND_LOOSE)
      return InpRoundLooseMaxHoldBars;
   if(bucket == SIGNAL_BREAKOUT)
      return InpBreakoutMaxHoldBars;
   return InpMaxHoldBars;
  }

double BucketStopLossPips(SignalBucket bucket)
  {
   if(bucket == SIGNAL_DOW_SWEEP)
      return InpDowStopLossPips;
   if(bucket == SIGNAL_RANGE_RECLAIM)
      return InpRangeStopLossPips;
   if(bucket == SIGNAL_ROUND_SHORT)
      return InpRoundShortStopLossPips;
   if(bucket == SIGNAL_EMA)
      return InpEmaStopLossPips;
   if(bucket == SIGNAL_COMPRESSION)
      return InpCompressionStopLossPips;
   if(bucket == SIGNAL_RSI)
      return InpRsiStopLossPips;
   if(bucket == SIGNAL_ROUND_LOOSE)
      return InpRoundLooseStopLossPips;
   if(bucket == SIGNAL_BREAKOUT)
      return InpBreakoutStopLossPips;
   return InpStopLossPips;
  }

double BucketTargetRMultiple(SignalBucket bucket)
  {
   if(bucket == SIGNAL_DOW_SWEEP)
      return InpDowTargetRMultiple;
   if(bucket == SIGNAL_RANGE_RECLAIM)
      return InpRangeTargetRMultiple;
   if(bucket == SIGNAL_ROUND_SHORT)
      return InpRoundShortTargetRMultiple;
   if(bucket == SIGNAL_EMA)
      return InpEmaTargetRMultiple;
   if(bucket == SIGNAL_COMPRESSION)
      return InpCompressionTargetRMultiple;
   if(bucket == SIGNAL_RSI)
      return InpRsiTargetRMultiple;
   if(bucket == SIGNAL_ROUND_LOOSE)
      return InpRoundLooseTargetRMultiple;
   if(bucket == SIGNAL_BREAKOUT)
      return InpBreakoutTargetRMultiple;
   return InpTargetRMultiple;
  }

double BucketRiskMultiplier(SignalBucket bucket)
  {
   if(bucket == SIGNAL_DOW_SWEEP)
      return InpDowRiskMultiplier;
   if(bucket == SIGNAL_RANGE_RECLAIM)
      return InpRangeRiskMultiplier;
   return 1.0;
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
      SignalBucket bucket = GetBucketFromComment(comment);
      int maxHoldBars = BucketMaxHoldBars(bucket);
      ENUM_TIMEFRAMES holdTimeframe = BucketSignalTimeframe(bucket);
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
   if(IsLossCooldownBlocked())
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

bool PassesVolatilityStateWithParams(const MqlRates &rates[], int lookbackBars, double minWindowRangePips, int roundStepPips)
  {
   int size = ArraySize(rates);
   if(size <= lookbackBars + 1)
      return false;
   double highest = rates[1].high;
   double lowest = rates[1].low;
   for(int shift = 1; shift <= lookbackBars; ++shift)
     {
      highest = MathMax(highest, rates[shift].high);
      lowest = MathMin(lowest, rates[shift].low);
     }
   double pip = GetPipSize();
   if(pip <= 0.0 || (highest - lowest) / pip < minWindowRangePips)
      return false;

   double zoneStep = roundStepPips * pip;
   if(zoneStep <= 0.0)
      return false;
   return (long)MathFloor(highest / zoneStep) != (long)MathFloor(lowest / zoneStep);
  }

bool PassesVolatilityState(const MqlRates &rates[])
  {
   return PassesVolatilityStateWithParams(rates, InpVolatilityLookbackBars, InpMinWindowRangePips, InpRoundStepPips);
  }

bool HasBullTrendContext(const MqlRates &rates[], const double &fastEma[], const double &slowEma[],
                         int pivotSpan, int scanBars, double minSlowSlopePips)
  {
   PivotPoint latestHigh, previousHigh, latestLow, previousLow;
   FindRecentPivotsWithSpan(rates, true, pivotSpan, scanBars, latestHigh, previousHigh);
   FindRecentPivotsWithSpan(rates, false, pivotSpan, scanBars, latestLow, previousLow);
   if(!latestHigh.valid || !previousHigh.valid || !latestLow.valid || !previousLow.valid)
      return false;
   if(!(latestHigh.price > previousHigh.price && latestLow.price > previousLow.price))
      return false;
   if(fastEma[1] <= slowEma[1])
      return false;
   if(rates[1].close <= slowEma[1])
      return false;

   double pip = GetPipSize();
   if(pip <= 0.0)
      return false;
   if((slowEma[1] - slowEma[1 + InpSlowSlopeLookback]) / pip < minSlowSlopePips)
      return false;
   return true;
  }

bool EvaluateRoundSignalWithParams(const MqlRates &rates[], const double &fastEma[], const double &slowEma[],
                                   int pivotSpan, int scanBars, int volLookbackBars, double minWindowRangePips,
                                   int roundStepPips, double maxEma13DistancePips, double minUpperWickShare,
                                   double maxLowerWickShare, double minSlowSlopePips)
  {
   if(!PassesVolatilityStateWithParams(rates, volLookbackBars, minWindowRangePips, roundStepPips))
      return false;

   PivotPoint latestHigh, previousHigh, latestLow, previousLow;
   FindRecentPivotsWithSpan(rates, true, pivotSpan, scanBars, latestHigh, previousHigh);
   FindRecentPivotsWithSpan(rates, false, pivotSpan, scanBars, latestLow, previousLow);
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
   if(slowSlopePips < minSlowSlopePips)
      return false;
   if(rates[1].low <= latestLow.price)
      return false;

   double emaDistancePips = MathAbs(rates[1].close - fastEma[1]) / pip;
   if(emaDistancePips > maxEma13DistancePips)
      return false;
   if(UpperWickShare(rates[1]) < minUpperWickShare)
      return false;
   if(LowerWickShare(rates[1]) > maxLowerWickShare)
      return false;
   return true;
  }

bool EvaluateRoundSignal(const MqlRates &rates[], const double &fastEma[], const double &slowEma[])
  {
   if(!InpEnableRoundBucket)
      return false;
   return EvaluateRoundSignalWithParams(rates, fastEma, slowEma,
                                        InpPivotSpan, InpTrendScanBars, InpVolatilityLookbackBars,
                                        InpMinWindowRangePips, InpRoundStepPips, InpMaxEma13DistancePips,
                                        InpMinUpperWickShare, InpMaxLowerWickShare, InpMinSlowSlopePips);
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
   if(InpDowRequireMainTrendContext &&
      !HasBullTrendContext(envRates, envFastEma, envSlowEma, InpPivotSpan, InpTrendScanBars, InpMinSlowSlopePips))
      return false;

   return EvaluateRoundSignalWithParams(signalRates, signalFastEma, signalSlowEma,
                                        InpDowPivotSpan, InpDowTrendScanBars, InpDowVolatilityLookbackBars,
                                        InpDowMinWindowRangePips, InpDowRoundStepPips, InpDowMaxEma13DistancePips,
                                        InpDowMinUpperWickShare, InpDowMaxLowerWickShare, InpDowMinSlowSlopePips);
  }

bool EvaluateRangeReclaimSignal(const MqlRates &envRates[], const double &envFastEma[], const double &envSlowEma[],
                                const MqlRates &dowRates[], const double &dowFastEma[], const double &dowSlowEma[],
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
   if(InpRangeRequireMainTrendContext &&
      !HasBullTrendContext(envRates, envFastEma, envSlowEma, InpPivotSpan, InpTrendScanBars, InpMinSlowSlopePips))
      return false;
   if(InpRangeRequireDowTrendContext &&
      !HasBullTrendContext(dowRates, dowFastEma, dowSlowEma, InpDowPivotSpan, InpDowTrendScanBars, InpDowMinSlowSlopePips))
      return false;

   return EvaluateRoundSignalWithParams(signalRates, signalFastEma, signalSlowEma,
                                        InpRangePivotSpan, InpRangeTrendScanBars, InpRangeVolatilityLookbackBars,
                                        InpRangeMinWindowRangePips, InpRangeRoundStepPips, InpRangeMaxEma13DistancePips,
                                        InpRangeMinUpperWickShare, InpRangeRoundMaxLowerWickShare,
                                        InpRangeMinSlowSlopePips);
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

bool OpenPosition(SignalBucket bucket)
  {
   double stopLossPips = BucketStopLossPips(bucket);
   double targetRMultiple = BucketTargetRMultiple(bucket);
   double riskMultiplier = BucketRiskMultiplier(bucket);
   string comment = BucketComment(bucket);
   bool isSell = BucketIsSell(bucket);
   if(bucket == SIGNAL_FRACTAL_TREND)
     {
      stopLossPips = 0.0;
      targetRMultiple = 0.0;
     }

   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   double pip = GetPipSize();
   double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   int stopsLevel = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freezeLevel = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_TRADE_FREEZE_LEVEL);
   int minDistancePoints = MathMax(stopsLevel, freezeLevel);
   double entryPrice = isSell ? bid : ask;
   if(entryPrice <= 0.0 || pip <= 0.0 || point <= 0.0)
      return false;
   double stopDistance = stopLossPips * pip;
   double targetDistance = stopDistance * targetRMultiple;
   double sl = NormalizePrice(isSell ? entryPrice + stopDistance : entryPrice - stopDistance);
   double tp = NormalizePrice(isSell ? entryPrice - targetDistance : entryPrice + targetDistance);
   if(bucket == SIGNAL_RANGE_RECLAIM_SHORT)
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
   if(stopDistance < minDistancePoints * point)
      return false;
   if(targetDistance > 0.0 && targetDistance < minDistancePoints * point)
      return false;

   double volume = CalculateVolume(stopDistance, riskMultiplier);
   if(volume <= 0.0)
      return false;
   if(isSell)
      return trade.Sell(volume, runtimeSymbol, 0.0, sl, tp, comment);
   return trade.Buy(volume, runtimeSymbol, 0.0, sl, tp, comment);
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
             (IsLossCooldownBlocked() ? 1 : 0),
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
   if(InpUseConsecutiveLossCooldown &&
      InpMaxConsecutiveLosses > 0 &&
      InpLossCooldownBars > 0 &&
      consecutiveLosses >= InpMaxConsecutiveLosses)
     {
      lossCooldownUntil = dealTime + (InpLossCooldownBars * PeriodSeconds(InpSignalTimeframe));
      dailyLossLockActivations++;
     }
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
   if(IsLossCooldownBlocked())
      return "loss_cooldown";
   if(IsDailyLossCapBlocked())
      return "daily_loss_cap";
   if(IsEquityDrawdownBlocked())
      return "equity_drawdown_cap";
   if(IsTradeCountBlocked())
      return "trade_cap";
   if(!InpAllowParallelBuckets && CountManagedPositions() > 0)
      return "position_open";
   if(InpMaxOpenPositions > 0 && CountManagedPositions() >= InpMaxOpenPositions)
      return "position_cap";

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
      "open_m15=" + IntegerToString(CountBucketPositions(SIGNAL_ROUND)) + "\r\n" +
      "open_m3=" + IntegerToString(CountBucketPositions(SIGNAL_DOW_SWEEP)) + "\r\n" +
      "open_m1=" + IntegerToString(CountBucketPositions(SIGNAL_RANGE_RECLAIM)) + "\r\n" +
      "daily_trades_opened=" + IntegerToString(dailyTradeCount) + "\r\n" +
      "daily_closed_trades=" + IntegerToString(dailyClosedTrades) + "\r\n" +
      "daily_entries_buy=" + IntegerToString(dailyEntriesBuy) + "\r\n" +
      "daily_entries_sell=" + IntegerToString(dailyEntriesSell) + "\r\n" +
      "consecutive_losses=" + IntegerToString(consecutiveLosses) + "\r\n" +
      "loss_cooldown_blocked=" + BoolText(IsLossCooldownBlocked()) + "\r\n" +
      "loss_cooldown_until=" + TimeToString(lossCooldownUntil, TIME_DATE | TIME_SECONDS) + "\r\n" +
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
      InpRoundShortSessionStartHour < 0 || InpRoundShortSessionStartHour > 23 || InpRoundShortSessionEndHour < 0 ||
      InpRoundShortSessionEndHour > 23 || InpRoundShortSessionStartHour == InpRoundShortSessionEndHour ||
      InpRoundShortMaxEma13DistancePips <= 0.0 || InpRoundShortMinLowerWickShare < 0.0 ||
      InpRoundShortMinLowerWickShare > 1.0 || InpRoundShortMaxUpperWickShare < 0.0 ||
      InpRoundShortMaxUpperWickShare > 1.0 || InpRoundShortMinLowerWickShare <= InpRoundShortMaxUpperWickShare ||
      InpRoundShortStopLossPips <= 0.0 || InpRoundShortTargetRMultiple <= 0.0 || InpRoundShortMaxHoldBars < 1 ||
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
      InpDowSessionStartHour < 0 || InpDowSessionStartHour > 23 || InpDowSessionEndHour < 0 ||
      InpDowSessionEndHour > 23 || InpDowSessionStartHour == InpDowSessionEndHour ||
      InpDowPivotSpan <= 0 || InpDowTrendScanBars <= 20 ||
      InpDowMinBreachPips < 0.0 || InpDowMaxBreachPips < InpDowMinBreachPips ||
      InpDowMinCloseLocation < 0.0 || InpDowMinCloseLocation > 1.0 ||
      InpDowMinLowerWickShare < 0.0 || InpDowMinLowerWickShare > 1.0 ||
      InpDowMaxUpperWickShare < 0.0 || InpDowMaxUpperWickShare > 1.0 ||
      InpDowStopBufferPips < 0.0 || InpDowTargetBufferPips < 0.0 ||
      InpDowMinTargetRMultiple <= 0.0 || InpDowMaxHoldBars < 1 ||
      InpDowVolatilityLookbackBars <= 0 || InpDowMinWindowRangePips <= 0.0 || InpDowRoundStepPips <= 0 ||
      InpDowMaxEma13DistancePips <= 0.0 || InpDowMinUpperWickShare < 0.0 || InpDowMinUpperWickShare > 1.0 ||
      InpDowMaxLowerWickShare < 0.0 || InpDowMaxLowerWickShare > 1.0 ||
      InpDowMinUpperWickShare <= InpDowMaxLowerWickShare || InpDowStopLossPips <= 0.0 ||
      InpDowTargetRMultiple <= 0.0 || InpDowRiskMultiplier <= 0.0 ||
      InpRangeSessionStartHour < 0 || InpRangeSessionStartHour > 23 || InpRangeSessionEndHour < 0 ||
      InpRangeSessionEndHour > 23 || InpRangeSessionStartHour == InpRangeSessionEndHour ||
      InpRangeLookbackBars < 5 || InpRangeAdxPeriod < 2 || InpRangeMaxAdx <= 0.0 ||
      InpRangeAtrPeriod < 2 || InpRangeMaxWidthAtrMultiple <= 0.0 ||
      InpRangeMinBreachPips < 0.0 || InpRangeMaxBreachPips < InpRangeMinBreachPips ||
      InpRangeMinCloseLocation < 0.0 || InpRangeMinCloseLocation > 1.0 ||
      InpRangeMinLowerWickShare < 0.0 || InpRangeMinLowerWickShare > 1.0 ||
      InpRangeMaxUpperWickShare < 0.0 || InpRangeMaxUpperWickShare > 1.0 ||
      InpRangeStopBufferPips < 0.0 || InpRangeTargetBufferPips < 0.0 ||
      InpRangeMinTargetRMultiple <= 0.0 || InpRangeMaxHoldBars < 1 ||
      InpRangePivotSpan <= 0 || InpRangeTrendScanBars <= 20 || InpRangeVolatilityLookbackBars <= 0 ||
      InpRangeMinWindowRangePips <= 0.0 || InpRangeRoundStepPips <= 0 ||
      InpRangeMaxEma13DistancePips <= 0.0 || InpRangeMinUpperWickShare < 0.0 || InpRangeMinUpperWickShare > 1.0 ||
      InpRangeRoundMaxLowerWickShare < 0.0 || InpRangeRoundMaxLowerWickShare > 1.0 ||
      InpRangeMinUpperWickShare <= InpRangeRoundMaxLowerWickShare || InpRangeStopLossPips <= 0.0 ||
      InpRangeTargetRMultiple <= 0.0 || InpRangeRiskMultiplier <= 0.0 ||
      InpFractalSessionStartHour < 0 || InpFractalSessionStartHour > 23 || InpFractalSessionEndHour < 0 ||
      InpFractalSessionEndHour > 23 || InpFractalSessionStartHour == InpFractalSessionEndHour ||
      InpFractalPivotSpan <= 0 || InpFractalScanBars <= 20 || InpFractalMidEMAPeriod <= InpFastEMAPeriod ||
      InpFractalSlowEMAPeriod <= InpFractalMidEMAPeriod || InpFractalStochKPeriod < 2 ||
      InpFractalStochDPeriod < 1 || InpFractalStochSlowing < 1 ||
      InpFractalStochBuyLevel <= 0.0 || InpFractalStochBuyLevel >= 100.0 ||
      InpFractalStopBufferPips < 0.0 || InpFractalTargetBufferPips < 0.0 ||
      InpFractalMinTargetRMultiple <= 0.0 || InpFractalMaxHoldBars < 1 ||
      InpStopLossPips <= 0.0 || InpTargetRMultiple <= 0.0 || InpMaxHoldBars < 1 ||
      InpMaxOpenPositions < 1 || InpRiskPercent <= 0.0 ||
      InpMicroCapBalanceThreshold < 0.0 || InpMicroCapRiskPercent <= 0.0 || InpDailyLossCapPercent <= 0.0 ||
      InpEquityDrawdownCapPercent < 0.0 || InpMaxTradesPerDay < 0 || InpMaxSpreadPips <= 0.0 || InpMagicNumber <= 0 ||
      InpMaxConsecutiveLosses < 0 || InpLossCooldownBars < 0 ||
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
   dowFastEmaHandle = iMA(runtimeSymbol, InpDowSignalTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   dowSlowEmaHandle = iMA(runtimeSymbol, InpDowSignalTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   rangeFastEmaHandle = iMA(runtimeSymbol, InpRangeSignalTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   rangeSlowEmaHandle = iMA(runtimeSymbol, InpRangeSignalTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   rangeAdxHandle = iADX(runtimeSymbol, InpRangeSignalTimeframe, InpRangeAdxPeriod);
   rangeAtrHandle = iATR(runtimeSymbol, InpRangeSignalTimeframe, InpRangeAtrPeriod);
   fractalFastEmaHandle = iMA(runtimeSymbol, InpFractalSignalTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   fractalMidEmaHandle = iMA(runtimeSymbol, InpFractalSignalTimeframe, InpFractalMidEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   fractalSlowEmaHandle = iMA(runtimeSymbol, InpFractalSignalTimeframe, InpFractalSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   fractalStochHandle = iStochastic(runtimeSymbol, InpFractalSignalTimeframe, InpFractalStochKPeriod, InpFractalStochDPeriod,
                                    InpFractalStochSlowing, MODE_SMA, STO_LOWHIGH);
   if(fastEmaHandle == INVALID_HANDLE || slowEmaHandle == INVALID_HANDLE || adxHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE ||
      dowFastEmaHandle == INVALID_HANDLE || dowSlowEmaHandle == INVALID_HANDLE ||
      rangeFastEmaHandle == INVALID_HANDLE || rangeSlowEmaHandle == INVALID_HANDLE ||
      rangeAdxHandle == INVALID_HANDLE || rangeAtrHandle == INVALID_HANDLE ||
      fractalFastEmaHandle == INVALID_HANDLE || fractalMidEmaHandle == INVALID_HANDLE ||
      fractalSlowEmaHandle == INVALID_HANDLE || fractalStochHandle == INVALID_HANDLE)
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
   if(dowFastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(dowFastEmaHandle);
   if(dowSlowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(dowSlowEmaHandle);
   if(rangeFastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(rangeFastEmaHandle);
   if(rangeSlowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(rangeSlowEmaHandle);
   if(rangeAdxHandle != INVALID_HANDLE)
      IndicatorRelease(rangeAdxHandle);
   if(rangeAtrHandle != INVALID_HANDLE)
      IndicatorRelease(rangeAtrHandle);
   if(fractalFastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(fractalFastEmaHandle);
   if(fractalMidEmaHandle != INVALID_HANDLE)
      IndicatorRelease(fractalMidEmaHandle);
   if(fractalSlowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(fractalSlowEmaHandle);
   if(fractalStochHandle != INVALID_HANDLE)
      IndicatorRelease(fractalStochHandle);
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
   bool newMainBar = IsNewBar(barTime);
   datetime dowBarTime = 0;
   bool newDowBar = false;
   if(InpEnableDowSweepBucket)
      newDowBar = IsNewBarForTimeframe(InpDowSignalTimeframe, lastDowBarTime, dowBarTime);
   datetime rangeBarTime = 0;
   bool newRangeBar = false;
   if(InpEnableRangeReclaimBucket)
      newRangeBar = IsNewBarForTimeframe(InpRangeSignalTimeframe, lastRangeBarTime, rangeBarTime);
   datetime fractalBarTime = 0;
   bool newFractalBar = false;
   if(InpEnableFractalTrendBucket)
      newFractalBar = IsNewBarForTimeframe(InpFractalSignalTimeframe, lastFractalBarTime, fractalBarTime);
   if(!newMainBar && !newDowBar && !newRangeBar && !newFractalBar)
      return;

   if(CountManagedPositions() > 0)
      ManageOpenPosition();

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

   int baseOpenCount = CountManagedPositions();
   int pendingOpenCount = 0;

   if(newMainBar && CanOpenAnotherTrade(barTime))
     {
      MqlRates rates[];
      double fastEma[];
      double slowEma[];
      double adxValues[];
      double rsiValues[];
      if(LoadSignalWindow(rates, fastEma, slowEma, adxValues, rsiValues, 260))
        {
         SignalBucket buckets[7];
         int bucketCount = 0;
         if(EvaluateRoundSignal(rates, fastEma, slowEma))
            buckets[bucketCount++] = SIGNAL_ROUND;
         if(EvaluateRoundShortSignal(rates, fastEma, slowEma))
            buckets[bucketCount++] = SIGNAL_ROUND_SHORT;
         if(EvaluateEmaSignal(rates, fastEma, slowEma, adxValues))
            buckets[bucketCount++] = SIGNAL_EMA;
         if(EvaluateCompressionSignal(rates, fastEma, slowEma, adxValues))
            buckets[bucketCount++] = SIGNAL_COMPRESSION;
         if(EvaluateRsiSignal(rates, fastEma, slowEma, rsiValues))
            buckets[bucketCount++] = SIGNAL_RSI;
         if(EvaluateBreakoutSignal(rates, fastEma, slowEma))
            buckets[bucketCount++] = SIGNAL_BREAKOUT;
         if(EvaluateRoundLooseSignal(rates, fastEma, slowEma))
            buckets[bucketCount++] = SIGNAL_ROUND_LOOSE;

         for(int i = 0; i < bucketCount; ++i)
           {
            SignalBucket bucket = buckets[i];
            if(InpMaxTradesPerDay > 0 && dailyTradeCount + pendingOpenCount >= InpMaxTradesPerDay)
               break;
            if(!CanOpenBucketTrade(bucket, baseOpenCount, pendingOpenCount))
               continue;
            if(OpenPosition(bucket))
               pendingOpenCount++;
           }
        }
     }

   if(newDowBar && CanOpenAnotherTrade(dowBarTime))
     {
      if(InpMaxTradesPerDay <= 0 || dailyTradeCount + pendingOpenCount < InpMaxTradesPerDay)
        {
         MqlRates envRates[];
         double envFastEma[];
         double envSlowEma[];
         double envAdxValues[];
         double envRsiValues[];
         MqlRates dowRates[];
         double dowFastEma[];
         double dowSlowEma[];
         if(LoadSignalWindow(envRates, envFastEma, envSlowEma, envAdxValues, envRsiValues, 260) &&
            LoadDowSignalWindow(dowRates, dowFastEma, dowSlowEma, 220))
           {
            if(CanOpenBucketTrade(SIGNAL_DOW_SWEEP, baseOpenCount, pendingOpenCount) &&
               EvaluateDowSweepSignal(envRates, envFastEma, envSlowEma, dowRates, dowFastEma, dowSlowEma))
              {
               if(OpenPosition(SIGNAL_DOW_SWEEP))
                  pendingOpenCount++;
              }
           }
        }
     }

   if(newRangeBar && CanOpenAnotherTrade(rangeBarTime))
     {
      if(InpMaxTradesPerDay <= 0 || dailyTradeCount + pendingOpenCount < InpMaxTradesPerDay)
        {
         MqlRates envRates[];
         double envFastEma[];
         double envSlowEma[];
         double envAdxValues[];
         double envRsiValues[];
         MqlRates dowRates[];
         double dowFastEma[];
         double dowSlowEma[];
         MqlRates rangeRates[];
         double rangeFastEma[];
         double rangeSlowEma[];
         double rangeAdx[];
         double rangeAtr[];
         if(LoadSignalWindow(envRates, envFastEma, envSlowEma, envAdxValues, envRsiValues, 260) &&
            LoadDowSignalWindow(dowRates, dowFastEma, dowSlowEma, 220) &&
            LoadRangeSignalWindow(rangeRates, rangeFastEma, rangeSlowEma, rangeAdx, rangeAtr, 220))
           {
            if(CanOpenBucketTrade(SIGNAL_RANGE_RECLAIM, baseOpenCount, pendingOpenCount) &&
               EvaluateRangeReclaimSignal(envRates, envFastEma, envSlowEma, dowRates, dowFastEma, dowSlowEma,
                                          rangeRates, rangeFastEma, rangeSlowEma, rangeAdx, rangeAtr))
              {
               if(OpenPosition(SIGNAL_RANGE_RECLAIM))
                  pendingOpenCount++;
              }
            if(CanOpenBucketTrade(SIGNAL_RANGE_RECLAIM_SHORT, baseOpenCount, pendingOpenCount) &&
               EvaluateRangeReclaimShortSignal(envRates, envFastEma, envSlowEma, rangeRates, rangeFastEma, rangeSlowEma, rangeAdx, rangeAtr))
              {
               if(OpenPosition(SIGNAL_RANGE_RECLAIM_SHORT))
                  pendingOpenCount++;
              }
           }
        }
     }

   if(newFractalBar && CanOpenAnotherTrade(fractalBarTime))
     {
      if(InpMaxTradesPerDay <= 0 || dailyTradeCount + pendingOpenCount < InpMaxTradesPerDay)
        {
         MqlRates envRates[];
         double envFastEma[];
         double envSlowEma[];
         double envAdxValues[];
         double envRsiValues[];
         MqlRates fractalRates[];
         double fractalFastEma[];
         double fractalMidEma[];
         double fractalSlowEma[];
         double stochK[];
         double stochD[];
         if(LoadSignalWindow(envRates, envFastEma, envSlowEma, envAdxValues, envRsiValues, 260) &&
            LoadFractalSignalWindow(fractalRates, fractalFastEma, fractalMidEma, fractalSlowEma, stochK, stochD, 220))
           {
            if(CanOpenBucketTrade(SIGNAL_FRACTAL_TREND, baseOpenCount, pendingOpenCount) &&
               EvaluateFractalTrendSignal(envRates, envFastEma, envSlowEma, fractalRates, fractalFastEma, fractalMidEma, fractalSlowEma, stochK, stochD))
              {
               if(OpenPosition(SIGNAL_FRACTAL_TREND))
                  pendingOpenCount++;
              }
           }
        }
     }
  }
