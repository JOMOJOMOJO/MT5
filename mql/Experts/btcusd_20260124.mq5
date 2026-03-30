//+------------------------------------------------------------------+
//| BTCUSD Scalping EA (EMA13/EMA100, 4 Trend-Follow Logics)        |
//| Created: 2026.02.07                                             |
//+------------------------------------------------------------------+

#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "2.00"
#property strict
#property description "BTCUSD M1/M3 EMA13/EMA100 Trend Scalper (4 logics)"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

//--- Global
CTrade trade;
CPositionInfo posInfo;

//--- Inputs (keep few for optimization)
// pips定義:
// - Forex: 5桁/3桁はpoint*10、それ以外はpoint
// - BTCUSDなど非Forex: pointをそのまま1 pipとして扱う
// 例) BTCUSDでpoint=0.01なら、1000 pips = 10.00ドル幅
input string          InpSymbol           = "BTCUSD";   // 取引シンボル（BTCUSD想定）
input ENUM_TIMEFRAMES InpTimeframe       = PERIOD_M1;   // 時間足（M1 or M3）
input int             InpFastEMAPeriod   = 13;          // EMA13
input int             InpSlowEMAPeriod   = 100;         // EMA100
input double          InpRiskPercent     = 1.0;         // 1トレードのリスク（%）目安: 0.3-1.5
input int             InpStopLossPips   = 6000;        // BTC M1目安: 3000-10000 / M3:6000-18000 (point=0.01なら約$30-$180)
input int             InpTakeProfitPips = 9000;        // BTC M1目安: 4000-14000 / M3:8000-26000 (point=0.01なら約$40-$260)
input int             InpMaxOpenTrades   = 1;           // 最大保有数

input bool            InpUseTimeFilter   = false;       // BTCは24/7のため通常OFF推奨
input int             InpTradeStartHour  = 1;           // 取引開始時刻（サーバー時刻）
input int             InpTradeEndHour    = 19;          // 取引終了時刻（サーバー時刻）
input bool            InpUseLossStop     = true;        // 連敗停止を使うか
input int             InpMaxConsecutiveLosses = 3;      // 連敗停止の回数
input double          InpMinTradesPerDay = 1.0;         // 最低トレード/日（評価用）
input double          InpTargetTradesPerDay = 3.0;      // 目標トレード/日（評価用）
input bool            InpUseHardTradeFloor = false;     // 最低トレード/日を満たさない場合を即0にするか
input bool            InpUseFreezeLevelCheck = false;   // 新規時にFreezeLevelも距離判定に使うか

//--- Main optimization knobs (3)
input double          InpTrendSlopePips  = 600.0;       // BTC M1:150-1200 / M3:300-2200 (EMA100の3バー傾き閾値)
input double          InpTouchTolerancePips = 700.0;    // BTC M1:300-1200 / M3:600-2200 (EMA13への許容距離)
input int             InpBreakoutLookback = 20;         // M1:10-40 / M3:8-30
input double          InpBreakoutBufferPips = 400.0;    // BTC M1:150-900 / M3:300-1800 (高値安値ブレイクの上乗せ幅)
input bool            InpUseVolatilityRegime = true;    // ATRで低ボラ/通常を切り替えるか
input int             InpATRPeriod       = 14;          // ATR期間
input double          InpLowVolATRPips   = 9000.0;      // BTC M1:4500-9000 / M3:9000-18000
input int             InpLowVolLogicMask = 5;           // 低ボラ時ロジック（1-15、レジームON時のみ）
input int             InpNormalLogicMask = 15;          // 通常時ロジック（1-15、レジームON時のみ）
input double          InpMaxSpreadPips   = 3500.0;      // BTC M1:300-3500 / M3:600-4500 (point=0.01なら約$3-$45)
input long            InpMagicNumber     = 123456;      // 同一シンボルで派生版を回す場合は変える
input bool            InpDebugCounters   = true;        // テスターで入口条件の落ち方を集計する

//--- Logic selection mask: 1=L1, 2=L2, 4=L3, 8=L4 (sum to combine)
// 例: 1=L1, 2=L2, 3=L1+L2, 4=L3, 5=L1+L3, 6=L2+L3, 7=L1+L2+L3
//     8=L4, 9=L1+L4, 10=L2+L4, 11=L1+L2+L4, 12=L3+L4
//     13=L1+L3+L4, 14=L2+L3+L4, 15=ALL
input int             InpLogicMask       = 15;          // ベースロジック組み合わせ（1-15）
input int             InpLogicCooldownBars = 3;         // 同一ロジックのクールダウン（バー）
input int             InpMaxOpenPerLogic = 1;           // ロジック別の最大保有数

