//+------------------------------------------------------------------+
//| ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader      |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Backtest-only multi-currency session opening reversal pullback EA with HTF obstacle diagnostics."

#include <Trade\Trade.mqh>

CTrade trade;

static const string STRATEGY_NAME = "ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader";

enum ENUM_SESSION_REVERSAL_SCENARIO
  {
   SESSION_REVERSAL_ALL_SYMBOLS_FIRST120 = 0,
   SESSION_REVERSAL_ONE_SYMBOL_FIRST120 = 1,
   SESSION_REVERSAL_ONE_SYMBOL_FIRST60 = 2,
   SESSION_REVERSAL_CLEAN_TARGET_FIRST120 = 3,
   SESSION_REVERSAL_CLEAN_TARGET_FIRST60 = 4,
   SESSION_REVERSAL_TOKYO_FIRST120 = 5,
   SESSION_REVERSAL_LONDON_FIRST120 = 6,
   SESSION_REVERSAL_NEWYORK_FIRST120 = 7,
   SESSION_REVERSAL_OVERLAP_FIRST120 = 8,
   SESSION_REVERSAL_TARGET_MULTIPLE_1_2 = 9,
   SESSION_REVERSAL_TARGET_MULTIPLE_2_0 = 10
  };

enum ENUM_HTF_ALIGNMENT_MODE
  {
   HTF_ALIGNMENT_STRICT_H4_H1 = 0,
   HTF_ALIGNMENT_H4_BIAS_H1_REVERSAL = 1,
   HTF_ALIGNMENT_H1_CONFIRMED_H4_NOT_OPPOSITE = 2,
   HTF_ALIGNMENT_SOFT = 3
  };

enum ENUM_HTF_PERMISSION_MODE
  {
   HTF_PERMISSION_CURRENT_POST_FILTER = 0,
   HTF_PERMISSION_H1_DIRECTION_H4_NOT_OPPOSITE_PREFILTER = 1,
   HTF_PERMISSION_H4_BIAS_H1_REVERSAL_PREFILTER = 2,
   HTF_PERMISSION_SOFT_PREFILTER = 3,
   HTF_PERMISSION_STRICT_PREFILTER = 4
  };

enum ENUM_BREAK_EVEN_MODE
  {
   BREAK_EVEN_DISABLED = 0,
   BREAK_EVEN_AT_1_0R = 1,
   BREAK_EVEN_AT_1_1R = 2,
   BREAK_EVEN_TIME_30MIN_AND_0_5R_OR_1_0R = 3
  };

struct SessionInfo
  {
   bool              active;
   string            label;
   int               index;
   int               startUtcHour;
   datetime          sessionStartUtc;
   datetime          sessionStartServer;
   int               minutesFromStart;
   int               serverHour;
   int               utcHour;
   int               jstHour;
   bool              first60;
   bool              first120;
   string            tradeWindowLabel;
   string            sessionKey;
  };

struct SignalPlan
  {
   bool              valid;
   bool              signalBlocked;
   string            symbol;
   string            direction;
   string            strategy;
   datetime          serverTime;
   int               serverHour;
   int               utcHour;
   int               jstHour;
   string            sessionLabel;
   datetime          sessionStartUtc;
   int               minutesFromSessionStart;
   string            tradeWindowLabel;
   bool              isWithinFirst60;
   bool              isWithinFirst120;
   double            brokerUtcOffsetUsed;
   string            selectedSymbolForSession;
   string            selectedReason;
   string            sessionCandidateSymbolMap;
   string            sessionCandidateSymbols;
   string            entryPattern;
   string            entryTrigger;
   double            necklineLevel;
   string            ltfWave3Direction;
   string            ltfWave3Timeframe;
   string            topContextTF;
   string            structureTF;
   string            primaryEntryTF;
   string            secondaryEntryTF;
   bool              useSecondaryEntryTF;
   string            htfAlignmentMode;
   string            htfPermissionMode;
   string            allowedDirection;
   string            htfWave3Direction;
   bool              htfWave3Confirmed;
   string            htfH4Wave3Direction;
   string            htfH1Wave3Direction;
   string            h4DirectionState;
   string            h1DirectionState;
   string            topContextDirectionState;
   string            structureDirectionState;
   string            htfFractalAlignment;
   double            htfWave3BreakLevel;
   double            htfWave3PullbackLevel;
   bool              wave3AlignmentPassed;
   bool              rejectedByHtfPermission;
   bool              candidateLongDetected;
   bool              candidateShortDetected;
   string            selectedCandidateDirection;
   string            selectedCandidateTimeframe;
   string            selectedCandidatePattern;
   string            primaryBestPattern;
   double            primaryBestScore;
   string            secondaryBestPattern;
   double            secondaryBestScore;
   string            m15BestPattern;
   double            m15BestScore;
   string            m5BestPattern;
   double            m5BestScore;
   double            htfNearestResistance;
   double            htfNearestSupport;
   double            nearestObstaclePrice;
   string            nearestObstacleType;
   double            nearestObstacleDistancePrice;
   double            nearestObstacleDistanceR;
   string            retestReferenceType;
   double            retestReferencePrice;
   int               retestReferenceCount;
   double            retestReferenceDistanceAtr;
   double            targetRoomScore;
   double            retestScore;
   double            fibScore;
   string            fibSourceTF;
   double            fibImpulseHigh;
   double            fibImpulseLow;
   double            fibRetraceRatio;
   string            fibZone;
   bool              fibRequiredPass;
   double            basePatternScore;
   string            timeBucket;
   bool              timeScoreRemovedFlag;
   bool              candidateOrderableBeforeSessionSelection;
   string            rejectedBeforeSelectionReason;
   string            sessionConsumedReason;
   double            finalScore;
   double            initialRiskPriceDistance;
   double            targetRewardMultiple;
   double            targetPrice;
   bool              cleanPathToTarget;
   bool              hardObstaclePresentBeforeTarget;
   bool              softObstaclePresentBeforeTarget;
   bool              obstacleBlocked;
   string            obstacleBlockReason;
   int               obstacleCountBeforeTarget;
   int               hardObstacleCountBeforeTarget;
   int               softObstacleCountBeforeTarget;
   double            entry;
   double            stopLoss;
   double            takeProfit;
   double            riskPrice;
   double            rewardR;
   double            atr;
   double            spreadPoints;
   double            score;
   string            failureType;
   string            reason;
   bool              sessionInvalidated;
   string            invalidationReason;
   string            sessionKey;
   string            symbolSessionKey;
  };

struct TrackedTrade
  {
   bool              active;
   string            symbol;
   string            direction;
   string            strategy;
   datetime          entryTime;
   datetime          serverTime;
   int               serverHour;
   int               utcHour;
   int               jstHour;
   string            sessionLabel;
   datetime          sessionStartUtc;
   int               minutesFromSessionStart;
   string            tradeWindowLabel;
   bool              isWithinFirst60;
   bool              isWithinFirst120;
   double            brokerUtcOffsetUsed;
   string            selectedSymbolForSession;
   string            selectedReason;
   string            sessionCandidateSymbolMap;
   string            sessionCandidateSymbols;
   string            entryPattern;
   string            entryTrigger;
   double            necklineLevel;
   string            ltfWave3Direction;
   string            ltfWave3Timeframe;
   string            topContextTF;
   string            structureTF;
   string            primaryEntryTF;
   string            secondaryEntryTF;
   bool              useSecondaryEntryTF;
   string            htfAlignmentMode;
   string            htfPermissionMode;
   string            allowedDirection;
   string            htfWave3Direction;
   bool              htfWave3Confirmed;
   string            htfH4Wave3Direction;
   string            htfH1Wave3Direction;
   string            h4DirectionState;
   string            h1DirectionState;
   string            topContextDirectionState;
   string            structureDirectionState;
   string            htfFractalAlignment;
   double            htfWave3BreakLevel;
   double            htfWave3PullbackLevel;
   bool              wave3AlignmentPassed;
   bool              rejectedByHtfPermission;
   bool              candidateLongDetected;
   bool              candidateShortDetected;
   string            selectedCandidateDirection;
   string            selectedCandidateTimeframe;
   string            selectedCandidatePattern;
   string            primaryBestPattern;
   double            primaryBestScore;
   string            secondaryBestPattern;
   double            secondaryBestScore;
   string            m15BestPattern;
   double            m15BestScore;
   string            m5BestPattern;
   double            m5BestScore;
   double            htfNearestResistance;
   double            htfNearestSupport;
   double            nearestObstaclePrice;
   string            nearestObstacleType;
   double            nearestObstacleDistanceR;
   string            retestReferenceType;
   double            retestReferencePrice;
   int               retestReferenceCount;
   double            retestReferenceDistanceAtr;
   double            targetRoomScore;
   double            retestScore;
   double            fibScore;
   string            fibSourceTF;
   double            fibImpulseHigh;
   double            fibImpulseLow;
   double            fibRetraceRatio;
   string            fibZone;
   bool              fibRequiredPass;
   double            basePatternScore;
   string            timeBucket;
   bool              timeScoreRemovedFlag;
   bool              candidateOrderableBeforeSessionSelection;
   string            rejectedBeforeSelectionReason;
   string            sessionConsumedReason;
   double            finalScore;
   bool              cleanPathToTarget;
   bool              hardObstaclePresentBeforeTarget;
   bool              softObstaclePresentBeforeTarget;
   bool              obstacleBlocked;
   double            targetRewardMultiple;
   double            targetPrice;
   string            breakEvenMode;
   bool              breakEvenEnabled;
   bool              breakEvenTriggered;
   string            breakEvenTriggerType;
   double            breakEvenTriggerR;
   datetime          breakEvenTriggerTime;
   int               barsToBreakEven;
   double            initialStopLossPrice;
   double            currentStopLossPrice;
   double            maxFavorableRBeforeExit;
   double            maxAdverseRBeforeExit;
   datetime          lastManagementBarTime;
   string            entryFailureType;
   bool              sessionInvalidated;
   string            invalidationReason;
   long              positionId;
   double            entryPrice;
   double            stopLoss;
   double            takeProfit;
   double            riskPrice;
   double            rewardR;
   double            volume;
   double            atr;
   double            spreadPoints;
   double            score;
  };

struct PatternCandidate
  {
   bool              valid;
   int               direction;
   string            pattern;
   string            trigger;
   double            neckline;
   double            stopAnchor;
   double            score;
   string            timeframeLabel;
   double            atr;
  };

struct DowPivot
  {
   datetime          time;
   double            price;
   int               kind;     // 1 = swing high, -1 = swing low
   int               shift;
  };

input string          InpSymbols                       = "USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD";
input ENUM_SESSION_REVERSAL_SCENARIO InpScenarioMode   = SESSION_REVERSAL_ONE_SYMBOL_FIRST120;
input ENUM_TIMEFRAMES InpScanTF                        = PERIOD_M15;
input ENUM_TIMEFRAMES InpDiagnosticTF                  = PERIOD_M5;
input ENUM_TIMEFRAMES InpTopContextTF                  = PERIOD_H4;
input ENUM_TIMEFRAMES InpStructureTF                   = PERIOD_H1;
input ENUM_TIMEFRAMES InpPrimaryEntryTF                = PERIOD_M15;
input ENUM_TIMEFRAMES InpSecondaryEntryTF              = PERIOD_M5;
input bool            InpUseSecondaryEntryTF           = true;
input bool            InpRequireStructureTFConfirmation = true;
input bool            InpUseTopTFAsOppositeFilterOnly  = false;
input int             InpBrokerUtcOffsetHours          = 3;
input int             InpATRPeriod                     = 14;
input int             InpMAPeriodFast                  = 10;
input int             InpMAPeriodSlow                  = 30;
input int             InpStructureLookbackBars         = 16;
input int             InpPatternLookbackBars           = 36;
input int             InpSwingDepth                    = 3;
input int             InpHTFLookbackBars               = 80;
input int             InpHTFWaveLookbackBars           = 120;
input double          InpHTFWaveBreakBufferATR         = 0.05;
input bool            InpUseOrderedDowFractalStructure = true;
input bool            InpTopContextTrendOnly           = true;
input bool            InpAllowStructureTrendBiasWhenNoWave3 = false;
input double          InpDowMinSwingATR                = 0.35;
input double          InpDowStructureToleranceATR      = 0.10;
input int             InpDowMinPivotsForTrend          = 4;
input bool            InpRequireH4H1Wave3Alignment     = true;
input ENUM_HTF_ALIGNMENT_MODE InpHTFAlignmentMode       = HTF_ALIGNMENT_STRICT_H4_H1;
input ENUM_HTF_PERMISSION_MODE InpHTFPermissionMode     = HTF_PERMISSION_STRICT_PREFILTER;
input bool            InpUseM5LowerTimeframeWave3      = true;
input bool            InpFilterOrderableBeforeSessionSelection = false;
input bool            InpUseFibPullbackScore           = false;
input bool            InpRequireFibPullbackZone        = false;
input double          InpFibPreferredMin               = 0.382;
input double          InpFibPreferredMax               = 0.618;
input double          InpFibDeepMax                    = 0.786;
input ENUM_BREAK_EVEN_MODE InpBreakEvenMode             = BREAK_EVEN_DISABLED;
input double          InpBreakEvenOffsetPoints         = 0.0;
input int             InpOpeningRangeMinutes           = 30;
input int             InpPreSessionMinutes             = 60;
input double          InpTargetRewardMultiple          = 1.50;
input bool            InpUseSoftObstacleAsHardFilter   = false;
input double          InpRoundNumberStepPips           = 50.0;
input double          InpEqualLevelTolerancePips       = 6.0;
input double          InpEqualLevelToleranceATR        = 0.12;
input double          InpRetestToleranceATR            = 0.28;
input bool            InpRequireRetestCloseBeyondNeckline = true;
input double          InpBreakBufferATR                = 0.08;
input double          InpStopBufferATR                 = 0.18;
input double          InpMinSL_ATR                     = 0.35;
input double          InpMaxSL_ATR                     = 3.00;
input double          InpSessionInvalidationATR        = 0.85;
input int             InpMaxHoldBars                   = 24;
input double          InpRiskPerTradePercent           = 0.25;
input double          InpMaxTotalOpenRiskPercent       = 2.50;
input double          InpMaxRiskPerSymbolPercent       = 0.50;
input int             InpMaxPositions                  = 6;
input double          InpDailyMaxLossPercent           = 3.00;
input double          InpMaxDrawdownPercent            = 15.00;
input double          InpMaxSpreadATR                  = 0.20;
input double          InpFixedLotFallback              = 0.01;
input double          InpMaxLotCap                     = 1.00;
input int             InpSlippagePoints                = 20;
input long            InpMagicNumber                   = 2026062701;
input bool            InpUseCommonFiles                = true;
input string          InpLogFolder                     = "fx_session_reversal_pullback";
input string          InpLogPrefix                     = "fxsessionrev";

string        g_symbols[];
datetime      g_lastScannedBars[];
TrackedTrade  g_trades[];
string        g_consumedSessionKeys[];
string        g_consumedSymbolSessionKeys[];
string        g_selectedSessionKeys[];
string        g_selectedSymbols[];
double        g_initialEquity = 0.0;
double        g_peakEquity = 0.0;
double        g_dayStartEquity = 0.0;
int           g_dayKey = 0;
bool          g_dailyStopped = false;
bool          g_drawdownStopped = false;
long          g_signalCount = 0;
long          g_orderSentCount = 0;
long          g_orderFailedCount = 0;
long          g_blockedCount = 0;
long          g_closedTradeCount = 0;
long          g_htfPermissionRejectedCount = 0;
long          g_preselectionRejectedCount = 0;

string BoolText(const bool value)
  {
   return value ? "true" : "false";
  }

string ScenarioModeName()
  {
   if(InpScenarioMode == SESSION_REVERSAL_ALL_SYMBOLS_FIRST120)
      return "session_reversal_pullback_all_symbols_first120";
   if(InpScenarioMode == SESSION_REVERSAL_ONE_SYMBOL_FIRST120)
      return "session_reversal_pullback_one_symbol_first120";
   if(InpScenarioMode == SESSION_REVERSAL_ONE_SYMBOL_FIRST60)
      return "session_reversal_pullback_one_symbol_first60";
   if(InpScenarioMode == SESSION_REVERSAL_CLEAN_TARGET_FIRST120)
      return "session_reversal_pullback_clean_target_path_first120";
   if(InpScenarioMode == SESSION_REVERSAL_CLEAN_TARGET_FIRST60)
      return "session_reversal_pullback_clean_target_path_first60";
   if(InpScenarioMode == SESSION_REVERSAL_TOKYO_FIRST120)
      return "tokyo_first120_reference";
   if(InpScenarioMode == SESSION_REVERSAL_LONDON_FIRST120)
      return "london_first120_reference";
   if(InpScenarioMode == SESSION_REVERSAL_NEWYORK_FIRST120)
      return "newyork_first120_reference";
   if(InpScenarioMode == SESSION_REVERSAL_OVERLAP_FIRST120)
      return "overlap_first120_reference";
   if(InpScenarioMode == SESSION_REVERSAL_TARGET_MULTIPLE_1_2)
      return "target_multiple_1_2_reference";
   return "target_multiple_2_0_reference";
  }

bool IsOneSymbolPerSessionScenario()
  {
   return InpScenarioMode != SESSION_REVERSAL_ALL_SYMBOLS_FIRST120;
  }

bool UsesCleanTargetPath()
  {
   return InpScenarioMode == SESSION_REVERSAL_CLEAN_TARGET_FIRST120 ||
          InpScenarioMode == SESSION_REVERSAL_CLEAN_TARGET_FIRST60 ||
          InpScenarioMode == SESSION_REVERSAL_TARGET_MULTIPLE_1_2 ||
          InpScenarioMode == SESSION_REVERSAL_TARGET_MULTIPLE_2_0;
  }

double EffectiveTargetRewardMultiple()
  {
   if(InpScenarioMode == SESSION_REVERSAL_TARGET_MULTIPLE_1_2)
      return 1.20;
   if(InpScenarioMode == SESSION_REVERSAL_TARGET_MULTIPLE_2_0)
      return 2.00;
   return InpTargetRewardMultiple;
  }

int EffectiveWindowMinutes()
  {
   if(InpScenarioMode == SESSION_REVERSAL_ONE_SYMBOL_FIRST60 ||
      InpScenarioMode == SESSION_REVERSAL_CLEAN_TARGET_FIRST60)
      return 60;
   return 120;
  }

string TradeWindowLabel()
  {
   int minutes = EffectiveWindowMinutes();
   if(minutes == 60)
      return "first_60min";
   if(minutes == 90)
      return "first_90min_reference";
   return "first_120min";
  }

string HTFAlignmentModeName()
  {
   if(InpHTFAlignmentMode == HTF_ALIGNMENT_H4_BIAS_H1_REVERSAL)
      return "h4_bias_h1_reversal_alignment";
   if(InpHTFAlignmentMode == HTF_ALIGNMENT_H1_CONFIRMED_H4_NOT_OPPOSITE)
      return "h1_confirmed_h4_not_opposite";
   if(InpHTFAlignmentMode == HTF_ALIGNMENT_SOFT)
      return "htf_soft_alignment";
   return "strict_h4_h1_alignment";
  }

string HTFPermissionModeName()
  {
   if(InpHTFPermissionMode == HTF_PERMISSION_STRICT_PREFILTER)
      return "strict_pre_filter";
   if(InpHTFPermissionMode == HTF_PERMISSION_H1_DIRECTION_H4_NOT_OPPOSITE_PREFILTER)
      return "structure_confirmed_top_not_opposite_pre_filter";
   if(InpHTFPermissionMode == HTF_PERMISSION_H4_BIAS_H1_REVERSAL_PREFILTER)
      return "top_bias_structure_reversal_pre_filter";
   if(InpHTFPermissionMode == HTF_PERMISSION_SOFT_PREFILTER)
      return "soft_pre_filter";
   return "current_post_filter";
  }

