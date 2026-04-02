//+------------------------------------------------------------------+
//| USDJPY Long Stack                                                |
//+------------------------------------------------------------------+
#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "1.00"
#property strict
#property description "USDJPY M15 long-only stack combining round continuation quality anchor and EMA continuation sidecar with shared live guards."

#include <Trade\Trade.mqh>

CTrade trade;

struct PivotPoint
  {
   bool     valid;
   int      shift;
   double   price;
   datetime time;
  };

enum SignalBucket
  {
   SIGNAL_NONE = 0,
   SIGNAL_ROUND = 1,
   SIGNAL_EMA = 2
  };

input string          InpSymbol                       = "USDJPY";
input ENUM_TIMEFRAMES InpSignalTimeframe              = PERIOD_M15;
input int             InpFastEMAPeriod                = 13;
input int             InpSlowEMAPeriod                = 100;
input int             InpSlowSlopeLookback            = 5;
input double          InpMinSlowSlopePips             = 0.0;
input string          InpAllowedWeekdays              = "1,2,3,4,5";

input bool            InpEnableRoundBucket            = true;
input int             InpRoundPivotSpan               = 2;
input int             InpRoundTrendScanBars           = 180;
input int             InpRoundVolatilityLookbackBars  = 24;
input double          InpRoundMinWindowRangePips      = 15.0;
input int             InpRoundStepPips                = 50;
input int             InpRoundSessionStartHour        = 7;
input int             InpRoundSessionEndHour          = 22;
input double          InpRoundMaxEma13DistancePips    = 12.0;
input double          InpRoundMinUpperWickShare       = 0.50;
input double          InpRoundMaxLowerWickShare       = 0.10;
input double          InpRoundStopLossPips            = 22.0;
input double          InpRoundTargetRMultiple         = 1.5;
input int             InpRoundMaxHoldBars             = 18;

input bool            InpEnableEmaBucket              = true;
input int             InpAdxPeriod                    = 14;
input double          InpEmaMaxAdx                    = 30.0;
input int             InpEmaSessionStartHour          = 7;
input int             InpEmaSessionEndHour            = 16;
input double          InpEmaMaxEma13DistancePips      = 22.0;
input double          InpEmaMaxRet1                   = 0.0004;
input double          InpEmaMinUpperWickShare         = 0.45;
input double          InpEmaMaxLowerWickShare         = 0.15;
input double          InpEmaMaxCloseLocation          = 0.45;
input double          InpEmaStopLossPips              = 15.0;
input double          InpEmaTargetRMultiple           = 1.2;
input int             InpEmaMaxHoldBars               = 12;

input double          InpRiskPercent                  = 2.0;
input bool            InpUseMicroCapRiskOverride      = true;
input double          InpMicroCapBalanceThreshold     = 150.0;
input double          InpMicroCapRiskPercent          = 3.0;
input bool            InpUseDailyLossCap              = true;
input double          InpDailyLossCapPercent          = 6.0;
input int             InpMaxTradesPerDay              = 3;
input double          InpMaxSpreadPips                = 2.0;
input long            InpMagicNumber                  = 20260520;

int fastEmaHandle = INVALID_HANDLE;
int slowEmaHandle = INVALID_HANDLE;
int adxHandle = INVALID_HANDLE;
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

bool IsWithinSession(datetime barTime, int sessionStartHour, int sessionEndHour)
  {
   MqlDateTime ts;
   TimeToStruct(barTime, ts);
   if(sessionStartHour < sessionEndHour)
      return ts.hour >= sessionStartHour && ts.hour < sessionEndHour;
   return ts.hour >= sessionStartHour || ts.hour < sessionEndHour;
  }

