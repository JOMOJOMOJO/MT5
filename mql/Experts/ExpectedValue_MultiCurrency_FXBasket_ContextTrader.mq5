//+------------------------------------------------------------------+
//| ExpectedValue_MultiCurrency_FXBasket_ContextTrader               |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Backtest-only multi-currency FX basket research EA with fixed-R trade logging."

#include <Trade\Trade.mqh>

CTrade trade;

static const string STRATEGY_NAME = "ExpectedValue_MultiCurrency_FXBasket_ContextTrader";

enum ENUM_FXBASKET_STRATEGY_MODE
  {
   FXBASKET_CONTEXT_PULLBACK = 0,
   FXBASKET_VOLATILITY_BREAKOUT = 1,
   FXBASKET_RANGE_REVERSION = 2
  };

struct SignalPlan
  {
   bool              valid;
   string            symbol;
   string            direction;
   string            strategy;
   string            label;
   string            reason;
   double            entry;
   double            stopLoss;
   double            takeProfit;
   double            riskPrice;
   double            rewardR;
   double            atr;
   double            spreadPoints;
   double            score;
  };

struct TrackedTrade
  {
   bool              active;
   string            symbol;
   string            direction;
   string            strategy;
   string            label;
   long              positionId;
   datetime          entryTime;
   double            entryPrice;
   double            stopLoss;
   double            takeProfit;
   double            riskPrice;
   double            rewardR;
   double            volume;
   double            atr;
   double            spreadPoints;
   double            score;
  };

input string          InpSymbols                    = "USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD";
input ENUM_FXBASKET_STRATEGY_MODE InpStrategyMode   = FXBASKET_CONTEXT_PULLBACK;
input ENUM_TIMEFRAMES InpScanTF                     = PERIOD_M15;
input ENUM_TIMEFRAMES InpContextTF                  = PERIOD_H1;
input int             InpFastMAPeriod               = 20;
input int             InpSlowMAPeriod               = 80;
input int             InpATRPeriod                  = 14;
input int             InpRSIPeriod                  = 14;
input int             InpBreakoutLookbackBars       = 16;
input int             InpMeanLookbackBars           = 32;
input double          InpPullbackATR                = 0.45;
input double          InpMaxEntryDistanceATR        = 0.85;
input double          InpCompressionMaxRatio        = 0.85;
input double          InpRangeMaxMASeparationATR    = 0.80;
input double          InpRangeZScore                = 1.15;
input double          InpRangeRSIExtreme            = 35.0;
input double          InpStopATRMultiplier          = 1.15;
input double          InpMinSL_ATR                  = 0.60;
input double          InpMaxSL_ATR                  = 2.20;
input double          InpRewardR                    = 1.25;
input int             InpMaxHoldBars                = 18;
input double          InpRiskPerTradePercent        = 0.25;
input double          InpMaxTotalOpenRiskPercent    = 2.50;
input double          InpMaxRiskPerSymbolPercent    = 0.50;
input int             InpMaxPositions               = 6;
input double          InpDailyMaxLossPercent        = 3.00;
input double          InpMaxDrawdownPercent         = 15.00;
input double          InpMaxSpreadATR               = 0.18;
input double          InpFixedLotFallback           = 0.01;
input double          InpMaxLotCap                  = 1.00;
input int             InpSlippagePoints             = 20;
input long            InpMagicNumber                = 2026062201;
input bool            InpUseCommonFiles             = true;
input string          InpLogFolder                  = "fxbasket_context_trader";
input string          InpLogPrefix                  = "fxbasket";

string        g_symbols[];
datetime      g_lastScannedBars[];
TrackedTrade  g_trades[];
double        g_initialEquity = 0.0;
double        g_peakEquity = 0.0;
double        g_dayStartEquity = 0.0;
int           g_dayKey = 0;
bool          g_dailyStopped = false;
bool          g_drawdownStopped = false;
long          g_signalCount = 0;
long          g_orderSentCount = 0;
long          g_orderFailedCount = 0;
long          g_blockedCount = 0;
long          g_closedTradeCount = 0;

//+------------------------------------------------------------------+
//| Small utilities                                                   |
//+------------------------------------------------------------------+
string BoolText(const bool value)
  {
   return value ? "true" : "false";
  }

