//+------------------------------------------------------------------+
//| USDJPY M5 Short Breakout Guarded                                |
//+------------------------------------------------------------------+
#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "1.00"
#property strict
#property description "USDJPY M5 short breakout-retest under M15 bearish context with structure stop, explicit R target, and risk guards."

#include <Trade\Trade.mqh>

CTrade trade;

struct PivotPoint
  {
   bool     valid;
   int      shift;
   double   price;
  };

input string          InpSymbol                          = "USDJPY";
input ENUM_TIMEFRAMES InpSignalTimeframe                 = PERIOD_M5;
input ENUM_TIMEFRAMES InpContextTimeframe                = PERIOD_M15;
input int             InpSignalFastEMAPeriod             = 13;
input int             InpContextFastEMAPeriod            = 13;
input int             InpContextSlowEMAPeriod            = 100;
input int             InpContextSlowSlopeLookback        = 5;
input double          InpContextMinSlowSlopePips         = 1.0;
input int             InpContextPivotSpan                = 2;
input int             InpContextPivotScanBars            = 80;
input int             InpSessionStartHour                = 7;
input int             InpSessionEndHour                  = 18;
input int             InpSupportLookbackBars             = 12;
input int             InpBreakoutBodyLookbackBars        = 20;
input double          InpMinBreakoutBodyPips             = 3.5;
input double          InpMinBreakoutBodyToRange          = 0.55;
input double          InpMinBreakoutVsAverageBody        = 1.10;
input double          InpMaxBreakoutCloseFromLow         = 0.30;
input double          InpMaxBreakoutBelowFastEmaPips     = 10.0;
input double          InpRetestTouchBufferPips           = 0.40;
input double          InpRetestMaxOvershootPips          = 0.80;
input double          InpMinRetestBodyPips               = 1.20;
input double          InpMaxRetestCloseFromLow           = 0.35;
input double          InpMinRetestCloseBelowSupportPips  = 0.20;
input int             InpStopPivotSpan                   = 2;
input int             InpStopScanBars                    = 20;
input double          InpStopBufferPips                  = 1.20;
input double          InpMinStopPips                     = 8.0;
input double          InpMaxStopPips                     = 18.0;
input double          InpTargetRMultiple                 = 1.40;
input int             InpMaxHoldBars                     = 18;
input double          InpRiskPercent                     = 0.35;
input bool            InpSkipTradeWhenMinLotRiskTooHigh  = true;
input double          InpMaxEffectiveRiskPercentAtMinLot = 1.25;
input bool            InpUseDailyLossCap                 = true;
input double          InpDailyLossCapPercent             = 3.0;
input bool            InpUseEquityKillSwitch             = true;
input double          InpEquityKillSwitchPercent         = 8.0;
input int             InpMaxTradesPerDay                 = 2;
input double          InpMaxSpreadPips                   = 2.0;
input double          InpMaxDeviationPips                = 1.5;
input string          InpAllowedWeekdays                 = "1,2,3,4,5";
input long            InpMagicNumber                     = 20260411;

int signalFastHandle = INVALID_HANDLE;
int contextFastHandle = INVALID_HANDLE;
int contextSlowHandle = INVALID_HANDLE;
string runtimeSymbol = "";
bool allowedWeekdays[7];
datetime lastBarTime = 0;
datetime currentDayStart = 0;
double dailyStartEquity = 0.0;
double equityPeak = 0.0;
int dailyTradeCount = 0;
bool dailyLossLocked = false;
bool equityDdLocked = false;

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
   return NormalizeDouble(price, (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_DIGITS));
  }

double GetSpreadPips()
  {
   double pip = GetPipSize();
   if(pip <= 0.0)
      return DBL_MAX;
   return (double)SymbolInfoInteger(runtimeSymbol, SYMBOL_SPREAD) * SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT) / pip;
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

double CloseFromLow(double highValue, double lowValue, double closeValue)
  {
   double range = highValue - lowValue;
   if(range <= 0.0)
      return 0.5;
   return (closeValue - lowValue) / range;
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
      dailyLossLocked = false;
     }
  }

void UpdateEquityPeak()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity > equityPeak)
      equityPeak = equity;
  }

