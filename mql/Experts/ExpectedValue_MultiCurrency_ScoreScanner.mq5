//+------------------------------------------------------------------+
//| ExpectedValue_MultiCurrency_ScoreScanner                         |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Multi-currency score scanner. Initial mode logs scores and candidate reasons without trading by default."

#include <Trade\Trade.mqh>

CTrade trade;

static const string STRATEGY_NAME = "ExpectedValue_MultiCurrency_ScoreScanner";

enum ENUM_TRADE_DIRECTION_MODE
  {
   TRADE_DIRECTION_BOTH = 0,
   TRADE_DIRECTION_LONG_ONLY = 1,
   TRADE_DIRECTION_SHORT_ONLY = 2
  };

enum ENUM_SYMBOL_RESEARCH_MODE
  {
   SYMBOL_RESEARCH_ALL = 0,
   SYMBOL_RESEARCH_XAUUSD_ONLY = 1,
   SYMBOL_RESEARCH_FX_ONLY = 2
  };

enum ENUM_RESEARCH_STRATEGY_MODE
  {
   RESEARCH_STRATEGY_SCORE_SCANNER = 0,
   RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE = 1
  };

input string          InpSymbols                       = "USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD,XAUUSD";
input int             InpScanSeconds                   = 300;
input bool            InpScanOnlyOnNewExecutionBar     = true;
input double          InpEntryScoreThreshold           = 60.0;
input ENUM_TIMEFRAMES InpContextTF                     = PERIOD_H1;
input ENUM_TIMEFRAMES InpPatternTF                     = PERIOD_M15;
input ENUM_TIMEFRAMES InpExecutionTF                   = PERIOD_M5;
input ENUM_RESEARCH_STRATEGY_MODE InpResearchStrategyMode = RESEARCH_STRATEGY_SCORE_SCANNER;
input ENUM_TRADE_DIRECTION_MODE InpTradeDirectionMode  = TRADE_DIRECTION_BOTH;
input bool            InpDisableUsdJpyShort            = false;
input ENUM_SYMBOL_RESEARCH_MODE InpSymbolResearchMode  = SYMBOL_RESEARCH_ALL;
input bool            InpUseDowFractalStructureFilter  = false;
input int             InpStructureSwingSpan            = 2;
input int             InpStructureScanBars             = 80;
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

struct PivotPoint
  {
   bool              valid;
   int               shift;
   double            price;
   datetime          time;
  };

struct StructureFilterState
  {
   bool              trendUp;
   bool              trendDown;
   bool              higherHigh;
   bool              higherLow;
   bool              lowerHigh;
   bool              lowerLow;
   bool              pullbackValid;
   bool              pullbackTooDeep;
   bool              fractalConfirmed;
   bool              reclaimConfirmed;
   bool              pass;
   double            structureStopReference;
   string            failReason;
  };

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
   bool              structureEvaluated;
   StructureFilterState structureState;
   string            reason;
  };

struct ThirdWaveSetup
  {
   string            symbol;
   string            direction;
   string            higherTfTrend;
   string            midTfPullbackStatus;
   string            lowerTfReversalStatus;
   string            skipReason;
   string            structureSlSource;
   bool              dataReady;
   bool              setupPass;
   bool              entryPass;
   double            entryPrice;
   double            stopLoss;
   double            takeProfit;
   double            volume;
   double            riskR;
   double            rr;
   double            swingHigh;
   double            swingLow;
   double            atr;
   double            spreadATR;
   double            retraceRatio;
   double            qualityScore;
  };

void WriteStructureFilterRow(const string symbol, const string direction, const StructureFilterState &state);
void WriteStructureSummaryRow();
void WriteThirdWaveSummaryRow();

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
datetime g_lastScanExecutionBarTime = 0;
datetime g_lastLoggedSkippedExecutionBarTime = 0;
long     g_structureEvaluations = 0;
long     g_structureDetailRows = 0;
long     g_structurePassCount = 0;
long     g_structureFailCount = 0;
long     g_structureNoContextSwingsCount = 0;
long     g_structureNoTrendUpCount = 0;
long     g_structureNoTrendDownCount = 0;
long     g_structurePullbackTooDeepCount = 0;
long     g_structurePullbackNotValidCount = 0;
long     g_structureNoFractalLowCount = 0;
long     g_structureNoFractalHighCount = 0;
long     g_structureNoReclaimCount = 0;
long     g_structureUnknownFailCount = 0;
long     g_thirdWaveEvaluations = 0;
long     g_thirdWaveLongEvaluations = 0;
long     g_thirdWaveShortEvaluations = 0;
long     g_thirdWaveSetupPassCount = 0;
long     g_thirdWaveEntryPassCount = 0;
long     g_thirdWaveOrderSentCount = 0;
long     g_thirdWaveOrderFailedCount = 0;
long     g_thirdWaveNoHigherTrendCount = 0;
long     g_thirdWaveTrendBrokenCount = 0;
long     g_thirdWaveNoMidPullbackCount = 0;
long     g_thirdWavePullbackTooShallowCount = 0;
long     g_thirdWavePullbackTooDeepCount = 0;
long     g_thirdWaveNoLowerReversalCount = 0;
long     g_thirdWaveSlTooCloseCount = 0;
long     g_thirdWaveSlTooWideCount = 0;
long     g_thirdWaveRrTooLowCount = 0;
long     g_thirdWaveExistingPositionCount = 0;
long     g_thirdWaveMarketClosedCount = 0;
long     g_thirdWaveSpreadGuardCount = 0;
long     g_thirdWaveDataUnavailableCount = 0;
long     g_thirdWaveAtrUnavailableCount = 0;
long     g_thirdWaveResearchExcludedCount = 0;
long     g_thirdWaveUnknownSkipCount = 0;

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

string UpperSymbol(const string symbol)
  {
   string upper = symbol;
   StringToUpper(upper);
   return upper;
  }

bool IsXauSymbol(const string symbol)
  {
   return (StringFind(UpperSymbol(symbol), "XAU") >= 0);
  }

bool IsUsdJpySymbol(const string symbol)
  {
   return (StringFind(UpperSymbol(symbol), "USDJPY") == 0);
  }

string BoolText(const bool value)
  {
   return (value ? "true" : "false");
  }

