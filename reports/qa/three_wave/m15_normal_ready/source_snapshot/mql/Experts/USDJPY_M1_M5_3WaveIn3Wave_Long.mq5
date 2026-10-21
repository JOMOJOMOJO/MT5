#property strict
#property version "1.05"
#property description "3x3 LONG EA with selectable READY or confirmed-HL retest entry."
#property tester_indicator "MultiTF_3WaveIn3Wave_Visualizer_Shared.ex5"
#property tester_indicator "ThreeWave_EMA_Display.ex5"
#include "../Include/ThreeWaveInputs.mqh"
#include "../Include/ThreeWaveStructure.mqh"
#include "../Include/M15EnvironmentDisplay.mqh"

enum StopMode { STOP_M1_WAVE2_LOW,STOP_M1_REVERSAL_LOW,STOP_M5_WAVE1_ORIGIN };
enum HLEntryMode { HL_ENTRY_READY=0, HL_ENTRY_CONFIRM=1, HL_ENTRY_RETEST=2 };
input HLEntryMode InpHLEntryMode=HL_ENTRY_RETEST;
input double InpHLNearFraction=0.25;
input ulong InpMagicNumber=260922331;
input StopMode InpStopMode=STOP_M1_REVERSAL_LOW;
input int InpSLBufferPoints=10;
input double InpRewardRisk=1.2;
input int InpCooldownMinutes=15;
input bool InpAllowDeferredProtection=true;
input bool InpShowMarkers=true;
input bool InpWriteCSV=true;
input bool InpVerifyIndicator=false; // Tester comparison only; does not gate or generate signals.
input bool InpTestDeferredProtection=false;
input bool InpShowEMAs=true; // Display only; periods are shared with the EMA entry filter.
input bool InpUseEMAFilter=true;
input bool InpEMARequireRising=true; // Strict rise of all three from shift 2 to shift 1.
input int InpEMAFastPeriod=20;
input int InpEMAMiddlePeriod=50;
input int InpEMASlowPeriod=100;
int ema_filter_handles[3]={INVALID_HANDLE,INVALID_HANDLE,INVALID_HANDLE};

bool EMAEntryAllowed(const datetime decision,string &result)
{
   if(!InpUseEMAFilter) { result="EMA_FILTER_DISABLED"; return true; }
   double current[3],previous[3];
   if(iTime(_Symbol,(ENUM_TIMEFRAMES)InpLowerTF,0)!=decision || iTime(_Symbol,(ENUM_TIMEFRAMES)InpLowerTF,1)+TFSeconds((ENUM_TIMEFRAMES)InpLowerTF)>decision)
   { result="EMA_TIME_NOT_READY"; return false; }
   for(int i=0;i<3;i++)
   {
      double values[2]; // CopyBuffer places the older (shift 2) value first.
      if(BarsCalculated(ema_filter_handles[i])<InpEMASlowPeriod+2 || CopyBuffer(ema_filter_handles[i],0,1,2,values)!=2)
      { result="EMA_DATA_NOT_READY"; return false; }
      previous[i]=values[0]; current[i]=values[1];
      if(!MathIsValidNumber(current[i]) || !MathIsValidNumber(previous[i]) ||
         current[i]==EMPTY_VALUE || previous[i]==EMPTY_VALUE)
      { result="EMA_DATA_INVALID"; return false; }
   }
   bool ordered=current[0]>current[1] && current[1]>current[2];
   bool rising=current[0]>previous[0] && current[1]>previous[1] && current[2]>previous[2];
   result=!ordered ? "EMA_ORDER_NOT_BULLISH" : (InpEMARequireRising && !rising ? "EMA_NOT_ALL_RISING" : "EMA_PASS");
   Print("TW_EMA_FILTER decision=",TimeToString(decision,TIME_DATE|TIME_SECONDS),
         " closed_bar=",TimeToString(iTime(_Symbol,(ENUM_TIMEFRAMES)InpLowerTF,1),TIME_DATE|TIME_SECONDS),
         " ema_fast=",DoubleToString(current[0],10)," ema_middle=",DoubleToString(current[1],10),
         " ema_slow=",DoubleToString(current[2],10)," prev_fast=",DoubleToString(previous[0],10),
         " prev_middle=",DoubleToString(previous[1],10)," prev_slow=",DoubleToString(previous[2],10),
         " result=",result);
   return ordered && (!InpEMARequireRising || rising);
}
int ema_display=INVALID_HANDLE;
string ema_display_name="";

void AttachEMADisplay()
{
   if(!InpShowEMAs || (MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE))) return;
   string instance=IntegerToString(ChartID())+"_"+IntegerToString((long)GetTickCount64());
   ema_display=iCustom(_Symbol,_Period,"ThreeWave_EMA_Display",instance,
                       InpEMAFastPeriod,InpEMAMiddlePeriod,InpEMASlowPeriod);
   if(ema_display==INVALID_HANDLE)
   { Print("TW_EMA display creation failed error=",GetLastError()); return; }
   if(!ChartIndicatorAdd(0,0,ema_display))
   {
      Print("TW_EMA chart attachment failed error=",GetLastError());
      IndicatorRelease(ema_display); ema_display=INVALID_HANDLE; return;
   }
   ema_display_name="TW EMA "+IntegerToString(InpEMAFastPeriod)+"/"+
                    IntegerToString(InpEMAMiddlePeriod)+"/"+IntegerToString(InpEMASlowPeriod)+" ["+instance+"]";
   ChartRedraw();
}