string DirectionText(const int direction)
  {
   if(direction > 0)
      return "LONG";
   if(direction < 0)
      return "SHORT";
   return "NONE";
  }

string StrategyModeName()
  {
   if(InpStrategyMode == FXBASKET_CONTEXT_PULLBACK)
      return "context_pullback";
   if(InpStrategyMode == FXBASKET_VOLATILITY_BREAKOUT)
      return "volatility_breakout";
   return "range_reversion";
  }

int DateKey(const datetime value)
  {
   MqlDateTime tm;
   TimeToStruct(value, tm);
   return tm.year * 10000 + tm.mon * 100 + tm.day;
  }

double ClampDouble(const double value, const double minValue, const double maxValue)
  {
   return MathMax(minValue, MathMin(maxValue, value));
  }

string CleanPart(string value)
  {
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
  }

bool ParseSymbols()
  {
   string parts[];
   int count = StringSplit(InpSymbols, ',', parts);
   ArrayResize(g_symbols, 0);
   ArrayResize(g_lastScannedBars, 0);

   for(int i = 0; i < count; ++i)
     {
      string symbol = CleanPart(parts[i]);
      if(symbol == "")
         continue;
      if(!SymbolSelect(symbol, true))
        {
         PrintFormat("%s: SymbolSelect failed for %s", STRATEGY_NAME, symbol);
         continue;
        }
      int size = ArraySize(g_symbols);
      ArrayResize(g_symbols, size + 1);
      ArrayResize(g_lastScannedBars, size + 1);
      g_symbols[size] = symbol;
      g_lastScannedBars[size] = 0;
     }

   return ArraySize(g_symbols) > 0;
  }

int LogFlags()
  {
   int flags = FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;
   return flags;
  }

void EnsureLogFolder()
  {
   int flags = 0;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;
   FolderCreate(InpLogFolder, flags);
  }

string LogFileName(const string suffix)
  {
   return InpLogFolder + "\\" + InpLogPrefix + "_" + StrategyModeName() + "_" + suffix + ".csv";
  }

void WriteSignalRow(const SignalPlan &plan, const string eventName)
  {
   EnsureLogFolder();
   int handle = FileOpen(LogFileName("signals"), LogFlags(), ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s: signal FileOpen failed err=%d", STRATEGY_NAME, GetLastError());
      return;
     }

   bool header = (FileSize(handle) == 0);
   FileSeek(handle, 0, SEEK_END);
   if(header)
      FileWrite(handle, "time", "event", "strategy", "symbol", "direction", "label", "reason",
                "entry", "stop_loss", "take_profit", "risk_price", "reward_r", "atr",
                "spread_points", "score");

   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             eventName,
             plan.strategy,
             plan.symbol,
             plan.direction,
             plan.label,
             plan.reason,
             DoubleToString(plan.entry, 8),
             DoubleToString(plan.stopLoss, 8),
             DoubleToString(plan.takeProfit, 8),
             DoubleToString(plan.riskPrice, 8),
             DoubleToString(plan.rewardR, 3),
             DoubleToString(plan.atr, 8),
             DoubleToString(plan.spreadPoints, 2),
             DoubleToString(plan.score, 3));
   FileClose(handle);
  }

