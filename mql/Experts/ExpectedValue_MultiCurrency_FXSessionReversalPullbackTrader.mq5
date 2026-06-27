//+------------------------------------------------------------------+
//| ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader      |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"
#property description "Backtest-only multi-currency session opening reversal pullback EA with HTF obstacle diagnostics."

#include <Trade\Trade.mqh>

CTrade trade;

static const string STRATEGY_NAME = "ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader";

enum ENUM_SESSION_REVERSAL_SCENARIO
  {
   SESSION_REVERSAL_ALL_SYMBOLS_FIRST120 = 0,
   SESSION_REVERSAL_ONE_SYMBOL_FIRST120 = 1,
   SESSION_REVERSAL_ONE_SYMBOL_FIRST60 = 2,
   SESSION_REVERSAL_CLEAN_TARGET_FIRST120 = 3,
   SESSION_REVERSAL_CLEAN_TARGET_FIRST60 = 4,
   SESSION_REVERSAL_TOKYO_FIRST120 = 5,
   SESSION_REVERSAL_LONDON_FIRST120 = 6,
   SESSION_REVERSAL_NEWYORK_FIRST120 = 7,
   SESSION_REVERSAL_OVERLAP_FIRST120 = 8,
   SESSION_REVERSAL_TARGET_MULTIPLE_1_2 = 9,
   SESSION_REVERSAL_TARGET_MULTIPLE_2_0 = 10
  };

struct SessionInfo
  {
   bool              active;
   string            label;
   int               index;
   int               startUtcHour;
   datetime          sessionStartUtc;
   datetime          sessionStartServer;
   int               minutesFromStart;
   int               serverHour;
   int               utcHour;
   int               jstHour;
   bool              first60;
   bool              first120;
   string            tradeWindowLabel;
   string            sessionKey;
  };

struct SignalPlan
  {
   bool              valid;
   bool              signalBlocked;
   string            symbol;
   string            direction;
   string            strategy;
   datetime          serverTime;
   int               serverHour;
   int               utcHour;
   int               jstHour;
   string            sessionLabel;
   datetime          sessionStartUtc;
   int               minutesFromSessionStart;
   string            tradeWindowLabel;
   bool              isWithinFirst60;
   bool              isWithinFirst120;
   double            brokerUtcOffsetUsed;
   string            selectedSymbolForSession;
   string            selectedReason;
   string            sessionCandidateSymbolMap;
   string            sessionCandidateSymbols;
   string            entryPattern;
   string            entryTrigger;
   double            necklineLevel;
   string            ltfWave3Direction;
   string            ltfWave3Timeframe;
   string            htfWave3Direction;
   bool              htfWave3Confirmed;
   string            htfH4Wave3Direction;
   string            htfH1Wave3Direction;
   string            htfFractalAlignment;
   double            htfWave3BreakLevel;
   double            htfWave3PullbackLevel;
   bool              wave3AlignmentPassed;
   double            htfNearestResistance;
   double            htfNearestSupport;
   double            nearestObstaclePrice;
   string            nearestObstacleType;
   double            nearestObstacleDistancePrice;
   double            nearestObstacleDistanceR;
   string            retestReferenceType;
   double            retestReferencePrice;
   int               retestReferenceCount;
   double            initialRiskPriceDistance;
   double            targetRewardMultiple;
   double            targetPrice;
   bool              cleanPathToTarget;
   bool              hardObstaclePresentBeforeTarget;
   bool              softObstaclePresentBeforeTarget;
   bool              obstacleBlocked;
   string            obstacleBlockReason;
   int               obstacleCountBeforeTarget;
   int               hardObstacleCountBeforeTarget;
   int               softObstacleCountBeforeTarget;
   double            entry;
   double            stopLoss;
   double            takeProfit;
   double            riskPrice;
   double            rewardR;
   double            atr;
   double            spreadPoints;
   double            score;
   string            failureType;
   string            reason;
   bool              sessionInvalidated;
   string            invalidationReason;
   string            sessionKey;
   string            symbolSessionKey;
  };

struct TrackedTrade
  {
   bool              active;
   string            symbol;
   string            direction;
   string            strategy;
   datetime          entryTime;
   datetime          serverTime;
   int               serverHour;
   int               utcHour;
   int               jstHour;
   string            sessionLabel;
   datetime          sessionStartUtc;
   int               minutesFromSessionStart;
   string            tradeWindowLabel;
   bool              isWithinFirst60;
   bool              isWithinFirst120;
   double            brokerUtcOffsetUsed;
   string            selectedSymbolForSession;
   string            selectedReason;
   string            sessionCandidateSymbolMap;
   string            sessionCandidateSymbols;
   string            entryPattern;
   string            entryTrigger;
   double            necklineLevel;
   string            ltfWave3Direction;
   string            ltfWave3Timeframe;
   string            htfWave3Direction;
   bool              htfWave3Confirmed;
   string            htfH4Wave3Direction;
   string            htfH1Wave3Direction;
   string            htfFractalAlignment;
   double            htfWave3BreakLevel;
   double            htfWave3PullbackLevel;
   bool              wave3AlignmentPassed;
   double            htfNearestResistance;
   double            htfNearestSupport;
   double            nearestObstaclePrice;
   string            nearestObstacleType;
   double            nearestObstacleDistanceR;
   string            retestReferenceType;
   double            retestReferencePrice;
   int               retestReferenceCount;
   bool              cleanPathToTarget;
   bool              hardObstaclePresentBeforeTarget;
   bool              softObstaclePresentBeforeTarget;
   bool              obstacleBlocked;
   double            targetRewardMultiple;
   double            targetPrice;
   string            entryFailureType;
   bool              sessionInvalidated;
   string            invalidationReason;
   long              positionId;
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
input ENUM_SESSION_REVERSAL_SCENARIO InpScenarioMode   = SESSION_REVERSAL_ONE_SYMBOL_FIRST120;
input ENUM_TIMEFRAMES InpScanTF                        = PERIOD_M15;
input ENUM_TIMEFRAMES InpDiagnosticTF                  = PERIOD_M5;
input int             InpBrokerUtcOffsetHours          = 3;
input int             InpATRPeriod                     = 14;
input int             InpMAPeriodFast                  = 10;
input int             InpMAPeriodSlow                  = 30;
input int             InpStructureLookbackBars         = 16;
input int             InpPatternLookbackBars           = 36;
input int             InpSwingDepth                    = 3;
input int             InpHTFLookbackBars               = 80;
input int             InpHTFWaveLookbackBars           = 120;
input double          InpHTFWaveBreakBufferATR         = 0.05;
input bool            InpRequireH4H1Wave3Alignment     = true;
input bool            InpUseM5LowerTimeframeWave3      = true;
input int             InpOpeningRangeMinutes           = 30;
input int             InpPreSessionMinutes             = 60;
input double          InpTargetRewardMultiple          = 1.50;
input bool            InpUseSoftObstacleAsHardFilter   = false;
input double          InpRoundNumberStepPips           = 50.0;
input double          InpEqualLevelTolerancePips       = 6.0;
input double          InpEqualLevelToleranceATR        = 0.12;
input double          InpRetestToleranceATR            = 0.28;
input double          InpBreakBufferATR                = 0.08;
input double          InpStopBufferATR                 = 0.18;
input double          InpMinSL_ATR                     = 0.35;
input double          InpMaxSL_ATR                     = 3.00;
input double          InpSessionInvalidationATR        = 0.85;
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
input long            InpMagicNumber                   = 2026062701;
input bool            InpUseCommonFiles                = true;
input string          InpLogFolder                     = "fx_session_reversal_pullback";
input string          InpLogPrefix                     = "fxsessionrev";

string        g_symbols[];
datetime      g_lastScannedBars[];
TrackedTrade  g_trades[];
string        g_consumedSessionKeys[];
string        g_consumedSymbolSessionKeys[];
string        g_selectedSessionKeys[];
string        g_selectedSymbols[];
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
   if(InpScenarioMode == SESSION_REVERSAL_ALL_SYMBOLS_FIRST120)
      return "session_reversal_pullback_all_symbols_first120";
   if(InpScenarioMode == SESSION_REVERSAL_ONE_SYMBOL_FIRST120)
      return "session_reversal_pullback_one_symbol_first120";
   if(InpScenarioMode == SESSION_REVERSAL_ONE_SYMBOL_FIRST60)
      return "session_reversal_pullback_one_symbol_first60";
   if(InpScenarioMode == SESSION_REVERSAL_CLEAN_TARGET_FIRST120)
      return "session_reversal_pullback_clean_target_path_first120";
   if(InpScenarioMode == SESSION_REVERSAL_CLEAN_TARGET_FIRST60)
      return "session_reversal_pullback_clean_target_path_first60";
   if(InpScenarioMode == SESSION_REVERSAL_TOKYO_FIRST120)
      return "tokyo_first120_reference";
   if(InpScenarioMode == SESSION_REVERSAL_LONDON_FIRST120)
      return "london_first120_reference";
   if(InpScenarioMode == SESSION_REVERSAL_NEWYORK_FIRST120)
      return "newyork_first120_reference";
   if(InpScenarioMode == SESSION_REVERSAL_OVERLAP_FIRST120)
      return "overlap_first120_reference";
   if(InpScenarioMode == SESSION_REVERSAL_TARGET_MULTIPLE_1_2)
      return "target_multiple_1_2_reference";
   return "target_multiple_2_0_reference";
  }

bool IsOneSymbolPerSessionScenario()
  {
   return InpScenarioMode != SESSION_REVERSAL_ALL_SYMBOLS_FIRST120;
  }

bool UsesCleanTargetPath()
  {
   return InpScenarioMode == SESSION_REVERSAL_CLEAN_TARGET_FIRST120 ||
          InpScenarioMode == SESSION_REVERSAL_CLEAN_TARGET_FIRST60 ||
          InpScenarioMode == SESSION_REVERSAL_TARGET_MULTIPLE_1_2 ||
          InpScenarioMode == SESSION_REVERSAL_TARGET_MULTIPLE_2_0;
  }

