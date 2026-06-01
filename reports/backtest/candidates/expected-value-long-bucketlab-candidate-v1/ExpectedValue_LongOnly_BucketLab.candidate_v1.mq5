//+------------------------------------------------------------------+
//| ExpectedValue_LongOnly_BucketLab                                 |
//+------------------------------------------------------------------+
#property strict
#property version   "1.01"
#property description "Long-only USDJPY bucket lab using M1 execution under M5 quality and M15/H1/H4 context, with risk guards and relative diagnostics."

#include <Trade\Trade.mqh>

CTrade trade;

static const string STRATEGY_NAME = "ExpectedValue_LongOnly_BucketLab";
static const string EA_VERSION = "candidate_v1";

enum ENUM_BUCKET_SL_MODE
  {
   SL_ATR_ONLY = 0,
   SL_M1_SWING = 1,
   SL_M5_SWING = 2,
   SL_HYBRID = 3
  };

enum ENUM_BUCKET_TP_MODE
  {
   TP_FIXED_R = 0,
   TP_RECENT_HIGH_OR_R = 1
  };

input bool            InpEnableTrading              = false;
input string          InpSymbol                     = "USDJPY";
input ENUM_TIMEFRAMES InpExecutionTimeframe         = PERIOD_M1;
input ENUM_TIMEFRAMES InpQualityTimeframe           = PERIOD_M5;
input ENUM_TIMEFRAMES InpBiasTimeframe              = PERIOD_M15;
input ENUM_TIMEFRAMES InpTrendTimeframe             = PERIOD_H1;
input ENUM_TIMEFRAMES InpAvoidTimeframe             = PERIOD_H4;
input long            InpMagicNumber                = 2026051902;

input int             InpExecFastEMAPeriod          = 9;
input int             InpExecSlowEMAPeriod          = 34;
input int             InpFastEMAPeriod              = 13;
input int             InpSlowEMAPeriod              = 100;
input int             InpSlowSlopeBars              = 5;
input int             InpATRPeriod                  = 14;
input int             InpATRAveragePeriod           = 80;
input int             InpADXPeriod                  = 14;

input bool            InpUseSessionFilter           = false;
input int             InpSessionStartHour           = 7;
input int             InpSessionEndHour             = 22;
input string          InpAllowedWeekdays            = "1,2,3,4,5";

input double          InpFixedLot                   = 0.01;
input double          InpFixedLotEquityThreshold    = 300.0;
input double          InpRiskPercent                = 3.0;
input double          InpMaxLotCap                  = 1.0;

input double          InpDailyMaxLossPercent        = 10.0;
input double          InpWeeklyMaxLossPercent       = 20.0;
input double          InpMaxDrawdownPercent         = 35.0;
input int             InpMaxConsecutiveLosses       = 6;
input bool            InpLossStreakStopForDayOnly   = true;
input int             InpMaxOpenPositions           = 1;
input double          InpMaxTotalOpenRiskPercent    = 8.0;
input int             InpCooldownBars               = 6;
input bool            InpFlattenOnRiskStop          = true;

input ENUM_BUCKET_SL_MODE InpStopMode               = SL_HYBRID;
input ENUM_BUCKET_TP_MODE InpTPMode                 = TP_FIXED_R;
input double          InpTargetRMultiple            = 1.35;
input double          InpMinTargetRMultiple         = 1.15;
input int             InpM1SwingLookbackBars        = 10;
input int             InpM5SwingLookbackBars        = 10;
input double          InpStopATRMultiplier          = 0.90;
input double          InpM1SwingBufferATR           = 0.08;
input double          InpM5SwingBufferATR           = 0.12;
input double          InpMinStopATR                 = 0.45;
input double          InpMaxStopATR                 = 2.20;
input double          InpMinStopSpreadMultiple      = 3.00;
input int             InpMaxHoldBars                = 45;

input double          InpMaxSpreadATR               = 0.12;
input double          InpMaxEMADeviationATR         = 1.20;
input double          InpMinBodyATR                 = 0.00;
input double          InpMaxBodyATR                 = 0.75;
input double          InpMinATRRatio                = 0.65;
input double          InpMaxATRRatio                = 1.55;
input int             InpRangeLookbackBars          = 48;
input int             InpRecentRangeBars            = 18;
input double          InpMinRangePosition           = 0.55;
input double          InpMaxRangePosition           = 0.92;
input double          InpMinSlowSlopeATR            = -0.03;
input double          InpMaxADX                     = 35.0;

input bool            InpEnablePullbackScoreBucket  = true;
input double          InpPullbackScoreThreshold     = 6.20;
input double          InpCandidateLogMinScore       = 4.20;
input double          InpMinExtremeATRRatio         = 0.35;
input double          InpMaxExtremeATRRatio         = 2.80;
input double          InpScoreMinDiscountRangePos   = 0.25;
input double          InpScoreMaxDiscountRangePos   = 0.45;
input double          InpScoreDeepPullbackATR       = 0.80;
input double          InpScoreMinExpansionATRRatio  = 1.45;
input double          InpScoreMaxExpansionATRRatio  = 1.80;
input bool            InpEnableM1PullbackBucket     = true;
input bool            InpEnableBreakoutBucket       = true;
input int             InpMinBiasScore               = 2;
input double          InpH4MaxBearSlopeATR          = 0.12;
input double          InpH4MaxBelowSlowATR          = 0.60;
input double          InpPullbackTouchATR           = 0.18;
input double          InpPullbackMaxDepthATR        = 1.20;
input double          InpMinCloseLocation           = 0.56;
input double          InpMinLowerWickATR            = 0.03;
input double          InpMinLowerWickShare          = 0.18;
input double          InpBreakoutBufferATR          = 0.04;
input double          InpBreakoutMaxChaseATR        = 0.45;
input double          InpBreakoutRetestBufferATR    = 0.12;
input double          InpMinUpPressure              = 0.52;
input double          InpMaxDownPressure            = 0.48;

input bool            InpLogDiagnostics             = true;
input bool            InpLogNoSignalDiagnostics     = true;
input bool            InpLogCandidateScores         = true;
input string          InpPresetName                 = "candidate_v1";
input bool            InpUseCommonFiles             = true;
input string          InpEventLogFileName           = "mt5_company_expected_value_long_bucketlab_events.csv";
input string          InpSummaryFileName            = "mt5_company_expected_value_long_bucketlab_summary.csv";
input string          InpMonthlySummaryFileName     = "mt5_company_expected_value_long_bucketlab_monthly.csv";

struct TradePlan
  {
   bool     valid;
   string   bucket;
   string   entryReason;
   string   slMode;
   string   tpMode;
   datetime signalBarTime;
   double   entryPrice;
   double   stopLoss;
   double   takeProfit;
   double   riskDistance;
   double   rewardDistance;
   double   riskMoney;
   double   riskPercent;
   double   lot;
   double   marginRequired;
   double   freeMarginAfterEntry;
   double   riskDistancePips;
   double   candidateScore;
   double   spreadScore;
   double   volatilityScore;
   double   h4ContextScore;
   double   h1M15BiasScore;
   double   trendScore;
   double   pullbackScore;
   double   pressureScore;
   double   structureScore;
   double   rrScore;
   double   spreadToRisk;
   double   spreadToReward;
   double   riskDistanceATR;
   double   rewardDistanceATR;
   double   spreadATR;
   double   emaDeviationATR;
   double   bodyATR;
   double   wickATR;
   double   atrRatio;
   double   rangePosition;
   double   slowSlopeATR;
   double   adxValue;
   double   distanceRecentHighATR;
   double   distanceRecentLowATR;
   double   recentRangeATR;
   double   pullbackDepthATR;
   double   breakoutAcceptanceATR;
   double   upPressure;
   double   downPressure;
   int      hourOfDay;
   int      dayOfWeek;
   bool     fixedLotMode;
   bool     minLotForced;
  };

struct TrackedPosition
  {
   ulong    identifier;
   datetime entryTime;
   double   entryPrice;
   double   stopLoss;
   double   takeProfit;
   double   volume;
   double   riskMoney;
   string   bucket;
   string   entryReason;
   string   slMode;
   string   tpMode;
  };

struct PendingCloseReason
  {
   ulong  identifier;
   string reason;
  };

struct MonthStat
  {
   int    monthKey;
   int    trades;
   int    wins;
   int    losses;
   double netMoney;
   double netR;
   double grossWinR;
   double grossLossR;
  };

string runtimeSymbol = "";
string runtimeAllowedWeekdays = "";
bool allowedWeekdays[7];

int fastEmaHandle = INVALID_HANDLE;
int slowEmaHandle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;
int adxHandle = INVALID_HANDLE;
int qualityFastEmaHandle = INVALID_HANDLE;
int qualitySlowEmaHandle = INVALID_HANDLE;
int qualityAtrHandle = INVALID_HANDLE;
int qualityAdxHandle = INVALID_HANDLE;
int biasFastEmaHandle = INVALID_HANDLE;
int biasSlowEmaHandle = INVALID_HANDLE;
int biasAtrHandle = INVALID_HANDLE;
int trendFastEmaHandle = INVALID_HANDLE;
int trendSlowEmaHandle = INVALID_HANDLE;
int trendAtrHandle = INVALID_HANDLE;
int avoidFastEmaHandle = INVALID_HANDLE;
int avoidSlowEmaHandle = INVALID_HANDLE;
int avoidAtrHandle = INVALID_HANDLE;

datetime lastBarTime = 0;
datetime lastEntryBarTime = 0;
datetime currentDayStart = 0;
int currentDayKey = -1;
int currentWeekKey = -1;

double dayStartEquity = 0.0;
double weekStartEquity = 0.0;
double accountPeakEquity = 0.0;
bool dailyStopActive = false;
bool weeklyStopActive = false;
bool drawdownStopActive = false;
bool lossStreakStopActive = false;
string dailyStopReason = "";
string weeklyStopReason = "";
string drawdownStopReason = "";
string lossStreakStopReason = "";

int consecutiveLosses = 0;
int observedMaxConsecutiveLosses = 0;
int totalClosedTrades = 0;
int totalWins = 0;
int totalLosses = 0;
double totalNetMoney = 0.0;
double totalR = 0.0;
double grossWinR = 0.0;
double grossLossR = 0.0;
double equityCurveR = 0.0;
double equityPeakR = 0.0;
double maxDrawdownR = 0.0;
double maxDrawdownPercent = 0.0;