void WriteTradeRow(const TrackedTrade &tracked,
                   const datetime exitTime,
                   const double exitPrice,
                   const double profit,
                   const double commission,
                   const double swap,
                   const string exitReason)
  {
   EnsureLogFolder();
   int handle = FileOpen(LogFileName("trades"), LogFlags(), ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("%s: trade FileOpen failed err=%d", STRATEGY_NAME, GetLastError());
      return;
     }

   bool header = (FileSize(handle) == 0);
   FileSeek(handle, 0, SEEK_END);
   if(header)
      FileWrite(handle, "entry_time", "exit_time", "strategy", "symbol", "direction", "label",
                "entry", "exit", "stop_loss", "take_profit", "risk_price", "result_r",
                "profit", "commission", "swap", "net_profit", "volume", "reward_r",
                "holding_bars", "atr", "spread_points", "score", "exit_reason", "position_id");

   double resultR = 0.0;
   if(tracked.riskPrice > 0.0)
     {
      if(tracked.direction == "LONG")
         resultR = (exitPrice - tracked.entryPrice) / tracked.riskPrice;
      else
         resultR = (tracked.entryPrice - exitPrice) / tracked.riskPrice;
     }

   int holdingBars = 0;
   int shift = iBarShift(tracked.symbol, InpScanTF, tracked.entryTime, false);
   if(shift >= 0)
      holdingBars = shift;

   double netProfit = profit + commission + swap;
   FileWrite(handle,
             TimeToString(tracked.entryTime, TIME_DATE | TIME_SECONDS),
             TimeToString(exitTime, TIME_DATE | TIME_SECONDS),
             tracked.strategy,
             tracked.symbol,
             tracked.direction,
             tracked.label,
             DoubleToString(tracked.entryPrice, 8),
             DoubleToString(exitPrice, 8),
             DoubleToString(tracked.stopLoss, 8),
             DoubleToString(tracked.takeProfit, 8),
             DoubleToString(tracked.riskPrice, 8),
             DoubleToString(resultR, 4),
             DoubleToString(profit, 2),
             DoubleToString(commission, 2),
             DoubleToString(swap, 2),
             DoubleToString(netProfit, 2),
             DoubleToString(tracked.volume, 3),
             DoubleToString(tracked.rewardR, 3),
             IntegerToString(holdingBars),
             DoubleToString(tracked.atr, 8),
             DoubleToString(tracked.spreadPoints, 2),
             DoubleToString(tracked.score, 3),
             exitReason,
             IntegerToString((int)tracked.positionId));
   FileClose(handle);
  }

void WriteSummaryRow()
  {
   EnsureLogFolder();
   int handle = FileOpen(LogFileName("summary"), LogFlags(), ',');
   if(handle == INVALID_HANDLE)
      return;

   bool header = (FileSize(handle) == 0);
   FileSeek(handle, 0, SEEK_END);
   if(header)
      FileWrite(handle, "time", "strategy", "symbols", "signals", "orders_sent",
                "orders_failed", "blocked", "closed_trades", "initial_equity",
                "final_equity", "peak_equity", "daily_stopped", "drawdown_stopped");

   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             StrategyModeName(),
             InpSymbols,
             IntegerToString((int)g_signalCount),
             IntegerToString((int)g_orderSentCount),
             IntegerToString((int)g_orderFailedCount),
             IntegerToString((int)g_blockedCount),
             IntegerToString((int)g_closedTradeCount),
             DoubleToString(g_initialEquity, 2),
             DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2),
             DoubleToString(g_peakEquity, 2),
             BoolText(g_dailyStopped),
             BoolText(g_drawdownStopped));
   FileClose(handle);
  }

//+------------------------------------------------------------------+
//| Market data helpers                                               |
//+------------------------------------------------------------------+
bool CopyClosedRates(const string symbol,
                     const ENUM_TIMEFRAMES tf,
                     const int bars,
                     MqlRates &rates[])
  {
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(symbol, tf, 1, bars, rates);
   return copied >= bars;
  }

double SMA(const MqlRates &rates[], const int shift, const int period)
  {
   if(period <= 0 || shift < 0 || shift + period > ArraySize(rates))
      return 0.0;
   double sum = 0.0;
   for(int i = shift; i < shift + period; ++i)
      sum += rates[i].close;
   return sum / period;
  }

double StdDevClose(const MqlRates &rates[], const int shift, const int period, const double mean)
  {
   if(period <= 1 || shift < 0 || shift + period > ArraySize(rates))
      return 0.0;
   double sum = 0.0;
   for(int i = shift; i < shift + period; ++i)
     {
      double diff = rates[i].close - mean;
      sum += diff * diff;
     }
   return MathSqrt(sum / (period - 1));
  }

double ATR(const MqlRates &rates[], const int shift, const int period)
  {
   if(period <= 0 || shift < 0 || shift + period + 1 > ArraySize(rates))
      return 0.0;
   double sum = 0.0;
   for(int i = shift; i < shift + period; ++i)
     {
      double prevClose = rates[i + 1].close;
      double tr1 = rates[i].high - rates[i].low;
      double tr2 = MathAbs(rates[i].high - prevClose);
      double tr3 = MathAbs(rates[i].low - prevClose);
      sum += MathMax(tr1, MathMax(tr2, tr3));
     }
   return sum / period;
  }

