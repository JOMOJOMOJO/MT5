#property strict
#property version "1.02"
#include "../../Include/Research/PortableTrading.mqh"
input bool InpIndependentClock=true;
input double InpDeviationATR=0.05;
// Fixed research baseline; deliberately refuses attachment outside the tester.
#include <Trade/Trade.mqh>
#include "../../Include/Research/PortableDealQuoteAudit.mqh"
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
struct DCAsset{string name;int atr;datetime consumed;bool close_due;datetime retry_bar,retry_signal;};
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
  {return PFUsdDirection(SymbolInfoString(symbol,SYMBOL_CURRENCY_BASE),SymbolInfoString(symbol,SYMBOL_CURRENCY_PROFIT),side);}
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
      if(PositionGetTicket(j)==0 || (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagic)continue;
      string symbol=PositionGetString(POSITION_SYMBOL);
      int side=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?1:-1;
      double risk=DCRisk(symbol,side>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL,PositionGetDouble(POSITION_VOLUME),
                         PositionGetDouble(POSITION_PRICE_OPEN),PositionGetDouble(POSITION_SL));
      total+=risk;if(group!=0 && DCUSDGroup(symbol,side)==group)same+=risk;
     }
   return total<=equity*InpTotalRiskPercent/100.0+1e-7 && (group==0 || same<=equity*InpUSDGroupRiskPercent/100.0+1e-7);
  }
bool DCClose(const string symbol)
  {
   bool complete=true;
   for(int j=PositionsTotal()-1;j>=0;j--)
     {
      ulong ticket=PositionGetTicket(j);
      if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=symbol || (ulong)PositionGetInteger(POSITION_MAGIC)!=InpMagic)continue;
      bool ok=dcTrade.PositionClose(ticket);uint rc=dcTrade.ResultRetcode();DCLog(symbol,0,"CLOSE_RESULT",0,0,0,0,0,0,rc);
      if(!ok || rc!=TRADE_RETCODE_DONE || PositionSelectByTicket(ticket))complete=false;
     }
   return complete;
  }
