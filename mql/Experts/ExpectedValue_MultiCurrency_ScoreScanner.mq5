//+------------------------------------------------------------------+
//| ExpectedValue_MultiCurrency_ScoreScanner                         |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Multi-currency score scanner. Initial mode logs scores and candidate reasons without trading by default."

#include <Trade\Trade.mqh>

CTrade trade;

static const string STRATEGY_NAME = "ExpectedValue_MultiCurrency_ScoreScanner";

input string          InpSymbols                       = "USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD,XAUUSD";
input int             InpScanSeconds                   = 30;
input double          InpEntryScoreThreshold           = 60.0;
input ENUM_TIMEFRAMES InpContextTF                     = PERIOD_H1;
input ENUM_TIMEFRAMES InpPatternTF                     = PERIOD_M15;
input ENUM_TIMEFRAMES InpExecutionTF                   = PERIOD_M5;
input bool            InpEnableTrading                 = false;
input int             InpMaxPositions                  = 1;
input int             InpMaxSameCurrencyGroupPositions = 1;

input long            InpMagicNumber                   = 2026060101;
input int             InpFastMAPeriod                  = 20;
input int             InpSlowMAPeriod                  = 50;
input int             InpATRPeriod                     = 14;
input int             InpATRAveragePeriod              = 60;
input int             InpSlopeLookbackBars             = 5;
input int             InpSetupLookbackBars             = 20;
input double          InpPullbackATR                   = 0.35;
input double          InpMinMomentumBodyATR            = 0.22;

input double          InpRiskPerTradePercent           = 0.50;
input double          InpMaxRiskPerSymbolPercent       = 1.00;
input double          InpMaxTotalOpenRiskPercent       = 3.00;
input double          InpDailyMaxLossPercent           = 3.00;
input double          InpWeeklyMaxLossPercent          = 6.00;
input double          InpMaxDrawdownPercent            = 10.00;
input double          InpMaxSpreadATR                  = 0.20;
input double          InpStopATRMultiplier             = 1.20;
input double          InpMinSL_ATR                     = 0.60;
input double          InpMaxSL_ATR                     = 2.20;
input double          InpRewardR                       = 1.50;
input double          InpFixedLotFallback              = 0.01;
input double          InpMaxLotCap                     = 1.00;
input int             InpSlippagePoints                = 20;

input bool            InpUseCommonFiles                = false;
input string          InpLogFolder                     = "logs";
input string          InpLogPrefix                     = "multicurrency_score";

struct SymbolScore
  {
   string            symbol;
   string            direction;
   double            totalScore;
   double            trendScore;
   double            setupScore;
   double            volatilityScore;
   double            costPenalty;
   double            riskPenalty;
   double            atr;
   double            spreadATR;
   double            stopDistance;
   double            stopLoss;
   double            takeProfit;
   double            volume;
   bool              dataReady;
   string            reason;
  };

string   g_symbols[];
double   g_initialEquity = 0.0;
double   g_peakEquity = 0.0;
double   g_dayStartEquity = 0.0;
double   g_weekStartEquity = 0.0;
int      g_dayKey = 0;
int      g_weekKey = 0;
bool     g_dailyStopped = false;
bool     g_weeklyStopped = false;
bool     g_drawdownStopped = false;
string   g_riskStopReason = "";

//+------------------------------------------------------------------+
//| Generic helpers                                                   |
//+------------------------------------------------------------------+
string Trim(const string value)
  {
   string result = value;
   StringTrimLeft(result);
   StringTrimRight(result);
   return result;
  }

void AppendReason(string &reason, const string token)
  {
   if(token == "")
      return;
   if(reason == "")
      reason = token;
   else
      reason += "|" + token;
  }

double ClampDouble(const double value, const double low, const double high)
  {
   if(value < low)
      return low;
   if(value > high)
      return high;
   return value;
  }

double Max3(const double a, const double b, const double c)
  {
   return MathMax(a, MathMax(b, c));
  }

string DirectionToString(const int direction)
  {
   if(direction > 0)
      return "LONG";
   if(direction < 0)
      return "SHORT";
   return "NONE";
  }

int DateKey(const datetime now)
  {
   MqlDateTime tm;
   TimeToStruct(now, tm);
   return tm.year * 10000 + tm.mon * 100 + tm.day;
  }

