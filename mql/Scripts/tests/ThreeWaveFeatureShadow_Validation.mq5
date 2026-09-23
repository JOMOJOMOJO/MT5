#property strict
#define OnInit FeatureEAInit
#define OnTick FeatureEATick
#define OnDeinit FeatureEADeinit
#include "../../Experts/USDJPY_3Wave_FeatureResearch.mq5"
#undef OnInit
#undef OnTick
#undef OnDeinit
int checks=0,failures=0;
void Check(bool pass,string name)
{checks++;if(!pass)failures++;Print(pass?"PASS ":"FAIL ",name);}
void Fixture()
{
   ArrayResize(active,1);ZeroMemory(active[0]);
   active[0].id="test";active[0].basis="STAGE";active[0].outcome="OPEN";
   active[0].entry_msc=1000000;active[0].entry=150;active[0].sl=149;active[0].tp=151;active[0].risk=1;
}
void OnStart()
{
   f_outcomes=FileOpen("TW_feature_shadow_unit.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   MqlTick tick={};tick.time_msc=1000000;tick.bid=149.99;tick.ask=150;
   Fixture();ObserveTick(tick);
   Check(!active[0].done && active[0].outcome=="OPEN","entry spread does not close shadow");
   Check(MathAbs(active[0].mae-0.01)<1e-9,"spread included in MAE");
   tick.time_msc+=1000;tick.bid=151.2;ObserveTick(tick);
   Check(active[0].done && active[0].outcome=="TP" && active[0].result==1,"TP label uses target not favorable gap");
   tick.time_msc+=1000;tick.bid=148;ObserveTick(tick);
   Check(active[0].result==1 && active[0].mae60==2,"post-exit excursion changes fixed horizon only");
   Fixture();tick.time_msc=1001000;tick.bid=148.8;ObserveTick(tick);
   Check(active[0].done && active[0].outcome=="SL" && MathAbs(active[0].result+1.2)<1e-9,"adverse gap retained in stop loss R");
   Fixture();tick.time_msc=1000000+14400000;tick.bid=150.2;ObserveTick(tick);
   Check(ArraySize(active)==0,"240-minute mark-to-market timeout completes shadow");
   Fixture();tick.time_msc=1001000;tick.bid=151;ObserveTick(tick);
   tick.time_msc=1000000+3600000;tick.bid=150;ObserveTick(tick);
   Check(ArraySize(active)==0,"complete 60-minute horizon releases finished shadow");
   FileClose(f_outcomes);f_outcomes=INVALID_HANDLE;
   Print("TW_FEATURE_SHADOW_UNIT_RESULT checks=",checks," failures=",failures);
}
