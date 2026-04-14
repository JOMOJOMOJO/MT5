//+------------------------------------------------------------------+
//| USDJPY Failed Breakout Short Structure Engine                    |
//+------------------------------------------------------------------+
#property strict
#property version   "1.20"
#property description "Standalone failed-breakout short structure engine scaffold."

#include <Trade\Trade.mqh>

CTrade trade;

enum HtfPhase
  {
   HTF_PHASE_UNKNOWN = 0,
   HTF_UP_IMPULSE = 1,
   HTF_UP_PULLBACK = 2,
   HTF_UP_EXHAUSTION = 3,
   HTF_RANGE_TOP = 4,
   HTF_RANGE_MIDDLE = 5,
   HTF_RANGE_BOTTOM = 6,
   HTF_DOWN_IMPULSE = 7,
   HTF_DOWN_PULLBACK = 8,
   HTF_DOWN_EXHAUSTION = 9
  };

enum LtfState
  {
   LTF_STATE_NONE = 0,
   LTF_SWEEP_ONLY = 1,
   LTF_FAILED_ACCEPTANCE = 2,
   LTF_RECLAIM_CONFIRMED = 3,
   LTF_LOWER_HIGH_FORMED = 4,
   LTF_BREAKDOWN_CONFIRMED = 5,
   LTF_RETEST_FAILURE = 6
  };

enum EntryTierMode
  {
   ENTRY_TIER_A_ONLY = 0,
   ENTRY_TIER_A_AND_B = 1
  };

enum EntryType
  {
   ENTRY_NONE = 0,
   ENTRY_ON_RECLAIM_FAILURE = 1,
   ENTRY_ON_LOWER_HIGH_BREAKDOWN = 2,
   ENTRY_ON_RETEST_FAILURE = 3
  };

enum StopBasisMode
  {
   STOP_SWEEP_HIGH = 0,
   STOP_FAILURE_PIVOT = 1
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
   bool      tierAEligible;
   bool      tierBEligible;
  };

struct LtfStateMachine
  {
   bool      valid;
   LtfState  state;
   string    stateLabel;
   string    structureLabel;
   string    failureType;
   string    volatilityBucket;
   PivotPoint latestHigh;
   PivotPoint previousHigh;
   PivotPoint latestLow;
   PivotPoint previousLow;
   double    localRangeHigh;
   double    localRangeLow;
   int       sweepShift;
   double    sweepHigh;
   double    sweepClose;
   double    reclaimClose;
   double    reclaimLow;
   double    lowerHighPrice;
   double    failurePivotHigh;
   double    breakdownLevel;
   double    retestLevel;
   double    retestHigh;
   double    targetSwingLow;
   double    closeLocation;
   double    sweepSizePips;
   double    ltfAtrPips;
   bool      sweepDetected;
   bool      failedAcceptance;
   bool      reclaimConfirmed;
   bool      lowerHighFormed;
   bool      breakdownConfirmed;
   bool      retestFailure;
  };

struct FailureSetup
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
   string    failureType;
   string    stopBasis;
   string    targetType;
   string    volatilityBucket;
   double    referenceLevelHigh;
   double    referenceLevelLow;
   double    fib382;
   double    fib50;
   double    fib618;
   double    activeWaveRetracement;
   double    sweepHigh;
   double    failurePivotHigh;
   double    breakdownLevel;
   double    targetSwingLow;
   double    invalidationLevel;
   double    sweepSizePips;
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
   string    failureType;
   string    stopBasis;
   string    targetType;
   string    volatilityBucket;
   double    referenceLevelHigh;
   double    activeWaveRetracement;
   double    sweepSizePips;
   double    ltfAtrPips;
   double    invalidationLevel;
   double    entry;
   double    stop;
   double    target;
   double    partialTarget;
   bool      usePartial;
   double    stopDistancePips;
   string    reason;
  };

