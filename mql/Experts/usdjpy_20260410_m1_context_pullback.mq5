//+------------------------------------------------------------------+
//| USDJPY M1 Context Pullback                                       |
//+------------------------------------------------------------------+
#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "1.00"
#property strict
#property description "USDJPY M15 regime + M1 pullback reclaim research EA with explicit stop-first sizing and live-safe guards."

#include <Trade\Trade.mqh>

CTrade trade;

input string          InpSymbol                         = "USDJPY";
input ENUM_TIMEFRAMES InpRegimeTimeframe                = PERIOD_M15;
input ENUM_TIMEFRAMES InpExecutionTimeframe             = PERIOD_M1;
input int             InpFastEMAPeriod                  = 13;
input int             InpSlowEMAPeriod                  = 100;
input int             InpRegimeSlopeLookback            = 5;
input int             InpRegimeSwingLookback            = 12;
input int             InpRegimeSwingShift               = 6;
input int             InpTriggerEMAPeriod               = 20;
input int             InpStopEMAPeriod                  = 50;
input int             InpRsiPeriod                      = 7;
input int             InpSessionStartHour               = 7;
input int             InpSessionEndHour                 = 16;
input int             InpPullbackBars                   = 5;
input int             InpRequiredClosesBelowFast        = 2;
input double          InpMaxSignalRsi                   = 36.0;
input double          InpMinPullback3Pips               = 0.8;
input double          InpMinPullback6Pips               = 1.2;
input double          InpEmaTouchBufferPips             = 0.4;
input double          InpMinSignalBodyPips              = 0.8;
input double          InpMinSignalRangePips             = 1.0;
input double          InpMinSignalCloseLocation         = 0.60;
input double          InpSignalBufferPips               = 0.2;
input double          InpStopBufferPips                 = 0.6;
input double          InpStopFloorPips                  = 4.0;
input double          InpStopCapPips                    = 10.0;
input double          InpTargetRMultiple                = 1.2;
input int             InpMaxHoldBars                    = 35;
input double          InpRiskPercent                    = 0.50;
input bool            InpUseMicroCapRiskOverride        = true;
input double          InpMicroCapBalanceThreshold       = 150.0;
input double          InpMicroCapRiskPercent            = 1.00;
input bool            InpSkipTradeWhenMinLotRiskTooHigh = true;
input double          InpMaxEffectiveRiskPercentAtMinLot = 1.20;
input bool            InpUseDailyLossCap                = true;
input double          InpDailyLossCapPercent            = 3.0;
input bool            InpFlattenOnDailyLossCap          = true;
input bool            InpUseEquityDrawdownCap           = true;
input double          InpEquityDrawdownCapPercent       = 8.0;
input bool            InpFlattenOnEquityDrawdownCap     = true;
input int             InpMaxTradesPerDay                = 5;
input int             InpConsecutiveLossLimit           = 2;
input int             InpCooldownBarsAfterLosses        = 60;
input double          InpMaxSpreadPips                  = 1.8;
input string          InpAllowedWeekdays                = "1,2,3,4,5";
input long            InpMagicNumber                    = 20260410;

int fastRegimeEmaHandle = INVALID_HANDLE;
int slowRegimeEmaHandle = INVALID_HANDLE;
int fastExecEmaHandle = INVALID_HANDLE;
int triggerExecEmaHandle = INVALID_HANDLE;
int stopExecEmaHandle = INVALID_HANDLE;
int execRsiHandle = INVALID_HANDLE;

string runtimeSymbol = "";
bool allowedWeekdays[7];
datetime lastExecutionBarTime = 0;
datetime currentDayStart = 0;
double dailyStartEquity = 0.0;
double equityPeak = 0.0;
int dailyTradeCount = 0;
int consecutiveLosses = 0;
datetime cooldownUntil = 0;

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

