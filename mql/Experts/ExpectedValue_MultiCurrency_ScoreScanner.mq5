//+------------------------------------------------------------------+
//| ExpectedValue_MultiCurrency_ScoreScanner                         |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Multi-currency score scanner. Initial mode logs scores and candidate reasons without trading by default."

#include <Trade\Trade.mqh>

CTrade trade;

static const string STRATEGY_NAME = "ExpectedValue_MultiCurrency_ScoreScanner";

enum ENUM_TRADE_DIRECTION_MODE
  {
   TRADE_DIRECTION_BOTH = 0,
   TRADE_DIRECTION_LONG_ONLY = 1,
   TRADE_DIRECTION_SHORT_ONLY = 2
  };

enum ENUM_SYMBOL_RESEARCH_MODE
  {
   SYMBOL_RESEARCH_ALL = 0,
   SYMBOL_RESEARCH_XAUUSD_ONLY = 1, // Research-only diagnostic branch, not a mainline promotion filter.
   SYMBOL_RESEARCH_FX_ONLY = 2      // Research-only diagnostic branch, not a mainline promotion filter.
  };

enum ENUM_RESEARCH_STRATEGY_MODE
  {
   RESEARCH_STRATEGY_SCORE_SCANNER = 0,
   RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE = 1,
   RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_REGIME = 2,
   RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_V2_AUDIT_FILTERED = 3,
   RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_V3_ENTRY_TIMING = 4,
   RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_V4_EARLY_REVERSAL = 5,
   RESEARCH_STRATEGY_NESTED_NWAVE_NECKLINE_BREAK = 6,
   RESEARCH_STRATEGY_NESTED_NWAVE_RETEST_CONFIRMATION = 7,
   RESEARCH_STRATEGY_NESTED_NWAVE_BREAKOUT_QUALITY_ROUTER = 8,
   RESEARCH_STRATEGY_NESTED_NWAVE_CONTEXT_QUALITY_ROUTER = 9,
   RESEARCH_STRATEGY_NESTED_NWAVE_CONTEXT_QUALITY_ROUTER_V2 = 10,
   RESEARCH_STRATEGY_NESTED_NWAVE_CONTEXT_QUALITY_ROUTER_V3 = 11, // Deprecated research alias; no weekday/time edge logic.
   RESEARCH_STRATEGY_NESTED_NWAVE_STRUCTURAL_BOS = 12,
   RESEARCH_STRATEGY_NESTED_NWAVE_STRUCTURAL_BOS_V2 = 13
  };

enum ENUM_ENTRY_SELECTION_MODE
  {
   ENTRY_SELECTION_BEST_ONLY = 0,
   ENTRY_SELECTION_ALL_SCORE_PASSING = 1
  };

enum ENUM_DIAGNOSTICS_LEVEL
  {
   DIAG_OFF = 0,
   DIAG_SUMMARY_ONLY = 1,
   DIAG_ENTRY_ONLY = 2,
   DIAG_VERBOSE = 3
  };

enum ENUM_THIRD_WAVE_REGIME
  {
   REGIME_UNKNOWN = 0,
   REGIME_TREND_UP = 1,
   REGIME_TREND_DOWN = 2,
   REGIME_RANGE = 3,
   REGIME_TRANSITION = 4,
   REGIME_EXHAUSTION = 5
  };

enum ENUM_V4_REVERSAL_SIGNAL_MODE
  {
   V4_SIGNAL_ALL = 0,
   V4_SIGNAL_MICRO_BREAK_ONLY = 1,
   V4_SIGNAL_CANDLE_REVERSAL_ONLY = 2,
   V4_SIGNAL_MICRO_OR_CANDLE = 3,
   V4_SIGNAL_WITHOUT_WEAK_SIGNALS = 4
  };

enum ENUM_THIRD_WAVE_SL_MODE
  {
   THIRD_WAVE_SL_CURRENT = 0,
   THIRD_WAVE_SL_LOWER_TF_REVERSAL = 1
  };

input string          InpSymbols                       = "USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD,XAUUSD";
input int             InpScanSeconds                   = 300;
input bool            InpScanOnlyOnNewExecutionBar     = true;
input double          InpEntryScoreThreshold           = 60.0;
input ENUM_TIMEFRAMES InpContextTF                     = PERIOD_H1;
input ENUM_TIMEFRAMES InpPatternTF                     = PERIOD_M15;
input ENUM_TIMEFRAMES InpExecutionTF                   = PERIOD_M5;
input ENUM_RESEARCH_STRATEGY_MODE InpResearchStrategyMode = RESEARCH_STRATEGY_SCORE_SCANNER;
input ENUM_ENTRY_SELECTION_MODE InpEntrySelectionMode  = ENTRY_SELECTION_BEST_ONLY;
input ENUM_DIAGNOSTICS_LEVEL InpDiagnosticsLevel       = DIAG_ENTRY_ONLY;
input ENUM_V4_REVERSAL_SIGNAL_MODE InpV4ReversalSignalMode = V4_SIGNAL_ALL;
input ENUM_THIRD_WAVE_SL_MODE InpThirdWaveSLMode       = THIRD_WAVE_SL_CURRENT;
input ENUM_TRADE_DIRECTION_MODE InpTradeDirectionMode  = TRADE_DIRECTION_BOTH;
input bool            InpDisableUsdJpyShort            = false; // Research-only diagnostic switch; keep false for universal tests.
input ENUM_SYMBOL_RESEARCH_MODE InpSymbolResearchMode  = SYMBOL_RESEARCH_ALL; // Keep ALL for mainline multi-currency research.
input bool            InpUseDowFractalStructureFilter  = false;
input int             InpStructureSwingSpan            = 2;
input int             InpStructureScanBars             = 80;
input bool            InpEnableTrading                 = false;
input int             InpMaxPositions                  = 1;
input int             InpMaxSameCurrencyGroupPositions = 1;

input long            InpMagicNumber                   = 2026060101;
input int             InpFastMAPeriod                  = 20;
input int             InpSlowMAPeriod                  = 50;
input int             InpATRPeriod                     = 14;
input int             InpATRAveragePeriod              = 60;
input int             InpSlopeLookbackBars             = 5;
input int             InpSetupLookbackBars             = 20;
input double          InpPullbackATR                   = 0.35;
input double          InpMinMomentumBodyATR            = 0.22;

input double          InpRiskPerTradePercent           = 0.50;
input double          InpMaxRiskPerSymbolPercent       = 1.00;
input double          InpMaxTotalOpenRiskPercent       = 3.00;
input double          InpDailyMaxLossPercent           = 3.00;
input double          InpWeeklyMaxLossPercent          = 6.00;
input double          InpMaxDrawdownPercent            = 10.00;
input double          InpMaxSpreadATR                  = 0.20;
input double          InpStopATRMultiplier             = 1.20;
input double          InpMinSL_ATR                     = 0.60;
input double          InpMaxSL_ATR                     = 2.20;
input double          InpRewardR                       = 1.50;
input double          InpFixedLotFallback              = 0.01;
input double          InpMaxLotCap                     = 1.00;
input int             InpSlippagePoints                = 20;

input bool            InpUseCommonFiles                = false;
input string          InpLogFolder                     = "logs";
input string          InpLogPrefix                     = "multicurrency_score";

struct PivotPoint
  {
   bool              valid;
   int               shift;
   double            price;
   datetime          time;
  };

struct StructureFilterState
  {
   bool              trendUp;
   bool              trendDown;
   bool              higherHigh;
   bool              higherLow;
   bool              lowerHigh;
   bool              lowerLow;
   bool              pullbackValid;
   bool              pullbackTooDeep;
   bool              fractalConfirmed;
   bool              reclaimConfirmed;
   bool              pass;
   double            structureStopReference;
   string            failReason;
  };

struct SymbolScore
  {
   string            symbol;
   string            direction;
   double            totalScore;
   double            trendScore;
   double            setupScore;
   double            volatilityScore;
   double            costPenalty;
   double            riskPenalty;
   double            atr;
   double            spreadATR;
   double            stopDistance;
   double            stopLoss;
   double            takeProfit;
   double            volume;
   bool              dataReady;
   bool              structureEvaluated;
   StructureFilterState structureState;
   string            reason;
  };

struct ThirdWaveSetup
  {
   string            symbol;
   string            direction;
   string            higherTfTrend;
   string            midTfPullbackStatus;
   string            lowerTfReversalStatus;
   string            skipReason;
   string            structureStageFailReason;
   string            executionBlockReason;
   string            structureSlSource;
   string            regime;
   string            regimeReason;
   string            higherTfSwingState;
   string            volatilityState;
   string            blockedByRegimeReason;
   bool              dataReady;
   bool              entryAllowedByRegime;
   bool              higherTfTrendPass;
   bool              midTfPullbackPass;
   bool              lowerTfReversalPass;
   bool              structureSlPass;
   bool              rrPass;
   bool              spreadGuardPass;
   bool              spreadGuardBlocked;
   bool              setupPass;
   bool              entryPass;
   bool              finalEntryPass;
   bool              v2FilterPass;
   bool              v3FilterPass;
   bool              v3MomentumExhausted;
   double            entryPrice;
   double            stopLoss;
   double            takeProfit;
   double            midTfStructureSL;
   double            lowerTfReversalSL;
   double            midTfStructureSLATR;
   double            lowerTfReversalSLATR;
   string            lowerTfReversalSLStatus;
   double            volume;
   double            riskR;
   double            rr;
   double            swingHigh;
   double            swingLow;
   double            atr;
   double            atrValue;
   double            spreadATR;
   double            maxSpreadATR;
   double            spreadPoints;
   double            retraceRatio;
   double            qualityScore;
   double            emaSlope;
   double            trendStrength;
   double            lowerReversalQuality;
   double            pullbackDepthATR;
   double            slATR;
   double            higherSwingLow1;
   double            higherSwingHigh1;
   double            higherSwingLow2;
   double            higherSwingHigh2;
   int               higherTrendAgeBars;
   double            higherAtr;
   double            impulseStartPrice;
   double            impulseEndPrice;
   double            pullbackExtremePrice;
   double            pullbackDepthPct;
   int               pullbackBars;
   bool              pullbackBrokeOrigin;
   double            pullbackStructureLevel;
   double            distancePullbackExtremeToEntryATR;
   double            distancePullbackExtremeToEntryPct;
   double            minorReversalLevel;
   double            reclaimOrBreakdownPrice;
   int               barsSinceReclaimOrBreakdown;
   double            entryDistanceFromReclaimATR;
   double            entryDistanceFromReclaimPoints;
   string            lowerReversalQualityLabel;
   string            waveAuditLabel;
   string            waveAuditReason;
   string            v2FilterFailReason;
   string            v3FilterFailReason;
   string            reversalSignalType;
   string            v4BlockReason;
   string            v4SignalModeName;
   bool              v4SignalModePass;
   bool              v4SignalModeBlocked;
   double            v3MomentumExhaustionScore;
   double            v3RecentMoveATR;
   double            v3CloseToRecentExtremeATR;
   int               v3ConsecutiveDirectionalBars;
   int               barsSincePullbackExtreme;
   int               barsSinceReversalSignal;
   double            distanceReversalSignalToEntryATR;
   double            impulseConsumedPct;
   double            preEntryMomentumScore;
   double            reversalStrengthScore;
   bool              v4ImpulseConsumedBlocked;
  };

struct NestedNWaveSetup
  {
   string            symbol;
   string            direction;
   string            label;
   string            failReason;
   string            executionBlockReason;
   string            fibZone;
   string            h4TrendState;
   string            h1CounterTrendState;
   string            necklineBreakLabel;
   bool              dataReady;
   bool              h4ImpulsePass;
   bool              h4PullbackZonePass;
   bool              h1CounterTrendPass;
   bool              necklinePass;
   bool              structureSlPass;
   bool              rrPass;
   bool              spreadGuardPass;
   bool              spreadGuardBlocked;
   bool              setupPass;
   bool              entryPass;
   bool              finalEntryPass;
   double            h4ImpulseHigh;
   double            h4ImpulseLow;
   double            h4FibRetracementPct;
   double            h4Atr;
   double            h1Atr;
   double            m15Atr;
   double            spreadATR;
   double            spreadPoints;
   double            necklinePrice;
   double            necklineBreakClosePrice;
   double            rightSideLevel;
   double            entryPrice;
   double            stopLoss;
   double            takeProfit;
   double            volume;
   double            riskR;
   double            rr;
   double            slPoints;
   double            slATR;
   double            tpPoints;
   double            tpATR;
   double            distanceNecklineToEntry;
   double            distanceNecklineToEntryATR;
   double            distanceRightSideToEntry;
   double            distanceRightSideToEntryATR;
   int               barsSinceRightSide;
   double            qualityScore;
   bool              retestConfirmationMode;
   bool              retestDetected;
   bool              retestHeld;
   bool              retestTriggerPass;
   bool              retestFailed;
   datetime          originalNecklineBreakTime;
   datetime          retestDetectedTime;
   datetime          retestTriggerTime;
   int               retestBarsAfterBreakout;
   int               entryDelayBars;
   double            retestDepthATR;
   double            retestZoneATR;
   double            retestReclaimPrice;
   double            retestDistanceFromNecklineATR;
   bool              falseBreakReturnInsideNeckline;
   string            retestQuality;
   string            retestFailureReason;
   bool              breakoutQualityRouterMode;
   string            breakoutQualityLabel;
   string            breakoutQualityReason;
   bool              breakoutQualityPass;
   bool              breakoutStrong;
   bool              breakoutWeak;
   bool              breakoutDirty;
   double            breakoutCloseDistanceFromNeckline;
   double            breakoutCloseDistanceFromNecklineATR;
   double            breakoutCloseDistanceFromNecklinePoints;
   double            breakoutBodyRatio;
   double            breakoutBodyATR;
   double            breakoutRangeATR;
   double            breakoutDirectionalWickRatio;
   double            breakoutClosePositionDirectional;
   int               necklineTouchCount;
   bool              contextQualityRouterMode;
   string            contextQualityLabel;
   string            contextQualityReason;
   double            contextQualityScore;
   bool              contextClean;
   bool              contextMixed;
   bool              contextPoor;
   bool              structuralBosMode;
   string            structuralBosState;
   string            m15ConfirmationType;
   double            h1BosLevel;
   double            h1CounterNWaveHigh;
   double            h1CounterNWaveLow;
   double            distanceBosToEntry;
   double            distanceBosToEntryATR;
   int               barsSinceBos;
   string            h4PivotSequence;
   string            h1PivotSequence;
   double            h4ImpulseATR;
   double            h1CounterWaveATR;
   double            h4CorrectionDepth;
   double            trueBosLevel;
   string            bosLevelSourcePivot;
   double            roomTo1R;
   double            roomTo2R;
   string            roomToTargetLabel;
  };

void WriteStructureFilterRow(const string symbol, const string direction, const StructureFilterState &state);
void WriteStructureSummaryRow();
void WriteThirdWaveSummaryRow();
void WriteThirdWaveWaveAuditRow(const ThirdWaveSetup &setup, const string eventName);
void WriteNestedNWaveSummaryRow();
void WriteNestedNWaveSignalRow(const NestedNWaveSetup &setup, const string eventName);
void WriteNestedNWaveTradeRow(const NestedNWaveSetup &setup,
                              const string eventName,
                              const string resultReason,
                              const long retcode);

string   g_symbols[];
double   g_initialEquity = 0.0;
double   g_peakEquity = 0.0;
double   g_dayStartEquity = 0.0;
double   g_weekStartEquity = 0.0;
int      g_dayKey = 0;
int      g_weekKey = 0;
bool     g_dailyStopped = false;
bool     g_weeklyStopped = false;
bool     g_drawdownStopped = false;
string   g_riskStopReason = "";
datetime g_lastScanExecutionBarTime = 0;
datetime g_lastLoggedSkippedExecutionBarTime = 0;
string   g_lastEntryBarKeys[];
datetime g_lastEntryBarTimes[];
long     g_structureEvaluations = 0;
long     g_structureDetailRows = 0;
long     g_structurePassCount = 0;
long     g_structureFailCount = 0;
long     g_structureNoContextSwingsCount = 0;
long     g_structureNoTrendUpCount = 0;
long     g_structureNoTrendDownCount = 0;
long     g_structurePullbackTooDeepCount = 0;
long     g_structurePullbackNotValidCount = 0;
long     g_structureNoFractalLowCount = 0;
long     g_structureNoFractalHighCount = 0;
long     g_structureNoReclaimCount = 0;
long     g_structureUnknownFailCount = 0;
long     g_thirdWaveEvaluations = 0;
long     g_thirdWaveLongEvaluations = 0;
long     g_thirdWaveShortEvaluations = 0;
long     g_thirdWaveHigherTrendPassCount = 0;
long     g_thirdWaveMidPullbackPassCount = 0;
long     g_thirdWaveLowerReversalPassCount = 0;
long     g_thirdWaveStructureSlPassCount = 0;
long     g_thirdWaveRrPassCount = 0;
long     g_thirdWaveSpreadGuardPassCount = 0;
long     g_thirdWaveSpreadGuardBlockedCount = 0;
long     g_thirdWaveFinalEntryPassCount = 0;
long     g_thirdWaveLongHigherTrendPassCount = 0;
long     g_thirdWaveLongMidPullbackPassCount = 0;
long     g_thirdWaveLongLowerReversalPassCount = 0;
long     g_thirdWaveLongStructureSlPassCount = 0;
long     g_thirdWaveLongRrPassCount = 0;
long     g_thirdWaveLongSpreadGuardPassCount = 0;
long     g_thirdWaveLongSpreadGuardBlockedCount = 0;
long     g_thirdWaveLongFinalEntryPassCount = 0;
long     g_thirdWaveShortHigherTrendPassCount = 0;
long     g_thirdWaveShortMidPullbackPassCount = 0;
long     g_thirdWaveShortLowerReversalPassCount = 0;
long     g_thirdWaveShortStructureSlPassCount = 0;
long     g_thirdWaveShortRrPassCount = 0;
long     g_thirdWaveShortSpreadGuardPassCount = 0;
long     g_thirdWaveShortSpreadGuardBlockedCount = 0;
long     g_thirdWaveShortFinalEntryPassCount = 0;
long     g_thirdWaveSetupPassCount = 0;
long     g_thirdWaveEntryPassCount = 0;
long     g_thirdWaveOrderSentCount = 0;
long     g_thirdWaveOrderFailedCount = 0;
long     g_thirdWaveNoHigherTrendCount = 0;
long     g_thirdWaveTrendBrokenCount = 0;
long     g_thirdWaveNoMidPullbackCount = 0;
long     g_thirdWavePullbackTooShallowCount = 0;
long     g_thirdWavePullbackTooDeepCount = 0;
long     g_thirdWaveNoLowerReversalCount = 0;
long     g_thirdWaveSlTooCloseCount = 0;
long     g_thirdWaveSlTooTightCount = 0;
long     g_thirdWaveSlTooWideCount = 0;
long     g_thirdWaveInvalidStopsCount = 0;
long     g_thirdWaveRrTooLowCount = 0;
long     g_thirdWaveExistingPositionCount = 0;
long     g_thirdWaveMarketClosedCount = 0;
long     g_thirdWaveSpreadGuardCount = 0;
long     g_thirdWaveDataUnavailableCount = 0;
long     g_thirdWaveAtrUnavailableCount = 0;
long     g_thirdWaveResearchExcludedCount = 0;
long     g_thirdWaveUnknownSkipCount = 0;
long     g_thirdWaveExecutionSpreadGuardCount = 0;
long     g_thirdWaveExecutionTradingDisabledCount = 0;
long     g_thirdWaveExecutionNoEntrySignalCount = 0;
long     g_thirdWaveExecutionPositionLimitCount = 0;
long     g_thirdWaveExecutionRiskStopCount = 0;
long     g_thirdWaveExecutionRiskLimitCount = 0;
long     g_thirdWaveExecutionInvalidCount = 0;
long     g_thirdWaveExecutionOrderFailedCount = 0;
long     g_thirdWaveExecutionUnknownCount = 0;
long     g_thirdWaveRegimeTrendUpCount = 0;
long     g_thirdWaveRegimeTrendDownCount = 0;
long     g_thirdWaveRegimeRangeCount = 0;
long     g_thirdWaveRegimeTransitionCount = 0;
long     g_thirdWaveRegimeExhaustionCount = 0;
long     g_thirdWaveRegimeUnknownCount = 0;
long     g_thirdWaveRegimeAllowedCount = 0;
long     g_thirdWaveRegimeBlockedCount = 0;
long     g_thirdWaveRegimeBlockLongRequiresTrendUpCount = 0;
long     g_thirdWaveRegimeBlockShortRequiresTrendDownCount = 0;
long     g_thirdWaveLowerReversalQualityLowCount = 0;
long     g_thirdWaveV2FilterEvaluations = 0;
long     g_thirdWaveV2FilterPassCount = 0;
long     g_thirdWaveV2FilterFailCount = 0;
long     g_thirdWaveV2FilterDeepPullbackCount = 0;
long     g_thirdWaveV2FilterTrendTooOldCount = 0;
long     g_thirdWaveV2FilterReclaimChaseCount = 0;
long     g_thirdWaveV3FilterEvaluations = 0;
long     g_thirdWaveV3FilterPassCount = 0;
long     g_thirdWaveV3FilterFailCount = 0;
long     g_thirdWaveV3FilterInvalidPositionCount = 0;
long     g_thirdWaveV3FilterLateEntryCount = 0;
long     g_thirdWaveV3FilterChasingEntryCount = 0;
long     g_thirdWaveV3FilterReclaimChaseCount = 0;
long     g_thirdWaveV3FilterPullbackChaseCount = 0;
long     g_thirdWaveV3FilterMomentumExhaustedCount = 0;
long     g_thirdWaveV4ReversalEvaluations = 0;
long     g_thirdWaveV4ReversalPassCount = 0;
long     g_thirdWaveV4ReversalFailCount = 0;
long     g_thirdWaveV4ConfirmedFractalCount = 0;
long     g_thirdWaveV4EarlyHigherLowCount = 0;
long     g_thirdWaveV4EarlyLowerHighCount = 0;
long     g_thirdWaveV4MomentumTurnCount = 0;
long     g_thirdWaveV4CandleReversalCount = 0;
long     g_thirdWaveV4MicroBreakCount = 0;
long     g_thirdWaveV4UnclearCount = 0;
long     g_thirdWaveV4ImpulseConsumedBlockedCount = 0;
long     g_nestedNWaveEvaluations = 0;
long     g_nestedNWaveLongEvaluations = 0;
long     g_nestedNWaveShortEvaluations = 0;
long     g_nestedNWaveH4ImpulsePassCount = 0;
long     g_nestedNWavePullbackZonePassCount = 0;
long     g_nestedNWaveH1CounterTrendPassCount = 0;
long     g_nestedNWaveNecklinePassCount = 0;
long     g_nestedNWaveStructureSlPassCount = 0;
long     g_nestedNWaveRrPassCount = 0;
long     g_nestedNWaveSpreadGuardPassCount = 0;
long     g_nestedNWaveSpreadGuardBlockedCount = 0;
long     g_nestedNWaveFinalEntryPassCount = 0;
long     g_nestedNWaveOrderSentCount = 0;
long     g_nestedNWaveOrderFailedCount = 0;
long     g_nestedNWaveDataUnavailableCount = 0;
long     g_nestedNWaveAtrUnavailableCount = 0;
long     g_nestedNWaveResearchExcludedCount = 0;
long     g_nestedNWaveNoH4NWaveCount = 0;
long     g_nestedNWaveTooShallowPullbackCount = 0;
long     g_nestedNWaveTooDeepPullbackCount = 0;
long     g_nestedNWaveNoH1CounterTrendCount = 0;
long     g_nestedNWaveNoClearNecklineCount = 0;
long     g_nestedNWaveNoNecklineBreakCount = 0;
long     g_nestedNWaveSlTooTightCount = 0;
long     g_nestedNWaveSlTooWideCount = 0;
long     g_nestedNWaveInvalidStructureCount = 0;
long     g_nestedNWaveSpreadGuardCount = 0;
long     g_nestedNWaveExistingPositionCount = 0;
long     g_nestedNWaveExecutionBlockedCount = 0;
long     g_nestedNWaveCleanEntryCount = 0;
long     g_nestedNWaveInitialBreakCount = 0;
long     g_nestedNWaveLateBreakCount = 0;
long     g_nestedNWaveChasingBreakCount = 0;
long     g_nestedNWaveRetestDetectedCount = 0;
long     g_nestedNWaveRetestHeldCount = 0;
long     g_nestedNWaveRetestTriggerPassCount = 0;
long     g_nestedNWaveNoRetestBreakCount = 0;
long     g_nestedNWaveNoRetestDetectedCount = 0;
long     g_nestedNWaveRetestInvalidatedCount = 0;
long     g_nestedNWaveNoRetestTriggerCount = 0;
long     g_nestedNWaveStrongBreakoutCount = 0;
long     g_nestedNWaveWeakBreakoutCount = 0;
long     g_nestedNWaveDirtyBreakoutCount = 0;
long     g_nestedNWaveUnclearBreakoutCount = 0;
long     g_nestedNWaveDirtyBreakoutFailCount = 0;
long     g_nestedNWaveUnclearBreakoutFailCount = 0;
long     g_nestedNWaveWeakBreakoutWaitingRetestCount = 0;
long     g_nestedNWaveRouterRetestRequiresWeakCount = 0;
long     g_nestedNWaveUnknownFailCount = 0;

//+------------------------------------------------------------------+
//| Generic helpers                                                   |
//+------------------------------------------------------------------+
string Trim(const string value)
  {
   string result = value;
   StringTrimLeft(result);
   StringTrimRight(result);
   return result;
  }

void AppendReason(string &reason, const string token)
  {
   if(token == "")
      return;
   if(reason == "")
      reason = token;
   else
      reason += "|" + token;
  }

void AppendCsvField(string &line, const string value)
  {
   if(line != "")
      line += ",";
   line += value;
  }

void AppendCsvLong(string &line, const long value)
  {
   AppendCsvField(line, IntegerToString(value));
  }

double ClampDouble(const double value, const double low, const double high)
  {
   if(value < low)
      return low;
   if(value > high)
      return high;
   return value;
  }

double Max3(const double a, const double b, const double c)
  {
   return MathMax(a, MathMax(b, c));
  }

string DirectionToString(const int direction)
  {
   if(direction > 0)
      return "LONG";
   if(direction < 0)
      return "SHORT";
   return "NONE";
  }

string UpperSymbol(const string symbol)
  {
   string upper = symbol;
   StringToUpper(upper);
   return upper;
  }

bool IsXauSymbol(const string symbol)
  {
   return (StringFind(UpperSymbol(symbol), "XAU") >= 0);
  }

bool IsUsdJpySymbol(const string symbol)
  {
   return (StringFind(UpperSymbol(symbol), "USDJPY") == 0);
  }

string BoolText(const bool value)
  {
   return (value ? "true" : "false");
  }

bool IsThirdWaveStrategyMode()
  {
   return (InpResearchStrategyMode == RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE ||
           InpResearchStrategyMode == RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_REGIME ||
           InpResearchStrategyMode == RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_V2_AUDIT_FILTERED ||
           InpResearchStrategyMode == RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_V3_ENTRY_TIMING ||
           InpResearchStrategyMode == RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_V4_EARLY_REVERSAL);
  }

bool IsAuditFilteredThirdWaveV2Mode()
  {
   return (InpResearchStrategyMode == RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_V2_AUDIT_FILTERED);
  }

bool IsEntryTimingThirdWaveV3Mode()
  {
   return (InpResearchStrategyMode == RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_V3_ENTRY_TIMING);
  }

bool IsEarlyReversalThirdWaveV4Mode()
  {
   return (InpResearchStrategyMode == RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_V4_EARLY_REVERSAL);
  }

bool IsNestedNWaveStrategyMode()
  {
   return (InpResearchStrategyMode == RESEARCH_STRATEGY_NESTED_NWAVE_NECKLINE_BREAK ||
           InpResearchStrategyMode == RESEARCH_STRATEGY_NESTED_NWAVE_RETEST_CONFIRMATION ||
           InpResearchStrategyMode == RESEARCH_STRATEGY_NESTED_NWAVE_BREAKOUT_QUALITY_ROUTER ||
           InpResearchStrategyMode == RESEARCH_STRATEGY_NESTED_NWAVE_CONTEXT_QUALITY_ROUTER ||
           InpResearchStrategyMode == RESEARCH_STRATEGY_NESTED_NWAVE_CONTEXT_QUALITY_ROUTER_V2 ||
           InpResearchStrategyMode == RESEARCH_STRATEGY_NESTED_NWAVE_CONTEXT_QUALITY_ROUTER_V3 ||
           InpResearchStrategyMode == RESEARCH_STRATEGY_NESTED_NWAVE_STRUCTURAL_BOS ||
           InpResearchStrategyMode == RESEARCH_STRATEGY_NESTED_NWAVE_STRUCTURAL_BOS_V2);
  }

bool IsNestedNWaveRetestConfirmationMode()
  {
   return (InpResearchStrategyMode == RESEARCH_STRATEGY_NESTED_NWAVE_RETEST_CONFIRMATION);
  }

bool IsNestedNWaveBreakoutQualityRouterMode()
  {
   return (InpResearchStrategyMode == RESEARCH_STRATEGY_NESTED_NWAVE_BREAKOUT_QUALITY_ROUTER);
  }

bool IsNestedNWaveContextQualityRouterMode()
  {
   return (InpResearchStrategyMode == RESEARCH_STRATEGY_NESTED_NWAVE_CONTEXT_QUALITY_ROUTER ||
           InpResearchStrategyMode == RESEARCH_STRATEGY_NESTED_NWAVE_CONTEXT_QUALITY_ROUTER_V2 ||
           InpResearchStrategyMode == RESEARCH_STRATEGY_NESTED_NWAVE_CONTEXT_QUALITY_ROUTER_V3);
  }

bool IsNestedNWaveContextQualityRouterV2Mode()
  {
   // V3 is intentionally a deprecated compatibility alias for V2. It must not add
   // weekday, symbol, or direction-specific expectancy rules.
   return (InpResearchStrategyMode == RESEARCH_STRATEGY_NESTED_NWAVE_CONTEXT_QUALITY_ROUTER_V2 ||
           InpResearchStrategyMode == RESEARCH_STRATEGY_NESTED_NWAVE_CONTEXT_QUALITY_ROUTER_V3);
  }

bool IsNestedNWaveContextQualityRouterV3Mode()
  {
   return (InpResearchStrategyMode == RESEARCH_STRATEGY_NESTED_NWAVE_CONTEXT_QUALITY_ROUTER_V3);
  }

bool IsNestedNWaveStructuralBosMode()
  {
   return (InpResearchStrategyMode == RESEARCH_STRATEGY_NESTED_NWAVE_STRUCTURAL_BOS ||
           InpResearchStrategyMode == RESEARCH_STRATEGY_NESTED_NWAVE_STRUCTURAL_BOS_V2);
  }

bool IsNestedNWaveStructuralBosV2Mode()
  {
   return (InpResearchStrategyMode == RESEARCH_STRATEGY_NESTED_NWAVE_STRUCTURAL_BOS_V2);
  }

string V4ReversalSignalModeName()
  {
   if(InpV4ReversalSignalMode == V4_SIGNAL_MICRO_BREAK_ONLY)
      return "V4_SIGNAL_MICRO_BREAK_ONLY";
   if(InpV4ReversalSignalMode == V4_SIGNAL_CANDLE_REVERSAL_ONLY)
      return "V4_SIGNAL_CANDLE_REVERSAL_ONLY";
   if(InpV4ReversalSignalMode == V4_SIGNAL_MICRO_OR_CANDLE)
      return "V4_SIGNAL_MICRO_OR_CANDLE";
   if(InpV4ReversalSignalMode == V4_SIGNAL_WITHOUT_WEAK_SIGNALS)
      return "V4_SIGNAL_WITHOUT_WEAK_SIGNALS";
   return "V4_SIGNAL_ALL";
  }

string ThirdWaveSLModeName()
  {
   if(InpThirdWaveSLMode == THIRD_WAVE_SL_LOWER_TF_REVERSAL)
      return "THIRD_WAVE_SL_LOWER_TF_REVERSAL";
   return "THIRD_WAVE_SL_CURRENT";
  }

bool IsRegimeAwareThirdWaveMode()
  {
   return (InpResearchStrategyMode == RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_REGIME ||
           IsAuditFilteredThirdWaveV2Mode() ||
           IsEntryTimingThirdWaveV3Mode() ||
           IsEarlyReversalThirdWaveV4Mode());
  }

bool IsAllCandidatesEntryMode()
  {
   return (InpEntrySelectionMode == ENTRY_SELECTION_ALL_SCORE_PASSING);
  }

bool DiagnosticsSummaryEnabled()
  {
   return (InpDiagnosticsLevel >= DIAG_SUMMARY_ONLY);
  }

bool DiagnosticsEntryDetailEnabled()
  {
   return (InpDiagnosticsLevel >= DIAG_ENTRY_ONLY);
  }

bool DiagnosticsVerboseEnabled()
  {
   return (InpDiagnosticsLevel >= DIAG_VERBOSE);
  }

string EntrySelectionModeName()
  {
   if(IsAllCandidatesEntryMode())
      return "all_score_passing";
   return "best_only";
  }

string ThirdWaveStrategyName()
  {
   if(IsEarlyReversalThirdWaveV4Mode())
      return "DowFractal_ThirdWave_V4_EarlyReversal";
   if(IsEntryTimingThirdWaveV3Mode())
      return "DowFractal_ThirdWave_V3_EntryTiming";
   if(IsAuditFilteredThirdWaveV2Mode())
      return "DowFractal_ThirdWave_V2_AuditFiltered";
   if(IsRegimeAwareThirdWaveMode())
      return "DowFractal_ThirdWave_Regime";
   return "DowFractal_ThirdWave";
  }

string NestedNWaveStrategyName()
  {
   if(IsNestedNWaveContextQualityRouterMode())
     {
      if(IsNestedNWaveContextQualityRouterV3Mode())
         return "Nested_NWave_ContextQualityRouterV3_Deprecated_V2Alias";
      if(IsNestedNWaveContextQualityRouterV2Mode())
         return "Nested_NWave_ContextQualityRouterV2";
      return "Nested_NWave_ContextQualityRouter";
     }
   if(IsNestedNWaveBreakoutQualityRouterMode())
      return "Nested_NWave_BreakoutQualityRouter";
   if(IsNestedNWaveRetestConfirmationMode())
      return "Nested_NWave_RetestConfirmation";
   if(IsNestedNWaveStructuralBosV2Mode())
      return "Nested_NWave_StructuralBOS_V2";
   if(IsNestedNWaveStructuralBosMode())
      return "Nested_NWave_StructuralBOS";
   return "Nested_NWave_NecklineBreak";
  }

string RegimeToString(const ENUM_THIRD_WAVE_REGIME regime)
  {
   if(regime == REGIME_TREND_UP)
      return "REGIME_TREND_UP";
   if(regime == REGIME_TREND_DOWN)
      return "REGIME_TREND_DOWN";
   if(regime == REGIME_RANGE)
      return "REGIME_RANGE";
   if(regime == REGIME_TRANSITION)
      return "REGIME_TRANSITION";
   if(regime == REGIME_EXHAUSTION)
      return "REGIME_EXHAUSTION";
   return "REGIME_UNKNOWN";
  }

string ServerSessionLabel()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   if(tm.hour < 8)
      return "server_00_07";
   if(tm.hour < 16)
      return "server_08_15";
   return "server_16_23";
  }

string TimeframeText(const ENUM_TIMEFRAMES timeframe)
  {
   return EnumToString(timeframe);
  }

string WaveAuditStructureState(const ThirdWaveSetup &setup)
  {
   if(setup.higherTfSwingState == "HH_HL")
      return "HH_HL";
   if(setup.higherTfSwingState == "LL_LH")
      return "LL_LH";
   if(setup.higherTfSwingState == "")
      return "mixed";
   return setup.higherTfSwingState;
  }

void UpdateThirdWaveEntryDistanceAudit(ThirdWaveSetup &setup)
  {
   double atr = setup.atrValue;
   if(atr <= 0.0)
      atr = setup.atr;

   double impulse = MathAbs(setup.impulseEndPrice - setup.impulseStartPrice);
   if(setup.entryPrice > 0.0 && setup.pullbackExtremePrice > 0.0)
     {
      double distance = MathAbs(setup.entryPrice - setup.pullbackExtremePrice);
      setup.distancePullbackExtremeToEntryATR = (atr > 0.0 ? distance / atr : 0.0);
      setup.distancePullbackExtremeToEntryPct = (impulse > 0.0 ? distance / impulse * 100.0 : 0.0);
     }

   if(setup.entryPrice > 0.0 && setup.reclaimOrBreakdownPrice > 0.0)
     {
      double distance = MathAbs(setup.entryPrice - setup.reclaimOrBreakdownPrice);
      setup.entryDistanceFromReclaimATR = (atr > 0.0 ? distance / atr : 0.0);
      double point = SymbolInfoDouble(setup.symbol, SYMBOL_POINT);
      setup.entryDistanceFromReclaimPoints = (point > 0.0 ? distance / point : 0.0);
      setup.distanceReversalSignalToEntryATR = setup.entryDistanceFromReclaimATR;
     }
   setup.barsSinceReversalSignal = setup.barsSinceReclaimOrBreakdown;
   setup.impulseConsumedPct = setup.distancePullbackExtremeToEntryPct;
  }

string ClassifyLowerReversalQualityLabel(const ThirdWaveSetup &setup)
  {
   if(!setup.lowerTfReversalPass)
      return "unclear";
   if(setup.barsSinceReclaimOrBreakdown > 3 || setup.entryDistanceFromReclaimATR > 0.90)
      return "late";
   if(setup.entryDistanceFromReclaimATR <= 0.25 && setup.barsSinceReclaimOrBreakdown <= 1)
      return "early";
   if(setup.entryDistanceFromReclaimATR <= 0.60 && setup.barsSinceReclaimOrBreakdown <= 2)
      return "acceptable";
   return "unclear";
  }

void ClassifyThirdWaveAuditLabel(ThirdWaveSetup &setup)
  {
   UpdateThirdWaveEntryDistanceAudit(setup);
   setup.lowerReversalQualityLabel = ClassifyLowerReversalQualityLabel(setup);

   if(!setup.higherTfTrendPass || !setup.midTfPullbackPass || !setup.lowerTfReversalPass)
     {
      setup.waveAuditLabel = "invalid_structure";
      setup.waveAuditReason = "stage_not_passed";
      return;
     }

   if(setup.pullbackBrokeOrigin ||
      setup.higherTfSwingState == "mixed" ||
      setup.higherTfSwingState == "compressed" ||
      setup.higherTfSwingState == "HH_no_HL" ||
      setup.higherTfSwingState == "LL_no_LH")
     {
      setup.waveAuditLabel = "invalid_structure";
      setup.waveAuditReason = "higher_or_pullback_structure_invalid";
      return;
     }

   if(setup.regime == RegimeToString(REGIME_RANGE) ||
      setup.regime == RegimeToString(REGIME_TRANSITION) ||
      setup.regime == RegimeToString(REGIME_UNKNOWN))
     {
      setup.waveAuditLabel = "range_noise";
      setup.waveAuditReason = "regime_not_directional";
      return;
     }

   bool reclaimLate = (setup.barsSinceReclaimOrBreakdown > 2 ||
                       setup.entryDistanceFromReclaimATR > 0.60);
   bool farFromPullback = (setup.distancePullbackExtremeToEntryATR > 2.20 ||
                           setup.distancePullbackExtremeToEntryPct > 65.0);
   bool stretched = (setup.slATR > 1.80 ||
                     setup.distancePullbackExtremeToEntryATR > 3.00 ||
                     setup.entryDistanceFromReclaimATR > 0.90);

   if(stretched)
     {
      setup.waveAuditLabel = "chasing_entry";
      setup.waveAuditReason = "entry_or_sl_stretched";
      return;
     }

   if(reclaimLate || farFromPullback)
     {
      setup.waveAuditLabel = "late_entry";
      setup.waveAuditReason = "entry_far_from_reclaim_or_pullback";
      return;
     }

   bool healthyRetrace = (setup.retraceRatio >= 0.25 && setup.retraceRatio <= 0.70);
   bool closeToReclaim = (setup.entryDistanceFromReclaimATR <= 0.35 &&
                          setup.barsSinceReclaimOrBreakdown <= 1);
   bool notTooFarFromPullback = (setup.distancePullbackExtremeToEntryATR <= 1.75 &&
                                 setup.distancePullbackExtremeToEntryPct <= 50.0);
   if(healthyRetrace && closeToReclaim && notTooFarFromPullback)
     {
      setup.waveAuditLabel = "third_wave_initial";
      setup.waveAuditReason = "clean_pullback_and_near_reclaim";
      return;
     }

   if(setup.distancePullbackExtremeToEntryATR <= 2.50 &&
      setup.distancePullbackExtremeToEntryPct <= 65.0 &&
      setup.retraceRatio >= 0.18 &&
      setup.retraceRatio <= 0.80)
     {
      setup.waveAuditLabel = "third_wave_middle";
      setup.waveAuditReason = "valid_but_not_initial";
      return;
     }

   setup.waveAuditLabel = "unclear";
   setup.waveAuditReason = "mixed_audit_conditions";
  }

string DateTimeText(const datetime value)
  {
   if(value <= 0)
      return "";
   return TimeToString(value, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
  }

int DateKey(const datetime now)
  {
   MqlDateTime tm;
   TimeToStruct(now, tm);
   return tm.year * 10000 + tm.mon * 100 + tm.day;
  }

int WeekKey(const datetime now)
  {
   MqlDateTime tm;
   TimeToStruct(now, tm);
   return tm.year * 100 + (tm.day_of_year / 7);
  }

bool IsDuplicateSymbol(const string symbol)
  {
   int size = ArraySize(g_symbols);
   for(int i = 0; i < size; ++i)
      if(g_symbols[i] == symbol)
         return true;
   return false;
  }

bool ParseSymbols()
  {
   ArrayResize(g_symbols, 0);

   string parts[];
   int count = StringSplit(InpSymbols, ',', parts);
   if(count <= 0)
      return false;

   for(int i = 0; i < count; ++i)
     {
      string symbol = Trim(parts[i]);
      if(symbol == "" || IsDuplicateSymbol(symbol))
         continue;

      if(!SymbolSelect(symbol, true))
        {
         PrintFormat("%s: SymbolSelect failed for %s", STRATEGY_NAME, symbol);
         continue;
        }

      int size = ArraySize(g_symbols);
      ArrayResize(g_symbols, size + 1);
      g_symbols[size] = symbol;
     }

   return ArraySize(g_symbols) > 0;
  }

bool IsSymbolAllowedByResearchMode(const string symbol, string &reason)
  {
   reason = "";
   if(InpSymbolResearchMode == SYMBOL_RESEARCH_XAUUSD_ONLY && !IsXauSymbol(symbol))
     {
      reason = "symbol_research_xauusd_only_excluded";
      return false;
     }

   if(InpSymbolResearchMode == SYMBOL_RESEARCH_FX_ONLY && IsXauSymbol(symbol))
     {
      reason = "symbol_research_fx_only_excluded";
      return false;
     }

   return true;
  }

bool IsDirectionAllowedByResearchMode(const string symbol, const int direction, string &reason)
  {
   reason = "";
   if(direction > 0 && InpTradeDirectionMode == TRADE_DIRECTION_SHORT_ONLY)
     {
      reason = "direction_mode_short_only";
      return false;
     }

   if(direction < 0 && InpTradeDirectionMode == TRADE_DIRECTION_LONG_ONLY)
     {
      reason = "direction_mode_long_only";
      return false;
     }

   if(direction < 0 && InpDisableUsdJpyShort && IsUsdJpySymbol(symbol))
     {
      reason = "disabled_usdjpy_short";
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Market data helpers                                               |
//+------------------------------------------------------------------+
bool LoadRates(const string symbol,
               const ENUM_TIMEFRAMES timeframe,
               const int barsNeeded,
               MqlRates &rates[],
               string &reason)
  {
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(symbol, timeframe, 0, barsNeeded, rates);
   if(copied < barsNeeded)
     {
      reason = "data_insufficient_" + EnumToString(timeframe) + "_" + IntegerToString(copied);
      return false;
     }
   return true;
  }

double AverageClose(const MqlRates &rates[], const int startShift, const int period)
  {
   int size = ArraySize(rates);
   if(period <= 0 || startShift < 0 || startShift + period > size)
      return 0.0;

   double sum = 0.0;
   for(int i = startShift; i < startShift + period; ++i)
      sum += rates[i].close;
   return sum / period;
  }

double TrueRangeAt(const MqlRates &rates[], const int shift)
  {
   int size = ArraySize(rates);
   if(shift < 0 || shift + 1 >= size)
      return 0.0;

   double highLow = rates[shift].high - rates[shift].low;
   double highClose = MathAbs(rates[shift].high - rates[shift + 1].close);
   double lowClose = MathAbs(rates[shift].low - rates[shift + 1].close);
   return Max3(highLow, highClose, lowClose);
  }

double AverageATR(const MqlRates &rates[], const int startShift, const int period)
  {
   int size = ArraySize(rates);
   if(period <= 0 || startShift < 0 || startShift + period + 1 > size)
      return 0.0;

   double sum = 0.0;
   for(int i = startShift; i < startShift + period; ++i)
      sum += TrueRangeAt(rates, i);
   return sum / period;
  }

double HighestHigh(const MqlRates &rates[], const int startShift, const int bars)
  {
   int size = ArraySize(rates);
   if(bars <= 0 || startShift < 0 || startShift + bars > size)
      return 0.0;

   double value = rates[startShift].high;
   for(int i = startShift + 1; i < startShift + bars; ++i)
      value = MathMax(value, rates[i].high);
   return value;
  }

double LowestLow(const MqlRates &rates[], const int startShift, const int bars)
  {
   int size = ArraySize(rates);
   if(bars <= 0 || startShift < 0 || startShift + bars > size)
      return 0.0;

   double value = rates[startShift].low;
   for(int i = startShift + 1; i < startShift + bars; ++i)
      value = MathMin(value, rates[i].low);
   return value;
  }

double SpreadPrice(const string symbol)
  {
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
      return ask - bid;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   long spreadPoints = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   return (double)spreadPoints * point;
  }

int RequiredBars()
  {
   int need = InpSlowMAPeriod + InpSlopeLookbackBars + InpATRAveragePeriod + InpATRPeriod + 10;
   need = MathMax(need, InpSetupLookbackBars + 10);
   need = MathMax(need, InpStructureScanBars + InpStructureSwingSpan * 2 + 10);
   return MathMax(need, 90);
  }

void ResetPivot(PivotPoint &pivot)
  {
   pivot.valid = false;
   pivot.shift = -1;
   pivot.price = 0.0;
   pivot.time = 0;
  }

void SetPivot(PivotPoint &pivot, const int shift, const double price, const datetime time)
  {
   pivot.valid = true;
   pivot.shift = shift;
   pivot.price = price;
   pivot.time = time;
  }

bool IsPivotHigh(const MqlRates &rates[], const int shift, const int span)
  {
   int size = ArraySize(rates);
   if(span < 1 || shift - span < 1 || shift + span >= size)
      return false;

   double price = rates[shift].high;
   for(int offset = 1; offset <= span; ++offset)
     {
      if(rates[shift - offset].high >= price)
         return false;
      if(rates[shift + offset].high >= price)
         return false;
     }
   return true;
  }

bool IsPivotLow(const MqlRates &rates[], const int shift, const int span)
  {
   int size = ArraySize(rates);
   if(span < 1 || shift - span < 1 || shift + span >= size)
      return false;

   double price = rates[shift].low;
   for(int offset = 1; offset <= span; ++offset)
     {
      if(rates[shift - offset].low <= price)
         return false;
      if(rates[shift + offset].low <= price)
         return false;
     }
   return true;
  }

bool FindRecentPivots(const MqlRates &rates[],
                      const bool highPivot,
                      const int span,
                      const int scanBars,
                      PivotPoint &latest,
                      PivotPoint &previous)
  {
   ResetPivot(latest);
   ResetPivot(previous);

   int size = ArraySize(rates);
   int maxShift = size - span - 1;
   if(maxShift > scanBars)
      maxShift = scanBars;
   for(int shift = span + 1; shift <= maxShift; ++shift)
     {
      bool found = (highPivot ? IsPivotHigh(rates, shift, span) : IsPivotLow(rates, shift, span));
      if(!found)
         continue;

      if(!latest.valid)
        {
         SetPivot(latest, shift, (highPivot ? rates[shift].high : rates[shift].low), rates[shift].time);
         continue;
        }

      SetPivot(previous, shift, (highPivot ? rates[shift].high : rates[shift].low), rates[shift].time);
      return true;
     }

   return (latest.valid && previous.valid);
  }

bool FindRecentPivots3(const MqlRates &rates[],
                       const bool highPivot,
                       const int span,
                       const int scanBars,
                       PivotPoint &latest,
                       PivotPoint &previous,
                       PivotPoint &third)
  {
   ResetPivot(latest);
   ResetPivot(previous);
   ResetPivot(third);

   int size = ArraySize(rates);
   int maxShift = size - span - 1;
   if(maxShift > scanBars)
      maxShift = scanBars;
   for(int shift = span + 1; shift <= maxShift; ++shift)
     {
      bool found = (highPivot ? IsPivotHigh(rates, shift, span) : IsPivotLow(rates, shift, span));
      if(!found)
         continue;

      if(!latest.valid)
        {
         SetPivot(latest, shift, (highPivot ? rates[shift].high : rates[shift].low), rates[shift].time);
         continue;
        }
      if(!previous.valid)
        {
         SetPivot(previous, shift, (highPivot ? rates[shift].high : rates[shift].low), rates[shift].time);
         continue;
        }

      SetPivot(third, shift, (highPivot ? rates[shift].high : rates[shift].low), rates[shift].time);
      return true;
     }

   return (latest.valid && previous.valid && third.valid);
  }

bool FindBestPivotBetween(const MqlRates &rates[],
                          const bool highPivot,
                          const int span,
                          const int newerShift,
                          const int olderShift,
                          PivotPoint &best)
  {
   ResetPivot(best);
   if(olderShift <= newerShift + 1)
      return false;

   for(int shift = newerShift + 1; shift < olderShift; ++shift)
     {
      bool found = (highPivot ? IsPivotHigh(rates, shift, span) : IsPivotLow(rates, shift, span));
      if(!found)
         continue;

      double price = (highPivot ? rates[shift].high : rates[shift].low);
      if(!best.valid ||
         (highPivot && price > best.price) ||
         (!highPivot && price < best.price))
         SetPivot(best, shift, price, rates[shift].time);
     }

   return best.valid;
  }

string PivotTimeText(const PivotPoint &pivot)
  {
   if(!pivot.valid)
      return "";
   return TimeToString(pivot.time, TIME_DATE | TIME_MINUTES);
  }

string PivotSeq3Text(const string firstLabel,
                     const PivotPoint &first,
                     const string secondLabel,
                     const PivotPoint &second,
                     const string thirdLabel,
                     const PivotPoint &third)
  {
   if(!first.valid || !second.valid || !third.valid)
      return "";

   string text = firstLabel + "@" + PivotTimeText(first) + "=" + DoubleToString(first.price, 5);
   text += "|" + secondLabel + "@" + PivotTimeText(second) + "=" + DoubleToString(second.price, 5);
   text += "|" + thirdLabel + "@" + PivotTimeText(third) + "=" + DoubleToString(third.price, 5);
   return text;
  }

void ResetStructureFilterState(StructureFilterState &state)
  {
   state.trendUp = false;
   state.trendDown = false;
   state.higherHigh = false;
   state.higherLow = false;
   state.lowerHigh = false;
   state.lowerLow = false;
   state.pullbackValid = false;
   state.pullbackTooDeep = false;
   state.fractalConfirmed = false;
   state.reclaimConfirmed = false;
   state.pass = false;
   state.structureStopReference = 0.0;
   state.failReason = "";
  }

void InitThirdWaveSetup(ThirdWaveSetup &setup, const string symbol, const int direction)
  {
   setup.symbol = symbol;
   setup.direction = DirectionToString(direction);
   setup.higherTfTrend = "none";
   setup.midTfPullbackStatus = "not_checked";
   setup.lowerTfReversalStatus = "not_checked";
   setup.skipReason = "";
   setup.structureStageFailReason = "";
   setup.executionBlockReason = "";
   setup.structureSlSource = "";
   setup.regime = (IsRegimeAwareThirdWaveMode() ? "REGIME_UNKNOWN" : "not_used");
   setup.regimeReason = "";
   setup.higherTfSwingState = "";
   setup.volatilityState = "";
   setup.blockedByRegimeReason = "";
   setup.dataReady = false;
   setup.entryAllowedByRegime = !IsRegimeAwareThirdWaveMode();
   setup.higherTfTrendPass = false;
   setup.midTfPullbackPass = false;
   setup.lowerTfReversalPass = false;
   setup.structureSlPass = false;
   setup.rrPass = false;
   setup.spreadGuardPass = false;
   setup.spreadGuardBlocked = false;
   setup.setupPass = false;
   setup.entryPass = false;
   setup.finalEntryPass = false;
   setup.v2FilterPass = !IsAuditFilteredThirdWaveV2Mode();
   setup.v3FilterPass = !IsEntryTimingThirdWaveV3Mode();
   setup.v3MomentumExhausted = false;
   setup.entryPrice = 0.0;
   setup.stopLoss = 0.0;
   setup.takeProfit = 0.0;
   setup.midTfStructureSL = 0.0;
   setup.lowerTfReversalSL = 0.0;
   setup.midTfStructureSLATR = 0.0;
   setup.lowerTfReversalSLATR = 0.0;
   setup.lowerTfReversalSLStatus = "not_evaluated";
   setup.volume = 0.0;
   setup.riskR = 0.0;
   setup.rr = 0.0;
   setup.swingHigh = 0.0;
   setup.swingLow = 0.0;
   setup.atr = 0.0;
   setup.atrValue = 0.0;
   setup.spreadATR = 0.0;
   setup.maxSpreadATR = InpMaxSpreadATR;
   setup.spreadPoints = 0.0;
   setup.retraceRatio = 0.0;
   setup.qualityScore = 0.0;
   setup.emaSlope = 0.0;
   setup.trendStrength = 0.0;
   setup.lowerReversalQuality = 0.0;
   setup.pullbackDepthATR = 0.0;
   setup.slATR = 0.0;
   setup.higherSwingLow1 = 0.0;
   setup.higherSwingHigh1 = 0.0;
   setup.higherSwingLow2 = 0.0;
   setup.higherSwingHigh2 = 0.0;
   setup.higherTrendAgeBars = 0;
   setup.higherAtr = 0.0;
   setup.impulseStartPrice = 0.0;
   setup.impulseEndPrice = 0.0;
   setup.pullbackExtremePrice = 0.0;
   setup.pullbackDepthPct = 0.0;
   setup.pullbackBars = 0;
   setup.pullbackBrokeOrigin = false;
   setup.pullbackStructureLevel = 0.0;
   setup.distancePullbackExtremeToEntryATR = 0.0;
   setup.distancePullbackExtremeToEntryPct = 0.0;
   setup.minorReversalLevel = 0.0;
   setup.reclaimOrBreakdownPrice = 0.0;
   setup.barsSinceReclaimOrBreakdown = 0;
   setup.entryDistanceFromReclaimATR = 0.0;
   setup.entryDistanceFromReclaimPoints = 0.0;
   setup.lowerReversalQualityLabel = "unclear";
   setup.waveAuditLabel = "unclear";
   setup.waveAuditReason = "";
   setup.v2FilterFailReason = "";
   setup.v3FilterFailReason = "";
   setup.reversalSignalType = "unclear";
   setup.v4BlockReason = "";
   setup.v4SignalModeName = V4ReversalSignalModeName();
   setup.v4SignalModePass = !IsEarlyReversalThirdWaveV4Mode();
   setup.v4SignalModeBlocked = false;
   setup.v3MomentumExhaustionScore = 0.0;
   setup.v3RecentMoveATR = 0.0;
   setup.v3CloseToRecentExtremeATR = 0.0;
   setup.v3ConsecutiveDirectionalBars = 0;
   setup.barsSincePullbackExtreme = 0;
   setup.barsSinceReversalSignal = 0;
   setup.distanceReversalSignalToEntryATR = 0.0;
   setup.impulseConsumedPct = 0.0;
   setup.preEntryMomentumScore = 0.0;
   setup.reversalStrengthScore = 0.0;
   setup.v4ImpulseConsumedBlocked = false;
  }

void InitNestedNWaveSetup(NestedNWaveSetup &setup, const string symbol, const int direction)
  {
   setup.symbol = symbol;
   setup.direction = DirectionToString(direction);
   setup.label = "unclear";
   setup.failReason = "";
   setup.executionBlockReason = "";
   setup.fibZone = "unknown";
   setup.h4TrendState = "none";
   setup.h1CounterTrendState = "none";
   setup.necklineBreakLabel = "none";
   setup.dataReady = false;
   setup.h4ImpulsePass = false;
   setup.h4PullbackZonePass = false;
   setup.h1CounterTrendPass = false;
   setup.necklinePass = false;
   setup.structureSlPass = false;
   setup.rrPass = false;
   setup.spreadGuardPass = false;
   setup.spreadGuardBlocked = false;
   setup.setupPass = false;
   setup.entryPass = false;
   setup.finalEntryPass = false;
   setup.h4ImpulseHigh = 0.0;
   setup.h4ImpulseLow = 0.0;
   setup.h4FibRetracementPct = 0.0;
   setup.h4Atr = 0.0;
   setup.h1Atr = 0.0;
   setup.m15Atr = 0.0;
   setup.spreadATR = 0.0;
   setup.spreadPoints = 0.0;
   setup.necklinePrice = 0.0;
   setup.necklineBreakClosePrice = 0.0;
   setup.rightSideLevel = 0.0;
   setup.entryPrice = 0.0;
   setup.stopLoss = 0.0;
   setup.takeProfit = 0.0;
   setup.volume = 0.0;
   setup.riskR = 0.0;
   setup.rr = 0.0;
   setup.slPoints = 0.0;
   setup.slATR = 0.0;
   setup.tpPoints = 0.0;
   setup.tpATR = 0.0;
   setup.distanceNecklineToEntry = 0.0;
   setup.distanceNecklineToEntryATR = 0.0;
   setup.distanceRightSideToEntry = 0.0;
   setup.distanceRightSideToEntryATR = 0.0;
   setup.barsSinceRightSide = 0;
   setup.qualityScore = 0.0;
   setup.retestConfirmationMode = IsNestedNWaveRetestConfirmationMode();
   setup.retestDetected = false;
   setup.retestHeld = false;
   setup.retestTriggerPass = false;
   setup.retestFailed = false;
   setup.originalNecklineBreakTime = 0;
   setup.retestDetectedTime = 0;
   setup.retestTriggerTime = 0;
   setup.retestBarsAfterBreakout = 0;
   setup.entryDelayBars = 0;
   setup.retestDepthATR = 0.0;
   setup.retestZoneATR = 0.0;
   setup.retestReclaimPrice = 0.0;
   setup.retestDistanceFromNecklineATR = 0.0;
   setup.falseBreakReturnInsideNeckline = false;
   setup.retestQuality = "not_applicable";
   setup.retestFailureReason = "";
   setup.breakoutQualityRouterMode = (IsNestedNWaveBreakoutQualityRouterMode() || IsNestedNWaveContextQualityRouterMode());
   setup.breakoutQualityLabel = "unclassified";
   setup.breakoutQualityReason = "";
   setup.breakoutQualityPass = false;
   setup.breakoutStrong = false;
   setup.breakoutWeak = false;
   setup.breakoutDirty = false;
   setup.breakoutCloseDistanceFromNeckline = 0.0;
   setup.breakoutCloseDistanceFromNecklineATR = 0.0;
   setup.breakoutCloseDistanceFromNecklinePoints = 0.0;
   setup.breakoutBodyRatio = 0.0;
   setup.breakoutBodyATR = 0.0;
   setup.breakoutRangeATR = 0.0;
   setup.breakoutDirectionalWickRatio = 0.0;
   setup.breakoutClosePositionDirectional = 0.0;
   setup.necklineTouchCount = 0;
   setup.contextQualityRouterMode = IsNestedNWaveContextQualityRouterMode();
   setup.contextQualityLabel = "not_evaluated";
   setup.contextQualityReason = "";
   setup.contextQualityScore = 0.0;
   setup.contextClean = false;
   setup.contextMixed = false;
   setup.contextPoor = false;
   setup.structuralBosMode = IsNestedNWaveStructuralBosMode();
   setup.structuralBosState = "not_evaluated";
   setup.m15ConfirmationType = "not_evaluated";
   setup.h1BosLevel = 0.0;
   setup.h1CounterNWaveHigh = 0.0;
   setup.h1CounterNWaveLow = 0.0;
   setup.distanceBosToEntry = 0.0;
   setup.distanceBosToEntryATR = 0.0;
   setup.barsSinceBos = 0;
   setup.h4PivotSequence = "";
   setup.h1PivotSequence = "";
   setup.h4ImpulseATR = 0.0;
   setup.h1CounterWaveATR = 0.0;
   setup.h4CorrectionDepth = 0.0;
   setup.trueBosLevel = 0.0;
   setup.bosLevelSourcePivot = "";
   setup.roomTo1R = 0.0;
   setup.roomTo2R = 0.0;
   setup.roomToTargetLabel = "not_evaluated";
  }

//+------------------------------------------------------------------+
//| Risk and position helpers                                         |
//+------------------------------------------------------------------+
string CurrencyGroup(const string symbol)
  {
   string upper = symbol;
   StringToUpper(upper);

   if(StringFind(upper, "JPY") >= 0)
      return "JPY";
   if(StringFind(upper, "USD") >= 0)
      return "USD";
   if(StringFind(upper, "EUR") >= 0)
      return "EUR";
   if(StringFind(upper, "GBP") >= 0)
      return "GBP";
   if(StringFind(upper, "AUD") >= 0)
      return "AUD";
   if(StringFind(upper, "CAD") >= 0)
      return "CAD";
   if(StringFind(upper, "CHF") >= 0)
      return "CHF";
   if(StringFind(upper, "NZD") >= 0)
      return "NZD";

   if(StringLen(upper) >= 3)
      return StringSubstr(upper, 0, 3);
   return upper;
  }

double PositionRiskPercent()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0)
      return 0.0;

   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double stop = PositionGetDouble(POSITION_SL);
   double volume = PositionGetDouble(POSITION_VOLUME);
   string symbol = PositionGetString(POSITION_SYMBOL);
   if(stop <= 0.0 || volume <= 0.0)
      return InpRiskPerTradePercent;

   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0.0 || tickValue <= 0.0)
      return InpRiskPerTradePercent;

   double money = MathAbs(entry - stop) / tickSize * tickValue * volume;
   return money / equity * 100.0;
  }

int CountManagedPositions()
  {
   int count = 0;
   int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      count++;
     }
   return count;
  }

int CountManagedPositionsForSymbol(const string symbol)
  {
   int count = 0;
   int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      count++;
     }
   return count;
  }

int CountManagedPositionsForSymbolDirection(const string symbol, const string direction)
  {
   int count = 0;
   int total = PositionsTotal();
   ENUM_POSITION_TYPE desiredType = POSITION_TYPE_BUY;
   if(direction == "SHORT")
      desiredType = POSITION_TYPE_SELL;

   for(int i = 0; i < total; ++i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != desiredType)
         continue;
      count++;
     }
   return count;
  }

int CountManagedPositionsForGroup(const string group)
  {
   int count = 0;
   int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if(CurrencyGroup(PositionGetString(POSITION_SYMBOL)) == group)
         count++;
     }
   return count;
  }

datetime ActiveEntryBarTime()
  {
   if(g_lastScanExecutionBarTime > 0)
      return g_lastScanExecutionBarTime;

   datetime barTime = 0;
   string reason = "";
   if(LatestClosedExecutionBarTime(barTime, reason))
      return barTime;

   return TimeCurrent();
  }

string EntryBarKey(const string strategyName, const string symbol, const string direction)
  {
   return strategyName + "|" + symbol + "|" + direction;
  }

bool HasEntryOnCurrentScanBar(const string strategyName, const string symbol, const string direction)
  {
   datetime barTime = ActiveEntryBarTime();
   string key = EntryBarKey(strategyName, symbol, direction);
   int size = ArraySize(g_lastEntryBarKeys);
   for(int i = 0; i < size; ++i)
     {
      if(g_lastEntryBarKeys[i] == key && g_lastEntryBarTimes[i] == barTime)
         return true;
     }
   return false;
  }

void MarkEntryOnCurrentScanBar(const string strategyName, const string symbol, const string direction)
  {
   datetime barTime = ActiveEntryBarTime();
   string key = EntryBarKey(strategyName, symbol, direction);
   int size = ArraySize(g_lastEntryBarKeys);
   for(int i = 0; i < size; ++i)
     {
      if(g_lastEntryBarKeys[i] == key)
        {
         g_lastEntryBarTimes[i] = barTime;
         return;
        }
     }

   ArrayResize(g_lastEntryBarKeys, size + 1);
   ArrayResize(g_lastEntryBarTimes, size + 1);
   g_lastEntryBarKeys[size] = key;
   g_lastEntryBarTimes[size] = barTime;
  }

double CurrentTotalOpenRiskPercent()
  {
   double risk = 0.0;
   int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      risk += PositionRiskPercent();
     }
   return risk;
  }

double CurrentSymbolOpenRiskPercent(const string symbol)
  {
   double risk = 0.0;
   int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      risk += PositionRiskPercent();
     }
   return risk;
  }

void UpdateRiskAnchors()
  {
   datetime now = TimeCurrent();
   int dayKey = DateKey(now);
   int weekKey = WeekKey(now);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(g_dayKey != dayKey)
     {
      g_dayKey = dayKey;
      g_dayStartEquity = equity;
      g_dailyStopped = false;
     }

   if(g_weekKey != weekKey)
     {
      g_weekKey = weekKey;
      g_weekStartEquity = equity;
      g_weeklyStopped = false;
     }

   if(equity > g_peakEquity)
      g_peakEquity = equity;
  }

bool IsHardRiskStopped(string &reason)
  {
   reason = "";
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(g_dayStartEquity > 0.0)
     {
      double dailyLoss = (g_dayStartEquity - equity) / g_dayStartEquity * 100.0;
      if(dailyLoss >= InpDailyMaxLossPercent)
        {
         g_dailyStopped = true;
         g_riskStopReason = "daily_loss_stop";
        }
     }

   if(g_weekStartEquity > 0.0)
     {
      double weeklyLoss = (g_weekStartEquity - equity) / g_weekStartEquity * 100.0;
      if(weeklyLoss >= InpWeeklyMaxLossPercent)
        {
         g_weeklyStopped = true;
         g_riskStopReason = "weekly_loss_stop";
        }
     }

   if(g_peakEquity > 0.0)
     {
      double drawdown = (g_peakEquity - equity) / g_peakEquity * 100.0;
      if(drawdown >= InpMaxDrawdownPercent)
        {
         g_drawdownStopped = true;
         g_riskStopReason = "max_drawdown_stop";
        }
     }

   if(g_dailyStopped || g_weeklyStopped || g_drawdownStopped)
     {
      reason = g_riskStopReason;
      return true;
     }

   return false;
  }

double RiskPenalty(const string symbol, string &reason)
  {
   double penalty = 0.0;
   string stopReason = "";
   if(IsHardRiskStopped(stopReason))
     {
      AppendReason(reason, stopReason);
      penalty += 100.0;
     }

   int openPositions = CountManagedPositions();
   if(InpMaxPositions > 0 && openPositions >= InpMaxPositions)
     {
      AppendReason(reason, "max_positions_reached");
      penalty += 60.0;
     }
   else if(openPositions > 0)
      penalty += openPositions * 4.0;

   int symbolPositions = CountManagedPositionsForSymbol(symbol);
   if(symbolPositions > 0)
     {
      AppendReason(reason, "symbol_already_open");
      penalty += 25.0;
     }

   string group = CurrencyGroup(symbol);
   int groupPositions = CountManagedPositionsForGroup(group);
   if(InpMaxSameCurrencyGroupPositions > 0 && groupPositions >= InpMaxSameCurrencyGroupPositions)
     {
      AppendReason(reason, "currency_group_limit_" + group);
      penalty += 35.0;
     }
   else if(groupPositions > 0)
      penalty += groupPositions * 6.0;

   double totalRisk = CurrentTotalOpenRiskPercent();
   if(totalRisk >= InpMaxTotalOpenRiskPercent)
     {
      AppendReason(reason, "total_open_risk_limit");
      penalty += 60.0;
     }

   double symbolRisk = CurrentSymbolOpenRiskPercent(symbol);
   if(symbolRisk >= InpMaxRiskPerSymbolPercent)
     {
      AppendReason(reason, "symbol_open_risk_limit");
      penalty += 50.0;
     }

   return penalty;
  }

double NormalizeVolume(const string symbol, const double rawVolume)
  {
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   if(minLot <= 0.0)
      minLot = InpFixedLotFallback;
   if(maxLot <= 0.0)
      maxLot = MathMax(InpMaxLotCap, minLot);
   if(step <= 0.0)
      step = minLot;

   double volume = ClampDouble(rawVolume, minLot, MathMin(maxLot, InpMaxLotCap));
   volume = MathFloor(volume / step) * step;
   if(volume < minLot)
      volume = minLot;

   int digits = 2;
   if(step < 0.1)
      digits = 3;
   if(step < 0.01)
      digits = 4;

   return NormalizeDouble(volume, digits);
  }

double CalculatePositionSize(const string symbol, const double stopDistance)
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);

   if(equity <= 0.0 || stopDistance <= 0.0 || tickSize <= 0.0 || tickValue <= 0.0)
      return NormalizeVolume(symbol, InpFixedLotFallback);

   double riskMoney = equity * InpRiskPerTradePercent / 100.0;
   double riskPerLot = stopDistance / tickSize * tickValue;
   if(riskMoney <= 0.0 || riskPerLot <= 0.0)
      return NormalizeVolume(symbol, InpFixedLotFallback);

   return NormalizeVolume(symbol, riskMoney / riskPerLot);
  }

//+------------------------------------------------------------------+
//| Dow/fractal third wave research branch                           |
//+------------------------------------------------------------------+
string ThirdWaveSwingState(const bool higherHigh,
                            const bool higherLow,
                            const bool lowerHigh,
                            const bool lowerLow)
  {
   if(higherHigh && higherLow)
      return "HH_HL";
   if(lowerHigh && lowerLow)
      return "LL_LH";
   if(higherHigh && !higherLow)
      return "HH_no_HL";
   if(lowerLow && !lowerHigh)
      return "LL_no_LH";
   if(higherLow && lowerHigh)
      return "compressed";
   return "mixed";
  }

void ClassifyThirdWaveRegime(const MqlRates &contextRates[],
                             ThirdWaveSetup &setup)
  {
   setup.regime = RegimeToString(REGIME_UNKNOWN);
   setup.regimeReason = "not_enough_context";
   setup.higherTfSwingState = "unknown";
   setup.volatilityState = "unknown";
   setup.entryAllowedByRegime = false;
   setup.blockedByRegimeReason = "";

   int span = InpStructureSwingSpan;
   if(span < 1)
      span = 1;

   int scanBars = InpStructureScanBars;
   if(scanBars < span * 4 + 10)
      scanBars = span * 4 + 10;

   PivotPoint highLatest;
   PivotPoint highPrevious;
   PivotPoint lowLatest;
   PivotPoint lowPrevious;
   bool hasHighs = FindRecentPivots(contextRates, true, span, scanBars, highLatest, highPrevious);
   bool hasLows = FindRecentPivots(contextRates, false, span, scanBars, lowLatest, lowPrevious);

   double fast = AverageClose(contextRates, 1, InpFastMAPeriod);
   double slow = AverageClose(contextRates, 1, InpSlowMAPeriod);
   double slowPast = AverageClose(contextRates, 1 + InpSlopeLookbackBars, InpSlowMAPeriod);
   double contextATR = AverageATR(contextRates, 1, InpATRPeriod);
   double averageATR = AverageATR(contextRates, 1, InpATRAveragePeriod);

   setup.emaSlope = slow - slowPast;
   setup.trendStrength = (contextATR > 0.0 ? MathAbs(setup.emaSlope) / contextATR : 0.0);

   double atrRatio = (averageATR > 0.0 ? contextATR / averageATR : 0.0);
   if(atrRatio > 0.0 && atrRatio < 0.75)
      setup.volatilityState = "low";
   else if(atrRatio > 1.35)
      setup.volatilityState = "high";
   else if(atrRatio > 0.0)
      setup.volatilityState = "normal";

   if(!hasHighs || !hasLows || contextATR <= 0.0 || fast <= 0.0 || slow <= 0.0 || slowPast <= 0.0)
     {
      setup.regime = RegimeToString(REGIME_UNKNOWN);
      setup.regimeReason = "insufficient_swings_or_indicators";
      return;
     }

   bool higherHigh = (highLatest.price > highPrevious.price);
   bool higherLow = (lowLatest.price > lowPrevious.price);
   bool lowerHigh = (highLatest.price < highPrevious.price);
   bool lowerLow = (lowLatest.price < lowPrevious.price);
   setup.higherTfSwingState = ThirdWaveSwingState(higherHigh, higherLow, lowerHigh, lowerLow);

   int rangeBars = MathMin(scanBars, 48);
   double rangeHigh = HighestHigh(contextRates, 1, rangeBars);
   double rangeLow = LowestLow(contextRates, 1, rangeBars);
   double rangeATR = (contextATR > 0.0 ? (rangeHigh - rangeLow) / contextATR : 0.0);
   double upSwingMomentum = (highLatest.price - highPrevious.price) / contextATR;
   double downSwingMomentum = (lowPrevious.price - lowLatest.price) / contextATR;
   double emaDistanceATR = MathAbs(contextRates[1].close - slow) / contextATR;

   bool emaUp = (fast > slow && setup.emaSlope > 0.0);
   bool emaDown = (fast < slow && setup.emaSlope < 0.0);
   bool structureUp = (higherHigh && higherLow);
   bool structureDown = (lowerHigh && lowerLow);
   bool mixedStructure = (!structureUp && !structureDown);
   bool lowVolatilityRange = (rangeATR > 0.0 && rangeATR < 2.20 && setup.trendStrength < 0.08);
   bool weakMixedRange = (mixedStructure && setup.trendStrength < 0.12);
   bool upExhaustion = (structureUp && emaUp && emaDistanceATR > 2.50 &&
                        contextRates[1].close < contextRates[2].close &&
                        contextRates[2].close < contextRates[3].close);
   bool downExhaustion = (structureDown && emaDown && emaDistanceATR > 2.50 &&
                          contextRates[1].close > contextRates[2].close &&
                          contextRates[2].close > contextRates[3].close);

   if(upExhaustion || downExhaustion)
     {
      setup.regime = RegimeToString(REGIME_EXHAUSTION);
      setup.regimeReason = StringFormat("exhaustion swing=%s strength=%.3f range_atr=%.2f vol=%s",
                                        setup.higherTfSwingState,
                                        setup.trendStrength,
                                        rangeATR,
                                        setup.volatilityState);
      return;
     }

   if(structureUp && emaUp && atrRatio >= 0.65 && upSwingMomentum > 0.10)
     {
      setup.regime = RegimeToString(REGIME_TREND_UP);
      setup.regimeReason = StringFormat("trend_up swing=%s strength=%.3f range_atr=%.2f vol=%s",
                                        setup.higherTfSwingState,
                                        setup.trendStrength,
                                        rangeATR,
                                        setup.volatilityState);
      return;
     }

   if(structureDown && emaDown && atrRatio >= 0.65 && downSwingMomentum > 0.10)
     {
      setup.regime = RegimeToString(REGIME_TREND_DOWN);
      setup.regimeReason = StringFormat("trend_down swing=%s strength=%.3f range_atr=%.2f vol=%s",
                                        setup.higherTfSwingState,
                                        setup.trendStrength,
                                        rangeATR,
                                        setup.volatilityState);
      return;
     }

   if(lowVolatilityRange || weakMixedRange)
     {
      setup.regime = RegimeToString(REGIME_RANGE);
      setup.regimeReason = StringFormat("range swing=%s strength=%.3f range_atr=%.2f vol=%s",
                                        setup.higherTfSwingState,
                                        setup.trendStrength,
                                        rangeATR,
                                        setup.volatilityState);
      return;
     }

   setup.regime = RegimeToString(REGIME_TRANSITION);
   setup.regimeReason = StringFormat("transition swing=%s strength=%.3f range_atr=%.2f vol=%s",
                                     setup.higherTfSwingState,
                                     setup.trendStrength,
                                     rangeATR,
                                     setup.volatilityState);
  }

bool ApplyThirdWaveRegimeGate(const int direction,
                              ThirdWaveSetup &setup)
  {
   if(!IsRegimeAwareThirdWaveMode())
      return true;

   setup.entryAllowedByRegime = false;
   setup.blockedByRegimeReason = "";
   if(direction > 0 && setup.regime != RegimeToString(REGIME_TREND_UP))
     {
      setup.blockedByRegimeReason = "regime_requires_trend_up";
      setup.skipReason = setup.blockedByRegimeReason;
      setup.structureStageFailReason = setup.blockedByRegimeReason;
      return false;
     }

   if(direction < 0 && setup.regime != RegimeToString(REGIME_TREND_DOWN))
     {
      setup.blockedByRegimeReason = "regime_requires_trend_down";
      setup.skipReason = setup.blockedByRegimeReason;
      setup.structureStageFailReason = setup.blockedByRegimeReason;
      return false;
     }

   setup.entryAllowedByRegime = true;
   return true;
  }

bool DetectHigherTimeframeDowTrend(const MqlRates &contextRates[],
                                    const int direction,
                                    ThirdWaveSetup &setup)
  {
   int span = InpStructureSwingSpan;
   if(span < 1)
      span = 1;

   int scanBars = InpStructureScanBars;
   if(scanBars < span * 4 + 10)
      scanBars = span * 4 + 10;

   PivotPoint highLatest;
   PivotPoint highPrevious;
   PivotPoint lowLatest;
   PivotPoint lowPrevious;
   bool hasHighs = FindRecentPivots(contextRates, true, span, scanBars, highLatest, highPrevious);
   bool hasLows = FindRecentPivots(contextRates, false, span, scanBars, lowLatest, lowPrevious);

   if(!hasHighs || !hasLows)
     {
      setup.skipReason = "no_higher_tf_trend";
      setup.higherTfTrend = "none";
      return false;
     }

   bool higherHigh = (highLatest.price > highPrevious.price);
   bool higherLow = (lowLatest.price > lowPrevious.price);
   bool lowerHigh = (highLatest.price < highPrevious.price);
   bool lowerLow = (lowLatest.price < lowPrevious.price);

   setup.higherSwingHigh1 = highLatest.price;
   setup.higherSwingHigh2 = highPrevious.price;
   setup.higherSwingLow1 = lowLatest.price;
   setup.higherSwingLow2 = lowPrevious.price;
   setup.higherTrendAgeBars = MathMax(highLatest.shift, lowLatest.shift);
   setup.higherAtr = AverageATR(contextRates, 1, InpATRPeriod);
   setup.higherTfSwingState = ThirdWaveSwingState(higherHigh, higherLow, lowerHigh, lowerLow);
   setup.swingHigh = highLatest.price;
   setup.swingLow = lowLatest.price;

   if(direction > 0)
     {
      setup.higherTfTrend = (higherHigh && higherLow ? "up" : "none");
      if(!(higherHigh && higherLow))
        {
         setup.skipReason = "no_higher_tf_trend";
         return false;
        }
      if(contextRates[1].close <= lowLatest.price)
        {
         setup.skipReason = "trend_broken";
         return false;
        }
      return true;
     }

   setup.higherTfTrend = (lowerHigh && lowerLow ? "down" : "none");
   if(!(lowerHigh && lowerLow))
     {
      setup.skipReason = "no_higher_tf_trend";
      return false;
     }
   if(contextRates[1].close >= highLatest.price)
     {
      setup.skipReason = "trend_broken";
      return false;
     }
   return true;
  }

bool DetectMidTimeframePullback(const MqlRates &patternRates[],
                                const int direction,
                                ThirdWaveSetup &setup)
  {
   int span = InpStructureSwingSpan;
   if(span < 1)
      span = 1;

   int scanBars = InpStructureScanBars;
   if(scanBars < span * 4 + 10)
      scanBars = span * 4 + 10;

   PivotPoint highLatest;
   PivotPoint highPrevious;
   PivotPoint lowLatest;
   PivotPoint lowPrevious;
   bool hasHighs = FindRecentPivots(patternRates, true, span, scanBars, highLatest, highPrevious);
   bool hasLows = FindRecentPivots(patternRates, false, span, scanBars, lowLatest, lowPrevious);

   double trendRange = MathAbs(setup.swingHigh - setup.swingLow);
   if(trendRange <= 0.0)
     {
      setup.skipReason = "no_mid_pullback";
      setup.midTfPullbackStatus = "no_range";
      return false;
     }

   if(direction > 0)
     {
      if(!hasLows)
        {
         setup.skipReason = "no_mid_pullback";
         setup.midTfPullbackStatus = "no_fractal_low";
         return false;
        }

      double impulseStart = setup.swingLow;
      double impulseEnd = setup.swingHigh;
      setup.retraceRatio = (setup.swingHigh - lowLatest.price) / trendRange;
      setup.pullbackDepthATR = (setup.atr > 0.0 ? MathAbs(setup.swingHigh - lowLatest.price) / setup.atr : 0.0);
      setup.pullbackDepthPct = setup.retraceRatio * 100.0;
      setup.impulseStartPrice = impulseStart;
      setup.impulseEndPrice = impulseEnd;
      setup.pullbackExtremePrice = lowLatest.price;
      setup.pullbackBars = lowLatest.shift;
      setup.pullbackBrokeOrigin = (lowLatest.price <= impulseStart);
      setup.pullbackStructureLevel = lowLatest.price;
      if(lowLatest.price <= setup.swingLow || setup.retraceRatio > 0.90)
        {
         setup.skipReason = "pullback_too_deep";
         setup.midTfPullbackStatus = "too_deep";
         setup.swingLow = lowLatest.price;
         return false;
        }
      if(setup.retraceRatio < 0.18)
        {
         setup.skipReason = "pullback_too_shallow";
         setup.midTfPullbackStatus = "too_shallow";
         setup.swingLow = lowLatest.price;
         return false;
        }

      setup.midTfPullbackStatus = "valid_higher_low";
      setup.swingLow = lowLatest.price;
      if(hasHighs)
         setup.swingHigh = MathMax(setup.swingHigh, highLatest.price);
      setup.structureSlSource = "mid_fractal_low";
      return true;
     }

   if(!hasHighs)
     {
      setup.skipReason = "no_mid_pullback";
      setup.midTfPullbackStatus = "no_fractal_high";
      return false;
     }

   double impulseStart = setup.swingHigh;
   double impulseEnd = setup.swingLow;
   setup.retraceRatio = (highLatest.price - setup.swingLow) / trendRange;
   setup.pullbackDepthATR = (setup.atr > 0.0 ? MathAbs(highLatest.price - setup.swingLow) / setup.atr : 0.0);
   setup.pullbackDepthPct = setup.retraceRatio * 100.0;
   setup.impulseStartPrice = impulseStart;
   setup.impulseEndPrice = impulseEnd;
   setup.pullbackExtremePrice = highLatest.price;
   setup.pullbackBars = highLatest.shift;
   setup.pullbackBrokeOrigin = (highLatest.price >= impulseStart);
   setup.pullbackStructureLevel = highLatest.price;
   if(highLatest.price >= setup.swingHigh || setup.retraceRatio > 0.90)
     {
      setup.skipReason = "pullback_too_deep";
      setup.midTfPullbackStatus = "too_deep";
      setup.swingHigh = highLatest.price;
      return false;
     }
   if(setup.retraceRatio < 0.18)
     {
      setup.skipReason = "pullback_too_shallow";
      setup.midTfPullbackStatus = "too_shallow";
      setup.swingHigh = highLatest.price;
      return false;
     }

   setup.midTfPullbackStatus = "valid_lower_high";
   setup.swingHigh = highLatest.price;
   if(hasLows)
      setup.swingLow = MathMin(setup.swingLow, lowLatest.price);
   setup.structureSlSource = "mid_fractal_high";
   return true;
  }

bool DetectLowerTimeframeReversal(const MqlRates &executionRates[],
                                  const int direction,
                                  ThirdWaveSetup &setup)
  {
   int span = InpStructureSwingSpan;
   if(span < 1)
      span = 1;

   int scanBars = MathMin(InpStructureScanBars, 48);
   if(scanBars < span * 4 + 10)
      scanBars = span * 4 + 10;

   PivotPoint highLatest;
   PivotPoint highPrevious;
   PivotPoint lowLatest;
   PivotPoint lowPrevious;
   bool hasHighs = FindRecentPivots(executionRates, true, span, scanBars, highLatest, highPrevious);
   bool hasLows = FindRecentPivots(executionRates, false, span, scanBars, lowLatest, lowPrevious);

   if(direction > 0)
     {
      if(!hasHighs)
        {
         setup.skipReason = "no_lower_reversal";
         setup.lowerTfReversalStatus = "no_minor_high";
         return false;
        }
      bool bullishBreak = (executionRates[1].close > highLatest.price &&
                           executionRates[1].close > executionRates[1].open);
      setup.minorReversalLevel = highLatest.price;
      setup.reclaimOrBreakdownPrice = executionRates[1].close;
      setup.barsSinceReclaimOrBreakdown = 1;
      if(!bullishBreak)
        {
         setup.skipReason = "no_lower_reversal";
         setup.lowerTfReversalStatus = "minor_high_not_reclaimed";
         return false;
        }

      setup.lowerReversalQuality = 100.0;
      if(IsRegimeAwareThirdWaveMode())
        {
         double barRange = executionRates[1].high - executionRates[1].low;
         double closeLocation = (barRange > 0.0 ? (executionRates[1].close - executionRates[1].low) / barRange : 0.5);
         bool pullbackLowHeld = (setup.swingLow <= 0.0 ||
                                 (executionRates[1].low > setup.swingLow &&
                                  executionRates[2].low > setup.swingLow));
         bool noImmediateStall = (closeLocation >= 0.55 &&
                                  executionRates[1].close >= executionRates[2].close);
         bool minorHigherLow = (!hasLows ||
                                !lowPrevious.valid ||
                                lowLatest.price >= lowPrevious.price ||
                                executionRates[1].low > lowLatest.price);
         double quality = 35.0;
         if(pullbackLowHeld)
            quality += 25.0;
         if(noImmediateStall)
            quality += 25.0;
         if(minorHigherLow)
            quality += 15.0;
         setup.lowerReversalQuality = quality;
         if(quality < 75.0)
           {
            setup.skipReason = "lower_reversal_quality_low";
            setup.lowerTfReversalStatus = "minor_high_reclaimed_quality_low";
            return false;
           }
        }

      setup.lowerTfReversalStatus = (IsRegimeAwareThirdWaveMode() ? "minor_high_reclaimed_quality_ok" : "minor_high_reclaimed");
      setup.qualityScore = 100.0 + setup.retraceRatio * 20.0 - setup.spreadATR * 10.0;
      if(IsRegimeAwareThirdWaveMode())
         setup.qualityScore += setup.lowerReversalQuality * 0.10;
      return true;
     }

   if(!hasLows)
     {
      setup.skipReason = "no_lower_reversal";
      setup.lowerTfReversalStatus = "no_minor_low";
      return false;
     }
   bool bearishBreak = (executionRates[1].close < lowLatest.price &&
                        executionRates[1].close < executionRates[1].open);
   setup.minorReversalLevel = lowLatest.price;
   setup.reclaimOrBreakdownPrice = executionRates[1].close;
   setup.barsSinceReclaimOrBreakdown = 1;
   if(!bearishBreak)
     {
      setup.skipReason = "no_lower_reversal";
      setup.lowerTfReversalStatus = "minor_low_not_broken";
      return false;
     }

   setup.lowerReversalQuality = 100.0;
   if(IsRegimeAwareThirdWaveMode())
     {
      double barRange = executionRates[1].high - executionRates[1].low;
      double closeLocation = (barRange > 0.0 ? (executionRates[1].close - executionRates[1].low) / barRange : 0.5);
      bool pullbackHighHeld = (setup.swingHigh <= 0.0 ||
                               (executionRates[1].high < setup.swingHigh &&
                                executionRates[2].high < setup.swingHigh));
      bool noImmediateReturn = (closeLocation <= 0.45 &&
                                executionRates[1].close <= executionRates[2].close);
      bool minorLowerHigh = (!hasHighs ||
                             !highPrevious.valid ||
                             highLatest.price <= highPrevious.price ||
                             executionRates[1].high < highLatest.price);
      double quality = 35.0;
      if(pullbackHighHeld)
         quality += 25.0;
      if(noImmediateReturn)
         quality += 25.0;
      if(minorLowerHigh)
         quality += 15.0;
      setup.lowerReversalQuality = quality;
      if(quality < 75.0)
        {
         setup.skipReason = "lower_reversal_quality_low";
         setup.lowerTfReversalStatus = "minor_low_broken_quality_low";
         return false;
        }
     }

   setup.lowerTfReversalStatus = (IsRegimeAwareThirdWaveMode() ? "minor_low_broken_quality_ok" : "minor_low_broken");
   setup.qualityScore = 100.0 + setup.retraceRatio * 20.0 - setup.spreadATR * 10.0;
   if(IsRegimeAwareThirdWaveMode())
      setup.qualityScore += setup.lowerReversalQuality * 0.10;
   return true;
  }

int RecentExecutionExtremeShift(const MqlRates &rates[],
                                const bool highExtreme,
                                const int lookback)
  {
   int size = ArraySize(rates);
   int maxShift = MathMin(size - 1, lookback);
   if(maxShift < 1)
      return 0;

   int bestShift = 1;
   double bestValue = (highExtreme ? rates[1].high : rates[1].low);
   for(int shift = 2; shift <= maxShift; ++shift)
     {
      double value = (highExtreme ? rates[shift].high : rates[shift].low);
      if((highExtreme && value > bestValue) ||
         (!highExtreme && value < bestValue))
        {
         bestValue = value;
         bestShift = shift;
        }
     }
   return bestShift;
  }

int CountDirectionalCandles(const MqlRates &rates[],
                            const int direction,
                            const int startShift,
                            const int maxBars)
  {
   int size = ArraySize(rates);
   int count = 0;
   for(int shift = startShift; shift < startShift + maxBars && shift < size; ++shift)
     {
      bool directional = (direction > 0 ?
                          rates[shift].close > rates[shift].open :
                          rates[shift].close < rates[shift].open);
      if(!directional)
         break;
      ++count;
     }
   return count;
  }

void UpdateThirdWaveV4EntryMomentumAudit(const MqlRates &executionRates[],
                                         const int direction,
                                         ThirdWaveSetup &setup)
  {
   setup.preEntryMomentumScore = 0.0;
   double atr = setup.atrValue;
   if(atr <= 0.0)
      atr = setup.atr;
   if(atr <= 0.0 || ArraySize(executionRates) < 8)
      return;

   int entryDirectionCandles = CountDirectionalCandles(executionRates, direction, 1, 4);
   double recentMove = (direction > 0 ?
                        executionRates[1].close - executionRates[4].close :
                        executionRates[4].close - executionRates[1].close);
   double recentMoveATR = (recentMove > 0.0 ? recentMove / atr : 0.0);

   int extremeShift = RecentExecutionExtremeShift(executionRates, direction > 0, 8);
   double recentExtreme = (direction > 0 ? executionRates[extremeShift].high : executionRates[extremeShift].low);
   double distanceToExtreme = MathAbs(executionRates[1].close - recentExtreme) / atr;

   setup.preEntryMomentumScore = entryDirectionCandles * 18.0;
   if(recentMoveATR > 0.90)
      setup.preEntryMomentumScore += 28.0;
   if(recentMoveATR > 1.40)
      setup.preEntryMomentumScore += 18.0;
   if(distanceToExtreme <= 0.25)
      setup.preEntryMomentumScore += 18.0;
  }

bool DetectEarlyLowerTimeframeReversal(const MqlRates &executionRates[],
                                       const int direction,
                                       ThirdWaveSetup &setup)
  {
   int size = ArraySize(executionRates);
   if(size < 12)
     {
      setup.skipReason = "no_lower_reversal";
      setup.lowerTfReversalStatus = "early_data_insufficient";
      setup.reversalSignalType = "unclear";
      return false;
     }

   double atr = setup.atrValue;
   if(atr <= 0.0)
      atr = setup.atr;
   if(atr <= 0.0)
     {
      setup.skipReason = "atr_unavailable";
      setup.lowerTfReversalStatus = "early_atr_unavailable";
      setup.reversalSignalType = "unclear";
      return false;
     }

   int span = InpStructureSwingSpan;
   if(span < 1)
      span = 1;

   int scanBars = MathMin(InpStructureScanBars, 48);
   if(scanBars < span * 4 + 10)
      scanBars = span * 4 + 10;

   PivotPoint highLatest;
   PivotPoint highPrevious;
   PivotPoint lowLatest;
   PivotPoint lowPrevious;
   bool hasHighs = FindRecentPivots(executionRates, true, span, scanBars, highLatest, highPrevious);
   bool hasLows = FindRecentPivots(executionRates, false, span, scanBars, lowLatest, lowPrevious);

   setup.barsSincePullbackExtreme = RecentExecutionExtremeShift(executionRates, direction < 0, 24);
   setup.barsSinceReclaimOrBreakdown = 1;
   setup.barsSinceReversalSignal = 1;
   setup.reversalSignalType = "unclear";
   setup.reversalStrengthScore = 0.0;
   UpdateThirdWaveV4EntryMomentumAudit(executionRates, direction, setup);

   double barRange = executionRates[1].high - executionRates[1].low;
   double body = MathAbs(executionRates[1].close - executionRates[1].open);
   double bodyATR = body / atr;
   double closeLocation = (barRange > 0.0 ? (executionRates[1].close - executionRates[1].low) / barRange : 0.5);

   if(direction > 0)
     {
      double microHigh = HighestHigh(executionRates, 2, 3);
      bool pullbackLowHeld = (setup.swingLow <= 0.0 ||
                              (executionRates[1].low > setup.swingLow &&
                               executionRates[2].low > setup.swingLow));
      bool confirmedFractal = (hasHighs &&
                               executionRates[1].close > highLatest.price &&
                               executionRates[1].close > executionRates[1].open);
      bool microBreak = (microHigh > 0.0 &&
                         executionRates[1].close > microHigh &&
                         executionRates[1].close > executionRates[1].open);
      bool strongBull = (executionRates[1].close > executionRates[1].open &&
                         (bodyATR >= 0.28 || closeLocation >= 0.68));
      bool bullishEngulf = (executionRates[2].close < executionRates[2].open &&
                            executionRates[1].close > executionRates[2].open &&
                            executionRates[1].open <= executionRates[2].close);
      int bearishStreak = CountDirectionalCandles(executionRates, -1, 2, 4);
      bool candleReversal = (bullishEngulf || (bearishStreak >= 2 && strongBull));
      bool earlyHigherLow = (executionRates[1].low > executionRates[2].low &&
                             executionRates[2].low <= executionRates[3].low &&
                             pullbackLowHeld);
      bool momentumTurn = (executionRates[1].close > executionRates[2].close &&
                           executionRates[2].close <= executionRates[3].close &&
                           executionRates[1].close > executionRates[1].open &&
                           pullbackLowHeld);

      double strength = 20.0;
      if(pullbackLowHeld)
         strength += 15.0;
      if(earlyHigherLow)
         strength += 25.0;
      if(microBreak)
         strength += 25.0;
      if(candleReversal)
         strength += 20.0;
      if(momentumTurn)
         strength += 15.0;
      if(confirmedFractal)
         strength += 15.0;
      if(setup.preEntryMomentumScore >= 85.0)
         strength -= 15.0;

      if(earlyHigherLow && (microBreak || candleReversal || momentumTurn))
         setup.reversalSignalType = "early_higher_low";
      else if(candleReversal && (microBreak || momentumTurn))
         setup.reversalSignalType = "candle_reversal";
      else if(microBreak && strongBull)
         setup.reversalSignalType = "micro_break";
      else if(momentumTurn && strongBull)
         setup.reversalSignalType = "momentum_turn";
      else if(confirmedFractal)
         setup.reversalSignalType = "confirmed_fractal_reclaim";

      setup.reversalStrengthScore = strength;
      if(setup.reversalSignalType == "unclear" || strength < 60.0)
        {
         setup.skipReason = "no_lower_reversal";
         setup.lowerTfReversalStatus = "early_reversal_not_confirmed";
         return false;
        }

      setup.minorReversalLevel = (setup.reversalSignalType == "confirmed_fractal_reclaim" ? highLatest.price : microHigh);
      if(setup.minorReversalLevel <= 0.0)
         setup.minorReversalLevel = executionRates[1].close;
      setup.reclaimOrBreakdownPrice = setup.minorReversalLevel;
      setup.lowerTfReversalStatus = setup.reversalSignalType;
      setup.lowerReversalQuality = setup.reversalStrengthScore;
      setup.qualityScore = 100.0 + setup.retraceRatio * 20.0 - setup.spreadATR * 10.0 + setup.reversalStrengthScore * 0.10;
      return true;
     }

   double microLow = LowestLow(executionRates, 2, 3);
   bool pullbackHighHeld = (setup.swingHigh <= 0.0 ||
                            (executionRates[1].high < setup.swingHigh &&
                             executionRates[2].high < setup.swingHigh));
   bool confirmedBreakdown = (hasLows &&
                              executionRates[1].close < lowLatest.price &&
                              executionRates[1].close < executionRates[1].open);
   bool microBreak = (microLow > 0.0 &&
                      executionRates[1].close < microLow &&
                      executionRates[1].close < executionRates[1].open);
   bool strongBear = (executionRates[1].close < executionRates[1].open &&
                      (bodyATR >= 0.28 || closeLocation <= 0.32));
   bool bearishEngulf = (executionRates[2].close > executionRates[2].open &&
                         executionRates[1].close < executionRates[2].open &&
                         executionRates[1].open >= executionRates[2].close);
   int bullishStreak = CountDirectionalCandles(executionRates, 1, 2, 4);
   bool candleReversal = (bearishEngulf || (bullishStreak >= 2 && strongBear));
   bool earlyLowerHigh = (executionRates[1].high < executionRates[2].high &&
                          executionRates[2].high >= executionRates[3].high &&
                          pullbackHighHeld);
   bool momentumTurn = (executionRates[1].close < executionRates[2].close &&
                        executionRates[2].close >= executionRates[3].close &&
                        executionRates[1].close < executionRates[1].open &&
                        pullbackHighHeld);

   double strength = 20.0;
   if(pullbackHighHeld)
      strength += 15.0;
   if(earlyLowerHigh)
      strength += 25.0;
   if(microBreak)
      strength += 25.0;
   if(candleReversal)
      strength += 20.0;
   if(momentumTurn)
      strength += 15.0;
   if(confirmedBreakdown)
      strength += 15.0;
   if(setup.preEntryMomentumScore >= 85.0)
      strength -= 15.0;

   if(earlyLowerHigh && (microBreak || candleReversal || momentumTurn))
      setup.reversalSignalType = "early_lower_high";
   else if(candleReversal && (microBreak || momentumTurn))
      setup.reversalSignalType = "candle_reversal";
   else if(microBreak && strongBear)
      setup.reversalSignalType = "micro_break";
   else if(momentumTurn && strongBear)
      setup.reversalSignalType = "momentum_turn";
   else if(confirmedBreakdown)
      setup.reversalSignalType = "confirmed_fractal_breakdown";

   setup.reversalStrengthScore = strength;
   if(setup.reversalSignalType == "unclear" || strength < 60.0)
     {
      setup.skipReason = "no_lower_reversal";
      setup.lowerTfReversalStatus = "early_reversal_not_confirmed";
      return false;
     }

   setup.minorReversalLevel = (setup.reversalSignalType == "confirmed_fractal_breakdown" ? lowLatest.price : microLow);
   if(setup.minorReversalLevel <= 0.0)
      setup.minorReversalLevel = executionRates[1].close;
   setup.reclaimOrBreakdownPrice = setup.minorReversalLevel;
   setup.lowerTfReversalStatus = setup.reversalSignalType;
   setup.lowerReversalQuality = setup.reversalStrengthScore;
   setup.qualityScore = 100.0 + setup.retraceRatio * 20.0 - setup.spreadATR * 10.0 + setup.reversalStrengthScore * 0.10;
   return true;
  }

void SetThirdWaveV4Block(ThirdWaveSetup &setup, const string reason)
  {
   setup.v4BlockReason = reason;
   setup.v4ImpulseConsumedBlocked = true;
   setup.skipReason = reason;
   setup.structureStageFailReason = reason;
  }

bool ApplyThirdWaveV4ImpulseGate(ThirdWaveSetup &setup)
  {
   if(!IsEarlyReversalThirdWaveV4Mode())
      return true;

   setup.v4BlockReason = "";
   setup.v4ImpulseConsumedBlocked = false;
   if(setup.distancePullbackExtremeToEntryPct > 90.0 ||
      setup.distancePullbackExtremeToEntryATR > 4.00 ||
      setup.preEntryMomentumScore >= 95.0)
     {
      SetThirdWaveV4Block(setup, "v4_impulse_consumed");
      return false;
     }
   return true;
  }

bool IsWeakV4ReversalSignal(const string signal)
  {
   if(signal == "early_higher_low" ||
      signal == "momentum_turn")
      return true;
   if(StringFind(signal, "confirmed_fractal") == 0)
      return true;
   return false;
  }

bool V4ReversalSignalAllowedByMode(const string signal)
  {
   if(!IsEarlyReversalThirdWaveV4Mode())
      return true;

   if(InpV4ReversalSignalMode == V4_SIGNAL_MICRO_BREAK_ONLY)
      return (signal == "micro_break");
   if(InpV4ReversalSignalMode == V4_SIGNAL_CANDLE_REVERSAL_ONLY)
      return (signal == "candle_reversal");
   if(InpV4ReversalSignalMode == V4_SIGNAL_MICRO_OR_CANDLE)
      return (signal == "micro_break" || signal == "candle_reversal");
   if(InpV4ReversalSignalMode == V4_SIGNAL_WITHOUT_WEAK_SIGNALS)
      return !IsWeakV4ReversalSignal(signal);
   return true;
  }

bool ApplyThirdWaveV4SignalModeFilter(ThirdWaveSetup &setup)
  {
   if(!IsEarlyReversalThirdWaveV4Mode())
      return true;

   setup.v4SignalModeName = V4ReversalSignalModeName();
   setup.v4SignalModePass = V4ReversalSignalAllowedByMode(setup.reversalSignalType);
   setup.v4SignalModeBlocked = !setup.v4SignalModePass;
   if(setup.v4SignalModePass)
      return true;

   setup.v4BlockReason = "v4_signal_mode_blocked";
   setup.skipReason = setup.v4BlockReason;
   setup.structureStageFailReason = setup.v4BlockReason;
   return false;
  }

void CalculateThirdWaveShadowStopLevels(const string symbol,
                                        const int direction,
                                        const MqlRates &executionRates[],
                                        ThirdWaveSetup &setup)
  {
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double spread = SpreadPrice(symbol);
   double buffer = MathMax(spread, setup.atr * 0.05);
   buffer = MathMax(buffer, point * 5.0);

   setup.midTfStructureSL = setup.stopLoss;
   setup.midTfStructureSLATR = setup.slATR;
   setup.lowerTfReversalSL = 0.0;
   setup.lowerTfReversalSLATR = 0.0;
   setup.lowerTfReversalSLStatus = "not_available";

   if(setup.entryPrice <= 0.0 || setup.atrValue <= 0.0 || ArraySize(executionRates) < 8)
      return;

   int lookback = setup.barsSincePullbackExtreme + 1;
   if(lookback < 4)
      lookback = 4;
   if(lookback > 16)
      lookback = 16;

   double reference = 0.0;
   if(direction > 0)
     {
      reference = LowestLow(executionRates, 1, lookback);
      setup.lowerTfReversalSL = NormalizeDouble(reference - buffer, digits);
      setup.lowerTfReversalSLATR = (setup.entryPrice - setup.lowerTfReversalSL) / setup.atrValue;
     }
   else
     {
      reference = HighestHigh(executionRates, 1, lookback);
      setup.lowerTfReversalSL = NormalizeDouble(reference + buffer, digits);
      setup.lowerTfReversalSLATR = (setup.lowerTfReversalSL - setup.entryPrice) / setup.atrValue;
     }

   double risk = MathAbs(setup.entryPrice - setup.lowerTfReversalSL);
   if(reference <= 0.0 || setup.lowerTfReversalSL <= 0.0 || risk <= 0.0)
     {
      setup.lowerTfReversalSLStatus = "invalid_stops";
      return;
     }

   double brokerStop = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point + spread;
   double minDistance = MathMax(brokerStop, setup.atr * InpMinSL_ATR);
   double maxDistance = setup.atr * InpMaxSL_ATR;
   if(risk <= brokerStop)
      setup.lowerTfReversalSLStatus = "invalid_stops";
   else if(risk <= minDistance)
      setup.lowerTfReversalSLStatus = "sl_too_tight";
   else if(maxDistance > 0.0 && risk > maxDistance)
      setup.lowerTfReversalSLStatus = "sl_too_wide";
   else
      setup.lowerTfReversalSLStatus = "valid";
  }

bool ApplyThirdWaveActualStopMode(const string symbol,
                                  ThirdWaveSetup &setup)
  {
   if(InpThirdWaveSLMode == THIRD_WAVE_SL_CURRENT)
      return true;

   if(InpThirdWaveSLMode != THIRD_WAVE_SL_LOWER_TF_REVERSAL)
      return true;

   if(setup.lowerTfReversalSLStatus != "valid")
     {
      setup.skipReason = (setup.lowerTfReversalSLStatus == "" ? "invalid_stops" : setup.lowerTfReversalSLStatus);
      return false;
     }

   double risk = MathAbs(setup.entryPrice - setup.lowerTfReversalSL);
   if(risk <= 0.0)
     {
      setup.skipReason = "invalid_stops";
      return false;
     }

   setup.stopLoss = setup.lowerTfReversalSL;
   setup.riskR = risk;
   setup.slATR = (setup.atrValue > 0.0 ? setup.riskR / setup.atrValue : 0.0);
   setup.structureSlSource = "lower_tf_reversal";
   setup.volume = CalculatePositionSize(symbol, setup.riskR);
   if(setup.volume <= 0.0)
     {
      setup.skipReason = "sl_too_tight";
      return false;
     }

   return true;
  }

bool CalculateStructureStopLoss(const string symbol,
                                const int direction,
                                ThirdWaveSetup &setup)
  {
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      point = 0.0;

   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double spread = SpreadPrice(symbol);
   double buffer = MathMax(spread, setup.atr * 0.05);
   buffer = MathMax(buffer, point * 5.0);

   setup.entryPrice = (direction > 0 ? ask : bid);
   if(setup.entryPrice <= 0.0)
     {
      setup.skipReason = "market_closed";
      return false;
     }

   if(direction > 0)
     {
      setup.stopLoss = NormalizeDouble(setup.swingLow - buffer, digits);
      setup.riskR = setup.entryPrice - setup.stopLoss;
     }
   else
     {
      setup.stopLoss = NormalizeDouble(setup.swingHigh + buffer, digits);
      setup.riskR = setup.stopLoss - setup.entryPrice;
     }
   setup.structureSlSource = "mid_tf_structure";
   setup.slATR = (setup.atrValue > 0.0 ? setup.riskR / setup.atrValue : 0.0);

   double brokerStop = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point + spread;
   double minDistance = MathMax(brokerStop, setup.atr * InpMinSL_ATR);
   double maxDistance = setup.atr * InpMaxSL_ATR;

   if(setup.riskR <= minDistance)
     {
      setup.skipReason = "sl_too_close";
      return false;
     }
   if(maxDistance > 0.0 && setup.riskR > maxDistance)
     {
      setup.skipReason = "sl_too_wide";
      return false;
     }

   setup.volume = CalculatePositionSize(symbol, setup.riskR);
   if(setup.volume <= 0.0)
     {
      setup.skipReason = "sl_too_close";
      return false;
     }

   return true;
  }

bool CalculateThirdWaveTakeProfit(const string symbol,
                                  const int direction,
                                  ThirdWaveSetup &setup)
  {
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   setup.rr = InpRewardR;
   if(setup.rr < 1.0)
     {
      setup.skipReason = "rr_too_low";
      return false;
     }

   if(direction > 0)
      setup.takeProfit = NormalizeDouble(setup.entryPrice + setup.riskR * setup.rr, digits);
   else
      setup.takeProfit = NormalizeDouble(setup.entryPrice - setup.riskR * setup.rr, digits);

   if(setup.takeProfit <= 0.0)
     {
      setup.skipReason = "rr_too_low";
      return false;
     }
   return true;
  }

string NestedFibZoneLabel(const double retracementPct)
  {
   if(retracementPct < 38.2)
      return "too_shallow_pullback";
   if(retracementPct <= 61.8)
      return "valid_h4_pullback_zone";
   return "too_deep_pullback";
  }

bool PivotRangeHigh(const MqlRates &rates[],
                    const int newerShift,
                    const int olderShift,
                    double &value)
  {
   value = 0.0;
   if(olderShift <= newerShift + 1)
      return false;
   int start = newerShift + 1;
   int bars = olderShift - newerShift - 1;
   value = HighestHigh(rates, start, bars);
   return (value > 0.0);
  }

bool PivotRangeLow(const MqlRates &rates[],
                   const int newerShift,
                   const int olderShift,
                   double &value)
  {
   value = 0.0;
   if(olderShift <= newerShift + 1)
      return false;
   int start = newerShift + 1;
   int bars = olderShift - newerShift - 1;
   value = LowestLow(rates, start, bars);
   return (value > 0.0);
  }

bool DetectNestedH4ImpulseAndPullback(const MqlRates &h4Rates[],
                                      const int direction,
                                      NestedNWaveSetup &setup)
  {
   int span = InpStructureSwingSpan;
   if(span < 1)
      span = 1;
   int scanBars = InpStructureScanBars;
   if(scanBars < span * 4 + 10)
      scanBars = span * 4 + 10;

   PivotPoint highLatest;
   PivotPoint highPrevious;
   PivotPoint lowLatest;
   PivotPoint lowPrevious;
   bool hasHighs = FindRecentPivots(h4Rates, true, span, scanBars, highLatest, highPrevious);
   bool hasLows = FindRecentPivots(h4Rates, false, span, scanBars, lowLatest, lowPrevious);
   if(!hasHighs || !hasLows)
     {
      setup.failReason = "invalid_structure";
      return false;
     }

   double currentClose = h4Rates[1].close;
   double impulseRange = 0.0;
   if(direction > 0)
     {
      bool higherHigh = (highLatest.price > highPrevious.price);
      bool higherLow = (lowLatest.price > lowPrevious.price);
      if(!higherHigh || !higherLow)
        {
         setup.failReason = "no_h4_nwave";
         setup.h4TrendState = "no_bullish_nwave";
         return false;
        }

      double impulseLow = (lowLatest.shift > highLatest.shift ? lowLatest.price : lowPrevious.price);
      double impulseHigh = highLatest.price;
      impulseRange = impulseHigh - impulseLow;
      if(impulseRange <= 0.0 || currentClose <= impulseLow)
        {
         setup.failReason = "invalid_structure";
         setup.h4TrendState = "bullish_nwave_broken";
         return false;
        }

      setup.h4TrendState = "bullish_nwave";
      setup.h4ImpulseLow = impulseLow;
      setup.h4ImpulseHigh = impulseHigh;
      setup.h4FibRetracementPct = (impulseHigh - currentClose) / impulseRange * 100.0;
     }
   else
     {
      bool lowerHigh = (highLatest.price < highPrevious.price);
      bool lowerLow = (lowLatest.price < lowPrevious.price);
      if(!lowerHigh || !lowerLow)
        {
         setup.failReason = "no_h4_nwave";
         setup.h4TrendState = "no_bearish_nwave";
         return false;
        }

      double impulseHigh = (highLatest.shift > lowLatest.shift ? highLatest.price : highPrevious.price);
      double impulseLow = lowLatest.price;
      impulseRange = impulseHigh - impulseLow;
      if(impulseRange <= 0.0 || currentClose >= impulseHigh)
        {
         setup.failReason = "invalid_structure";
         setup.h4TrendState = "bearish_nwave_broken";
         return false;
        }

      setup.h4TrendState = "bearish_nwave";
      setup.h4ImpulseLow = impulseLow;
      setup.h4ImpulseHigh = impulseHigh;
      setup.h4FibRetracementPct = (currentClose - impulseLow) / impulseRange * 100.0;
     }

   setup.h4ImpulsePass = true;
   setup.fibZone = NestedFibZoneLabel(setup.h4FibRetracementPct);
   if(setup.fibZone == "too_shallow_pullback")
     {
      setup.failReason = "too_shallow_pullback";
      return false;
     }
   if(setup.fibZone == "too_deep_pullback")
     {
      setup.failReason = "too_deep_pullback";
      return false;
     }

   setup.h4PullbackZonePass = true;
   setup.label = "valid_h4_pullback_zone";
   return true;
  }

bool DetectNestedH1CounterTrendNWave(const MqlRates &h1Rates[],
                                     const int direction,
                                     NestedNWaveSetup &setup)
  {
   int span = InpStructureSwingSpan;
   if(span < 1)
      span = 1;
   int scanBars = InpStructureScanBars;
   if(scanBars < span * 4 + 10)
      scanBars = span * 4 + 10;

   PivotPoint highLatest;
   PivotPoint highPrevious;
   PivotPoint lowLatest;
   PivotPoint lowPrevious;
   bool hasHighs = FindRecentPivots(h1Rates, true, span, scanBars, highLatest, highPrevious);
   bool hasLows = FindRecentPivots(h1Rates, false, span, scanBars, lowLatest, lowPrevious);
   if(!hasHighs || !hasLows)
     {
      setup.failReason = "no_h1_counter_trend_nwave";
      setup.h1CounterTrendState = "missing_swings";
      return false;
     }

   if(direction > 0)
     {
      bool counterDown = (highLatest.price < highPrevious.price && lowLatest.price < lowPrevious.price);
      if(!counterDown)
        {
         setup.failReason = "no_h1_counter_trend_nwave";
         setup.h1CounterTrendState = "no_bearish_counter_nwave";
         return false;
        }
      setup.h1CounterTrendState = "bearish_counter_nwave";
     }
   else
     {
      bool counterUp = (highLatest.price > highPrevious.price && lowLatest.price > lowPrevious.price);
      if(!counterUp)
        {
         setup.failReason = "no_h1_counter_trend_nwave";
         setup.h1CounterTrendState = "no_bullish_counter_nwave";
         return false;
        }
      setup.h1CounterTrendState = "bullish_counter_nwave";
     }

   setup.h1CounterTrendPass = true;
   setup.label = "h1_counter_trend_nwave";
   return true;
  }

bool DetectNestedStructuralBosConfirmation(const MqlRates &h1Rates[],
                                           const MqlRates &m15Rates[],
                                           const int direction,
                                           NestedNWaveSetup &setup)
  {
   int span = InpStructureSwingSpan;
   if(span < 1)
      span = 1;
   int scanBars = InpStructureScanBars;
   if(scanBars < span * 4 + 10)
      scanBars = span * 4 + 10;

   PivotPoint h1HighLatest;
   PivotPoint h1HighPrevious;
   PivotPoint h1LowLatest;
   PivotPoint h1LowPrevious;
   bool hasH1Highs = FindRecentPivots(h1Rates, true, span, scanBars, h1HighLatest, h1HighPrevious);
   bool hasH1Lows = FindRecentPivots(h1Rates, false, span, scanBars, h1LowLatest, h1LowPrevious);
   if(!hasH1Highs || !hasH1Lows)
     {
      setup.failReason = "no_h1_counter_trend_nwave";
      setup.structuralBosState = "missing_h1_swings";
      return false;
     }

   PivotPoint m15HighLatest;
   PivotPoint m15HighPrevious;
   PivotPoint m15LowLatest;
   PivotPoint m15LowPrevious;
   bool hasM15Highs = FindRecentPivots(m15Rates, true, span, scanBars, m15HighLatest, m15HighPrevious);
   bool hasM15Lows = FindRecentPivots(m15Rates, false, span, scanBars, m15LowLatest, m15LowPrevious);
   if(!hasM15Highs || !hasM15Lows)
     {
      setup.failReason = "no_clear_neckline";
      setup.structuralBosState = "missing_m15_swings";
      return false;
     }

   double entryPrice = (direction > 0 ? SymbolInfoDouble(setup.symbol, SYMBOL_ASK) : SymbolInfoDouble(setup.symbol, SYMBOL_BID));
   if(entryPrice <= 0.0)
     {
      setup.failReason = "market_closed";
      setup.executionBlockReason = "market_closed";
      return false;
     }
   setup.entryPrice = entryPrice;

   double bosLevel = 0.0;
   double invalidationLevel = 0.0;
   bool h1BosConfirmed = false;
   bool m15BosConfirmed = false;
   int barsSinceBos = 0;
   int size = ArraySize(m15Rates);
   int maxBosLookback = MathMin(12, size - 2);

   if(direction > 0)
     {
      if(!(h1HighLatest.price < h1HighPrevious.price && h1LowLatest.price < h1LowPrevious.price))
        {
         setup.failReason = "h1_counter_nwave_weak";
         setup.structuralBosState = "h1_down_counter_nwave_weak";
         return false;
        }

      bosLevel = h1HighLatest.price;
      invalidationLevel = (m15LowLatest.valid && m15LowLatest.price < entryPrice ? m15LowLatest.price : h1LowLatest.price);
      h1BosConfirmed = (h1Rates[1].close > bosLevel);
      m15BosConfirmed = (m15Rates[1].close > bosLevel);
      for(int shift = 1; shift <= maxBosLookback; ++shift)
        {
         if(m15Rates[shift].close > bosLevel && m15Rates[shift + 1].close <= bosLevel)
           {
            barsSinceBos = shift;
            break;
           }
        }
     }
   else
     {
      if(!(h1HighLatest.price > h1HighPrevious.price && h1LowLatest.price > h1LowPrevious.price))
        {
         setup.failReason = "h1_counter_nwave_weak";
         setup.structuralBosState = "h1_up_counter_nwave_weak";
         return false;
        }

      bosLevel = h1LowLatest.price;
      invalidationLevel = (m15HighLatest.valid && m15HighLatest.price > entryPrice ? m15HighLatest.price : h1HighLatest.price);
      h1BosConfirmed = (h1Rates[1].close < bosLevel);
      m15BosConfirmed = (m15Rates[1].close < bosLevel);
      for(int shift = 1; shift <= maxBosLookback; ++shift)
        {
         if(m15Rates[shift].close < bosLevel && m15Rates[shift + 1].close >= bosLevel)
           {
            barsSinceBos = shift;
            break;
           }
        }
     }

   setup.h1BosLevel = bosLevel;
   setup.h1CounterNWaveHigh = MathMax(h1HighLatest.price, h1HighPrevious.price);
   setup.h1CounterNWaveLow = MathMin(h1LowLatest.price, h1LowPrevious.price);
   setup.necklinePrice = bosLevel;
   setup.necklineBreakClosePrice = m15Rates[1].close;
   setup.rightSideLevel = invalidationLevel;
   setup.barsSinceBos = barsSinceBos;
   setup.barsSinceRightSide = (direction > 0 ? m15LowLatest.shift : m15HighLatest.shift);
   setup.distanceBosToEntry = MathAbs(entryPrice - bosLevel);
   setup.distanceBosToEntryATR = (setup.m15Atr > 0.0 ? setup.distanceBosToEntry / setup.m15Atr : 0.0);
   setup.distanceNecklineToEntry = setup.distanceBosToEntry;
   setup.distanceNecklineToEntryATR = setup.distanceBosToEntryATR;
   setup.distanceRightSideToEntry = MathAbs(entryPrice - invalidationLevel);
   setup.distanceRightSideToEntryATR = (setup.m15Atr > 0.0 ? setup.distanceRightSideToEntry / setup.m15Atr : 0.0);

   if(!h1BosConfirmed && !m15BosConfirmed)
     {
      setup.failReason = "no_h1_bos";
      setup.structuralBosState = "h1_countertrend_not_invalidated";
      setup.label = "h1_counter_nwave_valid";
      return false;
     }

   if(!m15BosConfirmed)
     {
      setup.failReason = "no_m15_bos";
      setup.structuralBosState = "h1_bos_without_m15_confirmation";
      setup.label = "h1_bos_confirmed";
      return false;
     }

   setup.necklinePass = true;
   setup.structuralBosState = (h1BosConfirmed ? "h1_bos_confirmed" : "m15_countertrend_bos_confirmed");
   setup.m15ConfirmationType = "m15_bos_confirmed";
   if(barsSinceBos > 1)
     {
      double retestExtreme = (direction > 0 ? LowestLow(m15Rates, 1, barsSinceBos) : HighestHigh(m15Rates, 1, barsSinceBos));
      bool retested = (direction > 0 ? retestExtreme <= bosLevel + setup.m15Atr * 0.25
                                      : retestExtreme >= bosLevel - setup.m15Atr * 0.25);
      if(retested)
         setup.m15ConfirmationType = "m15_retest_reclaim";
     }

   UpdateNestedBreakoutQualityMetrics(m15Rates, (barsSinceBos > 0 ? barsSinceBos : 1), direction, setup);
   ClassifyNestedBreakoutQuality(setup);

   if(setup.distanceBosToEntryATR > 1.80 || setup.distanceRightSideToEntryATR > 3.20)
      setup.label = "chasing_entry";
   else if(setup.distanceBosToEntryATR > 1.20 || barsSinceBos > 8)
      setup.label = "late_entry";
   else if(setup.h4FibRetracementPct >= 47.0 && setup.h4FibRetracementPct <= 53.0 &&
           setup.breakoutClosePositionDirectional < 0.45)
      setup.label = "h4_range_middle_noise";
   else
      setup.label = "clean_structural_bos";

   setup.necklineBreakLabel = setup.label;
   setup.qualityScore = 135.0;
   if(setup.label == "clean_structural_bos")
      setup.qualityScore += 20.0;
   else if(setup.label == "m15_retest_reclaim")
      setup.qualityScore += 10.0;
   else if(setup.label == "late_entry")
      setup.qualityScore -= 25.0;
   else if(setup.label == "chasing_entry")
      setup.qualityScore -= 45.0;
   else if(setup.label == "h4_range_middle_noise")
      setup.qualityScore -= 20.0;

   setup.qualityScore -= MathAbs(setup.h4FibRetracementPct - 50.0) * 0.45;
   setup.qualityScore -= setup.distanceBosToEntryATR * 14.0;
   setup.qualityScore -= MathMax(0, barsSinceBos - 3) * 3.0;
   return true;
  }

bool DetectNestedStructuralBosV2H4Sequence(const MqlRates &h4Rates[],
                                           const int direction,
                                           NestedNWaveSetup &setup)
  {
   int span = InpStructureSwingSpan;
   if(span < 1)
      span = 1;
   int scanBars = InpStructureScanBars;
   if(scanBars < span * 5 + 12)
      scanBars = span * 5 + 12;

   PivotPoint highLatest;
   PivotPoint highPrevious;
   PivotPoint highThird;
   PivotPoint lowLatest;
   PivotPoint lowPrevious;
   PivotPoint lowThird;
   bool hasHighs = FindRecentPivots3(h4Rates, true, span, scanBars, highLatest, highPrevious, highThird);
   bool hasLows = FindRecentPivots3(h4Rates, false, span, scanBars, lowLatest, lowPrevious, lowThird);
   if(!hasHighs || !hasLows)
     {
      setup.failReason = "h4_sequence_range_noise";
      setup.h4TrendState = "h4_sequence_range_noise";
      setup.structuralBosState = "h4_sequence_range_noise";
      return false;
     }

   double currentClose = h4Rates[1].close;
   double impulseRange = 0.0;

   if(direction > 0)
     {
      PivotPoint pivotA = lowPrevious;
      PivotPoint pivotC = lowLatest;
      PivotPoint pivotB;
      if(!FindBestPivotBetween(h4Rates, true, span, pivotC.shift, pivotA.shift, pivotB))
        {
         setup.failReason = "h4_sequence_range_noise";
         setup.h4TrendState = "missing_h4_impulse_high";
         setup.structuralBosState = "h4_sequence_range_noise";
         return false;
        }

      if(pivotC.price <= pivotA.price || currentClose <= pivotA.price)
        {
         setup.failReason = "h4_correction_invalid";
         setup.h4TrendState = "bullish_sequence_broken";
         setup.structuralBosState = "h4_correction_invalid";
         return false;
        }

      impulseRange = pivotB.price - pivotA.price;
      if(impulseRange <= 0.0)
        {
         setup.failReason = "h4_sequence_range_noise";
         setup.structuralBosState = "h4_sequence_range_noise";
         return false;
        }
      setup.h4PivotSequence = PivotSeq3Text("A_low", pivotA, "B_high", pivotB, "C_low", pivotC);
      setup.h4ImpulseLow = pivotA.price;
      setup.h4ImpulseHigh = pivotB.price;
      setup.h4FibRetracementPct = (pivotB.price - currentClose) / impulseRange * 100.0;
      setup.h4TrendState = "h4_sequence_valid_bullish";
     }
   else
     {
      PivotPoint pivotA = highPrevious;
      PivotPoint pivotC = highLatest;
      PivotPoint pivotB;
      if(!FindBestPivotBetween(h4Rates, false, span, pivotC.shift, pivotA.shift, pivotB))
        {
         setup.failReason = "h4_sequence_range_noise";
         setup.h4TrendState = "missing_h4_impulse_low";
         setup.structuralBosState = "h4_sequence_range_noise";
         return false;
        }

      if(pivotC.price >= pivotA.price || currentClose >= pivotA.price)
        {
         setup.failReason = "h4_correction_invalid";
         setup.h4TrendState = "bearish_sequence_broken";
         setup.structuralBosState = "h4_correction_invalid";
         return false;
        }

      impulseRange = pivotA.price - pivotB.price;
      if(impulseRange <= 0.0)
        {
         setup.failReason = "h4_sequence_range_noise";
         setup.structuralBosState = "h4_sequence_range_noise";
         return false;
        }
      setup.h4PivotSequence = PivotSeq3Text("A_high", pivotA, "B_low", pivotB, "C_high", pivotC);
      setup.h4ImpulseLow = pivotB.price;
      setup.h4ImpulseHigh = pivotA.price;
      setup.h4FibRetracementPct = (currentClose - pivotB.price) / impulseRange * 100.0;
      setup.h4TrendState = "h4_sequence_valid_bearish";
     }

   if(impulseRange <= 0.0)
     {
      setup.failReason = "h4_sequence_range_noise";
      setup.structuralBosState = "h4_sequence_range_noise";
      return false;
     }

   setup.h4ImpulseATR = (setup.h4Atr > 0.0 ? impulseRange / setup.h4Atr : 0.0);
   if(setup.h4ImpulseATR < 1.50)
     {
      setup.failReason = "h4_impulse_too_small";
      setup.label = "h4_impulse_too_small";
      setup.structuralBosState = "h4_impulse_too_small";
      return false;
     }

   setup.h4ImpulsePass = true;
   setup.h4CorrectionDepth = setup.h4FibRetracementPct;
   setup.fibZone = NestedFibZoneLabel(setup.h4FibRetracementPct);
   if(setup.fibZone == "too_shallow_pullback")
     {
      setup.failReason = "too_shallow_pullback";
      setup.label = "h4_correction_invalid";
      setup.structuralBosState = "h4_correction_invalid";
      return false;
     }
   if(setup.fibZone == "too_deep_pullback")
     {
      setup.failReason = "too_deep_pullback";
      setup.label = "h4_correction_invalid";
      setup.structuralBosState = "h4_correction_invalid";
      return false;
     }

   setup.h4PullbackZonePass = true;
   setup.label = "h4_sequence_valid";
   return true;
  }

bool DetectNestedStructuralBosV2H1CounterNWave(const MqlRates &h1Rates[],
                                               const int direction,
                                               NestedNWaveSetup &setup)
  {
   int span = InpStructureSwingSpan;
   if(span < 1)
      span = 1;
   int scanBars = InpStructureScanBars;
   if(scanBars < span * 5 + 12)
      scanBars = span * 5 + 12;

   PivotPoint highLatest;
   PivotPoint highPrevious;
   PivotPoint highThird;
   PivotPoint lowLatest;
   PivotPoint lowPrevious;
   PivotPoint lowThird;
   bool hasHighs = FindRecentPivots3(h1Rates, true, span, scanBars, highLatest, highPrevious, highThird);
   bool hasLows = FindRecentPivots3(h1Rates, false, span, scanBars, lowLatest, lowPrevious, lowThird);
   if(!hasHighs || !hasLows)
     {
      setup.failReason = "h1_counter_range_noise";
      setup.h1CounterTrendState = "missing_h1_sequence";
      setup.structuralBosState = "h1_counter_range_noise";
      return false;
     }

   double counterRange = 0.0;
   if(direction > 0)
     {
      PivotPoint pivotA = highPrevious;
      PivotPoint pivotC = highLatest;
      PivotPoint pivotB;
      if(!FindBestPivotBetween(h1Rates, false, span, pivotC.shift, pivotA.shift, pivotB))
        {
         setup.failReason = "h1_counter_range_noise";
         setup.h1CounterTrendState = "missing_h1_counter_low";
         setup.structuralBosState = "h1_counter_range_noise";
         return false;
        }

      if(pivotC.price >= pivotA.price)
        {
         setup.failReason = "h1_counter_range_noise";
         setup.h1CounterTrendState = "no_lower_high";
         setup.structuralBosState = "h1_counter_range_noise";
         return false;
        }
      if(pivotB.price <= setup.h4ImpulseLow)
        {
         setup.failReason = "h1_counter_too_deep";
         setup.h1CounterTrendState = "counter_wave_broke_h4_origin";
         setup.structuralBosState = "h1_counter_too_deep";
         return false;
        }

      counterRange = pivotA.price - pivotB.price;
      setup.h1PivotSequence = PivotSeq3Text("A_high", pivotA, "B_low", pivotB, "C_lower_high", pivotC);
      setup.h1CounterNWaveHigh = pivotA.price;
      setup.h1CounterNWaveLow = pivotB.price;
      setup.h1BosLevel = pivotC.price;
      setup.trueBosLevel = pivotC.price;
      setup.bosLevelSourcePivot = "h1_last_lower_high";
      setup.rightSideLevel = pivotB.price;
      setup.h1CounterTrendState = "h1_counter_sequence_valid_bearish";
     }
   else
     {
      PivotPoint pivotA = lowPrevious;
      PivotPoint pivotC = lowLatest;
      PivotPoint pivotB;
      if(!FindBestPivotBetween(h1Rates, true, span, pivotC.shift, pivotA.shift, pivotB))
        {
         setup.failReason = "h1_counter_range_noise";
         setup.h1CounterTrendState = "missing_h1_counter_high";
         setup.structuralBosState = "h1_counter_range_noise";
         return false;
        }

      if(pivotC.price <= pivotA.price)
        {
         setup.failReason = "h1_counter_range_noise";
         setup.h1CounterTrendState = "no_higher_low";
         setup.structuralBosState = "h1_counter_range_noise";
         return false;
        }
      if(pivotB.price >= setup.h4ImpulseHigh)
        {
         setup.failReason = "h1_counter_too_deep";
         setup.h1CounterTrendState = "counter_wave_broke_h4_origin";
         setup.structuralBosState = "h1_counter_too_deep";
         return false;
        }

      counterRange = pivotB.price - pivotA.price;
      setup.h1PivotSequence = PivotSeq3Text("A_low", pivotA, "B_high", pivotB, "C_higher_low", pivotC);
      setup.h1CounterNWaveHigh = pivotB.price;
      setup.h1CounterNWaveLow = pivotA.price;
      setup.h1BosLevel = pivotC.price;
      setup.trueBosLevel = pivotC.price;
      setup.bosLevelSourcePivot = "h1_last_higher_low";
      setup.rightSideLevel = pivotB.price;
      setup.h1CounterTrendState = "h1_counter_sequence_valid_bullish";
     }

   if(counterRange <= 0.0)
     {
      setup.failReason = "h1_counter_range_noise";
      setup.structuralBosState = "h1_counter_range_noise";
      return false;
     }

   setup.h1CounterWaveATR = (setup.h1Atr > 0.0 ? counterRange / setup.h1Atr : 0.0);
   if(setup.h1CounterWaveATR < 1.00)
     {
      setup.failReason = "h1_counter_too_small";
      setup.label = "h1_counter_too_small";
      setup.structuralBosState = "h1_counter_too_small";
      return false;
     }

   setup.h1CounterTrendPass = true;
   setup.label = "h1_counter_sequence_valid";
   return true;
  }

bool DetectNestedStructuralBosV2Confirmation(const MqlRates &h1Rates[],
                                             const MqlRates &m15Rates[],
                                             const int direction,
                                             NestedNWaveSetup &setup)
  {
   double entryPrice = (direction > 0 ? SymbolInfoDouble(setup.symbol, SYMBOL_ASK) : SymbolInfoDouble(setup.symbol, SYMBOL_BID));
   if(entryPrice <= 0.0)
     {
      setup.failReason = "market_closed";
      setup.executionBlockReason = "market_closed";
      return false;
     }
   setup.entryPrice = entryPrice;

   double bosLevel = setup.trueBosLevel;
   if(bosLevel <= 0.0)
     {
      setup.failReason = "true_bos_level_unclear";
      setup.structuralBosState = "true_bos_level_unclear";
      return false;
     }

   bool h1BosConfirmed = (direction > 0 ? h1Rates[1].close > bosLevel : h1Rates[1].close < bosLevel);
   bool m15BosConfirmed = (direction > 0 ? m15Rates[1].close > bosLevel : m15Rates[1].close < bosLevel);

   int barsSinceBos = 0;
   int size = ArraySize(m15Rates);
   int maxBosLookback = MathMin(12, size - 2);
   for(int shift = 1; shift <= maxBosLookback; ++shift)
     {
      if(direction > 0)
        {
         if(m15Rates[shift].close > bosLevel && m15Rates[shift + 1].close <= bosLevel)
           {
            barsSinceBos = shift;
            break;
           }
        }
      else
        {
         if(m15Rates[shift].close < bosLevel && m15Rates[shift + 1].close >= bosLevel)
           {
            barsSinceBos = shift;
            break;
           }
        }
     }

   setup.necklinePrice = bosLevel;
   setup.necklineBreakClosePrice = m15Rates[1].close;
   setup.barsSinceBos = barsSinceBos;
   setup.barsSinceRightSide = barsSinceBos;
   setup.distanceBosToEntry = MathAbs(entryPrice - bosLevel);
   setup.distanceBosToEntryATR = (setup.m15Atr > 0.0 ? setup.distanceBosToEntry / setup.m15Atr : 0.0);
   setup.distanceNecklineToEntry = setup.distanceBosToEntry;
   setup.distanceNecklineToEntryATR = setup.distanceBosToEntryATR;
   setup.distanceRightSideToEntry = MathAbs(entryPrice - setup.rightSideLevel);
   setup.distanceRightSideToEntryATR = (setup.m15Atr > 0.0 ? setup.distanceRightSideToEntry / setup.m15Atr : 0.0);

   if(!h1BosConfirmed && !m15BosConfirmed)
     {
      setup.failReason = "no_h1_bos";
      setup.structuralBosState = "true_bos_level_not_invalidated";
      setup.label = "true_bos_level_valid";
      return false;
     }

   if(!m15BosConfirmed)
     {
      setup.failReason = "no_m15_bos";
      setup.structuralBosState = "h1_close_bos_without_m15_confirmation";
      setup.label = "h1_close_bos_confirmed";
      return false;
     }

   setup.necklinePass = true;
   setup.structuralBosState = (h1BosConfirmed ? "h1_close_bos_confirmed" : "m15_bos_confirmed");
   setup.m15ConfirmationType = "m15_bos_confirmed";
   if(barsSinceBos > 1)
      setup.m15ConfirmationType = "m15_retest_reclaim";

   UpdateNestedBreakoutQualityMetrics(m15Rates, (barsSinceBos > 0 ? barsSinceBos : 1), direction, setup);
   ClassifyNestedBreakoutQuality(setup);

   if(setup.distanceBosToEntryATR > 1.80 || setup.distanceRightSideToEntryATR > 3.20)
      setup.label = "chasing_entry";
   else if(setup.distanceBosToEntryATR > 1.20 || barsSinceBos > 8)
      setup.label = "late_entry";
   else
      setup.label = "clean_structural_bos_v2";

   setup.necklineBreakLabel = setup.label;
   setup.qualityScore = 150.0;
   if(setup.label == "clean_structural_bos_v2")
      setup.qualityScore += 25.0;
   else if(setup.label == "late_entry")
      setup.qualityScore -= 25.0;
   else if(setup.label == "chasing_entry")
      setup.qualityScore -= 45.0;

   setup.qualityScore -= MathAbs(setup.h4FibRetracementPct - 50.0) * 0.45;
   setup.qualityScore += MathMin(setup.h4ImpulseATR, 4.0) * 3.0;
   setup.qualityScore += MathMin(setup.h1CounterWaveATR, 3.0) * 3.0;
   setup.qualityScore -= setup.distanceBosToEntryATR * 14.0;
   setup.qualityScore -= MathMax(0, barsSinceBos - 3) * 3.0;
   return true;
  }

bool ApplyNestedStructuralBosV2RoomFilter(NestedNWaveSetup &setup, const int direction)
  {
   setup.roomToTargetLabel = "room_ok";
   setup.roomTo1R = 0.0;
   setup.roomTo2R = 0.0;
   if(setup.riskR <= 0.0)
      return true;

   double room = 0.0;
   if(direction > 0 && setup.h4ImpulseHigh > setup.entryPrice)
      room = setup.h4ImpulseHigh - setup.entryPrice;
   else if(direction < 0 && setup.h4ImpulseLow < setup.entryPrice)
      room = setup.entryPrice - setup.h4ImpulseLow;

   if(room <= 0.0)
     {
      setup.roomToTargetLabel = "target_beyond_known_h4_impulse";
      return true;
     }

   setup.roomTo1R = room / setup.riskR;
   setup.roomTo2R = room / (setup.riskR * 2.0);
   if(setup.roomTo2R < 1.0)
     {
      setup.roomToTargetLabel = "insufficient_room_to_target";
      setup.label = "insufficient_room_to_target";
      setup.necklineBreakLabel = setup.label;
     }

   if(setup.roomTo1R < 1.0)
     {
      setup.failReason = "insufficient_room_to_target";
      setup.label = "insufficient_room_to_target";
      return false;
     }

   return true;
  }

string ClassifyNestedNecklineBreakLabel(const NestedNWaveSetup &setup, const bool freshBreak, const bool doublePattern)
  {
   if(!setup.necklinePass)
      return "no_clear_neckline";
   if(setup.distanceNecklineToEntryATR > 1.20 ||
      setup.distanceRightSideToEntryATR > 3.20 ||
      setup.barsSinceRightSide > 18)
      return "chasing_after_break";
   if(doublePattern && freshBreak &&
      setup.distanceNecklineToEntryATR <= 0.35 &&
      setup.distanceRightSideToEntryATR <= 2.40 &&
      setup.barsSinceRightSide <= 10)
      return "clean_nested_nwave_entry";
   if(freshBreak && setup.distanceNecklineToEntryATR <= 0.65 && setup.barsSinceRightSide <= 12)
      return "neckline_break_initial";
   return "neckline_break_late";
  }

void UpdateNestedBreakoutQualityMetrics(const MqlRates &m15Rates[],
                                        const int breakoutShift,
                                        const int direction,
                                        NestedNWaveSetup &setup)
  {
   int size = ArraySize(m15Rates);
   if(breakoutShift < 1 || breakoutShift >= size || setup.necklinePrice <= 0.0)
      return;

   double point = SymbolInfoDouble(setup.symbol, SYMBOL_POINT);
   double range = m15Rates[breakoutShift].high - m15Rates[breakoutShift].low;
   double body = MathAbs(m15Rates[breakoutShift].close - m15Rates[breakoutShift].open);
   double upperWick = m15Rates[breakoutShift].high - MathMax(m15Rates[breakoutShift].open, m15Rates[breakoutShift].close);
   double lowerWick = MathMin(m15Rates[breakoutShift].open, m15Rates[breakoutShift].close) - m15Rates[breakoutShift].low;
   if(range <= 0.0)
      return;

   double closeDistance = 0.0;
   if(direction > 0)
     {
      closeDistance = m15Rates[breakoutShift].close - setup.necklinePrice;
      setup.breakoutClosePositionDirectional = (m15Rates[breakoutShift].close - m15Rates[breakoutShift].low) / range;
      setup.breakoutDirectionalWickRatio = upperWick / range;
     }
   else
     {
      closeDistance = setup.necklinePrice - m15Rates[breakoutShift].close;
      setup.breakoutClosePositionDirectional = (m15Rates[breakoutShift].high - m15Rates[breakoutShift].close) / range;
      setup.breakoutDirectionalWickRatio = lowerWick / range;
     }

   setup.breakoutCloseDistanceFromNeckline = MathMax(0.0, closeDistance);
   setup.breakoutCloseDistanceFromNecklineATR = (setup.m15Atr > 0.0 ? setup.breakoutCloseDistanceFromNeckline / setup.m15Atr : 0.0);
   setup.breakoutCloseDistanceFromNecklinePoints = (point > 0.0 ? setup.breakoutCloseDistanceFromNeckline / point : 0.0);
   setup.breakoutBodyRatio = body / range;
   setup.breakoutBodyATR = (setup.m15Atr > 0.0 ? body / setup.m15Atr : 0.0);
   setup.breakoutRangeATR = (setup.m15Atr > 0.0 ? range / setup.m15Atr : 0.0);

   int touches = 0;
   int maxBars = MathMin(size - 1, MathMax(12, InpStructureSwingSpan * 12));
   double touchZone = MathMax(setup.m15Atr * 0.15, point * 10.0);
   for(int shift = breakoutShift + 1; shift <= maxBars; ++shift)
     {
      if(m15Rates[shift].high >= setup.necklinePrice - touchZone &&
         m15Rates[shift].low <= setup.necklinePrice + touchZone)
         ++touches;
     }
   setup.necklineTouchCount = touches;
  }

string ClassifyNestedBreakoutQuality(NestedNWaveSetup &setup)
  {
   setup.breakoutQualityLabel = "unclear";
   setup.breakoutQualityReason = "";
   setup.breakoutQualityPass = false;
   setup.breakoutStrong = false;
   setup.breakoutWeak = false;
   setup.breakoutDirty = false;

   if(!setup.necklinePass)
     {
      setup.breakoutQualityReason = "no_neckline_break";
      return setup.breakoutQualityLabel;
     }

   string reason = "";
   if(setup.breakoutCloseDistanceFromNecklineATR < 0.10)
      AppendReason(reason, "shallow_close_distance");
   if(setup.breakoutClosePositionDirectional < 0.45)
      AppendReason(reason, "weak_directional_close");
   if(setup.breakoutDirectionalWickRatio > 0.45)
      AppendReason(reason, "large_directional_wick");
   if(setup.slATR > 2.0)
      AppendReason(reason, "sl_too_wide_for_router");
   if(setup.distanceNecklineToEntryATR > 1.20)
      AppendReason(reason, "entry_far_from_neckline");
   if(setup.breakoutRangeATR > 2.80)
      AppendReason(reason, "breakout_bar_overextended");

   if(reason != "")
     {
      setup.breakoutQualityLabel = "dirty_breakout";
      setup.breakoutQualityReason = reason;
      setup.breakoutDirty = true;
      return setup.breakoutQualityLabel;
     }

   bool strong = (setup.breakoutCloseDistanceFromNecklineATR >= 0.25 &&
                  setup.breakoutBodyRatio >= 0.55 &&
                  setup.breakoutClosePositionDirectional >= 0.65 &&
                  setup.breakoutDirectionalWickRatio <= 0.30 &&
                  setup.breakoutRangeATR <= 2.20 &&
                  setup.slATR <= 1.80);
   if(strong)
     {
      setup.breakoutQualityLabel = "strong_breakout";
      setup.breakoutQualityReason = "instant_entry_quality";
      setup.breakoutQualityPass = true;
      setup.breakoutStrong = true;
      return setup.breakoutQualityLabel;
     }

   setup.breakoutQualityLabel = "weak_breakout";
   setup.breakoutQualityReason = "route_to_retest_confirmation";
   setup.breakoutQualityPass = true;
   setup.breakoutWeak = true;
   return setup.breakoutQualityLabel;
  }

string ClassifyNestedContextQuality(NestedNWaveSetup &setup)
  {
   setup.contextQualityLabel = "mixed_context";
   setup.contextQualityReason = "";
   setup.contextQualityScore = 0.0;
   setup.contextClean = false;
   setup.contextMixed = false;
   setup.contextPoor = false;

   int positive = 0;
   int negative = 0;
   string reason = "";

   if(setup.h4FibRetracementPct >= 42.0 && setup.h4FibRetracementPct <= 58.0)
     {
      ++positive;
      AppendReason(reason, "h4_mid_pullback");
     }
   else
     {
      ++negative;
      AppendReason(reason, "h4_edge_pullback");
     }

   if(setup.necklineTouchCount >= 5 && setup.necklineTouchCount <= 14)
     {
      ++positive;
      AppendReason(reason, "neckline_tested_not_extreme");
     }
   else if(setup.necklineTouchCount < 3 || setup.necklineTouchCount > 18)
     {
      ++negative;
      AppendReason(reason, "neckline_touch_extreme");
     }
   else
      AppendReason(reason, "neckline_touch_neutral");

   if(setup.slATR > 0.0 && setup.slATR <= 1.70)
     {
      ++positive;
      AppendReason(reason, "sl_atr_compact");
     }
   else if(setup.slATR > 2.00)
     {
      ++negative;
      AppendReason(reason, "sl_atr_wide");
     }
   else
      AppendReason(reason, "sl_atr_neutral");

   if(setup.distanceNecklineToEntryATR >= 0.10 && setup.distanceNecklineToEntryATR <= 0.80)
     {
      ++positive;
      AppendReason(reason, "entry_distance_usable");
     }
   else if(setup.distanceNecklineToEntryATR > 1.20)
     {
      ++negative;
      AppendReason(reason, "entry_distance_far");
     }
   else
      AppendReason(reason, "entry_distance_neutral");

   if(setup.breakoutClosePositionDirectional >= 0.55)
     {
      ++positive;
      AppendReason(reason, "directional_close_ok");
     }
   else if(setup.breakoutClosePositionDirectional < 0.35)
     {
      ++negative;
      AppendReason(reason, "directional_close_weak");
     }
   else
      AppendReason(reason, "directional_close_neutral");

   if(setup.breakoutBodyATR >= 0.20 && setup.breakoutBodyATR <= 1.00)
     {
      ++positive;
      AppendReason(reason, "body_atr_usable");
     }
   else if(setup.breakoutBodyATR > 1.20)
     {
      ++negative;
      AppendReason(reason, "body_atr_overextended");
     }
   else
      AppendReason(reason, "body_atr_neutral");

   if(setup.breakoutDirectionalWickRatio <= 0.45)
     {
      ++positive;
      AppendReason(reason, "wick_ok");
     }
   else if(setup.breakoutDirectionalWickRatio > 0.60)
     {
      ++negative;
      AppendReason(reason, "wick_large");
     }
   else
      AppendReason(reason, "wick_neutral");

   if(setup.distanceRightSideToEntryATR > 0.0 && setup.distanceRightSideToEntryATR <= 2.80)
     {
      ++positive;
      AppendReason(reason, "right_side_room_ok");
     }
   else if(setup.distanceRightSideToEntryATR > 3.30)
     {
      ++negative;
      AppendReason(reason, "right_side_distance_far");
     }
   else
      AppendReason(reason, "right_side_distance_neutral");

   if(setup.necklineBreakLabel == "chasing_after_break")
     {
      ++negative;
      AppendReason(reason, "late_break_label");
     }

   setup.contextQualityScore = positive - negative;
   setup.contextQualityReason = reason;

   if(positive >= 6 && negative <= 1)
     {
      setup.contextQualityLabel = "clean_context";
      setup.contextClean = true;
     }
   else if(negative >= 3 || positive <= 3)
     {
      setup.contextQualityLabel = "poor_context";
      setup.contextPoor = true;
     }
   else
     {
      setup.contextQualityLabel = "mixed_context";
      setup.contextMixed = true;
     }

   return setup.contextQualityLabel;
  }

bool DetectNestedM15NecklineBreak(const MqlRates &m15Rates[],
                                  const int direction,
                                  NestedNWaveSetup &setup)
  {
   int span = InpStructureSwingSpan;
   if(span < 1)
      span = 1;
   int scanBars = InpStructureScanBars;
   if(scanBars < span * 4 + 10)
      scanBars = span * 4 + 10;

   PivotPoint highLatest;
   PivotPoint highPrevious;
   PivotPoint lowLatest;
   PivotPoint lowPrevious;
   bool hasHighs = FindRecentPivots(m15Rates, true, span, scanBars, highLatest, highPrevious);
   bool hasLows = FindRecentPivots(m15Rates, false, span, scanBars, lowLatest, lowPrevious);
   if(!hasHighs || !hasLows)
     {
      setup.failReason = "no_clear_neckline";
      return false;
     }

   double point = SymbolInfoDouble(setup.symbol, SYMBOL_POINT);
   double entryPrice = (direction > 0 ? SymbolInfoDouble(setup.symbol, SYMBOL_ASK) : SymbolInfoDouble(setup.symbol, SYMBOL_BID));
   if(entryPrice <= 0.0)
     {
      setup.failReason = "market_closed";
      setup.executionBlockReason = "market_closed";
      return false;
     }
   setup.entryPrice = entryPrice;

   double neckline = 0.0;
   bool doublePattern = false;
   bool freshBreak = false;
   if(direction > 0)
     {
      doublePattern = (MathAbs(lowLatest.price - lowPrevious.price) <= setup.m15Atr * 0.75);
      if(!PivotRangeHigh(m15Rates, lowLatest.shift, lowPrevious.shift, neckline))
         neckline = highLatest.price;
      if(neckline <= 0.0 || m15Rates[1].close <= neckline)
        {
         setup.failReason = "no_neckline_break";
         return false;
        }
      freshBreak = (m15Rates[2].close <= neckline);
      setup.rightSideLevel = lowLatest.price;
      setup.barsSinceRightSide = lowLatest.shift;
      setup.necklinePrice = neckline;
      setup.necklineBreakClosePrice = m15Rates[1].close;
      setup.distanceNecklineToEntry = MathAbs(setup.entryPrice - neckline);
      setup.distanceRightSideToEntry = MathAbs(setup.entryPrice - setup.rightSideLevel);
     }
   else
     {
      doublePattern = (MathAbs(highLatest.price - highPrevious.price) <= setup.m15Atr * 0.75);
      if(!PivotRangeLow(m15Rates, highLatest.shift, highPrevious.shift, neckline))
         neckline = lowLatest.price;
      if(neckline <= 0.0 || m15Rates[1].close >= neckline)
        {
         setup.failReason = "no_neckline_break";
         return false;
        }
      freshBreak = (m15Rates[2].close >= neckline);
      setup.rightSideLevel = highLatest.price;
      setup.barsSinceRightSide = highLatest.shift;
      setup.necklinePrice = neckline;
      setup.necklineBreakClosePrice = m15Rates[1].close;
      setup.distanceNecklineToEntry = MathAbs(setup.entryPrice - neckline);
      setup.distanceRightSideToEntry = MathAbs(setup.entryPrice - setup.rightSideLevel);
     }

   setup.distanceNecklineToEntryATR = (setup.m15Atr > 0.0 ? setup.distanceNecklineToEntry / setup.m15Atr : 0.0);
   setup.distanceRightSideToEntryATR = (setup.m15Atr > 0.0 ? setup.distanceRightSideToEntry / setup.m15Atr : 0.0);
   setup.necklinePass = true;
   UpdateNestedBreakoutQualityMetrics(m15Rates, 1, direction, setup);
   setup.necklineBreakLabel = ClassifyNestedNecklineBreakLabel(setup, freshBreak, doublePattern);
   setup.label = setup.necklineBreakLabel;
   if(setup.necklineBreakLabel == "clean_nested_nwave_entry")
      setup.qualityScore = 130.0;
   else if(setup.necklineBreakLabel == "neckline_break_initial")
      setup.qualityScore = 110.0;
   else if(setup.necklineBreakLabel == "neckline_break_late")
      setup.qualityScore = 80.0;
   else
      setup.qualityScore = 45.0;

   setup.qualityScore -= MathAbs(setup.h4FibRetracementPct - 50.0) * 0.60;
   setup.qualityScore -= setup.distanceNecklineToEntryATR * 12.0;
   setup.qualityScore -= MathMax(0, setup.barsSinceRightSide - 5) * 2.0;
   if(point > 0.0)
      setup.distanceNecklineToEntry = NormalizeDouble(setup.distanceNecklineToEntry, (int)SymbolInfoInteger(setup.symbol, SYMBOL_DIGITS));
   return true;
  }

bool DetectNestedM15RetestConfirmation(const MqlRates &m15Rates[],
                                        const int direction,
                                        NestedNWaveSetup &setup)
  {
   int span = InpStructureSwingSpan;
   if(span < 1)
      span = 1;
   int scanBars = InpStructureScanBars;
   if(scanBars < span * 4 + 10)
      scanBars = span * 4 + 10;

   PivotPoint highLatest;
   PivotPoint highPrevious;
   PivotPoint lowLatest;
   PivotPoint lowPrevious;
   bool hasHighs = FindRecentPivots(m15Rates, true, span, scanBars, highLatest, highPrevious);
   bool hasLows = FindRecentPivots(m15Rates, false, span, scanBars, lowLatest, lowPrevious);
   if(!hasHighs || !hasLows)
     {
      setup.failReason = "no_clear_neckline";
      return false;
     }

   double entryPrice = (direction > 0 ? SymbolInfoDouble(setup.symbol, SYMBOL_ASK) : SymbolInfoDouble(setup.symbol, SYMBOL_BID));
   if(entryPrice <= 0.0)
     {
      setup.failReason = "market_closed";
      setup.executionBlockReason = "market_closed";
      return false;
     }
   setup.entryPrice = entryPrice;

   double neckline = 0.0;
   bool doublePattern = false;
   if(direction > 0)
     {
      doublePattern = (MathAbs(lowLatest.price - lowPrevious.price) <= setup.m15Atr * 0.75);
      if(!PivotRangeHigh(m15Rates, lowLatest.shift, lowPrevious.shift, neckline))
         neckline = highLatest.price;
      setup.rightSideLevel = lowLatest.price;
      setup.barsSinceRightSide = lowLatest.shift;
     }
   else
     {
      doublePattern = (MathAbs(highLatest.price - highPrevious.price) <= setup.m15Atr * 0.75);
      if(!PivotRangeLow(m15Rates, highLatest.shift, highPrevious.shift, neckline))
         neckline = lowLatest.price;
      setup.rightSideLevel = highLatest.price;
      setup.barsSinceRightSide = highLatest.shift;
     }

   if(neckline <= 0.0)
     {
      setup.failReason = "no_clear_neckline";
      return false;
     }

   int size = ArraySize(m15Rates);
   int maxWaitBars = 8;
   int breakoutShift = -1;
   for(int shift = 2; shift <= maxWaitBars + 1 && shift + 1 < size; ++shift)
     {
      if(direction > 0)
        {
         if(m15Rates[shift].close > neckline && m15Rates[shift + 1].close <= neckline)
           {
            breakoutShift = shift;
            break;
           }
        }
      else
        {
         if(m15Rates[shift].close < neckline && m15Rates[shift + 1].close >= neckline)
           {
            breakoutShift = shift;
            break;
           }
        }
     }

   setup.necklinePrice = neckline;
   setup.necklineBreakLabel = "retest_confirmation_wait";
   if(breakoutShift < 0)
     {
      setup.failReason = "no_retest_confirmation_break";
      setup.retestFailureReason = setup.failReason;
      return false;
     }

   setup.originalNecklineBreakTime = m15Rates[breakoutShift].time;
   setup.necklineBreakClosePrice = m15Rates[breakoutShift].close;
   setup.entryDelayBars = breakoutShift - 1;
   setup.retestZoneATR = 0.50;
   UpdateNestedBreakoutQualityMetrics(m15Rates, breakoutShift, direction, setup);

   bool invalidated = false;
   bool returnedInside = false;
   bool retestFound = false;
   int retestShift = -1;
   double zone = setup.m15Atr * setup.retestZoneATR;
   double bestDepth = DBL_MAX;

   for(int shift = breakoutShift - 1; shift >= 1; --shift)
     {
      if(direction > 0)
        {
         if(m15Rates[shift].close < setup.rightSideLevel)
            invalidated = true;
         if(m15Rates[shift].close <= neckline)
            returnedInside = true;
         if(m15Rates[shift].low <= neckline + zone && m15Rates[shift].close >= setup.rightSideLevel)
           {
            double depth = MathAbs(m15Rates[shift].low - neckline);
            if(depth < bestDepth)
              {
               bestDepth = depth;
               retestShift = shift;
               retestFound = true;
              }
           }
        }
      else
        {
         if(m15Rates[shift].close > setup.rightSideLevel)
            invalidated = true;
         if(m15Rates[shift].close >= neckline)
            returnedInside = true;
         if(m15Rates[shift].high >= neckline - zone && m15Rates[shift].close <= setup.rightSideLevel)
           {
            double depth = MathAbs(m15Rates[shift].high - neckline);
            if(depth < bestDepth)
              {
               bestDepth = depth;
               retestShift = shift;
               retestFound = true;
              }
           }
        }
     }

   setup.falseBreakReturnInsideNeckline = returnedInside;
   if(invalidated)
     {
      setup.retestFailed = true;
      setup.failReason = "retest_invalidated";
      setup.retestFailureReason = setup.failReason;
      setup.retestQuality = "return_inside_and_fail";
      return false;
     }
   if(!retestFound)
     {
      setup.failReason = "no_retest_detected";
      setup.retestFailureReason = setup.failReason;
      setup.retestQuality = "no_retest_break_and_go";
      return false;
     }

   setup.retestDetected = true;
   setup.retestHeld = true;
   setup.retestDetectedTime = m15Rates[retestShift].time;
   setup.retestBarsAfterBreakout = breakoutShift - retestShift;
   setup.retestDepthATR = (setup.m15Atr > 0.0 ? bestDepth / setup.m15Atr : 0.0);
   setup.retestDistanceFromNecklineATR = setup.retestDepthATR;

   double recentHigh = 0.0;
   double recentLow = 0.0;
   int lookbackBars = MathMin(3, MathMax(1, breakoutShift - 2));
   if(lookbackBars > 0 && 2 + lookbackBars <= size)
     {
      recentHigh = HighestHigh(m15Rates, 2, lookbackBars);
      recentLow = LowestLow(m15Rates, 2, lookbackBars);
     }

   bool candleTrigger = false;
   bool minorBreakTrigger = false;
   if(direction > 0)
     {
      candleTrigger = (m15Rates[1].close > m15Rates[1].open && m15Rates[1].close > neckline);
      minorBreakTrigger = (recentHigh > 0.0 && m15Rates[1].close > recentHigh);
      setup.retestReclaimPrice = (minorBreakTrigger ? recentHigh : neckline);
      setup.distanceNecklineToEntry = MathAbs(setup.entryPrice - neckline);
      setup.distanceRightSideToEntry = MathAbs(setup.entryPrice - setup.rightSideLevel);
     }
   else
     {
      candleTrigger = (m15Rates[1].close < m15Rates[1].open && m15Rates[1].close < neckline);
      minorBreakTrigger = (recentLow > 0.0 && m15Rates[1].close < recentLow);
      setup.retestReclaimPrice = (minorBreakTrigger ? recentLow : neckline);
      setup.distanceNecklineToEntry = MathAbs(setup.entryPrice - neckline);
      setup.distanceRightSideToEntry = MathAbs(setup.entryPrice - setup.rightSideLevel);
     }

   if(!candleTrigger && !minorBreakTrigger)
     {
      setup.failReason = "no_retest_trigger";
      setup.retestFailureReason = setup.failReason;
      setup.retestQuality = (returnedInside ? "deep_retest_but_reclaim_missing" : "shallow_retest_no_trigger");
      return false;
     }

   setup.retestTriggerPass = true;
   setup.retestTriggerTime = m15Rates[1].time;
   setup.retestQuality = (returnedInside ? "deep_retest_but_reclaim" : "shallow_retest_then_go");
   setup.distanceNecklineToEntryATR = (setup.m15Atr > 0.0 ? setup.distanceNecklineToEntry / setup.m15Atr : 0.0);
   setup.distanceRightSideToEntryATR = (setup.m15Atr > 0.0 ? setup.distanceRightSideToEntry / setup.m15Atr : 0.0);
   setup.necklinePass = true;
   setup.necklineBreakLabel = "retest_confirmed";
   setup.label = (setup.falseBreakReturnInsideNeckline ? "retest_then_go_after_return_inside" : "retest_confirmation_entry");
   setup.qualityScore = 125.0;
   if(doublePattern)
      setup.qualityScore += 10.0;
   setup.qualityScore -= setup.retestDepthATR * 10.0;
   setup.qualityScore -= setup.distanceNecklineToEntryATR * 8.0;
   setup.qualityScore -= MathMax(0, setup.entryDelayBars - 4) * 2.0;
   return true;
  }

bool CalculateNestedStopLoss(const string symbol,
                             const int direction,
                             NestedNWaveSetup &setup)
  {
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double spread = SpreadPrice(symbol);
   double buffer = MathMax(spread, setup.m15Atr * 0.05);
   buffer = MathMax(buffer, point * 5.0);
   if(point <= 0.0 || setup.entryPrice <= 0.0 || setup.rightSideLevel <= 0.0)
     {
      setup.failReason = "invalid_structure";
      return false;
     }

   if(direction > 0)
     {
      setup.stopLoss = NormalizeDouble(setup.rightSideLevel - buffer, digits);
      setup.riskR = setup.entryPrice - setup.stopLoss;
     }
   else
     {
      setup.stopLoss = NormalizeDouble(setup.rightSideLevel + buffer, digits);
      setup.riskR = setup.stopLoss - setup.entryPrice;
     }

   setup.slPoints = setup.riskR / point;
   setup.slATR = (setup.m15Atr > 0.0 ? setup.riskR / setup.m15Atr : 0.0);
   double brokerStop = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point + spread;
   double minDistance = MathMax(brokerStop, setup.m15Atr * InpMinSL_ATR);
   double maxDistance = setup.m15Atr * InpMaxSL_ATR;
   if(setup.riskR <= brokerStop || setup.riskR <= minDistance)
     {
      setup.failReason = "sl_too_tight";
      setup.label = "sl_too_tight";
      return false;
     }
   if(maxDistance > 0.0 && setup.riskR > maxDistance)
     {
      setup.failReason = "sl_too_wide";
      setup.label = "sl_too_wide";
      return false;
     }

   setup.volume = CalculatePositionSize(symbol, setup.riskR);
   if(setup.volume <= 0.0)
     {
      setup.failReason = "sl_too_tight";
      setup.label = "sl_too_tight";
      return false;
     }

   setup.structureSlPass = true;
   return true;
  }

bool CalculateNestedTakeProfit(const string symbol,
                               const int direction,
                               NestedNWaveSetup &setup)
  {
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   setup.rr = InpRewardR;
   if(setup.rr <= 0.0 || setup.riskR <= 0.0)
     {
      setup.failReason = "rr_too_low";
      return false;
     }

   if(direction > 0)
      setup.takeProfit = NormalizeDouble(setup.entryPrice + setup.riskR * setup.rr, digits);
   else
      setup.takeProfit = NormalizeDouble(setup.entryPrice - setup.riskR * setup.rr, digits);

   if(setup.takeProfit <= 0.0)
     {
      setup.failReason = "rr_too_low";
      return false;
     }

   setup.tpPoints = MathAbs(setup.takeProfit - setup.entryPrice) / SymbolInfoDouble(symbol, SYMBOL_POINT);
   setup.tpATR = (setup.m15Atr > 0.0 ? MathAbs(setup.takeProfit - setup.entryPrice) / setup.m15Atr : 0.0);
   setup.rrPass = true;
   return true;
  }

bool BuildNestedNWaveSetup(const string symbol,
                           const int direction,
                           NestedNWaveSetup &setup)
  {
   InitNestedNWaveSetup(setup, symbol, direction);

   string researchReason = "";
   if(!IsSymbolAllowedByResearchMode(symbol, researchReason))
     {
      setup.failReason = researchReason;
      return false;
     }
   if(!IsDirectionAllowedByResearchMode(symbol, direction, researchReason))
     {
      setup.failReason = researchReason;
      return false;
     }

   MqlRates h4Rates[];
   MqlRates h1Rates[];
   MqlRates m15Rates[];
   string reason = "";
   int barsNeeded = RequiredBars();
   if(!LoadRates(symbol, InpContextTF, barsNeeded, h4Rates, reason) ||
      !LoadRates(symbol, InpPatternTF, barsNeeded, h1Rates, reason) ||
      !LoadRates(symbol, InpExecutionTF, barsNeeded, m15Rates, reason))
     {
      setup.failReason = reason;
      return false;
     }

   setup.h4Atr = AverageATR(h4Rates, 1, InpATRPeriod);
   setup.h1Atr = AverageATR(h1Rates, 1, InpATRPeriod);
   setup.m15Atr = AverageATR(m15Rates, 1, InpATRPeriod);
   if(setup.h4Atr <= 0.0 || setup.h1Atr <= 0.0 || setup.m15Atr <= 0.0)
     {
      setup.failReason = "atr_unavailable";
      return false;
     }

   double spread = SpreadPrice(symbol);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   setup.spreadATR = spread / setup.m15Atr;
   setup.spreadPoints = (point > 0.0 ? spread / point : 0.0);
   setup.spreadGuardPass = (setup.spreadATR <= InpMaxSpreadATR);
   setup.spreadGuardBlocked = !setup.spreadGuardPass;
   setup.dataReady = true;

   if(IsNestedNWaveStructuralBosV2Mode())
     {
      if(!DetectNestedStructuralBosV2H4Sequence(h4Rates, direction, setup))
         return false;
      if(!DetectNestedStructuralBosV2H1CounterNWave(h1Rates, direction, setup))
         return false;
     }
   else
     {
      if(!DetectNestedH4ImpulseAndPullback(h4Rates, direction, setup))
         return false;
      if(!DetectNestedH1CounterTrendNWave(h1Rates, direction, setup))
         return false;
     }

   setup.setupPass = true;

   if(IsNestedNWaveStructuralBosV2Mode())
     {
      if(!DetectNestedStructuralBosV2Confirmation(h1Rates, m15Rates, direction, setup))
         return false;
      if(!CalculateNestedStopLoss(symbol, direction, setup))
         return false;
      if(!CalculateNestedTakeProfit(symbol, direction, setup))
         return false;
      if(!ApplyNestedStructuralBosV2RoomFilter(setup, direction))
         return false;
     }
   else if(IsNestedNWaveStructuralBosMode())
     {
      if(!DetectNestedStructuralBosConfirmation(h1Rates, m15Rates, direction, setup))
         return false;
      if(!CalculateNestedStopLoss(symbol, direction, setup))
         return false;
      if(!CalculateNestedTakeProfit(symbol, direction, setup))
         return false;
     }
   else if(IsNestedNWaveBreakoutQualityRouterMode() || IsNestedNWaveContextQualityRouterMode())
     {
      bool currentBreakDetected = DetectNestedM15NecklineBreak(m15Rates, direction, setup);
      if(currentBreakDetected)
        {
         if(!CalculateNestedStopLoss(symbol, direction, setup))
            return false;
         if(!CalculateNestedTakeProfit(symbol, direction, setup))
            return false;

         string quality = ClassifyNestedBreakoutQuality(setup);
         string context = ClassifyNestedContextQuality(setup);
         if(IsNestedNWaveContextQualityRouterMode())
           {
            if(quality == "strong_breakout")
              {
               if(context == "poor_context")
                 {
                  setup.failReason = "context_router_strong_poor_context_wait_retest";
                  setup.label = "strong_breakout_poor_context";
                  return false;
                 }
               setup.necklineBreakLabel = "context_router_strong_instant";
               setup.label = "strong_breakout_" + context;
              }
            else if(quality == "weak_breakout")
              {
               if(context == "clean_context")
                 {
                  if(IsNestedNWaveContextQualityRouterV2Mode() && setup.breakoutBodyATR < 0.20)
                    {
                     setup.failReason = "context_router_v2_weak_body_too_small";
                     setup.label = "weak_breakout_clean_context_body_too_small";
                     return false;
                    }
                  setup.necklineBreakLabel = "context_router_weak_clean_instant";
                  setup.label = "weak_breakout_clean_context";
               }
               else
                 {
                  setup.failReason = "context_router_weak_wait_retest";
                  setup.label = "weak_breakout_" + context;
                  return false;
                 }
              }
            else if(quality == "dirty_breakout")
              {
               if(context == "poor_context")
                 {
                  setup.failReason = "context_router_dirty_poor_context";
                  setup.label = "dirty_breakout_poor_context";
                  return false;
                 }
               setup.failReason = "context_router_dirty_wait_retest";
               setup.label = "dirty_breakout_" + context;
               return false;
              }
            else
              {
               setup.failReason = "context_router_unclear_breakout";
               setup.label = setup.breakoutQualityLabel;
               return false;
              }
           }
         else if(quality == "strong_breakout")
           {
            setup.necklineBreakLabel = "router_strong_instant";
            setup.label = "strong_breakout";
           }
         else if(quality == "weak_breakout")
           {
            setup.failReason = "weak_breakout_waiting_retest";
            setup.label = "weak_breakout";
            return false;
           }
         else
           {
            setup.failReason = (quality == "dirty_breakout" ? "dirty_breakout" : "unclear_breakout_quality");
            setup.label = setup.failReason;
            return false;
           }
        }
      else
        {
         setup.failReason = "";
         setup.label = "h1_counter_trend_nwave";
         setup.necklinePass = false;
         setup.retestConfirmationMode = true;
         if(!DetectNestedM15RetestConfirmation(m15Rates, direction, setup))
            return false;
         if(!CalculateNestedStopLoss(symbol, direction, setup))
            return false;
         if(!CalculateNestedTakeProfit(symbol, direction, setup))
            return false;

         string quality = ClassifyNestedBreakoutQuality(setup);
         string context = ClassifyNestedContextQuality(setup);
         if(IsNestedNWaveContextQualityRouterMode())
           {
            bool allowRetest = false;
            if(quality == "weak_breakout" && context != "poor_context")
               allowRetest = true;
            else if(quality == "dirty_breakout" && context == "clean_context")
               allowRetest = true;
            else if(quality == "strong_breakout" && context != "poor_context")
               allowRetest = true;

            if(!allowRetest)
              {
               setup.failReason = "context_router_retest_context_block";
               setup.label = setup.breakoutQualityLabel + "_" + context;
               return false;
              }
            setup.necklineBreakLabel = "context_router_retest_confirmed";
            setup.label = setup.breakoutQualityLabel + "_" + context + "_retest_confirmed";
           }
         else if(quality != "weak_breakout")
           {
            setup.failReason = "router_retest_requires_weak_breakout";
            setup.label = setup.breakoutQualityLabel;
            return false;
           }
         else
           {
            setup.necklineBreakLabel = "router_weak_retest_confirmed";
            setup.label = "weak_breakout_retest_confirmed";
           }
        }
     }
   else if(IsNestedNWaveRetestConfirmationMode())
     {
      if(!DetectNestedM15RetestConfirmation(m15Rates, direction, setup))
         return false;
      if(!CalculateNestedStopLoss(symbol, direction, setup))
         return false;

      if(!CalculateNestedTakeProfit(symbol, direction, setup))
         return false;
     }
   else
     {
      if(!DetectNestedM15NecklineBreak(m15Rates, direction, setup))
         return false;
      if(!CalculateNestedStopLoss(symbol, direction, setup))
         return false;

      if(!CalculateNestedTakeProfit(symbol, direction, setup))
         return false;
     }

   if(setup.spreadGuardBlocked)
     {
      setup.executionBlockReason = "spread_guard";
      setup.failReason = "spread_guard";
      return false;
     }

   setup.entryPass = true;
   setup.finalEntryPass = true;
   setup.failReason = "";
   return true;
  }

void SetThirdWaveV2FilterFail(ThirdWaveSetup &setup, const string reason)
  {
   setup.v2FilterPass = false;
   setup.v2FilterFailReason = reason;
   setup.skipReason = reason;
   setup.structureStageFailReason = reason;
  }

bool ApplyThirdWaveV2AuditFilters(ThirdWaveSetup &setup)
  {
   if(!IsAuditFilteredThirdWaveV2Mode())
      return true;

   setup.v2FilterPass = false;
   setup.v2FilterFailReason = "";

   if(setup.pullbackBrokeOrigin || setup.pullbackDepthPct > 75.0)
     {
      SetThirdWaveV2FilterFail(setup, "v2_pullback_too_deep_audit");
      return false;
     }

   if(setup.higherTrendAgeBars > 10)
     {
      SetThirdWaveV2FilterFail(setup, "v2_trend_too_old");
      return false;
     }

   if(setup.entryDistanceFromReclaimATR > 1.50)
     {
      SetThirdWaveV2FilterFail(setup, "v2_reclaim_chase_too_far");
      return false;
     }

   setup.v2FilterPass = true;
   return true;
  }

void UpdateThirdWaveV3MomentumAudit(const MqlRates &executionRates[],
                                    const int direction,
                                    ThirdWaveSetup &setup)
  {
   setup.v3ConsecutiveDirectionalBars = 0;
   setup.v3RecentMoveATR = 0.0;
   setup.v3CloseToRecentExtremeATR = 0.0;
   setup.v3MomentumExhaustionScore = 0.0;
   setup.v3MomentumExhausted = false;

   double atr = setup.atrValue;
   if(atr <= 0.0)
      atr = setup.atr;
   if(atr <= 0.0)
      return;

   int size = ArraySize(executionRates);
   int maxShift = MathMin(size - 1, 6);
   for(int shift = 1; shift <= maxShift; ++shift)
     {
      bool directional = (direction > 0 ?
                          executionRates[shift].close > executionRates[shift].open :
                          executionRates[shift].close < executionRates[shift].open);
      if(!directional)
         break;
      ++setup.v3ConsecutiveDirectionalBars;
     }

   if(size > 4)
     {
      double move = (direction > 0 ?
                     executionRates[1].close - executionRates[4].close :
                     executionRates[4].close - executionRates[1].close);
      setup.v3RecentMoveATR = (move > 0.0 ? move / atr : 0.0);
     }

   int lookback = MathMin(size - 1, 8);
   if(lookback >= 1 && setup.entryPrice > 0.0)
     {
      double recentHigh = executionRates[1].high;
      double recentLow = executionRates[1].low;
      for(int shift = 2; shift <= lookback; ++shift)
        {
         recentHigh = MathMax(recentHigh, executionRates[shift].high);
         recentLow = MathMin(recentLow, executionRates[shift].low);
        }
      double distanceToExtreme = (direction > 0 ?
                                  MathAbs(recentHigh - setup.entryPrice) :
                                  MathAbs(setup.entryPrice - recentLow));
      setup.v3CloseToRecentExtremeATR = distanceToExtreme / atr;
     }

   if(setup.v3ConsecutiveDirectionalBars >= 3)
      setup.v3MomentumExhaustionScore += 35.0;
   if(setup.v3RecentMoveATR > 1.20)
      setup.v3MomentumExhaustionScore += 35.0;
   if(setup.v3CloseToRecentExtremeATR > 0.0 &&
      setup.v3CloseToRecentExtremeATR <= 0.25)
      setup.v3MomentumExhaustionScore += 20.0;
   if(setup.entryDistanceFromReclaimATR > 0.60)
      setup.v3MomentumExhaustionScore += 10.0;
   if(setup.distancePullbackExtremeToEntryATR > 2.50)
      setup.v3MomentumExhaustionScore += 10.0;

   setup.v3MomentumExhausted = (setup.v3MomentumExhaustionScore >= 60.0);
  }

void SetThirdWaveV3FilterFail(ThirdWaveSetup &setup, const string reason)
  {
   setup.v3FilterPass = false;
   setup.v3FilterFailReason = reason;
   setup.skipReason = reason;
   setup.structureStageFailReason = reason;
  }

bool ApplyThirdWaveV3EntryTimingFilters(ThirdWaveSetup &setup)
  {
   if(!IsEntryTimingThirdWaveV3Mode())
      return true;

   setup.v3FilterPass = false;
   setup.v3FilterFailReason = "";

   if(setup.waveAuditLabel == "invalid_structure" ||
      setup.waveAuditLabel == "range_noise" ||
      setup.waveAuditLabel == "unclear")
     {
      SetThirdWaveV3FilterFail(setup, "v3_wave_position_invalid");
      return false;
     }

   if(setup.barsSinceReclaimOrBreakdown > 2 ||
      setup.entryDistanceFromReclaimATR > 0.60)
     {
      SetThirdWaveV3FilterFail(setup, "v3_reclaim_chase_too_far");
      return false;
     }

   if(setup.distancePullbackExtremeToEntryATR > 2.50 ||
      setup.distancePullbackExtremeToEntryPct > 65.0)
     {
      SetThirdWaveV3FilterFail(setup, "v3_pullback_entry_too_far");
      return false;
     }

   if(setup.v3MomentumExhausted)
     {
      SetThirdWaveV3FilterFail(setup, "v3_momentum_exhausted");
      return false;
     }

   if(setup.waveAuditLabel == "late_entry")
     {
      SetThirdWaveV3FilterFail(setup, "v3_late_entry");
      return false;
     }

   if(setup.waveAuditLabel == "chasing_entry")
     {
      SetThirdWaveV3FilterFail(setup, "v3_chasing_entry");
      return false;
     }

   setup.v3FilterPass = true;
   return true;
  }

bool BuildThirdWaveSetup(const string symbol,
                         const int direction,
                         ThirdWaveSetup &setup)
  {
   InitThirdWaveSetup(setup, symbol, direction);

   string researchReason = "";
   if(!IsSymbolAllowedByResearchMode(symbol, researchReason))
     {
      setup.skipReason = researchReason;
      setup.structureStageFailReason = researchReason;
      return false;
     }
   if(!IsDirectionAllowedByResearchMode(symbol, direction, researchReason))
     {
      setup.skipReason = researchReason;
      setup.structureStageFailReason = researchReason;
      return false;
     }

   MqlRates contextRates[];
   MqlRates patternRates[];
   MqlRates executionRates[];
   string reason = "";
   int barsNeeded = RequiredBars();
   if(!LoadRates(symbol, InpContextTF, barsNeeded, contextRates, reason) ||
     !LoadRates(symbol, InpPatternTF, barsNeeded, patternRates, reason) ||
      !LoadRates(symbol, InpExecutionTF, barsNeeded, executionRates, reason))
     {
      setup.skipReason = reason;
      setup.structureStageFailReason = reason;
      return false;
     }

   setup.atr = AverageATR(patternRates, 1, InpATRPeriod);
   double executionATR = AverageATR(executionRates, 1, InpATRPeriod);
   if(setup.atr <= 0.0 || executionATR <= 0.0)
     {
      setup.skipReason = "atr_unavailable";
      setup.structureStageFailReason = "atr_unavailable";
      return false;
     }
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double spread = SpreadPrice(symbol);
   setup.atrValue = executionATR;
   setup.maxSpreadATR = InpMaxSpreadATR;
   setup.spreadATR = spread / executionATR;
   setup.spreadPoints = (point > 0.0 ? spread / point : 0.0);
   setup.spreadGuardPass = (setup.spreadATR <= setup.maxSpreadATR);
   setup.spreadGuardBlocked = !setup.spreadGuardPass;

   setup.dataReady = true;
   if(IsRegimeAwareThirdWaveMode())
     {
      ClassifyThirdWaveRegime(contextRates, setup);
      if(!ApplyThirdWaveRegimeGate(direction, setup))
         return false;
     }

   if(!DetectHigherTimeframeDowTrend(contextRates, direction, setup))
     {
      setup.structureStageFailReason = setup.skipReason;
      return false;
     }
   setup.higherTfTrendPass = true;

   if(!DetectMidTimeframePullback(patternRates, direction, setup))
     {
      setup.structureStageFailReason = setup.skipReason;
      return false;
     }
   setup.midTfPullbackPass = true;

   setup.setupPass = true;
   bool lowerReversalOk = (IsEarlyReversalThirdWaveV4Mode() ?
                           DetectEarlyLowerTimeframeReversal(executionRates, direction, setup) :
                           DetectLowerTimeframeReversal(executionRates, direction, setup));
   if(!lowerReversalOk)
     {
      setup.structureStageFailReason = setup.skipReason;
      return false;
     }
   setup.lowerTfReversalPass = true;

   if(!ApplyThirdWaveV4SignalModeFilter(setup))
      return false;

   if(!CalculateStructureStopLoss(symbol, direction, setup))
     {
      if(setup.skipReason == "market_closed")
         setup.executionBlockReason = setup.skipReason;
      else
         setup.structureStageFailReason = setup.skipReason;
      return false;
     }
   CalculateThirdWaveShadowStopLevels(symbol, direction, executionRates, setup);
   if(!ApplyThirdWaveActualStopMode(symbol, setup))
     {
      setup.structureStageFailReason = setup.skipReason;
      return false;
     }
   setup.structureSlPass = true;

   if(!CalculateThirdWaveTakeProfit(symbol, direction, setup))
     {
      setup.structureStageFailReason = setup.skipReason;
      return false;
     }
   setup.rrPass = true;
   UpdateThirdWaveV3MomentumAudit(executionRates, direction, setup);
   ClassifyThirdWaveAuditLabel(setup);

   if(!ApplyThirdWaveV2AuditFilters(setup))
      return false;

   if(!ApplyThirdWaveV3EntryTimingFilters(setup))
      return false;

   if(!ApplyThirdWaveV4ImpulseGate(setup))
      return false;

   if(setup.spreadGuardBlocked)
     {
      setup.executionBlockReason = "spread_guard";
      setup.skipReason = "spread_guard";
      return false;
     }

   setup.entryPass = true;
   setup.finalEntryPass = true;
   setup.skipReason = "";
   return true;
  }

void RecordThirdWaveStructureFailReason(const string reason)
  {
   if(reason == "")
      return;

   if(reason == "no_higher_tf_trend")
      ++g_thirdWaveNoHigherTrendCount;
   else if(reason == "trend_broken")
      ++g_thirdWaveTrendBrokenCount;
   else if(reason == "no_mid_pullback")
      ++g_thirdWaveNoMidPullbackCount;
   else if(reason == "pullback_too_shallow")
      ++g_thirdWavePullbackTooShallowCount;
   else if(reason == "pullback_too_deep")
      ++g_thirdWavePullbackTooDeepCount;
   else if(reason == "no_lower_reversal")
      ++g_thirdWaveNoLowerReversalCount;
   else if(reason == "lower_reversal_quality_low")
      ++g_thirdWaveLowerReversalQualityLowCount;
   else if(reason == "sl_too_close")
      ++g_thirdWaveSlTooCloseCount;
   else if(reason == "sl_too_tight")
      ++g_thirdWaveSlTooTightCount;
   else if(reason == "sl_too_wide")
      ++g_thirdWaveSlTooWideCount;
   else if(reason == "invalid_stops")
      ++g_thirdWaveInvalidStopsCount;
   else if(reason == "rr_too_low")
      ++g_thirdWaveRrTooLowCount;
   else if(StringFind(reason, "data_insufficient_") == 0)
      ++g_thirdWaveDataUnavailableCount;
   else if(reason == "atr_unavailable")
      ++g_thirdWaveAtrUnavailableCount;
   else if(StringFind(reason, "symbol_research_") == 0 ||
           reason == "disabled_usdjpy_short" ||
           reason == "direction_mode_long_only" ||
           reason == "direction_mode_short_only")
      ++g_thirdWaveResearchExcludedCount;
   else if(reason == "regime_requires_trend_up")
      ++g_thirdWaveRegimeBlockLongRequiresTrendUpCount;
   else if(reason == "regime_requires_trend_down")
      ++g_thirdWaveRegimeBlockShortRequiresTrendDownCount;
   else if(StringFind(reason, "v2_") == 0)
      return;
   else
      ++g_thirdWaveUnknownSkipCount;
  }

void RecordThirdWaveRegimeState(const ThirdWaveSetup &setup)
  {
   if(!IsRegimeAwareThirdWaveMode())
      return;

   if(setup.regime == RegimeToString(REGIME_TREND_UP))
      ++g_thirdWaveRegimeTrendUpCount;
   else if(setup.regime == RegimeToString(REGIME_TREND_DOWN))
      ++g_thirdWaveRegimeTrendDownCount;
   else if(setup.regime == RegimeToString(REGIME_RANGE))
      ++g_thirdWaveRegimeRangeCount;
   else if(setup.regime == RegimeToString(REGIME_TRANSITION))
      ++g_thirdWaveRegimeTransitionCount;
   else if(setup.regime == RegimeToString(REGIME_EXHAUSTION))
      ++g_thirdWaveRegimeExhaustionCount;
   else
      ++g_thirdWaveRegimeUnknownCount;

   if(setup.entryAllowedByRegime)
      ++g_thirdWaveRegimeAllowedCount;
   else if(setup.blockedByRegimeReason != "")
      ++g_thirdWaveRegimeBlockedCount;
  }

void RecordThirdWaveExecutionBlockReason(const string reason)
  {
   if(reason == "")
      return;

   if(reason == "spread_guard")
      ++g_thirdWaveExecutionSpreadGuardCount;
   else if(reason == "trading_disabled")
      ++g_thirdWaveExecutionTradingDisabledCount;
   else if(reason == "no_entry_signal" || reason == "direction_none")
      ++g_thirdWaveExecutionNoEntrySignalCount;
   else if(reason == "max_positions" ||
           reason == "existing_position" ||
           reason == "same_currency_group_limit")
      ++g_thirdWaveExecutionPositionLimitCount;
   else if(reason == "daily_loss_stop" ||
           reason == "weekly_loss_stop" ||
           reason == "max_drawdown_stop")
      ++g_thirdWaveExecutionRiskStopCount;
   else if(reason == "symbol_risk_limit" || reason == "total_risk_limit")
      ++g_thirdWaveExecutionRiskLimitCount;
   else if(reason == "trade_levels_invalid" || reason == "market_closed")
      ++g_thirdWaveExecutionInvalidCount;
   else if(reason == "order_failed")
      ++g_thirdWaveExecutionOrderFailedCount;
   else
      ++g_thirdWaveExecutionUnknownCount;
  }

void RecordThirdWaveStagePasses(const ThirdWaveSetup &setup)
  {
   bool isLong = (setup.direction == "LONG");
   bool isShort = (setup.direction == "SHORT");

   if(setup.higherTfTrendPass)
     {
      ++g_thirdWaveHigherTrendPassCount;
      if(isLong)
         ++g_thirdWaveLongHigherTrendPassCount;
      else if(isShort)
         ++g_thirdWaveShortHigherTrendPassCount;
     }
   if(setup.midTfPullbackPass)
     {
      ++g_thirdWaveMidPullbackPassCount;
      if(isLong)
         ++g_thirdWaveLongMidPullbackPassCount;
      else if(isShort)
         ++g_thirdWaveShortMidPullbackPassCount;
     }
   if(setup.lowerTfReversalPass)
     {
      ++g_thirdWaveLowerReversalPassCount;
      if(isLong)
         ++g_thirdWaveLongLowerReversalPassCount;
      else if(isShort)
         ++g_thirdWaveShortLowerReversalPassCount;
     }
   if(setup.structureSlPass)
     {
      ++g_thirdWaveStructureSlPassCount;
      if(isLong)
         ++g_thirdWaveLongStructureSlPassCount;
      else if(isShort)
         ++g_thirdWaveShortStructureSlPassCount;
     }
   if(setup.rrPass)
     {
      ++g_thirdWaveRrPassCount;
      if(isLong)
         ++g_thirdWaveLongRrPassCount;
      else if(isShort)
         ++g_thirdWaveShortRrPassCount;
     }
   if(setup.spreadGuardPass)
     {
      ++g_thirdWaveSpreadGuardPassCount;
      if(isLong)
         ++g_thirdWaveLongSpreadGuardPassCount;
      else if(isShort)
         ++g_thirdWaveShortSpreadGuardPassCount;
     }
   if(setup.spreadGuardBlocked)
     {
      ++g_thirdWaveSpreadGuardBlockedCount;
      if(isLong)
         ++g_thirdWaveLongSpreadGuardBlockedCount;
      else if(isShort)
         ++g_thirdWaveShortSpreadGuardBlockedCount;
     }
   if(setup.finalEntryPass)
     {
      ++g_thirdWaveFinalEntryPassCount;
      if(isLong)
         ++g_thirdWaveLongFinalEntryPassCount;
      else if(isShort)
         ++g_thirdWaveShortFinalEntryPassCount;
     }
  }

void RecordThirdWaveV2Filter(const ThirdWaveSetup &setup)
  {
   if(!IsAuditFilteredThirdWaveV2Mode())
      return;

   if(!setup.rrPass && setup.v2FilterFailReason == "" && !setup.v2FilterPass)
      return;

   ++g_thirdWaveV2FilterEvaluations;
   if(setup.v2FilterPass)
     {
      ++g_thirdWaveV2FilterPassCount;
      return;
     }

   ++g_thirdWaveV2FilterFailCount;
   if(setup.v2FilterFailReason == "v2_pullback_too_deep_audit")
      ++g_thirdWaveV2FilterDeepPullbackCount;
   else if(setup.v2FilterFailReason == "v2_trend_too_old")
      ++g_thirdWaveV2FilterTrendTooOldCount;
   else if(setup.v2FilterFailReason == "v2_reclaim_chase_too_far")
      ++g_thirdWaveV2FilterReclaimChaseCount;
  }

void RecordThirdWaveV3Filter(const ThirdWaveSetup &setup)
  {
   if(!IsEntryTimingThirdWaveV3Mode())
      return;

   if(setup.structureSlPass && setup.rrPass)
      ++g_thirdWaveV3FilterEvaluations;
   else
      return;

   if(setup.v3FilterPass)
     {
      ++g_thirdWaveV3FilterPassCount;
      return;
     }

   ++g_thirdWaveV3FilterFailCount;
   if(setup.v3FilterFailReason == "v3_wave_position_invalid")
      ++g_thirdWaveV3FilterInvalidPositionCount;
   else if(setup.v3FilterFailReason == "v3_late_entry")
      ++g_thirdWaveV3FilterLateEntryCount;
   else if(setup.v3FilterFailReason == "v3_chasing_entry")
      ++g_thirdWaveV3FilterChasingEntryCount;
   else if(setup.v3FilterFailReason == "v3_reclaim_chase_too_far")
      ++g_thirdWaveV3FilterReclaimChaseCount;
   else if(setup.v3FilterFailReason == "v3_pullback_entry_too_far")
      ++g_thirdWaveV3FilterPullbackChaseCount;
   else if(setup.v3FilterFailReason == "v3_momentum_exhausted")
      ++g_thirdWaveV3FilterMomentumExhaustedCount;
  }

void RecordThirdWaveV4Reversal(const ThirdWaveSetup &setup)
  {
   if(!IsEarlyReversalThirdWaveV4Mode())
      return;
   if(!setup.setupPass)
      return;

   ++g_thirdWaveV4ReversalEvaluations;
   if(!setup.lowerTfReversalPass)
     {
      ++g_thirdWaveV4ReversalFailCount;
      ++g_thirdWaveV4UnclearCount;
      return;
     }

   ++g_thirdWaveV4ReversalPassCount;
   if(setup.reversalSignalType == "confirmed_fractal_reclaim" ||
      setup.reversalSignalType == "confirmed_fractal_breakdown")
      ++g_thirdWaveV4ConfirmedFractalCount;
   else if(setup.reversalSignalType == "early_higher_low")
      ++g_thirdWaveV4EarlyHigherLowCount;
   else if(setup.reversalSignalType == "early_lower_high")
      ++g_thirdWaveV4EarlyLowerHighCount;
   else if(setup.reversalSignalType == "momentum_turn")
      ++g_thirdWaveV4MomentumTurnCount;
   else if(setup.reversalSignalType == "candle_reversal")
      ++g_thirdWaveV4CandleReversalCount;
   else if(setup.reversalSignalType == "micro_break")
      ++g_thirdWaveV4MicroBreakCount;
   else
      ++g_thirdWaveV4UnclearCount;

   if(setup.v4ImpulseConsumedBlocked)
      ++g_thirdWaveV4ImpulseConsumedBlockedCount;
  }

void RecordThirdWaveEvaluation(const ThirdWaveSetup &setup)
  {
   ++g_thirdWaveEvaluations;
   if(setup.direction == "LONG")
      ++g_thirdWaveLongEvaluations;
   else if(setup.direction == "SHORT")
      ++g_thirdWaveShortEvaluations;

   RecordThirdWaveStagePasses(setup);
   RecordThirdWaveRegimeState(setup);
   RecordThirdWaveV2Filter(setup);
   RecordThirdWaveV3Filter(setup);
   RecordThirdWaveV4Reversal(setup);

   if(setup.setupPass)
      ++g_thirdWaveSetupPassCount;
   if(setup.entryPass)
      ++g_thirdWaveEntryPassCount;

   RecordThirdWaveStructureFailReason(setup.structureStageFailReason);
   RecordThirdWaveExecutionBlockReason(setup.executionBlockReason);
  }

bool ShouldWriteThirdWaveSignalDiagnostic(const ThirdWaveSetup &setup)
  {
   if(!DiagnosticsVerboseEnabled())
      return false;
   return (setup.lowerTfReversalPass ||
           setup.structureSlPass ||
           setup.rrPass ||
           setup.entryPass ||
           setup.executionBlockReason != "");
  }

void RecordNestedNWaveFailReason(const string reason)
  {
   if(reason == "")
      return;

   if(StringFind(reason, "data_insufficient_") == 0)
      ++g_nestedNWaveDataUnavailableCount;
   else if(reason == "atr_unavailable")
      ++g_nestedNWaveAtrUnavailableCount;
   else if(StringFind(reason, "symbol_research_") == 0 ||
           reason == "disabled_usdjpy_short" ||
           reason == "direction_mode_long_only" ||
           reason == "direction_mode_short_only")
      ++g_nestedNWaveResearchExcludedCount;
   else if(reason == "no_h4_nwave" ||
           reason == "h4_sequence_range_noise" ||
           reason == "h4_impulse_too_small" ||
           reason == "h4_correction_invalid")
      ++g_nestedNWaveNoH4NWaveCount;
   else if(reason == "too_shallow_pullback")
      ++g_nestedNWaveTooShallowPullbackCount;
   else if(reason == "too_deep_pullback")
      ++g_nestedNWaveTooDeepPullbackCount;
   else if(reason == "no_h1_counter_trend_nwave" ||
           reason == "h1_counter_range_noise" ||
           reason == "h1_counter_too_small" ||
           reason == "h1_counter_too_deep")
      ++g_nestedNWaveNoH1CounterTrendCount;
   else if(reason == "h1_counter_nwave_weak")
      ++g_nestedNWaveNoH1CounterTrendCount;
   else if(reason == "no_clear_neckline")
      ++g_nestedNWaveNoClearNecklineCount;
   else if(reason == "no_neckline_break")
      ++g_nestedNWaveNoNecklineBreakCount;
   else if(reason == "no_h1_bos" ||
           reason == "no_m15_bos" ||
           reason == "true_bos_level_unclear")
      ++g_nestedNWaveNoNecklineBreakCount;
   else if(reason == "sl_too_tight")
      ++g_nestedNWaveSlTooTightCount;
   else if(reason == "sl_too_wide")
      ++g_nestedNWaveSlTooWideCount;
   else if(reason == "invalid_structure" ||
           reason == "insufficient_room_to_target")
      ++g_nestedNWaveInvalidStructureCount;
   else if(reason == "spread_guard")
      ++g_nestedNWaveSpreadGuardCount;
   else if(reason == "no_retest_confirmation_break")
      ++g_nestedNWaveNoRetestBreakCount;
   else if(reason == "no_retest_detected")
      ++g_nestedNWaveNoRetestDetectedCount;
   else if(reason == "retest_invalidated")
      ++g_nestedNWaveRetestInvalidatedCount;
   else if(reason == "no_retest_trigger")
      ++g_nestedNWaveNoRetestTriggerCount;
   else if(reason == "dirty_breakout")
      ++g_nestedNWaveDirtyBreakoutFailCount;
   else if(reason == "unclear_breakout_quality")
      ++g_nestedNWaveUnclearBreakoutFailCount;
   else if(reason == "weak_breakout_waiting_retest")
      ++g_nestedNWaveWeakBreakoutWaitingRetestCount;
   else if(reason == "router_retest_requires_weak_breakout")
      ++g_nestedNWaveRouterRetestRequiresWeakCount;
   else if(reason == "context_router_weak_wait_retest" ||
           reason == "context_router_dirty_wait_retest" ||
           reason == "context_router_strong_poor_context_wait_retest" ||
           reason == "context_router_v2_weak_body_too_small")
      ++g_nestedNWaveWeakBreakoutWaitingRetestCount;
   else if(reason == "context_router_dirty_poor_context")
      ++g_nestedNWaveDirtyBreakoutFailCount;
   else if(reason == "context_router_unclear_breakout")
      ++g_nestedNWaveUnclearBreakoutFailCount;
   else if(reason == "context_router_retest_context_block")
      ++g_nestedNWaveRouterRetestRequiresWeakCount;
   else
      ++g_nestedNWaveUnknownFailCount;
  }

void RecordNestedNWaveEvaluation(const NestedNWaveSetup &setup)
  {
   ++g_nestedNWaveEvaluations;
   if(setup.direction == "LONG")
      ++g_nestedNWaveLongEvaluations;
   else if(setup.direction == "SHORT")
      ++g_nestedNWaveShortEvaluations;

   if(setup.h4ImpulsePass)
      ++g_nestedNWaveH4ImpulsePassCount;
   if(setup.h4PullbackZonePass)
      ++g_nestedNWavePullbackZonePassCount;
   if(setup.h1CounterTrendPass)
      ++g_nestedNWaveH1CounterTrendPassCount;
   if(setup.necklinePass)
      ++g_nestedNWaveNecklinePassCount;
   if(setup.structureSlPass)
      ++g_nestedNWaveStructureSlPassCount;
   if(setup.rrPass)
      ++g_nestedNWaveRrPassCount;
   if(setup.spreadGuardPass)
      ++g_nestedNWaveSpreadGuardPassCount;
   if(setup.spreadGuardBlocked)
      ++g_nestedNWaveSpreadGuardBlockedCount;
   if(setup.finalEntryPass)
      ++g_nestedNWaveFinalEntryPassCount;
   if(setup.retestDetected)
      ++g_nestedNWaveRetestDetectedCount;
   if(setup.retestHeld)
      ++g_nestedNWaveRetestHeldCount;
   if(setup.retestTriggerPass)
      ++g_nestedNWaveRetestTriggerPassCount;
   if(setup.breakoutQualityLabel == "strong_breakout")
      ++g_nestedNWaveStrongBreakoutCount;
   else if(setup.breakoutQualityLabel == "weak_breakout")
      ++g_nestedNWaveWeakBreakoutCount;
   else if(setup.breakoutQualityLabel == "dirty_breakout")
      ++g_nestedNWaveDirtyBreakoutCount;
   else if(setup.breakoutQualityLabel == "unclear")
      ++g_nestedNWaveUnclearBreakoutCount;

   if(setup.label == "clean_nested_nwave_entry" ||
      setup.label == "clean_structural_bos" ||
      setup.label == "clean_structural_bos_v2")
      ++g_nestedNWaveCleanEntryCount;
   else if(setup.label == "neckline_break_initial" ||
           setup.label == "m15_bos_confirmed" ||
           setup.label == "h1_bos_confirmed")
      ++g_nestedNWaveInitialBreakCount;
   else if(setup.label == "neckline_break_late" ||
           setup.label == "late_entry")
      ++g_nestedNWaveLateBreakCount;
   else if(setup.label == "chasing_after_break" ||
           setup.label == "chasing_entry")
      ++g_nestedNWaveChasingBreakCount;

   RecordNestedNWaveFailReason(setup.failReason);
  }

bool ShouldWriteNestedNWaveSignalDiagnostic(const NestedNWaveSetup &setup)
  {
   if(!DiagnosticsEntryDetailEnabled())
      return false;
   return (setup.entryPass ||
           setup.finalEntryPass ||
           setup.executionBlockReason != "" ||
           (setup.retestConfirmationMode && setup.setupPass && setup.h1CounterTrendPass && setup.failReason != "") ||
           (setup.breakoutQualityRouterMode && setup.necklinePass && setup.failReason != "") ||
           (setup.structureSlPass && setup.rrPass));
  }

//+------------------------------------------------------------------+
//| Score calculation                                                 |
//+------------------------------------------------------------------+
double TrendScoreForSide(const MqlRates &contextRates[],
                         const MqlRates &patternRates[],
                         const int direction,
                         string &reason)
  {
   double contextFast = AverageClose(contextRates, 1, InpFastMAPeriod);
   double contextSlow = AverageClose(contextRates, 1, InpSlowMAPeriod);
   double contextSlowPast = AverageClose(contextRates, 1 + InpSlopeLookbackBars, InpSlowMAPeriod);
   double patternFast = AverageClose(patternRates, 1, InpFastMAPeriod);
   double patternSlow = AverageClose(patternRates, 1, InpSlowMAPeriod);
   double patternSlowPast = AverageClose(patternRates, 1 + InpSlopeLookbackBars, InpSlowMAPeriod);

   double score = 0.0;
   bool contextAligned = false;
   bool patternAligned = false;

   if(direction > 0)
     {
      contextAligned = (contextFast > contextSlow && contextRates[1].close > contextSlow && contextSlow > contextSlowPast);
      patternAligned = (patternFast > patternSlow && patternRates[1].close > patternSlow && patternSlow > patternSlowPast);
     }
   else
     {
      contextAligned = (contextFast < contextSlow && contextRates[1].close < contextSlow && contextSlow < contextSlowPast);
      patternAligned = (patternFast < patternSlow && patternRates[1].close < patternSlow && patternSlow < patternSlowPast);
     }

   if(contextAligned)
      score += 18.0;
   if(patternAligned)
      score += 14.0;
   if(contextAligned && patternAligned)
      score += 3.0;

   if(score <= 0.0)
      AppendReason(reason, DirectionToString(direction) + "_trend_not_aligned");
   return score;
  }

double SetupScoreForSide(const MqlRates &patternRates[],
                         const MqlRates &executionRates[],
                         const double patternATR,
                         const int direction,
                         string &reason)
  {
   if(patternATR <= 0.0)
      return 0.0;

   double score = 0.0;
   double patternFast = AverageClose(patternRates, 1, InpFastMAPeriod);
   double body = MathAbs(patternRates[1].close - patternRates[1].open);
   double bodyATR = body / patternATR;
   double range = patternRates[1].high - patternRates[1].low;
   double closeLocation = 0.5;
   if(range > 0.0)
      closeLocation = (patternRates[1].close - patternRates[1].low) / range;

   double recentHigh = HighestHigh(patternRates, 2, InpSetupLookbackBars);
   double recentLow = LowestLow(patternRates, 2, InpSetupLookbackBars);

   if(direction > 0)
     {
      if(patternRates[1].low <= patternFast + patternATR * InpPullbackATR && patternRates[1].close > patternFast)
         score += 9.0;
      if(recentHigh > 0.0 && patternRates[1].close > recentHigh)
         score += 9.0;
      if(patternRates[1].close > patternRates[1].open && bodyATR >= InpMinMomentumBodyATR && closeLocation >= 0.62)
         score += 9.0;
      if(executionRates[1].close > executionRates[2].close && executionRates[1].close > AverageClose(executionRates, 1, InpFastMAPeriod))
         score += 8.0;
     }
   else
     {
      if(patternRates[1].high >= patternFast - patternATR * InpPullbackATR && patternRates[1].close < patternFast)
         score += 9.0;
      if(recentLow > 0.0 && patternRates[1].close < recentLow)
         score += 9.0;
      if(patternRates[1].close < patternRates[1].open && bodyATR >= InpMinMomentumBodyATR && closeLocation <= 0.38)
         score += 9.0;
      if(executionRates[1].close < executionRates[2].close && executionRates[1].close < AverageClose(executionRates, 1, InpFastMAPeriod))
         score += 8.0;
     }

   if(score < 12.0)
      AppendReason(reason, DirectionToString(direction) + "_setup_weak");
   return ClampDouble(score, 0.0, 35.0);
  }

double VolatilityScore(const double currentATR, const double averageATR, string &reason)
  {
   if(currentATR <= 0.0 || averageATR <= 0.0)
     {
      AppendReason(reason, "volatility_unavailable");
      return 0.0;
     }

   double ratio = currentATR / averageATR;
   if(ratio >= 0.80 && ratio <= 1.80)
      return 15.0;
   if(ratio >= 0.60 && ratio <= 2.20)
      return 10.0;
   if(ratio >= 0.40 && ratio <= 2.80)
      return 5.0;

   if(ratio < 0.40)
      AppendReason(reason, "volatility_too_low");
   else
      AppendReason(reason, "volatility_too_high");
   return 0.0;
  }

double CostPenalty(const string symbol, const double executionATR, double &spreadATR, string &reason)
  {
   spreadATR = 0.0;
   if(executionATR <= 0.0)
     {
      AppendReason(reason, "cost_unavailable");
      return 25.0;
     }

   spreadATR = SpreadPrice(symbol) / executionATR;
   if(spreadATR > InpMaxSpreadATR)
     {
      AppendReason(reason, "spread_atr_too_wide");
      return 18.0 + ClampDouble((spreadATR - InpMaxSpreadATR) * 80.0, 0.0, 22.0);
     }

   return ClampDouble(spreadATR / MathMax(InpMaxSpreadATR, 0.0001) * 8.0, 0.0, 8.0);
  }

void EvaluateDowFractalStructure(const string symbol,
                                 const MqlRates &contextRates[],
                                 const MqlRates &patternRates[],
                                 const MqlRates &executionRates[],
                                 const int direction,
                                 StructureFilterState &state)
  {
   ResetStructureFilterState(state);

   int span = InpStructureSwingSpan;
   if(span < 1)
      span = 1;

   int scanBars = InpStructureScanBars;
   if(scanBars < span * 4 + 10)
      scanBars = span * 4 + 10;

   PivotPoint contextHighLatest;
   PivotPoint contextHighPrevious;
   PivotPoint contextLowLatest;
   PivotPoint contextLowPrevious;
   PivotPoint patternHighLatest;
   PivotPoint patternHighPrevious;
   PivotPoint patternLowLatest;
   PivotPoint patternLowPrevious;

   bool hasContextHighs = FindRecentPivots(contextRates, true, span, scanBars, contextHighLatest, contextHighPrevious);
   bool hasContextLows = FindRecentPivots(contextRates, false, span, scanBars, contextLowLatest, contextLowPrevious);
   bool hasPatternHighs = FindRecentPivots(patternRates, true, span, scanBars, patternHighLatest, patternHighPrevious);
   bool hasPatternLows = FindRecentPivots(patternRates, false, span, scanBars, patternLowLatest, patternLowPrevious);

   if(hasContextHighs)
     {
      state.higherHigh = (contextHighLatest.price > contextHighPrevious.price);
      state.lowerHigh = (contextHighLatest.price < contextHighPrevious.price);
     }
   if(hasContextLows)
     {
      state.higherLow = (contextLowLatest.price > contextLowPrevious.price);
      state.lowerLow = (contextLowLatest.price < contextLowPrevious.price);
     }

   state.trendUp = (state.higherHigh && state.higherLow);
   state.trendDown = (state.lowerHigh && state.lowerLow);

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      point = 0.0;

   if(direction > 0)
     {
      state.pullbackTooDeep = (hasContextLows && patternRates[1].low <= contextLowPrevious.price);
      state.pullbackValid = (hasContextLows &&
                             hasPatternLows &&
                             !state.pullbackTooDeep &&
                             patternLowLatest.price > contextLowPrevious.price &&
                             patternRates[1].low > contextLowPrevious.price);
      state.fractalConfirmed = hasPatternLows;

      bool m5Rebound = (executionRates[1].close > executionRates[1].open &&
                        executionRates[1].close > executionRates[2].high);
      bool fractalReclaim = false;
      if(hasPatternLows)
        {
         int reclaimBars = patternLowLatest.shift - 2;
         if(reclaimBars > 12)
            reclaimBars = 12;
         if(reclaimBars > 0)
           {
            double reclaimHigh = HighestHigh(patternRates, 2, reclaimBars);
            fractalReclaim = (reclaimHigh > 0.0 && patternRates[1].close > reclaimHigh);
           }
         state.structureStopReference = patternLowLatest.price - point * 2.0;
        }

      state.reclaimConfirmed = (state.fractalConfirmed && (fractalReclaim || m5Rebound));
      state.pass = (state.trendUp && state.pullbackValid && state.fractalConfirmed && state.reclaimConfirmed);

      if(!hasContextHighs || !hasContextLows)
         state.failReason = "no_context_swings";
      else if(!state.trendUp)
         state.failReason = "no_trend_up";
      else if(state.pullbackTooDeep)
         state.failReason = "pullback_too_deep";
      else if(!state.pullbackValid)
         state.failReason = "pullback_not_valid";
      else if(!state.fractalConfirmed)
         state.failReason = "no_fractal_low";
      else if(!state.reclaimConfirmed)
         state.failReason = "no_reclaim";
     }
   else
     {
      state.pullbackTooDeep = (hasContextHighs && patternRates[1].high >= contextHighPrevious.price);
      state.pullbackValid = (hasContextHighs &&
                             hasPatternHighs &&
                             !state.pullbackTooDeep &&
                             patternHighLatest.price < contextHighPrevious.price &&
                             patternRates[1].high < contextHighPrevious.price);
      state.fractalConfirmed = hasPatternHighs;

      bool m5Reject = (executionRates[1].close < executionRates[1].open &&
                       executionRates[1].close < executionRates[2].low);
      bool fractalBreak = false;
      if(hasPatternHighs)
        {
         int reclaimBars = patternHighLatest.shift - 2;
         if(reclaimBars > 12)
            reclaimBars = 12;
         if(reclaimBars > 0)
           {
            double reclaimLow = LowestLow(patternRates, 2, reclaimBars);
            fractalBreak = (reclaimLow > 0.0 && patternRates[1].close < reclaimLow);
           }
         state.structureStopReference = patternHighLatest.price + point * 2.0;
        }

      state.reclaimConfirmed = (state.fractalConfirmed && (fractalBreak || m5Reject));
      state.pass = (state.trendDown && state.pullbackValid && state.fractalConfirmed && state.reclaimConfirmed);

      if(!hasContextHighs || !hasContextLows)
         state.failReason = "no_context_swings";
      else if(!state.trendDown)
         state.failReason = "no_trend_down";
      else if(state.pullbackTooDeep)
         state.failReason = "pullback_too_deep";
      else if(!state.pullbackValid)
         state.failReason = "pullback_not_valid";
      else if(!state.fractalConfirmed)
         state.failReason = "no_fractal_high";
      else if(!state.reclaimConfirmed)
         state.failReason = "no_reclaim";
     }

   if(state.pass)
      state.failReason = "";
   if(!state.pass && state.failReason == "")
      state.failReason = "unknown";
  }

string StructureReasonTokens(const string symbol, const StructureFilterState &state)
  {
   string reason = "";
   if(state.trendUp)
      AppendReason(reason, "trend_up");
   if(state.trendDown)
      AppendReason(reason, "trend_down");
   if(state.higherHigh)
      AppendReason(reason, "higher_high");
   if(state.higherLow)
      AppendReason(reason, "higher_low");
   if(state.lowerHigh)
      AppendReason(reason, "lower_high");
   if(state.lowerLow)
      AppendReason(reason, "lower_low");
   if(state.pullbackValid)
      AppendReason(reason, "pullback_valid");
   if(state.pullbackTooDeep)
      AppendReason(reason, "pullback_too_deep");
   if(state.fractalConfirmed)
      AppendReason(reason, "fractal_confirmed");
   if(state.reclaimConfirmed)
      AppendReason(reason, "reclaim_confirmed");

   if(state.pass)
      AppendReason(reason, "structure_filter_pass");
   else
     {
      AppendReason(reason, "structure_filter_fail_reason");
      AppendReason(reason, "structure_filter_fail_reason_" + state.failReason);
     }

   if(state.structureStopReference > 0.0)
     {
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      AppendReason(reason, "structure_stop_reference_" + DoubleToString(state.structureStopReference, digits));
     }

   return reason;
  }

void RecordStructureEvaluation(const StructureFilterState &state)
  {
   ++g_structureEvaluations;
   if(state.pass)
     {
      ++g_structurePassCount;
      return;
     }

   ++g_structureFailCount;
   if(state.failReason == "no_context_swings")
      ++g_structureNoContextSwingsCount;
   else if(state.failReason == "no_trend_up")
      ++g_structureNoTrendUpCount;
   else if(state.failReason == "no_trend_down")
      ++g_structureNoTrendDownCount;
   else if(state.failReason == "pullback_too_deep")
      ++g_structurePullbackTooDeepCount;
   else if(state.failReason == "pullback_not_valid")
      ++g_structurePullbackNotValidCount;
   else if(state.failReason == "no_fractal_low")
      ++g_structureNoFractalLowCount;
   else if(state.failReason == "no_fractal_high")
      ++g_structureNoFractalHighCount;
   else if(state.failReason == "no_reclaim")
      ++g_structureNoReclaimCount;
   else
      ++g_structureUnknownFailCount;
  }

string TopStructureFailReason(long &count)
  {
   string reason = "";
   count = 0;

   if(g_structureNoContextSwingsCount > count)
     {
      reason = "no_context_swings";
      count = g_structureNoContextSwingsCount;
     }
   if(g_structureNoTrendUpCount > count)
     {
      reason = "no_trend_up";
      count = g_structureNoTrendUpCount;
     }
   if(g_structureNoTrendDownCount > count)
     {
      reason = "no_trend_down";
      count = g_structureNoTrendDownCount;
     }
   if(g_structurePullbackTooDeepCount > count)
     {
      reason = "pullback_too_deep";
      count = g_structurePullbackTooDeepCount;
     }
   if(g_structurePullbackNotValidCount > count)
     {
      reason = "pullback_not_valid";
      count = g_structurePullbackNotValidCount;
     }
   if(g_structureNoFractalLowCount > count)
     {
      reason = "no_fractal_low";
      count = g_structureNoFractalLowCount;
     }
   if(g_structureNoFractalHighCount > count)
     {
      reason = "no_fractal_high";
      count = g_structureNoFractalHighCount;
     }
   if(g_structureNoReclaimCount > count)
     {
      reason = "no_reclaim";
      count = g_structureNoReclaimCount;
     }
   if(g_structureUnknownFailCount > count)
     {
      reason = "unknown";
      count = g_structureUnknownFailCount;
     }

   return reason;
  }

double StructureFilterPenalty(const string symbol,
                              const MqlRates &contextRates[],
                              const MqlRates &patternRates[],
                              const MqlRates &executionRates[],
                              const int direction,
                              string &reason,
                              StructureFilterState &state,
                              bool &structureEvaluated)
  {
   structureEvaluated = false;
   ResetStructureFilterState(state);

   if(!InpUseDowFractalStructureFilter)
      return 0.0;

   EvaluateDowFractalStructure(symbol, contextRates, patternRates, executionRates, direction, state);
   structureEvaluated = true;
   RecordStructureEvaluation(state);
   AppendReason(reason, StructureReasonTokens(symbol, state));

   if(!state.pass)
      return 100.0;
   return 0.0;
  }

void ComputeTradeLevels(SymbolScore &score, const int direction)
  {
   score.stopDistance = ClampDouble(score.atr * InpStopATRMultiplier,
                                    score.atr * InpMinSL_ATR,
                                    score.atr * InpMaxSL_ATR);
   score.volume = CalculatePositionSize(score.symbol, score.stopDistance);

   int digits = (int)SymbolInfoInteger(score.symbol, SYMBOL_DIGITS);
   double ask = SymbolInfoDouble(score.symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(score.symbol, SYMBOL_BID);
   double entry = (direction > 0 ? ask : bid);

   if(entry <= 0.0)
      return;

   if(direction > 0)
     {
      score.stopLoss = NormalizeDouble(entry - score.stopDistance, digits);
      score.takeProfit = NormalizeDouble(entry + score.stopDistance * InpRewardR, digits);
     }
   else
     {
      score.stopLoss = NormalizeDouble(entry + score.stopDistance, digits);
      score.takeProfit = NormalizeDouble(entry - score.stopDistance * InpRewardR, digits);
     }
  }

void ScoreSide(const string symbol,
               const MqlRates &contextRates[],
               const MqlRates &patternRates[],
               const MqlRates &executionRates[],
               const double patternATR,
               const double averagePatternATR,
               const double executionATR,
               const int direction,
               SymbolScore &score)
  {
   string reason = "";
   double trend = TrendScoreForSide(contextRates, patternRates, direction, reason);
   double setup = SetupScoreForSide(patternRates, executionRates, patternATR, direction, reason);
   double volatility = VolatilityScore(patternATR, averagePatternATR, reason);
   double spreadATR = 0.0;
   double cost = CostPenalty(symbol, executionATR, spreadATR, reason);
   double risk = RiskPenalty(symbol, reason);
   StructureFilterState structureState;
   bool structureEvaluated = false;
   risk += StructureFilterPenalty(symbol, contextRates, patternRates, executionRates, direction, reason, structureState, structureEvaluated);

   score.symbol = symbol;
   score.direction = DirectionToString(direction);
   score.trendScore = trend;
   score.setupScore = setup;
   score.volatilityScore = volatility;
   score.costPenalty = cost;
   score.riskPenalty = risk;
   score.totalScore = trend + setup + volatility - cost - risk;
   score.atr = patternATR;
   score.spreadATR = spreadATR;
   score.dataReady = true;
   score.structureEvaluated = structureEvaluated;
   score.structureState = structureState;
   score.reason = reason;
   ComputeTradeLevels(score, direction);
  }

void InitScore(SymbolScore &score, const string symbol)
  {
   score.symbol = symbol;
   score.direction = "NONE";
   score.totalScore = 0.0;
   score.trendScore = 0.0;
   score.setupScore = 0.0;
   score.volatilityScore = 0.0;
   score.costPenalty = 0.0;
   score.riskPenalty = 0.0;
   score.atr = 0.0;
   score.spreadATR = 0.0;
   score.stopDistance = 0.0;
   score.stopLoss = 0.0;
   score.takeProfit = 0.0;
   score.volume = 0.0;
   score.dataReady = false;
   score.structureEvaluated = false;
   ResetStructureFilterState(score.structureState);
   score.reason = "";
  }

bool EvaluateSymbolDirectionalScores(const string symbol,
                                     SymbolScore &longScore,
                                     bool &longReady,
                                     SymbolScore &shortScore,
                                     bool &shortReady,
                                     string &failureReason)
  {
   InitScore(longScore, symbol);
   InitScore(shortScore, symbol);
   longReady = false;
   shortReady = false;
   failureReason = "";

   string researchReason = "";
   if(!IsSymbolAllowedByResearchMode(symbol, researchReason))
     {
      failureReason = researchReason;
      return false;
     }

   MqlRates contextRates[];
   MqlRates patternRates[];
   MqlRates executionRates[];
   string reason = "";
   int barsNeeded = RequiredBars();

   if(!LoadRates(symbol, InpContextTF, barsNeeded, contextRates, reason))
     {
      failureReason = reason;
      PrintFormat("%s: %s skipped: %s", STRATEGY_NAME, symbol, reason);
      return false;
     }
   if(!LoadRates(symbol, InpPatternTF, barsNeeded, patternRates, reason))
     {
      failureReason = reason;
      PrintFormat("%s: %s skipped: %s", STRATEGY_NAME, symbol, reason);
      return false;
     }
   if(!LoadRates(symbol, InpExecutionTF, barsNeeded, executionRates, reason))
     {
      failureReason = reason;
      PrintFormat("%s: %s skipped: %s", STRATEGY_NAME, symbol, reason);
      return false;
     }

   double patternATR = AverageATR(patternRates, 1, InpATRPeriod);
   double averagePatternATR = AverageATR(patternRates, 1, InpATRAveragePeriod);
   double executionATR = AverageATR(executionRates, 1, InpATRPeriod);
   if(patternATR <= 0.0 || averagePatternATR <= 0.0 || executionATR <= 0.0)
     {
      failureReason = "atr_unavailable";
      return false;
     }

   string longBlockReason = "";
   string shortBlockReason = "";
   bool allowLong = IsDirectionAllowedByResearchMode(symbol, 1, longBlockReason);
   bool allowShort = IsDirectionAllowedByResearchMode(symbol, -1, shortBlockReason);

   if(!allowLong && !allowShort)
     {
      AppendReason(failureReason, longBlockReason);
      AppendReason(failureReason, shortBlockReason);
      return false;
     }

   if(allowLong)
     {
      ScoreSide(symbol, contextRates, patternRates, executionRates, patternATR, averagePatternATR, executionATR, 1, longScore);
      AppendReason(longScore.reason, shortBlockReason);
      if(longScore.totalScore < InpEntryScoreThreshold)
         AppendReason(longScore.reason, "below_threshold");
      else
         AppendReason(longScore.reason, "entry_score_ok");
      longReady = true;
     }

   if(allowShort)
     {
      ScoreSide(symbol, contextRates, patternRates, executionRates, patternATR, averagePatternATR, executionATR, -1, shortScore);
      AppendReason(shortScore.reason, longBlockReason);
      if(shortScore.totalScore < InpEntryScoreThreshold)
         AppendReason(shortScore.reason, "below_threshold");
      else
         AppendReason(shortScore.reason, "entry_score_ok");
      shortReady = true;
     }

   return (longReady || shortReady);
  }

bool EvaluateSymbol(const string symbol, SymbolScore &bestScore)
  {
   InitScore(bestScore, symbol);

   SymbolScore longScore;
   SymbolScore shortScore;
   bool longReady = false;
   bool shortReady = false;
   string failureReason = "";

   if(!EvaluateSymbolDirectionalScores(symbol, longScore, longReady, shortScore, shortReady, failureReason))
     {
      bestScore.reason = failureReason;
      return false;
     }

   if(longReady && shortReady)
      bestScore = (longScore.totalScore >= shortScore.totalScore ? longScore : shortScore);
   else if(longReady)
      bestScore = longScore;
   else
      bestScore = shortScore;

   return true;
  }

//+------------------------------------------------------------------+
//| CSV logging                                                       |
//+------------------------------------------------------------------+
string DailyLogFileName()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return StringFormat("%s\\%s_%04d%02d%02d.csv",
                       InpLogFolder,
                       InpLogPrefix,
                       tm.year,
                       tm.mon,
                       tm.day);
  }

string DailyScanLogFileName()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return StringFormat("%s\\%s_scan_%04d%02d%02d.csv",
                       InpLogFolder,
                       InpLogPrefix,
                       tm.year,
                       tm.mon,
                       tm.day);
  }

string DailyStructureLogFileName()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return StringFormat("%s\\%s_structure_%04d%02d%02d.csv",
                       InpLogFolder,
                       InpLogPrefix,
                       tm.year,
                       tm.mon,
                       tm.day);
  }

string DailyStructureSummaryLogFileName()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return StringFormat("%s\\%s_structure_summary_%04d%02d%02d.csv",
                       InpLogFolder,
                       InpLogPrefix,
                       tm.year,
                       tm.mon,
                       tm.day);
  }

string DailyThirdWaveSignalLogFileName()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return StringFormat("%s\\thirdwave_signal_diagnostics_%04d%02d%02d.csv",
                       InpLogFolder,
                       tm.year,
                       tm.mon,
                       tm.day);
  }

string DailyThirdWaveTradeLogFileName()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return StringFormat("%s\\thirdwave_trade_diagnostics_%04d%02d%02d.csv",
                       InpLogFolder,
                       tm.year,
                       tm.mon,
                       tm.day);
  }

string DailyThirdWaveWaveAuditLogFileName()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return StringFormat("%s\\thirdwave_wave_audit_%04d%02d%02d.csv",
                       InpLogFolder,
                       tm.year,
                       tm.mon,
                       tm.day);
  }

string DailyThirdWaveSummaryLogFileName()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return StringFormat("%s\\thirdwave_summary_%04d%02d%02d.csv",
                       InpLogFolder,
                       tm.year,
                       tm.mon,
                       tm.day);
  }

string DailyNestedNWaveSignalLogFileName()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return StringFormat("%s\\nested_nwave_signal_diagnostics_%04d%02d%02d.csv",
                       InpLogFolder,
                       tm.year,
                       tm.mon,
                       tm.day);
  }

string DailyNestedNWaveTradeLogFileName()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return StringFormat("%s\\nested_nwave_trade_diagnostics_%04d%02d%02d.csv",
                       InpLogFolder,
                       tm.year,
                       tm.mon,
                       tm.day);
  }

string DailyNestedNWaveSummaryLogFileName()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return StringFormat("%s\\nested_nwave_summary_%04d%02d%02d.csv",
                       InpLogFolder,
                       tm.year,
                       tm.mon,
                       tm.day);
  }

void EnsureLogFolder()
  {
   int flags = 0;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;
   FolderCreate(InpLogFolder, flags);
  }

void WriteScanDiagnosticRow(const string eventName,
                            const datetime lastScanBarTime,
                            const uint elapsedMs,
                            const string reason)
  {
   EnsureLogFolder();

   int flags = FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;

   string fileName = DailyScanLogFileName();
   int handle = FileOpen(fileName, flags, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s: FileOpen failed: %s err=%d", STRATEGY_NAME, fileName, GetLastError());
      return;
     }

   bool needsHeader = (FileSize(handle) == 0);
   FileSeek(handle, 0, SEEK_END);
   if(needsHeader)
      FileWrite(handle,
                "time",
                "event",
                "scan_driver_symbol",
                "last_scan_bar_time",
                "scan_elapsed_ms",
                "reason");

   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             eventName,
             _Symbol,
             DateTimeText(lastScanBarTime),
             IntegerToString((int)elapsedMs),
             reason);

   FileClose(handle);
  }

void WriteStructureFilterRow(const string symbol, const string direction, const StructureFilterState &state)
  {
   if(!DiagnosticsEntryDetailEnabled())
      return;

   ++g_structureDetailRows;
   EnsureLogFolder();

   int flags = FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;

   string fileName = DailyStructureLogFileName();
   int handle = FileOpen(fileName, flags, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s: FileOpen failed: %s err=%d", STRATEGY_NAME, fileName, GetLastError());
      return;
     }

   bool needsHeader = (FileSize(handle) == 0);
   FileSeek(handle, 0, SEEK_END);
   if(needsHeader)
      FileWrite(handle,
                "time",
                "symbol",
                "direction",
                "trend_up",
                "trend_down",
                "higher_high",
                "higher_low",
                "lower_high",
                "lower_low",
                "pullback_valid",
                "pullback_too_deep",
                "fractal_confirmed",
                "reclaim_confirmed",
                "structure_filter_pass",
                "structure_filter_fail_reason",
                "structure_stop_reference");

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             symbol,
             direction,
             BoolText(state.trendUp),
             BoolText(state.trendDown),
             BoolText(state.higherHigh),
             BoolText(state.higherLow),
             BoolText(state.lowerHigh),
             BoolText(state.lowerLow),
             BoolText(state.pullbackValid),
             BoolText(state.pullbackTooDeep),
             BoolText(state.fractalConfirmed),
             BoolText(state.reclaimConfirmed),
             BoolText(state.pass),
             state.failReason,
             DoubleToString(state.structureStopReference, digits));

   FileClose(handle);
  }

void WriteStructureSummaryRow()
  {
   if(!DiagnosticsSummaryEnabled())
      return;

   EnsureLogFolder();

   int flags = FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;

   string fileName = DailyStructureSummaryLogFileName();
   int handle = FileOpen(fileName, flags, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s: FileOpen failed: %s err=%d", STRATEGY_NAME, fileName, GetLastError());
      return;
     }

   bool needsHeader = (FileSize(handle) == 0);
   FileSeek(handle, 0, SEEK_END);
   if(needsHeader)
      FileWrite(handle,
                "time",
                "structure_evaluations",
                "structure_detail_rows",
                "structure_pass",
                "structure_fail",
                "structure_pass_rate",
                "no_context_swings",
                "no_trend_up",
                "no_trend_down",
                "pullback_too_deep",
                "pullback_not_valid",
                "no_fractal_low",
                "no_fractal_high",
                "not_enough_fractals",
                "no_reclaim",
                "unknown",
                "structure_top_fail_reason",
                "structure_top_fail_reason_rows");

   long topFailCount = 0;
   string topFailReason = TopStructureFailReason(topFailCount);
   long notEnoughFractals = g_structureNoContextSwingsCount + g_structureNoFractalLowCount + g_structureNoFractalHighCount;
   double passRate = 0.0;
   if(g_structureEvaluations > 0)
      passRate = (double)g_structurePassCount / (double)g_structureEvaluations * 100.0;

   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             g_structureEvaluations,
             g_structureDetailRows,
             g_structurePassCount,
             g_structureFailCount,
             DoubleToString(passRate, 2),
             g_structureNoContextSwingsCount,
             g_structureNoTrendUpCount,
             g_structureNoTrendDownCount,
             g_structurePullbackTooDeepCount,
             g_structurePullbackNotValidCount,
             g_structureNoFractalLowCount,
             g_structureNoFractalHighCount,
             notEnoughFractals,
             g_structureNoReclaimCount,
             g_structureUnknownFailCount,
             topFailReason,
             topFailCount);

   FileClose(handle);
  }

void WriteScoreRow(const SymbolScore &score, const string reason)
  {
   if(!DiagnosticsEntryDetailEnabled())
      return;

   EnsureLogFolder();

   int flags = FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;

   string fileName = DailyLogFileName();
   int handle = FileOpen(fileName, flags, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s: FileOpen failed: %s err=%d", STRATEGY_NAME, fileName, GetLastError());
      return;
     }

   bool needsHeader = (FileSize(handle) == 0);
   FileSeek(handle, 0, SEEK_END);
   if(needsHeader)
      FileWrite(handle,
                "time",
                "symbol",
                "direction",
                "totalScore",
                "trendScore",
                "setupScore",
                "volatilityScore",
                "costPenalty",
                "riskPenalty",
                "reason");

   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             score.symbol,
             score.direction,
             DoubleToString(score.totalScore, 2),
             DoubleToString(score.trendScore, 2),
             DoubleToString(score.setupScore, 2),
             DoubleToString(score.volatilityScore, 2),
             DoubleToString(score.costPenalty, 2),
             DoubleToString(score.riskPenalty, 2),
             reason);

   FileClose(handle);
  }

void WriteThirdWaveSignalRow(const ThirdWaveSetup &setup)
  {
   if(!DiagnosticsEntryDetailEnabled())
      return;

   EnsureLogFolder();

   int flags = FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;

   string fileName = DailyThirdWaveSignalLogFileName();
   int handle = FileOpen(fileName, flags, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s: FileOpen failed: %s err=%d", STRATEGY_NAME, fileName, GetLastError());
      return;
     }

   bool needsHeader = (FileSize(handle) == 0);
   FileSeek(handle, 0, SEEK_END);
   if(needsHeader)
      FileWrite(handle,
                "time",
                "symbol",
                "direction",
                "higher_tf_trend",
                "mid_tf_pullback_status",
                "lower_tf_reversal_status",
                "regime",
                "regime_reason",
                "higher_tf_swing_state",
                "ema_slope",
                "trend_strength",
                "volatility_state",
                "entry_allowed_by_regime",
                "blocked_by_regime_reason",
                "lower_reversal_quality",
                "pullback_depth_atr",
                "sl_atr",
                "setup_pass",
                "entry_pass",
                "final_entry_pass",
                "skip_reason",
                "structure_stage_fail_reason",
                "execution_block_reason",
                "higher_tf_trend_pass",
                "mid_tf_pullback_pass",
                "lower_tf_reversal_pass",
                "structure_sl_pass",
                "rr_pass",
                "v2_filter_pass",
                "v2_filter_fail_reason",
                "v3_filter_pass",
                "v3_filter_fail_reason",
                "v3_momentum_exhaustion_score",
                "v3_momentum_exhausted",
                "v3_recent_move_atr",
                "v3_consecutive_directional_bars",
                "v3_close_to_recent_extreme_atr",
                "reversal_signal_type",
                "v4_block_reason",
                "bars_since_pullback_extreme",
                "bars_since_reversal_signal",
                "distance_from_reversal_signal_to_entry_atr",
                "impulse_consumed_pct",
                "pre_entry_momentum_score",
                "reversal_strength_score",
                "spread_atr",
                "max_spread_atr",
                "spread_guard_pass",
                "spread_guard_blocked",
                "spread_points",
                "atr_value",
                "entry_price",
                "sl",
                "tp",
                "risk_r",
                "rr",
                "swing_high",
                "swing_low",
                "structure_sl_source",
                "strategy_name");

   int digits = (int)SymbolInfoInteger(setup.symbol, SYMBOL_DIGITS);
   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             setup.symbol,
             setup.direction,
             setup.higherTfTrend,
             setup.midTfPullbackStatus,
             setup.lowerTfReversalStatus,
             setup.regime,
             setup.regimeReason,
             setup.higherTfSwingState,
             DoubleToString(setup.emaSlope, digits),
             DoubleToString(setup.trendStrength, 4),
             setup.volatilityState,
             BoolText(setup.entryAllowedByRegime),
             setup.blockedByRegimeReason,
             DoubleToString(setup.lowerReversalQuality, 2),
             DoubleToString(setup.pullbackDepthATR, 2),
             DoubleToString(setup.slATR, 2),
             BoolText(setup.setupPass),
             BoolText(setup.entryPass),
             BoolText(setup.finalEntryPass),
             setup.skipReason,
             setup.structureStageFailReason,
             setup.executionBlockReason,
             BoolText(setup.higherTfTrendPass),
             BoolText(setup.midTfPullbackPass),
             BoolText(setup.lowerTfReversalPass),
             BoolText(setup.structureSlPass),
             BoolText(setup.rrPass),
             BoolText(setup.v2FilterPass),
             setup.v2FilterFailReason,
             BoolText(setup.v3FilterPass),
             setup.v3FilterFailReason,
             DoubleToString(setup.v3MomentumExhaustionScore, 2),
             BoolText(setup.v3MomentumExhausted),
             DoubleToString(setup.v3RecentMoveATR, 2),
             IntegerToString(setup.v3ConsecutiveDirectionalBars),
             DoubleToString(setup.v3CloseToRecentExtremeATR, 2),
             setup.reversalSignalType,
             setup.v4BlockReason,
             IntegerToString(setup.barsSincePullbackExtreme),
             IntegerToString(setup.barsSinceReversalSignal),
             DoubleToString(setup.distanceReversalSignalToEntryATR, 2),
             DoubleToString(setup.impulseConsumedPct, 2),
             DoubleToString(setup.preEntryMomentumScore, 2),
             DoubleToString(setup.reversalStrengthScore, 2),
             DoubleToString(setup.spreadATR, 4),
             DoubleToString(setup.maxSpreadATR, 4),
             BoolText(setup.spreadGuardPass),
             BoolText(setup.spreadGuardBlocked),
             DoubleToString(setup.spreadPoints, 1),
             DoubleToString(setup.atrValue, digits),
             DoubleToString(setup.entryPrice, digits),
             DoubleToString(setup.stopLoss, digits),
             DoubleToString(setup.takeProfit, digits),
             DoubleToString(setup.riskR, digits),
             DoubleToString(setup.rr, 2),
             DoubleToString(setup.swingHigh, digits),
             DoubleToString(setup.swingLow, digits),
             setup.structureSlSource,
             ThirdWaveStrategyName());

   FileClose(handle);
  }

void WriteThirdWaveTradeRow(const ThirdWaveSetup &setup,
                            const string eventName,
                            const string resultReason,
                            const long retcode)
  {
   if(!DiagnosticsEntryDetailEnabled())
      return;

   EnsureLogFolder();

   int flags = FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;

   string fileName = DailyThirdWaveTradeLogFileName();
   int handle = FileOpen(fileName, flags, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s: FileOpen failed: %s err=%d", STRATEGY_NAME, fileName, GetLastError());
      return;
     }

   bool needsHeader = (FileSize(handle) == 0);
   FileSeek(handle, 0, SEEK_END);
   if(needsHeader)
      FileWrite(handle,
                "time",
                "symbol",
                "direction",
                "event",
                "regime",
                "regime_reason",
                "higher_tf_swing_state",
                "ema_slope",
                "trend_strength",
                "volatility_state",
                "entry_allowed_by_regime",
                "blocked_by_regime_reason",
                "lower_reversal_quality",
                "pullback_depth_atr",
                "sl_atr",
                "order_retcode",
                "order_comment",
                "entry_price",
                "sl",
                "tp",
                "volume",
                "risk_r",
                "rr",
                "skip_reason",
                "structure_stage_fail_reason",
                "execution_block_reason",
                "v2_filter_pass",
                "v2_filter_fail_reason",
                "v3_filter_pass",
                "v3_filter_fail_reason",
                "v3_momentum_exhaustion_score",
                "v3_momentum_exhausted",
                "v3_recent_move_atr",
                "v3_consecutive_directional_bars",
                "v3_close_to_recent_extreme_atr",
                "reversal_signal_type",
                "v4_block_reason",
                "bars_since_pullback_extreme",
                "bars_since_reversal_signal",
                "distance_from_reversal_signal_to_entry_atr",
                "impulse_consumed_pct",
                "pre_entry_momentum_score",
                "reversal_strength_score",
                "spread_atr",
                "max_spread_atr",
                "spread_guard_pass",
                "spread_guard_blocked",
                "spread_points",
                "atr_value",
                "strategy_name");

   int digits = (int)SymbolInfoInteger(setup.symbol, SYMBOL_DIGITS);
   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             setup.symbol,
             setup.direction,
             eventName,
             setup.regime,
             setup.regimeReason,
             setup.higherTfSwingState,
             DoubleToString(setup.emaSlope, digits),
             DoubleToString(setup.trendStrength, 4),
             setup.volatilityState,
             BoolText(setup.entryAllowedByRegime),
             setup.blockedByRegimeReason,
             DoubleToString(setup.lowerReversalQuality, 2),
             DoubleToString(setup.pullbackDepthATR, 2),
             DoubleToString(setup.slATR, 2),
             IntegerToString((int)retcode),
             resultReason,
             DoubleToString(setup.entryPrice, digits),
             DoubleToString(setup.stopLoss, digits),
             DoubleToString(setup.takeProfit, digits),
             DoubleToString(setup.volume, 2),
             DoubleToString(setup.riskR, digits),
             DoubleToString(setup.rr, 2),
             setup.skipReason,
             setup.structureStageFailReason,
             setup.executionBlockReason,
             BoolText(setup.v2FilterPass),
             setup.v2FilterFailReason,
             BoolText(setup.v3FilterPass),
             setup.v3FilterFailReason,
             DoubleToString(setup.v3MomentumExhaustionScore, 2),
             BoolText(setup.v3MomentumExhausted),
             DoubleToString(setup.v3RecentMoveATR, 2),
             IntegerToString(setup.v3ConsecutiveDirectionalBars),
             DoubleToString(setup.v3CloseToRecentExtremeATR, 2),
             setup.reversalSignalType,
             setup.v4BlockReason,
             IntegerToString(setup.barsSincePullbackExtreme),
             IntegerToString(setup.barsSinceReversalSignal),
             DoubleToString(setup.distanceReversalSignalToEntryATR, 2),
             DoubleToString(setup.impulseConsumedPct, 2),
             DoubleToString(setup.preEntryMomentumScore, 2),
             DoubleToString(setup.reversalStrengthScore, 2),
             DoubleToString(setup.spreadATR, 4),
             DoubleToString(setup.maxSpreadATR, 4),
             BoolText(setup.spreadGuardPass),
             BoolText(setup.spreadGuardBlocked),
             DoubleToString(setup.spreadPoints, 1),
             DoubleToString(setup.atrValue, digits),
             ThirdWaveStrategyName());

   FileClose(handle);
  }

void WriteThirdWaveWaveAuditRow(const ThirdWaveSetup &setup, const string eventName)
  {
   if(!DiagnosticsEntryDetailEnabled())
      return;
   if(!IsThirdWaveStrategyMode())
      return;

   EnsureLogFolder();

   int flags = FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;

   string fileName = DailyThirdWaveWaveAuditLogFileName();
   int handle = FileOpen(fileName, flags, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s: FileOpen failed: %s err=%d", STRATEGY_NAME, fileName, GetLastError());
      return;
     }

   bool needsHeader = (FileSize(handle) == 0);
   FileSeek(handle, 0, SEEK_END);
   if(needsHeader)
      FileWriteString(handle,
                      "time,event,symbol,direction,entry_price,sl,tp,mid_tf_structure_sl,lower_tf_reversal_sl,mid_tf_structure_sl_atr,lower_tf_reversal_sl_atr,lower_tf_reversal_sl_status,result_R,profit,regime,session,scan_interval,entry_selection_mode,v4_signal_mode,thirdwave_sl_mode,v4_signal_mode_pass,v4_signal_mode_blocked,"
                      "higher_tf,higher_swing_low_1,higher_swing_high_1,higher_swing_low_2,higher_swing_high_2,higher_structure_state,higher_trend_age_bars,higher_ema_slope,higher_atr,"
                      "mid_tf,impulse_start_price,impulse_end_price,pullback_extreme_price,pullback_depth_pct,pullback_depth_atr,pullback_bars,pullback_broke_origin,pullback_structure_low_or_high,"
                      "distance_from_pullback_extreme_to_entry_atr,distance_from_pullback_extreme_to_entry_pct_of_impulse,"
                      "lower_tf,minor_reversal_level,reclaim_or_breakdown_price,bars_since_reclaim_or_breakdown,entry_distance_from_reclaim_atr,entry_distance_from_reclaim_points,"
                      "lower_reversal_quality,lower_reversal_quality_score,sl_atr,risk_r,rr,spread_atr,structure_stage_fail_reason,execution_block_reason,"
                      "v2_filter_pass,v2_filter_fail_reason,v3_filter_pass,v3_filter_fail_reason,v3_momentum_exhaustion_score,v3_momentum_exhausted,v3_recent_move_atr,v3_consecutive_directional_bars,v3_close_to_recent_extreme_atr,"
                      "reversal_signal_type,v4_block_reason,bars_since_pullback_extreme,bars_since_reversal_signal,distance_from_reversal_signal_to_entry_atr,impulse_consumed_pct,pre_entry_momentum_score,reversal_strength_score,"
                      "wave_audit_label,wave_audit_reason,strategy_name\r\n");

   int digits = (int)SymbolInfoInteger(setup.symbol, SYMBOL_DIGITS);
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   string session = "server_16_23";
   if(tm.hour < 8)
      session = "server_00_07";
   else if(tm.hour < 16)
      session = "server_08_15";

   string row = "";
   AppendCsvField(row, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
   AppendCsvField(row, eventName);
   AppendCsvField(row, setup.symbol);
   AppendCsvField(row, setup.direction);
   AppendCsvField(row, DoubleToString(setup.entryPrice, digits));
   AppendCsvField(row, DoubleToString(setup.stopLoss, digits));
   AppendCsvField(row, DoubleToString(setup.takeProfit, digits));
   AppendCsvField(row, DoubleToString(setup.midTfStructureSL, digits));
   AppendCsvField(row, DoubleToString(setup.lowerTfReversalSL, digits));
   AppendCsvField(row, DoubleToString(setup.midTfStructureSLATR, 2));
   AppendCsvField(row, DoubleToString(setup.lowerTfReversalSLATR, 2));
   AppendCsvField(row, setup.lowerTfReversalSLStatus);
   AppendCsvField(row, "");
   AppendCsvField(row, "");
   AppendCsvField(row, setup.regime);
   AppendCsvField(row, session);
   AppendCsvField(row, IntegerToString(InpScanSeconds));
   AppendCsvField(row, EntrySelectionModeName());
   AppendCsvField(row, setup.v4SignalModeName);
   AppendCsvField(row, ThirdWaveSLModeName());
   AppendCsvField(row, BoolText(setup.v4SignalModePass));
   AppendCsvField(row, BoolText(setup.v4SignalModeBlocked));
   AppendCsvField(row, TimeframeText(InpContextTF));
   AppendCsvField(row, DoubleToString(setup.higherSwingLow1, digits));
   AppendCsvField(row, DoubleToString(setup.higherSwingHigh1, digits));
   AppendCsvField(row, DoubleToString(setup.higherSwingLow2, digits));
   AppendCsvField(row, DoubleToString(setup.higherSwingHigh2, digits));
   AppendCsvField(row, WaveAuditStructureState(setup));
   AppendCsvField(row, IntegerToString(setup.higherTrendAgeBars));
   AppendCsvField(row, DoubleToString(setup.emaSlope, digits));
   AppendCsvField(row, DoubleToString(setup.higherAtr, digits));
   AppendCsvField(row, TimeframeText(InpPatternTF));
   AppendCsvField(row, DoubleToString(setup.impulseStartPrice, digits));
   AppendCsvField(row, DoubleToString(setup.impulseEndPrice, digits));
   AppendCsvField(row, DoubleToString(setup.pullbackExtremePrice, digits));
   AppendCsvField(row, DoubleToString(setup.pullbackDepthPct, 2));
   AppendCsvField(row, DoubleToString(setup.pullbackDepthATR, 2));
   AppendCsvField(row, IntegerToString(setup.pullbackBars));
   AppendCsvField(row, BoolText(setup.pullbackBrokeOrigin));
   AppendCsvField(row, DoubleToString(setup.pullbackStructureLevel, digits));
   AppendCsvField(row, DoubleToString(setup.distancePullbackExtremeToEntryATR, 2));
   AppendCsvField(row, DoubleToString(setup.distancePullbackExtremeToEntryPct, 2));
   AppendCsvField(row, TimeframeText(InpExecutionTF));
   AppendCsvField(row, DoubleToString(setup.minorReversalLevel, digits));
   AppendCsvField(row, DoubleToString(setup.reclaimOrBreakdownPrice, digits));
   AppendCsvField(row, IntegerToString(setup.barsSinceReclaimOrBreakdown));
   AppendCsvField(row, DoubleToString(setup.entryDistanceFromReclaimATR, 2));
   AppendCsvField(row, DoubleToString(setup.entryDistanceFromReclaimPoints, 1));
   AppendCsvField(row, setup.lowerReversalQualityLabel);
   AppendCsvField(row, DoubleToString(setup.lowerReversalQuality, 2));
   AppendCsvField(row, DoubleToString(setup.slATR, 2));
   AppendCsvField(row, DoubleToString(setup.riskR, digits));
   AppendCsvField(row, DoubleToString(setup.rr, 2));
   AppendCsvField(row, DoubleToString(setup.spreadATR, 4));
   AppendCsvField(row, setup.structureStageFailReason);
   AppendCsvField(row, setup.executionBlockReason);
   AppendCsvField(row, BoolText(setup.v2FilterPass));
   AppendCsvField(row, setup.v2FilterFailReason);
   AppendCsvField(row, BoolText(setup.v3FilterPass));
   AppendCsvField(row, setup.v3FilterFailReason);
   AppendCsvField(row, DoubleToString(setup.v3MomentumExhaustionScore, 2));
   AppendCsvField(row, BoolText(setup.v3MomentumExhausted));
   AppendCsvField(row, DoubleToString(setup.v3RecentMoveATR, 2));
   AppendCsvField(row, IntegerToString(setup.v3ConsecutiveDirectionalBars));
   AppendCsvField(row, DoubleToString(setup.v3CloseToRecentExtremeATR, 2));
   AppendCsvField(row, setup.reversalSignalType);
   AppendCsvField(row, setup.v4BlockReason);
   AppendCsvField(row, IntegerToString(setup.barsSincePullbackExtreme));
   AppendCsvField(row, IntegerToString(setup.barsSinceReversalSignal));
   AppendCsvField(row, DoubleToString(setup.distanceReversalSignalToEntryATR, 2));
   AppendCsvField(row, DoubleToString(setup.impulseConsumedPct, 2));
   AppendCsvField(row, DoubleToString(setup.preEntryMomentumScore, 2));
   AppendCsvField(row, DoubleToString(setup.reversalStrengthScore, 2));
   AppendCsvField(row, setup.waveAuditLabel);
   AppendCsvField(row, setup.waveAuditReason);
   AppendCsvField(row, ThirdWaveStrategyName());
   FileWriteString(handle, row + "\r\n");

   FileClose(handle);
  }

void WriteNestedNWaveSignalRow(const NestedNWaveSetup &setup, const string eventName)
  {
   if(!DiagnosticsEntryDetailEnabled())
      return;
   if(!IsNestedNWaveStrategyMode())
      return;

   EnsureLogFolder();

   int flags = FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;

   string fileName = DailyNestedNWaveSignalLogFileName();
   int handle = FileOpen(fileName, flags, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s: FileOpen failed: %s err=%d", STRATEGY_NAME, fileName, GetLastError());
      return;
     }

   bool needsHeader = (FileSize(handle) == 0);
   FileSeek(handle, 0, SEEK_END);
   if(needsHeader)
      FileWriteString(handle,
                      "time,event,symbol,direction,session,entry_selection_mode,scan_interval,strategy_name,"
                      "label,fail_reason,execution_block_reason,fib_zone,h4_trend_state,h1_counter_trend_state,neckline_break_label,"
                      "h4_impulse_pass,h4_pullback_zone_pass,h1_counter_trend_pass,neckline_pass,structure_sl_pass,rr_pass,spread_guard_pass,spread_guard_blocked,setup_pass,entry_pass,final_entry_pass,"
                      "h4_impulse_high,h4_impulse_low,h4_fib_retracement_pct,h4_atr,h1_atr,m15_atr,spread_atr,spread_points,"
                      "neckline_price,neckline_break_close_price,right_side_level,entry_price,sl,tp,volume,risk_r,rr,"
                      "bars_since_right_side,distance_neckline_to_entry,distance_neckline_to_entry_atr,distance_right_side_to_entry,distance_right_side_to_entry_atr,"
                      "sl_points,sl_atr,tp_points,tp_atr,quality_score,"
                      "retest_confirmation_mode,retest_detected,retest_held,retest_trigger_pass,retest_failed,"
                      "original_neckline_break_time,retest_detected_time,retest_trigger_time,retest_bars_after_breakout,entry_delay_bars,"
                      "retest_depth_atr,retest_zone_atr,retest_reclaim_price,retest_distance_from_neckline_atr,false_break_return_inside_neckline,retest_quality,retest_failure_reason,"
                      "breakout_quality_router_mode,breakout_quality_label,breakout_quality_reason,breakout_quality_pass,breakout_strong,breakout_weak,breakout_dirty,"
                      "breakout_close_distance_from_neckline_atr,breakout_close_distance_from_neckline_points,breakout_body_ratio,breakout_body_atr,breakout_range_atr,"
                      "breakout_directional_wick_ratio,breakout_close_position_directional,neckline_touch_count,"
                      "context_quality_router_mode,context_quality_label,context_quality_reason,context_quality_score,context_clean,context_mixed,context_poor,"
                      "structural_bos_mode,structural_bos_state,m15_confirmation_type,h1_bos_level,h1_counter_nwave_high,h1_counter_nwave_low,"
                      "distance_bos_to_entry,distance_bos_to_entry_atr,bars_since_bos,"
                      "h4_pivot_sequence,h1_pivot_sequence,h4_impulse_atr,h1_counter_wave_atr,h4_correction_depth,true_bos_level,bos_level_source_pivot,"
                      "room_to_1r,room_to_2r,room_to_target_label\r\n");

   int digits = (int)SymbolInfoInteger(setup.symbol, SYMBOL_DIGITS);
   string row = "";
   AppendCsvField(row, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
   AppendCsvField(row, eventName);
   AppendCsvField(row, setup.symbol);
   AppendCsvField(row, setup.direction);
   AppendCsvField(row, ServerSessionLabel());
   AppendCsvField(row, EntrySelectionModeName());
   AppendCsvField(row, IntegerToString(InpScanSeconds));
   AppendCsvField(row, NestedNWaveStrategyName());
   AppendCsvField(row, setup.label);
   AppendCsvField(row, setup.failReason);
   AppendCsvField(row, setup.executionBlockReason);
   AppendCsvField(row, setup.fibZone);
   AppendCsvField(row, setup.h4TrendState);
   AppendCsvField(row, setup.h1CounterTrendState);
   AppendCsvField(row, setup.necklineBreakLabel);
   AppendCsvField(row, BoolText(setup.h4ImpulsePass));
   AppendCsvField(row, BoolText(setup.h4PullbackZonePass));
   AppendCsvField(row, BoolText(setup.h1CounterTrendPass));
   AppendCsvField(row, BoolText(setup.necklinePass));
   AppendCsvField(row, BoolText(setup.structureSlPass));
   AppendCsvField(row, BoolText(setup.rrPass));
   AppendCsvField(row, BoolText(setup.spreadGuardPass));
   AppendCsvField(row, BoolText(setup.spreadGuardBlocked));
   AppendCsvField(row, BoolText(setup.setupPass));
   AppendCsvField(row, BoolText(setup.entryPass));
   AppendCsvField(row, BoolText(setup.finalEntryPass));
   AppendCsvField(row, DoubleToString(setup.h4ImpulseHigh, digits));
   AppendCsvField(row, DoubleToString(setup.h4ImpulseLow, digits));
   AppendCsvField(row, DoubleToString(setup.h4FibRetracementPct, 2));
   AppendCsvField(row, DoubleToString(setup.h4Atr, digits));
   AppendCsvField(row, DoubleToString(setup.h1Atr, digits));
   AppendCsvField(row, DoubleToString(setup.m15Atr, digits));
   AppendCsvField(row, DoubleToString(setup.spreadATR, 4));
   AppendCsvField(row, DoubleToString(setup.spreadPoints, 1));
   AppendCsvField(row, DoubleToString(setup.necklinePrice, digits));
   AppendCsvField(row, DoubleToString(setup.necklineBreakClosePrice, digits));
   AppendCsvField(row, DoubleToString(setup.rightSideLevel, digits));
   AppendCsvField(row, DoubleToString(setup.entryPrice, digits));
   AppendCsvField(row, DoubleToString(setup.stopLoss, digits));
   AppendCsvField(row, DoubleToString(setup.takeProfit, digits));
   AppendCsvField(row, DoubleToString(setup.volume, 2));
   AppendCsvField(row, DoubleToString(setup.riskR, digits));
   AppendCsvField(row, DoubleToString(setup.rr, 2));
   AppendCsvField(row, IntegerToString(setup.barsSinceRightSide));
   AppendCsvField(row, DoubleToString(setup.distanceNecklineToEntry, digits));
   AppendCsvField(row, DoubleToString(setup.distanceNecklineToEntryATR, 2));
   AppendCsvField(row, DoubleToString(setup.distanceRightSideToEntry, digits));
   AppendCsvField(row, DoubleToString(setup.distanceRightSideToEntryATR, 2));
   AppendCsvField(row, DoubleToString(setup.slPoints, 1));
   AppendCsvField(row, DoubleToString(setup.slATR, 2));
   AppendCsvField(row, DoubleToString(setup.tpPoints, 1));
   AppendCsvField(row, DoubleToString(setup.tpATR, 2));
   AppendCsvField(row, DoubleToString(setup.qualityScore, 2));
   AppendCsvField(row, BoolText(setup.retestConfirmationMode));
   AppendCsvField(row, BoolText(setup.retestDetected));
   AppendCsvField(row, BoolText(setup.retestHeld));
   AppendCsvField(row, BoolText(setup.retestTriggerPass));
   AppendCsvField(row, BoolText(setup.retestFailed));
   AppendCsvField(row, DateTimeText(setup.originalNecklineBreakTime));
   AppendCsvField(row, DateTimeText(setup.retestDetectedTime));
   AppendCsvField(row, DateTimeText(setup.retestTriggerTime));
   AppendCsvField(row, IntegerToString(setup.retestBarsAfterBreakout));
   AppendCsvField(row, IntegerToString(setup.entryDelayBars));
   AppendCsvField(row, DoubleToString(setup.retestDepthATR, 2));
   AppendCsvField(row, DoubleToString(setup.retestZoneATR, 2));
   AppendCsvField(row, DoubleToString(setup.retestReclaimPrice, digits));
   AppendCsvField(row, DoubleToString(setup.retestDistanceFromNecklineATR, 2));
   AppendCsvField(row, BoolText(setup.falseBreakReturnInsideNeckline));
   AppendCsvField(row, setup.retestQuality);
   AppendCsvField(row, setup.retestFailureReason);
   AppendCsvField(row, BoolText(setup.breakoutQualityRouterMode));
   AppendCsvField(row, setup.breakoutQualityLabel);
   AppendCsvField(row, setup.breakoutQualityReason);
   AppendCsvField(row, BoolText(setup.breakoutQualityPass));
   AppendCsvField(row, BoolText(setup.breakoutStrong));
   AppendCsvField(row, BoolText(setup.breakoutWeak));
   AppendCsvField(row, BoolText(setup.breakoutDirty));
   AppendCsvField(row, DoubleToString(setup.breakoutCloseDistanceFromNecklineATR, 2));
   AppendCsvField(row, DoubleToString(setup.breakoutCloseDistanceFromNecklinePoints, 1));
   AppendCsvField(row, DoubleToString(setup.breakoutBodyRatio, 2));
   AppendCsvField(row, DoubleToString(setup.breakoutBodyATR, 2));
   AppendCsvField(row, DoubleToString(setup.breakoutRangeATR, 2));
   AppendCsvField(row, DoubleToString(setup.breakoutDirectionalWickRatio, 2));
   AppendCsvField(row, DoubleToString(setup.breakoutClosePositionDirectional, 2));
   AppendCsvField(row, IntegerToString(setup.necklineTouchCount));
   AppendCsvField(row, BoolText(setup.contextQualityRouterMode));
   AppendCsvField(row, setup.contextQualityLabel);
   AppendCsvField(row, setup.contextQualityReason);
   AppendCsvField(row, DoubleToString(setup.contextQualityScore, 2));
   AppendCsvField(row, BoolText(setup.contextClean));
   AppendCsvField(row, BoolText(setup.contextMixed));
   AppendCsvField(row, BoolText(setup.contextPoor));
   AppendCsvField(row, BoolText(setup.structuralBosMode));
   AppendCsvField(row, setup.structuralBosState);
   AppendCsvField(row, setup.m15ConfirmationType);
   AppendCsvField(row, DoubleToString(setup.h1BosLevel, digits));
   AppendCsvField(row, DoubleToString(setup.h1CounterNWaveHigh, digits));
   AppendCsvField(row, DoubleToString(setup.h1CounterNWaveLow, digits));
   AppendCsvField(row, DoubleToString(setup.distanceBosToEntry, digits));
   AppendCsvField(row, DoubleToString(setup.distanceBosToEntryATR, 2));
   AppendCsvField(row, IntegerToString(setup.barsSinceBos));
   AppendCsvField(row, setup.h4PivotSequence);
   AppendCsvField(row, setup.h1PivotSequence);
   AppendCsvField(row, DoubleToString(setup.h4ImpulseATR, 2));
   AppendCsvField(row, DoubleToString(setup.h1CounterWaveATR, 2));
   AppendCsvField(row, DoubleToString(setup.h4CorrectionDepth, 2));
   AppendCsvField(row, DoubleToString(setup.trueBosLevel, digits));
   AppendCsvField(row, setup.bosLevelSourcePivot);
   AppendCsvField(row, DoubleToString(setup.roomTo1R, 2));
   AppendCsvField(row, DoubleToString(setup.roomTo2R, 2));
   AppendCsvField(row, setup.roomToTargetLabel);
   FileWriteString(handle, row + "\r\n");
   FileClose(handle);
  }

void WriteNestedNWaveTradeRow(const NestedNWaveSetup &setup,
                              const string eventName,
                              const string resultReason,
                              const long retcode)
  {
   if(!DiagnosticsEntryDetailEnabled())
      return;
   if(!IsNestedNWaveStrategyMode())
      return;

   EnsureLogFolder();

   int flags = FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;

   string fileName = DailyNestedNWaveTradeLogFileName();
   int handle = FileOpen(fileName, flags, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s: FileOpen failed: %s err=%d", STRATEGY_NAME, fileName, GetLastError());
      return;
     }

   bool needsHeader = (FileSize(handle) == 0);
   FileSeek(handle, 0, SEEK_END);
   if(needsHeader)
      FileWriteString(handle,
                      "time,event,symbol,direction,session,order_retcode,order_comment,strategy_name,"
                      "label,fail_reason,execution_block_reason,fib_zone,h4_trend_state,h1_counter_trend_state,neckline_break_label,"
                      "entry_price,sl,tp,volume,risk_r,rr,sl_points,sl_atr,tp_points,tp_atr,"
                      "neckline_price,neckline_break_close_price,right_side_level,bars_since_right_side,"
                      "distance_neckline_to_entry_atr,distance_right_side_to_entry_atr,spread_atr,spread_points,quality_score,"
                      "retest_confirmation_mode,retest_detected,retest_held,retest_trigger_pass,retest_failed,"
                      "original_neckline_break_time,retest_detected_time,retest_trigger_time,retest_bars_after_breakout,entry_delay_bars,"
                      "retest_depth_atr,retest_zone_atr,retest_reclaim_price,retest_distance_from_neckline_atr,false_break_return_inside_neckline,retest_quality,retest_failure_reason,"
                      "breakout_quality_router_mode,breakout_quality_label,breakout_quality_reason,breakout_quality_pass,breakout_strong,breakout_weak,breakout_dirty,"
                      "breakout_close_distance_from_neckline_atr,breakout_close_distance_from_neckline_points,breakout_body_ratio,breakout_body_atr,breakout_range_atr,"
                      "breakout_directional_wick_ratio,breakout_close_position_directional,neckline_touch_count,"
                      "context_quality_router_mode,context_quality_label,context_quality_reason,context_quality_score,context_clean,context_mixed,context_poor,"
                      "structural_bos_mode,structural_bos_state,m15_confirmation_type,h1_bos_level,h1_counter_nwave_high,h1_counter_nwave_low,"
                      "distance_bos_to_entry,distance_bos_to_entry_atr,bars_since_bos,"
                      "h4_pivot_sequence,h1_pivot_sequence,h4_impulse_atr,h1_counter_wave_atr,h4_correction_depth,true_bos_level,bos_level_source_pivot,"
                      "room_to_1r,room_to_2r,room_to_target_label\r\n");

   int digits = (int)SymbolInfoInteger(setup.symbol, SYMBOL_DIGITS);
   string row = "";
   AppendCsvField(row, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
   AppendCsvField(row, eventName);
   AppendCsvField(row, setup.symbol);
   AppendCsvField(row, setup.direction);
   AppendCsvField(row, ServerSessionLabel());
   AppendCsvField(row, IntegerToString((int)retcode));
   AppendCsvField(row, resultReason);
   AppendCsvField(row, NestedNWaveStrategyName());
   AppendCsvField(row, setup.label);
   AppendCsvField(row, setup.failReason);
   AppendCsvField(row, setup.executionBlockReason);
   AppendCsvField(row, setup.fibZone);
   AppendCsvField(row, setup.h4TrendState);
   AppendCsvField(row, setup.h1CounterTrendState);
   AppendCsvField(row, setup.necklineBreakLabel);
   AppendCsvField(row, DoubleToString(setup.entryPrice, digits));
   AppendCsvField(row, DoubleToString(setup.stopLoss, digits));
   AppendCsvField(row, DoubleToString(setup.takeProfit, digits));
   AppendCsvField(row, DoubleToString(setup.volume, 2));
   AppendCsvField(row, DoubleToString(setup.riskR, digits));
   AppendCsvField(row, DoubleToString(setup.rr, 2));
   AppendCsvField(row, DoubleToString(setup.slPoints, 1));
   AppendCsvField(row, DoubleToString(setup.slATR, 2));
   AppendCsvField(row, DoubleToString(setup.tpPoints, 1));
   AppendCsvField(row, DoubleToString(setup.tpATR, 2));
   AppendCsvField(row, DoubleToString(setup.necklinePrice, digits));
   AppendCsvField(row, DoubleToString(setup.necklineBreakClosePrice, digits));
   AppendCsvField(row, DoubleToString(setup.rightSideLevel, digits));
   AppendCsvField(row, IntegerToString(setup.barsSinceRightSide));
   AppendCsvField(row, DoubleToString(setup.distanceNecklineToEntryATR, 2));
   AppendCsvField(row, DoubleToString(setup.distanceRightSideToEntryATR, 2));
   AppendCsvField(row, DoubleToString(setup.spreadATR, 4));
   AppendCsvField(row, DoubleToString(setup.spreadPoints, 1));
   AppendCsvField(row, DoubleToString(setup.qualityScore, 2));
   AppendCsvField(row, BoolText(setup.retestConfirmationMode));
   AppendCsvField(row, BoolText(setup.retestDetected));
   AppendCsvField(row, BoolText(setup.retestHeld));
   AppendCsvField(row, BoolText(setup.retestTriggerPass));
   AppendCsvField(row, BoolText(setup.retestFailed));
   AppendCsvField(row, DateTimeText(setup.originalNecklineBreakTime));
   AppendCsvField(row, DateTimeText(setup.retestDetectedTime));
   AppendCsvField(row, DateTimeText(setup.retestTriggerTime));
   AppendCsvField(row, IntegerToString(setup.retestBarsAfterBreakout));
   AppendCsvField(row, IntegerToString(setup.entryDelayBars));
   AppendCsvField(row, DoubleToString(setup.retestDepthATR, 2));
   AppendCsvField(row, DoubleToString(setup.retestZoneATR, 2));
   AppendCsvField(row, DoubleToString(setup.retestReclaimPrice, digits));
   AppendCsvField(row, DoubleToString(setup.retestDistanceFromNecklineATR, 2));
   AppendCsvField(row, BoolText(setup.falseBreakReturnInsideNeckline));
   AppendCsvField(row, setup.retestQuality);
   AppendCsvField(row, setup.retestFailureReason);
   AppendCsvField(row, BoolText(setup.breakoutQualityRouterMode));
   AppendCsvField(row, setup.breakoutQualityLabel);
   AppendCsvField(row, setup.breakoutQualityReason);
   AppendCsvField(row, BoolText(setup.breakoutQualityPass));
   AppendCsvField(row, BoolText(setup.breakoutStrong));
   AppendCsvField(row, BoolText(setup.breakoutWeak));
   AppendCsvField(row, BoolText(setup.breakoutDirty));
   AppendCsvField(row, DoubleToString(setup.breakoutCloseDistanceFromNecklineATR, 2));
   AppendCsvField(row, DoubleToString(setup.breakoutCloseDistanceFromNecklinePoints, 1));
   AppendCsvField(row, DoubleToString(setup.breakoutBodyRatio, 2));
   AppendCsvField(row, DoubleToString(setup.breakoutBodyATR, 2));
   AppendCsvField(row, DoubleToString(setup.breakoutRangeATR, 2));
   AppendCsvField(row, DoubleToString(setup.breakoutDirectionalWickRatio, 2));
   AppendCsvField(row, DoubleToString(setup.breakoutClosePositionDirectional, 2));
   AppendCsvField(row, IntegerToString(setup.necklineTouchCount));
   AppendCsvField(row, BoolText(setup.contextQualityRouterMode));
   AppendCsvField(row, setup.contextQualityLabel);
   AppendCsvField(row, setup.contextQualityReason);
   AppendCsvField(row, DoubleToString(setup.contextQualityScore, 2));
   AppendCsvField(row, BoolText(setup.contextClean));
   AppendCsvField(row, BoolText(setup.contextMixed));
   AppendCsvField(row, BoolText(setup.contextPoor));
   AppendCsvField(row, BoolText(setup.structuralBosMode));
   AppendCsvField(row, setup.structuralBosState);
   AppendCsvField(row, setup.m15ConfirmationType);
   AppendCsvField(row, DoubleToString(setup.h1BosLevel, digits));
   AppendCsvField(row, DoubleToString(setup.h1CounterNWaveHigh, digits));
   AppendCsvField(row, DoubleToString(setup.h1CounterNWaveLow, digits));
   AppendCsvField(row, DoubleToString(setup.distanceBosToEntry, digits));
   AppendCsvField(row, DoubleToString(setup.distanceBosToEntryATR, 2));
   AppendCsvField(row, IntegerToString(setup.barsSinceBos));
   AppendCsvField(row, setup.h4PivotSequence);
   AppendCsvField(row, setup.h1PivotSequence);
   AppendCsvField(row, DoubleToString(setup.h4ImpulseATR, 2));
   AppendCsvField(row, DoubleToString(setup.h1CounterWaveATR, 2));
   AppendCsvField(row, DoubleToString(setup.h4CorrectionDepth, 2));
   AppendCsvField(row, DoubleToString(setup.trueBosLevel, digits));
   AppendCsvField(row, setup.bosLevelSourcePivot);
   AppendCsvField(row, DoubleToString(setup.roomTo1R, 2));
   AppendCsvField(row, DoubleToString(setup.roomTo2R, 2));
   AppendCsvField(row, setup.roomToTargetLabel);
   FileWriteString(handle, row + "\r\n");
   FileClose(handle);
  }

string TopNestedNWaveFailReason(long &count)
  {
   string reason = "";
   count = 0;

   if(g_nestedNWaveDataUnavailableCount > count)
     {
      reason = "data_unavailable";
      count = g_nestedNWaveDataUnavailableCount;
     }
   if(g_nestedNWaveAtrUnavailableCount > count)
     {
      reason = "atr_unavailable";
      count = g_nestedNWaveAtrUnavailableCount;
     }
   if(g_nestedNWaveResearchExcludedCount > count)
     {
      reason = "research_excluded";
      count = g_nestedNWaveResearchExcludedCount;
     }
   if(g_nestedNWaveNoH4NWaveCount > count)
     {
      reason = "no_h4_nwave";
      count = g_nestedNWaveNoH4NWaveCount;
     }
   if(g_nestedNWaveTooShallowPullbackCount > count)
     {
      reason = "too_shallow_pullback";
      count = g_nestedNWaveTooShallowPullbackCount;
     }
   if(g_nestedNWaveTooDeepPullbackCount > count)
     {
      reason = "too_deep_pullback";
      count = g_nestedNWaveTooDeepPullbackCount;
     }
   if(g_nestedNWaveNoH1CounterTrendCount > count)
     {
      reason = "no_h1_counter_trend_nwave";
      count = g_nestedNWaveNoH1CounterTrendCount;
     }
   if(g_nestedNWaveNoClearNecklineCount > count)
     {
      reason = "no_clear_neckline";
      count = g_nestedNWaveNoClearNecklineCount;
     }
   if(g_nestedNWaveNoNecklineBreakCount > count)
     {
      reason = "no_neckline_break";
      count = g_nestedNWaveNoNecklineBreakCount;
     }
   if(g_nestedNWaveSlTooTightCount > count)
     {
      reason = "sl_too_tight";
      count = g_nestedNWaveSlTooTightCount;
     }
   if(g_nestedNWaveSlTooWideCount > count)
     {
      reason = "sl_too_wide";
      count = g_nestedNWaveSlTooWideCount;
     }
   if(g_nestedNWaveInvalidStructureCount > count)
     {
      reason = "invalid_structure";
      count = g_nestedNWaveInvalidStructureCount;
     }
   if(g_nestedNWaveSpreadGuardCount > count)
     {
      reason = "spread_guard";
      count = g_nestedNWaveSpreadGuardCount;
     }
   if(g_nestedNWaveNoRetestBreakCount > count)
     {
      reason = "no_retest_confirmation_break";
      count = g_nestedNWaveNoRetestBreakCount;
     }
   if(g_nestedNWaveNoRetestDetectedCount > count)
     {
      reason = "no_retest_detected";
      count = g_nestedNWaveNoRetestDetectedCount;
     }
   if(g_nestedNWaveRetestInvalidatedCount > count)
     {
      reason = "retest_invalidated";
      count = g_nestedNWaveRetestInvalidatedCount;
     }
   if(g_nestedNWaveNoRetestTriggerCount > count)
     {
      reason = "no_retest_trigger";
      count = g_nestedNWaveNoRetestTriggerCount;
     }
   if(g_nestedNWaveDirtyBreakoutFailCount > count)
     {
      reason = "dirty_breakout";
      count = g_nestedNWaveDirtyBreakoutFailCount;
     }
   if(g_nestedNWaveUnclearBreakoutFailCount > count)
     {
      reason = "unclear_breakout_quality";
      count = g_nestedNWaveUnclearBreakoutFailCount;
     }
   if(g_nestedNWaveWeakBreakoutWaitingRetestCount > count)
     {
      reason = "weak_breakout_waiting_retest";
      count = g_nestedNWaveWeakBreakoutWaitingRetestCount;
     }
   if(g_nestedNWaveRouterRetestRequiresWeakCount > count)
     {
      reason = "router_retest_requires_weak_breakout";
      count = g_nestedNWaveRouterRetestRequiresWeakCount;
     }
   if(g_nestedNWaveUnknownFailCount > count)
     {
      reason = "unknown";
      count = g_nestedNWaveUnknownFailCount;
     }

   return reason;
  }

void WriteNestedNWaveSummaryRow()
  {
   if(!DiagnosticsSummaryEnabled())
      return;
   if(!IsNestedNWaveStrategyMode() &&
      g_nestedNWaveEvaluations <= 0)
      return;

   EnsureLogFolder();

   int flags = FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;

   string fileName = DailyNestedNWaveSummaryLogFileName();
   int handle = FileOpen(fileName, flags, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s: FileOpen failed: %s err=%d", STRATEGY_NAME, fileName, GetLastError());
      return;
     }

   bool needsHeader = (FileSize(handle) == 0);
   FileSeek(handle, 0, SEEK_END);
   if(needsHeader)
      FileWriteString(handle,
                      "time,strategy_name,entry_selection_mode,context_tf,pattern_tf,execution_tf,reward_r,"
                      "evaluations,long_evaluations,short_evaluations,h4_impulse_pass,pullback_zone_pass,h1_counter_trend_pass,neckline_pass,structure_sl_pass,rr_pass,spread_guard_pass,spread_guard_blocked,final_entry_pass,orders_sent,orders_failed,"
                      "data_unavailable,atr_unavailable,research_excluded,no_h4_nwave,too_shallow_pullback,too_deep_pullback,no_h1_counter_trend_nwave,no_clear_neckline,no_neckline_break,sl_too_tight,sl_too_wide,invalid_structure,spread_guard,existing_position,execution_blocked,clean_nested_nwave_entry,neckline_break_initial,neckline_break_late,chasing_after_break,retest_detected,retest_held,retest_trigger_pass,no_retest_confirmation_break,no_retest_detected,retest_invalidated,no_retest_trigger,strong_breakout,weak_breakout,dirty_breakout,unclear_breakout,dirty_breakout_fail,unclear_breakout_quality,weak_breakout_waiting_retest,router_retest_requires_weak_breakout,unknown,"
                      "top_fail_reason,top_fail_reason_rows\r\n");

   long topFailCount = 0;
   string topFailReason = TopNestedNWaveFailReason(topFailCount);

   string row = "";
   AppendCsvField(row, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
   AppendCsvField(row, NestedNWaveStrategyName());
   AppendCsvField(row, EntrySelectionModeName());
   AppendCsvField(row, TimeframeText(InpContextTF));
   AppendCsvField(row, TimeframeText(InpPatternTF));
   AppendCsvField(row, TimeframeText(InpExecutionTF));
   AppendCsvField(row, DoubleToString(InpRewardR, 2));
   AppendCsvLong(row, g_nestedNWaveEvaluations);
   AppendCsvLong(row, g_nestedNWaveLongEvaluations);
   AppendCsvLong(row, g_nestedNWaveShortEvaluations);
   AppendCsvLong(row, g_nestedNWaveH4ImpulsePassCount);
   AppendCsvLong(row, g_nestedNWavePullbackZonePassCount);
   AppendCsvLong(row, g_nestedNWaveH1CounterTrendPassCount);
   AppendCsvLong(row, g_nestedNWaveNecklinePassCount);
   AppendCsvLong(row, g_nestedNWaveStructureSlPassCount);
   AppendCsvLong(row, g_nestedNWaveRrPassCount);
   AppendCsvLong(row, g_nestedNWaveSpreadGuardPassCount);
   AppendCsvLong(row, g_nestedNWaveSpreadGuardBlockedCount);
   AppendCsvLong(row, g_nestedNWaveFinalEntryPassCount);
   AppendCsvLong(row, g_nestedNWaveOrderSentCount);
   AppendCsvLong(row, g_nestedNWaveOrderFailedCount);
   AppendCsvLong(row, g_nestedNWaveDataUnavailableCount);
   AppendCsvLong(row, g_nestedNWaveAtrUnavailableCount);
   AppendCsvLong(row, g_nestedNWaveResearchExcludedCount);
   AppendCsvLong(row, g_nestedNWaveNoH4NWaveCount);
   AppendCsvLong(row, g_nestedNWaveTooShallowPullbackCount);
   AppendCsvLong(row, g_nestedNWaveTooDeepPullbackCount);
   AppendCsvLong(row, g_nestedNWaveNoH1CounterTrendCount);
   AppendCsvLong(row, g_nestedNWaveNoClearNecklineCount);
   AppendCsvLong(row, g_nestedNWaveNoNecklineBreakCount);
   AppendCsvLong(row, g_nestedNWaveSlTooTightCount);
   AppendCsvLong(row, g_nestedNWaveSlTooWideCount);
   AppendCsvLong(row, g_nestedNWaveInvalidStructureCount);
   AppendCsvLong(row, g_nestedNWaveSpreadGuardCount);
   AppendCsvLong(row, g_nestedNWaveExistingPositionCount);
   AppendCsvLong(row, g_nestedNWaveExecutionBlockedCount);
   AppendCsvLong(row, g_nestedNWaveCleanEntryCount);
   AppendCsvLong(row, g_nestedNWaveInitialBreakCount);
   AppendCsvLong(row, g_nestedNWaveLateBreakCount);
   AppendCsvLong(row, g_nestedNWaveChasingBreakCount);
   AppendCsvLong(row, g_nestedNWaveRetestDetectedCount);
   AppendCsvLong(row, g_nestedNWaveRetestHeldCount);
   AppendCsvLong(row, g_nestedNWaveRetestTriggerPassCount);
   AppendCsvLong(row, g_nestedNWaveNoRetestBreakCount);
   AppendCsvLong(row, g_nestedNWaveNoRetestDetectedCount);
   AppendCsvLong(row, g_nestedNWaveRetestInvalidatedCount);
   AppendCsvLong(row, g_nestedNWaveNoRetestTriggerCount);
   AppendCsvLong(row, g_nestedNWaveStrongBreakoutCount);
   AppendCsvLong(row, g_nestedNWaveWeakBreakoutCount);
   AppendCsvLong(row, g_nestedNWaveDirtyBreakoutCount);
   AppendCsvLong(row, g_nestedNWaveUnclearBreakoutCount);
   AppendCsvLong(row, g_nestedNWaveDirtyBreakoutFailCount);
   AppendCsvLong(row, g_nestedNWaveUnclearBreakoutFailCount);
   AppendCsvLong(row, g_nestedNWaveWeakBreakoutWaitingRetestCount);
   AppendCsvLong(row, g_nestedNWaveRouterRetestRequiresWeakCount);
   AppendCsvLong(row, g_nestedNWaveUnknownFailCount);
   AppendCsvField(row, topFailReason);
   AppendCsvLong(row, topFailCount);
   FileWriteString(handle, row + "\r\n");
   FileClose(handle);
  }

string TopThirdWaveSkipReason(long &count)
  {
   string reason = "";
   count = 0;

   if(g_thirdWaveNoHigherTrendCount > count)
     {
      reason = "no_higher_tf_trend";
      count = g_thirdWaveNoHigherTrendCount;
     }
   if(g_thirdWaveTrendBrokenCount > count)
     {
      reason = "trend_broken";
      count = g_thirdWaveTrendBrokenCount;
     }
   if(g_thirdWaveNoMidPullbackCount > count)
     {
      reason = "no_mid_pullback";
      count = g_thirdWaveNoMidPullbackCount;
     }
   if(g_thirdWavePullbackTooShallowCount > count)
     {
      reason = "pullback_too_shallow";
      count = g_thirdWavePullbackTooShallowCount;
     }
   if(g_thirdWavePullbackTooDeepCount > count)
     {
      reason = "pullback_too_deep";
      count = g_thirdWavePullbackTooDeepCount;
     }
   if(g_thirdWaveNoLowerReversalCount > count)
     {
      reason = "no_lower_reversal";
      count = g_thirdWaveNoLowerReversalCount;
     }
   if(g_thirdWaveLowerReversalQualityLowCount > count)
     {
      reason = "lower_reversal_quality_low";
      count = g_thirdWaveLowerReversalQualityLowCount;
     }
   if(g_thirdWaveSlTooCloseCount > count)
     {
      reason = "sl_too_close";
      count = g_thirdWaveSlTooCloseCount;
     }
   if(g_thirdWaveSlTooTightCount > count)
     {
      reason = "sl_too_tight";
      count = g_thirdWaveSlTooTightCount;
     }
   if(g_thirdWaveSlTooWideCount > count)
     {
      reason = "sl_too_wide";
      count = g_thirdWaveSlTooWideCount;
     }
   if(g_thirdWaveInvalidStopsCount > count)
     {
      reason = "invalid_stops";
      count = g_thirdWaveInvalidStopsCount;
     }
   if(g_thirdWaveRrTooLowCount > count)
     {
      reason = "rr_too_low";
      count = g_thirdWaveRrTooLowCount;
     }
   if(g_thirdWaveDataUnavailableCount > count)
     {
      reason = "data_unavailable";
      count = g_thirdWaveDataUnavailableCount;
     }
   if(g_thirdWaveAtrUnavailableCount > count)
     {
      reason = "atr_unavailable";
      count = g_thirdWaveAtrUnavailableCount;
     }
   if(g_thirdWaveResearchExcludedCount > count)
     {
      reason = "research_excluded";
      count = g_thirdWaveResearchExcludedCount;
     }
   if(g_thirdWaveRegimeBlockLongRequiresTrendUpCount > count)
     {
      reason = "regime_requires_trend_up";
      count = g_thirdWaveRegimeBlockLongRequiresTrendUpCount;
     }
   if(g_thirdWaveRegimeBlockShortRequiresTrendDownCount > count)
     {
      reason = "regime_requires_trend_down";
      count = g_thirdWaveRegimeBlockShortRequiresTrendDownCount;
     }
   if(g_thirdWaveUnknownSkipCount > count)
     {
      reason = "unknown";
      count = g_thirdWaveUnknownSkipCount;
     }

   return reason;
  }

string TopThirdWaveExecutionBlockReason(long &count)
  {
   string reason = "";
   count = 0;

   if(g_thirdWaveExecutionSpreadGuardCount > count)
     {
      reason = "spread_guard";
      count = g_thirdWaveExecutionSpreadGuardCount;
     }
   if(g_thirdWaveExecutionTradingDisabledCount > count)
     {
      reason = "trading_disabled";
      count = g_thirdWaveExecutionTradingDisabledCount;
     }
   if(g_thirdWaveExecutionNoEntrySignalCount > count)
     {
      reason = "no_entry_signal";
      count = g_thirdWaveExecutionNoEntrySignalCount;
     }
   if(g_thirdWaveExecutionPositionLimitCount > count)
     {
      reason = "position_limit";
      count = g_thirdWaveExecutionPositionLimitCount;
     }
   if(g_thirdWaveExecutionRiskStopCount > count)
     {
      reason = "risk_stop";
      count = g_thirdWaveExecutionRiskStopCount;
     }
   if(g_thirdWaveExecutionRiskLimitCount > count)
     {
      reason = "risk_limit";
      count = g_thirdWaveExecutionRiskLimitCount;
     }
   if(g_thirdWaveExecutionInvalidCount > count)
     {
      reason = "invalid_trade_context";
      count = g_thirdWaveExecutionInvalidCount;
     }
   if(g_thirdWaveExecutionOrderFailedCount > count)
     {
      reason = "order_failed";
      count = g_thirdWaveExecutionOrderFailedCount;
     }
   if(g_thirdWaveExecutionUnknownCount > count)
     {
      reason = "unknown";
      count = g_thirdWaveExecutionUnknownCount;
     }

   return reason;
  }

string TopThirdWaveV2FilterFailReason(long &count)
  {
   string reason = "";
   count = 0;

   if(g_thirdWaveV2FilterDeepPullbackCount > count)
     {
      reason = "v2_pullback_too_deep_audit";
      count = g_thirdWaveV2FilterDeepPullbackCount;
     }
   if(g_thirdWaveV2FilterTrendTooOldCount > count)
     {
      reason = "v2_trend_too_old";
      count = g_thirdWaveV2FilterTrendTooOldCount;
     }
   if(g_thirdWaveV2FilterReclaimChaseCount > count)
     {
      reason = "v2_reclaim_chase_too_far";
      count = g_thirdWaveV2FilterReclaimChaseCount;
     }

   return reason;
  }

string TopThirdWaveV3FilterFailReason(long &count)
  {
   string reason = "";
   count = 0;

   if(g_thirdWaveV3FilterInvalidPositionCount > count)
     {
      count = g_thirdWaveV3FilterInvalidPositionCount;
      reason = "v3_wave_position_invalid";
     }
   if(g_thirdWaveV3FilterLateEntryCount > count)
     {
      count = g_thirdWaveV3FilterLateEntryCount;
      reason = "v3_late_entry";
     }
   if(g_thirdWaveV3FilterChasingEntryCount > count)
     {
      count = g_thirdWaveV3FilterChasingEntryCount;
      reason = "v3_chasing_entry";
     }
   if(g_thirdWaveV3FilterReclaimChaseCount > count)
     {
      count = g_thirdWaveV3FilterReclaimChaseCount;
      reason = "v3_reclaim_chase_too_far";
     }
   if(g_thirdWaveV3FilterPullbackChaseCount > count)
     {
      count = g_thirdWaveV3FilterPullbackChaseCount;
      reason = "v3_pullback_entry_too_far";
     }
   if(g_thirdWaveV3FilterMomentumExhaustedCount > count)
     {
      count = g_thirdWaveV3FilterMomentumExhaustedCount;
      reason = "v3_momentum_exhausted";
     }

   return reason;
  }

string TopThirdWaveV4ReversalSignal(long &count)
  {
   string reason = "";
   count = 0;

   if(g_thirdWaveV4ConfirmedFractalCount > count)
     {
      count = g_thirdWaveV4ConfirmedFractalCount;
      reason = "confirmed_fractal";
     }
   if(g_thirdWaveV4EarlyHigherLowCount > count)
     {
      count = g_thirdWaveV4EarlyHigherLowCount;
      reason = "early_higher_low";
     }
   if(g_thirdWaveV4EarlyLowerHighCount > count)
     {
      count = g_thirdWaveV4EarlyLowerHighCount;
      reason = "early_lower_high";
     }
   if(g_thirdWaveV4MomentumTurnCount > count)
     {
      count = g_thirdWaveV4MomentumTurnCount;
      reason = "momentum_turn";
     }
   if(g_thirdWaveV4CandleReversalCount > count)
     {
      count = g_thirdWaveV4CandleReversalCount;
      reason = "candle_reversal";
     }
   if(g_thirdWaveV4MicroBreakCount > count)
     {
      count = g_thirdWaveV4MicroBreakCount;
      reason = "micro_break";
     }
   if(g_thirdWaveV4UnclearCount > count)
     {
      count = g_thirdWaveV4UnclearCount;
      reason = "unclear";
     }

   return reason;
  }

void WriteThirdWaveSummaryRow()
  {
   if(!DiagnosticsSummaryEnabled())
      return;

   if(!IsThirdWaveStrategyMode() &&
      g_thirdWaveEvaluations <= 0)
      return;

   EnsureLogFolder();

   int flags = FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;

   string fileName = DailyThirdWaveSummaryLogFileName();
   int handle = FileOpen(fileName, flags, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s: FileOpen failed: %s err=%d", STRATEGY_NAME, fileName, GetLastError());
      return;
     }

   bool needsHeader = (FileSize(handle) == 0);
   FileSeek(handle, 0, SEEK_END);
   if(needsHeader)
      FileWriteString(handle,
                      "time,strategy_name,v4_signal_mode,thirdwave_sl_mode,evaluations,long_evaluations,short_evaluations,setup_pass,entry_pass,orders_sent,orders_failed,"
                      "higher_tf_trend_pass,mid_tf_pullback_pass,lower_tf_reversal_pass,structure_sl_pass,rr_pass,spread_guard_pass,spread_guard_blocked,final_entry_pass,"
                      "v2_filter_evaluations,v2_filter_pass,v2_filter_fail,v2_filter_deep_pullback,v2_filter_trend_too_old,v2_filter_reclaim_chase_too_far,"
                      "v3_filter_evaluations,v3_filter_pass,v3_filter_fail,v3_filter_invalid_position,v3_filter_late_entry,v3_filter_chasing_entry,v3_filter_reclaim_chase,v3_filter_pullback_chase,v3_filter_momentum_exhausted,"
                      "v4_reversal_evaluations,v4_reversal_pass,v4_reversal_fail,v4_confirmed_fractal,v4_early_higher_low,v4_early_lower_high,v4_momentum_turn,v4_candle_reversal,v4_micro_break,v4_unclear,v4_impulse_consumed_blocked,"
                      "regime_trend_up,regime_trend_down,regime_range,regime_transition,regime_exhaustion,regime_unknown,regime_allowed,regime_blocked,regime_block_long_requires_trend_up,regime_block_short_requires_trend_down,"
                      "long_higher_tf_trend_pass,long_mid_tf_pullback_pass,long_lower_tf_reversal_pass,long_structure_sl_pass,long_rr_pass,long_spread_guard_pass,long_spread_guard_blocked,long_final_entry_pass,"
                      "short_higher_tf_trend_pass,short_mid_tf_pullback_pass,short_lower_tf_reversal_pass,short_structure_sl_pass,short_rr_pass,short_spread_guard_pass,short_spread_guard_blocked,short_final_entry_pass,"
                      "no_higher_tf_trend,trend_broken,no_mid_pullback,pullback_too_shallow,pullback_too_deep,no_lower_reversal,lower_reversal_quality_low,sl_too_close,sl_too_tight,sl_too_wide,invalid_stops,rr_too_low,existing_position,market_closed,spread_guard,data_unavailable,atr_unavailable,research_excluded,regime_requires_trend_up,regime_requires_trend_down,unknown,"
                      "execution_spread_guard,execution_trading_disabled,execution_no_entry_signal,execution_position_limit,execution_risk_stop,execution_risk_limit,execution_invalid,execution_order_failed,execution_unknown,"
                      "top_structure_stage_fail_reason,top_structure_stage_fail_reason_rows,top_execution_block_reason,top_execution_block_reason_rows,top_skip_reason,top_skip_reason_rows,top_v2_filter_fail_reason,top_v2_filter_fail_reason_rows,top_v3_filter_fail_reason,top_v3_filter_fail_reason_rows,top_v4_reversal_signal,top_v4_reversal_signal_rows\r\n");

   long topSkipCount = 0;
   string topSkipReason = TopThirdWaveSkipReason(topSkipCount);
   long topExecutionBlockCount = 0;
   string topExecutionBlockReason = TopThirdWaveExecutionBlockReason(topExecutionBlockCount);
   long topV2FilterCount = 0;
   string topV2FilterReason = TopThirdWaveV2FilterFailReason(topV2FilterCount);
   long topV3FilterCount = 0;
   string topV3FilterReason = TopThirdWaveV3FilterFailReason(topV3FilterCount);
   long topV4SignalCount = 0;
   string topV4SignalReason = TopThirdWaveV4ReversalSignal(topV4SignalCount);

   string row = "";
   AppendCsvField(row, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
   AppendCsvField(row, ThirdWaveStrategyName());
   AppendCsvField(row, V4ReversalSignalModeName());
   AppendCsvField(row, ThirdWaveSLModeName());
   AppendCsvLong(row, g_thirdWaveEvaluations);
   AppendCsvLong(row, g_thirdWaveLongEvaluations);
   AppendCsvLong(row, g_thirdWaveShortEvaluations);
   AppendCsvLong(row, g_thirdWaveSetupPassCount);
   AppendCsvLong(row, g_thirdWaveEntryPassCount);
   AppendCsvLong(row, g_thirdWaveOrderSentCount);
   AppendCsvLong(row, g_thirdWaveOrderFailedCount);
   AppendCsvLong(row, g_thirdWaveHigherTrendPassCount);
   AppendCsvLong(row, g_thirdWaveMidPullbackPassCount);
   AppendCsvLong(row, g_thirdWaveLowerReversalPassCount);
   AppendCsvLong(row, g_thirdWaveStructureSlPassCount);
   AppendCsvLong(row, g_thirdWaveRrPassCount);
   AppendCsvLong(row, g_thirdWaveSpreadGuardPassCount);
   AppendCsvLong(row, g_thirdWaveSpreadGuardBlockedCount);
   AppendCsvLong(row, g_thirdWaveFinalEntryPassCount);
   AppendCsvLong(row, g_thirdWaveV2FilterEvaluations);
   AppendCsvLong(row, g_thirdWaveV2FilterPassCount);
   AppendCsvLong(row, g_thirdWaveV2FilterFailCount);
   AppendCsvLong(row, g_thirdWaveV2FilterDeepPullbackCount);
   AppendCsvLong(row, g_thirdWaveV2FilterTrendTooOldCount);
   AppendCsvLong(row, g_thirdWaveV2FilterReclaimChaseCount);
   AppendCsvLong(row, g_thirdWaveV3FilterEvaluations);
   AppendCsvLong(row, g_thirdWaveV3FilterPassCount);
   AppendCsvLong(row, g_thirdWaveV3FilterFailCount);
   AppendCsvLong(row, g_thirdWaveV3FilterInvalidPositionCount);
   AppendCsvLong(row, g_thirdWaveV3FilterLateEntryCount);
   AppendCsvLong(row, g_thirdWaveV3FilterChasingEntryCount);
   AppendCsvLong(row, g_thirdWaveV3FilterReclaimChaseCount);
   AppendCsvLong(row, g_thirdWaveV3FilterPullbackChaseCount);
   AppendCsvLong(row, g_thirdWaveV3FilterMomentumExhaustedCount);
   AppendCsvLong(row, g_thirdWaveV4ReversalEvaluations);
   AppendCsvLong(row, g_thirdWaveV4ReversalPassCount);
   AppendCsvLong(row, g_thirdWaveV4ReversalFailCount);
   AppendCsvLong(row, g_thirdWaveV4ConfirmedFractalCount);
   AppendCsvLong(row, g_thirdWaveV4EarlyHigherLowCount);
   AppendCsvLong(row, g_thirdWaveV4EarlyLowerHighCount);
   AppendCsvLong(row, g_thirdWaveV4MomentumTurnCount);
   AppendCsvLong(row, g_thirdWaveV4CandleReversalCount);
   AppendCsvLong(row, g_thirdWaveV4MicroBreakCount);
   AppendCsvLong(row, g_thirdWaveV4UnclearCount);
   AppendCsvLong(row, g_thirdWaveV4ImpulseConsumedBlockedCount);
   AppendCsvLong(row, g_thirdWaveRegimeTrendUpCount);
   AppendCsvLong(row, g_thirdWaveRegimeTrendDownCount);
   AppendCsvLong(row, g_thirdWaveRegimeRangeCount);
   AppendCsvLong(row, g_thirdWaveRegimeTransitionCount);
   AppendCsvLong(row, g_thirdWaveRegimeExhaustionCount);
   AppendCsvLong(row, g_thirdWaveRegimeUnknownCount);
   AppendCsvLong(row, g_thirdWaveRegimeAllowedCount);
   AppendCsvLong(row, g_thirdWaveRegimeBlockedCount);
   AppendCsvLong(row, g_thirdWaveRegimeBlockLongRequiresTrendUpCount);
   AppendCsvLong(row, g_thirdWaveRegimeBlockShortRequiresTrendDownCount);
   AppendCsvLong(row, g_thirdWaveLongHigherTrendPassCount);
   AppendCsvLong(row, g_thirdWaveLongMidPullbackPassCount);
   AppendCsvLong(row, g_thirdWaveLongLowerReversalPassCount);
   AppendCsvLong(row, g_thirdWaveLongStructureSlPassCount);
   AppendCsvLong(row, g_thirdWaveLongRrPassCount);
   AppendCsvLong(row, g_thirdWaveLongSpreadGuardPassCount);
   AppendCsvLong(row, g_thirdWaveLongSpreadGuardBlockedCount);
   AppendCsvLong(row, g_thirdWaveLongFinalEntryPassCount);
   AppendCsvLong(row, g_thirdWaveShortHigherTrendPassCount);
   AppendCsvLong(row, g_thirdWaveShortMidPullbackPassCount);
   AppendCsvLong(row, g_thirdWaveShortLowerReversalPassCount);
   AppendCsvLong(row, g_thirdWaveShortStructureSlPassCount);
   AppendCsvLong(row, g_thirdWaveShortRrPassCount);
   AppendCsvLong(row, g_thirdWaveShortSpreadGuardPassCount);
   AppendCsvLong(row, g_thirdWaveShortSpreadGuardBlockedCount);
   AppendCsvLong(row, g_thirdWaveShortFinalEntryPassCount);
   AppendCsvLong(row, g_thirdWaveNoHigherTrendCount);
   AppendCsvLong(row, g_thirdWaveTrendBrokenCount);
   AppendCsvLong(row, g_thirdWaveNoMidPullbackCount);
   AppendCsvLong(row, g_thirdWavePullbackTooShallowCount);
   AppendCsvLong(row, g_thirdWavePullbackTooDeepCount);
   AppendCsvLong(row, g_thirdWaveNoLowerReversalCount);
   AppendCsvLong(row, g_thirdWaveLowerReversalQualityLowCount);
   AppendCsvLong(row, g_thirdWaveSlTooCloseCount);
   AppendCsvLong(row, g_thirdWaveSlTooTightCount);
   AppendCsvLong(row, g_thirdWaveSlTooWideCount);
   AppendCsvLong(row, g_thirdWaveInvalidStopsCount);
   AppendCsvLong(row, g_thirdWaveRrTooLowCount);
   AppendCsvLong(row, g_thirdWaveExistingPositionCount);
   AppendCsvLong(row, g_thirdWaveMarketClosedCount);
   AppendCsvLong(row, g_thirdWaveSpreadGuardBlockedCount);
   AppendCsvLong(row, g_thirdWaveDataUnavailableCount);
   AppendCsvLong(row, g_thirdWaveAtrUnavailableCount);
   AppendCsvLong(row, g_thirdWaveResearchExcludedCount);
   AppendCsvLong(row, g_thirdWaveRegimeBlockLongRequiresTrendUpCount);
   AppendCsvLong(row, g_thirdWaveRegimeBlockShortRequiresTrendDownCount);
   AppendCsvLong(row, g_thirdWaveUnknownSkipCount);
   AppendCsvLong(row, g_thirdWaveExecutionSpreadGuardCount);
   AppendCsvLong(row, g_thirdWaveExecutionTradingDisabledCount);
   AppendCsvLong(row, g_thirdWaveExecutionNoEntrySignalCount);
   AppendCsvLong(row, g_thirdWaveExecutionPositionLimitCount);
   AppendCsvLong(row, g_thirdWaveExecutionRiskStopCount);
   AppendCsvLong(row, g_thirdWaveExecutionRiskLimitCount);
   AppendCsvLong(row, g_thirdWaveExecutionInvalidCount);
   AppendCsvLong(row, g_thirdWaveExecutionOrderFailedCount);
   AppendCsvLong(row, g_thirdWaveExecutionUnknownCount);
   AppendCsvField(row, topSkipReason);
   AppendCsvLong(row, topSkipCount);
   AppendCsvField(row, topExecutionBlockReason);
   AppendCsvLong(row, topExecutionBlockCount);
   AppendCsvField(row, topSkipReason);
   AppendCsvLong(row, topSkipCount);
   AppendCsvField(row, topV2FilterReason);
   AppendCsvLong(row, topV2FilterCount);
   AppendCsvField(row, topV3FilterReason);
   AppendCsvLong(row, topV3FilterCount);
   AppendCsvField(row, topV4SignalReason);
   AppendCsvLong(row, topV4SignalCount);
   FileWriteString(handle, row + "\r\n");

   FileClose(handle);
  }

bool IsEntryScoreCandidate(const SymbolScore &score)
  {
   return (score.dataReady && score.totalScore >= InpEntryScoreThreshold);
  }

bool ShouldWriteScoreDiagnostic(const SymbolScore &score, const bool isBest)
  {
   if(!DiagnosticsVerboseEnabled())
      return false;
   if(!score.dataReady)
      return false;
   if(isBest)
      return true;
   if(IsEntryScoreCandidate(score))
      return true;
   return false;
  }

bool ShouldWriteStructureDiagnostic(const SymbolScore &score, const bool isBest)
  {
   if(!DiagnosticsVerboseEnabled())
      return false;
   if(!score.structureEvaluated)
      return false;
   if(isBest)
      return true;
   if(IsEntryScoreCandidate(score))
      return true;
   if(score.structureState.pass)
      return true;
   return false;
  }

//+------------------------------------------------------------------+
//| Trading bridge                                                    |
//+------------------------------------------------------------------+
bool CanTradeCandidate(const SymbolScore &score, string &blockReason)
  {
   blockReason = "";
   if(!InpEnableTrading)
     {
      blockReason = "trading_disabled";
      return false;
     }
   if(!score.dataReady)
     {
      blockReason = "candidate_data_not_ready";
      return false;
     }
   if(score.totalScore < InpEntryScoreThreshold)
     {
      blockReason = "score_below_threshold";
      return false;
     }
   if(score.direction != "LONG" && score.direction != "SHORT")
     {
      blockReason = "direction_none";
      return false;
     }
   if(score.spreadATR > InpMaxSpreadATR)
     {
      blockReason = "spread_guard";
      return false;
     }
   if(score.stopLoss <= 0.0 || score.takeProfit <= 0.0 || score.volume <= 0.0)
     {
      blockReason = "trade_levels_invalid";
      return false;
     }

   string riskStop = "";
   if(IsHardRiskStopped(riskStop))
     {
      blockReason = riskStop;
      return false;
     }
   if(IsAllCandidatesEntryMode() &&
      CountManagedPositionsForSymbolDirection(score.symbol, score.direction) > 0)
     {
      blockReason = "existing_position";
      return false;
     }
   if(IsAllCandidatesEntryMode() &&
      HasEntryOnCurrentScanBar("ScoreScanner", score.symbol, score.direction))
     {
      blockReason = "same_scan_bar_reentry";
      return false;
     }
   if(InpMaxPositions > 0 && CountManagedPositions() >= InpMaxPositions)
     {
      blockReason = "max_positions";
      return false;
     }
   if(InpMaxSameCurrencyGroupPositions > 0 &&
      CountManagedPositionsForGroup(CurrencyGroup(score.symbol)) >= InpMaxSameCurrencyGroupPositions)
     {
      blockReason = "same_currency_group_limit";
      return false;
     }
   if(CurrentSymbolOpenRiskPercent(score.symbol) + InpRiskPerTradePercent > InpMaxRiskPerSymbolPercent)
     {
      blockReason = "symbol_risk_limit";
      return false;
     }
   if(CurrentTotalOpenRiskPercent() + InpRiskPerTradePercent > InpMaxTotalOpenRiskPercent)
     {
      blockReason = "total_risk_limit";
      return false;
     }

   return true;
  }

void TryTradeBestCandidate(const SymbolScore &score)
  {
   string blockReason = "";
   if(!CanTradeCandidate(score, blockReason))
     {
      if(InpEnableTrading)
        {
         string rowReason = score.reason;
         AppendReason(rowReason, "order_blocked");
         AppendReason(rowReason, blockReason);
         WriteScoreRow(score, rowReason);
         if(score.structureEvaluated)
            WriteStructureFilterRow(score.symbol, score.direction, score.structureState);
        }
      if(InpEnableTrading)
         PrintFormat("%s: trade blocked %s %s score=%.2f reason=%s",
                     STRATEGY_NAME,
                     score.symbol,
                     score.direction,
                     score.totalScore,
                     blockReason);
      return;
     }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);

   string comment = STRATEGY_NAME + "_score_" + DoubleToString(score.totalScore, 1);
   string attemptReason = score.reason;
   AppendReason(attemptReason, "order_attempt");
   WriteScoreRow(score, attemptReason);
   if(score.structureEvaluated)
      WriteStructureFilterRow(score.symbol, score.direction, score.structureState);

   bool ok = false;
   if(score.direction == "LONG")
      ok = trade.Buy(score.volume, score.symbol, 0.0, score.stopLoss, score.takeProfit, comment);
   else if(score.direction == "SHORT")
      ok = trade.Sell(score.volume, score.symbol, 0.0, score.stopLoss, score.takeProfit, comment);

   if(!ok)
     {
      string resultReason = score.reason;
      AppendReason(resultReason, "order_failed");
      AppendReason(resultReason, "retcode_" + IntegerToString((int)trade.ResultRetcode()));
      WriteScoreRow(score, resultReason);
      if(score.structureEvaluated)
         WriteStructureFilterRow(score.symbol, score.direction, score.structureState);
      PrintFormat("%s: order failed %s %s lot=%.2f retcode=%d",
                  STRATEGY_NAME,
                  score.symbol,
                  score.direction,
                  score.volume,
                  trade.ResultRetcode());
     }
   else
     {
      string resultReason = score.reason;
      AppendReason(resultReason, "order_sent");
      WriteScoreRow(score, resultReason);
      if(score.structureEvaluated)
         WriteStructureFilterRow(score.symbol, score.direction, score.structureState);
      MarkEntryOnCurrentScanBar("ScoreScanner", score.symbol, score.direction);
      PrintFormat("%s: order sent %s %s lot=%.2f score=%.2f",
                  STRATEGY_NAME,
                  score.symbol,
                  score.direction,
                  score.volume,
                  score.totalScore);
     }
  }

bool CanTradeThirdWaveCandidate(const ThirdWaveSetup &setup, string &blockReason)
  {
   blockReason = "";
   if(!InpEnableTrading)
     {
      blockReason = "trading_disabled";
      return false;
     }
   if(!setup.dataReady || !setup.entryPass)
     {
      blockReason = "no_entry_signal";
      return false;
     }
   if(setup.direction != "LONG" && setup.direction != "SHORT")
     {
      blockReason = "direction_none";
      return false;
     }
   if(setup.stopLoss <= 0.0 || setup.takeProfit <= 0.0 || setup.volume <= 0.0)
     {
      blockReason = "trade_levels_invalid";
      return false;
     }

   string riskStop = "";
   if(IsHardRiskStopped(riskStop))
     {
      blockReason = riskStop;
      return false;
     }
   if(InpMaxPositions > 0 && CountManagedPositions() >= InpMaxPositions)
     {
      blockReason = "max_positions";
      return false;
     }
   if(IsAllCandidatesEntryMode() &&
      CountManagedPositionsForSymbolDirection(setup.symbol, setup.direction) > 0)
     {
      blockReason = "existing_position";
      return false;
     }
   if(!IsAllCandidatesEntryMode() &&
      CountManagedPositionsForSymbol(setup.symbol) > 0)
     {
      blockReason = "existing_position";
      return false;
     }
   if(IsAllCandidatesEntryMode() &&
      HasEntryOnCurrentScanBar(ThirdWaveStrategyName(), setup.symbol, setup.direction))
     {
      blockReason = "same_scan_bar_reentry";
      return false;
     }
   if(InpMaxSameCurrencyGroupPositions > 0 &&
      CountManagedPositionsForGroup(CurrencyGroup(setup.symbol)) >= InpMaxSameCurrencyGroupPositions)
     {
      blockReason = "same_currency_group_limit";
      return false;
     }
   if(CurrentSymbolOpenRiskPercent(setup.symbol) + InpRiskPerTradePercent > InpMaxRiskPerSymbolPercent)
     {
      blockReason = "symbol_risk_limit";
      return false;
     }
   if(CurrentTotalOpenRiskPercent() + InpRiskPerTradePercent > InpMaxTotalOpenRiskPercent)
     {
      blockReason = "total_risk_limit";
      return false;
     }

   return true;
  }

void TryThirdWaveEntry(ThirdWaveSetup &setup)
  {
   string blockReason = "";
   if(!CanTradeThirdWaveCandidate(setup, blockReason))
     {
      if(blockReason == "existing_position")
         ++g_thirdWaveExistingPositionCount;
      if(blockReason == "market_closed")
         ++g_thirdWaveMarketClosedCount;
      setup.executionBlockReason = blockReason;
      RecordThirdWaveExecutionBlockReason(blockReason);
      setup.skipReason = blockReason;
      WriteThirdWaveTradeRow(setup, "order_blocked", blockReason, 0);
      WriteThirdWaveWaveAuditRow(setup, "order_blocked");
      WriteThirdWaveSignalRow(setup);
      PrintFormat("%s: thirdwave trade blocked %s %s reason=%s",
                  STRATEGY_NAME,
                  setup.symbol,
                  setup.direction,
                  blockReason);
      return;
     }

   string comment = ThirdWaveStrategyName();
   WriteThirdWaveTradeRow(setup, "order_attempt", "", 0);
   WriteThirdWaveWaveAuditRow(setup, "order_attempt");
   bool ok = false;
   if(setup.direction == "LONG")
      ok = trade.Buy(setup.volume, setup.symbol, 0.0, setup.stopLoss, setup.takeProfit, comment);
   else if(setup.direction == "SHORT")
      ok = trade.Sell(setup.volume, setup.symbol, 0.0, setup.stopLoss, setup.takeProfit, comment);

   if(!ok)
     {
      ++g_thirdWaveOrderFailedCount;
      ++g_thirdWaveExecutionOrderFailedCount;
      setup.executionBlockReason = "order_failed";
      setup.skipReason = "order_failed";
      WriteThirdWaveTradeRow(setup, "order_failed", "retcode_" + IntegerToString((int)trade.ResultRetcode()), (long)trade.ResultRetcode());
      WriteThirdWaveWaveAuditRow(setup, "order_failed");
      WriteThirdWaveSignalRow(setup);
      PrintFormat("%s: thirdwave order failed %s %s lot=%.2f retcode=%d",
                  STRATEGY_NAME,
                  setup.symbol,
                  setup.direction,
                  setup.volume,
                  trade.ResultRetcode());
     }
   else
     {
      ++g_thirdWaveOrderSentCount;
      WriteThirdWaveTradeRow(setup, "order_sent", "order_sent", (long)trade.ResultRetcode());
      WriteThirdWaveWaveAuditRow(setup, "order_sent");
      WriteThirdWaveSignalRow(setup);
      MarkEntryOnCurrentScanBar(ThirdWaveStrategyName(), setup.symbol, setup.direction);
     PrintFormat("%s: thirdwave order sent %s %s lot=%.2f rr=%.2f",
                  STRATEGY_NAME,
                  setup.symbol,
                  setup.direction,
                  setup.volume,
                  setup.rr);
     }
  }

bool CanTradeNestedNWaveCandidate(const NestedNWaveSetup &setup, string &blockReason)
  {
   blockReason = "";
   if(!InpEnableTrading)
     {
      blockReason = "trading_disabled";
      return false;
     }
   if(!setup.dataReady || !setup.entryPass)
     {
      blockReason = "no_entry_signal";
      return false;
     }
   if(setup.direction != "LONG" && setup.direction != "SHORT")
     {
      blockReason = "direction_none";
      return false;
     }
   if(setup.stopLoss <= 0.0 || setup.takeProfit <= 0.0 || setup.volume <= 0.0)
     {
      blockReason = "trade_levels_invalid";
      return false;
     }

   string riskStop = "";
   if(IsHardRiskStopped(riskStop))
     {
      blockReason = riskStop;
      return false;
     }
   if(InpMaxPositions > 0 && CountManagedPositions() >= InpMaxPositions)
     {
      blockReason = "max_positions";
      return false;
     }
   if(IsAllCandidatesEntryMode() &&
      CountManagedPositionsForSymbolDirection(setup.symbol, setup.direction) > 0)
     {
      blockReason = "existing_position";
      return false;
     }
   if(!IsAllCandidatesEntryMode() &&
      CountManagedPositionsForSymbol(setup.symbol) > 0)
     {
      blockReason = "existing_position";
      return false;
     }
   if(IsAllCandidatesEntryMode() &&
      HasEntryOnCurrentScanBar(NestedNWaveStrategyName(), setup.symbol, setup.direction))
     {
      blockReason = "same_scan_bar_reentry";
      return false;
     }
   if(InpMaxSameCurrencyGroupPositions > 0 &&
      CountManagedPositionsForGroup(CurrencyGroup(setup.symbol)) >= InpMaxSameCurrencyGroupPositions)
     {
      blockReason = "same_currency_group_limit";
      return false;
     }
   if(CurrentSymbolOpenRiskPercent(setup.symbol) + InpRiskPerTradePercent > InpMaxRiskPerSymbolPercent)
     {
      blockReason = "symbol_risk_limit";
      return false;
     }
   if(CurrentTotalOpenRiskPercent() + InpRiskPerTradePercent > InpMaxTotalOpenRiskPercent)
     {
      blockReason = "total_risk_limit";
      return false;
     }

   return true;
  }

void TryNestedNWaveEntry(NestedNWaveSetup &setup)
  {
   string blockReason = "";
   if(!CanTradeNestedNWaveCandidate(setup, blockReason))
     {
      ++g_nestedNWaveExecutionBlockedCount;
      if(blockReason == "existing_position")
         ++g_nestedNWaveExistingPositionCount;
      setup.executionBlockReason = blockReason;
      setup.failReason = blockReason;
      WriteNestedNWaveTradeRow(setup, "order_blocked", blockReason, 0);
      WriteNestedNWaveSignalRow(setup, "order_blocked");
      PrintFormat("%s: nested nwave trade blocked %s %s reason=%s",
                  STRATEGY_NAME,
                  setup.symbol,
                  setup.direction,
                  blockReason);
      return;
     }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);

   string comment = NestedNWaveStrategyName();
   WriteNestedNWaveTradeRow(setup, "order_attempt", "", 0);
   bool ok = false;
   if(setup.direction == "LONG")
      ok = trade.Buy(setup.volume, setup.symbol, 0.0, setup.stopLoss, setup.takeProfit, comment);
   else if(setup.direction == "SHORT")
      ok = trade.Sell(setup.volume, setup.symbol, 0.0, setup.stopLoss, setup.takeProfit, comment);

   if(!ok)
     {
      ++g_nestedNWaveOrderFailedCount;
      setup.executionBlockReason = "order_failed";
      setup.failReason = "order_failed";
      WriteNestedNWaveTradeRow(setup, "order_failed", "retcode_" + IntegerToString((int)trade.ResultRetcode()), (long)trade.ResultRetcode());
      WriteNestedNWaveSignalRow(setup, "order_failed");
      PrintFormat("%s: nested nwave order failed %s %s lot=%.2f retcode=%d",
                  STRATEGY_NAME,
                  setup.symbol,
                  setup.direction,
                  setup.volume,
                  trade.ResultRetcode());
     }
   else
     {
      ++g_nestedNWaveOrderSentCount;
      WriteNestedNWaveTradeRow(setup, "order_sent", "order_sent", (long)trade.ResultRetcode());
      WriteNestedNWaveSignalRow(setup, "order_sent");
      MarkEntryOnCurrentScanBar(NestedNWaveStrategyName(), setup.symbol, setup.direction);
      PrintFormat("%s: nested nwave order sent %s %s lot=%.2f label=%s rr=%.2f",
                  STRATEGY_NAME,
                  setup.symbol,
                  setup.direction,
                  setup.volume,
                  setup.label,
                  setup.rr);
     }
  }

//+------------------------------------------------------------------+
//| Scan orchestration                                                |
//+------------------------------------------------------------------+
int FindBestCandidate(const SymbolScore &scores[])
  {
   int bestIndex = -1;
   double bestScore = -DBL_MAX;
   int size = ArraySize(scores);

   for(int i = 0; i < size; ++i)
     {
      if(!scores[i].dataReady)
         continue;
      if(scores[i].totalScore > bestScore)
        {
         bestScore = scores[i].totalScore;
         bestIndex = i;
        }
     }

   return bestIndex;
  }

void ScanAllSymbols()
  {
   UpdateRiskAnchors();

   int count = ArraySize(g_symbols);
   if(count <= 0)
      return;

   SymbolScore scores[];
   ArrayResize(scores, 0);

   for(int i = 0; i < count; ++i)
     {
      if(IsAllCandidatesEntryMode())
        {
         SymbolScore longScore;
         SymbolScore shortScore;
         bool longReady = false;
         bool shortReady = false;
         string failureReason = "";
         EvaluateSymbolDirectionalScores(g_symbols[i], longScore, longReady, shortScore, shortReady, failureReason);

         int size = ArraySize(scores);
         if(longReady)
           {
            ArrayResize(scores, size + 1);
            scores[size] = longScore;
            size++;
           }
         if(shortReady)
           {
            ArrayResize(scores, size + 1);
            scores[size] = shortScore;
           }
        }
      else
        {
         SymbolScore score;
         EvaluateSymbol(g_symbols[i], score);
         int size = ArraySize(scores);
         ArrayResize(scores, size + 1);
         scores[size] = score;
        }
     }

   int bestIndex = FindBestCandidate(scores);
   int scoreCount = ArraySize(scores);
   for(int i = 0; i < scoreCount; ++i)
     {
      string rowReason = scores[i].reason;
      bool isBest = (bestIndex == i);
      if(bestIndex == i)
         AppendReason(rowReason, "best_candidate");
      else
         AppendReason(rowReason, "not_best");
      if(ShouldWriteScoreDiagnostic(scores[i], isBest))
         WriteScoreRow(scores[i], rowReason);
      if(ShouldWriteStructureDiagnostic(scores[i], isBest))
         WriteStructureFilterRow(scores[i].symbol, scores[i].direction, scores[i].structureState);
     }

   if(IsAllCandidatesEntryMode())
     {
      bool attempted = false;
      for(int i = 0; i < scoreCount; ++i)
        {
         if(!IsEntryScoreCandidate(scores[i]))
            continue;

         SymbolScore candidate = scores[i];
         AppendReason(candidate.reason, "all_score_passing_candidate");
         if(bestIndex == i)
            AppendReason(candidate.reason, "best_candidate");
         attempted = true;
         TryTradeBestCandidate(candidate);
        }

      if(!attempted)
         PrintFormat("%s: no score-passing candidate in scan", STRATEGY_NAME);
      return;
     }

   if(bestIndex >= 0)
     {
      SymbolScore best = scores[bestIndex];
      AppendReason(best.reason, "best_candidate");
      PrintFormat("%s: best=%s %s total=%.2f trend=%.2f setup=%.2f vol=%.2f cost=%.2f risk=%.2f reason=%s",
                  STRATEGY_NAME,
                  best.symbol,
                  best.direction,
                  best.totalScore,
                  best.trendScore,
                  best.setupScore,
                  best.volatilityScore,
                  best.costPenalty,
                  best.riskPenalty,
                  best.reason);
      TryTradeBestCandidate(best);
     }
   else
      PrintFormat("%s: no data-ready symbol in scan", STRATEGY_NAME);
  }

int FindBestThirdWaveCandidate(const ThirdWaveSetup &setups[])
  {
   int bestIndex = -1;
   double bestQuality = -DBL_MAX;
   int size = ArraySize(setups);

   for(int i = 0; i < size; ++i)
     {
      if(!setups[i].entryPass)
         continue;
      if(setups[i].qualityScore > bestQuality)
        {
         bestQuality = setups[i].qualityScore;
         bestIndex = i;
        }
     }

   return bestIndex;
  }

void ScanThirdWaveSymbols()
  {
   UpdateRiskAnchors();

   int symbolCount = ArraySize(g_symbols);
   if(symbolCount <= 0)
      return;

   ThirdWaveSetup setups[];
   ArrayResize(setups, 0);

   for(int i = 0; i < symbolCount; ++i)
     {
      for(int direction = 1; direction >= -1; direction -= 2)
        {
         string directionReason = "";
         if(!IsDirectionAllowedByResearchMode(g_symbols[i], direction, directionReason))
            continue;

         ThirdWaveSetup setup;
         BuildThirdWaveSetup(g_symbols[i], direction, setup);
         RecordThirdWaveEvaluation(setup);

         int size = ArraySize(setups);
         ArrayResize(setups, size + 1);
         setups[size] = setup;

         if(ShouldWriteThirdWaveSignalDiagnostic(setup))
            WriteThirdWaveSignalRow(setup);
         if(setup.entryPass)
            WriteThirdWaveWaveAuditRow(setup, "final_entry_candidate");
         else if(setup.rrPass && setup.v3FilterFailReason != "")
            WriteThirdWaveWaveAuditRow(setup, "v3_blocked_candidate");
         else if(setup.rrPass && setup.v4BlockReason != "")
            WriteThirdWaveWaveAuditRow(setup, "v4_blocked_candidate");
         else if(setup.rrPass && setup.executionBlockReason != "")
            WriteThirdWaveWaveAuditRow(setup, "execution_block_candidate");
        }
     }

   int bestIndex = FindBestThirdWaveCandidate(setups);
   if(IsAllCandidatesEntryMode())
     {
      bool attempted = false;
      int setupCount = ArraySize(setups);
      for(int i = 0; i < setupCount; ++i)
        {
         if(!setups[i].entryPass)
            continue;
         attempted = true;
         ThirdWaveSetup candidate = setups[i];
         candidate.skipReason = "all_score_passing_candidate";
         TryThirdWaveEntry(candidate);
        }

      if(!attempted)
         PrintFormat("%s: thirdwave no all-candidates entry candidate in scan", STRATEGY_NAME);
      return;
     }

   if(bestIndex >= 0)
     {
      ThirdWaveSetup best = setups[bestIndex];
      PrintFormat("%s: thirdwave best=%s %s trend=%s pullback=%s reversal=%s rr=%.2f",
                  STRATEGY_NAME,
                  best.symbol,
                  best.direction,
                  best.higherTfTrend,
                  best.midTfPullbackStatus,
                  best.lowerTfReversalStatus,
                  best.rr);
      TryThirdWaveEntry(best);
     }
   else
      PrintFormat("%s: thirdwave no entry candidate in scan", STRATEGY_NAME);
  }

int FindBestNestedNWaveCandidate(const NestedNWaveSetup &setups[])
  {
   int bestIndex = -1;
   double bestQuality = -DBL_MAX;
   int size = ArraySize(setups);

   for(int i = 0; i < size; ++i)
     {
      if(!setups[i].entryPass)
         continue;
      if(setups[i].qualityScore > bestQuality)
        {
         bestQuality = setups[i].qualityScore;
         bestIndex = i;
        }
     }

   return bestIndex;
  }

void ScanNestedNWaveSymbols()
  {
   UpdateRiskAnchors();

   int symbolCount = ArraySize(g_symbols);
   if(symbolCount <= 0)
      return;

   NestedNWaveSetup setups[];
   ArrayResize(setups, 0);

   for(int i = 0; i < symbolCount; ++i)
     {
      for(int direction = 1; direction >= -1; direction -= 2)
        {
         string directionReason = "";
         if(!IsDirectionAllowedByResearchMode(g_symbols[i], direction, directionReason))
            continue;

         NestedNWaveSetup setup;
         BuildNestedNWaveSetup(g_symbols[i], direction, setup);
         RecordNestedNWaveEvaluation(setup);

         int size = ArraySize(setups);
         ArrayResize(setups, size + 1);
         setups[size] = setup;

         if(ShouldWriteNestedNWaveSignalDiagnostic(setup))
            WriteNestedNWaveSignalRow(setup, setup.entryPass ? "final_entry_candidate" : "blocked_candidate");
        }
     }

   int bestIndex = FindBestNestedNWaveCandidate(setups);
   if(IsAllCandidatesEntryMode())
     {
      bool attempted = false;
      int setupCount = ArraySize(setups);
      for(int i = 0; i < setupCount; ++i)
        {
         if(!setups[i].entryPass)
            continue;
         attempted = true;
         NestedNWaveSetup candidate = setups[i];
         TryNestedNWaveEntry(candidate);
        }

      if(!attempted)
         PrintFormat("%s: nested nwave no all-candidates entry candidate in scan", STRATEGY_NAME);
      return;
     }

   if(bestIndex >= 0)
     {
      NestedNWaveSetup best = setups[bestIndex];
      PrintFormat("%s: nested nwave best=%s %s label=%s fib=%.2f quality=%.2f rr=%.2f",
                  STRATEGY_NAME,
                  best.symbol,
                  best.direction,
                  best.label,
                  best.h4FibRetracementPct,
                  best.qualityScore,
                  best.rr);
      TryNestedNWaveEntry(best);
     }
   else
      PrintFormat("%s: nested nwave no entry candidate in scan", STRATEGY_NAME);
  }

void RunActiveStrategyScan()
  {
   if(IsNestedNWaveStrategyMode())
      ScanNestedNWaveSymbols();
   else if(IsThirdWaveStrategyMode())
      ScanThirdWaveSymbols();
   else
      ScanAllSymbols();
  }

bool LatestClosedExecutionBarTime(datetime &barTime, string &reason)
  {
   barTime = 0;
   reason = "";

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, InpExecutionTF, 1, 1, rates);
   if(copied < 1)
     {
      reason = "execution_bar_time_unavailable_" + EnumToString(InpExecutionTF);
      return false;
     }

   barTime = rates[0].time;
   return (barTime > 0);
  }

void RunTimerScan()
  {
   uint started = GetTickCount();
   RunActiveStrategyScan();
   uint elapsed = GetTickCount() - started;
   WriteScanDiagnosticRow("scan_executed_timer", 0, elapsed, "scan_only_on_new_execution_bar_false");
   PrintFormat("%s: scan_executed_timer scan_elapsed_ms=%u",
               STRATEGY_NAME,
               elapsed);
  }

void RunNewExecutionBarScan()
  {
   datetime barTime = 0;
   string reason = "";
   if(!LatestClosedExecutionBarTime(barTime, reason))
     {
      WriteScanDiagnosticRow("scan_skipped_execution_bar_unavailable", g_lastScanExecutionBarTime, 0, reason);
      PrintFormat("%s: scan_skipped_execution_bar_unavailable last_scan_bar_time=%s reason=%s",
                  STRATEGY_NAME,
                  DateTimeText(g_lastScanExecutionBarTime),
                  reason);
      return;
     }

   if(barTime <= g_lastScanExecutionBarTime)
     {
      if(g_lastLoggedSkippedExecutionBarTime != g_lastScanExecutionBarTime)
        {
         g_lastLoggedSkippedExecutionBarTime = g_lastScanExecutionBarTime;
         WriteScanDiagnosticRow("scan_skipped_same_execution_bar", g_lastScanExecutionBarTime, 0, "");
         PrintFormat("%s: scan_skipped_same_execution_bar last_scan_bar_time=%s",
                     STRATEGY_NAME,
                     DateTimeText(g_lastScanExecutionBarTime));
        }
      return;
     }

   g_lastScanExecutionBarTime = barTime;
   uint started = GetTickCount();
   RunActiveStrategyScan();
   uint elapsed = GetTickCount() - started;
   WriteScanDiagnosticRow("scan_executed_new_execution_bar", g_lastScanExecutionBarTime, elapsed, "");
   PrintFormat("%s: scan_executed_new_execution_bar last_scan_bar_time=%s scan_elapsed_ms=%u",
               STRATEGY_NAME,
               DateTimeText(g_lastScanExecutionBarTime),
               elapsed);
  }

//+------------------------------------------------------------------+
//| Expert lifecycle                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpScanSeconds <= 0 ||
      InpEntryScoreThreshold < 0.0 ||
      InpMaxPositions < 0 ||
      InpMaxSameCurrencyGroupPositions < 0 ||
      InpFastMAPeriod < 2 ||
      InpSlowMAPeriod <= InpFastMAPeriod ||
      InpATRPeriod < 2 ||
      InpATRAveragePeriod < InpATRPeriod ||
      InpSlopeLookbackBars < 1 ||
      InpSetupLookbackBars < 3 ||
      InpStructureSwingSpan < 1 ||
      InpStructureScanBars < InpStructureSwingSpan * 4 + 10 ||
      InpRiskPerTradePercent <= 0.0 ||
      InpMaxRiskPerSymbolPercent <= 0.0 ||
      InpMaxTotalOpenRiskPercent <= 0.0 ||
      InpDailyMaxLossPercent <= 0.0 ||
      InpWeeklyMaxLossPercent <= 0.0 ||
      InpMaxDrawdownPercent <= 0.0 ||
      InpMaxSpreadATR <= 0.0 ||
      InpStopATRMultiplier <= 0.0 ||
      InpMinSL_ATR <= 0.0 ||
      InpMaxSL_ATR < InpMinSL_ATR ||
      InpThirdWaveSLMode < THIRD_WAVE_SL_CURRENT ||
      InpThirdWaveSLMode > THIRD_WAVE_SL_LOWER_TF_REVERSAL ||
      InpRewardR <= 0.0 ||
      InpFixedLotFallback <= 0.0 ||
      InpMaxLotCap <= 0.0)
     {
      PrintFormat("%s: invalid input parameter", STRATEGY_NAME);
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!ParseSymbols())
     {
      PrintFormat("%s: no valid symbols in InpSymbols", STRATEGY_NAME);
      return INIT_FAILED;
     }

   g_initialEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_peakEquity = g_initialEquity;
   g_dayStartEquity = g_initialEquity;
   g_weekStartEquity = g_initialEquity;
   g_dayKey = DateKey(TimeCurrent());
   g_weekKey = WeekKey(TimeCurrent());

   trade.SetExpertMagicNumber(InpMagicNumber);
   EventSetTimer(InpScanSeconds);
   EnsureLogFolder();

   PrintFormat("%s initialized symbols=%d trading=%s scan_seconds=%d scan_only_new_execution_bar=%s strategy_mode=%d entry_selection=%s diagnostics_level=%d v4_signal_mode=%s thirdwave_sl_mode=%s reward_r=%.2f direction_mode=%d symbol_research_mode=%d dow_fractal_filter=%s",
               STRATEGY_NAME,
               ArraySize(g_symbols),
               (InpEnableTrading ? "true" : "false"),
               InpScanSeconds,
               BoolText(InpScanOnlyOnNewExecutionBar),
               (int)InpResearchStrategyMode,
               EntrySelectionModeName(),
               (int)InpDiagnosticsLevel,
               V4ReversalSignalModeName(),
               ThirdWaveSLModeName(),
               InpRewardR,
               (int)InpTradeDirectionMode,
               (int)InpSymbolResearchMode,
               BoolText(InpUseDowFractalStructureFilter));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   WriteStructureSummaryRow();
   WriteThirdWaveSummaryRow();
   WriteNestedNWaveSummaryRow();
   EventKillTimer();
  }

void OnTick()
  {
  }

void OnTimer()
  {
   if(InpScanOnlyOnNewExecutionBar)
      RunNewExecutionBarScan();
   else
      RunTimerScan();
  }
