#property strict
#property version "1.00"
#property description "Validation EA: confirmed M5 HL, post-confirmation M1 breakout, 50% Buy Limit."
#include "../Include/SwingStructure/HLFib50.mqh"

input ulong InpMagicNumber=260915501;
input int InpSLBufferPoints=10;
input int InpLowerLeftBars=2;
input int InpLowerRightBars=2;
input int InpHigherLeftBars=2;
input int InpHigherRightBars=2;
input int InpHistoryBars=6000;
input bool InpAllowDeferredProtection=true;
input bool InpShowMarkers=true;
input bool InpWriteCSV=true;
input bool InpPreferServerExpiry=true; // Otherwise enforce expiry in Manage()
input double InpRewardRisk=1.2; // TP distance as a multiple of the SL distance
// Diagnostic only: exercise the requested deferred-SL/TP path in the tester.
input bool InpTestDeferredProtection=false;

const int LIFE_SECONDS=900;
const double RISK_FRACTION=0.01;
SSPivot lower_pivots[],higher_pivots[];
datetime lower_processed=0,higher_processed=0;
HFStructure setup;
HFPlan plan;
HFState state=WAIT_FOR_STRUCTURE;
datetime last_bar=0,started=0,used_structure=0,last_fill=0;
int journal=INVALID_HANDLE,csv=INVALID_HANDLE;
string prefix,reason="INITIALIZING",delete_reason="",entry_reason="";
bool blocked=false,cancel_latched=false;
string cancel_reason="";
long observed_order_count=-1,observed_position_count=-1;
ulong observed_order=0,observed_position=0;

string TS(const datetime t) { return t>0 ? TimeToString(t,TIME_DATE|TIME_SECONDS) : "-"; }
string ID(const datetime t) { return IntegerToString((long)t); }
double Price(const double p) { return NormalizeDouble(p,_Digits); }
void Transition(const HFState next,const string why)
{
   if(state!=next || reason!=why)
      Print("HF_STATE ",EnumToString(state)," -> ",EnumToString(next)," id=",ID(setup.new_low.bar_time)," reason=",why);
   state=next; reason=why;
}

// Exclusive journal handle doubles as an instance lock in this terminal.
// Append before sending an order: an uncertain send must never be blindly retried.
bool Save()
{
   if(journal==INVALID_HANDLE) return false;
   FileSeek(journal,0,SEEK_END);
   ResetLastError();
   uint bytes=FileWrite(journal,"HF3",(long)used_structure,(long)last_fill,
                        (long)plan.structure_id,(long)plan.placed,
                        DoubleToString(plan.low,10),DoubleToString(plan.entry,10),
                        DoubleToString(plan.sl,10),DoubleToString(plan.tp,10),
                        DoubleToString(plan.volume,8),DoubleToString(plan.loss,8),
                        (int)cancel_latched,cancel_reason,(int)blocked,
                        (long)plan.old_low.bar_time,(long)plan.old_low.confirmed_time,DoubleToString(plan.old_low.price,10),
                        (long)plan.new_low.bar_time,(long)plan.new_low.confirmed_time,DoubleToString(plan.new_low.price,10),
                        (long)plan.reference_high.bar_time,(long)plan.reference_high.confirmed_time,DoubleToString(plan.reference_high.price,10),
                        (long)plan.breakout_high.bar_time,(long)plan.breakout_high.confirmed_time,DoubleToString(plan.breakout_high.price,10),
                        (long)plan.cross_time,"END");
   FileFlush(journal);
   if(bytes==0 || GetLastError()!=0)
   { blocked=true; Transition(RECOVERY_BLOCKED,"JOURNAL_WRITE_FAILED"); return false; }
   return true;
}

bool LoadJournal()
{
   while(!FileIsEnding(journal))
   {
      string version=FileReadString(journal);
      if(version=="" && FileIsEnding(journal)) break;
      int fields=(version=="HF3" ? 27 : 14);
      if(version!="HF2" && version!="HF3") return false;
      string f[]; ArrayResize(f,fields);
      for(int i=0;i<fields;i++) f[i]=FileReadString(journal);
      if(f[fields-1]!="END") return false;
      used_structure=(datetime)StringToInteger(f[0]);
      last_fill=(datetime)StringToInteger(f[1]);
      plan.structure_id=(datetime)StringToInteger(f[2]);
      plan.placed=(datetime)StringToInteger(f[3]);
      plan.low=StringToDouble(f[4]); plan.entry=StringToDouble(f[5]);
      plan.sl=StringToDouble(f[6]); plan.tp=StringToDouble(f[7]);
      plan.volume=StringToDouble(f[8]); plan.loss=StringToDouble(f[9]);
      cancel_latched=(StringToInteger(f[10])!=0); cancel_reason=f[11];
      blocked=(StringToInteger(f[12])!=0);
      if(version=="HF3")
      {
         plan.old_low.bar_time=(datetime)StringToInteger(f[13]);
         plan.old_low.confirmed_time=(datetime)StringToInteger(f[14]); plan.old_low.price=StringToDouble(f[15]);
         plan.new_low.bar_time=(datetime)StringToInteger(f[16]);
         plan.new_low.confirmed_time=(datetime)StringToInteger(f[17]); plan.new_low.price=StringToDouble(f[18]);
         plan.reference_high.bar_time=(datetime)StringToInteger(f[19]);
         plan.reference_high.confirmed_time=(datetime)StringToInteger(f[20]); plan.reference_high.price=StringToDouble(f[21]);
         plan.reference_high.high=true;
         plan.breakout_high.bar_time=(datetime)StringToInteger(f[22]);
         plan.breakout_high.confirmed_time=(datetime)StringToInteger(f[23]); plan.breakout_high.price=StringToDouble(f[24]);
         plan.breakout_high.high=true; plan.cross_time=(datetime)StringToInteger(f[25]);
      }
   }
   return true;
}

