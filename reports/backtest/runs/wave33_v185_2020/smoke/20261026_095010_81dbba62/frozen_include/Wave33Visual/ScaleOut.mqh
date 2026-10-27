#ifndef WAVE33_VISUAL_SCALE_OUT_MQH
#define WAVE33_VISUAL_SCALE_OUT_MQH

// Pure execution policy. The caller supplies fixed, already-known targets,
// actual fills, symbol specifications and the current executable quote.
// This module never reads a quote/bar/position, submits an order or draws.
struct W33ScaleOutPlan
  {
   bool requested;
   bool valid;
   bool enabled;                   // True only for two distinct price targets.
   bool collapsed;                 // A single full-close target remains.
   double first_tp;
   double final_tp;
   string first_kind;
   string final_kind;
   string reason;
  };

struct W33ScaleOutVolumePlan
  {
   bool valid;
   bool split_allowed;
   bool fallback_to_single;
   bool completed;
   double target_close_volume;      // Floor(0.5 * CONFIRMED initial fill / step).
   double remaining_to_close;       // Target less cumulative confirmed closes.
   double remainder;                // Open volume after that remaining close.
   string reason;
  };

struct W33ScaleOutBEPlan
  {
   bool valid;
   bool can_modify;
   bool already_protected;
   bool favorable_rounding;
   double actual_entry;
   double target_sl;
   double executable_quote;
   double distance_points;
   double required_points;
   string reason;
  };

// Execution state is deliberately not inferred from a target touch or a send
// return code. The manager freezes initial_filled_volume only once its opening
// order is settled, and advances confirmed_closed_volume from unique confirmed
// closing deals belonging to the scale-out request. A partial fill of that
// request does NOT create another half-volume target.
struct W33ScaleOutState
  {
   bool planned;
   bool initial_volume_frozen;
   bool eligible;
   bool single_fallback;
   bool first_target_reached;
   bool request_pending;
   bool break_even_pending;
   bool break_even_done;
   double first_tp;
   double final_tp;
   double initial_filled_volume;
   double target_close_volume;
   double confirmed_closed_volume;
   double pending_request_volume;
   ulong pending_order;
   ulong pending_request_id;
   ulong last_confirmed_deal;        // Informational; caller must deduplicate ALL deals.
   datetime first_reached_at;
   datetime first_confirmed_at;
   int close_attempts;
   int be_attempts;
   string fallback_reason;
  };

void W33ResetScaleOutState(W33ScaleOutState &state)
  {
   ZeroMemory(state);
   state.fallback_reason="";
  }

bool W33ScaleOutValidPrice(const double value)
  {
   return MathIsValidNumber(value) && value>0.0;
  }

// This tolerance repairs only numerical grid noise. The half-tick price
// collapse below is an explicit executable-target resolution rule.
double W33ScaleOutUnitTolerance(const double units)
  {
   return MathMax(1e-9,MathAbs(units)*8.8817841970012523e-16);
  }

W33ScaleOutPlan W33BuildScaleOutPlan(const bool enabled,const int direction,
                                   const double entry,const double base_tp,
                                   const double wave1_inside_target,
                                   const double final_cap,const double tick_size)
  {
   W33ScaleOutPlan result;
   ZeroMemory(result);
   result.requested=enabled;
   result.valid=true;
   result.first_tp=base_tp;
   result.final_tp=base_tp;
   result.first_kind="BASE_RR";
   result.final_kind="BASE_RR";
   result.reason="SCALEOUT_DISABLED";
   // OFF preserves the original target exactly, including its representation.
   if(!enabled) return result;
   result.valid=false;
   if(direction!=1 && direction!=-1)
     { result.reason="SCALEOUT_INVALID_DIRECTION"; return result; }
   if(!W33ScaleOutValidPrice(entry) || !W33ScaleOutValidPrice(base_tp) ||
      direction*(base_tp-entry)<=0.0)
     { result.reason="SCALEOUT_INVALID_BASE_TARGET"; return result; }
   if(!W33ScaleOutValidPrice(tick_size))
     { result.reason="SCALEOUT_INVALID_TICK_SIZE"; return result; }
   if(!MathIsValidNumber(final_cap) || final_cap<0.0 ||
      (final_cap>0.0 && direction*(final_cap-entry)<=0.0))
     { result.reason="SCALEOUT_INVALID_CAP"; return result; }
   if(!MathIsValidNumber(base_tp-entry) ||
      (final_cap>0.0 && !MathIsValidNumber(final_cap-entry)))
     { result.reason="SCALEOUT_INVALID_ARITHMETIC"; return result; }

   result.valid=true;
   result.collapsed=true;
   result.reason="SCALEOUT_W1_TARGET_UNAVAILABLE";
   if(W33ScaleOutValidPrice(wave1_inside_target) &&
      direction*(wave1_inside_target-entry)>0.0)
     {
      double separation=direction*(wave1_inside_target-base_tp);
      if(!MathIsValidNumber(separation) || !MathIsValidNumber(wave1_inside_target-entry))
        {
         result.valid=false;
         result.reason="SCALEOUT_INVALID_ARITHMETIC";
         return result;
        }
      if(separation>tick_size*0.5)
        {
         result.first_tp=base_tp;
         result.final_tp=wave1_inside_target;
         result.first_kind="BASE_RR";
         result.final_kind="WAVE1_INSIDE";
         result.enabled=true;
         result.collapsed=false;
         result.reason="SCALEOUT_BASE_FIRST";
        }
      else if(separation<-tick_size*0.5)
        {
         result.first_tp=wave1_inside_target;
         result.final_tp=base_tp;
         result.first_kind="WAVE1_INSIDE";
         result.final_kind="BASE_RR";
         result.enabled=true;
         result.collapsed=false;
         result.reason="SCALEOUT_W1_FIRST";
        }
      else
        {
         // A pair of unresolvable prices must not be two execution events.
         // Keep the nearer price and close the whole volume there.
         result.first_tp=(separation<0.0 ? wave1_inside_target : base_tp);
         result.final_tp=result.first_tp;
         result.first_kind="BASE_RR_AND_WAVE1_INSIDE";
         result.final_kind=result.first_kind;
         result.reason="SCALEOUT_TARGETS_COLLAPSED";
        }
     }

   // An explicit obstacle cap has priority over the far target. If it lies at
   // or before the first target, the setup has one full-close target at the cap.
   if(final_cap>0.0 && direction*(final_cap-result.final_tp)<0.0)
     {
      result.final_tp=final_cap;
      result.final_kind="OBSTACLE_CAP";
      if(direction*(result.final_tp-result.first_tp)<=tick_size*0.5)
        {
         result.first_tp=result.final_tp;
         result.first_kind="OBSTACLE_CAP";
         result.enabled=false;
         result.collapsed=true;
         result.reason="SCALEOUT_CAP_COLLAPSED";
        }
      else result.reason="SCALEOUT_FINAL_CAPPED";
     }
   return result;
  }

