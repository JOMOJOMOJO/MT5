#property strict
#property version "1.10"
#property description "3-wave in 3-wave v1.0: causal visual observation, tester orders optional."
#include "../Include/Wave33Visual/Engine.mqh"
#include "../Include/Wave33Visual/Display.mqh"
#include "../Include/Wave33Visual/Ledger.mqh"

enum W33Pattern {M15_M5=0,M5_M1=1};
enum W33ObstacleMode {DISPLAY_ONLY=0,SKIP_IF_BLOCKED=1,CAP_TP=2};
input W33Pattern InpPattern=M15_M5;
input W33TriggerMode InpTriggerMode=W33_PIVOT_BREAK;
input int InpSwingLeft=2;
input int InpSwingRight=2;
input double InpFibMin=0.382;
input double InpFibMax=0.618;
input bool InpRequireFibTouch=true;
input bool InpRejectDeepFib=false;
input int InpTimeoutUpperBars=96;
input W33ObstacleMode InpObstacleMode=DISPLAY_ONLY;
input double InpRewardR=1.0;
input double InpRiskPercent=1.0;
input double InpSLExtraPoints=10.0;
input bool InpEnableTesterOrders=false;
input ulong InpMagic=3320261020;
input uint InpDeviationPoints=20;
input bool InpDraw=true;
input bool InpShowInfoPanel=false; // 左下の小さな凡例を表示
input bool InpDiagnosticLabels=false; // 詳細なスイング・診断文字を表示
input bool InpShowSwingPaths=true; // 確定した山谷を破線で結ぶ
input bool InpKeepObjects=true;
input bool InpScreenshots=false;
input int InpScreenshotLimit=12;
input string InpRunTag="wave33_v1";
// Manual important zones intentionally remain outside the automatic signal engine.
input string InpManualLevels=""; // Semicolon-separated prices, display from attach time only.

CWave33Engine g_engine;
CWave33Display g_display;
CWave33Ledger g_ledger;
ENUM_TIMEFRAMES g_upper,g_lower,g_frames[4];
datetime g_lastOpen[4];
bool g_ready=false;
string g_prefix,g_lastReason="",g_tag;
int g_shots=0;
W33Setup g_last;
struct W33Execution
  {
   W33Setup setup;
   ulong position_id;
   double initial_risk_money;
   double net_cash;
   double exit_volume;
   double filled_volume;
   bool pending;
  };
W33Execution g_records[];

int RecordIndex(const string id)
  {
   for(int i=0;i<ArraySize(g_records);i++)if(g_records[i].setup.setup_id==id)return i;
   return -1;
  }
void MergeExecution(W33Setup &s)
  {
   int i=RecordIndex(s.setup_id);if(i<0)return;
   W33Setup saved=g_records[i].setup;
   s.entry_price=saved.entry_price;s.sl_price=saved.sl_price;s.tp_price=saved.tp_price;
   s.risk_points=saved.risk_points;s.intended_rr=saved.intended_rr;
   s.order_sent_at=saved.order_sent_at;s.fill_at=saved.fill_at;s.entry_status=saved.entry_status;
   if(s.skip_reason=="")s.skip_reason=saved.skip_reason;s.exit_at=saved.exit_at;s.exit_reason=saved.exit_reason;
   s.realized_r=saved.realized_r;s.spread_points=saved.spread_points;
   s.nearest_obstacle_price=saved.nearest_obstacle_price;s.nearest_obstacle_tf=saved.nearest_obstacle_tf;
   s.nearest_obstacle_known_at=saved.nearest_obstacle_known_at;s.obstacle_distance_r=saved.obstacle_distance_r;
   s.h1_direction=saved.h1_direction;
   s.actual_rr=saved.actual_rr;s.candle_body_ratio=saved.candle_body_ratio;s.candle_body_atr=saved.candle_body_atr;
  }
double PriceRound(const double p,const int direction)
  {
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick<=0)tick=_Point;
   double v=p/tick;
   return NormalizeDouble((direction>0?MathCeil(v-1e-9):MathFloor(v+1e-9))*tick,_Digits);
  }
