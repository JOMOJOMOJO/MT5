// Read-only tester observer. Missing synchronous quotes are never interpolated.
#ifndef RESEARCH_DEAL_QUOTE_AUDIT
#define RESEARCH_DEAL_QUOTE_AUDIT
int dqFile=INVALID_HANDLE;
ulong dqSeen[];
string dqName="";
void DQStart(const string filename)
  {
   dqName=filename;
   dqFile=FileOpen(filename,FILE_WRITE|FILE_CSV|FILE_COMMON|FILE_ANSI,';');
   if(dqFile==INVALID_HANDLE){Print("DQ_FATAL_FILE");return;}
   FileWrite(dqFile,"deal","position_id","order","symbol","entry_kind","type","time_msc","price","volume",
      "sl","tp","profit","commission","swap","fee","bid","ask","quote_msc","quote_status","reason");
  }
void DQCapture(const ulong ticket)
  {
   if(dqFile==INVALID_HANDLE || ticket==0)return;
   for(int j=0;j<ArraySize(dqSeen);j++)if(dqSeen[j]==ticket)return;
   if(!HistoryDealSelect(ticket))return;
   long type=HistoryDealGetInteger(ticket,DEAL_TYPE);
   if(type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL)return;
   string symbol=HistoryDealGetString(ticket,DEAL_SYMBOL);
   long stamp=HistoryDealGetInteger(ticket,DEAL_TIME_MSC);
   MqlTick q;ZeroMemory(q);string status="MISSING";
   if(SymbolInfoTick(symbol,q) && q.time_msc==stamp && q.bid>0 && q.ask>=q.bid)status="CURRENT_EXACT_MSC";
   else
     {
      ZeroMemory(q);MqlTick a[];
      int n=CopyTicksRange(symbol,a,COPY_TICKS_ALL,(ulong)stamp,(ulong)stamp);
      bool ambiguous=false;
      for(int j=0;j<n;j++)
        {
         if(a[j].time_msc!=stamp || a[j].bid<=0 || a[j].ask<a[j].bid)continue;
         if(q.bid>0 && (q.bid!=a[j].bid || q.ask!=a[j].ask))ambiguous=true;
         q=a[j];
        }
      if(ambiguous){status="AMBIGUOUS_MSC";ZeroMemory(q);}
      else if(q.bid>0)status="HISTORY_EXACT_MSC";
     }
   ulong order=(ulong)HistoryDealGetInteger(ticket,DEAL_ORDER);
   double sl=0,tp=0;
   if(HistoryOrderSelect(order)){sl=HistoryOrderGetDouble(order,ORDER_SL);tp=HistoryOrderGetDouble(order,ORDER_TP);}
   FileWrite(dqFile,ticket,HistoryDealGetInteger(ticket,DEAL_POSITION_ID),order,symbol,
      HistoryDealGetInteger(ticket,DEAL_ENTRY),type,stamp,DoubleToString(HistoryDealGetDouble(ticket,DEAL_PRICE),12),
      DoubleToString(HistoryDealGetDouble(ticket,DEAL_VOLUME),8),DoubleToString(sl,12),DoubleToString(tp,12),
      DoubleToString(HistoryDealGetDouble(ticket,DEAL_PROFIT),8),DoubleToString(HistoryDealGetDouble(ticket,DEAL_COMMISSION),8),
      DoubleToString(HistoryDealGetDouble(ticket,DEAL_SWAP),8),DoubleToString(HistoryDealGetDouble(ticket,DEAL_FEE),8),
      DoubleToString(q.bid,12),DoubleToString(q.ask,12),q.time_msc,status,HistoryDealGetInteger(ticket,DEAL_REASON));
   int size=ArraySize(dqSeen);ArrayResize(dqSeen,size+1);dqSeen[size]=ticket;FileFlush(dqFile);
  }
void DQDrain()
  {
   if(!HistorySelect(0,TimeCurrent()))return;
   int n=HistoryDealsTotal();ulong ids[];ArrayResize(ids,n);
   for(int j=0;j<n;j++)ids[j]=HistoryDealGetTicket(j);
   for(int j=0;j<n;j++)DQCapture(ids[j]);
  }
void DQClose(){DQDrain();if(dqFile!=INVALID_HANDLE){FileClose(dqFile);dqFile=INVALID_HANDLE;}}
#endif