bool MineOrder()
{ return OrderGetString(ORDER_SYMBOL)==_Symbol && (ulong)OrderGetInteger(ORDER_MAGIC)==InpMagicNumber; }
bool MinePosition()
{ return PositionGetString(POSITION_SYMBOL)==_Symbol && (ulong)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber; }

void Counts(int &orders,int &positions,int &foreign,ulong &order,ulong &position)
{
   orders=0; positions=0; foreign=0; order=0; position=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i);
      if(t==0 || OrderGetString(ORDER_SYMBOL)!=_Symbol) continue;
      if(MineOrder()) { orders++; order=t; } else foreign++;
   }
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(t==0 || PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(MinePosition()) { positions++; position=t; } else foreign++;
   }
}

bool ResultOK(const uint code)
{ return code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_PLACED || code==TRADE_RETCODE_DONE_PARTIAL; }

bool Cancel(const ulong ticket,const string why)
{
   if(!OrderSelect(ticket)) return true;
   if(!MineOrder()) return false;
   MqlTradeRequest req={}; MqlTradeResult res={};
   req.action=TRADE_ACTION_REMOVE; req.order=ticket; req.symbol=_Symbol; req.magic=InpMagicNumber;
   bool sent=OrderSend(req,res);
   Print("HF_CANCEL ticket=",ticket," reason=",why," retcode=",res.retcode," comment=",res.comment);
   delete_reason=why;
   return sent && ResultOK(res.retcode);
}

ENUM_ORDER_TYPE_FILLING MarketFilling()
{
   long flags=SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   if((flags & SYMBOL_FILLING_FOK)!=0) return ORDER_FILLING_FOK;
   if((flags & SYMBOL_FILLING_IOC)!=0) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

bool EmergencyClose(const ulong ticket,const string why)
{
   if(!PositionSelectByTicket(ticket) || !MinePosition()) return false;
   // Closing an existing long only; never a market entry or a short position.
   if(PositionGetInteger(POSITION_TYPE)!=POSITION_TYPE_BUY) return false;
   MqlTick tick; if(!SymbolInfoTick(_Symbol,tick)) return false;
   MqlTradeRequest req={}; MqlTradeResult res={};
   req.action=TRADE_ACTION_DEAL; req.position=ticket; req.symbol=_Symbol;
   req.magic=InpMagicNumber; req.type=ORDER_TYPE_SELL;
   req.volume=PositionGetDouble(POSITION_VOLUME); req.price=tick.bid;
   req.type_filling=MarketFilling(); req.deviation=20;
   bool sent=OrderSend(req,res);
   Print("HF_EMERGENCY_CLOSE ticket=",ticket," reason=",why," retcode=",res.retcode);
   return sent && ResultOK(res.retcode);
}

bool PositionOwnedExclusively(const ulong ticket)
{
   if(!PositionSelectByTicket(ticket) || !MinePosition()) return false;
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) return true;
   const ulong identifier=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   if(!HistorySelectByPosition(identifier)) return false;
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong d=HistoryDealGetTicket(i);
      long type=HistoryDealGetInteger(d,DEAL_TYPE);
      if(type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL) continue;
      if((ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagicNumber) return false;
   }
   return PositionSelectByTicket(ticket);
}

void Protect(const ulong ticket)
{
   if(!PositionOwnedExclusively(ticket))
   { blocked=true; Transition(RECOVERY_BLOCKED,"POSITION_OWNERSHIP_UNCLEAR"); return; }
   if(PositionGetInteger(POSITION_TYPE)!=POSITION_TYPE_BUY)
   { blocked=true; Transition(RECOVERY_BLOCKED,"UNEXPECTED_OWN_POSITION_TYPE"); return; }
   if(PositionGetDouble(POSITION_SL)>0 && PositionGetDouble(POSITION_TP)>0) return;
   if(plan.structure_id==0 || plan.sl<=0 || plan.tp<=plan.sl)
   {
      blocked=true;
      EmergencyClose(ticket,"MISSING_PROTECTION_PLAN"); return;
   }
   MqlTick tick; if(!SymbolInfoTick(_Symbol,tick)) return;
   if(tick.bid<=plan.sl || tick.bid>=plan.tp)
   { EmergencyClose(ticket,"PLANNED_EXIT_ALREADY_CROSSED"); return; }
   MqlTradeRequest req={}; MqlTradeResult res={};
   req.action=TRADE_ACTION_SLTP; req.position=ticket; req.symbol=_Symbol;
   req.magic=InpMagicNumber; req.sl=plan.sl; req.tp=plan.tp;
   bool sent=OrderSend(req,res);
   Print("HF_PROTECT ticket=",ticket," sl=",plan.sl," tp=",plan.tp," retcode=",res.retcode);
   if(!sent || !ResultOK(res.retcode)) EmergencyClose(ticket,"SLTP_ATTACH_FAILED");
}

