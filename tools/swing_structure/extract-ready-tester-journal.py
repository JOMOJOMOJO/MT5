"""Find the last exact tester run marker, independent of log rotation/line offsets."""
from pathlib import Path
import sys,json,hashlib

def extract(source,destination,expert,start,end):
    source=Path(source);destination=Path(destination)
    marker=f'testing of Experts\\{expert}.ex5 from {start} 00:00 to {end} 00:00 started'
    sources=sorted(source.glob('*.log'))[-2:] if source.is_dir() else [source]
    chunks=[];provenance=[]
    for file in reversed(sources):
        raw=file.read_bytes();encoding='utf-16' if raw[:2] in [b'\xff\xfe',b'\xfe\xff'] else 'utf-8-sig'
        chunk=raw.decode(encoding).splitlines();chunks.insert(0,chunk)
        provenance.insert(0,dict(source=str(file),sha256=hashlib.sha256(raw).hexdigest()))
        if any(marker in line for line in chunk):break
    lines=[line for chunk in chunks for line in chunk]
    starts=[i for i,l in enumerate(lines) if marker in l]
    if not starts:raise RuntimeError('Exact tester run marker not found; do not guess log offset')
    first=starts[-1];last=len(lines)
    for i in range(first+1,len(lines)):
        if 'testing of Experts\\' in lines[i] and ' started' in lines[i]:last=i;break
    destination.write_text('\n'.join(lines[first:last])+'\n',encoding='utf-8-sig')
    destination.with_suffix('.extraction.json').write_text(json.dumps(dict(sources=provenance,first_line=first,last_line_exclusive=last,marker=marker),indent=2))

if __name__=='__main__':extract(*sys.argv[1:])