double EffectiveTargetRewardMultiple()
  {
   if(InpScenarioMode == SESSION_REVERSAL_TARGET_MULTIPLE_1_2)
      return 1.20;
   if(InpScenarioMode == SESSION_REVERSAL_TARGET_MULTIPLE_2_0)
      return 2.00;
   return InpTargetRewardMultiple;
  }

int EffectiveWindowMinutes()
  {
   if(InpScenarioMode == SESSION_REVERSAL_ONE_SYMBOL_FIRST60 ||
      InpScenarioMode == SESSION_REVERSAL_CLEAN_TARGET_FIRST60)
      return 60;
   return 120;
  }

string TradeWindowLabel()
  {
   int minutes = EffectiveWindowMinutes();
   if(minutes == 60)
      return "first_60min";
   if(minutes == 90)
      return "first_90min_reference";
   return "first_120min";
  }

bool ScenarioAllowsSession(const string label)
  {
   if(InpScenarioMode == SESSION_REVERSAL_TOKYO_FIRST120)
      return label == "tokyo";
   if(InpScenarioMode == SESSION_REVERSAL_LONDON_FIRST120)
      return label == "london";
   if(InpScenarioMode == SESSION_REVERSAL_NEWYORK_FIRST120)
      return label == "new_york";
   if(InpScenarioMode == SESSION_REVERSAL_OVERLAP_FIRST120)
      return label == "london_newyork_overlap";
   return true;
  }

bool IsTokyoJpySymbol(const string symbol)
  {
   return StringFind(symbol, "USDJPY") == 0 ||
          StringFind(symbol, "EURJPY") == 0 ||
          StringFind(symbol, "GBPJPY") == 0 ||
          StringFind(symbol, "AUDJPY") == 0;
  }

bool SymbolAllowedForSession(const string symbol, const string label)
  {
   if(label == "tokyo")
      return IsTokyoJpySymbol(symbol);
   return true;
  }

string CandidateSymbolsForSession(const string label)
  {
   string value = "";
   for(int i = 0; i < ArraySize(g_symbols); ++i)
     {
      if(!SymbolAllowedForSession(g_symbols[i], label))
         continue;
      if(value != "")
         value += "|";
      value += g_symbols[i];
     }
   return value == "" ? "none" : value;
  }

string CandidateSymbolMapForSession(const string label)
  {
   return label + "=" + CandidateSymbolsForSession(label);
  }

