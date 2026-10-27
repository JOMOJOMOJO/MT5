#ifndef WAVE33_LABEL_LAYOUT_MQH
#define WAVE33_LABEL_LAYOUT_MQH

// Rendering only. The immutable logical point is kept separately from the
// text's current screen position. No price history or strategy state is read.
struct W33LabelItem
  {
   string name,caption,tooltip,compact,last_caption,last_tip,leader;
   datetime at,placed_at;
   double price,placed_price;
   color colour,last_colour;
   int anchor,size,last_size,next,x,y,w,h;
   bool placed,bounds,forced_anchor,dirty;
  };
class CWave33LabelLayout
  {
private:
   string m_prefix,m_prior_prefix,m_leader_prefix,m_setup_hashes[],m_setup_ids[];
   bool m_enabled,m_dirty;
   int m_total,m_heads[1021],m_width,m_height,m_visible,m_first,m_scale;
   double m_min,m_max;
   W33LabelItem m_labels[];
   uint Hash(const string value) const
     {
      uint hash=2166136261;
      for(int i=0;i<StringLen(value);i++){hash^=(uint)StringGetCharacter(value,i);hash*=16777619;}
      return hash;
     }
   bool Owned(const string name) const
     {return StringFind(name,m_prefix)==0 || StringFind(name,m_prior_prefix)==0;}
   int Find(const string name) const
     {
      int slot=m_heads[(int)(Hash(name)%1021)];
      while(slot>=0){if(m_labels[slot].name==name)return slot;slot=m_labels[slot].next;}
      return -1;
     }
   bool Has(const string value,const string part) const{return StringFind(value,part)>=0;}
   string ShortID(const string name) const
     {
      // CSV replay/standalone observer fixtures may not have called Setup().
      // The complete setup ID is the first token in each observer tooltip.
      string tip=ObjectGetString(0,name,OBJPROP_TOOLTIP);
      int begin=StringFind(tip,"W33_");
      if(begin>=0)
        {
         int end=begin;while(end<StringLen(tip))
           {ushort c=StringGetCharacter(tip,end);if(c==' ' || c=='\n' || c=='\r' || c=='\t')break;end++;}
         if(end>begin)return StringSubstr(StringFormat("%08X",Hash(StringSubstr(tip,begin,end-begin))),0,4);
        }
      if(StringFind(name,m_prefix)==0)
        {
         string tail=StringSubstr(name,StringLen(m_prefix));
         if(StringFind(tail,"CHOP_")==0)
           {
            string hash=StringSubstr(tail,5);int end=StringFind(hash,"_");if(end>=0)hash=StringSubstr(hash,0,end);
            for(int i=0;i<ArraySize(m_setup_hashes);i++)if(m_setup_hashes[i]==hash)return m_setup_ids[i];
            return StringSubstr(hash,0,4);
           }
         return StringSubstr(tail,0,4);
        }
      if(StringFind(name,m_prior_prefix)==0)
        {
         string hash=StringSubstr(name,StringLen(m_prior_prefix));int end=StringFind(hash,"r");if(end>=0)hash=StringSubstr(hash,0,end);
         for(int i=0;i<ArraySize(m_setup_hashes);i++)if(m_setup_hashes[i]==hash)return m_setup_ids[i];
         return StringSubstr(hash,0,4);
        }
      return StringFormat("%04X",Hash(name)%65536);
     }
   string Revision(const string text) const
     {
      int p=StringFind(text,"r");
      while(p>=0)
        {
         int begin=p+1,end=begin;
         while(end<StringLen(text)){ushort c=StringGetCharacter(text,end);if(c<'0' || c>'9')break;end++;}
         if(end>begin)return "r"+StringSubstr(text,begin,end-begin);
         p=StringFind(text,"r",p+1);
        }
      return "";
     }
   string After(const string text,const string token) const
     {int p=StringFind(text,token);return p>=0?StringSubstr(text,p+StringLen(token)):"";}
   string NumberAfter(const string text,const string token) const
     {
      string tail=After(text,token),value="";
      for(int i=0;i<StringLen(tail);i++)
        {ushort c=StringGetCharacter(tail,i);if((c>='0' && c<='9') || c=='.' || c=='-')value+=StringSubstr(tail,i,1);else if(value!="")break;}
      return value;
     }
   string Compact(const string name,const string text,const double price) const
     {
      string id=" #"+ShortID(name),revision=Revision(text),r=revision!=""?" "+revision:"";
      if(Has(name,"_W1_known"))return Has(text,"旧")?"①旧"+r+id:"①"+r+id;
      if(Has(name,"_extension_tracking"))return "①延長中"+r+id;
      if(Has(name,"_W2") && !Has(name,"_W2_detail"))return Has(text,"旧")?"②旧"+r+id:"②"+r+id;
      if(Has(name,"CHOP_"))
        {
         if(Has(text,"判定不可"))return "往復 ?"+r+id;
         string ratio=NumberAfter(text,Has(text,"多い")?"多い":"少ない");
         return "往復 "+ratio+r+id;
        }
      if(Has(name,"_entry_text"))return (Has(text,"買")?"買 ENTRY":"売 ENTRY")+(Has(text,"約定")?" 約定":"")+id;
      if(Has(name,"_skip_"))
        {
         if(Has(text,"両側") || Has(text,"CONNECTED_OPPOSITE_W1_BOTH"))return "見送り 両側①"+id;
         if(Has(text,"接続") || Has(text,"逆①"))return "見送り 接続①"+id;
         if(Has(text,"往復"))return "見送り 往復"+id;
         if(Has(text,"高安帯"))return "見送り 高安帯"+id;
         if(Has(text,"初動"))return "見送り 初動後"+id;
         if(Has(text,"終値の押し"))return "見送り 深い押し "+NumberAfter(text,"終値の押し")+"%"+id;
         if(Has(text,"起点"))return "見送り 起点割れ"+id;
         if(Has(text,"余地"))return "見送り 余地不足"+id;
         if(Has(text,"時間切れ"))return "見送り 時間切れ"+id;
         if(Has(text,"別の波"))return "見送り 別候補"+id;
         if(Has(text,"検証終了"))return "見送り 終了"+id;
         return "見送り 条件未成立"+id;
        }
      if(Has(name,"_SL_label"))return (Has(text,"建値")?"SL 建値":"SL")+id;
      if(Has(name,"_TP_label"))return (Has(text,"分割不可")?"TP 全量":(Has(text,"①手前")?"TP ①手前":"TP"))+id;
      if(Has(name,"_opposite_wait"))return "逆① 利益決済待ち"+id;
      if(Has(name,"_opposite_exit_text"))return "EXIT 逆①"+id;
      if(Has(name,"_wave1_room_source_label"))return text+" @"+DoubleToString(price,_Digits)+id;
      if(Has(name,"_wave1_room_label"))return "①まで "+NumberAfter(text,"まで")+"R"+id;
      if(Has(name,"_obstacle_source_label"))
        {int space=StringFind(text," ");return "元 "+(space>=0?StringSubstr(text,space+1):text)+" @"+DoubleToString(price,_Digits)+id;}
      if(Has(name,"_obstacle_label"))return (Has(text,"抵抗")?"抵抗 ":(Has(text,"支持")?"支持 ":"参考 "))+
         (Has(text,"H1")?"H1":(Has(text,"M15")?"M15":"M5"))+id;
      if(StringFind(name,m_prior_prefix)==0)
        {
         string frame=Has(text,"H1")?"H1":"M15";
         if(Has(text,"事後参照"))return "元 "+After(text,"事後参照 ")+id;
         return frame+"高安帯 "+(Has(text,"未突破")?"未突破":(Has(text,"判定資料不足")?"?":"確認"))+id;
        }
      // Unknown diagnostic labels remain present; only long captions compact.
      if(StringLen(text)>22)return StringSubstr(text,0,21)+"…"+id;
      return text;
     }
   int Register(const string name)
     {
      if(!Owned(name) || ObjectFind(0,name)<0 || (ENUM_OBJECT)ObjectGetInteger(0,name,OBJPROP_TYPE)!=OBJ_TEXT)return -1;
      int found=Find(name);if(found>=0)return found;
      int n=ArraySize(m_labels),bucket=(int)(Hash(name)%1021);ArrayResize(m_labels,n+1,256);ZeroMemory(m_labels[n]);
      m_labels[n].name=name;m_labels[n].next=m_heads[bucket];m_heads[bucket]=n;
      m_labels[n].at=(datetime)ObjectGetInteger(0,name,OBJPROP_TIME,0);m_labels[n].price=ObjectGetDouble(0,name,OBJPROP_PRICE,0);
      m_labels[n].caption=ObjectGetString(0,name,OBJPROP_TEXT);m_labels[n].tooltip=ObjectGetString(0,name,OBJPROP_TOOLTIP);
      m_labels[n].anchor=(int)ObjectGetInteger(0,name,OBJPROP_ANCHOR);m_labels[n].size=(int)ObjectGetInteger(0,name,OBJPROP_FONTSIZE);
      m_labels[n].colour=(color)ObjectGetInteger(0,name,OBJPROP_COLOR);m_labels[n].leader=m_leader_prefix+StringFormat("%08X",Hash(name));
      m_labels[n].dirty=true;
      return n;
     }
   void ReferenceAnchor(const int i)
     {
      string name=m_labels[i].name,mate="";
      if(Has(name,"_label") && !Has(name,"_source_label") && StringSubstr(name,StringLen(name)-6)=="_label")mate=StringSubstr(name,0,StringLen(name)-6);
      else if(Has(name,"_opposite_wait"))mate=StringSubstr(name,0,StringLen(name)-14)+"_opposite_known";
      else if(StringFind(name,m_prior_prefix)==0 && StringSubstr(name,StringLen(name)-1)=="t")mate=StringSubstr(name,0,StringLen(name)-1)+"l";
      if(mate!="" && ObjectFind(0,mate)>=0)
        {
         double exact=ObjectGetDouble(0,mate,OBJPROP_PRICE,0);
         if(exact>0){m_labels[i].price=exact;m_labels[i].forced_anchor=true;}
        }
     }
   void Refresh(const int i)
     {
      string name=m_labels[i].name;
      datetime at=(datetime)ObjectGetInteger(0,name,OBJPROP_TIME,0);double price=ObjectGetDouble(0,name,OBJPROP_PRICE,0);
      string text=ObjectGetString(0,name,OBJPROP_TEXT),tip=ObjectGetString(0,name,OBJPROP_TOOLTIP);
      int anchor=(int)ObjectGetInteger(0,name,OBJPROP_ANCHOR);
      bool updated=!m_labels[i].placed || at!=m_labels[i].placed_at || price!=m_labels[i].placed_price || anchor!=ANCHOR_LEFT_UPPER;
      if(updated && !m_labels[i].forced_anchor){m_labels[i].at=at;m_labels[i].price=price;}
      if(text!=m_labels[i].last_caption)m_labels[i].caption=text;
      if(tip!=m_labels[i].last_tip)m_labels[i].tooltip=tip;
      int size=(int)ObjectGetInteger(0,name,OBJPROP_FONTSIZE);
      if(updated)
        {
         if(!m_labels[i].placed || anchor!=ANCHOR_LEFT_UPPER)m_labels[i].anchor=anchor;
         if(!m_labels[i].placed || size!=m_labels[i].last_size)m_labels[i].size=size;
        }
      color colour=(color)ObjectGetInteger(0,name,OBJPROP_COLOR);
      if(!m_labels[i].placed || colour!=m_labels[i].last_colour)m_labels[i].colour=colour;
      if(updated)ReferenceAnchor(i);
      m_labels[i].compact=Compact(name,m_labels[i].caption,m_labels[i].price);
     }
   void Restore(const int i)
     {
      if(ObjectFind(0,m_labels[i].name)<0)return;
      ObjectMove(0,m_labels[i].name,0,m_labels[i].at,m_labels[i].price);
      ObjectSetString(0,m_labels[i].name,OBJPROP_TEXT,m_labels[i].caption);ObjectSetString(0,m_labels[i].name,OBJPROP_TOOLTIP,m_labels[i].tooltip);
      ObjectSetInteger(0,m_labels[i].name,OBJPROP_ANCHOR,m_labels[i].anchor);ObjectSetInteger(0,m_labels[i].name,OBJPROP_FONTSIZE,m_labels[i].size);
      ObjectSetInteger(0,m_labels[i].name,OBJPROP_COLOR,m_labels[i].colour);
      ObjectDelete(0,m_labels[i].leader);m_labels[i].placed=false;m_labels[i].bounds=false;
     }
   int EstimatedWidth(const string text,const int size) const
     {
      // Conservative native-font estimate: CJK/fullwidth glyphs are one em,
      // Latin halfwidth glyphs 0.62 em. A 6 px guard covers glyph overhang.
      double units=0;
      for(int i=0;i<StringLen(text);i++)units+=(StringGetCharacter(text,i)>255?1.0:0.62);
      return (int)MathCeil(units*size*1.34)+6;
     }
   bool FreeBox(const int x,const int y,const int w,const int h,const int cols,const int rows,const int &grid[]) const
     {
      int left=x/8,top=y/8,right=(x+w+7)/8,bottom=(y+h+7)/8;
      if(left<0 || top<0 || right>=cols || bottom>=rows)return false;
      for(int yy=top;yy<=bottom;yy++)for(int xx=left;xx<=right;xx++)if(grid[yy*cols+xx]!=0)return false;
      return true;
     }
   void Occupy(const int x,const int y,const int w,const int h,const int cols,const int rows,int &grid[])
     {
      int left=(int)MathMax(0,x/8),top=(int)MathMax(0,y/8),right=(int)MathMin(cols-1,(x+w+7)/8),bottom=(int)MathMin(rows-1,(y+h+7)/8);
      for(int yy=top;yy<=bottom;yy++)for(int xx=left;xx<=right;xx++)grid[yy*cols+xx]=1;
     }
   void Leader(const int i,const datetime end,const double price)
     {
      string name=m_labels[i].leader;
      if(ObjectFind(0,name)<0)ObjectCreate(0,name,OBJ_TREND,0,m_labels[i].at,m_labels[i].price,end,price);
      else{ObjectMove(0,name,0,m_labels[i].at,m_labels[i].price);ObjectMove(0,name,1,end,price);}
      ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,name,OBJPROP_COLOR,m_labels[i].colour);ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,1);ObjectSetInteger(0,name,OBJPROP_BACK,true);ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetString(0,name,OBJPROP_TOOLTIP,"Visual caption leader only; actual anchor "+TimeToString(m_labels[i].at,TIME_DATE|TIME_SECONDS)+" @"+DoubleToString(m_labels[i].price,_Digits));
     }