bool IsWithinActiveSession(datetime barTime)
  {
   MqlDateTime ts;
   TimeToStruct(barTime, ts);
   if(InpSessionStartHour < InpSessionEndHour)
      return ts.hour >= InpSessionStartHour && ts.hour < InpSessionEndHour;
   return ts.hour >= InpSessionStartHour || ts.hour < InpSessionEndHour;
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

bool IsPivotHigh(const MqlRates &rates[], int shift, int span)
  {
   for(int i = 1; i <= span; ++i)
      if(rates[shift].high <= rates[shift - i].high || rates[shift].high <= rates[shift + i].high)
         return false;
   return true;
  }

bool IsPivotLow(const MqlRates &rates[], int shift, int span)
  {
   for(int i = 1; i <= span; ++i)
      if(rates[shift].low >= rates[shift - i].low || rates[shift].low >= rates[shift + i].low)
         return false;
   return true;
  }

bool FindRecentPivot(const MqlRates &rates[], int startShift, int scanBars, int span, bool highs, PivotPoint &pivot)
  {
   pivot.valid = false;
   int maxShift = MathMin(ArraySize(rates) - span - 1, startShift + scanBars);
   for(int shift = startShift; shift <= maxShift; ++shift)
     {
      if(shift - span < 0)
         continue;
      bool isPivot = highs ? IsPivotHigh(rates, shift, span) : IsPivotLow(rates, shift, span);
      if(!isPivot)
         continue;
      pivot.valid = true;
      pivot.shift = shift;
      pivot.price = highs ? rates[shift].high : rates[shift].low;
      return true;
     }
   return false;
  }

double AverageBodyPips(const MqlRates &rates[], int startShift, int lookback, double pip)
  {
   double total = 0.0;
   int count = 0;
   for(int shift = startShift; shift < startShift + lookback && shift < ArraySize(rates); ++shift)
     {
      total += MathAbs(rates[shift].close - rates[shift].open) / pip;
      count++;
     }
   if(count <= 0)
      return 0.0;
   return total / count;
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

void EnforceRiskGuards()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(InpUseDailyLossCap && dailyStartEquity > 0.0)
     {
      double dailyLossPct = 100.0 * (dailyStartEquity - equity) / dailyStartEquity;
      if(dailyLossPct >= InpDailyLossCapPercent)
         dailyLossLocked = true;
     }
   if(InpUseEquityKillSwitch && equityPeak > 0.0)
     {
      double drawdownPct = 100.0 * (equityPeak - equity) / equityPeak;
      if(drawdownPct >= InpEquityKillSwitchPercent)
         equityDdLocked = true;
     }
   if(dailyLossLocked || equityDdLocked)
      FlattenManagedPositions();
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
      double minLotRiskPct = 100.0 * (moneyPerLot * minVolume) / equity;
      if(minLotRiskPct > InpMaxEffectiveRiskPercentAtMinLot)
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

bool IsBearishContext(const MqlRates &rates[], const double &fastEma[], const double &slowEma[], int shift)
  {
   double pip = GetPipSize();
   if(shift + InpContextSlowSlopeLookback >= ArraySize(rates))
      return false;
   if(fastEma[shift] >= slowEma[shift] || rates[shift].close >= slowEma[shift] || rates[shift].close >= fastEma[shift])
      return false;
   double slowSlopePips = (slowEma[shift] - slowEma[shift + InpContextSlowSlopeLookback]) / pip;
   if(slowSlopePips > -InpContextMinSlowSlopePips)
      return false;
   PivotPoint latestHigh;
   PivotPoint previousHigh;
   PivotPoint latestLow;
   PivotPoint previousLow;
   if(!FindRecentPivot(rates, shift + InpContextPivotSpan + 1, InpContextPivotScanBars, InpContextPivotSpan, true, latestHigh))
      return false;
   if(!FindRecentPivot(rates, latestHigh.shift + 1, InpContextPivotScanBars, InpContextPivotSpan, true, previousHigh))
      return false;
   if(!FindRecentPivot(rates, shift + InpContextPivotSpan + 1, InpContextPivotScanBars, InpContextPivotSpan, false, latestLow))
      return false;
   if(!FindRecentPivot(rates, latestLow.shift + 1, InpContextPivotScanBars, InpContextPivotSpan, false, previousLow))
      return false;
   return latestHigh.price < previousHigh.price && latestLow.price < previousLow.price;
  }

bool EvaluateSignal(double &stopPrice)
  {
   MqlRates signalRates[];
   MqlRates contextRates[];
   double signalFast[];
   double contextFast[];
   double contextSlow[];
   ArraySetAsSeries(signalRates, true);
   ArraySetAsSeries(contextRates, true);
   ArraySetAsSeries(signalFast, true);
   ArraySetAsSeries(contextFast, true);
   ArraySetAsSeries(contextSlow, true);
   int signalCount = CopyRates(runtimeSymbol, InpSignalTimeframe, 0, 80, signalRates);
   int contextCount = CopyRates(runtimeSymbol, InpContextTimeframe, 0, 220, contextRates);
   if(signalCount < 40 || contextCount < 120)
      return false;
   if(CopyBuffer(signalFastHandle, 0, 0, signalCount, signalFast) != signalCount)
      return false;
   if(CopyBuffer(contextFastHandle, 0, 0, contextCount, contextFast) != contextCount)
      return false;
   if(CopyBuffer(contextSlowHandle, 0, 0, contextCount, contextSlow) != contextCount)
      return false;

   datetime signalTime = signalRates[1].time;
   if(signalTime == 0 || !IsWithinActiveSession(signalTime))
      return false;
   MqlDateTime ts;
   TimeToStruct(signalTime, ts);
   if(ts.day_of_week < 0 || ts.day_of_week > 6 || !allowedWeekdays[ts.day_of_week])
      return false;

   int contextShift = iBarShift(runtimeSymbol, InpContextTimeframe, signalTime, false);
   if(contextShift < 1)
      contextShift = 1;
   if(!IsBearishContext(contextRates, contextFast, contextSlow, contextShift))
      return false;

   double pip = GetPipSize();
   double support = DBL_MAX;
   for(int shift = 3; shift < 3 + InpSupportLookbackBars && shift < signalCount; ++shift)
      if(signalRates[shift].low < support)
         support = signalRates[shift].low;
   if(support == DBL_MAX)
      return false;

   MqlRates breakoutBar = signalRates[2];
   MqlRates retestBar = signalRates[1];
   double breakoutBodyPips = MathAbs(breakoutBar.close - breakoutBar.open) / pip;
   double breakoutRangePips = (breakoutBar.high - breakoutBar.low) / pip;
   if(breakoutBar.close >= breakoutBar.open || breakoutBodyPips < InpMinBreakoutBodyPips || breakoutRangePips <= 0.0)
      return false;
   if(breakoutBar.open < support || breakoutBar.close >= support)
      return false;
   if((breakoutBar.high < support) || (breakoutBar.high > support + (InpRetestMaxOvershootPips * pip)))
      return false;
   if((breakoutBodyPips / breakoutRangePips) < InpMinBreakoutBodyToRange)
      return false;
   if(CloseFromLow(breakoutBar.high, breakoutBar.low, breakoutBar.close) > InpMaxBreakoutCloseFromLow)
      return false;
   double avgBody = AverageBodyPips(signalRates, 3, InpBreakoutBodyLookbackBars, pip);
   if(avgBody <= 0.0 || (breakoutBodyPips / avgBody) < InpMinBreakoutVsAverageBody)
      return false;
   if(((signalFast[2] - breakoutBar.close) / pip) > InpMaxBreakoutBelowFastEmaPips)
      return false;

   double retestBodyPips = MathAbs(retestBar.close - retestBar.open) / pip;
   if(retestBar.close >= retestBar.open || retestBodyPips < InpMinRetestBodyPips)
      return false;
   if(retestBar.high < support - (InpRetestTouchBufferPips * pip))
      return false;
   if(retestBar.high > support + (InpRetestMaxOvershootPips * pip))
      return false;
   if(retestBar.close > support - (InpMinRetestCloseBelowSupportPips * pip))
      return false;
   if(retestBar.close >= signalFast[1])
      return false;
   if(CloseFromLow(retestBar.high, retestBar.low, retestBar.close) > InpMaxRetestCloseFromLow)
      return false;

   PivotPoint pivotHigh;
   double highestHigh = MathMax(breakoutBar.high, retestBar.high);
   for(int shift = 1; shift < 1 + InpStopScanBars && shift < signalCount; ++shift)
      if(signalRates[shift].high > highestHigh)
         highestHigh = signalRates[shift].high;
   if(FindRecentPivot(signalRates, 1 + InpStopPivotSpan, InpStopScanBars, InpStopPivotSpan, true, pivotHigh) && pivotHigh.price > highestHigh)
      highestHigh = pivotHigh.price;

   stopPrice = NormalizePrice(highestHigh + (InpStopBufferPips * pip));
   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   if(bid <= 0.0 || stopPrice <= bid)
      return false;
   double stopPips = (stopPrice - bid) / pip;
   if(stopPips < InpMinStopPips || stopPips > InpMaxStopPips)
      return false;
   return true;
  }

bool OpenShortPosition(double stopPrice)
  {
   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   if(bid <= 0.0 || stopPrice <= bid)
      return false;
   double stopDistance = stopPrice - bid;
   double volume = CalculateVolume(stopDistance);
   if(volume <= 0.0)
      return false;
   double tp = 0.0;
   if(InpTargetRMultiple > 0.0)
      tp = NormalizePrice(bid - (stopDistance * InpTargetRMultiple));
   if(trade.Sell(volume, runtimeSymbol, 0.0, stopPrice, tp, "m5_short_breakout"))
     {
      dailyTradeCount++;
      return true;
     }
   Print("Order failed: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
   return false;
  }

void ManageOpenPosition()
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
      int barsOpen = iBarShift(runtimeSymbol, InpSignalTimeframe, openedAt, false);
      if(barsOpen < InpMaxHoldBars)
         continue;
      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      trade.PositionClose(ticket);
     }
  }

int OnInit()
  {
   runtimeSymbol = NormalizePresetString(InpSymbol);
   if(InpContextFastEMAPeriod <= 0 || InpContextSlowEMAPeriod <= InpContextFastEMAPeriod ||
      InpSignalFastEMAPeriod <= 0 || InpSupportLookbackBars < 4 || InpBreakoutBodyLookbackBars < 5 ||
      InpContextSlowSlopeLookback <= 0 || InpContextPivotSpan <= 0 || InpStopPivotSpan <= 0 ||
      InpStopScanBars < 4 || InpTargetRMultiple <= 0.0 || InpMinStopPips <= 0.0 ||
      InpMaxStopPips <= InpMinStopPips || InpRiskPercent <= 0.0 || InpMagicNumber <= 0)
     {
      Print("Invalid breakout-guarded parameters.");
      return INIT_PARAMETERS_INCORRECT;
     }
   if(!ParseWeekdays(InpAllowedWeekdays))
      return INIT_PARAMETERS_INCORRECT;
   if(!SymbolInfoInteger(runtimeSymbol, SYMBOL_SELECT) && !SymbolSelect(runtimeSymbol, true))
      return INIT_FAILED;

   signalFastHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpSignalFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   contextFastHandle = iMA(runtimeSymbol, InpContextTimeframe, InpContextFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   contextSlowHandle = iMA(runtimeSymbol, InpContextTimeframe, InpContextSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(signalFastHandle == INVALID_HANDLE || contextFastHandle == INVALID_HANDLE || contextSlowHandle == INVALID_HANDLE)
      return INIT_FAILED;

   trade.SetExpertMagicNumber((ulong)InpMagicNumber);
   double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   double pip = GetPipSize();
   if(point > 0.0 && pip > 0.0)
      trade.SetDeviationInPoints((int)MathMax(0.0, MathRound(InpMaxDeviationPips * pip / point)));

   ResetDayState(TimeCurrent());
   equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(signalFastHandle != INVALID_HANDLE)
      IndicatorRelease(signalFastHandle);
   if(contextFastHandle != INVALID_HANDLE)
      IndicatorRelease(contextFastHandle);
   if(contextSlowHandle != INVALID_HANDLE)
      IndicatorRelease(contextSlowHandle);
  }

void OnTick()
  {
   UpdateEquityPeak();
   ResetDayState(TimeCurrent());
   EnforceRiskGuards();
   ManageOpenPosition();

   datetime barTime = 0;
   if(!IsNewBar(barTime))
      return;
   if(dailyLossLocked || equityDdLocked)
      return;
   if(GetSpreadPips() > InpMaxSpreadPips)
      return;
   if(CountManagedPositions() > 0)
      return;
   if(InpMaxTradesPerDay > 0 && dailyTradeCount >= InpMaxTradesPerDay)
      return;

   double stopPrice = 0.0;
   if(!EvaluateSignal(stopPrice))
      return;
   OpenShortPosition(stopPrice);
  }
