//+------------------------------------------------------------------+
//| Strategy_01_NWave_ExpectedValue                                  |
//| ExpectedValue_NWave_Scalper                                      |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Expected-value N-wave reversal scalper. Phase 1-2: detection, virtual trade logging, SL/TP/RR, risk lots."

#include <Trade\Trade.mqh>

CTrade trade;

static const string STRATEGY_NAME = "Strategy_01_NWave_ExpectedValue";
static const int    DIR_LONG      = 1;
static const int    DIR_SHORT     = -1;

enum ExtensionFilterMode
  {
   FILTER_ANY = 0,
   FILTER_ALL = 1
  };

enum ExitSimulationMode
  {
   EXIT_FIXED_R_ONLY = 0,
   EXIT_BE_AT_05R = 1,
   EXIT_BE_AT_08R = 2,
   EXIT_BE_AT_10R = 3,
   EXIT_PARTIAL_50_AT_05R_REST_15R = 4,
   EXIT_PARTIAL_50_AT_10R_REST_15R = 5,
   EXIT_TP_12R_FIXED = 6,
   EXIT_TP_15R_FIXED = 7
  };

enum TrendAlignmentFilterOption
  {
   TREND_ALIGN_ANY = 0,
   TREND_ALIGN_COUNTERTREND = 1,
   TREND_ALIGN_TRENDFOLLOW = 2,
   TREND_ALIGN_MIXEDTREND = 3
  };

enum DiagnosticBucketFilterOption
  {
   BUCKET_ANY = 0,
   BUCKET_LOW = 1,
   BUCKET_MIDDLE = 2,
   BUCKET_HIGH = 3
  };

enum DirectionFilterOption
  {
   DIRECTION_ANY = 0,
   DIRECTION_LONG_ONLY = 1,
   DIRECTION_SHORT_ONLY = 2
  };

enum StrategyMode
  {
   STRATEGY_01_ORIGINAL = 0,
   STRATEGY_01B_C_SHORT = 1,
   STRATEGY_01B_J_SHORT = 2
  };

input bool            EnableTrading                = false;
input long            MagicNumber                  = 2026051201;
input double          RiskPercent                  = 0.5;
input double          DailyMaxLossPercent          = 3.0;
input int             MaxConsecutiveLosses         = 3;
input int             MaxManagedPositions          = 1;
input StrategyMode    SelectedStrategyMode         = STRATEGY_01_ORIGINAL;
input ENUM_TIMEFRAMES ContextTF                    = PERIOD_H4;
input ENUM_TIMEFRAMES PatternTF                    = PERIOD_M15;
input ENUM_TIMEFRAMES EntryTF                      = PERIOD_M5;
input int             SwingDepth                   = 2;
input int             ContextScanBars              = 260;
input int             PatternScanBars              = 220;
input int             EntryScanBars                = 160;
input double          DoubleTopBottomToleranceATR  = 0.25;
input double          NecklineBreakBufferATR       = 0.05;
input double          SLBufferATR                  = 0.15;
input double          TakeProfitRMultiple          = 1.5;
input double          MinRR                        = 1.2;
input double          MaxSpreadPoints              = 50.0;
input bool            UseTradingSession            = false;
input int             SessionStartHour             = 0;
input int             SessionEndHour               = 24;
input bool            UseFiboExtensionFilter       = true;
input double          FiboExtensionMin             = 161.8;
input bool            UseATRExpansionFilter        = true;
input ExtensionFilterMode ExtensionFilterModeInput = FILTER_ALL;
input int             ATRPeriod                    = 14;
input double          MinATRPoints                 = 100.0;
input int             EMAShortPeriod               = 20;
input int             EMALongPeriod                = 50;
input int             EMASlopeBars                 = 3;
input double          EMAFlatSlopeATR              = 0.05;
input int             ADXPeriod                    = 14;
input double          ADXLowThreshold              = 20.0;
input double          ADXHighThreshold             = 30.0;
input int             ATRPercentileLookback        = 200;
input double          ATRLowPercentile             = 30.0;
input double          ATRHighPercentile            = 70.0;
input double          BreakBodyMiddleATR           = 0.25;
input double          BreakBodyStrongATR           = 0.50;
input int             DuplicateLookbackBars        = 3;
input ExitSimulationMode ExitSimulationModeInput   = EXIT_FIXED_R_ONLY;
input bool            UseTrendAlignmentFilter      = false;
input TrendAlignmentFilterOption AllowedTrendAlignmentTag = TREND_ALIGN_ANY;
input bool            UsePatternADXBucketFilter    = false;
input DiagnosticBucketFilterOption AllowedPatternADXBucket = BUCKET_ANY;
input bool            UseBreakCandleStrengthFilter = false;
input DiagnosticBucketFilterOption AllowedBreakCandleStrengthBucket = BUCKET_ANY;
input bool            UseEntryOpenCountFilter      = false;
input int             MaxEntryOpenCount            = 1;
input bool            UseDirectionFilter           = false;
input DirectionFilterOption AllowedDirection        = DIRECTION_ANY;
input double          MaxTotalOpenRiskPercent      = 1.0;
input double          MaxDailyLossR                = 2.0;
input double          MaxWeeklyLossR               = 5.0;
input double          MaxMonthlyLossR              = 8.0;
input double          StopTradingAfterMaxDD_R      = 0.0;
input bool            UseEquityCurveGuard          = true;
input int             MinBarsBetweenEntries        = 0;
input bool            AllowOnlyOnePositionForStrategy01B = true;
input bool            InpBlockUnsafeForwardDemoSettings = true;
input bool            InpBlockNonDemoAccountForForwardDemo = true;
input bool            InpUseDrawdownPercentGuards = true;
input double          SoftPauseDrawdownPercent     = 8.0;
input int             SoftPauseCooldownDays        = 5;
input double          HardStopDrawdownPercent      = 12.0;
input double          EmergencyStopDrawdownPercent = 15.0;
input bool            RequireManualResetAfterHardStop = true;
input bool            RequireManualResetAfterEmergencyStop = true;
input bool            InpResetDrawdownGuardState   = false;
input bool            InpUseSmallCapitalChallengeMode = false;
input bool            SmallCapitalRequireUsdAccount = true;
input bool            SmallCapitalUseEquityInsteadOfBalance = true;
input double          SmallCapitalTier1EquityUsd = 1000.0;
input double          SmallCapitalTier2EquityUsd = 10000.0;
input double          SmallCapitalTier1RiskPercent = 10.0;
input double          SmallCapitalTier2RiskPercent = 5.0;
input double          SmallCapitalTier3RiskPercent = 1.0;
input double          SmallCapitalMaxEffectiveRiskPercent = 15.0;
input bool            SmallCapitalAllowMinLotOverride = true;
input bool            SmallCapitalBlockIfEffectiveRiskTooHigh = true;
input bool            SmallCapitalUseChallengeDDGuards = true;
input double          SmallCapitalSoftPauseDDPercent = 40.0;
input double          SmallCapitalHardStopDDPercent = 70.0;
input double          SmallCapitalRuinDDPercent = 95.0;
input bool            InpUseUsd100ChallengeMode = false;
input double          Usd100ChallengeInitialBalance = 100.0;
input bool            Usd100UseMinLotOnly = true;
input double          Usd100MaxLot = 0.01;
input double          Usd100MaxEffectiveRiskPercent = 10.0;
input double          Usd100HardBlockEffectiveRiskPercent = 15.0;
input bool            Usd100BlockIfMarginInsufficient = true;
input bool            Usd100BlockIfEffectiveRiskTooHigh = true;
input double          Usd100SoftPauseDDPercent = 40.0;
input double          Usd100HardStopDDPercent = 70.0;
input double          Usd100RuinDDPercent = 95.0;
input bool            ConservativeSameBarExit      = true;
input bool            LogToCSV                     = true;
input bool            DrawObjects                  = true;
input bool            DebugMode                    = false;

struct SwingPoint
  {
   bool     valid;
   bool     isHigh;
   int      shift;
   double   price;
   datetime time;
  };

struct NWaveContext
  {
   bool        valid;
   int         direction;
   string      sourceTimeframe;
   SwingPoint  p1;
   SwingPoint  p2;
   SwingPoint  p3;
   SwingPoint  p4;
   double      firstLeg;
   double      activeLeg;
   double      fibExtensionValue;
   double      atrValue;
   string      filterReason;
   bool        contextFilterPassed;
   bool        fiboFilterPassed;
   bool        atrFilterPassed;
  };

struct PatternSetup
  {
   bool        valid;
   int         direction;
   string      patternType;
   SwingPoint  left;
   SwingPoint  right;
   SwingPoint  necklinePivot;
   double      necklinePrice;
   double      atrValue;
  };

struct TradePlan
  {
   bool        valid;
   int         direction;
   string      directionLabel;
   string      strategyName;
   string      setupId;
   string      contextTimeframe;
   string      patternTimeframe;
   string      entryTimeframe;
   string      sessionName;
   datetime    signalTime;
   datetime    signalBarTime;
   datetime    entryTime;
   datetime    entryBarTime;
   datetime    exitBarTime;
   double      signalPrice;
   double      entryPrice;
   double      stopLoss;
   double      takeProfit;
   double      riskPoints;
   double      rewardPoints;
   double      rr;
   double      lotSize;
   double      plannedRiskMoney;
   double      riskPercent;
   string      patternType;
   double      necklinePrice;
   double      leftPeakOrBottom;
   double      rightPeakOrBottom;
   double      fibExtensionValue;
   double      atrValue;
   double      spreadPoints;
   bool        contextFilterPassed;
   bool        fiboFilterPassed;
   bool        atrFilterPassed;
   bool        spreadFilterPassed;
   bool        isExecutable;
   string      entryReason;
   string      rejectReason;
   string      filterMode;
   string      contextFilterReason;
   double      contextEMAShort;
   double      contextEMALong;
   bool        contextEMAShortAboveLong;
   double      contextEMAShortSlopeATR;
   double      contextEMALongSlopeATR;
   string      contextPriceVsEMAShort;
   string      contextPriceVsEMALong;
   string      htfTrendState;
   double      patternADX;
   double      entryADX;
   string      patternADXBucket;
   string      entryADXBucket;
   string      patternDIDirection;
   string      entryDIDirection;
   double      patternATRValue;
   double      entryATRValue;
   double      patternATRPercentile;
   double      entryATRPercentile;
   string      patternATRBucket;
   string      entryATRBucket;
   double      slDistanceATR;
   double      tpDistanceATR;
   double      doubleTopBottomHeightATR;
   double      necklineDistanceATR;
   double      rightPeakDepthATR;
   double      leftRightSymmetryRatio;
   double      breakCandleBodyATR;
   double      breakCandleClosePosition;
   double      breakCandleDirectionStrength;
   string      breakCandleStrengthBucket;
   bool        contextDirectionAligned;
   string      trendAlignmentTag;
   int         entryOpenCount;
   int         sameDirectionOpenCount;
   int         oppositeDirectionOpenCount;
   int         barsSinceLastEntry;
   bool        approximateDuplicateSetup;
   int         holdingBars;
   datetime    setupTime;
   string      setupKey;
   string      comment;
   bool        smallCapitalMode;
   string      accountCurrency;
   double      accountBalance;
   double      accountEquity;
   string      selectedSmallCapitalTier;
   double      selectedRiskPercent;
   double      desiredRiskMoneyUsd;
   double      calculatedLotBeforeRounding;
   double      minLot;
   double      lotStep;
   double      finalLot;
   string      finalLotReason;
   double      actualRiskMoneyAtFinalLotUsd;
   double      effectiveRiskPercentAtFinalLot;
   double      marginRequired;
   double      freeMargin;
   double      freeMarginAfterEntryEstimate;
   bool        usd100ChallengeMode;
   string      usd100RiskWarning;
  };

struct ManagedTrade
  {
   bool      active;
   bool      live;
   ulong     positionId;
   ulong     entryDealTicket;
   TradePlan plan;
   datetime  entryTime;
   datetime  orderSendTime;
   datetime  actualEntryDealTime;
   double    actualEntryDealPrice;
   double    entryCommission;
   double    entrySwap;
   double    entrySpreadPoints;
   double    riskMoney;
   double    mfeR;
   double    maeR;
  };

struct ExitSimulationTrade
  {
   bool               active;
   ExitSimulationMode mode;
   TradePlan          plan;
   double             targetR;
   double             beTriggerR;
   double             partialTriggerR;
   double             partialFraction;
   double             realizedR;
   double             remainingFraction;
   bool               beArmed;
   bool               partialTaken;
   double             mfeR;
   double             maeR;
  };

string        runtimeSymbol = "";
double        runtimePoint = 0.0;
int           runtimeDigits = 0;
int           atrContextHandle = INVALID_HANDLE;
int           atrPatternHandle = INVALID_HANDLE;
int           atrEntryHandle = INVALID_HANDLE;
int           emaContextShortHandle = INVALID_HANDLE;
int           emaContextLongHandle = INVALID_HANDLE;
int           adxPatternHandle = INVALID_HANDLE;
int           adxEntryHandle = INVALID_HANDLE;
datetime      lastEntryBarTime = 0;
datetime      lastAcceptedEntryBarTime = 0;
string        lastLoggedSetupKey = "";
int           telemetryHandle = INVALID_HANDLE;
string        telemetryFileName = "";
int           exitSimulationHandle = INVALID_HANDLE;
string        exitSimulationFileName = "";
ManagedTrade  managedTrades[];
ExitSimulationTrade exitSimulationTrades[];
double        dailyStartEquity = 0.0;
double        virtualDailyProfit = 0.0;
int           dailyKey = 0;
int           weeklyKey = 0;
int           monthlyKey = 0;
double        dailyProfitR = 0.0;
double        weeklyProfitR = 0.0;
double        monthlyProfitR = 0.0;
int           consecutiveLosses = 0;
int           statTotalTrades = 0;
int           statWinTrades = 0;
int           statLossTrades = 0;
int           statLongTrades = 0;
int           statShortTrades = 0;
int           statCurrentLossStreak = 0;
int           statMaxConsecutiveLosses = 0;
double        statGrossWinR = 0.0;
double        statGrossLossR = 0.0;
double        statTotalR = 0.0;
double        statLongR = 0.0;
double        statShortR = 0.0;
double        statEquityCurveR = 0.0;
double        statEquityPeakR = 0.0;
double        statMaxDrawdownR = 0.0;
double        accountInitialEquity = 0.0;
double        accountPeakEquity = 0.0;
double        currentDrawdownPercent = 0.0;
double        maxDrawdownPercent = 0.0;
int           drawdownGuardState = 0;
datetime      softPauseStartTime = 0;
string        drawdownGuardReason = "";
bool          summaryWritten = false;
string        forwardDemoRunId = "";
string        forwardDemoPreflightFileName = "";
string        forwardDemoPreflightStatus = "";
string        forwardDemoPreflightWarnings = "";
bool          forwardDemoUnsafeSettings = false;
bool          csvLogOutputFailed = false;
bool          stopConditionTriggered = false;
string        stopReason = "";
int           dailyTotalSignals = 0;
int           dailyLiveEntries = 0;
int           dailyClosedTrades = 0;
int           dailyWinTrades = 0;
int           dailyLossTrades = 0;
double        dailyGrossWinR = 0.0;
double        dailyGrossLossR = 0.0;
double        dailyRealizedProfitR = 0.0;
double        dailyRealizedProfitMoney = 0.0;
double        dailyEquityCurveR = 0.0;
double        dailyEquityPeakR = 0.0;
double        dailyMaxDrawdownR = 0.0;
double        dailyEquityCurveMoney = 0.0;
double        dailyEquityPeakMoney = 0.0;
double        dailyMaxDrawdownMoney = 0.0;
int           dailyLiveOrderSendFailedCount = 0;
int           dailyLivePositionTrackingFailedCount = 0;
int           dailyLiveSLTPInvalidCount = 0;
int           dailyLiveLotInvalidCount = 0;
int           liveOrderSendFailedStreak = 0;
string        dailyRejectReasons[];
int           dailyRejectCounts[];
int           dealLevelHandle = INVALID_HANDLE;
string        dealLevelFileName = "";
double        smallCapitalStartBalanceUsd = 0.0;
double        smallCapitalCurrentBalanceUsd = 0.0;
double        smallCapitalCurrentEquityUsd = 0.0;
double        smallCapitalPeakEquityUsd = 0.0;
double        smallCapitalMinEquityUsd = 0.0;
double        smallCapitalMaxDrawdownPercent = 0.0;
double        smallCapitalMinMarginLevel = 0.0;
bool          smallCapitalRuinTriggered = false;
string        smallCapitalRuinReason = "";
int           smallCapitalConsecutiveMarginInsufficient = 0;

void ResetSwing(SwingPoint &point)
  {
   point.valid = false;
   point.isHigh = false;
   point.shift = -1;
   point.price = 0.0;
   point.time = 0;
  }

void ResetNWave(NWaveContext &ctx)
  {
   ctx.valid = false;
   ctx.direction = 0;
   ctx.sourceTimeframe = "";
   ResetSwing(ctx.p1);
   ResetSwing(ctx.p2);
   ResetSwing(ctx.p3);
   ResetSwing(ctx.p4);
   ctx.firstLeg = 0.0;
   ctx.activeLeg = 0.0;
   ctx.fibExtensionValue = 0.0;
   ctx.atrValue = 0.0;
   ctx.filterReason = "";
   ctx.contextFilterPassed = false;
   ctx.fiboFilterPassed = false;
   ctx.atrFilterPassed = false;
  }

void ResetPattern(PatternSetup &setup)
  {
   setup.valid = false;
   setup.direction = 0;
   setup.patternType = "";
   ResetSwing(setup.left);
   ResetSwing(setup.right);
   ResetSwing(setup.necklinePivot);
   setup.necklinePrice = 0.0;
   setup.atrValue = 0.0;
  }

void ResetTradePlan(TradePlan &plan)
  {
   plan.valid = false;
   plan.direction = 0;
   plan.directionLabel = "";
   plan.strategyName = STRATEGY_NAME;
   plan.setupId = "";
   plan.contextTimeframe = "";
   plan.patternTimeframe = "";
   plan.entryTimeframe = "";
   plan.sessionName = "";
   plan.signalTime = 0;
   plan.signalBarTime = 0;
   plan.entryTime = 0;
   plan.entryBarTime = 0;
   plan.exitBarTime = 0;
   plan.signalPrice = 0.0;
   plan.entryPrice = 0.0;
   plan.stopLoss = 0.0;
   plan.takeProfit = 0.0;
   plan.riskPoints = 0.0;
   plan.rewardPoints = 0.0;
   plan.rr = 0.0;
   plan.lotSize = 0.0;
   plan.plannedRiskMoney = 0.0;
   plan.riskPercent = RiskPercent;
   plan.patternType = "";
   plan.necklinePrice = 0.0;
   plan.leftPeakOrBottom = 0.0;
   plan.rightPeakOrBottom = 0.0;
   plan.fibExtensionValue = 0.0;
   plan.atrValue = 0.0;
   plan.spreadPoints = 0.0;
   plan.contextFilterPassed = false;
   plan.fiboFilterPassed = false;
   plan.atrFilterPassed = false;
   plan.spreadFilterPassed = false;
   plan.isExecutable = false;
   plan.entryReason = "";
   plan.rejectReason = "";
   plan.filterMode = "";
   plan.contextFilterReason = "";
   plan.contextEMAShort = 0.0;
   plan.contextEMALong = 0.0;
   plan.contextEMAShortAboveLong = false;
   plan.contextEMAShortSlopeATR = 0.0;
   plan.contextEMALongSlopeATR = 0.0;
   plan.contextPriceVsEMAShort = "";
   plan.contextPriceVsEMALong = "";
   plan.htfTrendState = "";
   plan.patternADX = 0.0;
   plan.entryADX = 0.0;
   plan.patternADXBucket = "";
   plan.entryADXBucket = "";
   plan.patternDIDirection = "";
   plan.entryDIDirection = "";
   plan.patternATRValue = 0.0;
   plan.entryATRValue = 0.0;
   plan.patternATRPercentile = 0.0;
   plan.entryATRPercentile = 0.0;
   plan.patternATRBucket = "";
   plan.entryATRBucket = "";
   plan.slDistanceATR = 0.0;
   plan.tpDistanceATR = 0.0;
   plan.doubleTopBottomHeightATR = 0.0;
   plan.necklineDistanceATR = 0.0;
   plan.rightPeakDepthATR = 0.0;
   plan.leftRightSymmetryRatio = 0.0;
   plan.breakCandleBodyATR = 0.0;
   plan.breakCandleClosePosition = 0.0;
   plan.breakCandleDirectionStrength = 0.0;
   plan.breakCandleStrengthBucket = "";
   plan.contextDirectionAligned = false;
   plan.trendAlignmentTag = "";
   plan.entryOpenCount = 0;
   plan.sameDirectionOpenCount = 0;
   plan.oppositeDirectionOpenCount = 0;
   plan.barsSinceLastEntry = -1;
   plan.approximateDuplicateSetup = false;
   plan.holdingBars = 0;
   plan.setupTime = 0;
   plan.setupKey = "";
   plan.comment = "";
   plan.smallCapitalMode = false;
   plan.accountCurrency = "";
   plan.accountBalance = 0.0;
   plan.accountEquity = 0.0;
   plan.selectedSmallCapitalTier = "";
   plan.selectedRiskPercent = RiskPercent;
   plan.desiredRiskMoneyUsd = 0.0;
   plan.calculatedLotBeforeRounding = 0.0;
   plan.minLot = 0.0;
   plan.lotStep = 0.0;
   plan.finalLot = 0.0;
   plan.finalLotReason = "";
   plan.actualRiskMoneyAtFinalLotUsd = 0.0;
   plan.effectiveRiskPercentAtFinalLot = 0.0;
   plan.marginRequired = 0.0;
   plan.freeMargin = 0.0;
   plan.freeMarginAfterEntryEstimate = 0.0;
   plan.usd100ChallengeMode = false;
   plan.usd100RiskWarning = "";
  }

string TimeframeToString(ENUM_TIMEFRAMES tf)
  {
   switch(tf)
     {
      case PERIOD_M1:  return "M1";
      case PERIOD_M2:  return "M2";
      case PERIOD_M3:  return "M3";
      case PERIOD_M4:  return "M4";
      case PERIOD_M5:  return "M5";
      case PERIOD_M6:  return "M6";
      case PERIOD_M10: return "M10";
      case PERIOD_M12: return "M12";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H3:  return "H3";
      case PERIOD_H4:  return "H4";
      case PERIOD_H6:  return "H6";
      case PERIOD_H8:  return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return IntegerToString((int)tf);
     }
  }

string DirectionLabel(int direction)
  {
   if(direction > 0)
      return "LONG";
   if(direction < 0)
      return "SHORT";
   return "NONE";
  }

string FilterModeLabel()
  {
   return (ExtensionFilterModeInput == FILTER_ALL) ? "FILTER_ALL" : "FILTER_ANY";
  }

string ExitSimulationModeLabel(ExitSimulationMode mode)
  {
   switch(mode)
     {
      case EXIT_FIXED_R_ONLY:                  return "EXIT_FIXED_R_ONLY";
      case EXIT_BE_AT_05R:                     return "EXIT_BE_AT_05R";
      case EXIT_BE_AT_08R:                     return "EXIT_BE_AT_08R";
      case EXIT_BE_AT_10R:                     return "EXIT_BE_AT_10R";
      case EXIT_PARTIAL_50_AT_05R_REST_15R:    return "EXIT_PARTIAL_50_AT_05R_REST_15R";
      case EXIT_PARTIAL_50_AT_10R_REST_15R:    return "EXIT_PARTIAL_50_AT_10R_REST_15R";
      case EXIT_TP_12R_FIXED:                  return "EXIT_TP_12R_FIXED";
      case EXIT_TP_15R_FIXED:                  return "EXIT_TP_15R_FIXED";
     }
   return "UNKNOWN";
  }

string TrendAlignmentOptionLabel(TrendAlignmentFilterOption option)
  {
   switch(option)
     {
      case TREND_ALIGN_ANY:          return "Any";
      case TREND_ALIGN_COUNTERTREND: return "CounterTrend";
      case TREND_ALIGN_TRENDFOLLOW:  return "TrendFollow";
      case TREND_ALIGN_MIXEDTREND:   return "MixedTrend";
     }
   return "Any";
  }

string BucketOptionLabel(DiagnosticBucketFilterOption option)
  {
   switch(option)
     {
      case BUCKET_ANY:    return "Any";
      case BUCKET_LOW:    return "low";
      case BUCKET_MIDDLE: return "middle";
      case BUCKET_HIGH:   return "high";
     }
   return "Any";
  }

string DirectionOptionLabel(DirectionFilterOption option)
  {
   switch(option)
     {
      case DIRECTION_ANY:        return "Any";
      case DIRECTION_LONG_ONLY:  return "LongOnly";
      case DIRECTION_SHORT_ONLY: return "ShortOnly";
     }
   return "Any";
  }

string StrategyModeLabel(StrategyMode mode)
  {
   switch(mode)
     {
      case STRATEGY_01_ORIGINAL: return "STRATEGY_01_ORIGINAL";
      case STRATEGY_01B_C_SHORT: return "STRATEGY_01B_C_SHORT";
      case STRATEGY_01B_J_SHORT: return "STRATEGY_01B_J_SHORT";
     }
   return "STRATEGY_01_ORIGINAL";
  }

bool IsStrategy01BMode()
  {
   return (SelectedStrategyMode == STRATEGY_01B_C_SHORT ||
           SelectedStrategyMode == STRATEGY_01B_J_SHORT);
  }

double EffectiveTakeProfitRMultiple()
  {
   if(IsStrategy01BMode())
      return 1.5;
   return TakeProfitRMultiple;
  }

string BoolLabel(bool value)
  {
   return value ? "1" : "0";
  }

string BoolWord(bool value)
  {
   return value ? "true" : "false";
  }

string AccountTradeModeLabel()
  {
   ENUM_ACCOUNT_TRADE_MODE mode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(mode == ACCOUNT_TRADE_MODE_DEMO)
      return "demo";
   if(mode == ACCOUNT_TRADE_MODE_CONTEST)
      return "contest";
   if(mode == ACCOUNT_TRADE_MODE_REAL)
      return "real";
   return "unknown";
  }

