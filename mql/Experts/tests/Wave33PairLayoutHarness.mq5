// Bounded native QA of the actual EA, connected-pair policy and chart labels.
#define OnInit W33BaseOnInit
#define OnTick W33BaseOnTick
#define OnDeinit W33BaseOnDeinit
#define OnTradeTransaction W33BaseOnTradeTransaction
#define OnChartEvent W33BaseOnChartEvent
#include "../Wave33ChopDiagnostic.mq5"
#undef OnInit
#undef OnTick
#undef OnDeinit
#undef OnTradeTransaction
#undef OnChartEvent

// Freeze the pre-change engine in the same build for complete CSV event parity.
#undef WAVE33_VISUAL_ENGINE_MQH
#define CWave33Series CWave33BeforeSeries
#define CWave33Engine CWave33BeforeEngine
#include "../../../reports/qa/w33_pair_layout_20261025/before/Engine.mqh"
#undef CWave33Series
#undef CWave33Engine

int qa_file=INVALID_HANDLE,qa_checks=0,qa_failures=0;
datetime qa_base=D'2020.01.01 00:00:00';
input bool InpQAVisual=false;
bool qa_done=false;
void QA(const string name,const bool ok,const string detail="")
  {qa_checks++;if(!ok)qa_failures++;Print("PAIR_LAYOUT_QA ",name," ",ok?"PASS":"FAIL"," ",detail);FileWrite(qa_file,name,ok?"PASS":"FAIL",detail);FileFlush(qa_file);}
string QAKey(const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const int d)
  {return EnumToString(u)+"_"+EnumToString(l)+"_"+W33DirectionName(d);}
void QABar(MqlRates &b,const ENUM_TIMEFRAMES tf,const int i,const double value,const int d)
  {ZeroMemory(b);double p=d>0?value:220-value;b.time=qa_base+i*PeriodSeconds(tf);b.open=p-0.1*d;b.close=p;b.high=p+0.3;b.low=p-0.3;b.tick_volume=100;b.spread=10;}
bool QAFeed(CWave33Engine &e,const ENUM_TIMEFRAMES tf,const int i,const double p,const int d,const datetime known=0)
  {MqlRates b;QABar(b,tf,i,p,d);return e.Feed(tf,b,known==0?b.time+PeriodSeconds(tf):known);}
void QAConfigure(CWave33Engine &e,const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const bool both,const bool legacy,const bool setter=true)
  {e.Configure(u,l,2,2,0.382,0.618,96,false,true);e.SetPoint(0.01);e.SetLifecyclePolicy(true);e.SetDeepFibClosePolicy(false);e.SetLowerRecognition(W33_NORMALIZED_OR_SIMPLE);e.SetTriggerMode(W33_PIVOT_BREAK);e.SetConnectedOppositePolicy(legacy);if(setter)e.SetConnectedPairPolicy(both);e.Reset("PAIR_SYNTHETIC");}
void QASeed(CWave33Engine &e,const ENUM_TIMEFRAMES u,const int d)
  {double p[]={110,112,115,112,108,105,108,110,112,109,104,100,104,107,110,114,117,120,118,116};for(int i=0;i<ArraySize(p);i++)QAFeed(e,u,i,p[i],d);}
void QAReverse(CWave33Engine &e,const ENUM_TIMEFRAMES u,const int d)
  {double p[]={113,110,113,115,109};for(int i=0;i<ArraySize(p);i++)QAFeed(e,u,20+i,p[i],d);}
void QASignal(CWave33Engine &e,const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const int d)
  {double p[]={116,114,110,111,113,115,113,112,113,116};int r=PeriodSeconds(u)/PeriodSeconds(l);for(int i=0;i<ArraySize(p);i++)QAFeed(e,l,20*r+i,p[i],d);}