void Publish(W33Event &e)
  {
   g_ledger.Write(e);g_display.Event(e);
   if(e.setup.setup_id!="")g_last=e.setup;
   if(e.reason_kind=="EXCLUSION")g_lastReason=e.reason;
  }
void Emit(W33Setup &s,const string event,const string kind,const string reason)
  {
   W33Event e;ZeroMemory(e);e.at=TimeCurrent();e.event_type=event;e.reason_kind=kind;e.reason=reason;e.setup=s;Publish(e);
  }
void Screenshot(const W33Setup &s,const string event)
  {
   if(!InpScreenshots || !InpDraw || g_shots>=InpScreenshotLimit || !MQLInfoInteger(MQL_VISUAL_MODE))return;
   Panel();ChartRedraw();
   string name="W33_"+W33Hash(g_tag)+"_"+W33Hash(s.setup_id)+"_"+event+".png";
   bool ok=ChartScreenShot(0,name,1600,1000,ALIGN_RIGHT);g_shots++;
   W33Setup copy=s;Emit(copy,"DRAWING_CAPTURE","OBSERVATION",ok?name:"ChartScreenShot failed "+IntegerToString(GetLastError()));
  }
void Obstacle(W33Setup &s)
  {
   W33Pivot pivots[];g_engine.GetObstacles(pivots);
   double best=DBL_MAX;s.nearest_obstacle_price=0;
   for(int i=0;i<ArraySize(pivots);i++)
     {
      double delta=s.direction*(pivots[i].price-s.entry_price);
      if(delta>0 && delta<best && pivots[i].known_at<=TimeCurrent())
        {
         best=delta;s.nearest_obstacle_price=pivots[i].price;s.nearest_obstacle_tf=pivots[i].tf;
         s.nearest_obstacle_time=pivots[i].time;s.nearest_obstacle_known_at=pivots[i].known_at;
        }
     }
   double peakDelta=s.direction*(s.wave1_peak_price-s.entry_price);
   if(peakDelta>0 && peakDelta<best)
     {best=peakDelta;s.nearest_obstacle_price=s.wave1_peak_price;s.nearest_obstacle_tf=s.upper_tf;
      s.nearest_obstacle_time=s.wave1_peak_time;s.nearest_obstacle_known_at=s.wave1_peak_known_at;}
   s.obstacle_distance_r=(s.nearest_obstacle_price>0 && s.risk_points>0)?best/(s.risk_points*_Point):-1;
   s.h1_direction=g_engine.H1Direction(s.direction);
  }
