//+------------------------------------------------------------------+
//| USDJPY Fractal Structure Short Guarded                           |
//+------------------------------------------------------------------+
#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "1.00"
#property strict
#property description "USDJPY short-only fractal structure method using M15 bearish trend and M5 sweep-reclaim transition."

#include <Trade\Trade.mqh>

CTrade trade;

struct PivotPoint
  {
   bool     valid;
   int      shift;
   double   price;
   datetime time;
  };

struct TrendContext
  {
   bool     valid;
   int      direction;
   PivotPoint latestHigh;
   PivotPoint previousHigh;
   PivotPoint latestLow;
   PivotPoint previousLow;
   double   ema20;
   double   ema50;
   double   atr;
   double   zoneLow;
   double   zoneHigh;
  };

struct PendingSetup
  {
   bool     active;
   datetime signalTime;
   double   signalHigh;
   double   triggerLow;
   int      barsRemaining;
  };

input string          InpSymbol                          = "USDJPY";
input ENUM_TIMEFRAMES InpTrendTimeframe                  = PERIOD_M15;
input ENUM_TIMEFRAMES InpSignalTimeframe                 = PERIOD_M5;
input int             InpTrendPivotSpan                  = 2;
input int             InpTrendScanBars                   = 220;
input int             InpFastEMAPeriod                   = 20;
input int             InpSlowEMAPeriod                   = 50;
input int             InpATRPeriod                       = 14;
input int             InpSlopeLookbackBars               = 4;
input double          InpMinSlowSlopePips                = 0.8;
input double          InpZoneATRMultiple                 = 0.40;
input double          InpMinZonePips                     = 4.0;
input int             InpLocalSweepLookbackBars          = 6;
input double          InpSweepBufferPips                 = 0.6;
input double          InpMinSignalRangePips              = 4.0;
input double          InpMinSignalBodyPips               = 1.5;
input double          InpMaxSignalCloseLocation          = 0.45;
input int             InpConfirmBreakBars                = 2;
input double          InpConfirmBreakBufferPips          = 0.2;
input double          InpStopBufferPips                  = 1.2;
input double          InpTargetRMultiple                 = 1.5;
input bool            InpUseTimeStop                     = true;
input int             InpMaxHoldBars                     = 12;
input double          InpRiskPercent                     = 0.35;
input int             InpSessionStartHour                = 0;
input int             InpSessionEndHour                  = 23;
input string          InpAllowedHours                    = "";
input double          InpMaxSpreadPips                   = 2.0;
input int             InpMaxTradesPerDay                 = 3;
input bool            InpUseDailyLossCap                 = true;
input double          InpDailyLossCapPercent             = 3.0;
input bool            InpUseEquityDrawdownCap            = true;
input double          InpEquityDrawdownCapPercent        = 8.0;
input string          InpAllowedWeekdays                 = "1,2,3,4,5";
input long            InpMagicNumber                     = 202604111;

string runtimeSymbol = "";
bool allowedWeekdays[7];
bool allowedHours[24];
datetime lastBarTime = 0;
datetime currentDayStart = 0;
double dailyStartEquity = 0.0;
double equityPeak = 0.0;
int dailyTradeCount = 0;
bool dailyLossLocked = false;
bool ddLocked = false;
int trendAtrHandle = INVALID_HANDLE;
int trendEma20Handle = INVALID_HANDLE;
int trendEma50Handle = INVALID_HANDLE;
PendingSetup pendingSetup;

string NormalizePresetString(string rawValue)
  {
   int marker = StringFind(rawValue, "||");
   if(marker < 0)
      return rawValue;
   return StringSubstr(rawValue, 0, marker);
  }

bool ParseWeekdays(string rawValue, bool &target[])
  {
   ArrayInitialize(target, false);

   string items[];
   int count = StringSplit(rawValue, ',', items);
   if(count <= 0)
      return false;

   for(int i = 0; i < count; ++i)
     {
      string item = items[i];
      StringReplace(item, " ", "");
      if(item == "")
         continue;
      int day = (int)StringToInteger(item);
      if(day < 0 || day > 6)
         return false;
      target[day] = true;
     }

   return true;
  }

