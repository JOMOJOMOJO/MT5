#property strict
#property version "1.00"
// Fixed research baseline; deliberately refuses attachment outside the tester.
#include <Trade/Trade.mqh>
// Read-only tester observer. Missing synchronous quotes are never interpolated.
#ifndef RESEARCH_DEAL_QUOTE_AUDIT
#define RESEARCH_DEAL_QUOTE_AUDIT
int dqFile=INVALID_HANDLE;
ulong dqSeen[];
string dqName="";
void DQStart(const string filename)
  {
   dqName=filename;
   dqFile=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(dqFile==INVALID_HANDLE){Print("DQ_FATAL_FILE");return;}
   FileWrite(dqFile,"deal","position_id","order","symbol","entry_kind","type","time_msc","price","volume",
      "sl","tp","profit","commission","swap","fee","bid","ask","quote_msc","quote_status","reason");
  }
void DQCapture(const ulong ticket)
  {
   if(dqFile==INVALID_HANDLE || ticket==0)return;
   for(int j=0;j<ArraySize(dqSeen);j++)if(dqSeen[j]==ticket)return;
   if(!HistoryDealSelect(ticket))return;
   long type=HistoryDealGetInteger(ticket,DEAL_TYPE);
   if(type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL)return;
   string symbol=HistoryDealGetString(ticket,DEAL_SYMBOL);
   long stamp=HistoryDealGetInteger(ticket,DEAL_TIME_MSC);
   MqlTick q;ZeroMemory(q);string status="MISSING";
   if(SymbolInfoTick(symbol,q) && q.time_msc==stamp && q.bid>0 && q.ask>=q.bid)status="CURRENT_EXACT_MSC";
   else
     {
      ZeroMemory(q);MqlTick a[];
      int n=CopyTicksRange(symbol,a,COPY_TICKS_ALL,(ulong)stamp,(ulong)stamp);
      bool ambiguous=false;
      for(int j=0;j<n;j++)
        {
         if(a[j].time_msc!=stamp || a[j].bid<=0 || a[j].ask<a[j].bid)continue;
         if(q.bid>0 && (q.bid!=a[j].bid || q.ask!=a[j].ask))ambiguous=true;
         q=a[j];
        }
      if(ambiguous){status="AMBIGUOUS_MSC";ZeroMemory(q);}
      else if(q.bid>0)status="HISTORY_EXACT_MSC";
     }
   ulong order=(ulong)HistoryDealGetInteger(ticket,DEAL_ORDER);
   double sl=0,tp=0;
   if(HistoryOrderSelect(order)){sl=HistoryOrderGetDouble(order,ORDER_SL);tp=HistoryOrderGetDouble(order,ORDER_TP);}
   FileWrite(dqFile,ticket,HistoryDealGetInteger(ticket,DEAL_POSITION_ID),order,symbol,
      HistoryDealGetInteger(ticket,DEAL_ENTRY),type,stamp,DoubleToString(HistoryDealGetDouble(ticket,DEAL_PRICE),12),
      DoubleToString(HistoryDealGetDouble(ticket,DEAL_VOLUME),8),DoubleToString(sl,12),DoubleToString(tp,12),
      DoubleToString(HistoryDealGetDouble(ticket,DEAL_PROFIT),8),DoubleToString(HistoryDealGetDouble(ticket,DEAL_COMMISSION),8),
      DoubleToString(HistoryDealGetDouble(ticket,DEAL_SWAP),8),DoubleToString(HistoryDealGetDouble(ticket,DEAL_FEE),8),
      DoubleToString(q.bid,12),DoubleToString(q.ask,12),q.time_msc,status,HistoryDealGetInteger(ticket,DEAL_REASON));
   int size=ArraySize(dqSeen);ArrayResize(dqSeen,size+1);dqSeen[size]=ticket;FileFlush(dqFile);
  }
void DQDrain()
  {
   if(!HistorySelect(0,TimeCurrent()))return;
   int n=HistoryDealsTotal();ulong ids[];ArrayResize(ids,n);
   for(int j=0;j<n;j++)ids[j]=HistoryDealGetTicket(j);
   for(int j=0;j<n;j++)DQCapture(ids[j]);
  }
