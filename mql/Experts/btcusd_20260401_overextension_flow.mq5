//+------------------------------------------------------------------+
//| BTCUSD Overextension Flow Prototype                              |
//+------------------------------------------------------------------+
#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "1.00"
#property strict
#property description "BTCUSD M5 high-turnover overextension fade with asymmetric flow filters"

#include <Trade\Trade.mqh>

CTrade trade;

enum ShortRuleMode
  {
   ShortRuleRet6Flow = 0,
   ShortRuleHighBreak = 1,
   ShortRuleBreakoutRsi = 2,
   ShortRuleFlowOnly = 3
  };

input string          InpSymbol                      = "BTCUSD";
input ENUM_TIMEFRAMES InpSignalTimeframe             = PERIOD_M5;
input int             InpATRPeriod                   = 14;
input int             InpRSIPeriod                   = 7;

input bool            InpEnableLong                  = true;
input int             InpLongStartHour               = 0;
input int             InpLongEndHour                 = 24;
input double          InpLongRocAtrMax              = -1.3739;
input double          InpLongRsiMax                 = 29.5772;
input bool            InpUseLongFlowFilter          = false;
input double          InpLongTickFlowMax            = -0.4165;
input int             InpLongHoldBars               = 3;
input double          InpLongStopATR                = 1.00;
input double          InpLongTargetRMultiple        = 1.25;

input bool            InpEnableShort                 = true;
input int             InpShortStartHour              = 0;
input int             InpShortEndHour                = 24;
input int             InpShortRuleMode              = ShortRuleHighBreak;
input double          InpShortRsiMin                = 70.3714;
input double          InpShortRet6Min               = 0.0017;
input double          InpShortHighBreakMin          = -0.5768;
input double          InpShortBreakoutPersistMin    = 1.0;
input bool            InpUseShortFlowFilter         = true;
input double          InpShortTickFlowMin           = 0.4176;
input int             InpShortHoldBars              = 6;
input double          InpShortStopATR               = 1.00;
input double          InpShortTargetRMultiple       = 1.25;

input double          InpRiskPercent                = 0.35;
input bool            InpSkipTradeWhenMinLotRiskTooHigh = true;
input double          InpMaxEffectiveRiskPercentAtMinLot = 1.00;

input bool            InpUseDailyLossCap            = true;
input double          InpDailyLossCapPercent        = 3.0;
input bool            InpUseEquityKillSwitch        = true;
input double          InpEquityKillSwitchPercent    = 12.0;
input int             InpMaxTradesPerDay            = 60;
input int             InpMaxOpenTrades              = 1;
input int             InpMaxOpenPerSide             = 1;
input double          InpMaxSpreadPips             = 2500.0;
input double          InpMaxDeviationPips          = 250.0;
input string          InpAllowedWeekdays           = "0,1,2,3,4,5,6";
input string          InpBlockedEntryHours         = "";
input long            InpMagicNumber               = 20260401;

int atrHandle = INVALID_HANDLE;
int rsiHandle = INVALID_HANDLE;

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
   double   close;
   double   atr;
   double   rsi;
   double   ret6;
   double   rocAtr6;
   double   highBreak12;
   double   breakoutPersistUp6;
   double   tickFlowSigned3;
  };

