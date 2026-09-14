#property strict
// Hand-authored score provider isolates policy behavior; final model parity uses generated estimators.
#define TS2_FEATURE_COUNT 3
const bool TS2_ROLLING=true,TS2_GATE_ENABLED=true;
const double TS2_GATE=0.0,TS2_FIXED_THRESHOLD=0.0,TS2_QUANTILE=0.5;
double TS2ScoreTradeability(const double &x[]){return x[0];}
double TS2ScoreLong(const double &x[]){return x[1];}
double TS2ScoreShort(const double &x[]){return x[2];}
#include "../../Include/TickShockTwoStagePolicy.mqh"
#include "../../Include/TickShockTwoStageTimeLabels.mqh"
input string InpHarnessFolder="two_stage_core_20260913";
int g_test_file=INVALID_HANDLE,g_failures=0;
void Check(const string id,const bool good)
  {FileWrite(g_test_file,id,good?"PASS":"FAIL");if(!good)++g_failures;}
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;
   if(FileIsExist(InpHarnessFolder+"\\results.csv",FILE_COMMON))return INIT_FAILED;
   FolderCreate(InpHarnessFolder,FILE_COMMON);
   g_test_file=FileOpen(InpHarnessFolder+"\\results.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   g_tstime_file=FileOpen(InpHarnessFolder+"\\labels.csv",FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(g_test_file==INVALID_HANDLE||g_tstime_file==INVALID_HANDLE)return INIT_FAILED;
   FileWrite(g_test_file,"test_id","status");
   TS2Reset();TS2Append(0,1);TS2Append(100,3);
   double raw[3]={1,100,0},s1=0,ls=0,ss=0,threshold=0;
   int direction=TS2Decision(raw,200,s1,ls,ss,threshold);
   Check("ROLL_CURRENT_EXCLUDED",MathAbs(threshold-2)<1e-12&&direction==1);
   raw[1]=200;direction=TS2Decision(raw,200,s1,ls,ss,threshold);
   Check("ROLL_SAME_TIMESTAMP_EXCLUDED",MathAbs(threshold-2)<1e-12&&direction==1);
   raw[1]=-100;raw[2]=60;direction=TS2Decision(raw,300,s1,ls,ss,threshold);
   Check("ROLL_PRIOR_GROUP_INCLUDED",MathAbs(threshold-51.5)<1e-12&&direction==-1);
   raw[0]=-1;raw[1]=1000;direction=TS2Decision(raw,400,s1,ls,ss,threshold);
   Check("STAGE1_REJECTION",direction==0);
   TSTimeRecord r;ZeroMemory(r);r.active=true;r.episode="synthetic";r.symbol="TEST";
   r.entry=1000;r.bid=100;r.ask=100.02;r.atr=.1;r.pip=.01;
   TSTimeAdvance(r,300999,100.04,100.06);Check("TIME_MINUS_ONE",!r.done[0]);
   TSTimeAdvance(r,301000,100.04,100.06);Check("TIME_EQUAL",r.done[0]&&!r.done[1]&&g_tstime_rows==2);
   TSTimeAdvance(r,601001,100.08,100.10);Check("TIME_PLUS_ONE",r.done[1]&&!r.done[2]&&g_tstime_rows==4);
   TSTimeAdvance(r,901000,100.01,100.03);Check("TIME_FINAL",r.done[2]&&!r.active&&g_tstime_rows==6);
   FileFlush(g_tstime_file);FileClose(g_tstime_file);FileClose(g_test_file);
   PrintFormat("two_stage_core tests=8 failures=%d orders=0",g_failures);
   return g_failures==0?INIT_SUCCEEDED:INIT_FAILED;
  }
void OnTick(){}
