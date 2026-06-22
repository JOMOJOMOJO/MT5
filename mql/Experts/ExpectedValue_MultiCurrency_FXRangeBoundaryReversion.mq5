//+------------------------------------------------------------------+
//| ExpectedValue_MultiCurrency_FXRangeBoundaryReversion             |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Backtest-only multi-currency FX range-boundary mean reversion research EA."

#include <Trade\Trade.mqh>

CTrade trade;

static const string STRATEGY_NAME = "ExpectedValue_MultiCurrency_FXRangeBoundaryReversion";

enum ENUM_RANGE_BOUNDARY_SCENARIO
  {
   RANGE_BOUNDARY_FIXED_R = 0,
   RANGE_BOUNDARY_TO_MID = 1,
   RANGE_BOUNDARY_TO_MID_TREND_FILTER = 2,
   RANGE_BOUNDARY_TO_MID_BOUNDARY_ONLY = 3
  };

struct SignalPlan
  {
   bool              valid;
   string            symbol;
   string            direction;
   string            strategy;
   string            entryType;
   string            rangePosition;
   string            regimeType;
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
   double            zscore;
   double            rsi;
   double            rangeLow;
   double            rangeHigh;
   double            rangeMid;
   double            distanceToRangeMidR;
   double            distanceToOppositeBoundaryR;
   double            roomToMean;
   double            roomToRangeMid;
   double            roomToOppositeBoundary;
   bool              h1AdxLow;
   bool              h4AdxLow;
   bool              h1SlopeSmall;
   bool              h4SlopeSmall;
   bool              rangeWidthOk;
   bool              middleOfRange;
   bool              strongTrendBreak;
   bool              targetTooFar;
  };

struct TrackedTrade
  {
   bool              active;
   string            symbol;
   string            direction;
   string            strategy;
   string            entryType;
   string            rangePosition;
   string            regimeType;
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
   double            zscore;
   double            rsi;
   double            rangeLow;
   double            rangeHigh;
   double            rangeMid;
   double            distanceToRangeMidR;
   double            distanceToOppositeBoundaryR;
   double            roomToMean;
   double            roomToRangeMid;
   double            roomToOppositeBoundary;
   bool              h1AdxLow;
   bool              h4AdxLow;
   bool              h1SlopeSmall;
   bool              h4SlopeSmall;
   bool              rangeWidthOk;
   bool              middleOfRange;
   bool              strongTrendBreak;
   bool              targetTooFar;
  };

input string          InpSymbols                       = "USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD";
input ENUM_RANGE_BOUNDARY_SCENARIO InpScenarioMode     = RANGE_BOUNDARY_FIXED_R;
input ENUM_TIMEFRAMES InpScanTF                        = PERIOD_M15;
input ENUM_TIMEFRAMES InpRangeTF                       = PERIOD_H1;
input ENUM_TIMEFRAMES InpHigherRangeTF                 = PERIOD_H4;
input int             InpRangeLookbackBars             = 48;
input int             InpHigherRangeLookbackBars       = 24;
input int             InpATRPeriod                     = 14;
input int             InpADXPeriod                     = 14;
input int             InpMAPeriod                      = 30;
input int             InpMeanLookbackBars              = 32;
input int             InpRSIPeriod                     = 14;
input double          InpH1MaxADX                      = 24.0;
input double          InpH4MaxADX                      = 25.0;
input double          InpStrongTrendADX                = 32.0;
input double          InpH1MaxSlopeATR                 = 0.35;
input double          InpH4MaxSlopeATR                 = 0.45;
input double          InpStrictH1MaxADX                = 20.0;
input double          InpStrictH4MaxADX                = 21.0;
input double          InpStrictH1MaxSlopeATR           = 0.22;
input double          InpStrictH4MaxSlopeATR           = 0.30;
input double          InpMinRangeWidthATR              = 2.50;
input double          InpMaxRangeWidthATR              = 12.00;
input double          InpBoundaryZone                  = 0.30;
input double          InpStrictBoundaryZone            = 0.20;
input double          InpMiddleMin                     = 0.38;
input double          InpMiddleMax                     = 0.62;
input double          InpZScoreExtreme                 = 0.55;
input double          InpLowerRSI                      = 44.0;
input double          InpUpperRSI                      = 56.0;
input double          InpBreakoutBufferATR             = 0.45;
input double          InpStopBufferATR                 = 0.30;
input double          InpMinSL_ATR                     = 0.45;
input double          InpMaxSL_ATR                     = 3.20;
input double          InpRewardR                       = 1.10;
input double          InpMinRoomToMidR                 = 0.35;
input double          InpMaxTargetDistanceR            = 3.00;
input int             InpMaxHoldBars                   = 24;
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
input long            InpMagicNumber                   = 2026062301;
input bool            InpUseCommonFiles                = true;
input string          InpLogFolder                     = "fx_range_boundary_reversion";
input string          InpLogPrefix                     = "fxrange";

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

