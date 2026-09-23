#property version "1.00"
#include "../../Include/SwingStructure/ConfirmedPivot.mqh"

int failures=0,checks=0;
void Check(const bool ok,const string name)
{
   checks++;
   if(!ok) failures++;
   Print(ok ? "PASS " : "FAIL ",name);
}

void UnitChecks()
{
   MqlRates r[];
   ArrayResize(r,8);
   ZeroMemory(r);
   for(int i=0;i<8;i++)
   {
      r[i].time=D'2026.09.01'+i*60;
      r[i].high=10;
      r[i].low=5;
   }
   r[2].high=12;
   Check(SSDetect(r,5,2,2,2)==0,"forming right confirmation bar is excluded");
   Check(SSDetect(r,6,2,2,2)==1,"high appears only after two right bars close");
   r[0].high=12;
   Check(SSDetect(r,6,2,2,2)==0,"equal left high rejected");
   r[0].high=10; r[4].high=12;
   Check(SSDetect(r,6,2,2,2)==0,"equal right high rejected");
   r[4].high=10; r[2].low=3;
   Check(SSDetect(r,6,2,2,2)==3,"outside bar retains both pivot types");
   r[0].low=3;
   Check(SSDetect(r,6,2,2,2)==1,"equal left low rejected");
   r[0].low=5; r[4].low=3;
   Check(SSDetect(r,6,2,2,2)==1,"equal right low rejected");
   r[4].low=5;
   Check(SSDetect(r,6,2,3,2)==0,"insufficient left bars waits");
   r[0].high=13;
   Check(SSDetect(r,6,2,1,1)==3 && SSDetect(r,6,2,2,2)==2,"window sensitivity");
   r[0].high=10;
   SSPivot p[]; datetime processed=0;
   SSCollect(r,5,2,2,processed,p);
   Check(ArraySize(p)==0,"no provisional record");
   SSCollect(r,6,2,2,processed,p);
   Check(ArraySize(p)==2 && p[0].bar_time==r[2].time && p[0].confirmed_time==r[5].time,"pivot and confirmation timestamps differ");
   r[2].high=9;
   SSCollect(r,8,2,2,processed,p);
   Check(ArraySize(p)==2 && p[0].price==12,"confirmed record survives changed history and new bars");
   Check(!SSCanConnect(p[0],p[1]),"ambiguous outside bar not connected");
   p[0].ambiguous=false; p[1].ambiguous=false;
   p[1].bar_time+=60; p[1].confirmed_time+=60;
   Check(SSCanConnect(p[0],p[1]),"alternating distinct pivots connect");
   p[1].high=true;
   Check(!SSCanConnect(p[0],p[1]),"same type not connected");
   datetime t[]={300,240,180,60};
   Check(SSChartIndex(t,4,180)==2 && SSChartIndex(t,4,120)==-1,"exact chart mapping and missing M1 bar");
}

bool WaitCalculated(const int handle)
{
   for(int i=0;i<100;i++)
   {
      if(BarsCalculated(handle)>0) return true;
      Sleep(100);
   }
   return false;
}

void CheckBuffers(const string symbol,const int handle,const ENUM_TIMEFRAMES tf,const int offset)
{
   MqlRates r[];
   const int n=CopyRates(symbol,tf,0,5000,r);
   SSPivot expected[]; datetime processed=0;
   SSCollect(r,n,2,2,processed,expected);
   int matched=0,actual=0;
   for(int b=offset;b<=offset+1;b++)
   {
      double values[];
      const int count=CopyBuffer(handle,b,0,Bars(symbol,PERIOD_M1),values);
      for(int j=0;j<count;j++) if(values[j]!=EMPTY_VALUE) actual++;
   }
   for(int i=0;i<ArraySize(expected);i++)
   {
      const int shift=iBarShift(symbol,PERIOD_M1,expected[i].bar_time,true);
      const int b=offset+(expected[i].high ? 0 : 1);
      double price[],confirmed[];
      if(CopyBuffer(handle,b,shift,1,price)==1 && CopyBuffer(handle,b+4,shift,1,confirmed)==1 &&
         price[0]==expected[i].price && (datetime)confirmed[0]==expected[i].confirmed_time) matched++;
   }
   Check(ArraySize(expected)>0 && actual==ArraySize(expected) && matched==actual,
         EnumToString(tf)+" all buffer prices, exact M1 times, confirmation times and no extra candidates: "+IntegerToString(matched));
}

