#property strict
#include "../../Include/TickShockTwoStageTimeLabels.mqh"
const int InpSubmitLatencyMs=0,InpMaxQuoteAgeMs=500;
#include "../../Include/TickShockTwoStageBarrierCandidate.mqh"
input string InpFolder="two_stage_barrier_multi_20260914";
int phase=0,test_file=INVALID_HANDLE,failures=0;long first_fill=0;ulong first_id=0,second_id=0;
void Check(const string name,const bool pass){FileWrite(test_file,name,pass?"PASS":"FAIL");FileFlush(test_file);if(!pass)++failures;}
int OnInit(){
 if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;
 if(FileIsExist(InpFolder+"\\results.csv",FILE_COMMON))return INIT_FAILED;
 FolderCreate(InpFolder,FILE_COMMON);
 if(!TSTCInit(InpFolder))return INIT_FAILED;
 test_file=FileOpen(InpFolder+"\\results.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');if(test_file==INVALID_HANDLE)return INIT_FAILED;
 FileWrite(test_file,"test_id","status");return INIT_SUCCEEDED;
}
void Arm(const int side,const string name){
 MqlTick q;if(!SymbolInfoTick(_Symbol,q))return;
 TSGIntent p;p.episode=name;p.symbol=_Symbol;p.direction=side;p.t0=q.time_msc-2;p.processing=q.time_msc-1;p.quote=q.time_msc-2;p.atr=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)*10;
 g_tsg_pending=p;g_tsg_pending_valid=true;TSGTryEntry();
}
void OnTick(){
 if(!MQLInfoInteger(MQL_TESTER)||phase==4)return;TSTCManage();
 if(phase==0&&TimeCurrent()<D'2025.01.02 09:00:00')return; // Deterministic fixture starts in an open trading session.
 if(phase==0){Arm(1,"test_long");if(ArraySize(g_tsg_trades)==1){first_fill=g_tsg_last_fill;first_id=g_tsg_trades[0].identifier;Check("FIRST_PROTECTED",g_tsg_trades[0].sl>0&&g_tsg_trades[0].tp>g_tsg_trades[0].entry);phase=1;}else {Check("FIRST_FILL",false);phase=4;}return;}
 if(phase==1){if(TSGNow()-first_fill<900000){if(TSGNow()-first_fill>1000){Arm(-1,"too_early");Check("EARLY_ENTRY_REJECTED",ArraySize(g_tsg_trades)==1);phase=2;}return;}}
 if(phase==2&&TSGNow()-first_fill>=900000){Arm(-1,"test_short");Check("TWO_POSITIONS",ArraySize(g_tsg_trades)==2&&g_tsg_peak_positions>=2);if(ArraySize(g_tsg_trades)!=2){phase=4;return;}second_id=g_tsg_trades[1].identifier;Check("DISTINCT_IDENTITIES",first_id!=second_id);TSGClose(g_tsg_trades[0],"TEST_CLOSE");phase=3;return;}
 if(phase==3){TSTCManage();Check("CLOSE_FIRST_ONLY",ArraySize(g_tsg_trades)==1&&g_tsg_trades[0].identifier==second_id&&TSGSelect(g_tsg_trades[0]));if(ArraySize(g_tsg_trades)>0)TSGClose(g_tsg_trades[0],"TEST_CLOSE");TSTCManage();Check("BOTH_RECONCILED",ArraySize(g_tsg_trades)==0&&g_tsg_closed==2&&g_tsg_errors==0);phase=4;}
}
void OnDeinit(const int reason){
 if(!MQLInfoInteger(MQL_TESTER)||test_file==INVALID_HANDLE)return;
 TSTCFinish();Check("FINISHED",phase==4&&g_tsg_closed==2&&g_tsg_errors==0&&PositionsTotal()==0);FileClose(test_file);
}