int dailySignals = 0;
int dailyEntries = 0;
int dailyRejects = 0;
int dailyRiskBlocks = 0;
int dailyClosedTrades = 0;

int eventLogHandle = INVALID_HANDLE;

TrackedPosition trackedPositions[];
PendingCloseReason pendingCloseReasons[];
MonthStat monthStats[];

double pendingEntryRiskMoney = 0.0;
double pendingEntrySL = 0.0;
double pendingEntryTP = 0.0;
double pendingEntryVolume = 0.0;
string pendingEntryBucket = "";
string pendingEntryReason = "";
string pendingEntrySLMode = "";
string pendingEntryTPMode = "";

string TrimSpaces(string value)
  {
   int start = 0;
   int finish = StringLen(value) - 1;
   while(start <= finish && StringGetCharacter(value, start) <= 32)
      start++;
   while(finish >= start && StringGetCharacter(value, finish) <= 32)
      finish--;
   if(finish < start)
      return "";
   return StringSubstr(value, start, finish - start + 1);
  }

string CleanPresetString(string value)
  {
   string cleaned = value;
   int marker = StringFind(cleaned, "||");
   if(marker >= 0)
      cleaned = StringSubstr(cleaned, 0, marker);
   return TrimSpaces(cleaned);
  }

bool ParseAllowedWeekdays()
  {
   for(int i = 0; i < 7; ++i)
      allowedWeekdays[i] = false;

   string text = CleanPresetString(runtimeAllowedWeekdays);
   if(text == "")
      return false;

   string parts[];
   int count = StringSplit(text, ',', parts);
   if(count <= 0)
      return false;
   for(int i = 0; i < count; ++i)
     {
      int day = (int)StringToInteger(TrimSpaces(parts[i]));
      if(day < 0 || day > 6)
         return false;
      allowedWeekdays[day] = true;
     }
   return true;
  }

bool IsAllowedWeekday(datetime stamp)
  {
   MqlDateTime dt;
   TimeToStruct(stamp, dt);
   return allowedWeekdays[dt.day_of_week];
  }

bool IsWithinSession(datetime stamp, int startHour, int endHour)
  {
   MqlDateTime dt;
   TimeToStruct(stamp, dt);
   if(startHour == endHour)
      return true;
   if(startHour < endHour)
      return (dt.hour >= startHour && dt.hour < endHour);
   return (dt.hour >= startHour || dt.hour < endHour);
  }

string BoolWord(bool value)
  {
   return value ? "true" : "false";
  }

double ClampDouble(double value, double low, double high)
  {
   if(value < low)
      return low;
   if(value > high)
      return high;
   return value;
  }

double ScoreBand(double value, double idealLow, double idealHigh, double softLow, double softHigh)
  {
   if(value >= idealLow && value <= idealHigh)
      return 1.0;
   if(value >= softLow && value <= softHigh)
      return 0.55;
   return 0.0;
  }

double ScoreMin(double value, double idealMin, double softMin)
  {
   if(value >= idealMin)
      return 1.0;
   if(value >= softMin)
      return 0.55;
   return 0.0;
  }

double ScoreMax(double value, double idealMax, double softMax)
  {
   if(value <= idealMax)
      return 1.0;
   if(value <= softMax)
      return 0.55;
   return 0.0;
  }

string TimeframeText()
  {
   return EnumToString(InpExecutionTimeframe) + "|quality=" + EnumToString(InpQualityTimeframe);
  }

int DayKey(datetime stamp)
  {
   MqlDateTime dt;
   TimeToStruct(stamp, dt);
   return dt.year * 1000 + dt.day_of_year;
  }

int WeekKey(datetime stamp)
  {
   MqlDateTime dt;
   TimeToStruct(stamp, dt);
   int week = (dt.day_of_year + 6) / 7;
   return dt.year * 100 + week;
  }

int MonthKey(datetime stamp)
  {
   MqlDateTime dt;
   TimeToStruct(stamp, dt);
   return dt.year * 100 + dt.mon;
  }

double PointValue()
  {
   return SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
  }

