//+------------------------------------------------------------------+
//| USDJPY Fractal Structure Method2 Scaffold                        |
//+------------------------------------------------------------------+
#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "1.00"
#property strict
#property description "Scaffold for a fractal-structure Method2 using HTF trend and LTF sweep-reclaim transition logic."

#include <Trade\Trade.mqh>

CTrade trade;

struct PivotPoint
  {
   bool     valid;
   int      shift;
   double   price;
   datetime time;
  };

struct TrendContext
  {
   int      direction;
   PivotPoint latestHigh;
   PivotPoint previousHigh;
   PivotPoint latestLow;
   PivotPoint previousLow;
   double   ema20;
   double   ema50;
   double   atr;
  };

struct PullbackContext
  {
   bool     zoneTouched;
   bool     sweepDone;
   double   sweepExtreme;
   double   triggerLevel;
   PivotPoint internalHigh;
   PivotPoint internalLow;
  };

struct EntryPlan
  {
   bool     valid;
   int      direction;
   double   entry;
   double   stop;
   double   target;
   string   reason;
  };

input string          InpSymbol                          = "USDJPY";
input ENUM_TIMEFRAMES InpTrendTimeframe                  = PERIOD_M15;
input ENUM_TIMEFRAMES InpSignalTimeframe                 = PERIOD_M5;
input int             InpPivotSpan                       = 2;
input int             InpTrendScanBars                   = 200;
input int             InpPullbackLookbackBars            = 24;
input int             InpFastEMAPeriod                   = 20;
input int             InpSlowEMAPeriod                   = 50;
input int             InpATRPeriod                       = 14;
input double          InpZoneATRMultiple                 = 0.25;
input double          InpMinZonePips                     = 4.0;
input double          InpSweepBufferPips                 = 1.5;
input double          InpStopBufferPips                  = 1.5;
input double          InpTargetRMultiple                 = 1.5;
input double          InpRiskPercent                     = 0.35;
input bool            InpEnableLong                      = true;
input bool            InpEnableShort                     = true;
input int             InpSessionStartHour                = 7;
input int             InpSessionEndHour                  = 22;
input int             InpMaxTradesPerDay                 = 3;
input double          InpMaxSpreadPips                   = 2.0;
input bool            InpUseDailyLossCap                 = true;
input double          InpDailyLossCapPercent             = 3.0;
input bool            InpUseEquityDrawdownCap            = true;
input double          InpEquityDrawdownCapPercent        = 8.0;
input string          InpAllowedWeekdays                 = "1,2,3,4,5";
input long            InpMagicNumber                     = 20260481;

string runtimeSymbol = "";
bool allowedWeekdays[7];
datetime lastSignalBarTime = 0;
datetime currentDayStart = 0;
double dailyStartEquity = 0.0;
double equityPeak = 0.0;
int dailyTradeCount = 0;

int trendAtrHandle = INVALID_HANDLE;
int trendEma20Handle = INVALID_HANDLE;
int trendEma50Handle = INVALID_HANDLE;

string NormalizePresetString(string rawValue)
  {
   int marker = StringFind(rawValue, "||");
   if(marker < 0)
      return rawValue;
   return StringSubstr(rawValue, 0, marker);
  }