bool Plan(W33Setup &s,string &why)
  {
   MqlTick tick;if(!SymbolInfoTick(_Symbol,tick)){why="NO_QUOTE";return false;}
   s.entry_price=s.direction>0?tick.ask:tick.bid;s.spread_points=(tick.ask-tick.bid)/_Point;
   double minDist=(double)MathMax(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*_Point;
   double pad=(s.spread_points+InpSLExtraPoints)*_Point+minDist;
   s.sl_price=PriceRound(s.wave2_extreme_price-s.direction*pad,-s.direction);
   double risk=s.direction*(s.entry_price-s.sl_price);s.risk_points=risk/_Point;s.intended_rr=InpRewardR;
   if(s.wave2_extreme_price<=0 || risk<=0){why="INVALID_STRUCTURAL_SL";return false;}
   s.tp_price=PriceRound(s.entry_price+s.direction*risk*InpRewardR,s.direction);
   Obstacle(s);
   if(InpObstacleMode==CAP_TP && s.nearest_obstacle_price>0)
     {
      double capped=PriceRound(s.nearest_obstacle_price-s.direction*(InpSLExtraPoints+s.spread_points)*_Point,-s.direction);
      if(s.direction*(capped-s.tp_price)<0)s.tp_price=capped;
     }
   if(s.direction*(s.tp_price-s.entry_price)<=0){why="OBSTACLE_CAP_NONPOSITIVE_RR";return false;}
   s.actual_rr=s.direction*(s.tp_price-s.entry_price)/risk;
   double reference=s.direction>0?tick.bid:tick.ask;
   if(s.direction*(reference-s.sl_price)<minDist || s.direction*(s.tp_price-reference)<minDist)
     {why="BROKER_STOPS_OR_FREEZE_LEVEL";return false;}
   if(InpObstacleMode==SKIP_IF_BLOCKED && s.nearest_obstacle_price>0 && s.obstacle_distance_r<InpRewardR)
     {why="OBSTACLE_NEAR";return false;}
   return true;
  }
bool PositionBusy()
  {
   // Netting and hedging: never merge with or alter any other position on this symbol.
   for(int i=0;i<ArraySize(g_records);i++)if(g_records[i].pending)return true;
   return PositionSelect(_Symbol);
  }
void HandleSignal(W33Event &signal)
  {
   W33Setup s=signal.setup;if(RecordIndex(s.setup_id)>=0)return;
   MqlRates bars[];int count=CopyRates(_Symbol,g_lower,1,15,bars);
   if(count>=2)
     {
      int last=count-1;double span=bars[last].high-bars[last].low,body=MathAbs(bars[last].close-bars[last].open),atr=0;
      for(int j=1;j<count;j++)atr+=MathMax(bars[j].high-bars[j].low,MathMax(MathAbs(bars[j].high-bars[j-1].close),MathAbs(bars[j].low-bars[j-1].close)));
      atr/=(count-1);s.candle_body_ratio=span>0?body/span:0;s.candle_body_atr=atr>0?body/atr:0;
     }
   string reason="";bool valid=Plan(s,reason);
   s.entry_status=valid?"DIAGNOSTIC_SIGNAL":"SIGNAL_RISK_REJECTED";
   signal.setup=s;Publish(signal); // Always preserve ENTRY, SL and TP, including order-disabled signals.
   int n=ArraySize(g_records);ArrayResize(g_records,n+1);ZeroMemory(g_records[n]);g_records[n].setup=s;
   s.state=RESISTANCE_AND_RISK_CHECK;Emit(s,"RISK_CHECK","OBSERVATION","actual_rr="+DoubleToString(s.actual_rr,6));
   if(!valid)
     {s.skip_reason=reason;s.entry_status="SKIPPED";Emit(s,"SKIP","EXCLUSION",reason);g_records[n].setup=s;Screenshot(s,"SKIP");return;}
   if(!InpEnableTesterOrders)
     {s.entry_status="DIAGNOSTIC_ONLY";Emit(s,"ORDER_DISABLED","OBSERVATION","tester orders disabled");g_records[n].setup=s;Screenshot(s,"SIGNAL");return;}
   if(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION))reason="TESTER_ONLY_ORDER_GUARD";
   else if(PositionBusy())reason="SYMBOL_POSITION_BUSY";
   else if(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_MODE)==SYMBOL_TRADE_MODE_DISABLED)reason="SYMBOL_TRADE_DISABLED";
   if(reason!="")
     {s.skip_reason=reason;s.entry_status="SKIPPED";Emit(s,"SKIP","EXCLUSION",reason);g_records[n].setup=s;Screenshot(s,"SKIP");return;}
   ENUM_ORDER_TYPE type=s.direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   double loss=0;
   if(!OrderCalcProfit(type,_Symbol,1.0,s.entry_price,s.sl_price,loss) || loss>=0)
     {s.skip_reason="ORDER_CALC_PROFIT_FAILED";s.entry_status="SKIPPED";Emit(s,"SKIP","EXCLUSION",s.skip_reason);g_records[n].setup=s;return;}
   double budget=AccountInfoDouble(ACCOUNT_EQUITY)*InpRiskPercent/100.0;
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),maxLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double volume=step>0?MathFloor(MathMin(budget/(-loss),maxLot)/step+1e-9)*step:0;
   volume=NormalizeDouble(volume,8);
   if(volume<minLot || volume<=0)
     {s.skip_reason="RISK_SIZE_BELOW_MIN_LOT";s.entry_status="SKIPPED";Emit(s,"SKIP","EXCLUSION",s.skip_reason);g_records[n].setup=s;return;}
   MqlTradeRequest request;MqlTradeResult result;MqlTradeCheckResult check;
   ZeroMemory(request);ZeroMemory(result);ZeroMemory(check);
   request.action=TRADE_ACTION_DEAL;request.symbol=_Symbol;request.magic=InpMagic;request.type=type;
   request.volume=volume;request.price=s.entry_price;request.sl=s.sl_price;request.tp=s.tp_price;
   request.deviation=InpDeviationPoints;request.comment=StringSubstr(s.setup_id,0,31);
   long filling=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   request.type_filling=(filling&SYMBOL_FILLING_FOK)!=0?ORDER_FILLING_FOK:((filling&SYMBOL_FILLING_IOC)!=0?ORDER_FILLING_IOC:ORDER_FILLING_RETURN);
   if(!OrderCheck(request,check))
     {s.entry_status="SKIPPED";s.skip_reason="ORDER_CHECK "+IntegerToString((int)check.retcode)+" "+check.comment;
      Emit(s,"SKIP","EXCLUSION",s.skip_reason);g_records[n].setup=s;return;}
   s.order_sent_at=TimeCurrent();s.entry_status="ORDER_SENT";
   g_records[n].setup=s;g_records[n].initial_risk_money=(-loss)*volume;g_records[n].pending=true;
   Emit(s,"ORDER","OBSERVATION","volume="+DoubleToString(volume,8)+" risk_budget="+DoubleToString(budget,2));
   bool sent=OrderSend(request,result);
   if(!sent || (result.retcode!=TRADE_RETCODE_DONE && result.retcode!=TRADE_RETCODE_DONE_PARTIAL && result.retcode!=TRADE_RETCODE_PLACED))
     {s.entry_status="ORDER_REJECTED";s.skip_reason="ORDER_SEND "+IntegerToString((int)result.retcode)+" "+result.comment;
      g_records[n].pending=false;Emit(s,"SKIP","EXCLUSION",s.skip_reason);g_records[n].setup=s;}
   Screenshot(s,"ORDER");
  }
