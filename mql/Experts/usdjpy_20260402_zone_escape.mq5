//+------------------------------------------------------------------+
//| USDJPY 50-pip Zone Escape Prototype                             |
//+------------------------------------------------------------------+
#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "1.00"
#property strict
#property description "USDJPY M5 zone-escape continuation prototype built from 50-pip event study"

#include <Trade\Trade.mqh>

CTrade trade;

input string          InpSymbol                           = "USDJPY";
input ENUM_TIMEFRAMES InpSignalTimeframe                  = PERIOD_M5;
input int             InpEMAFastPeriod                    = 13;
input int             InpEMASlowPeriod                    = 100;

input bool            InpEnableSell                       = true;
input int             InpSellStartHour                    = 0;
input int             InpSellEndHour                      = 9;
input double          InpZoneStepPips                     = 50.0;
input bool            InpRequireNotSameZone48             = true;
input int             InpZoneLookback24                   = 24;
input int             InpZoneLookback48                   = 48;
input int             InpTouchLookbackBars                = 144;
input int             InpMaxPriorTouches                  = 3;
input double          InpMinBreakoutBodyPips              = 4.0;
input double          InpMinBodyToRange                   = 0.60;
input double          InpMinBodyVsAvg                     = 1.00;
input int             InpAverageBodyLookback              = 20;
input int             InpBreakoutSlopeLookback            = 5;
input int             InpBreakoutExpiryBars               = 48;
input int             InpMaxRetestDelayBars               = 24;
input double          InpTouchTolerancePips               = 0.60;
input double          InpRetestBufferPips                 = 1.50;
input double          InpMidpointBufferPips               = 1.00;
input double          InpMinRetestCloseLocation           = 0.60;

input double          InpStopLossPips                     = 10.0;
input double          InpTargetRMultiple                  = 1.20;
input int             InpMaxHoldBars                      = 96;

input double          InpRiskPercent                      = 0.35;
input bool            InpSkipTradeWhenMinLotRiskTooHigh   = true;
input double          InpMaxEffectiveRiskPercentAtMinLot  = 2.00;

input bool            InpUseDailyLossCap                  = true;
input double          InpDailyLossCapPercent              = 3.0;
input bool            InpUseEquityKillSwitch              = true;
input double          InpEquityKillSwitchPercent          = 12.0;
input int             InpMaxTradesPerDay                  = 24;
input int             InpMaxOpenTrades                    = 1;
input int             InpMaxSpreadPips                    = 2.0;
input double          InpMaxDeviationPips                 = 2.0;
input string          InpAllowedWeekdays                  = "1,2,3,4,5";
input string          InpBlockedEntryHours                = "";
input long            InpMagicNumber                      = 20260425;

int emaFastHandle = INVALID_HANDLE;
int emaSlowHandle = INVALID_HANDLE;

bool allowedWeekdays[7];
bool blockedHours[24];
string runtimeSymbol = "";
string runtimeAllowedWeekdays = "";
string runtimeBlockedEntryHours = "";
datetime lastBarTime = 0;
datetime currentDayStart = 0;
double dailyStartEquity = 0.0;
double equityPeak = 0.0;
int dailyTradeCount = 0;

struct SignalContext
  {
   datetime barTime;
   int      hour;
   int      weekday;
   double   open;
   double   high;
   double   low;
   double   close;
   double   emaFast;
   double   emaSlow;
   double   retestCloseLocation;
   int      barsSinceBreakout;
  };

struct BreakoutSetup
  {
   bool     active;
   datetime breakoutTime;
   double   breakoutLevel;
   double   midpointLevel;
   int      direction;
  };

BreakoutSetup sellSetup;

int debugBreakouts = 0;
int debugSetupOverwrites = 0;
int debugSetupExpired = 0;
int debugMidpointInvalidations = 0;
int debugSessionChecks = 0;
int debugTouchChecks = 0;
int debugQualifiedSignals = 0;
int debugSpreadBlocks = 0;
int debugPositionBlocks = 0;
int debugDailyTradeBlocks = 0;
int debugDailyLossBlocks = 0;
int debugEquityBlocks = 0;
int debugVolumeBlocks = 0;
int debugOrdersPlaced = 0;

