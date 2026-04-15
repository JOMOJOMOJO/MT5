//+------------------------------------------------------------------+
//| USDJPY External Liquidity Sweep Failed Acceptance Engine         |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Standalone external-liquidity sweep failed-acceptance reversal engine."

#include <Trade\Trade.mqh>

CTrade trade;

enum ContextPhase
  {
   CTX_PHASE_UNKNOWN = 0,
   CTX_UP_IMPULSE = 1,
   CTX_UP_EXHAUSTION = 2,
   CTX_RANGE_TOP = 3,
   CTX_RANGE_MIDDLE = 4,
   CTX_RANGE_BOTTOM = 5,
   CTX_DOWN_IMPULSE = 6,
   CTX_DOWN_EXHAUSTION = 7
  };

enum EntryTierMode
  {
   ENTRY_TIER_A_ONLY = 0,
   ENTRY_TIER_A_AND_B = 1
  };

enum TradeBiasMode
  {
   TRADE_BIAS_SHORT_ONLY = 0,
   TRADE_BIAS_LONG_ONLY = 1,
   TRADE_BIAS_BOTH = 2
  };

enum ExternalLevelMode
  {
   EXT_LEVEL_CONTEXT_PRIOR_SWING = 0,
   EXT_LEVEL_M30_PRIOR_SWING = 1,
   EXT_LEVEL_PREVIOUS_DAY_EXTREME = 2,
   EXT_LEVEL_ALL = 3
  };

enum PatternState
  {
   PATTERN_STATE_NONE = 0,
   PATTERN_EXTERNAL_LEVEL_IDENTIFIED = 1,
   PATTERN_SWEEP_UP = 2,
   PATTERN_FAILED_ACCEPTANCE_ABOVE = 3,
   PATTERN_RECLAIMED_BACK_INSIDE_SHORT = 4,
   PATTERN_RETEST_REJECTED = 5,
   PATTERN_BREAKDOWN_READY = 6,
   PATTERN_SWEEP_DOWN = 7,
   PATTERN_FAILED_ACCEPTANCE_BELOW = 8,
   PATTERN_RECLAIMED_BACK_INSIDE_LONG = 9,
   PATTERN_RETEST_HELD = 10,
   PATTERN_BREAKOUT_READY = 11
  };

enum ExecutionTriggerMode
  {
   EXEC_RECLAIM_CLOSE_CONFIRM = 0,
   EXEC_RETEST_FAILURE = 1,
   EXEC_RECENT_SWING_BREAKDOWN = 2
  };

enum PartialTargetLevel
  {
   PARTIAL_TARGET_382 = 382,
   PARTIAL_TARGET_500 = 500
  };

enum FinalTargetMode
  {
   FINAL_TARGET_FIB_618 = 0,
   FINAL_TARGET_PRIOR_SWING = 1,
   FINAL_TARGET_FIXED_R = 2
  };

struct PivotPoint
  {
   bool     valid;
   bool     isHigh;
   int      shift;
   double   price;
   datetime time;
  };

struct ExternalLiquidityLevel
  {
   bool      valid;
   int       direction;
   string    levelTypeLabel;
   double    price;
   datetime  sourceTime;
  };

struct ContextPhaseContext
  {
   bool         valid;
   ContextPhase phase;
   string       phaseLabel;
   string       trendLabel;
   string       waveLabel;
   string       contextBucket;
   PivotPoint   latestHigh;
   PivotPoint   previousHigh;
   PivotPoint   latestLow;
   PivotPoint   previousLow;
   double       emaFast;
   double       emaSlow;
   double       atr;
   double       rangeHigh;
   double       rangeLow;
   double       rangePosition;
   double       activeWaveHigh;
   double       activeWaveLow;
   double       activeWaveClose;
   double       activeWaveRetracement;
   double       priorSwingHigh;
   double       priorSwingLow;
   bool         tierAShortEligible;
   bool         tierALongEligible;
   bool         tierBShortEligible;
   bool         tierBLongEligible;
  };

struct PatternStructureContext
  {
   bool     valid;
   double   patternAtr;
   double   executionAtr;
   double   sweepFloor;
   double   structureFloor;
   double   reclaimBuffer;
   double   breakBuffer;
   double   retestTolerance;
   double   failureGap;
   double   currentOpen;
   double   currentHigh;
   double   currentLow;
   double   currentClose;
   double   currentCloseLocation;
   double   localRangeHigh;
   double   localRangeLow;
   double   patternAtrPips;
   double   executionAtrPips;
   string   volatilityBucket;
  };

struct SweepFailureSetup
  {
   bool      valid;
   int       direction;
   string    tier;
   string    sideLabel;
   string    contextPhaseLabel;
   string    contextBucket;
   string    waveLabel;
   string    externalLevelTypeLabel;
   string    patternLabel;
   string    patternStateLabel;
   string    volatilityBucket;
   ExternalLiquidityLevel externalLevel;
   PivotPoint referencePivot;
   PivotPoint sweepPivot;
   PivotPoint continuationPivot;
   PivotPoint failurePivot;
   double    referenceLevel;
   double    reclaimLevel;
   double    retestLevel;
   double    continuationLevel;
   double    stopAnchor;
   double    invalidationLevel;
   double    priorSwingTarget;
   double    structureHeight;
   double    structureHeightPips;
   double    patternAtrPips;
   double    currentCloseLocation;
   datetime  setupTime;
  };

struct ExecutionTrigger
  {
   bool      fired;
   string    triggerLabel;
   double    entryPrice;
   double    setupToEntryPips;
   int       barsFromSetupToEntry;
   double    referenceLevel;
  };

struct PendingExecutionContext
  {
   bool      valid;
   SweepFailureSetup setup;
   double    setupBaselineEntry;
   datetime  detectedTime;
   double    recentSwingLevel;
   string    recentSwingLabel;
  };

struct EntryPlan
  {
   bool      valid;
   int       direction;
   string    tier;
   string    sideLabel;
   string    contextPhaseLabel;
   string    contextBucket;
   string    waveLabel;
   string    externalLevelTypeLabel;
   string    patternLabel;
   string    patternStateLabel;
   string    executionTriggerLabel;
   string    patternTimeframe;
   string    executionTimeframe;
   string    partialTargetLabel;
   string    finalTargetLabel;
   string    volatilityBucket;
   double    referenceLevel;
   double    continuationLevel;
   double    structureHeightPips;
   double    patternAtrPips;
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
   string    reason;
  };

input string          InpSymbol                   = "USDJPY";
input ENUM_TIMEFRAMES InpContextTimeframe         = PERIOD_M30;
input ENUM_TIMEFRAMES InpPatternTimeframe         = PERIOD_M10;
input ENUM_TIMEFRAMES InpExecutionTimeframe       = PERIOD_M3;
input int             InpContextPivotSpan         = 2;
input int             InpPatternPivotSpan         = 2;
input int             InpExecutionPivotSpan       = 1;
input int             InpContextScanBars          = 240;
input int             InpPatternScanBars          = 200;
input int             InpExecutionScanBars        = 80;
input int             InpContextRangeBars         = 48;
input int             InpPatternRangeBars         = 40;
input int             InpContextFastEMAPeriod     = 20;
input int             InpContextSlowEMAPeriod     = 50;
input int             InpContextATRPeriod         = 14;
input int             InpPatternATRPeriod         = 14;
input int             InpExecutionATRPeriod       = 14;
input double          InpContextHighZoneMin       = 0.70;
input double          InpContextLowZoneMax        = 0.30;
input ExternalLevelMode InpExternalLevelMode      = EXT_LEVEL_CONTEXT_PRIOR_SWING;
input double          InpSweepATRMultiple         = 0.18;
input double          InpTierAMinSweepPips        = 3.0;
input double          InpTierBMinSweepPips        = 1.5;
input double          InpMinPatternHeightPips     = 6.0;
input double          InpMinPatternHeightATR      = 0.35;
input double          InpReclaimBufferPips        = 0.8;
input double          InpMinBreakBufferPips       = 0.6;
input double          InpBreakBufferATR           = 0.08;
input double          InpRetestTolerancePips      = 0.8;
input double          InpLowerHighToleranceATR    = 0.18;
input double          InpMinLowerHighGapPips      = 1.0;
input double          InpTierAMaxCloseLocation    = 0.45;
input double          InpTierBMaxCloseLocation    = 0.60;
input EntryTierMode   InpTierMode                 = ENTRY_TIER_A_ONLY;
input TradeBiasMode   InpTradeBiasMode            = TRADE_BIAS_SHORT_ONLY;
input ExecutionTriggerMode InpExecutionTriggerMode = EXEC_RECLAIM_CLOSE_CONFIRM;
input PartialTargetLevel InpPartialTargetLevel    = PARTIAL_TARGET_382;
input FinalTargetMode InpFinalTargetMode          = FINAL_TARGET_FIB_618;
input double          InpTargetRMultiple          = 1.40;
input double          InpMinStopBufferPips        = 1.4;
input double          InpStopBufferATR            = 0.10;
input double          InpAcceptanceExitBufferPips = 0.5;
input double          InpHybridPartialFraction    = 0.50;
input int             InpSetupExpiryBars          = 24;
input int             InpMaxHoldBars              = 24;
input double          InpRiskPercent              = 0.35;
input int             InpSessionStartHour         = 0;
input int             InpSessionEndHour           = 0;
input double          InpMaxSpreadPips            = 2.0;
input bool            InpEnableTelemetry          = true;
input string          InpTelemetryFileName        = "mt5_company_usdjpy_20260416_external_liquidity_sweep_failed_acceptance.csv";
input long            InpMagicNumber              = 202604162;

