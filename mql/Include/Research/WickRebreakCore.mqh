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
