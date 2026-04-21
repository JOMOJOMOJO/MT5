//+------------------------------------------------------------------+
//| USDJPY Tokyo-London Session Box Breakout Engine                  |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Standalone Tokyo box / London breakout engine."

#include <Trade\Trade.mqh>

CTrade trade;

enum TradeBiasMode
  {
   TRADE_BIAS_SHORT_ONLY = 0,
   TRADE_BIAS_LONG_ONLY = 1,
   TRADE_BIAS_BOTH = 2
  };

enum BreakoutTriggerMode
  {
   EXEC_RANGE_CLOSE_CONFIRM = 0,
   EXEC_RANGE_RETEST_CONFIRM = 1,
   EXEC_BREAKOUT_BAR_CONTINUATION = 2
  };

enum PartialTargetLevel
  {
   PARTIAL_TARGET_382 = 382,
   PARTIAL_TARGET_500 = 500
  };

enum FinalTargetMode
  {
   FINAL_TARGET_SESSION_EXTENSION = 0,
   FINAL_TARGET_FIXED_R = 1
  };

struct SessionContext
  {
   bool      valid;
   int       sessionDayId;
   string    sessionTypeLabel;
   string    rangeTimeframeLabel;
   string    executionTimeframeLabel;
   string    volatilityBucket;
   string    boxWidthBucket;
   string    weekdayLabel;
   datetime  rangeStart;
   datetime  rangeEnd;
   datetime  breakoutStart;
   datetime  breakoutEnd;
   double    rangeHigh;
   double    rangeLow;
   double    rangeMid;
   double    rangeHeight;
   double    rangePips;
   double    rangeAtr;
   double    rangeAtrPips;
   double    boxWidthAtrRatio;
   double    executionAtr;
   double    executionAtrPips;
   double    breakoutBuffer;
   double    retestTolerance;
   double    previousDayHigh;
   double    previousDayLow;
   double    m30PriorSwingHigh;
   double    m30PriorSwingLow;
   bool      breakoutWindowActive;
   bool      breakoutWindowExpired;
   int       rangeBarCount;
  };

struct BreakoutSetup
  {
   bool      valid;
   int       sessionDayId;
   int       direction;
   string    sideLabel;
   string    sessionTypeLabel;
   string    breakoutSideLabel;
   string    breakoutTypeLabel;
   string    breakoutStateLabel;
   string    volatilityBucket;
   string    boxWidthBucket;
   string    prevDayAlignmentType;
   string    m30SwingAlignmentType;
   string    weekdayLabel;
   string    rangeTimeframeLabel;
   string    executionTimeframeLabel;
   double    rangeHigh;
   double    rangeLow;
   double    boxWidthPips;
   double    boxWidthAtrRatio;
   double    breakoutLevel;
   double    stopAnchor;
   double    invalidationLevel;
   double    structureHeight;
   double    structureHeightPips;
   double    rangeAtrPips;
   datetime  setupTime;
  };

struct ExecutionTrigger
  {
   bool      fired;
   string    triggerLabel;
   string    triggerTypeLabel;
   string    breakoutStrengthBucket;
   string    breakoutTimingBucket;
   double    entryPrice;
   double    setupToEntryPips;
   double    breakoutCloseDistancePips;
   double    breakoutCloseDistanceAtr;
   int       barsFromSetupToEntry;
   int       londonMinutesFromOpen;
   double    referenceLevel;
  };

struct PendingExecutionContext
  {
   bool      valid;
   int       sessionDayId;
   BreakoutSetup setup;
   double    setupBaselineEntry;
   datetime  detectedTime;
   bool      breakoutSeen;
   datetime  breakoutTime;
   double    breakoutBarExtreme;
   double    breakoutCloseDistancePips;
   double    breakoutCloseDistanceAtr;
   int       londonMinutesFromOpen;
   string    breakoutStrengthBucket;
   string    breakoutTimingBucket;
   double    recentSwingLevel;
   string    recentSwingLabel;
  };

struct EntryPlan
  {
   bool      valid;
   int       direction;
   int       sessionDayId;
   string    sideLabel;
   string    sessionTypeLabel;
   string    breakoutSideLabel;
   string    breakoutTypeLabel;
   string    breakoutStateLabel;
   string    executionTriggerLabel;
   string    triggerTypeLabel;
   string    rangeTimeframeLabel;
   string    executionTimeframeLabel;
   string    partialTargetLabel;
   string    finalTargetLabel;
   string    volatilityBucket;
   string    boxWidthBucket;
   string    breakoutStrengthBucket;
   string    breakoutTimingBucket;
   string    prevDayAlignmentType;
   string    m30SwingAlignmentType;
   string    weekdayLabel;
   double    rangeHigh;
   double    rangeLow;
   double    breakoutLevel;
   double    boxWidthPips;
   double    boxWidthAtrRatio;
   double    structureHeightPips;
   double    rangeAtrPips;
   double    breakoutCloseDistancePips;
   double    breakoutCloseDistanceAtr;
   double    invalidationLevel;
   double    setupBaselineEntry;
   double    setupToEntryPips;
   double    entry;
   double    stop;
   double    target;
   double    partialTarget;
   bool      usePartial;
   bool      runnerTargetEnabled;
   double    stopDistancePips;
   double    plannedRiskAmount;
   int       barsFromSetupToEntry;
   int       londonMinutesFromOpen;
   string    reason;
  };

input string              InpSymbol                   = "USDJPY";
input ENUM_TIMEFRAMES     InpRangeTimeframe           = PERIOD_M15;
input ENUM_TIMEFRAMES     InpExecutionTimeframe       = PERIOD_M5;
input int                 InpRangeATRPeriod           = 14;
input int                 InpExecutionATRPeriod       = 14;
input int                 InpRangeStartHour           = 0;
input int                 InpRangeEndHour             = 7;
input int                 InpBreakoutStartHour        = 7;
input int                 InpBreakoutEndHour          = 16;
input int                 InpRangeScanBars            = 96;
input int                 InpExecutionScanBars        = 48;
input double              InpMinRangePips             = 5.0;
input double              InpMaxRangePips             = 22.0;
input double              InpBreakoutBufferATR        = 0.08;
input double              InpMinBreakoutBufferPips    = 0.6;
input double              InpRetestTolerancePips      = 0.8;
input TradeBiasMode       InpTradeBiasMode            = TRADE_BIAS_BOTH;
input BreakoutTriggerMode InpBreakoutTriggerMode      = EXEC_RANGE_CLOSE_CONFIRM;
input PartialTargetLevel  InpPartialTargetLevel       = PARTIAL_TARGET_382;
input FinalTargetMode     InpFinalTargetMode          = FINAL_TARGET_SESSION_EXTENSION;
input double              InpTargetRMultiple          = 1.20;
input double              InpMinStopBufferPips        = 1.2;
input double              InpStopBufferATR            = 0.10;
input double              InpAcceptanceExitBufferPips = 0.5;
input double              InpHybridPartialFraction    = 0.50;
input int                 InpMaxHoldBars              = 24;
input double              InpRiskPercent              = 0.35;
input bool                InpOneTradePerSessionDay    = true;
input int                 InpSessionStartHour         = 0;
input int                 InpSessionEndHour           = 0;
input double              InpMaxSpreadPips            = 2.0;
input bool                InpEnableTelemetry          = true;
input string              InpTelemetryFileName        = "mt5_company_usdjpy_20260421_tokyo_london_box_breakout.csv";
input long                InpMagicNumber              = 202604211;

string runtimeSymbol = "";
string runtimeTelemetryFileName = "";
datetime lastExecutionBarTime = 0;
int rangeAtrHandle = INVALID_HANDLE;
int executionAtrHandle = INVALID_HANDLE;
int telemetryHandle = INVALID_HANDLE;
int lastTradeSessionDayId = -1;

EntryPlan pendingPlan;
EntryPlan activePlan;
PendingExecutionContext pendingLongExecution;
PendingExecutionContext pendingShortExecution;
bool hasPendingPlan = false;
bool activePartialTaken = false;
bool activeBreakEvenMoved = false;
bool pendingPartialExit = false;
string pendingExitReason = "";
datetime activeEntryTime = 0;
double activePlannedRiskAmount = 0.0;
int activeBarsToPartial = -1;
int activeBarsToFinal = -1;
int activeBarsToTimeStop = -1;
double activeMfePips = 0.0;
double activeMaePips = 0.0;
double activeMaxUnrealizedR = 0.0;
double activeMinUnrealizedR = 0.0;
datetime activeLastDiagnosticBarTime = 0;
int activeAcceptedOutsideBoxBars = 0;
int activeFailedBackInsideBoxBars = 0;
double activeMfeBeforeAcceptanceExit = 0.0;
double activeMaeBeforeAcceptanceExit = 0.0;

