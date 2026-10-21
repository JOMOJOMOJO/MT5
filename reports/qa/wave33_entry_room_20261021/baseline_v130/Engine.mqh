#ifndef WAVE33_VISUAL_ENGINE_MQH
#define WAVE33_VISUAL_ENGINE_MQH
#include "Types.mqh"

// Each call appends exactly one CLOSED candle. Arrays are chronological.
// A pivot's candle time and availability time are deliberately different.
class CWave33Series
  {
public:
   ENUM_TIMEFRAMES tf;
   MqlRates bars[];
   W33Pivot pivots[];
   void Reset(const ENUM_TIMEFRAMES timeframe)
     {
      tf=timeframe;
      ArrayResize(bars,0);
      ArrayResize(pivots,0);
     }
   bool Latest(const bool high,W33Pivot &p,const int offset=0) const
     {
      int found=0;
      for(int i=ArraySize(pivots)-1;i>=0;i--)
         if(pivots[i].is_high==high)
           {
            if(found==offset) { p=pivots[i]; return true; }
            found++;
           }
      return false;
     }
   bool Append(const MqlRates &bar,const datetime knownAt,const int left,const int right,W33Pivot &confirmed[])
     {
      ArrayResize(confirmed,0);
      int n=ArraySize(bars);
      if(knownAt<bar.time+PeriodSeconds(tf) || (n>0 && bar.time<=bars[n-1].time)) return false;
      ArrayResize(bars,n+1,4096);
      bars[n]=bar;
      int k=n-right;
      if(k<left) return true;
      bool high=true,low=true;
      for(int j=k-left;j<=k+right;j++)
        {
         if(j==k) continue;
         // Equal highs/lows are not arbitrarily chosen as unique pivots.
         if(bars[k].high<=bars[j].high) high=false;
         if(bars[k].low>=bars[j].low) low=false;
        }
      for(int side=0;side<2;side++)
        {
         bool isHigh=(side==0);
         if((isHigh && !high) || (!isHigh && !low)) continue;
         W33Pivot p;
         p.time=bars[k].time;
         p.known_at=knownAt;
         p.price=isHigh ? bars[k].high : bars[k].low;
         p.tf=tf;
         p.is_high=isHigh;
         W33Pivot prior;
         p.label=isHigh ? "H" : "L";
         if(Latest(isHigh,prior))
            p.label=isHigh ? (p.price>prior.price ? "HH" : "LH") : (p.price>prior.price ? "HL" : "LL");
         int count=ArraySize(pivots);
         ArrayResize(pivots,count+1,1024);
         pivots[count]=p;
         int countNew=ArraySize(confirmed);
         ArrayResize(confirmed,countNew+1);
         confirmed[countNew]=p;
        }
      return true;
     }
  };