bool IsNewBar(datetime &barTime)
  {
   datetime times[];
   ArraySetAsSeries(times, true);
   if(CopyTime(runtimeSymbol, InpExecutionTimeframe, 0, 2, times) < 2)
      return false;
   if(times[0] == lastExecutionBarTime)
      return false;
   lastExecutionBarTime = times[0];
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
      consecutiveLosses = 0;
      cooldownUntil = 0;
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

bool LoadRegimeWindow(MqlRates &rates[], double &fastEma[], double &slowEma[], int count)
  {
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(fastEma, true);
   ArraySetAsSeries(slowEma, true);
   int copiedRates = CopyRates(runtimeSymbol, InpRegimeTimeframe, 0, count, rates);
   if(copiedRates < InpRegimeSwingLookback + InpRegimeSwingShift + 10)
      return false;
   int copiedFast = CopyBuffer(fastRegimeEmaHandle, 0, 0, count, fastEma);
   int copiedSlow = CopyBuffer(slowRegimeEmaHandle, 0, 0, count, slowEma);
   return (copiedFast == copiedRates && copiedSlow == copiedRates);
  }

bool LoadExecutionWindow(MqlRates &rates[], double &fastEma[], double &triggerEma[], double &stopEma[], double &rsiValues[], int count)
  {
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(fastEma, true);
   ArraySetAsSeries(triggerEma, true);
   ArraySetAsSeries(stopEma, true);
   ArraySetAsSeries(rsiValues, true);
   int copiedRates = CopyRates(runtimeSymbol, InpExecutionTimeframe, 0, count, rates);
   if(copiedRates < InpPullbackBars + InpMaxHoldBars + 20)
      return false;
   int copiedFast = CopyBuffer(fastExecEmaHandle, 0, 0, count, fastEma);
   int copiedTrigger = CopyBuffer(triggerExecEmaHandle, 0, 0, count, triggerEma);
   int copiedStop = CopyBuffer(stopExecEmaHandle, 0, 0, count, stopEma);
   int copiedRsi = CopyBuffer(execRsiHandle, 0, 0, count, rsiValues);
   return (copiedFast == copiedRates && copiedTrigger == copiedRates && copiedStop == copiedRates && copiedRsi == copiedRates);
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

bool IsDailyLossBlocked()
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

void UpdateEquityPeak()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equityPeak <= 0.0 || equity > equityPeak)
      equityPeak = equity;
  }

bool FlattenManagedPositions(string reason)
  {
   bool anyFailed = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      if(!trade.PositionClose(ticket))
        {
         anyFailed = true;
         PrintFormat("Failed to flatten position %I64u (%s): %d", ticket, reason, GetLastError());
        }
     }
   return !anyFailed;
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
      int barsOpen = iBarShift(runtimeSymbol, InpExecutionTimeframe, openedAt, false);
      if(barsOpen >= 0 && barsOpen >= InpMaxHoldBars)
        {
         ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
         if(trade.PositionClose(ticket))
            return true;
         return false;
        }
     }
   return false;
  }

double BarRangePips(const MqlRates &bar)
  {
   double pip = GetPipSize();
   if(pip <= 0.0)
      return 0.0;
   return (bar.high - bar.low) / pip;
  }

double BodyPips(const MqlRates &bar)
  {
   double pip = GetPipSize();
   if(pip <= 0.0)
      return 0.0;
   return MathAbs(bar.close - bar.open) / pip;
  }

double CloseLocation(const MqlRates &bar)
  {
   double range = bar.high - bar.low;
   if(range <= 0.0)
      return 0.5;
   return (bar.close - bar.low) / range;
  }

double HighestHigh(const MqlRates &rates[], int startShift, int count)
  {
   double highest = -DBL_MAX;
   for(int shift = startShift; shift < startShift + count; ++shift)
      highest = MathMax(highest, rates[shift].high);
   return highest;
  }

double LowestLow(const MqlRates &rates[], int startShift, int count)
  {
   double lowest = DBL_MAX;
   for(int shift = startShift; shift < startShift + count; ++shift)
      lowest = MathMin(lowest, rates[shift].low);
   return lowest;
  }

bool IsBullishRegime(const MqlRates &rates[], const double &fastEma[], const double &slowEma[])
  {
   int slopeShift = 1 + InpRegimeSlopeLookback;
   int scanShift = 1 + InpRegimeSwingShift;
   if(ArraySize(rates) <= scanShift + InpRegimeSwingLookback)
      return false;

   double pip = GetPipSize();
   if(pip <= 0.0)
      return false;

   double currentSlowSlopePips = (slowEma[1] - slowEma[slopeShift]) / pip;
   if(!(fastEma[1] > slowEma[1] && currentSlowSlopePips > 0.0 && rates[1].close > slowEma[1]))
      return false;

   double recentHigh = HighestHigh(rates, 1, InpRegimeSwingLookback);
   double priorHigh = HighestHigh(rates, scanShift, InpRegimeSwingLookback);
   double recentLow = LowestLow(rates, 1, InpRegimeSwingLookback);
   double priorLow = LowestLow(rates, scanShift, InpRegimeSwingLookback);

   return (recentHigh > priorHigh && recentLow > priorLow);
  }

