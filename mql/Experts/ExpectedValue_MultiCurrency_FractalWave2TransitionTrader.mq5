//+------------------------------------------------------------------+
//| ExpectedValue_MultiCurrency_FractalWave2TransitionTrader         |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Standalone multi-currency M15 wave2 / M5 trend-transition research EA."

#include <Trade\Trade.mqh>

CTrade trade;

static const string STRATEGY_NAME = "ExpectedValue_MultiCurrency_FractalWave2TransitionTrader";

enum ENUM_RESEARCH_RUN_MODE
  {
   RUN_PARENT_FLIP_DIAGNOSTIC = 0,
   RUN_PARENT_WAVE2_DIAGNOSTIC = 1,
   RUN_CHILD_COUNTERTREND_DIAGNOSTIC = 2,
   RUN_CHILD_FLIP_DIAGNOSTIC = 3,
   RUN_TRADE_FIRST_CHILD_FLIP = 4
  };

enum ENUM_STOP_MODE
  {
   STOP_CHILD_WAVE_EXTREME = 0,
   STOP_PARENT_WAVE2_EXTREME = 1
  };

enum ENUM_PORTFOLIO_MODE
  {
   PORTFOLIO_ALL_SYMBOLS = 0,
   PORTFOLIO_ONE_SYMBOL_PER_BAR = 1
  };

enum ENUM_PARENT_WAVE2_START_MODE
  {
   WAVE2_START_FIRST_OPPOSITE_CLOSE = 0,
   WAVE2_START_CONFIRMED_OPPOSITE_PIVOT = 1,
   WAVE2_START_CHILD_COUNTERTREND = 2,
   WAVE2_START_DIAGNOSTIC_ONLY = 3
  };

enum ENUM_CHILD_ANCHOR_MODE
  {
   CHILD_ANCHOR_LEGACY_FIRST = 0,
   CHILD_ANCHOR_LATEST_VALID = 1
  };

enum ENUM_STRATEGY_STATE
  {
   STATE_IDLE = 0,
   STATE_PARENT_FLIP_DETECTED = 1,
   STATE_PARENT_WAVE1_CONFIRMED = 2,
   STATE_PARENT_WAVE2_PENDING = 3,
   STATE_PARENT_WAVE2_ACTIVE = 4,
   STATE_CHILD_COUNTER_TREND_CONFIRMED = 5,
   STATE_CHILD_TREND_FLIPPED = 6,
   STATE_SIGNAL_RESERVED = 7,
   STATE_SIGNAL_CONSUMED = 8,
   STATE_INVALIDATED = 9,
   STATE_EXPIRED = 10
  };

struct PivotPoint
  {
   datetime          time;
   datetime          confirmedTime;
   double            price;
   int               kind;
   int               shift;
  };

struct ChildAnchorCandidate
  {
   double            price;
   datetime          time;
   datetime          confirmedTime;
   double            extreme;
   int               swingCount;
   int               extensionCount;
  };

struct SymbolState
  {
   string            symbol;
   datetime          lastM5Bar;
   ENUM_STRATEGY_STATE strategyState;
   ENUM_STRATEGY_STATE previousState;
   datetime          stateChangedAt;
   string            stateChangeReason;
   string            parentEventId;
   int               parentDirection;
   string            parentBiasBeforeFlip;
   string            parentBiasAfterFlip;
   string            parentAnchorType;
   double            parentAnchorPrice;
   datetime          parentAnchorTime;
   datetime          parentStructureConfirmedTime;
   datetime          parentFirstBreakTime;
   double            parentFirstBreakPrice;
   datetime          parentWave1StartTime;
   datetime          parentWave1EndTime;
   double            parentWave1StartPrice;
   double            parentWave1EndPrice;
   double            parentWave1RangeAtr;
   bool              parentWave1Valid;
   string            parentWave1InvalidReason;
   bool              parentWave2Active;
   bool              parentWave2Pending;
   datetime          parentWave2StartTime;
   datetime          parentWave2FirstOppositeCloseTime;
   datetime          parentWave2ConfirmedPivotTime;
   datetime          parentWave2ChildCountertrendStartTime;
   datetime          parentWave2SelectedStartTime;
   int               parentWave2StartDelayBars;
   string            parentWave2StartReason;
   int               parentWave2Direction;
   int               parentWave2AgeBars;
   double            parentWave2InvalidationPrice;
   double            parentWave2Extreme;
   bool              parentWave2Invalidated;
   string            parentWave2InvalidReason;
   string            childTrendState;
   bool              childTrendAlignedWithWave2;
   double            childActiveOshiyasu;
   datetime          childActiveOshiyasuTime;
   double            childActiveModoritakane;
   datetime          childActiveModoritakaneTime;
   double            childCorrectionExtreme;
   datetime          childAnchorConfirmedTime;
   datetime          childStructureFirstDetectedTime;
   datetime          childStructureLatestUpdateTime;
   int               childAnchorUpdateCount;
   int               childAnchorVersion;
   double            childFirstAnchorPrice;
   datetime          childFirstAnchorTime;
   double            childLatestAnchorPrice;
   datetime          childLatestAnchorTime;
   bool              childAnchorChangedAfterInitialDetection;
   double            childAnchorUsedForFlip;
   bool              childAnchorIsLatestValid;
   bool              childTrendInvalidatedBeforeFlip;
   double            childTrendRangeAfterDetection;
   int               childSwingCount;
   int               childExtensionCount;
   int               childAnchorCount;
   bool              childCountertrendConfirmed;
   bool              childCountertrendValidAtEntry;
   string            childCountertrendRejectReason;
   bool              childTrendFlipDetected;
   int               childTrendFlipDirection;
   datetime          childTrendFlipTime;
   double            childTrendFlipLevel;
   double            childTrendFlipClose;
   double            childTrendFlipAtr;
   string            childTrendFlipEventId;
   int               childFlipAnchorVersion;
   bool              childFlipIsFirstBreakAfterAnchor;
   int               childFlipSignalAgeBars;
   bool              childFlipIsFresh;
   bool              childFlipEventConsumed;
   bool              signalConsumed;
   bool              signalReserved;
   datetime          signalReservedTime;
   bool              signalValidationPass;
   string            signalValidationRejectReason;
   bool              signalReservedBeforePortfolio;
   string            signalNotTradedReason;
   string            signalConsumptionStage;
   string            consumedFlipEventId;
   bool              signalReusedBlocked;
   bool              signalExpired;
  };

struct EntryCandidate
  {
   bool              valid;
   int               stateIndex;
   string            symbol;
   int               direction;
   double            entryPrice;
   double            stopLoss;
   double            takeProfit;
   double            riskPrice;
   double            atr;
   double            score;
   string            parentEventId;
   string            childFlipEventId;
   int               signalAgeBars;
   int               parentWave2Age;
   string            childTrendBeforeFlip;
   string            entryReason;
   string            entryRejectReason;
   int               parentWave2StartMode;
   string            parentWave2StartReason;
   int               parentWave2StartDelayBars;
   int               childAnchorVersion;
   int               childAnchorUpdateCount;
   double            childFirstAnchorPrice;
   double            childLatestAnchorPrice;
   double            childAnchorUsedForFlip;
   bool              childAnchorIsLatestValid;
   bool              childAnchorChangedAfterInitialDetection;
   int               childSwingCount;
   int               childExtensionCount;
   bool              childCountertrendValidAtEntry;
   string            childCountertrendRejectReason;
   bool              childFlipIsFirstBreakAfterAnchor;
   bool              childFlipIsFresh;
   bool              signalValidationPass;
   string            signalValidationRejectReason;
   bool              signalReservedBeforePortfolio;
   string            signalConsumptionStage;
   string            h1BiasState;
   bool              h1Alignment;
   string            h4BiasState;
   bool              h4Alignment;
   int               fractalAlignmentCount;
   bool              fullFractalAlignment;
   string            sessionLabel;
   int               utcHour;
   int               weekday;
  };

struct TrackedTrade
  {
   bool              active;
   long              positionId;
   string            symbol;
   int               direction;
   datetime          entryTime;
   double            entryPrice;
   double            initialStop;
   double            takeProfit;
   double            riskPrice;
   double            volume;
   double            atr;
   double            maxFavorableR;
   double            maxAdverseR;
   bool              reached05R;
   bool              reached08R;
   bool              reached10R;
   bool              reached13R;
   int               barsTo05R;
   int               barsTo10R;
   int               barsTo13R;
   bool              timeExitRequested;
   string            parentEventId;
   string            childFlipEventId;
   int               signalAgeBars;
   int               parentWave2Age;
   string            childTrendBeforeFlip;
   int               parentWave2StartMode;
   string            parentWave2StartReason;
   int               parentWave2StartDelayBars;
   int               childAnchorVersion;
   int               childAnchorUpdateCount;
   double            childFirstAnchorPrice;
   double            childLatestAnchorPrice;
   double            childAnchorUsedForFlip;
   bool              childAnchorIsLatestValid;
   bool              childAnchorChangedAfterInitialDetection;
   int               childSwingCount;
   int               childExtensionCount;
   bool              childCountertrendValidAtEntry;
   string            childCountertrendRejectReason;
   bool              childFlipIsFirstBreakAfterAnchor;
   bool              childFlipIsFresh;
   bool              signalValidationPass;
   string            signalValidationRejectReason;
   bool              signalReservedBeforePortfolio;
   string            signalConsumptionStage;
   string            h1BiasState;
   bool              h1Alignment;
   string            h4BiasState;
   bool              h4Alignment;
   int               fractalAlignmentCount;
   bool              fullFractalAlignment;
   string            sessionLabel;
   int               utcHour;
   int               weekday;
  };

struct ReasonCounter
  {
   string            reason;
   long              count;
  };

input string          InpSymbols = "USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD";
input ENUM_TIMEFRAMES InpTopContextTF = PERIOD_H1;
input ENUM_TIMEFRAMES InpParentTF = PERIOD_M15;
input ENUM_TIMEFRAMES InpChildTF = PERIOD_M5;
input ENUM_RESEARCH_RUN_MODE InpRunMode = RUN_TRADE_FIRST_CHILD_FLIP;
input ENUM_STOP_MODE InpStopMode = STOP_CHILD_WAVE_EXTREME;
input ENUM_PORTFOLIO_MODE InpPortfolioMode = PORTFOLIO_ALL_SYMBOLS;
input ENUM_PARENT_WAVE2_START_MODE InpParentWave2StartMode = WAVE2_START_CHILD_COUNTERTREND;
input ENUM_CHILD_ANCHOR_MODE InpChildAnchorMode = CHILD_ANCHOR_LATEST_VALID;
input bool            InpLegacyCurrentCodeDiagnostic = false;
input int             InpPivotDepth = 2;
input int             InpATRPeriod = 14;
input int             InpParentLookbackBars = 160;
input int             InpChildLookbackBars = 240;
input int             InpParentWave1MaxBars = 32;
input int             InpParentWave2MaxBars = 48;
input int             InpChildStructureMaxAgeBars = 144;
input bool            InpParentWave2InvalidationUseClose = true;
input bool            InpEntryOnFirstChildTrendFlip = true;
input int             InpChildFlipMaxSignalAgeBars = 1;
input bool            InpRequireChildTrendBeforeFlip = true;
input bool            InpOneEntryPerParentWave2 = true;
input bool            InpConsumeSignalBeforePortfolioSelection = true;
input double          InpTargetR = 1.30;
input int             InpMaxHoldBars = 30;
input double          InpRiskPerTradePercent = 0.25;
input double          InpMaxTotalOpenRiskPercent = 2.50;
input double          InpMaxRiskPerSymbolPercent = 0.50;
input int             InpMaxPositions = 6;
input double          InpDailyMaxLossPercent = 3.00;
input double          InpMaxDrawdownPercent = 15.00;
input double          InpMaxSpreadATR = 0.20;
input double          InpStopBufferATR = 0.10;
input double          InpFixedLotFallback = 0.01;
input double          InpMaxLotCap = 1.00;
input int             InpSlippagePoints = 20;
input int             InpBrokerUtcOffsetHours = 3;
input long            InpMagicNumber = 2026071101;
input bool            InpUseCommonFiles = true;
input string          InpLogFolder = "fractal_wave2_transition";
input string          InpRunId = "base";

string        g_symbols[];
SymbolState   g_states[];
TrackedTrade  g_trades[];
ReasonCounter g_rejections[];
string        g_parentFlipKeys[];
string        g_wave1Keys[];
string        g_wave2Keys[];
string        g_wave2PendingKeys[];
string        g_invalidatedWave2Keys[];
string        g_childTrendKeys[];
string        g_childAnchorKeys[];
string        g_childFlipKeys[];
string        g_firstSignalKeys[];
string        g_validCandidateKeys[];
string        g_invalidCandidateKeys[];
string        g_reservedSignalKeys[];
string        g_consumedSignalKeys[];
string        g_expiredSignalKeys[];
long          g_symbolsScanned = 0;
long          g_parentFlipsDetected = 0;
long          g_validParentWave1 = 0;
long          g_parentWave2Started = 0;
long          g_parentWave2Pending = 0;
long          g_parentWave2StartedFirstClose = 0;
long          g_parentWave2StartedConfirmedPivot = 0;
long          g_parentWave2StartedChildTrend = 0;
long          g_parentWave2Invalidated = 0;
long          g_childCountertrendConfirmed = 0;
long          g_childAnchorsCreated = 0;
long          g_childAnchorsUpdated = 0;
long          g_childTrendFlipsDetected = 0;
long          g_firstFlipSignals = 0;
long          g_freshFirstFlipSignals = 0;
long          g_validCandidates = 0;
long          g_candidateInvalid = 0;
long          g_signalsReserved = 0;
long          g_portfolioSelected = 0;
long          g_positionCapReject = 0;
long          g_riskReject = 0;
long          g_orderFailure = 0;
long          g_signalsConsumed = 0;
long          g_tradesTaken = 0;
long          g_expiredSignals = 0;
double        g_initialEquity = 0.0;
double        g_peakEquity = 0.0;
double        g_dayStartEquity = 0.0;
int           g_dayKey = 0;
bool          g_dailyStopped = false;
bool          g_drawdownStopped = false;

