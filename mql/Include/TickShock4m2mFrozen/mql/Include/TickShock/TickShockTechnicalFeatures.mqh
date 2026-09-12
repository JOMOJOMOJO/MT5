#ifndef TICK_SHOCK_TECHNICAL_FEATURES_MQH
#define TICK_SHOCK_TECHNICAL_FEATURES_MQH

// Pure, bounded indicator engine with one explicit CopyRates adapter.  Every bar
// is chronological and usable only at open_time + timeframe <= decision t0.
// Wilder indicators use an arithmetic seed, then Wilder smoothing.  EMA uses
// an arithmetic seed, then alpha=2/(period+1).  These finite-history definitions
// are shared by research and any resulting EA, rather than terminal handles.
#define TS_TECH_BAR_CAPACITY 256
#define TS_TECH_FEATURE_CAPACITY 600

struct TSTechSnapshot
  {
   long t0_msc;
   long quote_msc;
   long max_source_close_msc;
   long future_source_count;
   int rejected_uncompleted_bars;
   int invalid_bar_count;
   int m1_bars;
   int m5_bars;
   int m15_bars;
   int count;
   int available_count;
   bool overflow;
   double atr14_m1;
   double atr14_m5;
   double atr14_m15;
   string names[TS_TECH_FEATURE_CAPACITY];
   double values[TS_TECH_FEATURE_CAPACITY];
   bool available[TS_TECH_FEATURE_CAPACITY];
  };

string TSTechSchema(){return "tickshock-technical-features-v1";}
bool TSTechNumber(const double x){return MathIsValidNumber(x)&&x!=EMPTY_VALUE;}
double TSTechMissing(){return EMPTY_VALUE;}
double TSTechRatio(const double x,const double d)
  {return TSTechNumber(x)&&TSTechNumber(d)&&d>0.0?x/d:TSTechMissing();}
double TSTechDifference(const double x,const double y)
  {return TSTechNumber(x)&&TSTechNumber(y)?x-y:TSTechMissing();}
double TSTechProduct(const double x,const double y)
  {return TSTechNumber(x)&&TSTechNumber(y)?x*y:TSTechMissing();}
double TSTechAt(const double &values[],const int index)
  {return index>=0&&index<ArraySize(values)?values[index]:TSTechMissing();}

void TSTechAdd(TSTechSnapshot &s,const string name,const double value)
  {
   if(s.count>=TS_TECH_FEATURE_CAPACITY){s.overflow=true;return;}
   int i=s.count++;s.names[i]=name;s.available[i]=TSTechNumber(value);
   s.values[i]=s.available[i]?value:0.0;if(s.available[i])++s.available_count;
  }

int TSTechFind(const TSTechSnapshot &s,const string name)
  {for(int i=0;i<s.count;++i)if(s.names[i]==name)return i;return -1;}
double TSTechValue(const TSTechSnapshot &s,const string name)
  {int i=TSTechFind(s,name);return i>=0&&s.available[i]?s.values[i]:TSTechMissing();}

void TSTechAllocate(double &values[],const int count)
  {ArrayResize(values,count);ArrayInitialize(values,EMPTY_VALUE);}

// The current observation is ranked against up to 64 PREVIOUS observations;
// ties receive half weight.  At least 20 valid historical values are required.
double TSTechPercentile(const double &values[],const int index,const int lookback=64)
  {
   double x=TSTechAt(values,index);if(!TSTechNumber(x))return TSTechMissing();
   int n=0;double rank=0.0;
   for(int i=MathMax(0,index-lookback);i<index;++i)if(TSTechNumber(values[i]))
     {++n;if(values[i]<x)rank+=1.0;else if(values[i]==x)rank+=0.5;}
   return n>=20?rank/(double)n:TSTechMissing();
  }