int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER)||MQLInfoInteger(MQL_OPTIMIZATION))return INIT_FAILED;
   if(InpEntryBars<2||InpExitBars<1||InpExitBars>=InpEntryBars||InpATRPeriod<2||InpRiskPercent<=0||InpSLATR<=0)return INIT_PARAMETERS_INCORRECT;
   string names[];int n=StringSplit(InpSymbols,',',names);if(n<1)return INIT_PARAMETERS_INCORRECT;
   ArrayResize(dcAssets,n);
   for(int j=0;j<n;j++)
     {
      string resolved,why;
      if(!PFResolveSymbol(names[j],resolved,why)){Print("DC_FATAL_SYMBOL ",names[j]," ",why);return INIT_FAILED;}
      for(int k=0;k<j;k++)if(dcAssets[k].name==resolved)return INIT_PARAMETERS_INCORRECT;
      names[j]=resolved;dcAssets[j].name=resolved;dcAssets[j].consumed=0;dcAssets[j].close_due=false;
      dcAssets[j].retry_bar=0;dcAssets[j].retry_signal=0;
      if(!SymbolSelect(names[j],true)){Print("DC_FATAL_SYMBOL ",names[j]);return INIT_FAILED;}
      dcAssets[j].atr=iATR(names[j],PERIOD_D1,InpATRPeriod);
      if(dcAssets[j].atr==INVALID_HANDLE)return INIT_FAILED;
     }
   dcLog=FileOpen(InpTelemetryFileName,FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(dcLog==INVALID_HANDLE)return INIT_FAILED;
   FileWrite(dcLog,"time","symbol","signal_bar","event","price","atr","channel","sl","volume","risk_money","equity","retcode");
   DQStart(InpTelemetryFileName+".cost.csv");if(dqFile==INVALID_HANDLE)return INIT_FAILED;
   if(InpDeviationATR<0 || InpRiskPercent>100 || InpTotalRiskPercent<=0 || InpUSDGroupRiskPercent<=0 ||
         InpDailyLossPercent<=0 || InpDailyLossPercent>=100 || InpPeakLossPercent<=0 || InpPeakLossPercent>=100)return INIT_PARAMETERS_INCORRECT;
   if(!PFOpen(InpTelemetryFileName+".risk.csv"))return INIT_FAILED;
   if(InpIndependentClock && !EventSetTimer(10))return INIT_FAILED;
   dcTrade.SetExpertMagicNumber(InpMagic);dcTrade.SetAsyncMode(false);
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
   if(dcAssets[index].retry_bar>0)
     {
      DCLog(symbol,dcAssets[index].retry_signal,dcAssets[index].retry_bar==r[0].time?"RETRY_RESUMED":"RETRY_EXPIRED");
      dcAssets[index].retry_bar=0;dcAssets[index].retry_signal=0;
     }
   dcAssets[index].consumed=r[0].time;
   DCLog(symbol,r[1].time,"BAR_EVALUATED",r[1].close,a[0]);
   // Exclude signal bar [1] from both channels; only indices [2..N+1].
   double high=r[2].high,low=r[2].low,exitHigh=high,exitLow=low;
   for(int j=3;j<count;j++){high=MathMax(high,r[j].high);low=MathMin(low,r[j].low);}
   for(int j=3;j<InpExitBars+2;j++){exitHigh=MathMax(exitHigh,r[j].high);exitLow=MathMin(exitLow,r[j].low);}
   if(PFForeignPosition(symbol,InpMagic)){DCLog(symbol,r[1].time,"FOREIGN_POSITION");return;}
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
   PFPlan plan;bool planned=PFMakePlan(symbol,type,price,sl,InpRiskPercent,a[0],plan);PFWrite(symbol,type,price,sl,plan);
   if(!planned){DCLog(symbol,r[1].time,plan.reason,price,a[0],level,sl,plan.volume,plan.loss);return;}
   double volume=plan.volume,risk=plan.loss;
   dcTrade.SetDeviationInPoints((ulong)MathCeil(InpDeviationATR*a[0]/point));
   if(PFCountPositions(InpMagic)>=3 || !DCRiskRoom(DCUSDGroup(symbol,side),risk,equity))
     {DCLog(symbol,r[1].time,"PORTFOLIO_CAP");return;}
   double margin=0;
   if(!OrderCalcMargin(type,symbol,volume,price,margin)||margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE))
     {DCLog(symbol,r[1].time,"MARGIN");return;}
   DCLog(symbol,r[1].time,"RISK_PLAN",price,a[0],level,sl,volume,risk);
   bool sent=side>0?dcTrade.Buy(volume,symbol,price,sl,0,"D1 channel"):dcTrade.Sell(volume,symbol,price,sl,0,"D1 channel");
   uint rc=dcTrade.ResultRetcode();DCLog(symbol,r[1].time,sent?"SEND_RESULT":"SEND_FAILED",price,a[0],level,sl,volume,risk,rc);
   // MARKET_CLOSED is a definite rejection, not an uncertain send. Preserve this
   // closed-bar signal until a subsequent fresh quote in the same D1 bar.
   if(rc==TRADE_RETCODE_MARKET_CLOSED)
     {
      dcAssets[index].consumed=0;dcAssets[index].retry_bar=r[0].time;dcAssets[index].retry_signal=r[1].time;
      DCLog(symbol,r[1].time,"RETRY_MARKET_CLOSED",price,a[0],level,sl,volume,risk,rc);
      return;
     }
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
double OnTester(){DQDrain(true);return (double)dcErrors;}
void OnDeinit(const int reason)
  {
   EventKillTimer();PFClose();
   for(int j=0;j<ArraySize(dcAssets);j++)
      if(dcAssets[j].retry_bar>0)DCLog(dcAssets[j].name,dcAssets[j].retry_signal,"RETRY_END_CENSORED");
   DQClose();if(dcLog!=INVALID_HANDLE)FileClose(dcLog);
   for(int j=0;j<ArraySize(dcAssets);j++)if(dcAssets[j].atr!=INVALID_HANDLE)IndicatorRelease(dcAssets[j].atr);
   PrintFormat("DC_FINISH errors=%d uncertain=%d peak_stop=%d",dcErrors,(int)dcUncertain,(int)dcPeakStop);
  }

void OnTimer(){if(InpIndependentClock)OnTick();}