string DirectionText(const int direction)
  {
   if(direction > 0)
      return "LONG";
   if(direction < 0)
      return "SHORT";
   return "NONE";
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

double PipSize(const string symbol)
  {
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
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

datetime ServerToUtc(const datetime serverTime)
  {
   return serverTime - InpBrokerUtcOffsetHours * 3600;
  }

datetime UtcToServer(const datetime utcTime)
  {
   return utcTime + InpBrokerUtcOffsetHours * 3600;
  }

datetime BuildUtcSessionStart(const datetime utcTime, const int startHour)
  {
   MqlDateTime tm;
   TimeToStruct(utcTime, tm);
   tm.hour = startHour;
   tm.min = 0;
   tm.sec = 0;
   return StructToTime(tm);
  }

void ResetSessionInfo(SessionInfo &info)
  {
   info.active = false;
   info.label = "none";
   info.index = -1;
   info.startUtcHour = -1;
   info.sessionStartUtc = 0;
   info.sessionStartServer = 0;
   info.minutesFromStart = -1;
   info.serverHour = -1;
   info.utcHour = -1;
   info.jstHour = -1;
   info.first60 = false;
   info.first120 = false;
   info.tradeWindowLabel = TradeWindowLabel();
   info.sessionKey = "";
  }

void AddSessionInfo(const datetime utcTime,
                    const int serverHour,
                    const int utcHour,
                    const string label,
                    const int index,
                    const int startUtcHour,
                    SessionInfo &sessions[])
  {
   int size = ArraySize(sessions);
   ArrayResize(sessions, size + 1);
   SessionInfo info;
   ResetSessionInfo(info);
   info.active = true;
   info.label = label;
   info.index = index;
   info.startUtcHour = startUtcHour;
   info.serverHour = serverHour;
   info.utcHour = utcHour;
   info.jstHour = (utcHour + 9) % 24;
   info.sessionStartUtc = BuildUtcSessionStart(utcTime, info.startUtcHour);
   info.sessionStartServer = UtcToServer(info.sessionStartUtc);
   info.minutesFromStart = (int)((utcTime - info.sessionStartUtc) / 60);
   info.first60 = info.minutesFromStart >= 0 && info.minutesFromStart < 60;
   info.first120 = info.minutesFromStart >= 0 && info.minutesFromStart < 120;
   info.tradeWindowLabel = TradeWindowLabel();
   info.sessionKey = info.label + "_" + TimeToString(info.sessionStartUtc, TIME_DATE | TIME_MINUTES);
   sessions[size] = info;
  }

int BuildSessionInfos(const datetime serverTime, SessionInfo &sessions[])
  {
   ArrayResize(sessions, 0);
   MqlDateTime serverTm;
   TimeToStruct(serverTime, serverTm);
   datetime utcTime = ServerToUtc(serverTime);
   MqlDateTime utcTm;
   TimeToStruct(utcTime, utcTm);

   if(utcTm.hour >= 0 && utcTm.hour <= 8)
      AddSessionInfo(utcTime, serverTm.hour, utcTm.hour, "tokyo", 0, 0, sessions);
   if(utcTm.hour >= 7 && utcTm.hour <= 12)
      AddSessionInfo(utcTime, serverTm.hour, utcTm.hour, "london", 1, 7, sessions);
   if(utcTm.hour >= 13 && utcTm.hour <= 15)
      AddSessionInfo(utcTime, serverTm.hour, utcTm.hour, "london_newyork_overlap", 2, 13, sessions);
   if(utcTm.hour >= 16 && utcTm.hour <= 21)
      AddSessionInfo(utcTime, serverTm.hour, utcTm.hour, "new_york", 3, 16, sessions);

   return ArraySize(sessions);
  }

bool BuildSessionInfo(const datetime serverTime, SessionInfo &info)
  {
   SessionInfo sessions[];
   if(BuildSessionInfos(serverTime, sessions) <= 0)
     {
      ResetSessionInfo(info);
      return false;
     }
   info = sessions[0];
   return true;
  }

bool IsWithinTradeWindow(const SessionInfo &info)
  {
   if(!info.active || !ScenarioAllowsSession(info.label))
      return false;
   int minutes = EffectiveWindowMinutes();
   return info.minutesFromStart >= 0 && info.minutesFromStart < minutes;
  }

bool HasKey(const string &keys[], const string key)
  {
   for(int i = 0; i < ArraySize(keys); ++i)
     {
      if(keys[i] == key)
         return true;
     }
   return false;
  }

void AddKey(string &keys[], const string key)
  {
   if(key == "" || HasKey(keys, key))
      return;
   int size = ArraySize(keys);
   ArrayResize(keys, size + 1);
   keys[size] = key;
  }

bool SessionAlreadyConsumed(const SignalPlan &plan)
  {
   if(IsOneSymbolPerSessionScenario() && HasKey(g_consumedSessionKeys, plan.sessionKey))
      return true;
   if(HasKey(g_consumedSymbolSessionKeys, plan.symbolSessionKey))
      return true;
   return false;
  }

void MarkSessionConsumed(const SignalPlan &plan)
  {
   AddKey(g_consumedSymbolSessionKeys, plan.symbolSessionKey);
   if(IsOneSymbolPerSessionScenario())
      AddKey(g_consumedSessionKeys, plan.sessionKey);
  }

string SelectedSymbolForSession(const string sessionKey)
  {
   for(int i = 0; i < ArraySize(g_selectedSessionKeys); ++i)
     {
      if(g_selectedSessionKeys[i] == sessionKey)
         return g_selectedSymbols[i];
     }
   return "";
  }

void SetSelectedSymbolForSession(const string sessionKey, const string symbol)
  {
   for(int i = 0; i < ArraySize(g_selectedSessionKeys); ++i)
     {
      if(g_selectedSessionKeys[i] == sessionKey)
        {
         g_selectedSymbols[i] = symbol;
         return;
        }
     }
   int size = ArraySize(g_selectedSessionKeys);
   ArrayResize(g_selectedSessionKeys, size + 1);
   ArrayResize(g_selectedSymbols, size + 1);
   g_selectedSessionKeys[size] = sessionKey;
   g_selectedSymbols[size] = symbol;
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

bool CollectRangeByTime(const string symbol,
                        const ENUM_TIMEFRAMES tf,
                        const datetime startServer,
                        const datetime endServer,
                        double &high,
                        double &low,
                        double &openPrice)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   int copied = CopyRates(symbol, tf, startServer, endServer, rates);
   if(copied <= 0)
      return false;
   high = rates[0].high;
   low = rates[0].low;
   openPrice = rates[0].open;
   for(int i = 1; i < copied; ++i)
     {
      high = MathMax(high, rates[i].high);
      low = MathMin(low, rates[i].low);
     }
   return high > 0.0 && low > 0.0;
  }

bool FindConfirmedSwingLevel(const string symbol,
                             const ENUM_TIMEFRAMES tf,
                             const bool wantHigh,
                             const int depth,
                             const int lookback,
                             double &price)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = MathMax(lookback + depth + 8, depth * 2 + 10);
   int copied = CopyRates(symbol, tf, 1, bars, rates);
   if(copied < depth * 2 + 8)
      return false;

   int maxShift = MathMin(copied - depth - 1, lookback);
   for(int shift = depth + 1; shift <= maxShift; ++shift)
     {
      bool pivot = true;
      double candidate = wantHigh ? rates[shift].high : rates[shift].low;
      for(int j = 1; j <= depth; ++j)
        {
         if(wantHigh)
           {
            if(candidate <= rates[shift - j].high || candidate <= rates[shift + j].high)
              {
               pivot = false;
               break;
              }
           }
         else
           {
            if(candidate >= rates[shift - j].low || candidate >= rates[shift + j].low)
              {
               pivot = false;
               break;
              }
           }
        }
      if(pivot)
        {
         price = candidate;
         return true;
        }
     }
   return false;
  }

bool FindConfirmedSwingPair(const string symbol,
                            const ENUM_TIMEFRAMES tf,
                            const bool wantHigh,
                            const int depth,
                            const int lookback,
                            double &latestPrice,
                            double &previousPrice,
                            datetime &latestTime,
                            datetime &previousTime)
  {
   latestPrice = 0.0;
   previousPrice = 0.0;
   latestTime = 0;
   previousTime = 0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = MathMax(lookback + depth + 8, depth * 2 + 12);
   int copied = CopyRates(symbol, tf, 1, bars, rates);
   if(copied < depth * 2 + 10)
      return false;

   int found = 0;
   int maxShift = MathMin(copied - depth - 1, lookback);
   for(int shift = depth + 1; shift <= maxShift; ++shift)
     {
      bool pivot = true;
      double candidate = wantHigh ? rates[shift].high : rates[shift].low;
      for(int j = 1; j <= depth; ++j)
        {
         if(wantHigh)
           {
            if(candidate <= rates[shift - j].high || candidate <= rates[shift + j].high)
              {
               pivot = false;
               break;
              }
           }
         else
           {
            if(candidate >= rates[shift - j].low || candidate >= rates[shift + j].low)
              {
               pivot = false;
               break;
              }
           }
        }

      if(!pivot)
         continue;

      if(found == 0)
        {
         latestPrice = candidate;
         latestTime = rates[shift].time;
         ++found;
        }
      else
        {
         previousPrice = candidate;
         previousTime = rates[shift].time;
         return true;
        }
     }
   return false;
  }

int DetermineWave3DirectionOnTf(const string symbol,
                                const ENUM_TIMEFRAMES tf,
                                double &breakLevel,
                                double &pullbackLevel,
                                string &state)
  {
   breakLevel = 0.0;
   pullbackLevel = 0.0;
   state = "none";

   MqlRates rates[];
   int requiredBars = MathMax(InpHTFWaveLookbackBars + InpSwingDepth * 2 + 12,
                              InpATRPeriod + InpSwingDepth * 2 + 12);
   if(!CopyClosedRates(symbol, tf, requiredBars, rates))
     {
      state = "data_unavailable";
      return 0;
     }

   double atr = ATR(rates, 0, InpATRPeriod);
   if(atr <= 0.0)
     {
      state = "invalid_atr";
      return 0;
     }

   double latestHigh = 0.0;
   double previousHigh = 0.0;
   double latestLow = 0.0;
   double previousLow = 0.0;
   datetime latestHighTime = 0;
   datetime previousHighTime = 0;
   datetime latestLowTime = 0;
   datetime previousLowTime = 0;

   bool highs = FindConfirmedSwingPair(symbol, tf, true, InpSwingDepth, InpHTFWaveLookbackBars,
                                       latestHigh, previousHigh, latestHighTime, previousHighTime);
   bool lows = FindConfirmedSwingPair(symbol, tf, false, InpSwingDepth, InpHTFWaveLookbackBars,
                                      latestLow, previousLow, latestLowTime, previousLowTime);
   if(!highs || !lows)
     {
      state = "insufficient_confirmed_pivots";
      return 0;
     }

   double closePrice = rates[0].close;
   double buffer = atr * InpHTFWaveBreakBufferATR;
   bool longBreak = closePrice > latestHigh + buffer;
   bool shortBreak = closePrice < latestLow - buffer;
   bool longStructure = latestLow > previousLow - atr * 0.10;
   bool shortStructure = latestHigh < previousHigh + atr * 0.10;

   if(longBreak && longStructure && !(shortBreak && shortStructure))
     {
      breakLevel = latestHigh;
      pullbackLevel = latestLow;
      state = "confirmed_break_above_swing_high";
      return 1;
     }
   if(shortBreak && shortStructure && !(longBreak && longStructure))
     {
      breakLevel = latestLow;
      pullbackLevel = latestHigh;
      state = "confirmed_break_below_swing_low";
      return -1;
     }

   if(longBreak && !longStructure)
      state = "break_above_without_higher_pullback";
   else if(shortBreak && !shortStructure)
      state = "break_below_without_lower_pullback";
   else
      state = "no_confirmed_wave3_break";
   return 0;
  }

bool ApplyHtfWave3Alignment(const string symbol, const int entryDirection, SignalPlan &plan)
  {
   double h4Break = 0.0;
   double h4Pullback = 0.0;
   double h1Break = 0.0;
   double h1Pullback = 0.0;
   string h4State = "";
   string h1State = "";
   int h4Direction = DetermineWave3DirectionOnTf(symbol, PERIOD_H4, h4Break, h4Pullback, h4State);
   int h1Direction = DetermineWave3DirectionOnTf(symbol, PERIOD_H1, h1Break, h1Pullback, h1State);

   plan.htfH4Wave3Direction = DirectionText(h4Direction);
   plan.htfH1Wave3Direction = DirectionText(h1Direction);
   plan.htfFractalAlignment = "H4_" + plan.htfH4Wave3Direction + "_" + h4State +
                              "|H1_" + plan.htfH1Wave3Direction + "_" + h1State;
   plan.htfWave3Direction = (h4Direction == h1Direction && h1Direction != 0) ? DirectionText(h1Direction) : "NONE";
   plan.htfWave3Confirmed = h4Direction == entryDirection && h1Direction == entryDirection;
   plan.wave3AlignmentPassed = plan.htfWave3Confirmed;

   if(entryDirection > 0)
     {
      plan.htfWave3BreakLevel = h1Break > 0.0 ? h1Break : h4Break;
      plan.htfWave3PullbackLevel = h1Pullback > 0.0 ? h1Pullback : h4Pullback;
     }
   else
     {
      plan.htfWave3BreakLevel = h1Break > 0.0 ? h1Break : h4Break;
      plan.htfWave3PullbackLevel = h1Pullback > 0.0 ? h1Pullback : h4Pullback;
     }

   if(!InpRequireH4H1Wave3Alignment)
     {
      plan.wave3AlignmentPassed = (h1Direction == entryDirection && h4Direction != -entryDirection) ||
                                  (h4Direction == entryDirection && h1Direction != -entryDirection);
      if(plan.wave3AlignmentPassed && plan.htfWave3Direction == "NONE")
         plan.htfWave3Direction = DirectionText(entryDirection);
      return plan.wave3AlignmentPassed;
     }

   return plan.htfWave3Confirmed;
  }

bool FindRecentEqualLevel(const MqlRates &rates[],
                          const bool wantHigh,
                          const int lookback,
                          const double tolerance,
                          double &level)
  {
   int maxBars = MathMin(lookback, ArraySize(rates) - 2);
   for(int i = 2; i < maxBars; ++i)
     {
      double anchor = wantHigh ? rates[i].high : rates[i].low;
      int touches = 1;
      double sum = anchor;
      for(int j = i + 1; j < maxBars; ++j)
        {
         double value = wantHigh ? rates[j].high : rates[j].low;
         if(MathAbs(value - anchor) <= tolerance)
           {
            ++touches;
            sum += value;
           }
        }
      if(touches >= 2)
        {
         level = sum / touches;
         return true;
        }
     }
   return false;
  }

bool FindRecentRejectionLevel(const MqlRates &rates[], const bool wantHigh, double &level)
  {
   int maxBars = MathMin(InpPatternLookbackBars, ArraySize(rates) - 2);
   for(int i = 1; i < maxBars; ++i)
     {
      double body = MathAbs(rates[i].close - rates[i].open);
      double range = rates[i].high - rates[i].low;
      double upper = rates[i].high - MathMax(rates[i].close, rates[i].open);
      double lower = MathMin(rates[i].close, rates[i].open) - rates[i].low;
      if(wantHigh && upper > MathMax(body * 1.5, range * 0.25))
        {
         level = rates[i].high;
         return true;
        }
      if(!wantHigh && lower > MathMax(body * 1.5, range * 0.25))
        {
         level = rates[i].low;
         return true;
        }
     }
   return false;
  }

bool FindFailedBreakoutLevel(const MqlRates &rates[],
                             const int direction,
                             const double atr,
                             double &level)
  {
   int lookback = MathMin(InpPatternLookbackBars, ArraySize(rates) - InpStructureLookbackBars - 3);
   if(lookback < 6 || atr <= 0.0)
      return false;
   for(int i = 1; i < lookback; ++i)
     {
      double recentHigh = HighestHigh(rates, i + 1, InpStructureLookbackBars);
      double recentLow = LowestLow(rates, i + 1, InpStructureLookbackBars);
      if(direction > 0 && rates[i].high > recentHigh + atr * InpBreakBufferATR && rates[i].close < recentHigh)
        {
         level = recentHigh;
         return true;
        }
      if(direction < 0 && rates[i].low < recentLow - atr * InpBreakBufferATR && rates[i].close > recentLow)
        {
         level = recentLow;
         return true;
        }
     }
   return false;
  }

bool DetectDoubleBottom(const string symbol, const MqlRates &rates[], const double atr, double &neckline, double &stopAnchor)
  {
   double tolerance = MathMax(atr * 0.22, PipSize(symbol) * InpEqualLevelTolerancePips);
   int maxBars = MathMin(InpPatternLookbackBars, ArraySize(rates) - 4);
   for(int right = 2; right < maxBars / 2; ++right)
     {
      for(int left = right + 4; left < maxBars; ++left)
        {
         if(MathAbs(rates[right].low - rates[left].low) > tolerance)
            continue;
         neckline = HighestHigh(rates, right + 1, left - right - 1);
         if(neckline <= 0.0)
            continue;
         bool broke = rates[1].close > neckline + atr * InpBreakBufferATR ||
                      rates[0].close > neckline + atr * InpBreakBufferATR;
         bool retest = rates[0].low <= neckline + atr * InpRetestToleranceATR &&
                       rates[0].close >= neckline - atr * InpBreakBufferATR;
         if(broke && retest)
           {
            stopAnchor = MathMin(rates[right].low, rates[left].low);
            return true;
           }
        }
     }
   return false;
  }

bool DetectInverseHeadAndShoulders(const MqlRates &rates[], const double atr, double &neckline, double &stopAnchor)
  {
   int maxBars = MathMin(InpPatternLookbackBars, ArraySize(rates) - 4);
   for(int right = 2; right < MathMin(12, maxBars / 2); ++right)
     {
      for(int head = right + 3; head < MathMin(maxBars - 3, right + 18); ++head)
        {
         for(int left = head + 3; left < maxBars; ++left)
           {
            double leftLow = rates[left].low;
            double headLow = rates[head].low;
            double rightLow = rates[right].low;
            if(headLow >= leftLow - atr * 0.15 || headLow >= rightLow - atr * 0.15)
               continue;
            if(MathAbs(leftLow - rightLow) > atr * 0.55)
               continue;
            double leftNeck = HighestHigh(rates, head + 1, left - head - 1);
            double rightNeck = HighestHigh(rates, right + 1, head - right - 1);
            neckline = MathMax(leftNeck, rightNeck);
            bool broke = rates[1].close > neckline + atr * InpBreakBufferATR ||
                         rates[0].close > neckline + atr * InpBreakBufferATR;
            bool retest = rates[0].low <= neckline + atr * InpRetestToleranceATR &&
                          rates[0].close >= neckline - atr * InpBreakBufferATR;
            if(neckline > 0.0 && broke && retest)
              {
               stopAnchor = headLow;
               return true;
              }
           }
        }
     }
   return false;
  }

bool DetectDoubleTop(const string symbol, const MqlRates &rates[], const double atr, double &neckline, double &stopAnchor)
  {
   double tolerance = MathMax(atr * 0.22, PipSize(symbol) * InpEqualLevelTolerancePips);
   int maxBars = MathMin(InpPatternLookbackBars, ArraySize(rates) - 4);
   for(int right = 2; right < maxBars / 2; ++right)
     {
      for(int left = right + 4; left < maxBars; ++left)
        {
         if(MathAbs(rates[right].high - rates[left].high) > tolerance)
            continue;
         neckline = LowestLow(rates, right + 1, left - right - 1);
         if(neckline <= 0.0)
            continue;
         bool broke = rates[1].close < neckline - atr * InpBreakBufferATR ||
                      rates[0].close < neckline - atr * InpBreakBufferATR;
         bool retest = rates[0].high >= neckline - atr * InpRetestToleranceATR &&
                       rates[0].close <= neckline + atr * InpBreakBufferATR;
         if(broke && retest)
           {
            stopAnchor = MathMax(rates[right].high, rates[left].high);
            return true;
           }
        }
     }
   return false;
  }

bool DetectHeadAndShoulders(const MqlRates &rates[], const double atr, double &neckline, double &stopAnchor)
  {
   int maxBars = MathMin(InpPatternLookbackBars, ArraySize(rates) - 4);
   for(int right = 2; right < MathMin(12, maxBars / 2); ++right)
     {
      for(int head = right + 3; head < MathMin(maxBars - 3, right + 18); ++head)
        {
         for(int left = head + 3; left < maxBars; ++left)
           {
            double leftHigh = rates[left].high;
            double headHigh = rates[head].high;
            double rightHigh = rates[right].high;
            if(headHigh <= leftHigh + atr * 0.15 || headHigh <= rightHigh + atr * 0.15)
               continue;
            if(MathAbs(leftHigh - rightHigh) > atr * 0.55)
               continue;
            double leftNeck = LowestLow(rates, head + 1, left - head - 1);
            double rightNeck = LowestLow(rates, right + 1, head - right - 1);
            neckline = MathMin(leftNeck, rightNeck);
            bool broke = rates[1].close < neckline - atr * InpBreakBufferATR ||
                         rates[0].close < neckline - atr * InpBreakBufferATR;
            bool retest = rates[0].high >= neckline - atr * InpRetestToleranceATR &&
                          rates[0].close <= neckline + atr * InpBreakBufferATR;
            if(neckline > 0.0 && broke && retest)
              {
               stopAnchor = headHigh;
               return true;
              }
           }
        }
     }
   return false;
  }

bool DetectLongPattern(const string symbol,
                       const MqlRates &rates[],
                       const double atr,
                       string &pattern,
                       string &trigger,
                       double &neckline,
                       double &stopAnchor,
                       double &score)
  {
   pattern = "";
   trigger = "";
   neckline = 0.0;
   stopAnchor = LowestLow(rates, 0, MathMin(8, ArraySize(rates)));
   score = 0.0;

   double fast = SMA(rates, 0, InpMAPeriodFast);
   double slow = SMA(rates, 0, InpMAPeriodSlow);
   double priorFast = SMA(rates, 4, InpMAPeriodFast);
   double priorSlow = SMA(rates, 4, InpMAPeriodSlow);
   double structureHigh = HighestHigh(rates, 3, InpStructureLookbackBars);
   double structureLow = LowestLow(rates, 2, InpStructureLookbackBars);

   double localNeck = 0.0;
   double localStop = 0.0;
   if(DetectInverseHeadAndShoulders(rates, atr, localNeck, localStop))
     {
      pattern = "inverse_head_and_shoulders";
      trigger = "right_shoulder_entry";
      neckline = localNeck;
      stopAnchor = localStop;
      score = 4.5;
      return true;
     }

   if(DetectDoubleBottom(symbol, rates, atr, localNeck, localStop))
     {
      pattern = "double_bottom";
      trigger = "neckline_break_retest";
      neckline = localNeck;
      stopAnchor = localStop;
      score = 4.2;
      return true;
     }

   bool sweep = rates[1].low < structureLow - atr * InpBreakBufferATR &&
                rates[0].close > structureLow &&
                rates[0].close > rates[0].open;
   if(sweep)
     {
      pattern = "sweep_low_reclaim";
      trigger = "sweep_reclaim_retest";
      neckline = structureLow;
      stopAnchor = rates[1].low;
      score = 3.4;
      return true;
     }

   bool chochBreak = rates[1].close > structureHigh + atr * InpBreakBufferATR;
   bool retest = rates[0].low <= structureHigh + atr * InpRetestToleranceATR &&
                 rates[0].close > structureHigh - atr * InpBreakBufferATR;
   bool priorDown = priorFast < priorSlow || rates[6].close < rates[12].close;
   if(priorDown && chochBreak && retest)
     {
      pattern = "choch_up";
      trigger = "first_pullback_after_choch";
      neckline = structureHigh;
      stopAnchor = LowestLow(rates, 0, 6);
      score = 3.1;
      return true;
     }

   bool bos = fast > slow && priorFast <= priorSlow && rates[0].low <= fast + atr * InpRetestToleranceATR && rates[0].close > fast;
   if(bos)
     {
      pattern = "bos_up";
      trigger = "first_pullback_after_bos";
      neckline = fast;
      stopAnchor = LowestLow(rates, 0, 6);
      score = 2.6;
      return true;
     }

   return false;
  }

bool DetectShortPattern(const string symbol,
                        const MqlRates &rates[],
                        const double atr,
                        string &pattern,
                        string &trigger,
                        double &neckline,
                        double &stopAnchor,
                        double &score)
  {
   pattern = "";
   trigger = "";
   neckline = 0.0;
   stopAnchor = HighestHigh(rates, 0, MathMin(8, ArraySize(rates)));
   score = 0.0;

   double fast = SMA(rates, 0, InpMAPeriodFast);
   double slow = SMA(rates, 0, InpMAPeriodSlow);
   double priorFast = SMA(rates, 4, InpMAPeriodFast);
   double priorSlow = SMA(rates, 4, InpMAPeriodSlow);
   double structureHigh = HighestHigh(rates, 2, InpStructureLookbackBars);
   double structureLow = LowestLow(rates, 3, InpStructureLookbackBars);

   double localNeck = 0.0;
   double localStop = 0.0;
   if(DetectHeadAndShoulders(rates, atr, localNeck, localStop))
     {
      pattern = "head_and_shoulders";
      trigger = "right_shoulder_entry";
      neckline = localNeck;
      stopAnchor = localStop;
      score = 4.5;
      return true;
     }

   if(DetectDoubleTop(symbol, rates, atr, localNeck, localStop))
     {
      pattern = "double_top";
      trigger = "neckline_break_retest";
      neckline = localNeck;
      stopAnchor = localStop;
      score = 4.2;
      return true;
     }

   bool sweep = rates[1].high > structureHigh + atr * InpBreakBufferATR &&
                rates[0].close < structureHigh &&
                rates[0].close < rates[0].open;
   if(sweep)
     {
      pattern = "sweep_high_reclaim";
      trigger = "sweep_reclaim_retest";
      neckline = structureHigh;
      stopAnchor = rates[1].high;
      score = 3.4;
      return true;
     }

   bool chochBreak = rates[1].close < structureLow - atr * InpBreakBufferATR;
   bool retest = rates[0].high >= structureLow - atr * InpRetestToleranceATR &&
                 rates[0].close < structureLow + atr * InpBreakBufferATR;
   bool priorUp = priorFast > priorSlow || rates[6].close > rates[12].close;
   if(priorUp && chochBreak && retest)
     {
      pattern = "choch_down";
      trigger = "first_pullback_after_choch";
      neckline = structureLow;
      stopAnchor = HighestHigh(rates, 0, 6);
      score = 3.1;
      return true;
     }

   bool bos = fast < slow && priorFast >= priorSlow && rates[0].high >= fast - atr * InpRetestToleranceATR && rates[0].close < fast;
   if(bos)
     {
      pattern = "bos_down";
      trigger = "first_pullback_after_bos";
      neckline = fast;
      stopAnchor = HighestHigh(rates, 0, 6);
      score = 2.6;
      return true;
     }

   return false;
  }

void ResetPlan(SignalPlan &plan, const string symbol)
  {
   plan.valid = false;
   plan.signalBlocked = false;
   plan.symbol = symbol;
   plan.direction = "NONE";
   plan.strategy = ScenarioModeName();
   plan.serverTime = 0;
   plan.serverHour = 0;
   plan.utcHour = 0;
   plan.jstHour = 0;
   plan.sessionLabel = "none";
   plan.sessionStartUtc = 0;
   plan.minutesFromSessionStart = -1;
   plan.tradeWindowLabel = TradeWindowLabel();
   plan.isWithinFirst60 = false;
   plan.isWithinFirst120 = false;
   plan.brokerUtcOffsetUsed = InpBrokerUtcOffsetHours;
   plan.selectedSymbolForSession = "";
   plan.selectedReason = "";
   plan.sessionCandidateSymbolMap = "";
   plan.sessionCandidateSymbols = "";
   plan.entryPattern = "";
   plan.entryTrigger = "";
   plan.necklineLevel = 0.0;
   plan.ltfWave3Direction = "NONE";
   plan.ltfWave3Timeframe = EnumToString(InpScanTF);
   plan.htfWave3Direction = "NONE";
   plan.htfWave3Confirmed = false;
   plan.htfH4Wave3Direction = "NONE";
   plan.htfH1Wave3Direction = "NONE";
   plan.htfFractalAlignment = "none";
   plan.htfWave3BreakLevel = 0.0;
   plan.htfWave3PullbackLevel = 0.0;
   plan.wave3AlignmentPassed = false;
   plan.htfNearestResistance = 0.0;
   plan.htfNearestSupport = 0.0;
   plan.nearestObstaclePrice = 0.0;
   plan.nearestObstacleType = "none";
   plan.nearestObstacleDistancePrice = 0.0;
   plan.nearestObstacleDistanceR = 0.0;
   plan.retestReferenceType = "none";
   plan.retestReferencePrice = 0.0;
   plan.retestReferenceCount = 0;
   plan.initialRiskPriceDistance = 0.0;
   plan.targetRewardMultiple = EffectiveTargetRewardMultiple();
   plan.targetPrice = 0.0;
   plan.cleanPathToTarget = true;
   plan.hardObstaclePresentBeforeTarget = false;
   plan.softObstaclePresentBeforeTarget = false;
   plan.obstacleBlocked = false;
   plan.obstacleBlockReason = "not_blocked";
   plan.obstacleCountBeforeTarget = 0;
   plan.hardObstacleCountBeforeTarget = 0;
   plan.softObstacleCountBeforeTarget = 0;
   plan.entry = 0.0;
   plan.stopLoss = 0.0;
   plan.takeProfit = 0.0;
   plan.riskPrice = 0.0;
   plan.rewardR = EffectiveTargetRewardMultiple();
   plan.atr = 0.0;
   plan.spreadPoints = 0.0;
   plan.score = 0.0;
   plan.failureType = "other";
   plan.reason = "";
   plan.sessionInvalidated = false;
   plan.invalidationReason = "not_invalidated";
   plan.sessionKey = "";
   plan.symbolSessionKey = "";
  }

void ApplySessionInfo(SignalPlan &plan, const SessionInfo &info)
  {
   plan.serverHour = info.serverHour;
   plan.utcHour = info.utcHour;
   plan.jstHour = info.jstHour;
   plan.sessionLabel = info.label;
   plan.sessionStartUtc = info.sessionStartUtc;
   plan.minutesFromSessionStart = info.minutesFromStart;
   plan.tradeWindowLabel = info.tradeWindowLabel;
   plan.isWithinFirst60 = info.first60;
   plan.isWithinFirst120 = info.first120;
   plan.sessionKey = info.sessionKey;
   plan.symbolSessionKey = plan.symbol + "_" + info.sessionKey;
   plan.sessionCandidateSymbols = CandidateSymbolsForSession(info.label);
   plan.sessionCandidateSymbolMap = CandidateSymbolMapForSession(info.label);
  }

bool FillTradeLevels(SignalPlan &plan, const int direction, const double stopAnchor)
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
      plan.reason = "invalid_symbol_or_atr";
      return false;
     }

   plan.spreadPoints = (tick.ask - tick.bid) / point;
   double spreadATR = (tick.ask - tick.bid) / plan.atr;
   if(spreadATR > InpMaxSpreadATR)
     {
      plan.failureType = "spread_too_high";
      plan.reason = "spread_too_high";
      plan.signalBlocked = true;
     }

   int stopsLevel = (int)SymbolInfoInteger(plan.symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minBrokerDistance = (stopsLevel + 2) * point;
   double minStopDistance = MathMax(plan.atr * InpMinSL_ATR, minBrokerDistance);
   double maxStopDistance = plan.atr * InpMaxSL_ATR;
   double stopBuffer = MathMax(plan.atr * InpStopBufferATR, minBrokerDistance);

   if(direction > 0)
     {
      plan.direction = "LONG";
      plan.entry = tick.ask;
      plan.stopLoss = stopAnchor - stopBuffer;
      if(plan.entry - plan.stopLoss < minStopDistance)
         plan.stopLoss = plan.entry - minStopDistance;
      if(plan.entry - plan.stopLoss > maxStopDistance)
         plan.stopLoss = plan.entry - maxStopDistance;
      plan.riskPrice = MathAbs(plan.entry - plan.stopLoss);
      plan.targetPrice = plan.entry + plan.riskPrice * plan.targetRewardMultiple;
      plan.takeProfit = plan.targetPrice;
     }
   else
     {
      plan.direction = "SHORT";
      plan.entry = tick.bid;
      plan.stopLoss = stopAnchor + stopBuffer;
      if(plan.stopLoss - plan.entry < minStopDistance)
         plan.stopLoss = plan.entry + minStopDistance;
      if(plan.stopLoss - plan.entry > maxStopDistance)
         plan.stopLoss = plan.entry + maxStopDistance;
      plan.riskPrice = MathAbs(plan.entry - plan.stopLoss);
      plan.targetPrice = plan.entry - plan.riskPrice * plan.targetRewardMultiple;
      plan.takeProfit = plan.targetPrice;
     }

   if(plan.riskPrice <= 0.0)
     {
      plan.reason = "invalid_risk";
      return false;
     }

   if(MathAbs(plan.takeProfit - plan.entry) < minBrokerDistance)
     {
      plan.reason = "target_inside_stop_level";
      return false;
     }

   plan.entry = NormalizeDouble(plan.entry, digits);
   plan.stopLoss = NormalizeDouble(plan.stopLoss, digits);
   plan.takeProfit = NormalizeDouble(plan.takeProfit, digits);
   plan.targetPrice = NormalizeDouble(plan.targetPrice, digits);
   plan.riskPrice = MathAbs(plan.entry - plan.stopLoss);
   plan.initialRiskPriceDistance = plan.riskPrice;
   plan.rewardR = MathAbs(plan.takeProfit - plan.entry) / MathMax(plan.riskPrice, point);
   return plan.riskPrice > 0.0;
  }

