"""Readable evidence with explicit limits, and an offline comparison chart."""
from pathlib import Path
import plotly.graph_objects as go
from plotly.subplots import make_subplots

NAMES={'donchian':'ドンチャン','bollinger':'ボリンジャー回帰','ichimoku_cloud':'雲ブレイク','atr_breakout':'ATR収縮ブレイク'}
LABELS={'early_stop':'早期SL','early_win':'早期勝ち','late_stop':'遅いSL','all_win':'全勝ち'}
FEATURE_NAMES={'signal_range_atr':'直前足値幅/ATR','signed_body_atr':'方向調整実体/ATR',
 'rejection_wick_fraction':'進行方向側ヒゲ/値幅','signed_move12_atr':'方向調整12本変動/ATR',
 'relative_vol':'相対ATR','signed_ema_distance_atr':'方向調整EMA20距離/ATR',
 'breakout_margin_atr':'ブレイク幅/ATR','signal_spread_proxy_atr':'確定シグナル足spread proxy/ATR'}


def md(df):
    def fmt(v):return f'{v:.4f}' if isinstance(v,float) else str(v)
    return '\n'.join(['| '+' | '.join(df.columns)+' |','| '+' | '.join(['---']*len(df.columns))+' |']+
                     ['| '+' | '.join(fmt(v) for v in row)+' |' for row in df.itertuples(index=False,name=None)])


