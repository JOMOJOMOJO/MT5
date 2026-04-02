//+------------------------------------------------------------------+
//| USDJPY Regime Buckets Prototype                                 |
//+------------------------------------------------------------------+
#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "1.00"
#property strict
#property description "USDJPY M5 high-turnover prototype built from feature-lab regime buckets"

#include <Trade\Trade.mqh>

CTrade trade;

input string          InpSymbol                          = "USDJPY";
input ENUM_TIMEFRAMES InpSignalTimeframe                 = PERIOD_M5;
input int             InpATRPeriod                       = 14;

input bool            InpEnableLongBucket1              = true;
input bool            InpEnableLongBucket2              = true;
input int             InpLongStartHour                  = 0;
input int             InpLongEndHour                    = 24;
input double          InpLong1RocAtr12Max              = -1.8731;
input double          InpLong1CloseVsEma50Max          = -1.8137;
input double          InpLong2BreakoutPersistDown6Min  = 1.0;
input double          InpLong2CloseVsEma50Max          = -1.0000;
input double          InpLongEma50Slope6Max            = 0.2000;
input int             InpLongHoldBars                  = 12;
input double          InpLongStopATR                   = 1.20;
input double          InpLongTargetRMultiple           = 0.00;

input bool            InpEnableShortBucket1             = true;
input bool            InpEnableShortBucket2             = true;
input int             InpShortStartHour                 = 0;
input int             InpShortEndHour                   = 24;
input double          InpShort1CloseVsEma50Min         = 2.0675;
input double          InpShort1Ema50Slope6Min          = 0.4882;
input double          InpShort2BreakoutPersistUp6Min   = 1.0;
input double          InpShort2Rsi14Min                = 65.2672;
input double          InpShort2CloseVsEma50Min         = 0.8000;
input int             InpShortHoldBars                 = 12;
input double          InpShortStopATR                  = 1.20;
input double          InpShortTargetRMultiple          = 0.00;

input double          InpRiskPercent                    = 0.35;
input bool            InpSkipTradeWhenMinLotRiskTooHigh = true;
input double          InpMaxEffectiveRiskPercentAtMinLot = 2.00;

input bool            InpUseDailyLossCap                = true;
input double          InpDailyLossCapPercent            = 3.0;
input bool            InpUseEquityKillSwitch            = true;
input double          InpEquityKillSwitchPercent        = 12.0;
input int             InpMaxTradesPerDay                = 24;
input int             InpMaxOpenTrades                  = 1;
input int             InpMaxOpenPerSide                 = 1;
input double          InpMaxSpreadPips                  = 2.0;
input double          InpMaxDeviationPips               = 2.0;
input string          InpAllowedWeekdays                = "1,2,3,4,5";
input string          InpBlockedEntryHours              = "";
input long            InpMagicNumber                    = 20260421;

int atrHandle = INVALID_HANDLE;
int ema50Handle = INVALID_HANDLE;
int rsi14Handle = INVALID_HANDLE;

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
   double   rsi14;
   double   closeVsEma50;
   double   ema50Slope6;
   double   rocAtr12;
   double   breakoutPersistUp6;
   double   breakoutPersistDown6;
  };

