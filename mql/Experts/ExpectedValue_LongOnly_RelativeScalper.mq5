//+------------------------------------------------------------------+
//| ExpectedValue_LongOnly_RelativeScalper                           |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Long-only USDJPY relative-filter scalper with fixed-lot micro-cap mode, risk sizing, hard stops, diagnostics, and monthly summaries."

#include <Trade\Trade.mqh>

CTrade trade;

static const string STRATEGY_NAME = "ExpectedValue_LongOnly_RelativeScalper";

input bool            InpEnableTrading              = false;
input string          InpSymbol                     = "USDJPY";
input ENUM_TIMEFRAMES InpSignalTimeframe            = PERIOD_M5;
input long            InpMagicNumber                = 2026051901;

input int             InpFastEMAPeriod              = 13;
input int             InpSlowEMAPeriod              = 100;
input int             InpSlowSlopeBars              = 5;
input int             InpATRPeriod                  = 14;
input int             InpATRAveragePeriod           = 80;
input int             InpADXPeriod                  = 14;

input bool            InpUseSessionFilter           = true;
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
input int             InpCooldownBars               = 3;
input bool            InpFlattenOnRiskStop          = true;

input double          InpTargetRMultiple            = 1.5;
input int             InpSwingLookbackBars          = 12;
input double          InpStopATRMultiplier          = 1.20;
input double          InpStopSwingBufferATR         = 0.15;
input double          InpMinStopATR                 = 0.70;
input double          InpMaxStopATR                 = 3.00;
input int             InpMaxHoldBars                = 12;

input double          InpMaxSpreadATR               = 0.12;
input double          InpMaxEMADeviationATR         = 1.20;
input double          InpMinBodyATR                 = 0.05;
input double          InpMaxBodyATR                 = 1.40;
input double          InpMinATRRatio                = 0.55;
input double          InpMaxATRRatio                = 2.20;
input int             InpRangeLookbackBars          = 48;
input double          InpMinRangePosition           = 0.15;
input double          InpMaxRangePosition           = 0.92;
input double          InpMinSlowSlopeATR            = 0.00;
input double          InpMaxADX                     = 35.0;

input bool            InpEnablePullbackReclaim      = true;
input double          InpPullbackTouchATR           = 0.25;
input double          InpMinCloseLocation           = 0.55;
input double          InpMinLowerWickShare          = 0.20;

input bool            InpEnableDipContinuation      = true;
input double          InpDipMaxRet1                 = 0.0004;
input double          InpDipMinUpperWickShare       = 0.45;
input double          InpDipMaxLowerWickShare       = 0.15;
input double          InpDipMaxCloseLocation        = 0.45;

input bool            InpLogDiagnostics             = true;
input bool            InpLogNoSignalDiagnostics     = true;
input bool            InpUseCommonFiles             = true;
input string          InpEventLogFileName           = "mt5_company_expected_value_long_relative_events.csv";
input string          InpSummaryFileName            = "mt5_company_expected_value_long_relative_summary.csv";
input string          InpMonthlySummaryFileName     = "mt5_company_expected_value_long_relative_monthly.csv";

struct TradePlan
  {
   bool     valid;
   string   bucket;
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
   double   spreadATR;
   double   emaDeviationATR;
   double   bodyATR;
   double   atrRatio;
   double   rangePosition;
   double   slowSlopeATR;
   double   adxValue;
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

string TimeframeText()
  {
   return EnumToString(InpSignalTimeframe);
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
                "time", "event", "reason", "symbol", "timeframe", "bucket",
                "equity", "balance", "price", "sl", "tp", "lot",
                "risk_money", "risk_percent", "spread_atr", "ema_deviation_atr",
                "body_atr", "atr_ratio", "range_position", "slow_slope_atr",
                "adx", "open_positions", "total_open_risk_percent",
                "consecutive_losses", "detail");
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
             plan.bucket,
             AccountInfoDouble(ACCOUNT_EQUITY),
             AccountInfoDouble(ACCOUNT_BALANCE),
             plan.entryPrice,
             plan.stopLoss,
             plan.takeProfit,
             plan.lot,
             plan.riskMoney,
             plan.riskPercent,
             plan.spreadATR,
             plan.emaDeviationATR,
             plan.bodyATR,
             plan.atrRatio,
             plan.rangePosition,
             plan.slowSlopeATR,
             plan.adxValue,
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
   int barsSince = iBarShift(runtimeSymbol, InpSignalTimeframe, lastEntryBarTime, false);
   if(barsSince < 0)
      return false;
   return (barsSince < InpCooldownBars);
  }

