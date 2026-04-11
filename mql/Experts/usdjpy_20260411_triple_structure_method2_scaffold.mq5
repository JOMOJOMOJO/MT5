//+------------------------------------------------------------------+
//| USDJPY Triple Structure Method2 Scaffold                         |
//+------------------------------------------------------------------+
#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "1.00"
#property strict
#property description "Scaffold for HTF/LTF triple-top and inverse-triple-bottom structure trading with score-based entries."

#include <Trade\Trade.mqh>

CTrade trade;

enum EntryGradeMode
  {
   ENTRY_GRADE_STRONG_ONLY = 0,
   ENTRY_GRADE_STRONG_PLUS_STANDARD = 1
  };

struct PivotPoint
  {
   bool     valid;
   bool     isHigh;
   int      shift;
   double   price;
   datetime time;
  };

struct TrendContext
  {
   bool     valid;
   int      direction;
   PivotPoint latestHigh;
   PivotPoint previousHigh;
   PivotPoint latestLow;
   PivotPoint previousLow;
   double   emaFast;
   double   emaSlow;
   double   atr;
   double   rangeHigh;
   double   rangeLow;
   double   rangePosition;
  };

struct TriplePattern
  {
   bool     valid;
   int      direction;
   int      score;
   string   grade;
   PivotPoint extreme1;
   PivotPoint reaction1;
   PivotPoint extreme2;
   PivotPoint reaction2;
   PivotPoint extreme3;
   double   zoneCenter;
   double   tolerance;
   double   neckline;
   double   stopAnchor;
   bool     breakoutConfirmed;
   double   breakoutBodyPips;
   double   rangePosition;
   string   rangeBucket;
   string   breakoutType;
   string   label;
  };

struct EntryPlan
  {
   bool     valid;
   int      direction;
   int      score;
   string   tradeSide;
   double   entry;
   double   stop;
   double   target;
   string   grade;
   string   patternLabel;
   string   rangeBucket;
   string   breakoutType;
   double   stopDistancePips;
   double   breakoutBodyPips;
   string   reason;
  };

struct TradeTelemetryContext
  {
   bool     active;
   ulong    positionId;
   datetime entryTime;
   int      entryHour;
   int      score;
   string   tradeSide;
   string   grade;
   string   patternLabel;
   string   rangeBucket;
   string   breakoutType;
   double   stopDistancePips;
   double   breakoutBodyPips;
  };

input string          InpSymbol                       = "USDJPY";
input ENUM_TIMEFRAMES InpTrendTimeframe               = PERIOD_M15;
input ENUM_TIMEFRAMES InpSignalTimeframe              = PERIOD_M5;
input int             InpTrendPivotSpan               = 2;
input int             InpSignalPivotSpan              = 2;
input int             InpTrendScanBars                = 220;
input int             InpSignalScanBars               = 140;
input int             InpTrendFastEMAPeriod           = 20;
input int             InpTrendSlowEMAPeriod           = 50;
input int             InpTrendATRPeriod               = 14;
input int             InpSignalATRPeriod              = 14;
input int             InpRecentRangeBars              = 48;
input int             InpMinPivotGapBars              = 2;
input double          InpPatternToleranceATR          = 0.30;
input double          InpSoftPatternMultiplier        = 1.35;
input double          InpMinPatternPips               = 5.0;
input double          InpMinNeckDepthATR              = 0.35;
input double          InpMinNeckDepthPips             = 6.0;
input double          InpBreakBufferATR               = 0.08;
input double          InpMinBreakBufferPips           = 1.0;
input double          InpStopBufferATR                = 0.10;
input double          InpMinStopBufferPips            = 1.5;
input double          InpTargetRMultiple              = 1.6;
input int             InpStandardPatternScore         = 6;
input int             InpStrongPatternScore           = 8;
input EntryGradeMode  InpEntryGradeMode               = ENTRY_GRADE_STRONG_PLUS_STANDARD;
input double          InpRiskPercent                  = 0.35;
input int             InpSessionStartHour             = 7;
input int             InpSessionEndHour               = 23;
input string          InpBlockedEntryHours            = "";
input string          InpAllowedWeekdays              = "1,2,3,4,5";
input int             InpMaxTradesPerDay              = 4;
input double          InpMaxSpreadPips                = 2.2;
input int             InpMaxHoldBars                  = 24;
input bool            InpEnableLong                   = false;
input bool            InpEnableShort                  = true;
input bool            InpUseDailyLossCap              = true;
input double          InpDailyLossCapPercent          = 3.0;
input bool            InpUseEquityDrawdownCap         = true;
input double          InpEquityDrawdownCapPercent     = 8.0;
input bool            InpEnableTelemetry              = true;
input string          InpTelemetryFileName            = "mt5_company_usdjpy_20260411_triple_structure_method2_short.csv";
input long            InpMagicNumber                  = 202604111;

string runtimeSymbol = "";
string runtimeTelemetryFileName = "";
bool allowedWeekdays[7];
bool blockedEntryHours[24];
datetime lastSignalBarTime = 0;
datetime currentDayStart = 0;
double dailyStartEquity = 0.0;
double equityPeak = 0.0;
int dailyTradeCount = 0;
int telemetryHandle = INVALID_HANDLE;
TradeTelemetryContext pendingTelemetryContext;
TradeTelemetryContext activeTelemetryContext;
string pendingExitReason = "";

