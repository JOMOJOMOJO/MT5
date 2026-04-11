//+------------------------------------------------------------------+
//| USDJPY Late Quiet Spike Short Guarded                            |
//+------------------------------------------------------------------+
#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "1.00"
#property strict
#property description "USDJPY M15 short-only late-session quiet-spike fade with guarded risk controls."

#include <Trade\Trade.mqh>

CTrade trade;

struct SignalContext
  {
   datetime barTime;
   int      hour;
   int      weekday;
   double   close;
   double   atr;
   double   atrPct;
   double   closeVsEma20;
   double   closeVsEma50;
   double   ema20Slope3;
   double   rsi7;
   double   rsi14;
   double   macdLineAtr;
   double   stochK;
   double   stochD;
   double   tickVolumeRel10;
   double   highBreak24;
   bool     bullTrend;
   bool     stackedBullTrend;
  };

input string          InpSymbol                          = "USDJPY";
input ENUM_TIMEFRAMES InpSignalTimeframe                 = PERIOD_M15;
input int             InpFastEMAPeriod                   = 20;
input int             InpSlowEMAPeriod                   = 50;
input int             InpTrendEMAPeriod                  = 100;
input int             InpATRPeriod                       = 14;
input int             InpRSIFastPeriod                   = 7;
input int             InpRSISlowPeriod                   = 14;

input bool            InpEnableShort                     = true;
input int             InpShortStartHour                  = 20;
input int             InpShortEndHour                    = 24;
input double          InpShortMinCloseVsEma20Atr        = 1.80;
input double          InpShortMaxCloseVsEma20Atr        = 5.00;
input bool            InpUseCloseVsEma50Filter          = false;
input double          InpShortMinCloseVsEma50Atr        = 0.80;
input bool            InpUseBullTrendFilter             = false;
input bool            InpUseStackedBullTrendFilter      = false;
input bool            InpUseEma20SlopeFilter            = false;
input double          InpShortMinEma20Slope3Atr         = 0.55;
input bool            InpUseRsi7Filter                  = false;
input double          InpShortMinRsi7                   = 68.0;
input double          InpShortMaxRsi7                   = 92.0;
input bool            InpUseRsi14Filter                 = false;
input double          InpShortMinRsi14                  = 65.0;
input double          InpShortMaxRsi14                  = 90.0;
input bool            InpUseMacdLineAtrFilter           = false;
input double          InpShortMinMacdLineAtr            = 0.40;
input bool            InpUseStochFilter                 = false;
input double          InpShortMinStochK                 = 83.5;
input double          InpShortMinStochD                 = 81.5;
input bool            InpUseTickVolumeRel10Filter       = true;
input double          InpShortMaxTickVolumeRel10        = 0.70;
input bool            InpUseHighBreak24Filter           = false;
input double          InpShortMinHighBreak24Atr         = -0.20;
input double          InpShortMinATRPercent             = 0.0;
input double          InpShortMaxATRPercent             = 0.0012;

input int             InpHoldBars                       = 3;
input bool            InpExitOnMeanReversion            = true;
input double          InpExitBufferATR                  = 0.00;
input int             InpStructureLookbackBars          = 3;
input double          InpMinStopATR                     = 0.90;
input double          InpStructureBufferATR             = 0.10;
input double          InpTargetRMultiple                = 0.75;

input double          InpRiskPercent                    = 0.25;
input bool            InpSkipTradeWhenMinLotRiskTooHigh = true;
input double          InpMaxEffectiveRiskPercentAtMinLot = 1.00;
input bool            InpUseDailyLossCap                = true;
input double          InpDailyLossCapPercent            = 3.0;
input bool            InpUseEquityKillSwitch            = true;
input double          InpEquityKillSwitchPercent        = 8.0;
input int             InpMaxTradesPerDay                = 2;
input int             InpMaxOpenTrades                  = 1;
input double          InpMaxSpreadPips                  = 1.8;
input double          InpMaxDeviationPips               = 1.5;
input string          InpAllowedWeekdays                = "1,2,3,4,5";
input string          InpBlockedEntryHours              = "";
input long            InpMagicNumber                    = 20260462;

int atrHandle = INVALID_HANDLE;
int ema20Handle = INVALID_HANDLE;
int ema50Handle = INVALID_HANDLE;
int ema100Handle = INVALID_HANDLE;
int rsi7Handle = INVALID_HANDLE;
int rsi14Handle = INVALID_HANDLE;
int macdHandle = INVALID_HANDLE;
int stochHandle = INVALID_HANDLE;

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

