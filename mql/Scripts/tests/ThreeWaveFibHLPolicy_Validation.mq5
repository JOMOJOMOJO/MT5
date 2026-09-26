#property strict
#include "../../Include/ThreeWaveFibHLPolicy.mqh"
int checks=0,failures=0;
void Check(bool ok,string label) { checks++; if(!ok) failures++; Print(ok ? "PASS " : "FAIL ",label); }
int OnInit()
{
   Check(FibCloseInside(105,100,110,.5,.618),"50 percent boundary");
   Check(FibCloseInside(103.82,100,110,.5,.618),"61.8 percent boundary");
   Check(FibCloseInside(104,100,110,.5,.618),"inside close");
   Check(!FibCloseInside(105.001,100,110,.5,.618),"shallow close excluded");
   Check(!FibCloseInside(103.819,100,110,.5,.618),"deep close excluded");
   Check(!FibCloseInside(100,110,100,.5,.618),"inverted range excluded");
   Check(HLTighteningValid(105,99.99,102.99),"tighten to HL minus buffer");
   Check(!HLTighteningValid(105,99.99,99.98),"never widen SL");
   Check(!HLTighteningValid(105,99.99,99.99),"equal SL not a new target");
   Check(!HLTighteningValid(105,99.99,105),"zero risk TP undefined");
   Check(!HLTighteningValid(105,99.99,106),"SL above entry not used for RR recomputation");
   Check(MathAbs(HLTarget(105,103,1.2)-107.4)<1e-9,"TP uses fill and new risk");
   int f=FileOpen("TW_fib_hl_policy.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(f!=INVALID_HANDLE) { FileWrite(f,"checks","failures"); FileWrite(f,checks,failures); FileClose(f); }
   return failures==0 ? INIT_SUCCEEDED : INIT_FAILED;
}
void OnTick() { TesterStop(); }