bool PriceBeforeTarget(const SignalPlan &plan, const double price)
  {
   if(plan.riskPrice <= 0.0)
      return false;
   if(plan.direction == "LONG")
      return price > plan.entry && price <= plan.targetPrice;
   if(plan.direction == "SHORT")
      return price < plan.entry && price >= plan.targetPrice;
   return false;
  }

void UpdateNearestHtfLevels(SignalPlan &plan, const double price)
  {
   if(price <= 0.0)
      return;
   if(price > plan.entry)
     {
      if(plan.htfNearestResistance <= 0.0 ||
         MathAbs(price - plan.entry) < MathAbs(plan.htfNearestResistance - plan.entry))
         plan.htfNearestResistance = price;
     }
   if(price < plan.entry)
     {
      if(plan.htfNearestSupport <= 0.0 ||
         MathAbs(price - plan.entry) < MathAbs(plan.htfNearestSupport - plan.entry))
         plan.htfNearestSupport = price;
     }
  }

string ObstacleBlockReason(const SignalPlan &plan, const string obstacleType)
  {
   if(StringFind(obstacleType, "previous_day") >= 0)
      return "previous_day_level_blocked";
   if(StringFind(obstacleType, "previous_week") >= 0)
      return "previous_week_level_blocked";
   if(StringFind(obstacleType, "session_") >= 0 ||
      StringFind(obstacleType, "pre_session") >= 0 ||
      StringFind(obstacleType, "opening_range") >= 0)
      return "session_level_blocked";
   if(StringFind(obstacleType, "neckline") >= 0)
      return "neckline_level_blocked";
   if(StringFind(obstacleType, "h4_") >= 0 || StringFind(obstacleType, "h1_") >= 0)
      return plan.direction == "LONG" ? "htf_resistance_blocked" : "htf_support_blocked";
   return "obstacle_before_target";
  }

