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
input int             InpSlowEMAPeriod           = 50;
input int             InpTrendStackEMAPeriod     = 100;
input int             InpRSIPeriod               = 14;
input int             InpATRPeriod               = 14;

input bool            InpAllowBuy                = true;
input int             InpLongStartHour           = 20;
input int             InpLongEndHour             = 24;
input double          InpLongDistanceATR         = 1.50;
input double          InpLongMaxDistanceATR      = 0.0;
input double          InpLongMinATRPercent       = 0.0;
input double          InpLongMaxATRPercent       = 0.0;
input double          InpLongRsiMax              = 40.0;
input int             InpLongTrendFilterMode     = 1;
input bool            InpEnableSecondLongBucket  = false;
input int             InpSecondLongStartHour     = 13;
input int             InpSecondLongEndHour       = 22;
input double          InpSecondLongDistanceATR   = 1.50;
input double          InpSecondLongMaxDistanceATR = 0.0;
input double          InpSecondLongMinATRPercent = 0.0;
input double          InpSecondLongMaxATRPercent = 0.0;
input double          InpSecondLongRsiMax        = 30.0;
input int             InpSecondLongTrendFilterMode = 1;

input bool            InpAllowSell               = false;
input int             InpShortStartHour          = 0;
input int             InpShortEndHour            = 8;
input double          InpShortDistanceATR        = 0.87;
input double          InpShortMaxDistanceATR     = 3.0;
input double          InpShortMinATRPercent      = 0.0003;
input double          InpShortMaxATRPercent      = 0.0;
input double          InpShortRsiMin             = 64.0;
input double          InpShortRsiMax             = 82.0;
input int             InpShortTrendFilterMode    = 0;
input bool            InpShortRequireStackedBearTrend = false;
input bool            InpEnableSecondShortBucket = false;
input int             InpSecondShortStartHour    = 13;
input int             InpSecondShortEndHour      = 22;
input double          InpSecondShortDistanceATR  = 0.80;
input double          InpSecondShortMaxDistanceATR = 0.0;
input double          InpSecondShortMinATRPercent = 0.0;
input double          InpSecondShortMaxATRPercent = 0.0;
input double          InpSecondShortRsiMin       = 55.0;
input double          InpSecondShortRsiMax       = 100.0;
input bool            InpSecondShortRequireBearTrend = true;
input bool            InpUseAdaptiveShortAtrRegime = false;
input double          InpShortAtrRegimePivot     = 0.0012;
input double          InpShortDistanceATRCalm    = 1.0;
input double          InpShortMaxDistanceATRCalm = 3.0;
input double          InpShortRsiMinCalm         = 66.0;
input double          InpShortRsiMaxCalm         = 85.0;
input double          InpShortDistanceATRActive  = 0.9;
input double          InpShortMaxDistanceATRActive = 0.0;
input double          InpShortRsiMinActive       = 64.0;
input double          InpShortRsiMaxActive       = 95.0;

input int             InpHoldBars                = 8;
input int             InpLongHoldBars            = 8;
input int             InpShortHoldBars           = 0;
input bool            InpExitOnMeanReversion     = true;
input double          InpExitBufferATR           = 0.30;
input double          InpLongExitBufferATR       = 0.30;
input double          InpShortExitBufferATR      = 0.0;
input double          InpEmergencyStopATR        = 4.00;
input double          InpRiskPercent             = 0.05;

input int             InpMaxOpenTrades           = 8;
input int             InpMaxOpenPerSide          = 4;
input bool            InpUseDailyLossCap         = true;
input double          InpDailyLossCapPercent     = 3.0;
input int             InpMaxTradesPerDay         = 20;
input int             InpMaxConsecutiveLosses    = 5;
input int             InpConsecutiveLossCooldownBars = 24;
input bool            InpUseEquityDrawdownCap    = false;
input double          InpEquityDrawdownCapPercent = 12.0;
input bool            InpEnableTelemetry         = true;
input string          InpTelemetryFileName       = "mt5_company_btcusd_20260330_session_meanrev_bull15_40_long_h8_no_sun.csv";
input double          InpMaxSpreadPips           = 2500.0;
input double          InpMaxDeviationPips        = 250.0;
input string          InpAllowedWeekdays         = "1,2,3,4,6";
input string          InpBlockedEntryHours       = "3";
input long            InpMagicNumber             = 20260372;