int QACount(const W33Event &e[],const string type,const string id="",const string reason="")
  {int count=0;for(int i=0;i<ArraySize(e);i++)if(e[i].event_type==type && (id=="" || e[i].setup.setup_id==id) && (reason=="" || e[i].reason==reason))count++;return count;}
void QAPair(const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const int d,const bool legacy,const bool signalled)
  {
   string k=QAKey(u,l,d)+"_old"+(string)legacy+"_sig"+(string)signalled;CWave33Engine e;QAConfigure(e,u,l,true,legacy);QASeed(e,u,d);if(signalled)QASignal(e,u,l,d);
   W33Setup older;bool was=e.GetActive(d,older);QA("fixed_old_"+k,was && older.wave1_peak_fixed && older.signal_emitted==signalled);
   W33Event ignored[];e.Drain(ignored);QAReverse(e,u,d);W33Setup a,b;bool activeA=e.GetActive(d,a),activeB=e.GetActive(-d,b);W33Event events[];e.Drain(events);
   QA("both_inactive_"+k,!activeA && !activeB && a.setup_id==older.setup_id && b.setup_id!="");
   QA("same_explicit_reason_"+k,a.connected_opposite_cancelled && b.connected_opposite_cancelled && a.skip_reason=="CONNECTED_OPPOSITE_W1_BOTH" && b.skip_reason==a.skip_reason && a.entry_status=="INVALIDATED" && b.entry_status=="INVALIDATED");
   QA("mutual_link_"+k,a.connected_opposite_setup_id==b.setup_id && b.connected_opposite_setup_id==a.setup_id && a.connected_shared_time==older.wave1_peak_time && b.connected_shared_time==a.connected_shared_time && a.connected_shared_price==b.connected_shared_price);
   datetime now=qa_base+25*PeriodSeconds(u);QA("available_now_not_future_peak_"+k,a.connected_opposite_known_at==now && b.connected_opposite_known_at==now && !b.wave1_peak_fixed && b.wave1_peak_known_at==0);
   int ib=-1,ia=-1,in=-1;for(int i=0;i<ArraySize(events);i++){if(events[i].event_type=="WAVE1_BREAK" && events[i].setup.setup_id==b.setup_id)ib=i;if(events[i].event_type=="INVALIDATE" && events[i].setup.setup_id==a.setup_id)ia=i;if(events[i].event_type=="INVALIDATE" && events[i].setup.setup_id==b.setup_id)in=i;}
   QA("atomic_event_order_"+k,ib>=0 && ia>ib && in>ia && QACount(events,"INVALIDATE",a.setup_id,a.skip_reason)==1 && QACount(events,"INVALIDATE",b.setup_id,b.skip_reason)==1);
   QA("new_never_starts_tracking_"+k,QACount(events,"WAVE1_PROVISIONAL",b.setup_id)==0 && QACount(events,"STATE",b.setup_id)==0 && QACount(events,"SIGNAL",b.setup_id)==0);
   for(int i=0;i<20;i++)QAFeed(e,l,26*PeriodSeconds(u)/PeriodSeconds(l)+i,110+i%4,d);
   QAFeed(e,u,24,109,d,now+1);W33Event later[];e.Drain(later);
   QA("no_duplicate_or_signal_after_pair_"+k,QACount(later,"SIGNAL",a.setup_id)==0 && QACount(later,"SIGNAL",b.setup_id)==0 && QACount(later,"INVALIDATE",a.setup_id)==0 && QACount(later,"INVALIDATE",b.setup_id)==0);
   QA("no_order_submission_or_reactivation_"+k,!e.MarkOrderSubmitted(a.setup_id,true,now+3600) && !e.MarkOrderSubmitted(b.setup_id,true,now+3600) && !e.GetActive(d,a) && !e.GetActive(-d,b));
   CWave33Ledger ledger;string tag=InpRunTag+"_pair_"+k;QA("pair_ledger_open_"+k,ledger.Open(tag));for(int i=0;i<ArraySize(events);i++)ledger.Write(events[i]);for(int i=0;i<ArraySize(later);i++)ledger.Write(later[i]);ledger.Close();
  }
