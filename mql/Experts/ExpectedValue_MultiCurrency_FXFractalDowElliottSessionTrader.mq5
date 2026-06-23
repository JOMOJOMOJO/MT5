//+------------------------------------------------------------------+
//| ExpectedValue_MultiCurrency_FXFractalDowElliottSessionTrader     |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Backtest-only multi-currency FX Fractal/Dow/Elliott roadmap EA with session volatility diagnostics."

#include <Trade\Trade.mqh>

CTrade trade;

static const string STRATEGY_NAME = "ExpectedValue_MultiCurrency_FXFractalDowElliottSessionTrader";
static const string RESEARCH_STRATEGY_NAME = "RESEARCH_STRATEGY_FX_FRACTAL_DOW_ELLIOTT_SESSION";

enum ENUM_ROADMAP_SCENARIO
  {
   BASELINE_ALL_SESSIONS = 0,
   SESSION_VOLATILITY_ONLY_FILTER = 1,
   LONDON_ONLY_REFERENCE = 2,
   NEWYORK_ONLY_REFERENCE = 3,
   TOKYO_ONLY_REFERENCE = 4,
   LONDON_NEWYORK_OVERLAP_REFERENCE = 5,
   SYMBOL_BEST_SESSION = 6,
   SYMBOL_BEST_SESSION_WITH_DOW_ALIGNMENT = 7,
   SYMBOL_BEST_SESSION_WITH_WAVE3_CONFIRMED = 8
  };

struct SwingPoint
  {
   bool              valid;
   bool              isHigh;
   int               shift;
   double            price;
   datetime          time;
   datetime          confirmedTime;
   double            atr;
  };

struct SignalPlan
  {
   bool              valid;
   string            symbol;
   string            direction;
   string            strategy;
   string            setupType;
   string            waveStage;
   string            waveTF;
   string            baseCurrency;
   string            quoteCurrency;
   datetime          serverTime;
   int               serverHour;
   int               utcHour;
   string            sessionLabel;
   string            sessionWindowName;
   bool              allowedSession;
   int               sessionVolatilityRank;
   string            dowRegimeH4;
   string            dowRegimeH1;
   string            h4Structure;
   string            h1Structure;
   string            fractalAlignment;
   string            fibZone;
   string            divergenceType;
   string            m15ConfirmationType;
   string            failureType;
   string            reason;
   double            waveSizeATR;
   double            retracementRatio;
   double            extensionRatio;
   string            waveRuleValidity;
   bool              wave3BreakConfirmed;
   int               pivotConfirmationDelayBars;
   int               entryDelayFromPivot;
   datetime          pivotTime;
   datetime          pivotConfirmedTime;
   double            roomTo1R;
   double            roomTo2R;
   double            entry;
   double            stopLoss;
   double            takeProfit;
   double            riskPrice;
   double            rewardR;
   double            atr;
   double            spreadPoints;
   double            spreadATR;
   double            atrSessionPercentile;
   double            averageM15RangeATR;
   double            averageH1RangeATR;
   double            averageTrueRange;
   double            realizedVolatility;
   double            breakoutFollowthroughRate;
   double            averageSpreadATR;
   double            score;
  };

struct TrackedTrade
  {
   bool              active;
   string            symbol;
   string            direction;
   string            strategy;
   string            setupType;
   string            waveStage;
   string            waveTF;
   string            baseCurrency;
   string            quoteCurrency;
   datetime          serverTime;
   int               serverHour;
   int               utcHour;
   string            sessionLabel;
   string            sessionWindowName;
   bool              allowedSession;
   int               sessionVolatilityRank;
   string            dowRegimeH4;
   string            dowRegimeH1;
   string            h4Structure;
   string            h1Structure;
   string            fractalAlignment;
   string            fibZone;
   string            divergenceType;
   string            m15ConfirmationType;
   string            entryFailureType;
   double            waveSizeATR;
   double            retracementRatio;
   double            extensionRatio;
   string            waveRuleValidity;
   bool              wave3BreakConfirmed;
   int               pivotConfirmationDelayBars;
   int               entryDelayFromPivot;
   datetime          pivotTime;
   datetime          pivotConfirmedTime;
   double            roomTo1R;
   double            roomTo2R;
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
   double            spreadATR;
   double            atrSessionPercentile;
   double            averageM15RangeATR;
   double            averageH1RangeATR;
   double            averageTrueRange;
   double            realizedVolatility;
   double            breakoutFollowthroughRate;
   double            averageSpreadATR;
   double            score;
  };

struct SessionStats
  {
   string            label;
   string            windowName;
   int               rank;
   double            averageM15RangeATR;
   double            averageH1RangeATR;
   double            averageTrueRange;
   double            realizedVolatility;
   double            breakoutFollowthroughRate;
   double            averageSpreadATR;
   double            atrSessionPercentile;
  };

input string          InpSymbols                       = "USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD";
input ENUM_ROADMAP_SCENARIO InpScenarioMode            = BASELINE_ALL_SESSIONS;
input ENUM_TIMEFRAMES InpScanTF                        = PERIOD_M15;
input ENUM_TIMEFRAMES InpFastWaveTF                    = PERIOD_H1;
input ENUM_TIMEFRAMES InpSlowWaveTF                    = PERIOD_H4;
input int             InpSwingDepth                    = 3;
input int             InpWaveScanBars                  = 180;
input int             InpATRPeriod                     = 14;
input double          InpMinSwingSizeATR               = 0.70;
input double          InpWave2MinRetrace               = 0.25;
input double          InpWave2MaxRetrace               = 0.92;
input double          InpWave4MaxRetrace               = 0.70;
input double          InpWave4MaxOverlapATR            = 0.20;
input double          InpWave3MinVsWave1               = 0.75;
input int             InpScanFastMAPeriod              = 10;
input int             InpScanSlowMAPeriod              = 30;
input int             InpMicroBosLookbackBars          = 8;
input double          InpCandleBodyATR                 = 0.25;
input int             InpRSIPeriod                     = 14;
input int             InpMACDFastPeriod                = 12;
input int             InpMACDSlowPeriod                = 26;
input int             InpObstacleLookbackBars          = 48;
input int             InpBrokerUtcOffsetHours          = 2;
input int             InpSessionAuditLookbackBars      = 360;
input int             InpSessionRankLookbackBars       = 240;
input int             InpSessionRankAllowedMax         = 2;
input double          InpSessionMinRangeATR            = 0.55;
input double          InpFractalAlignmentATR           = 1.20;
input double          InpDowTransitionATR              = 0.25;
input double          InpSLBufferATR                   = 0.15;
input double          InpMinSL_ATR                     = 0.35;
input double          InpMaxSL_ATR                     = 4.00;
input double          InpRewardR                       = 1.40;
input int             InpMaxHoldBars                   = 32;
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
input long            InpMagicNumber                   = 2026062401;
input bool            InpUseCommonFiles                = true;
input string          InpLogFolder                     = "fxfractal_dow_elliott_session";
input string          InpLogPrefix                     = "fxfractal";

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
   if(InpScenarioMode == BASELINE_ALL_SESSIONS)
      return "baseline_all_sessions";
   if(InpScenarioMode == SESSION_VOLATILITY_ONLY_FILTER)
      return "session_volatility_only_filter";
   if(InpScenarioMode == LONDON_ONLY_REFERENCE)
      return "london_only_reference";
   if(InpScenarioMode == NEWYORK_ONLY_REFERENCE)
      return "newyork_only_reference";
   if(InpScenarioMode == TOKYO_ONLY_REFERENCE)
      return "tokyo_only_reference";
   if(InpScenarioMode == LONDON_NEWYORK_OVERLAP_REFERENCE)
      return "london_newyork_overlap_reference";
   if(InpScenarioMode == SYMBOL_BEST_SESSION)
      return "symbol_best_session";
   if(InpScenarioMode == SYMBOL_BEST_SESSION_WITH_DOW_ALIGNMENT)
      return "symbol_best_session_with_dow_alignment";
   return "symbol_best_session_with_wave3_confirmed";
  }