int emaHandle = INVALID_HANDLE;
int slowEmaHandle = INVALID_HANDLE;
int trendStackHandle = INVALID_HANDLE;
int rsiHandle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;

bool allowedWeekdays[7];
bool blockedEntryHours[24];
string runtimeSymbol = "";
string runtimeAllowedWeekdays = "";
string runtimeBlockedEntryHours = "";
string runtimeTelemetryFileName = "";

datetime lastSignalBarTime = 0;
int lastDayOfYear = -1;
double dailyStartBalance = 0.0;
datetime currentDayStart = 0;
int dailyClosedTrades = 0;
int consecutiveLosses = 0;
bool lossLockActive = false;
datetime lossLockUntil = 0;
double equityPeak = 0.0;
int telemetryHandle = INVALID_HANDLE;
int dailyEntriesBuy = 0;
int dailyEntriesSell = 0;
int dailyBlockedSpread = 0;
int dailyBlockedDailyLoss = 0;
int dailyBlockedTradeCap = 0;
int dailyBlockedLossLock = 0;
int dailyBlockedEquityCap = 0;
int dailyLossLockActivations = 0;

int OnInit()
{
    runtimeSymbol = NormalizePresetString(InpSymbol);
    runtimeAllowedWeekdays = NormalizePresetString(InpAllowedWeekdays);
    runtimeBlockedEntryHours = NormalizePresetString(InpBlockedEntryHours);
    runtimeTelemetryFileName = NormalizePresetString(InpTelemetryFileName);
    trade.SetExpertMagicNumber((ulong)InpMagicNumber);
    dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    equityPeak = AccountInfoDouble(ACCOUNT_EQUITY);

    if(InpMagicNumber <= 0 || InpRiskPercent <= 0.0 || InpEmergencyStopATR <= 0.0 || InpHoldBars <= 0 ||
       InpMaxTradesPerDay < 0 || InpMaxConsecutiveLosses < 0 || InpConsecutiveLossCooldownBars < 0 ||
       InpEquityDrawdownCapPercent < 0.0 || InpTrendStackEMAPeriod <= 0 ||
       InpLongTrendFilterMode < 0 || InpLongTrendFilterMode > 2 ||
       InpSecondLongTrendFilterMode < 0 || InpSecondLongTrendFilterMode > 2 ||
       InpShortTrendFilterMode < 0 || InpShortTrendFilterMode > 2 ||
       InpLongHoldBars < 0 || InpShortHoldBars < 0 ||
       InpLongExitBufferATR < 0.0 || InpShortExitBufferATR < 0.0)
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
        double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
        double pip = GetPipSize();
        if(point > 0.0 && pip > 0.0)
        {
            int deviationPoints = (int)MathMax(0.0, MathRound(InpMaxDeviationPips * pip / point));
            trade.SetDeviationInPoints(deviationPoints);
        }
    }

    emaHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    slowEmaHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    trendStackHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpTrendStackEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    rsiHandle = iRSI(runtimeSymbol, InpSignalTimeframe, InpRSIPeriod, PRICE_CLOSE);
    atrHandle = iATR(runtimeSymbol, InpSignalTimeframe, InpATRPeriod);

    if(emaHandle == INVALID_HANDLE || slowEmaHandle == INVALID_HANDLE || trendStackHandle == INVALID_HANDLE ||
       rsiHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE)
    {
        Print("Failed to create indicator handles.");
        return INIT_FAILED;
    }

    if(InpEnableTelemetry && !OpenTelemetryFile())
        Print("Telemetry file could not be opened. Continuing without telemetry.");

    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    FlushDailySummary(TimeCurrent(), "deinit");
    CloseTelemetryFile();
    ReleaseHandle(emaHandle);
    ReleaseHandle(slowEmaHandle);
    ReleaseHandle(trendStackHandle);
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