string DateTimeText(const datetime value)
  {
   if(value <= 0)
      return "";
   return TimeToString(value, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
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

bool IsSymbolAllowedByResearchMode(const string symbol, string &reason)
  {
   reason = "";
   if(InpSymbolResearchMode == SYMBOL_RESEARCH_XAUUSD_ONLY && !IsXauSymbol(symbol))
     {
      reason = "symbol_research_xauusd_only_excluded";
      return false;
     }

   if(InpSymbolResearchMode == SYMBOL_RESEARCH_FX_ONLY && IsXauSymbol(symbol))
     {
      reason = "symbol_research_fx_only_excluded";
      return false;
     }

   return true;
  }

bool IsDirectionAllowedByResearchMode(const string symbol, const int direction, string &reason)
  {
   reason = "";
   if(direction > 0 && InpTradeDirectionMode == TRADE_DIRECTION_SHORT_ONLY)
     {
      reason = "direction_mode_short_only";
      return false;
     }

   if(direction < 0 && InpTradeDirectionMode == TRADE_DIRECTION_LONG_ONLY)
     {
      reason = "direction_mode_long_only";
      return false;
     }

   if(direction < 0 && InpDisableUsdJpyShort && IsUsdJpySymbol(symbol))
     {
      reason = "disabled_usdjpy_short";
      return false;
     }

   return true;
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
   need = MathMax(need, InpStructureScanBars + InpStructureSwingSpan * 2 + 10);
   return MathMax(need, 90);
  }

void ResetPivot(PivotPoint &pivot)
  {
   pivot.valid = false;
   pivot.shift = -1;
   pivot.price = 0.0;
   pivot.time = 0;
  }

void SetPivot(PivotPoint &pivot, const int shift, const double price, const datetime time)
  {
   pivot.valid = true;
   pivot.shift = shift;
   pivot.price = price;
   pivot.time = time;
  }

bool IsPivotHigh(const MqlRates &rates[], const int shift, const int span)
  {
   int size = ArraySize(rates);
   if(span < 1 || shift - span < 1 || shift + span >= size)
      return false;

   double price = rates[shift].high;
   for(int offset = 1; offset <= span; ++offset)
     {
      if(rates[shift - offset].high >= price)
         return false;
      if(rates[shift + offset].high >= price)
         return false;
     }
   return true;
  }

bool IsPivotLow(const MqlRates &rates[], const int shift, const int span)
  {
   int size = ArraySize(rates);
   if(span < 1 || shift - span < 1 || shift + span >= size)
      return false;

   double price = rates[shift].low;
   for(int offset = 1; offset <= span; ++offset)
     {
      if(rates[shift - offset].low <= price)
         return false;
      if(rates[shift + offset].low <= price)
         return false;
     }
   return true;
  }

bool FindRecentPivots(const MqlRates &rates[],
                      const bool highPivot,
                      const int span,
                      const int scanBars,
                      PivotPoint &latest,
                      PivotPoint &previous)
  {
   ResetPivot(latest);
   ResetPivot(previous);

   int size = ArraySize(rates);
   int maxShift = size - span - 1;
   if(maxShift > scanBars)
      maxShift = scanBars;
   for(int shift = span + 1; shift <= maxShift; ++shift)
     {
      bool found = (highPivot ? IsPivotHigh(rates, shift, span) : IsPivotLow(rates, shift, span));
      if(!found)
         continue;

      if(!latest.valid)
        {
         SetPivot(latest, shift, (highPivot ? rates[shift].high : rates[shift].low), rates[shift].time);
         continue;
        }

      SetPivot(previous, shift, (highPivot ? rates[shift].high : rates[shift].low), rates[shift].time);
      return true;
     }

   return (latest.valid && previous.valid);
  }

void ResetStructureFilterState(StructureFilterState &state)
  {
   state.trendUp = false;
   state.trendDown = false;
   state.higherHigh = false;
   state.higherLow = false;
   state.lowerHigh = false;
   state.lowerLow = false;
   state.pullbackValid = false;
   state.pullbackTooDeep = false;
   state.fractalConfirmed = false;
   state.reclaimConfirmed = false;
   state.pass = false;
   state.structureStopReference = 0.0;
   state.failReason = "";
  }

void InitThirdWaveSetup(ThirdWaveSetup &setup, const string symbol, const int direction)
  {
   setup.symbol = symbol;
   setup.direction = DirectionToString(direction);
   setup.higherTfTrend = "none";
   setup.midTfPullbackStatus = "not_checked";
   setup.lowerTfReversalStatus = "not_checked";
   setup.skipReason = "";
   setup.structureSlSource = "";
   setup.dataReady = false;
   setup.setupPass = false;
   setup.entryPass = false;
   setup.entryPrice = 0.0;
   setup.stopLoss = 0.0;
   setup.takeProfit = 0.0;
   setup.volume = 0.0;
   setup.riskR = 0.0;
   setup.rr = 0.0;
   setup.swingHigh = 0.0;
   setup.swingLow = 0.0;
   setup.atr = 0.0;
   setup.spreadATR = 0.0;
   setup.retraceRatio = 0.0;
   setup.qualityScore = 0.0;
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
//| Dow/fractal third wave research branch                           |
//+------------------------------------------------------------------+
bool DetectHigherTimeframeDowTrend(const MqlRates &contextRates[],
                                    const int direction,
                                    ThirdWaveSetup &setup)
  {
   int span = InpStructureSwingSpan;
   if(span < 1)
      span = 1;

   int scanBars = InpStructureScanBars;
   if(scanBars < span * 4 + 10)
      scanBars = span * 4 + 10;

   PivotPoint highLatest;
   PivotPoint highPrevious;
   PivotPoint lowLatest;
   PivotPoint lowPrevious;
   bool hasHighs = FindRecentPivots(contextRates, true, span, scanBars, highLatest, highPrevious);
   bool hasLows = FindRecentPivots(contextRates, false, span, scanBars, lowLatest, lowPrevious);

   if(!hasHighs || !hasLows)
     {
      setup.skipReason = "no_higher_tf_trend";
      setup.higherTfTrend = "none";
      return false;
     }

   bool higherHigh = (highLatest.price > highPrevious.price);
   bool higherLow = (lowLatest.price > lowPrevious.price);
   bool lowerHigh = (highLatest.price < highPrevious.price);
   bool lowerLow = (lowLatest.price < lowPrevious.price);

   setup.swingHigh = highLatest.price;
   setup.swingLow = lowLatest.price;

   if(direction > 0)
     {
      setup.higherTfTrend = (higherHigh && higherLow ? "up" : "none");
      if(!(higherHigh && higherLow))
        {
         setup.skipReason = "no_higher_tf_trend";
         return false;
        }
      if(contextRates[1].close <= lowLatest.price)
        {
         setup.skipReason = "trend_broken";
         return false;
        }
      return true;
     }

   setup.higherTfTrend = (lowerHigh && lowerLow ? "down" : "none");
   if(!(lowerHigh && lowerLow))
     {
      setup.skipReason = "no_higher_tf_trend";
      return false;
     }
   if(contextRates[1].close >= highLatest.price)
     {
      setup.skipReason = "trend_broken";
      return false;
     }
   return true;
  }

bool DetectMidTimeframePullback(const MqlRates &patternRates[],
                                const int direction,
                                ThirdWaveSetup &setup)
  {
   int span = InpStructureSwingSpan;
   if(span < 1)
      span = 1;

   int scanBars = InpStructureScanBars;
   if(scanBars < span * 4 + 10)
      scanBars = span * 4 + 10;

   PivotPoint highLatest;
   PivotPoint highPrevious;
   PivotPoint lowLatest;
   PivotPoint lowPrevious;
   bool hasHighs = FindRecentPivots(patternRates, true, span, scanBars, highLatest, highPrevious);
   bool hasLows = FindRecentPivots(patternRates, false, span, scanBars, lowLatest, lowPrevious);

   double trendRange = MathAbs(setup.swingHigh - setup.swingLow);
   if(trendRange <= 0.0)
     {
      setup.skipReason = "no_mid_pullback";
      setup.midTfPullbackStatus = "no_range";
      return false;
     }

   if(direction > 0)
     {
      if(!hasLows)
        {
         setup.skipReason = "no_mid_pullback";
         setup.midTfPullbackStatus = "no_fractal_low";
         return false;
        }

      setup.retraceRatio = (setup.swingHigh - lowLatest.price) / trendRange;
      if(lowLatest.price <= setup.swingLow || setup.retraceRatio > 0.90)
        {
         setup.skipReason = "pullback_too_deep";
         setup.midTfPullbackStatus = "too_deep";
         setup.swingLow = lowLatest.price;
         return false;
        }
      if(setup.retraceRatio < 0.18)
        {
         setup.skipReason = "pullback_too_shallow";
         setup.midTfPullbackStatus = "too_shallow";
         setup.swingLow = lowLatest.price;
         return false;
        }

      setup.midTfPullbackStatus = "valid_higher_low";
      setup.swingLow = lowLatest.price;
      if(hasHighs)
         setup.swingHigh = MathMax(setup.swingHigh, highLatest.price);
      setup.structureSlSource = "mid_fractal_low";
      return true;
     }

   if(!hasHighs)
     {
      setup.skipReason = "no_mid_pullback";
      setup.midTfPullbackStatus = "no_fractal_high";
      return false;
     }

   setup.retraceRatio = (highLatest.price - setup.swingLow) / trendRange;
   if(highLatest.price >= setup.swingHigh || setup.retraceRatio > 0.90)
     {
      setup.skipReason = "pullback_too_deep";
      setup.midTfPullbackStatus = "too_deep";
      setup.swingHigh = highLatest.price;
      return false;
     }
   if(setup.retraceRatio < 0.18)
     {
      setup.skipReason = "pullback_too_shallow";
      setup.midTfPullbackStatus = "too_shallow";
      setup.swingHigh = highLatest.price;
      return false;
     }

   setup.midTfPullbackStatus = "valid_lower_high";
   setup.swingHigh = highLatest.price;
   if(hasLows)
      setup.swingLow = MathMin(setup.swingLow, lowLatest.price);
   setup.structureSlSource = "mid_fractal_high";
   return true;
  }

bool DetectLowerTimeframeReversal(const MqlRates &executionRates[],
                                  const int direction,
                                  ThirdWaveSetup &setup)
  {
   int span = InpStructureSwingSpan;
   if(span < 1)
      span = 1;

   int scanBars = MathMin(InpStructureScanBars, 48);
   if(scanBars < span * 4 + 10)
      scanBars = span * 4 + 10;

   PivotPoint highLatest;
   PivotPoint highPrevious;
   PivotPoint lowLatest;
   PivotPoint lowPrevious;
   bool hasHighs = FindRecentPivots(executionRates, true, span, scanBars, highLatest, highPrevious);
   bool hasLows = FindRecentPivots(executionRates, false, span, scanBars, lowLatest, lowPrevious);

   if(direction > 0)
     {
      if(!hasHighs)
        {
         setup.skipReason = "no_lower_reversal";
         setup.lowerTfReversalStatus = "no_minor_high";
         return false;
        }
      bool bullishBreak = (executionRates[1].close > highLatest.price &&
                           executionRates[1].close > executionRates[1].open);
      if(!bullishBreak)
        {
         setup.skipReason = "no_lower_reversal";
         setup.lowerTfReversalStatus = "minor_high_not_reclaimed";
         return false;
        }

      setup.lowerTfReversalStatus = "minor_high_reclaimed";
      setup.qualityScore = 100.0 + setup.retraceRatio * 20.0 - setup.spreadATR * 10.0;
      return true;
     }

   if(!hasLows)
     {
      setup.skipReason = "no_lower_reversal";
      setup.lowerTfReversalStatus = "no_minor_low";
      return false;
     }
   bool bearishBreak = (executionRates[1].close < lowLatest.price &&
                        executionRates[1].close < executionRates[1].open);
   if(!bearishBreak)
     {
      setup.skipReason = "no_lower_reversal";
      setup.lowerTfReversalStatus = "minor_low_not_broken";
      return false;
     }

   setup.lowerTfReversalStatus = "minor_low_broken";
   setup.qualityScore = 100.0 + setup.retraceRatio * 20.0 - setup.spreadATR * 10.0;
   return true;
  }

bool CalculateStructureStopLoss(const string symbol,
                                const int direction,
                                ThirdWaveSetup &setup)
  {
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      point = 0.0;

   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double spread = SpreadPrice(symbol);
   double buffer = MathMax(spread, setup.atr * 0.05);
   buffer = MathMax(buffer, point * 5.0);

   setup.entryPrice = (direction > 0 ? ask : bid);
   if(setup.entryPrice <= 0.0)
     {
      setup.skipReason = "market_closed";
      return false;
     }

   if(direction > 0)
     {
      setup.stopLoss = NormalizeDouble(setup.swingLow - buffer, digits);
      setup.riskR = setup.entryPrice - setup.stopLoss;
     }
   else
     {
      setup.stopLoss = NormalizeDouble(setup.swingHigh + buffer, digits);
      setup.riskR = setup.stopLoss - setup.entryPrice;
     }

   double brokerStop = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point + spread;
   double minDistance = MathMax(brokerStop, setup.atr * InpMinSL_ATR);
   double maxDistance = setup.atr * InpMaxSL_ATR;

   if(setup.riskR <= minDistance)
     {
      setup.skipReason = "sl_too_close";
      return false;
     }
   if(maxDistance > 0.0 && setup.riskR > maxDistance)
     {
      setup.skipReason = "sl_too_wide";
      return false;
     }

   setup.volume = CalculatePositionSize(symbol, setup.riskR);
   if(setup.volume <= 0.0)
     {
      setup.skipReason = "sl_too_close";
      return false;
     }

   return true;
  }

bool CalculateThirdWaveTakeProfit(const string symbol,
                                  const int direction,
                                  ThirdWaveSetup &setup)
  {
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   setup.rr = InpRewardR;
   if(setup.rr < 1.0)
     {
      setup.skipReason = "rr_too_low";
      return false;
     }

   if(direction > 0)
      setup.takeProfit = NormalizeDouble(setup.entryPrice + setup.riskR * setup.rr, digits);
   else
      setup.takeProfit = NormalizeDouble(setup.entryPrice - setup.riskR * setup.rr, digits);

   if(setup.takeProfit <= 0.0)
     {
      setup.skipReason = "rr_too_low";
      return false;
     }
   return true;
  }

bool BuildThirdWaveSetup(const string symbol,
                         const int direction,
                         ThirdWaveSetup &setup)
  {
   InitThirdWaveSetup(setup, symbol, direction);

   string researchReason = "";
   if(!IsSymbolAllowedByResearchMode(symbol, researchReason))
     {
      setup.skipReason = researchReason;
      return false;
     }
   if(!IsDirectionAllowedByResearchMode(symbol, direction, researchReason))
     {
      setup.skipReason = researchReason;
      return false;
     }

   MqlRates contextRates[];
   MqlRates patternRates[];
   MqlRates executionRates[];
   string reason = "";
   int barsNeeded = RequiredBars();
   if(!LoadRates(symbol, InpContextTF, barsNeeded, contextRates, reason) ||
      !LoadRates(symbol, InpPatternTF, barsNeeded, patternRates, reason) ||
      !LoadRates(symbol, InpExecutionTF, barsNeeded, executionRates, reason))
     {
      setup.skipReason = reason;
      return false;
     }

   setup.atr = AverageATR(patternRates, 1, InpATRPeriod);
   double executionATR = AverageATR(executionRates, 1, InpATRPeriod);
   if(setup.atr <= 0.0 || executionATR <= 0.0)
     {
      setup.skipReason = "atr_unavailable";
      return false;
     }
   setup.spreadATR = SpreadPrice(symbol) / executionATR;
   if(setup.spreadATR > InpMaxSpreadATR)
     {
      setup.skipReason = "spread_guard";
      return false;
     }

   setup.dataReady = true;
   if(!DetectHigherTimeframeDowTrend(contextRates, direction, setup))
      return false;
   if(!DetectMidTimeframePullback(patternRates, direction, setup))
      return false;

   setup.setupPass = true;
   if(!DetectLowerTimeframeReversal(executionRates, direction, setup))
      return false;
   if(!CalculateStructureStopLoss(symbol, direction, setup))
      return false;
   if(!CalculateThirdWaveTakeProfit(symbol, direction, setup))
      return false;

   setup.entryPass = true;
   setup.skipReason = "";
   return true;
  }

void RecordThirdWaveEvaluation(const ThirdWaveSetup &setup)
  {
   ++g_thirdWaveEvaluations;
   if(setup.direction == "LONG")
      ++g_thirdWaveLongEvaluations;
   else if(setup.direction == "SHORT")
      ++g_thirdWaveShortEvaluations;

   if(setup.setupPass)
      ++g_thirdWaveSetupPassCount;
   if(setup.entryPass)
      ++g_thirdWaveEntryPassCount;

   string reason = setup.skipReason;
   if(reason == "")
      return;

   if(reason == "no_higher_tf_trend")
      ++g_thirdWaveNoHigherTrendCount;
   else if(reason == "trend_broken")
      ++g_thirdWaveTrendBrokenCount;
   else if(reason == "no_mid_pullback")
      ++g_thirdWaveNoMidPullbackCount;
   else if(reason == "pullback_too_shallow")
      ++g_thirdWavePullbackTooShallowCount;
   else if(reason == "pullback_too_deep")
      ++g_thirdWavePullbackTooDeepCount;
   else if(reason == "no_lower_reversal")
      ++g_thirdWaveNoLowerReversalCount;
   else if(reason == "sl_too_close")
      ++g_thirdWaveSlTooCloseCount;
   else if(reason == "sl_too_wide")
      ++g_thirdWaveSlTooWideCount;
   else if(reason == "rr_too_low")
      ++g_thirdWaveRrTooLowCount;
   else if(reason == "existing_position")
      ++g_thirdWaveExistingPositionCount;
   else if(reason == "market_closed")
      ++g_thirdWaveMarketClosedCount;
   else if(reason == "spread_guard")
      ++g_thirdWaveSpreadGuardCount;
   else if(StringFind(reason, "data_insufficient_") == 0)
      ++g_thirdWaveDataUnavailableCount;
   else if(reason == "atr_unavailable")
      ++g_thirdWaveAtrUnavailableCount;
   else if(StringFind(reason, "symbol_research_") == 0 ||
           reason == "disabled_usdjpy_short" ||
           reason == "direction_mode_long_only" ||
           reason == "direction_mode_short_only")
      ++g_thirdWaveResearchExcludedCount;
   else
      ++g_thirdWaveUnknownSkipCount;
  }

bool ShouldWriteThirdWaveSignalDiagnostic(const ThirdWaveSetup &setup)
  {
   return (setup.setupPass || setup.entryPass);
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

void EvaluateDowFractalStructure(const string symbol,
                                 const MqlRates &contextRates[],
                                 const MqlRates &patternRates[],
                                 const MqlRates &executionRates[],
                                 const int direction,
                                 StructureFilterState &state)
  {
   ResetStructureFilterState(state);

   int span = InpStructureSwingSpan;
   if(span < 1)
      span = 1;

   int scanBars = InpStructureScanBars;
   if(scanBars < span * 4 + 10)
      scanBars = span * 4 + 10;

   PivotPoint contextHighLatest;
   PivotPoint contextHighPrevious;
   PivotPoint contextLowLatest;
   PivotPoint contextLowPrevious;
   PivotPoint patternHighLatest;
   PivotPoint patternHighPrevious;
   PivotPoint patternLowLatest;
   PivotPoint patternLowPrevious;

   bool hasContextHighs = FindRecentPivots(contextRates, true, span, scanBars, contextHighLatest, contextHighPrevious);
   bool hasContextLows = FindRecentPivots(contextRates, false, span, scanBars, contextLowLatest, contextLowPrevious);
   bool hasPatternHighs = FindRecentPivots(patternRates, true, span, scanBars, patternHighLatest, patternHighPrevious);
   bool hasPatternLows = FindRecentPivots(patternRates, false, span, scanBars, patternLowLatest, patternLowPrevious);

   if(hasContextHighs)
     {
      state.higherHigh = (contextHighLatest.price > contextHighPrevious.price);
      state.lowerHigh = (contextHighLatest.price < contextHighPrevious.price);
     }
   if(hasContextLows)
     {
      state.higherLow = (contextLowLatest.price > contextLowPrevious.price);
      state.lowerLow = (contextLowLatest.price < contextLowPrevious.price);
     }

   state.trendUp = (state.higherHigh && state.higherLow);
   state.trendDown = (state.lowerHigh && state.lowerLow);

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0.0)
      point = 0.0;

   if(direction > 0)
     {
      state.pullbackTooDeep = (hasContextLows && patternRates[1].low <= contextLowPrevious.price);
      state.pullbackValid = (hasContextLows &&
                             hasPatternLows &&
                             !state.pullbackTooDeep &&
                             patternLowLatest.price > contextLowPrevious.price &&
                             patternRates[1].low > contextLowPrevious.price);
      state.fractalConfirmed = hasPatternLows;

      bool m5Rebound = (executionRates[1].close > executionRates[1].open &&
                        executionRates[1].close > executionRates[2].high);
      bool fractalReclaim = false;
      if(hasPatternLows)
        {
         int reclaimBars = patternLowLatest.shift - 2;
         if(reclaimBars > 12)
            reclaimBars = 12;
         if(reclaimBars > 0)
           {
            double reclaimHigh = HighestHigh(patternRates, 2, reclaimBars);
            fractalReclaim = (reclaimHigh > 0.0 && patternRates[1].close > reclaimHigh);
           }
         state.structureStopReference = patternLowLatest.price - point * 2.0;
        }

      state.reclaimConfirmed = (state.fractalConfirmed && (fractalReclaim || m5Rebound));
      state.pass = (state.trendUp && state.pullbackValid && state.fractalConfirmed && state.reclaimConfirmed);

      if(!hasContextHighs || !hasContextLows)
         state.failReason = "no_context_swings";
      else if(!state.trendUp)
         state.failReason = "no_trend_up";
      else if(state.pullbackTooDeep)
         state.failReason = "pullback_too_deep";
      else if(!state.pullbackValid)
         state.failReason = "pullback_not_valid";
      else if(!state.fractalConfirmed)
         state.failReason = "no_fractal_low";
      else if(!state.reclaimConfirmed)
         state.failReason = "no_reclaim";
     }
   else
     {
      state.pullbackTooDeep = (hasContextHighs && patternRates[1].high >= contextHighPrevious.price);
      state.pullbackValid = (hasContextHighs &&
                             hasPatternHighs &&
                             !state.pullbackTooDeep &&
                             patternHighLatest.price < contextHighPrevious.price &&
                             patternRates[1].high < contextHighPrevious.price);
      state.fractalConfirmed = hasPatternHighs;

      bool m5Reject = (executionRates[1].close < executionRates[1].open &&
                       executionRates[1].close < executionRates[2].low);
      bool fractalBreak = false;
      if(hasPatternHighs)
        {
         int reclaimBars = patternHighLatest.shift - 2;
         if(reclaimBars > 12)
            reclaimBars = 12;
         if(reclaimBars > 0)
           {
            double reclaimLow = LowestLow(patternRates, 2, reclaimBars);
            fractalBreak = (reclaimLow > 0.0 && patternRates[1].close < reclaimLow);
           }
         state.structureStopReference = patternHighLatest.price + point * 2.0;
        }

      state.reclaimConfirmed = (state.fractalConfirmed && (fractalBreak || m5Reject));
      state.pass = (state.trendDown && state.pullbackValid && state.fractalConfirmed && state.reclaimConfirmed);

      if(!hasContextHighs || !hasContextLows)
         state.failReason = "no_context_swings";
      else if(!state.trendDown)
         state.failReason = "no_trend_down";
      else if(state.pullbackTooDeep)
         state.failReason = "pullback_too_deep";
      else if(!state.pullbackValid)
         state.failReason = "pullback_not_valid";
      else if(!state.fractalConfirmed)
         state.failReason = "no_fractal_high";
      else if(!state.reclaimConfirmed)
         state.failReason = "no_reclaim";
     }

   if(state.pass)
      state.failReason = "";
   if(!state.pass && state.failReason == "")
      state.failReason = "unknown";
  }

string StructureReasonTokens(const string symbol, const StructureFilterState &state)
  {
   string reason = "";
   if(state.trendUp)
      AppendReason(reason, "trend_up");
   if(state.trendDown)
      AppendReason(reason, "trend_down");
   if(state.higherHigh)
      AppendReason(reason, "higher_high");
   if(state.higherLow)
      AppendReason(reason, "higher_low");
   if(state.lowerHigh)
      AppendReason(reason, "lower_high");
   if(state.lowerLow)
      AppendReason(reason, "lower_low");
   if(state.pullbackValid)
      AppendReason(reason, "pullback_valid");
   if(state.pullbackTooDeep)
      AppendReason(reason, "pullback_too_deep");
   if(state.fractalConfirmed)
      AppendReason(reason, "fractal_confirmed");
   if(state.reclaimConfirmed)
      AppendReason(reason, "reclaim_confirmed");

   if(state.pass)
      AppendReason(reason, "structure_filter_pass");
   else
     {
      AppendReason(reason, "structure_filter_fail_reason");
      AppendReason(reason, "structure_filter_fail_reason_" + state.failReason);
     }

   if(state.structureStopReference > 0.0)
     {
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      AppendReason(reason, "structure_stop_reference_" + DoubleToString(state.structureStopReference, digits));
     }

   return reason;
  }

void RecordStructureEvaluation(const StructureFilterState &state)
  {
   ++g_structureEvaluations;
   if(state.pass)
     {
      ++g_structurePassCount;
      return;
     }

   ++g_structureFailCount;
   if(state.failReason == "no_context_swings")
      ++g_structureNoContextSwingsCount;
   else if(state.failReason == "no_trend_up")
      ++g_structureNoTrendUpCount;
   else if(state.failReason == "no_trend_down")
      ++g_structureNoTrendDownCount;
   else if(state.failReason == "pullback_too_deep")
      ++g_structurePullbackTooDeepCount;
   else if(state.failReason == "pullback_not_valid")
      ++g_structurePullbackNotValidCount;
   else if(state.failReason == "no_fractal_low")
      ++g_structureNoFractalLowCount;
   else if(state.failReason == "no_fractal_high")
      ++g_structureNoFractalHighCount;
   else if(state.failReason == "no_reclaim")
      ++g_structureNoReclaimCount;
   else
      ++g_structureUnknownFailCount;
  }

string TopStructureFailReason(long &count)
  {
   string reason = "";
   count = 0;

   if(g_structureNoContextSwingsCount > count)
     {
      reason = "no_context_swings";
      count = g_structureNoContextSwingsCount;
     }
   if(g_structureNoTrendUpCount > count)
     {
      reason = "no_trend_up";
      count = g_structureNoTrendUpCount;
     }
   if(g_structureNoTrendDownCount > count)
     {
      reason = "no_trend_down";
      count = g_structureNoTrendDownCount;
     }
   if(g_structurePullbackTooDeepCount > count)
     {
      reason = "pullback_too_deep";
      count = g_structurePullbackTooDeepCount;
     }
   if(g_structurePullbackNotValidCount > count)
     {
      reason = "pullback_not_valid";
      count = g_structurePullbackNotValidCount;
     }
   if(g_structureNoFractalLowCount > count)
     {
      reason = "no_fractal_low";
      count = g_structureNoFractalLowCount;
     }
   if(g_structureNoFractalHighCount > count)
     {
      reason = "no_fractal_high";
      count = g_structureNoFractalHighCount;
     }
   if(g_structureNoReclaimCount > count)
     {
      reason = "no_reclaim";
      count = g_structureNoReclaimCount;
     }
   if(g_structureUnknownFailCount > count)
     {
      reason = "unknown";
      count = g_structureUnknownFailCount;
     }

   return reason;
  }

double StructureFilterPenalty(const string symbol,
                              const MqlRates &contextRates[],
                              const MqlRates &patternRates[],
                              const MqlRates &executionRates[],
                              const int direction,
                              string &reason,
                              StructureFilterState &state,
                              bool &structureEvaluated)
  {
   structureEvaluated = false;
   ResetStructureFilterState(state);

   if(!InpUseDowFractalStructureFilter)
      return 0.0;

   EvaluateDowFractalStructure(symbol, contextRates, patternRates, executionRates, direction, state);
   structureEvaluated = true;
   RecordStructureEvaluation(state);
   AppendReason(reason, StructureReasonTokens(symbol, state));

   if(!state.pass)
      return 100.0;
   return 0.0;
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
   StructureFilterState structureState;
   bool structureEvaluated = false;
   risk += StructureFilterPenalty(symbol, contextRates, patternRates, executionRates, direction, reason, structureState, structureEvaluated);

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
   score.structureEvaluated = structureEvaluated;
   score.structureState = structureState;
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
   score.structureEvaluated = false;
   ResetStructureFilterState(score.structureState);
   score.reason = "";
  }

bool EvaluateSymbol(const string symbol, SymbolScore &bestScore)
  {
   InitScore(bestScore, symbol);

   string researchReason = "";
   if(!IsSymbolAllowedByResearchMode(symbol, researchReason))
     {
      bestScore.reason = researchReason;
      return false;
     }

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

   string longBlockReason = "";
   string shortBlockReason = "";
   bool allowLong = IsDirectionAllowedByResearchMode(symbol, 1, longBlockReason);
   bool allowShort = IsDirectionAllowedByResearchMode(symbol, -1, shortBlockReason);

   if(!allowLong && !allowShort)
     {
      AppendReason(bestScore.reason, longBlockReason);
      AppendReason(bestScore.reason, shortBlockReason);
      return false;
     }

   if(allowLong)
      ScoreSide(symbol, contextRates, patternRates, executionRates, patternATR, averagePatternATR, executionATR, 1, longScore);
   if(allowShort)
      ScoreSide(symbol, contextRates, patternRates, executionRates, patternATR, averagePatternATR, executionATR, -1, shortScore);

   if(allowLong && allowShort)
      bestScore = (longScore.totalScore >= shortScore.totalScore ? longScore : shortScore);
   else if(allowLong)
      bestScore = longScore;
   else
      bestScore = shortScore;

   AppendReason(bestScore.reason, longBlockReason);
   AppendReason(bestScore.reason, shortBlockReason);

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

string DailyScanLogFileName()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return StringFormat("%s\\%s_scan_%04d%02d%02d.csv",
                       InpLogFolder,
                       InpLogPrefix,
                       tm.year,
                       tm.mon,
                       tm.day);
  }

string DailyStructureLogFileName()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return StringFormat("%s\\%s_structure_%04d%02d%02d.csv",
                       InpLogFolder,
                       InpLogPrefix,
                       tm.year,
                       tm.mon,
                       tm.day);
  }

string DailyStructureSummaryLogFileName()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return StringFormat("%s\\%s_structure_summary_%04d%02d%02d.csv",
                       InpLogFolder,
                       InpLogPrefix,
                       tm.year,
                       tm.mon,
                       tm.day);
  }

string DailyThirdWaveSignalLogFileName()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return StringFormat("%s\\thirdwave_signal_diagnostics_%04d%02d%02d.csv",
                       InpLogFolder,
                       tm.year,
                       tm.mon,
                       tm.day);
  }