string NormalizePresetString(string rawValue)
  {
   int marker = StringFind(rawValue, "||");
   if(marker < 0)
      return rawValue;
   return StringSubstr(rawValue, 0, marker);
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

double PipsToPrice(double pips)
  {
   return pips * GetPipSize();
  }

double GetSpreadPips()
  {
   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   double pip = GetPipSize();
   if(ask <= 0.0 || bid <= 0.0 || pip <= 0.0)
      return DBL_MAX;
   return (ask - bid) / pip;
  }

bool HourInWindow(int hour, int startHour, int endHour)
  {
   if(startHour == endHour)
      return true;
   if(startHour < endHour)
      return (hour >= startHour && hour < endHour);
   return (hour >= startHour || hour < endHour);
  }

bool LoadSingleBuffer(int handle, int shift, double &value)
  {
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handle, 0, shift, 1, buffer) != 1)
      return false;
   value = buffer[0];
   return true;
  }

string VolatilityBucket(double atrPips)
  {
   if(atrPips < 5.0)
      return "quiet";
   if(atrPips < 9.0)
      return "normal";
   return "expanded";
  }

string TimeframeLabel(ENUM_TIMEFRAMES tf)
  {
   switch(tf)
     {
      case PERIOD_M3: return "m3";
      case PERIOD_M5: return "m5";
      case PERIOD_M10: return "m10";
      case PERIOD_M15: return "m15";
      case PERIOD_M30: return "m30";
      case PERIOD_H1: return "h1";
      default: return EnumToString(tf);
     }
  }

string BreakoutTriggerModeLabel(BreakoutTriggerMode mode)
  {
   switch(mode)
     {
      case EXEC_RANGE_RETEST_CONFIRM: return "exec_range_retest_confirm";
      case EXEC_BREAKOUT_BAR_CONTINUATION: return "exec_breakout_bar_continuation";
      default: return "exec_range_close_confirm";
     }
  }

string PartialTargetLevelLabel(PartialTargetLevel level)
  {
   if(level == PARTIAL_TARGET_500)
      return "partial_box_500";
   return "partial_box_382";
  }

string FinalTargetModeLabel(FinalTargetMode mode)
  {
   if(mode == FINAL_TARGET_FIXED_R)
      return "final_fixed_r";
   return "final_session_extension";
  }

string WeekdayLabel(datetime timeValue)
  {
   MqlDateTime tm;
   TimeToStruct(timeValue, tm);
   switch(tm.day_of_week)
     {
      case 1: return "Mon";
      case 2: return "Tue";
      case 3: return "Wed";
      case 4: return "Thu";
      case 5: return "Fri";
      case 6: return "Sat";
      default: return "Sun";
     }
  }

string BoxWidthBucket(double atrRatio)
  {
   if(atrRatio <= 0.0)
      return "unknown";
   if(atrRatio < 0.85)
      return "narrow";
   if(atrRatio < 1.35)
      return "normal";
   return "wide";
  }

string BreakoutStrengthBucket(double distanceAtr)
  {
   if(distanceAtr <= 0.0)
      return "unknown";
   if(distanceAtr < 0.20)
      return "weak_close";
   if(distanceAtr < 0.45)
      return "medium_close";
   return "strong_close";
  }

string BreakoutTimingBucket(int londonMinutesFromOpen)
  {
   if(londonMinutesFromOpen < 0)
      return "unknown";
   if(londonMinutesFromOpen < 30)
      return "0_30m";
   if(londonMinutesFromOpen < 60)
      return "30_60m";
   return "60m_plus";
  }

bool IsPivotHigh(string symbol, ENUM_TIMEFRAMES tf, int shift, int span)
  {
   double center = iHigh(symbol, tf, shift);
   if(center <= 0.0)
      return false;

   for(int i = 1; i <= span; ++i)
     {
      if(center <= iHigh(symbol, tf, shift - i))
         return false;
      if(center <= iHigh(symbol, tf, shift + i))
         return false;
     }
   return true;
  }

bool IsPivotLow(string symbol, ENUM_TIMEFRAMES tf, int shift, int span)
  {
   double center = iLow(symbol, tf, shift);
   if(center <= 0.0)
      return false;

   for(int i = 1; i <= span; ++i)
     {
      if(center >= iLow(symbol, tf, shift - i))
         return false;
      if(center >= iLow(symbol, tf, shift + i))
         return false;
     }
   return true;
  }

bool FindLatestConfirmedPivotLevelBeforeTime(ENUM_TIMEFRAMES tf,
                                             bool wantHigh,
                                             datetime beforeTime,
                                             int span,
                                             int scanBars,
                                             double &price)
  {
   price = 0.0;
   int bars = Bars(runtimeSymbol, tf);
   if(bars <= span * 3 + 5)
      return false;

   int maxShift = MathMin(scanBars, bars - span - 2);
   for(int shift = span + 1; shift <= maxShift; ++shift)
     {
      datetime barTime = iTime(runtimeSymbol, tf, shift);
      if(barTime <= 0)
         break;
      if(barTime >= beforeTime)
         continue;

      bool isPivot = wantHigh ? IsPivotHigh(runtimeSymbol, tf, shift, span)
                              : IsPivotLow(runtimeSymbol, tf, shift, span);
      if(!isPivot)
         continue;

      price = wantHigh ? iHigh(runtimeSymbol, tf, shift) : iLow(runtimeSymbol, tf, shift);
      return (price > 0.0);
     }

   return false;
  }

bool CollectPreviousDayRange(datetime referenceTime, double &dayHigh, double &dayLow)
  {
   dayHigh = 0.0;
   dayLow = 0.0;

   datetime previousDayTime = referenceTime - 86400;
   int previousDayId = BuildDayId(previousDayTime);
   bool found = false;
   double highValue = -DBL_MAX;
   double lowValue = DBL_MAX;
   int bars = Bars(runtimeSymbol, InpRangeTimeframe);
   int maxShift = MathMin(bars - 1, InpRangeScanBars * 6);

   for(int shift = 1; shift <= maxShift; ++shift)
     {
      datetime barTime = iTime(runtimeSymbol, InpRangeTimeframe, shift);
      if(barTime <= 0)
         break;

      int barDayId = BuildDayId(barTime);
      if(barDayId > previousDayId)
         continue;
      if(barDayId < previousDayId && found)
         break;
      if(barDayId != previousDayId)
         continue;

      double barHigh = iHigh(runtimeSymbol, InpRangeTimeframe, shift);
      double barLow = iLow(runtimeSymbol, InpRangeTimeframe, shift);
      if(barHigh <= 0.0 || barLow <= 0.0)
         continue;

      if(barHigh > highValue)
         highValue = barHigh;
      if(barLow < lowValue)
         lowValue = barLow;
      found = true;
     }

   if(!found || highValue <= lowValue)
      return false;

   dayHigh = highValue;
   dayLow = lowValue;
   return true;
  }

double AlignmentThresholdPips(const SessionContext &ctx)
  {
   return MathMax(2.0, MathMin(6.0, ctx.rangeAtrPips * 0.25));
  }

string BuildAlignmentType(int direction, double breakoutLevel, double referenceLevel, double thresholdPips, string nearPrefix, string farPrefix)
  {
   if(referenceLevel <= 0.0)
      return "unavailable";

   double distancePips = MathAbs(breakoutLevel - referenceLevel) / GetPipSize();
   if(distancePips <= thresholdPips)
      return nearPrefix;
   return farPrefix;
  }

void RecordBreakoutDiagnostics(PendingExecutionContext &ctx,
                               const SessionContext &sessionCtx,
                               datetime breakoutBarTime,
                               double breakoutClosePrice)
  {
   if(!ctx.valid)
      return;

   double distancePips = 0.0;
   if(ctx.setup.direction > 0)
      distancePips = (breakoutClosePrice - ctx.setup.breakoutLevel) / GetPipSize();
   else
      distancePips = (ctx.setup.breakoutLevel - breakoutClosePrice) / GetPipSize();
   if(distancePips < 0.0)
      distancePips = 0.0;

   ctx.breakoutCloseDistancePips = distancePips;
   ctx.breakoutCloseDistanceAtr = (sessionCtx.executionAtrPips > 0.0) ? (distancePips / sessionCtx.executionAtrPips) : 0.0;
   ctx.londonMinutesFromOpen = (int)((breakoutBarTime - sessionCtx.breakoutStart) / 60);
   ctx.breakoutStrengthBucket = BreakoutStrengthBucket(ctx.breakoutCloseDistanceAtr);
   ctx.breakoutTimingBucket = BreakoutTimingBucket(ctx.londonMinutesFromOpen);
  }

