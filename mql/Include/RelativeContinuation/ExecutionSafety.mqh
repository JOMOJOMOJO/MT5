#ifndef RELATIVE_CONTINUATION_EXECUTION_SAFETY_MQH
#define RELATIVE_CONTINUATION_EXECUTION_SAFETY_MQH
bool PersistRiskState()
  {
   return !(bool)MQLInfoInteger(MQL_TESTER) && riskStatePrefix != "";
  }

void SaveRiskState()
  {
   if(!PersistRiskState()) return;
   GlobalVariableSet(riskStatePrefix+"day",(double)currentDayStart);
   GlobalVariableSet(riskStatePrefix+"equity",dailyStartEquity);
   GlobalVariableSet(riskStatePrefix+"balance",dailyStartBalance);
   GlobalVariableSet(riskStatePrefix+"peak",equityPeak);
   GlobalVariableSet(riskStatePrefix+"daily",dailyCapLatched ? 1.0 : 0.0);
   GlobalVariableSet(riskStatePrefix+"dd",equityCapLatched ? 1.0 : 0.0);
   GlobalVariableSet(riskStatePrefix+"send",uncertainSend ? (double)uncertainSince : 0.0);
   GlobalVariableSet(riskStatePrefix+"order",(double)uncertainOrder);
  }

void RestoreRiskState()
  {
   if(PersistRiskState())
     {
      if(GlobalVariableCheck(riskStatePrefix+"peak"))
         equityPeak = MathMax(equityPeak,GlobalVariableGet(riskStatePrefix+"peak"));
      equityCapLatched = GlobalVariableGet(riskStatePrefix+"dd") > 0.0;
      if((datetime)GlobalVariableGet(riskStatePrefix+"day") == currentDayStart)
        {
         dailyStartEquity = GlobalVariableGet(riskStatePrefix+"equity");
         dailyStartBalance = GlobalVariableGet(riskStatePrefix+"balance");
         dailyCapLatched = GlobalVariableGet(riskStatePrefix+"daily") > 0.0;
        }
      uncertainSince = (datetime)GlobalVariableGet(riskStatePrefix+"send");
      uncertainSend = uncertainSince > 0;
      uncertainOrder = (ulong)GlobalVariableGet(riskStatePrefix+"order");
     }
   SaveRiskState();
  }

bool RefreshDailyTradeCount()
  {
   if(!HistorySelect(currentDayStart,TimeCurrent())) return false;
   ulong ids[];
   for(int i=0;i<HistoryDealsTotal();i++)
     {
      ulong deal=HistoryDealGetTicket(i);
      if(HistoryDealGetString(deal,DEAL_SYMBOL)!=runtimeSymbol ||
         HistoryDealGetInteger(deal,DEAL_MAGIC)!=InpMagicNumber ||
         HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_IN) continue;
      ulong order= (ulong)HistoryDealGetInteger(deal,DEAL_ORDER);
      bool found=false;
      for(int j=0;j<ArraySize(ids);j++) if(ids[j]==order) { found=true; break; }
      if(!found) { int n=ArraySize(ids); ArrayResize(ids,n+1); ids[n]=order; }
     }
   dailyTradeCount=ArraySize(ids); // one entry order, not one partial fill
   return true;
  }

bool HasPendingManagedOrder()
  {
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      ulong id=OrderGetTicket(i);
      if(id>0 && OrderGetString(ORDER_SYMBOL)==runtimeSymbol &&
         OrderGetInteger(ORDER_MAGIC)==InpMagicNumber) return true;
     }
   return false;
  }

void ReconcileUncertainSend()
  {
   if(!uncertainSend || HasPendingManagedOrder()) return;
   bool resolved=CountManagedPositions()>0;
   if(!resolved && HistorySelect(uncertainSince-60,TimeCurrent()))
     {
      for(int i=HistoryDealsTotal()-1;i>=0;i--)
        {
         ulong d=HistoryDealGetTicket(i);
         if(HistoryDealGetString(d,DEAL_SYMBOL)==runtimeSymbol && HistoryDealGetInteger(d,DEAL_MAGIC)==InpMagicNumber &&
            HistoryDealGetInteger(d,DEAL_ENTRY)==DEAL_ENTRY_IN &&
            HistoryDealGetInteger(d,DEAL_TIME)>=uncertainSince) { resolved=true; break; }
        }
      if(!resolved && uncertainOrder>0 && HistoryOrderSelect(uncertainOrder))
        {
         ENUM_ORDER_STATE state=(ENUM_ORDER_STATE)HistoryOrderGetInteger(uncertainOrder,ORDER_STATE);
         resolved=(state==ORDER_STATE_CANCELED || state==ORDER_STATE_REJECTED || state==ORDER_STATE_EXPIRED);
        }
     }
   if(resolved) { uncertainSend=false; uncertainOrder=0; SaveRiskState(); Print("SEND_RECONCILED"); }
   // No evidence of acceptance or rejection: fail closed; never blindly retry.
  }

bool CheckTradeResult(bool apiResult, string operation)
  {
   uint rc=trade.ResultRetcode();
   bool filled=apiResult && (rc==TRADE_RETCODE_DONE || rc==TRADE_RETCODE_DONE_PARTIAL);
   if(!filled) PrintFormat("TRADE_RESULT operation=%s retcode=%u order=%I64u deal=%I64u description=%s",
                          operation,rc,trade.ResultOrder(),trade.ResultDeal(),trade.ResultRetcodeDescription());
   return filled;
  }

bool RecordRoundDecision(string reason, bool passed=false)
  {
   roundDecision=reason;
   return passed;
  }

void RecordFunnel(datetime barTime, bool signal, bool gate)
  {
   if(!InpWriteFunnel) return;
   if(funnelHandle==INVALID_HANDLE)
     {
      funnelHandle=FileOpen(runtimeTelemetryFileName+".funnel.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,';');
      if(funnelHandle==INVALID_HANDLE) return;
      FileWrite(funnelHandle,"time","signal","signal_reason","entry_gate","spread_atr","spread_allowed",
                "atr","positions","daily_entries","daily_cap","equity_cap","uncertain_send");
     }
   FileWrite(funnelHandle,TimeToString(barTime,TIME_DATE|TIME_SECONDS),signal,roundDecision,gate,
             GetCurrentSpreadAtr(),IsSpreadAllowed(),GetDistanceUnit(),CountManagedPositions(),dailyTradeCount,
             dailyCapLatched,equityCapLatched,uncertainSend);
   // Buffered; close flushes. Avoid per-bar forced disk sync in optimization.
  }
#endif
