//+------------------------------------------------------------------+
//| USDJPY Trend Continuation Pullback Engine                        |
//+------------------------------------------------------------------+
#property strict
#property version   "1.10"
#property description "Standalone trend continuation pullback engine scaffold."

#include <Trade\Trade.mqh>

CTrade trade;

enum HtfPhase
  {
   HTF_PHASE_UNKNOWN = 0,
   HTF_UP_IMPULSE = 1,
   HTF_UP_PULLBACK = 2,
   HTF_UP_EXHAUSTION = 3,
   HTF_RANGE = 4,
   HTF_DOWN_IMPULSE = 5,
   HTF_DOWN_PULLBACK = 6,
   HTF_DOWN_EXHAUSTION = 7
  };

enum LtfState
  {
   LTF_STATE_NONE = 0,
   LTF_PULLBACK_IN_PROGRESS = 1,
   LTF_IN_FIB_ZONE = 2,
   LTF_HIGHER_LOW_FORMED = 3,
   LTF_RECLAIM_CONFIRMED = 4,
   LTF_CONTINUATION_BREAK = 5,
   LTF_RETEST_CONTINUATION = 6
  };

enum EntryTierMode
  {
   ENTRY_TIER_A_ONLY = 0,
   ENTRY_TIER_A_AND_B = 1
  };

enum EntryType
  {
   ENTRY_NONE = 0,
   ENTRY_ON_PULLBACK_RECLAIM = 1,
   ENTRY_ON_HIGHER_LOW_BREAK = 2,
   ENTRY_ON_RETEST_CONTINUATION = 3
  };

enum EntryPathMode
  {
   ENTRY_PATH_ALL = 0,
   ENTRY_PATH_PULLBACK_RECLAIM_ONLY = 1,
   ENTRY_PATH_HIGHER_LOW_BREAK_ONLY = 2,
   ENTRY_PATH_RETEST_CONTINUATION_ONLY = 3
  };

enum StopBasisMode
  {
   STOP_PULLBACK_LOW = 0,
   STOP_HIGHER_LOW = 1
  };

enum TargetMode
  {
   TARGET_PRIOR_SWING = 0,
   TARGET_FIXED_R = 1,
   TARGET_FIB = 2,
   TARGET_HYBRID_PARTIAL = 3
  };

enum FibTargetLevel
  {
   FIB_TARGET_382 = 382,
   FIB_TARGET_500 = 500,
   FIB_TARGET_618 = 618
  };

enum HybridPartialTargetLevel
  {
   HYBRID_PARTIAL_EXT_382 = 382,
   HYBRID_PARTIAL_EXT_500 = 500
  };

enum HybridRunnerTargetMode
  {
   HYBRID_RUNNER_FIB_618 = 0,
   HYBRID_RUNNER_PRIOR_SWING = 1,
   HYBRID_RUNNER_FIXED_R = 2
  };

enum ExitExecutionMode
  {
   EXIT_EXEC_EA_MANAGED = 0,
   EXIT_EXEC_SERVER_PARTIAL = 1
  };

struct PivotPoint
  {
   bool     valid;
   bool     isHigh;
   int      shift;
   double   price;
   datetime time;
  };

struct HtfPhaseContext
  {
   bool      valid;
   HtfPhase  phase;
   string    phaseLabel;
   string    trendLabel;
   string    waveLabel;
   string    contextBucket;
   string    fibDepthBucket;
   PivotPoint latestHigh;
   PivotPoint previousHigh;
   PivotPoint latestLow;
   PivotPoint previousLow;
   double    emaFast;
   double    emaSlow;
   double    atr;
   double    rangeHigh;
   double    rangeLow;
   double    rangePosition;
   double    activeWaveHigh;
   double    activeWaveLow;
   double    activeWaveClose;
   double    activeWaveRetracement;
   double    referenceLevelHigh;
   double    referenceLevelLow;
   double    fib382;
   double    fib50;
   double    fib618;
   double    extension382;
   double    extension50;
   double    extension618;
   bool      tierAEligible;
   bool      tierBEligible;
  };

struct LtfStateMachine
  {
   bool      valid;
   LtfState  state;
   string    stateLabel;
   string    structureLabel;
   string    setupType;
   string    volatilityBucket;
   string    fibDepthBucket;
   PivotPoint latestHigh;
   PivotPoint previousHigh;
   PivotPoint latestLow;
   PivotPoint previousLow;
   double    localRangeHigh;
   double    localRangeLow;
   int       parentHighShift;
   int       pullbackLowShift;
   double    pullbackLowPrice;
   double    pullbackRetracement;
   double    reclaimLevel;
   double    continuationLevel;
   double    retestLevel;
   double    higherLowPrice;
   double    targetSwingHigh;
   double    closeLocation;
   double    pullbackDepthPips;
   double    ltfAtrPips;
   bool      pullbackInProgress;
   bool      inFibZone;
   bool      higherLowFormed;
   bool      reclaimConfirmed;
   bool      continuationBreak;
   bool      retestContinuation;
  };

struct PullbackSetup
  {
   bool      valid;
   string    tier;
   EntryType entryType;
   string    entryTypeLabel;
   string    contextBucket;
   string    phaseLabel;
   string    waveLabel;
   string    fibDepthBucket;
   string    ltfStateLabel;
   string    setupType;
   string    stopBasis;
   string    targetType;
   string    volatilityBucket;
   double    referenceLevelHigh;
   double    referenceLevelLow;
   double    fib382;
   double    fib50;
   double    fib618;
   double    extension382;
   double    extension50;
   double    extension618;
   double    htfWaveRetracement;
   double    pullbackRetracement;
   double    pullbackLowPrice;
   double    higherLowPrice;
   double    reclaimLevel;
   double    continuationLevel;
   double    targetSwingHigh;
   double    pullbackDepthPips;
   double    ltfAtrPips;
   datetime  setupTime;
  };

struct EntryPlan
  {
   bool      valid;
   int       direction;
   string    tier;
   EntryType entryType;
   string    entryTypeLabel;
   string    contextBucket;
   string    phaseLabel;
   string    waveLabel;
   string    fibDepthBucket;
   string    ltfStateLabel;
   string    setupType;
   string    stopBasis;
   string    targetType;
   string    orderMode;
   string    partialTargetLabel;
   string    runnerTargetLabel;
   string    volatilityBucket;
   double    referenceLevelHigh;
   double    htfWaveRetracement;
   double    pullbackRetracement;
   double    pullbackDepthPips;
   double    ltfAtrPips;
   double    invalidationLevel;
   double    entry;
   double    stop;
   double    target;
   double    partialTarget;
   bool      usePartial;
   bool      runnerTargetEnabled;
   double    stopDistancePips;
   double    plannedRiskAmount;
   string    reason;
  };

