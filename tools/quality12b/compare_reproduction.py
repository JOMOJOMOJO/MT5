"""Accept unchanged trade executions with separately attributed swap differences."""
import argparse
import json
from decimal import Decimal
from pathlib import Path
from analyze_reports import analyze_report

OPERATIONAL = {'InpTelemetryFileName', 'InpOperatorCommandFile', 'InpStatusFileName'}
CORE_FIELDS = ('symbol', 'side', 'entry_time', 'entry_price', 'volume', 'initial_sl',
               'initial_tp', 'exit_time', 'exit_price', 'exit_reason', 'exit_comment',
               'profit', 'commission')


def compare(reference, candidate, *, require_real_ticks=True):
    old, before = analyze_report(reference, require_real_ticks=require_real_ticks)
    new, after = analyze_report(candidate, require_real_ticks=require_real_ticks)
    errors = []
    if not old['audit']['passed'] or not new['audit']['passed']:
        errors.append('Report audit failed')
    for key in ('broker', 'currency', 'symbol', 'timeframe', 'from_date', 'to_date'):
        if old['report'][key] != new['report'][key]:
            errors.append('Report identity differs: ' + key)
    old_inputs = {k: v for k, v in old['report']['inputs'].items() if k not in OPERATIONAL}
    new_inputs = {k: v for k, v in new['report']['inputs'].items() if k not in OPERATIONAL}
    if old_inputs != new_inputs:
        errors.append('Strategy/management input values differ')
    for key in ('initial_deposit', 'bars', 'ticks'):
        if old['reported'][key] != new['reported'][key]:
            errors.append('Report count/value differs: ' + key)
    if len(before) != len(after):
        errors.append('Trade counts differ')
    differences, swap_rows = [], []
    for i, (a, b) in enumerate(zip(before, after), start=1):
        changed = {k: {'reference': a[k], 'candidate': b[k]} for k in CORE_FIELDS if a[k] != b[k]}
        if changed:
            differences.append({'trade_index': i, 'entry_time': a['entry_time'], 'fields': changed})
        delta_net = Decimal(str(b['net'])) - Decimal(str(a['net']))
        delta_swap = Decimal(str(b['swap'])) - Decimal(str(a['swap']))
        if delta_net != delta_swap:
            errors.append(f'Trade {i}: net difference is not solely swap')
        if delta_swap:
            swap_rows.append({'trade_index': i, 'entry_time': a['entry_time'], 'old_swap': a['swap'],
                              'new_swap': b['swap'], 'delta_swap': float(delta_swap)})
    if differences:
        errors.append('Entry/exit/size/SL/TP/profit/commission sequence differs')
    old_calc, new_calc = old['calculated'], new['calculated']
    net_delta = Decimal(str(new_calc['net_profit'])) - Decimal(str(old_calc['net_profit']))
    swap_delta = Decimal(str(new_calc['swap'])) - Decimal(str(old_calc['swap']))
    if net_delta != swap_delta:
        errors.append('Aggregate net delta is not explained by swap delta')
    passed = not errors
    return {'schema': 1, 'passed': passed,
            'classification': ('EXACT_EXECUTIONS_SWAP_ONLY_DIFFERENCE' if swap_rows else 'EXACT_EXECUTIONS_AND_COSTS') if passed else 'REPRODUCTION_MISMATCH',
            'reference_sha256': old['report']['sha256'], 'candidate_sha256': new['report']['sha256'],
            'reference': old_calc, 'candidate': new_calc, 'trade_count': len(after),
            'exact_core_fields': list(CORE_FIELDS), 'core_trade_differences': differences,
            'swap_difference_trades': swap_rows, 'net_delta': float(net_delta), 'swap_delta': float(swap_delta),
            'errors': errors,
            'note': 'Observed swap-only difference is attributed, not removed from candidate P/L. No parameter or P/L threshold relaxation. Identical fills in this sample do not establish profitability or binary identity.'}


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference', required=True, type=Path)
    p.add_argument('--candidate', required=True, type=Path)
    p.add_argument('--out', required=True, type=Path)
    p.add_argument('--allow-generated-history-for-parity', action='store_true', help='Execution parity only; does not approve generated history quality')
    args = p.parse_args()
    result = compare(args.reference, args.candidate, require_real_ticks=not args.allow_generated_history_for_parity)
    result['real_tick_header_required'] = not args.allow_generated_history_for_parity
    args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({k: result[k] for k in ('passed', 'classification', 'trade_count', 'net_delta', 'swap_delta')}))
    raise SystemExit(0 if result['passed'] else 2)
