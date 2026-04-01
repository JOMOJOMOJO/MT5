//+------------------------------------------------------------------+
//| BTCUSD Session Pair RR Prototype                                 |
//+------------------------------------------------------------------+
#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "1.00"
#property strict
#property description "BTCUSD M5 session-pair prototype with explicit R-based risk and reward"

#include <Trade\Trade.mqh>

CTrade trade;

enum TrendFilterMode
  {
   TrendNone = 0,
   TrendBull = 1,
   TrendBear = 2
  };

input string          InpSymbol                  = "BTCUSD";
input ENUM_TIMEFRAMES InpSignalTimeframe         = PERIOD_M5;
input int             InpFastEMAPeriod           = 20;
input int             InpSlowEMAPeriod           = 50;
input int             InpRSIPeriod               = 14;
input int             InpATRPeriod               = 14;

input bool            InpEnableLong              = true;
input int             InpLongStartHour           = 20;
input int             InpLongEndHour             = 24;
input double          InpLongDistanceATR         = 1.20;
input double          InpLongRsiMax              = 35.0;
input int             InpLongTrendFilter         = TrendNone;
input int             InpLongHoldBars            = 12;

input bool            InpEnableShort             = true;
input int             InpShortStartHour          = 13;
input int             InpShortEndHour            = 22;
input double          InpShortDistanceATR        = 0.60;
input double          InpShortRsiMin             = 60.0;
input int             InpShortTrendFilter        = TrendBear;
input int             InpShortHoldBars           = 12;

input double          InpStopATR                 = 1.00;
input double          InpTargetRMultiple         = 1.35;
input double          InpRiskPercent             = 0.35;

input bool            InpUseDailyLossCap         = true;
input double          InpDailyLossCapPercent     = 3.0;
input bool            InpUseEquityKillSwitch     = true;
input double          InpEquityKillSwitchPercent = 12.0;
input int             InpMaxTradesPerDay         = 12;
input int             InpMaxOpenTrades           = 2;
input int             InpMaxOpenPerSide          = 1;
input double          InpMaxSpreadPips           = 2500.0;
input double          InpMaxDeviationPips        = 250.0;
input string          InpAllowedWeekdays         = "0,1,2,3,4,6";
input string          InpBlockedEntryHours       = "3";
input long            InpMagicNumber             = 20260381;

int fastHandle = INVALID_HANDLE;
int slowHandle = INVALID_HANDLE;
int rsiHandle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;

bool allowedWeekdays[7];
bool blockedHours[24];
string runtimeSymbol = "";
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
   double   fastEma;
   double   slowEma;
   double   rsi;
   double   atr;
  };