void QAProtection(const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const int d)
  {
   for(int mode=0;mode<2;mode++)
     {CWave33Engine e;QAConfigure(e,u,l,true,true);QASeed(e,u,d);QASignal(e,u,l,d);W33Setup s;e.GetActive(d,s);bool marked=e.MarkOrderSubmitted(s.setup_id,true,s.signal_known_at);if(mode)marked=marked && e.MarkExecution(s.setup_id,true,s.signal_known_at);QAReverse(e,u,d);W33Setup a,b;bool aa=e.GetActive(d,a),bb=e.GetActive(-d,b);W33Event ev[];e.Drain(ev);string k=QAKey(u,l,d)+"_"+(string)mode;
      QA("pending_or_position_protects_both_"+k,marked && aa && bb && !a.connected_opposite_cancelled && !b.connected_opposite_cancelled && a.position_open==(mode==1));QA("pending_or_position_no_pair_invalidation_"+k,QACount(ev,"INVALIDATE",s.setup_id,"CONNECTED_OPPOSITE_W1_BOTH")==0 && QACount(ev,"INVALIDATE",b.setup_id,"CONNECTED_OPPOSITE_W1_BOTH")==0);}
  }
void QAPolicyOff(const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const int d)
  {
   for(int mode=0;mode<3;mode++)
     {bool old=mode==0;CWave33Engine e;QAConfigure(e,u,l,false,old,mode!=2);QASeed(e,u,d);W33Setup s;e.GetActive(d,s);QAReverse(e,u,d);W33Setup a,b;bool aa=e.GetActive(d,a),bb=e.GetActive(-d,b);W33Event ev[];e.Drain(ev);QA("legacy_or_off_or_constructor_"+QAKey(u,l,d)+"_"+(string)mode,bb && aa==!old && QACount(ev,"INVALIDATE",s.setup_id,"CONNECTED_OPPOSITE_W1_CANDIDATE")==((int)old) && QACount(ev,"INVALIDATE","","CONNECTED_OPPOSITE_W1_BOTH")==0);}
  }
void QATiming(const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const int d)
  {
   CWave33Engine e;QAConfigure(e,u,l,true,true);QASeed(e,u,d);double p[]={113,110,113,115};for(int i=0;i<4;i++)QAFeed(e,u,20+i,p[i],d);W33Setup old;e.GetActive(d,old);datetime close=qa_base+25*PeriodSeconds(u),late=close+2*PeriodSeconds(u);bool forming=QAFeed(e,u,24,109,d,close-1);W33Setup a,b;QA("forming_no_pair_"+QAKey(u,l,d),!forming && e.GetActive(d,a) && !a.connected_opposite_cancelled);QAFeed(e,u,24,109,d,late);e.GetActive(d,a);e.GetActive(-d,b);QA("delayed_knowledge_not_backdated_"+QAKey(u,l,d),a.connected_opposite_known_at==late && b.connected_opposite_known_at==late && b.upper_break_confirmed_at==close && b.candidate_detected_at==late);
  }