bool IsDemoAccount()
  {
   return ((ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO);
  }

bool IsUsdAccount()
  {
   return (AccountInfoString(ACCOUNT_CURRENCY) == "USD");
  }

bool IsAnySmallCapitalMode()
  {
   return (InpUseSmallCapitalChallengeMode || InpUseUsd100ChallengeMode);
  }

double SmallCapitalRiskBaseMoney()
  {
   return SmallCapitalUseEquityInsteadOfBalance ? AccountInfoDouble(ACCOUNT_EQUITY)
                                                : AccountInfoDouble(ACCOUNT_BALANCE);
  }

string SmallCapitalTierLabel(double baseMoney)
  {
   if(baseMoney < SmallCapitalTier1EquityUsd)
      return "tier1_under_1000";
   if(baseMoney < SmallCapitalTier2EquityUsd)
      return "tier2_1000_to_10000";
   return "tier3_10000_plus";
  }

double EffectiveRiskPercent()
  {
   if(InpUseUsd100ChallengeMode)
      return 0.0;
   if(!InpUseSmallCapitalChallengeMode)
      return RiskPercent;

   double baseMoney = SmallCapitalRiskBaseMoney();
   if(baseMoney < SmallCapitalTier1EquityUsd)
      return SmallCapitalTier1RiskPercent;
   if(baseMoney < SmallCapitalTier2EquityUsd)
      return SmallCapitalTier2RiskPercent;
   return SmallCapitalTier3RiskPercent;
  }

bool Usd100UsesFixedMinLot(double baseMoney)
  {
   return (InpUseUsd100ChallengeMode && (Usd100UseMinLotOnly || baseMoney < 1000.0));
  }

string Usd100TierLabel(double baseMoney)
  {
   if(Usd100UsesFixedMinLot(baseMoney))
      return "usd100_fixed_min_lot_under_1000";
   if(baseMoney < 10000.0)
      return "usd100_hybrid_1000_to_10000";
   return "usd100_hybrid_10000_plus";
  }

double Usd100HybridRiskPercent(double baseMoney)
  {
   if(Usd100UsesFixedMinLot(baseMoney))
      return 0.0;
   if(baseMoney < 10000.0)
      return SmallCapitalTier2RiskPercent;
   return SmallCapitalTier3RiskPercent;
  }

void AppendWarning(string &warnings, string warning)
  {
   if(warning == "")
      return;
   if(warnings != "")
      warnings += "|";
   warnings += warning;
  }

string TimestampForFile(datetime stamp)
  {
   string value = TimeToString(stamp, TIME_DATE | TIME_SECONDS);
   StringReplace(value, ".", "");
   StringReplace(value, ":", "");
   StringReplace(value, " ", "_");
   return value;
  }

string DailyKeyToString(int key)
  {
   return IntegerToString(key);
  }

string CurrentStrategyModeForSummary()
  {
   return StrategyModeLabel(SelectedStrategyMode);
  }

void SetStopCondition(string reason)
  {
   if(reason == "")
      return;
   if(!stopConditionTriggered)
     {
      stopConditionTriggered = true;
      stopReason = reason;
      Print("Forward demo stop condition triggered: ", reason);
     }
  }

void ResetDailySummaryCounters()
  {
   dailyTotalSignals = 0;
   dailyLiveEntries = 0;
   dailyClosedTrades = 0;
   dailyWinTrades = 0;
   dailyLossTrades = 0;
   dailyGrossWinR = 0.0;
   dailyGrossLossR = 0.0;
   dailyRealizedProfitR = 0.0;
   dailyRealizedProfitMoney = 0.0;
   dailyEquityCurveR = 0.0;
   dailyEquityPeakR = 0.0;
   dailyMaxDrawdownR = 0.0;
   dailyEquityCurveMoney = 0.0;
   dailyEquityPeakMoney = 0.0;
   dailyMaxDrawdownMoney = 0.0;
   dailyLiveOrderSendFailedCount = 0;
   dailyLivePositionTrackingFailedCount = 0;
   dailyLiveSLTPInvalidCount = 0;
   dailyLiveLotInvalidCount = 0;
   liveOrderSendFailedStreak = 0;
   stopConditionTriggered = false;
   stopReason = "";
   ArrayResize(dailyRejectReasons, 0);
   ArrayResize(dailyRejectCounts, 0);
  }

void IncrementDailyRejectReason(string reason)
  {
   if(reason == "")
      reason = "blank";

   int size = ArraySize(dailyRejectReasons);
   for(int i = 0; i < size; ++i)
     {
      if(dailyRejectReasons[i] == reason)
        {
         dailyRejectCounts[i]++;
         return;
        }
     }

   ArrayResize(dailyRejectReasons, size + 1);
   ArrayResize(dailyRejectCounts, size + 1);
   dailyRejectReasons[size] = reason;
   dailyRejectCounts[size] = 1;
  }

string TopRejectReasonLabel(int rank)
  {
   int size = ArraySize(dailyRejectReasons);
   if(rank <= 0 || size <= 0)
      return "";

   string used[];
   ArrayResize(used, 0);
   for(int currentRank = 1; currentRank <= rank; ++currentRank)
     {
      int bestIndex = -1;
      int bestCount = -1;
      for(int i = 0; i < size; ++i)
        {
         bool alreadyUsed = false;
         int usedSize = ArraySize(used);
         for(int j = 0; j < usedSize; ++j)
           {
            if(used[j] == dailyRejectReasons[i])
              {
               alreadyUsed = true;
               break;
              }
           }
         if(alreadyUsed)
            continue;
         if(dailyRejectCounts[i] > bestCount)
           {
            bestCount = dailyRejectCounts[i];
            bestIndex = i;
           }
        }
      if(bestIndex < 0)
         return "";
      int usedSize = ArraySize(used);
      ArrayResize(used, usedSize + 1);
      used[usedSize] = dailyRejectReasons[bestIndex];
      if(currentRank == rank)
         return dailyRejectReasons[bestIndex] + "=" + IntegerToString(dailyRejectCounts[bestIndex]);
     }
   return "";
  }

void EvaluateRStopConditions()
  {
   if(MaxDailyLossR > 0.0 && dailyProfitR <= -MaxDailyLossR)
      SetStopCondition("daily_loss_r_reached");
   if(MaxWeeklyLossR > 0.0 && weeklyProfitR <= -MaxWeeklyLossR)
      SetStopCondition("weekly_loss_r_reached");
   if(MaxMonthlyLossR > 0.0 && monthlyProfitR <= -MaxMonthlyLossR)
      SetStopCondition("monthly_loss_r_reached");
  }

string DrawdownGuardGlobalKey()
  {
   return "EVNS_" + runtimeSymbol + "_" + IntegerToString((int)MagicNumber) + "_DDG";
  }

void PersistDrawdownGuardState()
  {
   string key = DrawdownGuardGlobalKey();
   if(drawdownGuardState >= 2)
      GlobalVariableSet(key, (double)drawdownGuardState);
   else if(GlobalVariableCheck(key))
      GlobalVariableDel(key);
  }

void LoadDrawdownGuardState()
  {
   drawdownGuardState = 0;
   drawdownGuardReason = "";
   softPauseStartTime = 0;

   string key = DrawdownGuardGlobalKey();
   if(InpResetDrawdownGuardState && GlobalVariableCheck(key))
      GlobalVariableDel(key);

   if(GlobalVariableCheck(key))
     {
      drawdownGuardState = (int)GlobalVariableGet(key);
      if(drawdownGuardState >= 3)
         drawdownGuardReason = "emergency_stop_drawdown_percent";
      else if(drawdownGuardState >= 2)
         drawdownGuardReason = "hard_stop_drawdown_percent";
     }
  }

void UpdateAccountDrawdownMetrics()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0)
      return;

   if(accountInitialEquity <= 0.0)
      accountInitialEquity = equity;
   if(accountPeakEquity <= 0.0 || equity > accountPeakEquity)
      accountPeakEquity = equity;

   currentDrawdownPercent = 0.0;
   if(accountPeakEquity > 0.0)
      currentDrawdownPercent = 100.0 * (accountPeakEquity - equity) / accountPeakEquity;
   if(currentDrawdownPercent > maxDrawdownPercent)
      maxDrawdownPercent = currentDrawdownPercent;
  }

void SetSmallCapitalRuin(string reason)
  {
   if(reason == "")
      reason = "small_capital_ruin";
   smallCapitalRuinTriggered = true;
   smallCapitalRuinReason = reason;
   SetStopCondition(reason);
  }

void UpdateSmallCapitalChallengeMetrics()
  {
   if(!IsAnySmallCapitalMode())
      return;

   smallCapitalCurrentBalanceUsd = AccountInfoDouble(ACCOUNT_BALANCE);
   smallCapitalCurrentEquityUsd = AccountInfoDouble(ACCOUNT_EQUITY);
   if(smallCapitalStartBalanceUsd <= 0.0)
      smallCapitalStartBalanceUsd = smallCapitalCurrentBalanceUsd;
   if(smallCapitalPeakEquityUsd <= 0.0 || smallCapitalCurrentEquityUsd > smallCapitalPeakEquityUsd)
      smallCapitalPeakEquityUsd = smallCapitalCurrentEquityUsd;
   if(smallCapitalMinEquityUsd <= 0.0 || smallCapitalCurrentEquityUsd < smallCapitalMinEquityUsd)
      smallCapitalMinEquityUsd = smallCapitalCurrentEquityUsd;

   if(smallCapitalPeakEquityUsd > 0.0)
     {
      double ddPercent = 100.0 * (smallCapitalPeakEquityUsd - smallCapitalCurrentEquityUsd) / smallCapitalPeakEquityUsd;
      if(ddPercent > smallCapitalMaxDrawdownPercent)
         smallCapitalMaxDrawdownPercent = ddPercent;
     }

   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   if(marginLevel > 0.0 && (smallCapitalMinMarginLevel <= 0.0 || marginLevel < smallCapitalMinMarginLevel))
      smallCapitalMinMarginLevel = marginLevel;

   if(smallCapitalCurrentEquityUsd <= 0.0)
      SetSmallCapitalRuin("small_capital_equity_zero");
   else if(smallCapitalCurrentBalanceUsd <= 0.0)
      SetSmallCapitalRuin("small_capital_balance_zero");
   else if(InpUseUsd100ChallengeMode &&
           Usd100RuinDDPercent > 0.0 &&
           smallCapitalMaxDrawdownPercent >= Usd100RuinDDPercent)
      SetSmallCapitalRuin("usd100_ruin_dd");
   else if(InpUseSmallCapitalChallengeMode &&
           SmallCapitalUseChallengeDDGuards &&
           SmallCapitalRuinDDPercent > 0.0 &&
           smallCapitalMaxDrawdownPercent >= SmallCapitalRuinDDPercent)
      SetSmallCapitalRuin("small_capital_ruin_dd");

   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   double stopOutLevel = AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);
   if(margin > 0.0 && marginLevel > 0.0 && stopOutLevel > 0.0 && marginLevel <= stopOutLevel)
      SetSmallCapitalRuin("small_capital_margin_stopout");
  }

bool CheckSmallCapitalChallengeLimits(string &rejectReason)
  {
   rejectReason = "";
   if(!IsAnySmallCapitalMode())
      return true;

   if((InpUseSmallCapitalChallengeMode && SmallCapitalRequireUsdAccount && !IsUsdAccount()) ||
      (InpUseUsd100ChallengeMode && !IsUsdAccount()))
     {
      rejectReason = InpUseUsd100ChallengeMode ? "usd100_non_usd_account_blocked" : "small_capital_non_usd_account_blocked";
      SetStopCondition(rejectReason);
      return false;
     }

   UpdateAccountDrawdownMetrics();
   UpdateSmallCapitalChallengeMetrics();
   if(smallCapitalRuinTriggered)
     {
      rejectReason = smallCapitalRuinReason == "" ? "small_capital_ruin_dd" : smallCapitalRuinReason;
      return false;
     }

   if(InpUseUsd100ChallengeMode)
     {
      if(Usd100RuinDDPercent > 0.0 && currentDrawdownPercent >= Usd100RuinDDPercent)
        {
         SetSmallCapitalRuin("usd100_ruin_dd");
         rejectReason = "usd100_ruin_dd";
         return false;
        }
      if(Usd100HardStopDDPercent > 0.0 && currentDrawdownPercent >= Usd100HardStopDDPercent)
        {
         if(drawdownGuardState < 2)
            drawdownGuardState = 2;
         drawdownGuardReason = "usd100_hard_stop_dd";
         SetStopCondition(drawdownGuardReason);
         rejectReason = drawdownGuardReason;
         return false;
        }
      if(Usd100SoftPauseDDPercent > 0.0 && currentDrawdownPercent >= Usd100SoftPauseDDPercent)
        {
         if(drawdownGuardState < 1)
            drawdownGuardState = 1;
         drawdownGuardReason = "usd100_soft_pause_dd";
         SetStopCondition(drawdownGuardReason);
         rejectReason = drawdownGuardReason;
         return false;
        }
      if(drawdownGuardReason == "usd100_soft_pause_dd")
        {
         drawdownGuardState = 0;
         drawdownGuardReason = "";
        }
      return true;
     }

   if(!SmallCapitalUseChallengeDDGuards)
      return true;

   if(SmallCapitalRuinDDPercent > 0.0 && currentDrawdownPercent >= SmallCapitalRuinDDPercent)
     {
      SetSmallCapitalRuin("small_capital_ruin_dd");
      rejectReason = "small_capital_ruin_dd";
      return false;
     }
   if(SmallCapitalHardStopDDPercent > 0.0 && currentDrawdownPercent >= SmallCapitalHardStopDDPercent)
     {
      if(drawdownGuardState < 2)
         drawdownGuardState = 2;
      drawdownGuardReason = "small_capital_hard_stop_dd";
      SetStopCondition(drawdownGuardReason);
      rejectReason = drawdownGuardReason;
      return false;
     }
   if(SmallCapitalSoftPauseDDPercent > 0.0 && currentDrawdownPercent >= SmallCapitalSoftPauseDDPercent)
     {
      if(drawdownGuardState < 1)
         drawdownGuardState = 1;
      drawdownGuardReason = "small_capital_soft_pause_dd";
      SetStopCondition(drawdownGuardReason);
      rejectReason = drawdownGuardReason;
      return false;
     }

   if(drawdownGuardReason == "small_capital_soft_pause_dd")
     {
      drawdownGuardState = 0;
      drawdownGuardReason = "";
     }
   return true;
  }

void SetDrawdownGuardState(int state, string reason)
  {
   if(state <= 0 || reason == "")
      return;

   bool shouldUpdate = false;
   if(state > drawdownGuardState)
      shouldUpdate = true;
   else if(state == 1 && drawdownGuardState <= 1)
      shouldUpdate = true;

   if(!shouldUpdate)
      return;

   drawdownGuardState = state;
   drawdownGuardReason = reason;
   if(state == 1)
      softPauseStartTime = TimeCurrent();
   if((state == 2 && RequireManualResetAfterHardStop) ||
      (state >= 3 && RequireManualResetAfterEmergencyStop))
      PersistDrawdownGuardState();
   SetStopCondition(reason);
  }

void EvaluateDrawdownPercentStopConditions()
  {
   if(!InpUseDrawdownPercentGuards)
      return;

   UpdateAccountDrawdownMetrics();
   if(currentDrawdownPercent <= 0.0)
      return;

   if(EmergencyStopDrawdownPercent > 0.0 && currentDrawdownPercent >= EmergencyStopDrawdownPercent)
     {
      SetDrawdownGuardState(3, "emergency_stop_drawdown_percent");
      return;
     }
   if(HardStopDrawdownPercent > 0.0 && currentDrawdownPercent >= HardStopDrawdownPercent)
     {
      SetDrawdownGuardState(2, "hard_stop_drawdown_percent");
      return;
     }
   if(SoftPauseDrawdownPercent > 0.0 && currentDrawdownPercent >= SoftPauseDrawdownPercent)
      SetDrawdownGuardState(1, "soft_pause_drawdown_percent");
  }

bool CheckDrawdownPercentLimits(string &rejectReason)
  {
   rejectReason = "";
   if(!InpUseDrawdownPercentGuards)
      return true;

   EvaluateDrawdownPercentStopConditions();

   if(drawdownGuardState >= 3)
     {
      if(!RequireManualResetAfterEmergencyStop &&
         (EmergencyStopDrawdownPercent <= 0.0 || currentDrawdownPercent < EmergencyStopDrawdownPercent))
        {
         drawdownGuardState = 0;
         drawdownGuardReason = "";
         PersistDrawdownGuardState();
         return true;
        }
      rejectReason = "emergency_stop_drawdown_percent";
      return false;
     }
   if(drawdownGuardState >= 2)
     {
      if(!RequireManualResetAfterHardStop &&
         (HardStopDrawdownPercent <= 0.0 || currentDrawdownPercent < HardStopDrawdownPercent))
        {
         drawdownGuardState = 0;
         drawdownGuardReason = "";
         PersistDrawdownGuardState();
         return true;
        }
      rejectReason = "hard_stop_drawdown_percent";
      return false;
     }
   if(drawdownGuardState == 1)
     {
      if(SoftPauseCooldownDays <= 0)
        {
         rejectReason = "soft_pause_drawdown_percent";
         return false;
        }
      datetime releaseTime = softPauseStartTime + (datetime)(SoftPauseCooldownDays * 86400);
      if(TimeCurrent() < releaseTime)
        {
         rejectReason = "soft_pause_drawdown_percent";
         return false;
        }

      drawdownGuardState = 0;
      drawdownGuardReason = "";
      softPauseStartTime = 0;
     }
   return true;
  }

void RegisterDailySignal(bool liveEntry)
  {
   dailyTotalSignals++;
   if(liveEntry)
     {
      dailyLiveEntries++;
      liveOrderSendFailedStreak = 0;
     }
  }

void RegisterDailyRejectedSignal(string reason)
  {
   dailyTotalSignals++;
   IncrementDailyRejectReason(reason);

   if(reason == "live_order_send_failed")
     {
      dailyLiveOrderSendFailedCount++;
      liveOrderSendFailedStreak++;
      if(liveOrderSendFailedStreak >= 3)
         SetStopCondition("live_order_send_failed_repeated");
     }
   else if(reason == "live_position_tracking_failed")
     {
      dailyLivePositionTrackingFailedCount++;
      SetStopCondition("live_position_tracking_failed");
     }
   else if(reason == "live_sl_tp_invalid")
     {
      dailyLiveSLTPInvalidCount++;
      SetStopCondition("live_sl_tp_invalid");
     }
   else if(reason == "live_lot_invalid")
     {
      dailyLiveLotInvalidCount++;
      SetStopCondition("live_lot_invalid");
     }
   else if(reason == "soft_pause_drawdown_percent" ||
           reason == "hard_stop_drawdown_percent" ||
           reason == "emergency_stop_drawdown_percent")
      SetStopCondition(reason);
   else if(reason == "small_capital_soft_pause_dd" ||
           reason == "small_capital_hard_stop_dd" ||
           reason == "small_capital_ruin_dd" ||
           reason == "small_capital_margin_insufficient" ||
           reason == "small_capital_non_usd_account_blocked")
      SetStopCondition(reason);
   else if(reason == "usd100_soft_pause_dd" ||
           reason == "usd100_hard_stop_dd" ||
           reason == "usd100_ruin_dd" ||
           reason == "usd100_margin_insufficient" ||
           reason == "usd100_repeated_margin_insufficient" ||
           reason == "usd100_effective_risk_too_high" ||
           reason == "usd100_effective_risk_hard_blocked" ||
           reason == "usd100_non_usd_account_blocked")
      SetStopCondition(reason);
   else if(reason == "non_demo_account_blocked")
      SetStopCondition(reason);
  }

void RegisterDailyClosedTrade(double profitR)
  {
   RegisterDailyClosedTrade(profitR, 0.0);
  }

void RegisterDailyClosedTrade(double profitR, double profitMoney)
  {
   dailyClosedTrades++;
   dailyRealizedProfitR += profitR;
   dailyRealizedProfitMoney += profitMoney;
   dailyEquityCurveR += profitR;
   if(dailyEquityCurveR > dailyEquityPeakR)
      dailyEquityPeakR = dailyEquityCurveR;
   double dd = dailyEquityPeakR - dailyEquityCurveR;
   if(dd > dailyMaxDrawdownR)
      dailyMaxDrawdownR = dd;

   dailyEquityCurveMoney += profitMoney;
   if(dailyEquityCurveMoney > dailyEquityPeakMoney)
      dailyEquityPeakMoney = dailyEquityCurveMoney;
   double moneyDd = dailyEquityPeakMoney - dailyEquityCurveMoney;
   if(moneyDd > dailyMaxDrawdownMoney)
      dailyMaxDrawdownMoney = moneyDd;

   if(profitR > 0.0)
     {
      dailyWinTrades++;
      dailyGrossWinR += profitR;
     }
   else if(profitR < 0.0)
     {
      dailyLossTrades++;
      dailyGrossLossR += MathAbs(profitR);
     }
  }

void RegisterLivePositionTrackingFailure()
  {
   dailyLivePositionTrackingFailedCount++;
   SetStopCondition("live_position_tracking_failed");
  }

string SessionName(datetime stamp)
  {
   MqlDateTime tm;
   TimeToStruct(stamp, tm);
   if(tm.hour >= 0 && tm.hour < 7)
      return "asia";
   if(tm.hour >= 7 && tm.hour < 13)
      return "london";
   if(tm.hour >= 13 && tm.hour < 22)
      return "new_york";
   return "late_us";
  }

double MarketEntryPrice(int direction)
  {
   if(direction > 0)
      return SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   if(direction < 0)
      return SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   return 0.0;
  }

double NormalizePrice(double price)
  {
   double tickSize = SymbolInfoDouble(runtimeSymbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0)
      tickSize = runtimePoint;
   if(tickSize <= 0.0)
      return NormalizeDouble(price, runtimeDigits);

   double normalized = MathRound(price / tickSize) * tickSize;
   return NormalizeDouble(normalized, runtimeDigits);
  }

double GetSpreadPoints()
  {
   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || runtimePoint <= 0.0)
      return DBL_MAX;
   return (ask - bid) / runtimePoint;
  }

double PointsFromPrice(double distance)
  {
   if(runtimePoint <= 0.0)
      return 0.0;
   return MathAbs(distance) / runtimePoint;
  }

bool CopyIndicatorValue(int handle, int bufferIndex, int shift, double &value)
  {
   value = 0.0;
   if(handle == INVALID_HANDLE || shift < 0)
      return false;

   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handle, bufferIndex, shift, 1, buffer) != 1)
      return false;

   value = buffer[0];
   return MathIsValidNumber(value);
  }

bool CopyATRValue(int handle, double &value)
  {
   if(!CopyIndicatorValue(handle, 0, 1, value))
      return false;

   return (value > 0.0);
  }

double ATRForTimeframe(ENUM_TIMEFRAMES tf)
  {
   double value = 0.0;
   if(tf == ContextTF && CopyATRValue(atrContextHandle, value))
      return value;
   if(tf == PatternTF && CopyATRValue(atrPatternHandle, value))
      return value;
   if(tf == EntryTF && CopyATRValue(atrEntryHandle, value))
      return value;

   int handle = iATR(runtimeSymbol, tf, ATRPeriod);
   if(handle == INVALID_HANDLE)
      return 0.0;
   bool ok = CopyATRValue(handle, value);
   IndicatorRelease(handle);
   return ok ? value : 0.0;
  }

double ATRPercentileForHandle(int handle, int lookback)
  {
   if(handle == INVALID_HANDLE || lookback <= 1)
      return 0.0;

   double values[];
   ArraySetAsSeries(values, true);
   int copied = CopyBuffer(handle, 0, 1, lookback, values);
   if(copied <= 1)
      return 0.0;

   double current = values[0];
   if(current <= 0.0 || !MathIsValidNumber(current))
      return 0.0;

   int valid = 0;
   int lessOrEqual = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(values[i] <= 0.0 || !MathIsValidNumber(values[i]))
         continue;
      valid++;
      if(values[i] <= current)
         lessOrEqual++;
     }
   if(valid <= 0)
      return 0.0;
   return 100.0 * (double)lessOrEqual / (double)valid;
  }

string ATRBucket(double percentile)
  {
   if(percentile <= 0.0)
      return "unknown_vol";
   if(percentile <= ATRLowPercentile)
      return "low_vol";
   if(percentile >= ATRHighPercentile)
      return "high_vol";
   return "normal_vol";
  }

string ADXBucket(double adx)
  {
   if(adx <= 0.0)
      return "unknown";
   if(adx < ADXLowThreshold)
      return "low";
   if(adx >= ADXHighThreshold)
      return "high";
   return "middle";
  }

string DIDirection(double plusDI, double minusDI)
  {
   double tolerance = 0.1;
   if(plusDI > minusDI + tolerance)
      return "plus_di";
   if(minusDI > plusDI + tolerance)
      return "minus_di";
   return "neutral";
  }

string PriceVsEMA(double price, double ema)
  {
   if(price <= 0.0 || ema <= 0.0)
      return "unknown";
   double tolerance = runtimePoint * 0.5;
   if(price > ema + tolerance)
      return "above";
   if(price < ema - tolerance)
      return "below";
   return "at";
  }

string HTFTrendState(double emaShort,
                     double emaLong,
                     double shortSlopeATR,
                     double longSlopeATR)
  {
   if(emaShort <= 0.0 || emaLong <= 0.0)
      return "unknown";

   bool shortRising = (shortSlopeATR > EMAFlatSlopeATR);
   bool shortFalling = (shortSlopeATR < -EMAFlatSlopeATR);
   bool longRising = (longSlopeATR > EMAFlatSlopeATR);
   bool longFalling = (longSlopeATR < -EMAFlatSlopeATR);
   bool shortFlat = (MathAbs(shortSlopeATR) <= EMAFlatSlopeATR);
   bool longFlat = (MathAbs(longSlopeATR) <= EMAFlatSlopeATR);

   if(shortFlat && longFlat)
      return "flat";
   if(emaShort > emaLong && shortRising && !longFalling)
      return "bullish";
   if(emaShort < emaLong && shortFalling && !longRising)
      return "bearish";
   return "mixed";
  }