void ResetBreakoutSetup(BreakoutSetup &setup)
  {
   setup.valid = false;
   setup.sessionDayId = -1;
   setup.direction = 0;
   setup.sideLabel = "";
   setup.sessionTypeLabel = "";
   setup.breakoutSideLabel = "";
   setup.breakoutTypeLabel = "";
   setup.breakoutStateLabel = "";
   setup.volatilityBucket = "";
   setup.boxWidthBucket = "";
   setup.prevDayAlignmentType = "";
   setup.m30SwingAlignmentType = "";
   setup.weekdayLabel = "";
   setup.rangeTimeframeLabel = "";
   setup.executionTimeframeLabel = "";
   setup.rangeHigh = 0.0;
   setup.rangeLow = 0.0;
   setup.boxWidthPips = 0.0;
   setup.boxWidthAtrRatio = 0.0;
   setup.breakoutLevel = 0.0;
   setup.stopAnchor = 0.0;
   setup.invalidationLevel = 0.0;
   setup.structureHeight = 0.0;
   setup.structureHeightPips = 0.0;
   setup.rangeAtrPips = 0.0;
   setup.setupTime = 0;
  }

void ResetPendingExecution(PendingExecutionContext &ctx)
  {
   ctx.valid = false;
   ctx.sessionDayId = -1;
   ResetBreakoutSetup(ctx.setup);
   ctx.setupBaselineEntry = 0.0;
   ctx.detectedTime = 0;
   ctx.breakoutSeen = false;
   ctx.breakoutTime = 0;
   ctx.breakoutBarExtreme = 0.0;
   ctx.breakoutCloseDistancePips = 0.0;
   ctx.breakoutCloseDistanceAtr = 0.0;
   ctx.londonMinutesFromOpen = -1;
   ctx.breakoutStrengthBucket = "";
   ctx.breakoutTimingBucket = "";
   ctx.recentSwingLevel = 0.0;
   ctx.recentSwingLabel = "";
  }

void ResetEntryPlan(EntryPlan &plan)
  {
   plan.valid = false;
   plan.direction = 0;
   plan.sessionDayId = -1;
   plan.sideLabel = "";
   plan.sessionTypeLabel = "";
   plan.breakoutSideLabel = "";
   plan.breakoutTypeLabel = "";
   plan.breakoutStateLabel = "";
   plan.executionTriggerLabel = "";
   plan.triggerTypeLabel = "";
   plan.rangeTimeframeLabel = "";
   plan.executionTimeframeLabel = "";
   plan.partialTargetLabel = "";
   plan.finalTargetLabel = "";
   plan.volatilityBucket = "";
   plan.boxWidthBucket = "";
   plan.breakoutStrengthBucket = "";
   plan.breakoutTimingBucket = "";
   plan.prevDayAlignmentType = "";
   plan.m30SwingAlignmentType = "";
   plan.weekdayLabel = "";
   plan.rangeHigh = 0.0;
   plan.rangeLow = 0.0;
   plan.breakoutLevel = 0.0;
   plan.boxWidthPips = 0.0;
   plan.boxWidthAtrRatio = 0.0;
   plan.structureHeightPips = 0.0;
   plan.rangeAtrPips = 0.0;
   plan.breakoutCloseDistancePips = 0.0;
   plan.breakoutCloseDistanceAtr = 0.0;
   plan.invalidationLevel = 0.0;
   plan.setupBaselineEntry = 0.0;
   plan.setupToEntryPips = 0.0;
   plan.entry = 0.0;
   plan.stop = 0.0;
   plan.target = 0.0;
   plan.partialTarget = 0.0;
   plan.usePartial = false;
   plan.runnerTargetEnabled = false;
   plan.stopDistancePips = 0.0;
   plan.plannedRiskAmount = 0.0;
   plan.barsFromSetupToEntry = -1;
   plan.londonMinutesFromOpen = -1;
   plan.reason = "";
  }

void ResetTradeRuntimeState()
  {
   activePartialTaken = false;
   activeBreakEvenMoved = false;
   pendingPartialExit = false;
   pendingExitReason = "";
   activeEntryTime = 0;
   activePlannedRiskAmount = 0.0;
   activeBarsToPartial = -1;
   activeBarsToFinal = -1;
   activeBarsToTimeStop = -1;
   activeMfePips = 0.0;
   activeMaePips = 0.0;
   activeMaxUnrealizedR = 0.0;
   activeMinUnrealizedR = 0.0;
   activeLastDiagnosticBarTime = 0;
   activeAcceptedOutsideBoxBars = 0;
   activeFailedBackInsideBoxBars = 0;
   activeMfeBeforeAcceptanceExit = 0.0;
   activeMaeBeforeAcceptanceExit = 0.0;
  }

bool IsNewBar(ENUM_TIMEFRAMES tf, datetime &lastSeenBarTime, datetime &barTime)
  {
   datetime times[];
   ArraySetAsSeries(times, true);
   if(CopyTime(runtimeSymbol, tf, 0, 2, times) < 2)
      return false;
   if(times[0] == lastSeenBarTime)
      return false;
   lastSeenBarTime = times[0];
   barTime = times[0];
   return true;
  }

int BuildDayId(datetime timeValue)
  {
   MqlDateTime tm;
   TimeToStruct(timeValue, tm);
   return tm.year * 10000 + tm.mon * 100 + tm.day;
  }

datetime BuildDateTime(datetime referenceTime, int hour)
  {
   MqlDateTime tm;
   TimeToStruct(referenceTime, tm);
   tm.hour = hour;
   tm.min = 0;
   tm.sec = 0;
   return StructToTime(tm);
  }

bool CollectSessionRange(datetime fromTime, datetime toTime, double &rangeHigh, double &rangeLow, int &barCount)
  {
   rangeHigh = -DBL_MAX;
   rangeLow = DBL_MAX;
   barCount = 0;

   int bars = Bars(runtimeSymbol, InpRangeTimeframe);
   if(bars <= 2)
      return false;

   int endShift = MathMin(bars - 1, InpRangeScanBars);
   for(int shift = 1; shift <= endShift; ++shift)
     {
      datetime barTime = iTime(runtimeSymbol, InpRangeTimeframe, shift);
      if(barTime <= 0)
         break;
      if(barTime >= toTime)
         continue;
      if(barTime < fromTime)
         break;

      double highValue = iHigh(runtimeSymbol, InpRangeTimeframe, shift);
      double lowValue = iLow(runtimeSymbol, InpRangeTimeframe, shift);
      if(highValue <= 0.0 || lowValue <= 0.0)
         continue;

      if(highValue > rangeHigh)
         rangeHigh = highValue;
      if(lowValue < rangeLow)
         rangeLow = lowValue;
      barCount++;
     }

   return (barCount > 0 && rangeHigh > rangeLow);
  }

bool ShortBiasAllowed()
  {
   return (InpTradeBiasMode == TRADE_BIAS_SHORT_ONLY || InpTradeBiasMode == TRADE_BIAS_BOTH);
  }

bool LongBiasAllowed()
  {
   return (InpTradeBiasMode == TRADE_BIAS_LONG_ONLY || InpTradeBiasMode == TRADE_BIAS_BOTH);
  }