bool EvaluateExecutionSignal(const MqlRates &rates[], const double &fastEma[], const double &triggerEma[], const double &stopEma[],
                             const double &rsiValues[], double &plannedStopPips)
  {
   plannedStopPips = 0.0;
   double pip = GetPipSize();
   if(pip <= 0.0)
      return false;

   MqlRates signalBar = rates[1];
   if(!(signalBar.close > signalBar.open))
      return false;
   if(!(signalBar.close > fastEma[1] + InpSignalBufferPips * pip && signalBar.close > triggerEma[1] + InpSignalBufferPips * pip))
      return false;
   if(!(triggerEma[1] > stopEma[1] && fastEma[1] > triggerEma[1]))
      return false;
   if(BodyPips(signalBar) < InpMinSignalBodyPips || BarRangePips(signalBar) < InpMinSignalRangePips)
      return false;
   if(CloseLocation(signalBar) < InpMinSignalCloseLocation)
      return false;

   int closesBelowFast = 0;
   double pullbackLow = signalBar.low;
   bool touchedTrigger = false;
   for(int shift = 2; shift <= InpPullbackBars + 1; ++shift)
     {
      if(rates[shift].close < fastEma[shift])
         closesBelowFast++;
      if(rates[shift].low <= triggerEma[shift] + InpEmaTouchBufferPips * pip)
         touchedTrigger = true;
      if(rates[shift].low < pullbackLow)
         pullbackLow = rates[shift].low;
     }

   if(closesBelowFast < InpRequiredClosesBelowFast || !touchedTrigger)
      return false;

   if(rsiValues[2] > InpMaxSignalRsi)
      return false;

   double pullback3Pips = (rates[4].close - rates[2].close) / pip;
   double pullback6Pips = (rates[7].close - rates[2].close) / pip;
   if(!(pullback3Pips >= InpMinPullback3Pips || pullback6Pips >= InpMinPullback6Pips))
      return false;

   double structureStop = MathMin(pullbackLow, stopEma[1]) - InpStopBufferPips * pip;
   double entryReference = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   double stopDistancePips = (entryReference - structureStop) / pip;
   if(stopDistancePips < InpStopFloorPips)
      stopDistancePips = InpStopFloorPips;
   if(stopDistancePips > InpStopCapPips)
      return false;

   plannedStopPips = stopDistancePips;
   return true;
  }

bool CanOpenAnotherTrade(datetime barTime)
  {
   if(CountManagedPositions() > 0)
      return false;
   if(dailyTradeCount >= InpMaxTradesPerDay)
      return false;
   if(IsDailyLossBlocked() || IsEquityDrawdownBlocked())
      return false;
   if(cooldownUntil > 0 && barTime < cooldownUntil)
      return false;
   return true;
  }

bool OpenLongTrade(double stopDistancePips)
  {
   if(stopDistancePips <= 0.0)
      return false;

   double pip = GetPipSize();
   if(pip <= 0.0)
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(runtimeSymbol, tick))
      return false;

   double entry = tick.ask;
   double stop = NormalizePrice(entry - stopDistancePips * pip);
   double target = NormalizePrice(entry + stopDistancePips * InpTargetRMultiple * pip);
   double volume = CalculateVolume(entry - stop);
   if(volume <= 0.0)
      return false;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);
   string comment = "m1_context_pullback_long";
   if(!trade.Buy(volume, runtimeSymbol, entry, stop, target, comment))
     {
      PrintFormat("Buy failed: %d", GetLastError());
      return false;
     }

   dailyTradeCount++;
   return true;
  }

