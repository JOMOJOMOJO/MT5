//+------------------------------------------------------------------+
//| USDJPY Dow Fractal Head-And-Shoulders Engine                     |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Standalone Dow/fractal head-and-shoulders reversal engine scaffold."

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

enum ExecutionTriggerMode
  {
   EXEC_NECK_CLOSE_CONFIRM = 0,
   EXEC_NECK_RETEST_FAILURE = 1,
   EXEC_RECENT_SWING_BREAK = 2
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
   bool       valid;
   ContextPhase phase;
   string     phaseLabel;
   string     trendLabel;
   string     waveLabel;
   string     contextBucket;
   PivotPoint latestHigh;
   PivotPoint previousHigh;
   PivotPoint latestLow;
   PivotPoint previousLow;
   double     emaFast;
   double     emaSlow;
   double     atr;
   double     rangeHigh;
   double     rangeLow;
   double     rangePosition;
   double     activeWaveHigh;
   double     activeWaveLow;
   double     activeWaveClose;
   double     activeWaveRetracement;
   double     priorSwingHigh;
   double     priorSwingLow;
   bool       tierAShortEligible;
   bool       tierALongEligible;
   bool       tierBShortEligible;
   bool       tierBLongEligible;
  };

struct PatternStructureContext
  {
   bool     valid;
   double   patternAtr;
   double   executionAtr;
   double   tolerance;
   double   headClearance;
   double   neckDepthFloor;
   double   breakBuffer;
   double   currentOpen;
   double   currentHigh;
   double   currentLow;
   double   currentClose;
   double   currentCloseLocation;
   double   patternAtrPips;
   double   executionAtrPips;
   string   volatilityBucket;
  };