double PipSize()
  {
   double point = PointValue();
   int digits = SymbolDigits();
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

int SymbolDigits()
  {
   return (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_DIGITS);
  }

double CurrentBid()
  {
   return SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
  }

double CurrentAsk()
  {
   return SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
  }

double CloseLocation(const MqlRates &bar)
  {
   double range = bar.high - bar.low;
   if(range <= 0.0)
      return 0.5;
   return (bar.close - bar.low) / range;
  }

double UpperWickShare(const MqlRates &bar)
  {
   double range = bar.high - bar.low;
   if(range <= 0.0)
      return 0.0;
   return (bar.high - MathMax(bar.open, bar.close)) / range;
  }

double LowerWickShare(const MqlRates &bar)
  {
   double range = bar.high - bar.low;
   if(range <= 0.0)
      return 0.0;
   return (MathMin(bar.open, bar.close) - bar.low) / range;
  }

bool OpenEventLog()
  {
   if(!InpLogDiagnostics)
      return true;
   if(eventLogHandle != INVALID_HANDLE)
      return true;

   string fileName = CleanPresetString(InpEventLogFileName);
   int flags = FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;
   eventLogHandle = FileOpen(fileName, flags, ';');
   if(eventLogHandle == INVALID_HANDLE)
     {
      PrintFormat("%s event log open failed: %s err=%d", STRATEGY_NAME, fileName, GetLastError());
      return false;
     }

   if(FileSize(eventLogHandle) == 0)
     {
      FileWrite(eventLogHandle,
                "time", "event", "reason", "symbol", "timeframe",
                 "preset_name", "ea_version", "bucket",
                 "entry_reason", "sl_mode", "tp_mode", "equity", "balance",
                 "price", "sl", "tp", "lot", "risk_money", "risk_percent",
                 "risk_percent_of_equity", "min_lot_forced",
                 "risk_distance_pips", "free_margin_after_entry",
                 "candidate_score", "spread_score", "volatility_score",
                 "h4_context_score", "h1_m15_bias_score", "trend_score",
                 "pullback_score", "pressure_score", "structure_score",
                 "rr_score", "spread_to_risk", "spread_to_reward",
                 "risk_distance_atr", "reward_distance_atr",
                 "spread_atr", "ema_deviation_atr", "body_atr", "wick_atr",
                 "atr_ratio", "range_position", "slow_slope_atr", "adx",
                "distance_recent_high_atr", "distance_recent_low_atr",
                "recent_range_atr", "pullback_depth_atr",
                "breakout_acceptance_atr", "up_pressure", "down_pressure",
                "hour", "day_of_week", "open_positions",
                "total_open_risk_percent", "consecutive_losses", "detail");
     }
   FileSeek(eventLogHandle, 0, SEEK_END);
   return true;
  }

void CloseEventLog()
  {
   if(eventLogHandle != INVALID_HANDLE)
     {
      FileFlush(eventLogHandle);
      FileClose(eventLogHandle);
      eventLogHandle = INVALID_HANDLE;
     }
  }

void LogEvent(string eventName,
              string reason,
              const TradePlan &plan,
              string detail)
  {
   if(!InpLogDiagnostics)
      return;
   if(!OpenEventLog())
      return;

   FileWrite(eventLogHandle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             eventName,
              reason,
              runtimeSymbol,
              TimeframeText(),
              CleanPresetString(InpPresetName),
              EA_VERSION,
              plan.bucket,
             plan.entryReason,
             plan.slMode,
             plan.tpMode,
             AccountInfoDouble(ACCOUNT_EQUITY),
             AccountInfoDouble(ACCOUNT_BALANCE),
             plan.entryPrice,
             plan.stopLoss,
             plan.takeProfit,
               plan.lot,
               plan.riskMoney,
               plan.riskPercent,
               plan.riskPercent,
               BoolWord(plan.minLotForced),
               plan.riskDistancePips,
               plan.freeMarginAfterEntry,
               plan.candidateScore,
              plan.spreadScore,
              plan.volatilityScore,
              plan.h4ContextScore,
              plan.h1M15BiasScore,
              plan.trendScore,
              plan.pullbackScore,
              plan.pressureScore,
              plan.structureScore,
              plan.rrScore,
              plan.spreadToRisk,
              plan.spreadToReward,
              plan.riskDistanceATR,
              plan.rewardDistanceATR,
              plan.spreadATR,
              plan.emaDeviationATR,
             plan.bodyATR,
             plan.wickATR,
             plan.atrRatio,
             plan.rangePosition,
             plan.slowSlopeATR,
             plan.adxValue,
             plan.distanceRecentHighATR,
             plan.distanceRecentLowATR,
             plan.recentRangeATR,
             plan.pullbackDepthATR,
             plan.breakoutAcceptanceATR,
             plan.upPressure,
             plan.downPressure,
             plan.hourOfDay,
             plan.dayOfWeek,
             CountManagedPositions(),
             CurrentTotalOpenRiskPercent(),
             consecutiveLosses,
             detail);
   FileFlush(eventLogHandle);
  }

void LogSimpleEvent(string eventName, string reason, string detail)
  {
   TradePlan empty;
   ZeroMemory(empty);
   empty.bucket = "";
   LogEvent(eventName, reason, empty, detail);
  }

void LogCandidateScore(const TradePlan &plan, bool wouldEnter, string rejectReason)
  {
   if(!InpLogCandidateScores)
      return;
   if(!wouldEnter && plan.candidateScore < InpCandidateLogMinScore)
      return;

   string detail =
      "candidate_time=" + TimeToString(plan.signalBarTime, TIME_DATE | TIME_SECONDS) +
      "|score_components=spread:" + DoubleToString(plan.spreadScore, 3) +
      ",volatility:" + DoubleToString(plan.volatilityScore, 3) +
      ",h4:" + DoubleToString(plan.h4ContextScore, 3) +
      ",bias:" + DoubleToString(plan.h1M15BiasScore, 3) +
      ",trend:" + DoubleToString(plan.trendScore, 3) +
      ",pullback:" + DoubleToString(plan.pullbackScore, 3) +
      ",pressure:" + DoubleToString(plan.pressureScore, 3) +
      ",structure:" + DoubleToString(plan.structureScore, 3) +
      ",rr:" + DoubleToString(plan.rrScore, 3) +
      "|would_enter=" + BoolWord(wouldEnter) +
      "|reject_reason=" + rejectReason +
      "|proposed_sl=" + DoubleToString(plan.stopLoss, SymbolDigits()) +
      "|proposed_tp=" + DoubleToString(plan.takeProfit, SymbolDigits());
   LogEvent("candidate_score", rejectReason, plan, detail);
  }

void ResetDayState(datetime now)
  {
   currentDayKey = DayKey(now);
   MqlDateTime dt;
   TimeToStruct(now, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   currentDayStart = StructToTime(dt);
   dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   dailyStopActive = false;
   dailyStopReason = "";
   dailySignals = 0;
   dailyEntries = 0;
   dailyRejects = 0;
   dailyRiskBlocks = 0;
   dailyClosedTrades = 0;
   if(InpLossStreakStopForDayOnly)
     {
      lossStreakStopActive = false;
      lossStreakStopReason = "";
     }
   LogSimpleEvent("period_reset", "day_reset", "day_start_equity=" + DoubleToString(dayStartEquity, 2));
  }

void ResetWeekState(datetime now)
  {
   currentWeekKey = WeekKey(now);
   weekStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   weeklyStopActive = false;
   weeklyStopReason = "";
   LogSimpleEvent("period_reset", "week_reset", "week_start_equity=" + DoubleToString(weekStartEquity, 2));
  }

void UpdatePeriodAnchors()
  {
   datetime now = TimeCurrent();
   int dayKey = DayKey(now);
   int weekKey = WeekKey(now);
   if(currentDayKey != dayKey)
      ResetDayState(now);
   if(currentWeekKey != weekKey)
      ResetWeekState(now);
  }

void UpdateDrawdown()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(accountPeakEquity <= 0.0 || equity > accountPeakEquity)
      accountPeakEquity = equity;

   double currentDDPercent = 0.0;
   if(accountPeakEquity > 0.0)
      currentDDPercent = 100.0 * (accountPeakEquity - equity) / accountPeakEquity;
   if(currentDDPercent > maxDrawdownPercent)
      maxDrawdownPercent = currentDDPercent;
  }

void AddPendingCloseReason(ulong identifier, string reason)
  {
   int size = ArraySize(pendingCloseReasons);
   for(int i = 0; i < size; ++i)
     {
      if(pendingCloseReasons[i].identifier == identifier)
        {
         pendingCloseReasons[i].reason = reason;
         return;
        }
     }
   ArrayResize(pendingCloseReasons, size + 1);
   pendingCloseReasons[size].identifier = identifier;
   pendingCloseReasons[size].reason = reason;
  }

string PopPendingCloseReason(ulong identifier)
  {
   int size = ArraySize(pendingCloseReasons);
   for(int i = 0; i < size; ++i)
     {
      if(pendingCloseReasons[i].identifier != identifier)
         continue;
      string reason = pendingCloseReasons[i].reason;
      for(int j = i; j < size - 1; ++j)
         pendingCloseReasons[j] = pendingCloseReasons[j + 1];
      ArrayResize(pendingCloseReasons, size - 1);
      return reason;
     }
   return "";
  }

int FindTrackedPositionIndex(ulong identifier)
  {
   int size = ArraySize(trackedPositions);
   for(int i = 0; i < size; ++i)
      if(trackedPositions[i].identifier == identifier)
         return i;
   return -1;
  }

void AddTrackedPosition(ulong identifier, datetime entryTime, double entryPrice, double volume)
  {
   if(identifier == 0)
      return;
   int index = FindTrackedPositionIndex(identifier);
   if(index < 0)
     {
      int size = ArraySize(trackedPositions);
      ArrayResize(trackedPositions, size + 1);
      index = size;
     }

   trackedPositions[index].identifier = identifier;
   trackedPositions[index].entryTime = entryTime;
   trackedPositions[index].entryPrice = entryPrice;
   trackedPositions[index].stopLoss = pendingEntrySL;
   trackedPositions[index].takeProfit = pendingEntryTP;
   trackedPositions[index].volume = volume;
   trackedPositions[index].riskMoney = pendingEntryRiskMoney;
   trackedPositions[index].bucket = pendingEntryBucket;
   trackedPositions[index].entryReason = pendingEntryReason;
   trackedPositions[index].slMode = pendingEntrySLMode;
   trackedPositions[index].tpMode = pendingEntryTPMode;
  }

TrackedPosition RemoveTrackedPosition(ulong identifier)
  {
   TrackedPosition result;
   ZeroMemory(result);
   int index = FindTrackedPositionIndex(identifier);
   if(index < 0)
      return result;

   int size = ArraySize(trackedPositions);
   result = trackedPositions[index];
   for(int i = index; i < size - 1; ++i)
      trackedPositions[i] = trackedPositions[i + 1];
   ArrayResize(trackedPositions, size - 1);
   return result;
  }

int EnsureMonthStat(int monthKey)
  {
   int size = ArraySize(monthStats);
   for(int i = 0; i < size; ++i)
      if(monthStats[i].monthKey == monthKey)
         return i;
   ArrayResize(monthStats, size + 1);
   monthStats[size].monthKey = monthKey;
   monthStats[size].trades = 0;
   monthStats[size].wins = 0;
   monthStats[size].losses = 0;
   monthStats[size].netMoney = 0.0;
   monthStats[size].netR = 0.0;
   monthStats[size].grossWinR = 0.0;
   monthStats[size].grossLossR = 0.0;
   return size;
  }

void UpdateMonthlyStats(datetime closeTime, double netMoney, double realizedR)
  {
   int index = EnsureMonthStat(MonthKey(closeTime));
   monthStats[index].trades++;
   monthStats[index].netMoney += netMoney;
   monthStats[index].netR += realizedR;
   if(realizedR > 0.0)
     {
      monthStats[index].wins++;
      monthStats[index].grossWinR += realizedR;
     }
   else if(realizedR < 0.0)
     {
      monthStats[index].losses++;
      monthStats[index].grossLossR += realizedR;
     }
  }

double CalculateRiskMoney(ENUM_ORDER_TYPE orderType, double volume, double entryPrice, double stopLoss)
  {
   double profit = 0.0;
   if(!OrderCalcProfit(orderType, runtimeSymbol, volume, entryPrice, stopLoss, profit))
      return 0.0;
   return MathAbs(profit);
  }

double NormalizeVolumeToBroker(double volume)
  {
   double minLot = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0)
      step = minLot;

   double cap = maxLot;
   if(InpMaxLotCap > 0.0)
      cap = MathMin(cap, InpMaxLotCap);

   volume = MathMax(volume, minLot);
   volume = MathMin(volume, cap);
   double steps = MathFloor((volume - minLot + 0.000000001) / step);
   double normalized = minLot + steps * step;
   if(normalized < minLot)
      normalized = minLot;
   if(normalized > cap)
      normalized = cap;
   return NormalizeDouble(normalized, 8);
  }

bool CalculateVolume(TradePlan &plan, string &rejectReason)
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskPerLot = CalculateRiskMoney(ORDER_TYPE_BUY, 1.0, plan.entryPrice, plan.stopLoss);
   if(riskPerLot <= 0.0)
     {
      rejectReason = "risk_per_lot_failed";
      return false;
     }

   double requestedVolume = 0.0;
   plan.fixedLotMode = (equity <= InpFixedLotEquityThreshold);
   if(plan.fixedLotMode)
      requestedVolume = InpFixedLot;
   else
      requestedVolume = (equity * InpRiskPercent / 100.0) / riskPerLot;

   double minLot = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_MIN);
   plan.minLotForced = (requestedVolume > 0.0 && requestedVolume < minLot);
   plan.lot = NormalizeVolumeToBroker(requestedVolume);
   if(plan.lot <= 0.0)
     {
      rejectReason = "lot_normalization_failed";
      return false;
     }

   plan.riskMoney = CalculateRiskMoney(ORDER_TYPE_BUY, plan.lot, plan.entryPrice, plan.stopLoss);
   if(plan.riskMoney <= 0.0)
     {
      rejectReason = "planned_risk_failed";
      return false;
     }
   plan.riskPercent = equity > 0.0 ? 100.0 * plan.riskMoney / equity : 0.0;

   if(!OrderCalcMargin(ORDER_TYPE_BUY, runtimeSymbol, plan.lot, plan.entryPrice, plan.marginRequired))
     {
      rejectReason = "margin_calc_failed";
      return false;
     }
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    plan.freeMarginAfterEntry = freeMargin - plan.marginRequired;
    if(plan.marginRequired > freeMargin)
      {
       rejectReason = "margin_insufficient";
      return false;
     }
   return true;
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
      if(PositionGetString(POSITION_SYMBOL) != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      count++;
     }
   return count;
  }

bool HasLosingManagedLong()
  {
   int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;
      if(PositionGetDouble(POSITION_PROFIT) < 0.0)
         return true;
     }
   return false;
  }

double CurrentTotalOpenRiskMoney()
  {
   double totalRisk = 0.0;
   int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type != POSITION_TYPE_BUY)
         continue;
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double stop = PositionGetDouble(POSITION_SL);
      double volume = PositionGetDouble(POSITION_VOLUME);
      if(stop <= 0.0 || stop >= entry)
         continue;
      totalRisk += CalculateRiskMoney(ORDER_TYPE_BUY, volume, entry, stop);
     }
   return totalRisk;
  }

double CurrentTotalOpenRiskPercent()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0)
      return 0.0;
   return 100.0 * CurrentTotalOpenRiskMoney() / equity;
  }

void TriggerStop(string scope, string reason, string detail)
  {
   if(scope == "daily")
     {
      if(dailyStopActive)
         return;
      dailyStopActive = true;
      dailyStopReason = reason;
     }
   else if(scope == "weekly")
     {
      if(weeklyStopActive)
         return;
      weeklyStopActive = true;
      weeklyStopReason = reason;
     }
   else if(scope == "drawdown")
     {
      if(drawdownStopActive)
         return;
      drawdownStopActive = true;
      drawdownStopReason = reason;
     }
   else if(scope == "loss_streak")
     {
      if(lossStreakStopActive)
         return;
      lossStreakStopActive = true;
      lossStreakStopReason = reason;
     }

   string message = STRATEGY_NAME + " STOP " + scope + " " + reason + " " + detail;
   Print(message);
   LogSimpleEvent("stop_condition_triggered", reason, detail);
  }

