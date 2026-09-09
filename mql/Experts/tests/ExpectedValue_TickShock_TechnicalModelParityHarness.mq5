#property strict
#include "../../Include/TickShock/TickShockTechnicalModel.mqh"
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;
   int src=FileOpen("technical_model_parity\\vectors.csv",FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
   int dst=FileOpen("technical_model_parity\\results.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   if(src==INVALID_HANDLE||dst==INVALID_HANDLE)return INIT_FAILED;
   FileReadString(src);FileWrite(dst,"episode_id","status","expected_direction","actual_direction","long_difference","short_difference");
   int rows=0,failures=0;
   while(!FileIsEnding(src))
     {
      string line=FileReadString(src);if(line=="")continue;string cells[];int n=StringSplit(line,',',cells);
      if(n!=TD_MODEL_FEATURE_COUNT+4){++failures;continue;}
      double raw[];ArrayResize(raw,TD_MODEL_FEATURE_COUNT);for(int i=0;i<TD_MODEL_FEATURE_COUNT;++i)raw[i]=cells[i+4]==""?EMPTY_VALUE:StringToDouble(cells[i+4]);
      double ls=0,ss=0;int actual=TDModelDecision(raw,ls,ss),expected=(int)StringToInteger(cells[3]);
      double dl=ls-StringToDouble(cells[1]),ds=ss-StringToDouble(cells[2]);bool ok=actual==expected&&MathAbs(dl)<1e-10&&MathAbs(ds)<1e-10;
      FileWrite(dst,cells[0],ok?"PASS":"FAIL",expected,actual,DoubleToString(dl,15),DoubleToString(ds,15));++rows;if(!ok)++failures;
     }
   FileClose(src);FileClose(dst);PrintFormat("technical_model_parity rows=%d failures=%d",rows,failures);
   return rows>0&&failures==0?INIT_SUCCEEDED:INIT_FAILED;
  }
void OnTick(){}
