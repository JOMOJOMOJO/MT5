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
   W33Pivot m_previous[2];
   datetime m_plot_previous[2];
   bool m_have_previous[2];
   string m_last_path[2],m_seen[];
   string Name(const string id,const string suffix){return m_prefix+W33Hash(id)+"_"+suffix;}
   string TF(const ENUM_TIMEFRAMES tf){string t=EnumToString(tf);StringReplace(t,"PERIOD_","");return t;}
   int Step(){return (int)MathMax(60,MathMax(PeriodSeconds((ENUM_TIMEFRAMES)_Period),PeriodSeconds(m_lower)));}
   string Clock(const datetime t){return TimeToString(t,TIME_DATE|TIME_SECONDS);}
   void Tip(const string name,const string text){if(m_enabled && ObjectFind(0,name)>=0)ObjectSetString(0,name,OBJPROP_TOOLTIP,text);}
   int Lane(const string id)
     {
      for(int i=0;i<ArraySize(m_ids);i++)if(m_ids[i]==id)return i;
      int n=ArraySize(m_ids);ArrayResize(m_ids,n+1);ArrayResize(m_levels,n+1);ArrayResize(m_trends,n+1);m_ids[n]=id;return n;
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
      Segment(n,known,price,known+Step(),price,c,true,1,style);
      Tip(n,id+" | "+suffix+" | known "+Clock(known)+" | "+DoubleToString(price,_Digits));
     }
   void CloseLine(const string name,const datetime at)
     {
      if(name=="" || ObjectFind(0,name)<0)return;
      datetime a=(datetime)ObjectGetInteger(0,name,OBJPROP_TIME,0),b=(datetime)ObjectGetInteger(0,name,OBJPROP_TIME,1);
      if(at<=a)return;
      double pa=ObjectGetDouble(0,name,OBJPROP_PRICE,0),pb=ObjectGetDouble(0,name,OBJPROP_PRICE,1);
      double p=b>a?pa+(pb-pa)*(double)(at-a)/(double)(b-a):pa;
      ObjectMove(0,name,1,at,p);ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
      if(!m_details)ObjectSetInteger(0,name,OBJPROP_COLOR,clrSlateGray);
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
      if(StringFind(reason,"WAVE1_ORIGIN_BROKEN")>=0)return "起点を突破";
      if(StringFind(reason,"TIMEOUT")>=0)return "時間切れ";
      if(StringFind(reason,"ACTIVE_SETUP_SAME_DIRECTION")>=0)return "別の波を監視中";
      if(StringFind(reason,"NO_LOWER_REVERSAL")>=0)return "転換なし";
      if(StringFind(reason,"OBSTACLE")>=0)return "抵抗が近い";
      if(StringFind(reason,"FIB_TOO_DEEP")>=0)return "押しが深い";
      if(StringFind(reason,"CENSORED")>=0)return "検証終了";
      return "条件未成立";
     }
