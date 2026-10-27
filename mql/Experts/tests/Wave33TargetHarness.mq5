#property strict
#property version "1.00"
#include "../../Include/Wave33Visual/Wave1Target.mqh"

input string InpRunTag="target_harness";
int g_file=INVALID_HANDLE,g_pass=0,g_fail=0;

void Check(const string name,const bool ok,const string detail)
  {
   if(ok) g_pass++; else g_fail++;
   FileWrite(g_file,name,ok ? "PASS" : "FAIL",detail);
  }

bool Near(const double value,const double expected,const double tolerance=1e-9)
  { return MathAbs(value-expected)<=tolerance; }

void TestLongAndShort()
  {
   W33Wave1TargetResult r=W33ExtendTargetToWave1(true,1,100,101,true,102,0.01,0.01,2,2,10);
   Check("long_rr_target_extended",r.applied && Near(r.final_tp,101.90) && r.reason=="TP_W1_EXTENDED",
         "A long target below fixed W1 extends to ten points before its high");
   Check("long_endpoint_buffer_logged",Near(r.desired_target,101.90) && Near(r.minimum_buffer_points,10) && Near(r.effective_buffer_points,10),
         "The requested executable target and actual margin are explicit");
   r=W33ExtendTargetToWave1(true,-1,100,99,true,98,0.01,0.01,2,2,10);
   Check("short_rr_target_extended",r.applied && Near(r.final_tp,98.10) && r.reason=="TP_W1_EXTENDED",
         "The short target uses the symmetric low plus buffer");
   Check("short_endpoint_buffer_logged",Near(r.desired_target,98.10) && Near(r.effective_buffer_points,10),
         "Short margin remains positive and points toward the inside of W1");
   r=W33ExtendTargetToWave1(true,1,100,102.20,true,102,0.01,0.01,2,2,10);
   Check("long_beyond_endpoint_never_shortened",!r.applied && r.final_tp==102.20 && r.reason=="TP_W1_ALREADY_REACHES_ENDPOINT",
         "A pre-existing larger RR target is retained");
   r=W33ExtendTargetToWave1(true,-1,100,97.80,true,98,0.01,0.01,2,2,10);
   Check("short_beyond_endpoint_never_shortened",!r.applied && r.final_tp==97.80 && r.reason=="TP_W1_ALREADY_REACHES_ENDPOINT",
         "A pre-existing lower short RR target is retained");
   r=W33ExtendTargetToWave1(true,1,100,102,true,102,0.01,0.01,2,2,10);
   Check("long_exact_endpoint_retained",!r.applied && r.final_tp==102,"A target exactly at W1 is unchanged");
   r=W33ExtendTargetToWave1(true,-1,100,98,true,98,0.01,0.01,2,2,10);
   Check("short_exact_endpoint_retained",!r.applied && r.final_tp==98,"A target exactly at short W1 is unchanged");
   r=W33ExtendTargetToWave1(true,1,100,101.95,true,102,0.01,0.01,2,2,10);
   Check("long_target_within_buffer_not_shortened",!r.applied && r.final_tp==101.95 && r.reason=="TP_W1_TARGET_NOT_FARTHER",
         "A base TP already closer to W1 than the buffer is never pulled back");
   r=W33ExtendTargetToWave1(true,-1,100,98.05,true,98,0.01,0.01,2,2,10);
   Check("short_target_within_buffer_not_shortened",!r.applied && r.final_tp==98.05 && r.reason=="TP_W1_TARGET_NOT_FARTHER",
         "The no-shortening guarantee is symmetric");
   r=W33ExtendTargetToWave1(true,1,100,101.90,true,102,0.01,0.01,2,2,10);
   Check("same_target_not_reported_as_extension",!r.applied && r.final_tp==101.90,"An unchanged exact target does not emit an applied flag");
  }

