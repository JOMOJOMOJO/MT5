//+------------------------------------------------------------------+
//| BTCUSD Compression Breakout Prototype                           |
//+------------------------------------------------------------------+
#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "1.00"
#property strict
#property description "BTCUSD M5 compression breakout family with London continuation longs and optional NY compression shorts"

#include <Trade\Trade.mqh>

CTrade trade;

enum LongRuleMode
  {
   LongRuleEmaGap2050 = 0,
   LongRuleRet24 = 1,
   LongRuleMacdAtr = 2,
   LongRuleEmaGap50100 = 3,
   LongRuleCloseVsEma50 = 4,
   LongRuleLowBreak24 = 5,
   LongRuleBreakoutPersistDown6 = 6,
   LongRuleRocAtr6 = 7,
   LongRuleHighBreak12 = 8,
   LongRuleBreakoutFollowthroughDown = 9,
   LongRuleBreakoutFollowthroughUp = 10
  };

enum ShortRuleMode
  {
   ShortRuleMacdAtr = 0,
   ShortRuleHighBreak24 = 1,
   ShortRuleTickVolumeZ = 2,
   ShortRuleCloseLocation = 3,
   ShortRuleRangeCompression12 = 4
  };

input string          InpSymbol                      = "BTCUSD";
input ENUM_TIMEFRAMES InpSignalTimeframe             = PERIOD_M5;
input int             InpATRPeriod                   = 14;

input bool            InpEnableLong                  = true;
input int             InpLongStartHour               = 8;
input int             InpLongEndHour                 = 16;
input int             InpLongRuleMode               = LongRuleBreakoutFollowthroughUp;
input double          InpLongEmaGap2050Max          = -1.3698;
input double          InpLongRet24Max               = -0.0057;
input double          InpLongMacdLineAtrMax         = -0.8699;
input double          InpLongEmaGap50100Max         = -1.6928;
input double          InpLongCloseVsEma50Max        = -1.7790;
input double          InpLongLowBreak24Max          = 1.0065;
input double          InpLongBreakoutPersistDown6Min = 1.0;
input double          InpLongRocAtr6Max             = -1.3740;
input double          InpLongHighBreak12Max         = -3.0688;
input double          InpLongBreakoutFollowthroughDownMin = 0.1433;
input double          InpLongBreakoutFollowthroughUpMin = 0.30;
input bool            InpUseLongStochDFilter        = true;
input double          InpLongStochDMax              = 100.0;
input bool            InpUseLongBbZFilter           = false;
input double          InpLongBbZMax                 = -1.55;
input bool            InpUseLongEma20SlopeFilter    = false;
input double          InpLongEma20Slope3Max         = -0.3403;
input bool            InpUseLongRsi7Filter          = false;
input double          InpLongRsi7Max                = 29.5750;
input bool            InpUseLongRet6Filter          = false;
input double          InpLongRet6Max                = -0.0016;
input bool            InpUseLongHighBreak12Filter   = false;
input double          InpLongHighBreak12FilterMax   = -3.0688;
input bool            InpUseLongHighBreakFilter     = false;
input double          InpLongHighBreak24Max         = -5.23;
input bool            InpUseLongRangeCompression24Filter = true;
input double          InpLongRangeCompression24Max  = 0.0120;
input bool            InpUseLongTickFlowFilter      = false;
input double          InpLongTickFlowMax            = -0.33;
input bool            InpUseLongTickVolumeFilter    = false;
input double          InpLongTickVolumeMin          = 0.33;
input int             InpLongHoldBars               = 12;
input double          InpLongStopATR                = 2.00;
input double          InpLongTargetRMultiple        = 0.00;

input bool            InpEnableShort                 = false;
input int             InpShortStartHour              = 13;
input int             InpShortEndHour                = 22;
input int             InpShortRuleMode              = ShortRuleCloseLocation;
input double          InpShortMacdLineAtrMin        = 0.9665;
input double          InpShortHighBreak24Min        = -0.3645;
input double          InpShortTickVolumeZMin        = 1.5444;
input double          InpShortCloseLocationMin      = 0.7589;
input double          InpShortRangeCompression12Max = 0.0075;
input bool            InpUseShortFlowFilter         = false;
input double          InpShortTickFlowMin           = 0.20;
input int             InpShortHoldBars              = 12;
input double          InpShortStopATR               = 1.50;
input double          InpShortTargetRMultiple       = 0.00;