void Drain()
  {
   W33Event events[];g_engine.Drain(events);
   for(int i=0;i<ArraySize(events);i++)
     {
      if(events[i].event_type=="SIGNAL")HandleSignal(events[i]);
      else {MergeExecution(events[i].setup);Publish(events[i]);
         if(events[i].event_type=="INVALIDATE" || events[i].event_type=="SKIP")Screenshot(events[i].setup,events[i].event_type);}
     }
  }
void FeedClosed()
  {
   // Merge every newly closed TF bar by close time. No old LTF replay against new upper anchors.
   MqlRates pending[];ENUM_TIMEFRAMES periods[];
   datetime now=TimeCurrent();
   for(int f=0;f<4;f++)
     {
      datetime current=iTime(_Symbol,g_frames[f],0);if(current==0 || current==g_lastOpen[f])continue;
      MqlRates bars[];int copied=CopyRates(_Symbol,g_frames[f],g_lastOpen[f],now,bars);
      if(copied<0)continue;
      for(int b=0;b<copied;b++)if(bars[b].time>=g_lastOpen[f] && bars[b].time+PeriodSeconds(g_frames[f])<=now)
        {int n=ArraySize(pending);ArrayResize(pending,n+1);ArrayResize(periods,n+1);pending[n]=bars[b];periods[n]=g_frames[f];}
      g_lastOpen[f]=current;
     }
   int n=ArraySize(pending);
   for(int i=0;i<n;i++)for(int j=i+1;j<n;j++)
      if(pending[j].time+PeriodSeconds(periods[j])<pending[i].time+PeriodSeconds(periods[i]))
        {MqlRates tmp=pending[i];pending[i]=pending[j];pending[j]=tmp;ENUM_TIMEFRAMES tf=periods[i];periods[i]=periods[j];periods[j]=tf;}
   for(int i=0;i<n;i++){g_engine.Feed(periods[i],pending[i],now);Drain();}
  }