// Reconcile actual fills, including fills occurring while EA was stopped.
void RecoverFills()
{
   datetime from=(plan.placed>0 ? plan.placed-60 : TimeCurrent()-86400);
   if(!HistorySelect(from,TimeCurrent())) { blocked=true; reason="HISTORY_UNAVAILABLE"; return; }
   datetime newest=last_fill;
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong d=HistoryDealGetTicket(i);
      if(HistoryDealGetString(d,DEAL_SYMBOL)!=_Symbol ||
         (ulong)HistoryDealGetInteger(d,DEAL_MAGIC)!=InpMagicNumber) continue;
      if(HistoryDealGetInteger(d,DEAL_TYPE)!=DEAL_TYPE_BUY || HistoryDealGetInteger(d,DEAL_ENTRY)!=DEAL_ENTRY_IN) continue;
      datetime t=(datetime)HistoryDealGetInteger(d,DEAL_TIME);
      // First fill of the single order starts cooldown, not its placement time.
      if(plan.placed>0 && t>=plan.placed && (newest<plan.placed || t<newest)) newest=t;
      else if(plan.placed==0 && t>newest) newest=t;
   }
   if(newest!=last_fill)
   {
      last_fill=newest; Save();
      Print("HF_FILL time=",TS(last_fill)," cooldown_until=",TS(last_fill+LIFE_SECONDS));
   }
}

void Manage()
{
   int orders,positions,foreign; ulong order,position;
   Counts(orders,positions,foreign,order,position);
   if(orders!=observed_order_count || positions!=observed_position_count ||
      order!=observed_order || position!=observed_position)
   {
      RecoverFills();
      Print("HF_INVENTORY own_orders=",orders," own_positions=",positions," foreign=",foreign,
            " order=",order," position=",position);
      observed_order_count=orders; observed_position_count=positions;
      observed_order=order; observed_position=position;
   }
   MqlTick tick; if(!SymbolInfoTick(_Symbol,tick)) return;
   if(positions>0) Protect(position);
   if(orders>1 || positions>1) { blocked=true; Transition(RECOVERY_BLOCKED,"MULTIPLE_OWN_EXPOSURES"); }
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i); if(t==0 || !MineOrder()) continue;
      string why="";
      if(OrderGetInteger(ORDER_TYPE)!=ORDER_TYPE_BUY_LIMIT) why="UNEXPECTED_ORDER_TYPE";
      else if(plan.structure_id==0 || plan.placed==0) why="MISSING_RECOVERY_PLAN";
      else if(MathAbs(OrderGetDouble(ORDER_PRICE_OPEN)-plan.entry)>SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE)*0.5) why="PLAN_ORDER_MISMATCH";
      else if(blocked) why="RECOVERY_BLOCKED";
      else if(cancel_latched) why=cancel_reason;
      else if(positions>0) why="CANCEL_REMAINDER_AFTER_FILL";
      else if(TimeCurrent()>=(datetime)OrderGetInteger(ORDER_TIME_SETUP)+LIFE_SECONDS) why="EXPIRED_15_MINUTES";
      else if(tick.bid<plan.low) why="M5_LOW_BROKEN";
      if(why!="")
      {
         bool changed=(!cancel_latched || cancel_reason!=why);
         cancel_latched=true; cancel_reason=why;
         if(changed) Save();
         Cancel(t,why);
      }
   }
}

bool Source(const ENUM_TIMEFRAMES tf,const int left,const int right,const datetime now,
            datetime &processed,SSPivot &pivots[],MqlRates &rates[])
{
   int wanted=InpHistoryBars;
   if(processed>0)
   {
      int shift=iBarShift(_Symbol,tf,processed,true);
      if(shift<0) return false;
      wanted=MathMax(left+right+3,shift+left+1);
   }
   ArraySetAsSeries(rates,false);
   int n=CopyRates(_Symbol,tf,0,wanted,rates);
   if(n<left+right+2 || !SeriesInfoInteger(_Symbol,tf,SERIES_SYNCHRONIZED)) return false;
   if(processed>0 && n<wanted) return false;
   if(rates[n-1].time>now || now>=rates[n-1].time+PeriodSeconds(tf)) return false;
   SSCollect(rates,n,left,right,processed,pivots);
   return true;
}