string runtimeSymbol = "";
string runtimeTelemetryFileName = "";
datetime lastPatternBarTime = 0;
datetime lastExecutionBarTime = 0;
int contextFastHandle = INVALID_HANDLE;
int contextSlowHandle = INVALID_HANDLE;
int contextAtrHandle = INVALID_HANDLE;
int patternAtrHandle = INVALID_HANDLE;
int executionAtrHandle = INVALID_HANDLE;
int telemetryHandle = INVALID_HANDLE;

EntryPlan pendingPlan;
EntryPlan activePlan;
PendingExecutionContext pendingExecution;
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

double CloseLocation(double highPrice, double lowPrice, double closePrice)
  {
   double range = highPrice - lowPrice;
   if(range <= 0.0)
      return 0.5;
   return (closePrice - lowPrice) / range;
  }

string VolatilityBucket(double atrPips)
  {
   if(atrPips < 5.0)
      return "quiet";
   if(atrPips < 9.0)
      return "normal";
   return "expanded";
  }

string ContextPhaseLabel(ContextPhase phase)
  {
   switch(phase)
     {
      case CTX_UP_IMPULSE: return "ctx_up_impulse";
      case CTX_UP_EXHAUSTION: return "ctx_up_exhaustion";
      case CTX_RANGE_TOP: return "ctx_range_top";
      case CTX_RANGE_MIDDLE: return "ctx_range_middle";
      case CTX_RANGE_BOTTOM: return "ctx_range_bottom";
      case CTX_DOWN_IMPULSE: return "ctx_down_impulse";
      case CTX_DOWN_EXHAUSTION: return "ctx_down_exhaustion";
     default: return "ctx_unknown";
     }
  }

string ExternalLevelModeLabel(ExternalLevelMode mode)
  {
   switch(mode)
     {
      case EXT_LEVEL_M30_PRIOR_SWING: return "m30_prior_swing";
      case EXT_LEVEL_PREVIOUS_DAY_EXTREME: return "previous_day_extreme";
      case EXT_LEVEL_ALL: return "all_external_levels";
      default: return "context_prior_swing";
     }
  }

string PatternStateLabel(PatternState state)
  {
   switch(state)
     {
      case PATTERN_EXTERNAL_LEVEL_IDENTIFIED: return "external_level_identified";
      case PATTERN_SWEEP_UP: return "sweep_up";
      case PATTERN_FAILED_ACCEPTANCE_ABOVE: return "failed_acceptance_above";
      case PATTERN_RECLAIMED_BACK_INSIDE_SHORT:
      case PATTERN_RECLAIMED_BACK_INSIDE_LONG: return "reclaimed_back_inside";
      case PATTERN_RETEST_REJECTED: return "retest_rejected";
      case PATTERN_BREAKDOWN_READY: return "breakdown_ready";
      case PATTERN_SWEEP_DOWN: return "sweep_down";
      case PATTERN_FAILED_ACCEPTANCE_BELOW: return "failed_acceptance_below";
      case PATTERN_RETEST_HELD: return "retest_held";
      case PATTERN_BREAKOUT_READY: return "breakout_ready";
      default: return "none";
     }
  }

string ExecutionTriggerModeLabel(ExecutionTriggerMode mode)
  {
   switch(mode)
     {
      case EXEC_RETEST_FAILURE: return "exec_retest_failure";
      case EXEC_RECENT_SWING_BREAKDOWN: return "exec_recent_swing_breakdown";
      default: return "exec_reclaim_close_confirm";
     }
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
      default: return EnumToString(tf);
     }
  }

string PartialTargetLevelLabel(PartialTargetLevel level)
  {
   if(level == PARTIAL_TARGET_500)
      return "partial_fib_500";
   return "partial_fib_382";
  }

string FinalTargetModeLabel(FinalTargetMode mode)
  {
   switch(mode)
     {
      case FINAL_TARGET_PRIOR_SWING: return "final_prior_swing";
      case FINAL_TARGET_FIXED_R: return "final_fixed_r";
      default: return "final_fib_618";
     }
  }

void ResetPivot(PivotPoint &pivot)
  {
   pivot.valid = false;
   pivot.isHigh = false;
   pivot.shift = 0;
   pivot.price = 0.0;
   pivot.time = 0;
  }

void ResetExternalLiquidityLevel(ExternalLiquidityLevel &level)
  {
   level.valid = false;
   level.direction = 0;
   level.levelTypeLabel = "";
   level.price = 0.0;
   level.sourceTime = 0;
  }

void ResetSweepFailureSetup(SweepFailureSetup &setup)
  {
   setup.valid = false;
   setup.direction = 0;
   setup.tier = "";
   setup.sideLabel = "";
   setup.contextPhaseLabel = "";
   setup.contextBucket = "";
   setup.waveLabel = "";
   setup.externalLevelTypeLabel = "";
   setup.patternLabel = "";
   setup.patternStateLabel = "";
   setup.volatilityBucket = "";
    ResetExternalLiquidityLevel(setup.externalLevel);
   ResetPivot(setup.referencePivot);
   ResetPivot(setup.sweepPivot);
   ResetPivot(setup.continuationPivot);
   ResetPivot(setup.failurePivot);
   setup.referenceLevel = 0.0;
   setup.reclaimLevel = 0.0;
   setup.retestLevel = 0.0;
   setup.continuationLevel = 0.0;
   setup.stopAnchor = 0.0;
   setup.invalidationLevel = 0.0;
   setup.priorSwingTarget = 0.0;
   setup.structureHeight = 0.0;
   setup.structureHeightPips = 0.0;
   setup.patternAtrPips = 0.0;
   setup.currentCloseLocation = 0.0;
   setup.setupTime = 0;
  }

void ResetEntryPlan(EntryPlan &plan)
  {
   plan.valid = false;
   plan.direction = 0;
   plan.tier = "";
   plan.sideLabel = "";
   plan.contextPhaseLabel = "";
   plan.contextBucket = "";
   plan.waveLabel = "";
   plan.externalLevelTypeLabel = "";
   plan.patternLabel = "";
   plan.patternStateLabel = "";
   plan.executionTriggerLabel = "";
   plan.patternTimeframe = "";
   plan.executionTimeframe = "";
   plan.partialTargetLabel = "";
   plan.finalTargetLabel = "";
   plan.volatilityBucket = "";
   plan.referenceLevel = 0.0;
   plan.continuationLevel = 0.0;
   plan.structureHeightPips = 0.0;
   plan.patternAtrPips = 0.0;
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
   plan.reason = "";
  }

