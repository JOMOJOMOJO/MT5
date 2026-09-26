// Research-only trigger adapter. Shared structure recognition is not modified.
#ifndef THREE_WAVE_FIB_WAVE2_TRIGGER
#define THREE_WAVE_FIB_WAVE2_TRIGGER
#include "ThreeWaveFibTickPolicy.mqh"
struct FibWatch
{
   M5Setup higher;
   M1Pattern lower;
   bool active;
   int state; // 0=armed, 1=touched/await next OnTick, 2=consumed or invalidated
   double bottom,top,touch_bid;
   long touch_msc,touch_seq;
};
FibWatch fib_watches[];
long fib_tick_seq=0;
int fib_csv=INVALID_HANDLE;

void FibLog(const FibWatch &w,const string event,const MqlTick &tick,const string why,const bool sent=false)
{
   string key=IntegerToString((long)w.higher.break_time)+"/"+IntegerToString((long)w.lower.choch_time)+"/"+IntegerToString((long)w.lower.wave1_high.bar_time);
   Print("TW_FIB event=",event," key=",key," tick_msc=",tick.time_msc," seq=",fib_tick_seq," reason=",why," sent=",sent);
   if(fib_csv==INVALID_HANDLE) return;
   FileWrite(fib_csv,event,key,tick.time_msc,fib_tick_seq,w.touch_msc,w.touch_seq,w.touch_bid,
             tick.bid,tick.ask,w.bottom,w.top,w.lower.reversal_low.price,
             TS(w.lower.reversal_low.bar_time),w.lower.wave1_high.price,
             TS(w.lower.wave1_high.bar_time),TS(w.lower.wave1_high.confirmed_time),
             TS(w.higher.break_time),TS(w.lower.choch_time),why,sent);
   FileFlush(fib_csv);
}

bool FibSame(const FibWatch &w,const M5Setup &s,const M1Pattern &p)
{
   return w.higher.break_time==s.break_time && w.lower.choch_time==p.choch_time &&
          w.lower.wave1_high.bar_time==p.wave1_high.bar_time;
}

void FibRefreshBegin()
{
   for(int i=0;i<ArraySize(fib_watches);i++) fib_watches[i].active=false;
}

void FibObserveStructure(const M5Setup &s,const M1Pattern &p,const MqlRates &rates[],const datetime now)
{
   if(!p.found_choch || !p.found_wave1_high || p.ready || p.wave1_high.confirmed_time>now ||
      now>s.wave1_high.bar_time+InpMaxSetupMinutes*60+60) return;
   // Shared can return a partial pattern at parent expiry/break. Do not revive it.
   for(int j=ArraySize(rates)-2;j>=0;j--)
   {
      if(BarCloseTime(rates[j],InpLowerTF)<s.wave1_high.confirmed_time) break;
      if(PriceBreakUp(rates[j],s.wave1_high.price) || rates[j].low<s.origin_low.price) return;
   }
   for(int i=0;i<ArraySize(fib_watches);i++)
   {
      if(FibSame(fib_watches[i],s,p))
      {
         fib_watches[i].active=true;
         return; // Keep the initially confirmed range fixed.
      }
   }
   // Never reconstruct a first touch from historical bars or on a late startup.
   if(p.wave1_high.confirmed_time!=now || now<=started) return;
   double range=p.wave1_high.price-p.reversal_low.price;
   if(range<=0) return;
   FibWatch w={}; w.higher=s; w.lower=p; w.active=true;
   w.bottom=p.wave1_high.price-range*InpFibEntryMaxRetracement;
   w.top=p.wave1_high.price-range*InpFibEntryMinRetracement;
   int n=ArraySize(fib_watches); ArrayResize(fib_watches,n+1); fib_watches[n]=w;
   MqlTick tick={}; SymbolInfoTick(_Symbol,tick);
   FibLog(w,"ARM",tick,"WAVE1_HIGH_CONFIRMED");
   if(InpShowMarkers)
   {
      DrawSetup(s,p,0);
      string key=g_prefix+"FIB_"+IntegerToString((long)s.break_time)+"_"+IntegerToString((long)p.choch_time);
      datetime end=s.wave1_high.bar_time+InpMaxSetupMinutes*60;
      HLineSegment(key+"TOP",now,end,w.top,clrDeepPink,STYLE_DOT);
      HLineSegment(key+"BOTTOM",now,end,w.bottom,clrDeepPink,STYLE_DOT);
      TextAt(key+"LABEL",now,w.top,"Fib Wave2 entry zone",clrDeepPink);
   }
}

