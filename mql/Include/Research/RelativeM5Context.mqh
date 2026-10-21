// Research-only hooks; the production EA and shared M15 classifier are unchanged.
enum MCPolicy { MC_FIXED=0, MC_UP_ONLY=1, MC_NON_DOWN=2, MC_UP2_RANGE1=3 };
input MCPolicy InpM15ResearchPolicy=MC_FIXED;
CM15Environment mcEnv;
M15EnvSnapshot mcPlan;
datetime mcCacheBar=0,mcPlanWhen=0;
int mcClosed=0,mcFile=INVALID_HANDLE;
bool mcValid=false;
double mcPlanRR=0.0;

bool MCOpen()
  {
   if(mcFile!=INVALID_HANDLE) return true;
   mcFile=FileOpen(runtimeTelemetryFileName+".m15.csv",FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI|FILE_SHARE_READ,';');
   if(mcFile==INVALID_HANDLE) return false;
   FileWrite(mcFile,"stage","time","signal_bar","ask_or_fill","regime","position","raw_position","location",
             "structure_high","structure_low","asof","break_direction","break_time","break_confirmed","break_minutes",
             "execution_gate","policy_allowed","rr","closed_m15_bars","decision_time");
   return true;
  }

bool MCLoad(const datetime when)
  {
   datetime bar=iTime(runtimeSymbol,PERIOD_M15,0);
   if(bar>0 && bar==mcCacheBar && mcValid) return true;
   MqlRates r[];ArraySetAsSeries(r,false);
   int n=CopyRates(runtimeSymbol,PERIOD_M15,0,1200,r);
   mcEnv.Reset();mcClosed=0;mcValid=false;
   if(n<1199) return false;
   for(int i=0;i<n;i++)
     {
      if(r[i].time+900>when) break;
      mcEnv.Step(r,i);mcClosed++;
     }
   mcCacheBar=bar;
   mcValid=mcClosed>=1198 && mcEnv.last<=when && mcEnv.last>0;
   return mcValid;
  }

bool MCPolicyDecision(const string regime,double &rr)
  {
   if(InpM15ResearchPolicy==MC_FIXED) return true;
   if(InpM15ResearchPolicy==MC_UP_ONLY) return regime=="UP";
   if(InpM15ResearchPolicy==MC_NON_DOWN) return regime=="UP" || regime=="RANGE";
   if(InpM15ResearchPolicy==MC_UP2_RANGE1)
     {
      if(regime=="UP") { rr=2.0; return true; }
      if(regime=="RANGE") { rr=1.0; return true; }
     }
   return false;
  }

void MCWrite(const string stage,const datetime when,const datetime signalBar,const double price,
             const M15EnvSnapshot &s,const bool gate,const bool allowed,const double rr,const datetime decision)
  {
   if(!MCOpen()) return;
   if(s.asof>when || s.break_confirmed>when || decision>when)
      Print("MC_CAUSAL_FAILURE");
   FileWrite(mcFile,stage,TimeToString(when,TIME_DATE|TIME_SECONDS),TimeToString(signalBar,TIME_DATE|TIME_SECONDS),
             DoubleToString(price,8),s.regime,s.position,DoubleToString(s.raw,12),s.location,
             DoubleToString(s.high,8),DoubleToString(s.low,8),TimeToString(s.asof,TIME_DATE|TIME_SECONDS),
             s.break_direction,TimeToString(s.break_time,TIME_DATE|TIME_SECONDS),TimeToString(s.break_confirmed,TIME_DATE|TIME_SECONDS),
             DoubleToString(s.break_minutes,2),gate,allowed,rr,mcClosed,TimeToString(decision,TIME_DATE|TIME_SECONDS));
  }

void MCCandidate(const datetime barTime,const bool gate)
  {
   datetime now=TimeCurrent();MqlTick t;if(!SymbolInfoTick(runtimeSymbol,t)) return;
   bool ready=MCLoad(now);M15EnvSnapshot s;mcEnv.Snapshot(now,t.ask,s);
   if(!ready) { s.regime="UNKNOWN";s.position="UNKNOWN"; }
   double rr=InpTargetRMultiple;
   bool allowed=MCPolicyDecision(s.regime,rr);
   MCWrite("CANDIDATE",now,barTime,t.ask,s,gate,allowed,rr,now);
  }

bool MCBeforeOrder(double &rr)
  {
   datetime now=TimeCurrent();MqlTick t;if(!SymbolInfoTick(runtimeSymbol,t)) return false;
   bool ready=MCLoad(now);mcEnv.Snapshot(now,t.ask,mcPlan);
   if(!ready) { mcPlan.regime="UNKNOWN";mcPlan.position="UNKNOWN"; }
   bool allowed=MCPolicyDecision(mcPlan.regime,rr);
   mcPlanRR=rr;mcPlanWhen=now;
   return allowed;
  }

void MCEntry(const datetime when,const double fill)
  {
   // Copy the decision-time structure; never advance it at a delayed deal event.
   M15EnvSnapshot s=mcPlan;
   if(s.high>s.low && fill>0 && s.regime!="UNKNOWN")
     {
      s.raw=(fill-s.low)/(s.high-s.low);s.normalized=MathMax(0.0,MathMin(1.0,s.raw));
      s.position=s.normalized<=1.0/3.0?"LOW":(s.normalized<=2.0/3.0?"MID":"HIGH");
      s.location=s.raw<0?"BELOW":(s.raw>1?"ABOVE":"INSIDE");
     }
   MCWrite("ENTRY",when,iTime(runtimeSymbol,InpSignalTimeframe,0),fill,s,true,true,mcPlanRR,mcPlanWhen);
  }

void MCClose() { if(mcFile!=INVALID_HANDLE) FileClose(mcFile); }
