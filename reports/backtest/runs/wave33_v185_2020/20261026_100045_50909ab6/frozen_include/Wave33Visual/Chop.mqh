#ifndef WAVE33_CHOP_DIAGNOSTIC_MQH
#define WAVE33_CHOP_DIAGNOSTIC_MQH
#include "Types.mqh"

// The formula and threshold are fixed; an explicit optional entry policy owns exclusion.
#define W33_CHOP_VERSION "LOWER_PIVOT_BACKTRACK_V1"
#define W33_CHOP_THRESHOLD 0.5

struct W33ChopResult
  {
   string status,reason;
   double adverse,span,ratio;
   int raw_pivots,normalized_pivots;
   W33Pivot path[]; // Fixed start, normalized known interior pivots, fixed endpoint.
   string pivot_times,pivot_known_at,pivot_prices,pivot_types;
  };

// Missing/invalid evidence remains UNAVAILABLE and is allowed, never interpreted
// as numeric zero/CLEAN. Only the evaluator's explicit CHOPPY status can block.
bool W33ChopShouldSkip(const bool enabled,const W33ChopResult &result)
  {return enabled && result.status=="CHOPPY";}

string W33ChopTime(const datetime at)
  {return at>0?TimeToString(at,TIME_DATE|TIME_SECONDS):"";}
string W33ChopCompactHash(const string value)
  {
   uint hash=2166136261;
   for(int i=0;i<StringLen(value);i++){hash^=(uint)StringGetCharacter(value,i);hash*=16777619;}
   return IntegerToString((long)hash);
  }
string W33ChopLabelName(const string prefix,const string setup_id,const int revision,const int serial)
  {return prefix+"CHOP_"+W33ChopCompactHash(setup_id)+"_r"+IntegerToString(revision)+"_"+IntegerToString(serial);}
bool W33ChopUnavailable(W33ChopResult &out,const string reason)
  {out.status="UNAVAILABLE";out.reason=reason;return false;}
void W33ChopPush(W33ChopResult &out,const W33Pivot &point,const string type)
  {
   int n=ArraySize(out.path);ArrayResize(out.path,n+1);out.path[n]=point;
   string separator=n>0?"|":"";
   out.pivot_times+=separator+W33ChopTime(point.time);
   out.pivot_known_at+=separator+W33ChopTime(point.known_at);
   out.pivot_prices+=separator+DoubleToString(point.price,16);
   out.pivot_types+=separator+type;
  }

// The published array must contain only pivots observed BEFORE this evaluation
// event. known_at filters future records as an additional check; it cannot repair
// same-timestamp event ordering in a caller that passes later unpublished pivots.
bool W33ChopEvaluate(const W33Setup &s,const W33Pivot &published[],const datetime evaluation_at,
                     const datetime first_lower_bar_time,W33ChopResult &out)
  {
   out.status="UNAVAILABLE";out.reason="";out.adverse=0;out.span=0;out.ratio=0;
   out.raw_pivots=0;out.normalized_pivots=0;ArrayResize(out.path,0);
   out.pivot_times="";out.pivot_known_at="";out.pivot_prices="";out.pivot_types="";
   if(!s.wave1_peak_fixed || s.wave1_extension_pending || s.wave1_start_time<=0 || s.wave1_peak_time<=s.wave1_start_time ||
      s.wave1_start_known_at<=0 || s.wave1_peak_known_at<=0)
      return W33ChopUnavailable(out,"FIXED_ANCHORS_MISSING");
   if(s.wave1_start_known_at>evaluation_at || s.wave1_peak_known_at>evaluation_at)
      return W33ChopUnavailable(out,"ANCHOR_NOT_KNOWN");
   if(s.wave1_start_known_at<s.wave1_start_time || s.wave1_peak_known_at<s.wave1_peak_time)
      return W33ChopUnavailable(out,"ANCHOR_KNOWN_BEFORE_SOURCE");
   if((s.direction!=1 && s.direction!=-1) || !MathIsValidNumber(s.wave1_start_price) ||
      !MathIsValidNumber(s.wave1_peak_price) || s.wave1_start_price<=0 || s.wave1_peak_price<=0)
      return W33ChopUnavailable(out,"INVALID_ANCHORS");
   out.span=s.direction*(s.wave1_peak_price-s.wave1_start_price);
   if(out.span<=0)return W33ChopUnavailable(out,"NONPOSITIVE_DIRECTIONAL_SPAN");
   if(first_lower_bar_time<=0 || first_lower_bar_time>s.wave1_start_time)
      return W33ChopUnavailable(out,"LOWER_HISTORY_INCOMPLETE");
   W33Pivot normalized[];datetime last_source=0,last_known=0;bool last_type=false,has_last=false;
   for(int i=0;i<ArraySize(published);i++)
     {
      W33Pivot p=published[i];
      if(p.tf!=s.lower_tf || p.known_at>evaluation_at || p.time<=s.wave1_start_time || p.time>=s.wave1_peak_time)continue;
      out.raw_pivots++;
      if(p.known_at<=0 || p.known_at<p.time)return W33ChopUnavailable(out,"PIVOT_KNOWN_BEFORE_SOURCE");
      if(!MathIsValidNumber(p.price) || p.price<=0)return W33ChopUnavailable(out,"INVALID_PIVOT_PRICE");
      if(has_last && (p.time<last_source || p.known_at<last_known))return W33ChopUnavailable(out,"PIVOT_CHRONOLOGY");
      if(has_last && p.time==last_source && p.is_high!=last_type)return W33ChopUnavailable(out,"SAME_TIME_HIGH_LOW_AMBIGUOUS");
      last_source=p.time;last_known=p.known_at;last_type=p.is_high;has_last=true;
      int n=ArraySize(normalized);
      if(n>0 && normalized[n-1].is_high==p.is_high)
        {
         if((p.is_high && p.price>normalized[n-1].price) || (!p.is_high && p.price<normalized[n-1].price))normalized[n-1]=p;
        }
      else {ArrayResize(normalized,n+1);normalized[n]=p;}
     }
   // Relative H/L prices are not constrained: legitimate gaps are preserved.
   W33Pivot anchor;ZeroMemory(anchor);anchor.tf=s.upper_tf;anchor.time=s.wave1_start_time;
   anchor.known_at=s.wave1_start_known_at;anchor.price=s.wave1_start_price;anchor.is_high=s.direction<0;
   W33ChopPush(out,anchor,"START");
   out.normalized_pivots=ArraySize(normalized);
   for(int j=0;j<ArraySize(normalized);j++)W33ChopPush(out,normalized[j],normalized[j].is_high?"H":"L");
   anchor.time=s.wave1_peak_time;anchor.known_at=s.wave1_peak_known_at;anchor.price=s.wave1_peak_price;anchor.is_high=s.direction>0;
   W33ChopPush(out,anchor,"END");
   for(int j=1;j<ArraySize(out.path);j++)
      out.adverse+=MathMax(0,-s.direction*(out.path[j].price-out.path[j-1].price));
   out.ratio=out.adverse/out.span;
   out.status=out.ratio>=W33_CHOP_THRESHOLD?"CHOPPY":"CLEAN";
   return true;
  }

