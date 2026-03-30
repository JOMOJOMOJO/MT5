//+------------------------------------------------------------------+
//| BTCUSD Regime Pullback / Breakout EA                             |
//| Reworked for higher-timeframe regime validation                  |
//+------------------------------------------------------------------+

#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "3.00"
#property strict
#property description "BTCUSD regime-aware M15 pullback and breakout trader"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

CTrade trade;
CPositionInfo posInfo;

input string          InpSymbol                = "BTCUSD";
input ENUM_TIMEFRAMES InpSignalTimeframe       = PERIOD_M15;
input ENUM_TIMEFRAMES InpRegimeTimeframe       = PERIOD_H1;
input bool            InpUseConfirmRegime      = true;
input ENUM_TIMEFRAMES InpConfirmRegimeTimeframe = PERIOD_H4;
input int             InpSignalFastEMAPeriod   = 20;
input int             InpSignalSlowEMAPeriod   = 50;
input int             InpRegimeFastEMAPeriod   = 50;
input int             InpRegimeSlowEMAPeriod   = 200;
input int             InpConfirmFastEMAPeriod  = 50;
input int             InpConfirmSlowEMAPeriod  = 200;
input int             InpRSIPeriod             = 14;
input int             InpATRPeriod             = 14;
input double          InpRiskPercent           = 0.35;
input int             InpMaxOpenTrades         = 1;

input bool            InpUseTimeFilter         = false;
input int             InpTradeStartHour        = 0;
input int             InpTradeEndHour          = 24;
input bool            InpAllowBuy              = true;
input bool            InpAllowSell             = true;
input bool            InpUseLossStop           = true;
input int             InpMaxConsecutiveLosses  = 2;
input bool            InpUseDailyLossCap       = true;
input double          InpDailyLossCapPercent   = 2.5;
input int             InpLossCooldownBars      = 8;
input double          InpMinTradesPerDay       = 0.10;
input double          InpTargetTradesPerDay    = 0.30;
input bool            InpUseHardTradeFloor     = false;
input bool            InpUseFreezeLevelCheck   = false;

// Logic mask: 1=Pullback, 2=Breakout
input int             InpBuyLogicMask          = 1;
input int             InpSellLogicMask         = 2;
input int             InpLogicCooldownBars     = 4;
input int             InpMaxOpenPerLogic       = 1;

input int             InpBreakoutLookback      = 12;
input double          InpPullbackToleranceATR  = 0.28;
input double          InpBreakoutBufferATR     = 0.04;
input double          InpMinSignalBodyATR      = 0.18;
input double          InpMinRegimeSlopePips    = 600.0;
input double          InpMinRegimeGapPips      = 1200.0;
input double          InpConfirmSlopeMultiplier = 0.50;
input double          InpConfirmGapMultiplier   = 0.50;
input double          InpMinSignalATRPips      = 6000.0;
input double          InpMaxSignalATRPips      = 50000.0;
input double          InpBuyPullbackRsiDip     = 45.0;
input double          InpBuyPullbackRsiReclaim = 50.0;
input double          InpSellPullbackRsiPeak   = 54.0;
input double          InpSellPullbackRsiReject = 50.0;
input double          InpBuyBreakoutMaxRsi     = 70.0;
input double          InpSellBreakoutMinRsi    = 30.0;
input double          InpMaxBreakoutExtensionATR = 1.20;

input double          InpStopATRMultiplier     = 1.60;
input double          InpTargetATRMultiplier   = 2.60;
input double          InpBreakEvenRR           = 1.10;
input double          InpTrailStartRR          = 1.80;
input double          InpTrailATRMultiplier    = 1.00;
input double          InpMaxSpreadPips         = 3500.0;
input long            InpMagicNumber           = 123456;
input bool            InpDebugCounters         = true;

const int REGIME_SLOPE_BARS = 3;
const int LOGIC_PULLBACK    = 1;
const int LOGIC_BREAKOUT    = 2;

int signalFastHandle = INVALID_HANDLE;
int signalSlowHandle = INVALID_HANDLE;
int regimeFastHandle = INVALID_HANDLE;
int regimeSlowHandle = INVALID_HANDLE;
int confirmFastHandle = INVALID_HANDLE;
int confirmSlowHandle = INVALID_HANDLE;
int rsiHandle        = INVALID_HANDLE;
int atrHandle        = INVALID_HANDLE;

datetime lastSignalBarTime = 0;
datetime lastLogicEntryTime[3];
datetime lastDealTime = 0;
ulong lastDealTicket = 0;
datetime lastLossTime = 0;
int consecutiveLosses = 0;
int lastDayOfYear = -1;
double initialBalance = 0.0;
double dailyStartBalance = 0.0;
double realizedPnlToday = 0.0;
datetime testStartTime = 0;

