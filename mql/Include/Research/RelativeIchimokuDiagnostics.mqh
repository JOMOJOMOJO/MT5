// Observation only: fixed 9/26/52, current-bar cloud from 26 bars earlier.
// No current-bar OHLC and no forward Chikou buffer reads.
int icFile=INVALID_HANDLE,icBars=INVALID_HANDLE;
struct ICSnapshot
  {
   bool valid;
   datetime anchor,asof,source_bar,source_close,lag_bar;
   double tenkan,kijun,kijun_old,span_a,span_b,last_close,lag_high,lag_low;
  };
ICSnapshot icPlan[3];

bool ICOpen()
  {
   icFile=FileOpen(runtimeTelemetryFileName+".ichi.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   icBars=FileOpen(runtimeTelemetryFileName+".ichi_bars.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(icFile==INVALID_HANDLE || icBars==INVALID_HANDLE) return false;
   FileWrite(icFile,"id","stage","tf","time","decision_time","price","valid","cloud_anchor","asof",
      "cloud_source_bar","cloud_source_close","lag_bar","tenkan","kijun","kijun_3bars_ago","span_a","span_b",
      "last_close","lag_high","lag_low","cloud_location","cloud_direction","tk_order","kijun_slope",
      "chikou_vs_old_range","cloud_thickness_r","distance_cloud_top_r","distance_cloud_bottom_r","distance_kijun_r");
   FileWrite(icBars,"id","tf","bar_time","close_time","high","low","close");
   return true;
  }

double ICMid(const MqlRates &r[],const int end,const int count)
  {
   double hi=r[end].high,lo=r[end].low;
   for(int i=end-count+1;i<end;i++){hi=MathMax(hi,r[i].high);lo=MathMin(lo,r[i].low);}
   return (hi+lo)/2.0;
  }

void ICLoad(const MqlRates &r[],const int closed,const int tfIndex,const datetime when)
  {
   ZeroMemory(icPlan[tfIndex]);
   int seconds=PeriodSeconds(dcTF[tfIndex]),q=closed,j=q-1,src=q-26;
   if(q<80 || q>=ArraySize(r) || r[q].time>when || r[q].time+seconds<=when) return;
   ICSnapshot s;ZeroMemory(s);
   s.anchor=r[q].time;s.asof=r[j].time+seconds;s.source_bar=r[src].time;s.source_close=r[src].time+seconds;
   s.lag_bar=r[j-26].time;
   s.tenkan=ICMid(r,j,9);s.kijun=ICMid(r,j,26);s.kijun_old=ICMid(r,j-3,26);
   s.span_a=(ICMid(r,src,9)+ICMid(r,src,26))/2.0;s.span_b=ICMid(r,src,52);
   s.last_close=r[j].close;s.lag_high=r[j-26].high;s.lag_low=r[j-26].low;
   s.valid=s.asof<=when && s.source_close<=when;
   icPlan[tfIndex]=s;
   for(int i=q-80;i<q;i++)
     {
      if(r[i].time+seconds>when) Print("IC_CAUSAL_FAILURE");
      FileWrite(icBars,dcId,EnumToString(dcTF[tfIndex]),TimeToString(r[i].time,TIME_DATE|TIME_SECONDS),
         TimeToString(r[i].time+seconds,TIME_DATE|TIME_SECONDS),DoubleToString(r[i].high,12),
         DoubleToString(r[i].low,12),DoubleToString(r[i].close,12));
     }
  }

string ICOrder(const double a,const double b) { return a>b?"UP":(a<b?"DOWN":"FLAT"); }
string ICLocation(const double p,const double hi,const double lo) { return p>hi?"ABOVE":(p<lo?"BELOW":"INSIDE"); }

void ICWrite(const string stage,const datetime when,const double price)
  {
   double risk=dcQuote.ask-NormalizePrice(dcQuote.ask-InpStopLossAtr*GetDistanceUnit());
   for(int i=0;i<3;i++)
     {
      ICSnapshot s=icPlan[i];
      if(s.asof>dcDecision || s.source_close>dcDecision || dcDecision>when) Print("IC_CAUSAL_FAILURE");
      bool ok=s.valid && risk>0;
      double top=MathMax(s.span_a,s.span_b),bottom=MathMin(s.span_a,s.span_b);
      FileWrite(icFile,dcId,stage,EnumToString(dcTF[i]),TimeToString(when,TIME_DATE|TIME_SECONDS),
         TimeToString(dcDecision,TIME_DATE|TIME_SECONDS),DoubleToString(price,12),(int)ok,
         TimeToString(s.anchor,TIME_DATE|TIME_SECONDS),TimeToString(s.asof,TIME_DATE|TIME_SECONDS),
         TimeToString(s.source_bar,TIME_DATE|TIME_SECONDS),TimeToString(s.source_close,TIME_DATE|TIME_SECONDS),
         TimeToString(s.lag_bar,TIME_DATE|TIME_SECONDS),DoubleToString(s.tenkan,12),DoubleToString(s.kijun,12),
         DoubleToString(s.kijun_old,12),DoubleToString(s.span_a,12),DoubleToString(s.span_b,12),
         DoubleToString(s.last_close,12),DoubleToString(s.lag_high,12),DoubleToString(s.lag_low,12),
         ok?ICLocation(price,top,bottom):"UNKNOWN",ok?ICOrder(s.span_a,s.span_b):"UNKNOWN",
         ok?ICOrder(s.tenkan,s.kijun):"UNKNOWN",ok?ICOrder(s.kijun,s.kijun_old):"UNKNOWN",
         ok?ICLocation(s.last_close,s.lag_high,s.lag_low):"UNKNOWN",
         ok?DoubleToString((top-bottom)/risk,12):"",ok?DoubleToString((price-top)/risk,12):"",
         ok?DoubleToString((price-bottom)/risk,12):"",ok?DoubleToString((price-s.kijun)/risk,12):"");
     }
  }

void ICClose()
  {
   if(icFile!=INVALID_HANDLE) FileClose(icFile);
   if(icBars!=INVALID_HANDLE) FileClose(icBars);
  }
