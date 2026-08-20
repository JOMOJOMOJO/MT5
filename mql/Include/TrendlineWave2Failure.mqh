//+------------------------------------------------------------------+
//| TrendlineWave2Failure.mqh                                        |
//| Independent TRENDLINE_WAVE2_FAILURE research bucket.             |
//+------------------------------------------------------------------+

// SOURCE_RULE:
// A structure-breaking H4 impulse is followed by a mature H1 trend,
// an opposite H1 trendline break, a Wave-2-like pullback, and an M15
// failure of the old trend before entry in the reversal direction.
//
// OPERATIONAL_DEFINITION:
// The discretionary ideas above are represented by closed-bar state
// transitions and SMA-slope-confirmed swings.  Every swing stores both
// the price-extreme time and the later time at which it became knowable.
//
// RESEARCH_PARAMETER:
// Every numerical threshold exposed below (ATR multiples, percentile,
// expiry, buffers, fixed 2R and risk limits) is an initial test value,
// not a value recommended by the source material.

static const string TW2F_STRATEGY_NAME = "TRENDLINE_WAVE2_FAILURE";

enum ENUM_BUCKET_MODE
  {
   BUCKET_LEGACY_ONLY = 0,
   BUCKET_TRENDLINE_WAVE2_FAILURE_ONLY = 1,
   BUCKET_LEGACY_AND_TRENDLINE_WAVE2_FAILURE = 2
  };

enum ENUM_TW2F_DIRECTION_MODE
  {
   TW2F_LONG_AND_SHORT = 0,
   TW2F_LONG_ONLY = 1,
   TW2F_SHORT_ONLY = 2
  };

enum ENUM_TW2F_SETUP_STATE
  {
   TW2F_STATE_IDLE = 0,
   TW2F_STATE_H4_IMPULSE_DETECTED,
   TW2F_STATE_H1_STRUCTURE_RECONSTRUCTED,
   TW2F_STATE_H1_TREND_MATURE,
   TW2F_STATE_H1_TRENDLINE_BROKEN,
   TW2F_STATE_H1_REVERSAL_LEG,
   TW2F_STATE_M15_PULLBACK_ACTIVE,
   TW2F_STATE_M15_CONTINUATION_FAILED,
   TW2F_STATE_M15_STRUCTURE_BROKEN,
   TW2F_STATE_ENTRY_READY,
   TW2F_STATE_POSITION_OPEN,
   TW2F_STATE_INVALIDATED,
   TW2F_STATE_EXPIRED
  };

enum ENUM_TW2F_STOP_MODE
  {
   TW2F_STOP_FULL_PATTERN_EXTREME = 0,
   TW2F_STOP_LATEST_M15_SWING_EXTREME = 1,
   TW2F_STOP_H1_WAVE2_EXTREME = 2
  };

enum ENUM_TW2F_LOT_MODE
  {
   TW2F_LOT_FIXED = 0,
   TW2F_LOT_PERCENT_RISK = 1
  };

enum ENUM_TW2F_RISK_BASE
  {
   TW2F_RISK_BALANCE = 0,
   TW2F_RISK_EQUITY = 1
  };

enum ENUM_TW2F_TAKE_PROFIT_MODE
  {
   TW2F_TAKE_PROFIT_FIXED_R = 0
  };

struct TW2FSwing
  {
   int               kind;              // +1 high, -1 low
   int               shift;
   double            price;
   datetime          pivotTime;
   datetime          confirmationTime;
  };

struct TW2FSetup
  {
   string            symbol;
   int               direction;         // entry direction: +1 long, -1 short
   ENUM_TW2F_SETUP_STATE state;
   ENUM_TW2F_SETUP_STATE previousState;
   datetime          stateChangedAt;
   string            stateReason;
   string            setupId;
   bool              traded;
   datetime          eligibleAfter;

   datetime          h4RecognizedAt;
   datetime          h4ImpulseStart;
   datetime          h4ImpulseEnd;
   double            h4ImpulseHigh;
   double            h4ImpulseLow;
   bool              h4PriorTrendValid;
   double            h4ProtectedSwing;
   datetime          h4ProtectedPivotTime;
   datetime          h4ProtectedConfirmationTime;
   int               h4ImpulseWindowBars;
   double            h4PreImpulseAtr;
   double            h4NormalizedMove;
   double            h4ImpulsePercentile;
   double            h4DirectionalEfficiency;
   double            h4CloseLocation;
   double            h4ImpulseScore;
   bool              h4StructureBreak;

   datetime          h1SequenceStartTime;
   double            h1SequenceStartPrice;
   double            h1SequenceStartAtr;
   datetime          h1MatureTime;
   int               h1CounterHighCount;
   int               h1CounterLowCount;
   int               h1TrendBars;
   double            h1TrendDistanceAtr;
   string            h1LegDistancesAtr;
   datetime          h1TrendlinePoint1Time;
   datetime          h1TrendlinePoint2Time;
   double            h1TrendlinePoint1Price;
   double            h1TrendlinePoint2Price;
   double            h1TrendlinePrice;
   double            h1TrendlineSlopePerSecond;
   int               h1TrendlineTouches;
   double            h1BreakDistanceAtr;
   datetime          h1BreakTime;
   double            h1Wave1Origin;
   datetime          h1Wave1OriginPivotTime;
   datetime          h1Wave1OriginConfirmationTime;
   double            h1Wave1ProvisionalExtreme;

   datetime          m15PullbackStartTime;
   string            m15StructureDirection;
   double            m15ReferenceExtreme;
   datetime          m15ReferencePivotTime;
   datetime          m15ReferenceConfirmationTime;
   datetime          m15LastCounterStructureConfirmationTime;
   double            m15PriorReferenceExtreme;
   datetime          m15PriorReferencePivotTime;
   datetime          m15PriorReferenceConfirmationTime;
   double            m15ProtectedSwing;
   datetime          m15ProtectedPivotTime;
   datetime          m15ProtectedConfirmationTime;
   double            m15PostAnchorExtreme;
   datetime          m15PostAnchorPivotTime;
   datetime          m15PostAnchorConfirmationTime;
   datetime          m15LastCountedPostAnchorConfirmationTime;
   string            m15PatternType;
   double            m15Point1;
   double            m15Point2;
   double            m15PatternNeckline;
   double            m15PatternHeightAtr;
   double            m15BreakExtensionAtr;
   double            m15PatternExtreme;
   double            h1Wave2Extreme;
   datetime          signalTime;
   datetime          signalBarTime;
   double            signalClosePrice;
   double            signalAtr;
   double            signalBreakBodyAtr;
   datetime          lastPivotTime;
   datetime          lastConfirmationTime;

   double            requestedEntryPrice;
   double            filledEntryPrice;
   double            slBeforeAdjustment;
   double            slAfterAdjustment;
   double            takeProfit;
   double            stopDistance;
   double            lot;
   double            plannedRiskMoney;
   double            actualInitialRiskMoney;
   double            plannedRr;
   double            estimatedCostR;
   double            spread;
   double            slippage;
   double            requiredMargin;
   double            projectedMarginLevel;
   double            totalOpenRiskPercent;
   double            currencyDirectionRiskPercent;
   double            dailyDrawdownPercent;
   double            weeklyDrawdownPercent;
   double            equityDrawdownPercent;
   string            rejectReason;
  };

struct TW2FBarClock
  {
   string            symbol;
   datetime          lastH4Bar;
   datetime          lastH1Bar;
   datetime          lastM15Bar;
  };

struct TW2FExpiryShadow
  {
   bool              active;
   bool              written;
   string            symbol;
   int               direction;
   string            setupId;
   datetime          h1BreakTime;
   double            h1Wave1Origin;
   datetime          expiryTime;
   int               expiryM15HighCount;
   int               expiryM15LowCount;
   datetime          firstCounterStructureTime;
   int               counterH1BarsFromBreak;
   int               counterH1BarsAfterExpiry;
   datetime          shadowAnchorTime;
   int               anchorH1BarsFromBreak;
   int               anchorH1BarsAfterExpiry;
   datetime          h1Wave1OriginBreakTime;
   bool              anchorBeforeOriginBreak;
   bool              noAnchorWithin240;
   int               observedH1BarsAfterExpiry;
   string            status;
  };

struct TW2FCandidate
  {
   bool              valid;
   int               stateIndex;
   string            symbol;
   int               direction;
   string            setupId;
   datetime          signalTime;
   double            signalClosePrice;
   double            requestedEntryPrice;
   double            stopLoss;
   double            takeProfit;
   double            riskPrice;
   double            atr;
   double            volume;
   double            plannedRiskMoney;
   double            estimatedCostR;
   double            requiredMargin;
   double            projectedMarginLevel;
   double            totalOpenRiskPercent;
   double            currencyDirectionRiskPercent;
  };

struct TW2FTrackedTrade
  {
   bool              active;
   ulong             ticket;
   long              positionId;
   string            symbol;
   int               direction;
   string            setupId;
   datetime          entryTime;
   double            signalClosePrice;
   double            requestedEntryPrice;
   double            entryPrice;
   double            initialStop;
   double            takeProfit;
   double            riskPrice;
   double            volume;
   double            initialRiskMoney;
   double            estimatedCostR;
   double            maxFavorableR;
   double            maxAdverseR;
   bool              recoveredAfterRestart;
  };

struct TW2FReasonCounter
  {
   string            reason;
   long              count;
  };

input ENUM_BUCKET_MODE InpBucketMode = BUCKET_LEGACY_ONLY;
input ENUM_TW2F_DIRECTION_MODE InpTW2FDirectionMode = TW2F_LONG_AND_SHORT;
input ENUM_TIMEFRAMES InpContextTF = PERIOD_H4;
input ENUM_TIMEFRAMES InpSetupTF = PERIOD_H1;
input ENUM_TIMEFRAMES InpEntryTF = PERIOD_M15;
input int             InpMAPeriod = 20;
// InpATRPeriod is shared with the legacy EA and defaults to 14.
input double          InpMinMASlopeATR = 0.02;
input int             InpMASlopeConfirmationBars = 2;
input double          InpMinimumSwingDistanceATR = 0.50;
input int             InpMinBarsBetweenSwings = 3;
input bool            InpRequirePriorH4Trend = true;
input double          InpImpulseMinATR = 1.50;
input int             InpImpulseLookbackBars = 250;
input double          InpImpulsePercentile = 95.0;
input double          InpMinimumDirectionalEfficiency = 0.65;
input double          InpImpulseCloseLocation = 0.25;
input double          InpStructureBreakBufferATR = 0.05;
input int             InpMaximumImpulseWindowBars = 3;
input int             InpH1RequiredLowerHighs = 2;
input int             InpH1RequiredLowerLows = 2;
input double          InpH1MinimumTrendATR = 2.50;
input int             InpH1MinimumTrendBars = 12;
input int             InpTrendlineMinBars = 3;
input double          InpTrendlineMinHeightATR = 0.10;
input double          InpTrendlineBreakBufferATR = 0.05;
input double          InpWaveInvalidationBufferATR = 0.05;
input double          InpEqualBottomToleranceATR = 0.20;
input double          InpHigherLowMaxATR = 0.60;
input double          InpFalseBreakMaxATR = 0.50;
input int             InpPatternMinBars = 3;
input int             InpPatternMaxBars = 24;
input double          InpMinimumPatternHeightATR = 0.50;
input int             InpMinimumEntryBufferPoints = 5;
input double          InpEntryBufferATR = 0.03;
input bool            InpRequireM15MASlope = true;
input double          InpMaxBreakExtensionATR = 0.50;
input double          InpMaxBreakCandleATR = 1.50;
input ENUM_TW2F_STOP_MODE InpTW2FStopMode = TW2F_STOP_FULL_PATTERN_EXTREME;
input double          InpSLSpreadMultiplier = 1.50;
input double          InpSLBufferATR = 0.15;
input ENUM_TW2F_TAKE_PROFIT_MODE InpTakeProfitMode = TW2F_TAKE_PROFIT_FIXED_R;
input double          InpTakeProfitR = 2.0;
input double          InpMinimumPlannedRR = 2.0;
input ENUM_TW2F_LOT_MODE InpLotMode = TW2F_LOT_PERCENT_RISK;
input ENUM_TW2F_RISK_BASE InpRiskBase = TW2F_RISK_EQUITY;
input double          InpRiskPercent = 0.50;
input double          InpFixedLot = 0.01;
input double          InpRiskMoneyTolerancePercent = 1.0;
input double          InpTW2FMaxTotalOpenRiskPercent = 2.0;
input int             InpMaxOpenPositionsTotal = 4;
input int             InpMaxOpenPositionsPerSymbol = 1;
input int             InpMaxSameDirectionPositions = 3;
input int             InpMaxEntriesPerSetup = 1;
input double          InpMaxRiskPerCurrencyDirectionPercent = 1.0;
input double          InpMinimumProjectedMarginLevelPercent = 200.0;
input double          InpDailyEquityDrawdownLimitPercent = 2.0;
input bool            InpClosePositionsOnDailyStop = false;
input double          InpWeeklyEquityDrawdownLimitPercent = 4.0;
input double          InpMaxEquityDrawdownPercent = 10.0;
input bool            InpClosePositionsOnHardStop = false;
input double          InpMaxEstimatedCostR = 0.10;
input double          InpEstimatedCommissionPerLotRoundTrip = -1.0; // negative = unavailable
input double          InpEstimatedSlippagePointsPerSide = 0.0;
input int             InpH1SetupExpiryBars = 72;
input int             InpM15PatternExpiryBars = 32;
input long            InpTW2FMagicNumber = 2026081501;
input bool            InpTW2FEmergencyDisable = false;
input int             InpTW2FLookbackBars = 420;
input string          InpTW2FLogFolder = "trendline_wave2_failure";

TW2FSetup        g_tw2fSetups[];
TW2FBarClock     g_tw2fClocks[];
TW2FTrackedTrade g_tw2fTrades[];
TW2FReasonCounter g_tw2fRejections[];
string           g_tw2fTradedSetupKeys[];
TW2FExpiryShadow g_tw2fExpiryShadows[];

static const int TW2F_SHADOW_MAX_H1_BARS = 240;

double           g_tw2fPeakEquity = 0.0;
double           g_tw2fDayStartEquity = 0.0;
double           g_tw2fWeekStartEquity = 0.0;
int              g_tw2fDayKey = 0;
int              g_tw2fWeekKey = 0;
bool             g_tw2fDailyStopped = false;
bool             g_tw2fWeeklyStopped = false;
bool             g_tw2fHardStopped = false;
bool             g_tw2fClosingForStop = false;

long g_tw2fH4PriorTrendCandidates = 0;
long g_tw2fH4ImpulseCandidates = 0;
long g_tw2fH4Impulses = 0;
long g_tw2fH4StructureBreaks = 0;
long g_tw2fH1Mature = 0;
long g_tw2fH1TrendlineBreaks = 0;
long g_tw2fM15Pullbacks = 0;
long g_tw2fM15Failures = 0;
long g_tw2fM15Breaks = 0;
long g_tw2fCountertrendStructure = 0;
long g_tw2fAnchorFrozen = 0;
long g_tw2fPostAnchorSwing = 0;
long g_tw2fEqualExtreme = 0;
long g_tw2fHigherLowOrLowerHigh = 0;
long g_tw2fFalseBreakRecovery = 0;
long g_tw2fTripleExtreme = 0;
long g_tw2fFailureInvalidated = 0;
long g_tw2fContinuationFailure = 0;
long g_tw2fProtectedBreak = 0;
long g_tw2fMAFilterReject = 0;
long g_tw2fPatternReachabilityTestsPassed = 0;
long g_tw2fPatternReachabilityTestsFailed = 0;
long g_tw2fM15PathTestsPassed = 0;
long g_tw2fM15PathTestsFailed = 0;
long g_tw2fShadowStarted = 0;
long g_tw2fShadowCounterStructure = 0;
long g_tw2fShadowAnchors = 0;
long g_tw2fShadowAnchorsBeforeOriginBreak = 0;
long g_tw2fShadowNoAnchorWithin240 = 0;
long g_tw2fShadowOrderAttempts = 0;
long g_tw2fExecutionPass = 0;
long g_tw2fOrders = 0;
long g_tw2fDailyStopCount = 0;
long g_tw2fWeeklyStopCount = 0;
long g_tw2fHardStopCount = 0;
long g_tw2fTotalRiskRejectCount = 0;
long g_tw2fCurrencyRiskRejectCount = 0;

bool TW2FIncludesLegacy()
  {
   return InpBucketMode == BUCKET_LEGACY_ONLY ||
          InpBucketMode == BUCKET_LEGACY_AND_TRENDLINE_WAVE2_FAILURE;
  }

bool TW2FIncludesNewBucket()
  {
   return InpBucketMode == BUCKET_TRENDLINE_WAVE2_FAILURE_ONLY ||
          InpBucketMode == BUCKET_LEGACY_AND_TRENDLINE_WAVE2_FAILURE;
  }

bool TW2FDirectionEnabled(const int direction)
  {
   if(InpTW2FDirectionMode == TW2F_LONG_ONLY) return direction > 0;
   if(InpTW2FDirectionMode == TW2F_SHORT_ONLY) return direction < 0;
   return true;
  }

string TW2FStateName(const ENUM_TW2F_SETUP_STATE state)
  {
   if(state == TW2F_STATE_H4_IMPULSE_DETECTED) return "H4_IMPULSE_DETECTED";
   if(state == TW2F_STATE_H1_STRUCTURE_RECONSTRUCTED) return "H1_STRUCTURE_RECONSTRUCTED";
   if(state == TW2F_STATE_H1_TREND_MATURE) return "H1_TREND_MATURE";
   if(state == TW2F_STATE_H1_TRENDLINE_BROKEN) return "H1_TRENDLINE_BROKEN";
   if(state == TW2F_STATE_H1_REVERSAL_LEG) return "H1_REVERSAL_LEG";
   if(state == TW2F_STATE_M15_PULLBACK_ACTIVE) return "M15_PULLBACK_ACTIVE";
   if(state == TW2F_STATE_M15_CONTINUATION_FAILED) return "M15_CONTINUATION_FAILED";
   if(state == TW2F_STATE_M15_STRUCTURE_BROKEN) return "M15_STRUCTURE_BROKEN";
   if(state == TW2F_STATE_ENTRY_READY) return "ENTRY_READY";
   if(state == TW2F_STATE_POSITION_OPEN) return "POSITION_OPEN";
   if(state == TW2F_STATE_INVALIDATED) return "INVALIDATED";
   if(state == TW2F_STATE_EXPIRED) return "EXPIRED";
   return "IDLE";
  }