int OnInit()
  {
   runtimeSymbol = NormalizePresetString(InpSymbol);
   runtimeAllowedWeekdays = NormalizePresetString(InpAllowedWeekdays);
   runtimeBlockedEntryHours = NormalizePresetString(InpBlockedEntryHours);

   ArrayInitialize(allowedWeekdays, false);
   ArrayInitialize(blockedHours, false);

   if(InpMagicNumber <= 0 || InpEMAFastPeriod <= 0 || InpEMASlowPeriod <= 0 ||
      InpZoneStepPips <= 0.0 || InpTouchLookbackBars <= 0 || InpBreakoutExpiryBars <= 0 ||
      InpMaxRetestDelayBars <= 0 || InpMinBreakoutBodyPips <= 0.0 || InpStopLossPips <= 0.0 ||
      InpTargetRMultiple < 0.0 || InpRiskPercent <= 0.0 || InpMaxHoldBars < 0 ||
      InpMaxTradesPerDay < 0 || InpMaxOpenTrades < 0 || InpMaxEffectiveRiskPercentAtMinLot < 0.0)
     {
      Print("Invalid zone-escape parameters.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!ParseIntList(runtimeAllowedWeekdays, allowedWeekdays, 7) ||
      !ParseIntList(runtimeBlockedEntryHours, blockedHours, 24))
     {
      Print("Invalid weekday or blocked-hour filters.");
      return INIT_PARAMETERS_INCORRECT;
     }

   trade.SetExpertMagicNumber((ulong)InpMagicNumber);
   SetTradeDeviation();

   emaFastHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(emaFastHandle == INVALID_HANDLE || emaSlowHandle == INVALID_HANDLE)
     {
      Print("Failed to create EMA handles.");
      return INIT_FAILED;
     }

   sellSetup.active = false;
   sellSetup.breakoutTime = 0;
   sellSetup.breakoutLevel = 0.0;
   sellSetup.midpointLevel = 0.0;
   sellSetup.direction = -1;

   InitializeDayState(TimeCurrent());
   equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if((bool)MQLInfoInteger(MQL_TESTER))
     {
      PrintFormat("zone_escape debug: breakouts=%d overwrites=%d expired=%d midpoint_invalid=%d session=%d touch=%d qualified=%d spread_blocks=%d position_blocks=%d daily_trade_blocks=%d daily_loss_blocks=%d equity_blocks=%d volume_blocks=%d orders=%d",
                  debugBreakouts,
                  debugSetupOverwrites,
                  debugSetupExpired,
                  debugMidpointInvalidations,
                  debugSessionChecks,
                  debugTouchChecks,
                  debugQualifiedSignals,
                  debugSpreadBlocks,
                  debugPositionBlocks,
                  debugDailyTradeBlocks,
                  debugDailyLossBlocks,
                  debugEquityBlocks,
                  debugVolumeBlocks,
                  debugOrdersPlaced);
     }

   ReleaseHandle(emaFastHandle);
   ReleaseHandle(emaSlowHandle);
  }

void OnTick()
  {
   UpdateDayState(TimeCurrent());
   UpdateEquityPeak();
   ManageTimedExits();

   datetime currentBar = iTime(runtimeSymbol, InpSignalTimeframe, 0);
   if(currentBar == 0 || currentBar == lastBarTime)
      return;

   lastBarTime = currentBar;

   RefreshBreakoutSetup();

   SignalContext ctx;
   if(!LoadSignalContext(ctx))
      return;

   bool shortSignal = (InpEnableSell && IsShortSignal(ctx));
   if(!shortSignal)
      return;

   if(!CanOpenNewEntries(ctx))
      return;

   OpenShortPosition();
  }

string NormalizePresetString(string rawValue)
  {
   int marker = StringFind(rawValue, "||");
   if(marker < 0)
      return rawValue;
   return StringSubstr(rawValue, 0, marker);
  }

void ReleaseHandle(int &handle)
  {
   if(handle != INVALID_HANDLE)
     {
      IndicatorRelease(handle);
      handle = INVALID_HANDLE;
     }
  }

bool ParseIntList(string value, bool &target[], int maxItems)
  {
   ArrayInitialize(target, false);
   string cleaned = value;
   StringReplace(cleaned, " ", "");
   if(StringLen(cleaned) == 0)
      return true;

   string parts[];
   int count = StringSplit(cleaned, ',', parts);
   if(count <= 0)
      return false;

   for(int i = 0; i < count; ++i)
     {
      int item = (int)StringToInteger(parts[i]);
      if(item < 0 || item >= maxItems)
         return false;
      target[item] = true;
     }

   return true;
  }

void SetTradeDeviation()
  {
   if(InpMaxDeviationPips <= 0.0)
      return;

   double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   double pip = GetPipSize();
   if(point <= 0.0 || pip <= 0.0)
      return;

   int deviationPoints = (int)MathMax(0.0, MathRound(InpMaxDeviationPips * pip / point));
   trade.SetDeviationInPoints(deviationPoints);
  }

double GetPipSize()
  {
   double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

void InitializeDayState(datetime now)
  {
   MqlDateTime tm;
   TimeToStruct(now, tm);
   tm.hour = 0;
   tm.min = 0;
   tm.sec = 0;
   currentDayStart = StructToTime(tm);
   dailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   dailyTradeCount = 0;
  }

void UpdateDayState(datetime now)
  {
   if(currentDayStart == 0)
     {
      InitializeDayState(now);
      return;
     }

   if(now >= currentDayStart + 86400)
      InitializeDayState(now);
  }

void UpdateEquityPeak()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity > equityPeak)
      equityPeak = equity;
  }