//--- Internal constants
const int    SLOPE_BARS   = 3;

//--- Indicator handles
int emaFastHandle = INVALID_HANDLE;
int emaSlowHandle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;

//--- State
datetime lastLogicEntryTime[5];
datetime lastDealTime = 0;
ulong lastDealTicket = 0;
int consecutiveLosses = 0;
int lastDayOfYear = -1;
double initialBalance = 0.0;
datetime testStartTime = 0;

//--- Debug counters
long dbgBarsSeen = 0;
long dbgBlockedMaxOpen = 0;
long dbgBlockedTradingTime = 0;
long dbgBlockedSpread = 0;
long dbgBlockedLossStop = 0;
long dbgBlockedNoLogic = 0;
long dbgBlockedSignalZero = 0;
long dbgBlockedCanEnter = 0;
long dbgSignalBuy = 0;
long dbgSignalSell = 0;
long dbgSignalDataShort = 0;
long dbgTrendUp = 0;
long dbgTrendDown = 0;
long dbgTrendFlat = 0;
long dbgLogicTriggers[5];
long dbgRegimeLowVol = 0;
long dbgRegimeNormal = 0;
long dbgRegimeAtrMissing = 0;
long dbgBuyAttempts = 0;
long dbgSellAttempts = 0;
long dbgOrderSuccess = 0;
long dbgOrderFail = 0;
long dbgLotsZero = 0;
long dbgStopsBlocked = 0;
double dbgSpreadSum = 0.0;
double dbgSpreadMax = 0.0;
long dbgSpreadSamples = 0;
double dbgAtrPipsSum = 0.0;
double dbgAtrPipsMax = 0.0;
long dbgAtrSamples = 0;

