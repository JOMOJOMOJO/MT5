#ifndef TICK_SHOCK_GRID_MQH
#define TICK_SHOCK_GRID_MQH

struct TickShockGridRuntime
  {
   long next_boundary_msc;
   long quote_msc;
   double bid;
   double ask;
   double mid;
  };

void TSGridReset(TickShockGridRuntime &state)
  {
   ZeroMemory(state);
  }

void TSGridObserveQuote(TickShockGridRuntime &state,const long time_msc,const double bid,const double ask,const int grid_ms)
  {
   if(state.next_boundary_msc<=0 && grid_ms>0)
      state.next_boundary_msc=((time_msc/grid_ms)+1)*grid_ms;
   state.quote_msc=time_msc;
   state.bid=bid;
   state.ask=ask;
   state.mid=(bid+ask)*0.5;
  }

void TSGridAdvanceBoundary(TickShockGridRuntime &state,const int grid_ms)
  {
   if(state.next_boundary_msc>0 && grid_ms>0) state.next_boundary_msc+=grid_ms;
  }

#endif