string TW2FStopModeName()
  {
   if(InpTW2FStopMode == TW2F_STOP_LATEST_M15_SWING_EXTREME) return "LATEST_M15_SWING_EXTREME";
   if(InpTW2FStopMode == TW2F_STOP_H1_WAVE2_EXTREME) return "H1_WAVE2_EXTREME";
   return "FULL_PATTERN_EXTREME";
  }

datetime TW2FBarCloseTime(const ENUM_TIMEFRAMES tf, const datetime openTime)
  {
   int seconds = PeriodSeconds(tf);
   return seconds > 0 ? openTime + seconds : openTime;
  }

int TW2FWeekKey(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   int daysFromMonday = (dt.day_of_week + 6) % 7;
   datetime monday = value - daysFromMonday * 86400 - dt.hour * 3600 - dt.min * 60 - dt.sec;
   return DateKey(monday);
  }

string TW2FGlobalKey(const string suffix)
  {
   return "TW2F." + IntegerToString((long)AccountInfoInteger(ACCOUNT_LOGIN)) + "." +
          IntegerToString(InpTW2FMagicNumber) + "." + suffix;
  }

void TW2FPersistRiskState()
  {
   GlobalVariableSet(TW2FGlobalKey("peak"), g_tw2fPeakEquity);
   GlobalVariableSet(TW2FGlobalKey("dayeq"), g_tw2fDayStartEquity);
   GlobalVariableSet(TW2FGlobalKey("weekeq"), g_tw2fWeekStartEquity);
   GlobalVariableSet(TW2FGlobalKey("daykey"), (double)g_tw2fDayKey);
   GlobalVariableSet(TW2FGlobalKey("weekkey"), (double)g_tw2fWeekKey);
   GlobalVariableSet(TW2FGlobalKey("dstop"), g_tw2fDailyStopped ? 1.0 : 0.0);
   GlobalVariableSet(TW2FGlobalKey("wstop"), g_tw2fWeeklyStopped ? 1.0 : 0.0);
   GlobalVariableSet(TW2FGlobalKey("hstop"), g_tw2fHardStopped ? 1.0 : 0.0);
  }

double TW2FGlobalOr(const string suffix, const double fallback)
  {
   string key = TW2FGlobalKey(suffix);
   return GlobalVariableCheck(key) ? GlobalVariableGet(key) : fallback;
  }

void TW2FAddRejection(const string reason)
  {
   string key = reason == "" ? "unknown" : reason;
   for(int i = 0; i < ArraySize(g_tw2fRejections); ++i)
     {
      if(g_tw2fRejections[i].reason == key)
        {
         ++g_tw2fRejections[i].count;
         return;
        }
     }
   int size = ArraySize(g_tw2fRejections);
   ArrayResize(g_tw2fRejections, size + 1);
   g_tw2fRejections[size].reason = key;
   g_tw2fRejections[size].count = 1;
  }

string TW2FLogFileName(const string suffix)
  {
   return InpTW2FLogFolder + "\\tw2f_" + InpRunId + "_" + suffix + ".csv";
  }

void TW2FEnsureLogFolder()
  {
   FolderCreate(InpTW2FLogFolder, InpUseCommonFiles ? FILE_COMMON : 0);
  }

int TW2FLogFlags()
  {
   int flags = FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_SHARE_WRITE;
   if(InpUseCommonFiles) flags |= FILE_COMMON;
   return flags;
  }

void TW2FResetSetup(TW2FSetup &state, const string symbol, const int direction)
  {
   ZeroMemory(state);
   state.symbol = symbol;
   state.direction = direction;
   state.state = TW2F_STATE_IDLE;
   state.previousState = TW2F_STATE_IDLE;
   state.stateReason = "initialized";
   state.m15StructureDirection = "none";
   state.m15PatternType = "NONE";
   state.rejectReason = "none";
   state.plannedRr = InpTakeProfitR;
  }

void TW2FWriteEvent(const TW2FSetup &state, const string eventName, const string rejectReason)
  {
   TW2FEnsureLogFolder();
   int handle = FileOpen(TW2FLogFileName("events"), TW2FLogFlags(), ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s FileOpen events failed err=%d", TW2F_STRATEGY_NAME, GetLastError());
      return;
     }
   bool header = FileSize(handle) == 0;
   FileSeek(handle, 0, SEEK_END);
   if(header)
      FileWriteString(handle,
         "timestamp,symbol,direction,setup_id,state_before,state_after,event,reject_reason,pivot_time,confirmation_time,"
         "h4_prior_trend_valid,h4_protected_swing,h4_impulse_window_bars,h4_pre_impulse_atr,h4_normalized_move,h4_impulse_percentile,h4_directional_efficiency,h4_close_location,h4_impulse_score,h4_structure_break,"
         "h1_lower_high_count,h1_lower_low_count,h1_trend_bars,h1_trend_distance_atr,h1_leg_distances_atr,h1_trendline_point1,h1_trendline_point2,h1_trendline_price,h1_trendline_slope,h1_trendline_touches,h1_break_distance_atr,h1_wave1_origin,h1_wave1_provisional_extreme,"
         "m15_structure_direction,m15_reference_extreme,m15_reference_pivot_time,m15_reference_confirmation_time,m15_protected_swing,m15_protected_pivot_time,m15_protected_confirmation_time,m15_post_anchor_extreme,m15_post_anchor_pivot_time,m15_post_anchor_confirmation_time,m15_pattern_type,m15_bottom_or_top_1,m15_bottom_or_top_2,m15_neckline,m15_pattern_height_atr,m15_break_extension_atr,"
         "signal_close_price,requested_entry_price,filled_entry_price,sl_before_adjustment,sl_after_adjustment,tp,stop_distance,lot,planned_risk_money,actual_initial_risk_money,planned_rr,gross_result_r,net_result_r,estimated_cost_r,"
         "spread,slippage,required_margin,projected_margin_level,total_open_risk_percent,currency_direction_risk_percent,daily_drawdown_percent,weekly_drawdown_percent,equity_drawdown_percent,"
         "exit_time,exit_price,result_money,mfe_r,mae_r,exit_reason\r\n");
   int digits = (int)SymbolInfoInteger(state.symbol, SYMBOL_DIGITS);
   string row = "";
   CsvAppend(row, TimeToString(state.stateChangedAt > 0 ? state.stateChangedAt : TimeCurrent(), TIME_DATE | TIME_SECONDS));
   CsvAppend(row, state.symbol);
   CsvAppend(row, DirectionText(state.direction));
   CsvAppend(row, state.setupId);
   CsvAppend(row, TW2FStateName(state.previousState));
   CsvAppend(row, TW2FStateName(state.state));
   CsvAppend(row, eventName);
   CsvAppend(row, rejectReason);
   CsvAppend(row, state.lastPivotTime > 0 ? TimeToString(state.lastPivotTime, TIME_DATE | TIME_MINUTES) : "");
   CsvAppend(row, state.lastConfirmationTime > 0 ? TimeToString(state.lastConfirmationTime, TIME_DATE | TIME_MINUTES) : "");
   CsvAppend(row, BoolText(state.h4PriorTrendValid));
   CsvAppend(row, DoubleToString(state.h4ProtectedSwing, digits));
   CsvAppend(row, IntegerToString(state.h4ImpulseWindowBars));
   CsvAppend(row, DoubleToString(state.h4PreImpulseAtr, digits));
   CsvAppend(row, DoubleToString(state.h4NormalizedMove, 4));
   CsvAppend(row, DoubleToString(state.h4ImpulsePercentile, 2));
   CsvAppend(row, DoubleToString(state.h4DirectionalEfficiency, 4));
   CsvAppend(row, DoubleToString(state.h4CloseLocation, 4));
   CsvAppend(row, DoubleToString(state.h4ImpulseScore, 4));
   CsvAppend(row, BoolText(state.h4StructureBreak));
   CsvAppend(row, IntegerToString(state.h1CounterHighCount));
   CsvAppend(row, IntegerToString(state.h1CounterLowCount));
   CsvAppend(row, IntegerToString(state.h1TrendBars));
   CsvAppend(row, DoubleToString(state.h1TrendDistanceAtr, 4));
   CsvAppend(row, state.h1LegDistancesAtr);
   CsvAppend(row, state.h1TrendlinePoint1Time > 0 ? TimeToString(state.h1TrendlinePoint1Time, TIME_DATE | TIME_MINUTES) + "@" + DoubleToString(state.h1TrendlinePoint1Price, digits) : "");
   CsvAppend(row, state.h1TrendlinePoint2Time > 0 ? TimeToString(state.h1TrendlinePoint2Time, TIME_DATE | TIME_MINUTES) + "@" + DoubleToString(state.h1TrendlinePoint2Price, digits) : "");
   CsvAppend(row, DoubleToString(state.h1TrendlinePrice, digits));
   CsvAppend(row, DoubleToString(state.h1TrendlineSlopePerSecond, 10));
   CsvAppend(row, IntegerToString(state.h1TrendlineTouches));
   CsvAppend(row, DoubleToString(state.h1BreakDistanceAtr, 4));
   CsvAppend(row, DoubleToString(state.h1Wave1Origin, digits));
   CsvAppend(row, DoubleToString(state.h1Wave1ProvisionalExtreme, digits));
   CsvAppend(row, state.m15StructureDirection);
   CsvAppend(row, DoubleToString(state.m15ReferenceExtreme, digits));
   CsvAppend(row, state.m15ReferencePivotTime > 0 ? TimeToString(state.m15ReferencePivotTime, TIME_DATE | TIME_MINUTES) : "");
   CsvAppend(row, state.m15ReferenceConfirmationTime > 0 ? TimeToString(state.m15ReferenceConfirmationTime, TIME_DATE | TIME_MINUTES) : "");
   CsvAppend(row, DoubleToString(state.m15ProtectedSwing, digits));
   CsvAppend(row, state.m15ProtectedPivotTime > 0 ? TimeToString(state.m15ProtectedPivotTime, TIME_DATE | TIME_MINUTES) : "");
   CsvAppend(row, state.m15ProtectedConfirmationTime > 0 ? TimeToString(state.m15ProtectedConfirmationTime, TIME_DATE | TIME_MINUTES) : "");
   CsvAppend(row, DoubleToString(state.m15PostAnchorExtreme, digits));
   CsvAppend(row, state.m15PostAnchorPivotTime > 0 ? TimeToString(state.m15PostAnchorPivotTime, TIME_DATE | TIME_MINUTES) : "");
   CsvAppend(row, state.m15PostAnchorConfirmationTime > 0 ? TimeToString(state.m15PostAnchorConfirmationTime, TIME_DATE | TIME_MINUTES) : "");
   CsvAppend(row, state.m15PatternType);
   CsvAppend(row, DoubleToString(state.m15Point1, digits));
   CsvAppend(row, DoubleToString(state.m15Point2, digits));
   CsvAppend(row, DoubleToString(state.m15PatternNeckline, digits));
   CsvAppend(row, DoubleToString(state.m15PatternHeightAtr, 4));
   CsvAppend(row, DoubleToString(state.m15BreakExtensionAtr, 4));
   CsvAppend(row, DoubleToString(state.signalClosePrice, digits));
   CsvAppend(row, DoubleToString(state.requestedEntryPrice, digits));
   CsvAppend(row, DoubleToString(state.filledEntryPrice, digits));
   CsvAppend(row, DoubleToString(state.slBeforeAdjustment, digits));
   CsvAppend(row, DoubleToString(state.slAfterAdjustment, digits));
   CsvAppend(row, DoubleToString(state.takeProfit, digits));
   CsvAppend(row, DoubleToString(state.stopDistance, digits));
   CsvAppend(row, DoubleToString(state.lot, 8));
   CsvAppend(row, DoubleToString(state.plannedRiskMoney, 2));
   CsvAppend(row, DoubleToString(state.actualInitialRiskMoney, 2));
   CsvAppend(row, DoubleToString(state.plannedRr, 4));
   CsvAppend(row, ""); CsvAppend(row, "");
   CsvAppend(row, DoubleToString(state.estimatedCostR, 4));
   CsvAppend(row, DoubleToString(state.spread, digits));
   CsvAppend(row, DoubleToString(state.slippage, digits));
   CsvAppend(row, DoubleToString(state.requiredMargin, 2));
   CsvAppend(row, DoubleToString(state.projectedMarginLevel, 2));
   CsvAppend(row, DoubleToString(state.totalOpenRiskPercent, 4));
   CsvAppend(row, DoubleToString(state.currencyDirectionRiskPercent, 4));
   CsvAppend(row, DoubleToString(state.dailyDrawdownPercent, 4));
   CsvAppend(row, DoubleToString(state.weeklyDrawdownPercent, 4));
   CsvAppend(row, DoubleToString(state.equityDrawdownPercent, 4));
   for(int i = 0; i < 6; ++i) CsvAppend(row, "");
   FileWriteString(handle, row + "\r\n");
   FileClose(handle);
  }

void TW2FWriteMilestone(TW2FSetup &state, const datetime at, const string eventName)
  {
   ENUM_TW2F_SETUP_STATE savedPrevious = state.previousState;
   datetime savedChangedAt = state.stateChangedAt;
   string savedReason = state.stateReason;
   state.previousState = state.state;
   state.stateChangedAt = at;
   state.stateReason = eventName;
   TW2FWriteEvent(state, eventName, "none");
   state.previousState = savedPrevious;
   state.stateChangedAt = savedChangedAt;
   state.stateReason = savedReason;
  }

void TW2FChangeState(TW2FSetup &state,
                     const ENUM_TW2F_SETUP_STATE nextState,
                     const datetime at,
                     const string reason)
  {
   if(state.state == nextState) return;
   state.previousState = state.state;
   state.state = nextState;
   state.stateChangedAt = at;
   state.stateReason = reason;
   TW2FWriteEvent(state, "state_transition", reason);
  }

bool TW2FIsTerminal(const TW2FSetup &state)
  {
   return state.state == TW2F_STATE_IDLE || state.state == TW2F_STATE_INVALIDATED ||
          state.state == TW2F_STATE_EXPIRED || state.state == TW2F_STATE_POSITION_OPEN;
  }

void TW2FReject(TW2FSetup &state, const string reason, const bool expireSetup = true)
  {
   state.rejectReason = reason;
   TW2FAddRejection(reason);
   if(expireSetup && state.state != TW2F_STATE_POSITION_OPEN)
      TW2FChangeState(state, TW2F_STATE_INVALIDATED, TimeCurrent(), reason);
   else
      TW2FWriteEvent(state, "rejected", reason);
  }

double TW2FSMA(const MqlRates &rates[], const int shift, const int period)
  {
   if(period <= 0 || shift < 0 || shift + period > ArraySize(rates)) return 0.0;
   double sum = 0.0;
   for(int i = shift; i < shift + period; ++i) sum += rates[i].close;
   return sum / period;
  }

void TW2FAppendSwing(TW2FSwing &swings[],
                     const TW2FSwing &candidate,
                     const MqlRates &rates[])
  {
   int size = ArraySize(swings);
   if(size == 0)
     {
      ArrayResize(swings, 1);
      swings[0] = candidate;
      return;
     }
   TW2FSwing last = swings[size - 1];
   if(last.kind == candidate.kind)
     {
      // OPERATIONAL_DEFINITION: same-kind duplicates are collapsed to the
      // more extreme member during deterministic closed-bar reconstruction.
      bool moreExtreme = candidate.kind > 0 ? candidate.price > last.price : candidate.price < last.price;
      if(moreExtreme) swings[size - 1] = candidate;
      return;
     }
   if(MathAbs(last.shift - candidate.shift) < InpMinBarsBetweenSwings) return;
   double candidateAtr = ATR(rates, candidate.shift, InpATRPeriod);
   if(candidateAtr <= 0.0 || MathAbs(candidate.price - last.price) < candidateAtr * InpMinimumSwingDistanceATR)
      return;
   ArrayResize(swings, size + 1);
   swings[size] = candidate;
  }

