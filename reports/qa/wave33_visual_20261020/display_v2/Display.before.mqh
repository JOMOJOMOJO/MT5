#ifndef WAVE33_DISPLAY_MQH
#define WAVE33_DISPLAY_MQH
#include "Types.mqh"
string W33Hash(const string value)
  {
   uint a=2166136261,b=2246822519;
   for(int i=0;i<StringLen(value);i++){a^=(uint)StringGetCharacter(value,i);a*=16777619;b^=(uint)StringGetCharacter(value,StringLen(value)-1-i);b*=3266489917;}
   return StringFormat("%08X%08X",a,b);
  }
// This module consumes snapshots only. Object changes never feed the engine.
class CWave33Display
  {
private:
   string m_prefix;
   bool m_enabled;
   int m_serial;
   ENUM_TIMEFRAMES m_upper,m_lower;
   string m_ids[],m_levels[],m_trends[];
   void CloseLine(const string name,const datetime at)
     {
      if(name=="" || ObjectFind(0,name)<0)return;
      datetime a=(datetime)ObjectGetInteger(0,name,OBJPROP_TIME,0),b=(datetime)ObjectGetInteger(0,name,OBJPROP_TIME,1);
      double pa=ObjectGetDouble(0,name,OBJPROP_PRICE,0),pb=ObjectGetDouble(0,name,OBJPROP_PRICE,1);
      double p=b>a?pa+(pb-pa)*(double)(at-a)/(double)(b-a):pa;
      ObjectMove(0,name,1,at,p);ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
     }
   int Lane(const string id)
     {
      for(int i=0;i<ArraySize(m_ids);i++)if(m_ids[i]==id)return i;
      int n=ArraySize(m_ids);ArrayResize(m_ids,n+1);ArrayResize(m_levels,n+1);ArrayResize(m_trends,n+1);m_ids[n]=id;return n;
     }
   string Name(const string id,const string suffix){return m_prefix+W33Hash(id)+"_"+suffix;}
   int Step(){return (int)MathMax(60,MathMax(PeriodSeconds((ENUM_TIMEFRAMES)_Period),PeriodSeconds(m_lower)));}
   void Text(const string name,const datetime at,const double price,const string text,const color c)
     {
      if(!m_enabled || at<=0 || price<=0)return;
      if(ObjectFind(0,name)<0)ObjectCreate(0,name,OBJ_TEXT,0,at,price);
      ObjectSetString(0,name,OBJPROP_TEXT,text);ObjectSetInteger(0,name,OBJPROP_COLOR,c);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);
      ObjectSetString(0,name,OBJPROP_TOOLTIP,text);
     }
   void Segment(const string name,const datetime a,const double pa,const datetime b,const double pb,const color c,const bool ray=false,const int width=1)
     {
      if(!m_enabled || a<=0 || pa<=0 || pb<=0)return;
      if(ObjectFind(0,name)<0)ObjectCreate(0,name,OBJ_TREND,0,a,pa,b,pb);
      ObjectSetInteger(0,name,OBJPROP_COLOR,c);ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
      ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,ray);
     }
   void Level(const string id,const string suffix,const datetime known,const double price,const color c)
     {Segment(Name(id,suffix),known,price,known+Step(),price,c,true);}
