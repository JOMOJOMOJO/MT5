"""Fixed RR-choice research report; no threshold selection."""
from pathlib import Path
import json
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

def table(x):
    def fmt(v):
        if pd.isna(v):return '—'
        return f'{v:.3f}' if isinstance(v,(float,np.floating)) else str(v)
    return '\n'.join(['| '+' | '.join(x.columns)+' |','| '+' | '.join(['---']*len(x.columns))+' |']+
                     ['| '+' | '.join(fmt(v) for v in row)+' |' for row in x.itertuples(index=False,name=None)])

def perf(v):
    v=pd.Series(v).dropna();loss=-v[v<0].sum()
    return dict(scored=len(v),mean_r=v.mean(),pf=v[v>0].sum()/loss if loss>0 else np.nan,win_rate=(v>0).mean() if len(v) else np.nan)

def main(out):
    out=Path(out);x=pd.read_csv(out/'candidates.csv');p=pd.read_csv(out/'predictions.csv');ledger=pd.read_csv(out/'execution_ledger.csv')
    monthly=pd.read_csv(out/'monthly_execution.csv');annual=pd.read_csv(out/'execution_statistics.csv');metrics=pd.read_csv(out/'annual_metrics.csv')
    boot=pd.read_csv(out/'month_bootstrap.csv');qa=json.loads((out/'dataset_audit.json').read_text())
    eligible=x[x.paired_eligible];allpairs=[];classes=[]
    names={0:'SL_BEFORE_1R',1:'1R_THEN_SL_BEFORE_1P2R',2:'1P2R_BEFORE_SL'}
    for year,g in eligible.groupby('year'):
        for label,c in names.items():
            q=g[g.reach_class.eq(label)];classes.append(dict(year=year,reach_class=c,n=len(q),
                sum_delta_rr1_minus_rr12=(q.rr1_result_r-q.rr12_result_r).sum()))
        for rr,c in [('RR1','rr1_result_r'),('RR12','rr12_result_r')]:allpairs.append(dict(year=year,action=rr,**perf(g[c])))
    pd.DataFrame(classes).to_csv(out/'reach_class_by_year.csv',index=False);pd.DataFrame(allpairs).to_csv(out/'fixed_rr_by_year.csv',index=False)
    paired=[]
    for rr,c in [('RR1','rr1_result_r'),('RR12','rr12_result_r')]:paired.append(dict(action=rr,**perf(eligible[c])))
    shadows=[];executed=[]
    for name,g in p.groupby('model'):
        chosen=g[g.action.ne('SKIP')];v=chosen[chosen.paired_eligible]
        result=np.where(v.action.eq('RR1'),v.rr1_result_r,v.rr12_result_r)
        shadows.append(dict(model=name,selected=len(chosen),RR1=int(chosen.action.eq('RR1').sum()),RR12=int(chosen.action.eq('RR12').sum()),
            skipped=int(g.action.eq('SKIP').sum()),selected_per_month=len(chosen)/96,**perf(result)))
        a=ledger[ledger.model.eq(name)&ledger.accepted];months=monthly[monthly.model.eq(name)]
        executed.append(dict(model=name,accepted=len(a),**perf(a.result_r),avg_month=len(a)/96,
            min_month=int(months.accepted.min()),months_ge20=int((months.accepted>=20).sum())))
    pd.DataFrame(shadows).to_csv(out/'shadow_summary.csv',index=False);pd.DataFrame(executed).to_csv(out/'execution_summary.csv',index=False)
    real=[]
    for name,g in p[p.real_tick_verified_before & p.paired_eligible].groupby('model'):
        q=g[g.action.ne('SKIP')];v=np.where(q.action.eq('RR1'),q.rr1_result_r,q.rr12_result_r)
        real.append(dict(model=name,available=len(g),selected=len(q),**perf(v)))
    pd.DataFrame(real).to_csv(out/'real_tick_shadow_summary.csv',index=False)
    rescue=eligible[eligible.reach_class.eq(1)];n=len(eligible);delta=(eligible.rr1_result_r-eligible.rr12_result_r).mean()
    fig,ax=plt.subplots(figsize=(11,4));ct=eligible.groupby(['year','reach_class']).size().unstack(fill_value=0)
    ct.columns=[names[int(c)] for c in ct.columns];ct.plot.bar(stacked=True,ax=ax);ax.set(ylabel='Candidates',title='Same Entry/SL: first target reached before stop');fig.tight_layout();fig.savefig(out/'reach_classes.png',dpi=150);plt.close(fig)
    fig,axes=plt.subplots(1,2,figsize=(13,4))
    for name,g in annual.groupby('model'):
        axes[0].plot(g.year,g.mean_r,'o-',label=name);axes[1].plot(g.year,g.accepted/12,'o-',label=name)
    axes[0].axhline(0,color='black',ls='--');axes[0].set(ylabel='Mean R (scorable accepts)',xlabel='Test year')
    axes[1].axhline(20,color='black',ls='--');axes[1].set(ylabel='Accepted per month',xlabel='Test year')
    axes[1].legend(fontsize=6);fig.tight_layout();fig.savefig(out/'annual_execution.png',dpi=150);plt.close(fig)
    fig,ax=plt.subplots(figsize=(10,4))
    for name,g in metrics.groupby('model'):ax.plot(g.year,g.ap_rescue,'o-',label=name)
    ax.set(title='Predicting reaches 1R then stops before 1.2R',ylabel='Average precision',xlabel='Test year');ax.legend(fontsize=6);fig.tight_layout();fig.savefig(out/'rescue_prediction.png',dpi=150);plt.close(fig)
    text=f'''# 同じEntry/SLでRR1・RR1.2・見送りを選ぶ研究

## 最初の問い: 方向は合っていたが1.2Rが遠かったのか

全2091候補から、RR1またはRR1.2についてSL/TPの両方に同じ1分足が触れる候補の和集合と未完了を除いた **{n}件** を共通母集団とした。

「1Rには届いたが、1.2R前にSL」は **{len(rescue)}件（{len(rescue)/n:.2%}）**。この群はRR1へ変えれば救えるが、1.2Rへ届く勝ちの利益は縮む。固定RR1と固定RR1.2の平均差は **{delta:+.5f}R/候補**。

{table(pd.DataFrame(paired))}

上記は2016〜2025年全候補の記述比較。以下のモデル評価は2016〜17を初期学習とする2018〜2025年だけであり、件数と期間を混同しない。`reach_class_by_year.csv`に年別の救済件数と利益差を保存した。

## 5パターン（時刻・スプレッドを入力しない）

1. STRUCTURE_LGBM: 既存117から時刻周期4項目とspread関連2項目を除いた111特徴。
2. COMPACT_LGBM: 固定29項目。構造/抵抗/Entry価格位置/確認待ち時間。
3. TSFRESH_LGBM: 29項目＋tsfreshで固定抽出した{qa['automatic_feature_count']}項目。値動きの平均・分散・自己相関・傾きなど。
4. SEQUENCE_LOGISTIC: M1/M5/M15/H1の確定足32本、ATR正規化した終値変化/実体/値幅の並びを、学習側標準化→PCA16→正則化多クラスlogisticへ入力。
5. SEQUENCE_AUG_LOGISTIC: 4と同じモデル。学習波形だけにtsaugの1%レンジノイズを1コピー追加。原系列/複製は各0.5重み、検証・評価は複製しない。

大型Transformerは今回使っていない。波形表現に情報があるかを軽量モデルで先に調べる固定比較。合成系列は独立した新しい候補や取引件数として数えない。ノイズ後の波形に元のラベルが必ず正しい保証はなく、ノイズへの頑健性を試す補助比較として扱う。

時間帯、曜日、spread、tick volume、絶対時刻はモデル入力にしない。Entryは元のAskのままなので、Entryから計算したRや価格位置にスプレッドの影響が間接的に残る。入力を削除してもシミュレータ依存を完全に除去したとは言わない。

## ラベル・予測・選択

3クラスを予測する: SLが1Rより先 / 1R到達後1.2R前にSL / 1.2RがSLより先。これにより `P(1.2R到達) <= P(1R到達)` を必ず満たす。

各年の学習は前年まで。直近1〜2年の過去前進予測だけで多クラス確率を補正する。15分embargoと両方の決着時刻でpurge。外側評価年を特徴選択・補正・ノイズ生成へ使わない。期待Rは予測クラス確率と学習側のクラス別平均SL損失、候補時点で既知のTP幅から計算する。

RR1/RR1.2の高い方の期待Rが正ならそれを選び、両方非正なら見送る。同値ならRR1。この選択規則は事前固定、閾値探索なし。全期間は既知データであり未知OOSではない。

## Shadow評価（保有制約なし）

{table(pd.DataFrame(shadows))}

採点対象は共通のpairedラベルだけ。選択数は事後除外候補も含む。見送りを「0Rの負け」にはしない。bootstrapの全機会損益比較のみ、資金を使わない行動の損益として0を計上する。

## 1ポジション・Entryから15分クールタイム

{table(pd.DataFrame(executed))}

各方策を独立にリプレイ。RRを変えると決済時刻も変わるため、その後の候補の実行可否も再計算する。事後の曖昧さ/未完了を先読みで実行除外せず、占有時間に参加させるが損益採点は除外。年末未完了は年末まで占有し、元の年次独立テストに合わせて年境界でresetする。

RR1の新しいTP到達時刻は正確なtickが未保存のため、M1の最初到達足の終端（同足に元の決済があればその時刻との小さい方）を保守的上限として使う。SLは元の到達tick価格と時刻を使う。元のRR1.2は保存済み結果を維持。手数料/スワップ/証拠金/注文拒否まで再現した実EA一致テストではない。

## 月単位の対応bootstrap

{table(boot)}

差は全共通候補あたりの損益差。見送り0を含むので「取引あたり平均」と分ける。selected_meanは選択されたshadow取引の平均R区間。年別層化し、各モデルで同じ1000回の月ブロック抽出を使用。複数比較・既知データ再利用の影響は残る。

## 元の実tick品質確認済み部分だけでの感度確認

{table(pd.DataFrame(real))}

学習は生成tickを含むまま、元の実tick品質フラグが成立する部分だけでshadow成績を確認する。独立した未知OOSではなく期間も偏っているため、生成tick側との違いの診断に限定する。

## 品質確認と成果物

- Entry/SL/元のRR1.2結果を変更せず、同じAsk Entryを保持。
- RR1.2の再構築は保存済み結果・到達分と照合。Entry BidとM1 Openが全件一致。
- 新しい波形は全{qa['causal_windows']}窓で確定・取得可能時刻を確認し、年ごとの未来価格改変で不変性を確認。
- モデル再学習の予測一致とEA/Sharedハッシュはaudit.jsonへ保存。
- candidates.csv: 全候補・両RR結果・除外理由・reach_class。
- predictions.csv: 予測確率・期待R・事前選択。
- action_statistics.csv / execution_ledger.csv / monthly_execution.csv: RR選択と見送り、実行頻度。
- annual_metrics.csv: 各RR到達予測と救済群予測のAUC/AP/Brier。
- automatic_features.csv / sequence_availability.csv / manifest.json: 抽出特徴量と因果時刻・固定仕様。
- reach_classes.png / annual_execution.png / rescue_prediction.png: 分布と年別比較。

本研究は条件採用ではない。売買EA・Sharedは変更していない。完了後のレビューで、年別の符号、頻度、合成系列の影響を確認してから結論を付ける。
'''
    (out/'summary.md').write_text(text,encoding='utf-8');print('REPORT COMPLETE',flush=True)

if __name__=='__main__':
    import sys
    main(Path(sys.argv[1]))