bool TW2FBuildSwings(const string symbol,
                     const ENUM_TIMEFRAMES tf,
                     MqlRates &rates[],
                     TW2FSwing &swings[])
  {
   int bars = MathMax(InpTW2FLookbackBars,
                      InpImpulseLookbackBars + InpMaximumImpulseWindowBars + InpMAPeriod + InpATRPeriod + 20);
   if(!CopyClosedRates(symbol, tf, bars, rates)) return false;
   ArrayResize(swings, 0);
   int oldest = ArraySize(rates) - MathMax(InpMAPeriod + 2, InpATRPeriod + 2);
   int active = 0;
   int candidateDirection = 0;
   int candidateCount = 0;
   int candidateFirstShift = -1;
   double activeHigh = 0.0, activeLow = 0.0;
   datetime activeHighTime = 0, activeLowTime = 0;
   int activeHighShift = -1, activeLowShift = -1;
   double pendingHigh = 0.0, pendingLow = 0.0;
   datetime pendingHighTime = 0, pendingLowTime = 0;
   int pendingHighShift = -1, pendingLowShift = -1;
   double snapshotHigh = 0.0, snapshotLow = 0.0;
   datetime snapshotHighTime = 0, snapshotLowTime = 0;
   int snapshotHighShift = -1, snapshotLowShift = -1;
   for(int shift = oldest; shift >= 0; --shift)
     {
      double ma1 = TW2FSMA(rates, shift, InpMAPeriod);
      double ma2 = TW2FSMA(rates, shift + 1, InpMAPeriod);
      double atr = ATR(rates, shift, InpATRPeriod);
      if(ma1 <= 0.0 || ma2 <= 0.0 || atr <= 0.0) continue;
      double slope = (ma1 - ma2) / atr;
      int sign = slope >= InpMinMASlopeATR ? 1 : (slope <= -InpMinMASlopeATR ? -1 : 0);
      if(active == 0)
        {
         if(sign == 0)
           {
            candidateDirection = 0; candidateCount = 0; candidateFirstShift = -1;
            continue;
           }
         if(sign != candidateDirection)
           {
            candidateDirection = sign; candidateCount = 1; candidateFirstShift = shift;
            pendingHigh = rates[shift].high; pendingLow = rates[shift].low;
            pendingHighTime = rates[shift].time; pendingLowTime = rates[shift].time;
            pendingHighShift = shift; pendingLowShift = shift;
           }
         else
           {
            ++candidateCount;
            if(rates[shift].high > pendingHigh) { pendingHigh = rates[shift].high; pendingHighTime = rates[shift].time; pendingHighShift = shift; }
            if(rates[shift].low < pendingLow) { pendingLow = rates[shift].low; pendingLowTime = rates[shift].time; pendingLowShift = shift; }
           }
         if(candidateCount >= InpMASlopeConfirmationBars)
           {
            active = candidateDirection;
            activeHigh = pendingHigh; activeLow = pendingLow;
            activeHighTime = pendingHighTime; activeLowTime = pendingLowTime;
            activeHighShift = pendingHighShift; activeLowShift = pendingLowShift;
            candidateDirection = 0; candidateCount = 0; candidateFirstShift = -1;
           }
         continue;
        }

      if(sign == -active)
        {
         if(candidateDirection != sign)
           {
            candidateDirection = sign; candidateCount = 1; candidateFirstShift = shift;
            pendingHigh = rates[shift].high; pendingLow = rates[shift].low;
            pendingHighTime = rates[shift].time; pendingLowTime = rates[shift].time;
            pendingHighShift = shift; pendingLowShift = shift;
            snapshotHigh = activeHigh; snapshotLow = activeLow;
            snapshotHighTime = activeHighTime; snapshotLowTime = activeLowTime;
            snapshotHighShift = activeHighShift; snapshotLowShift = activeLowShift;
           }
         else
           {
            ++candidateCount;
            if(rates[shift].high > pendingHigh) { pendingHigh = rates[shift].high; pendingHighTime = rates[shift].time; pendingHighShift = shift; }
            if(rates[shift].low < pendingLow) { pendingLow = rates[shift].low; pendingLowTime = rates[shift].time; pendingLowShift = shift; }
           }
         if(candidateCount >= InpMASlopeConfirmationBars)
           {
            TW2FSwing swing;
            swing.kind = active > 0 ? 1 : -1;
            swing.price = active > 0 ? snapshotHigh : snapshotLow;
            swing.pivotTime = active > 0 ? snapshotHighTime : snapshotLowTime;
            swing.shift = active > 0 ? snapshotHighShift : snapshotLowShift;
            swing.confirmationTime = TW2FBarCloseTime(tf, rates[shift].time);
            TW2FAppendSwing(swings, swing, rates);
            active = sign;
            activeHigh = pendingHigh; activeLow = pendingLow;
            activeHighTime = pendingHighTime; activeLowTime = pendingLowTime;
            activeHighShift = pendingHighShift; activeLowShift = pendingLowShift;
            candidateDirection = 0; candidateCount = 0; candidateFirstShift = -1;
           }
         continue;
        }

      if(candidateCount > 0)
        {
         if(pendingHigh > activeHigh) { activeHigh = pendingHigh; activeHighTime = pendingHighTime; activeHighShift = pendingHighShift; }
         if(pendingLow < activeLow) { activeLow = pendingLow; activeLowTime = pendingLowTime; activeLowShift = pendingLowShift; }
         candidateDirection = 0; candidateCount = 0; candidateFirstShift = -1;
        }
      if(rates[shift].high > activeHigh) { activeHigh = rates[shift].high; activeHighTime = rates[shift].time; activeHighShift = shift; }
      if(rates[shift].low < activeLow) { activeLow = rates[shift].low; activeLowTime = rates[shift].time; activeLowShift = shift; }
     }
   return ArraySize(swings) >= 4;
  }

double TW2FTrueRange(const MqlRates &rates[], const int shift)
  {
   if(shift < 0 || shift + 1 >= ArraySize(rates)) return 0.0;
   return MathMax(rates[shift].high - rates[shift].low,
                  MathMax(MathAbs(rates[shift].high - rates[shift + 1].close),
                          MathAbs(rates[shift].low - rates[shift + 1].close)));
  }

bool TW2FPriorAndProtected(const TW2FSwing &swings[],
                           const int entryDirection,
                           const datetime cutoff,
                           bool &priorValid,
                           TW2FSwing &protectedSwing)
  {
   TW2FSwing highs[]; TW2FSwing lows[];
   ArrayResize(highs, 0); ArrayResize(lows, 0);
   protectedSwing.kind = 0;
   TW2FSwing previousExtreme;
   previousExtreme.kind = 0;
   TW2FSwing betweenOpposite;
   betweenOpposite.kind = 0;
   for(int i = 0; i < ArraySize(swings); ++i)
     {
      if(swings[i].confirmationTime > cutoff || swings[i].pivotTime >= cutoff) continue;
      if(swings[i].kind > 0)
        {
         int n = ArraySize(highs); ArrayResize(highs, n + 1); highs[n] = swings[i];
        }
      else
        {
         int n = ArraySize(lows); ArrayResize(lows, n + 1); lows[n] = swings[i];
        }
     }
   priorValid = false;
   if(ArraySize(highs) >= 2 && ArraySize(lows) >= 2)
     {
      TW2FSwing h1 = highs[ArraySize(highs) - 2], h2 = highs[ArraySize(highs) - 1];
      TW2FSwing l1 = lows[ArraySize(lows) - 2], l2 = lows[ArraySize(lows) - 1];
      priorValid = entryDirection > 0 ? (h2.price > h1.price && l2.price > l1.price) :
                                       (h2.price < h1.price && l2.price < l1.price);
     }
   if(entryDirection > 0)
     {
      for(int i = 0; i < ArraySize(highs); ++i)
        {
         if(previousExtreme.kind > 0 && betweenOpposite.kind < 0 &&
            betweenOpposite.pivotTime > previousExtreme.pivotTime && highs[i].price > previousExtreme.price)
            protectedSwing = betweenOpposite;
         previousExtreme = highs[i];
         betweenOpposite.kind = 0;
         for(int j = 0; j < ArraySize(lows); ++j)
            if(lows[j].pivotTime > previousExtreme.pivotTime &&
               (i + 1 >= ArraySize(highs) || lows[j].pivotTime < highs[i + 1].pivotTime))
               betweenOpposite = lows[j];
        }
     }
   else
     {
      for(int i = 0; i < ArraySize(lows); ++i)
        {
         if(previousExtreme.kind < 0 && betweenOpposite.kind > 0 &&
            betweenOpposite.pivotTime > previousExtreme.pivotTime && lows[i].price < previousExtreme.price)
            protectedSwing = betweenOpposite;
         previousExtreme = lows[i];
         betweenOpposite.kind = 0;
         for(int j = 0; j < ArraySize(highs); ++j)
            if(highs[j].pivotTime > previousExtreme.pivotTime &&
               (i + 1 >= ArraySize(lows) || highs[j].pivotTime < lows[i + 1].pivotTime))
               betweenOpposite = highs[j];
        }
     }
   return protectedSwing.kind != 0;
  }

double TW2FImpulsePercentile(const MqlRates &rates[],
                             const int entryDirection,
                             const int window,
                             const double currentNormalized)
  {
   int valid = 0, below = 0;
   int maxEnd = MathMin(ArraySize(rates) - window - InpATRPeriod - 1,
                        window + InpImpulseLookbackBars - 1);
   for(int endShift = window; endShift <= maxEnd; ++endShift)
     {
      double preAtr = ATR(rates, endShift + window, InpATRPeriod);
      if(preAtr <= 0.0) continue;
      double move = entryDirection > 0 ? rates[endShift + window - 1].open - rates[endShift].close :
                                         rates[endShift].close - rates[endShift + window - 1].open;
      double normalized = move / preAtr;
      ++valid;
      if(normalized <= currentNormalized) ++below;
     }
   return valid > 0 ? 100.0 * below / valid : 0.0;
  }

bool TW2FDetectH4Impulse(const string symbol, const int entryDirection, TW2FSetup &detected)
  {
   MqlRates rates[]; TW2FSwing swings[];
   if(!TW2FBuildSwings(symbol, InpContextTF, rates, swings))
     {
      TW2FAddRejection("h4_data_or_swings_unavailable");
      return false;
     }
   bool found = false;
   double bestScore = -1.0;
   TW2FSetup best;
   TW2FResetSetup(best, symbol, entryDirection);
   int maxWindow = MathMin(InpMaximumImpulseWindowBars, 3);
   for(int window = 1; window <= maxWindow; ++window)
     {
      if(window + InpATRPeriod + 2 >= ArraySize(rates)) continue;
      datetime cutoff = rates[window - 1].time;
      bool priorValid = false;
      TW2FSwing protectedSwing;
      if(!TW2FPriorAndProtected(swings, entryDirection, cutoff, priorValid, protectedSwing)) continue;
      ++g_tw2fH4PriorTrendCandidates;
      if(InpRequirePriorH4Trend && !priorValid) continue;
      double preAtr = ATR(rates, window, InpATRPeriod);
      if(preAtr <= 0.0) continue;
      double move = entryDirection > 0 ? rates[window - 1].open - rates[0].close :
                                         rates[0].close - rates[window - 1].open;
      if(move <= 0.0) continue;
      double trSum = 0.0, high = rates[0].high, low = rates[0].low;
      for(int i = 0; i < window; ++i)
        {
         trSum += TW2FTrueRange(rates, i);
         high = MathMax(high, rates[i].high);
         low = MathMin(low, rates[i].low);
        }
      if(trSum <= 0.0 || high <= low) continue;
      double normalized = move / preAtr;
      double efficiency = MathAbs(move) / trSum;
      double closeLocation = (rates[0].close - low) / (high - low);
      double percentile = TW2FImpulsePercentile(rates, entryDirection, window, normalized);
      bool locationPass = entryDirection > 0 ? closeLocation <= InpImpulseCloseLocation :
                                               closeLocation >= 1.0 - InpImpulseCloseLocation;
      bool structureBreak = entryDirection > 0 ?
         rates[0].close < protectedSwing.price - preAtr * InpStructureBreakBufferATR :
         rates[0].close > protectedSwing.price + preAtr * InpStructureBreakBufferATR;
      if(normalized >= InpImpulseMinATR && percentile >= InpImpulsePercentile &&
         efficiency >= InpMinimumDirectionalEfficiency && locationPass)
         ++g_tw2fH4ImpulseCandidates;
      if(normalized < InpImpulseMinATR || percentile < InpImpulsePercentile ||
         efficiency < InpMinimumDirectionalEfficiency || !locationPass || !structureBreak)
         continue;
      double score = normalized * efficiency * percentile / 100.0;
      if(score <= bestScore) continue;
      bestScore = score;
      TW2FResetSetup(best, symbol, entryDirection);
      best.h4RecognizedAt = TW2FBarCloseTime(InpContextTF, rates[0].time);
      best.eligibleAfter = best.h4RecognizedAt;
      best.h4ImpulseStart = rates[window - 1].time;
      best.h4ImpulseEnd = best.h4RecognizedAt;
      best.h4ImpulseHigh = high;
      best.h4ImpulseLow = low;
      best.h4PriorTrendValid = priorValid;
      best.h4ProtectedSwing = protectedSwing.price;
      best.h4ProtectedPivotTime = protectedSwing.pivotTime;
      best.h4ProtectedConfirmationTime = protectedSwing.confirmationTime;
      best.h4ImpulseWindowBars = window;
      best.h4PreImpulseAtr = preAtr;
      best.h4NormalizedMove = normalized;
      best.h4ImpulsePercentile = percentile;
      best.h4DirectionalEfficiency = efficiency;
      best.h4CloseLocation = closeLocation;
      best.h4ImpulseScore = score;
      best.h4StructureBreak = true;
      best.lastPivotTime = protectedSwing.pivotTime;
      best.lastConfirmationTime = protectedSwing.confirmationTime;
      best.setupId = symbol + "|TW2F|" + DirectionText(entryDirection) + "|" + IntegerToString((long)best.h4RecognizedAt);
      found = true;
     }
   if(!found) return false;
   detected = best;
   return true;
  }

int TW2FFindRateShiftByTime(const MqlRates &rates[], const datetime time)
  {
   for(int i = 0; i < ArraySize(rates); ++i)
      if(rates[i].time <= time && time < TW2FBarCloseTime(InpSetupTF, rates[i].time)) return i;
   return -1;
  }

double TW2FTrendlinePrice(const datetime p1Time, const double p1Price,
                          const datetime p2Time, const double p2Price,
                          const datetime at)
  {
   long denominator = (long)p2Time - (long)p1Time;
   if(denominator == 0) return 0.0;
   double ratio = (double)((long)at - (long)p1Time) / (double)denominator;
   return p1Price + (p2Price - p1Price) * ratio;
  }

bool TW2FFindH1Maturity(TW2FSetup &state,
                        const MqlRates &rates[],
                        const TW2FSwing &swings[],
                        const datetime maxSignalTime)
  {
   int startIndex = -1;
   for(int i = 0; i < ArraySize(swings); ++i)
     {
      if(swings[i].confirmationTime > maxSignalTime) continue;
      if(swings[i].kind == (state.direction > 0 ? 1 : -1) && swings[i].pivotTime <= state.h4ImpulseStart)
         startIndex = i;
     }
   if(startIndex < 0) return false;
   TW2FSwing start = swings[startIndex];
   int rateShift = TW2FFindRateShiftByTime(rates, start.pivotTime);
   double startAtr = rateShift >= 0 ? ATR(rates, rateShift, InpATRPeriod) : 0.0;
   if(startAtr <= 0.0) return false;
   int highCount = 0, lowCount = 0;
   bool haveHigh = false, haveLow = false;
   double previousHigh = 0.0, previousLow = 0.0;
   double furthest = start.price;
   string legs = "";
   datetime matureAt = 0;
   int matureBars = 0;
   double matureDistance = 0.0;
   for(int i = startIndex; i < ArraySize(swings); ++i)
     {
      if(swings[i].confirmationTime > maxSignalTime) break;
      if(swings[i].kind > 0)
        {
         if(haveHigh)
           {
            bool counter = state.direction > 0 ? swings[i].price < previousHigh : swings[i].price > previousHigh;
            if(counter) ++highCount;
           }
         previousHigh = swings[i].price; haveHigh = true;
        }
      else
        {
         if(haveLow)
           {
            bool counter = state.direction > 0 ? swings[i].price < previousLow : swings[i].price > previousLow;
            if(counter) ++lowCount;
           }
         previousLow = swings[i].price; haveLow = true;
        }
      if(state.direction > 0) furthest = MathMin(furthest, swings[i].price);
      else furthest = MathMax(furthest, swings[i].price);
      double distanceAtr = MathAbs(furthest - start.price) / startAtr;
      int bars = BarsBetween(state.symbol, InpSetupTF, start.pivotTime, swings[i].confirmationTime);
      if(i > startIndex)
        {
         if(legs != "") legs += ";";
         legs += DoubleToString(MathAbs(swings[i].price - swings[i - 1].price) / startAtr, 3);
        }
      if(matureAt == 0 && highCount >= InpH1RequiredLowerHighs && lowCount >= InpH1RequiredLowerLows &&
         (distanceAtr >= InpH1MinimumTrendATR || bars >= InpH1MinimumTrendBars))
        {
         matureAt = swings[i].confirmationTime;
         matureBars = bars;
         matureDistance = distanceAtr;
        }
     }
   state.h1SequenceStartTime = start.pivotTime;
   state.h1SequenceStartPrice = start.price;
   state.h1SequenceStartAtr = startAtr;
   state.h1CounterHighCount = highCount;
   state.h1CounterLowCount = lowCount;
   state.h1TrendBars = matureAt > 0 ? matureBars : BarsBetween(state.symbol, InpSetupTF, start.pivotTime, maxSignalTime);
   state.h1TrendDistanceAtr = matureAt > 0 ? matureDistance : MathAbs(furthest - start.price) / startAtr;
   state.h1LegDistancesAtr = legs;
   if(matureAt <= 0) return false;
   state.h1MatureTime = matureAt;
   return true;
  }

bool TW2FFindH1TrendlineBreak(TW2FSetup &state,
                              const MqlRates &rates[],
                              const TW2FSwing &swings[],
                              const datetime maxSignalTime)
  {
   int oldest = ArraySize(rates) - InpATRPeriod - 2;
   for(int shift = oldest; shift >= 0; --shift)
     {
      datetime signalTime = TW2FBarCloseTime(InpSetupTF, rates[shift].time);
      if(signalTime <= state.h1MatureTime || signalTime > maxSignalTime || shift + 1 >= ArraySize(rates)) continue;
      TW2FSwing older, recent;
      older.kind = 0; recent.kind = 0;
      for(int i = 0; i < ArraySize(swings); ++i)
        {
         if(swings[i].confirmationTime > signalTime || swings[i].pivotTime < state.h1SequenceStartTime) continue;
         if(swings[i].kind != (state.direction > 0 ? 1 : -1)) continue;
         older = recent;
         recent = swings[i];
        }
      if(older.kind == 0 || recent.kind == 0 || recent.pivotTime <= older.pivotTime) continue;
      int pointBars = BarsBetween(state.symbol, InpSetupTF, older.pivotTime, recent.pivotTime);
      double atr = ATR(rates, shift, InpATRPeriod);
      if(pointBars < InpTrendlineMinBars || atr <= 0.0) continue;
      bool heightPass = state.direction > 0 ? older.price - recent.price >= atr * InpTrendlineMinHeightATR :
                                             recent.price - older.price >= atr * InpTrendlineMinHeightATR;
      if(!heightPass) continue;
      double lineCurrent = TW2FTrendlinePrice(older.pivotTime, older.price, recent.pivotTime, recent.price, rates[shift].time);
      double linePrevious = TW2FTrendlinePrice(older.pivotTime, older.price, recent.pivotTime, recent.price, rates[shift + 1].time);
      if(lineCurrent <= 0.0 || linePrevious <= 0.0) continue;
      bool crossed = state.direction > 0 ?
         rates[shift + 1].close <= linePrevious && rates[shift].close > lineCurrent + atr * InpTrendlineBreakBufferATR :
         rates[shift + 1].close >= linePrevious && rates[shift].close < lineCurrent - atr * InpTrendlineBreakBufferATR;
      if(!crossed) continue;
      TW2FSwing origin;
      origin.kind = 0;
      for(int i = 0; i < ArraySize(swings); ++i)
        {
         if(swings[i].confirmationTime <= signalTime && swings[i].pivotTime <= rates[shift].time &&
            swings[i].kind == (state.direction > 0 ? -1 : 1)) origin = swings[i];
        }
      if(origin.kind == 0) continue;
      state.h1TrendlinePoint1Time = older.pivotTime;
      state.h1TrendlinePoint2Time = recent.pivotTime;
      state.h1TrendlinePoint1Price = older.price;
      state.h1TrendlinePoint2Price = recent.price;
      state.h1TrendlinePrice = lineCurrent;
      state.h1TrendlineSlopePerSecond = (recent.price - older.price) /
                                        (double)((long)recent.pivotTime - (long)older.pivotTime);
      state.h1TrendlineTouches = 2;
      state.h1BreakDistanceAtr = MathAbs(rates[shift].close - lineCurrent) / atr;
      state.h1BreakTime = signalTime;
      state.h1Wave1Origin = origin.price;
      state.h1Wave1OriginPivotTime = origin.pivotTime;
      state.h1Wave1OriginConfirmationTime = origin.confirmationTime;
      state.lastPivotTime = origin.pivotTime;
      state.lastConfirmationTime = origin.confirmationTime;
      return true;
     }
   return false;
  }