int WeekKey(const datetime now)
  {
   MqlDateTime tm;
   TimeToStruct(now, tm);
   return tm.year * 100 + (tm.day_of_year / 7);
  }

bool IsDuplicateSymbol(const string symbol)
  {
   int size = ArraySize(g_symbols);
   for(int i = 0; i < size; ++i)
      if(g_symbols[i] == symbol)
         return true;
   return false;
  }

bool ParseSymbols()
  {
   ArrayResize(g_symbols, 0);

   string parts[];
   int count = StringSplit(InpSymbols, ',', parts);
   if(count <= 0)
      return false;

   for(int i = 0; i < count; ++i)
     {
      string symbol = Trim(parts[i]);
      if(symbol == "" || IsDuplicateSymbol(symbol))
         continue;

      if(!SymbolSelect(symbol, true))
        {
         PrintFormat("%s: SymbolSelect failed for %s", STRATEGY_NAME, symbol);
         continue;
        }

      int size = ArraySize(g_symbols);
      ArrayResize(g_symbols, size + 1);
      g_symbols[size] = symbol;
     }

   return ArraySize(g_symbols) > 0;
  }

//+------------------------------------------------------------------+
//| Market data helpers                                               |
//+------------------------------------------------------------------+
bool LoadRates(const string symbol,
               const ENUM_TIMEFRAMES timeframe,
               const int barsNeeded,
               MqlRates &rates[],
               string &reason)
  {
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(symbol, timeframe, 0, barsNeeded, rates);
   if(copied < barsNeeded)
     {
      reason = "data_insufficient_" + EnumToString(timeframe) + "_" + IntegerToString(copied);
      return false;
     }
   return true;
  }

double AverageClose(const MqlRates &rates[], const int startShift, const int period)
  {
   int size = ArraySize(rates);
   if(period <= 0 || startShift < 0 || startShift + period > size)
      return 0.0;

   double sum = 0.0;
   for(int i = startShift; i < startShift + period; ++i)
      sum += rates[i].close;
   return sum / period;
  }

double TrueRangeAt(const MqlRates &rates[], const int shift)
  {
   int size = ArraySize(rates);
   if(shift < 0 || shift + 1 >= size)
      return 0.0;

   double highLow = rates[shift].high - rates[shift].low;
   double highClose = MathAbs(rates[shift].high - rates[shift + 1].close);
   double lowClose = MathAbs(rates[shift].low - rates[shift + 1].close);
   return Max3(highLow, highClose, lowClose);
  }

double AverageATR(const MqlRates &rates[], const int startShift, const int period)
  {
   int size = ArraySize(rates);
   if(period <= 0 || startShift < 0 || startShift + period + 1 > size)
      return 0.0;

   double sum = 0.0;
   for(int i = startShift; i < startShift + period; ++i)
      sum += TrueRangeAt(rates, i);
   return sum / period;
  }

double HighestHigh(const MqlRates &rates[], const int startShift, const int bars)
  {
   int size = ArraySize(rates);
   if(bars <= 0 || startShift < 0 || startShift + bars > size)
      return 0.0;

   double value = rates[startShift].high;
   for(int i = startShift + 1; i < startShift + bars; ++i)
      value = MathMax(value, rates[i].high);
   return value;
  }

double LowestLow(const MqlRates &rates[], const int startShift, const int bars)
  {
   int size = ArraySize(rates);
   if(bars <= 0 || startShift < 0 || startShift + bars > size)
      return 0.0;

   double value = rates[startShift].low;
   for(int i = startShift + 1; i < startShift + bars; ++i)
      value = MathMin(value, rates[i].low);
   return value;
  }

double SpreadPrice(const string symbol)
  {
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
      return ask - bid;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   long spreadPoints = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
   return (double)spreadPoints * point;
  }

int RequiredBars()
  {
   int need = InpSlowMAPeriod + InpSlopeLookbackBars + InpATRAveragePeriod + InpATRPeriod + 10;
   need = MathMax(need, InpSetupLookbackBars + 10);
   return MathMax(need, 90);
  }

