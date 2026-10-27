#ifndef WAVE33_PRIOR_CONTEXT_MQH
#define WAVE33_PRIOR_CONTEXT_MQH
#include "Types.mqh"

// A location observation, not a completed double-top/double-bottom detector.
// Caller supplies only the already accepted/published feed prefix. Neither a
// chart redraw nor a terminal history query participates in this calculation.
#define W33_PRIOR_CONTEXT_VERSION "PRIOR_EXTREME_RETEST_V1"

struct W33PriorContextBar
  {
   ENUM_TIMEFRAMES tf;
   MqlRates bar;
   datetime known_at;
  };

struct W33PriorContextResult
  {
   string status,reason;
   bool near,blocked,has_latest_close;
   W33Pivot selected;
   double span,halfwidth,band_low,band_high,outer_edge,gap_fraction,room_r;
   bool tp_beyond,close_beyond,entry_passed;
   double latest_close;
   datetime latest_close_time,latest_close_known_at,latest_close_closed_at,evaluation_at;
   int candidate_count,near_count,unavailable_count;
   string candidate_sources,candidate_prices,candidate_known_at;
  };

string W33PriorContextTime(const datetime value)
  {return value>0?TimeToString(value,TIME_DATE|TIME_SECONDS):"";}

bool W33PriorContextUnavailable(W33PriorContextResult &out,const string reason)
  {out.status="UNAVAILABLE";out.reason=reason;out.blocked=false;return false;}

bool W33PriorContextShouldSkip(const bool enabled,const W33PriorContextResult &result)
  {return enabled && result.blocked && result.status=="BLOCKED";}

bool W33PriorContextLatestClose(const W33PriorContextBar &bars[],const W33Pivot &source,
                              const datetime evaluation_at,W33PriorContextBar &latest)
  {
   bool found=false;
   for(int i=0;i<ArraySize(bars);i++)
     {
      W33PriorContextBar b=bars[i];
      if(b.tf!=source.tf || b.bar.time<source.time || b.bar.time<=0 || b.known_at<=0 ||
         b.known_at>evaluation_at || b.bar.time+PeriodSeconds(b.tf)>evaluation_at ||
         b.known_at<b.bar.time+PeriodSeconds(b.tf) || !MathIsValidNumber(b.bar.close) || b.bar.close<=0)continue;
      if(!found || b.bar.time>latest.bar.time ||
         (b.bar.time==latest.bar.time && b.known_at>latest.known_at))
        {latest=b;found=true;}
     }
   return found;
  }

// Blocking evidence has priority, so a closer harmless/unknown candidate cannot
// hide a known barrier. Otherwise choose near first, then distance from W1 peak;
// exact-price/timeframe duplicates prefer H1, then the newer source candle.
bool W33PriorContextPrefer(const W33PriorContextResult &candidate,const W33PriorContextResult &selected,
                           const double epsilon)
  {
   if(candidate.blocked!=selected.blocked)return candidate.blocked;
   if(candidate.near!=selected.near)return candidate.near;
   // gap_fraction is dimensionless. Multiplying by span preserves the one
   // price epsilon used by the decision rules; no points-based tolerance.
   double candidate_gap=candidate.gap_fraction*candidate.span;
   double selected_gap=selected.gap_fraction*selected.span;
   if(candidate_gap<selected_gap-epsilon)return true;
   if(candidate_gap>selected_gap+epsilon)return false;
   if(candidate.selected.tf!=selected.selected.tf)return candidate.selected.tf==PERIOD_H1;
   if(candidate.selected.time!=selected.selected.time)return candidate.selected.time>selected.selected.time;
   return candidate.selected.known_at<selected.selected.known_at;
  }