input string          InpSymbol                       = "USDJPY";
input ENUM_TIMEFRAMES InpTrendTimeframe               = PERIOD_M15;
input ENUM_TIMEFRAMES InpSignalTimeframe              = PERIOD_M5;
input int             InpTrendPivotSpan               = 2;
input int             InpSignalPivotSpan              = 2;
input int             InpTrendScanBars                = 240;
input int             InpSignalScanBars               = 160;
input int             InpTrendRangeBars               = 48;
input int             InpTrendFastEMAPeriod           = 20;
input int             InpTrendSlowEMAPeriod           = 50;
input int             InpTrendATRPeriod               = 14;
input int             InpSignalATRPeriod              = 14;
input double          InpTierARangePosMin             = 0.72;
input double          InpTierBRangePosMin             = 0.60;
input double          InpTierAMinSweepPips            = 6.0;
input double          InpTierBMinSweepPips            = 3.5;
input double          InpSweepATRMultiple             = 0.18;
input double          InpReclaimBufferPips            = 0.8;
input double          InpConfirmBreakPips             = 0.5;
input double          InpRetestTolerancePips          = 0.6;
input double          InpTierAMaxCloseLocation        = 0.35;
input double          InpTierBMaxCloseLocation        = 0.50;
input bool            InpUseFibEntryFilter            = true;
input double          InpFibEntryMinRatio             = 0.382;
input double          InpFibEntryMaxRatio             = 0.618;
input EntryTierMode   InpTierMode                     = ENTRY_TIER_A_AND_B;
input StopBasisMode   InpStopBasisMode                = STOP_SWEEP_HIGH;
input double          InpMinStopBufferPips            = 1.2;
input double          InpStopBufferATR                = 0.08;
input TargetMode      InpTargetMode                   = TARGET_PRIOR_SWING;
input double          InpTargetRMultiple              = 1.10;
input double          InpTargetATRMultiple            = 1.80;
input FibTargetLevel  InpFibTargetLevel               = FIB_TARGET_500;
input int             InpTargetSwingLookbackBars      = 36;
input double          InpTargetFrontRunPips           = 1.5;
input double          InpHybridPartialFraction        = 0.50;
input int             InpMaxHoldBars                  = 12;
input bool            InpUseAcceptanceExit            = true;
input double          InpAcceptanceExitBufferPips     = 0.5;
input double          InpRiskPercent                  = 0.35;
input int             InpSessionStartHour             = 0;
input int             InpSessionEndHour               = 0;
input double          InpMaxSpreadPips                = 2.0;
input bool            InpEnableTelemetry              = true;
input string          InpTelemetryFileName            = "mt5_company_usdjpy_20260413_failed_breakout_short.csv";
input long            InpMagicNumber                  = 202604131;

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
      case HTF_RANGE_TOP: return "htf_range_top";
      case HTF_RANGE_MIDDLE: return "htf_range_middle";
      case HTF_RANGE_BOTTOM: return "htf_range_bottom";
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
      case LTF_SWEEP_ONLY: return "sweep_only";
      case LTF_FAILED_ACCEPTANCE: return "failed_acceptance";
      case LTF_RECLAIM_CONFIRMED: return "reclaim_confirmed";
      case LTF_LOWER_HIGH_FORMED: return "lower_high_formed";
      case LTF_BREAKDOWN_CONFIRMED: return "breakdown_confirmed";
      case LTF_RETEST_FAILURE: return "retest_failure";
      default: return "none";
     }
  }

