#ifndef W33_H1_EFFICIENCY_TESTS
#define W33_H1_EFFICIENCY_TESTS
#include "H1Efficiency.mqh"

int g_h1eff_checks=0;
int g_h1eff_failures=0;
int g_h1eff_test_file=INVALID_HANDLE;

void W33H1EffCheck(const string name,const bool ok)
  {
   g_h1eff_checks++;
   if(!ok)g_h1eff_failures++;
   Print("H1_EFFICIENCY_POLICY ",name," ",ok?"PASS":"FAIL");
   if(g_h1eff_test_file!=INVALID_HANDLE)
      FileWrite(g_h1eff_test_file,name,ok?"PASS":"FAIL");
  }

bool W33H1EffEq(const double actual,const double expected)
  {
   return MathIsValidNumber(actual) && MathAbs(actual-expected)<1.0e-10;
  }

void W33H1EffFixture(datetime &times[],double &closes[])
  {
   ArrayResize(times,W33_H1_EFFICIENCY_CLOSES);
   ArrayResize(closes,W33_H1_EFFICIENCY_CLOSES);
   for(int i=0;i<W33_H1_EFFICIENCY_CLOSES;i++)
     {
      times[i]=D'2025.01.06 00:00'+i*3600;
      closes[i]=100.0+i;
     }
  }

string W33H1EffSafeTag(const string tag)
  {
   string safe="";
   for(int i=0;i<StringLen(tag) && i<80;i++)
     {
      ushort c=StringGetCharacter(tag,i);
      bool allowed=(c>='a' && c<='z') || (c>='A' && c<='Z') ||
                   (c>='0' && c<='9') || c=='_' || c=='-';
      safe+=allowed?StringSubstr(tag,i,1):"_";
     }
   return safe==""?"w33_h1eff_policy":safe;
  }

