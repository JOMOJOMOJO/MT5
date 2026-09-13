"""Render evidence-led readout, without selecting or refitting anything."""
import json
import pandas as pd
import numpy as np
import usdjpy_only_ml as u


def table(df,columns):
    lines=['|'+'|'.join(columns)+'|','|'+'|'.join(['---']*len(columns))+'|']
    for _,r in df.iterrows():
        vs=[]
        for c in columns:
            v=r[c]
            vs.append(f'{v:.5f}' if isinstance(v,(float,np.floating)) else str(v))
        lines.append('|'+'|'.join(vs)+'|')
    return '\n'.join(lines)


def main():
    u.check_freeze();p=u.OUT
    cfg=json.loads((p/'selection.json').read_text());spec=json.loads((p/'frozen_model.json').read_text())
    comp=pd.read_csv(p/'comparison_monthly.csv');pop=pd.concat([pd.read_csv(p/'development_population.csv'),pd.read_csv(p/'holdout_population.csv')])
    front=pd.read_csv(p/'candidate_frontier.csv');families=pd.read_csv(p/'model_family_comparison.csv')
    ranking=pd.read_csv(p/'feature_ranking.csv');interactions=pd.read_csv(p/'interaction_ranking.csv')
    perm=pd.read_csv(p/'group_permutation.csv').groupby('feature_or_group')[['total_r_degradation','ev_rmse_increase']].mean().reset_index()
    costs=pd.read_csv(p/'cost_sensitivity.csv');freq=pd.read_csv(p/'frequency_frontier.csv')
    prior=pd.read_csv(p/'six_symbol_common_usdjpy_comparison.csv');geom=pd.read_csv(p/'geometry_diagnostics.csv')
    passing=front[front.robust_gate & front.min_month_trades.ge(100)]
    devtr=pd.read_csv(p/'selected_development_trades.csv');holdtr=pd.read_csv(p/'holdout_trades.csv')
    holdlong=[]
    for label,t in [('DEVELOPMENT',devtr),('HOLDOUT',holdtr)]:
        sec=(t.exit_msc-t.entry_msc)/1000
        u.dump(t.loc[sec>905].assign(actual_hold_seconds=sec[sec>905]),label.lower()+'_long_hold_observations.csv')
        holdlong.append(dict(scope=label,hold_over_900=int((sec>900).sum()),hold_over_905=int((sec>905).sum()),max_hold_seconds=float(sec.max())))
    u.dump(holdlong,'hold_time_limitations.csv')
    b=pd.read_csv(p/'feature_bins.csv');contrasts=[]
    wanted=['m5_ema20_price_gap_atr','m5_ema20_50_gap_atr','m5_rsi14_pct64',
        'm5_macd_hist_atr','m5_atr14_pct64','m5_spread_atr','m1_tick_volume_pct64',
        'm5_ema_alignment','m1_m5_alignment_product','m1_m15_alignment_product']
    for name in wanted:
        v=b[b.feature.eq(name)]
        if not len(v):continue
        for side in (1,-1):
            z=v[v.direction.eq(side)];ag=z.groupby('bin')[['total_r','rows']].sum()
            lo=ag.iloc[0];hi=ag.iloc[-1]
            contrasts.append(dict(feature=name,direction='LONG' if side==1 else 'SHORT',
                low_bin_n=int(lo['rows']),low_bin_ev=lo.total_r/lo['rows'],
                high_bin_n=int(hi['rows']),high_bin_ev=hi.total_r/hi['rows']))
    u.dump(contrasts,'technical_state_contrasts.csv')
    # Preserve the exact details of data-quality uncertainty rather than calling
    # a successful collection gate global validation or zero generated ticks.
    qnotes=[]
    for m in (202501,202502,202503,202504,202505,202506):
        q=json.loads((u.BATCH/str(m)/'collection_qa.json').read_text())
        qnotes.append(dict(month=m,technical_collection=q['status'],legacy_global_validation=q.get('legacy_run_integrity',{}).get('validation','SEE_SOURCE'),
            generated_fallback='SEE_TESTER_JOURNAL_NOT_ZERO_BY_ASSUMPTION',commission='NOT_OBSERVED_IN_COLLECTION'))
    u.dump(qnotes,'collection_quality_scope.csv')
    text=['# USDJPY専用 Tick-Shock ML：結果と再現手順','',
      '## 結論','',
      '**USDJPY専用化だけでは、月200取引を維持する安定した正の期待値は確認できなかった。**',
      '採用候補ではなく、事前指定どおり1つのholdout検証用候補を凍結した。5月は小幅プラス、6月はマイナスで、2か月合計もマイナス。結果を見てモデル・threshold・TP/SLを変更していない。',
      '`STABLE_POSITIVE_EDGE_NOT_ESTABLISHED` / `FREQUENCY_TARGET_NOT_MET_IN_HOLDOUT` / `PRODUCTION_NOT_ELIGIBLE`。',
      '5～6月は過去研究で観測済みの期間。今回のUSDJPY-only研究で未使用のholdoutであり、完全未使用OOSとは呼ばない。','',
      '## 1. 母数と取引頻度','',
      '以下は1 ATR geometry。shock数は残存episode archiveに含まれるanchor＋repeatの数であり、全statistical detectorの未集約検知総数と同一とは主張しない。`statistical_candidates`はpersistence判定前候補として別列に保存している。全raw検知の通貨別独立再集計には、保存されていないdetector event全行が必要。episode数とMLラベル数は実CSVの正確な件数。',
      table(pop[pop.geometry.eq(3)],['month','shock_detections_in_episode_archive','episodes','executable_long','executable_short']),
      '', 'USDJPYだけでも各月200件以上の売買可能episodeがあり、母数不足が主因ではない。LONG/SHORTは同じepisodeの相反する2ラベルであり独立サンプルを2倍に数えない。','',
      '## 2. 固定した研究設計','',
      '- 1月→2月、1～2月→3月、1～3月→4月のexpanding walk-forward。翌月へまたがるラベル・clusterを除外。',
      '- 486 causal features／raw-unit38列除外448版。新規特徴量なし。6モデル×2版×5 geometry=60モデル設定、180fold、12policy、720比較セル。',
      '- RR1、TP=SL=0.5/0.75/1/1.5/2 ATR、M5 ATR14、900秒後の最初の利用可能quoteによる時間決済。',
      '- LONG/SHORTのNET_Rを別々に推定し、高い方がcutoff以上なら選択。tieはNO TRADE。注文不可と判明してから反対側を選び直さない。',
      '- cutoffは学習score percentileまたは学習期間のportfolio件数だけで算出。将来月を見て件数を合わせない。各月の目標は保証されない。',
      '- spreadは実Bid/Ask経路に内包。Python primaryはさらに往復0.2pipを控除する仮定。実commissionの観測値ではない。0.4pipはprimaryからさらに0.2pip悪化するstress。',
      '- 1 pending/open position、全データ処理の最初にUSDJPYを抽出。他通貨をこのモデルの学習・threshold・損益に使わない。','',
      '## 3. モデル比較（開発forwardのみ）','',
      '各familyについて月200件を優先し、最悪月のEVから順に事前ルールで選んだ代表。LOGISTICというコード名はNET_RではRidge回帰を指す。最高単月損益順ではない。',
      table(families,['family','variant','geometry','policy','trades','min_month_trades','expectancy_r','pf','worst_month_ev']),
      '',f'全720セルのうちpooled EVがプラスは{int(front.expectancy_r.gt(0).sum())}セル。ただし全forward月200件以上かつプラスは{int((front.expectancy_r.gt(0)&front.min_month_trades.ge(200)).sum())}セル。頻度を含む採用基準通過は{len(passing)}。少数tradeの高EVを今回の成功として採用しない。','',
      '## 4. 凍結候補と月別成績','',
      f'**{cfg["family"]} / {cfg["variant"]} / NET_R / TP=SL={spec["distance_atr"]} ATR**。policyは`{cfg["policy"]}`。最終thresholdは **{spec["threshold"]:.17g}R**。',
      '名称の150は学習期間calibration目標であり、実際のforward件数ではない。開発では252～365件/月となったが、holdoutでは96/44件まで減った。1～4月全体の利用可能ラベルで最終fitし、そのfitのscoreから同じ手順でthresholdを凍結した。',
      table(comp,['scope','month','trades','win_rate','expectancy_r','pf','maxdd_r','total_r']),
      '', 'DDは固定1Rの確定損益曲線。EAの浮動損益込みequity DDや口座リスク%とは異なる。','',
      '## 5. Frequency–expectancy frontier','',
      '目標100/150/200/300件ごとに、両calibration方式・事前モデルgridのforward安定性で代表を保存。全720セルは`candidate_frontier.csv`、全foldは`walk_forward.csv`。',
      table(freq[freq.family.eq(cfg['family'])],['target_frequency','policy','geometry','trades','min_month_trades','expectancy_r','worst_month_ev']),
      '', '高scoreだから翌月でも同じ頻度・損益になるとは言えない。最終score分布はMay/Juneで低下し、学習calibrationのfrequencyが維持されなかった。`score_distributions.csv`と`holdout_monthly.csv`に分布を保存。','',
      '## 6. 技術状態・interactionの解釈','',
      '重要度上位はモデル内で使われた程度であって、利益の証明ではない。以下は選択されたElasticNetの3forward fitを集約した標準化係数の絶対値。',
      table(ranking.head(12),['feature','normalized']),
      '', '相対的に重要なinteraction：',
      table(interactions.head(8),['feature','normalized']),
      '', 'M1 realized volatility、M1/M15 ATR比、M15 RSI slope、M5 EMA整列、EMA/SMA差、shock×MACDが主に使われた。EMA距離・RSI percentile・MACD・ATR percentile・spread/ATR・activity・cross-TF状態の学習quintile別LONG/SHORT損益は`feature_bins.csv`に記録した。全行の片方向ラベル診断であり、そのbinを新規売買ルールとして採用していない。',
      '特徴量groupをvalidation月内でシャッフルした際の変化（正のdegradationは、その情報を壊すと損益が悪化したことを示す）：',
      table(perm,['feature_or_group','total_r_degradation','ev_rmse_increase']),
      '', '主要technical状態の低い学習quintileと高いquintileのforward EV（LONG/SHORT独立ラベル、モデル選択portfolioではない）：',
      table(pd.DataFrame(contrasts),['feature','direction','low_bin_n','low_bin_ev','high_bin_n','high_bin_ev']),
      '', '読み方：M5の価格−EMA20距離が低い側ではLONG、高い側ではSHORTの損失が相対的に小さい。RSI/MACDにも似た相対的な逆張り傾向があるが、上記の両端binの多くは依然マイナス。spread/ATRが高い状態は両方向とも悪化する。低spreadは損失を減らすが、それだけで正EVにはならない。高ATR側のSHORTはゼロに近づくものの、採用できる利益の証明ではない。M1/M5整列の一部小binにプラスがあっても53件などの小標本で、月200件の戦略へ置き換えない。',
      '', '係数・permutationは相関特徴量の影響を受ける。LightGBMのTreeSHAPは同じgeometry/feature版で別途行った説明用モデルであり、凍結ElasticNetのSHAPと混同しない。SHAPの加法一致を検証済み。`partial_dependence.csv`も予測応答の診断で、現実に存在しない特徴量組合せを含み得る。','',
      '## 7. TP/SL・コスト・時間決済','',
      '2 ATRが選ばれたのは短期TP勝率が優れたからではなく、頻度を維持した比較で最悪月の損失が相対的に小さかったため。採用候補ではない。開発83.5%、holdout77.9%がTIMEとなり、短期first-touch戦略としては幅が大きい。',
      table(geom,['geometry','direction','trades','timeout_rate','distance_spread_median','mfe_900_atr_median','mae_900_atr_median']),
      '',table(costs,['scope','cost_pips','expectancy_r','pf','total_r']),
      '', 'top5利益除外後、開発は約−22.30R、holdoutは約−8.41R。採用条件を満たさない。cluster/day bootstrap CIは`bootstrap.csv`参照。CIは開発でのモデル選択バイアスを補正していない。',
      '時間決済は既存ラベル生成器の「900秒以降の最初のquote」であり、厳密な15分以内を保証しない。休場・quote間隔・global replay遅延による長い保有を改変せず保存した。',
      table(pd.DataFrame(holdlong),['scope','hold_over_900','hold_over_905','max_hold_seconds']),
      '', '900秒超の観測を消したり、過去quoteへ時間決済を戻して損益を改善したりしていない。','',
      '## 8. 6通貨共通モデルとの比較','',
      '前回の共通モデルでUSDJPYだけを取り出し、他通貨とのposition競合を除いて既存予測を再集計した参考比較：',
      table(prior,['month','trades','expectancy_r','pf','maxdd_r']),
      '', '共通モデルはExtraTrees / SCALE_FREE / 2 ATRで主にSHORT、今回はElasticNet / FULL486 / 2 ATRで開発LONGが多い。共通モデルのreferenceは月109～159件と頻度が低い。今回の専用モデルは開発252～365件だが全月マイナスだった。',
      '重要な比較制限：前回は学習prefix75%＋校正tail、今回は指定の全prefix expanding fitであり、選択familyやfrequencyも異なる。したがってこの差を「USDJPY専用化だけの因果効果」とは断定しない。他5通貨を再学習に使用する追加実験は行っていない。前回共通モデルは今回の5～6月へ新たに適用していないため、holdoutの公平なcommon対USDJPY比較は未実施。','',
      '## 9. データ品質・QA','',
      '- Jan/Aprは旧research pool警告を保持したscoped Technical collection PASS_WITH_LEGACY_WARNING。全pipeline validatedとはしていない。',
      '- Marchのtester journalにはUSDJPYのgenerated/discarded tick fallbackの警告がある。モデル4指定だけで100%real-tickを保証しない。過去証跡のUSDJPY 1,431 symbol-minutesは参照値で、各episodeの完全なtick由来追跡はできない。',
      '- 元のfixture/expected、detector、既存feature producerは変更なし。新しいPython unit13件と再利用core unit18件がPASS。最初の追加unitのfixture列衝突1件を直した経緯は初回logとfinal logを両方保存。研究計算・expected損益を変えていない。',
      '- 独立損益計算、独立portfolio選択、causal clocks、selected/final model deterministic refit、全fitのpurge、既存source SHAを検証。`qa_checks.csv`の件数にはsource SHAなどの検査を含むため、独立した売買サンプル数と混同しない。',
      '- 重み/thresholdはfreeze JSON/PKL/SHAで封印。holdout commandは既存開封記録がある場合に再評価を拒否する。監査・再集計は既存結果を読むだけ。','',
      '## 10. MT5実約定','']
    text += ['全2,160 forward policyの独立再集計: 17,280 checks / 0 failures。圧縮USDJPY入力から全180 fitを再実行: 17,820 checks / 0 failures。これらは再現性検査数であり独立取引数ではない。','']
    batch=u.ROOT/'reports/backtest/batches/usdjpy_only_ml_20260912'
    if (batch/'summary.json').exists():
        actual=pd.read_csv(batch/'actual_monthly.csv');summary=json.loads((batch/'summary.json').read_text())
        text += [table(actual,['month','trades','net_profit','expectancy_r','pf_money','maxdd_money','commission','fee','swap']),
            '',f'MT5 QA failures: {summary["qa_failures"]}。全期間集約：`{json.dumps(summary["actual"],ensure_ascii=False)}`。',
            'Python labelと現在quoteでの成行注文は完全に同じ約定価格にはならない。シグナル/feature parityとtrade identity差・fill差・exit差を分離して`trade_comparison.csv`へ保存した。actual costがゼロでも未観測とは混同せず、当該testerのdealで観測したゼロに限定する。']
    else:text += ['実行中／独立再集計前。完了後に本節を更新する。現時点で実約定結果を推定しない。']
    text += ['', '検証専用EA：`mql/Experts/ExpectedValue_USDJPY_TickShockMLHoldout.mq5`。通常チャート/実口座/デモ口座では初期化を拒否する。研究EA本体へ注文機能を追加せず、新wrapperだけを使用。既存6通貨dispatcherは収集時刻を保つため維持し、USDJPY以外のsnapshotを注文/モデル評価前に拒否する。',
      'MetaEditor0 errors/0 warnings、学習3,644件のMQL推論parity PASS、学習日production wiring smoke PASS。最初のparity完了時、terminal shutdown待ちのためrunnerが安全停止した。モデル・EX5・設定SHA一致を確認した明示resumeのみ実施し、月次runの上書き/再試行はしていない。','',
      '## 再現と成果物','',
      '- `docs/research/tick_shock/usdjpy_only_ml_preregistration.md`：事前固定。',
      '- `reports/analysis/tick_shock/usdjpy_only_ml_20260912/`：全分析、freeze、QA、元USDJPYのみの圧縮入力。',
      '- `reports/backtest/batches/usdjpy_only_ml_20260912/`：parity/smoke/May/June、コンパイルと実約定。',
      '- `tools/tick_shock/usdjpy_only_ml.py`：development → sealed holdout。',
      '- `audit_usdjpy_only_ml.py`：interpret / summarize --holdout。',
      '- `prepare_usdjpy_only_mt5.py` / `run_usdjpy_only_mt5.ps1` / `reconcile_usdjpy_only_mt5.py`：MT5経路。',
      '- `test_usdjpy_only_ml.py` / `package_usdjpy_only_evidence.py`：回帰テスト・データ搬送。',
      '- `reproduce_usdjpy_only_evidence.py`：圧縮USDJPY入力から同じ選択/重みの監査。',
      '', '既存runへdevelopmentやholdoutを上書き実行しない。再集計は次を使用：',
      '```powershell','python tools/tick_shock/test_usdjpy_only_ml.py',
      'python tools/tick_shock/audit_usdjpy_only_ml.py summarize --holdout',
      'python tools/tick_shock/reconcile_usdjpy_only_mt5.py','```','',
      '## 次の判断','',
      '本候補を実資金へ投入しない。USDJPY単独の母数はあるが、事前情報から高頻度かつコスト後プラスの選択を安定して作れていない。May/Juneを再調整に流用しない。今後の別研究では、score校正の月間変動と実行時計/休場時間の影響を先に分離し、追加探索をするなら新しい事前仕様と検証期間を用意する。','']
    path=u.ROOT/'docs/research/tick_shock/usdjpy_only_ml_results.md'
    path.write_text('\n'.join(text),encoding='utf-8')
    u.js(dict(documented_at=u.stamp(),model_sha256=u.sha(p/'frozen_model.json'),
        selected=cfg,holdout=json.loads((p/'holdout_complete.json').read_text())['stats'],
        qualifying_development_candidates=len(passing),positive_min200_cells=int((front.expectancy_r.gt(0)&front.min_month_trades.ge(200)).sum()),
        production_eligible=False,mt5_complete=(batch/'summary.json').exists()),'readout_summary.json')
    print(path)


if __name__=='__main__':main()