void RegisterObstacle(SignalPlan &plan,
                      const string obstacleType,
                      const double price,
                      const bool hardObstacle)
  {
   if(price <= 0.0 || plan.riskPrice <= 0.0)
      return;

   UpdateNearestHtfLevels(plan, price);
   if(!PriceBeforeTarget(plan, price))
      return;

   double distancePrice = MathAbs(price - plan.entry);
   double distanceR = distancePrice / plan.riskPrice;
   ++plan.obstacleCountBeforeTarget;
   if(hardObstacle)
      ++plan.hardObstacleCountBeforeTarget;
   else
      ++plan.softObstacleCountBeforeTarget;

   if(hardObstacle)
      plan.hardObstaclePresentBeforeTarget = true;
   else
      plan.softObstaclePresentBeforeTarget = true;

   if(plan.nearestObstaclePrice <= 0.0 || distanceR < plan.nearestObstacleDistanceR)
     {
      plan.nearestObstaclePrice = price;
      plan.nearestObstacleType = obstacleType;
      plan.nearestObstacleDistancePrice = distancePrice;
      plan.nearestObstacleDistanceR = distanceR;
     }

   if(hardObstacle || InpUseSoftObstacleAsHardFilter)
     {
      if(distanceR < plan.targetRewardMultiple)
        {
         plan.cleanPathToTarget = false;
         if(UsesCleanTargetPath() && !plan.obstacleBlocked)
           {
            plan.obstacleBlocked = true;
            plan.obstacleBlockReason = ObstacleBlockReason(plan, obstacleType);
           }
        }
     }
   else
      plan.cleanPathToTarget = false;
  }