int W33RunH1EfficiencyTests(const string tag)
  {
   g_h1eff_checks=0;
   g_h1eff_failures=0;
   g_h1eff_test_file=FileOpen(W33H1EffSafeTag(tag)+"_h1efficiency_policy_tests.csv",
                            FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,';',CP_UTF8);
   W33H1EffCheck("report_file",g_h1eff_test_file!=INVALID_HANDLE);
   datetime t[];
   double c[];
   W33H1EffFixture(t,c);
   datetime decision=t[12]+3600;
   W33H1EfficiencyResult r=W33H1Efficiency(t,c,decision);
   W33H1EffCheck("monotonic_up_valid",r.valid && r.reason=="OK" && r.count==13);
   W33H1EffCheck("monotonic_up_er_one",W33H1EffEq(r.er,1.0) && W33H1EffEq(r.roundtrip,0.0));
   W33H1EffCheck("twelve_changes",W33H1EffEq(r.net_distance,12.0) && W33H1EffEq(r.path_distance,12.0));
   W33H1EffCheck("time_metadata",r.first_time==t[0] && r.last_time==t[12] && r.span_seconds==43200 && r.gap_count==0);
   W33H1EffCheck("high_efficiency_allowed",!W33H1EfficiencyShouldSkip(true,r));
   W33H1EffCheck("close_boundary_known",r.valid);

   for(int i=0;i<13;i++)c[i]=112.0-i;
   r=W33H1Efficiency(t,c,decision);
   W33H1EffCheck("monotonic_down",r.valid && W33H1EffEq(r.er,1.0));
   for(int i=0;i<13;i++)c[i]=100.0+(i%2);
   r=W33H1Efficiency(t,c,decision);
   W33H1EffCheck("alternating_er_zero",r.valid && W33H1EffEq(r.er,0.0) && W33H1EffEq(r.roundtrip,1.0));
   W33H1EffCheck("alternating_path",W33H1EffEq(r.net_distance,0.0) && W33H1EffEq(r.path_distance,12.0));
   W33H1EffCheck("low_efficiency_skipped",W33H1EfficiencyShouldSkip(true,r));
   W33H1EffCheck("gate_disabled",!W33H1EfficiencyShouldSkip(false,r));

   // One V-shaped reversal also has ER=0. It need not be a choppy zigzag.
   for(int i=0;i<13;i++)c[i]=100.0+MathAbs(i-6);
   r=W33H1Efficiency(t,c,decision);
   W33H1EffCheck("v_turn_counterexample",r.valid && W33H1EffEq(r.er,0.0) && W33H1EffEq(r.path_distance,12.0));

   for(int i=0;i<13;i++)c[i]=i==0?100.0:(i==1?105.0:102.0);
   r=W33H1Efficiency(t,c,decision);
   W33H1EffCheck("exact_threshold",r.valid && W33H1EffEq(r.er,0.25) && W33H1EfficiencyShouldSkip(true,r));
   double base_er=r.er;
   for(int i=0;i<13;i++)c[i]=200.0-c[i];
   r=W33H1Efficiency(t,c,decision);
   W33H1EffCheck("direction_symmetry",r.valid && W33H1EffEq(r.er,base_er));
   for(int i=0;i<13;i++)c[i]+=37.0;
   r=W33H1Efficiency(t,c,decision);
   W33H1EffCheck("translation_invariance",r.valid && W33H1EffEq(r.er,base_er));
   for(int i=0;i<13;i++)c[i]*=0.125;
   r=W33H1Efficiency(t,c,decision);
   W33H1EffCheck("positive_scale_invariance",r.valid && W33H1EffEq(r.er,base_er));

   // Nine +1 moves followed by three -1.8 moves have mathematical ER=0.25.
   c[0]=100.0;
   for(int i=1;i<13;i++)c[i]=c[i-1]+(i<=9?1.0:-1.8);
   r=W33H1Efficiency(t,c,decision);
   W33H1EffCheck("decimal_threshold_rounding",r.valid && W33H1EffEq(r.er,0.25) && W33H1EfficiencyShouldSkip(true,r));
   r.er=0.25+1.0e-8;
   W33H1EffCheck("above_threshold_not_hidden",!W33H1EfficiencyShouldSkip(true,r));
   r.er=0.25-1.0e-8;
   W33H1EffCheck("below_threshold_skipped",W33H1EfficiencyShouldSkip(true,r));

   W33H1EffFixture(t,c);
   c[0]=100.0;
   for(int i=1;i<13;i++)c[i]=c[i-1]+(i<=9?1.0:-1.8);
   r=W33H1Efficiency(t,c,t[12]+3600);
   base_er=r.er;
   for(int i=6;i<13;i++)t[i]+=48*3600;
   r=W33H1Efficiency(t,c,t[12]+3600);
   W33H1EffCheck("weekend_gap_not_vetoed",r.valid && r.gap_count==1 && r.span_seconds==60*3600);
   W33H1EffCheck("observed_bar_gap_same_er",W33H1EffEq(r.er,base_er));
   W33H1EffCheck("gap_does_not_change_gate",W33H1EfficiencyShouldSkip(true,r));
   W33H1EffFixture(t,c);
   for(int i=3;i<13;i++)t[i]+=3600;
   for(int i=9;i<13;i++)t[i]+=3600;
   r=W33H1Efficiency(t,c,t[12]+3600);
   W33H1EffCheck("multiple_gaps_counted",r.valid && r.gap_count==2 && r.span_seconds==14*3600);

   W33H1EffFixture(t,c);
   r=W33H1Efficiency(t,c,t[12]+3599);
   W33H1EffCheck("forming_bar_rejected",!r.valid && r.reason=="FUTURE_OR_FORMING_BAR");
   W33H1EffCheck("invalid_does_not_skip",!W33H1EfficiencyShouldSkip(true,r));
   r=W33H1Efficiency(t,c,t[11]+3600);
   W33H1EffCheck("future_bar_rejected",!r.valid && r.reason=="FUTURE_OR_FORMING_BAR");
   r=W33H1Efficiency(t,c,0);
   W33H1EffCheck("invalid_decision_rejected",!r.valid && r.reason=="INVALID_DECISION_TIME");
   t[6]=t[5];
   r=W33H1Efficiency(t,c,decision);
   W33H1EffCheck("duplicate_time_rejected",!r.valid && r.reason=="UNORDERED_TIME");
   t[6]=t[5]-3600;
   r=W33H1Efficiency(t,c,decision);
   W33H1EffCheck("unordered_time_rejected",!r.valid && r.reason=="UNORDERED_TIME");
   W33H1EffFixture(t,c);
   for(int i=0;i<13;i++)t[i]+=1800;
   r=W33H1Efficiency(t,c,t[12]+3600);
   W33H1EffCheck("off_hour_time_rejected",!r.valid && r.reason=="OFF_HOUR_TIME");
   W33H1EffFixture(t,c);
   t[0]=0;
   r=W33H1Efficiency(t,c,decision);
   W33H1EffCheck("nonpositive_time_rejected",!r.valid && r.reason=="INVALID_TIME");

   W33H1EffFixture(t,c);
   ArrayResize(c,12);
   r=W33H1Efficiency(t,c,decision);
   W33H1EffCheck("missing_close_rejected",!r.valid && r.reason=="ARRAY_LENGTH");
   W33H1EffFixture(t,c);
   ArrayResize(t,12);
   r=W33H1Efficiency(t,c,decision);
   W33H1EffCheck("missing_time_rejected",!r.valid && r.reason=="ARRAY_LENGTH");
   W33H1EffFixture(t,c);
   ArrayResize(t,14);
   ArrayResize(c,14);
   r=W33H1Efficiency(t,c,decision);
   W33H1EffCheck("extra_observation_rejected",!r.valid && r.reason=="ARRAY_LENGTH");
   ArrayResize(t,0);
   ArrayResize(c,0);
   r=W33H1Efficiency(t,c,decision);
   W33H1EffCheck("empty_input_rejected",!r.valid && r.reason=="ARRAY_LENGTH");

   W33H1EffFixture(t,c);
   for(int i=0;i<13;i++)c[i]=100.0;
   r=W33H1Efficiency(t,c,decision);
   W33H1EffCheck("flat_zero_path_unknown",!r.valid && r.reason=="ZERO_PATH" && W33H1EffEq(r.path_distance,0.0));
   W33H1EffCheck("flat_not_automatic_veto",!W33H1EfficiencyShouldSkip(true,r));
   c[5]=0.0;
   r=W33H1Efficiency(t,c,decision);
   W33H1EffCheck("zero_close_rejected",!r.valid && r.reason=="INVALID_CLOSE");
   c[5]=-1.0;
   r=W33H1Efficiency(t,c,decision);
   W33H1EffCheck("negative_close_rejected",!r.valid && r.reason=="INVALID_CLOSE");
   double outside_domain=2.0;
   c[5]=MathArcsin(outside_domain);
   W33H1EffCheck("nan_fixture_is_invalid",!MathIsValidNumber(c[5]));
   r=W33H1Efficiency(t,c,decision);
   W33H1EffCheck("nan_close_rejected",!r.valid && r.reason=="INVALID_CLOSE");
   W33H1EffFixture(t,c);
   for(int i=0;i<13;i++)c[i]=1.0e-9+i*1.0e-12;
   r=W33H1Efficiency(t,c,decision);
   W33H1EffCheck("small_positive_path_not_flat",r.valid && W33H1EffEq(r.er,1.0));
   W33H1EffCheck("safe_report_tag",W33H1EffSafeTag("../bad\\name:*")=="___bad_name__");
   W33H1EffCheck("empty_report_tag",W33H1EffSafeTag("")=="w33_h1eff_policy");

   if(g_h1eff_test_file!=INVALID_HANDLE)
     {
      FileWrite(g_h1eff_test_file,"SUMMARY",g_h1eff_failures==0?"PASS":"FAIL",
                g_h1eff_checks,g_h1eff_failures);
      FileClose(g_h1eff_test_file);
      g_h1eff_test_file=INVALID_HANDLE;
     }
   return g_h1eff_failures;
  }

#endif