bool BuildSessionContext(SessionContext &ctx)
  {
   ctx.valid = false;
   ctx.boxWidthBucket = "";
   ctx.weekdayLabel = "";
   ctx.previousDayHigh = 0.0;
   ctx.previousDayLow = 0.0;
   ctx.m30PriorSwingHigh = 0.0;
   ctx.m30PriorSwingLow = 0.0;
   ctx.boxWidthAtrRatio = 0.0;

   datetime now = TimeCurrent();
   ctx.sessionTypeLabel = "tokyo_range_london_break";
   ctx.rangeTimeframeLabel = TimeframeLabel(InpRangeTimeframe);
   ctx.executionTimeframeLabel = TimeframeLabel(InpExecutionTimeframe);
   ctx.rangeStart = BuildDateTime(now, InpRangeStartHour);
   ctx.rangeEnd = BuildDateTime(now, InpRangeEndHour);
   ctx.breakoutStart = BuildDateTime(now, InpBreakoutStartHour);
   ctx.breakoutEnd = BuildDateTime(now, InpBreakoutEndHour);
   ctx.breakoutWindowActive = (now >= ctx.breakoutStart && now < ctx.breakoutEnd);
   ctx.breakoutWindowExpired = (now >= ctx.breakoutEnd);
   ctx.sessionDayId = BuildDayId(ctx.rangeStart);
   ctx.weekdayLabel = WeekdayLabel(ctx.rangeStart);

   if(now < ctx.rangeEnd)
      return false;

   if(!LoadSingleBuffer(rangeAtrHandle, 1, ctx.rangeAtr) ||
      !LoadSingleBuffer(executionAtrHandle, 1, ctx.executionAtr))
      return false;

   if(!CollectSessionRange(ctx.rangeStart, ctx.rangeEnd, ctx.rangeHigh, ctx.rangeLow, ctx.rangeBarCount))
      return false;

   ctx.rangeMid = (ctx.rangeHigh + ctx.rangeLow) * 0.5;
   ctx.rangeHeight = ctx.rangeHigh - ctx.rangeLow;
   if(ctx.rangeHeight <= 0.0)
      return false;

   ctx.rangePips = ctx.rangeHeight / GetPipSize();
   ctx.rangeAtrPips = ctx.rangeAtr / GetPipSize();
   ctx.boxWidthAtrRatio = (ctx.rangeAtrPips > 0.0) ? (ctx.rangePips / ctx.rangeAtrPips) : 0.0;
   ctx.boxWidthBucket = BoxWidthBucket(ctx.boxWidthAtrRatio);
   ctx.executionAtrPips = ctx.executionAtr / GetPipSize();
   ctx.breakoutBuffer = MathMax(PipsToPrice(InpMinBreakoutBufferPips), ctx.executionAtr * InpBreakoutBufferATR);
   ctx.retestTolerance = PipsToPrice(InpRetestTolerancePips);
   ctx.volatilityBucket = VolatilityBucket(MathMax(ctx.rangeAtrPips, ctx.executionAtrPips));
   CollectPreviousDayRange(ctx.rangeStart, ctx.previousDayHigh, ctx.previousDayLow);
   FindLatestConfirmedPivotLevelBeforeTime(PERIOD_M30, true, ctx.rangeStart, 2, 160, ctx.m30PriorSwingHigh);
   FindLatestConfirmedPivotLevelBeforeTime(PERIOD_M30, false, ctx.rangeStart, 2, 160, ctx.m30PriorSwingLow);

   if(ctx.rangePips < InpMinRangePips)
      return false;
   if(InpMaxRangePips > 0.0 && ctx.rangePips > InpMaxRangePips)
      return false;

   ctx.valid = true;
   return true;
  }

bool BuildBreakoutSetup(const SessionContext &ctx, int direction, BreakoutSetup &setup)
  {
   ResetBreakoutSetup(setup);
   if(!ctx.valid)
      return false;

   if(direction < 0 && !ShortBiasAllowed())
      return false;
   if(direction > 0 && !LongBiasAllowed())
      return false;

   setup.valid = true;
   setup.sessionDayId = ctx.sessionDayId;
   setup.direction = direction;
   setup.sideLabel = (direction > 0) ? "long" : "short";
   setup.sessionTypeLabel = ctx.sessionTypeLabel;
   setup.breakoutSideLabel = (direction > 0) ? "high_breakout" : "low_breakout";
   setup.breakoutTypeLabel = (direction > 0) ? "session_high_breakout" : "session_low_breakout";
   setup.breakoutStateLabel = "session_box_ready";
   setup.volatilityBucket = ctx.volatilityBucket;
   setup.boxWidthBucket = ctx.boxWidthBucket;
   setup.weekdayLabel = ctx.weekdayLabel;
   setup.rangeTimeframeLabel = ctx.rangeTimeframeLabel;
   setup.executionTimeframeLabel = ctx.executionTimeframeLabel;
   setup.rangeHigh = ctx.rangeHigh;
   setup.rangeLow = ctx.rangeLow;
   setup.boxWidthPips = ctx.rangePips;
   setup.boxWidthAtrRatio = ctx.boxWidthAtrRatio;
   setup.breakoutLevel = (direction > 0) ? ctx.rangeHigh : ctx.rangeLow;
   setup.stopAnchor = (direction > 0) ? ctx.rangeLow : ctx.rangeHigh;
   setup.invalidationLevel = NormalizePrice((direction > 0)
                                            ? (ctx.rangeHigh - PipsToPrice(InpAcceptanceExitBufferPips))
                                            : (ctx.rangeLow + PipsToPrice(InpAcceptanceExitBufferPips)));
   setup.structureHeight = ctx.rangeHeight;
   setup.structureHeightPips = ctx.rangePips;
   setup.rangeAtrPips = ctx.rangeAtrPips;
   double alignmentThresholdPips = AlignmentThresholdPips(ctx);
   setup.prevDayAlignmentType = BuildAlignmentType(
      direction,
      setup.breakoutLevel,
      (direction > 0) ? ctx.previousDayHigh : ctx.previousDayLow,
      alignmentThresholdPips,
      (direction > 0) ? "near_prev_day_high" : "near_prev_day_low",
      (direction > 0) ? "far_prev_day_high" : "far_prev_day_low"
   );
   setup.m30SwingAlignmentType = BuildAlignmentType(
      direction,
      setup.breakoutLevel,
      (direction > 0) ? ctx.m30PriorSwingHigh : ctx.m30PriorSwingLow,
      alignmentThresholdPips,
      (direction > 0) ? "near_m30_prior_swing_high" : "near_m30_prior_swing_low",
      (direction > 0) ? "far_m30_prior_swing_high" : "far_m30_prior_swing_low"
   );
   setup.setupTime = TimeCurrent();
   return true;
  }

void SyncPendingExecution(const BreakoutSetup &setup, PendingExecutionContext &ctx)
  {
   if(!setup.valid)
      return;

   if(ctx.valid && ctx.sessionDayId == setup.sessionDayId && ctx.setup.direction == setup.direction)
     {
      ctx.setup = setup;
      return;
     }

   ResetPendingExecution(ctx);
   ctx.valid = true;
   ctx.sessionDayId = setup.sessionDayId;
   ctx.setup = setup;
   ctx.detectedTime = TimeCurrent();
   ctx.setupBaselineEntry = (setup.direction > 0)
                            ? SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK)
                            : SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   if(ctx.setupBaselineEntry <= 0.0)
      ctx.setupBaselineEntry = iClose(runtimeSymbol, InpExecutionTimeframe, 1);
  }

int BarsBetweenTimes(datetime olderTime, datetime newerTime, ENUM_TIMEFRAMES tf)
  {
   if(olderTime <= 0 || newerTime <= 0)
      return -1;
   int olderShift = iBarShift(runtimeSymbol, tf, olderTime, false);
   int newerShift = iBarShift(runtimeSymbol, tf, newerTime, false);
   if(olderShift < 0 || newerShift < 0)
      return -1;
   return olderShift - newerShift;
  }

bool PendingSetupExpired(const PendingExecutionContext &ctx, const SessionContext &sessionCtx)
  {
   if(!ctx.valid)
      return true;
   if(!sessionCtx.valid)
      return true;
   if(ctx.sessionDayId != sessionCtx.sessionDayId)
      return true;
   if(sessionCtx.breakoutWindowExpired)
      return true;
   return false;
  }