bool UsesHtfPrefilter()
  {
   return InpHTFPermissionMode != HTF_PERMISSION_CURRENT_POST_FILTER;
  }

string AllowedDirectionText(const int allowedDirection)
  {
   if(allowedDirection > 1)
      return "both";
   if(allowedDirection > 0)
      return "long_only";
   if(allowedDirection < 0)
      return "short_only";
   return "none";
  }

string TimeBucketLabel(const int minutesFromStart)
  {
   if(minutesFromStart < 0)
      return "outside";
   if(minutesFromStart < 30)
      return "0-30";
   if(minutesFromStart < 60)
      return "30-60";
   if(minutesFromStart < 90)
      return "60-90";
   if(minutesFromStart < 120)
      return "90-120";
   return "120+";
  }

string TFName(const ENUM_TIMEFRAMES tf)
  {
   return EnumToString(tf);
  }

string BreakEvenModeName()
  {
   if(InpBreakEvenMode == BREAK_EVEN_AT_1_0R)
      return "break_even_at_1_0r";
   if(InpBreakEvenMode == BREAK_EVEN_AT_1_1R)
      return "break_even_at_1_1r";
   if(InpBreakEvenMode == BREAK_EVEN_TIME_30MIN_AND_0_5R_OR_1_0R)
      return "time_30min_and_0_5r_break_even";
   return "no_break_even";
  }

bool ScenarioAllowsSession(const string label)
  {
   if(InpScenarioMode == SESSION_REVERSAL_TOKYO_FIRST120)
      return label == "tokyo";
   if(InpScenarioMode == SESSION_REVERSAL_LONDON_FIRST120)
      return label == "london";
   if(InpScenarioMode == SESSION_REVERSAL_NEWYORK_FIRST120)
      return label == "new_york";
   if(InpScenarioMode == SESSION_REVERSAL_OVERLAP_FIRST120)
      return label == "london_newyork_overlap";
   return true;
  }

bool IsTokyoJpySymbol(const string symbol)
  {
   return StringFind(symbol, "USDJPY") == 0 ||
          StringFind(symbol, "EURJPY") == 0 ||
          StringFind(symbol, "GBPJPY") == 0 ||
          StringFind(symbol, "AUDJPY") == 0;
  }

bool SymbolAllowedForSession(const string symbol, const string label)
  {
   if(label == "tokyo")
      return IsTokyoJpySymbol(symbol);
   return true;
  }

string CandidateSymbolsForSession(const string label)
  {
   string value = "";
   for(int i = 0; i < ArraySize(g_symbols); ++i)
     {
      if(!SymbolAllowedForSession(g_symbols[i], label))
         continue;
      if(value != "")
         value += "|";
      value += g_symbols[i];
     }
   return value == "" ? "none" : value;
  }

string CandidateSymbolMapForSession(const string label)
  {
   return label + "=" + CandidateSymbolsForSession(label);
  }

string DirectionText(const int direction)
  {
   if(direction > 0)
      return "LONG";
   if(direction < 0)
      return "SHORT";
   return "NONE";
  }

int DateKey(const datetime value)
  {
   MqlDateTime tm;
   TimeToStruct(value, tm);
   return tm.year * 10000 + tm.mon * 100 + tm.day;
  }

double ClampDouble(const double value, const double minValue, const double maxValue)
  {
   return MathMax(minValue, MathMin(maxValue, value));
  }

string CleanPart(string value)
  {
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
  }

double PipSize(const string symbol)
  {
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

bool ParseSymbols()
  {
   string parts[];
   int count = StringSplit(InpSymbols, ',', parts);
   ArrayResize(g_symbols, 0);
   ArrayResize(g_lastScannedBars, 0);

   for(int i = 0; i < count; ++i)
     {
      string symbol = CleanPart(parts[i]);
      if(symbol == "")
         continue;
      if(!SymbolSelect(symbol, true))
        {
         PrintFormat("%s: SymbolSelect failed for %s", STRATEGY_NAME, symbol);
         continue;
        }
      int size = ArraySize(g_symbols);
      ArrayResize(g_symbols, size + 1);
      ArrayResize(g_lastScannedBars, size + 1);
      g_symbols[size] = symbol;
      g_lastScannedBars[size] = 0;
     }

   return ArraySize(g_symbols) > 0;
  }

int LogFlags()
  {
   int flags = FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;
   return flags;
  }

void EnsureLogFolder()
  {
   int flags = 0;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;
   FolderCreate(InpLogFolder, flags);
  }

string LogFileName(const string suffix)
  {
   return InpLogFolder + "\\" + InpLogPrefix + "_" + ScenarioModeName() + "_" + suffix + ".csv";
  }

datetime ServerToUtc(const datetime serverTime)
  {
   return serverTime - InpBrokerUtcOffsetHours * 3600;
  }

datetime UtcToServer(const datetime utcTime)
  {
   return utcTime + InpBrokerUtcOffsetHours * 3600;
  }

datetime BuildUtcSessionStart(const datetime utcTime, const int startHour)
  {
   MqlDateTime tm;
   TimeToStruct(utcTime, tm);
   tm.hour = startHour;
   tm.min = 0;
   tm.sec = 0;
   return StructToTime(tm);
  }

void ResetSessionInfo(SessionInfo &info)
  {
   info.active = false;
   info.label = "none";
   info.index = -1;
   info.startUtcHour = -1;
   info.sessionStartUtc = 0;
   info.sessionStartServer = 0;
   info.minutesFromStart = -1;
   info.serverHour = -1;
   info.utcHour = -1;
   info.jstHour = -1;
   info.first60 = false;
   info.first120 = false;
   info.tradeWindowLabel = TradeWindowLabel();
   info.sessionKey = "";
  }

void AddSessionInfo(const datetime utcTime,
                    const int serverHour,
                    const int utcHour,
                    const string label,
                    const int index,
                    const int startUtcHour,
                    SessionInfo &sessions[])
  {
   int size = ArraySize(sessions);
   ArrayResize(sessions, size + 1);
   SessionInfo info;
   ResetSessionInfo(info);
   info.active = true;
   info.label = label;
   info.index = index;
   info.startUtcHour = startUtcHour;
   info.serverHour = serverHour;
   info.utcHour = utcHour;
   info.jstHour = (utcHour + 9) % 24;
   info.sessionStartUtc = BuildUtcSessionStart(utcTime, info.startUtcHour);
   info.sessionStartServer = UtcToServer(info.sessionStartUtc);
   info.minutesFromStart = (int)((utcTime - info.sessionStartUtc) / 60);
   info.first60 = info.minutesFromStart >= 0 && info.minutesFromStart < 60;
   info.first120 = info.minutesFromStart >= 0 && info.minutesFromStart < 120;
   info.tradeWindowLabel = TradeWindowLabel();
   info.sessionKey = info.label + "_" + TimeToString(info.sessionStartUtc, TIME_DATE | TIME_MINUTES);
   sessions[size] = info;
  }

int BuildSessionInfos(const datetime serverTime, SessionInfo &sessions[])
  {
   ArrayResize(sessions, 0);
   MqlDateTime serverTm;
   TimeToStruct(serverTime, serverTm);
   datetime utcTime = ServerToUtc(serverTime);
   MqlDateTime utcTm;
   TimeToStruct(utcTime, utcTm);

   if(utcTm.hour >= 0 && utcTm.hour <= 8)
      AddSessionInfo(utcTime, serverTm.hour, utcTm.hour, "tokyo", 0, 0, sessions);
   if(utcTm.hour >= 7 && utcTm.hour <= 12)
      AddSessionInfo(utcTime, serverTm.hour, utcTm.hour, "london", 1, 7, sessions);
   if(utcTm.hour >= 13 && utcTm.hour <= 15)
      AddSessionInfo(utcTime, serverTm.hour, utcTm.hour, "london_newyork_overlap", 2, 13, sessions);
   if(utcTm.hour >= 16 && utcTm.hour <= 21)
      AddSessionInfo(utcTime, serverTm.hour, utcTm.hour, "new_york", 3, 16, sessions);

   return ArraySize(sessions);
  }

bool BuildSessionInfo(const datetime serverTime, SessionInfo &info)
  {
   SessionInfo sessions[];
   if(BuildSessionInfos(serverTime, sessions) <= 0)
     {
      ResetSessionInfo(info);
      return false;
     }
   info = sessions[0];
   return true;
  }

bool IsWithinTradeWindow(const SessionInfo &info)
  {
   if(!info.active || !ScenarioAllowsSession(info.label))
      return false;
   int minutes = EffectiveWindowMinutes();
   return info.minutesFromStart >= 0 && info.minutesFromStart < minutes;
  }

bool HasKey(const string &keys[], const string key)
  {
   for(int i = 0; i < ArraySize(keys); ++i)
     {
      if(keys[i] == key)
         return true;
     }
   return false;
  }

void AddKey(string &keys[], const string key)
  {
   if(key == "" || HasKey(keys, key))
      return;
   int size = ArraySize(keys);
   ArrayResize(keys, size + 1);
   keys[size] = key;
  }

bool SessionAlreadyConsumed(const SignalPlan &plan)
  {
   if(IsOneSymbolPerSessionScenario() && HasKey(g_consumedSessionKeys, plan.sessionKey))
      return true;
   if(HasKey(g_consumedSymbolSessionKeys, plan.symbolSessionKey))
      return true;
   return false;
  }

void MarkSessionConsumed(const SignalPlan &plan)
  {
   AddKey(g_consumedSymbolSessionKeys, plan.symbolSessionKey);
   if(IsOneSymbolPerSessionScenario())
      AddKey(g_consumedSessionKeys, plan.sessionKey);
  }

string SelectedSymbolForSession(const string sessionKey)
  {
   for(int i = 0; i < ArraySize(g_selectedSessionKeys); ++i)
     {
      if(g_selectedSessionKeys[i] == sessionKey)
         return g_selectedSymbols[i];
     }
   return "";
  }

void SetSelectedSymbolForSession(const string sessionKey, const string symbol)
  {
   for(int i = 0; i < ArraySize(g_selectedSessionKeys); ++i)
     {
      if(g_selectedSessionKeys[i] == sessionKey)
        {
         g_selectedSymbols[i] = symbol;
         return;
        }
     }
   int size = ArraySize(g_selectedSessionKeys);
   ArrayResize(g_selectedSessionKeys, size + 1);
   ArrayResize(g_selectedSymbols, size + 1);
   g_selectedSessionKeys[size] = sessionKey;
   g_selectedSymbols[size] = symbol;
  }

bool CopyClosedRates(const string symbol,
                     const ENUM_TIMEFRAMES tf,
                     const int bars,
                     MqlRates &rates[])
  {
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(symbol, tf, 1, bars, rates);
   return copied >= bars;
  }

double SMA(const MqlRates &rates[], const int shift, const int period)
  {
   if(period <= 0 || shift < 0 || shift + period > ArraySize(rates))
      return 0.0;
   double sum = 0.0;
   for(int i = shift; i < shift + period; ++i)
      sum += rates[i].close;
   return sum / period;
  }

double ATR(const MqlRates &rates[], const int shift, const int period)
  {
   if(period <= 0 || shift < 0 || shift + period + 1 > ArraySize(rates))
      return 0.0;
   double sum = 0.0;
   for(int i = shift; i < shift + period; ++i)
     {
      double prevClose = rates[i + 1].close;
      double tr1 = rates[i].high - rates[i].low;
      double tr2 = MathAbs(rates[i].high - prevClose);
      double tr3 = MathAbs(rates[i].low - prevClose);
      sum += MathMax(tr1, MathMax(tr2, tr3));
     }
   return sum / period;
  }

double HighestHigh(const MqlRates &rates[], const int shift, const int period)
  {
   if(period <= 0 || shift < 0 || shift + period > ArraySize(rates))
      return 0.0;
   double value = rates[shift].high;
   for(int i = shift + 1; i < shift + period; ++i)
      value = MathMax(value, rates[i].high);
   return value;
  }

double LowestLow(const MqlRates &rates[], const int shift, const int period)
  {
   if(period <= 0 || shift < 0 || shift + period > ArraySize(rates))
      return 0.0;
   double value = rates[shift].low;
   for(int i = shift + 1; i < shift + period; ++i)
      value = MathMin(value, rates[i].low);
   return value;
  }

bool LatestClosedBarTime(const string symbol, datetime &barTime)
  {
   MqlRates rates[];
   if(!CopyClosedRates(symbol, InpPrimaryEntryTF, 1, rates))
      return false;
   barTime = rates[0].time;
   return barTime > 0;
  }

bool CollectRangeByTime(const string symbol,
                        const ENUM_TIMEFRAMES tf,
                        const datetime startServer,
                        const datetime endServer,
                        double &high,
                        double &low,
                        double &openPrice)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   int copied = CopyRates(symbol, tf, startServer, endServer, rates);
   if(copied <= 0)
      return false;
   high = rates[0].high;
   low = rates[0].low;
   openPrice = rates[0].open;
   for(int i = 1; i < copied; ++i)
     {
      high = MathMax(high, rates[i].high);
      low = MathMin(low, rates[i].low);
     }
   return high > 0.0 && low > 0.0;
  }

bool IsConfirmedPivotAt(const MqlRates &rates[],
                        const int shift,
                        const bool wantHigh,
                        const int depth)
  {
   int total = ArraySize(rates);
   if(shift - depth < 0 || shift + depth >= total)
      return false;

   double candidate = wantHigh ? rates[shift].high : rates[shift].low;
   for(int j = 1; j <= depth; ++j)
     {
      if(wantHigh)
        {
         if(candidate <= rates[shift - j].high || candidate <= rates[shift + j].high)
            return false;
        }
      else
        {
         if(candidate >= rates[shift - j].low || candidate >= rates[shift + j].low)
            return false;
        }
     }
   return true;
  }

void AppendDowPivot(DowPivot &pivots[],
                    const DowPivot &pivot,
                    const double minSwingDistance)
  {
   int size = ArraySize(pivots);
   if(size <= 0)
     {
      ArrayResize(pivots, 1);
      pivots[0] = pivot;
      return;
     }

   DowPivot last = pivots[size - 1];
   if(last.kind == pivot.kind)
     {
      bool moreExtreme = (pivot.kind > 0 && pivot.price > last.price) ||
                         (pivot.kind < 0 && pivot.price < last.price);
      if(moreExtreme)
         pivots[size - 1] = pivot;
      return;
     }

   if(MathAbs(pivot.price - last.price) < minSwingDistance)
      return;

   ArrayResize(pivots, size + 1);
   pivots[size] = pivot;
  }

bool CollectOrderedDowPivots(const string symbol,
                             const ENUM_TIMEFRAMES tf,
                             const int depth,
                             const int lookback,
                             DowPivot &pivots[],
                             double &atr,
                             string &state)
  {
   ArrayResize(pivots, 0);
   atr = 0.0;
   state = "none";

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = MathMax(lookback + depth + 8, InpATRPeriod + depth * 2 + 12);
   int copied = CopyRates(symbol, tf, 1, bars, rates);
   if(copied < depth * 2 + 10)
     {
      state = "data_unavailable";
      return false;
     }

   atr = ATR(rates, 0, InpATRPeriod);
   if(atr <= 0.0)
     {
      state = "invalid_atr";
      return false;
     }

   double minSwingDistance = atr * MathMax(0.0, InpDowMinSwingATR);
   int maxShift = MathMin(copied - depth - 1, lookback);
   for(int shift = maxShift; shift >= depth + 1; --shift)
     {
      if(IsConfirmedPivotAt(rates, shift, true, depth))
        {
         DowPivot pivot;
         pivot.time = rates[shift].time;
         pivot.price = rates[shift].high;
         pivot.kind = 1;
         pivot.shift = shift;
         AppendDowPivot(pivots, pivot, minSwingDistance);
        }
      if(IsConfirmedPivotAt(rates, shift, false, depth))
        {
         DowPivot pivot;
         pivot.time = rates[shift].time;
         pivot.price = rates[shift].low;
         pivot.kind = -1;
         pivot.shift = shift;
         AppendDowPivot(pivots, pivot, minSwingDistance);
        }
     }

   int count = ArraySize(pivots);
   if(count < InpDowMinPivotsForTrend)
     {
      state = "insufficient_ordered_dow_pivots";
      return false;
     }
   state = "ordered_dow_pivots_ready";
   return true;
  }

bool LastTwoDowPivotsOfKind(const DowPivot &pivots[],
                            const int kind,
                            double &latestPrice,
                            double &previousPrice,
                            datetime &latestTime,
                            datetime &previousTime)
  {
   latestPrice = 0.0;
   previousPrice = 0.0;
   latestTime = 0;
   previousTime = 0;
   int found = 0;
   for(int i = ArraySize(pivots) - 1; i >= 0; --i)
     {
      if(pivots[i].kind != kind)
         continue;
      if(found == 0)
        {
         latestPrice = pivots[i].price;
         latestTime = pivots[i].time;
         ++found;
        }
      else
        {
         previousPrice = pivots[i].price;
         previousTime = pivots[i].time;
         return true;
        }
     }
   return false;
  }

int DetermineDowTrendDirectionOnTf(const string symbol,
                                   const ENUM_TIMEFRAMES tf,
                                   double &breakLevel,
                                   double &pullbackLevel,
                                   string &state)
  {
   breakLevel = 0.0;
   pullbackLevel = 0.0;
   state = "none";

   DowPivot pivots[];
   double atr = 0.0;
   if(!CollectOrderedDowPivots(symbol, tf, InpSwingDepth, InpHTFWaveLookbackBars, pivots, atr, state))
      return 0;

   double latestHigh = 0.0;
   double previousHigh = 0.0;
   double latestLow = 0.0;
   double previousLow = 0.0;
   datetime latestHighTime = 0;
   datetime previousHighTime = 0;
   datetime latestLowTime = 0;
   datetime previousLowTime = 0;
   bool highs = LastTwoDowPivotsOfKind(pivots, 1, latestHigh, previousHigh, latestHighTime, previousHighTime);
   bool lows = LastTwoDowPivotsOfKind(pivots, -1, latestLow, previousLow, latestLowTime, previousLowTime);
   if(!highs || !lows)
     {
      state = "insufficient_ordered_dow_high_low_pairs";
      return 0;
     }

   double tolerance = atr * MathMax(0.0, InpDowStructureToleranceATR);
   bool higherHigh = latestHigh > previousHigh + tolerance;
   bool higherLow = latestLow > previousLow - tolerance;
   bool lowerLow = latestLow < previousLow - tolerance;
   bool lowerHigh = latestHigh < previousHigh + tolerance;

   if(higherHigh && higherLow && !(lowerLow && lowerHigh))
     {
      breakLevel = latestHigh;
      pullbackLevel = latestLow;
      state = "dow_trend_up_hh_hl";
      return 1;
     }
   if(lowerLow && lowerHigh && !(higherHigh && higherLow))
     {
      breakLevel = latestLow;
      pullbackLevel = latestHigh;
      state = "dow_trend_down_ll_lh";
      return -1;
     }

   state = "dow_range_or_transition";
   return 0;
  }