//+------------------------------------------------------------------+
//| Risk and position helpers                                         |
//+------------------------------------------------------------------+
string CurrencyGroup(const string symbol)
  {
   string upper = symbol;
   StringToUpper(upper);

   if(StringFind(upper, "JPY") >= 0)
      return "JPY";
   if(StringFind(upper, "USD") >= 0)
      return "USD";
   if(StringFind(upper, "EUR") >= 0)
      return "EUR";
   if(StringFind(upper, "GBP") >= 0)
      return "GBP";
   if(StringFind(upper, "AUD") >= 0)
      return "AUD";
   if(StringFind(upper, "CAD") >= 0)
      return "CAD";
   if(StringFind(upper, "CHF") >= 0)
      return "CHF";
   if(StringFind(upper, "NZD") >= 0)
      return "NZD";

   if(StringLen(upper) >= 3)
      return StringSubstr(upper, 0, 3);
   return upper;
  }

double PositionRiskPercent()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0)
      return 0.0;

   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double stop = PositionGetDouble(POSITION_SL);
   double volume = PositionGetDouble(POSITION_VOLUME);
   string symbol = PositionGetString(POSITION_SYMBOL);
   if(stop <= 0.0 || volume <= 0.0)
      return InpRiskPerTradePercent;

   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0.0 || tickValue <= 0.0)
      return InpRiskPerTradePercent;

   double money = MathAbs(entry - stop) / tickSize * tickValue * volume;
   return money / equity * 100.0;
  }

int CountManagedPositions()
  {
   int count = 0;
   int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      count++;
     }
   return count;
  }

int CountManagedPositionsForSymbol(const string symbol)
  {
   int count = 0;
   int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      count++;
     }
   return count;
  }

int CountManagedPositionsForGroup(const string group)
  {
   int count = 0;
   int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if(CurrencyGroup(PositionGetString(POSITION_SYMBOL)) == group)
         count++;
     }
   return count;
  }

double CurrentTotalOpenRiskPercent()
  {
   double risk = 0.0;
   int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      risk += PositionRiskPercent();
     }
   return risk;
  }

double CurrentSymbolOpenRiskPercent(const string symbol)
  {
   double risk = 0.0;
   int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      risk += PositionRiskPercent();
     }
   return risk;
  }

void UpdateRiskAnchors()
  {
   datetime now = TimeCurrent();
   int dayKey = DateKey(now);
   int weekKey = WeekKey(now);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(g_dayKey != dayKey)
     {
      g_dayKey = dayKey;
      g_dayStartEquity = equity;
      g_dailyStopped = false;
     }

   if(g_weekKey != weekKey)
     {
      g_weekKey = weekKey;
      g_weekStartEquity = equity;
      g_weeklyStopped = false;
     }

   if(equity > g_peakEquity)
      g_peakEquity = equity;
  }

bool IsHardRiskStopped(string &reason)
  {
   reason = "";
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(g_dayStartEquity > 0.0)
     {
      double dailyLoss = (g_dayStartEquity - equity) / g_dayStartEquity * 100.0;
      if(dailyLoss >= InpDailyMaxLossPercent)
        {
         g_dailyStopped = true;
         g_riskStopReason = "daily_loss_stop";
        }
     }

   if(g_weekStartEquity > 0.0)
     {
      double weeklyLoss = (g_weekStartEquity - equity) / g_weekStartEquity * 100.0;
      if(weeklyLoss >= InpWeeklyMaxLossPercent)
        {
         g_weeklyStopped = true;
         g_riskStopReason = "weekly_loss_stop";
        }
     }

   if(g_peakEquity > 0.0)
     {
      double drawdown = (g_peakEquity - equity) / g_peakEquity * 100.0;
      if(drawdown >= InpMaxDrawdownPercent)
        {
         g_drawdownStopped = true;
         g_riskStopReason = "max_drawdown_stop";
        }
     }

   if(g_dailyStopped || g_weeklyStopped || g_drawdownStopped)
     {
      reason = g_riskStopReason;
      return true;
     }

   return false;
  }