string EntryTypeLabel(EntryType entryType)
  {
   switch(entryType)
     {
      case ENTRY_ON_RECLAIM_FAILURE: return "entry_on_reclaim_failure";
      case ENTRY_ON_LOWER_HIGH_BREAKDOWN: return "entry_on_lower_high_breakdown";
      case ENTRY_ON_RETEST_FAILURE: return "entry_on_retest_failure";
      default: return "entry_none";
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
   plan.failureType = "";
   plan.stopBasis = "";
   plan.targetType = "";
   plan.volatilityBucket = "";
   plan.referenceLevelHigh = 0.0;
   plan.activeWaveRetracement = 0.0;
   plan.sweepSizePips = 0.0;
   plan.ltfAtrPips = 0.0;
   plan.invalidationLevel = 0.0;
   plan.entry = 0.0;
   plan.stop = 0.0;
   plan.target = 0.0;
   plan.partialTarget = 0.0;
   plan.usePartial = false;
   plan.stopDistancePips = 0.0;
   plan.reason = "";
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

string FibDepthBucket(double ratio)
  {
   if(ratio < 0.382)
      return "shallow";
   if(ratio <= 0.618)
      return "natural";
   return "deep";
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
      if(closePrice >= emaFast && retraceRatio <= 0.25 && rangePosition >= 0.75)
         return HTF_UP_IMPULSE;
      if(retraceRatio <= 0.618 && closePrice >= emaSlow)
         return HTF_UP_PULLBACK;
      return HTF_UP_EXHAUSTION;
     }

   if(trendLabel == "lh_ll")
     {
      if(closePrice <= emaFast && retraceRatio <= 0.25 && rangePosition <= 0.25)
         return HTF_DOWN_IMPULSE;
      if(retraceRatio <= 0.618 && closePrice <= emaSlow)
         return HTF_DOWN_PULLBACK;
      return HTF_DOWN_EXHAUSTION;
     }

   if(rangePosition >= 0.75)
      return HTF_RANGE_TOP;
   if(rangePosition <= 0.25)
      return HTF_RANGE_BOTTOM;
   return HTF_RANGE_MIDDLE;
  }

string BuildContextBucket(HtfPhase phase, double rangePosition)
  {
   if(phase == HTF_UP_EXHAUSTION)
      return "up_exhaustion";
   if(phase == HTF_RANGE_TOP)
      return "range_top";
   if(phase == HTF_UP_PULLBACK)
      return "up_pullback";
   if(phase == HTF_UP_IMPULSE)
      return "up_impulse";
   if(rangePosition >= 0.60)
      return "upper_probe";
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
   ctx.phase = ClassifyHtfPhase(ctx.trendLabel, ctx.emaFast, ctx.emaSlow, ctx.rangePosition, ctx.activeWaveRetracement, close1);
   ctx.phaseLabel = HtfPhaseLabel(ctx.phase);
   ctx.fibDepthBucket = FibDepthBucket(ctx.activeWaveRetracement);
   ctx.referenceLevelHigh = MathMax(ctx.latestHigh.price, ctx.previousHigh.price);
   ctx.referenceLevelLow = MathMin(ctx.latestHigh.price, ctx.previousHigh.price);
   ctx.fib382 = ComputeFibRetracement(ctx.activeWaveLow, ctx.activeWaveHigh, 0.382);
   ctx.fib50 = ComputeFibRetracement(ctx.activeWaveLow, ctx.activeWaveHigh, 0.500);
   ctx.fib618 = ComputeFibRetracement(ctx.activeWaveLow, ctx.activeWaveHigh, 0.618);
   ctx.contextBucket = BuildContextBucket(ctx.phase, ctx.rangePosition);

   ctx.tierAEligible = ((ctx.phase == HTF_UP_EXHAUSTION || ctx.phase == HTF_RANGE_TOP) &&
                        ctx.rangePosition >= InpTierARangePosMin &&
                        ctx.activeWaveRetracement >= InpFibEntryMinRatio &&
                        ctx.activeWaveRetracement <= 0.90);

   ctx.tierBEligible = ((ctx.phase == HTF_UP_PULLBACK || ctx.phase == HTF_UP_EXHAUSTION || ctx.phase == HTF_RANGE_TOP) &&
                        ctx.rangePosition >= InpTierBRangePosMin);

   ctx.valid = true;
   return true;
  }

bool PassFibEntryFilter(const HtfPhaseContext &ctx, double reclaimClose, bool strict, double &ratio)
  {
   ratio = ComputeFibRetracementRatio(ctx.activeWaveLow, ctx.activeWaveHigh, reclaimClose);
   if(!InpUseFibEntryFilter)
      return true;

   if(strict)
      return (ratio >= InpFibEntryMinRatio && ratio <= InpFibEntryMaxRatio);

   return (ratio >= 0.236 && ratio <= 0.786);
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

   double sweepFloorPrice = MathMax(PipsToPrice(InpTierBMinSweepPips), ltfAtr * InpSweepATRMultiple);
   double reclaimBufferPrice = PipsToPrice(InpReclaimBufferPips);
   double confirmBreakPrice = PipsToPrice(InpConfirmBreakPips);
   double retestTolerancePrice = PipsToPrice(InpRetestTolerancePips);

   machine.sweepShift = -1;
   for(int shift = 3; shift >= 1; --shift)
     {
      if(iHigh(runtimeSymbol, InpSignalTimeframe, shift) > ctx.referenceLevelHigh + sweepFloorPrice)
        {
         machine.sweepShift = shift;
         break;
        }
     }

   if(machine.sweepShift < 0)
      return false;

   machine.sweepDetected = true;
   machine.sweepHigh = iHigh(runtimeSymbol, InpSignalTimeframe, machine.sweepShift);
   machine.sweepClose = iClose(runtimeSymbol, InpSignalTimeframe, machine.sweepShift);
   machine.sweepSizePips = (machine.sweepHigh - ctx.referenceLevelHigh) / GetPipSize();

   machine.failedAcceptance = (machine.sweepClose < ctx.referenceLevelLow - reclaimBufferPrice);
   if(machine.failedAcceptance)
      machine.state = LTF_FAILED_ACCEPTANCE;
   else
      machine.state = LTF_SWEEP_ONLY;

   int latestShift = 1;
   double open1 = iOpen(runtimeSymbol, InpSignalTimeframe, latestShift);
   double high1 = iHigh(runtimeSymbol, InpSignalTimeframe, latestShift);
   double low1 = iLow(runtimeSymbol, InpSignalTimeframe, latestShift);
   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, latestShift);
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;

   machine.reclaimClose = close1;
   machine.reclaimLow = low1;
   machine.closeLocation = CloseLocation(high1, low1, close1);
   machine.reclaimConfirmed = (machine.failedAcceptance &&
                               close1 < ctx.referenceLevelLow - reclaimBufferPrice &&
                               close1 < open1);
   if(machine.reclaimConfirmed)
      machine.state = LTF_RECLAIM_CONFIRMED;

   machine.lowerHighPrice = 0.0;
   machine.lowerHighFormed = false;
   if(machine.latestHigh.valid &&
      machine.latestHigh.shift <= 4 &&
      machine.latestHigh.shift < machine.sweepShift &&
      machine.latestHigh.price < machine.sweepHigh &&
      machine.latestHigh.price < ctx.referenceLevelHigh + sweepFloorPrice)
     {
      machine.lowerHighFormed = true;
      machine.lowerHighPrice = machine.latestHigh.price;
      machine.state = LTF_LOWER_HIGH_FORMED;
     }

   machine.breakdownLevel = MathMin(iLow(runtimeSymbol, InpSignalTimeframe, machine.sweepShift), machine.reclaimLow);
   if(machine.previousLow.valid && machine.previousLow.shift <= 6 && machine.previousLow.shift < machine.sweepShift)
      machine.breakdownLevel = MathMin(machine.breakdownLevel, machine.previousLow.price);

   machine.breakdownConfirmed = (close1 < machine.breakdownLevel - confirmBreakPrice);
   if(machine.breakdownConfirmed)
      machine.state = LTF_BREAKDOWN_CONFIRMED;

   machine.retestLevel = machine.breakdownLevel;
   machine.retestHigh = high1;
   machine.retestFailure = false;
   if(machine.sweepShift >= 2)
     {
      double prevClose = iClose(runtimeSymbol, InpSignalTimeframe, 2);
      double prevLow = iLow(runtimeSymbol, InpSignalTimeframe, 2);
      if(prevClose < machine.breakdownLevel - confirmBreakPrice &&
         high1 >= machine.breakdownLevel - retestTolerancePrice &&
         close1 < machine.breakdownLevel - confirmBreakPrice &&
         close1 < open1 &&
         prevLow < machine.breakdownLevel - confirmBreakPrice)
        {
         machine.retestFailure = true;
         machine.state = LTF_RETEST_FAILURE;
        }
     }

   int swingShift = iLowest(runtimeSymbol, InpSignalTimeframe, MODE_LOW, InpTargetSwingLookbackBars, 2);
   machine.targetSwingLow = (swingShift >= 0) ? iLow(runtimeSymbol, InpSignalTimeframe, swingShift) : low1;

   machine.failurePivotHigh = machine.latestHigh.valid && machine.latestHigh.shift <= 4
                              ? machine.latestHigh.price
                              : MathMax(high1, machine.sweepHigh);

   machine.failureType = machine.retestFailure ? "retest_failure"
                        : machine.breakdownConfirmed ? "breakdown_after_failure"
                        : machine.reclaimConfirmed ? "reclaim_failure"
                        : machine.failedAcceptance ? "failed_acceptance"
                        : "sweep_only";
   machine.stateLabel = LtfStateLabel(machine.state);
   machine.structureLabel = machine.stateLabel;
   machine.valid = true;
   return true;
  }