int htfAtrHandle = INVALID_HANDLE;
int htfFastEmaHandle = INVALID_HANDLE;
int htfSlowEmaHandle = INVALID_HANDLE;
int ltfAtrHandle = INVALID_HANDLE;

string NormalizePresetString(string rawValue)
  {
   int marker = StringFind(rawValue, "||");
   if(marker < 0)
      return rawValue;
   return StringSubstr(rawValue, 0, marker);
  }

void ResetBoolArray(bool &values[], bool defaultValue)
  {
   int count = ArraySize(values);
   for(int i = 0; i < count; ++i)
      values[i] = defaultValue;
  }

bool IsBlankString(string value)
  {
   string normalized = NormalizePresetString(value);
   StringReplace(normalized, " ", "");
   StringReplace(normalized, "\t", "");
   return (normalized == "");
  }

bool ParseIntegerCsv(string rawValue, bool &target[], int minValue, int maxValue)
  {
   ResetBoolArray(target, false);
   string normalized = NormalizePresetString(rawValue);
   if(IsBlankString(normalized))
      return true;

   string items[];
   int count = StringSplit(normalized, ',', items);
   if(count <= 0)
      return false;

   for(int i = 0; i < count; ++i)
     {
      string item = items[i];
      StringReplace(item, " ", "");
      if(item == "")
         continue;
      int value = (int)StringToInteger(item);
      if(value < minValue || value > maxValue)
         return false;
      target[value - minValue] = true;
     }

   return true;
  }

void ResetTradeTelemetryContext(TradeTelemetryContext &ctx)
  {
   ctx.active = false;
   ctx.positionId = 0;
   ctx.entryTime = 0;
   ctx.entryHour = -1;
   ctx.score = 0;
   ctx.tradeSide = "";
   ctx.grade = "";
   ctx.patternLabel = "";
   ctx.rangeBucket = "";
   ctx.breakoutType = "";
   ctx.stopDistancePips = 0.0;
   ctx.breakoutBodyPips = 0.0;
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
   int digits = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
  }

double PipsToPrice(double pips)
  {
   return pips * GetPipSize();
  }

double GetSpreadPips()
  {
   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   double pip = GetPipSize();
   if(ask <= 0.0 || bid <= 0.0 || pip <= 0.0)
      return DBL_MAX;
   return (ask - bid) / pip;
  }

string RangePositionBucket(double value)
  {
   if(value >= 0.80)
      return "upper";
   if(value >= 0.60)
      return "mid_upper";
   if(value >= 0.40)
      return "middle";
   if(value >= 0.20)
      return "mid_lower";
   return "lower";
  }

int GetMinimumEntryScore()
  {
   if(InpEntryGradeMode == ENTRY_GRADE_STRONG_ONLY)
      return InpStrongPatternScore;
   return InpStandardPatternScore;
  }

bool EntryScoreAllowed(int score)
  {
   return (score >= GetMinimumEntryScore());
  }

bool HourInWindow(int hour, int startHour, int endHour)
  {
   if(startHour == endHour)
      return true;
   if(startHour < endHour)
      return (hour >= startHour && hour < endHour);
   return (hour >= startHour || hour < endHour);
  }

bool IsBlockedHour(int hour)
  {
   if(hour < 0 || hour > 23)
      return false;
   return blockedEntryHours[hour];
  }

void InitializeDayState(datetime now)
  {
   MqlDateTime tm;
   TimeToStruct(now, tm);
   tm.hour = 0;
   tm.min = 0;
   tm.sec = 0;
   currentDayStart = StructToTime(tm);
   dailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   dailyTradeCount = 0;
  }

void UpdateDayState(datetime now)
  {
   if(currentDayStart == 0)
     {
      InitializeDayState(now);
      return;
     }

   if(now >= currentDayStart + 86400)
      InitializeDayState(now);
  }

void UpdateEquityPeak()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity > equityPeak)
      equityPeak = equity;
  }

bool LoadSingleBuffer(int handle, int shift, double &value)
  {
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handle, 0, shift, 1, buffer) != 1)
      return false;
   value = buffer[0];
   return (value > 0.0 || handle == htfFastEmaHandle || handle == htfSlowEmaHandle);
  }

bool IsNewBar(ENUM_TIMEFRAMES tf, datetime &barTime)
  {
   datetime times[];
   ArraySetAsSeries(times, true);
   if(CopyTime(runtimeSymbol, tf, 0, 2, times) < 2)
      return false;

   if(times[0] == lastSignalBarTime)
      return false;

   lastSignalBarTime = times[0];
   barTime = times[0];
   return true;
  }

bool IsPivotHigh(string symbol, ENUM_TIMEFRAMES tf, int shift, int span)
  {
   double center = iHigh(symbol, tf, shift);
   if(center <= 0.0)
      return false;

   for(int i = 1; i <= span; ++i)
     {
      if(center <= iHigh(symbol, tf, shift - i))
         return false;
      if(center <= iHigh(symbol, tf, shift + i))
         return false;
     }
   return true;
  }