double RiskPenalty(const string symbol, string &reason)
  {
   double penalty = 0.0;
   string stopReason = "";
   if(IsHardRiskStopped(stopReason))
     {
      AppendReason(reason, stopReason);
      penalty += 100.0;
     }

   int openPositions = CountManagedPositions();
   if(InpMaxPositions > 0 && openPositions >= InpMaxPositions)
     {
      AppendReason(reason, "max_positions_reached");
      penalty += 60.0;
     }
   else if(openPositions > 0)
      penalty += openPositions * 4.0;

   int symbolPositions = CountManagedPositionsForSymbol(symbol);
   if(symbolPositions > 0)
     {
      AppendReason(reason, "symbol_already_open");
      penalty += 25.0;
     }

   string group = CurrencyGroup(symbol);
   int groupPositions = CountManagedPositionsForGroup(group);
   if(InpMaxSameCurrencyGroupPositions > 0 && groupPositions >= InpMaxSameCurrencyGroupPositions)
     {
      AppendReason(reason, "currency_group_limit_" + group);
      penalty += 35.0;
     }
   else if(groupPositions > 0)
      penalty += groupPositions * 6.0;

   double totalRisk = CurrentTotalOpenRiskPercent();
   if(totalRisk >= InpMaxTotalOpenRiskPercent)
     {
      AppendReason(reason, "total_open_risk_limit");
      penalty += 60.0;
     }

   double symbolRisk = CurrentSymbolOpenRiskPercent(symbol);
   if(symbolRisk >= InpMaxRiskPerSymbolPercent)
     {
      AppendReason(reason, "symbol_open_risk_limit");
      penalty += 50.0;
     }

   return penalty;
  }

double NormalizeVolume(const string symbol, const double rawVolume)
  {
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   if(minLot <= 0.0)
      minLot = InpFixedLotFallback;
   if(maxLot <= 0.0)
      maxLot = MathMax(InpMaxLotCap, minLot);
   if(step <= 0.0)
      step = minLot;

   double volume = ClampDouble(rawVolume, minLot, MathMin(maxLot, InpMaxLotCap));
   volume = MathFloor(volume / step) * step;
   if(volume < minLot)
      volume = minLot;

   int digits = 2;
   if(step < 0.1)
      digits = 3;
   if(step < 0.01)
      digits = 4;

   return NormalizeDouble(volume, digits);
  }

double CalculatePositionSize(const string symbol, const double stopDistance)
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);

   if(equity <= 0.0 || stopDistance <= 0.0 || tickSize <= 0.0 || tickValue <= 0.0)
      return NormalizeVolume(symbol, InpFixedLotFallback);

   double riskMoney = equity * InpRiskPerTradePercent / 100.0;
   double riskPerLot = stopDistance / tickSize * tickValue;
   if(riskMoney <= 0.0 || riskPerLot <= 0.0)
      return NormalizeVolume(symbol, InpFixedLotFallback);

   return NormalizeVolume(symbol, riskMoney / riskPerLot);
  }

//+------------------------------------------------------------------+
//| Score calculation                                                 |
//+------------------------------------------------------------------+
double TrendScoreForSide(const MqlRates &contextRates[],
                         const MqlRates &patternRates[],
                         const int direction,
                         string &reason)
  {
   double contextFast = AverageClose(contextRates, 1, InpFastMAPeriod);
   double contextSlow = AverageClose(contextRates, 1, InpSlowMAPeriod);
   double contextSlowPast = AverageClose(contextRates, 1 + InpSlopeLookbackBars, InpSlowMAPeriod);
   double patternFast = AverageClose(patternRates, 1, InpFastMAPeriod);
   double patternSlow = AverageClose(patternRates, 1, InpSlowMAPeriod);
   double patternSlowPast = AverageClose(patternRates, 1 + InpSlopeLookbackBars, InpSlowMAPeriod);

   double score = 0.0;
   bool contextAligned = false;
   bool patternAligned = false;

   if(direction > 0)
     {
      contextAligned = (contextFast > contextSlow && contextRates[1].close > contextSlow && contextSlow > contextSlowPast);
      patternAligned = (patternFast > patternSlow && patternRates[1].close > patternSlow && patternSlow > patternSlowPast);
     }
   else
     {
      contextAligned = (contextFast < contextSlow && contextRates[1].close < contextSlow && contextSlow < contextSlowPast);
      patternAligned = (patternFast < patternSlow && patternRates[1].close < patternSlow && patternSlow < patternSlowPast);
     }

   if(contextAligned)
      score += 18.0;
   if(patternAligned)
      score += 14.0;
   if(contextAligned && patternAligned)
      score += 3.0;

   if(score <= 0.0)
      AppendReason(reason, DirectionToString(direction) + "_trend_not_aligned");
   return score;
  }

