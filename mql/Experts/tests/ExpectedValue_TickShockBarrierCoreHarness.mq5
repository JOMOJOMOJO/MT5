#property strict
#include "../../Include/TickShockBarrierCore.mqh"
input string InpFolder="two_stage_barrier_core_20260914";
int file=INVALID_HANDLE,failed=0,passed=0;
void Check(const string id,const bool value){FileWrite(file,id,value?"PASS":"FAIL");if(value)++passed;else ++failed;}
int OnInit(){
 if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;
 if(FileIsExist(InpFolder+"\\results.csv",FILE_COMMON))return INIT_FAILED;FolderCreate(InpFolder,FILE_COMMON);
 file=FileOpen(InpFolder+"\\results.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');if(file==INVALID_HANDLE)return INIT_FAILED;
 FileWrite(file,"test_id","status");double sl=0,tp=0;
 Check("LONG",TSGBounds(1,100,1,.68,.55,.01,sl,tp)&&MathAbs(sl-99.45)<1e-10&&MathAbs(tp-100.68)<1e-10);
 Check("SHORT",TSGBounds(-1,100,1,.68,.55,.01,sl,tp)&&MathAbs(sl-100.55)<1e-10&&MathAbs(tp-99.32)<1e-10);
 Check("LONG_ROUND",TSGBounds(1,100,1,.685,.555,.01,sl,tp)&&MathAbs(sl-99.45)<1e-10&&MathAbs(tp-100.69)<1e-10);
 Check("SHORT_ROUND",TSGBounds(-1,100,1,.685,.555,.01,sl,tp)&&MathAbs(sl-100.55)<1e-10&&MathAbs(tp-99.31)<1e-10);
 Check("INVALID_DIRECTION",!TSGBounds(0,100,1,.68,.55,.01,sl,tp));
 Check("INVALID_TICK",!TSGBounds(1,100,1,.68,.55,0,sl,tp));
 Check("LONG_BID_STOP",!TSGBrokerBounds(1,99.90,100,99.85,100.68,.10));
 Check("SHORT_ASK_STOP",!TSGBrokerBounds(-1,100,100.10,100.15,99.32,.10));
 Check("BROKER_EQUAL",TSGBrokerBounds(1,99.90,100,99.80,100.68,.10));
 Check("INTERVAL_MINUS",!TSGSpacing(1000,900999,900));
 Check("INTERVAL_EQUAL",TSGSpacing(1000,901000,900));
 Check("INTERVAL_PLUS",TSGSpacing(1000,901001,900));
 Check("FIRST_ENTRY",TSGSpacing(0,100,900));
 FileClose(file);PrintFormat("barrier_core passed=%d failed=%d",passed,failed);return failed==0?INIT_SUCCEEDED:INIT_FAILED;
}
void OnTick(){}
