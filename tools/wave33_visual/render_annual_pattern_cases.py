"""Render four fixed first-entry review cases from the existing annual CSVs."""
from __future__ import annotations

import argparse
from bisect import bisect_left
from collections import defaultdict
import csv
from datetime import datetime
import hashlib
import json
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection, PolyCollection
from matplotlib.font_manager import FontProperties
import numpy as np


def read(path):
    with path.open(encoding='utf-8-sig', newline='') as handle:
        yield from csv.DictReader(handle, delimiter=';' if path.name in ('events.csv','lower_bars.csv') else ',')


def stamp(value):
    return datetime.fromisoformat(value[:10].replace('.', '-') + value[10:])


def short(value):
    return stamp(value).strftime('%m/%d %H:%M')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path('reports/backtest/runs/wave33_v170_2020'))
    parser.add_argument('--selection', choices=('first_cases','middle_room_losses'), default='first_cases')
    args = parser.parse_args()
    batch = args.root/'20261022_161002_0ef87d9b'
    middle=args.selection=='middle_room_losses'
    case_file = args.root/'pattern_review_20261023/resistance'/('trades.csv' if middle else 'cases.csv')
    out = args.root/'pattern_review_20261023/mechanisms/charts'
    if middle:
        out=out/'middle_room_losses'
    out.mkdir(parents=True, exist_ok=True)
    cases = list(read(case_file))
    chosen = []
    for arm in ('A', 'B'):
        for outcome in (('LOSS',) if middle else ('WIN', 'LOSS')):
            eligible = [x for x in cases if x['arm'] == arm and x['outcome'] == outcome]
            if middle:
                eligible=[x for x in eligible if x['order_room_band']=='0.5_TO_1']
            if eligible:
                chosen.append(min(eligible, key=lambda x: (abs((stamp(x['entry_at'])-datetime(2020,7,1)).total_seconds()), x['entry_at'], x['setup_id'])) if middle else min(eligible, key=lambda x: (x['entry_at'], x['setup_id'])))
    selection_rule=('From resistance/trades.csv, ORDER room band 0.5_TO_1, net LOSS, each arm A/B closest entry to 2020-07-01, tie entry_at/setup_id; no magnitude selection.' if middle else 'From resistance/cases.csv, first entry by (entry_at, setup_id) for each A/B x net WIN/LOSS; no magnitude selection.')
    manifest = dict(selection=selection_rule,
                    purpose='Post-hoc trade review reconstruction from recorded lower bars and ORDER snapshots; not an MT5 screenshot and not an ex-ante replay.',
                    chosen=[dict(arm=x['arm'], outcome=x['outcome'], setup_id=x['setup_id'], entry_at=x['entry_at']) for x in chosen],
                    constraints=['No EA changes or MT5 run.', 'Candles after ORDER are review context only and never recompute entry features.',
                                 'All purple levels must be known by ORDER; drawn from ORDER to the finite chart end only.',
                                 'Wave anchor source times differ from the explicitly shown confirmation/availability times.',
                                 'R1/R2 are analysis-reconstructed levels, not the original EA nearest-obstacle line.'],
                    source_hashes={str(case_file):sha(case_file)})
    (out/'selection_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    # Selection is persisted before reading prices or plotting outcomes.
    font = FontProperties(fname='C:/Windows/Fonts/meiryo.ttc')
    plt.rcParams.update({'font.family':font.get_name(), 'font.size':11, 'axes.unicode_minus':False,
                         'savefig.facecolor':'white', 'figure.facecolor':'white'})
    palette = dict(w1='#0072B2', w2='#E28A00', entry='#148B4E', sl='#D34D4D', tp='#148B4E',
                   external='#8B4CA8', near='#B25891')
    outputs = []
    for arm, run_name, tf_label in [('A','a_extension_on','M15 × M5'), ('B','b_extension_on','M5 × M1')]:
        selected = [x for x in chosen if x['arm'] == arm]
        ids = {x['setup_id'] for x in selected}
        events = defaultdict(dict)
        for seq, row in enumerate(read(batch/run_name/'events.csv')):
            if row['setup_id'] in ids and row['event_type'] in ('ORDER','EXIT'):
                assert row['event_type'] not in events[row['setup_id']]
                events[row['setup_id']][row['event_type']] = row
                events[row['setup_id']][row['event_type']+'_sequence'] = seq
        barfile = batch/run_name/'lower_bars.csv'
        bars = list(read(barfile))
        times = [stamp(x['bar_time']) for x in bars]
        assert times == sorted(times)
        manifest['source_hashes'][str(barfile)] = sha(barfile)
        manifest['source_hashes'][str(batch/run_name/'events.csv')] = sha(batch/run_name/'events.csv')
        for case in selected:
            e = events[case['setup_id']]
            order, close = e['ORDER'], e['EXIT']
            assert e['ORDER_sequence'] == int(case['order_sequence'])
            assert order['event_at'] == case['order_at']
            assert stamp(order['wave1_peak_known_at']) <= stamp(case['order_at'])
            assert stamp(order['wave2_extreme_known_at']) <= stamp(case['order_at'])
            start = stamp(case['wave1_start_time'])
            end = stamp(case['exit_at'])
            i0 = max(0,bisect_left(times,start)-8)
            i1 = min(len(times),bisect_left(times,end)+12)
            context = bars[i0:i1]
            n = len(context)
            assert n > 10

            def xpos(value):
                t = stamp(value) if isinstance(value,str) else value
                i = bisect_left(times,t)
                if i < len(times) and times[i] == t:
                    return float(i-i0)
                # Intrabar execution is placed within its recorded candle, without inventing another candle.
                j = max(0,i-1)
                if i < len(times):
                    seconds = (times[i]-times[j]).total_seconds()
                    fraction = min(.85,max(0,(t-times[j]).total_seconds()/seconds)) if seconds else 0
                else:
                    fraction = 0
                return j-i0+fraction

            values = np.array([[float(x[k]) for k in ('open','high','low','close')] for x in context])
            fig = plt.figure(figsize=(16,8.6))
            ax = fig.add_axes([.055,.20,.675,.63])
            info = fig.add_axes([.765,.17,.225,.68])
            info.axis('off')
            fig.text(.055,.95,f"{arm}  {tf_label}  |  {case['direction']}  {short(case['entry_at'])}  |  純損益 {float(case['net_r']):+.3f} R",fontsize=17,weight='bold')
            fig.text(.055,.895,'事後の取引レビュー図 — EAテスター直接画像ではありません',fontsize=11,color='#555555')
            wick = [[(i,row[2]),(i,row[1])] for i,row in enumerate(values)]
            green='#28876B'; red='#BA5454'
            bodycolors = [green if row[3]>=row[0] else red for row in values]
            ax.add_collection(LineCollection(wick, colors=bodycolors, linewidths=.8, alpha=.80))
            bodies=[]
            for i,row in enumerate(values):
                bottom,top=sorted((row[0],row[3]))
                if top-bottom < .002:
                    top=bottom+.002
                bodies.append([(i-.32,bottom),(i+.32,bottom),(i+.32,top),(i-.32,top)])
            ax.add_collection(PolyCollection(bodies,facecolors=bodycolors,edgecolors=bodycolors,linewidths=.5,alpha=.78))
            x0,x1,x2=(xpos(order[k]) for k in ('wave1_start_time','wave1_peak_time','wave2_extreme_time'))
            p0,p1,p2=(float(order[k]) for k in ('wave1_start_price','wave1_peak_price','wave2_extreme_price'))
            ax.plot([x0,x1],[p0,p1],color=palette['w1'],lw=2.6,zorder=5)
            ax.plot([x1,x2],[p1,p2],color=palette['w2'],lw=2.4,zorder=5)
            ax.scatter([x0,x1],[p0,p1],color=palette['w1'],s=26,zorder=6)
            ax.scatter([x2],[p2],color=palette['w2'],s=32,zorder=6)
            direction=1 if case['direction']=='LONG' else -1
            ax.annotate('① 第1波',(x1,p1),xytext=(6,14 if direction>0 else -25),textcoords='offset points',color=palette['w1'],weight='bold',fontsize=11,
                        bbox=dict(facecolor='white',edgecolor='none',alpha=.80,pad=1.5))
            ax.annotate('② 押し・戻り',(x2,p2),xytext=(-100,-25 if direction>0 else 14),textcoords='offset points',color=palette['w2'],weight='bold',fontsize=11,
                        bbox=dict(facecolor='white',edgecolor='none',alpha=.80,pad=1.5))
            known_x=xpos(order['wave1_peak_known_at'])
            fib=[p1-direction*abs(p1-p0)*r for r in (.382,.618)]
            entry_x=xpos(case['entry_at'])
            # The Fib area is first displayed at peak confirmation, rather than backdating it to the peak candle.
            if known_x < entry_x:
                ax.fill_between([known_x,entry_x],min(fib),max(fib),color=palette['w2'],alpha=.075,zorder=0)
            ax.axvspan(entry_x,n-1,color='#8D99A4',alpha=.035,zorder=0)
            ax.axvline(entry_x,color='#657782',ls=':',lw=.9)
            right=n-1
            levels=[]
            for label,key,color,style in [('SL','sl_price',palette['sl'],'-'),('TP','tp_price',palette['tp'],'-')]:
                price=float(case[key]);levels.append(price)
                ax.plot([entry_x,right],[price,price],color=color,lw=1.35,ls=style,zorder=2)
                ax.text(right+.8,price,label,color=color,fontsize=11,va='center',weight='bold')
            ax.plot([entry_x,right],[p1,p1],color=palette['w1'],lw=1,ls=(0,(4,4)),alpha=.75)
            levels.append(p1)
            entry=float(case['entry_price'])
            ax.scatter([entry_x],[entry],s=120,color=palette['entry'],marker='^' if direction>0 else 'v',edgecolors='white',lw=.5,zorder=8)
            ax.annotate(f'ENTRY {entry:.2f}',(entry_x,entry),xytext=(12,18 if direction>0 else -25),textcoords='offset points',color=palette['entry'],fontsize=10,weight='bold',
                        arrowprops=dict(arrowstyle='-',color=palette['entry'],lw=.8),
                        bbox=dict(facecolor='white',edgecolor='none',alpha=.85,pad=1.5))
            exit_x=xpos(case['exit_at']);exit_p=float(close['exit_price'])
            ax.scatter([exit_x],[exit_p],s=60,color='#3C444D',marker='x',linewidths=1.9,zorder=8)
            r1 = float(case['external_price']) if case['external_price'] else None
            r2 = float(case['near_wave1_price']) if case['near_wave1_price'] else None
            for index, price in enumerate([r1,r2],start=1):
                if price is None:
                    continue
                assert stamp(case['external_known_at' if index==1 else 'near_wave1_known_at']) <= stamp(case['order_at'])
                color=palette['external' if index==1 else 'near']
                if index==2 and r1 is not None and abs(r2-r1)<1e-7:
                    continue
                levels.append(price)
                ax.plot([entry_x,right],[price,price],color=color,ls=(0,(5,3)),lw=1.6,zorder=3)
                label='R1=R2' if index==1 and r2 is not None and abs(r1-r2)<1e-7 else f'R{index}'
                ax.text(entry_x+.04*(right-entry_x),price,label,color=color,fontsize=10,va='bottom',weight='bold',
                        bbox=dict(facecolor='white',edgecolor='none',alpha=.83,pad=1.2))
            low=min(float(values[:,2].min()),*levels); high=max(float(values[:,1].max()),*levels)
            span=high-low
            ax.set_ylim(low-.12*span,high+.15*span)
            ax.set_xlim(-1,n+5)
            ax.grid(True,alpha=.18,lw=.6)
            ax.set_ylabel('XAUUSD+ 価格')
            tickpos=np.unique(np.linspace(0,n-1,7).round().astype(int))
            ax.set_xticks(tickpos,[times[i0+i].strftime('%m/%d\n%H:%M') for i in tickpos],fontsize=10)
            ax.tick_params(axis='y',labelsize=10)
            for spine in ax.spines.values():
                spine.set_edgecolor('#C6CDD3')
            block=[('注文時点の固定情報','#333333',13),
                   (f"ENTRY  {entry:.2f}",palette['entry'],11),
                   (f"SL  {float(case['sl_price']):.2f}   /   TP  {float(case['tp_price']):.2f}",'#333333',11),
                   (f"①終点  {p1:.2f}",palette['w1'],11),
                   (f"①足位置  {short(order['wave1_peak_time'])}",'#555555',10),
                   (f"①確定を知った時刻\n{short(order['wave1_peak_known_at'])}",palette['w1'],10),
                   (f"②を知った時刻  {short(order['wave2_extreme_known_at'])}",palette['w2'],10),
                   (f"①までの余地  {float(case['order_room_r']):.2f} R",'#333333',11)]
            if r1 is None:
                block.append(('R1：既知の外側水準なし',palette['external'],11))
            else:
                block.extend([(f"R1 外側の{'抵抗' if direction>0 else '支持'}  {r1:.2f}",palette['external'],11),
                              (f"基準：{case['external_tf'].replace('PERIOD_','')}の{'高値' if direction>0 else '安値'}\n足位置 {short(case['external_source_at'])}\n既知時刻 {short(case['external_known_at'])}",'#555555',10)])
            if r2 is None:
                block.append(('R2：①近接（0.1R以内）\n外部水準なし',palette['near'],10))
            else:
                block.extend([(f"R2 ①近接の外部水準  {r2:.2f}",palette['near'],11),
                              (f"基準：{case['near_wave1_tf'].replace('PERIOD_','')}\n足位置 {short(case['near_wave1_source_at'])}\n既知時刻 {short(case['near_wave1_known_at'])}",'#555555',10)])
            block.append((f"結果：{case['exit_reason'].replace('DEAL_REASON_','')}\n{short(case['exit_at'])}  {float(case['net_r']):+.3f} R",'#333333',11))
            y=1.0
            for text,color,size in block:
                info.text(0,y,text,va='top',fontsize=size,color=color,linespacing=1.55,transform=info.transAxes)
                y-=.031*(text.count('\n')+1)+.022
            fig.text(.055,.115,'青：①とその終点水準　橙：②／Fib帯　緑▲▼：約定　×：決済　紫破線：注文時に既知の再計測水準',fontsize=10,color='#444444')
            fig.text(.055,.075,'紫線は注文時から図の右端まで。注文後の足は事後確認用です。R1/R2は分析で再構成した水準で、EA元描画の最近接線とは区別しています。',fontsize=9.5,color='#555555')
            fig.text(.055,.04,f"ID: {case['setup_id']}  |  時刻：ブローカー／ソース時刻  |  休場中の横幅は圧縮",fontsize=9,color='#666666')
            name=f"{arm.lower()}_{case['outcome'].lower()}_{'middle' if middle else 'first'}.png"
            fig.savefig(out/name,dpi=140)
            plt.close(fig)
            outputs.append(dict(arm=arm,outcome=case['outcome'],setup_id=case['setup_id'],file=name,
                                plotted_lower_bars=n,net_r=float(case['net_r']),order_at=case['order_at'],
                                confirmation_at=case['wave1_peak_known_at'],external_price=r1,near_wave1_price=r2))
    manifest['rendered']=outputs
    manifest['script_hash']=sha(Path(__file__))
    (out/'selection_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    report=[f'# 注文時の波と既知水準：{len(outputs)}事例', '',
            'これは原本lower_bars.csvと注文時スナップショットから描いた事後の取引レビュー図です。MT5のテスター直接画像ではありません。①の足位置と、EAが確定を知った時刻は別に記載しています。', '',
            ('resistance/trades.csvの①余地0.5〜1R群の純損益LOSSから、A/Bそれぞれ2020年7月1日にエントリーが最も近い各1件を固定選択しました。損失額の大きさによる選択ではありません。' if middle else 'resistance/cases.csvの中から、A/B×純損益WIN/LOSSについてエントリー時刻が最初の各1件を固定選択しました。損益の大小による選抜はしていません。したがって全475件からの無作為標本でも、代表性を保証する標本でもありません。'), '',
            '紫のR1は①の外側にある未消費の既知M15/H1高値／安値、R2は①から0.1R以内にある別の既知水準です。出所の足時刻・時間足・既知時刻は右側に記載し、線は注文時から右へ有限に描きます。R1/R2は今回の分析で再構成した水準で、元EAが拾った最近接線そのものではありません。注文後の足は取引結果を確認する背景にだけ使い、入口の特徴計算には混ぜていません。', '']
    for x in outputs:
        report.extend([f"## {x['arm']} {x['outcome']}：{x['setup_id']}", '', f"![{x['arm']} {x['outcome']} review]({x['file']})", ''])
    report.extend([f"再現：`python tools/wave33_visual/render_annual_pattern_cases.py{' --selection middle_room_losses' if middle else ''}`。選択規則、入力ハッシュ、IDはselection_manifest.json。", ''])
    (out/'README.md').write_text('\n'.join(report),encoding='utf-8')
    print(json.dumps(outputs,ensure_ascii=False))


if __name__=='__main__':
    main()