double SetupScoreForSide(const MqlRates &patternRates[],
                         const MqlRates &executionRates[],
                         const double patternATR,
                         const int direction,
                         string &reason)
  {
   if(patternATR <= 0.0)
      return 0.0;

   double score = 0.0;
   double patternFast = AverageClose(patternRates, 1, InpFastMAPeriod);
   double body = MathAbs(patternRates[1].close - patternRates[1].open);
   double bodyATR = body / patternATR;
   double range = patternRates[1].high - patternRates[1].low;
   double closeLocation = 0.5;
   if(range > 0.0)
      closeLocation = (patternRates[1].close - patternRates[1].low) / range;

   double recentHigh = HighestHigh(patternRates, 2, InpSetupLookbackBars);
   double recentLow = LowestLow(patternRates, 2, InpSetupLookbackBars);

   if(direction > 0)
     {
      if(patternRates[1].low <= patternFast + patternATR * InpPullbackATR && patternRates[1].close > patternFast)
         score += 9.0;
      if(recentHigh > 0.0 && patternRates[1].close > recentHigh)
         score += 9.0;
      if(patternRates[1].close > patternRates[1].open && bodyATR >= InpMinMomentumBodyATR && closeLocation >= 0.62)
         score += 9.0;
      if(executionRates[1].close > executionRates[2].close && executionRates[1].close > AverageClose(executionRates, 1, InpFastMAPeriod))
         score += 8.0;
     }
   else
     {
      if(patternRates[1].high >= patternFast - patternATR * InpPullbackATR && patternRates[1].close < patternFast)
         score += 9.0;
      if(recentLow > 0.0 && patternRates[1].close < recentLow)
         score += 9.0;
      if(patternRates[1].close < patternRates[1].open && bodyATR >= InpMinMomentumBodyATR && closeLocation <= 0.38)
         score += 9.0;
      if(executionRates[1].close < executionRates[2].close && executionRates[1].close < AverageClose(executionRates, 1, InpFastMAPeriod))
         score += 8.0;
     }

   if(score < 12.0)
      AppendReason(reason, DirectionToString(direction) + "_setup_weak");
   return ClampDouble(score, 0.0, 35.0);
  }

double VolatilityScore(const double currentATR, const double averageATR, string &reason)
  {
   if(currentATR <= 0.0 || averageATR <= 0.0)
     {
      AppendReason(reason, "volatility_unavailable");
      return 0.0;
     }

   double ratio = currentATR / averageATR;
   if(ratio >= 0.80 && ratio <= 1.80)
      return 15.0;
   if(ratio >= 0.60 && ratio <= 2.20)
      return 10.0;
   if(ratio >= 0.40 && ratio <= 2.80)
      return 5.0;

   if(ratio < 0.40)
      AppendReason(reason, "volatility_too_low");
   else
      AppendReason(reason, "volatility_too_high");
   return 0.0;
  }

double CostPenalty(const string symbol, const double executionATR, double &spreadATR, string &reason)
  {
   spreadATR = 0.0;
   if(executionATR <= 0.0)
     {
      AppendReason(reason, "cost_unavailable");
      return 25.0;
     }

   spreadATR = SpreadPrice(symbol) / executionATR;
   if(spreadATR > InpMaxSpreadATR)
     {
      AppendReason(reason, "spread_atr_too_wide");
      return 18.0 + ClampDouble((spreadATR - InpMaxSpreadATR) * 80.0, 0.0, 22.0);
     }

   return ClampDouble(spreadATR / MathMax(InpMaxSpreadATR, 0.0001) * 8.0, 0.0, 8.0);
  }