void TestSymbolGridsAndBuffers()
  {
   W33Wave1TargetResult r=W33ExtendTargetToWave1(true,1,111.000,111.200,true,111.500,0.001,0.001,3,2,10);
   Check("three_digit_point_buffer",r.applied && Near(r.final_tp,111.490),"Ten 0.001 points means a 0.010 price margin");
   r=W33ExtendTargetToWave1(true,-1,111.500,111.300,true,111.000,0.001,0.001,3,2,10);
   Check("three_digit_short_point_buffer",r.applied && Near(r.final_tp,111.010),"Short JPY-style prices retain their three-digit grid");
   r=W33ExtendTargetToWave1(true,1,100,101,true,102.037,0.01,0.05,2,1,10);
   Check("long_non_tick_peak_rounds_down",r.applied && Near(r.final_tp,101.90) && Near(r.effective_buffer_points,13.7),
         "A non-tick endpoint rounds the long target farther inside the endpoint");
   r=W33ExtendTargetToWave1(true,-1,104,103,true,102.037,0.01,0.05,2,1,10);
   Check("short_non_tick_peak_rounds_up",r.applied && Near(r.final_tp,102.15) && Near(r.effective_buffer_points,11.3),
         "A non-tick endpoint rounds the short target upward");
   r=W33ExtendTargetToWave1(true,1,100,101,true,102.10,0.01,0.10,2,1,10);
   Check("long_exact_tick_boundary",r.applied && Near(r.final_tp,102.00),"Floating arithmetic does not lose a tick at an exact boundary");
   r=W33ExtendTargetToWave1(true,-1,104,103,true,102.10,0.01,0.10,2,1,10);
   Check("short_exact_tick_boundary",r.applied && Near(r.final_tp,102.20),"Floating arithmetic does not add a tick at an exact boundary");
   r=W33ExtendTargetToWave1(true,1,100,101,true,102,0.01,0.01,2,30,10);
   Check("spread_overrides_extra_long",r.applied && Near(r.final_tp,101.70) && Near(r.minimum_buffer_points,30),
         "A thirty-point spread dominates the ten-point extra input");
   r=W33ExtendTargetToWave1(true,-1,100,99,true,98,0.01,0.01,2,30,10);
   Check("spread_overrides_extra_short",r.applied && Near(r.final_tp,98.30),"The executable margin is symmetric with wide spreads");
   r=W33ExtendTargetToWave1(true,1,100,101,true,102,0.01,0.25,2,0,0);
   Check("one_tick_minimum_even_zero_inputs",r.applied && Near(r.final_tp,101.75) && Near(r.minimum_buffer_points,25),
         "Zero extra and spread still leave at least one executable tick before W1");
   r=W33ExtendTargetToWave1(true,-1,100,99,true,98,0.01,0.25,2,0,0);
   Check("one_tick_short_minimum",r.applied && Near(r.final_tp,98.25),"Minimum-tick margin applies to short targets too");
   r=W33ExtendTargetToWave1(true,1,1.08000,1.08100,true,1.08200,0.00001,0.00001,5,12,10);
   Check("five_digit_forex_grid",r.applied && Near(r.final_tp,1.08188),"Spread points retain five-digit FX precision");
   r=W33ExtendTargetToWave1(true,1,100,101,true,104,1.0,1.0,0,0,1);
   Check("zero_digit_grid",r.applied && r.final_tp==103,"Whole-number symbols remain supported");
   r=W33ExtendTargetToWave1(true,1,0.00000100,0.00000110,true,0.00000150,0.00000001,0.00000001,8,1,2);
   Check("eight_digit_grid",r.applied && Near(r.final_tp,0.00000148,1e-14),"Eight decimal places use an executable target");
  }

