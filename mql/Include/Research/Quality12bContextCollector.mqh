// Tester-only observer. No order calls; no changes to baseline decisions.
int qcContext=INVALID_HANDLE,qcPath=INVALID_HANDLE;
struct QCPath
  {
   string id;datetime entry,minute;long first_msc,last_msc;
   double open,high,low,close;bool started;
  };
QCPath qcPaths[];

bool QCOpen()
  {
   if(qcContext!=INVALID_HANDLE && qcPath!=INVALID_HANDLE) return true;
   qcContext=FileOpen(runtimeTelemetryFileName+".context.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   qcPath=FileOpen(runtimeTelemetryFileName+".path.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(qcContext==INVALID_HANDLE || qcPath==INVALID_HANDLE) return false;
   FileWrite(qcContext,"id","entry_time","entry_price","tf","bars_loaded","asof","regime","position","raw_position","location","high","low","break_direction","break_time","break_level","break_minutes","m15_reference_equal","history_complete");
   FileWrite(qcPath,"id","minute","first_msc","last_msc","open_bid","high_bid","low_bid","close_bid","horizon_end","end_censored");
   return true;
  }

void QCContext(const string id,const datetime when,const double price,const ENUM_TIMEFRAMES tf)
  {
   MqlRates r[];ArraySetAsSeries(r,false);
   int copied=CopyRates(runtimeSymbol,tf,0,1200,r);
   CHTFResearchEnvironment env;env.Reset();CM15Environment original;original.Reset();
   int secs=PeriodSeconds(tf),closed=0;
   for(int i=0;i<copied;i++)
     {
      if(r[i].time+secs>when) break;
      env.Step(r,i,secs);closed++;
      if(tf==PERIOD_M15) original.Step(r,i);
     }
   HTFResearchSnapshot s;env.Snapshot(when,price,s);
   bool parity=true;
   if(tf==PERIOD_M15)
     {
      M15EnvSnapshot base;original.Snapshot(when,price,base);
      parity=(s.regime==base.regime && s.position==base.position && s.raw==base.raw &&
              s.location==base.location && s.high==base.high && s.low==base.low &&
              s.break_direction==base.break_direction && s.break_time==base.break_time &&
              s.break_level==base.break_level && s.break_minutes==base.break_minutes);
     }
   if(s.asof>when || !parity) Print("QC_CAUSAL_OR_PARITY_FAILURE id=",id);
   FileWrite(qcContext,id,TimeToString(when,TIME_DATE|TIME_SECONDS),DoubleToString(price,8),EnumToString(tf),closed,
             TimeToString(s.asof,TIME_DATE|TIME_SECONDS),s.regime,s.position,DoubleToString(s.raw,12),s.location,
             DoubleToString(s.high,8),DoubleToString(s.low,8),s.break_direction,
             TimeToString(s.break_time,TIME_DATE|TIME_SECONDS),DoubleToString(s.break_level,8),
             DoubleToString(s.break_minutes,2),(int)parity,(int)(copied>=1199));
   FileFlush(qcContext);
  }

void QCFlush(const int i,const bool horizon,const bool censored)
  {
   if(!qcPaths[i].started) return;
   FileWrite(qcPath,qcPaths[i].id,TimeToString(qcPaths[i].minute,TIME_DATE|TIME_SECONDS),
             qcPaths[i].first_msc,qcPaths[i].last_msc,DoubleToString(qcPaths[i].open,8),
             DoubleToString(qcPaths[i].high,8),DoubleToString(qcPaths[i].low,8),
             DoubleToString(qcPaths[i].close,8),(int)horizon,(int)censored);
   FileFlush(qcPath);
  }

void QCStart(const datetime when,const double price)
  {
   if(!MQLInfoInteger(MQL_TESTER) || !QCOpen()) return;
   string id=TimeToString(when,TIME_DATE|TIME_SECONDS);
   QCContext(id,when,price,PERIOD_M15);QCContext(id,when,price,PERIOD_H1);QCContext(id,when,price,PERIOD_H4);
   int n=ArraySize(qcPaths);ArrayResize(qcPaths,n+1);ZeroMemory(qcPaths[n]);
   qcPaths[n].id=id;qcPaths[n].entry=when;
   QCUpdate(false);
  }

void QCUpdate(const bool newBar)
  {
   if(ArraySize(qcPaths)==0) return;
   MqlTick t;if(!SymbolInfoTick(runtimeSymbol,t) || t.bid<=0.0) return;
   datetime minute=(datetime)((long)t.time/60*60);
   for(int i=ArraySize(qcPaths)-1;i>=0;i--)
     {
      if(t.time<qcPaths[i].entry) continue;
      if(!qcPaths[i].started || qcPaths[i].minute!=minute)
        {
         QCFlush(i,false,false);
         qcPaths[i].started=true;qcPaths[i].minute=minute;qcPaths[i].first_msc=t.time_msc;
         qcPaths[i].open=t.bid;qcPaths[i].high=t.bid;qcPaths[i].low=t.bid;
        }
      qcPaths[i].last_msc=t.time_msc;qcPaths[i].close=t.bid;
      qcPaths[i].high=MathMax(qcPaths[i].high,t.bid);qcPaths[i].low=MathMin(qcPaths[i].low,t.bid);
      if(newBar && iBarShift(runtimeSymbol,InpSignalTimeframe,qcPaths[i].entry,false)>=InpMaxHoldBars)
        {
         QCFlush(i,true,false);
         int lastIndex=ArraySize(qcPaths)-1;
         if(i!=lastIndex) qcPaths[i]=qcPaths[lastIndex];
         ArrayResize(qcPaths,lastIndex);
        }
     }
  }

void QCClose()
  {
   for(int i=0;i<ArraySize(qcPaths);i++) QCFlush(i,false,true);
   if(qcContext!=INVALID_HANDLE) FileClose(qcContext);
   if(qcPath!=INVALID_HANDLE) FileClose(qcPath);
  }
