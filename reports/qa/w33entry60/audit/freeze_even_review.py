"""Freeze manually inspected even-ID PNG annotations before label reveal."""
import csv
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
CHARTS = HERE.parent / 'charts'
PACKETS = HERE.parent / 'data/blind/packets.json'

# Entered from full, entry-only final PNG inspections; no outcome table read.
ratings = [
('V002','RANGE_OR_MIXED','CLEAN','UNCLEAR','MID','高値低下と大きな往復が混在。①は素直だが事前7点で外側8点の範囲を確定できない。'),
('V004','RANGE_OR_MIXED','CHOPPY_OR_MIXED','INTERNAL_ONLY','HIGH','①前に高値安値が大きく往復。①内も交互の実体と長いヒゲが多く、直前の高値群より下。'),
('V006','CLEAR_COUNTERTREND','CLEAN','INTERNAL_ONLY','HIGH','直前に段階的な上昇があり①の下落も滑らか。ただし①安値は上昇前の安値より上。'),
('V008','RANGE_OR_MIXED','CLEAN','UNCLEAR','MID','広い表示では上昇継続内の小さな押しからの①。事前3点のため外側8点の判定は不能。'),
('V010','RANGE_OR_MIXED','CHOPPY_OR_MIXED','INTERNAL_ONLY','HIGH','①前は同じ価格帯を往復。①内に大きな戻しを挟み、安値は事前レンジ下端まで届かない。'),
('V012','RANGE_OR_MIXED','CHOPPY_OR_MIXED','INTERNAL_ONLY','HIGH','直前後半は上昇だが以前は横ばい。①内に戻しが多く、以前の押し安値群の上で止まる。'),
('V014','RANGE_OR_MIXED','CLEAN','OUTER_RANGE_CLEAR','HIGH','直前は高安切上げが一貫せず重なる。①後半の下落は明瞭で事前最安値より下に実体が進む。'),
('V016','RANGE_OR_MIXED','CLEAN','INTERNAL_ONLY','HIGH','直前は同水準の高値と安値を繰り返す。①の反発は速いが高値は以前の高値群の内側。'),
('V018','CLEAR_COUNTERTREND','CHOPPY_OR_MIXED','UNCLEAR','MID','下降後の安値圏で長く横ばいになり、最後の短い反発で①。事前3点で外側範囲は不明。'),
('V020','CLEAR_COUNTERTREND','CHOPPY_OR_MIXED','INTERNAL_ONLY','MID','直前は上昇が進むが①下落中に直前波ほどの戻しを繰り返す。①終点のヒゲだけが以前の安値近傍。'),
('V022','RANGE_OR_MIXED','CLEAN','INTERNAL_ONLY','HIGH','事前は高値・安値が広く重なる。①の短い下落は滑らかだが以前の安値を終値で越えない。'),
('V024','CLEAR_COUNTERTREND','CLEAN','UNCLEAR','HIGH','直前の高値安値が連続して上がり①は連続陰線で下落。事前7点のため外側8点判定は保留。'),
('V026','RANGE_OR_MIXED','CHOPPY_OR_MIXED','UNCLEAR','MID','①の大半は高値圏の横ばいで、終盤2本ほどで急落。旧最安値への接近がヒゲか終値か判別しづらい。'),
('V028','CLEAR_COUNTERTREND','CHOPPY_OR_MIXED','INTERNAL_ONLY','HIGH','以前の下降は明瞭。①は上昇後に停滞と押しを挟み、以前の戻り高値群をまだ越えていない。'),
('V030','RANGE_OR_MIXED','CHOPPY_OR_MIXED','INTERNAL_ONLY','HIGH','事前高値がほぼ同値で往復。描画①の起点より下の安値が①の途中にあり、後半だけ急反発する。'),
('V032','RANGE_OR_MIXED','CLEAN','UNCLEAR','MID','直前の山谷に一方向性が乏しい。①は概ね下向きだが事前安値すれすれで終値突破を断定しづらい。'),
('V034','CLEAR_COUNTERTREND','CHOPPY_OR_MIXED','INTERNAL_ONLY','HIGH','直前の上昇は段階的。①線の大半は高値圏で横ばい、最後の急落でも以前の最安値は下に残る。'),
('V036','CLEAR_COUNTERTREND','CHOPPY_OR_MIXED','INTERNAL_ONLY','HIGH','直前は急な下降。描画①起点の後にさらに安値を掘ってから反発し、以前の戻り高値までは遠い。'),
('V038','RANGE_OR_MIXED','CLEAN','OUTER_RANGE_CLEAR','HIGH','直前の小さな戻しは重なりが多い。①は比較的素直に下げ、以前の押し安値の外へ実体が進む。'),
('V040','RANGE_OR_MIXED','CHOPPY_OR_MIXED','UNCLEAR','MID','直前は下降と戻しが混在。①内部でも戻しを挟み、以前のレンジ下端の終値突破は明確でない。'),
('V042','RANGE_OR_MIXED','CHOPPY_OR_MIXED','UNCLEAR','HIGH','以前は下降、その後に単発の急上昇。①内の戻しが大きく、事前7点のため外側8点は不明。'),
('V044','CLEAR_COUNTERTREND','CLEAN','INTERNAL_ONLY','HIGH','直前の高値低下が明瞭。①反発は速いが以前の戻り高値群の下にとどまる。'),
('V046','RANGE_OR_MIXED','CLEAN','INTERNAL_ONLY','HIGH','直前は下降後の上昇と戻しが混在。①自体は滑らかだが以前の高値より低い。'),
('V048','RANGE_OR_MIXED','CLEAN','INTERNAL_ONLY','HIGH','①直前の上昇は強いが事前の山谷は切上げが一貫しない。①下落の終点も以前の最安値より上。'),
('V050','RANGE_OR_MIXED','CLEAN','UNCLEAR','HIGH','以前の高値は低下し、売りに必要な持続上昇ではない。①は速いが事前5点で外側8点は未確定。'),
('V052','RANGE_OR_MIXED','CLEAN','INTERNAL_ONLY','HIGH','以前の大きな下落と戻しが混在。①下落は短く素直だが以前の急落安値よりかなり上。'),
('V054','RANGE_OR_MIXED','CHOPPY_OR_MIXED','INTERNAL_ONLY','HIGH','以前の山谷が重なる。描画①の起点を後から下回って反発しており、以前の高値までは届かない。'),
('V056','CLEAR_COUNTERTREND','CLEAN','INTERNAL_ONLY','MID','直前後半の下降から素直に反発。①高値のヒゲは旧高値近傍だが実体はその内側に見える。'),
('V058','RANGE_OR_MIXED','CLEAN','INTERNAL_ONLY','HIGH','直前後半は下向きだが以前の高安は重なりが多い。①反発が素直でも以前の高値まで距離が残る。'),
('V060','CLEAR_COUNTERTREND','CLEAN','INTERNAL_ONLY','MID','直前の戻り高値が下がる局面から①が反発。途中の押しはあるが以前の波より小さく、最高値は未突破。'),
]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    path = HERE / 'even_blind_review.json'
    if path.exists():
        raise SystemExit('Already frozen; do not overwrite before or after label reveal.')
    fields = ('blind_id','prior_structure','w1_progress','break_scope','confidence','concern')
    cases = [dict(zip(fields, values), image_sha256=sha(CHARTS / (values[0]+'.png'))) for values in ratings]
    assert [c['blind_id'] for c in cases] == [f'V{i:03}' for i in range(2, 61, 2)]
    manifest = json.loads((CHARTS / 'render_manifest.json').read_text(encoding='utf-8'))
    result = dict(reviewer='entry60_method_audit', review_type='EVEN_30_ENTRY_ONLY_BLIND', labels_read=False,
                  full_final_pngs_individually_inspected=30, packet_sha256=sha(PACKETS),
                  render_manifest_sha256=sha(CHARTS / 'render_manifest.json'),
                  render_script_sha256=manifest['script_sha256'],
                  rule='Final adaptive upper window min90/max300, fixed precontext; no outcome tables read.',
                  all_earlier_300_bar_layout_cases_revisited=True, cases=cases)
    path.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    with (HERE / 'even_blind_review.csv').open('w', encoding='utf-8-sig', newline='') as handle:
        writer=csv.DictWriter(handle, fieldnames=list(cases[0])); writer.writeheader(); writer.writerows(cases)
    (HERE / 'even_blind_review.sha256').write_text(sha(path)+'\n', encoding='ascii')
    print(json.dumps(dict(frozen=True, cases=len(cases), labels_read=False, review_sha256=sha(path),
                         render_script_sha256=manifest['script_sha256'])))


if __name__ == '__main__':
    main()
