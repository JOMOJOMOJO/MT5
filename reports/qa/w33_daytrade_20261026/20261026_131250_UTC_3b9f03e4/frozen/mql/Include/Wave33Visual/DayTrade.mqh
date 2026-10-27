#ifndef WAVE33_VISUAL_DAYTRADE_MQH
#define WAVE33_VISUAL_DAYTRADE_MQH
// Pure policy: no quotes, orders, positions, clocks or drawing are read here.
struct W33DayTradeConfig
  {bool enable_step;double start_r,step_r,lag_r,max_hold_hours;};
struct W33DayTradeState
  {
   bool initialized;int direction;long first_fill_msc;
   double entry,original_sl,risk_price,max_favorable_r,desired_sl_r;
   int stage_reached;
  };
struct W33DayTradeSLPlan
  {bool valid,can_modify,already_protected;double target_sl;string reason;};
bool W33DayTradeConfigValid(const W33DayTradeConfig &c)
  {
   return MathIsValidNumber(c.start_r) && c.start_r>0 && MathIsValidNumber(c.step_r) && c.step_r>0 &&
      MathIsValidNumber(c.lag_r) && c.lag_r>=0 && MathIsValidNumber(c.max_hold_hours) && c.max_hold_hours>0 && c.max_hold_hours<=24;
  }
bool W33InitDayTradeState(W33DayTradeState &s,const int direction,const long first_fill_msc,const double entry,const double original_sl)
  {
   if(s.initialized || (direction!=1 && direction!=-1) || first_fill_msc<=0 ||
      !MathIsValidNumber(entry) || !MathIsValidNumber(original_sl) || entry<=0 || original_sl<=0 || direction*(entry-original_sl)<=0)return false;
   s.initialized=true;s.direction=direction;s.first_fill_msc=first_fill_msc;s.entry=entry;s.original_sl=original_sl;
   s.risk_price=MathAbs(entry-original_sl);s.max_favorable_r=0;s.desired_sl_r=0;s.stage_reached=-1;return true;
  }
bool W33ObserveDayTradeQuote(W33DayTradeState &s,const W33DayTradeConfig &c,const double executable_quote)
  {
   if(!s.initialized || !W33DayTradeConfigValid(c) || !MathIsValidNumber(executable_quote) || executable_quote<=0)return false;
   double r=s.direction*(executable_quote-s.entry)/s.risk_price;
   s.max_favorable_r=MathMax(s.max_favorable_r,r);
   if(!c.enable_step || s.max_favorable_r+1e-9<c.start_r)return false;
   int stage=(int)MathFloor((s.max_favorable_r-c.start_r+1e-9)/c.step_r);
   if(stage<=s.stage_reached)return false;
   s.stage_reached=stage;s.desired_sl_r=c.start_r-c.lag_r+stage*c.step_r;return true;
  }
W33DayTradeSLPlan W33BuildDayTradeSLPlan(const W33DayTradeState &s,const W33DayTradeConfig &c,
   const double current_sl,const double executable_quote,const double point,const double tick_size,const int digits,
   const long stops_points,const long freeze_points)
  {
   W33DayTradeSLPlan p;ZeroMemory(p);p.reason="NO_STAGE";
   if(!s.initialized || !W33DayTradeConfigValid(c) || !c.enable_step || s.stage_reached<0)return p;
   if(!MathIsValidNumber(current_sl) || !MathIsValidNumber(executable_quote) || executable_quote<=0 ||
      !MathIsValidNumber(point) || point<=0 || !MathIsValidNumber(tick_size) || tick_size<=0 || stops_points<0 || freeze_points<0)
     {p.reason="INVALID_SPECIFICATION";return p;}
   double raw=s.entry+s.direction*s.risk_price*s.desired_sl_r;
   p.target_sl=NormalizeDouble((s.direction>0?MathCeil(raw/tick_size-1e-9):MathFloor(raw/tick_size+1e-9))*tick_size,digits);
   if(p.target_sl<=0){p.reason="INVALID_TARGET";return p;}
   p.valid=true;
   if(current_sl>0 && s.direction*(current_sl-p.target_sl)>=-tick_size*0.1)
     {p.already_protected=true;p.reason="ALREADY_PROTECTED";return p;}
   double distance=(MathMax((double)stops_points,(double)freeze_points)+1.0)*point;
   if(s.direction*(executable_quote-p.target_sl)<distance)
     {p.reason="STOPS_FREEZE_OR_PULLBACK_WAIT";return p;}
   p.can_modify=true;p.reason="STEP_SL_READY";return p;
  }
long W33DayTradeDeadlineMSC(const W33DayTradeState &s,const W33DayTradeConfig &c)
  {if(!s.initialized || !W33DayTradeConfigValid(c))return 0;return s.first_fill_msc+(long)MathRound(c.max_hold_hours*3600000.0);}
bool W33DayTradeDeadlineDue(const W33DayTradeState &s,const W33DayTradeConfig &c,const long now_msc)
  {long deadline=W33DayTradeDeadlineMSC(s,c);return deadline>0 && now_msc>=deadline;}
bool W33DayTradeWeekCloseDue(const long now_msc,const long session_end_msc,const int buffer_seconds)
  {return session_end_msc>0 && buffer_seconds>=0 && now_msc>=session_end_msc-(long)buffer_seconds*1000 && now_msc<=session_end_msc;}
#endif