bool BuildEntryTrigger(PendingExecutionContext &ctx, const SessionContext &sessionCtx, ExecutionTrigger &trigger)
  {
   trigger.fired = false;
   trigger.triggerLabel = "";
   trigger.triggerTypeLabel = "";
   trigger.breakoutStrengthBucket = "";
   trigger.breakoutTimingBucket = "";
   trigger.entryPrice = 0.0;
   trigger.setupToEntryPips = 0.0;
   trigger.breakoutCloseDistancePips = 0.0;
   trigger.breakoutCloseDistanceAtr = 0.0;
   trigger.barsFromSetupToEntry = -1;
   trigger.londonMinutesFromOpen = -1;
   trigger.referenceLevel = 0.0;

   if(!ctx.valid || !sessionCtx.valid || !sessionCtx.breakoutWindowActive)
      return false;

   double open1 = iOpen(runtimeSymbol, InpExecutionTimeframe, 1);
   double high1 = iHigh(runtimeSymbol, InpExecutionTimeframe, 1);
   double low1 = iLow(runtimeSymbol, InpExecutionTimeframe, 1);
   double close1 = iClose(runtimeSymbol, InpExecutionTimeframe, 1);
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;

   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   int barsFromSetup = BarsBetweenTimes(ctx.detectedTime, TimeCurrent(), InpExecutionTimeframe);
   double referencePrice = (ctx.setup.direction > 0) ? ask : bid;
   double setupToEntryPips = (ctx.setup.direction > 0)
                             ? (referencePrice - ctx.setupBaselineEntry) / GetPipSize()
                             : (ctx.setupBaselineEntry - referencePrice) / GetPipSize();

   bool closeBreak = false;
   if(ctx.setup.direction > 0)
      closeBreak = (close1 > ctx.setup.breakoutLevel + sessionCtx.breakoutBuffer && close1 > open1);
   else
      closeBreak = (close1 < ctx.setup.breakoutLevel - sessionCtx.breakoutBuffer && close1 < open1);

   if(InpBreakoutTriggerMode == EXEC_RANGE_CLOSE_CONFIRM)
     {
      if(closeBreak)
        {
         RecordBreakoutDiagnostics(ctx, sessionCtx, iTime(runtimeSymbol, InpExecutionTimeframe, 1), close1);
         trigger.fired = true;
         trigger.triggerLabel = "exec_range_close_confirm";
         trigger.triggerTypeLabel = trigger.triggerLabel;
         trigger.entryPrice = (ctx.setup.direction > 0) ? ask : bid;
         trigger.referenceLevel = ctx.setup.breakoutLevel;
        }
     }
   else if(InpBreakoutTriggerMode == EXEC_RANGE_RETEST_CONFIRM)
     {
      if(!ctx.breakoutSeen)
        {
         if(closeBreak)
           {
            ctx.breakoutSeen = true;
            ctx.breakoutTime = iTime(runtimeSymbol, InpExecutionTimeframe, 1);
            ctx.breakoutBarExtreme = (ctx.setup.direction > 0) ? high1 : low1;
            RecordBreakoutDiagnostics(ctx, sessionCtx, ctx.breakoutTime, close1);
           }
         return false;
        }

      if(ctx.setup.direction > 0)
        {
         if(low1 <= ctx.setup.breakoutLevel + sessionCtx.retestTolerance &&
            close1 > ctx.setup.breakoutLevel + sessionCtx.breakoutBuffer &&
            close1 > open1)
           {
            trigger.fired = true;
            trigger.triggerLabel = "exec_range_retest_confirm";
            trigger.triggerTypeLabel = trigger.triggerLabel;
            trigger.entryPrice = ask;
            trigger.referenceLevel = ctx.setup.breakoutLevel;
           }
        }
      else
        {
         if(high1 >= ctx.setup.breakoutLevel - sessionCtx.retestTolerance &&
            close1 < ctx.setup.breakoutLevel - sessionCtx.breakoutBuffer &&
            close1 < open1)
           {
            trigger.fired = true;
            trigger.triggerLabel = "exec_range_retest_confirm";
            trigger.triggerTypeLabel = trigger.triggerLabel;
            trigger.entryPrice = bid;
            trigger.referenceLevel = ctx.setup.breakoutLevel;
           }
        }
     }
   else
     {
      if(!ctx.breakoutSeen)
        {
         if(closeBreak)
           {
            ctx.breakoutSeen = true;
            ctx.breakoutTime = iTime(runtimeSymbol, InpExecutionTimeframe, 1);
            ctx.breakoutBarExtreme = (ctx.setup.direction > 0) ? high1 : low1;
            RecordBreakoutDiagnostics(ctx, sessionCtx, ctx.breakoutTime, close1);
            ctx.recentSwingLevel = ctx.breakoutBarExtreme;
            ctx.recentSwingLabel = (ctx.setup.direction > 0) ? "breakout_bar_high" : "breakout_bar_low";
           }
         return false;
        }

      if(ctx.setup.direction > 0)
        {
         if(close1 > ctx.recentSwingLevel + sessionCtx.breakoutBuffer && close1 > open1)
           {
            trigger.fired = true;
            trigger.triggerLabel = "exec_breakout_bar_continuation";
            trigger.triggerTypeLabel = trigger.triggerLabel;
            trigger.entryPrice = ask;
            trigger.referenceLevel = ctx.recentSwingLevel;
           }
        }
      else
        {
         if(close1 < ctx.recentSwingLevel - sessionCtx.breakoutBuffer && close1 < open1)
           {
            trigger.fired = true;
            trigger.triggerLabel = "exec_breakout_bar_continuation";
            trigger.triggerTypeLabel = trigger.triggerLabel;
            trigger.entryPrice = bid;
            trigger.referenceLevel = ctx.recentSwingLevel;
           }
        }
     }

   if(!trigger.fired)
      return false;

   trigger.setupToEntryPips = setupToEntryPips;
   trigger.barsFromSetupToEntry = barsFromSetup;
   trigger.breakoutCloseDistancePips = ctx.breakoutCloseDistancePips;
   trigger.breakoutCloseDistanceAtr = ctx.breakoutCloseDistanceAtr;
   trigger.breakoutStrengthBucket = ctx.breakoutStrengthBucket;
   trigger.londonMinutesFromOpen = ctx.londonMinutesFromOpen;
   trigger.breakoutTimingBucket = ctx.breakoutTimingBucket;
   return true;
  }

double SelectPartialTarget(const BreakoutSetup &setup, double entry, double risk, string &label)
  {
   double ratio = (InpPartialTargetLevel == PARTIAL_TARGET_500) ? 0.500 : 0.382;
   label = PartialTargetLevelLabel(InpPartialTargetLevel);

   double target = (setup.direction > 0)
                   ? (setup.breakoutLevel + setup.structureHeight * ratio)
                   : (setup.breakoutLevel - setup.structureHeight * ratio);
   if((setup.direction > 0 && target > entry) || (setup.direction < 0 && target < entry))
      return target;

   label += "_fallback_r";
   return (setup.direction > 0) ? (entry + risk * 0.75) : (entry - risk * 0.75);
  }

double SelectFinalTarget(const BreakoutSetup &setup, double entry, double risk, string &label)
  {
   label = FinalTargetModeLabel(InpFinalTargetMode);

   double target = 0.0;
   if(InpFinalTargetMode == FINAL_TARGET_FIXED_R)
      target = (setup.direction > 0) ? (entry + risk * InpTargetRMultiple) : (entry - risk * InpTargetRMultiple);
   else
      target = (setup.direction > 0) ? (setup.breakoutLevel + setup.structureHeight) : (setup.breakoutLevel - setup.structureHeight);

   if((setup.direction > 0 && target > entry) || (setup.direction < 0 && target < entry))
      return target;

   label += "_fallback_r";
   return (setup.direction > 0) ? (entry + risk * InpTargetRMultiple) : (entry - risk * InpTargetRMultiple);
  }

bool BuildEntryPlan(const BreakoutSetup &setup, const ExecutionTrigger &trigger, EntryPlan &plan)
  {
   ResetEntryPlan(plan);
   if(!setup.valid || !trigger.fired)
      return false;

   double entry = NormalizePrice(trigger.entryPrice);
   double stopBuffer = MathMax(PipsToPrice(InpMinStopBufferPips), PipsToPrice(setup.rangeAtrPips * InpStopBufferATR));
   double stop = NormalizePrice((setup.direction > 0) ? (setup.stopAnchor - stopBuffer) : (setup.stopAnchor + stopBuffer));
   if((setup.direction > 0 && stop >= entry) || (setup.direction < 0 && stop <= entry))
      return false;

   double risk = MathAbs(entry - stop);
   string partialLabel = "";
   string finalLabel = "";
   double partialTarget = NormalizePrice(SelectPartialTarget(setup, entry, risk, partialLabel));
   double finalTarget = NormalizePrice(SelectFinalTarget(setup, entry, risk, finalLabel));

   bool partialValid = (setup.direction > 0) ? (partialTarget > entry) : (partialTarget < entry);
   bool finalValid = (setup.direction > 0) ? (finalTarget > entry) : (finalTarget < entry);
   if(!partialValid || !finalValid)
      return false;
   if((setup.direction > 0 && finalTarget <= partialTarget) || (setup.direction < 0 && finalTarget >= partialTarget))
     {
      finalLabel += "_fallback_r";
      finalTarget = NormalizePrice((setup.direction > 0) ? (entry + risk * InpTargetRMultiple) : (entry - risk * InpTargetRMultiple));
      if((setup.direction > 0 && finalTarget <= partialTarget) || (setup.direction < 0 && finalTarget >= partialTarget))
         return false;
     }

   plan.valid = true;
   plan.direction = setup.direction;
   plan.sessionDayId = setup.sessionDayId;
   plan.sideLabel = setup.sideLabel;
   plan.sessionTypeLabel = setup.sessionTypeLabel;
   plan.breakoutSideLabel = setup.breakoutSideLabel;
   plan.breakoutTypeLabel = setup.breakoutTypeLabel;
   plan.breakoutStateLabel = setup.breakoutStateLabel;
   plan.executionTriggerLabel = trigger.triggerLabel;
   plan.triggerTypeLabel = trigger.triggerTypeLabel;
   plan.rangeTimeframeLabel = setup.rangeTimeframeLabel;
   plan.executionTimeframeLabel = setup.executionTimeframeLabel;
   plan.partialTargetLabel = partialLabel;
   plan.finalTargetLabel = finalLabel;
   plan.volatilityBucket = setup.volatilityBucket;
   plan.boxWidthBucket = setup.boxWidthBucket;
   plan.breakoutStrengthBucket = trigger.breakoutStrengthBucket;
   plan.breakoutTimingBucket = trigger.breakoutTimingBucket;
   plan.prevDayAlignmentType = setup.prevDayAlignmentType;
   plan.m30SwingAlignmentType = setup.m30SwingAlignmentType;
   plan.weekdayLabel = setup.weekdayLabel;
   plan.rangeHigh = setup.rangeHigh;
   plan.rangeLow = setup.rangeLow;
   plan.breakoutLevel = setup.breakoutLevel;
   plan.boxWidthPips = setup.boxWidthPips;
   plan.boxWidthAtrRatio = setup.boxWidthAtrRatio;
   plan.structureHeightPips = setup.structureHeightPips;
   plan.rangeAtrPips = setup.rangeAtrPips;
   plan.breakoutCloseDistancePips = trigger.breakoutCloseDistancePips;
   plan.breakoutCloseDistanceAtr = trigger.breakoutCloseDistanceAtr;
   plan.invalidationLevel = setup.invalidationLevel;
   plan.setupBaselineEntry = (setup.direction > 0)
                             ? SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK)
                             : SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   if(plan.setupBaselineEntry <= 0.0)
      plan.setupBaselineEntry = trigger.entryPrice;
   plan.setupToEntryPips = trigger.setupToEntryPips;
   plan.entry = entry;
   plan.stop = stop;
   plan.target = finalTarget;
   plan.partialTarget = partialTarget;
   plan.usePartial = true;
   plan.runnerTargetEnabled = true;
   plan.stopDistancePips = risk / GetPipSize();
   plan.plannedRiskAmount = 0.0;
   plan.barsFromSetupToEntry = trigger.barsFromSetupToEntry;
   plan.londonMinutesFromOpen = trigger.londonMinutesFromOpen;
   plan.reason = "session_box_" + setup.sideLabel + "_" + trigger.triggerLabel;
   return true;
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

