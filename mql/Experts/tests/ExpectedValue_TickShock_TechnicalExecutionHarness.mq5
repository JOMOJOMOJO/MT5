#property strict
#include "..\..\Include\TickShock\TickShockTechnicalStudy.mqh"

// Deterministic production-path checks. Values below are independent, literal
// hand calculations for EURUSD: ATR .004, tick .00001, pip .0001, spread .0001.
// The .25 ATR geometry therefore has distance .001 = 10 pips.
int g_te_pass=0,g_te_fail=0,g_te_file=INVALID_HANDLE;
string g_te_folder="tick_shock_technical_execution_harness";

bool TENear(const double actual,const double expected,const double tolerance=1e-9)
  {return MathIsValidNumber(actual)&&MathAbs(actual-expected)<=tolerance;}

void TECheck(const string id,const bool ok,const string expected,const string actual)
  {
   string status=ok?"PASS":"FAIL";
   if(ok)++g_te_pass;else ++g_te_fail;
   if(g_te_file!=INVALID_HANDLE)FileWrite(g_te_file,id,status,expected,actual);
   PrintFormat("%s %s expected=%s actual=%s",status,id,expected,actual);
  }

TSTDRecord TEBase(const string id)
  {
   TSTDRecord r;ZeroMemory(r);r.active=true;r.episode_id=id;r.symbol="EURUSD";r.cluster=7;
   r.t0=100000;r.quote=99900;r.processing=100600;r.eligible=100600;
   r.atr=.004;r.pip=.0001;r.tick=.00001;r.stops=0.0;
   return r;
  }

void TEEnter(TSTDRecord &r)
  {TSTDAdvance(r,100600,1.10000,1.10010);}

void TETestCausality()
  {
   TSTDRecord r=TEBase("TE-TIME");
   TSTDAdvance(r,100000,1.10000,1.10010);
   TECheck("TSTE-TIME-T0",!r.entered,"not entered at t0",(string)r.entry_msc);
   TSTDAdvance(r,100599,1.10000,1.10010);
   TECheck("TSTE-TIME-BEFORE-PROCESSING",!r.entered,"not entered before 100600",(string)r.entry_msc);
   TSTDAdvance(r,100600,1.10000,1.10010);
   TECheck("TSTE-TIME-PROCESSING-EQUALITY",r.entered&&r.entry_msc==100600,"entry 100600",(string)r.entry_msc);
   TECheck("TSTE-ENTRY-BID-ASK",TENear(r.entry_bid,1.10000)&&TENear(r.entry_ask,1.10010),"bid 1.10000 ask 1.10010",DoubleToString(r.entry_bid,5)+"/"+DoubleToString(r.entry_ask,5));
   TSTDAdvance(r,100600,1.10110,1.10120);
   TECheck("TSTE-SAME-ENTRY-MILLISECOND",r.barrier[0].status=="OPEN"&&r.barrier[TSTD_DISTANCES].status=="OPEN","both OPEN",r.barrier[0].status+"/"+r.barrier[TSTD_DISTANCES].status);
   TSTDAdvance(r,100599,1.10110,1.10120);
   TECheck("TSTE-OUT-OF-ORDER-QUOTE",r.barrier[0].status=="OPEN","OPEN after older quote",r.barrier[0].status);

   TSTDRecord latency=TEBase("TE-LATENCY");latency.eligible=100850;
   TSTDAdvance(latency,100849,1.10000,1.10010);
   TECheck("TSTE-LATENCY-BELOW",!latency.entered,"not entered before 100850",(string)latency.entry_msc);
   TSTDAdvance(latency,100850,1.10000,1.10010);
   TECheck("TSTE-LATENCY-EQUAL",latency.entry_msc==100850,"entry 100850",(string)latency.entry_msc);

   TSTDRecord source=TEBase("TE-SOURCE");source.quote=100600;
   TSTDAdvance(source,100600,1.10000,1.10010);
   TECheck("TSTE-SOURCE-QUOTE-EXCLUDED",!source.entered,"not entered at source quote",(string)source.entry_msc);
   TSTDAdvance(source,100601,1.10000,1.10010);
   TECheck("TSTE-SOURCE-QUOTE-NEXT",source.entry_msc==100601,"entry 100601",(string)source.entry_msc);
  }

