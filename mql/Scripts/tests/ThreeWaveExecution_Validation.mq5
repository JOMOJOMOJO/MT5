// Runs the actual EA functions with deterministic broker responses.
// OrderSend is replaced at preprocessing time: this script cannot send real orders.
int qa_failures=0,qa_checks=0,qa_sends=0;
double qa_equity=10000,qa_margin=10000,qa_ask=151.0;
long qa_stops=10;
bool qa_reject_attached=false,qa_timeout=false;
bool qa_false_zero=false,qa_true_zero=false,qa_position=false,qa_reject_protection=false;
double qa_position_sl=0,qa_position_tp=0,qa_position_entry=151,qa_position_volume=0.1;
bool qa_order=false;
datetime qa_order_placed=0;
MqlTradeRequest qa_request;
datetime qa_now=D'2025.03.03 12:00';
datetime QANow() { return qa_now; }
bool qa_history_visible=false,qa_history_deal=false,qa_history_order=false;
datetime qa_fill_time=0;
long qa_history_state=ORDER_STATE_CANCELED;
bool QAHistorySelect(const datetime from,const datetime to) { return true; }
int QAHistoryDealsTotal() { return qa_history_visible && qa_history_deal ? 1 : 0; }
ulong QAHistoryDealTicket(const int index) { return 55; }
string QAHistoryDealString(const ulong deal,const ENUM_DEAL_PROPERTY_STRING property) { return "USDJPY"; }
long QAHistoryDealInteger(const ulong deal,const ENUM_DEAL_PROPERTY_INTEGER property)
{
   if(property==DEAL_MAGIC) return 260922331;
   if(property==DEAL_ENTRY) return DEAL_ENTRY_IN;
   if(property==DEAL_TYPE) return DEAL_TYPE_BUY;
   if(property==DEAL_TIME) return qa_fill_time;
   return 42;
}
string QAHistoryOrderString(const ulong order,const ENUM_ORDER_PROPERTY_STRING property)
{ return qa_history_visible && qa_history_order ? "USDJPY" : ""; }
long QAHistoryOrderInteger(const ulong order,const ENUM_ORDER_PROPERTY_INTEGER property)
{ return property==ORDER_MAGIC ? 260922331 : qa_history_state; }
double QAHistoryOrderDouble(const ulong order,const ENUM_ORDER_PROPERTY_DOUBLE property) { return 0.1; }
double QADouble(const ENUM_ACCOUNT_INFO_DOUBLE property)
{ return property==ACCOUNT_EQUITY ? qa_equity : qa_margin; }
long QAInteger(const ENUM_ACCOUNT_INFO_INTEGER property)
{ return property==ACCOUNT_MARGIN_MODE ? ACCOUNT_MARGIN_MODE_RETAIL_HEDGING : 0; }
bool QAPositionSelect(const ulong ticket) { return qa_position && ticket==88; }
int QAOrdersTotal() { return qa_order ? 1 : 0; }
int QAPositionsTotal() { return qa_position ? 1 : 0; }
ulong QAOrderTicket(const int index) { return qa_order ? 42 : 0; }
ulong QAPositionTicket(const int index) { return qa_position ? 88 : 0; }
bool QAOrderSelect(const ulong ticket) { return qa_order && ticket==42; }
string QAOrderString(const ENUM_ORDER_PROPERTY_STRING property) { return "USDJPY"; }
double QAOrderDouble(const ENUM_ORDER_PROPERTY_DOUBLE property) { return property==ORDER_PRICE_OPEN ? 150.5 : 0.29; }
long QAOrderInteger(const ENUM_ORDER_PROPERTY_INTEGER property)
{
   if(property==ORDER_MAGIC) return 260922331;
   if(property==ORDER_TYPE) return ORDER_TYPE_BUY_LIMIT;
   return (long)qa_order_placed;
}
long QAPositionInteger(const ENUM_POSITION_PROPERTY_INTEGER property)
{
   if(property==POSITION_MAGIC) return 260922331;
   if(property==POSITION_IDENTIFIER) return 42;
   if(property==POSITION_TIME) return qa_now;
   return property==POSITION_TYPE ? POSITION_TYPE_BUY : 88;
}
string QAPositionString(const ENUM_POSITION_PROPERTY_STRING property) { return "USDJPY"; }
double QAPositionDouble(const ENUM_POSITION_PROPERTY_DOUBLE property)
{
   if(property==POSITION_SL) return qa_position_sl;
   if(property==POSITION_TP) return qa_position_tp;
   if(property==POSITION_PRICE_OPEN) return qa_position_entry;
   if(property==POSITION_VOLUME) return qa_position_volume;
   return 1;
}
double QASymbolDouble(const string symbol,const ENUM_SYMBOL_INFO_DOUBLE property)
{
   switch(property)
   {
      case SYMBOL_TRADE_TICK_SIZE: return 0.001;
      case SYMBOL_VOLUME_MIN: return 0.01;
      case SYMBOL_VOLUME_MAX: return 100;
      case SYMBOL_VOLUME_STEP: return 0.01;
      case SYMBOL_TRADE_CONTRACT_SIZE: return 100000;
      default: return 1;
   }
}
long QASymbolInteger(const string symbol,const ENUM_SYMBOL_INFO_INTEGER property)
{
   if(property==SYMBOL_TRADE_STOPS_LEVEL) return qa_stops;
   if(property==SYMBOL_ORDER_MODE) return SYMBOL_ORDER_MARKET|SYMBOL_ORDER_SL|SYMBOL_ORDER_TP;
   if(property==SYMBOL_EXPIRATION_MODE) return SYMBOL_EXPIRATION_SPECIFIED;
   return 0;
}
bool QATick(const string symbol,MqlTick &tick)
{ ZeroMemory(tick); tick.ask=qa_ask; tick.bid=qa_ask-0.01; return true; }
bool QAProfit(const ENUM_ORDER_TYPE type,const string symbol,const double volume,const double entry,const double exit_price,double &profit)
{ profit=volume*100000*(exit_price-entry)/exit_price; return true; }
bool QAMargin(const ENUM_ORDER_TYPE type,const string symbol,const double volume,const double price,double &margin)
{ margin=volume*1000; return true; }
bool QACheck(MqlTradeRequest &request,MqlTradeCheckResult &result)
{
   ZeroMemory(result);
   if(qa_false_zero || qa_true_zero) return qa_true_zero;
   if(qa_reject_attached && request.sl>0) { result.retcode=TRADE_RETCODE_INVALID_STOPS; return false; }
   result.retcode=TRADE_RETCODE_DONE; return true;
}
bool QASend(MqlTradeRequest &request,MqlTradeResult &result)
{
   qa_sends++; qa_request=request; ZeroMemory(result);
   if(request.action==TRADE_ACTION_REMOVE)
   { qa_order=false; result.retcode=TRADE_RETCODE_DONE; return true; }
   if(request.action==TRADE_ACTION_SLTP)
   {
      result.retcode=qa_reject_protection ? TRADE_RETCODE_INVALID_STOPS : TRADE_RETCODE_DONE;
      if(!qa_reject_protection) { qa_position_sl=request.sl; qa_position_tp=request.tp; }
      return !qa_reject_protection;
   }
   if(request.action==TRADE_ACTION_DEAL && request.position==88 && request.type==ORDER_TYPE_SELL)
   { qa_position=false; result.retcode=TRADE_RETCODE_DONE; return true; }
   result.retcode=qa_timeout ? TRADE_RETCODE_TIMEOUT : TRADE_RETCODE_PLACED;
   result.order=qa_timeout ? 0 : 42;
   return !qa_timeout;
}

