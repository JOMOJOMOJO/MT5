#property strict
#include "../../Include/ThreeWaveHLTickPolicy.mqh"
int checks=0,failures=0;
void Check(bool ok,string label) { checks++; if(!ok) failures++; Print(ok ? "PASS " : "FAIL ",label); }
int OnInit()
{
   Check(HLAction(false,true,false,105,105.5,105,100,99,106,false)==HL_DECIDE,"Ask inside retest band");
   Check(HLAction(false,true,false,105,106,105,100,99,106,false)==HL_DECIDE,"upper boundary included");
   Check(HLAction(false,true,false,105,105,105,100,99,106,false)==HL_DECIDE,"HL equality allowed");
   Check(HLAction(false,true,false,105,106.01,105,100,99,106,false)==HL_WAIT,"spread moves Ask outside band");
   Check(HLAction(false,true,false,107,108,105,100,99,106,false)==HL_WAIT,"do not chase above band");
   Check(HLAction(false,true,false,107,108,105,100,99,106,true)==HL_DECIDE,"immediate mode does not need retest");
   Check(HLAction(false,true,false,104.99,105.01,105,100,99,106,false)==HL_INVALIDATE,"Bid HL break wins over Ask proximity");
   Check(HLAction(false,false,false,105,105.5,105,100,99,106,false)==HL_INVALIDATE,"expired structure cannot enter");
   Check(HLAction(false,true,true,105,105.5,105,100,99,106,false)==HL_INVALIDATE,"one parent decision");
   Check(HLAction(true,true,false,105,105.5,105,100,99,106,false)==HL_WAIT,"no retry of consumed attempt");
   Check(HLAction(false,true,false,105,105.5,104,106,99,106,false)==HL_INVALIDATE,"reversal origin check");
   Check(HLAction(false,true,false,105,105.5,104,100,106,106,false)==HL_INVALIDATE,"parent origin check");
   int f=FileOpen("TW_hl_policy.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(f!=INVALID_HANDLE) { FileWrite(f,"checks","failures"); FileWrite(f,checks,failures); FileClose(f); }
   return failures==0 ? INIT_SUCCEEDED : INIT_FAILED;
}
void OnTick() { TesterStop(); }
