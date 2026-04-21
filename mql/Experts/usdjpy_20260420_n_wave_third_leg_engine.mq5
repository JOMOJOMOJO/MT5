//+------------------------------------------------------------------+
//| USDJPY Dow Fractal N-Wave Third-Leg Engine                      |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Standalone N-wave third-leg stop-run engine."

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
   CTX_DOWN_EXHAUSTION = 7,
   CTX_BULLISH_CORRECTION_CANDIDATE = 8,
   CTX_BEARISH_CORRECTION_CANDIDATE = 9
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

enum PatternState
  {
   PATTERN_STATE_NONE = 0,
   PATTERN_WAVE1_UP_CONFIRMED = 1,
   PATTERN_WAVE2_PULLBACK_IN_PROGRESS_BULL = 2,
   PATTERN_WAVE2_LOW_HELD = 3,
   PATTERN_WAVE2_INVALIDATION_LINE_DEFINED_BULL = 4,
   PATTERN_WAVE3_BREAK_READY_BULL = 5,
   PATTERN_WAVE1_DOWN_CONFIRMED = 6,
   PATTERN_WAVE2_PULLBACK_IN_PROGRESS_BEAR = 7,
   PATTERN_WAVE2_HIGH_HELD = 8,
   PATTERN_WAVE2_INVALIDATION_LINE_DEFINED_BEAR = 9,
   PATTERN_WAVE3_BREAK_READY_BEAR = 10
  };

enum ExecutionTriggerMode
  {
   EXEC_INVALIDATION_CLOSE_BREAK = 0,
   EXEC_RETEST_REJECT = 1,
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

struct WaveThirdLegSetup
  {
   bool      valid;
   int       direction;
   string    tier;
   string    sideLabel;
   string    contextPhaseLabel;
   string    contextBucket;
   string    waveLabel;
   string    waveSubtypeLabel;
   string    invalidationLineTypeLabel;
   string    patternLabel;
   string    patternStateLabel;
   string    volatilityBucket;
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
   WaveThirdLegSetup setup;
   double    setupBaselineEntry;
   datetime  detectedTime;
   bool      breakoutSeen;
   datetime  breakoutTime;
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
   string    waveSubtypeLabel;
   string    invalidationLineTypeLabel;
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
input double          InpWave1MinATRMultiple      = 0.18;
input double          InpTierAMinWave1Pips        = 3.0;
input double          InpTierBMinWave1Pips        = 1.5;
input double          InpMinPatternHeightPips     = 6.0;
input double          InpMinPatternHeightATR      = 0.35;
input double          InpInvalidationBufferPips   = 0.8;
input double          InpMinBreakBufferPips       = 0.6;
input double          InpBreakBufferATR           = 0.08;
input double          InpRetestTolerancePips      = 0.8;
input double          InpWave2FailureToleranceATR = 0.18;
input double          InpMinWave2FailureGapPips   = 1.0;
input double          InpTierAMaxCloseLocation    = 0.45;
input double          InpTierBMaxCloseLocation    = 0.60;
input EntryTierMode   InpTierMode                 = ENTRY_TIER_A_ONLY;
input TradeBiasMode   InpTradeBiasMode            = TRADE_BIAS_SHORT_ONLY;
input ExecutionTriggerMode InpExecutionTriggerMode = EXEC_INVALIDATION_CLOSE_BREAK;
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
input string          InpTelemetryFileName        = "mt5_company_usdjpy_20260420_n_wave_third_leg.csv";
input long            InpMagicNumber              = 202604201;

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
      case CTX_BULLISH_CORRECTION_CANDIDATE: return "ctx_bullish_correction_candidate";
      case CTX_BEARISH_CORRECTION_CANDIDATE: return "ctx_bearish_correction_candidate";
     default: return "ctx_unknown";
     }
  }

