// Research-only HTF descriptors. Never mutates or gates the M1/M5 strategy.
struct ContextPivot
{
   double price;
   datetime bar,confirmed;
};
struct ContextSnapshot
{
   string regime,status;
   ContextPivot high,old_high,low,old_low;
   datetime closed_bar;
   double ema,ema3,atr,slope;
   int bars;
};
int ctx_file=INVALID_HANDLE,ctx_rows=0,ctx_errors=0;
int ctx_bars_file=INVALID_HANDLE;
datetime ctx_last_h1=0,ctx_last_m15=0;
int ctx_ema_h1=INVALID_HANDLE,ctx_atr_h1=INVALID_HANDLE;
int ctx_ema_m15=INVALID_HANDLE,ctx_atr_m15=INVALID_HANDLE;

void ContextPivots(const MqlRates &r[],int seconds,datetime asof,ContextSnapshot &s)
{
   s.regime="UNKNOWN";s.status="INSUFFICIENT_PIVOTS";
   int n=ArraySize(r);s.bars=n;
   for(int i=2;i<n-2;i++)
   {
      datetime confirmed=r[i+2].time+seconds;
      if(confirmed>asof) continue;
      bool high=true,low=true;
      for(int k=1;k<=2;k++)
      {
         if(r[i].high<=r[i-k].high || r[i].high<=r[i+k].high) high=false;
         if(r[i].low>=r[i-k].low || r[i].low>=r[i+k].low) low=false;
      }
      ContextPivot p;p.bar=r[i].time;p.confirmed=confirmed;
      if(high){p.price=r[i].high;s.old_high=s.high;s.high=p;}
      if(low){p.price=r[i].low;s.old_low=s.low;s.low=p;}
   }
   if(s.old_high.bar==0 || s.old_low.bar==0) return;
   s.status="OK";s.regime="RANGE";
   if(s.high.price>s.old_high.price && s.low.price>s.old_low.price) s.regime="UP";
   if(s.high.price<s.old_high.price && s.low.price<s.old_low.price) s.regime="DOWN";
}
double ContextValue(int handle,int shift)
{
   double v[1];
   if(shift<1 || CopyBuffer(handle,0,shift,1,v)!=1 || !MathIsValidNumber(v[0]) || v[0]==EMPTY_VALUE) return EMPTY_VALUE;
   return v[0];
}
void ContextRead(ENUM_TIMEFRAMES tf,int ema_handle,int atr_handle,datetime asof,ContextSnapshot &s)
{
   ZeroMemory(s);s.regime="UNKNOWN";s.status="MISSING_RATES";
   s.ema=EMPTY_VALUE;s.ema3=EMPTY_VALUE;s.atr=EMPTY_VALUE;s.slope=EMPTY_VALUE;
   MqlRates r[];ArraySetAsSeries(r,false);
   int n=CopyRates(_Symbol,tf,1,800,r),seconds=PeriodSeconds(tf);
   if(n<8) return;
   s.closed_bar=r[n-1].time;
   if(s.closed_bar+seconds>asof){s.status="FUTURE_BAR_REJECTED";return;}
   datetime last_export=tf==PERIOD_H1?ctx_last_h1:ctx_last_m15;
   for(int j=0;j<n;j++)
      if(r[j].time>last_export)
         FileWrite(ctx_bars_file,tf==PERIOD_H1?"H1":"M15",ContextTS(r[j].time),ContextV(r[j].open),ContextV(r[j].high),ContextV(r[j].low),ContextV(r[j].close));
   if(tf==PERIOD_H1)ctx_last_h1=s.closed_bar;else ctx_last_m15=s.closed_bar;
   ContextPivots(r,seconds,asof,s);
   s.ema=ContextValue(ema_handle,1);s.ema3=ContextValue(ema_handle,4);s.atr=ContextValue(atr_handle,1);
   if(s.ema==EMPTY_VALUE || s.ema3==EMPTY_VALUE || s.atr==EMPTY_VALUE || s.atr<=0)
   {s.status+="/MISSING_INDICATOR";return;}
   s.slope=(s.ema-s.ema3)/(3*s.atr);
}
string ContextTS(datetime t){return t>0?TimeToString(t,TIME_DATE|TIME_SECONDS):"";}
string ContextV(double x){return MathIsValidNumber(x)&&MathAbs(x)<1e100?DoubleToString(x,12):"";}
void ContextWrite(string id,string tf,int seconds,const ContextSnapshot &s,datetime asof,double ask)
{
   double width=s.high.price-s.low.price;
   double position=s.high.bar>0 && s.low.bar>0 && width>0 ? (ask-s.low.price)/width : EMPTY_VALUE;
   double room=s.high.bar>0 ? s.high.price-ask : EMPTY_VALUE;
   FileWrite(ctx_file,id,tf,ContextTS(asof),s.status,s.regime,s.bars,ContextTS(s.closed_bar),ContextTS(s.closed_bar+seconds),
      ContextV(s.high.bar>0?s.high.price:EMPTY_VALUE),ContextTS(s.high.bar),ContextTS(s.high.confirmed),
      ContextV(s.old_high.bar>0?s.old_high.price:EMPTY_VALUE),ContextTS(s.old_high.bar),ContextTS(s.old_high.confirmed),
      ContextV(s.low.bar>0?s.low.price:EMPTY_VALUE),ContextTS(s.low.bar),ContextTS(s.low.confirmed),
      ContextV(s.old_low.bar>0?s.old_low.price:EMPTY_VALUE),ContextTS(s.old_low.bar),ContextTS(s.old_low.confirmed),
      ContextV(position),width>0?"OK":"NONPOSITIVE_OR_MISSING_RANGE",ContextV(room),ContextV(ask),
      ContextV(s.ema),ContextV(s.ema3),ContextV(s.atr),ContextV(s.slope));
   ctx_rows++;if(s.status!="OK")ctx_errors++;
}
void ContextRecord(string id,datetime asof,double ask)
{
   ContextSnapshot h1,m15;
   ContextRead(PERIOD_H1,ctx_ema_h1,ctx_atr_h1,asof,h1);
   ContextRead(PERIOD_M15,ctx_ema_m15,ctx_atr_m15,asof,m15);
   ContextWrite(id,"H1",3600,h1,asof,ask);ContextWrite(id,"M15",900,m15,asof,ask);
}
bool ContextInit()
{
   if(!ContextSelfTest())return false;
   ctx_ema_h1=iMA(_Symbol,PERIOD_H1,20,0,MODE_EMA,PRICE_CLOSE);ctx_atr_h1=iATR(_Symbol,PERIOD_H1,14);
   ctx_ema_m15=iMA(_Symbol,PERIOD_M15,20,0,MODE_EMA,PRICE_CLOSE);ctx_atr_m15=iATR(_Symbol,PERIOD_M15,14);
   if(ctx_ema_h1==INVALID_HANDLE || ctx_atr_h1==INVALID_HANDLE || ctx_ema_m15==INVALID_HANDLE || ctx_atr_m15==INVALID_HANDLE)return false;
   ctx_file=FileOpen("TW_context.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(ctx_file==INVALID_HANDLE)return false;
   ctx_bars_file=FileOpen("TW_context_bars.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(ctx_bars_file==INVALID_HANDLE)return false;
   FileWrite(ctx_bars_file,"tf","time","open","high","low","close");
   FileWrite(ctx_file,"id","tf","asof","status","regime","bars","closed_bar","closed_time",
      "high","high_time","high_confirmed","old_high","old_high_time","old_high_confirmed",
      "low","low_time","low_confirmed","old_low","old_low_time","old_low_confirmed",
      "position","position_status","room_price","entry_ask","ema20","ema_lag3","atr14","ema_slope_atr");
   return true;
}
void ContextDeinit()
{
   if(ctx_file!=INVALID_HANDLE)FileClose(ctx_file);
   if(ctx_bars_file!=INVALID_HANDLE)FileClose(ctx_bars_file);
   if(ctx_ema_h1!=INVALID_HANDLE)IndicatorRelease(ctx_ema_h1);
   if(ctx_atr_h1!=INVALID_HANDLE)IndicatorRelease(ctx_atr_h1);
   if(ctx_ema_m15!=INVALID_HANDLE)IndicatorRelease(ctx_ema_m15);
   if(ctx_atr_m15!=INVALID_HANDLE)IndicatorRelease(ctx_atr_m15);
   Print("TW_CONTEXT_RESULT rows=",ctx_rows," errors=",ctx_errors," orders_sent=0");
}
bool ContextSelfTest()
{
   MqlRates r[];ArrayResize(r,16);
   double prices[]={3,5,4,2,3,6,5,3,4,7,6,4,5,8,7,5};
   datetime start=D'2025.01.01';
   for(int i=0;i<16;i++){ZeroMemory(r[i]);r[i].time=start+i*900;r[i].high=prices[i]+0.25;r[i].low=prices[i]-0.25;}
   ContextSnapshot s={};ContextPivots(r,900,start+16*900,s);
   bool up=s.regime=="UP" && s.high.bar==r[13].time && s.low.bar==r[11].time;
   ZeroMemory(s);ContextPivots(r,900,start+15*900,s);
   bool future=s.high.bar==r[9].time && s.high.confirmed<=start+15*900;
   r[14].high=r[13].high;ZeroMemory(s);ContextPivots(r,900,start+16*900,s);
   bool equal=s.high.bar==r[9].time;
   for(int i=0;i<16;i++){r[i].high=20-prices[i]+0.25;r[i].low=20-prices[i]-0.25;}
   ZeroMemory(s);ContextPivots(r,900,start+16*900,s);bool down=s.regime=="DOWN";
   double mixed[]={6,7,6,4,6,9,6,3,6,10,6,2,6,11,6,1};
   for(int i=0;i<16;i++){r[i].high=mixed[i]+0.25;r[i].low=mixed[i]-0.25;}
   ZeroMemory(s);ContextPivots(r,900,start+16*900,s);bool range=s.regime=="RANGE";
   ArrayResize(r,5);ZeroMemory(s);ContextPivots(r,900,start+16*900,s);bool unknown=s.regime=="UNKNOWN";
   Print("TW_CONTEXT_UNIT up=",up," down=",down," range=",range," unknown=",unknown," future=",future," equal=",equal);
   return up&&down&&range&&unknown&&future&&equal;
}