void QAPure()
  {
   W33Setup a,b;ZeroMemory(a);ZeroMemory(b);datetime now=qa_base+3600;a.setup_id="old";a.symbol="X";a.upper_tf=PERIOD_M15;a.lower_tf=PERIOD_M5;a.direction=1;a.active=true;a.wave1_peak_fixed=true;a.candidate_detected_at=qa_base;a.wave1_peak_time=qa_base+900;a.wave1_peak_price=120;a.wave1_peak_known_at=qa_base+1800;a.last_updated_at=qa_base+1800;
   b=a;b.setup_id="new";b.direction=-1;b.wave1_peak_fixed=false;b.candidate_detected_at=now;b.wave1_start_time=a.wave1_peak_time;b.wave1_start_price=a.wave1_peak_price;b.wave1_start_known_at=a.wave1_peak_known_at;b.upper_break_confirmed_at=now;
   for(int variant=-1;variant<28;variant++)
     {W33Setup x=a,y=b;bool so=false,sn=false;datetime known=now;double point=0.01;
      switch(variant){case 0:x.wave1_peak_fixed=false;break;case 1:x.position_open=true;break;case 2:so=true;break;case 3:x.order_sent_at=now;break;case 4:x.fill_at=now;break;case 5:x.active=false;break;case 6:y.active=false;break;case 7:y.direction=x.direction;break;case 8:y.symbol="Y";break;case 9:y.upper_tf=PERIOD_M5;break;case 10:y.lower_tf=PERIOD_M1;break;case 11:y.candidate_detected_at=x.candidate_detected_at;break;case 12:x.wave1_peak_known_at=now+1;break;case 13:y.wave1_start_known_at=now+1;break;case 14:y.upper_break_confirmed_at=now+1;break;case 15:y.wave1_start_time++;break;case 16:y.wave1_start_price+=0.00501;break;case 17:known--;break;case 18:x.connected_opposite_cancelled=true;break;case 19:x.last_updated_at=now+1;break;case 20:point=0;break;case 21:sn=true;break;case 22:y.position_open=true;break;case 23:y.order_sent_at=now;break;case 24:y.fill_at=now;break;case 25:y.connected_opposite_cancelled=true;break;case 26:y.wave1_start_price+=0.005;break;case 27:y.wave1_start_price-=0.005;break;}
      W33Setup bx=x,by=y;bool expected=variant<0 || variant>=26;bool result=W33InvalidateConnectedPairUnordered(x,y,so,sn,known,point);QA("pure_connection_boundary_"+(string)variant,result==expected);
      QA("pure_atomic_no_partial_mutation_"+(string)variant,result?(!x.active && !y.active && x.connected_opposite_setup_id==y.setup_id && y.connected_opposite_setup_id==x.setup_id):(x.active==bx.active && y.active==by.active && x.connected_opposite_cancelled==bx.connected_opposite_cancelled && y.connected_opposite_cancelled==by.connected_opposite_cancelled && x.connected_opposite_setup_id==bx.connected_opposite_setup_id && y.connected_opposite_setup_id==by.connected_opposite_setup_id));}
  }
void QARecordedPair()
  {
   // Exact pre-cancellation snapshots from recorded_pair.json. Later P/L is
   // deliberately not an input. This is not a full historical market replay.
   W33Setup a,b;ZeroMemory(a);ZeroMemory(b);datetime now=D'2025.01.14 22:15:00';
   a.setup_id="W33_XAUUSD+_5_1_LONG_1736887800_51";a.symbol="XAUUSD+";a.upper_tf=PERIOD_M5;a.lower_tf=PERIOD_M1;a.direction=1;a.active=true;
   a.candidate_detected_at=D'2025.01.14 20:55:00';a.last_updated_at=D'2025.01.14 22:14:00';a.wave1_peak_fixed=true;a.wave1_peak_time=D'2025.01.14 21:35:00';a.wave1_peak_price=2676.33;a.wave1_peak_known_at=D'2025.01.14 21:50:00';
   b.setup_id="W33_XAUUSD+_5_1_SHORT_1736892600_52";b.symbol=a.symbol;b.upper_tf=a.upper_tf;b.lower_tf=a.lower_tf;b.direction=-1;b.active=true;b.candidate_detected_at=now;b.last_updated_at=now;
   b.wave1_start_time=D'2025.01.14 21:35:00';b.wave1_start_price=2676.33;b.wave1_start_known_at=D'2025.01.14 21:50:00';b.upper_break_confirmed_at=now;
   QA("recorded_user_pair_both_cancel_now",W33InvalidateConnectedPairUnordered(a,b,false,false,now,0.01) && !a.active && !b.active && a.connected_opposite_known_at==now && b.connected_opposite_known_at==now);
   QA("recorded_user_second_short_excluded_before_order",b.skip_reason=="CONNECTED_OPPOSITE_W1_BOTH" && b.order_sent_at==0 && b.fill_at==0 && b.connected_opposite_setup_id==a.setup_id);
  }