// Entry, SL and FINAL TP must already be planned by the executable-quote risk
// planner. A peak-only observation is UNAVAILABLE until those values exist.
bool W33PriorContextEvaluate(const W33Setup &s,const W33Pivot &published[],const W33PriorContextBar &bars[],
                            const datetime evaluation_at,const double band_fraction,W33PriorContextResult &out)
  {
   ZeroMemory(out);out.status="UNAVAILABLE";out.evaluation_at=evaluation_at;
   if(evaluation_at<=0)return W33PriorContextUnavailable(out,"INVALID_EVALUATION_TIME");
   if(!MathIsValidNumber(band_fraction) || band_fraction<0 || band_fraction>1)
      return W33PriorContextUnavailable(out,"INVALID_BAND_FRACTION");
   if(!s.wave1_peak_fixed || s.wave1_extension_pending || s.wave1_start_time<=0 ||
      s.wave1_peak_time<=s.wave1_start_time || s.wave1_start_known_at<=0 || s.wave1_peak_known_at<=0)
      return W33PriorContextUnavailable(out,"FIXED_ANCHORS_MISSING");
   if(s.wave1_start_known_at>evaluation_at || s.wave1_peak_known_at>evaluation_at)
      return W33PriorContextUnavailable(out,"ANCHOR_NOT_KNOWN");
   if(s.wave1_start_known_at<s.wave1_start_time || s.wave1_peak_known_at<s.wave1_peak_time)
      return W33PriorContextUnavailable(out,"ANCHOR_KNOWN_BEFORE_SOURCE");
   if((s.direction!=1 && s.direction!=-1) || !MathIsValidNumber(s.wave1_start_price) ||
      !MathIsValidNumber(s.wave1_peak_price) || s.wave1_start_price<=0 || s.wave1_peak_price<=0)
      return W33PriorContextUnavailable(out,"INVALID_ANCHORS");
   out.span=s.direction*(s.wave1_peak_price-s.wave1_start_price);
   if(out.span<=0)return W33PriorContextUnavailable(out,"NONPOSITIVE_DIRECTIONAL_SPAN");
   out.halfwidth=band_fraction*out.span;
   if(!MathIsValidNumber(out.span) || !MathIsValidNumber(out.halfwidth))
      return W33PriorContextUnavailable(out,"INVALID_SPAN");
   if(!MathIsValidNumber(s.entry_price) || !MathIsValidNumber(s.sl_price) || !MathIsValidNumber(s.tp_price) ||
      s.entry_price<=0 || s.sl_price<=0 || s.tp_price<=0 ||
      s.direction*(s.entry_price-s.sl_price)<=0 || s.direction*(s.tp_price-s.entry_price)<=0)
      return W33PriorContextUnavailable(out,"EXECUTABLE_PLAN_MISSING_OR_INVALID");
   double epsilon=out.span*1e-12;
   double risk=s.direction*(s.entry_price-s.sl_price);
   // One scan per source timeframe, not one full historical scan per level.
   // If the newest eligible bar predates a candidate, every earlier bar also
   // predates it, so applying source.time below is exactly equivalent.
   W33Pivot any_source;ZeroMemory(any_source);
   W33PriorContextBar latest_m15,latest_h1;ZeroMemory(latest_m15);ZeroMemory(latest_h1);
   any_source.tf=PERIOD_M15;bool has_m15=W33PriorContextLatestClose(bars,any_source,evaluation_at,latest_m15);
   any_source.tf=PERIOD_H1;bool has_h1=W33PriorContextLatestClose(bars,any_source,evaluation_at,latest_h1);
   bool selected=false;
   int candidate_count=0,near_count=0,unavailable_count=0;
   string sources="",prices="",known="";
   for(int i=0;i<ArraySize(published);i++)
     {
      W33Pivot p=published[i];
      if((p.tf!=PERIOD_M15 && p.tf!=PERIOD_H1) || p.is_high!=(s.direction>0) || p.time<=0 ||
         p.time>=s.wave1_start_time || p.known_at<=0 || p.known_at>evaluation_at ||
         p.known_at<p.time+PeriodSeconds(p.tf) || !MathIsValidNumber(p.price) || p.price<=0)continue;
      W33PriorContextResult candidate;ZeroMemory(candidate);
      candidate.evaluation_at=evaluation_at;candidate.selected=p;candidate.span=out.span;candidate.halfwidth=out.halfwidth;
      candidate.band_low=p.price-out.halfwidth;candidate.band_high=p.price+out.halfwidth;
      candidate.outer_edge=p.price+s.direction*out.halfwidth;
      candidate.gap_fraction=MathAbs(s.wave1_peak_price-p.price)/out.span;
      candidate.near=MathAbs(s.wave1_peak_price-p.price)<=out.halfwidth+epsilon;
      candidate.room_r=s.direction*(p.price-s.entry_price)/risk;
      candidate.entry_passed=s.direction*(s.entry_price-candidate.outer_edge)>epsilon;
      candidate.tp_beyond=s.direction*(s.tp_price-candidate.outer_edge)>epsilon;
      W33PriorContextBar latest;ZeroMemory(latest);
      if(p.tf==PERIOD_M15){latest=latest_m15;candidate.has_latest_close=has_m15;}
      else {latest=latest_h1;candidate.has_latest_close=has_h1;}
      candidate.has_latest_close=candidate.has_latest_close && latest.bar.time>=p.time;
      candidate.status="CLEAR";candidate.reason="WAVE1_NOT_NEAR_PRIOR_BAND";
      if(candidate.has_latest_close)
        {
         candidate.latest_close=latest.bar.close;candidate.latest_close_time=latest.bar.time;
         candidate.latest_close_known_at=latest.known_at;
         candidate.latest_close_closed_at=latest.bar.time+PeriodSeconds(latest.tf);
         candidate.close_beyond=s.direction*(latest.bar.close-candidate.outer_edge)>epsilon;
        }
      if(candidate.near)
        {
         near_count++;
         if(!candidate.has_latest_close)
           {candidate.status="UNAVAILABLE";candidate.reason="SOURCE_TF_CLOSED_BAR_MISSING";unavailable_count++;}
         else if(candidate.entry_passed)candidate.reason="EXECUTABLE_ENTRY_BEYOND_BAND";
         else if(!candidate.tp_beyond)candidate.reason="FINAL_TP_NOT_BEYOND_BAND";
         else if(candidate.close_beyond)candidate.reason="SOURCE_TF_CLOSE_BEYOND_BAND";
         else
           {candidate.status="BLOCKED";candidate.reason="PRIOR_EXTREME_RETEST_TP_BEYOND_UNBROKEN_BAND";candidate.blocked=true;}
        }
      string separator=candidate_count>0?"|":"";
      sources+=separator+EnumToString(p.tf)+"@"+W33PriorContextTime(p.time);
      prices+=separator+DoubleToString(p.price,16);known+=separator+W33PriorContextTime(p.known_at);
      candidate_count++;
      if(!selected || W33PriorContextPrefer(candidate,out,epsilon)){out=candidate;selected=true;}
     }
   out.candidate_count=candidate_count;out.near_count=near_count;out.unavailable_count=unavailable_count;
   out.candidate_sources=sources;out.candidate_prices=prices;out.candidate_known_at=known;
   if(!selected){out.status="NO_PRIOR_LEVEL";out.reason="NO_KNOWN_PRE_WAVE1_M15_H1_EXTREME";return true;}
   return out.status!="UNAVAILABLE";
  }