bool ParseAllowedHours(string rawValue, bool &target[])
  {
   ArrayInitialize(target, false);

   string normalized = NormalizePresetString(rawValue);
   StringReplace(normalized, " ", "");
   if(normalized == "")
     {
      for(int hour = 0; hour < 24; ++hour)
         target[hour] = true;
      return true;
     }

   string items[];
   int count = StringSplit(normalized, ',', items);
   if(count <= 0)
      return false;

   for(int i = 0; i < count; ++i)
     {
      string token = items[i];
      if(token == "")
         continue;
      int dash = StringFind(token, "-");
      if(dash >= 0)
        {
         int startHour = (int)StringToInteger(StringSubstr(token, 0, dash));
         int endHour = (int)StringToInteger(StringSubstr(token, dash + 1));
         if(startHour < 0 || startHour > 23 || endHour < 0 || endHour > 23)
            return false;
         if(startHour <= endHour)
           {
            for(int hour = startHour; hour <= endHour; ++hour)
               target[hour] = true;
           }
         else
           {
            for(int hour = startHour; hour < 24; ++hour)
               target[hour] = true;
            for(int hour = 0; hour <= endHour; ++hour)
               target[hour] = true;
           }
         continue;
        }

      int hour = (int)StringToInteger(token);
      if(hour < 0 || hour > 23)
         return false;
      target[hour] = true;
     }

   return true;
  }