string NormalizePresetString(string rawValue)
{
    int marker = StringFind(rawValue, "||");
    if(marker < 0)
        return rawValue;
    return StringSubstr(rawValue, 0, marker);
}

void OnTick()
{
    if(!IsNewSignalBar())
        return;

    UpdateDailyAnchor();
    UpdateEquityPeak();
    ManageOpenPositions();

    if(IsDailyLossCapBlocked())
    {
        dailyBlockedDailyLoss++;
        return;
    }
    if(IsEquityDrawdownBlocked())
    {
        dailyBlockedEquityCap++;
        return;
    }
    if(IsTradeCountBlocked())
    {
        dailyBlockedTradeCap++;
        return;
    }
    if(IsLossLockBlocked())
    {
        dailyBlockedLossLock++;
        return;
    }
    if(!IsSpreadAllowed())
    {
        dailyBlockedSpread++;
        return;
    }
    if(CountOpenPositions() >= InpMaxOpenTrades)
        return;

    int signal = GetSignal();
    if(signal > 0 && CanOpenSide(true))
        OpenPosition(true);
    else if(signal < 0 && CanOpenSide(false))
        OpenPosition(false);
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
    if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0)
        return;
    if(!HistoryDealSelect(trans.deal))
        return;
    if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != runtimeSymbol)
        return;

    long dealMagic = (long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
    if(dealMagic != InpMagicNumber)
        return;

    long dealEntry = (long)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
    long dealType = (long)HistoryDealGetInteger(trans.deal, DEAL_TYPE);
    string entrySide = (dealType == DEAL_TYPE_BUY) ? "buy" : "sell";
    string exitSide = (dealType == DEAL_TYPE_BUY) ? "sell" : "buy";
    double dealPrice = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
    double dealVolume = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);

    if(dealEntry == (long)DEAL_ENTRY_IN)
    {
        RegisterEntryDeal((datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME), entrySide, dealPrice, dealVolume);
        return;
    }

    if(dealEntry != (long)DEAL_ENTRY_OUT &&
       dealEntry != (long)DEAL_ENTRY_OUT_BY &&
       dealEntry != (long)DEAL_ENTRY_INOUT)
        return;

    double netProfit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT) +
                       HistoryDealGetDouble(trans.deal, DEAL_SWAP) +
                       HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
    RegisterClosedDeal((datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME), netProfit, exitSide, dealPrice, dealVolume);
}

bool IsNewSignalBar()
{
    datetime currentBarTime = iTime(runtimeSymbol, InpSignalTimeframe, 0);
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
    datetime nowTime = TimeCurrent();
    TimeToStruct(nowTime, t);
    if(t.day_of_year != lastDayOfYear)
    {
        FlushDailySummary(nowTime, "rollover");
        lastDayOfYear = t.day_of_year;
        dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        currentDayStart = StringToTime(TimeToString(nowTime, TIME_DATE));
        ResetDailyCounters();
        LogTelemetryEvent(nowTime, "day_reset", "", "", 0.0, 0.0, 0.0, "");
    }
}

bool IsDailyLossCapBlocked()
{
    if(!InpUseDailyLossCap || InpDailyLossCapPercent <= 0.0 || dailyStartBalance <= 0.0)
        return false;
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    return (balance <= dailyStartBalance * (1.0 - InpDailyLossCapPercent / 100.0));
}

void UpdateEquityPeak()
{
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    if(equityPeak <= 0.0 || equity > equityPeak)
        equityPeak = equity;
}

bool IsEquityDrawdownBlocked()
{
    if(!InpUseEquityDrawdownCap || InpEquityDrawdownCapPercent <= 0.0 || equityPeak <= 0.0)
        return false;
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    return (equity <= equityPeak * (1.0 - InpEquityDrawdownCapPercent / 100.0));
}

