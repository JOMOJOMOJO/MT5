#property strict
#property version   "1.00"
#property description "BTCUSD fractal trend pullback research EA with explicit EMA-anchor stop and R-based target"

#include <Trade/Trade.mqh>

CTrade trade;

input string          InpSymbol                   = "BTCUSD";
input ENUM_TIMEFRAMES InpSignalTimeframe          = PERIOD_M1;
input bool            InpAllowLong                = true;
input bool            InpAllowShort               = true;

input int             InpFastEmaPeriod            = 16;
input int             InpMidEmaPeriod             = 60;
input int             InpSlowEmaPeriod            = 150;

input bool            InpEnableAdxFilter          = true;
input int             InpAdxPeriod                = 22;
input double          InpAdxThreshold             = 30.0;

input bool            InpEnableRsiFilter          = true;
input int             InpRsiPeriod                = 18;
input double          InpLongRsiMin               = 62.0;
input double          InpShortRsiMax              = 48.0;

input bool            InpEnableStochFilter        = true;
input int             InpStochKPeriod             = 5;
input int             InpStochDPeriod             = 1;
input int             InpStochSlowing             = 1;
input double          InpStochBuyLevel            = 18.0;
input double          InpStochSellLevel           = 84.0;

input int             InpAtrPeriod                = 14;
input double          InpMinAtrValue              = 83.0;
input int             InpFractalLookbackBars      = 5;
input double          InpRiskReward               = 1.50;
input double          InpStopBufferAtrMultiplier  = 0.00;
input int             InpMaxHoldBars              = 0;

input double          InpRiskPercent              = 0.30;
input double          InpMinLot                   = 0.01;
input double          InpMaxLot                   = 0.50;

input int             InpMaxTradesPerDay          = 2;
input int             InpMaxConsecutiveLosses     = 3;
input int             InpCooldownBars             = 60;
input double          InpDailyLossCapPercent      = 3.0;
input double          InpEquityDrawdownCapPercent = 8.0;
input bool            InpFlattenOnDailyLoss       = true;
input bool            InpFlattenOnEquityCap       = true;
input double          InpMaxSpreadValue           = 120.0;
input int             InpSlippagePoints           = 200;

input ulong           InpMagicNumber              = 2026040901;

int      fastEmaHandle           = INVALID_HANDLE;
int      midEmaHandle            = INVALID_HANDLE;
int      slowEmaHandle           = INVALID_HANDLE;
int      adxHandle               = INVALID_HANDLE;
int      rsiHandle               = INVALID_HANDLE;
int      atrHandle               = INVALID_HANDLE;
int      fractalHandle           = INVALID_HANDLE;
int      stochHandle             = INVALID_HANDLE;

datetime lastSignalBarTime       = 0;
datetime cooldownUntil           = 0;
int      consecutiveLosses       = 0;
int      currentDayKey           = 0;
int      tradesToday             = 0;
double   todayClosedPnl          = 0.0;
double   todayStartEquity        = 0.0;
double   equityPeak              = 0.0;
bool     dayLossStopped          = false;
bool     equityCapStopped        = false;

bool     virtualStopsActive      = false;
double   virtualStopPrice        = 0.0;
double   virtualTargetPrice      = 0.0;
long     virtualPositionType     = POSITION_TYPE_BUY;

int DayKey(datetime when)
  {
   MqlDateTime stamp;
   TimeToStruct(when, stamp);
   return (stamp.year * 10000) + (stamp.mon * 100) + stamp.day;
  }

double NormalizePrice(double price)
  {
   int digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
  }

double CurrentSpreadValue()
  {
   double ask = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return -1.0;
   return ask - bid;
  }

bool IsSpreadAcceptable()
  {
   if(InpMaxSpreadValue <= 0.0)
      return true;

   double spread = CurrentSpreadValue();
   if(spread < 0.0)
      return false;
   return (spread <= InpMaxSpreadValue);
  }