void TW2FEvaluateH1(TW2FSetup &state, const datetime maxSignalTime, const bool reconstruction)
  {
   if(state.state < TW2F_STATE_H4_IMPULSE_DETECTED || TW2FIsTerminal(state)) return;
   MqlRates rates[]; TW2FSwing swings[];
   if(!TW2FBuildSwings(state.symbol, InpSetupTF, rates, swings))
     {
      TW2FReject(state, "h1_data_or_swings_unavailable", false);
      return;
     }
   double atr = ATR(rates, 0, InpATRPeriod);
   if(atr <= 0.0) { TW2FReject(state, "h1_atr_unavailable", false); return; }
   if(state.h1Wave1Origin > 0.0)
     {
      bool invalid = state.direction > 0 ? rates[0].close < state.h1Wave1Origin - atr * InpWaveInvalidationBufferATR :
                                           rates[0].close > state.h1Wave1Origin + atr * InpWaveInvalidationBufferATR;
      if(invalid) { TW2FReject(state, "h1_wave1_origin_broken"); return; }
     }
   if(state.state == TW2F_STATE_H4_IMPULSE_DETECTED)
      TW2FChangeState(state, TW2F_STATE_H1_STRUCTURE_RECONSTRUCTED, maxSignalTime,
                      reconstruction ? "closed_bar_reconstruction" : "h1_refresh");
   if(state.state <= TW2F_STATE_H1_STRUCTURE_RECONSTRUCTED && TW2FFindH1Maturity(state, rates, swings, maxSignalTime))
     {
      ++g_tw2fH1Mature;
      TW2FChangeState(state, TW2F_STATE_H1_TREND_MATURE, state.h1MatureTime,
                      state.direction > 0 ? "H1_BEARISH_SWING_SEQUENCE_MATURE" : "H1_BULLISH_SWING_SEQUENCE_MATURE");
     }
   if(state.state == TW2F_STATE_H1_TREND_MATURE && TW2FFindH1TrendlineBreak(state, rates, swings, maxSignalTime))
     {
      ++g_tw2fH1TrendlineBreaks;
      TW2FChangeState(state, TW2F_STATE_H1_TRENDLINE_BROKEN, state.h1BreakTime, "h1_trendline_closed_bar_break");
      TW2FChangeState(state, TW2F_STATE_H1_REVERSAL_LEG, state.h1BreakTime, "wave1_origin_frozen");
     }
   if(state.h1BreakTime > 0)
     {
      int bars = BarsBetween(state.symbol, InpSetupTF, state.h1BreakTime, maxSignalTime);
      if(bars > InpH1SetupExpiryBars)
        {
         TW2FStartExpiryShadow(state, maxSignalTime);
         TW2FChangeState(state, TW2F_STATE_EXPIRED, maxSignalTime, "h1_setup_expiry");
        }
     }
  }

double TW2FExtremeBetween(const MqlRates &rates[], const datetime from, const datetime to, const bool high)
  {
   double value = high ? -1.0e100 : 1.0e100;
   for(int i = 0; i < ArraySize(rates); ++i)
     {
      datetime closeTime = TW2FBarCloseTime(InpEntryTF, rates[i].time);
      if(closeTime < from || closeTime > to) continue;
      value = high ? MathMax(value, rates[i].high) : MathMin(value, rates[i].low);
     }
   if(high && value < -1.0e90) return 0.0;
   if(!high && value > 1.0e90) return 0.0;
   return value;
  }

bool TW2FLastTwoKind(const TW2FSwing &swings[], const int kind, const datetime from,
                     const datetime knownAt, TW2FSwing &older, TW2FSwing &recent, TW2FSwing &third)
  {
   older.kind = 0; recent.kind = 0; third.kind = 0;
   TW2FSwing list[]; ArrayResize(list, 0);
   for(int i = 0; i < ArraySize(swings); ++i)
     {
      if(swings[i].kind != kind || swings[i].pivotTime < from || swings[i].confirmationTime > knownAt) continue;
      int n = ArraySize(list); ArrayResize(list, n + 1); list[n] = swings[i];
     }
   int n = ArraySize(list);
   if(n < 2) return false;
   recent = list[n - 1]; older = list[n - 2];
   if(n >= 3) third = list[n - 3];
   return true;
  }

bool TW2FFindM15Protected(const TW2FSwing &swings[], const TW2FSetup &state,
                          const datetime knownAt, TW2FSwing &protectedSwing)
  {
   protectedSwing.kind = 0;
   int continuationKind = state.direction > 0 ? -1 : 1;
   TW2FSwing previousContinuation; previousContinuation.kind = 0;
   for(int i = 0; i < ArraySize(swings); ++i)
     {
      if(swings[i].confirmationTime > knownAt || swings[i].pivotTime < state.h1BreakTime ||
         swings[i].kind != continuationKind) continue;
      if(previousContinuation.kind != 0)
        {
         bool extended = state.direction > 0 ? swings[i].price < previousContinuation.price :
                                               swings[i].price > previousContinuation.price;
         if(extended)
           {
            for(int j = 0; j < ArraySize(swings); ++j)
              {
               if(swings[j].kind == -continuationKind &&
                  swings[j].pivotTime > previousContinuation.pivotTime &&
                  swings[j].pivotTime < swings[i].pivotTime &&
                  swings[j].confirmationTime <= knownAt)
                  protectedSwing = swings[j];
              }
           }
        }
      previousContinuation = swings[i];
     }
   return protectedSwing.kind != 0;
  }

string TW2FClassifyPattern(const TW2FSetup &state,
                           const TW2FSwing &older,
                           const TW2FSwing &recent,
                           const TW2FSwing &third,
                           const double atr,
                           const double spread,
                           const double latestClose)
  {
   double tolerance = MathMax(atr * InpEqualBottomToleranceATR, spread * 2.0);
   if(third.kind != 0)
     {
      double maximum = MathMax(third.price, MathMax(older.price, recent.price));
      double minimum = MathMin(third.price, MathMin(older.price, recent.price));
      if(maximum - minimum <= tolerance) return state.direction > 0 ? "TRIPLE_BOTTOM" : "TRIPLE_TOP";
     }
   double directionalDifference = state.direction > 0 ? recent.price - older.price : older.price - recent.price;
   if(MathAbs(directionalDifference) <= tolerance)
      return state.direction > 0 ? "EQUAL_DOUBLE_BOTTOM" : "EQUAL_DOUBLE_TOP";
   if(directionalDifference > atr * InpEqualBottomToleranceATR &&
      directionalDifference <= atr * InpHigherLowMaxATR)
      return state.direction > 0 ? "HIGHER_LOW" : "LOWER_HIGH";
   bool falseBreakDepth = directionalDifference < -atr * InpEqualBottomToleranceATR &&
                          directionalDifference >= -atr * InpFalseBreakMaxATR;
   bool recovered = state.direction > 0 ? latestClose > older.price : latestClose < older.price;
   if(falseBreakDepth && recovered) return "FALSE_BREAK_RECOVERY";
   return "NONE";
  }

bool TW2FApplyContinuationFailure(TW2FSetup &state,
                                  const string pattern,
                                  const datetime signalTime,
                                  const bool recordRuntimeEvidence)
  {
   bool recognized = pattern == "EQUAL_DOUBLE_BOTTOM" || pattern == "EQUAL_DOUBLE_TOP" ||
                     pattern == "HIGHER_LOW" || pattern == "LOWER_HIGH" ||
                     pattern == "FALSE_BREAK_RECOVERY" ||
                     pattern == "TRIPLE_BOTTOM" || pattern == "TRIPLE_TOP";
   if(state.state != TW2F_STATE_M15_PULLBACK_ACTIVE || !recognized) return false;
   if(recordRuntimeEvidence)
     {
      if(pattern == "EQUAL_DOUBLE_BOTTOM" || pattern == "EQUAL_DOUBLE_TOP") ++g_tw2fEqualExtreme;
      else if(pattern == "HIGHER_LOW" || pattern == "LOWER_HIGH") ++g_tw2fHigherLowOrLowerHigh;
      else if(pattern == "FALSE_BREAK_RECOVERY") ++g_tw2fFalseBreakRecovery;
      else ++g_tw2fTripleExtreme;
      ++g_tw2fContinuationFailure;
      ++g_tw2fM15Failures;
      TW2FChangeState(state, TW2F_STATE_M15_CONTINUATION_FAILED, signalTime, pattern);
     }
   else
     {
      state.previousState = state.state;
      state.state = TW2F_STATE_M15_CONTINUATION_FAILED;
      state.stateChangedAt = signalTime;
      state.stateReason = pattern;
     }
   return true;
  }

double TW2FPatternNeckline(const MqlRates &rates[], const TW2FSetup &state,
                           const datetime from, const datetime to)
  {
   double value = state.direction > 0 ? -1.0e100 : 1.0e100;
   for(int i = 0; i < ArraySize(rates); ++i)
     {
      if(rates[i].time <= from || rates[i].time >= to) continue;
      value = state.direction > 0 ? MathMax(value, rates[i].high) : MathMin(value, rates[i].low);
     }
   if(state.direction > 0 && value < -1.0e90) return 0.0;
   if(state.direction < 0 && value > 1.0e90) return 0.0;
   return value;
  }

bool TW2FAssertPatternClass(const int direction,
                            const double referencePrice,
                            const double newPrice,
                            const double latestClose,
                            const string expected)
  {
   TW2FSetup testState;
   TW2FSwing referenceSwing, newSwing, noThird;
   ZeroMemory(testState);
   ZeroMemory(referenceSwing);
   ZeroMemory(newSwing);
   ZeroMemory(noThird);
   testState.direction = direction;
   testState.state = TW2F_STATE_M15_PULLBACK_ACTIVE;
   referenceSwing.kind = direction > 0 ? -1 : 1;
   referenceSwing.price = referencePrice;
   newSwing.kind = referenceSwing.kind;
   newSwing.price = newPrice;
   string actual = TW2FClassifyPattern(testState, referenceSwing, newSwing, noThird,
                                       1.0, 0.01, latestClose);
   bool transitioned = TW2FApplyContinuationFailure(testState, actual, 1, false);
   if(actual == expected && transitioned &&
      testState.state == TW2F_STATE_M15_CONTINUATION_FAILED)
     {
      ++g_tw2fPatternReachabilityTestsPassed;
      return true;
     }
   ++g_tw2fPatternReachabilityTestsFailed;
   PrintFormat("%s M15 pattern reachability failed direction=%s expected=%s actual=%s transitioned=%s state=%s",
               TW2F_STRATEGY_NAME, DirectionText(direction), expected, actual,
               BoolText(transitioned), TW2FStateName(testState.state));
   return false;
  }

bool TW2FRunM15PatternReachabilityTests()
  {
   bool pass = true;
   pass = TW2FAssertPatternClass(1, 100.0, 100.05, 100.10, "EQUAL_DOUBLE_BOTTOM") && pass;
   pass = TW2FAssertPatternClass(1, 100.0, 100.30, 100.40, "HIGHER_LOW") && pass;
   pass = TW2FAssertPatternClass(1, 100.0,  99.70, 100.10, "FALSE_BREAK_RECOVERY") && pass;
   pass = TW2FAssertPatternClass(-1, 100.0, 99.95,  99.90, "EQUAL_DOUBLE_TOP") && pass;
   pass = TW2FAssertPatternClass(-1, 100.0, 99.70,  99.60, "LOWER_HIGH") && pass;
   pass = TW2FAssertPatternClass(-1, 100.0, 100.30, 99.90, "FALSE_BREAK_RECOVERY") && pass;
   PrintFormat("%s M15 pattern reachability tests passed=%d failed=%d",
               TW2F_STRATEGY_NAME, g_tw2fPatternReachabilityTestsPassed,
               g_tw2fPatternReachabilityTestsFailed);
   return pass;
  }

bool TW2FFindProtectedBetween(const TW2FSwing &swings[],
                              const TW2FSetup &state,
                              const datetime olderPivotTime,
                              const datetime newerPivotTime,
                              const datetime knownAt,
                              TW2FSwing &protectedSwing)
  {
   ZeroMemory(protectedSwing);
   int protectedKind = state.direction > 0 ? 1 : -1;
   for(int i = 0; i < ArraySize(swings); ++i)
     {
      if(swings[i].kind != protectedKind ||
         swings[i].pivotTime <= olderPivotTime || swings[i].pivotTime >= newerPivotTime ||
         swings[i].confirmationTime > knownAt)
         continue;
      protectedSwing = swings[i];
     }
   return protectedSwing.kind != 0;
  }

bool TW2FFindLatestSameKindAfter(const TW2FSwing &swings[],
                                 const TW2FSetup &state,
                                 const datetime afterPivotTime,
                                 const datetime afterConfirmationTime,
                                 const datetime knownAt,
                                 TW2FSwing &latest)
  {
   ZeroMemory(latest);
   int kind = state.direction > 0 ? -1 : 1;
   for(int i = 0; i < ArraySize(swings); ++i)
     {
      if(swings[i].kind != kind || swings[i].pivotTime <= afterPivotTime ||
         swings[i].confirmationTime <= afterConfirmationTime || swings[i].confirmationTime > knownAt)
         continue;
      latest = swings[i];
     }
   return latest.kind != 0;
  }

bool TW2FM15CounterStructure(const TW2FSetup &state,
                             const TW2FSwing &swings[],
                             const datetime knownAt,
                             TW2FSwing &highOld,
                             TW2FSwing &highNew,
                             TW2FSwing &lowOld,
                             TW2FSwing &lowNew)
  {
   TW2FSwing highThird, lowThird;
   bool haveHighs = TW2FLastTwoKind(swings, 1, state.h1BreakTime, knownAt,
                                    highOld, highNew, highThird);
   bool haveLows = TW2FLastTwoKind(swings, -1, state.h1BreakTime, knownAt,
                                   lowOld, lowNew, lowThird);
   return haveHighs && haveLows &&
      (state.direction > 0 ? highNew.price < highOld.price && lowNew.price < lowOld.price :
                             highNew.price > highOld.price && lowNew.price > lowOld.price);
  }