EntryType SelectEntryType(const LtfStateMachine &machine)
  {
   if(machine.retestFailure)
      return ENTRY_ON_RETEST_FAILURE;
   if(machine.lowerHighFormed && machine.breakdownConfirmed)
      return ENTRY_ON_LOWER_HIGH_BREAKDOWN;
   if(machine.reclaimConfirmed)
      return ENTRY_ON_RECLAIM_FAILURE;
   return ENTRY_NONE;
  }

void FillFailureSetup(const HtfPhaseContext &ctx,
                      const LtfStateMachine &machine,
                      const string tier,
                      const double fibRatio,
                      FailureSetup &setup)
  {
   setup.valid = true;
   setup.tier = tier;
   setup.entryType = SelectEntryType(machine);
   setup.entryTypeLabel = EntryTypeLabel(setup.entryType);
   setup.contextBucket = ctx.contextBucket;
   setup.phaseLabel = ctx.phaseLabel;
   setup.waveLabel = ctx.waveLabel;
   setup.fibDepthBucket = ctx.fibDepthBucket;
   setup.ltfStateLabel = machine.stateLabel;
   setup.failureType = machine.failureType;
   setup.stopBasis = (InpStopBasisMode == STOP_SWEEP_HIGH) ? "sweep_high" : "failure_pivot";
   setup.targetType = "pending";
   setup.volatilityBucket = machine.volatilityBucket;
   setup.referenceLevelHigh = ctx.referenceLevelHigh;
   setup.referenceLevelLow = ctx.referenceLevelLow;
   setup.fib382 = ctx.fib382;
   setup.fib50 = ctx.fib50;
   setup.fib618 = ctx.fib618;
   setup.activeWaveRetracement = fibRatio;
   setup.sweepHigh = machine.sweepHigh;
   setup.failurePivotHigh = machine.failurePivotHigh;
   setup.breakdownLevel = machine.breakdownLevel;
   setup.targetSwingLow = machine.targetSwingLow;
   setup.invalidationLevel = ctx.referenceLevelHigh + PipsToPrice(InpAcceptanceExitBufferPips);
   setup.sweepSizePips = machine.sweepSizePips;
   setup.ltfAtrPips = machine.ltfAtrPips;
   setup.setupTime = iTime(runtimeSymbol, InpSignalTimeframe, 1);
  }