void ResetDailyStateIfNeeded(datetime now)
  {
   int todayKey = DayKey(now);
   if(todayKey == currentDayKey)
      return;

   currentDayKey = todayKey;
   tradesToday = 0;
   todayClosedPnl = 0.0;
   todayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   dayLossStopped = false;
  }

bool HasAnyOpenPosition()
  {
   return PositionSelect(InpSymbol);
  }

bool ManagedPositionSelected()
  {
   if(!PositionSelect(InpSymbol))
      return false;

   long magic = PositionGetInteger(POSITION_MAGIC);
   return (magic == (long)InpMagicNumber);
  }

void ClearVirtualStops()
  {
   virtualStopsActive = false;
   virtualStopPrice = 0.0;
   virtualTargetPrice = 0.0;
  }

void UpdateEquityPeak()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity > equityPeak)
      equityPeak = equity;
  }

bool CloseManagedPosition(string reason)
  {
   if(!ManagedPositionSelected())
      return false;

   if(!trade.PositionClose(InpSymbol))
     {
      Print("Close failed: ", reason, " retcode=", trade.ResultRetcode(),
            " description=", trade.ResultRetcodeDescription());
      return false;
     }

   ClearVirtualStops();
   Print("Position closed: ", reason);
   return true;
  }

bool CheckRiskStops()
  {
   datetime now = TimeCurrent();
   ResetDailyStateIfNeeded(now);
   UpdateEquityPeak();

   if(todayStartEquity <= 0.0)
      todayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equityPeak <= 0.0)
      equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);

   if(!dayLossStopped && InpDailyLossCapPercent > 0.0)
     {
      double maxLoss = todayStartEquity * (InpDailyLossCapPercent / 100.0);
      if(todayClosedPnl <= -maxLoss)
        {
         dayLossStopped = true;
         Print("Daily loss cap hit. Closed PnL=", todayClosedPnl);
         if(InpFlattenOnDailyLoss)
            CloseManagedPosition("daily_loss_cap");
        }
     }

   if(!equityCapStopped && InpEquityDrawdownCapPercent > 0.0 && equityPeak > 0.0)
     {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double drawdownPercent = ((equityPeak - equity) / equityPeak) * 100.0;
      if(drawdownPercent >= InpEquityDrawdownCapPercent)
        {
         equityCapStopped = true;
         Print("Equity drawdown cap hit: ", DoubleToString(drawdownPercent, 2), "%");
         if(InpFlattenOnEquityCap)
            CloseManagedPosition("equity_dd_cap");
        }
     }

   return (!dayLossStopped && !equityCapStopped);
  }

bool IsNewSignalBar()
  {
   datetime barTime = iTime(InpSymbol, InpSignalTimeframe, 0);
   if(barTime <= 0)
      return false;
   if(barTime == lastSignalBarTime)
      return false;

   lastSignalBarTime = barTime;
   return true;
  }

bool HasRecentFractal(const double &fractalValues[], int copied, double &level)
  {
   for(int i = 1; i < copied; ++i)
     {
      double value = fractalValues[i];
      if(value != EMPTY_VALUE && MathIsValidNumber(value) && value > 0.0)
        {
         level = value;
         return true;
        }
     }
   level = 0.0;
   return false;
  }

double NormalizeVolumeToStep(double rawVolume)
  {
   double minVolume = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_STEP);
   double volume = MathMax(rawVolume, minVolume);
   volume = MathMin(volume, maxVolume);

   if(step > 0.0)
      volume = MathFloor(volume / step) * step;

   volume = MathMax(volume, minVolume);
   volume = MathMin(volume, maxVolume);
   return NormalizeDouble(volume, 2);
  }

double CalculateLotSize(double entryPrice, double stopPrice)
  {
   double tickSize = SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_VALUE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = equity * (InpRiskPercent / 100.0);
   double stopDistance = MathAbs(entryPrice - stopPrice);

   if(tickSize <= 0.0 || tickValue <= 0.0 || stopDistance <= 0.0 || riskAmount <= 0.0)
      return 0.0;

   double volume = riskAmount / ((stopDistance / tickSize) * tickValue);
   volume = MathMax(volume, InpMinLot);
   volume = MathMin(volume, InpMaxLot);
   return NormalizeVolumeToStep(volume);
  }