int OnInit()
  {
   runtimeSymbol = NormalizePresetString(InpSymbol);
   if(runtimeSymbol == "")
      return INIT_PARAMETERS_INCORRECT;
   if(!SymbolSelect(runtimeSymbol, true))
      return INIT_FAILED;

   string weekdayInput = NormalizePresetString(InpAllowedWeekdays);
   if(!ParseWeekdays(weekdayInput))
      return INIT_PARAMETERS_INCORRECT;

   if(InpPullbackBars < 3 || InpRequiredClosesBelowFast < 1 || InpTargetRMultiple <= 0.0 ||
      InpStopFloorPips <= 0.0 || InpStopCapPips <= InpStopFloorPips || InpMaxHoldBars <= 0 ||
      InpRiskPercent <= 0.0 || InpMaxTradesPerDay < 1 || InpConsecutiveLossLimit < 1 || InpCooldownBarsAfterLosses < 0)
      return INIT_PARAMETERS_INCORRECT;

   fastRegimeEmaHandle = iMA(runtimeSymbol, InpRegimeTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowRegimeEmaHandle = iMA(runtimeSymbol, InpRegimeTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   fastExecEmaHandle = iMA(runtimeSymbol, InpExecutionTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   triggerExecEmaHandle = iMA(runtimeSymbol, InpExecutionTimeframe, InpTriggerEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   stopExecEmaHandle = iMA(runtimeSymbol, InpExecutionTimeframe, InpStopEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   execRsiHandle = iRSI(runtimeSymbol, InpExecutionTimeframe, InpRsiPeriod, PRICE_CLOSE);

   if(fastRegimeEmaHandle == INVALID_HANDLE || slowRegimeEmaHandle == INVALID_HANDLE ||
      fastExecEmaHandle == INVALID_HANDLE || triggerExecEmaHandle == INVALID_HANDLE ||
      stopExecEmaHandle == INVALID_HANDLE || execRsiHandle == INVALID_HANDLE)
      return INIT_FAILED;

   ResetDayState(TimeCurrent());
   UpdateEquityPeak();
   trade.SetExpertMagicNumber(InpMagicNumber);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(fastRegimeEmaHandle != INVALID_HANDLE)
      IndicatorRelease(fastRegimeEmaHandle);
   if(slowRegimeEmaHandle != INVALID_HANDLE)
      IndicatorRelease(slowRegimeEmaHandle);
   if(fastExecEmaHandle != INVALID_HANDLE)
      IndicatorRelease(fastExecEmaHandle);
   if(triggerExecEmaHandle != INVALID_HANDLE)
      IndicatorRelease(triggerExecEmaHandle);
   if(stopExecEmaHandle != INVALID_HANDLE)
      IndicatorRelease(stopExecEmaHandle);
   if(execRsiHandle != INVALID_HANDLE)
      IndicatorRelease(execRsiHandle);
  }

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   ulong dealTicket = trans.deal;
   if(dealTicket == 0 || !HistoryDealSelect(dealTicket))
      return;

   if((string)HistoryDealGetString(dealTicket, DEAL_SYMBOL) != runtimeSymbol)
      return;
   if((long)HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber)
      return;
   if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
      return;

   double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT) + HistoryDealGetDouble(dealTicket, DEAL_SWAP) +
                   HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   if(profit < 0.0)
     {
      consecutiveLosses++;
      if(consecutiveLosses >= InpConsecutiveLossLimit)
        {
         cooldownUntil = TimeCurrent() + (datetime)(InpCooldownBarsAfterLosses * PeriodSeconds(InpExecutionTimeframe));
         PrintFormat("Cooldown activated until %s after %d losses.", TimeToString(cooldownUntil, TIME_DATE | TIME_MINUTES), consecutiveLosses);
        }
     }
   else if(profit > 0.0)
     {
      consecutiveLosses = 0;
      cooldownUntil = 0;
     }
  }

void OnTick()
  {
   if(runtimeSymbol == "")
      return;

   ResetDayState(TimeCurrent());
   UpdateEquityPeak();

   if(IsDailyLossBlocked())
     {
      if(InpFlattenOnDailyLossCap)
         FlattenManagedPositions("daily_loss_cap");
      return;
     }

   if(IsEquityDrawdownBlocked())
     {
      if(InpFlattenOnEquityDrawdownCap)
         FlattenManagedPositions("equity_drawdown_cap");
      return;
     }

   ManageOpenPosition();

   datetime executionBarTime = 0;
   if(!IsNewBar(executionBarTime))
      return;

   MqlDateTime ts;
   TimeToStruct(executionBarTime, ts);
   if(!IsAllowedWeekday(ts.day_of_week))
      return;
   if(!IsWithinActiveSession(executionBarTime))
      return;
   if(!IsSpreadAllowed())
      return;
   if(!CanOpenAnotherTrade(executionBarTime))
      return;

   MqlRates regimeRates[];
   double regimeFastEma[];
   double regimeSlowEma[];
   if(!LoadRegimeWindow(regimeRates, regimeFastEma, regimeSlowEma, 120))
      return;
   if(!IsBullishRegime(regimeRates, regimeFastEma, regimeSlowEma))
      return;

   MqlRates executionRates[];
   double execFastEma[];
   double execTriggerEma[];
   double execStopEma[];
   double execRsi[];
   if(!LoadExecutionWindow(executionRates, execFastEma, execTriggerEma, execStopEma, execRsi, 160))
      return;

   double plannedStopPips = 0.0;
   if(!EvaluateExecutionSignal(executionRates, execFastEma, execTriggerEma, execStopEma, execRsi, plannedStopPips))
      return;

   OpenLongTrade(plannedStopPips);
  }