long dbgBarsSeen = 0;
long dbgBlockedMaxOpen = 0;
long dbgBlockedTradingTime = 0;
long dbgBlockedSpread = 0;
long dbgBlockedLossStop = 0;
long dbgBlockedDailyLoss = 0;
long dbgBlockedLossCooldown = 0;
long dbgBlockedSignalZero = 0;
long dbgBlockedNoRegime = 0;
long dbgBlockedAtrRange = 0;
long dbgBlockedCanEnter = 0;
long dbgSignalBuy = 0;
long dbgSignalSell = 0;
long dbgBullRegime = 0;
long dbgBearRegime = 0;
long dbgNeutralRegime = 0;
long dbgPullbackTriggers = 0;
long dbgBreakoutTriggers = 0;
long dbgBuyAttempts = 0;
long dbgSellAttempts = 0;
long dbgOrderSuccess = 0;
long dbgOrderFail = 0;
long dbgLotsZero = 0;
long dbgStopsBlocked = 0;
long dbgManagedBreakEven = 0;
long dbgManagedTrail = 0;
long dbgSignalDataShort = 0;
double dbgAtrPipsSum = 0.0;
double dbgAtrPipsMax = 0.0;
long dbgAtrSamples = 0;
double dbgSpreadSum = 0.0;
double dbgSpreadMax = 0.0;
long dbgSpreadSamples = 0;

