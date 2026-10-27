#ifndef WAVE33_CHOP_FILTER_DISPLAY_MQH
#define WAVE33_CHOP_FILTER_DISPLAY_MQH
#include "Display.mqh"
#include "LabelLayout.mqh"

// EA-local caption adapter. The original display and its decision state stay
// unchanged. Its Event() advances the object serial once per nonempty setup ID.
class CWave33ChopDisplay : public CWave33Display
  {
private:
   string m_chop_prefix;
   bool m_chop_enabled;
   int m_chop_serial;
   CWave33LabelLayout m_readable;
public:
   void Init(const string prefix,const bool enabled)
     {
      m_chop_prefix=prefix;m_chop_enabled=enabled;m_chop_serial=0;
      m_readable.Init(prefix);
      CWave33Display::Init(prefix,enabled);
     }
   void ConfigureReadability(const bool enabled){m_readable.Configure(enabled && m_chop_enabled);}
   void Layout(const bool force=false){m_readable.Layout(force);}
   bool LabelAnchor(const string name,datetime &at,double &price) const{return m_readable.Anchor(name,at,price);}
   bool LabelBounds(const string name,int &x,int &y,int &w,int &h) const{return m_readable.Bounds(name,x,y,w,h);}
   bool LabelManaged(const string name) const{return m_readable.Managed(name);}
   int LabelCount() const{return m_readable.Count();}
   void Event(const W33Event &e)
     {
      CWave33Display::Event(e);
      if(!m_chop_enabled || e.setup.setup_id=="")return;
      m_chop_serial++;
      m_readable.Setup(e.setup.setup_id,StringSubstr(W33Hash(e.setup.setup_id),0,4));
      m_readable.Dirty();
      string key=m_chop_prefix+W33Hash(e.setup.setup_id)+"_";
      string revision=e.setup.wave1_revision>0?"_r"+IntegerToString(e.setup.wave1_revision):"";
      m_readable.Touch(key+"W1_known"+revision);m_readable.Touch(key+"W2"+revision);
      m_readable.Touch(key+"extension_tracking"+revision);m_readable.Touch(key+"entry_text");
      m_readable.Touch(key+"SL_label");m_readable.Touch(key+"TP_label");
      if(e.event_type!="SKIP" && e.event_type!="INVALIDATE" && e.event_type!="TEST_END")return;
      string name=m_chop_prefix+W33Hash(e.setup.setup_id)+"_skip_"+IntegerToString(m_chop_serial);
      if(e.reason=="CHOPPY_WAVE1" || e.reason=="PRIOR_LEVEL_RETEST" || e.reason=="CONNECTED_OPPOSITE_W1_BOTH")
         ObjectSetString(0,name,OBJPROP_TEXT,e.reason=="CHOPPY_WAVE1"?"見送り: ①内部の往復が多い":
                        (e.reason=="PRIOR_LEVEL_RETEST"?"見送り: 上位足の高安帯に再接近":"見送り 両側①"));
      if(e.reason=="CONNECTED_OPPOSITE_W1_BOTH")
        {
         string tip=e.reason+"\n"+e.setup.setup_id+"\nother "+e.setup.connected_opposite_setup_id;
         tip+="\nshared "+TimeToString(e.setup.connected_shared_time,TIME_DATE|TIME_SECONDS)+" @"+DoubleToString(e.setup.connected_shared_price,_Digits);
         tip+="\nknown "+TimeToString(e.setup.connected_opposite_known_at,TIME_DATE|TIME_SECONDS);
         ObjectSetString(0,name,OBJPROP_TOOLTIP,tip);
        }
      // Base captions sometimes have a small price/time offset. The display
      // layout's leader must still terminate at the actual rejected decision.
      double price=e.setup.entry_price;
      if(price<=0)price=e.setup.wave2_extreme_price;
      if(price<=0)price=e.setup.upper_break_level;
      if(e.reason=="FIB_CLOSE_TOO_DEEP" && e.setup.fib_close_price>0)price=e.setup.fib_close_price;
      if(e.reason=="CONNECTED_OPPOSITE_W1_BOTH" && e.at>0 && price>0)
        {
         string point=key+"pair_cancel_known";
         if(ObjectFind(0,point)<0)ObjectCreate(0,point,OBJ_ARROW,0,e.at,price);
         ObjectSetInteger(0,point,OBJPROP_ARROWCODE,159);ObjectSetInteger(0,point,OBJPROP_COLOR,clrIndianRed);
         ObjectSetInteger(0,point,OBJPROP_WIDTH,2);ObjectSetInteger(0,point,OBJPROP_SELECTABLE,false);
         ObjectSetString(0,point,OBJPROP_TOOLTIP,ObjectGetString(0,name,OBJPROP_TOOLTIP));
        }
      m_readable.SetAnchor(name,e.at,price);
     }
   void Clear(){m_readable.Clear();CWave33Display::Clear();}
  };
#endif