void Mark(const string key,const SSPivot &p,const string label,const color c)
{
   if(!InpShowMarkers || p.bar_time==0) return;
   string name=prefix+ID(setup.new_low.bar_time)+"_"+key;
   if(ObjectFind(0,name)>=0) return;
   if(!ObjectCreate(0,name,OBJ_ARROW,0,p.bar_time,p.price)) return;
   ObjectSetInteger(0,name,OBJPROP_ARROWCODE,p.high ? 234 : 233);
   ObjectSetInteger(0,name,OBJPROP_COLOR,c);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,p.high ? ANCHOR_BOTTOM : ANCHOR_TOP);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   string details="Structure "+ID(setup.new_low.bar_time)+" "+label+
                  "\nprice="+DoubleToString(p.price,_Digits)+"\npivot="+TS(p.bar_time)+"\nconfirmed="+TS(p.confirmed_time);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,details);
   string text=name+"t";
   ObjectCreate(0,text,OBJ_TEXT,0,p.bar_time,p.price);
   ObjectSetString(0,text,OBJPROP_TEXT,key+" #"+ID(setup.new_low.bar_time));
   ObjectSetInteger(0,text,OBJPROP_COLOR,c);
   ObjectSetInteger(0,text,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,text,OBJPROP_ANCHOR,p.high ? ANCHOR_LEFT_LOWER : ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,text,OBJPROP_SELECTABLE,false);
   ObjectSetString(0,text,OBJPROP_TOOLTIP,details);
}

void Level(const string key,const double value,const color c,const datetime placed)
{
   if(!InpShowMarkers || value<=0) return;
   string name=prefix+ID(setup.new_low.bar_time)+"_"+key;
   if(ObjectFind(0,name)>=0) return;
   ObjectCreate(0,name,OBJ_TREND,0,placed,value,placed+LIFE_SECONDS,value);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_COLOR,c);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DASH);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,key+" #"+ID(setup.new_low.bar_time)+" "+DoubleToString(value,_Digits)+" placed="+TS(placed));
}

void MarkPlan()
{
   Mark("L0",setup.old_low,"M5 older low",clrSlateBlue);
   Mark("L1",setup.new_low,"M5 higher low / Fibonacci bottom",clrAqua);
   Mark("H5",setup.reference_high,"Frozen M5 breakout reference",clrOrange);
   Mark("H1",setup.breakout_high,"Confirmed M1 high / Fibonacci top",clrLime);
   datetime placed=(plan.placed>0 ? plan.placed : TimeCurrent());
   Level("FIB50",(setup.new_low.price+setup.breakout_high.price)*0.5,clrGold,placed);
   Level("LIMIT",plan.entry,clrGold,placed);
   Level("SL",plan.sl,clrRed,placed); Level("TP",plan.tp,clrLime,placed);
}

void Display()
{
   if(!InpShowMarkers) return;
   string lines[8];
   lines[0]="USDJPY HL/Fib50 "+EnumToString(state)+" #"+ID(setup.new_low.bar_time);
   lines[1]="M5 L0="+DoubleToString(setup.old_low.price,_Digits)+" L1="+DoubleToString(setup.new_low.price,_Digits)+" HL="+(setup.valid ? "YES" : "NO");
   lines[2]="M5 H="+DoubleToString(setup.reference_high.price,_Digits)+" M1 H="+DoubleToString(setup.breakout_high.price,_Digits);
   lines[3]="Limit="+DoubleToString(plan.entry,_Digits)+" SL="+DoubleToString(plan.sl,_Digits)+" TP="+DoubleToString(plan.tp,_Digits);
   lines[4]="Placed="+TS(plan.placed)+" fill="+TS(last_fill);
   lines[5]="Entry: "+entry_reason;
   lines[6]="Delete: "+delete_reason;
   lines[7]="Reason: "+reason;
   for(int i=0;i<8;i++)
   {
      string name=prefix+"status"+IntegerToString(i);
      if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,10);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,20+i*17);
      ObjectSetInteger(0,name,OBJPROP_COLOR,ChartGetInteger(0,CHART_COLOR_FOREGROUND));
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
      ObjectSetString(0,name,OBJPROP_TEXT,lines[i]);
   }
}

void Diagnostic(const datetime now,const bool accepted)
{
   int orders,positions,foreign; ulong order,position;
   Counts(orders,positions,foreign,order,position);
   if(csv!=INVALID_HANDLE)
   {
      FileWrite(csv,TS(now),_Symbol,EnumToString(state),ID(setup.new_low.bar_time),
                setup.old_low.price,TS(setup.old_low.bar_time),TS(setup.old_low.confirmed_time),
                setup.new_low.price,TS(setup.new_low.bar_time),TS(setup.new_low.confirmed_time),
                setup.reference_high.price,TS(setup.reference_high.bar_time),TS(setup.reference_high.confirmed_time),
                TS(setup.cross_time),setup.breakout_high.price,TS(setup.breakout_high.bar_time),TS(setup.breakout_high.confirmed_time),
                (setup.breakout_high.price>0 ? (setup.new_low.price+setup.breakout_high.price)*0.5 : 0),
                plan.entry,plan.sl,plan.tp,plan.entry-plan.sl,plan.volume,plan.loss,
                AccountInfoDouble(ACCOUNT_EQUITY),accepted,reason,orders,positions,foreign,
                TS(plan.placed),TS(last_fill),delete_reason,entry_reason);
      FileFlush(csv);
   }
   Print("HF_M1 ",TS(now)," ",EnumToString(state)," accepted=",accepted," reason=",reason,
         " orders=",orders," positions=",positions," foreign=",foreign);
   Display();
}