class CWave33Engine
  {
private:
   CWave33Series m_upper,m_lower,m_h1,m_m15;
   W33Setup m_setup[2];
   W33Event m_events[];
   bool m_has[2],m_frozen[2];
   datetime m_last_break[2];
   datetime m_structure_key[2];
   datetime m_rejected_structure_key[2];
   ENUM_TIMEFRAMES m_upper_tf,m_lower_tf;
   int m_left,m_right,m_timeout;
   double m_fib_min,m_fib_max,m_point;
   bool m_reject_deep,m_require_fib,m_strict_lifecycle;
   W33TriggerMode m_mode;
   string m_symbol;
   long m_serial;

   int Slot(const int direction) const { return direction>0 ? 0 : 1; }
   void Emit(const int slot,const string type,const datetime at,const string kind="OBSERVATION",const string reason="")
     {
      m_setup[slot].last_updated_at=at;
      W33Event e;
      ZeroMemory(e);
      e.at=at;
      e.event_type=type;
      e.reason_kind=kind;
      e.reason=reason;
      e.setup=m_setup[slot];
      int n=ArraySize(m_events);
      ArrayResize(m_events,n+1,512);
      m_events[n]=e;
     }
   void PivotEvents(const W33Pivot &pivots[])
     {
      for(int j=0;j<ArraySize(pivots);j++)
        {
         W33Event e;
         ZeroMemory(e);
         e.at=pivots[j].known_at;
         e.event_type="PIVOT_CONFIRMED";
         e.reason_kind="OBSERVATION";
         e.reason=pivots[j].label;
         e.has_pivot=true;
         e.pivot=pivots[j];
         e.setup.symbol=m_symbol;
         e.setup.upper_tf=m_upper_tf;
         e.setup.lower_tf=m_lower_tf;
         int n=ArraySize(m_events);
         ArrayResize(m_events,n+1,512);
         m_events[n]=e;
        }
     }
   void ChangeState(const int slot,const W33State state,const datetime at)
     {
      if(m_setup[slot].state==state) return;
      m_setup[slot].state=state;
      Emit(slot,"STATE",at,"OBSERVATION",W33StateName(state));
     }
   void Invalidate(const int slot,const datetime at,const string reason)
     {
      if(!m_has[slot] || !m_setup[slot].active || m_setup[slot].position_open) return;
      m_setup[slot].active=false;
      m_setup[slot].skip_reason=reason;
      m_setup[slot].entry_status=m_setup[slot].signal_emitted ? "SIGNAL_MONITOR_COMPLETED" : "INVALIDATED";
      Emit(slot,m_setup[slot].signal_emitted ? "COMPLETED" : "INVALIDATE",at,m_setup[slot].signal_emitted ? "OBSERVATION" : "EXCLUSION",reason);
     }
   // Last two highs AND lows must form an ordered, complete countertrend.
   bool CounterPivots(const CWave33Series &series,const int direction,const datetime from,
                     const datetime knownBy,W33Pivot &h1,W33Pivot &h2,W33Pivot &l1,W33Pivot &l2) const
     {
      int hc=0,lc=0;
      for(int j=ArraySize(series.pivots)-1;j>=0;j--)
        {
         W33Pivot p=series.pivots[j];
         if(p.time<from || p.known_at>knownBy) continue;
         if(p.is_high && hc<2) { if(hc==0) h2=p; else h1=p; hc++; }
         if(!p.is_high && lc<2) { if(lc==0) l2=p; else l1=p; lc++; }
         if(hc==2 && lc==2) break;
        }
      if(hc<2 || lc<2) return false;
      bool alternating=(h1.time<l1.time && l1.time<h2.time && h2.time<l2.time) ||
                       (l1.time<h1.time && h1.time<l2.time && l2.time<h2.time);
      if(!alternating) return false;
      if(direction>0)
         return h2.price<h1.price && l2.price<l1.price;
      return h2.price>h1.price && l2.price>l1.price;
     }
   datetime LatestKnown(const W33Pivot &h1,const W33Pivot &h2,const W33Pivot &l1,const W33Pivot &l2) const
     {
      return (datetime)MathMax(MathMax((long)h1.known_at,(long)h2.known_at),MathMax((long)l1.known_at,(long)l2.known_at));
     }
   void Create(const int direction,const MqlRates &bar,const datetime knownAt,
               const W33Pivot &level,const W33Pivot &origin)
     {
      int i=Slot(direction);
      ZeroMemory(m_setup[i]);
      m_serial++;
      m_setup[i].setup_id=StringFormat("W33_%s_%d_%d_%s_%I64d_%I64d",m_symbol,(int)m_upper_tf,(int)m_lower_tf,
                                     W33DirectionName(direction),(long)bar.time,m_serial);
      m_setup[i].symbol=m_symbol;
      m_setup[i].upper_tf=m_upper_tf;
      m_setup[i].lower_tf=m_lower_tf;
      m_setup[i].direction=direction;
      m_setup[i].state=WAVE1_BREAK_CANDIDATE;
      m_setup[i].active=true;
      m_setup[i].candidate_detected_at=knownAt;
      m_setup[i].upper_break_level=level.price;
      m_setup[i].upper_break_level_time=level.time;
      m_setup[i].upper_break_level_known_at=level.known_at;
      m_setup[i].upper_break_bar_time=bar.time;
      m_setup[i].upper_break_confirmed_at=bar.time+PeriodSeconds(m_upper_tf);
      m_setup[i].wave1_start_time=origin.time;
      m_setup[i].wave1_start_price=origin.price;
      m_setup[i].wave1_start_known_at=origin.known_at;
      m_setup[i].wave1_provisional_time=bar.time;
      m_setup[i].wave1_provisional_price=direction>0 ? bar.high : bar.low;
      m_setup[i].entry_status="CANDIDATE";
      m_setup[i].lower_entry_stage="COUNTERTREND_NEGATION";
      m_setup[i].h1_direction=H1Direction(direction);
      m_has[i]=true;
      m_frozen[i]=false;
      m_structure_key[i]=0;
      m_rejected_structure_key[i]=0;
      m_last_break[i]=level.time;
      Emit(i,"WAVE1_BREAK",knownAt);
      ChangeState(i,WAVE1_TOP_TRACKING,knownAt);
      Emit(i,"WAVE1_PROVISIONAL",knownAt);
     }
   void Search(const MqlRates &bar,const datetime knownAt)
     {
      int count=ArraySize(m_upper.bars);
      if(count<2) return;
      MqlRates previous=m_upper.bars[count-2];
      for(int side=0;side<2;side++)
        {
         int direction=side==0 ? 1 : -1;
         W33Pivot h1,h2,l1,l2;
         // A level becoming confirmed on this candle's close cannot explain its break.
         if(!CounterPivots(m_upper,direction,0,bar.time,h1,h2,l1,l2)) continue;
         W33Pivot level,origin;
         if(direction>0) { level=h2; origin=l2; }
         else { level=l2; origin=h2; }
         if(level.time==m_last_break[side]) continue;
         bool crossed=direction>0 ? previous.close<=level.price && bar.close>level.price : previous.close>=level.price && bar.close<level.price;
         if(!crossed) continue;
         if(m_has[side] && m_setup[side].active)
           {
            // Record every distinct observable break, even while a prior setup
            // owns this direction's single lane. It is a documented concurrency
            // exclusion, not an invisible statistical filter.
            W33Setup previousSetup=m_setup[side];
            bool frozen=m_frozen[side];
            datetime structureKey=m_structure_key[side];
            datetime rejectedKey=m_rejected_structure_key[side];
            Create(direction,bar,knownAt,level,origin);
            m_setup[side].active=false;
            m_setup[side].entry_status="SKIPPED";
            m_setup[side].skip_reason="ACTIVE_SETUP_SAME_DIRECTION";
            Emit(side,"SKIP",knownAt,"EXCLUSION","ACTIVE_SETUP_SAME_DIRECTION");
            m_setup[side]=previousSetup;
            m_frozen[side]=frozen;
            m_structure_key[side]=structureKey;
            m_rejected_structure_key[side]=rejectedKey;
            // m_last_break intentionally retains the consumed new level.
           }
         else Create(direction,bar,knownAt,level,origin);
        }
     }
   void ObserveWave2(const int slot,const MqlRates &bar,const datetime knownAt)
     {
      if(!m_setup[slot].active || !m_setup[slot].wave1_peak_fixed || bar.time<m_setup[slot].wave2_start_time) return;
      int d=m_setup[slot].direction;
      // The scenario's entry-time W2 and risk anchor remain historical facts.
      // Continue only terminal monitoring and alternate-trigger comparison.
      if(m_setup[slot].signal_emitted)
        {
         if(!m_setup[slot].position_open && (d>0 ? bar.low<=m_setup[slot].wave1_start_price : bar.high>=m_setup[slot].wave1_start_price))
            Invalidate(slot,knownAt,"WAVE1_ORIGIN_BROKEN");
         return;
        }
      // A candle invalidating the scenario cannot also create a fresh signal.
      if(m_strict_lifecycle && (d>0 ? bar.low<=m_setup[slot].wave1_start_price : bar.high>=m_setup[slot].wave1_start_price))
        {
         Invalidate(slot,knownAt,"WAVE1_ORIGIN_BROKEN");
         return;
        }
      double price=d>0 ? bar.low : bar.high;
      bool newExtreme=(m_setup[slot].wave2_extreme_time==0 || (d>0 ? price<m_setup[slot].wave2_extreme_price : price>m_setup[slot].wave2_extreme_price));
      if(newExtreme)
        {
         m_setup[slot].wave2_extreme_time=bar.time;
         m_setup[slot].wave2_extreme_price=price;
         m_setup[slot].wave2_extreme_known_at=knownAt;
         double span=MathAbs(m_setup[slot].wave1_peak_price-m_setup[slot].wave1_start_price);
         m_setup[slot].retracement_ratio=span>0 ? d*(m_setup[slot].wave1_peak_price-price)/span : 0;
         Emit(slot,"WAVE2_EXTREME",knownAt);
        }
      double zoneLow=MathMin(m_setup[slot].fib_382_price,m_setup[slot].fib_618_price);
      double zoneHigh=MathMax(m_setup[slot].fib_382_price,m_setup[slot].fib_618_price);
      if(!m_setup[slot].fib_touched && bar.low<=zoneHigh && bar.high>=zoneLow)
        {
         m_setup[slot].fib_touched=true;
         m_setup[slot].fib_touch_at=bar.time;
         m_setup[slot].fib_touch_known_at=knownAt;
         Emit(slot,"FIB_TOUCH",knownAt);
        }
      if(!m_setup[slot].fib_too_deep_measured && m_setup[slot].retracement_ratio>m_fib_max)
        {
         m_setup[slot].fib_too_deep_measured=true;
         Emit(slot,"FIB_TOO_DEEP",knownAt,m_reject_deep ? "EXCLUSION" : "MEASUREMENT","FIB_TOO_DEEP");
         if(m_reject_deep) Invalidate(slot,knownAt,"FIB_TOO_DEEP");
        }
      if(m_setup[slot].active && (d>0 ? bar.low<=m_setup[slot].wave1_start_price : bar.high>=m_setup[slot].wave1_start_price))
         Invalidate(slot,knownAt,"WAVE1_ORIGIN_BROKEN");
     }
   bool SameWave2(const W33Setup &s,const datetime time,const double price) const
     {
      // Equal-price retests can form a later confirmed swing without updating
      // the first extreme's time. They still belong to the same deepest W2.
      return time>=s.wave2_start_time && MathAbs(price-s.wave2_extreme_price)<=MathMax(1e-10,m_point*0.5);
     }
   void LoseLowerStructure(const int slot,const datetime knownAt,const string reason)
     {
      if(!m_setup[slot].lower_structure_confirmed) return;
      m_setup[slot].lower_structure_confirmed=false;
      m_setup[slot].lower_wave2_time=0;
      m_setup[slot].lower_wave2_price=0;
      Emit(slot,"LOWER_STRUCTURE_LOST",knownAt,"MEASUREMENT",reason);
      ChangeState(slot,WAVE2_RETRACEMENT,knownAt);
     }
   void CheckLowerMembership(const int slot,const datetime knownAt)
     {
      if(!m_strict_lifecycle || !m_setup[slot].active || m_setup[slot].signal_emitted || !m_setup[slot].lower_structure_confirmed) return;
      if(!SameWave2(m_setup[slot],m_setup[slot].lower_wave2_time,m_setup[slot].lower_wave2_price))
         LoseLowerStructure(slot,knownAt,"WAVE2_EXTREME_CHANGED");
     }
   bool PullbackKnownBefore(const int slot,const datetime barTime) const
     {
      if(m_require_fib) return m_setup[slot].fib_touched && m_setup[slot].fib_touch_at<barTime;
      return m_setup[slot].wave2_extreme_time>0 && m_setup[slot].wave2_extreme_time<barTime && m_setup[slot].retracement_ratio>0;
     }
   bool ObserveInitialProgress(const int slot,const MqlRates &bar,const datetime knownAt,const bool priorPullback)
     {
      if(!m_strict_lifecycle || !m_has[slot] || !m_setup[slot].active || m_setup[slot].signal_emitted ||
         m_setup[slot].position_open || !m_setup[slot].wave1_peak_fixed ||
         m_setup[slot].first_progress_bar_time>0) return false;
      // A first Fib touch and continuation within one candle have unknown
      // intrabar order. Only an earlier CLOSED lower candle qualifies.
      if(!priorPullback || bar.time<m_setup[slot].wave2_start_time) return false;
      if(m_setup[slot].direction*(bar.close-m_setup[slot].wave1_peak_price)<=0) return false;
      m_setup[slot].first_progress_bar_time=bar.time;
      m_setup[slot].first_progress_close_at=bar.time+PeriodSeconds(m_lower_tf);
      m_setup[slot].first_progress_known_at=knownAt;
      m_setup[slot].first_progress_price=bar.close;
      Emit(slot,"INITIAL_MOVE_PROGRESS",knownAt,"OBSERVATION",m_require_fib ? "CLOSED_BEYOND_WAVE1_AFTER_PRIOR_FIB" : "CLOSED_BEYOND_WAVE1_AFTER_PRIOR_PULLBACK");
      return true;
     }
   void StoreLowerPivots(const int slot,const W33Pivot &h1,const W33Pivot &h2,const W33Pivot &l1,const W33Pivot &l2)
     {
      m_setup[slot].lower_high1_time=h1.time;
      m_setup[slot].lower_high2_time=h2.time;
      m_setup[slot].lower_high1_price=h1.price;
      m_setup[slot].lower_high2_price=h2.price;
      m_setup[slot].lower_low1_time=l1.time;
      m_setup[slot].lower_low2_time=l2.time;
      m_setup[slot].lower_low1_price=l1.price;
      m_setup[slot].lower_low2_price=l2.price;
      m_setup[slot].lower_pivot_times=StringFormat("%I64d|%I64d|%I64d|%I64d",(long)h1.time,(long)h2.time,(long)l1.time,(long)l2.time);
      m_setup[slot].lower_pivot_prices=StringFormat("%.10f|%.10f|%.10f|%.10f",h1.price,h2.price,l1.price,l2.price);
     }
   void LowerStructure(const int slot,const datetime knownAt)
     {
      if(!m_has[slot] || !m_setup[slot].active || !m_setup[slot].wave1_peak_fixed || m_frozen[slot]) return;
      W33Pivot h1,h2,l1,l2;
      bool found=CounterPivots(m_lower,m_setup[slot].direction,m_setup[slot].wave2_start_time,knownAt,h1,h2,l1,l2);
      if(!found)
        {
         LoseLowerStructure(slot,knownAt,"LATEST_PIVOTS_NO_LONGER_COUNTERTREND");
         return;
        }
      datetime key=(datetime)MathMax((long)l2.time,(long)h2.time);
      W33Pivot end;
      if(m_setup[slot].direction>0) end=l2; else end=h2;
      if(m_strict_lifecycle && !SameWave2(m_setup[slot],end.time,end.price))
        {
         LoseLowerStructure(slot,knownAt,"LOWER_COUNTERTREND_OUTSIDE_WAVE2");
         if(m_rejected_structure_key[slot]!=key)
           {
            m_rejected_structure_key[slot]=key;
            StoreLowerPivots(slot,h1,h2,l1,l2);
            Emit(slot,"LOWER_STRUCTURE_REJECTED",knownAt,"MEASUREMENT","LOWER_COUNTERTREND_OUTSIDE_WAVE2");
           }
         return;
        }
      if(m_structure_key[slot]==key && m_setup[slot].lower_structure_confirmed) return;
      m_structure_key[slot]=key;
      m_setup[slot].lower_structure_confirmed=true;
      m_setup[slot].lower_structure_known_at=(datetime)MathMax((long)m_setup[slot].wave1_peak_known_at,(long)LatestKnown(h1,h2,l1,l2));
      m_setup[slot].trigger_line_price=m_setup[slot].direction>0 ? h2.price : l2.price;
      m_setup[slot].trigger_known_at=m_setup[slot].lower_structure_known_at;
      StoreLowerPivots(slot,h1,h2,l1,l2);
      m_setup[slot].lower_wave2_time=end.time;
      m_setup[slot].lower_wave2_price=end.price;
      ChangeState(slot,LOWER_COUNTERTREND,knownAt);
      Emit(slot,"LOWER_STRUCTURE_CONFIRMED",knownAt);
     }
   double TrendlineAt(const W33Setup &s,const datetime time) const
     {
      datetime t1=s.direction>0 ? s.lower_high1_time : s.lower_low1_time;
      datetime t2=s.direction>0 ? s.lower_high2_time : s.lower_low2_time;
      double p1=s.direction>0 ? s.lower_high1_price : s.lower_low1_price;
      double p2=s.direction>0 ? s.lower_high2_price : s.lower_low2_price;
      if(t2<=t1) return 0;
      return p2+(p2-p1)*(double)(time-t2)/(double)(t2-t1);
     }
   void InspectObstacle(const W33Pivot &p,const int slot,const double reference)
     {
      int d=m_setup[slot].direction;
      if(d*(p.price-reference)<=0) return;
      if(m_setup[slot].nearest_obstacle_price==0 || MathAbs(p.price-reference)<MathAbs(m_setup[slot].nearest_obstacle_price-reference))
        {
         m_setup[slot].nearest_obstacle_price=p.price;
         m_setup[slot].nearest_obstacle_tf=p.tf;
         m_setup[slot].nearest_obstacle_time=p.time;
         m_setup[slot].nearest_obstacle_known_at=p.known_at;
        }
     }
   void SnapshotObstacle(const int slot,const double reference)
     {
      m_setup[slot].nearest_obstacle_price=0;
      W33Pivot all[];
      GetObstacles(all);
      for(int j=0;j<ArraySize(all);j++) InspectObstacle(all[j],slot,reference);
      W33Pivot peak;
      ZeroMemory(peak);
      peak.price=m_setup[slot].wave1_peak_price;
      peak.time=m_setup[slot].wave1_peak_time;
      peak.known_at=m_setup[slot].wave1_peak_known_at;
      peak.tf=m_upper_tf;
      InspectObstacle(peak,slot,reference);
     }
   void Trigger(const int slot,const MqlRates &bar,const datetime knownAt)
     {
      if(!m_has[slot] || !m_setup[slot].active || !m_setup[slot].wave1_peak_fixed || !m_setup[slot].lower_structure_confirmed) return;
      if(m_strict_lifecycle && !m_setup[slot].signal_emitted && !SameWave2(m_setup[slot],m_setup[slot].lower_wave2_time,m_setup[slot].lower_wave2_price)) return;
      // A just-confirmed upper peak or lower swing cannot be used on the bar
      // whose close made it known. No historical candle is replayed as SIGNAL.
      if(bar.time<m_setup[slot].wave1_peak_known_at || bar.time<m_setup[slot].lower_structure_known_at) return;
      if(m_require_fib && !m_setup[slot].fib_touched) return;
      int n=ArraySize(m_lower.bars);
      if(n==0) return;
      MqlRates previous=m_lower.bars[n-1]; // Current bar is not appended yet.
      datetime closeAt=bar.time+PeriodSeconds(m_lower_tf);
      datetime previousClose=previous.time+PeriodSeconds(m_lower_tf);
      int d=m_setup[slot].direction;
      double pivotLine=d>0 ? m_setup[slot].lower_high2_price : m_setup[slot].lower_low2_price;
      double trendLine=TrendlineAt(m_setup[slot],closeAt);
      double previousTrendLine=TrendlineAt(m_setup[slot],previousClose);
      bool pivotHit=m_setup[slot].pivot_trigger_at==0 && d*(bar.close-pivotLine)>0 && d*(previous.close-pivotLine)<=0;
      bool trendHit=m_setup[slot].trendline_trigger_at==0 && trendLine>0 && d*(bar.close-trendLine)>0 && d*(previous.close-previousTrendLine)<=0;
      if(pivotHit)
        {
         m_setup[slot].pivot_trigger_at=closeAt;
         m_setup[slot].pivot_trigger_known_at=knownAt;
         m_setup[slot].pivot_trigger_price=bar.close;
        }
      if(trendHit)
        {
         m_setup[slot].trendline_trigger_at=closeAt;
         m_setup[slot].trendline_trigger_known_at=knownAt;
         m_setup[slot].trendline_trigger_price=bar.close;
        }
      if(m_setup[slot].pivot_trigger_at>0 && m_setup[slot].trendline_trigger_at>0)
         m_setup[slot].trigger_delta_points=(m_setup[slot].pivot_trigger_price-m_setup[slot].trendline_trigger_price)/m_point;
      if(pivotHit) Emit(slot,"PIVOT_TRIGGER",knownAt);
      if(trendHit) Emit(slot,"TRENDLINE_TRIGGER",knownAt);
      if(m_setup[slot].signal_emitted) return;
      bool selected=(m_mode==W33_PIVOT_BREAK && pivotHit) || (m_mode==W33_TRENDLINE_BREAK && trendHit) || (m_mode==W33_FIRST_BREAK && (pivotHit || trendHit));
      if(!selected) return;
      // A diagnostic hit from the unselected trigger must never change the
      // selected arm's subsequent swing tracking. Freeze only at its SIGNAL.
      m_frozen[slot]=true;
      // Same-bar ties are explicitly deterministic: pivot wins FIRST_BREAK.
      bool usePivot=(m_mode==W33_PIVOT_BREAK || (m_mode==W33_FIRST_BREAK && pivotHit));
      m_setup[slot].trigger_type=usePivot ? "PIVOT_BREAK" : "TRENDLINE_BREAK";
      m_setup[slot].trigger_line_price=usePivot ? pivotLine : trendLine;
      m_setup[slot].trigger_known_at=m_setup[slot].lower_structure_known_at;
      m_setup[slot].trigger_bar_time=bar.time;
      m_setup[slot].signal_at=closeAt;
      m_setup[slot].signal_known_at=knownAt;
      m_setup[slot].signal_emitted=true;
      m_setup[slot].entry_price=bar.close; // Reference only; execution layer uses next available quote.
      m_setup[slot].entry_status="SIGNAL";
      m_setup[slot].h1_direction=H1Direction(d);
      double range=bar.high-bar.low;
      m_setup[slot].candle_body_ratio=range>0 ? MathAbs(bar.close-bar.open)/range : 0;
      SnapshotObstacle(slot,bar.close);
      ChangeState(slot,LOWER_REVERSAL_TRIGGER,knownAt);
      Emit(slot,"SIGNAL",knownAt);
      ChangeState(slot,RESISTANCE_AND_RISK_CHECK,knownAt);
     }
   void UpdateUpper(const MqlRates &bar,const datetime knownAt,const W33Pivot &confirmed[])
     {
      for(int slot=0;slot<2;slot++)
        {
         if(!m_has[slot] || !m_setup[slot].active) continue;
         m_setup[slot].upper_bars_elapsed++;
         if(m_timeout>0 && m_setup[slot].upper_bars_elapsed>=m_timeout)
           {
            string reason=m_setup[slot].wave1_peak_fixed && !m_setup[slot].signal_emitted ? "TIMEOUT|NO_LOWER_REVERSAL" : "TIMEOUT";
            Invalidate(slot,knownAt,reason);
            if(!m_setup[slot].active) continue;
           }
         int d=m_setup[slot].direction;
         if(!m_setup[slot].position_open && (d>0 ? bar.low<=m_setup[slot].wave1_start_price : bar.high>=m_setup[slot].wave1_start_price))
           {
            Invalidate(slot,knownAt,"WAVE1_ORIGIN_BROKEN");
            continue;
           }
         if(m_setup[slot].wave1_peak_fixed) continue;
         double price=d>0 ? bar.high : bar.low;
         if(d*(price-m_setup[slot].wave1_provisional_price)>0)
           {
            m_setup[slot].wave1_provisional_price=price;
            m_setup[slot].wave1_provisional_time=bar.time;
            Emit(slot,"WAVE1_PROVISIONAL",knownAt);
           }
         for(int j=0;j<ArraySize(confirmed);j++)
           {
            W33Pivot p=confirmed[j];
            if(p.is_high!=(d>0) || p.time<m_setup[slot].upper_break_bar_time || d*(p.price-m_setup[slot].wave1_provisional_price)<0) continue;
            double span=d*(p.price-m_setup[slot].wave1_start_price);
            if(span<=0) continue;
            m_setup[slot].wave1_peak_time=p.time;
            m_setup[slot].wave1_peak_price=p.price;
            m_setup[slot].wave1_peak_known_at=knownAt;
            m_setup[slot].wave1_peak_fixed=true;
            m_setup[slot].wave2_start_time=p.time+PeriodSeconds(m_upper_tf);
            m_setup[slot].fib_382_price=p.price-d*span*m_fib_min;
            m_setup[slot].fib_618_price=p.price-d*span*m_fib_max;
            Emit(slot,"WAVE1_PEAK_CONFIRMED",knownAt);
            ChangeState(slot,WAVE2_RETRACEMENT,knownAt);
            // Characterize already closed retracement candles at CURRENT knowledge
            // time. These observations never run the Trigger() function.
            int lowerCount=ArraySize(m_lower.bars),first=lowerCount;
            while(first>0 && m_lower.bars[first-1].time>=m_setup[slot].wave2_start_time) first--;
            for(int k=first;k<lowerCount && m_setup[slot].active;k++)
              {
               bool priorPullback=PullbackKnownBefore(slot,m_lower.bars[k].time);
               ObserveWave2(slot,m_lower.bars[k],knownAt);
               if(ObserveInitialProgress(slot,m_lower.bars[k],knownAt,priorPullback))
                  Invalidate(slot,knownAt,"INITIAL_MOVE_MISSED");
              }
            LowerStructure(slot,knownAt);
            break;
           }
        }
     }
   void AppendObstacles(const CWave33Series &series,W33Pivot &result[]) const
     {
      int n=ArraySize(result),count=ArraySize(series.pivots);
      ArrayResize(result,n+count);
      for(int j=0;j<count;j++) result[n+j]=series.pivots[j];
     }

public:
   CWave33Engine(void)
     {
      m_upper_tf=PERIOD_M15;
      m_lower_tf=PERIOD_M5;
      m_left=2; m_right=2; m_timeout=96;
      m_fib_min=0.382; m_fib_max=0.618;
      m_point=0.01;
      m_reject_deep=false; m_require_fib=true;
      m_strict_lifecycle=true;
      m_mode=W33_PIVOT_BREAK;
      m_serial=0;
     }
   void Configure(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower,const int left,const int right,
                  const double fibMin,const double fibMax,const int timeoutUpperBars,
                  const bool rejectDeep=false,const bool requireFib=true)
     {
      m_upper_tf=upper; m_lower_tf=lower;
      m_left=(int)MathMax(1,left); m_right=(int)MathMax(1,right);
      m_fib_min=fibMin; m_fib_max=fibMax;
      m_timeout=timeoutUpperBars;
      m_reject_deep=rejectDeep; m_require_fib=requireFib;
     }
   void SetPoint(const double point) { if(point>0) m_point=point; }
   void SetTriggerMode(const W33TriggerMode mode) { m_mode=mode; }
   void SetLifecyclePolicy(const bool strict=true) { m_strict_lifecycle=strict; }
   void Reset(const string symbol)
     {
      m_symbol=symbol; m_serial=0;
      m_upper.Reset(m_upper_tf);
      m_lower.Reset(m_lower_tf);
      m_h1.Reset(PERIOD_H1);
      m_m15.Reset(PERIOD_M15);
      ArrayResize(m_events,0);
      for(int i=0;i<2;i++)
        {
         ZeroMemory(m_setup[i]);
         m_setup[i].state=SEARCH_STRUCTURE;
         m_setup[i].symbol=symbol;
         m_setup[i].direction=i==0 ? 1 : -1;
         m_setup[i].upper_tf=m_upper_tf;
         m_setup[i].lower_tf=m_lower_tf;
         m_has[i]=false; m_frozen[i]=false;
         m_last_break[i]=0; m_structure_key[i]=0;
         m_rejected_structure_key[i]=0;
        }
     }
   bool Feed(const ENUM_TIMEFRAMES tf,const MqlRates &bar,const datetime knownAt)
     {
      W33Pivot confirmed[];
      if(tf==m_upper_tf)
        {
         if(!m_upper.Append(bar,knownAt,m_left,m_right,confirmed)) return false;
         PivotEvents(confirmed);
         UpdateUpper(bar,knownAt,confirmed);
         Search(bar,knownAt);
         return true;
        }
      if(tf==m_lower_tf)
        {
         int n=ArraySize(m_lower.bars);
         if(knownAt<bar.time+PeriodSeconds(tf) || (n>0 && bar.time<=m_lower.bars[n-1].time)) return false;
         // Extreme and Fib touch on the closing bar are observable now. The
         // trigger anchors themselves must already have existed at bar open.
         for(int slot=0;slot<2;slot++)
            if(m_has[slot] && m_setup[slot].active)
              {
               bool priorPullback=PullbackKnownBefore(slot,bar.time);
               ObserveWave2(slot,bar,knownAt);
               CheckLowerMembership(slot,knownAt);
               bool progressed=ObserveInitialProgress(slot,bar,knownAt,priorPullback);
               Trigger(slot,bar,knownAt);
               // Let a valid, pre-known initial reversal trigger on this very
               // close. If it did not, the old W1/W2 cannot be reused later.
               if(progressed && !m_setup[slot].signal_emitted)
                  Invalidate(slot,knownAt,"INITIAL_MOVE_MISSED");
              }
         if(!m_lower.Append(bar,knownAt,m_left,m_right,confirmed)) return false;
         PivotEvents(confirmed);
         for(int slot=0;slot<2;slot++) LowerStructure(slot,knownAt);
         return true;
        }
      if(tf==PERIOD_H1)
        {
         bool accepted=m_h1.Append(bar,knownAt,m_left,m_right,confirmed);
         if(accepted) PivotEvents(confirmed);
         return accepted;
        }
      if(tf==PERIOD_M15)
        {
         bool accepted=m_m15.Append(bar,knownAt,m_left,m_right,confirmed);
         if(accepted) PivotEvents(confirmed);
         return accepted;
        }
      return false;
     }
   int Drain(W33Event &events[])
     {
      int n=ArraySize(m_events);
      ArrayResize(events,n);
      for(int j=0;j<n;j++) events[j]=m_events[j];
      ArrayResize(m_events,0);
      return n;
     }
   bool GetActive(const int direction,W33Setup &s) const
     {
      int i=Slot(direction);
      s=m_setup[i];
      return m_has[i] && m_setup[i].active;
     }
   string H1Direction(const int direction) const
     {
      W33Pivot h1,h2,l1,l2;
      if(!m_h1.Latest(true,h2) || !m_h1.Latest(true,h1,1) || !m_h1.Latest(false,l2) || !m_h1.Latest(false,l1,1)) return "H1_RANGE";
      int trend=0;
      if(h2.price>h1.price && l2.price>l1.price) trend=1;
      if(h2.price<h1.price && l2.price<l1.price) trend=-1;
      if(trend==0) return "H1_RANGE";
      return trend==direction ? "WITH_H1" : "AGAINST_H1";
     }
   int GetObstacles(W33Pivot &pivots[]) const
     {
      ArrayResize(pivots,0);
      AppendObstacles(m_upper,pivots);
      if(m_lower_tf==PERIOD_M5) AppendObstacles(m_lower,pivots);
      AppendObstacles(m_h1,pivots);
      if(m_upper_tf!=PERIOD_M15) AppendObstacles(m_m15,pivots);
      return ArraySize(pivots);
     }
   bool MarkExecution(const string setupId,const bool positionOpen,const datetime knownAt)
     {
      for(int i=0;i<2;i++)
         if(m_has[i] && m_setup[i].setup_id==setupId)
           {
            m_setup[i].position_open=positionOpen;
            if(positionOpen)
              {
               m_setup[i].entry_status="POSITION_OPEN";
               ChangeState(i,POSITION_TRACKING,knownAt);
               Emit(i,"POSITION_TRACKING",knownAt);
              }
            else
              {
               m_setup[i].active=false;
               m_setup[i].entry_status="COMPLETED";
               Emit(i,"COMPLETED",knownAt);
              }
            return true;
           }
      return false;
     }
  };
#endif
