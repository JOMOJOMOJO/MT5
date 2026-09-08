#property strict
#property version "1.00"
#include "..\..\Include\TickShock\TickShockTechnicalFeatures.mqh"

input string InpOutputFolder="tick_shock_technical_discovery";
int g_tech_pass=0,g_tech_fail=0,g_tech_file=INVALID_HANDLE;

void TechCheck(const bool ok,const string id,const string actual)
  {
   string status=ok?"PASS":"FAIL";if(ok)++g_tech_pass;else ++g_tech_fail;
   if(g_tech_file!=INVALID_HANDLE)FileWrite(g_tech_file,id,status,actual);
   Print("TSTech ",id," ",status," ",actual);
  }
bool TechNear(const double actual,const double expected,const double tolerance=1e-9)
  {return TSTechNumber(actual)&&MathAbs(actual-expected)<=tolerance;}

void TechBars(MqlRates &bars[],const int count,const int seconds,const long end_msc,const bool flat=false)
  {
   ArrayResize(bars,count);for(int i=0;i<count;++i)
     {
      ZeroMemory(bars[i]);bars[i].time=(datetime)(end_msc/1000-(long)(count-i)*seconds);
      bars[i].close=flat?100.0:100.0+i;bars[i].open=flat?100.0:bars[i].close-0.25;
      bars[i].high=bars[i].close+1.0;bars[i].low=bars[i].close-1.0;bars[i].tick_volume=100+i;bars[i].spread=10;
     }
  }
void TechReflect(const MqlRates &source[],MqlRates &target[])
  {
   int n=ArraySize(source);ArrayResize(target,n);for(int i=0;i<n;++i)
     {target[i]=source[i];target[i].open=1000.0-source[i].open;target[i].close=1000.0-source[i].close;target[i].high=1000.0-source[i].low;target[i].low=1000.0-source[i].high;}
  }

