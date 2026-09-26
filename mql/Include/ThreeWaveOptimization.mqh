#ifndef THREE_WAVE_OPTIMIZATION
#define THREE_WAVE_OPTIMIZATION
// Optimize one entry family per batch. Do not change the selected live inputs.
bool TWFixOptimizationLong(const string name)
{
   bool enabled; long value,start,step,stop;
   if(!ParameterGetRange(name,enabled,value,start,step,stop)) return false;
   if(enabled) Print("TW_OPT_FIXED ",name,"=",value," (selected family / inactive input)");
   return ParameterSetRange(name,false,value,start,step,stop);
}
bool TWFixOptimizationDouble(const string name)
{
   bool enabled; double value,start,step,stop;
   if(!ParameterGetRange(name,enabled,value,start,step,stop)) return false;
   if(enabled) Print("TW_OPT_FIXED ",name,"=",value," (inactive input)");
   return ParameterSetRange(name,false,value,start,step,stop);
}
bool TWOptimizationBounds(const string name,long &minimum,long &maximum)
{
   bool enabled; long value,start,step,stop;
   if(!ParameterGetRange(name,enabled,value,start,step,stop)) return false;
   minimum=enabled ? start : value; maximum=enabled ? stop : value;
   return minimum>0 && maximum>=minimum && (!enabled || step>0);
}
void OnTesterDeinit()
{
   Print("TW_OPT_FINISHED");
}
int OnTesterInit()
{
   // ParameterGetRange is the authoritative source of selected tester values.
   bool enabled; long mode,start,step,stop,skip,ema,close_break,fib,verify;
   if(!ParameterGetRange("InpHLEntryMode",enabled,mode,start,step,stop) ||
      !ParameterGetRange("InpSkipLowerHL",enabled,skip,start,step,stop) ||
      !ParameterGetRange("InpUseEMAFilter",enabled,ema,start,step,stop) ||
      !ParameterGetRange("InpRequireCloseBreak",enabled,close_break,start,step,stop) ||
      !ParameterGetRange("InpRequireFibZone",enabled,fib,start,step,stop) ||
      !ParameterGetRange("InpVerifyIndicator",enabled,verify,start,step,stop)) return INIT_FAILED;
   if((mode!=HL_ENTRY_READY && mode!=HL_ENTRY_RETEST) || !close_break || fib ||
      (mode==HL_ENTRY_RETEST && (skip || verify)))
   {
      Print("TW_OPT_ERROR Select READY(0) or RETEST(2), CloseBreak=true, FibZone=false; RETEST requires SkipLowerHL=false and VerifyIndicator=false. Compare families in separate batches.");
      return INIT_PARAMETERS_INCORRECT;
   }
   string fixed[]={"InpHLEntryMode","InpSkipLowerHL","InpUseEMAFilter","InpLowerTF",
                   "InpRequireCloseBreak","InpRequireFibZone","InpVerifyIndicator","InpTestDeferredProtection"};
   for(int i=0;i<ArraySize(fixed);i++) if(!TWFixOptimizationLong(fixed[i])) return INIT_FAILED;
   if(!TWFixOptimizationDouble("InpFibZoneLow") || !TWFixOptimizationDouble("InpFibZoneHigh")) return INIT_FAILED;
   if(mode==HL_ENTRY_READY)
   {
      if(!TWFixOptimizationDouble("InpHLNearFraction")) return INIT_FAILED;
   }
   else
   {
      double value,first,increment,last;
      if(!ParameterGetRange("InpHLNearFraction",enabled,value,first,increment,last)) return INIT_FAILED;
      if(value<=0 || value>1 || (enabled && (first<=0 || increment<=0 || last<first || first>1)))
      { Print("TW_OPT_ERROR HLNearFraction must be in (0,1]"); return INIT_PARAMETERS_INCORRECT; }
      if(enabled && last>1)
      {
         last=first+MathFloor((1.0-first)/increment+1e-9)*increment;
         Print("TW_OPT_CLAMP InpHLNearFraction stop=",last);
         if(!ParameterSetRange("InpHLNearFraction",true,value,first,increment,last)) return INIT_FAILED;
      }
   }
   if(!ema)
   {
      string periods[]={"InpEMAFastPeriod","InpEMAMiddlePeriod","InpEMASlowPeriod","InpEMARequireRising"};
      for(int i=0;i<ArraySize(periods);i++) if(!TWFixOptimizationLong(periods[i])) return INIT_FAILED;
   }
   else
   {
      long fmin,fmax,mmin,mmax,smin,smax;
      if(!TWOptimizationBounds("InpEMAFastPeriod",fmin,fmax) ||
         !TWOptimizationBounds("InpEMAMiddlePeriod",mmin,mmax) ||
         !TWOptimizationBounds("InpEMASlowPeriod",smin,smax) || fmax>=mmin || mmax>=smin || smax>10000)
      { Print("TW_OPT_ERROR Use non-overlapping EMA ranges: fast max < middle min < slow min, slow max <=10000"); return INIT_PARAMETERS_INCORRECT; }
   }
   Print("TW_OPT_READY selected entry family=",mode," skipHL=",skip," EMA=",ema);
   return INIT_SUCCEEDED;
}
#endif