#define TimeCurrent QANow
#define AccountInfoDouble QADouble
#define AccountInfoInteger QAInteger
#define PositionSelectByTicket QAPositionSelect
#define PositionGetInteger QAPositionInteger
#define PositionGetString QAPositionString
#define PositionGetDouble QAPositionDouble
#define PositionsTotal QAPositionsTotal
#define PositionGetTicket QAPositionTicket
#define OrdersTotal QAOrdersTotal
#define OrderGetTicket QAOrderTicket
#define OrderSelect QAOrderSelect
#define OrderGetString QAOrderString
#define OrderGetDouble QAOrderDouble
#define OrderGetInteger QAOrderInteger
#define SymbolInfoDouble QASymbolDouble
#define SymbolInfoInteger QASymbolInteger
#define SymbolInfoTick QATick
#define OrderCalcProfit QAProfit
#define OrderCalcMargin QAMargin
#define OrderCheck QACheck
#define OrderSend QASend
#define HistorySelect QAHistorySelect
#define HistoryDealsTotal QAHistoryDealsTotal
#define HistoryDealGetTicket QAHistoryDealTicket
#define HistoryDealGetString QAHistoryDealString
#define HistoryDealGetInteger QAHistoryDealInteger
#define HistoryOrderGetString QAHistoryOrderString
#define HistoryOrderGetInteger QAHistoryOrderInteger
#define HistoryOrderGetDouble QAHistoryOrderDouble
#define OnInit HFQAInit
#define OnTick HFQATick
#define OnDeinit HFQADeinit
#define OnTradeTransaction HFQATransaction
#include "../../Experts/USDJPY_M1_M5_3WaveIn3Wave_Long.mq5"
#undef OnInit
#undef OnTick
#undef OnDeinit
#undef OnTradeTransaction