string BoolText(const bool value)
  {
   return value ? "true" : "false";
  }

string ScenarioModeName()
  {
   if(InpScenarioMode == RANGE_BOUNDARY_FIXED_R)
      return "new_range_boundary_reversion_fixedR";
   if(InpScenarioMode == RANGE_BOUNDARY_TO_MID)
      return "new_range_boundary_reversion_to_mid";
   if(InpScenarioMode == RANGE_BOUNDARY_TO_MID_TREND_FILTER)
      return "new_range_boundary_reversion_to_mid_with_trend_filter";
   return "new_range_boundary_reversion_to_mid_with_boundary_only";
  }

bool UsesMidTarget()
  {
   return InpScenarioMode != RANGE_BOUNDARY_FIXED_R;
  }

bool UsesStrictTrendFilter()
  {
   return InpScenarioMode == RANGE_BOUNDARY_TO_MID_TREND_FILTER;
  }

bool UsesStrictBoundaryOnly()
  {
   return InpScenarioMode == RANGE_BOUNDARY_TO_MID_BOUNDARY_ONLY;
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
                "time", "event", "strategy", "symbol", "direction", "entry_type",
                "range_position", "regime_type", "failure_type", "reason",
                "entry", "stop_loss", "take_profit", "risk_price", "reward_r",
                "atr", "spread_points", "score", "zscore", "rsi",
                "range_low", "range_high", "range_mid",
                "distance_to_range_mid_r", "distance_to_opposite_boundary_r",
                "room_to_mean", "room_to_range_mid", "room_to_opposite_boundary",
                "h1_adx_low", "h4_adx_low", "h1_ma_slope_small", "h4_ma_slope_small",
                "range_width_ok", "price_middle", "strong_trend_break", "target_too_far");

   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             eventName,
             plan.strategy,
             plan.symbol,
             plan.direction,
             plan.entryType,
             plan.rangePosition,
             plan.regimeType,
             plan.failureType,
             plan.reason,
             DoubleToString(plan.entry, 8),
             DoubleToString(plan.stopLoss, 8),
             DoubleToString(plan.takeProfit, 8),
             DoubleToString(plan.riskPrice, 8),
             DoubleToString(plan.rewardR, 3),
             DoubleToString(plan.atr, 8),
             DoubleToString(plan.spreadPoints, 2),
             DoubleToString(plan.score, 3),
             DoubleToString(plan.zscore, 4),
             DoubleToString(plan.rsi, 2),
             DoubleToString(plan.rangeLow, 8),
             DoubleToString(plan.rangeHigh, 8),
             DoubleToString(plan.rangeMid, 8),
             DoubleToString(plan.distanceToRangeMidR, 4),
             DoubleToString(plan.distanceToOppositeBoundaryR, 4),
             DoubleToString(plan.roomToMean, 8),
             DoubleToString(plan.roomToRangeMid, 8),
             DoubleToString(plan.roomToOppositeBoundary, 8),
             BoolText(plan.h1AdxLow),
             BoolText(plan.h4AdxLow),
             BoolText(plan.h1SlopeSmall),
             BoolText(plan.h4SlopeSmall),
             BoolText(plan.rangeWidthOk),
             BoolText(plan.middleOfRange),
             BoolText(plan.strongTrendBreak),
             BoolText(plan.targetTooFar));
   FileClose(handle);
  }

