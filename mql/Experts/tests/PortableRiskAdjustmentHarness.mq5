#property strict
#property version "1.00"
#include "../../Include/Research/PortableRiskAdjustment.mqh"
input string InpTelemetryFileName="risk_adjustment_harness.csv";
int qaFile=INVALID_HANDLE,qaCount=0,qaErrors=0;
bool qaTickDone=false;
void Check(const string name,const bool ok)
  {qaCount++;if(!ok)qaErrors++;FileWrite(qaFile,name,(int)ok);Print("PFA_QA ",name," ",ok);}
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER)||MQLInfoInteger(MQL_OPTIMIZATION))return INIT_FAILED;
   qaFile=FileOpen(InpTelemetryFileName,FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');if(qaFile==INVALID_HANDLE)return INIT_FAILED;
   FileWrite(qaFile,"test","passed");
   Check("OBSERVED_052_TO_051",MathAbs(PFNextSmallerVolume(0.52,65.71,65.528905,0.01,100,0.01)-0.51)<1e-9);
   Check("OBSERVED_057_TO_056",MathAbs(PFNextSmallerVolume(0.57,65.83,65.57135,0.01,100,0.01)-0.56)<1e-9);
   Check("OBSERVED_036_TO_035",MathAbs(PFNextSmallerVolume(0.36,64.25,64.199915,0.01,100,0.01)-0.35)<1e-9);
   Check("MINIMUM_NOT_FORCED",PFNextSmallerVolume(0.01,10,9,0.01,100,0.01)==0);
   Check("QUARTER_STEP",MathAbs(PFNextSmallerVolume(1.25,125,124,0.25,100,0.25)-1)<1e-9);
   Check("INVALID_BUDGET",PFNextSmallerVolume(0.5,100,0,0.01,100,0.01)==0);
   return INIT_SUCCEEDED;
  }
void CheckReal(const ENUM_ORDER_TYPE side,const MqlTick &q)
  {
   string tag=side==ORDER_TYPE_BUY?"BUY_":"SELL_";
   PFPlan p;ZeroMemory(p);PFAudit a;
   p.min_volume=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);p.max_volume=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   p.step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   p.volume=PFFloorVolume(p.min_volume+10*p.step,p.min_volume,p.max_volume,p.step);
   double entry=side==ORDER_TYPE_BUY?q.ask:q.bid;
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double sl=entry+(side==ORDER_TYPE_BUY?-100:100)*tick;
   double profit=0,minimumProfit=0;
   bool calc=OrderCalcProfit(side,_Symbol,p.volume,entry,sl,profit)&&
             OrderCalcProfit(side,_Symbol,p.min_volume,entry,sl,minimumProfit)&&profit<0&&minimumProfit<0;
   p.loss=-profit;p.min_loss=-minimumProfit;p.budget=p.loss*0.95;p.reason="NORMALIZED_VOLUME_EXCEEDS_RISK";
   double before=p.volume,beforeLoss=p.loss;
   Check(tag+"BROKER_PROFIT",calc&&p.min_loss<p.budget);
   bool disabled=PFReduceRejectedPlan(_Symbol,side,entry,sl,false,p,a);
   Check(tag+"OFF_UNCHANGED",!disabled&&p.volume==before&&p.loss==beforeLoss&&a.checks==0);
   bool ok=PFReduceRejectedPlan(_Symbol,side,entry,sl,true,p,a);
   double finalProfit=0;bool finalCalc=OrderCalcProfit(side,_Symbol,p.volume,entry,sl,finalProfit);
   Check(tag+"ON_RECHECK",ok&&a.checks>0&&p.volume<before&&p.volume>=p.min_volume&&
         finalCalc&&finalProfit<0&&-finalProfit<=p.budget+1e-7&&MathAbs(p.loss+finalProfit)<1e-7);
   Check(tag+"MARGIN_RECHECK",ok&&p.margin>=0&&p.margin<=AccountInfoDouble(ACCOUNT_MARGIN_FREE));
   p.reason="PROFIT_RECHECK_FAILED";before=p.volume;
   Check(tag+"OTHER_ERROR_NOT_RECOVERED",!PFReduceRejectedPlan(_Symbol,side,entry,sl,true,p,a)&&a.checks==0&&p.volume==before);
  }
void OnTick()
  {
   if(qaTickDone)return;MqlTick q;if(!SymbolInfoTick(_Symbol,q)||q.bid<=0||q.ask<q.bid)return;
   qaTickDone=true;CheckReal(ORDER_TYPE_BUY,q);CheckReal(ORDER_TYPE_SELL,q);FileFlush(qaFile);
  }
double OnTester(){return qaTickDone&&qaErrors==0?(double)qaCount:-(double)(qaErrors+1);}
void OnDeinit(const int reason)
  {
   if(!qaTickDone)qaErrors++;
   if(qaFile!=INVALID_HANDLE)FileClose(qaFile);
   PrintFormat("PFA_QA_FINISH tests=%d errors=%d",qaCount,qaErrors);
  }
