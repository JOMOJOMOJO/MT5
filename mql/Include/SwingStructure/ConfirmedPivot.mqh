#ifndef SWING_STRUCTURE_CONFIRMED_PIVOT_MQH
#define SWING_STRUCTURE_CONFIRMED_PIVOT_MQH

struct SSPivot
{
   datetime bar_time;
   datetime confirmed_time;
   double price;
   bool high;
   bool ambiguous;
};

// Chronological array: index 0 is oldest, count-1 is the forming bar.
// The next actual bar open proves that the last right-hand bar closed.
int SSDetect(const MqlRates &rates[],const int count,const int i,
             const int left,const int right)
{
   if(left<1 || right<1 || i<left || i+right>=count-1)
      return 0;
   bool hi=true,lo=true;
   for(int k=1;k<=left;k++)
   {
      if(rates[i].high<=rates[i-k].high) hi=false;
      if(rates[i].low>=rates[i-k].low) lo=false;
   }
   for(int k=1;k<=right;k++)
   {
      if(rates[i].high<=rates[i+k].high) hi=false;
      if(rates[i].low>=rates[i+k].low) lo=false;
   }
   return (hi ? 1 : 0)+(lo ? 2 : 0);
}

// Append-only within an instance. Even history corrections do not rewrite records.
void SSCollect(const MqlRates &rates[],const int count,const int left,
               const int right,datetime &processed,SSPivot &pivots[])
{
   for(int i=left;i<count-right-1;i++)
   {
      if(rates[i].time<=processed) continue;
      const int flags=SSDetect(rates,count,i,left,right);
      for(int kind=1;kind<=2;kind++)
      {
         if((flags & kind)==0) continue;
         const int n=ArraySize(pivots);
         ArrayResize(pivots,n+1,1024);
         pivots[n].bar_time=rates[i].time;
         pivots[n].confirmed_time=rates[i+right+1].time;
         pivots[n].price=(kind==1 ? rates[i].high : rates[i].low);
         pivots[n].high=(kind==1);
         pivots[n].ambiguous=(flags==3);
      }
      processed=rates[i].time;
   }
}

bool SSCanConnect(const SSPivot &a,const SSPivot &b)
{
   return !a.ambiguous && !b.ambiguous && a.high!=b.high &&
          a.bar_time<b.bar_time && a.confirmed_time<b.confirmed_time;
}

// Exact timestamp mapping to a descending M1 chart array. Never snap across gaps.
int SSChartIndex(const datetime &times[],const int count,const datetime target)
{
   int first=0,last=count-1;
   while(first<=last)
   {
      const int mid=first+(last-first)/2;
      if(times[mid]==target) return mid;
      if(times[mid]>target) first=mid+1;
      else last=mid-1;
   }
   return -1;
}
#endif
