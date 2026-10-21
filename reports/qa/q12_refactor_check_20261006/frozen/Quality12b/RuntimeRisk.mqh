// QUALITY12B_MODULE_BEGIN RuntimeRisk
#ifndef QUALITY12B_RUNTIMERISK_MQH
#define QUALITY12B_RUNTIMERISK_MQH
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
   return StringSubstr(value, 0 + start, finish - start + 1);
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

bool IsAllowedWeekday(int dayOfWeek)
  {
   if(dayOfWeek < 0 || dayOfWeek > 6)
      return false;
   return allowedWeekdays[dayOfWeek];
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
   MqlTick tick;
   if(!SymbolInfoTick(runtimeSymbol, tick))
      return -1.0;
   double pip = GetPipSize();
   if(pip <= 0.0)
      return -1.0;
   return (tick.ask - tick.bid) / pip;
  }

bool IsSpreadAllowed()
  {
   if(InpMaxSpreadPips <= 0.0)
      return true;
   double spreadPips = GetCurrentSpreadPips();
   if(spreadPips < 0.0)
      return false;
   return (spreadPips <= InpMaxSpreadPips);
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
     {
      if(InpSkipTradeWhenMinLotRiskTooHigh && InpMaxEffectiveRiskPercentAtMinLot > 0.0)
        {
         double minLotRiskAmount = moneyPerLot * minVolume;
         double minLotRiskPercent = (equity > 0.0 ? (minLotRiskAmount / equity) * 100.0 : 0.0);
         if(minLotRiskPercent > InpMaxEffectiveRiskPercentAtMinLot)
            return 0.0;
        }
      normalized = minVolume;
     }

   if(normalized > maxVolume)
      normalized = maxVolume;
   return NormalizeDouble(normalized, VolumeDigits(stepVolume));
  }

bool IsNewBarForTimeframe(ENUM_TIMEFRAMES timeframe, datetime &lastSeenBarTime, datetime &barTime)
  {
   datetime times[];
   ArraySetAsSeries(times, true);
   if(CopyTime(runtimeSymbol, timeframe, 0, 2, times) < 2)
      return false;
   if(times[0] == lastSeenBarTime)
      return false;
   lastSeenBarTime = times[0];
   barTime = times[0];
   return true;
  }

bool IsNewBar(datetime &barTime)
  {
   return IsNewBarForTimeframe(InpSignalTimeframe, lastBarTime, barTime);
  }

void ResetDailyCounters()
  {
   dailyTradeCount = 0;
   dailyClosedTrades = 0;
   dailyEntriesBuy = 0;
   dailyEntriesSell = 0;
   consecutiveLosses = 0;
   dailyBlockedSpread = 0;
   dailyBlockedDailyLoss = 0;
   dailyBlockedTradeCap = 0;
   dailyBlockedEquityCap = 0;
   dailyLossLockActivations = 0;
  }

void UpdateDailyAnchor()
  {
   datetime nowTime = TimeCurrent();
   MqlDateTime ts;
   TimeToStruct(nowTime, ts);
   if(ts.day_of_year != lastDayOfYear)
     {
      if(currentDayStart > 0)
         FlushDailySummary(nowTime, "rollover");
      lastDayOfYear = ts.day_of_year;
      ts.hour = 0;
      ts.min = 0;
      ts.sec = 0;
      currentDayStart = StructToTime(ts);
      dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      dailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(equityPeak <= 0.0)
         equityPeak = dailyStartEquity;
      ResetDailyCounters();
      LogTelemetryEvent(nowTime, "day_reset", "", "", 0.0, 0.0, 0.0, "");
     }
  }

void UpdateEquityPeak()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equityPeak <= 0.0 || equity > equityPeak)
      equityPeak = equity;
  }

bool IsDailyLossCapBlocked()
  {
   if(!InpUseDailyLossCap || InpDailyLossCapPercent <= 0.0 || dailyStartEquity <= 0.0)
      return false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   return (equity <= dailyStartEquity * (1.0 - InpDailyLossCapPercent / 100.0));
  }

bool IsEquityDrawdownBlocked()
  {
   if(!InpUseEquityDrawdownCap || InpEquityDrawdownCapPercent <= 0.0 || equityPeak <= 0.0)
      return false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   return (equity <= equityPeak * (1.0 - InpEquityDrawdownCapPercent / 100.0));
  }

bool IsTradeCountBlocked()
  {
   if(InpMaxTradesPerDay <= 0)
      return false;
   return (dailyTradeCount >= InpMaxTradesPerDay);
  }

bool IsWithinSession(datetime barTime, int sessionStartHour, int sessionEndHour)
  {
   MqlDateTime ts;
   TimeToStruct(barTime, ts);
   if(sessionStartHour < sessionEndHour)
      return ts.hour >= sessionStartHour && ts.hour < sessionEndHour;
   return ts.hour >= sessionStartHour || ts.hour < sessionEndHour;
  }

bool IsWithinActiveSession(datetime barTime)
  {
   return IsWithinSession(barTime, InpSessionStartHour, InpSessionEndHour);
  }

// QUALITY12B_MODULE_END RuntimeRisk
#endif
