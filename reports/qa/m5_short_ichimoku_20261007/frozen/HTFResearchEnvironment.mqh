// Diagnostic-only core shared by the production display and research replay.
#ifndef HTF_RESEARCH_ENVIRONMENT_CORE
#define HTF_RESEARCH_ENVIRONMENT_CORE
struct HTFResearchPivot { double price; datetime bar,confirmed; };
struct HTFResearchSnapshot
{
   string regime,position,location,break_direction;
   double high,low,raw,normalized,break_level,break_minutes;
   datetime asof,break_time,break_bar,break_confirmed;
};
class CHTFResearchEnvironment
{
private:
   HTFResearchPivot ho,hn,lo,ln;
   int highs,lows;
   datetime used_high,used_low,bull_time,bear_time;
   HTFResearchPivot bull,bear;
public:
   datetime last;
   void Reset()
   {
      ZeroMemory(ho);ZeroMemory(hn);ZeroMemory(lo);ZeroMemory(ln);
      ZeroMemory(bull);ZeroMemory(bear);highs=0;lows=0;last=0;
      used_high=0;used_low=0;bull_time=0;bear_time=0;
   }
   void Step(const MqlRates &r[],const int i,const int seconds)
   {
      datetime known=r[i].time+seconds;if(known<=last) return;
      int k=i-2;
      if(k>=2)
      {
         bool h=true,l=true;
         for(int j=1;j<=2;j++)
         {
            if(r[k].high<=r[k-j].high || r[k].high<r[k+j].high) h=false;
            if(r[k].low>=r[k-j].low || r[k].low>r[k+j].low) l=false;
         }
         if(h){ho=hn;hn.price=r[k].high;hn.bar=r[k].time;hn.confirmed=known;highs++;}
         if(l){lo=ln;ln.price=r[k].low;ln.bar=r[k].time;ln.confirmed=known;lows++;}
      }
      if(highs>0 && hn.bar!=used_high && r[i].close>hn.price)
      {used_high=hn.bar;bull=hn;bull_time=known;}
      if(lows>0 && ln.bar!=used_low && r[i].close<ln.price)
      {used_low=ln.bar;bear=ln;bear_time=known;}
      last=known;
   }
   void Snapshot(const datetime when,const double ask,HTFResearchSnapshot &s)
   {
      ZeroMemory(s);s.regime="UNKNOWN";s.position="UNKNOWN";s.location="UNKNOWN";
      s.break_direction="NONE";s.raw=EMPTY_VALUE;s.normalized=EMPTY_VALUE;s.break_minutes=EMPTY_VALUE;s.asof=last;
      if(highs>=2 && lows>=2)
      {
         s.regime=(hn.price>ho.price && ln.price>lo.price)?"UP":
                  ((hn.price<ho.price && ln.price<lo.price)?"DOWN":"RANGE");
         s.high=MathMax(ho.price,hn.price);s.low=MathMin(lo.price,ln.price);
         if(s.high>s.low && ask>0)
         {
            s.raw=(ask-s.low)/(s.high-s.low);s.normalized=MathMax(0.0,MathMin(1.0,s.raw));
            s.position=s.normalized<=1.0/3.0?"LOW":(s.normalized<=2.0/3.0?"MID":"HIGH");
            s.location=s.raw<0?"BELOW":(s.raw>1?"ABOVE":"INSIDE");
         }
      }
      if(bull_time>0 || bear_time>0)
      {
         bool up=bull_time>bear_time;HTFResearchPivot p=up?bull:bear;
         s.break_direction=up?"BULLISH":"BEARISH";s.break_time=up?bull_time:bear_time;
         s.break_level=p.price;s.break_bar=p.bar;s.break_confirmed=p.confirmed;
         s.break_minutes=(double)(when-s.break_time)/60.0;
      }
   }
};
#endif