double RSI(const MqlRates &rates[], const int shift, const int period)
  {
   if(period <= 0 || shift < 0 || shift + period + 1 > ArraySize(rates))
      return 50.0;

   double gain = 0.0;
   double loss = 0.0;
   for(int i = shift; i < shift + period; ++i)
     {
      double change = rates[i].close - rates[i + 1].close;
      if(change >= 0.0)
         gain += change;
      else
         loss += -change;
     }

   if(loss <= 0.0)
      return 100.0;
   double rs = gain / loss;
   return 100.0 - (100.0 / (1.0 + rs));
  }

double HighestHigh(const MqlRates &rates[], const int shift, const int period)
  {
   if(period <= 0 || shift < 0 || shift + period > ArraySize(rates))
      return 0.0;
   double value = rates[shift].high;
   for(int i = shift + 1; i < shift + period; ++i)
      value = MathMax(value, rates[i].high);
   return value;
  }

double LowestLow(const MqlRates &rates[], const int shift, const int period)
  {
   if(period <= 0 || shift < 0 || shift + period > ArraySize(rates))
      return 0.0;
   double value = rates[shift].low;
   for(int i = shift + 1; i < shift + period; ++i)
      value = MathMin(value, rates[i].low);
   return value;
  }

bool LatestClosedBarTime(const string symbol, datetime &barTime)
  {
   MqlRates rates[];
   if(!CopyClosedRates(symbol, InpScanTF, 1, rates))
      return false;
   barTime = rates[0].time;
   return barTime > 0;
  }

//+------------------------------------------------------------------+
//| Risk and position helpers                                         |
//+------------------------------------------------------------------+
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

double PositionRiskPercent()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0)
      return 0.0;

   string symbol = PositionGetString(POSITION_SYMBOL);
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double stop = PositionGetDouble(POSITION_SL);
   double volume = PositionGetDouble(POSITION_VOLUME);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   if(stop <= 0.0 || volume <= 0.0 || tickSize <= 0.0 || tickValue <= 0.0)
      return InpRiskPerTradePercent;

   double money = MathAbs(entry - stop) / tickSize * tickValue * volume;
   return money / equity * 100.0;
  }

double CurrentTotalOpenRiskPercent()
  {
   double risk = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
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
   for(int i = PositionsTotal() - 1; i >= 0; --i)
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

int CountManagedPositions()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         ++count;
     }
   return count;
  }