double TSTechZScore(const double &values[],const int index,const int lookback=64)
  {
   double x=TSTechAt(values,index);if(!TSTechNumber(x))return TSTechMissing();
   int n=0;double sum=0.0,sum2=0.0;
   for(int i=MathMax(0,index-lookback);i<index;++i)if(TSTechNumber(values[i]))
     {++n;sum+=values[i];sum2+=values[i]*values[i];}
   if(n<20)return TSTechMissing();double mean=sum/n,variance=MathMax(0.0,sum2/n-mean*mean);
   return variance>1e-24?(x-mean)/MathSqrt(variance):TSTechMissing();
  }

void TSTechSMA(const double &source_values[],const int period,double &output[])
  {
   int n=ArraySize(source_values);TSTechAllocate(output,n);if(period<=0)return;
   for(int i=period-1;i<n;++i)
     {double sum=0.0;bool valid=true;for(int j=i-period+1;j<=i;++j){if(!TSTechNumber(source_values[j])){valid=false;break;}sum+=source_values[j];}if(valid)output[i]=sum/period;}
  }

void TSTechSmooth(const double &source_values[],const int period,const bool wilder,double &output[])
  {
   int n=ArraySize(source_values);TSTechAllocate(output,n);if(period<=0)return;
   double sum=0.0,last=0.0,alpha=wilder?1.0/period:2.0/(period+1.0);int consecutive=0;
   for(int i=0;i<n;++i)
     {
      if(!TSTechNumber(source_values[i])){consecutive=0;sum=0.0;continue;}
      if(consecutive<period){sum+=source_values[i];++consecutive;if(consecutive==period){last=sum/period;output[i]=last;}}
      else{last+=alpha*(source_values[i]-last);output[i]=last;}
     }
  }

void TSTechATR(const MqlRates &bars[],const int period,double &output[])
  {
   int n=ArraySize(bars);double tr[];TSTechAllocate(tr,n);
   for(int i=1;i<n;++i)tr[i]=MathMax(bars[i].high-bars[i].low,MathMax(MathAbs(bars[i].high-bars[i-1].close),MathAbs(bars[i].low-bars[i-1].close)));
   TSTechSmooth(tr,period,true,output);
  }

void TSTechRSI(const double &close[],const int period,double &output[])
  {
   int n=ArraySize(close);double gains[],losses[],ag[],al[];TSTechAllocate(gains,n);TSTechAllocate(losses,n);TSTechAllocate(output,n);
   for(int i=1;i<n;++i){double change=close[i]-close[i-1];gains[i]=MathMax(change,0.0);losses[i]=MathMax(-change,0.0);}
   TSTechSmooth(gains,period,true,ag);TSTechSmooth(losses,period,true,al);
   for(int i=0;i<n;++i)if(TSTechNumber(ag[i])&&TSTechNumber(al[i]))
      output[i]=ag[i]+al[i]>0.0?100.0*ag[i]/(ag[i]+al[i]):50.0;
  }

void TSTechADX(const MqlRates &bars[],const int period,double &adx[],double &plus_di[],double &minus_di[])
  {
   int n=ArraySize(bars);double plus[],minus[],atr[],ps[],ms[],dx[];
   TSTechAllocate(plus,n);TSTechAllocate(minus,n);TSTechAllocate(plus_di,n);TSTechAllocate(minus_di,n);TSTechAllocate(dx,n);
   for(int i=1;i<n;++i)
     {double up=bars[i].high-bars[i-1].high,down=bars[i-1].low-bars[i].low;plus[i]=up>down&&up>0.0?up:0.0;minus[i]=down>up&&down>0.0?down:0.0;}
   TSTechATR(bars,period,atr);TSTechSmooth(plus,period,true,ps);TSTechSmooth(minus,period,true,ms);
   for(int i=0;i<n;++i)if(TSTechNumber(atr[i])&&atr[i]>0.0&&TSTechNumber(ps[i])&&TSTechNumber(ms[i]))
     {plus_di[i]=100.0*ps[i]/atr[i];minus_di[i]=100.0*ms[i]/atr[i];double sum=plus_di[i]+minus_di[i];dx[i]=sum>0.0?100.0*MathAbs(plus_di[i]-minus_di[i])/sum:0.0;}
   TSTechSmooth(dx,period,true,adx);
  }

