#ifndef WAVE33_VISUAL_ROOM_MQH
#define WAVE33_VISUAL_ROOM_MQH
#include "Types.mqh"

// Apply to the executable quote and rounded structural stop, never a signal's
// historical close. Zero minimum is an explicit legacy-comparison switch.
bool W33CheckWave1Room(W33Setup &s,const double minimum)
  {
   double risk=s.direction*(s.entry_price-s.sl_price);
   s.wave1_room_price=s.direction*(s.wave1_peak_price-s.entry_price);
   s.wave1_room_r=risk>0 ? s.wave1_room_price/risk : -1;
   s.wave1_room_rejected=minimum>0 && (risk<=0 || s.wave1_room_r+1e-12<minimum);
   return !s.wave1_room_rejected;
  }
#endif
