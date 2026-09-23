// Runs the actual EA functions with deterministic broker responses.
// OrderSend is replaced at preprocessing time: this script cannot send real orders.
int qa_failures=0,qa_checks=0,qa_sends=0;
double qa_equity=10000,qa_margin=10000,qa_ask=151.0;
long qa_stops=10;
bool qa_reject_attached=false,qa_timeout=false;
bool qa_false_zero=false,qa_true_zero=false,qa_position=false,qa_reject_protection=false;
double qa_position_sl=0,qa_position_tp=0;
bool qa_order=false;
datetime qa_order_placed=0;
MqlTradeRequest qa_request;
datetime QANow() { return D'2025.03.03 12:00'; }
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
   if(property==ORDER_MAGIC) return 260915501;
   if(property==ORDER_TYPE) return ORDER_TYPE_BUY_LIMIT;
   return (long)qa_order_placed;
}
long QAPositionInteger(const ENUM_POSITION_PROPERTY_INTEGER property)
{
   if(property==POSITION_MAGIC) return 260915501;
   return property==POSITION_TYPE ? POSITION_TYPE_BUY : 88;
}
string QAPositionString(const ENUM_POSITION_PROPERTY_STRING property) { return "USDJPY"; }
double QAPositionDouble(const ENUM_POSITION_PROPERTY_DOUBLE property)
{
   if(property==POSITION_SL) return qa_position_sl;
   if(property==POSITION_TP) return qa_position_tp;
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
   if(property==SYMBOL_ORDER_MODE) return SYMBOL_ORDER_LIMIT|SYMBOL_ORDER_SL|SYMBOL_ORDER_TP;
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
#define OnInit HFQAInit
#define OnTick HFQATick
#define OnDeinit HFQADeinit
#define OnTradeTransaction HFQATransaction
#include "../../Experts/USDJPY_M1_M5_HL_Fib50_Long.mq5"
#undef OnInit
#undef OnTick
#undef OnDeinit
#undef OnTradeTransaction

void Assert(const bool condition,const string label)
{
   qa_checks++;
   if(!condition) qa_failures++;
   Print(condition ? "PASS " : "FAIL ",label);
}
void Pivot(SSPivot &p,const datetime t,const datetime confirmed,const double price_value,const bool is_high)
{
   ZeroMemory(p); p.bar_time=t; p.confirmed_time=confirmed; p.price=price_value; p.high=is_high;
}

void OnStart()
{
   SSPivot p[]; ArrayResize(p,4);
   Pivot(p[0],100,200,149,false);
   Pivot(p[1],300,400,151,true);
   Pivot(p[2],500,600,150,false);
   Pivot(p[3],650,750,152,true);
   HFStructure s; string why;
   Assert(!HFBuild(p,599,s,why),"unconfirmed M5 low unavailable");
   Assert(HFBuild(p,600,s,why),"two confirmed lows form HL");
   Assert(s.reference_high.price==151,"reference fixed at low confirmation");
   Assert(HFBuild(p,800,s,why) && s.reference_high.price==151,"later confirmed M5 high does not move reference");
   MqlRates previous,bar; ZeroMemory(previous); ZeroMemory(bar);
   previous.close=150.9; bar.open=150.9; bar.high=151.1; bar.time=599;
   Assert(!HFCross(previous,bar,s),"pre-confirmation breakout rejected");
   bar.time=600;
   Assert(HFCross(previous,bar,s),"bar beginning at confirmation can cross afterwards");
   bar.high=151;
   Assert(!HFCross(previous,bar,s),"equal high is not breakout");
   bar.high=151.2; bar.open=151.1; previous.close=151.1;
   Assert(!HFCross(previous,bar,s),"already above level is not a new cross");
   previous.close=150.9;
   Assert(HFCross(previous,bar,s),"gap crossing from below accepted");
   s.cross_time=660;
   SSPivot candidate; Pivot(candidate,660,840,151.2,true);
   Assert(!HFEligibleHigh(candidate,s,839),"M1 right confirmation still open");
   Assert(HFEligibleHigh(candidate,s,840),"confirmed post-cross M1 high accepted");
   Assert(!HFEligibleHigh(candidate,s,900),"old confirmed M1 high not replayed later");
   candidate.bar_time=599;
   Assert(!HFEligibleHigh(candidate,s,840),"historical M1 high rejected");
   candidate.bar_time=660; candidate.ambiguous=true;
   Assert(!HFEligibleHigh(candidate,s,840),"ambiguous M1 high rejected");
   p[2].price=149;
   Assert(!HFBuild(p,800,s,why) && why=="NOT_HIGHER_LOW","equal M5 lows rejected");
   p[2].price=148;
   Assert(!HFBuild(p,800,s,why),"lower low rejected");
   p[2].price=150; p[2].ambiguous=true;
   Assert(!HFBuild(p,800,s,why),"ambiguous M5 structure rejected");
   p[2].ambiguous=false; HFBuild(p,800,setup,why);
   Pivot(setup.breakout_high,660,840,151,true);
   setup.cross_time=660;
   Assert(MakePlan(),"valid buy limit plan");
   Assert(MathAbs(plan.entry-150.5)<0.000001 && MathAbs(plan.sl-149.99)<0.000001,"50 percent entry and 10 point SL buffer");
   Assert(MathAbs(plan.tp-151.112)<0.000001,"fixed 1.2R target");
   Assert(plan.loss<=100 && plan.loss>96,"account currency loss within one percent after lot floor");
   Assert(MathAbs(plan.volume-0.29)<0.000001,"USDJPY USD-account conversion and volume step");
   qa_equity=1;
   Assert(!MakePlan() && reason=="MIN_LOT_EXCEEDS_ONE_PERCENT","minimum lot never rounded up past risk");
   qa_equity=10000; qa_margin=1;
   Assert(!MakePlan() && reason=="INSUFFICIENT_MARGIN","insufficient margin blocks order");
   qa_margin=10000; qa_ask=150.4;
   Assert(!MakePlan() && reason=="LIMIT_NOT_BELOW_ASK_OR_BROKER_DISTANCE","never replace invalid limit with market entry");
   qa_ask=153; qa_stops=2000;
   Assert(!MakePlan() && reason=="BROKER_STOPS_DISTANCE","structurally invalid stops do not trigger naked fallback");
   qa_stops=10; qa_ask=151;
   journal=FileOpen("hf_unit_journal.csv",FILE_WRITE|FILE_READ|FILE_CSV|FILE_ANSI,',');
   Assert(journal!=INVALID_HANDLE,"persistent journal opens");
   prefix="HF_QA_";
   Assert(Place(),"normal pending placement succeeds");
   Assert(qa_request.type==ORDER_TYPE_BUY_LIMIT && qa_request.action==TRADE_ACTION_PENDING && qa_request.sl>0 && qa_request.tp>0,"Buy Limit includes SL TP");
   Assert(qa_request.expiration==QANow()+900 && last_fill==0,"15 minute expiry and no cooldown on placement");
   datetime consumed=used_structure; double saved_sl=plan.sl;
   FileSeek(journal,0,SEEK_SET); used_structure=0; ZeroMemory(plan);
   Assert(LoadJournal() && used_structure==consumed && plan.sl==saved_sl,"restart restores consumed structure and protection plan");
   Assert(plan.reference_high.price==151 && plan.new_low.bar_time==500 && plan.breakout_high.bar_time==660,"restart restores marker anchors and original times");
   Assert(setup.new_low.bar_time<=used_structure,"restored structure remains consumed");
   qa_reject_attached=true;
   Assert(Place() && qa_request.sl==0 && qa_request.tp==0 && plan.sl==saved_sl,"definitive invalid stops uses deferred path with stored protection");
   qa_position=true;
   Protect(88);
   Assert(qa_position_sl==plan.sl && qa_position_tp==plan.tp,"fill receives planned SL TP through actual protection function");
   qa_position_sl=0; qa_position_tp=0; qa_reject_protection=true;
   Protect(88);
   Assert(!qa_position && qa_request.position==88 && qa_request.type==ORDER_TYPE_SELL,"failed protection closes the existing long only");
   qa_reject_protection=false; qa_reject_attached=false;
   int before_zero=qa_sends; qa_false_zero=true;
   Assert(!Place() && qa_sends==before_zero,"false zero check does not submit order");
   qa_false_zero=false; qa_true_zero=true;
   Assert(Place(),"true zero successful tester check accepted");
   qa_true_zero=false; qa_timeout=true;
   int before=qa_sends;
   Assert(!Place() && qa_sends==before+1 && blocked,"timeout blocks and does not resend");
   cancel_latched=true; cancel_reason="M5_LOW_BROKEN"; last_fill=QANow()-300; Save();
   FileSeek(journal,0,SEEK_SET); blocked=false; cancel_latched=false; last_fill=0;
   Assert(LoadJournal() && blocked && cancel_latched && last_fill==QANow()-300,"restart restores cancellation block and fill cooldown");
   blocked=false; cancel_latched=false; qa_timeout=false;
   qa_order=true; qa_order_placed=QANow()-899;
   observed_order_count=1; observed_position_count=0; observed_order=42; observed_position=0;
   Manage();
   Assert(qa_order,"pending order survives at 899 seconds");
   qa_order_placed=QANow()-900;
   Manage();
   Assert(!qa_order && delete_reason=="EXPIRED_15_MINUTES","pending order canceled at 900 seconds");
   qa_order=true; qa_order_placed=QANow()-30; cancel_latched=false; qa_ask=149;
   Manage();
   Assert(!qa_order && delete_reason=="M5_LOW_BROKEN","tick-level low break cancels pending order");
   qa_order=true; cancel_latched=false; qa_ask=151; qa_position=true;
   qa_position_sl=plan.sl; qa_position_tp=plan.tp;
   observed_position_count=1; observed_position=88;
   Manage();
   Assert(!qa_order && delete_reason=="CANCEL_REMAINDER_AFTER_FILL","partial-fill remainder canceled");
   FileClose(journal); journal=INVALID_HANDLE;
   Print("HF_UNIT_RESULT checks=",qa_checks," failures=",qa_failures);
   int result_file=FileOpen("hf_unit_result.txt",FILE_WRITE|FILE_TXT);
   if(result_file!=INVALID_HANDLE) { FileWrite(result_file,"checks=",qa_checks," failures=",qa_failures); FileClose(result_file); }
}