bool TSTechRange(const MqlRates &bars[],const int end,const int period,double &low,double &high)
  {
   if(period<=0||end<period-1||end>=ArraySize(bars))return false;
   low=bars[end-period+1].low;high=bars[end-period+1].high;
   for(int i=end-period+2;i<=end;++i){low=MathMin(low,bars[i].low);high=MathMax(high,bars[i].high);}return true;
  }

void TSTechStochastic(const MqlRates &bars[],const int period,double &k[],double &d[])
  {
   int n=ArraySize(bars);TSTechAllocate(k,n);
   for(int i=period-1;i<n;++i){double low=0.0,high=0.0;if(TSTechRange(bars,i,period,low,high)&&high>low)k[i]=100.0*(bars[i].close-low)/(high-low);}
   TSTechSMA(k,3,d);
  }

void TSTechCCI(const MqlRates &bars[],const int period,double &output[])
  {
   int n=ArraySize(bars);TSTechAllocate(output,n);double tp[];ArrayResize(tp,n);
   for(int i=0;i<n;++i)tp[i]=(bars[i].high+bars[i].low+bars[i].close)/3.0;
   for(int i=period-1;i<n;++i)
     {double mean=0.0,mad=0.0;for(int j=i-period+1;j<=i;++j)mean+=tp[j]/period;for(int j=i-period+1;j<=i;++j)mad+=MathAbs(tp[j]-mean)/period;if(mad>0.0)output[i]=(tp[i]-mean)/(0.015*mad);}
  }

// Filters out active/future bars even if a test adapter returns them.  Invalid
// or non-chronological OHLC are excluded and visible in snapshot diagnostics.
int TSTechCompleted(const MqlRates &source_bars[],const int seconds,const long t0_msc,MqlRates &output[],TSTechSnapshot &s)
  {
   ArrayResize(output,0);int total=ArraySize(source_bars),accepted=0;datetime previous=0;
   for(int i=MathMax(0,total-TS_TECH_BAR_CAPACITY-1);i<total;++i)
     {
      long close_msc=((long)source_bars[i].time+seconds)*1000;
      if(close_msc>t0_msc){++s.rejected_uncompleted_bars;continue;}
      if(source_bars[i].time<=0||source_bars[i].time<=previous||!MathIsValidNumber(source_bars[i].open)||!MathIsValidNumber(source_bars[i].high)||!MathIsValidNumber(source_bars[i].low)||!MathIsValidNumber(source_bars[i].close)||source_bars[i].low<=0.0||source_bars[i].high<source_bars[i].low||source_bars[i].open<source_bars[i].low||source_bars[i].open>source_bars[i].high||source_bars[i].close<source_bars[i].low||source_bars[i].close>source_bars[i].high)
        {++s.invalid_bar_count;continue;}
      previous=source_bars[i].time;ArrayResize(output,accepted+1);output[accepted++]=source_bars[i];
      if(close_msc>s.max_source_close_msc)s.max_source_close_msc=close_msc;
     }
   if(accepted>TS_TECH_BAR_CAPACITY)
     {for(int i=1;i<accepted;++i)output[i-1]=output[i];--accepted;ArrayResize(output,accepted);}
   return accepted;
  }