string ClassifyFailure(const TrackedTrade &tracked, const string exitReason, const double resultR)
  {
   if(tracked.rangePosition == "middle")
      return "entered_middle_of_range";
   if(resultR <= 0.0 && tracked.regimeType != "range")
      return "bad_regime";
   if(resultR <= 0.0 && tracked.targetTooFar)
      return "target_too_far";
   if(StringFind(exitReason, "SL") >= 0)
     {
      if(tracked.strongTrendBreak)
         return "trend_breakout_against_entry";
      return "stop_outside_range_hit";
     }
   if(resultR <= 0.0)
      return "no_mean_reversion";
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
                "entry_time", "exit_time", "strategy", "symbol", "direction", "entry_type",
                "range_position", "regime_type", "failure_type",
                "entry", "exit", "stop_loss", "take_profit", "risk_price", "result_r",
                "profit", "commission", "swap", "net_profit", "volume", "reward_r",
                "holding_bars", "atr", "spread_points", "score", "zscore", "rsi",
                "range_low", "range_high", "range_mid",
                "distance_to_range_mid_r", "distance_to_opposite_boundary_r",
                "room_to_mean", "room_to_range_mid", "room_to_opposite_boundary",
                "h1_adx_low", "h4_adx_low", "h1_ma_slope_small", "h4_ma_slope_small",
                "range_width_ok", "price_middle", "strong_trend_break", "target_too_far",
                "exit_reason", "position_id");

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
             tracked.entryType,
             tracked.rangePosition,
             tracked.regimeType,
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
             DoubleToString(tracked.zscore, 4),
             DoubleToString(tracked.rsi, 2),
             DoubleToString(tracked.rangeLow, 8),
             DoubleToString(tracked.rangeHigh, 8),
             DoubleToString(tracked.rangeMid, 8),
             DoubleToString(tracked.distanceToRangeMidR, 4),
             DoubleToString(tracked.distanceToOppositeBoundaryR, 4),
             DoubleToString(tracked.roomToMean, 8),
             DoubleToString(tracked.roomToRangeMid, 8),
             DoubleToString(tracked.roomToOppositeBoundary, 8),
             BoolText(tracked.h1AdxLow),
             BoolText(tracked.h4AdxLow),
             BoolText(tracked.h1SlopeSmall),
             BoolText(tracked.h4SlopeSmall),
             BoolText(tracked.rangeWidthOk),
             BoolText(tracked.middleOfRange),
             BoolText(tracked.strongTrendBreak),
             BoolText(tracked.targetTooFar),
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

double ADXProxy(const MqlRates &rates[], const int shift, const int period)
  {
   if(period <= 0 || shift < 0 || shift + period + 1 > ArraySize(rates))
      return 50.0;

   double plusDM = 0.0;
   double minusDM = 0.0;
   double trueRange = 0.0;
   for(int i = shift; i < shift + period; ++i)
     {
      double upMove = rates[i].high - rates[i + 1].high;
      double downMove = rates[i + 1].low - rates[i].low;
      if(upMove > downMove && upMove > 0.0)
         plusDM += upMove;
      if(downMove > upMove && downMove > 0.0)
         minusDM += downMove;

      double prevClose = rates[i + 1].close;
      double tr1 = rates[i].high - rates[i].low;
      double tr2 = MathAbs(rates[i].high - prevClose);
      double tr3 = MathAbs(rates[i].low - prevClose);
      trueRange += MathMax(tr1, MathMax(tr2, tr3));
     }

   if(trueRange <= 0.0)
      return 50.0;
   double plusDI = 100.0 * plusDM / trueRange;
   double minusDI = 100.0 * minusDM / trueRange;
   if(plusDI + minusDI <= 0.0)
      return 0.0;
   return 100.0 * MathAbs(plusDI - minusDI) / (plusDI + minusDI);
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
   plan.entryType = "";
   plan.rangePosition = "middle";
   plan.regimeType = "weak_trend";
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
   plan.zscore = 0.0;
   plan.rsi = 50.0;
   plan.rangeLow = 0.0;
   plan.rangeHigh = 0.0;
   plan.rangeMid = 0.0;
   plan.distanceToRangeMidR = 0.0;
   plan.distanceToOppositeBoundaryR = 0.0;
   plan.roomToMean = 0.0;
   plan.roomToRangeMid = 0.0;
   plan.roomToOppositeBoundary = 0.0;
   plan.h1AdxLow = false;
   plan.h4AdxLow = false;
   plan.h1SlopeSmall = false;
   plan.h4SlopeSmall = false;
   plan.rangeWidthOk = false;
   plan.middleOfRange = true;
   plan.strongTrendBreak = false;
   plan.targetTooFar = false;
  }