double NormalizePrice(double price)
  {
   int digits = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
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

double GetSpreadPips()
  {
   double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   if(point <= 0.0)
      return DBL_MAX;
   return (double)SymbolInfoInteger(runtimeSymbol, SYMBOL_SPREAD) * point / GetPipSize();
  }

bool HourInWindow(int hour, int startHour, int endHour)
  {
   if(startHour == endHour)
      return true;
   if(startHour < endHour)
      return hour >= startHour && hour < endHour;
   return hour >= startHour || hour < endHour;
  }

bool SameZone(int startShift, int lookback, double stepPrice)
  {
   double highest = -DBL_MAX;
   double lowest = DBL_MAX;
   for(int shift = startShift; shift < startShift + lookback; ++shift)
     {
      double barHigh = iHigh(runtimeSymbol, InpSignalTimeframe, shift);
      double barLow = iLow(runtimeSymbol, InpSignalTimeframe, shift);
      if(barHigh <= 0.0 || barLow <= 0.0)
         return false;
      if(barHigh > highest)
         highest = barHigh;
      if(barLow < lowest)
         lowest = barLow;
     }

   return (int)MathFloor(highest / stepPrice) == (int)MathFloor(lowest / stepPrice);
  }

double AverageBodyPips(int startShift, int lookback, double pip)
  {
   double total = 0.0;
   int count = 0;
   for(int shift = startShift; shift < startShift + lookback; ++shift)
     {
      double openValue = iOpen(runtimeSymbol, InpSignalTimeframe, shift);
      double closeValue = iClose(runtimeSymbol, InpSignalTimeframe, shift);
      if(openValue <= 0.0 || closeValue <= 0.0)
         return 0.0;
      total += MathAbs(closeValue - openValue) / pip;
      count++;
     }

   if(count <= 0)
      return 0.0;
   return total / count;
  }

int CountRoundTouches(double roundLevel, double tolerance, int startShift, int lookback)
  {
   int touches = 0;
   for(int shift = startShift; shift < startShift + lookback; ++shift)
     {
      double barHigh = iHigh(runtimeSymbol, InpSignalTimeframe, shift);
      double barLow = iLow(runtimeSymbol, InpSignalTimeframe, shift);
      if(barHigh <= 0.0 || barLow <= 0.0)
         return InpTouchLookbackBars + 1;
      if(barHigh >= roundLevel - tolerance && barLow <= roundLevel + tolerance)
         touches++;
     }

   return touches;
  }

double CloseLocation(double highValue, double lowValue, double closeValue)
  {
   double range = highValue - lowValue;
   if(range <= 0.0)
      return 0.5;
   return (closeValue - lowValue) / range;
  }

double FindBreakoutLevel(double openValue, double highValue, double lowValue, double closeValue, int direction, double stepPrice)
  {
   int startIndex = (int)MathFloor(lowValue / stepPrice) - 1;
   int endIndex = (int)MathCeil(highValue / stepPrice) + 1;
   for(int idx = startIndex; idx <= endIndex; ++idx)
     {
      double candidate = idx * stepPrice;
      if(direction > 0 && openValue < candidate && closeValue > candidate)
         return candidate;
      if(direction < 0 && openValue > candidate && closeValue < candidate)
         return candidate;
     }

   return DBL_MAX;
  }

bool DetectSellBreakout()
  {
   double pip = GetPipSize();
   double stepPrice = InpZoneStepPips * pip;
   double touchTolerance = InpTouchTolerancePips * pip;

   double emaFast[1];
   double emaSlowCurrent[1];
   double emaSlowPast[1];
   if(CopyBuffer(emaFastHandle, 0, 1, 1, emaFast) != 1 ||
      CopyBuffer(emaSlowHandle, 0, 1, 1, emaSlowCurrent) != 1 ||
      CopyBuffer(emaSlowHandle, 0, 1 + InpBreakoutSlopeLookback, 1, emaSlowPast) != 1)
      return false;

   double openValue = iOpen(runtimeSymbol, InpSignalTimeframe, 1);
   double highValue = iHigh(runtimeSymbol, InpSignalTimeframe, 1);
   double lowValue = iLow(runtimeSymbol, InpSignalTimeframe, 1);
   double closeValue = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   datetime barTime = iTime(runtimeSymbol, InpSignalTimeframe, 1);
   if(openValue <= 0.0 || highValue <= 0.0 || lowValue <= 0.0 || closeValue <= 0.0 || barTime == 0)
      return false;

   MqlDateTime tm;
   TimeToStruct(barTime, tm);
   if(tm.day_of_week == 0 || tm.day_of_week == 6)
      return false;

   double slowSlopePips = (emaSlowCurrent[0] - emaSlowPast[0]) / pip;
   if(slowSlopePips >= 0.0)
      return false;

   if(closeValue >= emaFast[0] || emaFast[0] >= emaSlowCurrent[0] || closeValue >= emaSlowCurrent[0])
      return false;

   double breakoutLevel = FindBreakoutLevel(openValue, highValue, lowValue, closeValue, -1, stepPrice);
   if(breakoutLevel == DBL_MAX)
      return false;

   double bodyPips = MathAbs(closeValue - openValue) / pip;
   double rangePips = (highValue - lowValue) / pip;
   if(bodyPips < InpMinBreakoutBodyPips || rangePips <= 0.0)
      return false;

   double bodyToRange = bodyPips / rangePips;
   if(bodyToRange < InpMinBodyToRange)
      return false;

   double avgBody = AverageBodyPips(2, InpAverageBodyLookback, pip);
   if(avgBody <= 0.0)
      return false;

   double bodyVsAvg = bodyPips / avgBody;
   if(bodyVsAvg < InpMinBodyVsAvg)
      return false;

   if(InpRequireNotSameZone48 && SameZone(2, InpZoneLookback48, stepPrice))
      return false;

   int priorTouches = CountRoundTouches(breakoutLevel, touchTolerance, 2, InpTouchLookbackBars);
   if(priorTouches > InpMaxPriorTouches)
      return false;

   if(sellSetup.active && (bool)MQLInfoInteger(MQL_TESTER))
      debugSetupOverwrites++;

   sellSetup.active = true;
   sellSetup.breakoutTime = barTime;
   sellSetup.breakoutLevel = breakoutLevel;
   sellSetup.midpointLevel = breakoutLevel - (0.5 * stepPrice);
   sellSetup.direction = -1;
   if((bool)MQLInfoInteger(MQL_TESTER))
      debugBreakouts++;
   return true;
  }

void RefreshBreakoutSetup()
  {
   if(sellSetup.active)
     {
      int breakoutShift = iBarShift(runtimeSymbol, InpSignalTimeframe, sellSetup.breakoutTime, false);
      if(breakoutShift < 0 || breakoutShift - 1 > InpBreakoutExpiryBars)
        {
         sellSetup.active = false;
         if((bool)MQLInfoInteger(MQL_TESTER))
            debugSetupExpired++;
        }
     }

   DetectSellBreakout();
  }

bool LoadSignalContext(SignalContext &ctx)
  {
   double emaFast[1];
   double emaSlow[1];
   if(CopyBuffer(emaFastHandle, 0, 1, 1, emaFast) != 1 ||
      CopyBuffer(emaSlowHandle, 0, 1, 1, emaSlow) != 1)
      return false;

   datetime barTime = iTime(runtimeSymbol, InpSignalTimeframe, 1);
   double openValue = iOpen(runtimeSymbol, InpSignalTimeframe, 1);
   double highValue = iHigh(runtimeSymbol, InpSignalTimeframe, 1);
   double lowValue = iLow(runtimeSymbol, InpSignalTimeframe, 1);
   double closeValue = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   if(barTime == 0 || openValue <= 0.0 || highValue <= 0.0 || lowValue <= 0.0 || closeValue <= 0.0)
      return false;

   MqlDateTime tm;
   TimeToStruct(barTime, tm);

   ctx.barTime = barTime;
   ctx.hour = tm.hour;
   ctx.weekday = tm.day_of_week;
   ctx.open = openValue;
   ctx.high = highValue;
   ctx.low = lowValue;
   ctx.close = closeValue;
   ctx.emaFast = emaFast[0];
   ctx.emaSlow = emaSlow[0];
   ctx.retestCloseLocation = 1.0 - CloseLocation(highValue, lowValue, closeValue);
   ctx.barsSinceBreakout = -1;

   if(sellSetup.active)
     {
      int breakoutShift = iBarShift(runtimeSymbol, InpSignalTimeframe, sellSetup.breakoutTime, false);
      if(breakoutShift >= 0)
         ctx.barsSinceBreakout = breakoutShift - 1;
     }

   return true;
  }

bool CanOpenNewEntries(const SignalContext &ctx)
  {
   if(ctx.weekday < 0 || ctx.weekday > 6 || !allowedWeekdays[ctx.weekday])
      return false;

   if(ctx.hour >= 0 && ctx.hour < 24 && blockedHours[ctx.hour])
      return false;

   if(GetSpreadPips() > InpMaxSpreadPips)
     {
      if((bool)MQLInfoInteger(MQL_TESTER))
         debugSpreadBlocks++;
      return false;
     }

   if(CountManagedPositions() >= InpMaxOpenTrades)
     {
      if((bool)MQLInfoInteger(MQL_TESTER))
         debugPositionBlocks++;
      return false;
     }

   if(InpMaxTradesPerDay > 0 && dailyTradeCount >= InpMaxTradesPerDay)
     {
      if((bool)MQLInfoInteger(MQL_TESTER))
         debugDailyTradeBlocks++;
      return false;
     }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(InpUseDailyLossCap && dailyStartEquity > 0.0)
     {
      double dailyLossPct = 100.0 * (dailyStartEquity - equity) / dailyStartEquity;
      if(dailyLossPct >= InpDailyLossCapPercent)
        {
         if((bool)MQLInfoInteger(MQL_TESTER))
            debugDailyLossBlocks++;
         return false;
        }
     }

   if(InpUseEquityKillSwitch && equityPeak > 0.0)
     {
      double peakDrawdownPct = 100.0 * (equityPeak - equity) / equityPeak;
      if(peakDrawdownPct >= InpEquityKillSwitchPercent)
        {
         if((bool)MQLInfoInteger(MQL_TESTER))
            debugEquityBlocks++;
         return false;
        }
     }

   return true;
  }

bool IsShortSignal(const SignalContext &ctx)
  {
   if(!sellSetup.active)
      return false;

   if(!HourInWindow(ctx.hour, InpSellStartHour, InpSellEndHour))
      return false;

   if((bool)MQLInfoInteger(MQL_TESTER))
      debugSessionChecks++;

   if(ctx.barsSinceBreakout <= 0)
      return false;

   if(ctx.barsSinceBreakout > InpBreakoutExpiryBars || ctx.barsSinceBreakout > InpMaxRetestDelayBars)
     {
      sellSetup.active = false;
      return false;
     }

   double pip = GetPipSize();
   double touchTolerance = InpTouchTolerancePips * pip;
   double retestBuffer = InpRetestBufferPips * pip;
   double midpointBuffer = InpMidpointBufferPips * pip;

   if(ctx.low <= sellSetup.midpointLevel + midpointBuffer)
     {
      sellSetup.active = false;
      if((bool)MQLInfoInteger(MQL_TESTER))
         debugMidpointInvalidations++;
      return false;
     }

   bool touchedFast = (ctx.low <= ctx.emaFast + touchTolerance && ctx.high >= ctx.emaFast - touchTolerance);
   if(!touchedFast)
      return false;

   if((bool)MQLInfoInteger(MQL_TESTER))
      debugTouchChecks++;

   if(ctx.high > sellSetup.breakoutLevel + retestBuffer)
      return false;

   if(ctx.close > sellSetup.breakoutLevel || ctx.close > ctx.emaFast || ctx.close > ctx.emaSlow)
      return false;

   if(ctx.retestCloseLocation < InpMinRetestCloseLocation)
      return false;

   if((bool)MQLInfoInteger(MQL_TESTER))
      debugQualifiedSignals++;
   return true;
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

double CalculateVolume(double stopDistance)
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = equity * (InpRiskPercent / 100.0);
   if(riskAmount <= 0.0)
      return 0.0;

   double tickSize = SymbolInfoDouble(runtimeSymbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(runtimeSymbol, SYMBOL_TRADE_TICK_VALUE);
   double minVolume = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_MAX);
   double stepVolume = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_STEP);
   if(tickSize <= 0.0 || tickValue <= 0.0 || minVolume <= 0.0 || maxVolume <= 0.0 || stepVolume <= 0.0)
      return 0.0;

   double moneyPerLot = (stopDistance / tickSize) * tickValue;
   if(moneyPerLot <= 0.0)
      return 0.0;

   if(InpSkipTradeWhenMinLotRiskTooHigh)
     {
      double minLotRiskPercent = 100.0 * (moneyPerLot * minVolume) / equity;
      if(minLotRiskPercent > InpMaxEffectiveRiskPercentAtMinLot)
         return 0.0;
     }

   double rawVolume = riskAmount / moneyPerLot;
   double normalized = MathFloor(rawVolume / stepVolume) * stepVolume;
   if(normalized < minVolume)
      return 0.0;
   if(normalized > maxVolume)
      normalized = maxVolume;

   return NormalizeDouble(normalized, VolumeDigits(stepVolume));
  }