int DetermineOrderedDowWave3DirectionOnTf(const string symbol,
                                          const ENUM_TIMEFRAMES tf,
                                          double &breakLevel,
                                          double &pullbackLevel,
                                          string &state)
  {
   breakLevel = 0.0;
   pullbackLevel = 0.0;
   state = "none";

   DowPivot pivots[];
   double atr = 0.0;
   if(!CollectOrderedDowPivots(symbol, tf, InpSwingDepth, InpHTFWaveLookbackBars, pivots, atr, state))
      return 0;

   double latestHigh = 0.0;
   double previousHigh = 0.0;
   double latestLow = 0.0;
   double previousLow = 0.0;
   datetime latestHighTime = 0;
   datetime previousHighTime = 0;
   datetime latestLowTime = 0;
   datetime previousLowTime = 0;
   bool highs = LastTwoDowPivotsOfKind(pivots, 1, latestHigh, previousHigh, latestHighTime, previousHighTime);
   bool lows = LastTwoDowPivotsOfKind(pivots, -1, latestLow, previousLow, latestLowTime, previousLowTime);
   if(!highs || !lows)
     {
      state = "insufficient_ordered_dow_high_low_pairs";
      return 0;
     }

   MqlRates rates[];
   if(!CopyClosedRates(symbol, tf, MathMax(InpATRPeriod + 10, InpSwingDepth * 2 + 12), rates))
     {
      state = "data_unavailable";
      return 0;
     }

   double closePrice = rates[0].close;
   double breakBuffer = atr * InpHTFWaveBreakBufferATR;
   double tolerance = atr * MathMax(0.0, InpDowStructureToleranceATR);
   bool higherPullback = latestLow > previousLow - tolerance;
   bool lowerPullback = latestHigh < previousHigh + tolerance;
   bool longBreak = closePrice > latestHigh + breakBuffer;
   bool shortBreak = closePrice < latestLow - breakBuffer;

   if(longBreak && higherPullback && !(shortBreak && lowerPullback))
     {
      breakLevel = latestHigh;
      pullbackLevel = latestLow;
      state = "ordered_dow_wave3_break_above_swing_high";
      return 1;
     }
   if(shortBreak && lowerPullback && !(longBreak && higherPullback))
     {
      breakLevel = latestLow;
      pullbackLevel = latestHigh;
      state = "ordered_dow_wave3_break_below_swing_low";
      return -1;
     }

   if(longBreak && !higherPullback)
      state = "break_above_without_higher_pullback";
   else if(shortBreak && !lowerPullback)
      state = "break_below_without_lower_pullback";
   else
      state = "no_ordered_dow_wave3_break";
   return 0;
  }

bool FindConfirmedSwingLevel(const string symbol,
                             const ENUM_TIMEFRAMES tf,
                             const bool wantHigh,
                             const int depth,
                             const int lookback,
                             double &price)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = MathMax(lookback + depth + 8, depth * 2 + 10);
   int copied = CopyRates(symbol, tf, 1, bars, rates);
   if(copied < depth * 2 + 8)
      return false;

   int maxShift = MathMin(copied - depth - 1, lookback);
   for(int shift = depth + 1; shift <= maxShift; ++shift)
     {
      bool pivot = true;
      double candidate = wantHigh ? rates[shift].high : rates[shift].low;
      for(int j = 1; j <= depth; ++j)
        {
         if(wantHigh)
           {
            if(candidate <= rates[shift - j].high || candidate <= rates[shift + j].high)
              {
               pivot = false;
               break;
              }
           }
         else
           {
            if(candidate >= rates[shift - j].low || candidate >= rates[shift + j].low)
              {
               pivot = false;
               break;
              }
           }
        }
      if(pivot)
        {
         price = candidate;
         return true;
        }
     }
   return false;
  }

bool FindConfirmedSwingPair(const string symbol,
                            const ENUM_TIMEFRAMES tf,
                            const bool wantHigh,
                            const int depth,
                            const int lookback,
                            double &latestPrice,
                            double &previousPrice,
                            datetime &latestTime,
                            datetime &previousTime)
  {
   latestPrice = 0.0;
   previousPrice = 0.0;
   latestTime = 0;
   previousTime = 0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = MathMax(lookback + depth + 8, depth * 2 + 12);
   int copied = CopyRates(symbol, tf, 1, bars, rates);
   if(copied < depth * 2 + 10)
      return false;

   int found = 0;
   int maxShift = MathMin(copied - depth - 1, lookback);
   for(int shift = depth + 1; shift <= maxShift; ++shift)
     {
      bool pivot = true;
      double candidate = wantHigh ? rates[shift].high : rates[shift].low;
      for(int j = 1; j <= depth; ++j)
        {
         if(wantHigh)
           {
            if(candidate <= rates[shift - j].high || candidate <= rates[shift + j].high)
              {
               pivot = false;
               break;
              }
           }
         else
           {
            if(candidate >= rates[shift - j].low || candidate >= rates[shift + j].low)
              {
               pivot = false;
               break;
              }
           }
        }

      if(!pivot)
         continue;

      if(found == 0)
        {
         latestPrice = candidate;
         latestTime = rates[shift].time;
         ++found;
        }
      else
        {
         previousPrice = candidate;
         previousTime = rates[shift].time;
         return true;
        }
     }
   return false;
  }

int DetermineWave3DirectionOnTf(const string symbol,
                                const ENUM_TIMEFRAMES tf,
                                double &breakLevel,
                                double &pullbackLevel,
                                string &state)
  {
   if(InpUseOrderedDowFractalStructure)
      return DetermineOrderedDowWave3DirectionOnTf(symbol, tf, breakLevel, pullbackLevel, state);

   breakLevel = 0.0;
   pullbackLevel = 0.0;
   state = "none";

   MqlRates rates[];
   int requiredBars = MathMax(InpHTFWaveLookbackBars + InpSwingDepth * 2 + 12,
                              InpATRPeriod + InpSwingDepth * 2 + 12);
   if(!CopyClosedRates(symbol, tf, requiredBars, rates))
     {
      state = "data_unavailable";
      return 0;
     }

   double atr = ATR(rates, 0, InpATRPeriod);
   if(atr <= 0.0)
     {
      state = "invalid_atr";
      return 0;
     }

   double latestHigh = 0.0;
   double previousHigh = 0.0;
   double latestLow = 0.0;
   double previousLow = 0.0;
   datetime latestHighTime = 0;
   datetime previousHighTime = 0;
   datetime latestLowTime = 0;
   datetime previousLowTime = 0;

   bool highs = FindConfirmedSwingPair(symbol, tf, true, InpSwingDepth, InpHTFWaveLookbackBars,
                                       latestHigh, previousHigh, latestHighTime, previousHighTime);
   bool lows = FindConfirmedSwingPair(symbol, tf, false, InpSwingDepth, InpHTFWaveLookbackBars,
                                      latestLow, previousLow, latestLowTime, previousLowTime);
   if(!highs || !lows)
     {
      state = "insufficient_confirmed_pivots";
      return 0;
     }

   double closePrice = rates[0].close;
   double buffer = atr * InpHTFWaveBreakBufferATR;
   bool longBreak = closePrice > latestHigh + buffer;
   bool shortBreak = closePrice < latestLow - buffer;
   bool longStructure = latestLow > previousLow - atr * 0.10;
   bool shortStructure = latestHigh < previousHigh + atr * 0.10;

   if(longBreak && longStructure && !(shortBreak && shortStructure))
     {
      breakLevel = latestHigh;
      pullbackLevel = latestLow;
      state = "confirmed_break_above_swing_high";
      return 1;
     }
   if(shortBreak && shortStructure && !(longBreak && longStructure))
     {
      breakLevel = latestLow;
      pullbackLevel = latestHigh;
      state = "confirmed_break_below_swing_low";
      return -1;
     }

   if(longBreak && !longStructure)
      state = "break_above_without_higher_pullback";
   else if(shortBreak && !shortStructure)
      state = "break_below_without_lower_pullback";
   else
      state = "no_confirmed_wave3_break";
   return 0;
  }

void PopulateHtfDirectionDiagnostics(const string symbol,
                                     SignalPlan &plan,
                                     int &topDirection,
                                     int &structureDirection,
                                     double &topBreak,
                                     double &topPullback,
                                     double &structureBreak,
                                     double &structurePullback)
  {
   string topState = "";
   string structureState = "";
   if(InpUseOrderedDowFractalStructure && InpTopContextTrendOnly)
      topDirection = DetermineDowTrendDirectionOnTf(symbol, InpTopContextTF, topBreak, topPullback, topState);
   else
      topDirection = DetermineWave3DirectionOnTf(symbol, InpTopContextTF, topBreak, topPullback, topState);
   structureDirection = DetermineWave3DirectionOnTf(symbol, InpStructureTF, structureBreak, structurePullback, structureState);
   if(structureDirection == 0 && InpUseOrderedDowFractalStructure && InpAllowStructureTrendBiasWhenNoWave3)
     {
      double trendBreak = 0.0;
      double trendPullback = 0.0;
      string trendState = "";
      int trendDirection = DetermineDowTrendDirectionOnTf(symbol, InpStructureTF, trendBreak, trendPullback, trendState);
      if(trendDirection != 0)
        {
         structureDirection = trendDirection;
         structureBreak = trendBreak;
         structurePullback = trendPullback;
         structureState = "structure_trend_bias_" + trendState;
        }
     }

   plan.htfH4Wave3Direction = DirectionText(topDirection);
   plan.htfH1Wave3Direction = DirectionText(structureDirection);
   plan.h4DirectionState = topState;
   plan.h1DirectionState = structureState;
   plan.topContextDirectionState = topState;
   plan.structureDirectionState = structureState;
   plan.htfFractalAlignment = TFName(InpTopContextTF) + "_" + DirectionText(topDirection) + "_" + topState +
                              "|" + TFName(InpStructureTF) + "_" + DirectionText(structureDirection) + "_" + structureState;
   plan.htfWave3Direction = (topDirection == structureDirection && structureDirection != 0) ? DirectionText(structureDirection) : "NONE";
   plan.htfWave3Confirmed = false;
   plan.wave3AlignmentPassed = false;
  }

int DetermineHtfAllowedDirection(const string symbol, SignalPlan &plan)
  {
   double topBreak = 0.0;
   double topPullback = 0.0;
   double structureBreak = 0.0;
   double structurePullback = 0.0;
   int topDirection = 0;
   int structureDirection = 0;
   PopulateHtfDirectionDiagnostics(symbol, plan, topDirection, structureDirection,
                                   topBreak, topPullback, structureBreak, structurePullback);

   plan.htfWave3BreakLevel = structureBreak > 0.0 ? structureBreak : topBreak;
   plan.htfWave3PullbackLevel = structurePullback > 0.0 ? structurePullback : topPullback;
   plan.htfPermissionMode = HTFPermissionModeName();

   int allowed = 0;
   if(InpHTFPermissionMode == HTF_PERMISSION_STRICT_PREFILTER)
     {
      if(InpUseTopTFAsOppositeFilterOnly && structureDirection != 0 && topDirection != -structureDirection)
         allowed = structureDirection;
      else if(InpRequireStructureTFConfirmation)
        {
         if(topDirection != 0 && topDirection == structureDirection)
            allowed = topDirection;
        }
      else if(topDirection != 0)
         allowed = topDirection;
     }
   else if(InpHTFPermissionMode == HTF_PERMISSION_H1_DIRECTION_H4_NOT_OPPOSITE_PREFILTER)
     {
      if(structureDirection != 0 && topDirection != -structureDirection)
         allowed = structureDirection;
      else if(!InpRequireStructureTFConfirmation && topDirection != 0)
         allowed = topDirection;
     }
   else if(InpHTFPermissionMode == HTF_PERMISSION_H4_BIAS_H1_REVERSAL_PREFILTER)
     {
      if(topDirection != 0 && structureDirection != -topDirection)
         allowed = topDirection;
     }
   else if(InpHTFPermissionMode == HTF_PERMISSION_SOFT_PREFILTER)
     {
      if(topDirection != 0 && topDirection == structureDirection)
         allowed = topDirection;
      else
         allowed = 2;
     }
   else
      allowed = 2;

   plan.allowedDirection = AllowedDirectionText(allowed);
   if(allowed == 0)
     {
      plan.rejectedByHtfPermission = true;
      plan.reason = "htf_permission_none";
      plan.failureType = "htf_permission_none";
   }
   return allowed;
  }

bool ApplyHtfWave3Alignment(const string symbol, const int entryDirection, SignalPlan &plan)
  {
   double topBreak = 0.0;
   double topPullback = 0.0;
   double structureBreak = 0.0;
   double structurePullback = 0.0;
   int topDirection = 0;
   int structureDirection = 0;
   PopulateHtfDirectionDiagnostics(symbol, plan, topDirection, structureDirection,
                                   topBreak, topPullback, structureBreak, structurePullback);
   plan.htfAlignmentMode = HTFAlignmentModeName();
   plan.htfPermissionMode = HTFPermissionModeName();
   plan.allowedDirection = "post_filter";
   plan.htfWave3Confirmed = topDirection == entryDirection && structureDirection == entryDirection;
   plan.wave3AlignmentPassed = plan.htfWave3Confirmed;

   if(entryDirection > 0)
     {
      plan.htfWave3BreakLevel = structureBreak > 0.0 ? structureBreak : topBreak;
      plan.htfWave3PullbackLevel = structurePullback > 0.0 ? structurePullback : topPullback;
     }
   else
     {
      plan.htfWave3BreakLevel = structureBreak > 0.0 ? structureBreak : topBreak;
      plan.htfWave3PullbackLevel = structurePullback > 0.0 ? structurePullback : topPullback;
     }

   if(InpHTFAlignmentMode == HTF_ALIGNMENT_STRICT_H4_H1)
     {
      if(InpUseTopTFAsOppositeFilterOnly)
        {
         plan.wave3AlignmentPassed = structureDirection == entryDirection && topDirection != -entryDirection;
         return plan.wave3AlignmentPassed;
        }
      if(!InpRequireStructureTFConfirmation)
        {
         plan.wave3AlignmentPassed = topDirection == entryDirection;
         return plan.wave3AlignmentPassed;
        }
      return plan.htfWave3Confirmed;
     }

   if(InpHTFAlignmentMode == HTF_ALIGNMENT_H4_BIAS_H1_REVERSAL)
     {
      plan.wave3AlignmentPassed = topDirection == entryDirection && structureDirection != -entryDirection;
      if(plan.wave3AlignmentPassed && plan.htfWave3Direction == "NONE")
         plan.htfWave3Direction = DirectionText(entryDirection);
      return plan.wave3AlignmentPassed;
     }

   if(InpHTFAlignmentMode == HTF_ALIGNMENT_H1_CONFIRMED_H4_NOT_OPPOSITE)
     {
      plan.wave3AlignmentPassed = structureDirection == entryDirection && topDirection != -entryDirection;
      if(plan.wave3AlignmentPassed && plan.htfWave3Direction == "NONE")
         plan.htfWave3Direction = DirectionText(entryDirection);
      return plan.wave3AlignmentPassed;
     }

   if(InpHTFAlignmentMode == HTF_ALIGNMENT_SOFT)
     {
      plan.wave3AlignmentPassed = !(topDirection == -entryDirection && structureDirection == -entryDirection);
      if(plan.wave3AlignmentPassed)
        {
         if(topDirection == entryDirection)
            plan.score += 0.30;
         if(structureDirection == entryDirection)
            plan.score += 0.30;
         if(topDirection == entryDirection && structureDirection == entryDirection)
            plan.score += 0.20;
         if(plan.htfWave3Direction == "NONE" && (topDirection == entryDirection || structureDirection == entryDirection))
            plan.htfWave3Direction = DirectionText(entryDirection);
        }
      return plan.wave3AlignmentPassed;
     }

   return plan.htfWave3Confirmed;
  }

bool FindRecentEqualLevel(const MqlRates &rates[],
                          const bool wantHigh,
                          const int lookback,
                          const double tolerance,
                          double &level)
  {
   int maxBars = MathMin(lookback, ArraySize(rates) - 2);
   for(int i = 2; i < maxBars; ++i)
     {
      double anchor = wantHigh ? rates[i].high : rates[i].low;
      int touches = 1;
      double sum = anchor;
      for(int j = i + 1; j < maxBars; ++j)
        {
         double value = wantHigh ? rates[j].high : rates[j].low;
         if(MathAbs(value - anchor) <= tolerance)
           {
            ++touches;
            sum += value;
           }
        }
      if(touches >= 2)
        {
         level = sum / touches;
         return true;
        }
     }
   return false;
  }

bool FindRecentRejectionLevel(const MqlRates &rates[], const bool wantHigh, double &level)
  {
   int maxBars = MathMin(InpPatternLookbackBars, ArraySize(rates) - 2);
   for(int i = 1; i < maxBars; ++i)
     {
      double body = MathAbs(rates[i].close - rates[i].open);
      double range = rates[i].high - rates[i].low;
      double upper = rates[i].high - MathMax(rates[i].close, rates[i].open);
      double lower = MathMin(rates[i].close, rates[i].open) - rates[i].low;
      if(wantHigh && upper > MathMax(body * 1.5, range * 0.25))
        {
         level = rates[i].high;
         return true;
        }
      if(!wantHigh && lower > MathMax(body * 1.5, range * 0.25))
        {
         level = rates[i].low;
         return true;
        }
     }
   return false;
  }

bool FindFailedBreakoutLevel(const MqlRates &rates[],
                             const int direction,
                             const double atr,
                             double &level)
  {
   int lookback = MathMin(InpPatternLookbackBars, ArraySize(rates) - InpStructureLookbackBars - 3);
   if(lookback < 6 || atr <= 0.0)
      return false;
   for(int i = 1; i < lookback; ++i)
     {
      double recentHigh = HighestHigh(rates, i + 1, InpStructureLookbackBars);
      double recentLow = LowestLow(rates, i + 1, InpStructureLookbackBars);
      if(direction > 0 && rates[i].high > recentHigh + atr * InpBreakBufferATR && rates[i].close < recentHigh)
        {
         level = recentHigh;
         return true;
        }
      if(direction < 0 && rates[i].low < recentLow - atr * InpBreakBufferATR && rates[i].close > recentLow)
        {
         level = recentLow;
         return true;
        }
     }
   return false;
  }

bool DetectDoubleBottom(const string symbol, const MqlRates &rates[], const double atr, double &neckline, double &stopAnchor)
  {
   double tolerance = MathMax(atr * 0.22, PipSize(symbol) * InpEqualLevelTolerancePips);
   int maxBars = MathMin(InpPatternLookbackBars, ArraySize(rates) - 4);
   for(int right = 2; right < maxBars / 2; ++right)
     {
      for(int left = right + 4; left < maxBars; ++left)
        {
         if(MathAbs(rates[right].low - rates[left].low) > tolerance)
            continue;
         neckline = HighestHigh(rates, right + 1, left - right - 1);
         if(neckline <= 0.0)
            continue;
          bool broke = rates[1].close > neckline + atr * InpBreakBufferATR;
          bool retest = rates[0].low <= neckline + atr * InpRetestToleranceATR &&
                        (InpRequireRetestCloseBeyondNeckline ? rates[0].close > neckline : rates[0].close >= neckline - atr * InpBreakBufferATR);
         if(broke && retest)
           {
            stopAnchor = MathMin(rates[right].low, rates[left].low);
            return true;
           }
        }
     }
   return false;
  }

bool DetectInverseHeadAndShoulders(const MqlRates &rates[], const double atr, double &neckline, double &stopAnchor)
  {
   int maxBars = MathMin(InpPatternLookbackBars, ArraySize(rates) - 4);
   for(int right = 2; right < MathMin(12, maxBars / 2); ++right)
     {
      for(int head = right + 3; head < MathMin(maxBars - 3, right + 18); ++head)
        {
         for(int left = head + 3; left < maxBars; ++left)
           {
            double leftLow = rates[left].low;
            double headLow = rates[head].low;
            double rightLow = rates[right].low;
            if(headLow >= leftLow - atr * 0.15 || headLow >= rightLow - atr * 0.15)
               continue;
            if(MathAbs(leftLow - rightLow) > atr * 0.55)
               continue;
            double leftNeck = HighestHigh(rates, head + 1, left - head - 1);
            double rightNeck = HighestHigh(rates, right + 1, head - right - 1);
            neckline = MathMax(leftNeck, rightNeck);
             bool broke = rates[1].close > neckline + atr * InpBreakBufferATR;
             bool retest = rates[0].low <= neckline + atr * InpRetestToleranceATR &&
                           (InpRequireRetestCloseBeyondNeckline ? rates[0].close > neckline : rates[0].close >= neckline - atr * InpBreakBufferATR);
            if(neckline > 0.0 && broke && retest)
              {
               stopAnchor = headLow;
               return true;
              }
           }
        }
     }
   return false;
  }