void QAParity(const ENUM_TIMEFRAMES u,const ENUM_TIMEFRAMES l,const int d,const bool legacy)
  {
   CWave33Engine current;QAConfigure(current,u,l,false,legacy);CWave33BeforeEngine before;before.Configure(u,l,2,2,0.382,0.618,96,false,true);before.SetPoint(0.01);before.SetLifecyclePolicy(true);before.SetDeepFibClosePolicy(false);before.SetLowerRecognition(W33_NORMALIZED_OR_SIMPLE);before.SetTriggerMode(W33_PIVOT_BREAK);before.SetConnectedOppositePolicy(legacy);before.Reset("PAIR_SYNTHETIC");
   double p[]={110,112,115,112,108,105,108,110,112,109,104,100,104,107,110,114,117,120,118,116,113,110,113,115,109,106,104,108,110,112,116,118};
   for(int i=0;i<ArraySize(p);i++){MqlRates b;QABar(b,u,i,p[i],d);current.Feed(u,b,b.time+PeriodSeconds(u));before.Feed(u,b,b.time+PeriodSeconds(u));}
   double lower[]={116,114,110,111,113,115,113,112,113,116};for(int i=0;i<ArraySize(lower);i++){MqlRates b;QABar(b,l,32*PeriodSeconds(u)/PeriodSeconds(l)+i,lower[i],d);current.Feed(l,b,b.time+PeriodSeconds(l));before.Feed(l,b,b.time+PeriodSeconds(l));}
   W33Event a[],b[];current.Drain(a);before.Drain(b);string key=QAKey(u,l,d)+"_"+(string)legacy;QA("legacy_off_event_count_"+key,ArraySize(a)==ArraySize(b));
   CWave33Ledger ca,cb;QA("parity_ledger_open_"+key,ca.Open(InpRunTag+"_parity_current_"+key) && cb.Open(InpRunTag+"_parity_before_"+key));for(int i=0;i<ArraySize(a);i++)ca.Write(a[i]);for(int i=0;i<ArraySize(b);i++)cb.Write(b[i]);ca.Close();cb.Close();
  }
void QAActualMain()
  {
   QA("actual_pair_input_enabled",InpSkipBothConnectedWave1);
   for(int arm=0;arm<2;arm++)for(int d=-1;d<=1;d+=2)
     {ENUM_TIMEFRAMES u=arm?PERIOD_M5:PERIOD_M15,l=arm?PERIOD_M1:PERIOD_M5;g_upper=u;g_lower=l;QAConfigure(g_engine,u,l,InpSkipBothConnectedWave1,InpCancelConnectedOpposite);QASeed(g_engine,u,d);Drain();QAReverse(g_engine,u,d);Drain();W33Setup a,b;bool aa=g_engine.GetActive(d,a),bb=g_engine.GetActive(-d,b);QA("actual_drain_pair_no_active_"+QAKey(u,l,d),!aa && !bb);QA("actual_drain_no_trade_record_"+QAKey(u,l,d),ArraySize(g_records)==0);}
   QA("actual_no_native_orders_positions",OrdersTotal()==0 && PositionsTotal()==0);
  }