void TW2FWriteExpiryShadow(const TW2FExpiryShadow &shadow)
  {
   TW2FEnsureLogFolder();
   int handle = FileOpen(TW2FLogFileName("expiry_shadow"), TW2FLogFlags(), ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s FileOpen expiry shadow failed err=%d", TW2F_STRATEGY_NAME, GetLastError());
      return;
     }
   bool header = FileSize(handle) == 0;
   FileSeek(handle, 0, SEEK_END);
   if(header)
      FileWriteString(handle,
         "expiry_time,symbol,direction,setup_id,h1_break_time,h1_wave1_origin,expiry_m15_high_count,expiry_m15_low_count,"
         "first_counter_structure_time,counter_h1_bars_from_break,counter_h1_bars_after_expiry,shadow_anchor_time,anchor_h1_bars_from_break,anchor_h1_bars_after_expiry,"
         "h1_wave1_origin_break_time,shadow_anchor_before_origin_break,no_anchor_within_240_h1_bars,observed_h1_bars_after_expiry,max_shadow_h1_bars,status,shadow_order_attempts\r\n");
   int digits = (int)SymbolInfoInteger(shadow.symbol, SYMBOL_DIGITS);
   string row = "";
   CsvAppend(row, TimeToString(shadow.expiryTime, TIME_DATE | TIME_SECONDS));
   CsvAppend(row, shadow.symbol);
   CsvAppend(row, DirectionText(shadow.direction));
   CsvAppend(row, shadow.setupId);
   CsvAppend(row, TimeToString(shadow.h1BreakTime, TIME_DATE | TIME_SECONDS));
   CsvAppend(row, DoubleToString(shadow.h1Wave1Origin, digits));
   CsvAppend(row, IntegerToString(shadow.expiryM15HighCount));
   CsvAppend(row, IntegerToString(shadow.expiryM15LowCount));
   CsvAppend(row, shadow.firstCounterStructureTime > 0 ? TimeToString(shadow.firstCounterStructureTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(row, shadow.firstCounterStructureTime > 0 ? IntegerToString(shadow.counterH1BarsFromBreak) : "");
   CsvAppend(row, shadow.firstCounterStructureTime > 0 ? IntegerToString(shadow.counterH1BarsAfterExpiry) : "");
   CsvAppend(row, shadow.shadowAnchorTime > 0 ? TimeToString(shadow.shadowAnchorTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(row, shadow.shadowAnchorTime > 0 ? IntegerToString(shadow.anchorH1BarsFromBreak) : "");
   CsvAppend(row, shadow.shadowAnchorTime > 0 ? IntegerToString(shadow.anchorH1BarsAfterExpiry) : "");
   CsvAppend(row, shadow.h1Wave1OriginBreakTime > 0 ? TimeToString(shadow.h1Wave1OriginBreakTime, TIME_DATE | TIME_SECONDS) : "");
   CsvAppend(row, shadow.shadowAnchorTime > 0 ? BoolText(shadow.anchorBeforeOriginBreak) : "");
   CsvAppend(row, BoolText(shadow.noAnchorWithin240));
   CsvAppend(row, IntegerToString(shadow.observedH1BarsAfterExpiry));
   CsvAppend(row, IntegerToString(TW2F_SHADOW_MAX_H1_BARS));
   CsvAppend(row, shadow.status);
   CsvAppend(row, IntegerToString((int)g_tw2fShadowOrderAttempts));
   FileWriteString(handle, row + "\r\n");
   FileClose(handle);
  }

void TW2FFinalizeExpiryShadow(const int index, const int observedBars, const string status)
  {
   if(index < 0 || index >= ArraySize(g_tw2fExpiryShadows) || g_tw2fExpiryShadows[index].written) return;
   g_tw2fExpiryShadows[index].active = false;
   g_tw2fExpiryShadows[index].written = true;
   g_tw2fExpiryShadows[index].observedH1BarsAfterExpiry = observedBars;
   g_tw2fExpiryShadows[index].status = status;
   TW2FWriteExpiryShadow(g_tw2fExpiryShadows[index]);
  }

void TW2FStartExpiryShadow(const TW2FSetup &state, const datetime expiryTime)
  {
   if(state.h1BreakTime <= 0 || state.h1Wave1Origin <= 0.0) return;
   for(int i = 0; i < ArraySize(g_tw2fExpiryShadows); ++i)
      if(g_tw2fExpiryShadows[i].setupId == state.setupId) return;
   TW2FExpiryShadow shadow;
   ZeroMemory(shadow);
   shadow.active = true;
   shadow.symbol = state.symbol;
   shadow.direction = state.direction;
   shadow.setupId = state.setupId;
   shadow.h1BreakTime = state.h1BreakTime;
   shadow.h1Wave1Origin = state.h1Wave1Origin;
   shadow.expiryTime = expiryTime;
   shadow.status = "observing";
   MqlRates rates[];
   TW2FSwing swings[];
   if(TW2FBuildSwings(state.symbol, InpEntryTF, rates, swings))
     {
      for(int i = 0; i < ArraySize(swings); ++i)
        {
         if(swings[i].pivotTime < state.h1BreakTime || swings[i].confirmationTime > expiryTime) continue;
         if(swings[i].kind > 0) ++shadow.expiryM15HighCount;
         if(swings[i].kind < 0) ++shadow.expiryM15LowCount;
        }
     }
   int size = ArraySize(g_tw2fExpiryShadows);
   ArrayResize(g_tw2fExpiryShadows, size + 1);
   g_tw2fExpiryShadows[size] = shadow;
   ++g_tw2fShadowStarted;
  }

void TW2FUpdateExpiryShadowsH1(const string symbol, const datetime signalTime)
  {
   MqlRates rates[];
   if(!CopyClosedRates(symbol, InpSetupTF, InpATRPeriod + 2, rates)) return;
   double atr = ATR(rates, 0, InpATRPeriod);
   if(atr <= 0.0) return;
   for(int i = 0; i < ArraySize(g_tw2fExpiryShadows); ++i)
     {
      if(!g_tw2fExpiryShadows[i].active || g_tw2fExpiryShadows[i].symbol != symbol ||
         signalTime <= g_tw2fExpiryShadows[i].expiryTime ||
         g_tw2fExpiryShadows[i].h1Wave1OriginBreakTime > 0) continue;
      bool broken = g_tw2fExpiryShadows[i].direction > 0 ?
         rates[0].close < g_tw2fExpiryShadows[i].h1Wave1Origin - atr * InpWaveInvalidationBufferATR :
         rates[0].close > g_tw2fExpiryShadows[i].h1Wave1Origin + atr * InpWaveInvalidationBufferATR;
      if(!broken) continue;
      g_tw2fExpiryShadows[i].h1Wave1OriginBreakTime = signalTime;
      if(g_tw2fExpiryShadows[i].shadowAnchorTime > 0)
        {
         g_tw2fExpiryShadows[i].anchorBeforeOriginBreak =
            g_tw2fExpiryShadows[i].shadowAnchorTime < signalTime;
         if(g_tw2fExpiryShadows[i].anchorBeforeOriginBreak)
            ++g_tw2fShadowAnchorsBeforeOriginBreak;
         int observed = BarsBetween(symbol, InpSetupTF, g_tw2fExpiryShadows[i].expiryTime, signalTime);
         TW2FFinalizeExpiryShadow(i, observed,
            g_tw2fExpiryShadows[i].anchorBeforeOriginBreak ? "anchor_before_origin_break" : "anchor_not_before_origin_break");
        }
     }
  }

void TW2FUpdateExpiryShadowsM15(const string symbol)
  {
   MqlRates rates[];
   TW2FSwing swings[];
   if(!TW2FBuildSwings(symbol, InpEntryTF, rates, swings)) return;
   datetime signalTime = TW2FBarCloseTime(InpEntryTF, rates[0].time);
   for(int i = 0; i < ArraySize(g_tw2fExpiryShadows); ++i)
     {
      if(!g_tw2fExpiryShadows[i].active || g_tw2fExpiryShadows[i].symbol != symbol ||
         signalTime <= g_tw2fExpiryShadows[i].expiryTime) continue;
      int afterExpiry = BarsBetween(symbol, InpSetupTF, g_tw2fExpiryShadows[i].expiryTime, signalTime);
      if(afterExpiry > TW2F_SHADOW_MAX_H1_BARS)
        {
         bool noAnchor = g_tw2fExpiryShadows[i].shadowAnchorTime == 0;
         g_tw2fExpiryShadows[i].noAnchorWithin240 = noAnchor;
         if(noAnchor) ++g_tw2fShadowNoAnchorWithin240;
         else if(g_tw2fExpiryShadows[i].h1Wave1OriginBreakTime == 0)
           {
            g_tw2fExpiryShadows[i].anchorBeforeOriginBreak = true;
            ++g_tw2fShadowAnchorsBeforeOriginBreak;
           }
         TW2FFinalizeExpiryShadow(i, TW2F_SHADOW_MAX_H1_BARS,
            noAnchor ? "no_anchor_within_240_h1_bars" :
            (g_tw2fExpiryShadows[i].anchorBeforeOriginBreak ? "anchor_before_origin_break" : "anchor_not_before_origin_break"));
         continue;
        }

      TW2FSetup probe;
      ZeroMemory(probe);
      probe.symbol = symbol;
      probe.direction = g_tw2fExpiryShadows[i].direction;
      probe.h1BreakTime = g_tw2fExpiryShadows[i].h1BreakTime;
      TW2FSwing highOld, highNew, lowOld, lowNew;
      bool counter = TW2FM15CounterStructure(probe, swings, signalTime,
                                             highOld, highNew, lowOld, lowNew);
      if(counter && g_tw2fExpiryShadows[i].firstCounterStructureTime == 0)
        {
         g_tw2fExpiryShadows[i].firstCounterStructureTime = signalTime;
         g_tw2fExpiryShadows[i].counterH1BarsFromBreak =
            BarsBetween(symbol, InpSetupTF, g_tw2fExpiryShadows[i].h1BreakTime, signalTime);
         g_tw2fExpiryShadows[i].counterH1BarsAfterExpiry = afterExpiry;
         ++g_tw2fShadowCounterStructure;
        }
      if(counter && g_tw2fExpiryShadows[i].shadowAnchorTime == 0)
        {
         TW2FSwing priorReference = probe.direction > 0 ? lowOld : highOld;
         TW2FSwing reference = probe.direction > 0 ? lowNew : highNew;
         TW2FSwing protectedSwing;
         if(TW2FFindProtectedBetween(swings, probe, priorReference.pivotTime,
                                    reference.pivotTime, signalTime, protectedSwing))
           {
            g_tw2fExpiryShadows[i].shadowAnchorTime = signalTime;
            g_tw2fExpiryShadows[i].anchorH1BarsFromBreak =
               BarsBetween(symbol, InpSetupTF, g_tw2fExpiryShadows[i].h1BreakTime, signalTime);
            g_tw2fExpiryShadows[i].anchorH1BarsAfterExpiry = afterExpiry;
            ++g_tw2fShadowAnchors;
            if(g_tw2fExpiryShadows[i].h1Wave1OriginBreakTime > 0)
              {
               g_tw2fExpiryShadows[i].anchorBeforeOriginBreak =
                  signalTime < g_tw2fExpiryShadows[i].h1Wave1OriginBreakTime;
               TW2FFinalizeExpiryShadow(i, afterExpiry, "anchor_not_before_origin_break");
               continue;
              }
           }
        }
      if(afterExpiry >= TW2F_SHADOW_MAX_H1_BARS)
        {
         bool noAnchor = g_tw2fExpiryShadows[i].shadowAnchorTime == 0;
         g_tw2fExpiryShadows[i].noAnchorWithin240 = noAnchor;
         if(noAnchor) ++g_tw2fShadowNoAnchorWithin240;
         else if(g_tw2fExpiryShadows[i].h1Wave1OriginBreakTime == 0)
           {
            g_tw2fExpiryShadows[i].anchorBeforeOriginBreak = true;
            ++g_tw2fShadowAnchorsBeforeOriginBreak;
           }
         TW2FFinalizeExpiryShadow(i, TW2F_SHADOW_MAX_H1_BARS,
            noAnchor ? "no_anchor_within_240_h1_bars" :
            (g_tw2fExpiryShadows[i].anchorBeforeOriginBreak ? "anchor_before_origin_break" : "anchor_not_before_origin_break"));
        }
     }
  }

void TW2FFinalizeExpiryShadows()
  {
   for(int i = 0; i < ArraySize(g_tw2fExpiryShadows); ++i)
     {
      if(!g_tw2fExpiryShadows[i].active || g_tw2fExpiryShadows[i].written) continue;
      int observed = BarsBetween(g_tw2fExpiryShadows[i].symbol, InpSetupTF,
                                 g_tw2fExpiryShadows[i].expiryTime, TimeCurrent());
      TW2FFinalizeExpiryShadow(i, observed < 0 ? 0 : observed,
                               "test_window_ended_before_240_h1_bars");
     }
  }

bool TW2FApplyFrozenM15Anchor(TW2FSetup &state,
                              const TW2FSwing &priorReference,
                              const TW2FSwing &reference,
                              const TW2FSwing &protectedSwing,
                              const datetime signalTime,
                              const double provisionalExtreme,
                              const bool recordRuntimeEvidence)
  {
   if(state.state != TW2F_STATE_H1_REVERSAL_LEG || priorReference.kind == 0 ||
      reference.kind == 0 || protectedSwing.kind == 0) return false;
   state.m15PullbackStartTime = reference.confirmationTime;
   state.m15StructureDirection = state.direction > 0 ? "BEARISH" : "BULLISH";
   state.m15ReferenceExtreme = reference.price;
   state.m15ReferencePivotTime = reference.pivotTime;
   state.m15ReferenceConfirmationTime = reference.confirmationTime;
   state.m15PriorReferenceExtreme = priorReference.price;
   state.m15PriorReferencePivotTime = priorReference.pivotTime;
   state.m15PriorReferenceConfirmationTime = priorReference.confirmationTime;
   state.m15ProtectedSwing = protectedSwing.price;
   state.m15ProtectedPivotTime = protectedSwing.pivotTime;
   state.m15ProtectedConfirmationTime = protectedSwing.confirmationTime;
   state.h1Wave1ProvisionalExtreme = provisionalExtreme;
   state.lastPivotTime = reference.pivotTime;
   state.lastConfirmationTime = reference.confirmationTime;
   if(recordRuntimeEvidence)
     {
      ++g_tw2fAnchorFrozen;
      ++g_tw2fM15Pullbacks;
      TW2FChangeState(state, TW2F_STATE_M15_PULLBACK_ACTIVE, signalTime, "anchor_frozen");
     }
   else
     {
      state.previousState = state.state;
      state.state = TW2F_STATE_M15_PULLBACK_ACTIVE;
      state.stateChangedAt = signalTime;
      state.stateReason = "anchor_frozen";
     }
   return true;
  }

bool TW2FM15DetectAndFreezeAnchor(TW2FSetup &state,
                                  const MqlRates &rates[],
                                  const TW2FSwing &swings[],
                                  const datetime signalTime)
  {
   if(state.state != TW2F_STATE_H1_REVERSAL_LEG) return false;
   TW2FSwing highOld, highNew, lowOld, lowNew;
   if(!TW2FM15CounterStructure(state, swings, signalTime, highOld, highNew, lowOld, lowNew))
      return false;

   TW2FSwing priorReference = state.direction > 0 ? lowOld : highOld;
   TW2FSwing reference = state.direction > 0 ? lowNew : highNew;
   if(reference.confirmationTime != state.m15LastCounterStructureConfirmationTime)
     {
      state.m15LastCounterStructureConfirmationTime = reference.confirmationTime;
      state.lastPivotTime = reference.pivotTime;
      state.lastConfirmationTime = reference.confirmationTime;
      ++g_tw2fCountertrendStructure;
      TW2FWriteMilestone(state, signalTime, "countertrend_structure");
     }

   TW2FSwing protectedSwing;
   if(!TW2FFindProtectedBetween(swings, state, priorReference.pivotTime,
                               reference.pivotTime, signalTime, protectedSwing))
      return false;

   double provisionalExtreme = TW2FExtremeBetween(rates, state.h1BreakTime,
                                                   signalTime, state.direction > 0);
   return TW2FApplyFrozenM15Anchor(state, priorReference, reference, protectedSwing,
                                  signalTime, provisionalExtreme, true);
  }

bool TW2FM15ClassifyActive(TW2FSetup &state,
                           const MqlRates &rates[],
                           const TW2FSwing &swings[],
                           const datetime signalTime,
                           const double atr)
  {
   if(state.state != TW2F_STATE_M15_PULLBACK_ACTIVE) return false;
   TW2FSwing postAnchor;
   if(!TW2FFindLatestSameKindAfter(swings, state, state.m15ReferencePivotTime,
                                  state.m15ReferenceConfirmationTime, signalTime, postAnchor))
      return false;
   if(postAnchor.confirmationTime != state.m15LastCountedPostAnchorConfirmationTime)
     {
      state.m15LastCountedPostAnchorConfirmationTime = postAnchor.confirmationTime;
      state.m15PostAnchorExtreme = postAnchor.price;
      state.m15PostAnchorPivotTime = postAnchor.pivotTime;
      state.m15PostAnchorConfirmationTime = postAnchor.confirmationTime;
      state.lastPivotTime = postAnchor.pivotTime;
      state.lastConfirmationTime = postAnchor.confirmationTime;
      ++g_tw2fPostAnchorSwing;
      TW2FWriteMilestone(state, signalTime, "post_anchor_swing");
     }

   int between = BarsBetween(state.symbol, InpEntryTF,
                             state.m15ReferencePivotTime, postAnchor.pivotTime);
   if(between < InpPatternMinBars || between > InpPatternMaxBars) return false;
   MqlTick tick;
   if(!SymbolInfoTick(state.symbol, tick)) return false;
   TW2FSwing reference, priorReference;
   ZeroMemory(reference);
   ZeroMemory(priorReference);
   reference.kind = state.direction > 0 ? -1 : 1;
   reference.price = state.m15ReferenceExtreme;
   reference.pivotTime = state.m15ReferencePivotTime;
   reference.confirmationTime = state.m15ReferenceConfirmationTime;
   priorReference.kind = reference.kind;
   priorReference.price = state.m15PriorReferenceExtreme;
   priorReference.pivotTime = state.m15PriorReferencePivotTime;
   priorReference.confirmationTime = state.m15PriorReferenceConfirmationTime;
   string pattern = TW2FClassifyPattern(state, reference, postAnchor, priorReference,
                                        atr, tick.ask - tick.bid, rates[0].close);
   if(pattern == "NONE") return false;
   double neckline = TW2FPatternNeckline(rates, state, reference.pivotTime,
                                         postAnchor.pivotTime);
   if(neckline <= 0.0) return false;
   double extreme = state.direction > 0 ? MathMin(reference.price, postAnchor.price) :
                                          MathMax(reference.price, postAnchor.price);
   double heightAtr = MathAbs(neckline - extreme) / atr;
   if(heightAtr < InpMinimumPatternHeightATR) return false;

   state.m15PostAnchorExtreme = postAnchor.price;
   state.m15PostAnchorPivotTime = postAnchor.pivotTime;
   state.m15PostAnchorConfirmationTime = postAnchor.confirmationTime;
   state.m15PatternType = pattern;
   state.m15Point1 = reference.price;
   state.m15Point2 = postAnchor.price;
   state.m15PatternNeckline = neckline;
   state.m15PatternHeightAtr = heightAtr;
   state.m15PatternExtreme = extreme;
   state.h1Wave2Extreme = TW2FExtremeBetween(rates, state.m15PullbackStartTime,
                                             signalTime, state.direction < 0);
   state.lastPivotTime = postAnchor.pivotTime;
   state.lastConfirmationTime = postAnchor.confirmationTime;
   return TW2FApplyContinuationFailure(state, pattern, signalTime, true);
  }

bool TW2FM15ReanchorInvalidatedFailure(TW2FSetup &state,
                                       const TW2FSwing &swings[],
                                       const datetime signalTime,
                                       const double atr)
  {
   if(state.state != TW2F_STATE_M15_CONTINUATION_FAILED) return false;
   TW2FSwing latest;
   if(!TW2FFindLatestSameKindAfter(swings, state, state.m15PostAnchorPivotTime,
                                  state.m15PostAnchorConfirmationTime, signalTime, latest))
      return false;
   double clearBuffer = atr * InpEqualBottomToleranceATR;
   bool clearlyBroken = state.direction > 0 ? latest.price < state.m15PatternExtreme - clearBuffer :
                                              latest.price > state.m15PatternExtreme + clearBuffer;
   if(!clearlyBroken) return false;
   TW2FSwing protectedSwing;
   if(!TW2FFindProtectedBetween(swings, state, state.m15PostAnchorPivotTime,
                               latest.pivotTime, signalTime, protectedSwing))
      return false;

   state.m15PriorReferenceExtreme = state.m15PostAnchorExtreme;
   state.m15PriorReferencePivotTime = state.m15PostAnchorPivotTime;
   state.m15PriorReferenceConfirmationTime = state.m15PostAnchorConfirmationTime;
   state.m15ReferenceExtreme = latest.price;
   state.m15ReferencePivotTime = latest.pivotTime;
   state.m15ReferenceConfirmationTime = latest.confirmationTime;
   state.m15ProtectedSwing = protectedSwing.price;
   state.m15ProtectedPivotTime = protectedSwing.pivotTime;
   state.m15ProtectedConfirmationTime = protectedSwing.confirmationTime;
   state.m15PostAnchorExtreme = 0.0;
   state.m15PostAnchorPivotTime = 0;
   state.m15PostAnchorConfirmationTime = 0;
   state.m15LastCountedPostAnchorConfirmationTime = 0;
   state.m15PatternType = "NONE";
   state.m15Point1 = 0.0;
   state.m15Point2 = 0.0;
   state.m15PatternNeckline = 0.0;
   state.m15PatternHeightAtr = 0.0;
   state.m15PatternExtreme = 0.0;
   state.lastPivotTime = latest.pivotTime;
   state.lastConfirmationTime = latest.confirmationTime;
   ++g_tw2fFailureInvalidated;
   TW2FChangeState(state, TW2F_STATE_M15_PULLBACK_ACTIVE, signalTime,
                   "failure_invalidated_reanchored");
   return true;
  }

bool TW2FM15WaitForProtectedBreak(TW2FSetup &state,
                                  const MqlRates &rates[],
                                  const datetime signalTime,
                                  const double atr,
                                  const bool recordRuntimeEvidence)
  {
   if(state.state != TW2F_STATE_M15_CONTINUATION_FAILED || ArraySize(rates) < 2) return false;
   double entryBuffer = MathMax(SymbolInfoDouble(state.symbol, SYMBOL_POINT) * InpMinimumEntryBufferPoints,
                                atr * InpEntryBufferATR);
   bool crossed = state.direction > 0 ?
      rates[1].close <= state.m15ProtectedSwing + entryBuffer && rates[0].close > state.m15ProtectedSwing + entryBuffer :
      rates[1].close >= state.m15ProtectedSwing - entryBuffer && rates[0].close < state.m15ProtectedSwing - entryBuffer;
   if(!crossed) return false;

   state.signalTime = signalTime;
   state.signalBarTime = rates[0].time;
   state.signalClosePrice = rates[0].close;
   state.signalAtr = atr;
   state.signalBreakBodyAtr = MathAbs(rates[0].close - rates[0].open) / atr;
   state.m15BreakExtensionAtr = MathAbs(rates[0].close - state.m15ProtectedSwing) / atr;
   state.lastPivotTime = state.m15ProtectedPivotTime;
   state.lastConfirmationTime = state.m15ProtectedConfirmationTime;
   if(recordRuntimeEvidence)
     {
      ++g_tw2fProtectedBreak;
      ++g_tw2fM15Breaks;
      TW2FWriteMilestone(state, signalTime, "protected_break");
     }

   if(InpRequireM15MASlope)
     {
      double ma1 = TW2FSMA(rates, 0, InpMAPeriod);
      double ma2 = TW2FSMA(rates, 1, InpMAPeriod);
      bool slopePass = state.direction > 0 ? rates[0].close > ma1 && ma1 > ma2 :
                                             rates[0].close < ma1 && ma1 < ma2;
      if(!slopePass)
        {
         if(recordRuntimeEvidence)
           {
            ++g_tw2fMAFilterReject;
            TW2FWriteMilestone(state, signalTime, "ma_filter_reject");
           }
         return false;
        }
     }
   return true;
  }

bool TW2FApplyProtectedBreakTransition(TW2FSetup &state,
                                       const datetime signalTime,
                                       const bool recordRuntimeEvidence)
  {
   if(state.state != TW2F_STATE_M15_CONTINUATION_FAILED) return false;
   if(recordRuntimeEvidence)
      TW2FChangeState(state, TW2F_STATE_M15_STRUCTURE_BROKEN, signalTime,
                      "m15_protected_swing_closed_bar_break");
   else
     {
      state.previousState = state.state;
      state.state = TW2F_STATE_M15_STRUCTURE_BROKEN;
      state.stateChangedAt = signalTime;
      state.stateReason = "m15_protected_swing_closed_bar_break";
     }
   return state.state == TW2F_STATE_M15_STRUCTURE_BROKEN;
  }

double TW2FNormalizePrice(const string symbol, const double value)
  {
   return NormalizeDouble(value, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
  }

bool TW2FManagedMagic(const long magic)
  {
   if(magic == InpTW2FMagicNumber) return true;
   return InpBucketMode == BUCKET_LEGACY_AND_TRENDLINE_WAVE2_FAILURE && magic == InpMagicNumber;
  }

int TW2FCountPositions(const string symbol = "", const int direction = 0)
  {
   int count = 0;
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      if(PositionGetTicket(i) == 0 || !TW2FManagedMagic((long)PositionGetInteger(POSITION_MAGIC))) continue;
      if(symbol != "" && PositionGetString(POSITION_SYMBOL) != symbol) continue;
      int positionDirection = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1;
      if(direction != 0 && positionDirection != direction) continue;
      ++count;
     }
   return count;
  }

bool TW2FPositionRiskMoney(double &riskMoney)
  {
   riskMoney = 0.0;
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      if(PositionGetTicket(i) == 0 || !TW2FManagedMagic((long)PositionGetInteger(POSITION_MAGIC))) continue;
      string symbol = PositionGetString(POSITION_SYMBOL);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double volume = PositionGetDouble(POSITION_VOLUME);
      ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(sl <= 0.0) return false;
      if((pt == POSITION_TYPE_BUY && sl >= open) || (pt == POSITION_TYPE_SELL && sl <= open)) continue;
      double result = 0.0;
      ENUM_ORDER_TYPE ot = pt == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(!OrderCalcProfit(ot, symbol, volume, open, sl, result)) return false;
      riskMoney += MathMax(0.0, -result);
     }
   return true;
  }

bool TW2FValidCurrencyCode(const string value)
  {
   if(StringLen(value) != 3) return false;
   for(int i = 0; i < 3; ++i)
     {
      ushort c = StringGetCharacter(value, i);
      if(!((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z'))) return false;
     }
   return true;
  }

bool TW2FCurrencyDirectionRisk(const string symbol, const int direction,
                               const double candidateRiskMoney,
                               double &maxPercent)
  {
   maxPercent = 0.0;
   string base = SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
   string quote = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
   if(!TW2FValidCurrencyCode(base) || !TW2FValidCurrencyCode(quote)) return false;
   double baseRisk = candidateRiskMoney, quoteRisk = candidateRiskMoney;
   int baseDirection = direction;
   int quoteDirection = -direction;
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      if(PositionGetTicket(i) == 0 || !TW2FManagedMagic((long)PositionGetInteger(POSITION_MAGIC))) continue;
      string ps = PositionGetString(POSITION_SYMBOL);
      string pb = SymbolInfoString(ps, SYMBOL_CURRENCY_BASE);
      string pq = SymbolInfoString(ps, SYMBOL_CURRENCY_PROFIT);
      if(!TW2FValidCurrencyCode(pb) || !TW2FValidCurrencyCode(pq)) continue;
      double open = PositionGetDouble(POSITION_PRICE_OPEN), sl = PositionGetDouble(POSITION_SL);
      double volume = PositionGetDouble(POSITION_VOLUME), result = 0.0;
      ENUM_POSITION_TYPE pt = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      int pd = pt == POSITION_TYPE_BUY ? 1 : -1;
      if(sl <= 0.0 || (pd > 0 && sl >= open) || (pd < 0 && sl <= open)) continue;
      if(!OrderCalcProfit(pd > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, ps, volume, open, sl, result)) continue;
      double risk = MathMax(0.0, -result);
      if(pb == base && pd == baseDirection) baseRisk += risk;
      if(pq == base && -pd == baseDirection) baseRisk += risk;
      if(pb == quote && pd == quoteDirection) quoteRisk += risk;
      if(pq == quote && -pd == quoteDirection) quoteRisk += risk;
     }
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0) return false;
   maxPercent = MathMax(baseRisk, quoteRisk) / equity * 100.0;
   return true;
  }

double TW2FNormalizeVolumeFloor(const string symbol, const double raw)
  {
   double minimum = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maximum = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(minimum <= 0.0 || maximum <= 0.0 || step <= 0.0 || raw < minimum) return 0.0;
   double volume = MathFloor((raw + 1.0e-12) / step) * step;
   volume = MathMin(maximum, volume);
   if(volume < minimum) return 0.0;
   return NormalizeDouble(volume, 8);
  }

bool TW2FRiskPerLot(const string symbol, const int direction, const double entry,
                    const double stop, double &riskPerLot)
  {
   double result = 0.0;
   if(!OrderCalcProfit(direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                       symbol, 1.0, entry, stop, result)) return false;
   riskPerLot = MathMax(0.0, -result);
   return riskPerLot > 0.0;
  }

bool TW2FLegacyCombinedExecutionGate(const EntryCandidate &candidate,
                                     const double volume,
                                     string &reason)
  {
   reason = "none";
   if(InpBucketMode != BUCKET_LEGACY_AND_TRENDLINE_WAVE2_FAILURE) return true;
   TW2FUpdateRiskAnchors();
   if(InpTW2FEmergencyDisable || g_tw2fDailyStopped || g_tw2fWeeklyStopped || g_tw2fHardStopped)
     {
      reason = InpTW2FEmergencyDisable ? "emergency_disable" :
               (g_tw2fDailyStopped ? "daily_equity_stop" :
                (g_tw2fWeeklyStopped ? "weekly_equity_stop" : "hard_equity_stop"));
      return false;
     }
   double plannedRisk = 0.0;
   if(!OrderCalcProfit(candidate.direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                       candidate.symbol, volume, candidate.entryPrice, candidate.stopLoss, plannedRisk))
     { reason = "legacy_order_calc_profit_failed"; return false; }
   plannedRisk = MathMax(0.0, -plannedRisk);
   if(plannedRisk <= 0.0) { reason = "legacy_planned_risk_invalid"; return false; }
   double openRisk = 0.0;
   if(!TW2FPositionRiskMoney(openRisk)) { reason = "managed_position_missing_sl"; return false; }
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0) { reason = "equity_invalid"; return false; }
   if((openRisk + plannedRisk) / equity * 100.0 > InpTW2FMaxTotalOpenRiskPercent)
     { reason = "total_open_risk_cap"; return false; }
   if(TW2FCountPositions() >= InpMaxOpenPositionsTotal)
     { reason = "total_position_cap"; return false; }
   if(TW2FCountPositions(candidate.symbol) >= InpMaxOpenPositionsPerSymbol)
     { reason = "symbol_position_cap"; return false; }
   if(TW2FCountPositions("", candidate.direction) >= InpMaxSameDirectionPositions)
     { reason = "same_direction_position_cap"; return false; }
   double currencyRisk = 0.0;
   if(TW2FCurrencyDirectionRisk(candidate.symbol, candidate.direction, plannedRisk, currencyRisk) &&
      currencyRisk > InpMaxRiskPerCurrencyDirectionPercent)
     { reason = "currency_direction_risk_cap"; return false; }
   double margin = 0.0;
   if(!OrderCalcMargin(candidate.direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                       candidate.symbol, volume, candidate.entryPrice, margin))
     { reason = "legacy_order_calc_margin_failed"; return false; }
   double projectedMargin = AccountInfoDouble(ACCOUNT_MARGIN) + margin;
   double projectedLevel = projectedMargin > 0.0 ? equity / projectedMargin * 100.0 : 1.0e9;
   if(projectedLevel < InpMinimumProjectedMarginLevelPercent)
     { reason = "projected_margin_level"; return false; }
   return true;
  }

bool TW2FCompleteExecutionCandidate(const int stateIndex,
                                     TW2FSetup &state,
                                     TW2FCandidate &candidate,
                                     const double requested,
                                     const double stop,
                                     const double takeProfit,
                                     const double riskPrice,
                                     const double volume,
                                     const double plannedRisk,
                                     const double costR,
                                     const double requiredMargin,
                                     const double projectedLevel,
                                     const double totalRiskPercent,
                                     const double currencyRisk,
                                     const bool recordRuntimeEvidence)
  {
   if(state.state != TW2F_STATE_M15_STRUCTURE_BROKEN || state.direction == 0 ||
      requested <= 0.0 || stop <= 0.0 || takeProfit <= 0.0 || riskPrice <= 0.0 || volume <= 0.0)
      return false;
   state.requestedEntryPrice = requested;
   state.slAfterAdjustment = stop;
   state.stopDistance = riskPrice;
   state.takeProfit = takeProfit;
   state.lot = volume;
   state.plannedRiskMoney = plannedRisk;
   state.plannedRr = InpTakeProfitR;
   state.estimatedCostR = costR;
   state.requiredMargin = requiredMargin;
   state.projectedMarginLevel = projectedLevel;
   state.totalOpenRiskPercent = totalRiskPercent;
   state.currencyDirectionRiskPercent = currencyRisk;
   ZeroMemory(candidate);
   candidate.valid = true;
   candidate.stateIndex = stateIndex;
   candidate.symbol = state.symbol;
   candidate.direction = state.direction;
   candidate.setupId = state.setupId;
   candidate.signalTime = state.signalTime;
   candidate.signalClosePrice = state.signalClosePrice;
   candidate.requestedEntryPrice = requested;
   candidate.stopLoss = stop;
   candidate.takeProfit = takeProfit;
   candidate.riskPrice = riskPrice;
   candidate.atr = state.signalAtr;
   candidate.volume = volume;
   candidate.plannedRiskMoney = plannedRisk;
   candidate.estimatedCostR = costR;
   candidate.requiredMargin = requiredMargin;
   candidate.projectedMarginLevel = projectedLevel;
   candidate.totalOpenRiskPercent = totalRiskPercent;
   candidate.currencyDirectionRiskPercent = currencyRisk;
   if(recordRuntimeEvidence)
     {
      ++g_tw2fExecutionPass;
      TW2FChangeState(state, TW2F_STATE_ENTRY_READY, state.signalTime,
                      "execution_and_risk_gates_passed");
      TW2FWriteMilestone(state, state.signalTime, "execution_candidate_valid");
     }
   else
     {
      state.previousState = state.state;
      state.state = TW2F_STATE_ENTRY_READY;
      state.stateChangedAt = state.signalTime;
      state.stateReason = "execution_and_risk_gates_passed";
     }
   return candidate.valid && state.state == TW2F_STATE_ENTRY_READY;
  }

bool TW2FBuildExecutionCandidate(const int stateIndex, TW2FSetup &state, TW2FCandidate &candidate)
  {
   ZeroMemory(candidate);
   candidate.stateIndex = stateIndex;
   candidate.symbol = state.symbol;
   candidate.direction = state.direction;
   candidate.setupId = state.setupId;
   candidate.signalTime = state.signalTime;
   candidate.signalClosePrice = state.signalClosePrice;
   MqlTick tick;
   if(!SymbolInfoTick(state.symbol, tick)) { TW2FReject(state, "tick_unavailable"); return false; }
   double point = SymbolInfoDouble(state.symbol, SYMBOL_POINT);
   if(point <= 0.0 || state.signalAtr <= 0.0) { TW2FReject(state, "point_or_atr_invalid"); return false; }
   double requested = state.direction > 0 ? tick.ask : tick.bid;
   state.requestedEntryPrice = requested;
   state.spread = tick.ask - tick.bid;
   double extension = state.direction > 0 ? requested - state.m15ProtectedSwing : state.m15ProtectedSwing - requested;
   state.m15BreakExtensionAtr = extension / state.signalAtr;
   if(extension > state.signalAtr * InpMaxBreakExtensionATR)
     { TW2FReject(state, "max_break_extension"); return false; }
   if(state.signalBreakBodyAtr > InpMaxBreakCandleATR)
     { TW2FReject(state, "max_break_candle"); return false; }

   double stopAnchor = state.m15PatternExtreme;
   if(InpTW2FStopMode == TW2F_STOP_LATEST_M15_SWING_EXTREME) stopAnchor = state.m15Point2;
   else if(InpTW2FStopMode == TW2F_STOP_H1_WAVE2_EXTREME) stopAnchor = state.h1Wave2Extreme;
   if(stopAnchor <= 0.0) { TW2FReject(state, "stop_anchor_invalid"); return false; }
   double buffer = MathMax(state.spread * InpSLSpreadMultiplier, state.signalAtr * InpSLBufferATR);
   double stop = state.direction > 0 ? stopAnchor - buffer : stopAnchor + buffer;
   state.slBeforeAdjustment = stop;
   int stopsLevel = (int)SymbolInfoInteger(state.symbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freezeLevel = (int)SymbolInfoInteger(state.symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double minimumDistance = MathMax(stopsLevel, freezeLevel) * point;
   if(state.direction > 0)
      stop = MathMin(stop, tick.bid - minimumDistance);
   else
      stop = MathMax(stop, tick.ask + minimumDistance);
   stop = TW2FNormalizePrice(state.symbol, stop);
   state.slAfterAdjustment = stop;
   double riskPrice = state.direction > 0 ? requested - stop : stop - requested;
   if(riskPrice <= 0.0) { TW2FReject(state, "stop_distance_invalid"); return false; }
   double plannedRr = InpTakeProfitR;
   if(InpTakeProfitMode != TW2F_TAKE_PROFIT_FIXED_R || plannedRr < InpMinimumPlannedRR)
     { TW2FReject(state, "planned_rr_invalid"); return false; }
   double tp = state.direction > 0 ? requested + riskPrice * plannedRr : requested - riskPrice * plannedRr;
   tp = TW2FNormalizePrice(state.symbol, tp);

   double riskPerLot = 0.0;
   if(!TW2FRiskPerLot(state.symbol, state.direction, requested, stop, riskPerLot))
     { TW2FReject(state, "order_calc_profit_failed"); return false; }
   double riskBase = InpRiskBase == TW2F_RISK_EQUITY ? AccountInfoDouble(ACCOUNT_EQUITY) :
                                                        AccountInfoDouble(ACCOUNT_BALANCE);
   double riskBudget = riskBase * InpRiskPercent / 100.0;
   double rawVolume = InpLotMode == TW2F_LOT_FIXED ? InpFixedLot : riskBudget / riskPerLot;
   double volume = TW2FNormalizeVolumeFloor(state.symbol, rawVolume);
   if(volume <= 0.0) { TW2FReject(state, "minimum_lot_exceeds_risk_budget"); return false; }
   double plannedRisk = riskPerLot * volume;
   if(InpLotMode == TW2F_LOT_PERCENT_RISK && plannedRisk > riskBudget * (1.0 + InpRiskMoneyTolerancePercent / 100.0))
     { TW2FReject(state, "normalized_volume_risk_exceeded"); return false; }

   double spreadR = state.spread / riskPrice;
   double slippagePrice = InpEstimatedSlippagePointsPerSide * point * 2.0;
   state.slippage = slippagePrice;
   double costR = spreadR + slippagePrice / riskPrice;
   if(InpEstimatedCommissionPerLotRoundTrip >= 0.0 && plannedRisk > 0.0)
      costR += InpEstimatedCommissionPerLotRoundTrip * volume / plannedRisk;
   if(costR > InpMaxEstimatedCostR) { state.estimatedCostR = costR; TW2FReject(state, "estimated_cost_r"); return false; }

   double openRiskMoney = 0.0;
   if(!TW2FPositionRiskMoney(openRiskMoney)) { TW2FReject(state, "managed_position_missing_sl"); return false; }
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0) { TW2FReject(state, "equity_invalid"); return false; }
   double totalRiskPercent = (openRiskMoney + plannedRisk) / equity * 100.0;
   if(totalRiskPercent > InpTW2FMaxTotalOpenRiskPercent)
     {
      ++g_tw2fTotalRiskRejectCount;
      TW2FReject(state, "total_open_risk_cap");
      return false;
     }
   if(TW2FCountPositions() >= InpMaxOpenPositionsTotal)
     { TW2FReject(state, "total_position_cap"); return false; }
   if(TW2FCountPositions(state.symbol) >= InpMaxOpenPositionsPerSymbol)
     { TW2FReject(state, "symbol_position_cap"); return false; }
   if(TW2FCountPositions("", state.direction) >= InpMaxSameDirectionPositions)
     { TW2FReject(state, "same_direction_position_cap"); return false; }
   if(HasKey(g_tw2fTradedSetupKeys, state.setupId) || state.traded)
     { TW2FReject(state, "setup_already_traded"); return false; }

   long marginMode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   if(marginMode == ACCOUNT_MARGIN_MODE_RETAIL_NETTING || marginMode == ACCOUNT_MARGIN_MODE_EXCHANGE)
     {
      for(int i = 0; i < PositionsTotal(); ++i)
        {
         if(PositionGetTicket(i) == 0 || PositionGetString(POSITION_SYMBOL) != state.symbol) continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != InpTW2FMagicNumber)
           { TW2FReject(state, "unsafe_netting_mixed_position"); return false; }
        }
     }

   double currencyRisk = 0.0;
   bool currencyKnown = TW2FCurrencyDirectionRisk(state.symbol, state.direction, plannedRisk, currencyRisk);
   if(currencyKnown && currencyRisk > InpMaxRiskPerCurrencyDirectionPercent)
     {
      ++g_tw2fCurrencyRiskRejectCount;
      TW2FReject(state, "currency_direction_risk_cap");
      return false;
     }
   if(!currencyKnown)
      TW2FAddRejection("currency_code_unavailable_warning");

   double requiredMargin = 0.0;
   if(!OrderCalcMargin(state.direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                       state.symbol, volume, requested, requiredMargin))
     { TW2FReject(state, "order_calc_margin_failed"); return false; }
   double projectedMargin = AccountInfoDouble(ACCOUNT_MARGIN) + requiredMargin;
   double projectedLevel = projectedMargin > 0.0 ? equity / projectedMargin * 100.0 : 1.0e9;
   if(projectedLevel < InpMinimumProjectedMarginLevelPercent)
     { TW2FReject(state, "projected_margin_level"); return false; }

   long tradeMode = SymbolInfoInteger(state.symbol, SYMBOL_TRADE_MODE);
   if(tradeMode == SYMBOL_TRADE_MODE_DISABLED || tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY)
     { TW2FReject(state, "symbol_trade_mode_blocked"); return false; }
   return TW2FCompleteExecutionCandidate(stateIndex, state, candidate, requested, stop, tp,
                                         riskPrice, volume, plannedRisk, costR, requiredMargin,
                                         projectedLevel, totalRiskPercent, currencyRisk, true);
  }

bool TW2FRunOneM15PathTest(const int direction, const int stateIndex)
  {
   TW2FSetup state;
   TW2FCandidate candidate;
   TW2FSwing priorReference, reference, protectedSwing, postAnchor, noThird;
   ZeroMemory(state);
   ZeroMemory(candidate);
   ZeroMemory(priorReference);
   ZeroMemory(reference);
   ZeroMemory(protectedSwing);
   ZeroMemory(postAnchor);
   ZeroMemory(noThird);
   state.symbol = ArraySize(g_symbols) > 0 ? g_symbols[0] : "USDJPY";
   state.direction = direction;
   state.setupId = direction > 0 ? "SELFTEST_M15_LONG" : "SELFTEST_M15_SHORT";
   state.state = TW2F_STATE_H1_REVERSAL_LEG;
   state.h1BreakTime = 100;
   priorReference.kind = direction > 0 ? -1 : 1;
   priorReference.price = direction > 0 ? 100.50 : 99.50;
   priorReference.pivotTime = 200;
   priorReference.confirmationTime = 220;
   protectedSwing.kind = -priorReference.kind;
   protectedSwing.price = direction > 0 ? 100.80 : 99.20;
   protectedSwing.pivotTime = 240;
   protectedSwing.confirmationTime = 260;
   reference.kind = priorReference.kind;
   reference.price = 100.00;
   reference.pivotTime = 280;
   reference.confirmationTime = 300;
   bool anchorApplied = TW2FApplyFrozenM15Anchor(state, priorReference, reference,
                                                 protectedSwing, 320, 100.0, false);

   postAnchor.kind = reference.kind;
   postAnchor.price = direction > 0 ? 100.30 : 99.70;
   postAnchor.pivotTime = 360;
   postAnchor.confirmationTime = 380;
   string expectedPattern = direction > 0 ? "HIGHER_LOW" : "LOWER_HIGH";
   string pattern = TW2FClassifyPattern(state, reference, postAnchor, noThird, 1.0, 0.01,
                                        direction > 0 ? 100.40 : 99.60);
   bool failureApplied = TW2FApplyContinuationFailure(state, pattern, 400, false);

   MqlRates rates[];
   ArrayResize(rates, InpMAPeriod + 2);
   for(int i = 0; i < ArraySize(rates); ++i)
     {
      rates[i].time = 500 - i * PeriodSeconds(InpEntryTF);
      rates[i].close = direction > 0 ? 100.70 : 99.30;
      rates[i].open = rates[i].close;
      rates[i].high = rates[i].close + 0.10;
      rates[i].low = rates[i].close - 0.10;
     }
   rates[0].close = direction > 0 ? 101.20 : 98.80;
   rates[0].open = direction > 0 ? 100.70 : 99.30;
   rates[InpMAPeriod].close = 100.00;
   bool protectedBreak = TW2FM15WaitForProtectedBreak(state, rates, 520, 1.0, false);
   bool structureBroken = protectedBreak && TW2FApplyProtectedBreakTransition(state, 520, false);

   double requested = direction > 0 ? 101.30 : 98.70;
   double stop = direction > 0 ? 99.30 : 100.70;
   double riskPrice = 2.00;
   double takeProfit = direction > 0 ? 105.30 : 94.70;
   bool entryReady = structureBroken &&
      TW2FCompleteExecutionCandidate(stateIndex, state, candidate, requested, stop,
                                     takeProfit, riskPrice, 0.10, 50.0, 0.02,
                                     100.0, 1000.0, 0.50, 0.50, false);
   bool pass = anchorApplied && state.previousState == TW2F_STATE_M15_STRUCTURE_BROKEN &&
               pattern == expectedPattern && failureApplied && protectedBreak && structureBroken &&
               entryReady && state.state == TW2F_STATE_ENTRY_READY && candidate.valid &&
               candidate.stateIndex == stateIndex && candidate.direction == direction &&
               candidate.stopLoss > 0.0 && candidate.takeProfit > 0.0 && candidate.volume > 0.0;
   if(pass)
     {
      ++g_tw2fM15PathTestsPassed;
      return true;
     }
   ++g_tw2fM15PathTestsFailed;
   PrintFormat("%s M15 path test failed direction=%s anchor=%s pattern=%s failure=%s break=%s structure=%s entry=%s candidate=%s index=%d stop=%.5f tp=%.5f volume=%.2f state=%s",
               TW2F_STRATEGY_NAME, DirectionText(direction), BoolText(anchorApplied), pattern,
               BoolText(failureApplied), BoolText(protectedBreak), BoolText(structureBroken),
               BoolText(entryReady), BoolText(candidate.valid), candidate.stateIndex,
               candidate.stopLoss, candidate.takeProfit, candidate.volume, TW2FStateName(state.state));
   return false;
  }

bool TW2FRunM15EndToEndStateTests()
  {
   bool longPass = TW2FRunOneM15PathTest(1, 901);
   bool shortPass = TW2FRunOneM15PathTest(-1, 902);
   PrintFormat("%s M15 end-to-end state tests passed=%d failed=%d",
               TW2F_STRATEGY_NAME, g_tw2fM15PathTestsPassed, g_tw2fM15PathTestsFailed);
   return longPass && shortPass;
  }

bool TW2FFindOpenedPosition(const string symbol, ulong &ticket, long &positionId, double &entryPrice)
  {
   ticket = 0; positionId = 0; entryPrice = 0.0;
   datetime newest = 0;
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      ulong currentTicket = PositionGetTicket(i);
      if(currentTicket == 0 || PositionGetString(POSITION_SYMBOL) != symbol ||
         (long)PositionGetInteger(POSITION_MAGIC) != InpTW2FMagicNumber) continue;
      datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      if(ticket == 0 || opened >= newest)
        {
         ticket = currentTicket;
         positionId = (long)PositionGetInteger(POSITION_IDENTIFIER);
         entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         newest = opened;
        }
     }
   return ticket > 0;
  }

void TW2FTrackPosition(const TW2FCandidate &candidate, TW2FSetup &state,
                       const ulong ticket, const long positionId, const double entryPrice)
  {
   int size = ArraySize(g_tw2fTrades);
   ArrayResize(g_tw2fTrades, size + 1);
   TW2FTrackedTrade tracked;
   ZeroMemory(tracked);
   tracked.active = true;
   tracked.ticket = ticket;
   tracked.positionId = positionId;
   tracked.symbol = candidate.symbol;
   tracked.direction = candidate.direction;
   tracked.setupId = candidate.setupId;
   tracked.entryTime = TimeCurrent();
   tracked.signalClosePrice = candidate.signalClosePrice;
   tracked.requestedEntryPrice = candidate.requestedEntryPrice;
   tracked.entryPrice = entryPrice;
   tracked.initialStop = state.slAfterAdjustment;
   tracked.takeProfit = state.takeProfit;
   tracked.riskPrice = MathAbs(entryPrice - state.slAfterAdjustment);
   tracked.volume = candidate.volume;
   tracked.initialRiskMoney = state.actualInitialRiskMoney;
   tracked.estimatedCostR = candidate.estimatedCostR;
   tracked.maxFavorableR = 0.0;
   tracked.maxAdverseR = 0.0;
   tracked.recoveredAfterRestart = false;
   g_tw2fTrades[size] = tracked;
  }

bool TW2FOpenCandidateForState(const TW2FCandidate &candidate, TW2FSetup &state)
  {
   if(!candidate.valid) return false;
   if(InpTW2FEmergencyDisable || g_tw2fDailyStopped || g_tw2fWeeklyStopped || g_tw2fHardStopped)
     {
      string reason = InpTW2FEmergencyDisable ? "emergency_disable" :
                      (g_tw2fDailyStopped ? "daily_equity_stop" :
                       (g_tw2fWeeklyStopped ? "weekly_equity_stop" : "hard_equity_stop"));
      TW2FReject(state, reason);
      return false;
     }
   trade.SetExpertMagicNumber(InpTW2FMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);
   trade.SetTypeFillingBySymbol(candidate.symbol);
   string shortId = "TW2F|" + (candidate.direction > 0 ? "L|" : "S|") + IntegerToString((long)candidate.signalTime);
   bool ok = candidate.direction > 0 ?
      trade.Buy(candidate.volume, candidate.symbol, 0.0, candidate.stopLoss, candidate.takeProfit, shortId) :
      trade.Sell(candidate.volume, candidate.symbol, 0.0, candidate.stopLoss, candidate.takeProfit, shortId);
   uint retcode = trade.ResultRetcode();
   if(!ok || (retcode != TRADE_RETCODE_DONE && retcode != TRADE_RETCODE_DONE_PARTIAL && retcode != TRADE_RETCODE_PLACED))
     {
      TW2FReject(state, "order_failed_" + IntegerToString((int)retcode));
      return false;
     }
   ulong ticket = 0; long positionId = 0; double filled = trade.ResultPrice();
   double selectedEntry = 0.0;
   if(!TW2FFindOpenedPosition(candidate.symbol, ticket, positionId, selectedEntry))
     {
      TW2FReject(state, "position_not_found_after_order");
      return false;
     }
   if(filled <= 0.0) filled = selectedEntry;
   double actualRiskPrice = MathAbs(filled - candidate.stopLoss);
   double actualRiskPerLot = 0.0;
   if(!TW2FRiskPerLot(candidate.symbol, candidate.direction, filled, candidate.stopLoss, actualRiskPerLot))
     {
      trade.PositionClose(ticket);
      TW2FReject(state, "post_fill_risk_calc_failed");
      return false;
     }
   double actualRiskMoney = actualRiskPerLot * candidate.volume;
   double permitted = candidate.plannedRiskMoney * (1.0 + InpRiskMoneyTolerancePercent / 100.0);
   if(actualRiskMoney > permitted)
     {
      trade.PositionClose(ticket);
      TW2FReject(state, "post_fill_risk_tolerance_exceeded");
      return false;
     }
   double finalTp = candidate.direction > 0 ? filled + actualRiskPrice * InpTakeProfitR :
                                               filled - actualRiskPrice * InpTakeProfitR;
   finalTp = TW2FNormalizePrice(candidate.symbol, finalTp);
   if(!trade.PositionModify(ticket, candidate.stopLoss, finalTp))
     {
      trade.PositionClose(ticket);
      TW2FReject(state, "post_fill_sl_tp_modify_failed_" + IntegerToString((int)trade.ResultRetcode()));
      return false;
     }
   state.filledEntryPrice = filled;
   state.takeProfit = finalTp;
   state.actualInitialRiskMoney = actualRiskMoney;
   state.stopDistance = actualRiskPrice;
   state.traded = true;
   AddUniqueKey(g_tw2fTradedSetupKeys, state.setupId);
   ++g_tw2fOrders;
   TW2FTrackPosition(candidate, state, ticket, positionId, filled);
   TW2FChangeState(state, TW2F_STATE_POSITION_OPEN, TimeCurrent(), "market_order_filled");
   TW2FWriteEvent(state, "order_filled", "none");
   return true;
  }

bool TW2FOpenCandidate(const TW2FCandidate &candidate)
  {
   if(candidate.stateIndex < 0 || candidate.stateIndex >= ArraySize(g_tw2fSetups)) return false;
   return TW2FOpenCandidateForState(candidate, g_tw2fSetups[candidate.stateIndex]);
  }

bool TW2FEvaluateM15(const int stateIndex, TW2FSetup &state, TW2FCandidate &candidate)
  {
   ZeroMemory(candidate);
   if(state.state < TW2F_STATE_H1_REVERSAL_LEG || TW2FIsTerminal(state)) return false;
   MqlRates rates[]; TW2FSwing swings[];
   if(!TW2FBuildSwings(state.symbol, InpEntryTF, rates, swings))
     { TW2FReject(state, "m15_data_or_swings_unavailable", false); return false; }
   datetime signalTime = TW2FBarCloseTime(InpEntryTF, rates[0].time);
   if(signalTime <= state.eligibleAfter || signalTime <= state.h1BreakTime) return false;
   double atr = ATR(rates, 0, InpATRPeriod);
   if(atr <= 0.0) { TW2FReject(state, "m15_atr_unavailable", false); return false; }
   if(state.state == TW2F_STATE_H1_REVERSAL_LEG)
     {
      TW2FM15DetectAndFreezeAnchor(state, rates, swings, signalTime);
      return false;
     }

   if(state.state == TW2F_STATE_M15_PULLBACK_ACTIVE)
     {
      int patternAge = BarsBetween(state.symbol, InpEntryTF,
                                   state.m15ReferenceConfirmationTime, signalTime);
      if(patternAge > InpM15PatternExpiryBars)
        {
         TW2FChangeState(state, TW2F_STATE_EXPIRED, signalTime, "m15_pattern_expiry");
         return false;
        }
      TW2FM15ClassifyActive(state, rates, swings, signalTime, atr);
     }

   if(state.state == TW2F_STATE_M15_CONTINUATION_FAILED)
     {
      if(TW2FM15ReanchorInvalidatedFailure(state, swings, signalTime, atr)) return false;
      if(!TW2FM15WaitForProtectedBreak(state, rates, signalTime, atr, true)) return false;
      if(!TW2FApplyProtectedBreakTransition(state, signalTime, true)) return false;
      if(!TW2FBuildExecutionCandidate(stateIndex, state, candidate)) return false;
      if(!candidate.valid)
        {
         TW2FWriteEvent(state, "execution_candidate_invalid", "candidate_valid_false");
         return false;
        }
      return candidate.valid;
     }
   return false;
  }

void TW2FProcessH4(const int symbolIndex)
  {
   string symbol = g_symbols[symbolIndex];
   MqlRates latest[];
   if(!CopyClosedRates(symbol, InpContextTF, InpATRPeriod + 3, latest))
     { TW2FAddRejection("h4_rates_unavailable"); return; }
   double atr = ATR(latest, 0, InpATRPeriod);
   datetime signalTime = TW2FBarCloseTime(InpContextTF, latest[0].time);
   for(int side = 0; side < 2; ++side)
     {
      int index = symbolIndex * 2 + side;
      if(g_tw2fSetups[index].state > TW2F_STATE_IDLE && !TW2FIsTerminal(g_tw2fSetups[index]) && atr > 0.0)
        {
         bool oppositeUpdate = g_tw2fSetups[index].direction > 0 ? latest[0].close < g_tw2fSetups[index].h4ImpulseLow - atr * InpStructureBreakBufferATR :
                                                                  latest[0].close > g_tw2fSetups[index].h4ImpulseHigh + atr * InpStructureBreakBufferATR;
         if(oppositeUpdate) TW2FReject(g_tw2fSetups[index], "h4_opposite_structure_update");
        }
      int direction = side == 0 ? 1 : -1;
      if(!TW2FDirectionEnabled(direction)) continue;
      TW2FSetup detected;
      if(!TW2FDetectH4Impulse(symbol, direction, detected)) continue;
      if(g_tw2fSetups[index].setupId == detected.setupId) continue;
      if(g_tw2fSetups[index].state > TW2F_STATE_IDLE && !TW2FIsTerminal(g_tw2fSetups[index]))
         TW2FChangeState(g_tw2fSetups[index], TW2F_STATE_EXPIRED, signalTime, "superseded_by_new_h4_impulse");
      g_tw2fSetups[index] = detected;
      ++g_tw2fH4Impulses;
      ++g_tw2fH4StructureBreaks;
      TW2FChangeState(g_tw2fSetups[index], TW2F_STATE_H4_IMPULSE_DETECTED, detected.h4RecognizedAt, "h4_impulse_and_protected_structure_break");
      TW2FEvaluateH1(g_tw2fSetups[index], detected.h4RecognizedAt, true);
     }
  }

void TW2FProcessH1(const int symbolIndex)
  {
   datetime signalTime = TimeCurrent();
   MqlRates latest[];
   if(CopyClosedRates(g_symbols[symbolIndex], InpSetupTF, 1, latest))
      signalTime = TW2FBarCloseTime(InpSetupTF, latest[0].time);
   TW2FUpdateExpiryShadowsH1(g_symbols[symbolIndex], signalTime);
   for(int side = 0; side < 2; ++side)
      TW2FEvaluateH1(g_tw2fSetups[symbolIndex * 2 + side], signalTime, false);
  }

void TW2FUpdateRiskMetrics(TW2FSetup &state)
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   state.dailyDrawdownPercent = g_tw2fDayStartEquity > 0.0 ?
      MathMax(0.0, (g_tw2fDayStartEquity - equity) / g_tw2fDayStartEquity * 100.0) : 0.0;
   state.weeklyDrawdownPercent = g_tw2fWeekStartEquity > 0.0 ?
      MathMax(0.0, (g_tw2fWeekStartEquity - equity) / g_tw2fWeekStartEquity * 100.0) : 0.0;
   state.equityDrawdownPercent = g_tw2fPeakEquity > 0.0 ?
      MathMax(0.0, (g_tw2fPeakEquity - equity) / g_tw2fPeakEquity * 100.0) : 0.0;
  }

void TW2FProcessM15(const int symbolIndex)
  {
   TW2FUpdateExpiryShadowsM15(g_symbols[symbolIndex]);
   for(int side = 0; side < 2; ++side)
     {
      int stateIndex = symbolIndex * 2 + side;
      TW2FUpdateRiskMetrics(g_tw2fSetups[stateIndex]);
      TW2FCandidate candidate;
      if(TW2FEvaluateM15(stateIndex, g_tw2fSetups[stateIndex], candidate)) TW2FOpenCandidate(candidate);
     }
  }

void TW2FCloseManagedPositions()
  {
   if(g_tw2fClosingForStop) return;
   g_tw2fClosingForStop = true;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && (long)PositionGetInteger(POSITION_MAGIC) == InpTW2FMagicNumber)
         trade.PositionClose(ticket);
     }
   g_tw2fClosingForStop = false;
  }