public:
   void Init(const string prefix,const bool enabled){m_prefix=prefix;m_enabled=enabled;m_serial=0;ArrayResize(m_ids,0);ArrayResize(m_levels,0);ArrayResize(m_trends,0);if(enabled){ChartSetInteger(0,CHART_SHIFT,true);ChartSetDouble(0,CHART_SHIFT_SIZE,20.0);}}
   void SetFrames(const ENUM_TIMEFRAMES upper,const ENUM_TIMEFRAMES lower){m_upper=upper;m_lower=lower;}
   void Event(const W33Event &e)
     {
      if(!m_enabled)return;
      W33Setup s=e.setup;string id=s.setup_id;string unique=IntegerToString(++m_serial);
      if(e.has_pivot)
        {
         string key="KNOWN_"+EnumToString(e.pivot.tf)+"_"+IntegerToString((int)e.pivot.time)+"_"+(e.pivot.is_high?"H":"L");
         color c=e.pivot.tf==m_lower?clrMediumPurple:(e.pivot.tf==m_upper?clrDodgerBlue:clrMagenta);
         string tf=EnumToString(e.pivot.tf);StringReplace(tf,"PERIOD_","");
         Text(Name(key,"label"),e.pivot.known_at,e.pivot.price,tf+" "+e.pivot.label,c);
         ObjectSetString(0,Name(key,"label"),OBJPROP_TOOLTIP,"Pivot "+TimeToString(e.pivot.time,TIME_DATE|TIME_MINUTES)+" known "+TimeToString(e.pivot.known_at,TIME_DATE|TIME_MINUTES));
         if(e.pivot.tf!=m_lower)Segment(Name(key,"level"),e.pivot.known_at,e.pivot.price,e.pivot.known_at+2*PeriodSeconds(e.pivot.tf),e.pivot.price,c);
        }
      if(id=="")return;
      if(e.event_type=="WAVE1_BREAK")
        {Level(id,"upper_break",e.at,s.upper_break_level,clrDodgerBlue);
         Text(Name(id,"candidate"),e.at,s.upper_break_level,"BREAK "+id,clrDodgerBlue);}
      if(s.wave1_provisional_price>0 && !s.wave1_peak_fixed)
         Segment(Name(id,"provisional_"+unique),s.wave1_start_time,s.wave1_start_price,s.wave1_provisional_time,s.wave1_provisional_price,clrSteelBlue,false,1);
      if(e.event_type=="WAVE1_PEAK_CONFIRMED")
        {
         Segment(Name(id,"W1"),s.wave1_start_time,s.wave1_start_price,s.wave1_peak_time,s.wave1_peak_price,clrBlue,false,3);
         Text(Name(id,"W1_known"),e.at,s.wave1_peak_price,"W1 confirmed "+TimeToString(e.at,TIME_DATE|TIME_MINUTES)+" (peak "+TimeToString(s.wave1_peak_time,TIME_MINUTES)+")",clrBlue);
        }
      if(s.wave1_peak_fixed && s.fib_382_price>0)
        {
         string n=Name(id,"fib");
         if(ObjectFind(0,n)<0)ObjectCreate(0,n,OBJ_RECTANGLE,0,s.wave1_peak_known_at,s.fib_382_price,e.at+60,s.fib_618_price);
         ObjectMove(0,n,1,e.at+60,s.fib_618_price);ObjectSetInteger(0,n,OBJPROP_COLOR,clrOrange);
         ObjectSetInteger(0,n,OBJPROP_FILL,false);ObjectSetInteger(0,n,OBJPROP_BACK,true);
        }
      if(e.event_type=="WAVE2_EXTREME" || e.event_type=="FIB_TOUCH")
         Text(Name(id,"W2_"+unique),e.at,s.wave2_extreme_price,"W2 "+DoubleToString(s.retracement_ratio*100,1)+"%",clrDarkOrange);
      if(e.event_type=="LOWER_STRUCTURE_CONFIRMED" || e.event_type=="TRIGGER_LINE_UPDATED")
        {
         int lane=Lane(id);CloseLine(m_levels[lane],e.at);CloseLine(m_trends[lane],e.at);
         Level(id,"lower_level_"+unique,e.at,s.trigger_line_price,clrMediumPurple);
         m_levels[lane]=Name(id,"lower_level_"+unique);
         Text(Name(id,"lower_"+unique),e.at,s.trigger_line_price,"REV "+DoubleToString(s.trigger_line_price,_Digits),clrMediumPurple);
         ObjectSetString(0,Name(id,"lower_"+unique),OBJPROP_TOOLTIP,s.lower_pivot_times+" | "+s.lower_pivot_prices);
         datetime ta=s.direction>0?s.lower_high1_time:s.lower_low1_time,tb=s.direction>0?s.lower_high2_time:s.lower_low2_time;
         double pa=s.direction>0?s.lower_high1_price:s.lower_low1_price,pb=s.direction>0?s.lower_high2_price:s.lower_low2_price;
         if(tb>ta && ta>0)
           {
            double slope=(pb-pa)/(double)(tb-ta),start=pb+slope*(e.at-tb);
            m_trends[lane]=Name(id,"trendline_"+unique);
            Segment(m_trends[lane],e.at,start,e.at+Step(),start+slope*Step(),clrMediumPurple,true);
           }
        }
      if(e.event_type=="LOWER_STRUCTURE_LOST")
        {int lane=Lane(id);CloseLine(m_levels[lane],e.at);CloseLine(m_trends[lane],e.at);}
      if(s.nearest_obstacle_price>0)
        {Level(id,"obstacle_"+unique,e.at,s.nearest_obstacle_price,clrMagenta);
         Text(Name(id,"room_"+unique),e.at,s.nearest_obstacle_price,"ROOM_TO_RESISTANCE_R="+DoubleToString(s.obstacle_distance_r,2),clrMagenta);}
      if(e.event_type=="SIGNAL" || e.event_type=="ORDER" || e.event_type=="FILL")
        {
         double price=s.entry_price;if(price<=0)price=s.trigger_line_price;
         string n=Name(id,"entry_"+unique);ObjectCreate(0,n,OBJ_ARROW,0,e.at,price);
         ObjectSetInteger(0,n,OBJPROP_ARROWCODE,s.direction>0?233:234);ObjectSetInteger(0,n,OBJPROP_COLOR,clrLimeGreen);
         Text(Name(id,"entry_text_"+unique),e.at,price,e.event_type+" "+s.trigger_type+" "+s.entry_status,clrGreen);
         Level(id,"SL_"+unique,e.at,s.sl_price,clrRed);Level(id,"TP_"+unique,e.at,s.tp_price,clrGreen);
        }
      if(e.event_type=="SKIP" || e.event_type=="INVALIDATE" || e.event_type=="TEST_END")
        {
         double p=s.entry_price;if(p<=0)p=s.wave2_extreme_price;if(p<=0)p=s.upper_break_level;
         Text(Name(id,"skip_"+unique),e.at,p,"SKIP "+e.reason_kind+" "+e.reason,clrCrimson);
         if(s.sl_price>0)Level(id,"skip_SL",e.at,s.sl_price,clrRed);
         if(s.tp_price>0)Level(id,"skip_TP",e.at,s.tp_price,clrGreen);
        }
      if(e.event_type=="LOWER_PIVOT")
         Text(Name(id,"pivot_"+unique),e.at,s.trigger_line_price,"known "+TimeToString(e.at,TIME_MINUTES)+" | "+e.reason,clrPurple);
      if(e.event_type=="TRENDLINE_DEFINED")
        {
         // Engine provides line value at knowledge time and one minute later.
         string parts[];if(StringSplit(e.reason,'|',parts)==2)
            Segment(Name(id,"TL_"+unique),e.at,StringToDouble(parts[0]),e.at+Step(),StringToDouble(parts[0])+(StringToDouble(parts[1])-StringToDouble(parts[0]))*Step()/60.0,clrPurple,true);
        }
      ChartRedraw();
     }
   void Panel(const string text)
     {
      if(!m_enabled)return;
      string lines[];int count=StringSplit(text,'\n',lines);
      string bg=m_prefix+"panel_background";
      if(ObjectFind(0,bg)<0)ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,5);ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,12);
      ObjectSetInteger(0,bg,OBJPROP_XSIZE,650);ObjectSetInteger(0,bg,OBJPROP_YSIZE,count*17+10);
      ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,clrBlack);ObjectSetInteger(0,bg,OBJPROP_COLOR,clrBlack);
      for(int i=0;i<14;i++)
        {
         string n=m_prefix+"panel_"+IntegerToString(i);
         if(i>=count){ObjectDelete(0,n);continue;}
         if(ObjectFind(0,n)<0)ObjectCreate(0,n,OBJ_LABEL,0,0,0);
         ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);ObjectSetInteger(0,n,OBJPROP_XDISTANCE,10);
         ObjectSetInteger(0,n,OBJPROP_YDISTANCE,18+i*17);ObjectSetInteger(0,n,OBJPROP_COLOR,clrWhite);
         ObjectSetInteger(0,n,OBJPROP_FONTSIZE,9);ObjectSetString(0,n,OBJPROP_TEXT,lines[i]);
        }
     }
   void Clear(){ObjectsDeleteAll(0,m_prefix);}
  };
#endif