def render(out,tables,manifest):
    out=Path(out);d=tables['trade_diagnostics'];counts=tables['group_counts'];p=tables['post_exit_paths']
    total=counts.loc[counts.scope.eq('all')].iloc[0];paths=p.loc[p.scope.eq('all')].iloc[0]
    fam=counts.loc[counts.scope.eq('method')].copy();fam['group']=fam.group.map(NAMES)
    feats=tables['feature_comparisons'];f=feats.loc[feats.scope.eq('all') & feats.feature.isin(FEATURE_NAMES)].pivot(index='feature',columns='label',values='median').reset_index()
    f['feature']=f.feature.map(FEATURE_NAMES)
    ci=manifest['early_loss_rate_difference_ci']
    early=d.loc[d.label.eq('early_stop')]
    cost=d.groupby('label')[['quote_stop_distance_atr','quote_target_distance_atr','entry_spread_proxy_atr']].median().reset_index()
    chf=early.loc[early.symbol.eq('USDCHF')].groupby('method').agg(n=('candidate_id','size'),stop_distance=('quote_stop_distance_atr','median'),target_distance=('quote_target_distance_atr','median')).reset_index()
    breakout=feats.loc[feats.scope.eq('method') & feats.feature.eq('breakout_margin_atr') & feats.n.gt(0)].pivot(index='group',columns='label',values='median').reset_index()
    env=tables['context_comparisons']
    e=env.loc[((env.cell.eq('AUDUSD_ichimoku_cloud_SHORT') & env.feature.eq('h1_alignment')) |
               (env.cell.isin(['AUDUSD_bollinger_SHORT','USDJPY_bollinger_LONG']) & env.feature.eq('vol_bucket')))].copy()
    lines=['# 早期SLはなぜ起きるか：勝ちとの比較', '',
      '2026-10-18。既存PF>1シナリオから選ばれた10条件、保守的SL先着2,666取引の事後診断。2024–25は既に探索済み、2026は不使用。ルールを変更せず、独立OOS・因果推定・新フィルタの採択結果とはしない。', '',
      '## 56%の分母と勝ち側の対照', '',
      f'早期SLは{int(total.early_stops)}/{int(total.losses)}敗 = {100*total.early_stop_rate_losses:.2f}%。全取引に対しては{100*total.early_stop_rate_all:.2f}%。勝ちも{int(total.early_wins)}/{int(total.winners)}勝 = {100*total.early_win_rate_winners:.2f}%が最初2本以内に決着した。', '',
      f'両割合の差は{100*ci["difference"]:.2f}ポイント、共通暦4週ブロック2,000反復の95%区間は[{100*ci["ci95_lower"]:.2f}, {100*ci["ci95_upper"]:.2f}]ポイント。選択済み標本の記述的区間であり、独立した市場での有意差検証ではない。', '',
      'この区間は0を跨ぐため、負けだけが特別に早いという差を明確に確認したとは言えない。ロジック間の同時刻重複を機械的にまとめた2,406時点でも、早期SL55.08%/早期勝ち51.90%という関係で、主な解釈は変わらない。', '',
      md(fam[['group','n','losses','winners','early_stops','early_wins','early_stop_rate_losses','early_win_rate_winners']]), '',
      '早期SL752件は1本目452件・2本目300件、すべて通常stop。同足順序不明48敗は含まない。H1の最初1〜2本という意味で、数秒で即損切りだったと確定した意味ではない。保存決済時刻は通常そのH1足終値時刻を上限とし、足内の正確な分数は不明。', '',
      '## 確認できた構造：1ATRの出口と費用', '',
      '現行ルールは約定価格からTP/SLとも1ATR、最大10実足。ATRは過去のTrue Rangeの平均であり、1ATRは常に十分離れた保護水準ではない。早期に勝つ取引も多いことから、短い決着自体はこの出口設計の特徴。[ATRの定義（MetaQuotes）](https://www.metatrader5.com/en/terminal/help/indicators/oscillators/atr)。', '',
      'エントリーにはspreadと片道0.2pipのslippageがある。約定価格から対称に置いた1ATRでも、現在の決済可能quoteからはSLが約1ATR−費用、TPが約1ATR＋費用になる。下表はentry足bar spread proxyと丸めを含む中央値。実際の全tickで確認した距離ではない。', '',
      md(cost), '',
      'USDCHFの早期SLだけを見ると下表。母数の小さいATR15件を他の条件と同じ確度では扱わない。SL側に近いことは約定モデルの構造として確認できるが、この差をすべて実測コストの因果効果とは呼ばない。', '',
      md(chf), '',
      f'早期SL752件中{int(paths.no_neutral_stop_through_exit_n)}件は実SL足までのBid高安が、Bid始値±1ATRという無費用の仮想逆行水準に達していない。最初2本全体でも{int(paths.no_neutral_stop_first2_n)}/{int(paths.neutral_stop_valid_first2)}件は未到達。費用・quote構造の影響を示す感度診断だが、費用を除けばその件数が勝ちになるとは言えない。TPも変わり、約定後の経路・候補制限も変わるため、新口座を再実行した利益ではない。', '',
      '## 事前に観測できる違い', '',
      '全体の中央値は下表。大きな足の後に入ることが一律に悪いという説明は支持されない。早期勝ちのほうがシグナル足値幅と実体が大きい。遅いSLとの比較は決着速度の選択も含むため、早期勝ちを主対照とする。', '',
      md(f), '',
      'ブレイク3系統では、終値が境界を超えた幅は早期SLの中央値0.337ATR、早期勝ち0.450ATR、全勝ち0.394ATR。下表の各系統でも早期SLの抜け幅が小さい。これは「伸び切った足への飛び乗り」より「浅い抜けが続かない」という仮説に整合する。浅い抜けでも勝ちはあり、遅いSLもあるので、この値をそのまま閾値にしてはいけない。BBの回帰幅を同じ指標と見なして混ぜていない。', '',
      md(breakout), '',
      '通貨・手法・方向の構成差を減らすため、同一10条件内の平均差を固定ウェイトで集計した。全通貨を同じ暦4週ブロックで再抽出し、年別の符号も確認した。8特徴の区間は多重比較未調整。閾値・組合せは探索していない。シグナル足spreadも実quoteではなくproxy。BBにはブレイク幅を定義していないため当該行は残り7条件の比較。', '',
      md(tables['feature_block_intervals'][['feature','cell_weighted_mean_difference','ci95_lower','ci95_upper','difference_2024','difference_2025']]), '',
      '## 環境差は手法ごとに違う', '',
      '以下は固定済み4軸の全110区分から説明用に取り上げた事後例であり、選択したフィルタではない。n、早期SL率（全取引分母）、勝ち件数を両年で示す。全区分はcontext_comparisons.csvに保存。', '',
      md(e[['cell','feature','bucket','n','early_stops','early_stop_rate_all','winners','n_2024','early_stop_rate_all_2024','winners_2024','n_2025','early_stop_rate_all_2025','winners_2025']]), '',
      'AUDUSD雲SHORTではH1逆行の早期SL率が両年高いが、勝率の方向は2025年に逆転する。通常ボラもAUDUSDのBBでは早期SLが少なく、USDJPYのBBでは多い。上位足順行だけにする、通常ボラを全部除く、といった共通フィルタで説明できない。', '',
      '## SL後の回復：説明用の価格経路', '',
      'SLで元取引は終了している。エントリーから5本目/10本目の終値が、方向調整後で0ATR以上だった件数を数えた。LONGではBid始値以上、SHORTではBid始値以下を意味する。SLから5本/10本後ではなく、途中で一度でも戻った件数でもない。これは費用前の仮想価格観測で、損切り撤廃の救済率ではない。SL後の最大損失や資金制約も解決していない。', '',
      md(p.loc[p.scope.eq('method'),['group','n_early_stop','valid_h5','returned_to_bid_open_h5','valid_h10','returned_to_bid_open_h10','above_plus1_atr_h10','missing_h10']]), '',
      f'全体ではエントリーから10本目を評価可能な{int(paths.valid_h10)}件中、方向調整後の終値変化が0ATR以上だったのは{int(paths.returned_to_bid_open_h10)}件（{100*paths.returned_to_bid_open_h10/paths.valid_h10:.1f}%）。平均終値変化は{paths.mean_bid_close_atr_h10:.3f}ATRだった。「ほとんどが一時的な振れで、待てば戻る」という説明も支持されない。途中で一度戻ったかという到達率とは別の指標。', '',
      '未知のデータ欠損を跨ぐ窓を除き、未評価数を明記。週末は旧エンジンと同じ明示的閉場proxyで実足を数えた。H2は元SL足の後の値動きが混ざる場合もある。価格補間と2026利用はない。', '',
      '## 判断と次の一手', '',
      '確認できたのは、勝ちも早く終わる1ATR出口の構造、費用によりSL側が近くなること、手法・通貨ごとに異なる事前環境の関連。直前の大きな足やトレンド逆行を共通の主因とは断定できない。市場注文の集中、ニュース、stop huntingなどはデータから確認していない。', '',
      '早期負けの件数だけを減らしても、早期勝ちや遅い勝ちを失えば期待値は改善しない。次に条件を試すなら一つの事前条件を固定し、元候補全件から再生して、失う勝ち・月次件数・ネット期待値・最悪月を比較する。今回SL幅、待機、フィルタを変更していない。実spread履歴、実手数料、swap、独立データによる検証は別の未完了課題。', '',
      '## 成果物', '',
      '[個別取引](trade_diagnostics.parquet)、[条件別件数](group_counts.csv)、[事前特徴](feature_comparisons.csv)、[環境別](context_comparisons.csv)、[SL後価格](post_exit_paths.csv)、[区間推定](feature_block_intervals.csv)、[図](dashboard.html)、[再現情報](manifest.json)。',
    ]
    (out/'report.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    fig=make_subplots(rows=2,cols=2,subplot_titles=['1〜2本での決着件数','全敗/全勝ちのうち早期決着した割合','直前シグナル足の値幅/ATR','エントリー時quoteからSLまでの距離/ATR'])
    for col,label,color in [('early_stops','早期SL','#d05a48'),('early_wins','早期勝ち','#287eae')]:
        fig.add_trace(go.Bar(x=fam.group,y=fam[col],name=label,marker_color=color,legendgroup=label),row=1,col=1)
        rate='early_stop_rate_losses' if col=='early_stops' else 'early_win_rate_winners'
        fig.add_trace(go.Bar(x=fam.group,y=100*fam[rate],name=label,marker_color=color,showlegend=False),row=1,col=2)
        sub=d.loc[d.label.eq('early_stop' if col=='early_stops' else 'early_win')]
        for j,fname in enumerate(['signal_range_atr','quote_stop_distance_atr'],1):
            values=sub[fname].dropna()
            q1,median,q3=values.quantile([.25,.5,.75]);iqr=q3-q1
            lower=values.loc[values.ge(q1-1.5*iqr)].min()
            upper=values.loc[values.le(q3+1.5*iqr)].max()
            fig.add_trace(go.Box(x=[label],q1=[q1],median=[median],q3=[q3],lowerfence=[lower],upperfence=[upper],
                name=label,marker_color=color,showlegend=False,boxpoints=False),row=2,col=j)
    fig.update_layout(height=800,template='plotly_white',margin=dict(t=100,b=70),font=dict(family='Arial, sans-serif'),legend=dict(orientation='h',y=1.1))
    fig.update_yaxes(title_text='件',row=1,col=1);fig.update_yaxes(title_text='%',row=1,col=2)
    fig.update_yaxes(title_text='ATR倍率',row=2,col=1);fig.update_yaxes(title_text='ATR倍率',row=2,col=2)
    html='<!doctype html><html lang="ja"><meta charset="utf-8"><title>早期SL比較</title><style>body{font:16px/1.7 system-ui;margin:28px;color:#24303a}aside{background:#fff4d7;padding:18px}</style><h1>負けだけが早く決着しているのか</h1><aside>早期SL：752/1,345敗＝55.9%。早期勝ち：696/1,320勝＝52.7%。全取引の早期SL率は28.2%。2024–25の探索済みデータ・実swap前・新ルールの検証ではありません。</aside><p><a href="report.md">分析レポート</a> / <a href="feature_comparisons.csv">事前特徴CSV</a></p>'
    html+=fig.to_html(full_html=False,include_plotlyjs=True)
    html+='<p>箱ひげ図は中央値・四分位と1.5IQR内のひげ。外れ値点は非表示、元データからの削除なし。4系統の構成差はレポートの条件内比較で別途確認。SL距離は事後bar spread proxyを使った実行モデル上の量です。</p></html>'
    (out/'dashboard.html').write_text(html,encoding='utf-8')