bool CanTradeNow()
  {
   datetime now = TimeCurrent();
   ResetDailyStateIfNeeded(now);

   if(!CheckRiskStops())
      return false;

   if(HasAnyOpenPosition())
      return false;

   if(tradesToday >= InpMaxTradesPerDay)
      return false;

   if(!IsSpreadAcceptable())
      return false;

   if(consecutiveLosses >= InpMaxConsecutiveLosses && now < cooldownUntil)
      return false;

   return true;
  }

bool PrepareTrendBuffers(MqlRates &signalBar,
                         double &fastEma,
                         double &midEma,
                         double &slowEma,
                         double &adxValue,
                         double &rsiValue,
                         double &atrValue,
                         double &stochMainPrev,
                         double &stochMainNow,
                         double &stochSignalNow,
                         double &recentUpFractal,
                         double &recentDownFractal)
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(InpSymbol, InpSignalTimeframe, 0, 3, rates) < 3)
      return false;

   double fastEmaBuffer[];
   double midEmaBuffer[];
   double slowEmaBuffer[];
   double adxBuffer[];
   double rsiBuffer[];
   double atrBuffer[];
   double stochMain[];
   double stochSignal[];
   double upFractal[];
   double downFractal[];

   ArraySetAsSeries(fastEmaBuffer, true);
   ArraySetAsSeries(midEmaBuffer, true);
   ArraySetAsSeries(slowEmaBuffer, true);
   ArraySetAsSeries(adxBuffer, true);
   ArraySetAsSeries(rsiBuffer, true);
   ArraySetAsSeries(atrBuffer, true);
   ArraySetAsSeries(stochMain, true);
   ArraySetAsSeries(stochSignal, true);
   ArraySetAsSeries(upFractal, true);
   ArraySetAsSeries(downFractal, true);

   int fractalBars = MathMax(3, InpFractalLookbackBars + 1);

   if(CopyBuffer(fastEmaHandle, 0, 0, 3, fastEmaBuffer) < 3 ||
      CopyBuffer(midEmaHandle, 0, 0, 3, midEmaBuffer) < 3 ||
      CopyBuffer(slowEmaHandle, 0, 0, 3, slowEmaBuffer) < 3 ||
      CopyBuffer(adxHandle, 0, 0, 3, adxBuffer) < 3 ||
      CopyBuffer(rsiHandle, 0, 0, 3, rsiBuffer) < 3 ||
      CopyBuffer(atrHandle, 0, 0, 3, atrBuffer) < 3 ||
      CopyBuffer(stochHandle, 0, 0, 4, stochMain) < 4 ||
      CopyBuffer(stochHandle, 1, 0, 4, stochSignal) < 4 ||
      CopyBuffer(fractalHandle, 0, 0, fractalBars, upFractal) < fractalBars ||
      CopyBuffer(fractalHandle, 1, 0, fractalBars, downFractal) < fractalBars)
      return false;

   signalBar = rates[1];
   fastEma = fastEmaBuffer[1];
   midEma = midEmaBuffer[1];
   slowEma = slowEmaBuffer[1];
   adxValue = adxBuffer[1];
   rsiValue = rsiBuffer[1];
   atrValue = atrBuffer[1];
   stochMainPrev = stochMain[2];
   stochMainNow = stochMain[1];
   stochSignalNow = stochSignal[1];

   if(!HasRecentFractal(upFractal, fractalBars, recentUpFractal))
      recentUpFractal = 0.0;
   if(!HasRecentFractal(downFractal, fractalBars, recentDownFractal))
      recentDownFractal = 0.0;

   return true;
  }