void TW2FUpdateRiskAnchors()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0) return;
   bool changed = false;
   if(equity > g_tw2fPeakEquity) { g_tw2fPeakEquity = equity; changed = true; }
   int dayKey = DateKey(TimeCurrent());
   if(dayKey != g_tw2fDayKey)
     {
      g_tw2fDayKey = dayKey; g_tw2fDayStartEquity = equity; g_tw2fDailyStopped = false; changed = true;
     }
   int weekKey = TW2FWeekKey(TimeCurrent());
   if(weekKey != g_tw2fWeekKey)
     {
      g_tw2fWeekKey = weekKey; g_tw2fWeekStartEquity = equity; g_tw2fWeeklyStopped = false; changed = true;
     }
   double dailyDd = g_tw2fDayStartEquity > 0.0 ? (g_tw2fDayStartEquity - equity) / g_tw2fDayStartEquity * 100.0 : 0.0;
   double weeklyDd = g_tw2fWeekStartEquity > 0.0 ? (g_tw2fWeekStartEquity - equity) / g_tw2fWeekStartEquity * 100.0 : 0.0;
   double hardDd = g_tw2fPeakEquity > 0.0 ? (g_tw2fPeakEquity - equity) / g_tw2fPeakEquity * 100.0 : 0.0;
   if(!g_tw2fDailyStopped && dailyDd >= InpDailyEquityDrawdownLimitPercent)
     { g_tw2fDailyStopped = true; ++g_tw2fDailyStopCount; changed = true; if(InpClosePositionsOnDailyStop) TW2FCloseManagedPositions(); }
   if(!g_tw2fWeeklyStopped && weeklyDd >= InpWeeklyEquityDrawdownLimitPercent)
     { g_tw2fWeeklyStopped = true; ++g_tw2fWeeklyStopCount; changed = true; }
   if(!g_tw2fHardStopped && hardDd >= InpMaxEquityDrawdownPercent)
     { g_tw2fHardStopped = true; ++g_tw2fHardStopCount; changed = true; if(InpClosePositionsOnHardStop) TW2FCloseManagedPositions(); }
   if(changed) TW2FPersistRiskState();
  }