string qa_names[];
datetime qa_anchor_time;
double qa_anchor_price;
CWave33ChopDisplay qa_display;
bool qa_label_ready=false;
int qa_visual_stage=0;
int qa_capture_waits=0;
bool qa_stage_advance=true,qa_saved_scale_fixed=false;
double qa_saved_fixed_min=0,qa_saved_fixed_max=0;
string QALabelCaption(const int i)
  {if(i==0)return "①旧 第1波 r0 始点と終点の履歴を保持";return (i%2==0?"見送り: 接続する逆方向の第1波候補を認識したため終了 ":"抵抗候補 M15 高値 2025.01.14 21:35 known 21:50 ")+(string)i;}
void QACheckBoxes(CWave33ChopDisplay &display,const string phase,const bool require_all)
  {
   int count=ArraySize(qa_names),xs[],ys[],ws[],hs[];ArrayResize(xs,count);ArrayResize(ys,count);ArrayResize(ws,count);ArrayResize(hs,count);int placed=0;
   int width=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS),height=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);bool inside=true,anchors=true,spacing=true;
   for(int i=0;i<count;i++)
     {datetime at;double p;anchors=anchors && display.LabelAnchor(qa_names[i],at,p) && at==qa_anchor_time && MathAbs(p-qa_anchor_price)<1e-9;
      if(!display.LabelBounds(qa_names[i],xs[i],ys[i],ws[i],hs[i])){ws[i]=0;continue;}placed++;inside=inside && xs[i]>=8 && ys[i]>=24 && xs[i]+ws[i]<=width-72 && ys[i]+hs[i]<=height-8;}
   for(int i=0;i<count;i++)for(int j=i+1;j<count;j++)if(ws[i]>0 && ws[j]>0)spacing=spacing && (xs[i]+ws[i]<=xs[j] || xs[j]+ws[j]<=xs[i] || ys[i]+hs[i]<=ys[j] || ys[j]+hs[j]<=ys[i]);
   QA("label_logical_anchors_stable_"+phase,anchors);QA("label_boxes_clamped_"+phase,inside);QA("label_boxes_no_overlap_"+phase,spacing);QA("label_all_visible_"+phase,!require_all || placed==count,(string)placed+" / "+(string)count);
  }
