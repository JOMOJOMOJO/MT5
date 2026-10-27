#property strict
#property version "1.00"
#property description "Tester-mode safety and parallel CSV reservation checks; no trading."
#include "../../Include/Wave33Visual/TesterRun.mqh"

input string InpRunTag="tester_run_harness";
int g_file=INVALID_HANDLE,g_passed=0,g_failed=0;
int g_claims[6];
string g_tags[6];

void Check(const string name,const bool passed,const string detail)
  {
   if(passed) g_passed++; else g_failed++;
   if(g_file!=INVALID_HANDLE) FileWrite(g_file,name,passed ? "PASS" : "FAIL",detail);
   Print("W33_TESTER_RUN_TEST ",passed ? "PASS " : "FAIL ",name," ",detail);
  }
bool SafeComponent(const string value,const int limit)
  {
   int n=StringLen(value);
   if(n<1 || n>limit || value=="." || value=="..") return false;
   for(int i=0;i<n;i++)
     {
      ushort c=StringGetCharacter(value,i);
      if(c<32 || c==127 || c==60 || c==62 || c==58 || c==34 || c==47 || c==92 || c==124 || c==63 || c==42) return false;
     }
   ushort last=StringGetCharacter(value,n-1);
   return last!=32 && last!=46;
  }
string NextCounter(const string value)
  {
   int last=-1,next=StringFind(value,"_");
   while(next>=0) { last=next; next=StringFind(value,"_",last+1); }
   if(last<0) return "";
   int counter=(int)StringToInteger(StringSubstr(value,last+1));
   return StringSubstr(value,0,last+1)+IntegerToString(counter+1);
  }
