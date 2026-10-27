#ifndef WAVE33_TESTER_RUN_MQH
#define WAVE33_TESTER_RUN_MQH

// Optimizer tasks are still tester tasks. Normal charts never gain permission
// from the batch switch alone; this helper does not submit or close any order.
bool W33TesterContextAllowed(const bool tester,const bool optimizing,const bool allowBatch)
  {
   return tester && (!optimizing || allowBatch);
  }

string W33SafeRunToken(const string value,const int maxLen)
  {
   if(maxLen<=0) return "";
   string clean=value;
   for(int i=0;i<StringLen(clean);i++)
     {
      ushort c=StringGetCharacter(clean,i);
      if(c<32 || c==127 || c==60 || c==62 || c==58 || c==34 ||
         c==47 || c==92 || c==124 || c==63 || c==42)
         StringSetCharacter(clean,i,95);
     }
   StringTrimLeft(clean);
   if(StringLen(clean)>maxLen) clean=StringSubstr(clean,0,maxLen);
   while(StringLen(clean)>0)
     {
      int last=StringLen(clean)-1;
      ushort c=StringGetCharacter(clean,last);
      if(c==32 || c==46 || (c>=0xD800 && c<=0xDBFF))
         clean=StringSubstr(clean,0,last);
      else break;
     }
   if(clean=="") clean="_";
   // These words are reserved even when followed by a filename extension.
   string upper=clean;
   StringToUpper(upper);
   int dot=StringFind(upper,".");
   if(dot>=0) upper=StringSubstr(upper,0,dot);
   StringTrimRight(upper);
   bool reserved=(upper=="CON" || upper=="PRN" || upper=="AUX" || upper=="NUL" ||
                  upper=="CONIN$" || upper=="CONOUT$");
   if(StringLen(upper)==4)
     {
      string family=StringSubstr(upper,0,3);
      ushort number=StringGetCharacter(upper,3);
      if((family=="COM" || family=="LPT") && number>=49 && number<=57) reserved=true;
     }
   if(reserved) clean=StringSubstr("_"+clean,0,maxLen);
   return clean;
  }

bool W33BatchRunOutputExists(const string tag)
  {
   return FileIsExist(tag+"_events.csv",FILE_COMMON) ||
          FileIsExist(tag+"_config.csv",FILE_COMMON) ||
          FileIsExist(tag+"_upper_bars.csv",FILE_COMMON) ||
          FileIsExist(tag+"_lower_bars.csv",FILE_COMMON) ||
          FileIsExist(tag+"_opposite_ticks.csv",FILE_COMMON);
  }

void W33ReleaseBatchRunTag(int &claimHandle)
  {
   if(claimHandle==INVALID_HANDLE) return;
   FileClose(claimHandle);
   claimHandle=INVALID_HANDLE;
   // A nonempty marker remains occupied after a completed pass or a crash.
   // Never delete it: a later pass must not reuse and truncate its CSV files.
  }

bool W33ReserveBatchRunTag(const string requested,const string symbol,const string contextHash,
                          string &resolved,int &claimHandle,string &reason)
  {
   reason="";
   if(claimHandle!=INVALID_HANDLE)
     {
      reason="BATCH_RUN_TAG_CLAIM_ALREADY_HELD";
      return false;
     }
   resolved="";
   // At most 70 characters before the file suffix. This is independent of the
   // 63-character chart-object name limit; drawing prefixes hash the run tag.
   string base=W33SafeRunToken(requested,30)+"_"+W33SafeRunToken(symbol,18)+"_"+
               W33SafeRunToken(contextHash,16);
   int lastError=0,openFailures=0;
   for(int counter=0;counter<256;counter++)
     {
      string candidate=base+"_"+IntegerToString(counter);
      if(W33BatchRunOutputExists(candidate)) continue;
      string marker=candidate+"_claim.bin";
      ResetLastError();
      // READ|WRITE preserves an existing marker, unlike WRITE alone, which
      // truncates it. Omitting both SHARE flags serializes competing claims.
      int handle=FileOpen(marker,FILE_READ|FILE_WRITE|FILE_BIN|FILE_COMMON);
      if(handle==INVALID_HANDLE)
        {
         lastError=GetLastError();
         openFailures++;
         continue;
        }
      if(FileSize(handle)>0)
        {
         FileClose(handle);
         continue;
        }
      // Recheck after obtaining the exclusive claim. A competing pass could
      // have completed between our first existence check and FileOpen.
      if(W33BatchRunOutputExists(candidate))
        {
         FileClose(handle);
         continue;
        }
      ResetLastError();
      uint written=FileWriteInteger(handle,87,CHAR_VALUE);
      if(written!=1)
        {
         int error=GetLastError();
         FileClose(handle);
         reason="BATCH_RUN_TAG_MARKER_WRITE_FAILED error="+IntegerToString(error);
         return false;
        }
      ResetLastError();
      FileFlush(handle);
      int flushError=GetLastError();
      if(flushError!=0)
        {
         FileClose(handle);
         reason="BATCH_RUN_TAG_MARKER_FLUSH_FAILED error="+IntegerToString(flushError);
         return false;
        }
      claimHandle=handle;
      resolved=candidate;
      return true;
     }
   reason="BATCH_RUN_TAG_RESERVATION_EXHAUSTED attempts=256 open_failures="+
          IntegerToString(openFailures)+" last_error="+IntegerToString(lastError);
   return false;
  }

#endif
