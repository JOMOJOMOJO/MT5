#ifndef THREE_WAVE_HL_RESEARCH_TRIGGER
#define THREE_WAVE_HL_RESEARCH_TRIGGER
#include "ThreeWaveHLTickPolicy.mqh"
struct HLWatch
{
   M5Setup higher;
   M1Pattern lower;
   bool active,consumed,decided;
   double top,sl;
   long armed_msc;
};
HLWatch hl_watches[];
int hl_csv=INVALID_HANDLE;

void HLLog(const HLWatch &w,string event,const MqlTick &tick,string why,bool sent=false)
{
   string key=IntegerToString((long)w.higher.break_time)+"/"+IntegerToString((long)w.lower.choch_time);
   Print("TW_HL event=",event," key=",key," tick_msc=",tick.time_msc," reason=",why," sent=",sent);
   if(hl_csv==INVALID_HANDLE) return;
   FileWrite(hl_csv,event,key,tick.time_msc,w.armed_msc,tick.bid,tick.ask,w.lower.hl.price,w.top,w.sl,
             w.lower.reversal_low.price,TS(w.lower.hl.bar_time),TS(w.lower.hl.confirmed_time),
             TS(w.higher.break_time),TS(w.lower.choch_time),why,sent);
   FileFlush(hl_csv);
}
void HLRefreshBegin()
{ for(int i=0;i<ArraySize(hl_watches);i++) hl_watches[i].active=false; }

void HLObserve(const M5Setup &s,const M1Pattern &p,const MqlRates &rates[],datetime now)
{
   if(!p.found_choch || !p.found_wave1_high ||
      now>s.wave1_high.bar_time+InpMaxSetupMinutes*60+TFSeconds((ENUM_TIMEFRAMES)InpLowerTF) ||
      (p.ready && p.ready_time+TFSeconds((ENUM_TIMEFRAMES)InpLowerTF)<now)) return;
   // Preserve the shared rule allowing READY on the first parent-break bar only.
   for(int j=ArraySize(rates)-2;j>=0;j--)
   {
      datetime closed=BarCloseTime(rates[j],InpLowerTF);
      if(closed<s.wave1_high.confirmed_time) break;
      if(rates[j].low<s.origin_low.price) return;
      if(PriceBreakUp(rates[j],s.wave1_high.price) && !(p.ready && closed==now && p.ready_time+TFSeconds((ENUM_TIMEFRAMES)InpLowerTF)==now)) return;
   }
   for(int i=0;i<ArraySize(hl_watches);i++)
   {
      if(hl_watches[i].higher.break_time==s.break_time && hl_watches[i].lower.choch_time==p.choch_time)
      {
         // Keep the first HL fixed even if Shared later reports a higher HL.
         hl_watches[i].active=true;
         for(int j=ArraySize(rates)-2;j>=0;j--)
         {
            if(rates[j].time<hl_watches[i].lower.hl.bar_time) break;
            if(rates[j].low<hl_watches[i].lower.hl.price) { hl_watches[i].active=false; break; }
         }
         return;
      }
   }
   if(!p.found_hl || p.hl.confirmed_time>now) return;
   HLWatch w={}; w.higher=s; w.lower=p; w.active=true;
   double step=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(step<=0) return;
   w.sl=Price(FloorStep(p.reversal_low.price-InpSLBufferPoints*_Point,step));
   w.top=p.hl.price+(p.hl.price-w.sl)*InpHLNearFraction;
   MqlTick tick={}; if(!SymbolInfoTick(_Symbol,tick)) return;
   w.armed_msc=tick.time_msc;
   // Mark old attempts as consumed rather than treating a later HL revision as first.
   if(p.hl.confirmed_time!=now || now<=started) w.consumed=true;
   int n=ArraySize(hl_watches); ArrayResize(hl_watches,n+1); hl_watches[n]=w;
   if(w.consumed) return;
   HLLog(w,"ARM",tick,"FIRST_CONFIRMED_HL");
   if(InpShowMarkers)
   {
      DrawSetup(s,p,0);
      string key=g_prefix+"HL_ZONE_"+IntegerToString((long)s.break_time)+"_"+IntegerToString((long)p.choch_time);
      HLineSegment(key,now,s.wave1_high.bar_time+InpMaxSetupMinutes*60,w.top,clrDeepPink,STYLE_DOT);
      TextAt(key+"LABEL",now,w.top,"HL retest maximum Ask",clrDeepPink);
   }
}
bool HLParentUsed(int index)
{
   for(int i=0;i<ArraySize(hl_watches);i++)
      if(i!=index && hl_watches[i].higher.break_time==hl_watches[index].higher.break_time && hl_watches[i].decided) return true;
   return false;
}
void ProcessHLTick()
{
   MqlTick tick={}; if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0 || tick.ask<=0) return;
   for(int i=0;i<ArraySize(hl_watches);i++)
   {
      if(hl_watches[i].consumed) continue;
      HLWatch w=hl_watches[i];
      HLTickAction action=HLAction(w.consumed,w.active,HLParentUsed(i),tick.bid,tick.ask,w.lower.hl.price,
                                  w.lower.reversal_low.price,w.higher.origin_low.price,w.top,InpHLEntryMode==HL_ENTRY_CONFIRM);
      if(action==HL_WAIT) continue;
      w.consumed=true;
      if(action==HL_INVALIDATE)
      {
         hl_watches[i]=w;
         HLLog(w,"INVALIDATE",tick,!w.active ? "STRUCTURE_OR_HL_CHANGED" : (HLParentUsed(i) ? "PARENT_ALREADY_DECIDED" : "HL_OR_ORIGIN_BROKEN"));
         continue;
      }
      w.decided=true; hl_watches[i]=w;
      int orders,positions,foreign; ulong order,position; Counts(orders,positions,foreign,order,position);
      string why=""; bool sent=false;
      if(blocked) why="RECOVERY_BLOCKED";
      else if(positions>0) why="POSITION_OPEN";
      else if(orders>0 || plan.inflight) why="ORDER_INFLIGHT";
      else if(foreign>0) why="FOREIGN_USDJPY_EXPOSURE";
      else if(TimeCurrent()<last_fill+InpCooldownMinutes*60) why="COOLDOWN";
      M1Pattern trigger=w.lower;
      // Timestamp adapter for execution journal; no historical READY is asserted.
      trigger.ready=false; trigger.ready_time=tick.time-TFSeconds((ENUM_TIMEFRAMES)InpLowerTF); trigger.ready_price=tick.ask;
      if(why=="")
      {
         string ema_reason="";
         if(!EMAEntryAllowed(iTime(_Symbol,(ENUM_TIMEFRAMES)InpLowerTF,0),ema_reason)) why=ema_reason;
         else { sent=Place(w.higher,trigger); why=reason; }
      }
      HLLog(w,"DECISION",tick,why,sent); LogCandidate(w.higher,trigger,why,sent);
      if(InpShowMarkers)
      {
         string key=g_prefix+"HL_DECISION_"+IntegerToString((long)w.higher.break_time);
         TextAt(key,tick.time,tick.ask,EnumToString(InpHLEntryMode)+": "+why,sent ? clrLime : clrGray);
      }
   }
}
#endif