int OnInit()
{
    trade.SetExpertMagicNumber((ulong)InpMagicNumber);
    initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    dailyStartBalance = initialBalance;
    testStartTime = TimeCurrent();

    if(InpMagicNumber <= 0)
    {
        Print("Invalid magic number.");
        return INIT_PARAMETERS_INCORRECT;
    }
    if(InpStopATRMultiplier <= 0.0 || InpTargetATRMultiplier <= 0.0 || InpRiskPercent <= 0.0)
    {
        Print("Invalid risk parameters.");
        return INIT_PARAMETERS_INCORRECT;
    }
    if(InpSignalFastEMAPeriod <= 0 || InpSignalSlowEMAPeriod <= 0 || InpRegimeFastEMAPeriod <= 0 || InpRegimeSlowEMAPeriod <= 0 ||
       InpConfirmFastEMAPeriod <= 0 || InpConfirmSlowEMAPeriod <= 0)
    {
        Print("Invalid EMA periods.");
        return INIT_PARAMETERS_INCORRECT;
    }

    signalFastHandle = iMA(InpSymbol, InpSignalTimeframe, InpSignalFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    signalSlowHandle = iMA(InpSymbol, InpSignalTimeframe, InpSignalSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    regimeFastHandle = iMA(InpSymbol, InpRegimeTimeframe, InpRegimeFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    regimeSlowHandle = iMA(InpSymbol, InpRegimeTimeframe, InpRegimeSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    confirmFastHandle = iMA(InpSymbol, InpConfirmRegimeTimeframe, InpConfirmFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    confirmSlowHandle = iMA(InpSymbol, InpConfirmRegimeTimeframe, InpConfirmSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    rsiHandle = iRSI(InpSymbol, InpSignalTimeframe, InpRSIPeriod, PRICE_CLOSE);
    atrHandle = iATR(InpSymbol, InpSignalTimeframe, InpATRPeriod);

    if(signalFastHandle == INVALID_HANDLE || signalSlowHandle == INVALID_HANDLE ||
       regimeFastHandle == INVALID_HANDLE || regimeSlowHandle == INVALID_HANDLE ||
       confirmFastHandle == INVALID_HANDLE || confirmSlowHandle == INVALID_HANDLE ||
       rsiHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
    {
        Print("Failed to create indicator handles.");
        return INIT_FAILED;
    }

    MqlTick tick;
    if(!SymbolInfoTick(InpSymbol, tick))
    {
        Print("Symbol error: ", InpSymbol);
        return INIT_FAILED;
    }

    PrintSymbolUnitInfo();
    Print("EA initialized");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    ReleaseHandle(signalFastHandle);
    ReleaseHandle(signalSlowHandle);
    ReleaseHandle(regimeFastHandle);
    ReleaseHandle(regimeSlowHandle);
    ReleaseHandle(confirmFastHandle);
    ReleaseHandle(confirmSlowHandle);
    ReleaseHandle(rsiHandle);
    ReleaseHandle(atrHandle);

    if(InpDebugCounters)
        PrintDebugSummary(reason);
}

void ReleaseHandle(int &handle)
{
    if(handle != INVALID_HANDLE)
    {
        IndicatorRelease(handle);
        handle = INVALID_HANDLE;
    }
}

void OnTick()
{
    ManageOpenPositions();

    if(!IsNewSignalBar())
        return;

    dbgBarsSeen++;

    UpdateLossStreak();
    if(IsDailyLossCapBlocked())
    {
        dbgBlockedDailyLoss++;
        return;
    }
    if(IsLossCooldownBlocked())
    {
        dbgBlockedLossCooldown++;
        return;
    }
    if(CountOpenPositions() >= InpMaxOpenTrades)
    {
        dbgBlockedMaxOpen++;
        return;
    }
    if(!IsTradingTime())
    {
        dbgBlockedTradingTime++;
        return;
    }
    if(!IsSpreadAllowed())
    {
        dbgBlockedSpread++;
        return;
    }
    if(IsLossStopBlocked())
    {
        dbgBlockedLossStop++;
        return;
    }

    int logicId = 0;
    int signal = GetTradingSignal(logicId);
    if(signal == 0)
    {
        dbgBlockedSignalZero++;
        return;
    }
    if(!CanEnterLogic(logicId))
    {
        dbgBlockedCanEnter++;
        return;
    }

    if(signal > 0)
    {
        dbgSignalBuy++;
        OpenPosition(true, logicId);
    }
    else
    {
        dbgSignalSell++;
        OpenPosition(false, logicId);
    }
}

bool IsNewSignalBar()
{
    datetime currentBarTime = iTime(InpSymbol, InpSignalTimeframe, 0);
    if(currentBarTime <= 0)
        return false;
    if(currentBarTime != lastSignalBarTime)
    {
        lastSignalBarTime = currentBarTime;
        return true;
    }
    return false;
}

void ManageOpenPositions()
{
    if(PositionsTotal() <= 0)
        return;

    MqlTick tick;
    if(!SymbolInfoTick(InpSymbol, tick))
        return;

    double atrPrice = GetCurrentATRPrice(true);
    if(atrPrice <= 0.0)
        return;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!posInfo.SelectByIndex(i))
            continue;
        if(posInfo.Symbol() != InpSymbol || posInfo.Magic() != InpMagicNumber)
            continue;

        bool isBuy = (posInfo.PositionType() == POSITION_TYPE_BUY);
        double openPrice = posInfo.PriceOpen();
        double currentSl = posInfo.StopLoss();
        double currentTp = posInfo.TakeProfit();
        if(openPrice <= 0.0 || currentSl <= 0.0 || currentTp <= 0.0)
            continue;

        double currentPrice = isBuy ? tick.bid : tick.ask;
        double initialRisk = MathAbs(openPrice - currentSl);
        if(initialRisk <= 0.0)
            continue;

        double profitDistance = isBuy ? (currentPrice - openPrice) : (openPrice - currentPrice);
        double newSl = currentSl;
        bool shouldModify = false;

        if(InpBreakEvenRR > 0.0 && profitDistance >= initialRisk * InpBreakEvenRR)
        {
            double bePrice = openPrice;
            if(isBuy && bePrice > newSl)
            {
                newSl = bePrice;
                shouldModify = true;
                dbgManagedBreakEven++;
            }
            if(!isBuy && (newSl == 0.0 || bePrice < newSl))
            {
                newSl = bePrice;
                shouldModify = true;
                dbgManagedBreakEven++;
            }
        }

        if(InpTrailStartRR > 0.0 && InpTrailATRMultiplier > 0.0 && profitDistance >= initialRisk * InpTrailStartRR)
        {
            double trailDistance = atrPrice * InpTrailATRMultiplier;
            if(trailDistance > 0.0)
            {
                double trailSl = isBuy ? (currentPrice - trailDistance) : (currentPrice + trailDistance);
                if(isBuy && trailSl > newSl)
                {
                    newSl = trailSl;
                    shouldModify = true;
                    dbgManagedTrail++;
                }
                if(!isBuy && (newSl == 0.0 || trailSl < newSl))
                {
                    newSl = trailSl;
                    shouldModify = true;
                    dbgManagedTrail++;
                }
            }
        }

        if(!shouldModify)
            continue;

        newSl = NormalizePrice(newSl);
        if(!ValidateStops(isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, currentPrice, newSl, currentTp))
            continue;
        trade.PositionModify(InpSymbol, newSl, currentTp);
    }
}

int GetTradingSignal(int &logicId)
{
    double signalFast[], signalSlow[], regimeFast[], regimeSlow[], confirmFast[], confirmSlow[], rsiBuffer[], atrBuffer[];
    int needSignalBars = MathMax(InpBreakoutLookback + 5, 8);
    int needRegimeBars = REGIME_SLOPE_BARS + 4;
    int needConfirmBars = REGIME_SLOPE_BARS + 4;

    ArraySetAsSeries(signalFast, true);
    ArraySetAsSeries(signalSlow, true);
    ArraySetAsSeries(regimeFast, true);
    ArraySetAsSeries(regimeSlow, true);
    ArraySetAsSeries(confirmFast, true);
    ArraySetAsSeries(confirmSlow, true);
    ArraySetAsSeries(rsiBuffer, true);
    ArraySetAsSeries(atrBuffer, true);

    if(CopyBuffer(signalFastHandle, 0, 0, needSignalBars, signalFast) < needSignalBars ||
       CopyBuffer(signalSlowHandle, 0, 0, needSignalBars, signalSlow) < needSignalBars ||
       CopyBuffer(regimeFastHandle, 0, 0, needRegimeBars, regimeFast) < needRegimeBars ||
       CopyBuffer(regimeSlowHandle, 0, 0, needRegimeBars, regimeSlow) < needRegimeBars ||
       (InpUseConfirmRegime && CopyBuffer(confirmFastHandle, 0, 0, needConfirmBars, confirmFast) < needConfirmBars) ||
       (InpUseConfirmRegime && CopyBuffer(confirmSlowHandle, 0, 0, needConfirmBars, confirmSlow) < needConfirmBars) ||
       CopyBuffer(rsiHandle, 0, 0, 4, rsiBuffer) < 4 ||
       CopyBuffer(atrHandle, 0, 0, 4, atrBuffer) < 4)
    {
        dbgSignalDataShort++;
        return 0;
    }

    double pip = GetPipSize();
    if(pip <= 0.0)
        return 0;

    double signalAtrPrice = atrBuffer[1];
    double signalAtrPips = signalAtrPrice / pip;
    if(signalAtrPips > 0.0)
    {
        dbgAtrSamples++;
        dbgAtrPipsSum += signalAtrPips;
        dbgAtrPipsMax = MathMax(dbgAtrPipsMax, signalAtrPips);
    }

    if(signalAtrPips < InpMinSignalATRPips || signalAtrPips > InpMaxSignalATRPips)
    {
        dbgBlockedAtrRange++;
        return 0;
    }

    double regimeFastSlope = regimeFast[1] - regimeFast[1 + REGIME_SLOPE_BARS];
    double regimeSlowSlope = regimeSlow[1] - regimeSlow[1 + REGIME_SLOPE_BARS];
    double regimeGap = regimeFast[1] - regimeSlow[1];
    bool bullRegime = regimeFast[1] > regimeSlow[1] &&
                      regimeFastSlope >= InpMinRegimeSlopePips * pip &&
                      regimeSlowSlope >= (InpMinRegimeSlopePips * 0.35 * pip) &&
                      regimeGap >= InpMinRegimeGapPips * pip;
    bool bearRegime = regimeFast[1] < regimeSlow[1] &&
                      regimeFastSlope <= -(InpMinRegimeSlopePips * pip) &&
                      regimeSlowSlope <= -(InpMinRegimeSlopePips * 0.35 * pip) &&
                      regimeGap <= -(InpMinRegimeGapPips * pip);

    if(InpUseConfirmRegime)
    {
        double confirmFastSlope = confirmFast[1] - confirmFast[1 + REGIME_SLOPE_BARS];
        double confirmGap = confirmFast[1] - confirmSlow[1];
        bool confirmBull = confirmFast[1] > confirmSlow[1] &&
                           confirmFastSlope >= (InpMinRegimeSlopePips * InpConfirmSlopeMultiplier * pip) &&
                           confirmGap >= (InpMinRegimeGapPips * InpConfirmGapMultiplier * pip);
        bool confirmBear = confirmFast[1] < confirmSlow[1] &&
                           confirmFastSlope <= -(InpMinRegimeSlopePips * InpConfirmSlopeMultiplier * pip) &&
                           confirmGap <= -(InpMinRegimeGapPips * InpConfirmGapMultiplier * pip);
        bullRegime = bullRegime && confirmBull;
        bearRegime = bearRegime && confirmBear;
    }

    if(bullRegime)
        dbgBullRegime++;
    else if(bearRegime)
        dbgBearRegime++;
    else
        dbgNeutralRegime++;

    double close1 = iClose(InpSymbol, InpSignalTimeframe, 1);
    double open1  = iOpen(InpSymbol, InpSignalTimeframe, 1);
    double high1  = iHigh(InpSymbol, InpSignalTimeframe, 1);
    double low1   = iLow(InpSymbol, InpSignalTimeframe, 1);
    double close2 = iClose(InpSymbol, InpSignalTimeframe, 2);

    double bodySize = MathAbs(close1 - open1);
    double minBody = signalAtrPrice * InpMinSignalBodyATR;
    double pullbackTolerance = signalAtrPrice * InpPullbackToleranceATR;
    double breakoutBuffer = signalAtrPrice * InpBreakoutBufferATR;

    bool signalBullTrend = signalFast[1] > signalSlow[1];
    bool signalBearTrend = signalFast[1] < signalSlow[1];
    bool bullishBody = close1 > open1;
    bool bearishBody = close1 < open1;

    if(InpAllowBuy && bullRegime)
    {
        if(IsLogicEnabled(LOGIC_PULLBACK, InpBuyLogicMask))
        {
            bool touchedFast = (low1 <= signalFast[1] + pullbackTolerance);
            bool reclaim = (close1 > signalFast[1] && close1 > close2);
            bool rsiRecover = (rsiBuffer[2] <= InpBuyPullbackRsiDip && rsiBuffer[1] >= InpBuyPullbackRsiReclaim);
            if(signalBullTrend && bullishBody && touchedFast && reclaim && rsiRecover)
            {
                logicId = LOGIC_PULLBACK;
                dbgPullbackTriggers++;
                return 1;
            }
        }

        if(IsLogicEnabled(LOGIC_BREAKOUT, InpBuyLogicMask))
        {
            int highestIdx = iHighest(InpSymbol, InpSignalTimeframe, MODE_HIGH, InpBreakoutLookback, 2);
            if(highestIdx >= 0)
            {
                double priorHigh = iHigh(InpSymbol, InpSignalTimeframe, highestIdx);
                double extension = close1 - signalFast[1];
                bool acceptableRsi = (rsiBuffer[1] <= InpBuyBreakoutMaxRsi);
                bool acceptableExtension = (extension <= signalAtrPrice * InpMaxBreakoutExtensionATR);
                bool resetIntoFast = (low1 <= signalFast[1] + pullbackTolerance);
                if(signalBullTrend && bullishBody && bodySize >= minBody && acceptableRsi && acceptableExtension && resetIntoFast && close1 > priorHigh + breakoutBuffer)
                {
                    logicId = LOGIC_BREAKOUT;
                    dbgBreakoutTriggers++;
                    return 1;
                }
            }
        }
    }

    if(InpAllowSell && bearRegime)
    {
        if(IsLogicEnabled(LOGIC_PULLBACK, InpSellLogicMask))
        {
            bool touchedFast = (high1 >= signalFast[1] - pullbackTolerance);
            bool reject = (close1 < signalFast[1] && close1 < close2);
            bool rsiReject = (rsiBuffer[2] >= InpSellPullbackRsiPeak && rsiBuffer[1] <= InpSellPullbackRsiReject);
            if(signalBearTrend && bearishBody && touchedFast && reject && rsiReject)
            {
                logicId = LOGIC_PULLBACK;
                dbgPullbackTriggers++;
                return -1;
            }
        }

        if(IsLogicEnabled(LOGIC_BREAKOUT, InpSellLogicMask))
        {
            int lowestIdx = iLowest(InpSymbol, InpSignalTimeframe, MODE_LOW, InpBreakoutLookback, 2);
            if(lowestIdx >= 0)
            {
                double priorLow = iLow(InpSymbol, InpSignalTimeframe, lowestIdx);
                double extension = signalFast[1] - close1;
                bool acceptableRsi = (rsiBuffer[1] >= InpSellBreakoutMinRsi);
                bool acceptableExtension = (extension <= signalAtrPrice * InpMaxBreakoutExtensionATR);
                bool resetIntoFast = (high1 >= signalFast[1] - pullbackTolerance);
                if(signalBearTrend && bearishBody && bodySize >= minBody && acceptableRsi && acceptableExtension && resetIntoFast && close1 < priorLow - breakoutBuffer)
                {
                    logicId = LOGIC_BREAKOUT;
                    dbgBreakoutTriggers++;
                    return -1;
                }
            }
        }
    }

    if(!bullRegime && !bearRegime)
        dbgBlockedNoRegime++;
    return 0;
}

void OpenPosition(bool isBuy, int logicId)
{
    MqlTick tick;
    if(!SymbolInfoTick(InpSymbol, tick))
        return;

    double atrPrice = GetCurrentATRPrice(false);
    if(atrPrice <= 0.0)
        return;

    double stopDistance = atrPrice * InpStopATRMultiplier;
    double targetDistance = atrPrice * InpTargetATRMultiplier;
    if(stopDistance <= 0.0 || targetDistance <= 0.0)
        return;

    double lots = CalculateLotSizeFromDistance(stopDistance);
    if(lots <= 0.0)
        return;

    double price = isBuy ? tick.ask : tick.bid;
    double sl = isBuy ? (price - stopDistance) : (price + stopDistance);
    double tp = isBuy ? (price + targetDistance) : (price - targetDistance);

    sl = NormalizePrice(sl);
    tp = NormalizePrice(tp);
    if(!ValidateStops(isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, price, sl, tp))
    {
        dbgStopsBlocked++;
        return;
    }

    if(isBuy)
        dbgBuyAttempts++;
    else
        dbgSellAttempts++;

    string comment = BuildOrderComment(logicId, isBuy);
    bool ok = trade.PositionOpen(InpSymbol, isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, lots, price, sl, tp, comment);
    if(!ok)
    {
        dbgOrderFail++;
        return;
    }

    dbgOrderSuccess++;
    lastLogicEntryTime[logicId] = iTime(InpSymbol, InpSignalTimeframe, 0);
}

int CountOpenPositions()
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(!posInfo.SelectByIndex(i))
            continue;
        if(posInfo.Symbol() == InpSymbol && posInfo.Magic() == InpMagicNumber)
            count++;
    }
    return count;
}

int CountOpenPositionsByLogic(int logicId)
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(!posInfo.SelectByIndex(i))
            continue;
        if(posInfo.Symbol() != InpSymbol || posInfo.Magic() != InpMagicNumber)
            continue;
        if(IsLogicMatch(posInfo.Comment(), logicId))
            count++;
    }
    return count;
}

bool CanEnterLogic(int logicId)
{
    if(logicId <= 0)
        return false;
    if(InpMaxOpenPerLogic > 0 && CountOpenPositionsByLogic(logicId) >= InpMaxOpenPerLogic)
        return false;
    if(InpLogicCooldownBars > 0 && lastLogicEntryTime[logicId] > 0)
    {
        int shift = iBarShift(InpSymbol, InpSignalTimeframe, lastLogicEntryTime[logicId], true);
        if(shift >= 0 && shift < InpLogicCooldownBars)
            return false;
    }
    return true;
}

bool IsLogicEnabled(int logicId, int logicMask)
{
    if(logicId < 1 || logicId > 2)
        return false;
    int mask = 1 << (logicId - 1);
    return ((ClampLogicMask(logicMask) & mask) != 0);
}

int ClampLogicMask(int logicMask)
{
    if(logicMask < 0)
        return 0;
    if(logicMask > 3)
        return 3;
    return logicMask;
}

bool IsTradingTime()
{
    if(!InpUseTimeFilter)
        return true;

    MqlDateTime t;
    TimeToStruct(TimeCurrent(), t);
    return IsHourInRange(t.hour, InpTradeStartHour, InpTradeEndHour);
}

bool IsHourInRange(int hour, int startHour, int endHour)
{
    int s = MathMax(0, MathMin(23, startHour));
    int e = MathMax(0, MathMin(24, endHour));
    if(s == e)
        return true;
    if(s < e)
        return (hour >= s && hour < e);
    return (hour >= s || hour < e);
}

double CalculateLotSizeFromDistance(double stopDistancePrice)
{
    if(stopDistancePrice <= 0.0)
        return 0.0;

    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double riskAmount = equity * InpRiskPercent / 100.0;

    double tickValue = SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_SIZE);
    if(tickValue <= 0.0 || tickSize <= 0.0)
        return 0.0;

    double pricePerLot = (tickValue / tickSize) * stopDistancePrice;
    if(pricePerLot <= 0.0)
        return 0.0;

    double lots = riskAmount / pricePerLot;
    double minLot = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_MAX);
    double stepLot = SymbolInfoDouble(InpSymbol, SYMBOL_VOLUME_STEP);
    if(minLot <= 0.0 || maxLot <= 0.0 || stepLot <= 0.0)
        return 0.0;

    lots = MathMax(minLot, MathMin(maxLot, lots));
    lots = MathFloor(lots / stepLot) * stepLot;
    if(lots <= 0.0)
        dbgLotsZero++;
    return lots;
}