void DQClose(){DQDrain();if(dqFile!=INVALID_HANDLE){FileClose(dqFile);dqFile=INVALID_HANDLE;}}
#endif

input string InpSymbols="USDJPY,EURUSD,GBPUSD,AUDUSD,XAUUSD";
input string InpTelemetryFileName="daily_channel.csv";
input ulong InpMagic=261008201;
input int InpEntryBars=20;
input int InpExitBars=10;
input int InpATRPeriod=14;
input double InpSLATR=2.0;
input double InpRiskPercent=0.25;
input double InpTotalRiskPercent=0.75;
input double InpUSDGroupRiskPercent=0.50;
input double InpDailyLossPercent=3.0;
input double InpPeakLossPercent=12.0;
CTrade dcTrade;
struct DCAsset{string name;int atr;datetime consumed;bool close_due;};
DCAsset dcAssets[];
int dcLog=INVALID_HANDLE,dcDay=-1;
datetime dcMinute=0;
double dcPeak=0,dcDayStart=0;
bool dcDailyStop=false,dcPeakStop=false,dcUncertain=false;
int dcErrors=0;
void DCLog(const string symbol,const datetime bar,const string reason,const double price=0,const double atr=0,
           const double level=0,const double sl=0,const double volume=0,const double risk=0,const uint retcode=0)
  {
   FileWrite(dcLog,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),symbol,TimeToString(bar,TIME_DATE|TIME_SECONDS),
     reason,DoubleToString(price,12),DoubleToString(atr,12),DoubleToString(level,12),DoubleToString(sl,12),
     DoubleToString(volume,8),DoubleToString(risk,8),DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY),8),retcode);
  }
int DCUSDGroup(const string symbol,const int side)
  {return StringSubstr(symbol,0,3)=="USD"?side:-side;}
double DCRisk(const string symbol,const ENUM_ORDER_TYPE type,const double volume,const double entry,const double sl)
  {
   double value=0;
   if(sl<=0 || !OrderCalcProfit(type,symbol,volume,entry,sl,value))return DBL_MAX;
   return MathMax(0.0,-value);
  }
bool DCRiskRoom(const int group,const double proposed,const double equity)
  {
   double total=proposed,same=proposed;
   for(int j=PositionsTotal()-1;j>=0;j--)
     {
      if(PositionGetTicket(j)==0)continue;
      string symbol=PositionGetString(POSITION_SYMBOL);
      int side=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1;
      double risk=DCRisk(symbol,side>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,PositionGetDouble(POSITION_VOLUME),
                         PositionGetDouble(POSITION_PRICE_OPEN),PositionGetDouble(POSITION_SL));
      total+=risk;if(DCUSDGroup(symbol,side)==group)same+=risk;
     }
   return total<=equity*InpTotalRiskPercent/100.0+1e-7 && same<=equity*InpUSDGroupRiskPercent/100.0+1e-7;
  }