bool EvaluateTierA(const HtfPhaseContext &ctx, const LtfStateMachine &machine, FailureSetup &setup)
  {
   setup.valid = false;
   if(!ctx.tierAEligible)
      return false;
   if(!(ctx.phase == HTF_UP_EXHAUSTION || ctx.phase == HTF_RANGE_TOP))
      return false;
   if(machine.sweepSizePips < InpTierAMinSweepPips)
      return false;
   if(machine.closeLocation > InpTierAMaxCloseLocation)
      return false;
   if(!(machine.state == LTF_BREAKDOWN_CONFIRMED || machine.state == LTF_RETEST_FAILURE))
      return false;

   double fibRatio = 0.0;
   if(!PassFibEntryFilter(ctx, machine.reclaimClose, true, fibRatio))
      return false;

   FillFailureSetup(ctx, machine, "tier_a", fibRatio, setup);
   return (setup.entryType != ENTRY_NONE);
  }

bool EvaluateTierB(const HtfPhaseContext &ctx, const LtfStateMachine &machine, FailureSetup &setup)
  {
   setup.valid = false;
   if(InpTierMode != ENTRY_TIER_A_AND_B)
      return false;
   if(!ctx.tierBEligible)
      return false;
   if(!(ctx.phase == HTF_UP_PULLBACK || ctx.phase == HTF_UP_EXHAUSTION || ctx.phase == HTF_RANGE_TOP))
      return false;
   if(machine.sweepSizePips < InpTierBMinSweepPips)
      return false;
   if(machine.closeLocation > InpTierBMaxCloseLocation)
      return false;
   if(!(machine.state == LTF_RECLAIM_CONFIRMED || machine.state == LTF_BREAKDOWN_CONFIRMED || machine.state == LTF_RETEST_FAILURE))
      return false;

   double fibRatio = 0.0;
   if(!PassFibEntryFilter(ctx, machine.reclaimClose, false, fibRatio))
      return false;

   FillFailureSetup(ctx, machine, "tier_b", fibRatio, setup);
   return (setup.entryType != ENTRY_NONE);
  }

bool DetectFailedBreakoutState(const HtfPhaseContext &ctx, FailureSetup &setup)
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