input string          InpSymbol                   = "USDJPY";
input ENUM_TIMEFRAMES InpTrendTimeframe           = PERIOD_M15;
input ENUM_TIMEFRAMES InpSignalTimeframe          = PERIOD_M5;
input int             InpTrendPivotSpan           = 2;
input int             InpSignalPivotSpan          = 2;
input int             InpTrendScanBars            = 240;
input int             InpSignalScanBars           = 160;
input int             InpTrendRangeBars           = 48;
input int             InpTrendFastEMAPeriod       = 20;
input int             InpTrendSlowEMAPeriod       = 50;
input int             InpTrendATRPeriod           = 14;
input int             InpSignalATRPeriod          = 14;
input double          InpTierARangePosMin         = 0.50;
input double          InpTierBRangePosMin         = 0.40;
input double          InpTierAMinPullbackPips     = 8.0;
input double          InpTierBMinPullbackPips     = 4.0;
input double          InpPullbackATRMultiple      = 0.25;
input double          InpReclaimBufferPips        = 0.8;
input double          InpConfirmBreakPips         = 0.5;
input double          InpRetestTolerancePips      = 0.6;
input double          InpTierAMinCloseLocation    = 0.65;
input double          InpTierBMinCloseLocation    = 0.50;
input bool            InpUseFibEntryFilter        = true;
input double          InpFibEntryMinRatio         = 0.382;
input double          InpFibEntryMaxRatio         = 0.618;
input EntryTierMode   InpTierMode                 = ENTRY_TIER_A_AND_B;
input EntryPathMode   InpEntryPathMode            = ENTRY_PATH_ALL;
input StopBasisMode   InpStopBasisMode            = STOP_HIGHER_LOW;
input double          InpMinStopBufferPips        = 1.2;
input double          InpStopBufferATR            = 0.08;
input TargetMode      InpTargetMode               = TARGET_PRIOR_SWING;
input double          InpTargetRMultiple          = 1.20;
input FibTargetLevel  InpFibTargetLevel           = FIB_TARGET_500;
input HybridPartialTargetLevel InpHybridPartialTargetLevel = HYBRID_PARTIAL_EXT_382;
input HybridRunnerTargetMode InpHybridRunnerTargetMode = HYBRID_RUNNER_FIB_618;
input ExitExecutionMode InpExitExecutionMode      = EXIT_EXEC_EA_MANAGED;
input double          InpTargetFrontRunPips       = 1.0;
input double          InpHybridPartialFraction    = 0.50;
input int             InpMaxHoldBars              = 16;
input bool            InpUseAcceptanceExit        = true;
input double          InpAcceptanceExitBufferPips = 0.5;
input double          InpRiskPercent              = 0.35;
input int             InpSessionStartHour         = 0;
input int             InpSessionEndHour           = 0;
input double          InpMaxSpreadPips            = 2.0;
input bool            InpEnableTelemetry          = true;
input string          InpTelemetryFileName        = "mt5_company_usdjpy_20260414_trend_continuation_pullback_long.csv";
input long            InpMagicNumber              = 202604141;

string runtimeSymbol = "";
string runtimeTelemetryFileName = "";
datetime lastBarTime = 0;
int htfFastHandle = INVALID_HANDLE;
int htfSlowHandle = INVALID_HANDLE;
int htfAtrHandle = INVALID_HANDLE;
int ltfAtrHandle = INVALID_HANDLE;
int telemetryHandle = INVALID_HANDLE;

EntryPlan pendingPlan;
EntryPlan activePlan;
bool hasPendingPlan = false;
bool activePartialTaken = false;
bool pendingPartialExit = false;
string pendingExitReason = "";
bool activeBreakEvenMoved = false;
bool activeServerPartialArmed = false;
ulong activeServerPartialOrderTicket = 0;
datetime activeEntryTime = 0;
datetime activePartialTime = 0;
double activeEntryVolume = 0.0;
double activePlannedRiskAmount = 0.0;
int activeBarsToPartial = -1;
int activeBarsToFinal = -1;
int activeBarsToTimeStop = -1;

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

string HtfPhaseLabel(HtfPhase phase)
  {
   switch(phase)
     {
      case HTF_UP_IMPULSE: return "htf_up_impulse";
      case HTF_UP_PULLBACK: return "htf_up_pullback";
      case HTF_UP_EXHAUSTION: return "htf_up_exhaustion";
      case HTF_RANGE: return "htf_range";
      case HTF_DOWN_IMPULSE: return "htf_down_impulse";
      case HTF_DOWN_PULLBACK: return "htf_down_pullback";
      case HTF_DOWN_EXHAUSTION: return "htf_down_exhaustion";
      default: return "htf_unknown";
     }
  }

string LtfStateLabel(LtfState state)
  {
   switch(state)
     {
      case LTF_PULLBACK_IN_PROGRESS: return "pullback_in_progress";
      case LTF_IN_FIB_ZONE: return "in_fib_zone";
      case LTF_HIGHER_LOW_FORMED: return "higher_low_formed";
      case LTF_RECLAIM_CONFIRMED: return "reclaim_confirmed";
      case LTF_CONTINUATION_BREAK: return "continuation_break";
      case LTF_RETEST_CONTINUATION: return "retest_continuation";
      default: return "none";
     }
  }

string EntryTypeLabel(EntryType entryType)
  {
   switch(entryType)
     {
      case ENTRY_ON_PULLBACK_RECLAIM: return "entry_on_pullback_reclaim";
      case ENTRY_ON_HIGHER_LOW_BREAK: return "entry_on_higher_low_break";
      case ENTRY_ON_RETEST_CONTINUATION: return "entry_on_retest_continuation";
     default: return "entry_none";
     }
  }

string ExitExecutionModeLabel(ExitExecutionMode mode)
  {
   if(mode == EXIT_EXEC_SERVER_PARTIAL)
      return "server_partial_limit";
   return "ea_managed";
  }

string HybridPartialTargetLabel(HybridPartialTargetLevel level)
  {
   if(level == HYBRID_PARTIAL_EXT_500)
      return "partial_ext_500";
   return "partial_ext_382";
  }

string HybridRunnerTargetLabel(HybridRunnerTargetMode mode)
  {
   switch(mode)
     {
      case HYBRID_RUNNER_PRIOR_SWING: return "runner_prior_swing";
      case HYBRID_RUNNER_FIXED_R: return "runner_fixed_r";
      default: return "runner_fib_618";
     }
  }