input double          InpRiskPercent                = 0.35;
input bool            InpSkipTradeWhenMinLotRiskTooHigh = true;
input double          InpMaxEffectiveRiskPercentAtMinLot = 1.00;

input bool            InpUseDailyLossCap            = true;
input double          InpDailyLossCapPercent        = 3.0;
input bool            InpUseEquityKillSwitch        = true;
input double          InpEquityKillSwitchPercent    = 12.0;
input int             InpMaxTradesPerDay            = 60;
input int             InpMaxOpenTrades              = 1;
input int             InpMaxOpenPerSide             = 1;
input double          InpMaxSpreadPips             = 2500.0;
input double          InpMaxDeviationPips          = 250.0;
input string          InpAllowedWeekdays           = "0,1,2,3,4,5,6";
input string          InpBlockedEntryHours         = "";
input long            InpMagicNumber               = 20260451;

int atrHandle = INVALID_HANDLE;
int ema20Handle = INVALID_HANDLE;
int ema50Handle = INVALID_HANDLE;
int ema100Handle = INVALID_HANDLE;
int macdHandle = INVALID_HANDLE;
int stochHandle = INVALID_HANDLE;
int bandsHandle = INVALID_HANDLE;
int rsi7Handle = INVALID_HANDLE;

bool allowedWeekdays[7];
bool blockedHours[24];
string runtimeSymbol = "";
string runtimeAllowedWeekdays = "";
string runtimeBlockedEntryHours = "";
datetime lastBarTime = 0;
datetime currentDayStart = 0;
double dailyStartEquity = 0.0;
double equityPeak = 0.0;
int dailyTradeCount = 0;

struct SignalContext
  {
   datetime barTime;
   int      hour;
   int      weekday;
   double   close;
   double   atr;
   double   ret6;
   double   ret24;
   double   rocAtr6;
   double   emaGap2050;
   double   emaGap50100;
   double   closeVsEma50;
   double   ema20Slope3;
   double   rsi7;
   double   macdLineAtr;
   double   bbZ;
   double   stochD;
   double   closeLocation;
   double   rangeCompression12;
   double   rangeCompression24;
   double   highBreak12;
   double   highBreak24;
   double   lowBreak24;
   double   breakoutPersistDown6;
   double   breakoutFollowthroughUp;
   double   breakoutFollowthroughDown;
   double   tickVolumeZ;
   double   tickFlowSigned3;
  };