void CloseManagedPositionByTicket(ulong ticket, string reason)
  {
   if(ticket == 0)
      return;
   if(!PositionSelectByTicket(ticket))
      return;
   ulong identifier = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
   AddPendingCloseReason(identifier, reason);
   if(!trade.PositionClose(ticket))
     {
      PrintFormat("%s position close failed ticket=%I64u reason=%s retcode=%d",
                  STRATEGY_NAME, ticket, reason, trade.ResultRetcode());
      LogSimpleEvent("close_failed", reason, "ticket=" + (string)ticket + " retcode=" + (string)trade.ResultRetcode());
     }
  }

void FlattenManagedPositions(string reason)
  {
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      CloseManagedPositionByTicket(ticket, reason);
     }
  }

void CheckRiskStops()
  {
   UpdateDrawdown();
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(InpDailyMaxLossPercent > 0.0 && dayStartEquity > 0.0)
     {
      double dailyLossPercent = 100.0 * (dayStartEquity - equity) / dayStartEquity;
      if(dailyLossPercent >= InpDailyMaxLossPercent)
        {
         TriggerStop("daily", "daily_max_loss", "daily_loss_percent=" + DoubleToString(dailyLossPercent, 4));
         if(InpFlattenOnRiskStop)
            FlattenManagedPositions("RISK_STOP");
        }
     }

   if(InpWeeklyMaxLossPercent > 0.0 && weekStartEquity > 0.0)
     {
      double weeklyLossPercent = 100.0 * (weekStartEquity - equity) / weekStartEquity;
      if(weeklyLossPercent >= InpWeeklyMaxLossPercent)
        {
         TriggerStop("weekly", "weekly_max_loss", "weekly_loss_percent=" + DoubleToString(weeklyLossPercent, 4));
         if(InpFlattenOnRiskStop)
            FlattenManagedPositions("RISK_STOP");
        }
     }

   if(InpMaxDrawdownPercent > 0.0 && accountPeakEquity > 0.0)
     {
      double ddPercent = 100.0 * (accountPeakEquity - equity) / accountPeakEquity;
      if(ddPercent >= InpMaxDrawdownPercent)
        {
         TriggerStop("drawdown", "max_drawdown", "drawdown_percent=" + DoubleToString(ddPercent, 4));
         if(InpFlattenOnRiskStop)
            FlattenManagedPositions("RISK_STOP");
        }
     }
  }

bool IsCooldownBlocked(datetime barTime)
  {
   if(InpCooldownBars <= 0 || lastEntryBarTime <= 0)
      return false;
   int barsSince = iBarShift(runtimeSymbol, InpExecutionTimeframe, lastEntryBarTime, false);
   if(barsSince < 0)
      return false;
   return (barsSince < InpCooldownBars);
  }

bool LoadMarketData(MqlRates &execRates[],
                    double &execFastEma[],
                    double &execSlowEma[],
                    double &execAtr[],
                    MqlRates &qualityRates[],
                    double &qualityFastEma[],
                    double &qualitySlowEma[],
                    double &qualityAtr[],
                    double &qualityAdx[])
  {
   int needExecBars = MathMax(InpExecSlowEMAPeriod + 10,
                              MathMax(InpM1SwingLookbackBars, InpRecentRangeBars) + 12);
   int needQualityBars = MathMax(InpSlowEMAPeriod + InpSlowSlopeBars + 10,
                                 MathMax(InpATRAveragePeriod + InpATRPeriod + 10,
                                         MathMax(InpRangeLookbackBars, MathMax(InpM5SwingLookbackBars, InpRecentRangeBars)) + 10));
   ArraySetAsSeries(execRates, true);
   ArraySetAsSeries(execFastEma, true);
   ArraySetAsSeries(execSlowEma, true);
   ArraySetAsSeries(execAtr, true);
   ArraySetAsSeries(qualityRates, true);
   ArraySetAsSeries(qualityFastEma, true);
   ArraySetAsSeries(qualitySlowEma, true);
   ArraySetAsSeries(qualityAtr, true);
   ArraySetAsSeries(qualityAdx, true);

   if(CopyRates(runtimeSymbol, InpExecutionTimeframe, 0, needExecBars, execRates) < needExecBars)
      return false;
   if(CopyBuffer(fastEmaHandle, 0, 0, needExecBars, execFastEma) < needExecBars)
      return false;
   if(CopyBuffer(slowEmaHandle, 0, 0, needExecBars, execSlowEma) < needExecBars)
      return false;
   if(CopyBuffer(atrHandle, 0, 0, needExecBars, execAtr) < needExecBars)
      return false;
   if(CopyRates(runtimeSymbol, InpQualityTimeframe, 0, needQualityBars, qualityRates) < needQualityBars)
      return false;
   if(CopyBuffer(qualityFastEmaHandle, 0, 0, needQualityBars, qualityFastEma) < needQualityBars)
      return false;
   if(CopyBuffer(qualitySlowEmaHandle, 0, 0, needQualityBars, qualitySlowEma) < needQualityBars)
      return false;
   if(CopyBuffer(qualityAtrHandle, 0, 0, needQualityBars, qualityAtr) < needQualityBars)
      return false;
   if(CopyBuffer(qualityAdxHandle, 0, 0, needQualityBars, qualityAdx) < needQualityBars)
      return false;
   return true;
  }

double AverageATR(const double &atr[])
  {
   double sum = 0.0;
   int count = 0;
   int size = ArraySize(atr);
   int limit = MathMin(InpATRAveragePeriod, size - 2);
   for(int i = 1; i <= limit; ++i)
     {
      if(atr[i] <= 0.0)
         continue;
      sum += atr[i];
      count++;
     }
   if(count <= 0)
      return 0.0;
   return sum / count;
  }

bool RecentRangePosition(const MqlRates &rates[], double &position)
  {
   int size = ArraySize(rates);
   int limit = MathMin(InpRangeLookbackBars, size - 2);
   if(limit < 5)
      return false;
   double highest = rates[1].high;
   double lowest = rates[1].low;
   for(int i = 1; i <= limit; ++i)
     {
      highest = MathMax(highest, rates[i].high);
      lowest = MathMin(lowest, rates[i].low);
     }
   double width = highest - lowest;
   if(width <= 0.0)
      return false;
   position = (rates[1].close - lowest) / width;
   return true;
  }

double RecentSwingLow(const MqlRates &rates[], int lookbackBars)
  {
   int size = ArraySize(rates);
   int limit = MathMin(lookbackBars, size - 2);
   double lowest = rates[1].low;
   for(int i = 1; i <= limit; ++i)
      lowest = MathMin(lowest, rates[i].low);
   return lowest;
  }

double RecentHighestHigh(const MqlRates &rates[], int lookbackBars, int startShift)
  {
   int size = ArraySize(rates);
   int limit = MathMin(startShift + lookbackBars - 1, size - 2);
   if(startShift > limit)
      return 0.0;
   double highest = rates[startShift].high;
   for(int i = startShift; i <= limit; ++i)
      highest = MathMax(highest, rates[i].high);
   return highest;
  }

double RecentLowestLow(const MqlRates &rates[], int lookbackBars, int startShift)
  {
   int size = ArraySize(rates);
   int limit = MathMin(startShift + lookbackBars - 1, size - 2);
   if(startShift > limit)
      return 0.0;
   double lowest = rates[startShift].low;
   for(int i = startShift; i <= limit; ++i)
      lowest = MathMin(lowest, rates[i].low);
   return lowest;
  }

bool RecentRangeStats(const MqlRates &rates[],
                      int lookbackBars,
                      double currentATR,
                      double &distanceHighATR,
                      double &distanceLowATR,
                      double &rangeATR)
  {
   if(currentATR <= 0.0)
      return false;
   double highest = RecentHighestHigh(rates, lookbackBars, 1);
   double lowest = RecentLowestLow(rates, lookbackBars, 1);
   if(highest <= 0.0 || lowest <= 0.0 || highest <= lowest)
      return false;
   double close = rates[1].close;
   distanceHighATR = (highest - close) / currentATR;
   distanceLowATR = (close - lowest) / currentATR;
   rangeATR = (highest - lowest) / currentATR;
   return true;
  }

bool DirectionalPressure(const MqlRates &rates[], int lookbackBars, double &upPressure, double &downPressure)
  {
   int size = ArraySize(rates);
   int limit = MathMin(lookbackBars, size - 2);
   if(limit < 3)
      return false;

   double upMove = 0.0;
   double downMove = 0.0;
   for(int i = 1; i <= limit; ++i)
     {
      double delta = rates[i].close - rates[i + 1].close;
      if(delta > 0.0)
         upMove += delta;
      else
         downMove += MathAbs(delta);
     }
   double total = upMove + downMove;
   if(total <= 0.0)
     {
      upPressure = 0.5;
      downPressure = 0.5;
      return true;
     }
   upPressure = upMove / total;
   downPressure = downMove / total;
   return true;
  }

string StopModeText()
  {
   if(InpStopMode == SL_ATR_ONLY)
      return "ATR_ONLY";
   if(InpStopMode == SL_M1_SWING)
      return "M1_SWING";
   if(InpStopMode == SL_M5_SWING)
      return "M5_SWING";
   return "HYBRID";
  }

string TPModeText()
  {
   if(InpTPMode == TP_RECENT_HIGH_OR_R)
      return "RECENT_HIGH_OR_R";
   return "FIXED_R";
  }