double GetPipSize()
  {
   double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

double PipsToPrice(double pips)
  {
   return pips * GetPipSize();
  }

double GetSpreadPips()
  {
   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   double pip = GetPipSize();
   if(ask <= 0.0 || bid <= 0.0 || pip <= 0.0)
      return DBL_MAX;
   return (ask - bid) / pip;
  }

double NormalizePrice(double price)
  {
   int digits = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
  }

bool HourInWindow(int hour, int startHour, int endHour)
  {
   if(startHour == endHour)
      return true;
   if(startHour < endHour)
      return (hour >= startHour && hour < endHour);
   return (hour >= startHour || hour < endHour);
  }

bool IsNewBar(datetime &barTime)
  {
   datetime times[];
   ArraySetAsSeries(times, true);
   if(CopyTime(runtimeSymbol, InpSignalTimeframe, 0, 2, times) < 2)
      return false;

   if(times[0] == lastBarTime)
      return false;

   lastBarTime = times[0];
   barTime = times[0];
   return true;
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
   dailyLossLocked = false;
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

bool FindLatestConfirmedPivots(ENUM_TIMEFRAMES tf,
                               int span,
                               int scanBars,
                               PivotPoint &latestHigh,
                               PivotPoint &previousHigh,
                               PivotPoint &latestLow,
                               PivotPoint &previousLow)
  {
   latestHigh.valid = false;
   previousHigh.valid = false;
   latestLow.valid = false;
   previousLow.valid = false;

   int foundHigh = 0;
   int foundLow = 0;
   int startShift = span + 1;
   int endShift = startShift + scanBars;

   for(int shift = startShift; shift <= endShift; ++shift)
     {
      if(foundHigh < 2 && IsPivotHigh(tf, shift, span))
        {
         PivotPoint pivot;
         pivot.valid = true;
         pivot.shift = shift;
         pivot.price = iHigh(runtimeSymbol, tf, shift);
         pivot.time = iTime(runtimeSymbol, tf, shift);
         if(foundHigh == 0)
            latestHigh = pivot;
         else
            previousHigh = pivot;
         foundHigh++;
        }

      if(foundLow < 2 && IsPivotLow(tf, shift, span))
        {
         PivotPoint pivot;
         pivot.valid = true;
         pivot.shift = shift;
         pivot.price = iLow(runtimeSymbol, tf, shift);
         pivot.time = iTime(runtimeSymbol, tf, shift);
         if(foundLow == 0)
            latestLow = pivot;
         else
            previousLow = pivot;
         foundLow++;
        }

      if(foundHigh >= 2 && foundLow >= 2)
         break;
     }

   return (foundHigh >= 2 && foundLow >= 2);
  }

bool BuildTrendContext(TrendContext &ctx)
  {
   ctx.valid = false;
   ctx.direction = 0;

   PivotPoint latestHigh, previousHigh, latestLow, previousLow;
   if(!FindLatestConfirmedPivots(InpTrendTimeframe,
                                 InpTrendPivotSpan,
                                 InpTrendScanBars,
                                 latestHigh,
                                 previousHigh,
                                 latestLow,
                                 previousLow))
      return false;

   double atrValues[1];
   double ema20Values[1];
   double ema50Values[1];
   double ema50SlopeValues[1];
   if(CopyBuffer(trendAtrHandle, 0, 1, 1, atrValues) != 1 ||
      CopyBuffer(trendEma20Handle, 0, 1, 1, ema20Values) != 1 ||
      CopyBuffer(trendEma50Handle, 0, 1, 1, ema50Values) != 1 ||
      CopyBuffer(trendEma50Handle, 0, 1 + InpSlopeLookbackBars, 1, ema50SlopeValues) != 1)
      return false;

   double slowSlopePips = (ema50Values[0] - ema50SlopeValues[0]) / GetPipSize();
   bool bearishDow = latestHigh.price < previousHigh.price && latestLow.price < previousLow.price;
   bool bearishEma = ema20Values[0] < ema50Values[0];
   bool bearishSlope = slowSlopePips <= -InpMinSlowSlopePips;
   if(!(bearishDow && bearishEma && bearishSlope))
      return false;

   double zoneWidth = MathMax(PipsToPrice(InpMinZonePips), atrValues[0] * InpZoneATRMultiple);
   ctx.valid = true;
   ctx.direction = -1;
   ctx.latestHigh = latestHigh;
   ctx.previousHigh = previousHigh;
   ctx.latestLow = latestLow;
   ctx.previousLow = previousLow;
   ctx.ema20 = ema20Values[0];
   ctx.ema50 = ema50Values[0];
   ctx.atr = atrValues[0];
   ctx.zoneLow = ema20Values[0] - zoneWidth;
   ctx.zoneHigh = ema20Values[0] + zoneWidth;
   return true;
  }

bool CountRecentManagedPositions(datetime sinceTime)
  {
   if(!HistorySelect(sinceTime, TimeCurrent()))
      return false;

   int count = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != runtimeSymbol)
         continue;
      if((long)HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber)
         continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_IN)
         continue;
      count++;
      if(count >= dailyTradeCount)
         break;
     }

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

void FlattenManagedPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      trade.PositionClose(ticket);
     }
  }

void UpdateRiskLocks()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(InpUseDailyLossCap && dailyStartEquity > 0.0)
     {
      double dailyLossPct = 100.0 * (dailyStartEquity - equity) / dailyStartEquity;
      if(dailyLossPct >= InpDailyLossCapPercent)
         dailyLossLocked = true;
     }

   if(InpUseEquityDrawdownCap && equityPeak > 0.0)
     {
      double ddPct = 100.0 * (equityPeak - equity) / equityPeak;
      if(ddPct >= InpEquityDrawdownCapPercent)
         ddLocked = true;
     }

   if(dailyLossLocked || ddLocked)
      FlattenManagedPositions();
  }

bool PassGlobalGuards()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);

   if(tm.day_of_week < 0 || tm.day_of_week > 6 || !allowedWeekdays[tm.day_of_week])
      return false;

   if(tm.hour < 0 || tm.hour > 23 || !allowedHours[tm.hour])
      return false;

   if(!HourInWindow(tm.hour, InpSessionStartHour, InpSessionEndHour))
      return false;

   if(GetSpreadPips() > InpMaxSpreadPips)
      return false;

   if(dailyLossLocked || ddLocked)
      return false;

   if(CountManagedPositions() > 0)
      return false;

   if(InpMaxTradesPerDay > 0 && dailyTradeCount >= InpMaxTradesPerDay)
      return false;

   return true;
  }

