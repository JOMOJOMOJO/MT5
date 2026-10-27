"""Draw entry-only, outcome-free W1/pre-zigzag packets, never future candles."""
from __future__ import annotations
import argparse
from bisect import bisect_right,bisect_left
from datetime import datetime
import hashlib
import json
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection, PolyCollection
from matplotlib.font_manager import FontProperties
from PIL import Image, ImageOps, ImageDraw


def dt(value):
    return datetime.fromisoformat(value[:10].replace('.','-')+value[10:])


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def render(case,out):
    s=case['snapshot'];direction=1 if case['direction']=='LONG' else -1
    # Fixed layout rule, not chosen from outcomes: retain all pre8 + W1, with
    # eight lead-in bars, at least90 and at most the300 causal packet bars.
    upper=case['upper_bars'];utimes=[dt(b['time']) for b in upper]
    first=min([dt(s['wave1_start_time'])]+[dt(p['time']) for p in case['pre_pivots']])
    left=max(0,min(bisect_left(utimes,first)-8,len(upper)-90))
    shown_upper=upper[left:]
    fig,axes=plt.subplots(2,1,figsize=(15,9),gridspec_kw={'height_ratios':[1.15,1]},layout='constrained')
    fig.set_facecolor('#f7f9fc')
    fig.suptitle(f"{case['blind_id']}  |  {case['arm']}  {case['upper_tf'].replace('PERIOD_','')} × {case['lower_tf'].replace('PERIOD_','')}  |  {case['direction']}",fontsize=19,weight='bold')
    warnings=[]
    for row,(ax,bars,pivots,kind) in enumerate(zip(axes,[shown_upper,case['lower_bars'][-180:]],[case['upper_pivots'],case['lower_pivots']],['上位足：①と直前のジグザグ','下位足：②の内部とエントリー直前'])):
        n=len(bars);times=[dt(b['time']) for b in bars]
        def xat(value):
            t=dt(value) if isinstance(value,str) else value
            if t<times[0]:return -1-(times[0]-t).total_seconds()/max(60,(times[1]-times[0]).total_seconds())
            j=bisect_right(times,t)-1
            if j>=n-1:
                if t>=dt(bars[-1]['closed_at']):return n
                return n-1
            seconds=(times[j+1]-times[j]).total_seconds()
            return j+min(1,max(0,(t-times[j]).total_seconds()/seconds))
        colors=['#21876a' if float(b['close'])>=float(b['open']) else '#be5b57' for b in bars]
        ax.add_collection(LineCollection([[(i,float(b['low'])),(i,float(b['high']))] for i,b in enumerate(bars)],colors=colors,linewidths=.7))
        bodies=[]
        for i,b in enumerate(bars):
            lo,hi=sorted([float(b['open']),float(b['close'])]);hi=max(hi,lo+.001)
            bodies.append([(i-.3,lo),(i+.3,lo),(i+.3,hi),(i-.3,hi)])
        ax.add_collection(PolyCollection(bodies,facecolors=colors,edgecolors=colors,linewidths=.3,alpha=.8))
        last=None
        for p in pivots:
            if p['ambiguous_same_time']:
                last=None;continue
            x=xat(p['time'])
            if x<0:continue
            if last and p['is_high']!=last['is_high'] and dt(p['time'])>dt(last['time']):
                ax.plot([xat(last['time']),x],[float(last['price']),float(p['price'])],color='#b6a9ca',lw=.65,ls=(0,(3,3)),alpha=.6)
            last=p
        extrema=[float(b['low']) for b in bars]+[float(b['high']) for b in bars]
        entry=float(s['entry_price']);extrema.append(entry)
        if row==0:
            pre=case['pre_pivots'];last=None
            for i,p in enumerate(pre):
                x=xat(p['time'])
                if p['ambiguous_same_time']:
                    last=None;continue
                if x>=0:
                    if last and p['is_high']!=last['is_high'] and dt(p['time'])>dt(last['time']):
                        ax.plot([xat(last['time']),x],[float(last['price']),float(p['price'])],color='#4b5665',lw=1.9,ls=(0,(4,3)))
                    ax.scatter([x],[float(p['price'])],color='#4b5665',s=15,zorder=4)
                    ax.annotate(f'P{i+1}',(x,float(p['price'])),xytext=(1,9 if p['is_high'] else -13),textcoords='offset points',fontsize=7.5,color='#3e4958')
                    extrema.append(float(p['price']))
                last=p
            if len(pre)==8 and not any(p['ambiguous_same_time'] for p in pre):
                box_lo=min(float(p['price']) for p in pre);box_hi=max(float(p['price']) for p in pre)
                begin=max(0,xat(case['pre_cutoff_at']))
                ax.fill_between([begin,n],box_lo,box_hi,color='#6d7987',alpha=.055)
                for price in [box_lo,box_hi]:ax.plot([begin,n],[price,price],color='#748091',lw=.9,ls=(0,(6,4)))
            anchor_keys=['wave1_start_time','wave1_peak_time','wave2_extreme_time']
            prices=[float(s[k]) for k in ['wave1_start_price','wave1_peak_price','wave2_extreme_price']]
            xx=[xat(s[k]) for k in anchor_keys]
            ax.plot(xx[:2],prices[:2],color='#0073b4',lw=2.9,zorder=6)
            ax.plot(xx[1:],prices[1:],color='#db8a17',lw=2.5,zorder=6)
            for j,(x,p) in enumerate(zip(xx,prices)):
                if 0<=x<=n:
                    ax.scatter([x],[p],s=28,color='#0073b4' if j<2 else '#db8a17',zorder=7)
                    if j>0:ax.annotate('①' if j==1 else '②',(x,p),xytext=(4,10 if (direction>0)==(j==1) else -18),textcoords='offset points',fontsize=13,weight='bold',color='#0073b4' if j==1 else '#db8a17')
                    extrema.append(p)
            if xx[0]<0:warnings.append('上位足の①起点が表示範囲外')
            for key,label,c in [('candidate_at','①候補','#0073b4')]:
                x=xat(case[key]);ax.plot([x,x],[0,.085],transform=ax.get_xaxis_transform(),color=c,lw=1)
                ax.text(x,.09,label,transform=ax.get_xaxis_transform(),fontsize=8,color=c,rotation=90,ha='center',va='bottom')
            known=s.get('wave1_peak_known_at')
            if known:
                x=xat(known);ax.plot([x,x],[.91,1],transform=ax.get_xaxis_transform(),color='#0073b4',lw=1)
                ax.text(x,.9,'①確定を認識',transform=ax.get_xaxis_transform(),fontsize=8,color='#0073b4',rotation=90,ha='center',va='top')
            level=float(s.get('upper_break_level') or 0)
            start=s.get('upper_break_level_known_at')
            if level and start:
                ax.plot([max(0,xat(start)),n],[level,level],color='#2c92bf',ls=':',lw=1)
            if s.get('wave1_peak_known_at'):
                x=max(0,xat(s['wave1_peak_known_at']))
                f1,f2=float(s['fib_382_price']),float(s['fib_618_price'])
                ax.fill_between([x,n],min(f1,f2),max(f1,f2),color='#e49424',alpha=.10)
        else:
            trigger=float(s.get('trigger_line_price') or 0);known=s.get('trigger_known_at')
            if trigger and known:
                ax.plot([max(0,xat(known)),n+1],[trigger,trigger],color='#9463b2',ls=(0,(4,3)),lw=1.5)
                extrema.append(trigger)
            extreme=float(s['wave2_extreme_price']);x=xat(s['wave2_extreme_time'])
            if x>=0:
                ax.scatter([x],[extreme],s=33,color='#db8a17',zorder=6)
                ax.annotate('② 極値',(x,extreme),xytext=(5,-17 if direction>0 else 9),textcoords='offset points',fontsize=9,color='#be7610')
            else:warnings.append('下位足の②極値が表示範囲外')
        ax.axvline(n-.05,color='#7f8d9a',ls=':',lw=.9)
        ax.scatter([n+1],[entry],s=80,marker='^' if direction>0 else 'v',color='#167b48',zorder=9)
        if row==1:ax.annotate('ENTRY（注文時価格）',(n+1,entry),xytext=(-135,15 if direction>0 else -24),textcoords='offset points',color='#167b48',fontsize=10,weight='bold')
        lo,hi=min(extrema),max(extrema);pad=max(.1,(hi-lo)*.09)
        ax.set_ylim(lo-pad,hi+pad);ax.set_xlim(-1,n+5)
        ticks=sorted(set([0]+list(range(max(0,n-300),n,50))+[n]))
        ax.set_xticks(ticks,[str(t-n) for t in ticks],fontsize=9)
        ax.set_xlabel('最後の処理済み確定足からの相対位置（本）',fontsize=9)
        ax.set_ylabel('XAUUSD+ 価格',fontsize=10)
        ax.set_title(kind+f'  /  {n}本',loc='left',fontsize=11,weight='bold')
        ax.grid(alpha=.12);ax.set_axisbelow(True)
        for spine in ax.spines.values():spine.set_edgecolor('#c8d0d9')
    if len(case['pre_pivots'])<8:warnings.append(f"①前の確定pivotが{len(case['pre_pivots'])}点（8点未満）")
    if any(p['ambiguous_same_time'] for p in case['pre_pivots']):warnings.append('同時H/Lがあり山谷順序不明')
    text='青：①／橙：②・Fib／灰太破線P：①前の既知ジグザグ／灰帯：その高安範囲／紫：下位転換判定線'
    if warnings:text+='\n注意：'+'、'.join(warnings)
    fig.supxlabel(text+'\n原本ログからの再構成。MT5直接画像ではありません。勝敗・決済後・年月日は非表示。',fontsize=9,color='#4d5966')
    path=out/(case['blind_id']+'.png');fig.savefig(path,dpi=110);plt.close(fig)
    return dict(blind_id=case['blind_id'],file=path.name,sha256=digest(path),upper_bars=len(shown_upper),upper_packet_start_row=left,lower_bars=min(180,len(case['lower_bars'])),warnings=warnings,order_sequence=case['order_sequence'])