bool DCClose(const string symbol)
  {
   if(!PositionSelect(symbol))return true;
   bool ok=dcTrade.PositionClose(symbol);uint rc=dcTrade.ResultRetcode();
   DCLog(symbol,0,"CLOSE_RESULT",0,0,0,0,0,0,rc);
   return ok && rc==TRADE_RETCODE_DONE && !PositionSelect(symbol);
  }
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER)||MQLInfoInteger(MQL_OPTIMIZATION))return INIT_FAILED;
   if(InpEntryBars<2||InpExitBars<1||InpExitBars>=InpEntryBars||InpATRPeriod<2||InpRiskPercent<=0||InpSLATR<=0)return INIT_PARAMETERS_INCORRECT;
   string names[];int n=StringSplit(InpSymbols,',',names);if(n<1)return INIT_PARAMETERS_INCORRECT;
   ArrayResize(dcAssets,n);
   for(int j=0;j<n;j++)
     {
      dcAssets[j].name=names[j];dcAssets[j].consumed=0;dcAssets[j].close_due=false;
      if(!SymbolSelect(names[j],true)){Print("DC_FATAL_SYMBOL ",names[j]);return INIT_FAILED;}
      dcAssets[j].atr=iATR(names[j],PERIOD_D1,InpATRPeriod);
      if(dcAssets[j].atr==INVALID_HANDLE)return INIT_FAILED;
     }
   dcLog=FileOpen(InpTelemetryFileName,FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(dcLog==INVALID_HANDLE)return INIT_FAILED;
   FileWrite(dcLog,"time","symbol","signal_bar","event","price","atr","channel","sl","volume","risk_money","equity","retcode");
   DQStart(InpTelemetryFileName+".cost.csv");if(dqFile==INVALID_HANDLE)return INIT_FAILED;
   dcTrade.SetExpertMagicNumber(InpMagic);dcTrade.SetAsyncMode(false);dcTrade.SetDeviationInPoints(10);
   dcPeak=AccountInfoDouble(ACCOUNT_EQUITY);return INIT_SUCCEEDED;
  }
void DCStep(const int index)
  {
   string symbol=dcAssets[index].name;MqlTick q;
   if(!SymbolInfoTick(symbol,q)||q.bid<=0||q.ask<q.bid||q.time>TimeCurrent()||TimeCurrent()-q.time>60)return;
   dcTrade.SetTypeFillingBySymbol(symbol);
   if(dcAssets[index].close_due)
     {if(DCClose(symbol))dcAssets[index].close_due=false;return;}
   MqlRates r[];ArraySetAsSeries(r,true);int count=InpEntryBars+2;
   if(CopyRates(symbol,PERIOD_D1,0,count,r)!=count)return;
   if(r[0].time>TimeCurrent() || r[1].time>=r[0].time || dcAssets[index].consumed==r[0].time)return;
   double a[];if(CopyBuffer(dcAssets[index].atr,0,1,1,a)!=1 || a[0]<=0)return;
   dcAssets[index].consumed=r[0].time;
   DCLog(symbol,r[1].time,"BAR_EVALUATED",r[1].close,a[0]);
   // Exclude signal bar [1] from both channels; only indices [2..N+1].
   double high=r[2].high,low=r[2].low,exitHigh=high,exitLow=low;
   for(int j=3;j<count;j++){high=MathMax(high,r[j].high);low=MathMin(low,r[j].low);}
   for(int j=3;j<InpExitBars+2;j++){exitHigh=MathMax(exitHigh,r[j].high);exitLow=MathMin(exitLow,r[j].low);}
   if(PositionSelect(symbol))
     {
      bool buy=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
      if((buy && r[1].close<exitLow)||(!buy && r[1].close>exitHigh))
        {DCLog(symbol,r[1].time,"CHANNEL_EXIT",r[1].close,a[0],buy?exitLow:exitHigh);dcAssets[index].close_due=!DCClose(symbol);}
      return; // No same-bar reversal or pyramiding.
     }
   int side=r[1].close>high?1:(r[1].close<low?-1:0);
   if(side==0){DCLog(symbol,r[1].time,"NO_SIGNAL");return;}
   double price=side>0?q.ask:q.bid,level=side>0?high:low;
   DCLog(symbol,r[1].time,"SIGNAL",price,a[0],level);
   if(dcDailyStop||dcPeakStop||dcUncertain||OrdersTotal()>0){DCLog(symbol,r[1].time,"RISK_LATCH");return;}
   double tick=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE),point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   if(tick<=0||point<=0){dcErrors++;return;}
   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   double raw=price-side*InpSLATR*a[0];
   double sl=NormalizeDouble((side>0?MathFloor(raw/tick):MathCeil(raw/tick))*tick,digits);
   double minStop=SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL)*point;
   if(sl<=0 || (side>0?q.bid-sl:sl-q.ask)<minStop){DCLog(symbol,r[1].time,"BROKER_STOP");return;}
   ENUM_ORDER_TYPE type=side>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   double equity=AccountInfoDouble(ACCOUNT_EQUITY),budget=equity*InpRiskPercent/100.0;
   double unitLoss=DCRisk(symbol,type,1.0,price,sl);
   double step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP),minimum=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   double maximum=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   if(unitLoss<=0||unitLoss==DBL_MAX||step<=0){DCLog(symbol,r[1].time,"RISK_CALC_FAILED");return;}
   double volume=NormalizeDouble(MathFloor(MathMin(maximum,budget/unitLoss)/step)*step,8);
   double risk=DCRisk(symbol,type,volume,price,sl);
   if(volume<minimum || risk>budget+1e-7){DCLog(symbol,r[1].time,"VOLUME_OR_RISK");return;}
   if(PositionsTotal()>=3 || !DCRiskRoom(DCUSDGroup(symbol,side),risk,equity))
     {DCLog(symbol,r[1].time,"PORTFOLIO_CAP");return;}
   double margin=0;
   if(!OrderCalcMargin(type,symbol,volume,price,margin)||margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE))
     {DCLog(symbol,r[1].time,"MARGIN");return;}
   DCLog(symbol,r[1].time,"RISK_PLAN",price,a[0],level,sl,volume,risk);
   bool sent=side>0?dcTrade.Buy(volume,symbol,price,sl,0,"D1 channel"):dcTrade.Sell(volume,symbol,price,sl,0,"D1 channel");
   uint rc=dcTrade.ResultRetcode();DCLog(symbol,r[1].time,sent?"SEND_RESULT":"SEND_FAILED",price,a[0],level,sl,volume,risk,rc);
   if(rc==TRADE_RETCODE_TIMEOUT||rc==TRADE_RETCODE_CONNECTION||rc==TRADE_RETCODE_PLACED)dcUncertain=true;
   if(PositionSelect(symbol))
     {
      double actual=DCRisk(symbol,type,PositionGetDouble(POSITION_VOLUME),PositionGetDouble(POSITION_PRICE_OPEN),PositionGetDouble(POSITION_SL));
      if(actual>budget+0.01){dcErrors++;DCLog(symbol,r[1].time,"FILL_RISK_EXCEEDED");dcAssets[index].close_due=!DCClose(symbol);}
     }
  }