bool DetectDoubleTop(const string symbol, const MqlRates &rates[], const double atr, double &neckline, double &stopAnchor)
  {
   double tolerance = MathMax(atr * 0.22, PipSize(symbol) * InpEqualLevelTolerancePips);
   int maxBars = MathMin(InpPatternLookbackBars, ArraySize(rates) - 4);
   for(int right = 2; right < maxBars / 2; ++right)
     {
      for(int left = right + 4; left < maxBars; ++left)
        {
         if(MathAbs(rates[right].high - rates[left].high) > tolerance)
            continue;
         neckline = LowestLow(rates, right + 1, left - right - 1);
         if(neckline <= 0.0)
            continue;
          bool broke = rates[1].close < neckline - atr * InpBreakBufferATR;
          bool retest = rates[0].high >= neckline - atr * InpRetestToleranceATR &&
                        (InpRequireRetestCloseBeyondNeckline ? rates[0].close < neckline : rates[0].close <= neckline + atr * InpBreakBufferATR);
         if(broke && retest)
           {
            stopAnchor = MathMax(rates[right].high, rates[left].high);
            return true;
           }
        }
     }
   return false;
  }

bool DetectHeadAndShoulders(const MqlRates &rates[], const double atr, double &neckline, double &stopAnchor)
  {
   int maxBars = MathMin(InpPatternLookbackBars, ArraySize(rates) - 4);
   for(int right = 2; right < MathMin(12, maxBars / 2); ++right)
     {
      for(int head = right + 3; head < MathMin(maxBars - 3, right + 18); ++head)
        {
         for(int left = head + 3; left < maxBars; ++left)
           {
            double leftHigh = rates[left].high;
            double headHigh = rates[head].high;
            double rightHigh = rates[right].high;
            if(headHigh <= leftHigh + atr * 0.15 || headHigh <= rightHigh + atr * 0.15)
               continue;
            if(MathAbs(leftHigh - rightHigh) > atr * 0.55)
               continue;
            double leftNeck = LowestLow(rates, head + 1, left - head - 1);
            double rightNeck = LowestLow(rates, right + 1, head - right - 1);
            neckline = MathMin(leftNeck, rightNeck);
             bool broke = rates[1].close < neckline - atr * InpBreakBufferATR;
             bool retest = rates[0].high >= neckline - atr * InpRetestToleranceATR &&
                           (InpRequireRetestCloseBeyondNeckline ? rates[0].close < neckline : rates[0].close <= neckline + atr * InpBreakBufferATR);
            if(neckline > 0.0 && broke && retest)
              {
               stopAnchor = headHigh;
               return true;
              }
           }
        }
     }
   return false;
  }

bool DetectLongPattern(const string symbol,
                       const MqlRates &rates[],
                       const double atr,
                       string &pattern,
                       string &trigger,
                       double &neckline,
                       double &stopAnchor,
                       double &score)
  {
   pattern = "";
   trigger = "";
   neckline = 0.0;
   stopAnchor = LowestLow(rates, 0, MathMin(8, ArraySize(rates)));
   score = 0.0;

   double fast = SMA(rates, 0, InpMAPeriodFast);
   double slow = SMA(rates, 0, InpMAPeriodSlow);
   double priorFast = SMA(rates, 4, InpMAPeriodFast);
   double priorSlow = SMA(rates, 4, InpMAPeriodSlow);
   double structureHigh = HighestHigh(rates, 3, InpStructureLookbackBars);
   double structureLow = LowestLow(rates, 2, InpStructureLookbackBars);

   double localNeck = 0.0;
   double localStop = 0.0;
   if(DetectInverseHeadAndShoulders(rates, atr, localNeck, localStop))
     {
      pattern = "inverse_head_and_shoulders";
      trigger = "neckline_break_retest";
      neckline = localNeck;
      stopAnchor = localStop;
      score = 4.5;
      return true;
     }

   if(DetectDoubleBottom(symbol, rates, atr, localNeck, localStop))
     {
      pattern = "double_bottom";
      trigger = "neckline_break_retest";
      neckline = localNeck;
      stopAnchor = localStop;
      score = 4.2;
      return true;
     }

   bool sweep = rates[1].low < structureLow - atr * InpBreakBufferATR &&
                rates[0].close > structureLow &&
                rates[0].close > rates[0].open;
   if(sweep)
     {
      pattern = "sweep_low_reclaim";
      trigger = "sweep_reclaim_retest";
      neckline = structureLow;
      stopAnchor = rates[1].low;
      score = 3.4;
      return true;
     }

   bool chochBreak = rates[1].close > structureHigh + atr * InpBreakBufferATR;
   bool retest = rates[0].low <= structureHigh + atr * InpRetestToleranceATR &&
                 rates[0].close > structureHigh - atr * InpBreakBufferATR;
   bool priorDown = priorFast < priorSlow || rates[6].close < rates[12].close;
   if(priorDown && chochBreak && retest)
     {
      pattern = "choch_up";
      trigger = "first_pullback_after_choch";
      neckline = structureHigh;
      stopAnchor = LowestLow(rates, 0, 6);
      score = 3.1;
      return true;
     }

   bool bos = fast > slow && priorFast <= priorSlow && rates[0].low <= fast + atr * InpRetestToleranceATR && rates[0].close > fast;
   if(bos)
     {
      pattern = "bos_up";
      trigger = "first_pullback_after_bos";
      neckline = fast;
      stopAnchor = LowestLow(rates, 0, 6);
      score = 2.6;
      return true;
     }

   return false;
  }

bool DetectShortPattern(const string symbol,
                        const MqlRates &rates[],
                        const double atr,
                        string &pattern,
                        string &trigger,
                        double &neckline,
                        double &stopAnchor,
                        double &score)
  {
   pattern = "";
   trigger = "";
   neckline = 0.0;
   stopAnchor = HighestHigh(rates, 0, MathMin(8, ArraySize(rates)));
   score = 0.0;

   double fast = SMA(rates, 0, InpMAPeriodFast);
   double slow = SMA(rates, 0, InpMAPeriodSlow);
   double priorFast = SMA(rates, 4, InpMAPeriodFast);
   double priorSlow = SMA(rates, 4, InpMAPeriodSlow);
   double structureHigh = HighestHigh(rates, 2, InpStructureLookbackBars);
   double structureLow = LowestLow(rates, 3, InpStructureLookbackBars);

   double localNeck = 0.0;
   double localStop = 0.0;
   if(DetectHeadAndShoulders(rates, atr, localNeck, localStop))
     {
      pattern = "head_and_shoulders";
      trigger = "neckline_break_retest";
      neckline = localNeck;
      stopAnchor = localStop;
      score = 4.5;
      return true;
     }

   if(DetectDoubleTop(symbol, rates, atr, localNeck, localStop))
     {
      pattern = "double_top";
      trigger = "neckline_break_retest";
      neckline = localNeck;
      stopAnchor = localStop;
      score = 4.2;
      return true;
     }

   bool sweep = rates[1].high > structureHigh + atr * InpBreakBufferATR &&
                rates[0].close < structureHigh &&
                rates[0].close < rates[0].open;
   if(sweep)
     {
      pattern = "sweep_high_reclaim";
      trigger = "sweep_reclaim_retest";
      neckline = structureHigh;
      stopAnchor = rates[1].high;
      score = 3.4;
      return true;
     }

   bool chochBreak = rates[1].close < structureLow - atr * InpBreakBufferATR;
   bool retest = rates[0].high >= structureLow - atr * InpRetestToleranceATR &&
                 rates[0].close < structureLow + atr * InpBreakBufferATR;
   bool priorUp = priorFast > priorSlow || rates[6].close > rates[12].close;
   if(priorUp && chochBreak && retest)
     {
      pattern = "choch_down";
      trigger = "first_pullback_after_choch";
      neckline = structureLow;
      stopAnchor = HighestHigh(rates, 0, 6);
      score = 3.1;
      return true;
     }

   bool bos = fast < slow && priorFast >= priorSlow && rates[0].high >= fast - atr * InpRetestToleranceATR && rates[0].close < fast;
   if(bos)
     {
      pattern = "bos_down";
      trigger = "first_pullback_after_bos";
      neckline = fast;
      stopAnchor = HighestHigh(rates, 0, 6);
      score = 2.6;
      return true;
     }

   return false;
  }

void ResetPatternCandidate(PatternCandidate &candidate)
  {
   candidate.valid = false;
   candidate.direction = 0;
   candidate.pattern = "";
   candidate.trigger = "";
   candidate.neckline = 0.0;
   candidate.stopAnchor = 0.0;
   candidate.score = 0.0;
   candidate.timeframeLabel = "";
   candidate.atr = 0.0;
  }

void ConsiderPatternCandidate(PatternCandidate &best,
                              const int direction,
                              const string pattern,
                              const string trigger,
                              const double neckline,
                              const double stopAnchor,
                              const double score,
                              const string timeframeLabel,
                              const double atr)
  {
   if(pattern == "" || score <= 0.0)
      return;
   if(!best.valid || score > best.score)
     {
      best.valid = true;
      best.direction = direction;
      best.pattern = pattern;
      best.trigger = trigger;
      best.neckline = neckline;
      best.stopAnchor = stopAnchor;
      best.score = score;
      best.timeframeLabel = timeframeLabel;
      best.atr = atr;
     }
  }

void UpdateTimeframeBestDiagnostics(SignalPlan &plan,
                                    const string timeframeLabel,
                                    const string pattern,
                                    const double score)
  {
   if(pattern == "" || score <= 0.0)
      return;
   if(timeframeLabel == TFName(InpPrimaryEntryTF))
     {
      if(score > plan.primaryBestScore)
        {
         plan.primaryBestScore = score;
         plan.primaryBestPattern = pattern;
        }
      if(score > plan.m15BestScore)
        {
         plan.m15BestScore = score;
         plan.m15BestPattern = pattern;
        }
      return;
     }
   if(timeframeLabel == TFName(InpSecondaryEntryTF))
     {
      if(score > plan.secondaryBestScore)
        {
         plan.secondaryBestScore = score;
         plan.secondaryBestPattern = pattern;
        }
      if(score > plan.m5BestScore)
        {
         plan.m5BestScore = score;
         plan.m5BestPattern = pattern;
        }
     }
  }

void EvaluatePatternCandidatesOnTf(const string symbol,
                                   const MqlRates &rates[],
                                   const double atr,
                                   const string timeframeLabel,
                                   const int allowedDirection,
                                   SignalPlan &plan,
                                   PatternCandidate &best)
  {
   string pattern = "";
   string trigger = "";
   double neckline = 0.0;
   double stopAnchor = 0.0;
   double score = 0.0;

   if(allowedDirection == 2 || allowedDirection > 0)
     {
      if(DetectLongPattern(symbol, rates, atr, pattern, trigger, neckline, stopAnchor, score))
        {
         plan.candidateLongDetected = true;
         UpdateTimeframeBestDiagnostics(plan, timeframeLabel, pattern, score);
         ConsiderPatternCandidate(best, 1, pattern, trigger, neckline, stopAnchor, score, timeframeLabel, atr);
        }
     }

   pattern = "";
   trigger = "";
   neckline = 0.0;
   stopAnchor = 0.0;
   score = 0.0;
   if(allowedDirection == 2 || allowedDirection < 0)
     {
      if(DetectShortPattern(symbol, rates, atr, pattern, trigger, neckline, stopAnchor, score))
        {
         plan.candidateShortDetected = true;
         UpdateTimeframeBestDiagnostics(plan, timeframeLabel, pattern, score);
         ConsiderPatternCandidate(best, -1, pattern, trigger, neckline, stopAnchor, score, timeframeLabel, atr);
        }
     }
  }

void ApplySelectedCandidateToPlan(SignalPlan &plan, const PatternCandidate &candidate)
  {
   plan.entryPattern = candidate.pattern;
   plan.entryTrigger = candidate.trigger;
   plan.necklineLevel = candidate.neckline;
   plan.score = candidate.score;
   plan.basePatternScore = candidate.score;
   plan.atr = candidate.atr;
   plan.ltfWave3Direction = DirectionText(candidate.direction);
   plan.ltfWave3Timeframe = candidate.timeframeLabel;
   plan.selectedCandidateDirection = DirectionText(candidate.direction);
   plan.selectedCandidateTimeframe = candidate.timeframeLabel;
   plan.selectedCandidatePattern = candidate.pattern;
  }

double RetestReferenceScore(const string referenceType)
  {
   if(referenceType == "none" || referenceType == "")
      return 0.0;
   double score = 0.15;
   if(StringFind(referenceType, "neckline_level") >= 0)
      score = MathMax(score, 0.20);
   if(StringFind(referenceType, "opening_range_high") >= 0 ||
      StringFind(referenceType, "opening_range_low") >= 0)
      score = MathMax(score, 0.15);
   if(StringFind(referenceType, "session_high") >= 0 ||
      StringFind(referenceType, "session_low") >= 0)
      score = MathMax(score, 0.10);
   return score;
  }

double TargetRoomScore(const SignalPlan &plan)
  {
   if(plan.cleanPathToTarget || plan.nearestObstacleType == "none")
      return 0.35;
   if(plan.nearestObstacleDistanceR >= 1.50)
      return 0.35;
   if(plan.nearestObstacleDistanceR >= 1.00)
      return 0.15;
   if(plan.nearestObstacleDistanceR > 0.0 && plan.nearestObstacleDistanceR < 0.80)
      return -0.30;
   return 0.0;
  }

bool FindFibImpulseOnTf(const string symbol,
                        const ENUM_TIMEFRAMES tf,
                        const int direction,
                        double &impulseHigh,
                        double &impulseLow)
  {
   double latestHigh = 0.0;
   double previousHigh = 0.0;
   double latestLow = 0.0;
   double previousLow = 0.0;
   datetime latestHighTime = 0;
   datetime previousHighTime = 0;
   datetime latestLowTime = 0;
   datetime previousLowTime = 0;
   bool highs = FindConfirmedSwingPair(symbol, tf, true, InpSwingDepth, InpHTFWaveLookbackBars,
                                       latestHigh, previousHigh, latestHighTime, previousHighTime);
   bool lows = FindConfirmedSwingPair(symbol, tf, false, InpSwingDepth, InpHTFWaveLookbackBars,
                                      latestLow, previousLow, latestLowTime, previousLowTime);
   if(!highs || !lows || latestHigh <= latestLow)
      return false;

   impulseHigh = latestHigh;
   impulseLow = latestLow;
   return impulseHigh > impulseLow;
  }

void ResetFibDiagnostics(SignalPlan &plan)
  {
   plan.fibScore = 0.0;
   plan.fibSourceTF = "none";
   plan.fibImpulseHigh = 0.0;
   plan.fibImpulseLow = 0.0;
   plan.fibRetraceRatio = 0.0;
   plan.fibZone = "none";
   plan.fibRequiredPass = !InpRequireFibPullbackZone;
  }

bool ApplyFibPullbackDiagnostics(SignalPlan &plan, const int direction)
  {
   ResetFibDiagnostics(plan);

   double impulseHigh = 0.0;
   double impulseLow = 0.0;
   ENUM_TIMEFRAMES sourceTf = InpStructureTF;
   bool found = FindFibImpulseOnTf(plan.symbol, InpStructureTF, direction, impulseHigh, impulseLow);
   if(!found)
     {
      sourceTf = InpTopContextTF;
      found = FindFibImpulseOnTf(plan.symbol, InpTopContextTF, direction, impulseHigh, impulseLow);
     }

   if(!found || impulseHigh <= impulseLow)
     {
      plan.fibZone = "no_confirmed_impulse";
      plan.fibRequiredPass = !InpRequireFibPullbackZone;
      if(InpRequireFibPullbackZone)
        {
         plan.reason = "fib_impulse_unavailable";
         plan.failureType = "fib_required_failed";
        }
      return plan.fibRequiredPass;
     }

   double range = impulseHigh - impulseLow;
   double retrace = 0.0;
   if(direction > 0)
      retrace = (impulseHigh - plan.entry) / range;
   else
      retrace = (plan.entry - impulseLow) / range;

   plan.fibSourceTF = TFName(sourceTf);
   plan.fibImpulseHigh = impulseHigh;
   plan.fibImpulseLow = impulseLow;
   plan.fibRetraceRatio = retrace;
   plan.fibZone = "outside";
   if(retrace >= InpFibPreferredMin && retrace <= InpFibPreferredMax)
     {
      plan.fibZone = "preferred_382_618";
      plan.fibScore = InpUseFibPullbackScore ? 0.25 : 0.0;
     }
   else if(retrace > InpFibPreferredMax && retrace <= InpFibDeepMax)
     {
      plan.fibZone = "deep_618_786";
      plan.fibScore = InpUseFibPullbackScore ? 0.10 : 0.0;
     }

   plan.fibRequiredPass = !InpRequireFibPullbackZone ||
                          plan.fibZone == "preferred_382_618" ||
                          plan.fibZone == "deep_618_786";
   if(!plan.fibRequiredPass)
     {
      plan.reason = "fib_zone_required_failed";
      plan.failureType = "fib_required_failed";
     }
   return plan.fibRequiredPass;
  }

void ApplyScoreComponents(SignalPlan &plan)
  {
   plan.retestReferenceDistanceAtr = 0.0;
   if(plan.retestReferencePrice > 0.0 && plan.atr > 0.0)
      plan.retestReferenceDistanceAtr = MathAbs(plan.entry - plan.retestReferencePrice) / plan.atr;

   double existingNonPatternScore = MathMax(0.0, plan.score - plan.basePatternScore);
   plan.timeScoreRemovedFlag = true;
   plan.retestScore = RetestReferenceScore(plan.retestReferenceType);
   plan.targetRoomScore = TargetRoomScore(plan);
   plan.score = plan.basePatternScore + existingNonPatternScore +
                plan.retestScore + plan.targetRoomScore + plan.fibScore;

   plan.finalScore = plan.score;
  }

