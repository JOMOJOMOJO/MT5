#ifndef THREE_WAVE_HL_TICK_POLICY
#define THREE_WAVE_HL_TICK_POLICY
enum HLTickAction { HL_WAIT, HL_DECIDE, HL_INVALIDATE };
HLTickAction HLAction(bool consumed,bool active,bool parent_used,double bid,double ask,
                      double hl,double origin,double parent_origin,double top,bool immediate)
{
   if(consumed) return HL_WAIT;
   if(!active || parent_used || bid<hl || bid<origin || bid<parent_origin) return HL_INVALIDATE;
   if(immediate || (ask>=hl && ask<=top)) return HL_DECIDE;
   return HL_WAIT;
}
#endif