struct ReversalSetup
  {
   bool      valid;
   int       direction;
   string    tier;
   string    sideLabel;
   string    contextPhaseLabel;
   string    contextBucket;
   string    waveLabel;
   string    patternLabel;
   string    patternStateLabel;
   string    volatilityBucket;
   PivotPoint leftShoulder;
   PivotPoint neck1;
   PivotPoint head;
   PivotPoint neck2;
   PivotPoint rightShoulder;
   double    neckline;
   double    breakoutLevel;
   double    retestLevel;
   double    stopAnchor;
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
   ReversalSetup setup;
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
   string    patternLabel;
   string    patternStateLabel;
   string    executionTriggerLabel;
   string    patternTimeframe;
   string    executionTimeframe;
   string    partialTargetLabel;
   string    finalTargetLabel;
   string    volatilityBucket;
   double    neckline;
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
input ENUM_TIMEFRAMES InpContextTimeframe         = PERIOD_H1;
input ENUM_TIMEFRAMES InpPatternTimeframe         = PERIOD_M15;
input ENUM_TIMEFRAMES InpExecutionTimeframe       = PERIOD_M3;
input int             InpContextPivotSpan         = 2;
input int             InpPatternPivotSpan         = 2;
input int             InpExecutionPivotSpan       = 1;
input int             InpContextScanBars          = 240;
input int             InpPatternScanBars          = 200;
input int             InpExecutionScanBars        = 80;
input int             InpContextRangeBars         = 48;
input int             InpContextFastEMAPeriod     = 20;
input int             InpContextSlowEMAPeriod     = 50;
input int             InpContextATRPeriod         = 14;
input int             InpPatternATRPeriod         = 14;
input int             InpExecutionATRPeriod       = 14;
input double          InpContextHighZoneMin       = 0.70;
input double          InpContextLowZoneMax        = 0.30;
input double          InpShoulderToleranceATR     = 0.30;
input double          InpTierBShoulderMultiplier  = 1.40;
input double          InpHeadClearanceATR         = 0.10;
input double          InpMinShoulderTolerancePips = 2.0;
input double          InpMinHeadClearancePips     = 1.0;
input double          InpMinPatternHeightPips     = 8.0;
input double          InpMinPatternHeightATR      = 0.45;
input double          InpBreakBufferATR           = 0.08;
input double          InpMinBreakBufferPips       = 0.6;
input double          InpRetestTolerancePips      = 0.8;
input double          InpMinPatternCloseLocation  = 0.35;
input EntryTierMode   InpTierMode                 = ENTRY_TIER_A_ONLY;
input TradeBiasMode   InpTradeBiasMode            = TRADE_BIAS_SHORT_ONLY;
input ExecutionTriggerMode InpExecutionTriggerMode = EXEC_NECK_RETEST_FAILURE;
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
input string          InpTelemetryFileName        = "mt5_company_usdjpy_20260414_dow_fractal_head_shoulders.csv";
input long            InpMagicNumber              = 202604142;

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

string ExecutionTriggerModeLabel(ExecutionTriggerMode mode)
  {
   switch(mode)
     {
      case EXEC_NECK_RETEST_FAILURE: return "exec_neck_retest_failure";
      case EXEC_RECENT_SWING_BREAK: return "exec_recent_swing_break";
      default: return "exec_neck_close_confirm";
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

void ResetReversalSetup(ReversalSetup &setup)
  {
   setup.valid = false;
   setup.direction = 0;
   setup.tier = "";
   setup.sideLabel = "";
   setup.contextPhaseLabel = "";
   setup.contextBucket = "";
   setup.waveLabel = "";
   setup.patternLabel = "";
   setup.patternStateLabel = "";
   setup.volatilityBucket = "";
   ResetPivot(setup.leftShoulder);
   ResetPivot(setup.neck1);
   ResetPivot(setup.head);
   ResetPivot(setup.neck2);
   ResetPivot(setup.rightShoulder);
   setup.neckline = 0.0;
   setup.breakoutLevel = 0.0;
   setup.retestLevel = 0.0;
   setup.stopAnchor = 0.0;
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
   plan.patternLabel = "";
   plan.patternStateLabel = "";
   plan.executionTriggerLabel = "";
   plan.patternTimeframe = "";
   plan.executionTimeframe = "";
   plan.partialTargetLabel = "";
   plan.finalTargetLabel = "";
   plan.volatilityBucket = "";
   plan.neckline = 0.0;
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
   ResetReversalSetup(ctx.setup);
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

bool BuildPatternStructure(PivotPoint &pivots[], PatternStructureContext &structure)
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

   structure.patternAtrPips = structure.patternAtr / GetPipSize();
   structure.executionAtrPips = structure.executionAtr / GetPipSize();
   structure.tolerance = MathMax(PipsToPrice(InpMinShoulderTolerancePips),
                                 structure.patternAtr * InpShoulderToleranceATR);
   structure.headClearance = MathMax(PipsToPrice(InpMinHeadClearancePips),
                                     structure.patternAtr * InpHeadClearanceATR);
   structure.neckDepthFloor = MathMax(PipsToPrice(InpMinPatternHeightPips),
                                      structure.patternAtr * InpMinPatternHeightATR);
   structure.breakBuffer = MathMax(PipsToPrice(InpMinBreakBufferPips),
                                   structure.executionAtr * InpBreakBufferATR);
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

bool FillShortSetup(const ContextPhaseContext &ctx,
                    const PatternStructureContext &structure,
                    const PivotPoint &ls,
                    const PivotPoint &n1,
                    const PivotPoint &head,
                    const PivotPoint &n2,
                    const PivotPoint &rs,
                    const string tier,
                    ReversalSetup &setup)
  {
   ResetReversalSetup(setup);

   double neckline = (n1.price + n2.price) / 2.0;
   double structureHeight = head.price - neckline;
   if(structureHeight < structure.neckDepthFloor)
      return false;

   double shoulderTolerance = structure.tolerance;
   if(tier == "tier_b")
      shoulderTolerance *= InpTierBShoulderMultiplier;

   if(MathAbs(ls.price - rs.price) > shoulderTolerance)
      return false;
   if(head.price < MathMax(ls.price, rs.price) + (tier == "tier_a" ? structure.headClearance : structure.headClearance * 0.5))
      return false;
   if(rs.price > head.price - structure.headClearance * 0.25)
      return false;
   if(structure.currentCloseLocation < InpMinPatternCloseLocation)
      return false;
   if(structure.currentClose > rs.price + shoulderTolerance * 0.5)
      return false;

   setup.valid = true;
   setup.direction = -1;
   setup.tier = tier;
   setup.sideLabel = "short";
   setup.contextPhaseLabel = ctx.phaseLabel;
   setup.contextBucket = ctx.contextBucket;
   setup.waveLabel = ctx.waveLabel;
   setup.patternLabel = "triple_top_head_shoulders";
   setup.patternStateLabel = (structure.currentClose <= neckline - structure.breakBuffer) ? "pattern_neck_broken"
                            : (structure.currentClose <= neckline + structure.breakBuffer) ? "pattern_break_ready"
                            : "pattern_formed";
   setup.volatilityBucket = structure.volatilityBucket;
   setup.leftShoulder = ls;
   setup.neck1 = n1;
   setup.head = head;
   setup.neck2 = n2;
   setup.rightShoulder = rs;
   setup.neckline = neckline;
   setup.breakoutLevel = neckline - structure.breakBuffer;
   setup.retestLevel = neckline + PipsToPrice(InpRetestTolerancePips);
   setup.stopAnchor = MathMax(head.price, rs.price);
   setup.priorSwingTarget = ctx.priorSwingLow;
   setup.structureHeight = structureHeight;
   setup.structureHeightPips = structureHeight / GetPipSize();
   setup.patternAtrPips = structure.patternAtrPips;
   setup.currentCloseLocation = structure.currentCloseLocation;
   setup.setupTime = iTime(runtimeSymbol, InpPatternTimeframe, 1);
   return true;
  }

bool FillLongSetup(const ContextPhaseContext &ctx,
                   const PatternStructureContext &structure,
                   const PivotPoint &ls,
                   const PivotPoint &n1,
                   const PivotPoint &head,
                   const PivotPoint &n2,
                   const PivotPoint &rs,
                   const string tier,
                   ReversalSetup &setup)
  {
   ResetReversalSetup(setup);

   double neckline = (n1.price + n2.price) / 2.0;
   double structureHeight = neckline - head.price;
   if(structureHeight < structure.neckDepthFloor)
      return false;

   double shoulderTolerance = structure.tolerance;
   if(tier == "tier_b")
      shoulderTolerance *= InpTierBShoulderMultiplier;

   if(MathAbs(ls.price - rs.price) > shoulderTolerance)
      return false;
   if(head.price > MathMin(ls.price, rs.price) - (tier == "tier_a" ? structure.headClearance : structure.headClearance * 0.5))
      return false;
   if(rs.price < head.price + structure.headClearance * 0.25)
      return false;
   if((1.0 - structure.currentCloseLocation) < InpMinPatternCloseLocation)
      return false;
   if(structure.currentClose < rs.price - shoulderTolerance * 0.5)
      return false;

   setup.valid = true;
   setup.direction = 1;
   setup.tier = tier;
   setup.sideLabel = "long";
   setup.contextPhaseLabel = ctx.phaseLabel;
   setup.contextBucket = ctx.contextBucket;
   setup.waveLabel = ctx.waveLabel;
   setup.patternLabel = "inverse_triple_top_head_shoulders";
   setup.patternStateLabel = (structure.currentClose >= neckline + structure.breakBuffer) ? "pattern_neck_broken"
                            : (structure.currentClose >= neckline - structure.breakBuffer) ? "pattern_break_ready"
                            : "pattern_formed";
   setup.volatilityBucket = structure.volatilityBucket;
   setup.leftShoulder = ls;
   setup.neck1 = n1;
   setup.head = head;
   setup.neck2 = n2;
   setup.rightShoulder = rs;
   setup.neckline = neckline;
   setup.breakoutLevel = neckline + structure.breakBuffer;
   setup.retestLevel = neckline - PipsToPrice(InpRetestTolerancePips);
   setup.stopAnchor = MathMin(head.price, rs.price);
   setup.priorSwingTarget = ctx.priorSwingHigh;
   setup.structureHeight = structureHeight;
   setup.structureHeightPips = structureHeight / GetPipSize();
   setup.patternAtrPips = structure.patternAtrPips;
   setup.currentCloseLocation = structure.currentCloseLocation;
   setup.setupTime = iTime(runtimeSymbol, InpPatternTimeframe, 1);
   return true;
  }

bool DetectTripleTopSetup(const ContextPhaseContext &ctx,
                          const PatternStructureContext &structure,
                          const PivotPoint &pivots[],
                          ReversalSetup &setup)
  {
   ResetReversalSetup(setup);
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
      if(p4.time <= p2.time || p2.time <= p0.time)
         continue;

      if(FillShortSetup(ctx, structure, p0, p1, p2, p3, p4, tier, setup))
         return true;
     }

   return false;
  }

bool DetectInverseTripleTopSetup(const ContextPhaseContext &ctx,
                                 const PatternStructureContext &structure,
                                 const PivotPoint &pivots[],
                                 ReversalSetup &setup)
  {
   ResetReversalSetup(setup);
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
      if(p4.time <= p2.time || p2.time <= p0.time)
         continue;

      if(FillLongSetup(ctx, structure, p0, p1, p2, p3, p4, tier, setup))
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
         if(pivots[i].time < ctx.setup.rightShoulder.time)
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
   double tolerance = PipsToPrice(InpMinHeadClearancePips);

   if(ctx.setup.direction < 0 && currentPrice > ctx.setup.head.price + tolerance)
      return true;
   if(ctx.setup.direction > 0 && currentPrice < ctx.setup.head.price - tolerance)
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

   if(InpExecutionTriggerMode == EXEC_NECK_CLOSE_CONFIRM)
     {
      if(ctx.setup.direction < 0)
        {
         if(close1 < ctx.setup.breakoutLevel && close1 < open1)
           {
            trigger.fired = true;
            trigger.triggerLabel = "exec_neck_close_confirm";
            trigger.entryPrice = bid;
            trigger.referenceLevel = ctx.setup.breakoutLevel;
           }
        }
      else
        {
         if(close1 > ctx.setup.breakoutLevel && close1 > open1)
           {
            trigger.fired = true;
            trigger.triggerLabel = "exec_neck_close_confirm";
            trigger.entryPrice = ask;
            trigger.referenceLevel = ctx.setup.breakoutLevel;
           }
        }
     }
   else if(InpExecutionTriggerMode == EXEC_NECK_RETEST_FAILURE)
     {
      if(!ctx.breakoutSeen)
        {
         if((ctx.setup.direction < 0 && close1 < ctx.setup.breakoutLevel && close1 < open1) ||
            (ctx.setup.direction > 0 && close1 > ctx.setup.breakoutLevel && close1 > open1))
           {
            ctx.breakoutSeen = true;
            ctx.breakoutTime = iTime(runtimeSymbol, InpExecutionTimeframe, 1);
           }
         return false;
        }

      double retestTolerance = PipsToPrice(InpRetestTolerancePips);
      if(ctx.setup.direction < 0)
        {
         if(high1 >= ctx.setup.neckline - retestTolerance &&
            close1 < ctx.setup.breakoutLevel &&
            close1 < open1)
           {
            trigger.fired = true;
            trigger.triggerLabel = "exec_neck_retest_failure";
            trigger.entryPrice = bid;
            trigger.referenceLevel = ctx.setup.neckline;
           }
        }
      else
        {
         if(low1 <= ctx.setup.neckline + retestTolerance &&
            close1 > ctx.setup.breakoutLevel &&
            close1 > open1)
           {
            trigger.fired = true;
            trigger.triggerLabel = "exec_neck_retest_failure";
            trigger.entryPrice = ask;
            trigger.referenceLevel = ctx.setup.neckline;
           }
        }
     }
   else
     {
      if(!ResolveRecentExecutionSwingLevel(ctx))
         return false;

      double buffer = PipsToPrice(InpMinBreakBufferPips);
      if(ctx.setup.direction < 0)
        {
         if(close1 < ctx.recentSwingLevel - buffer && close1 < open1)
           {
            trigger.fired = true;
            trigger.triggerLabel = "exec_recent_swing_break";
            trigger.entryPrice = bid;
            trigger.referenceLevel = ctx.recentSwingLevel;
           }
        }
      else
        {
         if(close1 > ctx.recentSwingLevel + buffer && close1 > open1)
           {
            trigger.fired = true;
            trigger.triggerLabel = "exec_recent_swing_break";
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

double SelectPartialTarget(const ReversalSetup &setup, double entry, string &label)
  {
   double ratio = (InpPartialTargetLevel == PARTIAL_TARGET_500) ? 0.500 : 0.382;
   label = PartialTargetLevelLabel(InpPartialTargetLevel);
   double target = 0.0;
   if(setup.direction < 0)
      target = setup.neckline - (setup.structureHeight * ratio);
   else
      target = setup.neckline + (setup.structureHeight * ratio);

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

double SelectFinalTarget(const ReversalSetup &setup,
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
      target = (setup.direction < 0) ? setup.neckline - (setup.structureHeight * 0.618)
                                     : setup.neckline + (setup.structureHeight * 0.618);

   if((setup.direction < 0 && target < entry) || (setup.direction > 0 && target > entry))
      return target;

   label += "_fallback_r";
   if(setup.direction < 0)
      return entry - risk * InpTargetRMultiple;
   return entry + risk * InpTargetRMultiple;
  }

bool BuildEntryPlan(const ReversalSetup &setup,
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
   if(!partialValid)
      return false;
   if(!finalValid)
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
   plan.patternLabel = setup.patternLabel;
   plan.patternStateLabel = setup.patternStateLabel;
   plan.executionTriggerLabel = trigger.triggerLabel;
   plan.patternTimeframe = TimeframeLabel(InpPatternTimeframe);
   plan.executionTimeframe = TimeframeLabel(InpExecutionTimeframe);
   plan.partialTargetLabel = partialLabel;
   plan.finalTargetLabel = finalLabel;
   plan.volatilityBucket = setup.volatilityBucket;
   plan.neckline = setup.neckline;
   plan.structureHeightPips = setup.structureHeightPips;
   plan.patternAtrPips = setup.patternAtrPips;
   plan.invalidationLevel = NormalizePrice(setup.direction < 0
                                           ? setup.neckline + PipsToPrice(InpAcceptanceExitBufferPips)
                                           : setup.neckline - PipsToPrice(InpAcceptanceExitBufferPips));
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
   plan.reason = "dow_hs_" + setup.tier + "_" + setup.sideLabel + "_" + trigger.triggerLabel;
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
                "pattern_label",
                "pattern_state",
                "execution_trigger",
                "pattern_tf",
                "execution_tf",
                "partial_target_label",
                "final_target_label",
                "neckline",
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
             plan.patternLabel,
             plan.patternStateLabel,
             plan.executionTriggerLabel,
             plan.patternTimeframe,
             plan.executionTimeframe,
             plan.partialTargetLabel,
             plan.finalTargetLabel,
             plan.neckline,
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
         pendingExitReason = activePlan.direction > 0 ? "acceptance_back_below_neck" : "acceptance_back_above_neck";
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

void StagePendingExecution(const ReversalSetup &setup)
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

bool SelectPreferredSetup(const ReversalSetup &shortSetup,
                          const ReversalSetup &longSetup,
                          ReversalSetup &selected)
  {
   ResetReversalSetup(selected);
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
   if(!BuildPatternStructure(pivots, structure))
     {
      ResetPendingExecution(pendingExecution);
      return;
     }

   ReversalSetup shortSetup;
   ReversalSetup longSetup;
   ReversalSetup selected;
   DetectTripleTopSetup(ctx, structure, pivots, shortSetup);
   DetectInverseTripleTopSetup(ctx, structure, pivots, longSetup);
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

void OnDeinit(const int reason)
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
