#ifndef WAVE33_VISUAL_ENGINE_MQH
#define WAVE33_VISUAL_ENGINE_MQH
#include "Types.mqh"
#include "ConnectedPair.mqh"

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
   bool m_reject_deep,m_require_fib,m_strict_lifecycle,m_reject_deep_close;
   bool m_extend_wave1;
   bool m_cancel_connected_opposite,m_skip_connected_pair,m_order_submitted[2];
   W33TriggerMode m_mode;
   W33LowerRecognitionMode m_lower_recognition;
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
   int FirstPivotAt(const CWave33Series &series,const datetime from) const
     {
      int left=0,right=ArraySize(series.pivots);
      while(left<right)
        {
         int mid=left+(right-left)/2;
         if(series.pivots[mid].time<from) left=mid+1; else right=mid;
        }
      return left;
     }
   bool AmbiguousPivot(const CWave33Series &series,const int index,const datetime knownBy) const
     {
      W33Pivot p=series.pivots[index];
      // An outside candle can be both a high and low pivot. Its OHLC does not
      // tell us which occurred first; neither side may invent an ordered leg.
      for(int j=index-1;j>=0 && series.pivots[j].time==p.time;j--)
         if(series.pivots[j].known_at<=knownBy && series.pivots[j].is_high!=p.is_high) return true;
      for(int j=index+1;j<ArraySize(series.pivots) && series.pivots[j].time==p.time;j++)
         if(series.pivots[j].known_at<=knownBy && series.pivots[j].is_high!=p.is_high) return true;
      return false;
     }
   bool NormalizedCounterPivots(const CWave33Series &series,const int direction,const datetime from,
                                const datetime knownBy,W33Pivot &h1,W33Pivot &h2,W33Pivot &l1,W33Pivot &l2,
                                string &unmet) const
     {
      W33Pivot normalized[];
      bool ambiguous=false;
      for(int j=FirstPivotAt(series,from);j<ArraySize(series.pivots);j++)
        {
         W33Pivot p=series.pivots[j];
         if(p.time<from || p.known_at>knownBy) continue;
         if(AmbiguousPivot(series,j,knownBy))
           {
            // Reset at an unordered outside swing, rather than bridge across
            // it with an invented H/L sequence. Later unambiguous legs can form
            // a new complete structure. Raw pivot events remain unchanged.
            ArrayResize(normalized,0);
            ambiguous=true;
            continue;
           }
         int n=ArraySize(normalized);
         if(n>0 && normalized[n-1].is_high==p.is_high)
           {
            if(p.is_high ? p.price>normalized[n-1].price : p.price<normalized[n-1].price)
               normalized[n-1]=p;
            continue;
           }
         ArrayResize(normalized,n+1);
         normalized[n]=p;
        }
      int hc=0,lc=0;
      for(int j=ArraySize(normalized)-1;j>=0;j--)
        {
         W33Pivot p=normalized[j];
         if(p.is_high && hc<2) { if(hc==0) h2=p; else h1=p; hc++; }
         if(!p.is_high && lc<2) { if(lc==0) l2=p; else l1=p; lc++; }
         if(hc==2 && lc==2) break;
        }
      if(hc<2 || lc<2)
        {
         unmet=ambiguous ? "AMBIGUOUS_PIVOT_ORDER" : "INCOMPLETE_COUNTERTREND";
         return false;
        }
      bool aligned=direction>0 ? h2.price<h1.price && l2.price<l1.price : h2.price>h1.price && l2.price>l1.price;
      if(!aligned) { unmet="COUNTERTREND_PRICES_NOT_ALIGNED"; return false; }
      unmet="";
      return true;
     }
   bool SimpleReactionPivots(const int slot,const datetime knownAt,W33Pivot &extreme,W33Pivot &reaction,string &unmet) const
     {
      bool foundExtreme=false;
      bool ambiguous=false;
      for(int j=FirstPivotAt(m_lower,m_setup[slot].wave2_start_time);j<ArraySize(m_lower.pivots);j++)
        {
         W33Pivot p=m_lower.pivots[j];
         if(p.time<m_setup[slot].wave2_start_time || p.known_at>knownAt) continue;
         if(AmbiguousPivot(m_lower,j,knownAt)) { ambiguous=true; continue; }
         if(!foundExtreme)
           {
            if(p.is_high==(m_setup[slot].direction<0) && SameWave2(m_setup[slot],p.time,p.price))
              { extreme=p; foundExtreme=true; }
            continue;
           }
         if(p.time>extreme.time && p.is_high!=extreme.is_high)
           {
            reaction=p;
            unmet="";
            return true; // Freeze the FIRST confirmed reaction, never chase later levels.
           }
        }
      unmet=ambiguous ? "AMBIGUOUS_PIVOT_ORDER" : (foundExtreme ? "WAITING_REACTION_PIVOT" : "WAITING_WAVE2_PIVOT");
      return false;
     }
   datetime LatestKnown(const W33Pivot &h1,const W33Pivot &h2,const W33Pivot &l1,const W33Pivot &l2) const
     {
      return (datetime)MathMax(MathMax((long)h1.known_at,(long)h2.known_at),MathMax((long)l1.known_at,(long)l2.known_at));
     }
   void CancelConnectedOpposite(const int newSlot,const datetime knownAt)
     {
      int oldSlot=1-newSlot;
      if((!m_cancel_connected_opposite && !m_skip_connected_pair) || !m_has[oldSlot] ||
         !W33ConnectedOppositeUnordered(m_setup[oldSlot],m_setup[newSlot],m_order_submitted[oldSlot],knownAt,m_point)) return;
      if(m_skip_connected_pair)
        {
         if(!W33InvalidateConnectedPairUnordered(m_setup[oldSlot],m_setup[newSlot],
                                                m_order_submitted[oldSlot],m_order_submitted[newSlot],knownAt,m_point)) return;
         Emit(oldSlot,"INVALIDATE",knownAt,"EXCLUSION","CONNECTED_OPPOSITE_W1_BOTH");
         Emit(newSlot,"INVALIDATE",knownAt,"EXCLUSION","CONNECTED_OPPOSITE_W1_BOTH");
         return;
        }
      m_setup[oldSlot].connected_opposite_cancelled=true;
      m_setup[oldSlot].connected_opposite_setup_id=m_setup[newSlot].setup_id;
      m_setup[oldSlot].connected_opposite_known_at=knownAt;
      m_setup[oldSlot].connected_shared_time=m_setup[oldSlot].wave1_peak_time;
      m_setup[oldSlot].connected_shared_price=m_setup[oldSlot].wave1_peak_price;
      m_setup[oldSlot].active=false;
      m_setup[oldSlot].entry_status="INVALIDATED";
      m_setup[oldSlot].skip_reason="CONNECTED_OPPOSITE_W1_CANDIDATE";
      // An unsubmitted diagnostic signal is also an exclusion. Do not send it
      // through Invalidate(), whose signalled branch normally means COMPLETED.
      Emit(oldSlot,"INVALIDATE",knownAt,"EXCLUSION","CONNECTED_OPPOSITE_W1_CANDIDATE");
     }
   void Create(const int direction,const MqlRates &bar,const datetime knownAt,
               const W33Pivot &level,const W33Pivot &origin,const bool adopted=true)
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
      m_setup[i].lower_recognition=m_lower_recognition==W33_STRICT_COUNTERTREND ? "STRICT_COUNTERTREND" : "NORMALIZED_COUNTERTREND";
      m_setup[i].lower_unmet_reason="WAITING_WAVE1_CONFIRMATION";
      m_setup[i].h1_direction=H1Direction(direction);
      m_has[i]=true;
      m_frozen[i]=false;
      m_order_submitted[i]=false;
      m_structure_key[i]=0;
      m_rejected_structure_key[i]=0;
      m_last_break[i]=level.time;
      Emit(i,"WAVE1_BREAK",knownAt);
      if(adopted) CancelConnectedOpposite(i,knownAt);
      // A paired exclusion still retains the observable WAVE1_BREAK, but it
      // must not resume tracking or become a signal on any subsequent feed.
      if(!m_setup[i].active) return;
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
            bool submitted=m_order_submitted[side];
            datetime structureKey=m_structure_key[side];
            datetime rejectedKey=m_rejected_structure_key[side];
            Create(direction,bar,knownAt,level,origin,false);
            m_setup[side].active=false;
            m_setup[side].entry_status="SKIPPED";
            m_setup[side].skip_reason="ACTIVE_SETUP_SAME_DIRECTION";
            Emit(side,"SKIP",knownAt,"EXCLUSION","ACTIVE_SETUP_SAME_DIRECTION");
            m_setup[side]=previousSetup;
            m_frozen[side]=frozen;
            m_order_submitted[side]=submitted;
            m_structure_key[side]=structureKey;
            m_rejected_structure_key[side]=rejectedKey;
            // m_last_break intentionally retains the consumed new level.
           }
         else Create(direction,bar,knownAt,level,origin);
        }
     }
   bool MinimumRetracementReached(const int slot,const MqlRates &bar) const
     {
      // A gap wholly beyond the band is still a qualifying pullback for the
      // extension lock. The original exact-band FIB_TOUCH entry rule is separate.
      int d=m_setup[slot].direction;
      double price=d>0 ? bar.low : bar.high;
      double span=d*(m_setup[slot].wave1_peak_price-m_setup[slot].wave1_start_price);
      return span>0 && d*(price-m_setup[slot].fib_382_price)<=span*1e-12;
     }
   void ObserveExtensionLock(const int slot,const MqlRates &bar,const datetime knownAt,const bool upperBar)
     {
      if(!m_extend_wave1 || !m_has[slot] || !m_setup[slot].active || !m_setup[slot].wave1_peak_fixed ||
         m_setup[slot].wave1_extension_locked || m_setup[slot].signal_emitted || m_setup[slot].position_open ||
         bar.time<m_setup[slot].wave2_start_time || !MinimumRetracementReached(slot,bar)) return;
      int d=m_setup[slot].direction;
      double continuation=d>0 ? bar.high : bar.low;
      bool ambiguous=upperBar && d*(continuation-m_setup[slot].wave1_peak_price)>0;
      m_setup[slot].wave1_extension_locked=true;
      m_setup[slot].wave1_extension_lock_bar_time=bar.time;
      m_setup[slot].wave1_extension_lock_known_at=knownAt;
      m_setup[slot].wave1_extension_lock_reason=ambiguous ? "AMBIGUOUS_EXTREME_AND_FIB_TOUCH" : "MIN_FIB_RETRACEMENT_OBSERVED";
      Emit(slot,"WAVE1_EXTENSION_LOCKED",knownAt,"OBSERVATION",m_setup[slot].wave1_extension_lock_reason);
     }
   bool StartWave1Extension(const int slot,const MqlRates &bar,const datetime knownAt)
     {
      if(!m_extend_wave1 || !m_has[slot] || !m_setup[slot].active || !m_setup[slot].wave1_peak_fixed ||
         m_setup[slot].wave1_extension_locked || m_setup[slot].fib_touched ||
         m_setup[slot].signal_emitted || m_setup[slot].position_open ||
         bar.time<m_setup[slot].wave2_start_time) return false;
      int d=m_setup[slot].direction;
      double price=d>0 ? bar.high : bar.low;
      if(d*(price-m_setup[slot].wave1_peak_price)<=0) return false;
      // Snapshot the entire prior revision before changing any anchor, W2,
      // lower-line, risk, or obstacle field. Event rows retain all provenance.
      Emit(slot,"WAVE1_EXTENSION_PREVIOUS_ANCHORS",knownAt,"OBSERVATION","PRE_MIN_FIB_NEW_EXTREME");
      W33Setup previous=m_setup[slot];
      ZeroMemory(m_setup[slot]);
      m_setup[slot].setup_id=previous.setup_id;
      m_setup[slot].symbol=previous.symbol;
      m_setup[slot].upper_tf=previous.upper_tf;
      m_setup[slot].lower_tf=previous.lower_tf;
      m_setup[slot].direction=previous.direction;
      m_setup[slot].state=WAVE1_TOP_TRACKING;
      m_setup[slot].active=true;
      m_setup[slot].candidate_detected_at=previous.candidate_detected_at;
      m_setup[slot].upper_break_level=previous.upper_break_level;
      m_setup[slot].upper_break_confirmed_at=previous.upper_break_confirmed_at;
      m_setup[slot].upper_break_bar_time=previous.upper_break_bar_time;
      m_setup[slot].upper_break_level_time=previous.upper_break_level_time;
      m_setup[slot].upper_break_level_known_at=previous.upper_break_level_known_at;
      m_setup[slot].wave1_start_time=previous.wave1_start_time;
      m_setup[slot].wave1_start_price=previous.wave1_start_price;
      m_setup[slot].wave1_start_known_at=previous.wave1_start_known_at;
      m_setup[slot].wave1_provisional_time=bar.time;
      m_setup[slot].wave1_provisional_price=price;
      m_setup[slot].wave1_revision=previous.wave1_revision+1;
      m_setup[slot].wave1_extension_pending=true;
      m_setup[slot].wave1_extension_started_at=knownAt;
      m_setup[slot].wave1_previous_peak_time=previous.wave1_peak_time;
      m_setup[slot].wave1_previous_peak_price=previous.wave1_peak_price;
      m_setup[slot].wave1_previous_peak_known_at=previous.wave1_peak_known_at;
      m_setup[slot].upper_bars_elapsed=previous.upper_bars_elapsed;
      m_setup[slot].entry_status="CANDIDATE";
      m_setup[slot].lower_entry_stage="COUNTERTREND_NEGATION";
      m_setup[slot].lower_recognition=m_lower_recognition==W33_STRICT_COUNTERTREND ? "STRICT_COUNTERTREND" : "NORMALIZED_COUNTERTREND";
      m_setup[slot].lower_unmet_reason="WAITING_EXTENDED_WAVE1_CONFIRMATION";
      m_setup[slot].h1_direction=H1Direction(d);
      m_frozen[slot]=false;
      m_structure_key[slot]=0;
      m_rejected_structure_key[slot]=0;
      Emit(slot,"WAVE1_EXTENSION_STARTED",knownAt,"OBSERVATION","PRE_MIN_FIB_NEW_EXTREME");
      return true;
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
      ObserveExtensionLock(slot,bar,knownAt,false);
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
   void ObserveUpperFibClose(const int slot,const MqlRates &bar,const datetime knownAt)
     {
      if(!m_has[slot] || !m_setup[slot].active || !m_setup[slot].wave1_peak_fixed ||
         m_setup[slot].signal_emitted || m_setup[slot].position_open || m_setup[slot].fib_close_bar_time>0 ||
         bar.time<m_setup[slot].wave2_start_time || knownAt<bar.time+PeriodSeconds(m_upper_tf) ||
         knownAt<m_setup[slot].wave1_peak_known_at) return;
      // Strictly beyond the fixed 61.8% (or configured maximum) boundary.
      // A wick beyond it or a close exactly on it is not a close violation.
      int d=m_setup[slot].direction;
      double span=d*(m_setup[slot].wave1_peak_price-m_setup[slot].wave1_start_price);
      if(span<=0) return;
      // Decimal prices and the multiplication by 0.618 may differ by one
      // binary rounding unit at mathematical equality. This is arithmetic
      // tolerance only, many orders smaller than a tradable price point.
      if(d*(bar.close-m_setup[slot].fib_618_price)>=-span*1e-12) return;
      m_setup[slot].fib_close_bar_time=bar.time;
      m_setup[slot].fib_close_at=bar.time+PeriodSeconds(m_upper_tf);
      m_setup[slot].fib_close_known_at=knownAt;
      m_setup[slot].fib_close_price=bar.close;
      m_setup[slot].fib_close_ratio=d*(m_setup[slot].wave1_peak_price-bar.close)/span;
      Emit(slot,"FIB_CLOSE_TOO_DEEP",knownAt,m_reject_deep_close ? "EXCLUSION" : "MEASUREMENT","FIB_CLOSE_TOO_DEEP");
      if(m_reject_deep_close) Invalidate(slot,knownAt,"FIB_CLOSE_TOO_DEEP");
     }
   bool SameWave2(const W33Setup &s,const datetime time,const double price) const
     {
      // Equal-price retests can form a later confirmed swing without updating
      // the first extreme's time. They still belong to the same deepest W2.
      return time>=s.wave2_start_time && MathAbs(price-s.wave2_extreme_price)<=MathMax(1e-10,m_point*0.5);
     }
   void LoseLowerStructure(const int slot,const datetime knownAt,const string reason)
     {
      m_setup[slot].lower_unmet_reason=reason;
      if(!m_setup[slot].lower_structure_confirmed) return;
      m_setup[slot].lower_structure_confirmed=false;
      m_setup[slot].lower_wave2_time=0;
      m_setup[slot].lower_wave2_price=0;
      Emit(slot,"LOWER_STRUCTURE_LOST",knownAt,"MEASUREMENT",reason);
      ChangeState(slot,WAVE2_RETRACEMENT,knownAt);
     }
   void CheckLowerMembership(const int slot,const datetime knownAt)
     {
      if((!m_strict_lifecycle && m_setup[slot].lower_recognition!="SIMPLE_REACTION_BREAK") || !m_setup[slot].active || m_setup[slot].signal_emitted || !m_setup[slot].lower_structure_confirmed) return;
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
      string unmet="LATEST_PIVOTS_NO_LONGER_COUNTERTREND";
      bool found=m_lower_recognition==W33_STRICT_COUNTERTREND ?
                 CounterPivots(m_lower,m_setup[slot].direction,m_setup[slot].wave2_start_time,knownAt,h1,h2,l1,l2) :
                 NormalizedCounterPivots(m_lower,m_setup[slot].direction,m_setup[slot].wave2_start_time,knownAt,h1,h2,l1,l2,unmet);
      W33Pivot end;
      if(found)
        {
         if(m_setup[slot].direction>0) end=l2; else end=h2;
         if(m_strict_lifecycle && !SameWave2(m_setup[slot],end.time,end.price))
           {
            datetime rejectedKey=(datetime)MathMax((long)l2.time,(long)h2.time);
            bool preserveSimple=m_lower_recognition==W33_NORMALIZED_OR_SIMPLE && m_setup[slot].lower_structure_confirmed &&
                                m_setup[slot].lower_recognition=="SIMPLE_REACTION_BREAK" &&
                                SameWave2(m_setup[slot],m_setup[slot].lower_wave2_time,m_setup[slot].lower_wave2_price);
            W33Setup current=m_setup[slot];
            if(!preserveSimple) LoseLowerStructure(slot,knownAt,"LOWER_COUNTERTREND_OUTSIDE_WAVE2");
            if(m_rejected_structure_key[slot]!=rejectedKey)
              {
               m_rejected_structure_key[slot]=rejectedKey;
               StoreLowerPivots(slot,h1,h2,l1,l2);
               if(preserveSimple)
                 {
                  m_setup[slot].lower_recognition="NORMALIZED_COUNTERTREND";
                  m_setup[slot].lower_entry_stage="COUNTERTREND_NEGATION";
                  m_setup[slot].lower_unmet_reason="LOWER_COUNTERTREND_OUTSIDE_WAVE2";
                 }
               Emit(slot,"LOWER_STRUCTURE_REJECTED",knownAt,"MEASUREMENT","LOWER_COUNTERTREND_OUTSIDE_WAVE2");
              }
            if(preserveSimple) m_setup[slot]=current;
            found=false;
            unmet="LOWER_COUNTERTREND_OUTSIDE_WAVE2";
           }
        }
      if(!found)
        {
         if(m_lower_recognition!=W33_NORMALIZED_OR_SIMPLE)
           { LoseLowerStructure(slot,knownAt,unmet); return; }
         W33Pivot extreme,reaction;
         if(!SimpleReactionPivots(slot,knownAt,extreme,reaction,unmet))
           { LoseLowerStructure(slot,knownAt,unmet); return; }
         // A simple reaction is an explicitly different hypothesis: deepest
         // W2 pivot -> first opposite pivot -> fresh closed price cross. It is
         // not labeled as a complete countertrend or a lower 1->2->3 count.
         if(m_setup[slot].lower_structure_confirmed && m_setup[slot].lower_recognition=="SIMPLE_REACTION_BREAK" &&
            m_structure_key[slot]==reaction.time)
           {
            m_setup[slot].lower_unmet_reason=m_mode==W33_TRENDLINE_BREAK ? "SIMPLE_REQUIRES_PIVOT_TRIGGER" : "WAITING_FRESH_REACTION_CROSS";
            return;
           }
         m_structure_key[slot]=reaction.time;
         m_setup[slot].lower_recognition="SIMPLE_REACTION_BREAK";
         m_setup[slot].lower_entry_stage="SIMPLE_REACTION_BREAK";
         m_setup[slot].lower_unmet_reason=m_mode==W33_TRENDLINE_BREAK ? "SIMPLE_REQUIRES_PIVOT_TRIGGER" : "WAITING_FRESH_REACTION_CROSS";
         m_setup[slot].lower_structure_confirmed=true;
         m_setup[slot].lower_structure_known_at=(datetime)MathMax((long)m_setup[slot].wave1_peak_known_at,MathMax((long)extreme.known_at,(long)reaction.known_at));
         m_setup[slot].trigger_line_price=reaction.price;
         m_setup[slot].trigger_known_at=m_setup[slot].lower_structure_known_at;
         m_setup[slot].lower_high1_time=0; m_setup[slot].lower_high1_price=0;
         m_setup[slot].lower_low1_time=0; m_setup[slot].lower_low1_price=0;
         m_setup[slot].lower_high2_time=m_setup[slot].direction>0 ? reaction.time : extreme.time;
         m_setup[slot].lower_high2_price=m_setup[slot].direction>0 ? reaction.price : extreme.price;
         m_setup[slot].lower_low2_time=m_setup[slot].direction>0 ? extreme.time : reaction.time;
         m_setup[slot].lower_low2_price=m_setup[slot].direction>0 ? extreme.price : reaction.price;
         m_setup[slot].lower_pivot_times=StringFormat("%I64d|%I64d",(long)extreme.time,(long)reaction.time);
         m_setup[slot].lower_pivot_prices=StringFormat("%.10f|%.10f",extreme.price,reaction.price);
         m_setup[slot].lower_wave2_time=extreme.time;
         m_setup[slot].lower_wave2_price=extreme.price;
         ChangeState(slot,LOWER_COUNTERTREND,knownAt);
         Emit(slot,"LOWER_STRUCTURE_CONFIRMED",knownAt,"OBSERVATION","SIMPLE_REACTION_BREAK");
         return;
        }
      string recognition=m_lower_recognition==W33_STRICT_COUNTERTREND ? "STRICT_COUNTERTREND" : "NORMALIZED_COUNTERTREND";
      datetime key=(datetime)MathMax((long)l2.time,(long)h2.time);
      if(m_structure_key[slot]==key && m_setup[slot].lower_structure_confirmed && m_setup[slot].lower_recognition==recognition)
        { m_setup[slot].lower_unmet_reason="WAITING_SELECTED_BREAK"; return; }
      m_structure_key[slot]=key;
      m_setup[slot].lower_recognition=recognition;
      m_setup[slot].lower_entry_stage="COUNTERTREND_NEGATION";
      m_setup[slot].lower_unmet_reason="WAITING_SELECTED_BREAK";
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
         m_setup[slot].nearest_obstacle_source=p.is_high ? "SWING_HIGH" : "SWING_LOW";
         m_setup[slot].nearest_obstacle_is_high=p.is_high;
        }
     }
   void SnapshotObstacle(const int slot,const double reference)
     {
      m_setup[slot].nearest_obstacle_price=0;
      m_setup[slot].nearest_obstacle_tf=m_upper_tf;
      m_setup[slot].nearest_obstacle_time=0;
      m_setup[slot].nearest_obstacle_known_at=0;
      m_setup[slot].nearest_obstacle_source="";
      m_setup[slot].nearest_obstacle_is_high=false;
      W33Pivot all[];
      GetObstacles(all);
      for(int j=0;j<ArraySize(all);j++) InspectObstacle(all[j],slot,reference);
      W33Pivot peak;
      ZeroMemory(peak);
      peak.price=m_setup[slot].wave1_peak_price;
      peak.time=m_setup[slot].wave1_peak_time;
      peak.known_at=m_setup[slot].wave1_peak_known_at;
      peak.tf=m_upper_tf;
      peak.is_high=m_setup[slot].direction>0;
      InspectObstacle(peak,slot,reference);
      if(m_setup[slot].nearest_obstacle_time==peak.time && m_setup[slot].nearest_obstacle_known_at==peak.known_at &&
         m_setup[slot].nearest_obstacle_tf==peak.tf && m_setup[slot].nearest_obstacle_price==peak.price)
         m_setup[slot].nearest_obstacle_source="WAVE1";
     }
   void Trigger(const int slot,const MqlRates &bar,const datetime knownAt)
     {
      if(!m_has[slot] || !m_setup[slot].active || !m_setup[slot].wave1_peak_fixed || !m_setup[slot].lower_structure_confirmed) return;
      bool simple=m_setup[slot].lower_recognition=="SIMPLE_REACTION_BREAK";
      if((m_strict_lifecycle || simple) && !m_setup[slot].signal_emitted && !SameWave2(m_setup[slot],m_setup[slot].lower_wave2_time,m_setup[slot].lower_wave2_price)) return;
      // A just-confirmed upper peak or lower swing cannot be used on the bar
      // whose close made it known. No historical candle is replayed as SIGNAL.
      if(bar.time<m_setup[slot].wave1_peak_known_at || bar.time<m_setup[slot].lower_structure_known_at)
        { m_setup[slot].lower_unmet_reason="TRIGGER_LINE_NOT_PREKNOWN"; return; }
      if(m_require_fib && !m_setup[slot].fib_touched)
        { m_setup[slot].lower_unmet_reason="WAITING_FIB_TOUCH"; return; }
      int n=ArraySize(m_lower.bars);
      if(n==0) return;
      MqlRates previous=m_lower.bars[n-1]; // Current bar is not appended yet.
      datetime closeAt=bar.time+PeriodSeconds(m_lower_tf);
      datetime previousClose=previous.time+PeriodSeconds(m_lower_tf);
      int d=m_setup[slot].direction;
      double pivotLine=d>0 ? m_setup[slot].lower_high2_price : m_setup[slot].lower_low2_price;
      // A single reaction pivot cannot define a trendline. Never fabricate a
      // second anchor from zero, the W2 extreme, or a later unconfirmed swing.
      double trendLine=simple ? 0 : TrendlineAt(m_setup[slot],closeAt);
      double previousTrendLine=simple ? 0 : TrendlineAt(m_setup[slot],previousClose);
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
      if(!selected)
        {
         m_setup[slot].lower_unmet_reason=simple ? (m_mode==W33_TRENDLINE_BREAK ? "SIMPLE_REQUIRES_PIVOT_TRIGGER" : "WAITING_FRESH_REACTION_CROSS") : "WAITING_SELECTED_BREAK";
         return;
        }
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
      m_setup[slot].lower_unmet_reason="";
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
         if(m_setup[slot].wave1_peak_fixed)
           {
            // Upper bars are fed first on equal close times. Inspect the old
            // threshold BEFORE reanchoring: its OHLC cannot establish whether
            // the new extreme or a same-bar qualifying pullback came first.
            ObserveExtensionLock(slot,bar,knownAt,true);
            ObserveUpperFibClose(slot,bar,knownAt);
            if(m_setup[slot].active) StartWave1Extension(slot,bar,knownAt);
            continue;
           }
         double price=d>0 ? bar.high : bar.low;
         if(d*(price-m_setup[slot].wave1_provisional_price)>0)
           {
            m_setup[slot].wave1_provisional_price=price;
            m_setup[slot].wave1_provisional_time=bar.time;
            Emit(slot,m_setup[slot].wave1_extension_pending ? "WAVE1_EXTENSION_TRACKING" : "WAVE1_PROVISIONAL",knownAt);
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
            bool extended=m_setup[slot].wave1_extension_pending;
            m_setup[slot].wave1_extension_pending=false;
            if(extended) m_setup[slot].wave1_extension_known_at=knownAt;
            Emit(slot,extended ? "WAVE1_EXTENDED_CONFIRMED" : "WAVE1_PEAK_CONFIRMED",knownAt);
            ChangeState(slot,WAVE2_RETRACEMENT,knownAt);
            // Upper closes observed while W1 was provisional become testable
            // only now against these fixed anchors. Preserve their original
            // candle/close times, record this CURRENT knowledge time, and check
            // the earliest breach before any lower-history characterization.
            int upperCount=ArraySize(m_upper.bars),upperFirst=upperCount;
            while(upperFirst>0 && m_upper.bars[upperFirst-1].time>=m_setup[slot].wave2_start_time) upperFirst--;
            for(int k=upperFirst;k<upperCount && m_setup[slot].active;k++)
              {
               ObserveExtensionLock(slot,m_upper.bars[k],knownAt,true);
               ObserveUpperFibClose(slot,m_upper.bars[k],knownAt);
              }
            if(!m_setup[slot].active) break;
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
      m_reject_deep_close=false;
      m_extend_wave1=false;
      m_cancel_connected_opposite=false;
      m_skip_connected_pair=false;
      m_strict_lifecycle=true;
      m_mode=W33_PIVOT_BREAK;
      m_lower_recognition=W33_STRICT_COUNTERTREND;
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
   void SetLowerRecognition(const W33LowerRecognitionMode mode) { m_lower_recognition=mode; }
   void SetLifecyclePolicy(const bool strict=true) { m_strict_lifecycle=strict; }
   void SetDeepFibClosePolicy(const bool reject=false) { m_reject_deep_close=reject; }
   void SetWave1ExtensionPolicy(const bool enabled=false) { m_extend_wave1=enabled; }
   void SetConnectedOppositePolicy(const bool enabled=false) { m_cancel_connected_opposite=enabled; }
   void SetConnectedPairPolicy(const bool enabled=false) { m_skip_connected_pair=enabled; }
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
         m_order_submitted[i]=false;
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
   bool FinishUnordered(const string setupId,const datetime knownAt,const string reason)
     {
      for(int i=0;i<2;i++)
         if(m_has[i] && m_setup[i].setup_id==setupId)
           {
            // Final risk/order failures relinquish this direction's lane. An
            // accepted open position and an untriggered candidate cannot be
            // completed through this API. The caller marks submission before
            // OrderSend and releases that guard only for a rejected request.
            if(!m_setup[i].active || !m_setup[i].signal_emitted || m_setup[i].position_open || m_order_submitted[i] ||
               knownAt<m_setup[i].signal_known_at || knownAt<m_setup[i].last_updated_at) return false;
            m_setup[i].active=false;
            m_setup[i].entry_status="UNORDERED_COMPLETED";
            m_setup[i].skip_reason=reason;
            Emit(i,"COMPLETED",knownAt,"OBSERVATION",reason);
            return true;
           }
      return false;
     }
   bool MarkOrderSubmitted(const string setupId,const bool submitted,const datetime knownAt)
     {
      for(int i=0;i<2;i++)
         if(m_has[i] && m_setup[i].setup_id==setupId)
           {
            if(!m_setup[i].active || !m_setup[i].signal_emitted || m_setup[i].position_open ||
               knownAt<m_setup[i].signal_known_at || knownAt<m_setup[i].last_updated_at) return false;
            m_order_submitted[i]=submitted;
            return true;
           }
      return false;
     }
   bool MarkExecution(const string setupId,const bool positionOpen,const datetime knownAt)
     {
      for(int i=0;i<2;i++)
         if(m_has[i] && m_setup[i].setup_id==setupId)
           {
            m_order_submitted[i]=false;
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