int OnInit()
  {
   runtimeSymbol = NormalizePresetString(InpSymbol);
   runtimeAllowedWeekdays = NormalizePresetString(InpAllowedWeekdays);
   runtimeBlockedEntryHours = NormalizePresetString(InpBlockedEntryHours);
   ArrayInitialize(allowedWeekdays, false);
   ArrayInitialize(blockedHours, false);

   if(InpMagicNumber <= 0 || InpATRPeriod <= 0 || InpRSIPeriod <= 0 || InpRiskPercent <= 0.0 ||
      InpLongHoldBars < 0 || InpShortHoldBars < 0 || InpLongStopATR <= 0.0 || InpShortStopATR <= 0.0 ||
      InpLongTargetRMultiple < 0.0 || InpShortTargetRMultiple < 0.0 || InpMaxTradesPerDay < 0 ||
      InpMaxOpenTrades < 0 || InpMaxOpenPerSide < 0 || InpMaxEffectiveRiskPercentAtMinLot < 0.0 ||
      InpShortRuleMode < ShortRuleRet6Flow || InpShortRuleMode > ShortRuleFlowOnly)
     {
      Print("Invalid overextension-flow parameters.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!ParseIntList(runtimeAllowedWeekdays, allowedWeekdays, 7) || !ParseIntList(runtimeBlockedEntryHours, blockedHours, 24))
     {
      Print("Invalid weekday or blocked-hour filters.");
      return INIT_PARAMETERS_INCORRECT;
     }

   trade.SetExpertMagicNumber((ulong)InpMagicNumber);
   SetTradeDeviation();

   atrHandle = iATR(runtimeSymbol, InpSignalTimeframe, InpATRPeriod);
   rsiHandle = iRSI(runtimeSymbol, InpSignalTimeframe, InpRSIPeriod, PRICE_CLOSE);

   if(atrHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE)
     {
      Print("Failed to create indicator handles.");
      return INIT_FAILED;
     }

   InitializeDayState(TimeCurrent());
   equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);
   return INIT_SUCCEEDED;
  }

string NormalizePresetString(string rawValue)
  {
   int marker = StringFind(rawValue, "||");
   if(marker < 0)
      return rawValue;
   return StringSubstr(rawValue, 0, marker);
  }

void OnDeinit(const int reason)
  {
   ReleaseHandle(atrHandle);
   ReleaseHandle(rsiHandle);
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

   SignalContext ctx;
   if(!LoadSignalContext(ctx))
      return;

   if(!CanOpenNewEntries(ctx))
      return;

   bool longSignal = IsLongSignal(ctx);
   bool shortSignal = IsShortSignal(ctx);

   if(longSignal && CountManagedPositions(POSITION_TYPE_BUY) < InpMaxOpenPerSide)
      OpenPosition(POSITION_TYPE_BUY, ctx);

   if(shortSignal && CountManagedPositions(POSITION_TYPE_SELL) < InpMaxOpenPerSide)
      OpenPosition(POSITION_TYPE_SELL, ctx);
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

bool LoadSignalContext(SignalContext &ctx)
  {
   double atr[1];
   double rsi[1];

   if(CopyBuffer(atrHandle, 0, 1, 1, atr) != 1 || CopyBuffer(rsiHandle, 0, 1, 1, rsi) != 1)
      return false;

   if(atr[0] <= 0.0)
      return false;

   datetime barTime = iTime(runtimeSymbol, InpSignalTimeframe, 1);
   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   double close7 = iClose(runtimeSymbol, InpSignalTimeframe, 7);
   if(barTime == 0 || close1 <= 0.0 || close7 <= 0.0)
      return false;

   double tickFlowSigned3 = ComputeTickFlowSigned3();
   double highBreak12 = ComputeHighBreak12();
   double breakoutPersistUp6 = ComputeBreakoutPersistUp6();
   if(tickFlowSigned3 == DBL_MAX || highBreak12 == DBL_MAX || breakoutPersistUp6 == DBL_MAX)
      return false;

   MqlDateTime tm;
   TimeToStruct(barTime, tm);

   ctx.barTime = barTime;
   ctx.hour = tm.hour;
   ctx.weekday = tm.day_of_week;
   ctx.close = close1;
   ctx.atr = atr[0];
   ctx.rsi = rsi[0];
   ctx.ret6 = (close1 - close7) / close7;
   ctx.rocAtr6 = (close1 - close7) / atr[0];
   ctx.highBreak12 = highBreak12;
   ctx.breakoutPersistUp6 = breakoutPersistUp6;
   ctx.tickFlowSigned3 = tickFlowSigned3;
   return true;
  }

double ComputePreviousHigh(int startShift, int lookback)
  {
   double highest = -DBL_MAX;
   for(int shift = startShift; shift < startShift + lookback; ++shift)
     {
      double barHigh = iHigh(runtimeSymbol, InpSignalTimeframe, shift);
      if(barHigh <= 0.0)
         return DBL_MAX;
      if(barHigh > highest)
         highest = barHigh;
     }
   return highest;
  }

double ComputeHighBreak12()
  {
   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   double atr1 = 0.0;
   double atr[1];
   if(CopyBuffer(atrHandle, 0, 1, 1, atr) != 1)
      return DBL_MAX;
   atr1 = atr[0];
   if(close1 <= 0.0 || atr1 <= 0.0)
      return DBL_MAX;

   double prevHigh12 = ComputePreviousHigh(2, 12);
   if(prevHigh12 == DBL_MAX)
      return DBL_MAX;

   return (close1 - prevHigh12) / atr1;
  }

double ComputeBreakoutPersistUp6()
  {
   double total = 0.0;
   for(int shift = 1; shift <= 6; ++shift)
     {
      double closeValue = iClose(runtimeSymbol, InpSignalTimeframe, shift);
      if(closeValue <= 0.0)
         return DBL_MAX;
      double prevHigh12 = ComputePreviousHigh(shift + 1, 12);
      if(prevHigh12 == DBL_MAX)
         return DBL_MAX;
      if(closeValue > prevHigh12)
         total += 1.0;
     }
   return total;
  }

double ComputeTickVolumeRel10(int shift)
  {
   double currentVolume = (double)iVolume(runtimeSymbol, InpSignalTimeframe, shift);
   if(currentVolume <= 0.0)
      return DBL_MAX;

   double sumVolume = 0.0;
   for(int i = shift; i < shift + 10; ++i)
     {
      double sample = (double)iVolume(runtimeSymbol, InpSignalTimeframe, i);
      if(sample <= 0.0)
         return DBL_MAX;
      sumVolume += sample;
     }

   double averageVolume = sumVolume / 10.0;
   if(averageVolume <= 0.0)
      return DBL_MAX;
   return currentVolume / averageVolume;
  }

double ComputeTickFlowSigned3()
  {
   double flow = 0.0;
   for(int shift = 1; shift <= 3; ++shift)
     {
      double closeNow = iClose(runtimeSymbol, InpSignalTimeframe, shift);
      double closePrev = iClose(runtimeSymbol, InpSignalTimeframe, shift + 1);
      if(closeNow <= 0.0 || closePrev <= 0.0)
         return DBL_MAX;

      double volRel = ComputeTickVolumeRel10(shift);
      if(volRel == DBL_MAX)
         return DBL_MAX;

      double direction = 0.0;
      if(closeNow > closePrev)
         direction = 1.0;
      else if(closeNow < closePrev)
         direction = -1.0;

      flow += direction * volRel;
     }

   return flow / 3.0;
  }

bool CanOpenNewEntries(const SignalContext &ctx)
  {
   if(ctx.weekday < 0 || ctx.weekday > 6 || !allowedWeekdays[ctx.weekday])
      return false;

   if(ctx.hour >= 0 && ctx.hour < 24 && blockedHours[ctx.hour])
      return false;

   if(GetSpreadPips() > InpMaxSpreadPips)
      return false;

   if(CountManagedPositions(-1) >= InpMaxOpenTrades)
      return false;

   if(InpMaxTradesPerDay > 0 && dailyTradeCount >= InpMaxTradesPerDay)
      return false;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(InpUseDailyLossCap && dailyStartEquity > 0.0)
     {
      double dailyLossPct = 100.0 * (dailyStartEquity - equity) / dailyStartEquity;
      if(dailyLossPct >= InpDailyLossCapPercent)
         return false;
     }

   if(InpUseEquityKillSwitch && equityPeak > 0.0)
     {
      double peakDrawdownPct = 100.0 * (equityPeak - equity) / equityPeak;
      if(peakDrawdownPct >= InpEquityKillSwitchPercent)
         return false;
     }

   return true;
  }

bool IsLongSignal(const SignalContext &ctx)
  {
   if(!InpEnableLong || !HourInWindow(ctx.hour, InpLongStartHour, InpLongEndHour))
      return false;

   if(ctx.rocAtr6 > InpLongRocAtrMax)
      return false;

   if(ctx.rsi > InpLongRsiMax)
      return false;

   if(InpUseLongFlowFilter && ctx.tickFlowSigned3 > InpLongTickFlowMax)
      return false;

   return true;
  }

bool IsShortSignal(const SignalContext &ctx)
  {
   if(!InpEnableShort || !HourInWindow(ctx.hour, InpShortStartHour, InpShortEndHour))
      return false;

   if(ctx.rsi < InpShortRsiMin)
      return false;

   if(InpShortRuleMode == ShortRuleRet6Flow)
     {
      if(ctx.ret6 < InpShortRet6Min)
         return false;
      if(InpUseShortFlowFilter && ctx.tickFlowSigned3 < InpShortTickFlowMin)
         return false;
     }
   else if(InpShortRuleMode == ShortRuleHighBreak)
     {
      if(ctx.highBreak12 < InpShortHighBreakMin)
         return false;
      if(InpUseShortFlowFilter && ctx.tickFlowSigned3 < InpShortTickFlowMin)
         return false;
     }
   else if(InpShortRuleMode == ShortRuleBreakoutRsi)
     {
      if(ctx.breakoutPersistUp6 < InpShortBreakoutPersistMin)
         return false;
      if(InpUseShortFlowFilter && ctx.tickFlowSigned3 < InpShortTickFlowMin)
         return false;
     }
   else if(InpShortRuleMode == ShortRuleFlowOnly)
     {
      if(ctx.tickFlowSigned3 < InpShortTickFlowMin)
         return false;
     }

   return true;
  }

bool HourInWindow(int hour, int startHour, int endHour)
  {
   if(startHour == endHour)
      return true;

   if(startHour < endHour)
      return hour >= startHour && hour < endHour;

   return hour >= startHour || hour < endHour;
  }

double GetSpreadPips()
  {
   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   double pip = GetPipSize();
   if(ask <= 0.0 || bid <= 0.0 || pip <= 0.0)
      return 0.0;
   return (ask - bid) / pip;
  }

int CountManagedPositions(int desiredType)
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      int type = (int)PositionGetInteger(POSITION_TYPE);
      if(desiredType >= 0 && type != desiredType)
         continue;
      count++;
     }
   return count;
  }