double GetCurrentATRPrice(bool useCurrentBar)
{
    if(atrHandle == INVALID_HANDLE)
        return 0.0;

    double atr[];
    ArrayResize(atr, 2);
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(atrHandle, 0, 0, 2, atr) < 2)
        return 0.0;
    return useCurrentBar ? atr[0] : atr[1];
}

double GetPipSize()
{
    double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    if(point <= 0.0)
        return 0.0;

    if(IsForexLikeSymbol())
    {
        int digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
        if(digits == 3 || digits == 5)
            return point * 10.0;
    }
    return point;
}

bool IsForexLikeSymbol()
{
    long calcMode = SymbolInfoInteger(InpSymbol, SYMBOL_TRADE_CALC_MODE);
    return (calcMode == SYMBOL_CALC_MODE_FOREX || calcMode == SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE);
}

double GetCurrentSpreadPips()
{
    MqlTick tick;
    if(!SymbolInfoTick(InpSymbol, tick))
        return -1.0;

    double pip = GetPipSize();
    if(pip <= 0.0)
        return -1.0;

    double spreadPips = (tick.ask - tick.bid) / pip;
    if(spreadPips >= 0.0)
    {
        dbgSpreadSamples++;
        dbgSpreadSum += spreadPips;
        dbgSpreadMax = MathMax(dbgSpreadMax, spreadPips);
    }
    return spreadPips;
}