string BoolText(const bool value)
  {
   return value ? "true" : "false";
  }

string DirectionText(const int direction)
  {
   if(direction > 0)
      return "LONG";
   if(direction < 0)
      return "SHORT";
   return "NONE";
  }

string StateName(const ENUM_STRATEGY_STATE state)
  {
   if(state == STATE_PARENT_FLIP_DETECTED) return "PARENT_FLIP_DETECTED";
   if(state == STATE_PARENT_WAVE1_CONFIRMED) return "PARENT_WAVE1_CONFIRMED";
   if(state == STATE_PARENT_WAVE2_PENDING) return "PARENT_WAVE2_PENDING";
   if(state == STATE_PARENT_WAVE2_ACTIVE) return "PARENT_WAVE2_ACTIVE";
   if(state == STATE_CHILD_COUNTER_TREND_CONFIRMED) return "CHILD_COUNTER_TREND_CONFIRMED";
   if(state == STATE_CHILD_TREND_FLIPPED) return "CHILD_TREND_FLIPPED";
   if(state == STATE_SIGNAL_RESERVED) return "SIGNAL_RESERVED";
   if(state == STATE_SIGNAL_CONSUMED) return "SIGNAL_CONSUMED";
   if(state == STATE_INVALIDATED) return "INVALIDATED";
   if(state == STATE_EXPIRED) return "EXPIRED";
   return "IDLE";
  }

string StopModeName()
  {
   return InpStopMode == STOP_PARENT_WAVE2_EXTREME ? "parent_wave2_extreme" : "child_wave_extreme";
  }

string ParentWave2StartModeName()
  {
   if(InpParentWave2StartMode == WAVE2_START_CONFIRMED_OPPOSITE_PIVOT)
      return "confirmed_opposite_pivot";
   if(InpParentWave2StartMode == WAVE2_START_CHILD_COUNTERTREND)
      return "child_countertrend_started";
   if(InpParentWave2StartMode == WAVE2_START_DIAGNOSTIC_ONLY)
      return "diagnostic_only";
   return "first_opposite_close";
  }

string ChildAnchorModeName()
  {
   return InpChildAnchorMode == CHILD_ANCHOR_LATEST_VALID ? "latest_valid" : "legacy_first";
  }

string RunModeName()
  {
   if(InpRunMode == RUN_PARENT_FLIP_DIAGNOSTIC) return "parent_flip_only_diagnostic";
   if(InpRunMode == RUN_PARENT_WAVE2_DIAGNOSTIC) return "parent_wave1_wave2_diagnostic";
   if(InpRunMode == RUN_CHILD_COUNTERTREND_DIAGNOSTIC) return "child_countertrend_diagnostic";
   if(InpRunMode == RUN_CHILD_FLIP_DIAGNOSTIC) return "child_flip_diagnostic";
   return "base_first_child_flip";
  }

string TFName(const ENUM_TIMEFRAMES tf)
  {
   return EnumToString(tf);
  }

void CsvAppend(string &line, const string value)
  {
   string escaped = value;
   StringReplace(escaped, "\"", "\"\"");
   if(line != "")
      line += ",";
   line += "\"" + escaped + "\"";
  }

int LogFlags()
  {
   int flags = FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_SHARE_WRITE;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;
   return flags;
  }

void EnsureLogFolder()
  {
   FolderCreate(InpLogFolder, InpUseCommonFiles ? FILE_COMMON : 0);
  }

string LogFileName(const string suffix)
  {
   return InpLogFolder + "\\fw2t_" + InpRunId + "_" + suffix + ".csv";
  }

bool HasKey(const string &keys[], const string key)
  {
   for(int i = 0; i < ArraySize(keys); ++i)
      if(keys[i] == key)
         return true;
   return false;
  }

bool AddUniqueKey(string &keys[], const string key)
  {
   if(key == "" || HasKey(keys, key))
      return false;
   int size = ArraySize(keys);
   ArrayResize(keys, size + 1);
   keys[size] = key;
   return true;
  }

void AddRejection(const string reason)
  {
   string key = reason == "" ? "unknown" : reason;
   for(int i = 0; i < ArraySize(g_rejections); ++i)
     {
      if(g_rejections[i].reason == key)
        {
         ++g_rejections[i].count;
         return;
        }
     }
   int size = ArraySize(g_rejections);
   ArrayResize(g_rejections, size + 1);
   g_rejections[size].reason = key;
   g_rejections[size].count = 1;
  }

bool CopyClosedRates(const string symbol,
                     const ENUM_TIMEFRAMES tf,
                     const int bars,
                     MqlRates &rates[])
  {
   ArraySetAsSeries(rates, true);
   return CopyRates(symbol, tf, 1, bars, rates) >= bars;
  }

double ATR(const MqlRates &rates[], const int shift, const int period)
  {
   if(period <= 0 || shift < 0 || shift + period + 1 > ArraySize(rates))
      return 0.0;
   double sum = 0.0;
   for(int i = shift; i < shift + period; ++i)
     {
      double prevClose = rates[i + 1].close;
      double tr = MathMax(rates[i].high - rates[i].low,
                          MathMax(MathAbs(rates[i].high - prevClose),
                                  MathAbs(rates[i].low - prevClose)));
      sum += tr;
     }
   return sum / period;
  }

bool IsConfirmedPivot(const MqlRates &rates[], const int shift, const bool high, const int depth)
  {
   if(shift - depth < 0 || shift + depth >= ArraySize(rates))
      return false;
   double price = high ? rates[shift].high : rates[shift].low;
   for(int i = 1; i <= depth; ++i)
     {
      if(high && (price <= rates[shift - i].high || price <= rates[shift + i].high))
         return false;
      if(!high && (price >= rates[shift - i].low || price >= rates[shift + i].low))
         return false;
     }
   return true;
  }

void AppendPivot(PivotPoint &pivots[], const PivotPoint &pivot)
  {
   int size = ArraySize(pivots);
   if(size == 0)
     {
      ArrayResize(pivots, 1);
      pivots[0] = pivot;
      return;
     }
   if(pivots[size - 1].kind == pivot.kind)
     {
      bool extreme = pivot.kind > 0 ? pivot.price > pivots[size - 1].price :
                                      pivot.price < pivots[size - 1].price;
      if(extreme)
         pivots[size - 1] = pivot;
      return;
     }
   ArrayResize(pivots, size + 1);
   pivots[size] = pivot;
  }

bool BuildPivots(const string symbol,
                 const ENUM_TIMEFRAMES tf,
                 const int lookback,
                 MqlRates &rates[],
                 PivotPoint &pivots[],
                 double &atr)
  {
   int bars = MathMax(lookback + InpPivotDepth + 8, InpATRPeriod + InpPivotDepth * 2 + 12);
   if(!CopyClosedRates(symbol, tf, bars, rates))
      return false;
   atr = ATR(rates, 0, InpATRPeriod);
   if(atr <= 0.0)
      return false;
   ArrayResize(pivots, 0);
   int maxShift = MathMin(ArraySize(rates) - InpPivotDepth - 1, lookback);
   for(int shift = maxShift; shift >= InpPivotDepth; --shift)
     {
      if(IsConfirmedPivot(rates, shift, true, InpPivotDepth))
        {
         PivotPoint p;
         p.time = rates[shift].time;
         p.confirmedTime = rates[shift - InpPivotDepth].time;
         p.price = rates[shift].high; p.kind = 1; p.shift = shift;
         AppendPivot(pivots, p);
        }
      if(IsConfirmedPivot(rates, shift, false, InpPivotDepth))
        {
         PivotPoint p;
         p.time = rates[shift].time;
         p.confirmedTime = rates[shift - InpPivotDepth].time;
         p.price = rates[shift].low; p.kind = -1; p.shift = shift;
         AppendPivot(pivots, p);
        }
     }
   return ArraySize(pivots) >= 3;
  }

int BarsBetween(const string symbol,
                const ENUM_TIMEFRAMES tf,
                const datetime older,
                const datetime newer)
  {
   if(older <= 0 || newer < older)
      return -1;
   int olderShift = iBarShift(symbol, tf, older, false);
   int newerShift = iBarShift(symbol, tf, newer, false);
   if(olderShift < 0 || newerShift < 0)
      return -1;
   return MathMax(0, olderShift - newerShift);
  }

string EventId(const string symbol,
               const string prefix,
               const int direction,
               const datetime time,
               const double level)
  {
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return symbol + "|" + prefix + "|" + DirectionText(direction) + "|" +
          IntegerToString((long)time) + "|" + DoubleToString(level, digits);
  }

void ResetState(SymbolState &state, const string symbol)
  {
   state.symbol = symbol;
   state.lastM5Bar = 0;
   state.strategyState = STATE_IDLE;
   state.previousState = STATE_IDLE;
   state.stateChangedAt = 0;
   state.stateChangeReason = "initialized";
   state.parentEventId = "";
   state.parentDirection = 0;
   state.parentBiasBeforeFlip = "unknown";
   state.parentBiasAfterFlip = "unknown";
   state.parentAnchorType = "none";
   state.parentAnchorPrice = 0.0;
   state.parentAnchorTime = 0;
   state.parentStructureConfirmedTime = 0;
   state.parentFirstBreakTime = 0;
   state.parentFirstBreakPrice = 0.0;
   state.parentWave1StartTime = 0;
   state.parentWave1EndTime = 0;
   state.parentWave1StartPrice = 0.0;
   state.parentWave1EndPrice = 0.0;
   state.parentWave1RangeAtr = 0.0;
   state.parentWave1Valid = false;
   state.parentWave1InvalidReason = "not_detected";
   state.parentWave2Active = false;
   state.parentWave2Pending = false;
   state.parentWave2StartTime = 0;
   state.parentWave2FirstOppositeCloseTime = 0;
   state.parentWave2ConfirmedPivotTime = 0;
   state.parentWave2ChildCountertrendStartTime = 0;
   state.parentWave2SelectedStartTime = 0;
   state.parentWave2StartDelayBars = -1;
   state.parentWave2StartReason = "not_detected";
   state.parentWave2Direction = 0;
   state.parentWave2AgeBars = -1;
   state.parentWave2InvalidationPrice = 0.0;
   state.parentWave2Extreme = 0.0;
   state.parentWave2Invalidated = false;
   state.parentWave2InvalidReason = "none";
   state.childTrendState = "unknown";
   state.childTrendAlignedWithWave2 = false;
   state.childActiveOshiyasu = 0.0;
   state.childActiveOshiyasuTime = 0;
   state.childActiveModoritakane = 0.0;
   state.childActiveModoritakaneTime = 0;
   state.childCorrectionExtreme = 0.0;
   state.childAnchorConfirmedTime = 0;
   state.childStructureFirstDetectedTime = 0;
   state.childStructureLatestUpdateTime = 0;
   state.childAnchorUpdateCount = 0;
   state.childAnchorVersion = 0;
   state.childFirstAnchorPrice = 0.0;
   state.childFirstAnchorTime = 0;
   state.childLatestAnchorPrice = 0.0;
   state.childLatestAnchorTime = 0;
   state.childAnchorChangedAfterInitialDetection = false;
   state.childAnchorUsedForFlip = 0.0;
   state.childAnchorIsLatestValid = false;
   state.childTrendInvalidatedBeforeFlip = false;
   state.childTrendRangeAfterDetection = 0.0;
   state.childSwingCount = 0;
   state.childExtensionCount = 0;
   state.childAnchorCount = 0;
   state.childCountertrendConfirmed = false;
   state.childCountertrendValidAtEntry = false;
   state.childCountertrendRejectReason = "no_confirmed_child_pivots";
   state.childTrendFlipDetected = false;
   state.childTrendFlipDirection = 0;
   state.childTrendFlipTime = 0;
   state.childTrendFlipLevel = 0.0;
   state.childTrendFlipClose = 0.0;
   state.childTrendFlipAtr = 0.0;
   state.childTrendFlipEventId = "";
   state.childFlipAnchorVersion = 0;
   state.childFlipIsFirstBreakAfterAnchor = false;
   state.childFlipSignalAgeBars = -1;
   state.childFlipIsFresh = false;
   state.childFlipEventConsumed = false;
   state.signalConsumed = false;
   state.signalReserved = false;
   state.signalReservedTime = 0;
   state.signalValidationPass = false;
   state.signalValidationRejectReason = "not_evaluated";
   state.signalReservedBeforePortfolio = false;
   state.signalNotTradedReason = "none";
   state.signalConsumptionStage = "none";
   state.consumedFlipEventId = "";
   state.signalReusedBlocked = false;
   state.signalExpired = false;
  }