// Volume units must be representable on the broker step. Never round a close
// volume up to obtain a nominal 50%, and never increase the initial position.
bool W33ScaleOutVolumeUnits(const double volume,const double step,double &units)
  {
   if(!MathIsValidNumber(volume) || volume<0.0 || !W33ScaleOutValidPrice(step)) return false;
   double raw=volume/step;
   if(!MathIsValidNumber(raw) || MathAbs(raw)>1e14) return false;
   units=MathRound(raw);
   return MathAbs(raw-units)<=W33ScaleOutUnitTolerance(raw);
  }

W33ScaleOutVolumePlan W33BuildScaleOutVolumePlan(const double initial_filled_volume,
                                               const double current_volume,
                                               const double min_volume,
                                               const double volume_step,
                                               const double cumulative_confirmed_closed,
                                               const bool broker_supported=true)
  {
   W33ScaleOutVolumePlan result;
   ZeroMemory(result);
   result.fallback_to_single=true;
   result.reason="SCALEOUT_INVALID_VOLUME_SPEC";
   if(!W33ScaleOutValidPrice(initial_filled_volume) ||
      !MathIsValidNumber(current_volume) || current_volume<0.0 ||
      !W33ScaleOutValidPrice(min_volume) || !W33ScaleOutValidPrice(volume_step) ||
      !MathIsValidNumber(cumulative_confirmed_closed) || cumulative_confirmed_closed<0.0)
      return result;
   double initial_units=0,current_units=0,closed_units=0;
   if(!W33ScaleOutVolumeUnits(initial_filled_volume,volume_step,initial_units) ||
      !W33ScaleOutVolumeUnits(current_volume,volume_step,current_units) ||
      !W33ScaleOutVolumeUnits(cumulative_confirmed_closed,volume_step,closed_units))
     { result.reason="SCALEOUT_VOLUME_OFF_STEP"; return result; }
   if(current_units>initial_units || closed_units>initial_units)
     { result.reason="SCALEOUT_VOLUME_EXCEEDS_INITIAL"; return result; }
   double min_raw=min_volume/volume_step;
   if(!MathIsValidNumber(min_raw) || min_raw>1e14) return result;
   double min_nearest=MathRound(min_raw);
   if(MathAbs(min_raw-min_nearest)<=W33ScaleOutUnitTolerance(min_raw)) min_raw=min_nearest;
   double minimum_units=MathCeil(min_raw);
   double target_units=MathFloor(initial_units*0.5);
   result.target_close_volume=target_units*volume_step;
   result.remainder=current_volume;
   result.valid=true;
   if(!broker_supported)
     { result.reason="SCALEOUT_PARTIAL_UNSUPPORTED"; return result; }
   if(target_units<minimum_units || initial_units-target_units<minimum_units)
     { result.reason="SCALEOUT_MIN_VOLUME_FALLBACK"; return result; }
   if(closed_units>=target_units)
     {
      result.split_allowed=true;
      result.fallback_to_single=false;
      result.completed=true;
      result.reason="SCALEOUT_TARGET_ALREADY_CONFIRMED";
      return result;
     }
   double remaining_units=target_units-closed_units;
   if(remaining_units<minimum_units || current_units-remaining_units<minimum_units)
     { result.reason="SCALEOUT_RESIDUAL_VOLUME_FALLBACK"; return result; }
   result.remaining_to_close=remaining_units*volume_step;
   result.remainder=(current_units-remaining_units)*volume_step;
   result.split_allowed=true;
   result.fallback_to_single=false;
   result.reason="SCALEOUT_HALF_VOLUME_READY";
   return result;
  }