struct TWPlan
{
   M5Setup higher;
   M1Pattern lower;
   datetime signal_time;
   datetime placed;
   ulong order;
   ulong position_id;
   double entry,sl,tp,volume,loss,equity,fill_price,fill_volume,fill_risk,reward_risk;
   bool inflight;
   bool emergency;
};
struct TWSnapshot
{
   long version;
   datetime evaluated,last_fill;
   ulong last_exit;
   bool blocked;
   TWPlan plan;
   long end_tag;
};
TWPlan plan;
datetime last_bar=0,last_fill=0,started=0;
ulong last_exit=0;
bool blocked=false;
int journal=INVALID_HANDLE,csv=INVALID_HANDLE,deals_csv=INVALID_HANDLE,parity=INVALID_HANDLE;
int indicator=INVALID_HANDLE;
string g_prefix="",reason="INITIALIZING",execution_state="IDLE";
int parity_checks=0,parity_failures=0,trace_csv=INVALID_HANDLE,shots=0;
datetime screenshot_pending=0;
datetime recovery_poll=0;
string screenshot_copy="";
double protected_volume=0,protected_entry=0;
long inventory_orders=-1,inventory_positions=-1,inventory_foreign=-1;
#include "../Include/ThreeWaveDrawing.mqh"
#include "../Include/ThreeWaveExecutionBase.mqh"

string TS(const datetime t) { return t>0 ? TimeToString(t,TIME_DATE|TIME_SECONDS) : ""; }
double FloorStep(const double v,const double step) { return MathFloor(v/step+1e-9)*step; }
double Price(const double p) { return NormalizeDouble(p,_Digits); }
string SignalID(const M5Setup &s,const M1Pattern &p)
{ return IntegerToString((long)s.break_time)+"/"+IntegerToString((long)p.choch_time)+"/"+IntegerToString((long)p.ready_time); }
string FibZoneName(const double pct)
{
   if(pct<38.2) return "<38.2";
   if(pct<50) return "38.2-50";
   if(pct<61.8) return "50-61.8";
   if(pct<78.6) return "61.8-78.6";
   if(pct<=100) return "78.6-100";
   return ">100";
}
void ExecutionState(const string next,const string why)
{
   if(next!=execution_state || why!=reason)
      Print("TW_STATE ",execution_state," -> ",next," reason=",why);
   execution_state=next; reason=why;
}
bool Save()
{
   if(journal==INVALID_HANDLE) { blocked=true; return false; }
   TWSnapshot snap={}; snap.version=33002; snap.evaluated=last_bar; snap.last_fill=last_fill;
   snap.last_exit=last_exit; snap.blocked=blocked; snap.plan=plan; snap.end_tag=33001999;
   FileSeek(journal,0,SEEK_END); ResetLastError();
   uint n=FileWriteStruct(journal,snap); FileFlush(journal);
   if(n!=sizeof(TWSnapshot) || GetLastError()!=0)
   { blocked=true; ExecutionState("RECOVERY_BLOCKED","JOURNAL_WRITE_FAILED"); return false; }
   return true;
}
bool LoadJournal()
{
   while(!FileIsEnding(journal))
   {
      TWSnapshot snap={};
      if(FileReadStruct(journal,snap)!=sizeof(TWSnapshot) || snap.version!=33002 || snap.end_tag!=33001999) return false;
      last_bar=snap.evaluated; last_fill=snap.last_fill; last_exit=snap.last_exit;
      blocked=snap.blocked; plan=snap.plan;
   }
   return true;
}
void DrawTrade()
{
   if(!InpShowMarkers || plan.signal_time==0) return;
   DrawSetup(plan.higher,plan.lower,0);
   string key=g_prefix+"TRADE_"+IntegerToString((long)plan.signal_time);
   double entry=(plan.fill_price>0 ? plan.fill_price : plan.entry);
   ArrowAt(key+"ENTRY",plan.placed,entry,clrWhite,233,2);
   TextAt(key+"ENTRY_TXT",plan.placed,entry,"Entry #"+IntegerToString((long)plan.order),clrWhite,ANCHOR_LEFT_UPPER,9);
   HLineSegment(key+"SL",plan.placed,plan.placed+900,plan.sl,clrRed,STYLE_DASH);
   HLineSegment(key+"TP",plan.placed,plan.placed+900,plan.tp,clrLime,STYLE_DASH);
   TextAt(key+"SL_TXT",plan.placed+900,plan.sl,"SL "+DoubleToString(plan.sl,_Digits),clrRed);
   TextAt(key+"TP_TXT",plan.placed+900,plan.tp,"TP "+DoubleToString(plan.tp,_Digits),clrLime);
}
void LogCandidate(const M5Setup &s,const M1Pattern &p,const string outcome,const bool sent)
{
   string entry_reason=InpHLEntryMode==HL_ENTRY_RETEST ? "HL_ENTRY_RETEST" :
      (InpSkipLowerHL ? "SKIP_HL_CHOCH_ONLY" : (p.early_break ? "WAVE2_RETURN_HIGH_CLOSE_BREAK" : "WAVE1_HIGH_CLOSE_BREAK"));
   int orders,positions,foreign; ulong o,t; Counts(orders,positions,foreign,o,t);
   double pct=p.retrace*100;
   int lbar_s=TFSeconds((ENUM_TIMEFRAMES)InpLowerTF),hbar_s=TFSeconds((ENUM_TIMEFRAMES)InpHigherTF);
   bool same=(plan.signal_time==p.ready_time+lbar_s && plan.higher.break_time==s.break_time && plan.lower.choch_time==p.choch_time);
   if(csv!=INVALID_HANDLE)
   {
      FileWrite(csv,TS(p.ready_time+lbar_s),TS(TimeCurrent()),SignalID(s,p),outcome,sent,"",
         entry_reason,
         s.origin_low.price,TS(s.origin_low.bar_time),TS(s.origin_low.confirmed_time),
         s.broken_high.price,TS(s.broken_high.bar_time),TS(s.broken_high.confirmed_time),TS(s.break_time+hbar_s),
         s.wave1_high.price,TS(s.wave1_high.bar_time),TS(s.wave1_high.confirmed_time),
         p.reversal_low.price,TS(p.reversal_low.bar_time),TS(p.reversal_low.confirmed_time),
         p.downtrend_return_high.price,TS(p.downtrend_return_high.bar_time),TS(p.downtrend_return_high.confirmed_time),TS(p.choch_time+lbar_s),
         p.wave1_high.price,TS(p.wave1_high.bar_time),TS(p.wave1_high.confirmed_time),
         p.hl.price,TS(p.hl.bar_time),TS(p.hl.confirmed_time),
         p.pullback_lh.price,TS(p.pullback_lh.bar_time),TS(p.pullback_lh.confirmed_time),p.early_break,pct,FibZoneName(pct),
         EnumToString(InpStopMode),same?plan.entry:0,same?plan.sl:0,same?plan.tp:0,InpRewardRisk,same?plan.volume:0,same?plan.loss:0,same?plan.equity:AccountInfoDouble(ACCOUNT_EQUITY),
         same?plan.order:0,execution_state,orders,positions,foreign);
      FileFlush(csv);
   }
   Print("TW_SIGNAL id=",SignalID(s,p)," confirmed=",TS(p.ready_time+lbar_s)," result=",outcome," sent=",sent," entry_reason=",entry_reason);
}

