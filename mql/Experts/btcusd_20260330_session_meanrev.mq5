//+------------------------------------------------------------------+
//| BTCUSD Session Mean-Reversion Prototype                          |
//+------------------------------------------------------------------+
#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "1.00"
#property strict
#property description "BTCUSD M5 session mean-reversion prototype from statistical edge research"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

CTrade trade;
CPositionInfo posInfo;

input string          InpSymbol                  = "BTCUSD";
input ENUM_TIMEFRAMES InpSignalTimeframe         = PERIOD_M5;
input int             InpEMAPeriod               = 20;
input int             InpRSIPeriod               = 14;
input int             InpATRPeriod               = 14;

input bool            InpAllowBuy                = false;
input int             InpLongStartHour           = 20;
input int             InpLongEndHour             = 24;
input double          InpLongDistanceATR         = 0.60;
input double          InpLongMaxDistanceATR      = 0.0;
input double          InpLongRsiMax              = 40.0;

input bool            InpAllowSell               = true;
input int             InpShortStartHour          = 0;
input int             InpShortEndHour            = 8;
input double          InpShortDistanceATR        = 1.00;
input double          InpShortMaxDistanceATR     = 0.0;
input double          InpShortRsiMin             = 66.0;

input int             InpHoldBars                = 12;
input bool            InpExitOnMeanReversion     = true;
input double          InpExitBufferATR           = 0.30;
input double          InpEmergencyStopATR        = 4.00;
input double          InpRiskPercent             = 0.05;

input int             InpMaxOpenTrades           = 8;
input int             InpMaxOpenPerSide          = 4;
input bool            InpUseDailyLossCap         = true;
input double          InpDailyLossCapPercent     = 3.0;
input double          InpMaxSpreadPips           = 2500.0;
input double          InpMaxDeviationPips        = 250.0;
input string          InpAllowedWeekdays         = "0,1,2,3,4,6";
input string          InpBlockedEntryHours       = "3";
input long            InpMagicNumber             = 20260330;

int emaHandle = INVALID_HANDLE;
int rsiHandle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;

bool allowedWeekdays[7];
bool blockedEntryHours[24];

datetime lastSignalBarTime = 0;
int lastDayOfYear = -1;
double dailyStartBalance = 0.0;