bool IsPivotLow(string symbol, ENUM_TIMEFRAMES tf, int shift, int span)
  {
   double center = iLow(symbol, tf, shift);
   if(center <= 0.0)
      return false;

   for(int i = 1; i <= span; ++i)
     {
      if(center >= iLow(symbol, tf, shift - i))
         return false;
      if(center >= iLow(symbol, tf, shift + i))
         return false;
     }
   return true;
  }

void AppendPivot(PivotPoint &pivots[], const PivotPoint &pivot)
  {
   int size = ArraySize(pivots);
   ArrayResize(pivots, size + 1);
   pivots[size] = pivot;
  }

bool CollectConfirmedPivots(string symbol,
                            ENUM_TIMEFRAMES tf,
                            int span,
                            int scanBars,
                            PivotPoint &pivots[])
  {
   ArrayResize(pivots, 0);
   int bars = Bars(symbol, tf);
   if(bars <= span * 3 + 5)
      return false;

   int startShift = span + 1;
   int endShift = MathMin(scanBars, bars - span - 2);
   if(endShift <= startShift)
      return false;

   for(int shift = endShift; shift >= startShift; --shift)
     {
      if(IsPivotHigh(symbol, tf, shift, span))
        {
         PivotPoint pivot;
         pivot.valid = true;
         pivot.isHigh = true;
         pivot.shift = shift;
         pivot.price = iHigh(symbol, tf, shift);
         pivot.time = iTime(symbol, tf, shift);
         AppendPivot(pivots, pivot);
        }

      if(IsPivotLow(symbol, tf, shift, span))
        {
         PivotPoint pivot;
         pivot.valid = true;
         pivot.isHigh = false;
         pivot.shift = shift;
         pivot.price = iLow(symbol, tf, shift);
         pivot.time = iTime(symbol, tf, shift);
         AppendPivot(pivots, pivot);
        }
     }

   return (ArraySize(pivots) >= 5);
  }

bool FindLatestTypePivots(const PivotPoint &pivots[],
                          bool wantHigh,
                          PivotPoint &latest,
                          PivotPoint &previous)
  {
   latest.valid = false;
   previous.valid = false;
   int count = ArraySize(pivots);
   for(int i = count - 1; i >= 0; --i)
     {
      if(pivots[i].isHigh != wantHigh)
         continue;
      if(!latest.valid)
         latest = pivots[i];
      else
        {
         previous = pivots[i];
         break;
        }
     }
   return (latest.valid && previous.valid);
  }

int DetectDowTrend(const PivotPoint &latestHigh,
                   const PivotPoint &previousHigh,
                   const PivotPoint &latestLow,
                   const PivotPoint &previousLow)
  {
   if(!latestHigh.valid || !previousHigh.valid || !latestLow.valid || !previousLow.valid)
      return 0;

   if(latestHigh.price > previousHigh.price && latestLow.price > previousLow.price)
      return 1;

   if(latestHigh.price < previousHigh.price && latestLow.price < previousLow.price)
      return -1;

   return 0;
  }

double ComputeRangeHigh(ENUM_TIMEFRAMES tf, int startShift, int lookback)
  {
   double highest = -DBL_MAX;
   for(int shift = startShift; shift < startShift + lookback; ++shift)
     {
      double value = iHigh(runtimeSymbol, tf, shift);
      if(value <= 0.0)
         return DBL_MAX;
      if(value > highest)
         highest = value;
     }
   return highest;
  }

double ComputeRangeLow(ENUM_TIMEFRAMES tf, int startShift, int lookback)
  {
   double lowest = DBL_MAX;
   for(int shift = startShift; shift < startShift + lookback; ++shift)
     {
      double value = iLow(runtimeSymbol, tf, shift);
      if(value <= 0.0)
         return DBL_MAX;
      if(value < lowest)
         lowest = value;
     }
   return lowest;
  }

bool BuildTrendContext(TrendContext &ctx)
  {
   ctx.valid = false;

   PivotPoint pivots[];
   if(!CollectConfirmedPivots(runtimeSymbol, InpTrendTimeframe, InpTrendPivotSpan, InpTrendScanBars, pivots))
      return false;

   if(!FindLatestTypePivots(pivots, true, ctx.latestHigh, ctx.previousHigh))
      return false;
   if(!FindLatestTypePivots(pivots, false, ctx.latestLow, ctx.previousLow))
      return false;

   double atrValue = 0.0;
   double fastValue = 0.0;
   double slowValue = 0.0;
   if(!LoadSingleBuffer(htfAtrHandle, 1, atrValue) ||
      !LoadSingleBuffer(htfFastEmaHandle, 1, fastValue) ||
      !LoadSingleBuffer(htfSlowEmaHandle, 1, slowValue))
      return false;

   double rangeHigh = ComputeRangeHigh(InpTrendTimeframe, 1, InpRecentRangeBars);
   double rangeLow = ComputeRangeLow(InpTrendTimeframe, 1, InpRecentRangeBars);
   double currentClose = iClose(runtimeSymbol, InpTrendTimeframe, 1);
   if(rangeHigh == DBL_MAX || rangeLow == DBL_MAX || currentClose <= 0.0 || rangeHigh <= rangeLow)
      return false;

   ctx.direction = DetectDowTrend(ctx.latestHigh, ctx.previousHigh, ctx.latestLow, ctx.previousLow);
   ctx.emaFast = fastValue;
   ctx.emaSlow = slowValue;
   ctx.atr = atrValue;
   ctx.rangeHigh = rangeHigh;
   ctx.rangeLow = rangeLow;
   ctx.rangePosition = (currentClose - rangeLow) / (rangeHigh - rangeLow);
   ctx.valid = true;
   return true;
  }