// Same min-volume OrderCalcProfit conversion, downward lot rounding, margin cap
// and final loss recomputation as the source EA. Entry changes to current Ask.
bool MakePlan(const M5Setup &s,const M1Pattern &p)
{
   double step=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),vmax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double vstep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(step<=0 || vmin<=0 || vmax<vmin || vstep<=0 || SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE)<=0)
   { reason="INVALID_SYMBOL_SPEC"; return false; }
   MqlTick tick={}; if(!SymbolInfoTick(_Symbol,tick) || tick.ask<=0) { reason="NO_QUOTE"; return false; }
   if(tick.bid<p.hl.price || tick.bid<p.reversal_low.price || tick.bid<s.origin_low.price)
   { reason="STRUCTURE_BROKEN_ON_ENTRY_TICK"; return false; }
   ZeroMemory(plan); plan.higher=s; plan.lower=p; plan.signal_time=p.ready_time+TFSeconds((ENUM_TIMEFRAMES)InpLowerTF);
   protected_volume=0; protected_entry=0;
   plan.entry=tick.ask; plan.reward_risk=InpRewardRisk; plan.equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double anchor=p.hl.price;
   if(InpStopMode==STOP_M1_REVERSAL_LOW) anchor=p.reversal_low.price;
   if(InpStopMode==STOP_M5_WAVE1_ORIGIN) anchor=s.origin_low.price;
   plan.sl=Price(FloorStep(anchor-InpSLBufferPoints*_Point,step));
   plan.tp=Price(MathRound((plan.entry+(plan.entry-plan.sl)*InpRewardRisk)/step)*step);
   if(plan.sl<=0 || plan.entry<=plan.sl || plan.tp<=plan.entry) { reason="INVALID_PRICE_GEOMETRY"; return false; }
   double stops=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   if(tick.bid-plan.sl+step*1e-6<stops || plan.tp-tick.bid+step*1e-6<stops)
   { reason="BROKER_STOPS_DISTANCE"; return false; }
   double loss=0;
   if(!OrderCalcProfit(ORDER_TYPE_BUY,_Symbol,vmin,plan.entry,plan.sl,loss) || loss>=0)
   { reason="RISK_CONVERSION_FAILED"; return false; }
   double budget=plan.equity*0.01;
   double volume=FloorStep(MathMin(vmax,budget/(-loss/vmin)),vstep);
   double margin=0;
   if(volume<vmin-1e-9) { reason="MIN_LOT_EXCEEDS_ONE_PERCENT"; return false; }
   if(!OrderCalcMargin(ORDER_TYPE_BUY,_Symbol,volume,plan.entry,margin)) { reason="MARGIN_CALC_FAILED"; return false; }
   double free=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(margin>free && margin>0) volume=FloorStep(volume*free/margin,vstep);
   while(volume>=vmin-1e-9)
   {
      plan.volume=NormalizeDouble(volume,8);
      if(!OrderCalcProfit(ORDER_TYPE_BUY,_Symbol,plan.volume,plan.entry,plan.sl,loss)) { reason="FINAL_LOSS_CALC_FAILED"; return false; }
      plan.loss=-loss;
      if(plan.loss<=budget) break; // No upward tolerance against the requested 1% ceiling.
      volume=FloorStep(volume-vstep,vstep);
   }
   if(volume<vmin-1e-9) { reason="INSUFFICIENT_MARGIN_OR_RISK_BUDGET"; return false; }
   if(!OrderCalcMargin(ORDER_TYPE_BUY,_Symbol,plan.volume,plan.entry,margin) || margin>free)
   { reason="FINAL_MARGIN_CHECK_FAILED"; return false; }
   Print("TW_RISK entry=",plan.entry," SL=",plan.sl," TP=",plan.tp," volume=",plan.volume,
         " expected_loss=",plan.loss," budget=",budget," tick_size=",step,
         " tick_value=",SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE_LOSS),
         " contract=",SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE)," account_currency=",AccountInfoString(ACCOUNT_CURRENCY));
   return true;
}
bool CheckRequest(MqlTradeRequest &req,uint &code)
{
   MqlTradeCheckResult check={}; ResetLastError(); bool valid=OrderCheck(req,check);
   int error=GetLastError(); code=check.retcode;
   Print("TW_CHECK valid=",valid," retcode=",code," error=",error," comment=",check.comment);
   return valid && (code==TRADE_RETCODE_DONE || (code==0 && error==0));
}
bool Place(const M5Setup &s,const M1Pattern &p)
{
   if(!MakePlan(s,p)) return false;
   long modes=SymbolInfoInteger(_Symbol,SYMBOL_ORDER_MODE);
   if((modes & SYMBOL_ORDER_MARKET)==0 || (modes & SYMBOL_ORDER_SL)==0 || (modes & SYMBOL_ORDER_TP)==0)
   { reason="BROKER_ORDER_MODE_UNSUPPORTED"; return false; }
   MqlTradeRequest req={}; MqlTradeResult res={};
   req.action=TRADE_ACTION_DEAL; req.type=ORDER_TYPE_BUY; req.symbol=_Symbol; req.magic=InpMagicNumber;
   req.price=plan.entry; req.volume=plan.volume; req.sl=plan.sl; req.tp=plan.tp;
   req.type_filling=MarketFilling(); req.deviation=20;
   req.comment="TW:"+IntegerToString((long)plan.signal_time);
   bool deferred=InpTestDeferredProtection; uint code=0;
   bool checked=CheckRequest(req,code);
   if(!checked)
   {
      if(code==TRADE_RETCODE_INVALID_STOPS && InpAllowDeferredProtection) deferred=true;
      else { reason="ORDER_CHECK_REJECTED_"+IntegerToString(code); return false; }
   }
   if(deferred)
   {
      req.sl=0; req.tp=0;
      if(!CheckRequest(req,code)) { reason="DEFERRED_CHECK_REJECTED"; return false; }
   }
   plan.placed=TimeCurrent(); plan.inflight=true;
   if(!Save()) return false; // Durable consumed decision and protection plan BEFORE send.
   bool sent=OrderSend(req,res);
   if(res.retcode==TRADE_RETCODE_INVALID_STOPS && !deferred && InpAllowDeferredProtection)
   {
      req.sl=0; req.tp=0; deferred=true;
      // Only definitive no-fill rejection permits the one naked retry.
      if(CheckRequest(req,code)) sent=OrderSend(req,res);
   }
   plan.order=res.order;
   Print("TW_ORDER order=",res.order," deal=",res.deal," retcode=",res.retcode," deferred=",deferred);
   if(!sent || !ResultOK(res.retcode))
   {
      if(res.retcode==0 || res.retcode==TRADE_RETCODE_TIMEOUT || res.retcode==TRADE_RETCODE_CONNECTION)
         blocked=true;
      else plan.inflight=false;
      Save(); ExecutionState(blocked ? "RECOVERY_BLOCKED" : "SIGNAL_CONSUMED","SEND_FAILED_NO_RETRY_"+IntegerToString(res.retcode));
      return false;
   }
   Save(); ExecutionState("ORDER_SENT",deferred ? "MARKET_BUY_DEFERRED_PROTECTION" : "MARKET_BUY_WITH_SLTP");
   return true;
}