void TETestGeometryAndBarriers()
  {
   TSTDRecord direct=TEBase("TE-DIRECT");TSTDEnter(direct,100600,1.10000,1.10010);
   TECheck("TSTE-GEOMETRY-LONG",TENear(direct.barrier[0].distance,.001)&&TENear(direct.barrier[0].sl,1.09910)&&TENear(direct.barrier[0].tp,1.10110),"distance .001 SL 1.09910 TP 1.10110",DoubleToString(direct.barrier[0].distance,5)+"/"+DoubleToString(direct.barrier[0].sl,5)+"/"+DoubleToString(direct.barrier[0].tp,5));
   TECheck("TSTE-GEOMETRY-SHORT",TENear(direct.barrier[TSTD_DISTANCES].sl,1.10100)&&TENear(direct.barrier[TSTD_DISTANCES].tp,1.09900),"SL 1.10100 TP 1.09900",DoubleToString(direct.barrier[TSTD_DISTANCES].sl,5)+"/"+DoubleToString(direct.barrier[TSTD_DISTANCES].tp,5));
   TSTDRecord rounding=TEBase("TE-ROUND");rounding.atr=.00401;TEEnter(rounding);
   TECheck("TSTE-OUTWARD-DISTANCE",TENear(rounding.barrier[0].distance,.00101),".00101",DoubleToString(rounding.barrier[0].distance,8));

   TSTDRecord long_tp=TEBase("TE-LONG-TP");TEEnter(long_tp);
   TSTDAdvance(long_tp,100700,1.10109,1.10119);
   TECheck("TSTE-LONG-TP-ONE-TICK-BELOW",long_tp.barrier[0].status=="OPEN","OPEN",long_tp.barrier[0].status);
   TSTDAdvance(long_tp,100701,1.10110,1.10120);
   TECheck("TSTE-LONG-TP-BID",long_tp.barrier[0].status=="TP"&&TENear(long_tp.barrier[0].exit_price,1.10110)&&TENear(long_tp.barrier[0].gross_r,1.0)&&TENear(long_tp.barrier[0].gross_pips,10.0),"TP exit 1.10110 R 1 pips 10",long_tp.barrier[0].status+"/"+DoubleToString(long_tp.barrier[0].gross_r,8));
   TSTDRecord short_tp=TEBase("TE-SHORT-TP");TEEnter(short_tp);
   TSTDAdvance(short_tp,100700,1.09891,1.09901);
   TECheck("TSTE-SHORT-TP-ONE-TICK-ABOVE",short_tp.barrier[TSTD_DISTANCES].status=="OPEN","OPEN",short_tp.barrier[TSTD_DISTANCES].status);
   TSTDAdvance(short_tp,100701,1.09890,1.09900);
   TECheck("TSTE-SHORT-TP-ASK",short_tp.barrier[TSTD_DISTANCES].status=="TP"&&TENear(short_tp.barrier[TSTD_DISTANCES].exit_price,1.09900)&&TENear(short_tp.barrier[TSTD_DISTANCES].gross_r,1.0),"TP exit 1.09900 R 1",short_tp.barrier[TSTD_DISTANCES].status+"/"+DoubleToString(short_tp.barrier[TSTD_DISTANCES].gross_r,8));

   TSTDRecord long_gap=TEBase("TE-LONG-GAP");TEEnter(long_gap);TSTDAdvance(long_gap,100700,1.09890,1.09900);
   TECheck("TSTE-LONG-SL-GAP",long_gap.barrier[0].status=="SL"&&TENear(long_gap.barrier[0].exit_price,1.09890)&&TENear(long_gap.barrier[0].gross_r,-1.2),"SL bid 1.09890 R -1.2",long_gap.barrier[0].status+"/"+DoubleToString(long_gap.barrier[0].gross_r,8));
   TSTDRecord short_gap=TEBase("TE-SHORT-GAP");TEEnter(short_gap);TSTDAdvance(short_gap,100700,1.10110,1.10120);
   TECheck("TSTE-SHORT-SL-GAP",short_gap.barrier[TSTD_DISTANCES].status=="SL"&&TENear(short_gap.barrier[TSTD_DISTANCES].exit_price,1.10120)&&TENear(short_gap.barrier[TSTD_DISTANCES].gross_r,-1.2),"SL ask 1.10120 R -1.2",short_gap.barrier[TSTD_DISTANCES].status+"/"+DoubleToString(short_gap.barrier[TSTD_DISTANCES].gross_r,8));
   TSTDRecord limit=TEBase("TE-LIMIT");TEEnter(limit);TSTDAdvance(limit,100700,1.10150,1.10160);
   TECheck("TSTE-TP-LIMIT-NO-POSITIVE-GAP",limit.barrier[0].status=="TP"&&TENear(limit.barrier[0].exit_price,1.10110)&&TENear(limit.barrier[0].gross_r,1.0),"TP at limit R 1",DoubleToString(limit.barrier[0].exit_price,5)+"/"+DoubleToString(limit.barrier[0].gross_r,8));
  }