void TSTechAddMA(TSTechSnapshot &s,const string prefix,const double &close[],const double &atr[],const int period,const double current_mid)
  {
   double ema[],sma[],egap[],sgap[];TSTechSmooth(close,period,false,ema);TSTechSMA(close,period,sma);
   int n=ArraySize(close),j=n-1;TSTechAllocate(egap,n);TSTechAllocate(sgap,n);
   for(int i=0;i<n;++i){egap[i]=TSTechRatio(TSTechDifference(close[i],ema[i]),atr[i]);sgap[i]=TSTechRatio(TSTechDifference(close[i],sma[i]),atr[i]);}
   double a=TSTechAt(atr,j),e=TSTechAt(ema,j),m=TSTechAt(sma,j);
   string ep=prefix+"ema"+IntegerToString(period)+"_",mp=prefix+"sma"+IntegerToString(period)+"_";
   TSTechAdd(s,ep+"value",e);TSTechAdd(s,ep+"price_gap_atr",TSTechRatio(TSTechDifference(current_mid,e),a));
   TSTechAdd(s,ep+"close_gap_atr",TSTechAt(egap,j));
   TSTechAdd(s,ep+"slope1_atr",TSTechRatio(TSTechDifference(e,TSTechAt(ema,j-1)),a));
   TSTechAdd(s,ep+"slope3_atr",TSTechRatio(TSTechDifference(e,TSTechAt(ema,j-3)),a));
   TSTechAdd(s,ep+"accel_atr",TSTechRatio(TSTechDifference(TSTechDifference(e,TSTechAt(ema,j-1)),TSTechDifference(TSTechAt(ema,j-1),TSTechAt(ema,j-2))),a));
   TSTechAdd(s,ep+"gap_pct64",TSTechPercentile(egap,j));TSTechAdd(s,ep+"gap_z64",TSTechZScore(egap,j));
   TSTechAdd(s,ep+"sma_gap_atr",TSTechRatio(TSTechDifference(e,m),a));
   TSTechAdd(s,mp+"value",m);TSTechAdd(s,mp+"price_gap_atr",TSTechRatio(TSTechDifference(current_mid,m),a));
   TSTechAdd(s,mp+"slope1_atr",TSTechRatio(TSTechDifference(m,TSTechAt(sma,j-1)),a));
   TSTechAdd(s,mp+"slope3_atr",TSTechRatio(TSTechDifference(m,TSTechAt(sma,j-3)),a));
   TSTechAdd(s,mp+"gap_pct64",TSTechPercentile(sgap,j));
  }

double TSTechEfficiency(const double &close[],const int end,const int lookback)
  {
   if(end<lookback)return TSTechMissing();double path=0.0;
   for(int i=end-lookback+1;i<=end;++i)path+=MathAbs(close[i]-close[i-1]);
   return path>0.0?(close[end]-close[end-lookback])/path:TSTechMissing();
  }