string DetermineRangePosition(const double position)
  {
   double zone = UsesStrictBoundaryOnly() ? InpStrictBoundaryZone : InpBoundaryZone;
   if(position <= zone)
      return "lower_boundary";
   if(position >= 1.0 - zone)
      return "upper_boundary";
   return "middle";
  }

bool FillTradeLevels(SignalPlan &plan, const int direction, const double m15Mean)
  {
   MqlTick tick;
   if(!SymbolInfoTick(plan.symbol, tick))
     {
      plan.reason = "tick_unavailable";
      return false;
     }

   double point = SymbolInfoDouble(plan.symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(plan.symbol, SYMBOL_DIGITS);
   if(point <= 0.0 || plan.atr <= 0.0 || plan.rangeHigh <= plan.rangeLow)
     {
      plan.reason = "invalid_levels";
      return false;
     }

   plan.spreadPoints = (tick.ask - tick.bid) / point;
   double spreadATR = (tick.ask - tick.bid) / plan.atr;
   if(spreadATR > InpMaxSpreadATR)
     {
      plan.reason = "spread_atr_guard";
      return false;
     }

   int stopsLevel = (int)SymbolInfoInteger(plan.symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minBrokerDistance = (stopsLevel + 2) * point;
   double minStopDistance = MathMax(plan.atr * InpMinSL_ATR, minBrokerDistance);
   double maxStopDistance = plan.atr * InpMaxSL_ATR;
   double stopBuffer = MathMax(plan.atr * InpStopBufferATR, minBrokerDistance);

   if(direction > 0)
     {
      plan.direction = "LONG";
      plan.entryType = "lower_boundary_reversion";
      plan.entry = tick.ask;
      plan.stopLoss = plan.rangeLow - stopBuffer;
      if(plan.entry - plan.stopLoss < minStopDistance)
         plan.stopLoss = plan.entry - minStopDistance;
      if(plan.entry - plan.stopLoss > maxStopDistance)
         plan.stopLoss = plan.entry - maxStopDistance;
     }
   else
     {
      plan.direction = "SHORT";
      plan.entryType = "upper_boundary_reversion";
      plan.entry = tick.bid;
      plan.stopLoss = plan.rangeHigh + stopBuffer;
      if(plan.stopLoss - plan.entry < minStopDistance)
         plan.stopLoss = plan.entry + minStopDistance;
      if(plan.stopLoss - plan.entry > maxStopDistance)
         plan.stopLoss = plan.entry + maxStopDistance;
     }

   plan.riskPrice = MathAbs(plan.entry - plan.stopLoss);
   if(plan.riskPrice <= 0.0)
     {
      plan.reason = "invalid_risk";
      return false;
     }

   if(direction > 0)
     {
      plan.roomToMean = MathMax(0.0, m15Mean - plan.entry);
      plan.roomToRangeMid = MathMax(0.0, plan.rangeMid - plan.entry);
      plan.roomToOppositeBoundary = MathMax(0.0, plan.rangeHigh - plan.entry);
      plan.distanceToRangeMidR = plan.roomToRangeMid / plan.riskPrice;
      plan.distanceToOppositeBoundaryR = plan.roomToOppositeBoundary / plan.riskPrice;
      if(UsesMidTarget())
         plan.takeProfit = plan.rangeMid;
      else
         plan.takeProfit = plan.entry + plan.riskPrice * InpRewardR;
     }
   else
     {
      plan.roomToMean = MathMax(0.0, plan.entry - m15Mean);
      plan.roomToRangeMid = MathMax(0.0, plan.entry - plan.rangeMid);
      plan.roomToOppositeBoundary = MathMax(0.0, plan.entry - plan.rangeLow);
      plan.distanceToRangeMidR = plan.roomToRangeMid / plan.riskPrice;
      plan.distanceToOppositeBoundaryR = plan.roomToOppositeBoundary / plan.riskPrice;
      if(UsesMidTarget())
         plan.takeProfit = plan.rangeMid;
      else
         plan.takeProfit = plan.entry - plan.riskPrice * InpRewardR;
     }

   if(UsesMidTarget())
     {
      if(plan.distanceToRangeMidR < InpMinRoomToMidR)
        {
         plan.reason = "mid_target_too_close";
         return false;
        }
      if(plan.distanceToRangeMidR > InpMaxTargetDistanceR)
         plan.targetTooFar = true;
     }
   else
     {
      plan.targetTooFar = InpRewardR > InpMaxTargetDistanceR;
     }

   if(MathAbs(plan.takeProfit - plan.entry) < minBrokerDistance)
     {
      plan.reason = "target_inside_stop_level";
      return false;
     }

   plan.entry = NormalizeDouble(plan.entry, digits);
   plan.stopLoss = NormalizeDouble(plan.stopLoss, digits);
   plan.takeProfit = NormalizeDouble(plan.takeProfit, digits);
   plan.riskPrice = MathAbs(plan.entry - plan.stopLoss);
   plan.rewardR = MathAbs(plan.takeProfit - plan.entry) / MathMax(plan.riskPrice, point);
   return plan.riskPrice > 0.0;
  }

bool BuildRangeBoundarySignal(const string symbol, SignalPlan &plan)
  {
   ResetPlan(plan, symbol);

   MqlRates scan[];
   MqlRates h1[];
   MqlRates h4[];
   int requiredScan = MathMax(InpMeanLookbackBars, InpRSIPeriod) + InpATRPeriod + 8;
   int requiredH1 = MathMax(InpRangeLookbackBars + InpATRPeriod + 8, InpMAPeriod + 10);
   int requiredH4 = MathMax(InpHigherRangeLookbackBars + InpATRPeriod + 8, InpMAPeriod + 10);

   if(!CopyClosedRates(symbol, InpScanTF, requiredScan, scan) ||
      !CopyClosedRates(symbol, InpRangeTF, requiredH1, h1) ||
      !CopyClosedRates(symbol, InpHigherRangeTF, requiredH4, h4))
     {
      plan.reason = "data_unavailable";
      return false;
     }

   double h1Atr = ATR(h1, 0, InpATRPeriod);
   double h4Atr = ATR(h4, 0, InpATRPeriod);
   double scanAtr = ATR(scan, 0, InpATRPeriod);
   double h1Adx = ADXProxy(h1, 0, InpADXPeriod);
   double h4Adx = ADXProxy(h4, 0, InpADXPeriod);
   double h1MaNow = SMA(h1, 0, InpMAPeriod);
   double h1MaPrev = SMA(h1, 4, InpMAPeriod);
   double h4MaNow = SMA(h4, 0, InpMAPeriod);
   double h4MaPrev = SMA(h4, 4, InpMAPeriod);
   double mean = SMA(scan, 0, InpMeanLookbackBars);
   double stdev = StdDevClose(scan, 0, InpMeanLookbackBars, mean);
   plan.rsi = RSI(scan, 0, InpRSIPeriod);

   if(h1Atr <= 0.0 || h4Atr <= 0.0 || scanAtr <= 0.0 ||
      h1MaNow <= 0.0 || h1MaPrev <= 0.0 || h4MaNow <= 0.0 || h4MaPrev <= 0.0 ||
      mean <= 0.0 || stdev <= 0.0)
     {
      plan.reason = "invalid_indicators";
      return false;
     }

   plan.atr = scanAtr;
   plan.rangeHigh = HighestHigh(h1, 0, InpRangeLookbackBars);
   plan.rangeLow = LowestLow(h1, 0, InpRangeLookbackBars);
   if(plan.rangeHigh <= plan.rangeLow)
     {
      plan.reason = "invalid_range";
      return false;
     }
   plan.rangeMid = (plan.rangeHigh + plan.rangeLow) * 0.5;

   double h1SlopeATR = MathAbs(h1MaNow - h1MaPrev) / h1Atr;
   double h4SlopeATR = MathAbs(h4MaNow - h4MaPrev) / h4Atr;
   double strictH1Adx = UsesStrictTrendFilter() ? InpStrictH1MaxADX : InpH1MaxADX;
   double strictH4Adx = UsesStrictTrendFilter() ? InpStrictH4MaxADX : InpH4MaxADX;
   double strictH1Slope = UsesStrictTrendFilter() ? InpStrictH1MaxSlopeATR : InpH1MaxSlopeATR;
   double strictH4Slope = UsesStrictTrendFilter() ? InpStrictH4MaxSlopeATR : InpH4MaxSlopeATR;

   plan.h1AdxLow = h1Adx <= strictH1Adx;
   plan.h4AdxLow = h4Adx <= strictH4Adx;
   plan.h1SlopeSmall = h1SlopeATR <= strictH1Slope;
   plan.h4SlopeSmall = h4SlopeATR <= strictH4Slope;
   double rangeWidthATR = (plan.rangeHigh - plan.rangeLow) / h1Atr;
   plan.rangeWidthOk = rangeWidthATR >= InpMinRangeWidthATR && rangeWidthATR <= InpMaxRangeWidthATR;

   double prevHigh = HighestHigh(h1, 1, InpRangeLookbackBars);
   double prevLow = LowestLow(h1, 1, InpRangeLookbackBars);
   bool breakoutUp = h1[0].close > prevHigh + h1Atr * InpBreakoutBufferATR;
   bool breakoutDown = h1[0].close < prevLow - h1Atr * InpBreakoutBufferATR;
   plan.strongTrendBreak = breakoutUp || breakoutDown || h1Adx >= InpStrongTrendADX || h4Adx >= InpStrongTrendADX;

   bool h1RangeState = plan.h1AdxLow && plan.h1SlopeSmall;
   bool h4RangeState = plan.h4AdxLow && plan.h4SlopeSmall;
   if(plan.strongTrendBreak)
      plan.regimeType = "strong_trend";
   else if(h1RangeState || h4RangeState)
      plan.regimeType = "range";
   else
      plan.regimeType = "weak_trend";

   if(!plan.rangeWidthOk)
     {
      plan.reason = "range_width_not_ok";
      plan.failureType = "bad_regime";
      return false;
     }
   if(plan.regimeType == "strong_trend")
     {
      plan.reason = "strong_trend_regime";
      plan.failureType = "bad_regime";
      return false;
     }
   if(UsesStrictTrendFilter() && plan.regimeType != "range")
     {
      plan.reason = "strict_trend_filter";
      plan.failureType = "bad_regime";
      return false;
     }

   double close = scan[0].close;
   double rangePositionValue = (close - plan.rangeLow) / (plan.rangeHigh - plan.rangeLow);
   plan.rangePosition = DetermineRangePosition(rangePositionValue);
   plan.middleOfRange = rangePositionValue >= InpMiddleMin && rangePositionValue <= InpMiddleMax;
   if(plan.rangePosition == "middle")
     {
      plan.reason = "entered_middle_of_range_guard";
      plan.failureType = "entered_middle_of_range";
      return false;
     }

   plan.zscore = (close - mean) / stdev;
   bool longOversold = plan.zscore <= -InpZScoreExtreme || plan.rsi <= InpLowerRSI;
   bool shortOverbought = plan.zscore >= InpZScoreExtreme || plan.rsi >= InpUpperRSI;
   bool longReversal = scan[0].close > scan[0].open;
   bool shortReversal = scan[0].close < scan[0].open;

   int direction = 0;
   if(plan.rangePosition == "lower_boundary" && longOversold && longReversal)
      direction = 1;
   else if(plan.rangePosition == "upper_boundary" && shortOverbought && shortReversal)
      direction = -1;

   if(direction == 0)
     {
      plan.reason = "no_boundary_reversal";
      plan.failureType = "other";
      return false;
     }

   plan.failureType = "other";
   int diagnosticScore = 0;
   if(plan.h1AdxLow)
      ++diagnosticScore;
   if(plan.h4AdxLow)
      ++diagnosticScore;
   if(plan.h1SlopeSmall)
      ++diagnosticScore;
   if(plan.h4SlopeSmall)
      ++diagnosticScore;
   if(plan.rangeWidthOk)
      ++diagnosticScore;
   if(plan.regimeType == "range")
      diagnosticScore += 2;
   plan.score = diagnosticScore + MathAbs(plan.zscore);

   if(!FillTradeLevels(plan, direction, mean))
      return false;

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
   g_trades[size].entryType = plan.entryType;
   g_trades[size].rangePosition = plan.rangePosition;
   g_trades[size].regimeType = plan.regimeType;
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
   g_trades[size].zscore = plan.zscore;
   g_trades[size].rsi = plan.rsi;
   g_trades[size].rangeLow = plan.rangeLow;
   g_trades[size].rangeHigh = plan.rangeHigh;
   g_trades[size].rangeMid = plan.rangeMid;
   g_trades[size].distanceToRangeMidR = plan.distanceToRangeMidR;
   g_trades[size].distanceToOppositeBoundaryR = plan.distanceToOppositeBoundaryR;
   g_trades[size].roomToMean = plan.roomToMean;
   g_trades[size].roomToRangeMid = plan.roomToRangeMid;
   g_trades[size].roomToOppositeBoundary = plan.roomToOppositeBoundary;
   g_trades[size].h1AdxLow = plan.h1AdxLow;
   g_trades[size].h4AdxLow = plan.h4AdxLow;
   g_trades[size].h1SlopeSmall = plan.h1SlopeSmall;
   g_trades[size].h4SlopeSmall = plan.h4SlopeSmall;
   g_trades[size].rangeWidthOk = plan.rangeWidthOk;
   g_trades[size].middleOfRange = plan.middleOfRange;
   g_trades[size].strongTrendBreak = plan.strongTrendBreak;
   g_trades[size].targetTooFar = plan.targetTooFar;
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
      if(BuildRangeBoundarySignal(g_symbols[i], plan))
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
   if(InpRangeLookbackBars < 8 ||
      InpHigherRangeLookbackBars < 6 ||
      InpATRPeriod < 2 ||
      InpADXPeriod < 2 ||
      InpMAPeriod < 5 ||
      InpMeanLookbackBars < 5 ||
      InpRSIPeriod < 2 ||
      InpBoundaryZone <= 0.0 ||
      InpBoundaryZone >= 0.5 ||
      InpStrictBoundaryZone <= 0.0 ||
      InpStrictBoundaryZone >= InpBoundaryZone ||
      InpMiddleMin <= 0.0 ||
      InpMiddleMax >= 1.0 ||
      InpMiddleMin >= InpMiddleMax ||
      InpStopBufferATR <= 0.0 ||
      InpMinSL_ATR <= 0.0 ||
      InpMaxSL_ATR < InpMinSL_ATR ||
      InpRewardR <= 0.0 ||
      InpMinRoomToMidR < 0.0 ||
      InpMaxTargetDistanceR <= 0.0 ||
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