string DailyThirdWaveTradeLogFileName()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return StringFormat("%s\\thirdwave_trade_diagnostics_%04d%02d%02d.csv",
                       InpLogFolder,
                       tm.year,
                       tm.mon,
                       tm.day);
  }

string DailyThirdWaveSummaryLogFileName()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   return StringFormat("%s\\thirdwave_summary_%04d%02d%02d.csv",
                       InpLogFolder,
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

void WriteScanDiagnosticRow(const string eventName,
                            const datetime lastScanBarTime,
                            const uint elapsedMs,
                            const string reason)
  {
   EnsureLogFolder();

   int flags = FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;

   string fileName = DailyScanLogFileName();
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
                "event",
                "last_scan_bar_time",
                "scan_elapsed_ms",
                "reason");

   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             eventName,
             DateTimeText(lastScanBarTime),
             IntegerToString((int)elapsedMs),
             reason);

   FileClose(handle);
  }

void WriteStructureFilterRow(const string symbol, const string direction, const StructureFilterState &state)
  {
   ++g_structureDetailRows;
   EnsureLogFolder();

   int flags = FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;

   string fileName = DailyStructureLogFileName();
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
                "trend_up",
                "trend_down",
                "higher_high",
                "higher_low",
                "lower_high",
                "lower_low",
                "pullback_valid",
                "pullback_too_deep",
                "fractal_confirmed",
                "reclaim_confirmed",
                "structure_filter_pass",
                "structure_filter_fail_reason",
                "structure_stop_reference");

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             symbol,
             direction,
             BoolText(state.trendUp),
             BoolText(state.trendDown),
             BoolText(state.higherHigh),
             BoolText(state.higherLow),
             BoolText(state.lowerHigh),
             BoolText(state.lowerLow),
             BoolText(state.pullbackValid),
             BoolText(state.pullbackTooDeep),
             BoolText(state.fractalConfirmed),
             BoolText(state.reclaimConfirmed),
             BoolText(state.pass),
             state.failReason,
             DoubleToString(state.structureStopReference, digits));

   FileClose(handle);
  }