void RegisterRetestReference(SignalPlan &plan,
                             const string referenceType,
                             const double price)
  {
   if(price <= 0.0)
      return;

   ++plan.retestReferenceCount;
   double distance = MathAbs(price - plan.entry);
   if(plan.retestReferenceType == "none")
      plan.retestReferenceType = referenceType;
   else if(StringFind(plan.retestReferenceType, referenceType) < 0)
      plan.retestReferenceType += "|" + referenceType;

   if(plan.retestReferencePrice <= 0.0 || distance < MathAbs(plan.retestReferencePrice - plan.entry))
      plan.retestReferencePrice = price;
  }

bool IsBreakoutRetestReferenceType(const string obstacleType, const string direction)
  {
   if(StringFind(obstacleType, "neckline") >= 0)
      return true;
   if(direction == "LONG")
     {
      return obstacleType == "session_high" ||
             obstacleType == "opening_range_high";
     }
   if(direction == "SHORT")
     {
      return obstacleType == "session_low" ||
             obstacleType == "opening_range_low";
     }
   return false;
  }

bool RegisterObstacleOrRetestReference(SignalPlan &plan,
                                       const string obstacleType,
                                       const double price,
                                       const bool hardObstacle)
  {
   if(price <= 0.0)
      return false;

   double buffer = plan.atr * InpRetestToleranceATR;
   bool brokenBehindEntry = false;
   if(plan.direction == "LONG")
      brokenBehindEntry = price <= plan.entry + buffer;
   else if(plan.direction == "SHORT")
      brokenBehindEntry = price >= plan.entry - buffer;

   if(brokenBehindEntry && IsBreakoutRetestReferenceType(obstacleType, plan.direction))
     {
      RegisterRetestReference(plan, obstacleType, price);
      UpdateNearestHtfLevels(plan, price);
      return true;
     }

   RegisterObstacle(plan, obstacleType, price, hardObstacle);
   return false;
  }

double RoundNumberStep(const string symbol)
  {
   if(InpRoundNumberStepPips <= 0.0)
      return 0.0;
   return InpRoundNumberStepPips * PipSize(symbol);
  }

void AddRoundNumberObstacle(SignalPlan &plan)
  {
   double step = RoundNumberStep(plan.symbol);
   if(step <= 0.0)
      return;
   double level = 0.0;
   if(plan.direction == "LONG")
      level = MathCeil(plan.entry / step) * step;
   else
      level = MathFloor(plan.entry / step) * step;
   if(MathAbs(level - plan.entry) < step * 0.05)
      level += (plan.direction == "LONG" ? step : -step);
   RegisterObstacle(plan, "round_number", level, false);
  }

void EvaluateTargetPathObstacles(SignalPlan &plan, const MqlRates &scan[])
  {
   plan.cleanPathToTarget = true;
   plan.nearestObstaclePrice = 0.0;
   plan.nearestObstacleType = "none";
   plan.nearestObstacleDistancePrice = 0.0;
   plan.nearestObstacleDistanceR = 0.0;
   plan.obstacleBlocked = false;
   plan.obstacleBlockReason = "not_blocked";
   plan.obstacleCountBeforeTarget = 0;
   plan.hardObstacleCountBeforeTarget = 0;
   plan.softObstacleCountBeforeTarget = 0;
   plan.hardObstaclePresentBeforeTarget = false;
   plan.softObstaclePresentBeforeTarget = false;
   plan.retestReferenceType = "none";
   plan.retestReferencePrice = 0.0;
   plan.retestReferenceCount = 0;

   double level = 0.0;
   RegisterObstacle(plan, "previous_day_high", iHigh(plan.symbol, PERIOD_D1, 1), true);
   RegisterObstacle(plan, "previous_day_low", iLow(plan.symbol, PERIOD_D1, 1), true);
   RegisterObstacle(plan, "current_day_high", iHigh(plan.symbol, PERIOD_D1, 0), false);
   RegisterObstacle(plan, "current_day_low", iLow(plan.symbol, PERIOD_D1, 0), false);
   RegisterObstacle(plan, "previous_week_high", iHigh(plan.symbol, PERIOD_W1, 1), true);
   RegisterObstacle(plan, "previous_week_low", iLow(plan.symbol, PERIOD_W1, 1), true);

   if(FindConfirmedSwingLevel(plan.symbol, PERIOD_H4, true, InpSwingDepth, InpHTFLookbackBars, level))
      RegisterObstacle(plan, "h4_confirmed_swing_high", level, true);
   if(FindConfirmedSwingLevel(plan.symbol, PERIOD_H4, false, InpSwingDepth, InpHTFLookbackBars, level))
      RegisterObstacle(plan, "h4_confirmed_swing_low", level, true);
   if(FindConfirmedSwingLevel(plan.symbol, PERIOD_H1, true, InpSwingDepth, InpHTFLookbackBars, level))
      RegisterObstacle(plan, "h1_confirmed_swing_high", level, true);
   if(FindConfirmedSwingLevel(plan.symbol, PERIOD_H1, false, InpSwingDepth, InpHTFLookbackBars, level))
      RegisterObstacle(plan, "h1_confirmed_swing_low", level, true);

   double sessionHigh = 0.0;
   double sessionLow = 0.0;
   double sessionOpen = 0.0;
   if(CollectRangeByTime(plan.symbol, InpScanTF, UtcToServer(plan.sessionStartUtc), plan.serverTime,
                         sessionHigh, sessionLow, sessionOpen))
     {
      RegisterObstacleOrRetestReference(plan, "session_high", sessionHigh, true);
      RegisterObstacleOrRetestReference(plan, "session_low", sessionLow, true);
     }

   double preHigh = 0.0;
   double preLow = 0.0;
   double preOpen = 0.0;
   datetime sessionStartServer = UtcToServer(plan.sessionStartUtc);
   if(CollectRangeByTime(plan.symbol, InpScanTF, sessionStartServer - InpPreSessionMinutes * 60,
                         sessionStartServer - 60, preHigh, preLow, preOpen))
     {
      RegisterObstacle(plan, "pre_session_high", preHigh, true);
      RegisterObstacle(plan, "pre_session_low", preLow, true);
     }

   double openHigh = 0.0;
   double openLow = 0.0;
   double openOpen = 0.0;
   if(CollectRangeByTime(plan.symbol, InpScanTF, sessionStartServer,
                         sessionStartServer + InpOpeningRangeMinutes * 60,
                         openHigh, openLow, openOpen))
     {
      RegisterObstacleOrRetestReference(plan, "opening_range_high", openHigh, true);
      RegisterObstacleOrRetestReference(plan, "opening_range_low", openLow, true);
     }

   if(plan.necklineLevel > 0.0)
      RegisterObstacleOrRetestReference(plan, "neckline_level", plan.necklineLevel, true);
   if(FindFailedBreakoutLevel(scan, plan.direction == "LONG" ? 1 : -1, plan.atr, level))
      RegisterObstacle(plan, "failed_breakout_level", level, true);

   double tolerance = MathMax(InpEqualLevelTolerancePips * PipSize(plan.symbol), plan.atr * InpEqualLevelToleranceATR);
   if(FindRecentEqualLevel(scan, true, InpPatternLookbackBars, tolerance, level))
      RegisterObstacle(plan, "recent_equal_highs", level, false);
   if(FindRecentEqualLevel(scan, false, InpPatternLookbackBars, tolerance, level))
      RegisterObstacle(plan, "recent_equal_lows", level, false);
   if(FindRecentRejectionLevel(scan, true, level))
      RegisterObstacle(plan, "recent_rejection_zone", level, false);
   if(FindRecentRejectionLevel(scan, false, level))
      RegisterObstacle(plan, "wick_cluster_zone", level, false);

   double recentHigh = HighestHigh(scan, 1, MathMin(12, ArraySize(scan) - 2));
   double recentLow = LowestLow(scan, 1, MathMin(12, ArraySize(scan) - 2));
   if(recentHigh > recentLow && (recentHigh - recentLow) / MathMax(plan.atr, _Point) <= 1.60)
     {
      RegisterObstacle(plan, "consolidation_zone", plan.direction == "LONG" ? recentHigh : recentLow, false);
      RegisterObstacle(plan, "price_congestion_zone", (recentHigh + recentLow) * 0.5, false);
     }
   AddRoundNumberObstacle(plan);

   if(plan.nearestObstaclePrice <= 0.0)
     {
      plan.nearestObstacleType = "none";
      plan.nearestObstacleDistanceR = 0.0;
      plan.nearestObstacleDistancePrice = 0.0;
     }

   if(UsesCleanTargetPath() && plan.obstacleBlocked)
     {
      plan.signalBlocked = true;
      plan.reason = plan.obstacleBlockReason;
      plan.failureType = plan.obstacleBlockReason;
   }
  }