void ComputeTradeLevels(SymbolScore &score, const int direction)
  {
   score.stopDistance = ClampDouble(score.atr * InpStopATRMultiplier,
                                    score.atr * InpMinSL_ATR,
                                    score.atr * InpMaxSL_ATR);
   score.volume = CalculatePositionSize(score.symbol, score.stopDistance);

   int digits = (int)SymbolInfoInteger(score.symbol, SYMBOL_DIGITS);
   double ask = SymbolInfoDouble(score.symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(score.symbol, SYMBOL_BID);
   double entry = (direction > 0 ? ask : bid);

   if(entry <= 0.0)
      return;

   if(direction > 0)
     {
      score.stopLoss = NormalizeDouble(entry - score.stopDistance, digits);
      score.takeProfit = NormalizeDouble(entry + score.stopDistance * InpRewardR, digits);
     }
   else
     {
      score.stopLoss = NormalizeDouble(entry + score.stopDistance, digits);
      score.takeProfit = NormalizeDouble(entry - score.stopDistance * InpRewardR, digits);
     }
  }

void ScoreSide(const string symbol,
               const MqlRates &contextRates[],
               const MqlRates &patternRates[],
               const MqlRates &executionRates[],
               const double patternATR,
               const double averagePatternATR,
               const double executionATR,
               const int direction,
               SymbolScore &score)
  {
   string reason = "";
   double trend = TrendScoreForSide(contextRates, patternRates, direction, reason);
   double setup = SetupScoreForSide(patternRates, executionRates, patternATR, direction, reason);
   double volatility = VolatilityScore(patternATR, averagePatternATR, reason);
   double spreadATR = 0.0;
   double cost = CostPenalty(symbol, executionATR, spreadATR, reason);
   double risk = RiskPenalty(symbol, reason);

   score.symbol = symbol;
   score.direction = DirectionToString(direction);
   score.trendScore = trend;
   score.setupScore = setup;
   score.volatilityScore = volatility;
   score.costPenalty = cost;
   score.riskPenalty = risk;
   score.totalScore = trend + setup + volatility - cost - risk;
   score.atr = patternATR;
   score.spreadATR = spreadATR;
   score.dataReady = true;
   score.reason = reason;
   ComputeTradeLevels(score, direction);
  }

void InitScore(SymbolScore &score, const string symbol)
  {
   score.symbol = symbol;
   score.direction = "NONE";
   score.totalScore = 0.0;
   score.trendScore = 0.0;
   score.setupScore = 0.0;
   score.volatilityScore = 0.0;
   score.costPenalty = 0.0;
   score.riskPenalty = 0.0;
   score.atr = 0.0;
   score.spreadATR = 0.0;
   score.stopDistance = 0.0;
   score.stopLoss = 0.0;
   score.takeProfit = 0.0;
   score.volume = 0.0;
   score.dataReady = false;
   score.reason = "";
  }

bool EvaluateSymbol(const string symbol, SymbolScore &bestScore)
  {
   InitScore(bestScore, symbol);

   MqlRates contextRates[];
   MqlRates patternRates[];
   MqlRates executionRates[];
   string reason = "";
   int barsNeeded = RequiredBars();

   if(!LoadRates(symbol, InpContextTF, barsNeeded, contextRates, reason))
     {
      bestScore.reason = reason;
      PrintFormat("%s: %s skipped: %s", STRATEGY_NAME, symbol, reason);
      return false;
     }
   if(!LoadRates(symbol, InpPatternTF, barsNeeded, patternRates, reason))
     {
      bestScore.reason = reason;
      PrintFormat("%s: %s skipped: %s", STRATEGY_NAME, symbol, reason);
      return false;
     }
   if(!LoadRates(symbol, InpExecutionTF, barsNeeded, executionRates, reason))
     {
      bestScore.reason = reason;
      PrintFormat("%s: %s skipped: %s", STRATEGY_NAME, symbol, reason);
      return false;
     }

   double patternATR = AverageATR(patternRates, 1, InpATRPeriod);
   double averagePatternATR = AverageATR(patternRates, 1, InpATRAveragePeriod);
   double executionATR = AverageATR(executionRates, 1, InpATRPeriod);
   if(patternATR <= 0.0 || averagePatternATR <= 0.0 || executionATR <= 0.0)
     {
      bestScore.reason = "atr_unavailable";
      return false;
     }

   SymbolScore longScore;
   SymbolScore shortScore;
   InitScore(longScore, symbol);
   InitScore(shortScore, symbol);

   ScoreSide(symbol, contextRates, patternRates, executionRates, patternATR, averagePatternATR, executionATR, 1, longScore);
   ScoreSide(symbol, contextRates, patternRates, executionRates, patternATR, averagePatternATR, executionATR, -1, shortScore);

   bestScore = (longScore.totalScore >= shortScore.totalScore ? longScore : shortScore);
   if(bestScore.totalScore < InpEntryScoreThreshold)
      AppendReason(bestScore.reason, "below_threshold");
   else
      AppendReason(bestScore.reason, "entry_score_ok");

   return true;
  }

//+------------------------------------------------------------------+
//| CSV logging                                                       |
//+------------------------------------------------------------------+
string DailyLogFileName()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return StringFormat("%s\\%s_%04d%02d%02d.csv",
                       InpLogFolder,
                       InpLogPrefix,
                       tm.year,
                       tm.mon,
                       tm.day);
  }