def sheets(out,ids,name):
    paths=[]
    for offset in range(0,len(ids),6):
        chosen=ids[offset:offset+6]
        canvas=Image.new('RGB',(2400,2200),'#e7edf3')
        for j,blind in enumerate(chosen):
            im=Image.open(out/(blind+'.png')).convert('RGB')
            im.thumbnail((1190,725),Image.Resampling.LANCZOS)
            canvas.paste(im,((j%2)*1200+5,(j//2)*733+4))
        path=out/(name+f'_{offset//6+1:02}.png');canvas.save(path);paths.append(path.name)
    return paths


def main():
    p=argparse.ArgumentParser();p.add_argument('--packets',type=Path,default=Path('reports/qa/w33entry60/data/blind/packets.json'));p.add_argument('--out',type=Path,default=Path('reports/qa/w33entry60/charts'));a=p.parse_args()
    a.out.mkdir(parents=True,exist_ok=True)
    plt.rcParams['font.family']=FontProperties(fname='C:/Windows/Fonts/meiryo.ttc').get_name();plt.rcParams['axes.unicode_minus']=False
    data=json.loads(a.packets.read_text(encoding='utf-8'));cases=data['cases']
    records=[render(c,a.out) for c in cases]
    groups={key:sheets(a.out,[c['blind_id'] for c in cases if int(c['blind_id'][1:])%2==parity],key) for key,parity in [('odd',1),('even',0)]}
    manifest=dict(kind='ENTRY_ONLY_RECORDED_LOG_RECONSTRUCTION',native_mt5_screenshot=False,outcome_labels_included=False,source_packet_sha256=digest(a.packets),script_sha256=digest(Path(__file__)),cases=records,contact_sheets=groups)
    (a.out/'render_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'cases':len(records),'contact_sheets':groups,'out':str(a.out)},ensure_ascii=False))


if __name__=='__main__':main()