void WriteStateEvent(const SymbolState &state, const string eventName)
  {
   EnsureLogFolder();
   int handle = FileOpen(LogFileName("events"), LogFlags(), ',');
   if(handle == INVALID_HANDLE)
      return;
   bool header = FileSize(handle) == 0;
   FileSeek(handle, 0, SEEK_END);
   if(header)
      FileWriteString(handle,
         "time,event,symbol,strategy_state,previous_strategy_state,state_changed_at,state_change_reason,parent_event_id,parent_direction,parent_bias_before_flip,parent_bias_after_flip,parent_anchor_type,parent_anchor_price,parent_anchor_time,parent_structure_confirmed_time,parent_first_break_time,parent_first_break_price,parent_wave1_start_time,parent_wave1_end_time,parent_wave1_start_price,parent_wave1_end_price,parent_wave1_range_atr,parent_wave1_valid,parent_wave1_invalid_reason,parent_wave2_active,parent_wave2_start_time,parent_wave2_direction,parent_wave2_age_bars,parent_wave2_invalidation_price,parent_wave2_extreme,parent_wave2_invalidated,parent_wave2_invalid_reason,child_trend_state,child_trend_aligned_with_wave2,child_active_oshiyasu,child_active_oshiyasu_time,child_active_modoritakane,child_active_modoritakane_time,child_anchor_confirmed_time,child_trend_flip_detected,child_trend_flip_direction,child_trend_flip_time,child_trend_flip_level,child_trend_flip_close,child_trend_flip_atr,child_trend_flip_event_id,entry_signal_age_bars,entry_signal_consumed,entry_signal_reused_blocked,parent_wave2_start_mode,parent_wave2_pending,parent_wave2_first_opposite_close_time,parent_wave2_confirmed_pivot_time,parent_wave2_child_countertrend_start_time,parent_wave2_selected_start_time,parent_wave2_start_delay_bars,parent_wave2_start_reason,child_structure_first_detected_time,child_structure_latest_update_time,child_anchor_update_count,child_anchor_version,child_first_anchor_price,child_first_anchor_time,child_latest_anchor_price,child_latest_anchor_time,child_anchor_changed_after_initial_detection,child_anchor_used_for_flip,child_anchor_is_latest_valid,child_trend_invalidated_before_flip,child_trend_range_after_detection,child_countertrend_confirmed,child_countertrend_direction,child_countertrend_swing_count,child_countertrend_extension_count,child_countertrend_anchor_count,child_countertrend_valid_at_entry,child_countertrend_reject_reason,child_flip_anchor_version,child_flip_is_first_break_after_anchor,child_flip_signal_age_bars,child_flip_is_fresh,child_flip_event_consumed,child_flip_reused_blocked,signal_validation_pass,signal_validation_reject_reason,signal_reserved_before_portfolio,signal_reserved_time,signal_not_traded_reason,signal_consumption_stage,child_anchor_mode,child_event_id\r\n");
   string line = "";
   CsvAppend(line, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
   CsvAppend(line, eventName);
   CsvAppend(line, state.symbol);
   CsvAppend(line, StateName(state.strategyState));
   CsvAppend(line, StateName(state.previousState));
   CsvAppend(line, state.stateChangedAt > 0 ? TimeToString(state.stateChangedAt, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, state.stateChangeReason);
   CsvAppend(line, state.parentEventId);
   CsvAppend(line, DirectionText(state.parentDirection));
   CsvAppend(line, state.parentBiasBeforeFlip);
   CsvAppend(line, state.parentBiasAfterFlip);
   CsvAppend(line, state.parentAnchorType);
   CsvAppend(line, DoubleToString(state.parentAnchorPrice, 8));
   CsvAppend(line, state.parentAnchorTime > 0 ? TimeToString(state.parentAnchorTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, state.parentStructureConfirmedTime > 0 ? TimeToString(state.parentStructureConfirmedTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, state.parentFirstBreakTime > 0 ? TimeToString(state.parentFirstBreakTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, DoubleToString(state.parentFirstBreakPrice, 8));
   CsvAppend(line, state.parentWave1StartTime > 0 ? TimeToString(state.parentWave1StartTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, state.parentWave1EndTime > 0 ? TimeToString(state.parentWave1EndTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, DoubleToString(state.parentWave1StartPrice, 8));
   CsvAppend(line, DoubleToString(state.parentWave1EndPrice, 8));
   CsvAppend(line, DoubleToString(state.parentWave1RangeAtr, 4));
   CsvAppend(line, BoolText(state.parentWave1Valid));
   CsvAppend(line, state.parentWave1InvalidReason);
   CsvAppend(line, BoolText(state.parentWave2Active));
   CsvAppend(line, state.parentWave2StartTime > 0 ? TimeToString(state.parentWave2StartTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, DirectionText(state.parentWave2Direction));
   CsvAppend(line, IntegerToString(state.parentWave2AgeBars));
   CsvAppend(line, DoubleToString(state.parentWave2InvalidationPrice, 8));
   CsvAppend(line, DoubleToString(state.parentWave2Extreme, 8));
   CsvAppend(line, BoolText(state.parentWave2Invalidated));
   CsvAppend(line, state.parentWave2InvalidReason);
   CsvAppend(line, state.childTrendState);
   CsvAppend(line, BoolText(state.childTrendAlignedWithWave2));
   CsvAppend(line, DoubleToString(state.childActiveOshiyasu, 8));
   CsvAppend(line, state.childActiveOshiyasuTime > 0 ? TimeToString(state.childActiveOshiyasuTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, DoubleToString(state.childActiveModoritakane, 8));
   CsvAppend(line, state.childActiveModoritakaneTime > 0 ? TimeToString(state.childActiveModoritakaneTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, state.childAnchorConfirmedTime > 0 ? TimeToString(state.childAnchorConfirmedTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, BoolText(state.childTrendFlipDetected));
   CsvAppend(line, DirectionText(state.childTrendFlipDirection));
   CsvAppend(line, state.childTrendFlipTime > 0 ? TimeToString(state.childTrendFlipTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, DoubleToString(state.childTrendFlipLevel, 8));
   CsvAppend(line, DoubleToString(state.childTrendFlipClose, 8));
   CsvAppend(line, DoubleToString(state.childTrendFlipAtr, 4));
   CsvAppend(line, state.childTrendFlipEventId);
   CsvAppend(line, IntegerToString(state.childFlipSignalAgeBars));
   CsvAppend(line, BoolText(state.signalConsumed));
   CsvAppend(line, BoolText(state.signalReusedBlocked));
   CsvAppend(line, IntegerToString((int)InpParentWave2StartMode));
   CsvAppend(line, BoolText(state.parentWave2Pending));
   CsvAppend(line, state.parentWave2FirstOppositeCloseTime > 0 ? TimeToString(state.parentWave2FirstOppositeCloseTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, state.parentWave2ConfirmedPivotTime > 0 ? TimeToString(state.parentWave2ConfirmedPivotTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, state.parentWave2ChildCountertrendStartTime > 0 ? TimeToString(state.parentWave2ChildCountertrendStartTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, state.parentWave2SelectedStartTime > 0 ? TimeToString(state.parentWave2SelectedStartTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, IntegerToString(state.parentWave2StartDelayBars));
   CsvAppend(line, state.parentWave2StartReason);
   CsvAppend(line, state.childStructureFirstDetectedTime > 0 ? TimeToString(state.childStructureFirstDetectedTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, state.childStructureLatestUpdateTime > 0 ? TimeToString(state.childStructureLatestUpdateTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, IntegerToString(state.childAnchorUpdateCount));
   CsvAppend(line, IntegerToString(state.childAnchorVersion));
   CsvAppend(line, DoubleToString(state.childFirstAnchorPrice, 8));
   CsvAppend(line, state.childFirstAnchorTime > 0 ? TimeToString(state.childFirstAnchorTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, DoubleToString(state.childLatestAnchorPrice, 8));
   CsvAppend(line, state.childLatestAnchorTime > 0 ? TimeToString(state.childLatestAnchorTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, BoolText(state.childAnchorChangedAfterInitialDetection));
   CsvAppend(line, DoubleToString(state.childAnchorUsedForFlip, 8));
   CsvAppend(line, BoolText(state.childAnchorIsLatestValid));
   CsvAppend(line, BoolText(state.childTrendInvalidatedBeforeFlip));
   CsvAppend(line, DoubleToString(state.childTrendRangeAfterDetection, 6));
   CsvAppend(line, BoolText(state.childCountertrendConfirmed));
   CsvAppend(line, DirectionText(-state.parentDirection));
   CsvAppend(line, IntegerToString(state.childSwingCount));
   CsvAppend(line, IntegerToString(state.childExtensionCount));
   CsvAppend(line, IntegerToString(state.childAnchorCount));
   CsvAppend(line, BoolText(state.childCountertrendValidAtEntry));
   CsvAppend(line, state.childCountertrendRejectReason);
   CsvAppend(line, IntegerToString(state.childFlipAnchorVersion));
   CsvAppend(line, BoolText(state.childFlipIsFirstBreakAfterAnchor));
   CsvAppend(line, IntegerToString(state.childFlipSignalAgeBars));
   CsvAppend(line, BoolText(state.childFlipIsFresh));
   CsvAppend(line, BoolText(state.childFlipEventConsumed));
   CsvAppend(line, BoolText(state.signalReusedBlocked));
   CsvAppend(line, BoolText(state.signalValidationPass));
   CsvAppend(line, state.signalValidationRejectReason);
   CsvAppend(line, BoolText(state.signalReservedBeforePortfolio));
   CsvAppend(line, state.signalReservedTime > 0 ? TimeToString(state.signalReservedTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, state.signalNotTradedReason);
   CsvAppend(line, state.signalConsumptionStage);
   CsvAppend(line, ChildAnchorModeName());
   CsvAppend(line, state.childTrendFlipEventId);
   FileWriteString(handle, line + "\r\n");
   FileClose(handle);
  }

void ChangeState(SymbolState &state,
                  const ENUM_STRATEGY_STATE nextState,
                  const datetime at,
                  const string reason)
  {
   if(state.strategyState == nextState)
      return;
   bool allowed = nextState == STATE_PARENT_FLIP_DETECTED;
   if(state.strategyState == STATE_IDLE)
      allowed = nextState == STATE_PARENT_FLIP_DETECTED;
   else if(state.strategyState == STATE_PARENT_FLIP_DETECTED)
      allowed = nextState == STATE_PARENT_WAVE1_CONFIRMED;
   else if(state.strategyState == STATE_PARENT_WAVE1_CONFIRMED)
      allowed = nextState == STATE_PARENT_WAVE2_PENDING || nextState == STATE_PARENT_WAVE2_ACTIVE ||
                nextState == STATE_INVALIDATED || nextState == STATE_EXPIRED || allowed;
   else if(state.strategyState == STATE_PARENT_WAVE2_PENDING)
      allowed = nextState == STATE_PARENT_WAVE2_ACTIVE || nextState == STATE_INVALIDATED ||
                nextState == STATE_EXPIRED || allowed;
   else if(state.strategyState == STATE_PARENT_WAVE2_ACTIVE)
      allowed = nextState == STATE_CHILD_COUNTER_TREND_CONFIRMED || nextState == STATE_INVALIDATED ||
                nextState == STATE_EXPIRED || allowed;
   else if(state.strategyState == STATE_CHILD_COUNTER_TREND_CONFIRMED)
      allowed = nextState == STATE_CHILD_TREND_FLIPPED || nextState == STATE_INVALIDATED ||
                nextState == STATE_EXPIRED || allowed;
   else if(state.strategyState == STATE_CHILD_TREND_FLIPPED)
      allowed = nextState == STATE_SIGNAL_RESERVED || nextState == STATE_SIGNAL_CONSUMED ||
                nextState == STATE_EXPIRED || allowed;
   else if(state.strategyState == STATE_SIGNAL_RESERVED)
      allowed = nextState == STATE_SIGNAL_CONSUMED || allowed;
   if(!allowed)
     {
      AddRejection("invalid_state_transition_" + StateName(state.strategyState) + "_to_" + StateName(nextState));
      WriteStateEvent(state, "invalid_state_transition_blocked");
      return;
     }
   state.previousState = state.strategyState;
   state.strategyState = nextState;
   state.stateChangedAt = at;
   state.stateChangeReason = reason;
   WriteStateEvent(state, "state_transition");
  }

bool FindFirstBreak(const MqlRates &rates[],
                    const datetime afterTime,
                    const double level,
                    const int direction,
                    int &breakShift,
                    datetime &breakTime,
                    double &breakClose)
  {
   breakShift = -1;
   breakTime = 0;
   breakClose = 0.0;
   for(int shift = ArraySize(rates) - 1; shift >= 0; --shift)
     {
      if(rates[shift].time <= afterTime)
         continue;
      bool broke = direction > 0 ? rates[shift].close > level : rates[shift].close < level;
      if(!broke)
         continue;
      breakShift = shift;
      breakTime = rates[shift].time;
      breakClose = rates[shift].close;
      return true;
     }
   return false;
  }

bool LatestPivotBefore(const PivotPoint &pivots[],
                       const datetime beforeTime,
                       const int kind,
                       PivotPoint &result)
  {
   bool found = false;
   for(int i = 0; i < ArraySize(pivots); ++i)
     {
      if(pivots[i].kind == kind && pivots[i].time < beforeTime &&
         pivots[i].confirmedTime <= beforeTime)
        {
         result = pivots[i];
         found = true;
        }
     }
   return found;
  }

void ClearChildState(SymbolState &state)
  {
   state.childTrendState = "unknown";
   state.childTrendAlignedWithWave2 = false;
   state.childActiveOshiyasu = 0.0;
   state.childActiveOshiyasuTime = 0;
   state.childActiveModoritakane = 0.0;
   state.childActiveModoritakaneTime = 0;
   state.childCorrectionExtreme = 0.0;
   state.childAnchorConfirmedTime = 0;
   state.childStructureFirstDetectedTime = 0;
   state.childStructureLatestUpdateTime = 0;
   state.childAnchorUpdateCount = 0;
   state.childAnchorVersion = 0;
   state.childFirstAnchorPrice = 0.0;
   state.childFirstAnchorTime = 0;
   state.childLatestAnchorPrice = 0.0;
   state.childLatestAnchorTime = 0;
   state.childAnchorChangedAfterInitialDetection = false;
   state.childAnchorUsedForFlip = 0.0;
   state.childAnchorIsLatestValid = false;
   state.childTrendInvalidatedBeforeFlip = false;
   state.childTrendRangeAfterDetection = 0.0;
   state.childSwingCount = 0;
   state.childExtensionCount = 0;
   state.childAnchorCount = 0;
   state.childCountertrendConfirmed = false;
   state.childCountertrendValidAtEntry = false;
   state.childCountertrendRejectReason = "no_confirmed_child_pivots";
   state.childTrendFlipDetected = false;
   state.childTrendFlipDirection = 0;
   state.childTrendFlipTime = 0;
   state.childTrendFlipLevel = 0.0;
   state.childTrendFlipClose = 0.0;
   state.childTrendFlipAtr = 0.0;
   state.childTrendFlipEventId = "";
   state.childFlipAnchorVersion = 0;
   state.childFlipIsFirstBreakAfterAnchor = false;
   state.childFlipSignalAgeBars = -1;
   state.childFlipIsFresh = false;
   state.childFlipEventConsumed = false;
   state.signalConsumed = false;
   state.signalReserved = false;
   state.signalReservedTime = 0;
   state.signalValidationPass = false;
   state.signalValidationRejectReason = "not_evaluated";
   state.signalReservedBeforePortfolio = false;
   state.signalNotTradedReason = "none";
   state.signalConsumptionStage = "none";
   state.consumedFlipEventId = "";
   state.signalReusedBlocked = false;
   state.signalExpired = false;
  }

bool FindFirstOppositeClose(const MqlRates &rates[], const int breakShift,
                            const int direction, datetime &foundTime)
  {
   foundTime = 0;
   for(int shift = breakShift - 1; shift >= 0; --shift)
     {
      bool opposite = false;
      if(InpLegacyCurrentCodeDiagnostic)
         opposite = direction > 0 ? rates[shift].close < rates[shift + 1].close :
                                    rates[shift].close > rates[shift + 1].close;
      else if(direction > 0)
         opposite = rates[shift].close < rates[shift].open ||
                    rates[shift].close < rates[shift + 1].low;
      else
         opposite = rates[shift].close > rates[shift].open ||
                    rates[shift].close > rates[shift + 1].high;
      if(opposite)
        {
         foundTime = rates[shift].time;
         return true;
        }
     }
   return false;
  }

bool FindConfirmedWave1EndPivot(const PivotPoint &pivots[], const datetime breakTime,
                                const int direction, datetime &foundTime)
  {
   foundTime = 0;
   int wantedKind = direction > 0 ? 1 : -1;
   datetime earliestTerminalPivot = breakTime - InpPivotDepth * PeriodSeconds(InpParentTF);
   for(int i = 0; i < ArraySize(pivots); ++i)
     {
      if(pivots[i].kind != wantedKind || pivots[i].time < earliestTerminalPivot ||
         pivots[i].confirmedTime <= breakTime)
         continue;
      foundTime = pivots[i].confirmedTime;
      return true;
     }
   return false;
  }

bool FindChildCountertrendStart(const string symbol, const datetime afterTime,
                                const datetime nowBar, const int parentDirection,
                                datetime &foundTime)
  {
   foundTime = 0;
   MqlRates rates[];
   PivotPoint pivots[];
   double atr = 0.0;
   if(!BuildPivots(symbol, InpChildTF, InpChildLookbackBars, rates, pivots, atr))
      return false;
   for(int i = 2; i < ArraySize(pivots); ++i)
     {
      PivotPoint a = pivots[i - 2], b = pivots[i - 1], c = pivots[i];
      if(a.time < afterTime || c.confirmedTime > nowBar)
         continue;
      bool falling = a.kind < 0 && b.kind > 0 && c.kind < 0 && c.price < a.price;
      bool rising = a.kind > 0 && b.kind < 0 && c.kind > 0 && c.price > a.price;
      if((parentDirection > 0 && falling) || (parentDirection < 0 && rising))
        {
         foundTime = c.confirmedTime;
         return true;
        }
     }
   return false;
  }

bool UpdateParentState(SymbolState &state, const datetime nowBar)
  {
   MqlRates rates[];
   PivotPoint pivots[];
   double atr = 0.0;
   if(!BuildPivots(state.symbol, InpParentTF, InpParentLookbackBars, rates, pivots, atr))
      return false;

   double lastHigh = 0.0, lastLow = 0.0;
   datetime lastHighTime = 0, lastLowTime = 0;
   double latestOshiyasu = 0.0, latestModoritakane = 0.0;
   datetime latestOshiyasuTime = 0, latestModoritakaneTime = 0;
   datetime latestLongEvent = 0, latestShortEvent = 0;
   for(int i = 0; i < ArraySize(pivots); ++i)
     {
      if(pivots[i].kind > 0)
        {
         if(lastHigh > 0.0 && pivots[i].price > lastHigh && lastLow > 0.0)
           {
            latestOshiyasu = lastLow;
            latestOshiyasuTime = lastLowTime;
            latestLongEvent = pivots[i].confirmedTime;
           }
         lastHigh = pivots[i].price;
         lastHighTime = pivots[i].time;
        }
      else
        {
         if(lastLow > 0.0 && pivots[i].price < lastLow && lastHigh > 0.0)
           {
            latestModoritakane = lastHigh;
            latestModoritakaneTime = lastHighTime;
            latestShortEvent = pivots[i].confirmedTime;
           }
         lastLow = pivots[i].price;
         lastLowTime = pivots[i].time;
        }
     }

   int direction = 0;
   double anchor = 0.0;
   datetime anchorTime = 0, structureEventTime = 0;
   string beforeBias = "unknown", afterBias = "unknown", anchorType = "none";
   if(latestShortEvent > latestLongEvent && latestModoritakane > 0.0)
     {
      direction = 1; anchor = latestModoritakane; anchorTime = latestModoritakaneTime;
      structureEventTime = latestShortEvent; beforeBias = "falling";
      afterBias = "rising"; anchorType = "modoritakane";
     }
   else if(latestLongEvent > latestShortEvent && latestOshiyasu > 0.0)
     {
      direction = -1; anchor = latestOshiyasu; anchorTime = latestOshiyasuTime;
      structureEventTime = latestLongEvent; beforeBias = "rising";
      afterBias = "falling"; anchorType = "oshiyasu";
     }
   else
      return false;

   int breakShift = -1;
   datetime breakTime = 0;
   double breakClose = 0.0;
   bool latestBreakFound = FindFirstBreak(rates, structureEventTime, anchor, direction,
                                          breakShift, breakTime, breakClose);
   if(!latestBreakFound && !(!InpLegacyCurrentCodeDiagnostic && state.parentWave2Pending && state.parentWave1Valid &&
                            !state.parentWave2Invalidated && state.parentEventId != ""))
      return false;

   // A pending wave1 owns its confirmation window. Without this lock, a newer
   // parent pattern can replace it before the terminal pivot or M5 correction confirms.
   if(!InpLegacyCurrentCodeDiagnostic && state.parentWave2Pending && state.parentWave1Valid &&
      !state.parentWave2Invalidated && state.parentEventId != "")
     {
      direction = state.parentDirection;
      anchor = state.parentAnchorPrice;
      anchorTime = state.parentAnchorTime;
      structureEventTime = state.parentStructureConfirmedTime;
      beforeBias = state.parentBiasBeforeFlip;
      afterBias = state.parentBiasAfterFlip;
      anchorType = state.parentAnchorType;
      breakTime = state.parentFirstBreakTime;
      breakClose = state.parentFirstBreakPrice;
      breakShift = -1;
      for(int shift = ArraySize(rates) - 1; shift >= 0; --shift)
         if(rates[shift].time == breakTime)
           { breakShift = shift; break; }
      if(breakShift < 0)
         return false;
     }

   string parentId = EventId(state.symbol, "PARENT", direction, breakTime, anchor);
   bool newParent = parentId != state.parentEventId;
   if(newParent)
     {
      state.parentEventId = parentId;
      state.parentDirection = direction;
      state.parentBiasBeforeFlip = beforeBias;
      state.parentBiasAfterFlip = afterBias;
      state.parentAnchorType = anchorType;
      state.parentAnchorPrice = anchor;
      state.parentAnchorTime = anchorTime;
      state.parentStructureConfirmedTime = structureEventTime;
      state.parentFirstBreakTime = breakTime;
      state.parentFirstBreakPrice = breakClose;
      state.parentWave2Active = false;
      state.parentWave2Pending = false;
      state.parentWave2StartTime = 0;
      state.parentWave2FirstOppositeCloseTime = 0;
      state.parentWave2ConfirmedPivotTime = 0;
      state.parentWave2ChildCountertrendStartTime = 0;
      state.parentWave2SelectedStartTime = 0;
      state.parentWave2StartDelayBars = -1;
      state.parentWave2StartReason = "not_detected";
      state.parentWave2Invalidated = false;
      state.parentWave2InvalidReason = "none";
      ClearChildState(state);
      if(AddUniqueKey(g_parentFlipKeys, parentId)) ++g_parentFlipsDetected;
      ChangeState(state, STATE_PARENT_FLIP_DETECTED, breakTime, "first_parent_anchor_close_break");
     }

   PivotPoint startPivot;
   bool startFound = LatestPivotBefore(pivots, breakTime, direction > 0 ? -1 : 1, startPivot);
   state.parentWave1StartTime = startFound ? startPivot.time : structureEventTime;
   state.parentWave1StartPrice = startFound ? startPivot.price : anchor;
   state.parentWave1EndTime = breakTime;
   state.parentWave1EndPrice = breakClose;
   int wave1Bars = BarsBetween(state.symbol, InpParentTF, state.parentWave1StartTime, breakTime);
   state.parentWave1RangeAtr = atr > 0.0 ? MathAbs(breakClose - state.parentWave1StartPrice) / atr : 0.0;
   state.parentWave1Valid = startFound && wave1Bars >= 0 && wave1Bars <= InpParentWave1MaxBars &&
                            ((direction > 0 && breakClose > state.parentWave1StartPrice) ||
                             (direction < 0 && breakClose < state.parentWave1StartPrice));
   state.parentWave1InvalidReason = state.parentWave1Valid ? "none" :
                                    (!startFound ? "wave1_start_pivot_missing" : "wave1_duration_or_direction_invalid");
   if(!state.parentWave1Valid)
      return true;
   if(AddUniqueKey(g_wave1Keys, parentId)) ++g_validParentWave1;
   if(newParent) ChangeState(state, STATE_PARENT_WAVE1_CONFIRMED, breakTime, "parent_wave1_confirmed");

   datetime firstClose = 0, confirmedPivot = 0, childStart = 0;
   FindFirstOppositeClose(rates, breakShift, direction, firstClose);
   FindConfirmedWave1EndPivot(pivots, breakTime, direction, confirmedPivot);
   FindChildCountertrendStart(state.symbol, breakTime, nowBar, direction, childStart);
   state.parentWave2FirstOppositeCloseTime = firstClose;
   state.parentWave2ConfirmedPivotTime = confirmedPivot;
   state.parentWave2ChildCountertrendStartTime = childStart;

   datetime selectedStart = 0;
   string startReason = "waiting_for_selected_start";
   if(InpParentWave2StartMode == WAVE2_START_FIRST_OPPOSITE_CLOSE)
     { selectedStart = firstClose; startReason = "first_opposite_close"; }
   else if(InpParentWave2StartMode == WAVE2_START_CONFIRMED_OPPOSITE_PIVOT)
     { selectedStart = confirmedPivot; startReason = "confirmed_wave1_terminal_pivot"; }
   else if(InpParentWave2StartMode == WAVE2_START_CHILD_COUNTERTREND)
     { selectedStart = childStart; startReason = "child_countertrend_confirmed"; }
   else
      startReason = "diagnostic_only_no_activation";

   state.parentWave2Pending = selectedStart <= 0;
   state.parentWave2Active = selectedStart > 0;
   state.parentWave2SelectedStartTime = selectedStart;
   state.parentWave2StartTime = selectedStart;
   state.parentWave2StartReason = startReason;
   state.parentWave2StartDelayBars = selectedStart > 0 ?
      BarsBetween(state.symbol, InpParentTF, breakTime, selectedStart) : -1;
   state.parentWave2Direction = -direction;
   state.parentWave2InvalidationPrice = state.parentWave1StartPrice;
   datetime ageOrigin = selectedStart > 0 ? selectedStart : breakTime;
   state.parentWave2AgeBars = BarsBetween(state.symbol, InpParentTF, ageOrigin, nowBar);

   bool invalidated = false;
   string invalidReason = "none";
   bool extremeSet = false;
   for(int shift = breakShift - 1; shift >= 0; --shift)
     {
      if(rates[shift].time < breakTime) continue;
      double test = InpParentWave2InvalidationUseClose ? rates[shift].close :
                    (direction > 0 ? rates[shift].low : rates[shift].high);
      if((direction > 0 && test < state.parentWave2InvalidationPrice) ||
         (direction < 0 && test > state.parentWave2InvalidationPrice))
        { invalidated = true; invalidReason = "wave1_origin_broken"; break; }
      if(selectedStart > 0 && rates[shift].time >= selectedStart)
        {
         if(!extremeSet)
           { state.parentWave2Extreme = direction > 0 ? rates[shift].low : rates[shift].high; extremeSet = true; }
         else if(direction > 0) state.parentWave2Extreme = MathMin(state.parentWave2Extreme, rates[shift].low);
         else state.parentWave2Extreme = MathMax(state.parentWave2Extreme, rates[shift].high);
        }
     }
   if(state.parentWave2AgeBars > InpParentWave2MaxBars)
     { invalidated = true; invalidReason = "wave2_max_age_exceeded"; }
   state.parentWave2Invalidated = invalidated;
   state.parentWave2InvalidReason = invalidReason;
   if(invalidated)
     {
      state.parentWave2Active = false;
      state.parentWave2Pending = false;
      ClearChildState(state);
      if(AddUniqueKey(g_invalidatedWave2Keys, parentId)) ++g_parentWave2Invalidated;
      ChangeState(state, invalidReason == "wave2_max_age_exceeded" ? STATE_EXPIRED : STATE_INVALIDATED,
                  rates[0].time, invalidReason);
      return true;
     }

   if(selectedStart <= 0)
     {
      string pendingKey = parentId + "|PENDING";
      if(AddUniqueKey(g_wave2PendingKeys, pendingKey)) ++g_parentWave2Pending;
      if(newParent || state.strategyState == STATE_PARENT_WAVE1_CONFIRMED)
         ChangeState(state, STATE_PARENT_WAVE2_PENDING, nowBar, startReason);
      return true;
     }

   if(AddUniqueKey(g_wave2Keys, parentId))
     {
      ++g_parentWave2Started;
      if(InpParentWave2StartMode == WAVE2_START_FIRST_OPPOSITE_CLOSE) ++g_parentWave2StartedFirstClose;
      else if(InpParentWave2StartMode == WAVE2_START_CONFIRMED_OPPOSITE_PIVOT) ++g_parentWave2StartedConfirmedPivot;
      else if(InpParentWave2StartMode == WAVE2_START_CHILD_COUNTERTREND) ++g_parentWave2StartedChildTrend;
     }
   if(newParent || state.strategyState == STATE_PARENT_WAVE2_PENDING ||
      state.strategyState == STATE_PARENT_WAVE1_CONFIRMED)
      ChangeState(state, STATE_PARENT_WAVE2_ACTIVE, selectedStart, startReason);
   return true;
  }

void ReserveSignal(SymbolState &state, const datetime at)
  {
   if(state.signalReserved || state.signalConsumed)
      return;
   state.signalReserved = true;
   state.signalConsumed = true;
   state.signalReservedTime = at;
   state.signalReservedBeforePortfolio = true;
   state.signalConsumptionStage = "before_portfolio";
   state.consumedFlipEventId = state.childTrendFlipEventId;
   if(AddUniqueKey(g_reservedSignalKeys, state.parentEventId)) ++g_signalsReserved;
   ChangeState(state, STATE_SIGNAL_RESERVED, at, "valid_signal_reserved_before_portfolio");
  }

void FinalizeSignal(SymbolState &state, const datetime at, const string stage, const string reason)
  {
   state.signalConsumed = true;
   state.childFlipEventConsumed = true;
   state.signalConsumptionStage = stage;
   state.signalNotTradedReason = reason;
   state.consumedFlipEventId = state.childTrendFlipEventId;
   if(AddUniqueKey(g_consumedSignalKeys, state.parentEventId)) ++g_signalsConsumed;
   ChangeState(state, STATE_SIGNAL_CONSUMED, at, reason);
  }

void ExpireSignal(SymbolState &state, const datetime at, const string reason)
  {
   state.signalConsumed = true;
   state.childFlipEventConsumed = true;
   state.signalExpired = true;
   state.signalConsumptionStage = "invalid_candidate";
   state.signalValidationRejectReason = reason;
   state.signalNotTradedReason = reason;
   state.consumedFlipEventId = state.childTrendFlipEventId;
   if(AddUniqueKey(g_consumedSignalKeys, state.parentEventId)) ++g_signalsConsumed;
   ChangeState(state, STATE_EXPIRED, at, reason);
  }

bool UpdateChildTrend(SymbolState &state, const datetime nowBar)
  {
   if(!state.parentWave2Active || state.parentWave2StartTime <= 0 || state.parentWave2Invalidated)
      return false;
   if(state.childTrendFlipDetected)
     {
      state.childFlipSignalAgeBars = BarsBetween(state.symbol, InpChildTF,
                                                 state.childTrendFlipTime, nowBar);
      state.childFlipIsFresh = state.childFlipSignalAgeBars == 0;
      if(!state.signalConsumed && state.childFlipSignalAgeBars > InpChildFlipMaxSignalAgeBars)
        {
         state.signalExpired = true;
         state.signalReusedBlocked = true;
         if(AddUniqueKey(g_expiredSignalKeys, state.parentEventId)) ++g_expiredSignals;
         ExpireSignal(state, nowBar, "child_flip_signal_expired");
        }
      return true;
     }
   MqlRates rates[];
   PivotPoint allPivots[];
   double atr = 0.0;
   if(!BuildPivots(state.symbol, InpChildTF, InpChildLookbackBars, rates, allPivots, atr))
     {
      state.childCountertrendRejectReason = "no_confirmed_child_pivots";
      return false;
     }

   ChildAnchorCandidate anchors[];
   ArrayResize(anchors, 0);
   int filteredSwings = 0;
   int eligiblePivots = 0;
   bool oppositeShapeWithoutExtension = false;
   for(int i = 0; i < ArraySize(allPivots); ++i)
      if(allPivots[i].time >= state.parentFirstBreakTime && allPivots[i].confirmedTime <= nowBar)
         ++eligiblePivots;
   for(int i = 2; i < ArraySize(allPivots); ++i)
     {
      PivotPoint a = allPivots[i - 2], b = allPivots[i - 1], c = allPivots[i];
      if(a.time < state.parentFirstBreakTime || c.confirmedTime > nowBar)
         continue;
      ++filteredSwings;
      bool falling = a.kind < 0 && b.kind > 0 && c.kind < 0 && c.price < a.price;
      bool rising = a.kind > 0 && b.kind < 0 && c.kind > 0 && c.price > a.price;
      bool fallingShape = a.kind < 0 && b.kind > 0 && c.kind < 0;
      bool risingShape = a.kind > 0 && b.kind < 0 && c.kind > 0;
      if((state.parentDirection > 0 && fallingShape && !falling) ||
         (state.parentDirection < 0 && risingShape && !rising))
         oppositeShapeWithoutExtension = true;
      if(!((state.parentDirection > 0 && falling) || (state.parentDirection < 0 && rising)))
         continue;
      int size = ArraySize(anchors);
      ArrayResize(anchors, size + 1);
      anchors[size].price = b.price;
      anchors[size].time = b.time;
      anchors[size].confirmedTime = c.confirmedTime;
      anchors[size].extreme = c.price;
      anchors[size].swingCount = MathMax(3, filteredSwings + 2);
      anchors[size].extensionCount = size + 1;
     }

   int oldObservedAnchorCount = state.childAnchorCount;
   state.childSwingCount = filteredSwings + (filteredSwings > 0 ? 2 : 0);
   state.childExtensionCount = ArraySize(anchors);
   state.childAnchorCount = ArraySize(anchors);
   if(ArraySize(anchors) == 0)
     {
      state.childTrendState = filteredSwings > 0 ? "range" : "unknown";
      state.childTrendAlignedWithWave2 = false;
      state.childCountertrendConfirmed = false;
      state.childCountertrendRejectReason = eligiblePivots == 0 ? "no_confirmed_child_pivots" :
                                               (eligiblePivots < 3 ? "only_one_opposite_bar" :
                                                (oppositeShapeWithoutExtension ? "no_price_extension" :
                                                 "child_range_only"));
      return false;
     }

   int selected = InpChildAnchorMode == CHILD_ANCHOR_LEGACY_FIRST ? 0 : ArraySize(anchors) - 1;
   ChildAnchorCandidate active = anchors[selected];
   if(state.childStructureFirstDetectedTime <= 0)
     {
      state.childStructureFirstDetectedTime = anchors[0].confirmedTime;
      state.childFirstAnchorPrice = anchors[0].price;
      state.childFirstAnchorTime = anchors[0].time;
      ++g_childAnchorsCreated;
     }
   if(ArraySize(anchors) > oldObservedAnchorCount)
      g_childAnchorsUpdated += MathMax(0, ArraySize(anchors) - MathMax(1, oldObservedAnchorCount));
   int oldVersion = state.childAnchorVersion;
   state.childAnchorVersion = selected + 1;
   bool activeAnchorChanged = state.childAnchorVersion > oldVersion;
   state.childAnchorUpdateCount = MathMax(0, ArraySize(anchors) - 1);
   state.childStructureLatestUpdateTime = active.confirmedTime;
   state.childLatestAnchorPrice = anchors[ArraySize(anchors) - 1].price;
   state.childLatestAnchorTime = anchors[ArraySize(anchors) - 1].time;
   state.childAnchorChangedAfterInitialDetection = ArraySize(anchors) > 1;
   state.childAnchorIsLatestValid = selected == ArraySize(anchors) - 1;
   state.childAnchorConfirmedTime = active.confirmedTime;
   state.childCorrectionExtreme = active.extreme;
   state.childTrendState = state.parentDirection > 0 ? "falling" : "rising";
   state.childTrendAlignedWithWave2 = true;
   state.childCountertrendConfirmed = true;
   state.childCountertrendRejectReason = "none";
   int childAge = BarsBetween(state.symbol, InpChildTF,
                              state.childStructureFirstDetectedTime, rates[0].time);
   if(childAge > InpChildStructureMaxAgeBars)
     {
      state.childTrendAlignedWithWave2 = false;
      state.childCountertrendConfirmed = false;
      state.childCountertrendRejectReason = "child_structure_too_old";
      return false;
     }
   if(state.parentDirection > 0)
     {
      state.childActiveModoritakane = active.price;
      state.childActiveModoritakaneTime = active.time;
     }
   else
     {
      state.childActiveOshiyasu = active.price;
      state.childActiveOshiyasuTime = active.time;
     }

   double rangeHigh = rates[0].high, rangeLow = rates[0].low;
   for(int shift = ArraySize(rates) - 1; shift >= 0; --shift)
     {
      if(rates[shift].time < state.childStructureFirstDetectedTime) continue;
      rangeHigh = MathMax(rangeHigh, rates[shift].high);
      rangeLow = MathMin(rangeLow, rates[shift].low);
     }
   state.childTrendRangeAfterDetection = atr > 0.0 ? (rangeHigh - rangeLow) / atr : 0.0;
   string trendKey = state.parentEventId + "|CHILD|" + IntegerToString((long)anchors[0].confirmedTime);
   if(AddUniqueKey(g_childTrendKeys, trendKey)) ++g_childCountertrendConfirmed;
   string anchorKey = state.parentEventId + "|ANCHOR|" + IntegerToString(state.childAnchorVersion);
   AddUniqueKey(g_childAnchorKeys, anchorKey);
   if(activeAnchorChanged)
      WriteStateEvent(state, oldVersion == 0 ? "child_anchor_created" : "child_anchor_updated");
   if(state.strategyState == STATE_PARENT_WAVE2_ACTIVE)
      ChangeState(state, STATE_CHILD_COUNTER_TREND_CONFIRMED, active.confirmedTime,
                  "child_countertrend_confirmed_latest_anchor_active");

   double flipLevel = active.price;
   int flipShift = -1;
   datetime flipTime = 0;
   double flipClose = 0.0;
   if(!FindFirstBreak(rates, active.confirmedTime, flipLevel, state.parentDirection,
                      flipShift, flipTime, flipClose))
      return true;

   state.childTrendFlipDetected = true;
   state.childTrendFlipDirection = state.parentDirection;
   state.childTrendFlipTime = flipTime;
   state.childTrendFlipLevel = flipLevel;
   state.childTrendFlipClose = flipClose;
   state.childTrendFlipAtr = state.parentDirection > 0 ? (flipClose - flipLevel) / atr :
                                                       (flipLevel - flipClose) / atr;
   state.childAnchorUsedForFlip = flipLevel;
   state.childFlipAnchorVersion = state.childAnchorVersion;
   state.childFlipIsFirstBreakAfterAnchor = true;
   state.childFlipSignalAgeBars = BarsBetween(state.symbol, InpChildTF, flipTime, rates[0].time);
   state.childFlipIsFresh = flipTime == rates[0].time && state.childFlipSignalAgeBars == 0;
   state.childTrendFlipEventId = EventId(state.symbol, "CHILD_FLIP", state.parentDirection,
                                         flipTime, flipLevel);
   if(AddUniqueKey(g_childFlipKeys, state.childTrendFlipEventId)) ++g_childTrendFlipsDetected;
   if(AddUniqueKey(g_firstSignalKeys, state.parentEventId)) ++g_firstFlipSignals;
   if(state.childFlipIsFresh) ++g_freshFirstFlipSignals;
   ChangeState(state, STATE_CHILD_TREND_FLIPPED, flipTime, "first_close_break_of_active_child_anchor");

   state.signalExpired = !state.childFlipIsFresh ||
                         state.childFlipSignalAgeBars > InpChildFlipMaxSignalAgeBars;
   if(state.signalExpired && AddUniqueKey(g_expiredSignalKeys, state.parentEventId))
     {
      ++g_expiredSignals;
      state.signalReusedBlocked = true;
      state.signalConsumptionStage = "invalid_candidate";
      state.signalValidationRejectReason = "stale_child_flip_not_reused";
      AddRejection("stale_child_flip_not_reused");
      ExpireSignal(state, nowBar, "stale_child_flip_not_reused");
     }
   return true;
  }

string BiasFromPivots(const string symbol, const ENUM_TIMEFRAMES tf)
  {
   MqlRates rates[];
   PivotPoint pivots[];
   double atr = 0.0;
   if(!BuildPivots(symbol, tf, 100, rates, pivots, atr) || ArraySize(pivots) < 4)
      return "unknown";
   double high1 = 0.0, high2 = 0.0, low1 = 0.0, low2 = 0.0;
   for(int i = ArraySize(pivots) - 1; i >= 0; --i)
     {
      if(pivots[i].kind > 0 && high1 == 0.0) high1 = pivots[i].price;
      else if(pivots[i].kind > 0 && high2 == 0.0) high2 = pivots[i].price;
      if(pivots[i].kind < 0 && low1 == 0.0) low1 = pivots[i].price;
      else if(pivots[i].kind < 0 && low2 == 0.0) low2 = pivots[i].price;
      if(high2 > 0.0 && low2 > 0.0) break;
     }
   if(high1 > high2 && low1 > low2) return "rising";
   if(high1 < high2 && low1 < low2) return "falling";
   return "range";
  }

string SessionLabel(const datetime serverTime, int &utcHour, int &weekday)
  {
   datetime utc = serverTime - InpBrokerUtcOffsetHours * 3600;
   MqlDateTime dt;
   TimeToStruct(utc, dt);
   utcHour = dt.hour;
   weekday = dt.day_of_week;
   bool tokyo = dt.hour >= 0 && dt.hour < 9;
   bool london = dt.hour >= 7 && dt.hour < 16;
   bool newYork = dt.hour >= 13 && dt.hour < 22;
   if(london && newYork) return "london_newyork_overlap";
   if(tokyo) return "tokyo";
   if(london) return "london";
   if(newYork) return "new_york";
   return "off_session";
  }

void ResetCandidate(EntryCandidate &candidate)
  {
   candidate.valid = false;
   candidate.stateIndex = -1;
   candidate.entryRejectReason = "none";
   candidate.signalValidationPass = false;
   candidate.signalValidationRejectReason = "not_evaluated";
   candidate.signalReservedBeforePortfolio = false;
   candidate.signalConsumptionStage = "none";
  }

bool RejectCandidate(SymbolState &state, EntryCandidate &candidate, const string reason)
  {
   state.signalValidationPass = false;
   state.signalValidationRejectReason = reason;
   state.signalConsumptionStage = "invalid_candidate";
   state.signalNotTradedReason = reason;
   candidate.entryRejectReason = reason;
   candidate.signalValidationRejectReason = reason;
   if(AddUniqueKey(g_invalidCandidateKeys, state.parentEventId)) ++g_candidateInvalid;
   AddRejection("candidate_invalid_" + reason);
   FinalizeSignal(state, TimeCurrent(), "invalid_candidate", reason);
   return false;
  }

bool BuildCandidateForState(const int index, SymbolState &state, EntryCandidate &candidate)
  {
   ResetCandidate(candidate);
   if(InpRunMode != RUN_TRADE_FIRST_CHILD_FLIP)
      return false;
   if(!state.parentWave1Valid || !state.parentWave2Active || state.parentWave2Invalidated)
      return false;
   if(InpRequireChildTrendBeforeFlip && !state.childTrendAlignedWithWave2)
      return false;
   if(!state.childTrendFlipDetected)
      return false;
   if(InpEntryOnFirstChildTrendFlip && state.childFlipSignalAgeBars > InpChildFlipMaxSignalAgeBars)
      return false;
   if(InpOneEntryPerParentWave2 && (state.signalReserved || state.signalConsumed))
     {
      state.signalReusedBlocked = true;
      return false;
     }

   MqlRates child[];
   if(!CopyClosedRates(state.symbol, InpChildTF, InpATRPeriod + 4, child))
      return RejectCandidate(state, candidate, "rates_unavailable");
   double atr = ATR(child, 0, InpATRPeriod);
   if(atr <= 0.0)
      return RejectCandidate(state, candidate, "atr_unavailable");
   MqlTick tick;
   if(!SymbolInfoTick(state.symbol, tick))
      return RejectCandidate(state, candidate, "tick_unavailable");
   int direction = state.parentDirection;
   double entry = direction > 0 ? tick.ask : tick.bid;
   double anchor = InpStopMode == STOP_PARENT_WAVE2_EXTREME ? state.parentWave2Extreme :
                                                             state.childCorrectionExtreme;
   if(entry <= 0.0 || anchor <= 0.0)
      return RejectCandidate(state, candidate, "entry_or_stop_anchor_invalid");
   double stop = direction > 0 ? anchor - atr * InpStopBufferATR : anchor + atr * InpStopBufferATR;
   double risk = MathAbs(entry - stop);
   if((direction > 0 && stop >= entry) || (direction < 0 && stop <= entry) ||
      risk < atr * 0.20 || risk > atr * 5.0)
     {
      return RejectCandidate(state, candidate, "invalid_stop_distance");
     }
   double point = SymbolInfoDouble(state.symbol, SYMBOL_POINT);
   int stopsLevel = (int)SymbolInfoInteger(state.symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(point <= 0.0 || (stopsLevel > 0 && risk < stopsLevel * point))
      return RejectCandidate(state, candidate, "broker_min_stop_distance");
   double spread = tick.ask - tick.bid;
   if(spread > atr * InpMaxSpreadATR)
     {
      return RejectCandidate(state, candidate, "spread_guard");
     }
   long tradeMode = SymbolInfoInteger(state.symbol, SYMBOL_TRADE_MODE);
   if(tradeMode == SYMBOL_TRADE_MODE_DISABLED || tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY)
      return RejectCandidate(state, candidate, "symbol_trade_mode_blocked");

   candidate.valid = true;
   candidate.stateIndex = index;
   candidate.symbol = state.symbol;
   candidate.direction = direction;
   candidate.entryPrice = entry;
   candidate.stopLoss = stop;
   candidate.takeProfit = direction > 0 ? entry + risk * InpTargetR : entry - risk * InpTargetR;
   candidate.riskPrice = risk;
   candidate.atr = atr;
   candidate.score = state.parentWave1RangeAtr;
   candidate.parentEventId = state.parentEventId;
   candidate.childFlipEventId = state.childTrendFlipEventId;
   candidate.signalAgeBars = state.childFlipSignalAgeBars;
   candidate.parentWave2Age = state.parentWave2AgeBars;
   candidate.childTrendBeforeFlip = state.childTrendState;
   candidate.entryReason = "first_child_trend_flip_after_parent_wave2";
   candidate.entryRejectReason = "none";
   candidate.parentWave2StartMode = (int)InpParentWave2StartMode;
   candidate.parentWave2StartReason = state.parentWave2StartReason;
   candidate.parentWave2StartDelayBars = state.parentWave2StartDelayBars;
   candidate.childAnchorVersion = state.childAnchorVersion;
   candidate.childAnchorUpdateCount = state.childAnchorUpdateCount;
   candidate.childFirstAnchorPrice = state.childFirstAnchorPrice;
   candidate.childLatestAnchorPrice = state.childLatestAnchorPrice;
   candidate.childAnchorUsedForFlip = state.childAnchorUsedForFlip;
   candidate.childAnchorIsLatestValid = state.childAnchorIsLatestValid;
   candidate.childAnchorChangedAfterInitialDetection = state.childAnchorChangedAfterInitialDetection;
   candidate.childSwingCount = state.childSwingCount;
   candidate.childExtensionCount = state.childExtensionCount;
   candidate.childCountertrendValidAtEntry = state.childCountertrendConfirmed &&
                                             !state.childTrendInvalidatedBeforeFlip;
   candidate.childCountertrendRejectReason = state.childCountertrendRejectReason;
   candidate.childFlipIsFirstBreakAfterAnchor = state.childFlipIsFirstBreakAfterAnchor;
   candidate.childFlipIsFresh = state.childFlipIsFresh;
   candidate.h1BiasState = BiasFromPivots(state.symbol, InpTopContextTF);
   candidate.h1Alignment = (direction > 0 && candidate.h1BiasState == "rising") ||
                           (direction < 0 && candidate.h1BiasState == "falling");
   candidate.h4BiasState = BiasFromPivots(state.symbol, PERIOD_H4);
   candidate.h4Alignment = (direction > 0 && candidate.h4BiasState == "rising") ||
                           (direction < 0 && candidate.h4BiasState == "falling");
   candidate.fractalAlignmentCount = 1 + (candidate.h1Alignment ? 1 : 0) + (candidate.h4Alignment ? 1 : 0);
   candidate.fullFractalAlignment = candidate.fractalAlignmentCount == 3;
   candidate.sessionLabel = SessionLabel(child[0].time, candidate.utcHour, candidate.weekday);
   state.childCountertrendValidAtEntry = candidate.childCountertrendValidAtEntry;
   state.signalValidationPass = true;
   state.signalValidationRejectReason = "none";
   state.signalNotTradedReason = "pending_portfolio";
   state.signalConsumptionStage = "before_portfolio";
   candidate.signalValidationPass = true;
   candidate.signalValidationRejectReason = "none";
   candidate.signalReservedBeforePortfolio = true;
   candidate.signalConsumptionStage = "before_portfolio";
   if(AddUniqueKey(g_validCandidateKeys, state.parentEventId)) ++g_validCandidates;
   ReserveSignal(state, child[0].time);
   return true;
  }

bool BuildCandidate(const int index, EntryCandidate &candidate)
  {
   return BuildCandidateForState(index, g_states[index], candidate);
  }

int CountManagedPositions()
  {
   int count = 0;
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      if(PositionGetTicket(i) > 0 && (long)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         ++count;
     }
   return count;
  }

bool HasManagedPosition(const string symbol)
  {
   if(!PositionSelect(symbol))
      return false;
   return (long)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber;
  }

double NormalizeVolume(const string symbol, const double raw)
  {
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = MathMin(SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX), InpMaxLotCap);
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = minLot;
   double volume = MathFloor(raw / step) * step;
   volume = MathMax(minLot, MathMin(maxLot, volume));
   return NormalizeDouble(volume, 8);
  }

double CalculatePositionSize(const string symbol, const double stopDistance)
  {
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tickValue <= 0.0) tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   if(stopDistance <= 0.0 || tickSize <= 0.0 || tickValue <= 0.0)
      return NormalizeVolume(symbol, InpFixedLotFallback);
   double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * InpRiskPerTradePercent / 100.0;
   double riskPerLot = stopDistance / tickSize * tickValue;
   if(riskPerLot <= 0.0)
      return NormalizeVolume(symbol, InpFixedLotFallback);
   return NormalizeVolume(symbol, riskMoney / riskPerLot);
  }

double CurrentOpenRiskPercent()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0) return 0.0;
   double riskMoney = 0.0;
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      if(PositionGetTicket(i) == 0 || (long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      string symbol = PositionGetString(POSITION_SYMBOL);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
      if(sl > 0.0 && tickSize > 0.0 && tickValue > 0.0)
         riskMoney += MathAbs(open - sl) / tickSize * tickValue * volume;
     }
   return riskMoney / equity * 100.0;
  }

int DateKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

void UpdateRiskAnchors()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_peakEquity = MathMax(g_peakEquity, equity);
   int key = DateKey(TimeCurrent());
   if(key != g_dayKey)
     {
      g_dayKey = key;
      g_dayStartEquity = equity;
      g_dailyStopped = false;
     }
   if(g_dayStartEquity > 0.0 && equity <= g_dayStartEquity * (1.0 - InpDailyMaxLossPercent / 100.0))
      g_dailyStopped = true;
   if(g_peakEquity > 0.0 && equity <= g_peakEquity * (1.0 - InpMaxDrawdownPercent / 100.0))
      g_drawdownStopped = true;
  }

bool RiskStopped()
  {
   return g_dailyStopped || g_drawdownStopped;
  }

void TrackPosition(const EntryCandidate &candidate, const double volume)
  {
   if(!PositionSelect(candidate.symbol))
      return;
   int size = ArraySize(g_trades);
   ArrayResize(g_trades, size + 1);
   TrackedTrade tracked;
   tracked.active = true;
   tracked.positionId = (long)PositionGetInteger(POSITION_IDENTIFIER);
   tracked.symbol = candidate.symbol;
   tracked.direction = candidate.direction;
   tracked.entryTime = (datetime)PositionGetInteger(POSITION_TIME);
   tracked.entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   tracked.initialStop = candidate.stopLoss;
   tracked.takeProfit = candidate.takeProfit;
   tracked.riskPrice = candidate.riskPrice;
   tracked.volume = volume;
   tracked.atr = candidate.atr;
   tracked.maxFavorableR = 0.0;
   tracked.maxAdverseR = 0.0;
   tracked.reached05R = false;
   tracked.reached08R = false;
   tracked.reached10R = false;
   tracked.reached13R = false;
   tracked.barsTo05R = -1;
   tracked.barsTo10R = -1;
   tracked.barsTo13R = -1;
   tracked.timeExitRequested = false;
   tracked.parentEventId = candidate.parentEventId;
   tracked.childFlipEventId = candidate.childFlipEventId;
   tracked.signalAgeBars = candidate.signalAgeBars;
   tracked.parentWave2Age = candidate.parentWave2Age;
   tracked.childTrendBeforeFlip = candidate.childTrendBeforeFlip;
   tracked.parentWave2StartMode = candidate.parentWave2StartMode;
   tracked.parentWave2StartReason = candidate.parentWave2StartReason;
   tracked.parentWave2StartDelayBars = candidate.parentWave2StartDelayBars;
   tracked.childAnchorVersion = candidate.childAnchorVersion;
   tracked.childAnchorUpdateCount = candidate.childAnchorUpdateCount;
   tracked.childFirstAnchorPrice = candidate.childFirstAnchorPrice;
   tracked.childLatestAnchorPrice = candidate.childLatestAnchorPrice;
   tracked.childAnchorUsedForFlip = candidate.childAnchorUsedForFlip;
   tracked.childAnchorIsLatestValid = candidate.childAnchorIsLatestValid;
   tracked.childAnchorChangedAfterInitialDetection = candidate.childAnchorChangedAfterInitialDetection;
   tracked.childSwingCount = candidate.childSwingCount;
   tracked.childExtensionCount = candidate.childExtensionCount;
   tracked.childCountertrendValidAtEntry = candidate.childCountertrendValidAtEntry;
   tracked.childCountertrendRejectReason = candidate.childCountertrendRejectReason;
   tracked.childFlipIsFirstBreakAfterAnchor = candidate.childFlipIsFirstBreakAfterAnchor;
   tracked.childFlipIsFresh = candidate.childFlipIsFresh;
   tracked.signalValidationPass = candidate.signalValidationPass;
   tracked.signalValidationRejectReason = candidate.signalValidationRejectReason;
   tracked.signalReservedBeforePortfolio = candidate.signalReservedBeforePortfolio;
   tracked.signalConsumptionStage = "traded";
   tracked.h1BiasState = candidate.h1BiasState;
   tracked.h1Alignment = candidate.h1Alignment;
   tracked.h4BiasState = candidate.h4BiasState;
   tracked.h4Alignment = candidate.h4Alignment;
   tracked.fractalAlignmentCount = candidate.fractalAlignmentCount;
   tracked.fullFractalAlignment = candidate.fullFractalAlignment;
   tracked.sessionLabel = candidate.sessionLabel;
   tracked.utcHour = candidate.utcHour;
   tracked.weekday = candidate.weekday;
   g_trades[size] = tracked;
  }

bool OpenCandidate(const EntryCandidate &candidate)
  {
   if(!candidate.valid)
      return false;
   ++g_portfolioSelected;
   if(RiskStopped())
     {
      AddRejection(g_dailyStopped ? "daily_loss_stop" : "drawdown_stop");
      ++g_riskReject;
      FinalizeSignal(g_states[candidate.stateIndex], TimeCurrent(), "risk_block",
                     g_dailyStopped ? "daily_loss_stop" : "drawdown_stop");
      return false;
     }
   if(HasManagedPosition(candidate.symbol))
     {
      AddRejection("symbol_position_cap");
      ++g_positionCapReject;
      FinalizeSignal(g_states[candidate.stateIndex], TimeCurrent(), "position_cap", "symbol_position_cap");
      return false;
     }
   if(CountManagedPositions() >= InpMaxPositions)
     {
      AddRejection("portfolio_position_cap");
      ++g_positionCapReject;
      FinalizeSignal(g_states[candidate.stateIndex], TimeCurrent(), "position_cap", "portfolio_position_cap");
      return false;
     }
   if(CurrentOpenRiskPercent() + InpRiskPerTradePercent > InpMaxTotalOpenRiskPercent)
     {
      AddRejection("portfolio_risk_cap");
      ++g_riskReject;
      FinalizeSignal(g_states[candidate.stateIndex], TimeCurrent(), "risk_block", "portfolio_risk_cap");
      return false;
     }
   if(InpRiskPerTradePercent > InpMaxRiskPerSymbolPercent)
     {
      AddRejection("symbol_risk_cap");
      ++g_riskReject;
      FinalizeSignal(g_states[candidate.stateIndex], TimeCurrent(), "risk_block", "symbol_risk_cap");
      return false;
     }
   double volume = CalculatePositionSize(candidate.symbol, candidate.riskPrice);
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);
   bool ok = candidate.direction > 0 ?
      trade.Buy(volume, candidate.symbol, 0.0, candidate.stopLoss, candidate.takeProfit, STRATEGY_NAME) :
      trade.Sell(volume, candidate.symbol, 0.0, candidate.stopLoss, candidate.takeProfit, STRATEGY_NAME);
   if(!ok)
     {
      AddRejection("order_failed_" + IntegerToString((int)trade.ResultRetcode()));
      ++g_orderFailure;
      FinalizeSignal(g_states[candidate.stateIndex], TimeCurrent(), "order_failure",
                     "order_failed_" + IntegerToString((int)trade.ResultRetcode()));
      return false;
     }
   ++g_tradesTaken;
   TrackPosition(candidate, volume);
   FinalizeSignal(g_states[candidate.stateIndex], TimeCurrent(), "traded", "traded");
   return true;
  }

void ManageTrades()
  {
   for(int i = 0; i < ArraySize(g_trades); ++i)
     {
      if(!g_trades[i].active)
         continue;
      if(!PositionSelect(g_trades[i].symbol) ||
         (long)PositionGetInteger(POSITION_IDENTIFIER) != g_trades[i].positionId)
         continue;
      MqlTick tick;
      if(!SymbolInfoTick(g_trades[i].symbol, tick))
         continue;
      double current = g_trades[i].direction > 0 ? tick.bid : tick.ask;
      double moveR = g_trades[i].direction > 0 ?
                     (current - g_trades[i].entryPrice) / g_trades[i].riskPrice :
                     (g_trades[i].entryPrice - current) / g_trades[i].riskPrice;
      g_trades[i].maxFavorableR = MathMax(g_trades[i].maxFavorableR, moveR);
      g_trades[i].maxAdverseR = MathMin(g_trades[i].maxAdverseR, moveR);
      int held = iBarShift(g_trades[i].symbol, InpChildTF, g_trades[i].entryTime, false);
      if(!g_trades[i].reached05R && moveR >= 0.5)
        { g_trades[i].reached05R = true; g_trades[i].barsTo05R = held; }
      if(!g_trades[i].reached08R && moveR >= 0.8)
         g_trades[i].reached08R = true;
      if(!g_trades[i].reached10R && moveR >= 1.0)
        { g_trades[i].reached10R = true; g_trades[i].barsTo10R = held; }
      if(!g_trades[i].reached13R && moveR >= 1.3)
        { g_trades[i].reached13R = true; g_trades[i].barsTo13R = held; }
      if(InpMaxHoldBars > 0 && held >= InpMaxHoldBars)
        {
         g_trades[i].timeExitRequested = true;
         trade.PositionClose(g_trades[i].symbol);
        }
     }
  }

int FindTracked(const long positionId)
  {
   for(int i = 0; i < ArraySize(g_trades); ++i)
      if(g_trades[i].active && g_trades[i].positionId == positionId)
         return i;
   return -1;
  }

void WriteTradeRow(const TrackedTrade &tracked,
                   const datetime exitTime,
                   const double exitPrice,
                   const double profit,
                   const double commission,
                   const double swap,
                   const string dealReason)
  {
   EnsureLogFolder();
   int handle = FileOpen(LogFileName("trades"), LogFlags(), ',');
   if(handle == INVALID_HANDLE) return;
   bool header = FileSize(handle) == 0;
   FileSeek(handle, 0, SEEK_END);
   if(header)
      FileWriteString(handle,
         "entry_time,exit_time,strategy,run_id,symbol,direction,parent_tf,child_tf,top_context_tf,entry_parent_event_id,entry_child_flip_event_id,entry_signal_age_bars,entry_on_first_child_flip,entry_signal_consumed,entry_signal_reused_blocked,entry_parent_wave2_age,entry_child_trend_before_flip,parent_wave2_start_mode,parent_wave2_start_reason,parent_wave2_start_delay_bars,child_anchor_mode,child_anchor_version,child_anchor_update_count,child_first_anchor_price,child_latest_anchor_price,child_anchor_used_for_flip,child_anchor_is_latest_valid,child_anchor_changed_after_initial_detection,child_swing_count,child_extension_count,child_countertrend_valid_at_entry,child_countertrend_reject_reason,child_flip_is_first_break_after_anchor,child_flip_is_fresh,signal_validation_pass,signal_validation_reject_reason,signal_reserved_before_portfolio,signal_consumption_stage,entry_reason,entry_reject_reason,h1_bias_state,h1_alignment_with_parent,h4_bias_state,h4_alignment_with_parent,fractal_alignment_count,full_fractal_alignment,session_label,utc_hour,weekday,stop_mode,entry,exit,stop_loss,take_profit,risk_price,result_r,max_favorable_r_before_exit,max_adverse_r_before_exit,reached_0_5r,reached_0_8r,reached_1_0r,reached_1_3r,bars_to_0_5r,bars_to_1_0r,bars_to_1_3r,exit_type,full_sl_exit,tp_exit,time_exit,profit,commission,swap,net_profit,volume,reward_r,holding_bars,atr,deal_reason\r\n");
   double resultR = tracked.direction > 0 ? (exitPrice - tracked.entryPrice) / tracked.riskPrice :
                                           (tracked.entryPrice - exitPrice) / tracked.riskPrice;
   int holdingBars = iBarShift(tracked.symbol, InpChildTF, tracked.entryTime, false);
   string exitType = tracked.timeExitRequested ? "time" :
                     (StringFind(dealReason, "SL") >= 0 ? "full_sl" :
                      (StringFind(dealReason, "TP") >= 0 ? "tp" : "other"));
   string line = "";
   CsvAppend(line, TimeToString(tracked.entryTime, TIME_DATE | TIME_SECONDS));
   CsvAppend(line, TimeToString(exitTime, TIME_DATE | TIME_SECONDS));
   CsvAppend(line, STRATEGY_NAME);
   CsvAppend(line, InpRunId);
   CsvAppend(line, tracked.symbol);
   CsvAppend(line, DirectionText(tracked.direction));
   CsvAppend(line, TFName(InpParentTF));
   CsvAppend(line, TFName(InpChildTF));
   CsvAppend(line, TFName(InpTopContextTF));
   CsvAppend(line, tracked.parentEventId);
   CsvAppend(line, tracked.childFlipEventId);
   CsvAppend(line, IntegerToString(tracked.signalAgeBars));
   CsvAppend(line, BoolText(tracked.signalAgeBars <= InpChildFlipMaxSignalAgeBars));
   CsvAppend(line, "true");
   CsvAppend(line, "false");
   CsvAppend(line, IntegerToString(tracked.parentWave2Age));
   CsvAppend(line, tracked.childTrendBeforeFlip);
   CsvAppend(line, IntegerToString(tracked.parentWave2StartMode));
   CsvAppend(line, tracked.parentWave2StartReason);
   CsvAppend(line, IntegerToString(tracked.parentWave2StartDelayBars));
   CsvAppend(line, ChildAnchorModeName());
   CsvAppend(line, IntegerToString(tracked.childAnchorVersion));
   CsvAppend(line, IntegerToString(tracked.childAnchorUpdateCount));
   CsvAppend(line, DoubleToString(tracked.childFirstAnchorPrice, 8));
   CsvAppend(line, DoubleToString(tracked.childLatestAnchorPrice, 8));
   CsvAppend(line, DoubleToString(tracked.childAnchorUsedForFlip, 8));
   CsvAppend(line, BoolText(tracked.childAnchorIsLatestValid));
   CsvAppend(line, BoolText(tracked.childAnchorChangedAfterInitialDetection));
   CsvAppend(line, IntegerToString(tracked.childSwingCount));
   CsvAppend(line, IntegerToString(tracked.childExtensionCount));
   CsvAppend(line, BoolText(tracked.childCountertrendValidAtEntry));
   CsvAppend(line, tracked.childCountertrendRejectReason);
   CsvAppend(line, BoolText(tracked.childFlipIsFirstBreakAfterAnchor));
   CsvAppend(line, BoolText(tracked.childFlipIsFresh));
   CsvAppend(line, BoolText(tracked.signalValidationPass));
   CsvAppend(line, tracked.signalValidationRejectReason);
   CsvAppend(line, BoolText(tracked.signalReservedBeforePortfolio));
   CsvAppend(line, tracked.signalConsumptionStage);
   CsvAppend(line, "first_child_trend_flip_after_parent_wave2");
   CsvAppend(line, "none");
   CsvAppend(line, tracked.h1BiasState);
   CsvAppend(line, BoolText(tracked.h1Alignment));
   CsvAppend(line, tracked.h4BiasState);
   CsvAppend(line, BoolText(tracked.h4Alignment));
   CsvAppend(line, IntegerToString(tracked.fractalAlignmentCount));
   CsvAppend(line, BoolText(tracked.fullFractalAlignment));
   CsvAppend(line, tracked.sessionLabel);
   CsvAppend(line, IntegerToString(tracked.utcHour));
   CsvAppend(line, IntegerToString(tracked.weekday));
   CsvAppend(line, StopModeName());
   CsvAppend(line, DoubleToString(tracked.entryPrice, 8));
   CsvAppend(line, DoubleToString(exitPrice, 8));
   CsvAppend(line, DoubleToString(tracked.initialStop, 8));
   CsvAppend(line, DoubleToString(tracked.takeProfit, 8));
   CsvAppend(line, DoubleToString(tracked.riskPrice, 8));
   CsvAppend(line, DoubleToString(resultR, 6));
   CsvAppend(line, DoubleToString(tracked.maxFavorableR, 6));
   CsvAppend(line, DoubleToString(tracked.maxAdverseR, 6));
   CsvAppend(line, BoolText(tracked.reached05R));
   CsvAppend(line, BoolText(tracked.reached08R));
   CsvAppend(line, BoolText(tracked.reached10R));
   CsvAppend(line, BoolText(tracked.reached13R));
   CsvAppend(line, IntegerToString(tracked.barsTo05R));
   CsvAppend(line, IntegerToString(tracked.barsTo10R));
   CsvAppend(line, IntegerToString(tracked.barsTo13R));
   CsvAppend(line, exitType);
   CsvAppend(line, BoolText(exitType == "full_sl"));
   CsvAppend(line, BoolText(exitType == "tp"));
   CsvAppend(line, BoolText(exitType == "time"));
   CsvAppend(line, DoubleToString(profit, 2));
   CsvAppend(line, DoubleToString(commission, 2));
   CsvAppend(line, DoubleToString(swap, 2));
   CsvAppend(line, DoubleToString(profit + commission + swap, 2));
   CsvAppend(line, DoubleToString(tracked.volume, 4));
   CsvAppend(line, DoubleToString(InpTargetR, 2));
   CsvAppend(line, IntegerToString(holdingBars));
   CsvAppend(line, DoubleToString(tracked.atr, 8));
   CsvAppend(line, dealReason);
   FileWriteString(handle, line + "\r\n");
   FileClose(handle);
  }

void WriteFunnel()
  {
   EnsureLogFolder();
   int handle = FileOpen(LogFileName("funnel"), LogFlags(), ',');
   if(handle == INVALID_HANDLE) return;
   FileSeek(handle, 0, SEEK_SET);
   FileWriteString(handle, "run_id,stage,count\r\n");
   string stages[] = {"symbols_scanned","parent_anchor_states_available","parent_flips_detected","parent_wave1_confirmed","parent_wave2_pending","parent_wave2_started_first_close","parent_wave2_started_confirmed_pivot","parent_wave2_started_child_trend","child_countertrend_confirmed","child_anchor_created","child_anchor_updated","child_flip_detected","fresh_first_flip_signal","valid_candidate","signal_reserved","portfolio_selected","trades_taken","candidate_invalid","position_cap_reject","risk_reject","order_failure","expired","parent_invalidated","signals_consumed"};
   long values[] = {g_symbolsScanned,g_parentFlipsDetected,g_parentFlipsDetected,g_validParentWave1,g_parentWave2Pending,g_parentWave2StartedFirstClose,g_parentWave2StartedConfirmedPivot,g_parentWave2StartedChildTrend,g_childCountertrendConfirmed,g_childAnchorsCreated,g_childAnchorsUpdated,g_childTrendFlipsDetected,g_freshFirstFlipSignals,g_validCandidates,g_signalsReserved,g_portfolioSelected,g_tradesTaken,g_candidateInvalid,g_positionCapReject,g_riskReject,g_orderFailure,g_expiredSignals,g_parentWave2Invalidated,g_signalsConsumed};
   for(int i = 0; i < ArraySize(stages); ++i)
      FileWriteString(handle, "\"" + InpRunId + "\",\"" + stages[i] + "\",\"" + IntegerToString(values[i]) + "\"\r\n");
   FileClose(handle);

   handle = FileOpen(LogFileName("rejections"), LogFlags(), ',');
   if(handle != INVALID_HANDLE)
     {
      FileSeek(handle, 0, SEEK_SET);
      FileWriteString(handle, "run_id,reason,count\r\n");
      for(int i = 0; i < ArraySize(g_rejections); ++i)
         FileWriteString(handle, "\"" + InpRunId + "\",\"" + g_rejections[i].reason + "\",\"" + IntegerToString(g_rejections[i].count) + "\"\r\n");
      FileClose(handle);
     }
  }

void WriteSummary()
  {
   EnsureLogFolder();
   int handle = FileOpen(LogFileName("summary"), LogFlags(), ',');
   if(handle == INVALID_HANDLE) return;
   FileSeek(handle, 0, SEEK_SET);
   FileWriteString(handle, "run_id,run_mode,symbols,parent_tf,child_tf,top_context_tf,parent_wave2_start_mode,child_anchor_mode,symbols_scanned,parent_flips_detected,parent_wave1_confirmed,parent_wave2_pending,parent_wave2_started,parent_wave2_started_first_close,parent_wave2_started_confirmed_pivot,parent_wave2_started_child_trend,parent_wave2_invalidated,child_countertrend_confirmed,child_anchor_created,child_anchor_updated,child_trend_flips_detected,fresh_first_flip_signals,valid_candidates,signals_reserved,signals_consumed,portfolio_selected,trades_taken,candidate_invalid,position_cap_reject,risk_reject,order_failure,expired_signals,daily_stopped,drawdown_stopped\r\n");
   string line = "";
   CsvAppend(line, InpRunId);
   CsvAppend(line, RunModeName());
   CsvAppend(line, InpSymbols);
   CsvAppend(line, TFName(InpParentTF));
   CsvAppend(line, TFName(InpChildTF));
   CsvAppend(line, TFName(InpTopContextTF));
   CsvAppend(line, ParentWave2StartModeName());
   CsvAppend(line, ChildAnchorModeName());
   CsvAppend(line, IntegerToString(g_symbolsScanned));
   CsvAppend(line, IntegerToString(g_parentFlipsDetected));
   CsvAppend(line, IntegerToString(g_validParentWave1));
   CsvAppend(line, IntegerToString(g_parentWave2Pending));
   CsvAppend(line, IntegerToString(g_parentWave2Started));
   CsvAppend(line, IntegerToString(g_parentWave2StartedFirstClose));
   CsvAppend(line, IntegerToString(g_parentWave2StartedConfirmedPivot));
   CsvAppend(line, IntegerToString(g_parentWave2StartedChildTrend));
   CsvAppend(line, IntegerToString(g_parentWave2Invalidated));
   CsvAppend(line, IntegerToString(g_childCountertrendConfirmed));
   CsvAppend(line, IntegerToString(g_childAnchorsCreated));
   CsvAppend(line, IntegerToString(g_childAnchorsUpdated));
   CsvAppend(line, IntegerToString(g_childTrendFlipsDetected));
   CsvAppend(line, IntegerToString(g_freshFirstFlipSignals));
   CsvAppend(line, IntegerToString(g_validCandidates));
   CsvAppend(line, IntegerToString(g_signalsReserved));
   CsvAppend(line, IntegerToString(g_signalsConsumed));
   CsvAppend(line, IntegerToString(g_portfolioSelected));
   CsvAppend(line, IntegerToString(g_tradesTaken));
   CsvAppend(line, IntegerToString(g_candidateInvalid));
   CsvAppend(line, IntegerToString(g_positionCapReject));
   CsvAppend(line, IntegerToString(g_riskReject));
   CsvAppend(line, IntegerToString(g_orderFailure));
   CsvAppend(line, IntegerToString(g_expiredSignals));
   CsvAppend(line, BoolText(g_dailyStopped));
   CsvAppend(line, BoolText(g_drawdownStopped));
   FileWriteString(handle, line + "\r\n");
   FileClose(handle);
   WriteFunnel();
  }

bool ParseSymbols()
  {
   string parts[];
   int count = StringSplit(InpSymbols, ',', parts);
   if(count <= 0) return false;
   ArrayResize(g_symbols, 0);
   for(int i = 0; i < count; ++i)
     {
      StringTrimLeft(parts[i]);
      StringTrimRight(parts[i]);
      if(parts[i] == "" || !SymbolSelect(parts[i], true)) continue;
      int size = ArraySize(g_symbols);
      ArrayResize(g_symbols, size + 1);
      g_symbols[size] = parts[i];
     }
   ArrayResize(g_states, ArraySize(g_symbols));
   for(int i = 0; i < ArraySize(g_symbols); ++i)
      ResetState(g_states[i], g_symbols[i]);
   return ArraySize(g_symbols) > 0;
  }

void ScanSymbols()
  {
   UpdateRiskAnchors();
   ManageTrades();
   EntryCandidate candidates[];
   ArrayResize(candidates, 0);
   for(int i = 0; i < ArraySize(g_states); ++i)
     {
      MqlRates latest[];
      if(!CopyClosedRates(g_states[i].symbol, InpChildTF, 1, latest))
         continue;
      if(latest[0].time <= g_states[i].lastM5Bar)
         continue;
      g_states[i].lastM5Bar = latest[0].time;
      ++g_symbolsScanned;
      UpdateParentState(g_states[i], latest[0].time);
      UpdateChildTrend(g_states[i], latest[0].time);
      EntryCandidate candidate;
      if(BuildCandidate(i, candidate))
        {
         int size = ArraySize(candidates);
         ArrayResize(candidates, size + 1);
         candidates[size] = candidate;
        }
     }
   if(ArraySize(candidates) == 0)
      return;
   if(InpPortfolioMode == PORTFOLIO_ONE_SYMBOL_PER_BAR)
     {
      int best = 0;
      for(int i = 1; i < ArraySize(candidates); ++i)
         if(candidates[i].score > candidates[best].score) best = i;
      for(int i = 0; i < ArraySize(candidates); ++i)
         if(i != best)
           {
            AddRejection("portfolio_not_selected");
            FinalizeSignal(g_states[candidates[i].stateIndex], TimeCurrent(),
                           "before_portfolio", "portfolio_not_selected");
           }
      OpenCandidate(candidates[best]);
      return;
     }
   for(int i = 0; i < ArraySize(candidates); ++i)
      OpenCandidate(candidates[i]);
  }

int OnInit()
  {
   if(InpParentTF != PERIOD_M15 || InpChildTF != PERIOD_M5 || InpTopContextTF != PERIOD_H1 ||
      InpPivotDepth < 1 || InpATRPeriod < 2 || InpParentWave1MaxBars < 1 ||
      InpParentWave2MaxBars < 1 || InpChildFlipMaxSignalAgeBars < 0 || InpTargetR <= 0.0 ||
      InpRiskPerTradePercent <= 0.0 || InpMaxRiskPerSymbolPercent <= 0.0 ||
      InpMaxTotalOpenRiskPercent <= 0.0 || InpMaxPositions < 1)
      return INIT_PARAMETERS_INCORRECT;
   if(!ParseSymbols())
      return INIT_FAILED;
   g_initialEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_peakEquity = g_initialEquity;
   g_dayStartEquity = g_initialEquity;
   g_dayKey = DateKey(TimeCurrent());
   trade.SetExpertMagicNumber(InpMagicNumber);
   EnsureLogFolder();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   WriteSummary();
  }

void OnTick()
  {
   ScanSymbols();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || !HistoryDealSelect(trans.deal))
      return;
   if((long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagicNumber)
      return;
   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT && entry != DEAL_ENTRY_OUT_BY)
      return;
   long positionId = (long)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   int index = FindTracked(positionId);
   if(index < 0) return;
   double exitPrice = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
   double commission = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   double swap = HistoryDealGetDouble(trans.deal, DEAL_SWAP);
   datetime exitTime = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
   string dealReason = EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON));
   WriteTradeRow(g_trades[index], exitTime, exitPrice, profit, commission, swap, dealReason);
   g_trades[index].active = false;
  }