bool HasManagedPosition(const string symbol)
  {
   if(!PositionSelect(symbol))
      return false;
   return (long)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber;
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

void UpdateRiskAnchors()
  {
   datetime now = TimeCurrent();
   int dayKey = DateKey(now);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(g_dayKey != dayKey)
     {
      g_dayKey = dayKey;
      g_dayStartEquity = equity;
      g_dailyStopped = false;
     }

   if(equity > g_peakEquity)
      g_peakEquity = equity;

   if(g_dayStartEquity > 0.0 && (g_dayStartEquity - equity) / g_dayStartEquity * 100.0 >= InpDailyMaxLossPercent)
      g_dailyStopped = true;
   if(g_peakEquity > 0.0 && (g_peakEquity - equity) / g_peakEquity * 100.0 >= InpMaxDrawdownPercent)
      g_drawdownStopped = true;
  }

bool HardRiskStopped()
  {
   UpdateRiskAnchors();
   return g_dailyStopped || g_drawdownStopped;
  }

//+------------------------------------------------------------------+
//| Signal builders                                                   |
//+------------------------------------------------------------------+
void ResetPlan(SignalPlan &plan, const string symbol)
  {
   plan.valid = false;
   plan.symbol = symbol;
   plan.direction = "NONE";
   plan.strategy = StrategyModeName();
   plan.label = "";
   plan.reason = "";
   plan.entry = 0.0;
   plan.stopLoss = 0.0;
   plan.takeProfit = 0.0;
   plan.riskPrice = 0.0;
   plan.rewardR = InpRewardR;
   plan.atr = 0.0;
   plan.spreadPoints = 0.0;
   plan.score = 0.0;
  }

bool FillTradeLevels(SignalPlan &plan, const int direction, const double atr)
  {
   MqlTick tick;
   if(!SymbolInfoTick(plan.symbol, tick))
     {
      plan.reason = "tick_unavailable";
      return false;
     }

   double point = SymbolInfoDouble(plan.symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(plan.symbol, SYMBOL_DIGITS);
   if(point <= 0.0 || atr <= 0.0)
     {
      plan.reason = "invalid_point_or_atr";
      return false;
     }

   plan.spreadPoints = (tick.ask - tick.bid) / point;
   double spreadATR = (tick.ask - tick.bid) / atr;
   if(spreadATR > InpMaxSpreadATR)
     {
      plan.reason = "spread_atr_guard";
      return false;
     }

   double stopDistance = ClampDouble(atr * InpStopATRMultiplier,
                                    atr * InpMinSL_ATR,
                                    atr * InpMaxSL_ATR);
   int stopsLevel = (int)SymbolInfoInteger(plan.symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stopsLevel > 0)
      stopDistance = MathMax(stopDistance, (stopsLevel + 2) * point);

   if(direction > 0)
     {
      plan.direction = "LONG";
      plan.entry = tick.ask;
      plan.stopLoss = plan.entry - stopDistance;
      plan.takeProfit = plan.entry + stopDistance * InpRewardR;
     }
   else
     {
      plan.direction = "SHORT";
      plan.entry = tick.bid;
      plan.stopLoss = plan.entry + stopDistance;
      plan.takeProfit = plan.entry - stopDistance * InpRewardR;
     }

   plan.entry = NormalizeDouble(plan.entry, digits);
   plan.stopLoss = NormalizeDouble(plan.stopLoss, digits);
   plan.takeProfit = NormalizeDouble(plan.takeProfit, digits);
   plan.riskPrice = MathAbs(plan.entry - plan.stopLoss);
   plan.atr = atr;
   return plan.riskPrice > 0.0;
  }

bool BuildContextPullbackSignal(const string symbol, SignalPlan &plan)
  {
   ResetPlan(plan, symbol);
   MqlRates context[];
   MqlRates scan[];
   int requiredContext = InpSlowMAPeriod + 12;
   int requiredScan = MathMax(InpMeanLookbackBars, InpATRPeriod) + 6;
   if(!CopyClosedRates(symbol, InpContextTF, requiredContext, context) ||
      !CopyClosedRates(symbol, InpScanTF, requiredScan, scan))
     {
      plan.reason = "data_unavailable";
      return false;
     }

   double fastNow = SMA(context, 0, InpFastMAPeriod);
   double fastPrev = SMA(context, 4, InpFastMAPeriod);
   double slowNow = SMA(context, 0, InpSlowMAPeriod);
   double atr = ATR(scan, 0, InpATRPeriod);
   double scanFast = SMA(scan, 0, InpFastMAPeriod);
   if(fastNow <= 0.0 || slowNow <= 0.0 || atr <= 0.0 || scanFast <= 0.0)
      return false;

   int direction = 0;
   bool trendUp = context[0].close > fastNow && fastNow > slowNow && fastNow > fastPrev;
   bool trendDown = context[0].close < fastNow && fastNow < slowNow && fastNow < fastPrev;

   if(trendUp)
     {
      bool pullback = scan[1].low <= scanFast + atr * InpPullbackATR;
      bool reclaim = scan[0].close > scanFast && scan[0].close > scan[0].open;
      bool notChasing = MathAbs(scan[0].close - scanFast) <= atr * InpMaxEntryDistanceATR;
      if(pullback && reclaim && notChasing)
         direction = 1;
     }
   if(direction == 0 && trendDown)
     {
      bool pullback = scan[1].high >= scanFast - atr * InpPullbackATR;
      bool reclaim = scan[0].close < scanFast && scan[0].close < scan[0].open;
      bool notChasing = MathAbs(scan[0].close - scanFast) <= atr * InpMaxEntryDistanceATR;
      if(pullback && reclaim && notChasing)
         direction = -1;
     }

   if(direction == 0)
     {
      plan.reason = "no_context_pullback";
      return false;
     }

   plan.label = "h1_trend_m15_pullback_reclaim";
   plan.score = MathAbs(fastNow - slowNow) / MathMax(ATR(context, 0, InpATRPeriod), _Point);
   return FillTradeLevels(plan, direction, atr);
  }

bool BuildVolatilityBreakoutSignal(const string symbol, SignalPlan &plan)
  {
   ResetPlan(plan, symbol);
   MqlRates context[];
   MqlRates scan[];
   int requiredContext = InpSlowMAPeriod + 12;
   int requiredScan = MathMax(InpBreakoutLookbackBars + 5, InpATRPeriod * 5 + 5);
   if(!CopyClosedRates(symbol, InpContextTF, requiredContext, context) ||
      !CopyClosedRates(symbol, InpScanTF, requiredScan, scan))
     {
      plan.reason = "data_unavailable";
      return false;
     }

   double fastNow = SMA(context, 0, InpFastMAPeriod);
   double slowNow = SMA(context, 0, InpSlowMAPeriod);
   double atr = ATR(scan, 0, InpATRPeriod);
   double atrBase = ATR(scan, InpATRPeriod * 2, InpATRPeriod * 3);
   if(fastNow <= 0.0 || slowNow <= 0.0 || atr <= 0.0 || atrBase <= 0.0)
      return false;

   bool compressed = atr / atrBase <= InpCompressionMaxRatio;
   if(!compressed)
     {
      plan.reason = "not_compressed";
      return false;
     }

   double recentHigh = HighestHigh(scan, 1, InpBreakoutLookbackBars);
   double recentLow = LowestLow(scan, 1, InpBreakoutLookbackBars);
   int direction = 0;
   if(context[0].close > fastNow && fastNow > slowNow && scan[0].close > recentHigh)
      direction = 1;
   else if(context[0].close < fastNow && fastNow < slowNow && scan[0].close < recentLow)
      direction = -1;

   if(direction == 0)
     {
      plan.reason = "no_context_breakout";
      return false;
     }

   plan.label = "h1_trend_m15_compression_breakout";
   plan.score = (recentHigh - recentLow) / MathMax(atr, _Point);
   return FillTradeLevels(plan, direction, atr);
  }

bool BuildRangeReversionSignal(const string symbol, SignalPlan &plan)
  {
   ResetPlan(plan, symbol);
   MqlRates context[];
   MqlRates scan[];
   int requiredContext = InpSlowMAPeriod + 12;
   int requiredScan = MathMax(InpMeanLookbackBars, InpRSIPeriod) + InpATRPeriod + 6;
   if(!CopyClosedRates(symbol, InpContextTF, requiredContext, context) ||
      !CopyClosedRates(symbol, InpScanTF, requiredScan, scan))
     {
      plan.reason = "data_unavailable";
      return false;
     }

   double fastNow = SMA(context, 0, InpFastMAPeriod);
   double slowNow = SMA(context, 0, InpSlowMAPeriod);
   double contextAtr = ATR(context, 0, InpATRPeriod);
   double atr = ATR(scan, 0, InpATRPeriod);
   double mean = SMA(scan, 0, InpMeanLookbackBars);
   double stdev = StdDevClose(scan, 0, InpMeanLookbackBars, mean);
   double rsi = RSI(scan, 0, InpRSIPeriod);
   if(fastNow <= 0.0 || slowNow <= 0.0 || contextAtr <= 0.0 || atr <= 0.0 || mean <= 0.0 || stdev <= 0.0)
      return false;

   bool rangeContext = MathAbs(fastNow - slowNow) <= contextAtr * InpRangeMaxMASeparationATR;
   if(!rangeContext)
     {
      plan.reason = "not_range_context";
      return false;
     }

   double z = (scan[0].close - mean) / stdev;
   int direction = 0;
   if(z <= -InpRangeZScore && rsi <= InpRangeRSIExtreme && scan[0].close > scan[0].open)
      direction = 1;
   else if(z >= InpRangeZScore && rsi >= (100.0 - InpRangeRSIExtreme) && scan[0].close < scan[0].open)
      direction = -1;

   if(direction == 0)
     {
      plan.reason = "no_range_reversion";
      return false;
     }

   plan.label = "h1_range_m15_zscore_reversion";
   plan.score = MathAbs(z);
   return FillTradeLevels(plan, direction, atr);
  }

bool BuildSignal(const string symbol, SignalPlan &plan)
  {
   if(InpStrategyMode == FXBASKET_CONTEXT_PULLBACK)
      return BuildContextPullbackSignal(symbol, plan);
   if(InpStrategyMode == FXBASKET_VOLATILITY_BREAKOUT)
      return BuildVolatilityBreakoutSignal(symbol, plan);
   return BuildRangeReversionSignal(symbol, plan);
  }

//+------------------------------------------------------------------+
//| Trading                                                           |
//+------------------------------------------------------------------+
void TrackNewPosition(const SignalPlan &plan, const double volume)
  {
   if(!PositionSelect(plan.symbol))
      return;
   if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
      return;

   int size = ArraySize(g_trades);
   ArrayResize(g_trades, size + 1);
   g_trades[size].active = true;
   g_trades[size].symbol = plan.symbol;
   g_trades[size].direction = plan.direction;
   g_trades[size].strategy = plan.strategy;
   g_trades[size].label = plan.label;
   g_trades[size].positionId = (long)PositionGetInteger(POSITION_IDENTIFIER);
   g_trades[size].entryTime = (datetime)PositionGetInteger(POSITION_TIME);
   g_trades[size].entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   g_trades[size].stopLoss = plan.stopLoss;
   g_trades[size].takeProfit = plan.takeProfit;
   g_trades[size].riskPrice = plan.riskPrice;
   g_trades[size].rewardR = plan.rewardR;
   g_trades[size].volume = volume;
   g_trades[size].atr = plan.atr;
   g_trades[size].spreadPoints = plan.spreadPoints;
   g_trades[size].score = plan.score;
  }

int FindTrackedTradeByPositionId(const long positionId)
  {
   for(int i = ArraySize(g_trades) - 1; i >= 0; --i)
     {
      if(g_trades[i].active && g_trades[i].positionId == positionId)
         return i;
     }
   return -1;
  }

bool CanOpenSignal(const SignalPlan &plan, string &blockReason)
  {
   blockReason = "";
   if(!plan.valid)
     {
      blockReason = "invalid_signal";
      return false;
     }
   if(HardRiskStopped())
     {
      blockReason = g_dailyStopped ? "daily_loss_stop" : "max_drawdown_stop";
      return false;
     }
   if(HasManagedPosition(plan.symbol))
     {
      blockReason = "symbol_already_open";
      return false;
     }
   if(InpMaxPositions > 0 && CountManagedPositions() >= InpMaxPositions)
     {
      blockReason = "max_positions";
      return false;
     }
   if(CurrentTotalOpenRiskPercent() + InpRiskPerTradePercent > InpMaxTotalOpenRiskPercent)
     {
      blockReason = "total_risk_limit";
      return false;
     }
   if(CurrentSymbolOpenRiskPercent(plan.symbol) + InpRiskPerTradePercent > InpMaxRiskPerSymbolPercent)
     {
      blockReason = "symbol_risk_limit";
      return false;
     }
   return true;
  }

void TryOpenSignal(SignalPlan &plan)
  {
   if(!plan.valid)
      return;

   ++g_signalCount;
   WriteSignalRow(plan, "signal");

   string blockReason = "";
   if(!CanOpenSignal(plan, blockReason))
     {
      ++g_blockedCount;
      plan.reason = blockReason;
      WriteSignalRow(plan, "blocked");
      return;
     }

   double volume = CalculatePositionSize(plan.symbol, plan.riskPrice);
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);

   bool ok = false;
   if(plan.direction == "LONG")
      ok = trade.Buy(volume, plan.symbol, 0.0, plan.stopLoss, plan.takeProfit, plan.strategy);
   else if(plan.direction == "SHORT")
      ok = trade.Sell(volume, plan.symbol, 0.0, plan.stopLoss, plan.takeProfit, plan.strategy);

   if(ok)
     {
      ++g_orderSentCount;
      TrackNewPosition(plan, volume);
      WriteSignalRow(plan, "order_sent");
     }
   else
     {
      ++g_orderFailedCount;
      plan.reason = "order_failed_" + IntegerToString((int)trade.ResultRetcode());
      WriteSignalRow(plan, "order_failed");
     }
  }

void ManageTimeStops()
  {
   if(InpMaxHoldBars <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      string symbol = PositionGetString(POSITION_SYMBOL);
      datetime openedAt = (datetime)PositionGetInteger(POSITION_TIME);
      int shift = iBarShift(symbol, InpScanTF, openedAt, false);
      if(shift >= InpMaxHoldBars)
         trade.PositionClose(ticket);
     }
  }

void ScanSymbols()
  {
   UpdateRiskAnchors();
   ManageTimeStops();

   for(int i = 0; i < ArraySize(g_symbols); ++i)
     {
      datetime barTime = 0;
      if(!LatestClosedBarTime(g_symbols[i], barTime))
         continue;
      if(barTime <= g_lastScannedBars[i])
         continue;
      g_lastScannedBars[i] = barTime;

      SignalPlan plan;
      if(BuildSignal(g_symbols[i], plan))
        {
         plan.valid = true;
         TryOpenSignal(plan);
        }
     }
  }

//+------------------------------------------------------------------+
//| Trade transaction logging                                         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   if(!HistoryDealSelect(trans.deal))
      return;

   long magic = (long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if(magic != InpMagicNumber)
      return;

   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT && entry != DEAL_ENTRY_OUT_BY)
      return;

   long positionId = (long)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   int trackedIndex = FindTrackedTradeByPositionId(positionId);
   if(trackedIndex < 0)
      return;

   double exitPrice = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
   double commission = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   double swap = HistoryDealGetDouble(trans.deal, DEAL_SWAP);
   datetime exitTime = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
   string exitReason = EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON));

   WriteTradeRow(g_trades[trackedIndex], exitTime, exitPrice, profit, commission, swap, exitReason);
   g_trades[trackedIndex].active = false;
   ++g_closedTradeCount;
  }