void WriteStructureSummaryRow()
  {
   EnsureLogFolder();

   int flags = FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;

   string fileName = DailyStructureSummaryLogFileName();
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
                "structure_evaluations",
                "structure_detail_rows",
                "structure_pass",
                "structure_fail",
                "structure_pass_rate",
                "no_context_swings",
                "no_trend_up",
                "no_trend_down",
                "pullback_too_deep",
                "pullback_not_valid",
                "no_fractal_low",
                "no_fractal_high",
                "not_enough_fractals",
                "no_reclaim",
                "unknown",
                "structure_top_fail_reason",
                "structure_top_fail_reason_rows");

   long topFailCount = 0;
   string topFailReason = TopStructureFailReason(topFailCount);
   long notEnoughFractals = g_structureNoContextSwingsCount + g_structureNoFractalLowCount + g_structureNoFractalHighCount;
   double passRate = 0.0;
   if(g_structureEvaluations > 0)
      passRate = (double)g_structurePassCount / (double)g_structureEvaluations * 100.0;

   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             g_structureEvaluations,
             g_structureDetailRows,
             g_structurePassCount,
             g_structureFailCount,
             DoubleToString(passRate, 2),
             g_structureNoContextSwingsCount,
             g_structureNoTrendUpCount,
             g_structureNoTrendDownCount,
             g_structurePullbackTooDeepCount,
             g_structurePullbackNotValidCount,
             g_structureNoFractalLowCount,
             g_structureNoFractalHighCount,
             notEnoughFractals,
             g_structureNoReclaimCount,
             g_structureUnknownFailCount,
             topFailReason,
             topFailCount);

   FileClose(handle);
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