string TrendAlignmentTag(int direction, string trendState)
  {
   if(direction > 0 && trendState == "bullish")
      return "TrendFollow";
   if(direction < 0 && trendState == "bearish")
      return "TrendFollow";
   if(direction > 0 && trendState == "bearish")
      return "CounterTrend";
   if(direction < 0 && trendState == "bullish")
      return "CounterTrend";
   return "MixedTrend";
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

bool IsPivotHigh(ENUM_TIMEFRAMES tf, int shift, int span)
  {
   double center = iHigh(runtimeSymbol, tf, shift);
   if(center <= 0.0)
      return false;

   for(int i = 1; i <= span; ++i)
     {
      if(center <= iHigh(runtimeSymbol, tf, shift - i))
         return false;
      if(center <= iHigh(runtimeSymbol, tf, shift + i))
         return false;
     }
   return true;
  }

bool IsPivotLow(ENUM_TIMEFRAMES tf, int shift, int span)
  {
   double center = iLow(runtimeSymbol, tf, shift);
   if(center <= 0.0)
      return false;

   for(int i = 1; i <= span; ++i)
     {
      if(center >= iLow(runtimeSymbol, tf, shift - i))
         return false;
      if(center >= iLow(runtimeSymbol, tf, shift + i))
         return false;
     }
   return true;
  }

void AppendSwing(SwingPoint &swings[], const SwingPoint &point)
  {
   int size = ArraySize(swings);
   ArrayResize(swings, size + 1);
   swings[size] = point;
  }

bool DetectSwings(ENUM_TIMEFRAMES tf, int span, int scanBars, SwingPoint &swings[])
  {
   ArrayResize(swings, 0);
   int bars = Bars(runtimeSymbol, tf);
   if(bars <= span * 3 + 8)
      return false;

   int startShift = span + 1;
   int endShift = MathMin(scanBars, bars - span - 2);
   if(endShift <= startShift)
      return false;

   for(int shift = endShift; shift >= startShift; --shift)
     {
      if(IsPivotHigh(tf, shift, span))
        {
         SwingPoint point;
         point.valid = true;
         point.isHigh = true;
         point.shift = shift;
         point.price = iHigh(runtimeSymbol, tf, shift);
         point.time = iTime(runtimeSymbol, tf, shift);
         AppendSwing(swings, point);
        }

      if(IsPivotLow(tf, shift, span))
        {
         SwingPoint point;
         point.valid = true;
         point.isHigh = false;
         point.shift = shift;
         point.price = iLow(runtimeSymbol, tf, shift);
         point.time = iTime(runtimeSymbol, tf, shift);
         AppendSwing(swings, point);
        }
     }

   return (ArraySize(swings) >= 4);
  }

void CompressAlternatingSwings(const SwingPoint &rawSwings[], SwingPoint &compressed[])
  {
   ArrayResize(compressed, 0);
   int count = ArraySize(rawSwings);
   for(int i = 0; i < count; ++i)
     {
      SwingPoint current = rawSwings[i];
      int size = ArraySize(compressed);
      if(size == 0)
        {
         AppendSwing(compressed, current);
         continue;
        }

      SwingPoint last = compressed[size - 1];
      if(last.isHigh != current.isHigh)
        {
         AppendSwing(compressed, current);
         continue;
        }

      bool replace = current.isHigh ? (current.price > last.price) : (current.price < last.price);
      if(replace)
         compressed[size - 1] = current;
     }
  }

bool NWaveFiltersPass(double fibExtensionValue,
                      double activeLeg,
                      double atrValue,
                      string &reason,
                      bool &fiboPassed,
                      bool &atrPassed)
  {
   fiboPassed = !UseFiboExtensionFilter || (fibExtensionValue >= FiboExtensionMin);
   atrPassed = !UseATRExpansionFilter;
   if(UseATRExpansionFilter && atrValue > 0.0)
     {
      bool legVsAtr = (activeLeg >= atrValue);
      bool legVsPoints = (MinATRPoints <= 0.0 || PointsFromPrice(activeLeg) >= MinATRPoints);
      atrPassed = (legVsAtr && legVsPoints);
     }

   if(!UseFiboExtensionFilter && !UseATRExpansionFilter)
     {
      reason = "filters_disabled";
      return true;
     }

   bool passed = false;
   if(ExtensionFilterModeInput == FILTER_ALL)
      passed = (fiboPassed && atrPassed);
   else
     {
      passed = false;
      if(UseFiboExtensionFilter && fiboPassed)
         passed = true;
      if(UseATRExpansionFilter && atrPassed)
         passed = true;
     }

   if(!passed)
     {
      if(UseFiboExtensionFilter && !fiboPassed && UseATRExpansionFilter && !atrPassed)
         reason = "fibo_and_atr_filter_failed";
      else if(UseFiboExtensionFilter && !fiboPassed)
         reason = "fibo_filter_failed";
      else if(UseATRExpansionFilter && !atrPassed)
         reason = "atr_filter_failed";
      else
         reason = "n_wave_filter_failed";
      return false;
     }

   if(UseFiboExtensionFilter && fiboPassed && UseATRExpansionFilter && atrPassed)
     {
      reason = "fibo_and_atr";
      return true;
     }
   if(UseFiboExtensionFilter && fiboPassed)
     {
      reason = "fibo";
      return true;
     }
   if(UseATRExpansionFilter && atrPassed)
     {
      reason = "atr";
      return true;
     }

   reason = "filters_disabled";
   return true;
  }

bool DetectNWaveOnTF(ENUM_TIMEFRAMES tf, int direction, NWaveContext &ctx)
  {
   ResetNWave(ctx);

   SwingPoint raw[];
   if(!DetectSwings(tf, SwingDepth, (tf == ContextTF ? ContextScanBars : PatternScanBars), raw))
      return false;

   SwingPoint swings[];
   CompressAlternatingSwings(raw, swings);
   int count = ArraySize(swings);
   if(count < 4)
      return false;

   double atrValue = ATRForTimeframe(tf);
   bool storedRejectedCandidate = false;
   NWaveContext rejectedCandidate;
   ResetNWave(rejectedCandidate);

   for(int i = count - 1; i >= 3; --i)
     {
      SwingPoint p1 = swings[i - 3];
      SwingPoint p2 = swings[i - 2];
      SwingPoint p3 = swings[i - 1];
      SwingPoint p4 = swings[i];

      if(direction > 0)
        {
         if(!p1.isHigh || p2.isHigh || !p3.isHigh || p4.isHigh)
            continue;
         if(!(p3.price < p1.price && p4.price < p2.price))
            continue;

         double firstLeg = p1.price - p2.price;
         double activeLeg = p3.price - p4.price;
         if(firstLeg <= 0.0 || activeLeg <= 0.0)
            continue;

         double fib = activeLeg / firstLeg * 100.0;
         string reason = "";
         bool fiboPassed = false;
         bool atrPassed = false;
         bool filtersPassed = NWaveFiltersPass(fib, activeLeg, atrValue, reason, fiboPassed, atrPassed);

         NWaveContext candidate;
         ResetNWave(candidate);
         candidate.valid = filtersPassed;
         candidate.direction = direction;
         candidate.sourceTimeframe = TimeframeToString(tf);
         candidate.p1 = p1;
         candidate.p2 = p2;
         candidate.p3 = p3;
         candidate.p4 = p4;
         candidate.firstLeg = firstLeg;
         candidate.activeLeg = activeLeg;
         candidate.fibExtensionValue = fib;
         candidate.atrValue = atrValue;
         candidate.filterReason = reason;
         candidate.contextFilterPassed = filtersPassed;
         candidate.fiboFilterPassed = fiboPassed;
         candidate.atrFilterPassed = atrPassed;

         if(filtersPassed)
           {
            ctx = candidate;
            return true;
           }
         if(!storedRejectedCandidate)
           {
            rejectedCandidate = candidate;
            storedRejectedCandidate = true;
           }
         continue;
        }

      if(direction < 0)
        {
         if(p1.isHigh || !p2.isHigh || p3.isHigh || !p4.isHigh)
            continue;
         if(!(p3.price > p1.price && p4.price > p2.price))
            continue;

         double firstLeg = p2.price - p1.price;
         double activeLeg = p4.price - p3.price;
         if(firstLeg <= 0.0 || activeLeg <= 0.0)
            continue;

         double fib = activeLeg / firstLeg * 100.0;
         string reason = "";
         bool fiboPassed = false;
         bool atrPassed = false;
         bool filtersPassed = NWaveFiltersPass(fib, activeLeg, atrValue, reason, fiboPassed, atrPassed);

         NWaveContext candidate;
         ResetNWave(candidate);
         candidate.valid = filtersPassed;
         candidate.direction = direction;
         candidate.sourceTimeframe = TimeframeToString(tf);
         candidate.p1 = p1;
         candidate.p2 = p2;
         candidate.p3 = p3;
         candidate.p4 = p4;
         candidate.firstLeg = firstLeg;
         candidate.activeLeg = activeLeg;
         candidate.fibExtensionValue = fib;
         candidate.atrValue = atrValue;
         candidate.filterReason = reason;
         candidate.contextFilterPassed = filtersPassed;
         candidate.fiboFilterPassed = fiboPassed;
         candidate.atrFilterPassed = atrPassed;

         if(filtersPassed)
           {
            ctx = candidate;
            return true;
           }
         if(!storedRejectedCandidate)
           {
            rejectedCandidate = candidate;
            storedRejectedCandidate = true;
           }
         continue;
        }
     }

   if(storedRejectedCandidate)
     {
      ctx = rejectedCandidate;
      return false;
     }

   ctx.filterReason = "n_wave_structure_missing";
   ctx.contextFilterPassed = false;
   return false;
  }

bool DetectNWave(int direction, NWaveContext &ctx)
  {
   NWaveContext contextCandidate;
   NWaveContext patternCandidate;
   ResetNWave(contextCandidate);
   ResetNWave(patternCandidate);

   if(DetectNWaveOnTF(ContextTF, direction, contextCandidate))
     {
      ctx = contextCandidate;
      return true;
     }
   if(DetectNWaveOnTF(PatternTF, direction, patternCandidate))
     {
      ctx = patternCandidate;
      return true;
     }

   if(contextCandidate.direction != 0)
      ctx = contextCandidate;
   else if(patternCandidate.direction != 0)
      ctx = patternCandidate;
   else
     {
      ResetNWave(ctx);
      ctx.direction = direction;
      ctx.filterReason = "n_wave_structure_missing";
     }
   return false;
  }

bool FindDoubleBottomStructure(const SwingPoint &swings[], PatternSetup &setup)
  {
   ResetPattern(setup);
   int count = ArraySize(swings);
   if(count < 3)
      return false;

   double atrValue = ATRForTimeframe(EntryTF);
   if(atrValue <= 0.0)
      return false;
   double tolerance = MathMax(atrValue * DoubleTopBottomToleranceATR, runtimePoint * 2.0);
   double minHeight = MathMax(atrValue * 0.50, runtimePoint * 5.0);

   for(int right = count - 1; right >= 0; --right)
     {
      if(swings[right].isHigh)
         continue;

      for(int left = right - 1; left >= 0; --left)
        {
         if(swings[left].isHigh)
            continue;

         int neckIndex = -1;
         double neckPrice = -DBL_MAX;
         for(int middle = left + 1; middle < right; ++middle)
           {
            if(!swings[middle].isHigh)
               continue;
            if(swings[middle].price > neckPrice)
              {
               neckPrice = swings[middle].price;
               neckIndex = middle;
              }
           }

         if(neckIndex < 0)
            continue;

         double bottomDiff = MathAbs(swings[right].price - swings[left].price);
         if(bottomDiff > tolerance)
            continue;

         double patternHeight = neckPrice - MathMax(swings[right].price, swings[left].price);
         if(patternHeight < minHeight)
            continue;

         setup.valid = true;
         setup.direction = DIR_LONG;
         setup.patternType = "double_bottom_neckline_break";
         setup.left = swings[left];
         setup.right = swings[right];
         setup.necklinePivot = swings[neckIndex];
         setup.necklinePrice = neckPrice;
         setup.atrValue = atrValue;
         return true;
        }
     }
   return false;
  }

bool FindDoubleTopStructure(const SwingPoint &swings[], PatternSetup &setup)
  {
   ResetPattern(setup);
   int count = ArraySize(swings);
   if(count < 3)
      return false;

   double atrValue = ATRForTimeframe(EntryTF);
   if(atrValue <= 0.0)
      return false;
   double tolerance = MathMax(atrValue * DoubleTopBottomToleranceATR, runtimePoint * 2.0);
   double minHeight = MathMax(atrValue * 0.50, runtimePoint * 5.0);

   for(int right = count - 1; right >= 0; --right)
     {
      if(!swings[right].isHigh)
         continue;

      for(int left = right - 1; left >= 0; --left)
        {
         if(!swings[left].isHigh)
            continue;

         int neckIndex = -1;
         double neckPrice = DBL_MAX;
         for(int middle = left + 1; middle < right; ++middle)
           {
            if(swings[middle].isHigh)
               continue;
            if(swings[middle].price < neckPrice)
              {
               neckPrice = swings[middle].price;
               neckIndex = middle;
              }
           }

         if(neckIndex < 0)
            continue;

         double topDiff = MathAbs(swings[right].price - swings[left].price);
         if(topDiff > tolerance)
            continue;

         double patternHeight = MathMin(swings[right].price, swings[left].price) - neckPrice;
         if(patternHeight < minHeight)
            continue;

         setup.valid = true;
         setup.direction = DIR_SHORT;
         setup.patternType = "double_top_neckline_break";
         setup.left = swings[left];
         setup.right = swings[right];
         setup.necklinePivot = swings[neckIndex];
         setup.necklinePrice = neckPrice;
         setup.atrValue = atrValue;
         return true;
        }
     }
   return false;
  }

bool CheckNecklineBreak(const PatternSetup &setup)
  {
   if(!setup.valid)
      return false;

   double close1 = iClose(runtimeSymbol, EntryTF, 1);
   double close2 = iClose(runtimeSymbol, EntryTF, 2);
   datetime close1Time = iTime(runtimeSymbol, EntryTF, 1);
   if(close1 <= 0.0 || close2 <= 0.0 || close1Time <= setup.right.time)
      return false;

   double buffer = setup.atrValue * NecklineBreakBufferATR;
   if(setup.direction > 0)
     {
      double trigger = setup.necklinePrice + buffer;
      return (close1 > trigger && close2 <= trigger);
     }

   double trigger = setup.necklinePrice - buffer;
   return (close1 < trigger && close2 >= trigger);
  }

bool DetectDoubleBottom(PatternSetup &setup)
  {
   SwingPoint raw[];
   if(!DetectSwings(EntryTF, SwingDepth, EntryScanBars, raw))
      return false;

   SwingPoint swings[];
   CompressAlternatingSwings(raw, swings);
   if(!FindDoubleBottomStructure(swings, setup))
      return false;
   return CheckNecklineBreak(setup);
  }

bool DetectDoubleTop(PatternSetup &setup)
  {
   SwingPoint raw[];
   if(!DetectSwings(EntryTF, SwingDepth, EntryScanBars, raw))
      return false;

   SwingPoint swings[];
   CompressAlternatingSwings(raw, swings);
   if(!FindDoubleTopStructure(swings, setup))
      return false;
   return CheckNecklineBreak(setup);
  }

bool CalculateSLTP(const PatternSetup &setup,
                   double entryPrice,
                   double &stopLoss,
                   double &takeProfit,
                   double &riskPoints,
                   double &rewardPoints,
                   double &rr,
                   string &rejectReason)
  {
   stopLoss = 0.0;
   takeProfit = 0.0;
   riskPoints = 0.0;
   rewardPoints = 0.0;
   rr = 0.0;
   rejectReason = "";

   if(!setup.valid || entryPrice <= 0.0 || runtimePoint <= 0.0)
     {
      rejectReason = "invalid_entry_or_setup";
      return false;
     }

   double buffer = setup.atrValue * SLBufferATR;
   if(setup.direction > 0)
     {
      stopLoss = NormalizePrice(setup.right.price - buffer);
      if(stopLoss <= 0.0 || stopLoss >= entryPrice)
        {
         rejectReason = "invalid_sl";
         return false;
        }
      double riskDistance = entryPrice - stopLoss;
      takeProfit = NormalizePrice(entryPrice + riskDistance * EffectiveTakeProfitRMultiple());
     }
   else
     {
      stopLoss = NormalizePrice(setup.right.price + buffer);
      if(stopLoss <= 0.0 || stopLoss <= entryPrice)
        {
         rejectReason = "invalid_sl";
         return false;
        }
      double riskDistance = stopLoss - entryPrice;
      takeProfit = NormalizePrice(entryPrice - riskDistance * EffectiveTakeProfitRMultiple());
     }

   if(takeProfit <= 0.0)
     {
      rejectReason = "invalid_tp";
      return false;
     }

   riskPoints = PointsFromPrice(entryPrice - stopLoss);
   rewardPoints = PointsFromPrice(takeProfit - entryPrice);
   if(riskPoints <= 0.0 || rewardPoints <= 0.0)
     {
      rejectReason = "invalid_risk_or_reward";
      return false;
     }

   rr = rewardPoints / riskPoints;
   if(rr < MinRR)
     {
      rejectReason = "rr_too_low";
      return false;
     }
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

double NormalizeVolumeUpByStep(double volume)
  {
   double stepVolume = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_STEP);
   if(stepVolume <= 0.0)
      return 0.0;
   double normalized = MathCeil(volume / stepVolume) * stepVolume;
   return NormalizeDouble(normalized, VolumeDigits(stepVolume));
  }

double CalculateRiskAmountByVolume(int direction, double entry, double stop, double volume)
  {
   if(volume <= 0.0 || entry <= 0.0 || stop <= 0.0 || entry == stop)
      return 0.0;

   ENUM_ORDER_TYPE orderType = direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double profit = 0.0;
   if(!OrderCalcProfit(orderType, runtimeSymbol, volume, entry, stop, profit))
      return 0.0;
   return MathAbs(profit);
  }

double CalculateLotSizeByRiskPercent(int direction, double entry, double stop, double riskPercent, double &rawVolume)
  {
   rawVolume = 0.0;
   double riskAmount = AccountInfoDouble(ACCOUNT_EQUITY) * (riskPercent / 100.0);
   double minVolume = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_MAX);
   double stepVolume = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_STEP);

   if(riskAmount <= 0.0 || entry <= 0.0 || stop <= 0.0 || entry == stop ||
      minVolume <= 0.0 || maxVolume <= 0.0 || stepVolume <= 0.0)
      return 0.0;

   double lossPerLot = CalculateRiskAmountByVolume(direction, entry, stop, 1.0);
   if(lossPerLot <= 0.0)
      return 0.0;

   rawVolume = riskAmount / lossPerLot;
   double volume = NormalizeVolumeByStep(rawVolume);
   if(volume < minVolume)
      return 0.0;
   if(volume > maxVolume)
      volume = NormalizeDouble(maxVolume, VolumeDigits(stepVolume));
   return volume;
  }

double CalculateLotSizeByRisk(int direction, double entry, double stop)
  {
   double rawVolume = 0.0;
   return CalculateLotSizeByRiskPercent(direction, entry, stop, RiskPercent, rawVolume);
  }

bool ApplyRiskSizingToPlan(int direction, double entry, double stop, TradePlan &plan, string &rejectReason)
  {
   rejectReason = "";
   plan.accountCurrency = AccountInfoString(ACCOUNT_CURRENCY);
   plan.accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   plan.accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   plan.smallCapitalMode = IsAnySmallCapitalMode();
   plan.usd100ChallengeMode = InpUseUsd100ChallengeMode;
   plan.selectedRiskPercent = EffectiveRiskPercent();
   plan.riskPercent = plan.selectedRiskPercent;
   plan.selectedSmallCapitalTier = InpUseUsd100ChallengeMode ? Usd100TierLabel(SmallCapitalRiskBaseMoney()) :
                                   (InpUseSmallCapitalChallengeMode ? SmallCapitalTierLabel(SmallCapitalRiskBaseMoney()) : "standard");
   plan.minLot = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_MIN);
   plan.lotStep = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_STEP);
   plan.freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   plan.finalLotReason = "normal_calculated_lot";

   double maxVolume = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_MAX);
   if(InpUseUsd100ChallengeMode && !IsUsdAccount())
     {
      plan.finalLotReason = "blocked_because_non_usd_account";
      rejectReason = "usd100_non_usd_account_blocked";
      return false;
     }
   if(InpUseSmallCapitalChallengeMode && SmallCapitalRequireUsdAccount && !IsUsdAccount())
     {
      plan.finalLotReason = "blocked_because_non_usd_account";
      rejectReason = "small_capital_non_usd_account_blocked";
      return false;
     }

   double riskBase = InpUseSmallCapitalChallengeMode ? SmallCapitalRiskBaseMoney() : AccountInfoDouble(ACCOUNT_EQUITY);
   if(InpUseUsd100ChallengeMode)
      riskBase = SmallCapitalRiskBaseMoney();
   plan.desiredRiskMoneyUsd = riskBase * (plan.selectedRiskPercent / 100.0);
   if(entry <= 0.0 || stop <= 0.0 || entry == stop ||
      plan.minLot <= 0.0 || plan.lotStep <= 0.0 || maxVolume <= 0.0)
     {
      plan.finalLotReason = "invalid_lot_or_risk";
      rejectReason = "invalid_lot_or_risk";
      return false;
     }

   if(plan.desiredRiskMoneyUsd <= 0.0)
     {
      if(!InpUseUsd100ChallengeMode)
        {
         plan.finalLotReason = "invalid_lot_or_risk";
         rejectReason = "invalid_lot_or_risk";
         return false;
        }
     }

   double lossPerLot = CalculateRiskAmountByVolume(direction, entry, stop, 1.0);
   if(lossPerLot <= 0.0)
     {
      plan.finalLotReason = "invalid_lot_or_risk";
      rejectReason = "invalid_lot_or_risk";
      return false;
     }

   double finalLot = 0.0;
   if(InpUseUsd100ChallengeMode)
     {
      double baseMoney = SmallCapitalRiskBaseMoney();
      if(Usd100UsesFixedMinLot(baseMoney))
        {
         if(Usd100MaxLot > 0.0 && plan.minLot > Usd100MaxLot + 0.0000001)
           {
            plan.finalLotReason = "usd100_min_lot_above_max_lot";
            rejectReason = "live_lot_invalid";
            return false;
           }
         finalLot = NormalizeDouble(plan.minLot, VolumeDigits(plan.lotStep));
         plan.calculatedLotBeforeRounding = finalLot;
         plan.finalLotReason = "usd100_fixed_min_lot";
        }
      else
        {
         plan.selectedRiskPercent = Usd100HybridRiskPercent(baseMoney);
         plan.riskPercent = plan.selectedRiskPercent;
         plan.desiredRiskMoneyUsd = riskBase * (plan.selectedRiskPercent / 100.0);
         if(plan.desiredRiskMoneyUsd <= 0.0)
           {
            plan.finalLotReason = "invalid_lot_or_risk";
            rejectReason = "invalid_lot_or_risk";
            return false;
           }
         plan.calculatedLotBeforeRounding = plan.desiredRiskMoneyUsd / lossPerLot;
         finalLot = NormalizeVolumeByStep(plan.calculatedLotBeforeRounding);
         if(finalLot < plan.minLot)
           {
            finalLot = NormalizeDouble(plan.minLot, VolumeDigits(plan.lotStep));
            plan.finalLotReason = "rounded_to_min_lot";
           }
         if(Usd100MaxLot > 0.0 && finalLot > Usd100MaxLot)
           {
            finalLot = NormalizeVolumeByStep(Usd100MaxLot);
            plan.finalLotReason = "usd100_capped_to_max_lot";
           }
        }
     }
   else
     {
      plan.calculatedLotBeforeRounding = plan.desiredRiskMoneyUsd / lossPerLot;
      finalLot = NormalizeVolumeByStep(plan.calculatedLotBeforeRounding);
     }
   if(finalLot < plan.minLot)
     {
      if(InpUseSmallCapitalChallengeMode && SmallCapitalAllowMinLotOverride)
        {
         finalLot = NormalizeDouble(plan.minLot, VolumeDigits(plan.lotStep));
         plan.finalLotReason = "rounded_to_min_lot";
        }
      else
        {
         plan.finalLotReason = "invalid_lot_or_risk";
         rejectReason = "invalid_lot_or_risk";
         return false;
        }
     }
   if(finalLot > maxVolume)
      finalLot = NormalizeDouble(maxVolume, VolumeDigits(plan.lotStep));

   plan.finalLot = finalLot;
   plan.lotSize = finalLot;
   plan.actualRiskMoneyAtFinalLotUsd = CalculateRiskAmountByVolume(direction, entry, stop, finalLot);
   plan.plannedRiskMoney = plan.actualRiskMoneyAtFinalLotUsd;
   plan.effectiveRiskPercentAtFinalLot = riskBase > 0.0 ? 100.0 * plan.actualRiskMoneyAtFinalLotUsd / riskBase : 0.0;
   if(InpUseUsd100ChallengeMode && Usd100UsesFixedMinLot(riskBase))
     {
      plan.desiredRiskMoneyUsd = plan.actualRiskMoneyAtFinalLotUsd;
      plan.selectedRiskPercent = plan.effectiveRiskPercentAtFinalLot;
      plan.riskPercent = plan.selectedRiskPercent;
     }

   ENUM_ORDER_TYPE orderType = direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   plan.marginRequired = 0.0;
   if(!OrderCalcMargin(orderType, runtimeSymbol, finalLot, entry, plan.marginRequired))
      plan.marginRequired = 0.0;
   plan.freeMarginAfterEntryEstimate = plan.freeMargin - plan.marginRequired;

   if(InpUseSmallCapitalChallengeMode &&
      SmallCapitalBlockIfEffectiveRiskTooHigh &&
      plan.effectiveRiskPercentAtFinalLot > SmallCapitalMaxEffectiveRiskPercent + 0.0000001)
     {
      plan.finalLotReason = "blocked_because_effective_risk_too_high";
      rejectReason = "small_capital_effective_risk_too_high";
      return false;
     }

   if(InpUseUsd100ChallengeMode &&
      Usd100HardBlockEffectiveRiskPercent > 0.0 &&
      plan.effectiveRiskPercentAtFinalLot > Usd100HardBlockEffectiveRiskPercent + 0.0000001)
     {
      plan.finalLotReason = "blocked_because_effective_risk_too_high";
      plan.usd100RiskWarning = "usd100_effective_risk_hard_blocked";
      rejectReason = "usd100_effective_risk_hard_blocked";
      return false;
     }

   if(InpUseUsd100ChallengeMode &&
      Usd100MaxEffectiveRiskPercent > 0.0 &&
      plan.effectiveRiskPercentAtFinalLot > Usd100MaxEffectiveRiskPercent + 0.0000001)
     {
      plan.usd100RiskWarning = "usd100_effective_risk_warning";
      if(Usd100BlockIfEffectiveRiskTooHigh)
        {
         plan.finalLotReason = "blocked_because_effective_risk_too_high";
         rejectReason = "usd100_effective_risk_too_high";
         return false;
        }
     }

   if(InpUseSmallCapitalChallengeMode && plan.marginRequired > 0.0 && plan.marginRequired > plan.freeMargin)
     {
      plan.finalLotReason = "margin_insufficient";
      smallCapitalConsecutiveMarginInsufficient++;
      if(smallCapitalConsecutiveMarginInsufficient >= 3)
        {
         smallCapitalRuinTriggered = true;
         smallCapitalRuinReason = "small_capital_margin_insufficient_repeated";
         SetStopCondition(smallCapitalRuinReason);
        }
      rejectReason = "small_capital_margin_insufficient";
      return false;
     }

   if(InpUseUsd100ChallengeMode &&
      Usd100BlockIfMarginInsufficient &&
      plan.marginRequired > 0.0 &&
      plan.marginRequired > plan.freeMargin)
     {
      plan.finalLotReason = "margin_insufficient";
      smallCapitalConsecutiveMarginInsufficient++;
      if(smallCapitalConsecutiveMarginInsufficient >= 3)
        {
         smallCapitalRuinTriggered = true;
         smallCapitalRuinReason = "usd100_repeated_margin_insufficient";
         SetStopCondition(smallCapitalRuinReason);
        }
      rejectReason = "usd100_margin_insufficient";
      return false;
     }

   smallCapitalConsecutiveMarginInsufficient = 0;
   return (plan.lotSize > 0.0 && plan.plannedRiskMoney > 0.0);
  }