void TSTechTimeframe(TSTechSnapshot &s,const MqlRates &bars[],const string prefix,const double mid,const double spread,const int shock_direction)
  {
   int n=ArraySize(bars),j=n-1;double close[],volume[],atr7[],atr14[],atr28[],volmean[];
   ArrayResize(close,n);ArrayResize(volume,n);for(int i=0;i<n;++i){close[i]=bars[i].close;volume[i]=(double)bars[i].tick_volume;}
   TSTechATR(bars,7,atr7);TSTechATR(bars,14,atr14);TSTechATR(bars,28,atr28);TSTechSMA(volume,20,volmean);
   double a=TSTechAt(atr14,j),c=TSTechAt(close,j);
   TSTechAdd(s,prefix+"atr7",TSTechAt(atr7,j));TSTechAdd(s,prefix+"atr14",a);TSTechAdd(s,prefix+"atr28",TSTechAt(atr28,j));
   TSTechAdd(s,prefix+"atr14_price",TSTechRatio(a,c));TSTechAdd(s,prefix+"atr7_atr28",TSTechRatio(TSTechAt(atr7,j),TSTechAt(atr28,j)));
   TSTechAdd(s,prefix+"atr14_pct64",TSTechPercentile(atr14,j));TSTechAdd(s,prefix+"atr14_z64",TSTechZScore(atr14,j));
   TSTechAdd(s,prefix+"atr14_change3",TSTechRatio(a,TSTechAt(atr14,j-3)));
   TSTechAdd(s,prefix+"spread_atr",TSTechRatio(spread,a));
   TSTechAdd(s,prefix+"tick_volume",TSTechAt(volume,j));TSTechAdd(s,prefix+"tick_volume_rel20",TSTechRatio(TSTechAt(volume,j),TSTechAt(volmean,j)));
   TSTechAdd(s,prefix+"tick_volume_pct64",TSTechPercentile(volume,j));
   TSTechAdd(s,prefix+"body_atr",n>0?TSTechRatio(bars[j].close-bars[j].open,a):TSTechMissing());
   TSTechAdd(s,prefix+"upper_wick_atr",n>0?TSTechRatio(bars[j].high-MathMax(bars[j].open,bars[j].close),a):TSTechMissing());
   TSTechAdd(s,prefix+"lower_wick_atr",n>0?TSTechRatio(MathMin(bars[j].open,bars[j].close)-bars[j].low,a):TSTechMissing());
   TSTechAdd(s,prefix+"bar_range_atr",n>0?TSTechRatio(bars[j].high-bars[j].low,a):TSTechMissing());
   TSTechAdd(s,prefix+"bar_close_location",n>0?TSTechRatio(bars[j].close-bars[j].low,bars[j].high-bars[j].low):TSTechMissing());
   const int periods[4]={5,10,20,50};for(int p=0;p<4;++p)TSTechAddMA(s,prefix,close,atr14,periods[p],mid);
   const int rsi_periods[3]={7,14,21};
   for(int p=0;p<3;++p)
     {
      double rsi[];TSTechRSI(close,rsi_periods[p],rsi);double value=TSTechAt(rsi,j);string key=prefix+"rsi"+IntegerToString(rsi_periods[p])+"_";
      TSTechAdd(s,key+"value",value);TSTechAdd(s,key+"centered",TSTechNumber(value)?(value-50.0)/50.0:TSTechMissing());
      TSTechAdd(s,key+"slope1",TSTechDifference(value,TSTechAt(rsi,j-1)));TSTechAdd(s,key+"slope3",TSTechDifference(value,TSTechAt(rsi,j-3)));TSTechAdd(s,key+"pct64",TSTechPercentile(rsi,j));
     }
   double fast[],slow[],macd[],signal[],hist[],histatr[];TSTechSmooth(close,12,false,fast);TSTechSmooth(close,26,false,slow);TSTechAllocate(macd,n);TSTechAllocate(hist,n);TSTechAllocate(histatr,n);
   for(int i=0;i<n;++i)macd[i]=TSTechDifference(fast[i],slow[i]);TSTechSmooth(macd,9,false,signal);
   for(int i=0;i<n;++i){hist[i]=TSTechDifference(macd[i],signal[i]);histatr[i]=TSTechRatio(hist[i],atr14[i]);}
   TSTechAdd(s,prefix+"macd_atr",TSTechRatio(TSTechAt(macd,j),a));TSTechAdd(s,prefix+"macd_signal_atr",TSTechRatio(TSTechAt(signal,j),a));
   TSTechAdd(s,prefix+"macd_hist_atr",TSTechAt(histatr,j));TSTechAdd(s,prefix+"macd_hist_slope1_atr",TSTechRatio(TSTechDifference(TSTechAt(hist,j),TSTechAt(hist,j-1)),a));TSTechAdd(s,prefix+"macd_hist_pct64",TSTechPercentile(histatr,j));
   double k[],d[],cci[];TSTechStochastic(bars,14,k,d);TSTechCCI(bars,20,cci);
   TSTechAdd(s,prefix+"stoch14_k",TSTechAt(k,j));TSTechAdd(s,prefix+"stoch14_d",TSTechAt(d,j));TSTechAdd(s,prefix+"stoch14_k_minus_d",TSTechDifference(TSTechAt(k,j),TSTechAt(d,j)));
   TSTechAdd(s,prefix+"williams14_r",TSTechNumber(TSTechAt(k,j))?TSTechAt(k,j)-100.0:TSTechMissing());TSTechAdd(s,prefix+"cci20",TSTechAt(cci,j));
   double adx[],pdi[],mdi[];TSTechADX(bars,14,adx,pdi,mdi);
   TSTechAdd(s,prefix+"adx14",TSTechAt(adx,j));TSTechAdd(s,prefix+"plus_di14",TSTechAt(pdi,j));TSTechAdd(s,prefix+"minus_di14",TSTechAt(mdi,j));TSTechAdd(s,prefix+"di_balance",TSTechDifference(TSTechAt(pdi,j),TSTechAt(mdi,j)));TSTechAdd(s,prefix+"adx14_slope3",TSTechDifference(TSTechAt(adx,j),TSTechAt(adx,j-3)));
   const int returns[5]={1,3,5,10,20};
   for(int p=0;p<5;++p)
     {int lag=returns[p];double prev=TSTechAt(close,j-lag);TSTechAdd(s,prefix+"roc"+IntegerToString(lag)+"_atr",TSTechRatio(TSTechDifference(c,prev),a));TSTechAdd(s,prefix+"roc"+IntegerToString(lag)+"_pct",TSTechNumber(prev)&&prev>0.0&&TSTechNumber(c)?100.0*(c/prev-1.0):TSTechMissing());}
   const int ranges[3]={5,20,60};
   for(int p=0;p<3;++p)
     {
      int period=ranges[p];double low=0.0,high=0.0;bool valid=TSTechRange(bars,j,period,low,high);string key=prefix+"range"+IntegerToString(period)+"_";
      TSTechAdd(s,key+"width_atr",valid?TSTechRatio(high-low,a):TSTechMissing());TSTechAdd(s,key+"position",valid?TSTechRatio(TSTechDifference(mid,low),high-low):TSTechMissing());
      TSTechAdd(s,key+"high_distance_atr",valid?TSTechRatio(TSTechDifference(high,mid),a):TSTechMissing());TSTechAdd(s,key+"low_distance_atr",valid?TSTechRatio(TSTechDifference(mid,low),a):TSTechMissing());
      TSTechAdd(s,key+"signed_efficiency",TSTechEfficiency(close,j,period));
      double rv=TSTechMissing();if(j>=period){double square=0.0;for(int i=j-period+1;i<=j;++i){double lr=MathLog(close[i]/close[i-1]);square+=lr*lr;}rv=MathSqrt(square/period);}
      TSTechAdd(s,prefix+"realized_vol"+IntegerToString(period),rv);TSTechAdd(s,prefix+"realized_vol"+IntegerToString(period)+"_atr",TSTechRatio(TSTechProduct(rv,c),a));
     }
   double sma20[];TSTechSMA(close,20,sma20);double sd=TSTechMissing();
   if(j>=19){double variance=0.0,mean=sma20[j];for(int i=j-19;i<=j;++i)variance+=(close[i]-mean)*(close[i]-mean)/20.0;sd=MathSqrt(variance);}
   TSTechAdd(s,prefix+"bb20_width_atr",TSTechNumber(sd)?TSTechRatio(4.0*sd,a):TSTechMissing());TSTechAdd(s,prefix+"bb20_price_z",TSTechRatio(TSTechDifference(mid,TSTechAt(sma20,j)),sd));
   TSTechAdd(s,prefix+"bb20_position",TSTechNumber(sd)&&sd>0.0&&TSTechNumber(mid)?(mid-sma20[j]+2.0*sd)/(4.0*sd):TSTechMissing());
   int consecutive=0;if(n>0){int last=bars[j].close>bars[j].open?1:(bars[j].close<bars[j].open?-1:0);for(int i=j;i>=0&&i>j-20;--i){int dir=bars[i].close>bars[i].open?1:(bars[i].close<bars[i].open?-1:0);if(dir!=last||last==0)break;consecutive+=last;}}
   TSTechAdd(s,prefix+"consecutive_signed_bars",n>0?(double)consecutive:TSTechMissing());
   double e5=TSTechValue(s,prefix+"ema5_value"),e10=TSTechValue(s,prefix+"ema10_value"),e20=TSTechValue(s,prefix+"ema20_value"),e50=TSTechValue(s,prefix+"ema50_value");
   TSTechAdd(s,prefix+"ema5_20_gap_atr",TSTechRatio(TSTechDifference(e5,e20),a));TSTechAdd(s,prefix+"ema10_20_gap_atr",TSTechRatio(TSTechDifference(e10,e20),a));TSTechAdd(s,prefix+"ema20_50_gap_atr",TSTechRatio(TSTechDifference(e20,e50),a));
   double align=TSTechNumber(e5)&&TSTechNumber(e10)&&TSTechNumber(e20)&&TSTechNumber(e50)?((e5>e10&&e10>e20&&e20>e50)?1.0:((e5<e10&&e10<e20&&e20<e50)?-1.0:0.0)):TSTechMissing();
   TSTechAdd(s,prefix+"ema_alignment",align);
   double rsi=TSTechValue(s,prefix+"rsi14_centered"),gap=TSTechValue(s,prefix+"ema20_price_gap_atr"),strength=TSTechAt(adx,j);
   TSTechAdd(s,prefix+"ema_alignment_x_rsi14",TSTechProduct(align,rsi));TSTechAdd(s,prefix+"ema20_gap_x_rsi14",TSTechProduct(gap,rsi));
   TSTechAdd(s,prefix+"rsi14_x_adx14",TSTechNumber(strength)?TSTechProduct(rsi,strength/100.0):TSTechMissing());
   TSTechAdd(s,prefix+"macd_hist_x_atr_expansion",TSTechProduct(TSTechAt(histatr,j),TSTechValue(s,prefix+"atr7_atr28")));
   TSTechAdd(s,prefix+"ema20_slope_x_adx",TSTechNumber(strength)?TSTechProduct(TSTechValue(s,prefix+"ema20_slope3_atr"),strength/100.0):TSTechMissing());
   TSTechAdd(s,prefix+"body_x_tick_activity",TSTechProduct(TSTechValue(s,prefix+"body_atr"),TSTechValue(s,prefix+"tick_volume_rel20")));
   const string oriented[7]={"ema20_price_gap_atr","ema20_50_gap_atr","rsi14_centered","macd_hist_atr","di_balance","roc5_atr","range20_signed_efficiency"};
   for(int i=0;i<7;++i)TSTechAdd(s,prefix+"shock_x_"+oriented[i],shock_direction==1||shock_direction==-1?TSTechProduct((double)shock_direction,TSTechValue(s,prefix+oriented[i])):TSTechMissing());
  }

