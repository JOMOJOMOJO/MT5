// RELATIVE_CONTINUATION_MODULE_BEGIN TelemetryControl
#ifndef RELATIVE_CONTINUATION_TELEMETRYCONTROL_MQH
#define RELATIVE_CONTINUATION_TELEMETRYCONTROL_MQH
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
             0,
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

void RegisterEntryDeal(datetime dealTime, string side, double price, double volume)
  {
   UpdateDailyAnchor();
   RefreshDailyTradeCount();
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
  }

string ReadOperatorModeFromFile()
  {
   if(!runtimeOperatorControlEnabled || runtimeOperatorCommandFile == "")
      return "normal";

   int handle = FileOpen(runtimeOperatorCommandFile, FILE_TXT | FILE_READ | FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_COMMON | FILE_ANSI);
   if(handle == INVALID_HANDLE)
      return "normal";

   string command = "";
   if(!FileIsEnding(handle))
      command = FileReadString(handle);
   FileClose(handle);

   if(command == "")
      return "normal";
   if(StringCompare(command, "pause", false) == 0 || StringCompare(command, "pause_entries", false) == 0)
      return "pause";
   if(StringCompare(command, "flatten", false) == 0 ||
      StringCompare(command, "flatten_and_pause", false) == 0 ||
      StringCompare(command, "kill", false) == 0)
      return "flatten";
   return "normal";
  }

void RefreshOperatorMode()
  {
   string nextMode = ReadOperatorModeFromFile();
   if(nextMode == operatorMode)
      return;

   operatorMode = nextMode;
   PrintFormat("Operator mode changed to '%s'", operatorMode);
   LogTelemetryEvent(TimeCurrent(), "operator_mode", operatorMode, "", 0.0, 0.0, 0.0, runtimeOperatorCommandFile);
  }

bool AreOperatorEntriesBlocked()
  {
   return (operatorMode != "normal");
  }

string BoolText(bool value)
  {
   if(value)
      return "true";
   return "false";
  }

string DetermineEntryState()
  {
   if(operatorMode == "flatten")
      return "operator_flatten";
   if(operatorMode == "pause")
      return "operator_pause";
   if(IsDailyLossCapBlocked())
      return "daily_loss_cap";
   if(IsEquityDrawdownBlocked())
      return "equity_drawdown_cap";
   if(IsTradeCountBlocked())
      return "trade_cap";
   if(!InpAllowParallelBuckets && CountManagedPositions() > 0)
      return "position_open";
   if(InpMaxOpenPositions > 0 && CountManagedPositions() >= InpMaxOpenPositions)
      return "position_cap";

   datetime currentBar = iTime(runtimeSymbol, InpSignalTimeframe, 0);
   MqlDateTime ts;
   TimeToStruct(currentBar, ts);
   if(!IsAllowedWeekday(ts.day_of_week))
      return "weekday_blocked";
   if(!IsWithinActiveSession(currentBar))
      return "inactive_session";
   if(!IsSpreadAllowed())
      return "spread";
   return "ready";
  }

void WriteStatusSnapshot()
  {
   if(!runtimeStatusSnapshotEnabled || runtimeStatusFileName == "")
      return;

   int handle = FileOpen(runtimeStatusFileName, FILE_TXT | FILE_WRITE | FILE_COMMON | FILE_ANSI);
   if(handle == INVALID_HANDLE)
     {
      if(!statusSnapshotErrorLogged)
        {
         PrintFormat("Status snapshot open failed for '%s' (%d)", runtimeStatusFileName, GetLastError());
         statusSnapshotErrorLogged = true;
        }
      return;
     }

   statusSnapshotErrorLogged = false;
   string snapshot =
      "timestamp=" + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS) + "\r\n" +
      "symbol=" + runtimeSymbol + "\r\n" +
      "timeframe=" + EnumToString(InpSignalTimeframe) + "\r\n" +
      "operator_mode=" + operatorMode + "\r\n" +
      "entry_state=" + DetermineEntryState() + "\r\n" +
      "balance=" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\r\n" +
      "equity=" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "\r\n" +
      "equity_peak=" + DoubleToString(equityPeak, 2) + "\r\n" +
      "open_positions=" + IntegerToString(CountManagedPositions()) + "\r\n" +
      "daily_trades_opened=" + IntegerToString(dailyTradeCount) + "\r\n" +
      "daily_closed_trades=" + IntegerToString(dailyClosedTrades) + "\r\n" +
      "daily_entries_buy=" + IntegerToString(dailyEntriesBuy) + "\r\n" +
      "daily_entries_sell=" + IntegerToString(dailyEntriesSell) + "\r\n" +
      "consecutive_losses=" + IntegerToString(consecutiveLosses) + "\r\n" +
      "spread_atr=" + DoubleToString(GetCurrentSpreadAtr(), 2) + "\r\n" +
      "daily_loss_cap_blocked=" + BoolText(IsDailyLossCapBlocked()) + "\r\n" +
      "equity_drawdown_blocked=" + BoolText(IsEquityDrawdownBlocked()) + "\r\n" +
      "trade_cap_blocked=" + BoolText(IsTradeCountBlocked()) + "\r\n" +
      "telemetry_file=" + runtimeTelemetryFileName + "\r\n";

   FileWriteString(handle, snapshot);
   FileClose(handle);
  }

// RELATIVE_CONTINUATION_MODULE_END TelemetryControl
#endif