double ComputePatternTolerance(double ltfAtr)
  {
   return MathMax(PipsToPrice(InpMinPatternPips), ltfAtr * InpPatternToleranceATR);
  }

double ComputeNeckDepthFloor(double ltfAtr)
  {
   return MathMax(PipsToPrice(InpMinNeckDepthPips), ltfAtr * InpMinNeckDepthATR);
  }

double ComputeBreakBuffer(double ltfAtr)
  {
   return MathMax(PipsToPrice(InpMinBreakBufferPips), ltfAtr * InpBreakBufferATR);
  }

double ComputeStopBuffer(double ltfAtr)
  {
   return MathMax(PipsToPrice(InpMinStopBufferPips), ltfAtr * InpStopBufferATR);
  }

double Max3(double a, double b, double c)
  {
   return MathMax(a, MathMax(b, c));
  }

double Min3(double a, double b, double c)
  {
   return MathMin(a, MathMin(b, c));
  }

string GradeFromScore(int score)
  {
   if(score >= InpStrongPatternScore)
      return "strong";
   if(score >= InpStandardPatternScore)
      return "standard";
   if(score >= InpStandardPatternScore - 1)
      return "soft";
   return "weak";
  }

int ExecutionQualityScore()
  {
   int score = 0;
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   if(!IsBlockedHour(tm.hour))
      score++;
   if(GetSpreadPips() <= InpMaxSpreadPips)
      score++;
   return MathMin(score, 1);
  }

bool SpacingOk(const PivotPoint &a, const PivotPoint &b)
  {
   return MathAbs(a.shift - b.shift) >= InpMinPivotGapBars;
  }

double BarBody(double openPrice, double closePrice)
  {
   return MathAbs(closePrice - openPrice);
  }

bool OpenTelemetryFile()
  {
   if(!InpEnableTelemetry)
      return false;
   if(telemetryHandle != INVALID_HANDLE)
      return true;

   telemetryHandle = FileOpen(runtimeTelemetryFileName,
                              FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_COMMON | FILE_ANSI,
                              ';');
   if(telemetryHandle == INVALID_HANDLE)
     {
      PrintFormat("Telemetry open failed for '%s' (%d)", runtimeTelemetryFileName, GetLastError());
      return false;
     }

   if(FileSize(telemetryHandle) == 0)
     {
      FileWrite(telemetryHandle,
                "timestamp",
                "event_type",
                "side",
                "position_id",
                "score",
                "grade",
                "pattern_label",
                "breakout_type",
                "range_bucket",
                "entry_hour",
                "stop_distance_pips",
                "breakout_body_pips",
                "price",
                "volume",
                "net_profit",
                "outcome",
                "reason",
                "note");
     }

   FileSeek(telemetryHandle, 0, SEEK_END);
   return true;
  }

void CloseTelemetryFile()
  {
   if(telemetryHandle != INVALID_HANDLE)
     {
      FileClose(telemetryHandle);
      telemetryHandle = INVALID_HANDLE;
     }
  }

void LogTelemetryEvent(datetime stamp,
                       string eventType,
                       string side,
                       ulong positionId,
                       int score,
                       string grade,
                       string patternLabel,
                       string breakoutType,
                       string rangeBucket,
                       int entryHour,
                       double stopDistancePips,
                       double breakoutBodyPips,
                       double price,
                       double volume,
                       double netProfit,
                       string outcome,
                       string reason,
                       string note)
  {
   if(!InpEnableTelemetry)
      return;
   if(!OpenTelemetryFile())
      return;

   FileSeek(telemetryHandle, 0, SEEK_END);
   FileWrite(telemetryHandle,
             TimeToString(stamp, TIME_DATE | TIME_SECONDS),
             eventType,
             side,
             (long)positionId,
             score,
             grade,
             patternLabel,
             breakoutType,
             rangeBucket,
             entryHour,
             stopDistancePips,
             breakoutBodyPips,
             price,
             volume,
             netProfit,
             outcome,
             reason,
             note);
   FileFlush(telemetryHandle);
  }