void TW2FManageTrades()
  {
   for(int i = 0; i < ArraySize(g_tw2fTrades); ++i)
     {
      if(!g_tw2fTrades[i].active) continue;
      bool selected = false;
      for(int p = 0; p < PositionsTotal(); ++p)
        {
         if(PositionGetTicket(p) > 0 &&
            (long)PositionGetInteger(POSITION_IDENTIFIER) == g_tw2fTrades[i].positionId &&
            (long)PositionGetInteger(POSITION_MAGIC) == InpTW2FMagicNumber)
           { selected = true; break; }
        }
      if(!selected || g_tw2fTrades[i].riskPrice <= 0.0) continue;
      MqlTick tick;
      if(!SymbolInfoTick(g_tw2fTrades[i].symbol, tick)) continue;
      double current = g_tw2fTrades[i].direction > 0 ? tick.bid : tick.ask;
      double moveR = g_tw2fTrades[i].direction > 0 ?
         (current - g_tw2fTrades[i].entryPrice) / g_tw2fTrades[i].riskPrice :
         (g_tw2fTrades[i].entryPrice - current) / g_tw2fTrades[i].riskPrice;
      g_tw2fTrades[i].maxFavorableR = MathMax(g_tw2fTrades[i].maxFavorableR, moveR);
      g_tw2fTrades[i].maxAdverseR = MathMin(g_tw2fTrades[i].maxAdverseR, moveR);
     }
  }