// A LONG closes against BID; a SHORT closes against ASK. A candle high/low or
// the opposite side of the spread cannot by itself trigger a partial close.
bool W33ScaleOutPriceReached(const int direction,const double bid,
                            const double ask,const double target)
  {
   if((direction!=1 && direction!=-1) || !W33ScaleOutValidPrice(bid) ||
      !W33ScaleOutValidPrice(ask) || ask<bid || !W33ScaleOutValidPrice(target)) return false;
   return direction*((direction>0 ? bid : ask)-target)>=0.0;
  }

W33ScaleOutBEPlan W33BuildScaleOutBEPlan(const int direction,const double actual_entry,
                                       const double existing_sl,const double bid,
                                       const double ask,const double point,
                                       const double tick_size,const int digits,
                                       const double stops_points,const double freeze_points)
  {
   W33ScaleOutBEPlan result;
   ZeroMemory(result);
   result.actual_entry=actual_entry;
   result.target_sl=actual_entry;
   result.reason="SCALEOUT_BE_INVALID_INPUT";
   if((direction!=1 && direction!=-1) || !W33ScaleOutValidPrice(actual_entry) ||
      !MathIsValidNumber(existing_sl) || existing_sl<0.0 ||
      !W33ScaleOutValidPrice(bid) || !W33ScaleOutValidPrice(ask) || ask<bid ||
      !W33ScaleOutValidPrice(point) || !W33ScaleOutValidPrice(tick_size) ||
      digits<0 || digits>8 || !MathIsValidNumber(stops_points) || stops_points<0.0 ||
      !MathIsValidNumber(freeze_points) || freeze_points<0.0) return result;
   if(MathAbs(NormalizeDouble(tick_size,digits)-tick_size)>tick_size*1e-8)
     { result.reason="SCALEOUT_BE_INVALID_TICK_PRECISION"; return result; }
   double units=actual_entry/tick_size;
   if(!MathIsValidNumber(units) || MathAbs(units)>1e14)
     { result.reason="SCALEOUT_BE_INVALID_TICK_RESOLUTION"; return result; }
   double nearest=MathRound(units);
   bool on_grid=(MathAbs(units-nearest)<=W33ScaleOutUnitTolerance(units));
   if(on_grid) result.target_sl=NormalizeDouble(nearest*tick_size,digits);
   else
     {
      // Weighted partial fills can have an off-grid average entry. Select the
      // first executable tick on the favorable side, at most one tick away.
      result.target_sl=NormalizeDouble((direction>0 ? MathCeil(units) : MathFloor(units))*tick_size,digits);
      result.favorable_rounding=true;
     }
   double epsilon=tick_size*1e-8;
   if(!W33ScaleOutValidPrice(result.target_sl) ||
      direction*(result.target_sl-actual_entry)<-epsilon ||
      MathAbs(result.target_sl-actual_entry)>tick_size+epsilon)
     { result.reason="SCALEOUT_BE_INVALID_GRID_TARGET"; return result; }
   result.valid=true;
   result.executable_quote=(direction>0 ? bid : ask);
   result.distance_points=direction*(result.executable_quote-result.target_sl)/point;
   result.required_points=MathMax(stops_points,freeze_points);
   if(!MathIsValidNumber(result.distance_points) ||
      !MathIsValidNumber(stops_points*point) || !MathIsValidNumber(freeze_points*point))
     {
      result.valid=false;
      result.reason="SCALEOUT_BE_INVALID_ARITHMETIC";
      return result;
     }
   if(existing_sl>0.0 && direction*(existing_sl-result.target_sl)>=-epsilon)
     {
      result.already_protected=true;
      result.reason="SCALEOUT_BE_ALREADY_PROTECTED";
      return result;
     }
   double distance=direction*(result.executable_quote-result.target_sl);
   if(distance<=0.0 || distance+epsilon<stops_points*point)
     { result.reason="SCALEOUT_BE_STOPS_LEVEL"; return result; }
   // The freeze boundary is excluded conservatively: do not keep issuing
   // modifications exactly at a broker's frozen-distance boundary.
   if(freeze_points>0.0 && distance<=freeze_points*point+epsilon)
     { result.reason="SCALEOUT_BE_FREEZE_LEVEL"; return result; }
   result.can_modify=true;
   result.reason=(result.favorable_rounding ? "SCALEOUT_BE_FAVORABLE_TICK_ROUNDING" : "SCALEOUT_BE_READY");
   return result;
  }

#endif
