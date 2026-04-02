//+------------------------------------------------------------------+
//| USDJPY Downside Persist Long                                     |
//+------------------------------------------------------------------+
#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "1.00"
#property strict
#property description "USDJPY M5 long-only prototype using downside-break persistence, spread expansion, and optional EMA13/EMA100 trend alignment."

#include <Trade\Trade.mqh>

CTrade trade;

input string          InpSymbol                   = "USDJPY";
input ENUM_TIMEFRAMES InpSignalTimeframe          = PERIOD_M5;
input int             InpFastEMAPeriod            = 13;
input int             InpSlowEMAPeriod            = 100;
input int             InpSlowSlopeLookback        = 6;
input int             InpBreakoutWindowBars       = 12;
input int             InpPersistLookbackBars      = 6;
input int             InpMinBreakoutPersist       = 2;
input int             InpSpreadZLookbackBars      = 20;
input double          InpMinSignalSpreadZ         = 0.0;
input bool            InpRequireTrendUp           = true;
input bool            InpRequireCloseBelowFast    = false;
input int             InpSessionStartHour         = 7;
input int             InpSessionEndHour           = 22;
input double          InpStopLossPips             = 15.0;
input double          InpTargetRMultiple          = 1.2;
input int             InpMaxHoldBars              = 12;
input int             InpCooldownBars             = 0;
input double          InpRiskPercent              = 2.0;
input bool            InpUseMicroCapRiskOverride  = true;
input double          InpMicroCapBalanceThreshold = 150.0;
input double          InpMicroCapRiskPercent      = 3.0;
input bool            InpUseDailyLossCap          = true;
input double          InpDailyLossCapPercent      = 6.0;
input int             InpMaxTradesPerDay          = 3;
input double          InpMaxSpreadPips            = 2.0;
input string          InpAllowedWeekdays          = "1,2,3,4,5";
input long            InpMagicNumber              = 20260502;

int fastEmaHandle = INVALID_HANDLE;
int slowEmaHandle = INVALID_HANDLE;
string runtimeSymbol = "";
bool allowedWeekdays[7];
datetime lastBarTime = 0;
datetime currentDayStart = 0;
double dailyStartEquity = 0.0;
int dailyTradeCount = 0;
int cooldownRemainingBars = 0;

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

double GetCurrentSpreadPips()
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
        {
         cooldownRemainingBars = InpCooldownBars;
         return true;
        }
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

   if(cooldownRemainingBars > 0)
      return false;

   return GetCurrentSpreadPips() <= InpMaxSpreadPips;
  }

double LowestLow(const MqlRates &rates[], int startShift, int length)
  {
   double value = rates[startShift].low;
   for(int shift = startShift + 1; shift < startShift + length; ++shift)
      value = MathMin(value, rates[shift].low);
   return value;
  }

int BreakoutPersistCount(const MqlRates &rates[])
  {
   int count = 0;
   for(int shift = 1; shift <= InpPersistLookbackBars; ++shift)
     {
      double priorLow = LowestLow(rates, shift + 1, InpBreakoutWindowBars);
      if(rates[shift].close < priorLow)
         count++;
     }
   return count;
  }

double SignalSpreadZ(const MqlRates &rates[])
  {
   double pip = GetPipSize();
   double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   if(pip <= 0.0 || point <= 0.0)
      return 0.0;

   double sum = 0.0;
   for(int shift = 1; shift <= InpSpreadZLookbackBars; ++shift)
      sum += (rates[shift].spread * point) / pip;
   double mean = sum / InpSpreadZLookbackBars;

   double variance = 0.0;
   for(int shift = 1; shift <= InpSpreadZLookbackBars; ++shift)
     {
      double value = (rates[shift].spread * point) / pip;
      variance += MathPow(value - mean, 2.0);
     }
   double stddev = MathSqrt(variance / InpSpreadZLookbackBars);
   if(stddev <= 1e-8)
      return 0.0;

   double currentSpread = (rates[1].spread * point) / pip;
   return (currentSpread - mean) / stddev;
  }

bool EvaluateSignal(const MqlRates &rates[], const double &fastEma[], const double &slowEma[])
  {
   if(BreakoutPersistCount(rates) < InpMinBreakoutPersist)
      return false;
   if(SignalSpreadZ(rates) < InpMinSignalSpreadZ)
      return false;

   if(InpRequireTrendUp)
     {
      double pip = GetPipSize();
      if(fastEma[1] <= slowEma[1])
         return false;
      if(rates[1].close <= slowEma[1])
         return false;
      if((slowEma[1] - slowEma[1 + InpSlowSlopeLookback]) / pip <= 0.0)
         return false;
     }

   if(InpRequireCloseBelowFast && rates[1].close >= fastEma[1])
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
   if(trade.Buy(volume, runtimeSymbol, 0.0, sl, tp, "downpersist_long"))
      dailyTradeCount++;
  }

int OnInit()
  {
   runtimeSymbol = NormalizePresetString(InpSymbol);
   if(
      InpFastEMAPeriod <= 0 || InpSlowEMAPeriod <= InpFastEMAPeriod || InpSlowSlopeLookback <= 0 ||
      InpBreakoutWindowBars < 2 || InpPersistLookbackBars < 1 || InpMinBreakoutPersist < 1 ||
      InpMinBreakoutPersist > InpPersistLookbackBars || InpSpreadZLookbackBars < 5 ||
      InpSessionStartHour < 0 || InpSessionStartHour > 23 || InpSessionEndHour < 0 || InpSessionEndHour > 23 ||
      InpSessionStartHour == InpSessionEndHour || InpStopLossPips <= 0.0 || InpTargetRMultiple <= 0.0 ||
      InpMaxHoldBars < 1 || InpCooldownBars < 0 || InpRiskPercent <= 0.0 || InpMicroCapRiskPercent <= 0.0 ||
      InpDailyLossCapPercent <= 0.0 || InpMaxTradesPerDay < 0 || InpMaxSpreadPips <= 0.0 || InpMagicNumber <= 0
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
   if(cooldownRemainingBars > 0)
      cooldownRemainingBars--;

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
   int barsNeeded = MathMax(140, InpBreakoutWindowBars + InpPersistLookbackBars + InpSpreadZLookbackBars + InpSlowSlopeLookback + 10);
   if(!LoadSignalWindow(rates, fastEma, slowEma, barsNeeded))
      return;

   if(EvaluateSignal(rates, fastEma, slowEma))
      OpenPosition();
  }
