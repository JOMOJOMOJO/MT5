"""Document training-only evidence, data quality and coefficient interpretation."""
import json
import platform
import re
from pathlib import Path
import numpy as np
import pandas as pd
import sklearn
import lightgbm
from analyze_technical_4m2m_real import ROOT, BATCH, OUT, sha
import analyze_technical_discovery as core


def main():
    model=json.loads((OUT/'frozen_model.json').read_text())
    freeze=json.loads((OUT/'freeze_record.json').read_text())
    coeff=[]
    for side in ('long','short'):
        m=model['models'][side]
        if 'coefficient' not in m:continue
        for name,c,mean,scale,median in zip(model['features'],m['coefficient'],m['mean'],m['scale'],m['median']):
            coeff.append(dict(direction=side,feature=name,standardized_logit_coefficient=c,
                              training_mean=mean,training_scale=scale,training_median=median,
                              interpretation='conditional model weight; correlated features, not a causal effect'))
    core.dump_csv(coeff,OUT/'selected_signed_coefficients.csv')
    quality=[];fallback_days=[]
    symbols=('EURUSD','GBPUSD','USDJPY','AUDUSD','USDCAD','USDCHF')
    for month in ('202501','202502','202503','202504','202505','202506'):
        qa=json.loads((BATCH/month/'collection_qa.json').read_text())
        text=(BATCH/month/'tester_journal_excerpt.txt').read_text(encoding='utf-8')
        for symbol in symbols:
            found=re.findall(r'\b'+symbol+r'\s*:\s*(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2})\s*-\s*(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2})\s+real ticks discarded for (\d+) minutes of (\d+) total minute bars',text)
            d=dict(month=month,symbol=symbol,collection_qa=qa['status'],commission='NOT_OBSERVED_IN_COLLECTION',
                   fallback_status='OBSERVED' if found else 'NO_DISCARD_MESSAGE_IN_EXCERPT_NOT_PROOF_OF_ZERO',
                   evidence=str((BATCH/month/'tester_journal_excerpt.txt').relative_to(ROOT)))
            if found:
                assert len(found)==1
                start,end,discarded,total=found[0]
                d.update(fallback_minutes=int(discarded),total_minute_bars=int(total),fraction=int(discarded)/int(total))
            quality.append(d)
            for day,count,total in re.findall(r'\b'+symbol+r'\s*:\s*(\d{4}\.\d{2}\.\d{2}) \d{2}:\d{2}\s*- real ticks discarded for (\d+) minutes out of (\d+)',text):
                fallback_days.append(dict(month=month,symbol=symbol,day=day,discarded_minutes=int(count),total_minutes=int(total)))
    core.dump_csv(quality,OUT/'collection_tick_quality.csv')
    core.dump_csv(fallback_days,OUT/'observed_fallback_days.csv')
    # Quantify training label population potentially affected; never delete rows after seeing results.
    affected=[]
    for month in ('202501','202502','202503','202504'):
        f=core.csv(BATCH/month/'technical_features.csv')
        own={(d['symbol'],d['day']) for d in fallback_days if d['month']==month}
        anyday={d['day'] for d in fallback_days if d['month']==month}
        dates=pd.to_datetime(f.t0_msc,unit='ms').dt.strftime('%Y.%m.%d')
        affected.append(dict(month=month,episodes=len(f),target_symbol_discard_day_episodes=sum((s,d) in own for s,d in zip(f.symbol,dates)),
                             any_symbol_discard_day_episodes=int(dates.isin(anyday).sum()),
                             note='Day-level exposure proxy; not tick-level provenance. Completed bars may carry effects across days. No rows excluded.'))
    core.dump_csv(affected,OUT/'training_fallback_exposure.csv')
    # Geometry evidence, both directions reported rather than hindsight best side.
    diag=pd.read_csv(OUT/'path_geometry_diagnostics.csv')
    geom=diag[diag.distance_index==model['distance_index']]
    core.dump_csv(geom,OUT/'selected_geometry_diagnostics.csv')
    core.write_json(dict(python=platform.python_version(),numpy=np.__version__,pandas=pd.__version__,
                         sklearn=sklearn.__version__,lightgbm=lightgbm.__version__,
                         seed=core.SEED,model_sha256=sha(OUT/'frozen_model.json')),
                    OUT/'environment.json')
    text='''# 1～4月の学習結果と、固定EAの意味

## 学習と評価を分離した

1～4月の11,230エピソード、486特徴量を使った。単月に当てはめた利益ではなく、
1～2月学習→3月評価、1～3月学習→4月評価で候補を比較した。
3モデル × 6距離 × 6しきい値＝108候補。5～6月は候補選定に使っていない。
全モデルの条件別成績は `inner_validation.csv` と `selection_frontier.csv`。

## 結論：条件をすべて満たす候補は0

月200取引、両月正の期待値、利益の集中が小さい、隣接しきい値でも正という
事前条件を同時に満たさなかった。これは今回の固定探索の結果であり、
すべてのテクニカル戦略に期待値がないという証明ではない。

依頼されたEA実験のため、事前登録の診断候補選定規則に従い、
`g5_ELASTICNET_LOGISTIC_0.1` を1つだけ固定した。採用合格ではない。
3月237取引 +0.02009R/取引、4月352取引 +0.001821R/取引。
Bid/Askスプレッド込みに追加0.2pip往復ストレスを加えた値で、実commissionとは別。
上位5利益を除くと両月ともマイナス、4月の利益集中も大きく、隣接領域の裏付けが弱い。

## 最終EAに組み込んだもの

- LONG/SHORT別の正則化ロジスティック回帰。陽性はコスト後R>0。
- 学習期間の平均勝ちR・平均負けRから各方向の期待Rへ変換する。
- 期待Rの高い方向が0.1R以上ならエントリー。同点・しきい値未満はNO TRADE。
- TP＝SL＝t0で利用可能な確定M5 ATR14の2倍をtick sizeへ外側丸め。
- 3スプレッド未満・broker距離不適合・最小lot超過リスク等は見送る。
- 最大保有15分、全通貨1ポジション、最大リスク10 USDかequityの0.25%の小さい方。
- Strategy Tester限定。通常チャート・実口座・デモチャートでは初期化失敗。

距離は到達経路を含む6距離の同一ルールで比較して選んだもので、後から広げたのではない。
ただし2ATR/15分は時間決済が多数であり、理想的なgeometryだと主張しない。
距離/スプレッド・MFE/MAE・到達時間は `selected_geometry_diagnostics.csv` を参照。

## 何がモデルに使われたか

大きな標準化係数はM5 EMA5の価格乖離・傾き、M15 SMA10/SMA50傾き、
M5 RSI21変化、M1×M15 RSI/trend、実現ボラ、M15 +DIなど。
全係数の方向・符号・学習時正規化値は `selected_signed_coefficients.csv`。
相関の強い特徴量が多いので、個々の係数を独立した利益要因・因果効果とは解釈しない。

## 再学習時の重大な制約

同じハイパーパラメータで1～4月全体へ再学習すると、固定0.1Rしきい値の取引数は
1月48、2月28、3月46、4月77件（合計199）に減った。
したがって最終固定EAは月200件の目的を満たさない。学習窓に対する予測スコアの
安定性が不十分である。これを隠して内側検証の237/352件をEAの頻度と呼ばない。
5～6月に合わせたしきい値変更や別候補への交換はしない。

## データ品質と再現性

月別RunIdでepisode/clusterを名前空間化し、先の月へ達する学習ラベルをpurgeした。
January/April旧scenario pool警告は元のVALIDATION_INVALIDを保持。
独立Technical収集QAだけが合格したことを区別する。
2月USDCHFは1,306分、3月は6通貨合計8,559 symbol-minutesのdiscardがjournalにある。
生成置換がないと断言しない。日単位の影響件数は `training_fallback_exposure.csv`。
データを結果に応じて除外・置換していない。

元のユーザー削除includeは戻さず、収集に使ったsource ZIPを私有の依存ツリーへ展開。
モデル以外の研究ロジックと既存注文adapterをコピーして使用した。
EAは重い研究observerを引き続き含み、今回高速化は行っていない。

最終MT5成績・モデル一致・実commissionは最終結果資料に分離して記録する。
'''
    target=ROOT/'docs/research/tick_shock/technical_4m2m_learning_results.md'
    target.write_text(text,encoding='utf-8')
    print(target)


if __name__=='__main__':main()