class CWave33PriorContext
  {
private:
   W33Pivot m_pivots[];
   W33PriorContextBar m_bars[];
   int m_file,m_serial;
   bool m_enabled,m_draw,m_filter_enabled;
   double m_band_fraction;
   string m_prefix;
   string CompactHash(const string value) const
     {
      uint hash=2166136261;
      for(int i=0;i<StringLen(value);i++){hash^=(uint)StringGetCharacter(value,i);hash*=16777619;}
      return IntegerToString((long)hash);
     }
   string ObjectName(const W33Setup &s,const int serial,const string suffix) const
     {
      // A hash of the caller prefix is bounded even when its original run tag
      // was very long. Setup and revision/stage serial remain separately keyed.
      return m_prefix+CompactHash(s.setup_id)+"r"+IntegerToString(s.wave1_revision)+"s"+IntegerToString(serial)+suffix;
     }
   bool EvaluationEvent(const string event) const
     {
      return event=="SIGNAL" || event=="ORDER" || event=="ORDER_DISABLED" || event=="SKIP" ||
             event=="WAVE1_PEAK_CONFIRMED" || event=="WAVE1_EXTENDED_CONFIRMED" || event=="PRIOR_CONTEXT_FILTER";
     }
   void Style(const string name,const color colour,const bool background=false)
     {
      ObjectSetInteger(0,name,OBJPROP_COLOR,colour);ObjectSetInteger(0,name,OBJPROP_BACK,background);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
     }
   void Segment(const string name,const datetime t1,const double p1,const datetime t2,const double p2,
                const color colour,const ENUM_LINE_STYLE style=STYLE_DASH)
     {
      if(!ObjectCreate(0,name,OBJ_TREND,0,t1,p1,t2,p2))return;
      ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,name,OBJPROP_STYLE,style);ObjectSetInteger(0,name,OBJPROP_WIDTH,1);Style(name,colour);
     }
   void Text(const string name,const datetime at,const double price,const string caption,const string tooltip,const color colour)
     {
      if(!ObjectCreate(0,name,OBJ_TEXT,0,at,price))return;
      ObjectSetString(0,name,OBJPROP_TEXT,caption);ObjectSetString(0,name,OBJPROP_TOOLTIP,tooltip);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);Style(name,colour);
     }
   void Draw(const W33Event &e,const W33PriorContextResult &r)
     {
      // One frozen picture per SIGNAL, never moving historical decision lines.
      if(!m_draw || e.event_type!="SIGNAL" || r.selected.time<=0 || !r.near)return;
      const W33Setup s=e.setup;datetime end=e.at+12*PeriodSeconds(s.lower_tf);
      if(end<=e.at)return;
      color colour=r.blocked?clrTomato:clrMediumPurple;
      string source_tf=r.selected.tf==PERIOD_H1?"H1":"M15";
      string title=(s.direction>0?"既知の高値帯 ":"既知の安値帯 ")+source_tf;
      string tooltip=s.setup_id+" r"+IntegerToString(s.wave1_revision)+"\n"+W33_PRIOR_CONTEXT_VERSION;
      tooltip+="\nsource "+EnumToString(r.selected.tf)+" "+W33PriorContextTime(r.selected.time)+" @"+DoubleToString(r.selected.price,8);
      tooltip+="\nknown "+W33PriorContextTime(r.selected.known_at)+"; evaluated "+W33PriorContextTime(e.at);
      tooltip+="\n"+r.status+"; "+r.reason+"; room "+DoubleToString(r.room_r,2)+"R";
      tooltip+="\n過去点を結ぶ線は事後説明用。帯は判断可能時刻から表示。";
      string band=ObjectName(s,m_serial,"b");
      if(ObjectCreate(0,band,OBJ_RECTANGLE,0,e.at,r.band_low,end,r.band_high))
        {ObjectSetInteger(0,band,OBJPROP_FILL,false);ObjectSetInteger(0,band,OBJPROP_STYLE,STYLE_DOT);Style(band,colour,true);ObjectSetString(0,band,OBJPROP_TOOLTIP,tooltip);}
      string level_line=ObjectName(s,m_serial,"l");
      Segment(level_line,e.at,r.selected.price,end,r.selected.price,colour);
      ObjectSetString(0,level_line,OBJPROP_TOOLTIP,tooltip);
      string historical_line=ObjectName(s,m_serial,"h");
      Segment(historical_line,r.selected.time,r.selected.price,s.wave1_peak_time,s.wave1_peak_price,colour,STYLE_DOT);
      ObjectSetString(0,historical_line,OBJPROP_TOOLTIP,tooltip);
      string point=ObjectName(s,m_serial,"p");
      if(ObjectCreate(0,point,OBJ_ARROW,0,r.selected.time,r.selected.price))
        {ObjectSetInteger(0,point,OBJPROP_ARROWCODE,159);Style(point,colour);ObjectSetString(0,point,OBJPROP_TOOLTIP,tooltip);}
      string source_date=StringSubstr(TimeToString(r.selected.time,TIME_DATE|TIME_MINUTES),5);
      StringReplace(source_date,".","/");
      string source_caption="事後参照 "+source_tf+" "+source_date+" @"+DoubleToString(r.selected.price,_Digits);
      Text(ObjectName(s,m_serial,"k"),r.selected.time,r.selected.price,source_caption,tooltip,colour);
      string caption=title+"まで "+DoubleToString(r.room_r,2)+"R";
      if(r.blocked)caption+=" / 未突破・TPは帯の先";
      else if(r.status=="UNAVAILABLE")caption+=" / 判定資料不足";
      else if(r.reason=="EXECUTABLE_ENTRY_BEYOND_BAND")caption+=s.direction>0?" / 買値は帯の上":" / 売値は帯の下";
      else if(r.reason=="FINAL_TP_NOT_BEYOND_BAND")caption+=" / TPは帯の先でない";
      else if(r.reason=="SOURCE_TF_CLOSE_BEYOND_BAND")caption+=s.direction>0?" / 確定終値で上抜け済み":" / 確定終値で下抜け済み";
      else caption+=" / 見送り条件なし";
      Text(ObjectName(s,m_serial,"t"),e.at,r.band_high,caption,tooltip,colour);
     }
   void Write(const W33Event &e,const W33PriorContextResult &r)
     {
      if(m_file==INVALID_HANDLE)return;
      const W33Setup s=e.setup;
      FileWrite(m_file,W33_PRIOR_CONTEXT_VERSION,s.setup_id,s.symbol,EnumToString(s.upper_tf),EnumToString(s.lower_tf),s.direction,
         e.event_type,m_serial,W33PriorContextTime(e.at),s.wave1_revision,W33PriorContextTime(s.wave1_start_time),
         W33PriorContextTime(s.wave1_start_known_at),DoubleToString(s.wave1_start_price,16),W33PriorContextTime(s.wave1_peak_time),
         W33PriorContextTime(s.wave1_peak_known_at),DoubleToString(s.wave1_peak_price,16),DoubleToString(m_band_fraction,16),
         DoubleToString(r.span,16),DoubleToString(r.halfwidth,16),r.status,r.reason,r.near?1:0,r.blocked?1:0,m_filter_enabled?1:0,
         r.selected.time>0?EnumToString(r.selected.tf):"",W33PriorContextTime(r.selected.time),W33PriorContextTime(r.selected.known_at),
         r.selected.is_high?"HIGH":"LOW",DoubleToString(r.selected.price,16),DoubleToString(r.band_low,16),DoubleToString(r.band_high,16),
         DoubleToString(r.outer_edge,16),DoubleToString(r.gap_fraction,16),DoubleToString(s.entry_price,16),DoubleToString(s.sl_price,16),
         DoubleToString(s.tp_price,16),DoubleToString(r.room_r,16),r.entry_passed?1:0,r.tp_beyond?1:0,r.has_latest_close?1:0,
         W33PriorContextTime(r.latest_close_time),W33PriorContextTime(r.latest_close_closed_at),W33PriorContextTime(r.latest_close_known_at),
         DoubleToString(r.latest_close,16),r.close_beyond?1:0,r.candidate_count,r.near_count,r.unavailable_count,
         r.candidate_sources,r.candidate_prices,r.candidate_known_at);
      FileFlush(m_file);
     }