int OnInit()
  {
   runtimeSymbol = InpSymbol;
   ArrayInitialize(allowedWeekdays, false);
   ArrayInitialize(blockedHours, false);

   if(InpMagicNumber <= 0 || InpFastEMAPeriod <= 0 || InpSlowEMAPeriod <= 0 || InpRSIPeriod <= 0 ||
      InpATRPeriod <= 0 || InpStopATR <= 0.0 || InpTargetRMultiple <= 0.0 || InpRiskPercent <= 0.0 ||
      InpLongHoldBars < 0 || InpShortHoldBars < 0 || InpMaxTradesPerDay < 0 || InpMaxOpenTrades < 0 ||
      InpMaxOpenPerSide < 0 || InpLongTrendFilter < TrendNone || InpLongTrendFilter > TrendBear ||
      InpShortTrendFilter < TrendNone || InpShortTrendFilter > TrendBear)
     {
      Print("Invalid session-pair parameters.");
      return INIT_PARAMETERS_INCORRECT;
     }

   if(!ParseIntList(InpAllowedWeekdays, allowedWeekdays, 7) || !ParseIntList(InpBlockedEntryHours, blockedHours, 24))
     {
      Print("Invalid weekday or blocked-hour filters.");
      return INIT_PARAMETERS_INCORRECT;
     }

   trade.SetExpertMagicNumber((ulong)InpMagicNumber);
   SetTradeDeviation();

   fastHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle = iRSI(runtimeSymbol, InpSignalTimeframe, InpRSIPeriod, PRICE_CLOSE);
   atrHandle = iATR(runtimeSymbol, InpSignalTimeframe, InpATRPeriod);

   if(fastHandle == INVALID_HANDLE || slowHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
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
   ReleaseHandle(fastHandle);
   ReleaseHandle(slowHandle);
   ReleaseHandle(rsiHandle);
   ReleaseHandle(atrHandle);
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
   double fast[1];
   double slow[1];
   double rsi[1];
   double atr[1];
   MqlRates rates[1];

   if(CopyBuffer(fastHandle, 0, 1, 1, fast) != 1 ||
      CopyBuffer(slowHandle, 0, 1, 1, slow) != 1 ||
      CopyBuffer(rsiHandle, 0, 1, 1, rsi) != 1 ||
      CopyBuffer(atrHandle, 0, 1, 1, atr) != 1 ||
      CopyRates(runtimeSymbol, InpSignalTimeframe, 1, 1, rates) != 1)
      return false;

   if(atr[0] <= 0.0)
      return false;

   MqlDateTime tm;
   TimeToStruct(rates[0].time, tm);

   ctx.barTime = rates[0].time;
   ctx.hour = tm.hour;
   ctx.weekday = tm.day_of_week;
   ctx.close = rates[0].close;
   ctx.fastEma = fast[0];
   ctx.slowEma = slow[0];
   ctx.rsi = rsi[0];
   ctx.atr = atr[0];
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

   if(!TrendPasses(ctx.fastEma, ctx.slowEma, (TrendFilterMode)InpLongTrendFilter))
      return false;

   double distance = (ctx.close - ctx.fastEma) / ctx.atr;
   return distance <= -InpLongDistanceATR && ctx.rsi <= InpLongRsiMax;
  }

bool IsShortSignal(const SignalContext &ctx)
  {
   if(!InpEnableShort || !HourInWindow(ctx.hour, InpShortStartHour, InpShortEndHour))
      return false;

   if(!TrendPasses(ctx.fastEma, ctx.slowEma, (TrendFilterMode)InpShortTrendFilter))
      return false;

   double distance = (ctx.close - ctx.fastEma) / ctx.atr;
   return distance >= InpShortDistanceATR && ctx.rsi >= InpShortRsiMin;
  }

bool TrendPasses(double fastEma, double slowEma, TrendFilterMode mode)
  {
   if(mode == TrendNone)
      return true;
   if(mode == TrendBull)
      return fastEma > slowEma;
   if(mode == TrendBear)
      return fastEma < slowEma;
   return false;
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

   double stopDistance = ctx.atr * InpStopATR;
   if(stopDistance <= 0.0)
      return;

   double sl = 0.0;
   double tp = 0.0;
   if(positionType == POSITION_TYPE_BUY)
     {
      sl = NormalizePrice(price - stopDistance);
      tp = NormalizePrice(price + stopDistance * InpTargetRMultiple);
     }
   else
     {
      sl = NormalizePrice(price + stopDistance);
      tp = NormalizePrice(price - stopDistance * InpTargetRMultiple);
     }

   double volume = CalculateVolume(stopDistance);
   if(volume <= 0.0)
      return;

   bool result = false;
   if(positionType == POSITION_TYPE_BUY)
      result = trade.Buy(volume, runtimeSymbol, 0.0, sl, tp, "session_pair_rr_long");
   else
      result = trade.Sell(volume, runtimeSymbol, 0.0, sl, tp, "session_pair_rr_short");

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

   double rawVolume = riskAmount / moneyPerLot;
   double normalized = MathFloor(rawVolume / stepVolume) * stepVolume;
   if(normalized < minVolume)
      return 0.0;
   if(normalized > maxVolume)
      normalized = maxVolume;
   return NormalizeDouble(normalized, 2);
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