bool MakePlan()
{
   double step=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double vmax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double vstep=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(step<=0 || vmin<=0 || vmax<vmin || vstep<=0 || SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE)<=0)
   { reason="INVALID_SYMBOL_SPEC"; return false; }
   ZeroMemory(plan);
   plan.structure_id=setup.new_low.bar_time; plan.low=setup.new_low.price;
   plan.old_low=setup.old_low; plan.new_low=setup.new_low;
   plan.reference_high=setup.reference_high; plan.breakout_high=setup.breakout_high;
   plan.cross_time=setup.cross_time;
   plan.entry=Price(HFFloor((plan.low+setup.breakout_high.price)*0.5,step));
   plan.sl=Price(HFFloor(plan.low-InpSLBufferPoints*_Point,step));
   plan.tp=Price(MathRound((plan.entry+(plan.entry-plan.sl)*InpRewardRisk)/step)*step);
   if(plan.sl<=0 || plan.entry<=plan.sl || plan.tp<=plan.entry)
   { reason="INVALID_PRICE_GEOMETRY"; return false; }
   double stops=SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   MqlTick tick; if(!SymbolInfoTick(_Symbol,tick)) { reason="NO_QUOTE"; return false; }
   if(tick.ask<=plan.entry || tick.ask-plan.entry+step*1e-6<stops)
   { reason="LIMIT_NOT_BELOW_ASK_OR_BROKER_DISTANCE"; return false; }
   if(plan.entry-plan.sl+step*1e-6<stops || plan.tp-plan.entry+step*1e-6<stops)
   { reason="BROKER_STOPS_DISTANCE"; return false; }
   double loss=0;
   if(!OrderCalcProfit(ORDER_TYPE_BUY,_Symbol,vmin,plan.entry,plan.sl,loss) || loss>=0)
   { reason="RISK_CONVERSION_FAILED"; return false; }
   double budget=AccountInfoDouble(ACCOUNT_EQUITY)*RISK_FRACTION;
   double volume=HFFloor(MathMin(vmax,budget/(-loss/vmin)),vstep);
   if(volume<vmin-1e-9) { reason="MIN_LOT_EXCEEDS_ONE_PERCENT"; return false; }
   double margin=0;
   if(!OrderCalcMargin(ORDER_TYPE_BUY,_Symbol,volume,plan.entry,margin))
   { reason="MARGIN_CALC_FAILED"; return false; }
   double free=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(margin>free && margin>0) volume=HFFloor(volume*free/margin,vstep);
   if(volume<vmin-1e-9) { reason="INSUFFICIENT_MARGIN"; return false; }
   // Volume is rounded down to the broker step.  Recalculate after the
   // rounding/margin adjustment and, if floating-point conversion still puts
   // the loss a little above the budget, step down one more volume increment.
   // Do not reject an otherwise valid signal merely because of a tiny
   // OrderCalcProfit rounding difference.
   volume=HFFloor(volume,vstep);
   while(volume>=vmin-1e-9)
   {
      plan.volume=NormalizeDouble(volume,8);
      if(!OrderCalcProfit(ORDER_TYPE_BUY,_Symbol,plan.volume,plan.entry,plan.sl,loss))
      { reason="FINAL_LOSS_CALC_FAILED"; return false; }
      plan.loss=-loss;
      const double tolerance=MathMax(1e-8,budget*1e-10);
      if(plan.loss<=budget+tolerance) break;
      volume=HFFloor(volume-vstep,vstep);
   }
   if(volume<vmin-1e-9 || plan.volume<vmin-1e-9)
   { reason="ROUNDING_RISK_EXCEEDED"; return false; }
   Print("HF_RISK equity=",AccountInfoDouble(ACCOUNT_EQUITY)," budget=",budget," expected_loss=",plan.loss,
         " lots=",plan.volume," tick_size=",step," tick_value_loss=",SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE_LOSS),
         " contract=",SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE)," currency=",AccountInfoString(ACCOUNT_CURRENCY),
         " actual_RR=",(plan.tp-plan.entry)/(plan.entry-plan.sl));
   return true;
}

