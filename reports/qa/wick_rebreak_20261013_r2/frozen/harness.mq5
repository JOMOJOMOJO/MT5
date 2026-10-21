#property strict
#property version "1.00"
#ifndef RESEARCH_WICK_REBREAK_CORE
#define RESEARCH_WICK_REBREAK_CORE
// 0 wait, 1 confirmed break, 2 expired, 3 invalidated. No live or forming-bar input.
int RBWaitDecision(const bool invalidated,const int age,const int expiry,
                   const datetime signal_bar,const datetime closed_bar,
                   const datetime available,const double close,const double level)
  {
   if(invalidated)return 3;
   if(age>expiry)return 2;
   if(age<1 || closed_bar<=signal_bar || closed_bar+300>available)return 0;
   if(close>level)return 1;
   return age>=expiry?2:0;
  }
int RBBarrier(const double bid,const double sl,const double tp)
  {if(bid<=sl)return -1;if(bid>=tp)return 1;return 0;}
#endif

input string InpTelemetryFileName="wick_rebreak_harness.csv";
int h=INVALID_HANDLE,n=0,errors=0;
void Check(const string label,const bool ok){n++;if(!ok)errors++;FileWrite(h,label,(int)ok);}
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;
   h=FileOpen(InpTelemetryFileName,FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');if(h<0)return INIT_FAILED;
   FileWrite(h,"test","passed");
   datetime t=D'2023.01.02 08:00';
   Check("NEWER_CLOSED_BREAK",RBWaitDecision(false,1,18,t,t+300,t+600,101,100)==1);
   Check("EQUALITY_NOT_BREAK",RBWaitDecision(false,1,18,t,t+300,t+600,100,100)==0);
   Check("SAME_BAR_NOT_BREAK",RBWaitDecision(false,1,18,t,t,t+600,101,100)==0);
   Check("OLDER_BAR_NOT_BREAK",RBWaitDecision(false,1,18,t,t-300,t+600,101,100)==0);
   Check("FORMING_BAR_NOT_BREAK",RBWaitDecision(false,1,18,t,t+300,t+599,101,100)==0);
   Check("INVALIDATION_PRIORITY",RBWaitDecision(true,1,18,t,t+300,t+600,101,100)==3);
   Check("EXPIRY_LAST_BAR_BREAK",RBWaitDecision(false,18,18,t,t+5400,t+5700,101,100)==1);
   Check("EXPIRY_LAST_BAR_MISS",RBWaitDecision(false,18,18,t,t+5400,t+5700,99,100)==2);
   Check("TOO_LATE",RBWaitDecision(false,19,18,t,t+5700,t+6000,101,100)==2);
   Check("NO_IMMEDIATE_B",RBWaitDecision(false,0,18,t,t+300,t+600,101,100)==0);
   Check("BELOW_SL",RBBarrier(98,99,102)==-1);
   Check("EXACT_SL",RBBarrier(99,99,102)==-1);
   Check("INSIDE",RBBarrier(100,99,102)==0);
   Check("EXACT_TP",RBBarrier(102,99,102)==1);
   Check("ABOVE_TP",RBBarrier(103,99,102)==1);
   PrintFormat("RB_QA_FINISH tests=%d errors=%d",n,errors);FileFlush(h);
   return errors==0?INIT_SUCCEEDED:INIT_FAILED;
  }
void OnTick(){}
void OnDeinit(const int reason){if(h>=0)FileClose(h);}
