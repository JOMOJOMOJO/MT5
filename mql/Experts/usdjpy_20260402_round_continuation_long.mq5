//+------------------------------------------------------------------+
//| USDJPY Round Continuation Long                                   |
//+------------------------------------------------------------------+
#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "1.00"
#property strict
#property description "USDJPY M15 long-only continuation prototype using EMA13/EMA100 trend, 50-pip anti-chop state, and wick-based pullback re-entry."

#include <Trade\Trade.mqh>

CTrade trade;

struct PivotPoint
  {
   bool     valid;
   int      shift;
   double   price;
   datetime time;
  };

input string          InpSymbol                   = "USDJPY";
input ENUM_TIMEFRAMES InpSignalTimeframe          = PERIOD_M15;
input int             InpFastEMAPeriod            = 13;
input int             InpSlowEMAPeriod            = 100;
input int             InpSlowSlopeLookback        = 5;
input int             InpPivotSpan                = 2;
input int             InpTrendScanBars            = 180;
input int             InpVolatilityLookbackBars   = 24;
input double          InpMinWindowRangePips       = 18.0;
input int             InpRoundStepPips            = 50;
input int             InpSessionStartHour         = 7;
input int             InpSessionEndHour           = 22;
input double          InpMaxEma13DistancePips     = 12.0;
input double          InpMinUpperWickShare        = 0.50;
input double          InpMaxLowerWickShare        = 0.10;
input double          InpMinSlowSlopePips         = 0.0;
input double          InpStopLossPips             = 22.0;
input double          InpTargetRMultiple          = 1.5;
input int             InpMaxHoldBars              = 18;
input double          InpRiskPercent              = 2.0;
input bool            InpUseMicroCapRiskOverride  = true;
input double          InpMicroCapBalanceThreshold = 150.0;
input double          InpMicroCapRiskPercent      = 3.0;
input bool            InpUseDailyLossCap          = true;
input double          InpDailyLossCapPercent      = 6.0;
input int             InpMaxTradesPerDay          = 2;
input double          InpMaxSpreadPips            = 2.0;
input string          InpAllowedWeekdays          = "1,2,3,4,5";
input long            InpMagicNumber              = 20260494;

int fastEmaHandle = INVALID_HANDLE;
int slowEmaHandle = INVALID_HANDLE;
string runtimeSymbol = "";
bool allowedWeekdays[7];
datetime lastBarTime = 0;
datetime currentDayStart = 0;
double dailyStartEquity = 0.0;
int dailyTradeCount = 0;

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

string NormalizePresetString(string rawValue)
  {
   int marker = StringFind(rawValue, "||");
   if(marker < 0)
      return rawValue;
   return StringSubstr(rawValue, 0, marker);
  }