bool Place()
{
   if(!MakePlan()) return false;
   long mode=SymbolInfoInteger(_Symbol,SYMBOL_ORDER_MODE);
   if((mode & SYMBOL_ORDER_LIMIT)==0 || (mode & SYMBOL_ORDER_SL)==0 || (mode & SYMBOL_ORDER_TP)==0)
   { reason="BROKER_ORDER_MODE_UNSUPPORTED"; return false; }
   MqlTradeRequest req={}; MqlTradeResult res={}; MqlTradeCheckResult check={};
   req.action=TRADE_ACTION_PENDING; req.symbol=_Symbol; req.magic=InpMagicNumber;
   req.type=ORDER_TYPE_BUY_LIMIT; req.type_filling=ORDER_FILLING_RETURN;
   req.price=plan.entry; req.volume=plan.volume; req.sl=plan.sl; req.tp=plan.tp;
   req.comment="HF:"+ID(plan.structure_id);
   // Prefer server expiry so it also works during a disconnection.
   // GTC remains available where a broker does not support specified expiry.
   long expiry=SymbolInfoInteger(_Symbol,SYMBOL_EXPIRATION_MODE);
   if(InpPreferServerExpiry && (expiry & SYMBOL_EXPIRATION_SPECIFIED)!=0)
   { req.type_time=ORDER_TIME_SPECIFIED; req.expiration=TimeCurrent()+LIFE_SECONDS; }
   else if((expiry & SYMBOL_EXPIRATION_GTC)!=0) req.type_time=ORDER_TIME_GTC;
   else if((expiry & SYMBOL_EXPIRATION_SPECIFIED)!=0)
   { req.type_time=ORDER_TIME_SPECIFIED; req.expiration=TimeCurrent()+LIFE_SECONDS; }
   else { reason="BROKER_EXPIRY_UNSUPPORTED"; return false; }
   bool deferred=InpTestDeferredProtection;
   ResetLastError();
   bool valid=OrderCheck(req,check);
   const int check_error=GetLastError();
   Print("HF_CHECK stage=WITH_SLTP valid=",valid,
         " retcode=",check.retcode," comment=",check.comment,
         " error=",check_error," balance=",check.balance,
         " equity=",check.equity," margin=",check.margin,
         " margin_free=",check.margin_free,
         " price=",req.price," sl=",req.sl," tp=",req.tp,
         " volume=",req.volume," type_time=",req.type_time,
         " type_filling=",req.type_filling);
   if(!valid || check.retcode!=TRADE_RETCODE_DONE)
   {
      if(check.retcode==TRADE_RETCODE_INVALID_STOPS && InpAllowDeferredProtection) deferred=true;
      else if(valid && check.retcode==0 && check_error==0)
      {
         // MT5 tester returns true/0/0 on a successful check in this environment.
         // A false result with retcode 0 is NOT success and must not be sent.
         Print("HF_CHECK_SUCCESS_ZERO_RETCODE");
      }
      else { reason="ORDER_CHECK_"+IntegerToString(check.retcode)+"_"+check.comment; return false; }
   }
   if(deferred)
   {
      req.sl=0; req.tp=0;
      ResetLastError();
      bool deferred_valid=OrderCheck(req,check);
      const int deferred_error=GetLastError();
      Print("HF_CHECK stage=WITHOUT_SLTP valid=",deferred_valid,
            " retcode=",check.retcode," comment=",check.comment,
            " error=",deferred_error," price=",req.price,
            " volume=",req.volume," type_time=",req.type_time,
            " type_filling=",req.type_filling);
      if(!deferred_valid || check.retcode!=TRADE_RETCODE_DONE)
      {
         if(deferred_valid && check.retcode==0 && deferred_error==0)
            Print("HF_CHECK_DEFERRED_SUCCESS_ZERO_RETCODE");
         else
         { reason="DEFERRED_CHECK_"+IntegerToString(check.retcode)+"_"+check.comment; return false; }
      }
   }
   plan.placed=TimeCurrent();
   used_structure=plan.structure_id;
   cancel_latched=false; cancel_reason="";
   if(!Save()) return false;
   bool sent=OrderSend(req,res);
   if(!deferred && res.retcode==TRADE_RETCODE_INVALID_STOPS && InpAllowDeferredProtection)
   {
      // Definitive rejection only: never resend after a timeout/unknown response.
      req.sl=0; req.tp=0; deferred=true;
      ResetLastError();
      if(OrderCheck(req,check) && (check.retcode==TRADE_RETCODE_DONE ||
         (check.retcode==0 && GetLastError()==0))) sent=OrderSend(req,res);
   }
   Print("HF_ORDER id=",ID(plan.structure_id)," ticket=",res.order," retcode=",res.retcode,
         " entry=",plan.entry," sl=",plan.sl," tp=",plan.tp," deferred=",deferred," comment=",res.comment);
   if(!sent || !ResultOK(res.retcode))
   {
      if(res.retcode==TRADE_RETCODE_TIMEOUT || res.retcode==TRADE_RETCODE_CONNECTION || res.retcode==0)
      { blocked=true; Save(); }
      Transition(STRUCTURE_CONSUMED,"SEND_FAILED_NO_RETRY_"+IntegerToString(res.retcode)); return false;
   }
   entry_reason="M5_HL_POST_CONFIRM_M1_BREAK_FIB50";
   MarkPlan();
   Transition(BUY_LIMIT_PLACED,deferred ? "LIMIT_PLACED_DEFERRED_PROTECTION" : "LIMIT_PLACED_WITH_SLTP");
   return true;
}