void OpenPosition(int positionType, const SignalContext &ctx)
  {
   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   double price = (positionType == POSITION_TYPE_BUY) ? ask : bid;
   if(price <= 0.0)
      return;

   double stopAtr = (positionType == POSITION_TYPE_BUY) ? InpLongStopATR : InpShortStopATR;
   double targetR = (positionType == POSITION_TYPE_BUY) ? InpLongTargetRMultiple : InpShortTargetRMultiple;
   double stopDistance = ctx.atr * stopAtr;
   if(stopDistance <= 0.0)
      return;

   double sl = 0.0;
   double tp = 0.0;
   if(positionType == POSITION_TYPE_BUY)
     {
      sl = NormalizePrice(price - stopDistance);
      if(targetR > 0.0)
         tp = NormalizePrice(price + stopDistance * targetR);
     }
   else
     {
      sl = NormalizePrice(price + stopDistance);
      if(targetR > 0.0)
         tp = NormalizePrice(price - stopDistance * targetR);
     }

   double volume = CalculateVolume(stopDistance);
   if(volume <= 0.0)
      return;

   bool result = false;
   if(positionType == POSITION_TYPE_BUY)
      result = trade.Buy(volume, runtimeSymbol, 0.0, sl, tp, "overextension_flow_long");
   else
      result = trade.Sell(volume, runtimeSymbol, 0.0, sl, tp, "overextension_flow_short");

   if(result)
      dailyTradeCount++;
   else
      Print("Order failed: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
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

double NormalizePrice(double price)
  {
   int digits = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
  }

void ManageTimedExits()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      int type = (int)PositionGetInteger(POSITION_TYPE);
      int holdBars = (type == POSITION_TYPE_BUY) ? InpLongHoldBars : InpShortHoldBars;
      if(holdBars <= 0)
         continue;

      datetime openedAt = (datetime)PositionGetInteger(POSITION_TIME);
      int shift = iBarShift(runtimeSymbol, InpSignalTimeframe, openedAt, false);
      if(shift < 0 || shift < holdBars)
         continue;

      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      if(!trade.PositionClose(ticket))
         Print("Timed exit failed for ticket ", ticket, ": ", trade.ResultRetcodeDescription());
     }
  }