bool EvaluateTripleTop(const TrendContext &ctx, TriplePattern &bestPattern)
  {
   bestPattern.valid = false;
   if(!InpEnableShort)
      return false;

   PivotPoint pivots[];
   if(!CollectConfirmedPivots(runtimeSymbol, InpSignalTimeframe, InpSignalPivotSpan, InpSignalScanBars, pivots))
      return false;

   double ltfAtr = 0.0;
   if(!LoadSingleBuffer(ltfAtrHandle, 1, ltfAtr))
      return false;

   double tolerance = ComputePatternTolerance(ltfAtr);
   double depthFloor = ComputeNeckDepthFloor(ltfAtr);
   double breakBuffer = ComputeBreakBuffer(ltfAtr);
   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   double open1 = iOpen(runtimeSymbol, InpSignalTimeframe, 1);
   double high1 = iHigh(runtimeSymbol, InpSignalTimeframe, 1);
   double low1 = iLow(runtimeSymbol, InpSignalTimeframe, 1);
   if(close1 <= 0.0 || open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   int bestScore = -1;
   double bestBreakBodyPips = -1.0;
   int count = ArraySize(pivots);
   for(int i = count - 1; i >= 4; --i)
     {
      PivotPoint p0 = pivots[i - 4];
      PivotPoint p1 = pivots[i - 3];
      PivotPoint p2 = pivots[i - 2];
      PivotPoint p3 = pivots[i - 1];
      PivotPoint p4 = pivots[i];

      if(!(p0.isHigh && !p1.isHigh && p2.isHigh && !p3.isHigh && p4.isHigh))
         continue;
      if(!(SpacingOk(p0, p1) && SpacingOk(p1, p2) && SpacingOk(p2, p3) && SpacingOk(p3, p4)))
         continue;

      double zoneCenter = (p0.price + p2.price + p4.price) / 3.0;
      double maxDeviation = Max3(MathAbs(p0.price - zoneCenter),
                                 MathAbs(p2.price - zoneCenter),
                                 MathAbs(p4.price - zoneCenter));
      if(maxDeviation > tolerance * InpSoftPatternMultiplier)
         continue;

      double neckline = MathMin(p1.price, p3.price);
      double neckDepth = zoneCenter - MathMax(p1.price, p3.price);
      bool breakoutConfirmed = (close1 < neckline - breakBuffer);
      bool weakBreak = (low1 < neckline - breakBuffer && close1 < neckline + breakBuffer * 0.25);
      bool failureClear = (p4.price <= MathMax(p0.price, p2.price) + tolerance * 0.25);
      double breakBodyPips = BarBody(open1, close1) / GetPipSize();

      int score = 0;
      if(ctx.rangePosition >= 0.25 && ctx.rangePosition <= 0.60)
         score += 2;
      else if(ctx.rangePosition > 0.60 && ctx.rangePosition <= 0.75)
         score += 1;

      if(ctx.latestHigh.price <= ctx.previousHigh.price)
         score += 1;
      if(ctx.emaFast <= ctx.emaSlow)
         score += 1;

      if(maxDeviation <= tolerance)
         score += 3;
      else
         score += 2;

      if(neckDepth >= depthFloor)
         score += 1;
      if(failureClear)
         score += 1;

      if(breakoutConfirmed && BarBody(open1, close1) >= breakBuffer)
         score += 2;
      else if(weakBreak)
         score += 1;

      score += ExecutionQualityScore();

      if(score > bestScore || (score == bestScore && breakBodyPips > bestBreakBodyPips))
        {
         bestScore = score;
         bestBreakBodyPips = breakBodyPips;
         bestPattern.valid = true;
         bestPattern.direction = -1;
         bestPattern.score = score;
         bestPattern.grade = GradeFromScore(score);
         bestPattern.extreme1 = p0;
         bestPattern.reaction1 = p1;
         bestPattern.extreme2 = p2;
         bestPattern.reaction2 = p3;
         bestPattern.extreme3 = p4;
         bestPattern.zoneCenter = zoneCenter;
         bestPattern.tolerance = tolerance;
         bestPattern.neckline = neckline;
         bestPattern.stopAnchor = Max3(p0.price, p2.price, p4.price);
         bestPattern.breakoutConfirmed = breakoutConfirmed;
         bestPattern.breakoutBodyPips = breakBodyPips;
         bestPattern.rangePosition = ctx.rangePosition;
         bestPattern.rangeBucket = RangePositionBucket(ctx.rangePosition);
         bestPattern.breakoutType = breakoutConfirmed ? "close_break" : "wick_break";
         bestPattern.label = "triple_top";
        }
     }

   return bestPattern.valid;
  }

bool EvaluateInverseTripleBottom(const TrendContext &ctx, TriplePattern &bestPattern)
  {
   bestPattern.valid = false;
   if(!InpEnableLong)
      return false;

   PivotPoint pivots[];
   if(!CollectConfirmedPivots(runtimeSymbol, InpSignalTimeframe, InpSignalPivotSpan, InpSignalScanBars, pivots))
      return false;

   double ltfAtr = 0.0;
   if(!LoadSingleBuffer(ltfAtrHandle, 1, ltfAtr))
      return false;

   double tolerance = ComputePatternTolerance(ltfAtr);
   double depthFloor = ComputeNeckDepthFloor(ltfAtr);
   double breakBuffer = ComputeBreakBuffer(ltfAtr);
   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   double open1 = iOpen(runtimeSymbol, InpSignalTimeframe, 1);
   double high1 = iHigh(runtimeSymbol, InpSignalTimeframe, 1);
   double low1 = iLow(runtimeSymbol, InpSignalTimeframe, 1);
   if(close1 <= 0.0 || open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   int bestScore = -1;
   double bestBreakBodyPips = -1.0;
   int count = ArraySize(pivots);
   for(int i = count - 1; i >= 4; --i)
     {
      PivotPoint p0 = pivots[i - 4];
      PivotPoint p1 = pivots[i - 3];
      PivotPoint p2 = pivots[i - 2];
      PivotPoint p3 = pivots[i - 1];
      PivotPoint p4 = pivots[i];

      if(!(!p0.isHigh && p1.isHigh && !p2.isHigh && p3.isHigh && !p4.isHigh))
         continue;
      if(!(SpacingOk(p0, p1) && SpacingOk(p1, p2) && SpacingOk(p2, p3) && SpacingOk(p3, p4)))
         continue;

      double zoneCenter = (p0.price + p2.price + p4.price) / 3.0;
      double maxDeviation = Max3(MathAbs(p0.price - zoneCenter),
                                 MathAbs(p2.price - zoneCenter),
                                 MathAbs(p4.price - zoneCenter));
      if(maxDeviation > tolerance * InpSoftPatternMultiplier)
         continue;

      double neckline = MathMax(p1.price, p3.price);
      double neckDepth = MathMin(p1.price, p3.price) - zoneCenter;
      bool breakoutConfirmed = (close1 > neckline + breakBuffer);
      bool weakBreak = (high1 > neckline + breakBuffer && close1 > neckline - breakBuffer * 0.25);
      bool failureClear = (p4.price >= MathMin(p0.price, p2.price) - tolerance * 0.25);
      double breakBodyPips = BarBody(open1, close1) / GetPipSize();

      int score = 0;
      if(ctx.rangePosition <= 0.35)
         score += 2;
      else if(ctx.rangePosition <= 0.45)
         score += 1;

      if(ctx.latestLow.price < ctx.previousLow.price)
         score += 1;
      if(ctx.emaFast <= ctx.emaSlow)
         score += 1;

      if(maxDeviation <= tolerance)
         score += 3;
      else
         score += 2;

      if(neckDepth >= depthFloor)
         score += 1;
      if(failureClear)
         score += 1;

      if(breakoutConfirmed && BarBody(open1, close1) >= breakBuffer)
         score += 2;
      else if(weakBreak)
         score += 1;

      score += ExecutionQualityScore();

      if(score > bestScore || (score == bestScore && breakBodyPips > bestBreakBodyPips))
        {
         bestScore = score;
         bestBreakBodyPips = breakBodyPips;
         bestPattern.valid = true;
         bestPattern.direction = 1;
         bestPattern.score = score;
         bestPattern.grade = GradeFromScore(score);
         bestPattern.extreme1 = p0;
         bestPattern.reaction1 = p1;
         bestPattern.extreme2 = p2;
         bestPattern.reaction2 = p3;
         bestPattern.extreme3 = p4;
         bestPattern.zoneCenter = zoneCenter;
         bestPattern.tolerance = tolerance;
         bestPattern.neckline = neckline;
         bestPattern.stopAnchor = Min3(p0.price, p2.price, p4.price);
         bestPattern.breakoutConfirmed = breakoutConfirmed;
         bestPattern.breakoutBodyPips = breakBodyPips;
         bestPattern.rangePosition = ctx.rangePosition;
         bestPattern.rangeBucket = RangePositionBucket(ctx.rangePosition);
         bestPattern.breakoutType = breakoutConfirmed ? "close_break" : "wick_break";
         bestPattern.label = "inverse_triple_bottom";
        }
     }

   return bestPattern.valid;
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

bool PassGlobalGuards()
  {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);

   if(tm.day_of_week < 0 || tm.day_of_week > 6 || !allowedWeekdays[tm.day_of_week])
      return false;
   if(IsBlockedHour(tm.hour))
      return false;
   if(!HourInWindow(tm.hour, InpSessionStartHour, InpSessionEndHour))
      return false;
   if(GetSpreadPips() > InpMaxSpreadPips)
      return false;
   if(CountManagedPositions() > 0)
      return false;
   if(InpMaxTradesPerDay > 0 && dailyTradeCount >= InpMaxTradesPerDay)
      return false;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(InpUseDailyLossCap && dailyStartEquity > 0.0)
     {
      double dailyLossPct = 100.0 * (dailyStartEquity - equity) / dailyStartEquity;
      if(dailyLossPct >= InpDailyLossCapPercent)
         return false;
     }

   if(InpUseEquityDrawdownCap && equityPeak > 0.0)
     {
      double ddPct = 100.0 * (equityPeak - equity) / equityPeak;
      if(ddPct >= InpEquityDrawdownCapPercent)
         return false;
     }

   return true;
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

double CalculateVolumeByRisk(double entry, double stop)
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
   double stopDistance = MathAbs(entry - stop);
   if(tickSize <= 0.0 || tickValue <= 0.0 || stopDistance <= 0.0 ||
      minVolume <= 0.0 || maxVolume <= 0.0 || stepVolume <= 0.0)
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

bool BuildEntryPlan(const TriplePattern &pattern, EntryPlan &plan)
  {
   plan.valid = false;
   if(!pattern.valid || !EntryScoreAllowed(pattern.score) || !pattern.breakoutConfirmed)
      return false;

   double ltfAtr = 0.0;
   if(!LoadSingleBuffer(ltfAtrHandle, 1, ltfAtr))
      return false;
   double stopBuffer = ComputeStopBuffer(ltfAtr);

   plan.direction = pattern.direction;
   plan.score = pattern.score;
   plan.tradeSide = (pattern.direction < 0) ? "short" : "long";
   plan.grade = pattern.grade;
   plan.patternLabel = pattern.label;
   plan.rangeBucket = pattern.rangeBucket;
   plan.breakoutType = pattern.breakoutType;
   plan.breakoutBodyPips = pattern.breakoutBodyPips;
   plan.reason = pattern.label + "_" + pattern.grade + "_s" + IntegerToString(pattern.score);

   if(pattern.direction < 0)
     {
      double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
      if(bid <= 0.0)
         return false;
      plan.entry = NormalizePrice(bid);
      plan.stop = NormalizePrice(pattern.stopAnchor + stopBuffer);
      if(plan.stop <= plan.entry)
         return false;
      double risk = plan.stop - plan.entry;
      plan.stopDistancePips = risk / GetPipSize();
      plan.target = NormalizePrice(plan.entry - risk * InpTargetRMultiple);
     }
   else if(pattern.direction > 0)
     {
      double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
      if(ask <= 0.0)
         return false;
      plan.entry = NormalizePrice(ask);
      plan.stop = NormalizePrice(pattern.stopAnchor - stopBuffer);
      if(plan.stop >= plan.entry)
         return false;
      double risk = plan.entry - plan.stop;
      plan.stopDistancePips = risk / GetPipSize();
      plan.target = NormalizePrice(plan.entry + risk * InpTargetRMultiple);
     }
   else
      return false;

   plan.valid = true;
   return true;
  }

bool ExecuteEntry(const EntryPlan &plan)
  {
   if(!plan.valid)
      return false;

   double volume = CalculateVolumeByRisk(plan.entry, plan.stop);
   if(volume <= 0.0)
      return false;

   bool result = false;
   pendingTelemetryContext.active = true;
   pendingTelemetryContext.positionId = 0;
   pendingTelemetryContext.entryTime = TimeCurrent();
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   pendingTelemetryContext.entryHour = tm.hour;
   pendingTelemetryContext.score = plan.score;
   pendingTelemetryContext.tradeSide = plan.tradeSide;
   pendingTelemetryContext.grade = plan.grade;
   pendingTelemetryContext.patternLabel = plan.patternLabel;
   pendingTelemetryContext.rangeBucket = plan.rangeBucket;
   pendingTelemetryContext.breakoutType = plan.breakoutType;
   pendingTelemetryContext.stopDistancePips = plan.stopDistancePips;
   pendingTelemetryContext.breakoutBodyPips = plan.breakoutBodyPips;
   if(plan.direction > 0)
      result = trade.Buy(volume, runtimeSymbol, 0.0, plan.stop, plan.target, plan.reason);
   else if(plan.direction < 0)
      result = trade.Sell(volume, runtimeSymbol, 0.0, plan.stop, plan.target, plan.reason);

   if(result)
      dailyTradeCount++;
   else
      ResetTradeTelemetryContext(pendingTelemetryContext);

   return result;
  }

void ManageOpenPositions()
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
      int barsSinceEntry = iBarShift(runtimeSymbol, InpSignalTimeframe, openedAt, false);
      if(barsSinceEntry >= InpMaxHoldBars && barsSinceEntry >= 0)
        {
         pendingExitReason = "time_stop";
         trade.PositionClose(runtimeSymbol);
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

   string symbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
   if(symbol != runtimeSymbol)
      return;

   long magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if(magic != InpMagicNumber)
      return;

   ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   ulong positionId = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   datetime dealTime = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
   double price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
   double volume = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) +
                   HistoryDealGetDouble(trans.deal, DEAL_SWAP) +
                   HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   string comment = HistoryDealGetString(trans.deal, DEAL_COMMENT);

   if(dealEntry == DEAL_ENTRY_IN || dealEntry == DEAL_ENTRY_INOUT)
     {
      if(pendingTelemetryContext.active)
        {
         activeTelemetryContext = pendingTelemetryContext;
         activeTelemetryContext.active = true;
         activeTelemetryContext.positionId = positionId;
         activeTelemetryContext.entryTime = dealTime;
         LogTelemetryEvent(dealTime,
                           "entry",
                           activeTelemetryContext.tradeSide,
                           positionId,
                           activeTelemetryContext.score,
                           activeTelemetryContext.grade,
                           activeTelemetryContext.patternLabel,
                           activeTelemetryContext.breakoutType,
                           activeTelemetryContext.rangeBucket,
                           activeTelemetryContext.entryHour,
                           activeTelemetryContext.stopDistancePips,
                           activeTelemetryContext.breakoutBodyPips,
                           price,
                           volume,
                           0.0,
                           "",
                           comment,
                           "");
         ResetTradeTelemetryContext(pendingTelemetryContext);
        }
      return;
     }

   if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_OUT_BY || dealEntry == DEAL_ENTRY_INOUT)
     {
      string outcome = "flat";
      if(profit > 0.0)
         outcome = "win";
      else if(profit < 0.0)
         outcome = "loss";

      string reason = comment;
      if(reason == "" && pendingExitReason != "")
         reason = pendingExitReason;

      LogTelemetryEvent(dealTime,
                        "exit",
                        activeTelemetryContext.tradeSide,
                        positionId,
                        activeTelemetryContext.score,
                        activeTelemetryContext.grade,
                        activeTelemetryContext.patternLabel,
                        activeTelemetryContext.breakoutType,
                        activeTelemetryContext.rangeBucket,
                        activeTelemetryContext.entryHour,
                        activeTelemetryContext.stopDistancePips,
                        activeTelemetryContext.breakoutBodyPips,
                        price,
                        volume,
                        profit,
                        outcome,
                        reason,
                        "");

      pendingExitReason = "";
      if(activeTelemetryContext.active && (activeTelemetryContext.positionId == 0 || activeTelemetryContext.positionId == positionId))
         ResetTradeTelemetryContext(activeTelemetryContext);
     }
  }

int OnInit()
  {
   runtimeSymbol = NormalizePresetString(InpSymbol);
   runtimeTelemetryFileName = NormalizePresetString(InpTelemetryFileName);
   ResetTradeTelemetryContext(pendingTelemetryContext);
   ResetTradeTelemetryContext(activeTelemetryContext);

   if(InpMagicNumber <= 0 || InpTrendPivotSpan <= 0 || InpSignalPivotSpan <= 0 ||
      InpTrendATRPeriod <= 0 || InpSignalATRPeriod <= 0 || InpTargetRMultiple <= 0.0 ||
      InpRiskPercent <= 0.0 || InpStandardPatternScore <= 0 || InpStrongPatternScore < InpStandardPatternScore)
     {
      Print("Invalid Method2 triple structure parameters.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!ParseIntegerCsv(InpAllowedWeekdays, allowedWeekdays, 0, 6))
     {
      Print("Invalid weekday filter.");
      return INIT_PARAMETERS_INCORRECT;
     }

   ResetBoolArray(blockedEntryHours, false);
   if(!IsBlankString(InpBlockedEntryHours))
     {
      if(!ParseIntegerCsv(InpBlockedEntryHours, blockedEntryHours, 0, 23))
        {
         Print("Invalid blocked hour filter.");
         return INIT_PARAMETERS_INCORRECT;
        }
     }

   trade.SetExpertMagicNumber((ulong)InpMagicNumber);

   htfAtrHandle = iATR(runtimeSymbol, InpTrendTimeframe, InpTrendATRPeriod);
   htfFastEmaHandle = iMA(runtimeSymbol, InpTrendTimeframe, InpTrendFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   htfSlowEmaHandle = iMA(runtimeSymbol, InpTrendTimeframe, InpTrendSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   ltfAtrHandle = iATR(runtimeSymbol, InpSignalTimeframe, InpSignalATRPeriod);
   if(htfAtrHandle == INVALID_HANDLE || htfFastEmaHandle == INVALID_HANDLE ||
      htfSlowEmaHandle == INVALID_HANDLE || ltfAtrHandle == INVALID_HANDLE)
     {
      Print("Failed to create indicator handles.");
      return INIT_FAILED;
     }

   InitializeDayState(TimeCurrent());
   equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);
   if(InpEnableTelemetry && !OpenTelemetryFile())
      Print("Telemetry file could not be opened. Continuing without telemetry.");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(htfAtrHandle != INVALID_HANDLE)
      IndicatorRelease(htfAtrHandle);
   if(htfFastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(htfFastEmaHandle);
   if(htfSlowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(htfSlowEmaHandle);
   if(ltfAtrHandle != INVALID_HANDLE)
      IndicatorRelease(ltfAtrHandle);
   CloseTelemetryFile();
  }

void OnTick()
  {
   datetime barTime;
   if(!IsNewBar(InpSignalTimeframe, barTime))
      return;

   UpdateDayState(TimeCurrent());
   UpdateEquityPeak();
   ManageOpenPositions();

   if(!PassGlobalGuards())
      return;

   TrendContext ctx;
   if(!BuildTrendContext(ctx))
      return;

   EntryPlan bestPlan;
   bestPlan.valid = false;

   if(InpEnableShort)
     {
      TriplePattern shortPattern;
      if(EvaluateTripleTop(ctx, shortPattern))
        {
         EntryPlan shortPlan;
         if(BuildEntryPlan(shortPattern, shortPlan))
            bestPlan = shortPlan;
        }
     }

   if(InpEnableLong)
     {
      TriplePattern longPattern;
      if(EvaluateInverseTripleBottom(ctx, longPattern))
        {
         EntryPlan longPlan;
         if(BuildEntryPlan(longPattern, longPlan))
           {
            if(!bestPlan.valid || longPlan.score > bestPlan.score)
               bestPlan = longPlan;
           }
        }
     }

   if(bestPlan.valid)
      ExecuteEntry(bestPlan);
  }