void Protect(const ulong ticket)
{
   if(!PositionOwnedExclusively(ticket))
   { blocked=true; ExecutionState("RECOVERY_BLOCKED","POSITION_OWNERSHIP_UNCLEAR"); return; }
   if(PositionGetInteger(POSITION_TYPE)!=POSITION_TYPE_BUY)
   { blocked=true; ExecutionState("RECOVERY_BLOCKED","UNEXPECTED_OWN_POSITION_TYPE"); return; }
   if(plan.signal_time==0 || plan.sl<=0)
   {
      blocked=true; ExecutionState("RECOVERY_BLOCKED","MISSING_PROTECTION_PLAN");
      if(PositionGetDouble(POSITION_SL)<=0 || PositionGetDouble(POSITION_TP)<=0)
         EmergencyClose(ticket,"MISSING_PROTECTION_PLAN");
      return;
   }
   if(plan.position_id>0 && plan.position_id!=(ulong)PositionGetInteger(POSITION_IDENTIFIER))
   { blocked=true; ExecutionState("RECOVERY_BLOCKED","POSITION_PLAN_MISMATCH"); return; }
   // A selected, owned position is positive fill evidence even when the
   // deal-history interval has not caught up with a delayed execution yet.
   ulong identifier=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   if(plan.inflight)
   {
      if(plan.order==0 || (plan.position_id==0 && identifier!=plan.order))
      { blocked=true; ExecutionState("RECOVERY_BLOCKED","POSITION_ORDER_IDENTITY_UNCLEAR"); return; }
      datetime filled=(datetime)PositionGetInteger(POSITION_TIME);
      if(filled<=0) { blocked=true; ExecutionState("RECOVERY_BLOCKED","POSITION_FILL_TIME_UNKNOWN"); return; }
      plan.position_id=identifier; plan.inflight=false;
      if(last_fill<plan.placed || filled<last_fill) last_fill=filled;
      Print("TW_RECONCILE source=position order=",plan.order," position=",identifier," filled=",TS(filled));
      if(!Save()) return;
   }
   if(plan.emergency) { EmergencyClose(ticket,"LATCHED_PROTECTION_FAILURE"); return; }
   double volume=PositionGetDouble(POSITION_VOLUME),entry=PositionGetDouble(POSITION_PRICE_OPEN);
   if(volume!=protected_volume || entry!=protected_entry)
   {
      double loss=0;
      bool calculated=OrderCalcProfit(ORDER_TYPE_BUY,_Symbol,volume,entry,plan.sl,loss);
      plan.fill_risk=(calculated && loss<0 ? -loss : 0);
      plan.fill_price=entry; plan.fill_volume=volume; plan.position_id=identifier;
      if(!calculated || loss>=0 || -loss>plan.equity*0.01)
      {
         plan.emergency=true; Save();
         EmergencyClose(ticket,"FILLED_PRICE_RISK_EXCEEDS_BUDGET_OR_CALC_FAILED"); return;
      }
      plan.fill_risk=-loss; plan.fill_price=entry; plan.fill_volume=volume;
      plan.position_id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      double step=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      plan.tp=Price(MathRound((entry+(entry-plan.sl)*plan.reward_risk)/step)*step);
      protected_volume=volume; protected_entry=entry; Save();
      Print("TW_FILLED_RISK entry=",entry," volume=",volume," expected_loss=",-loss," budget=",plan.equity*0.01);
   }
   double epsilon=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)*0.1;
   if(MathAbs(PositionGetDouble(POSITION_SL)-plan.sl)<epsilon && MathAbs(PositionGetDouble(POSITION_TP)-plan.tp)<epsilon) return;
   MqlTick tick={}; if(!SymbolInfoTick(_Symbol,tick)) return;
   if(tick.bid<=plan.sl || tick.bid>=plan.tp)
   { plan.emergency=true; Save(); EmergencyClose(ticket,"PLANNED_EXIT_ALREADY_CROSSED"); return; }
   MqlTradeRequest req={}; MqlTradeResult res={};
   req.action=TRADE_ACTION_SLTP; req.symbol=_Symbol; req.position=ticket;
   req.magic=InpMagicNumber; req.sl=plan.sl; req.tp=plan.tp;
   bool sent=OrderSend(req,res);
   Print("TW_PROTECT position=",ticket," SL=",plan.sl," TP=",plan.tp," retcode=",res.retcode);
   if(!sent || !ResultOK(res.retcode))
   { plan.emergency=true; Save(); EmergencyClose(ticket,"SLTP_ATTACH_FAILED"); }
}
void Recover()
{
   if(!HistorySelect(plan.placed>0 ? plan.placed-60 : TimeCurrent()-MathMax(86400,InpCooldownMinutes*60),TimeCurrent()))
   { blocked=true; reason="HISTORY_UNAVAILABLE"; return; }
   bool changed=false;
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong d=HistoryDealGetTicket(i);
      if(HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol || (ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagicNumber) continue;
      long entry=HistoryDealGetInteger(d,DEAL_ENTRY),type=HistoryDealGetInteger(d,DEAL_TYPE);
      datetime time=(datetime)HistoryDealGetInteger(d,DEAL_TIME);
      ulong order=(ulong)HistoryDealGetInteger(d,DEAL_ORDER);
      if(entry==DEAL_ENTRY_IN && type==DEAL_TYPE_BUY)
      {
         if(plan.placed>0 && time>=plan.placed && (plan.order==order || plan.order==0))
         {
            if(plan.order==0)
            {
               string expected="TW:"+IntegerToString((long)plan.signal_time);
               if(HistoryOrderGetString(order,ORDER_COMMENT)!=expected)
               { blocked=true; reason="RECOVERY_ORDER_IDENTITY_UNCLEAR"; changed=true; continue; }
               plan.order=order; changed=true;
            }
            if(last_fill<plan.placed || time<last_fill) { last_fill=time; changed=true; }
            if(plan.position_id==0) { plan.position_id=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID); changed=true; }
            if(plan.inflight)
            {
               plan.inflight=false; changed=true;
               Print("TW_RECONCILE source=deal order=",order," deal=",d," filled=",TS(time));
            }
         }
         else if(plan.placed==0 && time>last_fill) { last_fill=time; changed=true; }
      }
      if((entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY) && d>last_exit)
      {
         double profit=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_COMMISSION)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_FEE);
         if(deals_csv!=INVALID_HANDLE)
         {
            FileWrite(deals_csv,d,HistoryDealGetInteger(d,DEAL_POSITION_ID),TS(plan.signal_time),TS(time),
                      HistoryDealGetDouble(d,DEAL_PRICE),HistoryDealGetDouble(d,DEAL_VOLUME),profit,
                      plan.fill_risk,plan.fill_risk>0 ? profit/plan.fill_risk : 0,HistoryDealGetInteger(d,DEAL_REASON));
            FileFlush(deals_csv);
         }
         last_exit=d; changed=true;
      }
   }
   // Definitively rejected/cancelled/expired, completely unfilled orders do
   // not need a deal to resolve. Partial fills still require fill evidence.
   if(plan.inflight && plan.order>0 &&
      HistoryOrderGetString(plan.order,ORDER_SYMBOL)==_Symbol &&
      (ulong)HistoryOrderGetInteger(plan.order,ORDER_MAGIC)==InpMagicNumber)
   {
      long state=HistoryOrderGetInteger(plan.order,ORDER_STATE);
      double initial=HistoryOrderGetDouble(plan.order,ORDER_VOLUME_INITIAL);
      double remaining=HistoryOrderGetDouble(plan.order,ORDER_VOLUME_CURRENT);
      if((state==ORDER_STATE_CANCELED || state==ORDER_STATE_REJECTED || state==ORDER_STATE_EXPIRED) &&
         initial>0 && MathAbs(initial-remaining)<1e-9)
      {
         plan.inflight=false; changed=true;
         Print("TW_RECONCILE source=unfilled_terminal_order order=",plan.order," state=",state);
      }
   }
   if(changed) Save();
}
void Manage()
{
   int orders,positions,foreign; ulong order,position;
   Counts(orders,positions,foreign,order,position);
   // Inventory may remain flat after a rapid fill/close. Keep polling while
   // unresolved instead of relying solely on inventory/transaction changes.
   if(plan.inflight && TimeCurrent()!=recovery_poll)
   { recovery_poll=TimeCurrent(); Recover(); }
   if(orders!=inventory_orders || positions!=inventory_positions || foreign!=inventory_foreign)
   {
      Recover();
      Print("TW_INVENTORY orders=",orders," positions=",positions," foreign=",foreign);
      inventory_orders=orders; inventory_positions=positions; inventory_foreign=foreign;
   }
   if(positions>1 || orders>1) { blocked=true; ExecutionState("RECOVERY_BLOCKED","MULTIPLE_OWN_EXPOSURES"); Save(); }
   // No persistent pending-entry strategy. Remove only our exchange remainder.
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i); if(t==0 || !MineOrder()) continue;
      if(positions>0 || blocked || (plan.placed>0 && TimeCurrent()>plan.placed+60)) Cancel(t,"MARKET_REMAINDER_OR_RECOVERY");
   }
   if(positions==1)
   {
      double previous_fill=plan.fill_price,previous_volume=plan.fill_volume;
      Protect(position);
      if(previous_fill!=plan.fill_price || previous_volume!=plan.fill_volume) DrawTrade();
      if(!blocked) ExecutionState("POSITION_OPEN","POSITION_ACTIVE");
   }
   else if(!blocked && !plan.inflight && orders==0)
      ExecutionState(TimeCurrent()<last_fill+InpCooldownMinutes*60 ? "COOLDOWN" : "WAIT_SIGNAL",
                     TimeCurrent()<last_fill+InpCooldownMinutes*60 ? "FILL_COOLDOWN" : "NO_ACTIVE_EXPOSURE");
   if(plan.inflight && orders==0 && positions==0 && plan.placed>0 && TimeCurrent()>plan.placed+60)
   {
      Recover(); // Always exhaust current history before declaring unknown.
      if(plan.inflight && !blocked)
      { blocked=true; ExecutionState("RECOVERY_BLOCKED","UNRESOLVED_MARKET_SEND"); Save(); }
   }
}