bool LoadContextFrame(ENUM_TIMEFRAMES timeframe,
                      int fastHandle,
                      int slowHandle,
                      int atrHandleParam,
                      MqlRates &rates[],
                      double &fastEma[],
                      double &slowEma[],
                      double &atr[])
  {
   int needBars = MathMax(InpSlowEMAPeriod + InpSlowSlopeBars + 10, InpATRPeriod + 10);
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(fastEma, true);
   ArraySetAsSeries(slowEma, true);
   ArraySetAsSeries(atr, true);
   if(CopyRates(runtimeSymbol, timeframe, 0, needBars, rates) < needBars)
      return false;
   if(CopyBuffer(fastHandle, 0, 0, needBars, fastEma) < needBars)
      return false;
   if(CopyBuffer(slowHandle, 0, 0, needBars, slowEma) < needBars)
      return false;
   if(CopyBuffer(atrHandleParam, 0, 0, needBars, atr) < needBars)
      return false;
   return true;
  }

int BiasScore(const MqlRates &rates[], const double &fastEma[], const double &slowEma[], const double &atr[])
  {
   if(ArraySize(rates) <= InpSlowSlopeBars + 1 || ArraySize(atr) <= 1 || atr[1] <= 0.0)
      return 0;
   int score = 0;
   double slopeATR = (slowEma[1] - slowEma[1 + InpSlowSlopeBars]) / atr[1];
   if(rates[1].close >= slowEma[1])
      score++;
   if(fastEma[1] >= slowEma[1])
      score++;
   if(slopeATR >= InpMinSlowSlopeATR)
      score++;
   return score;
  }

double H4ContextScore(const MqlRates &rates[], const double &fastEma[], const double &slowEma[], const double &atr[])
  {
   if(ArraySize(rates) <= InpSlowSlopeBars + 1 || ArraySize(atr) <= 1 || atr[1] <= 0.0)
      return 0.0;

   double slopeATR = (slowEma[1] - slowEma[1 + InpSlowSlopeBars]) / atr[1];
   double belowSlowATR = (slowEma[1] - rates[1].close) / atr[1];
   bool strongBear = (fastEma[1] < slowEma[1] &&
                      slopeATR < -InpH4MaxBearSlopeATR &&
                      belowSlowATR > InpH4MaxBelowSlowATR);
   if(strongBear)
      return 0.15;
   if(rates[1].close < slowEma[1] || fastEma[1] < slowEma[1])
      return 0.55;
   if(slopeATR < InpMinSlowSlopeATR)
      return 0.75;
   return 1.0;
  }

bool AvoidFrameIsStrongBearish()
  {
   MqlRates rates[];
   double fastEma[];
   double slowEma[];
   double atr[];
   if(!LoadContextFrame(InpAvoidTimeframe, avoidFastEmaHandle, avoidSlowEmaHandle, avoidAtrHandle,
                        rates, fastEma, slowEma, atr))
      return true;
   if(atr[1] <= 0.0)
      return true;
   double slopeATR = (slowEma[1] - slowEma[1 + InpSlowSlopeBars]) / atr[1];
   double belowSlowATR = (slowEma[1] - rates[1].close) / atr[1];
   return (fastEma[1] < slowEma[1] &&
           slopeATR < -InpH4MaxBearSlopeATR &&
           belowSlowATR > InpH4MaxBelowSlowATR);
  }

void ResetPlan(TradePlan &plan)
  {
   ZeroMemory(plan);
   plan.valid = false;
   plan.bucket = "";
  }

