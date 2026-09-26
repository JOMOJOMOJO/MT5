#property strict
#property version "1.00"
#include "../../Include/ThreeWaveInputs.mqh"
#include "../../Include/ThreeWaveHLRecognitionPolicy.mqh"
int checks=0,failures=0;
void Check(bool ok,string name) { checks++; if(!ok) { failures++; Print("FAIL ",name); } }
int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER)) return INIT_FAILED;
   MqlRates r[]; ArrayResize(r,7);
   for(int i=0;i<7;i++) { ZeroMemory(r[i]); r[i].time=D'2025.01.02 00:00'+i*60; r[i].high=112; r[i].low=105; r[i].close=109; }
   r[1].low=104; r[1].high=115; r[3].low=103; r[3].high=111;
   r[4].low=101; r[4].high=113; r[5].low=102; r[6].low=99;
   M1Pattern p={}; p.found_wave1_high=true; p.wave1_high.bar_time=r[1].time;
   p.wave1_high.confirmed_time=r[3].time+60; p.reversal_low.price=100;
   int candidate=-1,emitted=-1; datetime key=0; PivotPoint hl={}; double threshold=0;
   Check(!ResearchHL(HL_RIGHT_ONE,r,4,p,candidate,emitted,key,hl,threshold),"right1 not yet confirmed");
   Check(ResearchHL(HL_RIGHT_ONE,r,5,p,candidate,emitted,key,hl,threshold),"right1 valid despite forming lower low");
   Check(hl.bar_time==r[4].time && hl.confirmed_time==r[5].time+60,"right1 bar versus knowledge time");
   r[5].low=101;
   Check(ResearchHL(HL_RIGHT_ONE,r,5,p,candidate,emitted,key,hl,threshold),"preserve Shared right equality");
   r[3].low=101;
   Check(!ResearchHL(HL_RIGHT_ONE,r,5,p,candidate,emitted,key,hl,threshold),"reject left equality");
   r[3].low=103; r[5].low=102;
   p.reversal_low.price=101;
   Check(!ResearchHL(HL_RIGHT_ONE,r,5,p,candidate,emitted,key,hl,threshold),"require higher than origin");
   p.reversal_low.price=100;
   Check(!ResearchHL(HL_PRICE_REVERSAL,r,2,p,candidate,emitted,key,hl,threshold),"Wave1 knowledge gate");
   Check(!ResearchHL(HL_PRICE_REVERSAL,r,3,p,candidate,emitted,key,hl,threshold),"no threshold break");
   r[4].close=112;
   Check(ResearchHL(HL_PRICE_REVERSAL,r,4,p,candidate,emitted,key,hl,threshold),"new lower candidate same-bar reversal");
   Check(hl.bar_time==r[4].time && hl.confirmed_time==r[4].time+60 && threshold==111,"one-minute recognition and frozen previous high");
   Check(!ResearchHL(HL_PRICE_REVERSAL,r,5,p,candidate,emitted,key,hl,threshold),"candidate recognized once");
   Check(!ResearchHL(HL_PRICE_REVERSAL,r,6,p,candidate,emitted,key,hl,threshold),"forming bar excluded");
   int f=FileOpen("HLRecognition_policy.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(f==INVALID_HANDLE) return INIT_FAILED;
   FileWrite(f,"checks","failures"); FileWrite(f,checks,failures); FileClose(f);
   Print("HLRecognition checks=",checks," failures=",failures);
   return failures==0 ? INIT_SUCCEEDED : INIT_FAILED;
}
void OnTick() { TesterStop(); }
