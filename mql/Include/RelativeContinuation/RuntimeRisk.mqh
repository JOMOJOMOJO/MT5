// RELATIVE_CONTINUATION_MODULE_BEGIN RuntimeRisk
#ifndef RELATIVE_CONTINUATION_RUNTIMERISK_MQH
#define RELATIVE_CONTINUATION_RUNTIMERISK_MQH
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
      if(StringLen(item) != 1 || StringGetCharacter(item,0) < '0' || StringGetCharacter(item,0) > '6')
         return false;
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

double GetDistanceUnit()
  {
   // All price-distance inputs share closed signal-TF ATR. Never bar 0.
   datetime stamp = iTime(runtimeSymbol, InpSignalTimeframe, 0);
   if(stamp <= 0 || distanceAtrHandle == INVALID_HANDLE) return 0.0;
   if(stamp == distanceAtrBar && distanceAtrValue > 0.0) return distanceAtrValue;
   double value[1];
   if(CopyBuffer(distanceAtrHandle,0,1,1,value) != 1 ||
      !MathIsValidNumber(value[0]) || value[0] <= 0.0) return 0.0;
   distanceAtrBar = stamp;
   distanceAtrValue = value[0];
   return distanceAtrValue;
  }

double NormalizePrice(double price)
  {
   int digits = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_DIGITS);
   double step = SymbolInfoDouble(runtimeSymbol, SYMBOL_TRADE_TICK_SIZE);
   if(step <= 0.0) return 0.0;
   return NormalizeDouble(MathRound(price / step) * step, digits);
  }

double GetCurrentSpreadAtr()
  {
   MqlTick tick;
   if(!SymbolInfoTick(runtimeSymbol, tick) || tick.bid <= 0.0 || tick.ask < tick.bid)
      return -1.0;
   double unit = GetDistanceUnit();
   if(unit <= 0.0)
      return -1.0;
   return (tick.ask - tick.bid) / unit;
  }

bool IsSpreadAllowed()
  {
   if(InpMaxSpreadAtr <= 0.0)
      return true;
   double spreadAtr = GetCurrentSpreadAtr();
   if(spreadAtr < 0.0)
      return false;
   // Tolerance for floating arithmetic only; does not grant an extra tick.
   return (spreadAtr <= InpMaxSpreadAtr + 1e-10);
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
   return InpRiskPercent;
  }

double CalculateVolume(ENUM_ORDER_TYPE side, double entryPrice, double stopPrice)
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskPercent = GetEffectiveRiskPercent(equity);
   double riskAmount = equity * (riskPercent / 100.0);
   if(riskAmount <= 0.0)
      return 0.0;

   double minVolume = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_MAX);
   double stepVolume = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_STEP);
   if(minVolume <= 0.0 || maxVolume < minVolume || stepVolume <= 0.0)
      return 0.0;

   double lossAtMin = 0.0;
   if(!OrderCalcProfit(side,runtimeSymbol,minVolume,entryPrice,stopPrice,lossAtMin) || lossAtMin >= 0.0)
      return 0.0;
   double moneyPerLot = -lossAtMin / minVolume;
   if(moneyPerLot <= 0.0)
      return 0.0;

   double rawVolume = riskAmount / moneyPerLot;
   double normalized = MathFloor(MathMin(rawVolume,maxVolume) / stepVolume + 1e-10) * stepVolume;
   if(normalized < minVolume)
     {
      Print("ORDER_SKIPPED MIN_VOLUME_EXCEEDS_RISK");
      return 0.0;
     }
   normalized = NormalizeDouble(normalized, VolumeDigits(stepVolume));
   double actualLoss = 0.0, margin = 0.0;
   if(!OrderCalcProfit(side,runtimeSymbol,normalized,entryPrice,stopPrice,actualLoss) ||
      -actualLoss > riskAmount + 1e-7 ||
      !OrderCalcMargin(side,runtimeSymbol,normalized,entryPrice,margin) ||
      margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE)) return 0.0;
   PrintFormat("RISK volume=%.8f expected_loss=%.4f budget=%.4f margin=%.4f",normalized,-actualLoss,riskAmount,margin);
   return normalized;
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
   datetime day = (datetime)(nowTime - ts.hour*3600 - ts.min*60 - ts.sec);
   if(day != currentDayStart)
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
      dailyCapLatched = false;
      RestoreRiskState();
      LogTelemetryEvent(nowTime, "day_reset", "", "", 0.0, 0.0, 0.0, "");
     }
  }

void UpdateEquityPeak()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equityPeak <= 0.0 || equity > equityPeak)
     {
      equityPeak = equity;
      SaveRiskState();
     }
  }

bool IsDailyLossCapBlocked()
  {
   if(!InpUseDailyLossCap || InpDailyLossCapPercent <= 0.0 || dailyStartEquity <= 0.0)
      return false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= dailyStartEquity * (1.0 - InpDailyLossCapPercent / 100.0))
     {
      dailyCapLatched = true;
      SaveRiskState();
     }
   return dailyCapLatched;
  }

bool IsEquityDrawdownBlocked()
  {
   if(!InpUseEquityDrawdownCap || InpEquityDrawdownCapPercent <= 0.0 || equityPeak <= 0.0)
      return false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= equityPeak * (1.0 - InpEquityDrawdownCapPercent / 100.0))
     {
      equityCapLatched = true;
      SaveRiskState();
     }
   return equityCapLatched;
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

// RELATIVE_CONTINUATION_MODULE_END RuntimeRisk
#endif