bool EvaluateLongEntry(double &stopPrice)
  {
   MqlRates signalBar;
   double fastEma = 0.0;
   double midEma = 0.0;
   double slowEma = 0.0;
   double adxValue = 0.0;
   double rsiValue = 0.0;
   double atrValue = 0.0;
   double stochMainPrev = 0.0;
   double stochMainNow = 0.0;
   double stochSignalNow = 0.0;
   double recentUpFractal = 0.0;
   double recentDownFractal = 0.0;

   if(!PrepareTrendBuffers(signalBar, fastEma, midEma, slowEma, adxValue, rsiValue, atrValue,
                           stochMainPrev, stochMainNow, stochSignalNow, recentUpFractal, recentDownFractal))
      return false;

   if(!(fastEma > midEma && midEma > slowEma))
      return false;
   if(signalBar.close <= signalBar.open)
      return false;
   if(recentDownFractal <= 0.0)
      return false;
   if(atrValue < InpMinAtrValue)
      return false;
   if(InpEnableAdxFilter && adxValue < InpAdxThreshold)
      return false;
   if(InpEnableRsiFilter && rsiValue < InpLongRsiMin)
      return false;
   if(InpEnableStochFilter)
     {
      bool stochBuySignal = (stochMainPrev < InpStochBuyLevel &&
                             stochMainNow > stochMainPrev &&
                             stochMainNow > InpStochBuyLevel &&
                             stochMainNow >= stochSignalNow);
      if(!stochBuySignal)
         return false;
     }

   double bid = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;

   stopPrice = 0.0;
   if(bid < fastEma && bid > midEma)
      stopPrice = midEma;
   else if(bid < midEma && bid > slowEma)
      stopPrice = slowEma;

   if(stopPrice <= 0.0)
      return false;

   stopPrice -= (atrValue * InpStopBufferAtrMultiplier);
   stopPrice = NormalizePrice(stopPrice);
   return (stopPrice < bid);
  }

bool EvaluateShortEntry(double &stopPrice)
  {
   MqlRates signalBar;
   double fastEma = 0.0;
   double midEma = 0.0;
   double slowEma = 0.0;
   double adxValue = 0.0;
   double rsiValue = 0.0;
   double atrValue = 0.0;
   double stochMainPrev = 0.0;
   double stochMainNow = 0.0;
   double stochSignalNow = 0.0;
   double recentUpFractal = 0.0;
   double recentDownFractal = 0.0;

   if(!PrepareTrendBuffers(signalBar, fastEma, midEma, slowEma, adxValue, rsiValue, atrValue,
                           stochMainPrev, stochMainNow, stochSignalNow, recentUpFractal, recentDownFractal))
      return false;

   if(!(fastEma < midEma && midEma < slowEma))
      return false;
   if(signalBar.close >= signalBar.open)
      return false;
   if(recentUpFractal <= 0.0)
      return false;
   if(atrValue < InpMinAtrValue)
      return false;
   if(InpEnableAdxFilter && adxValue < InpAdxThreshold)
      return false;
   if(InpEnableRsiFilter && rsiValue > InpShortRsiMax)
      return false;
   if(InpEnableStochFilter)
     {
      bool stochSellSignal = (stochMainPrev > InpStochSellLevel &&
                              stochMainNow < stochMainPrev &&
                              stochMainNow < InpStochSellLevel &&
                              stochMainNow <= stochSignalNow);
      if(!stochSellSignal)
         return false;
     }

   double ask = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   stopPrice = 0.0;
   if(ask > fastEma && ask < midEma)
      stopPrice = midEma;
   else if(ask > midEma && ask < slowEma)
      stopPrice = slowEma;

   if(stopPrice <= 0.0)
      return false;

   stopPrice += (atrValue * InpStopBufferAtrMultiplier);
   stopPrice = NormalizePrice(stopPrice);
   return (stopPrice > ask);
  }

