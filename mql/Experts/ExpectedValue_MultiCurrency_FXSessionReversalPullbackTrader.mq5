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

enum ENUM_TRANSCRIPT_CONTEXT_MODE
  {
   TRANSCRIPT_CONTEXT_DISABLED = 0,
   TRANSCRIPT_CONTEXT_H1_COUNTER_M15_REVERSAL = 1,
   TRANSCRIPT_CONTEXT_H1_NOT_OPPOSITE_M15_REVERSAL = 2,
   TRANSCRIPT_CONTEXT_H1_ALIGNED_M15_REVERSAL = 3
  };

enum ENUM_NESTED_THIRDWAVE_MODE
  {
   NESTED_THIRDWAVE_OFF = 0,
   NESTED_THIRDWAVE_DIAGNOSTIC_ONLY = 1,
   NESTED_THIRDWAVE_SCORE = 2,
   NESTED_THIRDWAVE_REQUIRED = 3
  };

enum ENUM_SESSION_GATE_MODE
  {
   SESSION_GATE_EXISTING_FIRST120 = 0,
   SESSION_GATE_NONE_DIAGNOSTIC = 1,
   SESSION_GATE_ACTIVE_LABEL_ONLY = 2,
   SESSION_GATE_ALLOW_LATE_STRUCTURE = 3
  };

enum ENUM_M5_CORRECTIVE_MODE
  {
   M5_CORRECTIVE_OFF = 0,
   M5_CORRECTIVE_DIAGNOSTIC_ONLY = 1,
   M5_CORRECTIVE_SCORE = 2,
   M5_CORRECTIVE_REQUIRED = 3
  };

enum ENUM_M15_WAVE_CONTEXT_MODE
  {
   M15_WAVE_CONTEXT_OFF = 0,
   M15_WAVE_CONTEXT_DIAGNOSTIC_ONLY = 1,
   M15_WAVE_CONTEXT_SCORE = 2,
   M15_WAVE_CONTEXT_REQUIRED_LIGHT = 3,
   M15_WAVE_CONTEXT_REQUIRED_STRICT = 4
  };

enum ENUM_M15_WAVE2_EXPANSION_MODE
  {
   M15_WAVE2_EXPANSION_OFF = 0,
   M15_WAVE2_EXPANSION_CURRENT_REQUIRED_LIGHT = 1,
   M15_WAVE2_EXPANSION_PULLBACK_ONLY = 2,
   M15_WAVE2_EXPANSION_WAVE1_OR_WAVE2 = 3,
   M15_WAVE2_EXPANSION_NOT_OPPOSITE_PLUS_PULLBACK = 4,
   M15_WAVE2_EXPANSION_FIB_OR_STRUCTURE_PULLBACK = 5,
   M15_WAVE2_EXPANSION_DIAGNOSTIC_ONLY = 6
  };

enum ENUM_M15_WAVE2_GATE_MODE
  {
   M15_WAVE2_GATE_NO_GATE = 0,
   M15_WAVE2_GATE_REQUIRED_LIGHT = 1,
   M15_WAVE2_GATE_REQUIRED_EXPANDED = 2,
   M15_WAVE2_GATE_REQUIRED_ONLY_LOW_QUALITY_M5 = 3,
   M15_WAVE2_GATE_SCORE_ONLY = 4,
   M15_WAVE2_GATE_DIAGNOSTIC_ONLY = 5,
   M15_WAVE2_GATE_REQUIRED_MEDIUM_LOW_QUALITY_M5 = 6
  };

enum ENUM_M15_WAVE2_ADJACENT_MODE
  {
   M15_WAVE2_ADJACENT_OFF = 0,
   M15_WAVE2_ADJACENT_REQUIRED_LIGHT_ORIGINAL = 1,
   M15_WAVE2_ADJACENT_RELAX_WAVE1_AGE_ONLY = 2,
   M15_WAVE2_ADJACENT_RELAX_WAVE2_AGE_ONLY = 3,
   M15_WAVE2_ADJACENT_RELAX_FIB_NEIGHBOR_ONLY = 4,
   M15_WAVE2_ADJACENT_ALLOW_ADJACENT_BREAK_TYPE_ONLY = 5,
   M15_WAVE2_ADJACENT_ALLOW_HIGH_QUALITY_M5_NEAR_MISS_ONLY = 6,
   M15_WAVE2_ADJACENT_RELAX_CONTEXT_FIB_ROOM_ONLY = 7,
   M15_WAVE2_ADJACENT_COMBINE_BEST_TWO = 8,
   M15_WAVE2_ADJACENT_DIAGNOSTIC_ONLY = 9
  };

enum ENUM_M15_WAVE2_ADJACENT_FIB_SIDE
  {
   M15_WAVE2_ADJACENT_FIB_BOTH = 0,
   M15_WAVE2_ADJACENT_FIB_SHALLOW_ONLY = 1,
   M15_WAVE2_ADJACENT_FIB_DEEP_ONLY = 2
  };

enum ENUM_EXIT_MODE
  {
   EXIT_FIXED_TP_SL = 0,
   EXIT_M5_FAILURE = 1,
   EXIT_M5_FAILURE_STRUCTURE_TARGET = 2,
   EXIT_M5_FAILURE_SHORTER_HOLD = 3
  };