void Panel()
  {
   W33Setup a,b;g_engine.GetActive(1,a);g_engine.GetActive(-1,b);
   string text="Wave33 v1 | "+_Symbol+" "+EnumToString(g_upper)+" x "+EnumToString(g_lower)+" | orders="+(InpEnableTesterOrders?"TESTER ON":"OFF")+"\n";
   text+="LONG "+W33StateName(a.state)+" "+a.setup_id+"\nSHORT "+W33StateName(b.state)+" "+b.setup_id+"\n";
   text+="Last "+g_last.setup_id+" | "+g_last.entry_status+"\nW1 "+W33Time(g_last.wave1_start_time)+" @"+DoubleToString(g_last.wave1_start_price,_Digits)+" -> "+DoubleToString(g_last.wave1_peak_price,_Digits)+"\n";
   text+="Peak located "+W33Time(g_last.wave1_peak_time)+" | known "+W33Time(g_last.wave1_peak_known_at)+"\n";
   text+="Fib "+DoubleToString(g_last.retracement_ratio*100,1)+"% | trigger "+DoubleToString(g_last.trigger_line_price,_Digits)+"\n";
   text+="SL "+DoubleToString(g_last.risk_points,1)+" pt | target RR "+DoubleToString(g_last.intended_rr,2)+" | room "+DoubleToString(g_last.obstacle_distance_r,2)+"R\n";
   text+="Candidate "+W33Time(g_last.candidate_detected_at)+"\nSignal "+W33Time(g_last.signal_at)+" | known "+W33Time(g_last.signal_known_at)+"\n";
   text+="Order "+W33Time(g_last.order_sent_at)+" | fill "+W33Time(g_last.fill_at)+"\nH1 "+g_last.h1_direction+"\nLast skip "+g_lastReason;
   g_display.Panel(text);
  }
bool Config()
  {
   int file=FileOpen(g_tag+"_config.csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON, ';',CP_UTF8);
   if(file==INVALID_HANDLE)return false;
   FileWrite(file,"parameter","value");
   FileWrite(file,"version","1.0");FileWrite(file,"symbol",_Symbol);FileWrite(file,"upper_tf",EnumToString(g_upper));FileWrite(file,"lower_tf",EnumToString(g_lower));
   FileWrite(file,"resolved_run_tag",g_tag);
   FileWrite(file,"swing_left",InpSwingLeft);FileWrite(file,"swing_right",InpSwingRight);FileWrite(file,"fib_min",InpFibMin);FileWrite(file,"fib_max",InpFibMax);
   FileWrite(file,"require_fib_touch",InpRequireFibTouch);FileWrite(file,"reject_deep_fib",InpRejectDeepFib);FileWrite(file,"timeout_upper_bars",InpTimeoutUpperBars);
   FileWrite(file,"trigger_mode",EnumToString(InpTriggerMode));FileWrite(file,"obstacle_mode",EnumToString(InpObstacleMode));FileWrite(file,"reward_r",InpRewardR);
   FileWrite(file,"risk_percent",InpRiskPercent);FileWrite(file,"sl_extra_points",InpSLExtraPoints);FileWrite(file,"tester_orders",InpEnableTesterOrders);
   FileWrite(file,"magic",InpMagic);FileWrite(file,"deviation_points",InpDeviationPoints);FileWrite(file,"manual_levels_display_only",InpManualLevels);
   FileWrite(file,"draw",InpDraw);FileWrite(file,"keep_objects",InpKeepObjects);FileWrite(file,"screenshots",InpScreenshots);FileWrite(file,"screenshot_limit",InpScreenshotLimit);
   FileWrite(file,"show_info_panel",InpShowInfoPanel);FileWrite(file,"diagnostic_labels",InpDiagnosticLabels);FileWrite(file,"show_swing_paths",InpShowSwingPaths);
   FileWrite(file,"tester",MQLInfoInteger(MQL_TESTER));FileWrite(file,"visual",MQLInfoInteger(MQL_VISUAL_MODE));FileWrite(file,"terminal_build",TerminalInfoInteger(TERMINAL_BUILD));
   FileWrite(file,"chart_tf",EnumToString((ENUM_TIMEFRAMES)_Period));FileWrite(file,"point",_Point);FileWrite(file,"tick_size",SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE));
   FileWrite(file,"volume_min",SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN));FileWrite(file,"volume_step",SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP));FileWrite(file,"contract_size",SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE));
   FileWrite(file,"stops_level",SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL));FileWrite(file,"freeze_level",SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL));
   FileClose(file);return true;
  }