string TFName(const ENUM_TIMEFRAMES tf)
  {
   if(tf == PERIOD_H1)
      return "H1";
   if(tf == PERIOD_H4)
      return "H4";
   if(tf == PERIOD_M15)
      return "M15";
   return EnumToString(tf);
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

string BaseCurrency(const string symbol)
  {
   return StringSubstr(symbol, 0, 3);
  }

string QuoteCurrency(const string symbol)
  {
   return StringSubstr(symbol, 3, 3);
  }

datetime UtcFromServer(const datetime serverTime)
  {
   return serverTime - InpBrokerUtcOffsetHours * 3600;
  }

int HourOfTime(const datetime value)
  {
   MqlDateTime tm;
   TimeToStruct(value, tm);
   return tm.hour;
  }

bool HourInWindow(const int hour, const int startHour, const int endHour)
  {
   int h = (hour % 24 + 24) % 24;
   int s = (startHour % 24 + 24) % 24;
   int e = (endHour % 24 + 24) % 24;
   if(s == e)
      return true;
   if(s < e)
      return h >= s && h < e;
   return h >= s || h < e;
  }

string SessionLabelFromUtcHour(const int utcHour)
  {
   if(HourInWindow(utcHour, 13, 16))
      return "london_newyork_overlap";
   if(HourInWindow(utcHour, 7, 16))
      return "london";
   if(HourInWindow(utcHour, 13, 22))
      return "new_york";
   if(HourInWindow(utcHour, 0, 8))
      return "tokyo";
   return "other";
  }

string SessionWindowNameFromLabel(const string label)
  {
   if(label == "tokyo")
      return "tokyo_utc_00_08";
   if(label == "london")
      return "london_utc_07_16";
   if(label == "new_york")
      return "new_york_utc_13_22";
   if(label == "london_newyork_overlap")
      return "london_newyork_overlap_utc_13_16";
   return "other";
  }

string SessionLabelForServerTime(const datetime serverTime)
  {
   return SessionLabelFromUtcHour(HourOfTime(UtcFromServer(serverTime)));
  }

int SessionIndex(const string label)
  {
   if(label == "tokyo")
      return 0;
   if(label == "london")
      return 1;
   if(label == "new_york")
      return 2;
   if(label == "london_newyork_overlap")
      return 3;
   return 4;
  }

string SessionLabelByIndex(const int index)
  {
   if(index == 0)
      return "tokyo";
   if(index == 1)
      return "london";
   if(index == 2)
      return "new_york";
   if(index == 3)
      return "london_newyork_overlap";
   return "other";
  }

double TrueRangeAt(const MqlRates &rates[], const int shift)
  {
   if(shift < 0 || shift >= ArraySize(rates))
      return 0.0;
   double prevClose = (shift + 1 < ArraySize(rates)) ? rates[shift + 1].close : rates[shift].close;
   double range1 = rates[shift].high - rates[shift].low;
   double range2 = MathAbs(rates[shift].high - prevClose);
   double range3 = MathAbs(rates[shift].low - prevClose);
   return MathMax(range1, MathMax(range2, range3));
  }

void BuildSessionStats(const string symbol,
                       const datetime serverTime,
                       SessionStats &stats)
  {
   stats.label = SessionLabelForServerTime(serverTime);
   stats.windowName = SessionWindowNameFromLabel(stats.label);
   stats.rank = 5;
   stats.averageM15RangeATR = 0.0;
   stats.averageH1RangeATR = 0.0;
   stats.averageTrueRange = 0.0;
   stats.realizedVolatility = 0.0;
   stats.breakoutFollowthroughRate = 0.0;
   stats.averageSpreadATR = 0.0;
   stats.atrSessionPercentile = 0.0;

   MqlRates m15[];
   MqlRates h1[];
   int m15Bars = MathMax(InpSessionAuditLookbackBars, InpSessionRankLookbackBars);
   if(!CopyClosedRates(symbol, InpScanTF, m15Bars, m15))
      return;
   CopyClosedRates(symbol, InpFastWaveTF, MathMax(240, InpSessionRankLookbackBars / 4), h1);

   double sessionRange[5] = {0.0, 0.0, 0.0, 0.0, 0.0};
   int sessionCount[5] = {0, 0, 0, 0, 0};
   double trSum = 0.0;
   double retSum = 0.0;
   double retSqSum = 0.0;
   int retCount = 0;
   int breakoutCount = 0;
   int followCount = 0;

   int limit = MathMin(ArraySize(m15) - InpATRPeriod - 2, InpSessionRankLookbackBars);
   for(int i = 0; i < limit; ++i)
     {
      string label = SessionLabelForServerTime(m15[i].time);
      int index = SessionIndex(label);
      double atr = ATR(m15, i, InpATRPeriod);
      if(atr <= 0.0)
         continue;
      double rangeAtr = (m15[i].high - m15[i].low) / atr;
      sessionRange[index] += rangeAtr;
      sessionCount[index]++;

      if(label == stats.label)
        {
         trSum += TrueRangeAt(m15, i);
         double change = (m15[i].close - m15[i + 1].close) / atr;
         retSum += change;
         retSqSum += change * change;
         retCount++;
         bool breakoutUp = m15[i].high > m15[i + 1].high && m15[i].close > m15[i + 1].high;
         bool breakoutDown = m15[i].low < m15[i + 1].low && m15[i].close < m15[i + 1].low;
         if(breakoutUp || breakoutDown)
           {
            breakoutCount++;
            if(MathAbs(m15[i].close - m15[i].open) >= atr * 0.30)
               followCount++;
           }
        }
     }

   double currentAvg = 0.0;
   int currentIndex = SessionIndex(stats.label);
   for(int i = 0; i < 5; ++i)
     {
      if(sessionCount[i] > 0)
         sessionRange[i] /= sessionCount[i];
      if(i == currentIndex)
         currentAvg = sessionRange[i];
     }

   int rank = 1;
   for(int i = 0; i < 5; ++i)
     {
      if(i != currentIndex && sessionRange[i] > currentAvg)
         rank++;
     }
   stats.rank = rank;
   stats.averageM15RangeATR = currentAvg;
   stats.averageTrueRange = retCount > 0 ? trSum / retCount : 0.0;
   if(retCount > 1)
     {
      double mean = retSum / retCount;
      stats.realizedVolatility = MathSqrt(MathMax(0.0, retSqSum / retCount - mean * mean));
     }
   stats.breakoutFollowthroughRate = breakoutCount > 0 ? (double)followCount / breakoutCount : 0.0;
   int below = 0;
   int active = 0;
   for(int i = 0; i < 5; ++i)
     {
      if(sessionCount[i] <= 0)
         continue;
      active++;
      if(sessionRange[i] <= currentAvg)
         below++;
     }
   stats.atrSessionPercentile = active > 0 ? (double)below / active : 0.0;

   int h1Limit = MathMin(ArraySize(h1) - InpATRPeriod - 1, 240);
   double h1Sum = 0.0;
   int h1Count = 0;
   for(int i = 0; i < h1Limit; ++i)
     {
      if(SessionLabelForServerTime(h1[i].time) != stats.label)
         continue;
      double atr = ATR(h1, i, InpATRPeriod);
      if(atr <= 0.0)
         continue;
      h1Sum += (h1[i].high - h1[i].low) / atr;
      h1Count++;
     }
   stats.averageH1RangeATR = h1Count > 0 ? h1Sum / h1Count : 0.0;

   MqlTick tick;
   if(SymbolInfoTick(symbol, tick))
     {
      double atr = ATR(m15, 0, InpATRPeriod);
      if(atr > 0.0)
         stats.averageSpreadATR = (tick.ask - tick.bid) / atr;
     }
  }

bool ScenarioSessionAllowed(const string label, const int rank, const double averageRangeATR)
  {
   if(InpScenarioMode == BASELINE_ALL_SESSIONS)
      return true;
   if(InpScenarioMode == LONDON_ONLY_REFERENCE)
      return label == "london";
   if(InpScenarioMode == NEWYORK_ONLY_REFERENCE)
      return label == "new_york";
   if(InpScenarioMode == TOKYO_ONLY_REFERENCE)
      return label == "tokyo";
   if(InpScenarioMode == LONDON_NEWYORK_OVERLAP_REFERENCE)
      return label == "london_newyork_overlap";
   if(InpScenarioMode == SESSION_VOLATILITY_ONLY_FILTER ||
      InpScenarioMode == SYMBOL_BEST_SESSION ||
      InpScenarioMode == SYMBOL_BEST_SESSION_WITH_DOW_ALIGNMENT ||
      InpScenarioMode == SYMBOL_BEST_SESSION_WITH_WAVE3_CONFIRMED)
      return rank <= InpSessionRankAllowedMax && averageRangeATR >= InpSessionMinRangeATR;
   return true;
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

bool IsPivotHigh(const MqlRates &rates[], const int shift, const int depth)
  {
   if(shift < depth || shift + depth >= ArraySize(rates))
      return false;
   double value = rates[shift].high;
   for(int i = 1; i <= depth; ++i)
     {
      if(rates[shift - i].high >= value || rates[shift + i].high > value)
         return false;
     }
   return true;
  }

bool IsPivotLow(const MqlRates &rates[], const int shift, const int depth)
  {
   if(shift < depth || shift + depth >= ArraySize(rates))
      return false;
   double value = rates[shift].low;
   for(int i = 1; i <= depth; ++i)
     {
      if(rates[shift - i].low <= value || rates[shift + i].low < value)
         return false;
     }
   return true;
  }

void AddPivot(SwingPoint &pivots[], const SwingPoint &candidate)
  {
   if(!candidate.valid || candidate.atr <= 0.0)
      return;

   int size = ArraySize(pivots);
   if(size == 0)
     {
      ArrayResize(pivots, 1);
      pivots[0] = candidate;
      return;
     }

   SwingPoint last = pivots[size - 1];
   if(last.isHigh == candidate.isHigh)
     {
      bool replace = (candidate.isHigh && candidate.price > last.price) ||
                     (!candidate.isHigh && candidate.price < last.price);
      if(replace)
         pivots[size - 1] = candidate;
      return;
     }

   double moveATR = MathAbs(candidate.price - last.price) / candidate.atr;
   if(moveATR < InpMinSwingSizeATR)
      return;

   ArrayResize(pivots, size + 1);
   pivots[size] = candidate;
  }

bool ExtractConfirmedPivots(const string symbol,
                            const ENUM_TIMEFRAMES tf,
                            MqlRates &rates[],
                            SwingPoint &pivots[])
  {
   ArrayResize(pivots, 0);
   int required = MathMax(InpWaveScanBars, InpSwingDepth * 2 + InpATRPeriod + 20);
   if(!CopyClosedRates(symbol, tf, required, rates))
      return false;

   int oldest = ArraySize(rates) - InpSwingDepth - 2;
   for(int shift = oldest; shift >= InpSwingDepth; --shift)
     {
      bool high = IsPivotHigh(rates, shift, InpSwingDepth);
      bool low = IsPivotLow(rates, shift, InpSwingDepth);
      if(!high && !low)
         continue;

      double atr = ATR(rates, shift, InpATRPeriod);
      if(atr <= 0.0)
         continue;

      if(high)
        {
         SwingPoint p;
         p.valid = true;
         p.isHigh = true;
         p.shift = shift;
         p.price = rates[shift].high;
         p.time = rates[shift].time;
         p.confirmedTime = rates[MathMax(0, shift - InpSwingDepth)].time;
         p.atr = atr;
         AddPivot(pivots, p);
        }
      if(low)
        {
         SwingPoint p;
         p.valid = true;
         p.isHigh = false;
         p.shift = shift;
         p.price = rates[shift].low;
         p.time = rates[shift].time;
         p.confirmedTime = rates[MathMax(0, shift - InpSwingDepth)].time;
         p.atr = atr;
         AddPivot(pivots, p);
        }
     }

   return ArraySize(pivots) >= 3;
  }

double RSIAtShift(const MqlRates &rates[], const int shift, const int period)
  {
   if(period <= 1 || shift < 0 || shift + period + 1 >= ArraySize(rates))
      return 50.0;
   double gains = 0.0;
   double losses = 0.0;
   for(int i = shift; i < shift + period; ++i)
     {
      double change = rates[i].close - rates[i + 1].close;
      if(change > 0.0)
         gains += change;
      else
         losses += MathAbs(change);
     }
   if(losses <= 0.0)
      return 100.0;
   double rs = gains / losses;
   return 100.0 - (100.0 / (1.0 + rs));
  }

double EMAAtShift(const MqlRates &rates[], const int shift, const int period)
  {
   if(period <= 1 || shift < 0 || shift + period + 20 >= ArraySize(rates))
      return SMA(rates, shift, period);
   int start = shift + period + 20;
   double alpha = 2.0 / (period + 1.0);
   double ema = rates[start].close;
   for(int i = start - 1; i >= shift; --i)
      ema = rates[i].close * alpha + ema * (1.0 - alpha);
   return ema;
  }

double MACDLineAtShift(const MqlRates &rates[], const int shift)
  {
   return EMAAtShift(rates, shift, InpMACDFastPeriod) - EMAAtShift(rates, shift, InpMACDSlowPeriod);
  }

string DetectDivergence(const MqlRates &rates[],
                        const SwingPoint &previousExtreme,
                        const SwingPoint &latestExtreme,
                        const int direction)
  {
   if(!previousExtreme.valid || !latestExtreme.valid)
      return "none";
   double prevRsi = RSIAtShift(rates, previousExtreme.shift, InpRSIPeriod);
   double latestRsi = RSIAtShift(rates, latestExtreme.shift, InpRSIPeriod);
   double prevMacd = MACDLineAtShift(rates, previousExtreme.shift);
   double latestMacd = MACDLineAtShift(rates, latestExtreme.shift);

   if(direction > 0 && previousExtreme.isHigh && latestExtreme.isHigh &&
      latestExtreme.price > previousExtreme.price)
     {
      bool rsi = latestRsi < prevRsi;
      bool macd = latestMacd < prevMacd;
      if(rsi && macd)
         return "bearish_rsi_macd";
      if(rsi)
         return "bearish_rsi";
      if(macd)
         return "bearish_macd";
     }

   if(direction < 0 && !previousExtreme.isHigh && !latestExtreme.isHigh &&
      latestExtreme.price < previousExtreme.price)
     {
      bool rsi = latestRsi > prevRsi;
      bool macd = latestMacd > prevMacd;
      if(rsi && macd)
         return "bullish_rsi_macd";
      if(rsi)
         return "bullish_rsi";
      if(macd)
         return "bullish_macd";
     }

   return "none";
  }

string FibZone(const string setupType, const double retracement)
  {
   if(setupType == "wave3_start_pullback")
     {
      if(retracement >= 0.50 && retracement <= 0.618)
         return "wave2_50_618";
      if(retracement >= 0.382 && retracement <= 0.786)
         return "wave2_382_786";
      return "wave2_other";
     }
   if(setupType == "wave4_continuation")
     {
      if(retracement >= 0.30 && retracement <= 0.45)
         return "wave4_382";
      if(retracement > 0.0 && retracement <= 0.70)
         return "wave4_shallow";
      return "wave4_other";
     }
   if(setupType == "abc_completion_reentry")
     {
      if(retracement >= 0.50 && retracement <= 0.786)
         return "abc_50_786";
      if(retracement >= 0.382 && retracement <= 0.886)
         return "abc_382_886";
      return "abc_other";
     }
   return "none";
  }

bool IsFibConfluenceZone(const string zone)
  {
   return zone == "wave2_50_618" || zone == "wave4_382" || zone == "abc_50_786";
  }

void ResetPlan(SignalPlan &plan, const string symbol)
  {
   plan.valid = false;
   plan.symbol = symbol;
   plan.direction = "NONE";
   plan.strategy = ScenarioModeName();
   plan.setupType = "";
   plan.waveStage = "unknown";
   plan.waveTF = "";
   plan.baseCurrency = BaseCurrency(symbol);
   plan.quoteCurrency = QuoteCurrency(symbol);
   plan.serverTime = 0;
   plan.serverHour = 0;
   plan.utcHour = 0;
   plan.sessionLabel = "unknown";
   plan.sessionWindowName = "unknown";
   plan.allowedSession = true;
   plan.sessionVolatilityRank = 0;
   plan.dowRegimeH4 = "unknown";
   plan.dowRegimeH1 = "unknown";
   plan.h4Structure = "unknown";
   plan.h1Structure = "unknown";
   plan.fractalAlignment = "unknown";
   plan.fibZone = "none";
   plan.divergenceType = "none";
   plan.m15ConfirmationType = "none";
   plan.failureType = "other";
   plan.reason = "";
   plan.waveSizeATR = 0.0;
   plan.retracementRatio = 0.0;
   plan.extensionRatio = 0.0;
   plan.waveRuleValidity = "unchecked";
   plan.wave3BreakConfirmed = false;
   plan.pivotConfirmationDelayBars = InpSwingDepth;
   plan.entryDelayFromPivot = 0;
   plan.pivotTime = 0;
   plan.pivotConfirmedTime = 0;
   plan.roomTo1R = 0.0;
   plan.roomTo2R = 0.0;
   plan.entry = 0.0;
   plan.stopLoss = 0.0;
   plan.takeProfit = 0.0;
   plan.riskPrice = 0.0;
   plan.rewardR = InpRewardR;
   plan.atr = 0.0;
   plan.spreadPoints = 0.0;
   plan.spreadATR = 0.0;
   plan.atrSessionPercentile = 0.0;
   plan.averageM15RangeATR = 0.0;
   plan.averageH1RangeATR = 0.0;
   plan.averageTrueRange = 0.0;
   plan.realizedVolatility = 0.0;
   plan.breakoutFollowthroughRate = 0.0;
   plan.averageSpreadATR = 0.0;
   plan.score = 0.0;
  }

bool LastPivotSequence(const SwingPoint &pivots[],
                       const bool &types[],
                       const int count,
                       SwingPoint &out[])
  {
   int size = ArraySize(pivots);
   if(size < count)
      return false;
   ArrayResize(out, count);
   int start = size - count;
   for(int i = 0; i < count; ++i)
     {
      out[i] = pivots[start + i];
      if(out[i].isHigh != types[i])
         return false;
     }
   return true;
  }

bool LastTwoExtremes(const SwingPoint &pivots[],
                     const bool wantHigh,
                     SwingPoint &older,
                     SwingPoint &latest)
  {
   int found = 0;
   for(int i = ArraySize(pivots) - 1; i >= 0; --i)
     {
      if(pivots[i].isHigh != wantHigh)
         continue;
      if(found == 0)
        {
         latest = pivots[i];
         found++;
        }
      else
        {
         older = pivots[i];
         return true;
        }
     }
   return false;
  }

string StructureLabelFromPivots(const SwingPoint &pivots[])
  {
   SwingPoint highOlder, highLatest, lowOlder, lowLatest;
   if(!LastTwoExtremes(pivots, true, highOlder, highLatest) ||
      !LastTwoExtremes(pivots, false, lowOlder, lowLatest))
      return "insufficient_fractals";

   bool hh = highLatest.price > highOlder.price;
   bool hl = lowLatest.price > lowOlder.price;
   bool lh = highLatest.price < highOlder.price;
   bool ll = lowLatest.price < lowOlder.price;
   if(hh && hl)
      return "HH_HL";
   if(lh && ll)
      return "LH_LL";
   if(hh && ll)
      return "expanding_transition";
   if(lh && hl)
      return "compression_range";
   return "mixed";
  }

string DowRegimeFromStructure(const string structure,
                              const double currentClose,
                              const SwingPoint &highLatest,
                              const SwingPoint &lowLatest)
  {
   if(structure == "HH_HL")
      return "trend_up";
   if(structure == "LH_LL")
      return "trend_down";
   if(structure == "compression_range")
      return "range";
   if(highLatest.valid && currentClose > highLatest.price - highLatest.atr * InpDowTransitionATR)
      return "transition_up";
   if(lowLatest.valid && currentClose < lowLatest.price + lowLatest.atr * InpDowTransitionATR)
      return "transition_down";
   return "range";
  }

bool GetDowContext(const string symbol,
                   const ENUM_TIMEFRAMES tf,
                   string &regime,
                   string &structure)
  {
   MqlRates rates[];
   SwingPoint pivots[];
   regime = "unknown";
   structure = "unknown";
   if(!ExtractConfirmedPivots(symbol, tf, rates, pivots))
      return false;
   structure = StructureLabelFromPivots(pivots);
   SwingPoint highOlder, highLatest, lowOlder, lowLatest;
   if(!LastTwoExtremes(pivots, true, highOlder, highLatest) ||
      !LastTwoExtremes(pivots, false, lowOlder, lowLatest))
      return false;
   regime = DowRegimeFromStructure(structure, rates[0].close, highLatest, lowLatest);
   return true;
  }

bool DowAllowsDirection(const string regimeH4,
                        const string regimeH1,
                        const int direction,
                        const bool strictAlignment)
  {
   if(direction > 0)
     {
      if(regimeH4 == "trend_down" || regimeH4 == "transition_down" ||
         regimeH1 == "trend_down" || regimeH1 == "transition_down")
         return false;
      if(strictAlignment)
         return (regimeH4 == "trend_up" || regimeH4 == "transition_up") &&
                (regimeH1 == "trend_up" || regimeH1 == "transition_up" || regimeH1 == "range");
      return true;
     }

   if(regimeH4 == "trend_up" || regimeH4 == "transition_up" ||
      regimeH1 == "trend_up" || regimeH1 == "transition_up")
      return false;
   if(strictAlignment)
      return (regimeH4 == "trend_down" || regimeH4 == "transition_down") &&
             (regimeH1 == "trend_down" || regimeH1 == "transition_down" || regimeH1 == "range");
   return true;
  }

string FractalAlignmentForPlan(const SignalPlan &plan)
  {
   if(plan.direction != "LONG" && plan.direction != "SHORT")
      return "unknown";

   MqlRates rates[];
   SwingPoint pivots[];
   if(!ExtractConfirmedPivots(plan.symbol, InpFastWaveTF, rates, pivots))
      return "unknown";

   bool wantHigh = plan.direction == "SHORT";
   SwingPoint latest;
   latest.valid = false;
   for(int i = ArraySize(pivots) - 1; i >= 0; --i)
     {
      if(pivots[i].isHigh == wantHigh)
        {
         latest = pivots[i];
         break;
        }
     }
   if(!latest.valid || latest.atr <= 0.0)
      return "unknown";

   double distanceATR = MathAbs(plan.entry - latest.price) / latest.atr;
   if(distanceATR <= InpFractalAlignmentATR)
      return "fractal_aligned";
   return "fractal_misaligned";
  }

int DirectionSign(const string direction)
  {
   if(direction == "LONG")
      return 1;
   if(direction == "SHORT")
      return -1;
   return 0;
  }

string M15Confirmation(const int direction, const MqlRates &scan[])
  {
   double atr = ATR(scan, 0, InpATRPeriod);
   double fast0 = SMA(scan, 0, InpScanFastMAPeriod);
   double fast1 = SMA(scan, 1, InpScanFastMAPeriod);
   double slow0 = SMA(scan, 0, InpScanSlowMAPeriod);
   double body = MathAbs(scan[0].close - scan[0].open);

   if(direction > 0)
     {
      if(scan[0].close > fast0 && scan[1].close <= fast1)
         return "ma_reclaim";
      if(scan[0].close > HighestHigh(scan, 1, InpMicroBosLookbackBars))
         return "micro_bos";
      if(scan[0].close > scan[0].open && body >= atr * InpCandleBodyATR && scan[0].close > slow0)
         return "candle_reversal";
     }
   else
     {
      if(scan[0].close < fast0 && scan[1].close >= fast1)
         return "ma_reclaim";
      if(scan[0].close < LowestLow(scan, 1, InpMicroBosLookbackBars))
         return "micro_bos";
      if(scan[0].close < scan[0].open && body >= atr * InpCandleBodyATR && scan[0].close < slow0)
         return "candle_reversal";
     }

   return "none";
  }

bool FillTradeLevels(SignalPlan &plan,
                     const int direction,
                     const double structureStop,
                     const MqlRates &scan[],
                     const MqlRates &h1[])
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
   plan.spreadATR = (tick.ask - tick.bid) / plan.atr;
   if(plan.spreadATR > InpMaxSpreadATR)
     {
      plan.reason = "spread_atr_guard";
      return false;
     }

   int stopsLevel = (int)SymbolInfoInteger(plan.symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStop = MathMax(plan.atr * InpMinSL_ATR, (stopsLevel + 2) * point);

   if(direction > 0)
     {
      plan.direction = "LONG";
      plan.entry = tick.ask;
      plan.stopLoss = MathMin(structureStop, plan.entry - minStop);
      plan.riskPrice = plan.entry - plan.stopLoss;
      if(plan.riskPrice > plan.atr * InpMaxSL_ATR)
        {
         plan.reason = "stop_too_wide";
         return false;
        }
      plan.takeProfit = plan.entry + plan.riskPrice * InpRewardR;
     }
   else
     {
      plan.direction = "SHORT";
      plan.entry = tick.bid;
      plan.stopLoss = MathMax(structureStop, plan.entry + minStop);
      plan.riskPrice = plan.stopLoss - plan.entry;
      if(plan.riskPrice > plan.atr * InpMaxSL_ATR)
        {
         plan.reason = "stop_too_wide";
         return false;
        }
      plan.takeProfit = plan.entry - plan.riskPrice * InpRewardR;
     }

   plan.entry = NormalizeDouble(plan.entry, digits);
   plan.stopLoss = NormalizeDouble(plan.stopLoss, digits);
   plan.takeProfit = NormalizeDouble(plan.takeProfit, digits);
   plan.riskPrice = MathAbs(plan.entry - plan.stopLoss);
   if(plan.riskPrice <= 0.0)
      return false;

   double obstacleDistance = 0.0;
   if(direction > 0)
      obstacleDistance = MathMax(0.0, HighestHigh(h1, 1, InpObstacleLookbackBars) - plan.entry);
   else
      obstacleDistance = MathMax(0.0, plan.entry - LowestLow(h1, 1, InpObstacleLookbackBars));

   plan.roomTo1R = obstacleDistance / plan.riskPrice;
   plan.roomTo2R = obstacleDistance / plan.riskPrice;
   if(plan.roomTo2R < 2.0)
      plan.failureType = "target_blocked";
   return true;
  }

void ApplyCommonPlanFields(SignalPlan &plan,
                           const ENUM_TIMEFRAMES tf,
                           const SwingPoint &latestPivot)
  {
   plan.waveTF = TFName(tf);
   plan.pivotConfirmationDelayBars = InpSwingDepth;
   plan.entryDelayFromPivot = latestPivot.shift;
   plan.pivotTime = latestPivot.time;
   plan.pivotConfirmedTime = latestPivot.confirmedTime;
   plan.atr = latestPivot.atr;
  }

bool BuildWave3Plan(const string symbol,
                    const ENUM_TIMEFRAMES tf,
                    const MqlRates &waveRates[],
                    const SwingPoint &pivots[],
                    const MqlRates &scan[],
                    const MqlRates &h1[],
                    const int direction,
                    SignalPlan &plan)
  {
   bool longTypes[3] = {false, true, false};
   bool shortTypes[3] = {true, false, true};
   SwingPoint seq[];
   if(direction > 0)
     {
      if(!LastPivotSequence(pivots, longTypes, 3, seq))
         return false;
     }
   else
     {
      if(!LastPivotSequence(pivots, shortTypes, 3, seq))
         return false;
     }

   ResetPlan(plan, symbol);
   plan.setupType = "wave3_start_pullback";
   plan.waveStage = "possible_wave3_start";
   ApplyCommonPlanFields(plan, tf, seq[2]);

   double wave1 = MathAbs(seq[1].price - seq[0].price);
   double wave2 = MathAbs(seq[2].price - seq[1].price);
   if(wave1 <= 0.0 || seq[2].atr <= 0.0)
      return false;

   plan.waveSizeATR = wave1 / seq[2].atr;
   plan.retracementRatio = wave2 / wave1;
   plan.extensionRatio = MathAbs(waveRates[0].close - seq[2].price) / wave1;
   plan.fibZone = FibZone(plan.setupType, plan.retracementRatio);

   bool noBreak = direction > 0 ? seq[2].price > seq[0].price : seq[2].price < seq[0].price;
   if(!noBreak || plan.retracementRatio < InpWave2MinRetrace || plan.retracementRatio > InpWave2MaxRetrace)
     {
      plan.waveStage = "invalid_count";
      plan.waveRuleValidity = "wave2_invalid";
      return false;
     }

   plan.wave3BreakConfirmed = direction > 0 ? waveRates[0].close > seq[1].price : waveRates[0].close < seq[1].price;
   plan.waveRuleValidity = "valid_wave2";
   plan.m15ConfirmationType = M15Confirmation(direction, scan);
   if(plan.m15ConfirmationType == "none")
     {
      plan.failureType = "m15_confirmation_failed";
      plan.reason = "m15_confirmation_missing";
      return false;
     }

   double stop = direction > 0 ? seq[2].price - seq[2].atr * InpSLBufferATR
                               : seq[2].price + seq[2].atr * InpSLBufferATR;
   if(!FillTradeLevels(plan, direction, stop, scan, h1))
      return false;

   plan.divergenceType = "none";
   plan.score = 1.0 + (IsFibConfluenceZone(plan.fibZone) ? 0.35 : 0.0) +
                (plan.wave3BreakConfirmed ? 0.20 : 0.0) + MathMin(plan.roomTo2R, 3.0) * 0.05;
   plan.valid = true;
   return true;
  }

bool BuildWave4Plan(const string symbol,
                    const ENUM_TIMEFRAMES tf,
                    const MqlRates &waveRates[],
                    const SwingPoint &pivots[],
                    const MqlRates &scan[],
                    const MqlRates &h1[],
                    const int direction,
                    SignalPlan &plan)
  {
   bool longTypes[5] = {false, true, false, true, false};
   bool shortTypes[5] = {true, false, true, false, true};
   SwingPoint seq[];
   if(direction > 0)
     {
      if(!LastPivotSequence(pivots, longTypes, 5, seq))
         return false;
     }
   else
     {
      if(!LastPivotSequence(pivots, shortTypes, 5, seq))
         return false;
     }

   ResetPlan(plan, symbol);
   plan.setupType = "wave4_continuation";
   plan.waveStage = "possible_wave4_pullback";
   ApplyCommonPlanFields(plan, tf, seq[4]);

   double wave1 = MathAbs(seq[1].price - seq[0].price);
   double wave3 = MathAbs(seq[3].price - seq[2].price);
   double wave4 = MathAbs(seq[4].price - seq[3].price);
   if(wave1 <= 0.0 || wave3 <= 0.0 || seq[4].atr <= 0.0)
      return false;

   plan.waveSizeATR = wave3 / seq[4].atr;
   plan.retracementRatio = wave4 / wave3;
   plan.extensionRatio = wave3 / wave1;
   plan.fibZone = FibZone(plan.setupType, plan.retracementRatio);
   plan.wave3BreakConfirmed = direction > 0 ? seq[3].price > seq[1].price : seq[3].price < seq[1].price;

   bool wave3NotShortest = wave3 >= wave1 * InpWave3MinVsWave1;
   bool wave4NotDeep = plan.retracementRatio > 0.0 && plan.retracementRatio <= InpWave4MaxRetrace;
   bool noDeepOverlap = direction > 0 ? seq[4].price > seq[1].price - seq[4].atr * InpWave4MaxOverlapATR
                                      : seq[4].price < seq[1].price + seq[4].atr * InpWave4MaxOverlapATR;
   if(!plan.wave3BreakConfirmed || !wave3NotShortest || !wave4NotDeep || !noDeepOverlap)
     {
      plan.waveStage = "invalid_count";
      plan.waveRuleValidity = "wave4_invalid";
      return false;
     }

   plan.waveRuleValidity = "valid_wave4";
   plan.m15ConfirmationType = M15Confirmation(direction, scan);
   if(plan.m15ConfirmationType == "none")
     {
      plan.failureType = "m15_confirmation_failed";
      plan.reason = "m15_confirmation_missing";
      return false;
     }

   plan.divergenceType = DetectDivergence(waveRates, seq[1], seq[3], direction);
   double stop = direction > 0 ? seq[4].price - seq[4].atr * InpSLBufferATR
                               : seq[4].price + seq[4].atr * InpSLBufferATR;
   if(!FillTradeLevels(plan, direction, stop, scan, h1))
      return false;

   plan.score = 0.9 + (IsFibConfluenceZone(plan.fibZone) ? 0.30 : 0.0) +
                (plan.divergenceType == "none" ? 0.15 : -0.10) + MathMin(plan.roomTo2R, 3.0) * 0.05;
   plan.valid = true;
   return true;
  }

bool BuildABCPlan(const string symbol,
                  const ENUM_TIMEFRAMES tf,
                  const MqlRates &waveRates[],
                  const SwingPoint &pivots[],
                  const MqlRates &scan[],
                  const MqlRates &h1[],
                  const int direction,
                  SignalPlan &plan)
  {
   bool longTypes[5] = {false, true, false, true, false};
   bool shortTypes[5] = {true, false, true, false, true};
   SwingPoint seq[];
   if(direction > 0)
     {
      if(!LastPivotSequence(pivots, longTypes, 5, seq))
         return false;
     }
   else
     {
      if(!LastPivotSequence(pivots, shortTypes, 5, seq))
         return false;
     }

   ResetPlan(plan, symbol);
   plan.setupType = "abc_completion_reentry";
   plan.waveStage = "possible_abc_completion";
   ApplyCommonPlanFields(plan, tf, seq[4]);

   double impulse = MathAbs(seq[1].price - seq[0].price);
   double correction = MathAbs(seq[4].price - seq[1].price);
   if(impulse <= 0.0 || seq[4].atr <= 0.0)
      return false;

   plan.waveSizeATR = impulse / seq[4].atr;
   plan.retracementRatio = correction / impulse;
   plan.extensionRatio = MathAbs(seq[4].price - seq[2].price) / MathMax(MathAbs(seq[2].price - seq[1].price), seq[4].atr);
   plan.fibZone = FibZone(plan.setupType, plan.retracementRatio);
   plan.wave3BreakConfirmed = false;

   bool cBeyondA = direction > 0 ? seq[4].price <= seq[2].price : seq[4].price >= seq[2].price;
   bool notBrokenImpulseStart = direction > 0 ? seq[4].price > seq[0].price : seq[4].price < seq[0].price;
   if(!cBeyondA || !notBrokenImpulseStart || plan.retracementRatio < 0.30 || plan.retracementRatio > 0.95)
     {
      plan.waveStage = "invalid_count";
      plan.waveRuleValidity = "abc_invalid";
      return false;
     }

   plan.waveRuleValidity = "valid_abc";
   plan.m15ConfirmationType = M15Confirmation(direction, scan);
   if(plan.m15ConfirmationType == "none")
     {
      plan.failureType = "m15_confirmation_failed";
      plan.reason = "m15_confirmation_missing";
      return false;
     }

   plan.divergenceType = DetectDivergence(waveRates, seq[1], seq[3], direction);
   double stop = direction > 0 ? seq[4].price - seq[4].atr * InpSLBufferATR
                               : seq[4].price + seq[4].atr * InpSLBufferATR;
   if(!FillTradeLevels(plan, direction, stop, scan, h1))
      return false;

   plan.score = 0.8 + (IsFibConfluenceZone(plan.fibZone) ? 0.35 : 0.0) +
                (plan.divergenceType != "none" ? 0.15 : 0.0) + MathMin(plan.roomTo2R, 3.0) * 0.05;
   plan.valid = true;
   return true;
  }

bool BuildWave5DiagnosticPlan(const string symbol,
                              const ENUM_TIMEFRAMES tf,
                              const MqlRates &waveRates[],
                              const SwingPoint &pivots[],
                              const MqlRates &scan[],
                              const int direction,
                              SignalPlan &plan)
  {
   bool longTypes[6] = {false, true, false, true, false, true};
   bool shortTypes[6] = {true, false, true, false, true, false};
   SwingPoint seq[];
   if(direction > 0)
     {
      if(!LastPivotSequence(pivots, longTypes, 6, seq))
         return false;
     }
   else
     {
      if(!LastPivotSequence(pivots, shortTypes, 6, seq))
         return false;
     }

   ResetPlan(plan, symbol);
   plan.setupType = "wave5_exhaustion_reversal_reference";
   plan.waveStage = "possible_wave5_exhaustion";
   ApplyCommonPlanFields(plan, tf, seq[5]);

   double wave1 = MathAbs(seq[1].price - seq[0].price);
   double wave2 = MathAbs(seq[2].price - seq[1].price);
   double wave3 = MathAbs(seq[3].price - seq[2].price);
   double wave4 = MathAbs(seq[4].price - seq[3].price);
   double wave5 = MathAbs(seq[5].price - seq[4].price);
   if(wave1 <= 0.0 || wave3 <= 0.0 || wave5 <= 0.0 || seq[5].atr <= 0.0)
      return false;

   plan.waveSizeATR = wave5 / seq[5].atr;
   plan.retracementRatio = wave4 / wave3;
   plan.extensionRatio = wave5 / wave1;
   plan.fibZone = "wave5_reference";
   plan.wave3BreakConfirmed = direction > 0 ? seq[3].price > seq[1].price : seq[3].price < seq[1].price;

   bool wave2NoBreak = direction > 0 ? seq[2].price > seq[0].price : seq[2].price < seq[0].price;
   bool wave3NotShortest = wave3 >= MathMin(wave1, wave5) * InpWave3MinVsWave1;
   bool wave4NotDeep = plan.retracementRatio > 0.0 && plan.retracementRatio <= InpWave4MaxRetrace;
   bool noDeepOverlap = direction > 0 ? seq[4].price > seq[1].price - seq[4].atr * InpWave4MaxOverlapATR
                                      : seq[4].price < seq[1].price + seq[4].atr * InpWave4MaxOverlapATR;
   if(!wave2NoBreak || !plan.wave3BreakConfirmed || !wave3NotShortest || !wave4NotDeep || !noDeepOverlap)
      return false;

   plan.divergenceType = DetectDivergence(waveRates, seq[3], seq[5], direction);
   if(plan.divergenceType == "none")
      return false;

   MqlTick tick;
   if(SymbolInfoTick(symbol, tick))
     {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point > 0.0)
         plan.spreadPoints = (tick.ask - tick.bid) / point;
      plan.entry = direction > 0 ? tick.ask : tick.bid;
     }

   plan.direction = direction > 0 ? "LONG" : "SHORT";
   plan.waveRuleValidity = "valid_wave5_exhaustion";
   plan.m15ConfirmationType = M15Confirmation(-direction, scan);
   plan.failureType = "wave5_exhaustion_divergence_avoid";
   plan.reason = "avoid_continuation_chase";
   plan.score = 0.5 + MathMin(plan.waveSizeATR, 5.0) * 0.05 +
                (plan.m15ConfirmationType == "none" ? 0.0 : 0.15);
   plan.valid = true;
   return true;
  }

void LogWave5Diagnostics(const string symbol)
  {
   MqlRates scan[];
   int requiredScan = MathMax(InpScanSlowMAPeriod + InpMicroBosLookbackBars + InpATRPeriod + 10, 80);
   if(!CopyClosedRates(symbol, InpScanTF, requiredScan, scan))
      return;

   ENUM_TIMEFRAMES timeframes[2] = {InpFastWaveTF, InpSlowWaveTF};
   for(int tfIndex = 0; tfIndex < 2; ++tfIndex)
     {
      MqlRates waveRates[];
      SwingPoint pivots[];
      if(!ExtractConfirmedPivots(symbol, timeframes[tfIndex], waveRates, pivots))
         continue;

      for(int direction = -1; direction <= 1; direction += 2)
        {
         SignalPlan diagnostic;
         if(BuildWave5DiagnosticPlan(symbol, timeframes[tfIndex], waveRates, pivots, scan, direction, diagnostic))
           {
            EnrichPlanContext(diagnostic);
            WriteSignalRow(diagnostic, "diagnostic");
           }
        }
     }
  }

bool BuildCandidateForTF(const string symbol,
                         const ENUM_TIMEFRAMES tf,
                         const MqlRates &scan[],
                         const MqlRates &h1[],
                         SignalPlan &best)
  {
   MqlRates waveRates[];
   SwingPoint pivots[];
   if(!ExtractConfirmedPivots(symbol, tf, waveRates, pivots))
      return false;

   bool found = false;
   SignalPlan candidate;
   for(int direction = -1; direction <= 1; direction += 2)
     {
      if(BuildWave3Plan(symbol, tf, waveRates, pivots, scan, h1, direction, candidate))
        {
         if(!found || candidate.score > best.score)
           {
            best = candidate;
            found = true;
           }
        }

      if(BuildWave4Plan(symbol, tf, waveRates, pivots, scan, h1, direction, candidate))
        {
         if(!found || candidate.score > best.score)
           {
            best = candidate;
            found = true;
           }
        }

      if(BuildABCPlan(symbol, tf, waveRates, pivots, scan, h1, direction, candidate))
        {
         if(!found || candidate.score > best.score)
           {
            best = candidate;
            found = true;
           }
        }
     }

   return found;
  }

bool BuildRoadmapSignal(const string symbol, SignalPlan &plan)
  {
   ResetPlan(plan, symbol);

   MqlRates scan[];
   MqlRates h1[];
   int requiredScan = MathMax(InpScanSlowMAPeriod + InpMicroBosLookbackBars + InpATRPeriod + 10, 80);
   int requiredH1 = MathMax(InpObstacleLookbackBars + InpATRPeriod + 10, 90);
   if(!CopyClosedRates(symbol, InpScanTF, requiredScan, scan) ||
      !CopyClosedRates(symbol, InpFastWaveTF, requiredH1, h1))
     {
      plan.reason = "rates_unavailable";
      return false;
     }

   SignalPlan best;
   ResetPlan(best, symbol);
   bool found = BuildCandidateForTF(symbol, InpFastWaveTF, scan, h1, best);

   SignalPlan slowBest;
   ResetPlan(slowBest, symbol);
   if(BuildCandidateForTF(symbol, InpSlowWaveTF, scan, h1, slowBest))
     {
      if(!found || slowBest.score > best.score)
        {
         best = slowBest;
         found = true;
        }
     }

   if(!found)
      return false;

   plan = best;
   EnrichPlanContext(plan);
   plan.valid = true;
   return true;
  }

void EnrichPlanContext(SignalPlan &plan)
  {
   plan.strategy = RESEARCH_STRATEGY_NAME;
   plan.serverTime = TimeCurrent();
   plan.serverHour = HourOfTime(plan.serverTime);
   plan.utcHour = HourOfTime(UtcFromServer(plan.serverTime));

   SessionStats sessionStats;
   BuildSessionStats(plan.symbol, plan.serverTime, sessionStats);
   plan.sessionLabel = sessionStats.label;
   plan.sessionWindowName = sessionStats.windowName;
   plan.sessionVolatilityRank = sessionStats.rank;
   plan.averageM15RangeATR = sessionStats.averageM15RangeATR;
   plan.averageH1RangeATR = sessionStats.averageH1RangeATR;
   plan.averageTrueRange = sessionStats.averageTrueRange;
   plan.realizedVolatility = sessionStats.realizedVolatility;
   plan.breakoutFollowthroughRate = sessionStats.breakoutFollowthroughRate;
   plan.averageSpreadATR = sessionStats.averageSpreadATR;
   plan.atrSessionPercentile = sessionStats.atrSessionPercentile;
   plan.allowedSession = ScenarioSessionAllowed(plan.sessionLabel, plan.sessionVolatilityRank, plan.averageM15RangeATR);

   GetDowContext(plan.symbol, InpSlowWaveTF, plan.dowRegimeH4, plan.h4Structure);
   GetDowContext(plan.symbol, InpFastWaveTF, plan.dowRegimeH1, plan.h1Structure);
   plan.fractalAlignment = FractalAlignmentForPlan(plan);
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

string CsvEscape(string value)
  {
   StringReplace(value, "\"", "\"\"");
   if(StringFind(value, ",") >= 0 || StringFind(value, "\"") >= 0 ||
      StringFind(value, "\r") >= 0 || StringFind(value, "\n") >= 0)
      return "\"" + value + "\"";
   return value;
  }

void CsvAdd(string &line, const string value)
  {
   if(line != "")
      line += ",";
   line += CsvEscape(value);
  }

void CsvWriteLine(const int handle, const string line)
  {
   FileWriteString(handle, line + "\r\n");
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
      CsvWriteLine(handle, "time,event,strategy,scenario_mode,symbol,direction,base_currency,quote_currency,server_time,server_hour,utc_hour,session_label,session_window_name,allowed_session,session_volatility_rank,dow_regime_h4,dow_regime_h1,h4_structure,h1_structure,fractal_alignment,wave_stage,setup_type,wave_tf,fib_zone,divergence_type,m15_confirmation_type,failure_type,reason,wave_size_atr,retracement_ratio,extension_ratio,wave_rule_validity,wave3_break_confirmed,pivot_confirmation_delay_bars,entry_delay_from_pivot,pivot_time,pivot_confirmed_time,room_to_1r,room_to_2r,entry,stop_loss,take_profit,risk_price,reward_r,atr,spread_points,spread_atr,atr_session_percentile,average_m15_range_atr,average_h1_range_atr,average_true_range,realized_volatility,breakout_followthrough_rate,average_spread_atr,score");

   string line = "";
   CsvAdd(line, TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
   CsvAdd(line, eventName);
   CsvAdd(line, plan.strategy);
   CsvAdd(line, ScenarioModeName());
   CsvAdd(line, plan.symbol);
   CsvAdd(line, plan.direction);
   CsvAdd(line, plan.baseCurrency);
   CsvAdd(line, plan.quoteCurrency);
   CsvAdd(line, TimeToString(plan.serverTime, TIME_DATE | TIME_SECONDS));
   CsvAdd(line, IntegerToString(plan.serverHour));
   CsvAdd(line, IntegerToString(plan.utcHour));
   CsvAdd(line, plan.sessionLabel);
   CsvAdd(line, plan.sessionWindowName);
   CsvAdd(line, BoolText(plan.allowedSession));
   CsvAdd(line, IntegerToString(plan.sessionVolatilityRank));
   CsvAdd(line, plan.dowRegimeH4);
   CsvAdd(line, plan.dowRegimeH1);
   CsvAdd(line, plan.h4Structure);
   CsvAdd(line, plan.h1Structure);
   CsvAdd(line, plan.fractalAlignment);
   CsvAdd(line, plan.waveStage);
   CsvAdd(line, plan.setupType);
   CsvAdd(line, plan.waveTF);
   CsvAdd(line, plan.fibZone);
   CsvAdd(line, plan.divergenceType);
   CsvAdd(line, plan.m15ConfirmationType);
   CsvAdd(line, plan.failureType);
   CsvAdd(line, plan.reason);
   CsvAdd(line, DoubleToString(plan.waveSizeATR, 4));
   CsvAdd(line, DoubleToString(plan.retracementRatio, 4));
   CsvAdd(line, DoubleToString(plan.extensionRatio, 4));
   CsvAdd(line, plan.waveRuleValidity);
   CsvAdd(line, BoolText(plan.wave3BreakConfirmed));
   CsvAdd(line, IntegerToString(plan.pivotConfirmationDelayBars));
   CsvAdd(line, IntegerToString(plan.entryDelayFromPivot));
   CsvAdd(line, TimeToString(plan.pivotTime, TIME_DATE | TIME_SECONDS));
   CsvAdd(line, TimeToString(plan.pivotConfirmedTime, TIME_DATE | TIME_SECONDS));
   CsvAdd(line, DoubleToString(plan.roomTo1R, 4));
   CsvAdd(line, DoubleToString(plan.roomTo2R, 4));
   CsvAdd(line, DoubleToString(plan.entry, 8));
   CsvAdd(line, DoubleToString(plan.stopLoss, 8));
   CsvAdd(line, DoubleToString(plan.takeProfit, 8));
   CsvAdd(line, DoubleToString(plan.riskPrice, 8));
   CsvAdd(line, DoubleToString(plan.rewardR, 3));
   CsvAdd(line, DoubleToString(plan.atr, 8));
   CsvAdd(line, DoubleToString(plan.spreadPoints, 2));
   CsvAdd(line, DoubleToString(plan.spreadATR, 6));
   CsvAdd(line, DoubleToString(plan.atrSessionPercentile, 4));
   CsvAdd(line, DoubleToString(plan.averageM15RangeATR, 4));
   CsvAdd(line, DoubleToString(plan.averageH1RangeATR, 4));
   CsvAdd(line, DoubleToString(plan.averageTrueRange, 8));
   CsvAdd(line, DoubleToString(plan.realizedVolatility, 6));
   CsvAdd(line, DoubleToString(plan.breakoutFollowthroughRate, 4));
   CsvAdd(line, DoubleToString(plan.averageSpreadATR, 6));
   CsvAdd(line, DoubleToString(plan.score, 4));
   CsvWriteLine(handle, line);
   FileClose(handle);
  }

string ClassifyFailure(const TrackedTrade &tracked, const string exitReason, const double resultR)
  {
   if(resultR > 0.0)
      return "other";
   if(!tracked.allowedSession)
      return "low_vol_session_noise";
   if(!DowAllowsDirection(tracked.dowRegimeH4, tracked.dowRegimeH1, tracked.direction == "LONG" ? 1 : -1, false))
      return "dow_misaligned";
   if(tracked.fractalAlignment != "fractal_aligned")
      return "fractal_misaligned";
   if(!tracked.wave3BreakConfirmed && tracked.setupType == "wave3_start_pullback")
      return "wave3_unconfirmed_too_early";
   if(tracked.divergenceType != "none" && tracked.setupType == "wave4_continuation")
      return "wave4_chase";
   if(tracked.setupType == "abc_completion_reentry" && !IsFibConfluenceZone(tracked.fibZone))
      return "abc_not_complete";
   if(tracked.roomTo2R < 2.0)
      return "target_blocked";
   if(!IsFibConfluenceZone(tracked.fibZone))
      return "fib_not_aligned";
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
      CsvWriteLine(handle, "entry_time,exit_time,strategy,scenario_mode,symbol,direction,base_currency,quote_currency,server_time,server_hour,utc_hour,session_label,session_window_name,allowed_session,session_volatility_rank,dow_regime_h4,dow_regime_h1,h4_structure,h1_structure,fractal_alignment,wave_stage,setup_type,wave_tf,fib_zone,divergence_type,m15_confirmation_type,failure_type,wave_size_atr,retracement_ratio,extension_ratio,wave_rule_validity,wave3_break_confirmed,pivot_confirmation_delay_bars,entry_delay_from_pivot,pivot_time,pivot_confirmed_time,room_to_1r,room_to_2r,entry,exit,stop_loss,take_profit,risk_price,result_r,profit,commission,swap,net_profit,volume,reward_r,holding_bars,atr,spread_points,spread_atr,atr_session_percentile,average_m15_range_atr,average_h1_range_atr,average_true_range,realized_volatility,breakout_followthrough_rate,average_spread_atr,score,exit_reason,position_id");

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
   string line = "";
   CsvAdd(line, TimeToString(tracked.entryTime, TIME_DATE | TIME_SECONDS));
   CsvAdd(line, TimeToString(exitTime, TIME_DATE | TIME_SECONDS));
   CsvAdd(line, tracked.strategy);
   CsvAdd(line, ScenarioModeName());
   CsvAdd(line, tracked.symbol);
   CsvAdd(line, tracked.direction);
   CsvAdd(line, tracked.baseCurrency);
   CsvAdd(line, tracked.quoteCurrency);
   CsvAdd(line, TimeToString(tracked.serverTime, TIME_DATE | TIME_SECONDS));
   CsvAdd(line, IntegerToString(tracked.serverHour));
   CsvAdd(line, IntegerToString(tracked.utcHour));
   CsvAdd(line, tracked.sessionLabel);
   CsvAdd(line, tracked.sessionWindowName);
   CsvAdd(line, BoolText(tracked.allowedSession));
   CsvAdd(line, IntegerToString(tracked.sessionVolatilityRank));
   CsvAdd(line, tracked.dowRegimeH4);
   CsvAdd(line, tracked.dowRegimeH1);
   CsvAdd(line, tracked.h4Structure);
   CsvAdd(line, tracked.h1Structure);
   CsvAdd(line, tracked.fractalAlignment);
   CsvAdd(line, tracked.waveStage);
   CsvAdd(line, tracked.setupType);
   CsvAdd(line, tracked.waveTF);
   CsvAdd(line, tracked.fibZone);
   CsvAdd(line, tracked.divergenceType);
   CsvAdd(line, tracked.m15ConfirmationType);
   CsvAdd(line, failureType);
   CsvAdd(line, DoubleToString(tracked.waveSizeATR, 4));
   CsvAdd(line, DoubleToString(tracked.retracementRatio, 4));
   CsvAdd(line, DoubleToString(tracked.extensionRatio, 4));
   CsvAdd(line, tracked.waveRuleValidity);
   CsvAdd(line, BoolText(tracked.wave3BreakConfirmed));
   CsvAdd(line, IntegerToString(tracked.pivotConfirmationDelayBars));
   CsvAdd(line, IntegerToString(tracked.entryDelayFromPivot));
   CsvAdd(line, TimeToString(tracked.pivotTime, TIME_DATE | TIME_SECONDS));
   CsvAdd(line, TimeToString(tracked.pivotConfirmedTime, TIME_DATE | TIME_SECONDS));
   CsvAdd(line, DoubleToString(tracked.roomTo1R, 4));
   CsvAdd(line, DoubleToString(tracked.roomTo2R, 4));
   CsvAdd(line, DoubleToString(tracked.entryPrice, 8));
   CsvAdd(line, DoubleToString(exitPrice, 8));
   CsvAdd(line, DoubleToString(tracked.stopLoss, 8));
   CsvAdd(line, DoubleToString(tracked.takeProfit, 8));
   CsvAdd(line, DoubleToString(tracked.riskPrice, 8));
   CsvAdd(line, DoubleToString(resultR, 4));
   CsvAdd(line, DoubleToString(profit, 2));
   CsvAdd(line, DoubleToString(commission, 2));
   CsvAdd(line, DoubleToString(swap, 2));
   CsvAdd(line, DoubleToString(netProfit, 2));
   CsvAdd(line, DoubleToString(tracked.volume, 3));
   CsvAdd(line, DoubleToString(tracked.rewardR, 3));
   CsvAdd(line, IntegerToString(holdingBars));
   CsvAdd(line, DoubleToString(tracked.atr, 8));
   CsvAdd(line, DoubleToString(tracked.spreadPoints, 2));
   CsvAdd(line, DoubleToString(tracked.spreadATR, 6));
   CsvAdd(line, DoubleToString(tracked.atrSessionPercentile, 4));
   CsvAdd(line, DoubleToString(tracked.averageM15RangeATR, 4));
   CsvAdd(line, DoubleToString(tracked.averageH1RangeATR, 4));
   CsvAdd(line, DoubleToString(tracked.averageTrueRange, 8));
   CsvAdd(line, DoubleToString(tracked.realizedVolatility, 6));
   CsvAdd(line, DoubleToString(tracked.breakoutFollowthroughRate, 4));
   CsvAdd(line, DoubleToString(tracked.averageSpreadATR, 6));
   CsvAdd(line, DoubleToString(tracked.score, 4));
   CsvAdd(line, exitReason);
   CsvAdd(line, IntegerToString((int)tracked.positionId));
   CsvWriteLine(handle, line);
   FileClose(handle);
  }

void WriteSessionAuditRow(const string symbol)
  {
   SessionStats stats;
   datetime serverTime = TimeCurrent();
   BuildSessionStats(symbol, serverTime, stats);

   string h4Regime = "unknown";
   string h1Regime = "unknown";
   string h4Structure = "unknown";
   string h1Structure = "unknown";
   GetDowContext(symbol, InpSlowWaveTF, h4Regime, h4Structure);
   GetDowContext(symbol, InpFastWaveTF, h1Regime, h1Structure);

   EnsureLogFolder();
   int handle = FileOpen(LogFileName("session_audit"), LogFlags(), ',');
   if(handle == INVALID_HANDLE)
      return;

   bool header = (FileSize(handle) == 0);
   FileSeek(handle, 0, SEEK_END);
   if(header)
      FileWrite(handle,
                "server_time", "strategy", "scenario_mode", "symbol", "server_hour", "utc_hour",
                "session_label", "session_window_name", "broker_utc_offset_used",
                "session_volatility_rank", "average_m15_range_atr", "average_h1_range_atr",
                "average_true_range", "realized_volatility", "breakout_followthrough_rate",
                "average_spread_atr", "atr_session_percentile", "dow_regime_h4", "dow_regime_h1",
                "h4_structure", "h1_structure", "trade_count_candidate", "avg_R_if_traded",
                "PF_if_traded", "net_if_traded");

   FileWrite(handle,
             TimeToString(serverTime, TIME_DATE | TIME_SECONDS),
             RESEARCH_STRATEGY_NAME,
             ScenarioModeName(),
             symbol,
             IntegerToString(HourOfTime(serverTime)),
             IntegerToString(HourOfTime(UtcFromServer(serverTime))),
             stats.label,
             stats.windowName,
             IntegerToString(InpBrokerUtcOffsetHours),
             IntegerToString(stats.rank),
             DoubleToString(stats.averageM15RangeATR, 4),
             DoubleToString(stats.averageH1RangeATR, 4),
             DoubleToString(stats.averageTrueRange, 8),
             DoubleToString(stats.realizedVolatility, 6),
             DoubleToString(stats.breakoutFollowthroughRate, 4),
             DoubleToString(stats.averageSpreadATR, 6),
             DoubleToString(stats.atrSessionPercentile, 4),
             h4Regime,
             h1Regime,
             h4Structure,
             h1Structure,
             "0",
             "0",
             "0",
             "0");
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
      FileWrite(handle, "time", "strategy", "scenario_mode", "symbols", "signals", "orders_sent",
                "orders_failed", "blocked", "closed_trades", "initial_equity",
                "final_equity", "peak_equity", "daily_stopped", "drawdown_stopped",
                "pivot_future_reference_policy", "pivot_confirmation_delay_bars",
                "broker_utc_offset_used");

   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             RESEARCH_STRATEGY_NAME,
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
             BoolText(g_drawdownStopped),
             "confirmed_pivots_only_no_repaint_zigzag",
             IntegerToString(InpSwingDepth),
             IntegerToString(InpBrokerUtcOffsetHours));
   FileClose(handle);
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
   g_trades[size].setupType = plan.setupType;
   g_trades[size].waveStage = plan.waveStage;
   g_trades[size].waveTF = plan.waveTF;
   g_trades[size].baseCurrency = plan.baseCurrency;
   g_trades[size].quoteCurrency = plan.quoteCurrency;
   g_trades[size].serverTime = plan.serverTime;
   g_trades[size].serverHour = plan.serverHour;
   g_trades[size].utcHour = plan.utcHour;
   g_trades[size].sessionLabel = plan.sessionLabel;
   g_trades[size].sessionWindowName = plan.sessionWindowName;
   g_trades[size].allowedSession = plan.allowedSession;
   g_trades[size].sessionVolatilityRank = plan.sessionVolatilityRank;
   g_trades[size].dowRegimeH4 = plan.dowRegimeH4;
   g_trades[size].dowRegimeH1 = plan.dowRegimeH1;
   g_trades[size].h4Structure = plan.h4Structure;
   g_trades[size].h1Structure = plan.h1Structure;
   g_trades[size].fractalAlignment = plan.fractalAlignment;
   g_trades[size].fibZone = plan.fibZone;
   g_trades[size].divergenceType = plan.divergenceType;
   g_trades[size].m15ConfirmationType = plan.m15ConfirmationType;
   g_trades[size].entryFailureType = plan.failureType;
   g_trades[size].waveSizeATR = plan.waveSizeATR;
   g_trades[size].retracementRatio = plan.retracementRatio;
   g_trades[size].extensionRatio = plan.extensionRatio;
   g_trades[size].waveRuleValidity = plan.waveRuleValidity;
   g_trades[size].wave3BreakConfirmed = plan.wave3BreakConfirmed;
   g_trades[size].pivotConfirmationDelayBars = plan.pivotConfirmationDelayBars;
   g_trades[size].entryDelayFromPivot = plan.entryDelayFromPivot;
   g_trades[size].pivotTime = plan.pivotTime;
   g_trades[size].pivotConfirmedTime = plan.pivotConfirmedTime;
   g_trades[size].roomTo1R = plan.roomTo1R;
   g_trades[size].roomTo2R = plan.roomTo2R;
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
   g_trades[size].spreadATR = plan.spreadATR;
   g_trades[size].atrSessionPercentile = plan.atrSessionPercentile;
   g_trades[size].averageM15RangeATR = plan.averageM15RangeATR;
   g_trades[size].averageH1RangeATR = plan.averageH1RangeATR;
   g_trades[size].averageTrueRange = plan.averageTrueRange;
   g_trades[size].realizedVolatility = plan.realizedVolatility;
   g_trades[size].breakoutFollowthroughRate = plan.breakoutFollowthroughRate;
   g_trades[size].averageSpreadATR = plan.averageSpreadATR;
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

bool CanOpenSignal(SignalPlan &plan, string &blockReason)
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
      plan.failureType = blockReason;
      return false;
     }
   if(!plan.allowedSession)
     {
      blockReason = "low_vol_session_noise";
      plan.failureType = blockReason;
      return false;
     }
   bool strictDow = (InpScenarioMode == SYMBOL_BEST_SESSION_WITH_DOW_ALIGNMENT ||
                     InpScenarioMode == SYMBOL_BEST_SESSION_WITH_WAVE3_CONFIRMED);
   if(!DowAllowsDirection(plan.dowRegimeH4, plan.dowRegimeH1, DirectionSign(plan.direction), strictDow))
     {
      blockReason = "dow_misaligned";
      plan.failureType = blockReason;
      return false;
     }
   if(plan.fractalAlignment == "fractal_misaligned" || plan.fractalAlignment == "unknown")
     {
      blockReason = "fractal_misaligned";
      plan.failureType = blockReason;
      return false;
     }
   if(InpScenarioMode == SYMBOL_BEST_SESSION_WITH_WAVE3_CONFIRMED &&
      plan.setupType == "wave3_start_pullback" && !plan.wave3BreakConfirmed)
     {
      blockReason = "wave3_unconfirmed_too_early";
      plan.failureType = blockReason;
      return false;
     }
   if(HasManagedPosition(plan.symbol))
     {
      blockReason = "symbol_already_open";
      plan.failureType = blockReason;
      return false;
     }
   if(InpMaxPositions > 0 && CountManagedPositions() >= InpMaxPositions)
     {
      blockReason = "max_positions";
      plan.failureType = blockReason;
      return false;
     }
   if(CurrentTotalOpenRiskPercent() + InpRiskPerTradePercent > InpMaxTotalOpenRiskPercent)
     {
      blockReason = "total_risk_limit";
      plan.failureType = blockReason;
      return false;
     }
   if(CurrentSymbolOpenRiskPercent(plan.symbol) + InpRiskPerTradePercent > InpMaxRiskPerSymbolPercent)
     {
      blockReason = "symbol_risk_limit";
      plan.failureType = blockReason;
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

      WriteSessionAuditRow(g_symbols[i]);
      LogWave5Diagnostics(g_symbols[i]);

      SignalPlan plan;
      if(BuildRoadmapSignal(g_symbols[i], plan))
         TryOpenSignal(plan);
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
   if(InpSwingDepth < 1 ||
      InpWaveScanBars < InpSwingDepth * 2 + InpATRPeriod + 20 ||
      InpATRPeriod < 2 ||
      InpMinSwingSizeATR <= 0.0 ||
      InpScanFastMAPeriod < 2 ||
      InpScanSlowMAPeriod <= InpScanFastMAPeriod ||
      InpRewardR < 1.0 ||
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
   WriteSummaryRow();
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   ScanSymbols();
  }

void OnDeinit(const int reason)
  {
   WriteSummaryRow();
  }