bool ParseWeekdays(string rawValue, bool &target[])
  {
   ArrayInitialize(target, false);
   string items[];
   int count = StringSplit(rawValue, ',', items);
   if(count <= 0)
      return false;

   for(int i = 0; i < count; ++i)
     {
      string item = items[i];
      StringReplace(item, " ", "");
      if(item == "")
         continue;
      int day = (int)StringToInteger(item);
      if(day < 0 || day > 6)
         return false;
      target[day] = true;
     }

   return true;
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

bool HourInWindow(int hour, int startHour, int endHour)
  {
   if(startHour == endHour)
      return true;
   if(startHour < endHour)
      return (hour >= startHour && hour < endHour);
   return (hour >= startHour || hour < endHour);
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

double ComputePreviousHigh(ENUM_TIMEFRAMES tf, int startShift, int lookback)
  {
   double highest = -DBL_MAX;
   for(int shift = startShift; shift < startShift + lookback; ++shift)
     {
      double barHigh = iHigh(runtimeSymbol, tf, shift);
      if(barHigh <= 0.0)
         return DBL_MAX;
      if(barHigh > highest)
         highest = barHigh;
     }
   return highest;
  }

double ComputePreviousLow(ENUM_TIMEFRAMES tf, int startShift, int lookback)
  {
   double lowest = DBL_MAX;
   for(int shift = startShift; shift < startShift + lookback; ++shift)
     {
      double barLow = iLow(runtimeSymbol, tf, shift);
      if(barLow <= 0.0)
         return DBL_MAX;
      if(barLow < lowest)
         lowest = barLow;
     }
   return lowest;
  }

bool IsPivotHigh(ENUM_TIMEFRAMES tf, int shift, int span)
  {
   double center = iHigh(runtimeSymbol, tf, shift);
   if(center <= 0.0)
      return false;

   for(int i = 1; i <= span; ++i)
     {
      if(center <= iHigh(runtimeSymbol, tf, shift - i))
         return false;
      if(center <= iHigh(runtimeSymbol, tf, shift + i))
         return false;
     }
   return true;
  }

bool IsPivotLow(ENUM_TIMEFRAMES tf, int shift, int span)
  {
   double center = iLow(runtimeSymbol, tf, shift);
   if(center <= 0.0)
      return false;

   for(int i = 1; i <= span; ++i)
     {
      if(center >= iLow(runtimeSymbol, tf, shift - i))
         return false;
      if(center >= iLow(runtimeSymbol, tf, shift + i))
         return false;
     }
   return true;
  }

bool FindLatestConfirmedPivots(ENUM_TIMEFRAMES tf,
                               int span,
                               int scanBars,
                               PivotPoint &latestHigh,
                               PivotPoint &previousHigh,
                               PivotPoint &latestLow,
                               PivotPoint &previousLow)
  {
   latestHigh.valid = false;
   previousHigh.valid = false;
   latestLow.valid = false;
   previousLow.valid = false;

   int foundHigh = 0;
   int foundLow = 0;
   int startShift = span + 1;
   int endShift = startShift + scanBars;

   for(int shift = startShift; shift <= endShift; ++shift)
     {
      if(foundHigh < 2 && IsPivotHigh(tf, shift, span))
        {
         PivotPoint pivot;
         pivot.valid = true;
         pivot.shift = shift;
         pivot.price = iHigh(runtimeSymbol, tf, shift);
         pivot.time = iTime(runtimeSymbol, tf, shift);
         if(foundHigh == 0)
            latestHigh = pivot;
         else
            previousHigh = pivot;
         foundHigh++;
        }

      if(foundLow < 2 && IsPivotLow(tf, shift, span))
        {
         PivotPoint pivot;
         pivot.valid = true;
         pivot.shift = shift;
         pivot.price = iLow(runtimeSymbol, tf, shift);
         pivot.time = iTime(runtimeSymbol, tf, shift);
         if(foundLow == 0)
            latestLow = pivot;
         else
            previousLow = pivot;
         foundLow++;
        }

      if(foundHigh >= 2 && foundLow >= 2)
         break;
     }

   return (foundHigh >= 2 && foundLow >= 2);
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

bool BuildTrendContext(TrendContext &ctx)
  {
   PivotPoint latestHigh, previousHigh, latestLow, previousLow;
   if(!FindLatestConfirmedPivots(InpTrendTimeframe,
                                 InpPivotSpan,
                                 InpTrendScanBars,
                                 latestHigh,
                                 previousHigh,
                                 latestLow,
                                 previousLow))
      return false;

   double atrValues[1];
   double ema20Values[1];
   double ema50Values[1];
   if(CopyBuffer(trendAtrHandle, 0, 1, 1, atrValues) != 1 ||
      CopyBuffer(trendEma20Handle, 0, 1, 1, ema20Values) != 1 ||
      CopyBuffer(trendEma50Handle, 0, 1, 1, ema50Values) != 1)
      return false;

   ctx.direction = DetectDowTrend(latestHigh, previousHigh, latestLow, previousLow);
   ctx.latestHigh = latestHigh;
   ctx.previousHigh = previousHigh;
   ctx.latestLow = latestLow;
   ctx.previousLow = previousLow;
   ctx.atr = atrValues[0];
   ctx.ema20 = ema20Values[0];
   ctx.ema50 = ema50Values[0];
   return (ctx.atr > 0.0);
  }

double ComputeZoneWidth(const TrendContext &ctx)
  {
   return MathMax(PipsToPrice(InpMinZonePips), ctx.atr * InpZoneATRMultiple);
  }

bool IsPriceInsideBuyZone(const TrendContext &ctx, double price)
  {
   double zoneWidth = ComputeZoneWidth(ctx);
   double anchor = ctx.latestLow.price;
   return (price <= anchor + zoneWidth && price >= anchor - zoneWidth);
  }

bool IsPriceInsideSellZone(const TrendContext &ctx, double price)
  {
   double zoneWidth = ComputeZoneWidth(ctx);
   double anchor = ctx.latestHigh.price;
   return (price >= anchor - zoneWidth && price <= anchor + zoneWidth);
  }

bool DetectBullSweepAndReclaim(const TrendContext &htfCtx, PullbackContext &pbCtx)
  {
   pbCtx.zoneTouched = false;
   pbCtx.sweepDone = false;
   pbCtx.sweepExtreme = 0.0;
   pbCtx.triggerLevel = 0.0;

   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   double low1 = iLow(runtimeSymbol, InpSignalTimeframe, 1);
   if(close1 <= 0.0 || low1 <= 0.0)
      return false;

   pbCtx.zoneTouched = IsPriceInsideBuyZone(htfCtx, close1);
   if(!pbCtx.zoneTouched)
      return false;

   double referenceLow = ComputePreviousLow(InpSignalTimeframe, 2, MathMax(4, InpPullbackLookbackBars));
   if(referenceLow == DBL_MAX)
      return false;

   if(low1 < referenceLow - PipsToPrice(InpSweepBufferPips))
     {
      pbCtx.sweepDone = true;
      pbCtx.sweepExtreme = low1;
      pbCtx.triggerLevel = iHigh(runtimeSymbol, InpSignalTimeframe, 1);
     }

   return pbCtx.sweepDone;
  }

bool DetectBearSweepAndReclaim(const TrendContext &htfCtx, PullbackContext &pbCtx)
  {
   pbCtx.zoneTouched = false;
   pbCtx.sweepDone = false;
   pbCtx.sweepExtreme = 0.0;
   pbCtx.triggerLevel = 0.0;

   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   double high1 = iHigh(runtimeSymbol, InpSignalTimeframe, 1);
   if(close1 <= 0.0 || high1 <= 0.0)
      return false;

   pbCtx.zoneTouched = IsPriceInsideSellZone(htfCtx, close1);
   if(!pbCtx.zoneTouched)
      return false;

   double referenceHigh = ComputePreviousHigh(InpSignalTimeframe, 2, MathMax(4, InpPullbackLookbackBars));
   if(referenceHigh == DBL_MAX)
      return false;

   if(high1 > referenceHigh + PipsToPrice(InpSweepBufferPips))
     {
      pbCtx.sweepDone = true;
      pbCtx.sweepExtreme = high1;
      pbCtx.triggerLevel = iLow(runtimeSymbol, InpSignalTimeframe, 1);
     }

   return pbCtx.sweepDone;
  }

bool ConfirmShortTermBullShift(PullbackContext &pbCtx)
  {
   if(!pbCtx.sweepDone)
      return false;

   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   if(close1 <= 0.0)
      return false;

   return (close1 > pbCtx.triggerLevel);
  }

bool ConfirmShortTermBearShift(PullbackContext &pbCtx)
  {
   if(!pbCtx.sweepDone)
      return false;

   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   if(close1 <= 0.0)
      return false;

   return (close1 < pbCtx.triggerLevel);
  }

bool BuildLongEntryPlan(const TrendContext &htfCtx,
                        const PullbackContext &pbCtx,
                        EntryPlan &plan)
  {
   plan.valid = false;
   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   if(ask <= 0.0 || !pbCtx.sweepDone)
      return false;

   plan.direction = 1;
   plan.entry = NormalizePrice(ask);
   plan.stop = NormalizePrice(pbCtx.sweepExtreme - PipsToPrice(InpStopBufferPips));
   if(plan.stop >= plan.entry)
      return false;

   double risk = plan.entry - plan.stop;
   plan.target = NormalizePrice(plan.entry + risk * InpTargetRMultiple);
   plan.reason = "fractal_long";
   plan.valid = true;
   return true;
  }

bool BuildShortEntryPlan(const TrendContext &htfCtx,
                         const PullbackContext &pbCtx,
                         EntryPlan &plan)
  {
   plan.valid = false;
   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   if(bid <= 0.0 || !pbCtx.sweepDone)
      return false;

   plan.direction = -1;
   plan.entry = NormalizePrice(bid);
   plan.stop = NormalizePrice(pbCtx.sweepExtreme + PipsToPrice(InpStopBufferPips));
   if(plan.stop <= plan.entry)
      return false;

   double risk = plan.stop - plan.entry;
   plan.target = NormalizePrice(plan.entry - risk * InpTargetRMultiple);
   plan.reason = "fractal_short";
   plan.valid = true;
   return true;
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

bool ExecuteEntry(const EntryPlan &plan)
  {
   if(!plan.valid)
      return false;

   double volume = CalculateVolumeByRisk(plan.entry, plan.stop);
   if(volume <= 0.0)
      return false;

   bool result = false;
   if(plan.direction > 0)
      result = trade.Buy(volume, runtimeSymbol, 0.0, plan.stop, plan.target, plan.reason);
   else if(plan.direction < 0)
      result = trade.Sell(volume, runtimeSymbol, 0.0, plan.stop, plan.target, plan.reason);

   if(result)
      dailyTradeCount++;

   return result;
  }

void ManageOpenPositions()
  {
   // Intentionally left minimal in the scaffold.
  }

int OnInit()
  {
   runtimeSymbol = NormalizePresetString(InpSymbol);
   ArrayInitialize(allowedWeekdays, false);

   if(InpMagicNumber <= 0 || InpPivotSpan <= 0 || InpTrendScanBars <= 0 ||
      InpATRPeriod <= 0 || InpFastEMAPeriod <= 0 || InpSlowEMAPeriod <= 0 ||
      InpRiskPercent <= 0.0 || InpTargetRMultiple <= 0.0)
     {
      Print("Invalid Method2 scaffold parameters.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!ParseWeekdays(NormalizePresetString(InpAllowedWeekdays), allowedWeekdays))
     {
      Print("Invalid weekday filter.");
      return INIT_PARAMETERS_INCORRECT;
     }

   trade.SetExpertMagicNumber((ulong)InpMagicNumber);

   trendAtrHandle = iATR(runtimeSymbol, InpTrendTimeframe, InpATRPeriod);
   trendEma20Handle = iMA(runtimeSymbol, InpTrendTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   trendEma50Handle = iMA(runtimeSymbol, InpTrendTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(trendAtrHandle == INVALID_HANDLE || trendEma20Handle == INVALID_HANDLE || trendEma50Handle == INVALID_HANDLE)
     {
      Print("Failed to create scaffold indicator handles.");
      return INIT_FAILED;
     }

   InitializeDayState(TimeCurrent());
   equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(trendAtrHandle != INVALID_HANDLE)
      IndicatorRelease(trendAtrHandle);
   if(trendEma20Handle != INVALID_HANDLE)
      IndicatorRelease(trendEma20Handle);
   if(trendEma50Handle != INVALID_HANDLE)
      IndicatorRelease(trendEma50Handle);
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

   TrendContext htfCtx;
   if(!BuildTrendContext(htfCtx))
      return;

   if(htfCtx.direction > 0 && InpEnableLong)
     {
      PullbackContext pbCtx;
      if(DetectBullSweepAndReclaim(htfCtx, pbCtx) && ConfirmShortTermBullShift(pbCtx))
        {
         EntryPlan plan;
         if(BuildLongEntryPlan(htfCtx, pbCtx, plan))
            ExecuteEntry(plan);
        }
     }

   if(htfCtx.direction < 0 && InpEnableShort)
     {
      PullbackContext pbCtx;
      if(DetectBearSweepAndReclaim(htfCtx, pbCtx) && ConfirmShortTermBearShift(pbCtx))
        {
         EntryPlan plan;
         if(BuildShortEntryPlan(htfCtx, pbCtx, plan))
            ExecuteEntry(plan);
        }
     }
  }