bool ParseWeekdays(string rawValue)
  {
   ArrayInitialize(allowedWeekdays, false);
   string items[];
   int count = StringSplit(rawValue, ',', items);
   if(count <= 0)
      return false;
   for(int i = 0; i < count; ++i)
     {
      string item = TrimSpaces(items[i]);
      if(item == "")
         continue;
      int day = (int)StringToInteger(item);
      if(day < 0 || day > 6)
         return false;
      allowedWeekdays[day] = true;
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

double NormalizePrice(double price)
  {
   int digits = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
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

double GetEffectiveRiskPercent(double equity)
  {
   if(InpUseMicroCapRiskOverride && equity > 0.0 && equity <= InpMicroCapBalanceThreshold)
      return InpMicroCapRiskPercent;
   return InpRiskPercent;
  }

double CalculateVolume(double stopDistance)
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskPercent = GetEffectiveRiskPercent(equity);
   double riskAmount = equity * (riskPercent / 100.0);
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

   double rawVolume = riskAmount / moneyPerLot;
   double normalized = MathFloor(rawVolume / stepVolume) * stepVolume;
   if(normalized < minVolume)
      return 0.0;
   if(normalized > maxVolume)
      normalized = maxVolume;
   return NormalizeDouble(normalized, VolumeDigits(stepVolume));
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

void ResetDayState(datetime now)
  {
   MqlDateTime ts;
   TimeToStruct(now, ts);
   ts.hour = 0;
   ts.min = 0;
   ts.sec = 0;
   datetime dayStart = StructToTime(ts);
   if(dayStart != currentDayStart)
     {
      currentDayStart = dayStart;
      dailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      dailyTradeCount = 0;
     }
  }

bool IsWithinActiveSession(datetime barTime)
  {
   MqlDateTime ts;
   TimeToStruct(barTime, ts);
   if(InpSessionStartHour < InpSessionEndHour)
      return ts.hour >= InpSessionStartHour && ts.hour < InpSessionEndHour;
   return ts.hour >= InpSessionStartHour || ts.hour < InpSessionEndHour;
  }

bool LoadSignalWindow(MqlRates &rates[], double &fastEma[], double &slowEma[], int count)
  {
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(fastEma, true);
   ArraySetAsSeries(slowEma, true);
   int copiedRates = CopyRates(runtimeSymbol, InpSignalTimeframe, 0, count, rates);
   if(copiedRates < 140)
      return false;
   int copiedFast = CopyBuffer(fastEmaHandle, 0, 0, count, fastEma);
   int copiedSlow = CopyBuffer(slowEmaHandle, 0, 0, count, slowEma);
   return copiedFast == copiedRates && copiedSlow == copiedRates;
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

bool ManageOpenPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      datetime openedAt = (datetime)PositionGetInteger(POSITION_TIME);
      int barsOpen = iBarShift(runtimeSymbol, InpSignalTimeframe, openedAt, false);
      if(barsOpen < InpMaxHoldBars)
         continue;
      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      if(trade.PositionClose(ticket))
         return true;
      return false;
     }
   return false;
  }

bool CanOpenAnotherTrade(datetime barTime)
  {
   if(CountManagedPositions() > 0)
      return false;
   if(dailyTradeCount >= InpMaxTradesPerDay)
      return false;

   MqlDateTime ts;
   TimeToStruct(barTime, ts);
   if(ts.day_of_week < 0 || ts.day_of_week > 6 || !allowedWeekdays[ts.day_of_week])
      return false;
   if(!IsWithinActiveSession(barTime))
      return false;

   if(InpUseDailyLossCap && dailyStartEquity > 0.0)
     {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(equity <= dailyStartEquity * (1.0 - InpDailyLossCapPercent / 100.0))
         return false;
     }

   return GetSpreadPips() <= InpMaxSpreadPips;
  }

bool IsPivotHigh(const MqlRates &rates[], int shift, int span)
  {
   int size = ArraySize(rates);
   if(shift - span < 0 || shift + span >= size)
      return false;
   double center = rates[shift].high;
   for(int i = 1; i <= span; ++i)
     {
      if(center <= rates[shift - i].high || center < rates[shift + i].high)
         return false;
     }
   return true;
  }

bool IsPivotLow(const MqlRates &rates[], int shift, int span)
  {
   int size = ArraySize(rates);
   if(shift - span < 0 || shift + span >= size)
      return false;
   double center = rates[shift].low;
   for(int i = 1; i <= span; ++i)
     {
      if(center >= rates[shift - i].low || center > rates[shift + i].low)
         return false;
     }
   return true;
  }

void FindRecentPivots(const MqlRates &rates[], bool wantHigh, PivotPoint &latest, PivotPoint &previous)
  {
   latest.valid = false;
   previous.valid = false;
   int size = ArraySize(rates);
   int maxShift = MathMin(size - 1 - InpPivotSpan, InpTrendScanBars);
   for(int shift = InpPivotSpan + 1; shift <= maxShift; ++shift)
     {
      bool match = wantHigh ? IsPivotHigh(rates, shift, InpPivotSpan) : IsPivotLow(rates, shift, InpPivotSpan);
      if(!match)
         continue;
      PivotPoint point;
      point.valid = true;
      point.shift = shift;
      point.price = wantHigh ? rates[shift].high : rates[shift].low;
      point.time = rates[shift].time;
      if(!latest.valid)
         latest = point;
      else
        {
         previous = point;
         break;
        }
     }
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

bool PassesVolatilityState(const MqlRates &rates[])
  {
   int size = ArraySize(rates);
   if(size <= InpVolatilityLookbackBars + 1)
      return false;
   double highest = rates[1].high;
   double lowest = rates[1].low;
   for(int shift = 1; shift <= InpVolatilityLookbackBars; ++shift)
     {
      highest = MathMax(highest, rates[shift].high);
      lowest = MathMin(lowest, rates[shift].low);
     }
   double pip = GetPipSize();
   if(pip <= 0.0 || (highest - lowest) / pip < InpMinWindowRangePips)
      return false;

   double zoneStep = InpRoundStepPips * pip;
   if(zoneStep <= 0.0)
      return false;
   return (long)MathFloor(highest / zoneStep) != (long)MathFloor(lowest / zoneStep);
  }

bool EvaluateSignal(const MqlRates &rates[], const double &fastEma[], const double &slowEma[])
  {
   if(!PassesVolatilityState(rates))
      return false;

   PivotPoint latestHigh, previousHigh, latestLow, previousLow;
   FindRecentPivots(rates, true, latestHigh, previousHigh);
   FindRecentPivots(rates, false, latestLow, previousLow);
   if(!latestHigh.valid || !previousHigh.valid || !latestLow.valid || !previousLow.valid)
      return false;

   double pip = GetPipSize();
   if(pip <= 0.0)
      return false;
   if(!(latestHigh.price > previousHigh.price && latestLow.price > previousLow.price))
      return false;
   if(fastEma[1] <= slowEma[1])
      return false;
   if(rates[1].close <= slowEma[1])
      return false;

   double slowSlopePips = (slowEma[1] - slowEma[1 + InpSlowSlopeLookback]) / pip;
   if(slowSlopePips < InpMinSlowSlopePips)
      return false;
   if(rates[1].low <= latestLow.price)
      return false;

   double emaDistancePips = MathAbs(rates[1].close - fastEma[1]) / pip;
   if(emaDistancePips > InpMaxEma13DistancePips)
      return false;
   if(UpperWickShare(rates[1]) < InpMinUpperWickShare)
      return false;
   if(LowerWickShare(rates[1]) > InpMaxLowerWickShare)
      return false;
   return true;
  }

void OpenPosition()
  {
   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   double pip = GetPipSize();
   double stopDistance = InpStopLossPips * pip;
   double targetDistance = stopDistance * InpTargetRMultiple;
   double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   int stopsLevel = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(ask <= 0.0 || pip <= 0.0 || point <= 0.0)
      return;
   if(stopDistance < stopsLevel * point)
      return;
   if(targetDistance > 0.0 && targetDistance < stopsLevel * point)
      return;

   double volume = CalculateVolume(stopDistance);
   if(volume <= 0.0)
      return;

   double sl = NormalizePrice(ask - stopDistance);
   double tp = NormalizePrice(ask + targetDistance);
   if(trade.Buy(volume, runtimeSymbol, 0.0, sl, tp, "round_continuation_long"))
      dailyTradeCount++;
  }

int OnInit()
  {
   runtimeSymbol = NormalizePresetString(InpSymbol);
   if(
      InpFastEMAPeriod <= 0 || InpSlowEMAPeriod <= InpFastEMAPeriod || InpSlowSlopeLookback <= 0 ||
      InpPivotSpan <= 0 || InpTrendScanBars <= 20 || InpVolatilityLookbackBars <= 0 ||
      InpMinWindowRangePips <= 0.0 || InpRoundStepPips <= 0 || InpSessionStartHour < 0 || InpSessionStartHour > 23 ||
      InpSessionEndHour < 0 || InpSessionEndHour > 23 || InpSessionStartHour == InpSessionEndHour ||
      InpMaxEma13DistancePips <= 0.0 || InpMinUpperWickShare < 0.0 || InpMinUpperWickShare > 1.0 ||
      InpMaxLowerWickShare < 0.0 || InpMaxLowerWickShare > 1.0 || InpMinUpperWickShare <= InpMaxLowerWickShare ||
      InpStopLossPips <= 0.0 || InpTargetRMultiple <= 0.0 || InpMaxHoldBars < 1 || InpRiskPercent <= 0.0 ||
      InpMicroCapBalanceThreshold < 0.0 || InpMicroCapRiskPercent <= 0.0 || InpDailyLossCapPercent <= 0.0 ||
      InpMaxTradesPerDay < 0 || InpMaxSpreadPips <= 0.0 || InpMagicNumber <= 0
   )
      return INIT_PARAMETERS_INCORRECT;

   if(!ParseWeekdays(InpAllowedWeekdays))
      return INIT_PARAMETERS_INCORRECT;
   if(!SymbolInfoInteger(runtimeSymbol, SYMBOL_SELECT))
      if(!SymbolSelect(runtimeSymbol, true))
         return INIT_FAILED;

   fastEmaHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowEmaHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(fastEmaHandle == INVALID_HANDLE || slowEmaHandle == INVALID_HANDLE)
      return INIT_FAILED;

   trade.SetExpertMagicNumber((ulong)InpMagicNumber);
   trade.SetDeviationInPoints((int)MathMax(10.0, (InpMaxSpreadPips * GetPipSize()) / SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT)));
   ResetDayState(TimeCurrent());
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(fastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(fastEmaHandle);
   if(slowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(slowEmaHandle);
  }

void OnTick()
  {
   datetime barTime = 0;
   if(!IsNewBar(barTime))
      return;

   ResetDayState(TimeCurrent());

   if(CountManagedPositions() > 0)
     {
      if(ManageOpenPosition() || CountManagedPositions() > 0)
         return;
     }

   if(!CanOpenAnotherTrade(barTime))
      return;

   MqlRates rates[];
   double fastEma[];
   double slowEma[];
   if(!LoadSignalWindow(rates, fastEma, slowEma, 260))
      return;

   if(EvaluateSignal(rates, fastEma, slowEma))
      OpenPosition();
  }
