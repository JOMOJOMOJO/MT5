#ifndef THREE_WAVE_DRAWING
#define THREE_WAVE_DRAWING
void DeleteOurObjects()
{
   for(int i=ObjectsTotal(0)-1;i>=0;i--)
   {
      string name=ObjectName(0,i);
      if(StringFind(name,g_prefix)==0) ObjectDelete(0,name);
   }
}

string ObjName(const string kind,const datetime t,const int serial=0)
{
   return g_prefix+kind+"_"+IntegerToString((long)t)+"_"+IntegerToString(serial);
}

void TextAt(const string name,const datetime t,const double price,const string text,const color c,const int anchor=ANCHOR_LEFT_LOWER,const int font=8)
{
   if(!ObjectCreate(0,name,OBJ_TEXT,0,t,price)) return;
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,c);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,font);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,anchor);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
}

void ArrowAt(const string name,const datetime t,const double price,const color c,const int code,const int width=2)
{
   if(!ObjectCreate(0,name,OBJ_ARROW,0,t,price)) return;
   ObjectSetInteger(0,name,OBJPROP_ARROWCODE,code);
   ObjectSetInteger(0,name,OBJPROP_COLOR,c);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
}

void Segment(const string name,const datetime t1,const double p1,const datetime t2,const double p2,const color c,const ENUM_LINE_STYLE style=STYLE_SOLID,const int width=1)
{
   if(!ObjectCreate(0,name,OBJ_TREND,0,t1,p1,t2,p2)) return;
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
   ObjectSetInteger(0,name,OBJPROP_COLOR,c);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
}

void HLineSegment(const string name,const datetime t1,const datetime t2,const double p,const color c,const ENUM_LINE_STYLE style=STYLE_DOT)
{
   Segment(name,t1,p,t2,p,c,style,1);
}

