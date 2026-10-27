#ifndef WAVE33_VISUAL_CONNECTED_PAIR_MQH
#define WAVE33_VISUAL_CONNECTED_PAIR_MQH
#include "ConnectedWave.mqh"

// Apply the pair policy atomically. The connection itself is the SAME causal
// old-endpoint/new-origin test used by the original old-only cancellation.
// Submitted or filled orders are never retrospectively cancelled here.
bool W33InvalidateConnectedPairUnordered(W33Setup &older,W33Setup &newer,
                                        const bool olderOrderSubmitted,
                                        const bool newerOrderSubmitted,
                                        const datetime knownAt,const double point)
  {
   if(newerOrderSubmitted || newer.position_open || newer.order_sent_at>0 ||
      newer.fill_at>0 || newer.connected_opposite_cancelled ||
      !W33ConnectedOppositeUnordered(older,newer,olderOrderSubmitted,knownAt,point)) return false;
   string olderId=older.setup_id,newerId=newer.setup_id;
   datetime sharedTime=older.wave1_peak_time;
   double sharedPrice=older.wave1_peak_price;
   older.connected_opposite_cancelled=true;
   older.connected_opposite_setup_id=newerId;
   older.connected_opposite_known_at=knownAt;
   older.connected_shared_time=sharedTime;
   older.connected_shared_price=sharedPrice;
   older.active=false;
   older.entry_status="INVALIDATED";
   older.skip_reason="CONNECTED_OPPOSITE_W1_BOTH";
   newer.connected_opposite_cancelled=true;
   newer.connected_opposite_setup_id=olderId;
   newer.connected_opposite_known_at=knownAt;
   newer.connected_shared_time=sharedTime;
   newer.connected_shared_price=sharedPrice;
   newer.active=false;
   newer.entry_status="INVALIDATED";
   newer.skip_reason="CONNECTED_OPPOSITE_W1_BOTH";
   return true;
  }
#endif