void ResetPlan(SignalPlan &plan, const string symbol)
  {
   plan.valid = false;
   plan.signalBlocked = false;
   plan.symbol = symbol;
   plan.direction = "NONE";
   plan.strategy = ScenarioModeName();
   plan.serverTime = 0;
   plan.serverHour = 0;
   plan.utcHour = 0;
   plan.jstHour = 0;
   plan.sessionLabel = "none";
   plan.sessionStartUtc = 0;
   plan.minutesFromSessionStart = -1;
   plan.tradeWindowLabel = TradeWindowLabel();
   plan.isWithinFirst60 = false;
   plan.isWithinFirst120 = false;
   plan.brokerUtcOffsetUsed = InpBrokerUtcOffsetHours;
   plan.selectedSymbolForSession = "";
   plan.selectedReason = "";
   plan.sessionCandidateSymbolMap = "";
   plan.sessionCandidateSymbols = "";
   plan.entryPattern = "";
   plan.entryTrigger = "";
   plan.necklineLevel = 0.0;
   plan.ltfWave3Direction = "NONE";
   plan.ltfWave3Timeframe = TFName(InpPrimaryEntryTF);
   plan.topContextTF = TFName(InpTopContextTF);
   plan.structureTF = TFName(InpStructureTF);
   plan.primaryEntryTF = TFName(InpPrimaryEntryTF);
   plan.secondaryEntryTF = TFName(InpSecondaryEntryTF);
   plan.useSecondaryEntryTF = InpUseSecondaryEntryTF;
   plan.htfAlignmentMode = HTFAlignmentModeName();
   plan.htfPermissionMode = HTFPermissionModeName();
   plan.allowedDirection = UsesHtfPrefilter() ? "none" : "post_filter";
   plan.htfWave3Direction = "NONE";
   plan.htfWave3Confirmed = false;
   plan.htfH4Wave3Direction = "NONE";
   plan.htfH1Wave3Direction = "NONE";
   plan.h4DirectionState = "none";
   plan.h1DirectionState = "none";
   plan.topContextDirectionState = "none";
   plan.structureDirectionState = "none";
   plan.htfFractalAlignment = "none";
   plan.htfWave3BreakLevel = 0.0;
   plan.htfWave3PullbackLevel = 0.0;
   plan.wave3AlignmentPassed = false;
   plan.rejectedByHtfPermission = false;
   plan.candidateLongDetected = false;
   plan.candidateShortDetected = false;
   plan.selectedCandidateDirection = "NONE";
   plan.selectedCandidateTimeframe = "none";
   plan.selectedCandidatePattern = "none";
   plan.primaryBestPattern = "none";
   plan.primaryBestScore = 0.0;
   plan.secondaryBestPattern = "none";
   plan.secondaryBestScore = 0.0;
   plan.m15BestPattern = "none";
   plan.m15BestScore = 0.0;
   plan.m5BestPattern = "none";
   plan.m5BestScore = 0.0;
   plan.htfNearestResistance = 0.0;
   plan.htfNearestSupport = 0.0;
   plan.nearestObstaclePrice = 0.0;
   plan.nearestObstacleType = "none";
   plan.nearestObstacleDistancePrice = 0.0;
   plan.nearestObstacleDistanceR = 0.0;
   plan.retestReferenceType = "none";
   plan.retestReferencePrice = 0.0;
   plan.retestReferenceCount = 0;
   plan.retestReferenceDistanceAtr = 0.0;
   plan.targetRoomScore = 0.0;
   plan.retestScore = 0.0;
   ResetFibDiagnostics(plan);
   plan.basePatternScore = 0.0;
   plan.timeBucket = "outside";
   plan.timeScoreRemovedFlag = false;
   plan.candidateOrderableBeforeSessionSelection = false;
   plan.rejectedBeforeSelectionReason = "none";
   plan.sessionConsumedReason = "not_consumed";
   plan.finalScore = 0.0;
   plan.initialRiskPriceDistance = 0.0;
   plan.targetRewardMultiple = EffectiveTargetRewardMultiple();
   plan.targetPrice = 0.0;
   plan.cleanPathToTarget = true;
   plan.hardObstaclePresentBeforeTarget = false;
   plan.softObstaclePresentBeforeTarget = false;
   plan.obstacleBlocked = false;
   plan.obstacleBlockReason = "not_blocked";
   plan.obstacleCountBeforeTarget = 0;
   plan.hardObstacleCountBeforeTarget = 0;
   plan.softObstacleCountBeforeTarget = 0;
   plan.entry = 0.0;
   plan.stopLoss = 0.0;
   plan.takeProfit = 0.0;
   plan.riskPrice = 0.0;
   plan.rewardR = EffectiveTargetRewardMultiple();
   plan.atr = 0.0;
   plan.spreadPoints = 0.0;
   plan.score = 0.0;
   plan.failureType = "other";
   plan.reason = "";
   plan.sessionInvalidated = false;
   plan.invalidationReason = "not_invalidated";
   plan.sessionKey = "";
   plan.symbolSessionKey = "";
  }

void ApplySessionInfo(SignalPlan &plan, const SessionInfo &info)
  {
   plan.serverHour = info.serverHour;
   plan.utcHour = info.utcHour;
   plan.jstHour = info.jstHour;
   plan.sessionLabel = info.label;
   plan.sessionStartUtc = info.sessionStartUtc;
   plan.minutesFromSessionStart = info.minutesFromStart;
   plan.timeBucket = TimeBucketLabel(info.minutesFromStart);
   plan.tradeWindowLabel = info.tradeWindowLabel;
   plan.isWithinFirst60 = info.first60;
   plan.isWithinFirst120 = info.first120;
   plan.sessionKey = info.sessionKey;
   plan.symbolSessionKey = plan.symbol + "_" + info.sessionKey;
   plan.sessionCandidateSymbols = CandidateSymbolsForSession(info.label);
   plan.sessionCandidateSymbolMap = CandidateSymbolMapForSession(info.label);
  }

