#ifndef THREE_WAVE_FIB_TICK_POLICY
#define THREE_WAVE_FIB_TICK_POLICY
enum FibTickAction { FIB_WAIT, FIB_TOUCH, FIB_SEND, FIB_INVALIDATE };
FibTickAction FibAction(const int state,const bool active,const bool parent_used,
                       const double bid,const double reversal,const double parent_origin,
                       const double bottom,const double top,const long sequence,const long touch_sequence)
{
   if(state==2) return FIB_WAIT;
   if(!active || parent_used || bid<reversal || bid<parent_origin) return FIB_INVALIDATE;
   if(state==0) return bid>=bottom && bid<=top ? FIB_TOUCH : FIB_WAIT;
   return sequence>touch_sequence ? FIB_SEND : FIB_WAIT;
}
#endif