double NormalizeVolumeByStep(double volume)
  {
   double stepVolume = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_STEP);
   if(stepVolume <= 0.0)
      return 0.0;
   double normalized = MathFloor(volume / stepVolume) * stepVolume;
   return NormalizeDouble(normalized, VolumeDigits(stepVolume));
  }

double CalculateVolumeByRisk(double entry, double stop)
  {
   double riskAmount = AccountInfoDouble(ACCOUNT_EQUITY) * (InpRiskPercent / 100.0);
   double tickSize = SymbolInfoDouble(runtimeSymbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(runtimeSymbol, SYMBOL_TRADE_TICK_VALUE);
   double minVolume = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_MAX);
   double stepVolume = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_STEP);
   double stopDistance = MathAbs(entry - stop);
   if(riskAmount <= 0.0 || tickSize <= 0.0 || tickValue <= 0.0 || stopDistance <= 0.0 ||
      minVolume <= 0.0 || maxVolume <= 0.0 || stepVolume <= 0.0)
      return 0.0;

   double moneyPerLot = (stopDistance / tickSize) * tickValue;
   if(moneyPerLot <= 0.0)
      return 0.0;

   double rawVolume = riskAmount / moneyPerLot;
   double normalized = NormalizeVolumeByStep(rawVolume);
   if(normalized < minVolume)
      return 0.0;
   if(normalized > maxVolume)
      normalized = NormalizeDouble(maxVolume, VolumeDigits(stepVolume));
   return normalized;
  }

