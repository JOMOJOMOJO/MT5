#property strict
#property version "1.00"
#property description "Tester-only synthetic execution arithmetic parity. Never sends orders."

input string InpOutputFile="MultiassetResearchParity_20261016.csv";
int g_file=INVALID_HANDLE;
int g_checks=0;
int g_failures=0;

double RoundPrice(const double price,const double tick,const bool up)
  {
   double units=up ? MathCeil(price/tick-1e-9) : MathFloor(price/tick+1e-9);
   return units*tick;
  }

double FloorVolume(const double budget,const double per_lot,const double minimum,
                   const double step,const double maximum)
  {
   if(budget<=0 || per_lot<=0 || minimum<=0 || step<=0 || maximum<=0) return 0.0;
   double raw=MathMin(budget/per_lot,maximum);
   double volume=MathFloor(raw/step+1e-10)*step;
   if(volume<minimum-1e-10 || volume*per_lot>budget+1e-8) return 0.0;
   return NormalizeDouble(volume,10);
  }

void Check(const string name,const double actual,const double expected,const double tolerance=1e-8)
  {
   bool passed=MathIsValidNumber(actual) && MathAbs(actual-expected)<=tolerance;
   g_checks++;
   if(!passed) g_failures++;
   if(g_file!=INVALID_HANDLE)
      FileWrite(g_file,name,DoubleToString(actual,12),DoubleToString(expected,12),passed ? "PASS" : "FAIL");
   PrintFormat("MULTIASSET_PARITY case=%s actual=%.12f expected=%.12f result=%s",
               name,actual,expected,passed ? "PASS" : "FAIL");
  }

int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))
     {
      Print("MultiassetResearchParity is tester-only; initialization refused outside tester.");
      return INIT_FAILED;
     }
   g_file=FileOpen(InpOutputFile,FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(g_file==INVALID_HANDLE)
     {
      PrintFormat("MULTIASSET_PARITY file error=%d",GetLastError());
      return INIT_FAILED;
     }
   FileWrite(g_file,"case","actual","expected","result");
   const double tick=0.00001;
   const double slip=0.00002;
   const double spread=0.00020;
   const double atr=0.001;
   const double units=100000.0;
   double entry=RoundPrice(1.1+spread+slip,tick,true);
   double stop=RoundPrice(entry-atr,tick,false);
   double target=RoundPrice(entry+atr,tick,true);
   double stop_fill=RoundPrice(stop-slip,tick,false);
   double target_fill=RoundPrice(target-slip,tick,false);
   double risk=(entry-stop_fill)*units;
   double volume=FloorVolume(10.0,risk,0.01,0.01,100.0);
   Check("EURUSD_LONG_entry",entry,1.10022);
   Check("EURUSD_LONG_stop",stop,1.09922);
   Check("EURUSD_LONG_target",target,1.10122);
   Check("EURUSD_risk_per_lot",risk,102.0);
   Check("floor_volume",volume,0.09);
   Check("minimum_lot_rejected",FloorVolume(10.0,risk,0.1,0.01,100.0),0.0);
   Check("LONG_stop_net",(stop_fill-entry)*units*volume,-9.18);
   Check("LONG_target_net",(target_fill-entry)*units*volume,8.82);
   Check("LONG_stop_R",(stop_fill-entry)*units*volume/(risk*volume),-1.0);
   double gap_fill=RoundPrice(1.098-slip,tick,false);
   Check("LONG_gap_stop_fill",gap_fill,1.09798);
   Check("LONG_gap_stop_net",(gap_fill-entry)*units*volume,-20.16);
   Check("same_bar_ambiguous",(1.102>=target && 1.098<=stop) ? 1.0 : 0.0,1.0);
   double short_entry=RoundPrice(1.1-slip,tick,false);
   double short_stop=RoundPrice(short_entry+atr,tick,true);
   double short_target=RoundPrice(short_entry-atr,tick,false);
   Check("SHORT_entry",short_entry,1.09998);
   Check("SHORT_stop_net",(short_entry-RoundPrice(short_stop+slip,tick,true))*units*volume,-9.18);
   Check("SHORT_target_net",(short_entry-RoundPrice(short_target+slip,tick,true))*units*volume,8.82);
   Check("USDCHF_historical_conversion",1.0/0.9,1.111111111111);
   Check("USDCAD_historical_conversion",1.0/1.35,0.740740740741);
   double yen_entry=RoundPrice(150.0+0.015+0.002,0.001,true);
   double yen_stop=RoundPrice(yen_entry-0.1,0.001,false);
   double yen_target=RoundPrice(yen_entry+0.1,0.001,true);
   double yen_risk=(yen_entry-RoundPrice(yen_stop-0.002,0.001,false))*units*MathMax(1.0/150.0075,1.0/(yen_stop+0.0075));
   double yen_volume=FloorVolume(10.0,yen_risk,0.01,0.01,100.0);
   Check("USDJPY_floor_volume",yen_volume,0.14);
   Check("USDJPY_target_conversion",1.0/(yen_target+0.0075),1.0/150.1245);
   Check("USDJPY_target_net",(RoundPrice(yen_target-0.002,0.001,false)-yen_entry)*units*yen_volume/(yen_target+0.0075),
         0.098*units*0.14/150.1245);
   FileFlush(g_file);
   PrintFormat("MULTIASSET_PARITY result=%s checks=%d failures=%d synthetic_fixture_only=true live_orders=false",
               g_failures==0 ? "PASS" : "FAIL",g_checks,g_failures);
   return g_failures==0 ? INIT_SUCCEEDED : INIT_FAILED;
  }

void OnTick() {}

double OnTester()
  {
   return g_failures==0 && g_checks>0 ? 1.0 : 0.0;
  }

void OnDeinit(const int reason)
  {
   if(g_file!=INVALID_HANDLE) FileClose(g_file);
  }
