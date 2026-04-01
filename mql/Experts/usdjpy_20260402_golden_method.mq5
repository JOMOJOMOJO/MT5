//+------------------------------------------------------------------+
//| USDJPY Golden Method Prototype                                   |
//+------------------------------------------------------------------+
#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "1.00"
#property strict
#property description "USDJPY Golden Method prototype using EMA13/EMA100, Dow-style swing trend, and round-number breakout follow-through."

#include <Trade\Trade.mqh>

CTrade trade;

enum TrendDirection
  {
   TrendNone = 0,
   TrendUp = 1,
   TrendDown = -1
  };

struct PivotPoint
  {
   bool     valid;
   int      shift;
   double   price;
   datetime time;
  };

struct TrendContext
  {
   int      direction;
   double   fastEma;
   double   slowEma;
   double   slowSlope;
   double   transitionLine;
   PivotPoint latestHigh;
   PivotPoint previousHigh;
   PivotPoint latestLow;
   PivotPoint previousLow;
  };

struct BreakoutState
  {
   bool     active;
   int      direction;
   double   roundLevel;
   double   midpoint;
   int      barsRemaining;
   datetime breakoutBarTime;
  };

input string          InpSymbol                      = "USDJPY";
input ENUM_TIMEFRAMES InpSignalTimeframe             = PERIOD_M5;
input int             InpFastEMAPeriod               = 13;
input int             InpSlowEMAPeriod               = 100;
input int             InpSlowSlopeLookback           = 5;
input int             InpPivotSpan                   = 2;
input int             InpTrendScanBars               = 180;
input bool            InpEnableStrategy1             = true;
input bool            InpEnableStrategy2             = true;
input double          InpTouchTolerancePips          = 0.6;
input double          InpStopLossPips                = 10.0;
input double          InpTakeProfitPips              = 10.0;
input double          InpRiskPercent                 = 2.0;
input bool            InpUseDailyLossCap             = true;
input double          InpDailyLossCapPercent         = 6.0;
input int             InpMaxTradesPerDay             = 1;
input double          InpMaxSpreadPips               = 2.0;
input int             InpRoundStepPips               = 50;
input int             InpVolatilityLookbackBars      = 24;
input int             InpRoundTouchLookbackBars      = 144;
input int             InpMaxRoundTouchesBeforeBreak  = 2;
input double          InpBreakoutMinBodyPips         = 4.0;
input double          InpBreakoutBodyToRangeMin      = 0.70;
input double          InpBreakoutVsAverageBodyMin    = 1.60;
input int             InpBreakoutExpiryBars          = 144;
input double          InpRoundMidpointBufferPips     = 1.0;
input string          InpAllowedWeekdays             = "1,2,3,4,5";
input long            InpMagicNumber                 = 20260492;

int fastEmaHandle = INVALID_HANDLE;
int slowEmaHandle = INVALID_HANDLE;

string runtimeSymbol = "";
bool allowedWeekdays[7];
datetime lastBarTime = 0;
datetime currentDayStart = 0;
double dailyStartEquity = 0.0;
int dailyTradeCount = 0;
BreakoutState breakoutState;