void OnStart()
{
   UnitChecks();
   const string symbol="SSV_QA";
   bool custom=false;
   if(!SymbolExist(symbol,custom)) Check(CustomSymbolCreate(symbol,"SwingStructureQA"),"create QA symbol");
   CustomSymbolSetInteger(symbol,SYMBOL_DIGITS,5);
   CustomSymbolSetDouble(symbol,SYMBOL_POINT,0.00001);
   SymbolSelect(symbol,true);
   MqlRates r[]; ArrayResize(r,601); ZeroMemory(r);
   for(int i=0;i<601;i++)
   {
      r[i].time=D'2026.09.01 00:00'+i*60;
      r[i].open=1.1+0.004*MathSin(i*0.06)+0.0007*MathSin(i*0.9);
      r[i].close=r[i].open+0.00005*MathCos(i);
      r[i].high=MathMax(r[i].open,r[i].close)+0.0001;
      r[i].low=MathMin(r[i].open,r[i].close)-0.0001;
      r[i].tick_volume=20;
      r[i].spread=10;
   }
   // Clear this dedicated fixture's previous append, so repeated runs start identically.
   CustomRatesDelete(symbol,0,D'2030.01.01');
   Check(CustomRatesReplace(symbol,r[0].time,r[600].time,r)==601,"synthetic M1 history loaded");
   // iCustom object functions use the calling chart. Run this script on SSV_QA M1.
   if(_Symbol!=symbol || _Period!=PERIOD_M1)
   {
      Print("Fixture prepared. Run this script again on SSV_QA M1.");
      return;
   }
   const long chart=ChartID();
   Check(chart>0,"M1 chart opened");
   for(int retry=0;retry<100 && Bars(symbol,PERIOD_M1)!=601;retry++) Sleep(100);
   Check(Bars(symbol,PERIOD_M1)==601,"fixture starts with exactly 601 M1 bars");
   const int handle=iCustom(symbol,PERIOD_M1,"M1_M5_SwingStructure_Visualizer");
   Check(handle!=INVALID_HANDLE,"indicator handle initialized");
   if(chart>0 && handle!=INVALID_HANDLE)
   {
      Check(ChartIndicatorAdd(chart,0,handle),"indicator attached to M1 chart");
      Check(WaitCalculated(handle),"indicator calculated in MT5");
      // A successful lower-TF calculation can precede the asynchronous M5 build.
      for(int retry=0;retry<100;retry++)
      {
         double ready[];
         int copied=CopyBuffer(handle,0,0,601,ready);
         bool found=false;
         for(int i=0;i<copied;i++) if(ready[i]!=EMPTY_VALUE) found=true;
         if(found) break;
         Sleep(100);
      }
      CheckBuffers(symbol,handle,PERIOD_M1,2);
      CheckBuffers(symbol,handle,PERIOD_M5,0);
      double old_values[8][601];
      for(int b=0;b<8;b++)
      {
         double v[]; const int copied=CopyBuffer(handle,b,0,601,v);
         for(int j=0;j<601;j++) old_values[b][j]=(j<copied ? v[j] : EMPTY_VALUE);
      }
      MqlRates extra[]; ArrayResize(extra,10);
      for(int i=0;i<10;i++)
      {
         extra[i]=r[600];
         extra[i].time=r[600].time+(i+1)*60;
         extra[i].high+=i*0.0001;
         extra[i].low-=i*0.0001;
      }
      Check(CustomRatesUpdate(symbol,extra)==10,"append ten M1 bars");
      Sleep(1500);
      double trigger[]; CopyBuffer(handle,0,0,1,trigger);
      Sleep(500);
      int retained=0,lost=0;
      for(int b=0;b<8;b++)
      {
         double v[]; const int copied=CopyBuffer(handle,b,10,601,v);
         for(int j=0;j<601;j++) if(old_values[b][j]!=EMPTY_VALUE)
         {
            if(copied==601 && v[j]==old_values[b][j]) retained++; else lost++;
         }
      }
      Check(retained>0 && lost==0,"all confirmed buffer entries immutable after append: "+IntegerToString(retained));
      ChartSetInteger(chart,CHART_AUTOSCROLL,false);
      ChartSetInteger(chart,CHART_SCALE,3);
      ChartNavigate(chart,CHART_END,-120);
      ChartRedraw(chart); Sleep(500);
      Check(ChartScreenShot(chart,"swing_structure_qa.png",1440,900,ALIGN_RIGHT),"chart screenshot saved");
      const string unrelated="QA_keep_me";
      ObjectCreate(chart,unrelated,OBJ_HLINE,0,0,1.1);
      Check(ObjectsTotal(chart)>10,"pivot and debug objects exist");
      ChartIndicatorDelete(chart,0,"SwingStructure M1/M5");
      IndicatorRelease(handle); Sleep(300);
      int remaining=0;
      for(int i=0;i<ObjectsTotal(chart);i++) if(StringFind(ObjectName(chart,i),"SSV_")==0) remaining++;
      Check(remaining==0 && ObjectFind(chart,unrelated)>=0,"deinit removes own objects and preserves unrelated drawing");
   }
   Print("SWING_STRUCTURE_RESULT checks=",checks," failures=",failures);
   const int f=FileOpen("swing_structure_result.txt",FILE_WRITE|FILE_TXT);
   if(f!=INVALID_HANDLE)
   {
      FileWrite(f,"checks=",checks," failures=",failures);
      FileClose(f);
   }
}
