// Tester-only observer. No trade calls and no environment-based entry gate.
int dcContext=INVALID_HANDLE,dcPath=INVALID_HANDLE;
HTFResearchSnapshot dcPlan[3];
int dcCounts[3];bool dcComplete[3];
datetime dcDecision=0;string dcId="";
MqlTick dcQuote;
ENUM_TIMEFRAMES dcTF[3]={PERIOD_M15,PERIOD_H1,PERIOD_H4};
struct DCPath
  {
   string id;datetime entry,minute;long first_msc,last_msc;
   double open,high,low,close;bool started;
  };
DCPath dcPaths[];

string DCNumber(const double value)
  { return value==EMPTY_VALUE ? "" : DoubleToString(value,12); }

bool DCOpen()
  {
   dcContext=FileOpen(runtimeTelemetryFileName+".context.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   dcPath=FileOpen(runtimeTelemetryFileName+".path.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(dcContext==INVALID_HANDLE || dcPath==INVALID_HANDLE) return false;
   FileWrite(dcContext,"id","stage","time","decision_time","price","tf","closed_bars","history_complete",
      "asof","regime","position","raw_position","location","range_valid","structure_high","structure_low",
      "break_direction","break_time","break_bar","break_confirmed","break_level","break_minutes",
      "m15_reference_equal","bid","ask","spread_price","spread_points","spread_atr","atr",
      "server_hour","server_weekday","execution_gate","spread_allowed","positions","daily_entries",
      "daily_cap","equity_cap","uncertain_send","planned_sl","planned_tp","hold_bars");
   FileWrite(dcPath,"id","minute","first_msc","last_msc","open_bid","high_bid","low_bid","close_bid","horizon_end","end_censored");
   return true;
  }

void DCLoad(const datetime when,const double price)
  {
   for(int t=0;t<3;t++)
     {
      MqlRates r[];ArraySetAsSeries(r,false);
      int n=CopyRates(runtimeSymbol,dcTF[t],0,1200,r),secs=PeriodSeconds(dcTF[t]);
      CHTFResearchEnvironment env;env.Reset();CM15Environment original;original.Reset();dcCounts[t]=0;
      for(int i=0;i<n;i++)
        {
         if(r[i].time+secs>when) break;
         env.Step(r,i,secs);if(t==0) original.Step(r,i);dcCounts[t]++;
        }
      env.Snapshot(when,price,dcPlan[t]);dcComplete[t]=(n>=1199 && dcCounts[t]>=1198);
      if(t==0)
        {
         M15EnvSnapshot b;original.Snapshot(when,price,b);
         if(b.regime!=dcPlan[t].regime || b.position!=dcPlan[t].position || b.raw!=dcPlan[t].raw ||
            b.location!=dcPlan[t].location || b.high!=dcPlan[t].high || b.low!=dcPlan[t].low ||
            b.break_direction!=dcPlan[t].break_direction || b.break_time!=dcPlan[t].break_time ||
            b.break_confirmed!=dcPlan[t].break_confirmed || b.break_bar!=dcPlan[t].break_bar ||
            b.break_level!=dcPlan[t].break_level || b.break_minutes!=dcPlan[t].break_minutes)
               Print("DC_CAUSAL_OR_PARITY_FAILURE");
        }
      if(!dcComplete[t])
        {
         dcPlan[t].regime="UNKNOWN";dcPlan[t].position="UNKNOWN";dcPlan[t].location="UNKNOWN";
         dcPlan[t].raw=EMPTY_VALUE;dcPlan[t].normalized=EMPTY_VALUE;
        }
     }
  }

void DCWrite(const string stage,const datetime when,const double price,const bool gate)
  {
   MqlDateTime dt;TimeToStruct(dcDecision,dt);
   double atr=GetDistanceUnit(),point=SymbolInfoDouble(runtimeSymbol,SYMBOL_POINT);
   double sl=NormalizePrice(dcQuote.ask-InpStopLossAtr*atr);
   double tp=NormalizePrice(dcQuote.ask+InpStopLossAtr*atr*InpTargetRMultiple);
   for(int t=0;t<3;t++)
     {
      HTFResearchSnapshot s=dcPlan[t];
      if(s.asof>dcDecision || s.break_confirmed>dcDecision || s.break_time>dcDecision || dcDecision>when)
         Print("DC_CAUSAL_OR_PARITY_FAILURE");
      bool valid=dcComplete[t] && s.high>s.low && s.regime!="UNKNOWN";
      if(valid)
        {
         s.raw=(price-s.low)/(s.high-s.low);
         s.position=s.raw<=1.0/3.0?"LOW":(s.raw<=2.0/3.0?"MID":"HIGH");
         s.location=s.raw<0?"BELOW":(s.raw>1?"ABOVE":"INSIDE");
        }
      FileWrite(dcContext,dcId,stage,TimeToString(when,TIME_DATE|TIME_SECONDS),TimeToString(dcDecision,TIME_DATE|TIME_SECONDS),
         DCNumber(price),EnumToString(dcTF[t]),dcCounts[t],(int)dcComplete[t],TimeToString(s.asof,TIME_DATE|TIME_SECONDS),
         s.regime,s.position,DCNumber(s.raw),s.location,(int)valid,DCNumber(s.high),DCNumber(s.low),s.break_direction,
         TimeToString(s.break_time,TIME_DATE|TIME_SECONDS),TimeToString(s.break_bar,TIME_DATE|TIME_SECONDS),
         TimeToString(s.break_confirmed,TIME_DATE|TIME_SECONDS),DCNumber(s.break_level),DCNumber(s.break_minutes),1,
         DCNumber(dcQuote.bid),DCNumber(dcQuote.ask),DCNumber(dcQuote.ask-dcQuote.bid),
         DCNumber(point>0?(dcQuote.ask-dcQuote.bid)/point:EMPTY_VALUE),DCNumber(atr>0?(dcQuote.ask-dcQuote.bid)/atr:EMPTY_VALUE),
         DCNumber(atr),dt.hour,dt.day_of_week,(int)gate,(int)IsSpreadAllowed(),CountManagedPositions(),dailyTradeCount,
         (int)dailyCapLatched,(int)equityCapLatched,(int)uncertainSend,DCNumber(sl),DCNumber(tp),InpMaxHoldBars);
     }
  }

void DCFlush(const int i,const bool horizon,const bool censored)
  {
   if(!dcPaths[i].started) return;
   FileWrite(dcPath,dcPaths[i].id,TimeToString(dcPaths[i].minute,TIME_DATE|TIME_SECONDS),dcPaths[i].first_msc,dcPaths[i].last_msc,
      DCNumber(dcPaths[i].open),DCNumber(dcPaths[i].high),DCNumber(dcPaths[i].low),DCNumber(dcPaths[i].close),(int)horizon,(int)censored);
  }

void DCUpdate(const bool newBar)
  {
   if(ArraySize(dcPaths)==0) return;
   MqlTick t;if(!SymbolInfoTick(runtimeSymbol,t) || t.bid<=0) return;
   datetime minute=(datetime)((long)t.time/60*60);
   for(int i=ArraySize(dcPaths)-1;i>=0;i--)
     {
      if(t.time<dcPaths[i].entry) continue;
      if(!dcPaths[i].started || dcPaths[i].minute!=minute)
        {
         DCFlush(i,false,false);dcPaths[i].started=true;dcPaths[i].minute=minute;dcPaths[i].first_msc=t.time_msc;
         dcPaths[i].open=t.bid;dcPaths[i].high=t.bid;dcPaths[i].low=t.bid;
        }
      dcPaths[i].last_msc=t.time_msc;dcPaths[i].close=t.bid;
      dcPaths[i].high=MathMax(dcPaths[i].high,t.bid);dcPaths[i].low=MathMin(dcPaths[i].low,t.bid);
      if(newBar && iBarShift(runtimeSymbol,InpSignalTimeframe,dcPaths[i].entry,false)>=InpMaxHoldBars)
        {
         DCFlush(i,true,false);int lastIndex=ArraySize(dcPaths)-1;
         if(i!=lastIndex) dcPaths[i]=dcPaths[lastIndex];ArrayResize(dcPaths,lastIndex);
        }
     }
  }

void DCCandidate(const datetime barTime,const bool gate)
  {
   if(!SymbolInfoTick(runtimeSymbol,dcQuote)) return;
   dcDecision=TimeCurrent();dcId=TimeToString(barTime,TIME_DATE|TIME_SECONDS);
   DCLoad(dcDecision,dcQuote.ask);DCWrite("CANDIDATE",dcDecision,dcQuote.ask,gate);
   int n=ArraySize(dcPaths);ArrayResize(dcPaths,n+1);ZeroMemory(dcPaths[n]);
   dcPaths[n].id=dcId;dcPaths[n].entry=dcDecision;DCUpdate(false);
  }

void DCEntry(const datetime when,const double fill)
  { DCWrite("ENTRY",when,fill,true); }

void DCClose()
  {
   for(int i=0;i<ArraySize(dcPaths);i++) DCFlush(i,false,true);
   if(dcContext!=INVALID_HANDLE) FileClose(dcContext);
   if(dcPath!=INVALID_HANDLE) FileClose(dcPath);
  }