string ContextRejectReason(const NWaveContext &context)
  {
   if(context.filterReason == "fibo_filter_failed")
      return "fibo_filter_failed";
   if(context.filterReason == "atr_filter_failed")
      return "atr_filter_failed";
   if(context.filterReason == "fibo_and_atr_filter_failed")
      return "n_wave_filter_failed";
   if(context.filterReason == "n_wave_structure_missing")
      return "n_wave_filter_failed";
   return "n_wave_filter_failed";
  }

int BarsBetweenEntryBars(datetime olderBarTime, datetime newerBarTime)
  {
   if(olderBarTime <= 0 || newerBarTime <= 0)
      return -1;

   int olderShift = iBarShift(runtimeSymbol, EntryTF, olderBarTime, true);
   int newerShift = iBarShift(runtimeSymbol, EntryTF, newerBarTime, true);
   if(olderShift < 0 || newerShift < 0)
      return -1;

   int elapsed = olderShift - newerShift;
   if(elapsed < 0)
      return -1;
   return elapsed;
  }

bool HasApproxDuplicateOpenSetup(const TradePlan &plan)
  {
   double threshold = MathMax(runtimePoint * 5.0, plan.atrValue * 0.05);
   int size = ArraySize(managedTrades);
   for(int i = 0; i < size; ++i)
     {
      if(!managedTrades[i].active)
         continue;

      TradePlan openPlan = managedTrades[i].plan;
      if(openPlan.direction != plan.direction)
         continue;
      if(openPlan.setupId == plan.setupId)
         return true;

      int barsAgo = BarsBetweenEntryBars(openPlan.entryBarTime, plan.entryBarTime);
      if(barsAgo < 0 || barsAgo > DuplicateLookbackBars)
         continue;
      if(MathAbs(openPlan.necklinePrice - plan.necklinePrice) <= threshold)
         return true;
     }
   return false;
  }

void PopulateOpenPositionDiagnostics(TradePlan &plan)
  {
   plan.entryOpenCount = 0;
   plan.sameDirectionOpenCount = 0;
   plan.oppositeDirectionOpenCount = 0;

   int size = ArraySize(managedTrades);
   for(int i = 0; i < size; ++i)
     {
      if(!managedTrades[i].active)
         continue;

      plan.entryOpenCount++;
      if(managedTrades[i].plan.direction == plan.direction)
         plan.sameDirectionOpenCount++;
      else if(managedTrades[i].plan.direction == -plan.direction)
         plan.oppositeDirectionOpenCount++;
     }

   plan.barsSinceLastEntry = BarsBetweenEntryBars(lastAcceptedEntryBarTime, plan.entryBarTime);
   plan.approximateDuplicateSetup = HasApproxDuplicateOpenSetup(plan);
  }

void PopulateContextEMADiagnostics(TradePlan &plan)
  {
   double shortNow = 0.0;
   double shortPast = 0.0;
   double longNow = 0.0;
   double longPast = 0.0;
   double contextATR = ATRForTimeframe(ContextTF);

   bool shortOk = CopyIndicatorValue(emaContextShortHandle, 0, 1, shortNow) &&
                  CopyIndicatorValue(emaContextShortHandle, 0, 1 + EMASlopeBars, shortPast);
   bool longOk = CopyIndicatorValue(emaContextLongHandle, 0, 1, longNow) &&
                 CopyIndicatorValue(emaContextLongHandle, 0, 1 + EMASlopeBars, longPast);
   if(!shortOk || !longOk)
     {
      plan.htfTrendState = "unknown";
      plan.trendAlignmentTag = "MixedTrend";
      return;
     }

   plan.contextEMAShort = shortNow;
   plan.contextEMALong = longNow;
   plan.contextEMAShortAboveLong = (shortNow > longNow);
   if(contextATR > 0.0)
     {
      plan.contextEMAShortSlopeATR = (shortNow - shortPast) / contextATR;
      plan.contextEMALongSlopeATR = (longNow - longPast) / contextATR;
     }

   double contextClose = iClose(runtimeSymbol, ContextTF, 1);
   plan.contextPriceVsEMAShort = PriceVsEMA(contextClose, shortNow);
   plan.contextPriceVsEMALong = PriceVsEMA(contextClose, longNow);
   plan.htfTrendState = HTFTrendState(shortNow, longNow, plan.contextEMAShortSlopeATR, plan.contextEMALongSlopeATR);
   plan.trendAlignmentTag = TrendAlignmentTag(plan.direction, plan.htfTrendState);
   plan.contextDirectionAligned = (plan.trendAlignmentTag == "TrendFollow");
  }

void PopulateADXDiagnostics(TradePlan &plan)
  {
   double patternPlusDI = 0.0;
   double patternMinusDI = 0.0;
   double entryPlusDI = 0.0;
   double entryMinusDI = 0.0;

   if(CopyIndicatorValue(adxPatternHandle, 0, 1, plan.patternADX) &&
      CopyIndicatorValue(adxPatternHandle, 1, 1, patternPlusDI) &&
      CopyIndicatorValue(adxPatternHandle, 2, 1, patternMinusDI))
     {
      plan.patternADXBucket = ADXBucket(plan.patternADX);
      plan.patternDIDirection = DIDirection(patternPlusDI, patternMinusDI);
     }
   else
     {
      plan.patternADXBucket = "unknown";
      plan.patternDIDirection = "unknown";
     }

   if(CopyIndicatorValue(adxEntryHandle, 0, 1, plan.entryADX) &&
      CopyIndicatorValue(adxEntryHandle, 1, 1, entryPlusDI) &&
      CopyIndicatorValue(adxEntryHandle, 2, 1, entryMinusDI))
     {
      plan.entryADXBucket = ADXBucket(plan.entryADX);
      plan.entryDIDirection = DIDirection(entryPlusDI, entryMinusDI);
     }
   else
     {
      plan.entryADXBucket = "unknown";
      plan.entryDIDirection = "unknown";
     }
  }

void PopulateATRDiagnostics(TradePlan &plan)
  {
   plan.patternATRValue = ATRForTimeframe(PatternTF);
   plan.entryATRValue = ATRForTimeframe(EntryTF);
   plan.patternATRPercentile = ATRPercentileForHandle(atrPatternHandle, ATRPercentileLookback);
   plan.entryATRPercentile = ATRPercentileForHandle(atrEntryHandle, ATRPercentileLookback);
   plan.patternATRBucket = ATRBucket(plan.patternATRPercentile);
   plan.entryATRBucket = ATRBucket(plan.entryATRPercentile);
  }

void PopulateSetupQualityDiagnostics(const PatternSetup &setup, TradePlan &plan)
  {
   double atr = setup.atrValue;
   if(atr <= 0.0)
      return;

   double leftDepth = MathAbs(setup.necklinePrice - setup.left.price) / atr;
   double rightDepth = MathAbs(setup.necklinePrice - setup.right.price) / atr;
   double maxDepth = MathMax(leftDepth, rightDepth);
   double minDepth = MathMin(leftDepth, rightDepth);

   plan.doubleTopBottomHeightATR = minDepth;
   plan.rightPeakDepthATR = rightDepth;
   plan.leftRightSymmetryRatio = (maxDepth > 0.0) ? minDepth / maxDepth : 0.0;
   plan.necklineDistanceATR = MathAbs(plan.signalPrice - setup.necklinePrice) / atr;

   double open1 = iOpen(runtimeSymbol, EntryTF, 1);
   double high1 = iHigh(runtimeSymbol, EntryTF, 1);
   double low1 = iLow(runtimeSymbol, EntryTF, 1);
   double close1 = iClose(runtimeSymbol, EntryTF, 1);
   double range = high1 - low1;
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || range <= 0.0)
      return;

   plan.breakCandleBodyATR = MathAbs(close1 - open1) / atr;
   plan.breakCandleClosePosition = (close1 - low1) / range;
   if(plan.breakCandleClosePosition < 0.0)
      plan.breakCandleClosePosition = 0.0;
   if(plan.breakCandleClosePosition > 1.0)
      plan.breakCandleClosePosition = 1.0;

   double alignedBody = setup.direction > 0 ? (close1 - open1) : (open1 - close1);
   plan.breakCandleDirectionStrength = alignedBody / range;
   if(plan.breakCandleBodyATR >= BreakBodyStrongATR && plan.breakCandleDirectionStrength >= 0.50)
      plan.breakCandleStrengthBucket = "high";
   else if(plan.breakCandleBodyATR >= BreakBodyMiddleATR && plan.breakCandleDirectionStrength > 0.0)
      plan.breakCandleStrengthBucket = "middle";
   else
      plan.breakCandleStrengthBucket = "low";
  }

void UpdatePlanATRDistanceRatios(TradePlan &plan)
  {
   double atr = plan.entryATRValue > 0.0 ? plan.entryATRValue : plan.atrValue;
   if(atr <= 0.0 || plan.entryPrice <= 0.0 || plan.stopLoss <= 0.0 || plan.takeProfit <= 0.0)
      return;

   plan.slDistanceATR = MathAbs(plan.entryPrice - plan.stopLoss) / atr;
   plan.tpDistanceATR = MathAbs(plan.takeProfit - plan.entryPrice) / atr;
  }

void PopulateMarketStateDiagnostics(const PatternSetup &setup, TradePlan &plan)
  {
   PopulateContextEMADiagnostics(plan);
   PopulateADXDiagnostics(plan);
   PopulateATRDiagnostics(plan);
   PopulateSetupQualityDiagnostics(setup, plan);
   PopulateOpenPositionDiagnostics(plan);
  }

void PopulatePlanDiagnostics(const PatternSetup &setup,
                             const NWaveContext &context,
                             double signalPrice,
                             double entryPrice,
                             TradePlan &plan)
  {
   ResetTradePlan(plan);

   datetime signalBarTime = iTime(runtimeSymbol, EntryTF, 1);
   datetime entryBarTime = iTime(runtimeSymbol, EntryTF, 0);
   plan.direction = setup.direction;
   plan.directionLabel = DirectionLabel(setup.direction);
   plan.strategyName = STRATEGY_NAME;
   plan.contextTimeframe = context.sourceTimeframe == "" ? TimeframeToString(ContextTF) : context.sourceTimeframe;
   plan.patternTimeframe = TimeframeToString(PatternTF);
   plan.entryTimeframe = TimeframeToString(EntryTF);
   plan.sessionName = SessionName(TimeCurrent());
   plan.signalTime = signalBarTime;
   plan.signalBarTime = signalBarTime;
   plan.entryTime = TimeCurrent();
   plan.entryBarTime = entryBarTime;
   plan.signalPrice = NormalizePrice(signalPrice);
   plan.entryPrice = NormalizePrice(entryPrice);
   plan.riskPercent = EffectiveRiskPercent();
   plan.selectedRiskPercent = plan.riskPercent;
   plan.patternType = setup.patternType;
   plan.necklinePrice = NormalizePrice(setup.necklinePrice);
   plan.leftPeakOrBottom = NormalizePrice(setup.left.price);
   plan.rightPeakOrBottom = NormalizePrice(setup.right.price);
   plan.fibExtensionValue = context.fibExtensionValue;
   plan.atrValue = setup.atrValue;
   plan.spreadPoints = GetSpreadPoints();
   plan.contextFilterPassed = context.contextFilterPassed;
   plan.fiboFilterPassed = context.fiboFilterPassed;
   plan.atrFilterPassed = context.atrFilterPassed;
   plan.spreadFilterPassed = (plan.spreadPoints <= MaxSpreadPoints);
   plan.filterMode = FilterModeLabel();
   plan.contextFilterReason = context.filterReason;
   plan.entryReason = setup.direction > 0 ? "double_bottom_neckline_close_break" : "double_top_neckline_close_break";
   plan.setupId = plan.directionLabel + "_" + IntegerToString((int)setup.right.time) + "_" + DoubleToString(plan.necklinePrice, runtimeDigits);
   plan.setupKey = plan.setupId;
   plan.setupTime = signalBarTime;
   plan.comment = STRATEGY_NAME + "_" + plan.directionLabel;
   PopulateMarketStateDiagnostics(setup, plan);
  }

bool BuildTradePlan(const PatternSetup &setup,
                    const NWaveContext &context,
                    double signalPrice,
                    double entryPrice,
                    TradePlan &plan)
  {
   PopulatePlanDiagnostics(setup, context, signalPrice, entryPrice, plan);
   if(!setup.valid || !context.valid || setup.direction != context.direction)
     {
      plan.rejectReason = ContextRejectReason(context);
      plan.valid = false;
      return false;
     }

   string staticStrategyRejectReason = "";
   if(!CheckSelectedStrategyStaticFilters(plan, staticStrategyRejectReason))
     {
      plan.rejectReason = staticStrategyRejectReason;
      plan.valid = false;
      return false;
     }

   double stopLoss = 0.0;
   double takeProfit = 0.0;
   double riskPoints = 0.0;
   double rewardPoints = 0.0;
   double rr = 0.0;
   string rejectReason = "";
   if(!CalculateSLTP(setup, entryPrice, stopLoss, takeProfit, riskPoints, rewardPoints, rr, rejectReason))
     {
      plan.rejectReason = rejectReason;
      plan.valid = false;
      return false;
     }

   plan.stopLoss = stopLoss;
   plan.takeProfit = takeProfit;
   plan.riskPoints = riskPoints;
   plan.rewardPoints = rewardPoints;
   plan.rr = rr;
   string sizingRejectReason = "";
   if(!ApplyRiskSizingToPlan(setup.direction, entryPrice, stopLoss, plan, sizingRejectReason))
     {
      plan.rejectReason = sizingRejectReason == "" ? "invalid_lot_or_risk" : sizingRejectReason;
      plan.valid = false;
      return false;
     }

   plan.valid = true;
   UpdatePlanATRDistanceRatios(plan);
   plan.rejectReason = "";
   plan.isExecutable = true;
   return true;
  }

bool HourInWindow(int hour, int startHour, int endHour)
  {
   if(startHour == endHour)
      return true;
   if(startHour < endHour)
      return (hour >= startHour && hour < endHour);
   return (hour >= startHour || hour < endHour);
  }

int MakeDailyKey(datetime stamp)
  {
   MqlDateTime tm;
   TimeToStruct(stamp, tm);
   return tm.year * 10000 + tm.mon * 100 + tm.day;
  }

int MakeWeeklyKey(datetime stamp)
  {
   MqlDateTime tm;
   TimeToStruct(stamp, tm);
   int mondayBasedDayOfWeek = (tm.day_of_week + 6) % 7;
   int week = (tm.day_of_year - mondayBasedDayOfWeek + 7) / 7;
   if(week < 0)
      week = 0;
   return tm.year * 100 + week;
  }

int MakeMonthlyKey(datetime stamp)
  {
   MqlDateTime tm;
   TimeToStruct(stamp, tm);
   return tm.year * 100 + tm.mon;
  }

void RefreshDailyState()
  {
   datetime now = TimeCurrent();
   int key = MakeDailyKey(now);
   int weekKey = MakeWeeklyKey(now);
   int monthKey = MakeMonthlyKey(now);

   if(key != dailyKey)
     {
      if(dailyKey != 0)
         WriteDailySummaryCSV("daily_rollover");
      dailyKey = key;
      dailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      virtualDailyProfit = 0.0;
      dailyProfitR = 0.0;
      consecutiveLosses = 0;
      ResetDailySummaryCounters();
     }
   if(weekKey != weeklyKey)
     {
      weeklyKey = weekKey;
      weeklyProfitR = 0.0;
     }
   if(monthKey != monthlyKey)
     {
      monthlyKey = monthKey;
      monthlyProfitR = 0.0;
     }
  }

int CountActiveVirtualTrades()
  {
   int count = 0;
   int size = ArraySize(managedTrades);
   for(int i = 0; i < size; ++i)
     {
      if(managedTrades[i].active && !managedTrades[i].live)
         count++;
     }
   return count;
  }

bool HasOpenPositionIdentifier(ulong positionId)
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      ulong currentId = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(currentId == positionId)
         return true;
     }
   return false;
  }

int CountManagedPositions()
  {
   int count = CountActiveVirtualTrades();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      count++;
     }
   return count;
  }

double TotalOpenManagedRiskMoney()
  {
   double totalRisk = 0.0;
   int size = ArraySize(managedTrades);
   for(int i = 0; i < size; ++i)
     {
      if(!managedTrades[i].active)
         continue;
      if(managedTrades[i].riskMoney > 0.0)
         totalRisk += managedTrades[i].riskMoney;
      else if(managedTrades[i].plan.plannedRiskMoney > 0.0)
         totalRisk += managedTrades[i].plan.plannedRiskMoney;
     }
   return totalRisk;
  }

bool IsDailyLossBlocked()
  {
   if(DailyMaxLossPercent <= 0.0 || dailyStartEquity <= 0.0)
      return false;

   double currentEquityChange = AccountInfoDouble(ACCOUNT_EQUITY) - dailyStartEquity + virtualDailyProfit;
   double lossLimit = dailyStartEquity * (DailyMaxLossPercent / 100.0);
   return (currentEquityChange <= -lossLimit);
  }

bool CheckRPeriodLossLimits(string &rejectReason)
  {
   if(!UseEquityCurveGuard)
      return true;

   if(MaxDailyLossR > 0.0 && dailyProfitR <= -MaxDailyLossR)
     {
      rejectReason = "daily_loss_r_blocked";
      SetStopCondition("daily_loss_r_reached");
      return false;
     }
   if(MaxWeeklyLossR > 0.0 && weeklyProfitR <= -MaxWeeklyLossR)
     {
      rejectReason = "weekly_loss_r_blocked";
      SetStopCondition("weekly_loss_r_reached");
      return false;
     }
   if(MaxMonthlyLossR > 0.0 && monthlyProfitR <= -MaxMonthlyLossR)
     {
      rejectReason = "monthly_loss_r_blocked";
      SetStopCondition("monthly_loss_r_reached");
      return false;
     }
   if(StopTradingAfterMaxDD_R > 0.0 && statMaxDrawdownR >= StopTradingAfterMaxDD_R)
     {
      rejectReason = "max_drawdown_r_blocked";
      return false;
     }
   return true;
  }

bool CheckRiskLimits(const TradePlan &plan, string &rejectReason)
  {
   rejectReason = "";
   RefreshDailyState();

   if(UseTradingSession)
     {
      MqlDateTime tm;
      TimeToStruct(TimeCurrent(), tm);
      if(!HourInWindow(tm.hour, SessionStartHour, SessionEndHour))
        {
         rejectReason = "trading_session_blocked";
         return false;
        }
     }

   if(GetSpreadPoints() > MaxSpreadPoints)
     {
      rejectReason = "spread_too_wide";
      return false;
     }
   if(IsDailyLossBlocked())
     {
      rejectReason = "daily_loss_blocked";
      return false;
     }
   if(MaxConsecutiveLosses > 0 && consecutiveLosses >= MaxConsecutiveLosses)
     {
      rejectReason = "consecutive_loss_blocked";
      return false;
     }
   if(MaxManagedPositions > 0 && CountManagedPositions() >= MaxManagedPositions)
     {
      rejectReason = "max_positions_blocked";
      return false;
     }
   if(MaxTotalOpenRiskPercent > 0.0)
     {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(equity <= 0.0)
        {
         rejectReason = "invalid_equity";
         return false;
        }
      double riskLimitMoney = equity * (MaxTotalOpenRiskPercent / 100.0);
      double plannedRiskMoney = plan.plannedRiskMoney > 0.0 ? plan.plannedRiskMoney : 0.0;
      if(TotalOpenManagedRiskMoney() + plannedRiskMoney > riskLimitMoney + 0.01)
        {
         rejectReason = "total_open_risk_blocked";
         return false;
        }
     }
   if(MinBarsBetweenEntries > 0 && plan.barsSinceLastEntry >= 0 && plan.barsSinceLastEntry < MinBarsBetweenEntries)
     {
      rejectReason = "min_bars_between_entries_blocked";
      return false;
     }
   if(AllowOnlyOnePositionForStrategy01B && IsStrategy01BMode() && CountManagedPositions() > 0)
     {
      rejectReason = "strategy01b_one_position_blocked";
      return false;
     }
   if(!CheckRPeriodLossLimits(rejectReason))
     {
      if(rejectReason == "")
         rejectReason = "equity_curve_guard_blocked";
      return false;
     }
   if(!CheckSmallCapitalChallengeLimits(rejectReason))
     {
      if(rejectReason == "")
         rejectReason = "small_capital_challenge_blocked";
      return false;
     }
   if(!CheckDrawdownPercentLimits(rejectReason))
     {
      if(rejectReason == "")
         rejectReason = "drawdown_percent_guard_blocked";
      return false;
     }
   return true;
  }

bool CheckRiskLimits()
  {
   string rejectReason = "";
   TradePlan emptyPlan;
   ResetTradePlan(emptyPlan);
   return CheckRiskLimits(emptyPlan, rejectReason);
  }

bool TrendAlignmentMatches(string tag)
  {
   if(AllowedTrendAlignmentTag == TREND_ALIGN_ANY)
      return true;
   if(AllowedTrendAlignmentTag == TREND_ALIGN_COUNTERTREND)
      return (tag == "CounterTrend");
   if(AllowedTrendAlignmentTag == TREND_ALIGN_TRENDFOLLOW)
      return (tag == "TrendFollow");
   if(AllowedTrendAlignmentTag == TREND_ALIGN_MIXEDTREND)
      return (tag == "MixedTrend");
   return true;
  }

bool BucketMatches(string bucket, DiagnosticBucketFilterOption option)
  {
   if(option == BUCKET_ANY)
      return true;
   if(option == BUCKET_LOW)
      return (bucket == "low");
   if(option == BUCKET_MIDDLE)
      return (bucket == "middle");
   if(option == BUCKET_HIGH)
      return (bucket == "high");
   return true;
  }

bool DirectionMatches(int direction)
  {
   if(AllowedDirection == DIRECTION_ANY)
      return true;
   if(AllowedDirection == DIRECTION_LONG_ONLY)
      return (direction > 0);
   if(AllowedDirection == DIRECTION_SHORT_ONLY)
      return (direction < 0);
   return true;
  }

bool CheckSelectedStrategyStaticFilters(const TradePlan &plan, string &rejectReason)
  {
   rejectReason = "";
   if(SelectedStrategyMode == STRATEGY_01_ORIGINAL)
      return true;

   if(plan.direction != DIR_SHORT)
     {
      rejectReason = "direction_filter_failed";
      return false;
     }
   if(plan.trendAlignmentTag != "CounterTrend")
     {
      rejectReason = "trend_alignment_filter_failed";
      return false;
     }
   if(plan.patternADXBucket != "middle")
     {
      rejectReason = "pattern_adx_bucket_filter_failed";
      return false;
     }

   if(SelectedStrategyMode == STRATEGY_01B_J_SHORT && plan.breakCandleStrengthBucket != "high")
     {
      rejectReason = "break_candle_strength_filter_failed";
      return false;
     }

   return true;
  }

bool CheckSelectedStrategyMode(const TradePlan &plan, string &rejectReason)
  {
   rejectReason = "";
   if(!CheckSelectedStrategyStaticFilters(plan, rejectReason))
      return false;

   if(SelectedStrategyMode == STRATEGY_01B_J_SHORT)
     {
      if(plan.entryOpenCount > 0)
        {
         rejectReason = "entry_open_count_filter_failed";
         return false;
        }
     }

   return true;
  }

bool CheckDiagnosticTagFilters(const TradePlan &plan, string &rejectReason)
  {
   rejectReason = "";

   if(UseDirectionFilter && !DirectionMatches(plan.direction))
     {
      rejectReason = "direction_filter_failed";
      return false;
     }

   if(UseTrendAlignmentFilter && !TrendAlignmentMatches(plan.trendAlignmentTag))
     {
      rejectReason = "trend_alignment_filter_failed";
      return false;
     }

   if(UsePatternADXBucketFilter && !BucketMatches(plan.patternADXBucket, AllowedPatternADXBucket))
     {
      rejectReason = "pattern_adx_bucket_filter_failed";
      return false;
     }

   if(UseBreakCandleStrengthFilter && !BucketMatches(plan.breakCandleStrengthBucket, AllowedBreakCandleStrengthBucket))
     {
      rejectReason = "break_candle_strength_filter_failed";
      return false;
     }

   if(UseEntryOpenCountFilter && plan.entryOpenCount > MaxEntryOpenCount)
     {
      rejectReason = "entry_open_count_filter_failed";
      return false;
     }

   return true;
  }