int OnInit()
  {
   runtimeSymbol = NormalizePresetString(InpSymbol);
   runtimeAllowedWeekdays = NormalizePresetString(InpAllowedWeekdays);
   runtimeBlockedEntryHours = NormalizePresetString(InpBlockedEntryHours);
   ArrayInitialize(allowedWeekdays, false);
   ArrayInitialize(blockedHours, false);

   if(InpMagicNumber <= 0 || InpATRPeriod <= 0 || InpRiskPercent <= 0.0 ||
      InpLongHoldBars < 0 || InpShortHoldBars < 0 || InpLongStopATR <= 0.0 || InpShortStopATR <= 0.0 ||
      InpLongTargetRMultiple < 0.0 || InpShortTargetRMultiple < 0.0 || InpMaxTradesPerDay < 0 ||
      InpMaxOpenTrades < 0 || InpMaxOpenPerSide < 0 || InpMaxEffectiveRiskPercentAtMinLot < 0.0 ||
      InpLongRuleMode < LongRuleEmaGap2050 || InpLongRuleMode > LongRuleBreakoutFollowthroughUp ||
      InpShortRuleMode < ShortRuleMacdAtr || InpShortRuleMode > ShortRuleRangeCompression12)
     {
      Print("Invalid regime-single parameters.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!ParseIntList(runtimeAllowedWeekdays, allowedWeekdays, 7) || !ParseIntList(runtimeBlockedEntryHours, blockedHours, 24))
     {
      Print("Invalid weekday or blocked-hour filters.");
      return INIT_PARAMETERS_INCORRECT;
     }

   trade.SetExpertMagicNumber((ulong)InpMagicNumber);
   SetTradeDeviation();

   atrHandle = iATR(runtimeSymbol, InpSignalTimeframe, InpATRPeriod);
   ema20Handle = iMA(runtimeSymbol, InpSignalTimeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
   ema50Handle = iMA(runtimeSymbol, InpSignalTimeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
   ema100Handle = iMA(runtimeSymbol, InpSignalTimeframe, 100, 0, MODE_EMA, PRICE_CLOSE);
   macdHandle = iMACD(runtimeSymbol, InpSignalTimeframe, 12, 26, 9, PRICE_CLOSE);
   stochHandle = iStochastic(runtimeSymbol, InpSignalTimeframe, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
   bandsHandle = iBands(runtimeSymbol, InpSignalTimeframe, 20, 0, 2.0, PRICE_CLOSE);
   rsi7Handle = iRSI(runtimeSymbol, InpSignalTimeframe, 7, PRICE_CLOSE);

   if(atrHandle == INVALID_HANDLE || ema20Handle == INVALID_HANDLE || ema50Handle == INVALID_HANDLE ||
      ema100Handle == INVALID_HANDLE || macdHandle == INVALID_HANDLE || stochHandle == INVALID_HANDLE ||
      bandsHandle == INVALID_HANDLE || rsi7Handle == INVALID_HANDLE)
     {
      Print("Failed to create indicator handles.");
      return INIT_FAILED;
     }

   InitializeDayState(TimeCurrent());
   equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);
   return INIT_SUCCEEDED;
  }

string NormalizePresetString(string rawValue)
  {
   int marker = StringFind(rawValue, "||");
   if(marker < 0)
      return rawValue;
   return StringSubstr(rawValue, 0, marker);
  }

void OnDeinit(const int reason)
  {
   ReleaseHandle(atrHandle);
   ReleaseHandle(ema20Handle);
   ReleaseHandle(ema50Handle);
   ReleaseHandle(ema100Handle);
   ReleaseHandle(macdHandle);
   ReleaseHandle(stochHandle);
   ReleaseHandle(bandsHandle);
   ReleaseHandle(rsi7Handle);
  }

void OnTick()
  {
   UpdateDayState(TimeCurrent());
   UpdateEquityPeak();
   ManageTimedExits();

   datetime currentBar = iTime(runtimeSymbol, InpSignalTimeframe, 0);
   if(currentBar == 0 || currentBar == lastBarTime)
      return;

   lastBarTime = currentBar;

   SignalContext ctx;
   if(!LoadSignalContext(ctx))
      return;

   if(!CanOpenNewEntries(ctx))
      return;

   bool longSignal = IsLongSignal(ctx);
   bool shortSignal = IsShortSignal(ctx);

   if(longSignal && CountManagedPositions(POSITION_TYPE_BUY) < InpMaxOpenPerSide)
      OpenPosition(POSITION_TYPE_BUY, ctx);

   if(shortSignal && CountManagedPositions(POSITION_TYPE_SELL) < InpMaxOpenPerSide)
      OpenPosition(POSITION_TYPE_SELL, ctx);
  }

void ReleaseHandle(int &handle)
  {
   if(handle != INVALID_HANDLE)
     {
      IndicatorRelease(handle);
      handle = INVALID_HANDLE;
     }
  }

bool ParseIntList(string value, bool &target[], int maxItems)
  {
   ArrayInitialize(target, false);
   string cleaned = value;
   StringReplace(cleaned, " ", "");
   if(StringLen(cleaned) == 0)
      return true;

   string parts[];
   int count = StringSplit(cleaned, ',', parts);
   if(count <= 0)
      return false;

   for(int i = 0; i < count; ++i)
     {
      int item = (int)StringToInteger(parts[i]);
      if(item < 0 || item >= maxItems)
         return false;
      target[item] = true;
     }
   return true;
  }

void SetTradeDeviation()
  {
   if(InpMaxDeviationPips <= 0.0)
      return;

   double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   double pip = GetPipSize();
   if(point <= 0.0 || pip <= 0.0)
      return;

   int deviationPoints = (int)MathMax(0.0, MathRound(InpMaxDeviationPips * pip / point));
   trade.SetDeviationInPoints(deviationPoints);
  }

double GetPipSize()
  {
   double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
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

bool LoadSignalContext(SignalContext &ctx)
  {
   double atr[1];
   double ema20[4];
   double ema50[1];
   double ema100[1];
   double macdMain[1];
   double stochD[1];
   double rsi7[1];
   double bandMid[1];
   double bandUpper[1];
   double bandLower[1];

   if(CopyBuffer(atrHandle, 0, 1, 1, atr) != 1 ||
      CopyBuffer(ema20Handle, 0, 1, 4, ema20) != 4 ||
      CopyBuffer(ema50Handle, 0, 1, 1, ema50) != 1 ||
      CopyBuffer(ema100Handle, 0, 1, 1, ema100) != 1 ||
      CopyBuffer(macdHandle, 0, 1, 1, macdMain) != 1 ||
      CopyBuffer(stochHandle, 1, 1, 1, stochD) != 1 ||
      CopyBuffer(rsi7Handle, 0, 1, 1, rsi7) != 1 ||
      CopyBuffer(bandsHandle, 0, 1, 1, bandMid) != 1 ||
      CopyBuffer(bandsHandle, 1, 1, 1, bandUpper) != 1 ||
      CopyBuffer(bandsHandle, 2, 1, 1, bandLower) != 1)
      return false;

   if(atr[0] <= 0.0 || ema20[0] <= 0.0 || ema50[0] <= 0.0 || ema100[0] <= 0.0)
      return false;

   datetime barTime = iTime(runtimeSymbol, InpSignalTimeframe, 1);
   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   double close7 = iClose(runtimeSymbol, InpSignalTimeframe, 7);
   double close25 = iClose(runtimeSymbol, InpSignalTimeframe, 25);
   if(barTime == 0 || close1 <= 0.0 || close7 <= 0.0 || close25 <= 0.0)
      return false;

   double tickFlowSigned3 = ComputeTickFlowSigned3();
   double closeLocation = ComputeCloseLocation();
   double rangeCompression12 = ComputeRangeCompression12();
   double rangeCompression24 = ComputeRangeCompression24();
   double highBreak12 = ComputeHighBreak12();
   double highBreak24 = ComputeHighBreak24();
   double lowBreak24 = ComputeLowBreak24();
   double breakoutPersistDown6 = ComputeBreakoutPersistDown6();
   double breakoutFollowthroughUp = ComputeBreakoutFollowthroughUp();
   double breakoutFollowthroughDown = ComputeBreakoutFollowthroughDown();
   double tickVolumeZ = ComputeTickVolumeZ(50);
   if(tickFlowSigned3 == DBL_MAX || closeLocation == DBL_MAX || rangeCompression12 == DBL_MAX ||
      rangeCompression24 == DBL_MAX ||
      highBreak12 == DBL_MAX || highBreak24 == DBL_MAX || lowBreak24 == DBL_MAX ||
      breakoutPersistDown6 == DBL_MAX || breakoutFollowthroughUp == DBL_MAX ||
      breakoutFollowthroughDown == DBL_MAX || tickVolumeZ == DBL_MAX)
      return false;

   double bandHalfWidth = (bandUpper[0] - bandLower[0]) / 2.0;
   if(bandHalfWidth <= 0.0)
      return false;

   double bbZ = (close1 - bandMid[0]) / bandHalfWidth;

   MqlDateTime tm;
   TimeToStruct(barTime, tm);

   ctx.barTime = barTime;
   ctx.hour = tm.hour;
   ctx.weekday = tm.day_of_week;
   ctx.close = close1;
   ctx.atr = atr[0];
   ctx.ret6 = (close1 - close7) / close7;
   ctx.ret24 = (close1 - close25) / close25;
   ctx.rocAtr6 = (close1 - close7) / atr[0];
   ctx.emaGap2050 = (ema20[0] - ema50[0]) / atr[0];
   ctx.emaGap50100 = (ema50[0] - ema100[0]) / atr[0];
   ctx.closeVsEma50 = (close1 - ema50[0]) / atr[0];
   ctx.ema20Slope3 = (ema20[0] - ema20[3]) / atr[0];
   ctx.rsi7 = rsi7[0];
   ctx.macdLineAtr = macdMain[0] / atr[0];
   ctx.bbZ = bbZ;
   ctx.stochD = stochD[0];
   ctx.closeLocation = closeLocation;
   ctx.rangeCompression12 = rangeCompression12;
   ctx.rangeCompression24 = rangeCompression24;
   ctx.highBreak12 = highBreak12;
   ctx.highBreak24 = highBreak24;
   ctx.lowBreak24 = lowBreak24;
   ctx.breakoutPersistDown6 = breakoutPersistDown6;
   ctx.breakoutFollowthroughUp = breakoutFollowthroughUp;
   ctx.breakoutFollowthroughDown = breakoutFollowthroughDown;
   ctx.tickVolumeZ = tickVolumeZ;
   ctx.tickFlowSigned3 = tickFlowSigned3;
   return true;
  }

double ComputeCloseLocation()
  {
   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   double high1 = iHigh(runtimeSymbol, InpSignalTimeframe, 1);
   double low1 = iLow(runtimeSymbol, InpSignalTimeframe, 1);
   double barRange = high1 - low1;
   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || barRange <= 0.0)
      return DBL_MAX;
   return (close1 - low1) / barRange;
  }

double ComputeRangeCompression12()
  {
   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   if(close1 <= 0.0)
      return DBL_MAX;

   double highest = ComputePreviousHigh(1, 12);
   double lowest = ComputePreviousLow(1, 12);
   if(highest == DBL_MAX || lowest == DBL_MAX || highest <= lowest)
      return DBL_MAX;

   return (highest - lowest) / close1;
  }

double ComputeRangeCompression24()
  {
   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   if(close1 <= 0.0)
      return DBL_MAX;

   double highest = ComputePreviousHigh(1, 24);
   double lowest = ComputePreviousLow(1, 24);
   if(highest == DBL_MAX || lowest == DBL_MAX || highest <= lowest)
      return DBL_MAX;

   return (highest - lowest) / close1;
  }

double ComputeHighBreak12()
  {
   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   double atr[1];
   if(CopyBuffer(atrHandle, 0, 1, 1, atr) != 1)
      return DBL_MAX;
   double atr1 = atr[0];
   if(close1 <= 0.0 || atr1 <= 0.0)
      return DBL_MAX;

   double prevHigh12 = ComputePreviousHigh(2, 12);
   if(prevHigh12 == DBL_MAX)
      return DBL_MAX;

   return (close1 - prevHigh12) / atr1;
  }

double ComputePreviousHigh(int startShift, int lookback)
  {
   double highest = -DBL_MAX;
   for(int shift = startShift; shift < startShift + lookback; ++shift)
     {
      double barHigh = iHigh(runtimeSymbol, InpSignalTimeframe, shift);
      if(barHigh <= 0.0)
         return DBL_MAX;
      if(barHigh > highest)
         highest = barHigh;
     }
   return highest;
  }

double ComputePreviousLow(int startShift, int lookback)
  {
   double lowest = DBL_MAX;
   for(int shift = startShift; shift < startShift + lookback; ++shift)
     {
      double barLow = iLow(runtimeSymbol, InpSignalTimeframe, shift);
      if(barLow <= 0.0)
         return DBL_MAX;
      if(barLow < lowest)
         lowest = barLow;
     }
   return lowest;
  }

double ComputeHighBreak24()
  {
   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   double atr1 = 0.0;
   double atr[1];
   if(CopyBuffer(atrHandle, 0, 1, 1, atr) != 1)
      return DBL_MAX;
   atr1 = atr[0];
   if(close1 <= 0.0 || atr1 <= 0.0)
      return DBL_MAX;

   double prevHigh24 = ComputePreviousHigh(2, 24);
   if(prevHigh24 == DBL_MAX)
      return DBL_MAX;

   return (close1 - prevHigh24) / atr1;
  }

double ComputeLowBreak24()
  {
   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   double atr[1];
   if(CopyBuffer(atrHandle, 0, 1, 1, atr) != 1)
      return DBL_MAX;
   double atr1 = atr[0];
   if(close1 <= 0.0 || atr1 <= 0.0)
      return DBL_MAX;

   double prevLow24 = ComputePreviousLow(2, 24);
   if(prevLow24 == DBL_MAX)
      return DBL_MAX;

  return (close1 - prevLow24) / atr1;
  }

double ComputeLowBreak12AtShift(int shift)
  {
   double closeValue = iClose(runtimeSymbol, InpSignalTimeframe, shift);
   if(closeValue <= 0.0)
      return DBL_MAX;

   double atr[1];
   if(CopyBuffer(atrHandle, 0, shift, 1, atr) != 1)
      return DBL_MAX;
   double atrValue = atr[0];
   if(atrValue <= 0.0)
      return DBL_MAX;

   double prevLow12 = ComputePreviousLow(shift + 1, 12);
   if(prevLow12 == DBL_MAX)
      return DBL_MAX;

   return (closeValue - prevLow12) / atrValue;
  }

double ComputeBreakoutPersistDown6()
  {
   int count = 0;
   for(int shift = 1; shift <= 6; ++shift)
     {
      double closeValue = iClose(runtimeSymbol, InpSignalTimeframe, shift);
      if(closeValue <= 0.0)
         return DBL_MAX;

      double prevLow12 = ComputePreviousLow(shift + 1, 12);
      if(prevLow12 == DBL_MAX)
         return DBL_MAX;

      if(closeValue < prevLow12)
         count++;
     }
   return (double)count;
  }

double ComputeBreakoutFollowthroughDown()
  {
   double sum = 0.0;
   for(int shift = 1; shift <= 3; ++shift)
     {
      double lowBreak12 = ComputeLowBreak12AtShift(shift);
      if(lowBreak12 == DBL_MAX)
         return DBL_MAX;
      double contribution = MathMax(-lowBreak12, 0.0);
      sum += contribution;
     }
   return sum / 3.0;
  }

double ComputeHighBreak12AtShift(int shift)
  {
   double closeValue = iClose(runtimeSymbol, InpSignalTimeframe, shift);
   if(closeValue <= 0.0)
      return DBL_MAX;

   double atr[1];
   if(CopyBuffer(atrHandle, 0, shift, 1, atr) != 1)
      return DBL_MAX;
   double atrValue = atr[0];
   if(atrValue <= 0.0)
      return DBL_MAX;

   double prevHigh12 = ComputePreviousHigh(shift + 1, 12);
   if(prevHigh12 == DBL_MAX)
      return DBL_MAX;

   return (closeValue - prevHigh12) / atrValue;
  }

double ComputeBreakoutFollowthroughUp()
  {
   double sum = 0.0;
   for(int shift = 1; shift <= 3; ++shift)
     {
      double highBreak12 = ComputeHighBreak12AtShift(shift);
      if(highBreak12 == DBL_MAX)
         return DBL_MAX;
      double contribution = MathMax(highBreak12, 0.0);
      sum += contribution;
     }
   return sum / 3.0;
  }

double ComputeTickVolumeZ(int lookback)
  {
   if(lookback <= 1)
      return DBL_MAX;

   double currentVolume = (double)iVolume(runtimeSymbol, InpSignalTimeframe, 1);
   if(currentVolume <= 0.0)
      return DBL_MAX;

   double sum = 0.0;
   double samples[];
   ArrayResize(samples, lookback);
   for(int shift = 1; shift <= lookback; ++shift)
     {
      double volume = (double)iVolume(runtimeSymbol, InpSignalTimeframe, shift);
      if(volume <= 0.0)
         return DBL_MAX;
      samples[shift - 1] = volume;
      sum += volume;
     }

   double mean = sum / lookback;
   if(mean <= 0.0)
      return DBL_MAX;

   double variance = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      double centered = samples[i] - mean;
      variance += centered * centered;
     }

   double std = MathSqrt(variance / lookback);
   if(std <= 0.0)
      return DBL_MAX;

   return (currentVolume - mean) / std;
  }

double ComputeTickVolumeRel10(int shift)
  {
   double currentVolume = (double)iVolume(runtimeSymbol, InpSignalTimeframe, shift);
   if(currentVolume <= 0.0)
      return DBL_MAX;

   double sumVolume = 0.0;
   for(int i = shift; i < shift + 10; ++i)
     {
      double sample = (double)iVolume(runtimeSymbol, InpSignalTimeframe, i);
      if(sample <= 0.0)
         return DBL_MAX;
      sumVolume += sample;
     }

   double averageVolume = sumVolume / 10.0;
   if(averageVolume <= 0.0)
      return DBL_MAX;
   return currentVolume / averageVolume;
  }

double ComputeTickFlowSigned3()
  {
   double flow = 0.0;
   for(int shift = 1; shift <= 3; ++shift)
     {
      double closeNow = iClose(runtimeSymbol, InpSignalTimeframe, shift);
      double closePrev = iClose(runtimeSymbol, InpSignalTimeframe, shift + 1);
      if(closeNow <= 0.0 || closePrev <= 0.0)
         return DBL_MAX;

      double volRel = ComputeTickVolumeRel10(shift);
      if(volRel == DBL_MAX)
         return DBL_MAX;

      double direction = 0.0;
      if(closeNow > closePrev)
         direction = 1.0;
      else if(closeNow < closePrev)
         direction = -1.0;

      flow += direction * volRel;
     }

   return flow / 3.0;
  }

bool CanOpenNewEntries(const SignalContext &ctx)
  {
   if(ctx.weekday < 0 || ctx.weekday > 6 || !allowedWeekdays[ctx.weekday])
      return false;

   if(ctx.hour >= 0 && ctx.hour < 24 && blockedHours[ctx.hour])
      return false;

   if(GetSpreadPips() > InpMaxSpreadPips)
      return false;

   if(CountManagedPositions(-1) >= InpMaxOpenTrades)
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

   if(InpUseEquityKillSwitch && equityPeak > 0.0)
     {
      double peakDrawdownPct = 100.0 * (equityPeak - equity) / equityPeak;
      if(peakDrawdownPct >= InpEquityKillSwitchPercent)
         return false;
     }

   return true;
  }

bool IsLongSignal(const SignalContext &ctx)
  {
   if(!InpEnableLong || !HourInWindow(ctx.hour, InpLongStartHour, InpLongEndHour))
      return false;

   if(InpLongRuleMode == LongRuleEmaGap2050)
     {
      if(ctx.emaGap2050 > InpLongEmaGap2050Max)
         return false;
     }
   else if(InpLongRuleMode == LongRuleRet24)
     {
      if(ctx.ret24 > InpLongRet24Max)
         return false;
     }
   else if(InpLongRuleMode == LongRuleMacdAtr)
     {
      if(ctx.macdLineAtr > InpLongMacdLineAtrMax)
         return false;
     }
   else if(InpLongRuleMode == LongRuleEmaGap50100)
     {
      if(ctx.emaGap50100 > InpLongEmaGap50100Max)
         return false;
     }
   else if(InpLongRuleMode == LongRuleCloseVsEma50)
     {
      if(ctx.closeVsEma50 > InpLongCloseVsEma50Max)
         return false;
     }
   else if(InpLongRuleMode == LongRuleLowBreak24)
     {
      if(ctx.lowBreak24 > InpLongLowBreak24Max)
         return false;
     }
   else if(InpLongRuleMode == LongRuleBreakoutPersistDown6)
     {
      if(ctx.breakoutPersistDown6 < InpLongBreakoutPersistDown6Min)
         return false;
     }
   else if(InpLongRuleMode == LongRuleRocAtr6)
     {
      if(ctx.rocAtr6 > InpLongRocAtr6Max)
         return false;
     }
   else if(InpLongRuleMode == LongRuleHighBreak12)
     {
      if(ctx.highBreak12 > InpLongHighBreak12Max)
         return false;
     }
   else if(InpLongRuleMode == LongRuleBreakoutFollowthroughDown)
     {
      if(ctx.breakoutFollowthroughDown < InpLongBreakoutFollowthroughDownMin)
         return false;
     }
   else if(InpLongRuleMode == LongRuleBreakoutFollowthroughUp)
     {
      if(ctx.breakoutFollowthroughUp < InpLongBreakoutFollowthroughUpMin)
         return false;
     }

   if(InpUseLongStochDFilter && ctx.stochD > InpLongStochDMax)
      return false;

   if(InpUseLongBbZFilter && ctx.bbZ > InpLongBbZMax)
      return false;

   if(InpUseLongEma20SlopeFilter && ctx.ema20Slope3 > InpLongEma20Slope3Max)
      return false;

   if(InpUseLongRsi7Filter && ctx.rsi7 > InpLongRsi7Max)
      return false;

   if(InpUseLongRet6Filter && ctx.ret6 > InpLongRet6Max)
      return false;

   if(InpUseLongHighBreak12Filter && ctx.highBreak12 > InpLongHighBreak12FilterMax)
      return false;

   if(InpUseLongHighBreakFilter && ctx.highBreak24 > InpLongHighBreak24Max)
      return false;

   if(InpUseLongRangeCompression24Filter && ctx.rangeCompression24 > InpLongRangeCompression24Max)
      return false;

   if(InpUseLongTickFlowFilter && ctx.tickFlowSigned3 > InpLongTickFlowMax)
      return false;

   if(InpUseLongTickVolumeFilter && ctx.tickVolumeZ < InpLongTickVolumeMin)
      return false;

   return true;
  }

bool IsShortSignal(const SignalContext &ctx)
  {
   if(!InpEnableShort || !HourInWindow(ctx.hour, InpShortStartHour, InpShortEndHour))
      return false;

   if(InpShortRuleMode == ShortRuleMacdAtr)
     {
      if(ctx.macdLineAtr < InpShortMacdLineAtrMin)
         return false;
     }
   else if(InpShortRuleMode == ShortRuleHighBreak24)
     {
      if(ctx.highBreak24 < InpShortHighBreak24Min)
         return false;
     }
   else if(InpShortRuleMode == ShortRuleTickVolumeZ)
     {
      if(ctx.tickVolumeZ < InpShortTickVolumeZMin)
         return false;
     }
   else if(InpShortRuleMode == ShortRuleCloseLocation)
     {
      if(ctx.closeLocation < InpShortCloseLocationMin)
         return false;
     }
   else if(InpShortRuleMode == ShortRuleRangeCompression12)
     {
      if(ctx.rangeCompression12 > InpShortRangeCompression12Max)
         return false;
     }

   if(InpUseShortFlowFilter && ctx.tickFlowSigned3 < InpShortTickFlowMin)
      return false;

   return true;
  }

bool HourInWindow(int hour, int startHour, int endHour)
  {
   if(startHour == endHour)
      return true;

   if(startHour < endHour)
      return hour >= startHour && hour < endHour;

   return hour >= startHour || hour < endHour;
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

int CountManagedPositions(int desiredType)
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      int type = (int)PositionGetInteger(POSITION_TYPE);
      if(desiredType >= 0 && type != desiredType)
         continue;
      count++;
     }
   return count;
  }

void OpenPosition(int positionType, const SignalContext &ctx)
  {
   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   double price = (positionType == POSITION_TYPE_BUY) ? ask : bid;
   if(price <= 0.0)
      return;

   double stopAtr = (positionType == POSITION_TYPE_BUY) ? InpLongStopATR : InpShortStopATR;
   double targetR = (positionType == POSITION_TYPE_BUY) ? InpLongTargetRMultiple : InpShortTargetRMultiple;
   double stopDistance = ctx.atr * stopAtr;
   if(stopDistance <= 0.0)
      return;

   double sl = 0.0;
   double tp = 0.0;
   if(positionType == POSITION_TYPE_BUY)
     {
      sl = NormalizePrice(price - stopDistance);
      if(targetR > 0.0)
         tp = NormalizePrice(price + stopDistance * targetR);
     }
   else
     {
      sl = NormalizePrice(price + stopDistance);
      if(targetR > 0.0)
         tp = NormalizePrice(price - stopDistance * targetR);
     }

   double volume = CalculateVolume(stopDistance);
   if(volume <= 0.0)
      return;

   bool result = false;
   if(positionType == POSITION_TYPE_BUY)
      result = trade.Buy(volume, runtimeSymbol, 0.0, sl, tp, "regime_single_long");
   else
      result = trade.Sell(volume, runtimeSymbol, 0.0, sl, tp, "regime_single_short");

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

   if(InpSkipTradeWhenMinLotRiskTooHigh)
     {
      double minLotRiskPercent = 100.0 * (moneyPerLot * minVolume) / equity;
      if(minLotRiskPercent > InpMaxEffectiveRiskPercentAtMinLot)
         return 0.0;
     }

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

double NormalizePrice(double price)
  {
   int digits = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
  }

void ManageTimedExits()
  {
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      int type = (int)PositionGetInteger(POSITION_TYPE);
      int holdBars = (type == POSITION_TYPE_BUY) ? InpLongHoldBars : InpShortHoldBars;
      if(holdBars <= 0)
         continue;

      datetime openedAt = (datetime)PositionGetInteger(POSITION_TIME);
      int shift = iBarShift(runtimeSymbol, InpSignalTimeframe, openedAt, false);
      if(shift < 0 || shift < holdBars)
         continue;

      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      if(!trade.PositionClose(ticket))
         Print("Timed exit failed for ticket ", ticket, ": ", trade.ResultRetcodeDescription());
     }
  }