int OnInit()
  {
   if(InpSwingLeft<1 || InpSwingRight<1 || InpFibMin<=0 || InpFibMax<=InpFibMin || InpFibMax>=1 || InpRewardR<=0 || InpRiskPercent<=0 || InpRiskPercent>100 || InpTimeoutUpperBars<1 || InpSLExtraPoints<0)return INIT_PARAMETERS_INCORRECT;
   if(MQLInfoInteger(MQL_OPTIMIZATION)){Print("Wave33 visual verification does not permit optimization.");return INIT_FAILED;}
   g_tag=InpRunTag;if(g_tag=="")return INIT_PARAMETERS_INCORRECT;
   StringReplace(g_tag,"/","_");StringReplace(g_tag,"\\","_");StringReplace(g_tag,":","_");
   if(FileIsExist(g_tag+"_events.csv",FILE_COMMON))
      g_tag+="_"+IntegerToString((long)TimeLocal())+"_"+IntegerToString((long)GetTickCount());
   Print("Wave33 resolved run tag: ",g_tag);
   g_upper=InpPattern==M15_M5?PERIOD_M15:PERIOD_M5;g_lower=InpPattern==M15_M5?PERIOD_M5:PERIOD_M1;
   g_frames[0]=PERIOD_H1;g_frames[1]=PERIOD_M15;g_frames[2]=PERIOD_M5;g_frames[3]=PERIOD_M1;
   for(int i=0;i<4;i++){g_lastOpen[i]=iTime(_Symbol,g_frames[i],0);if(g_lastOpen[i]==0)return INIT_FAILED;}
   g_engine.Configure(g_upper,g_lower,InpSwingLeft,InpSwingRight,InpFibMin,InpFibMax,InpTimeoutUpperBars,InpRejectDeepFib,InpRequireFibTouch);
   g_engine.Reset(_Symbol);g_engine.SetTriggerMode(InpTriggerMode);g_engine.SetPoint(_Point);
   if(!g_ledger.Open(g_tag) || !Config())return INIT_FAILED;
   g_prefix="W33_"+W33Hash(g_tag)+"_"+IntegerToString((int)InpPattern)+"_";
   g_display.Init(g_prefix,InpDraw);ZeroMemory(g_last);
   g_display.SetFrames(g_upper,g_lower);
   g_display.ConfigureVisuals(InpShowInfoPanel,InpDiagnosticLabels,InpShowSwingPaths);g_display.SetTriggerMode(InpTriggerMode);
   string levels[];int count=StringSplit(InpManualLevels,';',levels);
   for(int j=0;InpDraw && j<count;j++)
     {
      double p=StringToDouble(levels[j]);if(p<=0)continue;
      string name=g_prefix+"MANUAL_DISPLAY_ONLY_"+IntegerToString(j);
      ObjectCreate(0,name,OBJ_TREND,0,TimeCurrent(),p,TimeCurrent()+60,p);ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,true);
      ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);ObjectSetInteger(0,name,OBJPROP_COLOR,clrViolet);
      ObjectSetString(0,name,OBJPROP_TOOLTIP,"MANUAL DISPLAY ONLY known since "+W33Time(TimeCurrent()));
     }
   Print("Wave33 starts without historical setup replay; warm-up pivots accrue prospectively. Tester orders ",InpEnableTesterOrders," visual ",MQLInfoInteger(MQL_VISUAL_MODE));
   W33Setup initial;ZeroMemory(initial);initial.symbol=_Symbol;initial.upper_tf=g_upper;initial.lower_tf=g_lower;initial.state=SEARCH_STRUCTURE;
   Emit(initial,"INIT","OBSERVATION","SEARCH_STRUCTURE | prospective warmup | max(stops,freeze) SL buffer | manual display only");
   g_ready=true;return INIT_SUCCEEDED;
  }