bool IsTradeCountBlocked()
{
    if(InpMaxTradesPerDay <= 0)
        return false;
    return (dailyClosedTrades >= InpMaxTradesPerDay);
}

bool IsLossLockBlocked()
{
    if(!lossLockActive || InpMaxConsecutiveLosses <= 0)
        return false;
    if(InpConsecutiveLossCooldownBars <= 0)
        return true;
    if(TimeCurrent() >= lossLockUntil)
    {
        lossLockActive = false;
        consecutiveLosses = 0;
        return false;
    }
    return true;
}

void ActivateLossLock()
{
    lossLockActive = true;
    lossLockUntil = 0;
    dailyLossLockActivations++;

    if(InpConsecutiveLossCooldownBars > 0)
    {
        datetime anchorBarTime = iTime(runtimeSymbol, InpSignalTimeframe, 0);
        if(anchorBarTime <= 0)
            anchorBarTime = TimeCurrent();
        int barSeconds = PeriodSeconds(InpSignalTimeframe);
        if(barSeconds <= 0)
            barSeconds = 60;
        lossLockUntil = anchorBarTime + (datetime)(barSeconds * InpConsecutiveLossCooldownBars);
        LogTelemetryEvent(TimeCurrent(), "loss_lock", "cooldown", "", 0.0, 0.0, 0.0, TimeToString(lossLockUntil, TIME_DATE | TIME_MINUTES));
        PrintFormat("Loss lock activated: streak=%d cooldown_until=%s", consecutiveLosses, TimeToString(lossLockUntil, TIME_DATE | TIME_MINUTES));
        return;
    }

    LogTelemetryEvent(TimeCurrent(), "loss_lock", "day", "", 0.0, 0.0, 0.0, "");
    PrintFormat("Loss lock activated: streak=%d (rest of day)", consecutiveLosses);
}

void ResetDailyCounters()
{
    dailyClosedTrades = 0;
    consecutiveLosses = 0;
    lossLockActive = false;
    lossLockUntil = 0;
    dailyEntriesBuy = 0;
    dailyEntriesSell = 0;
    dailyBlockedSpread = 0;
    dailyBlockedDailyLoss = 0;
    dailyBlockedTradeCap = 0;
    dailyBlockedLossLock = 0;
    dailyBlockedEquityCap = 0;
    dailyLossLockActivations = 0;
}

void RegisterEntryDeal(datetime dealTime, string side, double price, double volume)
{
    UpdateDailyAnchor();
    if(side == "buy")
        dailyEntriesBuy++;
    else if(side == "sell")
        dailyEntriesSell++;
    LogTelemetryEvent(dealTime, "entry", "", side, price, volume, 0.0, "");
}

void RegisterClosedDeal(datetime dealTime, double netProfit, string side, double price, double volume)
{
    UpdateDailyAnchor();
    MqlDateTime nowStruct, dealStruct;
    TimeToStruct(TimeCurrent(), nowStruct);
    TimeToStruct(dealTime, dealStruct);
    if(nowStruct.day_of_year != dealStruct.day_of_year)
        return;

    dailyClosedTrades++;
    if(netProfit >= 0.0)
    {
        consecutiveLosses = 0;
        LogTelemetryEvent(dealTime, "exit", "win", side, price, volume, netProfit, "");
        return;
    }

    consecutiveLosses++;
    LogTelemetryEvent(dealTime, "exit", "loss", side, price, volume, netProfit, "");
    if(InpMaxConsecutiveLosses > 0 && consecutiveLosses >= InpMaxConsecutiveLosses)
        ActivateLossLock();
}