string NormalizePresetString(string rawValue)
  {
   int marker = StringFind(rawValue, "||");
   if(marker < 0)
      return rawValue;
   return StringSubstr(rawValue, 0, marker);
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

void ReleaseHandle(int &handle)
  {
   if(handle != INVALID_HANDLE)
     {
      IndicatorRelease(handle);
      handle = INVALID_HANDLE;
     }
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

double GetSpreadPips()
  {
   double ask = SymbolInfoDouble(runtimeSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   double pip = GetPipSize();
   if(ask <= 0.0 || bid <= 0.0 || pip <= 0.0)
      return DBL_MAX;
   return (ask - bid) / pip;
  }

double GetMinStopDistance()
  {
   int stops = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stops <= 0)
      return 0.0;
   return stops * SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
  }

bool ValidateStopLoss(ENUM_ORDER_TYPE orderType, double price, double sl)
  {
   if(sl <= 0.0)
      return false;

   double minDistance = GetMinStopDistance();
   if(minDistance <= 0.0)
      return true;

   if(orderType == ORDER_TYPE_SELL)
      return ((sl - price) >= minDistance);

   return false;
  }

bool HourInWindow(int hour, int startHour, int endHour)
  {
   if(startHour == endHour)
      return true;

   if(startHour < endHour)
      return (hour >= startHour && hour < endHour);

   return (hour >= startHour || hour < endHour);
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

int HeldBars(datetime openedAt)
  {
   if(openedAt <= 0)
      return 0;
   int shift = iBarShift(runtimeSymbol, InpSignalTimeframe, openedAt, false);
   if(shift < 0)
      return 0;
   return shift;
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

bool LoadSignalContext(SignalContext &ctx)
  {
   double atr[1];
   double ema20[4];
   double ema50[1];
   double ema100[1];
   double rsi7[1];
   double rsi14[1];
   double macdMain[1];
   double stochK[1];
   double stochD[1];

   if(CopyBuffer(atrHandle, 0, 1, 1, atr) != 1 ||
      CopyBuffer(ema20Handle, 0, 1, 4, ema20) != 4 ||
      CopyBuffer(ema50Handle, 0, 1, 1, ema50) != 1 ||
      CopyBuffer(ema100Handle, 0, 1, 1, ema100) != 1 ||
      CopyBuffer(rsi7Handle, 0, 1, 1, rsi7) != 1 ||
      CopyBuffer(rsi14Handle, 0, 1, 1, rsi14) != 1 ||
      CopyBuffer(macdHandle, 0, 1, 1, macdMain) != 1 ||
      CopyBuffer(stochHandle, 0, 1, 1, stochK) != 1 ||
      CopyBuffer(stochHandle, 1, 1, 1, stochD) != 1)
      return false;

   if(atr[0] <= 0.0 || ema20[0] <= 0.0 || ema50[0] <= 0.0 || ema100[0] <= 0.0)
      return false;

   datetime barTime = iTime(runtimeSymbol, InpSignalTimeframe, 1);
   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   if(barTime == 0 || close1 <= 0.0)
      return false;

   double prevHigh24 = ComputePreviousHigh(2, 24);
   double tickVolumeRel10 = ComputeTickVolumeRel10(1);
   if(prevHigh24 == DBL_MAX || tickVolumeRel10 == DBL_MAX)
      return false;

   MqlDateTime tm;
   TimeToStruct(barTime, tm);

   ctx.barTime = barTime;
   ctx.hour = tm.hour;
   ctx.weekday = tm.day_of_week;
   ctx.close = close1;
   ctx.atr = atr[0];
   ctx.atrPct = atr[0] / close1;
   ctx.closeVsEma20 = (close1 - ema20[0]) / atr[0];
   ctx.closeVsEma50 = (close1 - ema50[0]) / atr[0];
   ctx.ema20Slope3 = (ema20[0] - ema20[3]) / atr[0];
   ctx.rsi7 = rsi7[0];
   ctx.rsi14 = rsi14[0];
   ctx.macdLineAtr = macdMain[0] / atr[0];
   ctx.stochK = stochK[0];
   ctx.stochD = stochD[0];
   ctx.tickVolumeRel10 = tickVolumeRel10;
   ctx.highBreak24 = (close1 - prevHigh24) / atr[0];
   ctx.bullTrend = (ema20[0] > ema50[0]);
   ctx.stackedBullTrend = (ema20[0] > ema50[0] && ema50[0] > ema100[0]);
   return true;
  }

bool CanOpenNewEntries(const SignalContext &ctx)
  {
   if(ctx.weekday < 0 || ctx.weekday > 6 || !allowedWeekdays[ctx.weekday])
      return false;

   if(ctx.hour >= 0 && ctx.hour < 24 && blockedHours[ctx.hour])
      return false;

   if(GetSpreadPips() > InpMaxSpreadPips)
      return false;

   if(CountManagedPositions() >= InpMaxOpenTrades)
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

bool IsShortSignal(const SignalContext &ctx)
  {
   if(!InpEnableShort || !HourInWindow(ctx.hour, InpShortStartHour, InpShortEndHour))
      return false;

   if(ctx.closeVsEma20 < InpShortMinCloseVsEma20Atr)
      return false;
   if(InpShortMaxCloseVsEma20Atr > 0.0 && ctx.closeVsEma20 > InpShortMaxCloseVsEma20Atr)
      return false;

   if(InpUseCloseVsEma50Filter && ctx.closeVsEma50 < InpShortMinCloseVsEma50Atr)
      return false;
   if(InpUseBullTrendFilter && !ctx.bullTrend)
      return false;
   if(InpUseStackedBullTrendFilter && !ctx.stackedBullTrend)
      return false;
   if(InpUseEma20SlopeFilter && ctx.ema20Slope3 < InpShortMinEma20Slope3Atr)
      return false;

   if(InpShortMinATRPercent > 0.0 && ctx.atrPct < InpShortMinATRPercent)
      return false;
   if(InpShortMaxATRPercent > 0.0 && ctx.atrPct > InpShortMaxATRPercent)
      return false;

   if(InpUseRsi7Filter && (ctx.rsi7 < InpShortMinRsi7 || ctx.rsi7 > InpShortMaxRsi7))
      return false;
   if(InpUseRsi14Filter && (ctx.rsi14 < InpShortMinRsi14 || ctx.rsi14 > InpShortMaxRsi14))
      return false;
   if(InpUseMacdLineAtrFilter && ctx.macdLineAtr < InpShortMinMacdLineAtr)
      return false;
   if(InpUseStochFilter && (ctx.stochK < InpShortMinStochK || ctx.stochD < InpShortMinStochD))
      return false;
   if(InpUseTickVolumeRel10Filter && ctx.tickVolumeRel10 > InpShortMaxTickVolumeRel10)
      return false;
   if(InpUseHighBreak24Filter && ctx.highBreak24 < InpShortMinHighBreak24Atr)
      return false;

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

void OpenShortPosition(const SignalContext &ctx)
  {
   double bid = SymbolInfoDouble(runtimeSymbol, SYMBOL_BID);
   if(bid <= 0.0)
      return;

   double structureHigh = ComputePreviousHigh(1, MathMax(2, InpStructureLookbackBars));
   if(structureHigh == DBL_MAX)
      return;

   double minStop = bid + ctx.atr * InpMinStopATR;
   double structureStop = structureHigh + ctx.atr * InpStructureBufferATR;
   double sl = NormalizePrice(MathMax(minStop, structureStop));
   double price = NormalizePrice(bid);
   double stopDistance = sl - price;
   if(stopDistance <= 0.0)
      return;

   if(!ValidateStopLoss(ORDER_TYPE_SELL, price, sl))
      return;

   double tp = 0.0;
   if(InpTargetRMultiple > 0.0)
      tp = NormalizePrice(price - stopDistance * InpTargetRMultiple);

   double volume = CalculateVolume(stopDistance);
   if(volume <= 0.0)
      return;

   if(trade.Sell(volume, runtimeSymbol, 0.0, sl, tp, "late_quiet_spike_short"))
      dailyTradeCount++;
   else
      Print("Order failed: ", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
  }

void ManageOpenPositions()
  {
   double ema20[1];
   double atr[1];
   if(CopyBuffer(ema20Handle, 0, 1, 1, ema20) != 1 || CopyBuffer(atrHandle, 0, 1, 1, atr) != 1)
      return;

   double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
   if(close1 <= 0.0 || atr[0] <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      string symbol = PositionGetSymbol(i);
      if(symbol != runtimeSymbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      int type = (int)PositionGetInteger(POSITION_TYPE);
      if(type != POSITION_TYPE_SELL)
         continue;

      bool timeExit = (HeldBars((datetime)PositionGetInteger(POSITION_TIME)) >= InpHoldBars);
      bool meanExit = false;
      if(InpExitOnMeanReversion)
        {
         double exitPrice = ema20[0] + atr[0] * InpExitBufferATR;
         meanExit = (close1 <= exitPrice);
        }

      if(!timeExit && !meanExit)
         continue;

      ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
      if(!trade.PositionClose(ticket))
         Print("Exit failed for ticket ", ticket, ": ", trade.ResultRetcodeDescription());
     }
  }

int OnInit()
  {
   runtimeSymbol = NormalizePresetString(InpSymbol);
   runtimeAllowedWeekdays = NormalizePresetString(InpAllowedWeekdays);
   runtimeBlockedEntryHours = NormalizePresetString(InpBlockedEntryHours);
   ArrayInitialize(allowedWeekdays, false);
   ArrayInitialize(blockedHours, false);

   if(InpMagicNumber <= 0 || InpFastEMAPeriod <= 0 || InpSlowEMAPeriod <= 0 || InpTrendEMAPeriod <= 0 ||
      InpATRPeriod <= 0 || InpRSIFastPeriod <= 0 || InpRSISlowPeriod <= 0 || InpRiskPercent <= 0.0 ||
      InpHoldBars < 0 || InpMinStopATR <= 0.0 || InpTargetRMultiple < 0.0 || InpMaxTradesPerDay < 0 ||
      InpMaxOpenTrades < 0 || InpMaxEffectiveRiskPercentAtMinLot < 0.0)
     {
      Print("Invalid late-quiet-spike parameters.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!ParseIntList(runtimeAllowedWeekdays, allowedWeekdays, 7) ||
      !ParseIntList(runtimeBlockedEntryHours, blockedHours, 24))
     {
      Print("Invalid weekday or blocked-hour filters.");
      return INIT_PARAMETERS_INCORRECT;
     }

   trade.SetExpertMagicNumber((ulong)InpMagicNumber);
   SetTradeDeviation();

   atrHandle = iATR(runtimeSymbol, InpSignalTimeframe, InpATRPeriod);
   ema20Handle = iMA(runtimeSymbol, InpSignalTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   ema50Handle = iMA(runtimeSymbol, InpSignalTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   ema100Handle = iMA(runtimeSymbol, InpSignalTimeframe, InpTrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   rsi7Handle = iRSI(runtimeSymbol, InpSignalTimeframe, InpRSIFastPeriod, PRICE_CLOSE);
   rsi14Handle = iRSI(runtimeSymbol, InpSignalTimeframe, InpRSISlowPeriod, PRICE_CLOSE);
   macdHandle = iMACD(runtimeSymbol, InpSignalTimeframe, 12, 26, 9, PRICE_CLOSE);
   stochHandle = iStochastic(runtimeSymbol, InpSignalTimeframe, 14, 3, 3, MODE_SMA, STO_LOWHIGH);

   if(atrHandle == INVALID_HANDLE || ema20Handle == INVALID_HANDLE || ema50Handle == INVALID_HANDLE ||
      ema100Handle == INVALID_HANDLE || rsi7Handle == INVALID_HANDLE || rsi14Handle == INVALID_HANDLE ||
      macdHandle == INVALID_HANDLE || stochHandle == INVALID_HANDLE)
     {
      Print("Failed to create indicator handles.");
      return INIT_FAILED;
     }

   InitializeDayState(TimeCurrent());
   equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   ReleaseHandle(atrHandle);
   ReleaseHandle(ema20Handle);
   ReleaseHandle(ema50Handle);
   ReleaseHandle(ema100Handle);
   ReleaseHandle(rsi7Handle);
   ReleaseHandle(rsi14Handle);
   ReleaseHandle(macdHandle);
   ReleaseHandle(stochHandle);
  }

void OnTick()
  {
   UpdateDayState(TimeCurrent());
   UpdateEquityPeak();
   ManageOpenPositions();

   datetime currentBar = iTime(runtimeSymbol, InpSignalTimeframe, 0);
   if(currentBar == 0 || currentBar == lastBarTime)
      return;

   lastBarTime = currentBar;

   SignalContext ctx;
   if(!LoadSignalContext(ctx))
      return;

   if(!CanOpenNewEntries(ctx))
      return;

   if(IsShortSignal(ctx))
      OpenShortPosition(ctx);
  }
