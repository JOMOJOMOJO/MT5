//+------------------------------------------------------------------+
//| ExpectedValue_MultiCurrency_FXElliottWaveRoadmapTrader           |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Backtest-only multi-currency FX Elliott-wave roadmap EA using confirmed H1/H4 pivots."

#include <Trade\Trade.mqh>

CTrade trade;

static const string STRATEGY_NAME = "ExpectedValue_MultiCurrency_FXElliottWaveRoadmapTrader";

enum ENUM_ROADMAP_SCENARIO
  {
   WAVE3_START_PULLBACK_ONLY = 0,
   WAVE4_CONTINUATION_ONLY = 1,
   ABC_COMPLETION_REENTRY_ONLY = 2,
   COMBINED_ROADMAP_TRIGGERS = 3
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
   double            score;
  };

input string          InpSymbols                       = "USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD";
input ENUM_ROADMAP_SCENARIO InpScenarioMode            = COMBINED_ROADMAP_TRIGGERS;
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
input long            InpMagicNumber                   = 2026062310;
input bool            InpUseCommonFiles                = true;
input string          InpLogFolder                     = "fxelliott_roadmap";
input string          InpLogPrefix                     = "fxelliott";

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
   if(InpScenarioMode == WAVE3_START_PULLBACK_ONLY)
      return "wave3_start_pullback_only";
   if(InpScenarioMode == WAVE4_CONTINUATION_ONLY)
      return "wave4_continuation_only";
   if(InpScenarioMode == ABC_COMPLETION_REENTRY_ONLY)
      return "abc_completion_reentry_only";
   return "combined_roadmap_triggers";
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
   double spreadATR = (tick.ask - tick.bid) / plan.atr;
   if(spreadATR > InpMaxSpreadATR)
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
   if(InpScenarioMode != COMBINED_ROADMAP_TRIGGERS)
      return;

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
            WriteSignalRow(diagnostic, "diagnostic");
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
      if((InpScenarioMode == WAVE3_START_PULLBACK_ONLY ||
          InpScenarioMode == COMBINED_ROADMAP_TRIGGERS) &&
         BuildWave3Plan(symbol, tf, waveRates, pivots, scan, h1, direction, candidate))
        {
         if(!found || candidate.score > best.score)
           {
            best = candidate;
            found = true;
           }
        }

      if((InpScenarioMode == WAVE4_CONTINUATION_ONLY ||
          InpScenarioMode == COMBINED_ROADMAP_TRIGGERS) &&
         BuildWave4Plan(symbol, tf, waveRates, pivots, scan, h1, direction, candidate))
        {
         if(!found || candidate.score > best.score)
           {
            best = candidate;
            found = true;
           }
        }

      if((InpScenarioMode == ABC_COMPLETION_REENTRY_ONLY ||
          InpScenarioMode == COMBINED_ROADMAP_TRIGGERS) &&
         BuildABCPlan(symbol, tf, waveRates, pivots, scan, h1, direction, candidate))
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
   plan.valid = true;
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
                "time", "event", "strategy", "symbol", "direction", "base_currency", "quote_currency",
                "wave_stage", "setup_type", "wave_tf", "fib_zone", "divergence_type",
                "m15_confirmation_type", "failure_type", "reason", "wave_size_atr",
                "retracement_ratio", "extension_ratio", "wave_rule_validity",
                "wave3_break_confirmed", "pivot_confirmation_delay_bars",
                "entry_delay_from_pivot", "pivot_time", "pivot_confirmed_time",
                "room_to_1r", "room_to_2r", "entry", "stop_loss", "take_profit",
                "risk_price", "reward_r", "atr", "spread_points", "score");

   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             eventName,
             plan.strategy,
             plan.symbol,
             plan.direction,
             plan.baseCurrency,
             plan.quoteCurrency,
             plan.waveStage,
             plan.setupType,
             plan.waveTF,
             plan.fibZone,
             plan.divergenceType,
             plan.m15ConfirmationType,
             plan.failureType,
             plan.reason,
             DoubleToString(plan.waveSizeATR, 4),
             DoubleToString(plan.retracementRatio, 4),
             DoubleToString(plan.extensionRatio, 4),
             plan.waveRuleValidity,
             BoolText(plan.wave3BreakConfirmed),
             IntegerToString(plan.pivotConfirmationDelayBars),
             IntegerToString(plan.entryDelayFromPivot),
             TimeToString(plan.pivotTime, TIME_DATE | TIME_SECONDS),
             TimeToString(plan.pivotConfirmedTime, TIME_DATE | TIME_SECONDS),
             DoubleToString(plan.roomTo1R, 4),
             DoubleToString(plan.roomTo2R, 4),
             DoubleToString(plan.entry, 8),
             DoubleToString(plan.stopLoss, 8),
             DoubleToString(plan.takeProfit, 8),
             DoubleToString(plan.riskPrice, 8),
             DoubleToString(plan.rewardR, 3),
             DoubleToString(plan.atr, 8),
             DoubleToString(plan.spreadPoints, 2),
             DoubleToString(plan.score, 4));
   FileClose(handle);
  }

string ClassifyFailure(const TrackedTrade &tracked, const string exitReason, const double resultR)
  {
   if(resultR > 0.0)
      return "other";
   if(!tracked.wave3BreakConfirmed && tracked.setupType == "wave3_start_pullback")
      return "wave3_unconfirmed_too_early";
   if(tracked.divergenceType != "none" && tracked.setupType == "wave4_continuation")
      return "divergence_against_continuation";
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
      FileWrite(handle,
                "entry_time", "exit_time", "strategy", "symbol", "direction", "base_currency", "quote_currency",
                "wave_stage", "setup_type", "wave_tf", "fib_zone", "divergence_type",
                "m15_confirmation_type", "failure_type", "wave_size_atr",
                "retracement_ratio", "extension_ratio", "wave_rule_validity",
                "wave3_break_confirmed", "pivot_confirmation_delay_bars",
                "entry_delay_from_pivot", "pivot_time", "pivot_confirmed_time",
                "room_to_1r", "room_to_2r", "entry", "exit", "stop_loss", "take_profit",
                "risk_price", "result_r", "profit", "commission", "swap", "net_profit",
                "volume", "reward_r", "holding_bars", "atr", "spread_points", "score",
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
             tracked.baseCurrency,
             tracked.quoteCurrency,
             tracked.waveStage,
             tracked.setupType,
             tracked.waveTF,
             tracked.fibZone,
             tracked.divergenceType,
             tracked.m15ConfirmationType,
             failureType,
             DoubleToString(tracked.waveSizeATR, 4),
             DoubleToString(tracked.retracementRatio, 4),
             DoubleToString(tracked.extensionRatio, 4),
             tracked.waveRuleValidity,
             BoolText(tracked.wave3BreakConfirmed),
             IntegerToString(tracked.pivotConfirmationDelayBars),
             IntegerToString(tracked.entryDelayFromPivot),
             TimeToString(tracked.pivotTime, TIME_DATE | TIME_SECONDS),
             TimeToString(tracked.pivotConfirmedTime, TIME_DATE | TIME_SECONDS),
             DoubleToString(tracked.roomTo1R, 4),
             DoubleToString(tracked.roomTo2R, 4),
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
             DoubleToString(tracked.score, 4),
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
                "final_equity", "peak_equity", "daily_stopped", "drawdown_stopped",
                "pivot_future_reference_policy", "pivot_confirmation_delay_bars");

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
             BoolText(g_drawdownStopped),
             "confirmed_pivots_only_no_repaint_zigzag",
             IntegerToString(InpSwingDepth));
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