public:
   void Init(const string prefix)
     {
      m_prefix=prefix;m_prior_prefix="W33PC_"+IntegerToString((long)Hash(prefix))+"_";
      m_leader_prefix="W33LL_"+IntegerToString((long)Hash(prefix))+"_";m_enabled=false;m_dirty=true;m_total=-1;
      m_width=0;m_height=0;m_visible=0;m_first=0;m_scale=0;m_min=0;m_max=0;
      ArrayResize(m_labels,0);ArrayInitialize(m_heads,-1);
      ArrayResize(m_setup_hashes,0);ArrayResize(m_setup_ids,0);
     }
   void Configure(const bool enabled)
     {
      if(m_enabled && !enabled)for(int i=0;i<ArraySize(m_labels);i++)Restore(i);
      m_enabled=enabled;m_dirty=true;
     }
   void Dirty(){m_dirty=true;}
   void Touch(const string name)
     {if(!m_enabled)return;int i=Find(name);if(i<0)i=Register(name);if(i>=0)m_labels[i].dirty=true;m_dirty=true;}
   void Setup(const string id,const string short_id)
     {
      string hash=IntegerToString((long)Hash(id));
      for(int i=0;i<ArraySize(m_setup_hashes);i++)if(m_setup_hashes[i]==hash)return;
      int n=ArraySize(m_setup_hashes);ArrayResize(m_setup_hashes,n+1,64);ArrayResize(m_setup_ids,n+1,64);m_setup_hashes[n]=hash;m_setup_ids[n]=short_id;
     }
   void SetAnchor(const string name,const datetime at,const double price)
     {
      if(!m_enabled || at<=0 || price<=0)return;int i=Register(name);if(i<0)return;
      m_labels[i].at=at;m_labels[i].price=price;m_labels[i].forced_anchor=true;m_labels[i].dirty=true;m_dirty=true;
     }
   void Layout(const bool force=false)
     {
      if(!m_enabled || m_prefix=="")return;
      int width=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS),height=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
      int visible=(int)ChartGetInteger(0,CHART_VISIBLE_BARS),first=(int)ChartGetInteger(0,CHART_FIRST_VISIBLE_BAR),scale=(int)ChartGetInteger(0,CHART_SCALE);
      double low=ChartGetDouble(0,CHART_PRICE_MIN,0),high=ChartGetDouble(0,CHART_PRICE_MAX,0);
      int total=ObjectsTotal(0);bool resized=width!=m_width || height!=m_height || visible!=m_visible || first!=m_first || scale!=m_scale || low!=m_min || high!=m_max;
      if(!force && !m_dirty && !resized && total==m_total)return;
      if(width<100 || height<80 || high<=low)return;
      m_width=width;m_height=height;m_visible=visible;m_first=first;m_scale=scale;m_min=low;m_max=high;
      // CHART_WIDTH_IN_PIXELS includes the right-hand price scale. Reserve
      // explicit drawing space so a label cannot disappear behind that scale.
      int right_margin=(int)MathMax(64,EstimatedWidth(DoubleToString(high,_Digits),9)+16);
      int plot_width=(int)MathMax(80,width-right_margin),top_margin=24;
      // Discovery is linear only when the object inventory changes. Known
      // labels are hash-indexed, not repeatedly searched in a growing list.
      if(total!=m_total || force)
         for(int j=0;j<total;j++){string name=ObjectName(0,j);if(Owned(name))Register(name);}
      datetime leftTime=0,rightTime=0;double unused=0;int sub=0;
      bool leftOK=ChartXYToTimePrice(0,0,height/2,sub,leftTime,unused),rightOK=ChartXYToTimePrice(0,width-1,height/2,sub,rightTime,unused);
      int cols=plot_width/8+2,rows=height/8+2,grid[];ArrayResize(grid,cols*rows);ArrayInitialize(grid,0);
      for(int i=0;i<ArraySize(m_labels);i++)
        {
         datetime at=m_labels[i].at;double price=m_labels[i].price;
         bool cached_offscreen=price<low || price>high || (leftOK && rightOK && (at<leftTime || at>rightTime));
         // Historical labels are immutable except when the adapter explicitly
         // touches an existing wave/risk caption. Do not issue thousands of
         // object-property reads for old captions outside the visible window.
         if(cached_offscreen && !m_labels[i].dirty && !force)
           {
            m_labels[i].bounds=false;
            if(m_labels[i].placed)Restore(i);
            continue;
           }
         if(ObjectFind(0,m_labels[i].name)<0){m_labels[i].bounds=false;continue;}
         Refresh(i);m_labels[i].bounds=false;m_labels[i].dirty=false;
         at=m_labels[i].at;price=m_labels[i].price;
         bool offscreen=price<low || price>high || (leftOK && rightOK && (at<leftTime || at>rightTime));
         if(offscreen)
           {
            if(m_labels[i].placed)Restore(i);
            continue;
           }
         int px=0,py=0;if(!ChartTimePriceToXY(0,0,at,price,px,py))continue;
         if(px<0 || px>=width || py<0 || py>=height)continue;
         string compact=m_labels[i].compact;
         int font=Has(m_labels[i].caption,"旧")?7:8,w=(int)MathMin(plot_width-16,EstimatedWidth(compact,font)),h=font*2+2;
         int baseX=px+8,baseY=py-h-6;
         // Place above/below the immutable point, then nearby columns. A pixel
         // occupancy grid makes the visible-label pass independent of history.
         int bx=(int)MathMax(8,MathMin(plot_width-w-8,baseX)),by=(int)MathMax(top_margin,MathMin(height-h-8,baseY));bool found=false;
         for(int lane=0;lane<9 && !found;lane++)
           {
            int horizontal=lane==0?0:((lane%2==1?1:-1)*((lane+1)/2)*(w+16));
            int x=(int)MathMax(8,MathMin(plot_width-w-8,baseX+horizontal));
            for(int step=0;step<2*(height/(h+10)+1) && !found;step++)
              {
               int offset=step==0?0:((step%2==1?1:-1)*((step+1)/2)*(h+10));
               int y=baseY+offset;if(y<top_margin || y+h>height-8)continue;
               if(FreeBox(x,y,w,h,cols,rows,grid)){bx=x;by=y;found=true;}
              }
           }
         // Never drop a skip or a losing trade when an exceptionally dense
         // viewport exhausts physical space. The full caption remains in tips.
         Occupy(bx,by,w,h,cols,rows,grid);
         datetime placed=0;double plotted=0;sub=0;
         if(!ChartXYToTimePrice(0,bx,by,sub,placed,plotted) || sub!=0)continue;
         string tip=m_labels[i].caption+"\n"+m_labels[i].tooltip+"\nVisual anchor "+TimeToString(at,TIME_DATE|TIME_SECONDS)+" @"+DoubleToString(price,_Digits);
         ObjectMove(0,m_labels[i].name,0,placed,plotted);ObjectSetString(0,m_labels[i].name,OBJPROP_TEXT,compact);
         ObjectSetString(0,m_labels[i].name,OBJPROP_TOOLTIP,tip);ObjectSetInteger(0,m_labels[i].name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
         ObjectSetInteger(0,m_labels[i].name,OBJPROP_FONTSIZE,font);
         color rendered_colour=Has(m_labels[i].caption,"旧")?clrSlateGray:m_labels[i].colour;
         ObjectSetInteger(0,m_labels[i].name,OBJPROP_COLOR,rendered_colour);
         m_labels[i].placed=true;m_labels[i].placed_at=placed;m_labels[i].placed_price=plotted;m_labels[i].last_caption=compact;m_labels[i].last_tip=tip;
         m_labels[i].last_size=font;m_labels[i].last_colour=rendered_colour;
         m_labels[i].x=bx;m_labels[i].y=by;m_labels[i].w=w;m_labels[i].h=h;m_labels[i].bounds=true;
         Leader(i,placed,plotted);
        }
      m_total=ObjectsTotal(0);m_dirty=false;ChartRedraw();
     }
   bool Anchor(const string name,datetime &at,double &price) const
     {int i=Find(name);if(i<0)return false;at=m_labels[i].at;price=m_labels[i].price;return true;}
   bool Bounds(const string name,int &x,int &y,int &w,int &h) const
     {int i=Find(name);if(i<0 || !m_labels[i].bounds)return false;x=m_labels[i].x;y=m_labels[i].y;w=m_labels[i].w;h=m_labels[i].h;return true;}
   bool Managed(const string name) const{return Find(name)>=0;}
   int Count() const{return ArraySize(m_labels);}
   void Clear(){if(m_leader_prefix!="")ObjectsDeleteAll(0,m_leader_prefix);ArrayResize(m_labels,0);ArrayResize(m_setup_hashes,0);ArrayResize(m_setup_ids,0);ArrayInitialize(m_heads,-1);m_total=-1;m_dirty=true;}
  };
#endif
