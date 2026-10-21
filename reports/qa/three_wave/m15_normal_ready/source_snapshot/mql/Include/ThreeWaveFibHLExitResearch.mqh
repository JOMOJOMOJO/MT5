#ifndef THREE_WAVE_FIB_HL_EXIT_RESEARCH
#define THREE_WAVE_FIB_HL_EXIT_RESEARCH
#include "ThreeWaveFibHLPolicy.mqh"
datetime fib_used_parents[];
int exit_csv=INVALID_HANDLE;
ulong hl_observed_position=0;
bool hl_selected=false,hl_update_pending=false;
double hl_new_sl=0,hl_new_tp=0,hl_source_price=0;
datetime hl_source_time=0,hl_confirmed=0;
string hl_last_wait="";
long hl_last_request_msc=0;

void HLExitLog(string event,string why,const MqlTick &tick,uint retcode=0)
{
   Print("TW_HL_EXIT event=",event," reason=",why," position=",hl_observed_position,
         " new_sl=",hl_new_sl," new_tp=",hl_new_tp," retcode=",retcode);
   if(exit_csv==INVALID_HANDLE) return;
   FileWrite(exit_csv,event,why,hl_observed_position,TS(plan.signal_time),tick.time_msc,
             TS(hl_source_time),TS(hl_confirmed),hl_source_price,plan.fill_price,plan.sl,plan.tp,
             hl_new_sl,hl_new_tp,plan.fill_risk,tick.bid,retcode);
   FileFlush(exit_csv);
}

bool FirstFibClosedSignal(const M5Setup &s,const M1Pattern &p,const MqlRates &r[],datetime now)
{
   int last=ArraySize(r)-2;
   if(last<0 || !p.found_choch || !p.found_wave1_high ||
      r[last].time<p.wave1_high.confirmed_time ||
      now>s.wave1_high.bar_time+InpMaxSetupMinutes*60+60 ||
      (p.ready && p.ready_time+60<now)) return false;
   for(int i=0;i<ArraySize(fib_used_parents);i++) if(fib_used_parents[i]==s.break_time) return false;
   for(int i=last;i>=0;i--)
   {
      datetime closed=BarCloseTime(r[i],InpLowerTF);
      if(closed<s.wave1_high.confirmed_time) break;
      if(r[i].low<s.origin_low.price || PriceBreakUp(r[i],s.wave1_high.price)) return false;
   }
   if(!FibCloseInside(r[last].close,p.reversal_low.price,p.wave1_high.price,InpFibEntryMinRetracement,InpFibEntryMaxRetracement)) return false;
   for(int i=last-1;i>=0 && r[i].time>=p.wave1_high.confirmed_time;i--)
      if(FibCloseInside(r[i].close,p.reversal_low.price,p.wave1_high.price,InpFibEntryMinRetracement,InpFibEntryMaxRetracement)) return false;
   int n=ArraySize(fib_used_parents); ArrayResize(fib_used_parents,n+1); fib_used_parents[n]=s.break_time;
   Print("TW_FIB_CLOSE decision=",TS(now)," bar=",TS(r[last].time)," close=",r[last].close,
         " low=",p.reversal_low.price," high=",p.wave1_high.price," wave1_confirmed=",TS(p.wave1_high.confirmed_time));
   return true;
}

void ObserveNewHL(const MqlRates &rates[],const PivotPoint &pivots[],datetime now)
{
   if(!InpMoveSLToHL) return;
   int orders,positions,foreign; ulong order,ticket; Counts(orders,positions,foreign,order,ticket);
   if(positions!=1 || !PositionSelectByTicket(ticket) || !MinePosition()) return;
   ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   if(id!=plan.position_id || plan.fill_price<=0 || blocked || plan.emergency) return;
   if(id!=hl_observed_position)
   { hl_observed_position=id; hl_selected=false; hl_update_pending=false; hl_last_wait=""; hl_last_request_msc=0; }
   if(hl_selected) return;
   M1Pattern p; AnalyzeLowerPattern(rates,pivots,plan.higher,p);
   if(!p.found_hl || p.choch_time!=plan.lower.choch_time || p.wave1_high.bar_time!=plan.lower.wave1_high.bar_time ||
      p.hl.confirmed_time!=now || p.hl.confirmed_time<=plan.placed ||
      (p.ready && p.ready_time+60<now)) return;
   hl_selected=true; hl_source_price=p.hl.price; hl_source_time=p.hl.bar_time; hl_confirmed=p.hl.confirmed_time;
   double step=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   hl_new_sl=Price(FloorStep(p.hl.price-InpHLStopBufferPoints*_Point,step));
   hl_new_tp=InpRecalculateTPOnHL ? Price(MathRound(HLTarget(plan.fill_price,hl_new_sl,plan.reward_risk)/step)*step) : plan.tp;
   MqlTick tick={}; SymbolInfoTick(_Symbol,tick);
   if(!HLTighteningValid(plan.fill_price,MathMax(plan.sl,PositionGetDouble(POSITION_SL)),hl_new_sl))
   { HLExitLog("SKIP","SL_NOT_TIGHTER_OR_NOT_BELOW_ENTRY",tick); return; }
   hl_update_pending=true; HLExitLog("TARGET","FIRST_POST_ENTRY_HL_CONFIRMED",tick);
}

