#ifndef PORTABLE_CONTEXT_DIAGNOSTICS_MQH
#define PORTABLE_CONTEXT_DIAGNOSTICS_MQH
// Observations only. Closed bars, prior-bar normalization, no outcome/entry filter.
ENUM_TIMEFRAMES pcTF[4]={PERIOD_M5,PERIOD_M15,PERIOD_H1,PERIOD_H4};
int pcAtr[4]={INVALID_HANDLE,INVALID_HANDLE,INVALID_HANDLE,INVALID_HANDLE};
int pcEma[4]={INVALID_HANDLE,INVALID_HANDLE,INVALID_HANDLE,INVALID_HANDLE};
int pcFile=INVALID_HANDLE;
bool PCOpen(const string symbol,const string file)
  {
   ArrayInitialize(pcAtr,INVALID_HANDLE);ArrayInitialize(pcEma,INVALID_HANDLE);
   pcFile=FileOpen(file,FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');if(pcFile==INVALID_HANDLE)return false;
   FileWrite(pcFile,"id","symbol","decision","tf","closed_bar","available_at","history_ready","legacy_regime","legacy_position",
             "legacy_raw_position","legacy_break_direction","legacy_break_minutes","range_valid","asof","structure_high","structure_low",
             "closed_price_above_structure","closed_price_below_structure","range_atr_prior","body_atr_prior","gap_atr_prior",
             "tick_volume_ratio_prior20","real_volume_ratio_prior20","volume_source","ema20_slope3_atr","distance_ema20_atr",
             "spread_price","spread_atr","atr","atr_prior","min_lot","contract_size","return_3bars_atr");
   for(int i=0;i<4;i++)
     {
      pcAtr[i]=iATR(symbol,pcTF[i],14);pcEma[i]=iMA(symbol,pcTF[i],20,0,MODE_EMA,PRICE_CLOSE);
      if(pcAtr[i]==INVALID_HANDLE||pcEma[i]==INVALID_HANDLE)return false;
     }
   return true;
  }
string PCNum(const double n){return n==EMPTY_VALUE||!MathIsValidNumber(n)?"":DoubleToString(n,12);}
void PCWrite(const string id,const string symbol,const datetime decision,const HTFResearchSnapshot &context[])
  {
   MqlTick q;if(pcFile==INVALID_HANDLE||!SymbolInfoTick(symbol,q)||q.time>decision)return;
   for(int i=0;i<4;i++)
     {
      MqlRates r[];ArraySetAsSeries(r,true);double a[],e[];ArraySetAsSeries(a,true);ArraySetAsSeries(e,true);
      int seconds=PeriodSeconds(pcTF[i]);
      bool ready=CopyRates(symbol,pcTF[i],0,24,r)==24 && CopyBuffer(pcAtr[i],0,1,2,a)==2 && CopyBuffer(pcEma[i],0,1,4,e)==4;
      if(!ready || r[1].time+seconds>decision || a[0]<=0 || a[1]<=0)
        {
         FileWrite(pcFile,id,symbol,TimeToString(decision,TIME_DATE|TIME_SECONDS),EnumToString(pcTF[i]),"","",0);
         continue;
        }
      double ticks=0,real=0;bool allReal=true;
      for(int j=2;j<=21;j++){ticks+=(double)r[j].tick_volume;real+=(double)r[j].real_volume;if(r[j].real_volume<=0)allReal=false;}
      double tv=ticks>0?(double)r[1].tick_volume/(ticks/20):EMPTY_VALUE;
      double rv=allReal&&real>0&&r[1].real_volume>0?(double)r[1].real_volume/(real/20):EMPTY_VALUE;
      HTFResearchSnapshot s;ZeroMemory(s);s.regime="NA";s.position="NA";s.break_direction="NA";s.raw=EMPTY_VALUE;s.break_minutes=EMPTY_VALUE;
      if(i>0)s=context[i-1];
      if(s.asof>decision || s.break_confirmed>decision || s.break_time>decision){Print("PC_FATAL_FUTURE_CONTEXT");continue;}
      bool valid=i>0&&s.high>s.low&&s.regime!="UNKNOWN";
      FileWrite(pcFile,id,symbol,TimeToString(decision,TIME_DATE|TIME_SECONDS),EnumToString(pcTF[i]),
          TimeToString(r[1].time,TIME_DATE|TIME_SECONDS),TimeToString(r[1].time+seconds,TIME_DATE|TIME_SECONDS),1,
          s.regime,s.position,PCNum(s.raw),s.break_direction,PCNum(s.break_minutes),(int)valid,TimeToString(s.asof,TIME_DATE|TIME_SECONDS),
          PCNum(s.high),PCNum(s.low),(int)(valid&&r[1].close>s.high),(int)(valid&&r[1].close<s.low),
          PCNum((r[1].high-r[1].low)/a[1]),PCNum((r[1].close-r[1].open)/a[1]),PCNum((r[1].open-r[2].close)/a[1]),
          PCNum(tv),PCNum(rv),rv==EMPTY_VALUE?"TICK_ONLY":"REAL_AND_TICK",PCNum((e[0]-e[3])/a[0]),PCNum((r[1].close-e[0])/a[0]),
          PCNum(q.ask-q.bid),PCNum((q.ask-q.bid)/a[0]),PCNum(a[0]),PCNum(a[1]),SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN),
          SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE),PCNum((r[1].close-r[4].close)/a[1]));
     }
  }
void PCClose()
  {
   if(pcFile!=INVALID_HANDLE){FileClose(pcFile);pcFile=INVALID_HANDLE;}
   for(int i=0;i<4;i++){if(pcAtr[i]!=INVALID_HANDLE)IndicatorRelease(pcAtr[i]);if(pcEma[i]!=INVALID_HANDLE)IndicatorRelease(pcEma[i]);}
  }
#endif