int OnInit()
  {
   runtimeSymbol = NormalizePresetString(InpSymbol);
   runtimeAllowedWeekdays = NormalizePresetString(InpAllowedWeekdays);
   runtimeBlockedEntryHours = NormalizePresetString(InpBlockedEntryHours);
   ArrayInitialize(allowedWeekdays, false);
   ArrayInitialize(blockedHours, false);

   if(InpMagicNumber <= 0 || InpATRPeriod <= 0 || InpRiskPercent <= 0.0 ||
      InpLongHoldBars < 0 || InpShortHoldBars < 0 || InpLongStopATR <= 0.0 || InpShortStopATR <= 0.0 ||
      InpLongTargetRMultiple < 0.0 || InpShortTargetRMultiple < 0.0 || InpMaxTradesPerDay < 0 ||
      InpMaxOpenTrades < 0 || InpMaxOpenPerSide < 0 || InpMaxEffectiveRiskPercentAtMinLot < 0.0)
     {
      Print("Invalid regime-buckets parameters.");
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
   ema50Handle = iMA(runtimeSymbol, InpSignalTimeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
   rsi14Handle = iRSI(runtimeSymbol, InpSignalTimeframe, 14, PRICE_CLOSE);
   if(atrHandle == INVALID_HANDLE || ema50Handle == INVALID_HANDLE || rsi14Handle == INVALID_HANDLE)
     {
      Print("Failed to create indicator handles.");
      return INIT_FAILED;
     }

   InitializeDayState(TimeCurrent());
   equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   ReleaseHandle(atrHandle);
   ReleaseHandle(ema50Handle);
   ReleaseHandle(rsi14Handle);
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

   if(IsLongSignal(ctx) && CountManagedPositions(POSITION_TYPE_BUY) < InpMaxOpenPerSide)
      OpenPosition(POSITION_TYPE_BUY, ctx);

   if(IsShortSignal(ctx) && CountManagedPositions(POSITION_TYPE_SELL) < InpMaxOpenPerSide)
      OpenPosition(POSITION_TYPE_SELL, ctx);
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

bool LoadSignalContext(SignalContext &ctx)
  {
   double atr[1];
   double ema50[7];
   double rsi14[1];
   if(CopyBuffer(atrHandle, 0, 1, 1, atr) != 1 ||
      CopyBuffer(ema50Handle, 0, 1, 7, ema50) != 7 ||
      CopyBuffer(rsi14Handle, 0, 1, 1, rsi14) != 1)
      return false;

   if(atr[0] <= 0.0 || ema50[0] <= 0.0)
      return false;

   datetime barTime = iTime(runtimeSymbol, InpSignalTimeframe, 1);
   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   double close13 = iClose(runtimeSymbol, InpSignalTimeframe, 13);
   if(barTime == 0 || close1 <= 0.0 || close13 <= 0.0)
      return false;

   double breakoutPersistUp6 = ComputeBreakoutPersist(true);
   double breakoutPersistDown6 = ComputeBreakoutPersist(false);
   if(breakoutPersistUp6 == DBL_MAX || breakoutPersistDown6 == DBL_MAX)
      return false;

   MqlDateTime tm;
   TimeToStruct(barTime, tm);

   ctx.barTime = barTime;
   ctx.hour = tm.hour;
   ctx.weekday = tm.day_of_week;
   ctx.close = close1;
   ctx.atr = atr[0];
   ctx.rsi14 = rsi14[0];
   ctx.closeVsEma50 = (close1 - ema50[0]) / atr[0];
   ctx.ema50Slope6 = (ema50[0] - ema50[6]) / atr[0];
   ctx.rocAtr12 = (close1 - close13) / atr[0];
   ctx.breakoutPersistUp6 = breakoutPersistUp6;
   ctx.breakoutPersistDown6 = breakoutPersistDown6;
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

double ComputePreviousLow(int startShift, int lookback)
  {
   double lowest = DBL_MAX;
   for(int shift = startShift; shift < startShift + lookback; ++shift)
     {
      double barLow = iLow(runtimeSymbol, InpSignalTimeframe, shift);
      if(barLow <= 0.0)
         return DBL_MAX;
      if(barLow < lowest)
         lowest = barLow;
     }
   return lowest;
  }

double ComputeBreakoutPersist(bool upward)
  {
   int count = 0;
   for(int shift = 1; shift <= 6; ++shift)
     {
      double closeValue = iClose(runtimeSymbol, InpSignalTimeframe, shift);
      if(closeValue <= 0.0)
         return DBL_MAX;

      if(upward)
        {
         double prevHigh12 = ComputePreviousHigh(shift + 1, 12);
         if(prevHigh12 == DBL_MAX)
            return DBL_MAX;
         if(closeValue > prevHigh12)
            count++;
        }
      else
        {
         double prevLow12 = ComputePreviousLow(shift + 1, 12);
         if(prevLow12 == DBL_MAX)
            return DBL_MAX;
         if(closeValue < prevLow12)
            count++;
        }
     }

   return (double)count;
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
   if(!HourInWindow(ctx.hour, InpLongStartHour, InpLongEndHour))
      return false;

   bool bucket1 = false;
   bool bucket2 = false;

   if(InpEnableLongBucket1)
     {
      bucket1 = ctx.rocAtr12 <= InpLong1RocAtr12Max &&
                ctx.closeVsEma50 <= InpLong1CloseVsEma50Max &&
                ctx.ema50Slope6 <= InpLongEma50Slope6Max;
     }

   if(InpEnableLongBucket2)
     {
      bucket2 = ctx.breakoutPersistDown6 >= InpLong2BreakoutPersistDown6Min &&
                ctx.closeVsEma50 <= InpLong2CloseVsEma50Max &&
                ctx.ema50Slope6 <= InpLongEma50Slope6Max;
     }

   return bucket1 || bucket2;
  }

bool IsShortSignal(const SignalContext &ctx)
  {
   if(!HourInWindow(ctx.hour, InpShortStartHour, InpShortEndHour))
      return false;

   bool bucket1 = false;
   bool bucket2 = false;

   if(InpEnableShortBucket1)
     {
      bucket1 = ctx.closeVsEma50 >= InpShort1CloseVsEma50Min &&
                ctx.ema50Slope6 >= InpShort1Ema50Slope6Min;
     }

   if(InpEnableShortBucket2)
     {
      bucket2 = ctx.breakoutPersistUp6 >= InpShort2BreakoutPersistUp6Min &&
                ctx.rsi14 >= InpShort2Rsi14Min &&
                ctx.closeVsEma50 >= InpShort2CloseVsEma50Min;
     }

   return bucket1 || bucket2;
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
      result = trade.Buy(volume, runtimeSymbol, 0.0, sl, tp, "regime_buckets_long");
   else
      result = trade.Sell(volume, runtimeSymbol, 0.0, sl, tp, "regime_buckets_short");

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
