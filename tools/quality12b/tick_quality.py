"""Read-only real-tick coverage audit, scoped to the requested tester execution."""
import re
from pathlib import Path


def header_percent(value):
    if not re.search(r'リアルティック|real\s*ticks?', value or '', re.I):
        return None
    match = re.search(r'(\d+(?:\.\d+)?)\s*%', value)
    return float(match[1]) if match else None


def execution_blocks(report, journals):
    root = Path(journals)
    groups = {}
    for p in sorted(root.rglob('*.log')):
        if any(part.startswith('Agent-') for part in p.parts):
            groups.setdefault(str(p.parent), []).append(p)
    generic = re.compile(r'testing of .* from \d{4}\.\d{2}\.\d{2} 00:00 to \d{4}\.\d{2}\.\d{2} 00:00 started with inputs:', re.I)
    wanted = re.compile(r'testing of .*' + re.escape(report['expert']) + r'\.ex5 from ' + re.escape(report['from_date']) + r' 00:00 to ' + re.escape(report['to_date']) + r' 00:00 started with inputs:', re.I)
    blocks = []
    for paths in groups.values():
        lines = []
        for p in paths:
            lines.extend(p.read_text(encoding='utf-8-sig').splitlines())
        for start, line in enumerate(lines):
            if wanted.search(line):
                end = next((i for i in range(start + 1, len(lines)) if generic.search(lines[i])), len(lines))
                blocks.append(lines[start:end])
    # Optimization grids reuse the same expert/date window. The runner assigns
    # a unique telemetry filename per execution; period alone is not an ID.
    tag = report.get('inputs', {}).get('InpTelemetryFileName')
    if tag:
        identity = re.compile(r'\bInpTelemetryFileName=' + re.escape(str(tag)) + r'\s*$')
        blocks = [block for block in blocks if any(identity.search(line) for line in block)]
    return blocks


def audit(report, journals):
    blocks = execution_blocks(report, journals)
    pct = header_percent(report.get('model_quality'))
    block = blocks[0] if len(blocks) == 1 else []
    fallback = [line for line in block if re.search(r'real ticks (?:absent|discarded)|every tick generation used', line, re.I)]
    complete = any(re.search(r'test .* thread finished', line, re.I) for line in block)
    passed = pct == 100 and len(blocks) == 1 and complete and not fallback
    if pct == 0:
        category = 'GENERATED_TICKS'
    elif fallback or (pct is not None and 0 < pct < 100):
        category = 'MIXED_TICKS'
    elif passed:
        category = 'REAL_TICKS_NO_FALLBACK_REPORTED'
    else:
        category = 'UNVERIFIED'
    return {'strict_real_tick_pass': passed, 'category': category, 'header_real_tick_percent': pct,
            'matching_execution_blocks': len(blocks), 'test_finished_in_block': complete,
            'fallback_line_count': len(fallback), 'fallback_evidence': fallback,
            'scope': 'Expert/date plus unique telemetry input when present; ambiguous executions rejected',
            'limit': 'Header percentage may be rounded; no-fallback log is evidence, not a hash proof of historical ticks'}