void WriteThirdWaveSignalRow(const ThirdWaveSetup &setup)
  {
   EnsureLogFolder();

   int flags = FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;

   string fileName = DailyThirdWaveSignalLogFileName();
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
                "higher_tf_trend",
                "mid_tf_pullback_status",
                "lower_tf_reversal_status",
                "setup_pass",
                "entry_pass",
                "skip_reason",
                "entry_price",
                "sl",
                "tp",
                "risk_r",
                "rr",
                "swing_high",
                "swing_low",
                "structure_sl_source",
                "strategy_name");

   int digits = (int)SymbolInfoInteger(setup.symbol, SYMBOL_DIGITS);
   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             setup.symbol,
             setup.direction,
             setup.higherTfTrend,
             setup.midTfPullbackStatus,
             setup.lowerTfReversalStatus,
             BoolText(setup.setupPass),
             BoolText(setup.entryPass),
             setup.skipReason,
             DoubleToString(setup.entryPrice, digits),
             DoubleToString(setup.stopLoss, digits),
             DoubleToString(setup.takeProfit, digits),
             DoubleToString(setup.riskR, digits),
             DoubleToString(setup.rr, 2),
             DoubleToString(setup.swingHigh, digits),
             DoubleToString(setup.swingLow, digits),
             setup.structureSlSource,
             "DowFractal_ThirdWave");

   FileClose(handle);
  }

