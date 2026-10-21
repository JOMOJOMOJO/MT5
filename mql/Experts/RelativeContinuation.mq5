//+------------------------------------------------------------------+
//| Relative Continuation - ATR-scaled successor                      |
//+------------------------------------------------------------------+
#property copyright   "Trading System"
#property link        "https://www.mql5.com"
#property version     "2.00"
#property strict
#property description "USDJPY multi-bucket continuation prototype using EMA13/EMA100 trend, 50-unit anti-chop state, and parallel bucket entries."

#include <Trade\Trade.mqh>

CTrade trade;

#include "../Include/RelativeContinuation/Configuration.mqh"
#include "../Include/RelativeContinuation/RuntimeRisk.mqh"
#include "../Include/RelativeContinuation/ExecutionSafety.mqh"
#include "../Include/RelativeContinuation/MarketData.mqh"
#include "../Include/RelativeContinuation/PositionManagement.mqh"
#include "../Include/RelativeContinuation/PriceStructure.mqh"
#include "../Include/RelativeContinuation/Signals.mqh"
#include "../Include/RelativeContinuation/Orders.mqh"
#include "../Include/RelativeContinuation/TelemetryControl.mqh"
int OnInit()
  {
   runtimeSymbol = NormalizePresetString(InpSymbol);
   if(runtimeSymbol=="") runtimeSymbol=_Symbol;
   if(runtimeSymbol!=_Symbol) { Print("Attach to requested symbol chart: OnTick belongs to chart symbol"); return INIT_PARAMETERS_INCORRECT; }
   uint serverHash=2166136261;
   string server=AccountInfoString(ACCOUNT_SERVER);
   for(int i=0;i<StringLen(server);i++) serverHash=(serverHash^(uint)StringGetCharacter(server,i))*16777619;
   riskStatePrefix=StringFormat("RC2.%u.%I64d.%I64d.%s.",serverHash,AccountInfoInteger(ACCOUNT_LOGIN),InpMagicNumber,runtimeSymbol);
   if(StringLen(riskStatePrefix)>52) return INIT_PARAMETERS_INCORRECT;
   runtimeAllowedWeekdays = NormalizePresetString(InpAllowedWeekdays);
   runtimeTelemetryFileName = NormalizePresetString(InpTelemetryFileName);
   runtimeOperatorCommandFile = NormalizePresetString(InpOperatorCommandFile);
   runtimeStatusFileName = NormalizePresetString(InpStatusFileName);
   bool isTesterRuntime = ((bool)MQLInfoInteger(MQL_TESTER) || (bool)MQLInfoInteger(MQL_OPTIMIZATION));
   if(!isTesterRuntime)
     {
      string suffix=StringFormat("_%s_%I64d",runtimeSymbol,InpMagicNumber);
      if(runtimeTelemetryFileName=="relative_continuation.csv") runtimeTelemetryFileName="relative_continuation"+suffix+".csv";
      if(runtimeOperatorCommandFile=="relative_continuation_operator.txt") runtimeOperatorCommandFile="relative_continuation_operator"+suffix+".txt";
      if(runtimeStatusFileName=="relative_continuation_status.txt") runtimeStatusFileName="relative_continuation_status"+suffix+".txt";
     }
   runtimeOperatorControlEnabled = (InpEnableOperatorControl && !isTesterRuntime);
   runtimeStatusSnapshotEnabled = (InpEnableStatusSnapshot && !isTesterRuntime);

   if(
      InpFastEMAPeriod <= 0 || InpSlowEMAPeriod <= InpFastEMAPeriod || InpSlowSlopeLookback <= 0 ||
      InpPivotSpan <= 0 || InpTrendScanBars <= 20 || InpVolatilityLookbackBars <= 0 ||
      InpMinWindowRangeAtr <= 0.0 || InpGridStepAtr <= 0 || InpSessionStartHour < 0 || InpSessionStartHour > 23 ||
      InpSessionEndHour < 0 || InpSessionEndHour > 23 || InpSessionStartHour == InpSessionEndHour ||
      InpMaxEma13DistanceAtr <= 0.0 || InpMinUpperWickShare < 0.0 || InpMinUpperWickShare > 1.0 ||
      InpMaxLowerWickShare < 0.0 || InpMaxLowerWickShare > 1.0 || InpMinUpperWickShare <= InpMaxLowerWickShare ||
      InpRoundShortSessionStartHour < 0 || InpRoundShortSessionStartHour > 23 || InpRoundShortSessionEndHour < 0 ||
      InpRoundShortSessionEndHour > 23 || InpRoundShortSessionStartHour == InpRoundShortSessionEndHour ||
      InpRoundShortMaxEma13DistanceAtr <= 0.0 || InpRoundShortMinLowerWickShare < 0.0 ||
      InpRoundShortMinLowerWickShare > 1.0 || InpRoundShortMaxUpperWickShare < 0.0 ||
      InpRoundShortMaxUpperWickShare > 1.0 || InpRoundShortMinLowerWickShare <= InpRoundShortMaxUpperWickShare ||
      InpRoundShortStopLossAtr <= 0.0 || InpRoundShortTargetRMultiple <= 0.0 || InpRoundShortMaxHoldBars < 1 ||
      InpRoundLooseMaxEma13DistanceAtr <= InpMaxEma13DistanceAtr || InpRoundLooseStopLossAtr <= 0.0 ||
      InpRoundLooseTargetRMultiple <= 0.0 || InpRoundLooseMaxHoldBars < 1 ||
      InpAdxPeriod <= 1 || InpEmaMaxAdx <= 0.0 || InpEmaSessionStartHour < 0 || InpEmaSessionStartHour > 23 ||
      InpEmaSessionEndHour < 0 || InpEmaSessionEndHour > 23 || InpEmaSessionStartHour == InpEmaSessionEndHour ||
      InpEmaMaxEma13DistanceAtr <= 0.0 || InpEmaMaxRet1 < -0.01 || InpEmaMaxRet1 > 0.01 ||
      InpEmaMinUpperWickShare < 0.0 || InpEmaMinUpperWickShare > 1.0 || InpEmaMaxLowerWickShare < 0.0 ||
      InpEmaMaxLowerWickShare > 1.0 || InpEmaMaxCloseLocation < 0.0 || InpEmaMaxCloseLocation > 1.0 ||
      InpEmaMinUpperWickShare <= InpEmaMaxLowerWickShare || InpEmaStopLossAtr <= 0.0 ||
      InpEmaTargetRMultiple <= 0.0 || InpEmaMaxHoldBars < 1 ||
      InpCompressionSessionStartHour < 0 || InpCompressionSessionStartHour > 23 || InpCompressionSessionEndHour < 0 ||
      InpCompressionSessionEndHour > 23 || InpCompressionSessionStartHour == InpCompressionSessionEndHour ||
      InpCompressionMaxAdx <= 0.0 || InpCompressionMaxEma13DistanceAtr <= 0.0 ||
      InpCompressionMinUpperWickShare < 0.0 || InpCompressionMinUpperWickShare > 1.0 ||
      InpCompressionMaxLowerWickShare < 0.0 || InpCompressionMaxLowerWickShare > 1.0 ||
      InpCompressionMinUpperWickShare <= InpCompressionMaxLowerWickShare ||
      InpCompressionStopLossAtr <= 0.0 || InpCompressionTargetRMultiple <= 0.0 || InpCompressionMaxHoldBars < 1 ||
      InpRsiPeriod < 2 || InpRsiOversold <= 0.0 || InpRsiOversold >= 100.0 || InpRsiSessionStartHour < 0 ||
      InpRsiSessionStartHour > 23 || InpRsiSessionEndHour < 0 || InpRsiSessionEndHour > 23 ||
      InpRsiSessionStartHour == InpRsiSessionEndHour || InpRsiMaxEma13DistanceAtr <= 0.0 ||
      InpRsiTouchBufferAtr < 0.0 || InpRsiMinCloseLocation < 0.0 || InpRsiMinCloseLocation > 1.0 ||
      InpRsiMinBodyAtr <= 0.0 || InpRsiMaxLowerWickShare < 0.0 || InpRsiMaxLowerWickShare > 1.0 ||
      InpRsiStopLossAtr <= 0.0 || InpRsiTargetRMultiple <= 0.0 || InpRsiMaxHoldBars < 1 ||
      InpBreakoutSessionStartHour < 0 || InpBreakoutSessionStartHour > 23 || InpBreakoutSessionEndHour < 0 ||
      InpBreakoutSessionEndHour > 23 || InpBreakoutSessionStartHour == InpBreakoutSessionEndHour ||
      InpBreakoutLookbackBars <= 0 || InpBreakoutMidpointDistanceAtr <= 0.0 || InpBreakoutTouchToleranceAtr < 0.0 ||
      InpBreakoutRetestBufferAtr < 0.0 || InpBreakoutRetestDelayBars < 1 || InpBreakoutMinCloseLocation < 0.0 ||
      InpBreakoutMinCloseLocation > 1.0 || InpBreakoutMinBodyAtr <= 0.0 || InpBreakoutMinBodyToRange <= 0.0 ||
      InpBreakoutMinBodyToRange > 1.0 || InpBreakoutMaxToEma13Atr <= 0.0 ||
      InpBreakoutMinRetestCloseLocation < 0.0 || InpBreakoutMinRetestCloseLocation > 1.0 ||
      InpBreakoutMaxRetestDepthAtr < 0.0 || InpBreakoutStopLossAtr <= 0.0 ||
      InpBreakoutTargetRMultiple <= 0.0 || InpBreakoutMaxHoldBars < 1 ||
      InpDowSessionStartHour < 0 || InpDowSessionStartHour > 23 || InpDowSessionEndHour < 0 ||
      InpDowSessionEndHour > 23 || InpDowSessionStartHour == InpDowSessionEndHour ||
      InpDowPivotSpan <= 0 || InpDowTrendScanBars <= 20 ||
      InpDowMinBreachAtr < 0.0 || InpDowMaxBreachAtr < InpDowMinBreachAtr ||
      InpDowMinCloseLocation < 0.0 || InpDowMinCloseLocation > 1.0 ||
      InpDowMinLowerWickShare < 0.0 || InpDowMinLowerWickShare > 1.0 ||
      InpDowMaxUpperWickShare < 0.0 || InpDowMaxUpperWickShare > 1.0 ||
      InpDowStopBufferAtr < 0.0 || InpDowTargetBufferAtr < 0.0 ||
      InpDowMinTargetRMultiple <= 0.0 || InpDowMaxHoldBars < 1 ||
      InpRangeSessionStartHour < 0 || InpRangeSessionStartHour > 23 || InpRangeSessionEndHour < 0 ||
      InpRangeSessionEndHour > 23 || InpRangeSessionStartHour == InpRangeSessionEndHour ||
      InpRangeLookbackBars < 5 || InpRangeAdxPeriod < 2 || InpRangeMaxAdx <= 0.0 ||
      InpRangeAtrPeriod < 2 || InpRangeMaxWidthAtrMultiple <= 0.0 ||
      InpRangeMinBreachAtr < 0.0 || InpRangeMaxBreachAtr < InpRangeMinBreachAtr ||
      InpRangeMinCloseLocation < 0.0 || InpRangeMinCloseLocation > 1.0 ||
      InpRangeMinLowerWickShare < 0.0 || InpRangeMinLowerWickShare > 1.0 ||
      InpRangeMaxUpperWickShare < 0.0 || InpRangeMaxUpperWickShare > 1.0 ||
      InpRangeStopBufferAtr < 0.0 || InpRangeTargetBufferAtr < 0.0 ||
      InpRangeMinTargetRMultiple <= 0.0 || InpRangeMaxHoldBars < 1 ||
      InpFractalSessionStartHour < 0 || InpFractalSessionStartHour > 23 || InpFractalSessionEndHour < 0 ||
      InpFractalSessionEndHour > 23 || InpFractalSessionStartHour == InpFractalSessionEndHour ||
      InpFractalPivotSpan <= 0 || InpFractalScanBars <= 20 || InpFractalMidEMAPeriod <= InpFastEMAPeriod ||
      InpFractalSlowEMAPeriod <= InpFractalMidEMAPeriod || InpFractalStochKPeriod < 2 ||
      InpFractalStochDPeriod < 1 || InpFractalStochSlowing < 1 ||
      InpFractalStochBuyLevel <= 0.0 || InpFractalStochBuyLevel >= 100.0 ||
      InpFractalStopBufferAtr < 0.0 || InpFractalTargetBufferAtr < 0.0 ||
      InpFractalMinTargetRMultiple <= 0.0 || InpFractalMaxHoldBars < 1 ||
      InpStopLossAtr <= 0.0 || InpTargetRMultiple <= 0.0 || InpMaxHoldBars < 1 ||
      InpMaxOpenPositions < 1 || InpRiskPercent <= 0.0 ||
      InpDistanceATRPeriod<2 || InpDeviationAtr<0.0 || InpRiskPercent>100.0 ||
      InpDailyLossCapPercent<=0.0 || InpDailyLossCapPercent>=100.0 ||
      InpEquityDrawdownCapPercent < 0.0 || InpMaxTradesPerDay < 0 || InpMaxSpreadAtr <= 0.0 || InpMagicNumber <= 0 ||
      InpStatusHeartbeatSeconds < 0 || InpEquityDrawdownCapPercent>=100.0
   )
      return INIT_PARAMETERS_INCORRECT;

   if(!ParseWeekdays(runtimeAllowedWeekdays))
      return INIT_PARAMETERS_INCORRECT;
   if(!SymbolInfoInteger(runtimeSymbol, SYMBOL_SELECT))
      if(!SymbolSelect(runtimeSymbol, true))
         return INIT_FAILED;

   distanceAtrHandle=iATR(runtimeSymbol,InpSignalTimeframe,InpDistanceATRPeriod);
   fastEmaHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   slowEmaHandle = iMA(runtimeSymbol, InpSignalTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   adxHandle = iADX(runtimeSymbol, InpSignalTimeframe, InpAdxPeriod);
   rsiHandle = iRSI(runtimeSymbol, InpSignalTimeframe, InpRsiPeriod, PRICE_CLOSE);
   dowFastEmaHandle = iMA(runtimeSymbol, InpDowSignalTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   dowSlowEmaHandle = iMA(runtimeSymbol, InpDowSignalTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   rangeFastEmaHandle = iMA(runtimeSymbol, InpRangeSignalTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   rangeSlowEmaHandle = iMA(runtimeSymbol, InpRangeSignalTimeframe, InpSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   rangeAdxHandle = iADX(runtimeSymbol, InpRangeSignalTimeframe, InpRangeAdxPeriod);
   rangeAtrHandle = iATR(runtimeSymbol, InpRangeSignalTimeframe, InpRangeAtrPeriod);
   fractalFastEmaHandle = iMA(runtimeSymbol, InpFractalSignalTimeframe, InpFastEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   fractalMidEmaHandle = iMA(runtimeSymbol, InpFractalSignalTimeframe, InpFractalMidEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   fractalSlowEmaHandle = iMA(runtimeSymbol, InpFractalSignalTimeframe, InpFractalSlowEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   fractalStochHandle = iStochastic(runtimeSymbol, InpFractalSignalTimeframe, InpFractalStochKPeriod, InpFractalStochDPeriod,
                                    InpFractalStochSlowing, MODE_SMA, STO_LOWHIGH);
   if(distanceAtrHandle == INVALID_HANDLE || fastEmaHandle == INVALID_HANDLE || slowEmaHandle == INVALID_HANDLE || adxHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE ||
      dowFastEmaHandle == INVALID_HANDLE || dowSlowEmaHandle == INVALID_HANDLE ||
      rangeFastEmaHandle == INVALID_HANDLE || rangeSlowEmaHandle == INVALID_HANDLE ||
      rangeAdxHandle == INVALID_HANDLE || rangeAtrHandle == INVALID_HANDLE ||
      fractalFastEmaHandle == INVALID_HANDLE || fractalMidEmaHandle == INVALID_HANDLE ||
      fractalSlowEmaHandle == INVALID_HANDLE || fractalStochHandle == INVALID_HANDLE)
      return INIT_FAILED;

   trade.SetExpertMagicNumber((ulong)InpMagicNumber);
   trade.SetAsyncMode(false);
   if(!trade.SetTypeFillingBySymbol(runtimeSymbol)) return INIT_FAILED;
   UpdateDailyAnchor();
   if(!RefreshDailyTradeCount()) return INIT_FAILED;
   ReconcileUncertainSend();

   if(InpEnableTelemetry && !OpenTelemetryFile())
      Print("Telemetry file could not be opened. Continuing without telemetry.");

   if((runtimeOperatorControlEnabled || runtimeStatusSnapshotEnabled) && InpStatusHeartbeatSeconds > 0)
     {
      EventSetTimer(InpStatusHeartbeatSeconds);
      timerStarted = true;
     }

   RefreshOperatorMode();
   WriteStatusSnapshot();
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   FlushDailySummary(TimeCurrent(), "deinit");
   WriteStatusSnapshot();
   if(timerStarted)
     {
      EventKillTimer();
      timerStarted = false;
     }
   CloseTelemetryFile();
   if(funnelHandle!=INVALID_HANDLE) FileClose(funnelHandle);
   SaveRiskState();
   if(PersistRiskState()) GlobalVariablesFlush();
   if(distanceAtrHandle!=INVALID_HANDLE) IndicatorRelease(distanceAtrHandle);
   if(fastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(fastEmaHandle);
   if(slowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(slowEmaHandle);
   if(adxHandle != INVALID_HANDLE)
      IndicatorRelease(adxHandle);
   if(rsiHandle != INVALID_HANDLE)
      IndicatorRelease(rsiHandle);
   if(dowFastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(dowFastEmaHandle);
   if(dowSlowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(dowSlowEmaHandle);
   if(rangeFastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(rangeFastEmaHandle);
   if(rangeSlowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(rangeSlowEmaHandle);
   if(rangeAdxHandle != INVALID_HANDLE)
      IndicatorRelease(rangeAdxHandle);
   if(rangeAtrHandle != INVALID_HANDLE)
      IndicatorRelease(rangeAtrHandle);
   if(fractalFastEmaHandle != INVALID_HANDLE)
      IndicatorRelease(fractalFastEmaHandle);
   if(fractalMidEmaHandle != INVALID_HANDLE)
      IndicatorRelease(fractalMidEmaHandle);
   if(fractalSlowEmaHandle != INVALID_HANDLE)
      IndicatorRelease(fractalSlowEmaHandle);
   if(fractalStochHandle != INVALID_HANDLE)
      IndicatorRelease(fractalStochHandle);
  }

void OnTimer()
  {
   UpdateDailyAnchor();
   UpdateEquityPeak();
   RefreshOperatorMode();
   if(operatorMode == "flatten")
      FlattenManagedPositions("operator_flatten_timer");
   WriteStatusSnapshot();
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

void OnTick()
  {
   UpdateDailyAnchor();
   UpdateEquityPeak();
   RefreshOperatorMode();
   if(operatorMode == "flatten")
      FlattenManagedPositions("operator_flatten");

   ReconcileUncertainSend();
   bool dailyBlocked=IsDailyLossCapBlocked();
   bool equityBlocked=IsEquityDrawdownBlocked();
   if(dailyBlocked && InpFlattenOnDailyLossCap) FlattenManagedPositions("daily_loss_cap_tick");
   if(equityBlocked && InpFlattenOnEquityDrawdownCap) FlattenManagedPositions("equity_drawdown_cap_tick");

   datetime barTime = 0;
   bool newMainBar = IsNewBar(barTime);
   datetime dowBarTime = 0;
   bool newDowBar = false;
   if(InpEnableDowSweepBucket)
      newDowBar = IsNewBarForTimeframe(InpDowSignalTimeframe, lastDowBarTime, dowBarTime);
   datetime rangeBarTime = 0;
   bool newRangeBar = false;
   if(InpEnableRangeReclaimBucket || InpEnableRangeShortBucket)
      newRangeBar = IsNewBarForTimeframe(InpRangeSignalTimeframe, lastRangeBarTime, rangeBarTime);
   datetime fractalBarTime = 0;
   bool newFractalBar = false;
   if(InpEnableFractalTrendBucket)
      newFractalBar = IsNewBarForTimeframe(InpFractalSignalTimeframe, lastFractalBarTime, fractalBarTime);
   if(!newMainBar && !newDowBar && !newRangeBar && !newFractalBar)
      return;

   if(CountManagedPositions() > 0)
      ManageOpenPosition();

   WriteStatusSnapshot();

   // Record raw signals even when an execution gate rejects them.
   if(dailyBlocked) dailyBlockedDailyLoss++;
   if(equityBlocked) dailyBlockedEquityCap++;
   if(!RefreshDailyTradeCount()) return;

   int baseOpenCount = CountManagedPositions();
   int pendingOpenCount = 0;

   if(newMainBar)
     {
      MqlRates rates[];
      double fastEma[];
      double slowEma[];
      double adxValues[];
      double rsiValues[];
      roundDecision="DATA_UNAVAILABLE";
      if(LoadSignalWindow(rates, fastEma, slowEma, adxValues, rsiValues, 260))
        {
         SignalBucket buckets[7];
         int bucketCount = 0;
         bool roundSignal=EvaluateRoundSignal(rates,fastEma,slowEma);
         bool executionGate=CanOpenAnotherTrade(barTime);
         RecordFunnel(barTime,roundSignal,executionGate);
         if(roundSignal) buckets[bucketCount++] = SIGNAL_ROUND;
         if(EvaluateRoundShortSignal(rates, fastEma, slowEma))
            buckets[bucketCount++] = SIGNAL_ROUND_SHORT;
         if(EvaluateEmaSignal(rates, fastEma, slowEma, adxValues))
            buckets[bucketCount++] = SIGNAL_EMA;
         if(EvaluateCompressionSignal(rates, fastEma, slowEma, adxValues))
            buckets[bucketCount++] = SIGNAL_COMPRESSION;
         if(EvaluateRsiSignal(rates, fastEma, slowEma, rsiValues))
            buckets[bucketCount++] = SIGNAL_RSI;
         if(EvaluateBreakoutSignal(rates, fastEma, slowEma))
            buckets[bucketCount++] = SIGNAL_BREAKOUT;
         if(EvaluateRoundLooseSignal(rates, fastEma, slowEma))
            buckets[bucketCount++] = SIGNAL_ROUND_LOOSE;

         for(int i = 0; executionGate && i < bucketCount; ++i)
           {
            SignalBucket bucket = buckets[i];
            if(InpMaxTradesPerDay > 0 && dailyTradeCount + pendingOpenCount >= InpMaxTradesPerDay)
               break;
            if(!CanOpenBucketTrade(bucket, baseOpenCount, pendingOpenCount))
               continue;
            if(OpenPosition(bucket))
               pendingOpenCount++;
           }
        }
     }

   if(newDowBar && CanOpenAnotherTrade(dowBarTime))
     {
      if(InpMaxTradesPerDay <= 0 || dailyTradeCount + pendingOpenCount < InpMaxTradesPerDay)
        {
         MqlRates envRates[];
         double envFastEma[];
         double envSlowEma[];
         double envAdxValues[];
         double envRsiValues[];
         MqlRates dowRates[];
         double dowFastEma[];
         double dowSlowEma[];
         if(LoadSignalWindow(envRates, envFastEma, envSlowEma, envAdxValues, envRsiValues, 260) &&
            LoadDowSignalWindow(dowRates, dowFastEma, dowSlowEma, 220))
           {
            if(CanOpenBucketTrade(SIGNAL_DOW_SWEEP, baseOpenCount, pendingOpenCount) &&
               EvaluateDowSweepSignal(envRates, envFastEma, envSlowEma, dowRates, dowFastEma, dowSlowEma))
              {
               if(OpenPosition(SIGNAL_DOW_SWEEP))
                  pendingOpenCount++;
              }
           }
        }
     }

   if(newRangeBar && CanOpenAnotherTrade(rangeBarTime))
     {
      if(InpMaxTradesPerDay <= 0 || dailyTradeCount + pendingOpenCount < InpMaxTradesPerDay)
        {
         MqlRates envRates[];
         double envFastEma[];
         double envSlowEma[];
         double envAdxValues[];
         double envRsiValues[];
         MqlRates rangeRates[];
         double rangeFastEma[];
         double rangeSlowEma[];
         double rangeAdx[];
         double rangeAtr[];
         if(LoadSignalWindow(envRates, envFastEma, envSlowEma, envAdxValues, envRsiValues, 260) &&
            LoadRangeSignalWindow(rangeRates, rangeFastEma, rangeSlowEma, rangeAdx, rangeAtr, 220))
           {
            if(CanOpenBucketTrade(SIGNAL_RANGE_RECLAIM, baseOpenCount, pendingOpenCount) &&
               EvaluateRangeReclaimSignal(envRates, envFastEma, envSlowEma, rangeRates, rangeFastEma, rangeSlowEma, rangeAdx, rangeAtr))
              {
               if(OpenPosition(SIGNAL_RANGE_RECLAIM))
                  pendingOpenCount++;
              }
            if(CanOpenBucketTrade(SIGNAL_RANGE_RECLAIM_SHORT, baseOpenCount, pendingOpenCount) &&
               EvaluateRangeReclaimShortSignal(envRates, envFastEma, envSlowEma, rangeRates, rangeFastEma, rangeSlowEma, rangeAdx, rangeAtr))
              {
               if(OpenPosition(SIGNAL_RANGE_RECLAIM_SHORT))
                  pendingOpenCount++;
              }
           }
        }
     }

   if(newFractalBar && CanOpenAnotherTrade(fractalBarTime))
     {
      if(InpMaxTradesPerDay <= 0 || dailyTradeCount + pendingOpenCount < InpMaxTradesPerDay)
        {
         MqlRates envRates[];
         double envFastEma[];
         double envSlowEma[];
         double envAdxValues[];
         double envRsiValues[];
         MqlRates fractalRates[];
         double fractalFastEma[];
         double fractalMidEma[];
         double fractalSlowEma[];
         double stochK[];
         double stochD[];
         if(LoadSignalWindow(envRates, envFastEma, envSlowEma, envAdxValues, envRsiValues, 260) &&
            LoadFractalSignalWindow(fractalRates, fractalFastEma, fractalMidEma, fractalSlowEma, stochK, stochD, 220))
           {
            if(CanOpenBucketTrade(SIGNAL_FRACTAL_TREND, baseOpenCount, pendingOpenCount) &&
               EvaluateFractalTrendSignal(envRates, envFastEma, envSlowEma, fractalRates, fractalFastEma, fractalMidEma, fractalSlowEma, stochK, stochD))
              {
               if(OpenPosition(SIGNAL_FRACTAL_TREND))
                  pendingOpenCount++;
              }
           }
        }
     }
  }