void TETestRejections()
  {
   TSTDRecord spread=TEBase("TE-SPREAD");spread.atr=.0012;TSTDEnter(spread,100600,1.10000,1.10011);
   TECheck("TSTE-SPREAD-REJECT",spread.barrier[0].status=="COST_DISTANCE_REJECT"&&spread.barrier[TSTD_DISTANCES].status=="COST_DISTANCE_REJECT","both COST_DISTANCE_REJECT",spread.barrier[0].status+"/"+spread.barrier[TSTD_DISTANCES].status);
   TSTDRecord equal=TEBase("TE-SPREAD-EQUAL");equal.atr=.0012;TSTDEnter(equal,100600,1.10000,1.10010);
   TECheck("TSTE-SPREAD-EQUALITY",equal.barrier[0].status=="OPEN"&&equal.barrier[TSTD_DISTANCES].status=="OPEN","distance .0003 == 3 spread: OPEN",equal.barrier[0].status+"/"+equal.barrier[TSTD_DISTANCES].status);
   TSTDRecord broker=TEBase("TE-BROKER");broker.stops=.00095;TEEnter(broker);
   TECheck("TSTE-BROKER-LONG-BID",broker.barrier[0].status=="BROKER_DISTANCE_REJECT","bid-SL .00090 < .00095",broker.barrier[0].status);
   TECheck("TSTE-BROKER-SHORT-ASK",broker.barrier[TSTD_DISTANCES].status=="BROKER_DISTANCE_REJECT","SL-ask .00090 < .00095",broker.barrier[TSTD_DISTANCES].status);
   TSTDRecord broker_equal=TEBase("TE-BROKER-EQUAL");broker_equal.stops=.00090;TEEnter(broker_equal);
   TECheck("TSTE-BROKER-EQUALITY",broker_equal.barrier[0].status=="OPEN"&&broker_equal.barrier[TSTD_DISTANCES].status=="OPEN","both OPEN at .00090",broker_equal.barrier[0].status+"/"+broker_equal.barrier[TSTD_DISTANCES].status);
  }