void TW2FWriteTrade(const TW2FTrackedTrade &tracked, const datetime exitTime,
                    const double exitPrice, const double profit, const double commission,
                    const double swap, const string exitReason)
  {
   TW2FEnsureLogFolder();
   int handle = FileOpen(TW2FLogFileName("trades"), TW2FLogFlags(), ',');
   if(handle == INVALID_HANDLE) return;
   bool header = FileSize(handle) == 0;
   FileSeek(handle, 0, SEEK_END);
   if(header)
      FileWriteString(handle,
         "entry_time,exit_time,strategy,bucket,setup_id,symbol,direction,signal_close_price,requested_entry_price,filled_entry_price,sl,tp,stop_distance,lot,actual_initial_risk_money,gross_result_r,net_result_r,estimated_cost_r,result_money,mfe_r,mae_r,exit_price,exit_reason,recovered_after_restart\r\n");
   double grossR = tracked.initialRiskMoney > 0.0 ? profit / tracked.initialRiskMoney : 0.0;
   double netMoney = profit + commission + swap;
   double netR = tracked.initialRiskMoney > 0.0 ? netMoney / tracked.initialRiskMoney : 0.0;
   int digits = (int)SymbolInfoInteger(tracked.symbol, SYMBOL_DIGITS);
   string row = "";
   CsvAppend(row, TimeToString(tracked.entryTime, TIME_DATE | TIME_SECONDS));
   CsvAppend(row, TimeToString(exitTime, TIME_DATE | TIME_SECONDS));
   CsvAppend(row, TW2F_STRATEGY_NAME);
   CsvAppend(row, TW2F_STRATEGY_NAME);
   CsvAppend(row, tracked.setupId);
   CsvAppend(row, tracked.symbol);
   CsvAppend(row, DirectionText(tracked.direction));
   CsvAppend(row, DoubleToString(tracked.signalClosePrice, digits));
   CsvAppend(row, DoubleToString(tracked.requestedEntryPrice, digits));
   CsvAppend(row, DoubleToString(tracked.entryPrice, digits));
   CsvAppend(row, DoubleToString(tracked.initialStop, digits));
   CsvAppend(row, DoubleToString(tracked.takeProfit, digits));
   CsvAppend(row, DoubleToString(tracked.riskPrice, digits));
   CsvAppend(row, DoubleToString(tracked.volume, 8));
   CsvAppend(row, DoubleToString(tracked.initialRiskMoney, 2));
   CsvAppend(row, DoubleToString(grossR, 4));
   CsvAppend(row, DoubleToString(netR, 4));
   CsvAppend(row, DoubleToString(tracked.estimatedCostR, 4));
   CsvAppend(row, DoubleToString(netMoney, 2));
   CsvAppend(row, DoubleToString(tracked.maxFavorableR, 4));
   CsvAppend(row, DoubleToString(tracked.maxAdverseR, 4));
   CsvAppend(row, DoubleToString(exitPrice, digits));
   CsvAppend(row, exitReason);
   CsvAppend(row, BoolText(tracked.recoveredAfterRestart));
   FileWriteString(handle, row + "\r\n");
   FileClose(handle);
  }

int TW2FFindTracked(const long positionId)
  {
   for(int i = 0; i < ArraySize(g_tw2fTrades); ++i)
      if(g_tw2fTrades[i].active && g_tw2fTrades[i].positionId == positionId) return i;
   return -1;
  }

void TW2FOnTradeTransaction(const MqlTradeTransaction &trans)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || !HistoryDealSelect(trans.deal)) return;
   if((long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpTW2FMagicNumber) return;
   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT && entry != DEAL_ENTRY_OUT_BY) return;
   long positionId = (long)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   int index = TW2FFindTracked(positionId);
   if(index < 0) return;
   double exitPrice = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
   double commission = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   double swap = HistoryDealGetDouble(trans.deal, DEAL_SWAP);
   datetime exitTime = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
   string reason = EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON));
   TW2FWriteTrade(g_tw2fTrades[index], exitTime, exitPrice, profit, commission, swap, reason);
   g_tw2fTrades[index].active = false;
  }

void TW2FRecoverPositions()
  {
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || (long)PositionGetInteger(POSITION_MAGIC) != InpTW2FMagicNumber) continue;
      TW2FTrackedTrade tracked;
      ZeroMemory(tracked);
      tracked.active = true;
      tracked.ticket = ticket;
      tracked.positionId = (long)PositionGetInteger(POSITION_IDENTIFIER);
      tracked.symbol = PositionGetString(POSITION_SYMBOL);
      tracked.direction = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1;
      tracked.setupId = PositionGetString(POSITION_COMMENT);
      tracked.entryTime = (datetime)PositionGetInteger(POSITION_TIME);
      tracked.entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      tracked.initialStop = PositionGetDouble(POSITION_SL);
      tracked.takeProfit = PositionGetDouble(POSITION_TP);
      tracked.volume = PositionGetDouble(POSITION_VOLUME);
      tracked.riskPrice = MathAbs(tracked.entryPrice - tracked.initialStop);
      double riskPerLot = 0.0;
      if(TW2FRiskPerLot(tracked.symbol, tracked.direction, tracked.entryPrice, tracked.initialStop, riskPerLot))
         tracked.initialRiskMoney = riskPerLot * tracked.volume;
      tracked.recoveredAfterRestart = true;
      int size = ArraySize(g_tw2fTrades); ArrayResize(g_tw2fTrades, size + 1); g_tw2fTrades[size] = tracked;
     }
  }

void TW2FWriteSummary()
  {
   if(!TW2FIncludesNewBucket()) return;
   TW2FEnsureLogFolder();
   int handle = FileOpen(TW2FLogFileName("summary"), TW2FLogFlags(), ',');
   if(handle == INVALID_HANDLE) return;
   FileSeek(handle, 0, SEEK_END);
   if(FileSize(handle) == 0)
      FileWriteString(handle, "time,metric,value\r\n");
   string names[] = {"h4_prior_trend_candidates","h4_impulse_candidates","h4_impulses","h4_structure_breaks","h1_mature","h1_trendline_breaks",
                     "countertrend_structure","anchor_frozen","post_anchor_swing","equal_extreme","higher_low_or_lower_high","false_break_recovery","triple_extreme","failure_invalidated","continuation_failure","protected_break","ma_filter_reject","execution_pass","order",
                     "m15_pullbacks","m15_continuation_failures","m15_structure_breaks","pattern_reachability_tests_passed","pattern_reachability_tests_failed","m15_path_tests_passed","m15_path_tests_failed",
                     "shadow_started","shadow_countertrend_structure","shadow_anchor","shadow_anchor_before_origin_break","shadow_no_anchor_within_240","shadow_order_attempts",
                     "daily_stops","weekly_stops","hard_stops","total_risk_rejects","currency_risk_rejects"};
   long values[] = {g_tw2fH4PriorTrendCandidates,g_tw2fH4ImpulseCandidates,g_tw2fH4Impulses,g_tw2fH4StructureBreaks,g_tw2fH1Mature,g_tw2fH1TrendlineBreaks,
                    g_tw2fCountertrendStructure,g_tw2fAnchorFrozen,g_tw2fPostAnchorSwing,g_tw2fEqualExtreme,g_tw2fHigherLowOrLowerHigh,g_tw2fFalseBreakRecovery,g_tw2fTripleExtreme,g_tw2fFailureInvalidated,g_tw2fContinuationFailure,g_tw2fProtectedBreak,g_tw2fMAFilterReject,g_tw2fExecutionPass,g_tw2fOrders,
                    g_tw2fM15Pullbacks,g_tw2fM15Failures,g_tw2fM15Breaks,g_tw2fPatternReachabilityTestsPassed,g_tw2fPatternReachabilityTestsFailed,g_tw2fM15PathTestsPassed,g_tw2fM15PathTestsFailed,
                    g_tw2fShadowStarted,g_tw2fShadowCounterStructure,g_tw2fShadowAnchors,g_tw2fShadowAnchorsBeforeOriginBreak,g_tw2fShadowNoAnchorWithin240,g_tw2fShadowOrderAttempts,
                    g_tw2fDailyStopCount,g_tw2fWeeklyStopCount,g_tw2fHardStopCount,g_tw2fTotalRiskRejectCount,g_tw2fCurrencyRiskRejectCount};
   for(int i = 0; i < ArraySize(names); ++i)
      FileWrite(handle, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), names[i], values[i]);
   for(int i = 0; i < ArraySize(g_tw2fRejections); ++i)
      FileWrite(handle, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), "reject_" + g_tw2fRejections[i].reason, g_tw2fRejections[i].count);
   FileClose(handle);
  }

bool TW2FValidateInputs()
  {
   int contextSeconds = PeriodSeconds(InpContextTF);
   int setupSeconds = PeriodSeconds(InpSetupTF);
   int entrySeconds = PeriodSeconds(InpEntryTF);
   if(contextSeconds <= setupSeconds || setupSeconds <= entrySeconds || entrySeconds <= 0) return false;
   if(InpMAPeriod < 2 || InpATRPeriod < 2 || InpMASlopeConfirmationBars < 1 ||
      InpMinBarsBetweenSwings < 1 || InpImpulseLookbackBars < 20 ||
      InpMaximumImpulseWindowBars < 1 || InpMaximumImpulseWindowBars > 3 ||
      InpImpulsePercentile < 0.0 || InpImpulsePercentile > 100.0 ||
      InpTakeProfitR < InpMinimumPlannedRR || InpRiskPercent <= 0.0 ||
      InpTW2FMaxTotalOpenRiskPercent <= 0.0 || InpMaxOpenPositionsTotal < 1 ||
      InpTW2FMagicNumber <= 0 || InpTW2FMagicNumber == InpMagicNumber) return false;
   return true;
  }

bool TW2FInitialize()
  {
   if(!TW2FIncludesNewBucket()) return true;
   if(!TW2FValidateInputs()) return false;
   if(!TW2FRunM15PatternReachabilityTests()) return false;
   if(!TW2FRunM15EndToEndStateTests()) return false;
   int symbols = ArraySize(g_symbols);
   ArrayResize(g_tw2fClocks, symbols);
   ArrayResize(g_tw2fSetups, symbols * 2);
   for(int i = 0; i < symbols; ++i)
     {
      g_tw2fClocks[i].symbol = g_symbols[i];
      g_tw2fClocks[i].lastH4Bar = iTime(g_symbols[i], InpContextTF, 1);
      g_tw2fClocks[i].lastH1Bar = iTime(g_symbols[i], InpSetupTF, 1);
      g_tw2fClocks[i].lastM15Bar = iTime(g_symbols[i], InpEntryTF, 1);
      TW2FResetSetup(g_tw2fSetups[i * 2], g_symbols[i], 1);
      TW2FResetSetup(g_tw2fSetups[i * 2 + 1], g_symbols[i], -1);
     }
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   int today = DateKey(TimeCurrent()), thisWeek = TW2FWeekKey(TimeCurrent());
   int storedDay = (int)TW2FGlobalOr("daykey", today);
   int storedWeek = (int)TW2FGlobalOr("weekkey", thisWeek);
   g_tw2fPeakEquity = MathMax(equity, TW2FGlobalOr("peak", equity));
   g_tw2fDayKey = today;
   g_tw2fDayStartEquity = storedDay == today ? TW2FGlobalOr("dayeq", equity) : equity;
   g_tw2fDailyStopped = storedDay == today && TW2FGlobalOr("dstop", 0.0) > 0.5;
   g_tw2fWeekKey = thisWeek;
   g_tw2fWeekStartEquity = storedWeek == thisWeek ? TW2FGlobalOr("weekeq", equity) : equity;
   g_tw2fWeeklyStopped = storedWeek == thisWeek && TW2FGlobalOr("wstop", 0.0) > 0.5;
   g_tw2fHardStopped = TW2FGlobalOr("hstop", 0.0) > 0.5;
   TW2FPersistRiskState();
   TW2FEnsureLogFolder();
   TW2FRecoverPositions();
   return true;
  }

void TW2FScanSymbols()
  {
   if(!TW2FIncludesNewBucket()) return;
   TW2FUpdateRiskAnchors();
   TW2FManageTrades();
   for(int i = 0; i < ArraySize(g_tw2fClocks); ++i)
     {
      datetime h4 = iTime(g_tw2fClocks[i].symbol, InpContextTF, 1);
      datetime h1 = iTime(g_tw2fClocks[i].symbol, InpSetupTF, 1);
      datetime m15 = iTime(g_tw2fClocks[i].symbol, InpEntryTF, 1);
      if(h4 > 0 && h4 > g_tw2fClocks[i].lastH4Bar)
        { g_tw2fClocks[i].lastH4Bar = h4; TW2FProcessH4(i); }
      if(h1 > 0 && h1 > g_tw2fClocks[i].lastH1Bar)
        { g_tw2fClocks[i].lastH1Bar = h1; TW2FProcessH1(i); }
      if(m15 > 0 && m15 > g_tw2fClocks[i].lastM15Bar)
        { g_tw2fClocks[i].lastM15Bar = m15; TW2FProcessM15(i); }
     }
  }