int OnInit()
  {
   runtimeSymbol = NormalizePresetString(InpSymbol);
   ArrayInitialize(allowedWeekdays, false);

   if(InpFastEMAPeriod <= 0 || InpSlowEMAPeriod <= InpFastEMAPeriod || InpPivotSpan <= 0 ||
      InpTrendScanBars <= 20 || InpSlowSlopeLookback <= 0 || InpTouchTolerancePips < 0.0 ||
      InpStopLossPips <= 0.0 || InpTakeProfitPips <= 0.0 || InpRiskPercent <= 0.0 ||
      InpMaxTradesPerDay < 0 || InpRoundStepPips <= 0 || InpVolatilityLookbackBars <= 0 ||
      InpRoundTouchLookbackBars <= 0 || InpBreakoutMinBodyPips <= 0.0 || InpMagicNumber <= 0)
     {
      Print("Invalid USDJPY Golden Method parameters.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!ParseWeekdays(InpAllowedWeekdays))
     {
      Print("Invalid weekday filter.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!SymbolInfoInteger(runtimeSymbol, SYMBOL_SELECT))
     {
      if(!SymbolSelect(runtimeSymbol, true))
        {
         Print("Failed to select symbol ", runtimeSymbol);
         return INIT_FAILED;
        }
     }

   fastEmaHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowEmaHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(fastEmaHandle == INVALID_HANDLE || slowEmaHandle == INVALID_HANDLE)
     {
      Print("Failed to create EMA handles.");
      return INIT_FAILED;
     }

   trade.SetExpertMagicNumber((ulong)InpMagicNumber);
   trade.SetDeviationInPoints((int)MathMax(10.0, PipToPoints(1.0)));

   ResetDayState(TimeCurrent());
   breakoutState.active = false;
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

   MqlRates rates[];
   double fastEma[];
   double slowEma[];
   if(!LoadSignalWindow(rates, fastEma, slowEma, 260))
      return;

   if(CountManagedPositions() > 0)
      return;

   if(!CanOpenAnotherTrade())
      return;

   TrendContext trend;
   BuildTrendContext(rates, fastEma, slowEma, trend);

   bool justArmedBreakout = UpdateBreakoutState(rates, fastEma, slowEma, trend);

   int signalDirection = TrendNone;
   string signalTag = "";

   if(!justArmedBreakout && InpEnableStrategy2 && EvaluateStrategy2(rates, fastEma, slowEma, trend, signalDirection, signalTag))
     {
      OpenPosition(signalDirection, signalTag);
      return;
     }

   if(InpEnableStrategy1 && EvaluateStrategy1(rates, fastEma, slowEma, trend, signalDirection, signalTag))
     {
      OpenPosition(signalDirection, signalTag);
      return;
     }
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

bool LoadSignalWindow(MqlRates &rates[], double &fastEma[], double &slowEma[], int count)
  {
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(fastEma, true);
   ArraySetAsSeries(slowEma, true);

   int copiedRates = CopyRates(runtimeSymbol, InpSignalTimeframe, 0, count, rates);
   if(copiedRates < 120)
      return false;

   int copiedFast = CopyBuffer(fastEmaHandle, 0, 0, count, fastEma);
   int copiedSlow = CopyBuffer(slowEmaHandle, 0, 0, count, slowEma);
   if(copiedFast != copiedRates || copiedSlow != copiedRates)
      return false;

   return true;
  }

bool CanOpenAnotherTrade()
  {
   if(CountManagedPositions() > 0)
      return false;

   if(dailyTradeCount >= InpMaxTradesPerDay)
      return false;

   MqlDateTime ts;
   TimeToStruct(TimeCurrent(), ts);
   if(ts.day_of_week < 0 || ts.day_of_week > 6 || !allowedWeekdays[ts.day_of_week])
      return false;

   if(InpUseDailyLossCap && dailyStartEquity > 0.0)
     {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      if(equity <= dailyStartEquity * (1.0 - InpDailyLossCapPercent / 100.0))
         return false;
     }

   if(GetSpreadPips() > InpMaxSpreadPips)
      return false;

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

double GetPipSize()
  {
   double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
  }

double PipToPoints(double pips)
  {
   double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   double pip = GetPipSize();
   if(point <= 0.0)
      return 0.0;
   return (pips * pip) / point;
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

double GetRoundStepPrice()
  {
   return GetPipSize() * InpRoundStepPips;
  }

double NormalizePrice(double price)
  {
   int digits = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
  }

bool BarTouchesPrice(const MqlRates &bar, double level, double tolerance)
  {
   return bar.low <= level + tolerance && bar.high >= level - tolerance;
  }

double AverageBodyPips(const MqlRates &rates[], int startShift, int lookback)
  {
   double pip = GetPipSize();
   if(pip <= 0.0)
      return 0.0;

   double total = 0.0;
   int count = 0;
   int size = ArraySize(rates);
   int maxShift = MathMin(size - 1, startShift + lookback - 1);
   for(int shift = startShift; shift <= maxShift; ++shift)
     {
      total += MathAbs(rates[shift].close - rates[shift].open) / pip;
      count++;
     }

   if(count <= 0)
      return 0.0;
   return total / count;
  }

int CountRoundTouches(const MqlRates &rates[], double roundLevel, double tolerance, int startShift, int lookback)
  {
   int touches = 0;
   int size = ArraySize(rates);
   int maxShift = MathMin(size - 1, startShift + lookback - 1);
   for(int shift = startShift; shift <= maxShift; ++shift)
     {
      if(rates[shift].high >= roundLevel - tolerance && rates[shift].low <= roundLevel + tolerance)
         touches++;
     }
   return touches;
  }

bool IsLowVolatilitySameZone(const MqlRates &rates[])
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

   double zoneStep = GetRoundStepPrice();
   if(zoneStep <= 0.0)
      return false;

   long highZone = (long)MathFloor(highest / zoneStep);
   long lowZone = (long)MathFloor(lowest / zoneStep);
   return highZone == lowZone;
  }

bool IsPivotHigh(const MqlRates &rates[], int shift, int span)
  {
   int size = ArraySize(rates);
   if(shift - span < 1 || shift + span >= size)
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
   if(shift - span < 1 || shift + span >= size)
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
   int maxShift = MathMin(size - InpPivotSpan - 1, InpTrendScanBars);
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

void BuildTrendContext(const MqlRates &rates[], const double &fastEma[], const double &slowEma[], TrendContext &trend)
  {
   trend.direction = TrendNone;
   trend.fastEma = fastEma[1];
   trend.slowEma = slowEma[1];
   trend.slowSlope = slowEma[1] - slowEma[1 + InpSlowSlopeLookback];
   trend.transitionLine = 0.0;

   FindRecentPivots(rates, true, trend.latestHigh, trend.previousHigh);
   FindRecentPivots(rates, false, trend.latestLow, trend.previousLow);

   bool upTrend = trend.latestHigh.valid && trend.previousHigh.valid && trend.latestLow.valid && trend.previousLow.valid &&
                  trend.latestHigh.price > trend.previousHigh.price && trend.latestLow.price > trend.previousLow.price &&
                  trend.slowSlope > 0.0 && rates[1].close > slowEma[1];

   bool downTrend = trend.latestHigh.valid && trend.previousHigh.valid && trend.latestLow.valid && trend.previousLow.valid &&
                    trend.latestHigh.price < trend.previousHigh.price && trend.latestLow.price < trend.previousLow.price &&
                    trend.slowSlope < 0.0 && rates[1].close < slowEma[1];

   if(upTrend)
     {
      trend.direction = TrendUp;
      trend.transitionLine = trend.latestLow.price;
     }
   else if(downTrend)
     {
      trend.direction = TrendDown;
      trend.transitionLine = trend.latestHigh.price;
     }
  }

bool EvaluateStrategy1(const MqlRates &rates[], const double &fastEma[], const double &slowEma[], const TrendContext &trend, int &direction, string &tag)
  {
   direction = TrendNone;
   tag = "";

   double tolerance = InpTouchTolerancePips * GetPipSize();
   if(tolerance < 0.0)
      return false;

   if(IsLowVolatilitySameZone(rates))
      return false;

   if(trend.direction == TrendUp)
     {
      if(!BarTouchesPrice(rates[1], fastEma[1], tolerance))
         return false;
      if(rates[1].low <= trend.transitionLine)
         return false;
      if(rates[2].close <= fastEma[2] || rates[3].close <= fastEma[3])
         return false;
      if(rates[1].close < fastEma[1])
         return false;

      direction = TrendUp;
      tag = "golden_s1_buy";
      return true;
     }

   if(trend.direction == TrendDown)
     {
      if(!BarTouchesPrice(rates[1], fastEma[1], tolerance))
         return false;
      if(rates[1].high >= trend.transitionLine)
         return false;
      if(rates[2].close >= fastEma[2] || rates[3].close >= fastEma[3])
         return false;
      if(rates[1].close > fastEma[1])
         return false;

      direction = TrendDown;
      tag = "golden_s1_sell";
      return true;
     }

   return false;
  }

bool FindBreakoutLevel(const MqlRates &bar, int direction, double &level)
  {
   double step = GetRoundStepPrice();
   if(step <= 0.0)
      return false;

   int startIndex = (int)MathFloor(bar.low / step) - 1;
   int endIndex = (int)MathCeil(bar.high / step) + 1;
   for(int index = startIndex; index <= endIndex; ++index)
     {
      double candidate = index * step;
      if(direction == TrendUp && bar.open < candidate && bar.close > candidate)
        {
         level = candidate;
         return true;
        }
      if(direction == TrendDown && bar.open > candidate && bar.close < candidate)
        {
         level = candidate;
         return true;
        }
     }

   return false;
  }

bool BreakoutCandleIsLarge(const MqlRates &bar, const MqlRates &rates[])
  {
   double pip = GetPipSize();
   if(pip <= 0.0)
      return false;

   double body = MathAbs(bar.close - bar.open) / pip;
   double range = (bar.high - bar.low) / pip;
   if(body < InpBreakoutMinBodyPips || range <= 0.0)
      return false;

   double bodyToRange = body / range;
   if(bodyToRange < InpBreakoutBodyToRangeMin)
      return false;

   double upperWick = (bar.high - MathMax(bar.open, bar.close)) / pip;
   double lowerWick = (MathMin(bar.open, bar.close) - bar.low) / pip;
   if(MathMax(upperWick, lowerWick) > body * 0.35)
      return false;

   double averageBody = AverageBodyPips(rates, 2, 20);
   if(averageBody > 0.0 && body < averageBody * InpBreakoutVsAverageBodyMin)
      return false;

   return true;
  }

bool DetectNewBreakout(const MqlRates &rates[], const double &slowEma[], const TrendContext &trend, BreakoutState &state)
  {
   double level = 0.0;
   double tolerance = InpTouchTolerancePips * GetPipSize();

   int direction = TrendNone;
   if(FindBreakoutLevel(rates[1], TrendUp, level))
      direction = TrendUp;
   else if(FindBreakoutLevel(rates[1], TrendDown, level))
      direction = TrendDown;
   else
      return false;

   if(!BreakoutCandleIsLarge(rates[1], rates))
      return false;

   if(direction == TrendUp && (trend.slowSlope <= 0.0 || rates[1].close <= slowEma[1]))
      return false;
   if(direction == TrendDown && (trend.slowSlope >= 0.0 || rates[1].close >= slowEma[1]))
      return false;

   int touches = CountRoundTouches(rates, level, tolerance, 2, InpRoundTouchLookbackBars);
   if(touches > InpMaxRoundTouchesBeforeBreak)
      return false;

   state.active = true;
   state.direction = direction;
   state.roundLevel = level;
   state.midpoint = level + direction * (GetRoundStepPrice() * 0.5);
   state.barsRemaining = InpBreakoutExpiryBars;
   state.breakoutBarTime = rates[1].time;
   return true;
  }

bool UpdateBreakoutState(const MqlRates &rates[], const double &fastEma[], const double &slowEma[], const TrendContext &trend)
  {
   if(breakoutState.active)
     {
      breakoutState.barsRemaining--;
      double midpointBuffer = InpRoundMidpointBufferPips * GetPipSize();

      if(breakoutState.direction == TrendUp && rates[1].high >= breakoutState.midpoint - midpointBuffer)
         breakoutState.active = false;
      else if(breakoutState.direction == TrendDown && rates[1].low <= breakoutState.midpoint + midpointBuffer)
         breakoutState.active = false;

      if(breakoutState.barsRemaining <= 0)
         breakoutState.active = false;
     }

   if(breakoutState.active)
      return false;

   BreakoutState candidate;
   candidate.active = false;
   if(DetectNewBreakout(rates, slowEma, trend, candidate))
     {
      breakoutState = candidate;
      return true;
     }

   return false;
  }

bool EvaluateStrategy2(const MqlRates &rates[], const double &fastEma[], const double &slowEma[], const TrendContext &trend, int &direction, string &tag)
  {
   direction = TrendNone;
   tag = "";
   if(!breakoutState.active)
      return false;

   double tolerance = InpTouchTolerancePips * GetPipSize();
   if(!BarTouchesPrice(rates[1], fastEma[1], tolerance))
      return false;

   if(breakoutState.direction == TrendUp)
     {
      if(trend.slowSlope <= 0.0 || rates[1].close < fastEma[1] || rates[1].close < slowEma[1])
         return false;
      direction = TrendUp;
      tag = "golden_s2_buy";
      breakoutState.active = false;
      return true;
     }

   if(breakoutState.direction == TrendDown)
     {
      if(trend.slowSlope >= 0.0 || rates[1].close > fastEma[1] || rates[1].close > slowEma[1])
         return false;
      direction = TrendDown;
      tag = "golden_s2_sell";
      breakoutState.active = false;
      return true;
     }

   return false;
  }

void OpenPosition(int direction, string tag)
  {
   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   double pip = GetPipSize();
   double stopDistance = InpStopLossPips * pip;
   double targetDistance = InpTakeProfitPips * pip;
   double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   int stopsLevel = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_TRADE_STOPS_LEVEL);

   if(stopDistance <= 0.0 || targetDistance <= 0.0 || pip <= 0.0 || point <= 0.0)
      return;

   if(stopDistance < stopsLevel * point || targetDistance < stopsLevel * point)
      return;

   double price = direction == TrendUp ? ask : bid;
   if(price <= 0.0)
      return;

   double sl = 0.0;
   double tp = 0.0;
   if(direction == TrendUp)
     {
      sl = NormalizePrice(price - stopDistance);
      tp = NormalizePrice(price + targetDistance);
     }
   else if(direction == TrendDown)
     {
      sl = NormalizePrice(price + stopDistance);
      tp = NormalizePrice(price - targetDistance);
     }
   else
      return;

   double volume = CalculateVolume(stopDistance);
   if(volume <= 0.0)
      return;

   bool result = false;
   if(direction == TrendUp)
      result = trade.Buy(volume, runtimeSymbol, 0.0, sl, tp, tag);
   else
      result = trade.Sell(volume, runtimeSymbol, 0.0, sl, tp, tag);

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
