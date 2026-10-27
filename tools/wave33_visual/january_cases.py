"""Generate 30 loss examples plus eight win controls from immutable logs."""
from pathlib import Path
from datetime import datetime,timedelta
import csv,json,html
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from january_review import OUT,DT,hourly,candles

def fmt(x,n=2):return 'NA' if pd.isna(x) else f'{x:.{n}f}'

def main():
    base=pd.read_csv(OUT/'trades.csv');htf=pd.read_csv(OUT/'htf/features.csv');wave=pd.read_csv(OUT/'wave_exit/features.csv')
    data=base.merge(htf.drop(columns=[k for k in htf.columns if k in base.columns and k not in ['run','setup_id']]),on=['run','setup_id'],validate='one_to_one')
    data=data.merge(wave[[k for k in wave.columns if k not in data.columns or k in ['run','setup_id']]],on=['run','setup_id'],validate='one_to_one')
    data.to_csv(OUT/'all_features.csv',index=False)
    jan=data[data.month=='2025-01'].sort_values('fill_at')
    gold=jan[jan.run=='gold_v190'];usd=jan[jan.run=='usd_v180']
    # Deterministic selection: every latest-gold loss; chronological USD losses,
    # with the separately identified largest gap loss included as an execution case.
    u_loss=usd[usd.net_r<0];gap=u_loss.nsmallest(1,'net_r')
    chosen=pd.concat([gold[gold.net_r<0],u_loss.head(11),gap,gold[gold.net_r>0],usd[usd.net_r>0].head(4)]).drop_duplicates(['run','setup_id'])
    chosen=chosen.sort_values(['run','fill_at']);assert (chosen.net_r<0).sum()==30 and (chosen.net_r>0).sum()==8
    out=OUT/'cases';out.mkdir(exist_ok=True)
    bars={};hours={}
    for run in chosen.run.unique():
        b=pd.read_csv(OUT/'source'/run/'lower_bars.csv',sep=';');b['t']=pd.to_datetime(b.closed_at,format=DT);bars[run]=b.set_index('t').sort_index();hours[run]=hourly(run);hours[run].index+=pd.Timedelta(hours=1)
    meta=[]
    for n,(_,r) in enumerate(chosen.iterrows(),1):
        fill=datetime.strptime(r.fill_at,DT);exit=datetime.strptime(r.exit_at,DT);origin=datetime.strptime(r.wave1_start_time,DT);peak=datetime.strptime(r.wave1_peak_time,DT);w2=datetime.strptime(r.wave2_extreme_time,DT)
        h=hours[r.run];hb=h[(h.index>=fill-timedelta(days=4))&(h.index<=fill+timedelta(hours=12))]
        b=bars[r.run];left=max(origin-timedelta(minutes=15),fill-timedelta(hours=6));right=min(exit+timedelta(minutes=15),fill+timedelta(hours=6));mb=b[(b.index>=left)&(b.index<=right)]
        fig,(a,c)=plt.subplots(2,1,figsize=(13,8),dpi=115,constrained_layout=True,gridspec_kw={'height_ratios':[1,1.2]})
        candles(a,hb,.028);gapmask=hb.index.to_series().diff().dt.total_seconds().fillna(3600)<=3600
        a.plot(hb.index,hb.ema20.where(gapmask),color='#2366b5',lw=.9,label='H1 EMA20');a.plot(hb.index,hb.ema50.where(gapmask),color='#dd8800',lw=.9,label='H1 EMA50')
        a.scatter([fill],[r.entry],marker='^' if r.direction=='LONG' else 'v',s=65,c='#d22e32' if r.net_r<0 else '#008553',zorder=5,label='ENTRY')
        a.axvline(fill,color='black',ls='--',lw=.8);a.axvspan(fill,fill+timedelta(hours=12),color='gray',alpha=.09,label='約定後（結果説明）')
        if pd.notna(r.h1_er12_first_close_bar):
            e_start=datetime.strptime(r.h1_er12_first_close_bar,DT)+timedelta(hours=1)
            a.axvspan(e_start,datetime.strptime(r.h1_last_closed_at,DT),color='#ffbd4d',alpha=.14,label='ER12の観測窓')
        a.set_title(f'H1：ER12={fmt(r.h1_er12,3)} / EMA方向={r.h1_ema20_alignment} / EAのH1分類={r.h1_label}',loc='left',fontsize=10)
        a.xaxis.set_major_formatter(mdates.DateFormatter('%m/%d %H:%M'));a.legend(loc='upper left',fontsize=7,ncol=4);a.grid(alpha=.15)
        candles(c,mb,.0005)
        if origin>=left:c.plot([origin,peak],[r.wave1_start_price,r.wave1_peak_price],color='#1265bd',lw=2,label='① 約定時点の固定アンカー')
        c.plot([peak,w2],[r.wave1_peak_price,r.wave2_extreme_price],color='#e18900',lw=2,label='②')
        c.axvline(fill,color='black',ls='--',lw=.8);c.axvspan(fill,right,color='gray',alpha=.09)
        direction=1 if r.direction=='LONG' else -1
        for level,label,col in [(r.entry,'ENTRY','#333333'),(r.initial_sl,'初期SL','#cc2528'),(r.entry+direction*r.risk_price,'+1R参照','#159447')]:
            c.plot([fill,right],[level,level],color=col,lw=.9,ls='--',label=label)
        if r.tp>0 and abs(r.tp-r.entry-direction*r.risk_price)>r.risk_price*.05:c.plot([fill,right],[r.tp,r.tp],color='#159447',lw=.8,ls=':',label='実TP')
        if exit<=right:
            c.scatter([exit],[r.exit_price],c='#b32626' if r.net_r<0 else '#008553',marker='x',s=42,zorder=6,label='EXIT')
            c.axvspan(exit,right,color='#e48a8a',alpha=.09,label='決済後：MFE不算入')
        c.set_title(f'M1：①終点の位置 {r.wave1_peak_time} / 知り得た時刻 {r.wave1_peak_known_at}\nW1余地 {fmt(r.wave1_room_r)}R / native最大含み益 {fmt(r.native_max_favorable_r)}R',loc='left',fontsize=9)
        c.xaxis.set_major_formatter(mdates.DateFormatter('%m/%d %H:%M'));c.legend(loc='upper left',fontsize=7,ncol=4);c.grid(alpha=.15)
        fig.suptitle(f'{n:02d} | {r.run} | {r.fill_at} {r.direction} | 確定損益 {r.net_r:+.3f}R\n足は確定時刻で配置。灰色＝約定後の結果説明。判断指標には不使用。ブローカー時刻。',fontsize=11)
        name=f'case_{n:02d}.png';fig.savefig(out/name);plt.close(fig)
        meta.append(dict(case=n,file=name,run=r.run,setup_id=r.setup_id,fill_at=r.fill_at,direction=r.direction,net_r=r.net_r,h1_er12=None if pd.isna(r.h1_er12) else r.h1_er12,h1_log=r.h1_label,loss_path=r.loss_path_class,entry=r.entry,initial_sl=r.initial_sl,tp=r.tp,wave1_peak_time=r.wave1_peak_time,wave1_peak_known_at=r.wave1_peak_known_at))
        if n%8==0:print(f'cases {n}/{len(chosen)}',flush=True)
    (out/'index.json').write_text(json.dumps(meta,indent=2,ensure_ascii=False),encoding='utf-8')
    cards=[]
    for m in meta:
        outcome='loss' if m['net_r']<0 else 'win'
        cards.append(f'<article class="case {outcome}" data-text="{html.escape(str(m))}"><h2>{m["case"]:02d} {m["run"]} {m["direction"]} {m["net_r"]:+.3f}R</h2><p>{m["fill_at"]} ER12={fmt(m["h1_er12"],3) if m["h1_er12"] is not None else "NA"}</p><a href="{m["file"]}"><img loading="lazy" src="{m["file"]}"></a><details><summary>取引ID・判定値</summary><pre>{html.escape(json.dumps(m,ensure_ascii=False,indent=2))}</pre></details></article>')
    page='''<!doctype html><html lang="ja"><meta charset="utf-8"><title>1月の負け30件・勝ち8件</title><style>body{font:15px Meiryo,sans-serif;margin:24px;background:#f4f6f8;color:#183044}header{position:sticky;top:0;background:#fff;padding:12px;z-index:2}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(540px,1fr));gap:18px}article{background:#fff;padding:12px;border-radius:8px}img{width:100%}h2{font-size:16px}pre{white-space:pre-wrap}button,input{padding:8px;margin:4px}</style><header><h1>1月：負け30件・勝ち8件</h1><p>金v1.90の全18敗＋ドル円v1.80の時系列11敗と最大ギャップ損失1件。対照は金の全4勝＋ドル円の最初の4勝。MT5の実画面ではなく、保存ローソク足からの再構成です。</p><p>灰色の約定後区間は結果説明用。H1指標は約定前の確定足のみ。未来から当時の判断を変更していません。</p><button onclick="setMode('all')">すべて</button><button onclick="setMode('loss')">負け</button><button onclick="setMode('win')">勝ち</button><input id="q" placeholder="日時・SHORT・runなど検索" oninput="apply()"><a href="../README.md">分析本文</a></header><main>'''+''.join(cards)+'''</main><script>let mode='all';function setMode(m){mode=m;apply()}function apply(){const q=document.querySelector('#q').value.toLowerCase();document.querySelectorAll('.case').forEach(x=>x.style.display=((mode==='all'||x.classList.contains(mode))&&x.dataset.text.toLowerCase().includes(q))?'':'none')}</script></html>'''
    (out/'index.html').write_text(page,encoding='utf-8')
    print('saved 38 cases; 30 losses, 8 controls')

if __name__=='__main__':main()