bool WriteFixture(const string path,const string contents)
  {
   // Every fixture is inside this unique harness reservation prefix. Existing
   // files are never opened for overwrite, and no historical files are deleted.
   if(FileIsExist(path,FILE_COMMON)) return false;
   int handle=FileOpen(path,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
   if(handle==INVALID_HANDLE) return false;
   uint written=FileWriteString(handle,contents);
   FileFlush(handle); FileClose(handle);
   return written>0;
  }
bool FixtureUnchanged(const string path,const string contents)
  {
   int handle=FileOpen(path,FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON,0,CP_UTF8);
   if(handle==INVALID_HANDLE) return false;
   string read=FileReadString(handle);
   FileClose(handle);
   return read==contents;
  }
bool MarkerPresent(const string tag)
  {
   string name=tag+"_claim.bin";
   if(!FileIsExist(name,FILE_COMMON)) return false;
   int handle=FileOpen(name,FILE_READ|FILE_BIN|FILE_COMMON);
   if(handle==INVALID_HANDLE) return false;
   bool present=FileSize(handle)>0 && FileReadInteger(handle,CHAR_VALUE)==87;
   FileClose(handle);
   return present;
  }
void TestContext()
  {
   for(int tester=0;tester<2;tester++)
      for(int optimizing=0;optimizing<2;optimizing++)
         for(int allow=0;allow<2;allow++)
           {
            bool expected=tester==1 && (optimizing==0 || allow==1);
            Check(StringFormat("context_t%d_o%d_allow%d",tester,optimizing,allow),
                  W33TesterContextAllowed(tester==1,optimizing==1,allow==1)==expected,
                  "Batch permission can enable tester optimization, while every normal-chart combination stays denied");
           }
  }
void TestTokens()
  {
   Check("ordinary_token_preserved",W33SafeRunToken("Wave33_A_2020",30)=="Wave33_A_2020","Ordinary run identifiers stay recognizable");
   string bad="../A\\B:C*D?E\"F<G>H|I\nJ\t";
   Check("unsafe_path_characters_removed",SafeComponent(W33SafeRunToken(bad,32),32),"No slash, path separator, Windows forbidden character or control character survives");
   string longValue="";
   for(int i=0;i<200;i++) longValue+="x";
   Check("token_length_bounded",StringLen(W33SafeRunToken(longValue,17))==17,"Long requested tags cannot exceed the configured component bound");
   Check("empty_token_has_safe_fallback",W33SafeRunToken("",12)=="_","An empty component receives a usable filename fallback");
   Check("nonpositive_bound_empty",W33SafeRunToken("abc",0)=="" && W33SafeRunToken("abc",-1)=="","A nonpositive component bound produces no characters");
   Check("trailing_dots_spaces_removed",SafeComponent(W33SafeRunToken("  sample...  ",20),20),"Windows-normalized trailing dots and spaces do not survive");
   string devices[]={"CON","NUL","COM1","lpt9"};
   for(int i=0;i<ArraySize(devices);i++)
      Check("reserved_device_"+IntegerToString(i),W33SafeRunToken(devices[i],12)!=(devices[i]) && SafeComponent(W33SafeRunToken(devices[i],12),12),
            "Windows reserved device names receive a safe prefix");
   Check("reserved_device_with_extension",StringFind(W33SafeRunToken("CON.txt",20),"_CON")==0,
         "A device name remains reserved before a filename extension; a suffix alone cannot make it safe");
  }
void TestReservations()
  {
   string requested="W33RunQA_"+W33SafeRunToken(InpRunTag,21);
   string context="t"+IntegerToString((long)TimeLocal())+"_"+IntegerToString((long)GetTickCount());
   string why="";
   bool first=W33ReserveBatchRunTag(requested,"XAUUSD+",context,g_tags[0],g_claims[0],why);
   Check("first_reservation",first && g_claims[0]!=INVALID_HANDLE && why=="" && SafeComponent(g_tags[0],70),"The first pass obtains a bounded tag and a held exclusive claim");
   if(!first) return;
   Check("symbol_identity_in_tag",StringFind(g_tags[0],"XAUUSD+")>=0 && StringFind(g_tags[0],W33SafeRunToken(requested,30))==0,
         "The resolved name identifies this test request and its symbol");
   int forbidden=FileOpen(g_tags[0]+"_claim.bin",FILE_READ|FILE_BIN|FILE_COMMON);
   bool exclusive=forbidden==INVALID_HANDLE;
   if(forbidden!=INVALID_HANDLE) FileClose(forbidden);
   ResetLastError();
   Check("held_claim_is_exclusive",exclusive,"An unrelated reader cannot open the non-shared held claim");
   int savedHandle=g_claims[0]; string savedTag=g_tags[0];
   bool repeated=W33ReserveBatchRunTag(requested,"XAUUSD+",context,g_tags[0],g_claims[0],why);
   Check("already_held_handle_not_replaced",!repeated && g_claims[0]==savedHandle && g_tags[0]==savedTag && why=="BATCH_RUN_TAG_CLAIM_ALREADY_HELD",
         "A repeated call with a live handle cannot leak it or silently replace its namespace");
   bool second=W33ReserveBatchRunTag(requested,"XAUUSD+",context,g_tags[1],g_claims[1],why);
   Check("simultaneous_same_context_distinct",second && g_claims[1]!=INVALID_HANDLE && g_tags[1]!=g_tags[0],
         "Two identical contexts held simultaneously receive different output namespaces");
   Check("reservation_does_not_create_events",!FileIsExist(g_tags[0]+"_events.csv",FILE_COMMON),"Durable occupancy is independent of creating any CSV output");
   W33ReleaseBatchRunTag(g_claims[0]);
   Check("release_invalidates_handle",g_claims[0]==INVALID_HANDLE,"Release makes the caller's handle explicitly invalid");
   Check("released_marker_remains_nonempty",MarkerPresent(g_tags[0]),"A durable marker remains after release and has not been truncated");
   W33ReleaseBatchRunTag(g_claims[0]);
   Check("release_is_idempotent",g_claims[0]==INVALID_HANDLE,"Repeated cleanup of an invalid handle is harmless");
   bool third=W33ReserveBatchRunTag(requested,"XAUUSD+",context,g_tags[2],g_claims[2],why);
   Check("released_namespace_never_reused",third && g_tags[2]!=g_tags[0] && g_tags[2]!=g_tags[1],
         "A completed pass's marker continues blocking reuse even though it has no CSV file");
   if(third)
     {
      string occupied=NextCounter(g_tags[2]),path=occupied+"_events.csv",contents="HARNESS_EXISTING_EVENTS_MUST_SURVIVE";
      bool written=occupied!="" && WriteFixture(path,contents);
      Check("preexisting_events_fixture_created",written,"The legacy-output fixture uses only this new harness-owned prefix");
      bool fourth=W33ReserveBatchRunTag(requested,"XAUUSD+",context,g_tags[3],g_claims[3],why);
      Check("preexisting_events_namespace_skipped",written && fourth && g_tags[3]!=occupied,
            "A pre-existing events CSV without a prior claim cannot be selected for truncation");
      Check("preexisting_events_contents_preserved",written && FixtureUnchanged(path,contents),"Reservation leaves the exact existing event contents unchanged");
     }
   bool otherSymbol=W33ReserveBatchRunTag(requested,"EURUSD+",context,g_tags[4],g_claims[4],why);
   Check("different_symbol_is_separate",otherSymbol && g_tags[4]!=g_tags[1] && StringFind(g_tags[4],"EURUSD+")>=0,
         "Different Market Watch symbols cannot share CSV identities");
   bool otherContext=W33ReserveBatchRunTag(requested,"XAUUSD+","different_context",g_tags[5],g_claims[5],why);
   Check("different_context_is_separate",otherContext && g_tags[5]!=g_tags[1],"Different pass contexts retain distinct namespaces");
   bool bounded=true,distinct=true;
   for(int i=0;i<ArraySize(g_tags);i++)
     {
      bounded=bounded && SafeComponent(g_tags[i],70);
      for(int j=0;j<i;j++) distinct=distinct && g_tags[i]!=g_tags[j];
     }
   Check("all_resolved_paths_bounded",bounded,"All reservation paths stay within the documented 70-character tag bound");
   Check("all_reservations_pairwise_distinct",distinct,"Every fixture namespace remains distinct across held and released claims");
   for(int i=0;i<ArraySize(g_claims);i++) W33ReleaseBatchRunTag(g_claims[i]);
   bool released=true,markers=true;
   for(int i=0;i<ArraySize(g_claims);i++) { released=released && g_claims[i]==INVALID_HANDLE; markers=markers && MarkerPresent(g_tags[i]); }
   Check("all_handles_released",released,"The test releases every claim it acquired");
   Check("all_durable_markers_reopen_after_cleanup",markers,"All retained markers can be read after cleanup, proving no test handle remains locked");
  }
int OnInit()
  {
   for(int i=0;i<ArraySize(g_claims);i++) { g_claims[i]=INVALID_HANDLE; g_tags[i]=""; }
   string csvTag=W33SafeRunToken(InpRunTag,100);
   g_file=FileOpen("W33Harness_"+csvTag+".csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(g_file==INVALID_HANDLE) return INIT_FAILED;
   FileWrite(g_file,"test","passed","detail");
   TestContext(); TestTokens(); TestReservations();
   for(int i=0;i<ArraySize(g_claims);i++) W33ReleaseBatchRunTag(g_claims[i]);
   FileWrite(g_file,"FINAL",g_failed==0 ? "PASS" : "FAIL",StringFormat("passed=%d failed=%d",g_passed,g_failed));
   FileFlush(g_file); FileClose(g_file); g_file=INVALID_HANDLE;
   PrintFormat("W33_TESTER_RUN_HARNESS_FINAL passed=%d failed=%d",g_passed,g_failed);
   return INIT_SUCCEEDED;
  }
void OnTick() { if(MQLInfoInteger(MQL_TESTER)) TesterStop(); }
void OnDeinit(const int reason) { for(int i=0;i<ArraySize(g_claims);i++) W33ReleaseBatchRunTag(g_claims[i]); }
double OnTester() { return g_failed==0 ? 1.0 : 0.0; }