bool SendMarketOrder(ENUM_ORDER_TYPE orderType, double stopPrice)
  {
   double ask = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
   double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
   double entryPrice = (orderType == ORDER_TYPE_BUY) ? ask : bid;
   double riskDistance = MathAbs(entryPrice - stopPrice);

   if(entryPrice <= 0.0 || point <= 0.0 || riskDistance <= 0.0)
      return false;

   double targetPrice = (orderType == ORDER_TYPE_BUY)
                        ? entryPrice + (riskDistance * InpRiskReward)
                        : entryPrice - (riskDistance * InpRiskReward);
   targetPrice = NormalizePrice(targetPrice);

   double volume = CalculateLotSize(entryPrice, stopPrice);
   if(volume <= 0.0)
      return false;

   int stopsLevel = (int)SymbolInfoInteger(InpSymbol, SYMBOL_TRADE_STOPS_LEVEL);
   int freezeLevel = (int)SymbolInfoInteger(InpSymbol, SYMBOL_TRADE_FREEZE_LEVEL);
   double minDistance = MathMax(stopsLevel, freezeLevel) * point;

   bool useVirtualStops = (minDistance > 0.0 &&
                           (MathAbs(entryPrice - stopPrice) < minDistance ||
                            MathAbs(targetPrice - entryPrice) < minDistance));

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);
   trade.SetTypeFillingBySymbol(InpSymbol);

   bool submitted = false;
   string comment = EnumToString(InpSignalTimeframe) + " fractal trend";

   if(orderType == ORDER_TYPE_BUY)
      submitted = trade.Buy(volume, InpSymbol, 0.0, useVirtualStops ? 0.0 : stopPrice,
                            useVirtualStops ? 0.0 : targetPrice, comment);
   else
      submitted = trade.Sell(volume, InpSymbol, 0.0, useVirtualStops ? 0.0 : stopPrice,
                             useVirtualStops ? 0.0 : targetPrice, comment);

   if(!submitted)
     {
      Print("Order send failed. retcode=", trade.ResultRetcode(),
            " description=", trade.ResultRetcodeDescription());
      return false;
     }

   if(useVirtualStops)
     {
      virtualStopsActive = true;
      virtualStopPrice = stopPrice;
      virtualTargetPrice = targetPrice;
      virtualPositionType = (orderType == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
     }
   else
     {
      ClearVirtualStops();
     }

   tradesToday++;
   return true;
  }