bool FibParentConsumed(const int index)
{
   for(int i=0;i<ArraySize(fib_watches);i++)
      if(i!=index && fib_watches[i].higher.break_time==fib_watches[index].higher.break_time &&
         fib_watches[i].touch_seq>0) return true;
   return false;
}

void ProcessFibTick()
{
   MqlTick tick={}; if(!SymbolInfoTick(_Symbol,tick) || tick.bid<=0 || tick.ask<=0) return;
   fib_tick_seq++;
   for(int i=0;i<ArraySize(fib_watches);i++)
   {
      FibWatch w=fib_watches[i];
      if(w.state==2) continue;
      FibTickAction action=FibAction(w.state,w.active,FibParentConsumed(i),tick.bid,w.lower.reversal_low.price,
                                    w.higher.origin_low.price,w.bottom,w.top,fib_tick_seq,w.touch_seq);
      if(action==FIB_INVALIDATE)
      {
         string why=!w.active ? "STRUCTURE_NO_LONGER_ACTIVE" : (FibParentConsumed(i) ? "PARENT_FIRST_TOUCH_ALREADY_USED" : "ORIGIN_BROKEN");
         w.state=2; fib_watches[i]=w; FibLog(w,"INVALIDATE",tick,why); continue;
      }
      if(action==FIB_TOUCH)
      {
         // Actual quoted Bid must be within the zone; a gap across it is not a touch.
         w.state=1; w.touch_bid=tick.bid; w.touch_msc=tick.time_msc; w.touch_seq=fib_tick_seq;
         fib_watches[i]=w; FibLog(w,"TOUCH",tick,"WAIT_NEXT_AVAILABLE_TICK");
         continue; // Never send on the detection tick.
      }
      if(action!=FIB_SEND) continue;
      w.state=2; fib_watches[i]=w; // Consume even if EMA/exposure/cooldown rejects.
      int orders,positions,foreign; ulong order,position;
      Counts(orders,positions,foreign,order,position);
      string why=""; bool sent=false;
      if(blocked) why="RECOVERY_BLOCKED";
      else if(positions>0) why="POSITION_OPEN";
      else if(orders>0 || plan.inflight) why="ORDER_INFLIGHT";
      else if(foreign>0) why="FOREIGN_USDJPY_EXPOSURE";
      else if(TimeCurrent()<last_fill+InpCooldownMinutes*60) why="COOLDOWN";
      M1Pattern trigger=w.lower;
      // Adapter field for the unchanged execution journal's signal_time convention.
      // It is NOT a historical READY bar or a fabricated confirmed HL.
      trigger.ready_time=tick.time-60;
      trigger.ready_price=tick.ask;
      trigger.retrace=(w.lower.wave1_high.price-w.touch_bid)/(w.lower.wave1_high.price-w.lower.reversal_low.price);
      trigger.fib_ok=true;
      if(why=="")
      {
         string ema_reason="";
         if(!EMAEntryAllowed(iTime(_Symbol,PERIOD_M1,0),ema_reason)) why=ema_reason;
         else { sent=Place(w.higher,trigger); why=reason; }
      }
      FibLog(w,"DECISION",tick,why,sent);
      LogCandidate(w.higher,trigger,why,sent);
      if(InpShowMarkers)
      {
         string key=g_prefix+"FIB_DECISION_"+IntegerToString((long)w.higher.break_time);
         ArrowAt(key,tick.time,tick.ask,sent ? clrLime : clrGray,233,2);
         TextAt(key+"TEXT",tick.time,tick.ask,"Fib Wave2: "+why,sent ? clrLime : clrGray);
      }
   }
}
#endif
