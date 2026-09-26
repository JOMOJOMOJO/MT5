#property strict
#include "../../Include/ThreeWaveFibTickPolicy.mqh"
int checks=0,failures=0;
void Check(bool passed,string name)
{ checks++; if(!passed) failures++; Print(passed ? "PASS " : "FAIL ",name); }
int OnInit()
{
   Check(FibAction(0,true,false,106.18,100,99,103.82,106.18,1,0)==FIB_TOUCH,"upper boundary included");
   Check(FibAction(0,true,false,103.82,100,99,103.82,106.18,1,0)==FIB_TOUCH,"lower boundary included");
   Check(FibAction(0,true,false,106.19,100,99,103.82,106.18,1,0)==FIB_WAIT,"above zone waits");
   Check(FibAction(0,true,false,103.81,100,99,103.82,106.18,1,0)==FIB_WAIT,"gap below zone not fabricated touch");
   Check(FibAction(1,true,false,105,100,99,103.82,106.18,5,5)==FIB_WAIT,"no order on detection event");
   Check(FibAction(1,true,false,105,100,99,103.82,106.18,6,5)==FIB_SEND,"next delivered tick sends");
   Check(FibAction(1,true,false,107,100,99,103.82,106.18,6,5)==FIB_SEND,"next tick may have moved outside zone");
   Check(FibAction(1,true,false,99.9,100,99,103.82,106.18,6,5)==FIB_INVALIDATE,"reversal break cancels pending");
   Check(FibAction(1,true,false,99.9,99,100,103.82,106.18,6,5)==FIB_INVALIDATE,"parent break cancels pending");
   Check(FibAction(1,false,false,105,100,99,103.82,106.18,6,5)==FIB_INVALIDATE,"expired structure cannot send");
   Check(FibAction(0,true,true,105,100,99,103.82,106.18,6,5)==FIB_INVALIDATE,"parent first touch not reused");
   Check(FibAction(2,true,false,105,100,99,103.82,106.18,6,5)==FIB_WAIT,"consumed attempt not retried");
   int f=FileOpen("TW_fib_policy.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(f!=INVALID_HANDLE) { FileWrite(f,"checks","failures"); FileWrite(f,checks,failures); FileClose(f); }
   Print("TW_FIB_POLICY checks=",checks," failures=",failures);
   return failures==0 ? INIT_SUCCEEDED : INIT_FAILED;
}
void OnTick() { TesterStop(); }
