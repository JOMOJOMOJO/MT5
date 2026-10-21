#property strict
#property version "1.00"
#include "../../Include/Research/PortableTrading.mqh"
#include "../../Include/M15Environment.mqh"
input string InpTelemetryFileName="portable_harness.csv";
int qaFile=INVALID_HANDLE,qaErrors=0,qaCount=0;
void QACheck(const string name,const bool ok)
  {qaCount++;if(!ok)qaErrors++;FileWrite(qaFile,name,(int)ok);Print("PF_QA ",name," ",ok);}
void QAContext()
  {
   MqlRates r[18];ZeroMemory(r);
   double hi[18]={10,11,15,12,10,11,12,16,13,10,11,12,17,14,11,12,13,14};
   double lo[18]={8,9,10,9,6,8,9,11,10,7,9,10,12,11,8,9,10,11};
   for(int i=0;i<18;i++){r[i].time=D'2023.01.02'+i*900;r[i].high=hi[i];r[i].low=lo[i];r[i].close=(hi[i]+lo[i])/2;}
   CM15Environment a,b;a.Reset();b.Reset();M15EnvSnapshot waiting,known,mutated,outside;
   for(int i=0;i<=10;i++)a.Step(r,i);
   a.Snapshot(r[10].time+900,12,waiting);
   QACheck("RIGHT_CONFIRMATION_WAIT",waiting.regime=="UNKNOWN");
   a.Step(r,11);a.Snapshot(r[11].time+900,12,known);
   QACheck("CONFIRMED_STRUCTURE_UP",known.regime=="UP"&&known.position=="MID"&&MathAbs(known.raw-0.6)<1e-9);
   for(int i=12;i<18;i++){r[i].high=100000;r[i].low=0.01;r[i].close=90000;}
   for(int i=0;i<=11;i++)b.Step(r,i);
   b.Snapshot(r[11].time+900,12,mutated);
   QACheck("FUTURE_SUFFIX_INVARIANT",mutated.regime==known.regime&&mutated.raw==known.raw&&mutated.asof==known.asof&&mutated.break_time==known.break_time);
   b.Snapshot(r[11].time+900,20,outside);
   QACheck("RAW_POSITION_OUTSIDE",outside.location=="ABOVE"&&outside.raw>1&&outside.position=="HIGH");
  }
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER)||MQLInfoInteger(MQL_OPTIMIZATION))return INIT_FAILED;
   qaFile=FileOpen(InpTelemetryFileName,FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');if(qaFile==INVALID_HANDLE)return INIT_FAILED;
   FileWrite(qaFile,"test","passed");
   QACheck("USD_BASE_BUY",PFUsdDirection("USD","JPY",1)==1);
   QACheck("USD_BASE_SELL",PFUsdDirection("USD","JPY",-1)==-1);
   QACheck("USD_PROFIT_BUY",PFUsdDirection("EUR","USD",1)==-1);
   QACheck("GOLD_USD_BUY",PFUsdDirection("XAU","USD",1)==-1);
   QACheck("CROSS_NO_DIRECT_USD",PFUsdDirection("EUR","JPY",1)==0);
   QACheck("INVALID_VOLUME_SPEC",PFFloorVolume(1,0,10,0.01)==0);
   QACheck("NO_MINIMUM_UPSIZE",PFFloorVolume(0.009,0.01,10,0.01)==0);
   QACheck("DECIMAL_BOUNDARY",MathAbs(PFFloorVolume(0.03,0.01,10,0.01)-0.03)<1e-12);
   QACheck("QUARTER_LOT_STEP",MathAbs(PFFloorVolume(1.12,0.25,10,0.25)-1)<1e-12);
   QACheck("MAX_LOT_CAP",MathAbs(PFFloorVolume(3,0.1,0.5,0.1)-0.5)<1e-12);
   QACheck("OUTWARD_SL",MathAbs(PFPrice(157.1237,0.005,3,-1)-157.120)<1e-9);
   QACheck("UPWARD_SL",MathAbs(PFPrice(157.1237,0.005,3,1)-157.125)<1e-9);
   string resolved,reason;
   QACheck("EXACT_SYMBOL",PFResolveSymbol(_Symbol,resolved,reason)&&resolved==_Symbol);
   QACheck("BAD_ALIAS_REFUSED",!PFResolveSymbol("THIS_SYMBOL_DOES_NOT_EXIST",resolved,reason));
   QAContext();
   FileFlush(qaFile);return INIT_SUCCEEDED;
  }
void OnTick(){}
double OnTester(){return qaErrors==0?(double)qaCount:-(double)qaErrors;}
void OnDeinit(const int reason)
  {if(qaFile!=INVALID_HANDLE)FileClose(qaFile);PrintFormat("PF_QA_FINISH tests=%d errors=%d",qaCount,qaErrors);}