bool Evaluate(const datetime now)
{
   if(blocked) { Transition(RECOVERY_BLOCKED,"RECOVERY_OR_STORAGE_BLOCK"); return false; }
   MqlRates lower[],higher[];
   bool lo=Source(PERIOD_M1,InpLowerLeftBars,InpLowerRightBars,now,lower_processed,lower_pivots,lower);
   bool hi=Source(PERIOD_M5,InpHigherLeftBars,InpHigherRightBars,now,higher_processed,higher_pivots,higher);
   if(!lo || !hi) { reason="DATA_NOT_READY_SKIP_THIS_M1"; return false; }
   HFStructure next; string why;
   HFBuild(higher_pivots,now,next,why);
   if(next.new_low.bar_time!=setup.new_low.bar_time)
   {
      if(plan.structure_id>0 && next.new_low.bar_time>plan.structure_id)
      { cancel_latched=true; cancel_reason="NEW_M5_STRUCTURE"; Save(); Manage(); }
      setup=next;
      Transition(setup.valid ? BULLISH_STRUCTURE_CONFIRMED : WAIT_FOR_STRUCTURE,why);
   }
   int orders,positions,foreign; ulong order,position;
   Counts(orders,positions,foreign,order,position);
   if(positions>0) { Transition(POSITION_OPEN,"POSITION_ACTIVE"); return false; }
   if(orders>0 && plan.placed>0)
   {
      MqlRates since_order[];
      int copied=CopyRates(_Symbol,PERIOD_M1,plan.placed,now-1,since_order);
      for(int i=0;i<copied;i++)
         if(since_order[i].time>=plan.placed && since_order[i].low<plan.low)
         { cancel_latched=true; cancel_reason="HISTORY_M5_LOW_BROKEN"; Save(); Manage(); break; }
      Counts(orders,positions,foreign,order,position);
   }
   if(orders>0) { Transition(BUY_LIMIT_PLACED,"ORDER_ACTIVE"); return false; }
   if(TimeCurrent()<last_fill+LIFE_SECONDS) { Transition(COOLDOWN,"FILL_COOLDOWN_15_MINUTES"); return false; }
   if(foreign>0) { reason="FOREIGN_USDJPY_EXPOSURE"; return false; }
   if(!setup.valid) { Transition(WAIT_FOR_STRUCTURE,why); return false; }
   if(setup.new_low.bar_time<=used_structure) { Transition(STRUCTURE_CONSUMED,"STRUCTURE_ALREADY_USED_OR_INVALIDATED"); return false; }
   MqlTick tick; if(!SymbolInfoTick(_Symbol,tick)) { reason="NO_QUOTE"; return false; }
   if(tick.bid<setup.new_low.price)
   { used_structure=setup.new_low.bar_time; Save(); Transition(INVALIDATED,"M5_LOW_BROKEN"); return false; }
   // Scan closed M1 bars after the low was known. Do not infer intrabar ordering.
   // Incremental CopyRates window may be short; backfill from structure confirmation.
   MqlRates scan[]; ArraySetAsSeries(scan,false);
   int count=CopyRates(_Symbol,PERIOD_M1,setup.new_low.confirmed_time-60,now-1,scan);
   if(count<2) { Transition(WAIT_FOR_M1_BREAKOUT,"WAIT_POST_CONFIRM_BARS"); return false; }
   for(int i=1;i<count;i++)
   {
      if(scan[i].time+60>now || scan[i].time<=setup.scanned || scan[i].time<setup.new_low.confirmed_time) continue;
      if(scan[i].low<setup.new_low.price)
      { used_structure=setup.new_low.bar_time; Save(); Transition(INVALIDATED,"CLOSED_BAR_M5_LOW_BROKEN"); return false; }
      if(setup.cross_time==0 && HFCross(scan[i-1],scan[i],setup)) setup.cross_time=scan[i].time;
      setup.scanned=scan[i].time;
   }
   Transition(WAIT_FOR_M1_BREAKOUT,setup.cross_time>0 ? "WAIT_CONFIRMED_BREAKOUT_HIGH" : "WAIT_POST_CONFIRM_CROSS");
   for(int i=0;i<ArraySize(lower_pivots);i++)
   {
      if(lower_pivots[i].confirmed_time<=started || !HFEligibleHigh(lower_pivots[i],setup,now)) continue;
      setup.breakout_high=lower_pivots[i];
      Transition(BREAKOUT_CONFIRMED,"M1_HIGH_CONFIRMED_AFTER_CROSS");
      Transition(WAIT_FOR_50_PERCENT_PULLBACK,"PREPARING_BUY_LIMIT");
      return Place();
   }
   return false;
}

