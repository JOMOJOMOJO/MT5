"""Completed-study review; no fitting, filtering, execution or source mutation."""
import argparse,json
from pathlib import Path
from collections import Counter
from analyze_relative_search import read_csv,write_csv
from analyze_ichimoku_diagnostics import statistics
from analyze_m5_context import extended_stats
from analyze_multitf_diagnostics import summary

def review(batch):
    assert json.loads((batch/'status.json').read_text(encoding='utf-8-sig'))['status']=='COMPLETED'
    out=batch/'review';out.mkdir(exist_ok=True)
    manifest=json.loads((batch.parent.parent/'manifest.json').read_text())
    audit=[]
    for run in manifest['runs']:
        folder=batch/run['run_id'];ic=json.loads((folder/'ichimoku_audit.json').read_text())
        p=json.loads((folder/'observer_parity.json').read_text());c=json.loads((folder/'context_audit.json').read_text())
        assert ic['passed'] and p['passed'] and c['passed'] and ic['reference_population_and_path_equal']
        audit.append(dict(run_id=run['run_id'],reconstructed=ic['ohlc_reconstructed'],unknown=ic['unknown'],
                          parity_trades=p['trades'],quality=c['quality']['category'],fallback_lines=c['quality']['fallback_line_count']))
    raw=read_csv(batch/'candidates_with_ichimoku.csv');actual=read_csv(batch/'trades_with_ichimoku.csv')
    assert len(raw)==1666 and len(actual)==217
    assert len({(r['run_id'],r['id']) for r in raw})==len(raw)
    for label,rows,is_actual in [('shadow',raw,False),('actual',actual,True)]:
        path=out/(label+'_recomputed.csv');write_csv(path,statistics(rows,is_actual))
        assert read_csv(path)==read_csv(batch/f'ichimoku_{label}_statistics.csv')
    write_csv(out/'audit.csv',audit)
    groups=[]
    for tf in ('m15','h1','h4'):
        for pos in ('ABOVE','INSIDE','BELOW'):
            for period in ('ALL','2023','2024','2025','2026'):
                for population,rows in [('all_shadow',raw),('spread_allowed_shadow',[r for r in raw if r['spread_allowed']=='1']),('actual',actual)]:
                    selected=[r for r in rows if r[tf+'_ichi_cloud_location']==pos and (period=='ALL' or r['year']==period)]
                    groups.append(dict(tf=tf,position=pos,period=period,population=population,**summary(selected,population=='actual')))
    # Row schemas differ by population, so export separate files.
    for pop in ('all_shadow','spread_allowed_shadow','actual'):
        write_csv(out/(pop+'_cloud_comparison.csv'),[r for r in groups if r['population']==pop])
    all_actual=extended_stats(actual)
    h4=[r for r in actual if r['h4_ichi_cloud_location']=='ABOVE']
    h4_shadow=[r for r in raw if r['h4_ichi_cloud_location']=='ABOVE' and r['spread_allowed']=='1']
    sf=summary(h4_shadow,False)
    info=dict(audit_passed=True,runs=len(audit),reconstructed_rows=sum(a['reconstructed'] for a in audit),
        raw=len(raw),actual=len(actual),actual_stats=all_actual,h4_above_actual=extended_stats(h4),
        h4_above_spread_allowed_shadow=sf,h4_above_observed_monthly=len(h4)/45,
        outcomes=dict(Counter(r['shadow_outcome'] for r in raw)))
    (out/'review_audit.json').write_text(json.dumps(info,indent=2)+'\n')
    lines=['# 一目均衡表：完了レビュー','',
        '## 結論','',
        '**計算・因果時刻・売買不変性の監査は合格。H4の雲より上は追加検証する仮説として残るが、採用はしない。**',
        '基礎の売買結果は前回と同じ217件、合計純損益+4.98 USD、PF1.001。今回は一目を記録しただけである。',
        '期間は2023–2024と2025–2026年9月の別テストで、損益は単純合算。45か月連続の複利成績ではない。','',
        '## H4の雲位置：既存実取引の事後内訳','',
        '|状態|件数|勝率|平均価格R|純損益 USD|PF|','|---|---:|---:|---:|---:|---:|']
    for pos in ('ABOVE','INSIDE','BELOW'):
        z=next(r for r in groups if (r['tf'],r['position'],r['period'],r['population'])==('h4',pos,'ALL','actual'))
        lines.append(f"|{pos}|{z['n']}|{z['win_rate']:.1%}|{z['mean_price_r']:+.3f}|{z['net']:+.2f}|{z['pf']:.3f}|")
    lines += ['',
        'これは「雲より上だけを許可したEA」のバックテストではない。除外すると保有/日次制限/Equityが変わり、次のEntry可否やロットも変わる。',
        '従って+873.58 USDをフィルター導入後の利益と解釈してはいけない。','',
        '### H4雲より上：年別','',
        '|年|実取引n|純損益 USD|PF|実取引平均R|全候補平均R|spread上限内候補平均R(n)|',
        '|---|---:|---:|---:|---:|---:|---|']
    for year in ('2023','2024','2025','2026'):
        rows={r['population']:r for r in groups if (r['tf'],r['position'],r['period'])==('h4','ABOVE',year)}
        a=rows['actual'];s=rows['all_shadow'];sp=rows['spread_allowed_shadow']
        lines.append(f"|{year}{' 1–9月' if year=='2026' else ''}|{a['n']}|{a['net']:+.2f}|{a['pf']:.3f}|{a['mean_price_r']:+.3f}|{s['mean_price_r']:+.3f}|{sp['mean_price_r']:+.3f} ({sp['n']})|")
    lines += ['',
        '2024/2025は良いが2023は負、2026は実取引4件。年別再現性と標本数が不足する。',
        f"H4雲上かつ既存spread上限内のshadowは{sf['n']}件、平均{sf['mean_price_r']:+.3f}R、PF{sf['pf_price_r']:.3f}。こちらも2023は負。",
        '全候補のH4雲上は1,071件、平均−0.170R、PF0.683。spread制限を通した母集団と方向が逆であり、雲だけの効果ではない。',
        '平均spread/ATRの低さはコストと大きなATRの両方を含む。どちらが作用したかは今回確定できない。','',
        '## その他の所見','',
        '- H1の雲下：全候補359件、+0.042R、PF1.096。しかし2026は−0.302R。実取引66件では−0.024R、PF0.924。全候補の微益だけで採用しない。',
        '- H1基準線下向き：実49件、−0.174R、PF0.627。2025だけは正であり、除外条件としての再現性は未確立。',
        '- M15雲中：実32件、−0.214R、PF0.596。全候補でも各年が負だが、既存シグナル全体も負のため、独立した除外効果までは示さない。',
        '- 転換線と基準線の単純な上下関係、遅行関係、雲の色だけから、十分な件数で全年度の正期待値を裏付ける結論は出ていない。',
        '- 雲FLATなどの高PFは小標本（例：M15実取引6件）なので判断材料にしない。','',
        '## 頻度','',
        '既存実行は月平均4.82件。H4雲上に該当した既存実取引は109件/45か月=2.42件/月。',
        '一目をフィルター化しても、この集計だけでは月20回の目標を達成できない。将来の通貨追加も、まず独立した期間・実行リプレイで優位性を確認した後の判断。','',
        '## 監査・制限','',
        '- 3run完了、旧実取引との完全一致：短期1件、2023–2024 157件、2025–2026 60件。短期controlを本集計へ混ぜていない。',
        '- 一目の5,757観測行を保存した閉じたOHLCから再計算して一致（control含む）。UNKNOWN 0。',
        '- cloud_source/asof<=decision<=Entryの検査、future OHLCの極端値追加によるprefix不変性に合格。',
        '- 旧raw候補とshadow価格pathも完全一致。元EA/Shared/Entry/SL/TP/リスクは無変更。',
        '- shadowはspreadを含む価格Rであり、commission/swap/発注制限を再現しない。1分内SL/TP両側到達2件は除外。',
        '- 長期は両方MIXED_TICKS。2025以降のヘッダー100%も、ログではtick生成混在を確認済み。',
        '- 既知期間・多くの特徴の閲覧・同一局面依存がある。OOSや優位性確立とは表現しない。','',
        '## 次に検証するとすれば','',
        'H4雲上を単独条件とする固定リプレイを、既存spread/SL/RR/riskのまま比較する仮説に絞れる。',
        'H1基準線やM15雲位置をさらにAND追加する探索には進めない。今回、新規MT5ジョブ・条件採用・最適化は行わない。','',
        '## データ','',
        '- [全候補と一目特徴](../candidates_with_ichimoku.csv)',
        '- [実取引と一目特徴](../trades_with_ichimoku.csv)',
        '- [全候補の年別/特徴別統計](../ichimoku_shadow_statistics.csv)',
        '- [実取引の年別/特徴別統計](../ichimoku_actual_statistics.csv)',
        '- [spread上限内候補の雲位置比較](spread_allowed_shadow_cloud_comparison.csv)',
        '- [年別の図](h4_cloud_by_year.png)',
        '- [監査集計](review_audit.json)']
    (out/'summary.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    plot(groups,out)
    print(json.dumps(info))

def plot(groups,out):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    import numpy as np
    fig,axes=plt.subplots(1,2,figsize=(10,5),layout='constrained')
    for ax,pop,title in zip(axes,('all_shadow','actual'),('All candidates (shadow)','Existing executed trades')):
        data=np.zeros((4,3));ns=np.zeros((4,3),int)
        for i,year in enumerate(('2023','2024','2025','2026')):
            for j,pos in enumerate(('ABOVE','INSIDE','BELOW')):
                r=next(r for r in groups if (r['tf'],r['position'],r['period'],r['population'])==('h4',pos,year,pop))
                data[i,j]=r['mean_price_r'];ns[i,j]=r['n']
        im=ax.imshow(data,vmin=-.6,vmax=.6,cmap='RdYlGn')
        ax.set_xticks(range(3),('ABOVE','INSIDE','BELOW'));ax.set_yticks(range(4),('2023','2024','2025','2026 Jan-Sep'))
        ax.set_title(title)
        for i in range(4):
            for j in range(3):ax.text(j,i,f'{data[i,j]:+.3f}R\nn={ns[i,j]}',ha='center',va='center')
    fig.colorbar(im,ax=axes,label='Mean price R')
    fig.suptitle('H4 cloud position / retrospective groups, not a filter replay\nMixed ticks; different selected populations; small samples')
    fig.savefig(out/'h4_cloud_by_year.png',dpi=150);plt.close(fig)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('batch',type=Path);review(p.parse_args().batch)
