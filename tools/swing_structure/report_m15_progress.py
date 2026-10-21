"""Render descriptive research results without fitting thresholds."""
from pathlib import Path
import pandas as pd
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from analyze_m15_progress import OUT,STATES

def table(d):
    def fmt(x):
        if pd.isna(x):return '—'
        if isinstance(x,(float,np.floating)):return f'{x:.3f}'
        return str(x)
    lines=['| '+' | '.join(map(str,d.columns))+' |','| '+' | '.join(['---']*len(d.columns))+' |']
    return '\n'.join(lines+['| '+' | '.join(fmt(x) for x in row)+' |' for row in d.itertuples(index=False,name=None)])

def main():
    c=pd.read_csv(OUT/'candidates_with_progress.csv');s=pd.read_csv(OUT/'state_statistics.csv')
    old=pd.read_csv(OUT/'previous_down_28_diagnostics.csv');month=pd.read_csv(OUT/'monthly_counts.csv')
    names={'known_close_2025h1':'2025年1〜6月','holdout_close_2024q3':'2024年7〜9月'}
    parts=['''# M15進行状態の再分類・DOWN28候補の診断

## 結論

**前回DOWN群には、Entry後まもなくM15転換に進むケースが含まれていた。だが、その事実だけでEntry時点から見分けられるとは言えない。**

- 前回DOWN28件のうち、H0を終値突破したものは30分以内7件、60分以内9件、120分以内14件（50%）。H0はEntry時点で固定し、将来突破は診断ラベルとしてのみ利用した。
- 事前の小さな反転兆候でDOWN_WEAKENINGとなった旧DOWN15件は、120分以内突破9件（60%）。DOWN_CONTINUINGの11件は5件（45.5%）。差はあるが小標本で、期間別に順位が逆転するため安定した識別力の証明にはならない。
- 新W3_CANDIDATEは11件（2025年8、2024年3）。旧UNKNOWNだった7件が含まれ、確定pivot待ちでは表現できなかった進行状態を拾えた。
- UNKNOWNは76/119件（63.9%）から54/119件（45.4%）へ減った。ただしラベルが付いたことと、正しく初動を予測できたことは別。
- 条件採用・最適化なし。売買EA、Shared、Entry、SL、TP、各候補の損益は変更していない。

## 1. 固定した対象と分類の意味

前回の119候補・476個のRR別損益をそのまま再注釈した。M1/M5設定、CHoCH入口、親起点SL、RR1/1.2/1.5/2は同一。今回は保存済みMT5の確定M15 OHLCを因果順に再生したPython研究であり、新しいEAや注文処理は作っていない。

分類ルールは集計前の [plan.md](plan.md) に固定。EMA/ATR等の数値閾値を探して分類したのではない。

| 状態 | Entry時点での機械的な意味 |
|---|---|
| DOWN_CONTINUING | 最新2高値・2安値が下降、H0終値突破なし、小反転兆候なし |
| DOWN_WEAKENING | 下降構造は残るが、確定M15終値が直前足の高値を突破した兆候が残る。兆候足と直前足の安値の小さい方を終値で割れば解除 |
| W1_ACTIVE | 確定終値でH0突破後。Wave1高値pivot確定を待たず最高値を追跡 |
| W2_PULLBACK_ACTIVE | W1中に最初の終値低下が発生。直前までの最高値を固定し、起点を割らず押している |
| W3_CANDIDATE | W2状態で、既存M5転換済み＋押し開始以降のM1 CHoCHがEntry時点に利用可能 |
| W3_CONFIRMED | 押し開始後に固定Wave1上端をM15終値で突破。親HL確定は待たない |
| UNKNOWN | 上記以外、または構造否定 |

W3_CANDIDATEは候補時点の重ね合わせラベルであり、M15全足の基底状態はW2のまま。今回W2基底に属した11候補すべてがM5/M1条件を満たしたため、最終ラベルのW2は0件となった。W1も最初の終値低下までの短い区間なので1件だけだった。これは欠落データではない。

新W3_CONFIRMEDは起点／突破後の保護安値が終値で割れるまで続き、最初の高値pivot確定だけでは終了しない。そのため旧DOWN2件も新W3_CONFIRMEDに入った。異なる起点・スケールの状態が重なり得るため、これらをDOWN_WEAKENINGへ恣意的に振り替えなかった。このラベルは「いま初動にいる」と保証しない。状態開始からEntryまでの経過分も保存した。

## 2. 各状態の固定RR期待値

候補全体の価格R。実行制約で選別した成績ではない。4RRは同じ候補に対する4つの仮想出口であり、4取引ではない。
''']
    for run,label in names.items():
        q=s[s.run==run];v=q.pivot(index='state',columns='rr',values='expectancy_r').reindex(STATES+['ALL'])
        v.columns=[f'RR{x:g} 平均R' for x in v.columns]
        v.insert(0,'n',q[q.rr==1.2].set_index('state')['count']);v=v.reset_index()
        parts+=['### '+label,table(v)]
    parts+=['''W3_CANDIDATEのRR1.2平均Rは2025年+0.075R、2024年+1.200R。一方W3_CONFIRMEDは−0.304R／−0.134R。ただし候補集合が違う観察比較であり、「同じ試行で待つと悪化する」という因果比較ではない。旧研究の成績や出口を変更した結果でもない。

注意点として、W3_CANDIDATEの押し開始からEntryまでは中央値200分、最長3249.5分（週末を含む）。W3_CONFIRMEDも突破から中央値183分、最長558分経過している。したがって新ラベルでも「全てが初動直近」とは言えない。時間で除外して成績を良く見せず、そのまま残して経過時間を診断列にした。

## 3. MFE/MAEと到達率

TPを置かずSLまたは24時間まで観測した平均MFE/MAEと到達率（0〜1）を示す。RR別決済までのMFE/MAE、勝率、PFもCSVへ保存した。
''']
    for run,label in names.items():
        q=s[(s.run==run)&(s.rr==1.2)][['state','count','mean_mfe_24h','mean_mae_24h','reach_1.0r','reach_1.2r','reach_1.5r','reach_2.0r']]
        parts+=['### '+label,table(q)]
    parts+=['## 4. 月別候補数',table(month[month.state!='ALL'].pivot(index='month',columns='state',values='count').reindex(columns=STATES).reset_index()),
    '''今回は分類だけなので総候補数は増えていない。実行可能数も前回の月6〜17回から変わらず、月20回目標を解決したわけではない。

## 5. 前回DOWN28件：転換初動は含まれていたか

| 期間 | n | 30分以内H0突破 | 60分以内 | 120分以内 |
|---|---:|---:|---:|---:|
| 2025年1〜6月 | 17 | 4 | 5 | 9 |
| 2024年7〜9月 | 11 | 3 | 4 | 5 |
| 合計 | 28 | 7 | 9 | 14 |

120分以内の突破がなかった14件を「下降継続の成功」とは呼ばない。遅れて突破する場合もあり、今回の問いに対して120分以内ではなかったという意味である。

| 旧DOWNの新状態 | n | 30分以内 | 60分以内 | 120分以内 |
|---|---:|---:|---:|---:|
| DOWN_CONTINUING | 11 | 2 | 3 | 5 |
| DOWN_WEAKENING | 15 | 5 | 6 | 9 |
| W3_CONFIRMED | 2 | 0 | 0 | 0 |

期間別には、2025年の120分突破率はWEAKENING 5/9、CONTINUING 4/6。2024年は4/6対1/5。優劣の順序は一致しない。旧DOWN内のWEAKENINGのRR1.2平均Rは+0.458R／+0.463Rだったが、分類の価格的意味があるかを次のデータで確認する必要がある。

M5転換済みは28/28件。この研究母集団が元々M5転換後の候補なので、M5転換済みという特徴だけで勝ち負けを区別できない。M5転換の利用可能時刻も個票に保存した。

### Entry前特徴と未来120分突破の比較

未来ラベル別の中央値。これは結果の説明用であり、その未来ラベルをEntry条件に使用できない。
''']
    f=pd.read_csv(OUT/'previous_down_features_by_future_label.csv')
    selected=f[f.feature.isin(['h0_distance_r','latest_low_extension_atr','ema20_slope_atr','down_speed_atr_per_bar'])]
    parts+=[table(selected[['run','future_h0_break_120m','feature','n','median']]),
    '''H0までの距離は両期間とも120分以内突破群の方が近かった。EMA傾きと下降速度の方向は期間間で揃っていない。近いH0ほど早く到達しやすいという幾何学的な関係と、取引の正期待値は分けて扱う。閾値は選んでいない。

## 6. 個票の定義

- `previous_down_28_diagnostics.csv`：旧DOWN28件、Entry/SL、旧H0価格・bar/confirmed時刻、距離R、H0最初の終値突破時刻／分数、30/60/120分ラベル、安値更新幅、EMA/ATR/速度、M5転換時刻、H1/H4抵抗距離。
- `latest_low_extension_price` は前回の確定安値−最新の確定安値（下降更新幅は正）。`latest_low_extension_atr` はATR14正規化。未確定のヒゲ安値を先取りしない。
- EMA20は確定M15終値のEMA、傾きは1本前との差。ATR14はTrue RangeのWilder平滑。初期値は14本平均。十分なwarmupを含む。
- `down_speed_atr_per_bar = (3本前終値−最新終値)/(3×ATR14)`。正なら下降、負なら上昇。価格/分の符号付き速度も保存。
- 将来H0突破は保存データ終了までの初回。所要時間の中央値には数時間〜数日後の突破も含み得る。30/60/120分のラベルと混同しない。経過時間は週末を含むサーバー時刻差。
- H1/H4通常2/2高値、主要5/5高値の距離Rは前回のEntry時点データをそのまま利用。見つからない場合は欠損。
- `base_state`と`state`を分け、候補時点のW3_CANDIDATE重ね合わせを明示。`*_age_minutes`は状態の古さを診断する連続値で、フィルターには使わない。

## 7. QA・限界

- 119候補・476結果のEntry/SL/TP/Entry tick/exit tick/損益が元CSVと完全一致。元EA/Shared不変は別hash監査へ記録。
- 前方に切断した再生と、未来OHLCを変更した再生で、それ以前の状態・特徴量が変わらないことを確認。分類の2回再生も一致。
- H0突破、押し開始、W3突破の終値・時刻順序を検査。全使用pivotのconfirmed時刻<=Entry。
- 未来ラベルは分類処理とは別関数で後付け。旧DOWN28件のH0は旧分類の戻り高値から復元し、新分類の任意の高値とすり替えていない。
- 保存されたMT5出力の再分析であり、今回Python分類のMQL5実装・コンパイル・新規テスター実行はしていない。
- 新分類は提案された進行状態の一つの機械的定義。W2開始を1本の終値低下としたため小さな押しも含み、W3_CONFIRMEDは長く続くことがある。動画の裁量波と一致する保証はない。
- 2024年Q3は実ティック破棄・生成ティック置換が多い。該当Entry日フラグを引き継いだ。W3_CANDIDATE3件のうち1件は警告日に属する。両期間とも既知データでありOOSではない。
- R損益はスプレッドを含むが、手数料・swap・滑り・証拠金等を含まない。小標本・同じ親構造による依存がある。好結果の状態だけを選ぶ段階ではない。

## 次の判断

**「旧DOWNに転換初動が混在していた」は今回の診断と整合する。一方、事前のDOWN_WEAKENINGが安定してその初動を予測できるかは未確認。** W3_CANDIDATEは確定待ち前の状態を表すためのラベルとして残す価値があるが、売買条件にはまだ採用しない。

次に進む場合も、この定義を維持した別データでの診断を優先する。今回の結果を見てEMAや速度の閾値を調整しない。状態の古さと旧新の不一致を個別チャートで確認することも、閾値探索より先のQA課題になる。

## 成果物

- [全候補](candidates_with_progress.csv) / [固定RR結果](fixed_rr_outcomes.csv)
- [旧DOWN28件の個票](previous_down_28_diagnostics.csv) / [H0突破集計](previous_down_break_statistics.csv)
- [状態別統計](state_statistics.csv) / [月別件数](monthly_counts.csv) / [旧→新の対応](old_vs_new_states.csv)
- [旧DOWN内の状態別損益](previous_down_state_statistics.csv) / [未来ラベル別特徴](previous_down_features_by_future_label.csv)
- [監査](audit.json) / [旧H0復元監査](legacy_h0_audit.json) / [本番不変](production_unchanged.json) / [元データhash](source_hashes.json) / [H0距離と未来突破の図](down_h0_diagnostics.png)

再集計：`python tools/swing_structure/analyze_m15_progress.py`、報告生成：`python tools/swing_structure/report_m15_progress.py`。
''']
    (OUT/'summary.md').write_text('\n\n'.join(parts),encoding='utf-8')
    fig,axes=plt.subplots(1,2,figsize=(12,4),layout='constrained')
    for ax,(run,label) in zip(axes,names.items()):
        q=old[old.run==run]
        for state,color in [('DOWN_CONTINUING','red'),('DOWN_WEAKENING','orange'),('W3_CONFIRMED','green')]:
            v=q[q.state==state];hit=v.h0_break_minutes.le(120)
            ax.scatter(v.h0_distance_r,np.where(hit,v.h0_break_minutes,135),color=color,label=state,alpha=.8)
        ax.axhline(120,color='gray',ls='--');ax.set(title=run,xlabel='Entry to frozen H0 (R)',ylabel='Minutes to close break (135 = no break within 120m)')
    axes[0].legend(fontsize=8);fig.savefig(OUT/'down_h0_diagnostics.png',dpi=140);plt.close(fig)

if __name__=='__main__':main()