void OnTick(){if(!g_ready)return;FeedClosed();static datetime last=0;if(last!=TimeCurrent()){last=TimeCurrent();Panel();}}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {
   if(!g_ready || trans.type!=TRADE_TRANSACTION_DEAL_ADD || !HistoryDealSelect(trans.deal))return;
   if(HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=_Symbol || (ulong)HistoryDealGetInteger(trans.deal,DEAL_MAGIC)!=InpMagic)return;
   ulong pos=(ulong)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);
   ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   int index=-1;
   for(int i=0;i<ArraySize(g_records);i++)if(g_records[i].position_id==pos && pos>0){index=i;break;}
   if(index<0 && entry==DEAL_ENTRY_IN)
      for(int i=ArraySize(g_records)-1;i>=0;i--)if(g_records[i].pending){index=i;break;}
   if(index<0)return;
   W33Setup s=g_records[index].setup;
   double price=HistoryDealGetDouble(trans.deal,DEAL_PRICE),volume=HistoryDealGetDouble(trans.deal,DEAL_VOLUME);
   datetime when=(datetime)HistoryDealGetInteger(trans.deal,DEAL_TIME);
   g_records[index].net_cash+=HistoryDealGetDouble(trans.deal,DEAL_PROFIT)+HistoryDealGetDouble(trans.deal,DEAL_COMMISSION)+HistoryDealGetDouble(trans.deal,DEAL_SWAP)+HistoryDealGetDouble(trans.deal,DEAL_FEE);
   if(entry==DEAL_ENTRY_IN)
     {
      g_records[index].position_id=pos;double prior=g_records[index].filled_volume;
      s.entry_price=(s.entry_price*prior+price*volume)/(prior+volume);g_records[index].filled_volume+=volume;
      s.fill_at=when;s.risk_points=MathAbs(s.entry_price-s.sl_price)/_Point;s.entry_status="FILLED";s.state=POSITION_TRACKING;
      s.actual_rr=s.direction*(s.tp_price-s.entry_price)/(s.risk_points*_Point);
      double risk=0;
      if(OrderCalcProfit(s.direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,g_records[index].filled_volume,s.entry_price,s.sl_price,risk))
         g_records[index].initial_risk_money=MathAbs(risk);
      else Emit(s,"RISK_RECALC_FAILED","MEASUREMENT","fill risk uses pre-order estimate error="+IntegerToString(GetLastError()));
      g_records[index].pending=false;
      g_engine.MarkExecution(s.setup_id,true,TimeCurrent());Emit(s,"FILL","OBSERVATION","position filled");
     }
   else if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY)
     {
      g_records[index].exit_volume+=volume;
      bool closed=g_records[index].exit_volume>=g_records[index].filled_volume-1e-8;
      s.exit_at=when;s.exit_reason=EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal,DEAL_REASON));
      s.realized_r=g_records[index].initial_risk_money>0?g_records[index].net_cash/g_records[index].initial_risk_money:0;
      s.entry_status=closed?"CLOSED":"PARTIAL_EXIT";
      Emit(s,closed?"EXIT":"PARTIAL_EXIT","OBSERVATION",s.exit_reason);
      if(closed)g_engine.MarkExecution(s.setup_id,false,TimeCurrent());
     }
   g_records[index].setup=s;Panel();
  }
void OnDeinit(const int reason)
  {
   if(!g_ready)return;
   Drain();
   for(int d=-1;d<=1;d+=2)
     {
      W33Setup s;g_engine.GetActive(d,s);if(s.setup_id=="" || !s.active)continue;
      MergeExecution(s);Emit(s,"TEST_END","OBSERVATION","CENSORED_AT_STOP reason="+IntegerToString(reason));
     }
   g_ledger.Close();if(!InpKeepObjects)g_display.Clear();ChartRedraw();g_ready=false;
  }