public:
   CWave33PriorContext(){m_file=INVALID_HANDLE;m_serial=0;m_enabled=false;m_draw=false;m_filter_enabled=false;m_band_fraction=0.05;}
   bool Open(const string tag,const string prefix,const bool diagnostic,const bool draw,const bool skip,const double band_fraction)
     {
      Close();ArrayResize(m_pivots,0);ArrayResize(m_bars,0);m_serial=0;
      m_enabled=diagnostic || skip;m_draw=draw && m_enabled;m_filter_enabled=skip;m_band_fraction=band_fraction;
      m_prefix="W33PC_"+CompactHash(prefix)+"_";
      if(!m_enabled)return true;
      m_file=FileOpen(tag+"_context.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,';',CP_UTF8);
      if(m_file==INVALID_HANDLE)return false;
      FileWrite(m_file,"formula_version","setup_id","symbol","upper_tf","lower_tf","direction","source_event","event_serial","evaluation_at",
         "wave1_revision","start_time","start_known_at","start_price","peak_time","peak_known_at","peak_price","band_fraction","directional_span",
         "band_halfwidth","status","reason","wave1_near_band","blocked","entry_filter_enabled","source_tf","source_time","source_known_at","source_type",
         "source_price","band_low","band_high","outer_edge","gap_fraction","entry_price","sl_price","final_tp_price","room_to_source_r",
         "entry_passed_band","tp_beyond_band","has_latest_close","latest_close_time","latest_close_closed_at","latest_close_known_at","latest_close_price",
         "latest_close_beyond_band","candidate_count","near_candidate_count","unavailable_near_count","all_candidate_sources","all_candidate_prices","all_candidate_known_at");
      FileFlush(m_file);return true;
     }
   void ClosedBar(const ENUM_TIMEFRAMES tf,const MqlRates &bar,const datetime known_at)
     {
      if(!m_enabled || (tf!=PERIOD_M15 && tf!=PERIOD_H1))return;
      // This method is called only after the engine accepted this feed bar.
      // Invalid/future bars are never admitted, even if a caller errs.
      if(bar.time<=0 || known_at<bar.time+PeriodSeconds(tf) || !MathIsValidNumber(bar.close) || bar.close<=0)return;
      int n=ArraySize(m_bars);ArrayResize(m_bars,n+1,2048);m_bars[n].tf=tf;m_bars[n].bar=bar;m_bars[n].known_at=known_at;
     }
   bool Evaluate(const W33Setup &s,const datetime at,W33PriorContextResult &result) const
     {
      if(!m_enabled){ZeroMemory(result);result.evaluation_at=at;return W33PriorContextUnavailable(result,"OBSERVER_DISABLED");}
      return W33PriorContextEvaluate(s,m_pivots,m_bars,at,m_band_fraction,result);
     }
   void Event(const W33Event &e)
     {
      if(!m_enabled)return;
      m_serial++;
      // Confirmed-pivot events are distinct from evaluation events. The cache
      // contains only published observations; same timestamp is insufficient.
      if(e.event_type=="PIVOT_CONFIRMED" && e.has_pivot && (e.pivot.tf==PERIOD_M15 || e.pivot.tf==PERIOD_H1))
        {int n=ArraySize(m_pivots);ArrayResize(m_pivots,n+1,512);m_pivots[n]=e.pivot;}
      if(e.setup.setup_id=="" || !EvaluationEvent(e.event_type))return;
      W33PriorContextResult result;Evaluate(e.setup,e.at,result);Write(e,result);Draw(e,result);
     }
   void Close(){if(m_file!=INVALID_HANDLE){FileFlush(m_file);FileClose(m_file);m_file=INVALID_HANDLE;}}
   void Clear(){if(m_prefix!="")ObjectsDeleteAll(0,m_prefix);}
  };
#endif