string PatternStateLabel(PatternState state)
  {
   switch(state)
     {
      case PATTERN_WAVE1_UP_CONFIRMED: return "wave1_up_confirmed";
      case PATTERN_WAVE2_PULLBACK_IN_PROGRESS_BULL:
      case PATTERN_WAVE2_PULLBACK_IN_PROGRESS_BEAR: return "wave2_pullback_in_progress";
      case PATTERN_WAVE2_LOW_HELD: return "wave2_low_held";
      case PATTERN_WAVE2_HIGH_HELD: return "wave2_high_held";
      case PATTERN_WAVE2_INVALIDATION_LINE_DEFINED_BULL:
      case PATTERN_WAVE2_INVALIDATION_LINE_DEFINED_BEAR: return "wave2_invalidation_line_defined";
      case PATTERN_WAVE3_BREAK_READY_BULL:
      case PATTERN_WAVE3_BREAK_READY_BEAR: return "wave3_break_ready";
      case PATTERN_WAVE1_DOWN_CONFIRMED: return "wave1_down_confirmed";
      default: return "none";
     }
  }

string ExecutionTriggerModeLabel(ExecutionTriggerMode mode)
  {
   switch(mode)
     {
      case EXEC_RETEST_REJECT: return "exec_retest_reject";
      case EXEC_RECENT_SWING_BREAKDOWN: return "exec_recent_swing_breakdown";
      default: return "exec_invalidation_close_break";
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
      case PERIOD_H1: return "h1";
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

void ResetWaveThirdLegSetup(WaveThirdLegSetup &setup)
  {
   setup.valid = false;
   setup.direction = 0;
   setup.tier = "";
   setup.sideLabel = "";
   setup.contextPhaseLabel = "";
   setup.contextBucket = "";
   setup.waveLabel = "";
   setup.waveSubtypeLabel = "";
   setup.invalidationLineTypeLabel = "";
   setup.patternLabel = "";
   setup.patternStateLabel = "";
   setup.volatilityBucket = "";
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
   plan.waveSubtypeLabel = "";
   plan.invalidationLineTypeLabel = "";
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
   ResetWaveThirdLegSetup(ctx.setup);
   ctx.setupBaselineEntry = 0.0;
   ctx.detectedTime = 0;
   ctx.breakoutSeen = false;
   ctx.breakoutTime = 0;
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
      if(rangePosition >= InpContextHighZoneMin &&
         retraceRatio >= 0.382 && retraceRatio <= 0.618 &&
         closePrice < emaFast)
         return CTX_BEARISH_CORRECTION_CANDIDATE;
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
      if(rangePosition <= InpContextLowZoneMax &&
         retraceRatio >= 0.382 && retraceRatio <= 0.618 &&
         closePrice > emaFast)
         return CTX_BULLISH_CORRECTION_CANDIDATE;
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
      case CTX_BEARISH_CORRECTION_CANDIDATE: return "ctx_bearish_correction_candidate";
      case CTX_RANGE_TOP: return "ctx_range_top";
      case CTX_RANGE_BOTTOM: return "ctx_range_bottom";
      case CTX_DOWN_IMPULSE: return "ctx_down_impulse";
      case CTX_DOWN_EXHAUSTION: return "ctx_down_exhaustion";
      case CTX_BULLISH_CORRECTION_CANDIDATE: return "ctx_bullish_correction_candidate";
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
   ctx.tierAShortEligible = (ctx.phase == CTX_UP_EXHAUSTION ||
                             ctx.phase == CTX_RANGE_TOP ||
                             ctx.phase == CTX_BEARISH_CORRECTION_CANDIDATE);
   ctx.tierALongEligible = (ctx.phase == CTX_DOWN_EXHAUSTION ||
                            ctx.phase == CTX_RANGE_BOTTOM ||
                            ctx.phase == CTX_BULLISH_CORRECTION_CANDIDATE);
   ctx.tierBShortEligible = (ctx.tierAShortEligible || ctx.phase == CTX_UP_IMPULSE);
   ctx.tierBLongEligible = (ctx.tierALongEligible || ctx.phase == CTX_DOWN_IMPULSE);
   ctx.valid = true;
   return true;
  }

bool BuildWaveStructure(PivotPoint &pivots[], PatternStructureContext &structure)
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
   structure.sweepFloor = MathMax(PipsToPrice(InpTierBMinWave1Pips),
                                  structure.patternAtr * InpWave1MinATRMultiple);
   structure.structureFloor = MathMax(PipsToPrice(InpMinPatternHeightPips),
                                      structure.patternAtr * InpMinPatternHeightATR);
   structure.reclaimBuffer = PipsToPrice(InpInvalidationBufferPips);
   structure.breakBuffer = MathMax(PipsToPrice(InpMinBreakBufferPips),
                                   structure.executionAtr * InpBreakBufferATR);
   structure.retestTolerance = PipsToPrice(InpRetestTolerancePips);
   structure.failureGap = MathMax(PipsToPrice(InpMinWave2FailureGapPips),
                                  structure.patternAtr * InpWave2FailureToleranceATR);
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

PivotPoint PivotFromLevel(double price, datetime pivotTime, bool isHigh)
  {
   PivotPoint pivot;
   pivot.valid = (price > 0.0 && pivotTime > 0);
   pivot.isHigh = isHigh;
   pivot.shift = 0;
   pivot.price = price;
   pivot.time = pivotTime;
   return pivot;
  }

string DetectBearishWaveSubtype(const PatternStructureContext &structure,
                                const PivotPoint &wave1Low,
                                const PivotPoint &wave2High,
                                const PivotPoint &internalLow,
                                const PivotPoint &failureHigh)
  {
   if(MathAbs(wave2High.price - failureHigh.price) <= structure.failureGap)
      return "double_top_wave2";
   if(internalLow.price > wave1Low.price + structure.breakBuffer &&
      failureHigh.price < wave2High.price - structure.failureGap)
      return "hs_wave2";
   return "lower_high_wave2";
  }

string DetectBullishWaveSubtype(const PatternStructureContext &structure,
                                const PivotPoint &wave1High,
                                const PivotPoint &wave2Low,
                                const PivotPoint &internalHigh,
                                const PivotPoint &failureLow)
  {
   if(MathAbs(wave2Low.price - failureLow.price) <= structure.failureGap)
      return "double_bottom_wave2";
   if(internalHigh.price < wave1High.price - structure.breakBuffer &&
      failureLow.price > wave2Low.price + structure.failureGap)
      return "inverse_hs_wave2";
   return "higher_low_wave2";
  }

void SelectBearishInvalidationLine(const PatternStructureContext &structure,
                                   const PivotPoint &wave1Low,
                                   const PivotPoint &internalLow,
                                   const PivotPoint &wave2High,
                                   const PivotPoint &failureHigh,
                                   double &linePrice,
                                   datetime &lineTime,
                                   string &lineType)
  {
   if(MathAbs(internalLow.price - wave1Low.price) <= structure.breakBuffer * 1.5)
     {
      linePrice = MathMin(wave1Low.price, internalLow.price);
      lineTime = (wave1Low.time >= internalLow.time) ? wave1Low.time : internalLow.time;
      lineType = "wave1_low";
      return;
     }

   linePrice = internalLow.price;
   lineTime = internalLow.time;
   if(failureHigh.price < wave2High.price - structure.failureGap)
      lineType = "neckline_low";
   else
      lineType = "recent_swing_low";
  }

void SelectBullishInvalidationLine(const PatternStructureContext &structure,
                                   const PivotPoint &wave1High,
                                   const PivotPoint &internalHigh,
                                   const PivotPoint &wave2Low,
                                   const PivotPoint &failureLow,
                                   double &linePrice,
                                   datetime &lineTime,
                                   string &lineType)
  {
   if(MathAbs(internalHigh.price - wave1High.price) <= structure.breakBuffer * 1.5)
     {
      linePrice = MathMax(wave1High.price, internalHigh.price);
      lineTime = (wave1High.time >= internalHigh.time) ? wave1High.time : internalHigh.time;
      lineType = "wave1_high";
      return;
     }

   linePrice = internalHigh.price;
   lineTime = internalHigh.time;
   if(failureLow.price > wave2Low.price + structure.failureGap)
      lineType = "neckline_high";
   else
      lineType = "recent_swing_high";
  }

string BuildBearishPatternStateLabel(const PatternStructureContext &structure, double linePrice)
  {
   if(structure.currentClose <= linePrice - structure.breakBuffer)
      return PatternStateLabel(PATTERN_WAVE3_BREAK_READY_BEAR);
   return PatternStateLabel(PATTERN_WAVE2_INVALIDATION_LINE_DEFINED_BEAR);
  }

string BuildBullishPatternStateLabel(const PatternStructureContext &structure, double linePrice)
  {
   if(structure.currentClose >= linePrice + structure.breakBuffer)
      return PatternStateLabel(PATTERN_WAVE3_BREAK_READY_BULL);
   return PatternStateLabel(PATTERN_WAVE2_INVALIDATION_LINE_DEFINED_BULL);
  }

bool FillBearishWave2CompletionSetup(const ContextPhaseContext &ctx,
                                     const PatternStructureContext &structure,
                                     const PivotPoint &wave1High,
                                     const PivotPoint &wave1Low,
                                     const PivotPoint &wave2High,
                                     const PivotPoint &internalLow,
                                     const PivotPoint &failureHigh,
                                     const string tier,
                                     WaveThirdLegSetup &setup)
  {
   ResetWaveThirdLegSetup(setup);

   double tierWave1Floor = (tier == "tier_a") ? PipsToPrice(InpTierAMinWave1Pips) : PipsToPrice(InpTierBMinWave1Pips);
   double wave1Height = wave1High.price - wave1Low.price;
   if(wave1Height < structure.sweepFloor || wave1Height < tierWave1Floor || wave1Height < structure.structureFloor)
      return false;

   if(!(wave1High.time < wave1Low.time && wave1Low.time < wave2High.time && wave2High.time < internalLow.time && internalLow.time < failureHigh.time))
      return false;
   if(wave2High.price <= wave1Low.price + structure.reclaimBuffer)
      return false;
   if(internalLow.price < wave1Low.price - structure.breakBuffer)
      return false;
   if(failureHigh.price > wave1High.price + structure.failureGap)
      return false;
   if(failureHigh.price > wave2High.price + structure.breakBuffer)
      return false;
   if(structure.currentClose > wave2High.price + structure.reclaimBuffer)
      return false;

   double maxCloseLocation = (tier == "tier_a") ? InpTierAMaxCloseLocation : InpTierBMaxCloseLocation;
   if(structure.currentCloseLocation > maxCloseLocation)
      return false;

   double invalidationLine = 0.0;
   datetime invalidationTime = 0;
   string lineType = "";
   SelectBearishInvalidationLine(structure,
                                 wave1Low,
                                 internalLow,
                                 wave2High,
                                 failureHigh,
                                 invalidationLine,
                                 invalidationTime,
                                 lineType);
   if(invalidationLine <= 0.0 || lineType == "")
      return false;

   setup.valid = true;
   setup.direction = -1;
   setup.tier = tier;
   setup.sideLabel = "short";
   setup.contextPhaseLabel = ctx.phaseLabel;
   setup.contextBucket = ctx.contextBucket;
   setup.waveLabel = ctx.waveLabel;
   setup.waveSubtypeLabel = DetectBearishWaveSubtype(structure, wave1Low, wave2High, internalLow, failureHigh);
   setup.invalidationLineTypeLabel = lineType;
   setup.patternLabel = "n_wave_third_leg";
   setup.patternStateLabel = BuildBearishPatternStateLabel(structure, invalidationLine);
   setup.volatilityBucket = structure.volatilityBucket;
   setup.referencePivot = PivotFromLevel(invalidationLine, invalidationTime, false);
   setup.sweepPivot = wave2High;
   setup.continuationPivot = internalLow;
   setup.failurePivot = failureHigh;
   setup.referenceLevel = invalidationLine;
   setup.reclaimLevel = invalidationLine - structure.breakBuffer;
   setup.retestLevel = invalidationLine;
   setup.continuationLevel = invalidationLine;
   setup.stopAnchor = MathMax(wave2High.price, failureHigh.price);
   setup.invalidationLevel = invalidationLine + PipsToPrice(InpAcceptanceExitBufferPips);
   setup.priorSwingTarget = ctx.priorSwingLow;
   setup.structureHeight = wave1Height;
   setup.structureHeightPips = wave1Height / GetPipSize();
   setup.patternAtrPips = structure.patternAtrPips;
   setup.currentCloseLocation = structure.currentCloseLocation;
   setup.setupTime = iTime(runtimeSymbol, InpPatternTimeframe, 1);
   return true;
  }

bool FillBullishWave2CompletionSetup(const ContextPhaseContext &ctx,
                                     const PatternStructureContext &structure,
                                     const PivotPoint &wave1Low,
                                     const PivotPoint &wave1High,
                                     const PivotPoint &wave2Low,
                                     const PivotPoint &internalHigh,
                                     const PivotPoint &failureLow,
                                     const string tier,
                                     WaveThirdLegSetup &setup)
  {
   ResetWaveThirdLegSetup(setup);

   double tierWave1Floor = (tier == "tier_a") ? PipsToPrice(InpTierAMinWave1Pips) : PipsToPrice(InpTierBMinWave1Pips);
   double wave1Height = wave1High.price - wave1Low.price;
   if(wave1Height < structure.sweepFloor || wave1Height < tierWave1Floor || wave1Height < structure.structureFloor)
      return false;

   if(!(wave1Low.time < wave1High.time && wave1High.time < wave2Low.time && wave2Low.time < internalHigh.time && internalHigh.time < failureLow.time))
      return false;
   if(wave2Low.price >= wave1High.price - structure.reclaimBuffer)
      return false;
   if(internalHigh.price > wave1High.price + structure.breakBuffer)
      return false;
   if(failureLow.price < wave1Low.price - structure.failureGap)
      return false;
   if(failureLow.price < wave2Low.price - structure.breakBuffer)
      return false;
   if(structure.currentClose < wave2Low.price - structure.reclaimBuffer)
      return false;

   double minCloseLocation = 1.0 - ((tier == "tier_a") ? InpTierAMaxCloseLocation : InpTierBMaxCloseLocation);
   if(structure.currentCloseLocation < minCloseLocation)
      return false;

   double invalidationLine = 0.0;
   datetime invalidationTime = 0;
   string lineType = "";
   SelectBullishInvalidationLine(structure,
                                 wave1High,
                                 internalHigh,
                                 wave2Low,
                                 failureLow,
                                 invalidationLine,
                                 invalidationTime,
                                 lineType);
   if(invalidationLine <= 0.0 || lineType == "")
      return false;

   setup.valid = true;
   setup.direction = 1;
   setup.tier = tier;
   setup.sideLabel = "long";
   setup.contextPhaseLabel = ctx.phaseLabel;
   setup.contextBucket = ctx.contextBucket;
   setup.waveLabel = ctx.waveLabel;
   setup.waveSubtypeLabel = DetectBullishWaveSubtype(structure, wave1High, wave2Low, internalHigh, failureLow);
   setup.invalidationLineTypeLabel = lineType;
   setup.patternLabel = "n_wave_third_leg";
   setup.patternStateLabel = BuildBullishPatternStateLabel(structure, invalidationLine);
   setup.volatilityBucket = structure.volatilityBucket;
   setup.referencePivot = PivotFromLevel(invalidationLine, invalidationTime, true);
   setup.sweepPivot = wave2Low;
   setup.continuationPivot = internalHigh;
   setup.failurePivot = failureLow;
   setup.referenceLevel = invalidationLine;
   setup.reclaimLevel = invalidationLine + structure.breakBuffer;
   setup.retestLevel = invalidationLine;
   setup.continuationLevel = invalidationLine;
   setup.stopAnchor = MathMin(wave2Low.price, failureLow.price);
   setup.invalidationLevel = invalidationLine - PipsToPrice(InpAcceptanceExitBufferPips);
   setup.priorSwingTarget = ctx.priorSwingHigh;
   setup.structureHeight = wave1Height;
   setup.structureHeightPips = wave1Height / GetPipSize();
   setup.patternAtrPips = structure.patternAtrPips;
   setup.currentCloseLocation = structure.currentCloseLocation;
   setup.setupTime = iTime(runtimeSymbol, InpPatternTimeframe, 1);
   return true;
  }

bool DetectBearishWave2CompletionSetup(const ContextPhaseContext &ctx,
                                       const PatternStructureContext &structure,
                                       const PivotPoint &pivots[],
                                       WaveThirdLegSetup &setup)
  {
   ResetWaveThirdLegSetup(setup);
   if(!ShortBiasAllowed() || !ctx.valid || !structure.valid)
      return false;

   string tier = "";
   if(ctx.tierAShortEligible)
      tier = "tier_a";
   else if(InpTierMode == ENTRY_TIER_A_AND_B && ctx.tierBShortEligible)
      tier = "tier_b";
   else
      return false;

   int count = ArraySize(pivots);
   for(int i = count - 1; i >= 4; --i)
     {
      PivotPoint p0 = pivots[i - 4];
      PivotPoint p1 = pivots[i - 3];
      PivotPoint p2 = pivots[i - 2];
      PivotPoint p3 = pivots[i - 1];
      PivotPoint p4 = pivots[i];

      if(!(p0.isHigh && !p1.isHigh && p2.isHigh && !p3.isHigh && p4.isHigh))
         continue;
      if(!(SpacingOk(p0, p1) && SpacingOk(p1, p2) && SpacingOk(p2, p3) && SpacingOk(p3, p4)))
         continue;

      if(FillBearishWave2CompletionSetup(ctx, structure, p0, p1, p2, p3, p4, tier, setup))
         return true;
     }

   return false;
  }

bool DetectBullishWave2CompletionSetup(const ContextPhaseContext &ctx,
                                       const PatternStructureContext &structure,
                                       const PivotPoint &pivots[],
                                       WaveThirdLegSetup &setup)
  {
   ResetWaveThirdLegSetup(setup);
   if(!LongBiasAllowed() || !ctx.valid || !structure.valid)
      return false;

   string tier = "";
   if(ctx.tierALongEligible)
      tier = "tier_a";
   else if(InpTierMode == ENTRY_TIER_A_AND_B && ctx.tierBLongEligible)
      tier = "tier_b";
   else
      return false;

   int count = ArraySize(pivots);
   for(int i = count - 1; i >= 4; --i)
     {
      PivotPoint p0 = pivots[i - 4];
      PivotPoint p1 = pivots[i - 3];
      PivotPoint p2 = pivots[i - 2];
      PivotPoint p3 = pivots[i - 1];
      PivotPoint p4 = pivots[i];

      if(!(!p0.isHigh && p1.isHigh && !p2.isHigh && p3.isHigh && !p4.isHigh))
         continue;
      if(!(SpacingOk(p0, p1) && SpacingOk(p1, p2) && SpacingOk(p2, p3) && SpacingOk(p3, p4)))
         continue;

      if(FillBullishWave2CompletionSetup(ctx, structure, p0, p1, p2, p3, p4, tier, setup))
         return true;
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
   double tolerance = PipsToPrice(InpMinWave2FailureGapPips);

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

   if(InpExecutionTriggerMode == EXEC_INVALIDATION_CLOSE_BREAK)
     {
      if(ctx.setup.direction < 0)
        {
         if(close1 < ctx.setup.reclaimLevel && close1 < open1)
           {
            trigger.fired = true;
            trigger.triggerLabel = "exec_invalidation_close_break";
            trigger.entryPrice = bid;
            trigger.referenceLevel = ctx.setup.reclaimLevel;
           }
        }
      else
        {
         if(close1 > ctx.setup.reclaimLevel && close1 > open1)
           {
            trigger.fired = true;
            trigger.triggerLabel = "exec_invalidation_close_break";
            trigger.entryPrice = ask;
            trigger.referenceLevel = ctx.setup.reclaimLevel;
           }
        }
     }
   else if(InpExecutionTriggerMode == EXEC_RETEST_REJECT)
     {
      if(!ctx.breakoutSeen)
        {
         if((ctx.setup.direction < 0 && close1 < ctx.setup.reclaimLevel && close1 < open1) ||
            (ctx.setup.direction > 0 && close1 > ctx.setup.reclaimLevel && close1 > open1))
           {
            ctx.breakoutSeen = true;
            ctx.breakoutTime = iTime(runtimeSymbol, InpExecutionTimeframe, 1);
           }
         return false;
        }

      double tolerance = PipsToPrice(InpRetestTolerancePips);
      if(ctx.setup.direction < 0)
        {
         if(high1 >= ctx.setup.referenceLevel - tolerance &&
            close1 < ctx.setup.reclaimLevel &&
            close1 < open1)
           {
            trigger.fired = true;
            trigger.triggerLabel = "exec_retest_reject";
            trigger.entryPrice = bid;
            trigger.referenceLevel = ctx.setup.referenceLevel;
           }
        }
      else
        {
         if(low1 <= ctx.setup.referenceLevel + tolerance &&
            close1 > ctx.setup.reclaimLevel &&
            close1 > open1)
           {
            trigger.fired = true;
            trigger.triggerLabel = "exec_retest_hold";
            trigger.entryPrice = ask;
            trigger.referenceLevel = ctx.setup.referenceLevel;
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
            trigger.triggerLabel = "exec_recent_swing_breakout";
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

double SelectPartialTarget(const WaveThirdLegSetup &setup, double entry, string &label)
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

double SelectFinalTarget(const WaveThirdLegSetup &setup,
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

bool BuildEntryPlan(const WaveThirdLegSetup &setup,
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
   plan.waveSubtypeLabel = setup.waveSubtypeLabel;
   plan.invalidationLineTypeLabel = setup.invalidationLineTypeLabel;
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
   plan.reason = "nwave_third_leg_" + setup.tier + "_" + setup.sideLabel + "_" + trigger.triggerLabel;
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
                "wave_subtype",
                "invalidation_line_type",
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
             plan.waveSubtypeLabel,
             plan.invalidationLineTypeLabel,
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
         pendingExitReason = activePlan.direction > 0 ? "acceptance_back_below_invalidation_line" : "acceptance_back_above_invalidation_line";
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

void StagePendingExecution(const WaveThirdLegSetup &setup)
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

bool SelectPreferredSetup(const WaveThirdLegSetup &shortSetup,
                          const WaveThirdLegSetup &longSetup,
                          WaveThirdLegSetup &selected)
  {
   ResetWaveThirdLegSetup(selected);
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
   if(!BuildWaveStructure(pivots, structure))
     {
      ResetPendingExecution(pendingExecution);
      return;
     }

   WaveThirdLegSetup shortSetup;
   WaveThirdLegSetup longSetup;
   WaveThirdLegSetup selected;
   DetectBearishWave2CompletionSetup(ctx, structure, pivots, shortSetup);
   DetectBullishWave2CompletionSetup(ctx, structure, pivots, longSetup);
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
   return (tf == PERIOD_M15 || tf == PERIOD_M30 || tf == PERIOD_H1);
  }

bool IsAllowedPatternTimeframe(ENUM_TIMEFRAMES tf)
  {
   return (tf == PERIOD_M5 || tf == PERIOD_M10 || tf == PERIOD_M15);
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
      InpWave1MinATRMultiple <= 0.0 || InpTierAMinWave1Pips <= 0.0 || InpTierBMinWave1Pips <= 0.0 ||
      InpInvalidationBufferPips <= 0.0 || InpWave2FailureToleranceATR <= 0.0 || InpMinWave2FailureGapPips <= 0.0 ||
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