void TestInvalidAndLegacy()
  {
   const double original=101.123456789;
   W33Wave1TargetResult r=W33ExtendTargetToWave1(false,0,0,original,false,0,0,0,-1,-1,-1);
   Check("off_preserves_exact_old_target",!r.applied && r.final_tp==original && r.reason=="TP_W1_EXTENSION_DISABLED",
         "OFF returns the exact base TP even when unused new inputs are invalid");
   r=W33ExtendTargetToWave1(true,1,100,101,false,102,0.01,0.01,2,2,10);
   Check("unfixed_peak_cannot_extend",!r.applied && r.final_tp==101 && r.reason=="TP_W1_PEAK_NOT_FIXED",
         "A provisional future endpoint cannot alter the target");
   r=W33ExtendTargetToWave1(true,0,100,101,true,102,0.01,0.01,2,2,10);
   Check("zero_direction_rejected",!r.applied && r.reason=="TP_W1_INVALID_DIRECTION","Direction must be exactly +1 or -1");
   r=W33ExtendTargetToWave1(true,2,100,101,true,102,0.01,0.01,2,2,10);
   Check("other_direction_rejected",!r.applied && r.reason=="TP_W1_INVALID_DIRECTION","An arbitrary positive integer is not treated as LONG");
   r=W33ExtendTargetToWave1(true,1,0,101,true,102,0.01,0.01,2,2,10);
   Check("zero_entry_rejected",!r.applied && r.reason=="TP_W1_INVALID_PRICE","No order target is invented without a positive entry");
   r=W33ExtendTargetToWave1(true,1,100,0,true,102,0.01,0.01,2,2,10);
   Check("zero_base_tp_rejected",!r.applied && r.final_tp==0 && r.reason=="TP_W1_INVALID_PRICE","A missing original target is not repaired silently");
   r=W33ExtendTargetToWave1(true,1,100,101,true,0,0.01,0.01,2,2,10);
   Check("zero_peak_rejected",!r.applied && r.reason=="TP_W1_INVALID_PRICE","A zero fixed endpoint cannot be used");
   r=W33ExtendTargetToWave1(true,1,100,101,true,102,0,0.01,2,2,10);
   Check("zero_point_rejected",!r.applied && r.reason=="TP_W1_INVALID_POINT","Point conversion never divides by zero");
   r=W33ExtendTargetToWave1(true,1,100,101,true,102,0.01,0,2,2,10);
   Check("zero_tick_rejected",!r.applied && r.reason=="TP_W1_INVALID_TICK_SIZE","No unverified substitute tick grid is introduced");
   r=W33ExtendTargetToWave1(true,1,100,101,true,102,0.01,0.01,9,2,10);
   Check("invalid_digits_rejected",!r.applied && r.reason=="TP_W1_INVALID_DIGITS","NormalizeDouble supports zero through eight digits");
   r=W33ExtendTargetToWave1(true,1,100,101,true,102,0.01,0.005,2,2,10);
   Check("unrepresentable_tick_precision_rejected",!r.applied && r.reason=="TP_W1_INVALID_TICK_PRECISION",
         "Digits cannot represent a half-cent tick, so the old TP remains unchanged");
   r=W33ExtendTargetToWave1(true,1,100,101,true,102,0.01,0.01,2,-1,10);
   Check("negative_spread_rejected",!r.applied && r.reason=="TP_W1_INVALID_BUFFER","A bad spread is recorded instead of reducing the buffer");
   r=W33ExtendTargetToWave1(true,1,100,101,true,102,0.01,0.01,2,2,-1);
   Check("negative_extra_rejected",!r.applied && r.reason=="TP_W1_INVALID_BUFFER","A negative configured buffer does not alter the target");
   r=W33ExtendTargetToWave1(true,1,100,99,true,102,0.01,0.01,2,2,10);
   Check("long_nonprofit_base_rejected",!r.applied && r.reason=="TP_W1_INVALID_BASE_DIRECTION","The helper cannot turn an invalid base into a valid order");
   r=W33ExtendTargetToWave1(true,-1,100,101,true,98,0.01,0.01,2,2,10);
   Check("short_nonprofit_base_rejected",!r.applied && r.reason=="TP_W1_INVALID_BASE_DIRECTION","Short base TP must already be below entry");
   r=W33ExtendTargetToWave1(true,1,100,100.10,true,100.20,0.01,0.01,2,50,10);
   Check("long_large_margin_crossing_entry_rejected",!r.applied && r.final_tp==100.10 && r.reason=="TP_W1_TARGET_NOT_PROFITABLE",
         "A large spread cannot drag a profit target across entry");
   r=W33ExtendTargetToWave1(true,-1,100,99.90,true,99.80,0.01,0.01,2,50,10);
   Check("short_large_margin_crossing_entry_rejected",!r.applied && r.final_tp==99.90 && r.reason=="TP_W1_TARGET_NOT_PROFITABLE",
         "Short crossing-entry margins preserve the original target");
   double invalid=MathSqrt(-1.0);
   r=W33ExtendTargetToWave1(true,1,invalid,101,true,102,0.01,0.01,2,2,10);
   Check("nonfinite_price_rejected",!r.applied && r.reason=="TP_W1_INVALID_PRICE","NaN input cannot reach tick rounding");
   r=W33ExtendTargetToWave1(true,1,100,101,true,102,0.01,0.01,2,invalid,10);
   Check("nonfinite_buffer_rejected",!r.applied && r.reason=="TP_W1_INVALID_BUFFER","NaN spread cannot produce a desired target");
   r=W33ExtendTargetToWave1(true,1,100,101,true,102,invalid,0.01,2,2,10);
   Check("nonfinite_point_rejected",!r.applied && r.reason=="TP_W1_INVALID_POINT","A nonfinite point is rejected before conversion");
   r=W33ExtendTargetToWave1(true,1,100,101,true,102,0.01,invalid,2,2,10);
   Check("nonfinite_tick_rejected",!r.applied && r.reason=="TP_W1_INVALID_TICK_SIZE","A nonfinite tick is rejected before division");
  }

int OnInit()
  {
   g_file=FileOpen("W33Harness_"+InpRunTag+".csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(g_file==INVALID_HANDLE) return INIT_FAILED;
   FileWrite(g_file,"test","passed","detail");
   TestLongAndShort(); TestSymbolGridsAndBuffers(); TestInvalidAndLegacy();
   // CAP_TP, broker stop limits and final actual-R recomputation are integration
   // responsibilities: run a native fixture after this helper is applied and
   // verify CAP_TP still wins. This harness never claims that policy coverage.
   FileWrite(g_file,"FINAL",g_fail==0 ? "PASS" : "FAIL",StringFormat("passed=%d failed=%d",g_pass,g_fail));
   FileFlush(g_file); FileClose(g_file); g_file=INVALID_HANDLE;
   PrintFormat("W33_TARGET_HARNESS_FINAL passed=%d failed=%d",g_pass,g_fail);
   return INIT_SUCCEEDED;
  }
void OnTick() { if(MQLInfoInteger(MQL_TESTER)) TesterStop(); }
double OnTester() { return g_fail==0 ? 1.0 : 0.0; }