double SelectPreferredFibTarget(const FailureSetup &setup, double entryPrice)
  {
   double frontRun = PipsToPrice(InpTargetFrontRunPips);
   double candidates[3];
   candidates[0] = setup.fib382 + frontRun;
   candidates[1] = setup.fib50 + frontRun;
   candidates[2] = setup.fib618 + frontRun;

   int preferredIndex = 1;
   if(InpFibTargetLevel == FIB_TARGET_382)
      preferredIndex = 0;
   else if(InpFibTargetLevel == FIB_TARGET_618)
      preferredIndex = 2;

   if(candidates[preferredIndex] < entryPrice)
      return candidates[preferredIndex];

   for(int i = 0; i < 3; ++i)
     {
      if(candidates[i] < entryPrice)
         return candidates[i];
     }

   return 0.0;
  }

bool BuildEntryPlan(const FailureSetup &setup, EntryPlan &plan)
  {
   ResetEntryPlan(plan);
   if(!setup.valid)
      return false;

   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;

   double stopBufferPrice = MathMax(PipsToPrice(InpMinStopBufferPips),
                                    PipsToPrice(setup.ltfAtrPips * InpStopBufferATR));
   double stopAnchor = (InpStopBasisMode == STOP_SWEEP_HIGH) ? setup.sweepHigh : setup.failurePivotHigh;
   double entry = NormalizePrice(bid);
   double stop = NormalizePrice(stopAnchor + stopBufferPrice);
   if(stop <= entry)
      return false;

   double risk = stop - entry;
   double target = 0.0;
   double partialTarget = 0.0;
   bool usePartial = false;
   string targetType = "";

   if(InpTargetMode == TARGET_PRIOR_SWING)
     {
      target = NormalizePrice(setup.targetSwingLow + PipsToPrice(InpTargetFrontRunPips));
      targetType = "prior_swing";
      if(target >= entry)
        {
         target = NormalizePrice(entry - risk * InpTargetRMultiple);
         targetType = "prior_swing_fallback_r";
        }
     }
   else if(InpTargetMode == TARGET_FIXED_R)
     {
      target = NormalizePrice(entry - risk * InpTargetRMultiple);
      targetType = "fixed_r";
     }
   else if(InpTargetMode == TARGET_FIB)
     {
      target = NormalizePrice(SelectPreferredFibTarget(setup, entry));
      targetType = "fib";
      if(target <= 0.0 || target >= entry)
        {
         target = NormalizePrice(entry - risk * InpTargetRMultiple);
         targetType = "fib_fallback_r";
        }
     }
   else
     {
      partialTarget = NormalizePrice(SelectPreferredFibTarget(setup, entry));
      target = NormalizePrice(setup.targetSwingLow + PipsToPrice(InpTargetFrontRunPips));
      usePartial = (partialTarget > 0.0 && partialTarget < entry && target < entry);
      targetType = "hybrid_partial";
      if(!usePartial)
        {
         partialTarget = 0.0;
         target = NormalizePrice(entry - risk * InpTargetRMultiple);
         targetType = "hybrid_fallback_r";
        }
     }

   if(target >= entry)
      return false;
   if(usePartial && partialTarget >= entry)
      return false;

   plan.valid = true;
   plan.direction = -1;
   plan.tier = setup.tier;
   plan.entryType = setup.entryType;
   plan.entryTypeLabel = setup.entryTypeLabel;
   plan.contextBucket = setup.contextBucket;
   plan.phaseLabel = setup.phaseLabel;
   plan.waveLabel = setup.waveLabel;
   plan.fibDepthBucket = setup.fibDepthBucket;
   plan.ltfStateLabel = setup.ltfStateLabel;
   plan.failureType = setup.failureType;
   plan.stopBasis = setup.stopBasis;
   plan.targetType = targetType;
   plan.volatilityBucket = setup.volatilityBucket;
   plan.referenceLevelHigh = setup.referenceLevelHigh;
   plan.activeWaveRetracement = setup.activeWaveRetracement;
   plan.sweepSizePips = setup.sweepSizePips;
   plan.ltfAtrPips = setup.ltfAtrPips;
   plan.invalidationLevel = setup.invalidationLevel;
   plan.entry = entry;
   plan.stop = stop;
   plan.target = target;
   plan.partialTarget = partialTarget;
   plan.usePartial = usePartial;
   plan.stopDistancePips = risk / GetPipSize();
   plan.reason = "failed_breakout_" + setup.tier + "_" + setup.entryTypeLabel;
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
                "failure_type",
                "stop_basis",
                "target_type",
                "hour",
                "volatility_bucket",
                "reference_level",
                "active_wave_retracement",
                "sweep_size_pips",
                "ltf_atr_pips",
                "stop_distance_pips",
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

   FileSeek(telemetryHandle, 0, SEEK_END);
   FileWrite(telemetryHandle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             eventType,
             "short",
             (long)positionId,
             plan.tier,
             plan.entryTypeLabel,
             plan.phaseLabel,
             plan.waveLabel,
             plan.contextBucket,
             plan.fibDepthBucket,
             plan.ltfStateLabel,
             plan.failureType,
             plan.stopBasis,
             plan.targetType,
             tm.hour,
             plan.volatilityBucket,
             plan.referenceLevelHigh,
             plan.activeWaveRetracement,
             plan.sweepSizePips,
             plan.ltfAtrPips,
             plan.stopDistancePips,
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
      if(dealPrice >= activePlan.stop - pip * 0.2)
         return "stop_loss";
      if(!stillOpen && dealPrice <= activePlan.target + pip * 0.2)
         return "target";
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

   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   if(bid <= 0.0)
      return;

   double currentVolume = PositionGetDouble(POSITION_VOLUME);
   datetime openedAt = (datetime)PositionGetInteger(POSITION_TIME);
   int barsSinceEntry = iBarShift(runtimeSymbol, InpSignalTimeframe, openedAt, false);

   if(activePlan.usePartial && !activePartialTaken && activePlan.partialTarget > 0.0 && bid <= activePlan.partialTarget)
     {
      double closeVolume = 0.0;
      if(ComputePartialCloseVolume(currentVolume, closeVolume))
        {
         pendingExitReason = "hybrid_partial";
         pendingPartialExit = true;
         if(trade.PositionClosePartial(runtimeSymbol, closeVolume))
           {
            activePartialTaken = true;
            trade.PositionModify(runtimeSymbol, NormalizePrice(activePlan.entry), 0.0);
           }
         else
           {
            pendingExitReason = "";
            pendingPartialExit = false;
           }
        }
     }

   if(PositionSelect(runtimeSymbol) && (long)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
     {
      if(bid <= activePlan.target)
        {
         pendingExitReason = "target";
         trade.PositionClose(runtimeSymbol);
         return;
        }

      if(InpUseAcceptanceExit && iClose(runtimeSymbol, InpSignalTimeframe, 1) > activePlan.invalidationLevel)
        {
         pendingExitReason = "acceptance_back_above";
         trade.PositionClose(runtimeSymbol);
         return;
        }

      if(InpMaxHoldBars > 0 && barsSinceEntry >= InpMaxHoldBars && barsSinceEntry >= 0)
        {
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

   if(InpMagicNumber <= 0 || InpTrendPivotSpan <= 0 || InpSignalPivotSpan <= 0 ||
      InpTrendATRPeriod <= 0 || InpSignalATRPeriod <= 0 ||
      InpRiskPercent <= 0.0 || InpTargetRMultiple <= 0.0 ||
      InpTierARangePosMin < 0.0 || InpTierBRangePosMin < 0.0 ||
      InpFibEntryMinRatio < 0.0 || InpFibEntryMaxRatio < InpFibEntryMinRatio)
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
         activePartialTaken = false;
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
         string eventType = (pendingPartialExit || stillOpen) ? "partial_exit" : "exit";
         string outcome = "flat";
         if(profit > 0.0)
            outcome = "win";
         else if(profit < 0.0)
            outcome = "loss";

         string reason = InferExitReason(price, stillOpen);
         LogTelemetry(eventType, activePlan, positionId, price, volume, profit, outcome, reason);
         pendingExitReason = "";
         pendingPartialExit = false;

         if(!stillOpen)
           {
            ResetEntryPlan(activePlan);
            activePartialTaken = false;
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

   FailureSetup setup;
   if(!DetectFailedBreakoutState(ctx, setup))
      return;

   EntryPlan plan;
   if(!BuildEntryPlan(setup, plan))
      return;

   double volume = CalculateVolumeByRisk(plan.entry, plan.stop);
   if(volume <= 0.0)
      return;

   ResetEntryPlan(pendingPlan);
   pendingPlan = plan;
   hasPendingPlan = false;

   if(trade.Sell(volume, runtimeSymbol, 0.0, plan.stop, 0.0, plan.reason))
     {
      pendingPlan = plan;
      hasPendingPlan = true;
     }
   else
     {
      ResetEntryPlan(pendingPlan);
     }
  }
