#ifndef WAVE33_DISPLAY_MQH
#define WAVE33_DISPLAY_MQH
#include "Types.mqh"
string W33Hash(const string value)
  {
   uint a=2166136261,b=2246822519;
   for(int i=0;i<StringLen(value);i++){a^=(uint)StringGetCharacter(value,i);a*=16777619;b^=(uint)StringGetCharacter(value,StringLen(value)-1-i);b*=3266489917;}
   return StringFormat("%08X%08X",a,b);
  }
// Read-only drawing. Swing locations are retrospective, created ONLY when known.
// Horizontal decision lines still begin at their availability time.
class CWave33Display
  {
private:
   string m_prefix;
   bool m_enabled,m_panel,m_details,m_paths,m_panel_clean;
   int m_serial;
   ENUM_TIMEFRAMES m_upper,m_lower;
   W33TriggerMode m_trigger_mode;
   string m_ids[],m_levels[],m_trends[];
   bool m_decision_live[],m_risk_live[];
   W33Pivot m_previous[2];
   datetime m_plot_previous[2];
   bool m_have_previous[2];
   string m_last_path[2],m_seen[];
   string Name(const string id,const string suffix){return m_prefix+W33Hash(id)+"_"+suffix;}
   string TF(const ENUM_TIMEFRAMES tf){string t=EnumToString(tf);StringReplace(t,"PERIOD_","");return t;}
   int Step(){return (int)MathMax(60,MathMax(PeriodSeconds((ENUM_TIMEFRAMES)_Period),PeriodSeconds(m_lower)));}
   string Clock(const datetime t){return TimeToString(t,TIME_DATE|TIME_SECONDS);}
   string ShortClock(const datetime t)
     {
      if(t<=0)return "日時不明";
      string v=TimeToString(t,TIME_DATE|TIME_MINUTES);
      return StringSubstr(v,5,2)+"/"+StringSubstr(v,8,2)+" "+StringSubstr(v,11,5);
     }
   string LowerTip(const W33Setup &s,const datetime at)
     {
      string recognition=s.lower_recognition!=""?s.lower_recognition:s.lower_entry_stage;
      string trigger=s.trigger_type!=""?s.trigger_type:(m_trigger_mode==W33_TRENDLINE_BREAK?"TRENDLINE_BREAK":(m_trigger_mode==W33_FIRST_BREAK?"FIRST_BREAK":"PIVOT_BREAK"));
      string status=s.entry_status!=""?s.entry_status:"WAITING";
      string detail=recognition+" "+trigger+" "+status+" known "+TimeToString(at,TIME_DATE|TIME_MINUTES);
      if(StringLen(detail)>120)detail=recognition+" "+trigger+" known "+TimeToString(at,TIME_DATE|TIME_MINUTES);
      string unmet=" unmet "+s.lower_unmet_reason;
      if(s.lower_unmet_reason!="" && StringLen(detail+unmet)<=120)detail+=unmet;
      return detail;
     }
   void Tip(const string name,const string text){if(m_enabled && ObjectFind(0,name)>=0)ObjectSetString(0,name,OBJPROP_TOOLTIP,text);}
   int Lane(const string id)
     {
      for(int i=0;i<ArraySize(m_ids);i++)if(m_ids[i]==id)return i;
      int n=ArraySize(m_ids);ArrayResize(m_ids,n+1);ArrayResize(m_levels,n+1);ArrayResize(m_trends,n+1);
      ArrayResize(m_decision_live,n+1);ArrayResize(m_risk_live,n+1);
      m_ids[n]=id;m_levels[n]="";m_trends[n]="";m_decision_live[n]=true;m_risk_live[n]=false;return n;
     }
   void Text(const string name,const datetime at,const double price,const string text,const color c,const int anchor=ANCHOR_LEFT_LOWER,const int size=9)
     {
      if(!m_enabled || at<=0 || price<=0)return;
      if(ObjectFind(0,name)<0)ObjectCreate(0,name,OBJ_TEXT,0,at,price);
      else ObjectMove(0,name,0,at,price);
      ObjectSetString(0,name,OBJPROP_TEXT,text);ObjectSetString(0,name,OBJPROP_FONT,"Meiryo");
      ObjectSetInteger(0,name,OBJPROP_COLOR,c);ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,anchor);ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);Tip(name,text);
     }
   void Segment(const string name,const datetime a,const double pa,const datetime b,const double pb,const color c,const bool ray=false,const int width=1,const ENUM_LINE_STYLE style=STYLE_SOLID)
     {
      if(!m_enabled || a<=0 || b<=a || pa<=0 || pb<=0)return;
      if(ObjectFind(0,name)<0)ObjectCreate(0,name,OBJ_TREND,0,a,pa,b,pb);
      else {ObjectMove(0,name,0,a,pa);ObjectMove(0,name,1,b,pb);}
      ObjectSetInteger(0,name,OBJPROP_COLOR,c);ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
      ObjectSetInteger(0,name,OBJPROP_STYLE,style);ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);
      ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,ray);ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
     }
   void Dot(const string name,const datetime at,const double price,const color c,const int width=1)
     {
      if(!m_enabled || at<=0 || price<=0)return;
      if(ObjectFind(0,name)<0)ObjectCreate(0,name,OBJ_ARROW,0,at,price);
      ObjectSetInteger(0,name,OBJPROP_ARROWCODE,159);ObjectSetInteger(0,name,OBJPROP_COLOR,c);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,width);ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
     }
   void Level(const string id,const string suffix,const datetime known,const double price,const color c,const ENUM_LINE_STYLE style=STYLE_SOLID)
     {
      string n=Name(id,suffix);
      if(ObjectFind(0,n)>=0)return;
      // A finite one-bar stub is visible on the creation tick. Only observed
      // event times can subsequently extend a live line; no endless rays.
      Segment(n,known,price,known+Step(),price,c,false,1,style);
      Tip(n,id+" | "+suffix+" | known "+Clock(known)+" | "+DoubleToString(price,_Digits));
     }
   void ExtendLine(const string name,const datetime at)
     {
      if(name=="" || ObjectFind(0,name)<0)return;
      datetime a=(datetime)ObjectGetInteger(0,name,OBJPROP_TIME,0),b=(datetime)ObjectGetInteger(0,name,OBJPROP_TIME,1);
      datetime end=(datetime)MathMax((long)a+Step(),(long)at);
      if(end<=b)return;
      double pa=ObjectGetDouble(0,name,OBJPROP_PRICE,0),pb=ObjectGetDouble(0,name,OBJPROP_PRICE,1);
      double p=b>a?pa+(pb-pa)*(double)(end-a)/(double)(b-a):pa;
      ObjectMove(0,name,1,end,p);ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
     }
   void CloseLine(const string name,const datetime at,const bool mute=true)
     {
      if(name=="" || ObjectFind(0,name)<0)return;
      datetime a=(datetime)ObjectGetInteger(0,name,OBJPROP_TIME,0),b=(datetime)ObjectGetInteger(0,name,OBJPROP_TIME,1);
      // Same-tick decisions retain a one-bar marker rather than an invisible
      // zero-length line. This is drawing space, never a future price sample.
      datetime end=(datetime)MathMax((long)a+Step(),(long)at);
      double pa=ObjectGetDouble(0,name,OBJPROP_PRICE,0),pb=ObjectGetDouble(0,name,OBJPROP_PRICE,1);
      double p=b>a?pa+(pb-pa)*(double)(end-a)/(double)(b-a):pa;
      ObjectMove(0,name,1,end,p);ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
      if(mute && !m_details)ObjectSetInteger(0,name,OBJPROP_COLOR,clrSlateGray);
     }
   void FibEnd(const string id,const datetime at)
     {
      string n=Name(id,"fib");if(ObjectFind(0,n)<0)return;
      datetime a=(datetime)ObjectGetInteger(0,n,OBJPROP_TIME,0);
      ObjectMove(0,n,1,(datetime)MathMax((long)a+Step(),(long)at),ObjectGetDouble(0,n,OBJPROP_PRICE,1));
     }
   void CloseDecision(const int lane,const datetime at)
     {
      if(!m_decision_live[lane])return;
      CloseLine(Name(m_ids[lane],"upper_break"),at);CloseLine(m_levels[lane],at);CloseLine(m_trends[lane],at);
      FibEnd(m_ids[lane],at);m_decision_live[lane]=false;
     }
   void CloseRisk(const int lane,const datetime at)
     {
      // An unexecuted signal is already a short marker. A later monitor-end
      // event must not turn it (or a previously closed trade) into a long line.
      if(!m_risk_live[lane])return;
      CloseLine(Name(m_ids[lane],"SL"),at,false);CloseLine(Name(m_ids[lane],"TP"),at,false);
      CloseLine(Name(m_ids[lane],"obstacle"),at,false);CloseLine(Name(m_ids[lane],"wave1_room"),at,false);m_risk_live[lane]=false;
     }
   void Advance(const datetime at)
     {
      for(int i=0;i<ArraySize(m_ids);i++)
        {
         if(m_decision_live[i])
           {
            ExtendLine(Name(m_ids[i],"upper_break"),at);ExtendLine(m_levels[i],at);ExtendLine(m_trends[i],at);FibEnd(m_ids[i],at);
           }
         if(m_risk_live[i])
           {
            ExtendLine(Name(m_ids[i],"SL"),at);ExtendLine(Name(m_ids[i],"TP"),at);ExtendLine(Name(m_ids[i],"obstacle"),at);ExtendLine(Name(m_ids[i],"wave1_room"),at);
           }
        }
     }
   datetime PlotTime(const datetime source,const double price,const ENUM_TIMEFRAMES tf,const bool high,const datetime known)
     {
      if(tf==m_lower || source<=0 || known<source+PeriodSeconds(tf))return source;
      // Already-closed lower bars locate the upper extreme. Drawing only.
      MqlRates bars[];int n=CopyRates(_Symbol,m_lower,source,source+PeriodSeconds(tf)-1,bars);
      for(int i=0;i<n;i++)
        {
         if(bars[i].time+PeriodSeconds(m_lower)>known)continue;
         double p=high?bars[i].high:bars[i].low;
         if(MathAbs(p-price)<=_Point*0.5)return bars[i].time;
        }
      return source;
     }
   void Reference(const W33Setup &s,const string suffix,const string reference,const string label,const datetime source,const datetime known,const ENUM_TIMEFRAMES tf,const bool high,const double price,const datetime adopted,const color c,const bool firstWave=false)
     {
      // A source marker is retrospective evidence created now. It is never an
      // assertion that the decision line already existed at the swing candle.
      if(price<=0 || adopted<=0 || (known>0 && known>adopted) || source>adopted)return;
      string id=s.setup_id,n=Name(id,suffix);
      datetime start=adopted;
      // Fresh levels can show their known interval. Ancient source levels are
      // short adoption-time stubs, with their original date on the label.
      if(known>0 && s.candidate_detected_at>0 && known>=s.candidate_detected_at)start=known;
      // Native object tooltips truncate long text and can mangle non-ASCII.
      // Preserve all three full dates in a compact, ASCII-only source trace.
      string traceId=firstWave?"W1":"R"+StringSubstr(W33Hash(id),0,8);
      string traceHead=traceId+" "+TF(tf)+" "+(high?"HIGH":"LOW");
      string times=" source "+TimeToString(source,TIME_DATE|TIME_MINUTES)+
                   " known "+TimeToString(known,TIME_DATE|TIME_MINUTES)+
                   " adopted "+TimeToString(adopted,TIME_DATE|TIME_MINUTES);
      string detail=traceHead+" "+DoubleToString(price,_Digits)+times;
      if(StringLen(detail)>120)detail=traceHead+times;
      if(ObjectFind(0,n)<0)
        {
         Segment(n,start,price,adopted+Step(),price,c,false,1,STYLE_DOT);Tip(n,detail);
         // Keep the first adoption timestamp when SIGNAL and RISK_CHECK carry
         // the same immutable source snapshot on the same execution tick.
         datetime labelAt=adopted+Step();
         double labelPrice=price;
         double risk=s.entry_price>0 && s.sl_price>0?MathAbs(s.entry_price-s.sl_price):0;
         bool closeReferences=false;
         // Separate nearby reference captions by role. The horizontal source
         // levels keep their exact prices; only the text occupies a new lane.
         if(risk>0 && s.wave1_peak_price>0 && s.nearest_obstacle_price>0 &&
            MathAbs(s.wave1_peak_price-s.nearest_obstacle_price)<risk*0.15)
           {
            closeReferences=true;
            double hi=MathMax(s.wave1_peak_price,s.nearest_obstacle_price),lo=MathMin(s.wave1_peak_price,s.nearest_obstacle_price);
            if(firstWave)labelPrice=s.direction>0?hi+risk*0.02:lo-risk*0.02;
            else labelPrice=s.direction>0?lo-risk*0.02:hi+risk*0.02;
           }
         if(MathAbs(labelPrice-price)>_Point*0.1)
           {
            Segment(Name(id,suffix+"_caption_leader"),adopted,price,labelAt,labelPrice,c,false,1,STYLE_DOT);
            Tip(Name(id,suffix+"_caption_leader"),detail);
           }
         int captionAnchor=s.direction>0?ANCHOR_LEFT_LOWER:ANCHOR_LEFT_UPPER;
         if(!firstWave && closeReferences)captionAnchor=s.direction>0?ANCHOR_LEFT_UPPER:ANCHOR_LEFT_LOWER;
         Text(Name(id,suffix+"_label"),labelAt,labelPrice,label,c,captionAnchor,8);
         Tip(Name(id,suffix+"_label"),detail);
         if(source>0)
           {
            datetime plot=PlotTime(source,price,tf,high,adopted);
            Dot(Name(id,suffix+"_source"),plot,price,c,2);
            Tip(Name(id,suffix+"_source"),detail);
            Text(Name(id,suffix+"_source_label"),plot,price,reference,c,high?ANCHOR_RIGHT_LOWER:ANCHOR_RIGHT_UPPER,7);
            Tip(Name(id,suffix+"_source_label"),detail);
           }
        }
     }
   void RiskReferences(const W33Setup &s,const datetime at)
     {
      if(s.wave1_peak_price>0 && s.wave1_peak_known_at>0 && s.wave1_peak_known_at<=at)
        {
         string type=s.direction>0?"①高値":"①安値";
         string source=type+" "+TF(s.upper_tf)+" "+ShortClock(s.wave1_peak_time);
         string label=type+"まで "+DoubleToString(s.wave1_room_r,2)+"R";
         Reference(s,"wave1_room",source,label,s.wave1_peak_time,s.wave1_peak_known_at,s.upper_tf,s.direction>0,s.wave1_peak_price,at,clrCornflowerBlue,true);
        }
      if(s.nearest_obstacle_price<=0)return;
      // The W1 boundary has its own source trace and risk distance. Repeating
      // that exact same candidate as an unrelated purple resistance is noisy.
      if(s.nearest_obstacle_source=="WAVE1")return;
      bool high=s.nearest_obstacle_is_high;
      string kind=high?"高値":"安値";
      string frame=s.nearest_obstacle_time>0?TF(s.nearest_obstacle_tf):"出所未記録";
      string source="R"+StringSubstr(W33Hash(s.setup_id),0,8)+" "+frame+(s.nearest_obstacle_time>0?kind+" "+ShortClock(s.nearest_obstacle_time):"");
      string candidate=s.direction>0?"抵抗候補":"支持候補";
      // A previous low overhead / high below is only a historic reference;
      // it is not presented as a proven important barrier.
      if(s.nearest_obstacle_time>0 && high!=(s.direction>0))candidate="参考";
      string label=source+" "+candidate+" "+DoubleToString(s.obstacle_distance_r,2)+"R";
      Reference(s,"obstacle",source,label,s.nearest_obstacle_time,s.nearest_obstacle_known_at,s.nearest_obstacle_tf,high,s.nearest_obstacle_price,at,clrOrchid);
     }
   bool Seen(const string key)
     {
      for(int i=0;i<ArraySize(m_seen);i++)if(m_seen[i]==key)return true;
      int n=ArraySize(m_seen);ArrayResize(m_seen,n+1,1024);m_seen[n]=key;return false;
     }
   void Pivot(const W33Pivot &p,const datetime at)
     {
      if(p.known_at>at)return;
      string key="P_"+TF(p.tf)+"_"+IntegerToString((long)p.time)+(p.is_high?"H":"L");
      if(Seen(key))return;
      int slot=p.tf==m_upper?0:(p.tf==m_lower?1:-1);
      if(slot<0 && !m_details)return;
      color c=slot==0?clrSteelBlue:(slot==1?clrMediumPurple:clrDarkOrchid);
      datetime plot=PlotTime(p.time,p.price,p.tf,p.is_high,p.known_at);
      string info=TF(p.tf)+" "+p.label+" | swing "+Clock(p.time)+" | plot "+Clock(plot)+" | known "+Clock(p.known_at);
      Dot(Name(key,"point"),plot,p.price,c,slot==0?2:1);Tip(Name(key,"point"),info);
      if(m_details){Text(Name(key,"label"),plot,p.price,TF(p.tf)+" "+p.label,c,p.is_high?ANCHOR_LEFT_LOWER:ANCHOR_LEFT_UPPER,7);Tip(Name(key,"label"),info);}
      if(slot<0 || !m_paths)return;
      if(m_have_previous[slot] && p.time==m_previous[slot].time)
        {
         if(p.is_high!=m_previous[slot].is_high)
           {
            // Outside bars have no OHLC-known high/low ordering. Do not invent it.
            string same_bar_path=Name("P_"+TF(p.tf)+"_"+IntegerToString((long)p.time)+(p.is_high?"L":"H"),"swing_path");
            if(m_previous[slot].known_at==p.known_at && ObjectFind(0,same_bar_path)>=0)ObjectDelete(0,same_bar_path);
            m_have_previous[slot]=false;
           }
         return;
        }
      if(m_have_previous[slot] && p.time>m_previous[slot].time && p.is_high!=m_previous[slot].is_high && plot>m_plot_previous[slot])
        {
         string path=Name(key,"swing_path");
         Segment(path,m_plot_previous[slot],m_previous[slot].price,plot,p.price,c,false,1,STYLE_DASH);
         Tip(path,"Confirmed swing path "+TF(p.tf)+" | from "+Clock(m_previous[slot].time)+" | to "+Clock(p.time)+" | available "+Clock(at));m_last_path[slot]=path;
        }
      // Same-side successive pivots are not presented as a high-to-low leg.
      m_previous[slot]=p;m_plot_previous[slot]=plot;m_have_previous[slot]=true;
     }
   string Reason(const string reason)
     {
      if(StringFind(reason,"INITIAL_MOVE_MISSED")>=0)return "初動を逃したため終了";
      if(StringFind(reason,"WAVE1_ROOM_TOO_SMALL")>=0)return "①終点まで余地不足";
      if(StringFind(reason,"WAVE1_ORIGIN_BROKEN")>=0)return "起点を突破";
      if(StringFind(reason,"TIMEOUT")>=0)return "時間切れ";
      if(StringFind(reason,"ACTIVE_SETUP_SAME_DIRECTION")>=0)return "別の波を監視中";
      if(StringFind(reason,"NO_LOWER_REVERSAL")>=0)return "転換なし";
      if(StringFind(reason,"OBSTACLE")>=0)return "抵抗が近い";
      if(StringFind(reason,"FIB_CLOSE_TOO_DEEP")>=0)return "上位足終値の押しが深い";
      if(StringFind(reason,"FIB_TOO_DEEP")>=0)return "押しが深い";
      if(StringFind(reason,"CENSORED")>=0)return "検証終了";
      return "条件未成立";
     }
