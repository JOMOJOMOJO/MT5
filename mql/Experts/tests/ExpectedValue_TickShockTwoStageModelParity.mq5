#property strict
#include "../../Include/TickShockTwoStageModel.mqh"
#include "../../Include/TickShockTwoStagePolicy.mqh"
input string InpParityFolder="two_stage_model_parity_20260913";
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;
   string output=InpParityFolder+"\\results.csv";
   if(FileIsExist(output,FILE_COMMON))return INIT_FAILED;
   int source=FileOpen(InpParityFolder+"\\vectors.csv",FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   int result=FileOpen(output,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   if(source==INVALID_HANDLE||result==INVALID_HANDLE)return INIT_FAILED;
   for(int c=0;c<7+TS2_FEATURE_COUNT;++c)FileReadString(source);
   FileWrite(result,"episode_id","status","stage1_error","long_error","short_error","threshold_error","actual_direction","expected_direction");
   TS2Reset();int rows=0,failures=0;
   while(!FileIsEnding(source))
     {
      string episode=FileReadString(source);if(episode==""&&FileIsEnding(source))break;
      long processing=StringToInteger(FileReadString(source));
      double e1=StringToDouble(FileReadString(source)),el=StringToDouble(FileReadString(source)),es=StringToDouble(FileReadString(source));
      string et=FileReadString(source);int ed=(int)StringToInteger(FileReadString(source));
      double raw[TS2_FEATURE_COUNT];
      for(int c=0;c<TS2_FEATURE_COUNT;++c){string v=FileReadString(source);raw[c]=v==""?EMPTY_VALUE:StringToDouble(v);}
      double s1=0,ls=0,ss=0,threshold=0;int d=TS2Decision(raw,processing,s1,ls,ss,threshold);
      double dt=et==""?(threshold==DBL_MAX?0:DBL_MAX):MathAbs(threshold-StringToDouble(et));
      bool pass=MathAbs(s1-e1)<1e-10&&MathAbs(ls-el)<1e-10&&MathAbs(ss-es)<1e-10&&dt<1e-10&&d==ed;
      FileWrite(result,episode,pass?"PASS":"FAIL",MathAbs(s1-e1),MathAbs(ls-el),MathAbs(ss-es),dt,d,ed);
      ++rows;if(!pass)++failures;
     }
   FileClose(source);FileClose(result);
   PrintFormat("two_stage_model_parity rows=%d failures=%d orders=0",rows,failures);
   return rows>0&&failures==0?INIT_SUCCEEDED:INIT_FAILED;
  }
void OnTick(){}
