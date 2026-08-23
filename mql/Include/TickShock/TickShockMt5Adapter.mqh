#ifndef TICK_SHOCK_MT5_ADAPTER_MQH
#define TICK_SHOCK_MT5_ADAPTER_MQH

#include "TickShockConfig.mqh"
#include "TickShockMetrics.mqh"

bool TSMt5SelectSymbol(const string symbol)
  {
   return SymbolSelect(symbol,true);
  }

bool TSMt5LoadSymbolSpec(const string symbol,TickShockSymbolSpec &spec)
  {
   ZeroMemory(spec);
   spec.symbol=symbol;
   spec.digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   spec.point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   spec.tick_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   spec.tick_value=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(spec.tick_value<=0.0) spec.tick_value=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
   spec.contract_size=SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);
   spec.volume_min=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   spec.volume_max=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   spec.volume_step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
   spec.stops_level=(int)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
   spec.freeze_level=(int)SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL);
   spec.filling_mode=(int)SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE);
   return TSSymbolSpecValid(spec);
  }

int TSMt5CopyInfoTicks(const string symbol,MqlTick &ticks[],const ulong from_msc,const uint count)
  {
   return CopyTicks(symbol,ticks,COPY_TICKS_INFO,from_msc,count);
  }

bool TSMt5VisibleQuote(const string symbol,MqlTick &tick)
  {
   return SymbolInfoTick(symbol,tick);
  }

long TSMt5ServerNowMsc()
  {
   return (long)TimeCurrent()*1000;
  }

long TSMt5MemoryUsedMb()
  {
   return (long)MQLInfoInteger(MQL_MEMORY_USED);
  }

bool TSMt5CalcOneLotLoss(const int direction,const string symbol,const double entry,const double sl,double &loss)
  {
   ENUM_ORDER_TYPE type=direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   return OrderCalcProfit(type,symbol,1.0,entry,sl,loss);
  }

bool TSMt5CommissionResult(const int direction,
                           const string symbol,
                           const double entry,
                           const double sl,
                           const double commission_amount,
                           const double gross_r,
                           TickShockCommissionResult &result)
  {
   double profit_or_loss=0.0;
   bool calculated=TSMt5CalcOneLotLoss(direction,symbol,entry,sl,profit_or_loss);
   return TSBuildCommissionResult(calculated,profit_or_loss,commission_amount,gross_r,result);
  }

bool TSMt5CreateTrendHandles(const string symbol,int &ema20_m15,int &ema50_m15,int &ema20_h1,int &ema50_h1)
  {
   ema20_m15=iMA(symbol,PERIOD_M15,20,0,MODE_EMA,PRICE_CLOSE);
   ema50_m15=iMA(symbol,PERIOD_M15,50,0,MODE_EMA,PRICE_CLOSE);
   ema20_h1=iMA(symbol,PERIOD_H1,20,0,MODE_EMA,PRICE_CLOSE);
   ema50_h1=iMA(symbol,PERIOD_H1,50,0,MODE_EMA,PRICE_CLOSE);
   return ema20_m15!=INVALID_HANDLE && ema50_m15!=INVALID_HANDLE &&
          ema20_h1!=INVALID_HANDLE && ema50_h1!=INVALID_HANDLE;
  }

string TSMt5TrendLabel(const string symbol,const ENUM_TIMEFRAMES timeframe,const int ema20,const int ema50)
  {
   if(ema20==INVALID_HANDLE || ema50==INVALID_HANDLE || BarsCalculated(ema20)<51 || BarsCalculated(ema50)<51) return "UNAVAILABLE";
   double e20_1[1],e20_4[1],e50_1[1];
   if(CopyBuffer(ema20,0,1,1,e20_1)!=1 || CopyBuffer(ema20,0,4,1,e20_4)!=1 || CopyBuffer(ema50,0,1,1,e50_1)!=1) return "UNAVAILABLE";
   double close_1=iClose(symbol,timeframe,1);
   if(close_1<=0.0) return "UNAVAILABLE";
   if(close_1>e20_1[0] && e20_1[0]>e50_1[0] && e20_1[0]>e20_4[0]) return "UP";
   if(close_1<e20_1[0] && e20_1[0]<e50_1[0] && e20_1[0]<e20_4[0]) return "DOWN";
   return "NEUTRAL";
  }

void TSMt5ReleaseIndicator(const int handle)
  {
   if(handle!=INVALID_HANDLE) IndicatorRelease(handle);
  }

