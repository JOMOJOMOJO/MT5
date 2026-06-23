//+------------------------------------------------------------------+
//| ExpectedValue_MultiCurrency_FXCurrencyStrengthTrader             |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Backtest-only multi-currency FX basket EA using currency strength momentum."

#include <Trade\Trade.mqh>

CTrade trade;

static const string STRATEGY_NAME = "ExpectedValue_MultiCurrency_FXCurrencyStrengthTrader";

enum ENUM_STRENGTH_SCENARIO
  {
   STRENGTH_MOMENTUM = 0,
   STRENGTH_PULLBACK = 1,
   STRENGTH_REVERSAL_AVOID = 2,
   STRENGTH_MOMENTUM_ROOM2R = 3,
   STRENGTH_PULLBACK_ROOM2R = 4
  };

struct SignalPlan
  {
   bool              valid;
   string            symbol;
   string            direction;
   string            strategy;
   string            baseCurrency;
   string            quoteCurrency;
   double            baseStrength;
   double            quoteStrength;
   double            strengthDiff;
   int               strengthRankBase;
   int               strengthRankQuote;
   double            pairMomentumH1;
   double            pairMomentumH4;
   bool              strengthAlignment;
   bool              pairAlignment;
   string            entryType;
   double            pullbackDepthATR;
   bool              overextendedFlag;
   double            roomTo1R;
   double            roomTo2R;
   string            failureType;
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
   string            baseCurrency;
   string            quoteCurrency;
   double            baseStrength;
   double            quoteStrength;
   double            strengthDiff;
   int               strengthRankBase;
   int               strengthRankQuote;
   double            pairMomentumH1;
   double            pairMomentumH4;
   bool              strengthAlignment;
   bool              pairAlignment;
   string            entryType;
   double            pullbackDepthATR;
   bool              overextendedFlag;
   double            roomTo1R;
   double            roomTo2R;
   string            entryFailureType;
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

input string          InpSymbols                       = "USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD";
input ENUM_STRENGTH_SCENARIO InpScenarioMode           = STRENGTH_MOMENTUM;
input ENUM_TIMEFRAMES InpScanTF                        = PERIOD_M15;
input ENUM_TIMEFRAMES InpFastStrengthTF                = PERIOD_H1;
input ENUM_TIMEFRAMES InpSlowStrengthTF                = PERIOD_H4;
input int             InpATRPeriod                     = 14;
input int             InpMAPeriod                      = 24;
input int             InpH1ReturnLookbackBars          = 8;
input int             InpH4ReturnLookbackBars          = 6;
input int             InpScanFastMAPeriod              = 10;
input int             InpScanSlowMAPeriod              = 30;
input int             InpObstacleLookbackBars          = 48;
input double          InpH1ReturnWeight                = 0.75;
input double          InpH4ReturnWeight                = 0.85;
input double          InpH1SlopeWeight                 = 0.45;
input double          InpH4SlopeWeight                 = 0.55;
input double          InpMinStrengthDiff               = 0.70;
input double          InpMinPairMomentumATR            = 0.12;
input double          InpPullbackMaxDepthATR           = 0.85;
input double          InpRecoveryDistanceATR           = 0.10;
input double          InpMaxOverextendedATR            = 2.20;
input double          InpMaxH1MomentumATR              = 3.20;
input double          InpStopATRMultiplier             = 1.00;
input double          InpMinSL_ATR                     = 0.60;
input double          InpMaxSL_ATR                     = 2.50;
input double          InpRewardR                       = 1.20;
input bool            InpUseRoom1RDiagnostic           = true;
input int             InpMaxHoldBars                   = 20;
input double          InpRiskPerTradePercent           = 0.25;
input double          InpMaxTotalOpenRiskPercent       = 2.50;
input double          InpMaxRiskPerSymbolPercent       = 0.50;
input int             InpMaxPositions                  = 6;
input double          InpDailyMaxLossPercent           = 3.00;
input double          InpMaxDrawdownPercent            = 15.00;
input double          InpMaxSpreadATR                  = 0.20;
input double          InpFixedLotFallback              = 0.01;
input double          InpMaxLotCap                     = 1.00;
input int             InpSlippagePoints                = 20;
input long            InpMagicNumber                   = 2026062305;
input bool            InpUseCommonFiles                = true;
input string          InpLogFolder                     = "fx_currency_strength_trader";
input string          InpLogPrefix                     = "fxstrength";

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

static const string CURRENCIES[5] = {"USD", "JPY", "EUR", "GBP", "AUD"};

string BoolText(const bool value)
  {
   return value ? "true" : "false";
  }

string ScenarioModeName()
  {
   if(InpScenarioMode == STRENGTH_MOMENTUM)
      return "currency_strength_momentum";
   if(InpScenarioMode == STRENGTH_PULLBACK)
      return "currency_strength_pullback";
   if(InpScenarioMode == STRENGTH_REVERSAL_AVOID)
      return "currency_strength_reversal_avoid";
   if(InpScenarioMode == STRENGTH_MOMENTUM_ROOM2R)
      return "currency_strength_momentum_room_to_2r";
   return "currency_strength_pullback_room_to_2r";
  }

bool UsesPullbackEntry()
  {
   return InpScenarioMode == STRENGTH_PULLBACK || InpScenarioMode == STRENGTH_PULLBACK_ROOM2R;
  }

bool UsesOverextensionAvoid()
  {
   return InpScenarioMode == STRENGTH_REVERSAL_AVOID;
  }

bool RequiresRoomTo2R()
  {
   return InpScenarioMode == STRENGTH_MOMENTUM_ROOM2R || InpScenarioMode == STRENGTH_PULLBACK_ROOM2R;
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

int CurrencyIndex(const string currency)
  {
   for(int i = 0; i < 5; ++i)
     {
      if(CURRENCIES[i] == currency)
         return i;
     }
   return -1;
  }

string BaseCurrency(const string symbol)
  {
   return StringSubstr(symbol, 0, 3);
  }

string QuoteCurrency(const string symbol)
  {
   return StringSubstr(symbol, 3, 3);
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
      if(CurrencyIndex(BaseCurrency(symbol)) < 0 || CurrencyIndex(QuoteCurrency(symbol)) < 0)
        {
         PrintFormat("%s: unsupported currency in %s", STRATEGY_NAME, symbol);
         continue;
        }
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
   return InpLogFolder + "\\" + InpLogPrefix + "_" + ScenarioModeName() + "_" + suffix + ".csv";
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
      FileWrite(handle,
                "time", "event", "strategy", "symbol", "direction",
                "base_currency", "quote_currency", "base_strength", "quote_strength",
                "strength_diff", "strength_rank_base", "strength_rank_quote",
                "pair_momentum_h1", "pair_momentum_h4", "strength_alignment",
                "pair_alignment", "entry_type", "pullback_depth_atr",
                "overextended_flag", "room_to_1r", "room_to_2r", "failure_type",
                "reason", "entry", "stop_loss", "take_profit", "risk_price",
                "reward_r", "atr", "spread_points", "score");

   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             eventName,
             plan.strategy,
             plan.symbol,
             plan.direction,
             plan.baseCurrency,
             plan.quoteCurrency,
             DoubleToString(plan.baseStrength, 5),
             DoubleToString(plan.quoteStrength, 5),
             DoubleToString(plan.strengthDiff, 5),
             IntegerToString(plan.strengthRankBase),
             IntegerToString(plan.strengthRankQuote),
             DoubleToString(plan.pairMomentumH1, 5),
             DoubleToString(plan.pairMomentumH4, 5),
             BoolText(plan.strengthAlignment),
             BoolText(plan.pairAlignment),
             plan.entryType,
             DoubleToString(plan.pullbackDepthATR, 4),
             BoolText(plan.overextendedFlag),
             DoubleToString(plan.roomTo1R, 4),
             DoubleToString(plan.roomTo2R, 4),
             plan.failureType,
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

string ClassifyFailure(const TrackedTrade &tracked, const string exitReason, const double resultR)
  {
   if(resultR > 0.0)
      return "other";

   double currentStrengths[];
   int currentRanks[];
   if(ComputeStrengthScores(currentStrengths, currentRanks))
     {
      int baseIndex = CurrencyIndex(tracked.baseCurrency);
      int quoteIndex = CurrencyIndex(tracked.quoteCurrency);
      if(baseIndex >= 0 && quoteIndex >= 0)
        {
         double currentDiff = currentStrengths[baseIndex] - currentStrengths[quoteIndex];
         if((tracked.direction == "LONG" && currentDiff < 0.0) ||
            (tracked.direction == "SHORT" && currentDiff > 0.0))
            return "strength_reversed";
        }
     }

   if(!tracked.pairAlignment)
      return "pair_not_aligned";
   if(tracked.overextendedFlag)
      return "overextended_entry";
   if(RequiresRoomTo2R() && tracked.roomTo2R < 2.0)
      return "target_blocked";
   if(StringFind(tracked.entryType, "pullback") >= 0)
      return "pullback_failed";
   if(StringFind(exitReason, "TP") < 0)
      return "no_follow_through";
   return "other";
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
      FileWrite(handle,
                "entry_time", "exit_time", "strategy", "symbol", "direction",
                "base_currency", "quote_currency", "base_strength", "quote_strength",
                "strength_diff", "strength_rank_base", "strength_rank_quote",
                "pair_momentum_h1", "pair_momentum_h4", "strength_alignment",
                "pair_alignment", "entry_type", "pullback_depth_atr",
                "overextended_flag", "room_to_1r", "room_to_2r", "failure_type",
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

   string failureType = ClassifyFailure(tracked, exitReason, resultR);
   double netProfit = profit + commission + swap;
   FileWrite(handle,
             TimeToString(tracked.entryTime, TIME_DATE | TIME_SECONDS),
             TimeToString(exitTime, TIME_DATE | TIME_SECONDS),
             tracked.strategy,
             tracked.symbol,
             tracked.direction,
             tracked.baseCurrency,
             tracked.quoteCurrency,
             DoubleToString(tracked.baseStrength, 5),
             DoubleToString(tracked.quoteStrength, 5),
             DoubleToString(tracked.strengthDiff, 5),
             IntegerToString(tracked.strengthRankBase),
             IntegerToString(tracked.strengthRankQuote),
             DoubleToString(tracked.pairMomentumH1, 5),
             DoubleToString(tracked.pairMomentumH4, 5),
             BoolText(tracked.strengthAlignment),
             BoolText(tracked.pairAlignment),
             tracked.entryType,
             DoubleToString(tracked.pullbackDepthATR, 4),
             BoolText(tracked.overextendedFlag),
             DoubleToString(tracked.roomTo1R, 4),
             DoubleToString(tracked.roomTo2R, 4),
             failureType,
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
             ScenarioModeName(),
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

double PairMomentumScore(const string symbol,
                         double &pairMomentumH1,
                         double &pairMomentumH4)
  {
   MqlRates h1[];
   MqlRates h4[];
   int requiredH1 = MathMax(InpH1ReturnLookbackBars + InpATRPeriod + 6, InpMAPeriod + 10);
   int requiredH4 = MathMax(InpH4ReturnLookbackBars + InpATRPeriod + 6, InpMAPeriod + 10);
   if(!CopyClosedRates(symbol, InpFastStrengthTF, requiredH1, h1) ||
      !CopyClosedRates(symbol, InpSlowStrengthTF, requiredH4, h4))
     {
      pairMomentumH1 = 0.0;
      pairMomentumH4 = 0.0;
      return 0.0;
     }

   double h1Atr = ATR(h1, 0, InpATRPeriod);
   double h4Atr = ATR(h4, 0, InpATRPeriod);
   if(h1Atr <= 0.0 || h4Atr <= 0.0)
     {
      pairMomentumH1 = 0.0;
      pairMomentumH4 = 0.0;
      return 0.0;
     }

   double h1Return = (h1[0].close - h1[InpH1ReturnLookbackBars].close) / h1Atr;
   double h4Return = (h4[0].close - h4[InpH4ReturnLookbackBars].close) / h4Atr;
   double h1Slope = (SMA(h1, 0, InpMAPeriod) - SMA(h1, 4, InpMAPeriod)) / h1Atr;
   double h4Slope = (SMA(h4, 0, InpMAPeriod) - SMA(h4, 4, InpMAPeriod)) / h4Atr;

   pairMomentumH1 = h1Return + h1Slope * 0.5;
   pairMomentumH4 = h4Return + h4Slope * 0.5;

   return h1Return * InpH1ReturnWeight +
          h4Return * InpH4ReturnWeight +
          h1Slope * InpH1SlopeWeight +
          h4Slope * InpH4SlopeWeight;
  }

bool ComputeStrengthScores(double &strengths[], int &ranks[])
  {
   ArrayResize(strengths, 5);
   ArrayResize(ranks, 5);
   double counts[5] = {0, 0, 0, 0, 0};
   for(int i = 0; i < 5; ++i)
     {
      strengths[i] = 0.0;
      ranks[i] = 0;
     }

   for(int s = 0; s < ArraySize(g_symbols); ++s)
     {
      string symbol = g_symbols[s];
      int baseIndex = CurrencyIndex(BaseCurrency(symbol));
      int quoteIndex = CurrencyIndex(QuoteCurrency(symbol));
      if(baseIndex < 0 || quoteIndex < 0)
         continue;

      double h1 = 0.0;
      double h4 = 0.0;
      double score = PairMomentumScore(symbol, h1, h4);
      strengths[baseIndex] += score;
      strengths[quoteIndex] -= score;
      counts[baseIndex] += 1.0;
      counts[quoteIndex] += 1.0;
     }

   for(int i = 0; i < 5; ++i)
     {
      if(counts[i] > 0.0)
         strengths[i] /= counts[i];
     }

   for(int i = 0; i < 5; ++i)
     {
      int rank = 1;
      for(int j = 0; j < 5; ++j)
        {
         if(strengths[j] > strengths[i])
            ++rank;
        }
      ranks[i] = rank;
     }
   return true;
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

void ResetPlan(SignalPlan &plan, const string symbol)
  {
   plan.valid = false;
   plan.symbol = symbol;
   plan.direction = "NONE";
   plan.strategy = ScenarioModeName();
   plan.baseCurrency = BaseCurrency(symbol);
   plan.quoteCurrency = QuoteCurrency(symbol);
   plan.baseStrength = 0.0;
   plan.quoteStrength = 0.0;
   plan.strengthDiff = 0.0;
   plan.strengthRankBase = 0;
   plan.strengthRankQuote = 0;
   plan.pairMomentumH1 = 0.0;
   plan.pairMomentumH4 = 0.0;
   plan.strengthAlignment = false;
   plan.pairAlignment = false;
   plan.entryType = "";
   plan.pullbackDepthATR = 0.0;
   plan.overextendedFlag = false;
   plan.roomTo1R = 0.0;
   plan.roomTo2R = 0.0;
   plan.failureType = "other";
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

bool FillTradeLevels(SignalPlan &plan, const int direction, const MqlRates &scan[], const MqlRates &h1[])
  {
   MqlTick tick;
   if(!SymbolInfoTick(plan.symbol, tick))
     {
      plan.reason = "tick_unavailable";
      return false;
     }

   double point = SymbolInfoDouble(plan.symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(plan.symbol, SYMBOL_DIGITS);
   if(point <= 0.0 || plan.atr <= 0.0)
     {
      plan.reason = "invalid_point_or_atr";
      return false;
     }

   plan.spreadPoints = (tick.ask - tick.bid) / point;
   double spreadATR = (tick.ask - tick.bid) / plan.atr;
   if(spreadATR > InpMaxSpreadATR)
     {
      plan.reason = "spread_atr_guard";
      return false;
     }

   double stopDistance = ClampDouble(plan.atr * InpStopATRMultiplier,
                                     plan.atr * InpMinSL_ATR,
                                     plan.atr * InpMaxSL_ATR);
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
   if(plan.riskPrice <= 0.0)
      return false;

   double obstacleDistance = 0.0;
   if(direction > 0)
     {
      double obstacle = HighestHigh(h1, 1, InpObstacleLookbackBars);
      obstacleDistance = MathMax(0.0, obstacle - plan.entry);
     }
   else
     {
      double obstacle = LowestLow(h1, 1, InpObstacleLookbackBars);
      obstacleDistance = MathMax(0.0, plan.entry - obstacle);
     }

   plan.roomTo1R = obstacleDistance / plan.riskPrice;
   plan.roomTo2R = obstacleDistance / plan.riskPrice;
   if(RequiresRoomTo2R() && plan.roomTo2R < 2.0)
     {
      plan.reason = "target_blocked_room_to_2r";
      plan.failureType = "target_blocked";
      return false;
     }
   if(InpUseRoom1RDiagnostic && plan.roomTo1R < 1.0)
      plan.failureType = "target_blocked";

   return true;
  }

bool BuildCurrencyStrengthSignal(const string symbol,
                                 const double &strengths[],
                                 const int &ranks[],
                                 SignalPlan &plan)
  {
   ResetPlan(plan, symbol);

   MqlRates scan[];
   MqlRates h1[];
   int requiredScan = MathMax(InpScanSlowMAPeriod + 8, InpATRPeriod + 8);
   int requiredH1 = MathMax(InpObstacleLookbackBars + InpATRPeriod + 8, InpMAPeriod + 10);
   if(!CopyClosedRates(symbol, InpScanTF, requiredScan, scan) ||
      !CopyClosedRates(symbol, InpFastStrengthTF, requiredH1, h1))
     {
      plan.reason = "data_unavailable";
      return false;
     }

   int baseIndex = CurrencyIndex(plan.baseCurrency);
   int quoteIndex = CurrencyIndex(plan.quoteCurrency);
   if(baseIndex < 0 || quoteIndex < 0)
     {
      plan.reason = "unsupported_currency";
      return false;
     }

   plan.baseStrength = strengths[baseIndex];
   plan.quoteStrength = strengths[quoteIndex];
   plan.strengthDiff = plan.baseStrength - plan.quoteStrength;
   plan.strengthRankBase = ranks[baseIndex];
   plan.strengthRankQuote = ranks[quoteIndex];

   double pairScore = PairMomentumScore(symbol, plan.pairMomentumH1, plan.pairMomentumH4);
   plan.atr = ATR(scan, 0, InpATRPeriod);
   double fastNow = SMA(scan, 0, InpScanFastMAPeriod);
   double fastPrev = SMA(scan, 1, InpScanFastMAPeriod);
   double slowNow = SMA(scan, 0, InpScanSlowMAPeriod);
   if(plan.atr <= 0.0 || fastNow <= 0.0 || fastPrev <= 0.0 || slowNow <= 0.0)
     {
      plan.reason = "invalid_indicators";
      return false;
     }

   int direction = 0;
   if(plan.strengthDiff >= InpMinStrengthDiff)
      direction = 1;
   else if(plan.strengthDiff <= -InpMinStrengthDiff)
      direction = -1;
   else
     {
      plan.reason = "strength_diff_too_small";
      return false;
     }

   plan.strengthAlignment = (direction > 0 && plan.strengthRankBase < plan.strengthRankQuote) ||
                            (direction < 0 && plan.strengthRankBase > plan.strengthRankQuote);
   plan.pairAlignment = (direction > 0 && (plan.pairMomentumH1 >= InpMinPairMomentumATR || plan.pairMomentumH4 >= InpMinPairMomentumATR)) ||
                        (direction < 0 && (plan.pairMomentumH1 <= -InpMinPairMomentumATR || plan.pairMomentumH4 <= -InpMinPairMomentumATR));
   if(!plan.strengthAlignment)
     {
      plan.reason = "strength_rank_not_aligned";
      plan.failureType = "strength_reversed";
      return false;
     }
   if(!plan.pairAlignment)
     {
      plan.reason = "pair_not_aligned";
      plan.failureType = "pair_not_aligned";
      return false;
     }

   double extensionATR = MathAbs(scan[0].close - fastNow) / plan.atr;
   plan.overextendedFlag = extensionATR > InpMaxOverextendedATR || MathAbs(plan.pairMomentumH1) > InpMaxH1MomentumATR;
   if(UsesOverextensionAvoid() && plan.overextendedFlag)
     {
      plan.reason = "overextended_entry";
      plan.failureType = "overextended_entry";
      return false;
     }

   bool entryOk = false;
   if(UsesPullbackEntry())
     {
      if(direction > 0)
        {
         double pullback = MathMax(0.0, fastNow - scan[1].low) / plan.atr;
         plan.pullbackDepthATR = pullback;
         bool lightPullback = pullback <= InpPullbackMaxDepthATR;
         bool recovered = scan[0].close > fastNow + plan.atr * InpRecoveryDistanceATR && scan[0].close > scan[0].open;
         entryOk = lightPullback && recovered;
         plan.entryType = "strength_pullback_recovery";
        }
      else
        {
         double pullback = MathMax(0.0, scan[1].high - fastNow) / plan.atr;
         plan.pullbackDepthATR = pullback;
         bool lightPullback = pullback <= InpPullbackMaxDepthATR;
         bool recovered = scan[0].close < fastNow - plan.atr * InpRecoveryDistanceATR && scan[0].close < scan[0].open;
         entryOk = lightPullback && recovered;
         plan.entryType = "strength_pullback_breakdown";
        }
     }
   else
     {
      if(direction > 0)
         entryOk = scan[0].close > fastNow && fastNow >= slowNow;
      else
         entryOk = scan[0].close < fastNow && fastNow <= slowNow;
      plan.entryType = UsesOverextensionAvoid() ? "strength_momentum_reversal_avoid" : "strength_momentum";
      plan.pullbackDepthATR = extensionATR;
     }

   if(!entryOk)
     {
      plan.reason = "entry_trigger_missing";
      plan.failureType = UsesPullbackEntry() ? "pullback_failed" : "no_follow_through";
      return false;
     }

   if(!FillTradeLevels(plan, direction, scan, h1))
      return false;

   plan.score = MathAbs(plan.strengthDiff) + MathAbs(pairScore) * 0.25 + MathMax(0.0, plan.roomTo2R) * 0.10;
   return true;
  }

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
   g_trades[size].baseCurrency = plan.baseCurrency;
   g_trades[size].quoteCurrency = plan.quoteCurrency;
   g_trades[size].baseStrength = plan.baseStrength;
   g_trades[size].quoteStrength = plan.quoteStrength;
   g_trades[size].strengthDiff = plan.strengthDiff;
   g_trades[size].strengthRankBase = plan.strengthRankBase;
   g_trades[size].strengthRankQuote = plan.strengthRankQuote;
   g_trades[size].pairMomentumH1 = plan.pairMomentumH1;
   g_trades[size].pairMomentumH4 = plan.pairMomentumH4;
   g_trades[size].strengthAlignment = plan.strengthAlignment;
   g_trades[size].pairAlignment = plan.pairAlignment;
   g_trades[size].entryType = plan.entryType;
   g_trades[size].pullbackDepthATR = plan.pullbackDepthATR;
   g_trades[size].overextendedFlag = plan.overextendedFlag;
   g_trades[size].roomTo1R = plan.roomTo1R;
   g_trades[size].roomTo2R = plan.roomTo2R;
   g_trades[size].entryFailureType = plan.failureType;
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

   double strengths[];
   int ranks[];
   if(!ComputeStrengthScores(strengths, ranks))
      return;

   for(int i = 0; i < ArraySize(g_symbols); ++i)
     {
      datetime barTime = 0;
      if(!LatestClosedBarTime(g_symbols[i], barTime))
         continue;
      if(barTime <= g_lastScannedBars[i])
         continue;
      g_lastScannedBars[i] = barTime;

      SignalPlan plan;
      if(BuildCurrencyStrengthSignal(g_symbols[i], strengths, ranks, plan))
        {
         plan.valid = true;
         TryOpenSignal(plan);
        }
     }
  }

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

int OnInit()
  {
   if(InpATRPeriod < 2 ||
      InpMAPeriod < 5 ||
      InpH1ReturnLookbackBars < 2 ||
      InpH4ReturnLookbackBars < 2 ||
      InpScanFastMAPeriod < 2 ||
      InpScanSlowMAPeriod <= InpScanFastMAPeriod ||
      InpObstacleLookbackBars < 5 ||
      InpMinStrengthDiff <= 0.0 ||
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

   PrintFormat("%s initialized scenario=%s symbols=%d risk=%.2f reward_r=%.2f",
               STRATEGY_NAME,
               ScenarioModeName(),
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