bool IsSpreadAllowed()
{
    if(InpMaxSpreadPips <= 0.0)
        return true;
    double spreadPips = GetCurrentSpreadPips();
    if(spreadPips < 0.0)
        return false;
    return (spreadPips <= InpMaxSpreadPips);
}

double NormalizePrice(double price)
{
    int digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
    return NormalizeDouble(price, digits);
}

double GetMinStopDistance()
{
    int stops = (int)SymbolInfoInteger(InpSymbol, SYMBOL_TRADE_STOPS_LEVEL);
    int level = stops;
    if(InpUseFreezeLevelCheck)
    {
        int freeze = (int)SymbolInfoInteger(InpSymbol, SYMBOL_TRADE_FREEZE_LEVEL);
        level = MathMax(level, freeze);
    }
    if(level <= 0)
        return 0.0;
    double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    return level * point;
}

bool ValidateStops(ENUM_ORDER_TYPE orderType, double price, double sl, double tp)
{
    if(sl <= 0.0 || tp <= 0.0)
        return false;

    double minDist = GetMinStopDistance();
    if(minDist <= 0.0)
        return true;

    if(orderType == ORDER_TYPE_BUY)
        return ((price - sl) >= minDist && (tp - price) >= minDist);
    if(orderType == ORDER_TYPE_SELL)
        return ((sl - price) >= minDist && (price - tp) >= minDist);
    return false;
}