void TETestTimeAndSerialization()
  {
   TSTDRecord timed=TEBase("TE-TIMEOUT");TEEnter(timed);TSTDAdvance(timed,1000600,1.10000,1.10010);
   TECheck("TSTE-LONG-TIME",timed.barrier[0].status=="TIME"&&TENear(timed.barrier[0].gross_r,-.1)&&timed.barrier[0].exit_msc==1000600,"TIME at 900 seconds R -.1",timed.barrier[0].status+"/"+DoubleToString(timed.barrier[0].gross_r,8));
   TECheck("TSTE-SHORT-TIME",timed.barrier[TSTD_DISTANCES].status=="TIME"&&TENear(timed.barrier[TSTD_DISTANCES].gross_r,-.1),"TIME R -.1",timed.barrier[TSTD_DISTANCES].status+"/"+DoubleToString(timed.barrier[TSTD_DISTANCES].gross_r,8));
   TSTDRecord deadline_tp=TEBase("TE-DEADLINE-TP");TEEnter(deadline_tp);TSTDAdvance(deadline_tp,1000600,1.10110,1.10120);
   TECheck("TSTE-DEADLINE-BARRIER-PRIORITY",deadline_tp.barrier[0].status=="TP","TP takes priority on exact deadline",deadline_tp.barrier[0].status);
   TSTDRecord path=TEBase("TE-PATH");TEEnter(path);TSTDAdvance(path,160600,1.10050,1.10060);TSTDAdvance(path,400600,1.10030,1.10040);TSTDAdvance(path,1000600,1.10000,1.10010);
   TECheck("TSTE-CAUSAL-PATH-CHECKPOINTS",path.checkpoints[0]&&path.checkpoints[1]&&path.checkpoints[2]&&TENear(path.path_mfe[0],.0004)&&TENear(path.path_mae[1],.0006)&&TENear(path.path_mfe[4],.0004),"60/300/900 checkpoints MFE long .0004 MAE short .0006",DoubleToString(path.path_mfe[0],6)+"/"+DoubleToString(path.path_mae[1],6)+"/"+DoubleToString(path.path_mfe[4],6));
   TSTDRecord noentry=TEBase("TE-NOENTRY");TSTDAdvance(noentry,130001,1.10000,1.10010);
   TECheck("TSTE-ENTRY-WAIT-EXPIRES",!noentry.active&&!noentry.entered,"NO_ENTRY after 30 seconds",(string)noentry.active+"/"+(string)noentry.entered);
   FileFlush(g_tstd_outcomes);FileClose(g_tstd_outcomes);g_tstd_outcomes=INVALID_HANDLE;
   int read_handle=FileOpen(g_te_folder+"\\technical_outcomes.csv",FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
   if(read_handle==INVALID_HANDLE){TECheck("TSTE-SERIALIZATION-READ",false,"read outcomes","FileOpen failed");return;}
   string header=FileReadString(read_handle),names[];int columns=StringSplit(header,',',names);
   int entry_col=-1,processing_col=-1,eligible_col=-1,source_col=-1,status_col=-1,tp_col=-1,sl_col=-1,pips_col=-1,r_col=-1;
   for(int i=0;i<columns;++i){if(names[i]=="entry_msc")entry_col=i;else if(names[i]=="signal_processing_msc")processing_col=i;else if(names[i]=="entry_eligible_msc")eligible_col=i;else if(names[i]=="source_quote_msc")source_col=i;else if(names[i]=="status")status_col=i;else if(names[i]=="tp_touch_seconds")tp_col=i;else if(names[i]=="sl_touch_seconds")sl_col=i;else if(names[i]=="gross_pips")pips_col=i;else if(names[i]=="gross_r")r_col=i;}
   bool schema=entry_col>=0&&processing_col>=0&&eligible_col>=0&&source_col>=0&&status_col>=0&&tp_col>=0&&sl_col>=0&&pips_col>=0&&r_col>=0;
   TECheck("TSTE-OUTPUT-QA-COLUMNS",schema,"clocks and outcome QA columns present",(string)columns+" columns");
   int noentry_rows=0,blank_bad=0,causal_bad=0,width_bad=0;
   while(!FileIsEnding(read_handle))
     {
      string line=FileReadString(read_handle);if(line=="")continue;string values[];int count=StringSplit(line,',',values);
      if(count!=columns){++width_bad;continue;}if(!schema)continue;
      if(values[0]=="TE-NOENTRY")
        {++noentry_rows;if(values[status_col]!="NO_ENTRY"||values[tp_col]!=""||values[sl_col]!=""||values[pips_col]!=""||values[r_col]!="")++blank_bad;}
      else if(StringToInteger(values[entry_col])<StringToInteger(values[processing_col])||StringToInteger(values[entry_col])<StringToInteger(values[eligible_col])||StringToInteger(values[entry_col])<=StringToInteger(values[source_col]))++causal_bad;
     }
   FileClose(read_handle);
   TECheck("TSTE-NO-ENTRY-SCENARIO-COMPLETENESS",noentry_rows==2*TSTD_DISTANCES,"12 NO_ENTRY rows",(string)noentry_rows);
   TECheck("TSTE-NO-ENTRY-BLANK-NOT-ZERO",blank_bad==0,"no touch or P/L for unentered scenarios",(string)blank_bad+" invalid rows");
   TECheck("TSTE-SERIALIZED-CAUSALITY",causal_bad==0,"0 causal violations",(string)causal_bad);
   TECheck("TSTE-SERIALIZED-COLUMN-COUNT",width_bad==0,"0 width mismatches",(string)width_bad);
  }

int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;
   FolderCreate(g_te_folder,FILE_COMMON);
   g_te_file=FileOpen(g_te_folder+"\\technical_execution_harness.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',',CP_UTF8);
   g_tstd_outcomes=FileOpen(g_te_folder+"\\technical_outcomes.csv",FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
   if(g_te_file==INVALID_HANDLE||g_tstd_outcomes==INVALID_HANDLE)return INIT_FAILED;
   FileWrite(g_te_file,"test_id","status","expected","actual");FileWriteString(g_tstd_outcomes,TSTDOutcomeHeader()+"\r\n");
   TETestCausality();TETestGeometryAndBarriers();TETestRejections();TETestTimeAndSerialization();
   FileWrite(g_te_file,"TOTAL",g_te_fail==0?"PASS":"FAIL","0 failures",StringFormat("PASS=%d;FAIL=%d",g_te_pass,g_te_fail));
   FileClose(g_te_file);g_te_file=INVALID_HANDLE;
   PrintFormat("Technical execution harness PASS=%d FAIL=%d actual_orders=0",g_te_pass,g_te_fail);
   return g_te_fail==0?INIT_SUCCEEDED:INIT_FAILED;
  }
void OnTick(){}
void OnDeinit(const int reason)
  {if(g_te_file!=INVALID_HANDLE){FileClose(g_te_file);g_te_file=INVALID_HANDLE;}if(g_tstd_outcomes!=INVALID_HANDLE){FileClose(g_tstd_outcomes);g_tstd_outcomes=INVALID_HANDLE;}}
