#ifndef TICK_SHOCK_METRICS_MQH
#define TICK_SHOCK_METRICS_MQH

#include "TickShockBaseline.mqh"

struct TickShockEfficiencyResult
  {
   bool valid;
   double net_move;
   double path_length;
   double efficiency;
  };

struct TickShockCommissionResult
  {
   bool calculation_success;
   double one_lot_sl_loss;
   double commission_amount;
   double commission_r;
   double gross_r;
   double net_r;
   int applications;
  };

bool TSComputeDirectionalEfficiency(const double &mids[],const int count,TickShockEfficiencyResult &result)
  {
   ZeroMemory(result);
   if(count<2 || count>ArraySize(mids)) return false;
   result.net_move=MathAbs(mids[count-1]-mids[0]);
   for(int i=1;i<count;++i) result.path_length+=MathAbs(mids[i]-mids[i-1]);
   if(result.path_length<=0.0 || !MathIsValidNumber(result.path_length)) return false;
   result.efficiency=result.net_move/result.path_length;
   result.valid=MathIsValidNumber(result.efficiency);
   return result.valid;
  }

bool TSBuildCommissionResult(const bool calculation_success,const double one_lot_profit_or_loss,const double commission_amount,const double gross_r,TickShockCommissionResult &result)
  {
   ZeroMemory(result);
   result.calculation_success=calculation_success;
   result.one_lot_sl_loss=MathAbs(one_lot_profit_or_loss);
   result.commission_amount=MathMax(0.0,commission_amount);
   result.gross_r=gross_r;
   if(!calculation_success || result.one_lot_sl_loss<=0.0 || one_lot_profit_or_loss>=0.0) return false;
   result.commission_r=result.commission_amount/result.one_lot_sl_loss;
   result.net_r=result.gross_r-result.commission_r;
   result.applications=result.commission_amount>0.0?1:0;
   return MathIsValidNumber(result.commission_r) && MathIsValidNumber(result.net_r);
  }

#endif