bool ApplyExecutionGuards(TradePlan &plan)
  {
   if(!plan.valid)
      return false;

   plan.spreadPoints = GetSpreadPoints();
   plan.spreadFilterPassed = (plan.spreadPoints <= MaxSpreadPoints);
   PopulateOpenPositionDiagnostics(plan);

   string rejectReason = "";
   if(!CheckSelectedStrategyMode(plan, rejectReason))
     {
      plan.valid = false;
      plan.isExecutable = false;
      plan.rejectReason = rejectReason;
      return false;
     }

   if(EnableTrading && !ForwardDemoSettingsAllowLiveTrading(rejectReason))
     {
      plan.valid = false;
      plan.isExecutable = false;
      plan.rejectReason = rejectReason;
      SetStopCondition("unsafe_forward_demo_setting_blocked");
      return false;
     }

   if(!EnableTrading && !CheckDiagnosticTagFilters(plan, rejectReason))
     {
      plan.valid = false;
      plan.isExecutable = false;
      plan.rejectReason = rejectReason;
      return false;
     }

   if(!CheckRiskLimits(plan, rejectReason))
     {
      plan.valid = false;
      plan.isExecutable = false;
      plan.rejectReason = rejectReason;
      return false;
     }

   if(!StopsAreValidForMarket(plan, plan.entryPrice))
     {
      plan.valid = false;
      plan.isExecutable = false;
      plan.rejectReason = "stops_invalid";
      return false;
     }

   plan.isExecutable = true;
   plan.rejectReason = "";
   return true;
  }

string CSVNumber(double value)
  {
   if(!MathIsValidNumber(value))
      return "0.0";
   return DoubleToString(value, 10);
  }

void CSVAppend(string &line, string value)
  {
   if(StringLen(line) > 0)
      line += ";";

   string escaped = value;
   StringReplace(escaped, "\"", "\"\"");
   bool mustQuote = (StringFind(escaped, ";") >= 0 ||
                     StringFind(escaped, "\"") >= 0 ||
                     StringFind(escaped, "\r") >= 0 ||
                     StringFind(escaped, "\n") >= 0);
   if(mustQuote)
      line += "\"" + escaped + "\"";
   else
      line += escaped;
  }

void CSVWriteLine(int handle, string &values[])
  {
   string line = "";
   int count = ArraySize(values);
   for(int i = 0; i < count; ++i)
      CSVAppend(line, values[i]);
   FileWriteString(handle, line + "\r\n");
  }

void AppendPreflightCheck(string &warnings, bool condition, string warning)
  {
   if(!condition)
      AppendWarning(warnings, warning);
  }

bool ForwardDemoUnsafeSettingWarnings(string &warnings)
  {
   warnings = "";
   AppendPreflightCheck(warnings, runtimeSymbol == "USDJPY", "symbol_not_usdjpy");
   AppendPreflightCheck(warnings, _Period == PERIOD_M5, "chart_timeframe_not_m5");
   AppendPreflightCheck(warnings, IsStrategy01BMode(), "strategy_mode_not_strategy01b_candidate");
   AppendPreflightCheck(warnings, SelectedStrategyMode == STRATEGY_01B_J_SHORT, "primary_recommendation_is_j_short");
   if(!IsAnySmallCapitalMode())
     {
      AppendPreflightCheck(warnings, RiskPercent <= 0.25 + 0.0000001, "risk_percent_above_0_25");
      AppendPreflightCheck(warnings, MaxTotalOpenRiskPercent <= 0.25 + 0.0000001, "max_total_open_risk_above_0_25");
     }
   AppendPreflightCheck(warnings, AllowOnlyOnePositionForStrategy01B, "strategy01b_one_position_not_enabled");
   AppendPreflightCheck(warnings, UseEquityCurveGuard, "equity_curve_guard_not_enabled");
   if(InpBlockNonDemoAccountForForwardDemo)
      AppendPreflightCheck(warnings, IsDemoAccount(), "account_not_demo");
   if(InpUseSmallCapitalChallengeMode && SmallCapitalRequireUsdAccount)
      AppendPreflightCheck(warnings, IsUsdAccount(), "small_capital_account_not_usd");
   if(InpUseUsd100ChallengeMode)
      AppendPreflightCheck(warnings, IsUsdAccount(), "usd100_account_not_usd");
   AppendPreflightCheck(warnings, InpUseDrawdownPercentGuards, "drawdown_percent_guards_not_enabled");
   AppendPreflightCheck(warnings, SoftPauseDrawdownPercent > 0.0, "soft_pause_drawdown_percent_not_set");
   AppendPreflightCheck(warnings, HardStopDrawdownPercent > 0.0, "hard_stop_drawdown_percent_not_set");
   AppendPreflightCheck(warnings, EmergencyStopDrawdownPercent > 0.0, "emergency_stop_drawdown_percent_not_set");
   AppendPreflightCheck(warnings, MaxSpreadPoints <= 30.0 + 0.0000001, "max_spread_points_above_30");
   return (warnings != "");
  }

bool ForwardDemoSettingsAllowLiveTrading(string &rejectReason)
  {
   rejectReason = "";
   if(InpBlockNonDemoAccountForForwardDemo && !IsDemoAccount())
     {
      rejectReason = "non_demo_account_blocked";
      return false;
     }
   if(InpUseSmallCapitalChallengeMode && SmallCapitalRequireUsdAccount && !IsUsdAccount())
     {
      rejectReason = "small_capital_non_usd_account_blocked";
      return false;
     }
   if(InpUseUsd100ChallengeMode && !IsUsdAccount())
     {
      rejectReason = "usd100_non_usd_account_blocked";
      return false;
     }

   if(!InpBlockUnsafeForwardDemoSettings)
      return true;

   bool unsafe =
      runtimeSymbol != "USDJPY" ||
      _Period != PERIOD_M5 ||
      !AllowOnlyOnePositionForStrategy01B ||
      !UseEquityCurveGuard ||
      MaxSpreadPoints > 30.0 + 0.0000001;

   if(!IsAnySmallCapitalMode())
      unsafe = unsafe ||
               RiskPercent > 0.25 + 0.0000001 ||
               MaxTotalOpenRiskPercent > 0.25 + 0.0000001;

   if(!unsafe)
      return true;

   rejectReason = "unsafe_forward_demo_setting_blocked";
   return false;
  }

void WriteForwardDemoPreflightCSV()
  {
   datetime now = TimeCurrent();
   forwardDemoRunId = runtimeSymbol + "_" + IntegerToString((int)MagicNumber) + "_" + TimestampForFile(now);
   forwardDemoPreflightFileName = "preflight_" + TimestampForFile(now) + "_" + IntegerToString((int)MagicNumber) + ".csv";

   string warnings = "";
   forwardDemoUnsafeSettings = ForwardDemoUnsafeSettingWarnings(warnings);
   forwardDemoPreflightWarnings = warnings;
   forwardDemoPreflightStatus = "PASS";
   if(warnings != "")
      forwardDemoPreflightStatus = "WARN";

   string liveReject = "";
   if(EnableTrading && !ForwardDemoSettingsAllowLiveTrading(liveReject))
     {
      forwardDemoPreflightStatus = "BLOCK";
      SetStopCondition(liveReject);
     }
   else if(runtimeSymbol != "USDJPY")
      SetStopCondition("unexpected_symbol");

   int handle = FileOpen(forwardDemoPreflightFileName,
                         FILE_CSV | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_COMMON | FILE_ANSI,
                         ';');
   if(handle == INVALID_HANDLE)
     {
      csvLogOutputFailed = true;
      SetStopCondition("csv_log_output_failed");
      Print("Forward demo preflight CSV open failed: ", forwardDemoPreflightFileName);
      return;
     }

   string header = "";
   CSVAppend(header, "run_id");
   CSVAppend(header, "timestamp");
   CSVAppend(header, "account_login");
   CSVAppend(header, "account_trade_mode");
   CSVAppend(header, "account_is_demo");
   CSVAppend(header, "account_currency");
   CSVAppend(header, "broker_server");
   CSVAppend(header, "symbol");
   CSVAppend(header, "timeframe");
   CSVAppend(header, "selected_strategy_mode");
   CSVAppend(header, "enable_trading");
   CSVAppend(header, "risk_percent");
   CSVAppend(header, "max_total_open_risk_percent");
   CSVAppend(header, "max_daily_loss_r");
   CSVAppend(header, "max_weekly_loss_r");
   CSVAppend(header, "max_monthly_loss_r");
   CSVAppend(header, "stop_trading_after_maxdd_r");
   CSVAppend(header, "block_non_demo_account");
   CSVAppend(header, "use_small_capital_challenge_mode");
   CSVAppend(header, "small_capital_require_usd_account");
   CSVAppend(header, "small_capital_use_equity_instead_of_balance");
   CSVAppend(header, "small_capital_selected_tier");
   CSVAppend(header, "small_capital_selected_risk_percent");
   CSVAppend(header, "small_capital_max_effective_risk_percent");
   CSVAppend(header, "small_capital_allow_min_lot_override");
   CSVAppend(header, "small_capital_block_if_effective_risk_too_high");
   CSVAppend(header, "small_capital_use_challenge_dd_guards");
   CSVAppend(header, "small_capital_soft_pause_dd_percent");
   CSVAppend(header, "small_capital_hard_stop_dd_percent");
   CSVAppend(header, "small_capital_ruin_dd_percent");
   CSVAppend(header, "use_usd100_challenge_mode");
   CSVAppend(header, "usd100_initial_balance");
   CSVAppend(header, "usd100_use_min_lot_only");
   CSVAppend(header, "usd100_max_lot");
   CSVAppend(header, "usd100_max_effective_risk_percent");
   CSVAppend(header, "usd100_hard_block_effective_risk_percent");
   CSVAppend(header, "usd100_block_if_margin_insufficient");
   CSVAppend(header, "usd100_block_if_effective_risk_too_high");
   CSVAppend(header, "usd100_soft_pause_dd_percent");
   CSVAppend(header, "usd100_hard_stop_dd_percent");
   CSVAppend(header, "usd100_ruin_dd_percent");
   CSVAppend(header, "use_drawdown_percent_guards");
   CSVAppend(header, "soft_pause_drawdown_percent");
   CSVAppend(header, "soft_pause_cooldown_days");
   CSVAppend(header, "hard_stop_drawdown_percent");
   CSVAppend(header, "emergency_stop_drawdown_percent");
   CSVAppend(header, "drawdown_guard_state");
   CSVAppend(header, "min_bars_between_entries");
   CSVAppend(header, "allow_only_one_position_strategy01b");
   CSVAppend(header, "use_equity_curve_guard");
   CSVAppend(header, "max_spread_points");
   CSVAppend(header, "magic_number");
   CSVAppend(header, "digits");
   CSVAppend(header, "point");
   CSVAppend(header, "stops_level");
   CSVAppend(header, "freeze_level");
   CSVAppend(header, "lot_step");
   CSVAppend(header, "min_lot");
   CSVAppend(header, "max_lot");
   CSVAppend(header, "preflight_status");
   CSVAppend(header, "preflight_warnings");
   FileWriteString(handle, header + "\r\n");

   string line = "";
   CSVAppend(line, forwardDemoRunId);
   CSVAppend(line, TimeToString(now, TIME_DATE | TIME_SECONDS));
   CSVAppend(line, IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)));
   CSVAppend(line, AccountTradeModeLabel());
   CSVAppend(line, BoolWord(IsDemoAccount()));
   CSVAppend(line, AccountInfoString(ACCOUNT_CURRENCY));
   CSVAppend(line, AccountInfoString(ACCOUNT_SERVER));
   CSVAppend(line, runtimeSymbol);
   CSVAppend(line, TimeframeToString((ENUM_TIMEFRAMES)_Period));
   CSVAppend(line, StrategyModeLabel(SelectedStrategyMode));
   CSVAppend(line, BoolWord(EnableTrading));
   CSVAppend(line, CSVNumber(RiskPercent));
   CSVAppend(line, CSVNumber(MaxTotalOpenRiskPercent));
   CSVAppend(line, CSVNumber(MaxDailyLossR));
   CSVAppend(line, CSVNumber(MaxWeeklyLossR));
   CSVAppend(line, CSVNumber(MaxMonthlyLossR));
   CSVAppend(line, CSVNumber(StopTradingAfterMaxDD_R));
   CSVAppend(line, BoolWord(InpBlockNonDemoAccountForForwardDemo));
   CSVAppend(line, BoolWord(InpUseSmallCapitalChallengeMode));
   CSVAppend(line, BoolWord(SmallCapitalRequireUsdAccount));
   CSVAppend(line, BoolWord(SmallCapitalUseEquityInsteadOfBalance));
   CSVAppend(line, InpUseSmallCapitalChallengeMode ? SmallCapitalTierLabel(SmallCapitalRiskBaseMoney()) : "standard");
   CSVAppend(line, CSVNumber(EffectiveRiskPercent()));
   CSVAppend(line, CSVNumber(SmallCapitalMaxEffectiveRiskPercent));
   CSVAppend(line, BoolWord(SmallCapitalAllowMinLotOverride));
   CSVAppend(line, BoolWord(SmallCapitalBlockIfEffectiveRiskTooHigh));
   CSVAppend(line, BoolWord(SmallCapitalUseChallengeDDGuards));
   CSVAppend(line, CSVNumber(SmallCapitalSoftPauseDDPercent));
   CSVAppend(line, CSVNumber(SmallCapitalHardStopDDPercent));
   CSVAppend(line, CSVNumber(SmallCapitalRuinDDPercent));
   CSVAppend(line, BoolWord(InpUseUsd100ChallengeMode));
   CSVAppend(line, CSVNumber(Usd100ChallengeInitialBalance));
   CSVAppend(line, BoolWord(Usd100UseMinLotOnly));
   CSVAppend(line, CSVNumber(Usd100MaxLot));
   CSVAppend(line, CSVNumber(Usd100MaxEffectiveRiskPercent));
   CSVAppend(line, CSVNumber(Usd100HardBlockEffectiveRiskPercent));
   CSVAppend(line, BoolWord(Usd100BlockIfMarginInsufficient));
   CSVAppend(line, BoolWord(Usd100BlockIfEffectiveRiskTooHigh));
   CSVAppend(line, CSVNumber(Usd100SoftPauseDDPercent));
   CSVAppend(line, CSVNumber(Usd100HardStopDDPercent));
   CSVAppend(line, CSVNumber(Usd100RuinDDPercent));
   CSVAppend(line, BoolWord(InpUseDrawdownPercentGuards));
   CSVAppend(line, CSVNumber(SoftPauseDrawdownPercent));
   CSVAppend(line, IntegerToString(SoftPauseCooldownDays));
   CSVAppend(line, CSVNumber(HardStopDrawdownPercent));
   CSVAppend(line, CSVNumber(EmergencyStopDrawdownPercent));
   CSVAppend(line, IntegerToString(drawdownGuardState));
   CSVAppend(line, IntegerToString(MinBarsBetweenEntries));
   CSVAppend(line, BoolWord(AllowOnlyOnePositionForStrategy01B));
   CSVAppend(line, BoolWord(UseEquityCurveGuard));
   CSVAppend(line, CSVNumber(MaxSpreadPoints));
   CSVAppend(line, IntegerToString((long)MagicNumber));
   CSVAppend(line, IntegerToString(runtimeDigits));
   CSVAppend(line, CSVNumber(runtimePoint));
   CSVAppend(line, IntegerToString((int)SymbolInfoInteger(runtimeSymbol, SYMBOL_TRADE_STOPS_LEVEL)));
   CSVAppend(line, IntegerToString((int)SymbolInfoInteger(runtimeSymbol, SYMBOL_TRADE_FREEZE_LEVEL)));
   CSVAppend(line, CSVNumber(SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_STEP)));
   CSVAppend(line, CSVNumber(SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_MIN)));
   CSVAppend(line, CSVNumber(SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_MAX)));
   CSVAppend(line, forwardDemoPreflightStatus);
   CSVAppend(line, forwardDemoPreflightWarnings);
   FileWriteString(handle, line + "\r\n");
   FileClose(handle);

   Print("Forward demo preflight status=", forwardDemoPreflightStatus,
         ", file=", forwardDemoPreflightFileName,
         ", warnings=", forwardDemoPreflightWarnings);
  }

void WriteDailySummaryCSV(string trigger)
  {
   if(dailyKey == 0)
      return;

   string fileName = "daily_summary_" + DailyKeyToString(dailyKey) + "_" + IntegerToString((int)MagicNumber) + ".csv";
   int handle = FileOpen(fileName,
                         FILE_CSV | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_COMMON | FILE_ANSI,
                         ';');
   if(handle == INVALID_HANDLE)
     {
      csvLogOutputFailed = true;
      SetStopCondition("csv_log_output_failed");
      Print("Forward demo daily summary CSV open failed: ", fileName);
      return;
     }

   int spreadTooWide = 0;
   int dailyLossBlocked = 0;
   int weeklyLossBlocked = 0;
   int monthlyLossBlocked = 0;
   int totalOpenRiskBlocked = 0;
   int softPauseDrawdownBlocked = 0;
   int hardStopDrawdownBlocked = 0;
   int emergencyStopDrawdownBlocked = 0;
   int smallCapitalSoftPauseBlocked = 0;
   int smallCapitalHardStopBlocked = 0;
   int smallCapitalRuinBlocked = 0;
   int usd100SoftPauseBlocked = 0;
   int usd100HardStopBlocked = 0;
   int usd100RuinBlocked = 0;
   int usd100MarginInsufficientBlocked = 0;
   int usd100EffectiveRiskBlocked = 0;
   int reasonCount = ArraySize(dailyRejectReasons);
   for(int i = 0; i < reasonCount; ++i)
     {
      if(dailyRejectReasons[i] == "spread_too_wide")
         spreadTooWide = dailyRejectCounts[i];
      else if(dailyRejectReasons[i] == "daily_loss_r_blocked")
         dailyLossBlocked = dailyRejectCounts[i];
      else if(dailyRejectReasons[i] == "weekly_loss_r_blocked")
         weeklyLossBlocked = dailyRejectCounts[i];
      else if(dailyRejectReasons[i] == "monthly_loss_r_blocked")
         monthlyLossBlocked = dailyRejectCounts[i];
      else if(dailyRejectReasons[i] == "total_open_risk_blocked")
         totalOpenRiskBlocked = dailyRejectCounts[i];
      else if(dailyRejectReasons[i] == "soft_pause_drawdown_percent")
         softPauseDrawdownBlocked = dailyRejectCounts[i];
      else if(dailyRejectReasons[i] == "hard_stop_drawdown_percent")
         hardStopDrawdownBlocked = dailyRejectCounts[i];
      else if(dailyRejectReasons[i] == "emergency_stop_drawdown_percent")
         emergencyStopDrawdownBlocked = dailyRejectCounts[i];
      else if(dailyRejectReasons[i] == "small_capital_soft_pause_dd")
         smallCapitalSoftPauseBlocked = dailyRejectCounts[i];
      else if(dailyRejectReasons[i] == "small_capital_hard_stop_dd")
         smallCapitalHardStopBlocked = dailyRejectCounts[i];
      else if(dailyRejectReasons[i] == "small_capital_ruin_dd")
         smallCapitalRuinBlocked = dailyRejectCounts[i];
      else if(dailyRejectReasons[i] == "usd100_soft_pause_dd")
         usd100SoftPauseBlocked = dailyRejectCounts[i];
      else if(dailyRejectReasons[i] == "usd100_hard_stop_dd")
         usd100HardStopBlocked = dailyRejectCounts[i];
      else if(dailyRejectReasons[i] == "usd100_ruin_dd")
         usd100RuinBlocked = dailyRejectCounts[i];
      else if(dailyRejectReasons[i] == "usd100_margin_insufficient" ||
              dailyRejectReasons[i] == "usd100_repeated_margin_insufficient")
         usd100MarginInsufficientBlocked += dailyRejectCounts[i];
      else if(dailyRejectReasons[i] == "usd100_effective_risk_too_high" ||
              dailyRejectReasons[i] == "usd100_effective_risk_hard_blocked")
         usd100EffectiveRiskBlocked += dailyRejectCounts[i];
     }

   double winRate = dailyClosedTrades > 0 ? 100.0 * (double)dailyWinTrades / (double)dailyClosedTrades : 0.0;
   double avgWinR = dailyWinTrades > 0 ? dailyGrossWinR / (double)dailyWinTrades : 0.0;
   double avgLossR = dailyLossTrades > 0 ? -dailyGrossLossR / (double)dailyLossTrades : 0.0;
   double profitFactor = dailyGrossLossR > 0.0 ? dailyGrossWinR / dailyGrossLossR : (dailyGrossWinR > 0.0 ? 999.0 : 0.0);
   double maxDailyDrawdownPercent = dailyStartEquity > 0.0 ? 100.0 * dailyMaxDrawdownMoney / dailyStartEquity : 0.0;

   string header = "";
   CSVAppend(header, "date");
   CSVAppend(header, "trigger");
   CSVAppend(header, "strategy_mode");
   CSVAppend(header, "enable_trading");
   CSVAppend(header, "total_signals");
   CSVAppend(header, "live_entries");
   CSVAppend(header, "closed_trades");
   CSVAppend(header, "realized_profit_r");
   CSVAppend(header, "realized_profit_money");
   CSVAppend(header, "win_rate");
   CSVAppend(header, "avg_win_r");
   CSVAppend(header, "avg_loss_r");
   CSVAppend(header, "pf");
   CSVAppend(header, "max_daily_dd_r");
   CSVAppend(header, "max_daily_dd_percent");
   CSVAppend(header, "consecutive_losses");
   CSVAppend(header, "reject_reason_top1");
   CSVAppend(header, "reject_reason_top2");
   CSVAppend(header, "reject_reason_top3");
   CSVAppend(header, "spread_too_wide_count");
   CSVAppend(header, "daily_loss_r_blocked_count");
   CSVAppend(header, "weekly_loss_r_blocked_count");
   CSVAppend(header, "monthly_loss_r_blocked_count");
   CSVAppend(header, "total_open_risk_blocked_count");
   CSVAppend(header, "soft_pause_drawdown_percent_count");
   CSVAppend(header, "hard_stop_drawdown_percent_count");
   CSVAppend(header, "emergency_stop_drawdown_percent_count");
   CSVAppend(header, "small_capital_soft_pause_dd_count");
   CSVAppend(header, "small_capital_hard_stop_dd_count");
   CSVAppend(header, "small_capital_ruin_dd_count");
   CSVAppend(header, "usd100_soft_pause_dd_count");
   CSVAppend(header, "usd100_hard_stop_dd_count");
   CSVAppend(header, "usd100_ruin_dd_count");
   CSVAppend(header, "usd100_margin_insufficient_count");
   CSVAppend(header, "usd100_effective_risk_blocked_count");
   CSVAppend(header, "live_order_send_failed_count");
   CSVAppend(header, "live_position_tracking_failed_count");
   CSVAppend(header, "live_sl_tp_invalid_count");
   CSVAppend(header, "live_lot_invalid_count");
   CSVAppend(header, "drawdown_percent");
   CSVAppend(header, "max_drawdown_percent");
   CSVAppend(header, "drawdown_guard_state");
   CSVAppend(header, "stop_condition_triggered");
   CSVAppend(header, "stop_reason");
   FileWriteString(handle, header + "\r\n");

   string line = "";
   CSVAppend(line, DailyKeyToString(dailyKey));
   CSVAppend(line, trigger);
   CSVAppend(line, CurrentStrategyModeForSummary());
   CSVAppend(line, BoolWord(EnableTrading));
   CSVAppend(line, IntegerToString(dailyTotalSignals));
   CSVAppend(line, IntegerToString(dailyLiveEntries));
   CSVAppend(line, IntegerToString(dailyClosedTrades));
   CSVAppend(line, CSVNumber(dailyRealizedProfitR));
   CSVAppend(line, CSVNumber(dailyRealizedProfitMoney));
   CSVAppend(line, CSVNumber(winRate));
   CSVAppend(line, CSVNumber(avgWinR));
   CSVAppend(line, CSVNumber(avgLossR));
   CSVAppend(line, CSVNumber(profitFactor));
   CSVAppend(line, CSVNumber(dailyMaxDrawdownR));
   CSVAppend(line, CSVNumber(maxDailyDrawdownPercent));
   CSVAppend(line, IntegerToString(consecutiveLosses));
   CSVAppend(line, TopRejectReasonLabel(1));
   CSVAppend(line, TopRejectReasonLabel(2));
   CSVAppend(line, TopRejectReasonLabel(3));
   CSVAppend(line, IntegerToString(spreadTooWide));
   CSVAppend(line, IntegerToString(dailyLossBlocked));
   CSVAppend(line, IntegerToString(weeklyLossBlocked));
   CSVAppend(line, IntegerToString(monthlyLossBlocked));
   CSVAppend(line, IntegerToString(totalOpenRiskBlocked));
   CSVAppend(line, IntegerToString(softPauseDrawdownBlocked));
   CSVAppend(line, IntegerToString(hardStopDrawdownBlocked));
   CSVAppend(line, IntegerToString(emergencyStopDrawdownBlocked));
   CSVAppend(line, IntegerToString(smallCapitalSoftPauseBlocked));
   CSVAppend(line, IntegerToString(smallCapitalHardStopBlocked));
   CSVAppend(line, IntegerToString(smallCapitalRuinBlocked));
   CSVAppend(line, IntegerToString(usd100SoftPauseBlocked));
   CSVAppend(line, IntegerToString(usd100HardStopBlocked));
   CSVAppend(line, IntegerToString(usd100RuinBlocked));
   CSVAppend(line, IntegerToString(usd100MarginInsufficientBlocked));
   CSVAppend(line, IntegerToString(usd100EffectiveRiskBlocked));
   CSVAppend(line, IntegerToString(dailyLiveOrderSendFailedCount));
   CSVAppend(line, IntegerToString(dailyLivePositionTrackingFailedCount));
   CSVAppend(line, IntegerToString(dailyLiveSLTPInvalidCount));
   CSVAppend(line, IntegerToString(dailyLiveLotInvalidCount));
   UpdateAccountDrawdownMetrics();
   CSVAppend(line, CSVNumber(currentDrawdownPercent));
   CSVAppend(line, CSVNumber(maxDrawdownPercent));
   CSVAppend(line, IntegerToString(drawdownGuardState));
   CSVAppend(line, BoolWord(stopConditionTriggered));
   CSVAppend(line, stopReason);
   FileWriteString(handle, line + "\r\n");
   FileClose(handle);
  }