//+------------------------------------------------------------------+
int OnInit()
{
    trade.SetExpertMagicNumber((ulong)InpMagicNumber);
    initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    testStartTime = TimeCurrent();

    if(InpTimeframe != PERIOD_M1 && InpTimeframe != PERIOD_M3)
    {
        Print("Invalid timeframe. Use M1 or M3.");
        return INIT_PARAMETERS_INCORRECT;
    }
    if(InpStopLossPips <= 0 || InpTakeProfitPips <= 0 || InpTrendSlopePips < 0.0)
    {
        Print("Invalid parameters: check SL/TP/TrendSlope.");
        return INIT_PARAMETERS_INCORRECT;
    }
    if(InpMagicNumber <= 0)
    {
        Print("Invalid magic number. Use a positive value.");
        return INIT_PARAMETERS_INCORRECT;
    }

    emaFastHandle = iMA(InpSymbol, InpTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    if(emaFastHandle == INVALID_HANDLE)
    {
        Print("Failed to create EMA fast handle");
        return INIT_FAILED;
    }

    emaSlowHandle = iMA(InpSymbol, InpTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
    if(emaSlowHandle == INVALID_HANDLE)
    {
        Print("Failed to create EMA slow handle");
        return INIT_FAILED;
    }

    if(InpUseVolatilityRegime)
    {
        if(InpATRPeriod <= 0)
        {
            Print("Invalid ATR period: ", InpATRPeriod);
            return INIT_FAILED;
        }
        atrHandle = iATR(InpSymbol, InpTimeframe, InpATRPeriod);
        if(atrHandle == INVALID_HANDLE)
        {
            Print("Failed to create ATR handle");
            return INIT_FAILED;
        }
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

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(emaFastHandle != INVALID_HANDLE)
        IndicatorRelease(emaFastHandle);
    if(emaSlowHandle != INVALID_HANDLE)
        IndicatorRelease(emaSlowHandle);
    if(atrHandle != INVALID_HANDLE)
        IndicatorRelease(atrHandle);

    if(InpDebugCounters)
        PrintDebugSummary(reason);
}

//+------------------------------------------------------------------+
void PrintDebugSummary(const int reason)
{
    double avgSpread = (dbgSpreadSamples > 0) ? (dbgSpreadSum / dbgSpreadSamples) : 0.0;
    double avgAtrPips = (dbgAtrSamples > 0) ? (dbgAtrPipsSum / dbgAtrSamples) : 0.0;

    PrintFormat(
        "DebugSummary reason=%d bars=%I64d max_open=%I64d time=%I64d spread_block=%I64d loss_stop=%I64d no_logic=%I64d signal_zero=%I64d can_enter=%I64d buy_signals=%I64d sell_signals=%I64d order_ok=%I64d order_fail=%I64d lots_zero=%I64d stops_block=%I64d data_short=%I64d",
        reason,
        dbgBarsSeen,
        dbgBlockedMaxOpen,
        dbgBlockedTradingTime,
        dbgBlockedSpread,
        dbgBlockedLossStop,
        dbgBlockedNoLogic,
        dbgBlockedSignalZero,
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
        "DebugTrend up=%I64d down=%I64d flat=%I64d logic1=%I64d logic2=%I64d logic3=%I64d logic4=%I64d low_vol=%I64d normal=%I64d atr_missing=%I64d avg_atr_pips=%.2f max_atr_pips=%.2f avg_spread_pips=%.2f max_spread_pips=%.2f buy_attempts=%I64d sell_attempts=%I64d",
        dbgTrendUp,
        dbgTrendDown,
        dbgTrendFlat,
        dbgLogicTriggers[1],
        dbgLogicTriggers[2],
        dbgLogicTriggers[3],
        dbgLogicTriggers[4],
        dbgRegimeLowVol,
        dbgRegimeNormal,
        dbgRegimeAtrMissing,
        avgAtrPips,
        dbgAtrPipsMax,
        avgSpread,
        dbgSpreadMax,
        dbgBuyAttempts,
        dbgSellAttempts
    );
}

//+------------------------------------------------------------------+
double OnTester()
{
    double trades = TesterStatistics(STAT_TRADES);
    double profit = TesterStatistics(STAT_PROFIT);
    double dd = TesterStatistics(STAT_EQUITY_DD);
    double pf = TesterStatistics(STAT_PROFIT_FACTOR);
    datetime testEndTime = TimeCurrent();
    double durationDays = 0.0;
    if(testStartTime > 0 && testEndTime > testStartTime)
        durationDays = (double)(testEndTime - testStartTime) / 86400.0;
    if(durationDays < 1.0)
        durationDays = 1.0;
    // Forex is weekday-based, crypto is 24/7.
    double tradingDays = durationDays;
    if(IsForexLikeSymbol())
        tradingDays = durationDays * (5.0 / 7.0);
    if(tradingDays < 1.0)
        tradingDays = 1.0;
    double tradesPerDay = trades / tradingDays;

    if(profit <= 0.0 || dd <= 0.0 || pf <= 0.0)
        return 0.0;
    if(InpUseHardTradeFloor && InpMinTradesPerDay > 0.0 && tradesPerDay < InpMinTradesPerDay)
        return 0.0;

    double ddPct = 0.0;
    if(initialBalance > 0.0)
        ddPct = (dd / initialBalance) * 100.0;

    if(pf < 1.10 || ddPct > 25.0)
        return 0.0;

    double tradeScore = 1.0;
    if(InpMinTradesPerDay > 0.0)
    {
        double minRatio = tradesPerDay / InpMinTradesPerDay;
        minRatio = MathMax(0.0, MathMin(1.0, minRatio));
        tradeScore *= (0.2 + 0.8 * minRatio);
    }
    if(InpTargetTradesPerDay > 0.0)
    {
        double targetRatio = tradesPerDay / InpTargetTradesPerDay;
        targetRatio = MathMax(0.0, MathMin(1.0, targetRatio));
        tradeScore *= targetRatio;
    }

    return (profit / (dd + 1.0)) * pf * tradeScore;
}

//+------------------------------------------------------------------+
void OnTick()
{
    if(!IsNewBar())
        return;

    dbgBarsSeen++;

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

    UpdateLossStreak();
    if(IsLossStopBlocked())
    {
        dbgBlockedLossStop++;
        return;
    }

    int activeLogicMask = GetActiveLogicMask();
    if(activeLogicMask <= 0)
    {
        dbgBlockedNoLogic++;
        return;
    }

    int logicId = 0;
    int signal = GetTradingSignal(logicId, activeLogicMask);
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
    if(signal == 1)
    {
        dbgSignalBuy++;
        OpenBuyPosition(logicId);
    }
    else if(signal == -1)
    {
        dbgSignalSell++;
        OpenSellPosition(logicId);
    }
}

//+------------------------------------------------------------------+
bool IsNewBar()
{
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(InpSymbol, InpTimeframe, 0);
    if(currentBarTime != lastBarTime)
    {
        lastBarTime = currentBarTime;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
int GetTradingSignal(int &logicId, int activeLogicMask)
{
    double emaFast[], emaSlow[];
    int lookback = MathMax(2, InpBreakoutLookback);
    int needBars = MathMax(lookback + 3, SLOPE_BARS + 4);

    ArraySetAsSeries(emaFast, true);
    ArraySetAsSeries(emaSlow, true);

    int fastCopied = CopyBuffer(emaFastHandle, 0, 0, needBars, emaFast);
    int slowCopied = CopyBuffer(emaSlowHandle, 0, 0, needBars, emaSlow);
    if(fastCopied < needBars || slowCopied < needBars)
    {
        dbgSignalDataShort++;
        return 0;
    }

    // Use closed bars for stability
    double open1 = iOpen(InpSymbol, InpTimeframe, 1);
    double close1 = iClose(InpSymbol, InpTimeframe, 1);
    double high1 = iHigh(InpSymbol, InpTimeframe, 1);
    double low1  = iLow(InpSymbol, InpTimeframe, 1);

    double close2 = iClose(InpSymbol, InpTimeframe, 2);
    double high2 = iHigh(InpSymbol, InpTimeframe, 2);
    double low2  = iLow(InpSymbol, InpTimeframe, 2);

    double emaFast1 = emaFast[1];
    double emaFast2 = emaFast[2];
    double emaSlow1 = emaSlow[1];

    double pip = GetPipSize();
    double tol = InpTouchTolerancePips * pip;

    double trendSlopePips = GetEffectiveTrendSlopePips();
    double slope = emaSlow[1] - emaSlow[1 + SLOPE_BARS];
    bool emaUp = slope >= (trendSlopePips * pip);
    bool emaDown = slope <= -(trendSlopePips * pip);
    if(emaUp)
        dbgTrendUp++;
    else if(emaDown)
        dbgTrendDown++;
    else
        dbgTrendFlat++;

    bool emaFastAbove = emaFast1 > emaSlow1;
    bool emaFastBelow = emaFast1 < emaSlow1;

    bool usePullback = IsLogicEnabled(1, activeLogicMask);
    bool useBreakout = IsLogicEnabled(2, activeLogicMask);
    bool useReclaim  = IsLogicEnabled(3, activeLogicMask);
    bool useMomentum = IsLogicEnabled(4, activeLogicMask);

    // Logic 1: Pullback touch on EMA13
    if(usePullback)
    {
        bool touchBuy = (low1 <= emaFast1 + tol && high1 >= emaFast1 - tol);
        bool touchSell = touchBuy;

        if(emaUp && emaFastAbove && close1 < open1 && touchBuy && close1 >= emaFast1 - tol)
        {
            logicId = 1;
            dbgLogicTriggers[1]++;
            return 1;
        }
        if(emaDown && emaFastBelow && close1 > open1 && touchSell && close1 <= emaFast1 + tol)
        {
            logicId = 1;
            dbgLogicTriggers[1]++;
            return -1;
        }
    }

    // Logic 2: Trend breakout
    if(useBreakout)
    {
        double buffer = InpBreakoutBufferPips * pip;
        int highestIdx = iHighest(InpSymbol, InpTimeframe, MODE_HIGH, lookback, 2);
        int lowestIdx  = iLowest(InpSymbol, InpTimeframe, MODE_LOW, lookback, 2);
        if(highestIdx >= 0 && lowestIdx >= 0)
        {
            double highN = iHigh(InpSymbol, InpTimeframe, highestIdx);
            double lowN  = iLow(InpSymbol, InpTimeframe, lowestIdx);
            if(emaUp && emaFastAbove && close1 > highN + buffer)
            {
                logicId = 2;
                dbgLogicTriggers[2]++;
                return 1;
            }
            if(emaDown && emaFastBelow && close1 < lowN - buffer)
            {
                logicId = 2;
                dbgLogicTriggers[2]++;
                return -1;
            }
        }
    }

    // Logic 3: Reclaim EMA13 after pullback
    if(useReclaim)
    {
        if(emaUp && emaFastAbove && close2 < emaFast2 && close1 > emaFast1 && close1 > open1)
        {
            logicId = 3;
            dbgLogicTriggers[3]++;
            return 1;
        }
        if(emaDown && emaFastBelow && close2 > emaFast2 && close1 < emaFast1 && close1 < open1)
        {
            logicId = 3;
            dbgLogicTriggers[3]++;
            return -1;
        }
    }

    // Logic 4: Momentum continuation (break previous bar while above/below EMA13)
    if(useMomentum)
    {
        if(emaUp && emaFastAbove && close1 > emaFast1 && close1 > high2)
        {
            logicId = 4;
            dbgLogicTriggers[4]++;
            return 1;
        }
        if(emaDown && emaFastBelow && close1 < emaFast1 && close1 < low2)
        {
            logicId = 4;
            dbgLogicTriggers[4]++;
            return -1;
        }
    }

    return 0;
}

//+------------------------------------------------------------------+
bool IsTradingTime()
{
    if(!InpUseTimeFilter)
        return true;

    MqlDateTime t;
    TimeToStruct(TimeCurrent(), t);
    return IsHourInRange(t.hour, InpTradeStartHour, InpTradeEndHour);
}

//+------------------------------------------------------------------+
void OpenBuyPosition(int logicId)
{
    MqlTick tick;
    if(!SymbolInfoTick(InpSymbol, tick))
        return;

    if(InpStopLossPips <= 0 || InpTakeProfitPips <= 0)
        return;

    dbgBuyAttempts++;
    double lots = CalculateLotSize();
    if(lots <= 0)
        return;

    double pip = GetPipSize();
    double sl = tick.ask - InpStopLossPips * pip;
    double tp = tick.ask + InpTakeProfitPips * pip;

    if(!ValidateStops(ORDER_TYPE_BUY, tick.ask, sl, tp))
    {
        dbgStopsBlocked++;
        Print("Buy blocked: SL/TP too close to price (stops level).");
        return;
    }

    string comment = BuildOrderComment(logicId, true);
    bool ok = trade.PositionOpen(InpSymbol, ORDER_TYPE_BUY, lots, tick.ask, sl, tp, comment);
    if(!ok)
    {
        dbgOrderFail++;
        Print("Buy failed: ", trade.ResultRetcode());
    }
    else
    {
        dbgOrderSuccess++;
        lastLogicEntryTime[logicId] = iTime(InpSymbol, InpTimeframe, 0);
    }
}

//+------------------------------------------------------------------+
void OpenSellPosition(int logicId)
{
    MqlTick tick;
    if(!SymbolInfoTick(InpSymbol, tick))
        return;

    if(InpStopLossPips <= 0 || InpTakeProfitPips <= 0)
        return;

    dbgSellAttempts++;
    double lots = CalculateLotSize();
    if(lots <= 0)
        return;

    double pip = GetPipSize();
    double sl = tick.bid + InpStopLossPips * pip;
    double tp = tick.bid - InpTakeProfitPips * pip;

    if(!ValidateStops(ORDER_TYPE_SELL, tick.bid, sl, tp))
    {
        dbgStopsBlocked++;
        Print("Sell blocked: SL/TP too close to price (stops level).");
        return;
    }

    string comment = BuildOrderComment(logicId, false);
    bool ok = trade.PositionOpen(InpSymbol, ORDER_TYPE_SELL, lots, tick.bid, sl, tp, comment);
    if(!ok)
    {
        dbgOrderFail++;
        Print("Sell failed: ", trade.ResultRetcode());
    }
    else
    {
        dbgOrderSuccess++;
        lastLogicEntryTime[logicId] = iTime(InpSymbol, InpTimeframe, 0);
    }
}

//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
int CountOpenPositionsByLogic(int logicId)
{
    if(logicId <= 0)
        return 0;
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(!posInfo.SelectByIndex(i))
            continue;
        if(posInfo.Symbol() != InpSymbol || posInfo.Magic() != InpMagicNumber)
            continue;
        string comment = posInfo.Comment();
        if(IsLogicMatch(comment, logicId))
            count++;
    }
    return count;
}

//+------------------------------------------------------------------+
bool CanEnterLogic(int logicId)
{
    if(logicId <= 0)
        return false;
    if(InpMaxOpenPerLogic > 0 && CountOpenPositionsByLogic(logicId) >= InpMaxOpenPerLogic)
        return false;
    if(InpLogicCooldownBars > 0 && lastLogicEntryTime[logicId] > 0)
    {
        int shift = iBarShift(InpSymbol, InpTimeframe, lastLogicEntryTime[logicId], true);
        if(shift >= 0 && shift < InpLogicCooldownBars)
            return false;
    }
    return true;
}

//+------------------------------------------------------------------+
bool IsLogicEnabled(int logicId, int logicMask)
{
    if(logicId < 1 || logicId > 4)
        return false;
    int mask = 1 << (logicId - 1);
    return ((logicMask & mask) != 0);
}

//+------------------------------------------------------------------+
int ClampLogicMask(int logicMask)
{
    if(logicMask < 0)
        return 0;
    if(logicMask > 15)
        return 15;
    return logicMask;
}

//+------------------------------------------------------------------+
double GetCurrentATRPips()
{
    if(atrHandle == INVALID_HANDLE)
        return 0.0;

    double atr[1];
    if(CopyBuffer(atrHandle, 0, 1, 1, atr) <= 0)
        return 0.0;

    double pip = GetPipSize();
    if(pip <= 0.0)
        return 0.0;

    double atrPips = atr[0] / pip;
    if(atrPips > 0.0)
    {
        dbgAtrSamples++;
        dbgAtrPipsSum += atrPips;
        dbgAtrPipsMax = MathMax(dbgAtrPipsMax, atrPips);
    }
    return atrPips;
}

//+------------------------------------------------------------------+
int GetActiveLogicMask()
{
    int baseMask = ClampLogicMask(InpLogicMask);
    if(baseMask == 0)
        return 0;

    if(!InpUseVolatilityRegime)
        return baseMask;

    double atrPips = GetCurrentATRPips();
    if(atrPips <= 0.0)
    {
        dbgRegimeAtrMissing++;
        return 0;
    }

    double lowVolThreshold = GetEffectiveLowVolATRPips();
    int regimeMask = (atrPips <= lowVolThreshold)
        ? GetEffectiveLowVolLogicMask()
        : GetEffectiveNormalLogicMask();
    if(atrPips <= lowVolThreshold)
        dbgRegimeLowVol++;
    else
        dbgRegimeNormal++;

    // Final logic set = base allow-list AND current regime allow-list.
    return (baseMask & regimeMask);
}

//+------------------------------------------------------------------+
bool IsBtcLikeSymbol()
{
    string symbolUpper = InpSymbol;
    StringToUpper(symbolUpper);
    return (StringFind(symbolUpper, "BTC") >= 0);
}

//+------------------------------------------------------------------+
double GetEffectiveTrendSlopePips()
{
    return InpTrendSlopePips;
}

//+------------------------------------------------------------------+
double GetEffectiveLowVolATRPips()
{
    return InpLowVolATRPips;
}

//+------------------------------------------------------------------+
int GetEffectiveLowVolLogicMask()
{
    return ClampLogicMask(InpLowVolLogicMask);
}

//+------------------------------------------------------------------+
int GetEffectiveNormalLogicMask()
{
    return ClampLogicMask(InpNormalLogicMask);
}

//+------------------------------------------------------------------+
int GetEffectiveMaxConsecutiveLosses()
{
    int maxConsecutiveLosses = InpMaxConsecutiveLosses;
    if(IsBtcLikeSymbol() && maxConsecutiveLosses > 2)
        maxConsecutiveLosses = 2;
    return maxConsecutiveLosses;
}

//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
double GetEffectiveMaxSpreadPips()
{
    double maxSpread = InpMaxSpreadPips;

    // Some BTCUSD brokers are exposed as FOREX calc mode with a structurally wider cash spread.
    if(IsBtcLikeSymbol())
        maxSpread = MathMax(maxSpread, 3500.0);

    return maxSpread;
}

//+------------------------------------------------------------------+
bool IsSpreadAllowed()
{
    double maxSpread = GetEffectiveMaxSpreadPips();
    if(maxSpread <= 0.0)
        return true;

    double spreadPips = GetCurrentSpreadPips();
    if(spreadPips < 0.0)
        return false;
    return (spreadPips <= maxSpread);
}

//+------------------------------------------------------------------+
void UpdateLossStreak()
{
    if(!InpUseLossStop)
        return;

    MqlDateTime t;
    TimeToStruct(TimeCurrent(), t);
    if(t.day_of_year != lastDayOfYear)
    {
        lastDayOfYear = t.day_of_year;
        consecutiveLosses = 0;
        lastDealTime = 0;
        lastDealTicket = 0;
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

        string symbol = HistoryDealGetString(deal, DEAL_SYMBOL);
        if(symbol != InpSymbol)
            continue;

        long magic = HistoryDealGetInteger(deal, DEAL_MAGIC);
        if(magic != InpMagicNumber)
            continue;

        long entry = HistoryDealGetInteger(deal, DEAL_ENTRY);
        if(entry != DEAL_ENTRY_OUT)
            continue;

        double profit = HistoryDealGetDouble(deal, DEAL_PROFIT)
                      + HistoryDealGetDouble(deal, DEAL_SWAP)
                      + HistoryDealGetDouble(deal, DEAL_COMMISSION);
        if(profit < 0.0)
            consecutiveLosses++;
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

//+------------------------------------------------------------------+
bool IsLossStopBlocked()
{
    if(!InpUseLossStop)
        return false;
    int maxConsecutiveLosses = GetEffectiveMaxConsecutiveLosses();
    if(maxConsecutiveLosses <= 0)
        return false;
    return (consecutiveLosses >= maxConsecutiveLosses);
}

//+------------------------------------------------------------------+
double CalculateLotSize()
{
    if(InpStopLossPips <= 0)
        return 0.0;

    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double risk = equity * InpRiskPercent / 100.0;

    double tickValue = SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize  = SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_SIZE);
    if(tickValue <= 0 || tickSize <= 0)
        return 0.0;

    double pip = GetPipSize();
    double pipValue = (tickValue / tickSize) * pip;
    if(pipValue <= 0)
        return 0.0;

    double lots = risk / (InpStopLossPips * pipValue);

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

//+------------------------------------------------------------------+
bool IsForexLikeSymbol()
{
    long calcMode = SymbolInfoInteger(InpSymbol, SYMBOL_TRADE_CALC_MODE);
    return (calcMode == SYMBOL_CALC_MODE_FOREX || calcMode == SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE);
}

//+------------------------------------------------------------------+
double GetPipSize()
{
    double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    if(point <= 0.0)
        return 0.0;

    // Keep classic pip rule only for forex-like symbols.
    if(IsForexLikeSymbol())
    {
        int digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
        if(digits == 3 || digits == 5)
            return point * 10.0;
    }
    return point;
}

//+------------------------------------------------------------------+
void PrintSymbolUnitInfo()
{
    int digits = (int)SymbolInfoInteger(InpSymbol, SYMBOL_DIGITS);
    double point = SymbolInfoDouble(InpSymbol, SYMBOL_POINT);
    double tickSize = SymbolInfoDouble(InpSymbol, SYMBOL_TRADE_TICK_SIZE);
    double pip = GetPipSize();
    string mode = IsForexLikeSymbol() ? "FOREX" : "NON_FOREX";
    PrintFormat(
        "SymbolUnit %s mode=%s digits=%d point=%g tick=%g pip=%g (price for 1 pip)",
        InpSymbol, mode, digits, point, tickSize, pip
    );
}

//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
string BuildOrderComment(int logicId, bool isBuy)
{
    string side = isBuy ? "BUY" : "SELL";
    return "EMA Scalper L" + IntegerToString(logicId) + " " + side;
}

//+------------------------------------------------------------------+
bool IsLogicMatch(const string comment, int logicId)
{
    string tag = "L" + IntegerToString(logicId);
    return (StringFind(comment, tag) >= 0);
}

//+------------------------------------------------------------------+
bool IsHourInRange(int hour, int startHour, int endHour)
{
    int s = MathMax(0, MathMin(23, startHour));
    int e = MathMax(0, MathMin(23, endHour));

    if(s == e)
        return true;

    if(s < e)
        return (hour >= s && hour < e);

    return (hour >= s || hour < e);
}
//+------------------------------------------------------------------+