bool BuildTradePlan(TradePlan &plan, string &rejectReason)
  {
   ResetPlan(plan);

   MqlRates execRates[];
   double execFastEma[];
   double execSlowEma[];
   double execAtr[];
   MqlRates qualityRates[];
   double qualityFastEma[];
   double qualitySlowEma[];
   double qualityAtr[];
   double qualityAdx[];
   if(!LoadMarketData(execRates, execFastEma, execSlowEma, execAtr,
                      qualityRates, qualityFastEma, qualitySlowEma, qualityAtr, qualityAdx))
     {
      rejectReason = "market_data_unavailable";
      return false;
     }

   MqlRates signalBar = execRates[1];
   MqlRates qualityBar = qualityRates[1];
   plan.signalBarTime = signalBar.time;
   plan.slMode = StopModeText();
   plan.tpMode = TPModeText();
   MqlDateTime signalDt;
   TimeToStruct(signalBar.time, signalDt);
   plan.hourOfDay = signalDt.hour;
   plan.dayOfWeek = signalDt.day_of_week;
   plan.entryPrice = CurrentAsk();
   if(plan.entryPrice <= 0.0)
     {
      rejectReason = "ask_unavailable";
      return false;
     }

   if(!IsAllowedWeekday(signalBar.time))
     {
      rejectReason = "weekday_filter_failed";
      return false;
     }
   if(InpUseSessionFilter && !IsWithinSession(signalBar.time, InpSessionStartHour, InpSessionEndHour))
     {
      rejectReason = "session_filter_failed";
      return false;
     }

   double currentATR = qualityAtr[1];
   if(currentATR <= 0.0)
     {
      rejectReason = "atr_unavailable";
      return false;
     }

   double atrAverage = AverageATR(qualityAtr);
   if(atrAverage <= 0.0)
     {
      rejectReason = "atr_average_unavailable";
      return false;
     }

   double bid = CurrentBid();
   if(bid <= 0.0)
     {
      rejectReason = "bid_unavailable";
      return false;
     }

   plan.spreadATR = (plan.entryPrice - bid) / currentATR;
   plan.atrRatio = currentATR / atrAverage;
   plan.emaDeviationATR = MathAbs(qualityBar.close - qualityFastEma[1]) / currentATR;
   plan.bodyATR = MathAbs(qualityBar.close - qualityBar.open) / currentATR;
   plan.wickATR = (MathMin(signalBar.open, signalBar.close) - signalBar.low) / currentATR;
   plan.slowSlopeATR = (qualitySlowEma[1] - qualitySlowEma[1 + InpSlowSlopeBars]) / currentATR;
   plan.adxValue = qualityAdx[1];
   if(!RecentRangePosition(qualityRates, plan.rangePosition))
     {
      rejectReason = "range_position_unavailable";
      return false;
     }
   if(!RecentRangeStats(qualityRates, InpRecentRangeBars, currentATR,
                        plan.distanceRecentHighATR, plan.distanceRecentLowATR, plan.recentRangeATR))
     {
      rejectReason = "recent_range_stats_unavailable";
      return false;
     }
    if(!DirectionalPressure(qualityRates, InpRecentRangeBars, plan.upPressure, plan.downPressure))
      {
       rejectReason = "pressure_unavailable";
       return false;
      }

    if(plan.spreadATR > InpMaxSpreadATR)
      {
       rejectReason = "spread_atr_too_wide";
       return false;
      }
    if(plan.atrRatio < InpMinExtremeATRRatio)
      {
       rejectReason = "atr_ratio_extreme_low";
       return false;
      }
    if(plan.atrRatio > InpMaxExtremeATRRatio)
      {
       rejectReason = "atr_ratio_extreme_high";
       return false;
      }

    MqlRates biasRates[];
   double biasFastEma[];
   double biasSlowEma[];
   double biasAtr[];
   MqlRates trendRates[];
    double trendFastEma[];
    double trendSlowEma[];
    double trendAtr[];
    MqlRates avoidRates[];
    double avoidFastEma[];
    double avoidSlowEma[];
    double avoidAtr[];
    if(!LoadContextFrame(InpBiasTimeframe, biasFastEmaHandle, biasSlowEmaHandle, biasAtrHandle,
                         biasRates, biasFastEma, biasSlowEma, biasAtr) ||
       !LoadContextFrame(InpTrendTimeframe, trendFastEmaHandle, trendSlowEmaHandle, trendAtrHandle,
                         trendRates, trendFastEma, trendSlowEma, trendAtr) ||
       !LoadContextFrame(InpAvoidTimeframe, avoidFastEmaHandle, avoidSlowEmaHandle, avoidAtrHandle,
                         avoidRates, avoidFastEma, avoidSlowEma, avoidAtr))
      {
       rejectReason = "context_data_unavailable";
       return false;
      }
    int biasScore = BiasScore(biasRates, biasFastEma, biasSlowEma, biasAtr) +
                    BiasScore(trendRates, trendFastEma, trendSlowEma, trendAtr);
    plan.h1M15BiasScore = ClampDouble((double)biasScore / 6.0 * 1.35, 0.0, 1.35);
    plan.h4ContextScore = H4ContextScore(avoidRates, avoidFastEma, avoidSlowEma, avoidAtr);

    double closeLoc = CloseLocation(signalBar);
    double lowerWickShare = LowerWickShare(signalBar);
   double m1RecentHigh = RecentHighestHigh(execRates, InpRecentRangeBars, 2);
   double m1RecentLow = RecentLowestLow(execRates, InpRecentRangeBars, 2);
   if(m1RecentHigh <= 0.0 || m1RecentLow <= 0.0)
     {
      rejectReason = "m1_range_unavailable";
      return false;
     }
    plan.pullbackDepthATR = (m1RecentHigh - signalBar.low) / currentATR;
    plan.breakoutAcceptanceATR = (signalBar.close - m1RecentHigh) / currentATR;

    plan.spreadScore = ScoreMax(plan.spreadATR, 0.10, InpMaxSpreadATR);
    plan.volatilityScore = ScoreBand(plan.atrRatio, 0.85, 1.45,
                                     InpMinATRRatio, MathMax(InpMaxATRRatio, 1.85));
    plan.trendScore = 0.0;
    if(qualityFastEma[1] > qualitySlowEma[1])
       plan.trendScore += 0.35;
    if(qualityBar.close > qualitySlowEma[1])
       plan.trendScore += 0.35;
    if(plan.slowSlopeATR >= InpMinSlowSlopeATR)
       plan.trendScore += 0.25;
    if(plan.emaDeviationATR <= InpMaxEMADeviationATR)
       plan.trendScore += 0.20;
    if(InpMaxADX <= 0.0 || plan.adxValue <= InpMaxADX)
       plan.trendScore += 0.20;
    plan.trendScore = ClampDouble(plan.trendScore, 0.0, 1.35);

    bool pressureOk = (plan.upPressure >= InpMinUpPressure || plan.downPressure <= InpMaxDownPressure);
    bool touchedExecFast = (signalBar.low <= execFastEma[1] + InpPullbackTouchATR * currentATR ||
                            execRates[2].low <= execFastEma[2] + InpPullbackTouchATR * currentATR);
    bool closeRecovered = (signalBar.close > signalBar.open || signalBar.close > execFastEma[1]);
    bool discountRangePullback = (plan.rangePosition >= InpScoreMinDiscountRangePos &&
                                  plan.rangePosition <= InpScoreMaxDiscountRangePos);
    bool expansionDeepPullback = (plan.pullbackDepthATR >= InpScoreDeepPullbackATR &&
                                  plan.atrRatio >= InpScoreMinExpansionATRRatio &&
                                  plan.atrRatio <= InpScoreMaxExpansionATRRatio);
    bool scorePullbackShape = InpEnablePullbackScoreBucket &&
                              touchedExecFast &&
                              closeRecovered &&
                              signalBar.close >= execSlowEma[1] &&
                              closeLoc >= 0.42 &&
                              plan.pullbackDepthATR >= 0.0 &&
                              plan.pullbackDepthATR <= MathMax(InpPullbackMaxDepthATR, 1.80) &&
                              (discountRangePullback || expansionDeepPullback);

    plan.pullbackScore = 0.0;
    if(touchedExecFast)
       plan.pullbackScore += 0.35;
    if(signalBar.close > signalBar.open)
       plan.pullbackScore += 0.25;
    if(signalBar.close > execFastEma[1])
       plan.pullbackScore += 0.25;
    if(closeLoc >= InpMinCloseLocation)
       plan.pullbackScore += 0.25;
    else if(closeLoc >= 0.45)
       plan.pullbackScore += 0.12;
    if(plan.wickATR >= InpMinLowerWickATR || lowerWickShare >= InpMinLowerWickShare)
       plan.pullbackScore += 0.25;
    if(plan.pullbackDepthATR >= 0.25 && plan.pullbackDepthATR <= InpPullbackMaxDepthATR)
       plan.pullbackScore += 0.25;
    else if(plan.pullbackDepthATR >= 0.0 && plan.pullbackDepthATR <= MathMax(InpPullbackMaxDepthATR, 1.80))
       plan.pullbackScore += 0.10;
    plan.pullbackScore = ClampDouble(plan.pullbackScore, 0.0, 1.60);

    plan.pressureScore = 0.0;
    plan.pressureScore += 0.55 * ScoreMin(plan.upPressure, 0.65, InpMinUpPressure);
    plan.pressureScore += 0.45 * ScoreMax(plan.downPressure, 0.35, InpMaxDownPressure);
    if(signalBar.close > signalBar.open)
       plan.pressureScore += 0.20;
    plan.pressureScore = ClampDouble(plan.pressureScore, 0.0, 1.20);

    plan.structureScore = 0.0;
    plan.structureScore += 0.35 * ScoreBand(plan.rangePosition,
                                             InpScoreMinDiscountRangePos,
                                             InpScoreMaxDiscountRangePos,
                                             0.15, 0.75);
    plan.structureScore += 0.30 * ScoreBand(plan.distanceRecentHighATR, 0.75, 1.80, 0.25, 3.00);
    plan.structureScore += 0.35 * ScoreMin(plan.recentRangeATR, 3.50, 2.00);
    plan.structureScore += 0.25 * ScoreMin(plan.distanceRecentLowATR, 2.00, 1.00);
    plan.structureScore = ClampDouble(plan.structureScore, 0.0, 1.25);

    plan.candidateScore = plan.spreadScore + plan.volatilityScore + plan.h4ContextScore +
                          plan.h1M15BiasScore + plan.trendScore + plan.pullbackScore +
                          plan.pressureScore + plan.structureScore;

    bool m1Pullback = InpEnableM1PullbackBucket &&
                      touchedExecFast &&
                      signalBar.close > signalBar.open &&
                     signalBar.close > execFastEma[1] &&
                     execFastEma[1] >= execSlowEma[1] &&
                     closeLoc >= InpMinCloseLocation &&
                     (plan.wickATR >= InpMinLowerWickATR || lowerWickShare >= InpMinLowerWickShare) &&
                     plan.pullbackDepthATR >= 0.0 &&
                     plan.pullbackDepthATR <= InpPullbackMaxDepthATR &&
                     pressureOk;

   bool breakoutAcceptance = InpEnableBreakoutBucket &&
                             signalBar.close > m1RecentHigh + InpBreakoutBufferATR * currentATR &&
                             plan.breakoutAcceptanceATR <= InpBreakoutMaxChaseATR &&
                             signalBar.low >= m1RecentHigh - InpBreakoutRetestBufferATR * currentATR &&
                             closeLoc >= InpMinCloseLocation &&
                              execFastEma[1] >= execSlowEma[1] &&
                              pressureOk;

    if(scorePullbackShape)
      {
       plan.bucket = "M1_PULLBACK_SCORE_LONG";
       plan.entryReason = "m1_pullback_score_reclaim";
      }
    else if(m1Pullback)
      {
       plan.bucket = "M1_PULLBACK_EXECUTION_LONG";
       plan.entryReason = "m1_fast_reclaim_after_pullback";
     }
   else if(breakoutAcceptance)
     {
      plan.bucket = "BREAKOUT_ACCEPTANCE_RETEST_LONG";
      plan.entryReason = "m1_breakout_acceptance";
     }
    else
      {
       rejectReason = "bucket_setup_failed";
       return false;
      }

   double m1SwingLow = RecentSwingLow(execRates, InpM1SwingLookbackBars);
   double m5SwingLow = RecentSwingLow(qualityRates, InpM5SwingLookbackBars);
   double m1StructuralStop = m1SwingLow - InpM1SwingBufferATR * currentATR;
   double m5StructuralStop = m5SwingLow - InpM5SwingBufferATR * currentATR;
   double m1StructuralDistance = plan.entryPrice - m1StructuralStop;
   double m5StructuralDistance = plan.entryPrice - m5StructuralStop;
   double atrDistance = InpStopATRMultiplier * currentATR;
   double spreadDistance = (plan.entryPrice - bid) * InpMinStopSpreadMultiple;
   double minDistance = MathMax(InpMinStopATR * currentATR, spreadDistance);

   if(InpStopMode == SL_ATR_ONLY)
      plan.riskDistance = MathMax(atrDistance, minDistance);
   else if(InpStopMode == SL_M1_SWING)
      plan.riskDistance = MathMax(m1StructuralDistance, minDistance);
   else if(InpStopMode == SL_M5_SWING)
      plan.riskDistance = MathMax(m5StructuralDistance, minDistance);
   else
      plan.riskDistance = MathMax(MathMax(m1StructuralDistance, atrDistance), minDistance);

    if(plan.riskDistance <= 0.0)
      {
       rejectReason = "stop_distance_invalid";
       LogCandidateScore(plan, false, rejectReason);
       return false;
      }

    if(InpMaxStopATR > 0.0 && plan.riskDistance > InpMaxStopATR * currentATR)
      {
       rejectReason = "stop_distance_atr_too_wide";
       LogCandidateScore(plan, false, rejectReason);
       return false;
      }

   double point = PointValue();
   int stopsLevel = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_TRADE_STOPS_LEVEL);
    double minBrokerDistance = (stopsLevel + 2) * point;
    if(minBrokerDistance > 0.0 && plan.riskDistance < minBrokerDistance)
       plan.riskDistance = minBrokerDistance;
    plan.riskDistanceATR = plan.riskDistance / currentATR;
    double pip = PipSize();
    plan.riskDistancePips = pip > 0.0 ? plan.riskDistance / pip : 0.0;

    plan.rewardDistance = plan.riskDistance * InpTargetRMultiple;
   if(InpTPMode == TP_RECENT_HIGH_OR_R)
     {
      double qualityHigh = RecentHighestHigh(qualityRates, InpRangeLookbackBars, 1);
      double highDistance = qualityHigh - plan.entryPrice;
      if(highDistance >= plan.riskDistance * InpMinTargetRMultiple &&
         highDistance <= plan.riskDistance * InpTargetRMultiple)
         plan.rewardDistance = highDistance;
     }
    plan.stopLoss = NormalizeDouble(plan.entryPrice - plan.riskDistance, SymbolDigits());
    plan.takeProfit = NormalizeDouble(plan.entryPrice + plan.rewardDistance, SymbolDigits());
    plan.rewardDistanceATR = plan.rewardDistance / currentATR;
    plan.spreadToRisk = plan.riskDistance > 0.0 ? (plan.entryPrice - bid) / plan.riskDistance : 0.0;
    plan.spreadToReward = plan.rewardDistance > 0.0 ? (plan.entryPrice - bid) / plan.rewardDistance : 0.0;
    plan.rrScore = 0.0;
    plan.rrScore += 0.45 * ScoreMax(plan.spreadToRisk, 0.18, 0.28);
    plan.rrScore += 0.35 * ScoreBand(plan.riskDistanceATR, 0.45, 1.35, 0.35, InpMaxStopATR);
    plan.rrScore += 0.20 * ScoreMin(plan.rewardDistanceATR, 0.80, 0.55);
    plan.rrScore = ClampDouble(plan.rrScore, 0.0, 1.00);
    plan.candidateScore = plan.spreadScore + plan.volatilityScore + plan.h4ContextScore +
                          plan.h1M15BiasScore + plan.trendScore + plan.pullbackScore +
                          plan.pressureScore + plan.structureScore + plan.rrScore;

    if(plan.stopLoss <= 0.0 || plan.takeProfit <= plan.entryPrice || plan.stopLoss >= plan.entryPrice)
      {
       rejectReason = "sl_tp_invalid";
       LogCandidateScore(plan, false, rejectReason);
       return false;
      }

    if(plan.bucket == "M1_PULLBACK_SCORE_LONG" && plan.candidateScore < InpPullbackScoreThreshold)
      {
       rejectReason = "candidate_score_below_threshold";
       LogCandidateScore(plan, false, rejectReason);
       return false;
      }

    if(!CalculateVolume(plan, rejectReason))
      {
       LogCandidateScore(plan, false, rejectReason);
       return false;
      }

    plan.valid = true;
    if(plan.bucket == "M1_PULLBACK_SCORE_LONG")
       LogCandidateScore(plan, true, "accepted");
    return true;
  }