bool BuildSessionReversalSignal(const string symbol, const SessionInfo &session, SignalPlan &plan)
  {
   ResetPlan(plan, symbol);

   MqlRates scan[];
   int requiredScan = MathMax(InpPatternLookbackBars + InpStructureLookbackBars + 10,
                              InpMAPeriodSlow + InpATRPeriod + 10);
   if(!CopyClosedRates(symbol, InpScanTF, requiredScan, scan))
     {
      plan.reason = "data_unavailable";
      return false;
     }

   plan.serverTime = scan[0].time;
   ApplySessionInfo(plan, session);
   if(!IsWithinTradeWindow(session))
      return false;
   if(!SymbolAllowedForSession(symbol, session.label))
      return false;
   if(SessionAlreadyConsumed(plan))
      return false;

   double atr = ATR(scan, 0, InpATRPeriod);
   if(atr <= 0.0)
     {
      plan.reason = "invalid_atr";
      return false;
     }
   plan.atr = atr;

   string longPattern = "";
   string longTrigger = "";
   string shortPattern = "";
   string shortTrigger = "";
   double longNeck = 0.0;
   double shortNeck = 0.0;
   double longStop = 0.0;
   double shortStop = 0.0;
   double longScore = 0.0;
   double shortScore = 0.0;
   string lowerTimeframeLabel = EnumToString(InpScanTF);
   bool longValid = DetectLongPattern(symbol, scan, atr, longPattern, longTrigger, longNeck, longStop, longScore);
   bool shortValid = DetectShortPattern(symbol, scan, atr, shortPattern, shortTrigger, shortNeck, shortStop, shortScore);

   if(!longValid && !shortValid && InpUseM5LowerTimeframeWave3 && InpDiagnosticTF != InpScanTF)
     {
      MqlRates diagnostic[];
      if(CopyClosedRates(symbol, InpDiagnosticTF, requiredScan, diagnostic))
        {
         double diagnosticAtr = ATR(diagnostic, 0, InpATRPeriod);
         if(diagnosticAtr > 0.0)
           {
            longValid = DetectLongPattern(symbol, diagnostic, diagnosticAtr, longPattern, longTrigger, longNeck, longStop, longScore);
            shortValid = DetectShortPattern(symbol, diagnostic, diagnosticAtr, shortPattern, shortTrigger, shortNeck, shortStop, shortScore);
            if(longValid || shortValid)
               lowerTimeframeLabel = EnumToString(InpDiagnosticTF);
           }
        }
     }

   if(!longValid && !shortValid)
      return false;

   int direction = 0;
   double stopAnchor = 0.0;
   if(longValid && (!shortValid || longScore >= shortScore))
     {
      direction = 1;
      plan.entryPattern = longPattern;
      plan.entryTrigger = longTrigger;
      plan.necklineLevel = longNeck;
      stopAnchor = longStop;
      plan.score = longScore;
   }
   else
     {
      direction = -1;
      plan.entryPattern = shortPattern;
      plan.entryTrigger = shortTrigger;
      plan.necklineLevel = shortNeck;
      stopAnchor = shortStop;
      plan.score = shortScore;
     }

   plan.ltfWave3Direction = DirectionText(direction);
   plan.ltfWave3Timeframe = lowerTimeframeLabel;
   if(!ApplyHtfWave3Alignment(symbol, direction, plan))
     {
      plan.reason = "htf_wave3_alignment_failed";
      plan.failureType = "htf_wave3_alignment_failed";
      return false;
     }

   double sessionHigh = 0.0;
   double sessionLow = 0.0;
   double sessionOpen = 0.0;
   if(CollectRangeByTime(symbol, InpScanTF, session.sessionStartServer, plan.serverTime, sessionHigh, sessionLow, sessionOpen))
     {
      if(direction > 0 && sessionLow <= sessionOpen - atr * InpSessionInvalidationATR)
        {
         plan.sessionInvalidated = true;
         plan.invalidationReason = "opposite_break_first";
         plan.failureType = "opposite_break_first";
         plan.reason = "session_invalidated";
         plan.signalBlocked = true;
        }
      if(direction < 0 && sessionHigh >= sessionOpen + atr * InpSessionInvalidationATR)
        {
         plan.sessionInvalidated = true;
         plan.invalidationReason = "opposite_break_first";
         plan.failureType = "opposite_break_first";
         plan.reason = "session_invalidated";
         plan.signalBlocked = true;
        }
     }

   if(!FillTradeLevels(plan, direction, stopAnchor))
      return false;

   EvaluateTargetPathObstacles(plan, scan);

   if(plan.entryTrigger == "neckline_break_retest")
      plan.failureType = "neckline_retest_failed";
   else if(StringFind(plan.entryTrigger, "choch") >= 0)
      plan.failureType = "choch_failed";
   else if(StringFind(plan.entryTrigger, "bos") >= 0)
      plan.failureType = "bos_pullback_failed";
   else if(StringFind(plan.entryTrigger, "sweep") >= 0)
      plan.failureType = "sweep_reclaim_failed";
   else
      plan.failureType = "no_followthrough_after_retest";

   if(plan.sessionInvalidated)
      plan.failureType = "opposite_break_first";
   if(plan.obstacleBlocked && UsesCleanTargetPath())
      plan.failureType = plan.obstacleBlockReason;

   if(plan.cleanPathToTarget)
      plan.score += 0.35;
   if(plan.minutesFromSessionStart < 60)
      plan.score += 0.20;

   plan.valid = true;
   return true;
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
                "server_time", "server_hour", "utc_hour", "jst_hour",
                "session_label", "session_start_utc", "minutes_from_session_start",
                "trade_window_label", "is_within_first_60min", "is_within_first_120min",
                "broker_utc_offset_used", "selected_symbol_for_session", "selected_reason",
                "session_candidate_symbol_map",
                "entry_pattern", "entry_trigger", "neckline_level",
                "ltf_wave3_timeframe", "htf_wave3_direction", "htf_wave3_confirmed",
                "htf_fractal_alignment", "wave3_alignment_passed",
                "htf_nearest_resistance", "htf_nearest_support",
                "nearest_obstacle_price", "nearest_obstacle_type", "nearest_obstacle_distance_price",
                "nearest_obstacle_distance_r", "retest_reference_type", "retest_reference_price",
                "clean_path_to_target",
                "hard_obstacle_present_before_target", "soft_obstacle_present_before_target",
                "obstacle_blocked", "obstacle_block_reason", "obstacle_count_before_target",
                "hard_obstacle_count_before_target", "soft_obstacle_count_before_target",
                "target_reward_multiple", "target_price", "entry_price", "stop_loss_price",
                "initial_risk_price_distance", "take_profit", "reward_r", "atr", "spread_points",
                "score", "result_r", "failure_type", "session_invalidated", "invalidation_reason",
                "reason");

   FileWrite(handle,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
             eventName,
             plan.strategy,
             plan.symbol,
             plan.direction,
             TimeToString(plan.serverTime, TIME_DATE | TIME_SECONDS),
             IntegerToString(plan.serverHour),
             IntegerToString(plan.utcHour),
             IntegerToString(plan.jstHour),
             plan.sessionLabel,
             TimeToString(plan.sessionStartUtc, TIME_DATE | TIME_MINUTES),
             IntegerToString(plan.minutesFromSessionStart),
             plan.tradeWindowLabel,
             BoolText(plan.isWithinFirst60),
             BoolText(plan.isWithinFirst120),
             IntegerToString(InpBrokerUtcOffsetHours),
             plan.selectedSymbolForSession,
             plan.selectedReason,
             plan.sessionCandidateSymbolMap,
             plan.entryPattern,
             plan.entryTrigger,
             DoubleToString(plan.necklineLevel, 8),
             plan.ltfWave3Timeframe,
             plan.htfWave3Direction,
             BoolText(plan.htfWave3Confirmed),
             plan.htfFractalAlignment,
             BoolText(plan.wave3AlignmentPassed),
             DoubleToString(plan.htfNearestResistance, 8),
             DoubleToString(plan.htfNearestSupport, 8),
             DoubleToString(plan.nearestObstaclePrice, 8),
             plan.nearestObstacleType,
             DoubleToString(plan.nearestObstacleDistancePrice, 8),
             DoubleToString(plan.nearestObstacleDistanceR, 4),
             plan.retestReferenceType,
             DoubleToString(plan.retestReferencePrice, 8),
             BoolText(plan.cleanPathToTarget),
             BoolText(plan.hardObstaclePresentBeforeTarget),
             BoolText(plan.softObstaclePresentBeforeTarget),
             BoolText(plan.obstacleBlocked),
             plan.obstacleBlockReason,
             IntegerToString(plan.obstacleCountBeforeTarget),
             IntegerToString(plan.hardObstacleCountBeforeTarget),
             IntegerToString(plan.softObstacleCountBeforeTarget),
             DoubleToString(plan.targetRewardMultiple, 2),
             DoubleToString(plan.targetPrice, 8),
             DoubleToString(plan.entry, 8),
             DoubleToString(plan.stopLoss, 8),
             DoubleToString(plan.initialRiskPriceDistance, 8),
             DoubleToString(plan.takeProfit, 8),
             DoubleToString(plan.rewardR, 3),
             DoubleToString(plan.atr, 8),
             DoubleToString(plan.spreadPoints, 2),
             DoubleToString(plan.score, 3),
             "0.0000",
             plan.failureType,
             BoolText(plan.sessionInvalidated),
             plan.invalidationReason,
             plan.reason);
   FileClose(handle);
  }