bool OpenTelemetryFile()
{
    if(!InpEnableTelemetry)
        return false;
    if(telemetryHandle != INVALID_HANDLE)
        return true;

    telemetryHandle = FileOpen(runtimeTelemetryFileName, FILE_CSV | FILE_READ | FILE_WRITE | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_COMMON | FILE_ANSI, ';');
    if(telemetryHandle == INVALID_HANDLE)
    {
        PrintFormat("Telemetry open failed for '%s' (%d)", runtimeTelemetryFileName, GetLastError());
        return false;
    }

    if(FileSize(telemetryHandle) == 0)
    {
        FileWrite(telemetryHandle,
                  "timestamp", "event", "reason", "side", "price", "volume", "net_profit", "balance", "equity",
                  "daily_closed_trades", "daily_entries_buy", "daily_entries_sell", "consecutive_losses",
                  "blocked_spread", "blocked_daily_loss", "blocked_trade_cap", "blocked_loss_lock", "blocked_equity_cap",
                  "loss_lock_activations", "note");
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

void LogTelemetryEvent(datetime stamp, string eventType, string reason, string side, double price, double volume, double netProfit, string note)
{
    if(!InpEnableTelemetry)
        return;
    if(!OpenTelemetryFile())
        return;

    FileSeek(telemetryHandle, 0, SEEK_END);
    FileWrite(telemetryHandle,
              TimeToString(stamp, TIME_DATE | TIME_SECONDS),
              eventType,
              reason,
              side,
              price,
              volume,
              netProfit,
              AccountInfoDouble(ACCOUNT_BALANCE),
              AccountInfoDouble(ACCOUNT_EQUITY),
              dailyClosedTrades,
              dailyEntriesBuy,
              dailyEntriesSell,
              consecutiveLosses,
              dailyBlockedSpread,
              dailyBlockedDailyLoss,
              dailyBlockedTradeCap,
              dailyBlockedLossLock,
              dailyBlockedEquityCap,
              dailyLossLockActivations,
              note);
    FileFlush(telemetryHandle);
}

void FlushDailySummary(datetime stamp, string trigger)
{
    if(currentDayStart <= 0)
        return;
    LogTelemetryEvent(stamp, "daily_summary", trigger, "", 0.0, 0.0, AccountInfoDouble(ACCOUNT_BALANCE) - dailyStartBalance, "");
}

int GetSignal()
{
    double ema[], slowEma[], trendStackEma[], rsi[], atr[];
    ArraySetAsSeries(ema, true);
    ArraySetAsSeries(slowEma, true);
    ArraySetAsSeries(trendStackEma, true);
    ArraySetAsSeries(rsi, true);
    ArraySetAsSeries(atr, true);

    if(CopyBuffer(emaHandle, 0, 0, 3, ema) < 3 ||
       CopyBuffer(slowEmaHandle, 0, 0, 3, slowEma) < 3 ||
       CopyBuffer(trendStackHandle, 0, 0, 3, trendStackEma) < 3 ||
       CopyBuffer(rsiHandle, 0, 0, 3, rsi) < 3 ||
       CopyBuffer(atrHandle, 0, 0, 3, atr) < 3)
        return 0;

    if(atr[1] <= 0.0)
        return 0;

    datetime signalTime = iTime(runtimeSymbol, InpSignalTimeframe, 1);
    MqlDateTime barTime;
    TimeToStruct(signalTime, barTime);
    if(!IsAllowedWeekday(barTime.day_of_week) || IsBlockedEntryHour(barTime.hour))
        return 0;

    double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
    double distAtr = (close1 - ema[1]) / atr[1];
    double atrPct = (close1 > 0.0 ? (atr[1] / close1) : 0.0);
    bool isBullTrend = (ema[1] > slowEma[1]);
    bool isBearTrend = (ema[1] < slowEma[1]);
    bool isStackedBearTrend = (ema[1] < slowEma[1] && slowEma[1] < trendStackEma[1]);
    double shortDist = InpShortDistanceATR;
    double shortMaxDist = InpShortMaxDistanceATR;
    double shortRsiMin = InpShortRsiMin;
    double shortRsiMax = InpShortRsiMax;
    if(InpUseAdaptiveShortAtrRegime)
    {
        bool isActive = (atrPct >= InpShortAtrRegimePivot);
        if(isActive)
        {
            shortDist = InpShortDistanceATRActive;
            shortMaxDist = InpShortMaxDistanceATRActive;
            shortRsiMin = InpShortRsiMinActive;
            shortRsiMax = InpShortRsiMaxActive;
        }
        else
        {
            shortDist = InpShortDistanceATRCalm;
            shortMaxDist = InpShortMaxDistanceATRCalm;
            shortRsiMin = InpShortRsiMinCalm;
            shortRsiMax = InpShortRsiMaxCalm;
        }
    }

    bool primaryLongSignal =
       (InpAllowBuy &&
        IsHourInRange(barTime.hour, InpLongStartHour, InpLongEndHour) &&
        distAtr <= -InpLongDistanceATR &&
        (InpLongMaxDistanceATR <= 0.0 || distAtr >= -InpLongMaxDistanceATR) &&
        (InpLongMinATRPercent <= 0.0 || atrPct >= InpLongMinATRPercent) &&
        (InpLongMaxATRPercent <= 0.0 || atrPct <= InpLongMaxATRPercent) &&
        rsi[1] <= InpLongRsiMax &&
        IsTrendFilterSatisfied(InpLongTrendFilterMode, isBullTrend, isBearTrend));

    bool secondLongSignal =
       (InpAllowBuy &&
        InpEnableSecondLongBucket &&
        IsHourInRange(barTime.hour, InpSecondLongStartHour, InpSecondLongEndHour) &&
        distAtr <= -InpSecondLongDistanceATR &&
        (InpSecondLongMaxDistanceATR <= 0.0 || distAtr >= -InpSecondLongMaxDistanceATR) &&
        (InpSecondLongMinATRPercent <= 0.0 || atrPct >= InpSecondLongMinATRPercent) &&
        (InpSecondLongMaxATRPercent <= 0.0 || atrPct <= InpSecondLongMaxATRPercent) &&
        rsi[1] <= InpSecondLongRsiMax &&
        IsTrendFilterSatisfied(InpSecondLongTrendFilterMode, isBullTrend, isBearTrend));

    if(primaryLongSignal || secondLongSignal)
        return 1;

    if(InpAllowSell &&
       IsHourInRange(barTime.hour, InpShortStartHour, InpShortEndHour) &&
       distAtr >= shortDist &&
       (shortMaxDist <= 0.0 || distAtr <= shortMaxDist) &&
       (InpShortMinATRPercent <= 0.0 || atrPct >= InpShortMinATRPercent) &&
       (InpShortMaxATRPercent <= 0.0 || atrPct <= InpShortMaxATRPercent) &&
       rsi[1] >= shortRsiMin &&
       rsi[1] <= shortRsiMax &&
       IsTrendFilterSatisfied(InpShortTrendFilterMode, isBullTrend, isBearTrend) &&
       (!InpShortRequireStackedBearTrend || isStackedBearTrend))
        return -1;

    if(InpAllowSell &&
       InpEnableSecondShortBucket &&
       IsHourInRange(barTime.hour, InpSecondShortStartHour, InpSecondShortEndHour) &&
       distAtr >= InpSecondShortDistanceATR &&
       (InpSecondShortMaxDistanceATR <= 0.0 || distAtr <= InpSecondShortMaxDistanceATR) &&
       (InpSecondShortMinATRPercent <= 0.0 || atrPct >= InpSecondShortMinATRPercent) &&
       (InpSecondShortMaxATRPercent <= 0.0 || atrPct <= InpSecondShortMaxATRPercent) &&
       rsi[1] >= InpSecondShortRsiMin &&
       rsi[1] <= InpSecondShortRsiMax &&
       (!InpSecondShortRequireBearTrend || isBearTrend))
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

    double close1 = iClose(runtimeSymbol, InpSignalTimeframe, 1);
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!posInfo.SelectByIndex(i))
            continue;
        if(posInfo.Symbol() != runtimeSymbol || posInfo.Magic() != InpMagicNumber)
            continue;

        bool isBuy = (posInfo.PositionType() == POSITION_TYPE_BUY);
        int heldBars = HeldBars(posInfo.Time());
        int holdLimit = GetHoldBarsForSide(isBuy);
        bool timeExit = (heldBars >= holdLimit);
        bool meanExit = false;
        double exitBufferAtr = GetExitBufferForSide(isBuy);
        if(InpExitOnMeanReversion && exitBufferAtr > 0.0 && atr[1] > 0.0)
        {
            double exitBuffer = atr[1] * exitBufferAtr;
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
    int shift = iBarShift(runtimeSymbol, InpSignalTimeframe, openedAt, false);
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

int GetHoldBarsForSide(bool isBuy)
{
    if(isBuy && InpLongHoldBars > 0)
        return InpLongHoldBars;
    if(!isBuy && InpShortHoldBars > 0)
        return InpShortHoldBars;
    return InpHoldBars;
}

double GetExitBufferForSide(bool isBuy)
{
    if(isBuy && InpLongExitBufferATR > 0.0)
        return InpLongExitBufferATR;
    if(!isBuy && InpShortExitBufferATR > 0.0)
        return InpShortExitBufferATR;
    return InpExitBufferATR;
}

void OpenPosition(bool isBuy)
{
    MqlTick tick;
    if(!SymbolInfoTick(runtimeSymbol, tick))
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
    trade.PositionOpen(runtimeSymbol, isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, lots, price, sl, 0.0, comment);
}

int CountOpenPositions()
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(!posInfo.SelectByIndex(i))
            continue;
        if(posInfo.Symbol() == runtimeSymbol && posInfo.Magic() == InpMagicNumber)
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
        if(posInfo.Symbol() != runtimeSymbol || posInfo.Magic() != InpMagicNumber)
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

    double tickValue = SymbolInfoDouble(runtimeSymbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(runtimeSymbol, SYMBOL_TRADE_TICK_SIZE);
    if(tickValue <= 0.0 || tickSize <= 0.0)
        return 0.0;

    double pricePerLot = (tickValue / tickSize) * stopDistancePrice;
    if(pricePerLot <= 0.0)
        return 0.0;

    double lots = riskAmount / pricePerLot;
    double minLot = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_MAX);
    double stepLot = SymbolInfoDouble(runtimeSymbol, SYMBOL_VOLUME_STEP);
    if(minLot <= 0.0 || maxLot <= 0.0 || stepLot <= 0.0)
        return 0.0;

    lots = MathMax(minLot, MathMin(maxLot, lots));
    lots = MathFloor(lots / stepLot) * stepLot;
    return lots;
}

double NormalizePrice(double price)
{
    int digits = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_DIGITS);
    return NormalizeDouble(price, digits);
}

double GetPipSize()
{
    double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
    if(point <= 0.0)
        return 0.0;
    long calcMode = SymbolInfoInteger(runtimeSymbol, SYMBOL_TRADE_CALC_MODE);
    if(calcMode == SYMBOL_CALC_MODE_FOREX || calcMode == SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE)
    {
        int digits = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_DIGITS);
        if(digits == 3 || digits == 5)
            return point * 10.0;
    }
    return point;
}

double GetCurrentSpreadPips()
{
    MqlTick tick;
    if(!SymbolInfoTick(runtimeSymbol, tick))
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
    int stops = (int)SymbolInfoInteger(runtimeSymbol, SYMBOL_TRADE_STOPS_LEVEL);
    if(stops <= 0)
        return 0.0;
    double point = SymbolInfoDouble(runtimeSymbol, SYMBOL_POINT);
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

bool IsTrendFilterSatisfied(int mode, bool isBullTrend, bool isBearTrend)
{
    if(mode == 1)
        return isBullTrend;
    if(mode == 2)
        return isBearTrend;
    return true;
}

bool InitializeEntryFilters()
{
    for(int i = 0; i < 7; i++)
        allowedWeekdays[i] = false;
    for(int j = 0; j < 24; j++)
        blockedEntryHours[j] = false;

    if(!ParseAllowedWeekdays(runtimeAllowedWeekdays))
        return false;
    if(!ParseBlockedHours(runtimeBlockedEntryHours))
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