bool EntryGuardsPass(const TradePlan &plan, string &rejectReason)
  {
   if(dailyStopActive)
     {
      rejectReason = dailyStopReason == "" ? "daily_stop_active" : dailyStopReason;
      return false;
     }
   if(weeklyStopActive)
     {
      rejectReason = weeklyStopReason == "" ? "weekly_stop_active" : weeklyStopReason;
      return false;
     }
   if(drawdownStopActive)
     {
      rejectReason = drawdownStopReason == "" ? "drawdown_stop_active" : drawdownStopReason;
      return false;
     }
   if(lossStreakStopActive)
     {
      rejectReason = lossStreakStopReason == "" ? "loss_streak_stop_active" : lossStreakStopReason;
      return false;
     }
   if(InpMaxOpenPositions > 0 && CountManagedPositions() >= InpMaxOpenPositions)
     {
      rejectReason = "max_open_positions";
      return false;
     }
   if(HasLosingManagedLong())
     {
      rejectReason = "averaging_down_blocked";
      return false;
     }
   if(IsCooldownBlocked(plan.signalBarTime))
     {
      rejectReason = "cooldown_bars_blocked";
      return false;
     }
   if(InpMaxTotalOpenRiskPercent > 0.0)
     {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double riskAfter = CurrentTotalOpenRiskMoney() + plan.riskMoney;
      double riskAfterPercent = equity > 0.0 ? 100.0 * riskAfter / equity : 0.0;
      if(riskAfterPercent > InpMaxTotalOpenRiskPercent)
        {
         rejectReason = "total_open_risk_limit";
         return false;
        }
     }
   return true;
  }

bool PlaceTrade(const TradePlan &plan)
  {
   pendingEntryRiskMoney = plan.riskMoney;
   pendingEntrySL = plan.stopLoss;
   pendingEntryTP = plan.takeProfit;
   pendingEntryVolume = plan.lot;
   pendingEntryBucket = plan.bucket;
   pendingEntryReason = plan.entryReason;
   pendingEntrySLMode = plan.slMode;
   pendingEntryTPMode = plan.tpMode;

   string comment = "EV_LONG_LAB|" + plan.bucket;
   bool ok = trade.Buy(plan.lot, runtimeSymbol, 0.0, plan.stopLoss, plan.takeProfit, comment);
   if(!ok)
     {
      LogEvent("entry_failed", "order_send_failed", plan, "retcode=" + (string)trade.ResultRetcode());
      PrintFormat("%s entry failed retcode=%d", STRATEGY_NAME, trade.ResultRetcode());
      return false;
     }

   dailyEntries++;
   lastEntryBarTime = plan.signalBarTime;
   LogEvent("entry", "ENTRY", plan,
            "fixed_lot_mode=" + BoolWord(plan.fixedLotMode) +
            "|min_lot_forced=" + BoolWord(plan.minLotForced) +
            "|sl_mode=" + plan.slMode +
            "|tp_mode=" + plan.tpMode +
            "|entry_reason=" + plan.entryReason +
            "|margin=" + DoubleToString(plan.marginRequired, 2));
   return true;
  }

void ManageTimeouts()
  {
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;

      datetime openedAt = (datetime)PositionGetInteger(POSITION_TIME);
      int openShift = iBarShift(runtimeSymbol, InpExecutionTimeframe, openedAt, false);
      if(openShift >= InpMaxHoldBars)
         CloseManagedPositionByTicket(ticket, "TIMEOUT");
     }
  }

string DealExitReason(long dealReason, ulong positionIdentifier)
  {
   if(dealReason == DEAL_REASON_SL)
      return "SL";
   if(dealReason == DEAL_REASON_TP)
      return "TP";

   string pending = PopPendingCloseReason(positionIdentifier);
   if(pending == "TIMEOUT")
      return "TIMEOUT";
   if(pending == "RISK_STOP" || pending == "daily_max_loss" || pending == "weekly_max_loss" ||
      pending == "max_drawdown" || pending == "loss_streak")
      return "RISK_STOP";
   if(pending != "")
      return pending;
   return "MANUAL_OR_UNKNOWN";
  }

void RegisterClosedTrade(datetime closeTime,
                         ulong positionIdentifier,
                         double netMoney,
                         double closePrice,
                         double volume,
                         string exitReason)
  {
   TrackedPosition tracked = RemoveTrackedPosition(positionIdentifier);
   double riskMoney = tracked.riskMoney;
   if(riskMoney <= 0.0)
      riskMoney = MathAbs(netMoney);
   double realizedR = riskMoney > 0.0 ? netMoney / riskMoney : 0.0;

   totalClosedTrades++;
   dailyClosedTrades++;
   totalNetMoney += netMoney;
   totalR += realizedR;
   equityCurveR += realizedR;
   if(equityCurveR > equityPeakR)
      equityPeakR = equityCurveR;
   double ddR = equityPeakR - equityCurveR;
   if(ddR > maxDrawdownR)
      maxDrawdownR = ddR;

   if(realizedR > 0.0)
     {
      totalWins++;
      grossWinR += realizedR;
      consecutiveLosses = 0;
     }
   else if(realizedR < 0.0)
     {
      totalLosses++;
      grossLossR += realizedR;
      consecutiveLosses++;
      if(consecutiveLosses > observedMaxConsecutiveLosses)
         observedMaxConsecutiveLosses = consecutiveLosses;
     }

   if(InpMaxConsecutiveLosses > 0 && consecutiveLosses >= InpMaxConsecutiveLosses)
     {
      TriggerStop("loss_streak", "max_consecutive_losses",
                  "consecutive_losses=" + IntegerToString(consecutiveLosses));
      if(InpFlattenOnRiskStop)
         FlattenManagedPositions("RISK_STOP");
     }

   UpdateMonthlyStats(closeTime, netMoney, realizedR);

   TradePlan eventPlan;
   ResetPlan(eventPlan);
   eventPlan.bucket = tracked.bucket;
   eventPlan.entryReason = tracked.entryReason;
   eventPlan.slMode = tracked.slMode;
   eventPlan.tpMode = tracked.tpMode;
   eventPlan.entryPrice = tracked.entryPrice;
   eventPlan.stopLoss = tracked.stopLoss;
   eventPlan.takeProfit = tracked.takeProfit;
   eventPlan.lot = volume;
   eventPlan.riskMoney = riskMoney;
   int holdingSeconds = tracked.entryTime > 0 ? (int)(closeTime - tracked.entryTime) : 0;
   LogEvent("exit", exitReason, eventPlan,
            "close_price=" + DoubleToString(closePrice, SymbolDigits()) +
            "|net_money=" + DoubleToString(netMoney, 2) +
            "|realized_r=" + DoubleToString(realizedR, 6) +
            "|holding_seconds=" + IntegerToString(holdingSeconds));
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;
   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != runtimeSymbol)
      return;
   if((long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagicNumber)
      return;

   ENUM_DEAL_ENTRY entryType = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   ulong positionIdentifier = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   datetime dealTime = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
   double dealPrice = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   double dealVolume = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);

   if(entryType == DEAL_ENTRY_IN && dealType == DEAL_TYPE_BUY)
     {
      AddTrackedPosition(positionIdentifier, dealTime, dealPrice, dealVolume);
      return;
     }

   if(entryType != DEAL_ENTRY_OUT && entryType != DEAL_ENTRY_OUT_BY && entryType != DEAL_ENTRY_INOUT)
      return;

   double netMoney = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) +
                     HistoryDealGetDouble(trans.deal, DEAL_SWAP) +
                     HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   long dealReason = (long)HistoryDealGetInteger(trans.deal, DEAL_REASON);
   string exitReason = DealExitReason(dealReason, positionIdentifier);
   RegisterClosedTrade(dealTime, positionIdentifier, netMoney, dealPrice, dealVolume, exitReason);
  }

bool IsNewBar(datetime &barTime)
  {
   barTime = iTime(runtimeSymbol, InpExecutionTimeframe, 0);
   if(barTime <= 0)
      return false;
   if(barTime == lastBarTime)
      return false;
   lastBarTime = barTime;
   return true;
  }

void ProcessNewBar(datetime barTime)
  {
   TradePlan plan;
   string rejectReason = "";
   bool hasPlan = BuildTradePlan(plan, rejectReason);
   if(!hasPlan)
     {
      dailyRejects++;
      if(InpLogNoSignalDiagnostics)
         LogEvent("candidate_rejected", rejectReason, plan, "bar_time=" + TimeToString(barTime, TIME_DATE | TIME_SECONDS));
      return;
     }

   dailySignals++;
   LogEvent("signal", "SIGNAL", plan, "enable_trading=" + BoolWord(InpEnableTrading));
   if(!InpEnableTrading)
      return;

   if(!EntryGuardsPass(plan, rejectReason))
     {
      dailyRiskBlocks++;
      LogEvent("entry_blocked", rejectReason, plan, "risk_or_position_guard");
      return;
     }

   PlaceTrade(plan);
  }

void WriteSummary()
  {
   string fileName = CleanPresetString(InpSummaryFileName);
   int flags = FILE_CSV | FILE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;
   int handle = FileOpen(fileName, flags, ';');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s summary open failed: %s err=%d", STRATEGY_NAME, fileName, GetLastError());
      return;
     }

   double expectancyR = totalClosedTrades > 0 ? totalR / totalClosedTrades : 0.0;
   double profitFactor = grossLossR < 0.0 ? grossWinR / MathAbs(grossLossR) : 0.0;
   double winRate = totalClosedTrades > 0 ? 100.0 * totalWins / totalClosedTrades : 0.0;

    FileWrite(handle,
              "time", "strategy", "ea_version", "preset_name", "symbol", "timeframe", "enable_trading",
              "closed_trades", "wins", "losses", "win_rate", "expectancy_r",
             "profit_factor", "total_r", "net_money", "max_dd_r",
             "max_dd_percent", "max_consecutive_losses", "daily_stop_active",
             "weekly_stop_active", "drawdown_stop_active", "loss_streak_stop_active");
   FileWrite(handle,
              TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
              STRATEGY_NAME,
              EA_VERSION,
              CleanPresetString(InpPresetName),
              runtimeSymbol,
             TimeframeText(),
             BoolWord(InpEnableTrading),
             totalClosedTrades,
             totalWins,
             totalLosses,
             winRate,
             expectancyR,
             profitFactor,
             totalR,
             totalNetMoney,
             maxDrawdownR,
             maxDrawdownPercent,
             observedMaxConsecutiveLosses,
             BoolWord(dailyStopActive),
             BoolWord(weeklyStopActive),
             BoolWord(drawdownStopActive),
             BoolWord(lossStreakStopActive));
   FileClose(handle);
  }