enum ENUM_STRUCTURE_TARGET_MODE
  {
   STRUCTURE_TARGET_OFF = 0,
   STRUCTURE_TARGET_PRIOR_M15_SWING = 1,
   STRUCTURE_TARGET_M15_WAVE3_PROJECTION = 2,
   STRUCTURE_TARGET_NEAREST_HTF_OBSTACLE = 3
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
   string            sessionGateMode;
   string            activeSessionLabel;
   bool              structureStartedInFirst120;
   bool              entryAfterFirst120;
   bool              sessionGatePass;
   string            sessionGateRejectReason;
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
   string            transcriptContextMode;
   bool              transcriptContextPassed;
   string            transcriptStage;
   string            transcriptRejectReason;
   string            topSma75State;
   string            structureSma75State;
   string            primarySma75State;
   int               structureBreakAgeBars;
   double            structureBreakLevel;
   int               primaryBreakAgeBars;
   double            primaryBreakLevel;
   bool              nestedThirdwaveEnabled;
   string            nestedThirdwaveMode;
   string            h1ContextDirection;
   string            h1ContextImpulseDirection;
   double            contextImpulseHigh;
   double            contextImpulseLow;
   double            h1ContextFibRetraceRatio;
   string            h1ContextFibRoomBucket;
   double            contextFibRoomScore;
   bool              m15Wave1Candidate;
   string            m15Wave1Direction;
   string            m15Wave1BreakType;
   double            m15Wave1BreakLevel;
   int               m15Wave1AgeBars;
   double            m15Wave1High;
   double            m15Wave1Low;
   bool              m15Wave2Candidate;
   double            m15Wave2RetraceRatio;
   string            m15Wave2FibZone;
   double            m15Wave2FibScore;
   string            m15WaveContextMode;
   string            m15Wave2ExpansionMode;
   string            m15Wave2GateMode;
   string            m15Wave2Type;
   int               m15Wave2AgeBars;
   double            m15Wave2Score;
   bool              m15Wave2GatePass;
   string            m15Wave2GateRejectReason;
   double            m15WaveContextScore;
   string            m5PatternQualityGroup;
   bool              m15Wave2RequiredDueToPatternQuality;
   bool              m15Wave2ScoreApplied;
   string            m15Wave2AdjacentMode;
   string            m15Wave2AdjacentFibSide;
   bool              m15RequiredLightPass;
   string            m15RequiredLightRejectReason;
   bool              m15Wave2AdjacentPass;
   string            m15Wave2AdjacentReason;
   string            m15Wave2AdjacentRelaxedComponent;
   bool              m15Wave2NearMiss;
   bool              m5CorrectiveWaveDetected;
   string            m5CorrectiveDirection;
   int               m5CorrectiveSwingCount;
   bool              m5Corrective123Detected;
   bool              m5CorrectiveABCDetected;
   int               m5CorrectiveLegCount;
   datetime          m5CorrectiveStartTime;
   datetime          m5CorrectiveEndTime;
   int               m5CorrectiveAgeBars;
   double            m5CorrectivePullbackAtr;
   double            m5CorrectiveLastLHLevel;
   double            m5CorrectiveLastHLLevel;
   double            m5CorrectiveInvalidationLevel;
   bool              m5CorrectiveInvalidation;
   string            m5InvalidationType;
   double            m5InvalidationLevel;
   bool              m5InvalidationDetected;
   bool              m5InvalidationCloseBreak;
   double            m5InvalidationBreakAtr;
   double            m5InvalidationBodyAtr;
   bool              postBreakAcceptancePass;
   int               postBreakAcceptanceBars;
   double            postBreakReturnAtr;
   bool              firstRetestAfterInvalidation;
   int               barsFromInvalidationToEntry;
   double            retestLevel;
   double            retestDistanceAtr;
   string            sma75State;
   bool              sma75Reclaim;
   double            sma75GranvilleScore;
   double            nestedScore;
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
   string            exitMode;
   string            structureTargetMode;
   string            structureTargetType;
   double            structureTargetPrice;
   double            structureTargetR;
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
   string            sessionGateMode;
   string            activeSessionLabel;
   bool              structureStartedInFirst120;
   bool              entryAfterFirst120;
   bool              sessionGatePass;
   string            sessionGateRejectReason;
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
   string            transcriptContextMode;
   bool              transcriptContextPassed;
   string            transcriptStage;
   string            transcriptRejectReason;
   string            topSma75State;
   string            structureSma75State;
   string            primarySma75State;
   int               structureBreakAgeBars;
   double            structureBreakLevel;
   int               primaryBreakAgeBars;
   double            primaryBreakLevel;
   bool              nestedThirdwaveEnabled;
   string            nestedThirdwaveMode;
   string            h1ContextDirection;
   string            h1ContextImpulseDirection;
   double            contextImpulseHigh;
   double            contextImpulseLow;
   double            h1ContextFibRetraceRatio;
   string            h1ContextFibRoomBucket;
   double            contextFibRoomScore;
   bool              m15Wave1Candidate;
   string            m15Wave1Direction;
   string            m15Wave1BreakType;
   double            m15Wave1BreakLevel;
   int               m15Wave1AgeBars;
   double            m15Wave1High;
   double            m15Wave1Low;
   bool              m15Wave2Candidate;
   double            m15Wave2RetraceRatio;
   string            m15Wave2FibZone;
   double            m15Wave2FibScore;
   string            m15WaveContextMode;
   string            m15Wave2ExpansionMode;
   string            m15Wave2GateMode;
   string            m15Wave2Type;
   int               m15Wave2AgeBars;
   double            m15Wave2Score;
   bool              m15Wave2GatePass;
   string            m15Wave2GateRejectReason;
   double            m15WaveContextScore;
   string            m5PatternQualityGroup;
   bool              m15Wave2RequiredDueToPatternQuality;
   bool              m15Wave2ScoreApplied;
   string            m15Wave2AdjacentMode;
   string            m15Wave2AdjacentFibSide;
   bool              m15RequiredLightPass;
   string            m15RequiredLightRejectReason;
   bool              m15Wave2AdjacentPass;
   string            m15Wave2AdjacentReason;
   string            m15Wave2AdjacentRelaxedComponent;
   bool              m15Wave2NearMiss;
   bool              m5CorrectiveWaveDetected;
   string            m5CorrectiveDirection;
   int               m5CorrectiveSwingCount;
   bool              m5Corrective123Detected;
   bool              m5CorrectiveABCDetected;
   int               m5CorrectiveLegCount;
   datetime          m5CorrectiveStartTime;
   datetime          m5CorrectiveEndTime;
   int               m5CorrectiveAgeBars;
   double            m5CorrectivePullbackAtr;
   double            m5CorrectiveLastLHLevel;
   double            m5CorrectiveLastHLLevel;
   double            m5CorrectiveInvalidationLevel;
   bool              m5CorrectiveInvalidation;
   string            m5InvalidationType;
   double            m5InvalidationLevel;
   bool              m5InvalidationDetected;
   bool              m5InvalidationCloseBreak;
   double            m5InvalidationBreakAtr;
   double            m5InvalidationBodyAtr;
   bool              postBreakAcceptancePass;
   int               postBreakAcceptanceBars;
   double            postBreakReturnAtr;
   bool              firstRetestAfterInvalidation;
   int               barsFromInvalidationToEntry;
   double            retestLevel;
   double            retestDistanceAtr;
   string            sma75State;
   bool              sma75Reclaim;
   double            sma75GranvilleScore;
   double            nestedScore;
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
   string            exitMode;
   string            structureTargetMode;
   string            structureTargetType;
   double            structureTargetPrice;
   double            structureTargetR;
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
   datetime          lastExcursionBarTime;
   bool              reached05R;
   bool              reached08R;
   bool              reached10R;
   bool              reached13R;
   bool              reached15R;
   int               barsTo05R;
   int               barsTo10R;
   int               barsTo13R;
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
input ENUM_TRANSCRIPT_CONTEXT_MODE InpTranscriptContextMode = TRANSCRIPT_CONTEXT_DISABLED;
input int             InpTranscriptSmaPeriod           = 75;
input int             InpTranscriptStructureBreakMaxBars = 24;
input int             InpTranscriptPrimaryBreakMaxBars = 8;
input bool            InpTranscriptRequireStructureBreak = true;
input bool            InpTranscriptRequireSmaReclaim   = true;
input bool            InpTranscriptRequirePriorImpulse = false;
input int             InpTranscriptPriorImpulseMinPivots = 5;
input bool            InpTranscriptUsePrimaryFailureExit = false;
input int             InpTranscriptExitLookbackBars    = 10;
input bool            InpUseNestedThirdWaveLaunch      = false;
input ENUM_NESTED_THIRDWAVE_MODE InpNestedThirdWaveMode = NESTED_THIRDWAVE_OFF;
input bool            InpRequireM15Wave1Candidate      = false;
input bool            InpRequireM15Wave2Pullback       = false;
input bool            InpRequireM5CorrectiveWave       = false;
input bool            InpRequireM5CorrectiveInvalidation = false;
input bool            InpRequirePostBreakAcceptance    = false;
input int             InpPostBreakAcceptanceBars       = 1;
input bool            InpUseContextFibRoom             = false;
input bool            InpRequireContextFibRoom         = false;
input bool            InpUseM15Wave2FibZone            = false;
input bool            InpRequireM15Wave2FibZone        = false;
input bool            InpUseSma75GranvilleDiagnostic   = true;
input bool            InpUseSma75GranvilleScore        = false;
input bool            InpRequireSma75Granville         = false;
input ENUM_SESSION_GATE_MODE InpSessionGateMode        = SESSION_GATE_EXISTING_FIRST120;
input bool            InpUseM5CorrectiveABC            = false;
input ENUM_M5_CORRECTIVE_MODE InpM5CorrectiveMode      = M5_CORRECTIVE_OFF;
input int             InpM5CorrectiveMinSwings         = 3;
input bool            InpM5CorrectiveRequireTwoLegs    = true;
input int             InpM5CorrectiveMaxAgeBars        = 36;
input double          InpM5CorrectiveMinPullbackAtr    = 0.35;
input double          InpM5CorrectiveMaxPullbackAtr    = 3.0;
input bool            InpRequireM5InvalidationClose    = false;
input double          InpM5InvalidationMinBodyAtr      = 0.10;
input double          InpM5InvalidationMinBreakAtr     = 0.05;
input bool            InpUsePostBreakAcceptance        = false;
input double          InpPostBreakMaxReturnAtr         = 0.20;
input bool            InpRequireFirstRetestAfterInvalidation = false;
input int             InpFirstRetestMaxBars            = 12;
input ENUM_M15_WAVE_CONTEXT_MODE InpM15WaveContextMode = M15_WAVE_CONTEXT_OFF;
input int             InpM15Wave2MaxAgeBars            = 24;
input double          InpM15Wave2MinRetrace            = 0.236;
input double          InpM15Wave2PreferredMin          = 0.382;
input double          InpM15Wave2PreferredMax          = 0.786;
input ENUM_M15_WAVE2_EXPANSION_MODE InpM15Wave2ExpansionMode = M15_WAVE2_EXPANSION_OFF;
input ENUM_M15_WAVE2_GATE_MODE InpM15Wave2GateMode = M15_WAVE2_GATE_NO_GATE;
input ENUM_M15_WAVE2_ADJACENT_MODE InpM15Wave2AdjacentMode = M15_WAVE2_ADJACENT_OFF;
input ENUM_M15_WAVE2_ADJACENT_FIB_SIDE InpM15Wave2AdjacentFibSide = M15_WAVE2_ADJACENT_FIB_BOTH;
input int             InpM15Wave2AdjacentAgeExtraBars = 4;
input int             InpM15Wave2AdjacentCombineMask = 0;
input ENUM_EXIT_MODE  InpExitMode                      = EXIT_M5_FAILURE;
input ENUM_STRUCTURE_TARGET_MODE InpStructureTargetMode = STRUCTURE_TARGET_OFF;
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

string TranscriptContextModeName()
  {
   if(InpTranscriptContextMode == TRANSCRIPT_CONTEXT_H1_COUNTER_M15_REVERSAL)
      return "h1_counter_m15_reversal";
   if(InpTranscriptContextMode == TRANSCRIPT_CONTEXT_H1_NOT_OPPOSITE_M15_REVERSAL)
      return "h1_not_opposite_m15_reversal";
   if(InpTranscriptContextMode == TRANSCRIPT_CONTEXT_H1_ALIGNED_M15_REVERSAL)
      return "h1_aligned_m15_reversal";
   return "disabled";
  }

bool UsesTranscriptNestedThirdWave()
  {
   return InpTranscriptContextMode != TRANSCRIPT_CONTEXT_DISABLED;
  }

string NestedThirdWaveModeName()
  {
   if(InpNestedThirdWaveMode == NESTED_THIRDWAVE_DIAGNOSTIC_ONLY)
      return "diagnostic_only";
   if(InpNestedThirdWaveMode == NESTED_THIRDWAVE_SCORE)
      return "score";
   if(InpNestedThirdWaveMode == NESTED_THIRDWAVE_REQUIRED)
      return "required";
   return "off";
  }

bool UsesNestedThirdWaveLaunch()
  {
   return InpUseNestedThirdWaveLaunch && InpNestedThirdWaveMode != NESTED_THIRDWAVE_OFF;
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

string SessionGateModeName()
  {
   if(InpSessionGateMode == SESSION_GATE_NONE_DIAGNOSTIC)
      return "no_session_gate_diagnostic";
   if(InpSessionGateMode == SESSION_GATE_ACTIVE_LABEL_ONLY)
      return "active_session_label_only";
   if(InpSessionGateMode == SESSION_GATE_ALLOW_LATE_STRUCTURE)
      return "session_gate_but_allow_late_structure_completion";
   return "existing_first120_gate";
  }

string M5CorrectiveModeName()
  {
   if(InpM5CorrectiveMode == M5_CORRECTIVE_DIAGNOSTIC_ONLY)
      return "diagnostic_only";
   if(InpM5CorrectiveMode == M5_CORRECTIVE_SCORE)
      return "score";
   if(InpM5CorrectiveMode == M5_CORRECTIVE_REQUIRED)
      return "required";
   return "off";
  }

string M15WaveContextModeName()
  {
   if(InpM15WaveContextMode == M15_WAVE_CONTEXT_DIAGNOSTIC_ONLY)
      return "diagnostic_only";
   if(InpM15WaveContextMode == M15_WAVE_CONTEXT_SCORE)
      return "score";
   if(InpM15WaveContextMode == M15_WAVE_CONTEXT_REQUIRED_LIGHT)
      return "required_light";
   if(InpM15WaveContextMode == M15_WAVE_CONTEXT_REQUIRED_STRICT)
      return "required_strict";
   return "off";
  }

string M15Wave2ExpansionModeName()
  {
   if(InpM15Wave2ExpansionMode == M15_WAVE2_EXPANSION_CURRENT_REQUIRED_LIGHT)
      return "current_required_light";
   if(InpM15Wave2ExpansionMode == M15_WAVE2_EXPANSION_PULLBACK_ONLY)
      return "wave2_pullback_only";
   if(InpM15Wave2ExpansionMode == M15_WAVE2_EXPANSION_WAVE1_OR_WAVE2)
      return "wave1_or_wave2_context";
   if(InpM15Wave2ExpansionMode == M15_WAVE2_EXPANSION_NOT_OPPOSITE_PLUS_PULLBACK)
      return "structure_not_opposite_plus_pullback";
   if(InpM15Wave2ExpansionMode == M15_WAVE2_EXPANSION_FIB_OR_STRUCTURE_PULLBACK)
      return "fib_or_structure_pullback";
   if(InpM15Wave2ExpansionMode == M15_WAVE2_EXPANSION_DIAGNOSTIC_ONLY)
      return "diagnostic_only";
   return "off";
  }

string M15Wave2GateModeName()
  {
   if(InpM15Wave2GateMode == M15_WAVE2_GATE_REQUIRED_LIGHT)
      return "required_light";
   if(InpM15Wave2GateMode == M15_WAVE2_GATE_REQUIRED_EXPANDED)
      return "required_expanded";
   if(InpM15Wave2GateMode == M15_WAVE2_GATE_REQUIRED_ONLY_LOW_QUALITY_M5)
      return "required_only_if_m5_pattern_low_quality";
   if(InpM15Wave2GateMode == M15_WAVE2_GATE_SCORE_ONLY)
      return "score_only";
   if(InpM15Wave2GateMode == M15_WAVE2_GATE_DIAGNOSTIC_ONLY)
      return "diagnostic_only";
   if(InpM15Wave2GateMode == M15_WAVE2_GATE_REQUIRED_MEDIUM_LOW_QUALITY_M5)
      return "required_for_medium_low_quality_m5";
   return "no_gate";
  }

string M15Wave2AdjacentModeName()
  {
   if(InpM15Wave2AdjacentMode == M15_WAVE2_ADJACENT_REQUIRED_LIGHT_ORIGINAL)
      return "required_light_original";
   if(InpM15Wave2AdjacentMode == M15_WAVE2_ADJACENT_RELAX_WAVE1_AGE_ONLY)
      return "relax_wave1_age_only";
   if(InpM15Wave2AdjacentMode == M15_WAVE2_ADJACENT_RELAX_WAVE2_AGE_ONLY)
      return "relax_wave2_age_only";
   if(InpM15Wave2AdjacentMode == M15_WAVE2_ADJACENT_RELAX_FIB_NEIGHBOR_ONLY)
      return "relax_fib_neighbor_only";
   if(InpM15Wave2AdjacentMode == M15_WAVE2_ADJACENT_ALLOW_ADJACENT_BREAK_TYPE_ONLY)
      return "allow_adjacent_break_type_only";
   if(InpM15Wave2AdjacentMode == M15_WAVE2_ADJACENT_ALLOW_HIGH_QUALITY_M5_NEAR_MISS_ONLY)
      return "allow_high_quality_m5_near_miss_only";
   if(InpM15Wave2AdjacentMode == M15_WAVE2_ADJACENT_RELAX_CONTEXT_FIB_ROOM_ONLY)
      return "relax_context_fib_room_only";
   if(InpM15Wave2AdjacentMode == M15_WAVE2_ADJACENT_COMBINE_BEST_TWO)
      return "combine_best_two_adjacent";
   if(InpM15Wave2AdjacentMode == M15_WAVE2_ADJACENT_DIAGNOSTIC_ONLY)
      return "diagnostic_only";
   return "off";
  }

string M15Wave2AdjacentFibSideName()
  {
   if(InpM15Wave2AdjacentFibSide == M15_WAVE2_ADJACENT_FIB_SHALLOW_ONLY)
      return "shallow_only";
   if(InpM15Wave2AdjacentFibSide == M15_WAVE2_ADJACENT_FIB_DEEP_ONLY)
      return "deep_only";
   return "both";
  }

string ExitModeName()
  {
   if(InpExitMode == EXIT_FIXED_TP_SL)
      return "fixed_tp_sl";
   if(InpExitMode == EXIT_M5_FAILURE_STRUCTURE_TARGET)
      return "m5_failure_exit_structure_target";
   if(InpExitMode == EXIT_M5_FAILURE_SHORTER_HOLD)
      return "m5_failure_exit_shorter_hold_diagnostic";
   return "m5_failure_exit";
  }

string StructureTargetModeName()
  {
   if(InpStructureTargetMode == STRUCTURE_TARGET_PRIOR_M15_SWING)
      return "prior_m15_swing";
   if(InpStructureTargetMode == STRUCTURE_TARGET_M15_WAVE3_PROJECTION)
      return "m15_wave3_projection";
   if(InpStructureTargetMode == STRUCTURE_TARGET_NEAREST_HTF_OBSTACLE)
      return "nearest_htf_obstacle";
   return "off";
  }

bool UsesM5CorrectiveABC()
  {
   return InpUseM5CorrectiveABC || InpM5CorrectiveMode != M5_CORRECTIVE_OFF;
  }

bool UsesM15WaveContext()
  {
   return InpM15WaveContextMode != M15_WAVE_CONTEXT_OFF ||
          InpM15Wave2ExpansionMode != M15_WAVE2_EXPANSION_OFF ||
          InpM15Wave2GateMode != M15_WAVE2_GATE_NO_GATE ||
          InpM15Wave2AdjacentMode != M15_WAVE2_ADJACENT_OFF;
  }

string M5PatternQualityGroup(const string pattern)
  {
   if(pattern == "inverse_head_and_shoulders" ||
      pattern == "head_and_shoulders" ||
      pattern == "double_bottom" ||
      pattern == "double_top")
      return "high_quality";
   if(pattern == "sweep_low_reclaim" || pattern == "sweep_high_reclaim")
      return "medium_quality";
   if(StringFind(pattern, "choch") >= 0 || StringFind(pattern, "bos") >= 0)
      return "low_quality";
   if(pattern == "" || pattern == "none")
      return "unknown";
   return "low_quality";
  }

bool UsesPrimaryFailureExit()
  {
   return InpTranscriptUsePrimaryFailureExit ||
          InpExitMode == EXIT_M5_FAILURE ||
          InpExitMode == EXIT_M5_FAILURE_STRUCTURE_TARGET ||
          InpExitMode == EXIT_M5_FAILURE_SHORTER_HOLD;
  }

int EffectiveMaxHoldBars()
  {
   if(InpExitMode == EXIT_M5_FAILURE_SHORTER_HOLD)
      return MathMax(1, InpMaxHoldBars / 2);
   return InpMaxHoldBars;
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
   if(InpSessionGateMode == SESSION_GATE_NONE_DIAGNOSTIC ||
      InpSessionGateMode == SESSION_GATE_ACTIVE_LABEL_ONLY)
      return true;
   if(!info.active || !ScenarioAllowsSession(info.label))
      return false;
   int minutes = EffectiveWindowMinutes();
   if(InpSessionGateMode == SESSION_GATE_ALLOW_LATE_STRUCTURE)
      minutes = MathMax(minutes, 180);
   return info.minutesFromStart >= 0 && info.minutesFromStart < minutes;
  }

void BuildNoSessionInfo(const datetime serverTime, SessionInfo &info)
  {
   ResetSessionInfo(info);
   MqlDateTime serverTm;
   TimeToStruct(serverTime, serverTm);
   datetime utcTime = serverTime - InpBrokerUtcOffsetHours * 3600;
   MqlDateTime utcTm;
   TimeToStruct(utcTime, utcTm);
   datetime jstTime = utcTime + 9 * 3600;
   MqlDateTime jstTm;
   TimeToStruct(jstTime, jstTm);

   info.active = false;
   info.label = "none";
   info.index = -1;
   info.startUtcHour = -1;
   info.sessionStartUtc = 0;
   info.sessionStartServer = 0;
   info.minutesFromStart = -1;
   info.serverHour = serverTm.hour;
   info.utcHour = utcTm.hour;
   info.jstHour = jstTm.hour;
   info.tradeWindowLabel = TradeWindowLabel();
   info.sessionKey = "none_" + IntegerToString(DateKey(utcTime));
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

int SmaContextDirection(const MqlRates &rates[],
                        const int period,
                        const double atr,
                        string &state)
  {
   state = "sma_data_unavailable";
   if(period <= 1 || ArraySize(rates) < period + 8)
      return 0;

   double smaNow = SMA(rates, 0, period);
   double smaPrior = SMA(rates, 5, period);
   if(smaNow <= 0.0 || smaPrior <= 0.0)
      return 0;

   double closePrice = rates[0].close;
   double buffer = MathMax(atr * 0.03, 0.0);
   bool above = closePrice > smaNow + buffer;
   bool below = closePrice < smaNow - buffer;
   bool rising = smaNow >= smaPrior;
   bool falling = smaNow <= smaPrior;

   if(above && rising)
     {
      state = "above_75sma_rising";
      return 1;
     }
   if(below && falling)
     {
      state = "below_75sma_falling";
      return -1;
     }
   if(above)
     {
      state = "above_75sma_flat_or_falling";
      return 1;
     }
   if(below)
     {
      state = "below_75sma_flat_or_rising";
      return -1;
     }

   state = "near_75sma";
   return 0;
  }

bool FindRecentBreakOfConfirmedSwing(const string symbol,
                                     const ENUM_TIMEFRAMES tf,
                                     const int direction,
                                     const int maxAgeBars,
                                     double &breakLevel,
                                     int &breakAgeBars,
                                     string &state)
  {
   breakLevel = 0.0;
   breakAgeBars = -1;
   state = "none";
   if(direction == 0 || maxAgeBars < 0)
     {
      state = "invalid_recent_break_request";
      return false;
     }

   DowPivot pivots[];
   double pivotAtr = 0.0;
   if(!CollectOrderedDowPivots(symbol, tf, InpSwingDepth, InpHTFWaveLookbackBars, pivots, pivotAtr, state))
      return false;

   MqlRates rates[];
   int bars = MathMax(maxAgeBars + InpSwingDepth + 12, InpATRPeriod + InpTranscriptSmaPeriod + 12);
   if(!CopyClosedRates(symbol, tf, bars, rates))
     {
      state = "data_unavailable";
      return false;
     }

   double atr = ATR(rates, 0, InpATRPeriod);
   if(atr <= 0.0)
     {
      state = "invalid_atr";
      return false;
     }

   int wantedKind = direction > 0 ? 1 : -1;
   int maxShift = MathMin(maxAgeBars, ArraySize(rates) - 1);
   double breakBuffer = atr * MathMax(0.0, InpBreakBufferATR);
   double retestBuffer = atr * MathMax(0.0, InpRetestToleranceATR);

   for(int p = ArraySize(pivots) - 1; p >= 0; --p)
     {
      if(pivots[p].kind != wantedKind)
         continue;

      for(int shift = 0; shift <= maxShift; ++shift)
        {
         if(rates[shift].time <= pivots[p].time)
            continue;

         bool broke = direction > 0 ?
                      rates[shift].close > pivots[p].price + breakBuffer :
                      rates[shift].close < pivots[p].price - breakBuffer;
         if(!broke)
            continue;

         bool stillValid = direction > 0 ?
                           rates[0].close >= pivots[p].price - retestBuffer :
                           rates[0].close <= pivots[p].price + retestBuffer;
         if(!stillValid)
           {
            state = "recent_confirmed_swing_break_failed";
            return false;
           }

         bool retesting = direction > 0 ?
                          rates[0].low <= pivots[p].price + retestBuffer :
                          rates[0].high >= pivots[p].price - retestBuffer;
         breakLevel = pivots[p].price;
         breakAgeBars = shift;
         state = retesting ? "recent_confirmed_swing_break_retest" : "recent_confirmed_swing_break_continuation";
         return true;
        }
     }

   state = "no_recent_confirmed_swing_break";
   return false;
  }

bool ApplyTranscriptNestedThirdWaveContext(const string symbol,
                                           const int entryDirection,
                                           SignalPlan &plan)
  {
   plan.transcriptContextMode = TranscriptContextModeName();
   plan.transcriptContextPassed = false;
   plan.transcriptRejectReason = "none";

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
   plan.allowedDirection = "transcript_post_filter";

   MqlRates topRates[];
   MqlRates structureRates[];
   MqlRates primaryRates[];
   int bars = InpTranscriptSmaPeriod + InpATRPeriod + 20;
   if(!CopyClosedRates(symbol, InpTopContextTF, bars, topRates) ||
      !CopyClosedRates(symbol, InpStructureTF, bars, structureRates) ||
      !CopyClosedRates(symbol, InpPrimaryEntryTF, bars, primaryRates))
     {
      plan.transcriptRejectReason = "transcript_data_unavailable";
      plan.reason = plan.transcriptRejectReason;
      plan.failureType = plan.transcriptRejectReason;
      return false;
     }

   double topAtr = ATR(topRates, 0, InpATRPeriod);
   double structureAtr = ATR(structureRates, 0, InpATRPeriod);
   double primaryAtr = ATR(primaryRates, 0, InpATRPeriod);
   int topSmaDirection = SmaContextDirection(topRates, InpTranscriptSmaPeriod, topAtr, plan.topSma75State);
   int structureSmaDirection = SmaContextDirection(structureRates, InpTranscriptSmaPeriod, structureAtr, plan.structureSma75State);
   int primarySmaDirection = SmaContextDirection(primaryRates, InpTranscriptSmaPeriod, primaryAtr, plan.primarySma75State);

   bool contextOk = false;
   if(InpTranscriptContextMode == TRANSCRIPT_CONTEXT_H1_COUNTER_M15_REVERSAL)
      contextOk = topDirection != entryDirection;
   else if(InpTranscriptContextMode == TRANSCRIPT_CONTEXT_H1_NOT_OPPOSITE_M15_REVERSAL)
      contextOk = topDirection != -entryDirection;
   else if(InpTranscriptContextMode == TRANSCRIPT_CONTEXT_H1_ALIGNED_M15_REVERSAL)
      contextOk = topDirection == entryDirection;
   else
      contextOk = true;

   if(!contextOk)
     {
      plan.transcriptRejectReason = "transcript_top_context_mismatch";
      plan.reason = plan.transcriptRejectReason;
      plan.failureType = plan.transcriptRejectReason;
      return false;
     }

   string structureBreakState = "";
   bool structureBreakOk = FindRecentBreakOfConfirmedSwing(symbol, InpStructureTF, entryDirection,
                                                           InpTranscriptStructureBreakMaxBars,
                                                           plan.structureBreakLevel,
                                                           plan.structureBreakAgeBars,
                                                           structureBreakState);
   string primaryBreakState = "";
   bool primaryBreakOk = FindRecentBreakOfConfirmedSwing(symbol, InpPrimaryEntryTF, entryDirection,
                                                         InpTranscriptPrimaryBreakMaxBars,
                                                         plan.primaryBreakLevel,
                                                         plan.primaryBreakAgeBars,
                                                         primaryBreakState);

   if(InpTranscriptRequireStructureBreak && !structureBreakOk)
     {
      plan.transcriptRejectReason = "transcript_structure_break_missing_" + structureBreakState;
      plan.reason = plan.transcriptRejectReason;
      plan.failureType = plan.transcriptRejectReason;
      return false;
     }

   bool smaOk = structureSmaDirection == entryDirection || primarySmaDirection == entryDirection;
   if(InpTranscriptRequireSmaReclaim && !smaOk)
     {
      plan.transcriptRejectReason = "transcript_75sma_reclaim_missing";
      plan.reason = plan.transcriptRejectReason;
      plan.failureType = plan.transcriptRejectReason;
      return false;
     }

   if(InpTranscriptRequirePriorImpulse)
     {
      DowPivot pivots[];
      double impulseAtr = 0.0;
      string impulseState = "";
      bool enoughPivots = CollectOrderedDowPivots(symbol, InpStructureTF, InpSwingDepth,
                                                  InpHTFWaveLookbackBars, pivots, impulseAtr, impulseState) &&
                          ArraySize(pivots) >= InpTranscriptPriorImpulseMinPivots;
      if(!enoughPivots || topDirection != -entryDirection)
        {
         plan.transcriptRejectReason = "transcript_prior_impulse_missing";
         plan.reason = plan.transcriptRejectReason;
         plan.failureType = plan.transcriptRejectReason;
         return false;
        }
     }

   plan.transcriptStage = "top_" + DirectionText(topDirection) + "_" + plan.topContextDirectionState +
                          "|structure_" + DirectionText(structureDirection) + "_" + plan.structureDirectionState +
                          "|structure_break_" + structureBreakState +
                          "|primary_break_" + primaryBreakState;
   plan.transcriptContextPassed = true;
   plan.wave3AlignmentPassed = true;
   plan.htfWave3Direction = DirectionText(entryDirection);
   plan.htfWave3Confirmed = structureBreakOk && (topDirection == entryDirection || topDirection == -entryDirection);
   if(structureBreakOk)
      plan.score += 0.35;
   if(primaryBreakOk)
      plan.score += 0.20;
   if(smaOk)
      plan.score += 0.20;
   return true;
  }

string NestedFibBucket(const double ratio)
  {
   if(ratio < 0.0)
      return "outside_beyond_impulse";
   if(ratio < 0.382)
      return "room_under_382";
   if(ratio <= 0.618)
      return "room_382_618";
   if(ratio <= 0.786)
      return "deep_618_786";
   return "over_786";
  }

double NestedFibRoomScore(const double ratio)
  {
   if(ratio >= 0.0 && ratio < 0.382)
      return 0.15;
   if(ratio <= 0.618)
      return 0.10;
   if(ratio <= 0.786)
      return 0.05;
   return 0.0;
  }

double NestedWave2FibScore(const string zone)
  {
   if(zone == "room_382_618")
      return 0.20;
   if(zone == "deep_618_786")
      return 0.10;
   return 0.0;
  }

string M15Wave2FibBucket(const double ratio)
  {
   if(ratio < 0.236)
      return "no_fib";
   if(ratio < 0.382)
      return "shallow_236_382";
   if(ratio <= 0.618)
      return "preferred_382_618";
   if(ratio <= 0.786)
      return "deep_618_786";
   return "too_deep";
  }

double M15Wave2FibScore(const string zone)
  {
   if(zone == "preferred_382_618")
      return 0.20;
   if(zone == "deep_618_786")
      return 0.12;
   if(zone == "shallow_236_382")
      return 0.08;
   return 0.0;
  }

string RequiredLightRejectReason(const bool wave1,
                                 const bool wave2,
                                 const double retraceRatio,
                                 const int ageBars,
                                 const int maxAgeBars)
  {
   if(!wave1)
      return "missing_recent_wave1_break";
   if(ageBars > maxAgeBars)
      return "wave1_break_too_old";
   if(!wave2)
     {
      if(retraceRatio < InpM15Wave2MinRetrace)
         return "wave2_retrace_too_shallow";
      if(retraceRatio > 0.90)
         return "wave2_retrace_too_deep";
      return "wave2_pullback_missing";
     }
   return "none";
  }

bool EvaluateM15LightWave2(const string symbol,
                           const int entryDirection,
                           const int maxAgeBars,
                           const double entryPrice,
                           bool &wave1,
                           bool &wave2,
                           double &retraceRatio,
                           string &fibZone,
                           double &fibScore,
                           int &ageBars,
                           string &breakType,
                           double &waveHigh,
                           double &waveLow)
  {
   wave1 = false;
   wave2 = false;
   retraceRatio = 0.0;
   fibZone = "no_fib";
   fibScore = 0.0;
   ageBars = -1;
   breakType = "none";
   waveHigh = 0.0;
   waveLow = 0.0;

   double breakLevel = 0.0;
   int swingCount = 0;
   wave1 = FindRecentDirectionalBreakDetailed(symbol, InpStructureTF, entryDirection,
                                              maxAgeBars,
                                              breakLevel,
                                              ageBars,
                                              breakType,
                                              waveHigh,
                                              waveLow,
                                              swingCount);
   if(!wave1 || waveHigh <= waveLow || entryPrice <= 0.0)
      return wave1;

   double range = waveHigh - waveLow;
   if(entryDirection > 0)
      retraceRatio = (waveHigh - entryPrice) / range;
   else
      retraceRatio = (entryPrice - waveLow) / range;

   fibZone = M15Wave2FibBucket(retraceRatio);
   fibScore = M15Wave2FibScore(fibZone);
   wave2 = retraceRatio >= InpM15Wave2MinRetrace && retraceRatio <= 0.90;
   return true;
  }

bool IsAdjacentFibNeighbor(const double retraceRatio)
  {
   double shallowMin = MathMax(0.0, InpM15Wave2MinRetrace - 0.06);
   bool shallowNeighbor = retraceRatio >= shallowMin && retraceRatio < InpM15Wave2MinRetrace;
   bool deepNeighbor = retraceRatio > 0.90 && retraceRatio <= 0.98;
   if(InpM15Wave2AdjacentFibSide == M15_WAVE2_ADJACENT_FIB_SHALLOW_ONLY)
      return shallowNeighbor;
   if(InpM15Wave2AdjacentFibSide == M15_WAVE2_ADJACENT_FIB_DEEP_ONLY)
      return deepNeighbor;
   return shallowNeighbor || deepNeighbor;
  }

string M15Wave2TypeFromContext(const string fibZone,
                               const bool structurePullback,
                               const bool rangePullback,
                               const bool maPullback)
  {
   if(fibZone == "preferred_382_618")
      return "fib_pullback";
   if(fibZone == "shallow_236_382")
      return "shallow_pullback";
   if(fibZone == "deep_618_786" || fibZone == "too_deep")
      return "deep_pullback";
   if(structurePullback)
      return "structure_pullback";
   if(rangePullback)
      return "range_pullback";
   if(maPullback)
      return "ma_pullback";
   return "unknown";
  }

bool DetectM15ExpandedPullbackContext(SignalPlan &plan,
                                      const int entryDirection,
                                      bool &structurePullback,
                                      bool &rangePullback,
                                      bool &maPullback,
                                      bool &notOpposite)
  {
   structurePullback = false;
   rangePullback = false;
   maPullback = false;
   notOpposite = true;

   MqlRates rates[];
   int bars = MathMax(InpM15Wave2MaxAgeBars + InpSwingDepth + 12,
                      InpTranscriptSmaPeriod + InpATRPeriod + 12);
   if(!CopyClosedRates(plan.symbol, InpStructureTF, bars, rates))
      return false;

   double atr = ATR(rates, 0, InpATRPeriod);
   if(atr <= 0.0)
      return false;

   double trendBreak = 0.0;
   double trendPullback = 0.0;
   string trendState = "";
   int structureTrend = DetermineDowTrendDirectionOnTf(plan.symbol, InpStructureTF,
                                                       trendBreak, trendPullback, trendState);
   notOpposite = structureTrend != -entryDirection;

   int lookback = MathMin(InpM15Wave2MaxAgeBars, ArraySize(rates) - 2);
   if(lookback < 6)
      return false;

   double recentHigh = HighestHigh(rates, 1, lookback);
   double recentLow = LowestLow(rates, 1, lookback);
   double current = plan.entry > 0.0 ? plan.entry : rates[0].close;
   double recentRange = recentHigh - recentLow;
   if(recentRange > atr * 0.35)
     {
      double retrace = entryDirection > 0 ? (recentHigh - current) / recentRange :
                                           (current - recentLow) / recentRange;
      if(retrace > 0.0 && retrace < 1.25)
        {
         plan.m15Wave2RetraceRatio = retrace;
         plan.m15Wave2FibZone = M15Wave2FibBucket(retrace);
         plan.m15Wave2FibScore = M15Wave2FibScore(plan.m15Wave2FibZone);
         rangePullback = retrace >= InpM15Wave2MinRetrace && retrace <= 0.95;
         plan.m15Wave2AgeBars = lookback;
         plan.m15Wave1High = recentHigh;
         plan.m15Wave1Low = recentLow;
        }
     }

   DowPivot pivots[];
   double pivotAtr = 0.0;
   string pivotState = "";
   if(CollectOrderedDowPivots(plan.symbol, InpStructureTF, InpSwingDepth,
                              MathMax(InpM15Wave2MaxAgeBars + 12, InpHTFWaveLookbackBars),
                              pivots, pivotAtr, pivotState))
     {
      int count = ArraySize(pivots);
      if(count >= 2)
        {
         DowPivot latest = pivots[count - 1];
         DowPivot previous = pivots[count - 2];
         if(entryDirection > 0 && previous.kind == 1 && latest.kind == -1 && latest.shift <= InpM15Wave2MaxAgeBars)
           {
            structurePullback = true;
            plan.m15Wave2AgeBars = latest.shift;
            plan.m15Wave1High = previous.price;
            plan.m15Wave1Low = latest.price;
           }
         if(entryDirection < 0 && previous.kind == -1 && latest.kind == 1 && latest.shift <= InpM15Wave2MaxAgeBars)
           {
            structurePullback = true;
            plan.m15Wave2AgeBars = latest.shift;
            plan.m15Wave1High = latest.price;
            plan.m15Wave1Low = previous.price;
           }
        }
     }

   double sma75 = SMA(rates, 0, InpTranscriptSmaPeriod);
   if(sma75 > 0.0)
     {
      if(entryDirection > 0)
         maPullback = rates[0].low <= sma75 + atr * 0.25 && rates[0].close >= sma75 - atr * 0.10;
      else
         maPullback = rates[0].high >= sma75 - atr * 0.25 && rates[0].close <= sma75 + atr * 0.10;
     }

   return rangePullback || structurePullback || maPullback;
  }

bool FindLatestContextImpulse(const string symbol,
                              const int entryDirection,
                              double &impulseHigh,
                              double &impulseLow,
                              string &impulseDirection)
  {
   impulseHigh = 0.0;
   impulseLow = 0.0;
   impulseDirection = "NONE";

   DowPivot pivots[];
   double atr = 0.0;
   string state = "";
   if(!CollectOrderedDowPivots(symbol, InpTopContextTF, InpSwingDepth,
                               InpHTFWaveLookbackBars, pivots, atr, state))
      return false;

   int endKind = entryDirection > 0 ? -1 : 1;
   int priorKind = -endKind;
   for(int i = ArraySize(pivots) - 1; i >= 0; --i)
     {
      if(pivots[i].kind != endKind)
         continue;
      for(int j = i - 1; j >= 0; --j)
        {
         if(pivots[j].kind != priorKind)
            continue;
         if(entryDirection > 0)
           {
            impulseHigh = pivots[j].price;
            impulseLow = pivots[i].price;
            impulseDirection = "SHORT";
           }
         else
           {
            impulseHigh = pivots[i].price;
            impulseLow = pivots[j].price;
            impulseDirection = "LONG";
           }
         return impulseHigh > impulseLow;
        }
     }
   return false;
  }

bool FindRecentDirectionalBreakDetailed(const string symbol,
                                        const ENUM_TIMEFRAMES tf,
                                        const int direction,
                                        const int maxAgeBars,
                                        double &breakLevel,
                                        int &breakAgeBars,
                                        string &breakType,
                                        double &waveHigh,
                                        double &waveLow,
                                        int &swingCount)
  {
   breakLevel = 0.0;
   breakAgeBars = -1;
   breakType = "none";
   waveHigh = 0.0;
   waveLow = 0.0;
   swingCount = 0;
   if(direction == 0 || maxAgeBars < 0)
      return false;

   DowPivot pivots[];
   double pivotAtr = 0.0;
   string state = "";
   if(!CollectOrderedDowPivots(symbol, tf, InpSwingDepth, InpHTFWaveLookbackBars,
                               pivots, pivotAtr, state))
      return false;
   swingCount = ArraySize(pivots);

   MqlRates rates[];
   int bars = MathMax(maxAgeBars + InpSwingDepth + 12, InpATRPeriod + InpTranscriptSmaPeriod + 12);
   if(!CopyClosedRates(symbol, tf, bars, rates))
      return false;

   double atr = ATR(rates, 0, InpATRPeriod);
   if(atr <= 0.0)
      return false;

   int wantedKind = direction > 0 ? 1 : -1;
   int maxShift = MathMin(maxAgeBars, ArraySize(rates) - 1);
   double breakBuffer = atr * MathMax(0.0, InpBreakBufferATR);

   for(int p = ArraySize(pivots) - 1; p >= 0; --p)
     {
      if(pivots[p].kind != wantedKind)
         continue;

      for(int shift = 0; shift <= maxShift; ++shift)
        {
         if(rates[shift].time <= pivots[p].time)
            continue;

         bool broke = direction > 0 ?
                      rates[shift].close > pivots[p].price + breakBuffer :
                      rates[shift].close < pivots[p].price - breakBuffer;
         if(!broke)
            continue;

         breakLevel = pivots[p].price;
         breakAgeBars = shift;
         breakType = direction > 0 ? "return_high_break_or_bos_up" : "return_low_break_or_bos_down";

         for(int q = p - 1; q >= 0; --q)
           {
            if(pivots[q].kind != -wantedKind)
               continue;
            if(direction > 0)
              {
               waveHigh = pivots[p].price;
               waveLow = pivots[q].price;
              }
            else
              {
               waveHigh = pivots[q].price;
               waveLow = pivots[p].price;
              }
            break;
           }
         return true;
        }
     }
   return false;
  }

bool DetectCorrectiveWaveOnPrimary(const string symbol,
                                   const int entryDirection,
                                   int &swingCount,
                                   bool &corrective123,
                                   string &state)
  {
   swingCount = 0;
   corrective123 = false;
   state = "none";

   DowPivot pivots[];
   double atr = 0.0;
   if(!CollectOrderedDowPivots(symbol, InpPrimaryEntryTF, InpSwingDepth,
                               InpHTFWaveLookbackBars, pivots, atr, state))
      return false;
   swingCount = ArraySize(pivots);

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
      state = "insufficient_primary_swing_pairs";
      return false;
     }

   double tolerance = atr * MathMax(0.0, InpDowStructureToleranceATR);
   bool corrective = false;
   if(entryDirection > 0)
     {
      corrective = latestHigh < previousHigh + tolerance &&
                   latestLow < previousLow - tolerance;
      state = corrective ? "m5_lower_high_lower_low_correction" : "m5_no_down_correction";
     }
   else
     {
      corrective = latestHigh > previousHigh + tolerance &&
                   latestLow > previousLow - tolerance;
      state = corrective ? "m5_higher_high_higher_low_correction" : "m5_no_up_correction";
     }

   corrective123 = corrective && swingCount >= 3;
   return corrective;
  }

bool PostBreakAcceptance(const string symbol,
                         const int direction,
                         const double breakLevel,
                         const int breakAgeBars,
                         const string entryTrigger)
  {
   if(breakLevel <= 0.0 || breakAgeBars < 0)
      return false;
   if(InpPostBreakAcceptanceBars <= 0)
      return true;
   if(breakAgeBars < InpPostBreakAcceptanceBars)
      return false;

   MqlRates rates[];
   int bars = MathMax(InpPostBreakAcceptanceBars + 3, InpATRPeriod + 8);
   if(!CopyClosedRates(symbol, InpPrimaryEntryTF, bars, rates))
      return false;
   double atr = ATR(rates, 0, InpATRPeriod);
   if(atr <= 0.0)
      return false;

   double tolerance = atr * MathMax(0.0, InpRetestToleranceATR);
   bool held = direction > 0 ? rates[0].close > breakLevel : rates[0].close < breakLevel;
   bool retested = direction > 0 ? rates[0].low <= breakLevel + tolerance :
                                  rates[0].high >= breakLevel - tolerance;
   bool triggerAccepts = StringFind(entryTrigger, "retest") >= 0 ||
                         StringFind(entryTrigger, "choch") >= 0 ||
                         StringFind(entryTrigger, "bos") >= 0 ||
                         StringFind(entryTrigger, "sweep") >= 0;
   return held && (retested || triggerAccepts);
  }

bool IsTimeWithinSessionWindow(const SignalPlan &plan,
                               const datetime serverTime,
                               const int windowMinutes)
  {
   if(plan.sessionStartUtc <= 0 || serverTime <= 0 || windowMinutes <= 0)
      return false;
   datetime sessionStartServer = plan.sessionStartUtc + InpBrokerUtcOffsetHours * 3600;
   int minutes = (int)((serverTime - sessionStartServer) / 60);
   return minutes >= 0 && minutes < windowMinutes;
  }

bool StructureStartedFirst120(const SignalPlan &plan)
  {
   if(plan.sessionStartUtc <= 0)
      return false;
   if(plan.m15Wave1Candidate && IsTimeWithinSessionWindow(plan, plan.serverTime - plan.m15Wave1AgeBars * PeriodSeconds(InpStructureTF), 120))
      return true;
   if(plan.m5CorrectiveStartTime > 0 && IsTimeWithinSessionWindow(plan, plan.m5CorrectiveStartTime, 120))
      return true;
   return false;
  }

bool FinalizeSessionGate(SignalPlan &plan)
  {
   plan.sessionGateMode = SessionGateModeName();
   plan.structureStartedInFirst120 = StructureStartedFirst120(plan);

   if(InpSessionGateMode == SESSION_GATE_NONE_DIAGNOSTIC ||
      InpSessionGateMode == SESSION_GATE_ACTIVE_LABEL_ONLY)
     {
      plan.sessionGatePass = true;
      plan.sessionGateRejectReason = "not_gated";
      return true;
     }

   int effectiveWindow = EffectiveWindowMinutes();
   if(plan.minutesFromSessionStart >= 0 && plan.minutesFromSessionStart < effectiveWindow)
     {
      plan.sessionGatePass = true;
      plan.sessionGateRejectReason = "passed_first_window";
      return true;
     }

   if(InpSessionGateMode == SESSION_GATE_ALLOW_LATE_STRUCTURE &&
      plan.minutesFromSessionStart >= effectiveWindow &&
      plan.minutesFromSessionStart < 180 &&
      plan.structureStartedInFirst120)
     {
      plan.sessionGatePass = true;
      plan.sessionGateRejectReason = "late_entry_allowed_structure_started_first120";
      return true;
     }

   plan.sessionGatePass = false;
   plan.sessionGateRejectReason = "session_gate_failed";
   plan.reason = "session_gate_failed";
   plan.failureType = "session_gate_failed";
   return false;
  }

bool DetectRefinedM15WaveContext(SignalPlan &plan, const int entryDirection)
  {
   plan.m15WaveContextMode = M15WaveContextModeName();
   plan.m15Wave2ExpansionMode = M15Wave2ExpansionModeName();
   plan.m15Wave2GateMode = M15Wave2GateModeName();
   plan.m15Wave2AdjacentMode = M15Wave2AdjacentModeName();
   plan.m15Wave2AdjacentFibSide = M15Wave2AdjacentFibSideName();
   plan.m5PatternQualityGroup = M5PatternQualityGroup(plan.entryPattern);
   plan.m15Wave2GatePass = true;
   plan.m15Wave2GateRejectReason = "none";
   plan.m15Wave2RequiredDueToPatternQuality = false;
   plan.m15Wave2ScoreApplied = false;
   plan.m15RequiredLightPass = false;
   plan.m15RequiredLightRejectReason = "not_evaluated";
   plan.m15Wave2AdjacentPass = false;
   plan.m15Wave2AdjacentReason = "not_evaluated";
   plan.m15Wave2AdjacentRelaxedComponent = "none";
   plan.m15Wave2NearMiss = false;
   if(!UsesM15WaveContext() && !UsesM5CorrectiveABC())
      return true;

   double waveHigh = 0.0;
   double waveLow = 0.0;
   int swingCount = 0;
   bool lightWave1 = FindRecentDirectionalBreakDetailed(plan.symbol, InpStructureTF, entryDirection,
                                                        InpM15Wave2MaxAgeBars,
                                                        plan.m15Wave1BreakLevel,
                                                        plan.m15Wave1AgeBars,
                                                        plan.m15Wave1BreakType,
                                                        waveHigh,
                                                        waveLow,
                                                        swingCount);
   plan.m15Wave1Candidate = lightWave1;
   if(plan.m15Wave1Candidate)
     {
      plan.m15Wave1Direction = DirectionText(entryDirection);
      plan.m15Wave1High = waveHigh;
      plan.m15Wave1Low = waveLow;
      plan.m15Wave2AgeBars = plan.m15Wave1AgeBars;
      if(waveHigh > waveLow && plan.entry > 0.0)
        {
         double range = waveHigh - waveLow;
         if(entryDirection > 0)
            plan.m15Wave2RetraceRatio = (waveHigh - plan.entry) / range;
         else
            plan.m15Wave2RetraceRatio = (plan.entry - waveLow) / range;
         plan.m15Wave2FibZone = M15Wave2FibBucket(plan.m15Wave2RetraceRatio);
         plan.m15Wave2FibScore = M15Wave2FibScore(plan.m15Wave2FibZone);
         plan.m15Wave2Candidate = plan.m15Wave2RetraceRatio >= InpM15Wave2MinRetrace &&
                                  plan.m15Wave2RetraceRatio <= 0.90;
         plan.m15Wave2Type = M15Wave2TypeFromContext(plan.m15Wave2FibZone, false, plan.m15Wave2Candidate, false);
         }
      }

   bool lightWave2 = plan.m15Wave2Candidate;
   plan.m15RequiredLightPass = lightWave2;
   plan.m15RequiredLightRejectReason = RequiredLightRejectReason(lightWave1,
                                                                 lightWave2,
                                                                 plan.m15Wave2RetraceRatio,
                                                                 plan.m15Wave1AgeBars,
                                                                 InpM15Wave2MaxAgeBars);
   bool structurePullback = false;
   bool rangePullback = false;
   bool maPullback = false;
   bool notOpposite = true;
   bool expandedPullback = DetectM15ExpandedPullbackContext(plan, entryDirection,
                                                           structurePullback, rangePullback,
                                                           maPullback, notOpposite);
   if(expandedPullback && plan.m15Wave2Type == "unknown")
      plan.m15Wave2Type = M15Wave2TypeFromContext(plan.m15Wave2FibZone, structurePullback, rangePullback, maPullback);

   bool expandedCandidate = false;
   if(InpM15Wave2ExpansionMode == M15_WAVE2_EXPANSION_CURRENT_REQUIRED_LIGHT)
      expandedCandidate = lightWave2;
   else if(InpM15Wave2ExpansionMode == M15_WAVE2_EXPANSION_PULLBACK_ONLY)
      expandedCandidate = expandedPullback;
   else if(InpM15Wave2ExpansionMode == M15_WAVE2_EXPANSION_WAVE1_OR_WAVE2)
      expandedCandidate = plan.m15Wave1Candidate || expandedPullback;
   else if(InpM15Wave2ExpansionMode == M15_WAVE2_EXPANSION_NOT_OPPOSITE_PLUS_PULLBACK)
      expandedCandidate = notOpposite && expandedPullback;
   else if(InpM15Wave2ExpansionMode == M15_WAVE2_EXPANSION_FIB_OR_STRUCTURE_PULLBACK)
      expandedCandidate = plan.m15Wave2FibScore > 0.0 || structurePullback || rangePullback;
   else if(InpM15Wave2ExpansionMode == M15_WAVE2_EXPANSION_DIAGNOSTIC_ONLY)
      expandedCandidate = expandedPullback || lightWave2;
   else
      expandedCandidate = lightWave2;

   bool relaxedWave1 = false;
   bool relaxedWave2 = false;
   double relaxedRetrace = 0.0;
   string relaxedFibZone = "no_fib";
   double relaxedFibScore = 0.0;
   int relaxedAge = -1;
   string relaxedBreakType = "none";
   double relaxedWaveHigh = 0.0;
   double relaxedWaveLow = 0.0;
   int adjacentAgeLimit = InpM15Wave2MaxAgeBars + MathMax(0, InpM15Wave2AdjacentAgeExtraBars);
   EvaluateM15LightWave2(plan.symbol, entryDirection, adjacentAgeLimit, plan.entry,
                         relaxedWave1, relaxedWave2, relaxedRetrace, relaxedFibZone,
                         relaxedFibScore, relaxedAge, relaxedBreakType,
                         relaxedWaveHigh, relaxedWaveLow);

   bool ageAdjacent = relaxedWave2 && !lightWave2 && relaxedAge > InpM15Wave2MaxAgeBars;
   bool fibAdjacent = !lightWave2 && lightWave1 && IsAdjacentFibNeighbor(plan.m15Wave2RetraceRatio);
   bool breakAdjacent = false;
   bool highQualityAdjacent = !lightWave2 &&
                              plan.m5PatternQualityGroup == "high_quality" &&
                              notOpposite &&
                              (relaxedWave2 || fibAdjacent || expandedPullback);
   bool contextAdjacent = !lightWave2 &&
                          notOpposite &&
                          plan.contextFibRoomScore > 0.0 &&
                          (relaxedWave2 || fibAdjacent || expandedPullback);

   bool adjacentCandidate = lightWave2;
   string adjacentReason = lightWave2 ? "required_light_original_pass" : plan.m15RequiredLightRejectReason;
   string adjacentComponent = "required_light";
   if(InpM15Wave2AdjacentMode == M15_WAVE2_ADJACENT_RELAX_WAVE1_AGE_ONLY)
     {
      adjacentCandidate = lightWave2 || ageAdjacent;
      adjacentComponent = ageAdjacent ? "wave1_age" : "required_light";
      adjacentReason = adjacentCandidate ? (ageAdjacent ? "relaxed_wave1_age_pass" : "required_light_original_pass") : "relaxed_wave1_age_failed";
     }
   else if(InpM15Wave2AdjacentMode == M15_WAVE2_ADJACENT_RELAX_WAVE2_AGE_ONLY)
     {
      adjacentCandidate = lightWave2 || ageAdjacent;
      adjacentComponent = ageAdjacent ? "wave2_age_proxy" : "required_light";
      adjacentReason = adjacentCandidate ? (ageAdjacent ? "relaxed_wave2_age_proxy_pass" : "required_light_original_pass") : "relaxed_wave2_age_failed";
     }
   else if(InpM15Wave2AdjacentMode == M15_WAVE2_ADJACENT_RELAX_FIB_NEIGHBOR_ONLY)
     {
      adjacentCandidate = lightWave2 || fibAdjacent;
      adjacentComponent = fibAdjacent ? "fib_neighbor" : "required_light";
      adjacentReason = adjacentCandidate ? (fibAdjacent ? "fib_neighbor_pass" : "required_light_original_pass") : "fib_neighbor_failed";
     }
   else if(InpM15Wave2AdjacentMode == M15_WAVE2_ADJACENT_ALLOW_ADJACENT_BREAK_TYPE_ONLY)
     {
      adjacentCandidate = lightWave2 || breakAdjacent;
      adjacentComponent = breakAdjacent ? "adjacent_break_type" : "required_light";
      adjacentReason = adjacentCandidate ? (breakAdjacent ? "adjacent_break_type_pass" : "required_light_original_pass") : "no_adjacent_break_type_available";
     }
   else if(InpM15Wave2AdjacentMode == M15_WAVE2_ADJACENT_ALLOW_HIGH_QUALITY_M5_NEAR_MISS_ONLY)
     {
      adjacentCandidate = lightWave2 || highQualityAdjacent;
      adjacentComponent = highQualityAdjacent ? "high_quality_m5_near_miss" : "required_light";
      adjacentReason = adjacentCandidate ? (highQualityAdjacent ? "high_quality_m5_near_miss_pass" : "required_light_original_pass") : "high_quality_m5_near_miss_failed";
     }
   else if(InpM15Wave2AdjacentMode == M15_WAVE2_ADJACENT_RELAX_CONTEXT_FIB_ROOM_ONLY)
     {
      adjacentCandidate = lightWave2 || contextAdjacent;
      adjacentComponent = contextAdjacent ? "context_fib_room" : "required_light";
      adjacentReason = adjacentCandidate ? (contextAdjacent ? "context_fib_room_near_miss_pass" : "required_light_original_pass") : "context_fib_room_near_miss_failed";
     }
   else if(InpM15Wave2AdjacentMode == M15_WAVE2_ADJACENT_COMBINE_BEST_TWO)
     {
      int mask = InpM15Wave2AdjacentCombineMask;
      if(mask <= 0)
         mask = 1 | 16;
      bool wave1Enabled = (mask & 1) != 0;
      bool wave2Enabled = (mask & 2) != 0;
      bool fibEnabled = (mask & 4) != 0;
      bool breakEnabled = (mask & 8) != 0;
      bool highQualityEnabled = (mask & 16) != 0;
      bool contextEnabled = (mask & 32) != 0;
      bool combinedAdjacent =
         (wave1Enabled && ageAdjacent) ||
         (wave2Enabled && ageAdjacent) ||
         (fibEnabled && fibAdjacent) ||
         (breakEnabled && breakAdjacent) ||
         (highQualityEnabled && highQualityAdjacent) ||
         (contextEnabled && contextAdjacent);
      adjacentCandidate = lightWave2 || combinedAdjacent;
      if(combinedAdjacent)
        {
         if(wave1Enabled && ageAdjacent)
            adjacentComponent = "wave1_age";
         else if(wave2Enabled && ageAdjacent)
            adjacentComponent = "wave2_age_proxy";
         else if(fibEnabled && fibAdjacent)
            adjacentComponent = "fib_neighbor";
         else if(breakEnabled && breakAdjacent)
            adjacentComponent = "adjacent_break_type";
         else if(highQualityEnabled && highQualityAdjacent)
            adjacentComponent = "high_quality_m5_near_miss";
         else if(contextEnabled && contextAdjacent)
            adjacentComponent = "context_fib_room";
         adjacentReason = "combine_best_two_adjacent_pass";
        }
      else
         adjacentReason = lightWave2 ? "required_light_original_pass" : "combine_best_two_adjacent_failed";
     }
   else if(InpM15Wave2AdjacentMode == M15_WAVE2_ADJACENT_DIAGNOSTIC_ONLY)
     {
      adjacentCandidate = lightWave2 || ageAdjacent || fibAdjacent || breakAdjacent ||
                          highQualityAdjacent || contextAdjacent;
      adjacentComponent = lightWave2 ? "required_light" :
                          (ageAdjacent ? "age_near_miss" :
                           (fibAdjacent ? "fib_neighbor" :
                            (highQualityAdjacent ? "high_quality_m5_near_miss" :
                             (contextAdjacent ? "context_fib_room" : "none"))));
      adjacentReason = adjacentCandidate ? "diagnostic_adjacent_detected" : plan.m15RequiredLightRejectReason;
     }
   else if(InpM15Wave2AdjacentMode == M15_WAVE2_ADJACENT_REQUIRED_LIGHT_ORIGINAL)
     {
      adjacentCandidate = lightWave2;
      adjacentReason = lightWave2 ? "required_light_original_pass" : plan.m15RequiredLightRejectReason;
      adjacentComponent = "required_light";
     }

   plan.m15Wave2AdjacentPass = adjacentCandidate;
   plan.m15Wave2AdjacentReason = adjacentReason;
   plan.m15Wave2AdjacentRelaxedComponent = adjacentComponent;
   plan.m15Wave2NearMiss = adjacentCandidate && !lightWave2;

   if(plan.m15Wave2NearMiss && ageAdjacent)
     {
      plan.m15Wave1Candidate = relaxedWave1;
      plan.m15Wave1Direction = DirectionText(entryDirection);
      plan.m15Wave1BreakType = relaxedBreakType;
      plan.m15Wave1AgeBars = relaxedAge;
      plan.m15Wave1High = relaxedWaveHigh;
      plan.m15Wave1Low = relaxedWaveLow;
      plan.m15Wave2RetraceRatio = relaxedRetrace;
      plan.m15Wave2FibZone = relaxedFibZone;
      plan.m15Wave2FibScore = relaxedFibScore;
      plan.m15Wave2AgeBars = relaxedAge;
      plan.m15Wave2Type = M15Wave2TypeFromContext(relaxedFibZone, false, true, false);
     }

   if(InpM15Wave2ExpansionMode != M15_WAVE2_EXPANSION_OFF)
      plan.m15Wave2Candidate = expandedCandidate;
   if(InpM15Wave2AdjacentMode != M15_WAVE2_ADJACENT_OFF &&
      InpM15Wave2AdjacentMode != M15_WAVE2_ADJACENT_DIAGNOSTIC_ONLY)
      plan.m15Wave2Candidate = adjacentCandidate;

   if(plan.m15Wave2FibZone == "none")
      plan.m15Wave2FibZone = "no_fib";
   if(plan.m15Wave2Type == "")
      plan.m15Wave2Type = "unknown";

   plan.m15Wave2Score = 0.0;
   if(plan.m15Wave2Candidate)
      plan.m15Wave2Score += 0.12;
   if(structurePullback)
      plan.m15Wave2Score += 0.12;
   else if(rangePullback)
      plan.m15Wave2Score += 0.08;
   if(maPullback)
      plan.m15Wave2Score += 0.05;
   plan.m15Wave2Score += plan.m15Wave2FibScore;

   plan.m15WaveContextScore = 0.0;
   if(plan.m15Wave1Candidate)
      plan.m15WaveContextScore += 0.15;
   if(plan.m15Wave2Candidate)
      plan.m15WaveContextScore += plan.m15Wave2Score;

   if(InpM15WaveContextMode == M15_WAVE_CONTEXT_SCORE)
     {
      plan.nestedScore += plan.m15WaveContextScore;
      plan.score += plan.m15WaveContextScore;
      plan.m15Wave2ScoreApplied = true;
      }

   if(InpM15WaveContextMode == M15_WAVE_CONTEXT_REQUIRED_LIGHT && !lightWave2)
     {
      plan.reason = "m15_wave2_context_required_failed";
      plan.failureType = "m15_wave_context_failed";
      plan.m15Wave2GatePass = false;
      plan.m15Wave2GateRejectReason = "legacy_required_light_failed";
      return false;
      }
   if(InpM15WaveContextMode == M15_WAVE_CONTEXT_REQUIRED_STRICT &&
      (!plan.m15Wave1Candidate || !lightWave2 || plan.m15Wave2FibScore < 0.20))
     {
      plan.reason = "m15_wave2_context_strict_failed";
      plan.failureType = "m15_wave_context_failed";
      plan.m15Wave2GatePass = false;
      plan.m15Wave2GateRejectReason = "legacy_required_strict_failed";
      return false;
      }

   bool requireGate = false;
   bool gatePass = true;
   string gateReject = "none";
   if(InpM15Wave2GateMode == M15_WAVE2_GATE_REQUIRED_LIGHT)
     {
      requireGate = true;
      gatePass = lightWave2;
      gateReject = "required_light_failed";
     }
   else if(InpM15Wave2GateMode == M15_WAVE2_GATE_REQUIRED_EXPANDED)
     {
      requireGate = true;
      gatePass = expandedCandidate;
      gateReject = "required_expanded_failed";
     }
   else if(InpM15Wave2GateMode == M15_WAVE2_GATE_REQUIRED_ONLY_LOW_QUALITY_M5)
     {
      requireGate = plan.m5PatternQualityGroup == "low_quality";
      gatePass = !requireGate || expandedCandidate;
      gateReject = "required_low_quality_m5_failed";
     }
   else if(InpM15Wave2GateMode == M15_WAVE2_GATE_REQUIRED_MEDIUM_LOW_QUALITY_M5)
     {
      requireGate = plan.m5PatternQualityGroup == "low_quality" ||
                    plan.m5PatternQualityGroup == "medium_quality";
     gatePass = !requireGate || expandedCandidate;
      gateReject = "required_medium_low_quality_m5_failed";
     }

   if(InpM15Wave2AdjacentMode != M15_WAVE2_ADJACENT_OFF &&
      InpM15Wave2AdjacentMode != M15_WAVE2_ADJACENT_DIAGNOSTIC_ONLY)
     {
      requireGate = true;
      gatePass = adjacentCandidate;
      gateReject = adjacentReason;
     }

   plan.m15Wave2RequiredDueToPatternQuality = requireGate &&
      (InpM15Wave2GateMode == M15_WAVE2_GATE_REQUIRED_ONLY_LOW_QUALITY_M5 ||
       InpM15Wave2GateMode == M15_WAVE2_GATE_REQUIRED_MEDIUM_LOW_QUALITY_M5);

   bool shouldApplyScore = InpM15Wave2GateMode == M15_WAVE2_GATE_SCORE_ONLY ||
                           ((InpM15Wave2GateMode == M15_WAVE2_GATE_REQUIRED_ONLY_LOW_QUALITY_M5 ||
                             InpM15Wave2GateMode == M15_WAVE2_GATE_REQUIRED_MEDIUM_LOW_QUALITY_M5) &&
                            !requireGate);
   if(shouldApplyScore && plan.m15WaveContextScore > 0.0)
     {
      plan.nestedScore += plan.m15WaveContextScore;
      plan.score += plan.m15WaveContextScore;
      plan.m15Wave2ScoreApplied = true;
     }

   plan.m15Wave2GatePass = gatePass;
   plan.m15Wave2GateRejectReason = gatePass ? "none" : gateReject;
   if(!gatePass)
     {
      plan.reason = plan.m15Wave2GateRejectReason;
      plan.failureType = "m15_wave2_gate_failed";
      return false;
     }

   return true;
  }

bool DetectRefinedM5CorrectiveABC(SignalPlan &plan, const int entryDirection)
  {
   if(!UsesM5CorrectiveABC())
      return true;

   DowPivot pivots[];
   double atr = 0.0;
   string state = "";
   int lookback = MathMax(InpM5CorrectiveMaxAgeBars + InpSwingDepth + 12, InpHTFWaveLookbackBars);
   if(!CollectOrderedDowPivots(plan.symbol, InpPrimaryEntryTF, InpSwingDepth, lookback, pivots, atr, state))
      return true;

   int recentIndexes[];
   ArrayResize(recentIndexes, 0);
   for(int i = 0; i < ArraySize(pivots); ++i)
     {
      if(pivots[i].shift > InpM5CorrectiveMaxAgeBars)
         continue;
      int size = ArraySize(recentIndexes);
      ArrayResize(recentIndexes, size + 1);
      recentIndexes[size] = i;
     }

   int recentCount = ArraySize(recentIndexes);
   plan.m5CorrectiveSwingCount = recentCount;
   plan.m5CorrectiveDirection = DirectionText(-entryDirection);
   if(recentCount < MathMax(2, InpM5CorrectiveMinSwings))
      return true;

   double latestHigh = 0.0;
   double previousHigh = 0.0;
   double latestLow = 0.0;
   double previousLow = 0.0;
   datetime latestHighTime = 0;
   datetime previousHighTime = 0;
   datetime latestLowTime = 0;
   datetime previousLowTime = 0;
   int latestHighShift = -1;
   int latestLowShift = -1;
   int foundHigh = 0;
   int foundLow = 0;

   for(int r = recentCount - 1; r >= 0; --r)
     {
      DowPivot pivot = pivots[recentIndexes[r]];
      if(pivot.kind == 1)
        {
         if(foundHigh == 0)
           {
            latestHigh = pivot.price;
            latestHighTime = pivot.time;
            latestHighShift = pivot.shift;
            ++foundHigh;
           }
         else if(foundHigh == 1)
           {
            previousHigh = pivot.price;
            previousHighTime = pivot.time;
            ++foundHigh;
           }
        }
      if(pivot.kind == -1)
        {
         if(foundLow == 0)
           {
            latestLow = pivot.price;
            latestLowTime = pivot.time;
            latestLowShift = pivot.shift;
            ++foundLow;
           }
         else if(foundLow == 1)
           {
            previousLow = pivot.price;
            previousLowTime = pivot.time;
            ++foundLow;
           }
        }
      if(foundHigh >= 2 && foundLow >= 2)
         break;
     }
   if(foundHigh < 2 || foundLow < 2)
      return true;

   double tolerance = atr * MathMax(0.0, InpDowStructureToleranceATR);
   bool lowerHigh = latestHigh < previousHigh + tolerance;
   bool lowerLow = latestLow < previousLow - tolerance;
   bool higherHigh = latestHigh > previousHigh + tolerance;
   bool higherLow = latestLow > previousLow - tolerance;

   int legCount = 0;
   if(entryDirection > 0)
     {
      if(lowerHigh)
         ++legCount;
      if(lowerLow)
         ++legCount;
      plan.m5CorrectiveLastLHLevel = latestHigh;
      plan.m5CorrectiveInvalidationLevel = latestHigh;
      plan.m5CorrectiveABCDetected = InpM5CorrectiveRequireTwoLegs ? (lowerHigh && lowerLow) : (lowerHigh || lowerLow);
     }
   else
     {
      if(higherHigh)
         ++legCount;
      if(higherLow)
         ++legCount;
      plan.m5CorrectiveLastHLLevel = latestLow;
      plan.m5CorrectiveInvalidationLevel = latestLow;
      plan.m5CorrectiveABCDetected = InpM5CorrectiveRequireTwoLegs ? (higherHigh && higherLow) : (higherHigh || higherLow);
     }

   plan.m5CorrectiveLegCount = legCount;
   plan.m5Corrective123Detected = plan.m5CorrectiveABCDetected && recentCount >= InpM5CorrectiveMinSwings;
   plan.m5CorrectiveWaveDetected = plan.m5Corrective123Detected;
   plan.m5CorrectiveStartTime = MathMin(previousHighTime, previousLowTime);
   plan.m5CorrectiveEndTime = MathMax(latestHighTime, latestLowTime);
   plan.m5CorrectiveAgeBars = MathMin(latestHighShift, latestLowShift);
   if(plan.m5CorrectiveAgeBars < 0)
      plan.m5CorrectiveAgeBars = MathMax(latestHighShift, latestLowShift);

   double highMax = MathMax(MathMax(latestHigh, previousHigh), MathMax(latestLow, previousLow));
   double lowMin = MathMin(MathMin(latestHigh, previousHigh), MathMin(latestLow, previousLow));
   plan.m5CorrectivePullbackAtr = atr > 0.0 ? (highMax - lowMin) / atr : 0.0;
   if(plan.m5CorrectivePullbackAtr < InpM5CorrectiveMinPullbackAtr ||
      plan.m5CorrectivePullbackAtr > InpM5CorrectiveMaxPullbackAtr)
     {
      plan.m5CorrectiveABCDetected = false;
      plan.m5Corrective123Detected = false;
      plan.m5CorrectiveWaveDetected = false;
     }

   return true;
  }

bool DetectRefinedM5Invalidation(SignalPlan &plan, const int entryDirection)
  {
   if(!UsesM5CorrectiveABC())
      return true;

   double level = plan.m5CorrectiveInvalidationLevel;
   if(level <= 0.0)
      return true;

   MqlRates rates[];
   int bars = MathMax(InpM5CorrectiveMaxAgeBars + InpFirstRetestMaxBars + InpPostBreakAcceptanceBars + 8,
                      InpATRPeriod + 20);
   if(!CopyClosedRates(plan.symbol, InpPrimaryEntryTF, bars, rates))
      return true;
   double atr = ATR(rates, 0, InpATRPeriod);
   if(atr <= 0.0)
      return true;

   int maxShift = MathMin(InpFirstRetestMaxBars, ArraySize(rates) - 1);
   double minBreak = atr * MathMax(0.0, InpM5InvalidationMinBreakAtr);
   double minBody = atr * MathMax(0.0, InpM5InvalidationMinBodyAtr);
   int breakShift = -1;
   double breakAtr = 0.0;
   double bodyAtr = 0.0;

   for(int shift = maxShift; shift >= 0; --shift)
     {
      if(plan.m5CorrectiveEndTime > 0 && rates[shift].time <= plan.m5CorrectiveEndTime)
         continue;
      double body = MathAbs(rates[shift].close - rates[shift].open);
      bool broke = entryDirection > 0 ? rates[shift].close > level + minBreak :
                                        rates[shift].close < level - minBreak;
      if(!broke)
         continue;
      if(body < minBody)
         continue;
      breakShift = shift;
      breakAtr = entryDirection > 0 ? (rates[shift].close - level) / atr :
                                      (level - rates[shift].close) / atr;
      bodyAtr = body / atr;
      break;
     }

   if(breakShift < 0)
      return true;

   plan.m5InvalidationDetected = true;
   plan.m5CorrectiveInvalidation = true;
   plan.m5InvalidationCloseBreak = true;
   plan.m5InvalidationLevel = level;
   plan.m5InvalidationBreakAtr = breakAtr;
   plan.m5InvalidationBodyAtr = bodyAtr;
   plan.m5InvalidationType = entryDirection > 0 ? "m5_lh_close_break_up" : "m5_hl_close_break_down";
   plan.barsFromInvalidationToEntry = breakShift;
   plan.retestLevel = level;

   double maxReturn = 0.0;
   for(int shift = breakShift - 1; shift >= 0; --shift)
     {
      double returnAtr = entryDirection > 0 ? MathMax(0.0, (level - rates[shift].close) / atr) :
                                            MathMax(0.0, (rates[shift].close - level) / atr);
      maxReturn = MathMax(maxReturn, returnAtr);
     }
   plan.postBreakReturnAtr = maxReturn;
   plan.postBreakAcceptanceBars = InpPostBreakAcceptanceBars;
   plan.postBreakAcceptancePass = !InpUsePostBreakAcceptance || maxReturn <= InpPostBreakMaxReturnAtr;

   double retestTolerance = atr * MathMax(0.0, InpRetestToleranceATR);
   bool held = entryDirection > 0 ? rates[0].close >= level - atr * InpPostBreakMaxReturnAtr :
                                    rates[0].close <= level + atr * InpPostBreakMaxReturnAtr;
   bool touched = entryDirection > 0 ? rates[0].low <= level + retestTolerance :
                                       rates[0].high >= level - retestTolerance;
   plan.firstRetestAfterInvalidation = breakShift > 0 && breakShift <= InpFirstRetestMaxBars && held && touched;
   if(entryDirection > 0)
      plan.retestDistanceAtr = MathAbs(rates[0].low - level) / atr;
   else
      plan.retestDistanceAtr = MathAbs(rates[0].high - level) / atr;

   return true;
  }

bool ApplyRefinedWaveContext(SignalPlan &plan, const int entryDirection)
  {
   if(!UsesM15WaveContext() && !UsesM5CorrectiveABC())
      return true;

   if(!DetectRefinedM15WaveContext(plan, entryDirection))
      return false;
   if(!DetectRefinedM5CorrectiveABC(plan, entryDirection))
      return false;
   if(!DetectRefinedM5Invalidation(plan, entryDirection))
      return false;

   if(UsesM5CorrectiveABC())
     {
      double m5Score = 0.0;
      if(plan.m5CorrectiveABCDetected)
         m5Score += 0.25;
      if(plan.m5InvalidationDetected)
         m5Score += 0.35;
      if(plan.postBreakAcceptancePass && InpUsePostBreakAcceptance)
         m5Score += 0.20;
      if(plan.firstRetestAfterInvalidation)
         m5Score += 0.20;

      if(InpM5CorrectiveMode == M5_CORRECTIVE_SCORE)
        {
         plan.nestedScore += m5Score;
         plan.score += m5Score;
        }

      if(InpM5CorrectiveMode == M5_CORRECTIVE_REQUIRED)
        {
         if(!plan.m5CorrectiveABCDetected)
           {
            plan.reason = "m5_corrective_abc_required_failed";
            plan.failureType = "m5_corrective_abc_failed";
            return false;
           }
         if(InpRequireM5InvalidationClose && !plan.m5InvalidationCloseBreak)
           {
            plan.reason = "m5_invalidation_close_required_failed";
            plan.failureType = "m5_invalidation_failed";
            return false;
           }
         if(!InpRequireM5InvalidationClose && !plan.m5InvalidationDetected)
           {
            plan.reason = "m5_invalidation_required_failed";
            plan.failureType = "m5_invalidation_failed";
            return false;
           }
        }

      if(InpUsePostBreakAcceptance && InpRequirePostBreakAcceptance && !plan.postBreakAcceptancePass)
        {
         plan.reason = "post_break_acceptance_required_failed";
         plan.failureType = "post_break_acceptance_failed";
         return false;
        }
      if(InpRequireFirstRetestAfterInvalidation && !plan.firstRetestAfterInvalidation)
        {
         plan.reason = "first_retest_after_invalidation_required_failed";
         plan.failureType = "first_retest_failed";
         return false;
        }
     }

   return true;
  }

bool ApplyNestedThirdWaveLaunch(SignalPlan &plan, const int entryDirection)
  {
   plan.nestedThirdwaveEnabled = UsesNestedThirdWaveLaunch();
   plan.nestedThirdwaveMode = NestedThirdWaveModeName();
   if(!UsesNestedThirdWaveLaunch())
      return true;

   double topBreak = 0.0;
   double topPullback = 0.0;
   string topState = "";
   int topDirection = DetermineDowTrendDirectionOnTf(plan.symbol, InpTopContextTF,
                                                     topBreak, topPullback, topState);
   plan.h1ContextDirection = DirectionText(topDirection);

   MqlRates topRates[];
   if(CopyClosedRates(plan.symbol, InpTopContextTF, InpATRPeriod + InpTranscriptSmaPeriod + 12, topRates))
     {
      double impulseHigh = 0.0;
      double impulseLow = 0.0;
      string impulseDirection = "NONE";
      if(FindLatestContextImpulse(plan.symbol, entryDirection, impulseHigh, impulseLow, impulseDirection) &&
         impulseHigh > impulseLow)
        {
         plan.contextImpulseHigh = impulseHigh;
         plan.contextImpulseLow = impulseLow;
         plan.h1ContextImpulseDirection = impulseDirection;
         double range = impulseHigh - impulseLow;
         if(entryDirection > 0)
            plan.h1ContextFibRetraceRatio = (topRates[0].close - impulseLow) / range;
         else
            plan.h1ContextFibRetraceRatio = (impulseHigh - topRates[0].close) / range;
         plan.h1ContextFibRoomBucket = NestedFibBucket(plan.h1ContextFibRetraceRatio);
         plan.contextFibRoomScore = NestedFibRoomScore(plan.h1ContextFibRetraceRatio);
        }
     }

   double m15WaveHigh = 0.0;
   double m15WaveLow = 0.0;
   int m15SwingCount = 0;
   plan.m15Wave1Candidate = FindRecentDirectionalBreakDetailed(plan.symbol, InpStructureTF, entryDirection,
                                                               InpTranscriptStructureBreakMaxBars,
                                                               plan.m15Wave1BreakLevel,
                                                               plan.m15Wave1AgeBars,
                                                               plan.m15Wave1BreakType,
                                                               m15WaveHigh,
                                                               m15WaveLow,
                                                               m15SwingCount);
   if(plan.m15Wave1Candidate)
     {
      plan.m15Wave1Direction = DirectionText(entryDirection);
      plan.m15Wave1High = m15WaveHigh;
      plan.m15Wave1Low = m15WaveLow;
      if(m15WaveHigh > m15WaveLow)
        {
         double referenceEntry = plan.entry;
         if(referenceEntry <= 0.0)
           {
            MqlRates primaryRates[];
            if(CopyClosedRates(plan.symbol, InpPrimaryEntryTF, 2, primaryRates))
               referenceEntry = primaryRates[0].close;
           }
         double range = m15WaveHigh - m15WaveLow;
         if(entryDirection > 0)
            plan.m15Wave2RetraceRatio = (m15WaveHigh - referenceEntry) / range;
         else
            plan.m15Wave2RetraceRatio = (referenceEntry - m15WaveLow) / range;
         plan.m15Wave2FibZone = NestedFibBucket(plan.m15Wave2RetraceRatio);
         plan.m15Wave2FibScore = NestedWave2FibScore(plan.m15Wave2FibZone);
         plan.m15Wave2Candidate = plan.m15Wave2RetraceRatio >= 0.20 &&
                                  plan.m15Wave2RetraceRatio <= 0.90;
        }
     }

   string correctiveState = "";
   bool corrective123 = false;
   int correctiveSwingCount = 0;
   bool correctiveWave = DetectCorrectiveWaveOnPrimary(plan.symbol, entryDirection,
                                                       correctiveSwingCount,
                                                       corrective123,
                                                       correctiveState);
   plan.m5CorrectiveWaveDetected = correctiveWave;
   plan.m5CorrectiveDirection = DirectionText(-entryDirection);
   plan.m5CorrectiveSwingCount = correctiveSwingCount;
   plan.m5Corrective123Detected = corrective123;

   double primaryWaveHigh = 0.0;
   double primaryWaveLow = 0.0;
   int primarySwingCount = 0;
   int invalidationAge = -1;
   string invalidationType = "none";
   bool invalidation = FindRecentDirectionalBreakDetailed(plan.symbol, InpPrimaryEntryTF, entryDirection,
                                                          InpTranscriptPrimaryBreakMaxBars,
                                                          plan.m5InvalidationLevel,
                                                          invalidationAge,
                                                          invalidationType,
                                                          primaryWaveHigh,
                                                          primaryWaveLow,
                                                          primarySwingCount);
   plan.m5CorrectiveInvalidation = invalidation;
   plan.m5InvalidationType = invalidationType;
   plan.postBreakAcceptanceBars = InpPostBreakAcceptanceBars;
   plan.postBreakAcceptancePass = PostBreakAcceptance(plan.symbol, entryDirection,
                                                      plan.m5InvalidationLevel,
                                                      invalidationAge,
                                                      plan.entryTrigger);

   if(InpUseSma75GranvilleDiagnostic)
     {
      MqlRates structureRates[];
      MqlRates primaryRates[];
      if(CopyClosedRates(plan.symbol, InpStructureTF, InpTranscriptSmaPeriod + InpATRPeriod + 12, structureRates) &&
         CopyClosedRates(plan.symbol, InpPrimaryEntryTF, InpTranscriptSmaPeriod + InpATRPeriod + 12, primaryRates))
        {
         double structureAtr = ATR(structureRates, 0, InpATRPeriod);
         double primaryAtr = ATR(primaryRates, 0, InpATRPeriod);
         string structureState = "";
         string primaryState = "";
         int structureSma = SmaContextDirection(structureRates, InpTranscriptSmaPeriod, structureAtr, structureState);
         int primarySma = SmaContextDirection(primaryRates, InpTranscriptSmaPeriod, primaryAtr, primaryState);
         plan.sma75State = structureState + "|" + primaryState;
         plan.sma75Reclaim = structureSma == entryDirection || primarySma == entryDirection;
         plan.sma75GranvilleScore = plan.sma75Reclaim ? 0.15 : 0.0;
        }
     }

   plan.nestedScore = 0.0;
   if(plan.m15Wave1Candidate)
      plan.nestedScore += 0.20;
   if(plan.m15Wave2Candidate)
      plan.nestedScore += 0.20;
   if(InpUseM15Wave2FibZone)
      plan.nestedScore += plan.m15Wave2FibScore;
   if(plan.m5CorrectiveWaveDetected)
      plan.nestedScore += 0.20;
   if(plan.m5CorrectiveInvalidation)
      plan.nestedScore += 0.35;
   if(plan.postBreakAcceptancePass)
      plan.nestedScore += 0.25;
   if(InpUseContextFibRoom)
      plan.nestedScore += plan.contextFibRoomScore;
   if(InpUseSma75GranvilleScore)
      plan.nestedScore += plan.sma75GranvilleScore;

   bool defaultRequired = InpNestedThirdWaveMode == NESTED_THIRDWAVE_REQUIRED &&
                          !InpRequireM15Wave1Candidate &&
                          !InpRequireM15Wave2Pullback &&
                          !InpRequireM5CorrectiveWave &&
                          !InpRequireM5CorrectiveInvalidation &&
                          !InpRequirePostBreakAcceptance &&
                          !InpRequireContextFibRoom &&
                          !InpRequireM15Wave2FibZone &&
                          !InpRequireSma75Granville;
   if(defaultRequired || InpRequireM5CorrectiveInvalidation)
     {
      if(!plan.m5CorrectiveInvalidation)
        {
         plan.reason = "nested_m5_corrective_invalidation_missing";
         plan.failureType = "nested_required_failed";
         return false;
        }
     }
   if(InpRequireM15Wave1Candidate && !plan.m15Wave1Candidate)
     {
      plan.reason = "nested_m15_wave1_candidate_missing";
      plan.failureType = "nested_required_failed";
      return false;
     }
   if(InpRequireM15Wave2Pullback && !plan.m15Wave2Candidate)
     {
      plan.reason = "nested_m15_wave2_pullback_missing";
      plan.failureType = "nested_required_failed";
      return false;
     }
   if(InpRequireM5CorrectiveWave && !plan.m5CorrectiveWaveDetected)
     {
      plan.reason = "nested_m5_corrective_wave_missing";
      plan.failureType = "nested_required_failed";
      return false;
     }
   if(InpRequirePostBreakAcceptance && !plan.postBreakAcceptancePass)
     {
      plan.reason = "nested_post_break_acceptance_missing";
      plan.failureType = "nested_required_failed";
      return false;
     }
   if(InpRequireContextFibRoom && plan.contextFibRoomScore <= 0.0)
     {
      plan.reason = "nested_context_fib_room_missing";
      plan.failureType = "nested_required_failed";
      return false;
     }
   if(InpRequireM15Wave2FibZone && plan.m15Wave2FibScore <= 0.0)
     {
      plan.reason = "nested_m15_wave2_fib_zone_missing";
      plan.failureType = "nested_required_failed";
      return false;
     }
   if(InpRequireSma75Granville && !plan.sma75Reclaim)
     {
      plan.reason = "nested_sma75_granville_missing";
      plan.failureType = "nested_required_failed";
      return false;
     }

   if(InpNestedThirdWaveMode == NESTED_THIRDWAVE_SCORE ||
      InpNestedThirdWaveMode == NESTED_THIRDWAVE_REQUIRED)
      plan.score += plan.nestedScore;

   return true;
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
   plan.sessionGateMode = SessionGateModeName();
   plan.activeSessionLabel = "none";
   plan.structureStartedInFirst120 = false;
   plan.entryAfterFirst120 = false;
   plan.sessionGatePass = false;
   plan.sessionGateRejectReason = "not_evaluated";
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
   plan.transcriptContextMode = TranscriptContextModeName();
   plan.transcriptContextPassed = false;
   plan.transcriptStage = "none";
   plan.transcriptRejectReason = "none";
   plan.topSma75State = "none";
   plan.structureSma75State = "none";
   plan.primarySma75State = "none";
   plan.structureBreakAgeBars = -1;
   plan.structureBreakLevel = 0.0;
   plan.primaryBreakAgeBars = -1;
   plan.primaryBreakLevel = 0.0;
   plan.nestedThirdwaveEnabled = UsesNestedThirdWaveLaunch();
   plan.nestedThirdwaveMode = NestedThirdWaveModeName();
   plan.h1ContextDirection = "NONE";
   plan.h1ContextImpulseDirection = "NONE";
   plan.contextImpulseHigh = 0.0;
   plan.contextImpulseLow = 0.0;
   plan.h1ContextFibRetraceRatio = 0.0;
   plan.h1ContextFibRoomBucket = "none";
   plan.contextFibRoomScore = 0.0;
   plan.m15Wave1Candidate = false;
   plan.m15Wave1Direction = "NONE";
   plan.m15Wave1BreakType = "none";
   plan.m15Wave1BreakLevel = 0.0;
   plan.m15Wave1AgeBars = -1;
   plan.m15Wave1High = 0.0;
   plan.m15Wave1Low = 0.0;
   plan.m15Wave2Candidate = false;
   plan.m15Wave2RetraceRatio = 0.0;
   plan.m15Wave2FibZone = "none";
   plan.m15Wave2FibScore = 0.0;
   plan.m15WaveContextMode = M15WaveContextModeName();
   plan.m15Wave2ExpansionMode = M15Wave2ExpansionModeName();
   plan.m15Wave2GateMode = M15Wave2GateModeName();
   plan.m15Wave2Type = "unknown";
   plan.m15Wave2AgeBars = -1;
   plan.m15Wave2Score = 0.0;
   plan.m15Wave2GatePass = true;
   plan.m15Wave2GateRejectReason = "none";
   plan.m15WaveContextScore = 0.0;
   plan.m5PatternQualityGroup = "unknown";
   plan.m15Wave2RequiredDueToPatternQuality = false;
   plan.m15Wave2ScoreApplied = false;
   plan.m15Wave2AdjacentMode = M15Wave2AdjacentModeName();
   plan.m15Wave2AdjacentFibSide = M15Wave2AdjacentFibSideName();
   plan.m15RequiredLightPass = false;
   plan.m15RequiredLightRejectReason = "not_evaluated";
   plan.m15Wave2AdjacentPass = false;
   plan.m15Wave2AdjacentReason = "not_evaluated";
   plan.m15Wave2AdjacentRelaxedComponent = "none";
   plan.m15Wave2NearMiss = false;
   plan.m5CorrectiveWaveDetected = false;
   plan.m5CorrectiveDirection = "NONE";
   plan.m5CorrectiveSwingCount = 0;
   plan.m5Corrective123Detected = false;
   plan.m5CorrectiveABCDetected = false;
   plan.m5CorrectiveLegCount = 0;
   plan.m5CorrectiveStartTime = 0;
   plan.m5CorrectiveEndTime = 0;
   plan.m5CorrectiveAgeBars = -1;
   plan.m5CorrectivePullbackAtr = 0.0;
   plan.m5CorrectiveLastLHLevel = 0.0;
   plan.m5CorrectiveLastHLLevel = 0.0;
   plan.m5CorrectiveInvalidationLevel = 0.0;
   plan.m5CorrectiveInvalidation = false;
   plan.m5InvalidationType = "none";
   plan.m5InvalidationLevel = 0.0;
   plan.m5InvalidationDetected = false;
   plan.m5InvalidationCloseBreak = false;
   plan.m5InvalidationBreakAtr = 0.0;
   plan.m5InvalidationBodyAtr = 0.0;
   plan.postBreakAcceptancePass = false;
   plan.postBreakAcceptanceBars = InpPostBreakAcceptanceBars;
   plan.postBreakReturnAtr = 0.0;
   plan.firstRetestAfterInvalidation = false;
   plan.barsFromInvalidationToEntry = -1;
   plan.retestLevel = 0.0;
   plan.retestDistanceAtr = 0.0;
   plan.sma75State = "none";
   plan.sma75Reclaim = false;
   plan.sma75GranvilleScore = 0.0;
   plan.nestedScore = 0.0;
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
   plan.exitMode = ExitModeName();
   plan.structureTargetMode = StructureTargetModeName();
   plan.structureTargetType = "none";
   plan.structureTargetPrice = 0.0;
   plan.structureTargetR = 0.0;
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
   plan.sessionGateMode = SessionGateModeName();
   plan.activeSessionLabel = info.active ? info.label : "none";
   plan.entryAfterFirst120 = info.minutesFromStart >= 120;
   plan.sessionGatePass = false;
   plan.sessionGateRejectReason = "not_evaluated";
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

bool FindPriorStructureTarget(const string symbol,
                              const ENUM_TIMEFRAMES tf,
                              const int direction,
                              const double entryPrice,
                              double &targetPrice,
                              string &targetType)
  {
   targetPrice = 0.0;
   targetType = "none";

   DowPivot pivots[];
   double atr = 0.0;
   string state = "";
   if(!CollectOrderedDowPivots(symbol, tf, InpSwingDepth, InpHTFWaveLookbackBars, pivots, atr, state))
      return false;

   double bestDistance = DBL_MAX;
   int wantedKind = direction > 0 ? 1 : -1;
   for(int i = ArraySize(pivots) - 1; i >= 0; --i)
     {
      if(pivots[i].kind != wantedKind)
         continue;
      double distance = direction > 0 ? pivots[i].price - entryPrice : entryPrice - pivots[i].price;
      if(distance <= 0.0 || distance >= bestDistance)
         continue;
      bestDistance = distance;
      targetPrice = pivots[i].price;
      targetType = direction > 0 ? "prior_m15_swing_high" : "prior_m15_swing_low";
     }

   return targetPrice > 0.0;
  }

void ApplyStructureTarget(SignalPlan &plan, const int direction)
  {
   plan.exitMode = ExitModeName();
   plan.structureTargetMode = StructureTargetModeName();
   if(InpExitMode != EXIT_M5_FAILURE_STRUCTURE_TARGET ||
      InpStructureTargetMode == STRUCTURE_TARGET_OFF ||
      plan.entry <= 0.0 ||
      plan.riskPrice <= 0.0)
      return;

   double targetPrice = 0.0;
   string targetType = "none";
   if(InpStructureTargetMode == STRUCTURE_TARGET_PRIOR_M15_SWING)
      FindPriorStructureTarget(plan.symbol, InpStructureTF, direction, plan.entry, targetPrice, targetType);
   else if(InpStructureTargetMode == STRUCTURE_TARGET_M15_WAVE3_PROJECTION && plan.m15Wave1High > plan.m15Wave1Low)
     {
      double projection = (plan.m15Wave1High - plan.m15Wave1Low) * 1.0;
      targetPrice = direction > 0 ? plan.entry + projection : plan.entry - projection;
      targetType = "m15_wave3_projection_1_0";
     }
   else if(InpStructureTargetMode == STRUCTURE_TARGET_NEAREST_HTF_OBSTACLE)
     {
      targetPrice = plan.nearestObstaclePrice;
      targetType = plan.nearestObstacleType;
     }

   if(targetPrice <= 0.0)
      return;

   double targetR = direction > 0 ? (targetPrice - plan.entry) / plan.riskPrice :
                                    (plan.entry - targetPrice) / plan.riskPrice;
   if(targetR < 0.60 || targetR >= plan.rewardR)
      return;

   int digits = (int)SymbolInfoInteger(plan.symbol, SYMBOL_DIGITS);
   plan.structureTargetType = targetType;
   plan.structureTargetPrice = NormalizeDouble(targetPrice, digits);
   plan.structureTargetR = targetR;
   plan.takeProfit = plan.structureTargetPrice;
   plan.targetPrice = plan.structureTargetPrice;
   plan.rewardR = targetR;
   plan.targetRewardMultiple = targetR;
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
   if((InpSessionGateMode == SESSION_GATE_EXISTING_FIRST120 ||
       InpSessionGateMode == SESSION_GATE_ALLOW_LATE_STRUCTURE) &&
      !SymbolAllowedForSession(symbol, session.label))
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
       if(UsesTranscriptNestedThirdWave() && !ApplyTranscriptNestedThirdWaveContext(symbol, direction, plan))
         {
          plan.rejectedByHtfPermission = true;
          ++g_htfPermissionRejectedCount;
          return false;
         }
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
       bool alignmentOk = UsesTranscriptNestedThirdWave() ?
                          ApplyTranscriptNestedThirdWaveContext(symbol, direction, plan) :
                          ApplyHtfWave3Alignment(symbol, direction, plan);
       if(!alignmentOk)
         {
          plan.rejectedByHtfPermission = true;
          if(plan.reason == "")
             plan.reason = UsesTranscriptNestedThirdWave() ? "transcript_nested_context_failed" : "htf_wave3_alignment_failed";
          if(plan.failureType == "")
             plan.failureType = plan.reason;
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

   if(!ApplyNestedThirdWaveLaunch(plan, direction))
      return false;

   if(!ApplyRefinedWaveContext(plan, direction))
      return false;

   if(!FinalizeSessionGate(plan))
      return false;

   EvaluateTargetPathObstacles(plan, scan);
   ApplyStructureTarget(plan, direction);

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
          "session_gate_mode,active_session_label,structure_started_in_first120,entry_after_first120,session_gate_pass,session_gate_reject_reason," +
          "entry_pattern,entry_trigger,neckline_level,ltf_wave3_timeframe,top_context_tf,structure_tf,primary_entry_tf,secondary_entry_tf,use_secondary_entry_tf," +
          "htf_alignment_mode,htf_permission_mode,allowed_direction,top_context_direction_state,structure_direction_state," +
          "h4_direction_state,h1_direction_state,rejected_by_htf_permission,candidate_long_detected,candidate_short_detected," +
          "selected_candidate_direction,selected_candidate_timeframe,selected_candidate_pattern,primary_best_pattern,primary_best_score,secondary_best_pattern,secondary_best_score," +
          "m15_best_pattern,m15_best_score,m5_best_pattern,m5_best_score," +
          "htf_wave3_direction,htf_wave3_confirmed,htf_fractal_alignment,wave3_alignment_passed," +
          "transcript_context_mode,transcript_context_passed,transcript_stage,transcript_reject_reason," +
          "top_sma75_state,structure_sma75_state,primary_sma75_state,structure_break_age_bars,structure_break_level,primary_break_age_bars,primary_break_level," +
          "nested_thirdwave_enabled,nested_thirdwave_mode,h1_context_direction,h1_context_impulse_direction,context_impulse_high,context_impulse_low," +
          "h1_context_fib_retrace_ratio,h1_context_fib_room_bucket,context_fib_room_score," +
          "m15_wave1_candidate,m15_wave1_direction,m15_wave1_break_type,m15_wave1_break_level,m15_wave1_age_bars,m15_wave1_high,m15_wave1_low," +
          "m15_wave2_candidate,m15_wave2_retrace_ratio,m15_wave2_fib_zone,m15_wave2_fib_score,m15_wave_context_mode," +
          "m15_wave2_expansion_mode,m15_wave2_gate_mode,m15_wave2_type,m15_wave2_age_bars,m15_wave2_score,m15_wave2_gate_pass,m15_wave2_gate_reject_reason," +
          "m15_wave_context_score,m5_pattern_quality_group,m15_wave2_required_due_to_pattern_quality,m15_wave2_score_applied," +
          "m15_wave2_adjacent_mode,m15_wave2_adjacent_fib_side,m15_required_light_pass,m15_required_light_reject_reason," +
          "m15_wave2_adjacent_pass,m15_wave2_adjacent_reason,m15_wave2_adjacent_relaxed_component,m15_wave2_near_miss," +
          "m5_corrective_wave_detected,m5_corrective_direction,m5_corrective_swing_count,m5_corrective_123_detected,m5_corrective_abc_detected," +
          "m5_corrective_leg_count,m5_corrective_start_time,m5_corrective_end_time,m5_corrective_age_bars,m5_corrective_pullback_atr," +
          "m5_corrective_last_lh_level,m5_corrective_last_hl_level,m5_corrective_invalidation_level,m5_corrective_invalidation," +
          "m5_invalidation_detected,m5_invalidation_type,m5_invalidation_level,m5_invalidation_close_break,m5_invalidation_break_atr,m5_invalidation_body_atr," +
          "post_break_acceptance_pass,post_break_acceptance_bars,post_break_return_atr,first_retest_after_invalidation,bars_from_invalidation_to_entry,retest_level,retest_distance_atr," +
          "sma75_state,sma75_reclaim,sma75_granville_score,nested_score," +
          "htf_nearest_resistance,htf_nearest_support," +
          "nearest_obstacle_price,nearest_obstacle_type,nearest_obstacle_distance_price,nearest_obstacle_distance_r," +
          "retest_reference_type,retest_reference_price,retest_reference_distance_atr,clean_path_to_target," +
          "hard_obstacle_present_before_target,soft_obstacle_present_before_target,obstacle_blocked,obstacle_block_reason," +
          "obstacle_count_before_target,hard_obstacle_count_before_target,soft_obstacle_count_before_target," +
          "exit_mode,structure_target_mode,structure_target_type,structure_target_price,structure_target_r," +
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
   CsvAppend(line, plan.sessionGateMode);
   CsvAppend(line, plan.activeSessionLabel);
   CsvAppend(line, BoolText(plan.structureStartedInFirst120));
   CsvAppend(line, BoolText(plan.entryAfterFirst120));
   CsvAppend(line, BoolText(plan.sessionGatePass));
   CsvAppend(line, plan.sessionGateRejectReason);
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
   CsvAppend(line, plan.transcriptContextMode);
   CsvAppend(line, BoolText(plan.transcriptContextPassed));
   CsvAppend(line, plan.transcriptStage);
   CsvAppend(line, plan.transcriptRejectReason);
   CsvAppend(line, plan.topSma75State);
   CsvAppend(line, plan.structureSma75State);
   CsvAppend(line, plan.primarySma75State);
   CsvAppend(line, IntegerToString(plan.structureBreakAgeBars));
   CsvAppend(line, DoubleToString(plan.structureBreakLevel, 8));
   CsvAppend(line, IntegerToString(plan.primaryBreakAgeBars));
   CsvAppend(line, DoubleToString(plan.primaryBreakLevel, 8));
   CsvAppend(line, BoolText(plan.nestedThirdwaveEnabled));
   CsvAppend(line, plan.nestedThirdwaveMode);
   CsvAppend(line, plan.h1ContextDirection);
   CsvAppend(line, plan.h1ContextImpulseDirection);
   CsvAppend(line, DoubleToString(plan.contextImpulseHigh, 8));
   CsvAppend(line, DoubleToString(plan.contextImpulseLow, 8));
   CsvAppend(line, DoubleToString(plan.h1ContextFibRetraceRatio, 4));
   CsvAppend(line, plan.h1ContextFibRoomBucket);
   CsvAppend(line, DoubleToString(plan.contextFibRoomScore, 3));
   CsvAppend(line, BoolText(plan.m15Wave1Candidate));
   CsvAppend(line, plan.m15Wave1Direction);
   CsvAppend(line, plan.m15Wave1BreakType);
   CsvAppend(line, DoubleToString(plan.m15Wave1BreakLevel, 8));
   CsvAppend(line, IntegerToString(plan.m15Wave1AgeBars));
   CsvAppend(line, DoubleToString(plan.m15Wave1High, 8));
   CsvAppend(line, DoubleToString(plan.m15Wave1Low, 8));
   CsvAppend(line, BoolText(plan.m15Wave2Candidate));
   CsvAppend(line, DoubleToString(plan.m15Wave2RetraceRatio, 4));
   CsvAppend(line, plan.m15Wave2FibZone);
   CsvAppend(line, DoubleToString(plan.m15Wave2FibScore, 3));
   CsvAppend(line, plan.m15WaveContextMode);
   CsvAppend(line, plan.m15Wave2ExpansionMode);
   CsvAppend(line, plan.m15Wave2GateMode);
   CsvAppend(line, plan.m15Wave2Type);
   CsvAppend(line, IntegerToString(plan.m15Wave2AgeBars));
   CsvAppend(line, DoubleToString(plan.m15Wave2Score, 3));
   CsvAppend(line, BoolText(plan.m15Wave2GatePass));
   CsvAppend(line, plan.m15Wave2GateRejectReason);
   CsvAppend(line, DoubleToString(plan.m15WaveContextScore, 3));
   CsvAppend(line, plan.m5PatternQualityGroup);
   CsvAppend(line, BoolText(plan.m15Wave2RequiredDueToPatternQuality));
   CsvAppend(line, BoolText(plan.m15Wave2ScoreApplied));
   CsvAppend(line, plan.m15Wave2AdjacentMode);
   CsvAppend(line, plan.m15Wave2AdjacentFibSide);
   CsvAppend(line, BoolText(plan.m15RequiredLightPass));
   CsvAppend(line, plan.m15RequiredLightRejectReason);
   CsvAppend(line, BoolText(plan.m15Wave2AdjacentPass));
   CsvAppend(line, plan.m15Wave2AdjacentReason);
   CsvAppend(line, plan.m15Wave2AdjacentRelaxedComponent);
   CsvAppend(line, BoolText(plan.m15Wave2NearMiss));
   CsvAppend(line, BoolText(plan.m5CorrectiveWaveDetected));
   CsvAppend(line, plan.m5CorrectiveDirection);
   CsvAppend(line, IntegerToString(plan.m5CorrectiveSwingCount));
   CsvAppend(line, BoolText(plan.m5Corrective123Detected));
   CsvAppend(line, BoolText(plan.m5CorrectiveABCDetected));
   CsvAppend(line, IntegerToString(plan.m5CorrectiveLegCount));
   CsvAppend(line, plan.m5CorrectiveStartTime > 0 ? TimeToString(plan.m5CorrectiveStartTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, plan.m5CorrectiveEndTime > 0 ? TimeToString(plan.m5CorrectiveEndTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, IntegerToString(plan.m5CorrectiveAgeBars));
   CsvAppend(line, DoubleToString(plan.m5CorrectivePullbackAtr, 4));
   CsvAppend(line, DoubleToString(plan.m5CorrectiveLastLHLevel, 8));
   CsvAppend(line, DoubleToString(plan.m5CorrectiveLastHLLevel, 8));
   CsvAppend(line, DoubleToString(plan.m5CorrectiveInvalidationLevel, 8));
   CsvAppend(line, BoolText(plan.m5CorrectiveInvalidation));
   CsvAppend(line, BoolText(plan.m5InvalidationDetected));
   CsvAppend(line, plan.m5InvalidationType);
   CsvAppend(line, DoubleToString(plan.m5InvalidationLevel, 8));
   CsvAppend(line, BoolText(plan.m5InvalidationCloseBreak));
   CsvAppend(line, DoubleToString(plan.m5InvalidationBreakAtr, 4));
   CsvAppend(line, DoubleToString(plan.m5InvalidationBodyAtr, 4));
   CsvAppend(line, BoolText(plan.postBreakAcceptancePass));
   CsvAppend(line, IntegerToString(plan.postBreakAcceptanceBars));
   CsvAppend(line, DoubleToString(plan.postBreakReturnAtr, 4));
   CsvAppend(line, BoolText(plan.firstRetestAfterInvalidation));
   CsvAppend(line, IntegerToString(plan.barsFromInvalidationToEntry));
   CsvAppend(line, DoubleToString(plan.retestLevel, 8));
   CsvAppend(line, DoubleToString(plan.retestDistanceAtr, 4));
   CsvAppend(line, plan.sma75State);
   CsvAppend(line, BoolText(plan.sma75Reclaim));
   CsvAppend(line, DoubleToString(plan.sma75GranvilleScore, 3));
   CsvAppend(line, DoubleToString(plan.nestedScore, 3));
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
   CsvAppend(line, plan.exitMode);
   CsvAppend(line, plan.structureTargetMode);
   CsvAppend(line, plan.structureTargetType);
   CsvAppend(line, DoubleToString(plan.structureTargetPrice, 8));
   CsvAppend(line, DoubleToString(plan.structureTargetR, 4));
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
     {
      if(tracked.structureTargetPrice > 0.0 &&
         MathAbs(tracked.takeProfit - tracked.structureTargetPrice) <= SymbolInfoDouble(tracked.symbol, SYMBOL_POINT) * 3.0)
         return "structure_target";
      return "tp";
     }
   if(StringFind(exitReason, "SL") >= 0)
     {
      if(tracked.breakEvenTriggered && resultR > -0.25 && resultR < 0.35)
         return "break_even";
      return "full_sl";
     }
   if(StringFind(exitReason, "EXPERT") >= 0 || holdingBars >= EffectiveMaxHoldBars())
      return "time";
   return "other";
  }

string TradeHeaderLine()
  {
   return "entry_time,exit_time,strategy,symbol,direction,server_time,server_hour,utc_hour,jst_hour," +
          "session_label,session_start_utc,minutes_from_session_start,trade_window_label,is_within_first_60min,is_within_first_120min," +
          "broker_utc_offset_used,selected_symbol_for_session,selected_reason,session_candidate_symbol_map," +
          "session_gate_mode,active_session_label,structure_started_in_first120,entry_after_first120,session_gate_pass,session_gate_reject_reason," +
          "entry_pattern,entry_trigger,neckline_level,ltf_wave3_timeframe,top_context_tf,structure_tf,primary_entry_tf,secondary_entry_tf,use_secondary_entry_tf," +
          "htf_alignment_mode,htf_permission_mode,allowed_direction,top_context_direction_state,structure_direction_state," +
          "h4_direction_state,h1_direction_state,rejected_by_htf_permission,candidate_long_detected,candidate_short_detected," +
          "selected_candidate_direction,selected_candidate_timeframe,selected_candidate_pattern,primary_best_pattern,primary_best_score,secondary_best_pattern,secondary_best_score," +
          "m15_best_pattern,m15_best_score,m5_best_pattern,m5_best_score," +
          "htf_wave3_direction,htf_wave3_confirmed,htf_fractal_alignment,wave3_alignment_passed," +
          "transcript_context_mode,transcript_context_passed,transcript_stage,transcript_reject_reason," +
          "top_sma75_state,structure_sma75_state,primary_sma75_state,structure_break_age_bars,structure_break_level,primary_break_age_bars,primary_break_level," +
          "nested_thirdwave_enabled,nested_thirdwave_mode,h1_context_direction,h1_context_impulse_direction,context_impulse_high,context_impulse_low," +
          "h1_context_fib_retrace_ratio,h1_context_fib_room_bucket,context_fib_room_score," +
          "m15_wave1_candidate,m15_wave1_direction,m15_wave1_break_type,m15_wave1_break_level,m15_wave1_age_bars,m15_wave1_high,m15_wave1_low," +
          "m15_wave2_candidate,m15_wave2_retrace_ratio,m15_wave2_fib_zone,m15_wave2_fib_score,m15_wave_context_mode," +
          "m15_wave2_expansion_mode,m15_wave2_gate_mode,m15_wave2_type,m15_wave2_age_bars,m15_wave2_score,m15_wave2_gate_pass,m15_wave2_gate_reject_reason," +
          "m15_wave_context_score,m5_pattern_quality_group,m15_wave2_required_due_to_pattern_quality,m15_wave2_score_applied," +
          "m15_wave2_adjacent_mode,m15_wave2_adjacent_fib_side,m15_required_light_pass,m15_required_light_reject_reason," +
          "m15_wave2_adjacent_pass,m15_wave2_adjacent_reason,m15_wave2_adjacent_relaxed_component,m15_wave2_near_miss," +
          "m5_corrective_wave_detected,m5_corrective_direction,m5_corrective_swing_count,m5_corrective_123_detected,m5_corrective_abc_detected," +
          "m5_corrective_leg_count,m5_corrective_start_time,m5_corrective_end_time,m5_corrective_age_bars,m5_corrective_pullback_atr," +
          "m5_corrective_last_lh_level,m5_corrective_last_hl_level,m5_corrective_invalidation_level,m5_corrective_invalidation," +
          "m5_invalidation_detected,m5_invalidation_type,m5_invalidation_level,m5_invalidation_close_break,m5_invalidation_break_atr,m5_invalidation_body_atr," +
          "post_break_acceptance_pass,post_break_acceptance_bars,post_break_return_atr,first_retest_after_invalidation,bars_from_invalidation_to_entry,retest_level,retest_distance_atr," +
          "sma75_state,sma75_reclaim,sma75_granville_score,nested_score," +
          "htf_nearest_resistance,htf_nearest_support," +
          "nearest_obstacle_price,nearest_obstacle_type,nearest_obstacle_distance_r,retest_reference_type,retest_reference_price,retest_reference_distance_atr," +
          "clean_path_to_target,hard_obstacle_present_before_target,soft_obstacle_present_before_target,obstacle_blocked," +
          "exit_mode,structure_target_mode,structure_target_type,structure_target_price,structure_target_r," +
          "target_reward_multiple,target_price,base_pattern_score,target_room_score,retest_score,fib_source_tf,fib_impulse_high,fib_impulse_low," +
          "fib_retrace_ratio,fib_zone,fib_score,fib_required_pass,time_bucket,time_score_removed_flag," +
          "candidate_orderable_before_session_selection,rejected_before_selection_reason,session_consumed_reason,final_score," +
          "entry,exit,stop_loss,take_profit,risk_price,result_r," +
          "initial_stop_loss_price,current_stop_loss_price,break_even_enabled,break_even_triggered,break_even_trigger_type," +
          "break_even_trigger_r,break_even_trigger_time,bars_to_break_even,max_favorable_r_before_exit,max_adverse_r_before_exit," +
          "reached_0_5r,reached_0_8r,reached_1_0r,reached_1_3r,reached_1_5r,bars_to_0_5r,bars_to_1_0r,bars_to_1_3r,mfe_before_failure_exit,mfe_before_time_exit," +
          "exit_type,full_sl_exit,break_even_exit,tp_exit,time_exit,structure_target_exit,result_r_before_be,result_r_after_be," +
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
   bool structureTargetExit = exitType == "structure_target";
   double resultRBeforeBE = tracked.breakEvenTriggered ? tracked.breakEvenTriggerR : resultR;
   double resultRAfterBE = tracked.breakEvenTriggered ? resultR - tracked.breakEvenTriggerR : 0.0;
   double netProfit = profit + commission + swap;
   double mfeBeforeFailureExit = StringFind(exitReason, "failure") >= 0 ||
                                 StringFind(exitReason, "structure") >= 0 ? tracked.maxFavorableRBeforeExit : 0.0;
   double mfeBeforeTimeExit = timeExit ? tracked.maxFavorableRBeforeExit : 0.0;

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
   CsvAppend(line, tracked.sessionGateMode);
   CsvAppend(line, tracked.activeSessionLabel);
   CsvAppend(line, BoolText(tracked.structureStartedInFirst120));
   CsvAppend(line, BoolText(tracked.entryAfterFirst120));
   CsvAppend(line, BoolText(tracked.sessionGatePass));
   CsvAppend(line, tracked.sessionGateRejectReason);
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
   CsvAppend(line, tracked.transcriptContextMode);
   CsvAppend(line, BoolText(tracked.transcriptContextPassed));
   CsvAppend(line, tracked.transcriptStage);
   CsvAppend(line, tracked.transcriptRejectReason);
   CsvAppend(line, tracked.topSma75State);
   CsvAppend(line, tracked.structureSma75State);
   CsvAppend(line, tracked.primarySma75State);
   CsvAppend(line, IntegerToString(tracked.structureBreakAgeBars));
   CsvAppend(line, DoubleToString(tracked.structureBreakLevel, 8));
   CsvAppend(line, IntegerToString(tracked.primaryBreakAgeBars));
   CsvAppend(line, DoubleToString(tracked.primaryBreakLevel, 8));
   CsvAppend(line, BoolText(tracked.nestedThirdwaveEnabled));
   CsvAppend(line, tracked.nestedThirdwaveMode);
   CsvAppend(line, tracked.h1ContextDirection);
   CsvAppend(line, tracked.h1ContextImpulseDirection);
   CsvAppend(line, DoubleToString(tracked.contextImpulseHigh, 8));
   CsvAppend(line, DoubleToString(tracked.contextImpulseLow, 8));
   CsvAppend(line, DoubleToString(tracked.h1ContextFibRetraceRatio, 4));
   CsvAppend(line, tracked.h1ContextFibRoomBucket);
   CsvAppend(line, DoubleToString(tracked.contextFibRoomScore, 3));
   CsvAppend(line, BoolText(tracked.m15Wave1Candidate));
   CsvAppend(line, tracked.m15Wave1Direction);
   CsvAppend(line, tracked.m15Wave1BreakType);
   CsvAppend(line, DoubleToString(tracked.m15Wave1BreakLevel, 8));
   CsvAppend(line, IntegerToString(tracked.m15Wave1AgeBars));
   CsvAppend(line, DoubleToString(tracked.m15Wave1High, 8));
   CsvAppend(line, DoubleToString(tracked.m15Wave1Low, 8));
   CsvAppend(line, BoolText(tracked.m15Wave2Candidate));
   CsvAppend(line, DoubleToString(tracked.m15Wave2RetraceRatio, 4));
   CsvAppend(line, tracked.m15Wave2FibZone);
   CsvAppend(line, DoubleToString(tracked.m15Wave2FibScore, 3));
   CsvAppend(line, tracked.m15WaveContextMode);
   CsvAppend(line, tracked.m15Wave2ExpansionMode);
   CsvAppend(line, tracked.m15Wave2GateMode);
   CsvAppend(line, tracked.m15Wave2Type);
   CsvAppend(line, IntegerToString(tracked.m15Wave2AgeBars));
   CsvAppend(line, DoubleToString(tracked.m15Wave2Score, 3));
   CsvAppend(line, BoolText(tracked.m15Wave2GatePass));
   CsvAppend(line, tracked.m15Wave2GateRejectReason);
   CsvAppend(line, DoubleToString(tracked.m15WaveContextScore, 3));
   CsvAppend(line, tracked.m5PatternQualityGroup);
   CsvAppend(line, BoolText(tracked.m15Wave2RequiredDueToPatternQuality));
   CsvAppend(line, BoolText(tracked.m15Wave2ScoreApplied));
   CsvAppend(line, tracked.m15Wave2AdjacentMode);
   CsvAppend(line, tracked.m15Wave2AdjacentFibSide);
   CsvAppend(line, BoolText(tracked.m15RequiredLightPass));
   CsvAppend(line, tracked.m15RequiredLightRejectReason);
   CsvAppend(line, BoolText(tracked.m15Wave2AdjacentPass));
   CsvAppend(line, tracked.m15Wave2AdjacentReason);
   CsvAppend(line, tracked.m15Wave2AdjacentRelaxedComponent);
   CsvAppend(line, BoolText(tracked.m15Wave2NearMiss));
   CsvAppend(line, BoolText(tracked.m5CorrectiveWaveDetected));
   CsvAppend(line, tracked.m5CorrectiveDirection);
   CsvAppend(line, IntegerToString(tracked.m5CorrectiveSwingCount));
   CsvAppend(line, BoolText(tracked.m5Corrective123Detected));
   CsvAppend(line, BoolText(tracked.m5CorrectiveABCDetected));
   CsvAppend(line, IntegerToString(tracked.m5CorrectiveLegCount));
   CsvAppend(line, tracked.m5CorrectiveStartTime > 0 ? TimeToString(tracked.m5CorrectiveStartTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, tracked.m5CorrectiveEndTime > 0 ? TimeToString(tracked.m5CorrectiveEndTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(line, IntegerToString(tracked.m5CorrectiveAgeBars));
   CsvAppend(line, DoubleToString(tracked.m5CorrectivePullbackAtr, 4));
   CsvAppend(line, DoubleToString(tracked.m5CorrectiveLastLHLevel, 8));
   CsvAppend(line, DoubleToString(tracked.m5CorrectiveLastHLLevel, 8));
   CsvAppend(line, DoubleToString(tracked.m5CorrectiveInvalidationLevel, 8));
   CsvAppend(line, BoolText(tracked.m5CorrectiveInvalidation));
   CsvAppend(line, BoolText(tracked.m5InvalidationDetected));
   CsvAppend(line, tracked.m5InvalidationType);
   CsvAppend(line, DoubleToString(tracked.m5InvalidationLevel, 8));
   CsvAppend(line, BoolText(tracked.m5InvalidationCloseBreak));
   CsvAppend(line, DoubleToString(tracked.m5InvalidationBreakAtr, 4));
   CsvAppend(line, DoubleToString(tracked.m5InvalidationBodyAtr, 4));
   CsvAppend(line, BoolText(tracked.postBreakAcceptancePass));
   CsvAppend(line, IntegerToString(tracked.postBreakAcceptanceBars));
   CsvAppend(line, DoubleToString(tracked.postBreakReturnAtr, 4));
   CsvAppend(line, BoolText(tracked.firstRetestAfterInvalidation));
   CsvAppend(line, IntegerToString(tracked.barsFromInvalidationToEntry));
   CsvAppend(line, DoubleToString(tracked.retestLevel, 8));
   CsvAppend(line, DoubleToString(tracked.retestDistanceAtr, 4));
   CsvAppend(line, tracked.sma75State);
   CsvAppend(line, BoolText(tracked.sma75Reclaim));
   CsvAppend(line, DoubleToString(tracked.sma75GranvilleScore, 3));
   CsvAppend(line, DoubleToString(tracked.nestedScore, 3));
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
   CsvAppend(line, tracked.exitMode);
   CsvAppend(line, tracked.structureTargetMode);
   CsvAppend(line, tracked.structureTargetType);
   CsvAppend(line, DoubleToString(tracked.structureTargetPrice, 8));
   CsvAppend(line, DoubleToString(tracked.structureTargetR, 4));
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
   CsvAppend(line, BoolText(tracked.reached05R));
   CsvAppend(line, BoolText(tracked.reached08R));
   CsvAppend(line, BoolText(tracked.reached10R));
   CsvAppend(line, BoolText(tracked.reached13R));
   CsvAppend(line, BoolText(tracked.reached15R));
   CsvAppend(line, IntegerToString(tracked.barsTo05R));
   CsvAppend(line, IntegerToString(tracked.barsTo10R));
   CsvAppend(line, IntegerToString(tracked.barsTo13R));
   CsvAppend(line, DoubleToString(mfeBeforeFailureExit, 4));
   CsvAppend(line, DoubleToString(mfeBeforeTimeExit, 4));
   CsvAppend(line, exitType);
   CsvAppend(line, BoolText(fullSlExit));
   CsvAppend(line, BoolText(breakEvenExit));
   CsvAppend(line, BoolText(tpExit));
   CsvAppend(line, BoolText(timeExit));
   CsvAppend(line, BoolText(structureTargetExit));
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
                 "require_retest_close_beyond_neckline", "transcript_context_mode",
                 "transcript_sma_period", "transcript_structure_break_max_bars",
                 "transcript_primary_break_max_bars", "transcript_require_structure_break",
                 "transcript_require_sma_reclaim", "transcript_require_prior_impulse",
                 "transcript_prior_impulse_min_pivots", "transcript_use_primary_failure_exit",
                 "transcript_exit_lookback_bars", "break_even_mode",
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
               TranscriptContextModeName(),
               IntegerToString(InpTranscriptSmaPeriod),
               IntegerToString(InpTranscriptStructureBreakMaxBars),
               IntegerToString(InpTranscriptPrimaryBreakMaxBars),
               BoolText(InpTranscriptRequireStructureBreak),
               BoolText(InpTranscriptRequireSmaReclaim),
               BoolText(InpTranscriptRequirePriorImpulse),
               IntegerToString(InpTranscriptPriorImpulseMinPivots),
               BoolText(InpTranscriptUsePrimaryFailureExit),
               IntegerToString(InpTranscriptExitLookbackBars),
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

void UpdateTradeExcursionThresholds(TrackedTrade &tracked, const double favorable)
  {
   int heldBars = iBarShift(tracked.symbol, InpPrimaryEntryTF, tracked.entryTime, false);
   if(favorable >= 0.5 && !tracked.reached05R)
     {
      tracked.reached05R = true;
      tracked.barsTo05R = heldBars;
     }
   if(favorable >= 0.8)
      tracked.reached08R = true;
   if(favorable >= 1.0 && !tracked.reached10R)
     {
      tracked.reached10R = true;
      tracked.barsTo10R = heldBars;
     }
   if(favorable >= 1.3 && !tracked.reached13R)
     {
      tracked.reached13R = true;
      tracked.barsTo13R = heldBars;
     }
   if(favorable >= 1.5)
      tracked.reached15R = true;
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
   UpdateTradeExcursionThresholds(tracked, favorable);
  }

void UpdateTradeExcursionWithPrice(TrackedTrade &tracked, const double price)
  {
   double favorable = TradeFavorableR(tracked, price);
   tracked.maxFavorableRBeforeExit = MathMax(tracked.maxFavorableRBeforeExit, favorable);
   tracked.maxAdverseRBeforeExit = MathMax(tracked.maxAdverseRBeforeExit, TradeAdverseR(tracked, price));
   UpdateTradeExcursionThresholds(tracked, favorable);
  }

void ManageTradeExcursions()
  {
   for(int i = 0; i < ArraySize(g_trades); ++i)
     {
      if(!g_trades[i].active)
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
      if(rates[0].time <= g_trades[i].lastExcursionBarTime)
         continue;
      g_trades[i].lastExcursionBarTime = rates[0].time;
      UpdateTradeExcursionWithBar(g_trades[i], rates[0]);
     }
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

bool TranscriptPrimaryFailureExitSignal(TrackedTrade &tracked,
                                        const MqlRates &rates[],
                                        string &exitReason)
  {
   exitReason = "none";
   if(!UsesPrimaryFailureExit())
      return false;

   int heldBars = iBarShift(tracked.symbol, InpPrimaryEntryTF, tracked.entryTime, false);
   if(heldBars < 2)
      return false;

   double atr = ATR(rates, 0, InpATRPeriod);
   if(atr <= 0.0)
      return false;

   int lookback = MathMin(InpTranscriptExitLookbackBars, ArraySize(rates) - 2);
   if(lookback < 4)
      return false;

   double fast = SMA(rates, 0, InpMAPeriodFast);
   double slow = SMA(rates, 0, InpMAPeriodSlow);
   double buffer = atr * MathMax(0.0, InpBreakBufferATR);

   if(tracked.direction == "LONG")
     {
      double recentLow = LowestLow(rates, 1, lookback);
      if(recentLow > 0.0 && rates[0].close < recentLow - buffer)
        {
         exitReason = "transcript_m5_structure_low_break_exit";
         return true;
        }
      if(tracked.necklineLevel > 0.0 && rates[0].close < tracked.necklineLevel - buffer)
        {
         exitReason = "transcript_neckline_failure_exit";
         return true;
        }
      if(heldBars >= 3 && fast > 0.0 && slow > 0.0 && fast < slow && rates[0].close < fast)
        {
         exitReason = "transcript_m5_ma_failure_exit";
         return true;
        }
     }
   else if(tracked.direction == "SHORT")
     {
      double recentHigh = HighestHigh(rates, 1, lookback);
      if(recentHigh > 0.0 && rates[0].close > recentHigh + buffer)
        {
         exitReason = "transcript_m5_structure_high_break_exit";
         return true;
        }
      if(tracked.necklineLevel > 0.0 && rates[0].close > tracked.necklineLevel + buffer)
        {
         exitReason = "transcript_neckline_failure_exit";
         return true;
        }
      if(heldBars >= 3 && fast > 0.0 && slow > 0.0 && fast > slow && rates[0].close > fast)
        {
         exitReason = "transcript_m5_ma_failure_exit";
         return true;
        }
     }

   return false;
  }

void ManageTranscriptPrimaryFailureExits()
  {
   if(!UsesPrimaryFailureExit())
      return;

   trade.SetExpertMagicNumber(InpMagicNumber);
   for(int i = 0; i < ArraySize(g_trades); ++i)
     {
      if(!g_trades[i].active)
         continue;
      if(!PositionSelect(g_trades[i].symbol))
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if((long)PositionGetInteger(POSITION_IDENTIFIER) != g_trades[i].positionId)
         continue;

      int bars = MathMax(InpTranscriptExitLookbackBars + InpMAPeriodSlow + 10, InpATRPeriod + InpMAPeriodSlow + 12);
      MqlRates rates[];
      if(!CopyClosedRates(g_trades[i].symbol, InpPrimaryEntryTF, bars, rates))
         continue;

      UpdateTradeExcursionWithBar(g_trades[i], rates[0]);

      string exitReason = "none";
      if(!TranscriptPrimaryFailureExitSignal(g_trades[i], rates, exitReason))
         continue;

      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      if(ticket > 0)
         trade.PositionClose(ticket);
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
   g_trades[size].sessionGateMode = plan.sessionGateMode;
   g_trades[size].activeSessionLabel = plan.activeSessionLabel;
   g_trades[size].structureStartedInFirst120 = plan.structureStartedInFirst120;
   g_trades[size].entryAfterFirst120 = plan.entryAfterFirst120;
   g_trades[size].sessionGatePass = plan.sessionGatePass;
   g_trades[size].sessionGateRejectReason = plan.sessionGateRejectReason;
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
   g_trades[size].transcriptContextMode = plan.transcriptContextMode;
   g_trades[size].transcriptContextPassed = plan.transcriptContextPassed;
   g_trades[size].transcriptStage = plan.transcriptStage;
   g_trades[size].transcriptRejectReason = plan.transcriptRejectReason;
   g_trades[size].topSma75State = plan.topSma75State;
   g_trades[size].structureSma75State = plan.structureSma75State;
   g_trades[size].primarySma75State = plan.primarySma75State;
   g_trades[size].structureBreakAgeBars = plan.structureBreakAgeBars;
   g_trades[size].structureBreakLevel = plan.structureBreakLevel;
   g_trades[size].primaryBreakAgeBars = plan.primaryBreakAgeBars;
   g_trades[size].primaryBreakLevel = plan.primaryBreakLevel;
   g_trades[size].nestedThirdwaveEnabled = plan.nestedThirdwaveEnabled;
   g_trades[size].nestedThirdwaveMode = plan.nestedThirdwaveMode;
   g_trades[size].h1ContextDirection = plan.h1ContextDirection;
   g_trades[size].h1ContextImpulseDirection = plan.h1ContextImpulseDirection;
   g_trades[size].contextImpulseHigh = plan.contextImpulseHigh;
   g_trades[size].contextImpulseLow = plan.contextImpulseLow;
   g_trades[size].h1ContextFibRetraceRatio = plan.h1ContextFibRetraceRatio;
   g_trades[size].h1ContextFibRoomBucket = plan.h1ContextFibRoomBucket;
   g_trades[size].contextFibRoomScore = plan.contextFibRoomScore;
   g_trades[size].m15Wave1Candidate = plan.m15Wave1Candidate;
   g_trades[size].m15Wave1Direction = plan.m15Wave1Direction;
   g_trades[size].m15Wave1BreakType = plan.m15Wave1BreakType;
   g_trades[size].m15Wave1BreakLevel = plan.m15Wave1BreakLevel;
   g_trades[size].m15Wave1AgeBars = plan.m15Wave1AgeBars;
   g_trades[size].m15Wave1High = plan.m15Wave1High;
   g_trades[size].m15Wave1Low = plan.m15Wave1Low;
   g_trades[size].m15Wave2Candidate = plan.m15Wave2Candidate;
   g_trades[size].m15Wave2RetraceRatio = plan.m15Wave2RetraceRatio;
   g_trades[size].m15Wave2FibZone = plan.m15Wave2FibZone;
   g_trades[size].m15Wave2FibScore = plan.m15Wave2FibScore;
   g_trades[size].m15WaveContextMode = plan.m15WaveContextMode;
   g_trades[size].m15Wave2ExpansionMode = plan.m15Wave2ExpansionMode;
   g_trades[size].m15Wave2GateMode = plan.m15Wave2GateMode;
   g_trades[size].m15Wave2Type = plan.m15Wave2Type;
   g_trades[size].m15Wave2AgeBars = plan.m15Wave2AgeBars;
   g_trades[size].m15Wave2Score = plan.m15Wave2Score;
   g_trades[size].m15Wave2GatePass = plan.m15Wave2GatePass;
   g_trades[size].m15Wave2GateRejectReason = plan.m15Wave2GateRejectReason;
   g_trades[size].m15WaveContextScore = plan.m15WaveContextScore;
   g_trades[size].m5PatternQualityGroup = plan.m5PatternQualityGroup;
   g_trades[size].m15Wave2RequiredDueToPatternQuality = plan.m15Wave2RequiredDueToPatternQuality;
   g_trades[size].m15Wave2ScoreApplied = plan.m15Wave2ScoreApplied;
   g_trades[size].m15Wave2AdjacentMode = plan.m15Wave2AdjacentMode;
   g_trades[size].m15Wave2AdjacentFibSide = plan.m15Wave2AdjacentFibSide;
   g_trades[size].m15RequiredLightPass = plan.m15RequiredLightPass;
   g_trades[size].m15RequiredLightRejectReason = plan.m15RequiredLightRejectReason;
   g_trades[size].m15Wave2AdjacentPass = plan.m15Wave2AdjacentPass;
   g_trades[size].m15Wave2AdjacentReason = plan.m15Wave2AdjacentReason;
   g_trades[size].m15Wave2AdjacentRelaxedComponent = plan.m15Wave2AdjacentRelaxedComponent;
   g_trades[size].m15Wave2NearMiss = plan.m15Wave2NearMiss;
   g_trades[size].m5CorrectiveWaveDetected = plan.m5CorrectiveWaveDetected;
   g_trades[size].m5CorrectiveDirection = plan.m5CorrectiveDirection;
   g_trades[size].m5CorrectiveSwingCount = plan.m5CorrectiveSwingCount;
   g_trades[size].m5Corrective123Detected = plan.m5Corrective123Detected;
   g_trades[size].m5CorrectiveABCDetected = plan.m5CorrectiveABCDetected;
   g_trades[size].m5CorrectiveLegCount = plan.m5CorrectiveLegCount;
   g_trades[size].m5CorrectiveStartTime = plan.m5CorrectiveStartTime;
   g_trades[size].m5CorrectiveEndTime = plan.m5CorrectiveEndTime;
   g_trades[size].m5CorrectiveAgeBars = plan.m5CorrectiveAgeBars;
   g_trades[size].m5CorrectivePullbackAtr = plan.m5CorrectivePullbackAtr;
   g_trades[size].m5CorrectiveLastLHLevel = plan.m5CorrectiveLastLHLevel;
   g_trades[size].m5CorrectiveLastHLLevel = plan.m5CorrectiveLastHLLevel;
   g_trades[size].m5CorrectiveInvalidationLevel = plan.m5CorrectiveInvalidationLevel;
   g_trades[size].m5CorrectiveInvalidation = plan.m5CorrectiveInvalidation;
   g_trades[size].m5InvalidationType = plan.m5InvalidationType;
   g_trades[size].m5InvalidationLevel = plan.m5InvalidationLevel;
   g_trades[size].m5InvalidationDetected = plan.m5InvalidationDetected;
   g_trades[size].m5InvalidationCloseBreak = plan.m5InvalidationCloseBreak;
   g_trades[size].m5InvalidationBreakAtr = plan.m5InvalidationBreakAtr;
   g_trades[size].m5InvalidationBodyAtr = plan.m5InvalidationBodyAtr;
   g_trades[size].postBreakAcceptancePass = plan.postBreakAcceptancePass;
   g_trades[size].postBreakAcceptanceBars = plan.postBreakAcceptanceBars;
   g_trades[size].postBreakReturnAtr = plan.postBreakReturnAtr;
   g_trades[size].firstRetestAfterInvalidation = plan.firstRetestAfterInvalidation;
   g_trades[size].barsFromInvalidationToEntry = plan.barsFromInvalidationToEntry;
   g_trades[size].retestLevel = plan.retestLevel;
   g_trades[size].retestDistanceAtr = plan.retestDistanceAtr;
   g_trades[size].sma75State = plan.sma75State;
   g_trades[size].sma75Reclaim = plan.sma75Reclaim;
   g_trades[size].sma75GranvilleScore = plan.sma75GranvilleScore;
   g_trades[size].nestedScore = plan.nestedScore;
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
   g_trades[size].exitMode = plan.exitMode;
   g_trades[size].structureTargetMode = plan.structureTargetMode;
   g_trades[size].structureTargetType = plan.structureTargetType;
   g_trades[size].structureTargetPrice = plan.structureTargetPrice;
   g_trades[size].structureTargetR = plan.structureTargetR;
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
   g_trades[size].lastExcursionBarTime = 0;
   g_trades[size].reached05R = false;
   g_trades[size].reached08R = false;
   g_trades[size].reached10R = false;
   g_trades[size].reached13R = false;
   g_trades[size].reached15R = false;
   g_trades[size].barsTo05R = -1;
   g_trades[size].barsTo10R = -1;
   g_trades[size].barsTo13R = -1;
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
   int maxHoldBars = EffectiveMaxHoldBars();
   if(maxHoldBars <= 0)
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
      if(shift >= maxHoldBars)
         trade.PositionClose(ticket);
     }
  }

void ScanSymbols()
  {
   UpdateRiskAnchors();
   ManageTradeExcursions();
   ManageTranscriptPrimaryFailureExits();
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
        {
         if(InpSessionGateMode != SESSION_GATE_NONE_DIAGNOSTIC &&
            InpSessionGateMode != SESSION_GATE_ACTIVE_LABEL_ONLY)
            continue;
         ArrayResize(sessions, 1);
         BuildNoSessionInfo(barTime, sessions[0]);
        }

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
       InpTranscriptSmaPeriod < 10 ||
       InpTranscriptStructureBreakMaxBars < 0 ||
       InpTranscriptPrimaryBreakMaxBars < 0 ||
       InpTranscriptPriorImpulseMinPivots < 3 ||
       InpTranscriptExitLookbackBars < 4 ||
       InpPostBreakAcceptanceBars < 0 ||
       InpM5CorrectiveMinSwings < 2 ||
       InpM5CorrectiveMaxAgeBars < 6 ||
       InpM5CorrectiveMinPullbackAtr < 0.0 ||
       InpM5CorrectiveMaxPullbackAtr < InpM5CorrectiveMinPullbackAtr ||
       InpM5InvalidationMinBodyAtr < 0.0 ||
       InpM5InvalidationMinBreakAtr < 0.0 ||
       InpPostBreakMaxReturnAtr < 0.0 ||
       InpFirstRetestMaxBars < 1 ||
       InpM15Wave2MaxAgeBars < 1 ||
       InpM15Wave2MinRetrace < 0.0 ||
       InpM15Wave2PreferredMin < InpM15Wave2MinRetrace ||
       InpM15Wave2PreferredMax < InpM15Wave2PreferredMin ||
       InpM15Wave2AdjacentAgeExtraBars < 0 ||
       InpM15Wave2AdjacentCombineMask < 0 ||
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
