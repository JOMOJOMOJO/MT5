#ifndef PORTABLE_TRADING_RESEARCH_MQH
#define PORTABLE_TRADING_RESEARCH_MQH
// Research execution primitives. No trade sends; no minimum-lot risk override.
struct PFPlan
  {
   string reason,base_currency,profit_currency;
   double volume,raw_volume,min_volume,max_volume,step,unit_loss,min_loss,budget,loss,margin;
   double point,tick,contract,spread,spread_atr,spread_r,minimum_equity;
   int digits;long calc_mode;
  };
int PFUsdDirection(const string base,const string profit,const int side)
  {
   if(base=="USD" && profit!="USD")return side;
   if(profit=="USD" && base!="USD")return -side;
   return 0; // EURJPY and other crosses do not create a direct USD leg.
  }
double PFFloorVolume(const double raw,const double minimum,const double maximum,const double step)
  {
   if(!MathIsValidNumber(raw)||raw<=0||minimum<=0||maximum<minimum||step<=0)return 0;
   double v=NormalizeDouble(MathFloor(MathMin(raw,maximum)/step+1e-10)*step,8);
   if(v+1e-10<minimum || v>maximum+1e-10)return 0;
   return v;
  }
double PFPrice(const double raw,const double tick,const int digits,const int direction)
  {
   if(!MathIsValidNumber(raw)||raw<=0||tick<=0)return 0;
   double n=raw/tick;
   return NormalizeDouble((direction<0?MathFloor(n):direction>0?MathCeil(n):MathRound(n))*tick,digits);
  }
bool PFResolveSymbol(const string requested,string &resolved,string &reason)
  {
   resolved="";reason="";string key=requested;StringTrimLeft(key);StringTrimRight(key);
   bool custom=false;
   if(SymbolExist(key,custom)){resolved=key;return SymbolSelect(key,true);}
   if(StringLen(key)!=6){reason="SYMBOL_NOT_FOUND_USE_EXACT_BROKER_NAME";return false;}
   string base=StringSubstr(key,0,3),profit=StringSubstr(key,3,3);int matches=0;
   for(int i=0;i<SymbolsTotal(false);i++)
     {
      string s=SymbolName(i,false);
      if(SymbolInfoString(s,SYMBOL_CURRENCY_BASE)==base && SymbolInfoString(s,SYMBOL_CURRENCY_PROFIT)==profit)
        {resolved=s;matches++;}
     }
   if(matches!=1){resolved="";reason=matches>1?"AMBIGUOUS_SYMBOL_USE_EXACT_BROKER_NAME":"SYMBOL_NOT_FOUND";return false;}
   return SymbolSelect(resolved,true);
  }
bool PFMakePlan(const string symbol,const ENUM_ORDER_TYPE side,const double entry,const double sl,
                const double risk_percent,const double atr,PFPlan &p)
  {
   ZeroMemory(p);p.reason="INVALID_RISK_INPUT";
   if((side!=ORDER_TYPE_BUY && side!=ORDER_TYPE_SELL)||entry<=0||sl<=0||risk_percent<=0||risk_percent>100)return false;
   if((side==ORDER_TYPE_BUY && sl>=entry)||(side==ORDER_TYPE_SELL && sl<=entry))return false;
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);p.budget=equity*risk_percent/100.0;
   p.base_currency=SymbolInfoString(symbol,SYMBOL_CURRENCY_BASE);p.profit_currency=SymbolInfoString(symbol,SYMBOL_CURRENCY_PROFIT);
   p.min_volume=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);p.max_volume=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   p.step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);p.point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   p.tick=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);p.contract=SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);
   p.digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);p.calc_mode=SymbolInfoInteger(symbol,SYMBOL_TRADE_CALC_MODE);
   p.reason="INVALID_SYMBOL_SPEC";
   if(equity<=0||p.min_volume<=0||p.max_volume<p.min_volume||p.step<=0||p.point<=0||p.tick<=0||p.contract<=0)return false;
   // Use a valid minimum volume, not an assumed tradable 1.0 lot.
   double profit=0;p.reason="PROFIT_CALC_FAILED";
   if(!OrderCalcProfit(side,symbol,p.min_volume,entry,sl,profit)||!MathIsValidNumber(profit)||profit>=0)return false;
   p.min_loss=-profit;p.unit_loss=p.min_loss/p.min_volume;
   p.minimum_equity=p.min_loss*100.0/risk_percent;p.raw_volume=p.budget/p.unit_loss;
   MqlTick q;if(SymbolInfoTick(symbol,q)&&q.ask>=q.bid&&q.bid>0)p.spread=q.ask-q.bid;
   p.spread_atr=atr>0?p.spread/atr:EMPTY_VALUE;p.spread_r=p.spread/MathAbs(entry-sl);
   p.reason="MIN_VOLUME_EXCEEDS_RISK";
   if(p.min_loss>p.budget+1e-7)return false;
   p.volume=PFFloorVolume(p.raw_volume,p.min_volume,p.max_volume,p.step);
   if(p.volume<=0)return false;
   p.reason="PROFIT_RECHECK_FAILED";
   if(!OrderCalcProfit(side,symbol,p.volume,entry,sl,profit)||!MathIsValidNumber(profit)||profit>=0)return false;
   p.loss=-profit;p.reason="NORMALIZED_VOLUME_EXCEEDS_RISK";
   if(p.loss>p.budget+1e-7)return false;
   p.reason="MARGIN_CALC_FAILED";
   if(!OrderCalcMargin(side,symbol,p.volume,entry,p.margin)||!MathIsValidNumber(p.margin)||p.margin<0)return false;
   p.reason="INSUFFICIENT_MARGIN";if(p.margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE))return false;
   p.reason="OK";return true;
  }
int PFCountPositions(const ulong magic)
  {
   int n=0;for(int i=PositionsTotal()-1;i>=0;i--)
      if(PositionGetTicket(i)>0 && (ulong)PositionGetInteger(POSITION_MAGIC)==magic)n++;
   return n;
  }
bool PFForeignPosition(const string symbol,const ulong magic)
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
      if(PositionGetTicket(i)>0 && PositionGetString(POSITION_SYMBOL)==symbol && (ulong)PositionGetInteger(POSITION_MAGIC)!=magic)return true;
   return false;
  }
int pfRiskFile=INVALID_HANDLE;
bool PFOpen(const string file)
  {
   pfRiskFile=FileOpen(file,FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');if(pfRiskFile==INVALID_HANDLE)return false;
   FileWrite(pfRiskFile,"time","symbol","side","entry","sl","reason","volume","raw_volume","min_volume","max_volume","step",
             "min_loss","budget","planned_loss","margin","minimum_equity","point","tick_size","digits","contract_size","calc_mode",
             "base_currency","profit_currency","spread_price","spread_atr","spread_r");return true;
  }
void PFWrite(const string symbol,const ENUM_ORDER_TYPE side,const double entry,const double sl,const PFPlan &p)
  {
   if(pfRiskFile==INVALID_HANDLE)return;
   FileWrite(pfRiskFile,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),symbol,EnumToString(side),entry,sl,p.reason,p.volume,p.raw_volume,
             p.min_volume,p.max_volume,p.step,p.min_loss,p.budget,p.loss,p.margin,p.minimum_equity,p.point,p.tick,p.digits,p.contract,p.calc_mode,
             p.base_currency,p.profit_currency,p.spread,p.spread_atr,p.spread_r);
  }
void PFClose(){if(pfRiskFile!=INVALID_HANDLE){FileClose(pfRiskFile);pfRiskFile=INVALID_HANDLE;}}
#endif