void MonitorVirtualStops()
  {
   if(!virtualStopsActive || !ManagedPositionSelected())
      return;

   long positionType = PositionGetInteger(POSITION_TYPE);
   double bid = SymbolInfoDouble(InpSymbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(InpSymbol, SYMBOL_ASK);
   double price = (positionType == POSITION_TYPE_BUY) ? bid : ask;

   if(price <= 0.0)
      return;

   bool hitStop = false;
   bool hitTarget = false;

   if(positionType == POSITION_TYPE_BUY)
     {
      hitStop = (price <= virtualStopPrice);
      hitTarget = (price >= virtualTargetPrice);
     }
   else
     {
      hitStop = (price >= virtualStopPrice);
      hitTarget = (price <= virtualTargetPrice);
     }

   if(hitStop || hitTarget)
      CloseManagedPosition(hitStop ? "virtual_stop" : "virtual_target");
  }

void EnforceHoldTime()
  {
   if(InpMaxHoldBars <= 0 || !ManagedPositionSelected())
      return;

   datetime openedAt = (datetime)PositionGetInteger(POSITION_TIME);
   int barsOpen = iBarShift(InpSymbol, InpSignalTimeframe, openedAt, false);
   if(barsOpen >= InpMaxHoldBars)
      CloseManagedPosition("time_stop");
  }

int OnInit()
  {
   if(InpFastEmaPeriod <= 0 || InpMidEmaPeriod <= InpFastEmaPeriod || InpSlowEmaPeriod <= InpMidEmaPeriod ||
      InpRiskReward <= 0.0 || InpRiskPercent <= 0.0 || InpMaxTradesPerDay < 0 ||
      InpMaxConsecutiveLosses < 0 || InpCooldownBars < 0 || InpFractalLookbackBars < 2)
      return INIT_PARAMETERS_INCORRECT;

   fastEmaHandle = iMA(InpSymbol, InpSignalTimeframe, InpFastEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   midEmaHandle = iMA(InpSymbol, InpSignalTimeframe, InpMidEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowEmaHandle = iMA(InpSymbol, InpSignalTimeframe, InpSlowEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   adxHandle = iADX(InpSymbol, InpSignalTimeframe, InpAdxPeriod);
   rsiHandle = iRSI(InpSymbol, InpSignalTimeframe, InpRsiPeriod, PRICE_CLOSE);
   atrHandle = iATR(InpSymbol, InpSignalTimeframe, InpAtrPeriod);
   fractalHandle = iFractals(InpSymbol, InpSignalTimeframe);
   stochHandle = iStochastic(InpSymbol, InpSignalTimeframe, InpStochKPeriod, InpStochDPeriod,
                             InpStochSlowing, MODE_SMA, STO_LOWHIGH);

   if(fastEmaHandle == INVALID_HANDLE || midEmaHandle == INVALID_HANDLE || slowEmaHandle == INVALID_HANDLE ||
      adxHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE ||
      fractalHandle == INVALID_HANDLE || stochHandle == INVALID_HANDLE)
     {
      Print("Indicator handle creation failed");
      return INIT_FAILED;
     }

   currentDayKey = DayKey(TimeCurrent());
   todayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   equityPeak = todayStartEquity;
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);
   trade.SetTypeFillingBySymbol(InpSymbol);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(fastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(fastEmaHandle);
   if(midEmaHandle != INVALID_HANDLE)
      IndicatorRelease(midEmaHandle);
   if(slowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(slowEmaHandle);
   if(adxHandle != INVALID_HANDLE)
      IndicatorRelease(adxHandle);
   if(rsiHandle != INVALID_HANDLE)
      IndicatorRelease(rsiHandle);
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
   if(fractalHandle != INVALID_HANDLE)
      IndicatorRelease(fractalHandle);
   if(stochHandle != INVALID_HANDLE)
      IndicatorRelease(stochHandle);
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
   long magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(symbol != InpSymbol || magic != (long)InpMagicNumber || entry != DEAL_ENTRY_OUT)
      return;

   datetime dealTime = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
   ResetDailyStateIfNeeded(dealTime);

   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) +
                   HistoryDealGetDouble(trans.deal, DEAL_SWAP) +
                   HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   todayClosedPnl += profit;

   if(profit < 0.0)
     {
      consecutiveLosses++;
      cooldownUntil = dealTime + (InpCooldownBars * PeriodSeconds(InpSignalTimeframe));
     }
   else if(profit > 0.0)
     {
      consecutiveLosses = 0;
     }

   ClearVirtualStops();
  }

void OnTick()
  {
   MonitorVirtualStops();
   EnforceHoldTime();
   CheckRiskStops();

   if(!IsNewSignalBar())
      return;

   if(!CanTradeNow())
      return;

   double stopPrice = 0.0;
   if(InpAllowLong && EvaluateLongEntry(stopPrice))
     {
      SendMarketOrder(ORDER_TYPE_BUY, stopPrice);
      return;
     }

   if(InpAllowShort && EvaluateShortEntry(stopPrice))
      SendMarketOrder(ORDER_TYPE_SELL, stopPrice);
  }

double OnTester()
  {
   double trades = TesterStatistics(STAT_TRADES);
   double profit = TesterStatistics(STAT_PROFIT);
   double profitFactor = TesterStatistics(STAT_PROFIT_FACTOR);
   double drawdown = TesterStatistics(STAT_EQUITY_DD);

   if(trades < 6.0 || profit <= 0.0 || profitFactor <= 0.0 || drawdown <= 0.0)
      return 0.0;

   double cappedPf = MathMin(profitFactor, 3.0);
   double tradeWeight = MathMin(2.0, trades / 20.0);
   return (profit / drawdown) * cappedPf * tradeWeight;
  }