bool EntryTypeAllowed(EntryType entryType)
  {
   if(entryType == ENTRY_NONE)
      return false;

   if(InpEntryPathMode == ENTRY_PATH_ALL)
      return true;
   if(InpEntryPathMode == ENTRY_PATH_PULLBACK_RECLAIM_ONLY)
      return (entryType == ENTRY_ON_PULLBACK_RECLAIM);
   if(InpEntryPathMode == ENTRY_PATH_HIGHER_LOW_BREAK_ONLY)
      return (entryType == ENTRY_ON_HIGHER_LOW_BREAK);
   if(InpEntryPathMode == ENTRY_PATH_RETEST_CONTINUATION_ONLY)
      return (entryType == ENTRY_ON_RETEST_CONTINUATION);
   return false;
  }

string FibDepthBucket(double ratio)
  {
   if(ratio < 0.382)
      return "shallow";
   if(ratio <= 0.618)
      return "natural";
   return "deep";
  }

void ResetPivot(PivotPoint &pivot)
  {
   pivot.valid = false;
   pivot.isHigh = false;
   pivot.shift = 0;
   pivot.price = 0.0;
   pivot.time = 0;
  }

void ResetEntryPlan(EntryPlan &plan)
  {
   plan.valid = false;
   plan.direction = 0;
   plan.tier = "";
   plan.entryType = ENTRY_NONE;
   plan.entryTypeLabel = "";
   plan.contextBucket = "";
   plan.phaseLabel = "";
   plan.waveLabel = "";
   plan.fibDepthBucket = "";
   plan.ltfStateLabel = "";
   plan.setupType = "";
   plan.stopBasis = "";
   plan.targetType = "";
   plan.orderMode = "";
   plan.partialTargetLabel = "";
   plan.runnerTargetLabel = "";
   plan.volatilityBucket = "";
   plan.referenceLevelHigh = 0.0;
   plan.htfWaveRetracement = 0.0;
   plan.pullbackRetracement = 0.0;
   plan.pullbackDepthPips = 0.0;
   plan.ltfAtrPips = 0.0;
   plan.invalidationLevel = 0.0;
   plan.entry = 0.0;
   plan.stop = 0.0;
   plan.target = 0.0;
   plan.partialTarget = 0.0;
   plan.usePartial = false;
   plan.runnerTargetEnabled = false;
   plan.stopDistancePips = 0.0;
   plan.plannedRiskAmount = 0.0;
   plan.reason = "";
  }

void ResetTradeRuntimeState()
  {
   activePartialTaken = false;
   activeBreakEvenMoved = false;
   activeServerPartialArmed = false;
   activeServerPartialOrderTicket = 0;
   activeEntryTime = 0;
   activePartialTime = 0;
   activeEntryVolume = 0.0;
   activePlannedRiskAmount = 0.0;
   activeBarsToPartial = -1;
   activeBarsToFinal = -1;
   activeBarsToTimeStop = -1;
   pendingPartialExit = false;
   pendingExitReason = "";
  }