int OnInit()
{
   if(_Symbol!="USDJPY" || _Period!=PERIOD_M1 || InpMagicNumber==0 || InpSLBufferPoints<0 ||
      InpRewardRisk<=0.0 || InpRewardRisk>20.0 ||
      InpLowerLeftBars<1 || InpLowerRightBars<1 || InpHigherLeftBars<1 || InpHigherRightBars<1 ||
      InpLowerLeftBars>1000 || InpLowerRightBars>1000 || InpHigherLeftBars>1000 || InpHigherRightBars>1000 ||
      InpHistoryBars<MathMax(InpLowerLeftBars+InpLowerRightBars+2,InpHigherLeftBars+InpHigherRightBars+2) ||
      (InpTestDeferredProtection && !MQLInfoInteger(MQL_TESTER))) return INIT_PARAMETERS_INCORRECT;
   started=TimeCurrent(); last_bar=iTime(_Symbol,PERIOD_M1,0);
   string identity=AccountInfoString(ACCOUNT_SERVER)+"_"+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+"_"+IntegerToString((long)InpMagicNumber);
   StringReplace(identity,"\\","_"); StringReplace(identity,"/","_"); StringReplace(identity,":","_");
   string filename="HF_USDJPY_"+identity+".csv";
   // Tester runs are independent experiments; live terminal journal persists.
   if(MQLInfoInteger(MQL_TESTER)) FileDelete(filename);
   journal=FileOpen(filename,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(journal==INVALID_HANDLE) { Print("HF_INIT journal locked/unavailable ",GetLastError()); return INIT_FAILED; }
   if(!LoadJournal()) { blocked=true; reason="CORRUPT_JOURNAL"; }
   prefix="HF_"+IntegerToString((long)InpMagicNumber)+"_";
   if(plan.new_low.bar_time>0)
   {
      setup.old_low=plan.old_low; setup.new_low=plan.new_low;
      setup.reference_high=plan.reference_high; setup.breakout_high=plan.breakout_high;
      setup.cross_time=plan.cross_time; setup.valid=true;
      MarkPlan();
   }
   if(InpWriteCSV)
   {
      csv=FileOpen("HF_diagnostics_"+IntegerToString((long)InpMagicNumber)+".csv",FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ,',');
      if(csv==INVALID_HANDLE) return INIT_FAILED;
      if(FileSize(csv)==0) FileWrite(csv,"time","symbol","state","structure_id","old_low","old_low_time","old_low_confirmed","new_low","new_low_time","new_low_confirmed","m5_high","m5_high_time","m5_high_confirmed","cross_time","m1_high","m1_high_time","m1_high_confirmed","fib50","limit","sl","tp","sl_width","lots","expected_loss","equity","accepted","reason","orders","positions","foreign","placed","last_fill","delete_reason","entry_reason");
      FileSeek(csv,0,SEEK_END);
   }
   int own_orders,own_positions,foreign; ulong own_order,own_position;
   Counts(own_orders,own_positions,foreign,own_order,own_position);
   if(plan.structure_id==0 && (own_orders>0 || own_positions>0))
   { blocked=true; reason="EXISTING_EXPOSURE_WITHOUT_JOURNAL_PLAN"; }
   RecoverFills(); Manage();
   Print("HF_INIT recovered used_structure=",ID(used_structure)," placed=",TS(plan.placed)," last_fill=",TS(last_fill)," blocked=",blocked);
   Display();
   return INIT_SUCCEEDED;
}

void OnTick()
{
   Manage();
   datetime now=iTime(_Symbol,PERIOD_M1,0);
   if(now==0 || now==last_bar) return;
   last_bar=now; // Mark before evaluation: no intrabar retry of a signal.
   bool accepted=Evaluate(now);
   Diagnostic(now,accepted);
}

void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD && trans.symbol==_Symbol)
   { RecoverFills(); Manage(); Display(); }
   if(trans.type==TRADE_TRANSACTION_HISTORY_ADD && trans.order>0 && HistoryOrderSelect(trans.order))
   {
      if(HistoryOrderGetString(trans.order,ORDER_SYMBOL)!=_Symbol ||
         (ulong)HistoryOrderGetInteger(trans.order,ORDER_MAGIC)!=InpMagicNumber) return;
      long ended=HistoryOrderGetInteger(trans.order,ORDER_STATE);
      if(ended==ORDER_STATE_EXPIRED) delete_reason="EXPIRED_15_MINUTES_SERVER";
      else if(ended==ORDER_STATE_CANCELED && delete_reason=="") delete_reason="ORDER_CANCELED_EXTERNALLY";
      else if(ended!=ORDER_STATE_CANCELED) return;
      Print("HF_REMOVE ticket=",trans.order," reason=",delete_reason,
            " placed=",TS((datetime)HistoryOrderGetInteger(trans.order,ORDER_TIME_SETUP)),
            " removed=",TS((datetime)HistoryOrderGetInteger(trans.order,ORDER_TIME_DONE)));
      Display();
   }
}

void OnDeinit(const int why)
{
   if(journal!=INVALID_HANDLE) { FileFlush(journal); FileClose(journal); }
   if(csv!=INVALID_HANDLE) { FileFlush(csv); FileClose(csv); }
   // Preserve forensic markers in tester visual charts; remove only our objects otherwise.
   if(!MQLInfoInteger(MQL_TESTER) && prefix!="")
      for(int i=ObjectsTotal(0)-1;i>=0;i--)
      { string name=ObjectName(0,i); if(StringFind(name,prefix)==0) ObjectDelete(0,name); }
   Print("HF_DEINIT reason=",why," own pending orders remain server-side; EA management requires running terminal.");
}