void ReconcileHLExit()
{
   if(!hl_update_pending) return;
   int orders,positions,foreign; ulong order,ticket; Counts(orders,positions,foreign,order,ticket);
   if(positions!=1 || !PositionSelectByTicket(ticket) || !MinePosition() ||
      (ulong)PositionGetInteger(POSITION_IDENTIFIER)!=hl_observed_position) return;
   double epsilon=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)*.1;
   if(MathAbs(PositionGetDouble(POSITION_SL)-hl_new_sl)<epsilon && MathAbs(PositionGetDouble(POSITION_TP)-hl_new_tp)<epsilon)
   {
      MqlTick tick={}; SymbolInfoTick(_Symbol,tick); HLExitLog("RECONCILE","SERVER_CONFIRMED_NEW_PROTECTION",tick);
      plan.sl=hl_new_sl; plan.tp=hl_new_tp; Save(); hl_update_pending=false;
   }
}

void ApplyHLExit()
{
   if(!InpMoveSLToHL || !hl_update_pending || blocked || plan.emergency) return;
   int orders,positions,foreign; ulong order,ticket; Counts(orders,positions,foreign,order,ticket);
   if(positions!=1 || !PositionSelectByTicket(ticket) || !MinePosition() ||
      (ulong)PositionGetInteger(POSITION_IDENTIFIER)!=hl_observed_position)
   { hl_update_pending=false; return; }
   MqlTick tick={}; if(!SymbolInfoTick(_Symbol,tick)) return;
   if(hl_last_request_msc>0 && tick.time_msc-hl_last_request_msc<1000) return;
   if(tick.bid>=hl_new_tp || tick.bid<=hl_new_sl)
   {
      string why=tick.bid>=hl_new_tp ? "NEW_TP_ALREADY_REACHED" : "NEW_SL_ALREADY_CROSSED";
      hl_last_request_msc=tick.time_msc;
      bool closed=EmergencyClose(ticket,why);
      HLExitLog(closed ? "CLOSE" : "CLOSE_RETRY",why,tick);
      if(closed) hl_update_pending=false;
      return;
   }
   double stop=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   double freeze=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL)*_Point;
   double old_sl=PositionGetDouble(POSITION_SL),old_tp=PositionGetDouble(POSITION_TP);
   if(hl_new_sl<=old_sl)
   { hl_update_pending=false; HLExitLog("SKIP","SERVER_SL_ALREADY_TIGHTER",tick); return; }
   bool frozen=freeze>0 && ((old_sl>0 && tick.bid-old_sl<=freeze) || (old_tp>0 && old_tp-tick.bid<=freeze) ||
                            tick.bid-hl_new_sl<=freeze || hl_new_tp-tick.bid<=freeze);
   if(tick.bid-hl_new_sl<stop || hl_new_tp-tick.bid<stop || frozen)
   {
      if(hl_last_wait!="DISTANCE") { HLExitLog("WAIT","STOP_OR_FREEZE_DISTANCE",tick); hl_last_wait="DISTANCE"; }
      return; // Leave existing server protection untouched.
   }
   MqlTradeRequest req={}; MqlTradeResult res={};
   req.action=TRADE_ACTION_SLTP; req.symbol=_Symbol; req.position=ticket; req.magic=InpMagicNumber;
   req.sl=hl_new_sl; req.tp=hl_new_tp;
   hl_last_request_msc=tick.time_msc;
   bool sent=OrderSend(req,res);
   if(sent && ResultOK(res.retcode))
   {
      HLExitLog("MODIFY",InpRecalculateTPOnHL ? "HL_SL_AND_RR_TP_APPLIED" : "HL_SL_APPLIED_INITIAL_TP_KEPT",tick,res.retcode);
      plan.sl=hl_new_sl; plan.tp=hl_new_tp; Save();
      // Keep initial fill_risk intact: exit R remains measured against entry risk.
      hl_update_pending=false;
      if(InpShowMarkers)
      {
         string key=g_prefix+"HL_EXIT_"+IntegerToString((long)hl_observed_position);
         HLineSegment(key+"SL",tick.time,tick.time+900,plan.sl,clrRed,STYLE_DASH);
         HLineSegment(key+"TP",tick.time,tick.time+900,plan.tp,clrLime,STYLE_DASH);
      }
   }
   else
   {
      string why=IntegerToString((long)res.retcode);
      if(hl_last_wait!=why) { HLExitLog("RETRY","MODIFY_REJECTED_KEEP_OLD_PROTECTION",tick,res.retcode); hl_last_wait=why; }
   }
}
#endif
