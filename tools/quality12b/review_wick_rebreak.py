"""Close the fixed A/B study from audited artifacts; no optimization or MT5 execution."""
import argparse
import json
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from analyze_cost_channel import native, read, metrics
from analyze_reports import number
from prepare_portable_audit import ROOT, save, sha, verify


def table(df, columns):
    selected=df[columns].copy()
    for col in selected:
        if pd.api.types.is_float_dtype(selected[col]):selected[col]=selected[col].map(lambda x:f'{x:.3f}' if pd.notna(x) else 'NA')
    return '|'+ '|'.join(columns)+'|\n|'+'|'.join(['---']*len(columns))+'|\n'+'\n'.join(
        '|'+ '|'.join(str(x) for x in row)+'|' for row in selected.itertuples(index=False,name=None))


def run(batch):
    package=batch.parent.parent;m=verify(package)
    state=json.loads((batch/'status.json').read_text(encoding='utf-8-sig'))
    assert state['status']=='COMPLETED' and state['completed_runs']==34
    out=batch/'review';out.mkdir(exist_ok=True)
    sources={batch/'status.json',package/'manifest.json'}
    trades=[];years=[];audit_counts=dict(runs=0,period=0,baseline=0,ab=0,repair=0,harness_tests=0)
    for spec in m['runs']:
        folder=batch/spec['run_id'];path=folder/'audit.json';sources.add(path)
        audit=json.loads(path.read_text());assert audit['passed'] and audit['r3_audit_passed'];audit_counts['runs']+=1
        if spec['kind']=='harness':audit_counts['harness_tests']=audit['tests'];continue
        for filename,key in [('history_period_audit.json','period'),('baseline_parity.json','baseline'),
                             ('ab_cohort_parity.json','ab'),('observer_repair_parity.json','repair')]:
            path=folder/filename
            if path.exists():
                sources.add(path);assert json.loads(path.read_text())['passed'];audit_counts[key]+=1
        if spec.get('phase')!='known_validation':continue
        sources.update([folder/'trades.csv',folder/'report.htm',folder/'risk.csv'])
        data=read(folder/'trades.csv');computed=metrics(data);h,_,_=native(folder/'report.htm')
        assert len(data)==int(number(h['trade_count']))==audit['actual']['n']
        assert abs(computed['net']-float(number(h['net_profit'])))<.011
        assert abs(computed['pf']-audit['actual']['pf'])<1e-9
        risk=[r for r in read(folder/'risk.csv',';') if r['reason']=='OK']
        assert len(risk)==len(data)
        assert all(float(r['planned_loss'])<=float(r['budget'])+1e-7 for r in risk)
        for r in data:trades.append(dict(r,run_id=spec['run_id'],symbol=spec['symbol'],arm=spec['arm'],run_year=int(spec['date_from'][:4])))
        best=max(float(r['net']) for r in data)
        years.append(dict(symbol=spec['symbol'],year=int(spec['date_from'][:4]),arm=spec['arm'],**computed,
                          largest_win_usd=best,net_without_largest_win=computed['net']-best,
                          equity_dd_native=h['equity_drawdown_maximal'],balance_dd_native=h['balance_drawdown_maximal']))
    data=pd.DataFrame(trades);annual=pd.DataFrame(years)
    for c in ['net','fill_price_r','volume','risk_price','swap','holding_hours']:data[c]=pd.to_numeric(data[c])
    def csv(name):
        p=batch/name;sources.add(p);return pd.read_csv(p)
    monthly=csv('monthly_execution.csv');candidate=csv('candidate_comparison.csv');transition=csv('transition_ledger.csv')
    execution=csv('execution_ledger.csv');context=csv('context_statistics.csv');shadow=csv('shadow_statistics.csv')
    sources.update([batch/'paired_uncertainty.csv',batch/'historical_environment_differences.json'])
    assert len(candidate)==2*len(transition)==8952
    assert not candidate.duplicated(['symbol','year','id','arm']).any()
    assert len(data)==(execution.status=='FILLED').sum()
    assert len(monthly)==3*2*45
    totals=[];comparisons=[]
    for (symbol,arm),g in data.groupby(['symbol','arm'],sort=False):
        mm=monthly[(monthly.symbol==symbol)&(monthly.arm==arm)]
        assert len(mm)==45 and mm.actual_entries.sum()==len(g)
        best=g.net.max()
        totals.append(dict(symbol=symbol,arm=arm,**metrics(g.to_dict('records')),
                           months=45,entries_per_month=len(g)/45,months_at_least_20=int((mm.actual_entries>=20).sum()),
                           minimum_month_entries=int(mm.actual_entries.min()),maximum_month_entries=int(mm.actual_entries.max()),
                           largest_win_usd=best,net_without_largest_win=g.net.sum()-best,
                           worst_fill_r=g.fill_price_r.min(),best_fill_r=g.fill_price_r.max()))
    totals=pd.DataFrame(totals).sort_values(['symbol','arm'])
    for symbol,g in transition.groupby('symbol'):
        paired=g[g.a_evaluable & g.b_evaluable]
        entries=candidate[(candidate.symbol==symbol)&(candidate.arm=='B')&candidate.formed]
        a=candidate[(candidate.symbol==symbol)&(candidate.arm=='A')][['id','risk']].rename(columns={'risk':'a_risk'})
        joined=entries.merge(a,on='id',validate='one_to_one')
        comparisons.append(dict(symbol=symbol,raw_candidates=len(g),unique_parent_groups=g.parent_group.nunique(),
            b_formed=len(entries),b_formation_rate=len(entries)/len(g),anchor_broken=int((g.b_state=='PARENT_LOW_BROKEN').sum()),
            expired=int((g.b_state=='EXPIRED').sum()),a_losses_without_b=int(g.a_loss_without_b.sum()),
            a_wins_without_b=int(g.a_win_without_b.sum()),paired_evaluable=len(paired),
            paired_a_mean_r=paired.a_r.mean(),paired_b_mean_r=paired.b_r.mean(),paired_b_minus_a_r=(paired.b_r-paired.a_r).mean(),
            a_profit_to_b_loss=int(((paired.a_r>0)&(paired.b_r<0)).sum()),a_loss_to_b_profit=int(((paired.a_r<0)&(paired.b_r>0)).sum()),
            entry_worse_mean_a_r=entries.entry_change_in_a_r.mean(),entry_worse_median_a_r=entries.entry_change_in_a_r.median(),
            wait_mean_minutes=entries.wait_minutes.mean(),wait_median_minutes=entries.wait_minutes.median(),
            b_to_a_risk_width_mean=(joined.risk/joined.a_risk).mean()))
    comparisons=pd.DataFrame(comparisons)
    blockers=execution.groupby(['symbol','arm','status','detail']).size().rename('count').reset_index()
    yearly_context=context[context.year.astype(str)!='ALL'].copy()
    stability=[]
    for keys,g in yearly_context.groupby(['symbol','arm','feature','category']):
        stability.append(dict(zip(['symbol','arm','feature','category'],keys),years_present=len(g),
                              positive_years=int((g.expectancy_r>0).sum()),minimum_year_n=int(g.n_evaluable.min()),
                              total_evaluable=int(g.n_evaluable.sum()),worst_year_mean_r=g.expectancy_r.min(),best_year_mean_r=g.expectancy_r.max()))
    stability=pd.DataFrame(stability)
    assert not ((stability.years_present==4)&(stability.positive_years==4)).any(), 'Review any consistently positive context before finalizing verdict'
    excluded=candidate[candidate.formed & ~candidate.evaluable]
    assert len(excluded)==7 and (excluded.ambiguous_exit_minute==1).all()
    for name,frame in [('actual_overall.csv',totals),('actual_yearly.csv',annual),('candidate_transitions.csv',comparisons),
                       ('execution_blockers.csv',blockers),('context_stability.csv',stability),('excluded_shadows.csv',excluded),
                       ('actual_trades.csv',data)]:frame.to_csv(out/name,index=False,encoding='utf-8-sig')
    # Side-by-side views use identical axes. Native yearly tests reset their balances independently.
    fig,axs=plt.subplots(2,3,figsize=(15,7),constrained_layout=True)
    for j,symbol in enumerate(m['symbols']):
        for arm,color,offset in [('A','#2876ae',-.19),('B','#d67b20',.19)]:
            ss=annual[(annual.symbol==symbol)&(annual.arm==arm)].sort_values('year')
            axs[0,j].bar(np.arange(4)+offset,ss.net,.36,label=arm,color=color)
            mm=monthly[(monthly.symbol==symbol)&(monthly.arm==arm)].sort_values('month')
            axs[1,j].plot(np.arange(45),mm.actual_entries,label=arm,color=color,linewidth=1.3)
        axs[0,j].set_title(symbol);axs[0,j].axhline(0,color='black',linewidth=.7)
        axs[0,j].set_xticks(range(4),['2023','2024','2025','2026 Jan-Sep']);axs[0,j].set_ylim(-1300,1150)
        axs[1,j].axhline(20,color='black',linestyle='--',linewidth=1,label='20/month')
        axs[1,j].set_xticks([0,12,24,36,44],['2023-01','2024-01','2025-01','2026-01','2026-09']);axs[1,j].set_ylim(0,30)
        axs[0,j].legend();axs[1,j].legend(fontsize=8);axs[1,j].tick_params(axis='x',labelrotation=20)
    axs[0,0].set_ylabel('Net USD (yearly reset, deposit 10,000)');axs[1,0].set_ylabel('Actual entries per month')
    fig.suptitle('A: immediate upper-wick buy | B: later M5 close above fixed signal high')
    fig.savefig(out/'yearly_results_and_frequency.png',dpi=160);plt.close(fig)
    verdict=dict(engineering='PASSED',strategy='DO_NOT_PROMOTE_B',family_action='PARK_FIXED_WICK_REBREAK_THESIS',
                 audits=audit_counts,new_runs=30,reused_runs=4,raw_candidates=len(transition),formed_shadows=int(candidate.formed.sum()),
                 excluded_ambiguous_shadows=len(excluded),known_period=True,generated_ticks=True,parameters_changed=0,
                 no_current_context_category_positive_in_all_four_periods=True)
    save(out/'verdict.json',verdict)
    lines=['# 上ヒゲ即時A／終値再突破B：全期間検証の結論','',
        '**全34本の監査は合格。ただしBは採用しない。固定高値を終値で再突破してから買う変更は、複数年で安定した正期待値を作れなかった。**','',
        '対象はM5 Round LONG。過去のM1/M5「3の3 READY」EAとは別系統。売買EA・既存Sharedは変更していない。','',
        '## 1. 何を比較したか','',
        '- A：条件を満たした上ヒゲM5足の確定後、最初のAskで買う。',
        '- B：同じ足のHighを固定し、後続M5の終値が初めて上抜いた時に買う。待機18本、固定pivot low割れで無効。',
        '- 共通：Entry時ATR14×2.2のSL、TP1.5R、リスク予算Equity0.65%、1ポジション、日次2取引、日次損失3%、DD12%、spread/ATR上限0.2。',
        '- SL/TPは各Entry時のATRで再計算される。同じ絶対SL/TP・同じ出口時刻を固定した純粋な入口価格だけの比較ではない。',
        '- 2023〜2025各年＋2026年1〜9月、USDJPY/EURUSD/XAUUSD。Vantage、生成tick、既知期間。最適化なし。','',
        '## 2. 実行可能リプレイの結果','',
        '年ごと・銘柄ごと・A/Bごとに初期10,000 USDへ戻した独立口座の合算。以下のPFは全実取引の利益合計÷損失絶対額で再計算し、年別PFの平均ではない。合成portfolioや45か月連続複利の成績ではない。','',
        table(totals,['symbol','arm','n','net','pf','win_rate','mean_fill_r','entries_per_month','months_at_least_20']),
        '', 'mean_fill_rは価格損益R。net/PFには実際のswap等を含む。全runのcommission/feeは0、XAUUSD Aにswap −21.68 USDを含む。','',
        '- USDJPY：A/Bとも全期間PF<1。Bの改善は主に2025年29取引に依存。2025年のBはPF2.001・+498.12 USDだが、2023年は−628.69 USD、2026年は3取引のみで−62.49 USD。',
        '- EURUSD：Bで損失は縮小したが、全ての年で実損益が負。回数も119→59と半減し、正期待値には至っていない。',
        '- XAUUSD：Aの全期間−237.42 USDに対してBは−2,090.69 USD。2025年はA +1,001.85 USD、B −1,155.62 USDへ悪化。',
        '- 単独で毎月20回を満たす案はない。最も多いXAUUSD Aも月平均14.82回、45か月中20回以上は19か月。Bは全銘柄とも20回に届いた月が0。','',
        '![年別損益と月別実行回数](yearly_results_and_frequency.png)','',
        '## 3. 全候補shadow：口座制約を外しても改善したか','',
        '全元候補4,476件、B成立2,358件。候補があってもB未成立なら仮想損益0には置換しない。SL/TP両方に触れた決済分の7shadowは主評価から除外。口座リプレイの実取引を後から削除した結果ではない。','',
        table(shadow[shadow.year.astype(str)=='ALL'],['symbol','arm','base_candidates','n_evaluable','win_rate','expectancy_r','pf']),
        '', 'shadowは観測Ask/Bidのspreadを含む価格損益Rで、commission/swapは含まない。BはEURUSDで平均Rが改善したが依然負、USDJPY/XAUUSDでは悪化した。','',
        '## 4. 確認待ちで何を失ったか','',
        table(comparisons,['symbol','raw_candidates','b_formed','a_losses_without_b','a_wins_without_b','entry_worse_mean_a_r','wait_median_minutes']),
        '', 'B未成立はAの損失を1,773件避ける一方、Aの利益341件も取り逃した。重要なのは、Bが成立したケースでも平均0.51〜0.55 A-R高い価格で買い、待ち時間中央値15分だったこと。','',
        table(comparisons,['symbol','paired_evaluable','paired_a_mean_r','paired_b_mean_r','a_profit_to_b_loss','a_loss_to_b_profit','b_to_a_risk_width_mean']),
        '', '両案成立・両案評価可能な同一候補では、B−AはUSDJPY −0.468R、EURUSD −0.436R、XAUUSD −0.531R。週単位block bootstrapでも2023〜2024／2025〜2026の両区間で負だった。',
        'ただし「B成立を後で知った候補だけのA」は未来条件で選ばれた説明用部分集合であり、当時実行可能な新しいAフィルターの成績ではない。差にはEntry価格だけでなくATR/SL幅・出口時刻の変化も含む。','',
        '## 5. 回数を減らした要因','',
        'Aの全候補に対し、spread見送りはUSDJPY 1,336/1,666（80.2%）、EURUSD 1,255/1,408（89.1%）。ゴールドはspread 144件より日次回数制限165件、口座DD停止286件、保有中140件も大きい。',
        '記録は最初に返った見送り理由なので、複数制限の同時成立を排他的な真因として数えたものではない。',
        '全shadowの期待値も負で、spread制限だけを緩めれば収益性が解決するという証拠にはならない。損失縮小が取引削減から来ただけか、平均R/PFも併読する。','',
        '## 6. M15/H1/H4環境と年別再現性','',
        '事前に決めた6種類（H1方向/M15位置/H4方向、それぞれEntry時と共通A発生時）の全カテゴリを年別に確認した。4期間全てで正のshadow平均Rとなるカテゴリはなかった。AND探索・閾値探索は行っていない。',
        '例：XAUUSD A・共通A時点H4 RANGEは2023 +0.115R、2024 +0.045R、2025 +0.055Rだったが、2026は−0.155R。H1 RANGEも2026に負へ反転。',
        'M15 LOWには年2〜8件の小さい区分があり、良い年があっても採用根拠にしない。カテゴリを除外した後の口座経路は今回は実行しておらず、全shadow区分の成績を実行可能成績と混ぜない。',
        '同一親を共有する反復候補がある。親数・週block区間を保存したが、個々の候補が独立した証拠だとはみなさない。','',
        '## 7. 大勝依存・執行上の観測','',
        '最大利益取引を除いても、USDJPY Bの2025年は+398.08 USD、XAUUSD Aの2025年は+896.19 USD。良い年が1件の異常利益だけで作られたわけではない。問題は他年への再現性と低頻度。年別の詳細はactual_yearly.csv。',
        'リスクplanは全て予算内だが、SLが指定価格で約定する保証ではない。USDJPY Bの2023-08-11はSL144.638に対して実決済144.408、−2.144R（−134.31 USD）。SLより下のBidでの決済がAsk/Bid/約定ログに記録されており、想定riskの計算超過と区別する。',
        '18本のM5保有は通常90分相当だが、休場・tick不在時には壁時計90分で決済できない。XAUUSD Aの2025-11-27 20:10→翌01:09:26の取引は4.99時間となり、swap −21.68 USDが付いた。売買ルールは今回変えていない。',
        'real ticksの検証ではない。注文遅延0、追加commission0のtester条件であり、既知期間の結果から未使用OOSやliveでの優位性を主張しない。','',
        '## 8. 監査の結論と次の判断','',
        f"34/34 run合格。新規30本＋修正後r2から再監査付き再利用4本。履歴期間監査{audit_counts['period']}本、旧版reference/A一致{audit_counts['baseline']}組、A/B候補・shadow・環境一致{audit_counts['ab']}組、MQL harness {audit_counts['harness_tests']}項目。",
        '過去とのswap仕様差7runはenvironment_exact=falseのまま記録。適用swap0・日内買い・約定/cash/判断CSV完全一致の限定分類であり、現在のA/Bペアの環境差を許したものではない。3ソースのcompileは0 errors / 0 warnings、Python34テスト合格。',
        '**採否：Bを本番へ反映しない。この固定入口仮説は区切りをつけ、RR・待機本数・spread上限を利益に合わせて追加探索しない。Aも今回の全期間で正期待値を示しておらず、本番昇格の根拠にはしない。**',
        '本番EAを変更せず、このサイクルを終了する。別の仮説に進む場合も、今回の有利な年だけを選ぶのではなく、新しい予測理由と未使用期間を先に固定する。','',
        '## 成果物','',
        '- [年別実行結果](actual_yearly.csv) / [全期間実行結果](actual_overall.csv)',
        '- [選別・価格悪化・遷移](candidate_transitions.csv) / [実行見送り理由](execution_blockers.csv)',
        '- [環境区分の再現性](context_stability.csv) / [全環境区分](../context_statistics.csv)',
        '- [全4,476候補×A/B](../candidate_comparison.csv) / [月別実行数](../monthly_execution.csv)',
        '- [両案成立例の週block区間](../paired_uncertainty.csv) / [過去環境の差](../historical_environment_differences.json)',
        '- [機械可読な採否](verdict.json) / [入力証拠のhash](provenance.json)']
    (out/'summary.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    save(out/'provenance.json',dict(reviewer_sha256=sha(Path(__file__)),inputs={str(p.relative_to(ROOT)):sha(p) for p in sorted(sources)},
                                  outputs={p.name:sha(p) for p in sorted(out.iterdir()) if p.is_file() and p.name!='provenance.json'}))
    print(json.dumps(dict(review=str(out),**verdict)))


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--batch',type=Path,required=True)
    run(parser.parse_args().batch.resolve())