public:
   void Init(const string prefix,const bool enabled)
     {
      m_prefix=prefix;m_enabled=enabled;m_serial=0;m_panel=false;m_details=false;m_paths=true;m_panel_clean=false;m_trigger_mode=W33_PIVOT_BREAK;
      ArrayResize(m_ids,0);ArrayResize(m_levels,0);ArrayResize(m_trends,0);ArrayResize(m_seen,0);
      for(int i=0;i<2;i++){m_have_previous[i]=false;m_last_path[i]="";m_plot_previous[i]=0;ZeroMemory(m_previous[i]);}
      if(enabled){ChartSetInteger(0,CHART_SHIFT,true);ChartSetDouble(0,CHART_SHIFT_SIZE,20.0);}
     }
   void ConfigureVisuals(const bool showPanel=false,const bool diagnosticLabels=false,const bool swingPaths=true){m_panel=showPanel;m_details=diagnosticLabels;m_paths=swingPaths;m_panel_clean=false;}
   void SetFrames(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower){m_upper=upper;m_lower=lower;}
   void SetTriggerMode(const W33TriggerMode mode){m_trigger_mode=mode;}
   void Event(const W33Event &e)
     {
      if(!m_enabled)return;
      if(e.has_pivot)Pivot(e.pivot,e.at);
      W33Setup s=e.setup;string id=s.setup_id;if(id=="")return;
      string unique=IntegerToString(++m_serial),info=id+" | "+e.event_type+" | known "+Clock(e.at);
      if(e.event_type=="WAVE1_BREAK")
        {
         Level(id,"upper_break",e.at,s.upper_break_level,clrSteelBlue,STYLE_DASH);
         Dot(Name(id,"candidate_point"),e.at,s.upper_break_level,clrSteelBlue);
         if(m_details){Text(Name(id,"candidate"),e.at,s.upper_break_level,"転換候補",clrSteelBlue);Tip(Name(id,"candidate"),info);}
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
      if(s.wave1_peak_fixed && s.fib_382_price>0)
        {
         string n=Name(id,"fib");
         if(ObjectFind(0,n)<0)ObjectCreate(0,n,OBJ_RECTANGLE,0,s.wave1_peak_known_at,s.fib_382_price,e.at+Step(),s.fib_618_price);
         ObjectMove(0,n,1,e.at+Step(),s.fib_618_price);ObjectSetInteger(0,n,OBJPROP_COLOR,clrDarkOrange);ObjectSetInteger(0,n,OBJPROP_STYLE,STYLE_DOT);
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
         int lane=Lane(id);CloseLine(m_levels[lane],e.at);CloseLine(m_trends[lane],e.at);
         if(m_trigger_mode!=W33_TRENDLINE_BREAK)
           {Level(id,"lower_level_"+unique,e.at,s.trigger_line_price,clrMediumPurple,STYLE_DASH);m_levels[lane]=Name(id,"lower_level_"+unique);Tip(m_levels[lane],info+" | return pivot "+s.lower_pivot_times+" | "+s.lower_pivot_prices);}
         if(m_details)Text(Name(id,"lower_"+unique),e.at,s.trigger_line_price,"転換待ち",clrMediumPurple);
         if(m_trigger_mode!=W33_PIVOT_BREAK)
           {
            datetime ta=s.direction>0?s.lower_high1_time:s.lower_low1_time,tb=s.direction>0?s.lower_high2_time:s.lower_low2_time;
            double pa=s.direction>0?s.lower_high1_price:s.lower_low1_price,pb=s.direction>0?s.lower_high2_price:s.lower_low2_price;
            if(tb>ta && ta>0){double slope=(pb-pa)/(double)(tb-ta),start=pb+slope*(e.at-tb);m_trends[lane]=Name(id,"trendline_"+unique);Segment(m_trends[lane],e.at,start,e.at+Step(),start+slope*Step(),clrMediumPurple,true,1,STYLE_DASH);Tip(m_trends[lane],info);}
           }
        }
      if(e.event_type=="LOWER_STRUCTURE_LOST"){int lane=Lane(id);CloseLine(m_levels[lane],e.at);CloseLine(m_trends[lane],e.at);}
      if((e.event_type=="SIGNAL" || e.event_type=="RISK_CHECK") && s.nearest_obstacle_price>0)
        {
         Level(id,"obstacle",e.at,s.nearest_obstacle_price,clrOrchid,STYLE_DOT);
         Text(Name(id,"room"),e.at+Step(),s.nearest_obstacle_price,s.direction>0?"抵抗":"支持",clrOrchid,s.direction>0?ANCHOR_LEFT_LOWER:ANCHOR_LEFT_UPPER,8);
         Tip(Name(id,"room"),info+" | room "+DoubleToString(s.obstacle_distance_r,2)+"R | level known "+Clock(s.nearest_obstacle_known_at));
        }
      if(e.event_type=="SIGNAL" || e.event_type=="ORDER" || e.event_type=="FILL")
        {
         double price=s.entry_price;if(price<=0)price=s.trigger_line_price;
         string n=Name(id,"entry_"+unique);ObjectCreate(0,n,OBJ_ARROW,0,e.at,price);
         ObjectSetInteger(0,n,OBJPROP_ARROWCODE,s.direction>0?233:234);ObjectSetInteger(0,n,OBJPROP_COLOR,clrLimeGreen);ObjectSetInteger(0,n,OBJPROP_WIDTH,2);Tip(n,info+" | "+s.trigger_type);
         Text(Name(id,"entry_text"),e.at,price,(s.direction>0?"ENTRY 買い":"ENTRY 売り")+(e.event_type=="FILL"?" 約定":""),clrLimeGreen,s.direction>0?ANCHOR_LEFT_UPPER:ANCHOR_LEFT_LOWER,10);
         Tip(Name(id,"entry_text"),info+" | "+s.trigger_type+" | "+s.entry_status);
         Level(id,"SL",e.at,s.sl_price,clrTomato);Level(id,"TP",e.at,s.tp_price,clrLimeGreen);
         Text(Name(id,"SL_label"),e.at+Step()*2,s.sl_price,"SL",clrTomato,ANCHOR_LEFT_LOWER);Text(Name(id,"TP_label"),e.at+Step()*2,s.tp_price,"TP",clrLimeGreen,ANCHOR_LEFT_LOWER);
        }
      if(e.event_type=="SKIP" || e.event_type=="INVALIDATE" || e.event_type=="TEST_END")
        {
         double p=s.entry_price;if(p<=0)p=s.wave2_extreme_price;if(p<=0)p=s.upper_break_level;
         string n=Name(id,"skip_"+unique);Text(n,e.at,p,"見送り: "+Reason(e.reason),clrIndianRed,s.direction>0?ANCHOR_LEFT_LOWER:ANCHOR_LEFT_UPPER,8);Tip(n,info+" | "+e.reason_kind+" | "+e.reason);
         int lane=Lane(id);CloseLine(m_levels[lane],e.at);CloseLine(m_trends[lane],e.at);
         if(s.sl_price>0)Level(id,"skip_SL",e.at,s.sl_price,clrTomato);if(s.tp_price>0)Level(id,"skip_TP",e.at,s.tp_price,clrLimeGreen);
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