int OnInit()
{
    trade.SetExpertMagicNumber((ulong)InpMagicNumber);
    dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);

    if(InpMagicNumber <= 0 || InpRiskPercent <= 0.0 || InpEmergencyStopATR <= 0.0 || InpHoldBars <= 0)
    {
        Print("Invalid prototype parameters.");
        return INIT_PARAMETERS_INCORRECT;
    }
    if(!InitializeEntryFilters())
    {
        Print("Invalid weekday or blocked-hour filters.");
        return INIT_PARAMETERS_INCORRECT;
    }

    if(InpMaxDeviationPips > 0.0)
    {
        double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
        double pip = GetPipSize();
        if(point > 0.0 && pip > 0.0)
        {
            int deviationPoints = (int)MathMax(0.0, MathRound(InpMaxDeviationPips * pip / point));
            trade.SetDeviationInPoints(deviationPoints);
        }
    }

    emaHandle = iMA(InpSymbol, InpSignalTimeframe, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    rsiHandle = iRSI(InpSymbol, InpSignalTimeframe, InpRSIPeriod, PRICE_CLOSE);
    atrHandle = iATR(InpSymbol, InpSignalTimeframe, InpATRPeriod);

    if(emaHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
    {
        Print("Failed to create indicator handles.");
        return INIT_FAILED;
    }

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    ReleaseHandle(emaHandle);
    ReleaseHandle(rsiHandle);
    ReleaseHandle(atrHandle);
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
    if(!IsNewSignalBar())
        return;

    UpdateDailyAnchor();
    ManageOpenPositions();

    if(IsDailyLossCapBlocked())
        return;
    if(!IsSpreadAllowed())
        return;
    if(CountOpenPositions() >= InpMaxOpenTrades)
        return;

    int signal = GetSignal();
    if(signal > 0 && CanOpenSide(true))
        OpenPosition(true);
    else if(signal < 0 && CanOpenSide(false))
        OpenPosition(false);
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

void UpdateDailyAnchor()
{
    MqlDateTime t;
    TimeToStruct(TimeCurrent(), t);
    if(t.day_of_year != lastDayOfYear)
    {
        lastDayOfYear = t.day_of_year;
        dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    }
}

bool IsDailyLossCapBlocked()
{
    if(!InpUseDailyLossCap || InpDailyLossCapPercent <= 0.0 || dailyStartBalance <= 0.0)
        return false;
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    return (balance <= dailyStartBalance * (1.0 - InpDailyLossCapPercent / 100.0));
}

int GetSignal()
{
    double ema[], rsi[], atr[];
    ArraySetAsSeries(ema, true);
    ArraySetAsSeries(rsi, true);
    ArraySetAsSeries(atr, true);

    if(CopyBuffer(emaHandle, 0, 0, 3, ema) < 3 ||
       CopyBuffer(rsiHandle, 0, 0, 3, rsi) < 3 ||
       CopyBuffer(atrHandle, 0, 0, 3, atr) < 3)
        return 0;

    if(atr[1] <= 0.0)
        return 0;

    datetime signalTime = iTime(InpSymbol, InpSignalTimeframe, 1);
    MqlDateTime barTime;
    TimeToStruct(signalTime, barTime);
    if(!IsAllowedWeekday(barTime.day_of_week) || IsBlockedEntryHour(barTime.hour))
        return 0;

    double close1 = iClose(InpSymbol, InpSignalTimeframe, 1);
    double distAtr = (close1 - ema[1]) / atr[1];

    if(InpAllowBuy &&
       IsHourInRange(barTime.hour, InpLongStartHour, InpLongEndHour) &&
       distAtr <= -InpLongDistanceATR &&
       (InpLongMaxDistanceATR <= 0.0 || distAtr >= -InpLongMaxDistanceATR) &&
       rsi[1] <= InpLongRsiMax)
        return 1;

    if(InpAllowSell &&
       IsHourInRange(barTime.hour, InpShortStartHour, InpShortEndHour) &&
       distAtr >= InpShortDistanceATR &&
       (InpShortMaxDistanceATR <= 0.0 || distAtr <= InpShortMaxDistanceATR) &&
       rsi[1] >= InpShortRsiMin)
        return -1;

    return 0;
}

void ManageOpenPositions()
{
    double ema[], atr[];
    ArraySetAsSeries(ema, true);
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(emaHandle, 0, 0, 3, ema) < 3 || CopyBuffer(atrHandle, 0, 0, 3, atr) < 3)
        return;

    double close1 = iClose(InpSymbol, InpSignalTimeframe, 1);
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!posInfo.SelectByIndex(i))
            continue;
        if(posInfo.Symbol() != InpSymbol || posInfo.Magic() != InpMagicNumber)
            continue;

        bool isBuy = (posInfo.PositionType() == POSITION_TYPE_BUY);
        int heldBars = HeldBars(posInfo.Time());
        bool timeExit = (heldBars >= InpHoldBars);
        bool meanExit = false;
        if(InpExitOnMeanReversion && atr[1] > 0.0)
        {
            double exitBuffer = atr[1] * InpExitBufferATR;
            if(isBuy)
                meanExit = (close1 >= ema[1] - exitBuffer);
            else
                meanExit = (close1 <= ema[1] + exitBuffer);
        }

        if(timeExit || meanExit)
            trade.PositionClose(posInfo.Ticket());
    }
}

int HeldBars(datetime openedAt)
{
    if(openedAt <= 0)
        return 0;
    int shift = iBarShift(InpSymbol, InpSignalTimeframe, openedAt, false);
    if(shift < 0)
        return 0;
    return shift;
}

bool CanOpenSide(bool isBuy)
{
    if(CountOpenPositions() >= InpMaxOpenTrades)
        return false;
    if(CountOpenPositionsBySide(isBuy) >= InpMaxOpenPerSide)
        return false;
    return true;
}

void OpenPosition(bool isBuy)
{
    MqlTick tick;
    if(!SymbolInfoTick(InpSymbol, tick))
        return;

    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(atrHandle, 0, 0, 3, atr) < 3 || atr[1] <= 0.0)
        return;

    double stopDistance = atr[1] * InpEmergencyStopATR;
    double lots = CalculateLotSizeFromDistance(stopDistance);
    if(lots <= 0.0)
        return;

    double price = isBuy ? tick.ask : tick.bid;
    double sl = isBuy ? (price - stopDistance) : (price + stopDistance);
    price = NormalizePrice(price);
    sl = NormalizePrice(sl);

    if(!ValidateStopLoss(isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, price, sl))
        return;

    string comment = isBuy ? "SMR-L" : "SMR-S";
    trade.PositionOpen(InpSymbol, isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, lots, price, sl, 0.0, comment);
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