void ResetPendingExecution(PendingExecutionContext &ctx)
  {
   ctx.valid = false;
   ResetSweepFailureSetup(ctx.setup);
   ctx.setupBaselineEntry = 0.0;
   ctx.detectedTime = 0;
   ctx.recentSwingLevel = 0.0;
   ctx.recentSwingLabel = "";
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

void AppendPivot(PivotPoint &pivots[], const PivotPoint &pivot)
  {
   int size = ArraySize(pivots);
   ArrayResize(pivots, size + 1);
   pivots[size] = pivot;
  }

bool CollectConfirmedPivots(string symbol,
                            ENUM_TIMEFRAMES tf,
                            int span,
                            int scanBars,
                            PivotPoint &pivots[])
  {
   ArrayResize(pivots, 0);
   int bars = Bars(symbol, tf);
   if(bars <= span * 3 + 5)
      return false;

   int startShift = span + 1;
   int endShift = MathMin(scanBars, bars - span - 2);
   if(endShift <= startShift)
      return false;

   for(int shift = endShift; shift >= startShift; --shift)
     {
      if(IsPivotHigh(symbol, tf, shift, span))
        {
         PivotPoint pivot;
         pivot.valid = true;
         pivot.isHigh = true;
         pivot.shift = shift;
         pivot.price = iHigh(symbol, tf, shift);
         pivot.time = iTime(symbol, tf, shift);
         AppendPivot(pivots, pivot);
        }

      if(IsPivotLow(symbol, tf, shift, span))
        {
         PivotPoint pivot;
         pivot.valid = true;
         pivot.isHigh = false;
         pivot.shift = shift;
         pivot.price = iLow(symbol, tf, shift);
         pivot.time = iTime(symbol, tf, shift);
         AppendPivot(pivots, pivot);
        }
     }

   return (ArraySize(pivots) >= 5);
  }

bool FindLatestTypePivots(const PivotPoint &pivots[],
                          bool wantHigh,
                          PivotPoint &latest,
                          PivotPoint &previous)
  {
   ResetPivot(latest);
   ResetPivot(previous);
   int count = ArraySize(pivots);
   for(int i = count - 1; i >= 0; --i)
     {
      if(pivots[i].isHigh != wantHigh)
         continue;
      if(!latest.valid)
         latest = pivots[i];
      else
        {
         previous = pivots[i];
         break;
        }
     }
   return (latest.valid && previous.valid);
  }

double ComputeRangeHigh(ENUM_TIMEFRAMES tf, int startShift, int lookback)
  {
   double highest = -DBL_MAX;
   for(int shift = startShift; shift < startShift + lookback; ++shift)
     {
      double value = iHigh(runtimeSymbol, tf, shift);
      if(value <= 0.0)
         return DBL_MAX;
      if(value > highest)
         highest = value;
     }
   return highest;
  }

double ComputeRangeLow(ENUM_TIMEFRAMES tf, int startShift, int lookback)
  {
   double lowest = DBL_MAX;
   for(int shift = startShift; shift < startShift + lookback; ++shift)
     {
      double value = iLow(runtimeSymbol, tf, shift);
      if(value <= 0.0)
         return DBL_MAX;
      if(value < lowest)
         lowest = value;
     }
   return lowest;
  }

double ComputeFibRetracementRatio(double lowPrice, double highPrice, double price)
  {
   double range = highPrice - lowPrice;
   if(range <= 0.0)
      return 0.0;
   double ratio = (highPrice - price) / range;
   if(ratio < 0.0)
      ratio = 0.0;
   if(ratio > 1.5)
      ratio = 1.5;
   return ratio;
  }

string BuildTrendLabel(const PivotPoint &latestHigh,
                       const PivotPoint &previousHigh,
                       const PivotPoint &latestLow,
                       const PivotPoint &previousLow)
  {
   bool hh = latestHigh.price > previousHigh.price;
   bool hl = latestLow.price > previousLow.price;
   bool lh = latestHigh.price < previousHigh.price;
   bool ll = latestLow.price < previousLow.price;

   if(hh && hl)
      return "hh_hl";
   if(lh && ll)
      return "lh_ll";
   if(hh && ll)
      return "hh_ll";
   if(lh && hl)
      return "lh_hl";
   return "mixed";
  }

ContextPhase ClassifyContextPhase(const string trendLabel,
                                  double closePrice,
                                  double emaFast,
                                  double emaSlow,
                                  double rangePosition,
                                  double retraceRatio)
  {
   if(trendLabel == "hh_hl")
     {
      if(closePrice >= emaFast && rangePosition >= 0.60 && retraceRatio <= 0.382)
         return CTX_UP_IMPULSE;
      if(rangePosition >= InpContextHighZoneMin && (closePrice < emaFast || retraceRatio > 0.382))
         return CTX_UP_EXHAUSTION;
      if(rangePosition >= InpContextHighZoneMin)
         return CTX_RANGE_TOP;
      return CTX_RANGE_MIDDLE;
     }

   if(trendLabel == "lh_ll")
     {
      if(closePrice <= emaFast && rangePosition <= 0.40 && retraceRatio <= 0.382)
         return CTX_DOWN_IMPULSE;
      if(rangePosition <= InpContextLowZoneMax && (closePrice > emaFast || retraceRatio > 0.382))
         return CTX_DOWN_EXHAUSTION;
      if(rangePosition <= InpContextLowZoneMax)
         return CTX_RANGE_BOTTOM;
      return CTX_RANGE_MIDDLE;
     }

   if(rangePosition >= InpContextHighZoneMin)
      return CTX_RANGE_TOP;
   if(rangePosition <= InpContextLowZoneMax)
      return CTX_RANGE_BOTTOM;
   return CTX_RANGE_MIDDLE;
  }

string BuildContextBucket(ContextPhase phase)
  {
   switch(phase)
     {
      case CTX_UP_IMPULSE: return "ctx_up_impulse";
      case CTX_UP_EXHAUSTION: return "ctx_up_exhaustion";
      case CTX_RANGE_TOP: return "ctx_range_top";
      case CTX_RANGE_BOTTOM: return "ctx_range_bottom";
      case CTX_DOWN_IMPULSE: return "ctx_down_impulse";
      case CTX_DOWN_EXHAUSTION: return "ctx_down_exhaustion";
      default: return "ctx_range_middle";
     }
  }

bool BuildContextPhase(ContextPhaseContext &ctx)
  {
   ctx.valid = false;

   PivotPoint pivots[];
   if(!CollectConfirmedPivots(runtimeSymbol, InpContextTimeframe, InpContextPivotSpan, InpContextScanBars, pivots))
      return false;

   if(!FindLatestTypePivots(pivots, true, ctx.latestHigh, ctx.previousHigh))
      return false;
   if(!FindLatestTypePivots(pivots, false, ctx.latestLow, ctx.previousLow))
      return false;

   double close1 = iClose(runtimeSymbol, InpContextTimeframe, 1);
   if(close1 <= 0.0)
      return false;

   if(!LoadSingleBuffer(contextFastHandle, 1, ctx.emaFast) ||
      !LoadSingleBuffer(contextSlowHandle, 1, ctx.emaSlow) ||
      !LoadSingleBuffer(contextAtrHandle, 1, ctx.atr))
      return false;

   ctx.rangeHigh = ComputeRangeHigh(InpContextTimeframe, 1, InpContextRangeBars);
   ctx.rangeLow = ComputeRangeLow(InpContextTimeframe, 1, InpContextRangeBars);
   if(ctx.rangeHigh == DBL_MAX || ctx.rangeLow == DBL_MAX || ctx.rangeHigh <= ctx.rangeLow)
      return false;

   ctx.rangePosition = (close1 - ctx.rangeLow) / (ctx.rangeHigh - ctx.rangeLow);
   ctx.trendLabel = BuildTrendLabel(ctx.latestHigh, ctx.previousHigh, ctx.latestLow, ctx.previousLow);

   if(ctx.trendLabel == "hh_hl")
     {
      ctx.activeWaveHigh = ctx.latestHigh.price;
      ctx.activeWaveLow = ctx.previousLow.valid ? ctx.previousLow.price : ctx.latestLow.price;
      ctx.waveLabel = "parent_up_wave";
     }
   else if(ctx.trendLabel == "lh_ll")
     {
      ctx.activeWaveHigh = ctx.previousHigh.valid ? ctx.previousHigh.price : ctx.latestHigh.price;
      ctx.activeWaveLow = ctx.latestLow.price;
      ctx.waveLabel = "parent_down_wave";
     }
   else
     {
      ctx.activeWaveHigh = ctx.rangeHigh;
      ctx.activeWaveLow = ctx.rangeLow;
      ctx.waveLabel = "parent_range_wave";
     }

   if(ctx.activeWaveHigh <= ctx.activeWaveLow)
      return false;

   ctx.activeWaveClose = close1;
   ctx.activeWaveRetracement = ComputeFibRetracementRatio(ctx.activeWaveLow, ctx.activeWaveHigh, close1);
   ctx.phase = ClassifyContextPhase(ctx.trendLabel,
                                    close1,
                                    ctx.emaFast,
                                    ctx.emaSlow,
                                    ctx.rangePosition,
                                    ctx.activeWaveRetracement);
   ctx.phaseLabel = ContextPhaseLabel(ctx.phase);
   ctx.contextBucket = BuildContextBucket(ctx.phase);
   ctx.priorSwingHigh = MathMax(ctx.latestHigh.price, ctx.previousHigh.price);
   ctx.priorSwingLow = MathMin(ctx.latestLow.price, ctx.previousLow.price);
   ctx.tierAShortEligible = (ctx.phase == CTX_UP_EXHAUSTION || ctx.phase == CTX_RANGE_TOP);
   ctx.tierALongEligible = (ctx.phase == CTX_DOWN_EXHAUSTION || ctx.phase == CTX_RANGE_BOTTOM);
   ctx.tierBShortEligible = (ctx.tierAShortEligible || ctx.phase == CTX_UP_IMPULSE);
   ctx.tierBLongEligible = (ctx.tierALongEligible || ctx.phase == CTX_DOWN_IMPULSE);
   ctx.valid = true;
   return true;
  }

void AppendExternalLiquidityLevel(ExternalLiquidityLevel &levels[], const ExternalLiquidityLevel &level)
  {
   if(!level.valid)
      return;
   int size = ArraySize(levels);
   ArrayResize(levels, size + 1);
   levels[size] = level;
  }

int DayKey(datetime value)
  {
   MqlDateTime tm;
   TimeToStruct(value, tm);
   return tm.year * 1000 + tm.day_of_year;
  }

bool BuildPreviousTradingDayExtreme(bool wantHigh, double &price, datetime &sourceTime)
  {
   price = 0.0;
   sourceTime = 0;

   int bars = Bars(runtimeSymbol, PERIOD_M30);
   if(bars < 4)
      return false;

   datetime currentTime = iTime(runtimeSymbol, PERIOD_M30, 1);
   if(currentTime <= 0)
      return false;

   int currentDayKey = DayKey(currentTime);
   int previousDayKey = -1;

   for(int shift = 1; shift < bars; ++shift)
     {
      datetime barTime = iTime(runtimeSymbol, PERIOD_M30, shift);
      if(barTime <= 0)
         break;

      int barDayKey = DayKey(barTime);
      if(barDayKey == currentDayKey)
         continue;

      if(previousDayKey < 0)
         previousDayKey = barDayKey;
      if(barDayKey != previousDayKey)
         break;

      double value = wantHigh ? iHigh(runtimeSymbol, PERIOD_M30, shift) : iLow(runtimeSymbol, PERIOD_M30, shift);
      if(value <= 0.0)
         continue;

      if(sourceTime == 0)
        {
         price = value;
         sourceTime = barTime;
         continue;
        }

      if((wantHigh && value > price) || (!wantHigh && value < price))
         price = value;

      if(barTime > sourceTime)
         sourceTime = barTime;
     }

   return (sourceTime > 0);
  }

bool BuildM30PriorSwingLevel(bool wantHigh, ExternalLiquidityLevel &level)
  {
   ResetExternalLiquidityLevel(level);

   PivotPoint pivots[];
   if(!CollectConfirmedPivots(runtimeSymbol, PERIOD_M30, InpContextPivotSpan, InpContextScanBars, pivots))
      return false;

   PivotPoint latest;
   PivotPoint previous;
   if(!FindLatestTypePivots(pivots, wantHigh, latest, previous))
      return false;

   level.valid = true;
   level.direction = wantHigh ? -1 : 1;
   level.levelTypeLabel = "m30_prior_swing";
   level.price = latest.price;
   level.sourceTime = latest.time;
   return true;
  }

bool BuildContextPriorSwingLevel(const ContextPhaseContext &ctx, bool wantHigh, ExternalLiquidityLevel &level)
  {
   ResetExternalLiquidityLevel(level);

   double price = 0.0;
   datetime sourceTime = 0;
   if(wantHigh)
     {
      PivotPoint sourcePivot = (ctx.latestHigh.price >= ctx.previousHigh.price) ? ctx.latestHigh : ctx.previousHigh;
      price = sourcePivot.price;
      sourceTime = sourcePivot.time;
     }
   else
     {
      PivotPoint sourcePivot = (ctx.latestLow.price <= ctx.previousLow.price) ? ctx.latestLow : ctx.previousLow;
      price = sourcePivot.price;
      sourceTime = sourcePivot.time;
     }
   if(price <= 0.0 || sourceTime <= 0)
      return false;

   level.valid = true;
   level.direction = wantHigh ? -1 : 1;
   level.levelTypeLabel = "context_prior_swing";
   level.price = price;
   level.sourceTime = sourceTime;
   return true;
  }

bool BuildPreviousDayLevel(bool wantHigh, ExternalLiquidityLevel &level)
  {
   ResetExternalLiquidityLevel(level);

   double price = 0.0;
   datetime sourceTime = 0;
   if(!BuildPreviousTradingDayExtreme(wantHigh, price, sourceTime))
      return false;

   level.valid = true;
   level.direction = wantHigh ? -1 : 1;
   level.levelTypeLabel = "previous_day_extreme";
   level.price = price;
   level.sourceTime = sourceTime;
   return true;
  }

bool BuildExternalLiquidityLevels(const ContextPhaseContext &ctx,
                                  int direction,
                                  ExternalLiquidityLevel &levels[])
  {
   ArrayResize(levels, 0);

   bool wantHigh = (direction < 0);
   ExternalLiquidityLevel level;

   if(InpExternalLevelMode == EXT_LEVEL_CONTEXT_PRIOR_SWING || InpExternalLevelMode == EXT_LEVEL_ALL)
     {
      if(BuildContextPriorSwingLevel(ctx, wantHigh, level))
         AppendExternalLiquidityLevel(levels, level);
     }

   if(InpExternalLevelMode == EXT_LEVEL_M30_PRIOR_SWING || InpExternalLevelMode == EXT_LEVEL_ALL)
     {
      if(BuildM30PriorSwingLevel(wantHigh, level))
         AppendExternalLiquidityLevel(levels, level);
     }

   if(InpExternalLevelMode == EXT_LEVEL_PREVIOUS_DAY_EXTREME || InpExternalLevelMode == EXT_LEVEL_ALL)
     {
      if(BuildPreviousDayLevel(wantHigh, level))
         AppendExternalLiquidityLevel(levels, level);
     }

   return (ArraySize(levels) > 0);
  }

bool BuildSweepFailurePattern(PivotPoint &pivots[], PatternStructureContext &structure)
  {
   structure.valid = false;
   ArrayResize(pivots, 0);

   if(!CollectConfirmedPivots(runtimeSymbol, InpPatternTimeframe, InpPatternPivotSpan, InpPatternScanBars, pivots))
      return false;

   if(!LoadSingleBuffer(patternAtrHandle, 1, structure.patternAtr) ||
      !LoadSingleBuffer(executionAtrHandle, 1, structure.executionAtr))
      return false;

   structure.currentOpen = iOpen(runtimeSymbol, InpPatternTimeframe, 1);
   structure.currentHigh = iHigh(runtimeSymbol, InpPatternTimeframe, 1);
   structure.currentLow = iLow(runtimeSymbol, InpPatternTimeframe, 1);
   structure.currentClose = iClose(runtimeSymbol, InpPatternTimeframe, 1);
   if(structure.currentOpen <= 0.0 || structure.currentHigh <= 0.0 ||
      structure.currentLow <= 0.0 || structure.currentClose <= 0.0)
      return false;

   structure.localRangeHigh = ComputeRangeHigh(InpPatternTimeframe, 1, InpPatternRangeBars);
   structure.localRangeLow = ComputeRangeLow(InpPatternTimeframe, 1, InpPatternRangeBars);
   if(structure.localRangeHigh == DBL_MAX || structure.localRangeLow == DBL_MAX)
      return false;

   structure.patternAtrPips = structure.patternAtr / GetPipSize();
   structure.executionAtrPips = structure.executionAtr / GetPipSize();
   structure.sweepFloor = MathMax(PipsToPrice(InpTierBMinSweepPips),
                                  structure.patternAtr * InpSweepATRMultiple);
   structure.structureFloor = MathMax(PipsToPrice(InpMinPatternHeightPips),
                                      structure.patternAtr * InpMinPatternHeightATR);
   structure.reclaimBuffer = PipsToPrice(InpReclaimBufferPips);
   structure.breakBuffer = MathMax(PipsToPrice(InpMinBreakBufferPips),
                                   structure.executionAtr * InpBreakBufferATR);
   structure.retestTolerance = PipsToPrice(InpRetestTolerancePips);
   structure.failureGap = MathMax(PipsToPrice(InpMinLowerHighGapPips),
                                  structure.patternAtr * InpLowerHighToleranceATR);
   structure.currentCloseLocation = CloseLocation(structure.currentHigh, structure.currentLow, structure.currentClose);
   structure.volatilityBucket = VolatilityBucket(structure.executionAtrPips);
   structure.valid = true;
   return true;
  }

bool SpacingOk(const PivotPoint &a, const PivotPoint &b)
  {
   return (MathAbs(a.shift - b.shift) >= 2);
  }

bool ShortBiasAllowed()
  {
   return (InpTradeBiasMode == TRADE_BIAS_SHORT_ONLY || InpTradeBiasMode == TRADE_BIAS_BOTH);
  }

bool LongBiasAllowed()
  {
   return (InpTradeBiasMode == TRADE_BIAS_LONG_ONLY || InpTradeBiasMode == TRADE_BIAS_BOTH);
  }

PivotPoint PivotFromExternalLevel(const ExternalLiquidityLevel &level)
  {
   PivotPoint pivot;
   pivot.valid = level.valid;
   pivot.isHigh = (level.direction < 0);
   pivot.shift = 0;
   pivot.price = level.price;
   pivot.time = level.sourceTime;
   return pivot;
  }

void FillShortPatternState(const PatternStructureContext &structure,
                           const ExternalLiquidityLevel &level,
                           const PivotPoint &reclaimLow,
                           string &stateLabel)
  {
   stateLabel = PatternStateLabel(PATTERN_RETEST_REJECTED);
   if(structure.currentClose <= reclaimLow.price - structure.breakBuffer)
      stateLabel = PatternStateLabel(PATTERN_BREAKDOWN_READY);
   else if(structure.currentClose <= level.price - structure.reclaimBuffer)
      stateLabel = PatternStateLabel(PATTERN_RECLAIMED_BACK_INSIDE_SHORT);
  }

void FillLongPatternState(const PatternStructureContext &structure,
                          const ExternalLiquidityLevel &level,
                          const PivotPoint &reclaimHigh,
                          string &stateLabel)
  {
   stateLabel = PatternStateLabel(PATTERN_RETEST_HELD);
   if(structure.currentClose >= reclaimHigh.price + structure.breakBuffer)
      stateLabel = PatternStateLabel(PATTERN_BREAKOUT_READY);
   else if(structure.currentClose >= level.price + structure.reclaimBuffer)
      stateLabel = PatternStateLabel(PATTERN_RECLAIMED_BACK_INSIDE_LONG);
  }

bool FillShortExternalSweepFailureSetup(const ContextPhaseContext &ctx,
                                        const PatternStructureContext &structure,
                                        const ExternalLiquidityLevel &level,
                                        const PivotPoint &sweepHigh,
                                        const PivotPoint &reclaimLow,
                                        const PivotPoint &retestHigh,
                                        const string tier,
                                        SweepFailureSetup &setup)
  {
   ResetSweepFailureSetup(setup);

   double tierSweepFloor = (tier == "tier_a") ? PipsToPrice(InpTierAMinSweepPips) : PipsToPrice(InpTierBMinSweepPips);
   double sweepSize = sweepHigh.price - level.price;
   if(sweepHigh.time <= level.sourceTime || sweepSize < structure.sweepFloor || sweepSize < tierSweepFloor)
      return false;

   if(!(sweepHigh.time < reclaimLow.time && reclaimLow.time < retestHigh.time))
      return false;
   if(reclaimLow.price >= level.price - structure.reclaimBuffer)
      return false;

   double structureHeight = sweepHigh.price - reclaimLow.price;
   if(structureHeight < structure.structureFloor)
      return false;

   if(retestHigh.price >= sweepHigh.price - structure.failureGap)
      return false;
   if(retestHigh.price < level.price - (structure.reclaimBuffer + structure.retestTolerance))
      return false;
   if(structure.currentClose > level.price - structure.reclaimBuffer)
      return false;

   double maxCloseLocation = (tier == "tier_a") ? InpTierAMaxCloseLocation : InpTierBMaxCloseLocation;
   if(structure.currentCloseLocation > maxCloseLocation)
      return false;

   setup.valid = true;
   setup.direction = -1;
   setup.tier = tier;
   setup.sideLabel = "short";
   setup.contextPhaseLabel = ctx.phaseLabel;
   setup.contextBucket = ctx.contextBucket;
   setup.waveLabel = ctx.waveLabel;
   setup.externalLevelTypeLabel = level.levelTypeLabel;
   setup.patternLabel = "external_liquidity_sweep_failed_acceptance";
   FillShortPatternState(structure, level, reclaimLow, setup.patternStateLabel);
   setup.volatilityBucket = structure.volatilityBucket;
   setup.externalLevel = level;
   setup.referencePivot = PivotFromExternalLevel(level);
   setup.sweepPivot = sweepHigh;
   setup.continuationPivot = reclaimLow;
   setup.failurePivot = retestHigh;
   setup.referenceLevel = level.price;
   setup.reclaimLevel = level.price - structure.reclaimBuffer;
   setup.retestLevel = level.price + structure.retestTolerance;
   setup.continuationLevel = reclaimLow.price;
   setup.stopAnchor = MathMax(sweepHigh.price, retestHigh.price);
   setup.invalidationLevel = level.price + PipsToPrice(InpAcceptanceExitBufferPips);
   setup.priorSwingTarget = ctx.priorSwingLow;
   setup.structureHeight = structureHeight;
   setup.structureHeightPips = structureHeight / GetPipSize();
   setup.patternAtrPips = structure.patternAtrPips;
   setup.currentCloseLocation = structure.currentCloseLocation;
   setup.setupTime = iTime(runtimeSymbol, InpPatternTimeframe, 1);
   return true;
  }

bool FillLongExternalSweepFailureSetup(const ContextPhaseContext &ctx,
                                       const PatternStructureContext &structure,
                                       const ExternalLiquidityLevel &level,
                                       const PivotPoint &sweepLow,
                                       const PivotPoint &reclaimHigh,
                                       const PivotPoint &retestLow,
                                       const string tier,
                                       SweepFailureSetup &setup)
  {
   ResetSweepFailureSetup(setup);

   double tierSweepFloor = (tier == "tier_a") ? PipsToPrice(InpTierAMinSweepPips) : PipsToPrice(InpTierBMinSweepPips);
   double sweepSize = level.price - sweepLow.price;
   if(sweepLow.time <= level.sourceTime || sweepSize < structure.sweepFloor || sweepSize < tierSweepFloor)
      return false;

   if(!(sweepLow.time < reclaimHigh.time && reclaimHigh.time < retestLow.time))
      return false;
   if(reclaimHigh.price <= level.price + structure.reclaimBuffer)
      return false;

   double structureHeight = reclaimHigh.price - sweepLow.price;
   if(structureHeight < structure.structureFloor)
      return false;

   if(retestLow.price <= sweepLow.price + structure.failureGap)
      return false;
   if(retestLow.price > level.price + (structure.reclaimBuffer + structure.retestTolerance))
      return false;
   if(structure.currentClose < level.price + structure.reclaimBuffer)
      return false;

   double minCloseLocation = 1.0 - ((tier == "tier_a") ? InpTierAMaxCloseLocation : InpTierBMaxCloseLocation);
   if(structure.currentCloseLocation < minCloseLocation)
      return false;

   setup.valid = true;
   setup.direction = 1;
   setup.tier = tier;
   setup.sideLabel = "long";
   setup.contextPhaseLabel = ctx.phaseLabel;
   setup.contextBucket = ctx.contextBucket;
   setup.waveLabel = ctx.waveLabel;
   setup.externalLevelTypeLabel = level.levelTypeLabel;
   setup.patternLabel = "external_liquidity_sweep_failed_acceptance";
   FillLongPatternState(structure, level, reclaimHigh, setup.patternStateLabel);
   setup.volatilityBucket = structure.volatilityBucket;
   setup.externalLevel = level;
   setup.referencePivot = PivotFromExternalLevel(level);
   setup.sweepPivot = sweepLow;
   setup.continuationPivot = reclaimHigh;
   setup.failurePivot = retestLow;
   setup.referenceLevel = level.price;
   setup.reclaimLevel = level.price + structure.reclaimBuffer;
   setup.retestLevel = level.price - structure.retestTolerance;
   setup.continuationLevel = reclaimHigh.price;
   setup.stopAnchor = MathMin(sweepLow.price, retestLow.price);
   setup.invalidationLevel = level.price - PipsToPrice(InpAcceptanceExitBufferPips);
   setup.priorSwingTarget = ctx.priorSwingHigh;
   setup.structureHeight = structureHeight;
   setup.structureHeightPips = structureHeight / GetPipSize();
   setup.patternAtrPips = structure.patternAtrPips;
   setup.currentCloseLocation = structure.currentCloseLocation;
   setup.setupTime = iTime(runtimeSymbol, InpPatternTimeframe, 1);
   return true;
  }

bool DetectShortExternalSweepFailureSetup(const ContextPhaseContext &ctx,
                                          const PatternStructureContext &structure,
                                          const PivotPoint &pivots[],
                                          SweepFailureSetup &setup)
  {
   ResetSweepFailureSetup(setup);
   if(!ShortBiasAllowed() || !ctx.valid || !structure.valid)
      return false;

   string tier = "";
   if(ctx.tierAShortEligible)
      tier = "tier_a";
   else if(InpTierMode == ENTRY_TIER_A_AND_B && ctx.tierBShortEligible)
      tier = "tier_b";
   else
      return false;

   ExternalLiquidityLevel levels[];
   if(!BuildExternalLiquidityLevels(ctx, -1, levels))
      return false;

   int count = ArraySize(pivots);
   for(int levelIndex = 0; levelIndex < ArraySize(levels); ++levelIndex)
     {
      ExternalLiquidityLevel level = levels[levelIndex];
      for(int i = count - 1; i >= 2; --i)
        {
         PivotPoint p0 = pivots[i - 2];
         PivotPoint p1 = pivots[i - 1];
         PivotPoint p2 = pivots[i];

         if(!(p0.isHigh && !p1.isHigh && p2.isHigh))
            continue;
         if(!(SpacingOk(p0, p1) && SpacingOk(p1, p2)))
            continue;
         if(p0.time <= level.sourceTime)
            continue;

         if(FillShortExternalSweepFailureSetup(ctx, structure, level, p0, p1, p2, tier, setup))
            return true;
        }
     }

   return false;
  }

bool DetectLongExternalSweepFailureSetup(const ContextPhaseContext &ctx,
                                         const PatternStructureContext &structure,
                                         const PivotPoint &pivots[],
                                         SweepFailureSetup &setup)
  {
   ResetSweepFailureSetup(setup);
   if(!LongBiasAllowed() || !ctx.valid || !structure.valid)
      return false;

   string tier = "";
   if(ctx.tierALongEligible)
      tier = "tier_a";
   else if(InpTierMode == ENTRY_TIER_A_AND_B && ctx.tierBLongEligible)
      tier = "tier_b";
   else
      return false;

   ExternalLiquidityLevel levels[];
   if(!BuildExternalLiquidityLevels(ctx, 1, levels))
      return false;

   int count = ArraySize(pivots);
   for(int levelIndex = 0; levelIndex < ArraySize(levels); ++levelIndex)
     {
      ExternalLiquidityLevel level = levels[levelIndex];
      for(int i = count - 1; i >= 2; --i)
        {
         PivotPoint p0 = pivots[i - 2];
         PivotPoint p1 = pivots[i - 1];
         PivotPoint p2 = pivots[i];

         if(!(!p0.isHigh && p1.isHigh && !p2.isHigh))
            continue;
         if(!(SpacingOk(p0, p1) && SpacingOk(p1, p2)))
            continue;
         if(p0.time <= level.sourceTime)
            continue;

         if(FillLongExternalSweepFailureSetup(ctx, structure, level, p0, p1, p2, tier, setup))
            return true;
        }
     }

   return false;
  }

bool ResolveRecentExecutionSwingLevel(PendingExecutionContext &ctx)
  {
   if(!ctx.valid)
      return false;

   PivotPoint pivots[];
   if(CollectConfirmedPivots(runtimeSymbol, InpExecutionTimeframe, InpExecutionPivotSpan, InpExecutionScanBars, pivots))
     {
      for(int i = ArraySize(pivots) - 1; i >= 0; --i)
        {
         if(ctx.setup.direction < 0 && pivots[i].isHigh)
            continue;
         if(ctx.setup.direction > 0 && !pivots[i].isHigh)
            continue;
         if(pivots[i].time < ctx.setup.failurePivot.time)
            continue;
         ctx.recentSwingLevel = pivots[i].price;
         ctx.recentSwingLabel = ctx.setup.direction < 0 ? "recent_exec_swing_low" : "recent_exec_swing_high";
         return true;
        }
     }

   if(ctx.setup.direction < 0)
     {
      int shift = iLowest(runtimeSymbol, InpExecutionTimeframe, MODE_LOW, InpExecutionScanBars, 1);
      if(shift < 0)
         return false;
      ctx.recentSwingLevel = iLow(runtimeSymbol, InpExecutionTimeframe, shift);
      ctx.recentSwingLabel = "recent_exec_range_low";
     }
   else
     {
      int shift = iHighest(runtimeSymbol, InpExecutionTimeframe, MODE_HIGH, InpExecutionScanBars, 1);
      if(shift < 0)
         return false;
      ctx.recentSwingLevel = iHigh(runtimeSymbol, InpExecutionTimeframe, shift);
      ctx.recentSwingLabel = "recent_exec_range_high";
     }
   return (ctx.recentSwingLevel > 0.0);
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

bool PendingSetupExpiredOrInvalidated(PendingExecutionContext &ctx)
  {
   if(!ctx.valid)
      return true;

   int barsFromSetup = BarsBetweenTimes(ctx.detectedTime, TimeCurrent(), InpExecutionTimeframe);
   if(InpSetupExpiryBars > 0 && barsFromSetup > InpSetupExpiryBars)
      return true;

   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   double currentPrice = (ctx.setup.direction < 0) ? ask : bid;
   double tolerance = PipsToPrice(InpMinLowerHighGapPips);

   if(ctx.setup.direction < 0 && currentPrice > ctx.setup.sweepPivot.price + tolerance)
      return true;
   if(ctx.setup.direction > 0 && currentPrice < ctx.setup.sweepPivot.price - tolerance)
      return true;

   return false;
  }

bool BuildExecutionTrigger(PendingExecutionContext &ctx, ExecutionTrigger &trigger)
  {
   trigger.fired = false;
   trigger.triggerLabel = "";
   trigger.entryPrice = 0.0;
   trigger.setupToEntryPips = 0.0;
   trigger.barsFromSetupToEntry = -1;
   trigger.referenceLevel = 0.0;

   if(!ctx.valid)
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
   double referencePrice = (ctx.setup.direction < 0) ? bid : ask;
   double setupToEntryPips = (ctx.setup.direction < 0)
                             ? (ctx.setupBaselineEntry - referencePrice) / GetPipSize()
                             : (referencePrice - ctx.setupBaselineEntry) / GetPipSize();

   if(InpExecutionTriggerMode == EXEC_RECLAIM_CLOSE_CONFIRM)
     {
      if(ctx.setup.direction < 0)
        {
         if(close1 < ctx.setup.reclaimLevel && close1 < open1)
           {
            trigger.fired = true;
            trigger.triggerLabel = "exec_reclaim_close_confirm";
            trigger.entryPrice = bid;
            trigger.referenceLevel = ctx.setup.reclaimLevel;
           }
        }
      else
        {
         if(close1 > ctx.setup.reclaimLevel && close1 > open1)
           {
            trigger.fired = true;
            trigger.triggerLabel = "exec_reclaim_close_confirm";
            trigger.entryPrice = ask;
            trigger.referenceLevel = ctx.setup.reclaimLevel;
           }
        }
     }
   else if(InpExecutionTriggerMode == EXEC_RETEST_FAILURE)
     {
      double tolerance = PipsToPrice(InpRetestTolerancePips);
      if(ctx.setup.direction < 0)
        {
         if(high1 >= ctx.setup.retestLevel - tolerance &&
            close1 < ctx.setup.reclaimLevel &&
            close1 < open1)
           {
            trigger.fired = true;
            trigger.triggerLabel = "exec_retest_failure";
            trigger.entryPrice = bid;
            trigger.referenceLevel = ctx.setup.retestLevel;
           }
        }
      else
        {
         if(low1 <= ctx.setup.retestLevel + tolerance &&
            close1 > ctx.setup.reclaimLevel &&
            close1 > open1)
           {
            trigger.fired = true;
            trigger.triggerLabel = "exec_retest_failure";
            trigger.entryPrice = ask;
            trigger.referenceLevel = ctx.setup.retestLevel;
           }
        }
     }
   else
     {
      if(!ResolveRecentExecutionSwingLevel(ctx))
         return false;

      double buffer = MathMax(PipsToPrice(InpMinBreakBufferPips),
                              PipsToPrice(ctx.setup.patternAtrPips * InpBreakBufferATR));
      if(ctx.setup.direction < 0)
        {
         if(close1 < ctx.recentSwingLevel - buffer && close1 < open1)
           {
            trigger.fired = true;
            trigger.triggerLabel = "exec_recent_swing_breakdown";
            trigger.entryPrice = bid;
            trigger.referenceLevel = ctx.recentSwingLevel;
           }
        }
      else
        {
         if(close1 > ctx.recentSwingLevel + buffer && close1 > open1)
           {
            trigger.fired = true;
            trigger.triggerLabel = "exec_recent_swing_breakdown";
            trigger.entryPrice = ask;
            trigger.referenceLevel = ctx.recentSwingLevel;
           }
        }
     }

   if(!trigger.fired)
      return false;

   trigger.setupToEntryPips = setupToEntryPips;
   trigger.barsFromSetupToEntry = barsFromSetup;
   return true;
  }

double SelectPartialTarget(const SweepFailureSetup &setup, double entry, string &label)
  {
   double ratio = (InpPartialTargetLevel == PARTIAL_TARGET_500) ? 0.500 : 0.382;
   label = PartialTargetLevelLabel(InpPartialTargetLevel);
   double target = 0.0;

   if(setup.direction < 0)
      target = setup.continuationLevel - (setup.structureHeight * ratio);
   else
      target = setup.continuationLevel + (setup.structureHeight * ratio);

   if((setup.direction < 0 && target < entry) || (setup.direction > 0 && target > entry))
      return target;

   double fallbackDistance = MathAbs(entry - setup.stopAnchor);
   if(fallbackDistance <= 0.0)
      return 0.0;
   label += "_fallback";
   if(setup.direction < 0)
      return entry - fallbackDistance * 0.75;
   return entry + fallbackDistance * 0.75;
  }

double SelectFinalTarget(const SweepFailureSetup &setup,
                         double entry,
                         double risk,
                         string &label)
  {
   label = FinalTargetModeLabel(InpFinalTargetMode);
   double target = 0.0;

   if(InpFinalTargetMode == FINAL_TARGET_PRIOR_SWING)
      target = setup.priorSwingTarget;
   else if(InpFinalTargetMode == FINAL_TARGET_FIXED_R)
      target = (setup.direction < 0) ? entry - risk * InpTargetRMultiple : entry + risk * InpTargetRMultiple;
   else
      target = (setup.direction < 0)
               ? setup.continuationLevel - (setup.structureHeight * 0.618)
               : setup.continuationLevel + (setup.structureHeight * 0.618);

   if((setup.direction < 0 && target < entry) || (setup.direction > 0 && target > entry))
      return target;

   label += "_fallback_r";
   if(setup.direction < 0)
      return entry - risk * InpTargetRMultiple;
   return entry + risk * InpTargetRMultiple;
  }

bool BuildEntryPlan(const SweepFailureSetup &setup,
                    const ExecutionTrigger &trigger,
                    EntryPlan &plan)
  {
   ResetEntryPlan(plan);
   if(!setup.valid || !trigger.fired)
      return false;

   double stopBuffer = MathMax(PipsToPrice(InpMinStopBufferPips),
                               PipsToPrice(setup.patternAtrPips * InpStopBufferATR));
   double entry = NormalizePrice(trigger.entryPrice);
   double stop = 0.0;
   if(setup.direction < 0)
      stop = NormalizePrice(setup.stopAnchor + stopBuffer);
   else
      stop = NormalizePrice(setup.stopAnchor - stopBuffer);

   if((setup.direction < 0 && stop <= entry) || (setup.direction > 0 && stop >= entry))
      return false;

   double risk = MathAbs(entry - stop);
   string partialLabel = "";
   string finalLabel = "";
   double partialTarget = NormalizePrice(SelectPartialTarget(setup, entry, partialLabel));
   double finalTarget = NormalizePrice(SelectFinalTarget(setup, entry, risk, finalLabel));
   bool partialValid = (setup.direction < 0) ? (partialTarget > 0.0 && partialTarget < entry)
                                             : (partialTarget > entry);
   bool finalValid = (setup.direction < 0) ? (finalTarget > 0.0 && finalTarget < entry)
                                           : (finalTarget > entry);
   if(!partialValid || !finalValid)
      return false;
   if((setup.direction < 0 && finalTarget >= partialTarget) || (setup.direction > 0 && finalTarget <= partialTarget))
     {
      finalLabel += "_fallback_r";
      finalTarget = NormalizePrice((setup.direction < 0) ? entry - risk * InpTargetRMultiple
                                                         : entry + risk * InpTargetRMultiple);
      if((setup.direction < 0 && finalTarget >= partialTarget) || (setup.direction > 0 && finalTarget <= partialTarget))
         return false;
     }

   plan.valid = true;
   plan.direction = setup.direction;
   plan.tier = setup.tier;
   plan.sideLabel = setup.sideLabel;
   plan.contextPhaseLabel = setup.contextPhaseLabel;
   plan.contextBucket = setup.contextBucket;
   plan.waveLabel = setup.waveLabel;
   plan.externalLevelTypeLabel = setup.externalLevelTypeLabel;
   plan.patternLabel = setup.patternLabel;
   plan.patternStateLabel = setup.patternStateLabel;
   plan.executionTriggerLabel = trigger.triggerLabel;
   plan.patternTimeframe = TimeframeLabel(InpPatternTimeframe);
   plan.executionTimeframe = TimeframeLabel(InpExecutionTimeframe);
   plan.partialTargetLabel = partialLabel;
   plan.finalTargetLabel = finalLabel;
   plan.volatilityBucket = setup.volatilityBucket;
   plan.referenceLevel = setup.referenceLevel;
   plan.continuationLevel = setup.continuationLevel;
   plan.structureHeightPips = setup.structureHeightPips;
   plan.patternAtrPips = setup.patternAtrPips;
   plan.invalidationLevel = NormalizePrice(setup.invalidationLevel);
   plan.setupBaselineEntry = pendingExecution.setupBaselineEntry;
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
   plan.reason = "external_sweep_failure_" + setup.tier + "_" + setup.sideLabel + "_" + trigger.triggerLabel;
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
                "tier",
                "context_phase",
                "context_bucket",
                "wave_label",
                "external_level_type",
                "pattern_label",
                "pattern_state",
                "execution_trigger",
                "pattern_tf",
                "execution_tf",
                "partial_target_label",
                "final_target_label",
                "reference_level",
                "continuation_level",
                "structure_height_pips",
                "pattern_atr_pips",
                "volatility_bucket",
                "setup_to_entry_pips",
                "bars_from_pattern_to_entry",
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

   FileSeek(telemetryHandle, 0, SEEK_END);
   FileWrite(telemetryHandle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             eventType,
             plan.sideLabel,
             (long)positionId,
             plan.tier,
             plan.contextPhaseLabel,
             plan.contextBucket,
             plan.waveLabel,
             plan.externalLevelTypeLabel,
             plan.patternLabel,
             plan.patternStateLabel,
             plan.executionTriggerLabel,
             plan.patternTimeframe,
             plan.executionTimeframe,
             plan.partialTargetLabel,
             plan.finalTargetLabel,
             plan.referenceLevel,
             plan.continuationLevel,
             plan.structureHeightPips,
             plan.patternAtrPips,
             plan.volatilityBucket,
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
   if(activePlan.direction < 0)
      return SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   return SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
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

   if(activePlan.usePartial && activePartialTaken && !activeBreakEvenMoved)
      MoveStopToBreakeven();

   bool partialReached = activePlan.direction > 0 ? (currentPrice >= activePlan.partialTarget)
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

   bool finalReached = activePlan.direction > 0 ? (currentPrice >= activePlan.target)
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
      bool acceptanceFailed = activePlan.direction > 0 ? (execClose < activePlan.invalidationLevel)
                                                       : (execClose > activePlan.invalidationLevel);
      if(acceptanceFailed)
        {
         pendingExitReason = activePlan.direction > 0 ? "acceptance_back_below_failed_low" : "acceptance_back_above_failed_high";
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

void StagePendingExecution(const SweepFailureSetup &setup)
  {
   ResetPendingExecution(pendingExecution);
   pendingExecution.valid = setup.valid;
   pendingExecution.setup = setup;
   pendingExecution.detectedTime = TimeCurrent();
   pendingExecution.setupBaselineEntry = (setup.direction < 0)
                                         ? SymbolInfoDouble(runtimeSymbol, SYMBOL_BID)
                                         : SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   if(pendingExecution.setupBaselineEntry <= 0.0)
      pendingExecution.setupBaselineEntry = iClose(runtimeSymbol, InpPatternTimeframe, 1);
   ResolveRecentExecutionSwingLevel(pendingExecution);
  }

bool SelectPreferredSetup(const SweepFailureSetup &shortSetup,
                          const SweepFailureSetup &longSetup,
                          SweepFailureSetup &selected)
  {
   ResetSweepFailureSetup(selected);
   if(shortSetup.valid && !longSetup.valid)
     {
      selected = shortSetup;
      return true;
     }
   if(longSetup.valid && !shortSetup.valid)
     {
      selected = longSetup;
      return true;
     }
   if(!shortSetup.valid && !longSetup.valid)
      return false;

   if(shortSetup.setupTime >= longSetup.setupTime)
      selected = shortSetup;
   else
      selected = longSetup;
   return true;
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
      ResetPendingExecution(pendingExecution);
      return true;
     }

   ResetEntryPlan(pendingPlan);
   return false;
  }

void ProcessNewPatternBar()
  {
   if(hasPendingPlan || CountManagedPositions() > 0)
      return;
   if(!PassGlobalGuards())
     {
      ResetPendingExecution(pendingExecution);
      return;
     }

   ContextPhaseContext ctx;
   if(!BuildContextPhase(ctx))
     {
      ResetPendingExecution(pendingExecution);
      return;
     }

   PivotPoint pivots[];
   PatternStructureContext structure;
   if(!BuildSweepFailurePattern(pivots, structure))
     {
      ResetPendingExecution(pendingExecution);
      return;
     }

   SweepFailureSetup shortSetup;
   SweepFailureSetup longSetup;
   SweepFailureSetup selected;
   DetectShortExternalSweepFailureSetup(ctx, structure, pivots, shortSetup);
   DetectLongExternalSweepFailureSetup(ctx, structure, pivots, longSetup);
   if(!SelectPreferredSetup(shortSetup, longSetup, selected))
     {
      ResetPendingExecution(pendingExecution);
      return;
     }

   StagePendingExecution(selected);
  }

void ProcessExecutionBar()
  {
   if(!pendingExecution.valid)
      return;
   if(hasPendingPlan || CountManagedPositions() > 0)
      return;
   if(!PassGlobalGuards())
      return;
   if(PendingSetupExpiredOrInvalidated(pendingExecution))
     {
      ResetPendingExecution(pendingExecution);
      return;
     }

   ExecutionTrigger trigger;
   if(!BuildExecutionTrigger(pendingExecution, trigger))
      return;

   EntryPlan plan;
   if(!BuildEntryPlan(pendingExecution.setup, trigger, plan))
      return;

   ExecuteEntry(plan);
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &,
                        const MqlTradeResult &)
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
         activePlannedRiskAmount = activePlan.plannedRiskAmount > 0.0
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

bool IsAllowedContextTimeframe(ENUM_TIMEFRAMES tf)
  {
   return (tf == PERIOD_M15 || tf == PERIOD_M30);
  }

bool IsAllowedPatternTimeframe(ENUM_TIMEFRAMES tf)
  {
   return (tf == PERIOD_M5 || tf == PERIOD_M10);
  }

bool IsAllowedExecutionTimeframe(ENUM_TIMEFRAMES tf)
  {
   return (tf == PERIOD_M3 || tf == PERIOD_M5);
  }

int OnInit()
  {
   runtimeSymbol = NormalizePresetString(InpSymbol);
   runtimeTelemetryFileName = NormalizePresetString(InpTelemetryFileName);
   ResetEntryPlan(pendingPlan);
   ResetEntryPlan(activePlan);
   ResetPendingExecution(pendingExecution);
   ResetTradeRuntimeState();

   if(!IsAllowedContextTimeframe(InpContextTimeframe) ||
      !IsAllowedPatternTimeframe(InpPatternTimeframe) ||
      !IsAllowedExecutionTimeframe(InpExecutionTimeframe))
      return INIT_PARAMETERS_INCORRECT;
   if(InpMagicNumber <= 0 || InpContextPivotSpan <= 0 || InpPatternPivotSpan <= 0 || InpExecutionPivotSpan <= 0 ||
      InpContextATRPeriod <= 0 || InpPatternATRPeriod <= 0 || InpExecutionATRPeriod <= 0 ||
      InpRiskPercent <= 0.0 || InpTargetRMultiple <= 0.0 ||
      InpContextHighZoneMin < 0.0 || InpContextHighZoneMin > 1.0 ||
      InpContextLowZoneMax < 0.0 || InpContextLowZoneMax > 1.0 ||
      InpHybridPartialFraction <= 0.0 || InpHybridPartialFraction >= 1.0)
      return INIT_PARAMETERS_INCORRECT;

   trade.SetExpertMagicNumber((ulong)InpMagicNumber);

   contextFastHandle = iMA(runtimeSymbol, InpContextTimeframe, InpContextFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   contextSlowHandle = iMA(runtimeSymbol, InpContextTimeframe, InpContextSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   contextAtrHandle = iATR(runtimeSymbol, InpContextTimeframe, InpContextATRPeriod);
   patternAtrHandle = iATR(runtimeSymbol, InpPatternTimeframe, InpPatternATRPeriod);
   executionAtrHandle = iATR(runtimeSymbol, InpExecutionTimeframe, InpExecutionATRPeriod);
   if(contextFastHandle == INVALID_HANDLE || contextSlowHandle == INVALID_HANDLE ||
      contextAtrHandle == INVALID_HANDLE || patternAtrHandle == INVALID_HANDLE ||
      executionAtrHandle == INVALID_HANDLE)
      return INIT_FAILED;

   if(InpEnableTelemetry)
      OpenTelemetryFile();

   return INIT_SUCCEEDED;
  }

void OnDeinit(const int)
  {
   if(contextFastHandle != INVALID_HANDLE)
      IndicatorRelease(contextFastHandle);
   if(contextSlowHandle != INVALID_HANDLE)
      IndicatorRelease(contextSlowHandle);
   if(contextAtrHandle != INVALID_HANDLE)
      IndicatorRelease(contextAtrHandle);
   if(patternAtrHandle != INVALID_HANDLE)
      IndicatorRelease(patternAtrHandle);
   if(executionAtrHandle != INVALID_HANDLE)
      IndicatorRelease(executionAtrHandle);
   CloseTelemetryFile();
  }

void OnTick()
  {
   UpdateOpenTradeExcursion();
   ManageOpenPositions();

   datetime patternBarTime = 0;
   if(IsNewBar(InpPatternTimeframe, lastPatternBarTime, patternBarTime))
      ProcessNewPatternBar();

   datetime executionBarTime = 0;
   if(IsNewBar(InpExecutionTimeframe, lastExecutionBarTime, executionBarTime))
      ProcessExecutionBar();
  }