bool TSMt5ReadRunMetadata(const string path,string &run_id,string &metadata_hash,string &header)
  {
   run_id="";metadata_hash="";header="";
   int handle=FileOpen(path,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_COMMON);
   if(handle==INVALID_HANDLE) return false;
   if(!FileIsEnding(handle)) run_id=FileReadString(handle);
   if(!FileIsEnding(handle)) metadata_hash=FileReadString(handle);
   if(!FileIsEnding(handle)) header=FileReadString(handle);
   FileClose(handle);
   return run_id!="" && metadata_hash!="" && header!="";
  }

bool TSMt5WriteRunMetadata(const string path,const string run_id,const string metadata_hash,const string header)
  {
   int handle=FileOpen(path,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(handle==INVALID_HANDLE) return false;
   FileWriteString(handle,run_id+"\r\n"+metadata_hash+"\r\n"+header+"\r\n");
   FileFlush(handle);
   FileClose(handle);
   return true;
  }

bool TSMt5ExistingCsvHeaderMatches(const string path,const string expected_header)
  {
   int handle=FileOpen(path,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_COMMON);
   if(handle==INVALID_HANDLE) return false;
   bool empty=FileSize(handle)==0;
   string actual_header=empty?"":FileReadString(handle);
   FileClose(handle);
   return empty || actual_header==expected_header;
  }

int TSMt5OpenAppendCsv(const string folder,
                       const string path,
                       const string header,
                       const string run_id,
                       const string metadata_hash,
                       ENUM_TS_CSV_OPEN_STATUS &status)
  {
   status=TS_CSV_OPEN_IO_ERROR;
   if(folder=="" || path=="" || header=="" || run_id=="" || metadata_hash=="") return INVALID_HANDLE;
   FolderCreate(folder,FILE_COMMON);
   string metadata_path=path+".runmeta";
   bool data_exists=FileIsExist(path,FILE_COMMON);
   bool metadata_exists=FileIsExist(metadata_path,FILE_COMMON);
   ENUM_TS_CSV_OPEN_STATUS success_status=TS_CSV_OPEN_CREATED;
   if(metadata_exists)
     {
      string existing_run_id="",existing_hash="",existing_header="";
      if(!TSMt5ReadRunMetadata(metadata_path,existing_run_id,existing_hash,existing_header))
        {
         status=TS_CSV_OPEN_RUN_ID_COLLISION;
         return INVALID_HANDLE;
        }
      if(existing_run_id!=run_id || existing_hash!=metadata_hash || existing_header!=header)
        {
         status=TS_CSV_OPEN_RUN_ID_COLLISION;
         return INVALID_HANDLE;
        }
      if(data_exists && !TSMt5ExistingCsvHeaderMatches(path,header))
        {
         status=TS_CSV_OPEN_RUN_ID_COLLISION;
         return INVALID_HANDLE;
        }
      success_status=TS_CSV_OPEN_RESUMED;
     }
   else
     {
      if(data_exists)
        {
         int existing=FileOpen(path,FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_COMMON);
         bool nonempty=existing!=INVALID_HANDLE && FileSize(existing)>0;
         if(existing!=INVALID_HANDLE) FileClose(existing);
         if(nonempty)
           {
            status=TS_CSV_OPEN_RUN_ID_COLLISION;
            return INVALID_HANDLE;
           }
        }
      if(!TSMt5WriteRunMetadata(metadata_path,run_id,metadata_hash,header)) return INVALID_HANDLE;
     }
   int handle=FileOpen(path,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE|FILE_COMMON);
   if(handle==INVALID_HANDLE)
     {
      status=TS_CSV_OPEN_IO_ERROR;
      return INVALID_HANDLE;
     }
   bool empty=FileSize(handle)==0;
   FileSeek(handle,0,SEEK_END);
   if(empty) FileWriteString(handle,header+"\r\n");
   status=success_status;
   return handle;
  }

void TSMt5WriteLine(const int handle,const string line)
  {
   if(handle!=INVALID_HANDLE) FileWriteString(handle,line+"\r\n");
  }

void TSMt5Flush(const int handle)
  {
   if(handle!=INVALID_HANDLE) FileFlush(handle);
  }

void TSMt5Close(int &handle)
  {
   if(handle==INVALID_HANDLE) return;
   FileFlush(handle);
   FileClose(handle);
   handle=INVALID_HANDLE;
  }

long TSMt5FileSize(const int handle)
  {
   return handle==INVALID_HANDLE?0:(long)FileSize(handle);
  }

ulong TSMt5RuntimeTickCount()
  {
   return GetTickCount64();
  }

bool TSMt5StartTimer(const int milliseconds)
  {
   return EventSetMillisecondTimer(milliseconds);
  }

void TSMt5StopTimer()
  {
   EventKillTimer();
  }

bool TSMt5IsTester()
  {
   return (bool)MQLInfoInteger(MQL_TESTER);
  }

#endif
