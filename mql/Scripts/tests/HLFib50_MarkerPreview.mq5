// Replay one MT5 diagnostic row through the EA's own drawing functions.
// All trade sending is disabled at compilation, independently of terminal settings.
bool HFPreviewNoSend(MqlTradeRequest &request,MqlTradeResult &result)
{ ZeroMemory(result); return false; }
#define OrderSend HFPreviewNoSend
#define OnInit HFPreviewInit
#define OnTick HFPreviewTick
#define OnDeinit HFPreviewDeinit
#define OnTradeTransaction HFPreviewTransaction
#include "../../Experts/USDJPY_M1_M5_HL_Fib50_Long.mq5"
#undef OnInit
#undef OnTick
#undef OnDeinit
#undef OnTradeTransaction

void PreviewPivot(SSPivot &p,const string price_value,const string bar_value,const string confirmed_value,const bool is_high)
{
   ZeroMemory(p); p.price=StringToDouble(price_value); p.bar_time=StringToTime(bar_value);
   p.confirmed_time=StringToTime(confirmed_value); p.high=is_high;
}

void OnStart()
{
   int file=FileOpen("hf_marker_example.csv",FILE_READ|FILE_CSV|FILE_ANSI,',');
   if(file==INVALID_HANDLE) { Print("HF_PREVIEW missing example CSV"); return; }
   for(int i=0;i<34;i++) FileReadString(file);
   string f[34];
   for(int i=0;i<34;i++) { f[i]=FileReadString(file); StringReplace(f[i],"\"",""); }
   FileClose(file);
   PreviewPivot(setup.old_low,f[4],f[5],f[6],false);
   PreviewPivot(setup.new_low,f[7],f[8],f[9],false);
   PreviewPivot(setup.reference_high,f[10],f[11],f[12],true);
   PreviewPivot(setup.breakout_high,f[14],f[15],f[16],true);
   setup.cross_time=StringToTime(f[13]); setup.valid=true;
   plan.structure_id=setup.new_low.bar_time; plan.placed=StringToTime(f[30]);
   plan.entry=StringToDouble(f[18]); plan.sl=StringToDouble(f[19]); plan.tp=StringToDouble(f[20]);
   if(plan.entry<=0 || setup.old_low.price<=0 || setup.new_low.price<=0 || setup.reference_high.price<=0 || setup.breakout_high.price<=0)
   { Print("HF_PREVIEW invalid CSV prices"); return; }
   entry_reason="Recorded tester order; L0/L1/H5/H1 share structure ID";
   reason="MARKER_REPLAY_NO_TRADING"; state=BUY_LIMIT_PLACED;
   prefix="HF_PREVIEW_";
   const string preview_symbol="HF_MARKER_QA";
   MqlRates bars[];
   int n=-1;
   for(int i=0;i<100 && n<10;i++)
   {
      n=CopyRates("USDJPY",PERIOD_M1,setup.old_low.bar_time-1800,plan.placed+3600,bars);
      if(n<10) Sleep(100);
   }
   // A bounded copy of the actual tested USDJPY bars avoids terminal chart-history
   // navigation limits. Only this dedicated custom symbol is changed.
   if(_Symbol!=preview_symbol)
   {
      bool custom=false;
      if(SymbolExist(preview_symbol,custom) && !custom) { Print("HF_PREVIEW symbol collision"); return; }
      if(!custom && !CustomSymbolCreate(preview_symbol,"HFValidation","USDJPY")) return;
      SymbolSelect(preview_symbol,true);
      CustomRatesDelete(preview_symbol,0,D'2030.01.01');
      if(n>0) CustomRatesReplace(preview_symbol,bars[0].time,bars[n-1].time,bars);
      Print("HF_PREVIEW fixture prepared bars=",n,"; run again on HF_MARKER_QA M1");
      return;
   }
   MarkPlan(); Display();
   string id=ID(setup.new_low.bar_time);
   bool valid=ObjectGetInteger(0,prefix+id+"_L0",OBJPROP_TIME)==setup.old_low.bar_time &&
              ObjectGetInteger(0,prefix+id+"_L1",OBJPROP_TIME)==setup.new_low.bar_time &&
              ObjectGetInteger(0,prefix+id+"_H5",OBJPROP_TIME)==setup.reference_high.bar_time &&
              ObjectGetInteger(0,prefix+id+"_H1",OBJPROP_TIME)==setup.breakout_high.bar_time &&
              MathAbs(ObjectGetDouble(0,prefix+id+"_LIMIT",OBJPROP_PRICE)-plan.entry)<_Point*0.1;
   ChartSetInteger(0,CHART_AUTOSCROLL,false);
   ChartSetInteger(0,CHART_MODE,CHART_CANDLES);
   ChartSetInteger(0,CHART_SHOW_GRID,false);
   ChartSetInteger(0,CHART_SHOW_VOLUMES,CHART_VOLUME_HIDE);
   ChartSetInteger(0,CHART_SCALE,2);
   const int shift=iBarShift(_Symbol,PERIOD_M1,plan.placed+1800,false);
   ChartNavigate(0,CHART_END,0);
   ChartRedraw(); Sleep(1000);
   bool shot=ChartScreenShot(0,"hf_marker_preview.png",1440,900,ALIGN_RIGHT);
   Print("HF_PREVIEW_RESULT anchors=",valid," bars=",n," shift=",shift," screenshot=",shot);
}
