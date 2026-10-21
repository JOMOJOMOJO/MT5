"""Review the four completed, invariant M5 runs without including daily QA."""
import argparse,json
from pathlib import Path
from analyze_cost_channel import read,write,save,metrics

def review(batch):
    out=batch/'cost_review';out.mkdir(exist_ok=True);allrows=[];audits=[]
    for side in ('long','short'):
        for period in ('2023_2024','2025_2026'):
            name=f'cost_{side}_{period}';folder=batch/name
            a=json.loads((folder/'audit.json').read_text());p=json.loads((folder/'execution_parity.json').read_text())
            assert a['passed'] and p['passed'] and p['classification']=='EXACT_EXECUTIONS_AND_COSTS'
            assert a['actual']['n']==a['actual']['exact_quote_n']
            rows=read(folder/'trades_cost_decomposition.csv');assert metrics(rows)==a['actual']
            for r in rows:r['family']=side;r['run_id']=name
            allrows+=rows;audits.append(dict(run_id=name,n=len(rows),quality=a['quality']['category']))
    assert len(allrows)==447
    write(out/'trades.csv',allrows);groups=[]
    for side in ('long','short'):
        for year in ('ALL','2023','2024','2025','2026'):
            selected=[r for r in allrows if r['family']==side and (year=='ALL' or r['year']==year)]
            groups.append(dict(side=side,year=year,**metrics(selected)))
    write(out/'statistics.csv',groups);save(out/'audit.json',dict(passed=True,n=447,runs=audits))
    lines=['# 現行M5：同一Entry/Exit時刻でのコスト分解','',
      '447実取引のEntry/Exit/ロット/SL/TP/利益/手数料/swapは元レポートと完全一致。全件の同期quoteを取得。',
      '日足研究の不具合とは独立した、完了済みM5診断。','',
      '|側|年|件数|mid価格変化R|spread負担R|約定価格R|純損益USD|PF|',
      '|---|---|---:|---:|---:|---:|---:|---:|']
    for r in groups:lines.append(f"|{r['side']}|{r['year']}|{r['n']}|{r['mean_mid_move_r']:+.4f}|{r['mean_spread_cost_r']:.4f}|{r['mean_fill_r']:+.4f}|{r['net']:+.2f}|{r['pf']:.3f}|")
    lines+=['','## 解釈',
      '- LONGは同じEntry/Exit時刻のmid変化が平均+0.0771R。spread負担約0.0702Rで残る約定価格損益は+0.0069R。価格方向の寄与の大部分がspread負担で相殺されている。',
      '- SHORTはmid変化自体が負。spreadだけを改善しても、この固定時刻の平均損益は正にならない。',
      '- 年別の符号も確認する。全期間mid平均が正でも毎年の優位性、全候補の優位性、将来の優位性を意味しない。',
      '- 手数料/swap/feeは今回のM5実取引では全件0。約定価格と同時気配の残差も0。このテスター設定の事実であり実運用コスト0の保証ではない。',
      '- spread制限緩和後の成績ではない。見送り候補の追加やEntry/Exit時刻の変化を再現していない。',
      '- コストをゼロにしてSL/TPを再判定したバックテストでもない。決済時刻自体が元のコスト込み売買で決まっている。',
      '- 2023–2024と2025–2026年9月は別初期資金の既知期間テスト。生成tick混在、OOSではない。','',
      '日足戦略の判定は保留。市場休場での確定拒否後に当日シグナルを消費する不具合が見つかったため、初版の取引数・損益を研究成績として採用しない。']
    (out/'summary.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(json.dumps([g for g in groups if g['year']=='ALL'],ensure_ascii=False))

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--batch',type=Path,required=True);review(p.parse_args().batch)