// This function is the production seam used by synthetic tests and the EA.
// No terminal, file, clock, input, position or global dependency exists here.
bool TSTechBuildFromBars(const MqlRates &m1_input[],const MqlRates &m5_input[],const MqlRates &m15_input[],const long t0_msc,const long quote_msc,const double mid,const double spread,const int shock_direction,TSTechSnapshot &s)
  {
   ZeroMemory(s);s.t0_msc=t0_msc;s.quote_msc=quote_msc;
   MqlRates m1[],m5[],m15[];s.m1_bars=TSTechCompleted(m1_input,60,t0_msc,m1,s);s.m5_bars=TSTechCompleted(m5_input,300,t0_msc,m5,s);s.m15_bars=TSTechCompleted(m15_input,900,t0_msc,m15,s);
   bool quote_valid=quote_msc>0&&quote_msc<=t0_msc&&TSTechNumber(mid)&&mid>0.0&&TSTechNumber(spread)&&spread>=0.0;
   if(quote_msc>t0_msc)++s.future_source_count;
   double causal_mid=quote_valid?mid:TSTechMissing(),causal_spread=quote_valid?spread:TSTechMissing();
   TSTechAdd(s,"quote_mid",causal_mid);TSTechAdd(s,"quote_spread",causal_spread);TSTechAdd(s,"shock_direction",shock_direction==1||shock_direction==-1?(double)shock_direction:TSTechMissing());
   TSTechTimeframe(s,m1,"m1_",causal_mid,causal_spread,shock_direction);TSTechTimeframe(s,m5,"m5_",causal_mid,causal_spread,shock_direction);TSTechTimeframe(s,m15,"m15_",causal_mid,causal_spread,shock_direction);
   const string left[3]={"m1_","m1_","m5_"},right[3]={"m5_","m15_","m15_"};
   for(int p=0;p<3;++p)
     {
      string key=left[p]+right[p];double a=TSTechValue(s,left[p]+"ema_alignment"),b=TSTechValue(s,right[p]+"ema_alignment");
      TSTechAdd(s,key+"alignment_product",TSTechProduct(a,b));TSTechAdd(s,key+"rsi14_difference",TSTechDifference(TSTechValue(s,left[p]+"rsi14_value"),TSTechValue(s,right[p]+"rsi14_value")));
      TSTechAdd(s,key+"ema20_slope_product",TSTechProduct(TSTechValue(s,left[p]+"ema20_slope3_atr"),TSTechValue(s,right[p]+"ema20_slope3_atr")));
      TSTechAdd(s,key+"macd_hist_product",TSTechProduct(TSTechValue(s,left[p]+"macd_hist_atr"),TSTechValue(s,right[p]+"macd_hist_atr")));
      TSTechAdd(s,key+"atr_ratio",TSTechRatio(TSTechValue(s,left[p]+"atr14"),TSTechValue(s,right[p]+"atr14")));
      TSTechAdd(s,key+"rsi_x_trend",TSTechProduct(TSTechValue(s,left[p]+"rsi14_centered"),b));
     }
   double a1=TSTechValue(s,"m1_atr14"),a5=TSTechValue(s,"m5_atr14"),a15=TSTechValue(s,"m15_atr14");
   s.atr14_m1=TSTechNumber(a1)?a1:0.0;s.atr14_m5=TSTechNumber(a5)?a5:0.0;s.atr14_m15=TSTechNumber(a15)?a15:0.0;
   return !s.overflow&&s.future_source_count==0&&s.invalid_bar_count==0&&quote_valid&&s.atr14_m5>0.0;
  }