bool FillTradeLevels(SignalPlan &plan, const int direction, const double stopAnchor)
  {
   MqlTick tick;
   if(!SymbolInfoTick(plan.symbol, tick))
     {
      plan.reason = "tick_unavailable";
      return false;
     }

   double point = SymbolInfoDouble(plan.symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(plan.symbol, SYMBOL_DIGITS);
   if(point <= 0.0 || plan.atr <= 0.0)
     {
      plan.reason = "invalid_symbol_or_atr";
      return false;
     }

   plan.spreadPoints = (tick.ask - tick.bid) / point;
   double spreadATR = (tick.ask - tick.bid) / plan.atr;
   if(spreadATR > InpMaxSpreadATR)
     {
      plan.failureType = "spread_too_high";
      plan.reason = "spread_too_high";
      plan.signalBlocked = true;
     }

   int stopsLevel = (int)SymbolInfoInteger(plan.symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minBrokerDistance = (stopsLevel + 2) * point;
   double minStopDistance = MathMax(plan.atr * InpMinSL_ATR, minBrokerDistance);
   double maxStopDistance = plan.atr * InpMaxSL_ATR;
   double stopBuffer = MathMax(plan.atr * InpStopBufferATR, minBrokerDistance);

   if(direction > 0)
     {
      plan.direction = "LONG";
      plan.entry = tick.ask;
      plan.stopLoss = stopAnchor - stopBuffer;
      if(plan.entry - plan.stopLoss < minStopDistance)
         plan.stopLoss = plan.entry - minStopDistance;
      if(plan.entry - plan.stopLoss > maxStopDistance)
         plan.stopLoss = plan.entry - maxStopDistance;
      plan.riskPrice = MathAbs(plan.entry - plan.stopLoss);
      plan.targetPrice = plan.entry + plan.riskPrice * plan.targetRewardMultiple;
      plan.takeProfit = plan.targetPrice;
     }
   else
     {
      plan.direction = "SHORT";
      plan.entry = tick.bid;
      plan.stopLoss = stopAnchor + stopBuffer;
      if(plan.stopLoss - plan.entry < minStopDistance)
         plan.stopLoss = plan.entry + minStopDistance;
      if(plan.stopLoss - plan.entry > maxStopDistance)
         plan.stopLoss = plan.entry + maxStopDistance;
      plan.riskPrice = MathAbs(plan.entry - plan.stopLoss);
      plan.targetPrice = plan.entry - plan.riskPrice * plan.targetRewardMultiple;
      plan.takeProfit = plan.targetPrice;
     }

   if(plan.riskPrice <= 0.0)
     {
      plan.reason = "invalid_risk";
      return false;
     }

   if(MathAbs(plan.takeProfit - plan.entry) < minBrokerDistance)
     {
      plan.reason = "target_inside_stop_level";
      return false;
     }

   plan.entry = NormalizeDouble(plan.entry, digits);
   plan.stopLoss = NormalizeDouble(plan.stopLoss, digits);
   plan.takeProfit = NormalizeDouble(plan.takeProfit, digits);
   plan.targetPrice = NormalizeDouble(plan.targetPrice, digits);
   plan.riskPrice = MathAbs(plan.entry - plan.stopLoss);
   plan.initialRiskPriceDistance = plan.riskPrice;
   plan.rewardR = MathAbs(plan.takeProfit - plan.entry) / MathMax(plan.riskPrice, point);
   return plan.riskPrice > 0.0;
  }

bool PriceBeforeTarget(const SignalPlan &plan, const double price)
  {
   if(plan.riskPrice <= 0.0)
      return false;
   if(plan.direction == "LONG")
      return price > plan.entry && price <= plan.targetPrice;
   if(plan.direction == "SHORT")
      return price < plan.entry && price >= plan.targetPrice;
   return false;
  }

void UpdateNearestHtfLevels(SignalPlan &plan, const double price)
  {
   if(price <= 0.0)
      return;
   if(price > plan.entry)
     {
      if(plan.htfNearestResistance <= 0.0 ||
         MathAbs(price - plan.entry) < MathAbs(plan.htfNearestResistance - plan.entry))
         plan.htfNearestResistance = price;
     }
   if(price < plan.entry)
     {
      if(plan.htfNearestSupport <= 0.0 ||
         MathAbs(price - plan.entry) < MathAbs(plan.htfNearestSupport - plan.entry))
         plan.htfNearestSupport = price;
     }
  }

string ObstacleBlockReason(const SignalPlan &plan, const string obstacleType)
  {
   if(StringFind(obstacleType, "previous_day") >= 0)
      return "previous_day_level_blocked";
   if(StringFind(obstacleType, "previous_week") >= 0)
      return "previous_week_level_blocked";
   if(StringFind(obstacleType, "session_") >= 0 ||
      StringFind(obstacleType, "pre_session") >= 0 ||
      StringFind(obstacleType, "opening_range") >= 0)
      return "session_level_blocked";
   if(StringFind(obstacleType, "neckline") >= 0)
      return "neckline_level_blocked";
   if(StringFind(obstacleType, "h4_") >= 0 || StringFind(obstacleType, "h1_") >= 0 ||
      StringFind(obstacleType, "top_context") >= 0 || StringFind(obstacleType, "structure") >= 0)
      return plan.direction == "LONG" ? "htf_resistance_blocked" : "htf_support_blocked";
   return "obstacle_before_target";
  }

void RegisterObstacle(SignalPlan &plan,
                      const string obstacleType,
                      const double price,
                      const bool hardObstacle)
  {
   if(price <= 0.0 || plan.riskPrice <= 0.0)
      return;

   UpdateNearestHtfLevels(plan, price);
   if(!PriceBeforeTarget(plan, price))
      return;

   double distancePrice = MathAbs(price - plan.entry);
   double distanceR = distancePrice / plan.riskPrice;
   ++plan.obstacleCountBeforeTarget;
   if(hardObstacle)
      ++plan.hardObstacleCountBeforeTarget;
   else
      ++plan.softObstacleCountBeforeTarget;

   if(hardObstacle)
      plan.hardObstaclePresentBeforeTarget = true;
   else
      plan.softObstaclePresentBeforeTarget = true;

   if(plan.nearestObstaclePrice <= 0.0 || distanceR < plan.nearestObstacleDistanceR)
     {
      plan.nearestObstaclePrice = price;
      plan.nearestObstacleType = obstacleType;
      plan.nearestObstacleDistancePrice = distancePrice;
      plan.nearestObstacleDistanceR = distanceR;
     }

   if(hardObstacle || InpUseSoftObstacleAsHardFilter)
     {
      if(distanceR < plan.targetRewardMultiple)
        {
         plan.cleanPathToTarget = false;
         if(UsesCleanTargetPath() && !plan.obstacleBlocked)
           {
            plan.obstacleBlocked = true;
            plan.obstacleBlockReason = ObstacleBlockReason(plan, obstacleType);
           }
        }
     }
   else
      plan.cleanPathToTarget = false;
  }

void RegisterRetestReference(SignalPlan &plan,
                             const string referenceType,
                             const double price)
  {
   if(price <= 0.0)
      return;

   ++plan.retestReferenceCount;
   double distance = MathAbs(price - plan.entry);
   if(plan.retestReferenceType == "none")
      plan.retestReferenceType = referenceType;
   else if(StringFind(plan.retestReferenceType, referenceType) < 0)
      plan.retestReferenceType += "|" + referenceType;

   if(plan.retestReferencePrice <= 0.0 || distance < MathAbs(plan.retestReferencePrice - plan.entry))
      plan.retestReferencePrice = price;
  }

bool IsBreakoutRetestReferenceType(const string obstacleType, const string direction)
  {
   if(StringFind(obstacleType, "neckline") >= 0)
      return true;
   if(direction == "LONG")
     {
      return obstacleType == "session_high" ||
             obstacleType == "opening_range_high";
     }
   if(direction == "SHORT")
     {
      return obstacleType == "session_low" ||
             obstacleType == "opening_range_low";
     }
   return false;
  }

bool RegisterObstacleOrRetestReference(SignalPlan &plan,
                                       const string obstacleType,
                                       const double price,
                                       const bool hardObstacle)
  {
   if(price <= 0.0)
      return false;

   double buffer = plan.atr * InpRetestToleranceATR;
   bool brokenBehindEntry = false;
   if(plan.direction == "LONG")
      brokenBehindEntry = price <= plan.entry + buffer;
   else if(plan.direction == "SHORT")
      brokenBehindEntry = price >= plan.entry - buffer;

   if(brokenBehindEntry && IsBreakoutRetestReferenceType(obstacleType, plan.direction))
     {
      RegisterRetestReference(plan, obstacleType, price);
      UpdateNearestHtfLevels(plan, price);
      return true;
     }

   RegisterObstacle(plan, obstacleType, price, hardObstacle);
   return false;
  }

double RoundNumberStep(const string symbol)
  {
   if(InpRoundNumberStepPips <= 0.0)
      return 0.0;
   return InpRoundNumberStepPips * PipSize(symbol);
  }

void AddRoundNumberObstacle(SignalPlan &plan)
  {
   double step = RoundNumberStep(plan.symbol);
   if(step <= 0.0)
      return;
   double level = 0.0;
   if(plan.direction == "LONG")
      level = MathCeil(plan.entry / step) * step;
   else
      level = MathFloor(plan.entry / step) * step;
   if(MathAbs(level - plan.entry) < step * 0.05)
      level += (plan.direction == "LONG" ? step : -step);
   RegisterObstacle(plan, "round_number", level, false);
  }

void EvaluateTargetPathObstacles(SignalPlan &plan, const MqlRates &scan[])
  {
   plan.cleanPathToTarget = true;
   plan.nearestObstaclePrice = 0.0;
   plan.nearestObstacleType = "none";
   plan.nearestObstacleDistancePrice = 0.0;
   plan.nearestObstacleDistanceR = 0.0;
   plan.obstacleBlocked = false;
   plan.obstacleBlockReason = "not_blocked";
   plan.obstacleCountBeforeTarget = 0;
   plan.hardObstacleCountBeforeTarget = 0;
   plan.softObstacleCountBeforeTarget = 0;
   plan.hardObstaclePresentBeforeTarget = false;
   plan.softObstaclePresentBeforeTarget = false;
   plan.retestReferenceType = "none";
   plan.retestReferencePrice = 0.0;
   plan.retestReferenceCount = 0;

   double level = 0.0;
   RegisterObstacle(plan, "previous_day_high", iHigh(plan.symbol, PERIOD_D1, 1), true);
   RegisterObstacle(plan, "previous_day_low", iLow(plan.symbol, PERIOD_D1, 1), true);
   RegisterObstacle(plan, "current_day_high", iHigh(plan.symbol, PERIOD_D1, 0), false);
   RegisterObstacle(plan, "current_day_low", iLow(plan.symbol, PERIOD_D1, 0), false);
   RegisterObstacle(plan, "previous_week_high", iHigh(plan.symbol, PERIOD_W1, 1), true);
   RegisterObstacle(plan, "previous_week_low", iLow(plan.symbol, PERIOD_W1, 1), true);

   if(FindConfirmedSwingLevel(plan.symbol, InpTopContextTF, true, InpSwingDepth, InpHTFLookbackBars, level))
      RegisterObstacle(plan, "top_context_confirmed_swing_high", level, true);
   if(FindConfirmedSwingLevel(plan.symbol, InpTopContextTF, false, InpSwingDepth, InpHTFLookbackBars, level))
      RegisterObstacle(plan, "top_context_confirmed_swing_low", level, true);
   if(FindConfirmedSwingLevel(plan.symbol, InpStructureTF, true, InpSwingDepth, InpHTFLookbackBars, level))
      RegisterObstacle(plan, "structure_confirmed_swing_high", level, true);
   if(FindConfirmedSwingLevel(plan.symbol, InpStructureTF, false, InpSwingDepth, InpHTFLookbackBars, level))
      RegisterObstacle(plan, "structure_confirmed_swing_low", level, true);

   double sessionHigh = 0.0;
   double sessionLow = 0.0;
   double sessionOpen = 0.0;
   if(CollectRangeByTime(plan.symbol, InpPrimaryEntryTF, UtcToServer(plan.sessionStartUtc), plan.serverTime,
                         sessionHigh, sessionLow, sessionOpen))
     {
      RegisterObstacleOrRetestReference(plan, "session_high", sessionHigh, true);
      RegisterObstacleOrRetestReference(plan, "session_low", sessionLow, true);
     }

   double preHigh = 0.0;
   double preLow = 0.0;
   double preOpen = 0.0;
   datetime sessionStartServer = UtcToServer(plan.sessionStartUtc);
   if(CollectRangeByTime(plan.symbol, InpPrimaryEntryTF, sessionStartServer - InpPreSessionMinutes * 60,
                         sessionStartServer - 60, preHigh, preLow, preOpen))
     {
      RegisterObstacle(plan, "pre_session_high", preHigh, true);
      RegisterObstacle(plan, "pre_session_low", preLow, true);
     }

   double openHigh = 0.0;
   double openLow = 0.0;
   double openOpen = 0.0;
   if(CollectRangeByTime(plan.symbol, InpPrimaryEntryTF, sessionStartServer,
                         sessionStartServer + InpOpeningRangeMinutes * 60,
                         openHigh, openLow, openOpen))
     {
      RegisterObstacleOrRetestReference(plan, "opening_range_high", openHigh, true);
      RegisterObstacleOrRetestReference(plan, "opening_range_low", openLow, true);
     }

   if(plan.necklineLevel > 0.0)
      RegisterObstacleOrRetestReference(plan, "neckline_level", plan.necklineLevel, true);
   if(FindFailedBreakoutLevel(scan, plan.direction == "LONG" ? 1 : -1, plan.atr, level))
      RegisterObstacle(plan, "failed_breakout_level", level, true);

   double tolerance = MathMax(InpEqualLevelTolerancePips * PipSize(plan.symbol), plan.atr * InpEqualLevelToleranceATR);
   if(FindRecentEqualLevel(scan, true, InpPatternLookbackBars, tolerance, level))
      RegisterObstacle(plan, "recent_equal_highs", level, false);
   if(FindRecentEqualLevel(scan, false, InpPatternLookbackBars, tolerance, level))
      RegisterObstacle(plan, "recent_equal_lows", level, false);
   if(FindRecentRejectionLevel(scan, true, level))
      RegisterObstacle(plan, "recent_rejection_zone", level, false);
   if(FindRecentRejectionLevel(scan, false, level))
      RegisterObstacle(plan, "wick_cluster_zone", level, false);

   double recentHigh = HighestHigh(scan, 1, MathMin(12, ArraySize(scan) - 2));
   double recentLow = LowestLow(scan, 1, MathMin(12, ArraySize(scan) - 2));
   if(recentHigh > recentLow && (recentHigh - recentLow) / MathMax(plan.atr, _Point) <= 1.60)
     {
      RegisterObstacle(plan, "consolidation_zone", plan.direction == "LONG" ? recentHigh : recentLow, false);
      RegisterObstacle(plan, "price_congestion_zone", (recentHigh + recentLow) * 0.5, false);
     }
   AddRoundNumberObstacle(plan);

   if(plan.nearestObstaclePrice <= 0.0)
     {
      plan.nearestObstacleType = "none";
      plan.nearestObstacleDistanceR = 0.0;
      plan.nearestObstacleDistancePrice = 0.0;
     }

   if(UsesCleanTargetPath() && plan.obstacleBlocked)
     {
      plan.signalBlocked = true;
      plan.reason = plan.obstacleBlockReason;
      plan.failureType = plan.obstacleBlockReason;
   }
  }

bool BuildSessionReversalSignal(const string symbol, const SessionInfo &session, SignalPlan &plan)
  {
   ResetPlan(plan, symbol);

   MqlRates scan[];
   int requiredScan = MathMax(InpPatternLookbackBars + InpStructureLookbackBars + 10,
                              InpMAPeriodSlow + InpATRPeriod + 10);
   if(!CopyClosedRates(symbol, InpPrimaryEntryTF, requiredScan, scan))
     {
      plan.reason = "data_unavailable";
      return false;
     }

   plan.serverTime = scan[0].time;
   ApplySessionInfo(plan, session);
   if(!IsWithinTradeWindow(session))
      return false;
   if(!SymbolAllowedForSession(symbol, session.label))
      return false;
   if(SessionAlreadyConsumed(plan))
      return false;

   double atr = ATR(scan, 0, InpATRPeriod);
   if(atr <= 0.0)
     {
      plan.reason = "invalid_atr";
      return false;
     }
   plan.atr = atr;

   int direction = 0;
   double stopAnchor = 0.0;
   if(UsesHtfPrefilter())
     {
      int allowedDirection = DetermineHtfAllowedDirection(symbol, plan);
      if(allowedDirection == 0)
        {
         ++g_htfPermissionRejectedCount;
         return false;
        }

      PatternCandidate bestCandidate;
      ResetPatternCandidate(bestCandidate);
      EvaluatePatternCandidatesOnTf(symbol, scan, atr, TFName(InpPrimaryEntryTF),
                                    allowedDirection, plan, bestCandidate);

      if(InpUseSecondaryEntryTF && InpSecondaryEntryTF != InpPrimaryEntryTF)
        {
         MqlRates diagnostic[];
         if(CopyClosedRates(symbol, InpSecondaryEntryTF, requiredScan, diagnostic))
           {
            double diagnosticAtr = ATR(diagnostic, 0, InpATRPeriod);
            if(diagnosticAtr > 0.0)
               EvaluatePatternCandidatesOnTf(symbol, diagnostic, diagnosticAtr, TFName(InpSecondaryEntryTF),
                                             allowedDirection, plan, bestCandidate);
           }
        }

      if(!bestCandidate.valid)
         return false;

      direction = bestCandidate.direction;
      stopAnchor = bestCandidate.stopAnchor;
      ApplySelectedCandidateToPlan(plan, bestCandidate);
      plan.wave3AlignmentPassed = true;
      plan.htfWave3Confirmed = (direction > 0 && plan.htfH4Wave3Direction == "LONG" && plan.htfH1Wave3Direction == "LONG") ||
                               (direction < 0 && plan.htfH4Wave3Direction == "SHORT" && plan.htfH1Wave3Direction == "SHORT");
      if(plan.htfWave3Direction == "NONE" && allowedDirection != 2)
         plan.htfWave3Direction = DirectionText(allowedDirection);
     }
   else
     {
      PatternCandidate bestCandidate;
      ResetPatternCandidate(bestCandidate);
      EvaluatePatternCandidatesOnTf(symbol, scan, atr, TFName(InpPrimaryEntryTF),
                                    2, plan, bestCandidate);

      if(InpUseSecondaryEntryTF && InpSecondaryEntryTF != InpPrimaryEntryTF)
        {
         MqlRates diagnostic[];
         if(CopyClosedRates(symbol, InpSecondaryEntryTF, requiredScan, diagnostic))
           {
            double diagnosticAtr = ATR(diagnostic, 0, InpATRPeriod);
            if(diagnosticAtr > 0.0)
               EvaluatePatternCandidatesOnTf(symbol, diagnostic, diagnosticAtr, TFName(InpSecondaryEntryTF),
                                             2, plan, bestCandidate);
           }
        }

      if(!bestCandidate.valid)
         return false;

      direction = bestCandidate.direction;
      stopAnchor = bestCandidate.stopAnchor;
      ApplySelectedCandidateToPlan(plan, bestCandidate);
      if(!ApplyHtfWave3Alignment(symbol, direction, plan))
        {
         plan.rejectedByHtfPermission = true;
         plan.reason = "htf_wave3_alignment_failed";
         plan.failureType = "htf_wave3_alignment_failed";
         ++g_htfPermissionRejectedCount;
         return false;
        }
     }

   double sessionHigh = 0.0;
   double sessionLow = 0.0;
   double sessionOpen = 0.0;
   if(CollectRangeByTime(symbol, InpPrimaryEntryTF, session.sessionStartServer, plan.serverTime, sessionHigh, sessionLow, sessionOpen))
     {
      if(direction > 0 && sessionLow <= sessionOpen - atr * InpSessionInvalidationATR)
        {
         plan.sessionInvalidated = true;
         plan.invalidationReason = "opposite_break_first";
         plan.failureType = "opposite_break_first";
         plan.reason = "session_invalidated";
         plan.signalBlocked = true;
        }
      if(direction < 0 && sessionHigh >= sessionOpen + atr * InpSessionInvalidationATR)
        {
         plan.sessionInvalidated = true;
         plan.invalidationReason = "opposite_break_first";
         plan.failureType = "opposite_break_first";
         plan.reason = "session_invalidated";
         plan.signalBlocked = true;
        }
     }

   if(!FillTradeLevels(plan, direction, stopAnchor))
      return false;

   if(!ApplyFibPullbackDiagnostics(plan, direction))
      return false;

   EvaluateTargetPathObstacles(plan, scan);

   if(plan.entryTrigger == "neckline_break_retest")
      plan.failureType = "neckline_retest_failed";
   else if(StringFind(plan.entryTrigger, "choch") >= 0)
      plan.failureType = "choch_failed";
   else if(StringFind(plan.entryTrigger, "bos") >= 0)
      plan.failureType = "bos_pullback_failed";
   else if(StringFind(plan.entryTrigger, "sweep") >= 0)
      plan.failureType = "sweep_reclaim_failed";
   else
      plan.failureType = "no_followthrough_after_retest";

   if(plan.sessionInvalidated)
      plan.failureType = "opposite_break_first";
   if(plan.obstacleBlocked && UsesCleanTargetPath())
      plan.failureType = plan.obstacleBlockReason;

   ApplyScoreComponents(plan);

   plan.valid = true;
   return true;
  }

string SignalHeaderLine()
  {
   return "time,event,strategy,symbol,direction,server_time,server_hour,utc_hour,jst_hour," +
          "session_label,session_start_utc,minutes_from_session_start,trade_window_label,is_within_first_60min,is_within_first_120min," +
          "broker_utc_offset_used,selected_symbol_for_session,selected_reason,session_candidate_symbol_map," +
          "entry_pattern,entry_trigger,neckline_level,ltf_wave3_timeframe,top_context_tf,structure_tf,primary_entry_tf,secondary_entry_tf,use_secondary_entry_tf," +
          "htf_alignment_mode,htf_permission_mode,allowed_direction,top_context_direction_state,structure_direction_state," +
          "h4_direction_state,h1_direction_state,rejected_by_htf_permission,candidate_long_detected,candidate_short_detected," +
          "selected_candidate_direction,selected_candidate_timeframe,selected_candidate_pattern,primary_best_pattern,primary_best_score,secondary_best_pattern,secondary_best_score," +
          "m15_best_pattern,m15_best_score,m5_best_pattern,m5_best_score," +
          "htf_wave3_direction,htf_wave3_confirmed,htf_fractal_alignment,wave3_alignment_passed,htf_nearest_resistance,htf_nearest_support," +
          "nearest_obstacle_price,nearest_obstacle_type,nearest_obstacle_distance_price,nearest_obstacle_distance_r," +
          "retest_reference_type,retest_reference_price,retest_reference_distance_atr,clean_path_to_target," +
          "hard_obstacle_present_before_target,soft_obstacle_present_before_target,obstacle_blocked,obstacle_block_reason," +
          "obstacle_count_before_target,hard_obstacle_count_before_target,soft_obstacle_count_before_target," +
          "target_reward_multiple,target_price,base_pattern_score,target_room_score,retest_score,fib_source_tf,fib_impulse_high,fib_impulse_low," +
          "fib_retrace_ratio,fib_zone,fib_score,fib_required_pass,entry_price,stop_loss_price,initial_risk_price_distance," +
          "take_profit,reward_r,atr,spread_points,time_bucket,time_score_removed_flag,candidate_orderable_before_session_selection," +
          "rejected_before_selection_reason,session_consumed_reason,score,final_score,exit_type,result_r,break_even_triggered,failure_type,session_invalidated," +
          "invalidation_reason,reason";
  }

void WriteSignalRow(const SignalPlan &plan, const string eventName)
  {
   EnsureLogFolder();
   int handle = FileOpen(LogFileName("signals"), LogFlags(), ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s: signal FileOpen failed err=%d", STRATEGY_NAME, GetLastError());
      return;
     }

   bool header = (FileSize(handle) == 0);
   FileSeek(handle, 0, SEEK_END);
   if(header)
      FileWriteString(handle, SignalHeaderLine() + "\r\n");

   string line = "";
   CsvAppend(line, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
   CsvAppend(line, eventName);
   CsvAppend(line, plan.strategy);
   CsvAppend(line, plan.symbol);
   CsvAppend(line, plan.direction);
   CsvAppend(line, TimeToString(plan.serverTime, TIME_DATE | TIME_SECONDS));
   CsvAppend(line, IntegerToString(plan.serverHour));
   CsvAppend(line, IntegerToString(plan.utcHour));
   CsvAppend(line, IntegerToString(plan.jstHour));
   CsvAppend(line, plan.sessionLabel);
   CsvAppend(line, TimeToString(plan.sessionStartUtc, TIME_DATE | TIME_MINUTES));
   CsvAppend(line, IntegerToString(plan.minutesFromSessionStart));
   CsvAppend(line, plan.tradeWindowLabel);
   CsvAppend(line, BoolText(plan.isWithinFirst60));
   CsvAppend(line, BoolText(plan.isWithinFirst120));
   CsvAppend(line, IntegerToString(InpBrokerUtcOffsetHours));
   CsvAppend(line, plan.selectedSymbolForSession);
   CsvAppend(line, plan.selectedReason);
   CsvAppend(line, plan.sessionCandidateSymbolMap);
   CsvAppend(line, plan.entryPattern);
   CsvAppend(line, plan.entryTrigger);
   CsvAppend(line, DoubleToString(plan.necklineLevel, 8));
   CsvAppend(line, plan.ltfWave3Timeframe);
   CsvAppend(line, plan.topContextTF);
   CsvAppend(line, plan.structureTF);
   CsvAppend(line, plan.primaryEntryTF);
   CsvAppend(line, plan.secondaryEntryTF);
   CsvAppend(line, BoolText(plan.useSecondaryEntryTF));
   CsvAppend(line, plan.htfAlignmentMode);
   CsvAppend(line, plan.htfPermissionMode);
   CsvAppend(line, plan.allowedDirection);
   CsvAppend(line, plan.topContextDirectionState);
   CsvAppend(line, plan.structureDirectionState);
   CsvAppend(line, plan.h4DirectionState);
   CsvAppend(line, plan.h1DirectionState);
   CsvAppend(line, BoolText(plan.rejectedByHtfPermission));
   CsvAppend(line, BoolText(plan.candidateLongDetected));
   CsvAppend(line, BoolText(plan.candidateShortDetected));
   CsvAppend(line, plan.selectedCandidateDirection);
   CsvAppend(line, plan.selectedCandidateTimeframe);
   CsvAppend(line, plan.selectedCandidatePattern);
   CsvAppend(line, plan.primaryBestPattern);
   CsvAppend(line, DoubleToString(plan.primaryBestScore, 3));
   CsvAppend(line, plan.secondaryBestPattern);
   CsvAppend(line, DoubleToString(plan.secondaryBestScore, 3));
   CsvAppend(line, plan.m15BestPattern);
   CsvAppend(line, DoubleToString(plan.m15BestScore, 3));
   CsvAppend(line, plan.m5BestPattern);
   CsvAppend(line, DoubleToString(plan.m5BestScore, 3));
   CsvAppend(line, plan.htfWave3Direction);
   CsvAppend(line, BoolText(plan.htfWave3Confirmed));
   CsvAppend(line, plan.htfFractalAlignment);
   CsvAppend(line, BoolText(plan.wave3AlignmentPassed));
   CsvAppend(line, DoubleToString(plan.htfNearestResistance, 8));
   CsvAppend(line, DoubleToString(plan.htfNearestSupport, 8));
   CsvAppend(line, DoubleToString(plan.nearestObstaclePrice, 8));
   CsvAppend(line, plan.nearestObstacleType);
   CsvAppend(line, DoubleToString(plan.nearestObstacleDistancePrice, 8));
   CsvAppend(line, DoubleToString(plan.nearestObstacleDistanceR, 4));
   CsvAppend(line, plan.retestReferenceType);
   CsvAppend(line, DoubleToString(plan.retestReferencePrice, 8));
   CsvAppend(line, DoubleToString(plan.retestReferenceDistanceAtr, 4));
   CsvAppend(line, BoolText(plan.cleanPathToTarget));
   CsvAppend(line, BoolText(plan.hardObstaclePresentBeforeTarget));
   CsvAppend(line, BoolText(plan.softObstaclePresentBeforeTarget));
   CsvAppend(line, BoolText(plan.obstacleBlocked));
   CsvAppend(line, plan.obstacleBlockReason);
   CsvAppend(line, IntegerToString(plan.obstacleCountBeforeTarget));
   CsvAppend(line, IntegerToString(plan.hardObstacleCountBeforeTarget));
   CsvAppend(line, IntegerToString(plan.softObstacleCountBeforeTarget));
   CsvAppend(line, DoubleToString(plan.targetRewardMultiple, 2));
   CsvAppend(line, DoubleToString(plan.targetPrice, 8));
   CsvAppend(line, DoubleToString(plan.basePatternScore, 3));
   CsvAppend(line, DoubleToString(plan.targetRoomScore, 3));
   CsvAppend(line, DoubleToString(plan.retestScore, 3));
   CsvAppend(line, plan.fibSourceTF);
   CsvAppend(line, DoubleToString(plan.fibImpulseHigh, 8));
   CsvAppend(line, DoubleToString(plan.fibImpulseLow, 8));
   CsvAppend(line, DoubleToString(plan.fibRetraceRatio, 4));
   CsvAppend(line, plan.fibZone);
   CsvAppend(line, DoubleToString(plan.fibScore, 3));
   CsvAppend(line, BoolText(plan.fibRequiredPass));
   CsvAppend(line, DoubleToString(plan.entry, 8));
   CsvAppend(line, DoubleToString(plan.stopLoss, 8));
   CsvAppend(line, DoubleToString(plan.initialRiskPriceDistance, 8));
   CsvAppend(line, DoubleToString(plan.takeProfit, 8));
   CsvAppend(line, DoubleToString(plan.rewardR, 3));
   CsvAppend(line, DoubleToString(plan.atr, 8));
   CsvAppend(line, DoubleToString(plan.spreadPoints, 2));
   CsvAppend(line, plan.timeBucket);
   CsvAppend(line, BoolText(plan.timeScoreRemovedFlag));
   CsvAppend(line, BoolText(plan.candidateOrderableBeforeSessionSelection));
   CsvAppend(line, plan.rejectedBeforeSelectionReason);
   CsvAppend(line, plan.sessionConsumedReason);
   CsvAppend(line, DoubleToString(plan.score, 3));
   CsvAppend(line, DoubleToString(plan.finalScore, 3));
   CsvAppend(line, "none");
   CsvAppend(line, "0.0000");
   CsvAppend(line, "false");
   CsvAppend(line, plan.failureType);
   CsvAppend(line, BoolText(plan.sessionInvalidated));
   CsvAppend(line, plan.invalidationReason);
   CsvAppend(line, plan.reason);
   FileWriteString(handle, line + "\r\n");
   FileClose(handle);
  }

string ClassifyFailure(const TrackedTrade &tracked, const string exitReason, const double resultR)
  {
   if(tracked.sessionInvalidated)
      return "opposite_break_first";
   if(tracked.obstacleBlocked)
      return "obstacle_before_target";
   if(resultR <= 0.0)
     {
      if(StringFind(tracked.entryTrigger, "neckline") >= 0)
         return "neckline_retest_failed";
      if(StringFind(tracked.entryTrigger, "choch") >= 0)
         return "choch_failed";
      if(StringFind(tracked.entryTrigger, "bos") >= 0)
         return "bos_pullback_failed";
      if(StringFind(tracked.entryTrigger, "sweep") >= 0)
         return "sweep_reclaim_failed";
      return "no_followthrough_after_retest";
     }
   if(StringFind(exitReason, "TP") < 0 && resultR < tracked.rewardR * 0.5)
      return "target_not_reached_before_session_end";
   return "other";
  }

string CsvEscape(string value)
  {
   bool quote = StringFind(value, ",") >= 0 ||
                StringFind(value, "\"") >= 0 ||
                StringFind(value, "\r") >= 0 ||
                StringFind(value, "\n") >= 0;
   StringReplace(value, "\"", "\"\"");
   if(quote)
      return "\"" + value + "\"";
   return value;
  }

void CsvAppend(string &line, const string value)
  {
   if(line != "")
      line += ",";
   line += CsvEscape(value);
  }

string ExitTypeFromDeal(const TrackedTrade &tracked,
                        const string exitReason,
                        const double resultR,
                        const int holdingBars)
  {
   if(StringFind(exitReason, "TP") >= 0)
      return "tp";
   if(StringFind(exitReason, "SL") >= 0)
     {
      if(tracked.breakEvenTriggered && resultR > -0.25 && resultR < 0.35)
         return "break_even";
      return "full_sl";
     }
   if(StringFind(exitReason, "EXPERT") >= 0 || holdingBars >= InpMaxHoldBars)
      return "time";
   return "other";
  }

string TradeHeaderLine()
  {
   return "entry_time,exit_time,strategy,symbol,direction,server_time,server_hour,utc_hour,jst_hour," +
          "session_label,session_start_utc,minutes_from_session_start,trade_window_label,is_within_first_60min,is_within_first_120min," +
          "broker_utc_offset_used,selected_symbol_for_session,selected_reason,session_candidate_symbol_map," +
          "entry_pattern,entry_trigger,neckline_level,ltf_wave3_timeframe,top_context_tf,structure_tf,primary_entry_tf,secondary_entry_tf,use_secondary_entry_tf," +
          "htf_alignment_mode,htf_permission_mode,allowed_direction,top_context_direction_state,structure_direction_state," +
          "h4_direction_state,h1_direction_state,rejected_by_htf_permission,candidate_long_detected,candidate_short_detected," +
          "selected_candidate_direction,selected_candidate_timeframe,selected_candidate_pattern,primary_best_pattern,primary_best_score,secondary_best_pattern,secondary_best_score," +
          "m15_best_pattern,m15_best_score,m5_best_pattern,m5_best_score," +
          "htf_wave3_direction,htf_wave3_confirmed,htf_fractal_alignment,wave3_alignment_passed,htf_nearest_resistance,htf_nearest_support," +
          "nearest_obstacle_price,nearest_obstacle_type,nearest_obstacle_distance_r,retest_reference_type,retest_reference_price,retest_reference_distance_atr," +
          "clean_path_to_target,hard_obstacle_present_before_target,soft_obstacle_present_before_target,obstacle_blocked," +
          "target_reward_multiple,target_price,base_pattern_score,target_room_score,retest_score,fib_source_tf,fib_impulse_high,fib_impulse_low," +
          "fib_retrace_ratio,fib_zone,fib_score,fib_required_pass,time_bucket,time_score_removed_flag," +
          "candidate_orderable_before_session_selection,rejected_before_selection_reason,session_consumed_reason,final_score," +
          "entry,exit,stop_loss,take_profit,risk_price,result_r," +
          "initial_stop_loss_price,current_stop_loss_price,break_even_enabled,break_even_triggered,break_even_trigger_type," +
          "break_even_trigger_r,break_even_trigger_time,bars_to_break_even,max_favorable_r_before_exit,max_adverse_r_before_exit," +
          "exit_type,full_sl_exit,break_even_exit,tp_exit,time_exit,result_r_before_be,result_r_after_be," +
          "profit,commission,swap,net_profit,volume,reward_r,holding_bars,atr,spread_points,score,failure_type," +
          "session_invalidated,invalidation_reason,exit_reason,position_id,break_even_mode";
  }

void WriteTradeRow(const TrackedTrade &tracked,
                   const datetime exitTime,
                   const double exitPrice,
                   const double profit,
                   const double commission,
                   const double swap,
                   const string exitReason)
  {
   EnsureLogFolder();
   int handle = FileOpen(LogFileName("trades"), LogFlags(), ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s: trade FileOpen failed err=%d", STRATEGY_NAME, GetLastError());
      return;
     }

   bool header = (FileSize(handle) == 0);
   FileSeek(handle, 0, SEEK_END);
   if(header)
      FileWriteString(handle, TradeHeaderLine() + "\r\n");

   double resultR = 0.0;
   if(tracked.riskPrice > 0.0)
     {
      if(tracked.direction == "LONG")
         resultR = (exitPrice - tracked.entryPrice) / tracked.riskPrice;
      else
         resultR = (tracked.entryPrice - exitPrice) / tracked.riskPrice;
     }

   int holdingBars = 0;
   int shift = iBarShift(tracked.symbol, InpPrimaryEntryTF, tracked.entryTime, false);
   if(shift >= 0)
      holdingBars = shift;

   string failureType = ClassifyFailure(tracked, exitReason, resultR);
   string exitType = ExitTypeFromDeal(tracked, exitReason, resultR, holdingBars);
   bool fullSlExit = exitType == "full_sl";
   bool breakEvenExit = exitType == "break_even";
   bool tpExit = exitType == "tp";
   bool timeExit = exitType == "time";
   double resultRBeforeBE = tracked.breakEvenTriggered ? tracked.breakEvenTriggerR : resultR;
   double resultRAfterBE = tracked.breakEvenTriggered ? resultR - tracked.breakEvenTriggerR : 0.0;
   double netProfit = profit + commission + swap;

   string line = "";
   CsvAppend(line, TimeToString(tracked.entryTime, TIME_DATE | TIME_SECONDS));
   CsvAppend(line, TimeToString(exitTime, TIME_DATE | TIME_SECONDS));
   CsvAppend(line, tracked.strategy);
   CsvAppend(line, tracked.symbol);
   CsvAppend(line, tracked.direction);
   CsvAppend(line, TimeToString(tracked.serverTime, TIME_DATE | TIME_SECONDS));
   CsvAppend(line, IntegerToString(tracked.serverHour));
   CsvAppend(line, IntegerToString(tracked.utcHour));
   CsvAppend(line, IntegerToString(tracked.jstHour));
   CsvAppend(line, tracked.sessionLabel);
   CsvAppend(line, TimeToString(tracked.sessionStartUtc, TIME_DATE | TIME_MINUTES));
   CsvAppend(line, IntegerToString(tracked.minutesFromSessionStart));
   CsvAppend(line, tracked.tradeWindowLabel);
   CsvAppend(line, BoolText(tracked.isWithinFirst60));
   CsvAppend(line, BoolText(tracked.isWithinFirst120));
   CsvAppend(line, IntegerToString(InpBrokerUtcOffsetHours));
   CsvAppend(line, tracked.selectedSymbolForSession);
   CsvAppend(line, tracked.selectedReason);
   CsvAppend(line, tracked.sessionCandidateSymbolMap);
   CsvAppend(line, tracked.entryPattern);
   CsvAppend(line, tracked.entryTrigger);
   CsvAppend(line, DoubleToString(tracked.necklineLevel, 8));
   CsvAppend(line, tracked.ltfWave3Timeframe);
   CsvAppend(line, tracked.topContextTF);
   CsvAppend(line, tracked.structureTF);
   CsvAppend(line, tracked.primaryEntryTF);
   CsvAppend(line, tracked.secondaryEntryTF);
   CsvAppend(line, BoolText(tracked.useSecondaryEntryTF));
   CsvAppend(line, tracked.htfAlignmentMode);
   CsvAppend(line, tracked.htfPermissionMode);
   CsvAppend(line, tracked.allowedDirection);
   CsvAppend(line, tracked.topContextDirectionState);
   CsvAppend(line, tracked.structureDirectionState);
   CsvAppend(line, tracked.h4DirectionState);
   CsvAppend(line, tracked.h1DirectionState);
   CsvAppend(line, BoolText(tracked.rejectedByHtfPermission));
   CsvAppend(line, BoolText(tracked.candidateLongDetected));
   CsvAppend(line, BoolText(tracked.candidateShortDetected));
   CsvAppend(line, tracked.selectedCandidateDirection);
   CsvAppend(line, tracked.selectedCandidateTimeframe);
   CsvAppend(line, tracked.selectedCandidatePattern);
   CsvAppend(line, tracked.primaryBestPattern);
   CsvAppend(line, DoubleToString(tracked.primaryBestScore, 3));
   CsvAppend(line, tracked.secondaryBestPattern);
   CsvAppend(line, DoubleToString(tracked.secondaryBestScore, 3));
   CsvAppend(line, tracked.m15BestPattern);
   CsvAppend(line, DoubleToString(tracked.m15BestScore, 3));
   CsvAppend(line, tracked.m5BestPattern);
   CsvAppend(line, DoubleToString(tracked.m5BestScore, 3));
   CsvAppend(line, tracked.htfWave3Direction);
   CsvAppend(line, BoolText(tracked.htfWave3Confirmed));
   CsvAppend(line, tracked.htfFractalAlignment);
   CsvAppend(line, BoolText(tracked.wave3AlignmentPassed));
   CsvAppend(line, DoubleToString(tracked.htfNearestResistance, 8));
   CsvAppend(line, DoubleToString(tracked.htfNearestSupport, 8));
   CsvAppend(line, DoubleToString(tracked.nearestObstaclePrice, 8));
   CsvAppend(line, tracked.nearestObstacleType);
   CsvAppend(line, DoubleToString(tracked.nearestObstacleDistanceR, 4));
   CsvAppend(line, tracked.retestReferenceType);
   CsvAppend(line, DoubleToString(tracked.retestReferencePrice, 8));
   CsvAppend(line, DoubleToString(tracked.retestReferenceDistanceAtr, 4));
   CsvAppend(line, BoolText(tracked.cleanPathToTarget));
   CsvAppend(line, BoolText(tracked.hardObstaclePresentBeforeTarget));
   CsvAppend(line, BoolText(tracked.softObstaclePresentBeforeTarget));
   CsvAppend(line, BoolText(tracked.obstacleBlocked));
   CsvAppend(line, DoubleToString(tracked.targetRewardMultiple, 2));
   CsvAppend(line, DoubleToString(tracked.targetPrice, 8));
   CsvAppend(line, DoubleToString(tracked.basePatternScore, 3));
   CsvAppend(line, DoubleToString(tracked.targetRoomScore, 3));
   CsvAppend(line, DoubleToString(tracked.retestScore, 3));
   CsvAppend(line, tracked.fibSourceTF);
   CsvAppend(line, DoubleToString(tracked.fibImpulseHigh, 8));
   CsvAppend(line, DoubleToString(tracked.fibImpulseLow, 8));
   CsvAppend(line, DoubleToString(tracked.fibRetraceRatio, 4));
   CsvAppend(line, tracked.fibZone);
   CsvAppend(line, DoubleToString(tracked.fibScore, 3));
   CsvAppend(line, BoolText(tracked.fibRequiredPass));
   CsvAppend(line, tracked.timeBucket);
   CsvAppend(line, BoolText(tracked.timeScoreRemovedFlag));
   CsvAppend(line, BoolText(tracked.candidateOrderableBeforeSessionSelection));
   CsvAppend(line, tracked.rejectedBeforeSelectionReason);
   CsvAppend(line, tracked.sessionConsumedReason);
   CsvAppend(line, DoubleToString(tracked.finalScore, 3));
   CsvAppend(line, DoubleToString(tracked.entryPrice, 8));
   CsvAppend(line, DoubleToString(exitPrice, 8));
   CsvAppend(line, DoubleToString(tracked.stopLoss, 8));
   CsvAppend(line, DoubleToString(tracked.takeProfit, 8));
   CsvAppend(line, DoubleToString(tracked.riskPrice, 8));
   CsvAppend(line, DoubleToString(resultR, 4));
   CsvAppend(line, DoubleToString(tracked.initialStopLossPrice, 8));
   CsvAppend(line, DoubleToString(tracked.currentStopLossPrice, 8));
   CsvAppend(line, BoolText(tracked.breakEvenEnabled));
   CsvAppend(line, BoolText(tracked.breakEvenTriggered));
   CsvAppend(line, tracked.breakEvenTriggerType);
   CsvAppend(line, DoubleToString(tracked.breakEvenTriggerR, 4));
   CsvAppend(line, tracked.breakEvenTriggerTime > 0 ? TimeToString(tracked.breakEvenTriggerTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, IntegerToString(tracked.barsToBreakEven));
   CsvAppend(line, DoubleToString(tracked.maxFavorableRBeforeExit, 4));
   CsvAppend(line, DoubleToString(tracked.maxAdverseRBeforeExit, 4));
   CsvAppend(line, exitType);
   CsvAppend(line, BoolText(fullSlExit));
   CsvAppend(line, BoolText(breakEvenExit));
   CsvAppend(line, BoolText(tpExit));
   CsvAppend(line, BoolText(timeExit));
   CsvAppend(line, DoubleToString(resultRBeforeBE, 4));
   CsvAppend(line, DoubleToString(resultRAfterBE, 4));
   CsvAppend(line, DoubleToString(profit, 2));
   CsvAppend(line, DoubleToString(commission, 2));
   CsvAppend(line, DoubleToString(swap, 2));
   CsvAppend(line, DoubleToString(netProfit, 2));
   CsvAppend(line, DoubleToString(tracked.volume, 3));
   CsvAppend(line, DoubleToString(tracked.rewardR, 3));
   CsvAppend(line, IntegerToString(holdingBars));
   CsvAppend(line, DoubleToString(tracked.atr, 8));
   CsvAppend(line, DoubleToString(tracked.spreadPoints, 2));
   CsvAppend(line, DoubleToString(tracked.score, 3));
   CsvAppend(line, failureType);
   CsvAppend(line, BoolText(tracked.sessionInvalidated));
   CsvAppend(line, tracked.invalidationReason);
   CsvAppend(line, exitReason);
   CsvAppend(line, IntegerToString((int)tracked.positionId));
   CsvAppend(line, tracked.breakEvenMode);
   FileWriteString(handle, line + "\r\n");
   FileClose(handle);
  }

void WriteSummaryRow()
  {
   EnsureLogFolder();
   int handle = FileOpen(LogFileName("summary"), LogFlags(), ',');
   if(handle == INVALID_HANDLE)
      return;

   bool header = (FileSize(handle) == 0);
   FileSeek(handle, 0, SEEK_END);
   if(header)
      FileWrite(handle, "time", "strategy", "symbols", "signals", "orders_sent",
                "orders_failed", "blocked", "closed_trades", "initial_equity",
                "final_equity", "peak_equity", "daily_stopped", "drawdown_stopped",
                "trade_window_label", "target_reward_multiple", "broker_utc_offset_used",
                 "session_windows_mode", "require_h4_h1_wave3_alignment", "htf_alignment_mode",
                 "htf_permission_mode", "filter_orderable_before_session_selection",
                 "use_m5_lower_tf_wave3", "top_context_tf", "structure_tf", "primary_entry_tf",
                 "secondary_entry_tf", "use_secondary_entry_tf", "require_structure_tf_confirmation",
                 "use_top_tf_as_opposite_filter_only", "use_ordered_dow_fractal_structure",
                 "top_context_trend_only", "allow_structure_trend_bias_when_no_wave3",
                 "dow_min_swing_atr", "dow_structure_tolerance_atr",
                 "dow_min_pivots_for_trend", "use_fib_pullback_score", "require_fib_pullback_zone",
                 "fib_preferred_min", "fib_preferred_max", "fib_deep_max",
                 "require_retest_close_beyond_neckline", "break_even_mode",
                 "htf_permission_rejections", "preselection_rejections");

   string symbolsForSummary = InpSymbols;
   StringReplace(symbolsForSummary, ",", ";");

   FileWrite(handle,
              TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
              ScenarioModeName(),
              symbolsForSummary,
             IntegerToString((int)g_signalCount),
             IntegerToString((int)g_orderSentCount),
             IntegerToString((int)g_orderFailedCount),
             IntegerToString((int)g_blockedCount),
             IntegerToString((int)g_closedTradeCount),
             DoubleToString(g_initialEquity, 2),
             DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2),
             DoubleToString(g_peakEquity, 2),
             BoolText(g_dailyStopped),
             BoolText(g_drawdownStopped),
             TradeWindowLabel(),
             DoubleToString(EffectiveTargetRewardMultiple(), 2),
             IntegerToString(InpBrokerUtcOffsetHours),
             "non_exclusive_independent_start_windows",
             BoolText(InpRequireH4H1Wave3Alignment),
             HTFAlignmentModeName(),
             HTFPermissionModeName(),
             BoolText(InpFilterOrderableBeforeSessionSelection),
             BoolText(InpUseM5LowerTimeframeWave3),
             TFName(InpTopContextTF),
             TFName(InpStructureTF),
             TFName(InpPrimaryEntryTF),
             TFName(InpSecondaryEntryTF),
              BoolText(InpUseSecondaryEntryTF),
              BoolText(InpRequireStructureTFConfirmation),
              BoolText(InpUseTopTFAsOppositeFilterOnly),
              BoolText(InpUseOrderedDowFractalStructure),
              BoolText(InpTopContextTrendOnly),
              BoolText(InpAllowStructureTrendBiasWhenNoWave3),
              DoubleToString(InpDowMinSwingATR, 3),
              DoubleToString(InpDowStructureToleranceATR, 3),
              IntegerToString(InpDowMinPivotsForTrend),
              BoolText(InpUseFibPullbackScore),
              BoolText(InpRequireFibPullbackZone),
              DoubleToString(InpFibPreferredMin, 3),
              DoubleToString(InpFibPreferredMax, 3),
              DoubleToString(InpFibDeepMax, 3),
              BoolText(InpRequireRetestCloseBeyondNeckline),
              BreakEvenModeName(),
             IntegerToString((int)g_htfPermissionRejectedCount),
             IntegerToString((int)g_preselectionRejectedCount));
   FileClose(handle);
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

double PositionRiskPercent()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0)
      return 0.0;

   string symbol = PositionGetString(POSITION_SYMBOL);
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double stop = PositionGetDouble(POSITION_SL);
   double volume = PositionGetDouble(POSITION_VOLUME);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   if(stop <= 0.0 || volume <= 0.0 || tickSize <= 0.0 || tickValue <= 0.0)
      return InpRiskPerTradePercent;

   double money = MathAbs(entry - stop) / tickSize * tickValue * volume;
   return money / equity * 100.0;
  }

double CurrentTotalOpenRiskPercent()
  {
   double risk = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
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
   for(int i = PositionsTotal() - 1; i >= 0; --i)
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

int CountManagedPositions()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
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

void UpdateRiskAnchors()
  {
   datetime now = TimeCurrent();
   int dayKey = DateKey(now);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(g_dayKey != dayKey)
     {
      g_dayKey = dayKey;
      g_dayStartEquity = equity;
      g_dailyStopped = false;
     }

   if(equity > g_peakEquity)
      g_peakEquity = equity;

   if(g_dayStartEquity > 0.0 && (g_dayStartEquity - equity) / g_dayStartEquity * 100.0 >= InpDailyMaxLossPercent)
      g_dailyStopped = true;
   if(g_peakEquity > 0.0 && (g_peakEquity - equity) / g_peakEquity * 100.0 >= InpMaxDrawdownPercent)
      g_drawdownStopped = true;
  }

bool HardRiskStopped()
  {
   UpdateRiskAnchors();
   return g_dailyStopped || g_drawdownStopped;
  }

double TradeFavorableR(const TrackedTrade &tracked, const double price)
  {
   if(tracked.riskPrice <= 0.0)
      return 0.0;
   if(tracked.direction == "LONG")
      return (price - tracked.entryPrice) / tracked.riskPrice;
   if(tracked.direction == "SHORT")
      return (tracked.entryPrice - price) / tracked.riskPrice;
   return 0.0;
  }

double TradeAdverseR(const TrackedTrade &tracked, const double price)
  {
   if(tracked.riskPrice <= 0.0)
      return 0.0;
   if(tracked.direction == "LONG")
      return (tracked.entryPrice - price) / tracked.riskPrice;
   if(tracked.direction == "SHORT")
      return (price - tracked.entryPrice) / tracked.riskPrice;
   return 0.0;
  }

void UpdateTradeExcursionWithBar(TrackedTrade &tracked, const MqlRates &bar)
  {
   if(tracked.riskPrice <= 0.0)
      return;
   double favorable = 0.0;
   double adverse = 0.0;
   if(tracked.direction == "LONG")
     {
      favorable = TradeFavorableR(tracked, bar.high);
      adverse = TradeAdverseR(tracked, bar.low);
     }
   else if(tracked.direction == "SHORT")
     {
      favorable = TradeFavorableR(tracked, bar.low);
      adverse = TradeAdverseR(tracked, bar.high);
     }
   tracked.maxFavorableRBeforeExit = MathMax(tracked.maxFavorableRBeforeExit, favorable);
   tracked.maxAdverseRBeforeExit = MathMax(tracked.maxAdverseRBeforeExit, adverse);
  }

void UpdateTradeExcursionWithPrice(TrackedTrade &tracked, const double price)
  {
   tracked.maxFavorableRBeforeExit = MathMax(tracked.maxFavorableRBeforeExit, TradeFavorableR(tracked, price));
   tracked.maxAdverseRBeforeExit = MathMax(tracked.maxAdverseRBeforeExit, TradeAdverseR(tracked, price));
  }

double BreakEvenPrice(const TrackedTrade &tracked)
  {
   double point = SymbolInfoDouble(tracked.symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(tracked.symbol, SYMBOL_DIGITS);
   double offset = MathMax(0.0, InpBreakEvenOffsetPoints) * point;
   double price = tracked.entryPrice;
   if(tracked.direction == "LONG")
      price += offset;
   else if(tracked.direction == "SHORT")
      price -= offset;
   return NormalizeDouble(price, digits);
  }

bool BreakEvenTriggerReached(const TrackedTrade &tracked,
                             const MqlRates &bar,
                             double &triggerR,
                             string &triggerType)
  {
   triggerR = TradeFavorableR(tracked, bar.close);
   triggerType = "none";
   if(InpBreakEvenMode == BREAK_EVEN_DISABLED)
      return false;
   if(InpBreakEvenMode == BREAK_EVEN_AT_1_0R)
     {
      triggerType = "price_1_0r_close";
      return triggerR >= 1.0;
     }
   if(InpBreakEvenMode == BREAK_EVEN_AT_1_1R)
     {
      triggerType = "price_1_1r_close";
      return triggerR >= 1.1;
     }
   if(InpBreakEvenMode == BREAK_EVEN_TIME_30MIN_AND_0_5R_OR_1_0R)
     {
      int elapsedSeconds = (int)(bar.time - tracked.entryTime);
      if(triggerR >= 1.0)
        {
         triggerType = "price_1_0r_close";
         return true;
        }
      if(elapsedSeconds >= 30 * 60 && triggerR >= 0.5)
        {
         triggerType = "time_30min_0_5r_close";
         return true;
        }
     }
   triggerType = "none";
   return false;
  }

bool CanMoveStopToBreakEven(const TrackedTrade &tracked, const double breakEvenPrice)
  {
   MqlTick tick;
   if(!SymbolInfoTick(tracked.symbol, tick))
      return false;
   double point = SymbolInfoDouble(tracked.symbol, SYMBOL_POINT);
   int stopsLevel = (int)SymbolInfoInteger(tracked.symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = (stopsLevel + 2) * point;
   if(tracked.direction == "LONG")
     {
      if(tracked.currentStopLossPrice >= breakEvenPrice)
         return false;
      return tick.bid - breakEvenPrice >= minDistance;
     }
   if(tracked.direction == "SHORT")
     {
      if(tracked.currentStopLossPrice <= breakEvenPrice)
         return false;
      return breakEvenPrice - tick.ask >= minDistance;
     }
   return false;
  }

void ManageBreakEvenStops()
  {
   if(InpBreakEvenMode == BREAK_EVEN_DISABLED)
      return;

   trade.SetExpertMagicNumber(InpMagicNumber);
   for(int i = 0; i < ArraySize(g_trades); ++i)
     {
      if(!g_trades[i].active || g_trades[i].breakEvenTriggered)
         continue;
      if(!PositionSelect(g_trades[i].symbol))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if((long)PositionGetInteger(POSITION_IDENTIFIER) != g_trades[i].positionId)
         continue;

      MqlRates rates[];
      if(!CopyClosedRates(g_trades[i].symbol, InpPrimaryEntryTF, 1, rates))
         continue;
      if(rates[0].time <= g_trades[i].lastManagementBarTime)
         continue;

      g_trades[i].lastManagementBarTime = rates[0].time;
      UpdateTradeExcursionWithBar(g_trades[i], rates[0]);

      double triggerR = 0.0;
      string triggerType = "none";
      if(!BreakEvenTriggerReached(g_trades[i], rates[0], triggerR, triggerType))
         continue;

      double bePrice = BreakEvenPrice(g_trades[i]);
      if(!CanMoveStopToBreakEven(g_trades[i], bePrice))
         continue;

      if(trade.PositionModify(g_trades[i].symbol, bePrice, g_trades[i].takeProfit))
        {
         g_trades[i].breakEvenTriggered = true;
         g_trades[i].breakEvenTriggerType = triggerType;
         g_trades[i].breakEvenTriggerR = triggerR;
         g_trades[i].breakEvenTriggerTime = rates[0].time;
         g_trades[i].barsToBreakEven = iBarShift(g_trades[i].symbol, InpPrimaryEntryTF, g_trades[i].entryTime, false);
         g_trades[i].currentStopLossPrice = PositionGetDouble(POSITION_SL);
        }
     }
  }

void TrackNewPosition(const SignalPlan &plan, const double volume)
  {
   if(!PositionSelect(plan.symbol))
      return;
   if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
      return;

   int size = ArraySize(g_trades);
   ArrayResize(g_trades, size + 1);
   g_trades[size].active = true;
   g_trades[size].symbol = plan.symbol;
   g_trades[size].direction = plan.direction;
   g_trades[size].strategy = plan.strategy;
   g_trades[size].entryTime = (datetime)PositionGetInteger(POSITION_TIME);
   g_trades[size].serverTime = plan.serverTime;
   g_trades[size].serverHour = plan.serverHour;
   g_trades[size].utcHour = plan.utcHour;
   g_trades[size].jstHour = plan.jstHour;
   g_trades[size].sessionLabel = plan.sessionLabel;
   g_trades[size].sessionStartUtc = plan.sessionStartUtc;
   g_trades[size].minutesFromSessionStart = plan.minutesFromSessionStart;
   g_trades[size].tradeWindowLabel = plan.tradeWindowLabel;
   g_trades[size].isWithinFirst60 = plan.isWithinFirst60;
   g_trades[size].isWithinFirst120 = plan.isWithinFirst120;
   g_trades[size].brokerUtcOffsetUsed = plan.brokerUtcOffsetUsed;
   g_trades[size].selectedSymbolForSession = plan.selectedSymbolForSession;
   g_trades[size].selectedReason = plan.selectedReason;
   g_trades[size].sessionCandidateSymbolMap = plan.sessionCandidateSymbolMap;
   g_trades[size].sessionCandidateSymbols = plan.sessionCandidateSymbols;
   g_trades[size].entryPattern = plan.entryPattern;
   g_trades[size].entryTrigger = plan.entryTrigger;
   g_trades[size].necklineLevel = plan.necklineLevel;
   g_trades[size].ltfWave3Direction = plan.ltfWave3Direction;
   g_trades[size].ltfWave3Timeframe = plan.ltfWave3Timeframe;
   g_trades[size].topContextTF = plan.topContextTF;
   g_trades[size].structureTF = plan.structureTF;
   g_trades[size].primaryEntryTF = plan.primaryEntryTF;
   g_trades[size].secondaryEntryTF = plan.secondaryEntryTF;
   g_trades[size].useSecondaryEntryTF = plan.useSecondaryEntryTF;
   g_trades[size].htfAlignmentMode = plan.htfAlignmentMode;
   g_trades[size].htfPermissionMode = plan.htfPermissionMode;
   g_trades[size].allowedDirection = plan.allowedDirection;
   g_trades[size].htfWave3Direction = plan.htfWave3Direction;
   g_trades[size].htfWave3Confirmed = plan.htfWave3Confirmed;
   g_trades[size].htfH4Wave3Direction = plan.htfH4Wave3Direction;
   g_trades[size].htfH1Wave3Direction = plan.htfH1Wave3Direction;
   g_trades[size].h4DirectionState = plan.h4DirectionState;
   g_trades[size].h1DirectionState = plan.h1DirectionState;
   g_trades[size].topContextDirectionState = plan.topContextDirectionState;
   g_trades[size].structureDirectionState = plan.structureDirectionState;
   g_trades[size].htfFractalAlignment = plan.htfFractalAlignment;
   g_trades[size].htfWave3BreakLevel = plan.htfWave3BreakLevel;
   g_trades[size].htfWave3PullbackLevel = plan.htfWave3PullbackLevel;
   g_trades[size].wave3AlignmentPassed = plan.wave3AlignmentPassed;
   g_trades[size].rejectedByHtfPermission = plan.rejectedByHtfPermission;
   g_trades[size].candidateLongDetected = plan.candidateLongDetected;
   g_trades[size].candidateShortDetected = plan.candidateShortDetected;
   g_trades[size].selectedCandidateDirection = plan.selectedCandidateDirection;
   g_trades[size].selectedCandidateTimeframe = plan.selectedCandidateTimeframe;
   g_trades[size].selectedCandidatePattern = plan.selectedCandidatePattern;
   g_trades[size].primaryBestPattern = plan.primaryBestPattern;
   g_trades[size].primaryBestScore = plan.primaryBestScore;
   g_trades[size].secondaryBestPattern = plan.secondaryBestPattern;
   g_trades[size].secondaryBestScore = plan.secondaryBestScore;
   g_trades[size].m15BestPattern = plan.m15BestPattern;
   g_trades[size].m15BestScore = plan.m15BestScore;
   g_trades[size].m5BestPattern = plan.m5BestPattern;
   g_trades[size].m5BestScore = plan.m5BestScore;
   g_trades[size].htfNearestResistance = plan.htfNearestResistance;
   g_trades[size].htfNearestSupport = plan.htfNearestSupport;
   g_trades[size].nearestObstaclePrice = plan.nearestObstaclePrice;
   g_trades[size].nearestObstacleType = plan.nearestObstacleType;
   g_trades[size].nearestObstacleDistanceR = plan.nearestObstacleDistanceR;
   g_trades[size].retestReferenceType = plan.retestReferenceType;
   g_trades[size].retestReferencePrice = plan.retestReferencePrice;
   g_trades[size].retestReferenceCount = plan.retestReferenceCount;
   g_trades[size].retestReferenceDistanceAtr = plan.retestReferenceDistanceAtr;
   g_trades[size].targetRoomScore = plan.targetRoomScore;
   g_trades[size].retestScore = plan.retestScore;
   g_trades[size].fibScore = plan.fibScore;
   g_trades[size].fibSourceTF = plan.fibSourceTF;
   g_trades[size].fibImpulseHigh = plan.fibImpulseHigh;
   g_trades[size].fibImpulseLow = plan.fibImpulseLow;
   g_trades[size].fibRetraceRatio = plan.fibRetraceRatio;
   g_trades[size].fibZone = plan.fibZone;
   g_trades[size].fibRequiredPass = plan.fibRequiredPass;
   g_trades[size].basePatternScore = plan.basePatternScore;
   g_trades[size].timeBucket = plan.timeBucket;
   g_trades[size].timeScoreRemovedFlag = plan.timeScoreRemovedFlag;
   g_trades[size].candidateOrderableBeforeSessionSelection = plan.candidateOrderableBeforeSessionSelection;
   g_trades[size].rejectedBeforeSelectionReason = plan.rejectedBeforeSelectionReason;
   g_trades[size].sessionConsumedReason = plan.sessionConsumedReason;
   g_trades[size].finalScore = plan.finalScore;
   g_trades[size].cleanPathToTarget = plan.cleanPathToTarget;
   g_trades[size].hardObstaclePresentBeforeTarget = plan.hardObstaclePresentBeforeTarget;
   g_trades[size].softObstaclePresentBeforeTarget = plan.softObstaclePresentBeforeTarget;
   g_trades[size].obstacleBlocked = plan.obstacleBlocked;
   g_trades[size].targetRewardMultiple = plan.targetRewardMultiple;
   g_trades[size].targetPrice = plan.targetPrice;
   g_trades[size].breakEvenMode = BreakEvenModeName();
   g_trades[size].breakEvenEnabled = InpBreakEvenMode != BREAK_EVEN_DISABLED;
   g_trades[size].breakEvenTriggered = false;
   g_trades[size].breakEvenTriggerType = "none";
   g_trades[size].breakEvenTriggerR = 0.0;
   g_trades[size].breakEvenTriggerTime = 0;
   g_trades[size].barsToBreakEven = -1;
   g_trades[size].initialStopLossPrice = plan.stopLoss;
   g_trades[size].currentStopLossPrice = plan.stopLoss;
   g_trades[size].maxFavorableRBeforeExit = 0.0;
   g_trades[size].maxAdverseRBeforeExit = 0.0;
   g_trades[size].lastManagementBarTime = 0;
   g_trades[size].entryFailureType = plan.failureType;
   g_trades[size].sessionInvalidated = plan.sessionInvalidated;
   g_trades[size].invalidationReason = plan.invalidationReason;
   g_trades[size].positionId = (long)PositionGetInteger(POSITION_IDENTIFIER);
   g_trades[size].entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   g_trades[size].stopLoss = plan.stopLoss;
   g_trades[size].takeProfit = plan.takeProfit;
   g_trades[size].riskPrice = plan.riskPrice;
   g_trades[size].rewardR = plan.rewardR;
   g_trades[size].volume = volume;
   g_trades[size].atr = plan.atr;
   g_trades[size].spreadPoints = plan.spreadPoints;
   g_trades[size].score = plan.score;
  }

int FindTrackedTradeByPositionId(const long positionId)
  {
   for(int i = ArraySize(g_trades) - 1; i >= 0; --i)
     {
      if(g_trades[i].active && g_trades[i].positionId == positionId)
         return i;
     }
   return -1;
  }

bool CanOpenSignal(const SignalPlan &plan, string &blockReason)
  {
   blockReason = "";
   if(!plan.valid)
     {
      blockReason = "invalid_signal";
      return false;
     }
   if(plan.signalBlocked)
     {
      blockReason = plan.reason == "" ? "signal_blocked" : plan.reason;
      return false;
     }
   if(HardRiskStopped())
     {
      blockReason = g_dailyStopped ? "daily_loss_stop" : "max_drawdown_stop";
      return false;
     }
   if(HasManagedPosition(plan.symbol))
     {
      blockReason = "symbol_already_open";
      return false;
     }
   if(InpMaxPositions > 0 && CountManagedPositions() >= InpMaxPositions)
     {
      blockReason = "max_positions";
      return false;
     }
   if(CurrentTotalOpenRiskPercent() + InpRiskPerTradePercent > InpMaxTotalOpenRiskPercent)
     {
      blockReason = "total_risk_limit";
      return false;
     }
   if(CurrentSymbolOpenRiskPercent(plan.symbol) + InpRiskPerTradePercent > InpMaxRiskPerSymbolPercent)
     {
      blockReason = "symbol_risk_limit";
      return false;
     }
   return true;
  }

void TryOpenSignal(SignalPlan &plan)
  {
   if(!plan.valid)
      return;

   ++g_signalCount;
   WriteSignalRow(plan, "signal");

   string blockReason = "";
   if(!CanOpenSignal(plan, blockReason))
     {
      ++g_blockedCount;
      plan.reason = blockReason;
      plan.sessionConsumedReason = "blocked_" + blockReason;
      if(plan.failureType == "other")
         plan.failureType = blockReason;
      WriteSignalRow(plan, "blocked");
      MarkSessionConsumed(plan);
      return;
     }

   double volume = CalculatePositionSize(plan.symbol, plan.riskPrice);
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);

   bool ok = false;
   if(plan.direction == "LONG")
      ok = trade.Buy(volume, plan.symbol, 0.0, plan.stopLoss, plan.takeProfit, plan.strategy);
   else if(plan.direction == "SHORT")
      ok = trade.Sell(volume, plan.symbol, 0.0, plan.stopLoss, plan.takeProfit, plan.strategy);

   if(ok)
     {
      ++g_orderSentCount;
      plan.sessionConsumedReason = "order_sent";
      TrackNewPosition(plan, volume);
      WriteSignalRow(plan, "order_sent");
      MarkSessionConsumed(plan);
     }
   else
     {
      ++g_orderFailedCount;
      plan.reason = "order_failed_" + IntegerToString((int)trade.ResultRetcode());
      plan.sessionConsumedReason = "order_failed";
      WriteSignalRow(plan, "order_failed");
      MarkSessionConsumed(plan);
     }
  }

void ManageTimeStops()
  {
   if(InpMaxHoldBars <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      string symbol = PositionGetString(POSITION_SYMBOL);
      datetime openedAt = (datetime)PositionGetInteger(POSITION_TIME);
      int shift = iBarShift(symbol, InpPrimaryEntryTF, openedAt, false);
      if(shift >= InpMaxHoldBars)
         trade.PositionClose(ticket);
     }
  }

void ScanSymbols()
  {
   UpdateRiskAnchors();
   ManageBreakEvenStops();
   ManageTimeStops();

   SignalPlan candidates[];
   ArrayResize(candidates, 0);

   for(int i = 0; i < ArraySize(g_symbols); ++i)
     {
      datetime barTime = 0;
      if(!LatestClosedBarTime(g_symbols[i], barTime))
         continue;
      if(barTime <= g_lastScannedBars[i])
         continue;
      g_lastScannedBars[i] = barTime;

      SessionInfo sessions[];
      if(BuildSessionInfos(barTime, sessions) <= 0)
         continue;

      for(int sessionIndex = 0; sessionIndex < ArraySize(sessions); ++sessionIndex)
        {
         SignalPlan plan;
         if(BuildSessionReversalSignal(g_symbols[i], sessions[sessionIndex], plan))
           {
            plan.valid = true;
            int size = ArraySize(candidates);
            ArrayResize(candidates, size + 1);
            candidates[size] = plan;
           }
        }
     }

   if(ArraySize(candidates) <= 0)
      return;

   if(!IsOneSymbolPerSessionScenario())
     {
      for(int i = 0; i < ArraySize(candidates); ++i)
        {
         candidates[i].selectedSymbolForSession = candidates[i].symbol;
         candidates[i].selectedReason = "all_symbols_symbol_session_one_shot";
         TryOpenSignal(candidates[i]);
        }
      return;
     }

   while(true)
     {
      int best = -1;
      double bestScore = -1.0;
      for(int i = 0; i < ArraySize(candidates); ++i)
        {
         if(!candidates[i].valid)
            continue;
         if(HasKey(g_consumedSessionKeys, candidates[i].sessionKey))
            continue;
         if(InpFilterOrderableBeforeSessionSelection)
           {
            string preselectBlockReason = "";
            if(!CanOpenSignal(candidates[i], preselectBlockReason))
              {
               ++g_preselectionRejectedCount;
               candidates[i].candidateOrderableBeforeSessionSelection = false;
               candidates[i].rejectedBeforeSelectionReason = preselectBlockReason;
               candidates[i].sessionConsumedReason = "not_consumed_preselection_rejected";
               WriteSignalRow(candidates[i], "preselection_rejected");
               candidates[i].valid = false;
               continue;
              }
            candidates[i].candidateOrderableBeforeSessionSelection = true;
            candidates[i].rejectedBeforeSelectionReason = "none";
           }
         if(candidates[i].score > bestScore)
           {
            best = i;
            bestScore = candidates[i].score;
           }
        }
      if(best < 0)
         return;

      string selected = SelectedSymbolForSession(candidates[best].sessionKey);
      if(selected == "")
        {
         selected = candidates[best].symbol;
         SetSelectedSymbolForSession(candidates[best].sessionKey, selected);
        }
      if(candidates[best].symbol != selected)
        {
         AddKey(g_consumedSessionKeys, candidates[best].sessionKey);
         continue;
        }

      candidates[best].selectedSymbolForSession = selected;
      candidates[best].selectedReason = "highest_score_in_session_bar";
      TryOpenSignal(candidates[best]);
     }
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;

   long magic = (long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if(magic != InpMagicNumber)
      return;

   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT && entry != DEAL_ENTRY_OUT_BY)
      return;

   long positionId = (long)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   int trackedIndex = FindTrackedTradeByPositionId(positionId);
   if(trackedIndex < 0)
      return;

   double exitPrice = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
   double commission = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   double swap = HistoryDealGetDouble(trans.deal, DEAL_SWAP);
   datetime exitTime = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
   string exitReason = EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON));

   UpdateTradeExcursionWithPrice(g_trades[trackedIndex], exitPrice);
   WriteTradeRow(g_trades[trackedIndex], exitTime, exitPrice, profit, commission, swap, exitReason);
   g_trades[trackedIndex].active = false;
   ++g_closedTradeCount;
  }

int OnInit()
  {
   if(InpATRPeriod < 2 ||
      InpMAPeriodFast < 2 ||
      InpMAPeriodSlow <= InpMAPeriodFast ||
      InpStructureLookbackBars < 6 ||
      InpPatternLookbackBars < 12 ||
      InpSwingDepth < 1 ||
      InpHTFLookbackBars < 20 ||
      InpHTFWaveLookbackBars < 30 ||
      InpHTFWaveBreakBufferATR < 0.0 ||
      InpDowMinSwingATR < 0.0 ||
      InpDowStructureToleranceATR < 0.0 ||
      InpDowMinPivotsForTrend < 4 ||
      InpBreakEvenOffsetPoints < 0.0 ||
      InpOpeningRangeMinutes < 5 ||
      InpPreSessionMinutes < 15 ||
      InpTargetRewardMultiple <= 0.0 ||
      InpEqualLevelTolerancePips < 0.0 ||
      InpEqualLevelToleranceATR < 0.0 ||
      InpRetestToleranceATR <= 0.0 ||
      InpBreakBufferATR < 0.0 ||
      InpStopBufferATR <= 0.0 ||
      InpMinSL_ATR <= 0.0 ||
      InpMaxSL_ATR < InpMinSL_ATR ||
      InpSessionInvalidationATR <= 0.0 ||
      InpMaxHoldBars < 1 ||
      InpRiskPerTradePercent <= 0.0 ||
      InpMaxTotalOpenRiskPercent <= 0.0 ||
      InpMaxRiskPerSymbolPercent <= 0.0 ||
      InpMaxPositions < 1 ||
      InpDailyMaxLossPercent <= 0.0 ||
      InpMaxDrawdownPercent <= 0.0 ||
      InpMaxSpreadATR <= 0.0 ||
      InpFixedLotFallback <= 0.0 ||
      InpMaxLotCap <= 0.0)
     {
      PrintFormat("%s: invalid input", STRATEGY_NAME);
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!ParseSymbols())
     {
      PrintFormat("%s: no valid symbols", STRATEGY_NAME);
      return INIT_FAILED;
     }

   g_initialEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_peakEquity = g_initialEquity;
   g_dayStartEquity = g_initialEquity;
   g_dayKey = DateKey(TimeCurrent());
   trade.SetExpertMagicNumber(InpMagicNumber);
   EnsureLogFolder();

   PrintFormat("%s initialized scenario=%s symbols=%d risk=%.2f targetR=%.2f window=%s",
               STRATEGY_NAME,
               ScenarioModeName(),
               ArraySize(g_symbols),
               InpRiskPerTradePercent,
               EffectiveTargetRewardMultiple(),
               TradeWindowLabel());
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   WriteSummaryRow();
  }

void OnTick()
  {
   ScanSymbols();
  }