string BuildOrderComment(int logicId, bool isBuy)
{
    string side = isBuy ? "BUY" : "SELL";
    return "Regime EA L" + IntegerToString(logicId) + " " + side;
}

bool IsLogicMatch(const string comment, int logicId)
{
    string tag = "L" + IntegerToString(logicId);
    return (StringFind(comment, tag) >= 0);
}

void UpdateLossStreak()
{
    MqlDateTime t;
    TimeToStruct(TimeCurrent(), t);
    if(t.day_of_year != lastDayOfYear)
    {
        lastDayOfYear = t.day_of_year;
        consecutiveLosses = 0;
        lastDealTime = 0;
        lastDealTicket = 0;
        lastLossTime = 0;
        realizedPnlToday = 0.0;
        dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    }

    datetime from = (lastDealTime > 0)
        ? lastDealTime
        : (datetime)StringToTime(TimeToString(TimeCurrent(), TIME_DATE));

    if(!HistorySelect(from, TimeCurrent()))
        return;

    int deals = HistoryDealsTotal();
    datetime newestTime = lastDealTime;
    ulong newestTicket = lastDealTicket;
    for(int i = 0; i < deals; i++)
    {
        ulong deal = HistoryDealGetTicket(i);
        if(deal == 0)
            continue;

        datetime dealTime = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
        if(dealTime < lastDealTime)
            continue;
        if(dealTime == lastDealTime && deal <= lastDealTicket)
            continue;

        if(HistoryDealGetString(deal, DEAL_SYMBOL) != InpSymbol)
            continue;
        if(HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagicNumber)
            continue;
        if(HistoryDealGetInteger(deal, DEAL_ENTRY) != DEAL_ENTRY_OUT)
            continue;

        double profit = HistoryDealGetDouble(deal, DEAL_PROFIT)
                      + HistoryDealGetDouble(deal, DEAL_SWAP)
                      + HistoryDealGetDouble(deal, DEAL_COMMISSION);
        realizedPnlToday += profit;
        if(profit < 0.0)
        {
            consecutiveLosses++;
            lastLossTime = dealTime;
        }
        else
            consecutiveLosses = 0;

        if(dealTime > newestTime || (dealTime == newestTime && deal > newestTicket))
        {
            newestTime = dealTime;
            newestTicket = deal;
        }
    }

    if(newestTime > lastDealTime || (newestTime == lastDealTime && newestTicket > lastDealTicket))
    {
        lastDealTime = newestTime;
        lastDealTicket = newestTicket;
    }
}