void Assert(const bool ok,const string label)
{ qa_checks++; if(!ok) qa_failures++; Print(ok ? "PASS " : "FAIL ",label); }
void OnStart()
{
   M5Setup higher={}; M1Pattern lower={};
   higher.origin_low.price=149; lower.reversal_low.price=150;
   lower.hl.price=150.5; lower.ready_time=QANow()-60;
   FileDelete("tw_unit_journal.bin");
   journal=FileOpen("tw_unit_journal.bin",FILE_READ|FILE_WRITE|FILE_BIN);

   Assert(MakePlan(higher,lower),"market plan at current Ask");
   Assert(plan.entry==qa_ask && MathAbs(plan.sl-150.49)<1e-8,"Ask entry / Wave2 SL, no Fib50");
   Assert(plan.loss<=qa_equity*0.01,"final rounded lot loss <= Equity 1%");
   Assert(MathAbs(plan.tp-(plan.entry+(plan.entry-plan.sl)*1.2))<0.001,"default TP RR1.2");
   qa_equity=1; Assert(!MakePlan(higher,lower),"minimum lot oversizing rejected"); qa_equity=10000;
   qa_margin=1; Assert(!MakePlan(higher,lower),"insufficient margin rejected"); qa_margin=10000;
   qa_stops=1000; Assert(!MakePlan(higher,lower),"statically invalid stops rejected before naked fallback"); qa_stops=10;
   qa_false_zero=true; int sends=qa_sends;
   Assert(!Place(higher,lower) && qa_sends==sends,"false/zero OrderCheck cannot send"); qa_false_zero=false;
   qa_true_zero=true; Assert(Place(higher,lower),"true/zero OrderCheck accepted"); qa_true_zero=false;
   Assert(qa_request.action==TRADE_ACTION_DEAL && qa_request.type==ORDER_TYPE_BUY,"only market BUY entry");
   Assert(qa_request.sl>0 && qa_request.tp>0,"normal market order attaches SL/TP");
   Assert(last_fill==0,"send alone does not start cooldown");
   last_bar=QANow(); last_fill=QANow()-30; Save();
   double saved_sl=plan.sl; ZeroMemory(plan); last_bar=0; last_fill=0;
   FileSeek(journal,0,SEEK_SET);
   Assert(LoadJournal() && plan.sl==saved_sl && last_bar==QANow() && last_fill==QANow()-30,"journal restores consumed bar, protection and fill cooldown");
   qa_reject_attached=true; Assert(Place(higher,lower) && qa_request.sl==0 && qa_request.tp==0,"invalid attached stops exercise deferred path");
   qa_reject_attached=false; qa_position=true; qa_position_volume=plan.volume; qa_position_entry=plan.entry;
   Protect(88); Assert(qa_position_sl==plan.sl && qa_position_tp==plan.tp,"actual fill receives deferred protection");
   Assert(!plan.inflight && last_fill==qa_now,"owned position resolves fill before deal history becomes visible");
   qa_position_sl=0; qa_position_tp=0; qa_reject_protection=true;
   Protect(88); Assert(!qa_position && plan.emergency,"failed protection closes existing long and latches");
   qa_reject_protection=false; qa_position=true; plan.emergency=false; protected_volume=0;
   qa_position_entry=160; Protect(88);
   Assert(!qa_position && plan.emergency,"adverse fill exceeding budget exits rather than accepting oversized risk");
   qa_position=true; qa_position_sl=0; qa_position_tp=0; ZeroMemory(plan);
   Protect(88); Assert(!qa_position && blocked,"missing journal protection plan closes naked owned long");
   qa_timeout=true; blocked=false; Assert(!Place(higher,lower) && blocked,"uncertain send blocks further trading");
   qa_timeout=false; blocked=false; qa_position=false; qa_order=false;
   ZeroMemory(plan); plan.order=42; plan.placed=qa_now-120; plan.inflight=true;
   inventory_orders=0; inventory_positions=0; inventory_foreign=0;
   qa_history_visible=true; qa_history_deal=true; qa_fill_time=plan.placed+11;
   int prior_sends=qa_sends; Manage();
   Assert(!blocked && !plan.inflight && last_fill==qa_fill_time && qa_sends==prior_sends,
          "flat inventory with late history resolves before timeout without resending");
   qa_now++; qa_history_deal=false; qa_history_order=true;
   plan.inflight=true; plan.placed=qa_now-120; datetime cooldown_before=last_fill;
   Manage();
   Assert(!blocked && !plan.inflight && last_fill==cooldown_before,"cancelled unfilled order resolves without starting cooldown");
   qa_now++; qa_history_visible=false; plan.inflight=true; plan.placed=qa_now-120;
   Manage();
   Assert(blocked && plan.inflight && qa_sends==prior_sends,"genuinely unknown order stays blocked and is never resent");
   ulong bytes=FileSize(journal); qa_now++; Manage();
   Assert(FileSize(journal)==bytes,"persistent unresolved state does not append journal on every tick");
   FileClose(journal); journal=INVALID_HANDLE;
   Print("TW_EXEC_UNIT_RESULT checks=",qa_checks," failures=",qa_failures);
}
