#ifndef TICK_SHOCK_TWO_STAGE_POLICY_MQH
#define TICK_SHOCK_TWO_STAGE_POLICY_MQH
// Caller provides the generated TS2 model constants and score functions first.
// Score-only rolling state. Current and same-time observations cannot set their own threshold.
#define TS2_HISTORY_CAPACITY 20000
long g_ts2_times[];
double g_ts2_scores[];
bool g_ts2_policy_valid=true;
void TS2Reset(){ArrayResize(g_ts2_times,0);ArrayResize(g_ts2_scores,0);g_ts2_policy_valid=true;}
void TS2Append(const long time,const double score)
  {
   if(!MathIsValidNumber(score))return;
   int n=ArraySize(g_ts2_times);
   if(n>=TS2_HISTORY_CAPACITY){g_ts2_policy_valid=false;return;}
   ArrayResize(g_ts2_times,n+1);ArrayResize(g_ts2_scores,n+1);
   g_ts2_times[n]=time;g_ts2_scores[n]=score;
  }
double TS2RollingThreshold(const long time)
  {
   double values[];int count=0,keep=0;
   for(int i=0;i<ArraySize(g_ts2_times);++i)
     {
      if(g_ts2_times[i]<time-2592000000)continue;
      g_ts2_times[keep]=g_ts2_times[i];g_ts2_scores[keep]=g_ts2_scores[i];++keep;
      if(g_ts2_times[i]>=time)continue;
      ArrayResize(values,count+1);values[count++]=g_ts2_scores[i];
     }
   ArrayResize(g_ts2_times,keep);ArrayResize(g_ts2_scores,keep);
   if(count==0)return DBL_MAX;
   ArraySort(values);double location=(count-1)*TS2_QUANTILE;
   int left=(int)MathFloor(location),right=(int)MathCeil(location);
   return values[left]+(location-left)*(values[right]-values[left]);
  }
int TS2Decision(const double &raw[],const long processing,double &tradeability,double &ls,double &ss,double &threshold)
  {
   tradeability=0;ls=0;ss=0;threshold=DBL_MAX;
   if(ArraySize(raw)!=TS2_FEATURE_COUNT||!g_ts2_policy_valid)return 0;
   tradeability=TS2ScoreTradeability(raw);ls=TS2ScoreLong(raw);ss=TS2ScoreShort(raw);
   threshold=TS2_ROLLING?TS2RollingThreshold(processing):TS2_FIXED_THRESHOLD;
   if(TS2_ROLLING)TS2Append(processing,MathMax(ls,ss));
   if(!g_ts2_policy_valid||!MathIsValidNumber(tradeability)||!MathIsValidNumber(ls)||!MathIsValidNumber(ss))return 0;
   if(TS2_GATE_ENABLED&&tradeability<TS2_GATE)return 0;
   if(ls==ss||MathMax(ls,ss)<threshold)return 0;
   return ls>ss?1:-1;
  }
#endif