void WriteThirdWaveTradeRow(const ThirdWaveSetup &setup,
                            const string eventName,
                            const string resultReason,
                            const long retcode)
  {
   EnsureLogFolder();

   int flags = FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;

   string fileName = DailyThirdWaveTradeLogFileName();
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
                "event",
                "order_retcode",
                "order_comment",
                "entry_price",
                "sl",
                "tp",
                "volume",
                "risk_r",
                "rr",
                "skip_reason",
                "strategy_name");

   int digits = (int)SymbolInfoInteger(setup.symbol, SYMBOL_DIGITS);
   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             setup.symbol,
             setup.direction,
             eventName,
             IntegerToString((int)retcode),
             resultReason,
             DoubleToString(setup.entryPrice, digits),
             DoubleToString(setup.stopLoss, digits),
             DoubleToString(setup.takeProfit, digits),
             DoubleToString(setup.volume, 2),
             DoubleToString(setup.riskR, digits),
             DoubleToString(setup.rr, 2),
             setup.skipReason,
             "DowFractal_ThirdWave");

   FileClose(handle);
  }

string TopThirdWaveSkipReason(long &count)
  {
   string reason = "";
   count = 0;

   if(g_thirdWaveNoHigherTrendCount > count)
     {
      reason = "no_higher_tf_trend";
      count = g_thirdWaveNoHigherTrendCount;
     }
   if(g_thirdWaveTrendBrokenCount > count)
     {
      reason = "trend_broken";
      count = g_thirdWaveTrendBrokenCount;
     }
   if(g_thirdWaveNoMidPullbackCount > count)
     {
      reason = "no_mid_pullback";
      count = g_thirdWaveNoMidPullbackCount;
     }
   if(g_thirdWavePullbackTooShallowCount > count)
     {
      reason = "pullback_too_shallow";
      count = g_thirdWavePullbackTooShallowCount;
     }
   if(g_thirdWavePullbackTooDeepCount > count)
     {
      reason = "pullback_too_deep";
      count = g_thirdWavePullbackTooDeepCount;
     }
   if(g_thirdWaveNoLowerReversalCount > count)
     {
      reason = "no_lower_reversal";
      count = g_thirdWaveNoLowerReversalCount;
     }
   if(g_thirdWaveSlTooCloseCount > count)
     {
      reason = "sl_too_close";
      count = g_thirdWaveSlTooCloseCount;
     }
   if(g_thirdWaveSlTooWideCount > count)
     {
      reason = "sl_too_wide";
      count = g_thirdWaveSlTooWideCount;
     }
   if(g_thirdWaveRrTooLowCount > count)
     {
      reason = "rr_too_low";
      count = g_thirdWaveRrTooLowCount;
     }
   if(g_thirdWaveExistingPositionCount > count)
     {
      reason = "existing_position";
      count = g_thirdWaveExistingPositionCount;
     }
   if(g_thirdWaveMarketClosedCount > count)
     {
      reason = "market_closed";
      count = g_thirdWaveMarketClosedCount;
     }
   if(g_thirdWaveSpreadGuardCount > count)
     {
      reason = "spread_guard";
      count = g_thirdWaveSpreadGuardCount;
     }
   if(g_thirdWaveDataUnavailableCount > count)
     {
      reason = "data_unavailable";
      count = g_thirdWaveDataUnavailableCount;
     }
   if(g_thirdWaveAtrUnavailableCount > count)
     {
      reason = "atr_unavailable";
      count = g_thirdWaveAtrUnavailableCount;
     }
   if(g_thirdWaveResearchExcludedCount > count)
     {
      reason = "research_excluded";
      count = g_thirdWaveResearchExcludedCount;
     }
   if(g_thirdWaveUnknownSkipCount > count)
     {
      reason = "unknown";
      count = g_thirdWaveUnknownSkipCount;
     }

   return reason;
  }

