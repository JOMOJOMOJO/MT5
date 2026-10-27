#ifndef WAVE33_CHOP_FILTER_DISPLAY_MQH
#define WAVE33_CHOP_FILTER_DISPLAY_MQH
#include "Display.mqh"

// EA-local caption adapter. The original display and its decision state stay
// unchanged. Its Event() advances the object serial once per nonempty setup ID.
class CWave33ChopDisplay : public CWave33Display
  {
private:
   string m_chop_prefix;
   bool m_chop_enabled;
   int m_chop_serial;
public:
   void Init(const string prefix,const bool enabled)
     {
      m_chop_prefix=prefix;m_chop_enabled=enabled;m_chop_serial=0;
      CWave33Display::Init(prefix,enabled);
     }
   void Event(const W33Event &e)
     {
      CWave33Display::Event(e);
      if(!m_chop_enabled || e.setup.setup_id=="")return;
      m_chop_serial++;
      if(e.event_type!="SKIP" || e.reason!="CHOPPY_WAVE1")return;
      string name=m_chop_prefix+W33Hash(e.setup.setup_id)+"_skip_"+IntegerToString(m_chop_serial);
      ObjectSetString(0,name,OBJPROP_TEXT,"見送り: ①内部の往復が多い");
     }
  };
#endif