void EnsureLogFolder()
  {
   int flags = 0;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;
   FolderCreate(InpLogFolder, flags);
  }

void WriteScoreRow(const SymbolScore &score, const string reason)
  {
   EnsureLogFolder();

   int flags = FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;

   string fileName = DailyLogFileName();
   int handle = FileOpen(fileName, flags, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s: FileOpen failed: %s err=%d", STRATEGY_NAME, fileName, GetLastError());
      return;
     }

   bool needsHeader = (FileSize(handle) == 0);
   FileSeek(handle, 0, SEEK_END);
   if(needsHeader)
      FileWrite(handle,
                "time",
                "symbol",
                "direction",
                "totalScore",
                "trendScore",
                "setupScore",
                "volatilityScore",
                "costPenalty",
                "riskPenalty",
                "reason");

   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             score.symbol,
             score.direction,
             DoubleToString(score.totalScore, 2),
             DoubleToString(score.trendScore, 2),
             DoubleToString(score.setupScore, 2),
             DoubleToString(score.volatilityScore, 2),
             DoubleToString(score.costPenalty, 2),
             DoubleToString(score.riskPenalty, 2),
             reason);

   FileClose(handle);
  }

//+------------------------------------------------------------------+
//| Trading bridge                                                    |
//+------------------------------------------------------------------+
bool CanTradeCandidate(const SymbolScore &score, string &blockReason)
  {
   blockReason = "";
   if(!InpEnableTrading)
     {
      blockReason = "trading_disabled";
      return false;
     }
   if(!score.dataReady)
     {
      blockReason = "candidate_data_not_ready";
      return false;
     }
   if(score.totalScore < InpEntryScoreThreshold)
     {
      blockReason = "score_below_threshold";
      return false;
     }
   if(score.direction != "LONG" && score.direction != "SHORT")
     {
      blockReason = "direction_none";
      return false;
     }
   if(score.spreadATR > InpMaxSpreadATR)
     {
      blockReason = "spread_guard";
      return false;
     }
   if(score.stopLoss <= 0.0 || score.takeProfit <= 0.0 || score.volume <= 0.0)
     {
      blockReason = "trade_levels_invalid";
      return false;
     }

   string riskStop = "";
   if(IsHardRiskStopped(riskStop))
     {
      blockReason = riskStop;
      return false;
     }
   if(InpMaxPositions > 0 && CountManagedPositions() >= InpMaxPositions)
     {
      blockReason = "max_positions";
      return false;
     }
   if(InpMaxSameCurrencyGroupPositions > 0 &&
      CountManagedPositionsForGroup(CurrencyGroup(score.symbol)) >= InpMaxSameCurrencyGroupPositions)
     {
      blockReason = "same_currency_group_limit";
      return false;
     }
   if(CurrentSymbolOpenRiskPercent(score.symbol) + InpRiskPerTradePercent > InpMaxRiskPerSymbolPercent)
     {
      blockReason = "symbol_risk_limit";
      return false;
     }
   if(CurrentTotalOpenRiskPercent() + InpRiskPerTradePercent > InpMaxTotalOpenRiskPercent)
     {
      blockReason = "total_risk_limit";
      return false;
     }

   return true;
  }

void TryTradeBestCandidate(const SymbolScore &score)
  {
   string blockReason = "";
   if(!CanTradeCandidate(score, blockReason))
     {
      if(InpEnableTrading)
         PrintFormat("%s: trade blocked %s %s score=%.2f reason=%s",
                     STRATEGY_NAME,
                     score.symbol,
                     score.direction,
                     score.totalScore,
                     blockReason);
      return;
     }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);

   string comment = STRATEGY_NAME + "_score_" + DoubleToString(score.totalScore, 1);
   bool ok = false;
   if(score.direction == "LONG")
      ok = trade.Buy(score.volume, score.symbol, 0.0, score.stopLoss, score.takeProfit, comment);
   else if(score.direction == "SHORT")
      ok = trade.Sell(score.volume, score.symbol, 0.0, score.stopLoss, score.takeProfit, comment);

   if(!ok)
      PrintFormat("%s: order failed %s %s lot=%.2f retcode=%d",
                  STRATEGY_NAME,
                  score.symbol,
                  score.direction,
                  score.volume,
                  trade.ResultRetcode());
   else
      PrintFormat("%s: order sent %s %s lot=%.2f score=%.2f",
                  STRATEGY_NAME,
                  score.symbol,
                  score.direction,
                  score.volume,
                  score.totalScore);
  }

