#ifndef W33_H1_EFFICIENCY_EXECUTION
#define W33_H1_EFFICIENCY_EXECUTION
// EA-local data/log adapter. Pure math and decision are in H1Efficiency.mqh.
int g_h1_efficiency_file=INVALID_HANDLE;
bool H1EfficiencyOpen()
  {
   g_h1_efficiency_file=FileOpen(g_tag+"_h1_efficiency.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ,';',CP_UTF8);
   if(g_h1_efficiency_file==INVALID_HANDLE)return false;
   FileWrite(g_h1_efficiency_file,"decision_at","setup_id","symbol","direction","enabled","valid","reason","outcome","precedence",
      "close_count","first_open","last_open","last_close","span_seconds","gap_count","net_distance","path_distance","er","roundtrip",
      "threshold","entry","initial_sl","bar_open_times","closes");FileFlush(g_h1_efficiency_file);return true;
  }
void H1EfficiencyClose()
  {if(g_h1_efficiency_file!=INVALID_HANDLE){FileClose(g_h1_efficiency_file);g_h1_efficiency_file=INVALID_HANDLE;}}
W33H1EfficiencyResult ReadH1Efficiency(const datetime decision,MqlRates &rates[])
  {
   ArraySetAsSeries(rates,false);ResetLastError();int count=CopyRates(_Symbol,PERIOD_H1,1,W33_H1_EFFICIENCY_CLOSES,rates);
   int error=GetLastError();datetime times[];double closes[];int size=(int)MathMax(0,count);
   ArrayResize(times,size);ArrayResize(closes,size);
   for(int i=0;i<size;i++){times[i]=rates[i].time;closes[i]=rates[i].close;}
   W33H1EfficiencyResult r=W33H1Efficiency(times,closes,decision);
   if(count!=W33_H1_EFFICIENCY_CLOSES){r.valid=false;r.reason="H1_HISTORY_INCOMPLETE count="+(string)count+" error="+(string)error;}
   return r;
  }
void H1EfficiencyObservation(W33Setup &s,const W33H1EfficiencyResult &r,const MqlRates &rates[],
   const datetime decision,const bool rejected,const string precedence)
  {
   string times="",prices="";
   for(int i=0;i<ArraySize(rates);i++)
     {if(i>0){times+="|";prices+="|";}times+=W33Time(rates[i].time);prices+=DoubleToString(rates[i].close,16);}
   string outcome=!r.valid?"ALLOW_UNAVAILABLE":(rejected?(precedence=="ELIGIBLE"?"SKIP":"WOULD_SKIP_PRECEDENCE"):"ALLOW");
   if(g_h1_efficiency_file!=INVALID_HANDLE)
     {
      FileWrite(g_h1_efficiency_file,W33Time(decision),ScaleCSV(s.setup_id),ScaleCSV(_Symbol),s.direction,InpSkipH1LowEfficiency,r.valid,ScaleCSV(r.reason),outcome,precedence,
         r.count,W33Time(r.first_time),W33Time(r.last_time),r.last_time>0?W33Time(r.last_time+3600):"",r.span_seconds,r.gap_count,
         DoubleToString(r.net_distance,16),DoubleToString(r.path_distance,16),r.valid?DoubleToString(r.er,16):"",r.valid?DoubleToString(r.roundtrip,16):"",
         DoubleToString(W33_H1_EFFICIENCY_THRESHOLD,16),DoubleToString(s.entry_price,10),DoubleToString(s.sl_price,10),ScaleCSV(times),ScaleCSV(prices));FileFlush(g_h1_efficiency_file);
     }
   string reason="status="+r.reason+" policy="+(InpSkipH1LowEfficiency?"ON":"OFF")+" outcome="+outcome;
   if(r.valid)reason+=" er="+DoubleToString(r.er,12)+" roundtrip="+DoubleToString(r.roundtrip,12);
   reason+=" gap_count="+(string)r.gap_count+" span_seconds="+(string)r.span_seconds+" missing=ALLOW source=NATIVE_H1_SHIFT1";
   Emit(s,"H1_ER_ENTRY_FILTER","OBSERVATION",reason);
  }
#endif