int CountOpenPositionsBySide(bool isBuy)
{
    int count = 0;
    long desiredType = isBuy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(!posInfo.SelectByIndex(i))
            continue;
        if(posInfo.Symbol() != InpSymbol || posInfo.Magic() != InpMagicNumber)
            continue;
        if(posInfo.PositionType() == desiredType)
            count++;
    }
    return count;
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
    return lots;
}

double NormalizePrice(double price)
{
    int digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
    return NormalizeDouble(price, digits);
}

double GetPipSize()
{
    double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    if(point <= 0.0)
        return 0.0;
    long calcMode = SymbolInfoInteger(InpSymbol, SYMBOL_TRADE_CALC_MODE);
    if(calcMode == SYMBOL_CALC_MODE_FOREX || calcMode == SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE)
    {
        int digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
        if(digits == 3 || digits == 5)
            return point * 10.0;
    }
    return point;
}

double GetCurrentSpreadPips()
{
    MqlTick tick;
    if(!SymbolInfoTick(InpSymbol, tick))
        return -1.0;
    double pip = GetPipSize();
    if(pip <= 0.0)
        return -1.0;
    return (tick.ask - tick.bid) / pip;
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

double GetMinStopDistance()
{
    int stops = (int)SymbolInfoInteger(InpSymbol, SYMBOL_TRADE_STOPS_LEVEL);
    if(stops <= 0)
        return 0.0;
    double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    return stops * point;
}

bool ValidateStopLoss(ENUM_ORDER_TYPE orderType, double price, double sl)
{
    if(sl <= 0.0)
        return false;
    double minDist = GetMinStopDistance();
    if(minDist <= 0.0)
        return true;
    if(orderType == ORDER_TYPE_BUY)
        return ((price - sl) >= minDist);
    if(orderType == ORDER_TYPE_SELL)
        return ((sl - price) >= minDist);
    return false;
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

bool InitializeEntryFilters()
{
    for(int i = 0; i < 7; i++)
        allowedWeekdays[i] = false;
    for(int j = 0; j < 24; j++)
        blockedEntryHours[j] = false;

    if(!ParseAllowedWeekdays(InpAllowedWeekdays))
        return false;
    if(!ParseBlockedHours(InpBlockedEntryHours))
        return false;
    return true;
}

bool ParseAllowedWeekdays(string csvText)
{
    StringTrimLeft(csvText);
    StringTrimRight(csvText);
    if(StringLen(csvText) == 0)
    {
        for(int i = 0; i < 7; i++)
            allowedWeekdays[i] = true;
        return true;
    }

    string parts[];
    int count = StringSplit(csvText, ',', parts);
    if(count <= 0)
        return false;

    for(int i = 0; i < count; i++)
    {
        string token = parts[i];
        StringTrimLeft(token);
        StringTrimRight(token);
        if(StringLen(token) == 0)
            continue;
        int day = (int)StringToInteger(token);
        if(day < 0 || day > 6)
            return false;
        allowedWeekdays[day] = true;
    }
    return true;
}

bool ParseBlockedHours(string csvText)
{
    StringTrimLeft(csvText);
    StringTrimRight(csvText);
    if(StringLen(csvText) == 0)
        return true;

    string parts[];
    int count = StringSplit(csvText, ',', parts);
    if(count <= 0)
        return false;

    for(int i = 0; i < count; i++)
    {
        string token = parts[i];
        StringTrimLeft(token);
        StringTrimRight(token);
        if(StringLen(token) == 0)
            continue;
        int hour = (int)StringToInteger(token);
        if(hour < 0 || hour > 23)
            return false;
        blockedEntryHours[hour] = true;
    }
    return true;
}

bool IsAllowedWeekday(int dayOfWeek)
{
    if(dayOfWeek < 0 || dayOfWeek > 6)
        return false;
    return allowedWeekdays[dayOfWeek];
}

bool IsBlockedEntryHour(int hour)
{
    if(hour < 0 || hour > 23)
        return false;
    return blockedEntryHours[hour];
}
