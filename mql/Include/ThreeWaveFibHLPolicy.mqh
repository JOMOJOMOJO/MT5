#ifndef THREE_WAVE_FIB_HL_POLICY
#define THREE_WAVE_FIB_HL_POLICY
bool FibCloseInside(double close,double low,double high,double shallow,double deep)
{
   if(high<=low) return false;
   return close>=high-(high-low)*deep-1e-10 && close<=high-(high-low)*shallow+1e-10;
}
bool HLTighteningValid(double entry,double old_sl,double new_sl)
{ return new_sl>old_sl && new_sl<entry; }
double HLTarget(double entry,double sl,double rr)
{ return entry+(entry-sl)*rr; }
#endif