void OpenShortPosition()
  {
   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   if(bid <= 0.0)
      return;

   double pip = GetPipSize();
   double stopDistance = InpStopLossPips * pip;
   if(stopDistance <= 0.0)
      return;

   double sl = NormalizePrice(bid + stopDistance);
   double tp = 0.0;
   if(InpTargetRMultiple > 0.0)
      tp = NormalizePrice(bid - (stopDistance * InpTargetRMultiple));

   double volume = CalculateVolume(stopDistance);
   if(volume <= 0.0)
     {
      if((bool)MQLInfoInteger(MQL_TESTER))
         debugVolumeBlocks++;
      return;
     }

   if(trade.Sell(volume, runtimeSymbol, 0.0, sl, tp, "zone_escape_short"))
     {
      dailyTradeCount++;
      sellSetup.active = false;
      if((bool)MQLInfoInteger(MQL_TESTER))
         debugOrdersPlaced++;
     }
   else
     {
      Print("Order failed: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
     }
  }

void ManageTimedExits()
  {
   if(InpMaxHoldBars <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      datetime openedAt = (datetime)PositionGetInteger(POSITION_TIME);
      int shift = iBarShift(runtimeSymbol, InpSignalTimeframe, openedAt, false);
      if(shift < 0 || shift < InpMaxHoldBars)
         continue;

      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      if(!trade.PositionClose(ticket))
         Print("Timed exit failed for ticket ", ticket, ": ", trade.ResultRetcodeDescription());
     }
  }