bool IsLossStopBlocked()
{
    if(!InpUseLossStop)
        return false;
    if(InpMaxConsecutiveLosses <= 0)
        return false;
    return (consecutiveLosses >= InpMaxConsecutiveLosses);
}

bool IsDailyLossCapBlocked()
{
    if(!InpUseDailyLossCap)
        return false;
    if(InpDailyLossCapPercent <= 0.0)
        return false;
    if(dailyStartBalance <= 0.0)
        return false;
    double lossCapAmount = dailyStartBalance * (InpDailyLossCapPercent / 100.0);
    return (-realizedPnlToday >= lossCapAmount);
}

bool IsLossCooldownBlocked()
{
    if(InpLossCooldownBars <= 0)
        return false;
    if(lastLossTime <= 0)
        return false;
    int shift = iBarShift(InpSymbol, InpSignalTimeframe, lastLossTime, true);
    return (shift >= 0 && shift < InpLossCooldownBars);
}

double OnTester()
{
    double trades = TesterStatistics(STAT_TRADES);
    double profit = TesterStatistics(STAT_PROFIT);
    double dd = TesterStatistics(STAT_EQUITY_DD);
    double pf = TesterStatistics(STAT_PROFIT_FACTOR);
    datetime testEndTime = TimeCurrent();
    double durationDays = 1.0;
    if(testStartTime > 0 && testEndTime > testStartTime)
        durationDays = MathMax(1.0, (double)(testEndTime - testStartTime) / 86400.0);
    double tradesPerDay = trades / durationDays;

    if(profit <= 0.0 || dd <= 0.0 || pf <= 0.0)
        return 0.0;
    if(InpUseHardTradeFloor && InpMinTradesPerDay > 0.0 && tradesPerDay < InpMinTradesPerDay)
        return 0.0;

    double ddPct = 0.0;
    if(initialBalance > 0.0)
        ddPct = (dd / initialBalance) * 100.0;
    if(pf < 1.10 || ddPct > 15.0)
        return 0.0;

    double tradeScore = 1.0;
    if(InpTargetTradesPerDay > 0.0)
        tradeScore = MathMin(1.0, tradesPerDay / InpTargetTradesPerDay);

    return (profit / (dd + 1.0)) * pf * pf * tradeScore;
}