//+------------------------------------------------------------------+
//| Scan orchestration                                                |
//+------------------------------------------------------------------+
int FindBestCandidate(const SymbolScore &scores[])
  {
   int bestIndex = -1;
   double bestScore = -DBL_MAX;
   int size = ArraySize(scores);

   for(int i = 0; i < size; ++i)
     {
      if(!scores[i].dataReady)
         continue;
      if(scores[i].totalScore > bestScore)
        {
         bestScore = scores[i].totalScore;
         bestIndex = i;
        }
     }

   return bestIndex;
  }

void ScanAllSymbols()
  {
   UpdateRiskAnchors();

   int count = ArraySize(g_symbols);
   if(count <= 0)
      return;

   SymbolScore scores[];
   ArrayResize(scores, count);

   for(int i = 0; i < count; ++i)
      EvaluateSymbol(g_symbols[i], scores[i]);

   int bestIndex = FindBestCandidate(scores);
   for(int i = 0; i < count; ++i)
     {
      string rowReason = scores[i].reason;
      if(bestIndex == i)
         AppendReason(rowReason, "best_candidate");
      else
         AppendReason(rowReason, "not_best");
      WriteScoreRow(scores[i], rowReason);
     }

   if(bestIndex >= 0)
     {
      SymbolScore best = scores[bestIndex];
      PrintFormat("%s: best=%s %s total=%.2f trend=%.2f setup=%.2f vol=%.2f cost=%.2f risk=%.2f reason=%s",
                  STRATEGY_NAME,
                  best.symbol,
                  best.direction,
                  best.totalScore,
                  best.trendScore,
                  best.setupScore,
                  best.volatilityScore,
                  best.costPenalty,
                  best.riskPenalty,
                  best.reason);
      TryTradeBestCandidate(best);
     }
   else
      PrintFormat("%s: no data-ready symbol in scan", STRATEGY_NAME);
  }

//+------------------------------------------------------------------+
//| Expert lifecycle                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpScanSeconds <= 0 ||
      InpEntryScoreThreshold < 0.0 ||
      InpMaxPositions < 0 ||
      InpMaxSameCurrencyGroupPositions < 0 ||
      InpFastMAPeriod < 2 ||
      InpSlowMAPeriod <= InpFastMAPeriod ||
      InpATRPeriod < 2 ||
      InpATRAveragePeriod < InpATRPeriod ||
      InpSlopeLookbackBars < 1 ||
      InpSetupLookbackBars < 3 ||
      InpRiskPerTradePercent <= 0.0 ||
      InpMaxRiskPerSymbolPercent <= 0.0 ||
      InpMaxTotalOpenRiskPercent <= 0.0 ||
      InpDailyMaxLossPercent <= 0.0 ||
      InpWeeklyMaxLossPercent <= 0.0 ||
      InpMaxDrawdownPercent <= 0.0 ||
      InpMaxSpreadATR <= 0.0 ||
      InpStopATRMultiplier <= 0.0 ||
      InpMinSL_ATR <= 0.0 ||
      InpMaxSL_ATR < InpMinSL_ATR ||
      InpRewardR <= 0.0 ||
      InpFixedLotFallback <= 0.0 ||
      InpMaxLotCap <= 0.0)
     {
      PrintFormat("%s: invalid input parameter", STRATEGY_NAME);
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!ParseSymbols())
     {
      PrintFormat("%s: no valid symbols in InpSymbols", STRATEGY_NAME);
      return INIT_FAILED;
     }

   g_initialEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_peakEquity = g_initialEquity;
   g_dayStartEquity = g_initialEquity;
   g_weekStartEquity = g_initialEquity;
   g_dayKey = DateKey(TimeCurrent());
   g_weekKey = WeekKey(TimeCurrent());

   trade.SetExpertMagicNumber(InpMagicNumber);
   EventSetTimer(InpScanSeconds);
   EnsureLogFolder();

   PrintFormat("%s initialized symbols=%d trading=%s scan_seconds=%d",
               STRATEGY_NAME,
               ArraySize(g_symbols),
               (InpEnableTrading ? "true" : "false"),
               InpScanSeconds);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
  }

void OnTick()
  {
  }

void OnTimer()
  {
   ScanAllSymbols();
  }
