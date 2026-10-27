#ifndef WAVE33_DAYTRADE_PARTIAL_MQH
#define WAVE33_DAYTRADE_PARTIAL_MQH
#include "DayTrade.mqh"
// Pure sizing/price decisions. No market, clock, position or order API.
struct W33DayTradeHalfPlan
  {bool valid;double initial_volume,close_volume,remaining_volume;string reason;};
struct W33DayTradePartialState
  {
   bool initialized,triggered;int direction;
   double entry,original_sl,risk_price,trigger_r,trigger_price;
   double initial_volume,target_close_volume,target_remaining_volume,volume_step;
  };
struct W33DayTradePartialRequest
  {bool valid,complete;double request_volume;string reason;};
bool W33HalfSpecValid(const double min_volume,const double step,const double max_volume)
  {return MathIsValidNumber(min_volume) && MathIsValidNumber(step) && MathIsValidNumber(max_volume) && min_volume>0 && step>0 && max_volume>=min_volume;}
double W33HalfVolumeTolerance(const double step,const double reference=0)
  {
   if(!MathIsValidNumber(step) || step<=0)return 0;
   // Keep floating error allowance strictly below a native volume unit.
   // An absolute 1e-8 epsilon would mistake zero for a full 1e-8 half.
   double relative=MathIsValidNumber(reference)?MathAbs(reference)*2.2204460492503131e-16*8:0;
   return MathMin(step*0.1,MathMax(step*1e-7,relative));
  }
bool W33HalfOnGrid(const double volume,const double step)
  {return MathIsValidNumber(step) && step>0 && MathIsValidNumber(volume) && volume>=0 && MathAbs(volume-MathRound(volume/step)*step)<=W33HalfVolumeTolerance(step,volume);}
double W33DayTradeSplittableVolumeDown(const double risk_volume,const double min_volume,const double step,const double max_volume)
  {
   if(!MathIsValidNumber(risk_volume) || risk_volume<=0 || !W33HalfSpecValid(min_volume,step,max_volume))return 0;
   double units=2*MathFloor(MathMin(risk_volume,max_volume)/step/2+1e-9);
   double volume=NormalizeDouble(units*step,8);
   double tolerance=W33HalfVolumeTolerance(step,MathMax(volume,risk_volume));
   return volume/2+tolerance>=min_volume && volume<=risk_volume+tolerance?volume:0;
  }
W33DayTradeHalfPlan W33BuildDayTradeHalfPlan(const double initial_volume,const double min_volume,const double step,const double max_volume)
  {
   W33DayTradeHalfPlan p;ZeroMemory(p);p.reason="EXACT_HALF_UNAVAILABLE";
   if(!W33HalfSpecValid(min_volume,step,max_volume) || !MathIsValidNumber(initial_volume) || initial_volume<=0)return p;
   double tolerance=W33HalfVolumeTolerance(step,initial_volume);
   if(initial_volume>max_volume+tolerance || !W33HalfOnGrid(initial_volume,step) || !W33HalfOnGrid(initial_volume/2,step) || initial_volume/2+tolerance<min_volume)return p;
   p.valid=true;p.initial_volume=initial_volume;p.close_volume=NormalizeDouble(initial_volume/2,8);p.remaining_volume=p.close_volume;p.reason="EXACT_HALF_READY";return p;
  }
bool W33InitDayTradePartialState(W33DayTradePartialState &s,const W33DayTradeState &day,const double initial_volume,
   const double min_volume,const double step,const double max_volume,const double trigger_r=1.0)
  {
   if(s.initialized || !day.initialized || !MathIsValidNumber(trigger_r) || trigger_r<=0)return false;
   W33DayTradeHalfPlan p=W33BuildDayTradeHalfPlan(initial_volume,min_volume,step,max_volume);if(!p.valid)return false;
   double target=day.entry+day.direction*day.risk_price*trigger_r;if(!MathIsValidNumber(target) || target<=0)return false;
   s.initialized=true;s.triggered=false;s.direction=day.direction;s.entry=day.entry;s.original_sl=day.original_sl;s.risk_price=day.risk_price;
   s.trigger_r=trigger_r;s.trigger_price=target;s.initial_volume=p.initial_volume;s.target_close_volume=p.close_volume;s.target_remaining_volume=p.remaining_volume;s.volume_step=step;return true;
  }
bool W33DayTradePartialQuoteHit(const W33DayTradePartialState &s,const double bid,const double ask)
  {
   if(!s.initialized || !MathIsValidNumber(bid) || !MathIsValidNumber(ask) || bid<=0 || ask<bid)return false;
   double quote=s.direction>0?bid:ask;return s.direction*(quote-s.trigger_price)>=-s.risk_price*1e-9;
  }
bool W33ObserveDayTradePartialQuote(W33DayTradePartialState &s,const double bid,const double ask)
  {if(s.triggered || !W33DayTradePartialQuoteHit(s,bid,ask))return false;s.triggered=true;return true;}
bool W33DayTradePartialComplete(const W33DayTradePartialState &s,const double confirmed)
  {return s.initialized && MathIsValidNumber(s.volume_step) && s.volume_step>0 && MathIsValidNumber(confirmed) && confirmed>=0 && MathAbs(confirmed-s.target_close_volume)<=W33HalfVolumeTolerance(s.volume_step,MathMax(s.initial_volume,confirmed));}
W33DayTradePartialRequest W33BuildDayTradePartialRequest(const W33DayTradePartialState &s,const double confirmed,
   const double current_volume,const double min_volume,const double step,const double max_volume)
  {
   W33DayTradePartialRequest p;ZeroMemory(p);p.reason="INVALID_PARTIAL_LEDGER";
   if(!s.initialized || !W33HalfSpecValid(min_volume,step,max_volume) || !MathIsValidNumber(confirmed) || confirmed<0 ||
      !MathIsValidNumber(current_volume) || current_volume<=0 || !W33HalfOnGrid(confirmed,step) || !W33HalfOnGrid(current_volume,step))return p;
   double tolerance=W33HalfVolumeTolerance(step,MathMax(s.initial_volume,MathMax(current_volume,confirmed)));
   if(confirmed>s.target_close_volume+tolerance){p.complete=true;p.reason="HALF_OVERCLOSE_LEDGER";return p;}
   if(W33DayTradePartialComplete(s,confirmed)){p.valid=true;p.complete=true;p.reason="HALF_ALREADY_CONFIRMED";return p;}
   double residual=NormalizeDouble(s.target_close_volume-confirmed,8);
   if(residual<min_volume-tolerance || residual>max_volume+tolerance || !W33HalfOnGrid(residual,step) ||
      current_volume-residual<min_volume-tolerance || MathAbs(current_volume-(s.initial_volume-confirmed))>tolerance)return p;
   p.valid=true;p.request_volume=residual;p.reason="HALF_RESIDUAL_READY";return p;
  }
#endif