void PrintDebugSummary(const int reason)
{
    double avgAtr = (dbgAtrSamples > 0) ? (dbgAtrPipsSum / dbgAtrSamples) : 0.0;
    double avgSpread = (dbgSpreadSamples > 0) ? (dbgSpreadSum / dbgSpreadSamples) : 0.0;

    PrintFormat(
        "DebugSummary reason=%d bars=%I64d max_open=%I64d time=%I64d spread_block=%I64d loss_stop=%I64d daily_loss=%I64d loss_cooldown=%I64d signal_zero=%I64d no_regime=%I64d atr_range=%I64d can_enter=%I64d buy_signals=%I64d sell_signals=%I64d order_ok=%I64d order_fail=%I64d lots_zero=%I64d stops_block=%I64d data_short=%I64d",
        reason,
        dbgBarsSeen,
        dbgBlockedMaxOpen,
        dbgBlockedTradingTime,
        dbgBlockedSpread,
        dbgBlockedLossStop,
        dbgBlockedDailyLoss,
        dbgBlockedLossCooldown,
        dbgBlockedSignalZero,
        dbgBlockedNoRegime,
        dbgBlockedAtrRange,
        dbgBlockedCanEnter,
        dbgSignalBuy,
        dbgSignalSell,
        dbgOrderSuccess,
        dbgOrderFail,
        dbgLotsZero,
        dbgStopsBlocked,
        dbgSignalDataShort
    );

    PrintFormat(
        "DebugRegime bull=%I64d bear=%I64d neutral=%I64d pullback=%I64d breakout=%I64d buy_attempts=%I64d sell_attempts=%I64d managed_be=%I64d managed_trail=%I64d avg_atr_pips=%.2f max_atr_pips=%.2f avg_spread_pips=%.2f max_spread_pips=%.2f",
        dbgBullRegime,
        dbgBearRegime,
        dbgNeutralRegime,
        dbgPullbackTriggers,
        dbgBreakoutTriggers,
        dbgBuyAttempts,
        dbgSellAttempts,
        dbgManagedBreakEven,
        dbgManagedTrail,
        avgAtr,
        dbgAtrPipsMax,
        avgSpread,
        dbgSpreadMax
    );

    PrintFormat(
        "DebugRisk day_start_balance=%.2f realized_today=%.2f consecutive_losses=%d",
        dailyStartBalance,
        realizedPnlToday,
        consecutiveLosses
    );
}

void PrintSymbolUnitInfo()
{
    int digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
    double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    double tickSize = SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_SIZE);
    double pip = GetPipSize();
    string mode = IsForexLikeSymbol() ? "FOREX" : "NON_FOREX";
    PrintFormat(
        "SymbolUnit %s mode=%s digits=%d point=%g tick=%g pip=%g",
        InpSymbol, mode, digits, point, tickSize, pip
    );
}
//+------------------------------------------------------------------+
