"""Dataset audit document, computed solely from the acquired development bars."""
import json
from pathlib import Path
import pandas as pd
from .data import sha
from .report import markdown


def render(path):
    path=Path(path)
    m=json.loads((path/'manifest.json').read_text(encoding='utf-8'))
    rows=[]
    for r in m['datasets']:
        if r['status'] != 'available':
            continue
        assert sha(r['path'])==r['sha256']
        f=pd.read_parquet(r['path'])
        assert (f.time < 1767225600).all()
        gaps=pd.read_csv(Path(r['path']).with_suffix('.gaps.csv'))
        rows.append({'symbol':r['symbol'],'TF':r['timeframe'],'development_rows':r['development_rows'],
                     'first':str(pd.Timestamp(r['first_development_time'],unit='s')),
                     'last':str(pd.Timestamp(r['last_development_time'],unit='s')),
                     'months':r['months_with_data'],'gap_intervals':r['noncontiguous_intervals'],
                     'gaps_1h_or_less':int((gaps.seconds<=3600).sum()),
                     'spread_fallback_rows':r['nonpositive_spread_rows']})
    old=pd.read_parquet('reports/research/entry_candidates/data_20261014/M5.parquet')
    new=pd.read_parquet(path/'USDJPY/M5.parquet')
    joined=old.merge(new,on='time',suffixes=('_old','_new'))
    changes={c:int((joined[c+'_old']!=joined[c+'_new']).sum()) for c in ['open','high','low','close','spread']}
    result={'shared_usdjpy_m5_bars':len(joined),'different_values':changes,
            'old_bars_missing_from_new':int((~old.time.isin(new.time)).sum()),
            'new_bars_missing_from_old':int((~new.time.isin(old.time)).sum())}
    (path/'old_data_comparison.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    text=f'''# データ品質監査 2026-10-16

価格の取得元: **{m['broker']} / {m['server']}**、MT5 build {m['terminal_build']}、MaxBars={m['maxbars']}。
既存通常端末のEA/profileをコピーせず、AlgoTrading無効の新規研究専用端末で取得。口座認証情報はリポジトリに保存していない。

期間は2023-10-01から2025-12-31まで（2023は指標warmupだけ）。月次要求、終端は2026-01-01排他的。5通貨は2024–25の全月、USDCHFは2024年8月からの17か月。価格・OHLC・重複チェック通過、Parquet全30個のSHA256確認。取得可能期間が短いUSDCHFを他brokerの価格で補完しない。

{markdown(pd.DataFrame(rows))}

ギャップは休場・週末を含む。取引カレンダーが未確認のため異常欠損との確定区別はできない。小さいギャップも数と時刻を各 `.gaps.csv` に保存。欠損をforward fillしない。OHLC不整合・非正値・重複は受領時に失敗させる。各月件数は `.coverage.csv`。

USDCHFの取得不能月では、APIが要求範囲より後の最初の観測足1件を返した。この応答を取り込まず拒否し、日時・再試行を requests.csv に保存した。初回取得処理はこのガードで停止し、受領応答を月単位で隔離して他月を継続できるよう修正した。2026以降を要求・分析していない。初回の範囲外応答にも2026価格は含まれていない。

## 時刻・価格・コスト

- datetimeは明示UTCでAPIに渡した。API契約はUTC、broker時計とUTCの歴史的対応は未確認。夏時間を推測せず、地域セッション分析は保留。source clockの時・曜日一致だけを使う。
- `available_time=nominal close_time` は履歴バーの既知時刻proxy。実ティックの最初の観測時刻ではない。シグナルの次の観測始値で約定proxyを置き、1時間足分を超す遅延を失効扱い。
- Bid OHLCとbar spread。Ask OHLC・実tick順・履歴手数料・約定slip・swapは未取得。正値spreadも実際のentry/exit quoteの証拠ではない。
- manifest.specsにpoint/digits、pip換算、tick size/value、contract、最小/最大lot/step、profit currencyを保存。現在値であり歴史値の同一性未確認。tick valueは過去換算に使わない。pipは明示FX規約（JPY0.01、他0.0001）。
- broker stop distance/freeze level、margin、swapが歴史的に未検証。口座損益はprovisional。別brokerの価格を混ぜていない。

## 旧USDJPY M5との照合

共通{result['shared_usdjpy_m5_bars']:,}足。値が異なる足数: {changes}。旧のみ{result['old_bars_missing_from_new']:,}足、新のみ{result['new_bars_missing_from_old']:,}足（warmup開始・年度終了の収録差も含む）。
旧collectorは `max(nominal_close, first_observed)` を記録していたため、価格が一致してもavailabilityは同一と限らない。新取得した全通貨データ内で6手法を比較し、旧レポートと数値が同じであることを前提にしない。

## 制約と採択

USDCHFの欠損期間、clock対応、取引日カレンダー、歴史的仕様、実tick/costが未検証。これらを推測で埋めて採択しない。口座の未解決建玉がギャップを跨げば以後の経路を打切りとし、通年PF/DDと称さない。

根拠: [MT5 copy_rates_range](https://www.mql5.com/en/docs/python_metatrader5/mt5copyratesrange_py)。取得時configのhashはmanifestに保持。価格取得後・成績計算前にbootstrap回数だけ10000→20000へ修正しており、取得期間と価格データは変更していない。
'''
    (path/'audit.md').write_text(text,encoding='utf-8')
    return result


if __name__=='__main__':
    import sys
    print(json.dumps(render(sys.argv[1]),indent=2))
