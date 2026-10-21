// No return value from this observer is ever used by the trade engine.
#ifndef M15_ENVIRONMENT_DISPLAY
#define M15_ENVIRONMENT_DISPLAY
#include "M15Environment.mqh"
input bool InpShowM15Environment=true;
input bool InpM15EnvironmentCSV=true;
input bool InpM15EntryLabels=true;
CM15Environment m15env;
string m15prefix="",m15file="";
int m15csv=INVALID_HANDLE;
datetime m15poll=0,m15draw=0;
string m15seen[];
bool M15Visual() { return !MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE); }
bool M15Enabled() {return InpShowM15Environment || InpM15EnvironmentCSV || InpM15EntryLabels;}
string M15Value(double v,int digits=3) {return v==EMPTY_VALUE?"NA":DoubleToString(v,digits);}
bool M15At(datetime when,double ask,M15EnvSnapshot &s)
{
   ZeroMemory(s);s.regime="UNKNOWN";s.position="UNKNOWN";s.location="UNKNOWN";
   s.break_direction="NONE";s.raw=EMPTY_VALUE;s.break_minutes=EMPTY_VALUE;
   int shift=iBarShift(_Symbol,PERIOD_M15,when,false);if(shift<0) return false;
   datetime closed=iTime(_Symbol,PERIOD_M15,shift+1)+900;
   if(closed<=0 || closed>when) return false;
   if(m15env.last>closed)
   {
      // A delayed transaction must use its deal time, not today's cached state.
      MqlRates history[];int count=CopyRates(_Symbol,PERIOD_M15,shift+1,8000,history);
      if(count<5) return false;
      CM15Environment historical;historical.Reset();
      for(int i=0;i<count;i++) if(history[i].time+900<=when) historical.Step(history,i);
      historical.Snapshot(when,ask,s);return true;
   }
   if(m15env.last<closed)
   {
      MqlRates rates[];int n=0;
      if(m15env.last==0) n=CopyRates(_Symbol,PERIOD_M15,shift+1,8000,rates);
      else n=CopyRates(_Symbol,PERIOD_M15,m15env.last-7*86400,closed-1,rates);
      if(n<5) return false;
      for(int i=0;i<n;i++) if(rates[i].time+900<=when) m15env.Step(rates,i);
   }
   m15env.Snapshot(when,ask,s);return m15env.last==closed;
}
void M15Text(string name,int row,string text)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,12);ObjectSetInteger(0,name,OBJPROP_YDISTANCE,22+row*17);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
   ObjectSetString(0,name,OBJPROP_FONT,"Consolas");ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
}
void M15Line(string suffix,double price,color c,ENUM_LINE_STYLE style)
{
   string name=m15prefix+suffix;
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_HLINE,0,0,price);
   ObjectSetDouble(0,name,OBJPROP_PRICE,price);ObjectSetInteger(0,name,OBJPROP_COLOR,c);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,"M15 "+suffix+" "+DoubleToString(price,_Digits));
}
void M15DisplayTick()
{
   if(!InpShowM15Environment || !M15Visual() || TimeCurrent()==m15draw) return;
   m15draw=TimeCurrent();MqlTick tick={};if(!SymbolInfoTick(_Symbol,tick)) return;
   M15EnvSnapshot s;bool valid=M15At(tick.time,tick.ask,s);
   string rows[7];
   rows[0]="M15: "+s.regime+" / "+s.position+(valid?"":" (WAIT DATA)");
   rows[1]="raw_position: "+M15Value(s.raw,4);
   rows[2]="range_location: "+s.location;
   rows[3]="Structure High: "+(s.high>0?DoubleToString(s.high,_Digits):"NA");
   rows[4]="Structure Low: "+(s.low>0?DoubleToString(s.low,_Digits):"NA");
   rows[5]="Last Break: "+s.break_direction;rows[6]="Minutes Since Break: "+M15Value(s.break_minutes,1);
   for(int i=0;i<7;i++) M15Text(m15prefix+"PANEL_"+IntegerToString(i),i,rows[i]);
   if(valid && s.high>s.low && s.low>0)
   {
      M15Line("Structure High",s.high,clrMediumPurple,STYLE_SOLID);
      M15Line("Structure Low",s.low,clrMediumPurple,STYLE_SOLID);
      M15Line("1 of 3",s.low+(s.high-s.low)/3,clrSlateGray,STYLE_DOT);
      M15Line("2 of 3",s.low+2*(s.high-s.low)/3,clrSlateGray,STYLE_DOT);
   }
   else
   {
      ObjectDelete(0,m15prefix+"Structure High");ObjectDelete(0,m15prefix+"Structure Low");
      ObjectDelete(0,m15prefix+"1 of 3");ObjectDelete(0,m15prefix+"2 of 3");
   }
}
void M15FixedLabel(string event,string id,long msc,double ask,const M15EnvSnapshot &s)
{
   if(!InpM15EntryLabels || !M15Visual()) return;
   string name=m15prefix+event+"_"+id;StringReplace(name,"/","_");
   if(ObjectFind(0,name)<0 && ObjectCreate(0,name,OBJ_TEXT,0,(datetime)(msc/1000),ask))
   {
      string label=event+" M15="+s.regime+"_"+s.position+" pos="+M15Value(s.raw,2)+" break="+s.break_direction;
      ObjectSetString(0,name,OBJPROP_TEXT,label);
      ObjectSetString(0,name,OBJPROP_TOOLTIP,label+" "+s.location+" High="+DoubleToString(s.high,_Digits)+" Low="+DoubleToString(s.low,_Digits)+" id="+id);
      ObjectSetInteger(0,name,OBJPROP_COLOR,event=="ENTRY"?clrAqua:clrSilver);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,event=="ENTRY"?ANCHOR_RIGHT_UPPER:ANCHOR_RIGHT_LOWER);
   }
}
void M15Record(string event,string id,long msc,double ask,double fill=0,string quote_source="LIVE_ASK")
{
   if(!M15Enabled()) return;
   string key=event+"_"+id;
   for(int i=0;i<ArraySize(m15seen);i++) if(m15seen[i]==key) return;
   int n=ArraySize(m15seen);ArrayResize(m15seen,n+1);m15seen[n]=key;
   M15EnvSnapshot s;bool valid=M15At((datetime)(msc/1000),ask,s) && quote_source!="FILL_FALLBACK_NO_QUOTE";
   if(quote_source=="FILL_FALLBACK_NO_QUOTE")
   {s.position="UNKNOWN";s.location="UNKNOWN";s.raw=EMPTY_VALUE;s.normalized=EMPTY_VALUE;}
   if(s.break_time>0) s.break_minutes=((double)msc/1000.0-s.break_time)/60.0;
   if(m15csv!=INVALID_HANDLE)
   {
      FileWrite(m15csv,event,id,msc,_Symbol,ask,fill,valid,s.regime,s.position,M15Value(s.raw,12),s.location,
         s.high,s.low,s.break_direction,M15Value(s.break_minutes,9),(long)s.asof,(long)s.break_time,s.break_level,
         (long)s.break_bar,(long)s.break_confirmed,quote_source);
      FileFlush(m15csv);
   }
   M15FixedLabel(event,id,msc,ask,s);
}
void M15Ready(string id)
{if(!M15Enabled()) return;MqlTick t={};if(SymbolInfoTick(_Symbol,t)) M15Record("READY",id,t.time_msc,t.ask);}
void M15Deal(ulong deal,ulong magic)
{
   // Recover() has selected the trade history. Do not mutate its selection.
   if(!M15Enabled() || deal==0 || HistoryDealGetInteger(deal,DEAL_TIME_MSC)<=0) return;
   if(HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol || (ulong)HistoryDealGetInteger(deal,DEAL_MAGIC)!=magic ||
      HistoryDealGetInteger(deal,DEAL_TYPE)!=DEAL_TYPE_BUY || HistoryDealGetInteger(deal,DEAL_ENTRY)!=DEAL_ENTRY_IN) return;
   long msc=HistoryDealGetInteger(deal,DEAL_TIME_MSC);double fill=HistoryDealGetDouble(deal,DEAL_PRICE);
   MqlTick ticks[];double ask=fill;
   int copied=CopyTicksRange(_Symbol,ticks,COPY_TICKS_ALL,(ulong)msc,(ulong)msc);
   bool quoted=copied>0 && ticks[copied-1].ask>0;
   if(quoted) ask=ticks[copied-1].ask;
   M15Record("ENTRY",IntegerToString((long)deal),msc,ask,fill,quoted?"DEAL_TICK_ASK":"FILL_FALLBACK_NO_QUOTE");
}
void M15DisplayInit(ulong magic)
{
   m15env.Reset();m15prefix="M15_"+IntegerToString(ChartID())+"_";
   if(InpM15EnvironmentCSV)
   {
      m15file="TW_M15_environment_"+_Symbol+"_"+IntegerToString((long)magic)+".csv";
      if(MQLInfoInteger(MQL_TESTER)) FileDelete(m15file);
      m15csv=FileOpen(m15file,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
      if(m15csv==INVALID_HANDLE) Print("M15 diagnostic CSV unavailable; trading unaffected: ",GetLastError());
      else
      {
         if(FileSize(m15csv)==0) FileWrite(m15csv,"event","id","time_msc","symbol","ask","fill","valid","regime","position","raw_position","range_location",
            "structure_high","structure_low","last_break_direction","minutes_since_break","asof","break_time","break_level","break_bar","break_confirmed","quote_source");
         else
         {
            // Restore fixed labels from saved rows, never recalculate old states.
            while(!FileIsEnding(m15csv))
            {
               string fields[21];for(int j=0;j<21;j++) fields[j]=FileReadString(m15csv);
               if(fields[0]!="ENTRY" && fields[0]!="READY") continue;
               M15EnvSnapshot saved={};saved.regime=fields[7];saved.position=fields[8];
               saved.raw=fields[9]=="NA"?EMPTY_VALUE:StringToDouble(fields[9]);saved.location=fields[10];
               saved.high=StringToDouble(fields[11]);saved.low=StringToDouble(fields[12]);saved.break_direction=fields[13];
               string key=fields[0]+"_"+fields[1];int n=ArraySize(m15seen);ArrayResize(m15seen,n+1);m15seen[n]=key;
               M15FixedLabel(fields[0],fields[1],StringToInteger(fields[2]),StringToDouble(fields[4]),saved);
            }
         }
         FileSeek(m15csv,0,SEEK_END);
      }
   }
   if(M15Enabled()) {MqlTick tick={};M15EnvSnapshot initial;if(SymbolInfoTick(_Symbol,tick)) M15At(tick.time,tick.ask,initial);}
   M15DisplayTick();
}
void M15DisplayDeinit()
{
   if(m15csv!=INVALID_HANDLE) FileClose(m15csv);
   // Leave completed visual-test snapshots available for chart review.
   if(MQLInfoInteger(MQL_TESTER)) return;
   if(m15prefix!="") for(int i=ObjectsTotal(0)-1;i>=0;i--)
   {string name=ObjectName(0,i);if(StringFind(name,m15prefix)==0) ObjectDelete(0,name);}
}
#endif