string ClassifyFailure(const TrackedTrade &tracked, const string exitReason, const double resultR)
  {
   if(tracked.sessionInvalidated)
      return "opposite_break_first";
   if(tracked.obstacleBlocked)
      return "obstacle_before_target";
   if(resultR <= 0.0)
     {
      if(StringFind(tracked.entryTrigger, "neckline") >= 0)
         return "neckline_retest_failed";
      if(StringFind(tracked.entryTrigger, "choch") >= 0)
         return "choch_failed";
      if(StringFind(tracked.entryTrigger, "bos") >= 0)
         return "bos_pullback_failed";
      if(StringFind(tracked.entryTrigger, "sweep") >= 0)
         return "sweep_reclaim_failed";
      return "no_followthrough_after_retest";
     }
   if(StringFind(exitReason, "TP") < 0 && resultR < tracked.rewardR * 0.5)
      return "target_not_reached_before_session_end";
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
                "server_time", "server_hour", "utc_hour", "jst_hour",
                "session_label", "session_start_utc", "minutes_from_session_start",
                "trade_window_label", "is_within_first_60min", "is_within_first_120min",
                "broker_utc_offset_used", "selected_symbol_for_session", "selected_reason",
                "session_candidate_symbol_map",
                "entry_pattern", "entry_trigger", "neckline_level",
                "ltf_wave3_timeframe", "htf_wave3_direction", "htf_wave3_confirmed",
                "htf_fractal_alignment", "wave3_alignment_passed",
                "htf_nearest_resistance", "htf_nearest_support",
                "nearest_obstacle_price", "nearest_obstacle_type", "nearest_obstacle_distance_r",
                "retest_reference_type", "retest_reference_price",
                "clean_path_to_target", "hard_obstacle_present_before_target",
                "soft_obstacle_present_before_target", "obstacle_blocked",
                "target_reward_multiple", "target_price",
                "entry", "exit", "stop_loss", "take_profit", "risk_price", "result_r",
                "profit", "commission", "swap", "net_profit", "volume", "reward_r",
                "holding_bars", "atr", "spread_points", "score", "failure_type",
                "session_invalidated", "invalidation_reason", "exit_reason", "position_id");

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
             TimeToString(tracked.serverTime, TIME_DATE | TIME_SECONDS),
             IntegerToString(tracked.serverHour),
             IntegerToString(tracked.utcHour),
             IntegerToString(tracked.jstHour),
             tracked.sessionLabel,
             TimeToString(tracked.sessionStartUtc, TIME_DATE | TIME_MINUTES),
             IntegerToString(tracked.minutesFromSessionStart),
             tracked.tradeWindowLabel,
             BoolText(tracked.isWithinFirst60),
             BoolText(tracked.isWithinFirst120),
             IntegerToString(InpBrokerUtcOffsetHours),
             tracked.selectedSymbolForSession,
             tracked.selectedReason,
             tracked.sessionCandidateSymbolMap,
             tracked.entryPattern,
             tracked.entryTrigger,
             DoubleToString(tracked.necklineLevel, 8),
             tracked.ltfWave3Timeframe,
             tracked.htfWave3Direction,
             BoolText(tracked.htfWave3Confirmed),
             tracked.htfFractalAlignment,
             BoolText(tracked.wave3AlignmentPassed),
             DoubleToString(tracked.htfNearestResistance, 8),
             DoubleToString(tracked.htfNearestSupport, 8),
             DoubleToString(tracked.nearestObstaclePrice, 8),
             tracked.nearestObstacleType,
             DoubleToString(tracked.nearestObstacleDistanceR, 4),
             tracked.retestReferenceType,
             DoubleToString(tracked.retestReferencePrice, 8),
             BoolText(tracked.cleanPathToTarget),
             BoolText(tracked.hardObstaclePresentBeforeTarget),
             BoolText(tracked.softObstaclePresentBeforeTarget),
             BoolText(tracked.obstacleBlocked),
             DoubleToString(tracked.targetRewardMultiple, 2),
             DoubleToString(tracked.targetPrice, 8),
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
             failureType,
             BoolText(tracked.sessionInvalidated),
             tracked.invalidationReason,
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
                "trade_window_label", "target_reward_multiple", "broker_utc_offset_used",
                "session_windows_mode", "require_h4_h1_wave3_alignment", "use_m5_lower_tf_wave3");

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
             TradeWindowLabel(),
             DoubleToString(EffectiveTargetRewardMultiple(), 2),
             IntegerToString(InpBrokerUtcOffsetHours),
             "non_exclusive_independent_start_windows",
             BoolText(InpRequireH4H1Wave3Alignment),
             BoolText(InpUseM5LowerTimeframeWave3));
   FileClose(handle);
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
   g_trades[size].entryTime = (datetime)PositionGetInteger(POSITION_TIME);
   g_trades[size].serverTime = plan.serverTime;
   g_trades[size].serverHour = plan.serverHour;
   g_trades[size].utcHour = plan.utcHour;
   g_trades[size].jstHour = plan.jstHour;
   g_trades[size].sessionLabel = plan.sessionLabel;
   g_trades[size].sessionStartUtc = plan.sessionStartUtc;
   g_trades[size].minutesFromSessionStart = plan.minutesFromSessionStart;
   g_trades[size].tradeWindowLabel = plan.tradeWindowLabel;
   g_trades[size].isWithinFirst60 = plan.isWithinFirst60;
   g_trades[size].isWithinFirst120 = plan.isWithinFirst120;
   g_trades[size].brokerUtcOffsetUsed = plan.brokerUtcOffsetUsed;
   g_trades[size].selectedSymbolForSession = plan.selectedSymbolForSession;
   g_trades[size].selectedReason = plan.selectedReason;
   g_trades[size].sessionCandidateSymbolMap = plan.sessionCandidateSymbolMap;
   g_trades[size].sessionCandidateSymbols = plan.sessionCandidateSymbols;
   g_trades[size].entryPattern = plan.entryPattern;
   g_trades[size].entryTrigger = plan.entryTrigger;
   g_trades[size].necklineLevel = plan.necklineLevel;
   g_trades[size].ltfWave3Direction = plan.ltfWave3Direction;
   g_trades[size].ltfWave3Timeframe = plan.ltfWave3Timeframe;
   g_trades[size].htfWave3Direction = plan.htfWave3Direction;
   g_trades[size].htfWave3Confirmed = plan.htfWave3Confirmed;
   g_trades[size].htfH4Wave3Direction = plan.htfH4Wave3Direction;
   g_trades[size].htfH1Wave3Direction = plan.htfH1Wave3Direction;
   g_trades[size].htfFractalAlignment = plan.htfFractalAlignment;
   g_trades[size].htfWave3BreakLevel = plan.htfWave3BreakLevel;
   g_trades[size].htfWave3PullbackLevel = plan.htfWave3PullbackLevel;
   g_trades[size].wave3AlignmentPassed = plan.wave3AlignmentPassed;
   g_trades[size].htfNearestResistance = plan.htfNearestResistance;
   g_trades[size].htfNearestSupport = plan.htfNearestSupport;
   g_trades[size].nearestObstaclePrice = plan.nearestObstaclePrice;
   g_trades[size].nearestObstacleType = plan.nearestObstacleType;
   g_trades[size].nearestObstacleDistanceR = plan.nearestObstacleDistanceR;
   g_trades[size].retestReferenceType = plan.retestReferenceType;
   g_trades[size].retestReferencePrice = plan.retestReferencePrice;
   g_trades[size].retestReferenceCount = plan.retestReferenceCount;
   g_trades[size].cleanPathToTarget = plan.cleanPathToTarget;
   g_trades[size].hardObstaclePresentBeforeTarget = plan.hardObstaclePresentBeforeTarget;
   g_trades[size].softObstaclePresentBeforeTarget = plan.softObstaclePresentBeforeTarget;
   g_trades[size].obstacleBlocked = plan.obstacleBlocked;
   g_trades[size].targetRewardMultiple = plan.targetRewardMultiple;
   g_trades[size].targetPrice = plan.targetPrice;
   g_trades[size].entryFailureType = plan.failureType;
   g_trades[size].sessionInvalidated = plan.sessionInvalidated;
   g_trades[size].invalidationReason = plan.invalidationReason;
   g_trades[size].positionId = (long)PositionGetInteger(POSITION_IDENTIFIER);
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
   if(plan.signalBlocked)
     {
      blockReason = plan.reason == "" ? "signal_blocked" : plan.reason;
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
      if(plan.failureType == "other")
         plan.failureType = blockReason;
      WriteSignalRow(plan, "blocked");
      MarkSessionConsumed(plan);
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
      MarkSessionConsumed(plan);
     }
   else
     {
      ++g_orderFailedCount;
      plan.reason = "order_failed_" + IntegerToString((int)trade.ResultRetcode());
      WriteSignalRow(plan, "order_failed");
      MarkSessionConsumed(plan);
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

   SignalPlan candidates[];
   ArrayResize(candidates, 0);

   for(int i = 0; i < ArraySize(g_symbols); ++i)
     {
      datetime barTime = 0;
      if(!LatestClosedBarTime(g_symbols[i], barTime))
         continue;
      if(barTime <= g_lastScannedBars[i])
         continue;
      g_lastScannedBars[i] = barTime;

      SessionInfo sessions[];
      if(BuildSessionInfos(barTime, sessions) <= 0)
         continue;

      for(int sessionIndex = 0; sessionIndex < ArraySize(sessions); ++sessionIndex)
        {
         SignalPlan plan;
         if(BuildSessionReversalSignal(g_symbols[i], sessions[sessionIndex], plan))
           {
            plan.valid = true;
            int size = ArraySize(candidates);
            ArrayResize(candidates, size + 1);
            candidates[size] = plan;
           }
        }
     }

   if(ArraySize(candidates) <= 0)
      return;

   if(!IsOneSymbolPerSessionScenario())
     {
      for(int i = 0; i < ArraySize(candidates); ++i)
        {
         candidates[i].selectedSymbolForSession = candidates[i].symbol;
         candidates[i].selectedReason = "all_symbols_symbol_session_one_shot";
         TryOpenSignal(candidates[i]);
        }
      return;
     }

   while(true)
     {
      int best = -1;
      double bestScore = -1.0;
      for(int i = 0; i < ArraySize(candidates); ++i)
        {
         if(HasKey(g_consumedSessionKeys, candidates[i].sessionKey))
            continue;
         if(candidates[i].score > bestScore)
           {
            best = i;
            bestScore = candidates[i].score;
           }
        }
      if(best < 0)
         return;

      string selected = SelectedSymbolForSession(candidates[best].sessionKey);
      if(selected == "")
        {
         selected = candidates[best].symbol;
         SetSelectedSymbolForSession(candidates[best].sessionKey, selected);
        }
      if(candidates[best].symbol != selected)
        {
         AddKey(g_consumedSessionKeys, candidates[best].sessionKey);
         continue;
        }

      candidates[best].selectedSymbolForSession = selected;
      candidates[best].selectedReason = "highest_score_in_session_bar";
      TryOpenSignal(candidates[best]);
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
      InpMAPeriodFast < 2 ||
      InpMAPeriodSlow <= InpMAPeriodFast ||
      InpStructureLookbackBars < 6 ||
      InpPatternLookbackBars < 12 ||
      InpSwingDepth < 1 ||
      InpHTFLookbackBars < 20 ||
      InpHTFWaveLookbackBars < 30 ||
      InpHTFWaveBreakBufferATR < 0.0 ||
      InpOpeningRangeMinutes < 5 ||
      InpPreSessionMinutes < 15 ||
      InpTargetRewardMultiple <= 0.0 ||
      InpEqualLevelTolerancePips < 0.0 ||
      InpEqualLevelToleranceATR < 0.0 ||
      InpRetestToleranceATR <= 0.0 ||
      InpBreakBufferATR < 0.0 ||
      InpStopBufferATR <= 0.0 ||
      InpMinSL_ATR <= 0.0 ||
      InpMaxSL_ATR < InpMinSL_ATR ||
      InpSessionInvalidationATR <= 0.0 ||
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

   PrintFormat("%s initialized scenario=%s symbols=%d risk=%.2f targetR=%.2f window=%s",
               STRATEGY_NAME,
               ScenarioModeName(),
               ArraySize(g_symbols),
               InpRiskPerTradePercent,
               EffectiveTargetRewardMultiple(),
               TradeWindowLabel());
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