void QALabels(const int stage)
  {
   if(stage==0)
     {
   ChartRedraw();int width=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS),height=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0),sub=0;
   double low=ChartGetDouble(0,CHART_PRICE_MIN,0),high=ChartGetDouble(0,CHART_PRICE_MAX,0);
   bool available=width>=500 && height>=300 && high>low && ChartXYToTimePrice(0,width/3,height/2,sub,qa_anchor_time,qa_anchor_price) && qa_anchor_price>0;
   FileWrite(qa_file,"LABEL_CHART_GEOMETRY",available?"AVAILABLE":"UNAVAILABLE","width="+(string)width+" height="+(string)height+"; headless absence is not visual proof");
   if(InpQAVisual)QA("visual_geometry_available",available);if(!available)return;
   qa_label_ready=true;string prefix="QA_FIXTURE_";qa_display.Init(prefix,true);qa_display.ConfigureReadability(false);
   string unrelated="EXTERNAL_FIXTURE";ObjectCreate(0,unrelated,OBJ_TEXT,0,qa_anchor_time,qa_anchor_price);ObjectSetString(0,unrelated,OBJPROP_TEXT,"unrelated");
   int count=20;ArrayResize(qa_names,count);
   for(int i=0;i<count;i++)
     {qa_names[i]=prefix+"fixture_"+(string)i;ObjectCreate(0,qa_names[i],OBJ_TEXT,0,qa_anchor_time,qa_anchor_price);ObjectSetString(0,qa_names[i],OBJPROP_TEXT,QALabelCaption(i));ObjectSetString(0,qa_names[i],OBJPROP_TOOLTIP,"Full fixture provenance "+(string)i);ObjectSetInteger(0,qa_names[i],OBJPROP_COLOR,i%2!=0?clrViolet:clrOrangeRed);ObjectSetInteger(0,qa_names[i],OBJPROP_FONTSIZE,10);ObjectSetInteger(0,qa_names[i],OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);}
   ChartRedraw();if(InpQAVisual)QA("before_screenshot_requested",ChartScreenShot(0,InpRunTag+"_dense_before.png",width,height,ALIGN_LEFT));return;
     }
   if(!qa_label_ready)return;
   string prefix="QA_FIXTURE_",unrelated="EXTERNAL_FIXTURE";int count=ArraySize(qa_names);
   if(stage==1)
     {
   string before=InpRunTag+"_dense_before.png";
   if(!FileIsExist(before) && qa_capture_waits++<30){qa_stage_advance=false;return;}
   QA("before_screenshot_saved",FileIsExist(before) && FileMove(before,0,before,FILE_COMMON|FILE_REWRITE));qa_capture_waits=0;
   qa_display.ConfigureReadability(true);qa_display.Layout(true);QACheckBoxes(qa_display,"initial",true);
   QA("label_ownership_excludes_unrelated",!qa_display.LabelManaged(unrelated) && ObjectGetString(0,unrelated,OBJPROP_TEXT)=="unrelated");
   bool finite=true,leader_anchor=true;int leaders=0;
   for(int i=0;i<ObjectsTotal(0);i++){string n=ObjectName(0,i);if(StringFind(n,"W33LL_")!=0)continue;leaders++;finite=finite && !ObjectGetInteger(0,n,OBJPROP_RAY_LEFT) && !ObjectGetInteger(0,n,OBJPROP_RAY_RIGHT);leader_anchor=leader_anchor && ObjectGetInteger(0,n,OBJPROP_TIME,0)==qa_anchor_time && MathAbs(ObjectGetDouble(0,n,OBJPROP_PRICE,0)-qa_anchor_price)<1e-9;}
   QA("label_finite_leaders",finite && leaders>=count,(string)leaders);QA("label_leader_true_source_anchors",leader_anchor);
   qa_display.Layout(true);QACheckBoxes(qa_display,"repeat",true);
   long scale=ChartGetInteger(0,CHART_SCALE);ChartSetInteger(0,CHART_SCALE,(scale+1)%6);ChartRedraw();qa_display.Layout(true);QACheckBoxes(qa_display,"zoom",false);ChartSetInteger(0,CHART_SCALE,scale);ChartRedraw();qa_display.Layout(true);
   qa_saved_scale_fixed=(bool)ChartGetInteger(0,CHART_SCALEFIX);qa_saved_fixed_min=ChartGetDouble(0,CHART_FIXED_MIN);qa_saved_fixed_max=ChartGetDouble(0,CHART_FIXED_MAX);
   ChartSetInteger(0,CHART_SCALEFIX,true);ChartSetDouble(0,CHART_FIXED_MAX,qa_anchor_price+150);ChartSetDouble(0,CHART_FIXED_MIN,qa_anchor_price+100);ChartRedraw();return;
     }
   if(stage==2)
     {
   qa_display.Layout(true);double low=ChartGetDouble(0,CHART_PRICE_MIN),high=ChartGetDouble(0,CHART_PRICE_MAX);
   QA("offscreen_viewport_applied",qa_anchor_price<low || qa_anchor_price>high,"min="+DoubleToString(low,2)+" max="+DoubleToString(high,2)+" anchor="+DoubleToString(qa_anchor_price,2));
   bool offscreen_style=true;for(int i=0;i<count;i++)offscreen_style=offscreen_style && ObjectGetInteger(0,qa_names[i],OBJPROP_FONTSIZE)==10 && ObjectGetInteger(0,qa_names[i],OBJPROP_COLOR)==(i%2!=0?clrViolet:clrOrangeRed);
   QA("offscreen_restores_original_font_colour",offscreen_style,"font0="+(string)ObjectGetInteger(0,qa_names[0],OBJPROP_FONTSIZE));
   ChartSetDouble(0,CHART_FIXED_MIN,qa_saved_fixed_min);ChartSetDouble(0,CHART_FIXED_MAX,qa_saved_fixed_max);ChartSetInteger(0,CHART_SCALEFIX,qa_saved_scale_fixed);ChartRedraw();return;
     }
   if(stage==3)
     {
   qa_display.Layout(true);QACheckBoxes(qa_display,"return_from_offscreen",true);
   if(InpQAVisual)QA("after_screenshot_requested",ChartScreenShot(0,InpRunTag+"_dense_after.png",(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS),(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0),ALIGN_LEFT));return;
     }
   string after=InpRunTag+"_dense_after.png";
   if(!FileIsExist(after) && qa_capture_waits++<30){qa_stage_advance=false;return;}
   QA("after_screenshot_saved",FileIsExist(after) && FileMove(after,0,after,FILE_COMMON|FILE_REWRITE));qa_capture_waits=0;
   qa_display.ConfigureReadability(false);bool restored=true;for(int i=0;i<count;i++)restored=restored && ObjectGetInteger(0,qa_names[i],OBJPROP_TIME,0)==qa_anchor_time && MathAbs(ObjectGetDouble(0,qa_names[i],OBJPROP_PRICE,0)-qa_anchor_price)<1e-9 && ObjectGetString(0,qa_names[i],OBJPROP_TEXT)==QALabelCaption(i) && ObjectGetInteger(0,qa_names[i],OBJPROP_FONTSIZE)==10 && ObjectGetInteger(0,qa_names[i],OBJPROP_COLOR)==(i%2!=0?clrViolet:clrOrangeRed);
   QA("label_off_restores_originals",restored);qa_display.Clear();ObjectsDeleteAll(0,prefix);ObjectDelete(0,unrelated);
  }
