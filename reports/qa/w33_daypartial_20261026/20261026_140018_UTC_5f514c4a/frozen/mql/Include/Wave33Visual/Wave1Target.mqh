#ifndef WAVE33_WAVE1_TARGET_MQH
#define WAVE33_WAVE1_TARGET_MQH

// Pure target policy. No quotes, candles, objects, orders or setup state are read
// here. The caller supplies only the fixed endpoint that it knows at signal time.
// A later obstacle CAP_TP policy may shorten final_tp after this calculation.
struct W33Wave1TargetResult
  {
   double final_tp;                // base_tp is preserved exactly unless applied.
   double desired_target;          // Executable tick inside the fixed W1 endpoint.
   double minimum_buffer_points;   // max(extra, spread, one tick), before rounding.
   double effective_buffer_points; // Actual endpoint-to-target margin after rounding.
   bool applied;
   string reason;
  };

W33Wave1TargetResult W33ExtendTargetToWave1(const bool enabled,const int direction,
                                          const double entry,const double base_tp,
                                          const bool wave1_peak_fixed,const double wave1_peak,
                                          const double point,const double tick_size,const int digits,
                                          const double spread_points,const double extra_buffer_points)
  {
   W33Wave1TargetResult result;
   ZeroMemory(result);
   result.final_tp=base_tp;
   result.reason="TP_W1_EXTENSION_DISABLED";
   // In particular, OFF never normalizes an old RR target or changes its bits.
   if(!enabled) return result;
   if(direction!=1 && direction!=-1)
     { result.reason="TP_W1_INVALID_DIRECTION"; return result; }
   if(!wave1_peak_fixed)
     { result.reason="TP_W1_PEAK_NOT_FIXED"; return result; }
   if(!MathIsValidNumber(entry) || !MathIsValidNumber(base_tp) || !MathIsValidNumber(wave1_peak) ||
      entry<=0 || base_tp<=0 || wave1_peak<=0)
     { result.reason="TP_W1_INVALID_PRICE"; return result; }
   if(!MathIsValidNumber(point) || point<=0)
     { result.reason="TP_W1_INVALID_POINT"; return result; }
   if(!MathIsValidNumber(tick_size) || tick_size<=0)
     { result.reason="TP_W1_INVALID_TICK_SIZE"; return result; }
   if(digits<0 || digits>8)
     { result.reason="TP_W1_INVALID_DIGITS"; return result; }
   if(!MathIsValidNumber(spread_points) || !MathIsValidNumber(extra_buffer_points) ||
      spread_points<0 || extra_buffer_points<0)
     { result.reason="TP_W1_INVALID_BUFFER"; return result; }
   if(MathAbs(NormalizeDouble(tick_size,digits)-tick_size)>tick_size*1e-8)
     { result.reason="TP_W1_INVALID_TICK_PRECISION"; return result; }
   if(direction*(base_tp-entry)<=0)
     { result.reason="TP_W1_INVALID_BASE_DIRECTION"; return result; }

   double buffer=MathMax(MathMax(extra_buffer_points*point,spread_points*point),tick_size);
   double raw_target=wave1_peak-direction*buffer;
   if(!MathIsValidNumber(buffer) || !MathIsValidNumber(raw_target))
     { result.reason="TP_W1_INVALID_ARITHMETIC"; return result; }
   result.minimum_buffer_points=buffer/point;
   if(!MathIsValidNumber(result.minimum_buffer_points))
     { result.reason="TP_W1_INVALID_ARITHMETIC"; return result; }
   if(raw_target<=0 || direction*(raw_target-entry)<=0)
     { result.reason="TP_W1_TARGET_NOT_PROFITABLE"; return result; }

   double units=raw_target/tick_size;
   // Reject unresolvable tick grids instead of inventing a price. At ordinary
   // grids the tolerance only repairs floating error at an exact tick boundary.
   if(!MathIsValidNumber(units) || MathAbs(units)>1e14)
     { result.reason="TP_W1_INVALID_TICK_RESOLUTION"; return result; }
   double nearest=MathRound(units);
   double epsilon_units=MathMax(1e-9,MathAbs(units)*8.8817841970012523e-16);
   if(MathAbs(units-nearest)<=epsilon_units) units=nearest;
   double candidate=NormalizeDouble((direction>0 ? MathFloor(units) : MathCeil(units))*tick_size,digits);
   if(!MathIsValidNumber(candidate) || candidate<=0 || direction*(candidate-entry)<=0)
     { result.reason="TP_W1_TARGET_NOT_PROFITABLE"; return result; }
   result.desired_target=candidate;
   result.effective_buffer_points=direction*(wave1_peak-candidate)/point;
   if(!MathIsValidNumber(result.effective_buffer_points))
     { result.reason="TP_W1_INVALID_ARITHMETIC"; return result; }
   if(direction*(base_tp-wave1_peak)>=0)
     { result.reason="TP_W1_ALREADY_REACHES_ENDPOINT"; return result; }
   if(direction*(candidate-base_tp)<=tick_size*1e-9)
     { result.reason="TP_W1_TARGET_NOT_FARTHER"; return result; }
   result.final_tp=candidate;
   result.applied=true;
   result.reason="TP_W1_EXTENDED";
   return result;
  }

#endif