double HighestHigh(ENUM_TIMEFRAMES tf, int startShift, int lookback)
  {
   double highest = -DBL_MAX;
   for(int shift = startShift; shift < startShift + lookback; ++shift)
     {
      double value = iHigh(runtimeSymbol, tf, shift);
      if(value <= 0.0)
         return DBL_MAX;
      if(value > highest)
         highest = value;
     }
   return highest;
  }

bool DetectNewSellSweep(const TrendContext &ctx, PendingSetup &setup)
  {
   double open1 = iOpen(runtimeSymbol, InpSignalTimeframe, 1);
   double high1 = iHigh(runtimeSymbol, InpSignalTimeframe, 1);
   double low1 = iLow(runtimeSymbol, InpSignalTimeframe, 1);
   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   if(open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;

   double rangePips = (high1 - low1) / GetPipSize();
   double bodyPips = MathAbs(open1 - close1) / GetPipSize();
   if(rangePips < InpMinSignalRangePips || bodyPips < InpMinSignalBodyPips)
      return false;

   if(close1 >= open1)
      return false;

   double range = high1 - low1;
   if(range <= 0.0)
      return false;

   double closeLocation = (close1 - low1) / range;
   if(closeLocation > InpMaxSignalCloseLocation)
      return false;

   bool insideZone = (high1 >= ctx.zoneLow && low1 <= ctx.zoneHigh);
   if(!insideZone)
      return false;

   double previousLocalHigh = HighestHigh(InpSignalTimeframe, 2, MathMax(3, InpLocalSweepLookbackBars));
   if(previousLocalHigh == DBL_MAX)
      return false;

   if(high1 <= previousLocalHigh + PipsToPrice(InpSweepBufferPips))
      return false;

   setup.active = true;
   setup.signalTime = iTime(runtimeSymbol, InpSignalTimeframe, 1);
   setup.signalHigh = high1;
   setup.triggerLow = low1;
   setup.barsRemaining = MathMax(1, InpConfirmBreakBars);
   return true;
  }

bool SetupStillValid(const PendingSetup &setup)
  {
   if(!setup.active)
      return false;

   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   if(close1 > setup.signalHigh)
      return false;

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

double CalculateVolumeByRisk(double entry, double stop)
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
   double stopDistance = MathAbs(entry - stop);
   if(tickSize <= 0.0 || tickValue <= 0.0 || stopDistance <= 0.0 ||
      minVolume <= 0.0 || maxVolume <= 0.0 || stepVolume <= 0.0)
      return 0.0;

   double moneyPerLot = (stopDistance / tickSize) * tickValue;
   if(moneyPerLot <= 0.0)
      return 0.0;

   double rawVolume = riskAmount / moneyPerLot;
   double normalized = MathFloor(rawVolume / stepVolume) * stepVolume;
   if(normalized < minVolume)
      return 0.0;
   if(normalized > maxVolume)
      normalized = maxVolume;

   return NormalizeDouble(normalized, VolumeDigits(stepVolume));
  }

bool ExecuteShortEntry(const PendingSetup &setup)
  {
   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;

   double confirmClose = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   if(confirmClose >= setup.triggerLow - PipsToPrice(InpConfirmBreakBufferPips))
      return false;

   double entry = NormalizePrice(bid);
   double stop = NormalizePrice(setup.signalHigh + PipsToPrice(InpStopBufferPips));
   if(stop <= entry)
      return false;

   double risk = stop - entry;
   double target = NormalizePrice(entry - risk * InpTargetRMultiple);
   double volume = CalculateVolumeByRisk(entry, stop);
   if(volume <= 0.0)
      return false;

   bool result = trade.Sell(volume, runtimeSymbol, 0.0, stop, target, "fractal_short");
   if(result)
      dailyTradeCount++;
   return result;
  }

void ManageOpenPositions()
  {
   if(!InpUseTimeStop || InpMaxHoldBars <= 0)
      return;

   int periodSeconds = PeriodSeconds(InpSignalTimeframe);
   if(periodSeconds <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      int barsHeld = (int)((TimeCurrent() - openTime) / periodSeconds);
      if(barsHeld >= InpMaxHoldBars)
        {
         ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
         trade.PositionClose(ticket);
        }
     }
  }

int OnInit()
  {
   runtimeSymbol = NormalizePresetString(InpSymbol);
   ArrayInitialize(allowedWeekdays, false);
   ArrayInitialize(allowedHours, false);
   pendingSetup.active = false;
   pendingSetup.signalTime = 0;
   pendingSetup.signalHigh = 0.0;
   pendingSetup.triggerLow = 0.0;
   pendingSetup.barsRemaining = 0;

   if(InpMagicNumber <= 0 || InpTrendPivotSpan <= 0 || InpTrendScanBars <= 0 ||
      InpATRPeriod <= 0 || InpFastEMAPeriod <= 0 || InpSlowEMAPeriod <= 0 ||
      InpRiskPercent <= 0.0 || InpTargetRMultiple <= 0.0 || InpConfirmBreakBars <= 0)
     {
      Print("Invalid fractal short parameters.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!ParseWeekdays(NormalizePresetString(InpAllowedWeekdays), allowedWeekdays))
     {
      Print("Invalid weekday filter.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!ParseAllowedHours(InpAllowedHours, allowedHours))
     {
      Print("Invalid hour filter.");
      return INIT_PARAMETERS_INCORRECT;
     }

   trade.SetExpertMagicNumber((ulong)InpMagicNumber);

   double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   double pip = GetPipSize();
   trade.SetDeviationInPoints((int)MathMax(1.0, MathRound((PipsToPrice(1.0) / point))));

   trendAtrHandle = iATR(runtimeSymbol, InpTrendTimeframe, InpATRPeriod);
   trendEma20Handle = iMA(runtimeSymbol, InpTrendTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   trendEma50Handle = iMA(runtimeSymbol, InpTrendTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(trendAtrHandle == INVALID_HANDLE || trendEma20Handle == INVALID_HANDLE || trendEma50Handle == INVALID_HANDLE)
     {
      Print("Failed to create fractal short indicator handles.");
      return INIT_FAILED;
     }

   InitializeDayState(TimeCurrent());
   equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(trendAtrHandle != INVALID_HANDLE)
      IndicatorRelease(trendAtrHandle);
   if(trendEma20Handle != INVALID_HANDLE)
      IndicatorRelease(trendEma20Handle);
   if(trendEma50Handle != INVALID_HANDLE)
      IndicatorRelease(trendEma50Handle);
  }

void OnTick()
  {
   datetime barTime;
   if(!IsNewBar(barTime))
      return;

   UpdateDayState(TimeCurrent());
   UpdateEquityPeak();
   UpdateRiskLocks();
   ManageOpenPositions();

   TrendContext ctx;
   bool bearishTrend = BuildTrendContext(ctx);

   if(pendingSetup.active)
     {
      pendingSetup.barsRemaining--;
      if(!SetupStillValid(pendingSetup) || pendingSetup.barsRemaining < 0 || !bearishTrend)
        {
         pendingSetup.active = false;
        }
      else if(PassGlobalGuards())
        {
         if(ExecuteShortEntry(pendingSetup))
            pendingSetup.active = false;
        }
     }

   if(!pendingSetup.active && bearishTrend && PassGlobalGuards())
     {
      PendingSetup newSetup;
      newSetup.active = false;
      if(DetectNewSellSweep(ctx, newSetup))
         pendingSetup = newSetup;
     }
  }
