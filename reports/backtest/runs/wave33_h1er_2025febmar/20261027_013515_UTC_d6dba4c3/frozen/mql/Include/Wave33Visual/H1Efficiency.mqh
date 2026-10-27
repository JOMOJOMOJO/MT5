#ifndef W33_H1_EFFICIENCY
#define W33_H1_EFFICIENCY

// One preregistered comparison: 12 observed H1 close-to-close changes.
// The complement 1 - ER measures path inefficiency, NOT a literal number of
// round trips, a high/low zigzag count, or a prediction of the next direction.
#define W33_H1_EFFICIENCY_WINDOW 12
#define W33_H1_EFFICIENCY_CLOSES 13
#define W33_H1_EFFICIENCY_THRESHOLD 0.25
#define W33_H1_EFFICIENCY_EDGE_EPS 1.0e-12

struct W33H1EfficiencyResult
  {
   bool valid;
   string reason;
   int count;
   double net_distance;
   double path_distance;
   double er;
   double roundtrip;
   datetime first_time;
   datetime last_time;
   int gap_count;
   long span_seconds;
  };

// Input times are H1 BAR OPEN times, ordered oldest to newest. Every close
// must already have been observable at decision_at. Gaps, including weekend
// gaps, remain part of the observed-bar convention and are reported only.
// No market-data reads, trade operations, drawing, or state mutations occur.
W33H1EfficiencyResult W33H1Efficiency(const datetime &times[],
                                     const double &closes[],
                                     const datetime decision_at)
  {
   W33H1EfficiencyResult r;
   ZeroMemory(r);
   r.count=ArraySize(closes);
   r.reason="ARRAY_LENGTH";
   if(ArraySize(times)!=W33_H1_EFFICIENCY_CLOSES ||
      r.count!=W33_H1_EFFICIENCY_CLOSES)
      return r;
   r.reason="INVALID_DECISION_TIME";
   if(decision_at<3600)
      return r;

   for(int i=0;i<W33_H1_EFFICIENCY_CLOSES;i++)
     {
      r.reason="INVALID_TIME";
      if(times[i]<=0)
         return r;
      r.reason="OFF_HOUR_TIME";
      if(((long)times[i])%3600!=0)
         return r;
      r.reason="UNORDERED_TIME";
      if(i>0 && times[i]<=times[i-1])
         return r;
      r.reason="FUTURE_OR_FORMING_BAR";
      // Subtract from decision_at to avoid overflowing a malformed time+3600.
      if(times[i]>decision_at-3600)
         return r;
      r.reason="INVALID_CLOSE";
      if(!MathIsValidNumber(closes[i]) || closes[i]<=0.0)
         return r;
      if(i>0)
        {
         if(times[i]-times[i-1]>3600)
            r.gap_count++;
         r.path_distance+=MathAbs(closes[i]-closes[i-1]);
        }
     }

   r.first_time=times[0];
   r.last_time=times[W33_H1_EFFICIENCY_CLOSES-1];
   r.span_seconds=(long)(r.last_time-r.first_time);
   r.net_distance=MathAbs(closes[W33_H1_EFFICIENCY_CLOSES-1]-closes[0]);
   r.reason="DISTANCE_OVERFLOW";
   if(!MathIsValidNumber(r.path_distance) || !MathIsValidNumber(r.net_distance))
      return r;
   r.reason="ZERO_PATH";
   if(r.path_distance==0.0)
      return r;

   // The triangle inequality bounds ER to [0,1]; clamp floating-point noise.
   r.er=MathMax(0.0,MathMin(1.0,r.net_distance/r.path_distance));
   r.roundtrip=1.0-r.er;
   r.valid=true;
   r.reason="OK";
   return r;
  }

bool W33H1EfficiencyShouldSkip(const bool enabled,
                             const W33H1EfficiencyResult &r)
  {
   // Missing/flat/invalid observations are not silently promoted into a new
   // entry veto. The edge epsilon repairs arithmetic noise at exactly 0.25.
   return enabled && r.valid && MathIsValidNumber(r.er) &&
          r.er>=0.0 && r.er<=W33_H1_EFFICIENCY_THRESHOLD+W33_H1_EFFICIENCY_EDGE_EPS;
  }

#endif
