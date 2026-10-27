#ifndef WAVE33_VISUAL_OPPOSITE_EXIT_MQH
#define WAVE33_VISUAL_OPPOSITE_EXIT_MQH

// Pure policy: no market data, trading, drawing or event-type selection here.
// The caller supplies an actual-fill order key and a monotone knowledge-order
// key. These keys distinguish events occurring within the same datetime second;
// a historical pivot location is never a valid replacement for event_known_at.
struct W33OppositeExitState
  {
   bool armed;
   bool request_pending;
   string source_setup_id;
   int source_direction;
   datetime detected_at;
   ulong detected_order_key;
   datetime requested_at;
   ulong requested_order_key;
   int attempts;
  };

void W33ResetOppositeExit(W33OppositeExitState &state)
  {
   ZeroMemory(state);
   // MQL ZeroMemory leaves string storage NULL, which is distinct from an
   // explicitly empty string in native equality checks. Normalize the source
   // identity so a flat position has no residual or indeterminate cause.
   state.source_setup_id="";
  }

// realized_cash already contains all booked profit, commission, fee and swap.
// remaining_swap belongs only to the still-open volume. A conservative closing
// cost is estimated from the observed nonnegative entry cost per filled volume;
// this is an estimate, never a promise that the eventual fill will be positive.
double W33OppositeNetEstimate(const double quote_profit,
                             const double realized_cash,
                             const double remaining_swap,
                             const double entry_cost_per_volume,
                             const double remaining_volume)
  {
   if(!MathIsValidNumber(quote_profit) || !MathIsValidNumber(realized_cash) ||
      !MathIsValidNumber(remaining_swap) || !MathIsValidNumber(entry_cost_per_volume) ||
      !MathIsValidNumber(remaining_volume) || remaining_volume<0.0)
      return MathArcsin(2.0);
   double closing_cost=MathMax(0.0,entry_cost_per_volume)*remaining_volume;
   double net=quote_profit+realized_cash+remaining_swap-closing_cost;
   if(!MathIsValidNumber(closing_cost) || !MathIsValidNumber(net)) return MathArcsin(2.0);
   return net;
  }

bool W33ArmOppositeExit(W33OppositeExitState &state,
                       const int position_direction,
                       const datetime filled_at,
                       const ulong fill_order_key,
                       const string source_setup_id,
                       const int source_direction,
                       const datetime event_known_at,
                       const ulong event_order_key)
  {
   if(state.armed || filled_at<=0 || fill_order_key==0 || source_setup_id=="") return false;
   if((position_direction!=1 && position_direction!=-1) || source_direction!=-position_direction) return false;
   if(event_known_at<filled_at || event_order_key<=fill_order_key) return false;
   state.armed=true;
   state.request_pending=false;
   state.source_setup_id=source_setup_id;
   state.source_direction=source_direction;
   state.detected_at=event_known_at;
   state.detected_order_key=event_order_key;
   state.requested_at=0;
   state.requested_order_key=0;
   state.attempts=0;
   return true;
  }

bool W33ShouldRequestOppositeExit(const W33OppositeExitState &state,
                                const bool enabled,
                                const bool tester,
                                const bool own_position,
                                const double net_estimate)
  {
   return enabled && tester && own_position && state.armed && !state.request_pending &&
          MathIsValidNumber(net_estimate) && net_estimate>0.0;
  }

bool W33MarkOppositeExitRequested(W33OppositeExitState &state,
                                const datetime at,
                                const ulong order_key)
  {
   if(!state.armed || state.request_pending || at<state.detected_at || order_key<state.detected_order_key) return false;
   state.request_pending=true;
   state.requested_at=at;
   state.requested_order_key=order_key;
   state.attempts++;
   return true;
  }

// Rejection or partial fill leaves the source latched and permits a later
// profitable retry on the residual position. Flat positions reset all state.
// Source invalidation intentionally has no reset function: arming is sticky.
void W33ResolveOppositeExitRequest(W33OppositeExitState &state,
                                  const bool position_still_open)
  {
   if(!position_still_open)
     {
      W33ResetOppositeExit(state);
      return;
     }
   state.request_pending=false;
  }

#endif