#include "../Include/ThreeWaveHLResearchTrigger.mqh"

bool GetSources(MqlRates &lower[],MqlRates &higher[])
{
   ArraySetAsSeries(lower,false); ArraySetAsSeries(higher,false);
   int lc=CopyRates(_Symbol,InpLowerTF,0,InpHistoryLowerBars,lower);
   int hc=CopyRates(_Symbol,InpHigherTF,0,InpHistoryHigherBars,higher);
   if(lc<100 || hc<100 || !SeriesInfoInteger(_Symbol,InpLowerTF,SERIES_SYNCHRONIZED) ||
      !SeriesInfoInteger(_Symbol,InpHigherTF,SERIES_SYNCHRONIZED)) return false;
   return lower[lc-1].time==last_bar && higher[hc-1].time<=last_bar && last_bar<higher[hc-1].time+TFSeconds((ENUM_TIMEFRAMES)InpHigherTF);
}
void Evaluate(const datetime now)
{
   if(InpHLEntryMode==HL_ENTRY_RETEST) HLRefreshBegin();
   MqlRates lower[],higher[];
   if(!GetSources(lower,higher)) { ExecutionState("WAIT_DATA","DATA_NOT_READY_SKIP_THIS_M1"); return; }
   datetime closed_time=lower[ArraySize(lower)-2].time+TFSeconds((ENUM_TIMEFRAMES)InpLowerTF);
   ArrayResize(tw_events,0); tw_trace_from=closed_time;
   PivotPoint lp[],hp[]; M5Setup setups[];
   BuildPivots(lower,InpLowerTF,InpLowerLeftBars,InpLowerRightBars,lp);
   BuildPivots(higher,InpHigherTF,InpHigherLeftBars,InpHigherRightBars,hp);
   AlignHigherPivotPlotTimes(hp,lower); BuildHigherSetups(higher,hp,setups);
   int fresh=0; double digest=0;
   for(int i=0;i<ArraySize(setups);i++)
   {
      M1Pattern p; AnalyzeLowerPattern(lower,lp,setups[i],p);
      if(p.ready && p.ready_time+TFSeconds((ENUM_TIMEFRAMES)InpLowerTF)==closed_time)
         M15Ready(SignalID(setups[i],p));
      if(InpHLEntryMode==HL_ENTRY_RETEST) { HLObserve(setups[i],p,lower,now); continue; }
      if(!p.ready || p.ready_time+TFSeconds((ENUM_TIMEFRAMES)InpLowerTF)!=closed_time) continue;
      fresh++; digest+=(double)setups[i].break_time;
      if(InpShowMarkers)
      {
         DrawSetup(setups[i],p,0);
         TextAt(g_prefix+"EA_READY_"+IntegerToString((long)now),now,p.ready_price+20*_Point,"EA LONG READY "+TS(now),clrWhite);
      }
      if(MQLInfoInteger(MQL_VISUAL_MODE) && shots<3) screenshot_pending=now;
      int orders,positions,foreign; ulong o,t; Counts(orders,positions,foreign,o,t);
      string why=""; bool sent=false;
      if(blocked) why="RECOVERY_BLOCKED";
      else if(positions>0) why="POSITION_OPEN";
      else if(orders>0 || plan.inflight) why="ORDER_INFLIGHT";
      else if(foreign>0) why="FOREIGN_USDJPY_EXPOSURE";
      else if(TimeCurrent()<last_fill+InpCooldownMinutes*60) why="COOLDOWN";
      else if(p.ready_time+TFSeconds((ENUM_TIMEFRAMES)InpLowerTF)<=started) why="STARTUP_STALE_SIGNAL";
      if(why=="")
      {
         string ema_reason="";
         if(!EMAEntryAllowed(now,ema_reason)) why=ema_reason;
         else { sent=Place(setups[i],p); why=reason; }
      }
      LogCandidate(setups[i],p,why,sent);
   }
   for(int e=0;e<ArraySize(tw_events);e++)
   {
      if(trace_csv!=INVALID_HANDLE) FileWrite(trace_csv,TS(tw_events[e].time),tw_events[e].setup,tw_events[e].state,tw_events[e].reason);
      Print("TW_STRUCTURE ",TS(tw_events[e].time)," setup=",tw_events[e].setup," state=",tw_events[e].state," reason=",tw_events[e].reason);
   }
   if(trace_csv!=INVALID_HANDLE) FileFlush(trace_csv);
   // CopyBuffer forces the SAME shared indicator to calculate on the current tick.
   // Parity is diagnostic only, so trading never waits for a second signal tick.
   if(indicator!=INVALID_HANDLE)
   {
      double count[1],sum[1];
      bool available=CopyBuffer(indicator,0,1,1,count)==1 && CopyBuffer(indicator,1,1,1,sum)==1;
      bool equal=available && count[0]==fresh && sum[0]==digest;
      parity_checks++; if(!equal) parity_failures++;
      if(parity!=INVALID_HANDLE) FileWrite(parity,TS(now),fresh,digest,available,available?count[0]:-1,available?sum[0]:-1,equal);
      if(!equal) Print("TW_PARITY_FAIL ",TS(now)," available=",available," EA count=",fresh," indicator=",count[0]);
   }
   Print("TW_M1 ",TS(now)," fresh_ready=",fresh," state=",execution_state," reason=",reason);
}
#include "../Include/ThreeWaveOptimization.mqh"