void QAFinish(){FileWrite(qa_file,"SUMMARY",qa_failures?"FAIL":"PASS",(string)qa_checks+" checks; "+(string)qa_failures+" failures");FileClose(qa_file);qa_file=INVALID_HANDLE;ExpertRemove();}
int OnInit()
  {if(!MQLInfoInteger(MQL_TESTER))return INIT_FAILED;int result=W33BaseOnInit();if(result!=INIT_SUCCEEDED)return result;qa_file=FileOpen(InpRunTag+"_assertions.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,';',CP_UTF8);if(qa_file==INVALID_HANDLE)return INIT_FAILED;FileWrite(qa_file,"test","result","detail");return INIT_SUCCEEDED;}
void OnTick()
  {
   if(qa_done)return;qa_done=true;QAPure();QARecordedPair();ENUM_TIMEFRAMES u[2]={PERIOD_M15,PERIOD_M5},l[2]={PERIOD_M5,PERIOD_M1};for(int arm=0;arm<2;arm++)for(int d=-1;d<=1;d+=2){for(int legacy=0;legacy<2;legacy++)for(int signal=0;signal<2;signal++)QAPair(u[arm],l[arm],d,legacy==1,signal==1);QAProtection(u[arm],l[arm],d);QAPolicyOff(u[arm],l[arm],d);QATiming(u[arm],l[arm],d);for(int legacy=0;legacy<2;legacy++)QAParity(u[arm],l[arm],d,legacy==1);}QAActualMain();if(InpQAVisual){EventSetTimer(1);return;}FileWrite(qa_file,"LABEL_CHART_GEOMETRY","NOT_TESTED","Headless run; visual geometry is tested separately");QAFinish();
  }
void OnTimer(){if(!InpQAVisual || qa_file==INVALID_HANDLE)return;qa_stage_advance=true;QALabels(qa_visual_stage);if(qa_stage_advance)qa_visual_stage++;if(qa_visual_stage>=5){EventKillTimer();QAFinish();}}
void OnDeinit(const int reason){EventKillTimer();if(qa_file!=INVALID_HANDLE)FileClose(qa_file);W33BaseOnDeinit(reason);}