void OnTick()
  {
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);dcPeak=MathMax(dcPeak,equity);
   MqlDateTime t;TimeToStruct(TimeCurrent(),t);int day=t.year*1000+t.day_of_year;
   if(day!=dcDay){dcDay=day;dcDayStart=equity;dcDailyStop=false;}
   if(equity<=dcDayStart*(1-InpDailyLossPercent/100.0))dcDailyStop=true;
   if(equity<=dcPeak*(1-InpPeakLossPercent/100.0))dcPeakStop=true;
   datetime minute=(datetime)((long)TimeCurrent()/60*60);if(minute==dcMinute)return;dcMinute=minute;
   if(dcDailyStop||dcPeakStop)
     for(int j=0;j<ArraySize(dcAssets);j++)if(PositionSelect(dcAssets[j].name))dcAssets[j].close_due=true;
   // Deterministic rotating priority prevents a constant first-symbol advantage.
   int n=ArraySize(dcAssets),start=(int)((long)TimeCurrent()/86400%n);
   for(int j=0;j<n;j++)DCStep((j+start)%n);
  }
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
  {if(trans.type==TRADE_TRANSACTION_DEAL_ADD)DQCapture(trans.deal);}
double OnTester(){DQDrain();return (double)dcErrors;}
void OnDeinit(const int reason)
  {
   DQClose();if(dcLog!=INVALID_HANDLE)FileClose(dcLog);
   for(int j=0;j<ArraySize(dcAssets);j++)if(dcAssets[j].atr!=INVALID_HANDLE)IndicatorRelease(dcAssets[j].atr);
   PrintFormat("DC_FINISH errors=%d uncertain=%d peak_stop=%d",dcErrors,(int)dcUncertain,(int)dcPeakStop);
  }