bool LoadMarketData(MqlRates &rates[], double &fastEma[], double &slowEma[], double &atr[], double &adx[])
  {
   int needBars = MathMax(InpSlowEMAPeriod + InpSlowSlopeBars + 10,
                          MathMax(InpATRAveragePeriod + InpATRPeriod + 10,
                                  MathMax(InpRangeLookbackBars, InpSwingLookbackBars) + 10));
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(fastEma, true);
   ArraySetAsSeries(slowEma, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(adx, true);

   if(CopyRates(runtimeSymbol, InpSignalTimeframe, 0, needBars, rates) < needBars)
      return false;
   if(CopyBuffer(fastEmaHandle, 0, 0, needBars, fastEma) < needBars)
      return false;
   if(CopyBuffer(slowEmaHandle, 0, 0, needBars, slowEma) < needBars)
      return false;
   if(CopyBuffer(atrHandle, 0, 0, needBars, atr) < needBars)
      return false;
   if(CopyBuffer(adxHandle, 0, 0, needBars, adx) < needBars)
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

double RecentSwingLow(const MqlRates &rates[])
  {
   int size = ArraySize(rates);
   int limit = MathMin(InpSwingLookbackBars, size - 2);
   double lowest = rates[1].low;
   for(int i = 1; i <= limit; ++i)
      lowest = MathMin(lowest, rates[i].low);
   return lowest;
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

   MqlRates rates[];
   double fastEma[];
   double slowEma[];
   double atr[];
   double adx[];
   if(!LoadMarketData(rates, fastEma, slowEma, atr, adx))
     {
      rejectReason = "market_data_unavailable";
      return false;
     }

   MqlRates signalBar = rates[1];
   plan.signalBarTime = signalBar.time;
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

   double currentATR = atr[1];
   if(currentATR <= 0.0)
     {
      rejectReason = "atr_unavailable";
      return false;
     }

   double atrAverage = AverageATR(atr);
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
   plan.emaDeviationATR = MathAbs(signalBar.close - fastEma[1]) / currentATR;
   plan.bodyATR = MathAbs(signalBar.close - signalBar.open) / currentATR;
   plan.slowSlopeATR = (slowEma[1] - slowEma[1 + InpSlowSlopeBars]) / currentATR;
   plan.adxValue = adx[1];
   if(!RecentRangePosition(rates, plan.rangePosition))
     {
      rejectReason = "range_position_unavailable";
      return false;
     }

   if(plan.spreadATR > InpMaxSpreadATR)
     {
      rejectReason = "spread_atr_too_wide";
      return false;
     }
   if(plan.atrRatio < InpMinATRRatio)
     {
      rejectReason = "atr_ratio_too_low";
      return false;
     }
   if(plan.atrRatio > InpMaxATRRatio)
     {
      rejectReason = "atr_ratio_too_high";
      return false;
     }
   if(fastEma[1] <= slowEma[1])
     {
      rejectReason = "ema_trend_filter_failed";
      return false;
     }
   if(signalBar.close <= slowEma[1])
     {
      rejectReason = "price_below_slow_ema";
      return false;
     }
   if(plan.slowSlopeATR < InpMinSlowSlopeATR)
     {
      rejectReason = "slow_slope_filter_failed";
      return false;
     }
   if(plan.emaDeviationATR > InpMaxEMADeviationATR)
     {
      rejectReason = "ema_deviation_atr_too_large";
      return false;
     }
   if(plan.bodyATR < InpMinBodyATR)
     {
      rejectReason = "body_atr_too_small";
      return false;
     }
   if(plan.bodyATR > InpMaxBodyATR)
     {
      rejectReason = "body_atr_too_large";
      return false;
     }
   if(plan.rangePosition < InpMinRangePosition)
     {
      rejectReason = "range_position_too_low";
      return false;
     }
   if(plan.rangePosition > InpMaxRangePosition)
     {
      rejectReason = "range_position_too_high";
      return false;
     }
   if(InpMaxADX > 0.0 && plan.adxValue > InpMaxADX)
     {
      rejectReason = "adx_too_high";
      return false;
     }

   double closeLoc = CloseLocation(signalBar);
   double lowerWick = LowerWickShare(signalBar);
   double upperWick = UpperWickShare(signalBar);
   bool touchedFast = (signalBar.low <= fastEma[1] + InpPullbackTouchATR * currentATR ||
                       rates[2].close <= fastEma[2]);
   bool reclaim = InpEnablePullbackReclaim &&
                  signalBar.close > signalBar.open &&
                  signalBar.close > fastEma[1] &&
                  touchedFast &&
                  closeLoc >= InpMinCloseLocation &&
                  lowerWick >= InpMinLowerWickShare;

   double ret1 = rates[2].close > 0.0 ? (signalBar.close - rates[2].close) / rates[2].close : 0.0;
   bool dipContinuation = InpEnableDipContinuation &&
                          ret1 <= InpDipMaxRet1 &&
                          upperWick >= InpDipMinUpperWickShare &&
                          lowerWick <= InpDipMaxLowerWickShare &&
                          closeLoc <= InpDipMaxCloseLocation;

   if(reclaim)
      plan.bucket = "PULLBACK_RECLAIM";
   else if(dipContinuation)
      plan.bucket = "DIP_CONTINUATION";
   else
     {
      rejectReason = "setup_shape_failed";
      return false;
     }

   double swingLow = RecentSwingLow(rates);
   double structuralStop = swingLow - InpStopSwingBufferATR * currentATR;
   double structuralDistance = plan.entryPrice - structuralStop;
   double atrDistance = InpStopATRMultiplier * currentATR;
   double minDistance = InpMinStopATR * currentATR;
   plan.riskDistance = MathMax(MathMax(structuralDistance, atrDistance), minDistance);

   if(InpMaxStopATR > 0.0 && plan.riskDistance > InpMaxStopATR * currentATR)
     {
      rejectReason = "stop_distance_atr_too_wide";
      return false;
     }

   double point = PointValue();
   int stopsLevel = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minBrokerDistance = (stopsLevel + 2) * point;
   if(minBrokerDistance > 0.0 && plan.riskDistance < minBrokerDistance)
      plan.riskDistance = minBrokerDistance;

   plan.rewardDistance = plan.riskDistance * InpTargetRMultiple;
   plan.stopLoss = NormalizeDouble(plan.entryPrice - plan.riskDistance, SymbolDigits());
   plan.takeProfit = NormalizeDouble(plan.entryPrice + plan.rewardDistance, SymbolDigits());
   if(plan.stopLoss <= 0.0 || plan.takeProfit <= plan.entryPrice || plan.stopLoss >= plan.entryPrice)
     {
      rejectReason = "sl_tp_invalid";
      return false;
     }

   if(!CalculateVolume(plan, rejectReason))
      return false;

   plan.valid = true;
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

   string comment = "EV_LONG_REL|" + plan.bucket;
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
      int openShift = iBarShift(runtimeSymbol, InpSignalTimeframe, openedAt, false);
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
   eventPlan.entryPrice = tracked.entryPrice;
   eventPlan.stopLoss = tracked.stopLoss;
   eventPlan.takeProfit = tracked.takeProfit;
   eventPlan.lot = volume;
   eventPlan.riskMoney = riskMoney;
   LogEvent("exit", exitReason, eventPlan,
            "close_price=" + DoubleToString(closePrice, SymbolDigits()) +
            "|net_money=" + DoubleToString(netMoney, 2) +
            "|realized_r=" + DoubleToString(realizedR, 6));
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
   barTime = iTime(runtimeSymbol, InpSignalTimeframe, 0);
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
             "time", "strategy", "symbol", "timeframe", "enable_trading",
             "closed_trades", "wins", "losses", "win_rate", "expectancy_r",
             "profit_factor", "total_r", "net_money", "max_dd_r",
             "max_dd_percent", "max_consecutive_losses", "daily_stop_active",
             "weekly_stop_active", "drawdown_stop_active", "loss_streak_stop_active");
   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             STRATEGY_NAME,
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

   if(InpFastEMAPeriod <= 1 || InpSlowEMAPeriod <= InpFastEMAPeriod ||
      InpSlowSlopeBars <= 0 || InpATRPeriod <= 1 || InpATRAveragePeriod < InpATRPeriod ||
      InpADXPeriod <= 1 || InpSessionStartHour < 0 || InpSessionStartHour > 23 ||
      InpSessionEndHour < 0 || InpSessionEndHour > 23 || InpFixedLot <= 0.0 ||
      InpFixedLotEquityThreshold < 0.0 || InpRiskPercent <= 0.0 || InpDailyMaxLossPercent <= 0.0 ||
      InpWeeklyMaxLossPercent <= 0.0 || InpMaxDrawdownPercent <= 0.0 ||
      InpMaxConsecutiveLosses < 0 || InpMaxOpenPositions < 1 || InpMaxTotalOpenRiskPercent <= 0.0 ||
      InpCooldownBars < 0 || InpTargetRMultiple <= 0.0 || InpSwingLookbackBars < 2 ||
      InpStopATRMultiplier <= 0.0 || InpStopSwingBufferATR < 0.0 || InpMinStopATR <= 0.0 ||
      InpMaxStopATR < InpMinStopATR || InpMaxHoldBars < 1 || InpMaxSpreadATR <= 0.0 ||
      InpMaxEMADeviationATR <= 0.0 || InpMinBodyATR < 0.0 || InpMaxBodyATR <= InpMinBodyATR ||
      InpMinATRRatio <= 0.0 || InpMaxATRRatio < InpMinATRRatio || InpRangeLookbackBars < 5 ||
      InpMinRangePosition < 0.0 || InpMinRangePosition > 1.0 ||
      InpMaxRangePosition < 0.0 || InpMaxRangePosition > 1.0 ||
      InpMinRangePosition >= InpMaxRangePosition || InpMaxADX < 0.0 ||
      InpPullbackTouchATR < 0.0 || InpMinCloseLocation < 0.0 || InpMinCloseLocation > 1.0 ||
      InpMinLowerWickShare < 0.0 || InpMinLowerWickShare > 1.0 ||
      InpDipMaxRet1 < -0.01 || InpDipMaxRet1 > 0.01 ||
      InpDipMinUpperWickShare < 0.0 || InpDipMinUpperWickShare > 1.0 ||
      InpDipMaxLowerWickShare < 0.0 || InpDipMaxLowerWickShare > 1.0 ||
      InpDipMaxCloseLocation < 0.0 || InpDipMaxCloseLocation > 1.0 ||
      InpMagicNumber <= 0)
      return INIT_PARAMETERS_INCORRECT;

   if(!SymbolInfoInteger(runtimeSymbol, SYMBOL_SELECT))
      if(!SymbolSelect(runtimeSymbol, true))
         return INIT_FAILED;

   fastEmaHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowEmaHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   atrHandle = iATR(runtimeSymbol, InpSignalTimeframe, InpATRPeriod);
   adxHandle = iADX(runtimeSymbol, InpSignalTimeframe, InpADXPeriod);
   if(fastEmaHandle == INVALID_HANDLE || slowEmaHandle == INVALID_HANDLE ||
      atrHandle == INVALID_HANDLE || adxHandle == INVALID_HANDLE)
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
   LogSimpleEvent("init", "INIT", "enable_trading=" + BoolWord(InpEnableTrading) + "|now=" + TimeToString(now, TIME_DATE | TIME_SECONDS));
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
