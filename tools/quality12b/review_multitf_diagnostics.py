"""Read-only review of a completed observer batch; writes separate review artifacts."""
import argparse
import csv
import json
from collections import Counter
from pathlib import Path
from statistics import mean, median
from analyze_relative_search import read_csv, write_csv
from analyze_multitf_diagnostics import aggregate, verify_context
from analyze_m5_context import extended_stats

def review(batch):
    assert json.loads((batch/'status.json').read_text(encoding='utf-8-sig'))['status']=='COMPLETED'
    package=batch.parent.parent
    manifest=json.loads((package/'manifest.json').read_text())
    out=batch/'review';out.mkdir(exist_ok=True)
    audits=[]
    for run in manifest['runs']:
        folder=batch/run['run_id']
        a=json.loads((folder/'context_audit.json').read_text());assert a['passed']
        m=json.loads((folder/'metrics.json').read_text(encoding='utf-8-sig'));assert m['audit']['passed']
        for r in read_csv(folder/'context.csv',';'):verify_context(r)
        parity=None
        if 'reference_report' in run:
            parity=json.loads((folder/'observer_parity.json').read_text());assert parity['passed']
        q=a['quality']
        audits.append(dict(run_id=run['run_id'],passed=True,candidates=a['candidates'],trades=a['entries'],
            parity_trades=parity['trades'] if parity else '',invalid_ranges=a['invalid_ranges'],
            quality=q['category'],header_real_tick_percent=q['header_real_tick_percent'],fallback_lines=q['fallback_line_count']))
    c=read_csv(batch/'candidates_with_context.csv');t=read_csv(batch/'trades_with_context.csv');monthly=read_csv(batch/'monthly_counts.csv')
    assert len(c)==len({(r['run_id'],r['id']) for r in c})
    assert sum(int(r['executed']) for r in c)==len(t)
    assert len(c)==sum(int(r['candidates']) for r in monthly)
    assert len(t)==sum(int(r['executions']) for r in monthly)
    # Recompute summary tables independently from the exported population rows.
    write_csv(out/'audit.csv',audits)
    annual=[]
    for year in ('2023','2024','2025','2026'):
        raw=[r for r in c if r['year']==year];trades=[r for r in t if r['year']==year]
        annual.append(dict(year=year,months=9 if year=='2026' else 12,candidates=len(raw),
            spread_blocked=sum(r['spread_allowed']=='0' for r in raw),
            median_spread_price=median(float(r['spread_price']) for r in raw),
            median_atr=median(float(r['atr']) for r in raw),median_spread_atr=median(float(r['spread_atr']) for r in raw),
            **extended_stats(trades)))
    write_csv(out/'annual_review.csv',annual)
    actual=aggregate(t,True);shadow=aggregate(c,False)
    write_csv(out/'actual_recomputed.csv',actual);write_csv(out/'shadow_recomputed.csv',shadow)
    assert read_csv(out/'actual_recomputed.csv')==read_csv(batch/'actual_environment_statistics.csv')
    assert read_csv(out/'shadow_recomputed.csv')==read_csv(batch/'shadow_environment_statistics.csv')
    joint=[r for r in shadow if r['period']=='ALL' and r['axis']=='JOINT_REGIME_SPREAD_TIME']
    info=dict(completed_runs=len(audits),parity_comparisons=sum(r['parity_trades']!='' for r in audits),
        candidate_count=len(c),execution_count=len(t),spread_blocked=sum(r['spread_allowed']=='0' for r in c),
        spread_only=sum(r['gate_flags']=='SPREAD' for r in c),
        candidates_per_month=len(c)/len(monthly),executions_per_month=len(t)/len(monthly),
        min_monthly_candidates=min(int(r['candidates']) for r in monthly),
        months_at_least20_candidates=sum(int(r['candidates'])>=20 for r in monthly),
        months_at_least20_executions=sum(int(r['executions'])>=20 for r in monthly),
        zero_execution_months=sum(int(r['executions'])==0 for r in monthly),
        outcomes=dict(Counter(r['shadow_outcome'] for r in c)),
        unclassified_nonexecutions=sum(r['gate_flags']=='OTHER_GATE_OR_ORDER_REJECTION' for r in c),
        joint_cells=len(joint),joint_cells_below30=sum(r['n']<30 for r in joint))
    (out/'review_audit.json').write_text(json.dumps(info,indent=2)+'\n')
    def find(rows,axis,category,year='ALL'):
        return next((r for r in rows if (r['period'],r['axis'],r['category'])==(year,axis,category)),None)
    lines=['# M5 × M15/H1/H4環境診断：完了レビュー','',
        '## 結論','',
        '**環境データの収集・監査は完了。利益改善が確認できたという結果ではない。**',
        'M5の実取引は217件、期間別の純損益合計は+4.98 USD、PF 1.001、勝率48.4%。ほぼ横ばい。',
        '2023–2024と2025–2026年9月はそれぞれ10,000 USDで開始した別テスト。合計損益は単純合算で、45か月連続の複利結果ではない。',
        '全候補shadowは1,666件（両側到達2件除外、評価1,664件）、平均−0.133R、価格RベースPF 0.743。',
        'shadowはspreadを含むがcommission/swap/発注制約を含まない1分Bid近似。実取引との成績差を環境の効果と解釈しない。','',
        '## 実取引の年別結果','',
        '|年|raw候補|実取引|純損益 USD|PF|平均価格R|spread上限抵触|',
        '|---|---:|---:|---:|---:|---:|---:|']
    for r in annual:
        lines.append(f"|{r['year']}{'（1–9月）' if r['year']=='2026' else ''}|{r['candidates']}|{r['n']}|{r['net']:+.2f}|{r['pf']:.3f}|{r['mean_price_r']:+.3f}|{r['spread_blocked']}|")
    lines += ['', '## 頻度と見送り','',
        f"raw候補は月平均{info['candidates_per_month']:.2f}件、45か月中{info['months_at_least20_candidates']}か月で20件以上（最少15件）。",
        f"実行は月平均{info['executions_per_month']:.2f}件。月20件以上は{info['months_at_least20_executions']}か月だけ、ゼロ月は{info['zero_execution_months']}か月。",
        'spread>0.20ATRに抵触した候補は1,388/1,666=83.3%。うちspreadのみの記録要因は1,349件。',
        '上限内278件のうち217件を実行。残り61件は保有中・日次件数等。4件は既存ログでは具体的な後段見送り理由を特定できず、OTHER_GATE_OR_ORDER_REJECTIONとして残す。',
        'M5の値幅が小さい局面ほど同じspreadがATRに対して重くなる。2026年は候補303件中296件が上限超過。',
        'ただし上限を外せば改善するという意味ではない。上限超過shadowの成績は低い。今回は制御を変更しない。','',
        '## 環境による差（全候補shadow、事後の記述比較）','',
        '|区分|件数|平均R|価格R PF|2023 平均R(n)|2024|2025|2026 1–9月|',
        '|---|---:|---:|---:|---|---|---|---|']
    comparisons=[('H4_REGIME_POSITION','RANGE_LOW'),('M15_REGIME_POSITION','UP_MID'),
                 ('H1_REGIME_POSITION','DOWN_HIGH'),('JOINT_REGIME','UP|UP|UP')]
    for axis,cat in comparisons:
        r=find(shadow,axis,cat);ys=[]
        for y in ('2023','2024','2025','2026'):
            z=find(shadow,axis,cat,y);ys.append(f"{z['mean_price_r']:+.3f} ({z['n']})" if z else 'なし')
        lines.append(f"|{axis}: {cat}|{r['n']}|{r['mean_price_r']:+.3f}|{r['pf_price_r']:.3f}|"+'|'.join(ys)+'|')
    lines += ['',
        '- H4 RANGE_LOWは全体で比較的良いが2026年は負。実取引15件の年別平均Rも2023 +0.528、2024 −0.220、2025 −0.170で一貫しない。採用根拠には不足。',
        '- M15 UP_MIDも39候補しかなく、2023/2026は負。実取引8件の高PFだけでは判断できない。',
        '- H1 DOWN_HIGHは全体では悪いが2025は正。悪条件としての再現性も未確立。',
        '- 3時間足すべてUPはshadow91件で全4年が負。「上位足が全部上昇なら勝ちやすい」という単純仮説は今回の母集団では支持されない。実取引は12件しかなく、同じ結論へ混同しない。','',
        '## スプレッドと時刻','',
        '|spread/ATR|shadow件数|shadow平均R|shadow PF|実取引件数|実取引純損益 USD|',
        '|---|---:|---:|---:|---:|---:|']
    for cat in ('0_to_0.10','0.10_to_0.20','0.20_to_0.30','above_0.30'):
        r=find(shadow,'SPREAD_ATR',cat);a=find(actual,'SPREAD_ATR',cat)
        lines.append(f"|{cat}|{r['n']}|{r['mean_price_r']:+.3f}|{r['pf_price_r']:.3f}|{a['n'] if a else 0}|{a['net'] if a else 0:+.2f}|")
    lines += ['',
        'spread<=0.1ATRは良い成績だがshadow19件/実取引15件、2026年は該当なし。利益と頻度を両立できる証拠ではない。',
        'spread/ATRはコストだけでなく、ATR分母（値動きの大きさ）も表す。コスト効果とボラティリティ効果は未分離。年別の中央値をannual_review.csvに保存。',
        'サーバー時刻06–11時の実取引は71件・+537.91 USD・PF1.305。ただし2023/2026は負。全候補shadowでは−0.146R。時間帯単独でも安定した改善は確認できない。',
        f"環境3TF×spread×6時間帯の観測済み{info['joint_cells']}セルのうち{info['joint_cells_below30']}セルが30件未満。細分化した勝率のランキングは採用に使わない。",
        '時刻はブローカーサーバー時刻。日本時間・UTC・取引セッションの夏時間へ自動変換していない。','',
        '## 監査・限界','',
        '- 4run完了、因果時刻監査/M15元分類との一致確認は全run合格。UNKNOWN位置2件も削除せず保持。',
        '- 観測追加前後のEntry/SL/TP/注文数/損益の完全一致：M15 98件、M5短期1件、M5 2023–2024 157件。',
        '- ソース追加は観測フックのみ。売買EA・Shared・SL/TP/リスクの変更なし。コンパイル0 errors/0 warnings。',
        '- 長期2runはどちらもMIXED_TICKS。2023–2024ヘッダー57%、2025–2026ヘッダー100%でもログ上にtick欠落/廃棄あり。純real-tick検証とは呼ばない。',
        '- 勝率は時間決済を含め損益が正の割合。TP到達率とは別。Horizon MFE/MAEはSL/TP後も含む18本固定窓。',
        '- 既知期間、同じ局面の候補依存、多数の区分を閲覧した事後分析。新期間での優位性確立ではない。','',
        '## 次の判断','',
        '今回は環境フィルターを採用しない。H4レンジ下部の反発余地は記録しておく仮説だが、別年・実行可能母集団で再現していない。',
        '頻度を阻む主因はspread/ATR。上限緩和ではなく、同じシグナル時点での実際のコストと値幅を分けて確認するのが先。',
        '本ファミリーは「1通貨で毎月20件、安定した正期待値」という目標を現状満たしていない。細かいAND条件の追加で救済する段階には進めない。',
        '参考：同じ中心パラメータのM15版は全446候補・実223件、M5版は全1,666候補・実217件。M5化で候補は増えたが実行数は増えていない。18本の保有上限もM15=270分からM5=90分へ変わるため、時間足だけの純粋な因果比較ではない。',
        '新規MT5ジョブや本番反映は今回実施しない。','',
        '## ファイル','',
        '- 全候補：[candidates_with_context.csv](../candidates_with_context.csv)',
        '- 実取引：[trades_with_context.csv](../trades_with_context.csv)',
        '- 全区分shadow：[shadow_environment_statistics.csv](../shadow_environment_statistics.csv)',
        '- 全区分実取引：[actual_environment_statistics.csv](../actual_environment_statistics.csv)',
        '- 月別：[monthly_counts.csv](../monthly_counts.csv)',
        '- 本レビュー集計：[annual_review.csv](annual_review.csv) / [audit.csv](audit.csv)',
        '- 全体分布：[environment_means.png](environment_means.png)']
    (out/'summary.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    plot(shadow,out)
    print(json.dumps(info))

def plot(rows,out):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import numpy as np
    cats=[r+'_'+p for r in ('UP','RANGE','DOWN') for p in ('LOW','MID','HIGH')]
    values=np.full((9,3),np.nan);ns=np.zeros((9,3),int)
    for i,cat in enumerate(cats):
        for j,tf in enumerate(('M15','H1','H4')):
            r=next((r for r in rows if (r['period'],r['axis'],r['category'])==('ALL',tf+'_REGIME_POSITION',cat)),None)
            if r:values[i,j]=r['mean_price_r'];ns[i,j]=r['n']
    fig,ax=plt.subplots(figsize=(7,8));im=ax.imshow(values,cmap='RdYlGn',vmin=-.6,vmax=.6)
    ax.set_xticks(range(3),['M15','H1','H4']);ax.set_yticks(range(9),cats)
    for i in range(9):
        for j in range(3):
            ax.text(j,i,f'{values[i,j]:+.3f}R\nn={ns[i,j]}',ha='center',va='center',fontsize=10)
    ax.set_title('All-candidate shadow: mean price R\n2023–2026 Sep / no filter selection')
    fig.colorbar(im,ax=ax,label='Mean R (before commission/swap)')
    fig.text(.5,.015,'Descriptive, mixed ticks. Small / dependent samples. Not an out-of-sample result.',ha='center',fontsize=8)
    fig.tight_layout(rect=(0,.04,1,1));fig.savefig(out/'environment_means.png',dpi=150);plt.close(fig)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('batch',type=Path);review(p.parse_args().batch)