bool IsNewBar(ENUM_TIMEFRAMES tf, datetime &barTime)
  {
   datetime times[];
   ArraySetAsSeries(times, true);
   if(CopyTime(runtimeSymbol, tf, 0, 2, times) < 2)
      return false;
   if(times[0] == lastBarTime)
      return false;
   lastBarTime = times[0];
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

   return (ArraySize(pivots) >= 4);
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

double ComputeFibRetracement(double lowPrice, double highPrice, double ratio)
  {
   if(highPrice <= lowPrice)
      return 0.0;
   return highPrice - ((highPrice - lowPrice) * ratio);
  }

double ComputeFibExtension(double lowPrice, double highPrice, double ratio)
  {
   if(highPrice <= lowPrice)
      return 0.0;
   return highPrice + ((highPrice - lowPrice) * ratio);
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

HtfPhase ClassifyHtfPhase(const string trendLabel,
                          double emaFast,
                          double emaSlow,
                          double rangePosition,
                          double retraceRatio,
                          double closePrice)
  {
   if(trendLabel == "hh_hl")
     {
      if(closePrice >= emaFast && rangePosition >= 0.60 && retraceRatio <= 0.382)
         return HTF_UP_IMPULSE;
      if(closePrice >= emaSlow && retraceRatio >= 0.236 && retraceRatio <= 0.786)
         return HTF_UP_PULLBACK;
      return HTF_UP_EXHAUSTION;
     }

   if(trendLabel == "lh_ll")
     {
      if(closePrice <= emaFast && rangePosition <= 0.40 && retraceRatio <= 0.382)
         return HTF_DOWN_IMPULSE;
      if(closePrice <= emaSlow && retraceRatio >= 0.236 && retraceRatio <= 0.786)
         return HTF_DOWN_PULLBACK;
      return HTF_DOWN_EXHAUSTION;
     }

   return HTF_RANGE;
  }

string BuildContextBucket(HtfPhase phase, double retraceRatio)
  {
   if(phase == HTF_UP_PULLBACK)
      return "up_pullback_" + FibDepthBucket(retraceRatio);
   if(phase == HTF_UP_IMPULSE)
      return "up_impulse";
   if(phase == HTF_UP_EXHAUSTION)
      return "up_exhaustion";
   if(phase == HTF_RANGE)
      return "range";
   if(phase == HTF_DOWN_IMPULSE || phase == HTF_DOWN_PULLBACK || phase == HTF_DOWN_EXHAUSTION)
      return "down_offside";
   return "offside";
  }

bool BuildHtfPhaseContext(HtfPhaseContext &ctx)
  {
   ctx.valid = false;

   PivotPoint pivots[];
   if(!CollectConfirmedPivots(runtimeSymbol, InpTrendTimeframe, InpTrendPivotSpan, InpTrendScanBars, pivots))
      return false;

   if(!FindLatestTypePivots(pivots, true, ctx.latestHigh, ctx.previousHigh))
      return false;
   if(!FindLatestTypePivots(pivots, false, ctx.latestLow, ctx.previousLow))
      return false;

   double close1 = iClose(runtimeSymbol, InpTrendTimeframe, 1);
   if(close1 <= 0.0)
      return false;

   if(!LoadSingleBuffer(htfFastHandle, 1, ctx.emaFast) ||
      !LoadSingleBuffer(htfSlowHandle, 1, ctx.emaSlow) ||
      !LoadSingleBuffer(htfAtrHandle, 1, ctx.atr))
      return false;

   ctx.rangeHigh = ComputeRangeHigh(InpTrendTimeframe, 1, InpTrendRangeBars);
   ctx.rangeLow = ComputeRangeLow(InpTrendTimeframe, 1, InpTrendRangeBars);
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
   ctx.phase = ClassifyHtfPhase(ctx.trendLabel,
                                ctx.emaFast,
                                ctx.emaSlow,
                                ctx.rangePosition,
                                ctx.activeWaveRetracement,
                                close1);
   ctx.phaseLabel = HtfPhaseLabel(ctx.phase);
   ctx.fibDepthBucket = FibDepthBucket(ctx.activeWaveRetracement);
   ctx.referenceLevelHigh = ctx.latestHigh.price;
   ctx.referenceLevelLow = ctx.activeWaveLow;
   ctx.fib382 = ComputeFibRetracement(ctx.activeWaveLow, ctx.activeWaveHigh, 0.382);
   ctx.fib50 = ComputeFibRetracement(ctx.activeWaveLow, ctx.activeWaveHigh, 0.500);
   ctx.fib618 = ComputeFibRetracement(ctx.activeWaveLow, ctx.activeWaveHigh, 0.618);
   ctx.extension382 = ComputeFibExtension(ctx.activeWaveLow, ctx.activeWaveHigh, 0.382);
   ctx.extension50 = ComputeFibExtension(ctx.activeWaveLow, ctx.activeWaveHigh, 0.500);
   ctx.extension618 = ComputeFibExtension(ctx.activeWaveLow, ctx.activeWaveHigh, 0.618);
   ctx.contextBucket = BuildContextBucket(ctx.phase, ctx.activeWaveRetracement);

   ctx.tierAEligible = (ctx.phase == HTF_UP_PULLBACK &&
                        ctx.rangePosition >= InpTierARangePosMin &&
                        ctx.activeWaveRetracement >= InpFibEntryMinRatio &&
                        ctx.activeWaveRetracement <= 0.786 &&
                        close1 >= ctx.emaSlow);

   ctx.tierBEligible = ((ctx.phase == HTF_UP_PULLBACK || ctx.phase == HTF_UP_IMPULSE) &&
                        ctx.rangePosition >= InpTierBRangePosMin &&
                        ctx.activeWaveRetracement >= 0.236 &&
                        ctx.activeWaveRetracement <= 0.786);

   ctx.valid = true;
   return true;
  }

bool PassFibEntryFilter(double pullbackRetracement, bool strict)
  {
   if(!InpUseFibEntryFilter)
      return true;

   if(strict)
      return (pullbackRetracement >= InpFibEntryMinRatio && pullbackRetracement <= InpFibEntryMaxRatio);

   return (pullbackRetracement >= 0.236 && pullbackRetracement <= 0.786);
  }

bool BuildLtfStateMachine(const HtfPhaseContext &ctx, LtfStateMachine &machine)
  {
   machine.valid = false;

   PivotPoint pivots[];
   if(!CollectConfirmedPivots(runtimeSymbol, InpSignalTimeframe, InpSignalPivotSpan, InpSignalScanBars, pivots))
      return false;

   FindLatestTypePivots(pivots, true, machine.latestHigh, machine.previousHigh);
   FindLatestTypePivots(pivots, false, machine.latestLow, machine.previousLow);

   double ltfAtr = 0.0;
   if(!LoadSingleBuffer(ltfAtrHandle, 1, ltfAtr))
      return false;

   machine.ltfAtrPips = ltfAtr / GetPipSize();
   machine.volatilityBucket = VolatilityBucket(machine.ltfAtrPips);
   machine.localRangeHigh = ComputeRangeHigh(InpSignalTimeframe, 1, MathMin(InpSignalScanBars, 24));
   machine.localRangeLow = ComputeRangeLow(InpSignalTimeframe, 1, MathMin(InpSignalScanBars, 24));

   machine.parentHighShift = iBarShift(runtimeSymbol, InpSignalTimeframe, ctx.latestHigh.time, false);
   if(machine.parentHighShift < 3)
      return false;

   int searchCount = MathMin(machine.parentHighShift, InpSignalScanBars - 1);
   if(searchCount < 3)
      return false;

   machine.pullbackLowShift = iLowest(runtimeSymbol, InpSignalTimeframe, MODE_LOW, searchCount, 1);
   if(machine.pullbackLowShift < 1 || machine.pullbackLowShift >= machine.parentHighShift)
      return false;

   machine.pullbackLowPrice = iLow(runtimeSymbol, InpSignalTimeframe, machine.pullbackLowShift);
   if(machine.pullbackLowPrice <= 0.0)
      return false;

   double pullbackFloorPrice = MathMax(PipsToPrice(InpTierBMinPullbackPips), ltfAtr * InpPullbackATRMultiple);
   double reclaimBufferPrice = PipsToPrice(InpReclaimBufferPips);
   double confirmBreakPrice = PipsToPrice(InpConfirmBreakPips);
   double retestTolerancePrice = PipsToPrice(InpRetestTolerancePips);
   double higherLowFloorPrice = MathMax(PipsToPrice(0.4), ltfAtr * 0.10);

   machine.pullbackDepthPips = (ctx.referenceLevelHigh - machine.pullbackLowPrice) / GetPipSize();
   machine.pullbackRetracement = ComputeFibRetracementRatio(ctx.activeWaveLow, ctx.activeWaveHigh, machine.pullbackLowPrice);
   machine.fibDepthBucket = FibDepthBucket(machine.pullbackRetracement);
   machine.pullbackInProgress = ((ctx.referenceLevelHigh - machine.pullbackLowPrice) >= pullbackFloorPrice);
   if(!machine.pullbackInProgress)
      return false;

   machine.state = LTF_PULLBACK_IN_PROGRESS;
   machine.inFibZone = (machine.pullbackRetracement >= 0.382 && machine.pullbackRetracement <= 0.618);
   if(machine.inFibZone)
      machine.state = LTF_IN_FIB_ZONE;

   machine.higherLowFormed = false;
   machine.higherLowPrice = 0.0;
   if(machine.latestLow.valid &&
      machine.latestLow.shift < machine.pullbackLowShift &&
      machine.latestLow.shift <= 6 &&
      machine.latestLow.price > machine.pullbackLowPrice + higherLowFloorPrice)
     {
      machine.higherLowFormed = true;
      machine.higherLowPrice = machine.latestLow.price;
      machine.state = LTF_HIGHER_LOW_FORMED;
     }

   machine.reclaimLevel = 0.0;
   int reclaimCount = machine.pullbackLowShift - 2;
   if(reclaimCount >= 1)
     {
      int reclaimShift = iHighest(runtimeSymbol, InpSignalTimeframe, MODE_HIGH, reclaimCount, 2);
      if(reclaimShift >= 0)
         machine.reclaimLevel = iHigh(runtimeSymbol, InpSignalTimeframe, reclaimShift);
     }
   if(machine.reclaimLevel <= 0.0)
     {
      if(machine.latestHigh.valid && machine.latestHigh.shift < machine.pullbackLowShift)
         machine.reclaimLevel = machine.latestHigh.price;
      else
         machine.reclaimLevel = iHigh(runtimeSymbol, InpSignalTimeframe, 2);
     }

   double open1 = iOpen(runtimeSymbol, InpSignalTimeframe, 1);
   double high1 = iHigh(runtimeSymbol, InpSignalTimeframe, 1);
   double low1 = iLow(runtimeSymbol, InpSignalTimeframe, 1);
   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;

   machine.closeLocation = CloseLocation(high1, low1, close1);
   machine.reclaimConfirmed = (close1 > machine.reclaimLevel + reclaimBufferPrice &&
                               close1 > open1);
   if(machine.reclaimConfirmed)
      machine.state = LTF_RECLAIM_CONFIRMED;

   machine.continuationLevel = ctx.referenceLevelHigh;
   machine.continuationBreak = (close1 > machine.continuationLevel + confirmBreakPrice &&
                                close1 > open1 &&
                                (machine.reclaimConfirmed || machine.higherLowFormed));
   if(machine.continuationBreak)
      machine.state = LTF_CONTINUATION_BREAK;

   machine.retestLevel = machine.continuationLevel;
   machine.retestContinuation = false;
   double prevClose = iClose(runtimeSymbol, InpSignalTimeframe, 2);
   if(prevClose > machine.continuationLevel + confirmBreakPrice &&
      low1 <= machine.continuationLevel + retestTolerancePrice &&
      close1 > machine.continuationLevel + confirmBreakPrice &&
      close1 > open1)
     {
      machine.retestContinuation = true;
      machine.state = LTF_RETEST_CONTINUATION;
     }

   machine.targetSwingHigh = ctx.referenceLevelHigh;
   machine.setupType = machine.retestContinuation ? "retest_continuation"
                       : machine.continuationBreak ? "continuation_break"
                       : (machine.higherLowFormed && machine.reclaimConfirmed) ? "higher_low_reclaim"
                       : machine.reclaimConfirmed ? "pullback_reclaim"
                       : machine.higherLowFormed ? "higher_low_formed"
                       : machine.inFibZone ? "in_fib_zone"
                       : "pullback_only";
   machine.stateLabel = LtfStateLabel(machine.state);
   machine.structureLabel = machine.stateLabel;
   machine.valid = true;
   return true;
  }

EntryType SelectEntryType(const LtfStateMachine &machine)
  {
   if(machine.retestContinuation)
      return ENTRY_ON_RETEST_CONTINUATION;
   if(machine.higherLowFormed && (machine.reclaimConfirmed || machine.continuationBreak))
      return ENTRY_ON_HIGHER_LOW_BREAK;
   if(machine.reclaimConfirmed)
      return ENTRY_ON_PULLBACK_RECLAIM;
   return ENTRY_NONE;
  }

void FillPullbackSetup(const HtfPhaseContext &ctx,
                       const LtfStateMachine &machine,
                       const string tier,
                       PullbackSetup &setup)
  {
   setup.valid = true;
   setup.tier = tier;
   setup.entryType = SelectEntryType(machine);
   setup.entryTypeLabel = EntryTypeLabel(setup.entryType);
   setup.contextBucket = ctx.contextBucket;
   setup.phaseLabel = ctx.phaseLabel;
   setup.waveLabel = ctx.waveLabel;
   setup.fibDepthBucket = machine.fibDepthBucket;
   setup.ltfStateLabel = machine.stateLabel;
   setup.setupType = machine.setupType;
   setup.stopBasis = (InpStopBasisMode == STOP_HIGHER_LOW) ? "higher_low" : "pullback_low";
   setup.targetType = "pending";
   setup.volatilityBucket = machine.volatilityBucket;
   setup.referenceLevelHigh = ctx.referenceLevelHigh;
   setup.referenceLevelLow = ctx.referenceLevelLow;
   setup.fib382 = ctx.fib382;
   setup.fib50 = ctx.fib50;
   setup.fib618 = ctx.fib618;
   setup.extension382 = ctx.extension382;
   setup.extension50 = ctx.extension50;
   setup.extension618 = ctx.extension618;
   setup.htfWaveRetracement = ctx.activeWaveRetracement;
   setup.pullbackRetracement = machine.pullbackRetracement;
   setup.pullbackLowPrice = machine.pullbackLowPrice;
   setup.higherLowPrice = machine.higherLowPrice;
   setup.reclaimLevel = machine.reclaimLevel;
   setup.continuationLevel = machine.continuationLevel;
   setup.targetSwingHigh = machine.targetSwingHigh;
   setup.pullbackDepthPips = machine.pullbackDepthPips;
   setup.ltfAtrPips = machine.ltfAtrPips;
   setup.setupTime = iTime(runtimeSymbol, InpSignalTimeframe, 1);
  }

bool EvaluateTierA(const HtfPhaseContext &ctx, const LtfStateMachine &machine, PullbackSetup &setup)
  {
   setup.valid = false;
   if(!ctx.tierAEligible)
      return false;
   if(ctx.phase != HTF_UP_PULLBACK)
      return false;
   if(machine.pullbackDepthPips < InpTierAMinPullbackPips)
      return false;
   if(machine.closeLocation < InpTierAMinCloseLocation)
      return false;
   if(!machine.inFibZone)
      return false;
   if(!(machine.higherLowFormed || machine.retestContinuation))
      return false;
   if(!(machine.reclaimConfirmed || machine.continuationBreak || machine.retestContinuation))
      return false;
   if(!PassFibEntryFilter(machine.pullbackRetracement, true))
      return false;

   FillPullbackSetup(ctx, machine, "tier_a", setup);
   return EntryTypeAllowed(setup.entryType);
  }

bool EvaluateTierB(const HtfPhaseContext &ctx, const LtfStateMachine &machine, PullbackSetup &setup)
  {
   setup.valid = false;
   if(InpTierMode != ENTRY_TIER_A_AND_B)
      return false;
   if(!ctx.tierBEligible)
      return false;
   if(!(ctx.phase == HTF_UP_PULLBACK || ctx.phase == HTF_UP_IMPULSE))
      return false;
   if(machine.pullbackDepthPips < InpTierBMinPullbackPips)
      return false;
   if(machine.closeLocation < InpTierBMinCloseLocation)
      return false;
   if(!(machine.reclaimConfirmed || machine.continuationBreak || machine.retestContinuation))
      return false;
   if(!PassFibEntryFilter(machine.pullbackRetracement, false))
      return false;

   FillPullbackSetup(ctx, machine, "tier_b", setup);
   return EntryTypeAllowed(setup.entryType);
  }

bool DetectContinuationSetup(const HtfPhaseContext &ctx, PullbackSetup &setup)
  {
   setup.valid = false;
   if(!ctx.valid)
      return false;

   LtfStateMachine machine;
   if(!BuildLtfStateMachine(ctx, machine))
      return false;

   if(EvaluateTierA(ctx, machine, setup))
      return true;

   if(EvaluateTierB(ctx, machine, setup))
      return true;

   return false;
  }

double SelectPreferredFibTarget(const PullbackSetup &setup, double entryPrice)
  {
   double frontRun = PipsToPrice(InpTargetFrontRunPips);
   double candidates[3];
   candidates[0] = setup.extension382 - frontRun;
   candidates[1] = setup.extension50 - frontRun;
   candidates[2] = setup.extension618 - frontRun;

   int preferredIndex = 1;
   if(InpFibTargetLevel == FIB_TARGET_382)
      preferredIndex = 0;
   else if(InpFibTargetLevel == FIB_TARGET_618)
      preferredIndex = 2;

   if(candidates[preferredIndex] > entryPrice)
      return candidates[preferredIndex];

   for(int i = 0; i < 3; ++i)
     {
      if(candidates[i] > entryPrice)
         return candidates[i];
     }

   return 0.0;
  }

double SelectHybridPartialTarget(const PullbackSetup &setup)
  {
   double frontRun = PipsToPrice(InpTargetFrontRunPips);
   if(InpHybridPartialTargetLevel == HYBRID_PARTIAL_EXT_500)
      return setup.extension50 - frontRun;
   return setup.extension382 - frontRun;
  }

double SelectHybridRunnerTarget(const PullbackSetup &setup,
                                double entryPrice,
                                double risk,
                                double partialTarget,
                                bool &enabled,
                                string &label)
  {
   enabled = false;
   label = HybridRunnerTargetLabel(InpHybridRunnerTargetMode);

   double frontRun = PipsToPrice(InpTargetFrontRunPips);
   double target = 0.0;
   if(InpHybridRunnerTargetMode == HYBRID_RUNNER_PRIOR_SWING)
      target = setup.targetSwingHigh - frontRun;
   else if(InpHybridRunnerTargetMode == HYBRID_RUNNER_FIXED_R)
      target = entryPrice + (risk * InpTargetRMultiple);
   else
      target = setup.extension618 - frontRun;

   if(target <= entryPrice)
     {
      label += "_disabled_below_entry";
      return 0.0;
     }

   if(partialTarget > 0.0 && target <= partialTarget)
     {
      label += "_disabled_below_partial";
      return 0.0;
     }

   enabled = true;
   return target;
  }

bool BuildEntryPlan(const PullbackSetup &setup, EntryPlan &plan)
  {
   ResetEntryPlan(plan);
   if(!setup.valid)
      return false;

   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   double stopBufferPrice = MathMax(PipsToPrice(InpMinStopBufferPips),
                                    PipsToPrice(setup.ltfAtrPips * InpStopBufferATR));
   double stopAnchor = setup.pullbackLowPrice;
   if(InpStopBasisMode == STOP_HIGHER_LOW && setup.higherLowPrice > 0.0)
      stopAnchor = setup.higherLowPrice;

   double entry = NormalizePrice(ask);
   double stop = NormalizePrice(stopAnchor - stopBufferPrice);
   if(stop >= entry)
      return false;

   double risk = entry - stop;
   double frontRun = PipsToPrice(InpTargetFrontRunPips);
   double target = 0.0;
   double partialTarget = 0.0;
   bool usePartial = false;
   bool runnerTargetEnabled = false;
   string targetType = "";
   string partialTargetLabel = "partial_none";
   string runnerTargetLabel = "runner_none";
   string orderMode = ExitExecutionModeLabel(InpExitExecutionMode);

   if(InpTargetMode == TARGET_PRIOR_SWING)
     {
      target = NormalizePrice(setup.targetSwingHigh - frontRun);
      targetType = "prior_swing";
      if(target <= entry)
        {
         target = NormalizePrice(entry + risk * InpTargetRMultiple);
         targetType = "prior_swing_fallback_r";
        }
     }
   else if(InpTargetMode == TARGET_FIXED_R)
     {
      target = NormalizePrice(entry + risk * InpTargetRMultiple);
      targetType = "fixed_r";
     }
   else if(InpTargetMode == TARGET_FIB)
     {
      target = NormalizePrice(SelectPreferredFibTarget(setup, entry));
      targetType = "fib";
      if(target <= 0.0 || target <= entry)
        {
         target = NormalizePrice(entry + risk * InpTargetRMultiple);
         targetType = "fib_fallback_r";
        }
     }
   else
     {
      partialTarget = NormalizePrice(SelectHybridPartialTarget(setup));
      partialTargetLabel = HybridPartialTargetLabel(InpHybridPartialTargetLevel);
      usePartial = (partialTarget > entry);
      target = NormalizePrice(SelectHybridRunnerTarget(setup,
                                                       entry,
                                                       risk,
                                                       partialTarget,
                                                       runnerTargetEnabled,
                                                       runnerTargetLabel));
      targetType = "hybrid_partial";
      if(!usePartial)
         return false;
     }

   if(InpTargetMode != TARGET_HYBRID_PARTIAL && target <= entry)
      return false;
   if(usePartial && partialTarget <= entry)
      return false;
   if(InpTargetMode == TARGET_HYBRID_PARTIAL && runnerTargetEnabled && target <= partialTarget)
      return false;

   plan.valid = true;
   plan.direction = 1;
   plan.tier = setup.tier;
   plan.entryType = setup.entryType;
   plan.entryTypeLabel = setup.entryTypeLabel;
   plan.contextBucket = setup.contextBucket;
   plan.phaseLabel = setup.phaseLabel;
   plan.waveLabel = setup.waveLabel;
   plan.fibDepthBucket = setup.fibDepthBucket;
   plan.ltfStateLabel = setup.ltfStateLabel;
   plan.setupType = setup.setupType;
   plan.stopBasis = setup.stopBasis;
   plan.targetType = targetType;
   plan.orderMode = orderMode;
   plan.partialTargetLabel = partialTargetLabel;
   plan.runnerTargetLabel = runnerTargetLabel;
   plan.volatilityBucket = setup.volatilityBucket;
   plan.referenceLevelHigh = setup.referenceLevelHigh;
   plan.htfWaveRetracement = setup.htfWaveRetracement;
   plan.pullbackRetracement = setup.pullbackRetracement;
   plan.pullbackDepthPips = setup.pullbackDepthPips;
   plan.ltfAtrPips = setup.ltfAtrPips;
   plan.invalidationLevel = NormalizePrice(stopAnchor - PipsToPrice(InpAcceptanceExitBufferPips));
   plan.entry = entry;
   plan.stop = stop;
   plan.target = target;
   plan.partialTarget = partialTarget;
   plan.usePartial = usePartial;
    plan.runnerTargetEnabled = runnerTargetEnabled;
   plan.stopDistancePips = risk / GetPipSize();
   plan.plannedRiskAmount = 0.0;
   plan.reason = "trend_continuation_" + setup.tier + "_" + setup.entryTypeLabel;
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

int BarsSinceSignalTime(datetime eventTime)
  {
   if(eventTime <= 0)
      return -1;
   int shift = iBarShift(runtimeSymbol, InpSignalTimeframe, eventTime, false);
   if(shift < 0)
      return -1;
   return shift;
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
   if(currentSl >= newSl - PipsToPrice(0.1))
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

bool CancelServerPartialOrder()
  {
   if(activeServerPartialOrderTicket == 0)
     {
      activeServerPartialArmed = false;
      return true;
     }

   if(!OrderSelect(activeServerPartialOrderTicket))
     {
      activeServerPartialOrderTicket = 0;
      activeServerPartialArmed = false;
      return true;
     }

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_REMOVE;
   request.order = activeServerPartialOrderTicket;
   request.symbol = runtimeSymbol;
   if(!OrderSend(request, result))
      return false;
   if(result.retcode != TRADE_RETCODE_DONE)
      return false;

   activeServerPartialOrderTicket = 0;
   activeServerPartialArmed = false;
   return true;
  }

bool ArmServerPartialOrder()
  {
   activeServerPartialArmed = false;
   activeServerPartialOrderTicket = 0;

   if(!activePlan.valid || !activePlan.usePartial || activePlan.partialTarget <= activePlan.entry)
      return false;
   if(!PositionSelect(runtimeSymbol))
      return false;
   if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
      return false;

   double currentVolume = PositionGetDouble(POSITION_VOLUME);
   double closeVolume = 0.0;
   if(!ComputePartialCloseVolume(currentVolume, closeVolume))
      return false;

   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action = TRADE_ACTION_PENDING;
   request.symbol = runtimeSymbol;
   request.magic = InpMagicNumber;
   request.volume = closeVolume;
   request.price = NormalizePrice(activePlan.partialTarget);
   request.type = ORDER_TYPE_SELL_LIMIT;
   request.type_filling = ORDER_FILLING_RETURN;
   request.type_time = ORDER_TIME_GTC;
   request.comment = "partial_runner";

   if(!OrderSend(request, result))
      return false;
   if(result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED)
      return false;

   activeServerPartialOrderTicket = result.order;
   activeServerPartialArmed = (activeServerPartialOrderTicket > 0);
   return activeServerPartialArmed;
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
                "entry_type",
                "phase",
                "wave_label",
                "context_bucket",
                "fib_depth_bucket",
                "ltf_state",
                "setup_type",
                "stop_basis",
                "target_type",
                "order_mode",
                "partial_target_label",
                "runner_target_label",
                "hour",
                "volatility_bucket",
                "reference_level",
                "htf_wave_retracement",
                "pullback_retracement",
                "pullback_depth_pips",
                "ltf_atr_pips",
                "stop_distance_pips",
                "planned_risk_amount",
                "partial_taken",
                "be_moved",
                "partial_order_armed",
                "runner_target_enabled",
                "runner_target_hit",
                "runner_stop_at_breakeven",
                "bars_since_entry",
                "bars_to_partial",
                "bars_to_final",
                "bars_to_time_stop",
                "target_reached_before_timeout",
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

   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);

   int barsSinceEntry = (eventType == "entry") ? 0 : BarsSinceSignalTime(activeEntryTime);
   double plannedRiskAmount = activePlannedRiskAmount;
   if(plannedRiskAmount <= 0.0)
      plannedRiskAmount = plan.plannedRiskAmount;

   bool runnerTargetHit = (reason == "runner_target");
   bool runnerStopAtBreakeven = (reason == "breakeven_after_partial");
   bool targetReachedBeforeTimeout = ((reason == "target" || reason == "runner_target") &&
                                      barsSinceEntry >= 0 &&
                                      (InpMaxHoldBars <= 0 || barsSinceEntry < InpMaxHoldBars));

   int barsToPartial = activeBarsToPartial;
   int barsToFinal = activeBarsToFinal;
   int barsToTimeStop = activeBarsToTimeStop;
   if(eventType == "partial_exit" && barsToPartial < 0)
      barsToPartial = barsSinceEntry;
   if((reason == "target" || reason == "runner_target") && barsToFinal < 0)
      barsToFinal = barsSinceEntry;
   if(reason == "time_stop" && barsToTimeStop < 0)
      barsToTimeStop = barsSinceEntry;

   double eventRMultiple = 0.0;
   if(plannedRiskAmount > 0.0)
      eventRMultiple = netProfit / plannedRiskAmount;

   FileSeek(telemetryHandle, 0, SEEK_END);
   FileWrite(telemetryHandle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             eventType,
             "long",
             (long)positionId,
             plan.tier,
             plan.entryTypeLabel,
             plan.phaseLabel,
             plan.waveLabel,
             plan.contextBucket,
             plan.fibDepthBucket,
             plan.ltfStateLabel,
             plan.setupType,
             plan.stopBasis,
             plan.targetType,
             plan.orderMode,
             plan.partialTargetLabel,
             plan.runnerTargetLabel,
             tm.hour,
             plan.volatilityBucket,
             plan.referenceLevelHigh,
             plan.htfWaveRetracement,
             plan.pullbackRetracement,
             plan.pullbackDepthPips,
             plan.ltfAtrPips,
             plan.stopDistancePips,
             plannedRiskAmount,
             (int)activePartialTaken,
             (int)activeBreakEvenMoved,
             (int)activeServerPartialArmed,
             (int)plan.runnerTargetEnabled,
             (int)runnerTargetHit,
             (int)runnerStopAtBreakeven,
             barsSinceEntry,
             barsToPartial,
             barsToFinal,
             barsToTimeStop,
             (int)targetReachedBeforeTimeout,
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

string InferExitReason(double dealPrice, bool stillOpen)
  {
   if(pendingExitReason != "")
      return pendingExitReason;

   double pip = GetPipSize();
   if(activePlan.valid)
     {
      if(activePartialTaken && dealPrice <= activePlan.entry + pip * 0.2)
         return "breakeven_after_partial";
      if(dealPrice <= activePlan.stop + pip * 0.2)
         return "stop_loss";
      if(!stillOpen && activePlan.runnerTargetEnabled && dealPrice >= activePlan.target - pip * 0.2)
         return activePartialTaken ? "runner_target" : "target";
      if(!stillOpen && !activePlan.runnerTargetEnabled && activePartialTaken)
         return "runner_timeout";
      if(!stillOpen && !activePlan.usePartial && dealPrice >= activePlan.target - pip * 0.2)
         return "target";
      if(stillOpen)
         return "hybrid_partial";
     }

   return "platform_exit";
  }

void ManageOpenPositions()
  {
   if(!PositionSelect(runtimeSymbol))
     {
      CancelServerPartialOrder();
      return;
     }
   if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
      return;
   if(!activePlan.valid)
      return;

   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   if(bid <= 0.0)
      return;

   double currentVolume = PositionGetDouble(POSITION_VOLUME);
   datetime openedAt = (datetime)PositionGetInteger(POSITION_TIME);
   int barsSinceEntry = iBarShift(runtimeSymbol, InpSignalTimeframe, openedAt, false);

   if(activePlan.usePartial && activePartialTaken && !activeBreakEvenMoved)
      MoveStopToBreakeven();

   if(activePlan.usePartial &&
      !activePartialTaken &&
      InpExitExecutionMode == EXIT_EXEC_EA_MANAGED &&
      activePlan.partialTarget > 0.0 &&
      bid >= activePlan.partialTarget)
     {
      double closeVolume = 0.0;
      if(ComputePartialCloseVolume(currentVolume, closeVolume))
        {
         activePartialTaken = true;
         activePartialTime = TimeCurrent();
         activeBarsToPartial = barsSinceEntry;
         pendingExitReason = "hybrid_partial";
         pendingPartialExit = true;
         if(trade.PositionClosePartial(runtimeSymbol, closeVolume))
           {
            MoveStopToBreakeven();
           }
         else
           {
            activePartialTaken = false;
            activePartialTime = 0;
            activeBarsToPartial = -1;
            pendingExitReason = "";
            pendingPartialExit = false;
           }
        }
     }

   if(PositionSelect(runtimeSymbol) && (long)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
     {
      if(activePlan.runnerTargetEnabled && activePlan.target > 0.0 && bid >= activePlan.target)
        {
         activeBarsToFinal = barsSinceEntry;
         pendingExitReason = activePartialTaken ? "runner_target" : "target";
         trade.PositionClose(runtimeSymbol);
         return;
        }

      if(InpUseAcceptanceExit && iClose(runtimeSymbol, InpSignalTimeframe, 1) < activePlan.invalidationLevel)
        {
         pendingExitReason = "acceptance_back_below";
         trade.PositionClose(runtimeSymbol);
         return;
        }

      if(InpMaxHoldBars > 0 && barsSinceEntry >= InpMaxHoldBars && barsSinceEntry >= 0)
        {
         activeBarsToTimeStop = barsSinceEntry;
         pendingExitReason = "time_stop";
         trade.PositionClose(runtimeSymbol);
        }
     }
  }

int OnInit()
  {
   runtimeSymbol = NormalizePresetString(InpSymbol);
   runtimeTelemetryFileName = NormalizePresetString(InpTelemetryFileName);
   ResetEntryPlan(pendingPlan);
   ResetEntryPlan(activePlan);
   ResetTradeRuntimeState();

   if(InpMagicNumber <= 0 || InpTrendPivotSpan <= 0 || InpSignalPivotSpan <= 0 ||
      InpTrendATRPeriod <= 0 || InpSignalATRPeriod <= 0 ||
      InpRiskPercent <= 0.0 || InpTargetRMultiple <= 0.0 ||
      InpTierARangePosMin < 0.0 || InpTierARangePosMin > 1.0 ||
      InpTierBRangePosMin < 0.0 || InpTierBRangePosMin > 1.0 ||
      InpFibEntryMinRatio < 0.0 || InpFibEntryMaxRatio < InpFibEntryMinRatio ||
      InpHybridPartialFraction <= 0.0 || InpHybridPartialFraction >= 1.0)
      return INIT_PARAMETERS_INCORRECT;

   trade.SetExpertMagicNumber((ulong)InpMagicNumber);

   htfFastHandle = iMA(runtimeSymbol, InpTrendTimeframe, InpTrendFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   htfSlowHandle = iMA(runtimeSymbol, InpTrendTimeframe, InpTrendSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   htfAtrHandle = iATR(runtimeSymbol, InpTrendTimeframe, InpTrendATRPeriod);
   ltfAtrHandle = iATR(runtimeSymbol, InpSignalTimeframe, InpSignalATRPeriod);
   if(htfFastHandle == INVALID_HANDLE || htfSlowHandle == INVALID_HANDLE ||
      htfAtrHandle == INVALID_HANDLE || ltfAtrHandle == INVALID_HANDLE)
      return INIT_FAILED;

   if(InpEnableTelemetry)
      OpenTelemetryFile();

   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   CancelServerPartialOrder();
   if(htfFastHandle != INVALID_HANDLE)
      IndicatorRelease(htfFastHandle);
   if(htfSlowHandle != INVALID_HANDLE)
      IndicatorRelease(htfSlowHandle);
   if(htfAtrHandle != INVALID_HANDLE)
      IndicatorRelease(htfAtrHandle);
   if(ltfAtrHandle != INVALID_HANDLE)
      IndicatorRelease(ltfAtrHandle);
   CloseTelemetryFile();
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
         activeEntryVolume = volume;
         activePlannedRiskAmount = activePlan.plannedRiskAmount > 0.0
                                   ? activePlan.plannedRiskAmount
                                   : CalculateRiskAmountByVolume(activePlan.entry, activePlan.stop, volume);
         hasPendingPlan = false;
         if(activePlan.usePartial && activePlan.orderMode == ExitExecutionModeLabel(EXIT_EXEC_SERVER_PARTIAL))
            ArmServerPartialOrder();
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
            if(activePartialTime == 0)
               activePartialTime = dealTime;
            if(activeBarsToPartial < 0)
               activeBarsToPartial = BarsSinceSignalTime(activeEntryTime);
            activeServerPartialOrderTicket = 0;
            activeServerPartialArmed = false;
            if(!activeBreakEvenMoved)
               MoveStopToBreakeven();
           }

         string reason = InferExitReason(price, stillOpen);
         if(reason == "target" || reason == "runner_target")
            activeBarsToFinal = BarsSinceSignalTime(activeEntryTime);
         if(reason == "time_stop")
            activeBarsToTimeStop = BarsSinceSignalTime(activeEntryTime);

         if(!stillOpen)
            CancelServerPartialOrder();

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

void OnTick()
  {
   datetime barTime = 0;
   if(!IsNewBar(InpSignalTimeframe, barTime))
      return;

   ManageOpenPositions();

   if(!PassGlobalGuards())
      return;

   HtfPhaseContext ctx;
   if(!BuildHtfPhaseContext(ctx))
      return;

   PullbackSetup setup;
   if(!DetectContinuationSetup(ctx, setup))
      return;

   EntryPlan plan;
   if(!BuildEntryPlan(setup, plan))
      return;

   double volume = CalculateVolumeByRisk(plan.entry, plan.stop);
   if(volume <= 0.0)
      return;
   plan.plannedRiskAmount = CalculateRiskAmountByVolume(plan.entry, plan.stop, volume);

   ResetEntryPlan(pendingPlan);
   pendingPlan = plan;
   hasPendingPlan = false;

   if(trade.Buy(volume, runtimeSymbol, 0.0, plan.stop, 0.0, plan.reason))
     {
      pendingPlan = plan;
      hasPendingPlan = true;
     }
   else
     {
      ResetEntryPlan(pendingPlan);
     }
  }