int TSTechReadCompletedBars(const string symbol,const ENUM_TIMEFRAMES timeframe,const long t0_msc,MqlRates &bars[])
  {
   ArraySetAsSeries(bars,false);ArrayResize(bars,0);if(t0_msc<=0)return 0;
   // CopyRates may include the bar containing t0. The pure builder excludes it.
   int copied=CopyRates(symbol,timeframe,(datetime)(t0_msc/1000),TS_TECH_BAR_CAPACITY+1,bars);
   if(copied<0){ArrayResize(bars,0);return 0;}return copied;
  }

bool TSTechCapture(const string symbol,const long t0_msc,const long quote_msc,const double mid,const double spread,const int shock_direction,TSTechSnapshot &s)
  {
   MqlRates m1[],m5[],m15[];TSTechReadCompletedBars(symbol,PERIOD_M1,t0_msc,m1);TSTechReadCompletedBars(symbol,PERIOD_M5,t0_msc,m5);TSTechReadCompletedBars(symbol,PERIOD_M15,t0_msc,m15);
   return TSTechBuildFromBars(m1,m5,m15,t0_msc,quote_msc,mid,spread,shock_direction,s);
  }

string TSTechNamesCsv(const TSTechSnapshot &s)
  {string row="";for(int i=0;i<s.count;++i){if(i>0)row+=",";row+=s.names[i];}return row;}
string TSTechValuesCsv(const TSTechSnapshot &s)
  {string row="";for(int i=0;i<s.count;++i){if(i>0)row+=",";if(s.available[i])row+=DoubleToString(s.values[i],12);}return row;}
string TSTechSchemaNamesCsv()
  {MqlRates empty[];TSTechSnapshot s;TSTechBuildFromBars(empty,empty,empty,0,0,0.0,0.0,0,s);return TSTechNamesCsv(s);}

#endif