bool OpenCSVFile()
  {
   if(!LogToCSV)
      return false;
   if(telemetryHandle != INVALID_HANDLE)
      return true;

   telemetryHandle = FileOpen(telemetryFileName,
                              FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_COMMON | FILE_ANSI,
                              ';');
   if(telemetryHandle == INVALID_HANDLE)
     {
      csvLogOutputFailed = true;
      SetStopCondition("csv_log_output_failed");
      return false;
     }

   if(FileSize(telemetryHandle) == 0)
     {
      string header =
         "Time;SetupId;SignalTime;EntryTime;SignalBarTime;EntryBarTime;ExitBarTime;Symbol;Direction;StrategyName;" +
         "ContextTF;PatternTF;EntryTF;SessionName;SignalPrice;EntryPrice;StopLoss;TakeProfit;RiskPoints;RewardPoints;" +
         "RR;LotSize;PlannedRiskMoney;RiskPercent;PatternType;NecklinePrice;LeftPeakOrBottom;RightPeakOrBottom;" +
         "FiboExtensionValue;ATRValue;SpreadPoints;ContextFilterPassed;FiboFilterPassed;ATRFilterPassed;SpreadFilterPassed;" +
         "EntryReason;RejectReason;Result;ProfitMoney;ProfitR;MFE;MAE;MFE_R;MAE_R;HoldingBars;ExitReason;FilterMode;" +
         "ContextFilterReason;IsExecutable;ContextEMAShort;ContextEMALong;ContextEMAShortAboveLong;ContextEMAShortSlopeATR;" +
         "ContextEMALongSlopeATR;ContextPriceVsEMAShort;ContextPriceVsEMALong;HTFTrendState;PatternADX;EntryADX;" +
         "PatternADXBucket;EntryADXBucket;PatternDIDirection;EntryDIDirection;PatternATR;EntryATR;PatternATRPercentile;" +
         "EntryATRPercentile;PatternATRBucket;EntryATRBucket;SLDistanceATR;TPDistanceATR;DoubleTopBottomHeightATR;" +
         "NecklineDistanceATR;RightPeakOrBottomDepthATR;LeftRightSymmetryRatio;BreakCandleBodyATR;BreakCandleClosePosition;" +
         "BreakCandleDirectionStrength;BreakCandleStrengthBucket;ContextDirectionAligned;TrendAlignmentTag;EntryOpenCount;" +
         "SameDirectionOpenCount;OppositeDirectionOpenCount;BarsSinceLastEntry;ApproximateDuplicateSetup;MFEReached05;" +
         "MFEReached10;MFE05ThenSL;MFE10ThenSL;StopConditionTriggered;StopReason;DrawdownPercent;DrawdownR;" +
         "AccountCurrency;AccountBalance;AccountEquity;SmallCapitalMode;SelectedSmallCapitalTier;SelectedRiskPercent;" +
         "DesiredRiskMoneyUsd;CalculatedLotBeforeRounding;MinLot;LotStep;FinalLot;FinalLotReason;" +
         "ActualRiskMoneyAtFinalLotUsd;EffectiveRiskPercentAtFinalLot;MarginRequired;FreeMargin;" +
         "FreeMarginAfterEntryEstimate;SmallCapitalRuinTriggered;SmallCapitalRuinReason;SmallCapitalMaxDrawdownPercent;" +
         "SmallCapitalMinEquityUsd;SmallCapitalMinMarginLevel;Usd100ChallengeMode;Usd100RiskWarning";
      FileWriteString(telemetryHandle, header + "\r\n");
     }

   FileSeek(telemetryHandle, 0, SEEK_END);
   return true;
  }

void CloseCSVFile()
  {
   if(telemetryHandle != INVALID_HANDLE)
     {
      FileClose(telemetryHandle);
      telemetryHandle = INVALID_HANDLE;
     }
  }

bool OpenExitSimulationFile()
  {
   if(!LogToCSV)
      return false;
   if(exitSimulationHandle != INVALID_HANDLE)
      return true;

   exitSimulationHandle = FileOpen(exitSimulationFileName,
                                   FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_COMMON | FILE_ANSI,
                                   ';');
   if(exitSimulationHandle == INVALID_HANDLE)
     {
      csvLogOutputFailed = true;
      SetStopCondition("csv_log_output_failed");
      return false;
     }

   if(FileSize(exitSimulationHandle) == 0)
     {
      string header =
         "Time;SetupId;SignalBarTime;EntryBarTime;ExitBarTime;Symbol;Direction;ExitSimulationMode;Result;ProfitR;" +
         "MFE_R;MAE_R;HoldingBars;ExitReason;TargetR;BETriggerR;PartialTriggerR;PartialFraction;TrendAlignmentTag;" +
         "HTFTrendState;PatternADXBucket;EntryADXBucket;PatternATRBucket;EntryATRBucket;BreakCandleStrengthBucket;" +
         "EntryOpenCount;SameDirectionOpenCount;OppositeDirectionOpenCount;SessionName;PatternType;FiboExtensionValue;" +
         "EntryPrice;StopLoss;RiskPoints;ContextDirectionAligned;ApproximateDuplicateSetup";
      FileWriteString(exitSimulationHandle, header + "\r\n");
     }

   FileSeek(exitSimulationHandle, 0, SEEK_END);
   return true;
  }

void CloseExitSimulationFile()
  {
   if(exitSimulationHandle != INVALID_HANDLE)
     {
      FileClose(exitSimulationHandle);
      exitSimulationHandle = INVALID_HANDLE;
     }
  }

bool OpenDealLevelFile()
  {
   if(!LogToCSV)
      return false;
   if(dealLevelHandle != INVALID_HANDLE)
      return true;

   dealLevelHandle = FileOpen(dealLevelFileName,
                              FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_COMMON | FILE_ANSI,
                              ';');
   if(dealLevelHandle == INVALID_HANDLE)
     {
      csvLogOutputFailed = true;
      SetStopCondition("csv_log_output_failed");
      return false;
     }

   if(FileSize(dealLevelHandle) == 0)
     {
      string header =
         "setup_id;strategy_mode;signal_time;order_send_time;planned_entry_price;planned_sl;planned_tp;planned_risk_points;" +
         "actual_entry_deal_time;actual_entry_deal_price;actual_exit_deal_time;actual_exit_deal_price;exit_reason;" +
         "actual_risk_money;realized_profit_money;commission;swap;slippage_points_entry;slippage_points_exit;" +
         "spread_at_entry;spread_at_exit;realized_r;account_balance;account_equity;peak_equity;drawdown_percent;drawdown_r;" +
         "account_currency;selected_small_capital_tier;selected_risk_percent;desired_risk_money_usd;" +
         "calculated_lot_before_rounding;min_lot;lot_step;final_lot;final_lot_reason;" +
         "actual_risk_money_at_final_lot_usd;effective_risk_percent_at_final_lot;margin_required;free_margin;" +
         "free_margin_after_entry_estimate;start_balance_usd;current_balance_usd;current_equity_usd;peak_equity_usd;" +
         "min_equity_usd;max_drawdown_percent;min_margin_level;ruin_triggered;ruin_reason;usd100_challenge_mode;usd100_risk_warning";
      FileWriteString(dealLevelHandle, header + "\r\n");
     }

   FileSeek(dealLevelHandle, 0, SEEK_END);
   return true;
  }

void CloseDealLevelFile()
  {
   if(dealLevelHandle != INVALID_HANDLE)
     {
      FileClose(dealLevelHandle);
      dealLevelHandle = INVALID_HANDLE;
     }
  }

double EntrySlippagePoints(const ManagedTrade &record)
  {
   if(runtimePoint <= 0.0 || record.actualEntryDealPrice <= 0.0 || record.plan.entryPrice <= 0.0)
      return 0.0;
   if(record.plan.direction > 0)
      return (record.actualEntryDealPrice - record.plan.entryPrice) / runtimePoint;
   return (record.plan.entryPrice - record.actualEntryDealPrice) / runtimePoint;
  }

double ExitSlippagePoints(const ManagedTrade &record, double exitPrice, string exitReason)
  {
   if(runtimePoint <= 0.0 || exitPrice <= 0.0)
      return 0.0;

   double expectedExit = 0.0;
   if(exitReason == "stop_loss")
      expectedExit = record.plan.stopLoss;
   else if(exitReason == "take_profit")
      expectedExit = record.plan.takeProfit;
   else
      return 0.0;

   if(expectedExit <= 0.0)
      return 0.0;
   if(record.plan.direction > 0)
      return (expectedExit - exitPrice) / runtimePoint;
   return (exitPrice - expectedExit) / runtimePoint;
  }

void SumPositionDealMoney(ulong positionId, double &dealProfit, double &commission, double &swap)
  {
   dealProfit = 0.0;
   commission = 0.0;
   swap = 0.0;
   datetime untilTime = TimeCurrent() + 86400;
   if(!HistorySelect(0, untilTime))
      return;

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if((ulong)HistoryDealGetInteger(ticket, DEAL_POSITION_ID) != positionId)
         continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != runtimeSymbol)
         continue;
      if((long)HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber)
         continue;
      dealProfit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
      commission += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      swap += HistoryDealGetDouble(ticket, DEAL_SWAP);
     }
  }

void PopulateEntryDealDetails(ManagedTrade &record, ulong dealTicket)
  {
   record.entryDealTicket = dealTicket;
   if(dealTicket == 0 || !HistoryDealSelect(dealTicket))
      return;

   record.actualEntryDealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
   record.actualEntryDealPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   record.entryCommission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   record.entrySwap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
   record.entrySpreadPoints = record.plan.spreadPoints;
  }

void WriteDealLevelLog(const ManagedTrade &record,
                       datetime exitDealTime,
                       double exitDealPrice,
                       string exitReason,
                       double actualRiskMoney,
                       double realizedProfitMoney,
                       double commission,
                       double swap,
                       double realizedR)
  {
   if(!LogToCSV)
      return;
   if(!OpenDealLevelFile())
      return;

   UpdateAccountDrawdownMetrics();
   double currentDrawdownR = statEquityPeakR - statEquityCurveR;
   double spreadAtExit = GetSpreadPoints();
   string line = "";
   CSVAppend(line, record.plan.setupId);
   CSVAppend(line, StrategyModeLabel(SelectedStrategyMode));
   CSVAppend(line, TimeToString(record.plan.signalTime, TIME_DATE | TIME_SECONDS));
   CSVAppend(line, record.orderSendTime > 0 ? TimeToString(record.orderSendTime, TIME_DATE | TIME_SECONDS) : "");
   CSVAppend(line, CSVNumber(record.plan.entryPrice));
   CSVAppend(line, CSVNumber(record.plan.stopLoss));
   CSVAppend(line, CSVNumber(record.plan.takeProfit));
   CSVAppend(line, CSVNumber(record.plan.riskPoints));
   CSVAppend(line, record.actualEntryDealTime > 0 ? TimeToString(record.actualEntryDealTime, TIME_DATE | TIME_SECONDS) : "");
   CSVAppend(line, CSVNumber(record.actualEntryDealPrice));
   CSVAppend(line, exitDealTime > 0 ? TimeToString(exitDealTime, TIME_DATE | TIME_SECONDS) : "");
   CSVAppend(line, CSVNumber(exitDealPrice));
   CSVAppend(line, exitReason);
   CSVAppend(line, CSVNumber(actualRiskMoney));
   CSVAppend(line, CSVNumber(realizedProfitMoney));
   CSVAppend(line, CSVNumber(commission));
   CSVAppend(line, CSVNumber(swap));
   CSVAppend(line, CSVNumber(EntrySlippagePoints(record)));
   CSVAppend(line, CSVNumber(ExitSlippagePoints(record, exitDealPrice, exitReason)));
   CSVAppend(line, CSVNumber(record.entrySpreadPoints));
   CSVAppend(line, CSVNumber(spreadAtExit));
   CSVAppend(line, CSVNumber(realizedR));
   CSVAppend(line, CSVNumber(AccountInfoDouble(ACCOUNT_BALANCE)));
   CSVAppend(line, CSVNumber(AccountInfoDouble(ACCOUNT_EQUITY)));
   CSVAppend(line, CSVNumber(accountPeakEquity));
   CSVAppend(line, CSVNumber(currentDrawdownPercent));
   CSVAppend(line, CSVNumber(currentDrawdownR));
   UpdateSmallCapitalChallengeMetrics();
   CSVAppend(line, record.plan.accountCurrency);
   CSVAppend(line, record.plan.selectedSmallCapitalTier);
   CSVAppend(line, CSVNumber(record.plan.selectedRiskPercent));
   CSVAppend(line, CSVNumber(record.plan.desiredRiskMoneyUsd));
   CSVAppend(line, CSVNumber(record.plan.calculatedLotBeforeRounding));
   CSVAppend(line, CSVNumber(record.plan.minLot));
   CSVAppend(line, CSVNumber(record.plan.lotStep));
   CSVAppend(line, CSVNumber(record.plan.finalLot));
   CSVAppend(line, record.plan.finalLotReason);
   CSVAppend(line, CSVNumber(record.plan.actualRiskMoneyAtFinalLotUsd));
   CSVAppend(line, CSVNumber(record.plan.effectiveRiskPercentAtFinalLot));
   CSVAppend(line, CSVNumber(record.plan.marginRequired));
   CSVAppend(line, CSVNumber(record.plan.freeMargin));
   CSVAppend(line, CSVNumber(record.plan.freeMarginAfterEntryEstimate));
   CSVAppend(line, CSVNumber(smallCapitalStartBalanceUsd));
   CSVAppend(line, CSVNumber(smallCapitalCurrentBalanceUsd));
   CSVAppend(line, CSVNumber(smallCapitalCurrentEquityUsd));
   CSVAppend(line, CSVNumber(smallCapitalPeakEquityUsd));
   CSVAppend(line, CSVNumber(smallCapitalMinEquityUsd));
   CSVAppend(line, CSVNumber(smallCapitalMaxDrawdownPercent));
   CSVAppend(line, CSVNumber(smallCapitalMinMarginLevel));
   CSVAppend(line, BoolWord(smallCapitalRuinTriggered));
   CSVAppend(line, smallCapitalRuinReason);
   CSVAppend(line, BoolWord(record.plan.usd100ChallengeMode));
   CSVAppend(line, record.plan.usd100RiskWarning);
   FileWriteString(dealLevelHandle, line + "\r\n");
   FileFlush(dealLevelHandle);
  }

void WriteExitSimulationLog(const ExitSimulationTrade &record,
                            string result,
                            double profitR,
                            string exitReason,
                            datetime exitBarTime)
  {
   if(!LogToCSV)
      return;
   if(!OpenExitSimulationFile())
      return;

   int holdingBars = HoldingBars(record.plan.entryBarTime, exitBarTime);
   string line = "";
   CSVAppend(line, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
   CSVAppend(line, record.plan.setupId);
   CSVAppend(line, TimeToString(record.plan.signalBarTime, TIME_DATE | TIME_SECONDS));
   CSVAppend(line, TimeToString(record.plan.entryBarTime, TIME_DATE | TIME_SECONDS));
   CSVAppend(line, exitBarTime > 0 ? TimeToString(exitBarTime, TIME_DATE | TIME_SECONDS) : "");
   CSVAppend(line, runtimeSymbol);
   CSVAppend(line, record.plan.directionLabel);
   CSVAppend(line, ExitSimulationModeLabel(record.mode));
   CSVAppend(line, result);
   CSVAppend(line, CSVNumber(profitR));
   CSVAppend(line, CSVNumber(record.mfeR));
   CSVAppend(line, CSVNumber(record.maeR));
   CSVAppend(line, IntegerToString(holdingBars));
   CSVAppend(line, exitReason);
   CSVAppend(line, CSVNumber(record.targetR));
   CSVAppend(line, CSVNumber(record.beTriggerR));
   CSVAppend(line, CSVNumber(record.partialTriggerR));
   CSVAppend(line, CSVNumber(record.partialFraction));
   CSVAppend(line, record.plan.trendAlignmentTag);
   CSVAppend(line, record.plan.htfTrendState);
   CSVAppend(line, record.plan.patternADXBucket);
   CSVAppend(line, record.plan.entryADXBucket);
   CSVAppend(line, record.plan.patternATRBucket);
   CSVAppend(line, record.plan.entryATRBucket);
   CSVAppend(line, record.plan.breakCandleStrengthBucket);
   CSVAppend(line, IntegerToString(record.plan.entryOpenCount));
   CSVAppend(line, IntegerToString(record.plan.sameDirectionOpenCount));
   CSVAppend(line, IntegerToString(record.plan.oppositeDirectionOpenCount));
   CSVAppend(line, record.plan.sessionName);
   CSVAppend(line, record.plan.patternType);
   CSVAppend(line, CSVNumber(record.plan.fibExtensionValue));
   CSVAppend(line, CSVNumber(record.plan.entryPrice));
   CSVAppend(line, CSVNumber(record.plan.stopLoss));
   CSVAppend(line, CSVNumber(record.plan.riskPoints));
   CSVAppend(line, BoolLabel(record.plan.contextDirectionAligned));
   CSVAppend(line, BoolLabel(record.plan.approximateDuplicateSetup));
   FileWriteString(exitSimulationHandle, line + "\r\n");
   FileFlush(exitSimulationHandle);
  }

void WriteCSVLog(const TradePlan &plan,
                 string result,
                 double profitMoney,
                 double profitR,
                 double mfe,
                 double mae,
                 string exitReason)
  {
   if(!LogToCSV)
      return;
   if(!OpenCSVFile())
      return;

   FileSeek(telemetryHandle, 0, SEEK_END);
   string line = "";
   CSVAppend(line, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
   CSVAppend(line, plan.setupId);
   CSVAppend(line, TimeToString(plan.signalTime, TIME_DATE | TIME_SECONDS));
   CSVAppend(line, TimeToString(plan.entryTime, TIME_DATE | TIME_SECONDS));
   CSVAppend(line, TimeToString(plan.signalBarTime, TIME_DATE | TIME_SECONDS));
   CSVAppend(line, TimeToString(plan.entryBarTime, TIME_DATE | TIME_SECONDS));
   CSVAppend(line, plan.exitBarTime > 0 ? TimeToString(plan.exitBarTime, TIME_DATE | TIME_SECONDS) : "");
   CSVAppend(line, runtimeSymbol);
   CSVAppend(line, plan.directionLabel);
   CSVAppend(line, plan.strategyName);
   CSVAppend(line, plan.contextTimeframe);
   CSVAppend(line, plan.patternTimeframe);
   CSVAppend(line, plan.entryTimeframe);
   CSVAppend(line, plan.sessionName);
   CSVAppend(line, CSVNumber(plan.signalPrice));
   CSVAppend(line, CSVNumber(plan.entryPrice));
   CSVAppend(line, CSVNumber(plan.stopLoss));
   CSVAppend(line, CSVNumber(plan.takeProfit));
   CSVAppend(line, CSVNumber(plan.riskPoints));
   CSVAppend(line, CSVNumber(plan.rewardPoints));
   CSVAppend(line, CSVNumber(plan.rr));
   CSVAppend(line, CSVNumber(plan.lotSize));
   CSVAppend(line, CSVNumber(plan.plannedRiskMoney));
   CSVAppend(line, CSVNumber(plan.riskPercent));
   CSVAppend(line, plan.patternType);
   CSVAppend(line, CSVNumber(plan.necklinePrice));
   CSVAppend(line, CSVNumber(plan.leftPeakOrBottom));
   CSVAppend(line, CSVNumber(plan.rightPeakOrBottom));
   CSVAppend(line, CSVNumber(plan.fibExtensionValue));
   CSVAppend(line, CSVNumber(plan.atrValue));
   CSVAppend(line, CSVNumber(plan.spreadPoints));
   CSVAppend(line, BoolLabel(plan.contextFilterPassed));
   CSVAppend(line, BoolLabel(plan.fiboFilterPassed));
   CSVAppend(line, BoolLabel(plan.atrFilterPassed));
   CSVAppend(line, BoolLabel(plan.spreadFilterPassed));
   CSVAppend(line, plan.entryReason);
   CSVAppend(line, plan.rejectReason);
   CSVAppend(line, result);
   CSVAppend(line, CSVNumber(profitMoney));
   CSVAppend(line, CSVNumber(profitR));
   CSVAppend(line, CSVNumber(mfe));
   CSVAppend(line, CSVNumber(mae));
   CSVAppend(line, CSVNumber(mfe));
   CSVAppend(line, CSVNumber(mae));
   CSVAppend(line, IntegerToString(plan.holdingBars));
   CSVAppend(line, exitReason);
   CSVAppend(line, plan.filterMode);
   CSVAppend(line, plan.contextFilterReason);
   CSVAppend(line, BoolLabel(plan.isExecutable));
   CSVAppend(line, CSVNumber(plan.contextEMAShort));
   CSVAppend(line, CSVNumber(plan.contextEMALong));
   CSVAppend(line, BoolLabel(plan.contextEMAShortAboveLong));
   CSVAppend(line, CSVNumber(plan.contextEMAShortSlopeATR));
   CSVAppend(line, CSVNumber(plan.contextEMALongSlopeATR));
   CSVAppend(line, plan.contextPriceVsEMAShort);
   CSVAppend(line, plan.contextPriceVsEMALong);
   CSVAppend(line, plan.htfTrendState);
   CSVAppend(line, CSVNumber(plan.patternADX));
   CSVAppend(line, CSVNumber(plan.entryADX));
   CSVAppend(line, plan.patternADXBucket);
   CSVAppend(line, plan.entryADXBucket);
   CSVAppend(line, plan.patternDIDirection);
   CSVAppend(line, plan.entryDIDirection);
   CSVAppend(line, CSVNumber(plan.patternATRValue));
   CSVAppend(line, CSVNumber(plan.entryATRValue));
   CSVAppend(line, CSVNumber(plan.patternATRPercentile));
   CSVAppend(line, CSVNumber(plan.entryATRPercentile));
   CSVAppend(line, plan.patternATRBucket);
   CSVAppend(line, plan.entryATRBucket);
   CSVAppend(line, CSVNumber(plan.slDistanceATR));
   CSVAppend(line, CSVNumber(plan.tpDistanceATR));
   CSVAppend(line, CSVNumber(plan.doubleTopBottomHeightATR));
   CSVAppend(line, CSVNumber(plan.necklineDistanceATR));
   CSVAppend(line, CSVNumber(plan.rightPeakDepthATR));
   CSVAppend(line, CSVNumber(plan.leftRightSymmetryRatio));
   CSVAppend(line, CSVNumber(plan.breakCandleBodyATR));
   CSVAppend(line, CSVNumber(plan.breakCandleClosePosition));
   CSVAppend(line, CSVNumber(plan.breakCandleDirectionStrength));
   CSVAppend(line, plan.breakCandleStrengthBucket);
   CSVAppend(line, BoolLabel(plan.contextDirectionAligned));
   CSVAppend(line, plan.trendAlignmentTag);
   CSVAppend(line, IntegerToString(plan.entryOpenCount));
   CSVAppend(line, IntegerToString(plan.sameDirectionOpenCount));
   CSVAppend(line, IntegerToString(plan.oppositeDirectionOpenCount));
   CSVAppend(line, IntegerToString(plan.barsSinceLastEntry));
   CSVAppend(line, BoolLabel(plan.approximateDuplicateSetup));
   CSVAppend(line, BoolLabel(mfe >= 0.5));
   CSVAppend(line, BoolLabel(mfe >= 1.0));
   CSVAppend(line, BoolLabel(result == "LOSS" && mfe >= 0.5));
   CSVAppend(line, BoolLabel(result == "LOSS" && mfe >= 1.0));
   UpdateAccountDrawdownMetrics();
   CSVAppend(line, BoolWord(stopConditionTriggered));
   CSVAppend(line, stopReason);
   CSVAppend(line, CSVNumber(currentDrawdownPercent));
   CSVAppend(line, CSVNumber(statEquityPeakR - statEquityCurveR));
   UpdateSmallCapitalChallengeMetrics();
   CSVAppend(line, plan.accountCurrency);
   CSVAppend(line, CSVNumber(plan.accountBalance));
   CSVAppend(line, CSVNumber(plan.accountEquity));
   CSVAppend(line, BoolWord(plan.smallCapitalMode));
   CSVAppend(line, plan.selectedSmallCapitalTier);
   CSVAppend(line, CSVNumber(plan.selectedRiskPercent));
   CSVAppend(line, CSVNumber(plan.desiredRiskMoneyUsd));
   CSVAppend(line, CSVNumber(plan.calculatedLotBeforeRounding));
   CSVAppend(line, CSVNumber(plan.minLot));
   CSVAppend(line, CSVNumber(plan.lotStep));
   CSVAppend(line, CSVNumber(plan.finalLot));
   CSVAppend(line, plan.finalLotReason);
   CSVAppend(line, CSVNumber(plan.actualRiskMoneyAtFinalLotUsd));
   CSVAppend(line, CSVNumber(plan.effectiveRiskPercentAtFinalLot));
   CSVAppend(line, CSVNumber(plan.marginRequired));
   CSVAppend(line, CSVNumber(plan.freeMargin));
   CSVAppend(line, CSVNumber(plan.freeMarginAfterEntryEstimate));
   CSVAppend(line, BoolWord(smallCapitalRuinTriggered));
   CSVAppend(line, smallCapitalRuinReason);
   CSVAppend(line, CSVNumber(smallCapitalMaxDrawdownPercent));
   CSVAppend(line, CSVNumber(smallCapitalMinEquityUsd));
   CSVAppend(line, CSVNumber(smallCapitalMinMarginLevel));
   CSVAppend(line, BoolWord(plan.usd100ChallengeMode));
   CSVAppend(line, plan.usd100RiskWarning);
   FileWriteString(telemetryHandle, line + "\r\n");
   FileFlush(telemetryHandle);
  }

void WriteRejectedSetupLog(const TradePlan &plan)
  {
   RegisterDailyRejectedSignal(plan.rejectReason);
   WriteCSVLog(plan, "REJECTED", 0.0, 0.0, 0.0, 0.0, "");
  }

int HoldingBars(datetime entryBarTime, datetime exitBarTime)
  {
   if(entryBarTime <= 0 || exitBarTime <= 0)
      return 0;
   int entryShift = iBarShift(runtimeSymbol, EntryTF, entryBarTime, true);
   int exitShift = iBarShift(runtimeSymbol, EntryTF, exitBarTime, true);
   if(entryShift < 0 || exitShift < 0)
      return 0;
   return MathAbs(entryShift - exitShift);
  }

void RecordClosedTradeStats(int direction, double profitR)
  {
   statTotalTrades++;
   statTotalR += profitR;
   statEquityCurveR += profitR;
   if(statEquityCurveR > statEquityPeakR)
      statEquityPeakR = statEquityCurveR;
   double drawdownR = statEquityPeakR - statEquityCurveR;
   if(drawdownR > statMaxDrawdownR)
      statMaxDrawdownR = drawdownR;

   if(direction > 0)
     {
      statLongTrades++;
      statLongR += profitR;
     }
   else if(direction < 0)
     {
      statShortTrades++;
      statShortR += profitR;
     }

   if(profitR > 0.0)
     {
      statWinTrades++;
      statGrossWinR += profitR;
      statCurrentLossStreak = 0;
     }
   else if(profitR < 0.0)
     {
      statLossTrades++;
      statGrossLossR += MathAbs(profitR);
      statCurrentLossStreak++;
      if(statCurrentLossStreak > statMaxConsecutiveLosses)
         statMaxConsecutiveLosses = statCurrentLossStreak;
     }
  }

double StatExpectancyR()
  {
   if(statTotalTrades <= 0)
      return 0.0;
   return statTotalR / (double)statTotalTrades;
  }

double StatProfitFactor()
  {
   if(statGrossLossR <= 0.0)
      return statGrossWinR > 0.0 ? 999.0 : 0.0;
   return statGrossWinR / statGrossLossR;
  }

void WriteSummaryCSV(string trigger)
  {
   if(summaryWritten)
      return;

   string summaryFileName = STRATEGY_NAME + "_" + runtimeSymbol + "_" + IntegerToString((int)MagicNumber) + "_summary.csv";
   int handle = FileOpen(summaryFileName,
                         FILE_CSV | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_COMMON | FILE_ANSI,
                         ';');
   if(handle == INVALID_HANDLE)
      return;

   double winRate = statTotalTrades > 0 ? 100.0 * (double)statWinTrades / (double)statTotalTrades : 0.0;
   double avgWinR = statWinTrades > 0 ? statGrossWinR / (double)statWinTrades : 0.0;
   double avgLossR = statLossTrades > 0 ? -statGrossLossR / (double)statLossTrades : 0.0;
   double longExpectancyR = statLongTrades > 0 ? statLongR / (double)statLongTrades : 0.0;
   double shortExpectancyR = statShortTrades > 0 ? statShortR / (double)statShortTrades : 0.0;
   UpdateAccountDrawdownMetrics();
   UpdateSmallCapitalChallengeMetrics();

   FileWrite(handle,
             "Time",
             "Trigger",
             "Symbol",
             "StrategyName",
             "TotalTrades",
             "WinRate",
             "AvgWinR",
             "AvgLossR",
             "ExpectancyR",
             "ProfitFactor",
             "MaxConsecutiveLosses",
             "LongTrades",
             "ShortTrades",
             "LongExpectancyR",
             "ShortExpectancyR",
             "MaxDD_R",
             "MaxDDPercent",
             "CurrentDDPercent",
             "DrawdownGuardState",
             "StopConditionTriggered",
             "StopReason",
             "AccountCurrency",
             "StartBalanceUsd",
             "CurrentBalanceUsd",
             "CurrentEquityUsd",
             "PeakEquityUsd",
             "MinEquityUsd",
             "SmallCapitalMaxDrawdownPercent",
             "MinMarginLevel",
             "SmallCapitalRuinTriggered",
             "SmallCapitalRuinReason");
   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             trigger,
             runtimeSymbol,
             STRATEGY_NAME,
             statTotalTrades,
             winRate,
             avgWinR,
             avgLossR,
             StatExpectancyR(),
             StatProfitFactor(),
             statMaxConsecutiveLosses,
             statLongTrades,
             statShortTrades,
             longExpectancyR,
             shortExpectancyR,
             statMaxDrawdownR,
             maxDrawdownPercent,
             currentDrawdownPercent,
             drawdownGuardState,
             BoolWord(stopConditionTriggered),
             stopReason,
             AccountInfoString(ACCOUNT_CURRENCY),
             smallCapitalStartBalanceUsd,
             smallCapitalCurrentBalanceUsd,
             smallCapitalCurrentEquityUsd,
             smallCapitalPeakEquityUsd,
             smallCapitalMinEquityUsd,
             smallCapitalMaxDrawdownPercent,
             smallCapitalMinMarginLevel,
             BoolWord(smallCapitalRuinTriggered),
             smallCapitalRuinReason);
   FileClose(handle);
   summaryWritten = true;
  }

string ObjectPrefix()
  {
   return STRATEGY_NAME + "_" + runtimeSymbol + "_" + IntegerToString((int)MagicNumber) + "_";
  }

void DeleteObjectsWithPrefix(string prefix)
  {
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; --i)
     {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
     }
  }