void FibZone(const string base,const datetime t1,const datetime t2,const double low,const double high)
{
   if(!InpShowFibZone || high<=low) return;
   double zHigh=high-(high-low)*InpFibZoneLow;
   double zLow =high-(high-low)*InpFibZoneHigh;
   string box=base+"_FIBBOX";
   if(ObjectCreate(0,box,OBJ_RECTANGLE,0,t1,zHigh,t2,zLow))
   {
      ObjectSetInteger(0,box,OBJPROP_COLOR,clrDarkSlateGray);
      ObjectSetInteger(0,box,OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(0,box,OBJPROP_FILL,false);
      ObjectSetInteger(0,box,OBJPROP_BACK,true);
      ObjectSetInteger(0,box,OBJPROP_SELECTABLE,false);
   }
   double f50=(low+high)*0.5;
   HLineSegment(base+"_FIB50",t1,t2,f50,clrSilver,STYLE_DOT);
}

void DrawHigherPivots(const PivotPoint &pivots[])
{
   if(!InpShowHigherPivots) return;
   int start=MathMax(0,ArraySize(pivots)-80);
   PivotPoint prev={};
   bool havePrev=false;
   for(int i=start;i<ArraySize(pivots);i++)
   {
      PivotPoint p=pivots[i];
      string tag=(p.high ? "M5 H" : "M5 L");
      color c=(p.high ? clrTomato : clrDodgerBlue);
      datetime pt=PivotPlotTime(p);
      TextAt(ObjName("M5P",p.bar_time,i),pt,p.price,tag,c,p.high?ANCHOR_LEFT_LOWER:ANCHOR_LEFT_UPPER,7);
      if(InpShowStructureLines && havePrev && prev.high!=p.high)
         Segment(ObjName("M5ZZ",p.bar_time,i),PivotPlotTime(prev),prev.price,pt,p.price,clrSlateGray,STYLE_DOT,1);
      prev=p; havePrev=true;
   }
}

void DrawLowerPivots(const PivotPoint &pivots[])
{
   if(!InpDiagnosticMode) return;
   int start=MathMax(0,ArraySize(pivots)-120);
   for(int i=start;i<ArraySize(pivots);i++)
   {
      PivotPoint p=pivots[i];
      string tag=(p.high ? "M1 H" : "M1 L");
      color c=(p.high ? clrLightCoral : clrDeepSkyBlue);
      TextAt(ObjName("M1P",p.bar_time,i),p.bar_time,p.price,tag,c,
             p.high ? ANCHOR_LEFT_LOWER : ANCHOR_LEFT_UPPER,6);
   }
}

void DrawSetup(const M5Setup &s,const M1Pattern &p,const int serial)
{
   string base=g_prefix+"S"+IntegerToString(serial)+"_"+IntegerToString((long)s.break_time);

   datetime m5BreakPlot=CloseSignalPlotTime(s.break_time,InpHigherTF);
   datetime brokenPlot=PivotPlotTime(s.broken_high);
   datetime originPlot=PivotPlotTime(s.origin_low);
   datetime wave1Plot=PivotPlotTime(s.wave1_high);

   ArrowAt(base+"_M5BREAK",m5BreakPlot,s.break_price,clrLimeGreen,233,2);
   TextAt(base+"_M5BREAK_TXT",m5BreakPlot,s.break_price,"M5 CHoCH / Wave1 start",clrLimeGreen,ANCHOR_LEFT_LOWER,8);
   HLineSegment(base+"_BROKEN",brokenPlot,s.wave1_high.confirmed_time,s.broken_high.price,clrDarkOrange,STYLE_DASH);
   TextAt(base+"_BROKEN_TXT",brokenPlot,s.broken_high.price,"M5 return high",clrDarkOrange,ANCHOR_LEFT_LOWER,7);

   ArrowAt(base+"_M5W1H",wave1Plot,s.wave1_high.price,clrGold,234,2);
   TextAt(base+"_M5W1H_TXT",wave1Plot,s.wave1_high.price,"M5 Wave1 high -> Wave2",clrGold,ANCHOR_LEFT_LOWER,8);

   if(InpShowStructureLines)
      Segment(base+"_M5W1",originPlot,s.origin_low.price,wave1Plot,s.wave1_high.price,clrMediumSeaGreen,STYLE_SOLID,2);

   if(!p.found_choch) return;

   datetime m1ChochPlot=CloseSignalPlotTime(p.choch_time,InpLowerTF);
   ArrowAt(base+"_M1CHOCH",m1ChochPlot,p.choch_price,clrAqua,233,2);
   TextAt(base+"_M1CHOCH_TXT",m1ChochPlot,p.choch_price,"M1 CHoCH",clrAqua,ANCHOR_LEFT_LOWER,8);
   HLineSegment(base+"_M1RET",p.downtrend_return_high.bar_time,m1ChochPlot,p.downtrend_return_high.price,clrAqua,STYLE_DOT);

   if(InpShowRelevantM1Pivots)
   {
      TextAt(base+"_M1RL",p.reversal_low.bar_time,p.reversal_low.price,"M1 reversal low",clrDeepSkyBlue,ANCHOR_LEFT_UPPER,7);
      TextAt(base+"_M1RH",p.downtrend_return_high.bar_time,p.downtrend_return_high.price,"M1 return high",clrDeepSkyBlue,ANCHOR_LEFT_LOWER,7);
   }

   if(!p.found_wave1_high) return;
   ArrowAt(base+"_M1W1H",p.wave1_high.bar_time,p.wave1_high.price,clrYellow,234,1);
   TextAt(base+"_M1W1H_TXT",p.wave1_high.bar_time,p.wave1_high.price,"M1 Wave1 high",clrYellow,ANCHOR_LEFT_LOWER,7);

   datetime fibEnd=p.found_hl ? p.hl.confirmed_time+15*60 : p.wave1_high.confirmed_time+15*60;
   if(p.ready) fibEnd=p.ready_time;
   FibZone(base,p.wave1_high.bar_time,fibEnd,p.reversal_low.price,p.wave1_high.price);

   if(InpShowStructureLines)
      Segment(base+"_M1W1",p.reversal_low.bar_time,p.reversal_low.price,p.wave1_high.bar_time,p.wave1_high.price,clrAqua,STYLE_SOLID,2);

   if(!p.found_hl) return;

   color hlc=(p.fib_ok ? clrLime : clrOrangeRed);
   ArrowAt(base+"_HL",p.hl.bar_time,p.hl.price,hlc,233,1);
   TextAt(base+"_HL_TXT",p.hl.bar_time,p.hl.price,
          "M1 HL  retrace="+DoubleToString(p.retrace*100.0,1)+"%"+(p.fib_ok?" [Fib OK]":" [outside Fib]"),
          hlc,ANCHOR_LEFT_UPPER,7);
   if(InpShowStructureLines)
      Segment(base+"_M1W2",p.wave1_high.bar_time,p.wave1_high.price,p.hl.bar_time,p.hl.price,clrOrange,STYLE_SOLID,2);

   if(p.pullback_lh.bar_time>0)
   {
      HLineSegment(base+"_PBLH",p.pullback_lh.bar_time,p.ready ? p.ready_time : p.hl.confirmed_time+20*60,
                   p.pullback_lh.price,clrViolet,STYLE_DOT);
      TextAt(base+"_PBLH_TXT",p.pullback_lh.bar_time,p.pullback_lh.price,"M1 Wave2 return high",clrViolet,ANCHOR_LEFT_LOWER,7);
   }

   if(!p.ready) return;
   datetime readyPlot=CloseSignalPlotTime(p.ready_time,InpLowerTF);
   ArrowAt(base+"_READY",readyPlot,p.ready_price,clrLime,241,3);
   TextAt(base+"_READY_TXT",readyPlot,p.ready_price,
          p.early_break ? "3x3 LONG READY (Wave2 return-high break)" : "3x3 LONG READY (Wave1-high break)",
          clrLime,ANCHOR_LEFT_LOWER,9);
   if(InpShowStructureLines)
      Segment(base+"_M1W3START",p.hl.bar_time,p.hl.price,readyPlot,p.ready_price,clrLime,STYLE_SOLID,2);
}


#endif
