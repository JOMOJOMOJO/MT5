#ifndef WAVE33_VISUAL_CONNECTED_WAVE_MQH
#define WAVE33_VISUAL_CONNECTED_WAVE_MQH
#include "Types.mqh"

// Both snapshots are facts available NOW. The new candidate does not need a
// confirmed endpoint; only its origin must be the old, already fixed endpoint.
bool W33ConnectedOppositeUnordered(const W33Setup &older,const W33Setup &newer,
                                  const bool orderSubmitted,const datetime knownAt,
                                  const double point)
  {
   if(!MathIsValidNumber(point) || point<=0 || !older.active || !newer.active ||
      !older.wave1_peak_fixed || older.position_open || orderSubmitted ||
      older.order_sent_at>0 || older.fill_at>0 || older.connected_opposite_cancelled) return false;
   if(older.setup_id=="" || newer.setup_id=="" || older.setup_id==newer.setup_id ||
      (older.direction!=1 && older.direction!=-1) || newer.direction!=-older.direction ||
      older.symbol!=newer.symbol || older.upper_tf!=newer.upper_tf || older.lower_tf!=newer.lower_tf) return false;
   if(older.candidate_detected_at<=0 || newer.candidate_detected_at<=older.candidate_detected_at ||
      newer.candidate_detected_at>knownAt || older.last_updated_at>knownAt ||
      older.wave1_peak_known_at<=0 || older.wave1_peak_known_at>knownAt ||
      newer.wave1_start_known_at<=0 || newer.wave1_start_known_at>knownAt ||
      newer.upper_break_confirmed_at<=0 || newer.upper_break_confirmed_at>knownAt) return false;
   if(older.wave1_peak_time<=0 || newer.wave1_start_time!=older.wave1_peak_time ||
      newer.wave1_start_time>knownAt || !MathIsValidNumber(older.wave1_peak_price) ||
      !MathIsValidNumber(newer.wave1_start_price)) return false;
   // The tiny relative term only absorbs floating point representation at
   // exact half-point equality; it is not an extra tradable price allowance.
   return MathAbs(newer.wave1_start_price-older.wave1_peak_price)<=point*(0.5+1e-9);
  }
#endif