void DrawPriceLine(string name, double price, color clr, ENUM_LINE_STYLE style)
  {
   if(!DrawObjects || price <= 0.0)
      return;
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
  }

void DrawArrow(string name, datetime time, double price, int arrowCode, color clr)
  {
   if(!DrawObjects || time <= 0 || price <= 0.0)
      return;
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_ARROW, 0, time, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_TIME, time);
  }

void DrawText(string name, datetime time, double price, string text, color clr)
  {
   if(!DrawObjects || time <= 0 || price <= 0.0)
      return;
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, time, price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_TIME, time);
  }

void DrawRecentSwings()
  {
   if(!DrawObjects)
      return;

   string prefix = ObjectPrefix() + "swing_";
   DeleteObjectsWithPrefix(prefix);

   SwingPoint raw[];
   if(!DetectSwings(EntryTF, SwingDepth, EntryScanBars, raw))
      return;

   SwingPoint swings[];
   CompressAlternatingSwings(raw, swings);
   int count = ArraySize(swings);
   int first = MathMax(0, count - 20);
   for(int i = first; i < count; ++i)
     {
      SwingPoint point = swings[i];
      string name = prefix + IntegerToString((int)point.time) + (point.isHigh ? "_H" : "_L");
      int arrowCode = point.isHigh ? 234 : 233;
      color clr = point.isHigh ? clrTomato : clrDeepSkyBlue;
      DrawArrow(name, point.time, point.price, arrowCode, clr);
     }
  }

void DrawSetupObjects(const TradePlan &plan, const PatternSetup &setup)
  {
   if(!DrawObjects || !plan.valid || !setup.valid)
      return;

   string prefix = ObjectPrefix() + plan.setupKey + "_";
   color setupColor = plan.direction > 0 ? clrDeepSkyBlue : clrTomato;
   datetime breakTime = iTime(runtimeSymbol, EntryTF, 1);

   string necklineName = prefix + "neckline";
   if(ObjectFind(0, necklineName) < 0)
      ObjectCreate(0, necklineName, OBJ_TREND, 0, setup.necklinePivot.time, plan.necklinePrice, breakTime, plan.necklinePrice);
   ObjectSetInteger(0, necklineName, OBJPROP_COLOR, setupColor);
   ObjectSetInteger(0, necklineName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, necklineName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, necklineName, OBJPROP_RAY_RIGHT, false);
   ObjectSetDouble(0, necklineName, OBJPROP_PRICE, 0, plan.necklinePrice);
   ObjectSetDouble(0, necklineName, OBJPROP_PRICE, 1, plan.necklinePrice);
   ObjectSetInteger(0, necklineName, OBJPROP_TIME, 0, setup.necklinePivot.time);
   ObjectSetInteger(0, necklineName, OBJPROP_TIME, 1, breakTime);

   DrawArrow(prefix + "left", setup.left.time, setup.left.price, setup.direction > 0 ? 233 : 234, setupColor);
   DrawArrow(prefix + "right", setup.right.time, setup.right.price, setup.direction > 0 ? 233 : 234, setupColor);
   DrawArrow(prefix + "entry", breakTime, plan.entryPrice, setup.direction > 0 ? 233 : 234, clrLimeGreen);
   DrawPriceLine(prefix + "sl", plan.stopLoss, clrRed, STYLE_DOT);
   DrawPriceLine(prefix + "tp", plan.takeProfit, clrLimeGreen, STYLE_DOT);

   string label = STRATEGY_NAME + " " + plan.directionLabel + " RR=" + DoubleToString(plan.rr, 2);
   DrawText(prefix + "label", breakTime, plan.entryPrice, label, setupColor);
  }

int FindManagedTradeByPositionId(ulong positionId)
  {
   int size = ArraySize(managedTrades);
   for(int i = 0; i < size; ++i)
     {
      if(managedTrades[i].active && managedTrades[i].live && managedTrades[i].positionId == positionId)
         return i;
     }
   return -1;
  }

int FindUntrackedManagedPositionId(ulong &positionId)
  {
   positionId = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      ulong currentId = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(FindManagedTradeByPositionId(currentId) < 0)
        {
         positionId = currentId;
         return i;
        }
     }
   return -1;
  }

bool PositionIdFromDeal(ulong dealTicket, ulong &positionId)
  {
   positionId = 0;
   if(dealTicket == 0)
      return false;
   if(!HistoryDealSelect(dealTicket))
      return false;
   string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
   if(symbol != runtimeSymbol)
      return false;
   if((long)HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber)
      return false;
   positionId = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
   return (positionId > 0);
  }

int AddManagedTrade(const TradePlan &plan, bool live, ulong positionId)
  {
   int size = ArraySize(managedTrades);
   ArrayResize(managedTrades, size + 1);
   managedTrades[size].active = true;
   managedTrades[size].live = live;
   managedTrades[size].positionId = positionId;
   managedTrades[size].entryDealTicket = 0;
   managedTrades[size].plan = plan;
   managedTrades[size].entryTime = TimeCurrent();
   managedTrades[size].orderSendTime = plan.entryTime;
   managedTrades[size].actualEntryDealTime = 0;
   managedTrades[size].actualEntryDealPrice = 0.0;
   managedTrades[size].entryCommission = 0.0;
   managedTrades[size].entrySwap = 0.0;
   managedTrades[size].entrySpreadPoints = plan.spreadPoints;
   managedTrades[size].riskMoney = plan.plannedRiskMoney;
   if(managedTrades[size].riskMoney <= 0.0)
      managedTrades[size].riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * (plan.riskPercent / 100.0);
   managedTrades[size].mfeR = 0.0;
   managedTrades[size].maeR = 0.0;
   lastAcceptedEntryBarTime = plan.entryBarTime;
   return size;
  }

void AddVirtualTrade(const TradePlan &plan)
  {
   AddManagedTrade(plan, false, 0);
   RegisterDailySignal(false);
   WriteCSVLog(plan, "VIRTUAL_ENTRY", 0.0, 0.0, 0.0, 0.0, "");
   AddExitSimulationTrades(plan);
  }

void ConfigureExitSimulationMode(ExitSimulationMode mode,
                                 double &targetR,
                                 double &beTriggerR,
                                 double &partialTriggerR,
                                 double &partialFraction)
  {
   targetR = EffectiveTakeProfitRMultiple();
   beTriggerR = 0.0;
   partialTriggerR = 0.0;
   partialFraction = 0.0;

   if(mode == EXIT_BE_AT_05R)
      beTriggerR = 0.5;
   else if(mode == EXIT_BE_AT_08R)
      beTriggerR = 0.8;
   else if(mode == EXIT_BE_AT_10R)
      beTriggerR = 1.0;
   else if(mode == EXIT_PARTIAL_50_AT_05R_REST_15R)
     {
      targetR = 1.5;
      partialTriggerR = 0.5;
      partialFraction = 0.5;
     }
   else if(mode == EXIT_PARTIAL_50_AT_10R_REST_15R)
     {
      targetR = 1.5;
      partialTriggerR = 1.0;
      partialFraction = 0.5;
     }
   else if(mode == EXIT_TP_12R_FIXED)
      targetR = 1.2;
   else if(mode == EXIT_TP_15R_FIXED)
      targetR = 1.5;
  }

void AddExitSimulationTradeForMode(const TradePlan &plan, ExitSimulationMode mode)
  {
   int size = ArraySize(exitSimulationTrades);
   ArrayResize(exitSimulationTrades, size + 1);

   double targetR = 0.0;
   double beTriggerR = 0.0;
   double partialTriggerR = 0.0;
   double partialFraction = 0.0;
   ConfigureExitSimulationMode(mode, targetR, beTriggerR, partialTriggerR, partialFraction);
   if(mode != EXIT_TP_12R_FIXED && plan.rr > 0.0)
      targetR = plan.rr;

   exitSimulationTrades[size].active = true;
   exitSimulationTrades[size].mode = mode;
   exitSimulationTrades[size].plan = plan;
   exitSimulationTrades[size].targetR = targetR;
   exitSimulationTrades[size].beTriggerR = beTriggerR;
   exitSimulationTrades[size].partialTriggerR = partialTriggerR;
   exitSimulationTrades[size].partialFraction = partialFraction;
   exitSimulationTrades[size].realizedR = 0.0;
   exitSimulationTrades[size].remainingFraction = 1.0;
   exitSimulationTrades[size].beArmed = false;
   exitSimulationTrades[size].partialTaken = false;
   exitSimulationTrades[size].mfeR = 0.0;
   exitSimulationTrades[size].maeR = 0.0;
  }

void AddExitSimulationTrades(const TradePlan &plan)
  {
   for(int i = 0; i <= (int)EXIT_TP_15R_FIXED; ++i)
      AddExitSimulationTradeForMode(plan, (ExitSimulationMode)i);
  }

double PriceAtR(const TradePlan &plan, double rMultiple)
  {
   double distance = plan.riskPoints * runtimePoint * rMultiple;
   if(plan.direction > 0)
      return plan.entryPrice + distance;
   return plan.entryPrice - distance;
  }

bool OriginalStopTouched(const TradePlan &plan, double barHigh, double barLow)
  {
   if(plan.direction > 0)
      return (barLow <= plan.stopLoss);
   return (barHigh >= plan.stopLoss);
  }

bool BETouched(const TradePlan &plan, double barHigh, double barLow)
  {
   if(plan.direction > 0)
      return (barLow <= plan.entryPrice);
   return (barHigh >= plan.entryPrice);
  }

bool UpsideRTouched(const TradePlan &plan, double rMultiple, double barHigh, double barLow)
  {
   double price = PriceAtR(plan, rMultiple);
   if(plan.direction > 0)
      return (barHigh >= price);
   return (barLow <= price);
  }

void UpdateExitSimulationExcursion(ExitSimulationTrade &record, double barHigh, double barLow)
  {
   if(!record.active || record.plan.riskPoints <= 0.0 || runtimePoint <= 0.0 || barHigh <= 0.0 || barLow <= 0.0)
      return;

   double favorablePoints = 0.0;
   double adversePoints = 0.0;
   if(record.plan.direction > 0)
     {
      favorablePoints = (barHigh - record.plan.entryPrice) / runtimePoint;
      adversePoints = (record.plan.entryPrice - barLow) / runtimePoint;
     }
   else
     {
      favorablePoints = (record.plan.entryPrice - barLow) / runtimePoint;
      adversePoints = (barHigh - record.plan.entryPrice) / runtimePoint;
     }

   double favorableR = favorablePoints / record.plan.riskPoints;
   double adverseR = -adversePoints / record.plan.riskPoints;
   if(favorableR > record.mfeR)
      record.mfeR = favorableR;
   if(adverseR < record.maeR)
      record.maeR = adverseR;
  }

void CloseExitSimulationTrade(int index, string result, double profitR, string exitReason, datetime exitBarTime)
  {
   if(index < 0 || index >= ArraySize(exitSimulationTrades))
      return;

   WriteExitSimulationLog(exitSimulationTrades[index], result, profitR, exitReason, exitBarTime);
   exitSimulationTrades[index].active = false;
  }

void ProcessFixedExitSimulation(int index, double barHigh, double barLow, datetime exitBarTime)
  {
   ExitSimulationTrade record = exitSimulationTrades[index];
   bool slTouched = OriginalStopTouched(record.plan, barHigh, barLow);
   bool tpTouched = UpsideRTouched(record.plan, record.targetR, barHigh, barLow);

   if(slTouched && tpTouched)
     {
      if(ConservativeSameBarExit)
         CloseExitSimulationTrade(index, "LOSS", -1.0, "exit_sim_same_bar_stop_first", exitBarTime);
      else
         CloseExitSimulationTrade(index, "WIN", record.targetR, "exit_sim_same_bar_target_first", exitBarTime);
     }
   else if(slTouched)
      CloseExitSimulationTrade(index, "LOSS", -1.0, "exit_sim_stop_loss", exitBarTime);
   else if(tpTouched)
      CloseExitSimulationTrade(index, "WIN", record.targetR, "exit_sim_take_profit", exitBarTime);
  }

void ProcessBEExitSimulation(int index, double barHigh, double barLow, datetime exitBarTime)
  {
   ExitSimulationTrade record = exitSimulationTrades[index];
   bool originalSLTouched = OriginalStopTouched(record.plan, barHigh, barLow);
   bool triggerTouched = UpsideRTouched(record.plan, record.beTriggerR, barHigh, barLow);
   bool tpTouched = UpsideRTouched(record.plan, record.targetR, barHigh, barLow);

   if(!record.beArmed && originalSLTouched)
     {
      if(triggerTouched && ConservativeSameBarExit)
        {
         CloseExitSimulationTrade(index, "LOSS", -1.0, "exit_sim_be_same_bar_original_stop_first", exitBarTime);
         return;
        }
      if(!triggerTouched)
        {
         CloseExitSimulationTrade(index, "LOSS", -1.0, "exit_sim_stop_loss", exitBarTime);
         return;
        }
     }

   if(!record.beArmed && triggerTouched)
     {
      exitSimulationTrades[index].beArmed = true;
      record.beArmed = true;
     }

   if(record.beArmed)
     {
      bool beTouched = BETouched(record.plan, barHigh, barLow);
      if(beTouched && tpTouched)
        {
         if(ConservativeSameBarExit)
            CloseExitSimulationTrade(index, "BREAK_EVEN", 0.0, "exit_sim_same_bar_be_first", exitBarTime);
         else
            CloseExitSimulationTrade(index, "WIN", record.targetR, "exit_sim_same_bar_target_first", exitBarTime);
        }
      else if(beTouched)
         CloseExitSimulationTrade(index, "BREAK_EVEN", 0.0, "exit_sim_break_even", exitBarTime);
      else if(tpTouched)
         CloseExitSimulationTrade(index, "WIN", record.targetR, "exit_sim_take_profit", exitBarTime);
      return;
     }

   if(tpTouched)
      CloseExitSimulationTrade(index, "WIN", record.targetR, "exit_sim_take_profit", exitBarTime);
  }

void ProcessPartialExitSimulation(int index, double barHigh, double barLow, datetime exitBarTime)
  {
   ExitSimulationTrade record = exitSimulationTrades[index];
   bool originalSLTouched = OriginalStopTouched(record.plan, barHigh, barLow);
   bool partialTouched = UpsideRTouched(record.plan, record.partialTriggerR, barHigh, barLow);
   bool tpTouched = UpsideRTouched(record.plan, record.targetR, barHigh, barLow);

   if(!record.partialTaken && originalSLTouched)
     {
      if(partialTouched && ConservativeSameBarExit)
        {
         CloseExitSimulationTrade(index, "LOSS", -1.0, "exit_sim_partial_same_bar_stop_first", exitBarTime);
         return;
        }
      if(!partialTouched)
        {
         CloseExitSimulationTrade(index, "LOSS", -1.0, "exit_sim_stop_loss", exitBarTime);
         return;
        }
     }

   if(!record.partialTaken && partialTouched)
     {
      exitSimulationTrades[index].realizedR += record.partialFraction * record.partialTriggerR;
      exitSimulationTrades[index].remainingFraction = 1.0 - record.partialFraction;
      exitSimulationTrades[index].partialTaken = true;
      record = exitSimulationTrades[index];
     }

   if(record.partialTaken)
     {
      if(originalSLTouched && tpTouched)
        {
         double profitR = record.realizedR + record.remainingFraction * (ConservativeSameBarExit ? -1.0 : record.targetR);
         string result = profitR > 0.0 ? "WIN" : (profitR < 0.0 ? "LOSS" : "BREAK_EVEN");
         string reason = ConservativeSameBarExit ? "exit_sim_partial_same_bar_rest_stop_first" : "exit_sim_partial_same_bar_rest_target_first";
         CloseExitSimulationTrade(index, result, profitR, reason, exitBarTime);
        }
      else if(originalSLTouched)
        {
         double profitR = record.realizedR - record.remainingFraction;
         string result = profitR > 0.0 ? "WIN" : (profitR < 0.0 ? "LOSS" : "BREAK_EVEN");
         CloseExitSimulationTrade(index, result, profitR, "exit_sim_partial_rest_stop_loss", exitBarTime);
        }
      else if(tpTouched)
        {
         double profitR = record.realizedR + record.remainingFraction * record.targetR;
         CloseExitSimulationTrade(index, "WIN", profitR, "exit_sim_partial_rest_take_profit", exitBarTime);
        }
      return;
     }

   if(tpTouched)
      CloseExitSimulationTrade(index, "WIN", record.targetR, "exit_sim_take_profit", exitBarTime);
  }

void UpdateExitSimulationResultsOnClosedBar()
  {
   int size = ArraySize(exitSimulationTrades);
   if(size <= 0)
      return;

   double barHigh = iHigh(runtimeSymbol, EntryTF, 1);
   double barLow = iLow(runtimeSymbol, EntryTF, 1);
   datetime exitBarTime = iTime(runtimeSymbol, EntryTF, 1);
   if(barHigh <= 0.0 || barLow <= 0.0 || exitBarTime <= 0)
      return;

   for(int i = 0; i < size; ++i)
     {
      if(!exitSimulationTrades[i].active)
         continue;
      if(exitBarTime < exitSimulationTrades[i].plan.entryBarTime)
         continue;

      UpdateExitSimulationExcursion(exitSimulationTrades[i], barHigh, barLow);

      if(exitSimulationTrades[i].beTriggerR > 0.0)
         ProcessBEExitSimulation(i, barHigh, barLow, exitBarTime);
      else if(exitSimulationTrades[i].partialTriggerR > 0.0)
         ProcessPartialExitSimulation(i, barHigh, barLow, exitBarTime);
      else
         ProcessFixedExitSimulation(i, barHigh, barLow, exitBarTime);
     }
  }

void UpdateTradeExcursion(ManagedTrade &record, double exitSidePrice)
  {
   if(!record.active || record.plan.riskPoints <= 0.0 || runtimePoint <= 0.0)
      return;

   double favorablePoints = 0.0;
   double adversePoints = 0.0;
   if(record.plan.direction > 0)
     {
      favorablePoints = (exitSidePrice - record.plan.entryPrice) / runtimePoint;
      adversePoints = (record.plan.entryPrice - exitSidePrice) / runtimePoint;
     }
   else
     {
      favorablePoints = (record.plan.entryPrice - exitSidePrice) / runtimePoint;
      adversePoints = (exitSidePrice - record.plan.entryPrice) / runtimePoint;
     }

   double favorableR = favorablePoints / record.plan.riskPoints;
   double adverseR = -adversePoints / record.plan.riskPoints;
   if(favorableR > record.mfeR)
      record.mfeR = favorableR;
   if(adverseR < record.maeR)
      record.maeR = adverseR;
  }

void UpdateTradeExcursionFromRange(ManagedTrade &record, double barHigh, double barLow)
  {
   if(!record.active || record.plan.riskPoints <= 0.0 || runtimePoint <= 0.0 || barHigh <= 0.0 || barLow <= 0.0)
      return;

   double favorablePoints = 0.0;
   double adversePoints = 0.0;
   if(record.plan.direction > 0)
     {
      favorablePoints = (barHigh - record.plan.entryPrice) / runtimePoint;
      adversePoints = (record.plan.entryPrice - barLow) / runtimePoint;
     }
   else
     {
      favorablePoints = (record.plan.entryPrice - barLow) / runtimePoint;
      adversePoints = (barHigh - record.plan.entryPrice) / runtimePoint;
     }

   double favorableR = favorablePoints / record.plan.riskPoints;
   double adverseR = -adversePoints / record.plan.riskPoints;
   if(favorableR > record.mfeR)
      record.mfeR = favorableR;
   if(adverseR < record.maeR)
      record.maeR = adverseR;
  }

void RegisterClosedOutcome(double profitMoney, double profitR, bool addToVirtualDailyProfit)
  {
   RefreshDailyState();
   if(addToVirtualDailyProfit)
      virtualDailyProfit += profitMoney;
   dailyProfitR += profitR;
   weeklyProfitR += profitR;
   monthlyProfitR += profitR;
   RegisterDailyClosedTrade(profitR, profitMoney);
   if(profitR < 0.0)
      consecutiveLosses++;
   else if(profitR > 0.0)
      consecutiveLosses = 0;
   EvaluateRStopConditions();
   EvaluateDrawdownPercentStopConditions();
  }

void CloseVirtualTrade(int index, string result, double profitR, string exitReason, datetime exitBarTime)
  {
   if(index < 0 || index >= ArraySize(managedTrades))
      return;

   ManagedTrade record = managedTrades[index];
   double profitMoney = record.riskMoney * profitR;
   RegisterClosedOutcome(profitMoney, profitR, true);
   RecordClosedTradeStats(record.plan.direction, profitR);

   TradePlan exitPlan = record.plan;
   exitPlan.exitBarTime = exitBarTime;
   exitPlan.holdingBars = HoldingBars(exitPlan.entryBarTime, exitBarTime);
   WriteCSVLog(exitPlan, result, profitMoney, profitR, record.mfeR, record.maeR, exitReason);
   managedTrades[index].active = false;
  }

void UpdateVirtualTradeResults()
  {
   int size = ArraySize(managedTrades);
   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return;

   for(int i = 0; i < size; ++i)
     {
      if(!managedTrades[i].active || managedTrades[i].live)
         continue;

      TradePlan plan = managedTrades[i].plan;
      double exitSidePrice = (plan.direction > 0) ? bid : ask;
      UpdateTradeExcursion(managedTrades[i], exitSidePrice);
     }
  }