int OnInit()
{
   if(InpHLEntryMode==HL_ENTRY_RETEST && InpSkipLowerHL)
   { Print("TW_INPUT_ERROR HL_ENTRY_RETEST requires InpSkipLowerHL=false"); return INIT_PARAMETERS_INCORRECT; }
   if(InpHLEntryMode==HL_ENTRY_CONFIRM || InpHLEntryMode<HL_ENTRY_READY || InpHLEntryMode>HL_ENTRY_RETEST ||
      (InpHLEntryMode==HL_ENTRY_RETEST && (InpHLNearFraction<=0 || InpHLNearFraction>1)) ||
      (InpHLEntryMode==HL_ENTRY_RETEST && InpVerifyIndicator) ||
      InpEMAFastPeriod<1 || InpEMAMiddlePeriod<=InpEMAFastPeriod || InpEMASlowPeriod<=InpEMAMiddlePeriod ||
      InpEMASlowPeriod>10000 ||
      _Period!=(ENUM_TIMEFRAMES)InpLowerTF ||
      InpMagicNumber==0 || InpSLBufferPoints<0 || InpCooldownMinutes<0 || InpCooldownMinutes>10080 ||
      InpRewardRisk<=0 || InpRewardRisk>20 || !InpRequireCloseBreak || InpRequireFibZone ||
      InpLowerLeftBars<1 || InpLowerRightBars<1 || InpHigherLeftBars<1 || InpHigherRightBars<1 ||
      InpLowerLeftBars>1000 || InpLowerRightBars>1000 || InpHigherLeftBars>1000 || InpHigherRightBars>1000 ||
      InpHistoryLowerBars<InpLowerLeftBars+InpLowerRightBars+3 || InpHistoryHigherBars<InpHigherLeftBars+InpHigherRightBars+3 ||
      InpHistoryLowerBars<500 || InpHistoryHigherBars<200 || InpMaxSetupMinutes<30 ||
      ((InpTestDeferredProtection || InpVerifyIndicator) && !MQLInfoInteger(MQL_TESTER))) return INIT_PARAMETERS_INCORRECT;
   if(InpUseEMAFilter)
   {
      TesterHideIndicators(true); // Calculation handles must not add duplicate chart lines.
      int periods[3]={InpEMAFastPeriod,InpEMAMiddlePeriod,InpEMASlowPeriod};
      for(int i=0;i<3;i++)
      {
         ema_filter_handles[i]=iMA(_Symbol,(ENUM_TIMEFRAMES)InpLowerTF,periods[i],0,MODE_EMA,PRICE_CLOSE);
         if(ema_filter_handles[i]==INVALID_HANDLE)
         { TesterHideIndicators(false); return INIT_FAILED; }
      }
      TesterHideIndicators(false);
   }
   started=TimeCurrent();
   string identity=AccountInfoString(ACCOUNT_SERVER)+"_"+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+"_"+IntegerToString((long)InpMagicNumber);
   StringReplace(identity,"/","_"); StringReplace(identity,"\\","_"); StringReplace(identity,":","_");
   string name="TW_USDJPY_"+identity+".bin";
   if(MQLInfoInteger(MQL_TESTER)) FileDelete(name);
   journal=FileOpen(name,FILE_READ|FILE_WRITE|FILE_BIN);
   if(journal==INVALID_HANDLE) return INIT_FAILED;
   if(!LoadJournal()) { blocked=true; reason="CORRUPT_JOURNAL"; }
   // Never replay the already-open startup bar, even after a clean restart.
   last_bar=iTime(_Symbol,(ENUM_TIMEFRAMES)InpLowerTF,0);
   g_prefix="TW_"+IntegerToString((long)InpMagicNumber)+"_";
   if(InpWriteCSV)
   {
      trace_csv=FileOpen("TW_transitions.csv",FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
      if(trace_csv==INVALID_HANDLE) return INIT_FAILED;
      if(FileSize(trace_csv)==0) FileWrite(trace_csv,"time","setup","state","reason");
      FileSeek(trace_csv,0,SEEK_END);
      csv=FileOpen("TW_signals.csv",FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
      deals_csv=FileOpen("TW_exits.csv",FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
      if(csv==INVALID_HANDLE || deals_csv==INVALID_HANDLE) return INIT_FAILED;
      if(FileSize(csv)==0) FileWrite(csv,"signal_time","decision_tick","signal_id","reason","sent","invalidation_reason","state_transition_reason",
         "m5_origin","m5_origin_time","m5_origin_confirmed","m5_return_high","m5_return_time","m5_return_confirmed","m5_choch_time",
         "m5_wave1_high","m5_wave1_time","m5_wave1_confirmed","m1_reversal_low","m1_reversal_time","m1_reversal_confirmed",
         "m1_return_high","m1_return_time","m1_return_confirmed","m1_choch_time","m1_wave1_high","m1_wave1_time","m1_wave1_confirmed",
         "m1_wave2_low","m1_wave2_time","m1_wave2_confirmed","m1_wave2_return_high","m1_wave2_return_time","m1_wave2_return_confirmed",
         "early_break","retracement_pct","fib_zone","stop_mode","entry_price","sl","tp","rr","lots","expected_loss","equity",
         "order","execution_state","orders","positions","foreign");
      if(FileSize(deals_csv)==0) FileWrite(deals_csv,"deal","position_id","signal_time","exit_time","exit_price","volume","profit_exit_deal","initial_risk","result_R_exit_deal","reason");
      FileSeek(csv,0,SEEK_END); FileSeek(deals_csv,0,SEEK_END);
   }
   if(InpVerifyIndicator)
   {
      indicator=iCustom(_Symbol,(ENUM_TIMEFRAMES)InpLowerTF,"MultiTF_3WaveIn3Wave_Visualizer_Shared",InpLowerTF,InpHigherTF,
         InpLowerLeftBars,InpLowerRightBars,InpHigherLeftBars,InpHigherRightBars,InpHistoryLowerBars,InpHistoryHigherBars,
         InpMaxSetupMinutes,InpFibZoneLow,InpFibZoneHigh,false,true,(bool)MQLInfoInteger(MQL_VISUAL_MODE),false,false,true,false,InpMaxDrawSetups,
         (bool)MQLInfoInteger(MQL_VISUAL_MODE),false);
      if(indicator==INVALID_HANDLE) return INIT_FAILED;
      if(MQLInfoInteger(MQL_VISUAL_MODE)) ChartIndicatorAdd(0,0,indicator);
      parity=FileOpen("TW_parity.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
      if(parity==INVALID_HANDLE) return INIT_FAILED;
      FileWrite(parity,"time","ea_count","ea_digest","available","indicator_count","indicator_digest","equal");
   }
   if(InpWriteCSV && InpHLEntryMode==HL_ENTRY_RETEST)
   {
      hl_csv=FileOpen("TW_hl_events.csv",FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
      if(hl_csv==INVALID_HANDLE) return INIT_FAILED;
      if(FileSize(hl_csv)==0)
         FileWrite(hl_csv,"event","key","tick_msc","armed_msc","bid","ask","hl","zone_top","sl",
                   "reversal_low","hl_time","hl_confirmed","parent","choch","reason","sent");
      FileSeek(hl_csv,0,SEEK_END);
   }
   Print("TW_HL_ENTRY mode=",EnumToString(InpHLEntryMode)," near_fraction=",InpHLNearFraction);
   Recover(); Manage(); DrawTrade(); Save();
   AttachEMADisplay();
   M15DisplayInit(InpMagicNumber);
   Print("TW_INIT equity_risk=1% RR=",InpRewardRisk," cooldown=",InpCooldownMinutes," stop=",EnumToString(InpStopMode),
         " EMA=",InpEMAFastPeriod,"/",InpEMAMiddlePeriod,"/",InpEMASlowPeriod);
   return INIT_SUCCEEDED;
}
void OnTick()
{
   if(screenshot_copy!="" && FileIsExist(screenshot_copy))
   {
      FolderCreate("TW_validation",FILE_COMMON);
      bool copied=FileCopy(screenshot_copy,0,"TW_validation\\"+screenshot_copy,FILE_COMMON|FILE_REWRITE);
      Print("TW_VISUAL_FILE copied=",copied," path=",screenshot_copy," error=",GetLastError());
      screenshot_copy="";
   }
   if(screenshot_pending>0)
   {
      ChartSetInteger(0,CHART_SCALE,2); ChartRedraw();
      string path="TW_visual_"+IntegerToString((long)screenshot_pending)+".png";
      bool ok=ChartScreenShot(0,path,1440,900,ALIGN_RIGHT);
      Print("TW_VISUAL screenshot=",ok," signal=",TS(screenshot_pending)," file=",path);
      screenshot_copy=path; shots++; screenshot_pending=0;
   }
   Manage();
   datetime now=iTime(_Symbol,(ENUM_TIMEFRAMES)InpLowerTF,0);
   if(now==0) return;
   if(now!=last_bar)
   {
      last_bar=now;
      if(!Save()) return;
      Evaluate(now);
      Manage();
   }
   if(InpHLEntryMode==HL_ENTRY_RETEST) ProcessHLTick();
   M15DisplayTick();
}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &req,const MqlTradeResult &res)
{
   if(trans.symbol!=_Symbol) return;
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD || trans.type==TRADE_TRANSACTION_HISTORY_ADD)
   { Recover(); Manage(); }
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD) M15Deal(trans.deal,InpMagicNumber);
}
void OnDeinit(const int why)
{
   M15DisplayDeinit();
   if(hl_csv!=INVALID_HANDLE) { FileFlush(hl_csv); FileClose(hl_csv); }
   for(int i=0;i<3;i++) if(ema_filter_handles[i]!=INVALID_HANDLE) IndicatorRelease(ema_filter_handles[i]);
   if(ema_display_name!="") ChartIndicatorDelete(0,0,ema_display_name);
   if(ema_display!=INVALID_HANDLE) IndicatorRelease(ema_display);
   Print("TW_PARITY_RESULT checks=",parity_checks," failures=",parity_failures);
   if(MQLInfoInteger(MQL_TESTER) && HistorySelect(started,TimeCurrent()))
   {
      int all=FileOpen("TW_deals.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
      if(all!=INVALID_HANDLE)
      {
         FileWrite(all,"deal","order","position","time","time_msc","entry","type","price","volume","profit","commission","swap","fee","reason");
         for(int i=0;i<HistoryDealsTotal();i++)
         {
            ulong d=HistoryDealGetTicket(i);
            if(HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol || (ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagicNumber) continue;
            FileWrite(all,d,HistoryDealGetInteger(d,DEAL_ORDER),HistoryDealGetInteger(d,DEAL_POSITION_ID),
               TS((datetime)HistoryDealGetInteger(d,DEAL_TIME)),HistoryDealGetInteger(d,DEAL_TIME_MSC),
               HistoryDealGetInteger(d,DEAL_ENTRY),HistoryDealGetInteger(d,DEAL_TYPE),HistoryDealGetDouble(d,DEAL_PRICE),
               HistoryDealGetDouble(d,DEAL_VOLUME),HistoryDealGetDouble(d,DEAL_PROFIT),HistoryDealGetDouble(d,DEAL_COMMISSION),
               HistoryDealGetDouble(d,DEAL_SWAP),HistoryDealGetDouble(d,DEAL_FEE),HistoryDealGetInteger(d,DEAL_REASON));
         }
         FileClose(all);
      }
   }
   if(journal!=INVALID_HANDLE) { FileFlush(journal); FileClose(journal); }
   if(csv!=INVALID_HANDLE) { FileFlush(csv); FileClose(csv); }
   if(deals_csv!=INVALID_HANDLE) { FileFlush(deals_csv); FileClose(deals_csv); }
   if(parity!=INVALID_HANDLE) { FileFlush(parity); FileClose(parity); }
   if(trace_csv!=INVALID_HANDLE) { FileFlush(trace_csv); FileClose(trace_csv); }
   if(indicator!=INVALID_HANDLE) IndicatorRelease(indicator);
   if(!MQLInfoInteger(MQL_TESTER) && g_prefix!="") DeleteOurObjects();
   Print("TW_DEINIT reason=",why," protection management needs a running connected terminal");
}