//+------------------------------------------------------------------+
//| Expert lifecycle                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpFastMAPeriod < 2 ||
      InpSlowMAPeriod <= InpFastMAPeriod ||
      InpATRPeriod < 2 ||
      InpRSIPeriod < 2 ||
      InpBreakoutLookbackBars < 3 ||
      InpMeanLookbackBars < 5 ||
      InpStopATRMultiplier <= 0.0 ||
      InpMinSL_ATR <= 0.0 ||
      InpMaxSL_ATR < InpMinSL_ATR ||
      InpRewardR <= 0.0 ||
      InpMaxHoldBars < 1 ||
      InpRiskPerTradePercent <= 0.0 ||
      InpMaxTotalOpenRiskPercent <= 0.0 ||
      InpMaxRiskPerSymbolPercent <= 0.0 ||
      InpMaxPositions < 1 ||
      InpDailyMaxLossPercent <= 0.0 ||
      InpMaxDrawdownPercent <= 0.0 ||
      InpMaxSpreadATR <= 0.0 ||
      InpFixedLotFallback <= 0.0 ||
      InpMaxLotCap <= 0.0)
     {
      PrintFormat("%s: invalid input", STRATEGY_NAME);
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!ParseSymbols())
     {
      PrintFormat("%s: no valid symbols", STRATEGY_NAME);
      return INIT_FAILED;
     }

   g_initialEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_peakEquity = g_initialEquity;
   g_dayStartEquity = g_initialEquity;
   g_dayKey = DateKey(TimeCurrent());
   trade.SetExpertMagicNumber(InpMagicNumber);
   EnsureLogFolder();

   PrintFormat("%s initialized mode=%s symbols=%d risk=%.2f reward_r=%.2f",
               STRATEGY_NAME,
               StrategyModeName(),
               ArraySize(g_symbols),
               InpRiskPerTradePercent,
               InpRewardR);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   WriteSummaryRow();
  }

void OnTick()
  {
   ScanSymbols();
  }
