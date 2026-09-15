#ifndef TICK_SHOCK_BARRIER_CORE_MQH
#define TICK_SHOCK_BARRIER_CORE_MQH
bool TSGBounds(const int side,const double entry,const double atr,const double tp_atr,const double sl_atr,
               const double tick,double &sl,double &tp)
  {
   if((side!=1&&side!=-1)||!MathIsValidNumber(entry)||!MathIsValidNumber(atr)||!MathIsValidNumber(tp_atr)||!MathIsValidNumber(sl_atr)||!MathIsValidNumber(tick)||entry<=0||atr<=0||tp_atr<=0||sl_atr<=0||tick<=0)return false;
   // SL rounds toward entry (never widen the risk); TP rounds away from entry.
   sl=side>0?MathCeil((entry-sl_atr*atr)/tick-1e-10)*tick:MathFloor((entry+sl_atr*atr)/tick+1e-10)*tick;
   tp=side>0?MathCeil((entry+tp_atr*atr)/tick-1e-10)*tick:MathFloor((entry-tp_atr*atr)/tick+1e-10)*tick;
   return sl>0&&tp>0&&side*(entry-sl)>0&&side*(tp-entry)>0;
  }
bool TSGBrokerBounds(const int side,const double bid,const double ask,const double sl,const double tp,const double stops)
  {
   if((side!=1&&side!=-1)||bid<=0||ask<=bid||stops<0)return false;
   return side>0?(bid-sl>=stops-1e-12&&tp-bid>=stops-1e-12):(sl-ask>=stops-1e-12&&ask-tp>=stops-1e-12);
  }
bool TSGSpacing(const long last_fill,const long now,const int seconds)
  {return seconds>0&&(last_fill==0||now-last_fill>=(long)seconds*1000);}
#endif