void UpdateVirtualTradeResultsOnClosedBar()
  {
   int size = ArraySize(managedTrades);
   double barHigh = iHigh(runtimeSymbol, EntryTF, 1);
   double barLow = iLow(runtimeSymbol, EntryTF, 1);
   datetime exitBarTime = iTime(runtimeSymbol, EntryTF, 1);
   if(barHigh <= 0.0 || barLow <= 0.0 || exitBarTime <= 0)
      return;

   for(int i = 0; i < size; ++i)
     {
      if(!managedTrades[i].active || managedTrades[i].live)
         continue;

      TradePlan plan = managedTrades[i].plan;
      if(exitBarTime < plan.entryBarTime)
         continue;

      UpdateTradeExcursionFromRange(managedTrades[i], barHigh, barLow);

      bool slTouched = false;
      bool tpTouched = false;
      if(plan.direction > 0)
        {
         slTouched = (barLow <= plan.stopLoss);
         tpTouched = (barHigh >= plan.takeProfit);
        }
      else
        {
         slTouched = (barHigh >= plan.stopLoss);
         tpTouched = (barLow <= plan.takeProfit);
        }

      if(slTouched && tpTouched)
        {
         if(ConservativeSameBarExit)
            CloseVirtualTrade(i, "LOSS", -1.0, "virtual_same_bar_stop_first", exitBarTime);
         else
            CloseVirtualTrade(i, "WIN", plan.rr, "virtual_same_bar_target_first", exitBarTime);
        }
      else if(slTouched)
         CloseVirtualTrade(i, "LOSS", -1.0, "virtual_stop_loss", exitBarTime);
      else if(tpTouched)
         CloseVirtualTrade(i, "WIN", plan.rr, "virtual_take_profit", exitBarTime);
     }
  }

void UpdateLiveTradeExcursions()
  {
   int size = ArraySize(managedTrades);
   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return;

   for(int i = 0; i < size; ++i)
     {
      if(!managedTrades[i].active || !managedTrades[i].live)
         continue;
      double exitSidePrice = managedTrades[i].plan.direction > 0 ? bid : ask;
      UpdateTradeExcursion(managedTrades[i], exitSidePrice);
     }
  }

bool StopsAreValidForMarket(const TradePlan &plan, double entryPrice)
  {
   int stopsLevel = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopsLevel * runtimePoint;
   if(minDistance <= 0.0)
      return true;

   if(plan.direction > 0)
      return ((entryPrice - plan.stopLoss) >= minDistance && (plan.takeProfit - entryPrice) >= minDistance);
   return ((plan.stopLoss - entryPrice) >= minDistance && (entryPrice - plan.takeProfit) >= minDistance);
  }

void CheckManagedPositionsHaveStops()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      if(sl <= 0.0 || tp <= 0.0)
        {
         SetStopCondition("missing_sl_tp_order");
         return;
        }
     }
  }

bool OpenTrade(const TradePlan &plan)
  {
   if(!plan.valid)
      return false;

   string forwardDemoRejectReason = "";
   if(!ForwardDemoSettingsAllowLiveTrading(forwardDemoRejectReason))
     {
      TradePlan rejectedPlan = plan;
      rejectedPlan.valid = false;
      rejectedPlan.isExecutable = false;
      rejectedPlan.rejectReason = forwardDemoRejectReason;
      SetStopCondition(forwardDemoRejectReason);
      WriteRejectedSetupLog(rejectedPlan);
      return false;
     }

   double marketEntry = plan.direction > 0 ? SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK)
                                           : SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   if(marketEntry <= 0.0)
     {
      TradePlan rejectedPlan = plan;
      rejectedPlan.valid = false;
      rejectedPlan.isExecutable = false;
      rejectedPlan.rejectReason = "invalid_entry_price";
      WriteRejectedSetupLog(rejectedPlan);
      return false;
     }

   TradePlan actualPlan = plan;
   double riskPoints = 0.0;
   double rewardPoints = 0.0;
   double rr = 0.0;
   double stopLoss = 0.0;
   double takeProfit = 0.0;

   PatternSetup minimalSetup;
   ResetPattern(minimalSetup);
   minimalSetup.valid = true;
   minimalSetup.direction = plan.direction;
   minimalSetup.right.valid = true;
   minimalSetup.right.price = plan.direction > 0 ? plan.stopLoss + plan.atrValue * SLBufferATR
                                                 : plan.stopLoss - plan.atrValue * SLBufferATR;
   minimalSetup.atrValue = plan.atrValue;

   string rejectReason = "";
   if(!CalculateSLTP(minimalSetup, marketEntry, stopLoss, takeProfit, riskPoints, rewardPoints, rr, rejectReason))
     {
      actualPlan.valid = false;
      actualPlan.isExecutable = false;
      actualPlan.rejectReason = "live_sl_tp_invalid";
      WriteRejectedSetupLog(actualPlan);
      return false;
     }

   actualPlan.entryPrice = NormalizePrice(marketEntry);
   actualPlan.entryTime = TimeCurrent();
   actualPlan.entryBarTime = iTime(runtimeSymbol, EntryTF, 0);
   actualPlan.stopLoss = stopLoss;
   actualPlan.takeProfit = takeProfit;
   actualPlan.riskPoints = riskPoints;
   actualPlan.rewardPoints = rewardPoints;
   actualPlan.rr = rr;
   string sizingRejectReason = "";
   if(!ApplyRiskSizingToPlan(actualPlan.direction, actualPlan.entryPrice, actualPlan.stopLoss, actualPlan, sizingRejectReason))
     {
      actualPlan.valid = false;
      actualPlan.isExecutable = false;
      actualPlan.rejectReason = sizingRejectReason == "" ? "live_lot_invalid" : sizingRejectReason;
      WriteRejectedSetupLog(actualPlan);
      return false;
     }
   actualPlan.spreadPoints = GetSpreadPoints();
   PopulateOpenPositionDiagnostics(actualPlan);
   UpdatePlanATRDistanceRatios(actualPlan);

   string riskRejectReason = "";
   if(!CheckRiskLimits(actualPlan, riskRejectReason))
     {
      actualPlan.valid = false;
      actualPlan.isExecutable = false;
      actualPlan.rejectReason = riskRejectReason;
      WriteRejectedSetupLog(actualPlan);
      return false;
     }

   if(actualPlan.lotSize <= 0.0 || actualPlan.plannedRiskMoney <= 0.0 || actualPlan.stopLoss <= 0.0 || actualPlan.takeProfit <= 0.0)
     {
      actualPlan.valid = false;
      actualPlan.isExecutable = false;
      actualPlan.rejectReason = "live_lot_invalid";
      WriteRejectedSetupLog(actualPlan);
      return false;
     }
   if(!StopsAreValidForMarket(actualPlan, marketEntry))
     {
      actualPlan.valid = false;
      actualPlan.isExecutable = false;
      actualPlan.rejectReason = "live_sl_tp_invalid";
      WriteRejectedSetupLog(actualPlan);
      return false;
     }

   bool result = false;
   if(actualPlan.direction > 0)
      result = trade.Buy(actualPlan.lotSize, runtimeSymbol, 0.0, actualPlan.stopLoss, actualPlan.takeProfit, actualPlan.comment);
   else
      result = trade.Sell(actualPlan.lotSize, runtimeSymbol, 0.0, actualPlan.stopLoss, actualPlan.takeProfit, actualPlan.comment);

   if(!result)
     {
      if(DebugMode)
         Print("Order failed: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
      actualPlan.valid = false;
      actualPlan.isExecutable = false;
      actualPlan.rejectReason = "live_order_send_failed";
      WriteRejectedSetupLog(actualPlan);
      return false;
     }

   ulong positionId = 0;
   ulong dealTicket = trade.ResultDeal();
   bool tracked = PositionIdFromDeal(dealTicket, positionId);
   if(!tracked && FindUntrackedManagedPositionId(positionId) >= 0)
      tracked = true;
   if(tracked)
     {
      int managedIndex = AddManagedTrade(actualPlan, true, positionId);
      if(managedIndex >= 0)
         PopulateEntryDealDetails(managedTrades[managedIndex], dealTicket);
     }
   else
     {
      actualPlan.rejectReason = "live_position_tracking_failed";
      RegisterDailySignal(true);
      RegisterLivePositionTrackingFailure();
      WriteCSVLog(actualPlan, "LIVE_ENTRY_UNTRACKED", 0.0, 0.0, 0.0, 0.0, "live_position_tracking_failed");
      return true;
     }

   RegisterDailySignal(true);
   WriteCSVLog(actualPlan, "LIVE_ENTRY", 0.0, 0.0, 0.0, 0.0, "");
   return true;
  }

bool BuildCandidateForDirection(int direction, TradePlan &plan, PatternSetup &setup)
  {
   ResetTradePlan(plan);
   ResetPattern(setup);

   bool hasPattern = false;
   if(direction > 0)
      hasPattern = DetectDoubleBottom(setup);
   else
      hasPattern = DetectDoubleTop(setup);
   if(!hasPattern)
      return false;

   double signalPrice = iClose(runtimeSymbol, EntryTF, 1);
   double entryPrice = MarketEntryPrice(direction);
   if(signalPrice <= 0.0 || entryPrice <= 0.0)
     {
      NWaveContext emptyContext;
      ResetNWave(emptyContext);
      emptyContext.direction = direction;
      emptyContext.filterReason = "invalid_entry_price";
      PopulatePlanDiagnostics(setup, emptyContext, signalPrice, entryPrice, plan);
      plan.rejectReason = "invalid_entry_price";
      return true;
     }

   NWaveContext context;
   ResetNWave(context);
   if(!DetectNWave(direction, context))
     {
      PopulatePlanDiagnostics(setup, context, signalPrice, entryPrice, plan);
      plan.rejectReason = ContextRejectReason(context);
      return true;
     }

   BuildTradePlan(setup, context, signalPrice, entryPrice, plan);
   return true;
  }

bool SelectPlan(const TradePlan &longPlan,
                const PatternSetup &longSetup,
                bool hasLongPlan,
                const TradePlan &shortPlan,
                const PatternSetup &shortSetup,
                bool hasShortPlan,
                TradePlan &selectedPlan,
                PatternSetup &selectedSetup,
                TradePlan &rejectedOtherPlan)
  {
   ResetTradePlan(selectedPlan);
   ResetPattern(selectedSetup);
   ResetTradePlan(rejectedOtherPlan);

   bool longExecutable = hasLongPlan && longPlan.valid && longPlan.isExecutable;
   bool shortExecutable = hasShortPlan && shortPlan.valid && shortPlan.isExecutable;

   if(longExecutable && !shortExecutable)
     {
      selectedPlan = longPlan;
      selectedSetup = longSetup;
      return true;
     }
   if(shortExecutable && !longExecutable)
     {
      selectedPlan = shortPlan;
      selectedSetup = shortSetup;
      return true;
     }
   if(!longExecutable && !shortExecutable)
      return false;

   if(longSetup.right.time >= shortSetup.right.time)
     {
      selectedPlan = longPlan;
      selectedSetup = longSetup;
      rejectedOtherPlan = shortPlan;
     }
   else
     {
      selectedPlan = shortPlan;
      selectedSetup = shortSetup;
      rejectedOtherPlan = longPlan;
     }
   return true;
  }

void ProcessNewEntryBar()
  {
   DrawRecentSwings();

   TradePlan longPlan;
   TradePlan shortPlan;
   PatternSetup longSetup;
   PatternSetup shortSetup;
   bool hasLongPlan = BuildCandidateForDirection(DIR_LONG, longPlan, longSetup);
   bool hasShortPlan = BuildCandidateForDirection(DIR_SHORT, shortPlan, shortSetup);
   if(!hasLongPlan && !hasShortPlan)
      return;

   if(hasLongPlan && longPlan.valid)
      ApplyExecutionGuards(longPlan);
   if(hasShortPlan && shortPlan.valid)
      ApplyExecutionGuards(shortPlan);

   if(hasLongPlan && !longPlan.valid && longPlan.rejectReason != "")
      WriteRejectedSetupLog(longPlan);
   if(hasShortPlan && !shortPlan.valid && shortPlan.rejectReason != "")
      WriteRejectedSetupLog(shortPlan);

   TradePlan plan;
   TradePlan rejectedOtherPlan;
   PatternSetup setup;
   if(!SelectPlan(longPlan, longSetup, hasLongPlan, shortPlan, shortSetup, hasShortPlan, plan, setup, rejectedOtherPlan))
      return;

   if(rejectedOtherPlan.setupId != "")
     {
      rejectedOtherPlan.valid = false;
      rejectedOtherPlan.isExecutable = false;
      rejectedOtherPlan.rejectReason = "candidate_not_selected";
      WriteRejectedSetupLog(rejectedOtherPlan);
     }

   if(plan.setupKey == lastLoggedSetupKey)
      return;

   lastLoggedSetupKey = plan.setupKey;
   DrawSetupObjects(plan, setup);

   if(EnableTrading)
      OpenTrade(plan);
   else
      AddVirtualTrade(plan);
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
   if((long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != MagicNumber)
      return;

   ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(dealEntry != DEAL_ENTRY_OUT && dealEntry != DEAL_ENTRY_OUT_BY && dealEntry != DEAL_ENTRY_INOUT)
      return;

   ulong positionId = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   int index = FindManagedTradeByPositionId(positionId);
   if(index < 0)
      return;

   bool stillOpen = HasOpenPositionIdentifier(positionId);
   string exitReason = "live_exit";
   double dealPrice = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   datetime dealTime = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
   double tolerance = runtimePoint * 2.0;
   TradePlan plan = managedTrades[index].plan;
   if(plan.direction > 0)
     {
      if(dealPrice <= plan.stopLoss + tolerance)
         exitReason = "stop_loss";
      else if(dealPrice >= plan.takeProfit - tolerance)
         exitReason = "take_profit";
     }
   else
     {
      if(dealPrice >= plan.stopLoss - tolerance)
         exitReason = "stop_loss";
      else if(dealPrice <= plan.takeProfit + tolerance)
         exitReason = "take_profit";
     }

   if(!stillOpen)
     {
      double dealProfit = 0.0;
      double totalCommission = 0.0;
      double totalSwap = 0.0;
      SumPositionDealMoney(positionId, dealProfit, totalCommission, totalSwap);
      double profitMoney = dealProfit + totalCommission + totalSwap;
      if(profitMoney == 0.0)
         profitMoney = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) +
                       HistoryDealGetDouble(trans.deal, DEAL_SWAP) +
                       HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

      double profitR = 0.0;
      if(managedTrades[index].riskMoney > 0.0)
         profitR = profitMoney / managedTrades[index].riskMoney;

      string result = profitR > 0.0 ? "WIN" : (profitR < 0.0 ? "LOSS" : "FLAT");
      UpdateTradeExcursion(managedTrades[index], dealPrice);
      RegisterClosedOutcome(profitMoney, profitR, false);
      RecordClosedTradeStats(plan.direction, profitR);
      TradePlan exitPlan = plan;
      exitPlan.exitBarTime = iTime(runtimeSymbol, EntryTF, 0);
      exitPlan.holdingBars = HoldingBars(exitPlan.entryBarTime, exitPlan.exitBarTime);
      WriteDealLevelLog(managedTrades[index], dealTime, dealPrice, exitReason,
                        managedTrades[index].riskMoney, profitMoney,
                        totalCommission, totalSwap, profitR);
      WriteCSVLog(exitPlan, result, profitMoney, profitR, managedTrades[index].mfeR, managedTrades[index].maeR, exitReason);
      managedTrades[index].active = false;
     }
  }

int OnInit()
  {
   runtimeSymbol = _Symbol;
   runtimePoint = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   runtimeDigits = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_DIGITS);

   if(runtimePoint <= 0.0 || runtimeDigits < 0)
      return INIT_FAILED;
   if(MagicNumber <= 0 || RiskPercent <= 0.0 || RiskPercent > 2.0 ||
      DailyMaxLossPercent < 0.0 || MaxConsecutiveLosses < 0 || MaxManagedPositions < 0 ||
      SwingDepth < 1 || ContextScanBars <= SwingDepth * 3 || PatternScanBars <= SwingDepth * 3 ||
      EntryScanBars <= SwingDepth * 3 || DoubleTopBottomToleranceATR <= 0.0 ||
      NecklineBreakBufferATR < 0.0 || SLBufferATR < 0.0 || TakeProfitRMultiple <= 0.0 ||
      MinRR <= 0.0 || MaxSpreadPoints <= 0.0 || ATRPeriod <= 0 ||
      EMAShortPeriod <= 0 || EMALongPeriod <= 0 || EMAShortPeriod >= EMALongPeriod ||
      EMASlopeBars <= 0 || EMAFlatSlopeATR < 0.0 || ADXPeriod <= 0 ||
      ADXLowThreshold <= 0.0 || ADXHighThreshold <= ADXLowThreshold ||
      ATRPercentileLookback <= 10 || ATRLowPercentile < 0.0 || ATRHighPercentile > 100.0 ||
      ATRLowPercentile >= ATRHighPercentile || BreakBodyMiddleATR < 0.0 ||
      BreakBodyStrongATR < BreakBodyMiddleATR || DuplicateLookbackBars < 0 ||
      MaxEntryOpenCount < 0 || MaxTotalOpenRiskPercent < 0.0 || MaxDailyLossR < 0.0 ||
      MaxWeeklyLossR < 0.0 || MaxMonthlyLossR < 0.0 || StopTradingAfterMaxDD_R < 0.0 ||
      MinBarsBetweenEntries < 0 || SoftPauseCooldownDays < 0 ||
      SoftPauseDrawdownPercent < 0.0 || HardStopDrawdownPercent < 0.0 ||
      EmergencyStopDrawdownPercent < 0.0 ||
      SmallCapitalTier1EquityUsd <= 0.0 || SmallCapitalTier2EquityUsd <= SmallCapitalTier1EquityUsd ||
      SmallCapitalTier1RiskPercent <= 0.0 || SmallCapitalTier2RiskPercent <= 0.0 ||
      SmallCapitalTier3RiskPercent <= 0.0 || SmallCapitalMaxEffectiveRiskPercent <= 0.0 ||
      SmallCapitalSoftPauseDDPercent < 0.0 || SmallCapitalHardStopDDPercent < 0.0 ||
      SmallCapitalRuinDDPercent < 0.0 ||
      (SmallCapitalHardStopDDPercent > 0.0 && SmallCapitalRuinDDPercent > 0.0 &&
       SmallCapitalRuinDDPercent < SmallCapitalHardStopDDPercent) ||
      (SmallCapitalSoftPauseDDPercent > 0.0 && SmallCapitalHardStopDDPercent > 0.0 &&
       SmallCapitalHardStopDDPercent < SmallCapitalSoftPauseDDPercent) ||
      Usd100ChallengeInitialBalance <= 0.0 || Usd100MaxLot <= 0.0 ||
      Usd100MaxEffectiveRiskPercent <= 0.0 || Usd100HardBlockEffectiveRiskPercent <= 0.0 ||
      Usd100HardBlockEffectiveRiskPercent < Usd100MaxEffectiveRiskPercent ||
      Usd100SoftPauseDDPercent < 0.0 || Usd100HardStopDDPercent < 0.0 ||
      Usd100RuinDDPercent < 0.0 ||
      (Usd100HardStopDDPercent > 0.0 && Usd100RuinDDPercent > 0.0 &&
       Usd100RuinDDPercent < Usd100HardStopDDPercent) ||
      (Usd100SoftPauseDDPercent > 0.0 && Usd100HardStopDDPercent > 0.0 &&
       Usd100HardStopDDPercent < Usd100SoftPauseDDPercent) ||
      (HardStopDrawdownPercent > 0.0 && EmergencyStopDrawdownPercent > 0.0 &&
       EmergencyStopDrawdownPercent < HardStopDrawdownPercent) ||
      (SoftPauseDrawdownPercent > 0.0 && HardStopDrawdownPercent > 0.0 &&
       HardStopDrawdownPercent < SoftPauseDrawdownPercent) ||
      SessionStartHour < 0 || SessionStartHour > 23 || SessionEndHour < 0 || SessionEndHour > 24 ||
      FiboExtensionMin <= 0.0 || MinATRPoints < 0.0)
      return INIT_PARAMETERS_INCORRECT;

   trade.SetExpertMagicNumber((ulong)MagicNumber);
   trade.SetTypeFillingBySymbol(runtimeSymbol);

   atrContextHandle = iATR(runtimeSymbol, ContextTF, ATRPeriod);
   atrPatternHandle = iATR(runtimeSymbol, PatternTF, ATRPeriod);
   atrEntryHandle = iATR(runtimeSymbol, EntryTF, ATRPeriod);
   emaContextShortHandle = iMA(runtimeSymbol, ContextTF, EMAShortPeriod, 0, MODE_EMA, PRICE_CLOSE);
   emaContextLongHandle = iMA(runtimeSymbol, ContextTF, EMALongPeriod, 0, MODE_EMA, PRICE_CLOSE);
   adxPatternHandle = iADX(runtimeSymbol, PatternTF, ADXPeriod);
   adxEntryHandle = iADX(runtimeSymbol, EntryTF, ADXPeriod);
   if(atrContextHandle == INVALID_HANDLE || atrPatternHandle == INVALID_HANDLE || atrEntryHandle == INVALID_HANDLE ||
      emaContextShortHandle == INVALID_HANDLE || emaContextLongHandle == INVALID_HANDLE ||
      adxPatternHandle == INVALID_HANDLE || adxEntryHandle == INVALID_HANDLE)
      return INIT_FAILED;

   telemetryFileName = STRATEGY_NAME + "_" + runtimeSymbol + "_" + IntegerToString((int)MagicNumber) + "_diagnostics.csv";
   exitSimulationFileName = STRATEGY_NAME + "_" + runtimeSymbol + "_" + IntegerToString((int)MagicNumber) + "_exit_simulation.csv";
   dealLevelFileName = STRATEGY_NAME + "_" + runtimeSymbol + "_" + IntegerToString((int)MagicNumber) + "_deal_level.csv";
   accountInitialEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   accountPeakEquity = accountInitialEquity;
   currentDrawdownPercent = 0.0;
   maxDrawdownPercent = 0.0;
   smallCapitalStartBalanceUsd = AccountInfoDouble(ACCOUNT_BALANCE);
   smallCapitalCurrentBalanceUsd = smallCapitalStartBalanceUsd;
   smallCapitalCurrentEquityUsd = AccountInfoDouble(ACCOUNT_EQUITY);
   smallCapitalPeakEquityUsd = smallCapitalCurrentEquityUsd;
   smallCapitalMinEquityUsd = smallCapitalCurrentEquityUsd;
   smallCapitalMaxDrawdownPercent = 0.0;
   smallCapitalMinMarginLevel = 0.0;
   smallCapitalRuinTriggered = false;
   smallCapitalRuinReason = "";
   smallCapitalConsecutiveMarginInsufficient = 0;
   LoadDrawdownGuardState();
   RefreshDailyState();
   ArrayResize(managedTrades, 0);
   ArrayResize(exitSimulationTrades, 0);
   WriteForwardDemoPreflightCSV();

   if(DrawObjects)
      DeleteObjectsWithPrefix(ObjectPrefix() + "swing_");
   if(LogToCSV)
     {
      OpenCSVFile();
      OpenExitSimulationFile();
      OpenDealLevelFile();
     }

   Print(STRATEGY_NAME, " initialized on ", runtimeSymbol, ". EnableTrading=", EnableTrading ? "true" : "false",
         ". StrategyMode=", StrategyModeLabel(SelectedStrategyMode),
         ". ForwardDemoPreflight=", forwardDemoPreflightStatus,
         ". ForwardDemoWarnings=", forwardDemoPreflightWarnings,
         ". EffectiveTPR=", DoubleToString(EffectiveTakeProfitRMultiple(), 2),
         ". ExitSimulationModeInput=", ExitSimulationModeLabel(ExitSimulationModeInput),
         ". TrendFilter=", UseTrendAlignmentFilter ? TrendAlignmentOptionLabel(AllowedTrendAlignmentTag) : "off",
         ". PatternADXFilter=", UsePatternADXBucketFilter ? BucketOptionLabel(AllowedPatternADXBucket) : "off",
         ". BreakStrengthFilter=", UseBreakCandleStrengthFilter ? BucketOptionLabel(AllowedBreakCandleStrengthBucket) : "off",
         ". EntryOpenFilter=", UseEntryOpenCountFilter ? IntegerToString(MaxEntryOpenCount) : "off",
         ". DirectionFilter=", UseDirectionFilter ? DirectionOptionLabel(AllowedDirection) : "off",
         ". DDPercentGuards=", InpUseDrawdownPercentGuards ? "on" : "off",
         ". SoftDD=", DoubleToString(SoftPauseDrawdownPercent, 2),
         ". HardDD=", DoubleToString(HardStopDrawdownPercent, 2),
         ". EmergencyDD=", DoubleToString(EmergencyStopDrawdownPercent, 2));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int)
  {
   WriteDailySummaryCSV("OnDeinit");
   WriteSummaryCSV("OnDeinit");
   if(atrContextHandle != INVALID_HANDLE)
      IndicatorRelease(atrContextHandle);
   if(atrPatternHandle != INVALID_HANDLE)
      IndicatorRelease(atrPatternHandle);
   if(atrEntryHandle != INVALID_HANDLE)
      IndicatorRelease(atrEntryHandle);
   if(emaContextShortHandle != INVALID_HANDLE)
      IndicatorRelease(emaContextShortHandle);
   if(emaContextLongHandle != INVALID_HANDLE)
      IndicatorRelease(emaContextLongHandle);
   if(adxPatternHandle != INVALID_HANDLE)
      IndicatorRelease(adxPatternHandle);
   if(adxEntryHandle != INVALID_HANDLE)
      IndicatorRelease(adxEntryHandle);
   CloseCSVFile();
   CloseExitSimulationFile();
   CloseDealLevelFile();
  }

double OnTester()
  {
   WriteSummaryCSV("OnTester");
   return StatExpectancyR();
  }

void OnTick()
  {
   RefreshDailyState();
   UpdateAccountDrawdownMetrics();
   UpdateSmallCapitalChallengeMetrics();
   EvaluateDrawdownPercentStopConditions();
   string smallCapitalTickReject = "";
   CheckSmallCapitalChallengeLimits(smallCapitalTickReject);
   UpdateVirtualTradeResults();
   UpdateLiveTradeExcursions();
   if(EnableTrading)
      CheckManagedPositionsHaveStops();

   datetime entryBarTime = 0;
   if(IsNewBar(EntryTF, lastEntryBarTime, entryBarTime))
     {
      UpdateVirtualTradeResultsOnClosedBar();
      UpdateExitSimulationResultsOnClosedBar();
      ProcessNewEntryBar();
     }
  }