public:
   void Init(const string prefix,const bool enabled)
     {
      m_prefix=prefix;m_enabled=enabled;m_serial=0;m_panel=false;m_details=false;m_paths=true;m_panel_clean=false;m_trigger_mode=W33_PIVOT_BREAK;
      ArrayResize(m_ids,0);ArrayResize(m_levels,0);ArrayResize(m_trends,0);ArrayResize(m_seen,0);ArrayResize(m_decision_live,0);ArrayResize(m_risk_live,0);
      for(int i=0;i<2;i++){m_have_previous[i]=false;m_last_path[i]="";m_plot_previous[i]=0;ZeroMemory(m_previous[i]);}
      if(enabled){ChartSetInteger(0,CHART_SHIFT,true);ChartSetDouble(0,CHART_SHIFT_SIZE,20.0);}
     }
   void ConfigureVisuals(const bool showPanel=false,const bool diagnosticLabels=false,const bool swingPaths=true){m_panel=showPanel;m_details=diagnosticLabels;m_paths=swingPaths;m_panel_clean=false;}
   void SetFrames(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower){m_upper=upper;m_lower=lower;}
   void SetTriggerMode(const W33TriggerMode mode){m_trigger_mode=mode;}
   void Event(const W33Event &e)
     {
      if(!m_enabled)return;
      Advance(e.at);
      if(e.has_pivot)Pivot(e.pivot,e.at);
      W33Setup s=e.setup;string id=s.setup_id;if(id=="")return;
      int lane=Lane(id);
      string unique=IntegerToString(++m_serial),info=id+" | "+e.event_type+" | known "+Clock(e.at);
      if(e.event_type=="WAVE1_BREAK")
        {
         Level(id,"upper_break",e.at,s.upper_break_level,clrSteelBlue,STYLE_DASH);
         Dot(Name(id,"candidate_point"),e.at,s.upper_break_level,clrSteelBlue);
         if(m_details){Text(Name(id,"candidate"),e.at,s.upper_break_level,"転換候補",clrSteelBlue);Tip(Name(id,"candidate"),info);}
        }
      if(e.event_type=="INITIAL_MOVE_PROGRESS" && s.first_progress_price>0)
        {
         string n=Name(id,"initial_move_progress");Dot(n,e.at,s.first_progress_price,clrSlateGray,2);
         Tip(n,"INITIAL_MOVE_PROGRESS bar "+Clock(s.first_progress_bar_time)+" close "+Clock(s.first_progress_close_at)+" known "+Clock(s.first_progress_known_at));
        }
      if(e.event_type=="LOWER_STRUCTURE_REJECTED" && m_details)
        {
         string n=Name(id,"wave2_binding_rejected");Text(n,e.at,s.wave2_extreme_price,"別の下位波：待機",clrSlateGray,ANCHOR_LEFT_UPPER,8);Tip(n,info+" | "+e.reason);
        }
      if(e.event_type=="WAVE1_PROVISIONAL" && s.wave1_provisional_price>0 && !s.wave1_peak_fixed)
        {
         datetime a=PlotTime(s.wave1_start_time,s.wave1_start_price,s.upper_tf,s.direction<0,e.at);
         Segment(Name(id,"provisional"),a,s.wave1_start_price,s.wave1_provisional_time,s.wave1_provisional_price,clrSlateGray,false,1,STYLE_DOT);
         Dot(Name(id,"provisional_history_"+unique),s.wave1_provisional_time,s.wave1_provisional_price,clrSlateGray);
         Tip(Name(id,"provisional_history_"+unique),info+" | provisional extreme "+Clock(s.wave1_provisional_time));
         Tip(Name(id,"provisional"),info+" | provisional W1, not a confirmed swing");
        }
      if(e.event_type=="WAVE1_PEAK_CONFIRMED")
        {
         datetime a=PlotTime(s.wave1_start_time,s.wave1_start_price,s.upper_tf,s.direction<0,e.at);
         datetime b=PlotTime(s.wave1_peak_time,s.wave1_peak_price,s.upper_tf,s.direction>0,e.at);
         ObjectDelete(0,Name(id,"provisional"));Segment(Name(id,"W1"),a,s.wave1_start_price,b,s.wave1_peak_price,clrDodgerBlue,false,3);
         Tip(Name(id,"W1"),info+" | start "+Clock(s.wave1_start_time)+" | peak "+Clock(s.wave1_peak_time));
         Text(Name(id,"W1_known"),b,s.wave1_peak_price,"① 第1波",clrDodgerBlue,s.direction>0?ANCHOR_LEFT_LOWER:ANCHOR_LEFT_UPPER,10);
         Tip(Name(id,"W1_known"),info+" | swing at "+Clock(s.wave1_peak_time)+" | confirmed "+Clock(s.wave1_peak_known_at));
        }
      if(m_decision_live[lane] && s.wave1_peak_fixed && s.fib_382_price>0)
        {
         string n=Name(id,"fib");
         if(ObjectFind(0,n)<0)ObjectCreate(0,n,OBJ_RECTANGLE,0,s.wave1_peak_known_at,s.fib_382_price,e.at,s.fib_618_price);
         FibEnd(id,e.at);ObjectSetInteger(0,n,OBJPROP_COLOR,clrDarkOrange);ObjectSetInteger(0,n,OBJPROP_STYLE,STYLE_DOT);
         ObjectSetInteger(0,n,OBJPROP_FILL,false);ObjectSetInteger(0,n,OBJPROP_BACK,true);Tip(n,id+" | Fib 38.2-61.8% | anchors known "+Clock(s.wave1_peak_known_at));
        }
      if((e.event_type=="WAVE2_EXTREME" || e.event_type=="FIB_TOUCH") && s.wave2_extreme_price>0)
        {
         datetime peak=PlotTime(s.wave1_peak_time,s.wave1_peak_price,s.upper_tf,s.direction>0,e.at);
         Segment(Name(id,"W2_leg"),peak,s.wave1_peak_price,s.wave2_extreme_time,s.wave2_extreme_price,clrDarkOrange,false,2);
         Dot(Name(id,"W2_history_"+unique),s.wave2_extreme_time,s.wave2_extreme_price,clrDarkOrange);Tip(Name(id,"W2_history_"+unique),info+" | extreme "+Clock(s.wave2_extreme_time)+" | deepest "+DoubleToString(s.retracement_ratio*100,1)+"%");
         Text(Name(id,"W2"),s.wave2_extreme_time,s.wave2_extreme_price,"② 押し・戻り",clrDarkOrange,s.direction>0?ANCHOR_LEFT_UPPER:ANCHOR_LEFT_LOWER,10);
         Tip(Name(id,"W2"),info+" | latest observed extreme "+Clock(s.wave2_extreme_time)+" | deepest "+DoubleToString(s.retracement_ratio*100,1)+"%");
         if(m_details)Text(Name(id,"W2_detail_"+unique),e.at,s.wave2_extreme_price,"W2 "+DoubleToString(s.retracement_ratio*100,1)+"%",clrDarkOrange);
        }
      if(e.event_type=="LOWER_STRUCTURE_CONFIRMED" || e.event_type=="TRIGGER_LINE_UPDATED")
        {
         CloseLine(m_levels[lane],e.at);CloseLine(m_trends[lane],e.at);
         if(m_trigger_mode!=W33_TRENDLINE_BREAK)
           {Level(id,"lower_level_"+unique,e.at,s.trigger_line_price,clrMediumPurple,STYLE_DASH);m_levels[lane]=Name(id,"lower_level_"+unique);Tip(m_levels[lane],LowerTip(s,e.at));}
         if(m_details)Text(Name(id,"lower_"+unique),e.at,s.trigger_line_price,"転換待ち",clrMediumPurple);
         if(m_trigger_mode!=W33_PIVOT_BREAK)
           {
            datetime ta=s.direction>0?s.lower_high1_time:s.lower_low1_time,tb=s.direction>0?s.lower_high2_time:s.lower_low2_time;
            double pa=s.direction>0?s.lower_high1_price:s.lower_low1_price,pb=s.direction>0?s.lower_high2_price:s.lower_low2_price;
            if(tb>ta && ta>0){double slope=(pb-pa)/(double)(tb-ta),start=pb+slope*(e.at-tb);m_trends[lane]=Name(id,"trendline_"+unique);Segment(m_trends[lane],e.at,start,e.at+Step(),start+slope*Step(),clrMediumPurple,false,1,STYLE_DASH);Tip(m_trends[lane],LowerTip(s,e.at));}
           }
        }
      if(e.event_type=="LOWER_STRUCTURE_LOST"){CloseLine(m_levels[lane],e.at);CloseLine(m_trends[lane],e.at);m_levels[lane]="";m_trends[lane]="";}
      if(e.event_type=="SIGNAL" || e.event_type=="RISK_CHECK")RiskReferences(s,e.at);
      bool riskRejected=s.entry_status=="SIGNAL_RISK_REJECTED";
      if((e.event_type=="SIGNAL" && !riskRejected) || e.event_type=="ORDER" || e.event_type=="FILL")
        {
         double price=s.entry_price;if(price<=0)price=s.trigger_line_price;
         string n=Name(id,"entry_"+unique);ObjectCreate(0,n,OBJ_ARROW,0,e.at,price);
         ObjectSetInteger(0,n,OBJPROP_ARROWCODE,s.direction>0?233:234);ObjectSetInteger(0,n,OBJPROP_COLOR,clrLimeGreen);ObjectSetInteger(0,n,OBJPROP_WIDTH,2);Tip(n,LowerTip(s,e.at));
         Text(Name(id,"entry_text"),e.at,price,(s.direction>0?"ENTRY 買い":"ENTRY 売り")+(e.event_type=="FILL"?" 約定":""),clrLimeGreen,s.direction>0?ANCHOR_LEFT_UPPER:ANCHOR_LEFT_LOWER,10);
         Tip(Name(id,"entry_text"),LowerTip(s,e.at));
         Level(id,"SL",e.at,s.sl_price,clrTomato);Level(id,"TP",e.at,s.tp_price,clrLimeGreen);
         Text(Name(id,"SL_label"),e.at+Step(),s.sl_price,"SL",clrTomato,ANCHOR_LEFT_LOWER);Text(Name(id,"TP_label"),e.at+Step(),s.tp_price,"TP",clrLimeGreen,ANCHOR_LEFT_LOWER);
        }
      if(e.event_type=="SIGNAL")CloseDecision(lane,e.at);
      // POSITION_TRACKING is an engine acknowledgement drained later than
      // immediate trade callbacks. It must not reopen lines after an EXIT.
      if(e.event_type=="ORDER" || e.event_type=="FILL")m_risk_live[lane]=true;
      if(e.event_type=="OPPOSITE_WAVE1_ARMED")
        {
         double price=s.entry_price-s.direction*MathAbs(s.entry_price-s.sl_price)*0.12;
         string n=Name(id,"opposite_wait");Text(n,e.at,price,"逆①：プラス決済待ち",clrGold,s.direction>0?ANCHOR_LEFT_UPPER:ANCHOR_LEFT_LOWER,8);
         Tip(n,"source "+s.opposite_setup_id+" | opposite swing "+Clock(s.opposite_wave_peak_time)+" | known "+Clock(s.opposite_wave_known_at)+" | SL/TP retained; net profit after estimated costs must exceed zero");
         Dot(Name(id,"opposite_known"),e.at,s.entry_price,clrGold,1);Tip(Name(id,"opposite_known"),info+" | source "+s.opposite_setup_id);
        }
      if(e.event_type=="EXIT" && s.exit_reason=="OPPOSITE_WAVE1_PROFIT" && s.exit_price>0)
        {
         string n=Name(id,"opposite_exit");Dot(n,e.at,s.exit_price,clrGold,2);
         Tip(n,"fill "+DoubleToString(s.exit_price,_Digits)+" | "+DoubleToString(s.realized_r,4)+"R | broker "+s.exit_deal_reason+" | known "+Clock(e.at));
         Text(Name(id,"opposite_exit_text"),e.at,s.exit_price,"EXIT 逆① 利益決済",clrGold,s.direction>0?ANCHOR_LEFT_LOWER:ANCHOR_LEFT_UPPER,9);
         Tip(Name(id,"opposite_exit_text"),"source "+s.opposite_setup_id+" | actual "+DoubleToString(s.realized_r,4)+"R | known "+Clock(e.at));
        }
      if(e.event_type=="COMPLETED" || e.event_type=="INVALIDATE")CloseDecision(lane,e.at);
      if(e.event_type=="EXIT" || e.event_type=="TEST_END" || e.event_type=="SKIP")
        {CloseDecision(lane,e.at);CloseRisk(lane,e.at);}
      if(e.event_type=="SKIP" || e.event_type=="INVALIDATE" || e.event_type=="TEST_END")
        {
         double p=s.entry_price;if(p<=0)p=s.wave2_extreme_price;if(p<=0)p=s.upper_break_level;
         if(e.reason=="FIB_CLOSE_TOO_DEEP" && s.fib_close_price>0)p=s.fib_close_price;
         double textPrice=p;datetime textAt=e.at;
         if(e.reason=="FIB_CLOSE_TOO_DEEP" && s.fib_close_price>0)
           {
            // A pre-entry close rejection has no SL width yet. Use a small
            // part of the fixed W1 span for caption spacing, retaining the
            // actual observed close as a point and a finite leader.
            textPrice=p-s.direction*MathAbs(s.wave1_peak_price-s.wave1_start_price)*0.04;textAt=e.at+Step();
            string observed="FIB_CLOSE_TOO_DEEP close "+DoubleToString(p,_Digits)+" known "+TimeToString(e.at,TIME_DATE|TIME_MINUTES);
            Dot(Name(id,"fib_close_point_"+unique),e.at,p,clrIndianRed,1);Tip(Name(id,"fib_close_point_"+unique),observed);
            Segment(Name(id,"fib_close_leader_"+unique),e.at,p,textAt,textPrice,clrIndianRed,false,1,STYLE_DOT);Tip(Name(id,"fib_close_leader_"+unique),observed);
           }
         if(s.entry_price>0 && s.sl_price>0)
           {
            // Caption spacing only: the signal/SL/TP and reference lines are
            // unchanged. A native-price point and short leader retain the
            // exact rejected signal location without colliding with captions.
            double risk=MathAbs(s.entry_price-s.sl_price);
            textPrice=p-s.direction*risk*0.12;textAt=e.at+Step();
            string priceTip="SKIP price "+DoubleToString(p,_Digits)+" "+StringSubstr(e.reason,0,48)+" known "+TimeToString(e.at,TIME_DATE|TIME_MINUTES);
            Dot(Name(id,"skipped_price_"+unique),e.at,p,clrIndianRed,1);Tip(Name(id,"skipped_price_"+unique),priceTip);
            Segment(Name(id,"skipped_leader_"+unique),e.at,p,textAt,textPrice,clrIndianRed,false,1,STYLE_DOT);Tip(Name(id,"skipped_leader_"+unique),priceTip);
           }
         string caption="見送り: "+Reason(e.reason);
         if(e.reason=="FIB_CLOSE_TOO_DEEP")caption="見送り: "+TF(s.upper_tf)+"終値の押し "+DoubleToString(s.fib_close_ratio*100,1)+"%";
         string n=Name(id,"skip_"+unique);Text(n,textAt,textPrice,caption,clrIndianRed,s.direction>0?ANCHOR_LEFT_UPPER:ANCHOR_LEFT_LOWER,8);
         string skipDetail=StringSubstr(e.reason,0,48)+" unmet "+StringSubstr(s.lower_unmet_reason,0,40)+" known "+TimeToString(e.at,TIME_DATE|TIME_MINUTES);
         if(s.lower_recognition!="" && StringLen(skipDetail+" "+s.lower_recognition)<=120)skipDetail+=" "+s.lower_recognition;
         Tip(n,skipDetail);
         if(e.reason=="FIB_CLOSE_TOO_DEEP")
           {
            string closeTip="FIB_CLOSE_TOO_DEEP "+TF(s.upper_tf)+" "+DoubleToString(s.fib_close_ratio*100,2)+"% bar "+ShortClock(s.fib_close_bar_time)+" known "+TimeToString(s.fib_close_known_at,TIME_DATE|TIME_MINUTES);
            Tip(n,closeTip);
           }
         if(s.sl_price>0 && ObjectFind(0,Name(id,"SL"))<0)Level(id,"skip_SL",e.at,s.sl_price,clrTomato);
         if(s.tp_price>0 && ObjectFind(0,Name(id,"TP"))<0)Level(id,"skip_TP",e.at,s.tp_price,clrLimeGreen);
        }
      ChartRedraw();
     }
   void Panel(const string text)
     {
      if(!m_enabled)return;
      if(!m_panel && m_panel_clean)return;
      if(!m_panel_clean){ObjectDelete(0,m_prefix+"panel_background");for(int i=0;i<14;i++)ObjectDelete(0,m_prefix+"panel_"+IntegerToString(i));m_panel_clean=true;}
      string n=m_prefix+"status_compact";if(!m_panel){ObjectDelete(0,n);return;}
      if(ObjectFind(0,n)<0)ObjectCreate(0,n,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_LOWER);ObjectSetInteger(0,n,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);ObjectSetInteger(0,n,OBJPROP_XDISTANCE,8);ObjectSetInteger(0,n,OBJPROP_YDISTANCE,22);
      ObjectSetInteger(0,n,OBJPROP_COLOR,clrSilver);ObjectSetInteger(0,n,OBJPROP_FONTSIZE,8);ObjectSetString(0,n,OBJPROP_FONT,"Meiryo");
      ObjectSetString(0,n,OBJPROP_TEXT,TF(m_upper)+"→"+TF(m_lower)+"  ①第1波 → ②押し・戻り → ENTRY   破線=確定した山谷");Tip(n,text);
     }
   void Clear(){if(m_prefix!="")ObjectsDeleteAll(0,m_prefix);}
  };
#endif