class CWave33ChopObserver
  {
private:
   W33Pivot m_pivots[];
   datetime m_first_lower;
   ENUM_TIMEFRAMES m_lower;
   int m_file,m_event_serial;
   bool m_enabled,m_draw,m_entry_filter_enabled;
   string m_prefix;
   bool EvaluationEvent(const string event) const
     {
      return event=="WAVE1_PEAK_CONFIRMED" || event=="WAVE1_EXTENDED_CONFIRMED" || event=="SIGNAL" ||
             event=="ORDER" || event=="ORDER_DISABLED" || event=="SKIP" || event=="INVALIDATE" ||
             event=="COMPLETED" || event=="EXIT" || event=="TEST_END" || event=="CHOP_ENTRY_FILTER";
     }
   void Draw(const W33Event &e,const W33ChopResult &r,const int serial)
     {
      if(!m_draw)return;
      const W33Setup s=e.setup;
      bool peak=e.event_type=="WAVE1_PEAK_CONFIRMED" || e.event_type=="WAVE1_EXTENDED_CONFIRMED";
      bool entry=e.event_type=="ORDER" || e.event_type=="ORDER_DISABLED";
      bool terminal=(e.event_type=="INVALIDATE" || e.event_type=="SKIP") && s.wave1_peak_fixed && !s.wave1_extension_pending;
      if(!peak && !entry && !terminal)return;
      double price=s.wave1_peak_price;
      if(entry && s.entry_price>0)price=s.entry_price;
      if(terminal && s.wave2_extreme_price>0)price=s.wave2_extreme_price;
      if(price<=0)return;
      string name=m_prefix+W33ChopCompactHash(s.setup_id)+"_r"+IntegerToString(s.wave1_revision)+"_"+IntegerToString(serial);
      if(!ObjectCreate(0,name,OBJ_TEXT,0,e.at,price))return;
      string short_event=e.event_type=="WAVE1_PEAK_CONFIRMED"?"P":(e.event_type=="WAVE1_EXTENDED_CONFIRMED"?"R":e.event_type);
      string text="①"+(r.status=="UNAVAILABLE"?"往復判定不可":(r.status=="CHOPPY"?"往復多い ":"往復少ない ")+DoubleToString(r.ratio,2));
      text+=" ["+short_event+" r"+IntegerToString(s.wave1_revision)+"]";
      ObjectSetString(0,name,OBJPROP_TEXT,text);
      ObjectSetInteger(0,name,OBJPROP_COLOR,r.status=="CHOPPY"?clrOrange:(r.status=="CLEAN"?clrLightSkyBlue:clrGray));
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      // Bounded tooltip: full path details live in CSV, not an unbounded tooltip.
      string tooltip=s.setup_id+"\n"+e.event_type+" @"+W33ChopTime(e.at);
      tooltip+="\nStart "+W33ChopTime(s.wave1_start_time)+" known "+W33ChopTime(s.wave1_start_known_at);
      tooltip+="\nEnd "+W33ChopTime(s.wave1_peak_time)+" known "+W33ChopTime(s.wave1_peak_known_at);
      tooltip+="\n"+r.status+" "+DoubleToString(r.ratio,4)+(m_entry_filter_enabled?"; entry filter ON":"; observation only")+"; full path in chop CSV";
      ResetLastError();
      if(!ObjectSetString(0,name,OBJPROP_TOOLTIP,tooltip))Print("CHOP_TOOLTIP_SET_FAILED length=",StringLen(tooltip)," error=",GetLastError());
     }
public:
   CWave33ChopObserver(){m_file=INVALID_HANDLE;m_first_lower=0;m_enabled=false;m_draw=false;m_entry_filter_enabled=false;m_event_serial=0;}
   bool Open(const string tag,const string prefix,const ENUM_TIMEFRAMES lower,const bool enabled,const bool draw,const bool entry_filter_enabled=false)
     {
      Close();ArrayResize(m_pivots,0);m_first_lower=0;m_event_serial=0;m_entry_filter_enabled=entry_filter_enabled;
      m_enabled=enabled || entry_filter_enabled;m_draw=draw && m_enabled;m_prefix=prefix+"CHOP_";m_lower=lower;
      if(!m_enabled)return true;
      m_file=FileOpen(tag+"_chop.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,';',CP_UTF8);
      if(m_file==INVALID_HANDLE)return false;
      FileWrite(m_file,"formula_version","threshold","setup_id","symbol","upper_tf","lower_tf","direction","source_event","event_serial",
         "evaluation_at","wave1_revision","start_time","start_known_at","start_price","peak_time","peak_known_at","peak_price",
         "first_lower_bar_time","raw_pivots","normalized_pivots","path_source_times","path_known_at","path_prices","path_types",
         "adverse_price_moves","directional_span","backtrack_ratio","status","unavailable_reason","entry_filter_enabled");
      FileFlush(m_file);
      return true;
     }
   bool Evaluate(const W33Setup &setup,const datetime evaluation_at,W33ChopResult &result) const
     {
      if(!m_enabled)
        {
         ZeroMemory(result);result.status="UNAVAILABLE";result.reason="OBSERVER_DISABLED";return false;
        }
      return W33ChopEvaluate(setup,m_pivots,evaluation_at,m_first_lower,result);
     }
   void AcceptedLowerBar(const datetime source_time)
     {if(m_enabled && (m_first_lower==0 || source_time<m_first_lower))m_first_lower=source_time;}
   void Event(const W33Event &e)
     {
      if(!m_enabled)return;
      m_event_serial++;
      // Evaluate before adding this event's pivot: event order, not timestamp alone.
      if(e.setup.setup_id!="" && EvaluationEvent(e.event_type))
        {
         W33ChopResult r;W33ChopEvaluate(e.setup,m_pivots,e.at,m_first_lower,r);
         const W33Setup s=e.setup;
         if(m_file!=INVALID_HANDLE)
            FileWrite(m_file,W33_CHOP_VERSION,DoubleToString(W33_CHOP_THRESHOLD,16),s.setup_id,s.symbol,EnumToString(s.upper_tf),EnumToString(s.lower_tf),
               s.direction,e.event_type,m_event_serial,W33ChopTime(e.at),s.wave1_revision,W33ChopTime(s.wave1_start_time),W33ChopTime(s.wave1_start_known_at),
               DoubleToString(s.wave1_start_price,16),W33ChopTime(s.wave1_peak_time),W33ChopTime(s.wave1_peak_known_at),DoubleToString(s.wave1_peak_price,16),
               W33ChopTime(m_first_lower),r.raw_pivots,r.normalized_pivots,r.pivot_times,r.pivot_known_at,r.pivot_prices,r.pivot_types,
               DoubleToString(r.adverse,16),DoubleToString(r.span,16),DoubleToString(r.ratio,16),r.status,r.reason,m_entry_filter_enabled?1:0);
         if(m_file!=INVALID_HANDLE)FileFlush(m_file);
         Draw(e,r,m_event_serial);
        }
      if(e.has_pivot && e.pivot.tf==m_lower)
        {int n=ArraySize(m_pivots);ArrayResize(m_pivots,n+1);m_pivots[n]=e.pivot;}
     }
   void Close(){if(m_file!=INVALID_HANDLE){FileFlush(m_file);FileClose(m_file);m_file=INVALID_HANDLE;}}
   void Clear(){ObjectsDeleteAll(0,m_prefix);}
  };
#endif