bool LoadSignalWindow(MqlRates &rates[], double &fastEma[], double &slowEma[], double &adxValues[], int count)
  {
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(fastEma, true);
   ArraySetAsSeries(slowEma, true);
   ArraySetAsSeries(adxValues, true);
   int copiedRates = CopyRates(runtimeSymbol, InpSignalTimeframe, 0, count, rates);
   if(copiedRates < 140)
      return false;
   int copiedFast = CopyBuffer(fastEmaHandle, 0, 0, count, fastEma);
   int copiedSlow = CopyBuffer(slowEmaHandle, 0, 0, count, slowEma);
   int copiedAdx = CopyBuffer(adxHandle, 0, 0, count, adxValues);
   return copiedFast == copiedRates && copiedSlow == copiedRates && copiedAdx == copiedRates;
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

int GetBucketHoldBars(string positionComment)
  {
   if(StringFind(positionComment, "stack_round") >= 0)
      return InpRoundMaxHoldBars;
   if(StringFind(positionComment, "stack_ema") >= 0)
      return InpEmaMaxHoldBars;
   return MathMax(InpRoundMaxHoldBars, InpEmaMaxHoldBars);
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
      string comment = PositionGetString(POSITION_COMMENT);
      int maxHoldBars = GetBucketHoldBars(comment);
      int barsOpen = iBarShift(runtimeSymbol, InpSignalTimeframe, openedAt, false);
      if(barsOpen < maxHoldBars)
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

void FindRecentPivots(const MqlRates &rates[], bool wantHigh, int span, int maxScanBars, PivotPoint &latest, PivotPoint &previous)
  {
   latest.valid = false;
   previous.valid = false;
   int size = ArraySize(rates);
   int maxShift = MathMin(size - 1 - span, maxScanBars);
   for(int shift = span + 1; shift <= maxShift; ++shift)
     {
      bool match = wantHigh ? IsPivotHigh(rates, shift, span) : IsPivotLow(rates, shift, span);
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

double CloseLocation(const MqlRates &bar)
  {
   double range = bar.high - bar.low;
   if(range <= 0.0)
      return 0.5;
   return (bar.close - bar.low) / range;
  }

bool PassesRoundVolatilityState(const MqlRates &rates[])
  {
   int size = ArraySize(rates);
   if(size <= InpRoundVolatilityLookbackBars + 1)
      return false;
   double highest = rates[1].high;
   double lowest = rates[1].low;
   for(int shift = 1; shift <= InpRoundVolatilityLookbackBars; ++shift)
     {
      highest = MathMax(highest, rates[shift].high);
      lowest = MathMin(lowest, rates[shift].low);
     }
   double pip = GetPipSize();
   if(pip <= 0.0 || (highest - lowest) / pip < InpRoundMinWindowRangePips)
      return false;

   double zoneStep = InpRoundStepPips * pip;
   if(zoneStep <= 0.0)
      return false;
   return (long)MathFloor(highest / zoneStep) != (long)MathFloor(lowest / zoneStep);
  }

bool EvaluateRoundSignal(const MqlRates &rates[], const double &fastEma[], const double &slowEma[], datetime barTime)
  {
   if(!InpEnableRoundBucket)
      return false;
   if(!IsWithinSession(barTime, InpRoundSessionStartHour, InpRoundSessionEndHour))
      return false;
   if(!PassesRoundVolatilityState(rates))
      return false;

   PivotPoint latestHigh, previousHigh, latestLow, previousLow;
   FindRecentPivots(rates, true, InpRoundPivotSpan, InpRoundTrendScanBars, latestHigh, previousHigh);
   FindRecentPivots(rates, false, InpRoundPivotSpan, InpRoundTrendScanBars, latestLow, previousLow);
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
   if(emaDistancePips > InpRoundMaxEma13DistancePips)
      return false;
   if(UpperWickShare(rates[1]) < InpRoundMinUpperWickShare)
      return false;
   if(LowerWickShare(rates[1]) > InpRoundMaxLowerWickShare)
      return false;
   return true;
  }

bool EvaluateEmaSignal(const MqlRates &rates[], const double &fastEma[], const double &slowEma[], const double &adxValues[], datetime barTime)
  {
   if(!InpEnableEmaBucket)
      return false;
   if(!IsWithinSession(barTime, InpEmaSessionStartHour, InpEmaSessionEndHour))
      return false;

   double pip = GetPipSize();
   if(pip <= 0.0)
      return false;
   if(fastEma[1] <= slowEma[1])
      return false;
   if(rates[1].close <= slowEma[1])
      return false;

   double slowSlopePips = (slowEma[1] - slowEma[1 + InpSlowSlopeLookback]) / pip;
   if(slowSlopePips < InpMinSlowSlopePips)
      return false;

   if(adxValues[1] <= 0.0 || adxValues[1] > InpEmaMaxAdx)
      return false;

   double emaDistancePips = MathAbs(rates[1].close - fastEma[1]) / pip;
   if(emaDistancePips > InpEmaMaxEma13DistancePips)
      return false;

   double ret1 = 0.0;
   if(rates[2].close > 0.0)
      ret1 = (rates[1].close - rates[2].close) / rates[2].close;
   if(ret1 > InpEmaMaxRet1)
      return false;

   if(UpperWickShare(rates[1]) < InpEmaMinUpperWickShare)
      return false;
   if(LowerWickShare(rates[1]) > InpEmaMaxLowerWickShare)
      return false;
   if(CloseLocation(rates[1]) > InpEmaMaxCloseLocation)
      return false;
   return true;
  }

bool OpenPosition(SignalBucket bucket)
  {
   double stopPips = 0.0;
   double targetR = 0.0;
   string comment = "";

   if(bucket == SIGNAL_ROUND)
     {
      stopPips = InpRoundStopLossPips;
      targetR = InpRoundTargetRMultiple;
      comment = "stack_round";
     }
   else if(bucket == SIGNAL_EMA)
     {
      stopPips = InpEmaStopLossPips;
      targetR = InpEmaTargetRMultiple;
      comment = "stack_ema";
     }
   else
      return false;

   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   double pip = GetPipSize();
   double stopDistance = stopPips * pip;
   double targetDistance = stopDistance * targetR;
   double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   int stopsLevel = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(ask <= 0.0 || pip <= 0.0 || point <= 0.0)
      return false;
   if(stopDistance < stopsLevel * point)
      return false;
   if(targetDistance > 0.0 && targetDistance < stopsLevel * point)
      return false;

   double volume = CalculateVolume(stopDistance);
   if(volume <= 0.0)
      return false;

   double sl = NormalizePrice(ask - stopDistance);
   double tp = NormalizePrice(ask + targetDistance);
   if(trade.Buy(volume, runtimeSymbol, 0.0, sl, tp, comment))
     {
      dailyTradeCount++;
      return true;
     }
   return false;
  }

int OnInit()
  {
   runtimeSymbol = NormalizePresetString(InpSymbol);
   if(
      InpFastEMAPeriod <= 0 || InpSlowEMAPeriod <= InpFastEMAPeriod || InpSlowSlopeLookback <= 0 ||
      InpRiskPercent <= 0.0 || InpMicroCapBalanceThreshold < 0.0 || InpMicroCapRiskPercent <= 0.0 ||
      InpDailyLossCapPercent <= 0.0 || InpMaxTradesPerDay < 0 || InpMaxSpreadPips <= 0.0 || InpMagicNumber <= 0 ||
      (!InpEnableRoundBucket && !InpEnableEmaBucket) ||
      (InpEnableRoundBucket && (
         InpRoundPivotSpan <= 0 || InpRoundTrendScanBars <= 20 || InpRoundVolatilityLookbackBars <= 0 ||
         InpRoundMinWindowRangePips <= 0.0 || InpRoundStepPips <= 0 || InpRoundSessionStartHour < 0 ||
         InpRoundSessionStartHour > 23 || InpRoundSessionEndHour < 0 || InpRoundSessionEndHour > 23 ||
         InpRoundSessionStartHour == InpRoundSessionEndHour || InpRoundMaxEma13DistancePips <= 0.0 ||
         InpRoundMinUpperWickShare < 0.0 || InpRoundMinUpperWickShare > 1.0 ||
         InpRoundMaxLowerWickShare < 0.0 || InpRoundMaxLowerWickShare > 1.0 ||
         InpRoundMinUpperWickShare <= InpRoundMaxLowerWickShare || InpRoundStopLossPips <= 0.0 ||
         InpRoundTargetRMultiple <= 0.0 || InpRoundMaxHoldBars < 1
      )) ||
      (InpEnableEmaBucket && (
         InpAdxPeriod <= 1 || InpEmaMaxAdx <= 0.0 || InpEmaSessionStartHour < 0 || InpEmaSessionStartHour > 23 ||
         InpEmaSessionEndHour < 0 || InpEmaSessionEndHour > 23 || InpEmaSessionStartHour == InpEmaSessionEndHour ||
         InpEmaMaxEma13DistancePips <= 0.0 || InpEmaMaxRet1 < -0.01 || InpEmaMaxRet1 > 0.01 ||
         InpEmaMinUpperWickShare < 0.0 || InpEmaMinUpperWickShare > 1.0 || InpEmaMaxLowerWickShare < 0.0 ||
         InpEmaMaxLowerWickShare > 1.0 || InpEmaMaxCloseLocation < 0.0 || InpEmaMaxCloseLocation > 1.0 ||
         InpEmaStopLossPips <= 0.0 || InpEmaTargetRMultiple <= 0.0 || InpEmaMaxHoldBars < 1
      ))
   )
      return INIT_PARAMETERS_INCORRECT;

   if(!ParseWeekdays(InpAllowedWeekdays))
      return INIT_PARAMETERS_INCORRECT;
   if(!SymbolInfoInteger(runtimeSymbol, SYMBOL_SELECT))
      if(!SymbolSelect(runtimeSymbol, true))
         return INIT_FAILED;

   fastEmaHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowEmaHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   adxHandle = iADX(runtimeSymbol, InpSignalTimeframe, InpAdxPeriod);
   if(fastEmaHandle == INVALID_HANDLE || slowEmaHandle == INVALID_HANDLE || adxHandle == INVALID_HANDLE)
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
   if(adxHandle != INVALID_HANDLE)
      IndicatorRelease(adxHandle);
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
   double adxValues[];
   if(!LoadSignalWindow(rates, fastEma, slowEma, adxValues, 260))
      return;

   SignalBucket bucket = SIGNAL_NONE;
   if(EvaluateRoundSignal(rates, fastEma, slowEma, barTime))
      bucket = SIGNAL_ROUND;
   else if(EvaluateEmaSignal(rates, fastEma, slowEma, adxValues, barTime))
      bucket = SIGNAL_EMA;

   if(bucket != SIGNAL_NONE)
      OpenPosition(bucket);
  }