double CalculateRiskAmountByVolume(double entry, double stop, double volume)
  {
   double tickSize = SymbolInfoDouble(runtimeSymbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(runtimeSymbol, SYMBOL_TRADE_TICK_VALUE);
   double stopDistance = MathAbs(entry - stop);
   if(volume <= 0.0 || tickSize <= 0.0 || tickValue <= 0.0 || stopDistance <= 0.0)
      return 0.0;

   double moneyPerLot = (stopDistance / tickSize) * tickValue;
   if(moneyPerLot <= 0.0)
      return 0.0;
   return moneyPerLot * volume;
  }

bool OpenTelemetryFile()
  {
   if(!InpEnableTelemetry)
      return false;
   if(telemetryHandle != INVALID_HANDLE)
      return true;

   telemetryHandle = FileOpen(runtimeTelemetryFileName,
                              FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_COMMON | FILE_ANSI,
                              ';');
   if(telemetryHandle == INVALID_HANDLE)
      return false;

   if(FileSize(telemetryHandle) == 0)
     {
      FileWrite(telemetryHandle,
                "timestamp",
                "event_type",
                "side",
                "position_id",
                "session_type",
                "breakout_side",
                "breakout_type",
                "breakout_state",
                "execution_trigger",
                "trigger_type",
                "range_tf",
                "execution_tf",
                "partial_target_label",
                "final_target_label",
                "volatility_bucket",
                "box_width_pips",
                "box_width_atr_ratio",
                "box_width_bucket",
                "breakout_level",
                "breakout_close_distance_pips",
                "breakout_close_distance_atr",
                "breakout_strength_bucket",
                "london_minutes_from_open",
                "breakout_timing_bucket",
                "prev_day_alignment_type",
                "m30_swing_alignment_type",
                "weekday",
                "range_height_pips",
                "range_atr_pips",
                "setup_to_entry_pips",
                "bars_from_setup_to_entry",
                "stop_distance_pips",
                "planned_risk_amount",
                "partial_hit",
                "be_move",
                "runner_target_enabled",
                "runner_target_hit",
                "runner_stop_at_breakeven",
                "bars_since_entry",
                "bars_to_partial",
                "bars_to_final",
                "bars_to_time_stop",
                "accepted_outside_box_bars",
                "failed_back_inside_box_bars",
                "mfe_before_acceptance_exit",
                "mae_before_acceptance_exit",
                "did_time_stop_after_partial",
                "did_runner_hit_before_time_stop",
                "mfe_pips",
                "mae_pips",
                "max_unrealized_r",
                "min_unrealized_r",
                "event_r_multiple",
                "price",
                "volume",
                "net_profit",
                "outcome",
                "reason");
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

int BarsSinceEntry(datetime entryTime)
  {
   return BarsBetweenTimes(entryTime, TimeCurrent(), InpExecutionTimeframe);
  }

void LogTelemetry(string eventType,
                  const EntryPlan &plan,
                  ulong positionId,
                  double price,
                  double volume,
                  double netProfit,
                  string outcome,
                  string reason)
  {
   if(!InpEnableTelemetry)
      return;
   if(!OpenTelemetryFile())
      return;

   int barsSinceEntry = (eventType == "entry") ? 0 : BarsSinceEntry(activeEntryTime);
   double plannedRiskAmount = activePlannedRiskAmount;
   if(plannedRiskAmount <= 0.0)
      plannedRiskAmount = plan.plannedRiskAmount;
   double eventRMultiple = 0.0;
   if(plannedRiskAmount > 0.0)
      eventRMultiple = netProfit / plannedRiskAmount;

   bool runnerTargetHit = (reason == "runner_target");
   bool runnerStopAtBreakeven = (reason == "breakeven_after_partial");
   bool didTimeStopAfterPartial = (reason == "time_stop" && activePartialTaken);
   bool didRunnerHitBeforeTimeStop = (reason == "runner_target");

   FileSeek(telemetryHandle, 0, SEEK_END);
   FileWrite(telemetryHandle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             eventType,
             plan.sideLabel,
             (long)positionId,
             plan.sessionTypeLabel,
             plan.breakoutSideLabel,
             plan.breakoutTypeLabel,
             plan.breakoutStateLabel,
             plan.executionTriggerLabel,
             plan.triggerTypeLabel,
             plan.rangeTimeframeLabel,
             plan.executionTimeframeLabel,
             plan.partialTargetLabel,
             plan.finalTargetLabel,
             plan.volatilityBucket,
             plan.boxWidthPips,
             plan.boxWidthAtrRatio,
             plan.boxWidthBucket,
             plan.breakoutLevel,
             plan.breakoutCloseDistancePips,
             plan.breakoutCloseDistanceAtr,
             plan.breakoutStrengthBucket,
             plan.londonMinutesFromOpen,
             plan.breakoutTimingBucket,
             plan.prevDayAlignmentType,
             plan.m30SwingAlignmentType,
             plan.weekdayLabel,
             plan.structureHeightPips,
             plan.rangeAtrPips,
             plan.setupToEntryPips,
             plan.barsFromSetupToEntry,
             plan.stopDistancePips,
             plannedRiskAmount,
             (int)activePartialTaken,
             (int)activeBreakEvenMoved,
             (int)plan.runnerTargetEnabled,
             (int)runnerTargetHit,
             (int)runnerStopAtBreakeven,
             barsSinceEntry,
             activeBarsToPartial,
             activeBarsToFinal,
             activeBarsToTimeStop,
             activeAcceptedOutsideBoxBars,
             activeFailedBackInsideBoxBars,
             activeMfeBeforeAcceptanceExit,
             activeMaeBeforeAcceptanceExit,
             (int)didTimeStopAfterPartial,
             (int)didRunnerHitBeforeTimeStop,
             activeMfePips,
             activeMaePips,
             activeMaxUnrealizedR,
             activeMinUnrealizedR,
             eventRMultiple,
             price,
             volume,
             netProfit,
             outcome,
             reason);
   FileFlush(telemetryHandle);
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

bool PassGlobalGuards()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   if(!HourInWindow(tm.hour, InpSessionStartHour, InpSessionEndHour))
      return false;
   if(GetSpreadPips() > InpMaxSpreadPips)
      return false;
   if(CountManagedPositions() > 0)
      return false;
   return true;
  }

bool ComputePartialCloseVolume(double currentVolume, double &closeVolume)
  {
   double minVolume = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_MIN);
   double stepVolume = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_STEP);
   if(minVolume <= 0.0 || stepVolume <= 0.0)
      return false;

   closeVolume = NormalizeVolumeByStep(currentVolume * InpHybridPartialFraction);
   if(closeVolume < minVolume)
      return false;
   if(currentVolume - closeVolume < minVolume)
      return false;
   return true;
  }

double ActiveCurrentPrice()
  {
   if(activePlan.direction > 0)
      return SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   return SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
  }

void UpdateOpenTradeExcursion()
  {
   if(!activePlan.valid)
      return;
   if(!PositionSelect(runtimeSymbol))
      return;
   if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
      return;

   double currentPrice = ActiveCurrentPrice();
   if(currentPrice <= 0.0 || activePlan.stopDistancePips <= 0.0)
      return;

   double favorablePips = 0.0;
   double adversePips = 0.0;
   if(activePlan.direction > 0)
     {
      favorablePips = (currentPrice - activePlan.entry) / GetPipSize();
      adversePips = (activePlan.entry - currentPrice) / GetPipSize();
     }
   else
     {
      favorablePips = (activePlan.entry - currentPrice) / GetPipSize();
      adversePips = (currentPrice - activePlan.entry) / GetPipSize();
     }

   if(favorablePips > activeMfePips)
      activeMfePips = favorablePips;
   if(adversePips > activeMaePips)
      activeMaePips = adversePips;

   double unrealizedR = favorablePips / activePlan.stopDistancePips;
   double adverseR = -adversePips / activePlan.stopDistancePips;
   if(unrealizedR > activeMaxUnrealizedR)
      activeMaxUnrealizedR = unrealizedR;
   if(adverseR < activeMinUnrealizedR)
      activeMinUnrealizedR = adverseR;
  }

void UpdateActiveBoxAcceptanceDiagnostics()
  {
   if(!activePlan.valid)
      return;

   datetime diagnosticBarTime = iTime(runtimeSymbol, InpExecutionTimeframe, 1);
   if(diagnosticBarTime <= 0 || diagnosticBarTime == activeLastDiagnosticBarTime)
      return;

   double execClose = iClose(runtimeSymbol, InpExecutionTimeframe, 1);
   if(execClose <= 0.0)
      return;

   activeLastDiagnosticBarTime = diagnosticBarTime;
   bool acceptedOutside = (activePlan.direction > 0)
                          ? (execClose > activePlan.rangeHigh)
                          : (execClose < activePlan.rangeLow);
   bool failedBackInside = (execClose >= activePlan.rangeLow && execClose <= activePlan.rangeHigh);

   if(acceptedOutside)
      activeAcceptedOutsideBoxBars++;
   if(failedBackInside)
      activeFailedBackInsideBoxBars++;
  }

bool MoveStopToBreakeven()
  {
   if(!PositionSelect(runtimeSymbol))
      return false;
   if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
      return false;
   if(!activePlan.valid)
      return false;

   double currentSl = PositionGetDouble(POSITION_SL);
   double newSl = NormalizePrice(activePlan.entry);
   double epsilon = PipsToPrice(0.1);
   if((activePlan.direction > 0 && currentSl >= newSl - epsilon) ||
      (activePlan.direction < 0 && currentSl <= newSl + epsilon && currentSl > 0.0))
     {
      activeBreakEvenMoved = true;
      return true;
     }

   if(trade.PositionModify(runtimeSymbol, newSl, 0.0))
     {
      activeBreakEvenMoved = true;
      return true;
     }
   return false;
  }

string InferExitReason(double dealPrice, bool stillOpen)
  {
   if(pendingExitReason != "")
      return pendingExitReason;

   double pip = GetPipSize();
   if(activePlan.valid)
     {
      if(activePartialTaken && MathAbs(dealPrice - activePlan.entry) <= pip * 0.2)
         return "breakeven_after_partial";

      if(activePlan.direction > 0)
        {
         if(dealPrice <= activePlan.stop + pip * 0.2)
            return "stop_loss";
         if(!stillOpen && dealPrice >= activePlan.target - pip * 0.2)
            return activePartialTaken ? "runner_target" : "target";
        }
      else
        {
         if(dealPrice >= activePlan.stop - pip * 0.2)
            return "stop_loss";
         if(!stillOpen && dealPrice <= activePlan.target + pip * 0.2)
            return activePartialTaken ? "runner_target" : "target";
        }

      if(!stillOpen && !activePlan.runnerTargetEnabled && activePartialTaken)
         return "runner_timeout";
      if(stillOpen)
         return "partial_exit";
     }

   return "platform_exit";
  }

void ManageOpenPositions()
  {
   if(!PositionSelect(runtimeSymbol))
      return;
   if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
      return;
   if(!activePlan.valid)
      return;

   double currentPrice = ActiveCurrentPrice();
   if(currentPrice <= 0.0)
      return;

   double currentVolume = PositionGetDouble(POSITION_VOLUME);
   datetime openedAt = (datetime)PositionGetInteger(POSITION_TIME);
   int barsSinceEntry = iBarShift(runtimeSymbol, InpExecutionTimeframe, openedAt, false);

   UpdateActiveBoxAcceptanceDiagnostics();

   if(activePlan.usePartial && activePartialTaken && !activeBreakEvenMoved)
      MoveStopToBreakeven();

   bool partialReached = (activePlan.direction > 0) ? (currentPrice >= activePlan.partialTarget)
                                                    : (currentPrice <= activePlan.partialTarget);
   if(activePlan.usePartial && !activePartialTaken && partialReached)
     {
      double closeVolume = 0.0;
      if(ComputePartialCloseVolume(currentVolume, closeVolume))
        {
         activePartialTaken = true;
         activeBarsToPartial = barsSinceEntry;
         pendingExitReason = "partial_exit";
         pendingPartialExit = true;
         if(trade.PositionClosePartial(runtimeSymbol, closeVolume))
            MoveStopToBreakeven();
         else
           {
            activePartialTaken = false;
            activeBarsToPartial = -1;
            pendingExitReason = "";
            pendingPartialExit = false;
           }
        }
     }

   if(!PositionSelect(runtimeSymbol) || (long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
      return;

   bool finalReached = (activePlan.direction > 0) ? (currentPrice >= activePlan.target)
                                                  : (currentPrice <= activePlan.target);
   if(activePlan.runnerTargetEnabled && finalReached)
     {
      activeBarsToFinal = barsSinceEntry;
      pendingExitReason = activePartialTaken ? "runner_target" : "target";
      trade.PositionClose(runtimeSymbol);
      return;
     }

   double execClose = iClose(runtimeSymbol, InpExecutionTimeframe, 1);
   if(execClose > 0.0)
     {
      bool acceptanceFailed = (activePlan.direction > 0)
                              ? (execClose < activePlan.invalidationLevel)
                              : (execClose > activePlan.invalidationLevel);
      if(acceptanceFailed)
        {
         activeMfeBeforeAcceptanceExit = activeMfePips;
         activeMaeBeforeAcceptanceExit = activeMaePips;
         pendingExitReason = (activePlan.direction > 0)
                             ? "acceptance_back_inside_box"
                             : "acceptance_back_inside_box";
         trade.PositionClose(runtimeSymbol);
         return;
        }
     }

   if(InpMaxHoldBars > 0 && barsSinceEntry >= InpMaxHoldBars && barsSinceEntry >= 0)
     {
      activeBarsToTimeStop = barsSinceEntry;
      pendingExitReason = "time_stop";
      trade.PositionClose(runtimeSymbol);
     }
  }

bool ExecuteEntry(const EntryPlan &plan)
  {
   if(!plan.valid)
      return false;

   double volume = CalculateVolumeByRisk(plan.entry, plan.stop);
   if(volume <= 0.0)
      return false;

   EntryPlan localPlan = plan;
   localPlan.plannedRiskAmount = CalculateRiskAmountByVolume(localPlan.entry, localPlan.stop, volume);
   ResetEntryPlan(pendingPlan);
   pendingPlan = localPlan;
   hasPendingPlan = false;

   bool result = false;
   if(localPlan.direction > 0)
      result = trade.Buy(volume, runtimeSymbol, 0.0, localPlan.stop, 0.0, localPlan.reason);
   else
      result = trade.Sell(volume, runtimeSymbol, 0.0, localPlan.stop, 0.0, localPlan.reason);

   if(result)
     {
      pendingPlan = localPlan;
      hasPendingPlan = true;
      lastTradeSessionDayId = localPlan.sessionDayId;
      ResetPendingExecution(pendingLongExecution);
      ResetPendingExecution(pendingShortExecution);
      return true;
     }

   ResetEntryPlan(pendingPlan);
   return false;
  }

bool IsAllowedRangeTimeframe(ENUM_TIMEFRAMES tf)
  {
   return (tf == PERIOD_M15 || tf == PERIOD_M30);
  }

bool IsAllowedExecutionTimeframe(ENUM_TIMEFRAMES tf)
  {
   return (tf == PERIOD_M3 || tf == PERIOD_M5);
  }

bool SelectTriggeredPlan(const EntryPlan &longPlan, const EntryPlan &shortPlan, EntryPlan &selected)
  {
   ResetEntryPlan(selected);
   if(longPlan.valid && !shortPlan.valid)
     {
      selected = longPlan;
      return true;
     }
   if(shortPlan.valid && !longPlan.valid)
     {
      selected = shortPlan;
      return true;
     }
   if(!longPlan.valid && !shortPlan.valid)
      return false;

   if(MathAbs(longPlan.setupToEntryPips) >= MathAbs(shortPlan.setupToEntryPips))
      selected = longPlan;
   else
      selected = shortPlan;
   return true;
  }

void ProcessExecutionBar()
  {
   if(hasPendingPlan || CountManagedPositions() > 0)
      return;
   if(!PassGlobalGuards())
      return;

   SessionContext sessionCtx;
   if(!BuildSessionContext(sessionCtx))
     {
      ResetPendingExecution(pendingLongExecution);
      ResetPendingExecution(pendingShortExecution);
      return;
     }

   if(InpOneTradePerSessionDay && lastTradeSessionDayId == sessionCtx.sessionDayId)
     {
      ResetPendingExecution(pendingLongExecution);
      ResetPendingExecution(pendingShortExecution);
      return;
     }

   if(!sessionCtx.breakoutWindowActive)
     {
      if(sessionCtx.breakoutWindowExpired)
        {
         ResetPendingExecution(pendingLongExecution);
         ResetPendingExecution(pendingShortExecution);
        }
      return;
     }

   BreakoutSetup longSetup;
   BreakoutSetup shortSetup;
   BuildBreakoutSetup(sessionCtx, 1, longSetup);
   BuildBreakoutSetup(sessionCtx, -1, shortSetup);
   SyncPendingExecution(longSetup, pendingLongExecution);
   SyncPendingExecution(shortSetup, pendingShortExecution);

   if(PendingSetupExpired(pendingLongExecution, sessionCtx))
      ResetPendingExecution(pendingLongExecution);
   if(PendingSetupExpired(pendingShortExecution, sessionCtx))
      ResetPendingExecution(pendingShortExecution);

   ExecutionTrigger longTrigger;
   ExecutionTrigger shortTrigger;
   EntryPlan longPlan;
   EntryPlan shortPlan;
   if(BuildEntryTrigger(pendingLongExecution, sessionCtx, longTrigger))
      BuildEntryPlan(pendingLongExecution.setup, longTrigger, longPlan);
   if(BuildEntryTrigger(pendingShortExecution, sessionCtx, shortTrigger))
      BuildEntryPlan(pendingShortExecution.setup, shortTrigger, shortPlan);

   EntryPlan selected;
   if(!SelectTriggeredPlan(longPlan, shortPlan, selected))
      return;

   ExecuteEntry(selected);
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;

   string symbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
   if(symbol != runtimeSymbol)
      return;
   if(HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagicNumber)
      return;

   ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   ulong positionId = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   datetime dealTime = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
   double price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   double volume = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) +
                   HistoryDealGetDouble(trans.deal, DEAL_SWAP) +
                   HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

   if(dealEntry == DEAL_ENTRY_IN || dealEntry == DEAL_ENTRY_INOUT)
     {
      if(hasPendingPlan)
        {
         activePlan = pendingPlan;
         ResetTradeRuntimeState();
         activeEntryTime = dealTime;
         activePlannedRiskAmount = (activePlan.plannedRiskAmount > 0.0)
                                   ? activePlan.plannedRiskAmount
                                   : CalculateRiskAmountByVolume(activePlan.entry, activePlan.stop, volume);
         hasPendingPlan = false;
         LogTelemetry("entry", activePlan, positionId, price, volume, 0.0, "", activePlan.reason);
        }
      return;
     }

   if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_OUT_BY)
     {
      bool stillOpen = PositionSelect(runtimeSymbol) && (long)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber;
      if(activePlan.valid)
        {
         string eventType = stillOpen ? "partial_exit" : "exit";
         string outcome = "flat";
         if(profit > 0.0)
            outcome = "win";
         else if(profit < 0.0)
            outcome = "loss";

         if(stillOpen)
           {
            activePartialTaken = true;
            if(activeBarsToPartial < 0)
               activeBarsToPartial = BarsSinceEntry(activeEntryTime);
            if(!activeBreakEvenMoved)
               MoveStopToBreakeven();
           }

         string reason = InferExitReason(price, stillOpen);
         if(reason == "target" || reason == "runner_target")
            activeBarsToFinal = BarsSinceEntry(activeEntryTime);
         if(reason == "time_stop")
            activeBarsToTimeStop = BarsSinceEntry(activeEntryTime);

         LogTelemetry(eventType, activePlan, positionId, price, volume, profit, outcome, reason);
         pendingExitReason = "";
         pendingPartialExit = false;

         if(!stillOpen)
           {
            ResetEntryPlan(activePlan);
            ResetTradeRuntimeState();
           }
        }
     }
  }

int OnInit()
  {
   runtimeSymbol = NormalizePresetString(InpSymbol);
   runtimeTelemetryFileName = NormalizePresetString(InpTelemetryFileName);
   ResetEntryPlan(pendingPlan);
   ResetEntryPlan(activePlan);
   ResetPendingExecution(pendingLongExecution);
   ResetPendingExecution(pendingShortExecution);
   ResetTradeRuntimeState();

   if(!IsAllowedRangeTimeframe(InpRangeTimeframe) ||
      !IsAllowedExecutionTimeframe(InpExecutionTimeframe))
      return INIT_PARAMETERS_INCORRECT;
   if(InpMagicNumber <= 0 ||
      InpRangeATRPeriod <= 0 ||
      InpExecutionATRPeriod <= 0 ||
      InpRiskPercent <= 0.0 ||
      InpTargetRMultiple <= 0.0 ||
      InpMinRangePips <= 0.0 ||
      InpMaxRangePips <= 0.0 ||
      InpBreakoutEndHour == InpBreakoutStartHour ||
      InpRangeEndHour == InpRangeStartHour ||
      InpHybridPartialFraction <= 0.0 || InpHybridPartialFraction >= 1.0)
      return INIT_PARAMETERS_INCORRECT;

   trade.SetExpertMagicNumber((ulong)InpMagicNumber);

   rangeAtrHandle = iATR(runtimeSymbol, InpRangeTimeframe, InpRangeATRPeriod);
   executionAtrHandle = iATR(runtimeSymbol, InpExecutionTimeframe, InpExecutionATRPeriod);
   if(rangeAtrHandle == INVALID_HANDLE || executionAtrHandle == INVALID_HANDLE)
      return INIT_FAILED;

   if(InpEnableTelemetry)
      OpenTelemetryFile();

   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(rangeAtrHandle != INVALID_HANDLE)
      IndicatorRelease(rangeAtrHandle);
   if(executionAtrHandle != INVALID_HANDLE)
      IndicatorRelease(executionAtrHandle);
   CloseTelemetryFile();
  }

void OnTick()
  {
   UpdateOpenTradeExcursion();
   ManageOpenPositions();

   datetime executionBarTime = 0;
   if(IsNewBar(InpExecutionTimeframe, lastExecutionBarTime, executionBarTime))
      ProcessExecutionBar();
  }
