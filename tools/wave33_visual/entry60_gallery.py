"""Build an offline 60-case image gallery after frozen blind reviews are linked."""
import csv
import html
import json
from pathlib import Path


def esc(s):return html.escape(str(s),quote=True)


def main():
    root=Path('reports/qa/w33entry60')
    frozen=json.loads((root/'reviews/blind_frozen.json').read_text(encoding='utf-8'))
    assert frozen['status']=='FROZEN_BEFORE_OUTCOME_REVEAL'
    cases=json.loads((root/'analysis/gallery_cases.json').read_text(encoding='utf-8'))
    packets={c['blind_id']:c for c in json.loads((root/'data/blind/packets.json').read_text(encoding='utf-8'))['cases']}
    words={'CLEAR_COUNTERTREND':'①前：持続する逆方向トレンド','RANGE_OR_MIXED':'①前：往復・混在・同方向継続','UNCLEAR':'判定不能','CLEAN':'①：素直に進む','CHOPPY_OR_MIXED':'①：往復が多い／混在','OUTER_RANGE_CLEAR':'前高安範囲を終値突破','INTERNAL_ONLY':'前高安範囲の内側','HIGH':'確信度：高','MID':'確信度：中','LOW':'確信度：低'}
    cards=[]
    for c in cases:
        cid=c['blind_id'];p=packets[cid];s=p['snapshot']
        codes=[words[c[k]] for k in ('prior_structure','w1_progress','break_scope')]
        outcome='勝ち' if c['outcome']=='WIN' else '負け'
        cards.append(f'''<article id="{cid}" data-arm="{c['arm']}" data-side="{c['direction']}" data-result="{c['outcome']}" data-scope="{c['break_scope']}">
<header><b>{cid}　{c['arm']}：{esc(p['upper_tf'].replace('PERIOD_',''))} × {esc(p['lower_tf'].replace('PERIOD_',''))}　{c['direction']}</b><span class="result">{outcome}　{c['net_r']:+.3f}R</span></header>
<a href="charts/{cid}.png" target="_blank"><img src="charts/{cid}.png" alt="{cid} エントリー直前の比較図" loading="lazy"></a>
<div class="notes"><b>{esc(' ／ '.join(codes))}</b><p>{esc(c['concern'])}</p><small>{esc(words[c['confidence']])}</small></div>
<details><summary>注文時点の日時・アンカー情報</summary><p>ORDER {esc(p['order_at'])}<br>①起点 {esc(s['wave1_start_time'])} / {float(s['wave1_start_price']):.2f}<br>①終点 {esc(s['wave1_peak_time'])} / {float(s['wave1_peak_price']):.2f}<br>①終点を知った時刻 {esc(s['wave1_peak_known_at'])}<br>候補発生 {esc(p['candidate_at'])}</p></details>
</article>''')
    body='''<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>3波3波｜①と前ジグザグ60件</title>
<style>body{margin:0;background:#edf2f7;color:#233247;font-family:Meiryo,sans-serif}main{max-width:1800px;margin:auto;padding:18px}h1{font-size:25px;margin:8px 0}p{line-height:1.7}.toolbar{position:sticky;top:0;z-index:3;background:#fff;border:1px solid #cbd5e1;padding:12px;display:flex;gap:12px;flex-wrap:wrap;align-items:center;border-radius:9px}button,select{font:inherit;padding:7px;border:1px solid #94a3b8;border-radius:5px;background:white}button{cursor:pointer}#grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px;margin:18px 0}article{background:#fff;border:2px solid #d3dce6;border-radius:8px;overflow:hidden;scroll-margin-top:100px}article:target{box-shadow:0 0 0 4px #e4ae3f}article header{padding:12px;display:flex;justify-content:space-between;gap:10px}img{width:100%;height:auto;display:block}.result,.notes{display:none}.show-results .result{display:inline}.show-notes .notes{display:block}.show-results article[data-result=LOSS]{border-color:#bc5454}.show-results article[data-result=WIN]{border-color:#21876a}.notes,details{padding:10px 14px;border-top:1px solid #e3e8ef;font-size:13px}details p{font-family:monospace;font-size:12px}.muted{font-size:13px;color:#596b80}a{color:#1d6798}[hidden]{display:none!important}@media(max-width:950px){#grid{grid-template-columns:1fr}h1{font-size:21px}}</style>
<main><h1>①と、その前のジグザグ｜60件のエントリー直前比較</h1>
<p>勝ち30・負け30をA/B・LONG/SHORTに分散。最初は勝敗と観察メモを隠しています。画像を押すと原寸で開きます。<br>上段：①と前の既知ジグザグ。下段：②の内部。エントリー後の足・決済結果は描いていません。</p>
<p class="muted">MT5直接スクリーンショットではなく、原本の確定足・ORDERログからの再構成です。横軸は足数、日時は各カードの詳細にあります。勝敗を均等に抽出したため、この60件の割合は年間勝率ではありません。灰帯がない事例は前8点不足などで外側突破を判定できません。</p>
<div class="toolbar"><select id="arm"><option value="">A/Bすべて</option><option>A</option><option>B</option></select><select id="side"><option value="">買い・売り両方</option><option value="LONG">LONG</option><option value="SHORT">SHORT</option></select><select id="result" disabled><option value="">勝ち・負け両方</option><option value="WIN">勝ち30件</option><option value="LOSS">負け30件</option></select><select id="scope"><option value="">突破範囲すべて</option><option value="OUTER_RANGE_CLEAR">外側突破と観察</option><option value="INTERNAL_ONLY">内側と観察</option><option value="UNCLEAR">判定不能</option></select><button id="reveal">勝敗とR損益を表示</button><button id="notes">観察メモを表示</button><span id="count"></span></div><section id="grid">'''+''.join(cards)+'''</section><p class="muted">観察は勝敗を伏せて固定後に照合しました。画像の形だけで除外条件へ採用したものではありません。<a href="README.md">分析レポート</a> ／ <a href="analysis/visual_annotations_unblinded.csv">全60件と観察記録CSV</a></p></main>
<script>const body=document.body;const selects=['arm','side','result','scope'].map(x=>document.getElementById(x));const cards=[...document.querySelectorAll('article')];function filter(){let n=0;cards.forEach(c=>{let show=selects.every(s=>!s.value||c.dataset[s.id]===s.value);c.hidden=!show;if(show)n++});document.getElementById('count').textContent=n+' / 60件'}selects.forEach(s=>s.addEventListener('change',filter));document.getElementById('reveal').onclick=function(){let shown=body.classList.toggle('show-results');this.textContent=shown?'勝敗とR損益を隠す':'勝敗とR損益を表示';selects[2].disabled=!shown;if(!shown)selects[2].value='';filter()};document.getElementById('notes').onclick=function(){let shown=body.classList.toggle('show-notes');this.textContent=shown?'観察メモを隠す':'観察メモを表示'};filter();</script></html>'''
    (root/'index.html').write_text(body,encoding='utf-8')
    print('Created offline gallery with60 entry-only images, results hidden by default')


if __name__=='__main__':main()