int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER)){Print("Technical feature harness requires MQL_TESTER");return INIT_FAILED;}
   FolderCreate(InpOutputFolder,FILE_COMMON);g_tech_file=FileOpen(InpOutputFolder+"\\technical_features_harness.csv",FILE_COMMON|FILE_WRITE|FILE_CSV,',');
   if(g_tech_file==INVALID_HANDLE)return INIT_FAILED;FileWrite(g_tech_file,"test_id","status","actual");
   const long t0=1800000000000;MqlRates m1[],m5[],m15[];TechBars(m1,256,60,t0);TechBars(m5,256,300,t0);TechBars(m15,256,900,t0);
   TSTechSnapshot up;bool built=TSTechBuildFromBars(m1,m5,m15,t0,t0-1,355.25,0.02,1,up);
   TechCheck(built&&!up.overflow&&up.count>400&&up.count<=600,"TECH-SCHEMA-CAPACITY",StringFormat("count=%d available=%d",up.count,up.available_count));
   bool unique=true;for(int i=0;i<up.count;++i)for(int j=i+1;j<up.count;++j)if(up.names[i]==up.names[j])unique=false;
   TechCheck(unique,"TECH-SCHEMA-UNIQUE",IntegerToString(up.count));
   TechCheck(TSTechNamesCsv(up)==TSTechSchemaNamesCsv(),"TECH-SCHEMA-MISSING-STABLE","populated and empty names identical");
   TechCheck(TechNear(TSTechValue(up,"m1_sma5_value"),353.0),"TECH-SMA5-ORACLE",DoubleToString(TSTechValue(up,"m1_sma5_value"),10));
   TechCheck(TechNear(TSTechValue(up,"m1_ema20_value"),345.5),"TECH-EMA20-ORACLE",DoubleToString(TSTechValue(up,"m1_ema20_value"),10));
   TechCheck(TechNear(up.atr14_m1,2.0)&&TechNear(up.atr14_m5,2.0),"TECH-ATR-WILDER-ORACLE",DoubleToString(up.atr14_m5,10));
   TechCheck(TechNear(TSTechValue(up,"m1_rsi14_value"),100.0),"TECH-RSI-UP-ORACLE",DoubleToString(TSTechValue(up,"m1_rsi14_value"),10));
   TechCheck(TechNear(TSTechValue(up,"m1_ema20_slope3_atr"),1.5),"TECH-SLOPE-ORACLE",DoubleToString(TSTechValue(up,"m1_ema20_slope3_atr"),10));
   TechCheck(TechNear(TSTechValue(up,"m1_adx14"),100.0),"TECH-ADX-ORACLE",DoubleToString(TSTechValue(up,"m1_adx14"),10));
   TechCheck(TechNear(TSTechValue(up,"m1_macd_atr"),3.5)&&TechNear(TSTechValue(up,"m1_macd_hist_atr"),0.0),"TECH-MACD-ORACLE",DoubleToString(TSTechValue(up,"m1_macd_atr"),10));
   TechCheck(up.max_source_close_msc==t0&&up.future_source_count==0&&up.m1_bars==256,"TECH-COMPLETED-EQUAL",StringFormat("source=%I64d t0=%I64d",up.max_source_close_msc,t0));
   TSTechSnapshot before,after;TSTechBuildFromBars(m1,m5,m15,t0-1,t0-2,354.25,0.02,1,before);TSTechBuildFromBars(m1,m5,m15,t0+1,t0,355.25,0.02,1,after);
   TechCheck(before.m1_bars==255&&before.max_source_close_msc==t0-60000&&before.rejected_uncompleted_bars==3,"TECH-COMPLETED-MINUS1",StringFormat("bars=%d rejected=%d",before.m1_bars,before.rejected_uncompleted_bars));
   TechCheck(after.m1_bars==256&&after.max_source_close_msc==t0,"TECH-COMPLETED-PLUS1",StringFormat("bars=%d source=%I64d",after.m1_bars,after.max_source_close_msc));
   MqlRates changed[];ArrayCopy(changed,m1);changed[255].open=5000.0;changed[255].close=5000.0;changed[255].high=6000.0;changed[255].low=4000.0;
   TSTechSnapshot changed_future;TSTechBuildFromBars(changed,m5,m15,t0-1,t0-2,354.25,0.02,1,changed_future);
   TechCheck(TSTechValuesCsv(before)==TSTechValuesCsv(changed_future),"TECH-FUTURE-BAR-MUTATION","uncompleted bar cannot change any feature");
   TSTechSnapshot bad_quote;bool quote_ok=TSTechBuildFromBars(m1,m5,m15,t0,t0+1,355.25,0.02,1,bad_quote);
   TechCheck(!quote_ok&&bad_quote.future_source_count==1&&!TSTechNumber(TSTechValue(bad_quote,"quote_mid"))&&!TSTechNumber(TSTechValue(bad_quote,"m1_ema20_price_gap_atr")),"TECH-FUTURE-QUOTE-REJECT","future quote is unavailable and build invalid");
   MqlRates down1[],down5[],down15[];TechReflect(m1,down1);TechReflect(m5,down5);TechReflect(m15,down15);TSTechSnapshot down;
   TSTechBuildFromBars(down1,down5,down15,t0,t0-1,644.75,0.02,-1,down);
   TechCheck(TechNear(TSTechValue(down,"m1_rsi14_value"),0.0)&&TechNear(TSTechValue(up,"m1_ema20_price_gap_atr"),-TSTechValue(down,"m1_ema20_price_gap_atr")),"TECH-LONG-SHORT-SYMMETRY","RSI and normalized EMA distance reflected");
   TechCheck(TechNear(TSTechValue(up,"m1_shock_x_rsi14_centered"),TSTechValue(down,"m1_shock_x_rsi14_centered"))&&TechNear(TSTechValue(up,"m1_shock_x_ema20_price_gap_atr"),TSTechValue(down,"m1_shock_x_ema20_price_gap_atr")),"TECH-SHOCK-INTERACTION-SYMMETRY","shock-relative features invariant under reflection");
   TechCheck(TechNear(TSTechValue(up,"m1_plus_di14"),TSTechValue(down,"m1_minus_di14"))&&TechNear(TSTechValue(up,"m1_stoch14_k")+TSTechValue(down,"m1_stoch14_k"),100.0),"TECH-DI-STOCH-SYMMETRY","DI swaps; stochastic reflected around 50");
   MqlRates flat1[],flat5[],flat15[];TechBars(flat1,256,60,t0,true);TechBars(flat5,256,300,t0,true);TechBars(flat15,256,900,t0,true);TSTechSnapshot flat;
   TSTechBuildFromBars(flat1,flat5,flat15,t0,t0-1,100.0,0.02,1,flat);
   TechCheck(TechNear(TSTechValue(flat,"m1_rsi14_value"),50.0)&&TechNear(TSTechValue(flat,"m1_adx14"),0.0),"TECH-FLAT-RSI-ADX","RSI=50; ADX=0");
   TechCheck(!TSTechNumber(TSTechValue(flat,"m1_bb20_price_z"))&&TechNear(TSTechValue(flat,"m1_ema20_price_gap_atr"),0.0),"TECH-BLANK-NOT-ZERO","zero standard deviation missing; genuine price gap zero valid");
   MqlRates empty[];TSTechSnapshot missing;bool empty_ok=TSTechBuildFromBars(empty,empty,empty,t0,t0-1,100.0,0.02,1,missing);
   TechCheck(!empty_ok&&missing.count==up.count&&missing.available_count==3&&StringFind(TSTechValuesCsv(missing),",,")>=0,"TECH-MISSING-SERIALIZATION",StringFormat("available=%d",missing.available_count));
   MqlRates many1[],many5[],many15[];TechBars(many1,400,60,t0);TechBars(many5,400,300,t0);TechBars(many15,400,900,t0);TSTechSnapshot capped;
   TSTechBuildFromBars(many1,many5,many15,t0,t0-1,499.25,0.02,1,capped);
   TechCheck(capped.m1_bars==256&&capped.m5_bars==256&&capped.m15_bars==256,"TECH-PHYSICAL-BAR-CAPACITY",StringFormat("%d/%d/%d",capped.m1_bars,capped.m5_bars,capped.m15_bars));
   TSTechSnapshot invalid_direction;TSTechBuildFromBars(m1,m5,m15,t0,t0-1,355.25,0.02,0,invalid_direction);
   TechCheck(!TSTechNumber(TSTechValue(invalid_direction,"shock_direction"))&&!TSTechNumber(TSTechValue(invalid_direction,"m1_shock_x_rsi14_centered")),"TECH-DIRECTION-ZERO-MISSING","direction zero not SHORT");
   double rankings[22];for(int i=0;i<22;++i)rankings[i]=(double)i;
   TechCheck(TechNear(TSTechPercentile(rankings,21),1.0),"TECH-PERCENTILE-ORACLE","21 greater than every historical 0..20");
   FileWrite(g_tech_file,"TOTAL",g_tech_fail==0?"PASS":"FAIL",StringFormat("PASS=%d;FAIL=%d;FEATURES=%d",g_tech_pass,g_tech_fail,up.count));
   FileClose(g_tech_file);g_tech_file=INVALID_HANDLE;PrintFormat("Technical features harness PASS=%d FAIL=%d features=%d",g_tech_pass,g_tech_fail,up.count);
   return g_tech_fail==0?INIT_SUCCEEDED:INIT_FAILED;
  }
void OnTick(){}
void OnDeinit(const int reason){if(g_tech_file!=INVALID_HANDLE)FileClose(g_tech_file);}