void WriteThirdWaveSummaryRow()
  {
   if(InpResearchStrategyMode != RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE &&
      g_thirdWaveEvaluations <= 0)
      return;

   EnsureLogFolder();

   int flags = FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_ANSI;
   if(InpUseCommonFiles)
      flags |= FILE_COMMON;

   string fileName = DailyThirdWaveSummaryLogFileName();
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
                "strategy_name",
                "evaluations",
                "long_evaluations",
                "short_evaluations",
                "setup_pass",
                "entry_pass",
                "orders_sent",
                "orders_failed",
                "no_higher_tf_trend",
                "trend_broken",
                "no_mid_pullback",
                "pullback_too_shallow",
                "pullback_too_deep",
                "no_lower_reversal",
                "sl_too_close",
                "sl_too_wide",
                "rr_too_low",
                "existing_position",
                "market_closed",
                "spread_guard",
                "data_unavailable",
                "atr_unavailable",
                "research_excluded",
                "unknown",
                "top_skip_reason",
                "top_skip_reason_rows");

   long topSkipCount = 0;
   string topSkipReason = TopThirdWaveSkipReason(topSkipCount);

   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             "DowFractal_ThirdWave",
             g_thirdWaveEvaluations,
             g_thirdWaveLongEvaluations,
             g_thirdWaveShortEvaluations,
             g_thirdWaveSetupPassCount,
             g_thirdWaveEntryPassCount,
             g_thirdWaveOrderSentCount,
             g_thirdWaveOrderFailedCount,
             g_thirdWaveNoHigherTrendCount,
             g_thirdWaveTrendBrokenCount,
             g_thirdWaveNoMidPullbackCount,
             g_thirdWavePullbackTooShallowCount,
             g_thirdWavePullbackTooDeepCount,
             g_thirdWaveNoLowerReversalCount,
             g_thirdWaveSlTooCloseCount,
             g_thirdWaveSlTooWideCount,
             g_thirdWaveRrTooLowCount,
             g_thirdWaveExistingPositionCount,
             g_thirdWaveMarketClosedCount,
             g_thirdWaveSpreadGuardCount,
             g_thirdWaveDataUnavailableCount,
             g_thirdWaveAtrUnavailableCount,
             g_thirdWaveResearchExcludedCount,
             g_thirdWaveUnknownSkipCount,
             topSkipReason,
             topSkipCount);

   FileClose(handle);
  }

bool IsEntryScoreCandidate(const SymbolScore &score)
  {
   return (score.dataReady && score.totalScore >= InpEntryScoreThreshold);
  }

bool ShouldWriteScoreDiagnostic(const SymbolScore &score, const bool isBest)
  {
   if(!score.dataReady)
      return false;
   if(isBest)
      return true;
   if(IsEntryScoreCandidate(score))
      return true;
   return false;
  }

bool ShouldWriteStructureDiagnostic(const SymbolScore &score, const bool isBest)
  {
   if(!score.structureEvaluated)
      return false;
   if(isBest)
      return true;
   if(IsEntryScoreCandidate(score))
      return true;
   if(score.structureState.pass)
      return true;
   return false;
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
        {
         string rowReason = score.reason;
         AppendReason(rowReason, "order_blocked");
         AppendReason(rowReason, blockReason);
         WriteScoreRow(score, rowReason);
         if(score.structureEvaluated)
            WriteStructureFilterRow(score.symbol, score.direction, score.structureState);
        }
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
   string attemptReason = score.reason;
   AppendReason(attemptReason, "order_attempt");
   WriteScoreRow(score, attemptReason);
   if(score.structureEvaluated)
      WriteStructureFilterRow(score.symbol, score.direction, score.structureState);

   bool ok = false;
   if(score.direction == "LONG")
      ok = trade.Buy(score.volume, score.symbol, 0.0, score.stopLoss, score.takeProfit, comment);
   else if(score.direction == "SHORT")
      ok = trade.Sell(score.volume, score.symbol, 0.0, score.stopLoss, score.takeProfit, comment);

   if(!ok)
     {
      string resultReason = score.reason;
      AppendReason(resultReason, "order_failed");
      AppendReason(resultReason, "retcode_" + IntegerToString((int)trade.ResultRetcode()));
      WriteScoreRow(score, resultReason);
      if(score.structureEvaluated)
         WriteStructureFilterRow(score.symbol, score.direction, score.structureState);
      PrintFormat("%s: order failed %s %s lot=%.2f retcode=%d",
                  STRATEGY_NAME,
                  score.symbol,
                  score.direction,
                  score.volume,
                  trade.ResultRetcode());
     }
   else
     {
      string resultReason = score.reason;
      AppendReason(resultReason, "order_sent");
      WriteScoreRow(score, resultReason);
      if(score.structureEvaluated)
         WriteStructureFilterRow(score.symbol, score.direction, score.structureState);
      PrintFormat("%s: order sent %s %s lot=%.2f score=%.2f",
                  STRATEGY_NAME,
                  score.symbol,
                  score.direction,
                  score.volume,
                  score.totalScore);
     }
  }