void WriteMonthlySummary()
  {
   string fileName = CleanPresetString(InpMonthlySummaryFileName);
   int flags = FILE_CSV | FILE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;
   int handle = FileOpen(fileName, flags, ';');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s monthly summary open failed: %s err=%d", STRATEGY_NAME, fileName, GetLastError());
      return;
     }

   FileWrite(handle, "month", "trades", "wins", "losses", "net_money", "net_r", "expectancy_r", "profit_factor");
   int size = ArraySize(monthStats);
   for(int i = 0; i < size; ++i)
     {
      double expectancyR = monthStats[i].trades > 0 ? monthStats[i].netR / monthStats[i].trades : 0.0;
      double profitFactor = monthStats[i].grossLossR < 0.0 ? monthStats[i].grossWinR / MathAbs(monthStats[i].grossLossR) : 0.0;
      FileWrite(handle,
                monthStats[i].monthKey,
                monthStats[i].trades,
                monthStats[i].wins,
                monthStats[i].losses,
                monthStats[i].netMoney,
                monthStats[i].netR,
                expectancyR,
                profitFactor);
     }
   FileClose(handle);
  }

int OnInit()
  {
   runtimeSymbol = CleanPresetString(InpSymbol);
   runtimeAllowedWeekdays = CleanPresetString(InpAllowedWeekdays);
   if(runtimeSymbol == "")
      return INIT_PARAMETERS_INCORRECT;
   if(!ParseAllowedWeekdays())
      return INIT_PARAMETERS_INCORRECT;

   if(InpExecFastEMAPeriod <= 1 || InpExecSlowEMAPeriod <= InpExecFastEMAPeriod ||
      InpFastEMAPeriod <= 1 || InpSlowEMAPeriod <= InpFastEMAPeriod ||
      InpSlowSlopeBars <= 0 || InpATRPeriod <= 1 || InpATRAveragePeriod < InpATRPeriod ||
      InpADXPeriod <= 1 || InpSessionStartHour < 0 || InpSessionStartHour > 23 ||
      InpSessionEndHour < 0 || InpSessionEndHour > 23 || InpFixedLot <= 0.0 ||
      InpFixedLotEquityThreshold < 0.0 || InpRiskPercent <= 0.0 || InpDailyMaxLossPercent <= 0.0 ||
      InpWeeklyMaxLossPercent <= 0.0 || InpMaxDrawdownPercent <= 0.0 ||
      InpMaxConsecutiveLosses < 0 || InpMaxOpenPositions < 1 || InpMaxTotalOpenRiskPercent <= 0.0 ||
      InpCooldownBars < 0 || InpTargetRMultiple <= 0.0 || InpMinTargetRMultiple <= 0.0 ||
      InpTargetRMultiple < InpMinTargetRMultiple || InpM1SwingLookbackBars < 2 ||
      InpM5SwingLookbackBars < 2 || InpStopATRMultiplier <= 0.0 ||
      InpM1SwingBufferATR < 0.0 || InpM5SwingBufferATR < 0.0 || InpMinStopATR <= 0.0 ||
      InpMinStopSpreadMultiple < 0.0 ||
      InpMaxStopATR < InpMinStopATR || InpMaxHoldBars < 1 || InpMaxSpreadATR <= 0.0 ||
      InpMaxEMADeviationATR <= 0.0 || InpMinBodyATR < 0.0 || InpMaxBodyATR <= InpMinBodyATR ||
      InpMinATRRatio <= 0.0 || InpMaxATRRatio < InpMinATRRatio || InpRangeLookbackBars < 5 ||
      InpRecentRangeBars < 3 ||
      InpMinRangePosition < 0.0 || InpMinRangePosition > 1.0 ||
      InpMaxRangePosition < 0.0 || InpMaxRangePosition > 1.0 ||
      InpMinRangePosition >= InpMaxRangePosition || InpMaxADX < 0.0 ||
      InpMinBiasScore < 0 || InpH4MaxBearSlopeATR < 0.0 || InpH4MaxBelowSlowATR < 0.0 ||
      InpPullbackTouchATR < 0.0 || InpMinCloseLocation < 0.0 || InpMinCloseLocation > 1.0 ||
      InpPullbackMaxDepthATR <= 0.0 || InpMinLowerWickATR < 0.0 ||
      InpMinLowerWickShare < 0.0 || InpMinLowerWickShare > 1.0 ||
      InpBreakoutBufferATR < 0.0 || InpBreakoutMaxChaseATR <= 0.0 ||
      InpBreakoutRetestBufferATR < 0.0 || InpMinUpPressure < 0.0 || InpMinUpPressure > 1.0 ||
      InpMaxDownPressure < 0.0 || InpMaxDownPressure > 1.0 ||
      InpMagicNumber <= 0)
      return INIT_PARAMETERS_INCORRECT;

   if(!SymbolInfoInteger(runtimeSymbol, SYMBOL_SELECT))
      if(!SymbolSelect(runtimeSymbol, true))
         return INIT_FAILED;

   fastEmaHandle = iMA(runtimeSymbol, InpExecutionTimeframe, InpExecFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowEmaHandle = iMA(runtimeSymbol, InpExecutionTimeframe, InpExecSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   atrHandle = iATR(runtimeSymbol, InpExecutionTimeframe, InpATRPeriod);
   adxHandle = iADX(runtimeSymbol, InpExecutionTimeframe, InpADXPeriod);
   qualityFastEmaHandle = iMA(runtimeSymbol, InpQualityTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   qualitySlowEmaHandle = iMA(runtimeSymbol, InpQualityTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   qualityAtrHandle = iATR(runtimeSymbol, InpQualityTimeframe, InpATRPeriod);
   qualityAdxHandle = iADX(runtimeSymbol, InpQualityTimeframe, InpADXPeriod);
   biasFastEmaHandle = iMA(runtimeSymbol, InpBiasTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   biasSlowEmaHandle = iMA(runtimeSymbol, InpBiasTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   biasAtrHandle = iATR(runtimeSymbol, InpBiasTimeframe, InpATRPeriod);
   trendFastEmaHandle = iMA(runtimeSymbol, InpTrendTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   trendSlowEmaHandle = iMA(runtimeSymbol, InpTrendTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   trendAtrHandle = iATR(runtimeSymbol, InpTrendTimeframe, InpATRPeriod);
   avoidFastEmaHandle = iMA(runtimeSymbol, InpAvoidTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   avoidSlowEmaHandle = iMA(runtimeSymbol, InpAvoidTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   avoidAtrHandle = iATR(runtimeSymbol, InpAvoidTimeframe, InpATRPeriod);
   if(fastEmaHandle == INVALID_HANDLE || slowEmaHandle == INVALID_HANDLE ||
      atrHandle == INVALID_HANDLE || adxHandle == INVALID_HANDLE ||
      qualityFastEmaHandle == INVALID_HANDLE || qualitySlowEmaHandle == INVALID_HANDLE ||
      qualityAtrHandle == INVALID_HANDLE || qualityAdxHandle == INVALID_HANDLE ||
      biasFastEmaHandle == INVALID_HANDLE || biasSlowEmaHandle == INVALID_HANDLE ||
      biasAtrHandle == INVALID_HANDLE || trendFastEmaHandle == INVALID_HANDLE ||
      trendSlowEmaHandle == INVALID_HANDLE || trendAtrHandle == INVALID_HANDLE ||
      avoidFastEmaHandle == INVALID_HANDLE || avoidSlowEmaHandle == INVALID_HANDLE ||
      avoidAtrHandle == INVALID_HANDLE)
      return INIT_FAILED;

   trade.SetExpertMagicNumber((ulong)InpMagicNumber);
   trade.SetDeviationInPoints(20);

   datetime now = TimeCurrent();
   currentDayKey = -1;
   currentWeekKey = -1;
   dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   weekStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   accountPeakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   UpdatePeriodAnchors();
   UpdateDrawdown();
   OpenEventLog();
   LogSimpleEvent("init", "INIT",
                  "enable_trading=" + BoolWord(InpEnableTrading) +
                  "|preset_name=" + CleanPresetString(InpPresetName) +
                  "|ea_version=" + EA_VERSION +
                  "|now=" + TimeToString(now, TIME_DATE | TIME_SECONDS));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   LogSimpleEvent("deinit", "DEINIT", "reason=" + IntegerToString(reason));
   WriteSummary();
   WriteMonthlySummary();
   CloseEventLog();
   if(fastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(fastEmaHandle);
   if(slowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(slowEmaHandle);
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
   if(adxHandle != INVALID_HANDLE)
      IndicatorRelease(adxHandle);
   if(qualityFastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(qualityFastEmaHandle);
   if(qualitySlowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(qualitySlowEmaHandle);
   if(qualityAtrHandle != INVALID_HANDLE)
      IndicatorRelease(qualityAtrHandle);
   if(qualityAdxHandle != INVALID_HANDLE)
      IndicatorRelease(qualityAdxHandle);
   if(biasFastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(biasFastEmaHandle);
   if(biasSlowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(biasSlowEmaHandle);
   if(biasAtrHandle != INVALID_HANDLE)
      IndicatorRelease(biasAtrHandle);
   if(trendFastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(trendFastEmaHandle);
   if(trendSlowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(trendSlowEmaHandle);
   if(trendAtrHandle != INVALID_HANDLE)
      IndicatorRelease(trendAtrHandle);
   if(avoidFastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(avoidFastEmaHandle);
   if(avoidSlowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(avoidSlowEmaHandle);
   if(avoidAtrHandle != INVALID_HANDLE)
      IndicatorRelease(avoidAtrHandle);
  }

void OnTick()
  {
   UpdatePeriodAnchors();
   UpdateDrawdown();
   ManageTimeouts();
   CheckRiskStops();

   datetime barTime = 0;
   if(!IsNewBar(barTime))
      return;
   ProcessNewBar(barTime);
  }
//+------------------------------------------------------------------+