bool CanTradeThirdWaveCandidate(const ThirdWaveSetup &setup, string &blockReason)
  {
   blockReason = "";
   if(!InpEnableTrading)
     {
      blockReason = "trading_disabled";
      return false;
     }
   if(!setup.dataReady || !setup.entryPass)
     {
      blockReason = "no_entry_signal";
      return false;
     }
   if(setup.direction != "LONG" && setup.direction != "SHORT")
     {
      blockReason = "direction_none";
      return false;
     }
   if(setup.stopLoss <= 0.0 || setup.takeProfit <= 0.0 || setup.volume <= 0.0)
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
   if(CountManagedPositionsForSymbol(setup.symbol) > 0)
     {
      blockReason = "existing_position";
      return false;
     }
   if(InpMaxSameCurrencyGroupPositions > 0 &&
      CountManagedPositionsForGroup(CurrencyGroup(setup.symbol)) >= InpMaxSameCurrencyGroupPositions)
     {
      blockReason = "same_currency_group_limit";
      return false;
     }
   if(CurrentSymbolOpenRiskPercent(setup.symbol) + InpRiskPerTradePercent > InpMaxRiskPerSymbolPercent)
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

void TryThirdWaveEntry(ThirdWaveSetup &setup)
  {
   string blockReason = "";
   if(!CanTradeThirdWaveCandidate(setup, blockReason))
     {
      if(blockReason == "existing_position")
         ++g_thirdWaveExistingPositionCount;
      setup.skipReason = blockReason;
      WriteThirdWaveTradeRow(setup, "order_blocked", blockReason, 0);
      WriteThirdWaveSignalRow(setup);
      PrintFormat("%s: thirdwave trade blocked %s %s reason=%s",
                  STRATEGY_NAME,
                  setup.symbol,
                  setup.direction,
                  blockReason);
      return;
     }

   string comment = "DowFractal_ThirdWave";
   WriteThirdWaveTradeRow(setup, "order_attempt", "", 0);
   bool ok = false;
   if(setup.direction == "LONG")
      ok = trade.Buy(setup.volume, setup.symbol, 0.0, setup.stopLoss, setup.takeProfit, comment);
   else if(setup.direction == "SHORT")
      ok = trade.Sell(setup.volume, setup.symbol, 0.0, setup.stopLoss, setup.takeProfit, comment);

   if(!ok)
     {
      ++g_thirdWaveOrderFailedCount;
      setup.skipReason = "order_failed";
      WriteThirdWaveTradeRow(setup, "order_failed", "retcode_" + IntegerToString((int)trade.ResultRetcode()), (long)trade.ResultRetcode());
      WriteThirdWaveSignalRow(setup);
      PrintFormat("%s: thirdwave order failed %s %s lot=%.2f retcode=%d",
                  STRATEGY_NAME,
                  setup.symbol,
                  setup.direction,
                  setup.volume,
                  trade.ResultRetcode());
     }
   else
     {
      ++g_thirdWaveOrderSentCount;
      WriteThirdWaveTradeRow(setup, "order_sent", "order_sent", (long)trade.ResultRetcode());
      WriteThirdWaveSignalRow(setup);
      PrintFormat("%s: thirdwave order sent %s %s lot=%.2f rr=%.2f",
                  STRATEGY_NAME,
                  setup.symbol,
                  setup.direction,
                  setup.volume,
                  setup.rr);
     }
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
      bool isBest = (bestIndex == i);
      if(bestIndex == i)
         AppendReason(rowReason, "best_candidate");
      else
         AppendReason(rowReason, "not_best");
      if(ShouldWriteScoreDiagnostic(scores[i], isBest))
         WriteScoreRow(scores[i], rowReason);
      if(ShouldWriteStructureDiagnostic(scores[i], isBest))
         WriteStructureFilterRow(scores[i].symbol, scores[i].direction, scores[i].structureState);
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

int FindBestThirdWaveCandidate(const ThirdWaveSetup &setups[])
  {
   int bestIndex = -1;
   double bestQuality = -DBL_MAX;
   int size = ArraySize(setups);

   for(int i = 0; i < size; ++i)
     {
      if(!setups[i].entryPass)
         continue;
      if(setups[i].qualityScore > bestQuality)
        {
         bestQuality = setups[i].qualityScore;
         bestIndex = i;
        }
     }

   return bestIndex;
  }

void ScanThirdWaveSymbols()
  {
   UpdateRiskAnchors();

   int symbolCount = ArraySize(g_symbols);
   if(symbolCount <= 0)
      return;

   ThirdWaveSetup setups[];
   ArrayResize(setups, 0);

   for(int i = 0; i < symbolCount; ++i)
     {
      for(int direction = 1; direction >= -1; direction -= 2)
        {
         string directionReason = "";
         if(!IsDirectionAllowedByResearchMode(g_symbols[i], direction, directionReason))
            continue;

         ThirdWaveSetup setup;
         BuildThirdWaveSetup(g_symbols[i], direction, setup);
         RecordThirdWaveEvaluation(setup);

         int size = ArraySize(setups);
         ArrayResize(setups, size + 1);
         setups[size] = setup;

         if(ShouldWriteThirdWaveSignalDiagnostic(setup))
            WriteThirdWaveSignalRow(setup);
        }
     }

   int bestIndex = FindBestThirdWaveCandidate(setups);
   if(bestIndex >= 0)
     {
      ThirdWaveSetup best = setups[bestIndex];
      PrintFormat("%s: thirdwave best=%s %s trend=%s pullback=%s reversal=%s rr=%.2f",
                  STRATEGY_NAME,
                  best.symbol,
                  best.direction,
                  best.higherTfTrend,
                  best.midTfPullbackStatus,
                  best.lowerTfReversalStatus,
                  best.rr);
      TryThirdWaveEntry(best);
     }
   else
      PrintFormat("%s: thirdwave no entry candidate in scan", STRATEGY_NAME);
  }

void RunActiveStrategyScan()
  {
   if(InpResearchStrategyMode == RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE)
      ScanThirdWaveSymbols();
   else
      ScanAllSymbols();
  }

bool LatestClosedExecutionBarTime(datetime &barTime, string &reason)
  {
   barTime = 0;
   reason = "";

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, InpExecutionTF, 1, 1, rates);
   if(copied < 1)
     {
      reason = "execution_bar_time_unavailable_" + EnumToString(InpExecutionTF);
      return false;
     }

   barTime = rates[0].time;
   return (barTime > 0);
  }

void RunTimerScan()
  {
   uint started = GetTickCount();
   RunActiveStrategyScan();
   uint elapsed = GetTickCount() - started;
   WriteScanDiagnosticRow("scan_executed_timer", 0, elapsed, "scan_only_on_new_execution_bar_false");
   PrintFormat("%s: scan_executed_timer scan_elapsed_ms=%u",
               STRATEGY_NAME,
               elapsed);
  }

void RunNewExecutionBarScan()
  {
   datetime barTime = 0;
   string reason = "";
   if(!LatestClosedExecutionBarTime(barTime, reason))
     {
      WriteScanDiagnosticRow("scan_skipped_execution_bar_unavailable", g_lastScanExecutionBarTime, 0, reason);
      PrintFormat("%s: scan_skipped_execution_bar_unavailable last_scan_bar_time=%s reason=%s",
                  STRATEGY_NAME,
                  DateTimeText(g_lastScanExecutionBarTime),
                  reason);
      return;
     }

   if(barTime <= g_lastScanExecutionBarTime)
     {
      if(g_lastLoggedSkippedExecutionBarTime != g_lastScanExecutionBarTime)
        {
         g_lastLoggedSkippedExecutionBarTime = g_lastScanExecutionBarTime;
         WriteScanDiagnosticRow("scan_skipped_same_execution_bar", g_lastScanExecutionBarTime, 0, "");
         PrintFormat("%s: scan_skipped_same_execution_bar last_scan_bar_time=%s",
                     STRATEGY_NAME,
                     DateTimeText(g_lastScanExecutionBarTime));
        }
      return;
     }

   g_lastScanExecutionBarTime = barTime;
   uint started = GetTickCount();
   RunActiveStrategyScan();
   uint elapsed = GetTickCount() - started;
   WriteScanDiagnosticRow("scan_executed_new_execution_bar", g_lastScanExecutionBarTime, elapsed, "");
   PrintFormat("%s: scan_executed_new_execution_bar last_scan_bar_time=%s scan_elapsed_ms=%u",
               STRATEGY_NAME,
               DateTimeText(g_lastScanExecutionBarTime),
               elapsed);
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
      InpStructureSwingSpan < 1 ||
      InpStructureScanBars < InpStructureSwingSpan * 4 + 10 ||
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

   PrintFormat("%s initialized symbols=%d trading=%s scan_seconds=%d scan_only_new_execution_bar=%s strategy_mode=%d direction_mode=%d symbol_research_mode=%d dow_fractal_filter=%s",
               STRATEGY_NAME,
               ArraySize(g_symbols),
               (InpEnableTrading ? "true" : "false"),
               InpScanSeconds,
               BoolText(InpScanOnlyOnNewExecutionBar),
               (int)InpResearchStrategyMode,
               (int)InpTradeDirectionMode,
               (int)InpSymbolResearchMode,
               BoolText(InpUseDowFractalStructureFilter));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   WriteStructureSummaryRow();
   WriteThirdWaveSummaryRow();
   EventKillTimer();
  }

void OnTick()
  {
  }

void OnTimer()
  {
   if(InpScanOnlyOnNewExecutionBar)
      RunNewExecutionBarScan();
   else
      RunTimerScan();
  }
